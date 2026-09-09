import SwiftUI
import SwiftData
import UserNotifications
import StoreKit

struct SettingsView: View {
    var onResetAllData: (() -> Void)?

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
    @AppStorage("towerShowParallax") private var towerShowParallax = true
    /// The same defaults key `PhotoLibrarySaver` reads, so the toggle and the
    /// service share one source of truth rather than mirroring each other.
    /// Both default to on.
    @AppStorage(PhotoLibrarySaver.defaultsKey) private var savesToCameraRoll = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var reminderTime = Date()
    @State private var systemNotificationsDenied = false

    // MARK: - Sheet State

    @State private var showResetConfirmation = false
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
                        .foregroundStyle(.secondary)
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
                        SettingsIcon(systemName: "bell.fill")
                    }
                }
                .tint(AppColors.accentWarm)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        Task { await requestNotificationPermission() }
                    } else {
                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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

            // MARK: - Sounds

            Section("Sounds") {
                Toggle(isOn: Binding(
                    get: { !SoundEngine.isMuted },
                    set: { SoundEngine.isMuted = !$0 }
                )) {
                    Label {
                        Text("Completion Sounds")
                    } icon: {
                        SettingsIcon(systemName: "speaker.wave.2.fill")
                    }
                }
                .tint(AppColors.accentWarm)
            }

            // MARK: - Tower Appearance (#172)

            // MARK: - Camera

            Section("Camera") {
                Toggle(isOn: $savesToCameraRoll) {
                    Label {
                        Text("Save to Photos")
                    } icon: {
                        SettingsIcon(systemName: "photo.on.rectangle.angled")
                    }
                }
                .tint(AppColors.accentWarm)
            }

            Section("Tower") {
                Toggle(isOn: $towerShowParallax) {
                    Label {
                        Text("3D Parallax")
                    } icon: {
                        SettingsIcon(systemName: "cube.transparent")
                    }
                }
                .tint(AppColors.accentWarm)

                // #173: Haptic toggle
                Toggle(isOn: $hapticsEnabled) {
                    Label {
                        Text("Haptic Feedback")
                    } icon: {
                        SettingsIcon(systemName: "iphone.radiowaves.left.and.right")
                    }
                }
                .tint(AppColors.accentWarm)
            }

            // MARK: - Section 3: Data

            Section("Data") {
                Button {
                    HapticsEngine.lightTap()
                    exportData()
                } label: {
                    Label {
                        Text("Export Data")
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
                        SettingsIcon(systemName: "trash.fill", tint: AppColors.warmRed)
                    }
                }
                .confirmationDialog(
                    "Reset All Data?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Everything", role: .destructive) {
                        HapticsEngine.snap()
                        onResetAllData?()
                        dismiss()
                    }
                } message: {
                    Text("This will permanently delete every win, its photo, and your tower. This cannot be undone.")
                }
            }

            // MARK: - Section 4: Support

            Section("Support") {
                Link(destination: URL(string: "mailto:support@strataapp.co")!) {
                    Label {
                        HStack {
                            Text("Send Feedback")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } icon: {
                        SettingsIcon(systemName: "envelope.fill")
                    }
                }

                Button {
                    requestReview()
                } label: {
                    Label {
                        Text("Rate on App Store")
                            .foregroundStyle(.primary)
                    } icon: {
                        SettingsIcon(systemName: "star.fill")
                    }
                }
            }

            // MARK: - Section 5: Legal

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
                        SettingsIcon(systemName: "hand.raised.fill")
                    }
                }
            } footer: {
                Text("Everything you log stays on this device. Strata has no account and no server.")
            }

            // MARK: - Section 6: Debug

            #if DEBUG
            Section("Debug") {
                Button(role: .destructive) {
                    onResetAllData?()
                    dismiss()
                } label: {
                    Label("Reset All Data", systemImage: "trash")
                }
            }

            Section("Animation Previews") {
                Button { SoundEngine.completionTone(category: .health) } label: {
                    Label("Completion Tone (Health)", systemImage: "speaker.wave.2")
                }
                Button { SoundEngine.blockImpact(mass: 2) } label: {
                    Label("Block Impact (Medium)", systemImage: "speaker.wave.1")
                }
                Button { SoundEngine.allClearChime() } label: {
                    Label("All-Clear Chime", systemImage: "music.note")
                }
                Button { HapticsEngine.reward() } label: {
                    Label("Reward Haptic", systemImage: "hand.tap")
                }
            }

            Section("Reset Triggers") {
                Button {
                    UserDefaults.standard.set(false, forKey: "hasSeenFirstDrop")
                    HapticsEngine.lightTap()
                } label: {
                    Label("Reset First Block Magic", systemImage: "1.circle")
                }
                Button {
                    UserDefaults.standard.set(0, forKey: "lastAuroraWeek")
                    HapticsEngine.lightTap()
                } label: {
                    Label("Reset Aurora Cooldown", systemImage: "sparkles")
                }
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            await checkNotificationStatus()
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - Notification Helpers

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

    private func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "Time to build"
        content.body = "Your tower is ready for a new block."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "strata.daily.reminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "strata-export-\(dateFormatter.string(from: Date())).json"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)

        exportURL = tempURL
        showExportShare = true
    }

}

// MARK: - Settings Icon Badge

/// A settings row's glyph.
///
/// Was a white icon on a saturated rounded square — orange, magenta, blue,
/// yellow — which is stock iOS Settings iconography and belongs to no palette
/// in this app. Thirteen of them made the quietest screen the most colourful.
/// Now a plain monochrome glyph, so colour in the app means a category.
///
/// `tint` exists for the one case where colour is semantic rather than
/// decorative: the destructive row.
private struct SettingsIcon: View {
    let systemName: String
    var tint: Color? = nil

    var body: some View {
        Image(systemName: systemName)
            .iconSize(GridConstants.iconAction, relativeTo: .body, weight: .medium)
            .foregroundStyle(tint ?? .secondary)
            .frame(width: 28, height: 28)
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
