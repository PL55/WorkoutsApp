// WorkoutsApp/UI/SessionDetail/SessionDetailView.swift
import SwiftUI

struct SessionDetailView: View {

    let session: WorkoutSession
    @Binding var navigationPath: NavigationPath

    init(session: WorkoutSession, navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.session = session
        self._navigationPath = navigationPath
    }
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    var body: some View {
        List {
            ForEach(allExercises, id: \.id) { exercise in
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
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    private var allExercises: [any AnalyticsTrackable] {
        (session.strengthExercises as [any AnalyticsTrackable]) +
        (session.cardioExercises as [any AnalyticsTrackable])
    }

    private func deleteExercises(offsets: IndexSet) {
        let exercises = allExercises
        for index in offsets {
            let exercise = exercises[index]
            Task {
                try? await injected.interactors.workouts.deleteExercise(
                    id: exercise.id,
                    type: exercise.exerciseType,
                    from: session.id
                )
            }
        }
    }
}
