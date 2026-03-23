# WorkoutsApp

A personal workout tracking iOS app built with Clean Architecture and SwiftUI. Log workout sessions with strength and cardio exercises, track progress over time, and browse a personal exercise library.

**Platform**: iOS 18.0+ · **Language**: Swift 5 / Swift 6.1 toolchain · **Persistence**: SwiftData (fully local)

---

## Features

- **Session logging** — Create workout sessions and add unlimited strength or cardio exercises
- **Exercise library** — Auto-populated library of exercises you've used, with type-filtered autocomplete suggestions
- **Progress tracking** — Per-exercise historical chart showing volume (strength) or duration (cardio) over time
- **Offline-first** — All data stored locally on device in a SwiftData SQLite store; no accounts, no network

---

## Architecture Overview

The app follows Clean Architecture in four layers, with a dedicated ViewModel layer sitting between views and interactors.

```
RootView (launch state machine)
    │
    ▼
SwiftUI Views  ──onChange──▶  ViewModels (@Observable)
    │                              │
    │ @Query (reads)               │ interactor calls
    │                              ▼
    └──────────────────────▶  Interactors (business logic)
                                   │
                                   ▼
                             Repositories (SwiftData)
```

### Presentation Layer — Views

Views are pure functions of state. They own `@Query` for live SwiftData results and forward those results into their ViewModel via `onChange`. Side effects (save, delete) are delegated to the ViewModel.

| View | Role |
|---|---|
| `RootView` | Launch state machine — shows loading/error/retry before the app is ready |
| `SessionListView` | Session list grouped by date; pull-to-refresh; delete sessions |
| `SessionDetailView` | All exercises for a session (strength + cardio unified) |
| `AddExerciseView` | Form for adding exercises; type picker; autocomplete suggestions |
| `ExerciseProgressView` | Historical analytics chart per exercise name |

### ViewModel Layer

`@Observable @MainActor` classes that own derived state and interactor references. The view body reads cached stored properties — no recomputation on unrelated renders.

| ViewModel | Derived State |
|---|---|
| `SessionListViewModel` | `groupedSessions` — sessions keyed by calendar day, sorted newest-first |
| `SessionDetailViewModel` | `allExercises` — strength + cardio merged into `[any AnalyticsTrackable]` |
| `AddExerciseViewModel` | `filteredSuggestions` — library entries matching current type and name prefix; `saveState: Loadable<UUID>` |

`ExerciseProgressView` has no ViewModel — it is already clean (`Loadable` + `onAppear`, no inline computation).

### Business Logic Layer — Interactors

`WorkoutsInteractor` is a protocol with one real implementation (`RealWorkoutsInteractor`) and one stub (`StubWorkoutsInteractor`). The interactor coordinates between the repository and the exercise library cache.

### Data Access Layer — Repositories

`WorkoutsDBRepository` is a protocol implemented by `MainDBRepository`, a `@ModelActor`-isolated SwiftData wrapper. All writes are async and thread-safe.

---

## Data Storage

All data lives **locally on your device** in SwiftData (SQLite under the hood):

| Model | What it stores |
|---|---|
| `WorkoutSession` | Date + name; parent of all exercises (cascade delete) |
| `StrengthExercise` | Name, sets, reps, weight — linked to a session |
| `CardioExercise` | Name, duration — linked to a session |
| `ExerciseLibraryEntry` | Unique exercise names you've used (powers autocomplete) |

`StrengthExercise` and `CardioExercise` both carry a SwiftData `#Index` on their `name` property, so progress queries scan the index rather than the full table as your log grows.

Deleting the app permanently deletes all workout data — there is no iCloud sync or backup mechanism.

---

## App Launch Flow

```
App.swift
  └─ RootView
       ├─ .notRequested / .isLoading  →  ProgressView("Loading...")
       │       │
       │       └─ AppEnvironment.bootstrap() async throws
       │               • creates ModelContainer (off main thread)
       │               • wires MainDBRepository, RealWorkoutsInteractor, DIContainer
       │
       ├─ .loaded(env)  →  SessionListView (real container + DI injected)
       │
       └─ .failed(error)  →  Error screen + Retry button
```

