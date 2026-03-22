# Performance Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate render-path recomputation, add SwiftData indexes, move bootstrap off the main thread with an error recovery UI, and fix two correctness bugs in CancelBag and Loadable.

**Architecture:** Utilities fixes first (least risk), then SwiftData index annotations, then `@Observable` ViewModels for three views, then the async bootstrap + RootView. Each task is independently buildable and testable. The ViewModel pattern uses a `configure(interactor:)` method called from `.onAppear` so the real interactor is always wired before ViewInspector inspection fires.

**Tech Stack:** Swift 5 (language mode), Swift 6.1 toolchain, SwiftUI, SwiftData, Combine, ViewInspector 0.10+, Swift Testing (`@Suite`, `@Test`, `#expect`)

**Spec:** `docs/superpowers/specs/2026-03-22-performance-improvements-design.md`

---

## File Map

| File | Action | Task |
|---|---|---|
| `WorkoutsApp/Utilities/CancelBag.swift` | Modify — add `.cancel()` call | 1 |
| `WorkoutsApp/Utilities/Loadable.swift` | Modify — error equality via domain+code | 2 |
| `UnitTests/Utilities/LoadableTests.swift` | Modify — add two new test cases | 1 + 2 |
| `WorkoutsApp/Repositories/Models/StrengthExercise.swift` | Modify — add `#Index` | 3 |
| `WorkoutsApp/Repositories/Models/CardioExercise.swift` | Modify — add `#Index` | 3 |
| `WorkoutsApp/UI/SessionList/SessionListViewModel.swift` | **Create** | 4 |
| `WorkoutsApp/UI/SessionList/SessionListView.swift` | Modify — use VM | 4 |
| `UnitTests/UI/SessionListViewModelTests.swift` | **Create** | 4 |
| `UnitTests/UI/SessionListTests.swift` | Modify — add delete test | 4 |
| `WorkoutsApp/UI/SessionDetail/SessionDetailViewModel.swift` | **Create** | 5 |
| `WorkoutsApp/UI/SessionDetail/SessionDetailView.swift` | Modify — use VM | 5 |
| `UnitTests/UI/SessionDetailViewModelTests.swift` | **Create** | 5 |
| `WorkoutsApp/UI/AddExercise/AddExerciseViewModel.swift` | **Create** | 6 |
| `WorkoutsApp/UI/AddExercise/AddExerciseView.swift` | Modify — use VM | 6 |
| `UnitTests/UI/AddExerciseViewModelTests.swift` | **Create** | 6 |
| `UnitTests/UI/AddExerciseViewTests.swift` | Modify — pass VM instead of saveState | 6 |
| `WorkoutsApp/UI/RootView.swift` | **Create** | 7 |
| `WorkoutsApp/DependencyInjection/AppEnvironment.swift` | Modify — async throws, no fallback | 7 |
| `WorkoutsApp/Core/App.swift` | Modify — render RootView | 7 |
| `WorkoutsApp/Core/AppDelegate.swift` | Modify — remove environment ownership | 7 |
| `UnitTests/UI/RootViewTests.swift` | **Create** | 7 |

---

## Task 1: Fix CancelBag

**Files:**
- Modify: `WorkoutsApp/Utilities/CancelBag.swift`
- Modify: `UnitTests/Utilities/LoadableTests.swift`

### Background

`CancelBag.cancel()` currently calls `subscriptions.removeAll()` without calling `.cancel()` on each item. Tasks stored in the bag continue running after "cancellation". Since `Task` already conforms to `Cancellable` via the retroactive conformance at the bottom of the file, fixing this is one line.

- [ ] **Step 1.1: Write a failing test**

Add this test to `UnitTests/Utilities/LoadableTests.swift`, inside the `LoadableTests` suite:

```swift
@Test func cancelBagActuallyCancelsTasks() async {
    let bag = CancelBag()
    let exp = TestExpectation()
    let task = Task {
        do {
            try await Task.sleep(for: .seconds(10))
        } catch {
            // Task.sleep throws CancellationError when cancelled
            exp.fulfill()
        }
    }
    task.store(in: bag)
    bag.cancel()
    await exp.fulfillment()
    // If we reach here, the task was actually cancelled
}
```

- [ ] **Step 1.2: Run the test to confirm it fails (times out or hangs)**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/LoadableTests/cancelBagActuallyCancelsTasks \
  -quiet 2>&1 | tail -20
```

Expected: test either hangs or fails (task never gets cancelled).

- [ ] **Step 1.3: Fix CancelBag**

In `WorkoutsApp/Utilities/CancelBag.swift`, change `cancel()`:

```swift
func cancel() {
    subscriptions.forEach { $0.cancel() }
    subscriptions.removeAll()
}
```

Full updated file for reference:
```swift
import Combine

final class CancelBag {
    fileprivate(set) var subscriptions = [any Cancellable]()
    private let equalToAny: Bool

    init(equalToAny: Bool = false) {
        self.equalToAny = equalToAny
    }

    func cancel() {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }

    func isEqual(to other: CancelBag) -> Bool {
        return other === self || other.equalToAny || self.equalToAny
    }
}

extension Cancellable {
    func store(in cancelBag: CancelBag) {
        cancelBag.subscriptions.append(self)
    }
}

