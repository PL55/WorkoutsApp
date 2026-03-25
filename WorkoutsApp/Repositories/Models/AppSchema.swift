// WorkoutsApp/Repositories/Models/AppSchema.swift
import SwiftData

// Empty namespace — kept for compatibility with any remaining references
enum DBModel { }

// MARK: - Schema versions

/// V1 — original schema (no name/status on WorkoutSession)
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [WorkoutSession.self, StrengthExercise.self, CardioExercise.self, ExerciseLibraryEntry.self]
    }
}

/// V2 — adds `name` (String, default "") and `statusRaw` (String, default "completed") to WorkoutSession
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] {
        [WorkoutSession.self, StrengthExercise.self, CardioExercise.self, ExerciseLibraryEntry.self]
    }
}

// MARK: - Migration plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }

    /// Lightweight migration: SwiftData applies Swift-level defaults (`""`, `"completed"`)
    /// to the two new columns for all existing WorkoutSession rows.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
