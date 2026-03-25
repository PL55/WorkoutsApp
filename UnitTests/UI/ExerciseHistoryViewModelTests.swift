// UnitTests/UI/ExerciseHistoryViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct ExerciseHistoryViewModelTests {

    private func makeEntry(sessionID: UUID = UUID()) -> ProgressEntry {
        ProgressEntry(id: UUID(), sessionID: sessionID, date: .now,
                      exerciseType: .strength, value: 1000, label: "Volume (lbs)")
    }

    @Test func loadEntriesTransitionsToLoaded() async throws {
        let entry = makeEntry()
        let mocked = MockedWorkoutsInteractor(expected: [.progressEntries(exerciseName: "Bench Press")])
        mocked.progressEntriesResult = .success([entry])

        let vm = ExerciseHistoryViewModel()
        vm.configure(interactor: mocked)
        vm.loadEntries(for: "Bench Press")

        for _ in 0..<100 where vm.entries.isLoading { await Task.yield() }

        if case .loaded(let entries) = vm.entries {
            #expect(entries.count == 1)
        } else {
            Issue.record("Expected .loaded, got \(vm.entries)")
        }
        mocked.verify()
    }

    @Test func loadEntriesTransitionsToFailedOnError() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.progressEntries(exerciseName: "Run")])
        mocked.progressEntriesResult = .failure(NSError.test)

        let vm = ExerciseHistoryViewModel()
        vm.configure(interactor: mocked)
        vm.loadEntries(for: "Run")

        for _ in 0..<100 where vm.entries.isLoading { await Task.yield() }

        #expect(vm.entries.error != nil)
        mocked.verify()
    }

    @Test func loadEntriesHandlesEmpty() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.progressEntries(exerciseName: "Squat")])
        mocked.progressEntriesResult = .success([])

        let vm = ExerciseHistoryViewModel()
        vm.configure(interactor: mocked)
        vm.loadEntries(for: "Squat")

        for _ in 0..<100 where vm.entries.isLoading { await Task.yield() }

        if case .loaded(let entries) = vm.entries {
            #expect(entries.isEmpty)
        } else {
            Issue.record("Expected .loaded([]), got \(vm.entries)")
        }
        mocked.verify()
    }
}
