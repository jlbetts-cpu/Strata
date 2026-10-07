import SwiftData
import SwiftUI

/// **The crew chat's bar, at the foot of the Plan and the Journal** (the
/// owner, 2026-10-06: "i really like the crew chat like chat section and I
/// think we should use some of the design for the plan and journal tab").
///
/// The same pieces as `CrewChatSheet`'s composer, so the three read as one
/// thing: a page-glass capsule holding the field at the 44pt floor, and the
/// glass ↑ beside it, disabled until there is something to send. An optional
/// leading button (the Journal's pen) sits where a chat keeps its
/// attachment.
///
/// The field is the page's own. The Journal's is the chat's growing
/// `TextField`, where Return is a new line. The Plan's is `PlanTextField`,
/// the same UIKit field its lines use: Return sends there and the keyboard
/// never leaves, which a SwiftUI field cannot promise (its `onSubmit` lets
/// go of the keyboard and catches it a beat later, and resetting its text
/// mid-edit left the old line in it to be sent again: "Wate the plants",
/// measured on the simulator).
struct DayComposer<Field: View, Leading: View>: View {
    let canSend: Bool
    var onSend: () -> Void
    @ViewBuilder var field: () -> Field
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(alignment: .bottom, spacing: GridConstants.gapTight) {
            leading()
            field()
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkPrimary)
                .padding(.horizontal, GridConstants.gapLabel)
                .padding(.vertical, GridConstants.gapTight)
                .frame(minHeight: GlassIconButton.defaultSide)
                .glassCapsule(onPage: true, interactive: false)
            GlassIconButton(systemName: "arrow.up", onPage: true, accessibilityLabel: "Send") { onSend() }
                .disabled(!canSend)
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.vertical, GridConstants.gapTight)
    }
}

extension DayComposer where Leading == EmptyView {
    init(canSend: Bool, onSend: @escaping () -> Void, @ViewBuilder field: @escaping () -> Field) {
        self.init(canSend: canSend, onSend: onSend, field: field, leading: { EmptyView() })
    }
}

/// What a send does to the page, apart from the views so it can be tested.
enum DayComposing {
    /// The Journal: what was sent becomes the note's next paragraph. The
    /// note is never rewritten, only added to.
    static func appending(_ paragraph: String, to note: String) -> String {
        let words = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return note }
        var kept = note
        while let last = kept.last, last.isWhitespace { kept.removeLast() }
        return kept.isEmpty ? words : kept + "\n\n" + words
    }

    static func hasWords(_ draft: String) -> Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The Plan: what was sent becomes a line at the end of the plan, in the
    /// colour the tower has least of, as a line started by tapping below the
    /// last one is (`PlanLines.addLine`).
    /// **Do It Too** (2026-10-06, the retention pass the owner approved: "the
    /// ritual of winning together"): a friend's win, put on your own plan in
    /// its colour and size, so seeing what they did turns into doing it.
    /// Nothing is sent: they never learn you copied it.
    @discardableResult
    static func doItToo(_ title: String, colour: HabitCategory, size: BlockSize,
                        context: ModelContext) -> PlanItem? {
        let words = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return nil }
        let all = (try? context.fetch(FetchDescriptor<PlanItem>())) ?? []
        if let already = onPlan(words, in: all) { return already }
        let line = PlanItem(text: words, order: (all.map(\.order).max() ?? -1) + 1, category: colour)
        line.sizeRaw = size.rawValue
        context.insert(line)
        try? context.save()
        return line
    }

    /// The same words already waiting on the plan, not yet done.
    static func onPlan(_ title: String, in all: [PlanItem]) -> PlanItem? {
        let words = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return all.first { $0.completedAt == nil && $0.text.compare(words, options: .caseInsensitive) == .orderedSame }
    }

    @discardableResult
    static func addPlanLine(_ text: String, after all: [PlanItem], habits: [Habit],
                            context: ModelContext) -> PlanItem? {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return nil }
        let line = PlanItem(text: words, order: (all.map(\.order).max() ?? -1) + 1,
                            category: QuickWinService.spontaneousCategory(existing: habits))
        context.insert(line)
        try? context.save()
        return line
    }
}
