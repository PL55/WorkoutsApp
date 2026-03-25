// WorkoutsApp/Models/DTOs/CardioExerciseDTO.swift
import Foundation

struct CardioExerciseDTO: Hashable, AnalyticsTrackable {
    let id: UUID
    let name: String
    let durationMinutes: Double

    var exerciseType: ExerciseType { .cardio }
    var analyticsValue: Double { durationMinutes }
    var analyticsLabel: String { "Duration (min)" }
}
