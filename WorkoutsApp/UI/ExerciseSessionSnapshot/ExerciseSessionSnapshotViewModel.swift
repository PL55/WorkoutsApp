// WorkoutsApp/UI/ExerciseSessionSnapshot/ExerciseSessionSnapshotViewModel.swift
import Observation
import Foundation

@Observable
@MainActor
final class ExerciseSessionSnapshotViewModel {

    private(set) var session: Loadable<WorkoutSessionDTO> = .notRequested

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    func loadSession(id: UUID) {
        let cancelBag = CancelBag()
        session.setIsLoading(cancelBag: cancelBag)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                session = .loaded(try await interactor.fetchSession(id: id))
            } catch {
                session = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }
}
