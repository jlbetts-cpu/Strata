import SwiftUI
import SwiftData
import UserNotifications
import StoreKit
// For `UTType.zip`, which is what the file importer accepts: a backup is one
// zip, and naming the type stops somebody handing this a photograph.
import UniformTypeIdentifiers

/// **Settings is PUSHED from Profile, which is the only way in, and that is why
/// it has no Done.** The sentence used to be the doc on an `isPushed` flag that
/// both call sites set to `true`; the flag is deleted and the sentence is true
/// of the type (`docs/consistency-audit.md` §1.4, and the record of what went is
/// at the bottom of this file). A pushed screen has a back button, and a Done
/// that called `dismiss()` would only pop back to Profile — two controls that
/// both mean "back".
struct SettingsView: View {
    /// Returns whether the record was actually emptied.
    var onResetAllData: (() -> Bool)?

    /// Still read: `runReset` leaves the screen once the record is actually
    /// emptied, and stays on it with the reason if it is not.
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var habits: [Habit]
    @Query private var logs: [HabitLog]

    // MARK: - Notification State

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 8
    @AppStorage("reminderMinute") private var reminderMinute = 0

    // #172/#173: Tower appearance toggles
    /// The same defaults key `PhotoLibrarySaver` reads, so the toggle and the
    /// service share one source of truth rather than mirroring each other.
    /// Both default to on.
    @AppStorage(PhotoLibrarySaver.defaultsKey) private var savesToCameraRoll = true
    @AppStorage(LocationService.defaultsKey) private var remembersPlaces = true
    /// On by default, the same default `ReplayReminder.isEnabled` registers.
    @AppStorage(ReplayReminder.defaultsKey) private var replayRemindersOn = true
    @AppStorage(PastWinReminder.defaultsKey) private var pastWinRemindersOn = true
    /// Off by default (spec section 2). `JournalLock` reads the same key.
    @AppStorage(JournalLock.defaultsKey) private var locksJournal = false
    @State private var location = LocationService.shared
    @State private var replayOnboarding = false
    /// The sample replay being previewed, from the Replays section.
    @State private var previewing: Replay?

    /// What the photographs are costing, in the units a phone uses.
    ///
    /// **Measured once, off the main thread, not per body evaluation.** It was
    /// a computed property that walked the image directory — so every time
    /// SwiftUI re-evaluated this screen, which is every toggle and every
    /// scroll, it did file I/O on the main thread to produce a string almost
    /// nobody was reading yet. That is exactly the kind of thing that makes an
    /// app feel heavy for no reason anybody can point at.
    @State private var storageLine = " "

    private func measureStorage() async {
        let used = await Task.detached(priority: .utility) {
            ImageManager.shared.storageUsed()
        }.value
        guard used.count > 0 else { storageLine = "No photographs stored yet."; return }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let size = formatter.string(fromByteCount: used.bytes)
        storageLine = "\(used.count) photograph\(used.count == 1 ? "" : "s"), \(size)."
    }
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var reminderTime = Date()
    @State private var systemNotificationsDenied = false

    // MARK: - Sheet State

    @State private var showResetConfirmation = false
    /// Reset All Data did not commit. Shown HERE, not on `MainAppView`: this
    /// screen is pushed inside the Profile sheet, and a view presenting a sheet
    /// cannot put an alert on screen, so the message used to be raised where
    /// nobody could see it.
    @State private var resetFailed = false
    @State private var showExportShare = false
    @State private var exportURL: URL?
    /// The backup could not be built. Every failure in `exportData` used to
    /// `return` in silence, so pressing the button did nothing at all and
    /// there was no way for anyone to say what had happened. Shown here for
    /// the same reason as `resetFailed`.
    @State private var exportFailed = false
    /// Which step of the backup failed, so the alert says something a person
    /// can act on rather than one sentence covering five different faults.
    @State private var exportFailure = ""

    // MARK: - Restore

    /// The file picker for a backup zip.
    @State private var showRestorePicker = false
    /// The picked file, copied into this app's temporary directory.
    ///
    /// **A copy, not the picked URL.** A document picker hands back a
    /// security-scoped URL whose access has to be started and stopped, and a
    /// restore reads it twice — once to count what is inside, and again for
    /// every photograph after somebody confirms. Copying first means nothing in
    /// the flow depends on how long the file provider keeps that URL alive, and
    /// a file that is on iCloud Drive rather than on the phone is pulled down
    /// once, here, where the failure has a message.
    @State private var restoreZip: RestoreBackupView.Picked?
    /// The picked file could not even be copied. Shown for the same reason as
    /// every other message on this screen: the alternative is a row that does
    /// nothing.
    @State private var restoreFailure = ""

