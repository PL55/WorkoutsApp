# Workout Tracker App — Design Spec

**Date**: 2026-03-21
**Approach**: Lean Refactor + Protocol-First Exercise System (Approach A)
**Base**: WorkoutsApp Clean Architecture template

---

## Overview

Refactor the WorkoutsApp template into a personal iOS workout tracking app. The app lets the user log workout sessions containing strength and cardio exercises, browse history grouped by date, and track progress for individual exercises over time.

Core goals:
- Reuse proven template infrastructure (DIContainer, Loadable, Store, SwiftData patterns)
- Remove all irrelevant template code (web repositories, push notifications, deep linking, images)
- Protocol-first exercise system for extensibility and isolation
- All persistence logic behind interfaces, thoroughly tested via mocks

**Swift language mode**: Swift 5 (matching the existing template `Package.swift`).

**Cross-actor boundary policy**: No `@Model` instances cross between the `@ModelActor` repository and the main actor in either direction. All cross-boundary communication uses plain value types (`UUID`, `ExerciseInput`, `ExerciseType`, `ProgressEntry`). This eliminates all SwiftData cross-context hazards by design.

---

## Supporting Types

### ExerciseType

```swift
enum ExerciseType: String, Codable, CaseIterable {
    case strength
    case cardio
}
```

`String` raw value for SwiftData persistence. `CaseIterable` for the type picker in `AddExerciseView`.

### ExerciseInput

Used on the **create path only**. Views never construct `@Model` instances — they build an `ExerciseInput` from form values and pass it to the interactor.

```swift
enum ExerciseInput {
    case strength(name: String, sets: Int, reps: Int, weight: Double)
    case cardio(name: String, durationMinutes: Double)

    var name: String {
        switch self {
        case .strength(let name, _, _, _): return name
        case .cardio(let name, _): return name
        }
    }

    var exerciseType: ExerciseType {
        switch self {
        case .strength: return .strength
        case .cardio: return .cardio
        }
    }
}
```

### ProgressEntry

Value type returned from the repository across the actor boundary.

```swift
struct ProgressEntry: Identifiable {
    let id: UUID
    let date: Date
    let exerciseType: ExerciseType
    let value: Double
    let label: String   // "Volume (lbs)" or "Duration (min)"
}
```

---

## Data Model

### Protocol Hierarchy

Used for **display only** — objects retrieved from SwiftData relationships on the main thread.

```swift
protocol Exercise: Identifiable {
    var id: UUID { get }
    var name: String { get }
    var exerciseType: ExerciseType { get }
}

protocol AnalyticsTrackable: Exercise {
    var analyticsValue: Double { get }
    var analyticsLabel: String { get }
}
```

Protocol objects are never passed to the interactor or repository. Views extract the `id` and `exerciseType` from protocol instances when they need to trigger delete operations, then pass those as plain value types.

### SwiftData Models

`exerciseType` is **stored** (not computed) — required for `#Predicate` queries. `analyticsValue` and `analyticsLabel` are computed and never queried.

Both exercise models declare back-references with explicit `@Relationship(inverse:)`. Without this, SwiftData inverse inference is unreliable.

```swift
@Model class WorkoutSession {
    var id: UUID
    var date: Date
    @Relationship(deleteRule: .cascade) var strengthExercises: [StrengthExercise] = []
    @Relationship(deleteRule: .cascade) var cardioExercises: [CardioExercise] = []
}

@Model class StrengthExercise {
    var id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double
    var exerciseType: ExerciseType = ExerciseType.strength   // stored, set at init
    @Relationship(inverse: \WorkoutSession.strengthExercises)
    var session: WorkoutSession?
    var analyticsValue: Double { Double(sets * reps) * weight }
    var analyticsLabel: String { "Volume (lbs)" }
}

@Model class CardioExercise {
    var id: UUID
    var name: String
    var durationMinutes: Double
    var exerciseType: ExerciseType = ExerciseType.cardio     // stored, set at init
    @Relationship(inverse: \WorkoutSession.cardioExercises)
    var session: WorkoutSession?
    var analyticsValue: Double { durationMinutes }
    var analyticsLabel: String { "Duration (min)" }
}

@Model class ExerciseLibraryEntry {
    @Attribute(.unique) var name: String
    var id: UUID
    var type: ExerciseType
}
```

