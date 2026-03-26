// WorkoutsApp/UI/SessionList/SessionCell.swift
import SwiftUI

struct SessionCell: View {
    let session: WorkoutSessionDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.displayName)
                .font(.headline)
            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(session.strengthExercises.count + session.cardioExercises.count) exercise(s)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
