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

        let s1 = WorkoutSession(id: UUID(), date: today)
        let s2 = WorkoutSession(id: UUID(), date: today.addingTimeInterval(3600))
        let s3 = WorkoutSession(id: UUID(), date: yesterday)

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

        let old = WorkoutSession(id: UUID(), date: yesterday)
        let new = WorkoutSession(id: UUID(), date: today)

        vm.sessionsDidChange([old, new])  // old first intentionally

        #expect(vm.groupedSessions[0].key == today)
        #expect(vm.groupedSessions[1].key == yesterday)
    }

    @Test func deleteSessionCallsInteractor() async throws {
        let sessionID = UUID()
        let mocked = MockedWorkoutsInteractor(expected: [.deleteSession(id: sessionID)])
        let vm = SessionListViewModel()
        vm.configure(interactor: mocked)
        try await vm.deleteSession(id: sessionID)
        mocked.verify()
    }
}
