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
    /// **The name as it is being typed; saved only with words in it** (the
    /// owner, 2026-10-14: "You are still able to delete your name and save
    /// which is a no no everyone should have a name"). It was saved on every
    /// keystroke, so clearing it saved nothing. Emptied and left, it comes
    /// back to the name it was.
    @State private var nameDraft: String?
    @FocusState private var namingSelf: Bool
    @State private var showsSettings = false
    @State private var showsMaker = false
    @State private var confirmsDeleteHead = false
    /// One neutral face per head, for the row of heads. Read off the main
    /// actor, because five heads are five 600px PNGs and this draws five 60pt
    /// squares.
    @State private var headSwatches: [UUID: HeadRig] = [:]

    private var store: ProfileStore { .shared }
    private var heads: HeadStore { .shared }

    /// Twice the header button: the same picture, near and far.
    private static let pictureSide: CGFloat = GlassIconButton.defaultSide * 2

    var body: some View {
        // **The reader exists only so the head section can be PHOTOGRAPHED.**
        // `docs/screen-audit.md` carries the head picker as screen 19 and
        // `docs/space.md` §0 records that it "was never in the folder": the
        // picker is a row inside the head section, that section is below the
        // fold on a page carrying the identity block, the streak, the chart and
        // five switches, and nothing on this Mac can scroll a simulator. So the
        // only capture anybody ever got of screen 19 was screen 12 again, with
        // a byte-for-byte identical layout signature. See `scrollToAnchor`.
        ScrollViewReader { scroller in
        // **Edit Profile** (2026-10-15): Memories is the profile now, with
        // your score, streak and trend a press away there (`ProfileHeader`,
        // `YourScoreSheet`) and Settings behind its gear. What is left here
        // is changing who you are: the picture, the name, the heads.
        Form {
            identity
            bannerSection
            featuredSection
            headSection
            earlierHeadsSection
        }
        // **The same break Settings takes, for the same measured reason, and
        // because these two screens have to agree.** The full argument — the
        // 45.0pt ceiling check 11b failed on, and iOS 26's own Settings
        // measured at 63.0 and 70.3 between groups against 10.3 inside one —
        // is written out over `SettingsView`'s copy of this line. It is here as
        // well rather than only there because this file's own header says
        // Profile is "built as a `Form` on `WarmBackground` exactly like
        // `SettingsView`, so pushing from one to the other reads as one place",
        // and a section break is the loudest thing that could stop being true.
        .listSectionSpacing(GridConstants.gapPage)
        .scrollContentBackground(.hidden)
        // **The primary, on the platform's own controls, and it is INK.**
        //
        // **This paragraph said "the owner: 'make sure you are changing the
        // primary to the blue'" and pointed at `AppColors.accentPrimary`, and
        // both halves were dead** (corrected 2026-10-01,
        // `docs/consistency-audit.md` §2.1). The later instruction retired the
        // blue — "I think I prefer if the primary color was the black and white
        // button for dark mode instead of this blue color we are going with
        // right now lets just do the basic" — the tint on the line below has
        // been `inkPrimary` ever since, and `accentPrimary` is deleted from the
        // palette with zero call sites. A comment naming a colour the file does
        // not use is how `switchOn` ended up with six call sites arguing with
        // its own header, which is the other half of the same audit.
        //
        // What is still true and is the reason the tint is set at all: a
        // `Form`'s links, its Done and its pickers all take it, and leaving
        // them to the platform paints them the system blue, which is where
        // every "this looks like default iOS" complaint came from.
        //
        // The measurement that is worth keeping off the retired token: white on
        // `AppColors.accent` measured **2.03:1** where a 17pt word is held to
        // 4.5, and `accentPrimary` was the 4.38:1 answer to that. Ink has the
        // problem from neither direction — `inkPrimary` against the page is
        // about 15:1 whichever way round the scheme is.
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle("Edit Profile", drawn: true)
        .toolbar { doneToolbar }
        // **AFTER `.toolbar`, not before it.** Measured: with the tint applied
        // above, Done still rendered (10, 10, 10). A toolbar item is hosted by
        // the navigation bar rather than by the content it was declared on, so
        // a tint set upstream of the title and the toolbar does not reach it,
        // and the one control the colour was for was the one control that
        // never got it. Below them it does.
        .tint(AppColors.inkPrimary)
        // "Head brought back" and its Undo, over this sheet: the Wins tab's
        // own line is under it, out of sight (`EarlierHeads.bringBack`).
        .undoLine()
        // Profile's head sleeps under the maker. Before that modifier, so the
        // maker's own preview head stays awake. ANDed with what arrives, so a
        // cover above Profile still pauses it.
        .environment(\.headsAwake, coveringHeadsAwake && !showsMaker)
        .navigationDestination(isPresented: $showsSettings) {
            SettingsView(onResetAllData: onResetAllData)
        }
        .task {
            if opensSettings { showsSettings = true }
            #if DEBUG
            if DebugHarness.headMakerState != nil { showsMaker = true }
            await scrollToAnchor(scroller)
            #endif
        }
        // Keyed on the ids, not the whole list: a rename must not send five
        // heads back to disk to be read again.
        .task(id: heads.entries.map(\.id)) { headSwatches = await heads.swatches() }
        .fullScreenCover(isPresented: $showsMaker) {
            HeadMakerView()
        }
        // **By name, and it says where the head goes.** A head is minutes in
        // front of the camera over a photograph that may not exist any more.
        // Since 2026-10-14 deleting keeps it under Earlier Heads, with your
        // last three, so the words say that and not "cannot be undone".
        .confirmationDialog(Text(deleteHeadLabel + "?"),
                            isPresented: $confirmsDeleteHead, titleVisibility: .visible) {
            Button(deleteHeadLabel, role: .destructive) {
                if let id = heads.activeID { heads.delete(id) }
            }
        } message: {
            Text(deleteHeadMessage)
        }
        }
    }

    /// Where `-strataScrollProfile` can put the page. The head section is the
    /// only one so far, because it is the only one below the fold.
    static let headAnchor = "head-section"

    #if DEBUG
    /// `-strataScrollProfile head`: opens Profile already scrolled to the head
    /// section, so screen 19 can be photographed at all.
    ///
    /// **Not a named accessor on `DebugHarness` like its neighbours**
    /// (`scrollsMemories`, `profileChartUnit`) only because that file was off
    /// limits to the pass that needed this. It should move there, beside
    /// `-strataScrollMemories`, which is the same flag for the same reason on
    /// the other long page.
    ///
    /// **The sleep is not a settle and it is not pretending to be one.** It
    /// waits for the `Form` to have laid its sections out at all; the capture's
    /// own settle poll (`tools/settle-shot.py`) is what decides the screen has
    /// stopped moving. Without any wait, `scrollTo` runs against a list whose
    /// rows do not exist yet and does nothing at all, silently.
    @MainActor
    private func scrollToAnchor(_ scroller: ScrollViewProxy) async {
        guard DebugHarness.scrollProfileTo == "head" else { return }
        try? await Task.sleep(for: .seconds(1.5))
        scroller.scrollTo(Self.headAnchor, anchor: .top)
    }
    #endif

    // MARK: - Banner

    /// **This month's banner, chosen** (`BannerEditor`): the photographs
    /// have to be this month's (the owner, 2026-10-16).
    private var bannerSection: some View {
        Section {
            FormSectionLabel("Banner")
            BannerEditor(month: Date())
                .listRowSeparator(.hidden)
        }
    }

    // MARK: - Featured

    private var featuredSection: some View {
        Section {
            FormSectionLabel("Featured wins")
            FeaturedEditor()
                .listRowSeparator(.hidden)
        }
    }

    // MARK: - Identity

    private var identity: some View {
        Section {
            VStack(spacing: GridConstants.gapItem) {
                pictureControl
                // The name and the username together, close (the owner,
                // 2026-10-16: "it should be closer to the name").
                VStack(spacing: 2) {
                    nameField
                    // **Typed here, nothing over it** (the owner: "no popups
                    // in popups"): saved when the keyboard's key or leaving the
                    // field says so, first come (`SocialStore.setHandle`).
                    if CrewsFlag.isOn {
                        HandleField(text: $handleDraft, note: handleNote, onSubmit: saveHandle)
                            .disabled(handleLocked)
                            .onDisappear(perform: saveHandle)
                    }
                }
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
    /// The draft saved if it has words in it; otherwise the name it was.
    private func keepName() {
        guard let draft = nameDraft else { return }
        let words = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !words.isEmpty, words != store.name { store.setName(words) }
        nameDraft = nil
    }

    @State private var photoPick: PhotosPickerItem?
    @State private var handleDraft = ProfileStore.shared.handle ?? ""
    @State private var handleNote: String?

    /// Kept until a month has passed (`Handle.nextChange`), and says so.
    private var handleLocked: Bool {
        ProfileStore.shared.handle != nil && Handle.nextChange(after: ProfileStore.shared.handleSetAt) != nil
    }

    private func saveHandle() {
        let draft = Handle.normalized(handleDraft)
        guard !draft.isEmpty, draft != ProfileStore.shared.handle, Handle.problem(draft) == nil else { return }
        handleNote = "Checking"
        Task {
            switch await SocialStore.shared.setHandle(draft) {
            case .saved: handleNote = "Saved"; HapticsEngine.success()
            case .same: handleNote = nil
            case .taken: handleNote = "Taken. Try another."
            case .invalid(let why): handleNote = why
            case .tooSoon(let date): handleNote = "You can change it again on \(date.formatted(.dateTime.month(.wide).day()))."
            case .offline: handleNote = "Couldn't reach iCloud. Try again."
            }
        }
    }

    private var nameField: some View {
        ZStack {
            if (nameDraft ?? store.name).isEmpty {
                // `inkTertiary` (2026-10-02, design review). It was
                // `inkQuiet` at **3.32:1** on the sheet (rgb 135 on 246), and a
                // placeholder that is the field's only visible label is text,
                // held to 4.5. Still well short of the name's own ink, so an
                // empty field still reads as empty.
                Text("Your name")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkTertiary)
                    .allowsHitTesting(false)
            }
            TextField("", text: Binding(get: { nameDraft ?? store.name },
                                        set: { nameDraft = String($0.prefix(24)) }))
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .multilineTextAlignment(.center)
                .textContentType(.name)
                .submitLabel(.done)
                .focused($namingSelf)
                .onSubmit(keepName)
                .onChange(of: namingSelf) { _, now in if !now { keepName() } }
                .onDisappear(perform: keepName)
                .accessibilityLabel("Your name")
        }
    }

    /// The picture is the control, with no "Edit" under it (the owner's call;
    /// the picture is obviously the thing to press).
    ///
    /// **It is your head, so a press does one of two things** (2026-10-14):
    /// with no head yet it opens the maker, because the blank head is where
    /// yours goes (the owner: "make the head making a must"); with one, it
    /// opens the colour behind it. Choose Photo, Remove Photo and Use Photo
    /// or Initials went with the photograph, which left a menu of one item,
    /// so it is a press now and not a menu.
    /// With no head, a press makes one. With a head, the picture is only the
    /// picture: its background colour was chosen here until 2026-10-16 (the
    /// owner: "it should just stay the default grey"), so there is nothing to
    /// press.
    @ViewBuilder
    private var pictureControl: some View {
        if heads.head == nil {
            Button {
                HapticsEngine.lightTap()
                showsMaker = true
            } label: {
                ProfileAvatar(side: Self.pictureSide)
                    .contentShape(Circle())
            }
            .buttonStyle(.press)
            .accessibilityLabel("Make Your Head")
        } else {
            ProfileAvatar(side: Self.pictureSide)
                .accessibilityLabel("Your head")
        }
    }

    // MARK: - Your head

    /// The active head's name, but only when somebody CHOSE it.
    ///
    /// (`deletableHeadName`, which returned `heads.activeEntry?.name ?? "this
    /// head"` and was interpolated into four strings, is gone: three of those
    /// four needed title case or a sentence opener, so each is its own property
    /// below and none of them builds a label out of a raw name any more.)
    ///
    /// **Found by looking at the screen, not by counting** (2026-10-01). Cut 14
    /// stopped `HeadPickerRow` drawing a name the app made up, and the capture
    /// of the head picker that followed — the first one ever taken of that
    /// screen — showed what the name had quietly been holding up: the
    /// destructive row read **"Delete Me"**, with nothing anywhere on the page
    /// saying that "Me" was the name of a head. It stops being a head's name
    /// and becomes a sentence, on the one row in Profile that destroys work and
    /// cannot be undone.
    ///
    /// So the two go together: wherever a head is named to you, it is named
    /// only if the name is a Fact, and otherwise the app says "this head",
    /// which is what it already said when there was no entry at all.
    private var chosenHeadName: String? {
        guard let name = heads.activeEntry?.name,
              !HeadPickerRow.isGenerated(name, person: store.name) else { return nil }
        return name
    }

    /// "Delete Sam", or "Delete This Head". Title case, because it is a
    /// control's label and every other row in this section is.
    private var deleteHeadLabel: String {
        chosenHeadName.map { "Delete \($0)" } ?? "Delete This Head"
    }

    /// **Where a deleted head goes, said before it goes** (the owner,
    /// 2026-10-14, "the hint for delete your head"). It said a head "can't be
    /// brought back, only made again"; since that day a deleted head waits
    /// under Earlier Heads on this phone with your last three, and Delete for
    /// Good is a hold on it there.
    private var deleteHeadMessage: String {
        "\(chosenHeadName ?? "This head") moves to Earlier Heads on this phone, kept with your last three. Hold it there to delete it for good."
    }

    /// **Your head, not an option** (the owner, 2026-10-14: "make the head
    /// making a must"). Before a head exists, one row and a footer saying what
    /// it is. Once it exists: the tower switch, its look, and Delete.
    ///
    /// **Several heads since 2026-09-23** (owner: "add your friend's head for
    /// instance to your tower instead of yours"). The row picks which one is
    /// in use; everything under it is about that head, which is what the
    /// footer says. Branching on the LIST rather than on `heads.head`, so a
    /// head whose files will not load still shows in the row and can be
    /// deleted, rather than the whole section falling back to "Make Your
    /// Head" over a folder full of faces.
    private var headSection: some View {
        Section {
            // The title inside the section (2026-10-16), and the scroll anchor
            // with it: the one view here that exists in every branch.
            FormSectionLabel(heads.entries.count > 1 ? "Your heads" : "Your head")
                .id(Self.headAnchor)
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
                // `person` is only read by `HeadPickerRow.isGenerated`: a head
                // the app named after you is a name nobody chose, and the same
                // word is already the title of this page.
                HeadPickerRow(entries: heads.entries, activeID: heads.activeID,
                              swatches: headSwatches, active: heads.undressed,
                              person: store.name,
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
                //
                // **AND THE SWITCH TINTS ARE `switchTrack` NOW, AND THEY WERE
                // `switchOn` HERE AND `inkPrimary` IN SETTINGS**
                // (2026-10-01, `docs/consistency-audit.md` §1.3). This file had
                // four `Toggle`s tinted `AppColors.switchOn` (#138BC2) while
                // `SettingsView` — which this file's own header says Profile is
                // "built as a `Form` on `WarmBackground` exactly like", so that
                // "pushing from one to the other reads as one place" — had six
                // tinted `inkPrimary`. You push from Profile to Settings through
                // `settingsLink` below, and the switches changed colour on the
                // way.
                //
                // `switchOn`'s own header already said this could not be
                // happening: "**NOTHING READS THIS ANY MORE, AND THAT IS THE
                // DECISION. 2026-10-01.** The owner: 'I think I prefer if the
                // primary color was the black and white button for dark mode
                // instead of this blue color we are going with right now lets
                // just do the basic.' So the app is monochrome: every action,
                // every switch and every link is `inkPrimary`." Five live
                // readers against a token whose first line says it has none is a
                // decision recorded and half-applied.
                //
                // **The audit's verdict was `inkPrimary`, and it is wrong in dark
                // mode.** A switch track is a SURFACE and what it has to differ
                // from is the WHITE KNOB sliding on it, never the page;
                // `inkPrimary` is `white.opacity(0.92)` in dark, which composites
                // to rgb(237) on the night ground and measures **1.17:1** against
                // that knob. That is the `accentWarm` bug from "An ink is not a
                // surface" to within a tenth, and `SettingsView` has been
                // shipping it on six switches. Making Profile match would have
                // been consistency by spreading a bug.
                //
                // So both screens take `AppColors.switchTrack`: one fixed warm
                // grey, monochrome as he asked, computed to clear 3:1 against the
                // thumb AND both grounds. The arithmetic, the window it sits in,
                // and the one thing about it that needs his eye are all on the
                // token.
                // **No switch for the tower** (the owner, 2026-10-14: "no
                // need to have the option of letting head on tower"). The
                // head waits in Wins' crest and comes out when you press it.

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
                // **Always, now that the head is always somewhere** (the
                // owner, 2026-10-14): it is your picture and your crews see
                // it, so its look is never a control for nothing.
                if let made = heads.undressed {
                    DisclosureGroup(isExpanded: $showsLookPicker) {
                        HeadLookPicker(head: made, selection: heads.look) { kind in
                            heads.setLook(kind)
                        }
                    } label: {
                        HStack {
                            Label {
                                // One black down the column. See the note on
                                // the tower switch above.
                                Text("Look")
                                    .foregroundStyle(AppColors.inkPrimary)
                            } icon: {
                                SettingsIcon(systemName: "camera.filters")
                            }
                            Spacer(minLength: GridConstants.gapTight)
                            Text(heads.look.name)
                                .font(Typography.headerSmall)
                                .foregroundStyle(AppColors.inkTertiary)
                        }
                    }
                }

                // **One head, yours** (the owner, 2026-10-03: "lets remove the
                // option to add another head I think i like the intimacy of
                // just making your head"). "Add Another Head" is gone; Delete
                // and make it again is the way to a new one.
                Button(role: .destructive) {
                    confirmsDeleteHead = true
                } label: {
                    Label {
                        // **One red on the row, not two.** The word was taking
                        // the destructive role's own red, the system #FF3B30,
                        // beside a glyph in the app's: two reds four points
                        // apart on one line, and the app's palette losing to the
                        // platform's on the one row where the colour is the
                        // meaning.
                        //
                        // **And the app's red was `warmRed`, which measured
                        // 2.71:1 on this card** (2026-10-02). A 17pt word is held
                        // to 4.5:1 and it was not close, on one of the two
                        // presses in the app that destroy work. The full table
                        // and the measured result are on Settings' Reset All Data
                        // row, which had the identical fault; the short version
                        // is that `AppColors.destructiveInk` is the app's own
                        // red too, it clears 5.64:1 light and 4.74:1 dark, and
                        // unlike `warmRed` it inverts with the scheme.
                        Text(deleteHeadLabel)
                            .foregroundStyle(AppColors.destructiveInk)
                    } icon: {
                        SettingsIcon(systemName: "trash", tint: AppColors.destructiveInk)
                    }
                }
            }
            // **A photograph instead, if you would rather** (the owner,
            // 2026-10-16). It stands for you everywhere your head would.
            PhotosPicker(selection: $photoPick, matching: .images) {
                Label {
                    Text(store.usesPhoto ? "Change Photo" : "Use a Photo Instead").foregroundStyle(AppColors.inkPrimary)
                } icon: {
                    SettingsIcon(systemName: "photo")
                }
            }
            .onChange(of: photoPick) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { store.usePhoto(data) }
                    photoPick = nil
                }
            }
            if store.usesPhoto, !heads.entries.isEmpty {
                Button {
                    HapticsEngine.lightTap()
                    store.useHead()
                } label: {
                    Label {
                        Text("Use My Head Instead").foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "face.smiling")
                    }
                }
            }
        } footer: {
            // **Nil in the one-head case, so the section has no footer at
            // all**, which is why this is `if let` and not a `Text` of an
            // empty string: an empty footer still reserves a band.
            if let line = headFooter {
                Text(line)
                    .formFooter()
            }
        }
    }

    /// **Your last three heads, to take one back** (the owner, 2026-10-14:
    /// "the app should save your previous three heads to go off of"). Under
    /// your head, only once there is one: a press makes it yours again, with
    /// Undo, and a hold deletes it for good (`EarlierHeadsRow`).
    @ViewBuilder
    private var earlierHeadsSection: some View {
        // **Folded away** (the owner, 2026-10-16: "collapse other information
        // like the previous heads ... anything unnecessary and not useful the
        // user shouldn't be there by default"). One row; open, the heads.
        if !heads.earlierEntries.isEmpty {
            Section {
                DisclosureGroup(isExpanded: $showsEarlierHeads) {
                    EarlierHeadsRow(entries: heads.earlierEntries) { EarlierHeads.bringBack($0) }
                        .padding(.top, GridConstants.gapTight)
                } label: {
                    Text(EarlierHeads.title)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                }
            } footer: {
                if showsEarlierHeads {
                    Text(EarlierHeads.footer)
                        .formFooter()
                }
            }
        }
    }

    @State private var showsEarlierHeads = false

    /// **Nothing, when there is one head** (cut 6, `docs/copy-audit.md`,
    /// 2026-10-01): labelled rows do not need a sentence saying what they do.
    ///
    /// The other two cases stay, each for a reason the rows cannot carry: the
    /// multi-head line says WHICH face is you, which nothing else on the page
    /// says; the no-head line is a promise made before the thing exists, under
    /// a single `Make Your Head` row. Neither speaks of switches any more
    /// (2026-10-14): the head appears wherever you do.
    private var headFooter: String? {
        if heads.entries.isEmpty {
            return HeadAsk.Copy.profileFooter
        }
        if heads.entries.count > 1 {
            return "The head you pick above is the one your crews see."
        }
        return nil
    }

    // MARK: - Done

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
            // **`sheetAction()`, which is where the font, the ink and the 44pt
            // box now live** (2026-10-01, `docs/consistency-audit.md` §1.4).
            // This was a bare `Text` and measured **68x36** on the built sheet,
            // the same miss `AddWinSheet` and `PlanLines` each fixed privately
            // with the owner's words on it, "really easy to miss click". Six
            // sheets, two of them fixed, four of them not: see `SheetAction`,
            // including the part this does NOT fix — Done and the title are now
            // the same ink exactly — and what presses instead.
            Text("Done").sheetAction()
        }
        .buttonStyle(.pressWord)
    }
}

