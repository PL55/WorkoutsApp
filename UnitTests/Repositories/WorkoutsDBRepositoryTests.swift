// UnitTests/Repositories/WorkoutsDBRepositoryTests.swift
import Testing
import SwiftData
import Foundation
@testable import WorkoutsApp

@MainActor
@Suite struct WorkoutsDBRepositoryTests {

    let container: ModelContainer
    let sut: MainDBRepository

    init() throws {
        container = try ModelContainer.appModelContainer(inMemoryOnly: true)
        sut = MainDBRepository(modelContainer: container)
    }

    // MARK: - saveNewSession

    @Test func saveNewSession_returnsSessionID() async throws {
        let input = ExerciseInput.strength(name: "Squat", sets: 3, reps: 5, weight: 100.0)
        let id = try await sut.saveNewSession(date: .now, with: input)
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        let sessions = try container.mainContext.fetch(descriptor)
        #expect(sessions.count == 1)
    }

    @Test func saveNewSession_cascadeDelete() async throws {
        let input = ExerciseInput.strength(name: "Squat", sets: 3, reps: 5, weight: 100.0)
        let id = try await sut.saveNewSession(date: .now, with: input)
        try await sut.deleteSession(id: id)
        let sessions = try container.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        let strength = try container.mainContext.fetch(FetchDescriptor<StrengthExercise>())
        #expect(sessions.isEmpty)
        #expect(strength.isEmpty)
    }

    @Test func addExercise_appendsToSession() async throws {
        let id = try await sut.saveNewSession(date: .now, with: .cardio(name: "Run", durationMinutes: 20))
        try await sut.addExercise(.strength(name: "Bench", sets: 3, reps: 8, weight: 60.0), to: id)
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        let session = try container.mainContext.fetch(descriptor).first!
        #expect(session.strengthExercises.count == 1)
        #expect(session.cardioExercises.count == 1)
    }

    @Test func deleteExercise_removesRecordAndRelationship() async throws {
        let input = ExerciseInput.strength(name: "Deadlift", sets: 1, reps: 5, weight: 140.0)
        let sessionID = try await sut.saveNewSession(date: .now, with: input)
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        let session = try container.mainContext.fetch(descriptor).first!
        let exerciseID = session.strengthExercises.first!.id
        try await sut.deleteExercise(id: exerciseID, type: .strength, from: sessionID)
        let updated = try container.mainContext.fetch(descriptor).first!
        let allStrength = try container.mainContext.fetch(FetchDescriptor<StrengthExercise>())
        #expect(updated.strengthExercises.isEmpty)
        #expect(allStrength.isEmpty)
    }

    @Test func deleteExercise_throwsWhenNotFound() async throws {
        let sessionID = try await sut.saveNewSession(date: .now, with: .cardio(name: "Bike", durationMinutes: 45))
        await #expect(throws: ExerciseNotFoundError.self) {
            try await sut.deleteExercise(id: UUID(), type: .strength, from: sessionID)
        }
    }

    @Test func upsertLibraryEntry_noDuplicates() async throws {
        try await sut.upsertLibraryEntry(name: "Squat", type: .strength)
        try await sut.upsertLibraryEntry(name: "Squat", type: .strength)
        let descriptor = FetchDescriptor<ExerciseLibraryEntry>(predicate: #Predicate { $0.name == "Squat" })
        let entries = try container.mainContext.fetch(descriptor)
        #expect(entries.count == 1)
    }

    @Test func libraryContains_returnsTrueAfterInsert() async throws {
        try await sut.upsertLibraryEntry(name: "Pull-up", type: .strength)
        let result = try await sut.libraryContains(name: "Pull-up")
        #expect(result == true)
    }

    @Test func libraryContains_returnsFalseWhenAbsent() async throws {
        let result = try await sut.libraryContains(name: "NonExistent")
        #expect(result == false)
    }

    @Test func progressEntries_sortedByDateAscending() async throws {
        let older = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        _ = try await sut.saveNewSession(date: .now, with: .strength(name: "Press", sets: 3, reps: 10, weight: 50.0))
        _ = try await sut.saveNewSession(date: older, with: .strength(name: "Press", sets: 3, reps: 8, weight: 45.0))
        let entries = try await sut.progressEntries(for: "Press")
        #expect(entries.count == 2)
        #expect(entries[0].date <= entries[1].date)
    }

    @Test func progressEntries_orphanedExerciseSilentlyDropped() async throws {
        try await sut.upsertLibraryEntry(name: "Test", type: .strength)
        let orphan = StrengthExercise(name: "Test", sets: 1, reps: 1, weight: 1)
        container.mainContext.insert(orphan)
        try container.mainContext.save()
        let entries = try await sut.progressEntries(for: "Test")
        #expect(entries.isEmpty)
    }

    // MARK: - fetchSessions

    @Test func fetchSessions_returnsAllSessionsAsDTO() async throws {
        let input1 = ExerciseInput.strength(name: "Squat", sets: 3, reps: 5, weight: 100.0)
        let input2 = ExerciseInput.cardio(name: "Run", durationMinutes: 30)
        let id1 = try await sut.saveNewSession(date: .now, with: input1)
        let id2 = try await sut.saveNewSession(date: .now, with: input2)
        let sessions = try await sut.fetchSessions()
        #expect(sessions.count == 2)
        let ids = Set(sessions.map(\.id))
        #expect(ids.contains(id1))
        #expect(ids.contains(id2))
    }

    @Test func fetchSessions_sortedByDateDescending() async throws {
        let older = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        _ = try await sut.saveNewSession(date: older, with: .strength(name: "A", sets: 1, reps: 1, weight: 1))
        _ = try await sut.saveNewSession(date: .now, with: .strength(name: "B", sets: 1, reps: 1, weight: 1))
        let sessions = try await sut.fetchSessions()
        #expect(sessions[0].date > sessions[1].date)
    }

    @Test func fetchSession_returnsSingleSessionWithExercises() async throws {
        let id = try await sut.saveNewSession(date: .now, with: .strength(name: "Bench", sets: 3, reps: 8, weight: 60))
        try await sut.addExercise(.cardio(name: "Run", durationMinutes: 20), to: id)
        let session = try await sut.fetchSession(id: id)
        #expect(session.id == id)
        #expect(session.strengthExercises.count == 1)
        #expect(session.cardioExercises.count == 1)
        #expect(session.strengthExercises[0].name == "Bench")
        #expect(session.cardioExercises[0].name == "Run")
    }

    @Test func fetchSession_throwsWhenNotFound() async throws {
        await #expect(throws: SessionNotFoundError.self) {
            try await sut.fetchSession(id: UUID())
        }
    }

    @Test func fetchLibraryEntries_returnsAllEntriesAsDTOs() async throws {
        try await sut.upsertLibraryEntry(name: "Squat", type: .strength)
        try await sut.upsertLibraryEntry(name: "Run", type: .cardio)
        let entries = try await sut.fetchLibraryEntries()
        #expect(entries.count == 2)
        let names = Set(entries.map(\.name))
        #expect(names.contains("Squat"))
        #expect(names.contains("Run"))
    }
}
