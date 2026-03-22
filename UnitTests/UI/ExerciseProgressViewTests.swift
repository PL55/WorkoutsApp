// UnitTests/UI/ExerciseProgressViewTests.swift
import Testing
import ViewInspector
import SwiftData
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct ExerciseProgressViewTests {

    @Test func showsLoadingState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = ExerciseProgressView(exerciseName: "Squat", progressState: .isLoading(last: nil, cancelBag: .test))
        let view = sut.inject(container).modelContainer(ModelContainer.mock)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func showsEmptyState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = ExerciseProgressView(exerciseName: "Squat", progressState: .loaded([]))
        let view = sut.inject(container).modelContainer(ModelContainer.mock)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func showsErrorState() async throws {
        let container = DIContainer(interactors: .mocked())
        let sut = ExerciseProgressView(exerciseName: "Squat", progressState: .failed(NSError.test))
        let view = sut.inject(container).modelContainer(ModelContainer.mock)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }

    @Test func showsEntriesWhenLoaded() async throws {
        let entry = ProgressEntry(id: UUID(), date: .now, exerciseType: .strength, value: 1500, label: "Volume (lbs)")
        let container = DIContainer(interactors: .mocked())
        let sut = ExerciseProgressView(exerciseName: "Squat", progressState: .loaded([entry]))
        let view = sut.inject(container).modelContainer(ModelContainer.mock)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { _ in }
        }
    }
}
