import SwiftUI
import AppIntents

/// Shown after logging a win through Siri: the block it became, in its own
/// colour, and how many there are today.
struct WinLoggedSnippet: View {
    let title: String?
    let colour: HabitCategory
    let today: Int

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(colour.style.baseColor)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title ?? "A win")
                    .font(.headline)
                Text(today == 1 ? "The first on today's tower" : "\(today) on today's tower")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}

/// Shown when Siri lists today's wins.
struct TodaysWinsSnippet: View {
    let wins: [TodaysWins.Win]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(wins.prefix(5)) { win in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(win.colour.style.baseColor)
                        .frame(width: 10, height: 10)
                    Text(win.title ?? "A win")
                        .font(.subheadline)
                        .foregroundStyle(win.title == nil ? .secondary : .primary)
                }
            }
            if wins.count > 5 {
                Text("and \(wins.count - 5) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

/// A single line, for when there is nothing to show.
struct IntentMessageSnippet: View {
    let message: String
    var body: some View {
        Text(message).font(.subheadline).foregroundStyle(.secondary).padding()
    }
}