`@Relationship(deleteRule: .cascade)` ensures deleting a `WorkoutSession` deletes all child exercise records.

`@Attribute(.unique)` on `ExerciseLibraryEntry.name` is a safety-net constraint. The repository uses fetch-before-insert to avoid hitting it in normal flow. Because `MainDBRepository` is a `@ModelActor`, all callers are serialised on the actor — there is no true concurrent access from multiple threads, so the fetch-then-insert pattern is safe within this design.

Multiple sessions per date are allowed.

---

## Architecture

### Layers

```
Presentation (Views)
  — builds ExerciseInput from form values
  — passes UUID + ExerciseType for delete operations
  — reads @Model objects from @Query / relationships for display only
    ↓ (only value types cross the boundary)
Business Logic (WorkoutsInteractor protocol)
    ↓ (only value types cross the boundary)
Data Access (WorkoutsDBRepository protocol / @ModelActor MainDBRepository)
  — owns all @Model creation, mutation, deletion
  — returns only value types (UUID, [ProgressEntry])
    ↓
SwiftData
```

### What Is Kept from the Template

| Component | Status | Notes |
|---|---|---|
| `DIContainer` | Adapted | `WebRepositories` removed |
| `Store<State>` | Kept | Unchanged |
| `AppState` | Simplified | Routing only |
| `Loadable<T>` + `LoadableSubject.load { }` | Kept | Unchanged — `CancelBag` managed internally |
| `CancelBag` | Kept | Unchanged |
| `@ModelActor MainDBRepository` | Extended | New protocol conformance added |
| `ModelContainer` extensions | Adapted | Schema updated |
| `AppSchema` | Adapted | New model types |
| `AppEnvironment` | Adapted | Web/push/system stripped |
| `@Query` pattern | Kept | Session list, detail, autocomplete |
| `NavigationStack` / `NavigationPath` | Kept | Unchanged |
| `Query+Search.swift` | Kept | Unchanged — used for library autocomplete |

### What Is Removed

- `CountriesWebRepository`, `ImagesWebRepository`, `PushTokenWebRepository`
- `WebRepository` base protocol, `DIContainer.WebRepositories`
- `PushNotificationsHandler`, `DeepLinksHandler`, `SystemEventsHandler`
- `ImagesInteractor`, `UserPermissionsInteractor`
- `AppState.Permissions`, `AppState.System`
- `LocaleReader`, `ImageView`, `ModalFlagView`
- `EnvironmentOverrides` package dependency
- All `ApiModel` types
- `Country`, `CountryDetails`, `CountryCurrency` models

### AppState

```swift
struct AppState: Equatable {
    var routing = ViewRouting()
}

extension AppState {
    struct ViewRouting: Equatable {
        var sessionList = SessionList.Routing()
    }
}

// In SessionListView file:
extension SessionList {
    struct Routing: Equatable {}   // empty — no deep linking in this app
}
```

### AppEnvironment

```swift
@MainActor
struct AppEnvironment {
    let isRunningTests: Bool
    let diContainer: DIContainer
    let modelContainer: ModelContainer   // retained so App.swift can apply .modelContainer()
}

extension AppEnvironment {
    static func bootstrap() -> AppEnvironment {
        let appState = Store<AppState>(AppState())
        let modelContainer = configuredModelContainer()
        let dbRepository = MainDBRepository(modelContainer: modelContainer)
        let interactors = DIContainer.Interactors(
            workouts: RealWorkoutsInteractor(dbRepository: dbRepository)
        )
        let diContainer = DIContainer(appState: appState, interactors: interactors)
        return AppEnvironment(
            isRunningTests: ProcessInfo.processInfo.isRunningTests,
            diContainer: diContainer,
            modelContainer: modelContainer
        )
    }

    private static func configuredModelContainer() -> ModelContainer {
        do {
            return try ModelContainer.appModelContainer()
        } catch {
            return ModelContainer.stub   // in-memory fallback — consistent with template
        }
    }
}
```

