// UnitTests/UI/SessionDetailViewTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct SessionDetailViewTests {

    let sessionID: UUID
    let strengthDTO: StrengthExerciseDTO

    init() {
        sessionID = UUID()
        strengthDTO = StrengthExerciseDTO(id: UUID(), name: "Squat", sets: 3, reps: 5, weight: 100)
    }

    @Test func rendersExerciseRows() async throws {
        let dto = WorkoutSessionDTO(id: sessionID, date: .now,
                                     strengthExercises: [strengthDTO], cardioExercises: [])
        let mocked = MockedWorkoutsInteractor(expected: [.fetchSession(id: sessionID)])
        mocked.fetchSessionResult = .success(dto)
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = SessionDetailView(sessionID: sessionID)
        try await ViewHosting.host(sut.inject(container)) {
            try await sut.inspection.inspect(after: .milliseconds(200)) { view in
                #expect(throws: Never.self) { try view.find(ExerciseRow.self) }
                mocked.verify()
            }
        }
    }
}
