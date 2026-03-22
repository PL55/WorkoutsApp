// UnitTests/UI/SessionDetailViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct SessionDetailViewModelTests {

    let session: WorkoutSession
    let strength: StrengthExercise
    let cardio: CardioExercise

    init() {
        session = WorkoutSession(id: UUID(), date: .now)
        // Do NOT set @Relationship properties (strengthExercises/cardioExercises) on the
        // session outside a ModelContext — SwiftData relationships require a backing store.
        // The VM receives plain arrays via updateExercises(strength:cardio:), so we only
        // need the model objects themselves, not wired into the session graph.
        strength = StrengthExercise(id: UUID(), name: "Squat", sets: 3, reps: 5, weight: 100)
        cardio = CardioExercise(id: UUID(), name: "Run", durationMinutes: 30)
    }

    @Test func combinesStrengthAndCardio() {
        let vm = SessionDetailViewModel()
        vm.updateExercises(strength: [strength], cardio: [cardio])
        #expect(vm.allExercises.count == 2)
        let names = vm.allExercises.map(\.name)
        #expect(names.contains("Squat"))
        #expect(names.contains("Run"))
    }

    @Test func strengthExercisesAppearFirst() {
        let vm = SessionDetailViewModel()
        vm.updateExercises(strength: [strength], cardio: [cardio])
        #expect(vm.allExercises[0].name == "Squat")
        #expect(vm.allExercises[1].name == "Run")
    }

    @Test func emptyWhenNoExercises() {
        let vm = SessionDetailViewModel()
        vm.updateExercises(strength: [], cardio: [])
        #expect(vm.allExercises.isEmpty)
    }

    @Test func deleteExerciseCallsInteractor() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [
            .deleteExercise(id: strength.id, type: .strength, sessionID: session.id)
        ])
        let vm = SessionDetailViewModel()
        vm.configure(interactor: mocked)
        try await vm.deleteExercise(id: strength.id, type: .strength, from: session.id)
        mocked.verify()
    }
}
