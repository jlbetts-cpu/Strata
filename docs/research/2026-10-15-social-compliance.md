# Social features: compliance audit, 2026-10-15

**This is research, not legal advice.** Written by an AI assistant reading this
repo (build 144, `92f64ba`) and public sources. It does not repeat
`docs/privacy-law-review-2026-10-14.md` or `docs/crews-app-store-privacy.md`;
it looks for what those two missed, what has changed since (the policy and
terms rewrite in `6627a3a`, the crew widget in `1505176`), and which of their
items are still open in the repo today. Where a point is already in the prior
review it is named "still open" and not argued again.

Tags: **(a)** primary legal or Apple text, read this pass at the URL given;
**(b)** a secondary source (forum post, law-firm or press summary), or a fact
read in this repo's code (with file:line); **(c)** inference. **[R]** marks a
point from memory not re-verified this pass.

Scope note: the owner's brief says "available worldwide likely". The launch
checklist still says **United States, Canada, Australia, New Zealand**
(`tasks/launch-checklist.md:130-132`). Those two plans carry very different
legal loads, and section 1 is about that choice.

---

## 0. Ranked gaps (launch risk, highest first)

| # | Gap | Kind of risk | Minimal fix |
|---|---|---|---|
| 1 | "Worldwide" would pull in the EU DSA, GDPR, UK Online Safety Act, Brazil's ECA Digital and Australia's under-16 law; none is prepared for | Legal, several regulators | Ship 1.0 to US, CA, NZ (AU only with crews 16+ there). Revisit per region |
| 2 | CSAM path not ready: no NCMEC registration, no runbook, and the `Report` schema still lets a reporter **edit or delete** their own report | Legal (18 U.S.C. 2258A) | Register; one-page runbook; drop `_creator` READ/WRITE on `Report` in Production |
| 3 | Block never reaches the developer; a non-owner's block leaves the abuser still seeing the victim; a chat line cannot be hidden | App Review 1.2 rejection | Block also files a Report; offer "Block and Leave"; add Hide on a chat line |
| 4 | Word filter covers chat and reply lines only, not win titles, first names or crew names (crew names now also reach home screens) | App Review 1.2 | Run `CrewWords.isAcceptable` on those three, on send and on read |
| 5 | Age rating: the social-media questions (required since September 2026) are not in the checklist; App Privacy "not linked" line still contradicts the manifest | Submission accuracy, DPLA 7.9 | Answer "social media capabilities: yes, off under 13"; fix checklist line 124 |
| 6 | Texas SB 2420: if crews or the widget arrive in an update after 1.0, that update is a likely "significant change" with no PermissionKit flow | Legal (Texas, in force) | Ship crews and the widget **in 1.0**, or add the PermissionKit request before turning them on |
| 7 | App Review cannot reach an invite-only crew without a second person | App Review 2.1 / 1.2 | Put a live invite link to a seeded crew, with a second member, in Review Notes |
| 8 | Crew rules and Terms never say "zero tolerance" or name abusive people, and the rules sheet does not link the Terms | App Review 1.2 template | Two words on the sheet, one line in the Terms, a Terms link |
| 9 | Reset All Data withdraws posts but leaves you a member of every crew (name and head stay) | 5.1.1(v) reading, GDPR Art. 17, policy accuracy | Reset also leaves every crew and ends the ones you started |
| 10 | Crew widget: policy silent; shows on a locked phone in StandBy; can lag a ban or removal until the app runs | Privacy expectation, low | One policy sentence; `.privacySensitive()` on names and faces |
| 11 | No "involves a child" report reason, so a CSAM report cannot be triaged first | Operational, feeds #2 | Add one `Reason` case |
| 12 | "Declined" is treated as 13 to 15 and opens crews, which may include a child account whose parent did not share | Unclear, COPPA-adjacent | LAWYER; meanwhile prefer `requiredRegulatoryFeatures` where available |
| 13 | Photos go unfiltered for an adult who has Sensitive Content Warning off | App Review 1.2, low | Say it plainly in Review Notes; no code change required |

Detail, evidence and citations for each follow.

---

## 1. Where it is sold: the worldwide question

