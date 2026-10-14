import Observation
import SwiftUI

// MARK: - The ring's moment

/// **A win lands, and the ring comes forward to take it** (the owner,
/// 2026-10-10: the ring "stays a small pill at the top and progress is
/// barely noticeable ... when a win is completed, animate the ring large on
/// screen: zoom in so the user visually sees the ring filling up, perhaps a
/// checkmark beat, then zoom back to its spot ... same spirit as the
/// existing confetti, but a smaller everyday moment. Keep it calm and
/// minimal, not loud").
///
/// The crest itself makes the trip, not a second ring: it lifts out of its
/// place in the header, grows to the middle of the screen, the segment the
/// win earned is drawn round it, your face gives way to his drawn check for
/// a beat, the fraction counts up, and it goes home. About two seconds, and
/// nothing has to be pressed: touches go straight through it to the tower.
///
/// **What it is not.** Not the goal's celebration: that is the tower's
/// dance and the confetti, once a day, and it still follows when this win
/// was the one that reached the goal. Not a second cue either: it says
/// nothing and asks nothing.
///
/// With Reduce Motion nothing travels: the check fades in over the crest
/// where it sits, and out.
@MainActor
@Observable
final class RingMoment {
    static let shared = RingMoment()

    /// Where the crest's glass circle is, in the window.
    var crestFrame: CGRect = .zero
    /// The crest is out of its place: the header's own is hidden.
    private(set) var lifted = false
    /// The stages, for the layer that draws them.
    private(set) var grown = false
    private(set) var filled = false
    /// The count before the win, and after.
    private(set) var from = 0
    private(set) var to = 0
    private(set) var goal = 1
    /// The crest in its place, with the check over it (Reduce Motion).
    private(set) var checkInPlace = false
    /// **The count the header shows until the ring has taken the win**
    /// (found by review): the header had the new segment and the new
    /// fraction for the best part of a second, and then the ring came out
    /// showing the old ones and filled them again. Held at the old count
    /// from the moment a win is accepted until the segment is drawn.
    private(set) var holding: Int?

    @ObservationIgnored private var playing: Task<Void, Never>?
    /// One is waiting on the block or under way: the goal's dance waits for
    /// it (`MainAppView.celebrateGoalIfDue`), so the two are never on
    /// screen at once.
    var isPlaying: Bool { playing != nil }

    /// The beats, in seconds, after the wait for the block.
    static let growsFor = 0.42
    static let sweepsFor = 0.34
    static let settlesFor = 0.16
    static let returnsFor = 0.44
    /// From the press to home again.
    static var whole: Double {
        GridConstants.ringWaitsForBlock + growsFor + sweepsFor + settlesFor + GridConstants.ringHold + returnsFor
    }

    /// A win was logged: `from` wins became `to`. Nothing plays for a count
    /// that fell, for the first count of a launch, or while one is playing
    /// (a second win in the same two seconds simply shows in the count).
    func play(from: Int, to: Int, goal: Int, reduceMotion: Bool) {
        guard to > from, playing == nil, crestFrame.width > 0 else { return }
        self.from = from
        self.to = to
        self.goal = max(1, goal)
        holding = from
        playing = Task { [weak self] in
            /// Waits, and says whether the moment is still wanted: a
            /// cancelled one must not go on to tap or to move anything
            /// (found by review: only the first wait was checked).
            func wait(_ seconds: Double) async -> Bool {
                try? await Task.sleep(for: .seconds(seconds))
                return !Task.isCancelled
            }
            guard await wait(GridConstants.ringWaitsForBlock), let self else { return }
            if reduceMotion {
                withAnimation(GridConstants.crossFade) { self.checkInPlace = true }
                self.holding = nil
                HapticsEngine.tick()
                guard await wait(GridConstants.ringHold + 0.4) else { return }
                withAnimation(GridConstants.crossFade) { self.checkInPlace = false }
                self.playing = nil
                return
            }
            self.lifted = true
            withAnimation(GridConstants.ringLift) { self.grown = true }
            guard await wait(Self.growsFor) else { return }
            withAnimation(GridConstants.ringSweep) { self.filled = true }
            self.holding = nil
            // The tap lands as the segment closes, with the check.
            guard await wait(Self.sweepsFor) else { return }
            HapticsEngine.tick()
            guard await wait(Self.settlesFor + GridConstants.ringHold) else { return }
            withAnimation(GridConstants.ringReturn) { self.grown = false }
            guard await wait(Self.returnsFor) else { return }
            self.lifted = false
            self.filled = false
            self.playing = nil
        }
    }

    /// Stopped where it is: the screen it was over has gone, or the win
    /// was taken back.
    func cancel() {
        playing?.cancel()
        playing = nil
        lifted = false
        grown = false
        filled = false
        checkInPlace = false
        holding = nil
    }
}

/// **When the ring's moment plays**, as a rule that can be tested without a
/// screen (found by review: the first version lived in a view modifier and
/// had four faults nothing tested). Fed the day's count and whether the
/// tower is in view with nothing over it.
nonisolated struct RingTrigger: Equatable {
    enum Action: Equatable {
        case none
        case play(from: Int, to: Int)
        case cancel
    }

    /// A win logged while something was over the tower, and when.
    private(set) var waiting: (from: Int, to: Int, at: Date)?
    /// How long a win waits for the tower to come back into view. Long
    /// enough for the add sheet to leave; past it the moment has gone, and
    /// the count is simply the count (a win from the widget, one brought by
    /// iCloud, a backup restored on another tab).
    static let keeps: TimeInterval = 6

    static func == (a: RingTrigger, b: RingTrigger) -> Bool {
        a.waiting?.from == b.waiting?.from && a.waiting?.to == b.waiting?.to && a.waiting?.at == b.waiting?.at
    }

    mutating func counted(old: Int, new: Int, isClear: Bool, now: Date = Date()) -> Action {
        // **A win taken back takes the moment with it** (found by review:
        // Undo inside the wait still played the ring up to a count the
        // header no longer had).
        guard new > old else {
            waiting = nil
            return new < old ? .cancel : .none
        }
        let from = waiting.map { now.timeIntervalSince($0.at) < Self.keeps ? $0.from : old } ?? old
        if isClear {
            waiting = nil
            return .play(from: from, to: new)
        }
        waiting = (from, new, waiting?.at ?? now)
        return .none
    }

    mutating func cleared(_ isClear: Bool, now: Date = Date()) -> Action {
        guard isClear else { return .cancel }
        guard let due = waiting else { return .none }
        waiting = nil
        guard now.timeIntervalSince(due.at) < Self.keeps else { return .none }
        return .play(from: due.from, to: due.to)
    }
}

