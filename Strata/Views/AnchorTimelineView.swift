import SwiftUI

struct AnchorTimelineView: View {
    let events: [CalendarAnchor]
    let workouts: [WorkoutEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !events.isEmpty {
                Text("SCHEDULE")
                    .font(Typography.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                ForEach(events) { event in
                    eventRow(event)

                    if event.id != events.last?.id {
                        timelineConnector
                    }
                }
            }

            if !workouts.isEmpty {
                Text("WORKOUTS")
                    .font(Typography.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                    .padding(.horizontal, 20)
                    .padding(.top, events.isEmpty ? 8 : 16)
                    .padding(.bottom, 8)

                ForEach(workouts) { workout in
                    workoutRow(workout)
                }
            }
        }
    }

    // MARK: - Event Row

    private func eventRow(_ event: CalendarAnchor) -> some View {
        HStack(spacing: 12) {
            // Timeline dot
            Circle()
                .fill(Color(
                    red: event.colorRed,
                    green: event.colorGreen,
                    blue: event.colorBlue
                ))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(Typography.bodyMedium)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(event.timeString)
                    .font(Typography.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Workout Row

    private func workoutRow(_ workout: WorkoutEvent) -> some View {
        HStack(spacing: 12) {
            // Health icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(HabitCategory.health.style.gradient)
                    .frame(width: 36, height: 36)

                Image(systemName: "figure.run")
                    .font(Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.displayName)
                    .font(Typography.bodyMedium)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(workout.durationMinutes) min")
                        .font(Typography.caption2)
                        .foregroundStyle(.secondary)

                    if let cal = workout.calories {
                        Text("\(Int(cal)) kcal")
                            .font(Typography.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HabitCategory.health.style.gradientBottom)
                .font(.body)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Connector

    private var timelineConnector: some View {
        HStack {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 2, height: 16)
                .padding(.leading, 24)
            Spacer()
        }
    }
}
