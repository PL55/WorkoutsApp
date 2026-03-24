# Exercise-Centric Home Screen — Design Spec

**Date:** 2026-03-24
**Branch:** feature/exercise-centric-home
**Status:** Approved

---

## Overview

Redesign the home screen from a session-first view (workouts grouped by date) to an exercise-first view (exercises with volume/analytics preview). The goal is to make the app about tracking progress over time rather than simply recording when a workout happened.

### User-facing change

| Before | After |
|---|---|
| Home shows sessions grouped by date | Home shows exercise tiles grouped by Strength / Cardio |
| Tap session → see exercises in that session | Tap exercise → see historical sessions for that exercise |
| Tap exercise → see progress chart | Tap history entry → see sets/reps/weight (or duration) for that day |
| No way to see full session from progress view | "View Full Session" button on snapshot view |

---

## Approach

**Clean Home Replacement (Approach A):** `SessionListView` is removed as the primary entry point and replaced by a new `ExerciseListView`. Sessions remain fully accessible — they are reached through the exercise history → session snapshot → "View Full Session" path.

---

## Data Layer

### 1. `ProgressEntry` — add `sessionID`

Add `sessionID: UUID` to the existing `ProgressEntry` struct. The repository already holds the session reference when constructing entries (`e.session`), so `sessionID` is populated from `e.session!.id` at construction time in `progressEntries(for:)`.

```swift
struct ProgressEntry: Identifiable, Equatable {
    let id: UUID
    let sessionID: UUID      // NEW — populated from e.session!.id; used for navigation to snapshot
    let date: Date
    let exerciseType: ExerciseType
    let value: Double
    let label: String
}
```

**Deduplication:** When a session contains multiple exercise rows with the same name (e.g. two "Bench Press" `StrengthExercise` records in one session), `progressEntries(for:)` currently returns one `ProgressEntry` per row, producing duplicate date entries. To avoid showing duplicates in `ExerciseHistoryView`, the repository deduplicates by `sessionID` before returning: for each `sessionID`, keep the row with the highest `analyticsValue`. This deduplication is applied inside `progressEntries(for:)` before sorting.

### 2. New `ExerciseOverviewDTO`

Plain struct used for home screen tiles. Located in `Models/DTOs/`.

```swift
struct ExerciseOverviewDTO: Identifiable {
    let id: String           // exercise name — unique within a given ExerciseType tab
    let name: String
    let exerciseType: ExerciseType
    let bestValue: Double    // max analyticsValue across all sessions
    let latestValue: Double  // analyticsValue of the most recent session
    let lastDate: Date       // date of most recent session (drives "most recent" sort)
    let analyticsLabel: String
}
```

`id` is the exercise name. Since `ExerciseListView` shows one tab per `ExerciseType`, name is unique within a given tab. No composite key needed.

### 3. New repository method: `fetchExerciseOverviews(type: ExerciseType)`

Added to `WorkoutsDBRepository` protocol and implemented in `MainDBRepository`.

- Single `FetchDescriptor` (no explicit sort needed — grouping is done in Swift) over `StrengthExercise` or `CardioExercise` depending on `type`
- SwiftData populates the `session` inverse relationship automatically on access — no additional fetch required
- Groups results by `name` in Swift (O(n) pass)
- For each group: filters out rows where `session == nil`, computes `bestValue = max(analyticsValue)`, finds the entry with the latest `session.date` for `latestValue` and `lastDate`
- Groups with no valid session entries are excluded entirely
- Returns `[ExerciseOverviewDTO]` — no SwiftData types leak out

This is a single query (no N+1), O(n) grouping pass, then O(k) per group where k is the number of sessions per exercise name.

### 4. New interactor method: `fetchExerciseOverviews(type: ExerciseType)`

Thin pass-through on `WorkoutsInteractor` protocol and `RealWorkoutsInteractor`. Consistent with existing pattern.

---

## AppState

`AppState.ViewRouting` currently contains `var sessionList = SessionList.Routing()` where `SessionList` is a typealias for `SessionListView`. When `SessionListView` is deleted, this must be updated:

