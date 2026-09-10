import SwiftUI

/// The first two minutes.
///
/// **Not a funnel.** The published onboarding frameworks all describe the same
/// fourteen screens — welcome, goal question, pain points, social proof, pain
/// amplification, comparison table, permission priming, processing moment,
/// account, paywall — and they exist to convert a subscription. Strata has no
/// account, no subscription and nothing to convert; it is a personal record
/// that lives on one phone. Running that structure here would produce exactly
/// what the owner said his previous attempts produced: something that looks
/// like every other app's onboarding and nothing like this one.
///
/// Two things are worth taking from those frameworks and both are here. The
/// first is that **the interactive demo is the hardest and most important
/// screen**, and that it must be built from the app's real components rather
/// than mocked — so step three is the actual `NextSlotButton`, driving the
/// actual `BlockSizeDraw` maths, dropping actual `BlockSurface` blocks. What
/// you learn here is the app, not a picture of it. The second is the copy
/// rule: write like a person, second person, and let the button say what
/// happens next.
///
/// **Everything else comes from this app's own system.** `WarmBackground` is
/// the ground, the letterforms are the owner's, the fall is
/// `GridConstants.dropGravity` on `dropFallCurve` — the same constant
/// acceleration the tower uses, because the whole point of the first screen is
/// that you have already seen the app work by the time you reach the second.
///
/// There are three steps and no progress dots. Dots are chrome that count
/// chrome; the steps are short enough that nobody needs a map of them.
struct OnboardingView: View {

    /// Called when the last step is finished, or skipped.
    var onFinish: () -> Void

    @State private var step = 0
    #if DEBUG
    /// Which page to open on, so each one can be photographed — nothing here
    /// can tap the simulator.
    private static let debugStep = DebugHarness.onboardingStep
    #endif
    @State private var landed = 0
    /// What the tutorial has actually seen the finger do.
    @State private var hasTapped = false
    @State private var hasDrawn = false
    @State private var drawnSize: BlockSize = .small
    @State private var madeBlocks: [BlockSize] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cell: CGFloat = 72

