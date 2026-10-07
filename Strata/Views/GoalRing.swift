import SwiftUI

/// **Today's goal, as a ring, in the middle of the Wins header** (the owner,
/// 2026-10-06: "a goal progress ring in the middle of the home page which
/// fits the crew menu with there middle menu ... it lets users set there
/// goals for the day how many wins they want to obtain").
///
/// Where a crew's tower has its faces, yours has the day's count in a ring
/// that fills toward a number you chose. A specific goal you set yourself
/// raises what gets done (Locke and Latham 2002), and the nearer it is the
/// harder people push (the goal gradient: Kivetz, Urminsky and Zheng 2006).
///
/// **Built so it cannot become a verdict**, because an unmet target is the
/// loudest way to tell someone with ADHD they failed (the rest-day reasoning,
/// `Streaks.Rest`): the ring only ever fills, never shows what is left, has
/// no red and no "missed"; past the goal it stays full and the count keeps
/// going; it starts again with the day; and you choose the number, starting
/// low. Reaching it is the day's peak: the ring swells and the tower dances
/// (`MainAppView`); not reaching it says nothing at all.
///
/// A tap opens the goal: minus, the number, plus.
nonisolated enum DailyGoal {
    static let defaultsKey = "dailyGoal"
    static let standard = 3
    static let range = 1...12

    static func progress(wins: Int, goal: Int) -> Double {
        guard goal > 0 else { return 1 }
        return min(1, Double(max(0, wins)) / Double(goal))
    }

    /// The moment it is reached: the count crossing the goal, not resting on it.
    static func reached(from old: Int, to new: Int, goal: Int) -> Bool {
        old < goal && new >= goal
    }

    static func clamped(_ value: Int) -> Int { min(range.upperBound, max(range.lowerBound, value)) }
}

/// **The ring alone**, segment per win in its block's colour, the rest the
/// track: drawn round whatever sits in the middle (your head on Wins; a
/// crew's bubble, once crews have goals), so the two towers share one ring.
struct GoalRingStroke: View {
    let wins: Int
    var colours: [Color] = []
    let goal: Int
    var line: CGFloat = 4
    /// Half the space between two segments, as a share of the ring.
    private static let gap = 0.018

    /// One segment a win toward the goal; past it, one for every win, so
    /// the ring stays full and keeps the day's colours.
    private var segments: Int { max(1, max(goal, wins)) }

    var body: some View {
        ZStack {
            ForEach(0..<segments, id: \.self) { i in
                let span = 1.0 / Double(segments)
                Circle()
                    .trim(from: Double(i) * span + Self.gap, to: Double(i + 1) * span - Self.gap)
                    .stroke(i < wins ? colour(i) : AppColors.inkPrimary.opacity(0.08),
                            style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(GridConstants.cueIn, value: wins)
        .accessibilityHidden(true)
    }

    private func colour(_ i: Int) -> Color {
        colours.indices.contains(i) ? colours[i] : AppColors.inkPrimary
    }
}

/// **The caption under a tower's middle**: a crew's name, or the goal's
/// fraction. One glass capsule for both towers (it was the crew header's
/// own), so the two read as the same object.
struct CrestCaption: View {
    let text: String
    var chevron = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(Typography.headerSmall)
                .monospacedDigit()
                .foregroundStyle(AppColors.inkPrimary)
                .lineLimit(1)
                .contentTransition(.numericText())
            if chevron {
                Image(systemName: "chevron.right")
                    .font(Typography.headerSmall)
                    .imageScale(.small)
                    .foregroundStyle(AppColors.inkTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassCapsule(onPage: true)
    }
}

/// **The middle of the Wins header** (the owner, 2026-10-06: "make it so we
/// can have the head in there and the fraction under like where the name
/// would be in the crew ... as close to the crew experience as possible").
/// Your head in the ring, the day's fraction in the crew's caption under it.
/// A tap on either sets the goal.
struct GoalCrest: View {
    let wins: Int
    var colours: [Color] = []
    @Binding var goal: Int
    /// The crew bubble's side, so the two towers' middles match.
    var side: CGFloat = 60

    @State private var choosing = false
    @State private var swell = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let line: CGFloat = 4

    var body: some View {
        VStack(spacing: GridConstants.spacing) {
            Button { choosing = true } label: {
                ZStack {
                    GoalRingStroke(wins: wins, colours: colours, goal: goal, line: Self.line)
                        .padding(Self.line / 2 + 2)
                    CrestFace(side: side - 2 * (Self.line + 6))
                }
                .frame(width: side, height: side)
                .stillGlassCircle()
                .scaleEffect(swell && !reduceMotion ? 1.1 : 1)
                .contentShape(Circle())
            }
            .buttonStyle(.press)
            .zIndex(1)
            Button { choosing = true } label: {
                CrestCaption(text: "\(wins)/\(goal)")
                    // A 44pt target round the capsule, as the crew's has.
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
            }
            // `.plain`: a scaling press on interactive glass cancels the tap
            // on a phone (`CrewReactions`); the crew's caption is the same.
            .buttonStyle(.plain)
            .zIndex(2)
        }
        .animation(GridConstants.cueIn, value: wins)
        .onChange(of: wins) { old, new in
            guard DailyGoal.reached(from: old, to: new, goal: goal) else { return }
            // The tower's dance carries the tap; without motion it does not
            // dance, so the crest does.
            if reduceMotion { HapticsEngine.success() }
            withAnimation(GridConstants.cueIn) { swell = true }
            Task {
                try? await Task.sleep(for: .milliseconds(420))
                withAnimation(GridConstants.cueOut) { swell = false }
            }
        }
        .popover(isPresented: $choosing) {
            GoalChooser(goal: $goal)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(wins == 1 ? "1 win today" : "\(wins) wins today")
        .accessibilityValue("Goal \(goal)")
        .accessibilityHint("Sets the day's goal")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { choosing = true }
    }
}

/// **You, in the middle**: the head your crews see (`HeadStore.headForCrews`),
/// so Wins and a crew show the same you; without one, your profile picture.
private struct CrestFace: View {
    let side: CGFloat

    var body: some View {
        if let rig = HeadStore.shared.headForCrews {
            LivingHeadView(rig: rig, side: side * ProfileAvatar.headShare, liveliness: .calm)
                .frame(width: side, height: side)
                .accessibilityHidden(true)
        } else {
            ProfileAvatar(side: side)
        }
    }
}

/// The goal: minus, the number, plus, and what it is, in one line.
private struct GoalChooser: View {
    @Binding var goal: Int

    var body: some View {
        VStack(spacing: GridConstants.gapItem) {
            Text("Daily goal")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
            HStack(spacing: GridConstants.gapLabel) {
                GlassIconButton(systemName: "minus", onPage: true, accessibilityLabel: "Fewer") {
                    goal = DailyGoal.clamped(goal - 1)
                }
                .disabled(goal <= DailyGoal.range.lowerBound)
                Text("\(goal)")
                    .font(Typography.tally)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.inkPrimary)
                    .contentTransition(.numericText(value: Double(goal)))
                    .frame(minWidth: 44)
                    .animation(GridConstants.crossFade, value: goal)
                GlassIconButton(systemName: "plus", onPage: true, accessibilityLabel: "More") {
                    goal = DailyGoal.clamped(goal + 1)
                }
                .disabled(goal >= DailyGoal.range.upperBound)
            }
        }
        .padding(GridConstants.gapWide)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily goal")
    }
}
