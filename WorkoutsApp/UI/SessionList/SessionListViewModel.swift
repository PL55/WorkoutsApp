// WorkoutsApp/UI/SessionList/SessionListViewModel.swift
import Observation
import Foundation

@Observable
@MainActor
final class SessionListViewModel {

    /// Active session (pinned at top of Sessions tab). Nil when no session is in progress.
    private(set) var activeSession: WorkoutSessionDTO?
    /// Completed sessions sorted by date descending.
    private(set) var completedSessions: [WorkoutSessionDTO] = []
    /// Async state for the full sessions load.
    private(set) var sessionsState: Loadable<Void> = .notRequested

    var hasActiveSession: Bool { activeSession != nil }

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    // MARK: - Load

    func loadSessions() {
        let cancelBag = CancelBag()
        sessionsState.setIsLoading(cancelBag: cancelBag)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let all = try await interactor.fetchAllSessions()
                activeSession = all.first { $0.status == .active }
                completedSessions = all
                    .filter { $0.status == .completed }
                    .sorted { $0.date > $1.date }
                sessionsState = .loaded(())
            } catch {
                sessionsState = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }

    // MARK: - Session lifecycle

    func startSession(name: String) {
        let cancelBag = CancelBag()
        sessionsState.setIsLoading(cancelBag: cancelBag)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await interactor.startSession(name: name)
                loadSessions()
            } catch {
                sessionsState = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }

    func endSession(id: UUID) {
        let task = Task { [weak self] in
            guard let self else { return }
            try? await interactor.endSession(id: id)
            loadSessions()
        }
        _ = task
    }

    func cancelSession(id: UUID) {
        let task = Task { [weak self] in
            guard let self else { return }
            try? await interactor.cancelSession(id: id)
            loadSessions()
        }
        _ = task
    }

    func deleteSession(id: UUID) {
        let task = Task { [weak self] in
            guard let self else { return }
            try? await interactor.deleteSession(id: id)
            loadSessions()
        }
        _ = task
    }
}