    var body: some View {
        ZStack {
            WarmBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                stage
                Spacer(minLength: 0)
                words
                actions
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.bottom, GridConstants.gapSection)
        }
        .task {
            #if DEBUG
            if let start = Self.debugStep { step = start }
            #endif
            await runFall()
        }
    }

    // MARK: - The mark

    private var header: some View {
        VStack(spacing: GridConstants.gapItem) {
            StrataMark(side: 64)
            StrataWordmark(size: Typography.screenTitleCap,
                           color: .primary.opacity(0.85))
        }
        .padding(.top, GridConstants.gapSection)
        .opacity(step == 0 ? 1 : 0)
        .frame(height: step == 0 ? nil : 0)
        .animation(GridConstants.gentleReveal, value: step)
    }

    // MARK: - The stage

    /// What the step is about, shown rather than described.
    @ViewBuilder
    private var stage: some View {
        switch step {
        case 0: fallingTower
        case 1: namedBlocks
        case 2: workshop
        default: thanks
        }
    }

    /// Blocks arriving out of nothing, at one gravity.
    ///
    /// This is the app's own fall: `t = sqrt(2d/g)` at
    /// `GridConstants.dropGravity`, on `dropFallCurve`, which is constant
    /// acceleration and does NOT ease out at the end. A falling object does
    /// not decelerate into the ground, and arriving at peak speed is what
    /// makes the landing land.
    private var fallingTower: some View {
        HStack(alignment: .bottom, spacing: GridConstants.spacing) {
            ForEach(Array(Self.opening.enumerated()), id: \.offset) { index, category in
                block(category, size: .small)
                    .offset(y: landed > index ? 0 : -420)
                    .opacity(landed > index ? 1 : 0)
            }
        }
        .frame(height: Self.cell)
    }

    private static let opening: [HabitCategory] = [.health, .mindfulness, .social, .work]

    private func runFall() async {
        guard step == 0, landed == 0 else { return }
        try? await Task.sleep(for: .milliseconds(350))
        for index in Self.opening.indices {
            let fall = GridConstants.dropFallCurve.speed(1 / fallSeconds)
            withAnimation(reduceMotion ? GridConstants.gentleReveal : fall) {
                landed = index + 1
            }
            HapticsEngine.tick()
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 190))
        }
    }

    /// `t = sqrt(2d/g)`, clamped the way the tower clamps it.
    private var fallSeconds: Double {
        let t = (2 * 420 / GridConstants.dropGravity).squareRoot()
        return min(max(Double(t), GridConstants.dropDurationRange.lowerBound),
                   GridConstants.dropDurationRange.upperBound)
    }

    /// Three ordinary things, so "a win" stops being an abstraction.
    private var namedBlocks: some View {
        VStack(alignment: .leading, spacing: GridConstants.spacing) {
            ForEach(Array(Self.examples.enumerated()), id: \.offset) { index, example in
                HStack(spacing: GridConstants.gapItem) {
                    block(example.category, size: .small)
                    Text(example.title)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(.primary.opacity(0.85))
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private static let examples: [(title: String, category: HabitCategory)] = [
        ("Made the bed", .mindfulness),
        ("Sent the email", .work),
        ("Walked to the shop", .health)
    ]

    // MARK: - The tutorial

    /// **The real control.** `NextSlotButton` is the same view the tower uses,
    /// wired to the same `BlockSizeDraw` maths — so pressing it here teaches
    /// the actual gesture rather than a demonstration of one. It hands back
    /// the size it reached, which is how this screen knows whether the second
    /// half of the lesson has actually happened.
    private var workshop: some View {
        VStack(spacing: GridConstants.gapItem) {
            HStack(alignment: .bottom, spacing: GridConstants.spacing) {
                ForEach(Array(madeBlocks.enumerated()), id: \.offset) { _, size in
                    block(.mindfulness, size: size)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(height: Self.cell * 2 + GridConstants.spacing, alignment: .bottom)

            NextSlotButton(
                reduceMotion: reduceMotion,
                cornerRadius: GridConstants.blockCornerRadius(forCell: Self.cell),
                previewCategory: .mindfulness,
                onSizeChanged: { drawnSize = $0 },
                action: { size in
                    withAnimation(GridConstants.dropSettleSpring) {
                        madeBlocks.append(size)
                    }
                    if size == .small { hasTapped = true } else { hasDrawn = true }
                    HapticsEngine.success()
                },
                onOpenMenu: { hasTapped = true }
            )
            .frame(width: Self.cell, height: Self.cell)
        }
    }

    // MARK: - The thank you

    /// The last thing you see before the app.
    ///
    /// **A person, not a brand.** This is the owner's first app and he wanted
    /// to say so himself, so it is written in the first person, it has his
    /// face on it, and it makes one offer rather than three: get in touch. No
    /// rating prompt, no share sheet, no newsletter — asking for something on
    /// the screen where you are thanking somebody turns the thank you into a
    /// transaction.
    ///
    /// It is a page of the onboarding rather than a card floating on one,
    /// because a card would be chrome and CLAUDE.md is clear that a rim, a
    /// frosted band or a blurred edge is a block's claim.
    private var thanks: some View {
        VStack(spacing: GridConstants.gapItem) {
            Image("CreatorPortrait")
                .resizable()
                .scaledToFill()
                .frame(width: 132, height: 132)
                .clipShape(Circle())
                .overlay {
                    // A hairline, not a rim. It stops the photograph's sky
                    // dissolving into a pale page; it is not pretending to be
                    // a block.
                    Circle().strokeBorder(AppColors.inkQuiet.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: .black.opacity(GridConstants.shadowOpacity), radius: 10, y: 4)
                .accessibilityLabel("Jayden, who made Strata")

            Text("Jayden")
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.9))
        }
    }

    /// Where to find him. **Empty until it is filled in**, and the button is
    /// not drawn while it is — shipping a dead link on the screen that asks
    /// somebody to get in touch would be worse than not asking.
    private static let linkedIn = ""

    @ViewBuilder
    private var connectButton: some View {
        if let url = URL(string: Self.linkedIn), !Self.linkedIn.isEmpty {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Connect on LinkedIn")
                }
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    RoundedRectangle(cornerRadius: GridConstants.radiusSurface,
                                     style: .continuous)
                        .fill(AppColors.inkQuiet.opacity(0.14))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Words

    private var words: some View {
        VStack(spacing: GridConstants.gapTight) {
            Text(title)
                .font(Typography.headerLarge)
                .foregroundStyle(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(Typography.bodyMedium)
                .foregroundStyle(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, GridConstants.gapItem)
        .padding(.bottom, GridConstants.gapSection)
        .animation(GridConstants.gentleReveal, value: step)
        .animation(GridConstants.gentleReveal, value: hasTapped)
    }

    private var title: String {
        switch step {
        case 0: return "Everything you did, stacked up"
        case 1: return "A win is anything you finished"
        case 2: return hasTapped ? "Now draw a bigger one" : "Make one"
        default: return "Thank you, genuinely"
        }
    }

    private var subtitle: String {
        switch step {
        case 0:
            return "Strata is a record of what you actually got done. One block for each thing."
        case 1:
            return "It doesn't have to be impressive. If you did it, it counts."
        case 2:
            return hasTapped
                ? "Press and hold, then pull sideways for a wide block or up for a tall one. Let go when it's the size you want."
                : "Press the empty slot. That's the whole thing."
        default:
            return "Strata is the first app I've made, and you're one of the first people to open it. That means a lot. If you find a bug, want something added, or just fancy saying hello, I'd really like to hear from you."
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: GridConstants.gapTight) {
            if step == 3 { connectButton }

            Button {
                HapticsEngine.lightTap()
                advance()
            } label: {
                Text(actionTitle)
                    .font(Typography.headerMedium)
                    // **Inverted, both ways.** A `warmBlack` button with white
                    // type is right on the light page and nearly invisible on
                    // the dark one. `slotInk` is the app's ink and flips, so
                    // the button is always the opposite of the ground it is
                    // standing on — which is the only thing a primary action
                    // has to be.
                    .foregroundStyle(WarmBackground.top)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: GridConstants.radiusSurface,
                                         style: .continuous)
                            .fill(AppColors.slotInk)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.35)
            .animation(GridConstants.gentleReveal, value: canAdvance)

            // A way out that does not pretend to be anything else. Somebody
            // who has used the app before should not have to be taught it
            // again, and hiding the exit is a dark pattern.
            Button("Skip") {
                HapticsEngine.lightTap()
                onFinish()
            }
            .font(Typography.bodySmall)
            .foregroundStyle(AppColors.inkQuiet)
            .opacity(step < 2 ? 1 : 0)
        }
    }

    /// The last step will not let you past until you have actually done both
    /// halves of the gesture. That is the difference between a tutorial and a
    /// slideshow — and it is the one screen where being made to try is the
    /// entire value.
    private var canAdvance: Bool {
        step != 2 || (hasTapped && hasDrawn)
    }

    private var actionTitle: String {
        switch step {
        case 0: return "Show me"
        case 1: return "Let me try"
        case 2: return "One more thing"
        default: return "Start"
        }
    }

    private func advance() {
        guard step < 3 else { onFinish(); return }
        withAnimation(GridConstants.naturalSettle) { step += 1 }
    }

    // MARK: - Drawing

    private func block(_ category: HabitCategory, size: BlockSize) -> some View {
        let gutter = GridConstants.spacing
        let width = Self.cell * CGFloat(size.columnSpan) + gutter * CGFloat(size.columnSpan - 1)
        let height = Self.cell * CGFloat(size.rowSpan) + gutter * CGFloat(size.rowSpan - 1)
        return BlockSurface(
            cornerRadius: GridConstants.blockCornerRadius(forCell: Self.cell),
            scale: Self.cell / GridConstants.blockReferenceCell
        ) {
            category.style.baseColor
        }
        .frame(width: width, height: height)
    }
}
