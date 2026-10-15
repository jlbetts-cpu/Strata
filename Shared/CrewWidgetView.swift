import SwiftUI
import UIKit
import WidgetKit

/// The crew widget's face (`CrewWidget`). In `Shared/` so the app's
/// `WidgetPreviewRenderer` can photograph it; the widget is the only place
/// it is shown.
// MARK: - The face

struct CrewWidgetView: View {
    let crew: CrewWidgetSnapshot.Crew?
    /// Forced size, for the app's renderer (`WidgetPreviewRenderer`).
    var forcedFamily: WidgetFamily?
    @Environment(\.widgetFamily) private var environmentFamily

    private var family: WidgetFamily { forcedFamily ?? environmentFamily }

    /// Small fits four people across; medium fits a full crew of eight.
    private var cap: Int { family == .systemMedium ? 8 : 4 }

    /// Everyone, in the order they joined. When a small widget cannot fit the
    /// crew, the people who have logged come first, so the row shows the day.
    private var shown: [CrewWidgetSnapshot.Member] {
        guard let crew else { return [] }
        guard crew.members.count > cap else { return crew.members }
        let logged = crew.members.filter { !$0.wins.isEmpty }
        let waiting = crew.members.filter { $0.wins.isEmpty }
        return Array((logged + waiting).prefix(cap))
    }

    var body: some View {
        if let crew {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(crew.name)
                        .font(.system(size: 15, weight: .semibold))
                        // Redacted on a locked phone and in StandBy: friends'
                        // names and faces are for whoever unlocked it.
                        .privacySensitive()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if family == .systemMedium {
                        Text("\(crew.loggedCount) of \(crew.members.count) today")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                CrewStand(members: shown)
                    .privacySensitive()
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)
                Text("Your crew shows up here.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

/// The row: a column per person, a head on each person's stack of wins.
private struct CrewStand: View {
    let members: [CrewWidgetSnapshot.Member]

    /// Between people.
    private let gap: CGFloat = 8
    /// Between a person's blocks, as the tower's lattice spaces them.
    private let blockGap: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let count = CGFloat(max(members.count, 1))
            // Each person gets an even share of the width, so a medium
            // widget is filled rather than holding a small row in its middle.
            let slot = floor(geo.size.width / count)
            let column = min(52, slot - gap)
            let head = column
            // The stacks fill the height: the tallest reaches up under the
            // top line, and the rest keep the same scale so a Deep win is
            // the same height in every column. Never more than twice the
            // resting size, so one Quick win does not become a pillar.
            let room = max(0, geo.size.height - head - 2)
            let tallest = members.map { stackHeight($0.wins, column: column) }.max() ?? 0
            let scale = tallest > 0 ? min(room / tallest, 2) : 1
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(members) { member in
                    VStack(spacing: 2) {
                        Face(member: member, side: head)
                            .opacity(member.wins.isEmpty ? 0.45 : 1)
                            .grayscale(member.wins.isEmpty ? 1 : 0)
                        VStack(spacing: blockGap * scale) {
                            ForEach(Array(member.wins.reversed().enumerated()), id: \.offset) { _, win in
                                RoundedRectangle(cornerRadius: column * 0.147, style: .continuous)
                                    .fill(Color(hex6: win.hex))
                                    .frame(width: column, height: height(of: win, column: column) * scale)
                            }
                        }
                    }
                    .frame(width: slot)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(member.wins.isEmpty ? "\(member.name), no wins yet"
                                        : member.wins.count == 1 ? "\(member.name), 1 win"
                                        : "\(member.name), \(member.wins.count) wins")
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }

    /// Quick, Regular and Deep, as the tower's 1, 2 and 4 cells read side by
    /// side in one column.
    private func height(of win: CrewWidgetSnapshot.Win, column: CGFloat) -> CGFloat {
        switch win.tier {
        case 3: return column * 0.62
        case 2: return column * 0.4
        default: return column * 0.24
        }
    }

    private func stackHeight(_ wins: [CrewWidgetSnapshot.Win], column: CGFloat) -> CGFloat {
        guard !wins.isEmpty else { return 0 }
        return wins.reduce(0) { $0 + height(of: $1, column: column) } + blockGap * CGFloat(wins.count - 1) + 2
    }
}

/// A person's face as the app rendered it, or their initial.
private struct Face: View {
    let member: CrewWidgetSnapshot.Member
    let side: CGFloat

    var body: some View {
        if let file = member.face, let directory = CrewWidgetSnapshot.headDirectory,
           let image = UIImage(contentsOfFile: directory.appendingPathComponent(file).path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
        } else {
            Circle()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: side * 0.78, height: side * 0.78)
                .overlay {
                    Text(member.name.first.map { String($0).uppercased() } ?? "")
                        .font(.system(size: side * 0.38, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: side, height: side)
        }
    }
}

extension Color {
    /// `RRGGBB`, for the colours the snapshot carries.
    init(hex6: String) {
        let value = UInt32(hex6, radix: 16) ?? 0x888888
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