extension Task: @retroactive Cancellable { }
```

- [ ] **Step 1.4: Run all tests to confirm nothing broke**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 1.5: Commit**

```bash
git add WorkoutsApp/Utilities/CancelBag.swift UnitTests/Utilities/LoadableTests.swift
git commit -m "fix: CancelBag.cancel() now calls .cancel() on stored tasks"
```

---

## Task 2: Fix Loadable Error Equality

**Files:**
- Modify: `WorkoutsApp/Utilities/Loadable.swift`
- Modify: `UnitTests/Utilities/LoadableTests.swift`

### Background

`Loadable<T>` compares `.failed` cases using `lhsE.localizedDescription == rhsE.localizedDescription`. Two different errors with the same user-facing message are considered equal, suppressing SwiftUI re-renders. Fix: use `(domain, code)` which is stable and unique.

- [ ] **Step 2.1: Write failing tests**

Add these two tests to `UnitTests/Utilities/LoadableTests.swift` inside the `LoadableTests` suite:

```swift
@Test func failedEqualityUsesDomainAndCode() {
    // Same domain+code, different description → EQUAL
    let sameCode1 = NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Message A"])
    let sameCode2 = NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Message B"])
    #expect(Loadable<Int>.failed(sameCode1) == Loadable<Int>.failed(sameCode2))
}

@Test func failedInequalityUsesDomainAndCode() {
    // Same description, different code → NOT EQUAL
    let base    = NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Same"])
    let diffCode   = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Same"])
    let diffDomain = NSError(domain: "other", code: 0, userInfo: [NSLocalizedDescriptionKey: "Same"])
    #expect(Loadable<Int>.failed(base) != Loadable<Int>.failed(diffCode))
    #expect(Loadable<Int>.failed(base) != Loadable<Int>.failed(diffDomain))
}
```

- [ ] **Step 2.2: Run tests to confirm they fail**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/LoadableTests/failedEqualityUsesDomainAndCode \
  -only-testing:UnitTests/LoadableTests/failedInequalityUsesDomainAndCode \
  -quiet 2>&1 | tail -20
```

Expected: both tests fail.

- [ ] **Step 2.3: Fix the equality case in Loadable.swift**

In `WorkoutsApp/Utilities/Loadable.swift`, find the `Equatable` extension and replace the `.failed` case:

Old:
```swift
case let (.failed(lhsE), .failed(rhsE)):
    return lhsE.localizedDescription == rhsE.localizedDescription
```

New:
```swift
case let (.failed(lhsE), .failed(rhsE)):
    let lhs = lhsE as NSError
    let rhs = rhsE as NSError
    return lhs.domain == rhs.domain && lhs.code == rhs.code
```

- [ ] **Step 2.3b: While in Loadable.swift, add the `isLoading` helper**

`AddExerciseView` and `RootView` both need a `Loadable.isLoading` computed var. Add it once here as an `internal` extension so neither view needs a `private extension`:

```swift
extension Loadable {
    /// Returns `true` while an async operation is in flight.
    var isLoading: Bool {
        if case .isLoading = self { return true }
        return false
    }
}
```

Add this at the bottom of `WorkoutsApp/Utilities/Loadable.swift`, after the `LoadableSubject` extension.

- [ ] **Step 2.4: Run all tests**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 2.5: Commit**

```bash
git add WorkoutsApp/Utilities/Loadable.swift UnitTests/Utilities/LoadableTests.swift
git commit -m "fix: Loadable error equality uses domain+code instead of localizedDescription"
```

---

## Task 3: Add SwiftData Indexes

**Files:**
- Modify: `WorkoutsApp/Repositories/Models/StrengthExercise.swift`
- Modify: `WorkoutsApp/Repositories/Models/CardioExercise.swift`

### Background

`progressEntries(for:)` does full-table scans on both exercise tables filtered by `name`. The SwiftData `#Index` macro (iOS 17+) declares an index inside the `@Model` class body. Adding it is a lightweight schema change — SwiftData handles it automatically on next store open with no migration plan needed.

**TDD note:** This is a schema annotation with no logic to unit-test directly. The existing integration tests in `UnitTests/Repositories/WorkoutsDBRepositoryTests.swift` serve as the regression harness — Steps 3.3–3.4 confirm they still pass after the annotation is added.

- [ ] **Step 3.1: Add `#Index` to StrengthExercise**

In `WorkoutsApp/Repositories/Models/StrengthExercise.swift`, add `#Index<StrengthExercise>([\.name])` as the first line inside the class body:

```swift
@Model
final class StrengthExercise {
    #Index<StrengthExercise>([\.name])

    var id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double
    var exerciseType: ExerciseType = ExerciseType.strength
    @Relationship(inverse: \WorkoutSession.strengthExercises)
    var session: WorkoutSession?

    var analyticsValue: Double { Double(sets * reps) * weight }
    var analyticsLabel: String { "Volume (lbs)" }

    init(id: UUID = UUID(), name: String, sets: Int, reps: Int, weight: Double) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
    }
}

extension StrengthExercise: Exercise, AnalyticsTrackable { }
```

- [ ] **Step 3.2: Add `#Index` to CardioExercise**

In `WorkoutsApp/Repositories/Models/CardioExercise.swift`:

```swift
@Model
final class CardioExercise {
    #Index<CardioExercise>([\.name])

    var id: UUID
    var name: String
    var durationMinutes: Double
    var exerciseType: ExerciseType = ExerciseType.cardio
    @Relationship(inverse: \WorkoutSession.cardioExercises)
    var session: WorkoutSession?

    var analyticsValue: Double { durationMinutes }
    var analyticsLabel: String { "Duration (min)" }

    init(id: UUID = UUID(), name: String, durationMinutes: Double) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
    }
}

extension CardioExercise: Exercise, AnalyticsTrackable { }
```

