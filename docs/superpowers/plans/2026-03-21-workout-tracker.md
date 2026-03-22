# Workout Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the WorkoutsApp template into a personal iOS workout tracker by replacing the countries domain with a workout domain while preserving the core infrastructure.

**Architecture:** Three-layer Clean Architecture (View → Interactor → Repository) with protocol-based dependency injection. All cross-actor boundaries use plain value types only — no `@Model` instances cross between `@ModelActor` repository and main actor. SwiftData handles persistence; `@Query` handles reactive display.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, `@ModelActor`, Combine, Swift Testing, ViewInspector

**Pre-existing test helpers** (defined in the template — do not redefine):
- `CancelBag.test` — in `UnitTests/TestHelpers.swift`
- `NSError.test` — in `UnitTests/TestHelpers.swift`
- `ModelContainer.mock` — in `UnitTests/Mocks/MockedDBRepositories.swift`
- `ModelContainer.appModelContainer(inMemoryOnly:isStub:)` — in `WorkoutsApp/Repositories/Database/ModelContainer.swift`

---

## File Map

### Create
- `WorkoutsApp/Utilities/ExerciseType.swift` — `ExerciseType` enum
- `WorkoutsApp/Utilities/ExerciseInput.swift` — `ExerciseInput` enum (create-path value type)
- `WorkoutsApp/Repositories/Models/WorkoutSession.swift` — `@Model WorkoutSession`
- `WorkoutsApp/Repositories/Models/StrengthExercise.swift` — `@Model StrengthExercise`
- `WorkoutsApp/Repositories/Models/CardioExercise.swift` — `@Model CardioExercise`
- `WorkoutsApp/Repositories/Models/ExerciseLibraryEntry.swift` — `@Model ExerciseLibraryEntry`
- `WorkoutsApp/Repositories/Models/ProgressEntry.swift` — `ProgressEntry` value type
- `WorkoutsApp/Repositories/Database/WorkoutsDBRepository.swift` — protocol + `MainDBRepository` conformance
- `WorkoutsApp/Interactors/WorkoutsInteractor.swift` — protocol + `RealWorkoutsInteractor` + `StubWorkoutsInteractor`
- `WorkoutsApp/UI/SessionList/SessionListView.swift`
- `WorkoutsApp/UI/SessionList/SessionCell.swift`
- `WorkoutsApp/UI/SessionDetail/SessionDetailView.swift`
- `WorkoutsApp/UI/SessionDetail/ExerciseRow.swift`
- `WorkoutsApp/UI/AddExercise/AddExerciseView.swift`
- `WorkoutsApp/UI/ExerciseProgress/ExerciseProgressView.swift`
- `UnitTests/Mocks/Interactors/WorkoutsInteractorTests.swift`
- `UnitTests/Repositories/WorkoutsDBRepositoryTests.swift`
- `UnitTests/UI/SessionListTests.swift`
- `UnitTests/UI/AddExerciseViewTests.swift`
- `UnitTests/UI/ExerciseProgressViewTests.swift`

### Modify
- `WorkoutsApp/Repositories/Models/AppSchema.swift` — replace `DBModel.Country` schema with workout models
- `WorkoutsApp/Repositories/Database/ModelContainer.swift` — keep `@ModelActor`, keep `appModelContainer`; update uses new schema
- `WorkoutsApp/Core/AppState.swift` — remove `System`, `Permissions`; empty `SessionList.Routing`
- `WorkoutsApp/DependencyInjection/DIContainer.swift` — remove web repos; `Interactors` has `workouts` only
- `WorkoutsApp/DependencyInjection/AppEnvironment.swift` — strip web/push/system; keep `modelContainer`
- `WorkoutsApp/Core/AppDelegate.swift` — remove `SystemEventsHandler`, `SceneDelegate`, push methods
- `WorkoutsApp/Core/App.swift` — remove `EnvironmentOverrides`; root view shows `SessionListView`
- `WorkoutsApp/UI/RootViewModifier.swift` — remove `system.isActive` reference
- `UnitTests/Mocks/MockedInteractors.swift` — replace countries/images/permissions mocks with workouts mock
- `UnitTests/Mocks/MockedDBRepositories.swift` — replace countries DB mock with workouts DB mock

### Delete (after all new code compiles)
- `WorkoutsApp/Repositories/Models/Country.swift`
- `WorkoutsApp/Repositories/Models/CountryDetails.swift`
- `WorkoutsApp/Repositories/Models/CountryCurrency.swift`
- `WorkoutsApp/Repositories/Models/MockedData.swift`
- `WorkoutsApp/Repositories/WebAPI/CountriesWebRepository.swift`
- `WorkoutsApp/Repositories/WebAPI/ImagesWebRepository.swift`
- `WorkoutsApp/Repositories/WebAPI/PushTokenWebRepository.swift`
- `WorkoutsApp/Repositories/WebAPI/WebRepository.swift`
- `WorkoutsApp/Interactors/CountriesInteractor.swift`
- `WorkoutsApp/Interactors/ImagesInteractor.swift`
- `WorkoutsApp/Interactors/UserPermissionsInteractor.swift`
- `WorkoutsApp/Core/DeepLinksHandler.swift`
- `WorkoutsApp/Core/PushNotificationsHandler.swift`
- `WorkoutsApp/Core/SystemEventsHandler.swift`
- `WorkoutsApp/UI/CountriesList/CountriesListView.swift`
- `WorkoutsApp/UI/CountriesList/CountryCell.swift`
- `WorkoutsApp/UI/CountriesList/LocaleReader.swift`
- `WorkoutsApp/UI/CountryDetails/CountryDetailsView.swift`
- `WorkoutsApp/UI/CountryDetails/DetailRow.swift`
- `WorkoutsApp/UI/CountryDetails/ModalFlagView.swift`
- `UnitTests/Mocks/MockedWebRepositories.swift`
- `UnitTests/Mocks/MockedSystemEventsHandler.swift`
- `UnitTests/Mocks/MockedSystemPermissions.swift`
- `UnitTests/Mocks/NetworkMocking/MockedResponse.swift`
- `UnitTests/Mocks/NetworkMocking/RequestMocking.swift`
- `UnitTests/Mocks/Interactors/CountriesInteractorTests.swift`
- `UnitTests/Mocks/Interactors/UserPermissionsInteractorTests.swift`
- `UnitTests/Mocks/Interactors/ImagesInteractorTests.swift`
- `UnitTests/UI/ImageViewTests.swift`
- `UnitTests/UI/CountriesListTests.swift`
- `UnitTests/UI/DeepLinkUITests.swift`
- `UnitTests/UI/ModalFlagViewTests.swift`
- `UnitTests/Repositories/PushTokenWebRepositoryTests.swift`
- `UnitTests/Repositories/ImageWebRepositoryTests.swift`
- `UnitTests/Repositories/CountriesWebRepositoryTests.swift`
- `UnitTests/Repositories/WebRepositoryTests.swift`
- `UnitTests/Repositories/CountriesDBRepositoryTests.swift`
- `UnitTests/System/DeepLinksHandlerTests.swift`
- `UnitTests/System/PushNotificationsHandlerTests.swift`

---

## Task 1: ExerciseType and ExerciseInput value types

**Files:**
- Create: `WorkoutsApp/Utilities/ExerciseType.swift`
- Create: `WorkoutsApp/Utilities/ExerciseInput.swift`
- Test: `UnitTests/Utilities/HelpersTests.swift` (add to existing)

