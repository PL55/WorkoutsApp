// WorkoutsApp/UI/SessionDetail/SessionDetailViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class SessionDetailViewModel {

    /// Async state for session fetching.
    private(set) var session: Loadable<WorkoutSessionDTO> = .notRequested
    /// All exercises merged, strength first.
    private(set) var allExercises: [any AnalyticsTrackable] = []
    /// The session's display name (custom name or date-formatted fallback).
    private(set) var sessionDisplayName: String = ""
    /// The session's date, for display.
    private(set) var sessionDate: Date?
    /// The session's lifecycle status.
    private(set) var sessionStatus: SessionStatus = .completed

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()
    let sessionID: UUID

    init(sessionID: UUID) {
        self.sessionID = sessionID
    }

    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    // MARK: - Load

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

    func sessionDidChange(_ dto: WorkoutSessionDTO) {
        sessionDate = dto.date
        sessionDisplayName = dto.displayName
        sessionStatus = dto.status
        allExercises = (dto.strengthExercises as [any AnalyticsTrackable])
                     + (dto.cardioExercises as [any AnalyticsTrackable])
    }

    // MARK: - Exercise mutations

    func deleteExercise(id: UUID, type: ExerciseType) async throws {
        try await interactor.deleteExercise(id: id, type: type, from: sessionID)
        loadSession()
    }

    // MARK: - Session lifecycle

    func endSession() {
        let task = Task { [weak self] in
            guard let self else { return }
            try? await interactor.endSession(id: sessionID)
            loadSession()
        }
        _ = task
    }

    func cancelSession() async throws {
        try await interactor.cancelSession(id: sessionID)
    }

    func renameSession(name: String) {
        let task = Task { [weak self] in
            guard let self else { return }
            try? await interactor.renameSession(id: sessionID, name: name)
            loadSession()
        }
        _ = task
    }
}