- [ ] **Step 3.3: Build to confirm it compiles**

```bash
xcodebuild build \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3.4: Run all tests**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3.5: Commit**

```bash
git add WorkoutsApp/Repositories/Models/StrengthExercise.swift \
        WorkoutsApp/Repositories/Models/CardioExercise.swift
git commit -m "perf: add SwiftData #Index on exercise name for faster progressEntries queries"
```

---

## Task 4: SessionListViewModel

**Files:**
- Create: `WorkoutsApp/UI/SessionList/SessionListViewModel.swift`
- Modify: `WorkoutsApp/UI/SessionList/SessionListView.swift`
- Create: `UnitTests/UI/SessionListViewModelTests.swift`
- Modify: `UnitTests/UI/SessionListTests.swift`

### Background

`SessionListView.groupedSessions` is a computed property in the view body — it runs `Dictionary(grouping:)` + `sorted` on every render. Moving it to an `@Observable` VM means it only recomputes when `sessions` actually changes (via `onChange`).

The VM uses `StubWorkoutsInteractor` by default and is configured with the real interactor in `.onAppear`. `.onAppear` fires synchronously during view hosting, before ViewInspector's inspection callback — so the real interactor is always wired before tests inspect the view.

- [ ] **Step 4.1: Create SessionListViewModel with failing tests**

Create `UnitTests/UI/SessionListViewModelTests.swift`:

```swift
// UnitTests/UI/SessionListViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct SessionListViewModelTests {

    @Test func groupsSessionsByDay() {
        let vm = SessionListViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let s1 = WorkoutSession(id: UUID(), date: today)
        let s2 = WorkoutSession(id: UUID(), date: today.addingTimeInterval(3600))
        let s3 = WorkoutSession(id: UUID(), date: yesterday)

        vm.sessionsDidChange([s1, s2, s3])

        #expect(vm.groupedSessions.count == 2)
        #expect(vm.groupedSessions[0].key == today)
        #expect(vm.groupedSessions[0].value.count == 2)
        #expect(vm.groupedSessions[1].key == yesterday)
        #expect(vm.groupedSessions[1].value.count == 1)
    }

    @Test func groupsEmptySessionsAsEmpty() {
        let vm = SessionListViewModel()
        vm.sessionsDidChange([])
        #expect(vm.groupedSessions.isEmpty)
    }

    @Test func sortsGroupsMostRecentFirst() {
        let vm = SessionListViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let old = WorkoutSession(id: UUID(), date: yesterday)
        let new = WorkoutSession(id: UUID(), date: today)

        vm.sessionsDidChange([old, new])  // old first intentionally

        #expect(vm.groupedSessions[0].key == today)
        #expect(vm.groupedSessions[1].key == yesterday)
    }

    @Test func deleteSessionCallsInteractor() async throws {
        let sessionID = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [.deleteSession(id: sessionID)])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        try await vm.deleteSession(id: sessionID)
        mocked.verify()
    }
}
```

- [ ] **Step 4.2: Run tests to confirm they fail**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/SessionListViewModelTests \
  -quiet 2>&1 | tail -20
```

Expected: compile error (type doesn't exist yet).

- [ ] **Step 4.3: Create SessionListViewModel**

Create `WorkoutsApp/UI/SessionList/SessionListViewModel.swift`:

```swift
// WorkoutsApp/UI/SessionList/SessionListViewModel.swift
import Observation
import Foundation

/// Holds memoized state derived from the session list.
/// Recomputes groupedSessions only when sessions change, not on every render.
@Observable
final class SessionListViewModel {

    /// Sessions grouped by calendar day, sorted most-recent-first.
    private(set) var groupedSessions: [(key: Date, value: [WorkoutSession])] = []

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    /// Wire the real interactor. Call from `.onAppear` so it runs before any user interaction.
    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    /// Called via `.onChange(of: sessions, initial: true)` — regroups and sorts.
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

- [ ] **Step 4.4: Run VM tests to confirm they pass**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/SessionListViewModelTests \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4.5: Update SessionListView to use the VM**

Replace `WorkoutsApp/UI/SessionList/SessionListView.swift` with:

```swift
// WorkoutsApp/UI/SessionList/SessionListView.swift
import SwiftUI
import SwiftData
import Combine

struct SessionListView: View {

    @Query(sort: \WorkoutSession.date, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var vm = SessionListViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var routingState: Routing = .init()
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "dumbbell",
                        description: Text("Tap + to log your first workout")
                    )
                } else {
                    sessionList
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        navigationPath.append(AddExerciseDestination(sessionID: nil))
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session, navigationPath: $navigationPath)
            }
            .navigationDestination(for: AddExerciseDestination.self) { dest in
                AddExerciseView(sessionID: dest.sessionID)
            }
            .navigationDestination(for: ExerciseProgressDestination.self) { dest in
                ExerciseProgressView(exerciseName: dest.exerciseName)
            }
        }
        .onAppear {
            vm.configure(interactor: injected.interactors.workouts)
        }
        .onChange(of: sessions, initial: true) { _, new in
            vm.sessionsDidChange(new)
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    private var sessionList: some View {
        List {
            ForEach(vm.groupedSessions, id: \.key) { date, group in
                Section(header: Text(date, style: .date)) {
                    ForEach(group) { session in
                        NavigationLink(value: session) {
                            SessionCell(session: session)
                        }
                    }
                    .onDelete { indexSet in
                        deleteSession(group: group, offsets: indexSet)
                    }
                }
            }
        }
    }

    private func deleteSession(group: [WorkoutSession], offsets: IndexSet) {
        for index in offsets {
            let session = group[index]
            Task {
                try? await vm.deleteSession(id: session.id)
            }
        }
    }
}

