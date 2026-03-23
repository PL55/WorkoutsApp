# WorkoutsApp - Project Overview

A personal workout tracking iOS app built with Clean Architecture and SwiftUI. Users can log workout sessions with strength and cardio exercises, track progress over time, and browse an exercise library.

**Platform**: iOS 18.0+, macOS 12.0+ (iOS-primary; macOS has UIKit limitations)
**Language**: Swift 5 (language mode), Swift 6.1 toolchain
**UI Framework**: SwiftUI + Combine
**Architecture**: Clean Architecture (four-layer: View → ViewModel → Interactor → Repository)
**Persistence**: SwiftData (fully local, no network layer)

---

## Architecture Overview

```
┌─────────────────────────────────────────┐
│         LAUNCH LAYER                    │
│                                         │
│  RootView (Loadable<AppEnvironment>)    │
│  AppEnvironment.bootstrap() async       │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│       PRESENTATION LAYER                │
│   (SwiftUI Views + @Query)              │
│                                         │
│  SessionListView, SessionDetailView     │
│  AddExerciseView, ExerciseProgressView  │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│        VIEWMODEL LAYER                  │
│   (@Observable @MainActor classes)      │
│                                         │
│  SessionListViewModel                   │
│  SessionDetailViewModel                 │
│  AddExerciseViewModel                   │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      BUSINESS LOGIC LAYER               │
│         (Interactors)                   │
│                                         │
│  WorkoutsInteractor                     │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│       DATA ACCESS LAYER                 │
│        (Repositories)                   │
│                                         │
│  WorkoutsDBRepository (SwiftData)       │
└─────────────────────────────────────────┘
```

### Note on @Query in Views

Views use SwiftData's `@Query` macro directly for list data (sessions, exercises). This is a pragmatic deviation from strict Clean Architecture — it bypasses the repository layer for read operations. Write/delete operations still go through the ViewModel → Interactor → Repository path. The `Query+Search.swift` helper provides a `.query()` modifier for searchable `@Query` bindings.

### Note on ExerciseProgressView

`ExerciseProgressView` has no ViewModel — it is already clean (`Loadable` + `onAppear`, no computation in body). It uses `$progressState.load { }` directly since it remains a `@State`-owned `Binding<Loadable<T>>`.

---

## Layer Breakdown

### Launch Layer

**`RootView`** owns the entire bootstrap sequence as a `Loadable<AppEnvironment>` state machine:

- `.notRequested` / `.isLoading` → shows `ProgressView("Loading...")`
- `.loaded(env)` → renders `SessionListView` with real `modelContainer` and `DIContainer` injected
- `.failed(error)` → shows an error screen with a **Retry** button that re-runs `bootstrap()`

This eliminates the previous silent fallback: if `ModelContainer` creation fails, the user sees an error with a recovery path instead of silently getting an in-memory stub (and losing all data).

### Presentation Layer (`UI/`)

SwiftUI views that are pure functions of state. Views own `@Query` for raw SwiftData results, pass those results into their ViewModel via `onChange`, and read computed/cached state back from the VM.

- `RootView` — Launch state machine; shown before `SessionListView` is rendered
- `SessionListView` — Main list; uses `@Query` for `WorkoutSession`; delegates grouping + delete to `SessionListViewModel`
- `SessionDetailView` — Shows all exercises in a session; delegates exercise list merging + delete to `SessionDetailViewModel`
- `AddExerciseView` — Form for adding strength or cardio exercises; delegates suggestions, form state, and save to `AddExerciseViewModel`
- `ExerciseProgressView` — Historical progress entries; warns if exercise logged as both types; uses `Loadable<[ProgressEntry]>` directly (no VM)
- `SessionCell` / `ExerciseRow` — Simple display components
- `ErrorView` — Reusable error display with retry action
- `RootViewModifier` — Root-level appearance configuration (navigation bar, accent color)

### ViewModel Layer (`UI/<Feature>/`)

`@Observable @MainActor` classes that own all computed/derived state and interactor calls. Views hold VMs via `@State`.

