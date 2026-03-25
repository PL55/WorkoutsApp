// WorkoutsApp/UI/SessionDetail/SessionDetailView.swift
import SwiftUI

struct SessionDetailView: View {

    @Binding var navigationPath: NavigationPath

    @State private var vm: SessionDetailViewModel
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showCancelConfirmation = false
    @Environment(\.injected) private var injected: DIContainer
    @Environment(\.dismiss) private var dismiss

    let inspection = Inspection<Self>()

    init(sessionID: UUID, navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        _vm = State(initialValue: SessionDetailViewModel(sessionID: sessionID))
        self._navigationPath = navigationPath
    }

    init(sessionID: UUID, navigationPath: Binding<NavigationPath> = .constant(NavigationPath()), viewModel: SessionDetailViewModel) {
        _vm = State(initialValue: viewModel)
        self._navigationPath = navigationPath
    }

    var body: some View {
        content
            .navigationTitle(vm.sessionDisplayName.isEmpty ? "Session" : vm.sessionDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Rename Session", isPresented: $showRenameAlert) {
                TextField("Session name", text: $renameText)
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { vm.renameSession(name: trimmed) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Cancel Session",
                isPresented: $showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel Session", role: .destructive) {
                    Task {
                        try? await vm.cancelSession()
                        navigationPath.removeLast()
                    }
                }
                Button("Keep Session", role: .cancel) {}
            } message: {
                Text("This will permanently delete the session and all its exercises.")
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

            // Active-only actions at the bottom of the list
            if vm.sessionStatus == .active {
                Section {
                    Button("End Session") { vm.endSession() }
                        .frame(maxWidth: .infinity)
                    Button("Cancel Session", role: .destructive) {
                        showCancelConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                navigationPath.append(AddExerciseDestination(sessionID: vm.sessionID))
            } label: {
                Image(systemName: "plus")
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Button("Rename") {
                renameText = vm.sessionDisplayName
                showRenameAlert = true
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
