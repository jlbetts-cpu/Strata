import SwiftUI
import SwiftData

/// **Memories is your profile** (the owner, 2026-10-15: "I want the profile
/// to feel like a profile and I think I want the memories to be the profile").
/// The top of the page: your head, your name, your score, and the streak as
/// one quiet line. Your photographs, months and albums follow under it.
///
/// The layout is `docs/research/2026-10-15-profile.md` §3.1: one number above
/// the fold, everything else a press away. A press on your head opens Edit
/// Profile; a press on the score opens Your Score.
struct ProfileHeader: View {
    var onOpen: () -> Void

    /// Every logged win, read live, so a delete lowers the score in the same
    /// moment the block leaves the tower (`WinsScore`).
    @Query(filter: #Predicate<HabitLog> { $0.completed }) private var logs: [HabitLog]

    private var store: ProfileStore { .shared }

    var body: some View {
        // Once a pass: each read faults every log's win (the review).
        let tally = WinsScore.tally(logs.compactMap { $0.habit?.blockSize })
        ProfileTop(person: .me, name: store.name.isEmpty ? "Your Name" : store.name, nameIsPrompt: store.name.isEmpty,
                   figures: [], onPerson: onOpen, personHint: "Opens your profile and stats.", glass: true)
            // Any change here, an older win deleted too, reaches your crews.
            .onChange(of: tally, initial: true) { _, now in
                if CrewsFlag.isOn { SocialStore.shared.noteMyScore(now) }
            }
    }
}

/// **The top of a profile, yours or a friend's** (the owner, 2026-10-15:
/// "the score, wins, and crews area is way too big and doesn't feel
/// researched and minimal ... you should be able to see other people's
/// profiles so that needs to look clean and consistent").
///
/// The head, the name, and the figures as ONE quiet line under it, the way
/// Threads and Apple's own account pages state counts: numbers in the ink,
/// their words a step quieter, a dot between. Three big numerals in a row is
/// Instagram's grid of 2014, and it made the counts the loudest thing on a
/// page that is about the person and their days. One component, so a
/// friend's profile cannot drift from yours.
struct ProfileTop: View {
    struct Figure: Hashable {
        let value: Int
        let word: String
        init(_ value: Int, _ word: String) { self.value = value; self.word = word }
    }

    let person: HeadPerson
    let name: String
    /// "Your Name" before there is one, in the quiet ink a prompt wears, so
    /// it does not read as somebody's name (found by review, 2026-10-15).
    var nameIsPrompt = false
    let figures: [Figure]
    var onPerson: (() -> Void)? = nil
    var personHint: String = ""
    var onFigures: (() -> Void)? = nil
    var figuresHint: String = ""
    /// **Yours, on glass** (2026-10-16): the head in a glass bubble and the
    /// name in the glass caption, as the Wins middle and a crew's are.
    var glass = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let headSide: CGFloat = 76

    var body: some View {
        VStack(spacing: GridConstants.gapTight) {
            pressable(onPerson, hint: personHint) {
                if glass {
                    VStack(spacing: GridConstants.spacing) {
                        PersonHead(person: person, side: Self.headSide, life: .calm, setting: .disc(.clear))
                            .stillGlassCircle()
                        CrestCaption(text: name, chevron: true)
                            .padding(.vertical, 7)
                    }
                } else {
                    VStack(spacing: GridConstants.gapTight) {
                        PersonHead(person: person, side: Self.headSide, life: .calm, setting: .disc(.chosen))
                        Text(name)
                            .font(Typography.headerMedium)
                            .foregroundStyle(nameIsPrompt ? AppColors.inkTertiary : AppColors.inkPrimary)
                            .lineLimit(1)
                    }
                }
            }
            .accessibilityLabel(personHint.isEmpty ? name : "\(name), \(personHint)")
            if !figures.isEmpty {
                // Said as "11 score, 8 wins, 1 crew": on the line itself, so
                // the button inside takes it, never the dots between.
                pressable(onFigures, hint: figuresHint) {
                    line
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(figures.map { "\($0.value) \($0.word)" }.joined(separator: ", "))
                }
            }
        }
        .padding(.top, GridConstants.gapTight)
        .frame(maxWidth: .infinity)
    }

    /// "11 score · 8 wins · 1 crew"
    private var line: some View {
        HStack(spacing: GridConstants.gapTight) {
            ForEach(Array(figures.enumerated()), id: \.offset) { index, figure in
                if index > 0 {
                    Text(verbatim: "·").foregroundStyle(AppColors.inkTertiary)
                }
                HStack(spacing: 4) {
                    Text(verbatim: "\(figure.value)")
                        .font(Typography.headerSmall)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(figure.value)))
                        .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: figure.value)
                    Text(figure.word)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                }
            }
            // **Where your stats are** (the owner, 2026-10-15: "how to get to
            // that screen doesnt really make sense"): a chevron, as a row that
            // opens something says so. Only on yours.
            if onFigures != nil {
                Image(systemName: "chevron.right")
                    .iconSize(GridConstants.iconMedium, relativeTo: .subheadline, weight: .semibold)
                    .foregroundStyle(AppColors.inkTertiary)
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(minHeight: 44)
        .padding(.horizontal, GridConstants.gapItem)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func pressable<Label: View>(_ action: (() -> Void)?, hint: String,
                                        @ViewBuilder label: () -> Label) -> some View {
        if let action {
            Button {
                HapticsEngine.lightTap()
                action()
            } label: { label().contentShape(Rectangle()) }
            .buttonStyle(.pressSurface)
            .accessibilityHint(hint)
        } else {
            label()
        }
    }
}

/// **Your Stats** (the owner, 2026-10-15: "the your score when you scroll
/// down I feel like how its scored isnt useful ... it can show more info ...
/// information that you want to read like the stats and stuff"). It was the
/// score's arithmetic, a row per size; it is what people look up about their
/// own record, the way Fitness and Screen Time summarise: this week against
/// last, the streak, and the record so far. How the score is counted is one
/// quiet line under it. Opened from the figures line under your name.
struct YourScoreSheet: View {
    /// For Settings, reached through Edit.
    var resetAllData: () -> Bool = { false }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<HabitLog> { $0.completed }) private var logs: [HabitLog]
    @State private var vm = ProfileViewModel()
    @AppStorage("profileChartUnit") private var unitRaw = WinTrend.Unit.week.rawValue