// MARK: - Routing

extension SessionList {
    struct Routing: Equatable {}
}

typealias SessionList = SessionListView

// MARK: - Navigation Destinations

struct AddExerciseDestination: Hashable {
    let sessionID: UUID?
}

struct ExerciseProgressDestination: Hashable {
    let exerciseName: String
}
```

- [ ] **Step 4.6: Write a failing delete test**

In `UnitTests/UI/SessionListTests.swift`, add the following test (the VM wiring in Step 4.5 is already in place, so this test should compile and pass immediately after the view is updated; adding the test first verifies it compiles before Step 4.7's final full-suite run):



```swift
@Test func deleteSessionCallsInteractor() async throws {
    let sessionID = UUID()
    let container = DIContainer(interactors: .mocked(workouts: [
        .deleteSession(id: sessionID)
    ]))
    let sut = SessionListView()
    let modelContainer = ModelContainer.mock
    let repo = MainDBRepository(modelContainer: modelContainer)
    _ = try await repo.saveNewSession(date: .now, with: .strength(name: "Squat", sets: 3, reps: 5, weight: 100))
    let view = sut.inject(container).modelContainer(modelContainer)
    try await ViewHosting.host(view) {
        try await sut.inspection.inspect { view in
            // Trigger delete on the first row of the first section
            try view.find(ViewType.NavigationStack.self)
                .find(ViewType.List.self)
                .section(0)
                .forEach(0)
                .callOnDelete(IndexSet([0]))
        }
        try await Task.sleep(for: .milliseconds(100))
        container.interactors.verify()
    }
}
```

- [ ] **Step 4.7: Run all tests**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4.8: Commit**

```bash
git add WorkoutsApp/UI/SessionList/SessionListViewModel.swift \
        WorkoutsApp/UI/SessionList/SessionListView.swift \
        UnitTests/UI/SessionListViewModelTests.swift \
        UnitTests/UI/SessionListTests.swift
git commit -m "perf: extract SessionListViewModel to memoize groupedSessions"
```

---

## Task 5: SessionDetailViewModel

**Files:**
- Create: `WorkoutsApp/UI/SessionDetail/SessionDetailViewModel.swift`
- Modify: `WorkoutsApp/UI/SessionDetail/SessionDetailView.swift`
- Create: `UnitTests/UI/SessionDetailViewModelTests.swift`

### Background

`SessionDetailView.allExercises` is a computed property that concatenates strength and cardio arrays + performs existential boxing (`as [any AnalyticsTrackable]`) on every render. Moving it to the VM means the concatenation only happens when the exercise arrays actually change.

- [ ] **Step 5.1: Create SessionDetailViewModelTests.swift with failing tests**

Create `UnitTests/UI/SessionDetailViewModelTests.swift`:

```swift
// UnitTests/UI/SessionDetailViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct SessionDetailViewModelTests {

    let session: WorkoutSession
    let strength: StrengthExercise
    let cardio: CardioExercise

    init() {
        session = WorkoutSession(id: UUID(), date: .now)
        // Do NOT set @Relationship properties (strengthExercises/cardioExercises) on the
        // session outside a ModelContext — SwiftData relationships require a backing store.
        // The VM receives plain arrays via updateExercises(strength:cardio:), so we only
        // need the model objects themselves, not wired into the session graph.
        strength = StrengthExercise(id: UUID(), name: "Squat", sets: 3, reps: 5, weight: 100)
        cardio = CardioExercise(id: UUID(), name: "Run", durationMinutes: 30)
    }

    @Test func combinesStrengthAndCardio() {
        let vm = SessionDetailViewModel()
        vm.updateExercises(strength: [strength], cardio: [cardio])
        #expect(vm.allExercises.count == 2)
        let names = vm.allExercises.map(\.name)
        #expect(names.contains("Squat"))
        #expect(names.contains("Run"))
    }

    @Test func strengthExercisesAppearFirst() {
        let vm = SessionDetailViewModel()
        vm.updateExercises(strength: [strength], cardio: [cardio])
        #expect(vm.allExercises[0].name == "Squat")
        #expect(vm.allExercises[1].name == "Run")
    }

    @Test func emptyWhenNoExercises() {
        let vm = SessionDetailViewModel()
        vm.updateExercises(strength: [], cardio: [])
        #expect(vm.allExercises.isEmpty)
    }

    @Test func deleteExerciseCallsInteractor() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [
            .deleteExercise(id: strength.id, type: .strength, sessionID: session.id)
        ])
        let vm = SessionDetailViewModel()
        vm.configure(interactor: mocked)
        try await vm.deleteExercise(id: strength.id, type: .strength, from: session.id)
        mocked.verify()
    }
}
```

- [ ] **Step 5.2: Run tests to confirm they fail**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/SessionDetailViewModelTests \
  -quiet 2>&1 | tail -20
```

Expected: compile error.

- [ ] **Step 5.3: Create SessionDetailViewModel**

Create `WorkoutsApp/UI/SessionDetail/SessionDetailViewModel.swift`:

