import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Logging a win, with a photo of it.
///
/// This is the add screen. It asks what you did, what colour it is, how big it
/// was, and lets you put a picture on it — and pressing Add drops the block on
/// the tower. It is not a form about the future; everything it asks about has
/// already happened.
///
/// It replaced a form with eleven controls (a title field, a category picker, a
/// recurring/one-time control, a date picker, a "set time" toggle, a time
/// picker, an effort picker, a HealthKit type picker and a threshold picker) to
/// say "read a chapter". No time, no schedule: the tower records what you did,
/// not when you meant to.
///
/// The controls are the same ones the block's own card uses — six colour
/// circles and three size buttons — so the thing you are making looks like the
/// thing it becomes.
struct AddWinSheet: View {

    let modelContext: ModelContext
    let tower: Tower?
    /// When set, the sheet edits this block's habit instead of creating one.
    var editing: Habit? = nil
    var editingLog: HabitLog? = nil
    /// A photograph the sheet opens already holding — a shot just taken on
    /// the camera tab, which lands here to be named and sized rather than
    /// going straight onto the tower unnamed.
    /// Pre-filled title, when the win is being written from a plan line.
    var initialTitle: String? = nil
    var initialPhoto: UIImage? = nil
    /// The size drawn out of the camera's shutter, if the photograph came from
    /// there. Defaulted, so no other call site changes.
    var initialSize: BlockSize = .small
    /// Where the photograph was taken, if it came from the camera.
    var initialPlace: WinPlace? = nil
    /// Which part of the photograph the block shows, if it was moved on the
    /// review.
    var initialCrop: CGPoint = .zero
    /// The colour to open on instead of the tower's least-used one. Worn as a
    /// colour, not claimed as a category: a plan line's colour may have been
    /// assigned rather than picked, and nothing records which.
    var initialColour: HabitCategory? = nil
    var onSaved: (Habit) -> Void = { _ in }
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    @State private var title = ""
    @State private var category: HabitCategory = .health
    @State private var size: BlockSize = .small
    @State private var place: WinPlace?
    @State private var photo: UIImage?
    /// Whether the user touched the photo at all this time round.
    ///
    /// Without it, every save rewrote the image — re-encoding a JPEG that had
    /// already been encoded, losing a little each time, for an edit that was
    /// only ever a rename.
    @State private var photoChanged = false
    /// Which part of the photograph the block shows. Carried from the review.
    @State private var crop: CGPoint = .zero
    /// Whether a swatch was pressed. Until one is, `category` is only the
    /// colour the sheet opened on, and is saved as a colour rather than as a
    /// kind of win. See `QuickWinService.labels(showing:chosen:)`.
    @State private var categoryChosen = false
    @State private var showCamera = false
    @State private var choosingSource = false
    /// Looking at the photograph this win already has.
    @State private var peeking = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var loaded = false
    @State private var confirmingDelete = false
    @State private var isSaving = false

    private var isEditing: Bool { editing != nil }
    /// A name is optional.
    ///
    /// Naming a win is the slowest part of logging one, and the app already
    /// has a block that carries no text — that is what the empty slot drops
    /// when you hold it. Requiring a name here made the sheet stricter than
    /// the gesture beside it for no reason, and the most common thing anyone
    /// wants to record is one they cannot be bothered to describe.
    ///
    /// An unnamed block is a colour and a size, which is a perfectly good
    /// thing to have done.
    private var canSave: Bool { !isSaving }

