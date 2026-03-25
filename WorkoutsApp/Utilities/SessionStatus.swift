// WorkoutsApp/Utilities/SessionStatus.swift
import Foundation

/// Session lifecycle state. Stored as a raw String in SwiftData for predicate compatibility.
enum SessionStatus: String, Codable, Equatable {
    case active
    case completed
}
