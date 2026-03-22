// UnitTests/UI/SessionListTests.swift
import Testing
import ViewInspector
import SwiftData
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct SessionListTests {

    @Test func rendersEmptyState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = SessionListView()
        let modelContainer = ModelContainer.mock
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func rendersWithSessions() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = SessionListView()
        let modelContainer = ModelContainer.mock
        let repo = MainDBRepository(modelContainer: modelContainer)
        _ = try await repo.saveNewSession(date: .now, with: .strength(name: "Squat", sets: 3, reps: 5, weight: 100))
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }
}
