// WorkoutsApp/UI/ExerciseSessionSnapshot/ExerciseSessionSnapshotView.swift
import SwiftUI

struct ExerciseSessionSnapshotView: View {

    let exerciseName: String
    let sessionID: UUID
    let exerciseType: ExerciseType

    @State private var vm = ExerciseSessionSnapshotViewModel()
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    var body: some View {
        content
            .navigationTitle(exerciseName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: SessionDetailDestination(sessionID: sessionID)) {
                        Text("View Full Session")
                    }
                }
            }
            .task {
                vm.configure(interactor: injected.interactors.workouts)
                vm.loadSession(id: sessionID)
            }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.session {
        case .notRequested, .isLoading:
            ProgressView()
        case .loaded(let session):
            loadedView(session)
        case .failed(let error):
            ErrorView(error: error, retryAction: { vm.loadSession(id: sessionID) })
        }
    }

    @ViewBuilder
    private func loadedView(_ session: WorkoutSessionDTO) -> some View {
        List {
            Section(session.date.formatted(date: .abbreviated, time: .omitted)) {
                switch exerciseType {
                case .strength:
                    let exercises = session.strengthExercises.filter { $0.name == exerciseName }
                    if exercises.isEmpty {
                        Text("No data found").foregroundStyle(.secondary)
                    } else {
                        ForEach(exercises) { e in
                            HStack {
                                Text("\(e.sets) sets × \(e.reps) reps")
                                Spacer()
                                Text("\(e.weight, format: .number.precision(.fractionLength(1))) lbs")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                case .cardio:
                    let exercises = session.cardioExercises.filter { $0.name == exerciseName }
                    if exercises.isEmpty {
                        Text("No data found").foregroundStyle(.secondary)
                    } else {
                        ForEach(exercises) { e in
                            HStack {
                                Text("Duration")
                                Spacer()
                                Text("\(e.durationMinutes, format: .number.precision(.fractionLength(1))) min")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
