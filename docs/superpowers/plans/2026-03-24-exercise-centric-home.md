# Exercise-Centric Home — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-03-24-exercise-centric-home-design.md`
**Branch:** `feature/exercise-centric-home` (create before Step 1)

---

## Phase 1 — Data Foundation

**Step 1: `ProgressEntry` — add `sessionID`**
- `Repositories/Models/ProgressEntry.swift`: add `sessionID: UUID`
- `Repositories/Database/WorkoutsDBRepository.swift`: populate `sessionID` from `e.session!.id` in `progressEntries(for:)`; add deduplication (group by `sessionID`, keep highest `analyticsValue` per group) before final sort

**Step 2: `ExerciseOverviewDTO`**
- New file: `Models/DTOs/ExerciseOverviewDTO.swift`
- Fields: `id: String` (name), `name`, `exerciseType`, `bestValue`, `latestValue`, `lastDate`, `analyticsLabel`

**Step 3: `fetchExerciseOverviews` — repo + interactor + stubs + mocks**
- `WorkoutsDBRepository` protocol: add `fetchExerciseOverviews(type: ExerciseType) async throws -> [ExerciseOverviewDTO]`
- `MainDBRepository`: single `FetchDescriptor` pass, group by name in Swift, compute `bestValue`/`latestValue`/`lastDate`, exclude orphans
- `WorkoutsInteractor` protocol + `RealWorkoutsInteractor`: thin pass-through
- `StubWorkoutsInteractor`: return `[]`
- `MockedWorkoutsInteractor` + `MockedWorkoutsDBRepository`: add action + result

**Step 4: `Loadable.value` computed property**
- `Utilities/Loadable.swift`: add `var value: T? { if case .loaded(let v) = self { return v }; return nil }` — skip if already present

---

## Phase 2 — ViewModels

**Step 5: `ExerciseListViewModel`**
- New file: `UI/ExerciseList/ExerciseListViewModel.swift`
- `SortOrder` enum (alphabetical / mostRecent / leastRecent) in same file
- `sortOrder` with `didSet` → calls `sorted(_:)` → updates `sortedOverviews`
- `loadOverviews(type:)` → manual Task + Loadable → calls `sorted(_:)` on success

**Step 6: `ExerciseHistoryViewModel`**
- New file: `UI/ExerciseHistory/ExerciseHistoryViewModel.swift`
- `loadEntries(for: String)` → manual Task + Loadable → `interactor.progressEntries(for:)`

**Step 7: `ExerciseSessionSnapshotViewModel`**
- New file: `UI/ExerciseSessionSnapshot/ExerciseSessionSnapshotViewModel.swift`
- `loadSession(id: UUID)` → manual Task + Loadable → `interactor.fetchSession(id:)`

---

## Phase 3 — Views

**Step 8: `ExerciseTileView`**
- New file: `UI/ExerciseList/ExerciseTileView.swift`
- Display-only: name, best value, latest value, last date

**Step 9: `ExerciseHistoryView`**
- New file: `UI/ExerciseHistory/ExerciseHistoryView.swift`
- List of `ProgressEntry` rows as `NavigationLink` → `ExerciseSnapshotDestination`
- Mixed-type warning, empty state, error state
- `.task` → `vm.configure` + `vm.loadEntries`

**Step 10: `ExerciseSessionSnapshotView`**
- New file: `UI/ExerciseSessionSnapshot/ExerciseSessionSnapshotView.swift`
- Strength path: extract from `session.strengthExercises` by name, show sets/reps/weight
- Cardio path: extract from `session.cardioExercises` by name, show duration
- "View Full Session" toolbar button → `SessionDetailDestination`
- `.task` → `vm.configure` + `vm.loadSession`

**Step 11: `ExerciseListView`**
- New file: `UI/ExerciseList/ExerciseListView.swift`
- Segmented picker (Strength/Cardio); `.task` + `.onChange(of: selectedType)` for load
- Sort button (cycles `vm.sortOrder`); `+` button → `AddExerciseDestination`
- All `navigationDestination` registrations (SessionDetail, AddExercise, ExerciseHistory, ExerciseSnapshot)
- Move `SessionDetailDestination`, `AddExerciseDestination` here (from SessionListView.swift)
- New: `ExerciseHistoryDestination`, `ExerciseSnapshotDestination`
- `ExerciseList.Routing` empty struct + `typealias ExerciseList = ExerciseListView`

---

## Phase 4 — Wire Up & Delete

**Step 12: Update `AppState` + `RootView`**
- `Core/AppState.swift`: rename `sessionList → exerciseList`, update type to `ExerciseList.Routing`
- `UI/RootView.swift`: replace `SessionListView(...)` with `ExerciseListView(...)`

**Step 13: Update `SessionDetailView`**
- Replace `ExerciseProgressDestination` push with `ExerciseHistoryDestination(exerciseName: exercise.name, exerciseType: exercise.exerciseType)`
- Remove `navigationDestination(for: ExerciseProgressDestination.self)` registration (now lives in `ExerciseListView`)

**Step 14: Delete old files**
- `UI/SessionList/SessionListView.swift`
- `UI/SessionList/SessionListViewModel.swift`
- `UI/SessionList/SessionCell.swift`
- `UI/ExerciseProgress/ExerciseProgressView.swift`

---

## Phase 5 — Tests

**Step 15: New ViewModel tests**
- `ExerciseListViewModelTests`: sort transitions, loadOverviews states, sortedOverviews recomputes without re-fetch
- `ExerciseHistoryViewModelTests`: loadEntries states
- `ExerciseSessionSnapshotViewModelTests`: loadSession states, exercise extraction by name+type

**Step 16: New interactor + repository tests**
- Interactor: `fetchExerciseOverviews(type:)` calls correct repo method
- Repository: bestValue/latestValue/lastDate correctness; orphan exclusion; deduplication in `progressEntries`

**Step 17: New UI tests**
- `ExerciseListViewTests`, `ExerciseHistoryViewTests`, `ExerciseSessionSnapshotViewTests`

**Step 18: Delete old test files**
- `UnitTests/UI/SessionListTests.swift`
- `UnitTests/UI/SessionListViewModelTests.swift`
- `UnitTests/UI/ExerciseProgressViewTests.swift`
