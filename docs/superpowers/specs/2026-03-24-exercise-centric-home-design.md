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

Add `sessionID: UUID` to the existing `ProgressEntry` struct. The repository already holds the session reference when constructing entries (`e.session`), so this is a one-line addition at the construction site in `progressEntries(for:)`.

```swift
struct ProgressEntry: Identifiable, Equatable {
    let id: UUID
    let sessionID: UUID      // NEW
    let date: Date
    let exerciseType: ExerciseType
    let value: Double
    let label: String
}
```

### 2. New `ExerciseOverviewDTO`

Plain struct used for home screen tiles. Located in `Models/DTOs/`.

```swift
struct ExerciseOverviewDTO: Identifiable {
    let id: String           // exercise name — unique within a given ExerciseType
    let name: String
    let exerciseType: ExerciseType
    let bestValue: Double    // max analyticsValue across all sessions
    let latestValue: Double  // analyticsValue of the most recent session
    let lastDate: Date       // date of most recent session (drives "most recent" sort)
    let analyticsLabel: String
}
```

### 3. New repository method: `fetchExerciseOverviews(type: ExerciseType)`

Added to `WorkoutsDBRepository` protocol and implemented in `MainDBRepository`.

- Single `FetchDescriptor` pass over `StrengthExercise` or `CardioExercise` (determined by `type`)
- Groups results by `name` in Swift
- For each group: computes `bestValue = max(analyticsValue)`, finds the entry with the latest `session?.date` for `latestValue` and `lastDate`
- Filters out any exercise not linked to a session (orphaned records)
- Returns `[ExerciseOverviewDTO]` — no SwiftData types leak out

This is a single query (no N+1), O(n) grouping pass, then O(k) per group where k is the number of sessions per exercise name.

### 4. New interactor method: `fetchExerciseOverviews(type: ExerciseType)`

Thin pass-through on `WorkoutsInteractor` protocol and `RealWorkoutsInteractor`. Consistent with existing pattern.

---

## ViewModel Layer

All VMs follow the existing `configure(interactor:)` + manual `Task + Loadable` pattern.

### `ExerciseListViewModel`

```swift
@Observable @MainActor final class ExerciseListViewModel {
    private(set) var overviews: Loadable<[ExerciseOverviewDTO]> = .notRequested
    private(set) var sortedOverviews: [ExerciseOverviewDTO] = []
    var sortOrder: SortOrder = .alphabetical

    func configure(interactor: any WorkoutsInteractor)
    func loadOverviews(type: ExerciseType)       // manual Task + Loadable
    private func applySort(_ overviews: [ExerciseOverviewDTO])
}

enum SortOrder {
    case alphabetical    // sort by name ascending
    case mostRecent      // sort by lastDate descending
    case leastRecent     // sort by lastDate ascending
}
```

`sortedOverviews` is derived in-memory: recomputed when `overviews` transitions to `.loaded` or when `sortOrder` changes. No re-fetch required for sort changes.

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

Uses the existing `fetchSession(id:)` interactor method. The view extracts the matching exercise by name and type from the loaded `WorkoutSessionDTO`.

---

## Navigation

