# Invites and finding friends (research, 2026-10-13)

The owner's ask: "making crews easy enough and inviting people because I dont
want anyone to not know what to do or who to add and should we have a add
friends button i want to push engagement and invites as much as possible and
not just outside the app but in the app knowing who of your contacts are on
the app and stuff like that."

Read-only pass over `~/Developer/Strata` at `e9d1bf7`. Nothing was built.
Tags on every outside claim: **(a)** research or data, **(b)** seen in a
shipping product or its own docs, **(c)** my inference. Sources at the foot.

## The answer in five lines

1. **Yes to an add-friends button, as a verb, not a friends list.** "Invite a
   Friend" on the Crews tab makes a crew of two and opens the share sheet in
   one tap. A friend chat is already a crew of two, so nothing new is stored.
2. **The biggest leak is not on the inviter's side, it is the friend who does
   not have the app yet.** Today they install, sit through onboarding, and the
   invitation is gone; they have to find the text again on their own.
3. **A solo person is asked to invite exactly once, for twelve seconds.** The
   second moment (a first reaction) needs a crew, so someone who closed the
   first never sees another.
4. **"Who of your contacts are on the app" cannot be built well on this
   stack.** The app cannot know its own user's phone number, CloudKit's
   contact discovery has been gone since iOS 17, and hashed numbers in a
   public database can be reversed by anyone. It would also turn the
   privacy label and policy from "nothing about your contacts" into "phone
   number collected".
5. **What gives the same feeling without that**: the share sheet's own row of
   the people you text most (already there), plus "people you already share a
   crew with" when starting a new crew (no new iCloud fields).

---

## 1. What exists today

### Every way in

**Starting or sending an invitation**

