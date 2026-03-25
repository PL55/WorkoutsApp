// WorkoutsApp/UI/SessionDetail/SessionDetailViewModel.swift
import Foundation
import Observation

/// Holds session detail data fetched via interactor.
/// Merges strength and cardio arrays only when session data changes.
@Observable
@MainActor
final class SessionDetailViewModel {

    /// Async state for session fetching.
    private(set) var session: Loadable<WorkoutSessionDTO> = .notRequested

    /// All exercises for the session as `AnalyticsTrackable`, strength first.
    private(set) var allExercises: [any AnalyticsTrackable] = []

    /// The session's date, for the navigation title.
    private(set) var sessionDate: Date?

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()
    let sessionID: UUID

    init(sessionID: UUID) {
        self.sessionID = sessionID
    }

    /// Wire the real interactor. Call from `.task`.
    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    /// Fetch session from the interactor.
    func loadSession() {
        let cancelBag = CancelBag()
        session.setIsLoading(cancelBag: cancelBag)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let fetched = try await interactor.fetchSession(id: sessionID)
                session = .loaded(fetched)
                sessionDidChange(fetched)
            } catch {
                session = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }

    /// Update derived state from a fetched session DTO.
    func sessionDidChange(_ dto: WorkoutSessionDTO) {
        sessionDate = dto.date
        allExercises = (dto.strengthExercises as [any AnalyticsTrackable])
                     + (dto.cardioExercises as [any AnalyticsTrackable])
    }

    func deleteExercise(id: UUID, type: ExerciseType) async throws {
        try await interactor.deleteExercise(id: id, type: type, from: sessionID)
        loadSession()
    }
}
