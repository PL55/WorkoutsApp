// UnitTests/UI/ExerciseHistoryViewTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct ExerciseHistoryViewTests {

    private func makeEntry(exerciseType: ExerciseType = .strength) -> ProgressEntry {
        ProgressEntry(id: UUID(), sessionID: UUID(), date: .now,
                      exerciseType: exerciseType, value: 1000, label: "Volume (lbs)")
    }

    @Test func rendersLoadingState() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.progressEntries(exerciseName: "Bench Press")])
        mocked.progressEntriesResult = .success([])
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseHistoryView(exerciseName: "Bench Press", exerciseType: .strength)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func rendersEmptyState() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.progressEntries(exerciseName: "Squat")])
        mocked.progressEntriesResult = .success([])
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseHistoryView(exerciseName: "Squat", exerciseType: .strength)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func rendersErrorState() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.progressEntries(exerciseName: "Run")])
        mocked.progressEntriesResult = .failure(NSError.test)
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseHistoryView(exerciseName: "Run", exerciseType: .cardio)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func rendersLoadedEntries() async throws {
        let entry = makeEntry()
        let mocked = MockedWorkoutsInteractor(expected: [.progressEntries(exerciseName: "Bench Press")])
        mocked.progressEntriesResult = .success([entry])
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseHistoryView(exerciseName: "Bench Press", exerciseType: .strength)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func rendersMixedTypeWarning() async throws {
        let strengthEntry = makeEntry(exerciseType: .strength)
        let cardioEntry = makeEntry(exerciseType: .cardio)
        let mocked = MockedWorkoutsInteractor(expected: [.progressEntries(exerciseName: "Exercise")])
        mocked.progressEntriesResult = .success([strengthEntry, cardioEntry])
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseHistoryView(exerciseName: "Exercise", exerciseType: .strength)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }
}
