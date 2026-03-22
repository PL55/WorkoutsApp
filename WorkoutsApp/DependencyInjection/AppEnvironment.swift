// WorkoutsApp/DependencyInjection/AppEnvironment.swift
import Foundation
import SwiftData

/// Bootstrapped app environment. Created once at launch via `bootstrap()`.
/// `ModelContainer.stub` is still available for tests — only the silent
/// production fallback is removed. Errors now propagate so RootView can
/// surface them with a retry option.
struct AppEnvironment {
    let diContainer: DIContainer
    let modelContainer: ModelContainer

    /// Creates the full app environment: ModelContainer → Repository → Interactor → DIContainer.
    /// Throws if ModelContainer creation fails (e.g. schema migration error, disk full).
    /// Not constrained to @MainActor — called from a Task inside RootView.
    static func bootstrap() async throws -> AppEnvironment {
        let modelContainer = try ModelContainer.appModelContainer()
        let dbRepository = MainDBRepository(modelContainer: modelContainer)
        let appState = Store<AppState>(AppState())
        let interactors = DIContainer.Interactors(
            workouts: RealWorkoutsInteractor(dbRepository: dbRepository)
        )
        let diContainer = DIContainer(appState: appState, interactors: interactors)
        return AppEnvironment(diContainer: diContainer, modelContainer: modelContainer)
    }
}
