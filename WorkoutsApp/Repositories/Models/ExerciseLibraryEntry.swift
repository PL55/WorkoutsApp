// WorkoutsApp/Repositories/Models/ExerciseLibraryEntry.swift
import SwiftData
import Foundation

@Model
final class ExerciseLibraryEntry {
    @Attribute(.unique) var name: String
    var id: UUID
    var type: ExerciseType

    init(id: UUID = UUID(), name: String, type: ExerciseType) {
        self.id = id
        self.name = name
        self.type = type
    }
}
