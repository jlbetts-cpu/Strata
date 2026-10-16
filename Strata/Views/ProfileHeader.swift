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
    /// The month Memories is showing, for the line's month figure (the owner:
    /// "one of the stats month specific since it's by month").
    var month: Date = Date()
    @State private var editingBanner = false

    /// Every logged win, read live, so a delete lowers the score in the same
    /// moment the block leaves the tower (`WinsScore`).
    @Query(filter: #Predicate<HabitLog> { $0.completed }) private var logs: [HabitLog]

    private var store: ProfileStore { .shared }

    /// This month's wins only, so every month's banner is its own (the
    /// owner, 2026-10-16: "the banner should use only wins from that month,
    /// so every month is different"). Your choice where it is of this month;
    /// else the month's latest photographs.
    private var banner: [BannerPicture] {
        let key = monthKey
        let photographed = logs.filter { $0.imageFileName != nil && $0.dateString.hasPrefix(key) }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        let files = photographed.compactMap(\.imageFileName)
        let chosen = store.bannerFiles(for: key).filter { files.contains($0) }
        let picked = chosen.isEmpty ? Array(files.prefix(ProfileBanner.most)) : chosen
        return picked.map(BannerPicture.mine)
    }

    private var monthKey: String { String(DateUtils.dateString(from: month).prefix(7)) }

    /// The streak, the month's wins, and its photographs.
    private var chips: [InfoCard.Fact] {
        let streak = Streaks.current(among: Set(logs.map(\.dateString)), restsPerWeek: Streaks.Rest.profile)
        let inMonth = logs.filter { $0.dateString.hasPrefix(monthKey) }
        let monthName = month.formatted(.dateTime.month(.wide))
        var out = [InfoCard.Fact(icon: "flame", text: streak == 1 ? "1 day streak" : "\(streak) day streak"),
                   InfoCard.Fact(icon: "checkmark.circle", text: "\(inMonth.count) in \(monthName)")]
        let photos = inMonth.filter { $0.imageFileName != nil }.count
        if photos > 0 { out.append(InfoCard.Fact(icon: "camera", text: photos == 1 ? "1 photo" : "\(photos) photos")) }
        return out
    }

    var body: some View {
        // Once a pass: each read faults every log's win (the review).
        let tally = WinsScore.tally(logs.compactMap { $0.habit?.blockSize })
        let _ = store.bannerChanged
        ProfileTop(person: .me, name: store.name.isEmpty ? "Your Name" : store.name, nameIsPrompt: store.name.isEmpty,
                   figures: [], onPerson: onOpen, personHint: "Opens your profile and stats.", glass: true,
                   banner: banner, chips: chips, handle: store.handle)
            // **Edit this month's banner** from a hold, as a hold edits
            // everything else here.
            .contextMenu {
                Button { editingBanner = true } label: {
                    Label("Edit Banner", systemImage: "photo.on.rectangle")
                }
            }
            .sheet(isPresented: $editingBanner) { BannerPickerSheet(month: month) }
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
    /// The banner of recent wins over the head (`ProfileBanner`); none, and
    /// the head stands alone as it did.
    var banner: [BannerPicture]? = nil
    /// Short facts under the name, Hinge's way (`InfoCard`): yours.
    var chips: [InfoCard.Fact] = []
    /// @them, under the name, when they have one (`Handle`).
    var handle: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let headSide: CGFloat = 76

    var body: some View {
        if let banner { bannered(banner) } else { plain }
    }

    /// **The banner, the head over its foot, the name and a line** (the
    /// owner's sketch, 2026-10-16): the head stands across the banner's
    /// lower edge on a ring of the page, so it reads as in front of it.
    /// **One card: the banner, the head over its foot, the name and the
    /// facts** (the owner, 2026-10-16: "maybe combining the banner, pfp and
    /// the profile stats into one clean container"). The card is a form row's
    /// surface with the hairline; the photographs sit inside it at the same
    /// distance from every edge, their corners concentric with the card's.
    /// The whole card opens your profile.
    private func bannered(_ banner: [BannerPicture]) -> some View {
        let inset = PageCard.inset
        return pressable(onPerson, hint: personHint) {
            VStack(spacing: GridConstants.gapTight) {
                ZStack(alignment: .bottom) {
                    ProfileBanner(pictures: banner)
                        .padding(.bottom, Self.headSide / 2)
                    PersonHead(person: person, side: Self.headSide, life: .calm, setting: .disc(.chosen))
                        .padding(4)
                        .background(Circle().fill(Color(uiColor: .secondarySystemGroupedBackground)))
                }
                // **It opens** (the owner, 2026-10-16: "making sure the user
                // knows they can open the profile"): the row's chevron beside
                // the name, where yours opens Profile.
                HStack(spacing: 4) {
                    Text(name)
                        .font(Typography.headerMedium)
                        .foregroundStyle(nameIsPrompt ? AppColors.inkTertiary : AppColors.inkPrimary)
                        .lineLimit(1)
                    if onPerson != nil {
                        Image(systemName: "chevron.right")
                            .font(Typography.headerSmall)
                            .imageScale(.small)
                            .foregroundStyle(AppColors.inkTertiary)
                            .accessibilityHidden(true)
                    }
                }
                if let handle {
                    Text(verbatim: "@" + handle)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                        .padding(.top, -GridConstants.gapTight)
                }
                if !chips.isEmpty {
                    InfoCard(chips: chips, quiet: true)
                }
            }
            .padding([.horizontal, .top], inset)
            .padding(.bottom, GridConstants.gapItem)
            .pageCard()
        }
        .accessibilityLabel(([name] + chips.map(\.text) + [personHint]).filter { !$0.isEmpty }.joined(separator: ", "))
        .padding(.top, GridConstants.gapTight)
        .frame(maxWidth: .infinity)
    }

    private var plain: some View {
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
                    figuresLine
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(figures.map { "\($0.value) \($0.word)" }.joined(separator: ", "))
                }
            }
        }
        .padding(.top, GridConstants.gapTight)
        .frame(maxWidth: .infinity)
    }

    /// "11 score · 8 wins · 1 crew"
    private var figuresLine: some View {
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

    /// The figures, across the top of the card, short as Hinge's are.
    private func chips(_ stats: ProfileStats) -> [InfoCard.Fact] {
        var out = [
            InfoCard.Fact(icon: "flame", text: vm.currentStreak == 1 ? "1 day streak" : "\(vm.currentStreak) day streak"),
            InfoCard.Fact(icon: "checkmark.circle", text: stats.wins == 1 ? "1 win" : "\(stats.wins) wins"),
            InfoCard.Fact(icon: "star", text: "Score \(stats.score)"),
        ]
        if CrewsFlag.isOn {
            let crews = SocialStore.shared.groupCrewCount
            out.append(InfoCard.Fact(icon: "person.2", text: crews == 1 ? "1 crew" : "\(crews) crews"))
        }
        return out
    }

    /// **Who you are as a winner, a few words a line** (2026-10-16; the
    /// owner: "the lines were short ... research what information should be
    /// in there because it is your profile"). A profile's lines are traits,
    /// not reports (Hinge's "Christian", "Monogamy"; Bitmoji's one identity):
    /// when you win, your best day, your goal, your best run, your photos,
    /// and since when. Only the ones that are true yet.
    private func facts(_ stats: ProfileStats, entries: [StatsData.Entry]) -> [InfoCard.Fact] {
        var out: [InfoCard.Fact] = []
        if entries.count >= 3, let peak = StatsData.peakHour(StatsData.hours(entries, today: Date(), days: 60)) {
            switch peak {
            case 5..<12: out.append(InfoCard.Fact(icon: "sunrise", text: "Morning person"))
            case 12..<17: out.append(InfoCard.Fact(icon: "sun.max", text: "Afternoon person"))
            case 17..<21: out.append(InfoCard.Fact(icon: "sunset", text: "Evening person"))
            default: out.append(InfoCard.Fact(icon: "moon", text: "Night owl"))
            }
        }
        if let day = stats.bestDay { out.append(InfoCard.Fact(icon: "calendar", text: "Best on \(day)s")) }
        out.append(InfoCard.Fact(icon: "target", text: "Goal \(dailyGoal) a day"))
        if vm.bestStreak > 1 { out.append(InfoCard.Fact(icon: "trophy", text: "Best run \(vm.bestStreak) days")) }
        if stats.photos > 0 {
            out.append(InfoCard.Fact(icon: "camera", text: stats.photos == 1 ? "1 photo" : "\(stats.photos) photos"))
        }
        if let first = entries.map(\.day).min(), let date = DateUtils.date(from: first) {
            out.append(InfoCard.Fact(icon: "clock", text: "Since \(date.formatted(.dateTime.month(.abbreviated).year()))"))
        }
        return out
    }

    var body: some View {
        let stats = stats
        let entries = entries
        Form {
            // **You, then your facts, organised** (the owner, 2026-10-16:
            // "the stats header looks pretty lame"; then, after Hinge, "organize
            // information using icons and clean hairline dividers"). Your head
            // alive and your name; then one card (`InfoCard`): the figures
            // across the top, sideways when they do not fit, and the facts
            // about your record a line each.
            Section {
                VStack(spacing: GridConstants.gapItem) {
                    PersonHead(person: .me, side: 80, life: .expressive, setting: .disc(.quiet))
                    Text(profile.name.isEmpty ? "Your Name" : profile.name)
                        .font(Typography.headerMedium)
                        .foregroundStyle(profile.name.isEmpty ? AppColors.inkTertiary : AppColors.inkPrimary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Color.clear)

            Section {
                InfoCard(chips: chips(stats), rows: facts(stats, entries: entries))
                    .listRowInsets(EdgeInsets())
            }

            Section {
                WeekWinsChart(days: StatsData.week(entries, today: Date()), goal: dailyGoal)
                    .padding(.vertical, GridConstants.gapTight)
            }

            if !entries.isEmpty {
                Section {
                    HourWinsChart(hours: StatsData.hours(entries, today: Date()))
                        .padding(.vertical, GridConstants.gapTight)
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
}