    // MARK: - App Info

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        // **The reader exists so the LOWER half of this page can be
        // photographed.** This screen is seven sections and about 1,500pt tall,
        // nothing on this Mac can scroll a simulator, and every capture of it
        // in `docs/space.md` and `docs/screen-audit.md` is of the top third. So
        // the three footers under Camera, How Strata Works and Privacy — which
        // are where the 2026-10-01 copy cuts landed — had never been looked at
        // on a built screen by anybody. `-strataScrollSettings` fixes that.
        // See `scrollToAnchor`, and `ProfileView`'s copy of the same thing.
        ScrollViewReader { scroller in
        Form {
            // MARK: - Branded Header

            Section {
                VStack(spacing: GridConstants.gapItem) {
                    // The mark, not a five-block diorama.
                    //
                    // This was a little tower built from `MiniBlockPreview`,
                    // which had drifted a long way from the real block: a
                    // diagonal gradient and a frosted overlay, no rim, no band
                    // — the styling the tower left behind. `StrataMark` is
                    // drawn from `BlockSurface`, so it is the same object the
                    // rest of the app is made of and cannot drift again.
                    StrataMark(side: 72)

                    // **NO WORDMARK, HERE OR ANYWHERE** (2026-09-30). The
                    // owner: "keep it off everywhere for now, since we are
                    // going to change the name anyway."
                    //
                    // It came off the camera first, for a reason that was about
                    // that screen — the app's name over a live lens. This is
                    // the general case: every name in the running app is a
                    // name that has to be re-set the day it changes, and
                    // setting it in three places only means forgetting one.
                    // The mark above carries the identity until there is a
                    // name to carry.

                    // **The model plate, with the name taken out of it.**
                    //
                    // It read "Strata Neo 1.0 (34)", and that line earned its
                    // place: a name set beside a version and a build is what a
                    // device's plate looks like, which is the register the
                    // design was after, and it meant a reviewer opening the app
                    // found the full name without the app announcing itself.
                    //
                    // Both halves of that are on hold rather than wrong. The
                    // version is the half that is still true today; the name is
                    // the half that is about to change, and a plate carrying a
                    // name the App Store no longer agrees with is worse than a
                    // plate carrying none.
                    // `inkTertiary`, not `inkQuiet` (2026-10-02, design
                    // review): the plate is text somebody reads to a support
                    // email, and `inkQuiet` measured **3.32:1** here (rgb 135 on
                    // 246). `inkQuiet`'s own doc keeps it for glyphs.
                    Text(verbatim: appVersion)
                        .font(Typography.sectionLabel)
                        .kerning(Typography.sectionKerning)
                        .foregroundStyle(AppColors.inkTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Version \(appVersion)")
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            // **The gap above the mark was the biggest thing on the screen.**
            //
            // Measured off the built screen at 402x874: 96.0pt of empty page
            // between the title's cap and the top of the mark, against 69.7pt
            // between one section's card and the next. Check 7 asks that a
            // section break be the biggest gap on the page; this beat one by
            // 26.3pt, and it did it in the opening of the composition, so the
            // screen read as having been pushed down rather than laid out.
            //
            // Three things were stacked to make it: the list's own
            // first-section inset, the row's default vertical inset, and a
            // `gapWide` (24) added here on top of both. The 24 goes, the row's
            // own inset is written down rather than inherited, and what is left
            // is the one gap that belongs to the platform. The bottom inset
            // carries the `gapTight` the VStack used to pad with, so the number
            // lives in one place. Profile's identity section is now exactly the
            // same shape, for the same reason, so the two still read as one
            // place when you push from one to the other.
            .listRowInsets(EdgeInsets(top: 0,
                                      leading: GridConstants.horizontalPadding,
                                      bottom: GridConstants.gapTight,
                                      trailing: GridConstants.horizontalPadding))

            // MARK: - Section 1: Notifications

            Section {
                // **One black down the column.** Measured off the built
                // screen: a row whose label is inked `AppColors.inkPrimary`
                // renders (38, 38, 38) and a row left to the platform renders
                // (0, 0, 0). Preview Your Week and Daily Reminder are four rows
                // apart, the same rank, 15.1:1 beside 21:1.
                //
                // The buttons on this screen were inked a pass ago, because a
                // `Button` in a `Form` otherwise paints its label with the tint
                // and would have given Settings six blue rows against the one
                // accent check 5 allows. The toggles, the picker and the link
                // were not, because they do not take the tint, so nothing looked
                // wrong in the source. It looks wrong on the screen. The ink
                // goes on the `Text`, not on the row, so a disabled row still
                // greys.
                Toggle(isOn: $notificationsEnabled) {
                    Label {
                        Text("Daily Reminder")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "bell")
                    }
                }
                // **`switchTrack`, and all six of this page's switches were
                // `inkPrimary`, which is a dark-mode failure nobody had looked
                // at** (2026-10-01, `docs/consistency-audit.md` §1.3 plus check
                // 12, and the audit's own verdict was the one being corrected
                // here).
                //
                // The consistency half: Profile's four switches were
                // `AppColors.switchOn`, the blue, and these six were ink — two
                // colours for "on" on two screens one push apart, whose own doc
                // comments say they are built the same way so that "pushing from
                // one to the other reads as one place".
                //
                // The half that was not in the audit: `inkPrimary` is
                // `white.opacity(0.92)` in dark mode, so the ON track composites
                // to rgb(237) and the thumb iOS slides on it is WHITE. That is
                // **1.17:1**, and the owner's words about the last time this
                // happened are on `switchOn`: "the switch in the setthing in dark
                // mode it doesnt even look like a switch its like white on white
                // just looks like a pill." The audit sampled light mode only
                // (§3.9) and recommended spreading this to Profile.
                //
                // `switchTrack` is one fixed warm grey, computed against the
                // thumb and both grounds, and it carries the whole argument
                // including the one number that does not clear 3:1 and cannot be
                // made to. The page's other `.tint` — the one at the bottom, for
                // the `Form`'s links and pickers — stays `inkPrimary`, because
                // those are INK on a page and not a surface under a white knob.
                .tint(AppColors.switchTrack)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        Task { await requestNotificationPermission() }
                    } else {
                        Task { await DailyReminder.removePending() }
                    }
                }

                if notificationsEnabled {
                    // **It gets a glyph, because every other row has one.**
                    // This was the one row on either screen with no icon, so its
                    // label began in the icon column while the eleven rows
                    // around it began 43pt further in. A column that one row
                    // steps out of is not a column.
                    DatePicker(
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    ) {
                        Label {
                            Text("Reminder Time")
                                .foregroundStyle(AppColors.inkPrimary)
                        } icon: {
                            SettingsIcon(systemName: "clock")
                        }
                    }
                    .datePickerStyle(.compact)
                    .onChange(of: reminderTime) { _, newTime in
                        let calendar = Calendar.current
                        reminderHour = calendar.component(.hour, from: newTime)
                        reminderMinute = calendar.component(.minute, from: newTime)
                        HapticsEngine.tick()
                        scheduleReminder()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // `@AppStorage`, not a Binding over UserDefaults: SwiftUI is
                // told when the value changes, so the switch cannot show one
                // thing while the store holds another.
                Toggle(isOn: $replayRemindersOn) {
                    Label {
                        Text("Weekly and Monthly Replays")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "square.stack.3d.up")
                    }
                }
                .tint(AppColors.switchTrack)
                .onChange(of: replayRemindersOn) { _, on in
                    Task { on ? await ReplayReminder.schedule(context: modelContext) : await ReplayReminder.removePending() }
                }

                // An evening line about a past win, only on a day with one
                // of its own (`PastWinReminder`).
                Toggle(isOn: $pastWinRemindersOn) {
                    Label {
                        Text("A Past Win")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "clock.arrow.circlepath")
                    }
                }
                .tint(AppColors.switchTrack)
                .onChange(of: pastWinRemindersOn) { _, on in
                    Task { on ? await PastWinReminder.schedule(context: modelContext) : await PastWinReminder.removePending() }
                }
            } header: {
                FormSectionLabel("Notifications")
            } footer: {
                if systemNotificationsDenied && notificationsEnabled {
                    VStack(alignment: .leading, spacing: GridConstants.spacing) {
                        Text("Notifications are disabled in system settings.")
                            .formFooter()
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
            }
            .animation(reduceMotion ? .none : GridConstants.motionSnappy, value: notificationsEnabled)

            // MARK: - Sounds & Haptics

            // **One section, under Apple's own name.** Haptics had a section of
            // its own called "Feedback", and the same screen has a "Send
            // Feedback" row further down: one word meaning a buzz in one place
            // and an email in the other. What you hear and what you feel when a
            // win lands are the same question, and Settings on the phone
            // already answers it with this heading.
            Section {
                Toggle(isOn: Binding(
                    get: { !SoundEngine.isMuted },
                    set: { SoundEngine.isMuted = !$0 }
                )) {
                    Label {
                        Text("Completion Sounds")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "speaker.wave.2")
                    }
                }
                .tint(AppColors.switchTrack)

                Toggle(isOn: $hapticsEnabled) {
                    Label {
                        Text("Haptic Feedback")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "iphone.radiowaves.left.and.right")
                    }
                }
                .tint(AppColors.switchTrack)
            } header: {
                FormSectionLabel("Sounds & Haptics")
            }

            // MARK: - Replays

            // **Watch it before it happens.** A replay only arrives at the end of a week
            // or a month, so without this nobody could see what one looks like until
            // then. The preview is the real replay on sample wins, not a video of one.
            Section {
                // The ink is on the rows, not the Section: on the Section it
                // also inked the header, which then read darker and heavier
                // than every other heading on the screen.
                Button { previewing = ReplaySample.replay(.week, now: Date()) } label: {
                    Label { Text("Preview Your Week") } icon: { SettingsIcon(systemName: "square.stack.3d.up") }
                }
                .foregroundStyle(AppColors.inkPrimary)
                Button { previewing = ReplaySample.replay(.month, now: Date()) } label: {
                    Label { Text("Preview Your Month") } icon: { SettingsIcon(systemName: "calendar") }
                }
                .foregroundStyle(AppColors.inkPrimary)
            } header: {
                FormSectionLabel("Replays")
            }

            // MARK: - Camera

            Section {
                Toggle(isOn: $savesToCameraRoll) {
                    Label {
                        Text("Save to Photos")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "photo.on.rectangle.angled")
                    }
                }
                .tint(AppColors.switchTrack)

                // **The switch that fills the map lives beside the one that
                // fills the camera roll**, because they are the same decision
                // about the same photograph and looking for one in a different
                // section from the other is the app being inconsistent.
                // **"Keep Places", and it was "Remember Places"** (2026-10-01,
                // `docs/copy-audit.md`'s voice finding).
                //
                // "Remember" puts the APP in the role of something keeping
                // track of a person, which is the exact construction the
                // onboarding pass already rejected and wrote down:
                // `OnboardingView.swift:897` — "And nothing here watches you.
                // Page four said 'It remembers where you were', which puts the
                // app in the role of something keeping track of a person."
                // Two words on a switch said it again. `CLAUDE.md`'s "Words the
                // app says" is explicit that nothing may sound like
                // surveillance, and it names faces, cameras and location as
                // where it matters most. This switch is all three.
                //
                // **"Keep" is not a new word, it is the app's own.** What this
                // switch does is already stated twice in the app and both
                // times with this verb: the empty map says "Photos you take in
                // Strata keep the place they were taken"
                // (`MemoriesMapView.swift:718`) and the denied footer six lines
                // below says "photographs can't be placed on your map". The
                // subject there is the PHOTOGRAPH, not the app, and that is the
                // whole correction. "Places on Photos" was the other candidate
                // and loses on the row above it: `Save to Photos` is verb plus
                // object, and two rows in one section reading the same shape is
                // the pair saying they are the same kind of decision.
                Toggle(isOn: $remembersPlaces) {
                    Label {
                        Text("Keep Places")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "mappin.and.ellipse")
                    }
                }
                .tint(AppColors.switchTrack)
                .disabled(location.isDenied)
            } header: {
                FormSectionLabel("Camera").id(Self.cameraAnchor)
            } footer: {
                Text(storageLine)
                    .formFooter()
                    .accessibilityLabel("Photographs use \(storageLine)")

                // **The working case says nothing here now** (cut 10,
                // `docs/copy-audit.md`). This footer carried "Photographs you
                // take in Strata keep the place they were taken, and appear on
                // your map." under a switch that says the same thing in two
                // words, inside a section headed Camera. The sentence is not
                // lost: `MemoriesMapView.swift:718` says it on the empty map,
                // which is where somebody stands when they have the question.
                // A settings footer is read by somebody who came looking for a
                // switch; the map is read by somebody wondering why it is bare.
                //
                // **The denied branch stays**, which is why this is an `if` and
                // not a deletion. It is the map's one real disappointment, it
                // is caused by a setting in a different app, and no other
                // screen can tell you. Its own note already said it "should not
                // be discovered". The `gapTight` moved off the line above and
                // onto this one, so the air exists only when the line does.
                if location.isDenied {
                    Text("Location is off for Some Wins in the Settings app, so photographs can't be placed on your map.")
                        .formFooter()
                        .padding(.top, GridConstants.gapTight)
                }
            }

