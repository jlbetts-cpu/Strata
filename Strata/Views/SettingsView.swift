import SwiftUI
import SwiftData
import UserNotifications
import StoreKit
// For `UTType.zip`, which is what the file importer accepts: a backup is one
// zip, and naming the type stops somebody handing this a photograph.
import UniformTypeIdentifiers

struct SettingsView: View {
    /// Returns whether the record was actually emptied.
    var onResetAllData: (() -> Bool)?
    /// Pushed from Profile, which is the only way in now. A pushed screen has
    /// a back button, and a Done that called `dismiss()` would only pop back
    /// to Profile — two controls that both mean "back".
    var isPushed = false

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

                    StrataWordmark(size: 30)

                    // **The model plate, and the one place inside the app
                    // that says the full name.**
                    //
                    // The owner asked whether Neo needs to appear in the app
                    // at all, and the answer we settled on is almost nowhere:
                    // the wordmark, the launch and the camera all stay
                    // "Strata", because nobody inside the app is choosing
                    // between this and another app. It belongs on the App
                    // Store shelf and under the icon. This row is the
                    // exception, and it earns it: a name set beside a version
                    // and a build is what a device's plate looks like, which
                    // is the 1990s instrument register the whole design is
                    // after. It also means a reviewer who opens the app finds
                    // the full name without the app announcing itself.
                    Text("Strata Neo \(appVersion)")
                        .font(Typography.sectionLabel)
                        .kerning(Typography.sectionKerning)
                        .foregroundStyle(AppColors.inkQuiet)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, GridConstants.gapWide)
                .padding(.bottom, GridConstants.gapTight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Strata Neo, version \(appVersion)")
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // MARK: - Section 1: Notifications

            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Label {
                        Text("Daily Reminder")
                    } icon: {
                        SettingsIcon(systemName: "bell")
                    }
                }
                .tint(AppColors.switchOn)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        Task { await requestNotificationPermission() }
                    } else {
                        Task { await DailyReminder.removePending() }
                    }
                }

                if notificationsEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
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
                    Label { Text("Weekly and Monthly Replays") } icon: { SettingsIcon(systemName: "square.stack.3d.up") }
                }
                .tint(AppColors.switchOn)
                .onChange(of: replayRemindersOn) { _, on in
                    Task { on ? await ReplayReminder.schedule(context: modelContext) : await ReplayReminder.removePending() }
                }
            } header: {
                FormSectionLabel("Notifications")
            } footer: {
                if systemNotificationsDenied && notificationsEnabled {
                    VStack(alignment: .leading, spacing: GridConstants.spacing) {
                        Text("Notifications are disabled in system settings.")
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
            }
            .animation(reduceMotion ? .none : GridConstants.gentleReveal, value: notificationsEnabled)

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
                    } icon: {
                        SettingsIcon(systemName: "speaker.wave.2")
                    }
                }
                .tint(AppColors.switchOn)

                Toggle(isOn: $hapticsEnabled) {
                    Label {
                        Text("Haptic Feedback")
                    } icon: {
                        SettingsIcon(systemName: "iphone.radiowaves.left.and.right")
                    }
                }
                .tint(AppColors.switchOn)
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
                    } icon: {
                        SettingsIcon(systemName: "photo.on.rectangle.angled")
                    }
                }
                .tint(AppColors.switchOn)

                // **The switch that fills the map lives beside the one that
                // fills the camera roll**, because they are the same decision
                // about the same photograph and looking for one in a different
                // section from the other is the app being inconsistent.
                Toggle(isOn: $remembersPlaces) {
                    Label {
                        Text("Remember Places")
                    } icon: {
                        SettingsIcon(systemName: "mappin.and.ellipse")
                    }
                }
                .tint(AppColors.switchOn)
                .disabled(location.isDenied)
            } header: {
                FormSectionLabel("Camera")
            } footer: {
                Text(storageLine)
                    .padding(.bottom, GridConstants.gapTight)
                    .accessibilityLabel("Photographs use \(storageLine)")

                // Stated here because it is the map's one real disappointment
                // and it should not be discovered.
                Text(location.isDenied
                     ? "Location is off for Strata in the Settings app, so photographs can't be placed on your map."
                     : "Photographs you take in Strata keep the place they were taken, and appear on your map.")
            }

            // MARK: - How Strata works

            Section {
                Button {
                    HapticsEngine.lightTap()
                    replayOnboarding = true
                } label: {
                    Label {
                        Text("How Strata Works")
                            .foregroundStyle(AppColors.inkPrimary)
                    } icon: {
                        SettingsIcon(systemName: "questionmark.circle")
                    }
                }
            } footer: {
                // The owner: "add onboarding to the settings so people that
                // missed what to do can go there." Onboarding shows once and
                // has a Skip button on every page, so somebody who skipped it
                // — or who came back a month later — otherwise has no way to
                // be told how the app works.
                Text("The short walkthrough you saw when you first opened the app.")
            }

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
                        Text("Reset All Data")
                    } icon: {
                        // **The one that keeps its colour.** Red here is not
                        // decoration, it is the meaning: this row erases
                        // everything, and every platform marks that in red.
                        // The rule is that colour must MEAN something, not
                        // that chrome is grey.
                        SettingsIcon(systemName: "trash", tint: AppColors.warmRed)
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
                FormSectionLabel("Data")
            } footer: {
                // Said where the two rows are, because the fear this answers is
                // "will restoring wipe what I have now".
                Text("A backup is one zip file with your wins and your photographs in it. Restoring only adds what the file holds; nothing already on this phone is deleted.")
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
                    } icon: {
                        SettingsIcon(systemName: "hand.raised")
                    }
                }
            } footer: {
                Text("Everything you log stays on this device. Strata has no account and no server.")
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
        .scrollContentBackground(.hidden)
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle("Settings", drawn: false)
        .toolbar {
            settingsToolbar
        }
        .task {
            await checkNotificationStatus()
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Nothing was deleted", isPresented: $resetFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Strata could not reset your data, so every win and photo is still here. Try again.")
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
                restoreFailure = "Strata could not open that file (\(error.localizedDescription))."
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

    /// **Bare glyphs, like every other screen.** See
    /// the Toolbars note in `MainAppView`: iOS 26 puts a glass capsule behind every
    /// toolbar item, the app strips it deliberately, and a screen that misses
    /// the treatment both looks unlike its neighbours and can render that
    /// capsule black against the warm ground. This was one of three that had
    /// been missed.
    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        if !isPushed {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .confirmationAction) { settingsDoneButton }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .confirmationAction) { settingsDoneButton }
            }
        }
    }

    private var settingsDoneButton: some View {
        Button {
            HapticsEngine.lightTap()
            dismiss()
        } label: {
            Text("Done").font(Typography.headerSmall)
        }
        .foregroundStyle(AppColors.accentWarm)
    }

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
            exportURL = try BackupExport.makeZip(habits: habits, logs: logs,
                                                 appVersion: appVersion)
            showExportShare = true
        } catch let failure as BackupArchive.WriteFailure {
            exportFailure = failure.message
            exportFailed = true
        } catch {
            exportFailure = "Strata could not write the backup file (\(error.localizedDescription))."
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
            restoreFailure = "Strata could not read that file (\(error.localizedDescription))."
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
/// `AppColors.warmRed`, never the system red.
struct SettingsIcon: View {
    let systemName: String
    /// Only a row whose colour MEANS something passes one — Reset All Data is
    /// red because it erases everything, not for decoration.
    var tint: Color? = nil

    private static let side: CGFloat = 30

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
