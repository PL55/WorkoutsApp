// WorkoutsApp/Interactors/WorkoutsInteractor.swift
import Foundation

// MARK: - Protocol

protocol WorkoutsInteractor {
    // sessionID == nil → creates new session; returns its UUID
    // sessionID != nil → adds to existing session; returns same UUID
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID
    func deleteSession(id: UUID) async throws
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
    func fetchSessions() async throws -> [WorkoutSessionDTO]
    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO
    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO]
}

// MARK: - Real implementation

struct RealWorkoutsInteractor: WorkoutsInteractor {

    let dbRepository: any WorkoutsDBRepository

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

    func fetchSessions() async throws -> [WorkoutSessionDTO] {
        try await dbRepository.fetchSessions()
    }

    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO {
        try await dbRepository.fetchSession(id: id)
    }

    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO] {
        try await dbRepository.fetchLibraryEntries()
    }
}

// MARK: - Stub (for UI tests and previews)

struct StubWorkoutsInteractor: WorkoutsInteractor {
    func addExercise(to sessionID: UUID?, input: ExerciseInput) async throws -> UUID {
        sessionID ?? UUID()
    }
    func deleteSession(id: UUID) async throws {}
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {}
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] { [] }
    func fetchSessions() async throws -> [WorkoutSessionDTO] { [] }
    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO {
        WorkoutSessionDTO(id: id, date: .now, strengthExercises: [], cardioExercises: [])
    }
    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO] { [] }
}
