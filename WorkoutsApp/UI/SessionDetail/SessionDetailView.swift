// WorkoutsApp/UI/SessionDetail/SessionDetailView.swift
import SwiftUI

struct SessionDetailView: View {

    let session: WorkoutSession
    @Binding var navigationPath: NavigationPath

    @State private var vm = SessionDetailViewModel()
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    init(session: WorkoutSession, navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.session = session
        self._navigationPath = navigationPath
    }

    var body: some View {
        List {
            ForEach(vm.allExercises, id: \.id) { exercise in
                NavigationLink(value: ExerciseProgressDestination(exerciseName: exercise.name)) {
                    ExerciseRow(exercise: exercise)
                }
            }
            .onDelete { indexSet in
                deleteExercises(offsets: indexSet)
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigationPath.append(AddExerciseDestination(sessionID: session.id))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            vm.configure(interactor: injected.interactors.workouts)
        }
        .onChange(of: session.strengthExercises, initial: true) { _, new in
            vm.updateExercises(strength: new, cardio: session.cardioExercises)
        }
        .onChange(of: session.cardioExercises, initial: true) { _, new in
            vm.updateExercises(strength: session.strengthExercises, cardio: new)
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    private func deleteExercises(offsets: IndexSet) {
        let exercises = vm.allExercises
        for index in offsets {
            let exercise = exercises[index]
            Task {
                try? await vm.deleteExercise(id: exercise.id, type: exercise.exerciseType, from: session.id)
            }
        }
    }
}