    var body: some View {
        NavigationStack {
            // **THE SHEET IS A FIELD, AND THE BLOCK STANDS ON ITS FLOOR.**
            //
            // Check 11 of `docs/screen-audit.md`, measured on the built sheet
            // at 402x874 with `tools/page-room.py`. It failed two clauses and
            // they were the same fault:
            //
            // - **11b**, both ends of the ladder. Seven controls at 10.3, 11.0,
            //   14.0, 23.0, 26.7, 29.7 and 33.3pt apart. One rhythm, nothing
            //   on it reading as a break, and `docs/space.md`'s P1 (Kubovy,
            //   Holcombe and Wagemans 1998) says why that is the same as no
            //   spacing at all: proximity groups by the RATIO between
            //   competing distances, and 33.3 against 26.7 is 1.25x.
            // - **11c**, the air between things rather than after them. The
            //   biggest break on the page was 300.7pt and it was UNDER the
            //   last band. A page that does that stopped; it did not end.
            //
            // **The emptiness was never the fault, and the record proves it.**
            // An earlier pass read 49% empty as the problem and cut it to 38%
            // by moving the well below the controls and sizing it off the
            // page. That move was right for its own reason and the sheet still
            // failed, because what was wrong is that one spacing cannot group
            // anything. So this is a REDISTRIBUTION: the same ink, the same
            // emptiness, three groups instead of one list.
            //
            //   the name          what you did
            //   gapPage (64)
            //   colour + size     what the block is, gapItem apart, one group
            //   the break         everything left over
            //   the block         what you made
            //   gapPage (64)      the floor
            //
            // Measured on the built Edit sheet at 402x874, which is this same
            // view with the keyboard down: gaps of 10.3, 38.0, 71.3, 15.0,
            // 196.7 and 32.0, with a 64.0 floor under it. The break is 13.1x
            // the gap inside the group and it falls between two content bands,
            // which is both of the clauses that were failing. Without the
            // Delete button, which is the Add case, the same arithmetic puts
            // the block at y593 to 776 and the break at 279.
            //
            // **The block is floored rather than hung.** It is the subject,
            // and `docs/illustrations.md`'s rule for this app is that the
            // figure sits small in a big empty field — a field is AROUND a
            // figure, so the sheet has to keep a floor under it. The app has
            // the same composition once already and the audit calls it a
            // worked example that passes: Store unavailable's pill sits at
            // y766 with a 483.7pt break above it and 24 under it.
            //
            // The `GeometryReader` is what makes that arithmetic rather than a
            // guess, and it is the pattern `PlanSheet.content` already uses:
            // the stack is held to at least the viewport's height and the
            // `Spacer` is the flexible thing in it, so the break is exactly
            // what the content left over.
            //
            // **The line that used to end this paragraph said "with the
            // keyboard up the spacer falls back to its 64 and nothing is
            // pushed off the bottom", and that is measurably false** (found
            // 2026-10-01 by photographing the state nobody had photographed:
            // Add, fresh, with the keyboard up, which is the state this sheet
            // opens in every single time). At 402x874 the well draws y377 to
            // y560 and the keyboard's top edge is y539.7, so **21pt of the
            // block is behind the keyboard** — not the block, but most of the
            // blurred bottom band, which is the one piece of a block that says
            // it is a block. The Edit sheet does not show it because it opens
            // with the keyboard down, and the Add sheet WITH a photograph does
            // not either, because a photograph takes the colour row away and
            // everything above the well moves up 65pt.
            //
            // **It is left alone, and the reason is arithmetic rather than
            // taste.** The block's top is pinned by the content above it plus
            // the spacer's floor, so the only way to lift it clear is to spend
            // the 64: `gapPage` is the BREAK this whole composition is built
            // on, and cutting it to 40 to buy 21pt would take the break from
            // 13.1x the gap inside the group to about 8x and put the page back
            // where check 11b found it. The content scrolls, the band is
            // reachable on the first flick, and the alternative is paying for a
            // band with the composition. **Recorded rather than hidden**, since
            // a comment claiming the opposite is worse than no comment.
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        nameField
                        decisions
                        Spacer(minLength: GridConstants.gapPage)
                        subject
                    }
                    // **The app's page margin, not a private one.** This was
                    // 20 while every other screen is `horizontalPadding` (16),
                    // so the add sheet's content sat four points further in
                    // than the tower behind it — the kind of difference nobody
                    // can name and everybody feels when they move between two
                    // screens.
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.top, GridConstants.gapTight)
                    // The floor. It was `gapLabel` (16), which is a margin and
                    // not a floor: with the block standing on it the sheet
                    // needs the rung that says "this is the end of the page".
                    .padding(.bottom, GridConstants.gapPage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
            }
            .sheetTitle(isEditing ? "Edit" : "Add a win", drawn: true)
            .toolbar {
                addWinToolbar
            }
            .onAppear(perform: load)
            .confirmationDialog("Delete this?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteIt() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The block leaves the tower.")
            }
        }
        // Full height, and it stays that way. A medium detent was tried to
        // close the empty space at the bottom and it clipped the size control
        // instead — the sheet's content is taller than half a screen once the
        // photo well is a 2x2. Empty space under a form is ordinary; a control
        // cut off by the edge of a sheet is a bug.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // The page's own background, not the default translucent one. Through
        // frosted glass the tower's colours bleed up behind the controls and
        // the sheet reads as muddy — and a frosted surface is the block's
        // material, not a sheet's.
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .fullScreenCover(isPresented: $showCamera) { cameraCover }
        // Two sources, asked once.
        //
        // The camera alone was the wrong call: most wins are photographed when
        // they happen and named later, so by the time you are filling this in
        // the picture is usually already in your library. Taking one now is
        // the other half, not the whole of it.
        // Title case, as the photo menu further down, Profile and the viewer
        // already have it, and as Photos does: these are buttons, and the
        // same action was spelled two ways depending on which door you used.
        .contextMenu {
            if photo != nil {
                Button("Replace Photo") { choosingSource = true }
                Button("Remove Photo", role: .destructive) {
                    photo = nil
                    photoChanged = true
                }
            }
        }
        // **The title is EMPTY, and that is the cut, not an oversight**
        // (2026-10-01, `docs/copy-audit.md` number 13). It read "Add a photo"
        // and was presented with `titleVisibility: .hidden`, so the string was
        // in the source and nothing was ever drawn from it. What IS on screen
        // is `Take Photo`, `Choose from Library`, `Remove Photo` and `Cancel`,
        // which say it four times over. `Text(verbatim:)` rather than a bare
        // "" so it is not offered to the localiser as a string to translate.
        .confirmationDialog(Text(verbatim: ""), isPresented: $choosingSource, titleVisibility: .hidden) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showLibrary = true }
            if photo != nil {
                Button("Remove Photo", role: .destructive) {
                    photo = nil
                    photoChanged = true
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $peeking) { peekCover }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    photo = image
                    photoChanged = true
                }
                pickerItem = nil
            }
        }
    }

    // MARK: - The three groups
    //
    // One property each, named for the group it is, because the composition is
    // the thing this screen gets wrong when it is edited carelessly: a control
    // added to the wrong `VStack` inherits that group's spacing and the page
    // quietly goes back to having one rhythm.

    /// **What you did.** The sheet's first question and its own subject, so
    /// `gapPage` stands between it and the two properties under it.
    private var nameField: some View {
        Group {
                    // **THE PLACEHOLDER IS A TOKEN NOW, AND IT WAS 1.73:1.**
                    //
                    // The open check on this screen in `docs/screen-audit.md`
                    // was that the placeholder's contrast had never been
                    // sampled. Sampled, on the identical pattern in
                    // `ProfileView`: a bare `TextField`'s own placeholder
                    // renders (190, 190, 192) on a (247, 247, 247) page, which
                    // is 1.73:1 and under even the 3:1 a plain UI element is
                    // held to, let alone the 4.5 of the sentence it is
                    // standing in for. `inkQuiet` is the token for a
                    // placeholder and measures 3.3:1 there, and a `prompt` is
                    // the only way to set its colour without rebuilding the
                    // field.
                    TextField(
                        isEditing ? "Name" : "What did you do?",
                        text: $title,
                        prompt: Text(isEditing ? "Name" : "What did you do?")
                            .foregroundStyle(AppColors.inkQuiet)
                    )
                        .font(Typography.headerMedium)
                        // **PURE BLACK, AND NOTHING ELSE ON THE SHEET IS.**
                        //
                        // A `TextField` with no `foregroundStyle` falls
                        // through to `UIColor.label`, which is (0, 0, 0) on
                        // light and pure (255, 255, 255) on dark. Measured at
                        // 18.91:1 where every other ink on this sheet is
                        // `inkPrimary` at (37, 37, 37) and 13.81:1. So the one
                        // word the whole screen is about was the one word
                        // drawn in an ink the design system does not own.
                        .foregroundStyle(AppColors.inkPrimary)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await save() } }
        }
    }

    /// **What the block IS: its colour and its size, one group.**
    ///
    /// They are `gapItem` apart — "between items in a set", which is what two
    /// properties of one block are — and that is the TIGHT END of check 11b's
    /// ladder. The clause asks for a gap of 17pt or less AND one of 48 or more
    /// on the same page, because a page whose gaps all sit in the middle has
    /// one spacing and one spacing groups nothing (P1). These two controls are
    /// one answer to one question, what does this block look like, and the
    /// block below shows both of them at once, so they belong to each other
    /// more than either belongs to the name above or the block below.
    ///
    /// **`gapItem` and not `gapTight`, and it was `gapTight` for one build.**
    /// Photographed, 8 put the row of discs almost on the segmented control's
    /// track: 11.0pt measured vertically against the 14pt that separates two
    /// circles horizontally on the same row, so the group was tighter than its
    /// own internal rhythm and read as a collision rather than as a pair. 12
    /// measures 15.0 with a swatch ringed, which is the state this sheet opens
    /// in, and 17.0 at the worst — a bare 34pt circle in its 44pt box — which
    /// is still inside 11b's ceiling. `gapTight` is for a glyph and its label;
    /// these are two controls.
    ///
    /// **The two small-caps labels are gone** (2026-10-01). `COLOUR` stood over
    /// six saturated discs and `SIZE` over a three-way segmented control
    /// reading Quick / Regular / Deep, and the owner's instruction for this
    /// pass names exactly that: "the areas are very self explanitory and I
    /// think over explaining components loses the charm". Two reasons beyond
    /// the obvious one:
    ///
    /// - **The screen demonstrates both.** Press a disc and the block below
    ///   turns that colour; press Deep and it becomes four times the size.
    ///   That is what putting the well AFTER the controls bought, and a label
    ///   describing a demonstration you can watch is the caption-under-a-
    ///   picture pattern the copy audit is built to find.
    /// - **`COLOUR` was slightly untrue.** Pressing a disc sets `category`, not
    ///   a colour — that is what `categoryChosen` records and what
    ///   `QuickWinService.labels(showing:chosen:)` reads. The label named the
    ///   half of the fact that is not the half the control sets.
    ///
    /// **What it cost, checked rather than assumed.** VoiceOver read the word
    /// `COLOUR` as a plain element before the discs, so cutting it would have
    /// left a swipe landing on "Health, button" with nothing saying what the
    /// row is for. The row carries that as a container label now, which is the
    /// honest trade: the fact survives for the people who needed it and the
    /// ink goes. Size never needed one — `Picker("Size", …)` keeps its label
    /// through `.labelsHidden()`, which hides a label and does not delete it.
    ///
    /// **And one cost that is NOT free, written down rather than hidden.** In
    /// the one state where the colour row is suppressed — a new win that
    /// arrived with a photograph already on it — this group is the size picker
    /// alone, so the sheet has no gap at 17pt or under left on it and fails
    /// 11b. It used to have one: the 11.0 between `SIZE` and its own picker.
    /// That state has three content bands (the name, the picker, the block),
    /// which is the case 11b's own text exempts in spirit — "a page of two or
    /// three bands has nothing to group" — but the clause is written in gaps
    /// rather than bands, so it reads as a failure. No capture of that state
    /// exists yet, and putting both labels back everywhere to satisfy a clause
    /// one state cannot otherwise meet would be the audit measuring itself.
    private var decisions: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                    // **No colour question while you are taking the photo.**
                    //
                    // A block with a picture on it shows the picture; the
                    // colour underneath is never seen, so asking for it at
                    // capture is a decision that changes nothing you can see,
                    // on the one screen that has to be fast. The same
                    // reasoning took the category colour off map blocks that
                    // carry a photograph.
                    //
                    // **But it is there when you come back to the win.** The
                    // owner's call (2026-09-13): optional, in Edit. What kind
                    // of win it was still means something to a Focus filter,
                    // and somebody who cares can say so without everybody
                    // being asked every time.
                    //
                    // The category is KEPT, not cleared — remove the
                    // photograph and the block needs its colour back, and
                    // silently discarding a choice somebody made would be
                    // worse than hiding the control.
                    if photo == nil || isEditing {
                        categoryControl
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    sizeControl
        }
        .padding(.top, GridConstants.gapPage)
    }

    /// **What you made.** The block, and in Edit the one thing you can do to
    /// it that is not a property of it.
    ///
    /// `gapSection` between them, which is what the pair already measured
    /// (32.0pt) when the button carried `gapWide` plus its own 8 of top
    /// padding — two numbers summing to a rung, which is how a rung stops
    /// being one.
    private var subject: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapSection) {
                    // **THE WELL IS LAST, AND IT IS THE BIGGEST THING HERE.**
                    //
                    // It used to sit second, a 96pt square under the title, and
                    // the sheet ended at 445pt on an 874pt screen — measured,
                    // FORTY-NINE PERCENT of it empty. A form that fills the top
                    // half and abandons the bottom is not a composition.
                    //
                    // Two things fix it at once, and they are the same move.
                    // The well is the one control whose job is to show you what
                    // you are making, so it belongs AFTER the two controls that
                    // decide what that is — you pick the size and watch the box
                    // become it, which is cause before effect rather than a
                    // preview that updates behind you. And sized off the page
                    // rather than off a hard-coded 96, it is big enough to be
                    // the subject: a Deep block fills the width, a Quick one is
                    // a quarter of that, and the difference between the
                    // smallest thing you can log and the biggest is something
                    // you can see across the room.
                    //
                    // It also puts the largest target on the most valuable
                    // action, which is the one law of this screen: a win with a
                    // photograph is what the whole app is for.
                    photoWell

                    if isEditing {
                        deleteButton
                    }
        }
    }

    // MARK: - Pieces

    private var cameraCover: some View {
        Group {
            // No count passed: the tally belongs to the tower's camera, and
            // with nothing to put in it the grid line runs unbroken.
            CameraView(
                onCaptured: { image, drawn, where_, window in
                    photo = image
                    photoChanged = true
                    crop = window
                    // A size drawn out of the shutter wins over the sheet's
                    // own picker: it is the more recent thing you said, and
                    // you said it with your hand.
                    size = drawn
                    place = where_
                    showCamera = false
                },
                onClose: { showCamera = false },
                fillsScreen: true
            )
            // No colour-scheme override on this one.
            //
            // A `preferredColorScheme` inside a full-screen cover still
            // reaches the window, so opening the camera from the add sheet
            // flipped the whole app dark and flipped it back on dismiss — the
            // screen lurching around a photo you were only trying to attach.
            // The status bar renders white over the black viewfinder on its
            // own, so it bought nothing.
        }
    }

    @ViewBuilder
    private var peekCover: some View {
        Group {
            if let shown = photo {
                PhotoPeek(
                    image: shown,
                    onClose: { peeking = false },
                    onReplace: {
                        // Close first: asking UIKit to present a sheet while
                        // another is still dismissing drops the second one
                        // silently, which is the same trap the plan sheet
                        // documents.
                        peeking = false
                        choosingSource = true
                    },
                    onRemove: {
                        peeking = false
                        photo = nil
                        photoChanged = true
                    })
            }
        }
    }

    // **`field(_:_:)` is DELETED** (2026-10-01, the room pass). It wrapped a
    // control in a `FormSectionLabel` plus `gapTight`, and it had two callers:
    // `COLOUR` and `SIZE`, both of which are cut. The thing worth keeping out
    // of it is on `decisions` above — a label and the control it heads are
    // `gapTight` apart, which is the rung, and `FormSectionLabel` is still the
    // app's one correct section label wherever a section does need naming.

    /// The photo, shown as the block will show it.
    ///
    /// It is the block's own aspect ratio and the block's own corner radius, so
    /// what you frame here is what ends up on the tower — a square well for a
    /// square block, wide for a wide one. Tapping it opens the camera; tapping
    /// a photo you already took replaces it.
    /// See the Toolbars note in `MainAppView`. iOS 26 puts a glass capsule behind
    /// every toolbar item; this app strips it, and a screen that misses the
    /// treatment looks unlike its neighbours and can render that capsule black
    /// against the warm ground — which is what happened on the plan sheet.
    @ToolbarContentBuilder
    private var addWinToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .cancellationAction) { cancelButton }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .confirmationAction) { confirmButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .cancellationAction) { cancelButton }
            ToolbarItem(placement: .confirmationAction) { confirmButton }
        }
    }

    // **One toolbar-action style for every sheet**: `headerSmall`, as
    // Profile, Settings, Plan and the plan line's Done already are. These were
    // the system body size, so "Add" stood visibly bigger than Profile's
    // "Done". Confirm wears the accent; Cancel stays the quieter ink, as the
    // head maker's Retake does beside its Save.
    private var cancelButton: some View {
        Button {
            HapticsEngine.lightTap()
            dismiss()
        } label: {
            // **44, measured.** Bare `Text` in a toolbar measured 68 by 36 off
            // the accessibility tree. `PlanSheet` carries the same fix with
            // the owner's own words on it, "really easy to miss click", and
            // this sheet never got it.
            Text("Cancel").font(Typography.headerSmall)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(AppColors.inkSecondary)
    }

    private var confirmButton: some View {
        Button { Task { await save() } } label: {
            Text(isEditing ? "Save" : "Add").font(Typography.headerSmall)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
            .disabled(!canSave)
            .foregroundStyle(canSave ? AppColors.accentWarm : AppColors.inkQuiet)
    }

    private var photoWell: some View {
        // The well is the block, at the block's real proportions.
        //
        // It was `.aspectRatio` on a full-width frame, so Quick (1x1) and Deep
        // (2x2) are both square and both came out the same size — the one
        // control whose job is to show you what you are making showed no
        // difference between the smallest thing and the biggest. It is sized
        // from the grid now: one cell for Quick, two across for Regular, two
        // across and two down for Deep, using the same cell pitch and corner
        // radius the tower uses. Picking Deep makes the box visibly bigger,
        // because the block is.
        // **Half the page, less the gutter**, so a two-wide block is the
        // content width exactly and a one-wide one is half of it. It was a
        // hard-coded 96 — a number with no relationship to anything on screen,
        // which is why the well read as a thumbnail on a page it was supposed
        // to be the subject of.
        let cell = (UIScreen.main.bounds.width
                    - GridConstants.horizontalPadding * 2
                    - GridConstants.spacing) / 2
        let gap = GridConstants.spacing
        let wellRadius = GridConstants.blockCornerRadius(forCell: cell)
        let w = CGFloat(size.columnSpan) * cell + CGFloat(size.columnSpan - 1) * gap
        let h = CGFloat(size.rowSpan) * cell + CGFloat(size.rowSpan - 1) * gap

        return Button {
            HapticsEngine.lightTap()
            // **A photograph you can see is a photograph you can open.**
            //
            // Tapping the well always opened the "add a photo" dialog, even
            // when it already had one on it — so the one thing the well
            // obviously invites you to do, look at the picture, was the one
            // thing it would not do. The owner: "why when you click on a photo
            // in the edit menu you arent able to view the photo."
            //
            // Empty, it still asks where to get one. Full, it shows it, and
            // replacing or removing moves to a long press — which is where
            // iOS puts a secondary action on something you are mainly looking
            // at.
            if photo == nil { choosingSource = true } else { peeking = true }
        } label: {
            ZStack {
                // **THE WELL IS THE BLOCK, NOT A HOLE WHERE ONE GOES.**
                //
                // It was a recess in `slotInk` at 3.5% with a DASHED 1.5pt
                // border, and three things were wrong with that at once.
                //
                // The dash exists nowhere else in this app. The comment above
                // it claimed it matched "the tower's empty slot", and the
                // tower's slot is a solid stroke; so the one thing on this
                // sheet that said it was quoting the system was quoting
                // something that does not exist.
                //
                // The border was `slotInk.opacity(0.26)`, which the audit
                // measured on the tower at 1.39:1 against the page. The
                // largest object on the sheet was outlined in a line you
                // cannot see.
                //
                // And the hierarchy was upside down. The well is the biggest
                // thing here by a long way, and a photograph is the one
                // OPTIONAL part of a win, so the sheet gave its loudest
                // position to its quietest content and drew it as an absence.
                //
                // So it is drawn as the block it is making, through
                // `BlockSurface` and `EtherealFill`: the same surface, rim,
                // wash and corner the tower uses. Pick a colour and the block
                // turns that colour. Pick a size and it becomes that size.
                // Add a photograph and the photograph becomes the block, which
                // is literally what happens when it lands. The sheet stops
                // describing the win and starts showing it, the empty space
                // below it is filled by the subject rather than by a hole, and
                // every value on it comes from the block system instead of
                // from three numbers written here.
                BlockSurface(
                    cornerRadius: wellRadius,
                    // A photograph gets the lighter wash, as `BlockFace` gives
                    // it: 0.10 of white over a picture floors the composite and
                    // caps white text below 4.5:1 however dark the picture is.
                    washOpacity: photo == nil ? GridConstants.blockScrimOpacity : 0.06
                ) {
                    if let photo {
                        // **Bounded here, not only by the frame below.**
                        //
                        // `scaledToFill` with nothing to fill wants the image's
                        // natural size — three thousand points across for a real
                        // photograph — and `clipShape` clips DRAWING, not hit
                        // testing. So the well's touch area covered the whole
                        // sheet and swallowed taps on the title field above it:
                        // the owner's report was "once a photo is added you can
                        // edit the title no more". Nothing errored, nothing looked
                        // wrong, the field simply stopped answering.
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: w, height: h)
                            .clipped()
                    } else {
                        Rectangle().fill(EtherealFill.fill(category.style.baseColor))
                    }
                }
                .frame(width: w, height: h)

                if photo == nil {
                    // **THE GLYPH NEEDS A GROUND, AND WHITE ALONE CANNOT GIVE
                    // IT ONE.**
                    //
                    // Measured on the built sheet with the red category
                    // chosen: a white camera on rgb(251, 107, 97) came out at
                    // 2.70:1, under the 3:1 a graphic has to clear. And no
                    // amount of white fixes it, because white against this red
                    // tops out at 2.78 whatever weight or size it is drawn at.
                    // Contrast does not improve with boldness.
                    //
                    // A block's own LABEL clears it because `BlockWash` lifts
                    // the bottom 26% of every block toward white and the label
                    // sits in that band. This glyph is in the middle, where
                    // there is no wash, so it has to bring its own.
                    //
                    // The disc is the pattern this file already uses for the
                    // replace affordance on a filled well, at the same 0.35,
                    // so a photographed block and an unphotographed one answer
                    // in one language.
                    // **"Add a photo" is DELETED** (2026-10-01, the type pass).
                    //
                    // It was a 13pt line under the glyph, and the glyph is a
                    // camera in a disc in the middle of an EMPTY photo well:
                    // the caption said what the thing beside it already showed.
                    // It was also conditional on `size != .small`, so the well
                    // captioned itself on two of the three block sizes and not
                    // on the third — one object with two different amounts of
                    // writing on it depending on how big it was drawn, which is
                    // the thing the owner named ("I hate when there is like one
                    // type of font next to another").
                    //
                    // Nothing is lost to VoiceOver: the well's own
                    // `.accessibilityLabel` below is already "Add a photo".
                    // The `VStack` went with the caption — one child does not
                    // need a stack.
                    Image(systemName: "camera.fill")
                        // An icon size from a token, which also scales with
                        // Dynamic Type (CLAUDE.md, Conventions). A weighted
                        // text style does neither.
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                        .foregroundStyle(.white)
                        .padding(GridConstants.gapItem)
                        .background(Circle().fill(.black.opacity(0.35)))
                }
            }
            .frame(width: w, height: h)
            // And the hit area is the shape, not whatever the content grew to.
            .contentShape(RoundedRectangle(cornerRadius: wellRadius, style: .continuous))
            // No overlay stroke. `BlockSurface` draws the rim, which is the
            // whole point of going through it: a block's edge is a gradient
            // that follows the light, not a flat line, and a second stroke
            // over it was the "two shadows under one object" fault in
            // another costume.
            .overlay(alignment: .bottomTrailing) {
                if photo != nil {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .iconSize(GridConstants.iconMedium, relativeTo: .caption2, weight: .medium)
                        .foregroundStyle(.white)
                        .padding(GridConstants.gapTight)
                        .background(Circle().fill(.black.opacity(0.35)))
                        .padding(GridConstants.gapTight)
                }
            }
            // Grows from the top left, where a block is anchored, so the
            // change reads as the block getting bigger rather than as the box
            // moving.
            //
            // No `.animation` here. Changing the size is ONE change and it has
            // to be one animation: this modifier ran the well on `slotSnap`
            // while the button's fill and everything the well pushes down the
            // page ran on the `motionSmooth` of the `withAnimation` that set
            // the value — two springs at different rates and different
            // damping, which is exactly why the parts looked like they were
            // moving separately. The transaction at the source now covers all
            // of it.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo == nil ? "Add a photo" : "Replace the photo")
    }

    /// Colour, as circles.
    ///
    /// These were briefly blocks, on the rule that every surface you can act
    /// on is one. The owner preferred the circles (2026-09-09) and that
    /// settles it: a swatch is not a block you are placing, it is a property
    /// of the block you are describing, and a round chip reads as a property
    /// in a way a small square does not. The blocks are still what the SIZE
    /// control and the photo well are made of.
    /// Whether to ring the swatch the win is on.
    ///
    /// Always, where the colour can be seen: no photograph, so the ring marks
    /// the colour of the block. With a photograph the colour cannot be seen,
    /// so a ring would only be claiming a kind of win — and for a win nobody
    /// gave one, that claim is untrue. So there it rings only a real choice.
    private var showsSelection: Bool {
        photo == nil || categoryChosen || (editing.map { $0.category != .unlabeled } ?? false)
    }

    private var categoryControl: some View {
        // 4pt, the grid's own gutter. The circles are 34 inside 44pt targets,
        // so there is already 10pt of air between them before any spacing at
        // all; the 6 this was is simply not a rung.
        // **PULLED BACK ONTO THE MARGIN.**
        //
        // Measured off the built sheet: the title's text, the photo well and
        // the COLOUR label all start at 16pt, and the first swatch started at
        // 21. A 34pt circle centred in its 44pt tap frame leaves five points of
        // air on its leading edge, so the row LOOKED five points indented while
        // every number in the layout said it was not.
        //
        // The frame keeps its 44 — the target is not negotiable — and the row
        // is shifted by exactly the air. `GridConstants.tallyOpticalInset` is
        // the same correction for the same reason on the tower's count, and
        // CLAUDE.md records why: a box aligned to the grid still LOOKS indented
        // next to something whose ink goes to its own edge.
        HStack(spacing: GridConstants.spacing) {
            ForEach(HabitCategory.selectable, id: \.self) { cat in
                let isSelected = showsSelection && category == cat
                Button {
                    HapticsEngine.tick()
                    categoryChosen = true
                    withAnimation(GridConstants.motionSmooth) { category = cat }
                } label: {
                    ZStack {
                        // The same object a block is: lit from inside, with
                        // the same rim. See `ColourSwatch`.
                        ColourSwatch(colour: cat.style.baseColor, side: Self.swatchSide)
                        if let icon = cat.iconName {
                            Image(systemName: icon)
                                .iconSize(13, relativeTo: .footnote, weight: .medium)
                                .foregroundStyle(.white)
                        }
                        if isSelected {
                            Circle()
                                // **`inkPrimary`, not `.primary.opacity(0.75)`.**
                                // CLAUDE.md's rule is that this is not a colour,
                                // it is a colour in light mode: 75% black on a
                                // near-white page and 75% white on a near-black
                                // one, which are not the same weight. The token
                                // is the adaptive form of exactly this ink, and
                                // Profile's own swatch ring now wears it too.
                                // **IT HUGS THE SWATCH, AND IT IS NOT BLACK.**
                                //
                                // A full-strength `inkPrimary` ring at 42
                                // around a 34pt circle is a hard black outline
                                // floating four points off the thing it
                                // selects — the only pure ink ring in the app,
                                // on a row of pastels, which made the chosen
                                // colour look stickered rather than chosen.
                                //
                                // 38 sits on the swatch's own edge with two
                                // points of air, and 0.55 ink is still
                                // unmistakable against every colour in the
                                // palette while reading as a mark on the row
                                // rather than a hole cut in it. Selection has
                                // to be obvious; it does not have to shout.
                                .strokeBorder(AppColors.inkPrimary.opacity(0.55),
                                              lineWidth: GridConstants.strokeMedium)
                                .frame(width: Self.selectionRingSide,
                                       height: Self.selectionRingSide)
                        }
                    }
                    .frame(width: Self.swatchTarget, height: Self.swatchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cat.rawValue)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        // The air inside the leading swatch's tap frame, taken back out. See
        // the note above.
        .padding(.leading, -Self.swatchInset)
        // **The word `COLOUR` is gone from the page and kept for VoiceOver.**
        //
        // `.contain` rather than `.combine`: the six discs stay individually
        // focusable and individually selectable — combining them would make
        // the row one element and take the choice away from the people this
        // is for. What the container adds is the sentence the deleted label
        // used to read out, announced on entering the row.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Colour")
    }

    /// The selection ring's diameter: on the swatch's own edge, two points
    /// outside a 34pt circle.
    static let selectionRingSide: CGFloat = 38

    /// The HIG's minimum target, measured not declared, and the box every
    /// swatch is drawn inside. It was the literal 44 in the row and again
    /// inside `swatchInset`, which is two copies of one number.
    ///
    /// Not `private`: `SheetRoomTests` works out, from this and the ring, how
    /// much empty box a measured gap above the colour row carries, and
    /// therefore whether the tight end of the sheet's ladder still clears
    /// check 11b's 17pt ceiling.
    static let swatchTarget: CGFloat = 44

    /// A swatch's own artwork, unringed. It was the literal 34 at the one call
    /// site; `PlanItemDetailSheet` names the same number for the same reason
    /// and says it was typed three times in one expression there.
    ///
    /// Not `private`: it is the WORST case for the air a measured gap above
    /// this row carries, since a swatch with no selection ring on it is 5pt
    /// narrower than its box on each side rather than 3.
    static let swatchSide: CGFloat = 34

    /// Half the difference between the 44pt target and the WIDEST thing drawn
    /// inside it, which is the 38pt ring and not the 34pt circle.
    ///
    /// Measured off the built sheet with a colour chosen: the ring's leading
    /// edge came out at 14.0 while the name, both labels, the picker and the
    /// well all start at 16. The pass that pulled this row onto the margin
    /// measured the chip and left the mark two points outside it, so the row
    /// was on the margin exactly until you used it.
    ///
    /// The price is that the six circles sit at 18.0 instead of 16.0. That is
    /// the better trade: two points on a row of round shapes is invisible,
    /// because a circle's optical edge is inside its box anyway, and a mark
    /// that appears and shoves the row off the margin is a thing that moves.
    static let swatchInset: CGFloat = (swatchTarget - selectionRingSide) / 2

    /// Size, named.
    ///
    /// It was briefly the three shapes at true proportion, which is more
    /// honest about what a size IS — and the owner preferred the words
    /// (2026-09-09). They are right that this is the one place a name helps:
    /// the shapes tell you the geometry, the words tell you what the geometry
    /// is FOR, and "Deep" is the thing you are actually choosing.
    private var sizeControl: some View {
        // **The platform's control for three exclusive options.**
        //
        // This was three hand-built buttons with their own fill, corner and
        // selected state — a segmented control re-implemented, and it looked
        // like one that had been re-implemented: "the buttons like quick,
        // regular, deep i wish they were more apple buttons." `Picker` IS the
        // control, it comes with the selection indicator, the sliding
        // animation, the keyboard and VoiceOver behaviour, and on iOS 26 the
        // system's own glass treatment — none of which the hand-built version
        // had.
        //
        // The haptic and the shared transaction stay: changing this resizes
        // the photo well and moves everything under it, and that has to be ONE
        // animation or the parts look like they are moving separately.
        Picker("Size", selection: Binding(
            get: { size },
            set: { chosen in
                guard chosen != size else { return }
                HapticsEngine.tick()
                withAnimation(GridConstants.slotSnap) { size = chosen }
            })) {
            ForEach([BlockSize.small, .medium, .hard], id: \.self) { option in
                Text(option.effortLabel).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// **The red the delete button is tinted, and it is TWO reds** (2026-10-01).
    ///
    /// It was one: `0xB3000F`, a fixed hex, and the note on it recorded a
    /// careful light-mode measurement — a pill of (231, 199, 201) with its
    /// label at 4.59:1, against systemRed's 2.54 and `D70015`'s 3.50. Every one
    /// of those numbers is still true and every one of them was taken on the
    /// light page only.
    ///
    /// **This is CLAUDE.md's "an ink is not a surface" for the fifth time**, and
    /// it is the one the rule's own list does not have: a colour that is BOTH.
    /// `.bordered` draws the label at the tint and the fill from the same tint
    /// over the page, so a tint tuned to sit dark on a 247 ground sits dark on a
    /// 28 one too, where dark is what the ground already is. Measured off the
    /// built Edit sheet at 402x874, dark:
    ///
    /// |  | light | dark, before | dark, after |
    /// |---|---|---|---|
    /// | label on its own pill | 4.56:1 | **2.20:1** | **3.96:1** |
    /// | pill against the page | 1.47:1 | **1.08:1** | **1.42:1** |
    ///
    /// 2.20 on the one control in this app that destroys a win, and a pill one
    /// level off the page it stands on, so what was actually on screen in the
    /// dark was a dim red word floating in the margin. Both numbers are
    /// measured off the built Edit sheet, before and after, not computed.
    ///
    /// **4.5 is not reachable here and that is a property of the style, not of
    /// the red.** The label and the fill come from the same colour, so on a dark
    /// page brightening the tint brightens both: the label's luminance stays
    /// about 6x the fill's whatever the red, and with the WCAG formula's +0.05
    /// floors that caps the pair around 4. The render agrees with the
    /// arithmetic — rgb(255, 92, 84) on a pill of rgb(83, 43, 40) is **3.96**,
    /// and systemRed's own dark value computes to 3.89, so there is about a
    /// tenth of a point left in the whole red family. Clearing 4.5 means giving
    /// the label a second colour, or `.borderedProminent`, which is a white word
    /// on a solid red pill: louder than anything else on this sheet, and the
    /// settled call is that this button is the platform's. **So the number to
    /// beat was the 2.20, not the 4.5**, and the gap is written here rather than
    /// quietly passed. If it is ever worth closing, the lever is the style and
    /// not the colour.
    ///
    /// The dark value is the brightest red that still reads as a red rather than
    /// as a salmon, which is also where the measured return flattens out.
    static let destructiveTint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.361, blue: 0.329, alpha: 1)    // rgb(255, 92, 84)
            : UIColor(red: 0.702, green: 0.0, blue: 0.059, alpha: 1)    // 0xB3000F, unchanged
    })

    /// **The platform's destructive button, not a copy of one.**
    ///
    /// It was a hand-built pill: a plain button whose label carried its own
    /// red-tinted rounded rectangle. That is `.bordered` with a destructive
    /// role, re-implemented and slightly wrong — "look at delete button in
    /// edit it looks off stuff like that should be native looking."
    ///
    /// The whole app had 20 `.buttonStyle(.plain)` and not one native style,
    /// which is how every button ended up being a small act of invention. The
    /// departure from the platform is meant to be the camera, the blocks and
    /// the numbers; a delete button is none of those.
    private var deleteButton: some View {
        Button("Delete", role: .destructive) {
            HapticsEngine.tick()
            confirmingDelete = true
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(Self.destructiveTint)
        // **Its own width, pinned left.** Stretched edge to edge it was the
        // only centred thing on a form where every label, field and control
        // starts at the same left margin: "the delete button looks weird in
        // the add menu because everything else is left aligned." A native
        // button sizes to its content; making it full width was the last
        // piece of the hand-built version still hanging on.
        .frame(maxWidth: .infinity, alignment: .leading)
        // **No top padding of its own any more.** It carried `gapTight` on top
        // of the stack's `gapWide`, which is 32 written as two numbers; the
        // gap is `gapSection` on `subject` now, one rung, declared once.
    }

    // MARK: - Load, save, delete

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let initialPhoto {
            photo = initialPhoto
            photoChanged = true
        }
        // Before the editing branch below, which must still win: a habit being
        // edited already has a size and nobody drew a new one.
        size = initialSize
        place = initialPlace
        crop = initialCrop
        if let initialTitle, !initialTitle.isEmpty {
            title = initialTitle
        }
        if let habit = editing {
            title = habit.title == QuickWinService.untitled ? "" : habit.title
            category = habit.displayCategory
            size = habit.blockSize
            if let name = editingLog?.imageFileName {
                Task { photo = await ImageManager.shared.loadFullImage(fileName: name) }
            }
        } else {
            titleFocused = true
            // **A new win does not start green.**
            //
            // The default was `.health`, and the colour picker is hidden once
            // there is a photograph — so every photographed win in the app
            // was green, forever, with no way to say otherwise. From a phone:
            // "the blocks with images are only green no other color which
            // makes it look bad."
            //
            // It starts on whatever the tower has least of, which is the rule
            // the tower's own empty slot already picks by, so a wall of wins
            // comes out varied without anybody choosing.
            if let initialColour, initialColour != .unlabeled {
                category = initialColour
            } else {
                let existing = (try? modelContext.fetch(FetchDescriptor<Habit>())) ?? []
                category = QuickWinService.spontaneousCategory(existing: existing)
            }
        }
    }

    private func save() async {
        let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // `untitled` is the sentinel a nameless block already uses: the block
        // views check for it and draw no text at all, and the title field
        // shows it back as an empty placeholder rather than as the word "Win"
        // for you to delete.
        let trimmed = typed.isEmpty ? QuickWinService.untitled : typed
        guard !isSaving else { return }
        isSaving = true

        if let habit = editing {
            habit.title = trimmed
            // Only a pressed swatch rewrites what the win is. Opening a win
            // with no category and saving it used to promote the colour it
            // was wearing into a category it never had.
            if categoryChosen {
                habit.category = category
                habit.spontaneousCategoryRaw = nil
            }
            habit.blockSize = size
            try? modelContext.save()
            if photoChanged, let log = editingLog {
                if let photo {
                    await attach(photo, to: log)
                } else {
                    // Removing a photo used to do nothing at all: the dialog
                    // set `photo` to nil, and the save path only ever ran when
                    // there WAS a photo, so `imageFileName` was never cleared
                    // and the block kept its face.
                    //
                    // **The reference is cleared first and the file goes only
                    // if that saved.** It was the other way round, under a
                    // `try?`: the photograph was deleted, the save failed
                    // silently, and the block was left naming a file that no
                    // longer existed. `PhotoRemoval.removePhoto` is the same
                    // rule in the viewer.
                    let name = log.imageFileName
                    log.imageFileName = nil
                    do {
                        try modelContext.save()
                        if let name { ImageManager.shared.deleteImage(fileName: name) }
                    } catch {
                        NSLog("[strata-photo] could not remove the photo from the win, so the file stays: \(error)")
                        log.imageFileName = name
                    }
                }
            }
            HapticsEngine.success()
            onSaved(habit)
            dismiss()
            return
        }

        do {
            let labels = QuickWinService.labels(showing: category, chosen: categoryChosen)
            let win = try QuickWinService.logWin(
                title: trimmed,
                category: labels.category,
                size: size,
                spontaneous: labels.spontaneous,
                context: modelContext,
                tower: tower
            )
            // The photo is attached to the LOG the service just returned rather
            // than looked up afterwards. Re-deriving it from `habit.logs` is
            // exactly the lookup that intermittently came back empty.
            if let photo,
               let log = (win.habit.logs ?? []).first(where: { $0.id == win.logID }) {
                await attach(photo, to: log)
            }
            HapticsEngine.success()
            onSaved(win.habit)
            dismiss()
        } catch {
            isSaving = false
        }
    }

    /// Writes the image to disk and points the log at it.
    ///
    /// Saved before the sheet closes, not after: the tower reads
    /// `imageFileName` on its next build, and a block that arrives with no face
    /// and grows one a moment later is the flash this avoids.
    /// The photograph is stored WHOLE, not cropped to the block it is going on.
    ///
    /// It used to be trimmed to the block's aspect before writing, on the
    /// reasoning that the block clips it anyway so the rest is bytes nobody can
    /// see. That is true right up until the block is resized — and then the
    /// already-cropped picture was loaded back, cropped AGAIN to the new
    /// aspect, and written. Every resize cropped the crop, so the subject
    /// zoomed further out of frame each time until it was gone.
    ///
    /// `CachedImageView` draws with `.scaledToFill()`, so the block crops to
    /// its own shape at display time, from the whole image, every time. Which
    /// means a resize now re-frames rather than re-crops, and is reversible.
    private func attach(_ image: UIImage, to log: HabitLog) async {
        let id = log.id
        // The place is written HERE, in the same block that writes the file
        // name, because a coordinate on a log with no photograph is a pin with
        // nothing to show. The two facts arrive together and are stored
        // together.
        if let place {
            log.latitude = place.latitude
            log.longitude = place.longitude
            log.locationAccuracy = place.accuracy
        }
        // Where the block's window sits on the picture. Zero is the middle,
        // which is every win nobody dragged.
        log.cropPositionX = crop.x == 0 ? nil : crop.x
        log.cropPositionY = crop.y == 0 ? nil : crop.y
        // The file this is replacing, if any. Deleted only AFTER the new one
        // is safely written — the other order loses the photograph outright if
        // the save fails.
        let previous = log.imageFileName
        // **Awaited, not launched.** This used to be an unstructured `Task`,
        // so the write finished AFTER `dismiss()` — and the filename never
        // reached the log. Proved by driving the real picker and then reading
        // the store: the photograph was on disk, referenced by no win at all,
        // an orphan the moment it was written. Every photograph anyone added
        // was lost this way, which is why blocks kept their colour and the
        // gallery stayed empty.
        //
        // The comment above once claimed this was "saved before the sheet
        // closes". It is now true.
        if let name = try? await ImageManager.shared.save(image: image, for: id) {
            log.imageFileName = name
            // Not `try?`: a save that fails here is a photograph written to
            // disk that no win points at, and silence is how that stays
            // invisible.
            do { try modelContext.save() } catch { NSLog("[strata] photo save failed: \(error)") }
            if let previous, previous != name {
                ImageManager.shared.deleteImage(fileName: previous)
            }
        }
    }

    private func deleteIt() {
        guard let habit = editing else { return }
        // **The photographs go with it.** Deleting the rows and leaving the
        // files was one of three leaks that put 3127 images and 522MB on a
        // phone. Read the names BEFORE the entities go, or there is nothing
        // left to read them from.
        let names = (habit.logs ?? []).compactMap(\.imageFileName)

        // **Object by object, in one transaction, and never `try?`.** The rows
        // go first and the photographs only if they went: a delete that fails
        // silently while the files are already gone is the shape of the bug
        // that left Reset All Data deleting pictures and keeping wins.
        do {
            try modelContext.transaction {
                for log in habit.logs ?? [] { modelContext.delete(log) }
                PlanItem.untick(planItemID: habit.planItemID, context: modelContext)
                modelContext.delete(habit)
            }
        } catch {
            NSLog("[strata-delete] could not delete the win, so its photographs stay: \(error)")
            return
        }
        for name in names { ImageManager.shared.deleteImage(fileName: name) }
        HapticsEngine.tick()
        onDeleted()
        dismiss()
    }
}

/// A photograph, full screen, and a way out.
///
/// **Not `PhotoViewer`.** That one is a deck: it needs a whole run of saved
/// `GalleryPhoto`s to page through and a file name to load from disk. The
/// photograph on the add sheet may be neither — it can be a `UIImage` that has
/// not been written anywhere yet, taken thirty seconds ago. So this is the
/// smaller thing: one picture, fitted, on the app's black, with the same glass
/// close button the viewer uses.
/// The photograph, full screen, with the two things you can do to it.
///
/// **Replacing used to be reachable only by long-pressing the well.** It was
/// there the whole time, in a `.contextMenu`, which is to say it was invisible:
/// from a device, "there is no way to replace a photo now when viewing it
/// clicking on it." A gesture nobody performs is the same as a feature that
/// does not exist.
///
/// So the actions live where you already are once you have tapped the picture,
/// behind the same `⋯` the main photo viewer uses. The long press still works
/// for anyone who found it.
private struct PhotoPeek: View {
    let image: UIImage
    var onClose: () -> Void
    var onReplace: (() -> Void)?
    var onRemove: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
                .padding(.horizontal, GridConstants.horizontalPadding)

            VStack {
                HStack {
                    GlassIconButton(systemName: "xmark", tint: .white,
                                    accessibilityLabel: "Close", action: onClose)
                    Spacer(minLength: 0)
                    if onReplace != nil || onRemove != nil {
                        Menu {
                            if let onReplace {
                                Button {
                                    HapticsEngine.lightTap()
                                    onReplace()
                                } label: {
                                    Label("Replace Photo", systemImage: "photo.on.rectangle")
                                }
                            }
                            if let onRemove {
                                Button(role: .destructive) {
                                    HapticsEngine.warning()
                                    onRemove()
                                } label: {
                                    Label("Remove Photo", systemImage: "trash")
                                }
                            }
                        } label: {
                            GlassIconLabel(systemName: "ellipsis", tint: .white)
                        }
                        .accessibilityLabel("Photo actions")
                    }
                }
                .padding(.horizontal, GridConstants.horizontalPadding)
                .padding(.top, GridConstants.gapItem)
                Spacer(minLength: 0)
            }
        }
        .statusBarHidden()
    }
}
