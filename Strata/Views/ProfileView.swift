import Accessibility
import Charts
import PhotosUI
import SwiftData
import SwiftUI

/// You, your wins over time, your head, and Settings.
///
/// Apple Health is the reference: your picture at the top, a couple of facts,
/// one chart that says one thing, then the rows behind them. Built as a
/// `Form` on `WarmBackground` exactly like `SettingsView`, so pushing from one
/// to the other reads as one place. Plan and reasoning:
/// `docs/profile-and-head-plan.md`.
struct ProfileView: View {
    /// Returns whether the record was actually emptied.
    var onResetAllData: () -> Bool
    /// Push straight on to Settings — `-strataOpenSheet settings`, so every
    /// screenshot script written before Settings moved still reaches it.
    var opensSettings = false

    /// Whether a cover above Profile has put its heads to sleep.
    @Environment(\.headsAwake) private var coveringHeadsAwake

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showsLookPicker = false
    @State private var vm = ProfileViewModel()
    @State private var showsSettings = false
    @State private var showsLibrary = false
    @State private var pickerItem: PhotosPickerItem?
    /// The bar a tap has picked out, by the start of its period. Nil shows
    /// the trend.
    @State private var selectedBar: Date?
    @State private var showsMaker = false
    @State private var confirmsDeleteHead = false
    /// One neutral face per head, for the row of heads. Read off the main
    /// actor, because five heads are five 600px PNGs and this draws five 60pt
    /// squares.
    @State private var headSwatches: [UUID: HeadRig] = [:]
    /// Remembered: somebody who reads their weeks will want their weeks the
    /// next time too.
    @AppStorage("profileChartUnit") private var unitRaw = WinTrend.Unit.week.rawValue

    private var store: ProfileStore { .shared }
    private var heads: HeadStore { .shared }
    private var unit: WinTrend.Unit { WinTrend.Unit(rawValue: unitRaw) ?? .week }

    /// Twice the header button: the same picture, near and far.
    private static let pictureSide: CGFloat = GlassIconButton.defaultSide * 2
    /// Tall enough to compare bars by eye, short enough that the chart and
    /// its sentence share a screen with the streak.
    private static let chartHeight: CGFloat = 160
    /// **The tally's ink, taken from the palette.**
    ///
    /// The streak figure and the bars were `.primary.opacity(0.85)` and
    /// `.primary.opacity(0.45)`. CLAUDE.md is explicit that this is not a
    /// colour, it is a colour in light mode: the same number is 85% black on a
    /// near-white page and 85% WHITE on a near-black one, and the two are not
    /// the same weight of voice. `AppColors.inkPrimary` is exactly that ink made
    /// adaptive (0.85 light, 0.92 dark), and it exists because the literal had
    /// been written in eight places.
    ///
    /// So the numbers below are FRACTIONS of the token rather than alphas of
    /// their own.
    ///
    /// The period we are in, which is not finished. 0.53 of the ink lands on
    /// the same 0.45 in light mode that was measured at 3.3:1, and a little
    /// stronger in dark, which is the correction the token exists for. It still
    /// clears 3:1 as a graphic while reading as not yet whole; 0.35 fell to
    /// 2.4:1.
    private static let unfinishedBarShare = 0.53
    /// A bar that is not the one you picked. It steps back rather than
    /// disappearing, so its height can still be compared with the picked one's.
    private static let unpickedBarShare = 0.4

