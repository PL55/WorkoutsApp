// WorkoutsApp/UI/ExerciseHistory/ExerciseHistoryViewModel.swift
import Observation
import Foundation

@Observable
@MainActor
final class ExerciseHistoryViewModel {

    private(set) var entries: Loadable<[ProgressEntry]> = .notRequested

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    func loadEntries(for exerciseName: String) {
        let cancelBag = CancelBag()
        entries.setIsLoading(cancelBag: cancelBag)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                entries = .loaded(try await interactor.progressEntries(for: exerciseName))
            } catch {
                entries = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }
}
