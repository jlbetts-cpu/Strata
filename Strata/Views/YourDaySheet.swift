import SwiftData
import SwiftUI

/// **Your day: what the middle of Wins opens** (the owner, 2026-10-06: "we
/// have to flesh it out like how the middle of the crew chats are fleshed
/// out"; his pick, "Your day sheet").
///
/// The crew's details sheet, for one: the same inset list on the warm page,
/// the same section labels. You in the ring and today's count; the day's
/// goal to change; your three (`YourThree`); this
/// week as seven small ink rings with the strips you printed under them;
/// and your streak with its rest days.
/// Nothing on it counts against you: a ring only fills, and a week is
/// shown as what was done.
struct YourDaySheet: View {
    @Binding var goal: Int
    /// Opens the booth on a day: nil for today, or an earlier day's key.
    var openStrip: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var counts: [String: Int] = [:]
    /// This week's printed strips, today's first (`PhotoStrip.printed`).
    @State private var printed: [PhotoStrip] = []
    @AppStorage(YourThree.defaultsKey) private var threeRaw = ""
    /// The titles of today's wins, for the ticks on your three.
    @State private var titlesToday: [String] = []
    @State private var choosingThree = false

    private var today: String { DateUtils.dateString(from: Date()) }
    private var winsToday: Int { counts[today] ?? 0 }
    private var three: [YourThree.Item] { YourThree.decode(threeRaw) }
    /// Today's goal: the one you set (Hard day, which lowered it, is gone).
    private var todaysGoal: Int { goal }

    var body: some View {
        NavigationStack {
            List {
                identity
                Section {
                    HStack(spacing: GridConstants.gapLabel) {
                        Text("Wins a day")
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkPrimary)
                        Spacer(minLength: 0)
                        GlassIconButton(systemName: "minus", onPage: true, accessibilityLabel: "Fewer") {
                            goal = DailyGoal.clamped(goal - 1)
                        }
                        .disabled(goal <= DailyGoal.range.lowerBound)
                        Text("\(goal)")
                            .font(Typography.headerMedium)
                            .monospacedDigit()
                            .foregroundStyle(AppColors.inkPrimary)
                            .contentTransition(.numericText(value: Double(goal)))
                            .frame(minWidth: 28)
                            .animation(GridConstants.crossFade, value: goal)
                        GlassIconButton(systemName: "plus", onPage: true, accessibilityLabel: "More") {
                            goal = DailyGoal.clamped(goal + 1)
                        }
                        .disabled(goal >= DailyGoal.range.upperBound)
                    }
                    .accessibilityElement(children: .contain)
                } header: {
                    FormSectionLabel("Daily Goal")
                } footer: {
                    Text("Reach it and your tower dances and prints the day's strip.")
                        .formFooter()
                }
                .listRowSeparator(.hidden)
                yourThree
                // **The week and its strips, one section** (the owner,
                // 2026-10-07): the rings, then every strip printed this week,
                // today's first. A strip that was never developed is not
                // shown, and a week with none shows only its rings.
                Section {
                    week
                    if !printed.isEmpty { weekStrips }
                } header: {
                    FormSectionLabel("This Week")
                }
                .listRowSeparator(.hidden)
                Section {
                    HStack(alignment: .top, spacing: GridConstants.gapWide) {
                        StreakFigure(value: Streaks.current(among: counts.keys, restsPerWeek: Streaks.Rest.profile),
                                     label: "Current")
                        StreakFigure(value: Streaks.longest(among: counts.keys, restsPerWeek: Streaks.Rest.profile),
                                     label: "Best")
                    }
                    .padding(.vertical, GridConstants.gapTight)
                } header: {
                    FormSectionLabel("Streak")
                } footer: {
                    Text("A day off a week won't break it.")
                        .formFooter()
                }
                .listRowSeparator(.hidden)
            }
            .listSectionSeparator(.hidden)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(WarmBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Done").sheetAction(.confirm) }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .sheet(isPresented: $choosingThree) {
            YourThreePicker(initial: three) { chosen in
                threeRaw = YourThree.encode(chosen)
            }
        }
        .task {
            counts = Self.counts(context: context)
            titlesToday = WinIdeas.titlesToday(context: context)
            #if DEBUG
            if DebugHarness.openSheet == "yourthree" { choosingThree = true }
            #endif
            printed = await PhotoStrip.printed(on: Self.weekDays().filter { !$0.future }.map(\.key),
                                               context: context)
        }
    }

