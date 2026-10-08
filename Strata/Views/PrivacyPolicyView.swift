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
                ForEach(Self.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                        // **The same label Settings' sections wear.** This page
                        // is opened FROM a Settings row, and its headings were
                        // `headerMedium` on the app's default ink while the
                        // headings a tap behind it were the platform's grouped
                        // list style. Two ranks of heading, one after the other,
                        // for the same job. `FormSectionLabel` is the style
                        // section 2 of `docs/design-system-future.md` names, and
                        // uppercase and kerned is also the register the page
                        // wants: a policy reads as a document, not as prose.
                        FormSectionLabel(section.title)
                        Text(section.body)
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
                }

                // `inkTertiary`: `inkQuiet` is held to 3:1 because it is for
                // glyphs, and this is a sentence (2026-10-02, design review).
                Text("Last updated 5 October 2026")
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

    private static let sections: [(title: String, body: String)] = [
        ("What Some Wins stores",
         "Your wins: their names, sizes, colours, dates, any photo you attach, and "
         + "where a photo was taken if you turn that on. And, if you add them, "
         + "your name and a profile photo. Your journal stays in your own iCloud "
         + "and is never shared with a crew. That is the whole of it."),
        ("Where it is stored",
         "On your device. Some Wins has no account and no server of its own. "
         + "Nothing you log is sent anywhere unless you send a win to a crew, "
         + "and nobody but you can read it unless you do."),
        ("Anonymous usage",
         "Some Wins counts which parts of the app are used, like a win being logged "
         + "or a strip being printed, so the parts that do not work can be fixed. The "
         + "counts go to TelemetryDeck with a random number in place of anything about "
         + "you, and never include what you write, what you photograph or where you "
         + "are. They are not used to track you. Turn them off in Settings, Share "
         + "Anonymous Usage."),
        ("Photos",
         "A photo you attach is copied into Some Wins' own storage on your device so "
         + "the block still has it if you later remove the original. Deleting a win "
         + "deletes its photo with it."),
        ("Your profile",
         "The name and profile photo you add in Profile stay on your device. If "
         + "you join a crew, the people in it see your name. The profile photo is "
         + "never sent anywhere. It is a small copy made from the one you choose; "
         + "removing it deletes that copy."),
        ("Your head",
         "If you make a head, Some Wins takes a few photos with the front camera and turns "
         + "them into your head, right on your device. It keeps only those small "
         + "pictures, never video. Your head only shows up where you turn it on, and "
         + "Delete Head removes it. If your head is on your tower and you join a "
         + "crew, a smaller copy goes to the crew so its people can see it; "
         + "otherwise it never leaves your device."),
        ("Places",
         "Some Wins asks first, and iOS will not give it a position until you say yes. "
         + "After that, Some Wins notes where a photo was taken, at "
         + "the moment you take it, so your wins can appear on your map. It "
         + "checks only while the camera is open, never in the background, and the "
         + "coordinates are stored on your device beside the photo and nowhere "
         + "else. Photos you took before you turned it on have no place and cannot "
         + "be given one."),
        ("Sharing",
         "Sharing a photo hands it to the iOS share sheet. Where it goes from "
         + "there is between you and whatever app you send it to. Save to Photos, "
         + "if you leave it on, puts a copy of each photo you take in your photo "
         + "library, where it is yours like any other. When you press Save Video on "
         + "a replay, Some Wins saves that video to your camera roll. It is made on your "
         + "device and not sent anywhere."),
        ("Crews",
         "A crew is up to 8 people who share a tower for the day. It runs on "
         + "iCloud: a crew lives in the iCloud of whoever started it, and Apple "
         + "shares it with the people in it. There is no Some Wins server, and Some Wins "
         + "cannot read what a crew holds. A win goes to a crew only if you tick "
         + "that crew for that win; the crews you ticked last stay ticked until you "
         + "change them. When someone adds a win or reacts to yours, their phone "
         + "also leaves a short note in iCloud's public area so iCloud can alert "
         + "the crew. The note holds scrambled tags for the crew and the people "
         + "(which only phones already in the crew can match), the win's random "
         + "id, and whether it is a win or a reaction: no names, titles or photos. "
         + "Your phone asks to hear only about your crews, never from people you "
         + "blocked or crews you muted. The phone that left the note deletes it, "
         + "usually within minutes. Your phone then reads the win from the crew "
         + "and writes the notification itself."),
        ("What a crew sees",
         "Of a win you send: its title, colour, size and icon, its photo, and when "
         + "you logged it. The photo is a smaller copy with no place and no camera "
         + "details in it. With it, your first name, your head if it is on your tower, "
         + "and your profile photo, which is never sent if you are under 16. "
         + "Never your notes, captions, places or mood. Tag someone and they are "
         + "asked whether to keep a copy; only your crew sees who a win was with. "
         + "The crew itself has a name "
         + "and a photo that anyone in it can change, and keeps the time zone of "
         + "whoever started it, so its day ends at one midnight for everyone."),
        ("Taking a win back",
         "Untick a crew on a win and the win leaves that crew. Delete a win and "
         + "every copy goes. Remove its photo and the photo goes from every copy. "
         + "Leave a crew and your wins leave with you; end a crew you started and "
         + "it is deleted for everyone. A crew keeps two weeks of days, and older "
         + "wins and their photos are deleted the next time anyone opens it. "
         + "Whoever started a crew can remove any win in it, and anyone can hide "
         + "a win for themselves."),
        ("Block and Report",
         "Block hides that person's wins, head and name in every crew on your "
         + "phones. Your blocks and mutes reach your other devices through your "
         + "own iCloud, which no crew can see. They are not told. If you started the crew, they are removed "
         + "from it too. You can unblock them in a crew's details. You can report "
         + "a win, a person (their name, photo or head) or a crew (its name or "
         + "picture). A report sends Some Wins what you reported (the title and, "
         + "if there is one, the photo), the reason you chose, the random ids of "
         + "the crew, the person and you, and the iCloud account identifier that "
         + "sent it, so the account can be removed from every crew. A report goes "
         + "only to Some Wins, never to the crew, only Some Wins can read it, and "
         + "every report is looked at within a day."),
        ("The photo check",
         "Before a photo goes to a crew, your phone checks it with Apple's "
         + "sensitive content check, when Sensitive Content Warning or "
         + "Communication Safety is turned on. A photo it flags stays with you, "
         + "and the win goes without it. Photos that arrive from your crews are "
         + "checked on your phone the same way, and one it flags is never shown. "
         + "Under 16, with the check turned off, friends' photos are not shown."),
        ("Ages",
         "Crews are for 13 and up. The first time you open Crews, Some Wins asks for "
         + "your age range through Apple, never your birthday, and keeps the answer "
         + "on your phone. Under 13, Crews do not open. From 13 to 15, crews work, "
         + "but photos are never sent. If you would rather not say, Some Wins treats "
         + "you as 13 to 15."),
        ("Deleting everything",
         "Profile › Settings › Data › Reset All Data removes every win, every photo, "
         + "your name, profile photo and head, and your tower from the device "
         + "permanently. Deleting the app does the same."),
        ("Contact",
         "Questions about any of this: jbett5@hotmail.com")
    ]
}
