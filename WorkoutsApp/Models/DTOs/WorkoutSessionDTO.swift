// WorkoutsApp/Models/DTOs/WorkoutSessionDTO.swift
import Foundation

struct WorkoutSessionDTO: Identifiable, Hashable {
    let id: UUID
    let date: Date
    /// User-visible session name. Empty string means no custom name — display layer should use `displayName`.
    let name: String
    let status: SessionStatus
    let strengthExercises: [StrengthExerciseDTO]
    let cardioExercises: [CardioExerciseDTO]

    /// The name to show in the UI. Falls back to a date-formatted string when `name` is empty.
    var displayName: String {
        name.isEmpty ? Self.defaultName(for: date) : name
    }

    static func defaultName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH:mm"
        return formatter.string(from: date)
    }
}
