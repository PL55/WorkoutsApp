// WorkoutsApp/Repositories/Models/ProgressEntry.swift
import Foundation

struct ProgressEntry: Identifiable, Equatable {
    let id: UUID
    let sessionID: UUID
    let date: Date
    let exerciseType: ExerciseType
    let value: Double
    let label: String
}