    /// **This week's strips, a tap away** (the owner, 2026-10-07: "shouldn't
    /// you be able to access the last couple days photo strips"). Under the
    /// rings, each printed strip small with its day under it, today's first;
    /// a tap opens it in the booth.
    private var weekStrips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: GridConstants.gapItem) {
                ForEach(printed) { past in
                    Button {
                        dismiss()
                        openStrip(past.day == today ? nil : past.day)
                    } label: {
                        VStack(spacing: GridConstants.gapTight) {
                            StripView(frames: past.frames(excluding: StripKeeping.excluded(.me, day: past.day)),
                                      day: past.day, signature: past.signature, paper: StripKeeping.paper,
                                      width: 44, developed: 1, decor: StripDecor.picture(owner: .me, day: past.day))
                            Text(Self.dayName(past.day))
                                .font(Typography.screenSubtitle)
                                .foregroundStyle(AppColors.inkSecondary)
                        }
                    }
                    .buttonStyle(.pressSurface)
                    .accessibilityLabel("\(Self.dayName(past.day))'s strip")
                }
            }
        }
    }

    /// "Today", or "Mon".
    static func dayName(_ key: String) -> String {
        if key == DateUtils.dateString(from: Date()) { return "Today" }
        guard let date = DateUtils.date(from: key) else { return key }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    // MARK: - Your three

    /// **Your three, under the goal** (`YourThree`). Each row is the win; one
    /// logged today wears a quiet tick, and one not logged is only its words:
    /// no empty circle, nothing that reads as owed. A tap on any of them
    /// changes the three.
    private var yourThree: some View {
        let done = YourThree.done(three, titlesToday: titlesToday)
        return Section {
            if three.isEmpty {
                Button { choosingThree = true } label: {
                    HStack(spacing: GridConstants.gapLabel) {
                        Text(YourThree.Copy.empty)
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkPrimary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColors.inkTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press)
            } else {
                ForEach(three) { item in
                    let isDone = done.contains(item.id)
                    Button { choosingThree = true } label: {
                        HStack(spacing: GridConstants.gapLabel) {
                            Text(item.title)
                                .font(Typography.bodyLarge)
                                .foregroundStyle(AppColors.inkPrimary)
                            Spacer(minLength: 0)
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(Typography.headerSmall)
                                    .foregroundStyle(AppColors.inkTertiary)
                                    .transition(.opacity)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel(isDone ? "\(item.title), done today" : item.title)
                    .accessibilityHint("Changes your three")
                }
            }
        } header: {
            FormSectionLabel(YourThree.Copy.section)
        } footer: {
            Text(YourThree.Copy.footer)
                .formFooter()
        }
        .listRowSeparator(.hidden)
        .animation(GridConstants.crossFade, value: done)
    }

    /// You in the ring, larger, and today's count: the crest, as the crew's
    /// sheet opens on the crew.
    private var identity: some View {
        Section {
            VStack(spacing: GridConstants.gapItem) {
                ZStack {
                    GoalRingStroke(wins: winsToday, goal: todaysGoal, line: 6)
                        .padding(5)
                    CrestFace(side: 72)
                }
                .frame(width: 104, height: 104)
                Text("\(winsToday) of \(todaysGoal) today")
                    .font(Typography.headerMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.inkPrimary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(winsToday) of \(todaysGoal) wins today")
        }
        .listRowBackground(Color.clear)
    }

    /// Monday to Sunday of this week: a small ink ring each, filled toward
    /// the goal by that day's wins. Days to come are only their letter.
    private var week: some View {
        let days = Self.weekDays()
        return HStack(spacing: 0) {
            ForEach(days, id: \.key) { day in
                VStack(spacing: GridConstants.spacing) {
                    GoalRingStroke(wins: day.future ? 0 : counts[day.key] ?? 0,
                                   goal: day.key == today ? todaysGoal : goal, line: 3)
                        .frame(width: 30, height: 30)
                        .opacity(day.future ? 0.35 : 1)
                    Text(day.letter)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(day.key == today ? AppColors.inkPrimary : AppColors.inkTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.future ? day.name : "\(day.name), \(counts[day.key] ?? 0) wins")
            }
        }
        .padding(.vertical, GridConstants.gapTight)
    }

    struct WeekDay { let key: String; let letter: String; let name: String; let future: Bool }

    static func weekDays(now: Date = Date(), calendar: Calendar = .current) -> [WeekDay] {
        var cal = calendar
        cal.firstWeekday = 2
        guard let start = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let today = cal.startOfDay(for: now)
        return (0..<7).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return WeekDay(key: DateUtils.dateString(from: date),
                           letter: String(date.formatted(.dateTime.weekday(.narrow))),
                           name: date.formatted(.dateTime.weekday(.wide)),
                           future: date > today)
        }
    }

    /// Wins per day over the streak's horizon.
    @MainActor
    static func counts(context: ModelContext) -> [String: Int] {
        let from = Streaks.horizonKey()
        let d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed && $0.dateString >= from })
        var out: [String: Int] = [:]
        for log in (try? context.fetch(d)) ?? [] { out[log.dateString, default: 0] += 1 }
        return out
    }
}
