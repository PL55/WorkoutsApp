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

    private func makeDTO(status: SessionStatus = .completed, name: String = "") -> WorkoutSessionDTO {
        WorkoutSessionDTO(id: sessionID, date: .now, name: name, status: status,
                          strengthExercises: [strength], cardioExercises: [cardio])
    }

    @Test func combinesStrengthAndCardio() {
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.sessionDidChange(makeDTO())
        #expect(vm.allExercises.count == 2)
        let names = vm.allExercises.map(\.name)
        #expect(names.contains("Squat"))
        #expect(names.contains("Run"))
    }

    @Test func strengthExercisesAppearFirst() {
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.sessionDidChange(makeDTO())
        #expect(vm.allExercises[0].name == "Squat")
        #expect(vm.allExercises[1].name == "Run")
    }

    @Test func emptyWhenNoExercises() {
        let vm = SessionDetailViewModel(sessionID: sessionID)
        let dto = WorkoutSessionDTO(id: sessionID, date: .now, name: "", status: .completed,
                                    strengthExercises: [], cardioExercises: [])
        vm.sessionDidChange(dto)
        #expect(vm.allExercises.isEmpty)
    }

    @Test func sessionDidChange_setsStatus() {
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.sessionDidChange(makeDTO(status: .active))
        #expect(vm.sessionStatus == .active)
    }

    @Test func sessionDidChange_setsDisplayName_customName() {
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.sessionDidChange(makeDTO(name: "Leg Day"))
        #expect(vm.sessionDisplayName == "Leg Day")
    }

    @Test func sessionDidChange_setsDisplayName_fallsBackToDate() {
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.sessionDidChange(makeDTO(name: ""))
        #expect(!vm.sessionDisplayName.isEmpty)
    }

    @Test func deleteExerciseCallsInteractorAndReloads() async throws {
        let emptyDTO = WorkoutSessionDTO(id: sessionID, date: .now, name: "", status: .completed,
                                         strengthExercises: [], cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [
            .deleteExercise(id: strength.id, type: .strength, sessionID: sessionID),
            .fetchSession(id: sessionID)
        ])
        mocked.fetchSessionResult = .success(emptyDTO)
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.configure(interactor: mocked)
        try await vm.deleteExercise(id: strength.id, type: .strength)
        for _ in 0..<100 where vm.session.isLoading { await Task.yield() }
        mocked.verify()
    }

    @Test func loadSessionTransitionsToLoaded() async throws {
        let dto = makeDTO()
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .success(dto)
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.configure(interactor: mocked)
        vm.loadSession()
        for _ in 0..<100 where vm.session.isLoading { await Task.yield() }
        if case .loaded(let session) = vm.session {
            #expect(session.strengthExercises.count == 1)
        } else {
            Issue.record("Expected .loaded, got \(vm.session)")
        }
        mocked.verify()
    }

    @Test func endSessionCallsInteractorAndReloads() async throws {
        let dto = makeDTO(status: .completed)
        let mocked = MockedWorkoutsInteractor(expected: [
            .endSession(id: sessionID),
            .fetchSession(id: sessionID)
        ])
        mocked.fetchSessionResult = .success(dto)
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.configure(interactor: mocked)
        vm.endSession()
        for _ in 0..<200 where vm.session.isLoading || vm.session == .notRequested { await Task.yield() }
        mocked.verify()
    }

    @Test func renameSessionCallsInteractorAndReloads() async throws {
        let dto = makeDTO(name: "New Name")
        let mocked = MockedWorkoutsInteractor(expected: [
            .renameSession(id: sessionID, name: "New Name"),
            .fetchSession(id: sessionID)
        ])
        mocked.fetchSessionResult = .success(dto)
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.configure(interactor: mocked)
        vm.renameSession(name: "New Name")
        for _ in 0..<200 where vm.session.isLoading || vm.session == .notRequested { await Task.yield() }
        mocked.verify()
    }

    @Test func cancelSessionCallsInteractor() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.cancelSession(id: sessionID)])
        let vm = SessionDetailViewModel(sessionID: sessionID)
        vm.configure(interactor: mocked)
        try await vm.cancelSession()
        mocked.verify()
    }
}