`App.swift` applies both modifiers using the same `modelContainer` instance:
```swift
ContentView()
    .inject(appEnvironment.diContainer)
    .modelContainer(appEnvironment.modelContainer)
```

This ensures `@Query` macros and the `@ModelActor` repository share the same container.

### Repository: @ModelActor

`MainDBRepository` is declared as `@ModelActor` in `ModelContainer.swift`. The macro provides `modelContext` (background context for writes) and `modelContainer` (for `mainContext` reads). The workout app adds a `WorkoutsDBRepository` conformance to `MainDBRepository`, exactly as the template adds `CountriesDBRepository` conformance.

Write operations use `modelContext.transaction { }`. No explicit `context.save()` calls are needed — `transaction` handles saving.

### Loadable Pattern

`Loadable<T>` and `LoadableSubject.load { }` are kept unchanged. `CancelBag` is allocated inside `load { }` — views do not manage it directly.

```swift
// Usage in AddExerciseView:
@State private var saveState: Loadable<UUID> = .notRequested   // UUID = new/existing session ID

$saveState.load {
    try await injected.interactors.workouts.addExercise(to: sessionID, input: input)
}
```

`Loadable` is **not** used in `SessionListView` or `SessionDetailView` — both are `@Query`-driven.
`Loadable<UUID>` is used in `AddExerciseView`. `Loadable<[ProgressEntry]>` is used in `ExerciseProgressView`.

### Schema Registration

```swift
// AppSchema.swift
enum DBModel { }   // namespace — kept from template

extension Schema {
    private static var actualVersion: Schema.Version = Version(1, 0, 0)

    static var appSchema: Schema {
        Schema([
            WorkoutSession.self,
            StrengthExercise.self,
            CardioExercise.self,
            ExerciseLibraryEntry.self
        ], version: actualVersion)
    }
}
```

All four types must be registered.

### Schema Migration

Out of scope for v1. Deploy any schema change with a `VersionedSchema` + `SchemaMigrationPlan` to prevent data loss on existing devices.

---

## Interfaces

### WorkoutsInteractor

```swift
protocol WorkoutsInteractor {
    // sessionID == nil → creates new session; returns its UUID
    // sessionID != nil → adds exercise to existing session; returns same UUID
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID
    func deleteSession(id: UUID) async throws
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
}
```

All parameters and return values are plain value types. No `@Model` instances cross this boundary.

### WorkoutsDBRepository

```swift
protocol WorkoutsDBRepository {
    // Creates session + exercise in a single transaction; returns new session UUID
    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID
    // Creates exercise in a single transaction; fetches session by ID internally
    func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws
    // Deletes session by ID (cascade deletes children)
    func deleteSession(id: UUID) async throws
    // Fetches exercise by id+type, removes from session array, deletes record
    // Throws ExerciseNotFoundError if not found
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    // Two FetchDescriptors combined and sorted; orphaned exercises silently dropped
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
    // Returns true if an entry with this name exists
    func libraryContains(name: String) async throws -> Bool
    // Idempotent — fetch-before-insert; never throws for existing name
    func upsertLibraryEntry(name: String, type: ExerciseType) async throws
}
```

**`MainDBRepository` implementation patterns:**

`saveNewSession`:

```swift
func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID {
    let sessionID = UUID()
    let session = WorkoutSession(id: sessionID, date: date)
    try modelContext.transaction {
        modelContext.insert(session)
        switch input {
        case .strength(let name, let sets, let reps, let weight):
            let e = StrengthExercise(id: UUID(), name: name, sets: sets, reps: reps, weight: weight)
            e.session = session
            session.strengthExercises.append(e)
            modelContext.insert(e)
        case .cardio(let name, let durationMinutes):
            let e = CardioExercise(id: UUID(), name: name, durationMinutes: durationMinutes)
            e.session = session
            session.cardioExercises.append(e)
            modelContext.insert(e)
        }
    }
    return sessionID
}
```

`addExercise` — fetches session by ID within the actor, then appends:

