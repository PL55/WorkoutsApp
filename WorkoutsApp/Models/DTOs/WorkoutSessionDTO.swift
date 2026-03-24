// WorkoutsApp/Models/DTOs/WorkoutSessionDTO.swift
import Foundation

struct WorkoutSessionDTO: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let strengthExercises: [StrengthExerciseDTO]
    let cardioExercises: [CardioExerciseDTO]
}
