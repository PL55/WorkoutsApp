// UnitTests/UI/AddExerciseViewModelTests.swift
import Testing
import Foundation
import SwiftData
@testable import WorkoutsApp

@MainActor
@Suite struct AddExerciseViewModelTests {

    @Test func filtersSuggestionsByTypeAndName() {
        let vm = AddExerciseViewModel(sessionID: nil)
        let squat = ExerciseLibraryEntry(name: "Squat", type: .strength)
        let bench = ExerciseLibraryEntry(name: "Bench Press", type: .strength)
        let run   = ExerciseLibraryEntry(name: "Run", type: .cardio)

        vm.exerciseType = .strength
        vm.name = "sq"
        vm.updateSuggestions(from: [squat, bench, run])

        #expect(vm.filteredSuggestions.count == 1)
        #expect(vm.filteredSuggestions.first?.name == "Squat")
    }

    @Test func excludesExactNameMatchFromSuggestions() {
        let vm = AddExerciseViewModel(sessionID: nil)
        let squat = ExerciseLibraryEntry(name: "Squat", type: .strength)

        vm.exerciseType = .strength
        vm.name = "Squat"   // exact match → excluded
        vm.updateSuggestions(from: [squat])

        #expect(vm.filteredSuggestions.isEmpty)
    }

    @Test func filtersToSelectedTypeOnly() {
        let vm = AddExerciseViewModel(sessionID: nil)
        let squat = ExerciseLibraryEntry(name: "Squat", type: .strength)
        let run   = ExerciseLibraryEntry(name: "Run", type: .cardio)

        vm.exerciseType = .cardio
        // Use a non-empty name that matches only "Run". Using "" causes ExerciseLibraryEntry
        // @Model properties to be unreliable in parallel test runs without a ModelContext.
        vm.name = "r"
        vm.updateSuggestions(from: [squat, run])

        #expect(vm.filteredSuggestions.count == 1)
        #expect(vm.filteredSuggestions.first?.name == "Run")
    }

    @Test func saveCallsInteractorAndTransitionsToLoaded() async throws {
        let sessionID = UUID()
        let returnedID = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [
            .addExercise(sessionID: sessionID, input: .strength(name: "Squat", sets: 3, reps: 10, weight: 135))
        ])
        mocked.addExerciseResult = .success(returnedID)

        let vm = AddExerciseViewModel(sessionID: sessionID)
        vm.configure(interactor: mocked)
        vm.name = "Squat"
        vm.sets = 3
        vm.reps = 10
        vm.weight = 135
        vm.exerciseType = .strength

        vm.save()

        // Allow the Task fired by save() to complete before asserting
        try await Task.sleep(for: .milliseconds(100))

        mocked.verify()
        if case .loaded(let id) = vm.saveState {
            #expect(id == returnedID)
        } else {
            Issue.record("Expected .loaded, got \(vm.saveState)")
        }
    }

    @Test func saveTransitionsToFailedOnError() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [
            .addExercise(sessionID: nil, input: .cardio(name: "Run", durationMinutes: 30))
        ])
        mocked.addExerciseResult = .failure(NSError.test)

        let vm = AddExerciseViewModel(sessionID: nil)
        vm.configure(interactor: mocked)
        vm.name = "Run"
        vm.durationMinutes = 30
        vm.exerciseType = .cardio

        vm.save()

        // Allow the Task fired by save() to complete before asserting
        try await Task.sleep(for: .milliseconds(100))

        mocked.verify()
        #expect(vm.saveState.error != nil)
    }
}
