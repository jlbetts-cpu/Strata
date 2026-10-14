import SwiftUI
import UserNotifications

/// **Crew Alerts, link by link** (`AlertCheck`; TestFlight only). Four rows,
/// each the last thing that link did, in plain words, with the error's own
/// words under a failure, and Check Again to ask iCloud now. A friend's win
/// reaches a closed phone only if all four say yes.
struct AlertCheckSection: View {
    @State private var permission: UNAuthorizationStatus = .notDetermined
    @State private var checking = false
    @State private var tick = 0

    var body: some View {
        Section {
            row("Allowed", ok: permission == .authorized || permission == .provisional,
                detail: permissionWords)
            outcomeRow("Registered for alerts", AlertCheck.outcome(.push))
            outcomeRow("Listening in iCloud", AlertCheck.outcome(.listen))
            outcomeRow("Last alert sent to a crew", AlertCheck.outcome(.send))
            Button {
                HapticsEngine.lightTap()
                checking = true
                Task {
                    await SocialStore.shared.checkAlertsNow()
                    await readPermission()
                    checking = false
                    tick += 1
                }
            } label: {
                Text(checking ? "Checking" : "Check Again")
                    .foregroundStyle(AppColors.inkPrimary)
            }
            .disabled(checking)
        } header: {
            FormSectionLabel("Crew Alerts")
        } footer: {
            Text("A friend's win reaches this phone closed only when every row says Yes. Only on TestFlight.")
                .formFooter()
        }
        .id(tick)
        .task { await readPermission() }
    }

    private var permissionWords: String {
        switch permission {
        case .authorized, .provisional, .ephemeral: "Yes"
        case .denied: "Off in Settings"
        default: "Not asked yet"
        }
    }

    private func readPermission() async {
        permission = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func outcomeRow(_ title: String, _ outcome: AlertCheck.Outcome?) -> some View {
        guard let outcome else { return AnyView(row(title, ok: false, detail: "Nothing yet")) }
        let when = outcome.at.formatted(date: .omitted, time: .shortened)
        return AnyView(row(title, ok: outcome.ok,
                           detail: outcome.ok ? "Yes, \(when)" : "No, \(when)",
                           error: outcome.ok ? nil : outcome.detail))
    }

    private func row(_ title: String, ok: Bool, detail: String, error: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).foregroundStyle(AppColors.inkPrimary)
                Spacer(minLength: GridConstants.gapTight)
                Text(detail)
                    .font(Typography.headerSmall)
                    .foregroundStyle(ok ? AppColors.inkSecondary : AppColors.destructiveInk)
            }
            if let error, !error.isEmpty {
                Text(error)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkTertiary)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