            // MARK: - Memories

            // **Month Drawing** (spec section 4): the hold on Memories' month
            // drawing, as a row, because a hidden gesture needs a second way
            // in. See `MonthDrawingSettingsView`.
            Section {
                NavigationLink {
                    MonthDrawingSettingsView()
                } label: {
                    Label {
                        Text("Month Drawing")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "pencil.and.scribble")
                    }
                }
            } header: {
                FormSectionLabel("Memories")
            }

            // MARK: - Journal

            // **Lock Journal** (the owner approved it on 2026-10-05, spec
            // section 2): Face ID or the passcode, asked once a session before
            // a note opens. Off by default, because the journal is already in
            // the person's own iCloud and a lock nobody asked for is a door
            // between them and their own words. See `JournalLock`.
            Section {
                Toggle(isOn: $locksJournal) {
                    Label {
                        Text("Lock Journal")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "lock")
                    }
                }
                .tint(AppColors.switchTrack)
                .onChange(of: locksJournal) { _, on in
                    // Switching it on starts a locked session, so the next
                    // note asks; it does not wait for the app to leave.
                    if on { JournalLock.shared.relock() }
                }
            } header: {
                FormSectionLabel("Journal")
            }

            // MARK: - How Strata works

            Section {
                Button {
                    HapticsEngine.lightTap()
                    replayOnboarding = true
                } label: {
                    Label {
                        Text("How Some Wins Works")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "questionmark.circle")
                    }
                }
            }
            // **No footer** (cut 15, `docs/copy-audit.md`). It read "The short
            // walkthrough you saw when you first opened the app." under a row
            // reading `How Strata Works` beside a `questionmark.circle`. The
            // row names itself; a sentence under it is the label again in
            // longer words.
            //
            // The reason the ROW exists is unchanged and is the owner's:
            // "add onboarding to the settings so people that missed what to do
            // can go there." Onboarding shows once and has a Skip on every
            // page, so somebody who skipped it has no other way back to it.
            // That argument was always for the row, never for the footer.

            // MARK: - Section 3: Data

            Section {
                Button {
                    HapticsEngine.lightTap()
                    exportData()
                } label: {
                    Label {
                        Text("Back Up Everything")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(habits.isEmpty)
                // `AppColors`, not `.tertiary`/`.primary`. The row beside it in
                // Replays was already on the app's ink, so one section of this
                // screen was lit by the platform and the next by the app.
                .foregroundStyle(habits.isEmpty ? AppColors.inkQuiet : AppColors.inkPrimary)

                // **The other half of the backup, beside it.**
                //
                // The owner: "there is no way to put the backup zip into the
                // app." He found that out by reinstalling, believing his wins
                // were in iCloud, and losing all of them — a backup nobody can
                // restore is not a backup, and for months this section had
                // exactly one of the two rows. They sit together because they
                // are one feature and somebody looking for the second one looks
                // where the first one is.
                //
                // **Never disabled.** Back Up Everything is disabled on an
                // empty store because there is nothing to back up; an empty
                // store is precisely when a restore matters most.
                Button {
                    HapticsEngine.lightTap()
                    showRestorePicker = true
                } label: {
                    Label {
                        Text("Restore From a Backup")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "square.and.arrow.down")
                    }
                }

                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label {
                        // **One red on the row, not two.** The word was taking
                        // the destructive role's own red, the system #FF3B30,
                        // beside a glyph in the app's: two reds four points
                        // apart on one line, on the one row in the app where the
                        // colour IS the meaning.
                        //
                        // **`AppColors.destructiveInk`, and it was `warmRed` at 2.71:1**
                        // (2026-10-02). The other worker sampled all three reds
                        // on the built light card and this is the only one that
                        // clears the 4.5:1 a 17pt word is held to:
                        //
                        //     AppColors.warmRed   #E85D4A   rgb(228)   2.71:1
                        //     the system red      #FF3B30              2.79:1
                        //     destructiveTint     #B3000F              5.65:1
                        //
                        // Measured on the built sheet after the move: **5.64:1
                        // light, 4.74:1 dark.** `warmRed` was chosen as "the
                        // app's palette rather than the platform's" and that
                        // argument is right and is kept — this token is the
                        // app's own red too, and it is the one that inverts
                        // (rgb(255, 92, 84) in dark), which `warmRed` does not.
                        //
                        // **One red at one weight across every delete in the
                        // app**, which closes "six shapes of destructive action
                        // in three reds" from `docs/consistency-audit.md` §3.3
                        // down to one colour.
                        Text("Reset All Data")
                            .foregroundStyle(AppColors.destructiveInk)
                    } icon: {
                        // **The one that keeps its colour.** Red here is not
                        // decoration, it is the meaning: this row erases
                        // everything, and every platform marks that in red.
                        // The rule is that colour must MEAN something, not
                        // that chrome is grey.
                        SettingsIcon(systemName: "trash", tint: AppColors.destructiveInk)
                    }
                }
                .confirmationDialog(
                    "Reset All Data?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Everything", role: .destructive) {
                        HapticsEngine.snap()
                        runReset()
                    }
                } message: {
                    Text("This permanently deletes every win and photo, your name and profile photo, and your head. It cannot be undone.")
                }
            } header: {
                FormSectionLabel("Data").id(Self.dataAnchor)
            } footer: {
                // Said where the two rows are, because the fear this answers is
                // "will restoring wipe what I have now".
                Text("A backup is one zip file with your wins and your photographs in it. Restoring only adds what the file holds; nothing already on this phone is deleted.")
                    .formFooter()
            }

            // MARK: - Section 4: Support

            Section {
                // **An address that receives mail.** This was
                // support@strataapp.co, and strataapp.co has no MX record and
                // no A record — checked with dig on 2026-09-13 — so every
                // message sent from here went nowhere, from the button the
                // onboarding thank-you page points people toward. It is the
                // address the privacy policy already publishes, so the app has
                // one contact rather than two. Swap both when the domain is
                // real.
                Link(destination: URL(string: "mailto:jbett5@hotmail.com")!) {
                    Label {
                        HStack {
                            Text("Send Feedback")
                                .foregroundStyle(AppColors.inkPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                // Icon sizes come from `GridConstants.icon*`
                                // (CLAUDE.md, Conventions). `.font(.caption)`
                                // was the one raw text style left on a glyph
                                // in this screen, and it does not scale with
                                // Dynamic Type the way `iconSize` does.
                                .iconSize(GridConstants.iconMedium, relativeTo: .footnote, weight: .medium)
                                .foregroundStyle(AppColors.inkQuiet)
                        }
                    } icon: {
                        SettingsIcon(systemName: "envelope")
                    }
                }

                Button {
                    requestReview()
                } label: {
                    Label {
                        Text("Rate on App Store")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "star")
                    }
                }
            } header: {
                FormSectionLabel("Support")
            }

            // MARK: - Section 5: Legal
            //
            // These were links to strataapp.co/privacy and /terms. The domain
            // does not resolve — curl gets no response at all, not a 404 — so
            // both rows were dead ends, including the one App Review opens.
            // The policy is in the app now, where it is true regardless of
            // what is hosted. A hosted copy is still required for App Store
            // Connect; see tasks/app-store-readiness.md.
            Section {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label {
                        Text("Privacy")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "hand.raised")
                    }
                }
            } footer: {
                // **KEPT, deliberately, against the rule** (flag 19,
                // `docs/copy-audit.md`, 2026-10-01). By the audit's own test
                // this is Explanation and it goes: `PrivacyPolicyView.swift:54`
                // says it at length one tap away, which is the pattern every
                // other cut on this screen was made for.
                //
                // It stays because it is the one sentence in the app that
                // SELLS what `docs/brand.md` calls the product's spine, and it
                // is sitting on the row of somebody who already cares enough to
                // have gone looking. Thirteen words. Every other footer on this
                // screen explains a control; this one is the claim the app is
                // for. If it is ever cut, it should be cut by the owner and not
                // by the rule.
                Text("Everything you log stays on this device. Some Wins has no account and no server.")
                    .formFooter()
            }

            // MARK: - Section 6: Debug

            #if DEBUG
            Section {
                Button(role: .destructive) {
                    runReset()
                } label: {
                    Label("Reset All Data", systemImage: "trash")
                }
            } header: {
                FormSectionLabel("Debug")
            }

            #endif
        }
        .task { await measureStorage() }
        .fullScreenCover(isPresented: $replayOnboarding) {
            OnboardingView { replayOnboarding = false }
        }
        .fullScreenCover(item: $previewing) { replay in
            ReplayView(replay: replay, isSample: true) { previewing = nil }
        }
        // **The page's own break, taken from the platform's number**
        // (2026-10-01, check 11b in `docs/screen-audit.md`).
        //
        // Measured on the built screen at 402x874: fourteen gaps, six of them
        // on the 12 rung, and the biggest gap on the whole page **45.0pt** —
        // under the 48 clause 11b asks for. `docs/space.md`'s P1 is the reason
        // that matters rather than being a number miss: proximity groups by
        // the RATIO between competing distances, so a page whose biggest gap is
        // 45 against a body of 25s is grouping at 1.8x, and nothing on it reads
        // as a break. Every gap on this page belonged to the system `Form`.
        //
        // **What the platform itself does, measured on this simulator rather
        // than assumed.** iOS 26's own Settings root, captured at the same
        // 402x874: its cards start at **16.0** — the same margin this app
        // uses — its rows sit **10.3 to 11.7pt** apart, and its groups sit
        // **63.0 and 70.3pt** apart. Six times the inside gap, and it buys that
        // break with no section label on the page at all.
        //
        // So the break is the platform's own, and this is the API for it
        // rather than padding inside `FormSectionLabel`: padding there would
        // also land on `PlanItemDetailSheet` and `PrivacyPolicyView`, which are
        // not this screen and did not ask. `listSectionSpacing` changes this
        // `Form` and nothing else. `gapPage` because it is the ladder's top
        // rung and `docs/space.md` §7 adds it for exactly this job.
        //
        // **Why the labels stay** (the owner named Settings as a possible
        // exception to "no tiny thin font anywhere", so this is researched
        // rather than assumed):
        //   1. They are not thin and not tiny. `Typography.sectionLabel` is
        //      `tier(.subheadline)` at `titleWeight`: **15pt SEMIBOLD**, which
        //      is the floor `TypographyTests.noSourceSetsTypeBelowTheFloor`
        //      enforces at the app's heading weight. Settings needs no
        //      exception, because nothing here is under it.
        //
        //      **This said "15pt Medium" and the number in the argument put to
        //      the owner was wrong within hours of being written** (corrected
        //      2026-10-01, `docs/consistency-audit.md` §2.2). The whole scale
        //      went to Medium that morning, to answer "no tiny thin font
        //      anywhere"; by the evening his reading of the result was "the text
        //      reads as premium not dull a nice thicker font for headers", and
        //      `Typography.titleWeight` became `.semibold` and the DEFAULT
        //      argument of `tier(_:)`. So `sectionLabel` is Semibold, and so are
        //      `screenTitle`, `headerMedium` and `headerSmall`.
        //
        //      **The decision stands and only the number moves**, which is the
        //      point of correcting it rather than deleting it: the labels were
        //      kept because they are not thin, and the measurement says they are
        //      14.5% LESS thin than the sentence claimed. At a title's optical
        //      size Medium's stem is 3.68pt and Semibold's 4.21. Two more
        //      comments still carry the old number and are not this file's:
        //      `Typography.swift` on `headerSmall` and on `sectionLabel`.
        //   2. Apple's root Settings can drop its labels because every row
        //      there is a named destination — General, Accessibility, Camera —
        //      so the row IS its own heading. These rows are switches, and
        //      their grouping is not recoverable from their names: "Weekly and
        //      Monthly Replays" could sit under Notifications or under
        //      Replays, and it is under Notifications because the label says
        //      so.
        //   3. They are this page's only VoiceOver headings, across seven
        //      sections, which is how somebody not looking at the screen
        //      navigates it.
        // What is NOT the platform's is the STYLE — SF Rounded, uppercased by
        // the style, kerned 0.8 — and that is the app's own on purpose;
        // `FormSectionLabel`'s own doc carries the argument.
        .listSectionSpacing(GridConstants.gapPage)
        .scrollContentBackground(.hidden)
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle("Settings", drawn: false)
        // **The primary, on the platform's own controls, and BELOW the
        // toolbar.** See `ProfileView`, where this was measured: with the tint
        // applied above `.toolbar`, Profile's Done still rendered (10, 10, 10).
        // A toolbar item is hosted by the navigation bar rather than by the
        // content it was declared on, so a tint set upstream of the title and
        // the toolbar never reaches it, and the one control the colour exists
        // for is the one control that does not get it. Moved here for the same
        // reason, before this screen's own toolbar grows a coloured action.
        .tint(AppColors.inkPrimary)
        .task {
            await checkNotificationStatus()
            #if DEBUG
            await scrollToAnchor(scroller)
            #endif
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Nothing was deleted", isPresented: $resetFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Some Wins could not reset your data, so every win and photo is still here. Try again.")
        }
        .alert("The backup was not made", isPresented: $exportFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            // The step that failed, not one sentence covering five faults. A
            // full disk and a file system error are different problems and a
            // person can do something about the first.
            Text("\(exportFailure) Nothing was changed, so your wins and photos are all still here.")
        }
        // **`.zip` only.** Everything else in Files is the wrong file, and being
        // told so by the picker is better than being told so by an alert.
        .fileImporter(isPresented: $showRestorePicker,
                      allowedContentTypes: [.zip],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { copyForRestore(url) }
            case .failure(let error):
                restoreFailure = "Some Wins could not open that file (\(error.localizedDescription))."
            }
        }
        .alert("That file could not be opened", isPresented: Binding(
            get: { !restoreFailure.isEmpty },
            set: { if !$0 { restoreFailure = "" } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(restoreFailure) Nothing has been changed.")
        }
        // `item:`, so the screen cannot open before there is a file for it to
        // read — a sheet on a Bool plus a separate optional is how a view ends
        // up presenting an empty state for one frame.
        .sheet(item: $restoreZip) { picked in
            RestoreBackupView(zip: picked.url) { discardRestoreCopy() }
        }
        #if DEBUG
        .task {
            // `-strataAutoReset`: runs the same action the button does, so the
            // failure message can be photographed where a person would see it.
            // Nothing on this machine can tap the simulator.
            guard DebugHarness.autoResets else { return }
            try? await Task.sleep(for: .seconds(1.5))
            runReset()
        }
        .task {
            // `-strataRestoreFrom <file name in Documents>`: opens the restore
            // screen on a backup already in the container.
            //
            // **Because nothing on this machine can drive a file picker.** The
            // restore's own screen — the counts, the warnings, the confirm — can
            // only be looked at if there is a way in that does not go through
            // `UIDocumentPickerViewController`, and a feature whose whole point
            // is that somebody READS it before tapping has to be looked at
            // rather than measured. It skips the picker and nothing else: the
            // same screen, the same plan, the same merge.
            guard let name = DebugHarness.argument("-strataRestoreFrom") else { return }
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documents.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else {
                restoreFailure = "There is no \(name) in Documents."
                return
            }
            try? await Task.sleep(for: .seconds(0.5))
            // Through the same copy the picker's path uses, so the flow under
            // test is the real one.
            copyForRestore(url)
        }
        #endif
        }
    }

    /// Where `-strataScrollSettings` can put the page. Both are below the fold
    /// and neither has ever been in a capture.
    static let cameraAnchor = "camera-section"
    static let dataAnchor = "data-section"

    #if DEBUG
    /// `-strataScrollSettings camera|data`: opens Settings already scrolled, so
    /// the sections under the fold can be looked at.
    ///
    /// **Not a named accessor on `DebugHarness`** like `scrollsMemories`, only
    /// because that file was off limits to the pass that needed this. It
    /// belongs there, beside `-strataScrollMemories` and
    /// `-strataScrollProfile`, which are the same flag for the same reason on
    /// the other two long pages.
    ///
    /// The sleep waits for the `Form` to have laid its sections out at all —
    /// `scrollTo` against a list whose rows do not exist yet does nothing and
    /// says nothing. What decides the screen has stopped moving is the
    /// capture's own settle poll in `tools/settle-shot.py`, not this.
    @MainActor
    private func scrollToAnchor(_ scroller: ScrollViewProxy) async {
        let anchor: String
        switch DebugHarness.scrollSettingsTo {
        case "camera": anchor = Self.cameraAnchor
        case "data":   anchor = Self.dataAnchor
        default:       return
        }
        try? await Task.sleep(for: .seconds(1.5))
        scroller.scrollTo(anchor, anchor: .top)
    }
    #endif

    /// Resets, and stays on this screen with the reason if it did not happen.
    /// Leaving would put the person back on a Profile that still shows
    /// everything, with no word about why.
    private func runReset() {
        if onResetAllData?() == false {
            HapticsEngine.warning()
            resetFailed = true
        } else {
            dismiss()
        }
    }

    // MARK: - Notification Helpers

    // MARK: - Settings has no Done, and never had one anybody could press
    //
    // **`settingsToolbar`, `settingsDoneButton` and `isPushed` are deleted**
    // (2026-10-01, `docs/consistency-audit.md` §1.4). The toolbar was behind
    // `if !isPushed` and both call sites in the app passed `isPushed: true`
    // (`ProfileView`'s `navigationDestination` and its `settingsLink`). So the
    // flag had one value everywhere, which is the condition `SectionHeading`
    // writes down about a different flag: **"A flag with one value in the whole
    // app is a decision nobody made."** The button and the twelve-line argument
    // above it described a control nobody could reach, and the audit counted it
    // as one of six sheet confirm words while it was drawing none.
    //
    // Settings is a PUSHED page, always. Its leading item is the system's back
    // chevron, which is also its dismiss, and `PrivacyPolicyView` one level
    // deeper is the same shape. A trailing Done beside a back chevron would be
    // two ways out of one page.
    //
    // **Two things worth keeping out of what went.**
    //
    // The glass rule, which still applies to anything this file ever puts in a
    // toolbar: iOS 26 draws a glass capsule behind every toolbar item, the app
    // strips it with `sharedBackgroundVisibility(.hidden)`, and a screen that
    // misses the treatment both looks unlike its neighbours and can render that
    // capsule black against the warm ground. `sheetTitle(_:drawn:)` carries it
    // for the principal slot, which is this page's only toolbar item.
    //
    // And the measurement that moved every confirm word off `accentWarm`: on
    // Profile, which had the identical button, the word rendered (28, 26, 24) at
    // 16.2:1 beside a title at (37, 37, 37) and 14.3:1, so the bar held two
    // words of the same black and nothing said which one was the button. That
    // fault is not fixed by the move to ink, it is moved — see `SheetAction`,
    // which now owns the ink, the font and the 44pt box for the five sheets that
    // do have a confirm word.

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            if granted {
                scheduleReminder()
            } else {
                notificationsEnabled = false
                systemNotificationsDenied = true
            }
        } catch {
            notificationsEnabled = false
            systemNotificationsDenied = true
        }
    }

    /// See `DailyReminder`: only on days with nothing on the tower yet.
    private func scheduleReminder() {
        let today = DateUtils.dateString(from: Date())
        let loggedToday = logs.contains { $0.dateString == today && $0.completed }
        Task { await DailyReminder.schedule(hour: reminderHour, minute: reminderMinute,
                                            loggedToday: loggedToday) }
    }

    private func checkNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        systemNotificationsDenied = settings.authorizationStatus == .denied

        // Initialize reminderTime Date from stored hour/minute
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        if let date = Calendar.current.date(from: components) {
            reminderTime = date
        }
    }

    // MARK: - Export

    /// Builds the backup and hands it to the share sheet.
    ///
    /// **The format and the file live in `BackupExport`, not here.** They were
    /// written out in this function, in a `View`, which is why they could not be
    /// tested and why the restore had nothing to read against: the round-trip
    /// test — export, empty the store, restore, compare — is the only test that
    /// proves a backup is a backup, and it cannot be written against a private
    /// function that raises an alert. Every failure still surfaces here, now with
    /// the step that failed.
    private func exportData() {
        do {
            // The day's journal goes in the backup too: see `BackupExport.document`.
            let notes = (try? modelContext.fetch(FetchDescriptor<MoodLog>())) ?? []
            exportURL = try BackupExport.makeZip(habits: habits, logs: logs, notes: notes,
                                                 appVersion: appVersion)
            showExportShare = true
        } catch let failure as BackupArchive.WriteFailure {
            exportFailure = failure.message
            exportFailed = true
        } catch {
            exportFailure = "Some Wins could not write the backup file (\(error.localizedDescription))."
            exportFailed = true
        }
    }

    // MARK: - Restore

    /// Copies the picked file somewhere this app owns, then opens the preview.
    ///
    /// **The copy is the point.** A document picker's URL is security-scoped and
    /// borrowed: access has to be started and stopped, and it can be a file that
    /// is not on the phone yet. A restore reads the zip twice — once to count
    /// what is in it, and again for each photograph after somebody has confirmed
    /// — so borrowing that URL across a whole flow with a sheet in the middle of
    /// it is how a restore fails half way through for a reason nobody can
    /// explain. Copying once, here, makes every later read an ordinary file
    /// read, and the one failure that can happen has a message.
    private func copyForRestore(_ picked: URL) {
        let fm = FileManager.default
        let scoped = picked.startAccessingSecurityScopedResource()
        defer { if scoped { picked.stopAccessingSecurityScopedResource() } }

        let destination = fm.temporaryDirectory
            .appendingPathComponent("restore-\(UUID().uuidString).zip")
        do {
            try fm.copyItem(at: picked, to: destination)
        } catch {
            restoreFailure = "Some Wins could not read that file (\(error.localizedDescription))."
            return
        }
        restoreZip = RestoreBackupView.Picked(url: destination)
    }

    /// Closes the restore screen and removes the app's copy of the zip.
    ///
    /// The person's own file is never touched: this deletes the copy
    /// `copyForRestore` made, and nothing else. Leaving it would keep a
    /// second copy of the whole library in the temporary directory.
    private func discardRestoreCopy() {
        if let url = restoreZip?.url {
            try? FileManager.default.removeItem(at: url)
        }
        restoreZip = nil
        // The storage line counts photographs on disk, and a restore has just
        // changed that number.
        Task { await measureStorage() }
    }

}