Bootstrap errors are surfaced with a Retry button rather than silently falling back to an in-memory database — preventing silent data loss.

---

## Key Design Decisions

### ViewModels alongside @Query

`@Query` can't live inside an `@Observable` class — it requires a SwiftUI View context. Views own `@Query` and forward raw results into the ViewModel via `onChange`. The VM computes derived state once (on data change) and caches it. The view body reads a stored property, so unrelated renders don't re-run grouping or filtering logic.

### Async bootstrap

`ModelContainer` initialization previously blocked `@MainActor` on the first frame. Moving `bootstrap()` to `async throws` lets the main thread stay responsive while the SQLite store opens. `RootView` shows a `ProgressView` during this window.

### Loadable<T> state machine

Async operations are modeled as a four-state enum (`notRequested / isLoading / loaded / failed`) rather than separate `isLoading: Bool` and `error: Error?` flags. This eliminates impossible state combinations and maps cleanly to SwiftUI `switch` expressions.

Inside `@Observable` ViewModels, `Loadable` is managed manually (`Task + [weak self]`) since the `$binding.load {}` helper requires a SwiftUI `Binding`.

### Error equality by (domain, code)

Comparing `Loadable.failed` errors via `localizedDescription` caused SwiftUI to skip re-renders when the error changed but the message stayed the same. Using `NSError.domain + NSError.code` provides stable, unique error identity.

### CancelBag actually cancels

`CancelBag.cancel()` previously called `removeAll()` without calling `.cancel()` on stored tasks, so background work continued running after "cancellation". Each stored item now receives a cooperative cancellation signal before its reference is removed.

---

## Building

### Requirements

- Xcode 16.0+
- iOS 18.0+ simulator or physical device

### Run

```bash
open WorkoutsApp.xcodeproj
# Select an iOS Simulator (or paired device) → Cmd+R
```

SPM dependencies are fetched automatically:
- [`ViewInspector`](https://github.com/nalexn/ViewInspector) 0.10.0+

### Test

```bash
# In Xcode
Cmd+U

# CLI
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Tests use the **Swift Testing** framework (`@Suite`, `@Test`, `#expect`).

### Troubleshooting

| Problem | Fix |
|---|---|
| SwiftData migration error at launch | Delete app from simulator → `Cmd+Shift+K` → rebuild |
| `No such module 'ViewInspector'` | File → Packages → Reset Package Caches |
| Build fails on macOS | Select an iOS Simulator destination — UIKit dependencies prevent macOS builds |
| Build fails on device, works on simulator | Check `Signing & Capabilities` → verify Team is selected and device runs iOS 18.0+ |

---

## Project Structure

```
WorkoutsApp/
├── Core/                   # App entry point, AppDelegate, AppState
├── DependencyInjection/    # DIContainer, AppEnvironment (async bootstrap)
├── Interactors/            # WorkoutsInteractor protocol + implementations
├── Repositories/
│   ├── Database/           # WorkoutsDBRepository + ModelContainer
│   └── Models/             # SwiftData @Model types + ProgressEntry struct
├── UI/
│   ├── RootView.swift      # Launch state machine
│   ├── SessionList/        # View + ViewModel
│   ├── SessionDetail/      # View + ViewModel
│   ├── AddExercise/        # View + ViewModel
│   ├── ExerciseProgress/   # View only (no VM needed)
│   └── Common/             # ErrorView, Query+Search, RootViewModifier
└── Utilities/              # Store, Loadable, CancelBag, ExerciseType, ExerciseInput, Helpers

UnitTests/
├── Mocks/                  # MockedInteractors, MockedDBRepositories
├── Interactors/            # WorkoutsInteractorTests
├── Repositories/           # WorkoutsDBRepositoryTests (in-memory ModelContainer)
├── UI/                     # ViewInspector tests + ViewModel unit tests
└── Utilities/              # LoadableTests, HelpersTests
```
