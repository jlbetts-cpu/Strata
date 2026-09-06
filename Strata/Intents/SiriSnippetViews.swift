import SwiftUI
import AppIntents

/// Shown after completing a habit via Siri
struct HabitCompletionSnippet: View {
    let title: String
    let category: String
    let alreadyDone: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alreadyDone ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(categoryColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(alreadyDone ? "Already completed today" : "Completed -- building your tower")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var categoryColor: Color {
        switch category {
        case "health": Color(red: 0.063, green: 0.718, blue: 0.498)
        case "work": Color(red: 0.251, green: 0.663, blue: 1.0)
        case "creativity": Color(red: 0.686, green: 0.612, blue: 0.980)
        case "focus": Color(red: 0.992, green: 0.710, blue: 0.310)
        case "social": Color(red: 0.976, green: 0.439, blue: 0.400)
        case "mindfulness": Color(red: 0.925, green: 0.522, blue: 0.706)
        default: .gray
        }
    }
}

/// Shown when Siri lists today's habits
struct TodaysHabitsSnippet: View {
    let habits: [(title: String, category: String, done: Bool)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(habits.prefix(5), id: \.title) { habit in
                HStack(spacing: 8) {
                    Circle()
                        .fill(habit.done ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(habit.title)
                        .font(.subheadline)
                        .strikethrough(habit.done)
                        .foregroundStyle(habit.done ? .secondary : .primary)
                }
            }
            if habits.count > 5 {
                Text("+\(habits.count - 5) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

/// Error state snippet
struct IntentErrorSnippet: View {
    let message: String
    var body: some View {
        Text(message).font(.subheadline).foregroundStyle(.secondary).padding()
    }
}

/// Shown after skipping a habit via Siri
struct HabitSkipSnippet: View {
    let title: String
    let category: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "forward.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text("Skipped for today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}

/// Shown after logging mood via Siri
struct MoodLogSnippet: View {
    let mood: Int
    let motivation: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(moodEmoji)
                .font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text("Mood: \(mood)/5  Motivation: \(motivation)/5")
                    .font(.headline)
                Text("Logged for today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var moodEmoji: String {
        switch mood {
        case 1: return "😞"
        case 2: return "😐"
        case 3: return "🙂"
        case 4: return "😊"
        case 5: return "🤩"
        default: return "🙂"
        }
    }
}
