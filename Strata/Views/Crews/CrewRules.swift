import SwiftUI

/// **The few rules of a crew, agreed to once, before the first one.**
///
/// App Review asks this of any app where people share with each other
/// (Guideline 1.2): terms that say objectionable content and abusive people
/// are not tolerated, agreed to before sharing starts, with a way to report
/// and a way to block. Four plain lines, in the app's own voice, and one
/// button. Nothing to scroll and nothing legal-sounding: the privacy policy
/// is a link for whoever wants it.
enum CrewRules {
    static let key = "crews.rulesAccepted.v1"

    static var accepted: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct CrewRulesSheet: View {
    var onAgree: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapWide) {
            Text("Crew rules")
                .font(Typography.screenTitle)
                .foregroundStyle(AppColors.inkPrimary)
                .padding(.top, GridConstants.gapSection)

            // `FeatureList`, as every explanation is (2026-10-08). The words
            // are the same promises App Review reads (guideline 1.2: no
            // objectionable content, a way to report with a response within
            // a day, a way to block), split into a title and its detail.
            FeatureList(rows: [
                ("MarkCheck", "Your own wins", "Post your own wins and your own photos."),
                ("MarkSlash", "Nothing hurtful", "Nothing hateful, sexual, violent or cruel. Ever."),
                ("MarkAlert", "Report it", "Every report is looked at within a day, and whatever or whoever broke these rules is removed."),
                ("MarkLock", "Block anyone", "Any time. They are not told."),
            ])

            Spacer(minLength: 0)

            VStack(spacing: GridConstants.gapTight) {
                PrimaryCapsule(title: "I Agree") {
                    HapticsEngine.success()
                    CrewRules.accepted = true
                    onAgree()
                }

                Button("Not Now") { onNotNow() }
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.bottom, GridConstants.gapWide)
        .background(WarmBackground().ignoresSafeArea())
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}
