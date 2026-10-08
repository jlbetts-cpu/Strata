#!/usr/bin/env python3
"""The privacy policy, written once.

**Two copies drifted** (the 2026-10-08 audit: the in-app policy was dated 5
October and the hosted one 8 October, and the in-app one had lost sections).
So the text lives here and both copies are generated from it:

    python3 tools/policy/policy.py

writes docs/privacy.html (the URL App Store Connect links to) and
Strata/Views/PrivacyPolicyText.swift (the screen in Settings).
StrataTests/PrivacyPolicyTests.swift fails if the two ever disagree.

Every sentence must be true of the code (CLAUDE.md: what the app claims about
itself must be true). No long dashes.
"""
import html, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
UPDATED = "8 October 2026"
EMAIL = "jbett5@hotmail.com"

LEDE = ("Some Wins has no account and no server of its own. What you log stays on "
        "your device and in your own iCloud, unless you send a win to a crew.")

SECTIONS = [
    ("In short", [
        "The only things that leave your phone are: what you sync to your own "
        "iCloud, the wins you send to a crew, a report if you make one, and "
        "anonymous usage counts, which you can turn off. Some Wins includes no "
        "third-party code, shows no ads and never sells anything about you.",
    ]),
    ("What Some Wins stores", [
        "Your wins: their names, sizes, colours, dates, any photo you attach, and "
        "where a photo was taken if you turn that on. Your journal, drawings, "
        "stickers and photo strips. And, if you add them, your name, a profile "
        "photo and a head.",
    ]),
    ("Where it is stored", [
        "On your device, and in your own iCloud when iCloud is on for Some Wins, "
        "so it reaches your other devices and comes back if you reinstall. Some "
        "Wins cannot read your iCloud; only your Apple Account can. Nothing you "
        "log is sent anywhere else unless you send a win to a crew.",
    ]),
    ("Anonymous usage", [
        "Some Wins counts which parts of the app are used, so the parts that do "
        "not work can be fixed: things like a win being logged and its size, a "
        "strip being printed, which tab is opened, how far someone gets through "
        "the first screens, a crew being started, a tip and its size, and the "
        "kind of crash or freeze if the app has one.",
        "Each count carries the app version, the iPhone model, the iOS version, "
        "the language and region setting, a random number for the session and a "
        "random number made for this install in place of anything about you. It "
        "never includes what you write, what you photograph, who you are or "
        "where you are. The counts go to TelemetryDeck, a German company that "
        "keeps them in the EU, and are not "
        "linked to you or used to track you.",
        "Turn them off in Settings, Share Anonymous Usage. Turning them off also "
        "deletes the random number, so turning them back on starts as a stranger.",
    ]),
    ("Photos", [
        "A photo you attach is copied into Some Wins' own storage so the block "
        "still has it if you later remove the original. Deleting a win deletes "
        "its photo with it.",
        "Photos are kept on this device, and a smaller copy of each is kept in "
        "your own iCloud when iCloud is on for Some Wins, so a new phone gets "
        "them back. If your iCloud is full, new photos stay on this device "
        "until there is room. They are also in your iPhone's iCloud Backup if "
        "that is on, and in the backup file you can make in Settings.",
    ]),
    ("Places", [
        "Some Wins asks first, and iOS will not give it a position until you say "
        "yes. After that, Some Wins notes where a photo was taken, at the moment "
        "you take it, so your wins can appear on your map. It checks only while "
        "the camera is open, never in the background. The place is kept with the "
        "win on your device and in your iCloud, and is never sent to a crew.",
        "Photos you took before you turned it on have no place and cannot be "
        "given one.",
    ]),
    ("Your profile", [
        "The name and profile photo you add in Profile stay with your wins. If you "
        "join a crew, the people in it see your first name, and your profile "
        "photo if you are 16 or older. Removing the photo deletes it.",
    ]),
    ("Your head", [
        "If you make a head, Some Wins takes a few photos with the front camera "
        "and Apple's on-device tools find your face and cut it out. It keeps only "
        "those small cut-out pictures and where to place them, never video and "
        "never measurements of your face, and none of it leaves your device to "
        "be analysed. Your head appears only where you turn it on, and Delete "
        "Head removes it.",
        "If you are in a crew and 16 or older, a smaller copy of your head goes "
        "to the crew while it shows anywhere, after the same check photos get.",
    ]),
    ("Sharing", [
        "Sharing a photo or a strip hands it to the iOS share sheet. Where it goes "
        "from there is between you and whatever app you send it to. Save to "
        "Photos, if you leave it on, puts a copy of each photo you take in your "
        "photo library. Save Video on a replay saves a video made on your device "
        "to your camera roll.",
    ]),
    ("Crews", [
        "A crew is up to 8 people who share a tower for the day. Crews need iOS 26 "
        "or later. A crew runs on iCloud: it lives in the iCloud of whoever "
        "started it, and Apple shares it with the people in it. There is no Some "
        "Wins server, and Some Wins cannot read what a crew holds.",
        "A win goes to a crew only if you tick that crew for that win. The crews "
        "you ticked last stay ticked until you change them.",
        "When someone adds a win or reacts to yours, their phone also leaves a "
        "short note in iCloud's public area so iCloud can alert the crew. The "
        "note holds scrambled tags for the crew and the people (which only phones "
        "already in the crew can match), the win's random id, and whether it is "
        "a win or a reaction: no names, titles or photos. The phone that left the "
        "note deletes it within minutes. Your phone then reads the win from the "
        "crew and writes the notification itself.",
    ]),
    ("What a crew sees", [
        "Of a win you send: its title, colour, size and icon, its photo, and when "
        "you logged it. The photo is a smaller copy with no place and no camera "
        "details in it. With it, your first name, and from 16, your profile photo "
        "and your head. Never your journal, notes, places or mood. Tag someone "
        "and they are asked whether to keep a copy; only your crew sees who a win "
        "was with.",
        "Everything you send to a crew's day chat, the replies under a win, and "
        "the drawings, stickers and reactions you send are seen by everyone in "
        "the crew. A short list of words is kept out of the chat.",
        "The crew itself has a name and a photo that anyone in it can change, and "
        "keeps the time zone of whoever started it, so its day ends at one "
        "midnight for everyone.",
    ]),
    ("Taking a win back", [
        "Untick a crew on a win and the win leaves that crew. Delete a win and "
        "every copy goes. Remove its photo and the photo goes from every copy. "
        "Leave a crew and your wins leave with you; end a crew you started and it "
        "is deleted for everyone.",
        "A crew keeps two weeks of days, and older wins and their photos are "
        "deleted the next time anyone opens it. Whoever started a crew can remove "
        "any win in it, and anyone can hide a win for themselves.",
    ]),
    ("Block and Report", [
        "Block hides that person's wins, head and name in every crew on your "
        "phones. Your blocks and mutes reach your other devices through your own "
        "iCloud, which no crew can see. They are not told. If you started the "
        "crew, they are removed from it too.",
        "You can report a win, a person (their name, photo or head) or a crew "
        "(its name or picture). A report sends Some Wins what you reported (the "
        "title and, if there is one, the photo), the reason you chose, the random "
        "ids of the crew, the person and you, and the iCloud account identifier "
        "that sent it, so the account can be removed from every crew. A report "
        "goes only to Some Wins, never to the crew, and only Some Wins can read "
        "it. Every report is looked at within a day, and reports are deleted "
        "after a year unless the law requires keeping one longer. Content that "
        "appears to exploit a child is reported to the National Center for "
        "Missing and Exploited Children, as the law requires.",
    ]),
    ("The photo check", [
        "Before a photo goes to a crew, your phone checks it with Apple's "
        "sensitive content check, when Sensitive Content Warning or Communication "
        "Safety is turned on. A photo it flags stays with you, and the win goes "
        "without it. Photos that arrive from your crews are checked on your phone "
        "the same way, and one it flags is never shown. Under 16, with the check "
        "turned off, friends' photos are not shown.",
    ]),
    ("Ages", [
        "Crews are for 13 and up. The first time you open Crews, Some Wins asks "
        "for your age range through Apple, never your birthday, and keeps the "
        "answer on your phone. Under 13, Crews do not open. From 13 to 15, crews "
        "work, but your photos, profile photo and head are never sent. If you "
        "would rather not say, Some Wins treats you as 13 to 15.",
    ]),
    ("Deleting everything", [
        "Profile, Settings, Data, Reset All Data deletes every win, photo, journal entry, "
        "drawing, sticker and strip, your name, profile photo and head, from "
        "this device and from your iCloud. Leave your crews first, and end any "
        "you started, so your wins leave them too.",
        "Deleting the app removes it from this device only: what is in your "
        "iCloud stays there and comes back if you reinstall. To remove that "
        "without the app, open the Settings app, your name, iCloud, and manage "
        "the storage Some Wins uses.",
    ]),
    ("Your rights", [
        "Some Wins does not sell or share personal information, and does not "
        "track you across other apps or websites, so a Do Not Track signal "
        "changes nothing here. Because there is no server, the only things Some "
        "Wins itself holds are reports and the anonymous counts. You can ask what "
        "it holds about you, or ask for it to be deleted, by writing to the "
        "address below. Where you live may also give you the right to complain "
        "to a data protection authority.",
    ]),
    ("Children", [
        "Some Wins is not directed at children under 13, and Crews do not open "
        "for anyone under 13. Some Wins receives only the reports someone "
        "chooses to make and the anonymous counts above, which say nothing about "
        "who you are.",
    ]),
    ("Removal requests", [
        "Anyone, including people who do not use Some Wins, can ask for an "
        "intimate image shared without consent to be removed. How is in the "
        "Terms of Use, and a valid request is acted on within 48 hours.",
    ]),
    ("Changes", [
        "If this policy changes, the date at the top changes with it.",
    ]),
    ("Contact", [
        "Some Wins is made by Jayden Betts, in California, USA. Questions about "
        "any of this: " + EMAIL,
    ]),
]


