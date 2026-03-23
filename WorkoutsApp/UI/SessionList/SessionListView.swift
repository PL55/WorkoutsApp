// WorkoutsApp/UI/SessionList/SessionListView.swift
import SwiftUI
import Combine

struct SessionListView: View {

    @State private var vm = SessionListViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var routingState: Routing = .init()
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Workouts")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            navigationPath.append(AddExerciseDestination(sessionID: nil))
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .navigationDestination(for: SessionDetailDestination.self) { dest in
                    SessionDetailView(sessionDTO: dest.session, navigationPath: $navigationPath)
                }
                .navigationDestination(for: AddExerciseDestination.self) { dest in
                    AddExerciseView(sessionID: dest.sessionID)
                }
                .navigationDestination(for: ExerciseProgressDestination.self) { dest in
                    ExerciseProgressView(exerciseName: dest.exerciseName)
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
        switch vm.sessions {
        case .notRequested, .isLoading:
            ProgressView()
        case .loaded(let sessions):
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "dumbbell",
                    description: Text("Tap + to log your first workout")
                )
            } else {
                sessionList
            }
        case .failed(let error):
            ErrorView(error: error, retryAction: { vm.loadSessions() })
        }
    }

    private var sessionList: some View {
        List {
            ForEach(vm.groupedSessions, id: \.key) { date, group in
                Section(header: Text(date, style: .date)) {
                    ForEach(group) { session in
                        NavigationLink(value: SessionDetailDestination(session: session)) {
                            SessionCell(session: session)
                        }
                    }
                    .onDelete { indexSet in
                        deleteSession(group: group, offsets: indexSet)
                    }
                }
            }
        }
    }

    private func deleteSession(group: [WorkoutSessionDTO], offsets: IndexSet) {
        for index in offsets {
            let session = group[index]
            Task {
                try? await vm.deleteSession(id: session.id)
            }
        }
    }
}

// MARK: - Routing

extension SessionList {
    struct Routing: Equatable {}
}

typealias SessionList = SessionListView

// MARK: - Navigation Destinations

struct SessionDetailDestination: Hashable {
    let session: WorkoutSessionDTO
}

struct AddExerciseDestination: Hashable {
    let sessionID: UUID?
}

struct ExerciseProgressDestination: Hashable {
    let exerciseName: String
}
