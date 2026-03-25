// UnitTests/UI/ExerciseSessionSnapshotViewTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct ExerciseSessionSnapshotViewTests {

    @Test func rendersLoadingState() async throws {
        let sessionID = UUID()
        let dto = WorkoutSessionDTO(id: sessionID, date: .now, name: "", status: .completed,
                                    strengthExercises: [StrengthExerciseDTO(id: UUID(), name: "Bench Press", sets: 3, reps: 8, weight: 60)],
                                    cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .success(dto)
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseSessionSnapshotView(exerciseName: "Bench Press", sessionID: sessionID, exerciseType: .strength)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func rendersErrorState() async throws {
        let sessionID = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .failure(SessionNotFoundError())
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseSessionSnapshotView(exerciseName: "Bench Press", sessionID: sessionID, exerciseType: .strength)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func rendersStrengthDetail() async throws {
        let sessionID = UUID()
        let bench = StrengthExerciseDTO(id: UUID(), name: "Bench Press", sets: 4, reps: 6, weight: 80)
        let dto = WorkoutSessionDTO(id: sessionID, date: .now, name: "", status: .completed, strengthExercises: [bench], cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .success(dto)
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseSessionSnapshotView(exerciseName: "Bench Press", sessionID: sessionID, exerciseType: .strength)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func rendersCardioDetail() async throws {
        let sessionID = UUID()
        let run = CardioExerciseDTO(id: UUID(), name: "Running", durationMinutes: 30)
        let dto = WorkoutSessionDTO(id: sessionID, date: .now, name: "", status: .completed, strengthExercises: [], cardioExercises: [run])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .success(dto)
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseSessionSnapshotView(exerciseName: "Running", sessionID: sessionID, exerciseType: .cardio)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }
}
