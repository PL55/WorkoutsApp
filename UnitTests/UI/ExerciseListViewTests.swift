// UnitTests/UI/ExerciseListViewTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct ExerciseListViewTests {

    @Test func rendersWithStrengthOverviews() async throws {
        let overview = ExerciseOverviewDTO(id: "Bench Press", name: "Bench Press", exerciseType: .strength,
                                           bestValue: 1920, latestValue: 1440, lastDate: .now, analyticsLabel: "Volume (lbs)")
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .strength)])
        mocked.fetchExerciseOverviewsResult = .success([overview])
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseListView()
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func rendersEmptyState() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .strength)])
        mocked.fetchExerciseOverviewsResult = .success([])
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseListView()
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func rendersErrorState() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .strength)])
        mocked.fetchExerciseOverviewsResult = .failure(NSError.test)
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = ExerciseListView()
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }
}
