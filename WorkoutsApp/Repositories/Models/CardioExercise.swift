// WorkoutsApp/Repositories/Models/CardioExercise.swift
import SwiftData
import Foundation

@Model
final class CardioExercise {
    #Index<CardioExercise>([\.name])

    var id: UUID
    var name: String
    var durationMinutes: Double
    var exerciseType: ExerciseType = ExerciseType.cardio
    @Relationship(inverse: \WorkoutSession.cardioExercises)
    var session: WorkoutSession?

    var analyticsValue: Double { durationMinutes }
    var analyticsLabel: String { "Duration (min)" }

    init(id: UUID = UUID(), name: String, durationMinutes: Double) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
    }
}

extension CardioExercise: Exercise, AnalyticsTrackable { }
