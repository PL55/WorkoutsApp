// UnitTests/Mocks/MockedDBRepositories.swift
import Foundation
import SwiftData
@testable import WorkoutsApp

extension ModelContainer {

    static var mock: ModelContainer {
        try! appModelContainer(inMemoryOnly: true, isStub: false)
    }
}

// MARK: - MockedWorkoutsDBRepository

final class MockedWorkoutsDBRepository: Mock, WorkoutsDBRepository {

    enum Action: Equatable {
        case saveNewSession(input: ExerciseInput)
        case addExercise(input: ExerciseInput, sessionID: UUID)
        case deleteSession(id: UUID)
        case deleteExercise(id: UUID, type: ExerciseType, sessionID: UUID)
        case progressEntries(exerciseName: String)
        case libraryContains(name: String)
        case upsertLibraryEntry(name: String, type: ExerciseType)
        case fetchSessions
        case fetchSession(id: UUID)
        case fetchLibraryEntries
    }

    var actions: MockActions<Action>
    var saveNewSessionResult: Result<UUID, Error> = .success(UUID())
    var addExerciseResult: Result<Void, Error> = .success(())
    var deleteSessionResult: Result<Void, Error> = .success(())
    var deleteExerciseResult: Result<Void, Error> = .success(())
    var progressEntriesResult: Result<[ProgressEntry], Error> = .success([])
    var libraryContainsResult: Result<Bool, Error> = .success(false)
    var upsertLibraryEntryResult: Result<Void, Error> = .success(())
    var fetchSessionsResult: Result<[WorkoutSessionDTO], Error> = .success([])
    var fetchSessionResult: Result<WorkoutSessionDTO, Error> = .failure(SessionNotFoundError())
    var fetchLibraryEntriesResult: Result<[ExerciseLibraryEntryDTO], Error> = .success([])

    init(expected: [Action]) {
        self.actions = .init(expected: expected)
    }

    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID {
        register(.saveNewSession(input: input))
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

    func fetchSessions() async throws -> [WorkoutSessionDTO] {
        register(.fetchSessions)
        return try fetchSessionsResult.get()
    }

    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO {
        register(.fetchSession(id: id))
        return try fetchSessionResult.get()
    }

    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO] {
        register(.fetchLibraryEntries)
        return try fetchLibraryEntriesResult.get()
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
