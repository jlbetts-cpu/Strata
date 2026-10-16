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
    var onEdit: () -> Void
    var onScore: () -> Void

    /// Every logged win, read live, so a delete lowers the score in the same
    /// moment the block leaves the tower (`WinsScore`).
    @Query(filter: #Predicate<HabitLog> { $0.completed }) private var logs: [HabitLog]

    private var store: ProfileStore { .shared }

    var body: some View {
        // Once a pass: each read faults every log's win (the review).
        let tally = WinsScore.tally(logs.compactMap { $0.habit?.blockSize })
        let crews = CrewsFlag.isOn ? SocialStore.shared.crews.count : nil
        ProfileTop(person: .me, name: store.name.isEmpty ? "Your Name" : store.name, nameIsPrompt: store.name.isEmpty,
                   figures: [ProfileTop.Figure(tally.score, "score"),
                             ProfileTop.Figure(tally.wins, tally.wins == 1 ? "win" : "wins")]
                       + (crews.map { [ProfileTop.Figure($0, $0 == 1 ? "crew" : "crews")] } ?? []),
                   onPerson: onEdit, personHint: "Edit Profile",
                   onFigures: onScore, figuresHint: "Opens your stats.")
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let headSide: CGFloat = 76

    var body: some View {
        VStack(spacing: GridConstants.gapTight) {
            pressable(onPerson, hint: personHint) {
                VStack(spacing: GridConstants.gapTight) {
                    PersonHead(person: person, side: Self.headSide, life: .calm, setting: .disc(.chosen))
                    Text(name)
                        .font(Typography.headerMedium)
                        .foregroundStyle(nameIsPrompt ? AppColors.inkTertiary : AppColors.inkPrimary)
                        .lineLimit(1)
                }
            }
            .accessibilityLabel(personHint.isEmpty ? name : "\(name), \(personHint)")
            if !figures.isEmpty {
                pressable(onFigures, hint: figuresHint) { line }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(figures.map { "\($0.value) \($0.word)" }.joined(separator: ", "))
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

    var body: some View {
        let stats = stats
        Form {
            Section {
                VStack(spacing: 0) {
                    Text(verbatim: StrataFont.digits(stats.score))
                        .font(Typography.tally)
                        .foregroundStyle(AppColors.inkPrimary)
                        .contentTransition(.numericText(value: Double(stats.score)))
                    Text("score")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, GridConstants.gapTight)
                .accessibilityElement(children: .combine)
            } footer: {
                Text(stats.wins == 0 ? "Your first win starts it." : "Quick is 1, Regular 2, Deep 3.")
                    .formFooter()
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .listRowBackground(Color.clear)

            Section {
                LabeledContent("Wins") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: "\(stats.thisWeek)").monospacedDigit()
                        if stats.thisWeek + stats.lastWeek > 0 {
                            Text(stats.weekCompared)
                                .font(Typography.screenSubtitle)
                                .foregroundStyle(AppColors.inkTertiary)
                        }
                    }
                }
                LabeledContent("Streak") {
                    Text(verbatim: vm.currentStreak == 1 ? "1 day" : "\(vm.currentStreak) days").monospacedDigit()
                }
            } header: {
                FormSectionLabel("This Week")
            } footer: {
                Text(vm.currentStreak == 0 ? "Log a win to start one." : "A day off a week won't break it.")
                    .formFooter()
            }

            Section {
                LabeledContent("Wins") { Text(verbatim: "\(stats.wins)").monospacedDigit() }
                LabeledContent("Photos") { Text(verbatim: "\(stats.photos)").monospacedDigit() }
                LabeledContent("Best Streak") {
                    Text(verbatim: vm.bestStreak == 1 ? "1 day" : "\(vm.bestStreak) days").monospacedDigit()
                }
                if let colour = stats.topColour {
                    LabeledContent("Top Colour") {
                        HStack(spacing: GridConstants.gapTight) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colour.style.baseColor)
                                .frame(width: 14, height: 14)
                            Text(colour.rawValue.capitalized)
                        }
                    }
                }
                if let day = stats.bestDay {
                    LabeledContent("Best Day") { Text(day) }
                }
            } header: {
                FormSectionLabel("All Time")
            }

            WinTrendSection(bars: vm.barsByUnit, summaries: vm.summaryByUnit, unitRaw: $unitRaw)
        }
        .listSectionSpacing(GridConstants.gapPage)
        .scrollContentBackground(.hidden)
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle("Your Stats", drawn: true)
        .toolbar {
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
}
