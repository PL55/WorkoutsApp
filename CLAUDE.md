# WorkoutsApp - Project Overview

A personal workout tracking iOS app built with Clean Architecture and SwiftUI. Users can log workout sessions with strength and cardio exercises, track progress over time, and browse an exercise library.

**Platform**: iOS 18.0+, macOS 12.0+ (iOS-primary; macOS has UIKit limitations)
**Language**: Swift 5 (language mode), Swift 6.1 toolchain
**UI Framework**: SwiftUI + Combine
**Architecture**: Clean Architecture (three-layer)
**Persistence**: SwiftData

---

## Architecture Overview

```
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

Views use SwiftData's `@Query` macro directly for list data (sessions, exercises). This is a pragmatic deviation from strict Clean Architecture — it bypasses the repository layer for read operations. Write/delete operations still go through the Interactor → Repository path. The `Query+Search.swift` helper provides a `.query()` modifier for searchable @Query bindings.

---

## Layer Breakdown

### Presentation Layer (`UI/`)

SwiftUI views that are pure functions of state. Side effects are triggered by user actions or `onAppear` and forwarded to Interactors.

- `SessionListView` — Main list grouped by date; uses `@Query` for `WorkoutSession`; pull-to-refresh; delete sessions; navigates to detail/add/progress
- `SessionDetailView` — Shows all exercises in a session (strength + cardio unified via `AnalyticsTrackable`); delete exercises; navigate to progress
- `AddExerciseView` — Form for adding strength or cardio exercises; segmented picker for type; suggests from exercise library; uses `Loadable<UUID>` for save state
- `ExerciseProgressView` — Historical progress entries for an exercise name; warns if exercise logged as both types; uses `Loadable<[ProgressEntry]>`
- `SessionCell` / `ExerciseRow` — Simple display components
- `ErrorView` — Reusable error display with retry action
- `RootViewModifier` — Root-level appearance configuration

### Business Logic Layer (`Interactors/`)

**Protocol**: `WorkoutsInteractor`
```swift
protocol WorkoutsInteractor {
    func addExercise(_ input: ExerciseInput, to session: WorkoutSession) async throws
    func deleteSession(_ session: WorkoutSession) async throws
    func deleteExercise(_ input: ExerciseInput) async throws
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
}
```

**Implementation**: `RealWorkoutsInteractor` — coordinates between `WorkoutsDBRepository` and caching (`ExerciseLibraryEntry`).

**Stub**: `StubWorkoutsInteractor` — no-op implementation for SwiftUI previews and tests.

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

Minimal Redux-like state — only routing, no data state (SwiftData + @Query handles data):

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

`LoadableSubject` extension adds `.load { }` for triggering async work from a `Binding<Loadable<T>>`.

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

`@MainActor` bootstrap factory — creates the real `ModelContainer`, `MainDBRepository`, `RealWorkoutsInteractor`, and `DIContainer`. Called once at app startup from `AppDelegate`.

---

## Data Models (`Repositories/Models/`)

All persistence models use SwiftData `@Model`:

| Model | Description |
|---|---|
| `WorkoutSession` | A single workout; has relationships to `StrengthExercise` and `CardioExercise` (cascade delete) |
| `StrengthExercise` | Sets/reps/weight; `analyticsValue` = sets × reps × weight (volume) |
| `CardioExercise` | Duration-based; `analyticsValue` = duration |
| `ExerciseLibraryEntry` | Unique exercise name + type; auto-saved when user adds an exercise |
| `ProgressEntry` | Non-persisted struct; captures historical analytics for charting |
| `AppSchema` | Schema version definition (v1.0.0); lists all `@Model` classes |

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

Both `StrengthExercise` and `CardioExercise` conform to `AnalyticsTrackable`, enabling polymorphic display in `SessionDetailView`.

### ExerciseType (`Utilities/ExerciseType.swift`)

```swift
enum ExerciseType: String, Codable, CaseIterable, Hashable {
    case strength
    case cardio
}
```

### ExerciseInput (`Utilities/ExerciseInput.swift`)

Input enum for creating exercises passed from View → Interactor → Repository:

```swift
enum ExerciseInput {
    case strength(Strength)
    case cardio(Cardio)
}
```

---

## Data Flow

### Adding an Exercise

1. User fills out form in `AddExerciseView`
2. View calls `injected.interactors.workouts.addExercise(input, to: session)`
3. `RealWorkoutsInteractor` calls `dbRepository.addStrengthExercise()` or `addCardioExercise()`
4. `MainDBRepository` inserts into `ModelContext`
5. SwiftData notifies `@Query` in `SessionDetailView`
6. UI re-renders automatically

### Viewing Progress

1. `ExerciseProgressView` appears (`onAppear`)
2. View triggers `Loadable.load { }` on a `Binding<Loadable<[ProgressEntry]>>`
3. Interactor calls `dbRepository.progressEntries(for: name)`
4. `MainDBRepository` queries SwiftData for historical data
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
│   ├── App.swift                    # @main entry point
│   ├── AppDelegate.swift            # UIApplicationDelegate; bootstraps AppEnvironment
│   └── AppState.swift               # Centralized app state (routing only)
├── DependencyInjection/
│   ├── DIContainer.swift            # DI container + @Environment entry
│   └── AppEnvironment.swift         # Bootstrap factory (@MainActor)
├── Interactors/
│   └── WorkoutsInteractor.swift     # Protocol + Real + Stub implementations
├── Repositories/
│   ├── Database/
│   │   ├── WorkoutsDBRepository.swift  # Protocol + MainDBRepository (@ModelActor)
│   │   └── ModelContainer.swift        # ModelContainer factory + mock support
│   └── Models/
│       ├── WorkoutSession.swift
│       ├── StrengthExercise.swift
│       ├── CardioExercise.swift
│       ├── ExerciseLibraryEntry.swift
│       ├── ProgressEntry.swift          # Non-persisted struct
│       └── AppSchema.swift              # SwiftData schema version
├── UI/
│   ├── SessionList/
│   │   ├── SessionListView.swift
│   │   └── SessionCell.swift
│   ├── SessionDetail/
│   │   ├── SessionDetailView.swift
│   │   └── ExerciseRow.swift
│   ├── AddExercise/
│   │   └── AddExerciseView.swift
│   ├── ExerciseProgress/
│   │   └── ExerciseProgressView.swift
│   ├── Common/
│   │   ├── ErrorView.swift
│   │   └── Query+Search.swift          # .query() modifier for searchable @Query
│   └── RootViewModifier.swift
└── Utilities/
    ├── Store.swift                      # CurrentValueSubject alias + extensions
    ├── Loadable.swift                   # Async state machine
    ├── CancelBag.swift                  # Task/Cancellable management
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
│   ├── SessionListTests.swift
│   ├── SessionDetailViewTests.swift
│   ├── AddExerciseViewTests.swift
│   ├── ExerciseProgressViewTests.swift
│   └── RootViewAppearanceTests.swift
└── Utilities/
    ├── LoadableTests.swift
    └── HelpersTests.swift
```