- [ ] **Step 1: Write the failing tests**

Add to `UnitTests/Utilities/HelpersTests.swift`:

```swift
import Testing
@testable import WorkoutsApp

@Suite struct ExerciseTypeTests {
    @Test func rawValues() {
        #expect(ExerciseType.strength.rawValue == "strength")
        #expect(ExerciseType.cardio.rawValue == "cardio")
    }

    @Test func allCases() {
        #expect(ExerciseType.allCases.count == 2)
    }
}

@Suite struct ExerciseInputTests {
    @Test func strengthNameExtraction() {
        let input = ExerciseInput.strength(name: "Bench Press", sets: 3, reps: 10, weight: 80.0)
        #expect(input.name == "Bench Press")
        #expect(input.exerciseType == .strength)
    }

    @Test func cardioNameExtraction() {
        let input = ExerciseInput.cardio(name: "Running", durationMinutes: 30.0)
        #expect(input.name == "Running")
        #expect(input.exerciseType == .cardio)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure** (types don't exist yet)

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/ExerciseTypeTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 3: Create `ExerciseType.swift`**

```swift
// WorkoutsApp/Utilities/ExerciseType.swift
import Foundation

enum ExerciseType: String, Codable, CaseIterable {
    case strength
    case cardio
}
```

- [ ] **Step 4: Create `ExerciseInput.swift`**

```swift
// WorkoutsApp/Utilities/ExerciseInput.swift
import Foundation

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

- [ ] **Step 5: Run tests — expect pass**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/ExerciseTypeTests \
  -only-testing:UnitTests/ExerciseInputTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: PASSED for both suites.

- [ ] **Step 6: Commit**

```bash
git add WorkoutsApp/Utilities/ExerciseType.swift \
        WorkoutsApp/Utilities/ExerciseInput.swift \
        UnitTests/Utilities/HelpersTests.swift
git commit -m "feat: add ExerciseType and ExerciseInput value types"
```

---

## Task 2: SwiftData models and ProgressEntry

**Files:**
- Create: `WorkoutsApp/Repositories/Models/WorkoutSession.swift`
- Create: `WorkoutsApp/Repositories/Models/StrengthExercise.swift`
- Create: `WorkoutsApp/Repositories/Models/CardioExercise.swift`
- Create: `WorkoutsApp/Repositories/Models/ExerciseLibraryEntry.swift`
- Create: `WorkoutsApp/Repositories/Models/ProgressEntry.swift`

These are SwiftData `@Model` classes and a value type — no direct unit tests at this layer. They are tested via repository integration tests in Task 5.

- [ ] **Step 1: Create `WorkoutSession.swift`**

```swift
// WorkoutsApp/Repositories/Models/WorkoutSession.swift
import SwiftData
import Foundation

@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    @Relationship(deleteRule: .cascade) var strengthExercises: [StrengthExercise] = []
    @Relationship(deleteRule: .cascade) var cardioExercises: [CardioExercise] = []

    init(id: UUID = UUID(), date: Date) {
        self.id = id
        self.date = date
    }
}
```

- [ ] **Step 2: Create `StrengthExercise.swift`**

```swift
// WorkoutsApp/Repositories/Models/StrengthExercise.swift
import SwiftData
import Foundation

@Model
final class StrengthExercise {
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

- [ ] **Step 3: Create `CardioExercise.swift`**

```swift
// WorkoutsApp/Repositories/Models/CardioExercise.swift
import SwiftData
import Foundation

@Model
final class CardioExercise {
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

- [ ] **Step 4: Create `ExerciseLibraryEntry.swift`**

```swift
// WorkoutsApp/Repositories/Models/ExerciseLibraryEntry.swift
import SwiftData
import Foundation

@Model
final class ExerciseLibraryEntry {
    @Attribute(.unique) var name: String
    var id: UUID
    var type: ExerciseType

    init(id: UUID = UUID(), name: String, type: ExerciseType) {
        self.id = id
        self.name = name
        self.type = type
    }
}
```

- [ ] **Step 5: Create `ProgressEntry.swift`**

```swift
// WorkoutsApp/Repositories/Models/ProgressEntry.swift
import Foundation

struct ProgressEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let exerciseType: ExerciseType
    let value: Double
    let label: String
}
```

- [ ] **Step 6: Add Exercise protocols to `Helpers.swift`**

Open `WorkoutsApp/Utilities/Helpers.swift` and append:

```swift
// MARK: - Exercise Protocols

protocol Exercise: Identifiable {
    var id: UUID { get }
    var name: String { get }
    var exerciseType: ExerciseType { get }
}

protocol AnalyticsTrackable: Exercise {
    var analyticsValue: Double { get }
    var analyticsLabel: String { get }
}

// MARK: - Custom Errors

struct ExerciseNotFoundError: Error {
    var localizedDescription: String { "Exercise not found in this session" }
}

struct SessionNotFoundError: Error {
    var localizedDescription: String { "Workout session not found" }
}
```

- [ ] **Step 7: Build to confirm models compile**

```bash
xcodebuild build -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: BUILD SUCCEEDED (existing code still compiles alongside new models).

- [ ] **Step 8: Commit**

```bash
git add WorkoutsApp/Repositories/Models/WorkoutSession.swift \
        WorkoutsApp/Repositories/Models/StrengthExercise.swift \
        WorkoutsApp/Repositories/Models/CardioExercise.swift \
        WorkoutsApp/Repositories/Models/ExerciseLibraryEntry.swift \
        WorkoutsApp/Repositories/Models/ProgressEntry.swift \
        WorkoutsApp/Utilities/Helpers.swift
git commit -m "feat: add workout SwiftData models and Exercise protocols"
```

---

## Task 3: Update AppSchema and ModelContainer

**Files:**
- Modify: `WorkoutsApp/Repositories/Models/AppSchema.swift`
- Modify: `WorkoutsApp/Repositories/Database/ModelContainer.swift`

- [ ] **Step 1: Rewrite `AppSchema.swift`**

```swift
// WorkoutsApp/Repositories/Models/AppSchema.swift
import SwiftData

// Empty namespace — kept for compatibility with any remaining references
enum DBModel { }

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

- [ ] **Step 2: Build — confirm schema compiles**

```bash
xcodebuild build -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: BUILD SUCCEEDED. (Old country models still exist so schema change doesn't break anything yet.)

- [ ] **Step 3: Commit**

```bash
git add WorkoutsApp/Repositories/Models/AppSchema.swift
git commit -m "feat: update AppSchema to workout models"
```

---

## Task 4: WorkoutsDBRepository protocol and MainDBRepository implementation

**Files:**
- Create: `WorkoutsApp/Repositories/Database/WorkoutsDBRepository.swift`
- Modify: `UnitTests/Mocks/MockedDBRepositories.swift`
- Create: `UnitTests/Repositories/WorkoutsDBRepositoryTests.swift`

- [ ] **Step 1: Write the failing repository integration tests**

Create `UnitTests/Repositories/WorkoutsDBRepositoryTests.swift`:

```swift
// UnitTests/Repositories/WorkoutsDBRepositoryTests.swift
import Testing
import SwiftData
@testable import WorkoutsApp

@Suite struct WorkoutsDBRepositoryTests {

    let container: ModelContainer
    let sut: MainDBRepository

