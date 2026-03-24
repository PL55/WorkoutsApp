// WorkoutsApp/UI/RootView.swift
import SwiftUI

/// Manages app launch state and surfaces database errors with a retry option.
/// Renders a ProgressView during bootstrap, SessionListView on success,
/// and an error screen with a Retry button on failure.
struct RootView: View {

    @State private var launchState: Loadable<AppEnvironment>

    let inspection = Inspection<Self>()

    /// Production init — starts in .notRequested; bootstrap fires from .onAppear.
    init() {
        _launchState = State(initialValue: .notRequested)
    }

    /// Testing init — allows injecting a specific launch state directly.
    init(launchState: Loadable<AppEnvironment>) {
        _launchState = State(initialValue: launchState)
    }

    var body: some View {
        content
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch launchState {
        case .notRequested, .isLoading:
            ProgressView("Loading…")
                .onAppear { bootstrap() }
        case .loaded(let env):
            SessionListView()
                .modifier(RootViewAppearance())
                .inject(env.diContainer)
        case .failed(let error):
            errorView(error)
        }
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text("Unable to load database")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry") { bootstrap() }
        }
    }

    /// Starts the async bootstrap and updates launchState.
    /// Uses manual Task + Loadable (not $binding.load {}) for consistency
    /// with the ViewModel pattern — no Binding is available here.
    private func bootstrap() {
        guard !launchState.isLoading else { return }
        let cancelBag = CancelBag()
        launchState.setIsLoading(cancelBag: cancelBag)
        let task = Task {
            do {
                launchState = .loaded(try await AppEnvironment.bootstrap())
            } catch {
                launchState = .failed(error)
            }
        }
        task.store(in: cancelBag)
    }
}

// Loadable.isLoading is declared as an internal extension in Loadable.swift.