---

## Testing Strategy

### Unit Tests — Interactors

Use `MockedWorkoutsDBRepository` (implements `Mock` protocol) to verify interactor calls the correct repository methods with correct arguments.

```swift
// MockActions tracks expected vs actual calls
mockedRepo.actions = .init(expected: [.addStrengthExercise(...)])
try await interactor.addExercise(input, to: session)
mockedRepo.verify()
```

### Integration Tests — Repositories

Use a real `ModelContainer.mock` (in-memory SwiftData store) — no mocking at the persistence level.

### UI Tests — ViewInspector

Views are tested with `ViewInspector` for async UI state transitions. The `Inspection` helper in `Helpers.swift` bridges ViewInspector's `InspectionEmissary` protocol.

### Test Pattern

- Mocks track actions via `MockActions<Action>`
- Each mock method appends the action and returns a pre-configured `Result`
- `verify()` asserts expected == actual actions

---

## Common Patterns

### Loadable Loading Pattern

```swift
// In View
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
# Select iOS Simulator → Cmd+R
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

---

## Questions to Ask When Modifying

- [ ] Which layer does this belong to? (View / Interactor / Repository)
- [ ] Should this be a repository operation or can the view use `@Query` directly?
- [ ] Does this need `Loadable` for async UI feedback?
- [ ] Should the result go to `AppState` (app-wide) or stay local to the view?
- [ ] Do I need to update the protocol AND the real implementation AND the mock/stub?
- [ ] Should this data be cached in `ExerciseLibraryEntry`?
- [ ] Is there a corresponding test for this change?
