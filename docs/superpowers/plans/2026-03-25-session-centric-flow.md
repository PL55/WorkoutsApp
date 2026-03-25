# Session-Centric Flow Redesign

**Date:** 2026-03-25
**Status:** Spec

---

## Overview

Restructure the app around an explicit session lifecycle. Users start a named session, add exercises to it while it's active, then end it. Ended sessions are shown in a `Sessions` tab; exercise analytics (the current home screen) move to an `Exercises` tab and only reflect data from completed sessions.

---

## User-Facing Changes

### Tab Bar

Replace the current single-screen home with a two-tab structure:

| Tab | Content |
|-----|---------|
| **Sessions** | Active session (pinned at top) + completed sessions sorted by date descending |
| **Exercises** | Current home screen — exercise list with progress/analytics |

### Session Lifecycle

```
[Start Session] → active → [End Session] → completed
                         → [Cancel Session] → deleted
```

1. **Start Session** — user taps a button in the Sessions tab to create a new session. A `New Session` screen appears with a name field pre-filled with `YYYY-MM-DD-HH:mm` (local time). User can edit the name before confirming.

2. **Active Session** — appears pinned at the top of the Sessions tab. User taps it to open `SessionDetailView`, where they can add/delete exercises and rename the session. The session remains active until explicitly ended or cancelled.

3. **One active session at a time** — if the user taps "Start Session" while an active session exists, show an alert:
   > "You have an active session: \<name\>. End it or cancel it before starting a new one."
   > Actions: **End Session** | **Cancel Session** | **Dismiss**

4. **End Session** — marks the session as `.completed`. It moves from the pinned active slot to the completed list. Exercise data from this session becomes visible in the Exercises tab.

5. **Cancel Session** — deletes the session entirely (with a confirmation prompt). No data is retained.

6. **Completed sessions are editable** — the user can still add/delete exercises and rename a completed session after ending it. There is no lock on completed sessions.

7. **Rename** — available from `SessionDetailView` for both active and completed sessions (inline edit or a dedicated rename action).

### Exercises Tab

Identical to the current home screen. Only shows data from **completed** sessions. No change to UI — only the data filtering changes on the backend.

---

## Data Model Changes

### `WorkoutSession` (@Model) — new fields

```swift
// Add to WorkoutSession @Model:
var name: String           // user-editable; defaults to "YYYY-MM-DD-HH:mm"
var status: SessionStatus  // .active | .completed
```

```swift
enum SessionStatus: String, Codable {
    case active
    case completed
}
```

`SessionStatus` must be `Codable` and stored as a `String` raw value so SwiftData can persist it.

### `WorkoutSessionDTO` — mirror the new fields

The repository's private `toDTO()` extension maps both new fields onto the DTO. Views and ViewModels only ever reference `WorkoutSessionDTO` — they have no knowledge of the `@Model` layer.

```swift
// Add to WorkoutSessionDTO plain struct:
var name: String
var status: SessionStatus
```

`SessionStatus` is defined in `Utilities/` (not in the repository models) so it is importable by the DTO layer without pulling in SwiftData.

---

## Architecture Changes

### Repository Layer — `WorkoutsDBRepository`

New/changed methods:

```swift
// New
func startSession(name: String) async throws -> WorkoutSession
func endSession(_ session: WorkoutSession) async throws
func cancelSession(_ session: WorkoutSession) async throws
func renameSession(_ session: WorkoutSession, name: String) async throws
func fetchActiveSession() async throws -> WorkoutSessionDTO?

// Changed
func fetchSessions() async throws -> [WorkoutSessionDTO]
// Implementation: returns only .completed sessions (for Exercises tab / progress queries)

// New — for Sessions tab
func fetchAllSessions() async throws -> [WorkoutSessionDTO]
// Returns all sessions regardless of status
```

`progressEntries(for:)` already filters through completed session data implicitly since it queries `StrengthExercise`/`CardioExercise` linked to sessions — no change needed there as long as `addExercise` still works. However, the interactor should ensure that progress queries only traverse exercises belonging to completed sessions. Add a predicate filter on session status in the repository query.

### Interactor Layer — `WorkoutsInteractor`

