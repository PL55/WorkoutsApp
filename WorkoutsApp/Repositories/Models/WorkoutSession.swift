// WorkoutsApp/Repositories/Models/WorkoutSession.swift
import SwiftData
import Foundation

@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    /// User-visible session name. Defaults to empty; DTO formats date as fallback display.
    var name: String = ""
    /// Stored as raw String for SwiftData predicate compatibility.
    var statusRaw: String = SessionStatus.completed.rawValue
    @Relationship(deleteRule: .cascade) var strengthExercises: [StrengthExercise] = []
    @Relationship(deleteRule: .cascade) var cardioExercises: [CardioExercise] = []

    /// Convenience accessor — not persisted.
    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), date: Date, name: String = "", status: SessionStatus = .completed) {
        self.id = id
        self.date = date
        self.name = name
        self.statusRaw = status.rawValue
    }
}