**Requirement.**
- **EU Digital Services Act** (Regulation 2022/2065). Crews store information
  supplied by users at their request (sealed `CrewItem` records in the app's
  CloudKit public database), which makes Some Wins a **hosting service**. It is
  probably **not an "online platform"**, because recital 14 treats content shared
  in closed groups with a finite number of people as not "disseminated to the
  public" [R]. The micro and small enterprise exemption in Art. 19(1) removes
  only **Section 3** (the online-platform duties, Arts. 20 to 28): "This Section,
  with the exception of Article 24(3) thereof, shall not apply to providers of
  online platforms that qualify as micro or small enterprises" (a, via
  https://www.springlex.eu/en/packages/dsa/dsa-regulation/article-19/). Sections 1
  and 2 still apply to every hosting provider regardless of size: Art. 11 and 12
  points of contact, **Art. 13 an EU legal representative for a provider with no
  EU establishment**, Art. 14 terms that describe moderation, **Art. 16
  notice-and-action**, **Art. 17 a statement of reasons to the person whose
  content or account is restricted** (a ban today is silent), and Art. 18
  notifying authorities of suspected serious crime (b, summary at
  https://prighter.com/resources/laws/dsa/articles/article-13 ; c on the
  classification).
- **EU trader status**: Apple asks every developer distributing in the EU to
  declare trader status; a trader's address and phone are shown on the EU
  product page [R]. Tips and Plus make Jayden plausibly a trader (c). This is the
  reason the checklist left the EU out (`tasks/launch-checklist.md:130-132`).
- **GDPR**: covered in the prior review section 5 (Art. 27 representative,
  lawful basis per purpose, ePrivacy consent for the default-on analytics id).
  Not repeated.
- **UK Online Safety Act 2023**: a user-to-user service with UK users must keep
  written illegal-content and children's risk assessments, whatever its size [R].