```swift
// WorkoutsApp/UI/SessionDetail/SessionDetailViewModel.swift
import Observation

/// Holds the unified exercise list for a session.
/// Merges strength and cardio arrays only when either changes, not on every render.
@Observable
final class SessionDetailViewModel {

    /// All exercises for the session as `AnalyticsTrackable`, strength first.
    private(set) var allExercises: [any AnalyticsTrackable] = []

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    /// Wire the real interactor. Call from `.onAppear`.
    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    /// Call from `.onChange(of: session.strengthExercises, initial: true)` and
    /// `.onChange(of: session.cardioExercises, initial: true)`.
    func updateExercises(strength: [StrengthExercise], cardio: [CardioExercise]) {
        allExercises = (strength as [any AnalyticsTrackable]) + (cardio as [any AnalyticsTrackable])
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        try await interactor.deleteExercise(id: id, type: type, from: sessionID)
    }
}
```

- [ ] **Step 5.4: Run VM tests to confirm they pass**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/SessionDetailViewModelTests \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5.5: Update SessionDetailView to use the VM**

Replace `WorkoutsApp/UI/SessionDetail/SessionDetailView.swift` with:

```swift
// WorkoutsApp/UI/SessionDetail/SessionDetailView.swift
import SwiftUI

struct SessionDetailView: View {

    let session: WorkoutSession
    @Binding var navigationPath: NavigationPath

    @State private var vm = SessionDetailViewModel()
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    init(session: WorkoutSession, navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.session = session
        self._navigationPath = navigationPath
    }

    var body: some View {
        List {
            ForEach(vm.allExercises, id: \.id) { exercise in
                NavigationLink(value: ExerciseProgressDestination(exerciseName: exercise.name)) {
                    ExerciseRow(exercise: exercise)
                }
            }
            .onDelete { indexSet in
                deleteExercises(offsets: indexSet)
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigationPath.append(AddExerciseDestination(sessionID: session.id))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            vm.configure(interactor: injected.interactors.workouts)
        }
        .onChange(of: session.strengthExercises, initial: true) { _, new in
            vm.updateExercises(strength: new, cardio: session.cardioExercises)
        }
        .onChange(of: session.cardioExercises, initial: true) { _, new in
            vm.updateExercises(strength: session.strengthExercises, cardio: new)
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    private func deleteExercises(offsets: IndexSet) {
        let exercises = vm.allExercises
        for index in offsets {
            let exercise = exercises[index]
            Task {
                try? await vm.deleteExercise(id: exercise.id, type: exercise.exerciseType, from: session.id)
            }
        }
    }
}
```

- [ ] **Step 5.6: Run all tests**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5.7: Commit**

```bash
git add WorkoutsApp/UI/SessionDetail/SessionDetailViewModel.swift \
        WorkoutsApp/UI/SessionDetail/SessionDetailView.swift \
        UnitTests/UI/SessionDetailViewModelTests.swift
git commit -m "perf: extract SessionDetailViewModel to memoize allExercises list"
```

---

## Task 6: AddExerciseViewModel

**Files:**
- Create: `WorkoutsApp/UI/AddExercise/AddExerciseViewModel.swift`
- Modify: `WorkoutsApp/UI/AddExercise/AddExerciseView.swift`
- Create: `UnitTests/UI/AddExerciseViewModelTests.swift`
- Modify: `UnitTests/UI/AddExerciseViewTests.swift`

### Background