| # | Where | What it does | Notes |
|---|---|---|---|
| S1 | Crews tab, empty state, **Start a Crew** | Opens New Crew (photo and name, both optional), then **Invite** makes the crew and opens the share sheet | `CrewsListView.empty`, `NewCrewSheet.start` |
| S2 | Crews tab, compose glyph top right | Same New Crew sheet. At five crews it says why not | Label "Start a Crew" |
| S3 | Wins tab tip after your **very first win**: "Your win is up. Who else should see it?" | **Start a Crew** (no crew) routes to S1 and the share sheet carries a picture of your tower. **Invite** (has a crew) opens the share sheet for your first crew | `FirstWinInvite`, 1.4 s after the block lands, leaves by itself after 12 s |
| S4 | Same tip, once more, after the **first reaction** anyone sends you | Same | Only if S3 was shown. Needs a crew to happen at all |
| S5 | Crew Info (press the middle of a crew's tower), **Invite** row under People | Share sheet with the link | Hidden at 8 people. Two taps from the tower, not visible on it |
| S6 | Crew Info, QR glyph top left, **Show a Code** | The same link as a QR for a friend beside you | Leaves the screen when the app goes to the background |

There is **no invite step in onboarding** (film, then the gesture, head,
thank-you, goal and name pages) and **no Invite standing on a crew's own
screen** (the owner removed it 2026-10-13: "I dont like how invite is just
there").

**Accepting one**

| # | Path | Taps to be in the crew |
|---|---|---|
| A1 | Link in Messages, app installed, Crews used before | **1**: the link opens the app (universal link, `applinks:somewins.xyz`, live since build 135) and joins |
| A2 | Same, first time in Crews | **3**: link, Agree to the crew rules, the system's age-range sheet |
| A3 | QR scanned with the Camera | As A1 or A2, plus the Camera's banner tap |
| A4 | Link opened inside Instagram, Snapchat or another in-app browser | Universal links usually do not fire there (c); `join.html` shows **Open in Some Wins**, one extra tap |
| A5 | **No app yet** | Link, `join.html`, **Get Some Wins** (TestFlight today, and TestFlight itself if not installed), Install, Open, the film and five onboarding pages with a required name, then **go back to Messages on their own** and tap the link again, Agree, age. **About 13 taps and one step the app never asks for.** The invitation is not carried across the install (`CrewRouter.pendingInvite` only holds a link the app has already seen) |

### Taps from first launch to a friend in a crew (inviter)

| Route | Taps | What is in the way |
|---|---|---|
| Crews tab first | Onboarding about 6, then Crews tab 1, the Crews film (6 s, skippable), Agree 1, age 1, Start a Crew 1, Invite 1, a person in the share sheet 1, Send 1: **about 13**, **7 from the tab** | Three things happen before the first button: the film, the rules, the age question |
| First-win tip | First win, then Start a Crew 1, film, Agree 1, age 1, New Crew opens itself, Invite 1, person 1, Send 1: **about 6 after the win** | Only if the 12 s tip is pressed in time |
| Second crew, or more people later | Crew row 1, middle of the tower 1, Invite 1, person 1, Send 1: **5** | Invite lives in Crew Info only |

Then the friend's side (A1 to A5) on top. For a friend without the app, the
end-to-end count is roughly 13 for the inviter and 13 for the friend, and the
friend's half includes a step nothing prompts.

### Where someone gets stuck

1. **The friend without the app loses the invitation at install** (A5). The
   page says "Get Some Wins first, then open this link again", but after
   TestFlight and onboarding the person is in the app, not on that page, and
   nothing in the app says a link is waiting. This is the largest leak in the
   loop (c): every invitation to a new person crosses it.
2. **One prompt, ever, for a solo person.** S4 requires a reaction, which
   requires a crew. Close S3, or miss its 12 seconds, and the app never asks
   again. The empty Crews tab is the only remaining way in, and it opens on
   "Start a Crew", a concept, not a person.
3. **A crew of one is a dead end.** Close the share sheet without sending
   and you have a crew with "Just you so far." on its row, no Invite on its
   screen, and the Invite two taps deep in Crew Info. The research of earlier
   today proposed ending such a crew quietly (`qol-research-2026-10-13.md`,
   M14, question 3); that question is still open.
4. **"Who to add" is answered only after you have committed.** The share
   sheet's row of the people you message most is a good answer (b) [H8], but
   it appears after Start a Crew, New Crew and Invite. Before that, the app
   names nobody.
5. **The vocabulary is "crew", the person is thinking "friend".** The owner's
   own question was "add friends". Every button says Crew or Invite; nothing
   says Friend except the tip's "Who else should see it?" (c)
6. **Three gates on a first visit to Crews**: the film, the rules, the age
   question. Each is justified (rules are App Review 1.2; age is the 13+
   rule), but they come before the one thing the person came to do (c).
7. **We cannot see the funnel.** `crew_invite_sent` fires when the share
   sheet OPENS (`CrewSharing.invite`), not when something is sent, so invites
   sent per person and joins per invite (the two halves of a viral
   coefficient) cannot be read from TelemetryDeck today.
8. **A friend on an older iPhone dead-ends.** Crews need iOS 26. They install,
   open the link, and are told the phone is too old. Nothing on the join page
   warns them first.

---

## 2. How shipping apps do it

| App | Friends on the app | Suggestions | Invite from contacts | Placement | Tag |
|---|---|---|---|---|---|
| **BeReal** | Contacts who have accounts appear in an "Add Your Contacts" list; the list is absent if none do | Yes, from contacts | Share your username link | Friends icon top left of the feed; contacts step in setup can be skipped or denied | (b) [B2][B3] |
| **Locket** (2022) | Phone number sign-up; **Contacts access was required**, the app would not work without it | Pick close friends | Opens iMessage with a pre-written text you can edit; no messages sent from Locket's own number | Onboarding, before the widget | (b) [L2]. TechCrunch: a standalone invite "would be a more privacy-focused approach" |
| **Instagram** | "Connect contacts" shows contacts who have accounts | People you may know, from synced contacts | Contacts are synced and stored on Meta's servers, re-uploaded periodically; deleting them takes up to 90 days | Settings and Discover People | (b) [I3][I4] |
| **Snapchat** | Contact sync matches your address book | Quick Add, now renamed **Find Friends** | Yes | Add Friends screen, chat screen | (b) [S2]. **Teens are only suggested to people with numerous mutual friends or who already have them in an uploaded contact book**; requests between teens and strangers with no mutual friends are delayed and investigated [S2][S3] |
| **Retro** | Close-friends photo journal; friend list private | No public data found | Invites; "keys" give a close friend more history | | (b) [R6]. Onboarding contact handling not found in sources |
| **Partiful** | None needed | None | **The invite is a link that works with no app and no account** | The host shares the link wherever they already talk | (b) [P1][P2]. Credited as the growth loop (a weak, from analyst write-ups) |
| **Gas** (2022) | Contacts plus your school | Classmates | Reported: a one-hour lockout unless you invite | Onboarding | (b) [G2][G3]; the lockout claim is from one newsletter, unverified. Built for virality, sold to Discord, shut down (c) |
| **Find My** | Apple's own identity system | Recent contacts in the With field | The system contact picker | People tab, Add button | (b) [F1] |
| **iMessage** | Blue or green bubble: the platform knows who has iMessage through Apple's own account system | None | n/a | n/a | (b) [M1]. Only Apple can do this without a phone-number database of its own (c) |

What the evidence says about the questions he asked:

- **"Friends on the app" lists come from apps that own a phone-number
  identity and a server.** Every app above that shows one (BeReal, Locket,
  Instagram, Snapchat, Gas) verifies a phone number at sign-up and matches
  contacts on its own servers (b). Some Wins has neither, on purpose (c).
- **Contact matching has a known safety cost for teens.** Snap had to
  restrict who a teen is suggested to and delay stranger requests (b) [S2][S3].
  Some Wins admits 13 to 15 (c): a phone-number directory would make them
  findable by number.
- **Requiring contacts is now against the guidelines' grain.** 5.1.1(iii):
  "Where possible, use the out-of-process picker or a share sheet rather than
  requesting full access to protected resources like Photos or Contacts."
  5.1.1(iv): do not "force people to consent to unnecessary data access"
  (a) [A1]. Locket's 2022 requirement predates iOS 18's limited access.
- **Path, 2012**: uploaded whole address books to "find friends"; the CEO
  apologised ("the way we had designed our 'Add Friends' feature was
  wrong"), Congress wrote to Apple, and Apple added the per-app Contacts
  permission (b) [H9].
- **Link-first beats install-first for small groups.** Partiful's whole loop
  is that the invitee needs nothing installed (b) [P1][P2]. We cannot do that
  (a crew needs the app) but we can make the install step keep the invitation
  (section 3, App Clip).

### Virality, honestly

- The viral coefficient is invites sent per user times the share of invites
  that convert (a) [K1]. Above 1 is "rarely seen in the real world", and an
  early k above 1 built on loops that expire "is almost always unsustainable"
  (a) [K1][K2].
- The useful number for a small-circle app is the activation threshold, not
  k. Facebook's was "7 friends in 10 days" (b, secondhand) [K3]. For Some Wins
  the equivalent is **a new person in a crew with at least one other person
  within their first few days** (c): a crew of one has no value, and the
  research on Locket, BeReal and Retro all sells "a few close friends", not
  reach (b) [L1][B1].
- **Locket's growth came from TikTok, not from contact matching** (b) [L3];
  the founder says no paid promotion. For Some Wins the matching outside
  channel is the photo strip shared to stories (already built, link-free by
  the Launch Pack rule) and the trailer (c).
- No solid study compares share-sheet links, prefilled SMS and in-app
  invites on conversion (a, absence) [K4]. Measure our own (section 4, item 2).

---

## 3. Technical options for "who of your contacts are on the app"

### What the stack can and cannot do

| Option | Status | Verdict |
|---|---|---|
| **CloudKit user discoverability** (`CKDiscoverAllUserIdentitiesOperation`, `requestApplicationPermission(.userDiscoverability)`) | Obsoleted in iOS 17. Developers on Apple's forums report no replacement that returns another user from a contact (b) [C1][C2] | Gone. This was the only way to match contacts to iCloud users with Apple verifying the identity |
| **Your own phone number in the public DB, hashed** | The app cannot read the phone's number. The person would type it, and with no server there is no SMS check, so **anyone could claim anyone's number** and appear as them (c) | Not safe without verification |
| **Hashed numbers at all** | Phone numbers are a small space; hashed contact discovery is "severely broken": researchers crawled 100% of US numbers on Signal's old scheme and 10% on WhatsApp with modest resources (a) [N1]. Signal said the same in 2014 (b) [N2] | In a CloudKit **public** database every user can read and query the directory, so the full list of Some Wins users by phone number is recoverable (c) |
| **A new record type** (say `Reach`) | Development creates it just in time; **Production (TestFlight and the App Store) rejects an unknown type until the owner presses Deploy Schema Changes in CloudKit Console**, and a deployed type can never be renamed or deleted (b) [C3][C4]. Its security roles would need World read, which is the enumeration above | An owner step in the Console, permanent |
| **iOS 18 limited Contacts access**, `ContactAccessButton`, `contactAccessPicker` | The button grants one contact per tap from an in-app search; the picker changes the shared set in bulk; both need the Contacts permission and a usage string (b) [C5] | Useful only if we then match contacts, which we cannot do safely. Not needed for invites |
| **`CNContactPickerViewController`** | No permission; out-of-process; the app gets only the people picked, once (b) [C5][A1] | Fine, but the share sheet already does the job better here (below) |
| **`MFMessageComposeViewController`** | Prefills recipients and body; the person must press Send; no auto-send (b) [C6] | Its link preview comes from `join.html`'s tags (the logo), not the tower picture `CrewSharing` attaches today. Loses Instagram and Snapchat DMs, which college students use (c) |
| **The share sheet** (today) | Shows the people you message most first, every messaging app, and carries the rich card with the tower (b) [H8] | **Keep it as the one way to send.** The spec's first design was picker plus composer and was replaced for these reasons (spec 2.3, 2026-10-02) |

### Privacy and the label, if contact discovery were built anyway

- **Guideline 5.1.2(iv)**: "Do not use information from Contacts ... to build a
  contact database for your own use" (a) [A1]. A public directory of hashed
  numbers is close to that line.
- **5.1.2(v)**: contacting people from Contacts only "at the explicit
  initiative of that user on an individualized basis; do not include a
  Select All option", and show what the message will say and who it is from
  (a) [A1].
- **The label**: Apple lists "a hashed phone number" under **Contact Info >
  Phone Number** (a) [A2]. Hashing is not an exemption. The label would add
  Phone Number (Linked, App Functionality), and **Contacts** too if contact
  hashes are stored rather than only queried. Today it is Identifiers and
  User Content only (`docs/crews-app-store-privacy.md` section 1).
- **The policy and the promise**: `CrewSharing` says "Contacts never pass
  through the app and nothing is uploaded"; `docs/launch-pack-log.md` turned
  down Contacts as "a permission this app has never asked for". Both would
  change.
- **The voice**: "See who's here" style features read as being watched,
  which `docs/voice.md` and `docs/ten.md` rule 4 forbid (c).

**Conclusion (c):** do not build contact discovery on CloudKit's public
database. Without a verified identity it is spoofable, and with hashes it is
enumerable. If he wants it anyway, the honest minimum is his own server with
SMS verification and private set intersection, which this app has avoided
from the start.

### What gives the same feeling, with no new iCloud fields

1. **The share sheet's people row** already is "who to add", ranked by who
   you actually text (b). Getting people to it faster (section 4, item 1) is
   most of the win.
2. **People you already share a crew with.** The app already holds their
   names and heads, sealed, on your phone. Starting a crew could offer them.
   Delivery is the catch: a new crew's key has to reach them, and the only
   sealed path is an existing crew's chat. For a crew of two that is
   private. For a bigger crew, a line addressed to one person is still
   sealed with a key everyone in that crew holds, so a crewmate with a
   modified app could read it (c). A marked chat line (like `planMarker`)
   needs no new record type; it does need an older-build fallback that reads
   as a plain line with the link.
3. **App Clip that keeps the invitation across install.** An App Clip opened
   from `somewins.xyz/join` can **read** the CloudKit public database (iOS
   16+, read-only) and write to a group container that **the full app
   inherits on install** (b) [C7]. So the clip could show the crew's name and
   faces (opened with the key in the link), offer the app, and the app joins
   on first launch. No clipboard, no paste banner. Costs: a new target, a size
   limit (15 to 50 MB) [C7], and App Clip experiences are set up in App Store
   Connect around a released version (c, check). After launch, not before.

---

## 4. Recommendations, ranked

Copy below follows `docs/voice.md`: Title Case buttons, no exclamation marks,
no long dashes, nothing that counts people or advertises the cap.

### Cheap and clearly right (no new iCloud fields)

1. **Invite a Friend, one tap, on the empty Crews tab** (the add-friends
   button). Makes an unnamed crew and opens the share sheet at once; an
   unnamed crew of two is shown by the friend's name, so nothing is lost.
   Name and photo stay in Crew Info. This is `qol-research` M14, already
   written up. *Primary button:* **Invite a Friend**. The compose glyph keeps
   the full New Crew sheet. (c, with [P1] for link-first)
2. **Measure the loop.** Fire `crew_invite_sent` from the share sheet's
   completion with `completed == true`, plus an anonymous bucket of where it
   went (Messages, another app, cancelled). Then joins per invite and invites
   per new person are readable in TelemetryDeck with no names. Without this,
   none of the rest can be judged (a) [K1].
3. **Fix the install gap on the page, today.** `join.html`, after **Get Some
   Wins** is pressed, swaps its note to: "Once it's installed, come back to
   this page and tap Open in Some Wins." The Safari tab keeps the link in its
   address, so returning there works where returning to Messages is a hunt
   (c). Site only, no build.
4. **One line in the app for the same moment.** On the empty Crews tab, for
   someone who has never been in a crew, under the button: "Got a link from a
   friend? Open it again to join." Small, quiet ink. Gone once they have a
   crew. (c)
5. **A crew of one gets one quiet tip, not a button.** When the share sheet
   closes with nothing sent, or the first time you open a crew that is still
   just you: the one `TipCard`, title "Just you so far.", line "A crew starts
   when one friend joins.", action **Invite**, its own close, leaves by
   itself like every tip. Once per crew. This respects his "no Invite
   standing on a crew's screen". (If he answers question 3 below with "end it
   quietly", this item shrinks to the tip-free case.)
6. **Say iOS 26 on the join page**, under the buttons, small: "Crews need
   iOS 26." So a friend on an older phone learns it before installing. (c)
7. **At launch, Get Some Wins points at the App Store**, not TestFlight
   (already on the checklist in spirit). TestFlight needs a second app first
   (c).

### Needs the owner's call

- **A. The add-friends button's details.** Is the empty state's button
  "Invite a Friend" (crew of two) instead of "Start a Crew"? And does a crew
  of one with nothing sent end quietly? (Open since this morning's research,
  question 3.)
- **B. A second chance for solo people.** Today: once after the first win,
  once after a first reaction, never again (his rule, 2026-10-05). The second
  moment is unreachable without a crew. Proposal: replace "first reaction"
  for someone with no crew by **the first day the goal is reached**, same
  tip, same words ("Your win is up. Who else should see it?"), shown after
  the dance. Still two moments, ever.
- **C. Start a crew with people from your crews.** Faces of people you
  already share a crew with, at the top of New Crew; picked ones are sent the
  invitation as a sealed line in the crew you share (private for a pair,
  readable in principle by that crew for a bigger one). No new record type,
  a new chat marker, sync code nobody can run end to end on the simulator,
  so a second reader and two real phones before Friends.
- **D. An App Clip for invitations, after the App Store release.** The only
  clean way to keep an invitation across install. Large: a new target, App
  Store Connect setup, and a review.
- **E. Contact discovery ("your contacts on Some Wins").** Recommended no
  (section 3). If yes, it is his own server with SMS verification, a new
  privacy label (Phone Number, maybe Contacts), a new privacy policy, a
  Contacts permission prompt, an age policy for 13 to 15, and a promise
  change in the app's own comments and docs.

### Avoid

- **Requiring Contacts to continue**, or asking for it in onboarding (5.1.1
  (iii) and (iv) [A1]; Locket's 2022 requirement drew press criticism [L2]).
- **Invite gates or lockouts** (the Gas pattern [G3]) and anything that makes
  using the app depend on inviting.
- **Bulk or Select All invites** (5.1.2(v) [A1]).
- **Reading the clipboard on first launch** to carry an invitation across
  install (already turned down: the paste banner reads as watching,
  `crew-plus-design.md` part 4).
- **Counts of people**: "3 friends are here", invites-sent tallies, join
  leaderboards, and anything that names the eight-person cap.
- **Notifications that ask for invites** or mention an empty crew
  (`docs/voice.md`: never notify about an absence).
- **Swapping the share sheet for a contact picker plus composer.** It loses
  the tower card and the non-Messages apps students use (section 3).

---

## Sources

Apple
- [A1] App Review Guidelines 5.1.1 and 5.1.2: https://developer.apple.com/app-store/review/guidelines/
- [A2] App privacy details (Contacts, hashed Phone Number, "collect", on-device): https://developer.apple.com/app-store/app-privacy-details/
- [C1] `CKDiscoverAllUserIdentitiesOperation` (iOS 10 to 17): https://developer.apple.com/documentation/cloudkit/ckdiscoveralluseridentitiesoperation
- [C2] Forums, replacing `.userDiscoverability`: https://developer.apple.com/forums/thread/811731
- [C3] Meet CloudKit Console (WWDC21), deploying schema: https://developer.apple.com/videos/play/wwdc2021/10117/
- [C4] `CKRecord` (production rejects unknown types): https://developer.apple.com/documentation/cloudkit/ckrecord ; forums: https://developer.apple.com/forums/thread/748719
- [C5] Meet the Contact Access Button (WWDC24): https://developer.apple.com/videos/play/wwdc2024/10121/
- [C6] `canSendText()` and MessageUI: https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/cansendtext() ; no auto-send: https://developer.apple.com/forums/thread/102839
- [C7] What's new in App Clips (WWDC22, CloudKit read, shared container): https://developer.apple.com/videos/play/wwdc2022/10097/ ; size limits (WWDC23): https://developer.apple.com/videos/play/wwdc2023/10178/
- [H8] HIG, Activity views: https://developer.apple.com/design/human-interface-guidelines/activity-views
- [F1] Find My, share your location: https://support.apple.com/guide/iphone/share-your-location-iph01954dc44/ios
- [M1] Why are my iPhone messages green: https://support.apple.com/en-us/105087

Apps
- [B1] BeReal, no friend counts: https://sociality.io/blog/what-is-bereal/
- [B2] BeReal help, adding friends and contacts: https://help.bereal.com/hc/articles/7537949847069 (returned 403 to the fetcher; read through search excerpts)
- [B3] BeReal setup, contacts step skippable: https://www.androidauthority.com/what-is-bereal-3201044/
- [L1] Locket App Store page: https://apps.apple.com/us/app/1600525061
- [L2] TechCrunch on Locket onboarding (2022): https://techcrunch.com/2022/01/11/locket-an-app-for-sharing-photos-to-friends-homescreens-hits-the-top-of-the-app-store
- [L3] Locket's TikTok growth: https://techcrunch.com/2022/08/02/locket-app-that-lets-yor-post-photos-to-your-loved-ones-homescreens-raises-12-5m
- [I3] Instagram, connecting contacts: https://help.instagram.com/227486307449481
- [I4] Instagram, disconnecting and deleting synced contacts: https://help.instagram.com/236691729788553
- [S2] Snapchat, What happened to Quick Add (Find Friends, teen limits): https://help.snapchat.com/hc/en-us/articles/34691800487316-What-happened-to-Quick-Add
- [S3] Snap, new safeguards (2023): https://values.snap.com/news/new-safeguards-for-snapchatters-2023 ; TechCrunch (2024): https://techcrunch.com/2024/06/25/snapchat-introduces-new-safety-features-to-limit-strangers-contacting-users/
- [R6] Retro (TechCrunch 2023): https://techcrunch.com/2023/07/07/retro-is-a-deeply-personal-photo-journaling-app-for-close-friends/ ; Engadget: https://engadget.com/2234246/retro-app-what-is-it-how-to-use
- [P1] Partiful: https://en.wikipedia.org/wiki/Partiful
- [P2] Partiful's link-based growth (analyst write-up, weak): https://sacra.com/chat/h/ca6c792b-7d6d-42a9-ae5f-0970a819c66c/
- [G2] Gas, school-by-school: https://thehustle.co/10-18-22-gas-app
- [G3] Gas, invite lockout (single newsletter, unverified): https://mostlybusiness.beehiiv.com/p/how-gas-went-viral-with-1-million
- [H9] Path's address book upload and Apple's response (2012): https://mjtsai.com/blog/2012/02/08/path-uploads-your-entire-iphone-address-book-to-its-servers/ ; https://www.computerworld.com/article/2501626/apple-to-ban-stealthy-iphone-contact-data-harvesting.html

Research and growth
- [N1] Hagen et al., "All the Numbers are US", NDSS 2021: https://eprint.iacr.org/2020/1119
- [N2] Signal, The Difficulty of Private Contact Discovery (2014): https://signal.org/blog/contact-discovery/
- [K1] Andrew Chen on viral coefficient and retention: https://andrewchen.com/retention-is-king/
- [K2] Andrew Chen on viral loops (summary of a talk): https://speedrun.substack.com/p/the-lost-art-of-designing-viral-loops
- [K3] "7 friends in 10 days" (secondhand account of the 2013 talk): https://www.news.aakashg.com/p/ultimate-guide-activation
- [K4] No head-to-head study of invite channels found; nearest: Köster, Matt and Hess, HICSS 2017: https://boris.unibe.ch/105389

In the repo: `Strata/Views/Crews/CrewsListView.swift`, `CrewSharing.swift`,
`CrewCode.swift`, `CrewInfoSheet.swift`, `FirstWinInviteCard.swift`,
`Strata/Social/FirstWinInvite.swift`, `StrataAppDelegate.swift`
(`CrewRouter`), `PublicCrewCloud.swift`, `docs/join.html`,
`docs/crew-plus-design.md` part 4, `docs/launch-pack-log.md` part 5,
`docs/qol-research-2026-10-13.md` section 1, the crews spec 2.3.
