// UnitTests/UI/AddExerciseViewTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct AddExerciseViewTests {

    @Test func showsStrengthFieldsByDefault() async throws {
        let mocked = MockedWorkoutsInteractor(expected: [.fetchLibraryEntries])
        mocked.fetchLibraryEntriesResult = .success([])
        let container = DIContainer(interactors: .init(workouts: mocked))
        let sut = AddExerciseView(sessionID: nil)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func showsLoadingStateWhenSaving() async throws {
        let container = DIContainer(interactors: .mocked())
        let vm = AddExerciseViewModel(sessionID: nil)
        vm.saveState = .isLoading(last: nil, cancelBag: .test)
        let sut = AddExerciseView(sessionID: nil, viewModel: vm)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }

    @Test func showsErrorState() async throws {
        let container = DIContainer(interactors: .mocked())
        let vm = AddExerciseViewModel(sessionID: nil)
        vm.saveState = .failed(NSError.test)
        let sut = AddExerciseView(sessionID: nil, viewModel: vm)
        let view = sut.inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { view in
                #expect(container.appState.value == AppState())
            }
        }
    }
}