**Initialization pattern:** `@Environment` is not available at `@State` init time. VMs are initialized with `StubWorkoutsInteractor` as a placeholder and receive the real interactor via `configure(interactor:)` called from `.onAppear`.

```swift
// All three VMs follow this pattern:
@State private var vm = SessionListViewModel()

.onAppear { vm.configure(interactor: injected.interactors.workouts) }
```

**Loadable in ViewModels:** The `$binding.load { }` helper requires a `Binding<Loadable<T>>` which is not available inside `@Observable` classes. VMs use an explicit `Task + Loadable` pattern instead:

```swift
func save() {
    let cancelBag = CancelBag()
    saveState.setIsLoading(cancelBag: cancelBag)
    let task = Task { [weak self] in
        guard let self else { return }
        do { saveState = .loaded(try await interactor.addExercise(...)) }
        catch { saveState = .failed(error) }
    }
    task.store(in: cancelBag)
}
```

| ViewModel | Owns | Exposes |
|---|---|---|
| `SessionListViewModel` | Interactor ref | `groupedSessions: [(key: Date, value: [WorkoutSession])]` |
| `SessionDetailViewModel` | Interactor ref | `allExercises: [any AnalyticsTrackable]` |
| `AddExerciseViewModel` | Interactor ref, `sessionID`, form fields | `filteredSuggestions`, `saveState: Loadable<UUID>` |

### Business Logic Layer (`Interactors/`)

**Protocol**: `WorkoutsInteractor`
```swift
protocol WorkoutsInteractor {
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID
    func deleteSession(id: UUID) async throws
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
}
```

**Implementation**: `RealWorkoutsInteractor` — coordinates between `WorkoutsDBRepository` and caching (`ExerciseLibraryEntry`).

**Stub**: `StubWorkoutsInteractor` — no-op implementation for SwiftUI previews and VM initialization.

Key principles:
- Protocol-based for testability
- Coordinates between repositories
- `progressEntries` returns data directly (used locally by one view, not stored in AppState)

### Data Access Layer (`Repositories/`)

**Protocol**: `WorkoutsDBRepository`
```swift
protocol WorkoutsDBRepository {
    func addSession() async throws -> WorkoutSession
    func deleteSession(_ session: WorkoutSession) async throws
    func addStrengthExercise(_ input: ExerciseInput.Strength, to session: WorkoutSession) async throws
    func addCardioExercise(_ input: ExerciseInput.Cardio, to session: WorkoutSession) async throws
    func deleteExercise(_ input: ExerciseInput) async throws
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
    func saveExerciseLibraryEntry(name: String, type: ExerciseType) async throws
    func exerciseLibraryEntries() async throws -> [ExerciseLibraryEntry]
}
```

**Implementation**: `MainDBRepository` — `@ModelActor` wrapping `ModelContext` for thread-safe SwiftData access.

No web/network repositories — this app is fully local.

---

## Core Components

### AppState (`Core/AppState.swift`)

Minimal Redux-like state — only routing, no data state (SwiftData + `@Query` handles data):

```swift
struct AppState: Equatable {
    var routing = ViewRouting()
}

struct ViewRouting: Equatable {
    var sessionList = SessionList.Routing()
}
```

### Store<State> (`Utilities/Store.swift`)

```swift
typealias Store<State> = CurrentValueSubject<State, Never>
```

Extensions provide subscript access, Binding dispatchers, and publisher updates for reactive two-way data flow.

### Loadable<T> (`Utilities/Loadable.swift`)

State machine for async operations with UI feedback:

```swift
enum Loadable<T> {
    case notRequested
    case isLoading(last: T?, cancelBag: CancelBag)
    case loaded(T)
    case failed(Error)
}
```

- `LoadableSubject` extension adds `.load { }` for triggering async work from a `Binding<Loadable<T>>` (used in views, not VMs)
- `isLoading: Bool` computed property on `Loadable` for binding to UI disabled states
- Error equality uses `(NSError.domain, NSError.code)` — stable identity that correctly triggers SwiftUI re-renders even when two different errors share the same `localizedDescription`