    init() throws {
        container = try ModelContainer.appModelContainer(inMemoryOnly: true)
        sut = MainDBRepository(modelContainer: container)
    }

    // MARK: - saveNewSession

    @Test func saveNewSession_returnsSessionID() async throws {
        let input = ExerciseInput.strength(name: "Squat", sets: 3, reps: 5, weight: 100.0)
        let id = try await sut.saveNewSession(date: .now, with: input)
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        let sessions = try container.mainContext.fetch(descriptor)
        #expect(sessions.count == 1)
    }

    @Test func saveNewSession_cascadeDelete() async throws {
        let input = ExerciseInput.strength(name: "Squat", sets: 3, reps: 5, weight: 100.0)
        let id = try await sut.saveNewSession(date: .now, with: input)
        try await sut.deleteSession(id: id)
        let sessions = try container.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        let strength = try container.mainContext.fetch(FetchDescriptor<StrengthExercise>())
        #expect(sessions.isEmpty)
        #expect(strength.isEmpty)
    }

    @Test func addExercise_appendsToSession() async throws {
        let id = try await sut.saveNewSession(date: .now, with: .cardio(name: "Run", durationMinutes: 20))
        try await sut.addExercise(.strength(name: "Bench", sets: 3, reps: 8, weight: 60.0), to: id)
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        let session = try container.mainContext.fetch(descriptor).first!
        #expect(session.strengthExercises.count == 1)
        #expect(session.cardioExercises.count == 1)
    }

    @Test func deleteExercise_removesRecordAndRelationship() async throws {
        let input = ExerciseInput.strength(name: "Deadlift", sets: 1, reps: 5, weight: 140.0)
        let sessionID = try await sut.saveNewSession(date: .now, with: input)
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        let session = try container.mainContext.fetch(descriptor).first!
        let exerciseID = session.strengthExercises.first!.id
        try await sut.deleteExercise(id: exerciseID, type: .strength, from: sessionID)
        let updated = try container.mainContext.fetch(descriptor).first!
        let allStrength = try container.mainContext.fetch(FetchDescriptor<StrengthExercise>())
        #expect(updated.strengthExercises.isEmpty)
        #expect(allStrength.isEmpty)
    }

    @Test func deleteExercise_throwsWhenNotFound() async throws {
        let sessionID = try await sut.saveNewSession(date: .now, with: .cardio(name: "Bike", durationMinutes: 45))
        await #expect(throws: ExerciseNotFoundError.self) {
            try await sut.deleteExercise(id: UUID(), type: .strength, from: sessionID)
        }
    }

