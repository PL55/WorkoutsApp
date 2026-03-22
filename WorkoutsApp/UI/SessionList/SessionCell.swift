// WorkoutsApp/UI/SessionList/SessionCell.swift
import SwiftUI

struct SessionCell: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.date, style: .time)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(session.strengthExercises.count + session.cardioExercises.count) exercise(s)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
