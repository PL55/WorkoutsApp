// UnitTests/UI/AddExerciseViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct AddExerciseViewModelTests {

    @Test func filtersSuggestionsByTypeAndName() {
        let vm = AddExerciseViewModel(sessionID: nil)
        let squat = ExerciseLibraryEntryDTO(id: UUID(), name: "Squat", type: .strength)
        let bench = ExerciseLibraryEntryDTO(id: UUID(), name: "Bench Press", type: .strength)
        let run   = ExerciseLibraryEntryDTO(id: UUID(), name: "Run", type: .cardio)

        vm.exerciseType = .strength
        vm.name = "sq"
        vm.updateSuggestions(from: [squat, bench, run])

        #expect(vm.filteredSuggestions.count == 1)
        #expect(vm.filteredSuggestions.first?.name == "Squat")
    }

    @Test func excludesExactNameMatchFromSuggestions() {
        let vm = AddExerciseViewModel(sessionID: nil)
        let squat = ExerciseLibraryEntryDTO(id: UUID(), name: "Squat", type: .strength)

        vm.exerciseType = .strength
        vm.name = "Squat"
        vm.updateSuggestions(from: [squat])

        #expect(vm.filteredSuggestions.isEmpty)
    }

    @Test func filtersToSelectedTypeOnly() {
        let vm = AddExerciseViewModel(sessionID: nil)
        let squat = ExerciseLibraryEntryDTO(id: UUID(), name: "Squat", type: .strength)
        let run   = ExerciseLibraryEntryDTO(id: UUID(), name: "Run", type: .cardio)

        vm.exerciseType = .cardio
        vm.name = "r"
        vm.updateSuggestions(from: [squat, run])

        #expect(vm.filteredSuggestions.count == 1)
        #expect(vm.filteredSuggestions.first?.name == "Run")
    }

    @Test func loadLibraryEntriesPopulatesEntries() async throws {
        let entry = ExerciseLibraryEntryDTO(id: UUID(), name: "Squat", type: .strength)
        let mocked = MockedWorkoutsInteractor(expected: [.fetchLibraryEntries])
        mocked.fetchLibraryEntriesResult = .success([entry])
        let vm = AddExerciseViewModel(sessionID: nil)
        vm.configure(interactor: mocked)
        vm.loadLibraryEntries()

        for _ in 0..<100 where vm.libraryEntries == nil {
            await Task.yield()
        }

        #expect(vm.libraryEntries?.count == 1)
        mocked.verify()
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

        for _ in 0..<100 where vm.saveState.isLoading {
            await Task.yield()
        }

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

        for _ in 0..<100 where vm.saveState.isLoading {
            await Task.yield()
        }

        mocked.verify()
        #expect(vm.saveState.error != nil)
    }
}