```swift
func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws {
    let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
    guard let session = try modelContext.fetch(descriptor).first else { throw SessionNotFoundError() }
    try modelContext.transaction {
        switch input {
        case .strength(let name, let sets, let reps, let weight):
            let e = StrengthExercise(id: UUID(), name: name, sets: sets, reps: reps, weight: weight)
            e.session = session
            session.strengthExercises.append(e)
            modelContext.insert(e)
        case .cardio(let name, let durationMinutes):
            let e = CardioExercise(id: UUID(), name: name, durationMinutes: durationMinutes)
            e.session = session
            session.cardioExercises.append(e)
            modelContext.insert(e)
        }
    }
}
```

`deleteExercise` — fetches both session and exercise by ID within the actor:

```swift
func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
    let sessionDescriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
    guard let session = try modelContext.fetch(sessionDescriptor).first else { throw SessionNotFoundError() }
    try modelContext.transaction {
        switch type {
        case .strength:
            guard let e = session.strengthExercises.first(where: { $0.id == id }) else {
                throw ExerciseNotFoundError()
            }
            session.strengthExercises.removeAll { $0.id == id }
            modelContext.delete(e)
        case .cardio:
            guard let e = session.cardioExercises.first(where: { $0.id == id }) else {
                throw ExerciseNotFoundError()
            }
            session.cardioExercises.removeAll { $0.id == id }
            modelContext.delete(e)
        }
    }
}
```

`upsertLibraryEntry` — fetch-before-insert; safe because `@ModelActor` serialises all callers:

```swift
func upsertLibraryEntry(name: String, type: ExerciseType) async throws {
    let descriptor = FetchDescriptor<ExerciseLibraryEntry>(predicate: #Predicate { $0.name == name })
    guard try modelContext.fetch(descriptor).isEmpty else { return }
    try modelContext.transaction {
        modelContext.insert(ExerciseLibraryEntry(id: UUID(), name: name, type: type))
    }
}
```

`progressEntries` — two `FetchDescriptor` calls, combined and sorted. Exercises with `nil` session (orphaned records after a partial failure) are silently dropped — intentional; the chart shows available data only. A repository integration test verifies this:

```swift
func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] {
    let strengthFetch = FetchDescriptor<StrengthExercise>(predicate: #Predicate { $0.name == exerciseName })
    let cardioFetch   = FetchDescriptor<CardioExercise>(predicate: #Predicate { $0.name == exerciseName })
    let strength = try modelContext.fetch(strengthFetch).compactMap { e -> ProgressEntry? in
        guard let date = e.session?.date else { return nil }
        return ProgressEntry(id: e.id, date: date, exerciseType: .strength, value: e.analyticsValue, label: e.analyticsLabel)
    }
    let cardio = try modelContext.fetch(cardioFetch).compactMap { e -> ProgressEntry? in
        guard let date = e.session?.date else { return nil }
        return ProgressEntry(id: e.id, date: date, exerciseType: .cardio, value: e.analyticsValue, label: e.analyticsLabel)
    }
    return (strength + cardio).sorted { $0.date < $1.date }
}
```

---

## Data Flow

### Logging a New Exercise (First in a Session)

```
1. User taps "New Workout"
2. AddExerciseView presented with sessionID = nil, saveState = .notRequested
3. User fills in form (@State values — no @Model)
4. User taps Save
5. View constructs ExerciseInput, calls $saveState.load { interactor.addExercise(to: nil, input:) }
6. saveState → .isLoading; interactor calls dbRepository.saveNewSession(date: .now, with: input)
7. Repository creates session + exercise in one transaction, returns new UUID
8. Interactor calls libraryContains; if false, calls upsertLibraryEntry
9. Interactor returns UUID; saveState → .loaded(uuid)
10. View dismisses; @Query in SessionListView auto-refreshes
```

### Adding a Subsequent Exercise to an Existing Session

