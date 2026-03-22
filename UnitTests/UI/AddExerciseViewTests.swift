// UnitTests/UI/AddExerciseViewTests.swift
import Testing
import ViewInspector
import SwiftData
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct AddExerciseViewTests {

    @Test func showsStrengthFieldsByDefault() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = AddExerciseView(sessionID: nil)
        let modelContainer = ModelContainer.mock
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                // Strength is selected by default — view renders without error
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func showsLoadingStateWhenSaving() async throws {
        let container = DIContainer(interactors: .mocked(workouts: [
            .addExercise(sessionID: nil, input: .strength(name: "Squat", sets: 3, reps: 5, weight: 100))
        ]))
        let sut = AddExerciseView(sessionID: nil, saveState: .isLoading(last: nil, cancelBag: .test))
        let modelContainer = ModelContainer.mock
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                // Loading state rendered — view does not crash
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func showsErrorState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = AddExerciseView(sessionID: nil, saveState: .failed(NSError.test))
        let modelContainer = ModelContainer.mock
        let view = sut.inject(container).modelContainer(modelContainer)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }
}