    var body: some View {
        Form {
            identity
            streak
            trend
            headSection
            settingsLink
        }
        .scrollContentBackground(.hidden)
        // **The primary, on the platform's own controls.** The owner: "make
        // sure you are changing the primary to the blue." A `Form`'s links,
        // its Done and its pickers all take the tint, and ink made them look
        // like labels rather than like things to press. See
        // `AppColors.accentPrimary` for why it is the accent's hue at a
        // different weight rather than the accent itself.
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle("Profile", drawn: true)
        .toolbar { doneToolbar }
        // **AFTER `.toolbar`, not before it.** Measured: with the tint applied
        // above, Done still rendered (10, 10, 10). A toolbar item is hosted by
        // the navigation bar rather than by the content it was declared on, so
        // a tint set upstream of the title and the toolbar does not reach it,
        // and the one control the colour was for was the one control that
        // never got it. Below them it does.
        .tint(AppColors.inkPrimary)
        // Profile's head sleeps under the maker and the photo library. Before
        // those modifiers, so the maker's own preview head stays awake.
        // ANDed with what arrives, so a cover above Profile still pauses it.
        .environment(\.headsAwake, coveringHeadsAwake && !(showsMaker || showsLibrary))
        .navigationDestination(isPresented: $showsSettings) {
            SettingsView(onResetAllData: onResetAllData, isPushed: true)
        }
        .task {
            vm.load(context: modelContext)
            if opensSettings { showsSettings = true }
            #if DEBUG
            if DebugHarness.headMakerState != nil { showsMaker = true }
            if let unit = DebugHarness.profileChartUnit { unitRaw = unit }
            #endif
        }
        .onChange(of: unitRaw) { _, _ in selectedBar = nil }
        // Keyed on the ids, not the whole list: a rename must not send five
        // heads back to disk to be read again.
        .task(id: heads.entries.map(\.id)) { headSwatches = await heads.swatches() }
        .fullScreenCover(isPresented: $showsMaker) {
            HeadMakerView()
        }
        // **By name, and it says out loud that it cannot be undone.** A head is
        // minutes in front of the camera over a photograph that may not exist
        // any more, so this is the one place in Profile that destroys work.
        .confirmationDialog(Text("Delete \(deletableHeadName)?"),
                            isPresented: $confirmsDeleteHead, titleVisibility: .visible) {
            Button("Delete \(deletableHeadName)", role: .destructive) {
                if let id = heads.activeID { heads.delete(id) }
            }
        } message: {
            Text("\(deletableHeadName) is removed from this phone and from everywhere it appears. A head can't be brought back, only made again.")
        }
        .photosPicker(isPresented: $showsLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                defer { pickerItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                let prepared = await Task.detached(priority: .userInitiated) {
                    ProfileStore.preparedPhotoData(from: data)
                }.value
                if let prepared { store.setPhotoData(prepared) }
            }
        }
    }

    // MARK: - Identity

