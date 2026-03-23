// UnitTests/UI/SessionListViewModelTests.swift
import Testing
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct SessionListViewModelTests {

    @Test func groupsSessionsByDay() {
        let vm = SessionListViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let s1 = WorkoutSessionDTO(id: UUID(), date: today, strengthExercises: [], cardioExercises: [])
        let s2 = WorkoutSessionDTO(id: UUID(), date: today.addingTimeInterval(3600), strengthExercises: [], cardioExercises: [])
        let s3 = WorkoutSessionDTO(id: UUID(), date: yesterday, strengthExercises: [], cardioExercises: [])

        vm.sessionsDidChange([s1, s2, s3])

        #expect(vm.groupedSessions.count == 2)
        #expect(vm.groupedSessions[0].key == today)
        #expect(vm.groupedSessions[0].value.count == 2)
        #expect(vm.groupedSessions[1].key == yesterday)
        #expect(vm.groupedSessions[1].value.count == 1)
    }

    @Test func groupsEmptySessionsAsEmpty() {
        let vm = SessionListViewModel()
        vm.sessionsDidChange([])
        #expect(vm.groupedSessions.isEmpty)
    }

    @Test func sortsGroupsMostRecentFirst() {
        let vm = SessionListViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let old = WorkoutSessionDTO(id: UUID(), date: yesterday, strengthExercises: [], cardioExercises: [])
        let new = WorkoutSessionDTO(id: UUID(), date: today, strengthExercises: [], cardioExercises: [])

        vm.sessionsDidChange([old, new])

        #expect(vm.groupedSessions[0].key == today)
        #expect(vm.groupedSessions[1].key == yesterday)
    }

    @Test func deleteSessionCallsInteractor() async throws {
        let sessionID = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [
            .deleteSession(id: sessionID),
            .fetchSessions
        ])
        mocked.fetchSessionsResult = .success([])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        try await vm.deleteSession(id: sessionID)
        // Wait for loadSessions() Task to complete
        for _ in 0..<100 where vm.sessions.isLoading {
            await Task.yield()
        }
        mocked.verify()
    }

    @Test func loadSessionsTransitionsToLoaded() async throws {
        let dto = WorkoutSessionDTO(id: UUID(), date: .now, strengthExercises: [], cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSessions])
        mocked.fetchSessionsResult = .success([dto])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.loadSessions()

        for _ in 0..<100 where vm.sessions.isLoading {
            await Task.yield()
        }

        if case .loaded(let sessions) = vm.sessions {
            #expect(sessions.count == 1)
        } else {
            Issue.record("Expected .loaded, got \(vm.sessions)")
        }
        mocked.verify()
    }

    @Test func loadSessionsTransitionsToFailedOnError() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSessions])
        mocked.fetchSessionsResult = .failure(NSError.test)
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        vm.loadSessions()

        for _ in 0..<100 where vm.sessions.isLoading {
            await Task.yield()
        }

        #expect(vm.sessions.error != nil)
        mocked.verify()
    }
}
