// WorkoutsApp/Core/App.swift
import SwiftUI

@main
struct MainApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.isRunningTests {
                Text("Running unit tests")
            } else {
                RootView()
            }
        }
    }
}
