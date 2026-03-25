# WorkoutsApp

Personal workout tracking iOS app — Clean Architecture + SwiftUI.

**Platform**: iOS 18.0+ (primary), macOS 12.0+ (UIKit limitations apply)
**Language**: Swift 5 mode, Swift 6.1 toolchain
**UI**: SwiftUI + Combine | **Persistence**: SwiftData (fully local)

---

## Architecture

```
RootView (Loadable<AppEnvironment>)
    └── View  →  ViewModel  →  Interactor  →  Repository
                    ↕DTO only
```

Four layers: **Presentation → ViewModel → Business Logic → Data Access**

### Core Standard: Views Never Touch Data Models

Views and ViewModels reference **only plain DTO structs** (`Models/DTOs/`). SwiftData `@Model` objects never leave the repository layer. The repository maps `@Model → DTO` via private `toDTO()` before returning data upward.

- Views have zero SwiftData dependency and can be tested without `ModelContainer`
- VMs own `Loadable<DTO>` state and re-fetch explicitly after mutations

### Launch Layer

`RootView` runs `AppEnvironment.bootstrap() async throws` as a `Loadable<AppEnvironment>` state machine:
- `.isLoading` → `ProgressView`
- `.loaded(env)` → renders app with real container + DI
- `.failed` → `ErrorView` with Retry (no silent in-memory fallback)

### Presentation Layer (`UI/`)

Pure SwiftUI views — no SwiftData imports, no computation in `body`. All state comes from VMs or local `Loadable<T>`.

| View | Notes |
|------|-------|
| `RootView` | Launch state machine |
| `SessionListView` | Delegates to `SessionListViewModel` |
| `SessionDetailView` | Takes `sessionID: UUID`; delegates to `SessionDetailViewModel` |
| `AddExerciseView` | Form; delegates to `AddExerciseViewModel` |
| `ExerciseProgressView` | No VM — uses `$progressState.load {}` directly |

### ViewModel Layer (`UI/<Feature>/`)

`@Observable @MainActor` classes. Views hold them via `@State`.

**Configure pattern** (`@Environment` unavailable at `@State` init time):
```swift
@State private var vm = SessionListViewModel()

.task {
    vm.configure(interactor: injected.interactors.workouts)
    await vm.loadSessions()
}
```

**Loadable in VMs** (no `Binding<Loadable<T>>` available inside `@Observable`):
```swift
func save() {
    let cancelBag = CancelBag()
    saveState.setIsLoading(cancelBag: cancelBag)
    let task = Task { [weak self] in   // always [weak self]
        guard let self else { return }
        do { saveState = .loaded(try await interactor.addExercise(...)) }
        catch { saveState = .failed(error) }
    }
    task.store(in: cancelBag)
}
```

### Business Logic Layer (`Interactors/`)

Protocol-based (`WorkoutsInteractor`). `RealWorkoutsInteractor` coordinates repo + caching. `StubWorkoutsInteractor` for previews/init.

### Data Access Layer (`Repositories/`)

`MainDBRepository` — `@ModelActor` for thread-safe SwiftData. Maps `@Model → DTO` before returning. No network layer.

---

## Key Utilities

| Utility | Purpose |
|---------|---------|
| `Loadable<T>` | Async state machine: `.notRequested / .isLoading / .loaded / .failed` |
| `CancelBag` | Manages `Task` + `Cancellable` refs; `cancel()` delivers cooperative cancellation |
| `Store<State>` | `CurrentValueSubject` alias + Binding dispatchers for routing |
| `DIContainer` | Holds `Store<AppState>` + `Interactors`; injected via `@Environment(\.injected)` |
| `AppState` | Routing only — no data state (VMs own data) |

**Loadable error equality**: uses `(NSError.domain, NSError.code)` — not `localizedDescription` — for stable SwiftUI re-render identity.

---

## Data Models

### @Model (persistence — never exposed to views)

