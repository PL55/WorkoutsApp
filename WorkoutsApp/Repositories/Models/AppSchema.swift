// WorkoutsApp/Repositories/Models/AppSchema.swift
import SwiftData

// Empty namespace — kept for compatibility with any remaining references
enum DBModel { }

extension Schema {
    private static var actualVersion: Schema.Version = Version(1, 0, 0)

    static var appSchema: Schema {
        Schema([
            WorkoutSession.self,
            StrengthExercise.self,
            CardioExercise.self,
            ExerciseLibraryEntry.self
        ], version: actualVersion)
    }
}
