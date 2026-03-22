// UnitTests/UI/SessionDetailViewTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct SessionDetailViewTests {

    let session: WorkoutSession

    init() {
        session = WorkoutSession(id: UUID(), date: .now)
        let strength = StrengthExercise(id: UUID(), name: "Squat", sets: 3, reps: 5, weight: 100)
        strength.session = session
        session.strengthExercises = [strength]
    }

    @Test func rendersExerciseRows() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = SessionDetailView(session: session)
        try await ViewHosting.host(sut.inject(container)) {
            try await sut.inspection.inspect { view in
                #expect(throws: Never.self) { try view.find(ExerciseRow.self) }
                container.interactors.verify()
            }
        }
    }

    @Test func deleteExerciseCallsInteractor() async throws {
        let strength = session.strengthExercises[0]
        let container = DIContainer(interactors: .mocked(workouts: [
            .deleteExercise(id: strength.id, type: .strength, sessionID: session.id)
        ]))
        let sut = SessionDetailView(session: session)
        try await ViewHosting.host(sut.inject(container)) {
            try await sut.inspection.inspect { view in
                try view.find(ViewType.List.self).forEach(0).callOnDelete(IndexSet([0]))
            }
            try await Task.sleep(for: .milliseconds(100))
            container.interactors.verify()
        }
    }
}
