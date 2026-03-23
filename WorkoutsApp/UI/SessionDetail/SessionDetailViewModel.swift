// WorkoutsApp/UI/SessionDetail/SessionDetailViewModel.swift
import Foundation
import Observation

/// Holds the unified exercise list for a session.
/// Merges strength and cardio arrays only when either changes, not on every render.
@Observable
@MainActor
final class SessionDetailViewModel {

    /// All exercises for the session as `AnalyticsTrackable`, strength first.
    private(set) var allExercises: [any AnalyticsTrackable] = []

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    /// Wire the real interactor. Call from `.onAppear`.
    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    /// Call from `.onChange(of: session.strengthExercises, initial: true)` and
    /// `.onChange(of: session.cardioExercises, initial: true)`.
    func updateExercises(strength: [StrengthExercise], cardio: [CardioExercise]) {
        allExercises = (strength as [any AnalyticsTrackable]) + (cardio as [any AnalyticsTrackable])
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        try await interactor.deleteExercise(id: id, type: type, from: sessionID)
    }
}
