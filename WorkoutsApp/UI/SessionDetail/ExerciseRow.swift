// WorkoutsApp/UI/SessionDetail/ExerciseRow.swift
import SwiftUI

struct ExerciseRow: View {
    let exercise: any AnalyticsTrackable

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .font(.body)
            Text("\(exercise.analyticsLabel): \(exercise.analyticsValue, format: .number.precision(.fractionLength(1)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
