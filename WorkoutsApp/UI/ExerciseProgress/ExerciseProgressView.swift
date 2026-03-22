// WorkoutsApp/UI/ExerciseProgress/ExerciseProgressView.swift
import SwiftUI

struct ExerciseProgressView: View {

    let exerciseName: String
    @State private(set) var progressState: Loadable<[ProgressEntry]>
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    init(exerciseName: String, progressState: Loadable<[ProgressEntry]> = .notRequested) {
        self.exerciseName = exerciseName
        self._progressState = .init(initialValue: progressState)
    }

    var body: some View {
        content
            .navigationTitle(exerciseName)
            .onAppear {
                if case .notRequested = progressState { loadEntries() }
            }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch progressState {
        case .notRequested, .isLoading:
            ProgressView()
        case .loaded(let entries):
            loadedView(entries)
        case .failed(let error):
            ErrorView(error: error, retryAction: loadEntries)
        }
    }

    @ViewBuilder
    private func loadedView(_ entries: [ProgressEntry]) -> some View {
        if entries.isEmpty {
            ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis", description: Text("Log \(exerciseName) to see your progress here"))
        } else {
            List {
                if Set(entries.map(\.exerciseType)).count > 1 {
                    Section {
                        Label("'\(exerciseName)' has been logged as both strength and cardio — results may be mixed", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Section("History") {
                    ForEach(entries) { entry in
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

    private func loadEntries() {
        $progressState.load {
            try await injected.interactors.workouts.progressEntries(for: exerciseName)
        }
    }
}
