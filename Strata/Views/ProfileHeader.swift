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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var store: ProfileStore { .shared }
    private static let headSide: CGFloat = GlassIconButton.defaultSide * 2

    private var tally: WinsScore.Tally { WinsScore.tally(logs.compactMap { $0.habit?.blockSize }) }
    private var streak: Int {
        Streaks.current(among: logs.map(\.dateString), restsPerWeek: Streaks.Rest.profile)
    }

    var body: some View {
        VStack(spacing: GridConstants.gapTight) {
            Button {
                HapticsEngine.lightTap()
                onEdit()
            } label: {
                VStack(spacing: GridConstants.gapTight) {
                    PersonHead(person: .me, side: Self.headSide, life: .calm, setting: .disc(.chosen))
                    Text(store.name.isEmpty ? "Your Name" : store.name)
                        .font(Typography.headerMedium)
                        .foregroundStyle(store.name.isEmpty ? AppColors.inkSecondary : AppColors.inkPrimary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressSurface)
            .accessibilityLabel(store.name.isEmpty ? "Edit Profile" : "\(store.name), Edit Profile")

            // **A profile's row of figures** (the owner, 2026-10-15: "an
            // improved profile feeling more like a social media with a 'wins'
            // score"): the score first, then how many wins it is made of,
            // then the crews you are in. One press opens how it adds up.
            Button {
                HapticsEngine.lightTap()
                onScore()
            } label: {
                HStack(alignment: .top, spacing: 0) {
                    figure(tally.score, "Score")
                    figure(tally.wins, tally.wins == 1 ? "Win" : "Wins")
                    if CrewsFlag.isOn { figure(SocialStore.shared.crews.count, SocialStore.shared.crews.count == 1 ? "Crew" : "Crews") }
                }
                .frame(maxWidth: 320)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressSurface)
            .accessibilityLabel("Score, \(tally.score). \(tally.wins) wins" + (streak > 0 ? ". \(streak) days in a row" : ""))
            .accessibilityHint("Shows how it adds up.")
            // A zero shows nothing: an invitation, not a verdict.
            if streak > 0 {
                Text(streak == 1 ? "1 day in a row" : "\(streak) days in a row")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            }
        }
        .padding(.top, GridConstants.gapItem)
        .frame(maxWidth: .infinity)
    }

    /// One figure in the row: the number, rolling as it changes, over its word.
    private func figure(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: StrataFont.digits(value))
                .font(Typography.tally)
                .foregroundStyle(AppColors.inkPrimary)
                .contentTransition(.numericText(value: Double(value)))
                .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: value)
            Text(label)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

/// **Your Score**: how the number adds up, then the streak and the trend that
/// used to stand on Profile (`docs/research/2026-10-15-profile.md` §3.3, the
/// Fitness pattern: the figure on the page, the detail a press away).
struct YourScoreSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<HabitLog> { $0.completed }) private var logs: [HabitLog]
    @State private var vm = ProfileViewModel()
    @AppStorage("profileChartUnit") private var unitRaw = WinTrend.Unit.week.rawValue

    private var sizes: [BlockSize] { logs.compactMap { $0.habit?.blockSize } }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 0) {
                    Text(verbatim: StrataFont.digits(WinsScore.tally(sizes).score))
                        .font(Typography.tally)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("Score")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, GridConstants.gapTight)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Color.clear)

            Section {
                // Deepest first, as the photographs are split.
                ForEach([BlockSize.hard, .medium, .small], id: \.self) { size in
                    let count = sizes.filter { $0 == size }.count
                    LabeledContent(size.effortLabel) {
                        Text(verbatim: "\(count) × \(WinsScore.points(size)) = \(count * WinsScore.points(size))")
                            .monospacedDigit()
                    }
                }
            } footer: {
                Text(sizes.isEmpty ? "Your first win starts it."
                     : "Quick is 1, Regular 2, Deep 3. Delete a win and it comes off.")
                    .formFooter()
            }

            Section {
                HStack(alignment: .top, spacing: GridConstants.gapWide) {
                    StreakFigure(value: vm.currentStreak, label: "Current")
                    StreakFigure(value: vm.bestStreak, label: "Best")
                }
                .padding(.vertical, GridConstants.gapTight)
            } header: {
                FormSectionLabel("Streak")
            } footer: {
                Text(vm.currentStreak == 0 ? "Log a win to start one." : "A day off a week won't break it.")
                    .formFooter()
            }

            WinTrendSection(bars: vm.barsByUnit, summaries: vm.summaryByUnit, unitRaw: $unitRaw)
        }
        .listSectionSpacing(GridConstants.gapPage)
        .scrollContentBackground(.hidden)
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle("Your Score", drawn: true)
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