Navigation destinations are defined alongside `ExerciseListView` (as today's destinations live in `SessionListView.swift`).

```
ExerciseListView  (new home)
  └─ ExerciseHistoryDestination(exerciseName: String, exerciseType: ExerciseType)
       └─ ExerciseSnapshotDestination(exerciseName: String, sessionID: UUID, exerciseType: ExerciseType)
            └─ SessionDetailDestination(sessionID: UUID)   ← existing, unchanged
```

`NavigationStack` with `navigationDestination(for:)` — identical pattern to today.

---

## View Layer

### `ExerciseListView` (new, replaces `SessionListView` as root)

- Segmented `Picker` for Strength / Cardio tab, `@State var selectedType: ExerciseType`
- Tab change triggers `vm.loadOverviews(type: selectedType)`
- Toolbar:
  - Leading: sort button — cycles Alphabetical → Most Recent → Least Recent; label shows current sort
  - Trailing: `+` button — pushes `AddExerciseDestination(sessionID: nil)` (unchanged)
- Content states: `.notRequested`/`.isLoading` → `ProgressView`, `.loaded([])` → `ContentUnavailableView`, `.loaded` → list of `ExerciseTileView`, `.failed` → `ErrorView`
- List uses `vm.sortedOverviews` (never re-fetches on sort change)

### `ExerciseTileView` (new, display-only component)

- Title: exercise name
- Subtitle row 1: `Best: {bestValue} {analyticsLabel}`
- Subtitle row 2: `Latest: {latestValue} {analyticsLabel}`
- Trailing: last logged date (`.date` style)

### `ExerciseHistoryView` (new, replaces `ExerciseProgressView`)

- Navigation title: exercise name
- Each row: date (left) + analytics value + label (right) — `NavigationLink` → `ExerciseSnapshotDestination`
- Retains mixed-type warning from `ExerciseProgressView`
- Empty state: `ContentUnavailableView`
- Uses `ExerciseHistoryViewModel` (configure + load in `.task`)

### `ExerciseSessionSnapshotView` (new)

- Navigation title: exercise name + session date
- **Strength**: displays sets, reps, weight in a simple list
- **Cardio**: displays duration in minutes
- Toolbar button: "View Full Session" → pushes `SessionDetailDestination(sessionID:)` onto the stack
- Loadable state machine: loading → loaded → error
- Uses `ExerciseSessionSnapshotViewModel`

### `SessionDetailView` — unchanged

Still reachable as a pushed destination from `ExerciseSessionSnapshotView`. No modifications needed.

---

## Deleted Files

| File | Reason |
|---|---|
| `UI/SessionList/SessionListView.swift` | Replaced by `ExerciseListView` |
| `UI/SessionList/SessionListViewModel.swift` | Replaced by `ExerciseListViewModel` |
| `UI/SessionList/SessionCell.swift` | Replaced by `ExerciseTileView` |
| `UI/ExerciseProgress/ExerciseProgressView.swift` | Replaced by `ExerciseHistoryView` |

Navigation destinations and `SessionList.Routing` from `SessionListView.swift` move into `ExerciseListView.swift`.

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

- **`ExerciseListViewModelTests`**: sort order transitions (all three), `loadOverviews` Loadable state machine, tab switch triggers reload, empty overviews handled
- **`ExerciseHistoryViewModelTests`**: `loadEntries` Loadable transitions, empty entries handled
- **`ExerciseSessionSnapshotViewModelTests`**: `loadSession` Loadable transitions, correct exercise extracted by name + type from `WorkoutSessionDTO`

### Interactor tests (`MockedWorkoutsDBRepository`)

- `fetchExerciseOverviews(type:)` calls repo with correct type argument

### Repository tests (in-memory `ModelContainer.mock`)

- `fetchExerciseOverviews` returns correct `bestValue`, `latestValue`, `lastDate` from seeded data
- Exercises not linked to a session are excluded
- Library-only entries (never logged) do not appear

### UI tests (ViewInspector + `Inspection` helper)

- **`ExerciseListViewTests`**: loaded/empty/error states render correctly; sort button present; tab switching
- **`ExerciseHistoryViewTests`**: loaded/empty/error states; mixed-type warning shown when applicable
- **`ExerciseSessionSnapshotViewTests`**: strength detail fields visible; cardio detail fields visible; "View Full Session" button present

### Mocks updated

- `MockedWorkoutsInteractor` — add `fetchExerciseOverviews(type:)`
- `MockedWorkoutsDBRepository` — add `fetchExerciseOverviews(type:)`

---

## Questions to Ask When Implementing

- [ ] Does `ExerciseOverviewDTO.id` need to be a composite of name + type, or is name alone sufficient (since the type is already a separate tab)?
- [ ] Should `sortedOverviews` recompute via a `didSet` on `overviews` and a property observer on `sortOrder`, or explicitly via a helper called from both paths?
- [ ] Does `ExerciseSessionSnapshotView` need delete functionality (remove exercise from session), or is it read-only?
- [ ] Should `ExerciseHistoryView` show a chart (like the old `ExerciseProgressView` might have in future), or just the list for now?