### CancelBag (`Utilities/CancelBag.swift`)

Manages `Cancellable` subscriptions and `Task` references. `cancel()` calls `.cancel()` on every stored item before removing references, ensuring cooperative cancellation is actually delivered to stored tasks.

### DIContainer (`DependencyInjection/DIContainer.swift`)

```swift
struct DIContainer {
    let appState: Store<AppState>
    let interactors: Interactors
}

struct Interactors {
    let workouts: WorkoutsInteractor
}
```

Injected via SwiftUI `@Environment`:

```swift
extension EnvironmentValues {
    @Entry var injected: DIContainer = .stub
}
```

Views access it with `@Environment(\.injected) var injected`.

### AppEnvironment (`DependencyInjection/AppEnvironment.swift`)

Async bootstrap factory — creates the real `ModelContainer`, `MainDBRepository`, `RealWorkoutsInteractor`, and `DIContainer`. Runs off `@MainActor` so the main thread is not blocked during app launch. Errors propagate to `RootView` for display; there is no silent fallback.

```swift
static func bootstrap() async throws -> AppEnvironment
```

---

## Data Models (`Repositories/Models/`)

All persistence models use SwiftData `@Model`:

| Model | Description |
|---|---|
| `WorkoutSession` | A single workout; has relationships to `StrengthExercise` and `CardioExercise` (cascade delete) |
| `StrengthExercise` | Sets/reps/weight; `analyticsValue` = sets × reps × weight (volume); indexed on `name` |
| `CardioExercise` | Duration-based; `analyticsValue` = duration; indexed on `name` |
| `ExerciseLibraryEntry` | Unique exercise name + type; auto-saved when user adds an exercise |
| `ProgressEntry` | Non-persisted struct; captures historical analytics for charting |
| `AppSchema` | Schema version definition (v1.0.0); lists all `@Model` classes |

### SwiftData Indexes

`StrengthExercise` and `CardioExercise` both declare a `#Index` on their `name` property, eliminating full-table scans in `progressEntries` queries as data grows:

```swift
@Model final class StrengthExercise {
    #Index<StrengthExercise>([\.name])
    // ...
}
```

Adding `#Index` is a lightweight schema change — SwiftData handles it automatically on next store open, with no `VersionedSchema` or `SchemaMigrationPlan` required.

### Key Protocols (`Utilities/Helpers.swift`)

```swift
protocol Exercise: AnyObject {
    var id: PersistentIdentifier { get }
    var name: String { get }
    var exerciseType: ExerciseType { get }
}

protocol AnalyticsTrackable: Exercise {
    var analyticsValue: Double { get }
    var analyticsLabel: String { get }
}
```

Both `StrengthExercise` and `CardioExercise` conform to `AnalyticsTrackable`, enabling polymorphic display in `SessionDetailView` via `vm.allExercises: [any AnalyticsTrackable]`.

### ExerciseType (`Utilities/ExerciseType.swift`)

```swift
enum ExerciseType: String, Codable, CaseIterable, Hashable {
    case strength
    case cardio
}
```

### ExerciseInput (`Utilities/ExerciseInput.swift`)

Input enum for creating exercises passed from ViewModel → Interactor → Repository:

```swift
enum ExerciseInput {
    case strength(Strength)
    case cardio(Cardio)
}
```

---

## Data Flow

### App Launch

1. `App.swift` renders `RootView` (or `Text("Running unit tests")` in test mode)
2. `RootView.bootstrap()` fires; `launchState` transitions `notRequested → isLoading`
3. `AppEnvironment.bootstrap()` runs async: creates `ModelContainer`, `MainDBRepository`, `RealWorkoutsInteractor`, `DIContainer`
4. On success: `launchState → .loaded(env)`; `SessionListView` is rendered with real container + DI injected
5. On failure: `launchState → .failed(error)`; error screen with Retry button shown