// MARK: - Settings Icon Badge

/// A settings row's glyph.
///
/// **No box.** This drew a `BlockSurface` behind every icon — an actual block,
/// the app's own — for rows that are not wins. CLAUDE.md is explicit that a
/// block's claim is "you built this and it is standing on something", and a
/// preference is not something you built. Eleven of them down the page made
/// Settings look like a tower laid on its side.
///
/// The owner, after the colours came out: "why does there need to be boxes
/// around the icons in the settings?" There does not. A bare glyph is what
/// every list on this platform uses, it removes a whole layer of chrome from
/// the quietest screen in the app, and it costs the section nothing — the row
/// already has a label saying what it is.
///
/// The frame stays, so the labels still line up in a column.
/// Internal so Profile's Settings row wears the same glyph at the same size.
///
/// **Outline glyphs, in both lists.** Settings mixed `bell.fill` and
/// `star.fill` with outline `calendar` and `questionmark.circle`, once with
/// `square.stack.3d.up` two rows above its own `.fill` twin; Profile was all
/// outline. Profile's set is the reference. A destructive row is
/// `AppColors.destructiveInk`, never the system red and no longer
/// `AppColors.warmRed`, which measured 2.71:1 on this card against the 4.5 a
/// word is held to. See the note at the Reset All Data row.
struct SettingsIcon: View {
    let systemName: String
    /// Only a row whose colour MEANS something passes one — Reset All Data is
    /// red because it erases everything, not for decoration.
    var tint: Color? = nil