- **Brazil, ECA Digital (Lei 15.211/2025)**: enforceable since 17 March 2026;
  reaches any IT service "likely to be accessed" by minors, with age assurance and
  parental supervision duties for under-16s on social services (b,
  https://www.gov.br/anpd/pt-br/assuntos/eca-digital/eca-digital-english and
  https://withpersona.com/blog/brazil-digital-eca-age-assurance-regulation).
- **Australia**: still open from the prior review (section 2.6).

**Status: gap, if worldwide.** Nothing in the code is region-aware: no
storefront or region check exists in `Strata/Social` (grep for `storefront`,
`Locale.current.region`, `Australia`: no hits) (b).

**Minimal fix.** Keep 1.0 to the United States, Canada and New Zealand, plus
Australia only once crews are 16+ there. Each added region later is its own
checklist: EU (DSA representative, notice form, statement of reasons on a ban,
trader address, analytics opt-in), UK (two written assessments), Brazil (16+
crews or parental supervision). "Worldwide" for a solo developer with a chat
feature is the single biggest legal multiplier in this audit (c).

---

## 2. CSAM reporting and the report record

**Requirement.** 18 U.S.C. 2258A: a provider with actual knowledge of apparent
CSAM reports it to NCMEC's CyberTipline and preserves the report's contents for
one year (REPORT Act, 2024) (a, per the prior review's reading of
https://www.law.cornell.edu/uscode/text/18/2258A). The Apple Developer Program
License Agreement 3.2 bars using Apple services "to create or distribute any
content or activity that promotes child sexual exploitation or abuse" (a,
https://developer.apple.com/support/terms/apple-developer-program-license-agreement/).

**Status: gap, still open from the prior review, plus one new angle.**
- NCMEC registration is unticked (`tasks/launch-checklist.md:160`) and no runbook
  exists (no `docs/*runbook*`, no `.md` in `tools/cloudkit/`) (b).
- **New:** `Report` still grants `READ, WRITE TO "_creator"`
  (`tools/cloudkit/full-schema.ckdb:135`). Write includes delete. A reporter who
  sent apparent CSAM "as a report", or anyone who reports and then regrets it,
  can **delete the very record the law asks the provider to preserve** (c). It also
  contradicts the policy's "A report goes only to Some Wins"
  (`Strata/Views/PrivacyPolicyText.swift:61`) and the code comment that says the
  writer "may create it and nothing more" (`Strata/Social/CrewSafety.swift:43-44`).
- **New:** the developer cannot remove a single sealed item. `CrewItem` grants
  write only to `_creator` and the Moderator role has no grant on it
  (`full-schema.ckdb:203-205`) (b). Removal is therefore always a **ban**, which
  reaches each phone when it next refreshes bans: at most every 24 hours in the
  background, every 5 minutes when Crews opens (`PublicCrewCloud.swift:1780-1781`)
  (b). That satisfies 1.2's "remove content" (c), but the runbook must say removal
  equals a ban, and the 48-hour NCII promise in the terms depends on it.

**Minimal fix.** (1) Register with the CyberTipline. (2) In the CloudKit Console,
Production schema: `Report`, untick Read and Write for Creator; keep Create for
Authenticated. Update `full-schema.ckdb:135` to match so a redeploy does not undo
it. (3) A one-page runbook beside `tools/cloudkit/reports.sh`: never download or
screenshot; file from the Console; ban with a non-descriptive reason; keep the
Report for a year; then delete. **LAWYER** for the preservation step.

**Never do this (a, DPLA 3.3.3(N)):** "You may not transmit off the user's device
any information about whether an image or video has been identified by the
Sensitive Content Analysis Framework". So a future "auto-report photos the check
flags" would breach the licence. Today nothing does: a held-back photo is simply
not sent (`SocialStore.swift:2919-2927`) and verdicts stay in local
`UserDefaults` (`SocialStore.swift:286-290`); reports carry no verdict
(`CrewSafety.swift:56-96`). **Met** (b).

---

## 3. Guideline 1.2: report, block, filter, contact

**Requirement (a, current text,
https://developer.apple.com/app-store/review/guidelines/):** apps with
user-generated content "must include: A method for filtering objectionable
material from being posted to the app; A mechanism to report offensive content
and timely responses to concerns; The ability to block abusive users from the
service; Published contact information so users can easily reach you." The June
2026 revision added: "It is your responsibility to remove content that violates
this guideline, your terms of service, or your community standards" (a; change
log at https://developer.apple.com/news/?id=a233fmpw).

How reviewers apply it, as quoted in a November 2025 rejection (b,
https://developer.apple.com/forums/thread/807358): users must "agree to terms
(EULA) and these terms must make it clear that there is no tolerance for
objectionable content or abusive users"; "A mechanism for users to immediately
remove posts from the feed"; "The developer must act on objectionable content
reports within 24 hours by removing the content and ejecting the user".

### 3.1 Block (gap)

- `CrewSafety.block` hides the person locally and, only if you started the crew,
  removes them (`CrewSafety.swift:193-201`). **It sends nothing to Some Wins** (b).
  Reviewers often expect a block of abusive content to reach the developer (b,
  rejection templates vary; c on how likely).
- For a **non-owner**, the blocked person stays in the crew and keeps seeing the
  blocker's wins and chat lines; the dialog says only "You won't see their wins in
  any crew" (`CrewInfoSheet.swift:464-465`, `CrewChatSheet.swift:1500-1502`) (b).
  For a 13 to 15 year old being harassed, the only escape is Leave (c).
- Blocks key on the random profile id (`SocialStore.swift:454-456`); someone who
  resets the app gets a new id and is unblocked (c). The account-level Ban covers
  that once reported.

**Minimal fix.** On Block, also file a `Report` (reason `harassment` or a new
`blocked`) so the developer hears of it; for a non-owner, make the confirmation
"Block" and "Block and Leave". Copy stays as is otherwise.

### 3.2 Remove from my view (gap, small)

A win can be hidden (`SocialStore.hide(winID:)`, `:392`); a **chat line cannot**
(no hide action in `Strata/Views/Crews/CrewChatSheet.swift`; only report and
block) (b). Reporting a line does not hide it either
(`CrewChatSheet.swift:1464-1474`). **Fix:** Hide on a chat line, and hide a
reported item for the reporter at the moment of reporting.

### 3.3 Filter (gap)

- Text: `CrewWords.isAcceptable` runs on chat lines and reply lines only
  (`SocialStore.swift:1192,1212`, `CrewRecords.swift:178,226`) (b). **Win titles,
  first names and crew names are never checked**; `rename` saves whatever is typed
  (`SocialStore.swift:773-785`) (b). The prior review marked the filter "meets
  it"; it does for chat, not for these three. A reviewer who names a test crew
  with a slur sees it shown (c).
- **Widget change:** the crew name is now also drawn on the home screen and listed
  in the widget's crew picker (`CrewWidgetPublisher.swift:104`,
  `StrataWidget/CrewWidget.swift:38-41`) (b), so an unfiltered crew name leaves
  the app.
- Photos: Apple's Sensitive Content Analysis on send and receive, entitlement
  present (`Strata/Strata.entitlements`, `CrewSafety.swift:145-189`) (b). When the
  person has the analysis off, outgoing photos go unchecked (`:177`) and adults see
  incoming photos unchecked (`:146-147`, `CrewAge.swift:77`) (b). Apple exposes no
  other first-party nudity check, and the framework only runs when the user or a
  parent has turned it on (a, entitlement doc
  https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.sensitivecontentanalysis.client
  ; c on review tolerance). **Met with a caveat**; say it in Review Notes.

**Minimal fix.** Apply `CrewWords.isAcceptable` to `title`, `firstName` and crew
`name` on send (refuse with the existing words) and on decode (drop or blank).

### 3.4 Report (met, one improvement)

Win, message, person, crew and legacy reply are reportable, queued offline
(`CrewSafety.swift:29-113`) (b). Reasons are inappropriate, harassment, spam,
other (`:12-23`). **Improvement:** add "It involves a child" so the reports that
carry a legal clock (section 2) can be found first in `reports.sh`. The 24-hour
promise is a personal duty; see the prior review.

### 3.5 Terms agreed before sharing (gap, small)

The rules sheet says "Nothing hateful, sexual, violent or cruel. Ever." and
"whatever or whoever broke these rules is removed" (`CrewRules.swift:35-40`) (b).
The Terms say "Breaking these can get you removed from a crew"
(`docs/terms.html`, Crew rules) (b). Neither says **zero tolerance** or names
**abusive users**, the two things the rejection template asks for (b), and the
sheet does not link the Terms (no `terms` reference in `CrewRules.swift`) (b).
**Fix:** "Nothing hurtful" detail becomes "Zero tolerance for anything hateful,
sexual, violent or cruel, or for anyone who abuses others."; add a Terms link
under I Agree; mirror one sentence in the Terms.

### 3.6 Contact (met)

Settings, Send Feedback (`Strata/Views/FeedbackAndReview.swift:24-31`), the policy
and the terms carry the address (b). Support URL still to set
(`tasks/launch-checklist.md:120`).

---

## 4. Guideline 1.2.1 (creator content)

**Requirement (a):** creator apps "must provide a way for users to identify
content that exceeds the app's age rating, and use an age restriction mechanism
based on verified or declared age". **Status: not applicable** (c). Crews are
private friend groups, not a creator community with monetised experiences.
Nothing to do.

---

## 5. Guideline 5.1.1 and account deletion

**Requirement (a):** 5.1.1(v): "If your app supports account creation, you must
also offer account deletion within the app."

**Status: unclear, probably not applicable, but there is a real hole.** There is
no sign-up; identity is the iCloud account plus a random profile id (c). Joining a
crew does, however, write a **Member** record (first name, head) to the
developer's public database that persists. Reset All Data calls
`withdrawEverything` (`MainAppView.swift:2736`), which removes wins, reactions and
lines and then re-shares your member record (`SocialStore.swift:902-921`), so
**you stay a member of every crew with your name** (b). The policy tells people to
leave first (`PrivacyPolicyText.swift:70`) (b). If App Review reads crew
membership as an account, there is no one-tap way to delete it (c); under GDPR
Art. 17, if the EU is ever added, the same (c).

**Minimal fix.** Reset All Data also leaves every crew and ends the ones the
person started (the same calls Crew Info uses, `CrewInfoSheet.swift:568-577`).
Then the policy line simplifies.

5.1.1(i) to (iv) and the label: still open from the prior review only where noted
in section 7 below.

---

## 6. Guideline 5.1.2 and the Apple frameworks' own terms

- 5.1.2(i) (a): "You must clearly disclose where personal data will be shared with
  third parties ... and obtain explicit permission". TelemetryDeck is disclosed
  (`PrivacyPolicyText.swift:20`) and opt-out exists (b). **Met** for US/CA/NZ (c);
  EU would need opt-in (prior review).
- DPLA 3.3.3(O) Declared Age Range (a): use "only for the purposes of providing
  age-appropriate content and/or features ... or to comply with laws"; no sharing
  with data brokers. The answer stays on the phone (`CrewAge.swift:32-45`) (b).
  **Met.**
- DPLA 3.3.3(N) Sensitive Content Analysis: **met**, see section 2.

---

## 7. Age rating, Declared Age Range, Texas and Utah

### 7.1 Apple's rating system

**Requirement (a).** Since July 2025 the tiers are 4+, 9+, 13+, 16+, 18+; new
required questions on in-app controls, capabilities and more; answers were
required from 31 January 2026 (b, https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/).
From **September 2026**, the questionnaire's **social media capability**
questions are required for new apps and updates: a social media capability is
"the ability to redistribute, amplify, or interact with user-generated content
through a social feed or similar discovery method"; such apps show a Social Media
descriptor, and "If you indicate that your app or game includes social media
capabilities but they are disabled for anyone under 13, it won't be included in
the Time Allowance category for Social Media for users under 13" (a,
https://developer.apple.com/news/?id=tlur8uvi). DPLA 7.9 makes accurate answers a
contract term: "You agree to provide accurate and complete information about Your
Application as requested in App Store Connect" (a).

**Status: gap (checklist).** `tasks/launch-checklist.md:122-123` lists only UGC
and messaging and "Expect 13+" (b). A crew's day tower is a feed of friends' posts
you react to (c), so the honest answer is **Yes, social media capabilities, and
disabled under 13** (crews never open under 13, `CrewGate.swift:32`) (b).

**Also still open:** `tasks/launch-checklist.md:124-125` says every App Privacy
row is "not linked"; the manifest declares report rows **linked**
(`Strata/PrivacyInfo.xcprivacy:108-170`) (b). The manifest is right (prior review
6.5).

**Minimal fix.** Update the checklist's rating and privacy lines; answer as above;
accept whatever rating Apple calculates (16+ would also be fine for a college
audience, c).

### 7.2 Texas SB 2420 (in force) and the 2027 states

**Requirement (a, https://developer.apple.com/news/?id=sg176nne, 3 June 2026):**
new Texas accounts from 4 June 2026 need parent consent for under-18 downloads,
purchases "and significant changes associated with an app"; developers use the
Declared Age Range API, "the Significant Change API under PermissionKit", the
StoreKit age rating property, and a server notification for withdrawn consent;
"it's the developer's responsibility to determine when there's a significant
change". Apple's Q&A adds: "When a parent or guardian revokes consent for their
child to access an app, Apple will prevent the app from launching", and until a
parent consents to a significant update "the child must be prevented from
accessing the significant update" (a, https://developer.apple.com/support/age-assurance).
Utah 6 May 2027, Louisiana 1 July 2027, Alabama and California AB 1043 1 January
2027: see the prior review's table.

**Status.**
- Revocation: **met by the system** for a server-less app, since Apple blocks
  launch (a). The `RESCIND_CONSENT` server notification cannot be received
  without a server, and forum reports say its payload cannot identify an
  accountless user anyway (b, https://developer.apple.com/forums/thread/845068).
- Age asked only at Crews, with gates 13 and 16, no `isEligibleForAgeFeatures`
  or `requiredRegulatoryFeatures`, no PermissionKit (`CrewsListView.swift:854-875`;
  grep finds no `PermissionKit`) (b). **Still open** from the prior review.
- **New angle:** crews are on only in TestFlight today
  (`tasks/launch-checklist.md:150-153`) and the widget landed in build 144. If
  either reaches the App Store **after** 1.0, that update is a plausible
  "significant change" for a Texas minor (c). If both are in 1.0, the parent's
  consent at download covers them (c).

**Minimal fix.** Ship crews and the crew widget in 1.0. Before any later update
that adds a social surface (Friends, photo features for 13 to 15), add the
PermissionKit significant-change request for Texas minors. **LAWYER** for what
counts as significant.

### 7.3 Declined answers (unclear)

`declinedSharing` and errors become `.declined`, treated as 13 to 15, which
**opens crews** (`CrewAge.swift:28,68-70`, `CrewsListView.swift:863-871`) (b).
For a Child Account (under 13) the parent controls sharing (a, Apple newsroom
June 2025: developers "can request the age range associated with a Child
Account"), so a child whose parent never enabled sharing reads as declined and
gets text-only crews (c). Not COPPA "actual knowledge" (c), but it is the one path
by which an under-13 reaches crews. Separately, on TestFlight an error counts as
**adult** (`CrewsListView.swift:872`), which only matters if minors are invited as
testers (c).

**Minimal fix.** LAWYER on whether that is acceptable; the engineering option is
to read `requiredRegulatoryFeatures` (iOS 26.4) where present, and in a region
where sharing is required, treat a decline as not yet answered rather than as a
teen (b, https://developer.apple.com/support/age-assurance lists the property).

---

## 8. COPPA (amended 2025)

**Requirement (a,
https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule):**
effective 23 June 2025, compliance by 22 April 2026; biometric identifiers become
personal information; written retention policy; notice must name the internal
operations a persistent identifier supports.

**Status: met** for what the code knows. Under 13, crews do not open
(`CrewGate.swift:32`) and analytics stop with the install id forgotten
(`CrewAge.swift:40-44`) (b); the policy says so (`PrivacyPolicyText.swift:77`) (b).
Two edges: a child who never opens Crews is never asked, so analytics continue
(not actual knowledge, c); and section 7.3's declined path. Nothing else to do
for a 13+ general-audience app (c).

---

## 9. CCPA/CPRA and California

**Status: not applicable** (CCPA thresholds; prior review section 4). The
California minors' removal paragraph now exists (`PrivacyPolicyText.swift:79-81`)
(b). **Met.**

---

## 10. GDPR basics for a no-server app

Only relevant if section 1 goes worldwide. Beyond the prior review's list: the
developer holds **ciphertext plus metadata** (crew id, record kind, writer's
app-scoped iCloud id, times; `PrivacyPolicyText.swift:45`) (b). Encrypted data
the controller cannot decrypt can still be personal data in the hands of a party
that holds identifiers next to it (c, LAWYER); the metadata is personal data
outright (c). So "no server" does not mean "no GDPR"; it means a short policy with
lawful bases, retention for crew metadata, Apple named as processor and US
transfer basis, and section 5's erasure fix (c).

---

## 11. Guideline 4.2 (minimum functionality)

**Requirement (a):** "If your App doesn't provide some sort of lasting
entertainment value or adequate utility, it may not be accepted." **Status: met**
(c): the app is a full logging app; crews are optional. The live risk at review
is not 4.2 but **reachability**: a reviewer cannot test report, block or chat in
an invite-only crew without one. `docs/crews-app-store-privacy.md` section 3 says
"if Review asks". **Fix:** put a live invite link to a seeded crew, with a second
test member who has posted a win, a photo and a chat line, in Review Notes from
the first submission (c).

---

## 12. Apple Communication Safety and Sensitive Content Analysis

**Requirement.** No Apple text found that **requires** an app with user images to
adopt the framework (b, search this pass; the guidelines text does not mention it,
a). Apple does turn similar protections on by default for 13 to 17 ("kids ages 13
to 17 will have similar age-appropriate protections enabled from the beginning",
a, https://www.apple.com/newsroom/2025/06/apple-expands-tools-to-help-parents-protect-kids-and-teens-online/),
so for teens the analysis policy is usually on and the check runs (c). The
licence condition on using it is in section 2.

**Status: met, beyond what is required.** 13 to 15 never send photos or heads
(`CrewAge.swift:73`); with the check off they see no friends' photos
(`CrewAge.swift:77`, `CrewSafety.swift:145-148`); adults' outgoing photos are
checked when the analysis is on (`:175-188`) (b).

---

## 13. What the crew widget changes

Files: `Shared/CrewWidgetSnapshot.swift`, `Strata/Social/CrewWidgetPublisher.swift`,
`StrataWidget/CrewWidget.swift`, `Shared/CrewWidgetView.swift`.

**Good, by design (b):**
- No titles and no photographs, only colours, sizes, first names and faces
  (`CrewWidgetSnapshot.swift:12-15`).
- Built from `SocialStore.wins(in:on:)` and `visible`, so blocked people and hidden
  wins never reach it (`CrewWidgetPublisher.swift:88-92`,
  `SocialStore.swift:381-385,438-442`).
- Friends' faces go through `CrewHeads`, which holds the photo check
  (`PersonHead.swift:29-35`); a face kept while unpacking is kept only if
  `photoIsShown` (`CrewWidgetPublisher.swift:119-121`).
- Minors' faces: 13 to 15 never send a head (`CrewAge.swift:71-73`), so no
  under-16 face appears on anyone else's home screen; a teen sees only their own.
- Crews off on the phone: file and faces are deleted (`CrewWidgetPublisher.swift:32,40-46`).
- No required-reason API in the widget target (grep of `StrataWidget`, `Shared`
  for `UserDefaults`, file timestamps, uptime: none), so no manifest needed there
  (b).

**Gaps (all low):**
1. **The policy does not mention it** (`PrivacyPolicyText.swift`, no "widget") (b).
   A crew member's first name and head now appear on friends' Home Screens, where
   "anyone holding the phone" can see them, the widget's own reasoning
   (`CrewWidgetSnapshot.swift:15`). **Fix:** under "What a crew sees": "If someone
   in your crew adds the Crew widget, your first name, your head and how many wins
   you logged today show on their Home Screen."
2. **Shown on a locked phone.** `.systemSmall` is eligible for StandBy, which
   shows widgets while the phone is locked and charging, and iPhone widgets can
   also appear on a paired Mac's desktop [R]. Nothing is marked
   `.privacySensitive()` (`Shared/CrewWidgetView.swift`, `StrataWidget/CrewWidget.swift:22`)
   (b). **Fix:** `.privacySensitive()` on names and faces, so iOS redacts them
   when locked; no visual change unlocked.
3. **Lag after a ban, removal or block on another device.** The file is rewritten
   only while the app runs (`CrewWidgetPublisher.swift:28-36`,
   `StrataApp.swift:266`) (b). A banned person's face can stay on a home screen
   until the app next opens (c). Acceptable; mention in the runbook that removal
   reaches widgets when the app next runs.
4. **Unfiltered crew name** on the home screen and in the configuration picker:
   section 3.3.
5. Faces are written into the App Group container, which is part of the device's
   iCloud Backup [R]. Friends' heads already live on the phone for the tower, so
   this adds little (c).

---

## 14. Still open from the prior reviews (unchanged in the repo)

Listed so nothing is lost, not argued again: Australia decision (prior 2.6);
Texas engineering (prior 2.3); `Ban.reason` world-readable and `ban.sh` writes a
free reason (`full-schema.ckdb:13-15`, `tools/cloudkit/ban.sh:19`); export
compliance read (prior 6.7); BIPA/MHMDA head notice screen (prior 3.4); a lawyer's
read of the terms.

Closed since the prior review (b): policy rewritten for sealed public crews,
heads, library access, reports, invite links, California minors, change notices
(`PrivacyPolicyText.swift:37-86`); Terms rewritten (`docs/terms.html`, 14 October
2026); notification extension manifest added
(`SomeWinsNotifications/PrivacyInfo.xcprivacy`); under-13 analytics stop
(`CrewAge.swift:40-44`); crew picture gated by age and check
(`SocialStore.swift:788-795`); SCA entitlement present (`Strata/Strata.entitlements`).

---

## Sources read this pass

- App Review Guidelines (1.2, 1.2.1, 4.2, 5.1.1(v), 5.1.2(i)): https://developer.apple.com/app-store/review/guidelines/
- Guidelines and DPLA change log, 8 June 2026: https://developer.apple.com/news/?id=a233fmpw
- Apple Developer Program License Agreement (1.2 definitions, 3.2, 3.3.3(N), 3.3.3(O), 7.9): https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- Age rating social media questions, 9 July 2026: https://developer.apple.com/news/?id=tlur8uvi
- Texas update, 3 June 2026: https://developer.apple.com/news/?id=sg176nne
- Age assurance Q&A: https://developer.apple.com/support/age-assurance
- Apple newsroom, June 2025: https://www.apple.com/newsroom/2025/06/apple-expands-tools-to-help-parents-protect-kids-and-teens-online/
- 1.2 rejection text as posted (b): https://developer.apple.com/forums/thread/807358
- Server-less consent revocation thread (b): https://developer.apple.com/forums/thread/845068
- 2025 rating tiers (b): https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/
- DSA Art. 19 (a, via consolidated text): https://www.springlex.eu/en/packages/dsa/dsa-regulation/article-19/ ; Art. 13 summary (b): https://prighter.com/resources/laws/dsa/articles/article-13
- Brazil ECA Digital (a/b): https://www.gov.br/anpd/pt-br/assuntos/eca-digital/eca-digital-english ; https://withpersona.com/blog/brazil-digital-eca-age-assurance-regulation
- COPPA final rule: https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule
