// WorkoutsApp/Models/DTOs/ExerciseLibraryEntryDTO.swift
import Foundation

struct ExerciseLibraryEntryDTO: Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: ExerciseType
}
