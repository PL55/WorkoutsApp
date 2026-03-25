// WorkoutsApp/UI/SessionDetail/SessionDetailView.swift
import SwiftUI

struct SessionDetailView: View {

    @Binding var navigationPath: NavigationPath

    @State private var vm: SessionDetailViewModel
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    /// Production init — creates a fresh VM for the given session ID.
    init(sessionID: UUID, navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        _vm = State(initialValue: SessionDetailViewModel(sessionID: sessionID))
        self._navigationPath = navigationPath
    }

    /// Testing init — allows injecting a pre-configured VM.
    init(sessionID: UUID, navigationPath: Binding<NavigationPath> = .constant(NavigationPath()), viewModel: SessionDetailViewModel) {
        _vm = State(initialValue: viewModel)
        self._navigationPath = navigationPath
    }

    var body: some View {
        content
            .navigationTitle(vm.sessionDate?.formatted(date: .abbreviated, time: .omitted) ?? "Session")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        navigationPath.append(AddExerciseDestination(sessionID: vm.sessionID))
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                vm.configure(interactor: injected.interactors.workouts)
                vm.loadSession()
            }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.session {
        case .notRequested, .isLoading:
            ProgressView()
        case .loaded:
            exerciseList
        case .failed(let error):
            ErrorView(error: error, retryAction: { vm.loadSession() })
        }
    }

    private var exerciseList: some View {
        List {
            ForEach(vm.allExercises, id: \.id) { exercise in
                NavigationLink(value: ExerciseHistoryDestination(
                    exerciseName: exercise.name,
                    exerciseType: exercise.exerciseType
                )) {
                    ExerciseRow(exercise: exercise)
                }
            }
            .onDelete { indexSet in
                deleteExercises(offsets: indexSet)
            }
        }
    }

    private func deleteExercises(offsets: IndexSet) {
        let exercises = vm.allExercises
        for index in offsets {
            let exercise = exercises[index]
            Task {
                try? await vm.deleteExercise(id: exercise.id, type: exercise.exerciseType)
            }
        }
    }
}
