// WorkoutsApp/UI/ExerciseList/ExerciseTileView.swift
import SwiftUI

struct ExerciseTileView: View {

    let overview: ExerciseOverviewDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(overview.name)
                .font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best: \(overview.bestValue, format: .number.precision(.fractionLength(1))) \(overview.analyticsLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Latest: \(overview.latestValue, format: .number.precision(.fractionLength(1))) \(overview.analyticsLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(overview.lastDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
