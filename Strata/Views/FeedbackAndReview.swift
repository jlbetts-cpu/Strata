import MessageUI
import StoreKit
import SwiftData
import SwiftUI

/// **Send Feedback, wherever mail is** (2026-10-08).
///
/// It was a bare mailto link, which on a phone with no mail account set up
/// (more phones than you would think: people who only use Gmail's app) opens
/// nothing at all, so the one row for telling the owner something was broken
/// did nothing. Now: the system composer when the phone can send mail, the
/// mailto when another app can take it, and when neither can, the address to
/// copy. Subject and footer are `Support`'s.
struct FeedbackButton<Label: View>: View {
    @ViewBuilder var label: () -> Label

    @Environment(\.openURL) private var openURL
    @State private var composing = false
    @State private var offersCopy = false

    var body: some View {
        Button(action: send, label: label)
            .sheet(isPresented: $composing) {
                MailComposer(to: Support.address, subject: Support.subject, body: Support.currentFooter)
                    .ignoresSafeArea()
            }
            .alert("Send Feedback", isPresented: $offersCopy) {
                Button("Copy Address") { UIPasteboard.general.string = Support.address }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("There is no mail app set up on this iPhone. You can write to \(Support.address) from anywhere.")
            }
    }

    private func send() {
        HapticsEngine.lightTap()
        if MFMailComposeViewController.canSendMail() {
            composing = true
            return
        }
        guard let url = Support.mailtoURL(body: Support.currentFooter) else {
            offersCopy = true
            return
        }
        openURL(url) { accepted in
            if !accepted { offersCopy = true }
        }
    }
}

/// The system mail composer, filled in.
private struct MailComposer: UIViewControllerRepresentable {
    let to: String
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setToRecipients([to])
        mail.setSubject(subject)
        mail.setMessageBody(body, isHTML: false)
        return mail
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

/// **Asks for a review once, at a calm moment after a win lands**
/// (2026-10-08). The rule is `ReviewAsk.shouldAsk`; this only finds the
/// moment: a few seconds after today's count rises, so the block has landed
/// and the goal's booth, which opens 1.8s after a goal is crossed, has had
/// its chance to be up first, and then only if nothing is presented.
struct ReviewPrompt: ViewModifier {
    /// Today's blocks on the tower. A rise is a win landing.
    let blockCount: Int
    /// Read when the moment comes, not when the win landed: on the tower,
    /// no sheet, no booth, nothing still falling.
    var isCalm: () -> Bool

    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .task { ReviewAsk.noteLaunch(today: DateUtils.dateString(from: Date())) }
            .onChange(of: blockCount) { old, new in
                guard new > old else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(4))
                    consider()
                }
            }
    }

    private func consider() {
        let defaults = UserDefaults.standard
        let today = DateUtils.dateString(from: Date())
        let firstDay = defaults.string(forKey: ReviewAsk.firstDayKey)
        let asked = defaults.string(forKey: ReviewAsk.askedVersionKey)
        let version = ReviewAsk.currentVersion
        guard ReviewAsk.mayAsk(firstDay: firstDay, today: today, askedVersion: asked, version: version),
              isCalm(), !Self.somethingIsPresented else { return }
        var recent = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed },
                                               sortBy: [SortDescriptor(\.dateString, order: .reverse)])
        recent.fetchLimit = 200
        recent.propertiesToFetch = [\.dateString]
        guard let logs = try? modelContext.fetch(recent) else { return }
        let days = Set(logs.map(\.dateString)).count
        guard ReviewAsk.shouldAsk(wins: logs.count, winDays: days, firstDay: firstDay, today: today,
                                  askedVersion: asked, version: version, calm: true) else { return }
        defaults.set(version, forKey: ReviewAsk.askedVersionKey)
        requestReview()
    }

    /// A sheet or cover is up, whoever raised it (`MainAppView`'s booth
    /// check, the same question).
    private static var somethingIsPresented: Bool {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            .contains { $0.isKeyWindow && $0.rootViewController?.presentedViewController != nil }
    }
}
