import SwiftUI
import SwiftData
import UserNotifications
import StoreKit

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
                VStack(spacing: 12) {
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

                    Text("Version \(appVersion)")
                        .font(Typography.caption)
                        .foregroundStyle(AppColors.inkQuiet)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Strata version \(appVersion)")
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
                Text("Notifications")
            } footer: {
                if systemNotificationsDenied && notificationsEnabled {
                    VStack(alignment: .leading, spacing: 4) {
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
            Section("Sounds & Haptics") {
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
            }

            // MARK: - Replays

            // **Watch it before it happens.** A replay only arrives at the end of a week
            // or a month, so without this nobody could see what one looks like until
            // then. The preview is the real replay on sample wins, not a video of one.
            Section("Replays") {
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
                Text("Camera")
            } footer: {
                Text(storageLine)
                    .padding(.bottom, 6)
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
                            .foregroundStyle(.primary)
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

            Section("Data") {
                Button {
                    HapticsEngine.lightTap()
                    exportData()
                } label: {
                    Label {
                        Text("Back Up Everything")
                            .foregroundStyle(.primary)
                    } icon: {
                        SettingsIcon(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(habits.isEmpty)
                .foregroundStyle(habits.isEmpty ? .tertiary : .primary)

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
            }

            // MARK: - Section 4: Support

            Section("Support") {
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
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
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
                            .foregroundStyle(.primary)
                    } icon: {
                        SettingsIcon(systemName: "star")
                    }
                }
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
            Section("Debug") {
                Button(role: .destructive) {
                    runReset()
                } label: {
                    Label("Reset All Data", systemImage: "trash")
                }
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
        #if DEBUG
        .task {
            // `-strataAutoReset`: runs the same action the button does, so the
            // failure message can be photographed where a person would see it.
            // Nothing on this machine can tap the simulator.
            guard DebugHarness.autoResets else { return }
            try? await Task.sleep(for: .seconds(1.5))
            runReset()
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

    private func exportData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let export = StrataExport(
            exportDate: Date(),
            appVersion: appVersion,
            habits: habits.map { habit in
                ExportHabit(
                    title: habit.title,
                    category: habit.category.rawValue,
                    blockSize: habit.blockSize.rawValue,
                    frequency: habit.frequency.map(\.rawValue),
                    scheduledTime: habit.scheduledTime,
                    createdAt: habit.createdAt
                )
            },
            logs: logs.map { log in
                ExportLog(
                    habitTitle: log.habit?.title ?? "Unknown",
                    dateString: log.dateString,
                    completed: log.completed,
                    completedAt: log.completedAt,
                    skipped: log.skipped,
                    note: log.note,
                    caption: log.caption
                )
            }
        )

        guard let data = try? encoder.encode(export) else { return }

        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        let name = "Strata Backup \(stamp.string(from: Date()))"

        // **A backup, which means the photographs too.**
        //
        // This wrote a lone JSON file and called it an export. Every win's
        // name, date and size was in it and not one picture — so restoring
        // from it would have given somebody back a tower of empty blocks, and
        // the photographs are the part nobody can retype. The owner asked for
        // "a backup file if possible for saved data"; a backup that drops the
        // irreplaceable half is not one.
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try? fm.removeItem(at: folder)
        guard (try? fm.createDirectory(at: folder, withIntermediateDirectories: true)) != nil,
              (try? data.write(to: folder.appendingPathComponent("wins.json"))) != nil
        else { return }

        // Copied, never moved. These are the user's only copy.
        let photos = folder.appendingPathComponent("photos", isDirectory: true)
        try? fm.createDirectory(at: photos, withIntermediateDirectories: true)
        let source = ImageManager.shared.imageDirectory
        for file in (try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.copyItem(at: file, to: photos.appendingPathComponent(file.lastPathComponent))
        }

        // **Zipped by the system, with no dependency.** `NSFileCoordinator`'s
        // `.forUploading` option hands back a zip of a directory — it is what
        // AirDrop uses for a folder — so a backup is one file somebody can
        // mail themselves without the app shipping an archiver.
        var error: NSError?
        var zipped: URL?
        NSFileCoordinator().coordinate(readingItemAt: folder,
                                       options: [.forUploading],
                                       error: &error) { url in
            let destination = fm.temporaryDirectory
                .appendingPathComponent("\(name).zip")
            try? fm.removeItem(at: destination)
            try? fm.copyItem(at: url, to: destination)
            zipped = destination
        }
        try? fm.removeItem(at: folder)

        guard let zipped else { return }
        exportURL = zipped
        showExportShare = true
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

// MARK: - Export Models

private struct StrataExport: Encodable {
    let exportDate: Date
    let appVersion: String
    let habits: [ExportHabit]
    let logs: [ExportLog]
}

private struct ExportHabit: Encodable {
    let title: String
    let category: String
    let blockSize: String
    let frequency: [String]
    let scheduledTime: String?
    let createdAt: Date
}

private struct ExportLog: Encodable {
    let habitTitle: String
    let dateString: String
    let completed: Bool
    let completedAt: Date?
    let skipped: Bool
    let note: String?
    let caption: String
}
