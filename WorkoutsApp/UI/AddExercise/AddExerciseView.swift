// WorkoutsApp/UI/AddExercise/AddExerciseView.swift
import SwiftUI

struct AddExerciseView: View {

    @State private var vm: AddExerciseViewModel

    @Environment(\.injected) private var injected: DIContainer
    @Environment(\.dismiss) private var dismiss

    let inspection = Inspection<Self>()

    /// Production init — creates a fresh VM for the given session.
    init(sessionID: UUID?) {
        _vm = State(initialValue: AddExerciseViewModel(sessionID: sessionID))
    }

    /// Testing init — allows injecting a pre-configured VM.
    init(sessionID: UUID?, viewModel: AddExerciseViewModel) {
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(vm.sessionID == nil ? "New Workout" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.save() }
                        .disabled(vm.name.isEmpty || vm.saveState.isLoading)
                }
            }
            .onChange(of: vm.saveState) { _, new in
                if case .loaded = new { dismiss() }
            }
            .onChange(of: vm.name) { _, _ in
                if let entries = vm.libraryEntries {
                    vm.updateSuggestions(from: entries)
                }
            }
            .onChange(of: vm.exerciseType) { _, _ in
                if let entries = vm.libraryEntries {
                    vm.updateSuggestions(from: entries)
                }
            }
            .task {
                vm.configure(interactor: injected.interactors.workouts)
                vm.loadLibraryEntries()
            }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.saveState {
        case .isLoading:
            ProgressView()
        case .failed(let error):
            ErrorView(error: error, retryAction: vm.save)
        default:
            form
        }
    }

    private var form: some View {
        Form {
            Section("Exercise Type") {
                Picker("Type", selection: $vm.exerciseType) {
                    ForEach(ExerciseType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Exercise Name") {
                TextField("e.g. Bench Press", text: $vm.name)
                    .autocorrectionDisabled()
                ForEach(vm.filteredSuggestions) { entry in
                    Button(entry.name) { vm.name = entry.name }
                        .foregroundStyle(.secondary)
                }
            }

            if vm.exerciseType == .strength {
                Section("Strength Details") {
                    Stepper("Sets: \(vm.sets)", value: $vm.sets, in: 1...20)
                    Stepper("Reps: \(vm.reps)", value: $vm.reps, in: 1...100)
                    HStack {
                        Text("Weight (lbs)")
                        Spacer()
                        TextField("0", value: $vm.weight, format: .number)
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
                        TextField("0", value: $vm.durationMinutes, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
        }
    }
}
