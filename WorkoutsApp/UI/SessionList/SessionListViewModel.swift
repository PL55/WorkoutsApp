// WorkoutsApp/UI/SessionList/SessionListViewModel.swift
import Observation
import Foundation

/// Holds memoized state derived from the session list.
/// Owns session data via Loadable — views no longer use @Query.
@Observable
@MainActor
final class SessionListViewModel {

    /// Async state for session fetching.
    private(set) var sessions: Loadable<[WorkoutSessionDTO]> = .notRequested

    /// Sessions grouped by calendar day, sorted most-recent-first.
    private(set) var groupedSessions: [(key: Date, value: [WorkoutSessionDTO])] = []

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    /// Wire the real interactor. Call from `.task`.
    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    /// Fetch sessions from the interactor. Uses manual Task + Loadable pattern.
    func loadSessions() {
        let cancelBag = CancelBag()
        sessions.setIsLoading(cancelBag: cancelBag)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let fetched = try await interactor.fetchSessions()
                sessions = .loaded(fetched)
                sessionsDidChange(fetched)
            } catch {
                sessions = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }

    /// Regroups and sorts sessions by day. Called after fetch completes.
    func sessionsDidChange(_ sessions: [WorkoutSessionDTO]) {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        groupedSessions = grouped.sorted { $0.key > $1.key }
    }

    func deleteSession(id: UUID) async throws {
        try await interactor.deleteSession(id: id)
        loadSessions()
    }
}