```
1. User opens session → SessionDetailView (session passed via NavigationLink as @Model from @Query)
2. User taps "Add Exercise" → AddExerciseView with sessionID = session.id
3. User types name → @Query filters ExerciseLibraryEntry for autocomplete
4. User fills fields, taps Save
5. View constructs ExerciseInput, calls $saveState.load { interactor.addExercise(to: session.id, input:) }
6. Interactor calls dbRepository.addExercise(input, to: session.id)
7. Repository fetches session by ID, inserts exercise in one transaction
8. Interactor checks library, calls upsertLibraryEntry if name is new
9. saveState → .loaded(session.id); view dismisses
10. @Query in SessionDetailView auto-refreshes
```

### Viewing Progress for an Exercise

```
1. User taps exercise name in SessionDetailView
2. SessionDetailView pushes ExerciseProgressDestination(exerciseName:) onto NavigationPath
3. ExerciseProgressView appears with progressState = .notRequested
4. On appear: $progressState.load { interactor.progressEntries(for: exerciseName) }
5. Repository fetches strength + cardio entries, returns [ProgressEntry] sorted by date
6. progressState → .loaded(entries)
7. View displays trend list
8. If Set(entries.map(\.exerciseType)).count > 1, shows warning:
   Text("'\(exerciseName)' has been logged as both strength and cardio — results may be mixed")
```

`ExerciseProgressDestination` is a wrapper type to prevent navigation value collisions:

```swift
struct ExerciseProgressDestination: Hashable {
    let exerciseName: String
}
```

### Session List Grouping

```swift
var groupedSessions: [(key: Date, value: [WorkoutSession])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
    return grouped.sorted { $0.key > $1.key }
}
```

"Same date" = same calendar day. Performance is acceptable for a personal app. If it becomes an issue, cache with `onChange(of: sessions)`.

### SessionDetailView Exercise List

`SessionDetailView` uses relationship traversal on the main context — no separate `@Query` needed:

```swift
var allExercises: [any AnalyticsTrackable] {
    (session.strengthExercises as [any AnalyticsTrackable]) +
    (session.cardioExercises as [any AnalyticsTrackable])
}
```

When the user deletes an exercise, the view passes `exercise.id` and `exercise.exerciseType` — not the `@Model` instance — to the interactor.

---

## Views

| View | Replaces | Purpose |
|---|---|---|
| `SessionListView` | `CountriesListView` | Sessions grouped by calendar day |
| `SessionDetailView` | `CountryDetailsView` | Exercises via relationship traversal; delete passes `id + type`; name tap pushes `ExerciseProgressDestination` |
| `AddExerciseView` | _(new)_ | Strength/cardio form, library autocomplete, `Loadable<UUID>` save state |
| `ExerciseProgressView` | _(new)_ | Progress trend, `Loadable<[ProgressEntry]>`, type-mismatch warning |
| `ErrorView` | `ErrorView` | Kept unchanged |

Pull-to-refresh removed — `@Query` reflects SwiftData state automatically.

---

## Testing Strategy

### Interactor Unit Tests (Highest Priority)

`MockWorkoutsDBRepository` is a `class`. The mock works entirely with value types (`UUID`, `ExerciseInput`, `ExerciseType`, `[ProgressEntry]`) — no `@Model` instances created.

```swift
class MockWorkoutsDBRepository: WorkoutsDBRepository {
    var saveNewSessionCalled = false
    var addExerciseCalled = false
    var upsertLibraryEntryCalled = false
    var deleteSessionCalled = false
    var deleteExerciseCalled = false
    var libraryEntries: [String] = []

    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID {
        saveNewSessionCalled = true
        return UUID()
    }

    func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws {
        addExerciseCalled = true
    }

    func deleteSession(id: UUID) async throws { deleteSessionCalled = true }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        deleteExerciseCalled = true
    }

    func upsertLibraryEntry(name: String, type: ExerciseType) async throws {
        upsertLibraryEntryCalled = true
        if !libraryEntries.contains(name) { libraryEntries.append(name) }
    }

    func libraryContains(name: String) async throws -> Bool {
        libraryEntries.contains(name)
    }

    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] { [] }
}
```

