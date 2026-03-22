// WorkoutsApp/Core/AppState.swift
import SwiftUI
import Combine

struct AppState: Equatable {
    var routing = ViewRouting()
}

extension AppState {
    struct ViewRouting: Equatable {
        var sessionList = SessionList.Routing()
    }
}

func == (lhs: AppState, rhs: AppState) -> Bool {
    return lhs.routing == rhs.routing
}