### Adding an Exercise

1. User fills out form in `AddExerciseView` (form fields bound to `vm`)
2. User taps Save → `vm.save()` called
3. VM builds `ExerciseInput`, sets `saveState = .isLoading`, fires a `Task`
4. `RealWorkoutsInteractor.addExercise(to:input:)` called
5. `MainDBRepository` inserts into `ModelContext`
6. SwiftData notifies `@Query` in `SessionDetailView`; VM's `updateExercises` called via `onChange`
7. UI re-renders automatically via `@Observable`

### Viewing Progress

1. `ExerciseProgressView` appears (`onAppear`)
2. View triggers `$progressState.load { }` on a `Binding<Loadable<[ProgressEntry]>>`
3. Interactor calls `dbRepository.progressEntries(for: name)`
4. `MainDBRepository` queries SwiftData (indexed on `name`)
5. Returns `[ProgressEntry]` directly (local view state, not AppState)
6. `Loadable` transitions: `notRequested → isLoading → loaded`

### Navigation / Routing

1. Routing state stored in `AppState.routing.sessionList`
2. Views observe routing via Combine publishers on `Store<AppState>`
3. `NavigationPath` driven by routing state
4. `Binding` dispatchers sync local routing state back to `AppState`

---

## File Organization

```
WorkoutsApp/
├── Core/
│   ├── App.swift                    # @main entry point; renders RootView
│   ├── AppDelegate.swift            # Minimal UIApplicationDelegate shell
│   └── AppState.swift               # Centralized app state (routing only)
├── DependencyInjection/
│   ├── DIContainer.swift            # DI container + @Environment entry
│   └── AppEnvironment.swift         # Async bootstrap factory (throws on failure)
├── Interactors/
│   └── WorkoutsInteractor.swift     # Protocol + Real + Stub implementations
├── Repositories/
│   ├── Database/
│   │   ├── WorkoutsDBRepository.swift  # Protocol + MainDBRepository (@ModelActor)
│   │   └── ModelContainer.swift        # ModelContainer factory + mock support
│   └── Models/
│       ├── WorkoutSession.swift
│       ├── StrengthExercise.swift       # #Index on name
│       ├── CardioExercise.swift         # #Index on name
│       ├── ExerciseLibraryEntry.swift
│       ├── ProgressEntry.swift          # Non-persisted struct
│       └── AppSchema.swift              # SwiftData schema version
├── UI/
│   ├── RootView.swift               # Launch state machine + error recovery
│   ├── SessionList/
│   │   ├── SessionListView.swift
│   │   ├── SessionListViewModel.swift   # @Observable groupedSessions + delete
│   │   └── SessionCell.swift
│   ├── SessionDetail/
│   │   ├── SessionDetailView.swift
│   │   ├── SessionDetailViewModel.swift # @Observable allExercises + delete
│   │   └── ExerciseRow.swift
│   ├── AddExercise/
│   │   ├── AddExerciseView.swift
│   │   └── AddExerciseViewModel.swift   # @Observable form state + save + suggestions
│   ├── ExerciseProgress/
│   │   └── ExerciseProgressView.swift   # No VM — already clean
│   ├── Common/
│   │   ├── ErrorView.swift
│   │   └── Query+Search.swift           # .query() modifier for searchable @Query
│   └── RootViewModifier.swift
└── Utilities/
    ├── Store.swift                      # CurrentValueSubject alias + extensions
    ├── Loadable.swift                   # Async state machine + isLoading helper
    ├── CancelBag.swift                  # Task/Cancellable management (cancel() fixed)
    ├── ExerciseType.swift
    ├── ExerciseInput.swift
    └── Helpers.swift                    # Protocols, extensions, Inspection helper

UnitTests/
├── TestHelpers.swift
├── Mocks/
│   ├── Mock.swift                       # Mock protocol + MockActions
│   ├── MockedInteractors.swift          # MockedWorkoutsInteractor
│   ├── MockedDBRepositories.swift       # MockedWorkoutsDBRepository
│   └── Interactors/
│       └── WorkoutsInteractorTests.swift
├── Repositories/
│   └── WorkoutsDBRepositoryTests.swift
├── UI/
│   ├── RootViewTests.swift              # Loadable launch state transitions
│   ├── SessionListTests.swift
│   ├── SessionListViewModelTests.swift  # groupedSessions grouping + delete
│   ├── SessionDetailViewTests.swift
│   ├── SessionDetailViewModelTests.swift # allExercises merge + delete
│   ├── AddExerciseViewTests.swift
│   ├── AddExerciseViewModelTests.swift  # suggestions filter + save state
│   ├── ExerciseProgressViewTests.swift
│   └── RootViewAppearanceTests.swift
└── Utilities/
    ├── LoadableTests.swift
    └── HelpersTests.swift
```

---

## Testing Strategy

### Unit Tests — ViewModels

Plain `@Observable` classes tested without SwiftUI or SwiftData. Inject `MockedWorkoutsInteractor` directly via `vm.configure(interactor:)`.

```swift
@Test func groupsSessionsByDay() async throws {
    let vm = SessionListViewModel()
    vm.configure(interactor: MockedWorkoutsInteractor())
    vm.sessionsDidChange([session1, session2])
    #expect(vm.groupedSessions.count == 2)
}
```

### Unit Tests — Interactors

Use `MockedWorkoutsDBRepository` (implements `Mock` protocol) to verify the interactor calls the correct repository methods with correct arguments.

```swift
mockedRepo.actions = .init(expected: [.addStrengthExercise(...)])
try await interactor.addExercise(to: sessionID, input: input)
mockedRepo.verify()
```

### Integration Tests — Repositories

Use a real `ModelContainer.mock` (in-memory SwiftData store) — no mocking at the persistence level.

### UI Tests — ViewInspector

Views are tested with `ViewInspector` for async UI state transitions. The `Inspection` helper in `Helpers.swift` bridges ViewInspector's `InspectionEmissary` protocol. VMs are injected at init via the `init(sessionID:viewModel:)` overload where applicable.

### Test Pattern

- Mocks track actions via `MockActions<Action>`
- Each mock method appends the action and returns a pre-configured `Result`
- `verify()` asserts expected == actual actions
- Swift Testing framework (`@Suite`, `@Test`, `#expect`) — **not** XCTest

---

## Common Patterns

### ViewModel Configure Pattern

```swift
// In View:
@State private var vm = SessionListViewModel()

.onAppear { vm.configure(interactor: injected.interactors.workouts) }
.onChange(of: sessions, initial: true) { vm.sessionsDidChange(sessions) }

// In body — reads cached/computed state, no recomputation:
ForEach(vm.groupedSessions, id: \.key) { ... }
```

### Manual Task + Loadable Pattern (inside @Observable VMs)

```swift
func save() {
    let cancelBag = CancelBag()
    saveState.setIsLoading(cancelBag: cancelBag)
    let task = Task { [weak self] in
        guard let self else { return }
        do { saveState = .loaded(try await interactor.addExercise(...)) }
        catch { saveState = .failed(error) }
    }
    task.store(in: cancelBag)
}
```

### Loadable Loading Pattern (in Views with @State)

```swift
// In View — still valid for ExerciseProgressView and RootView bootstrap:
@State private var progressState: Loadable<[ProgressEntry]> = .notRequested

$progressState.load {
    try await injected.interactors.workouts.progressEntries(for: exerciseName)
}
```

### Routing / Navigation Pattern

```swift
// Observe AppState routing
private var routingUpdate: AnyPublisher<SessionList.Routing, Never> {
    injected.appState.updates(for: \.routing.sessionList)
}

.onReceive(routingUpdate) { self.routingState = $0 }

// Dispatch local state back to AppState
private var routingBinding: Binding<SessionList.Routing> {
    $routingState.dispatched(to: injected.appState, \.routing.sessionList)
}
```

### @Query with Search

