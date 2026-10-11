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

    /// The same, in a sentence: "for today", "for tomorrow", "for Monday".
    func spoken(from today: Date = Date(), calendar: Calendar = .current) -> String {
        switch self {
        case .repeating: return "that come back"
        case .day(0): return "for today"
        case .day(1): return "for tomorrow"
        case .day:
            guard let date = date(from: today, calendar: calendar) else { return "" }
            return "for " + calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1]
        }
    }

    /// The weekdays a line written under Repeating comes back on: all of
    /// them. Fewer is one press away, on the line (`PlanItemDetailSheet`).
    static let everyDay: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    /// The lines this scope shows.
    func lines(_ all: [PlanItem], today: Date = Date(), calendar: Calendar = .current) -> [PlanItem] {
        switch self {
        case .repeating:
            return all.filter(\.repeats)
        case .day(let offset):
            guard let date = date(from: today, calendar: calendar) else { return [] }
            return all.filter {
                $0.belongs(on: date, calendar: calendar, today: today)
                    && !(offset == 0 && PlanSkips.isSkipped($0.id, on: date) && $0.completedAt == nil)
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
    /// How many open lines each scope holds, so a day with something
    /// planned can say so with a dot, never a number.
    var planned: (PlanScope) -> Bool = { _ in false }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(PlanScope.all, id: \.self) { item in
                        word(item).id(item)
                    }
                }
                .padding(.horizontal, GridConstants.horizontalPadding - GridConstants.gapTight)
            }
            .onChange(of: scope) { _, now in
                withAnimation(GridConstants.motionSnappy) { proxy.scrollTo(now, anchor: .center) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Which day")
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
        .accessibilityLabel(item.title())
        .accessibilityValue(planned(item) ? "Has plans" : "")
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
        .animation(GridConstants.crossFade, value: chosen)
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
                }
                .transition(.opacity)
            } else {
                Button {
                    HapticsEngine.tick()
                    withAnimation(GridConstants.crossFade) { open = true }
                } label: {
                    HStack(spacing: 4) {
                        Text("Now")
                            .font(Typography.headerSmall)
                        Image(systemName: "chevron.down")
                            .iconSize(GridConstants.iconChevron, relativeTo: .caption2, weight: .semibold)
                    }
                    .foregroundStyle(AppColors.inkTertiary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressWord)
                .accessibilityLabel("When: now")
                .accessibilityHint("Plan it for later instead.")
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
        .accessibilityLabel(Self.title(item))
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
        .animation(GridConstants.crossFade, value: chosen)
    }
}

/// The lines planned from the add sheet in this sitting, as the plan shows
/// them: the empty box and the words.
struct PlannedHereList: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: GridConstants.spacing) {
                    PlanBullet(category: .unlabeled, isDone: false)
                        .frame(width: 44, height: 44)
                    Text(line)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.leading, -10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Planned: " + lines.joined(separator: ", "))
    }
}
