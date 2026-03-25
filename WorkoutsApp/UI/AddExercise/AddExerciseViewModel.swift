// WorkoutsApp/UI/AddExercise/AddExerciseViewModel.swift
import Observation
import Foundation

/// Owns form state and the save flow for AddExerciseView.
/// Filters library suggestions only when name or exerciseType changes, not on every render.
@Observable
@MainActor
final class AddExerciseViewModel {

    var exerciseType: ExerciseType = .strength
    var name: String = ""
    var sets: Int = 3
    var reps: Int = 10
    var weight: Double = 0
    var durationMinutes: Double = 0

    /// Tracks the save operation. `.loaded(UUID)` means success -> view should dismiss.
    var saveState: Loadable<UUID> = .notRequested

    /// Library entries fetched from interactor.
    private(set) var libraryEntries: [ExerciseLibraryEntryDTO]?

    /// Suggestions filtered from the exercise library.
    private(set) var filteredSuggestions: [ExerciseLibraryEntryDTO] = []

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()
    /// Internal (not private) so AddExerciseView can read it for the navigationTitle.
    let sessionID: UUID?

    init(sessionID: UUID?) {
        self.sessionID = sessionID
    }

    /// Wire the real interactor. Call from `.task`.
    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    /// Fetch library entries from the interactor.
    func loadLibraryEntries() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let entries = try await interactor.fetchLibraryEntries()
                libraryEntries = entries
                updateSuggestions(from: entries)
            } catch {
                libraryEntries = []
            }
        }
    }

    /// Filter library entries to those matching the current exerciseType and name prefix.
    /// Excludes exact matches (the name the user already typed).
    func updateSuggestions(from library: [ExerciseLibraryEntryDTO]) {
        filteredSuggestions = library.filter {
            $0.type == exerciseType
            && $0.name.localizedCaseInsensitiveContains(name)
            && $0.name != name
        }
    }

    /// Build the ExerciseInput and start the async save.
    func save() {
        let input: ExerciseInput
        switch exerciseType {
        case .strength:
            input = .strength(name: name, sets: sets, reps: reps, weight: weight)
        case .cardio:
            input = .cardio(name: name, durationMinutes: durationMinutes)
        }
        let cancelBag = CancelBag()
        saveState.setIsLoading(cancelBag: cancelBag)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                saveState = .loaded(try await interactor.addExercise(to: sessionID, input: input))
            } catch {
                saveState = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }
}