```swift
protocol WorkoutsInteractor {
    // Existing (unchanged)
    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO]
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]

    // Changed
    func fetchSessions() async throws -> [WorkoutSessionDTO]         // completed only (Exercises tab)
    func fetchAllSessions() async throws -> [WorkoutSessionDTO]      // all (Sessions tab)
    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO

    // New
    func fetchActiveSession() async throws -> WorkoutSessionDTO?
    func startSession(name: String) async throws -> UUID
    func endSession(id: UUID) async throws
    func cancelSession(id: UUID) async throws
    func renameSession(id: UUID, name: String) async throws
    func deleteSession(id: UUID) async throws                        // existing, unchanged
}
```

### ViewModel Layer

#### `SessionListViewModel` (Sessions tab)

New responsibilities:
- Loads all sessions via `fetchAllSessions()`
- Exposes `activeSession: WorkoutSessionDTO?` and `completedSessions: [WorkoutSessionDTO]` (sorted by date descending)
- Exposes `startSession(name:)`, `endSession(id:)`, `cancelSession(id:)` actions
- `hasActiveSession: Bool` computed from `activeSession != nil`

#### `SessionDetailViewModel` (existing, extended)

New responsibilities:
- Exposes `renameSession(name:)` action
- Exposes `endSession()` and `cancelSession()` actions
- Exposes `session.status` so the view can show/hide the End/Cancel buttons

#### `ExercisesViewModel` (new — or reuse existing home screen VM if one exists)

The Exercises tab is the current home screen. If it already has a VM, no changes needed — it already queries completed-only data (once the repository filter is in place).

---

## New / Modified Screens

### `NewSessionView` (new)

- Single text field: "Session Name", pre-filled with `YYYY-MM-DD-HH:mm`
- "Start" button — calls `vm.startSession(name:)`, dismisses on success
- "Cancel" button — dismisses without action
- Sheet or NavigationStack push from Sessions tab

### `SessionListView` (modified)

- **Header slot**: if `activeSession != nil`, render an `ActiveSessionCard` at the top (distinct visual treatment — e.g., highlighted border, "ACTIVE" badge)
- **List**: completed sessions below, sorted date descending
- **FAB / toolbar button**: "New Session" → checks `hasActiveSession`; if true, shows the alert described above; otherwise presents `NewSessionView`

### `SessionDetailView` (modified)

- **Rename**: toolbar button or tap-on-title gesture opens an inline rename field or alert
- **End Session** button: visible for both active and completed sessions? No — show "End Session" only when `session.status == .active`. Show no lifecycle button for completed sessions (they're already done).
- **Cancel Session** button: destructive, visible only when `session.status == .active`. Presents a confirmation alert before deleting.
- Exercise add/delete works the same as today for both active and completed sessions.

---

## Migration

Adding `name` and `status` to `WorkoutSession` requires a SwiftData schema migration.

- `status` default: existing sessions should be migrated to `.completed` (they have no active lifecycle concept)
- `name` default: existing sessions can default to their formatted date string (e.g., format `date` as `YYYY-MM-DD-HH:mm`)
- This requires a `VersionedSchema` and `SchemaMigrationPlan` — lightweight migration with custom mapping for the defaults

---

## Testing

### New unit tests needed

| Test file | What to cover |
|-----------|--------------|
| `SessionListViewModelTests` | `activeSession` / `completedSessions` split; `startSession` when active exists (should not call interactor); `endSession` / `cancelSession` state transitions |
| `SessionDetailViewModelTests` | `renameSession`; `endSession`; `cancelSession` confirmation |
| `WorkoutsInteractorTests` | `startSession` delegates to repo; `endSession` sets status; `progressEntries` excludes active-session exercises |
| `WorkoutsDBRepositoryTests` | `fetchAllSessions` returns all; `fetchSessions` returns completed only; `startSession` sets `.active`; `endSession` sets `.completed`; `cancelSession` deletes |

### Existing tests to update

- `SessionListViewModelTests` — `loadSessions` now calls `fetchAllSessions`, not `fetchSessions`
- `WorkoutsInteractorTests` — `fetchSessions` mock expectation changes to completed-only
- Any test that creates a `WorkoutSession` fixture needs `name` and `status` fields

---

## Out of Scope

- Push notifications for session reminders
- Session templates / recurring sessions
- Sharing or exporting sessions
- Multiple concurrent active sessions
