// UnitTests/UI/SessionListTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct SessionListTests {

    @Test func rendersEmptyState() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSessions])
        mocked.fetchSessionsResult = .success([])
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = SessionListView()
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func rendersWithSessions() async throws {
        let dto = WorkoutSessionDTO(id: UUID(), date: .now, strengthExercises: [], cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSessions])
        mocked.fetchSessionsResult = .success([dto])
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = SessionListView()
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }
}
