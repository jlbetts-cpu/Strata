import SwiftData
import SwiftUI

/// **Your day: what the middle of Wins opens** (the owner, 2026-10-06: "we
/// have to flesh it out like how the middle of the crew chats are fleshed
/// out"; his pick, "Your day sheet").
///
/// The crew's details sheet, for one: the same inset list on the warm page,
/// the same section labels. You in the ring and today's count; the day's
/// goal to change; your three and the Hard day switch (`YourThree`); this
/// week as seven small ink rings; today's strip, or a line saying the goal
/// prints one; and your streak with its rest days.
/// Nothing on it counts against you: a ring only fills, and a week is
/// shown as what was done.
struct YourDaySheet: View {
    @Binding var goal: Int
    var openStrip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var counts: [String: Int] = [:]
    @State private var strip: PhotoStrip?
    @AppStorage(YourThree.defaultsKey) private var threeRaw = ""
    @AppStorage(DailyGoal.hardDayKey) private var hardDay = ""
    /// The titles of today's wins, for the ticks on your three.
    @State private var titlesToday: [String] = []
    @State private var choosingThree = false

    private var today: String { DateUtils.dateString(from: Date()) }
    private var winsToday: Int { counts[today] ?? 0 }
    private var three: [YourThree.Item] { YourThree.decode(threeRaw) }
    /// Today's goal (`DailyGoal.today`): your three on a hard day.
    private var todaysGoal: Int { DailyGoal.today(goal: goal, hardDay: hardDay, on: today) }

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
                Section {
                    week
                } header: {
                    FormSectionLabel("This Week")
                }
                .listRowSeparator(.hidden)
                Section {
                    // **Growing all day, dark until it develops** (the
                    // owner's pick: "Yes, undeveloped"). A tap opens the booth.
                    Button {
                        dismiss()
                        openStrip()
                    } label: {
                        HStack(spacing: GridConstants.gapLabel) {
                            if let strip {
                                StripView(frames: strip.frames(excluding: StripKeeping.excluded(.me, day: today)),
                                          day: today, signature: strip.signature, paper: StripKeeping.paper,
                                          width: 64, developed: StripKeeping.isDeveloped(.me, day: today) ? 1 : 0,
                                          decor: StripDecor.picture(owner: .me, day: today))
                            }
                            Text(stripLine)
                                .font(Typography.bodyLarge)
                                .foregroundStyle(AppColors.inkPrimary)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppColors.inkTertiary)
                        }
                    }
                    .buttonStyle(.press)
                } header: {
                    FormSectionLabel("Today's Strip")
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
                // No three, no hard day: the switch would have nothing to be.
                if chosen.isEmpty, hardDay == today { setHardDay(false) }
            }
        }
        .task {
            counts = Self.counts(context: context)
            titlesToday = WinIdeas.titlesToday(context: context)
            #if DEBUG
            if DebugHarness.openSheet == "yourthree" { choosingThree = true }
            #endif
            strip = await PhotoStrip.mine(context: context)
        }
    }

    // MARK: - Your three

    /// **Your three, under the goal** (`YourThree`). Each row is the win; one
    /// logged today wears a quiet tick, and one not logged is only its words:
    /// no empty circle, nothing that reads as owed. A tap on any of them
    /// changes the three. Under them, the switch for a hard day.
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
                Toggle(isOn: Binding(get: { hardDay == today }, set: { setHardDay($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(YourThree.Copy.hardDay)
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text(YourThree.Copy.hardDayLine)
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkTertiary)
                    }
                }
                // The switch every form in the app wears (`switchTrack`).
                .tint(AppColors.switchTrack)
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

    /// Hard day on or off, for today only. The evening's check-in is asked
    /// again, so a day the switch has met is left alone at 7pm too; it can
    /// only be taken away here, never added (one cue a day).
    private func setHardDay(_ on: Bool) {
        hardDay = on ? today : ""
        Task { await EveningCheckIn.update(context: context) }
    }

    /// What the strip is doing today, in a line.
    private var stripLine: String {
        if StripKeeping.isDeveloped(.me, day: today) { return "Turn it, doodle on it, share it." }
        if strip?.candidates.isEmpty ?? true { return "Photos and doodles from today land here." }
        return todaysGoal - winsToday == 1 ? "One more win prints it." : "Reach your goal to print it."
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
