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
        case addExercise(sessionID: UUID?, input: ExerciseInput)
        case deleteSession(id: UUID)
        case deleteExercise(id: UUID, type: ExerciseType, sessionID: UUID)
        case progressEntries(exerciseName: String)
        case fetchSessions
        case fetchSession(id: UUID)
        case fetchLibraryEntries
        case fetchExerciseOverviews(type: ExerciseType)
    }

    var actions: MockActions<Action>
    var addExerciseResult: Result<UUID, Error> = .success(UUID())
    var progressEntriesResult: Result<[ProgressEntry], Error> = .success([])
    var fetchSessionsResult: Result<[WorkoutSessionDTO], Error> = .success([])
    var fetchSessionResult: Result<WorkoutSessionDTO, Error> = .failure(SessionNotFoundError())
    var fetchLibraryEntriesResult: Result<[ExerciseLibraryEntryDTO], Error> = .success([])
    var fetchExerciseOverviewsResult: Result<[ExerciseOverviewDTO], Error> = .success([])

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

    func fetchExerciseOverviews(type: ExerciseType) async throws -> [ExerciseOverviewDTO] {
        register(.fetchExerciseOverviews(type: type))
        return try fetchExerciseOverviewsResult.get()
    }
}
