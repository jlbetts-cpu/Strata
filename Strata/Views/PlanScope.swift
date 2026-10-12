import SwiftUI

/// **Which part of the plan is on the page** (2026-10-10, planning ahead:
/// "let users plan wins ahead, today or days/a week out ... evolve it into
/// the place that shows all of a user's plans across days, including
/// recurring/repeating ones").
///
/// A day, today through six days on, or the lines that repeat. One row of
/// plain words chooses it, and what is typed in the bar goes to whatever is
/// chosen: "Tomorrow", three lines, Done, and tomorrow is planned. No date
/// picker and no times: a plan here is a day and some words (the research:
/// every per-line field a planner adds is a decision at the moment of
/// writing, and Ellie's "no dates, no decisions" is why its list is fast).
enum PlanScope: Hashable {
    /// Days from today: 0 is today.
    case day(Int)
    case repeating

    /// Today through the same weekday next week, then the repeating lines.
    static let all: [PlanScope] = (0...6).map(PlanScope.day) + [.repeating]

    func date(from today: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard case .day(let offset) = self else { return nil }
        return calendar.date(byAdding: .day, value: offset, to: today)
    }

    /// The word in the row: Today, Tomorrow, then the day's short name.
    func title(from today: Date = Date(), calendar: Calendar = .current) -> String {
        switch self {
        case .repeating: return "Repeating"
        case .day(0): return "Today"
        case .day(1): return "Tomorrow"
        case .day:
            guard let date = date(from: today, calendar: calendar) else { return "" }
            return calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        }
    }

