import PencilKit
import SwiftUI

// MARK: - The middle's two tabs

/// What a crew tower's middle opens: the crew (its details, as it always
/// did) or Draw (the owner, 2026-10-07: "when you tap the middle head slot
/// there should be a little doodle tab").
enum CrewMiddleTab: String, CaseIterable {
    case crew, draw

    var title: String {
        switch self {
        case .crew: "Crew"
        case .draw: "Draw"
        }
    }
}

/// **The crew's details and Draw, one sheet, two words at the top.**
///
/// The switch is the day sheet's (`DaySheet.tabSwitch`): two plain words, the
/// chosen one in ink, the other faint, no capsule and no segmented control.
/// It sits where a title would, over whichever tab is showing, because the
/// Crew tab is `CrewInfoSheet` exactly as it was, navigation bar and all, and
/// neither tab has a title of its own to compete with it.
struct CrewMiddleSheet: View {
    let crewID: CrewID
    let tucks: CrewTossTucks
    var onLeft: () -> Void

    @State private var tab: CrewMiddleTab

    init(crewID: CrewID, opening: CrewMiddleTab, tucks: CrewTossTucks, onLeft: @escaping () -> Void) {
        self.crewID = crewID
        self.tucks = tucks
        self.onLeft = onLeft
        _tab = State(initialValue: opening)
    }