```swift
.query(searchText: searchText, results: $sessions) { search in
    Query(filter: #Predicate<WorkoutSession> { session in
        search.isEmpty || session.name.localizedStandardContains(search)
    }, sort: \WorkoutSession.date, order: .reverse)
}
```

---

## Building the Project

### Prerequisites

- Xcode 16.0+
- iOS 18.0+ simulator or device

### Build

```bash
open WorkoutsApp.xcodeproj
# Select iOS Simulator (or paired device) → Cmd+R
```

Xcode fetches SPM dependencies automatically:
- `ViewInspector` 0.10.0+

### Run Tests

```bash
# Xcode
Cmd+U

# CLI
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Troubleshooting

**SwiftData migration errors**: Delete app from simulator, clean build folder (`Cmd+Shift+K`), rebuild.

**"No such module 'ViewInspector'"**: File → Packages → Reset Package Caches.

**macOS build fails with UIKit error**: Select an iOS Simulator destination. The project declares macOS support in `Package.swift` but has UIKit dependencies.

**Build fails on device but succeeds on simulator**: Check `Signing & Capabilities` tab — ensure a Team is selected and the provisioning profile has no warning icons. Also verify the device is running iOS 18.0+.

---

## Design Decisions

### Why ViewModels alongside @Query?

`@Query` results in SwiftUI views change on every SwiftData write, triggering a view body re-evaluation. Operations like grouping sessions by day or merging two exercise arrays were computed inline in the view body — meaning they ran on every render, not just when their inputs changed.

`@Observable` ViewModels break this coupling: the view passes raw `@Query` results into the VM via `onChange`, and the VM recomputes only when its input actually changes. The view body then reads a cached stored property — no recomputation on unrelated renders.

### Why not put @Query inside the ViewModel?

`@Query` is a SwiftUI property wrapper — it requires a View context and cannot be used inside an `@Observable` class. The view must own `@Query` and forward results to the VM. This is the correct boundary: SwiftData observation lives in the view layer, derived state lives in the VM.

### Why async bootstrap?

The previous `AppEnvironment` ran `ModelContainer` creation synchronously on `@MainActor`, holding the main thread during file I/O. Moving `bootstrap()` to `async throws` lets the main thread stay responsive while the store opens. The `RootView` `ProgressView` is shown during this window.

### Why surface bootstrap errors instead of falling back to in-memory?

A silent fallback to an in-memory `ModelContainer` means the app appears to work, but all user data is invisible. The user may add sessions that vanish on next launch. Surfacing the error with a Retry button is honest and gives the user (or developer) a recovery path.

### Why (domain, code) for Loadable error equality?

`localizedDescription` is a user-facing string. Two different underlying errors can produce the same description (e.g., both show "The operation couldn't be completed"), causing SwiftUI to skip re-renders when the error changes. Using `NSError.domain + NSError.code` provides stable, unique error identity.

### Why configure(interactor:) instead of init(interactor:)?

`@State` property wrappers are initialized before the view's `@Environment` is available, so `@State private var vm = SessionListViewModel(interactor: injected.interactors.workouts)` would crash. The `configure(interactor:)` pattern defers injection to `.onAppear` when the environment is fully wired.

---

## Questions to Ask When Modifying

- [ ] Which layer does this belong to? (View / ViewModel / Interactor / Repository)
- [ ] Should this be a repository operation or can the view use `@Query` directly?
- [ ] Is there derived/computed state that should live in the ViewModel instead of the view body?
- [ ] Does this need `Loadable` for async UI feedback?
- [ ] Am I in a View (`$binding.load {}`) or a ViewModel (manual `Task + Loadable`)?
- [ ] Should the result go to `AppState` (app-wide) or stay local to the view/VM?
- [ ] Do I need to update the protocol AND the real implementation AND the mock/stub?
- [ ] Should this data be cached in `ExerciseLibraryEntry`?
- [ ] Is there a corresponding test for this change?
- [ ] Have I added `[weak self]` in Task closures inside ViewModels to avoid retain cycles?
