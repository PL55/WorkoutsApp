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
        mockedDB.startSessionResult = .success(fixedSessionID)
    }
}

// MARK: - startSession

final class StartSessionTests: WorkoutsInteractorTests {

    @Test func delegatesToRepository() async throws {
        mockedDB.actions = .init(expected: [.startSession(name: "Leg Day")])
        let id = try await sut.startSession(name: "Leg Day")
        #expect(id == fixedSessionID)
        mockedDB.verify()
    }
}

// MARK: - endSession

final class EndSessionTests: WorkoutsInteractorTests {

    @Test func delegatesToRepository() async throws {
        let sessionID = UUID()
        mockedDB.actions = .init(expected: [.endSession(id: sessionID)])
        try await sut.endSession(id: sessionID)
        mockedDB.verify()
    }
}

// MARK: - cancelSession

final class CancelSessionTests: WorkoutsInteractorTests {

    @Test func delegatesToRepository() async throws {
        let sessionID = UUID()
        mockedDB.actions = .init(expected: [.cancelSession(id: sessionID)])
        try await sut.cancelSession(id: sessionID)
        mockedDB.verify()
    }
}

// MARK: - renameSession

final class RenameSessionTests: WorkoutsInteractorTests {

    @Test func delegatesToRepository() async throws {
        let sessionID = UUID()
        mockedDB.actions = .init(expected: [.renameSession(id: sessionID, name: "Push Day")])
        try await sut.renameSession(id: sessionID, name: "Push Day")
        mockedDB.verify()
    }
}

// MARK: - fetchActiveSession

final class FetchActiveSessionTests: WorkoutsInteractorTests {

    @Test func forwardsResultFromRepository() async throws {
        let dto = WorkoutSessionDTO(id: UUID(), date: .now, name: "My Session", status: .active,
                                    strengthExercises: [], cardioExercises: [])
        mockedDB.actions = .init(expected: [.fetchActiveSession])
        mockedDB.fetchActiveSessionResult = .success(dto)
        let result = try await sut.fetchActiveSession()
        #expect(result?.id == dto.id)
        #expect(result?.status == .active)
        mockedDB.verify()
    }

    @Test func returnsNilWhenNoActiveSession() async throws {
        mockedDB.actions = .init(expected: [.fetchActiveSession])
        mockedDB.fetchActiveSessionResult = .success(nil)
        let result = try await sut.fetchActiveSession()
        #expect(result == nil)
        mockedDB.verify()
    }
}

// MARK: - fetchAllSessions

final class FetchAllSessionsTests: WorkoutsInteractorTests {

    @Test func forwardsAllSessionsFromRepository() async throws {
        let active = WorkoutSessionDTO(id: UUID(), date: .now, name: "", status: .active,
                                       strengthExercises: [], cardioExercises: [])
        let completed = WorkoutSessionDTO(id: UUID(), date: .now, name: "", status: .completed,
                                          strengthExercises: [], cardioExercises: [])
        mockedDB.actions = .init(expected: [.fetchAllSessions])
        mockedDB.fetchAllSessionsResult = .success([active, completed])
        let result = try await sut.fetchAllSessions()
        #expect(result.count == 2)
        mockedDB.verify()
    }
}

// MARK: - fetchSessions (completed only)

final class FetchSessionsTests: WorkoutsInteractorTests {

    @Test func forwardsCompletedSessionsFromRepository() async throws {
        let dto = WorkoutSessionDTO(id: UUID(), date: .now, name: "", status: .completed,
                                    strengthExercises: [], cardioExercises: [])
        mockedDB.actions = .init(expected: [.fetchSessions])
        mockedDB.fetchSessionsResult = .success([dto])
        let result = try await sut.fetchSessions()
        #expect(result.count == 1)
        #expect(result[0].id == dto.id)
        mockedDB.verify()
    }
}

// MARK: - fetchSession

final class FetchSessionTests: WorkoutsInteractorTests {

