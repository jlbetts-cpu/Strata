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
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Self.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(Typography.headerMedium)
                        Text(section.body)
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Last updated 7 September 2026")
                    .font(Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GridConstants.horizontalPadding)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let sections: [(title: String, body: String)] = [
        ("What Strata stores",
         "Your wins — their names, sizes, colours, dates, and any photo you attach. "
         + "That is the whole of it."),
        ("Where it is stored",
         "On your device. Strata has no account, no server, and no analytics. "
         + "Nothing you log is sent anywhere, and nobody but you can read it."),
        ("Photos",
         "A photo you attach is copied into Strata's own storage on your device so "
         + "the block still has it if you later remove the original. Deleting a win "
         + "deletes its photo with it."),
        ("Apple Health and Calendar",
         "Only if you connect them, and only while you leave them connected. Strata "
         + "reads from them to add context to your day; it never writes to them and "
         + "never copies them off your device."),
        ("Sharing",
         "Sharing a tower renders an image on your device and hands it to the iOS "
         + "share sheet. Where it goes from there is between you and whatever app "
         + "you send it to."),
        ("Deleting everything",
         "Settings › Data › Reset All Data removes every win, every photo, and your "
         + "tower from the device permanently. Deleting the app does the same."),
        ("Contact",
         "Questions about any of this: support@strataapp.co")
    ]
}