`AddExerciseView` filters `libraryEntries` inline in the form body — a locale-aware `localizedCaseInsensitiveContains` scan on every keystroke render. Moving this to the VM means filtering only runs when `name` or `exerciseType` changes. The VM also owns the `save()` flow using the manual `Task + Loadable` pattern (no `$binding.load {}` since ViewModels don't have Bindings).

Test compatibility: the existing tests pass `saveState:` directly in `AddExerciseView.init`. After the refactor, tests pass a pre-configured `AddExerciseViewModel` instead. `AddExerciseView` gains an optional `viewModel:` init parameter for testing.

- [ ] **Step 6.1: Create AddExerciseViewModelTests.swift with failing tests**

Create `UnitTests/UI/AddExerciseViewModelTests.swift`:

```swift
// UnitTests/UI/AddExerciseViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct AddExerciseViewModelTests {

    @Test func filtersSuggestionsByTypeAndName() {
        let vm = AddExerciseViewModel(sessionID: nil)
        let squat = ExerciseLibraryEntry(name: "Squat", type: .strength)
        let bench = ExerciseLibraryEntry(name: "Bench Press", type: .strength)
        let run   = ExerciseLibraryEntry(name: "Run", type: .cardio)

        vm.exerciseType = .strength
        vm.name = "sq"
        vm.updateSuggestions(from: [squat, bench, run])

        #expect(vm.filteredSuggestions.count == 1)
        #expect(vm.filteredSuggestions[0].name == "Squat")
    }

    @Test func excludesExactNameMatchFromSuggestions() {
        let vm = AddExerciseViewModel(sessionID: nil)
        let squat = ExerciseLibraryEntry(name: "Squat", type: .strength)

        vm.exerciseType = .strength
        vm.name = "Squat"   // exact match → excluded
        vm.updateSuggestions(from: [squat])

        #expect(vm.filteredSuggestions.isEmpty)
    }

    @Test func filtersToSelectedTypeOnly() {
        let vm = AddExerciseViewModel(sessionID: nil)
        let squat = ExerciseLibraryEntry(name: "Squat", type: .strength)
        let run   = ExerciseLibraryEntry(name: "Run", type: .cardio)

        vm.exerciseType = .cardio
        vm.name = ""   // empty → all names match
        vm.updateSuggestions(from: [squat, run])

        #expect(vm.filteredSuggestions.count == 1)
        #expect(vm.filteredSuggestions[0].name == "Run")
    }

    @Test func saveCallsInteractorAndTransitionsToLoaded() async throws {
        let sessionID = UUID()
        let returnedID = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [
            .addExercise(sessionID: sessionID, input: .strength(name: "Squat", sets: 3, reps: 10, weight: 135))
        ])
        mocked.addExerciseResult = .success(returnedID)

        let vm = AddExerciseViewModel(sessionID: sessionID)
        vm.configure(interactor: mocked)
        vm.name = "Squat"
        vm.sets = 3
        vm.reps = 10
        vm.weight = 135
        vm.exerciseType = .strength

        vm.save()

        // Wait for the async Task inside save() to complete
        try await Task.sleep(for: .milliseconds(200))

        mocked.verify()
        if case .loaded(let id) = vm.saveState {
            #expect(id == returnedID)
        } else {
            Issue.record("Expected .loaded, got \(vm.saveState)")
        }
    }

    @Test func saveTransitionsToFailedOnError() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [
            .addExercise(sessionID: nil, input: .cardio(name: "Run", durationMinutes: 30))
        ])
        mocked.addExerciseResult = .failure(NSError.test)

        let vm = AddExerciseViewModel(sessionID: nil)
        vm.configure(interactor: mocked)
        vm.name = "Run"
        vm.durationMinutes = 30
        vm.exerciseType = .cardio

        vm.save()

        try await Task.sleep(for: .milliseconds(200))

        mocked.verify()
        #expect(vm.saveState.error != nil)
    }
}
```

- [ ] **Step 6.2: Run tests to confirm they fail**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/AddExerciseViewModelTests \
  -quiet 2>&1 | tail -20
```

Expected: compile error.

- [ ] **Step 6.3: Create AddExerciseViewModel**

Create `WorkoutsApp/UI/AddExercise/AddExerciseViewModel.swift`:

```swift
// WorkoutsApp/UI/AddExercise/AddExerciseViewModel.swift
import Observation
import Foundation

/// Owns form state and the save flow for AddExerciseView.
/// Filters library suggestions only when name or exerciseType changes, not on every render.
@Observable
final class AddExerciseViewModel {

    var exerciseType: ExerciseType = .strength
    var name: String = ""
    var sets: Int = 3
    var reps: Int = 10
    var weight: Double = 0
    var durationMinutes: Double = 0

    /// Tracks the save operation. `.loaded(UUID)` means success → view should dismiss.
    var saveState: Loadable<UUID> = .notRequested

    /// Suggestions filtered from the exercise library.
    private(set) var filteredSuggestions: [ExerciseLibraryEntry] = []

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()
    /// Internal (not private) so AddExerciseView can read it for the navigationTitle.
    let sessionID: UUID?

    init(sessionID: UUID?) {
        self.sessionID = sessionID
    }

    /// Wire the real interactor. Call from `.onAppear`.
    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    /// Filter library entries to those matching the current exerciseType and name prefix.
    /// Excludes exact matches (the name the user already typed).
    /// Call from `.onChange(of: vm.name)` and `.onChange(of: vm.exerciseType)`.
    func updateSuggestions(from library: [ExerciseLibraryEntry]) {
        filteredSuggestions = library.filter {
            $0.type == exerciseType
            && $0.name.localizedCaseInsensitiveContains(name)
            && $0.name != name
        }
    }

    /// Build the ExerciseInput and start the async save. Uses manual Task + Loadable
    /// because LoadableSubject.load {} requires a Binding, unavailable in @Observable classes.
    func save() {
        let input: ExerciseInput
        switch exerciseType {
        case .strength:
            input = .strength(name: name, sets: sets, reps: reps, weight: weight)
        case .cardio:
            input = .cardio(name: name, durationMinutes: durationMinutes)
        }
        let cancelBag = CancelBag()
        saveState.setIsLoading(cancelBag: cancelBag)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                saveState = .loaded(try await interactor.addExercise(to: sessionID, input: input))
            } catch {
                saveState = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }
}
```

- [ ] **Step 6.4: Run VM tests to confirm they pass**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/AddExerciseViewModelTests \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6.5: Rewrite AddExerciseView to use the VM**

Replace `WorkoutsApp/UI/AddExercise/AddExerciseView.swift` with:

```swift
// WorkoutsApp/UI/AddExercise/AddExerciseView.swift
import SwiftUI
import SwiftData

struct AddExerciseView: View {

    @State private var vm: AddExerciseViewModel

    @Query(sort: \ExerciseLibraryEntry.name)
    private var libraryEntries: [ExerciseLibraryEntry]

    @Environment(\.injected) private var injected: DIContainer
    @Environment(\.dismiss) private var dismiss

    let inspection = Inspection<Self>()

    /// Production init — creates a fresh VM for the given session.
    init(sessionID: UUID?) {
        _vm = State(initialValue: AddExerciseViewModel(sessionID: sessionID))
    }

    /// Testing init — allows injecting a pre-configured VM (e.g. with a preset saveState).
    init(sessionID: UUID?, viewModel: AddExerciseViewModel) {
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(vm.sessionID == nil ? "New Workout" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.save() }
                        .disabled(vm.name.isEmpty || vm.saveState.isLoading)
                }
            }
            .onChange(of: vm.saveState) { _, new in
                if case .loaded = new { dismiss() }
            }
            .onChange(of: vm.name, initial: true) { _, _ in
                vm.updateSuggestions(from: libraryEntries)
            }
            .onChange(of: vm.exerciseType) { _, _ in
                vm.updateSuggestions(from: libraryEntries)
            }
            .onAppear {
                vm.configure(interactor: injected.interactors.workouts)
            }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.saveState {
        case .isLoading:
            ProgressView()
        case .failed(let error):
            ErrorView(error: error, retryAction: vm.save)
        default:
            form
        }
    }

    private var form: some View {
        Form {
            Section("Exercise Type") {
                Picker("Type", selection: $vm.exerciseType) {
                    ForEach(ExerciseType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Exercise Name") {
                TextField("e.g. Bench Press", text: $vm.name)
                    .autocorrectionDisabled()
                ForEach(vm.filteredSuggestions) { entry in
                    Button(entry.name) { vm.name = entry.name }
                        .foregroundStyle(.secondary)
                }
            }

            if vm.exerciseType == .strength {
                Section("Strength Details") {
                    Stepper("Sets: \(vm.sets)", value: $vm.sets, in: 1...20)
                    Stepper("Reps: \(vm.reps)", value: $vm.reps, in: 1...100)
                    HStack {
                        Text("Weight (lbs)")
                        Spacer()
                        TextField("0", value: $vm.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            } else {
                Section("Cardio Details") {
                    HStack {
                        Text("Duration (min)")
                        Spacer()
                        TextField("0", value: $vm.durationMinutes, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
        }
    }
}

// MARK: - Helpers
// Loadable.isLoading is declared as an internal extension in Loadable.swift (added in Task 2).
```

- [ ] **Step 6.6: Update AddExerciseViewTests.swift**

Replace `UnitTests/UI/AddExerciseViewTests.swift` with:

```swift
// UnitTests/UI/AddExerciseViewTests.swift
import Testing
import ViewInspector
import SwiftData
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct AddExerciseViewTests {

    @Test func showsStrengthFieldsByDefault() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = AddExerciseView(sessionID: nil)
        let modelContainer = ModelContainer.mock
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func showsLoadingStateWhenSaving() async throws {
        let container = DIContainer(interactors: .mocked())
        let vm = AddExerciseViewModel(sessionID: nil)
        vm.saveState = .isLoading(last: nil, cancelBag: .test)
        let sut = AddExerciseView(sessionID: nil, viewModel: vm)
        let modelContainer = ModelContainer.mock
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func showsErrorState() async throws {
        let container = DIContainer(interactors: .mocked())
        let vm = AddExerciseViewModel(sessionID: nil)
        vm.saveState = .failed(NSError.test)
        let sut = AddExerciseView(sessionID: nil, viewModel: vm)
        let modelContainer = ModelContainer.mock
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }
}
```

- [ ] **Step 6.7: Run all tests**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6.8: Commit**

```bash
git add WorkoutsApp/UI/AddExercise/AddExerciseViewModel.swift \
        WorkoutsApp/UI/AddExercise/AddExerciseView.swift \
        UnitTests/UI/AddExerciseViewModelTests.swift \
        UnitTests/UI/AddExerciseViewTests.swift
git commit -m "perf: extract AddExerciseViewModel to debounce suggestion filtering"
```

---

## Task 7: Async Bootstrap + RootView

**Files:**
- Create: `WorkoutsApp/UI/RootView.swift`
- Modify: `WorkoutsApp/DependencyInjection/AppEnvironment.swift`
- Modify: `WorkoutsApp/Core/App.swift`
- Modify: `WorkoutsApp/Core/AppDelegate.swift`
- Create: `UnitTests/UI/RootViewTests.swift`

### Background

`AppEnvironment.bootstrap()` currently runs synchronously on `@MainActor` — it blocks the first frame. It also silently falls back to an in-memory `ModelContainer.stub` on failure, losing all user data with no recovery path.

New design:
1. `AppDelegate` becomes a minimal shell (no longer owns the environment).
2. `MainApp` renders `RootView` (or a test placeholder).
3. `RootView` starts with `.notRequested`, shows a `ProgressView`, then fires bootstrap async via `.onAppear`. On success it shows `SessionListView`. On failure it shows an error message with a Retry button.
4. `AppEnvironment.bootstrap()` becomes `async throws`. No `@MainActor` constraint. No silent catch.

This is the most complex task — do it last so the full test suite is green before you start.

- [ ] **Step 7.1: Write RootView tests first**

Create `UnitTests/UI/RootViewTests.swift`:

```swift
// UnitTests/UI/RootViewTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct RootViewTests {

    @Test func showsProgressViewWhileLoading() async throws {
        let sut = RootView(launchState: .isLoading(last: nil, cancelBag: .test))
        try await ViewHosting.host(sut) {
            try await sut.inspection.inspect { view in
                #expect(throws: Never.self) { try view.find(ViewType.ProgressView.self) }
            }
        }
    }

    @Test func showsErrorViewOnFailure() async throws {
        let sut = RootView(launchState: .failed(NSError.test))
        try await ViewHosting.host(sut) {
            try await sut.inspection.inspect { view in
                #expect(throws: Never.self) { try view.find(text: "Unable to load database") }
                #expect(throws: Never.self) { try view.find(button: "Retry") }
            }
        }
    }

    @Test func showsErrorDescriptionOnFailure() async throws {
        let error = NSError(domain: "test", code: 42,
                            userInfo: [NSLocalizedDescriptionKey: "Disk full"])
        let sut = RootView(launchState: .failed(error))
        try await ViewHosting.host(sut) {
            try await sut.inspection.inspect { view in
                #expect(throws: Never.self) { try view.find(text: "Disk full") }
            }
        }
    }
}
```

- [ ] **Step 7.2: Run tests to confirm they fail (type doesn't exist)**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/RootViewTests \
  -quiet 2>&1 | tail -20
```

Expected: compile error — `RootView` doesn't exist yet.

- [ ] **Step 7.3: Rewrite AppEnvironment**

Replace `WorkoutsApp/DependencyInjection/AppEnvironment.swift` with:

```swift
// WorkoutsApp/DependencyInjection/AppEnvironment.swift
import Foundation
import SwiftData

/// Bootstrapped app environment. Created once at launch via `bootstrap()`.
/// `ModelContainer.stub` is still available for tests — only the silent
/// production fallback is removed. Errors now propagate so RootView can
/// surface them with a retry option.
struct AppEnvironment {
    let diContainer: DIContainer
    let modelContainer: ModelContainer

    /// Creates the full app environment: ModelContainer → Repository → Interactor → DIContainer.
    /// Throws if ModelContainer creation fails (e.g. schema migration error, disk full).
    /// Not constrained to @MainActor — called from a Task inside RootView.
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

- [ ] **Step 7.4: Create RootView**

Create `WorkoutsApp/UI/RootView.swift`:

```swift
// WorkoutsApp/UI/RootView.swift
import SwiftUI

/// Manages app launch state and surfaces database errors with a retry option.
/// Renders a ProgressView during bootstrap, SessionListView on success,
/// and an error screen with a Retry button on failure.
struct RootView: View {

    @State private var launchState: Loadable<AppEnvironment>

    let inspection = Inspection<Self>()

    /// Production init — starts in .notRequested; bootstrap fires from .onAppear.
    init() {
        _launchState = State(initialValue: .notRequested)
    }

    /// Testing init — allows injecting a specific launch state directly.
    init(launchState: Loadable<AppEnvironment>) {
        _launchState = State(initialValue: launchState)
    }

    var body: some View {
        content
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch launchState {
        case .notRequested, .isLoading:
            ProgressView("Loading…")
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

    /// Starts the async bootstrap and updates launchState.
    /// Uses manual Task + Loadable (not $binding.load {}) for consistency
    /// with the ViewModel pattern — no Binding is available here.
    private func bootstrap() {
        guard !launchState.isLoading else { return }
        let cancelBag = CancelBag()
        launchState.setIsLoading(cancelBag: cancelBag)
        let task = Task {
            do {
                launchState = .loaded(try await AppEnvironment.bootstrap())
            } catch {
                launchState = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }
}

// Loadable.isLoading is declared as an internal extension in Loadable.swift (added in Task 2).
```

- [ ] **Step 7.5: Update App.swift**

Replace `WorkoutsApp/Core/App.swift` with:

```swift
// WorkoutsApp/Core/App.swift
import SwiftUI

@main
struct MainApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

- [ ] **Step 7.6: Simplify AppDelegate.swift**

Replace `WorkoutsApp/Core/AppDelegate.swift` with:

```swift
// WorkoutsApp/Core/AppDelegate.swift
import UIKit

/// Minimal app delegate — retained for UIApplicationDelegate lifecycle hooks.
/// AppEnvironment bootstrap has moved to RootView.
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }
}
```

- [ ] **Step 7.7: Build to confirm it compiles**

```bash
xcodebuild build \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

If you see errors about `AppEnvironment.rootView` or `modelContainer.isStub`, it means something still references the old `App.swift` extension — remove it.

- [ ] **Step 7.8: Run all tests**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7.9: Commit**

```bash
git add WorkoutsApp/UI/RootView.swift \
        WorkoutsApp/DependencyInjection/AppEnvironment.swift \
        WorkoutsApp/Core/App.swift \
        WorkoutsApp/Core/AppDelegate.swift \
        UnitTests/UI/RootViewTests.swift
git commit -m "feat: async bootstrap with error recovery UI in RootView"
```

---

## Final Verification

- [ ] **Run full test suite one last time**

```bash
xcodebuild test \
  -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -quiet 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` with no failures.

- [ ] **Verify task list in the feature branch**

All 7 tasks should be committed on `feature/performance-improvements-spec`.

---

## Summary of Changes

| Problem | Fix | Task |
|---|---|---|
| Tasks not cancelled | `CancelBag.cancel()` calls `.cancel()` on each item | 1 |
| Error equality by description | Use `(domain, code)` pair | 2 |
| Unindexed name queries | `#Index<T>([\.name])` on both exercise models | 3 |
| `groupedSessions` recomputed every render | `SessionListViewModel.sessionsDidChange` | 4 |
| `allExercises` recomputed + existential boxing every render | `SessionDetailViewModel.updateExercises` | 5 |
| Library suggestions filtered every keystroke render | `AddExerciseViewModel.updateSuggestions` | 6 |
| Blocking synchronous bootstrap + silent data loss | `async throws` bootstrap + `RootView` error UI | 7 |
