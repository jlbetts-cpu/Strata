import SwiftUI

/// **The app's own loader** (the owner, 2026-10-15, with a recording of a
/// ring that draws and erases itself: "the loading I want it to look kinda
/// like this with the erasing effect kinda like the logo and it would
/// alternate from doodle and clean and have the colors of the blocks
/// alternating as well").
///
/// A ring drawn on from its head and rubbed out from its tail, turning as it
/// goes, as the launch's camera is drawn and then erased (`LaunchHandoff`).
/// Each round is the next block colour, and every other round is drawn by
/// hand: a loop that wobbles a little and does not quite meet, at his pen's
/// weight, where the clean round is a true circle. One component wherever the
/// app waits, so waiting looks like this app and nothing else.
///
/// Reduce Motion: no turning and no drawing. A whole ring stands still and
/// its colour changes round to round by a cross-fade.
struct WinsLoader: View {
    var size: CGFloat = 28

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One round: drawn on, then rubbed out.
    static let round: Double = 1.4
    /// The block colours, in the order the tower offers them.
    static let colours: [HabitCategory] = HabitCategory.selectable

    var body: some View {
        TimelineView(.animation(paused: false)) { context in
            let frame = Self.frame(at: context.date.timeIntervalSinceReferenceDate)
            ring(frame)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Loading")
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private func ring(_ f: Frame) -> some View {
        let colour = Self.colours[f.round % Self.colours.count].style.baseColor
        let line = StrokeStyle(lineWidth: max(2, size * 0.1), lineCap: .round, lineJoin: .round)
        if reduceMotion {
            Circle()
                .inset(by: line.lineWidth / 2)
                .stroke(colour, style: line)
                .animation(GridConstants.crossFade, value: f.round)
        } else {
            Group {
                if f.round % 2 == 1 {
                    // His pen: a little heavier, and a loop drawn by hand.
                    DrawnLoop(seed: f.round)
                        .trim(from: f.tail, to: f.head)
                        .stroke(colour, style: StrokeStyle(lineWidth: line.lineWidth * 1.15, lineCap: .round, lineJoin: .round))
                } else {
                    Circle()
                        .inset(by: line.lineWidth / 2)
                        .trim(from: f.tail, to: f.head)
                        .stroke(colour, style: line)
                }
            }
            .rotationEffect(.degrees(f.turn))
        }
    }

    struct Frame: Equatable {
        let round: Int
        /// Where the drawn part starts and ends, as fractions of the loop.
        let tail: Double
        let head: Double
        /// How far the whole ring has turned, in degrees.
        let turn: Double
    }

    /// A pure function of time, so it can be tested and never drifts.
    static func frame(at time: Double) -> Frame {
        let progress = time / round
        let index = Int(progress.rounded(.down))
        let p = progress - Double(index)
        // The first half draws it on, the second rubs it out after it.
        let head = ease(min(1, p * 1.6)) * 0.86
        let tail = ease(max(0, p * 1.6 - 0.6)) * 0.86
        // Turning steadily, and a quarter on with every round, so no round
        // starts where the last one did.
        let turn = (time * 210).truncatingRemainder(dividingBy: 360) + Double(index % 4) * 90 - 90
        return Frame(round: max(0, index), tail: min(tail, head), head: head, turn: turn)
    }

    private static func ease(_ x: Double) -> Double {
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }
}

/// **A loop drawn by hand**: round, but not a circle. The radius wanders a
/// little, twice slowly and once quickly, as a pen held loosely does, and the
/// end runs a touch past the start. Seeded, so a round is drawn the same way
/// for its whole life.
private struct DrawnLoop: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * 0.86
        let phase = Double(seed % 7) * 0.9
        var path = Path()
        let steps = 72
        // A little past a whole turn: the pen does not quite close the loop.
        let sweep = 2 * Double.pi * 1.04
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = -Double.pi / 2 + sweep * t
            let wobble = 1 + 0.032 * sin(2 * angle + phase) + 0.014 * sin(5 * angle + phase * 1.7)
            // The end drifts inward a hair as it passes the start.
            let drift = 1 - 0.05 * max(0, t - 0.96) / 0.04
            let r = radius * wobble * drift
            let point = CGPoint(x: centre.x + r * cos(angle), y: centre.y + r * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