    /// The word read aloud: the day's whole name, not "Mon".
    func spokenTitle(from today: Date = Date(), calendar: Calendar = .current) -> String {
        guard case .day(let offset) = self, offset > 1, let date = date(from: today, calendar: calendar) else {
            return title(from: today, calendar: calendar)
        }
        return calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1]
    }

    /// What the field you write a plan in says, in the plan sheet's bar and
    /// under the add sheet's title alike.
    func prompt(from today: Date = Date(), calendar: Calendar = .current) -> String {
        self == .repeating ? "Plan something that repeats" : "Plan \(spoken(from: today, calendar: calendar))"
    }

    /// The same, in a sentence: "for today", "for tomorrow", "for Monday".
    func spoken(from today: Date = Date(), calendar: Calendar = .current) -> String {
        switch self {
        case .repeating: return "that repeat"
        case .day(0): return "for today"
        case .day(1): return "for tomorrow"
        case .day:
            guard let date = date(from: today, calendar: calendar) else { return "" }
            return "for " + calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1]
        }
    }

    /// The weekdays a line written under Repeating comes back on: all of
    /// them. Fewer is chosen where the line is written (`WeekdayChips`).
    static let everyDay: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    /// The days alone, for choosing a line's day.
    static let days: [PlanScope] = (0...6).map(PlanScope.day)

    /// The scope a day falls in, when it is one of the seven on the row.
    static func of(day: String?, today: Date = Date(), calendar: Calendar = .current) -> PlanScope? {
        guard let day else { return nil }
        return days.first { $0.date(from: today, calendar: calendar).map(DateUtils.dateString(from:)) == day }
    }

    /// The lines this scope shows.
    func lines(_ all: [PlanItem], today: Date = Date(), calendar: Calendar = .current) -> [PlanItem] {
        switch self {
        case .repeating:
            return all.filter(\.repeats)
        case .day(let offset):
            guard let date = date(from: today, calendar: calendar) else { return [] }
            return all.filter {
                $0.belongs(on: date, calendar: calendar, today: today)
                    && !(offset == 0 && PlanSkips.isSkipped($0, on: date) && $0.completedAt == nil)
            }
        }
    }

    /// One-offs whose day went by, shown under today's lines and nowhere
    /// else (`PlanItem.isEarlier`).
    static func earlier(_ all: [PlanItem], today: Date = Date()) -> [PlanItem] {
        all.filter { $0.isEarlier(than: today) && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

/// The row of days over the plan: plain words, the chosen one in ink, as the
/// sheet's own Plan and Journal are (`DaySheet.tabWord`), a size down.
struct PlanScopeRow: View {
    @Binding var scope: PlanScope
    /// The words offered: every day and Repeating, or the days alone where
    /// only a day is being chosen (a line's own sheet).
    var choices: [PlanScope] = PlanScope.all
    /// The page's margin either side, or none inside a form's own row.
    var margin: CGFloat = GridConstants.horizontalPadding - GridConstants.gapTight
    /// How many open lines each scope holds, so a day with something
    /// planned can say so with a dot, never a number.
    var planned: (PlanScope) -> Bool = { _ in false }

    /// The days, which scroll. Repeating is not one of them.
    private var days: [PlanScope] { choices.filter { $0 != .repeating } }

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(days, id: \.self) { item in
                            word(item).id(item)
                        }
                    }
                    .padding(.horizontal, margin)
                }
                .moreToTheRight()
                // **Opened on the chosen day.** A line set for Saturday
                // opened its sheet with the row at Today and nothing on it
                // in ink: the chosen word was off the right edge.
                .onAppear { proxy.scrollTo(scope, anchor: .center) }
                .onChange(of: scope) { _, now in
                    withAnimation(GridConstants.motionSnappy) { proxy.scrollTo(now, anchor: .center) }
                }
            }
            // **Repeating stands still at the end of the row** (the flows
            // pass, 2026-10-11). It was the eighth word, off the right edge
            // of a row that scrolls, so the way to make a plan repeat could
            // not be seen without knowing to look for it.
            if choices.contains(.repeating) { repeating }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Which day")
    }

    private var repeating: some View {
        let chosen = scope == .repeating
        return Button {
            guard !chosen else { return }
            HapticsEngine.tick()
            withAnimation(GridConstants.crossFade) { scope = .repeating }
        } label: {
            Image(systemName: "repeat")
                .font(Typography.headerSmall)
                .foregroundStyle(chosen ? AppColors.inkPrimary : AppColors.inkTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .padding(.trailing, max(0, margin - GridConstants.gapTight))
        .accessibilityLabel("Repeating")
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
    }

    private func word(_ item: PlanScope) -> some View {
        let chosen = item == scope
        return Button {
            guard item != scope else { return }
            HapticsEngine.tick()
            withAnimation(GridConstants.crossFade) { scope = item }
        } label: {
            VStack(spacing: 2) {
                Text(item.title())
                    .font(Typography.headerSmall)
                    .foregroundStyle(chosen ? AppColors.inkPrimary : AppColors.inkTertiary)
                // Something is planned there: a dot, in the word's own ink.
                Circle()
                    .fill(chosen ? AppColors.inkPrimary : AppColors.inkTertiary)
                    .frame(width: 4, height: 4)
                    .opacity(planned(item) ? 1 : 0)
            }
            .padding(.horizontal, GridConstants.gapTight)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .accessibilityLabel(item.spokenTitle())
        .accessibilityValue(planned(item) ? "Has plans" : "")
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
        .animation(GridConstants.crossFade, value: chosen)
    }
}

// MARK: - Which days a repeating line comes back on

/// **The days, where the line is written** (the owner, 2026-10-11: "what if
/// you want to select something that repeats on monday wednesday friday
/// there is no option for that"). There was one, three presses deep: write
/// the line, open its sheet, switch Repeats on, then the days. Under
/// Repeating every new line simply came back every day.
///
/// Seven letters under the row of days, whenever Repeating is chosen, in the
/// plan and in the add sheet. All on to begin with (every day); press the
/// ones it is not for. What is chosen stays for the next line, so three
/// lines for Monday, Wednesday and Friday are set once.
///
/// **Quiet, in both appearances.** A line has no colour of its own when it
/// is written, so the chip cannot take one as the line's own sheet does.
/// The first build filled a chosen day in solid ink: seven black squares
/// under the name in light, and seven WHITE ones in dark, against the
/// owner's "light on light, dark on dark" (only the primary button is white
/// in dark mode). A chosen day is the chat's chosen reaction instead
/// (`ChatReactions`): a tint of the page's ink with the letter in ink. A day
/// that is off has no fill, a hairline, and the letter in grey.
///
/// **One chip, in all three places** (the owner, 2026-10-11: "make sure
/// that's consistent ... in the pop up sheet the M-S looks circle while it
/// looks square"). A line's own sheet drew its seven days itself, from a
/// copy of these numbers: narrower in its form row, on a filled well, and so
/// rounder to the eye than the ones under the name. It draws these now. The
/// chip is SQUARE, with a block's own corner at its size, as the plan's box
/// is: what stands for a block is block-shaped.
///
/// There a line has a colour, and the chosen days wear it (`tint`): the
/// colour pressed above is the colour of what comes back.
struct WeekdayChips: View {
    @Binding var days: Set<Int>
    /// The line's own colour, where it has one. Nil is the page's ink.
    var tint: Color? = nil
    private let calendar = Calendar.current
    /// Monday first, as the line's sheet has them.
    private let order = [2, 3, 4, 5, 6, 7, 1]

    private static let side: CGFloat = 44
    private static let shape = RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: 44), style: .continuous)

    var body: some View {
        HStack(spacing: GridConstants.spacing) {
            ForEach(order, id: \.self) { day in chip(day) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Which days")
        .accessibilityValue(PlanItem.repeatSummary(days, calendar: calendar) ?? "")
    }

    private func chip(_ day: Int) -> some View {
        let on = days.contains(day)
        return Button {
            // Never none: a line that repeats on no day is not a line.
            if on, days.count == 1 {
                HapticsEngine.warning()
                return
            }
            HapticsEngine.lightTap()
            withAnimation(GridConstants.motionSnappy) {
                if on { days.remove(day) } else { days.insert(day) }
            }
        } label: {
            Text(calendar.veryShortWeekdaySymbols[day - 1])
                .font(Typography.sectionLabel)
                .foregroundStyle(on ? (tint == nil ? AppColors.inkPrimary : .white) : AppColors.inkTertiary)
                // Square at every width: 44 where there is room, and the
                // same share of a narrower row both ways, never 41 by 44.
                .frame(maxWidth: Self.side, maxHeight: Self.side)
                .aspectRatio(1, contentMode: .fit)
                // **No ground of its own under a day that is off.** For an
                // hour each chip was backed with the page's colour, so a
                // long list scrolling behind the plan's bar could not show
                // through one. The plan's sheet is not that colour: the off
                // days stood out as white keys, brighter than the chosen
                // ones, which is the wrong way round (seen 2026-10-11).
                .background { Self.shape.fill(on ? (tint ?? AppColors.chosenFill) : .clear) }
                .overlay {
                    Self.shape.strokeBorder(on ? .clear : GridConstants.fillHairline, lineWidth: GridConstants.strokeThin)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        // "Every Monday": the row of days above has a plain "Monday" of its
        // own, and the two must not be one name.
        .accessibilityLabel("Every \(calendar.weekdaySymbols[day - 1])")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - When, in the add sheet

/// **Now, or later** (the owner, 2026-10-10: "the add sheet gains an
/// optional way to schedule/plan a win for later, while keeping the existing
/// add-a-past-win flow ... minimal and fully optional. Making a win must be
/// fast").
///
/// One quiet word under the name, "Now". Nothing else is on the sheet until
/// it is pressed, so adding a win is as it was. Pressed, it opens the same
/// row of days the plan has, with Now first: choose a day and the sheet is
/// for writing plans, a line a Return; choose Now and it is for a win again.
struct WhenRow: View {
    /// Nil is now: a win. Otherwise the plan it is for.
    @Binding var when: PlanScope?
    @State private var open = false

    /// Now, later today, the days ahead, and the lines that repeat.
    private var choices: [PlanScope?] { [nil] + PlanScope.all }

    static func title(_ item: PlanScope?) -> String {
        switch item {
        case nil: "Now"
        case .day(0): "Later"
        case let scope?: scope.title()
        }
    }

    var body: some View {
        Group {
            if open || when != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(choices, id: \.self) { item in word(item) }
                    }
                    .padding(.trailing, GridConstants.gapWide)
                }
                .moreToTheRight()
                .transition(.opacity)
            } else {
                Button {
                    // Opening the row is a light tap; choosing on it ticks.
                    HapticsEngine.lightTap()
                    withAnimation(GridConstants.crossFade) { open = true }
                } label: {
                    HStack(spacing: 4) {
                        // **It says what it does, on a chip** (the flows
                        // pass, 2026-10-11). It was the word "Now" in the
                        // caption grey with a small chevron, which read as
                        // a label for the field above it; nobody pressed
                        // it. The chip is the one the row of ideas over the
                        // keyboard is made of, so it is a thing to press.
                        Text("Plan for Later")
                            .font(Typography.headerSmall)
                        Image(systemName: "chevron.down")
                            .iconSize(GridConstants.iconChevron, relativeTo: .caption2, weight: .semibold)
                    }
                    .foregroundStyle(AppColors.inkSecondary)
                    .padding(.horizontal, GridConstants.gapItem)
                    .frame(height: 34)
                    .background(Capsule(style: .continuous).fill(AppColors.quietFill))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressWord)
                .accessibilityLabel("Plan for later")
                .accessibilityHint("Choose a day, and the plan opens on it.")
                .transition(.opacity)
            }
        }
        // The first word starts on the page's margin, as the name does.
        .padding(.leading, open || when != nil ? -GridConstants.gapTight : 0)
    }

    private func word(_ item: PlanScope?) -> some View {
        let chosen = item == when
        return Button {
            HapticsEngine.tick()
            withAnimation(GridConstants.crossFade) {
                when = item
                if item == nil { open = false }
            }
        } label: {
            Text(Self.title(item))
                .font(Typography.headerSmall)
                .foregroundStyle(chosen ? AppColors.inkPrimary : AppColors.inkTertiary)
                .padding(.horizontal, GridConstants.gapTight)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .accessibilityLabel(item.map { $0 == .day(0) ? "Later today" : $0.spokenTitle() } ?? "Now")
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
        .animation(GridConstants.crossFade, value: chosen)
    }
}

/// The lines planned from the add sheet in this sitting, as the plan shows
/// them: the empty box and the words.
struct PlannedHereList: View {
    let lines: [String]
    /// When each comes back ("Mon Wed Fri"), for a repeating line: the
    /// chips can change between one line and the next, and each line says
    /// what it was given, as it does in the plan.
    var notes: [String?] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: GridConstants.spacing) {
                    PlanBullet(category: .unlabeled, isDone: false)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line)
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if notes.indices.contains(index), let note = notes[index] {
                            Text(note)
                                .font(Typography.screenSubtitle)
                                .foregroundStyle(AppColors.inkTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                // The plan's own row pitch (`PlanLines`), so a line reads
                // the same height in both sheets.
                .padding(.vertical, GridConstants.spacing)
                .padding(.leading, -PlanLines.bulletInset)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Planned: " + lines.enumerated().map { index, line in
            notes.indices.contains(index) ? [line, notes[index]].compactMap { $0 }.joined(separator: " ") : line
        }.joined(separator: ", "))
        .accessibilityHidden(lines.isEmpty)
    }
}

private extension View {
    /// **A row that runs on past the edge fades into it**, so the last word
    /// in view is not cut in half and the row says there is more (seen
    /// 2026-10-10: "Repeating" stood at the screen's edge as an "R").
    func moreToTheRight() -> some View {
        mask {
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.9),
                                   .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
    }
}
