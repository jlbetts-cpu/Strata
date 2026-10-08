import SwiftUI

/// The privacy policy, in the app.
///
/// It used to be a link to `https://strataapp.co/privacy`, which does not
/// resolve — the domain answers nothing at all. A dead privacy link is worse
/// than no link: App Review opens it, and so does anyone who wants to know
/// what happens to their photos. The text lives here so it is true whatever
/// the domain is doing.
///
/// This does NOT remove the need for a hosted copy: App Store Connect asks for
/// a privacy policy URL and will not take an in-app screen instead. It removes
/// the broken promise in the meantime.
///
/// **The text is generated** (2026-10-08): `tools/policy/policy.py` writes
/// `PrivacyPolicyText` and `docs/privacy.html` from one source, because the
/// two copies drifted (different dates, missing sections). Edit it there.
///
/// **Crews (2026-10-02) are the first thing that sends anything**, so the
/// sections below say exactly what a crew receives and nothing it does not:
/// the key sets in `CrewRecords`, the age rules in `CrewAge`, the report in
/// `CrewSafety.report`. Change one of those and this text, `docs/privacy.html`
/// and `PrivacyInfo.xcprivacy` change with it (CLAUDE.md, "What the app
/// CLAIMS about itself must be true"). Every sentence is written so it is
/// true with `CrewsFlag` off as well: "if you join a crew".
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GridConstants.gapWide) {
                Text(PrivacyPolicyText.lede)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                ForEach(PrivacyPolicyText.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                        // **The same label Settings' sections wear.** This page
                        // is opened FROM a Settings row, and uppercase and
                        // kerned is the register a policy wants: it reads as a
                        // document, not as prose.
                        FormSectionLabel(section.title)
                        ForEach(section.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(Typography.bodyLarge)
                                .foregroundStyle(AppColors.inkSecondary)
                        }
                    }
                }

                Link("Terms of Use", destination: Support.termsURL)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                    .frame(minHeight: 44)

                // `inkTertiary`: `inkQuiet` is held to 3:1 because it is for
                // glyphs, and this is a sentence (2026-10-02, design review).
                Text("Last updated \(PrivacyPolicyText.updated)")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkTertiary)
                    .padding(.top, GridConstants.gapTight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GridConstants.horizontalPadding)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle("Privacy", drawn: false)
    }

}
