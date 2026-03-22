// WorkoutsApp/Core/AppDelegate.swift
import UIKit

/// Minimal app delegate — retained for UIApplicationDelegate lifecycle hooks.
/// AppEnvironment bootstrap has moved to RootView.
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }
}
