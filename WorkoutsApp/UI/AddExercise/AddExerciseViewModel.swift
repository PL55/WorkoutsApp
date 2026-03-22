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

    /// Tracks the save operation. `.loaded(UUID)` means success → view should dismiss.
    var saveState: Loadable<UUID> = .notRequested

    /// Suggestions filtered from the exercise library.
    private(set) var filteredSuggestions: [ExerciseLibraryEntry] = []

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()
    /// Internal (not private) so AddExerciseView can read it for the navigationTitle.
    let sessionID: UUID?

    init(sessionID: UUID?) {
        self.sessionID = sessionID
    }

    /// Wire the real interactor. Call from `.onAppear`.
    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    /// Filter library entries to those matching the current exerciseType and name prefix.
    /// Excludes exact matches (the name the user already typed).
    /// Call from `.onChange(of: vm.name)` and `.onChange(of: vm.exerciseType)`.
    func updateSuggestions(from library: [ExerciseLibraryEntry]) {
        filteredSuggestions = library.filter {
            $0.type == exerciseType
            && $0.name.localizedCaseInsensitiveContains(name)
            && $0.name != name
        }
    }

    /// Build the ExerciseInput and start the async save. Uses manual Task + Loadable
    /// because LoadableSubject.load {} requires a Binding, unavailable in @Observable classes.
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
