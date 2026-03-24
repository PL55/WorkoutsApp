// WorkoutsApp/Repositories/Database/WorkoutsDBRepository.swift
import SwiftData
import Foundation

// MARK: - Protocol

protocol WorkoutsDBRepository {
    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID
    func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws
    func deleteSession(id: UUID) async throws
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
    func libraryContains(name: String) async throws -> Bool
    func upsertLibraryEntry(name: String, type: ExerciseType) async throws
    // New read methods — return DTOs, no SwiftData types leak out
    func fetchSessions() async throws -> [WorkoutSessionDTO]
    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO
    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO]
}

// MARK: - MainDBRepository conformance

extension MainDBRepository: WorkoutsDBRepository {

    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID {
        let sessionID = UUID()
        let session = WorkoutSession(id: sessionID, date: date)
        modelContext.insert(session)
        try insertExercise(input, into: session)
        try modelContext.save()
        return sessionID
    }

    func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        guard let session = try modelContext.fetch(descriptor).first else { throw SessionNotFoundError() }
        try insertExercise(input, into: session)
        try modelContext.save()
    }

    func deleteSession(id: UUID) async throws {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        guard let session = try modelContext.fetch(descriptor).first else { throw SessionNotFoundError() }
        modelContext.delete(session)
        try modelContext.save()
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        guard let session = try modelContext.fetch(descriptor).first else { throw SessionNotFoundError() }
        switch type {
        case .strength:
            guard let e = session.strengthExercises.first(where: { $0.id == id })
            else { throw ExerciseNotFoundError() }
            session.strengthExercises.removeAll { $0.id == id }
            modelContext.delete(e)
        case .cardio:
            guard let e = session.cardioExercises.first(where: { $0.id == id })
            else { throw ExerciseNotFoundError() }
            session.cardioExercises.removeAll { $0.id == id }
            modelContext.delete(e)
        }
        try modelContext.save()
    }

    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] {
        let strengthFetch = FetchDescriptor<StrengthExercise>(predicate: #Predicate { $0.name == exerciseName })
        let cardioFetch   = FetchDescriptor<CardioExercise>(predicate: #Predicate { $0.name == exerciseName })
        let strength = try modelContext.fetch(strengthFetch).compactMap { e -> ProgressEntry? in
            guard let date = e.session?.date else { return nil }
            return ProgressEntry(id: e.id, date: date, exerciseType: .strength,
                                 value: e.analyticsValue, label: e.analyticsLabel)
        }
        let cardio = try modelContext.fetch(cardioFetch).compactMap { e -> ProgressEntry? in
            guard let date = e.session?.date else { return nil }
            return ProgressEntry(id: e.id, date: date, exerciseType: .cardio,
                                 value: e.analyticsValue, label: e.analyticsLabel)
        }
        return (strength + cardio).sorted { $0.date < $1.date }
    }

    func libraryContains(name: String) async throws -> Bool {
        let descriptor = FetchDescriptor<ExerciseLibraryEntry>(predicate: #Predicate { $0.name == name })
        return try !modelContext.fetch(descriptor).isEmpty
    }

    func upsertLibraryEntry(name: String, type: ExerciseType) async throws {
        let descriptor = FetchDescriptor<ExerciseLibraryEntry>(predicate: #Predicate { $0.name == name })
        guard try modelContext.fetch(descriptor).isEmpty else { return }
        modelContext.insert(ExerciseLibraryEntry(name: name, type: type))
        try modelContext.save()
    }

    func fetchSessions() async throws -> [WorkoutSessionDTO] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        guard let session = try modelContext.fetch(descriptor).first else {
            throw SessionNotFoundError()
        }
        return session.toDTO()
    }

    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO] {
        let descriptor = FetchDescriptor<ExerciseLibraryEntry>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDTO() }
    }

    // MARK: - Private helpers

    private func insertExercise(_ input: ExerciseInput, into session: WorkoutSession) throws {
        switch input {
        case .strength(let name, let sets, let reps, let weight):
            let e = StrengthExercise(name: name, sets: sets, reps: reps, weight: weight)
            e.session = session
            session.strengthExercises.append(e)
            modelContext.insert(e)
        case .cardio(let name, let durationMinutes):
            let e = CardioExercise(name: name, durationMinutes: durationMinutes)
            e.session = session
            session.cardioExercises.append(e)
            modelContext.insert(e)
        }
    }
}

// MARK: - DTO Mapping

private extension WorkoutSession {
    func toDTO() -> WorkoutSessionDTO {
        WorkoutSessionDTO(
            id: id,
            date: date,
            strengthExercises: strengthExercises.map { $0.toDTO() },
            cardioExercises: cardioExercises.map { $0.toDTO() }
        )
    }
}

private extension StrengthExercise {
    func toDTO() -> StrengthExerciseDTO {
        StrengthExerciseDTO(id: id, name: name, sets: sets, reps: reps, weight: weight)
    }
}

private extension CardioExercise {
    func toDTO() -> CardioExerciseDTO {
        CardioExerciseDTO(id: id, name: name, durationMinutes: durationMinutes)
    }
}

private extension ExerciseLibraryEntry {
    func toDTO() -> ExerciseLibraryEntryDTO {
        ExerciseLibraryEntryDTO(id: id, name: name, type: type)
    }
}