    /// **The row's height, which is what this number actually sets.**
    ///
    /// Measured off the built Settings screen at 402x874: the Notifications
    /// section's card is 85.3pt tall for two rows and the Replays section's is
    /// 85.7pt for two, so a row is 42.65pt. That is 1.35pt under the 44pt check
    /// 8 asks for, measured rather than declared.
    ///
    /// The two sections settle which term sets it. Notifications' rows carry a
    /// switch and Replays' rows do not, and they measure the same, so the switch
    /// is not the driver. What both have is this frame, and 30 + 12.65 of row
    /// inset is the 42.65 on the screen. 32 puts a row at 44.65 and keeps the
    /// icon column on the 4pt grid.
    ///
    /// The glyph inside it does not change: it measures 15.3 by 16.7pt against a
    /// label cap of 12.2, so it is already the taller of the two and the air is
    /// what makes a bare glyph quiet.
    private static let side: CGFloat = 32

    var body: some View {
        Image(systemName: systemName)
            .iconSize(GridConstants.iconCategory, relativeTo: .footnote, weight: .medium)
            .foregroundStyle(tint ?? AppColors.inkSecondary)
            .frame(width: Self.side, height: Self.side)
    }
}

// MARK: - A section's label

/// The one heading a `Form` section wears, on every sheet in the app.
///
/// **`Section("Name")` is the platform's heading, not this app's.** It arrives
/// in SF Pro at a size and a case iOS picks, so Settings, Profile and a plan
/// line each named their sections in a face the app uses nowhere else, while
/// `AddWinSheet` set its own labels from `Typography.sectionLabel` by hand.
/// Three screens, three answers to one question.
///
/// `docs/design-system-future.md` section 2 settles which: "A label that wants
/// to feel like an instrument gets: SF Rounded, footnote size, medium weight,
/// ALL CAPS, `Typography.sectionKerning` (0.8). That is
/// `Typography.sectionLabel` and it already exists. Use it for section headings
/// and index labels; do not invent another."
///
/// **Case comes from the style, not from the caller**: the bug
/// `SectionHeading` records, and the reason "Streak" and "Your head" sat one
/// section apart at the same rank looking like two different ranks. This is
/// `SectionHeading`'s style without its page margin and section gap, which a
/// `Form` row already supplies; and without its `.isHeader` trait, which a
/// `Form` section header already carries.
struct FormSectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Typography.sectionLabel)
            .kerning(Typography.sectionKerning)
            .textCase(.uppercase)
            .foregroundStyle(AppColors.inkSecondary)
    }
}

