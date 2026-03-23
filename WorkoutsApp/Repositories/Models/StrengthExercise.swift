// WorkoutsApp/Repositories/Models/StrengthExercise.swift
import SwiftData
import Foundation

@Model
final class StrengthExercise {
    #Index<StrengthExercise>([\.name])

    var id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double
    var exerciseType: ExerciseType = ExerciseType.strength
    @Relationship(inverse: \WorkoutSession.strengthExercises)
    var session: WorkoutSession?

    var analyticsValue: Double { Double(sets * reps) * weight }
    var analyticsLabel: String { "Volume (lbs)" }

    init(id: UUID = UUID(), name: String, sets: Int, reps: Int, weight: Double) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
    }
}

extension StrengthExercise: Exercise, AnalyticsTrackable { }
