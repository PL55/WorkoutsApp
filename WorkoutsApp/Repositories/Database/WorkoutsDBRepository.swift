// WorkoutsApp/Repositories/Database/WorkoutsDBRepository.swift
import SwiftData
import Foundation

// MARK: - Protocol

protocol WorkoutsDBRepository {
    // Session lifecycle
    func startSession(name: String) async throws -> UUID
    func endSession(id: UUID) async throws
    func cancelSession(id: UUID) async throws
    func renameSession(id: UUID, name: String) async throws
    // Legacy: creates a completed session + first exercise in one call
    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID
    // Exercise mutations
    func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws
    func deleteSession(id: UUID) async throws
    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws
    // Reads — sessions
    func fetchActiveSession() async throws -> WorkoutSessionDTO?
    func fetchAllSessions() async throws -> [WorkoutSessionDTO]         // all statuses (Sessions tab)
    func fetchSessions() async throws -> [WorkoutSessionDTO]            // completed only (Exercises tab)
    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO
    // Reads — exercises / library
    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO]
    func fetchExerciseOverviews(type: ExerciseType) async throws -> [ExerciseOverviewDTO]
    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry]
    func libraryContains(name: String) async throws -> Bool
    func upsertLibraryEntry(name: String, type: ExerciseType) async throws
}

// MARK: - MainDBRepository conformance

extension MainDBRepository: WorkoutsDBRepository {

    // MARK: Session lifecycle

    func startSession(name: String) async throws -> UUID {
        let sessionID = UUID()
        let session = WorkoutSession(id: sessionID, date: .now, name: name, status: .active)
        modelContext.insert(session)
        try modelContext.save()
        return sessionID
    }

    func endSession(id: UUID) async throws {
        let session = try fetchSessionModel(id: id)
        session.status = .completed
        try modelContext.save()
    }

    func cancelSession(id: UUID) async throws {
        let session = try fetchSessionModel(id: id)
        modelContext.delete(session)
        try modelContext.save()
    }

    func renameSession(id: UUID, name: String) async throws {
        let session = try fetchSessionModel(id: id)
        session.name = name
        try modelContext.save()
    }

    // MARK: Legacy

    func saveNewSession(date: Date, with input: ExerciseInput) async throws -> UUID {
        let sessionID = UUID()
        let session = WorkoutSession(id: sessionID, date: date, name: "", status: .completed)
        modelContext.insert(session)
        try insertExercise(input, into: session)
        try modelContext.save()
        return sessionID
    }

    // MARK: Exercise mutations

    func addExercise(_ input: ExerciseInput, to sessionID: UUID) async throws {
        let session = try fetchSessionModel(id: sessionID)
        try insertExercise(input, into: session)
        try modelContext.save()
    }

    func deleteSession(id: UUID) async throws {
        let session = try fetchSessionModel(id: id)
        modelContext.delete(session)
        try modelContext.save()
    }

    func deleteExercise(id: UUID, type: ExerciseType, from sessionID: UUID) async throws {
        let session = try fetchSessionModel(id: sessionID)
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

    // MARK: Session reads

    func fetchActiveSession() async throws -> WorkoutSessionDTO? {
        let activeRaw = SessionStatus.active.rawValue
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == activeRaw }
        )
        return try modelContext.fetch(descriptor).first?.toDTO()
    }

    func fetchAllSessions() async throws -> [WorkoutSessionDTO] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchSessions() async throws -> [WorkoutSessionDTO] {
        let completedRaw = SessionStatus.completed.rawValue
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == completedRaw },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchSession(id: UUID) async throws -> WorkoutSessionDTO {
        try fetchSessionModel(id: id).toDTO()
    }

    // MARK: Library / analytics reads

    func fetchLibraryEntries() async throws -> [ExerciseLibraryEntryDTO] {
        let descriptor = FetchDescriptor<ExerciseLibraryEntry>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchExerciseOverviews(type: ExerciseType) async throws -> [ExerciseOverviewDTO] {
        typealias Row = (name: String, date: Date, value: Double, label: String)
        let completedRaw = SessionStatus.completed.rawValue
        let rows: [Row]
        switch type {
        case .strength:
            rows = try modelContext.fetch(FetchDescriptor<StrengthExercise>()).compactMap { e in
                guard let session = e.session, session.statusRaw == completedRaw else { return nil }
                return (e.name, session.date, e.analyticsValue, e.analyticsLabel)
            }
        case .cardio:
            rows = try modelContext.fetch(FetchDescriptor<CardioExercise>()).compactMap { e in
                guard let session = e.session, session.statusRaw == completedRaw else { return nil }
                return (e.name, session.date, e.analyticsValue, e.analyticsLabel)
            }
        }
        return Dictionary(grouping: rows, by: \.name).compactMap { name, entries -> ExerciseOverviewDTO? in
            guard let latest = entries.max(by: { $0.date < $1.date }),
                  let best   = entries.max(by: { $0.value < $1.value })
            else { return nil }
            return ExerciseOverviewDTO(
                id: name, name: name, exerciseType: type,
                bestValue: best.value, latestValue: latest.value,
                lastDate: latest.date, analyticsLabel: latest.label
            )
        }
    }

    func progressEntries(for exerciseName: String) async throws -> [ProgressEntry] {
        let completedRaw = SessionStatus.completed.rawValue
        let strengthFetch = FetchDescriptor<StrengthExercise>(predicate: #Predicate { $0.name == exerciseName })
        let cardioFetch   = FetchDescriptor<CardioExercise>(predicate: #Predicate { $0.name == exerciseName })
        let strength = try modelContext.fetch(strengthFetch).compactMap { e -> ProgressEntry? in
            guard let session = e.session, session.statusRaw == completedRaw else { return nil }
            return ProgressEntry(id: e.id, sessionID: session.id, date: session.date,
                                 exerciseType: .strength, value: e.analyticsValue, label: e.analyticsLabel)
        }
        let cardio = try modelContext.fetch(cardioFetch).compactMap { e -> ProgressEntry? in
            guard let session = e.session, session.statusRaw == completedRaw else { return nil }
            return ProgressEntry(id: e.id, sessionID: session.id, date: session.date,
                                 exerciseType: .cardio, value: e.analyticsValue, label: e.analyticsLabel)
        }
        let all = strength + cardio
        let deduplicated = Dictionary(grouping: all, by: \.sessionID)
            .compactMap { _, entries in entries.max(by: { $0.value < $1.value }) }
        return deduplicated.sorted { $0.date < $1.date }
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

    // MARK: - Private helpers

    private func fetchSessionModel(id: UUID) throws -> WorkoutSession {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        guard let session = try modelContext.fetch(descriptor).first else { throw SessionNotFoundError() }
        return session
    }

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
            name: name,
            status: status,
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
