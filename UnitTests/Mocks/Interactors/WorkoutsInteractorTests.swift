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

// MARK: - fetchSessions

final class FetchSessionsTests: WorkoutsInteractorTests {

    @Test func forwardsSessionsFromRepository() async throws {
        let dto = WorkoutSessionDTO(id: UUID(), date: .now, strengthExercises: [], cardioExercises: [])
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
        let dto = WorkoutSessionDTO(id: sessionID, date: .now, strengthExercises: [], cardioExercises: [])
        mockedDB.actions = .init(expected: [.fetchSession(id: sessionID)])
        mockedDB.fetchSessionResult = .success(dto)
        let result = try await sut.fetchSession(id: sessionID)
        #expect(result.id == sessionID)
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
        let sessions = try await stub.fetchSessions()
        #expect(sessions.isEmpty)
        let session = try await stub.fetchSession(id: UUID())
        #expect(session.strengthExercises.isEmpty)
        let libraryEntries = try await stub.fetchLibraryEntries()
        #expect(libraryEntries.isEmpty)
    }
}
