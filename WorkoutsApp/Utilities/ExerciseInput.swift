// WorkoutsApp/Utilities/ExerciseInput.swift
import Foundation

enum ExerciseInput {
    case strength(name: String, sets: Int, reps: Int, weight: Double)
    case cardio(name: String, durationMinutes: Double)

    var name: String {
        switch self {
        case .strength(let name, _, _, _): return name
        case .cardio(let name, _): return name
        }
    }

    var exerciseType: ExerciseType {
        switch self {
        case .strength: return .strength
        case .cardio: return .cardio
        }
    }
}
