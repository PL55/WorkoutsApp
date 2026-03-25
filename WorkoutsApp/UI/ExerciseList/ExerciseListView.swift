// WorkoutsApp/UI/ExerciseList/ExerciseListView.swift
import SwiftUI
import Combine

struct ExerciseListView: View {

    @State private var vm = ExerciseListViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var selectedType: ExerciseType = .strength
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Exercises")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            vm.sortOrder = nextSortOrder
                        } label: {
                            Label(vm.sortOrder.label, systemImage: "arrow.up.arrow.down")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            navigationPath.append(AddExerciseDestination(sessionID: nil))
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .navigationDestination(for: SessionDetailDestination.self) { dest in
                    SessionDetailView(sessionID: dest.sessionID, navigationPath: $navigationPath)
                }
                .navigationDestination(for: AddExerciseDestination.self) { dest in
                    AddExerciseView(sessionID: dest.sessionID)
                }
                .navigationDestination(for: ExerciseHistoryDestination.self) { dest in
                    ExerciseHistoryView(exerciseName: dest.exerciseName, exerciseType: dest.exerciseType)
                }
                .navigationDestination(for: ExerciseSnapshotDestination.self) { dest in
                    ExerciseSessionSnapshotView(
                        exerciseName: dest.exerciseName,
                        sessionID: dest.sessionID,
                        exerciseType: dest.exerciseType
                    )
                }
        }
        .task {
            vm.configure(interactor: injected.interactors.workouts)
            vm.loadOverviews(type: selectedType)
        }
        .onChange(of: selectedType) {
            vm.loadOverviews(type: selectedType)
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            Picker("Type", selection: $selectedType) {
                Text("Strength").tag(ExerciseType.strength)
                Text("Cardio").tag(ExerciseType.cardio)
            }
            .pickerStyle(.segmented)
            .padding()

            switch vm.overviews {
            case .notRequested, .isLoading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let overviews) where overviews.isEmpty:
                ContentUnavailableView(
                    "No Exercises Yet",
                    systemImage: "dumbbell",
                    description: Text("Tap + to log your first workout")
                )
            case .loaded:
                exerciseList
            case .failed(let error):
                ErrorView(error: error, retryAction: { vm.loadOverviews(type: selectedType) })
            }
        }
    }

    private var exerciseList: some View {
        List {
            ForEach(vm.sortedOverviews) { overview in
                NavigationLink(value: ExerciseHistoryDestination(
                    exerciseName: overview.name,
                    exerciseType: overview.exerciseType
                )) {
                    ExerciseTileView(overview: overview)
                }
            }
        }
    }

    private var nextSortOrder: SortOrder {
        let all = SortOrder.allCases
        let idx = all.firstIndex(of: vm.sortOrder) ?? 0
        return all[(idx + 1) % all.count]
    }
}

// MARK: - Routing

extension ExerciseList {
    struct Routing: Equatable {}
}

typealias ExerciseList = ExerciseListView

// MARK: - Navigation Destinations

struct SessionDetailDestination: Hashable {
    let sessionID: UUID
}

struct AddExerciseDestination: Hashable {
    let sessionID: UUID?
}

struct ExerciseHistoryDestination: Hashable {
    let exerciseName: String
    let exerciseType: ExerciseType
}

struct ExerciseSnapshotDestination: Hashable {
    let exerciseName: String
    let sessionID: UUID
    let exerciseType: ExerciseType
}
