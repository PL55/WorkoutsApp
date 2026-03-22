// WorkoutsApp/Repositories/Models/WorkoutSession.swift
import SwiftData
import Foundation

@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    @Relationship(deleteRule: .cascade) var strengthExercises: [StrengthExercise] = []
    @Relationship(deleteRule: .cascade) var cardioExercises: [CardioExercise] = []

    init(id: UUID = UUID(), date: Date) {
        self.id = id
        self.date = date
    }
}
