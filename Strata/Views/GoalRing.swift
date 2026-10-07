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

    /// **Hard day** (the owner's pick, 2026-10-06: "Three + a Hard day
    /// switch"): the day it was switched on, as a date key. Kept as a day and
    /// not a flag so it turns itself off at midnight, with nothing to undo.
    static let hardDayKey = "hardDay"

    /// **The goal for today, which is the one everything asks**: the crest,
    /// the dance, the booth's develop, the cue and the evening's check-in.
    /// On a hard day it is your three; never MORE than the goal you set, so a
    /// hard day can only make the day lighter.
    static func today(goal: Int, hardDay: String, on day: String) -> Int {
        hardDay == day ? min(goal, YourThree.size) : goal
    }

    /// Today's goal from the stored settings, for code with no view to hold
    /// them (`EveningCheckIn`).
    static func stored(on day: String, defaults: UserDefaults = .standard) -> Int {
        today(goal: defaults.object(forKey: defaultsKey) as? Int ?? standard,
              hardDay: defaults.string(forKey: hardDayKey) ?? "", on: day)
    }
}

/// **Your three: wins you could do on your worst day** (the owner,
/// 2026-10-06: "add people's 3 daily minimums, like these are wins that no
/// matter what life does, no matter your emotional state, no matter what
/// perspective of life you have based on the season it's in, you can adhere
/// to").
///
/// A floor chosen ahead, on a good day, is the "minimum viable" habit that
/// survives a bad one (Fogg's tiny habits; Wood's habit research: what holds
/// up under stress is what was made small and automatic). So the list is
/// three, and each is small enough to do in bed.
///
/// **Built so it can never read as a debt.** The three are ordinary wins:
/// logged as any other (`HabitLog`, no mark), counted toward the goal, never
/// synced to a crew as a list. Not done shows nothing at all, never an empty
/// circle; done shows a quiet tick. They lead the ideas over the add sheet's
/// keyboard (`WinIdeas.pick`), and drop out of it once logged today, as every
/// idea does. No cue of their own: one cue a day stays the rule.
nonisolated enum YourThree {
    static let defaultsKey = "yourThree"
    static let size = 3

    /// One of your three: its words, and its colour when it has one (a pick
    /// does; a win you typed takes the colour you last gave it).
    nonisolated struct Item: Codable, Equatable, Hashable, Sendable, Identifiable {
        let title: String
        var category: HabitCategory?
        var id: String { title.lowercased() }
    }

    /// The picks, in the past-tense voice of `WinIdeas.small`: things a
    /// person can say they did on their worst day.
    static let picks: [Item] = [
        Item(title: "Drank some water", category: .health),
        Item(title: "Went outside", category: .health),
        Item(title: "Replied to a message", category: .social),
        Item(title: "Took my meds", category: .health),
        Item(title: "Ate a real meal", category: .health),
        Item(title: "Brushed my teeth", category: .health),
        Item(title: "Opened a window", category: .mindfulness),
        Item(title: "Stretched for a minute", category: .health),
    ]

    /// Every word a person reads here, in one place, so a test can hold them
    /// to the owner's rules (no long dash; nothing that counts against you).
    nonisolated enum Copy {
        static let section = "Your Three"
        static let footer = "Small enough for your hardest day. Any of them counts."
        static let empty = "Choose your three"
        static let pickerTitle = "Three for any day"
        static let pickerLine = "Pick ones you could do on your worst day."
        static let ownPrompt = "Or write your own"
        static let hardDay = "Hard day"
        static let hardDayLine = "Today, your three are enough."
        static let onboardingTitle = "Three you can always do"
        static let onboardingLine = pickerLine
        static let onboardingKeep = "Keep these"
        static let onboardingSkip = "Skip"
        static let onboardingWaiting = "Not yet. Pick one, or skip."

        static var all: [String] {
            [section, footer, empty, pickerTitle, pickerLine, ownPrompt, hardDay, hardDayLine,
             onboardingTitle, onboardingLine, onboardingKeep, onboardingSkip, onboardingWaiting]
        }
    }

    /// The stored list, read back. Anything unreadable is no list, never a
    /// crash; past three, only the first three.
    static func decode(_ raw: String) -> [Item] {
        guard let data = raw.data(using: .utf8),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return [] }
        return clean(items)
    }

    static func encode(_ items: [Item]) -> String {
        guard let data = try? JSONEncoder().encode(clean(items)) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Trimmed, named, each once, three at most.
    static func clean(_ items: [Item]) -> [Item] {
        var seen: Set<String> = []
        var out: [Item] = []
        for item in items {
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, seen.insert(title.lowercased()).inserted else { continue }
            out.append(Item(title: title, category: item.category))
            if out.count == size { break }
        }
        return out
    }

    /// The ones logged today, matched by title the way `WinIdeas.pick`
    /// matches what is done: case and surrounding space ignored.
    static func done(_ items: [Item], titlesToday: some Sequence<String>) -> Set<String> {
        let today = Set(titlesToday.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return Set(items.map(\.id).filter(today.contains))
    }

    /// As ideas for the add sheet. A typed one with no colour of its own
    /// takes the colour it was last logged in, else keeps the sheet's.
    static func ideas(_ items: [Item], logged: [WinIdeas.Logged]) -> [WinIdea] {
        items.map { item in
            if let category = item.category { return WinIdea(title: item.title, category: category) }
            let last = logged.filter { $0.title.lowercased() == item.id }.max { $0.day < $1.day }
            return WinIdea(title: item.title, category: last?.category ?? .unlabeled, keepsColour: last == nil)
        }
    }
}

/// **The ring alone, in ink**: a segment per win, the rest the track, drawn
/// round whatever sits in the middle. **Monotone on purpose** (the owner,
/// 2026-10-06: "the blocks being the only colored element feels right to
/// me"); it was a segment per win in its block's colour, and the colour
/// belongs to the blocks alone. Drawn (your head on Wins; a
/// crew's bubble, once crews have goals), so the two towers share one ring.
struct GoalRingStroke: View {
    let wins: Int
    let goal: Int
    var line: CGFloat = 4
    /// Half the space between two segments, as a share of the ring.
    private static let gap = 0.018

    /// One segment a win toward the goal; past it, one for every win, so
    /// the ring stays full.
    private var segments: Int { max(1, max(goal, wins)) }

    var body: some View {
        ZStack {
            ForEach(0..<segments, id: \.self) { i in
                let span = 1.0 / Double(segments)
                Circle()
                    .trim(from: Double(i) * span + Self.gap, to: Double(i + 1) * span - Self.gap)
                    .stroke(i < wins ? AppColors.inkPrimary : AppColors.inkPrimary.opacity(0.08),
                            style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(GridConstants.cueIn, value: wins)
        .accessibilityHidden(true)
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
    /// Today's goal (`DailyGoal.today`): your three on a hard day. Read
    /// only; the number is set in Your day.
    let goal: Int
    /// Open Your day (`YourDaySheet`), as a crew's middle opens its details.
    var openDay: () -> Void = {}
    /// The crew bubble's side, so the two towers' middles match.
    var side: CGFloat = 60

    private var arrived: Bool { LaunchMoment.shared.finished }
    @State private var swell = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let line: CGFloat = 4

    var body: some View {
        VStack(spacing: GridConstants.spacing) {
            Button { openDay() } label: {
                ZStack {
                    GoalRingStroke(wins: wins, goal: goal, line: Self.line)
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
            Button { openDay() } label: {
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
        // **It arrives after the launch** (the owner: drawn, "erased and then
        // that middle progress comes in"): small and clear until the logo
        // has been rubbed out, then in on the cue's spring.
        .scaleEffect(arrived || reduceMotion ? 1 : 0.7)
        .opacity(arrived ? 1 : 0)
        .animation(reduceMotion ? GridConstants.crossFade : GridConstants.cueIn, value: arrived)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(wins == 1 ? "1 win today" : "\(wins) wins today")
        .accessibilityValue("Goal \(goal)")
        .accessibilityHint("Opens your day")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { openDay() }
    }
}

/// **You, in the middle**: the head your crews see (`HeadStore.headForCrews`),
/// so Wins and a crew show the same you; without one, your profile picture.
struct CrestFace: View {
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
