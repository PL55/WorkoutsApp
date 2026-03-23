# Performance Improvements Design

**Date**: 2026-03-22
**Status**: Approved
**Scope**: Performance fixes + ViewModel extraction. Exercise type refactoring deferred to a future round.

---

## Problem Statement

The app has several performance issues that will degrade as data grows:

1. **Render-path recomputation**: `groupedSessions`, `allExercises`, and library suggestion filtering all execute in the SwiftUI view body, running on every render regardless of whether their inputs changed.
2. **Unindexed queries**: `progressEntries` performs two full-table scans on `StrengthExercise` and `CardioExercise` filtered by `name` with no SwiftData index.
3. **Main-thread blocking at launch**: `ModelContainer` initialization runs synchronously on `@MainActor`, blocking the first frame.
4. **Silent data loss on failure**: If `ModelContainer` creation fails, the app silently falls back to an in-memory stub — the user loses all data with no recovery path.
5. **CancelBag doesn't cancel**: `cancel()` removes references without calling `cancel()` on stored tasks, so they continue running in the background.
6. **Loadable error equality is fragile**: Comparing errors by `localizedDescription` means different errors with the same message are treated as equal, suppressing SwiftUI re-renders.

---

## Design

### 1. ViewModel Layer

Introduce `@Observable` ViewModels for three views. Views own their VM via `@State`. Views still own `@Query` and pass results into the VM via `onChange`. VMs hold the interactor reference and expose computed/cached state.

**ViewModel initialization pattern:** `@Environment` is not available at `@State` init time. ViewModels are initialized with a placeholder interactor (`StubWorkoutsInteractor`) and then configured with the real interactor in `.onAppear` or `.task`. Each VM exposes a `configure(interactor:)` method for this purpose. Since operations require user interaction (taps, form submission), the brief window between init and configuration has no behavioral impact.

```swift
// Pattern used by all three VMs:
@State private var vm = SessionListViewModel()

.task {
    vm.configure(interactor: injected.interactors.workouts)
}
```

#### SessionListViewModel

```swift
@Observable
final class SessionListViewModel {
    private(set) var groupedSessions: [(key: Date, value: [WorkoutSession])] = []
    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    func sessionsDidChange(_ sessions: [WorkoutSession]) {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        groupedSessions = grouped.sorted { $0.key > $1.key }
    }

    func deleteSession(id: UUID) async throws {
        try await interactor.deleteSession(id: id)
    }
}
```

**View integration:**
- `SessionListView` creates `@State private var vm = SessionListViewModel()`.
- Uses `.task { vm.configure(interactor: injected.interactors.workouts) }` to inject the real interactor.
- Uses `.onChange(of: sessions, initial: true)` to call `vm.sessionsDidChange(sessions)`.
- Body reads `vm.groupedSessions` (a stored property, no recomputation).

#### SessionDetailViewModel

```swift
@Observable
final class SessionDetailViewModel {
    private(set) var allExercises: [any AnalyticsTrackable] = []
    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    func updateExercises(strength: [StrengthExercise], cardio: [CardioExercise]) {
        allExercises = (strength as [any AnalyticsTrackable]) + (cardio as [any AnalyticsTrackable])
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        try await interactor.deleteExercise(id: id, type: type, from: sessionID)
    }
}
```

**View integration:**
- `SessionDetailView` creates `@State private var vm = SessionDetailViewModel()`.
- Uses `.task { vm.configure(interactor: injected.interactors.workouts) }`.
- Calls `vm.updateExercises(strength:cardio:)` in `.onChange(of: session.strengthExercises, initial: true)` (and same for cardio).
- Body reads `vm.allExercises`.

#### AddExerciseViewModel

```swift
@Observable
final class AddExerciseViewModel {
    var exerciseType: ExerciseType = .strength
    var name: String = ""
    var sets: Int = 3
    var reps: Int = 10
    var weight: Double = 0
    var durationMinutes: Double = 0
    var saveState: Loadable<UUID> = .notRequested
    private(set) var filteredSuggestions: [ExerciseLibraryEntry] = []

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()
    private let sessionID: UUID?

    init(sessionID: UUID?) {
        self.sessionID = sessionID
    }

    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    func updateSuggestions(from library: [ExerciseLibraryEntry]) {
        filteredSuggestions = library.filter {
            $0.type == exerciseType
            && $0.name.localizedCaseInsensitiveContains(name)
            && $0.name != name
        }
    }

    func save() {
        let input: ExerciseInput
        switch exerciseType {
        case .strength:
            input = .strength(name: name, sets: sets, reps: reps, weight: weight)
        case .cardio:
            input = .cardio(name: name, durationMinutes: durationMinutes)
        }
        let cancelBag = CancelBag()
        saveState.setIsLoading(cancelBag: cancelBag)
        let task = Task {
            do {
                saveState = .loaded(try await interactor.addExercise(to: sessionID, input: input))
            } catch {
                saveState = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }
}
```