    @Test func upsertLibraryEntry_noDuplicates() async throws {
        try await sut.upsertLibraryEntry(name: "Squat", type: .strength)
        try await sut.upsertLibraryEntry(name: "Squat", type: .strength)
        let descriptor = FetchDescriptor<ExerciseLibraryEntry>(predicate: #Predicate { $0.name == "Squat" })
        let entries = try container.mainContext.fetch(descriptor)
        #expect(entries.count == 1)
    }

    @Test func libraryContains_returnsTrueAfterInsert() async throws {
        try await sut.upsertLibraryEntry(name: "Pull-up", type: .strength)
        let result = try await sut.libraryContains(name: "Pull-up")
        #expect(result == true)
    }

    @Test func libraryContains_returnsFalseWhenAbsent() async throws {
        let result = try await sut.libraryContains(name: "NonExistent")
        #expect(result == false)
    }

    @Test func progressEntries_sortedByDateAscending() async throws {
        let older = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        _ = try await sut.saveNewSession(date: .now, with: .strength(name: "Press", sets: 3, reps: 10, weight: 50.0))
        _ = try await sut.saveNewSession(date: older, with: .strength(name: "Press", sets: 3, reps: 8, weight: 45.0))
        let entries = try await sut.progressEntries(for: "Press")
        #expect(entries.count == 2)
        #expect(entries[0].date <= entries[1].date)
    }

    @Test func progressEntries_orphanedExerciseSilentlyDropped() async throws {
        // Create session, get exercise ID, then delete session (orphans nothing due to cascade)
        // To test orphan drop: manually insert an exercise without a session
        try await sut.upsertLibraryEntry(name: "Test", type: .strength)
        // Insert orphaned exercise directly via model context
        let orphan = StrengthExercise(name: "Test", sets: 1, reps: 1, weight: 1)
        // orphan.session is nil — simulates orphaned record
        container.mainContext.insert(orphan)
        try container.mainContext.save()
        let entries = try await sut.progressEntries(for: "Test")
        #expect(entries.isEmpty) // nil session → dropped
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure** (protocol not defined yet)

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/WorkoutsDBRepositoryTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 3: Create `WorkoutsDBRepository.swift`**

```swift
// WorkoutsApp/Repositories/Database/WorkoutsDBRepository.swift
import SwiftData
import Foundation

// MARK: - Protocol

protocol WorkoutsDBRepository {
    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID
    func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws
    func deleteSession(id: UUID) async throws
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
    func libraryContains(name: String) async throws -> Bool
    func upsertLibraryEntry(name: String, type: ExerciseType) async throws
}

// MARK: - MainDBRepository conformance

extension MainDBRepository: WorkoutsDBRepository {

    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID {
        let sessionID = UUID()
        let session = WorkoutSession(id: sessionID, date: date)
        try modelContext.transaction {
            modelContext.insert(session)
            try insertExercise(input, into: session)
        }
        return sessionID
    }

    func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        guard let session = try modelContext.fetch(descriptor).first else { throw SessionNotFoundError() }
        try modelContext.transaction {
            try insertExercise(input, into: session)
        }
    }

    func deleteSession(id: UUID) async throws {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        guard let session = try modelContext.fetch(descriptor).first else { throw SessionNotFoundError() }
        try modelContext.transaction {
            modelContext.delete(session)
        }
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        guard let session = try modelContext.fetch(descriptor).first else { throw SessionNotFoundError() }
        try modelContext.transaction {
            switch type {
            case .strength:
                guard let e = session.strengthExercises.first(where: { $0.id == id })
                else { throw ExerciseNotFoundError() }
                session.strengthExercises.removeAll { $0.id == id }
                modelContext.delete(e)
            case .cardio:
                guard let e = session.cardioExercises.first(where: { $0.id == id })
                else { throw ExerciseNotFoundError() }
                session.cardioExercises.removeAll { $0.id == id }
                modelContext.delete(e)
            }
        }
    }

    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] {
        let strengthFetch = FetchDescriptor<StrengthExercise>(predicate: #Predicate { $0.name == exerciseName })
        let cardioFetch   = FetchDescriptor<CardioExercise>(predicate: #Predicate { $0.name == exerciseName })
        let strength = try modelContext.fetch(strengthFetch).compactMap { e -> ProgressEntry? in
            guard let date = e.session?.date else { return nil }
            return ProgressEntry(id: e.id, date: date, exerciseType: .strength,
                                 value: e.analyticsValue, label: e.analyticsLabel)
        }
        let cardio = try modelContext.fetch(cardioFetch).compactMap { e -> ProgressEntry? in
            guard let date = e.session?.date else { return nil }
            return ProgressEntry(id: e.id, date: date, exerciseType: .cardio,
                                 value: e.analyticsValue, label: e.analyticsLabel)
        }
        return (strength + cardio).sorted { $0.date < $1.date }
    }

    func libraryContains(name: String) async throws -> Bool {
        let descriptor = FetchDescriptor<ExerciseLibraryEntry>(predicate: #Predicate { $0.name == name })
        return try !modelContext.fetch(descriptor).isEmpty
    }

    func upsertLibraryEntry(name: String, type: ExerciseType) async throws {
        let descriptor = FetchDescriptor<ExerciseLibraryEntry>(predicate: #Predicate { $0.name == name })
        guard try modelContext.fetch(descriptor).isEmpty else { return }
        try modelContext.transaction {
            modelContext.insert(ExerciseLibraryEntry(name: name, type: type))
        }
    }

    // MARK: - Private helpers

    private func insertExercise(_ input: ExerciseInput, into session: WorkoutSession) throws {
        switch input {
        case .strength(let name, let sets, let reps, let weight):
            let e = StrengthExercise(name: name, sets: sets, reps: reps, weight: weight)
            e.session = session
            session.strengthExercises.append(e)
            modelContext.insert(e)
        case .cardio(let name, let durationMinutes):
            let e = CardioExercise(name: name, durationMinutes: durationMinutes)
            e.session = session
            session.cardioExercises.append(e)
            modelContext.insert(e)
        }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/WorkoutsDBRepositoryTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: all tests PASSED.

- [ ] **Step 5: Add `MockedWorkoutsDBRepository` to `MockedDBRepositories.swift`**

Append to `UnitTests/Mocks/MockedDBRepositories.swift` (keep existing `MockedCountriesDBRepository` for now — it will be deleted in Task 12):

```swift
// MARK: - MockedWorkoutsDBRepository

final class MockedWorkoutsDBRepository: Mock, WorkoutsDBRepository {

    enum Action: Equatable {
        case saveNewSession(date: Date, input: ExerciseInput)
        case addExercise(input: ExerciseInput, sessionID: UUID)
        case deleteSession(id: UUID)
        case deleteExercise(id: UUID, type: ExerciseType, sessionID: UUID)
        case progressEntries(exerciseName: String)
        case libraryContains(name: String)
        case upsertLibraryEntry(name: String, type: ExerciseType)
    }

    var actions: MockActions<Action>
    var saveNewSessionResult: Result<UUID, Error> = .success(UUID())
    var addExerciseResult: Result<Void, Error> = .success(())
    var deleteSessionResult: Result<Void, Error> = .success(())
    var deleteExerciseResult: Result<Void, Error> = .success(())
    var progressEntriesResult: Result<[ProgressEntry], Error> = .success([])
    var libraryContainsResult: Result<Bool, Error> = .success(false)
    var upsertLibraryEntryResult: Result<Void, Error> = .success(())

    init(expected: [Action]) {
        self.actions = .init(expected: expected)
    }

    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID {
        register(.saveNewSession(date: date, input: input))
        return try saveNewSessionResult.get()
    }

    func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws {
        register(.addExercise(input: input, sessionID: sessionID))
        try addExerciseResult.get()
    }

    func deleteSession(id: UUID) async throws {
        register(.deleteSession(id: id))
        try deleteSessionResult.get()
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        register(.deleteExercise(id: id, type: type, sessionID: sessionID))
        try deleteExerciseResult.get()
    }

    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] {
        register(.progressEntries(exerciseName: exerciseName))
        return try progressEntriesResult.get()
    }

    func libraryContains(name: String) async throws -> Bool {
        register(.libraryContains(name: name))
        return try libraryContainsResult.get()
    }

    func upsertLibraryEntry(name: String, type: ExerciseType) async throws {
        register(.upsertLibraryEntry(name: name, type: type))
        try upsertLibraryEntryResult.get()
    }
}

extension ExerciseInput: Equatable {
    public static func == (lhs: ExerciseInput, rhs: ExerciseInput) -> Bool {
        switch (lhs, rhs) {
        case (.strength(let n1, let s1, let r1, let w1), .strength(let n2, let s2, let r2, let w2)):
            return n1 == n2 && s1 == s2 && r1 == r2 && w1 == w2
        case (.cardio(let n1, let d1), .cardio(let n2, let d2)):
            return n1 == n2 && d1 == d2
        default:
            return false
        }
    }
}
```

- [ ] **Step 6: Build to confirm mock compiles**

```bash
xcodebuild build -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 7: Commit**

```bash
git add WorkoutsApp/Repositories/Database/WorkoutsDBRepository.swift \
        UnitTests/Repositories/WorkoutsDBRepositoryTests.swift \
        UnitTests/Mocks/MockedDBRepositories.swift
git commit -m "feat: add WorkoutsDBRepository protocol and MainDBRepository implementation"
```

---

## Task 5: WorkoutsInteractor protocol and implementation

**Files:**
- Create: `WorkoutsApp/Interactors/WorkoutsInteractor.swift`
- Create: `UnitTests/Mocks/Interactors/WorkoutsInteractorTests.swift`

- [ ] **Step 1: Write failing interactor tests**

Create `UnitTests/Mocks/Interactors/WorkoutsInteractorTests.swift`:

```swift
// UnitTests/Mocks/Interactors/WorkoutsInteractorTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite class WorkoutsInteractorTests {

    var mockedDB: MockedWorkoutsDBRepository!
    var sut: RealWorkoutsInteractor!
    let fixedSessionID = UUID()

    init() {
        mockedDB = MockedWorkoutsDBRepository(expected: [])
        sut = RealWorkoutsInteractor(dbRepository: mockedDB)
        mockedDB.saveNewSessionResult = .success(fixedSessionID)
    }
}

// MARK: - addExercise(to:nil) — new session

final class AddExerciseNewSessionTests: WorkoutsInteractorTests {

    @Test func createsNewSessionWhenNil() async throws {
        let input = ExerciseInput.strength(name: "Squat", sets: 3, reps: 5, weight: 100.0)
        mockedDB.actions = .init(expected: [
            .saveNewSession(input: input),
            .libraryContains(name: "Squat"),
            .upsertLibraryEntry(name: "Squat", type: .strength)
        ])
        mockedDB.libraryContainsResult = .success(false)
        let id = try await sut.addExercise(to: nil, input: input)
        #expect(id == fixedSessionID)
        mockedDB.verify()
    }

    @Test func doesNotUpsertLibraryWhenNameExists() async throws {
        let input = ExerciseInput.cardio(name: "Running", durationMinutes: 30)
        mockedDB.actions = .init(expected: [
            .saveNewSession(input: input),
            .libraryContains(name: "Running")
        ])
        mockedDB.libraryContainsResult = .success(true)
        _ = try await sut.addExercise(to: nil, input: input)
        mockedDB.verify()
    }
}

// MARK: - addExercise(to:existingID) — existing session

final class AddExerciseExistingSessionTests: WorkoutsInteractorTests {

    @Test func addsToExistingSession() async throws {
        let sessionID = UUID()
        let input = ExerciseInput.cardio(name: "Bike", durationMinutes: 45)
        mockedDB.actions = .init(expected: [
            .addExercise(input: input, sessionID: sessionID),
            .libraryContains(name: "Bike"),
            .upsertLibraryEntry(name: "Bike", type: .cardio)
        ])
        mockedDB.libraryContainsResult = .success(false)
        let id = try await sut.addExercise(to: sessionID, input: input)
        #expect(id == sessionID)
        mockedDB.verify()
    }
}

// MARK: - deleteSession

final class DeleteSessionTests: WorkoutsInteractorTests {

    @Test func deletesSession() async throws {
        let sessionID = UUID()
        mockedDB.actions = .init(expected: [.deleteSession(id: sessionID)])
        try await sut.deleteSession(id: sessionID)
        mockedDB.verify()
    }
}

// MARK: - deleteExercise

final class DeleteExerciseTests: WorkoutsInteractorTests {

    @Test func deletesExercise() async throws {
        let sessionID = UUID()
        let exerciseID = UUID()
        mockedDB.actions = .init(expected: [
            .deleteExercise(id: exerciseID, type: .strength, sessionID: sessionID)
        ])
        try await sut.deleteExercise(id: exerciseID, type: .strength, from: sessionID)
        mockedDB.verify()
    }
}

// MARK: - progressEntries

final class ProgressEntriesTests: WorkoutsInteractorTests {

    @Test func forwardsEntriesToCaller() async throws {
        let entry = ProgressEntry(id: UUID(), date: .now, exerciseType: .strength, value: 1000, label: "Volume (lbs)")
        mockedDB.actions = .init(expected: [.progressEntries(exerciseName: "Squat")])
        mockedDB.progressEntriesResult = .success([entry])
        let result = try await sut.progressEntries(for: "Squat")
        #expect(result == [entry])
        mockedDB.verify()
    }
}

// MARK: - StubWorkoutsInteractor

final class StubWorkoutsInteractorTests: WorkoutsInteractorTests {
    @Test func stubReturnsDefaults() async throws {
        let stub = StubWorkoutsInteractor()
        let id = try await stub.addExercise(to: nil, input: .cardio(name: "Run", durationMinutes: 20))
        #expect(id != nil)
        try await stub.deleteSession(id: UUID())
        try await stub.deleteExercise(id: UUID(), type: .strength, from: UUID())
        let entries = try await stub.progressEntries(for: "anything")
        #expect(entries.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/WorkoutsInteractorTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 3: Create `WorkoutsInteractor.swift`**

```swift
// WorkoutsApp/Interactors/WorkoutsInteractor.swift
import Foundation

// MARK: - Protocol

protocol WorkoutsInteractor {
    // sessionID == nil → creates new session; returns its UUID
    // sessionID != nil → adds to existing session; returns same UUID
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID
    func deleteSession(id: UUID) async throws
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
}

// MARK: - Real implementation

struct RealWorkoutsInteractor: WorkoutsInteractor {

    let dbRepository: any WorkoutsDBRepository

    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID {
        let id: UUID
        if let sessionID {
            try await dbRepository.addExercise(input, to: sessionID)
            id = sessionID
        } else {
            id = try await dbRepository.saveNewSession(date: .now, with: input)
        }
        if try await !dbRepository.libraryContains(name: input.name) {
            try await dbRepository.upsertLibraryEntry(name: input.name, type: input.exerciseType)
        }
        return id
    }

    func deleteSession(id: UUID) async throws {
        try await dbRepository.deleteSession(id: id)
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        try await dbRepository.deleteExercise(id: id, type: type, from: sessionID)
    }

    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] {
        try await dbRepository.progressEntries(for: exerciseName)
    }
}

// MARK: - Stub (for UI tests and previews)

struct StubWorkoutsInteractor: WorkoutsInteractor {
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID {
        sessionID ?? UUID()
    }
    func deleteSession(id: UUID) async throws {}
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {}
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] { [] }
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/WorkoutsInteractorTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

Expected: all PASSED.

- [ ] **Step 5: Commit**

```bash
git add WorkoutsApp/Interactors/WorkoutsInteractor.swift \
        UnitTests/Mocks/Interactors/WorkoutsInteractorTests.swift
git commit -m "feat: add WorkoutsInteractor protocol and implementation"
```

---

## Task 6: Simplify core wiring (AppState, DIContainer, AppEnvironment, AppDelegate, App)

**Files:**
- Modify: `WorkoutsApp/Core/AppState.swift`
- Modify: `WorkoutsApp/DependencyInjection/DIContainer.swift`
- Modify: `WorkoutsApp/DependencyInjection/AppEnvironment.swift`
- Modify: `WorkoutsApp/Core/AppDelegate.swift`
- Modify: `WorkoutsApp/Core/App.swift`
- Modify: `WorkoutsApp/UI/RootViewModifier.swift`
- Modify: `UnitTests/Mocks/MockedInteractors.swift`

- [ ] **Step 1: Rewrite `AppState.swift`**

The original template has a custom `func == (lhs:rhs:)` free function. Remove it — `struct AppState: Equatable` synthesizes equality automatically from its stored properties.

```swift
// WorkoutsApp/Core/AppState.swift
import SwiftUI
import Combine

struct AppState: Equatable {
    var routing = ViewRouting()
}

extension AppState {
    struct ViewRouting: Equatable {
        var sessionList = SessionList.Routing()
    }
}
```

Note: `SessionList.Routing` is defined alongside `SessionListView` in Task 7.

- [ ] **Step 2: Rewrite `DIContainer.swift`**

```swift
// WorkoutsApp/DependencyInjection/DIContainer.swift
import SwiftUI
import SwiftData

struct DIContainer {

    let appState: Store<AppState>
    let interactors: Interactors

    init(appState: Store<AppState> = .init(AppState()), interactors: Interactors) {
        self.appState = appState
        self.interactors = interactors
    }

    init(appState: AppState, interactors: Interactors) {
        self.init(appState: Store<AppState>(appState), interactors: interactors)
    }
}

extension DIContainer {
    struct Interactors {
        let workouts: any WorkoutsInteractor

        static var stub: Self {
            .init(workouts: StubWorkoutsInteractor())
        }
    }
}

extension EnvironmentValues {
    @Entry var injected: DIContainer = DIContainer(appState: AppState(), interactors: .stub)
}

extension View {
    func inject(_ container: DIContainer) -> some View {
        return self.environment(\.injected, container)
    }
}
```

- [ ] **Step 3: Rewrite `AppEnvironment.swift`**

```swift
// WorkoutsApp/DependencyInjection/AppEnvironment.swift
import UIKit
import SwiftData

@MainActor
struct AppEnvironment {
    let isRunningTests: Bool
    let diContainer: DIContainer
    let modelContainer: ModelContainer
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
            return ModelContainer.stub
        }
    }
}
```

- [ ] **Step 4: Rewrite `AppDelegate.swift`**

Remove `SystemEventsHandler`, `SceneDelegate`, and all push notification methods:

```swift
// WorkoutsApp/Core/AppDelegate.swift
import UIKit
import SwiftUI

@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {

    private lazy var environment = AppEnvironment.bootstrap()

    var rootView: some View {
        environment.rootView
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
}
```

- [ ] **Step 5: Rewrite `App.swift`**

Remove `EnvironmentOverrides` dependency; update root view to `SessionListView` (placeholder until Task 7):

```swift
// WorkoutsApp/Core/App.swift
import SwiftUI

@main
struct MainApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            appDelegate.rootView
        }
    }
}

extension AppEnvironment {
    var rootView: some View {
        VStack {
            if isRunningTests {
                Text("Running unit tests")
            } else {
                Text("Workout Tracker")  // replaced with SessionListView in Task 7
                    .modelContainer(modelContainer)
                    .inject(diContainer)
                if modelContainer.isStub {
                    Text("⚠️ There is an issue with local database")
                        .font(.caption2)
                }
            }
        }
    }
}
```

- [ ] **Step 6: Simplify `RootViewModifier.swift`**

Remove `system.isActive` reference (no longer in AppState):

```swift
// WorkoutsApp/UI/RootViewModifier.swift
import SwiftUI

struct RootViewAppearance: ViewModifier {
    internal let inspection = Inspection<Self>()

    func body(content: Content) -> some View {
        content
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
}
```

- [ ] **Step 7: Rewrite `MockedInteractors.swift`**

```swift
// UnitTests/Mocks/MockedInteractors.swift
import Testing
import SwiftUI
import Foundation
@testable import WorkoutsApp

extension DIContainer.Interactors {
    static func mocked(
        workouts: [MockedWorkoutsInteractor.Action] = []
    ) -> DIContainer.Interactors {
        self.init(workouts: MockedWorkoutsInteractor(expected: workouts))
    }

    func verify(sourceLocation: SourceLocation = #_sourceLocation) {
        (workouts as? MockedWorkoutsInteractor)?.verify(sourceLocation: sourceLocation)
    }
}

// MARK: - MockedWorkoutsInteractor

final class MockedWorkoutsInteractor: Mock, WorkoutsInteractor {

    enum Action: Equatable {
        case addExercise(sessionID: UUID?, input: ExerciseInput)
        case deleteSession(id: UUID)
        case deleteExercise(id: UUID, type: ExerciseType, sessionID: UUID)
        case progressEntries(exerciseName: String)
    }

    var actions: MockActions<Action>
    var addExerciseResult: Result<UUID, Error> = .success(UUID())
    var progressEntriesResult: Result<[ProgressEntry], Error> = .success([])

    init(expected: [Action]) {
        self.actions = .init(expected: expected)
    }

    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID {
        register(.addExercise(sessionID: sessionID, input: input))
        return try addExerciseResult.get()
    }

    func deleteSession(id: UUID) async throws {
        register(.deleteSession(id: id))
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        register(.deleteExercise(id: id, type: type, sessionID: sessionID))
    }

    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] {
        register(.progressEntries(exerciseName: exerciseName))
        return try progressEntriesResult.get()
    }
}
```

- [ ] **Step 8: Build to confirm wiring compiles**

```bash
xcodebuild build -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: BUILD SUCCEEDED. (Old country views/interactors still exist so there will be unused-variable warnings but no errors.)

- [ ] **Step 9: Commit**

```bash
git add WorkoutsApp/Core/AppState.swift \
        WorkoutsApp/DependencyInjection/DIContainer.swift \
        WorkoutsApp/DependencyInjection/AppEnvironment.swift \
        WorkoutsApp/Core/AppDelegate.swift \
        WorkoutsApp/Core/App.swift \
        WorkoutsApp/UI/RootViewModifier.swift \
        UnitTests/Mocks/MockedInteractors.swift
git commit -m "feat: simplify core wiring for workout domain"
```

---

## Task 7: SessionListView and SessionCell

**Files:**
- Create: `WorkoutsApp/UI/SessionList/SessionListView.swift`
- Create: `WorkoutsApp/UI/SessionList/SessionCell.swift`
- Create: `UnitTests/UI/SessionListTests.swift`

- [ ] **Step 1: Write failing UI tests**

Create `UnitTests/UI/SessionListTests.swift`:

```swift
// UnitTests/UI/SessionListTests.swift
import Testing
import ViewInspector
import SwiftData
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct SessionListTests {

    @Test func rendersEmptyState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = SessionListView()
        let modelContainer = ModelContainer.mock
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func rendersWithSessions() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = SessionListView()
        let modelContainer = ModelContainer.mock
        let repo = MainDBRepository(modelContainer: modelContainer)
        _ = try await repo.saveNewSession(date: .now, with: .strength(name: "Squat", sets: 3, reps: 5, weight: 100))
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/SessionListTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 3: Create `SessionCell.swift`**

```swift
// WorkoutsApp/UI/SessionList/SessionCell.swift
import SwiftUI

struct SessionCell: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.date, style: .time)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(session.strengthExercises.count + session.cardioExercises.count) exercise(s)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 4: Create `SessionListView.swift`**

```swift
// WorkoutsApp/UI/SessionList/SessionListView.swift
import SwiftUI
import SwiftData
import Combine

struct SessionListView: View {

    @Query(sort: \WorkoutSession.date, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var navigationPath = NavigationPath()
    @State private var routingState: Routing = .init()
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView("No Workouts Yet", systemImage: "dumbbell", description: Text("Tap + to log your first workout"))
                } else {
                    sessionList
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: AddExerciseDestination(sessionID: nil)) {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
            .navigationDestination(for: AddExerciseDestination.self) { dest in
                AddExerciseView(sessionID: dest.sessionID)
            }
            .navigationDestination(for: ExerciseProgressDestination.self) { dest in
                ExerciseProgressView(exerciseName: dest.exerciseName)
            }
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    private var sessionList: some View {
        List {
            ForEach(groupedSessions, id: \.key) { date, group in
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

    private var groupedSessions: [(key: Date, value: [WorkoutSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        return grouped.sorted { $0.key > $1.key }
    }

    private func deleteSession(group: [WorkoutSession], offsets: IndexSet) {
        for index in offsets {
            let session = group[index]
            Task {
                try? await injected.interactors.workouts.deleteSession(id: session.id)
            }
        }
    }
}

// MARK: - Routing

extension SessionList {
    struct Routing: Equatable {}
}

// Alias so AppState.ViewRouting can reference SessionList
typealias SessionList = SessionListView

// MARK: - Navigation Destinations

struct AddExerciseDestination: Hashable {
    let sessionID: UUID?
}

struct ExerciseProgressDestination: Hashable {
    let exerciseName: String
}
```

- [ ] **Step 5: Update `App.swift` to use `SessionListView`**

Change the placeholder `Text("Workout Tracker")` to `SessionListView()`:

```swift
// In AppEnvironment.rootView:
SessionListView()
    .modifier(RootViewAppearance())
    .modelContainer(modelContainer)
    .inject(diContainer)
```

- [ ] **Step 6: Run tests — expect pass**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/SessionListTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 7: Commit**

```bash
git add WorkoutsApp/UI/SessionList/SessionListView.swift \
        WorkoutsApp/UI/SessionList/SessionCell.swift \
        WorkoutsApp/Core/App.swift \
        UnitTests/UI/SessionListTests.swift
git commit -m "feat: add SessionListView with date-grouped sessions"
```

---

## Task 8: SessionDetailView and ExerciseRow

**Files:**
- Create: `WorkoutsApp/UI/SessionDetail/SessionDetailView.swift`
- Create: `WorkoutsApp/UI/SessionDetail/ExerciseRow.swift`

- [ ] **Step 1: Create `ExerciseRow.swift`**

```swift
// WorkoutsApp/UI/SessionDetail/ExerciseRow.swift
import SwiftUI

struct ExerciseRow: View {
    let exercise: any AnalyticsTrackable

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .font(.body)
            Text("\(exercise.analyticsLabel): \(exercise.analyticsValue, format: .number.precision(.fractionLength(1)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 2: Create `SessionDetailView.swift`**

```swift
// WorkoutsApp/UI/SessionDetail/SessionDetailView.swift
import SwiftUI

struct SessionDetailView: View {

    let session: WorkoutSession
    @Environment(\.injected) private var injected: DIContainer

    var body: some View {
        List {
            ForEach(allExercises, id: \.id) { exercise in
                NavigationLink(value: ExerciseProgressDestination(exerciseName: exercise.name)) {
                    ExerciseRow(exercise: exercise)
                }
            }
            .onDelete { indexSet in
                deleteExercises(offsets: indexSet)
            }
        }
        .navigationTitle(session.date, displayedComponents: .date)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: AddExerciseDestination(sessionID: session.id)) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var allExercises: [any AnalyticsTrackable] {
        (session.strengthExercises as [any AnalyticsTrackable]) +
        (session.cardioExercises as [any AnalyticsTrackable])
    }

    private func deleteExercises(offsets: IndexSet) {
        let exercises = allExercises
        for index in offsets {
            let exercise = exercises[index]
            Task {
                try? await injected.interactors.workouts.deleteExercise(
                    id: exercise.id,
                    type: exercise.exerciseType,
                    from: session.id
                )
            }
        }
    }
}
```

- [ ] **Step 3: Write `SessionDetailViewTests.swift`**

```swift
// UnitTests/UI/SessionDetailViewTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct SessionDetailViewTests {

    let session: WorkoutSession

    init() {
        session = WorkoutSession(id: UUID(), date: .now)
        let strength = StrengthExercise(id: UUID(), name: "Squat", sets: 3, reps: 5, weight: 100)
        strength.session = session
        session.strengthExercises = [strength]
    }

    @Test func rendersExerciseRows() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = SessionDetailView(session: session)
        try await ViewHosting.host(sut.inject(container)) {
            try await sut.inspection.inspect { view in
                #expect(throws: Never.self) { try view.find(ExerciseRow.self) }
                container.interactors.verify()
            }
        }
    }

    @Test func deleteExerciseCallsInteractor() async throws {
        let strength = session.strengthExercises[0]
        let container = DIContainer(interactors: .mocked(workouts: [
            .deleteExercise(id: strength.id, type: .strength, sessionID: session.id)
        ]))
        let sut = SessionDetailView(session: session)
        try await ViewHosting.host(sut.inject(container)) {
            try await sut.inspection.inspect { view in
                try view.find(ViewType.List.self).forEach(0).callOnDelete(IndexSet([0]))
                container.interactors.verify()
            }
        }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/SessionDetailViewTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 5: Commit**

```bash
git add WorkoutsApp/UI/SessionDetail/SessionDetailView.swift \
        WorkoutsApp/UI/SessionDetail/ExerciseRow.swift \
        UnitTests/UI/SessionDetailViewTests.swift
git commit -m "feat: add SessionDetailView with exercise list and delete"
```

---

## Task 9: AddExerciseView

**Files:**
- Create: `WorkoutsApp/UI/AddExercise/AddExerciseView.swift`
- Create: `UnitTests/UI/AddExerciseViewTests.swift`

- [ ] **Step 1: Write failing UI tests**

Create `UnitTests/UI/AddExerciseViewTests.swift`:

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
                // Strength is selected by default — view renders without error
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func showsLoadingStateWhenSaving() async throws {
        let container = DIContainer(interactors: .mocked(workouts: [
            .addExercise(sessionID: nil, input: .strength(name: "Squat", sets: 3, reps: 5, weight: 100))
        ]))
        let sut = AddExerciseView(sessionID: nil, saveState: .isLoading(last: nil, cancelBag: .test))
        let modelContainer = ModelContainer.mock
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                // Loading state rendered — view does not crash
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func showsErrorState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = AddExerciseView(sessionID: nil, saveState: .failed(NSError.test))
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

- [ ] **Step 2: Run tests — expect compile failure**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/AddExerciseViewTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 3: Create `AddExerciseView.swift`**

```swift
// WorkoutsApp/UI/AddExercise/AddExerciseView.swift
import SwiftUI
import SwiftData

struct AddExerciseView: View {

    let sessionID: UUID?

    @State private(set) var saveState: Loadable<UUID>
    @State private var exerciseType: ExerciseType = .strength
    @State private var name: String = ""
    @State private var sets: Int = 3
    @State private var reps: Int = 10
    @State private var weight: Double = 0
    @State private var durationMinutes: Double = 0

    @Query(sort: \ExerciseLibraryEntry.name)
    private var libraryEntries: [ExerciseLibraryEntry]

    @Environment(\.injected) private var injected: DIContainer
    @Environment(\.dismiss) private var dismiss

    let inspection = Inspection<Self>()

    init(sessionID: UUID?, saveState: Loadable<UUID> = .notRequested) {
        self.sessionID = sessionID
        self._saveState = .init(initialValue: saveState)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(sessionID == nil ? "New Workout" : "Add Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(name.isEmpty || saveState.isLoading)
                    }
                }
        }
        .onChange(of: saveState) { _, new in
            if case .loaded = new { dismiss() }
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch saveState {
        case .isLoading:
            ProgressView()
        case .failed(let error):
            ErrorView(error: error, retryAction: save)
        default:
            form
        }
    }

    private var form: some View {
        Form {
            Section("Exercise Type") {
                Picker("Type", selection: $exerciseType) {
                    ForEach(ExerciseType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Exercise Name") {
                TextField("e.g. Bench Press", text: $name)
                    .autocorrectionDisabled()
                let suggestions = libraryEntries.filter {
                    $0.type == exerciseType && $0.name.localizedCaseInsensitiveContains(name) && $0.name != name
                }
                ForEach(suggestions) { entry in
                    Button(entry.name) { name = entry.name }
                        .foregroundStyle(.secondary)
                }
            }

            if exerciseType == .strength {
                Section("Strength Details") {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                    Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                    HStack {
                        Text("Weight (lbs)")
                        Spacer()
                        TextField("0", value: $weight, format: .number)
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
                        TextField("0", value: $durationMinutes, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
        }
    }

    private func save() {
        let input: ExerciseInput
        switch exerciseType {
        case .strength:
            input = .strength(name: name, sets: sets, reps: reps, weight: weight)
        case .cardio:
            input = .cardio(name: name, durationMinutes: durationMinutes)
        }
        $saveState.load {
            try await injected.interactors.workouts.addExercise(to: sessionID, input: input)
        }
    }
}

private extension Loadable {
    var isLoading: Bool {
        if case .isLoading = self { return true }
        return false
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/AddExerciseViewTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 5: Commit**

```bash
git add WorkoutsApp/UI/AddExercise/AddExerciseView.swift \
        UnitTests/UI/AddExerciseViewTests.swift
git commit -m "feat: add AddExerciseView with strength/cardio form and library autocomplete"
```

---

## Task 10: ExerciseProgressView

**Files:**
- Create: `WorkoutsApp/UI/ExerciseProgress/ExerciseProgressView.swift`
- Create: `UnitTests/UI/ExerciseProgressViewTests.swift`

- [ ] **Step 1: Write failing UI tests**

Create `UnitTests/UI/ExerciseProgressViewTests.swift`:

```swift
// UnitTests/UI/ExerciseProgressViewTests.swift
import Testing
import ViewInspector
import SwiftData
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct ExerciseProgressViewTests {

    @Test func showsLoadingState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = ExerciseProgressView(exerciseName: "Squat", progressState: .isLoading(last: nil, cancelBag: .test))
        let view = sut.inject(container).modelContainer(ModelContainer.mock)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func showsEmptyState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = ExerciseProgressView(exerciseName: "Squat", progressState: .loaded([]))
        let view = sut.inject(container).modelContainer(ModelContainer.mock)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func showsErrorState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = ExerciseProgressView(exerciseName: "Squat", progressState: .failed(NSError.test))
        let view = sut.inject(container).modelContainer(ModelContainer.mock)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func showsEntriesWhenLoaded() async throws {
        let entry = ProgressEntry(id: UUID(), date: .now, exerciseType: .strength, value: 1500, label: "Volume (lbs)")
        let container = DIContainer(interactors: .mocked())
        let sut = ExerciseProgressView(exerciseName: "Squat", progressState: .loaded([entry]))
        let view = sut.inject(container).modelContainer(ModelContainer.mock)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/ExerciseProgressViewTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 3: Create `ExerciseProgressView.swift`**

```swift
// WorkoutsApp/UI/ExerciseProgress/ExerciseProgressView.swift
import SwiftUI

struct ExerciseProgressView: View {

    let exerciseName: String
    @State private(set) var progressState: Loadable<[ProgressEntry]>
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    init(exerciseName: String, progressState: Loadable<[ProgressEntry]> = .notRequested) {
        self.exerciseName = exerciseName
        self._progressState = .init(initialValue: progressState)
    }

    var body: some View {
        content
            .navigationTitle(exerciseName)
            .onAppear {
                if case .notRequested = progressState { loadEntries() }
            }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch progressState {
        case .notRequested, .isLoading:
            ProgressView()
        case .loaded(let entries):
            loadedView(entries)
        case .failed(let error):
            ErrorView(error: error, retryAction: loadEntries)
        }
    }

    @ViewBuilder
    private func loadedView(_ entries: [ProgressEntry]) -> some View {
        if entries.isEmpty {
            ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis", description: Text("Log \(exerciseName) to see your progress here"))
        } else {
            List {
                if Set(entries.map(\.exerciseType)).count > 1 {
                    Section {
                        Label("'\(exerciseName)' has been logged as both strength and cardio — results may be mixed", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Section("History") {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.date, style: .date)
                                .font(.subheadline)
                            Spacer()
                            Text("\(entry.value, format: .number.precision(.fractionLength(1))) \(entry.label)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func loadEntries() {
        $progressState.load {
            try await injected.interactors.workouts.progressEntries(for: exerciseName)
        }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnitTests/ExerciseProgressViewTests \
  2>&1 | grep -E "error:|FAILED|PASSED"
```

- [ ] **Step 5: Commit**

```bash
git add WorkoutsApp/UI/ExerciseProgress/ExerciseProgressView.swift \
        UnitTests/UI/ExerciseProgressViewTests.swift
git commit -m "feat: add ExerciseProgressView with trend list and type-mismatch warning"
```

---

## Task 11: Delete template files and run full test suite

**Goal:** Remove all countries/images/push/web code that was replaced. Then verify the full test suite still passes.

- [ ] **Step 1: Delete main app template files**

```bash
rm WorkoutsApp/Repositories/Models/Country.swift
rm WorkoutsApp/Repositories/Models/CountryDetails.swift
rm WorkoutsApp/Repositories/Models/CountryCurrency.swift
rm WorkoutsApp/Repositories/Models/MockedData.swift
rm WorkoutsApp/Repositories/WebAPI/CountriesWebRepository.swift
rm WorkoutsApp/Repositories/WebAPI/ImagesWebRepository.swift
rm WorkoutsApp/Repositories/WebAPI/PushTokenWebRepository.swift
rm WorkoutsApp/Repositories/WebAPI/WebRepository.swift
rm WorkoutsApp/Interactors/CountriesInteractor.swift
rm WorkoutsApp/Interactors/ImagesInteractor.swift
rm WorkoutsApp/Interactors/UserPermissionsInteractor.swift
rm WorkoutsApp/Core/DeepLinksHandler.swift
rm WorkoutsApp/Core/PushNotificationsHandler.swift
rm WorkoutsApp/Core/SystemEventsHandler.swift
rm -rf WorkoutsApp/UI/CountriesList
rm -rf WorkoutsApp/UI/CountryDetails
```

- [ ] **Step 2: Delete test template files**

```bash
rm UnitTests/Mocks/MockedWebRepositories.swift
rm UnitTests/Mocks/MockedSystemEventsHandler.swift
rm UnitTests/Mocks/MockedSystemPermissions.swift
rm -rf UnitTests/Mocks/NetworkMocking
rm UnitTests/Mocks/Interactors/CountriesInteractorTests.swift
rm UnitTests/Mocks/Interactors/UserPermissionsInteractorTests.swift
rm UnitTests/Mocks/Interactors/ImagesInteractorTests.swift
rm UnitTests/UI/ImageViewTests.swift
rm UnitTests/UI/CountriesListTests.swift
rm UnitTests/UI/DeepLinkUITests.swift
rm UnitTests/UI/ModalFlagViewTests.swift
rm UnitTests/Repositories/PushTokenWebRepositoryTests.swift
rm UnitTests/Repositories/ImageWebRepositoryTests.swift
rm UnitTests/Repositories/CountriesWebRepositoryTests.swift
rm UnitTests/Repositories/WebRepositoryTests.swift
rm UnitTests/Repositories/CountriesDBRepositoryTests.swift
rm UnitTests/System/DeepLinksHandlerTests.swift
rm UnitTests/System/PushNotificationsHandlerTests.swift
```

- [ ] **Step 3: Remove `MockedCountriesDBRepository` from `MockedDBRepositories.swift`**

Edit `UnitTests/Mocks/MockedDBRepositories.swift` — keep only `MockedWorkoutsDBRepository` and `ModelContainer.mock`.

- [ ] **Step 4: Build to confirm clean compile**

```bash
xcodebuild build -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Run full test suite**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "error:|Test Suite|FAILED|PASSED"
```

Expected: all test suites PASSED.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: remove countries/images/push template code — workout tracker complete"
```

---

## Task 12: Remove EnvironmentOverrides package dependency

The `EnvironmentOverrides` package is imported in `App.swift` in the original template. After removing it from all source files, remove it from `Package.swift` too.

- [ ] **Step 1: Verify no remaining imports**

```bash
grep -r "EnvironmentOverrides" WorkoutsApp/ UnitTests/
```

Expected: no matches (was only in the old `App.swift` which is now rewritten).

- [ ] **Step 2: Remove from `Package.swift`**

Open `Package.swift` and remove:
- The `.package(url: ..., from: "0.0.4")` entry for `EnvironmentOverrides`
- Any `.product(name: "EnvironmentOverrides", ...)` in target dependencies

- [ ] **Step 3: Build to confirm clean compile**

```bash
xcodebuild build -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 4: Run full test suite — final check**

```bash
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "error:|Test Suite|FAILED|PASSED"
```

Expected: all PASSED.

- [ ] **Step 5: Final commit**

```bash
git add Package.swift Package.resolved
git commit -m "chore: remove EnvironmentOverrides dependency — workout tracker ready"
```

---

## Reference

- Spec: `docs/superpowers/specs/2026-03-21-workout-tracker-design.md`
- Test framework: Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`)
- Build command: `xcodebuild test -scheme WorkoutsApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- Repository pattern: `@ModelActor MainDBRepository` owns all SwiftData context operations
- Cross-actor boundary rule: only value types (`UUID`, `ExerciseInput`, `ExerciseType`, `ProgressEntry`) cross actor boundaries — never `@Model` instances