| Model | Key details |
|-------|------------|
| `WorkoutSession` | Has `StrengthExercise` + `CardioExercise` (cascade delete) |
| `StrengthExercise` | `analyticsValue` = sets × reps × weight; `#Index` on `name` |
| `CardioExercise` | `analyticsValue` = duration; `#Index` on `name` |
| `ExerciseLibraryEntry` | Unique name + type; auto-saved on exercise add |
| `AppSchema` | SwiftData schema version (v1.0.0) |

### DTOs (plain structs — what views and VMs see)

`WorkoutSessionDTO`, `StrengthExerciseDTO`, `CardioExerciseDTO`, `ExerciseLibraryEntryDTO`, `ProgressEntry` (non-persisted).

`StrengthExerciseDTO` and `CardioExerciseDTO` conform to `AnalyticsTrackable` for polymorphic exercise display.

### Shared Enums (in `Utilities/` — importable by DTO layer without SwiftData)

`ExerciseType` (`strength | cardio`), `ExerciseInput` (passed VM → Interactor → Repository).

---

## File Organization

```
WorkoutsApp/
├── Core/                   App.swift, AppDelegate.swift, AppState.swift
├── DependencyInjection/    DIContainer.swift, AppEnvironment.swift
├── Interactors/            WorkoutsInteractor.swift (Protocol + Real + Stub)
├── Models/DTOs/            WorkoutSessionDTO, StrengthExerciseDTO, CardioExerciseDTO, ExerciseLibraryEntryDTO
├── Repositories/
│   ├── Database/           WorkoutsDBRepository.swift, ModelContainer.swift
│   └── Models/             WorkoutSession, StrengthExercise, CardioExercise, ExerciseLibraryEntry, AppSchema
├── UI/
│   ├── RootView.swift
│   ├── SessionList/        SessionListView, SessionListViewModel, SessionCell
│   ├── SessionDetail/      SessionDetailView, SessionDetailViewModel, ExerciseRow
│   ├── AddExercise/        AddExerciseView, AddExerciseViewModel
│   ├── ExerciseProgress/   ExerciseProgressView
│   └── Common/             ErrorView, RootViewModifier
└── Utilities/              Store, Loadable, CancelBag, ExerciseType, ExerciseInput, Helpers

UnitTests/
├── Mocks/                  Mock.swift, MockedInteractors, MockedDBRepositories
├── Interactors/            WorkoutsInteractorTests
├── Repositories/           WorkoutsDBRepositoryTests
├── UI/                     RootViewTests, SessionList*, SessionDetail*, AddExercise*, ExerciseProgress*
└── Utilities/              LoadableTests, HelpersTests
```

---

## Testing

| Level | Approach |
|-------|----------|
| ViewModels | Plain `@Observable` — inject `MockedWorkoutsInteractor` via `configure(interactor:)`; use DTO fixtures |
| Interactors | `MockedWorkoutsDBRepository` via `Mock` protocol; assert exact method calls via `verify()` |
| Repositories | Real `ModelContainer.mock` (in-memory SwiftData) |
| Views | `ViewInspector` for async state transitions; `Inspection` helper bridges `InspectionEmissary` |

**Framework**: Swift Testing (`@Suite`, `@Test`, `#expect`) — not XCTest.

---

## Build & Test

```bash
# Build: open WorkoutsApp.xcodeproj → select iOS Simulator → Cmd+R
# Test (Xcode): Cmd+U
xcodebuild test -scheme WorkoutsApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**SPM dependency**: `ViewInspector` 0.10.0+

**Troubleshooting**: SwiftData migration errors → delete app from simulator + `Cmd+Shift+K`. Missing ViewInspector → File → Packages → Reset Package Caches.

---

## Questions to Ask When Modifying

- [ ] Which layer? (View / ViewModel / Interactor / Repository)
- [ ] Am I passing a DTO, not an `@Model`, to the layer above?
- [ ] Does the repository need a new `toDTO()` mapping?
- [ ] Is computed/derived state in the ViewModel, not the view body?
- [ ] Do I need `Loadable`? Am I in a View (`$binding.load {}`) or VM (manual `Task + Loadable`)?
- [ ] Did I update protocol + real implementation + mock/stub?
- [ ] Did I add `[weak self]` in Task closures inside ViewModels?
- [ ] Is there a corresponding test?
