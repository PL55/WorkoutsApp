// WorkoutsApp/Repositories/Database/ModelContainer.swift
import SwiftData

extension ModelContainer {

    static func appModelContainer(
        inMemoryOnly: Bool = false, isStub: Bool = false
    ) throws -> ModelContainer {
        let modelConfig = ModelConfiguration(
            isStub ? "stub" : nil,
            isStoredInMemoryOnly: inMemoryOnly
        )
        if inMemoryOnly {
            // In-memory stores start fresh — no migration needed, and running the
            // migration plan concurrently across parallel test suites causes crashes.
            return try ModelContainer(for: Schema(SchemaV2.models), configurations: modelConfig)
        }
        return try ModelContainer(migrationPlan: AppMigrationPlan.self, configurations: modelConfig)
    }

    static var stub: ModelContainer {
        try! appModelContainer(inMemoryOnly: true, isStub: true)
    }

    var isStub: Bool {
        return configurations.first?.name == "stub"
    }
}

@ModelActor
final actor MainDBRepository { }
