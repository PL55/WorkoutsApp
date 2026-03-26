// WorkoutsApp/Repositories/Database/ModelContainer.swift
import SwiftData
import Foundation

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

        return try ModelContainer(for: Schema(SchemaV2.models), configurations: modelConfig)
    }

    static var stub: ModelContainer {
        try! appModelContainer(inMemoryOnly: true, isStub: true)
    }

    var isStub: Bool {
        return configurations.first?.name == "stub"
    }
}

final actor MainDBRepository {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
    }
}