**Note on Loadable in ViewModels:** The `LoadableSubject.load {}` extension operates on `Binding<Loadable<T>>`, which is not available inside an `@Observable` class. ViewModels use `Loadable` directly via manual `Task` + state assignment as shown above. Views that still use `@State var loadable: Loadable<T>` (like `ExerciseProgressView`) can continue using `$loadableState.load {}`.

**View integration:**
- `AddExerciseView` creates the VM at init.
- Uses `.onChange(of: vm.name)` and `.onChange(of: vm.exerciseType)` to call `vm.updateSuggestions(from: libraryEntries)`.
- `@Query` for `libraryEntries` stays in the view; results passed to VM on change.
- Body reads `vm.filteredSuggestions`, `vm.saveState`, and binds form fields to VM properties.

#### ExerciseProgressView — no ViewModel

This view is already clean: `Loadable` + `onAppear`, no computation in body. No changes needed.

#### File locations

New files:
- `WorkoutsApp/UI/SessionList/SessionListViewModel.swift`
- `WorkoutsApp/UI/SessionDetail/SessionDetailViewModel.swift`
- `WorkoutsApp/UI/AddExercise/AddExerciseViewModel.swift`

### 2. SwiftData Indexes

#### Index declarations

Add `#Index` macro to both exercise models. SwiftData's `#Index` macro is declared at the `@Model` body level (not as a property attribute):

```swift
// StrengthExercise.swift
@Model
final class StrengthExercise {
    #Index<StrengthExercise>([\.name])
    // ... existing properties unchanged
}

// CardioExercise.swift
@Model
final class CardioExercise {
    #Index<CardioExercise>([\.name])
    // ... existing properties unchanged
}
```

#### Schema migration approach

Adding indexes is a lightweight schema change that SwiftData handles automatically. No `VersionedSchema` or `SchemaMigrationPlan` is needed — SwiftData detects the new index annotations and creates them on the next store open.

The existing `AppSchema` and `ModelContainer` configuration remain unchanged. If automatic migration fails on a user's device, the existing error recovery UI (Section 3) will surface the error with a retry option.

**Note:** `ModelContainer.stub` remains available for tests and the `DIContainer` default `@Entry` value. It is NOT removed — only the silent production fallback in `AppEnvironment` is eliminated.

### 3. Async Bootstrap + Error Recovery UI

#### AppEnvironment changes

`bootstrap()` becomes a throwing async function that creates the `ModelContainer` off the main thread:

```swift
struct AppEnvironment {
    let diContainer: DIContainer
    let modelContainer: ModelContainer

    static func bootstrap() async throws -> AppEnvironment {
        let modelContainer = try ModelContainer.appModelContainer()
        let dbRepository = MainDBRepository(modelContainer: modelContainer)
        let appState = Store<AppState>(AppState())
        let interactors = DIContainer.Interactors(
            workouts: RealWorkoutsInteractor(dbRepository: dbRepository)
        )
        let diContainer = DIContainer(appState: appState, interactors: interactors)
        return AppEnvironment(diContainer: diContainer, modelContainer: modelContainer)
    }
}
```

- Removes `@MainActor` constraint
- Removes `isRunningTests` (moved to the root view level)
- Removes the silent `catch` → `stub` fallback — errors propagate

#### Root view changes

Introduce a `RootView` that manages launch state:

```swift
struct RootView: View {
    @State private var launchState: Loadable<AppEnvironment> = .notRequested

    let inspection = Inspection<Self>()

    var body: some View {
        content
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch launchState {
        case .notRequested, .isLoading:
            ProgressView("Loading...")
                .onAppear { bootstrap() }
        case .loaded(let env):
            SessionListView()
                .modifier(RootViewAppearance())
                .modelContainer(env.modelContainer)
                .inject(env.diContainer)
        case .failed(let error):
            errorView(error)
        }
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text("Unable to load database")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry") { bootstrap() }
        }
    }

    private func bootstrap() {
        let cancelBag = CancelBag()
        launchState.setIsLoading(cancelBag: cancelBag)
        let task = Task {
            do {
                launchState = .loaded(try await AppEnvironment.bootstrap())
            } catch {
                launchState = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }
}
```

