// UnitTests/UI/SessionListViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct SessionListViewModelTests {

    private func makeSession(id: UUID = UUID(), status: SessionStatus, name: String = "") -> WorkoutSessionDTO {
        WorkoutSessionDTO(id: id, date: .now, name: name, status: status,
                          strengthExercises: [], cardioExercises: [])
    }

    // MARK: - loadSessions

    @Test func loadSessions_splitsActiveAndCompleted() async throws {
        let active = makeSession(status: .active, name: "Today")
        let c1 = makeSession(status: .completed)
        let c2 = makeSession(status: .completed)
        let mocked = MockedWorkoutsInteractor(expected: [.fetchAllSessions])
        mocked.fetchAllSessionsResult = .success([active, c1, c2])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.loadSessions()
        for _ in 0..<100 where vm.sessionsState.isLoading { await Task.yield() }
        #expect(vm.activeSession?.id == active.id)
        #expect(vm.completedSessions.count == 2)
        mocked.verify()
    }

    @Test func loadSessions_noActiveSession() async throws {
        let c1 = makeSession(status: .completed)
        let mocked = MockedWorkoutsInteractor(expected: [.fetchAllSessions])
        mocked.fetchAllSessionsResult = .success([c1])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.loadSessions()
        for _ in 0..<100 where vm.sessionsState.isLoading { await Task.yield() }
        #expect(vm.activeSession == nil)
        #expect(vm.completedSessions.count == 1)
        mocked.verify()
    }

    @Test func hasActiveSession_trueWhenActive() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.fetchAllSessions])
        mocked.fetchAllSessionsResult = .success([makeSession(status: .active)])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.loadSessions()
        for _ in 0..<100 where vm.sessionsState.isLoading { await Task.yield() }
        #expect(vm.hasActiveSession == true)
        mocked.verify()
    }

    @Test func hasActiveSession_falseWhenNone() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.fetchAllSessions])
        mocked.fetchAllSessionsResult = .success([])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.loadSessions()
        for _ in 0..<100 where vm.sessionsState.isLoading { await Task.yield() }
        #expect(vm.hasActiveSession == false)
        mocked.verify()
    }

    // MARK: - completedSessions ordering

    @Test func completedSessions_sortedByDateDescending() async throws {
        let older = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let newer = Date.now
        let c1 = WorkoutSessionDTO(id: UUID(), date: older, name: "", status: .completed,
                                   strengthExercises: [], cardioExercises: [])
        let c2 = WorkoutSessionDTO(id: UUID(), date: newer, name: "", status: .completed,
                                   strengthExercises: [], cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchAllSessions])
        mocked.fetchAllSessionsResult = .success([c1, c2])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.loadSessions()
        for _ in 0..<100 where vm.sessionsState.isLoading { await Task.yield() }
        #expect(vm.completedSessions[0].date >= vm.completedSessions[1].date)
        mocked.verify()
    }

    // MARK: - startSession

    @Test func startSession_callsInteractorAndReloads() async throws {
        let newID = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [
            .startSession(name: "Push Day"),
            .fetchAllSessions
        ])
        mocked.startSessionResult = .success(newID)
        mocked.fetchAllSessionsResult = .success([])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.startSession(name: "Push Day")
        for _ in 0..<200 where vm.sessionsState.isLoading { await Task.yield() }
        mocked.verify()
    }

    // MARK: - endSession

    @Test func endSession_callsInteractorAndReloads() async throws {
        let id = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [
            .endSession(id: id),
            .fetchAllSessions
        ])
        mocked.fetchAllSessionsResult = .success([])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.endSession(id: id)
        for _ in 0..<200 {
            if mocked.actions.factual.count >= 2 { break }
            await Task.yield()
        }
        mocked.verify()
    }

    // MARK: - cancelSession

    @Test func cancelSession_callsInteractorAndReloads() async throws {
        let id = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [
            .cancelSession(id: id),
            .fetchAllSessions
        ])
        mocked.fetchAllSessionsResult = .success([])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.cancelSession(id: id)
        for _ in 0..<200 {
            if mocked.actions.factual.count >= 2 { break }
            await Task.yield()
        }
        mocked.verify()
    }
}
