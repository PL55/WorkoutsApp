// WorkoutsApp/UI/ExerciseHistory/ExerciseHistoryView.swift
import SwiftUI

struct ExerciseHistoryView: View {

    let exerciseName: String
    let exerciseType: ExerciseType

    @State private var vm = ExerciseHistoryViewModel()
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    var body: some View {
        content
            .navigationTitle(exerciseName)
            .task {
                vm.configure(interactor: injected.interactors.workouts)
                vm.loadEntries(for: exerciseName)
            }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.entries {
        case .notRequested, .isLoading:
            ProgressView()
        case .loaded(let entries):
            if entries.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Log \(exerciseName) to see your history here")
                )
            } else {
                loadedView(entries)
            }
        case .failed(let error):
            ErrorView(error: error, retryAction: { vm.loadEntries(for: exerciseName) })
        }
    }

    @ViewBuilder
    private func loadedView(_ entries: [ProgressEntry]) -> some View {
        List {
            if Set(entries.map(\.exerciseType)).count > 1 {
                Section {
                    Label(
                        "'\(exerciseName)' has been logged as both strength and cardio — results may be mixed",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            Section("History") {
                ForEach(entries) { entry in
                    NavigationLink(value: ExerciseSnapshotDestination(
                        exerciseName: exerciseName,
                        sessionID: entry.sessionID,
                        exerciseType: entry.exerciseType
                    )) {
                        HStack {
                            Text(entry.date, style: .date)
                                .font(.subheadline)
                            Spacer()
                            Text("\(entry.value, format: .number.precision(.fractionLength(1))) \(entry.label)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
