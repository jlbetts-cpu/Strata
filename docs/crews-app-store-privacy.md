# Crews: App Store privacy, age rating and CloudKit, for the owner

Everything here is a manual step in App Store Connect or the CloudKit Console.
None of it can be done from the repo. Do it in the same release that turns
`CrewsFlag` on, not before and not after: the label, the policy and the app
have to agree on the day people can use Crews.

Sources in the repo: `Strata/PrivacyInfo.xcprivacy` (the reasoning, in its
comments), `Strata/Views/PrivacyPolicyView.swift` and `docs/privacy.html` (what
users are told), spec `docs/superpowers/specs/2026-10-02-crews-design.md`
section 9, research `docs/research/concept-and-social.md` 4.3 to 4.5.

---

## 0. Blockers found in this pass (fix before the flag goes on)

- [ ] **The photo check cannot run yet.** `CrewSafety.photoIsFine` uses
  `SCSensitivityAnalyzer`, which needs the entitlement
  `com.apple.developer.sensitivecontentanalysis.client` (value: `analysis`).
  Neither `Strata/Strata.entitlements` nor `Strata/StrataDebug.entitlements`
  has it, so `analysisPolicy` is always `.disabled` and every photo goes
  unchecked. The policy promises the check "when Sensitive Content Warning or
  Communication Safety is turned on"; that is only true once the entitlement
  is in both files and the provisioning profile.
- [ ] **The crew picture skips the age rule and the photo check.**
  `SocialStore.setPhoto` sends a crew picture without asking `photosAllowed()`
  or `photoCheck`. The policy says that from 13 to 15 photos are never sent,
  and a 13 to 15 year old can currently set a crew picture. Gate it the way
  `checkedPhoto(for:)` gates a win's photo.
- [ ] **CLAUDE.md is out of date.** "What the app CLAIMS about itself must be
  true" says `NSPrivacyCollectedDataTypes` must stay empty until a server
  exists. Reports are now collected (section 1), so that line needs your edit.
- [ ] **A notification extension, if one is added** (spec section 5), needs
  its own `PrivacyInfo.xcprivacy` declaring UserDefaults reason `1C8F.1`,
  because it reads the app group's Hide Alerts list.
- [ ] **Check the BUILT Info.plist in Debug and Release** (CLAUDE.md rule):
  `CKSharingSupported` and the `remote-notification` background mode present,
  no permission string for anything Crews does not use. The contact picker
  needs no Contacts permission and must not get a usage string.

## 1. App Store Connect: App Privacy

App Store Connect > the app > App Privacy > Data Types > Edit.

The answer changes from **"No, we do not collect data from this app"** to
**"Yes, we collect data from this app"**, because a report reaches the
developer. Declare exactly two types:

- [ ] **Identifiers > User ID**
  - Used for: **App Functionality** only.
  - Linked to the user's identity: **Yes**.
  - Used for tracking: **No**.
  - What it is: the random profile ids of the person reporting and the person
    reported, and CloudKit's own id for the reporting iCloud account, on a
    `Report` record.
- [ ] **User Content > Other User Content**
  - Used for: **App Functionality** only.
  - Linked to the user's identity: **Yes**.
  - Used for tracking: **No**.
  - What it is: the reported win's title and the reason picked from a list.

Leave everything else unticked: Name, Photos or Videos, Contacts, Location,
Contact Info, Health, Usage Data, Diagnostics. The resulting label should read
**Data Linked to You: Identifiers, User Content**, and nothing under Data Used
to Track You.

**Why Name, Photos and the rest of a win are NOT declared.** Apple counts data
as collected when it leaves the device "in a way that allows you and/or your
third-party partners to access it". A crew's wins, names, heads and pictures
sit in the private iCloud database of whoever started the crew and are shared
with its members by Apple's iCloud sharing. You cannot read a user's private
or shared database, there is no Some Wins server to copy it to, and Apple's
iCloud is not a "third-party partner" in Apple's sense (code from a vendor you
added to the app). So they are not collected. The research doc reached the
same reading, marked as inference to confirm. The spec's 9.3 had listed them;
declaring them would tell people Some Wins collects their photos and their name,
which is untrue in the same way the HealthAndFitness label was.

