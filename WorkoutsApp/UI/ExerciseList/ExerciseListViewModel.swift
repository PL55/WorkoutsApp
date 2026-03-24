// WorkoutsApp/UI/ExerciseList/ExerciseListViewModel.swift
import Observation
import Foundation

enum SortOrder: CaseIterable {
    case alphabetical
    case mostRecent
    case leastRecent

    var label: String {
        switch self {
        case .alphabetical: return "A–Z"
        case .mostRecent:   return "Most Recent"
        case .leastRecent:  return "Least Recent"
        }
    }
}

@Observable
@MainActor
final class ExerciseListViewModel {

    private(set) var overviews: Loadable<[ExerciseOverviewDTO]> = .notRequested
    private(set) var sortedOverviews: [ExerciseOverviewDTO] = []

    var sortOrder: SortOrder = .alphabetical {
        didSet {
            if let loaded = overviews.value {
                sortedOverviews = sorted(loaded)
            }
        }
    }

    private var interactor: any WorkoutsInteractor = StubWorkoutsInteractor()

    func configure(interactor: any WorkoutsInteractor) {
        self.interactor = interactor
    }

    func loadOverviews(type: ExerciseType) {
        let cancelBag = CancelBag()
        overviews.setIsLoading(cancelBag: cancelBag)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let fetched = try await interactor.fetchExerciseOverviews(type: type)
                overviews = .loaded(fetched)
                sortedOverviews = sorted(fetched)
            } catch {
                overviews = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }

    private func sorted(_ overviews: [ExerciseOverviewDTO]) -> [ExerciseOverviewDTO] {
        switch sortOrder {
        case .alphabetical: return overviews.sorted { $0.name < $1.name }
        case .mostRecent:   return overviews.sorted { $0.lastDate > $1.lastDate }
        case .leastRecent:  return overviews.sorted { $0.lastDate < $1.lastDate }
        }
    }
}
