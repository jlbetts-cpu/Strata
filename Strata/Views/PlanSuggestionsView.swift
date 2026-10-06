import SwiftUI

/// **Suggest, at the foot of the plan.** One quiet word until it is wanted;
/// then three lines, each a box to check, and Others or Done.
///
/// At the bottom because every main thing in the app is: the tower and the
/// calendar stand on the bottom of the screen and fill upward (the owner,
/// 2026-10-03: "i like how all our main elements are near the bottom").
///
/// Checking a box makes it a real plan line at once, in its colour, at its
/// size, with its repeat; unchecking takes it back. Nothing is added that
/// was not checked. No header, no chat: "really minimal and clean... not a
/// crazy amount of information at once".
struct PlanSuggestionsView: View {
    /// What the model is told, given what it has already shown.
    var context: (_ alreadyShown: [String]) -> PlanSuggestionContext
    /// Adds a suggestion to the plan; returns the new line's id.
    var keep: (PlanSuggestion) -> UUID
    /// Takes a kept suggestion back off the plan.
    var unkeep: (UUID) -> Void
    var suggester: PlanSuggester = PlanSuggestions.suggester
    /// The idle word shows only while the keyboard is up (the owner,
    /// 2026-10-06: "the suggest should only pop up when the keyboard does").
    /// Suggestions already asked for stay when it goes down.
    var offersWord = true

    private enum Phase: Equatable {
        case idle, thinking, showing([PlanSuggestion]), failed
    }

    @State private var phase: Phase = .idle
    /// Suggestion to the plan line it became.
    @State private var kept: [UUID: UUID] = [:]
    @State private var shown: [String] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let calendar = Calendar.current
    private static let tapTarget: CGFloat = 44
    private static let bulletInset: CGFloat = (tapTarget - 24) / 2

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch phase {
            case .idle:
                if offersWord {
                    suggestButton.transition(.opacity)
                }
            case .thinking:
                // Three faint rows where the three will land: the page says
                // what is coming and where, rather than a spinner saying only
                // "wait". The model takes a few seconds on the phone. Still,
                // not breathing: nothing in this app loops
                // (`SkeletonBlockView` has the measurement).
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<PlanSuggestionRules.count, id: \.self) { i in placeholder(i) }
                }
                .opacity(0.6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Thinking of suggestions")
                Color.clear.frame(height: Self.tapTarget)
            case .showing(let suggestions):
                ForEach(suggestions) { row($0) }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                footer
            case .failed:
                Text("Couldn't suggest right now.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkTertiary)
                    .frame(maxWidth: .infinity, minHeight: Self.tapTarget)
                footer
            }
        }
        .padding(.bottom, GridConstants.gapTight)
        .task { PlanSuggestions.prewarm() }
        .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: phase)
        .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: offersWord)
    }

    private var suggestButton: some View {
        Button { ask() } label: {
            Label("Suggest", systemImage: "sparkles")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: Self.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityHint("Shows three ideas for today's plan")
    }

    private var footer: some View {
        HStack {
            Button("Others") { ask() }
                .accessibilityHint("Shows three different ideas")
            Spacer()
            // "Hide", not "Done": the sheet's own Done is one line up the
            // screen, and two of them meant two different things.
            Button("Hide") {
                HapticsEngine.lightTap()
                kept = [:]
                shown = []
                phase = .idle
            }
        }
        .font(Typography.headerMedium)
        .foregroundStyle(AppColors.inkSecondary)
        .buttonStyle(.pressWord)
        .frame(minHeight: Self.tapTarget)
        .padding(.horizontal, GridConstants.horizontalPadding)
    }

    private func placeholder(_ i: Int) -> some View {
        HStack(spacing: GridConstants.spacing) {
            RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: 24), style: .continuous)
                .strokeBorder(PlanBullet.outlineInk, lineWidth: PlanBullet.outlineWidth(forSide: 24))
                .frame(width: 24, height: 24)
                .frame(width: Self.tapTarget, height: Self.tapTarget)
            Capsule()
                .fill(AppColors.inkQuiet.opacity(0.35))
                .frame(width: [132, 104, 150][i % 3], height: 10)
            Spacer(minLength: 0)
        }
        .padding(.leading, GridConstants.horizontalPadding - Self.bulletInset)
    }

    private func row(_ suggestion: PlanSuggestion) -> some View {
        let isKept = kept[suggestion.id] != nil
        return Button { toggle(suggestion) } label: {
            HStack(alignment: .center, spacing: GridConstants.spacing) {
                PlanBullet(category: suggestion.category, isDone: isKept, tinted: true)
                    .frame(width: Self.tapTarget, height: Self.tapTarget)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                    if let repeats = PlanItem.repeatSummary(suggestion.repeatDays, calendar: calendar) {
                        Text(repeats)
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, GridConstants.horizontalPadding - Self.bulletInset)
            .padding(.trailing, GridConstants.horizontalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(isKept ? "\(suggestion.title), on your plan" : "Add \(suggestion.title) to your plan")
    }

    private func toggle(_ suggestion: PlanSuggestion) {
        if let line = kept[suggestion.id] {
            HapticsEngine.lightTap()
            unkeep(line)
            kept[suggestion.id] = nil
        } else {
            HapticsEngine.tick()
            kept[suggestion.id] = keep(suggestion)
            // The tick shows, then the row leaves: it is on the plan now, and
            // the same words twice on one screen is the "crazy amount of
            // information" the owner asked not to see. Unchecking in that
            // beat takes it back.
            Task {
                try? await Task.sleep(for: .milliseconds(550))
                guard kept[suggestion.id] != nil, case .showing(let current) = phase else { return }
                let left = current.filter { $0.id != suggestion.id }
                shown.append(suggestion.title)
                phase = left.isEmpty ? .idle : .showing(left)
            }
        }
    }

    private func ask() {
        HapticsEngine.lightTap()
        if case .showing(let current) = phase { shown += current.map(\.title) }
        let context = context(shown)
        phase = .thinking
        Task {
            do {
                let suggestions = try await suggester.suggest(context)
                phase = suggestions.isEmpty ? .failed : .showing(suggestions)
            } catch {
                phase = .failed
            }
        }
    }
}