def linkify(text):
    t = html.escape(text, quote=False)
    t = t.replace(EMAIL, f'<a href="mailto:{EMAIL}">{EMAIL}</a>')
    t = t.replace("Terms of Use", '<a href="terms.html">Terms of Use</a>')
    return t


def write_html():
    page = (ROOT / "docs/privacy.html").read_text()
    head = page[: page.index("<body>")]
    parts = ['<body>', '<main>', '  <h1>Privacy</h1>',
             f'  <p class="sub">Some Wins · last updated {UPDATED}</p>', '',
             f'  <p class="lede">{linkify(LEDE)}</p>']
    for title, paras in SECTIONS:
        parts += ['', f'  <h2>{html.escape(title)}</h2>']
        parts += [f'  <p>{linkify(p)}</p>' for p in paras]
    parts += ['', '  <footer>Some Wins is made by Jayden Betts. '
              '<a href="terms.html">Terms of Use</a></footer>', '</main>', '</body>', '</html>', '']
    (ROOT / "docs/privacy.html").write_text(head + "\n".join(parts))


def swift_string(s):
    out = '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    # The address lives once, in `Support` (SupportTests.oneAddress).
    return out.replace(EMAIL, "\\(Support.address)")


def write_swift():
    lines = [
        "// GENERATED by tools/policy/policy.py. Edit the policy THERE and rerun it;",
        "// docs/privacy.html is generated from the same text, and",
        "// StrataTests/PrivacyPolicyTests.swift fails if the two disagree.",
        "",
        "nonisolated enum PrivacyPolicyText {",
        f"    static let updated = {swift_string(UPDATED)}",
        f"    static let lede = {swift_string(LEDE)}",
        "    static let sections: [(title: String, paragraphs: [String])] = [",
    ]
    for title, paras in SECTIONS:
        lines.append(f"        ({swift_string(title)}, [")
        lines += [f"            {swift_string(p)}," for p in paras]
        lines.append("        ]),")
    lines += ["    ]", "}", ""]
    (ROOT / "Strata/Views/PrivacyPolicyText.swift").write_text("\n".join(lines))


if __name__ == "__main__":
    for _, paras in SECTIONS:
        for p in paras:
            assert "—" not in p and "–" not in p, p
    write_html()
    write_swift()
    print("wrote docs/privacy.html and Strata/Views/PrivacyPolicyText.swift")
