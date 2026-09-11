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

                Text("Last updated 11 September 2026")
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
         "Your wins: their names, sizes, colours, dates, any photo you attach, and "
         + "where a photo was taken if you turn that on. And, if you add them, "
         + "your name and a profile photo. That is the whole of it."),
        ("Where it is stored",
         "On your device. Strata has no account, no server, and no analytics. "
         + "Nothing you log is sent anywhere, and nobody but you can read it."),
        ("Photos",
         "A photo you attach is copied into Strata's own storage on your device so "
         + "the block still has it if you later remove the original. Deleting a win "
         + "deletes its photo with it."),
        ("Your profile",
         "The name and profile photo you add in Profile stay on your device, like "
         + "everything else, and are never sent anywhere. The photo is a small copy "
         + "made from the one you choose; removing it deletes that copy."),
        ("Your head",
         "If you make a head, Strata takes a few photos with the front camera and turns "
         + "them into your head, right on your device. It keeps only those small "
         + "pictures, never video, and never sends them anywhere. Your head only shows "
         + "up where you turn it on, and Delete Head removes it."),
        ("Places",
         "Strata asks first, and iOS will not give it a position until you say yes. "
         + "After that, Strata notes where you were at "
         + "the moment you take a photo, so your wins can appear on your map. It "
         + "looks only while the camera is open, never in the background, and the "
         + "coordinates are stored on your device beside the photo and nowhere "
         + "else. Photos you took before you turned it on have no place and cannot "
         + "be given one."),
        ("Sharing",
         "Sharing a tower renders an image on your device and hands it to the iOS "
         + "share sheet. Where it goes from there is between you and whatever app "
         + "you send it to."),
        ("Deleting everything",
         "Profile › Settings › Data › Reset All Data removes every win, every photo, "
         + "your name, profile photo and head, and your tower from the device "
         + "permanently. Deleting the app does the same."),
        ("Contact",
         "Questions about any of this: jbett5@hotmail.com")
    ]
}
