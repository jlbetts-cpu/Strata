import SwiftUI
import SwiftData
import UserNotifications
import StoreKit

struct SettingsView: View {
    var onboarding: OnboardingState?
    var onResetAllData: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(HealthKitService.self) private var healthKitService
    @Environment(EventKitService.self) private var eventKitService

    @Query private var habits: [Habit]
    @Query private var logs: [HabitLog]

    // MARK: - Notification State

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 8
    @AppStorage("reminderMinute") private var reminderMinute = 0

    // #172/#173: Tower appearance toggles
    @AppStorage("towerShowGhostBlock") private var towerShowGhostBlock = true
    @AppStorage("towerShowParallax") private var towerShowParallax = true
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
                    // Mini tower — 3 stacked blocks
                    VStack(spacing: 4) {
                        MiniBlockPreview(category: .creativity, blockSize: .small, title: "", showTitle: false)
                            .frame(width: 40, height: 40)
                            .offset(x: 2)

                        HStack(spacing: 4) {
                            MiniBlockPreview(category: .focus, blockSize: .small, title: "", showTitle: false)
                                .frame(width: 40, height: 40)
                            MiniBlockPreview(category: .health, blockSize: .small, title: "", showTitle: false)
                                .frame(width: 40, height: 40)
                        }

                        HStack(spacing: 4) {
                            MiniBlockPreview(category: .social, blockSize: .small, title: "", showTitle: false)
                                .frame(width: 40, height: 40)
                            MiniBlockPreview(category: .mindfulness, blockSize: .medium, title: "", showTitle: false)
                                .frame(width: 84, height: 40)
                        }
                    }