    private var stats: ProfileStats {
        ProfileStats.make(logs.compactMap { log in
            guard let habit = log.habit else { return nil }
            return ProfileStats.Win(dateString: log.dateString, category: habit.category,
                                    size: habit.blockSize, hasPhoto: log.imageFileName != nil)
        })
    }

    @AppStorage(DailyGoal.defaultsKey) private var dailyGoal = DailyGoal.standard

    /// Every win as the charts read it: its day, its hour, its colour.
    private var entries: [StatsData.Entry] {
        logs.compactMap { log in
            guard let habit = log.habit else { return nil }
            let hour = Calendar.current.component(.hour, from: log.completedAt ?? log.createdAt)
            return StatsData.Entry(day: log.dateString, hour: hour, category: habit.displayCategory)
        }
    }

    private var profile: ProfileStore { .shared }

    var body: some View {
        let stats = stats
        let entries = entries
        Form {
            // **You, then your figures** (the owner, 2026-10-16: "the stats
            // header looks pretty lame ... combine the profile and stats").
            // Your head alive, your name, and three glass tiles: the score,
            // the streak, and this week.
            Section {
                VStack(spacing: GridConstants.gapItem) {
                    PersonHead(person: .me, side: 88, life: .expressive, setting: .disc(.quiet))
                    Text(profile.name.isEmpty ? "Your Name" : profile.name)
                        .font(Typography.headerMedium)
                        .foregroundStyle(profile.name.isEmpty ? AppColors.inkTertiary : AppColors.inkPrimary)
                    HStack(spacing: GridConstants.gapItem) {
                        tile(stats.score, "score")
                        tile(vm.currentStreak, "day streak")
                        tile(stats.wins, stats.wins == 1 ? "win" : "wins")
                    }
                    .padding(.top, GridConstants.gapTight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, GridConstants.gapTight)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Color.clear)

            Section {
                WeekWinsChart(days: StatsData.week(entries, today: Date()), goal: dailyGoal)
                    .padding(.vertical, GridConstants.gapTight)
            } header: {
                FormSectionLabel("This Week")
            } footer: {
                // One week on this page, the chart's own seven days: a
                // calendar-week comparison under it said a different number.
                Text("Drag across to read a day.")
                    .formFooter()
            }

            if !entries.isEmpty {
                Section {
                    HourWinsChart(hours: StatsData.hours(entries, today: Date()))
                        .padding(.vertical, GridConstants.gapTight)
                } header: {
                    FormSectionLabel("When You Win")
                }
            }

            WinTrendSection(bars: vm.barsByUnit, summaries: vm.summaryByUnit, unitRaw: $unitRaw)
        }
        .listSectionSpacing(GridConstants.gapPage)
        .scrollContentBackground(.hidden)
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle("Profile", drawn: true)
        .toolbar {
            BareToolbarItem(placement: .cancellationAction) {
                NavigationLink {
                    ProfileView(onResetAllData: resetAllData)
                } label: {
                    Text("Edit").sheetAction(.cancel)
                }
                .buttonStyle(.pressWord)
            }
            BareToolbarItem(placement: .confirmationAction) {
                Button {
                    HapticsEngine.lightTap()
                    dismiss()
                } label: {
                    Text("Done").sheetAction()
                }
                .buttonStyle(.pressWord)
            }
        }
        .tint(AppColors.inkPrimary)
        .task { vm.load(context: modelContext) }
    }

    /// A figure on glass: the number large, what it is under it.
    private func tile(_ value: Int, _ word: String) -> some View {
        VStack(spacing: 2) {
            // Not the tally's 34 (the owner, 2026-10-16: "some text is too
            // large, I don't like big text like that"): the heading's size.
            Text(verbatim: StrataFont.digits(value))
                .font(Typography.headerMedium)
                .monospacedDigit()
                .foregroundStyle(AppColors.inkPrimary)
                .contentTransition(.numericText(value: Double(value)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(word)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GridConstants.gapItem)
        // Flat, with the thin outline the owner likes; glass cast a shadow.
        .background {
            let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
            shape.fill(AppColors.quietFill)
                .overlay(shape.strokeBorder(AppColors.inkPrimary.opacity(0.08), lineWidth: GridConstants.strokeThin))
        }
    }
}