- [ ] **Your call:** if App Review questions it, or you read Apple's page
  differently, the conservative alternative is to also declare **Contact Info >
  Name**, **User Content > Photos or Videos** and **Other User Content** for
  the crew data, each Linked, not Tracking, App Functionality. If you do, add
  the same entries to `PrivacyInfo.xcprivacy` in the same change; the two must
  agree.

**Do not use the "optional disclosure" exception for reports.** It requires,
among other things, that the person's name or account is shown in the
submission form beside what is sent. The Report confirmation shows neither.

- [ ] **Privacy Policy URL**: publish the updated `docs/privacy.html` (last
  updated 2 October 2026) to the URL App Store Connect lists, and open it on a
  phone to be sure it is the new one.

## 2. App Store Connect: Age Rating

App Store Connect > the app > App Information > Age Rating > Edit. Answer by
these facts; the wording of Apple's questions may differ.

- [ ] **User-Generated Content: Yes.** A crew sees titles and photographs
  other people wrote and took.
- [ ] **Messaging and Chat: No.** There is no chat, no comments, no
  reactions. A crew sees wins, nothing typed to each other.
- [ ] **Unrestricted Web Access: No. Advertising: No.**
- [ ] **Age assurance / in-app controls: Yes.** Declared Age Range is asked
  the first time Crews opens. Under 13, Crews do not open; 13 to 15, photos
  are never sent; declining to answer counts as 13 to 15.
- [ ] **Rating: 13+.** If the calculated rating comes out lower, choose the
  higher rating (13+) as the override. This is your call from 2026-10-02.

## 3. App Review notes (guideline 1.2)

Paste a short version of this into App Review Information > Notes, with a
second test iCloud account if Review asks for one.

- [ ] **Filter:** crews are invite only (up to 8 people, joined only through
  an iCloud invite sent from the app), and every photo is checked on the
  phone with Apple's Sensitive Content Analysis before it is sent; a flagged
  photo is not sent. (Blocked until the entitlement in section 0 is added.)
- [ ] **Report:** on the back of any friend's win. A report goes to the
  developer, never to the crew. Say how quickly you will act on one; Apple
  asks for "timely" and the number is yours to set.
- [ ] **Block:** on any member row in Crew Info. Their wins, head and name
  disappear from every crew on the blocker's phone; they are not told; if the
  blocker started the crew they are also removed.
- [ ] **Contact:** jbett5@hotmail.com, already in the in-app privacy policy
  and Settings > Send Feedback, and on `docs/privacy.html`. Add it to the
  product page's support URL or description too.
- [ ] **Where reports arrive:** nothing emails you. Reports are records in the
  CloudKit Console (section 4). Decide how often you will look.

## 4. CloudKit Console: the `Report` record type

Container `iCloud.JaydenBetts.Strata`. A report is written to the **public**
database by `CrewSafety.report`, and the public database is readable by every
user of the app unless its permissions say otherwise. This step is what makes
"only Some Wins can read it" true.

- [ ] CloudKit Console > Schema > Record Types, **Development**. If `Report`
  does not exist yet, create it with six String fields: `crew`, `winID`,
  `sender`, `reporter`, `reason`, `title`. (Saving one report from a debug
  build in development also creates it.)
- [ ] Schema > Security Roles. For `Report`, on **World**, **Authenticated**
  and **Creator**: tick **Create** only. Untick **Read** and **Write**
  everywhere. World: create only, and nobody but the developer can read a
  report, including the person who made it.
- [ ] Schema > Indexes. Add a **Queryable** index on `recordName` for
  `Report`, and a **Sortable** one on `createdTimestamp`, so you can list
  reports in the Console.
- [ ] **Deploy Schema Changes** to Production, then open the Production
  schema and confirm the `Report` security roles came across as set.
- [ ] Verify from a phone signed in to a second iCloud account: make a
  report, then confirm it appears in the Console's Production public database
  and that the app cannot read it back (a query for `Report` fails with a
  permission error).
