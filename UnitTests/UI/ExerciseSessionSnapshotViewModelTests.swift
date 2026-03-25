// UnitTests/UI/ExerciseSessionSnapshotViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct ExerciseSessionSnapshotViewModelTests {

    @Test func loadSessionTransitionsToLoaded() async throws {
        let sessionID = UUID()
        let dto = WorkoutSessionDTO(id: sessionID, date: .now,
                                    strengthExercises: [StrengthExerciseDTO(id: UUID(), name: "Bench Press", sets: 3, reps: 8, weight: 60)],
                                    cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .success(dto)

        let vm = ExerciseSessionSnapshotViewModel()
        vm.configure(interactor: mocked)
        vm.loadSession(id: sessionID)

        for _ in 0..<100 where vm.session.isLoading { await Task.yield() }

        if case .loaded(let session) = vm.session {
            #expect(session.id == sessionID)
            #expect(session.strengthExercises.count == 1)
        } else {
            Issue.record("Expected .loaded, got \(vm.session)")
        }
        mocked.verify()
    }

    @Test func loadSessionTransitionsToFailedOnError() async throws {
        let sessionID = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .failure(SessionNotFoundError())

        let vm = ExerciseSessionSnapshotViewModel()
        vm.configure(interactor: mocked)
        vm.loadSession(id: sessionID)

        for _ in 0..<100 where vm.session.isLoading { await Task.yield() }

        #expect(vm.session.error != nil)
        mocked.verify()
    }

    @Test func loadedSessionContainsStrengthExerciseByName() async throws {
        let sessionID = UUID()
        let bench = StrengthExerciseDTO(id: UUID(), name: "Bench Press", sets: 4, reps: 6, weight: 80)
        let squat = StrengthExerciseDTO(id: UUID(), name: "Squat", sets: 3, reps: 5, weight: 100)
        let dto = WorkoutSessionDTO(id: sessionID, date: .now,
                                    strengthExercises: [bench, squat],
                                    cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .success(dto)

        let vm = ExerciseSessionSnapshotViewModel()
        vm.configure(interactor: mocked)
        vm.loadSession(id: sessionID)

        for _ in 0..<100 where vm.session.isLoading { await Task.yield() }

        if case .loaded(let session) = vm.session {
            let found = session.strengthExercises.filter { $0.name == "Bench Press" }
            #expect(found.count == 1)
            #expect(found.first?.sets == 4)
        } else {
            Issue.record("Expected .loaded, got \(vm.session)")
        }
        mocked.verify()
    }

    @Test func loadedSessionContainsCardioExerciseByName() async throws {
        let sessionID = UUID()
        let run = CardioExerciseDTO(id: UUID(), name: "Running", durationMinutes: 30)
        let dto = WorkoutSessionDTO(id: sessionID, date: .now,
                                    strengthExercises: [],
                                    cardioExercises: [run])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .success(dto)

        let vm = ExerciseSessionSnapshotViewModel()
        vm.configure(interactor: mocked)
        vm.loadSession(id: sessionID)

        for _ in 0..<100 where vm.session.isLoading { await Task.yield() }

        if case .loaded(let session) = vm.session {
            let found = session.cardioExercises.filter { $0.name == "Running" }
            #expect(found.count == 1)
            #expect(found.first?.durationMinutes == 30)
        } else {
            Issue.record("Expected .loaded, got \(vm.session)")
        }
        mocked.verify()
    }
}