- Rename `sessionList` to `exerciseList` in `ViewRouting`
- Add `struct Routing: Equatable {}` to `ExerciseListView` (same empty struct pattern)
- Update the `SessionList` typealias site: `typealias ExerciseList = ExerciseListView`

`RootView.swift` passes the `DIContainer` environment to `SessionListView` — update the call site to `ExerciseListView`.

---

## ViewModel Layer

All VMs follow the existing `configure(interactor:)` + manual `Task + Loadable` pattern.

### `ExerciseListViewModel`

```swift
@Observable @MainActor final class ExerciseListViewModel {
    private(set) var overviews: Loadable<[ExerciseOverviewDTO]> = .notRequested
    private(set) var sortedOverviews: [ExerciseOverviewDTO] = []
    var sortOrder: SortOrder = .alphabetical {
        didSet { if let loaded = overviews.value { sortedOverviews = sorted(loaded) } }
    }

    func configure(interactor: any WorkoutsInteractor)
    func loadOverviews(type: ExerciseType)       // manual Task + Loadable; calls applySort on success
    private func sorted(_ overviews: [ExerciseOverviewDTO]) -> [ExerciseOverviewDTO]
}

enum SortOrder {
    case alphabetical    // sort by name ascending
    case mostRecent      // sort by lastDate descending
    case leastRecent     // sort by lastDate ascending
}
```

`sortOrder` uses `didSet` to recompute `sortedOverviews` in-memory when the sort changes. `loadOverviews` calls `sorted(_:)` when the fetch completes. No re-fetch is needed for sort changes. The view must never call `sorted` directly — it always reads `vm.sortedOverviews`.

`Loadable` needs a `value` computed property (returns the associated value if `.loaded`, else `nil`) — check if this already exists; add it if not.

### `ExerciseHistoryViewModel`

```swift
@Observable @MainActor final class ExerciseHistoryViewModel {
    private(set) var entries: Loadable<[ProgressEntry]> = .notRequested

    func configure(interactor: any WorkoutsInteractor)
    func loadEntries(for exerciseName: String)   // manual Task + Loadable
}
```

Uses the existing `progressEntries(for:)` interactor method (no new interactor method needed).

### `ExerciseSessionSnapshotViewModel`

```swift
@Observable @MainActor final class ExerciseSessionSnapshotViewModel {
    private(set) var session: Loadable<WorkoutSessionDTO> = .notRequested

    func configure(interactor: any WorkoutsInteractor)
    func loadSession(id: UUID)                   // manual Task + Loadable
}
```

Uses the existing `fetchSession(id:)` interactor method. The view extracts the matching exercise by name and type from the loaded `WorkoutSessionDTO`. Read-only — no delete functionality in this view.

---

## Navigation

Navigation destinations are defined in `ExerciseListView.swift` (the same pattern as destinations in `SessionListView.swift` today).

```
ExerciseListView  (new home)
  └─ ExerciseHistoryDestination(exerciseName: String, exerciseType: ExerciseType)   ← NEW
       └─ ExerciseSnapshotDestination(exerciseName: String, sessionID: UUID, exerciseType: ExerciseType)   ← NEW
            └─ SessionDetailDestination(sessionID: UUID)   ← moved from SessionListView.swift
```

`NavigationStack` with `navigationDestination(for:)` — identical pattern to today.

**Destination structs moved from `SessionListView.swift` into `ExerciseListView.swift`:**
- `SessionDetailDestination` — moved unchanged (still `Hashable`, still takes `sessionID: UUID`)
- `AddExerciseDestination` — moved unchanged (still `Hashable`, still takes `sessionID: UUID?`); referenced by `SessionDetailView`'s toolbar `+` button

**Destination structs deleted:**
- `ExerciseProgressDestination` — deleted; `SessionDetailView` push site updated to use `ExerciseHistoryDestination` instead

