// WorkoutsApp/Core/AppState.swift
import SwiftUI
import Combine

struct AppState: Equatable {
    var routing = ViewRouting()
}

extension AppState {
    struct ViewRouting: Equatable {
        var exerciseList = ExerciseList.Routing()
    }
}

func == (lhs: AppState, rhs: AppState) -> Bool {
    return lhs.routing == rhs.routing
}