    /// The words' centre sits on the bar's: the sheet's bar starts under the
    /// drag indicator, and Done's middle is this far down (measured on an
    /// iPhone 17 Pro sheet, 2026-10-07).
    static let switchTop: CGFloat = 13

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                switch tab {
                case .crew:
                    CrewInfoSheet(crewID: crewID, onLeft: onLeft).transition(.opacity)
                case .draw:
                    CrewDrawTab(crewID: crewID, tucks: tucks).transition(.opacity)
                }
            }
            tabSwitch.padding(.top, Self.switchTop)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }

    private var tabSwitch: some View {
        HStack(spacing: GridConstants.gapTight) {
            ForEach(CrewMiddleTab.allCases, id: \.self) { item in
                let chosen = item == tab
                Button {
                    guard item != tab else { return }
                    HapticsEngine.tick()
                    withAnimation(GridConstants.crossFade) { tab = item }
                } label: {
                    // Both words the title's size and weight; only the ink
                    // moves (the day sheet's rule, 2026-10-05).
                    Text(item.title)
                        .font(Typography.headerMedium)
                        .foregroundStyle(chosen ? AppColors.inkPrimary : AppColors.inkTertiary)
                        .padding(.horizontal, GridConstants.gapTight)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressWord)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(chosen ? [.isSelected] : [])
                .animation(GridConstants.crossFade, value: chosen)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }
}

// MARK: - Draw

/// **Draw: one drawing a day, thrown onto this crew's tower.**
///
/// The app's own pen (`InkCanvas`, the same as a doodle in the chat) on a
/// square well, and one button, Throw it in. It drops onto this crew's tower
/// on everyone's phone (`CrewTossLayer`) and clears when the crew's day ends.
/// Once thrown, the tab shows it small and says when the next one can be
/// drawn. Under it, the drawings tucked away on this phone today, each a tap
/// from the tower again.
///
/// Words: never "missed", never "streak", no long dash.
struct CrewDrawTab: View {
    let crewID: CrewID
    let tucks: CrewTossTucks

    @Environment(\.dismiss) private var dismiss
    @State private var ink = InkController()
    @State private var throwing = false
    @State private var refused = false
    @State private var reporting: CrewMessage?
    @State private var thanked = false

    private var store: SocialStore { SocialStore.shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                    if !store.canReply() {
                        Text("Drawing here is off on this phone.")
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, GridConstants.gapWide)
                    } else if let mine = store.myToss(in: crewID), let sketch = mine.sketch {
                        thrown(sketch)
                    } else {
                        canvas
                    }
                    tuckedSection
                }
                .padding(.horizontal, GridConstants.horizontalPadding)
                .padding(.top, GridConstants.gapTight)
                .padding(.bottom, GridConstants.gapWide)
            }
            .scrollDisabled(store.myToss(in: crewID) == nil && store.canReply())
            .background(WarmBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Done").sheetAction(.confirm) }
                }
            }
            .alert("That drawing stays with you", isPresented: $refused) {
                Button("OK", role: .cancel) {}
            }
            .alert("Thanks for telling us", isPresented: $thanked) {
                Button("Done", role: .cancel) {}
            } message: {
                Text("Every report is looked at within a day.")
            }
        }
        // While there is ink on it a swipe does not throw it away.
        .interactiveDismissDisabled(!ink.isEmpty && store.myToss(in: crewID) == nil)
        #if DEBUG
        .task { await debugThrow() }
        #endif
    }

    // MARK: Before

    private var canvas: some View {
        VStack(spacing: GridConstants.gapItem) {
            InkCanvas(controller: ink, aspectRatio: 1)
            Text("One a day. It drops onto this crew's tower for everyone, and clears when the day ends.")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if ink.isEmpty || throwing {
                PrimaryCapsule(waiting: "Throw it in", because: throwing ? "On its way" : "Draw something first")
            } else {
                PrimaryCapsule(title: "Throw it in") { throwIt() }
            }
        }
    }

    private func throwIt() {
        guard !throwing, let png = InkExport.doodlePNG(InkDoodle(drawing: ink.drawing, stickers: ink.stickers,
                                                                  canvas: ink.canvasSize)) else { return }
        throwing = true
        HapticsEngine.lightTap()
        Task {
            let outcome = await store.toss(png, in: crewID)
            throwing = false
            switch outcome {
            case .sent:
                // Closed, so it falls in front of you (`CrewTossLayer` holds
                // a live drop while a sheet is up).
                dismiss()
            case .refusedSketch:
                refused = true
            case .refusedWords, .notAllowed:
                break
            }
        }
    }

    // MARK: After

    private func thrown(_ sketch: URL) -> some View {
        VStack(spacing: GridConstants.gapTight) {
            InkImage(url: sketch, tint: AppColors.drawingInk)
                .frame(width: 128, height: 128)
                .padding(GridConstants.gapItem)
                .accessibilityLabel("Your drawing for today")
            Text("Yours is on the tower.")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
            Text("Back tomorrow for another.")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, GridConstants.gapWide)
    }

    // MARK: Tucked away

    /// Today's drawings tucked into the bubble on this phone, by whoever
    /// drew them. A tap puts one back; a hold offers Report too, since a
    /// drawing you tucked away may be one you wanted gone.
    @ViewBuilder
    private var tuckedSection: some View {
        let tucked = store.tosses(in: crewID).filter { tucks.isTucked($0.messageID) }
        if !tucked.isEmpty {
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                FormSectionLabel("Tucked Away")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: GridConstants.gapTight)],
                          alignment: .leading, spacing: GridConstants.gapTight) {
                    ForEach(tucked) { toss in tile(toss) }
                }
                Text("Only on your phone. Tap one to put it back on the tower.")
                    .formFooter()
            }
            .padding(.top, GridConstants.gapWide)
            .confirmationDialog("Report this drawing?", isPresented: Binding(get: { reporting != nil },
                                                                           set: { if !$0 { reporting = nil } }),
                                titleVisibility: .visible, presenting: reporting) { toss in
                ForEach(CrewSafety.Reason.allCases) { reason in
                    Button(reason.words) {
                        Task {
                            await CrewSafety.report(.message(toss), in: crewID, reason: reason)
                            thanked = true
                        }
                    }
                }
            } message: { _ in
                Text("Your report goes to Some Wins. Nobody in the crew is told.")
            }
        }
    }

    private func tile(_ toss: CrewMessage) -> some View {
        let name = toss.senderProfileID == store.me ? "You"
            : (store.crew(crewID)?.member(toss.senderProfileID)?.shortName ?? "")
        return Button {
            HapticsEngine.lightTap()
            withAnimation(GridConstants.motionSnappy) { tucks.putBack(toss.messageID) }
        } label: {
            VStack(spacing: 4) {
                Group {
                    if let sketch = toss.sketch {
                        InkImage(url: sketch, tint: AppColors.drawingInk).padding(10)
                    }
                }
                .frame(width: 84, height: 84)
                .background(RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                    .fill(AppColors.quietFill))
                Text(name.isEmpty ? " " : name)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressSurface)
        .contextMenu {
            Button("Put Back", systemImage: "arrow.down.to.line") { tucks.putBack(toss.messageID) }
            if toss.senderProfileID != store.me {
                Button("Report", systemImage: "flag", role: .destructive) { reporting = toss }
            }
        }
        .accessibilityLabel(name == "You" ? "Your drawing" : "\(name.isEmpty ? "A friend" : name)'s drawing")
        .accessibilityHint("Puts it back on the tower.")
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    #if DEBUG
    /// `-strataCrewSheet throw`: draws a small sun over a hill and throws it,
    /// so the throw and its fall can be filmed without a finger.
    private func debugThrow() async {
        guard DebugHarness.argument("-strataCrewSheet") == "throw", store.myToss(in: crewID) == nil else { return }
        try? await Task.sleep(for: .seconds(1.2))
        ink.load(InkSamples.sunOverHill(in: CGSize(width: 320, height: 320), width: 6))
        try? await Task.sleep(for: .seconds(1.6))
        throwIt()
    }
    #endif
}