    private var identity: some View {
        Section {
            VStack(spacing: GridConstants.gapItem) {
                pictureControl
                // Only when asked for, from the picture's menu (owner: the
                // colours "should not be visible at all times"), and only
                // when there is a background to colour.
                if showsSwatches && hasBackground {
                    backgroundSwatches
                        .transition(.opacity)
                }
                nameField
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        // **The row's own insets, written down rather than inherited.**
        //
        // Measured off the built sheet at 402x874: 75.3pt of empty page between
        // the title's cap and the top of the picture, against 71.3pt between the
        // streak card and the trend card. Check 7 of the audit asks that a
        // section break be the biggest gap on the page, and this beat one by
        // 4.0pt, in the one place where it is the first thing anybody sees.
        //
        // The note that used to be here said the section had no top padding of
        // its own, because adding `gapWide` had measured 85pt. That was true and
        // it stopped one step early: what is left after taking the 24 away is
        // still the list's own first-section inset PLUS the row's default
        // vertical inset, stacked. Zeroing the row's leaves the list's, which is
        // the part that belongs to the platform. The bottom inset carries the
        // `gapTight` the VStack used to pad with, so that number now lives in
        // one place rather than two.
        //
        // `contentMargins(.top:for: .scrollContent)` looked like the tidier
        // answer and is the wrong one: it adds a margin around the scroll's
        // content rather than replacing the list's first-section inset, so it
        // could only ever have made this gap bigger.
        .listRowInsets(EdgeInsets(top: 0,
                                  leading: GridConstants.horizontalPadding,
                                  bottom: GridConstants.gapTight,
                                  trailing: GridConstants.horizontalPadding))
    }

    /// Your name, with the hint drawn rather than left to the platform.
    ///
    /// **Measured: the platform's placeholder is 1.73:1 here.** A `TextField`'s
    /// own placeholder renders (190, 190, 192) against this page's
    /// (247, 247, 247). It is the only piece of text on Profile under the 4.5:1
    /// the audit asks of text, and it is under even the 3:1 a plain UI element
    /// gets. It matters more here than it would in a list row, because this is a
    /// bare centred line with no row, no label and no box around it: the hint IS
    /// the control, and at that ratio the top of the screen reads as switched
    /// off.
    ///
    /// `AppColors.inkQuiet` is the token written for exactly this case, in its
    /// own words "a chevron, a placeholder, a hint", and it is held to 3:1 on
    /// purpose. It composites to (136, 136, 136) on this page, 3.3:1.
    ///
    /// `prompt:` would have been the tidier way to reach it, and it is not
    /// reliable: the style set on a prompt's `Text` is not applied by every
    /// control that takes one, and a contrast fix that may or may not land is
    /// not a fix. The accessibility label is set by hand because the title
    /// string that used to supply it is now empty.
    private var nameField: some View {
        ZStack {
            if store.name.isEmpty {
                Text("Your name")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkQuiet)
                    .allowsHitTesting(false)
            }
            TextField("", text: Binding(get: { store.name },
                                        set: { store.setName($0) }))
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .multilineTextAlignment(.center)
                .textContentType(.name)
                .submitLabel(.done)
                .accessibilityLabel("Your name")
        }
    }

    /// The picture is the control, with no "Edit" under it (the owner's call;
    /// the picture is obviously the thing to press). Always a menu now that
    /// there is always a choice: a photo, or a colour behind your initials.
    /// A menu rather than a confirmation dialog, because presenting the
    /// library from a dialog that is still dismissing is the double
    /// presentation `MainAppView` records UIKit silently dropping.
    private var pictureControl: some View {
        Menu {
            if heads.head != nil {
                if heads.isProfilePicture {
                    Button("Use Photo or Initials", systemImage: "person.crop.circle") {
                        heads.setProfilePicture(false)
                    }
                } else {
                    // Named once there is more than one, because with several
                    // heads "my head" does not say which.
                    Button(heads.entries.count > 1 ? "Use \(deletableHeadName)" : "Use My Head",
                           systemImage: "face.smiling") {
                        heads.setProfilePicture(true)
                    }
                }
            }
            Button("Choose Photo", systemImage: "photo.on.rectangle") {
                // A photo you just chose is the picture you meant to see.
                if heads.isProfilePicture { heads.setProfilePicture(false) }
                showsLibrary = true
            }
            if hasBackground {
                Button("Background Colour", systemImage: "paintpalette") {
                    withAnimation(GridConstants.motionSnappy) { showsSwatches = true }
                }
            }
            if store.photo != nil {
                Button("Remove Photo", systemImage: "trash", role: .destructive) { store.removePhoto() }
            }
        } label: {
            ProfileAvatar(side: Self.pictureSide)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change profile picture")
    }

    /// Behind a head or initials. A photograph covers the whole circle.
    private var hasBackground: Bool { store.photo == nil || heads.headForPicture != nil }

    // MARK: - Background colour

    /// The colours a block can be, and none. The same palette as the tower,
    /// so a picture's colour belongs to the app rather than being a new one.
    private var backgroundSwatches: some View {
        HStack(spacing: 0) {
            swatch(nil)
            ForEach(HabitCategory.selectable, id: \.self) { colour in
                swatch(colour)
            }
        }
    }

    /// Big enough to see, inside a full 44pt target.
    private static let swatchSide: CGFloat = 26

    @State private var showsSwatches = false
    /// The latest pick, so a quick second pick is not closed by the first.
    @State private var swatchPick = 0

    private func swatch(_ colour: HabitCategory?) -> some View {
        let selected = store.background == colour
        return Button {
            HapticsEngine.tick()
            withAnimation(GridConstants.motionSnappy) { store.setBackground(colour) }
            // Put away once chosen, after a beat long enough to see the ring
            // land on it.
            swatchPick += 1
            let pick = swatchPick
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                guard pick == swatchPick else { return }
                withAnimation(GridConstants.motionSnappy) { showsSwatches = false }
            }
        } label: {
            Circle()
                // **`AppColors`, not `.quaternary`.** A system hierarchical grey
                // is neither in the palette nor measured against this page, and
                // section 8 of `docs/design-system-future.md` refuses a colour
                // that is neither in `AppColors` nor taken from content.
                // `quietFill` is the token for a shape that is only there to be
                // a shape.
                // Lit like a block when it IS a colour; a plain well when it
                // is the absence of one. See `ColourSwatch`.
                .fill(colour.map { AnyShapeStyle(EtherealFill.fill($0.style.baseColor)) }
                        ?? AnyShapeStyle(AppColors.quietFill))
                .frame(width: Self.swatchSide, height: Self.swatchSide)
                // **"No colour" still has to read as a choice.** `quietFill` is
                // 6% ink, so on its own it all but vanishes beside six
                // saturated circles. The app's own word for an empty slot is a
                // faint outline, at the weight `AddWinSheet`'s empty photo well
                // already uses, borrowed rather than invented.
                .overlay {
                    if colour == nil {
                        Circle().strokeBorder(AppColors.slotInk.opacity(0.26),
                                              lineWidth: GridConstants.strokeThin)
                    }
                }
                .padding(GridConstants.spacing)
                .overlay {
                    // The ring was `.primary.opacity(0.85)`, which is
                    // `AppColors.inkPrimary` written the way CLAUDE.md forbids.
                    //
                    // **0.55, not full strength.** `AddWinSheet` settled this on
                    // 2026-10-01 and its comment says "Profile's own swatch ring
                    // now wears it too", which was not true: this one was still
                    // at 1.0, so the app had two answers to "which colour is
                    // chosen" one sheet apart. Full ink on a row of pastels made
                    // the chosen colour look stickered rather than chosen, and
                    // the argument is the same here. Selection has to be
                    // obvious; it does not have to shout.
                    Circle().strokeBorder(AppColors.inkPrimary.opacity(selected ? 0.55 : 0),
                                          lineWidth: GridConstants.strokeMedium)
                }
                .frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.colourName(colour))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private static func colourName(_ colour: HabitCategory?) -> String {
        switch colour {
        case .health?:      return "Green"
        case .work?:        return "Blue"
        case .creativity?:  return "Purple"
        case .focus?:       return "Amber"
        case .social?:      return "Coral"
        case .mindfulness?: return "Pink"
        default:            return "No colour"
        }
    }

    // MARK: - Streak

    /// Current and best, side by side. Best is always there, so a break never
    /// looks like the record was lost — broken streaks shown in a log make
    /// people less likely to carry on (Silverman & Barasch, 2023). No red and
    /// no warning; a zero is an invitation, not a verdict.
    private var streak: some View {
        Section {
            HStack(alignment: .top, spacing: GridConstants.gapWide) {
                streakFigure(vm.currentStreak, label: "Current")
                streakFigure(vm.bestStreak, label: "Best")
            }
            .padding(.vertical, GridConstants.gapTight)
        // **The platform's card, not ours**, and that is the owner's call
        // (2026-09-30): "a lot of those panels and elements should just be
        // Apple native to make them cleaner instead of our system — I think it
        // looks a bit off in Profile and Settings having the custom stuff."
        //
        // He is right, and the reason is that the ground moved under the
        // argument. `PageSurface` went on here when the page was a lower, warmer
        // thing and a stock white card sat eight levels over it, reading as
        // paper on a lit sheet. The page is clean white now; the platform's own
        // card is already nearly the page, so the problem it was solving is gone
        // and all that is left is a settings screen that does not behave like
        // one.
        } header: {
            FormSectionLabel("Streak")
        } footer: {
            if vm.currentStreak == 0 {
                Text("Log a win to start one.")
            }
        }
    }

    private func streakFigure(_ value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: GridConstants.gapTight) {
                // **`Typography.tally`, which is the token for this.** It was
                // `StrataFont.relative(28, to: .title)`, and 28 is not one of
                // the five sizes `Typography` has: the scale is 34, 17, 15, 13
                // and 11, and this was a sixth rung invented for one screen.
                // The token's own doc names this exact case, "any number the app
                // states as a fact about your day: the win tally, a day's
                // numeral on a month block, a photo count".
                //
                // Measured: the figure's cap goes 20.0pt to 23.8pt, and the
                // streak card grows about 5pt. That is the right direction as
                // well as the tidy one. The streak is the one fact on this page
                // and it was set smaller than the screen's own title.
                Text(verbatim: StrataFont.digits(value))
                    .font(Typography.tally)
                    .foregroundStyle(AppColors.inkPrimary)
                    .contentTransition(.numericText())
                Text(value == 1 ? "day" : "days")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) streak, \(value) \(value == 1 ? "day" : "days")")
    }

    // MARK: - Trend

    /// Apple Health's Highlight: one sentence, one chart, and a Day / Week /
    /// Month control over them. The sentence is the point and quotes the
    /// numbers behind it; the chart is the evidence (Apple HIG, Charts:
    /// "Summarize the main message of your chart").
    private var trend: some View {
        let summary = vm.summary(unit)
        let bars = vm.bars(unit)
        return Section {
            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                Picker("Wins per", selection: $unitRaw) {
                    ForEach(WinTrend.Unit.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                VStack(alignment: .leading, spacing: 0) {
                    Text(shownHeadline(summary: summary, bars: bars))
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .contentTransition(.numericText())
                    Text(shownDetail(summary: summary, bars: bars))
                        .font(Typography.bodySmall)
                        .foregroundStyle(AppColors.inkSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .animation(GridConstants.motionSnappy, value: selectedBar)

                if summary.kind != .empty {
                    chart(bars)
                        .frame(height: Self.chartHeight)
                        .padding(.top, GridConstants.gapTight)
                        .animation(GridConstants.motionSmooth, value: unitRaw)
                }
            }
            .padding(.vertical, GridConstants.gapTight)
        } header: {
            FormSectionLabel("Wins per \(unit.name)")
        }
    }

    private func headline(_ summary: WinTrend.Summary) -> String {
        switch summary.kind {
        case .more:      return "You're logging more wins lately."
        case .same:      return "You're keeping a steady pace."
        case .fewer:     return "A quieter stretch lately."
        case .notEnough: return "Keep logging to see your trend."
        case .empty:     return "Your \(unit.plural) will show up here."
        }
    }

    /// The numbers, in words somebody's mum reads without a legend: how many
    /// a day, week or month lately, and what "usual" was.
    private func detail(_ summary: WinTrend.Summary) -> String {
        let recent = Self.wins(summary.recentAverage)
        let usual = Self.wins(summary.usualAverage)
        let stretch = "the last \(unit.recent) \(unit.plural)"
        switch summary.kind {
        case .more:
            return "\(recent) a \(unit.name) over \(stretch), up from \(usual) before that."
        case .same:
            // "Close to", not "right in line with": inside the band is not
            // the same as equal, and 2.3 "right in line with" 2.7 read as the
            // page contradicting its own numbers.
            return "About \(recent) a \(unit.name) over \(stretch), close to your usual \(Self.number(summary.usualAverage))."
        case .fewer:
            return "\(recent) a \(unit.name) over \(stretch), down from \(usual) before that."
        case .notEnough:
            return "It appears once you have about \(unit.recent + unit.minimumBaseline) \(unit.plural) of wins."
        case .empty:
            return "Log a win and it's counted here."
        }
    }

    /// "18", "4.5", "0.6" — whole above ten, one decimal below, and never a
    /// trailing ".0".
    private static func number(_ value: Double) -> String {
        if value >= 10 { return String(Int(value.rounded())) }
        let tenths = (value * 10).rounded() / 10
        return tenths == tenths.rounded() ? String(Int(tenths)) : String(format: "%.1f", tenths)
    }

    private static func wins(_ value: Double) -> String {
        let text = number(value)
        return "\(text) \(text == "1" ? "win" : "wins")"
    }

    // MARK: - A bar, picked out

    /// Tap a bar and the sentence above the chart becomes that day, week or
    /// month: its count and when it was. Where Apple Health puts a scrubbed
    /// value, so the number is read where the eye already is rather than in a
    /// callout covering the bars beside it. Tap it again for the trend back.
    private func picked(from bars: [WinTrend.Bar]) -> WinTrend.Bar? {
        guard let selectedBar else { return nil }
        return bars.first { $0.start == selectedBar }
    }

    private func shownHeadline(summary: WinTrend.Summary, bars: [WinTrend.Bar]) -> String {
        guard let bar = picked(from: bars) else { return headline(summary) }
        return "\(bar.count) \(bar.count == 1 ? "win" : "wins")"
    }

    private func shownDetail(summary: WinTrend.Summary, bars: [WinTrend.Bar]) -> String {
        guard let bar = picked(from: bars) else { return detail(summary) }
        switch unit {
        case .day:
            return bar.isCurrent
                ? "Today so far"
                : bar.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .week:
            let start = bar.start.formatted(.dateTime.month(.abbreviated).day())
            if bar.isCurrent { return "This week so far, since \(start)" }
            let end = Calendar.current.date(byAdding: .day, value: 6, to: bar.start)
                .map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? ""
            return "\(start) to \(end)"
        case .month:
            return bar.isCurrent
                ? "This month so far"
                : bar.start.formatted(.dateTime.month(.wide).year())
        }
    }

    private func barInk(for bar: WinTrend.Bar) -> Color {
        let share = bar.isCurrent ? Self.unfinishedBarShare : 1.0
        guard let selectedBar else { return AppColors.inkPrimary.opacity(share) }
        // The picked bar keeps its ink; the rest step back rather than
        // disappearing, so its height can still be compared with theirs.
        return AppColors.inkPrimary
            .opacity(bar.start == selectedBar ? share : share * Self.unpickedBarShare)
    }

    private func pick(_ date: Date, in bars: [WinTrend.Bar]) {
        let component = unit.component
        guard let bar = bars.first(where: { bar in
            Calendar.current.dateInterval(of: component, for: bar.start)?.contains(date) ?? false
        }) else { return }
        HapticsEngine.tick()
        selectedBar = selectedBar == bar.start ? nil : bar.start
    }

    // MARK: - The chart

    private func chart(_ bars: [WinTrend.Bar]) -> some View {
        let ticks = yTicks(bars)
        let labelEvery = unit == .day ? 7 : (unit == .week ? 4 : 3)
        let labelFormat: Date.FormatStyle = unit == .month
            ? .dateTime.month(.abbreviated)
            : .dateTime.month(.abbreviated).day()
        return Chart(bars) { bar in
            BarMark(x: .value("Period", bar.start, unit: unit.component),
                    y: .value("Wins", bar.count),
                    // 0.6 read as a wall of white slabs on the dark ground.
                    width: .ratio(0.5))
                .foregroundStyle(barInk(for: bar))
                .cornerRadius(GridConstants.radiusMark)
        }
        .chartYScale(domain: 0...(ticks.last ?? 2))
        .chartYAxis {
            AxisMarks(position: .trailing, values: ticks) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: GridConstants.headerDividerHeight))
                    // `quietFill` is the token for "a hairline's fill", and it
                    // is adaptive. The 0.1 here was a `.primary.opacity`, the
                    // one thing CLAUDE.md says a colour must never be.
                    .foregroundStyle(AppColors.quietFill)
                // **The axis reads at the page's body size, not at a size only
                // the chart uses.**
                //
                // These two labels were `Typography.caption2` (11 Medium) and
                // they were the only call sites it had in the whole running app.
                // So Profile carried four text sizes at the default Dynamic Type
                // setting (34 for the tally, 17, 13, 11) where check 4 allows
                // three, and the fourth existed to serve one chart. A chart with
                // a size of its own is a chart with a type scale of its own.
                //
                // `bodySmall` is 13 and is already on this card twice: the
                // sentence directly above the plot and the Current and Best
                // labels in the card over it. The axis still recedes, because it
                // recedes on INK (inkSecondary, 0.62, measured 6.19:1) rather
                // than on being two points smaller than everything else.
                //
                // Checked for collision before the change: at the week unit a
                // label lands every 4 bars, so three of them, about 40pt wide at
                // 13 against the 110pt they are spaced; at the month unit, four
                // labels of about 26pt against 83pt. Nothing touches.
                AxisValueLabel()
                    .font(Typography.bodySmall)
                    .foregroundStyle(AppColors.inkSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: unit.component, count: labelEvery)) { _ in
                // The same size as the y axis above, for the same reason.
                AxisValueLabel(format: labelFormat)
                    .font(Typography.bodySmall)
                    .foregroundStyle(AppColors.inkSecondary)
            }
        }
        // A tap anywhere in the plot picks the period under it. The whole
        // plot is the target, not the bar: a bar 12pt wide is under the 44pt
        // the HIG asks for, and Apple HIG, Charts suggests exactly this.
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plot = proxy.plotFrame else { return }
                        let x = location.x - geometry[plot].origin.x
                        guard let date: Date = proxy.value(atX: x) else { return }
                        pick(date, in: bars)
                    }
            }
        }
        .accessibilityChartDescriptor(PeriodWinsDescriptor(bars: bars, unit: unit,
                                                           summary: headline(vm.summary(unit))))
    }

    /// Familiar ticks — steps of 1, 2, 5, 10… — so the axis reads 0 / 10 / 20
    /// rather than 0 / 7 / 14 (Apple HIG, Charts: prefer familiar sequences).
    ///
    /// The smallest familiar step that covers the tallest bar in at most
    /// three steps. The first version took the smallest step whose DOUBLE
    /// covered it, which put a 21-win week under an axis running to 40: half
    /// the chart was empty sky above bars that all looked the same height.
    private func yTicks(_ bars: [WinTrend.Bar]) -> [Int] {
        let top = max(bars.map(\.count).max() ?? 0, 1)
        let steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000]
        let step = steps.first { top <= $0 * 3 } ?? Int((Double(top) / 3).rounded(.up))
        let count = Int((Double(top) / Double(step)).rounded(.up))
        return (0...max(count, 1)).map { $0 * step }
    }

    // MARK: - Your head

    /// The head the delete row would remove: the one in use, which is the one
    /// the row above it has marked and the one the picture is showing.
    private var deletableHeadName: String { heads.activeEntry?.name ?? "this head" }

    /// 100% optional. Before a head exists, one row and a footer saying what
    /// it is. Once it exists, only switches for places it can actually
    /// appear — a switch for a placement that is not built would be a
    /// feature that cannot fire, which CLAUDE.md calls worse than none.
    ///
    /// **Several heads since 2026-09-23** (owner: "add your friend's head for
    /// instance to your tower instead of yours"). The row picks which one is
    /// in use; every switch under it is about that head, which is what the
    /// footer says. Branching on the LIST rather than on `heads.head`, so a
    /// head whose files will not load still shows in the row and can be
    /// deleted, rather than the whole section falling back to "Make Your
    /// Head" over a folder full of faces.
    private var headSection: some View {
        Section {
            if heads.entries.isEmpty {
                Button {
                    HapticsEngine.lightTap()
                    showsMaker = true
                } label: {
                    Label {
                        Text("Make Your Head").foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "face.smiling")
                    }
                }
            } else {
                HeadPickerRow(entries: heads.entries, activeID: heads.activeID,
                              swatches: headSwatches, active: heads.undressed,
                              onPick: { heads.use($0) })

                // **One black down the column.** Measured on Settings, which is
                // built the same way and was captured with its rows on screen: a
                // row whose label is inked `AppColors.inkPrimary` renders
                // (38, 38, 38) and a row that is left to the platform renders
                // (0, 0, 0). Four rows apart, same rank, two blacks, 21:1 beside
                // 15.1:1.
                //
                // The buttons on these two screens were inked a pass ago,
                // because a `Button` in a `Form` otherwise paints its label with
                // the tint and would have given Profile six blue rows against
                // the one accent check 5 allows. The toggles, the pickers and the
                // links were not, because they do not take the tint and so
                // nothing looked wrong in the source. They look wrong on the
                // screen. The ink goes on the `Text` rather than the row, so a
                // disabled row still greys and a destructive one still reds.
                Toggle(isOn: Binding(get: { heads.isProfilePicture },
                                     set: { heads.setProfilePicture($0) })) {
                    Label {
                        Text("Use as Profile Picture")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "person.crop.circle")
                    }
                }
                .tint(AppColors.switchOn)

                // **Its look, wherever it appears.** The owner: "a way to add
                // the filter to the profile picture head so the user can get
                // different variety and choice of their head." The same four
                // looks the camera has, on the head itself: your picture, the
                // map, and the photos you add it to.
                //
                // **And it only appears when the head is somewhere to be
                // seen.** The owner, 2026-09-23: "why are the filter picker
                // always visible." Because it was: a row of five treatments
                // sitting under the switches whether or not a single one of
                // them was on, which is a control for a thing that is not
                // happening. It shows when the head is being used on at
                // least one surface, and goes away again when it is not.
                // **Behind a row now, not a strip of swatches sitting open.**
                //
                // The owner, twice: "why are the filter picker always
                // visible." The first answer was to hide it when the head
                // appears nowhere, and that was not the point: the moment one
                // switch is on, which for most people is the profile picture,
                // five swatches are open on the page again. A look is
                // something somebody changes once and then forgets, so it is
                // a row you open, with the current one named on the right,
                // like every other settings row in the app.
                if let made = heads.undressed, heads.isSomewhere {
                    DisclosureGroup(isExpanded: $showsLookPicker) {
                        HeadLookPicker(head: made, selection: heads.look) { kind in
                            heads.setLook(kind)
                        }
                    } label: {
                        HStack {
                            Label {
                                // One black down the column. See the note on
                                // Use as Profile Picture above.
                                Text("Look")
                                    .foregroundStyle(AppColors.inkPrimary)
                            } icon: {
                                SettingsIcon(systemName: "camera.filters")
                            }
                            Spacer(minLength: GridConstants.gapTight)
                            Text(heads.look.name)
                                .font(Typography.bodySmall)
                                .foregroundStyle(AppColors.inkTertiary)
                        }
                    }
                }

                // **The head that lives on the tower.**
                //
                // The owner, 2026-09-23: "for the head I want it to be added
                // to the Wins screen as an option, where it kinda just floats
                // on the top, around, bouncing off the walls... occasionally
                // he can drop down and jump along the tops of the blocks."
                //
                // "As an option" is the load bearing part, and it is why this
                // row exists rather than the companion simply being there:
                // off by default, and while it is off `TowerCompanionLayer`
                // builds no view, starts no clock and asks for no frames.
                // First in this group because it is the one you SEE, above
                // the two that decide where the head is stamped.
                Toggle(isOn: Binding(get: { heads.showsOnTower },
                                     set: { heads.setShowsOnTower($0) })) {
                    Label {
                        Text("Let My Head Onto the Tower")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "square.stack")
                    }
                }
                .tint(AppColors.switchOn)

                Toggle(isOn: Binding(get: { heads.showsOnMap },
                                     set: { heads.setShowsOnMap($0) })) {
                    Label {
                        Text("Show My Head on the Map")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "map")
                    }
                }
                .tint(AppColors.switchOn)

                Toggle(isOn: Binding(get: { heads.showsCameraSticker },
                                     set: { heads.setShowsCameraSticker($0) })) {
                    Label {
                        Text("Add My Head to Photos")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "camera")
                    }
                }
                .tint(AppColors.switchOn)

                // Not "Make It Again". Saving adds a head now and never writes
                // over one, so a label that promised a replacement would be
                // describing something the code no longer does.
                Button {
                    HapticsEngine.lightTap()
                    showsMaker = true
                } label: {
                    Label {
                        Text("Add Another Head").foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "camera")
                    }
                }

                Button(role: .destructive) {
                    confirmsDeleteHead = true
                } label: {
                    Label {
                        // **One red on the row, not two.** The glyph beside this
                        // word is `AppColors.warmRed` (#E85D4A) and the word
                        // itself was taking the destructive role's own red,
                        // which is the system #FF3B30: two reds four points
                        // apart on one line, and the app's palette losing to the
                        // platform's on the one row where the colour is the
                        // meaning.
                        Text("Delete \(deletableHeadName)")
                            .foregroundStyle(AppColors.warmRed)
                    } icon: {
                        SettingsIcon(systemName: "trash", tint: AppColors.warmRed)
                    }
                }
            }
        } header: {
            FormSectionLabel(heads.entries.count > 1 ? "Your heads" : "Your head")
        } footer: {
            Text(headFooter)
        }
    }

    private var headFooter: String {
        if heads.entries.isEmpty {
            return "About fifteen seconds in front of the camera. It stays on this phone, and it only appears where you switch it on."
        }
        if heads.entries.count > 1 {
            // Says which head the switches under it are about. Without this,
            // four switches sit under a row of faces with nothing saying
            // which face they belong to.
            return "The head you pick above is the one that appears where you switch it on."
        }
        return "It only appears where you switch it on."
    }

    // MARK: - Settings

    private var settingsLink: some View {
        Section {
            NavigationLink {
                SettingsView(onResetAllData: onResetAllData, isPushed: true)
            } label: {
                Label {
                    // One black down the column. See the note on Use as Profile
                    // Picture above.
                    Text("Settings")
                        .foregroundStyle(AppColors.inkPrimary)
                } icon: {
                    SettingsIcon(systemName: "gearshape")
                }
            }
        }
    }

    // MARK: - Toolbar

    /// Bare text, like Settings' Done — see `SettingsView.settingsToolbar`
    /// for why the iOS 26 capsule is stripped.
    @ToolbarContentBuilder
    private var doneToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .confirmationAction) { doneButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .confirmationAction) { doneButton }
        }
    }

    /// **It takes the tint, and it used to override it.**
    ///
    /// This carried `.foregroundStyle(AppColors.accentWarm)` and measured
    /// (28, 26, 24) on the built sheet, 16.2:1, beside a title measuring
    /// (37, 37, 37) at 14.3:1. Two words in the bar, the same weight of black,
    /// and nothing on the screen said which one was the button. The Form two
    /// lines up sets `.tint(AppColors.inkPrimary)` precisely so that the
    /// platform's own controls carry the primary, and this was the one control
    /// on the page opting out of it.
    ///
    /// Taking the override off leaves #007BB2, measured by the palette at 4.38:1
    /// on a light page, and makes Profile's only coloured thing its only button,
    /// which is what check 5 asks for.
    private var doneButton: some View {
        Button {
            HapticsEngine.lightTap()
            dismiss()
        } label: {
            Text("Done").font(Typography.headerSmall)
        }
    }
}

/// VoiceOver and Audio Graphs for the chart: values with context, never
/// adjectives (Apple HIG, Charts).
private struct PeriodWinsDescriptor: AXChartDescriptorRepresentable {
    let bars: [WinTrend.Bar]
    let unit: WinTrend.Unit
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(unit == .month ? "MMMMyyyy" : "MMMd")
        let names = bars.map { formatter.string(from: $0.start) }
        let top = Double(bars.map(\.count).max() ?? 0)
        let title = "Wins per \(unit.name)"

        let xAxis = AXCategoricalDataAxisDescriptor(title: unit.title, categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(title: "Wins",
                                                range: 0...max(top, 1),
                                                gridlinePositions: []) { value in
            let wins = Int(value)
            return "\(wins) \(wins == 1 ? "win" : "wins")"
        }
        let points = zip(bars, names).map { bar, name in
            AXDataPoint(x: name, y: Double(bar.count),
                        label: bar.isCurrent ? "This \(unit.name), so far" : nil)
        }
        let series = AXDataSeriesDescriptor(name: title, isContinuous: false, dataPoints: points)
        return AXChartDescriptor(title: title, summary: summary,
                                 xAxis: xAxis, yAxis: yAxis,
                                 additionalAxes: [], series: [series])
    }
}
