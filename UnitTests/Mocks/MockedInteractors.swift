// UnitTests/Mocks/MockedInteractors.swift
import Testing
import SwiftUI
import Foundation
@testable import WorkoutsApp

extension DIContainer.Interactors {
    static func mocked(
        workouts: [MockedWorkoutsInteractor.Action] = []
    ) -> DIContainer.Interactors {
        self.init(
            workouts: MockedWorkoutsInteractor(expected: workouts)
        )
    }

    func verify(sourceLocation: SourceLocation = #_sourceLocation) {
        (workouts as? MockedWorkoutsInteractor)?.verify(sourceLocation: sourceLocation)
    }
}

// MARK: - MockedWorkoutsInteractor

final class MockedWorkoutsInteractor: Mock, WorkoutsInteractor {

    enum Action: Equatable {
        case startSession(name: String)
        case endSession(id: UUID)
        case cancelSession(id: UUID)
        case renameSession(id: UUID, name: String)
        case fetchActiveSession
        case fetchAllSessions
        case fetchSessions
        case fetchSession(id: UUID)
        case addExercise(sessionID: UUID?, input: ExerciseInput)
        case deleteSession(id: UUID)
        case deleteExercise(id: UUID, type: ExerciseType, sessionID: UUID)
        case progressEntries(exerciseName: String)
        case fetchLibraryEntries
        case fetchExerciseOverviews(type: ExerciseType)
    }

    var actions: MockActions<Action>

    var startSessionResult: Result<UUID, Error> = .success(UUID())
    var fetchActiveSessionResult: Result<WorkoutSessionDTO?, Error> = .success(nil)
    var fetchAllSessionsResult: Result<[WorkoutSessionDTO], Error> = .success([])
    var fetchSessionsResult: Result<[WorkoutSessionDTO], Error> = .success([])
    var fetchSessionResult: Result<WorkoutSessionDTO, Error> = .failure(SessionNotFoundError())
    var addExerciseResult: Result<UUID, Error> = .success(UUID())
    var progressEntriesResult: Result<[ProgressEntry], Error> = .success([])
    var fetchLibraryEntriesResult: Result<[ExerciseLibraryEntryDTO], Error> = .success([])
    var fetchExerciseOverviewsResult: Result<[ExerciseOverviewDTO], Error> = .success([])

    init(expected: [Action]) {
        self.actions = .init(expected: expected)
    }

    func startSession(name: String) async throws -> UUID {
        register(.startSession(name: name))
        return try startSessionResult.get()
    }

    func endSession(id: UUID) async throws {
        register(.endSession(id: id))
    }

    func cancelSession(id: UUID) async throws {
        register(.cancelSession(id: id))
    }

    func renameSession(id: UUID, name: String) async throws {
        register(.renameSession(id: id, name: name))
    }

    func fetchActiveSession() async throws -> WorkoutSessionDTO? {
        register(.fetchActiveSession)
        return try fetchActiveSessionResult.get()
    }

    func fetchAllSessions() async throws -> [WorkoutSessionDTO] {
        register(.fetchAllSessions)
        return try fetchAllSessionsResult.get()
    }

    func fetchSessions() async throws -> [WorkoutSessionDTO] {
        register(.fetchSessions)
        return try fetchSessionsResult.get()
    }

    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO {
        register(.fetchSession(id: id))
        return try fetchSessionResult.get()
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

    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO] {
        register(.fetchLibraryEntries)
        return try fetchLibraryEntriesResult.get()
    }

    func fetchExerciseOverviews(type: ExerciseType) async throws -> [ExerciseOverviewDTO] {
        register(.fetchExerciseOverviews(type: type))
        return try fetchExerciseOverviewsResult.get()
    }
}
