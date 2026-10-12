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
        if let already = onPlan(words, in: all) {
            // One whose day went by is brought to today: the menu then says
            // it is on your plan, and it is, on today's tower.
            if already.isEarlier() {
                already.day = DateUtils.dateString(from: Date())
                try? context.save()
            }
            return already
        }
        // Today's: seeing what a friend did turns into doing it today, and
        // it stands on your tower as an outline at once.
        let line = PlanItem(text: words, order: (all.map(\.order).max() ?? -1) + 1, category: colour,
                            day: DateUtils.dateString(from: Date()))
        line.sizeRaw = size.rawValue
        context.insert(line)
        try? context.save()
        return line
    }

    /// The same words waiting on TODAY's plan, not yet done today.
    ///
    /// **Today's, in the plan's order** (found by review, 2026-10-11). It was
    /// the first line anywhere with the words and no tick, in whatever order
    /// the store returned them. Since lines got days that was wrong three
    /// ways: logging "Study" today ticked Thursday's "Study" (which then
    /// showed done on a day that had not come, and was cleared off the plan
    /// overnight); a repeating line ticked on an earlier day, in an app that
    /// had stayed open since, could not be found at all; and Do It Too said
    /// a friend's win was planned when the line was for another day.
    ///
    /// After today's, a one-off whose day went by: doing it now is doing it.
    /// Never one for a day still to come.
    static func onPlan(_ title: String, in all: [PlanItem], on now: Date = Date(),
                       calendar: Calendar = .current) -> PlanItem? {
        let words = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // By what the win is called: "Gym" ticks "Gym @ 2" (`PlanTime`).
        let wanted = PlanTime.title(words)
        func same(_ line: PlanItem) -> Bool {
            PlanTime.title(line.text).compare(wanted, options: .caseInsensitive) == .orderedSame
        }
        let ordered = all.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
        return ordered.first { same($0) && $0.isOpen(on: now, calendar: calendar, today: now) }
            ?? ordered.first { same($0) && $0.isEarlier(than: now) }
    }

    @discardableResult
    static func addPlanLine(_ text: String, after all: [PlanItem], habits: [Habit],
                            context: ModelContext, day: Date = Date(), repeatDays: Set<Int> = []) -> PlanItem? {
        addPlanLines(text, after: all, habits: habits, context: context, day: day, repeatDays: repeatDays).last
    }

    /// **As many lines as were written** (2026-10-10, planning as fast as a
    /// note: "essentially dropping a quick bullet list of intended wins").
    /// One line is one plan line. A list pasted or dictated in, one thing a
    /// line, becomes that many, with whatever bullet it wore taken off.
    /// For `day`, or coming back on `repeatDays`.
    @discardableResult
    static func addPlanLines(_ text: String, after all: [PlanItem], habits: [Habit],
                             context: ModelContext, day: Date = Date(), repeatDays: Set<Int> = []) -> [PlanItem] {
        let lines = planLines(in: text)
        guard !lines.isEmpty else { return [] }
        var order = (all.map(\.order).max() ?? -1) + 1
        var made: [PlanItem] = []
        for words in lines {
            let line = PlanItem(text: words, order: order,
                                category: QuickWinService.spontaneousCategory(existing: habits),
                                day: DateUtils.dateString(from: day))
            if !repeatDays.isEmpty { line.repeatDays = repeatDays }
            context.insert(line)
            made.append(line)
            order += 1
        }
        try? context.save()
        return made
    }

    /// What was typed, as lines: split where it breaks, each trimmed, and a
    /// leading "-", "•", "*", "[ ]", "1." or "1)" taken off, since a list
    /// brought from Notes or Reminders arrives wearing them.
    static func planLines(in text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).compactMap { raw in
            var line = raw.trimmingCharacters(in: .whitespaces)
            // The bullet, the hollow bullet and the short dash are written
            // by their numbers: they are marks to take off, not words the
            // app says, and no dash of any length is typed in this source.
            for mark in ["- [ ]", "- [x]", "[ ]", "[x]", "-", "\u{2022}", "*", "\u{25E6}", "\u{2013}"]
            where line.hasPrefix(mark) {
                line = String(line.dropFirst(mark.count)).trimmingCharacters(in: .whitespaces)
                break
            }
            // "1." or "12)" and a space.
            let digits = line.prefix { $0.isNumber }
            if !digits.isEmpty, digits.count <= 2 {
                let rest = line.dropFirst(digits.count)
                if let first = rest.first, first == "." || first == ")", rest.dropFirst().first == " " {
                    line = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
            }
            return line.isEmpty ? nil : line
        }
    }
}
