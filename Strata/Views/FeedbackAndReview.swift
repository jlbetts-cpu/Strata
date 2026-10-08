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

