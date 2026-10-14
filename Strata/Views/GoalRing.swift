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

    /// **Hard day is gone** (the owner, 2026-10-07: "I don't understand the
    /// point of checking the hard day thing"; his pick: remove it). It made
    /// today's goal your three for a day. Your three stay, as the first lines
    /// of each day's Plan (`YourThree.plan`); the goal is the one you set.

    /// Today's goal from the stored settings, for code with no view to hold
    /// them (`EveningCheckIn`).
    static func stored(on day: String, defaults: UserDefaults = .standard) -> Int {
        defaults.object(forKey: defaultsKey) as? Int ?? standard
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
        static let onboardingTitle = "Three you can always do"
        static let onboardingLine = pickerLine
        static let onboardingKeep = "Keep These"
        static let onboardingSkip = "Skip"
        static let onboardingWaiting = "Not yet. Pick one, or skip."

        static var all: [String] {
            [section, footer, empty, pickerTitle, pickerLine, ownPrompt,
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
                DoodleRing()
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

/// **The ring as his pen draws one** (the owner, 2026-10-13: he picked "The
/// goal ring round my head" drawn in his doodle style; "finish the
/// recommended making sure the aesthetic is perfect and clean").
///
/// The same hand as `DoodleDot`, the one dot for "something new": round, a
/// touch fuller on one side, its edge never quite a circle. Two slow
/// ripples round the rim and a hair less tall than wide, **fixed**, so every
/// ring in the app is the same mark and nothing shimmers. Gentler than the
/// dot's, because a ring is a line, not a fill: the dot's 6% would read as a
/// wobble on a 52pt ring, where 2% reads as a hand. At the crest that is
/// about half a point either side of true. A slight variation, not a
/// scribble.
///
/// Begins at three o'clock and runs clockwise, as `Circle` does, so a
/// segment trimmed from it lands where the circle's did and the ring's
/// `rotationEffect(-90)` still puts the first segment at the top.
struct DoodleRing: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0...Self.steps {
            let t = Double(i) / Double(Self.steps) * 2 * .pi
            let k = Self.radiusShare(at: t)
            let p = CGPoint(x: c.x + cos(t) * r * k, y: c.y + sin(t) * r * k * Self.squash)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    /// Enough points that no corner shows under a 2.6pt round pen even on
    /// the moment's 220pt ring: 1.7pt apart at the crest, 5.8 at full size.
    static let steps = 120
    /// A hair less tall than wide, as the dot is (0.97 there).
    static let squash = 0.99

    /// **The radius at angle `t`, as a share of the frame's**: within the
    /// frame at its widest (the ripples only take away, as the dot's do),
    /// and back where it began at a full turn, so the line closes on itself.
    nonisolated static func radiusShare(at t: Double) -> Double {
        0.98 + 0.014 * sin(2 * t + 0.7) + 0.006 * sin(3 * t + 2.1)
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
                // Grown no further than XXXL (2026-10-08): at the largest
                // accessibility size the fraction was twice the width of the
                // ring it captions and ran into the tower's first row.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
/// A tap on the fraction opens Your day; so does a tap on your face, unless
/// your head is in it, when the tap lets him out onto the tower.
struct GoalCrest: View {
    let wins: Int
    /// Today's goal, the one you set. Read only; the number is set in Your day.
    let goal: Int
    /// Open Your day (`YourDaySheet`), as a crew's middle opens its details.
    var openDay: () -> Void = {}
    /// The crew bubble's side, so the two towers' middles match.
    var side: CGFloat = 60

    private var arrived: Bool { LaunchMoment.shared.finished }
    /// What the ring and the fraction show: the count, or the count before
    /// the win the ring is about to come forward for (`RingMoment.holding`).
    private var shown: Int { RingMoment.shared.holding ?? wins }
    @State private var swell = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// **His pen's weight** (2026-10-14, the doodle ring): about 2.6pt,
    /// the line `skeleton.py` was settled at (2026-10-07: 2.3 "too thin",
    /// 4.0 "a bit too thick") and beside `InkPen.width` 2.5. It was 4, a
    /// system weight; a hand-drawn ring at 4 reads as a marker, not a pen.
    static let line: CGFloat = 2.6
    /// From the crest's edge to the middle of the ring's line: where the 4pt
    /// ring's middle was, so the thinner pen sits on the same circle and
    /// neither the face nor the glass round it moves.
    static let ringInset: CGFloat = 4
    /// From the crest's edge to the face: the ring, and a little glass
    /// between it and you. Kept at the 10 the 4pt ring left, so the face is
    /// the size it was.
    static let faceInset: CGFloat = 10

    /// The face inside a crest of `side`. A share of the side, so the crest,
    /// its trip (`GoalRingMomentLayer`) and the head's flight in and out
    /// (`CompanionParking.crestHeadSide`) agree at any size.
    static func faceSide(crest side: CGFloat) -> CGFloat {
        side * (1 - 2 * faceInset / 60)
    }

    /// The caption under the ring and its 44pt target: how far below the
    /// ring a head let out is put, so he starts in the room and not on the
    /// fraction.
    static let captionRoom: CGFloat = 48

    private var parking: CompanionParking { .shared }

    /// **Your head is out on the tower**, so the ring holds your picture
    /// (`CrestFace.headIsOut`). Not while the crest is handing him over.
    static var headIsOut: Bool {
        let parking = CompanionParking.shared
        return HeadStore.shared.headForTower != nil && !parking.parked && !parking.releasing
    }

    /// **A press on your face lets your head out** (the owner, 2026-10-13:
    /// "pfp/head in middle of wins tower (press, head comes out)"), as a
    /// press on a face in a crew's bubble does (`CrewParking.pop`). Only
    /// with a head in the ring: with none, or with him already out, the
    /// press opens Your day, as it always has.
    private var canLetOut: Bool {
        HeadStore.shared.headForCrews != nil && !Self.headIsOut
            && !parking.arriving && !parking.releasing
    }

    var body: some View {
        VStack(spacing: GridConstants.spacing) {
            Button { pressFace() } label: {
                ZStack {
                    GoalRingStroke(wins: shown, goal: goal, line: Self.line)
                        .padding(Self.ringInset)
                    CrestFace(side: Self.faceSide(crest: side), headIsOut: Self.headIsOut)
                }
                .frame(width: side, height: side)
                .stillGlassCircle()
                // **Carried over it, it swells to say "let go here"**; he
                // lands and it gives and comes back: the crew bubble's two
                // answers (`CrewBubble`), on the crest that is his dock now.
                .scaleEffect(parking.over && !reduceMotion ? 1.12 : 1)
                .animation(GridConstants.motionSnappy, value: parking.over)
                .phaseAnimator([false, true], trigger: parking.landed) { content, phase in
                    content.scaleEffect(phase && !reduceMotion ? 1.1 : 1)
                } animation: { phase in
                    phase ? GridConstants.tapSquashSpring : GridConstants.elasticPop
                }
                // His drawn check over it, where it sits, when a win lands
                // and nothing may travel (Reduce Motion, `RingMoment`).
                .overlay {
                    if RingMoment.shared.checkInPlace {
                        // Over the face only: the ring it sits in stays in
                        // view (seen 2026-10-10: the disc under the check
                        // was the crest's whole size and hid the ring).
                        ZStack {
                            Circle().fill(WarmBackground.top)
                                .padding(Self.faceInset)
                            Image("MarkCheck")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(AppColors.inkPrimary)
                                .padding(side * 0.29)
                        }
                        .transition(.opacity)
                    }
                }
                .scaleEffect(swell && !reduceMotion ? 1.1 : 1)
                .contentShape(Circle())
                // Where it is, for the trip it makes when a win lands, and
                // out of sight while it is away on it.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    RingMoment.shared.crestFrame = $0
                    // And where the head goes in and comes out.
                    CompanionParking.shared.dockFrame = $0
                }
                .opacity(RingMoment.shared.lifted ? 0 : 1)
            }
            .buttonStyle(.press)
            .zIndex(1)
            Button { HapticsEngine.lightTap(); openDay() } label: {
                CrestCaption(text: "\(shown)/\(goal)")
                    // A 44pt target round the capsule, as the crew's has.
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    // Away with the ring while it is out (`RingMoment`):
                    // the count is under it there, counting up.
                    .opacity(RingMoment.shared.lifted ? 0 : 1)
            }
            // `.plain`: a scaling press on interactive glass cancels the tap
            // on a phone (`CrewReactions`); the crew's caption is the same.
            .buttonStyle(.plain)
            .zIndex(2)
        }
        .animation(GridConstants.cueIn, value: shown)
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
        .accessibilityHint("Opens your day.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { openDay() }
        .accessibilityActions {
            if canLetOut {
                Button("Let Your Head Out") { letOut() }
            }
        }
    }

    private func pressFace() {
        guard canLetOut else {
            HapticsEngine.lightTap()
            openDay()
            return
        }
        letOut()
    }

    /// **Out onto the tower.** With the tower switch already on he is in
    /// the ring and simply goes. With it off, the press is the switch: on,
    /// which mounts the tower's head layer, with him held in the ring for
    /// the beat it takes to be measured, then out, so he leaves from the
    /// ring rather than appearing wherever the tower would first put him.
    /// Profile's "Let My Head Onto the Tower" reads on after, which is true.
    private func letOut() {
        HapticsEngine.lightTap()
        let heads = HeadStore.shared
        guard !heads.showsOnTower else {
            parking.letOut()
            return
        }
        heads.setShowsOnTower(true)
        parking.parked = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            CompanionParking.shared.letOut()
        }
    }
}

/// **You, in the middle**: the head your crews see (`HeadStore.headForCrews`),
/// so Wins and a crew show the same you; without one, your profile picture.
struct CrestFace: View {
    let side: CGFloat
    /// **Your head is out on the tower** (2026-10-14): your picture or
    /// initial holds the ring, as a crew's bubble shows its faces once its
    /// heads are out. Never the head twice.
    var headIsOut = false

    var body: some View {
        if !headIsOut, let rig = HeadStore.shared.headForCrews {
            LivingHeadView(rig: rig, side: side * ProfileAvatar.headShare, liveliness: .calm)
                .frame(width: side, height: side)
                .accessibilityHidden(true)
        } else {
            ProfileAvatar(side: side, showsHead: !headIsOut)
        }
    }
}
