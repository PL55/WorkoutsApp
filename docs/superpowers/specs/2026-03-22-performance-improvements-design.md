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

#### SessionListViewModel

```swift
@Observable
final class SessionListViewModel {
    private(set) var groupedSessions: [(key: Date, value: [WorkoutSession])] = []
    private let interactor: any WorkoutsInteractor

    init(interactor: any WorkoutsInteractor) {
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
- `SessionListView` creates `@State private var vm: SessionListViewModel` initialized with the interactor from the DI container.
- Uses `.onChange(of: sessions)` to call `vm.sessionsDidChange(sessions)`.
- Body reads `vm.groupedSessions` (a stored property, no recomputation).

#### SessionDetailViewModel

```swift
@Observable
final class SessionDetailViewModel {
    private(set) var allExercises: [any AnalyticsTrackable] = []
    private let interactor: any WorkoutsInteractor

    init(interactor: any WorkoutsInteractor) {
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
- `SessionDetailView` creates the VM at init.
- Calls `vm.updateExercises(strength:cardio:)` in `onAppear` and `onChange` of the session's exercise arrays.
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

    private let interactor: any WorkoutsInteractor
    private let sessionID: UUID?

    init(interactor: any WorkoutsInteractor, sessionID: UUID?) {
        self.interactor = interactor
        self.sessionID = sessionID
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
        $saveState.load {
            try await interactor.addExercise(to: sessionID, input: input)
        }
    }
}
```

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

### 2. SwiftData Indexes + Schema Migration

#### Index annotations

Add `@Attribute(.index)` to the `name` property on both exercise models:

```swift
// StrengthExercise.swift
@Attribute(.index) var name: String

// CardioExercise.swift
@Attribute(.index) var name: String
```

#### Schema versioning

- Rename current `AppSchema` to `AppSchemaV1`
- Create `AppSchemaV2` with the indexed models
- Create `AppMigrationPlan` with a lightweight migration stage from V1 to V2
- Wire the migration plan into `ModelContainer` configuration

```swift
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [WorkoutSession.self, StrengthExercise.self, CardioExercise.self, ExerciseLibraryEntry.self]
    }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] {
        [WorkoutSession.self, StrengthExercise.self, CardioExercise.self, ExerciseLibraryEntry.self]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)]
    }
}
```

#### ModelContainer update

Pass the migration plan to `ModelContainer`:

```swift
static func appModelContainer(inMemoryOnly: Bool = false, isStub: Bool = false) throws -> ModelContainer {
    let schema = AppSchemaV2.schema
    let config = ModelConfiguration(isStub ? "stub" : nil, schema: schema, isStoredInMemoryOnly: inMemoryOnly)
    return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [config])
}
```

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

    var body: some View {
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
        $launchState.load {
            try await AppEnvironment.bootstrap()
        }
    }
}
```

#### AppDelegate / MainApp simplification

`AppDelegate` no longer holds the environment. `MainApp.body` just renders `RootView()`. The `isRunningTests` check moves into `RootView` or stays in `MainApp`:

```swift
@main
struct MainApp: App {
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

`AppDelegate` can be retained if needed for other `UIApplicationDelegate` hooks, but it no longer owns `AppEnvironment`.

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
| `Repositories/Models/StrengthExercise.swift` | Add `@Attribute(.index)` on `name` |
| `Repositories/Models/CardioExercise.swift` | Add `@Attribute(.index)` on `name` |
| `Repositories/Models/AppSchema.swift` | Versioned schemas + migration plan |
| `Repositories/Database/ModelContainer.swift` | Wire migration plan |
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

## Test Impact

- **New unit tests** for `SessionListViewModel`, `SessionDetailViewModel`, `AddExerciseViewModel` — test the computation logic (grouping, filtering, save coordination) without SwiftUI or SwiftData.
- **Update existing UI tests** — views now delegate to VMs; mocking approach changes slightly (inject mock interactor into VM instead of via DI container in some cases).
- **Existing repository tests** — unaffected. Schema migration should be tested with a migration test using the versioned schemas.
- **Loadable tests** — update error equality assertions.

## Out of Scope

- Exercise type refactoring (separate future effort)
- Adding new features or UI changes beyond error recovery screen
- Networking layer
- `Query+Search.swift` changes
