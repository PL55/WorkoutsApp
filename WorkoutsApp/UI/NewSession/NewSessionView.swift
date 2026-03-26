// WorkoutsApp/UI/NewSession/NewSessionView.swift
import SwiftUI

struct NewSessionView: View {

    @Environment(\.dismiss) private var dismiss
    /// Called with the chosen name when the user taps Start.
    let onStart: (String) -> Void

    @State private var sessionName: String

    init(defaultName: String, onStart: @escaping (String) -> Void) {
        _sessionName = State(initialValue: defaultName)
        self.onStart = onStart
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Name") {
                    TextField("e.g. Leg Day", text: $sessionName)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        onStart(sessionName)
                        dismiss()
                    }
                    .disabled(sessionName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
