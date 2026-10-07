import SwiftData
import SwiftUI

/// **Your day: what the middle of Wins opens** (the owner, 2026-10-06: "we
/// have to flesh it out like how the middle of the crew chats are fleshed
/// out"; his pick, "Your day sheet").
///
/// The crew's details sheet, for one: the same inset list on the warm page,
/// the same section labels. You in the ring and today's count; the day's
/// goal to change; this week as seven small ink rings; today's strip, or a
/// line saying the goal prints one; and your streak with its rest days.
/// Nothing on it counts against you: a ring only fills, and a week is
/// shown as what was done.
struct YourDaySheet: View {
    @Binding var goal: Int
    var openStrip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var counts: [String: Int] = [:]
    @State private var strip: DayStrip?

    private var today: String { DateUtils.dateString(from: Date()) }
    private var winsToday: Int { counts[today] ?? 0 }

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
                Section {
                    week
                } header: {
                    FormSectionLabel("This Week")
                }
                .listRowSeparator(.hidden)
                Section {
                    if let strip, !strip.frames.isEmpty, winsToday >= goal {
                        Button {
                            dismiss()
                            openStrip()
                        } label: {
                            HStack(spacing: GridConstants.gapLabel) {
                                DayStripView(strip: strip, width: 64)
                                Text("Keep, share or change its paper.")
                                    .font(Typography.bodyLarge)
                                    .foregroundStyle(AppColors.inkPrimary)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppColors.inkTertiary)
                            }
                        }
                        .buttonStyle(.press)
                    } else {
                        Text(goal - winsToday == 1 ? "One more win prints today's strip."
                                                   : "Reach your goal to print today's strip.")
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
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
        .task {
            counts = Self.counts(context: context)
            strip = await DayStrip.today(context: context)
        }
    }

    /// You in the ring, larger, and today's count: the crest, as the crew's
    /// sheet opens on the crew.
    private var identity: some View {
        Section {
            VStack(spacing: GridConstants.gapItem) {
                ZStack {
                    GoalRingStroke(wins: winsToday, goal: goal, line: 6)
                        .padding(5)
                    CrestFace(side: 72)
                }
                .frame(width: 104, height: 104)
                Text("\(winsToday) of \(goal) today")
                    .font(Typography.headerMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.inkPrimary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(winsToday) of \(goal) wins today")
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
                    GoalRingStroke(wins: day.future ? 0 : counts[day.key] ?? 0, goal: goal, line: 3)
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
