// WorkoutsApp/UI/SessionList/SessionListView.swift
import SwiftUI

struct SessionListView: View {

    @State private var vm = SessionListViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var showNewSession = false
    @State private var showActiveSessionAlert = false
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Sessions")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            if vm.hasActiveSession {
                                showActiveSessionAlert = true
                            } else {
                                showNewSession = true
                            }
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
                .sheet(isPresented: $showNewSession) {
                    NewSessionView(defaultName: WorkoutSessionDTO.defaultName(for: .now)) { name in
                        vm.startSession(name: name)
                    }
                }
                .alert("Active Session", isPresented: $showActiveSessionAlert) {
                    activeSessionAlertButtons
                } message: {
                    if let active = vm.activeSession {
                        Text("You have an active session: \"\(active.displayName)\". End it or cancel it before starting a new one.")
                    }
                }
        }
        .task {
            vm.configure(interactor: injected.interactors.workouts)
            vm.loadSessions()
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.sessionsState {
        case .notRequested, .isLoading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error):
            ErrorView(error: error, retryAction: vm.loadSessions)
        case .loaded:
            sessionsList
        }
    }

    private var sessionsList: some View {
        List {
            // Active session pinned at top
            if let active = vm.activeSession {
                Section("Active") {
                    NavigationLink(value: SessionDetailDestination(sessionID: active.id)) {
                        SessionCell(session: active)
                    }
                    .listRowBackground(Color.accentColor.opacity(0.08))
                    .overlay(alignment: .trailing) {
                        Text("ACTIVE")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                            .padding(.trailing, 36)
                    }
                }
            }

            // Completed sessions
            if vm.completedSessions.isEmpty && vm.activeSession == nil {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Tap + to start your first session")
                )
                .listRowSeparator(.hidden)
            } else if !vm.completedSessions.isEmpty {
                Section("Completed") {
                    ForEach(vm.completedSessions) { session in
                        NavigationLink(value: SessionDetailDestination(sessionID: session.id)) {
                            SessionCell(session: session)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            vm.deleteSession(id: vm.completedSessions[index].id)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var activeSessionAlertButtons: some View {
        if let active = vm.activeSession {
            Button("End Session") { vm.endSession(id: active.id) }
            Button("Cancel Session", role: .destructive) { vm.cancelSession(id: active.id) }
            Button("Dismiss", role: .cancel) {}
        }
    }
}