    @Test func forwardsSingleSessionFromRepository() async throws {
        let sessionID = UUID()
        let dto = WorkoutSessionDTO(id: sessionID, date: .now, name: "", status: .completed,
                                    strengthExercises: [], cardioExercises: [])
        mockedDB.actions = .init(expected: [.fetchSession(id: sessionID)])
        mockedDB.fetchSessionResult = .success(dto)
        let result = try await sut.fetchSession(id: sessionID)
        #expect(result.id == sessionID)
        mockedDB.verify()
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
        let entry = ProgressEntry(id: UUID(), sessionID: UUID(), date: .now, exerciseType: .strength, value: 1000, label: "Volume (lbs)")
        mockedDB.actions = .init(expected: [.progressEntries(exerciseName: "Squat")])
        mockedDB.progressEntriesResult = .success([entry])
        let result = try await sut.progressEntries(for: "Squat")
        #expect(result == [entry])
        mockedDB.verify()
    }
}

// MARK: - fetchLibraryEntries

final class FetchLibraryEntriesTests: WorkoutsInteractorTests {

    @Test func forwardsLibraryEntriesFromRepository() async throws {
        let entry = ExerciseLibraryEntryDTO(id: UUID(), name: "Squat", type: .strength)
        mockedDB.actions = .init(expected: [.fetchLibraryEntries])
        mockedDB.fetchLibraryEntriesResult = .success([entry])
        let result = try await sut.fetchLibraryEntries()
        #expect(result.count == 1)
        #expect(result[0].name == "Squat")
        mockedDB.verify()
    }
}

// MARK: - fetchExerciseOverviews

final class FetchExerciseOverviewsTests: WorkoutsInteractorTests {

    @Test func forwardsStrengthOverviewsFromRepository() async throws {
        let overview = ExerciseOverviewDTO(id: "Bench Press", name: "Bench Press", exerciseType: .strength,
                                           bestValue: 1000, latestValue: 800, lastDate: .now, analyticsLabel: "Volume (lbs)")
        mockedDB.actions = .init(expected: [.fetchExerciseOverviews(type: .strength)])
        mockedDB.fetchExerciseOverviewsResult = .success([overview])
        let result = try await sut.fetchExerciseOverviews(type: .strength)
        #expect(result.count == 1)
        #expect(result[0].name == "Bench Press")
        mockedDB.verify()
    }

    @Test func forwardsCardioOverviewsFromRepository() async throws {
        mockedDB.actions = .init(expected: [.fetchExerciseOverviews(type: .cardio)])
        mockedDB.fetchExerciseOverviewsResult = .success([])
        let result = try await sut.fetchExerciseOverviews(type: .cardio)
        #expect(result.isEmpty)
        mockedDB.verify()
    }
}

// MARK: - StubWorkoutsInteractor

final class StubWorkoutsInteractorTests: WorkoutsInteractorTests {
    @Test func stubReturnsDefaults() async throws {
        let stub = StubWorkoutsInteractor()
        let newID = try await stub.startSession(name: "Test")
        #expect(newID != nil)
        try await stub.endSession(id: UUID())
        try await stub.cancelSession(id: UUID())
        try await stub.renameSession(id: UUID(), name: "Renamed")
        let active = try await stub.fetchActiveSession()
        #expect(active == nil)
        let all = try await stub.fetchAllSessions()
        #expect(all.isEmpty)
        let id = try await stub.addExercise(to: nil, input: .cardio(name: "Run", durationMinutes: 20))
        #expect(id != nil)
        try await stub.deleteSession(id: UUID())
        try await stub.deleteExercise(id: UUID(), type: .strength, from: UUID())
        let entries = try await stub.progressEntries(for: "anything")
        #expect(entries.isEmpty)
        let sessions = try await stub.fetchSessions()
        #expect(sessions.isEmpty)
        let session = try await stub.fetchSession(id: UUID())
        #expect(session.strengthExercises.isEmpty)
        let libraryEntries = try await stub.fetchLibraryEntries()
        #expect(libraryEntries.isEmpty)
        let overviews = try await stub.fetchExerciseOverviews(type: .strength)
        #expect(overviews.isEmpty)
    }
}
