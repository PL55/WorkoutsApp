// WorkoutsApp/Models/DTOs/ExerciseOverviewDTO.swift
import Foundation

struct ExerciseOverviewDTO: Identifiable {
    let id: String  // exercise name — unique within a given ExerciseType tab
    let name: String
    let exerciseType: ExerciseType
    let bestValue: Double
    let latestValue: Double
    let lastDate: Date
    let analyticsLabel: String
}
