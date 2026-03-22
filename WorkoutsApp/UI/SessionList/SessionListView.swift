// WorkoutsApp/UI/SessionList/SessionListView.swift
import SwiftUI
import SwiftData
import Combine

struct SessionListView: View {

    @Query(sort: \WorkoutSession.date, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var navigationPath = NavigationPath()
    @State private var routingState: Routing = .init()
    @Environment(\.injected) private var injected: DIContainer

    let inspection = Inspection<Self>()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView("No Workouts Yet", systemImage: "dumbbell", description: Text("Tap + to log your first workout"))
                } else {
                    sessionList
                }
            }
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
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session, navigationPath: $navigationPath)
            }
            .navigationDestination(for: AddExerciseDestination.self) { dest in
                AddExerciseView(sessionID: dest.sessionID)
            }
            .navigationDestination(for: ExerciseProgressDestination.self) { dest in
                ExerciseProgressView(exerciseName: dest.exerciseName)
            }
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    private var sessionList: some View {
        List {
            ForEach(groupedSessions, id: \.key) { date, group in
                Section(header: Text(date, style: .date)) {
                    ForEach(group) { session in
                        NavigationLink(value: session) {
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

    private var groupedSessions: [(key: Date, value: [WorkoutSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        return grouped.sorted { $0.key > $1.key }
    }

    private func deleteSession(group: [WorkoutSession], offsets: IndexSet) {
        for index in offsets {
            let session = group[index]
            Task {
                try? await injected.interactors.workouts.deleteSession(id: session.id)
            }
        }
    }
}

// MARK: - Routing

extension SessionList {
    struct Routing: Equatable {}
}

// Alias so AppState.ViewRouting can reference SessionList
typealias SessionList = SessionListView

// MARK: - Navigation Destinations

struct AddExerciseDestination: Hashable {
    let sessionID: UUID?
}

struct ExerciseProgressDestination: Hashable {
    let exerciseName: String
}