/// **A form footer, on the type ladder** (2026-10-02, design review).
///
/// Every footer on Settings and Profile was a bare `Text`, which a grouped
/// `Form` sets in `.footnote` and `.secondary`: **13pt at 3.36:1**, measured
/// under Data on the built sheet (rgb 134 on 246). That is under the 15pt
/// floor the owner locked ("no tiny thin font anywhere", `docs/design.md`)
/// and under the 4.5:1 a word that size is held to, on six sentences across
/// two screens, including the one that sells the product's spine. The
/// audit's twelve checks never caught it because no capture had reached the
/// footers until `-strataScrollSettings` existed.
///
/// One modifier rather than six fixes: the 15 rung (`screenSubtitle`, the
/// body weight) in `inkTertiary`, the ink `CountReadout` already reads at
/// 4.69:1 on this ground.
struct FormFooterStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typography.screenSubtitle)
            .foregroundStyle(AppColors.inkTertiary)
    }
}

extension View {
    /// See `FormFooterStyle`.
    func formFooter() -> some View { modifier(FormFooterStyle()) }
}

// MARK: - Share Sheet (UIKit Bridge)

/// The system share sheet.
///
/// `UIActivityViewController` rather than a hand-built row of app buttons: it
/// already knows which apps the person has, which ones they use most, and how
/// each one wants an image handed to it — and Instagram and Snapchat both take
/// a story image through it. A custom sheet is a worse version of that which
/// needs updating every time somebody installs something.
///
/// Not `private`: the tower shares through it too.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