**Note:** `RootView.bootstrap()` uses the manual `Task` + `Loadable` pattern (same as `AddExerciseViewModel.save()`) since `$launchState.load {}` requires a `Binding` and `@State` in a top-level view is acceptable here. However, for consistency with the ViewModel approach, we use the explicit pattern.

#### AppDelegate / MainApp simplification

`AppDelegate` no longer holds the environment. `@UIApplicationDelegateAdaptor` is retained in `MainApp` so that `AppDelegate` can still handle `UIApplicationDelegate` lifecycle hooks if needed in the future, but it becomes a minimal shell. `MainApp.body` renders `RootView()`:

```swift
@main
struct MainApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.isRunningTests {
                Text("Running unit tests")
            } else {
                RootView()
            }
        }
    }
}
```

`AppDelegate` is simplified to:

```swift
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
}
```

### 4. CancelBag Fix

```swift
func cancel() {
    subscriptions.forEach { $0.cancel() }
    subscriptions.removeAll()
}
```

One-line change. Tasks stored via `task.store(in: cancelBag)` will now receive cooperative cancellation.

### 5. Loadable Error Equality Fix

```swift
case let (.failed(lhsE), .failed(rhsE)):
    let lhs = lhsE as NSError
    let rhs = rhsE as NSError
    return lhs.domain == rhs.domain && lhs.code == rhs.code
```

Uses stable error identity (domain + code) instead of user-facing description string. Different errors will correctly trigger re-renders even if they share the same localized message.

---

## Files Changed

| File | Change |
|---|---|
| `UI/SessionList/SessionListViewModel.swift` | **New** — `@Observable` VM |
| `UI/SessionList/SessionListView.swift` | Refactor to use VM |
| `UI/SessionDetail/SessionDetailViewModel.swift` | **New** — `@Observable` VM |
| `UI/SessionDetail/SessionDetailView.swift` | Refactor to use VM |
| `UI/AddExercise/AddExerciseViewModel.swift` | **New** — `@Observable` VM |
| `UI/AddExercise/AddExerciseView.swift` | Refactor to use VM |
| `Repositories/Models/StrengthExercise.swift` | Add `#Index` on `name` |
| `Repositories/Models/CardioExercise.swift` | Add `#Index` on `name` |
| `DependencyInjection/AppEnvironment.swift` | Make `bootstrap()` async throws |
| `Core/App.swift` | Simplify to use `RootView` |
| `Core/AppDelegate.swift` | Remove environment ownership |
| `UI/RootView.swift` | **New** — launch state + error recovery |
| `Utilities/CancelBag.swift` | Fix `cancel()` |
| `Utilities/Loadable.swift` | Fix error equality |

## Files NOT Changed

| File | Reason |
|---|---|
| `UI/ExerciseProgress/ExerciseProgressView.swift` | Already clean |
| `UI/Common/ErrorView.swift` | Reused as-is |
| `UI/Common/Query+Search.swift` | Not involved |
| `Interactors/WorkoutsInteractor.swift` | No API changes |
| `Repositories/Database/WorkoutsDBRepository.swift` | No changes (indexes are on models) |
| `Repositories/Models/AppSchema.swift` | No changes (lightweight index migration is automatic) |
| `Repositories/Database/ModelContainer.swift` | No changes (no migration plan to wire) |
| `DependencyInjection/DIContainer.swift` | No changes (`ModelContainer.stub` and `@Entry` default remain) |

## Test Impact

- **New unit tests** for `SessionListViewModel`, `SessionDetailViewModel`, `AddExerciseViewModel` — test the computation logic (grouping, filtering, save coordination) without SwiftUI or SwiftData. VMs are plain `@Observable` classes, so tests just call methods and assert stored properties.
- **Update existing UI tests** — views now delegate to VMs; inject mock interactor via `vm.configure(interactor:)` instead of only through DI container.
- **New UI test** for `RootView` — include `Inspection` hook for ViewInspector consistency with existing test patterns. Test loading, loaded, and failed states.
- **Existing repository tests** — unaffected.
- **Loadable tests** — update error equality assertions.

## Out of Scope

- Exercise type refactoring (separate future effort)
- Adding new features or UI changes beyond error recovery screen
- Networking layer
- `Query+Search.swift` changes
