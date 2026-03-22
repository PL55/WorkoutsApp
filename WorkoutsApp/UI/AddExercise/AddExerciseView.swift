// WorkoutsApp/UI/AddExercise/AddExerciseView.swift
import SwiftUI
import SwiftData

struct AddExerciseView: View {

    let sessionID: UUID?

    @State private(set) var saveState: Loadable<UUID>
    @State private var exerciseType: ExerciseType = .strength
    @State private var name: String = ""
    @State private var sets: Int = 3
    @State private var reps: Int = 10
    @State private var weight: Double = 0
    @State private var durationMinutes: Double = 0

    @Query(sort: \ExerciseLibraryEntry.name)
    private var libraryEntries: [ExerciseLibraryEntry]

    @Environment(\.injected) private var injected: DIContainer
    @Environment(\.dismiss) private var dismiss

    let inspection = Inspection<Self>()

    init(sessionID: UUID?, saveState: Loadable<UUID> = .notRequested) {
        self.sessionID = sessionID
        self._saveState = .init(initialValue: saveState)
    }

    var body: some View {
        content
            .navigationTitle(sessionID == nil ? "New Workout" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || saveState.isLoading)
                }
            }
            .onChange(of: saveState) { _, new in
                if case .loaded = new { dismiss() }
            }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch saveState {
        case .isLoading:
            ProgressView()
        case .failed(let error):
            ErrorView(error: error, retryAction: save)
        default:
            form
        }
    }

    private var form: some View {
        Form {
            Section("Exercise Type") {
                Picker("Type", selection: $exerciseType) {
                    ForEach(ExerciseType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Exercise Name") {
                TextField("e.g. Bench Press", text: $name)
                    .autocorrectionDisabled()
                let suggestions = libraryEntries.filter {
                    $0.type == exerciseType && $0.name.localizedCaseInsensitiveContains(name) && $0.name != name
                }
                ForEach(suggestions) { entry in
                    Button(entry.name) { name = entry.name }
                        .foregroundStyle(.secondary)
                }
            }

            if exerciseType == .strength {
                Section("Strength Details") {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                    Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                    HStack {
                        Text("Weight (lbs)")
                        Spacer()
                        TextField("0", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            } else {
                Section("Cardio Details") {
                    HStack {
                        Text("Duration (min)")
                        Spacer()
                        TextField("0", value: $durationMinutes, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
        }
    }

    private func save() {
        let input: ExerciseInput
        switch exerciseType {
        case .strength:
            input = .strength(name: name, sets: sets, reps: reps, weight: weight)
        case .cardio:
            input = .cardio(name: name, durationMinutes: durationMinutes)
        }
        $saveState.load {
            try await injected.interactors.workouts.addExercise(to: sessionID, input: input)
        }
    }
}
