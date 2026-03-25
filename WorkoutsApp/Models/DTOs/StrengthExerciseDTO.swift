// WorkoutsApp/Models/DTOs/StrengthExerciseDTO.swift
import Foundation

struct StrengthExerciseDTO: Hashable, AnalyticsTrackable {
    let id: UUID
    let name: String
    let sets: Int
    let reps: Int
    let weight: Double

    var exerciseType: ExerciseType { .strength }
    var analyticsValue: Double { Double(sets * reps) * weight }
    var analyticsLabel: String { "Volume (lbs)" }
}