                    Text("Strata")
                        .font(Typography.brandLogo)
                        .kerning(Typography.brandLogoKerning)

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
                        SettingsIcon(systemName: "bell.fill", color: .orange)
                    }
                }
                .tint(AppColors.accentPurple)
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
                        SettingsIcon(systemName: "speaker.wave.2.fill", color: .purple)
                    }
                }
                .tint(AppColors.accentPurple)
            }

            // MARK: - Tower Appearance (#172)

            Section("Tower") {
                Toggle(isOn: $towerShowGhostBlock) {
                    Label {
                        Text("Ghost Block Preview")
                    } icon: {
                        SettingsIcon(systemName: "square.dashed", color: .gray)
                    }
                }
                .tint(AppColors.accentPurple)

                Toggle(isOn: $towerShowParallax) {
                    Label {
                        Text("3D Parallax")
                    } icon: {
                        SettingsIcon(systemName: "cube.transparent", color: .blue)
                    }
                }
                .tint(AppColors.accentPurple)

                // #173: Haptic toggle
                Toggle(isOn: $hapticsEnabled) {
                    Label {
                        Text("Haptic Feedback")
                    } icon: {
                        SettingsIcon(systemName: "iphone.radiowaves.left.and.right", color: .green)
                    }
                }
                .tint(AppColors.accentPurple)
            }

            // MARK: - Apple Health

            Section {
                HStack {
                    Label {
                        Text("Apple Health")
                    } icon: {
                        SettingsIcon(systemName: "heart.fill", color: AppColors.healthGreen)
                    }

                    Spacer()

                    if healthKitService.isAuthorized {
                        Text("Connected")
                            .font(Typography.caption)
                            .foregroundStyle(AppColors.healthGreen)
                    } else if healthKitService.isAvailable {
                        Button("Connect") {
                            Task { await healthKitService.requestAccess() }
                        }
                        .font(Typography.bodySmall)
                        .foregroundStyle(AppColors.healthGreen)
                    } else {
                        Text("Not Available")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if healthKitService.isAuthorized {
                    let connectedHabits = habits.filter { $0.healthKitType != nil }
                    if connectedHabits.isEmpty {
                        Text("No habits connected to Apple Health yet")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(connectedHabits, id: \.id) { habit in
                            HStack(spacing: 8) {
                                Image(systemName: habit.category.iconName)
                                    .iconSize(11, relativeTo: .footnote, weight: .medium)
                                    .foregroundStyle(habit.category.style.baseColor)
                                Text(habit.title)
                                    .font(Typography.bodySmall)
                                Spacer()
                                if let typeStr = habit.healthKitType,
                                   let type = HealthKitHabitType(rawValue: typeStr) {
                                    Text(type.displayName)
                                        .font(Typography.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Integrations")
            }

            // MARK: - Calendar

            Section {
                HStack {
                    Label {
                        Text("Calendar")
                    } icon: {
                        SettingsIcon(systemName: "calendar", color: .red)
                    }

                    Spacer()

                    if eventKitService.isAuthorized {
                        Text("Connected")
                            .font(Typography.caption)
                            .foregroundStyle(AppColors.healthGreen)
                    } else {
                        Button("Connect") {
                            Task { await eventKitService.requestAccess() }
                        }
                        .font(Typography.bodySmall)
                        .foregroundStyle(AppColors.healthGreen)
                    }
                }

                if eventKitService.isAuthorized {
                    Text("Calendar events appear as context on your timeline")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Section 2: Customization

            Section("Customization") {
                Label {
                    HStack {
                        Text("Customization")
                        Spacer()
                        Text("Coming soon")
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    SettingsIcon(systemName: "paintbrush.fill", color: AppColors.accentPurple)
                }
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
                        SettingsIcon(systemName: "square.and.arrow.up", color: .blue)
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
                        SettingsIcon(systemName: "trash.fill", color: AppColors.warmRed)
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
                    Text("This will permanently delete all habits, logs, and photos. This cannot be undone.")
                }
            }

            // MARK: - Section 4: Support

            Section("Support") {
                Button {
                    HapticsEngine.lightTap()
                    replayTutorial()
                } label: {
                    Label {
                        Text("Replay Tutorial")
                            .foregroundStyle(.primary)
                    } icon: {
                        SettingsIcon(systemName: "arrow.counterclockwise", color: AppColors.healthGreen)
                    }
                }

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
                        SettingsIcon(systemName: "envelope.fill", color: .blue)
                    }
                }

                Button {
                    requestReview()
                } label: {
                    Label {
                        Text("Rate on App Store")
                            .foregroundStyle(.primary)
                    } icon: {
                        SettingsIcon(systemName: "star.fill", color: .yellow)
                    }
                }
            }

            // MARK: - Section 5: Legal

            Section {
                Link("Privacy Policy", destination: URL(string: "https://strataapp.co/privacy")!)
                    .foregroundStyle(.secondary)

                Link("Terms of Service", destination: URL(string: "https://strataapp.co/terms")!)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Section 6: Debug

            #if DEBUG
            Section("Debug") {
                Button {
                    resetOnboardingFlags()
                } label: {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                }

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
                Button {
                    UserDefaults.standard.set(false, forKey: "hasSeenBlockTapHint")
                    HapticsEngine.lightTap()
                } label: {
                    Label("Reset Block Tap Hint", systemImage: "hand.point.up")
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

    // MARK: - Replay Tutorial

    private func replayTutorial() {
        guard let onboarding else { return }
        onboarding.hasSeenWelcome = false
        onboarding.hasSeenHoldHint = false
        onboarding.hasSeenSkipHint = false
        onboarding.hasSeenFirstBlockHint = false
        onboarding.hasSeenNLPHint = false
        onboarding.hasSeenDragHint = false
        onboarding.hasSeenPhotoHint = false
        onboarding.hasSeenWeekHint = false
        onboarding.hasSeenContextMenuHint = false
        onboarding.dismissHint()
        UserDefaults.standard.removeObject(forKey: "hasSeenBlockTapHint")
        dismiss()
    }

    // MARK: - Reset Onboarding (Debug)

    private func resetOnboardingFlags() {
        for key in [
            "onb_welcome", "onb_hold", "onb_skip", "onb_firstBlock",
            "onb_nlp", "onb_drag", "onb_photo", "onb_week",
            "onb_contextMenu", "onb_sessionCount",
            "hasSeenBlockTapHint", "hasCompletedFirstHabit"
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - Settings Icon Badge

private struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Share Sheet (UIKit Bridge)

private struct ShareSheet: UIViewControllerRepresentable {
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
