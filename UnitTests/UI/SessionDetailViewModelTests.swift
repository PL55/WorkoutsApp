// UnitTests/UI/SessionDetailViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct SessionDetailViewModelTests {

    let sessionID: UUID
    let strength: StrengthExerciseDTO
    let cardio: CardioExerciseDTO

    init() {
        sessionID = UUID()
        strength = StrengthExerciseDTO(id: UUID(), name: "Squat", sets: 3, reps: 5, weight: 100)
        cardio = CardioExerciseDTO(id: UUID(), name: "Run", durationMinutes: 30)
    }

    @Test func combinesStrengthAndCardio() {
        let vm = SessionDetailViewModel(sessionID: sessionID)
        let dto = WorkoutSessionDTO(id: sessionID, date: .now,
                                     strengthExercises: [strength], cardioExercises: [cardio])
        vm.sessionDidChange(dto)
        #expect(vm.allExercises.count == 2)
        let names = vm.allExercises.map(\.name)
        #expect(names.contains("Squat"))
        #expect(names.contains("Run"))
    }

    @Test func strengthExercisesAppearFirst() {
        let vm = SessionDetailViewModel(sessionID: sessionID)
        let dto = WorkoutSessionDTO(id: sessionID, date: .now,
                                     strengthExercises: [strength], cardioExercises: [cardio])
        vm.sessionDidChange(dto)
        #expect(vm.allExercises[0].name == "Squat")
        #expect(vm.allExercises[1].name == "Run")
    }

    @Test func emptyWhenNoExercises() {
        let vm = SessionDetailViewModel(sessionID: sessionID)
        let dto = WorkoutSessionDTO(id: sessionID, date: .now,
                                     strengthExercises: [], cardioExercises: [])
        vm.sessionDidChange(dto)
        #expect(vm.allExercises.isEmpty)
    }

    @Test func deleteExerciseCallsInteractorAndReloads() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [
            .deleteExercise(id: strength.id, type: .strength, sessionID: sessionID),
            .fetchSession(id: sessionID)
        ])
        let dto = WorkoutSessionDTO(id: sessionID, date: .now,
                                     strengthExercises: [], cardioExercises: [])
        mocked.fetchSessionResult = .success(dto)
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.configure(interactor: mocked)
        try await vm.deleteExercise(id: strength.id, type: .strength)
        // Wait for loadSession() Task to complete
        for _ in 0..<100 where vm.session.isLoading {
            await Task.yield()
        }
        mocked.verify()
    }

    @Test func loadSessionTransitionsToLoaded() async throws {
        let dto = WorkoutSessionDTO(id: sessionID, date: .now,
                                     strengthExercises: [strength], cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .success(dto)
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.configure(interactor: mocked)
        vm.loadSession()

        for _ in 0..<100 where vm.session.isLoading {
            await Task.yield()
        }

        if case .loaded(let session) = vm.session {
            #expect(session.strengthExercises.count == 1)
        } else {
            Issue.record("Expected .loaded, got \(vm.session)")
        }
        mocked.verify()
    }
}