/// The ring with the newest segment drawn round as `progress` goes 0 to 1.
/// The same ink, track and gaps as `GoalRingStroke`.
private struct RingSweep: View {
    let from: Int
    let to: Int
    let goal: Int
    let line: CGFloat
    var progress: Double

    private static let gap = 0.018
    private var segments: Int { max(1, max(goal, to)) }

    var body: some View {
        ZStack {
            ForEach(0..<segments, id: \.self) { i in
                let span = 1.0 / Double(segments)
                let start = Double(i) * span + Self.gap
                let end = Double(i + 1) * span - Self.gap
                // The track, under everything.
                Circle()
                    .trim(from: start, to: end)
                    .stroke(AppColors.inkPrimary.opacity(0.08), style: StrokeStyle(lineWidth: line, lineCap: .round))
                if i < from {
                    Circle()
                        .trim(from: start, to: end)
                        .stroke(AppColors.inkPrimary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                } else if i < to {
                    // What this win earned, drawn round.
                    Circle()
                        .trim(from: start, to: start + (end - start) * progress)
                        .stroke(AppColors.inkPrimary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                        .opacity(progress > 0 ? 1 : 0)
                }
            }
        }
        .rotationEffect(.degrees(-90))
        .accessibilityHidden(true)
    }
}

/// The crest on its trip, over the page. Touches pass through.
struct GoalRingMomentLayer: View {
    private var moment: RingMoment { RingMoment.shared }

    /// How big it grows: most of a small phone's width, never the whole.
    private func grownSide(in size: CGSize) -> CGFloat { min(220, size.width * 0.56) }

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let home = moment.crestFrame.offsetBy(dx: -origin.x, dy: -origin.y)
            let big = grownSide(in: geo.size)
            // A little above the middle: over the tower's open air, clear of
            // the block that has just landed at its foot.
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.4)
            let side = moment.grown ? big : home.width
            let at = moment.grown ? centre : CGPoint(x: home.midX, y: home.midY)
            if moment.lifted, home.width > 0 {
                crest(side: side, big: big)
                    .position(at)
                    .transition(.identity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The crest at `side`: the glass, the ring, the face or the check, and
    /// the fraction under it once it has grown.
    private func crest(side: CGFloat, big: CGFloat) -> some View {
        // Everything is a share of the side, so it is one object at any size.
        let line = max(4, side * 4 / 60)
        return ZStack {
            RingSweep(from: moment.from, to: moment.to, goal: moment.goal, line: line,
                      progress: moment.filled ? 1 : 0)
                .padding(line / 2 + side * 2 / 60)
            ZStack {
                CrestFace(side: side - 2 * (line + side * 6 / 60), headIsOut: GoalCrest.headIsOut)
                    .opacity(moment.filled ? 0 : 1)
                    .scaleEffect(moment.filled ? 0.86 : 1)
                // His drawn check, in ink: done.
                Image("MarkCheck")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppColors.inkPrimary)
                    .frame(width: side * 0.42, height: side * 0.42)
                    .opacity(moment.filled ? 1 : 0)
                    .scaleEffect(moment.filled ? 1 : 0.6)
            }
            .animation(GridConstants.ringCheck.delay(moment.filled ? 0.3 : 0), value: moment.filled)
        }
        .frame(width: side, height: side)
        .stillGlassCircle()
        .overlay(alignment: .bottom) {
            // The count, under it, as the caption is at home: only while
            // it is out, and counted up as the segment closes.
            CrestCaption(text: "\(moment.filled ? moment.to : moment.from)/\(moment.goal)")
                .scaleEffect(1.25)
                .fixedSize()
                .offset(y: 54)
                .opacity(moment.grown ? 1 : 0)
                .animation(GridConstants.ringSweep.delay(moment.filled ? 0.3 : 0), value: moment.filled)
        }
    }
}

/// Watches the day's wins and starts the moment; the layer rides over the
/// content. One modifier, so `MainAppView`'s body takes one more line.
struct GoalRingMomentWatch: ViewModifier {
    let wins: Int
    let goal: Int
    /// Wins is the screen in front and nothing else is over it.
    let isClear: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trigger = RingTrigger()

    func body(content: Content) -> some View {
        content
            .overlay { GoalRingMomentLayer().ignoresSafeArea() }
            .onChange(of: wins) { old, new in
                // The first count of a launch is the count, not a win.
                guard LaunchMoment.shared.finished else { return }
                act(trigger.counted(old: old, new: new, isClear: isClear))
            }
            .onChange(of: isClear) { _, clear in act(trigger.cleared(clear)) }
    }

    private func act(_ action: RingTrigger.Action) {
        switch action {
        case .none: break
        case .cancel: RingMoment.shared.cancel()
        case .play(let from, let to):
            RingMoment.shared.play(from: from, to: to, goal: goal, reduceMotion: reduceMotion)
        }
    }
}
