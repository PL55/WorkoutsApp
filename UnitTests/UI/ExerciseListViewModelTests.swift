// UnitTests/UI/ExerciseListViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct ExerciseListViewModelTests {

    private func makeOverview(name: String, lastDate: Date, best: Double = 100, latest: Double = 80) -> ExerciseOverviewDTO {
        ExerciseOverviewDTO(id: name, name: name, exerciseType: .strength,
                            bestValue: best, latestValue: latest,
                            lastDate: lastDate, analyticsLabel: "Volume (lbs)")
    }

    // MARK: - loadOverviews

    @Test func loadOverviewsTransitionsToLoaded() async throws {
        let overview = makeOverview(name: "Bench Press", lastDate: .now)
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .strength)])
        mocked.fetchExerciseOverviewsResult = .success([overview])

        let vm = ExerciseListViewModel()
        vm.configure(interactor: mocked)
        vm.loadOverviews(type: .strength)

        for _ in 0..<100 where vm.overviews.isLoading { await Task.yield() }

        if case .loaded(let items) = vm.overviews {
            #expect(items.count == 1)
        } else {
            Issue.record("Expected .loaded, got \(vm.overviews)")
        }
        mocked.verify()
    }

    @Test func loadOverviewsTransitionsToFailedOnError() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .cardio)])
        mocked.fetchExerciseOverviewsResult = .failure(NSError.test)

        let vm = ExerciseListViewModel()
        vm.configure(interactor: mocked)
        vm.loadOverviews(type: .cardio)

        for _ in 0..<100 where vm.overviews.isLoading { await Task.yield() }

        #expect(vm.overviews.error != nil)
        mocked.verify()
    }

    @Test func loadOverviewsPopulatesSortedOverviews() async throws {
        let a = makeOverview(name: "Arnold Press", lastDate: .now)
        let b = makeOverview(name: "Bench Press", lastDate: .now)
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .strength)])
        mocked.fetchExerciseOverviewsResult = .success([b, a])

        let vm = ExerciseListViewModel()
        vm.configure(interactor: mocked)
        vm.loadOverviews(type: .strength)

        for _ in 0..<100 where vm.overviews.isLoading { await Task.yield() }

        #expect(vm.sortedOverviews.map(\.name) == ["Arnold Press", "Bench Press"])
    }

    // MARK: - sortOrder

    @Test func sortOrderAlphabeticalSortsByName() async throws {
        let a = makeOverview(name: "Squat", lastDate: .distantPast)
        let b = makeOverview(name: "Bench Press", lastDate: .now)
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .strength)])
        mocked.fetchExerciseOverviewsResult = .success([a, b])

        let vm = ExerciseListViewModel()
        vm.configure(interactor: mocked)
        vm.loadOverviews(type: .strength)
        for _ in 0..<100 where vm.overviews.isLoading { await Task.yield() }

        vm.sortOrder = .alphabetical
        #expect(vm.sortedOverviews.map(\.name) == ["Bench Press", "Squat"])
    }

    @Test func sortOrderMostRecentSortsByLastDateDescending() async throws {
        let old = makeOverview(name: "Squat", lastDate: .distantPast)
        let recent = makeOverview(name: "Bench Press", lastDate: .now)
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .strength)])
        mocked.fetchExerciseOverviewsResult = .success([old, recent])

        let vm = ExerciseListViewModel()
        vm.configure(interactor: mocked)
        vm.loadOverviews(type: .strength)
        for _ in 0..<100 where vm.overviews.isLoading { await Task.yield() }

        vm.sortOrder = .mostRecent
        #expect(vm.sortedOverviews.first?.name == "Bench Press")
    }

    @Test func sortOrderLeastRecentSortsByLastDateAscending() async throws {
        let old = makeOverview(name: "Squat", lastDate: .distantPast)
        let recent = makeOverview(name: "Bench Press", lastDate: .now)
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .strength)])
        mocked.fetchExerciseOverviewsResult = .success([old, recent])

        let vm = ExerciseListViewModel()
        vm.configure(interactor: mocked)
        vm.loadOverviews(type: .strength)
        for _ in 0..<100 where vm.overviews.isLoading { await Task.yield() }

        vm.sortOrder = .leastRecent
        #expect(vm.sortedOverviews.first?.name == "Squat")
    }

    @Test func sortOrderChangeDoesNotTriggerRefetch() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.fetchExerciseOverviews(type: .strength)])
        mocked.fetchExerciseOverviewsResult = .success([])

        let vm = ExerciseListViewModel()
        vm.configure(interactor: mocked)
        vm.loadOverviews(type: .strength)
        for _ in 0..<100 where vm.overviews.isLoading { await Task.yield() }

        vm.sortOrder = .mostRecent
        vm.sortOrder = .leastRecent
        // mocked.verify() confirms no extra fetchExerciseOverviews calls were made
        mocked.verify()
    }
}
