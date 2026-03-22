// WorkoutsApp/UI/SessionList/SessionListViewModel.swift
import Observation
import Foundation

/// Holds memoized state derived from the session list.
/// Recomputes groupedSessions only when sessions change, not on every render.
@Observable
final class SessionListViewModel {

    /// Sessions grouped by calendar day, sorted most-recent-first.
    private(set) var groupedSessions: [(key: Date, value: [WorkoutSession])] = []

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    /// Wire the real interactor. Call from `.onAppear` so it runs before any user interaction.
    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    /// Called via `.onChange(of: sessions, initial: true)` — regroups and sorts.
    func sessionsDidChange(_ sessions: [WorkoutSession]) {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        groupedSessions = grouped.sorted { $0.key > $1.key }
    }

    func deleteSession(id: UUID) async throws {
        try await interactor.deleteSession(id: id)
    }
}
