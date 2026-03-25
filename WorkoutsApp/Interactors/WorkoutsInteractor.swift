// WorkoutsApp/Interactors/WorkoutsInteractor.swift
import Foundation

// MARK: - Protocol

protocol WorkoutsInteractor {
    // Session lifecycle
    func startSession(name: String) async throws -> UUID
    func endSession(id: UUID) async throws
    func cancelSession(id: UUID) async throws
    func renameSession(id: UUID, name: String) async throws
    // Session reads
    func fetchActiveSession() async throws -> WorkoutSessionDTO?
    func fetchAllSessions() async throws -> [WorkoutSessionDTO]     // all statuses (Sessions tab)
    func fetchSessions() async throws -> [WorkoutSessionDTO]        // completed only (Exercises tab)
    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO
    // Exercise mutations
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID
    func deleteSession(id: UUID) async throws
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    // Analytics / library
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO]
    func fetchExerciseOverviews(type: ExerciseType) async throws -> [ExerciseOverviewDTO]
}

// MARK: - Real implementation

struct RealWorkoutsInteractor: WorkoutsInteractor {

    let dbRepository: any WorkoutsDBRepository

    func startSession(name: String) async throws -> UUID {
        try await dbRepository.startSession(name: name)
    }

    func endSession(id: UUID) async throws {
        try await dbRepository.endSession(id: id)
    }

    func cancelSession(id: UUID) async throws {
        try await dbRepository.cancelSession(id: id)
    }

    func renameSession(id: UUID, name: String) async throws {
        try await dbRepository.renameSession(id: id, name: name)
    }

    func fetchActiveSession() async throws -> WorkoutSessionDTO? {
        try await dbRepository.fetchActiveSession()
    }

    func fetchAllSessions() async throws -> [WorkoutSessionDTO] {
        try await dbRepository.fetchAllSessions()
    }

    func fetchSessions() async throws -> [WorkoutSessionDTO] {
        try await dbRepository.fetchSessions()
    }

    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO {
        try await dbRepository.fetchSession(id: id)
    }

    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID {
        let id: UUID
        if let sessionID {
            try await dbRepository.addExercise(input, to: sessionID)
            id = sessionID
        } else {
            id = try await dbRepository.saveNewSession(date: .now, with: input)
        }
        if try await !dbRepository.libraryContains(name: input.name) {
            try await dbRepository.upsertLibraryEntry(name: input.name, type: input.exerciseType)
        }
        return id
    }

    func deleteSession(id: UUID) async throws {
        try await dbRepository.deleteSession(id: id)
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        try await dbRepository.deleteExercise(id: id, type: type, from: sessionID)
    }

    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] {
        try await dbRepository.progressEntries(for: exerciseName)
    }

    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO] {
        try await dbRepository.fetchLibraryEntries()
    }

    func fetchExerciseOverviews(type: ExerciseType) async throws -> [ExerciseOverviewDTO] {
        try await dbRepository.fetchExerciseOverviews(type: type)
    }
}

// MARK: - Stub (for UI tests and previews)

struct StubWorkoutsInteractor: WorkoutsInteractor {
    func startSession(name: String) async throws -> UUID { UUID() }
    func endSession(id: UUID) async throws {}
    func cancelSession(id: UUID) async throws {}
    func renameSession(id: UUID, name: String) async throws {}
    func fetchActiveSession() async throws -> WorkoutSessionDTO? { nil }
    func fetchAllSessions() async throws -> [WorkoutSessionDTO] { [] }
    func fetchSessions() async throws -> [WorkoutSessionDTO] { [] }
    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO {
        WorkoutSessionDTO(id: id, date: .now, name: "", status: .completed, strengthExercises: [], cardioExercises: [])
    }
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID { sessionID ?? UUID() }
    func deleteSession(id: UUID) async throws {}
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {}
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] { [] }
    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO] { [] }
    func fetchExerciseOverviews(type: ExerciseType) async throws -> [ExerciseOverviewDTO] { [] }
}