**`navigationDestination` registrations in `ExerciseListView`:**
- `SessionDetailDestination` → `SessionDetailView(sessionID:navigationPath:)` (existing)
- `AddExerciseDestination` → `AddExerciseView(sessionID:)` (existing)
- `ExerciseHistoryDestination` → `ExerciseHistoryView(exerciseName:exerciseType:)` (new)
- `ExerciseSnapshotDestination` → `ExerciseSessionSnapshotView(exerciseName:sessionID:exerciseType:)` (new)

---

## View Layer

### `ExerciseListView` (new, replaces `SessionListView` as root)

- Segmented `Picker` for Strength / Cardio tab, `@State var selectedType: ExerciseType = .strength`
- Initial load: `.task { vm.configure(interactor:); vm.loadOverviews(type: selectedType) }`
- Tab-switch reload: `.onChange(of: selectedType) { vm.loadOverviews(type: selectedType) }`
- Toolbar:
  - Leading: sort button — cycles Alphabetical → Most Recent → Least Recent; label shows current sort; tapping sets `vm.sortOrder` directly (triggers `didSet`)
  - Trailing: `+` button — pushes `AddExerciseDestination(sessionID: nil)` (unchanged)
- Content states: `.notRequested`/`.isLoading` → `ProgressView`, `.loaded([])` → `ContentUnavailableView`, `.loaded` → list of `ExerciseTileView`, `.failed` → `ErrorView`
- List uses `vm.sortedOverviews`

### `ExerciseTileView` (new, display-only component)

- Title: exercise name
- Subtitle row 1: `Best: {bestValue} {analyticsLabel}`
- Subtitle row 2: `Latest: {latestValue} {analyticsLabel}`
- Trailing: last logged date (`.date` style)

### `ExerciseHistoryView` (new, replaces `ExerciseProgressView`)

- Navigation title: exercise name
- Receives `exerciseName: String` and `exerciseType: ExerciseType`
- Each row: date (left) + analytics value + label (right) — `NavigationLink` → `ExerciseSnapshotDestination`
- Retains mixed-type warning from `ExerciseProgressView` (shown when entries contain both `.strength` and `.cardio` types)
- Empty state: `ContentUnavailableView`
- Uses `ExerciseHistoryViewModel` (configure + load in `.task`)
- Chart: list only for now (no chart); can be added in a future iteration

### `ExerciseSessionSnapshotView` (new)

- Navigation title: exercise name + session date
- Receives `exerciseName: String`, `sessionID: UUID`, `exerciseType: ExerciseType`
- **Strength**: displays sets, reps, weight in a simple list (extracted from `WorkoutSessionDTO.strengthExercises` by name match)
- **Cardio**: displays duration in minutes (extracted from `WorkoutSessionDTO.cardioExercises` by name match)
- Toolbar button: "View Full Session" → pushes `SessionDetailDestination(sessionID:)` onto the stack
- Read-only — no delete
- Loadable state machine: loading → loaded → error
- Uses `ExerciseSessionSnapshotViewModel`

### `SessionDetailView` — one push-site update

`SessionDetailView` currently navigates to `ExerciseProgressView` via `ExerciseProgressDestination`. Update the `NavigationLink` destination in `exerciseList` to push `ExerciseHistoryDestination(exerciseName:exerciseType:)` instead. No other changes.

---

## Deleted Files

| File | Reason |
|---|---|
| `UI/SessionList/SessionListView.swift` | Replaced by `ExerciseListView` |
| `UI/SessionList/SessionListViewModel.swift` | Replaced by `ExerciseListViewModel` |
| `UI/SessionList/SessionCell.swift` | Replaced by `ExerciseTileView` |
| `UI/ExerciseProgress/ExerciseProgressView.swift` | Replaced by `ExerciseHistoryView` |

---

## Modified Files