Key test cases:
- `addExercise(to: nil, input:)` → `saveNewSessionCalled == true`, `addExerciseCalled == false`
- `addExercise(to: someUUID, input:)` → `addExerciseCalled == true`, `saveNewSessionCalled == false`
- New exercise name → `upsertLibraryEntryCalled == true`
- Existing name (pre-seeded in `libraryEntries`) → `upsertLibraryEntryCalled == false`
- `deleteSession` → `deleteSessionCalled == true`
- `deleteExercise` → `deleteExerciseCalled == true`

### Repository Integration Tests

```swift
let container = try ModelContainer.appModelContainer(inMemoryOnly: true)
let repo = MainDBRepository(modelContainer: container)
```

Key test cases:
- `saveNewSession` returns a valid UUID; session exists in store by that ID
- Cascade delete: deleting session removes child exercises
- `addExercise` sets `exercise.session` back-reference correctly
- `deleteExercise` removes from relationship array **and** deletes the `@Model` record
- `deleteExercise` with unknown ID throws `ExerciseNotFoundError`
- `upsertLibraryEntry`: repeated calls with same name produce exactly one record
- `progressEntries`: sorted ascending, spans both types
- `progressEntries` with an orphaned exercise (nil session): silently dropped, count excludes it

### UI Tests (ViewInspector)

`StubWorkoutsInteractor` is a no-op struct conforming to `WorkoutsInteractor`, used by ViewInspector tests:

```swift
struct StubWorkoutsInteractor: WorkoutsInteractor {
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID { UUID() }
    func deleteSession(id: UUID) async throws {}
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {}
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] { [] }
}
```

Test cases:
- `AddExerciseView` shows strength fields (sets, reps, weight) for `.strength`
- `AddExerciseView` shows cardio fields (durationMinutes) for `.cardio`
- `AddExerciseView` renders spinner when `saveState == .isLoading`
- `AddExerciseView` renders `ErrorView` when `saveState == .failed`
- `ExerciseProgressView` renders spinner when `progressState == .isLoading`
- `ExerciseProgressView` renders empty state when `progressState == .loaded([])`
- `ExerciseProgressView` renders `ErrorView` when `progressState == .failed`

---

## File Structure

```
WorkoutsApp/
├── Core/
│   ├── AppState.swift              (routing only; SessionList.Routing is empty struct)
│   ├── App.swift                   (bootstrap(), .inject(), .modelContainer())
│   └── AppDelegate.swift
├── DependencyInjection/
│   ├── DIContainer.swift           (WebRepositories removed; Interactors has workouts only)
│   └── AppEnvironment.swift        (isRunningTests, diContainer, modelContainer)
├── Interactors/
│   └── WorkoutsInteractor.swift    (protocol + RealWorkoutsInteractor + StubWorkoutsInteractor)
├── Repositories/
│   ├── Database/
│   │   ├── WorkoutsDBRepository.swift   (protocol + MainDBRepository extension)
│   │   └── ModelContainer.swift         (@ModelActor MainDBRepository + ModelContainer extensions)
│   └── Models/
│       ├── AppSchema.swift              (Schema.appSchema with all 4 @Model types)
│       ├── WorkoutSession.swift
│       ├── StrengthExercise.swift
│       ├── CardioExercise.swift
│       ├── ExerciseLibraryEntry.swift
│       └── ProgressEntry.swift          (value type)
├── UI/
│   ├── SessionList/
│   │   ├── SessionListView.swift        (groups by calendar day)
│   │   └── SessionCell.swift
│   ├── SessionDetail/
│   │   ├── SessionDetailView.swift      (relationship traversal for exercises)
│   │   └── ExerciseRow.swift
│   ├── AddExercise/
│   │   └── AddExerciseView.swift        (Loadable<UUID> save state)
│   ├── ExerciseProgress/
│   │   └── ExerciseProgressView.swift   (Loadable<[ProgressEntry]>)
│   └── Common/
│       ├── ErrorView.swift
│       └── Query+Search.swift           (kept unchanged)
└── Utilities/
    ├── CancelBag.swift
    ├── Loadable.swift
    ├── Store.swift
    ├── Helpers.swift
    ├── ExerciseType.swift
    └── ExerciseInput.swift
```
