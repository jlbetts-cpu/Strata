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

            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                rule("person.crop.circle", "Post your own wins and your own photos.")
                rule("hand.raised", "Nothing hateful, sexual, violent or cruel. None of it is allowed, ever.")
                rule("exclamationmark.bubble", "Report anything that breaks these. Every report is looked at within a day, and whatever or whoever broke them is removed.")
                rule("nosign", "Block anyone, any time. They are not told.")
            }

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

    private func rule(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(width: 24)
            Text(text)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