| File | Change |
|---|---|
| `Core/AppState.swift` | Rename `sessionList` → `exerciseList` in `ViewRouting`; update typealias to `ExerciseList` |
| `UI/RootView.swift` | Update `SessionListView` call site to `ExerciseListView` |
| `UI/SessionDetail/SessionDetailView.swift` | Replace `ExerciseProgressDestination` push with `ExerciseHistoryDestination` |
| `Repositories/Models/ProgressEntry.swift` | Add `sessionID: UUID` |
| `Repositories/Database/WorkoutsDBRepository.swift` | Add `fetchExerciseOverviews(type:)` to protocol + implementation; add deduplication to `progressEntries(for:)` |
| `Interactors/WorkoutsInteractor.swift` | Add `fetchExerciseOverviews(type:)` to protocol + real impl + stub |
| `Utilities/Loadable.swift` | Add `var value: T? { get }` computed property if not already present |
| `UnitTests/Mocks/MockedInteractors.swift` | Add `fetchExerciseOverviews(type:)` |
| `UnitTests/Mocks/MockedDBRepositories.swift` | Add `fetchExerciseOverviews(type:)` |

---

## New Files

| File | Purpose |
|---|---|
| `Models/DTOs/ExerciseOverviewDTO.swift` | Home screen tile data |
| `UI/ExerciseList/ExerciseListView.swift` | New home screen |
| `UI/ExerciseList/ExerciseListViewModel.swift` | Tile data + sort |
| `UI/ExerciseList/ExerciseTileView.swift` | Tile display component |
| `UI/ExerciseHistory/ExerciseHistoryView.swift` | Historical entries list |
| `UI/ExerciseHistory/ExerciseHistoryViewModel.swift` | History load |
| `UI/ExerciseSessionSnapshot/ExerciseSessionSnapshotView.swift` | Single-session exercise detail |
| `UI/ExerciseSessionSnapshot/ExerciseSessionSnapshotViewModel.swift` | Session load + exercise extraction |

---

## Testing

All tests use Swift Testing (`@Suite`, `@Test`, `#expect`) consistent with the existing suite.

### ViewModel tests (`MockedWorkoutsInteractor`)

- **`ExerciseListViewModelTests`**: sort order transitions (all three), `loadOverviews` Loadable state machine, tab switch triggers reload, empty overviews handled, `sortedOverviews` recomputes on `sortOrder` change without re-fetch
- **`ExerciseHistoryViewModelTests`**: `loadEntries` Loadable transitions, empty entries handled
- **`ExerciseSessionSnapshotViewModelTests`**: `loadSession` Loadable transitions, correct exercise extracted by name + type from `WorkoutSessionDTO`

### Interactor tests (`MockedWorkoutsDBRepository`)

- `fetchExerciseOverviews(type:)` calls repo with correct type argument

### Repository tests (in-memory `ModelContainer.mock`)

- `fetchExerciseOverviews` returns correct `bestValue`, `latestValue`, `lastDate` from seeded data
- Exercises not linked to a session are excluded
- Multiple exercise rows with the same name in one session produce one `ExerciseOverviewDTO` entry
- `progressEntries(for:)` deduplicates by `sessionID`, keeping highest `analyticsValue` per session

### UI tests (ViewInspector + `Inspection` helper)

- **`ExerciseListViewTests`**: loaded/empty/error states render correctly; sort button present; tab switching
- **`ExerciseHistoryViewTests`**: loaded/empty/error states; mixed-type warning shown when applicable
- **`ExerciseSessionSnapshotViewTests`**: strength detail fields visible; cardio detail fields visible; "View Full Session" button present

### Mocks updated

- `MockedWorkoutsInteractor` — add `fetchExerciseOverviews(type:)`
- `MockedWorkoutsDBRepository` — add `fetchExerciseOverviews(type:)`

### Deleted test files

| File | Reason |
|---|---|
| `UnitTests/UI/RootViewTests.swift` | Keep — tests `RootView` Loadable launch states, unaffected |
| `UnitTests/UI/SessionListTests.swift` | Delete — replaced by `ExerciseListViewTests` |
| `UnitTests/UI/SessionListViewModelTests.swift` | Delete — replaced by `ExerciseListViewModelTests` |
| `UnitTests/UI/ExerciseProgressViewTests.swift` | Delete — replaced by `ExerciseHistoryViewTests` |
