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

    @Test func deleteSessionCallsInteractor() async throws {
        let modelContainer = ModelContainer.mock
        let repo = MainDBRepository(modelContainer: modelContainer)
        // Save the session first so we know the UUID it was assigned
        let sessionID = try await repo.saveNewSession(
            date: .now,
            with: .strength(name: "Squat", sets: 3, reps: 5, weight: 100)
        )
        let container = DIContainer(interactors: .mocked(workouts: [
            .deleteSession(id: sessionID)
        ]))
        let sut = SessionListView()
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            // Delay 200ms to allow @Query to publish sessions and vm.groupedSessions to populate
            try await sut.inspection.inspect(after: .milliseconds(200)) { view in
                // List > ForEach(groupedSessions) > Section > ForEach(group).onDelete
                try view.find(ViewType.List.self)
                    .forEach(0)   // outer ForEach over groupedSessions
                    .section(0)   // the Section inside
                    .forEach(0)   // inner ForEach over sessions in the group
                    .callOnDelete(IndexSet([0]))
            }
            try await Task.sleep(for: .milliseconds(100))
            container.interactors.verify()
        }
    }
}
