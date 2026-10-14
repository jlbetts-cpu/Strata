# Privacy and legal review, 2026-10-14

**This is research, not legal advice.** It was written by an AI assistant
reading this repo and public sources, to help a solo developer know where to
look. It is not a substitute for a lawyer, it can be wrong about how a court
or regulator would read a rule, and laws in this area changed several times in
2025 and 2026. Every place marked **LAWYER** is a question to put to a real
one before or soon after launch. California has free and low-cost options for
students and small founders (UC Davis School of Law clinics, the California
Lawyers for the Arts and similar referral services, and startup law clinics at
UC Berkeley and Santa Clara).

Scope: build 140 (`d7bb43f`), `~/Developer/Strata`. Launch plan read from
`tasks/launch-checklist.md` section 4: **United States, Canada, Australia, New
Zealand**, rated 13+, crews switched on for the App Store after the two-phone
test.

Tags, as the other research docs use them: **(a)** a law, rule or guideline
read at its source, **(b)** a fact read in this repo's code, **(c)** inference.

---

## 0. The short answer

Nothing found is a "the app is illegal" problem. The app's design (no
account, no server, data on the phone and in the person's own iCloud, crews
sealed end to end, no ads, no tracking, analytics without an SDK) is about as
low-risk as a social feature can be. What is wrong is mostly **the words not
matching the code** after the 2026-10-09 move of crews to the public database,
plus four real legal exposures that need a decision:

1. **The privacy policy describes the crew architecture that was replaced.**
   It says a crew "lives in the iCloud of whoever started it". Since
   2026-10-09 every crew lives in Some Wins' own public CloudKit database,
   sealed (`Strata/Social/PublicCrewCloud.swift:5-26`,
   `NotifyShared/CrewSeal.swift:6-13`). Retention and deletion sentences
   are also untrue now (section 8). A privacy policy that misdescribes
   practices is the classic FTC Act section 5 / CalOPPA deception case.
2. **Australia's under-16 social media law** (in force 10 December 2025) may
   reach crews, which let 13 to 15 year olds in. Decide before launch:
   crews 16+ in Australia, or Australia off the launch list. **LAWYER.**
3. **The head is a face-derived artefact** and the policy says the app keeps
   "never measurements of your face". It keeps eye outlines, eye positions,
   tilt and iris colour per face (`Strata/Models/HeadRig.swift:31-44`,
   `Strata/Models/HeadStore.swift:68-78`, `:801-825`) and sends them to crews
   inside `head.json` (`Strata/Social/CrewHeadPack.swift:23-39`). This is
   very unlikely to be a "biometric identifier" (nothing can recognise a
   person from it), but the sentence is false and there is no consent step
   before the camera finds the face. Fix the sentence and add a one-screen
   notice. Biometric laws with private lawsuits (Illinois BIPA, Washington's
   My Health My Data Act) are why this is worth the hour.
4. **Texas's App Store Accountability Act has been in force since 4 June
   2026.** The app reads the age only when Crews first opens and does not
   use PermissionKit's significant-change flow. Either add that before a
   Texas launch or get a lawyer's yes that a feature-level check is enough.

The ranked list is in section 9.

---

## 1. What the app actually does with data (from the code)

| Data | Where it goes | Who can read it | File |
|---|---|---|---|
| Wins, journal, drawings, strips, name, heads, places | SwiftData on the phone, and the person's own **private** iCloud (SwiftData + CloudKit mirroring) | The person (their Apple Account) | `Strata/Services/SharedModelContainer.swift`, `PhotoSync.swift` |
| Crew content: wins (title, colour, icon, size, photo, times, tagged people), chat lines, doodles, reactions, member first name and head pack, crew name/picture/time zone | App's **public** CloudKit database, one record type `CrewItem`; every field sealed with the crew's AES-256-GCM key; photos and heads in sealed assets | Only phones holding the crew key. Developer sees ciphertext plus metadata: crew id, record kind, creator's app-scoped iCloud user id, timestamps, sizes | `Strata/Social/PublicCrewCloud.swift:5-26`, `NotifyShared/CrewSeal.swift`, `tools/cloudkit/full-schema.ckdb:191-206` |
| Crew key | Inside the invite link after `#`; on the phone (app group); a backup in the person's private iCloud; identity in the Keychain | Anyone holding the link | `Strata/Social/CrewKeys.swift:3-60`, `CrewKeyBackup.swift`, `CrewVault.swift` |
| Pings (notification nudges) | Public DB `Ping` record: SHA-256 tags of crew and profile ids, win id, kind; deleted by sender after about 10 min | Any app install can read; tags are one-way | `NotifyShared/CrewNotes.swift:1-40` |
| Reports | Public DB `Report`: crew id, win id, reporter and reported profile ids, **reported person's iCloud account id** (`senderAccount`), reason, title or **chat line text**, photo or doodle asset | Moderator role (developer), **and the reporter (creator) can read and edit their own** | `Strata/Social/CrewSafety.swift:49-133`, `tools/cloudkit/full-schema.ckdb:119-136` |
| Bans | Public DB `Ban`: account id and a reason | **World-readable** | `tools/cloudkit/full-schema.ckdb:5-16`, `PublicCrewCloud.swift:1774-1818`, `tools/cloudkit/ban.sh` |
| Age range | UserDefaults on the phone only | Nobody else | `Strata/Social/CrewAge.swift` |
| Analytics | TelemetryDeck ingest API, no SDK: hashed random install id, session id, event names from a closed list, app version, device model, OS, locale | TelemetryDeck and developer. **Currently silent**: no `SomeWinsTelemetryAppID` in `Info.plist` or the project yet | `Strata/Services/Analytics.swift`, `tasks/launch-checklist.md` section 5 |
| Push | Apple only (CloudKit subscriptions, silent push; notification written on the phone) | Apple | `Strata/Social/CrewNotifications.swift`, `SomeWinsNotifications/NotificationService.swift` |
| Place names | `CLGeocoder` reverse lookups, Apple, real time | Apple | `Strata/Services/PlaceNames.swift` |

Network surface, by grep of every `https://` and `URLSession` in app,
widget and extension code: Apple (CloudKit, geocoder, push, StoreKit) and
TelemetryDeck. Nothing else. **(b)**

Permission strings (`Strata.xcodeproj/project.pbxproj`, both configs):
camera, Face ID (journal lock), location when in use, photo library add,
**photo library read** ("So a photo you took today can go on a win."). No
contacts, no microphone, no tracking (ATT). **(b)**

---

## 2. Children and teens

### 2.1 COPPA (under 13)

**Rule (a).** Children's Online Privacy Protection Act, 15 U.S.C. 6501-6506,
and the FTC's COPPA Rule, 16 CFR Part 312
(https://www.ecfr.gov/current/title-16/chapter-I/subchapter-C/part-312).
Applies to an operator of an online service (1) **directed to children** under
13, or (2) with **actual knowledge** that it collects personal information
from a child. The 2025 amendments (final rule April 2025, compliance date
22 April 2026) add **biometric identifiers** (including facial templates and
"faceprints") to "personal information"
(https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-finalizes-changes-childrens-privacy-rule-limiting-companies-ability-monetize-kids-data).
"Personal information" already included a photo containing a child's image
and a **persistent identifier**. The "support for internal operations"
exception (312.5(c)(7)) lets a persistent identifier be collected without
parental consent when used only for things like analytics that keep the
service working, and for nothing else.

**Does it apply (c).**
- *Directed to children?* No on the facts: 13+ rating, college-student
  audience (memory: "launch users are students"), no child-oriented content,
  no Kids category. Keep marketing (TikTok/Instagram film, screenshots,
  description) free of anything child-directed; the FTC weighs that.
- *Actual knowledge?* **Yes, the app can acquire it.** When Declared Age
  Range answers under 13, the app stores `under13` (`CrewAge.swift:84`,
  `CrewsListView.swift:807`). From then on it knows this install is a child.
  What does it then "collect" (send off the phone to itself)?
  - Wins, heads, photos: stay on the phone and the child's own iCloud.
    Not collected by the operator (c), though no FTC text says so outright.
  - Crews: never open for under 13 (`CrewGate.swift:34-35`). Good.
  - Reports: a child cannot be in a crew, so cannot report or be reported.
  - **Analytics: still sent.** The hashed install id is a persistent
    identifier. It likely fits the internal-operations exception
    (aggregate counts to fix the app), but only if it is never used for
    anything else, and the policy must still describe it.
- *Is an app-wide age gate needed?* No, for a general-audience 13+ app;
  COPPA does not require one, and the FTC discourages gates that invite
  lying. But California's AB 1043 (section 2.3) will require asking the
  platform's age signal at download/launch from 2027, so plan for it.

**What the app does today (b).** Crews blocked under 13; policy section
"Children" says not directed at children and crews do not open under 13.
Analytics are not gated by age (`Analytics.swift` has no age check).

**Gaps and fixes.**
- **Should fix:** when `CrewAge.current == .under13`, call
  `Analytics.shared.stopSharing()` (it also forgets the install id). Cheap,
  removes the only operator collection from a known child. Add one policy
  line: "If Apple tells Some Wins you are under 13, anonymous usage counts
  stop."
- **Should fix:** the head step in onboarding (`OnboardingView.swift:106`)
  asks everyone, including any under-13 who installed anyway, to scan their
  face before any age is known. On-device only, so not COPPA "collection"
  (c), but see section 3's notice.

### 2.2 California Age-Appropriate Design Code (AB 2273)

**Rule (a).** Cal. Civ. Code 1798.99.28-1798.99.40. Applies only to a
"business" as defined by the CCPA (section 4), so **it would not reach Some
Wins even if it were in force** (c). Status: enjoined in *NetChoice v. Bonta*
(see the status table in section 2.5). No action.

### 2.3 App store age laws (Utah, Texas, Louisiana, California)

**Rules (a).**
- **Utah App Store Accountability Act** (SB 142, 2025), Utah Code 13-75.
  Duties on app stores and on **developers**: use the store's age category
  and parental-consent signal, do not enforce terms against a minor without
  consent, tell the store about "significant changes". See section 2.5 for
  dates.
- **Texas App Store Accountability Act** (SB 2420), Tex. Bus. & Com. Code
  ch. 121. **In force since 4 June 2026** (the Fifth Circuit stayed the
  December 2025 injunction). Apple's developer notice
  (https://developer.apple.com/news/?id=sg176nne) lists the developer side:
  use Declared Age Range for the age category, ask PermissionKit's
  significant-change API when the app changes in a way that matters to a
  minor (Apple says deciding what counts is the developer's job), and handle
  the server notification when a parent withdraws consent.
- **Louisiana** (HB 570, 2025) and **California Digital Age Assurance Act**
  (AB 1043, 2025): see section 2.5.

**How Apple implements them (a).** The Declared Age Range framework
(https://developer.apple.com/documentation/declaredagerange) is Apple's
mechanism for developers to receive the age category, and in regulated
regions the parental-consent status; PermissionKit carries "significant
change" consent requests. Apple's developer news posts on these laws are the
place to read what Apple expects per state.

**What the app does (b).** Asks Declared Age Range once, at first Crews open,
with gates 13 and 16 (`CrewsListView.swift:798-830`); stores the lower bound
only; re-asks after 90 days unless adult (`CrewAge.swift:49-56`); treats
"declined" and errors as 13-15 (`CrewAge.swift:20-27`, `:59`). On
TestFlight an error is treated as adult (`CrewsListView.swift:818`), which is
fine because TestFlight testers are invited.

**Gaps (c).**
- The app asks only at Crews. Utah's developer duties and California's
  AB 1043 are framed around download/launch, not a feature. For a Utah user,
  the store-level age and consent signal should be read at launch, not only
  at Crews. **LAWYER** (Utah), and plan an engineering task for 2027 (AB
  1043).
- Nothing reads Apple's regulated-region signals (whether regulatory
  requirements apply, whether sharing is required, whether parental
  permission is needed for significant updates). **Texas is live now.**
  **Must fix for a Texas launch** (or **LAWYER** to confirm feature-level is
  enough): at launch, ask Declared Age Range whether requirements apply; for
  a Texas minor, read the age at launch rather than only at Crews, route
  significant changes (turning crews on in an update, adding chat or photo
  features) through PermissionKit, and handle consent-withdrawn by closing
  crews for that person. Utah, Louisiana, Alabama and California follow in
  2027.

### 2.4 Other state social-media-for-minors laws

Most (Florida HB 3, Georgia SB 351, Tennessee, Mississippi HB 1126, Texas
SCOPE Act HB 18, Virginia SB 854, Nebraska, Louisiana) define "social media
platform" by public profiles, discovery of strangers, or a user or revenue
threshold, and several are enjoined. Crews are invite-only groups of at most
8 with no discovery, no public profile, no feed, no algorithm. **(c)** Most
definitions do not reach it, and where one arguably does (Mississippi's
broad definition, Virginia's 1-hour default for under 16) the exposure is
small and the cure is the same as Australia's: 16+ for crews in that state.
The table in section 2.5 gives each law's status. **LAWYER** for a 30-minute
pass over the table, not more.

### 2.5 Status of the age laws, October 2026

See the appendix (verified 2026-10-14). The headline: **Texas SB 2420 has been in force since 4 June 2026**; Utah (6 May 2027), Louisiana (1 July 2027), Alabama and California AB 1043 (1 January 2027) follow.

### 2.6 Australia and New Zealand

**Rule (a).** Online Safety Amendment (Social Media Minimum Age) Act 2024
(Cth), in force 10 December 2025: providers of an **age-restricted social
media platform** must take reasonable steps to stop under-16s having
accounts. Penalty up to AUD 49.5 million. The Online Safety
(Age-Restricted Social Media Platforms) Rules 2025 exclude services whose
sole or primary purpose is messaging, gaming, education, health and similar.
https://www.esafety.gov.au/about-us/industry-regulation/social-media-age-restrictions

**Does it apply (c).** Arguable either way. The statutory test is whether a
"significant purpose" of the service is online social interaction between
users, and whether users can post material. Crews (post wins with photos,
chat, react) are a social feature; the app's primary purpose is personal
logging. A small invite-only feature might be outside eSafety's priorities,
but the law has no size floor.

**What the app does (b).** Lets 13-15 into crews, with text only.

**Fix, ranked.** **Must decide before launch:** either (1) drop Australia
from the 1.0 territories (one checkbox), or (2) make crews 16+ for
Australian storefronts (the 16 gate already exists in `CrewAge`; key it on
`Locale.current.region` or the storefront). Option 1 costs nothing and can be
undone after a lawyer looks. **LAWYER** before re-adding Australia.

---

## 3. Biometrics and faces

### 3.1 What the code computes and keeps (b)

- **During capture**, every camera frame in the maker runs
  `VNDetectFaceLandmarksRequest` (eyes, brows, lips, jaw contour) and while
  lining up `VNDetectFaceCaptureQualityRequest`
  (`Strata/Services/HeadCaptureEngine.swift:213-217`). From these it measures
  smile width, brow raise, mouth openness, eye openness, wink, chin and the
  jawline (`:241-265`). These live only in memory with the kept frames.
- **From a chosen photo**, the same landmarks run once
  (`Strata/Services/HeadFromPhoto.swift:28-52`). Any photo can be chosen,
  including of someone else.
- **Subject lifting**: `VNGenerateForegroundInstanceMaskRequest`
  (`HeadCaptureEngine.swift:499`).
- **Kept on disk** per head (`HeadStore.swift:801-825`): the cut-out PNGs
  (600px), shut-eye PNGs, and `head.json` holding, per expression,
  `HeadRig.Eye` = eye centre x/y, half-width/height, tilt angle, the eye
  opening's **outline polygon**, and **iris colour** (`HeadRig.swift:31-44`),
  plus chin and content height. **No face template, no faceprint, no
  `VNGenerateImageFeaturePrintRequest`, no recognition, no matching**
  (grep of the whole app). Up to the last three heads are kept after "Delete
  This Head" until "Delete for Good".
- **Sent to crews** (16+ only, after the photo check): a 256px pack of the
  PNGs **and `head.json`** (`CrewHeadPack.swift:23-39`), sealed.
- **Also**: the camera runs `VNDetectFaceLandmarksRequest` for a live
  retouch on faces (`FaceRetouch.swift:144`, `LiveRetouch`), on anyone in
  frame, transiently, "without anyone noticing" (`FaceRetouch.swift:1-20`).
  Not stored. Not mentioned in the policy.

### 3.2 The laws

- **Illinois BIPA**, 740 ILCS 14
  (https://www.ilga.gov/legislation/ilcs/ilcs3.asp?ActID=3004&ChapterID=57).
  "Biometric identifier" includes a "scan of ... face geometry"; it
  **excludes photographs**. A private entity that "collects, captures ... or
  otherwise obtains" one needs a public written retention policy, written
  notice, and a written release (14/15). Private right of action, $1,000 or
  $5,000 per violation (since the 2024 amendment, per person, not per scan).
- **Texas CUBI**, Bus. & Com. Code 503.001
  (https://statutes.capitol.texas.gov/Docs/BC/htm/BC.503.htm): "record of
  hand or face geometry" captured for a commercial purpose needs notice and
  consent; AG enforcement only (the Meta and Google settlements).
- **Washington RCW 19.375** (enrolment into a database for a commercial
  purpose; photographs excluded) and **Washington My Health My Data Act**,
  RCW 19.373 (https://app.leg.wa.gov/RCW/default.aspx?cite=19.373):
  "biometric data" includes face imagery "from which an identifier template
  can be extracted", it counts as consumer health data, it needs **consent
  to collect**, a **separate Consumer Health Data Privacy Policy**, and it
  has a **private right of action**. No size threshold.
- **CCPA "biometric information"** (Civ. Code 1798.140(c)): only matters if
  the CCPA applies, which it does not (section 4).
- **COPPA** 2025: biometric identifiers are personal information, under 13
  only (section 2.1).
- **Colorado** (HB 24-1130, in the Colorado Privacy Act, effective 1 July
  2025): its biometric duties apply to any controller that processes
  biometric identifiers, regardless of the CPA's thresholds.

### 3.3 Does the head count? (c)

Probably not, for four reasons: (1) nothing leaves the phone to the
developer: crew copies are sealed and the developer cannot open them, so the
developer does not "collect" or "possess" anything in the usual sense;
(2) what is stored is a photograph (excluded from BIPA and RCW 19.375) and
eye-opening outlines in canvas fractions, from which nobody can be
identified; courts have tied "biometric identifier" to the ability to
identify (the Ninth Circuit's *Zellmer v. Meta*, 2024), and a September 2026
order in *Doe (Hazlitt) v. Apple* held face crops are not biometric
identifiers; (3) there is no template, enrolment or matching; (4) the
landmark pass is transient, and the Seventh Circuit (*G.T. v. Samsung*,
August 2026) held data that stays on the device outside the company's
control is not "possessed". Two cautions from the same cases: the Apple
order said **encryption is no defence** (control means the power to delete or
move, which the developer has over the public database), and geometry that
leaves the phone is where risk rises. So: never add a face vector, and
consider sending crews only the eye ellipse (x, y, rx, ry, angle) rather than
the outline polygon, if the blink still looks right.

**But** the exposure is lawsuit-shaped (BIPA and MHMDA both have private
rights of action, and plaintiffs' firms file on thin theories), the 2025
COPPA rule and MHMDA define face data broadly, and the policy currently says
something untrue. The cure is cheap. **LAWYER:** one question: "Does
on-device landmark detection plus storing eye-outline coordinates with a
cut-out photo, sealed end to end, require BIPA/MHMDA notice and consent?"

### 3.4 Fixes

- **Must fix (policy):** replace "never measurements of your face" with the
  truth, for example: "It keeps those small cut-out pictures and where the
  eyes sit in each, so your head can blink. It never makes or keeps a
  faceprint or anything that could recognise you, and none of it is sent to
  Some Wins." And: "The camera also finds faces to soften the light on them
  as you take a photo; nothing about a face is kept." And the crew copy:
  "goes to the crew, with where its eyes sit".
- **Should fix (code + copy):** a one-screen notice before the head maker's
  camera or photo pick, with a Continue button, saying what is found, what is
  kept, where, how to delete. This is the "written notice and release" a
  cautious reading of BIPA and the "consent" MHMDA asks for, at almost no
  cost. Store `head.consentedAt` locally.
- **Should fix:** a retention sentence for heads already exists ("stays...
  until you choose Delete for Good"). Add an automatic limit for earlier
  heads (for example, earlier heads deleted after a year unused) or say they
  are kept until deleted. BIPA requires a published retention schedule.
- **Nice to have:** a Settings toggle for the live retouch, and one line in
  the camera's explanation.
- **Nice to have:** say in the crew rules that a head must be your own face
  (HeadFromPhoto accepts anyone's photo; the terms already ban content "of
  anyone who has not agreed to be in it").

---

## 4. California: CCPA/CPRA and CalOPPA

**CCPA/CPRA (a).** Civ. Code 1798.140(d): a "business" must have annual
gross revenue above **$26,625,000** (CPI-adjusted from $25M on 1 Jan 2025),
or buy/sell/share personal information of 100,000+ consumers, or earn 50%+
of revenue from selling/sharing it. https://cppa.ca.gov/regulations/ .
**Some Wins is far below every threshold (c). The CCPA does not apply.**
Re-check if revenue or a data-selling model ever changes. The Age-Appropriate
Design Code, which borrows the same definition, does not apply either.

**CalOPPA (a).** Bus. & Prof. Code 22575-22579
(https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=22575).
Applies to any operator of an online service, including apps, that collects
personally identifiable information from California residents, **with no
size threshold**. The policy must be conspicuously posted (the App Store
listing link and in-app Settings count) and must:

| CalOPPA requirement | `docs/privacy.html` today | Verdict |
|---|---|---|
| Categories of PII collected | "What Some Wins stores", "Anonymous usage", report contents | Mostly yes; add the reported person's iCloud account id and chat text in reports, and library photo read access |
| Categories of third parties it is shared with | Apple (iCloud), TelemetryDeck | Yes |
| Process to review and request changes, if one exists | "You can ask what it holds ... or ask for it to be deleted" | Yes |
| How users are notified of material changes | "the date at the top changes with it" | Weak. Add: "If a change matters, Some Wins will also say so in the app." |
| Effective date | "last updated 14 October 2026" | Yes |
| How it responds to Do Not Track | "a Do Not Track signal changes nothing here" with the reason | Yes |
| Whether third parties collect PII over time and across sites | "does not track you across other apps or websites" | Yes |

**California minors (a).** Bus. & Prof. Code 22580-22582 ("eraser law"):
an operator with **actual knowledge** that a minor (under 18) in California
uses the service must let a registered minor remove content they posted, and
**tell them how**. Declared Age Range gives that knowledge for 13-17 (b,
`CrewAge.teen`). The app already lets anyone withdraw their wins, lines and
reactions (`SocialStore.withdrawEverything`, `:898-917`), so the mechanism
exists. **Should fix:** one policy paragraph headed "If you are under 18 in
California" pointing at Taking a win back.

---

## 5. GDPR and UK GDPR

**Rule (a).** GDPR (Regulation 2016/679): applies to a non-EU developer who
offers the app to people in the EU (Art. 3(2)). Needs a lawful basis (Art.
6), child consent at 13-16 depending on the country where consent is the
basis (Art. 8, https://gdpr-info.eu/art-8-gdpr/), a controller identity and
contact (Art. 13), an EU representative (Art. 27) unless processing is
occasional and low-risk, transfer safeguards (Ch. V), and rights handling.
ePrivacy Art. 5(3) requires consent to store or read an identifier on a
device unless strictly necessary, which bites the **analytics install id,
on by default** (`Analytics.swift:107`, `defaults.register(...: true)`).
The UK has the same shape plus the ICO's Children's Code and the Online
Safety Act 2023, whose user-to-user duties (illegal content and children's
risk assessments, age assurance) have no size floor.

**Does it apply (b, c).** The planned territories exclude the EU and UK
(`tasks/launch-checklist.md:114-116`). **Keep it that way for 1.0.** The
list was chosen for the EU trader-address rule and UK safety paperwork; the
analytics consent point and the Online Safety Act's risk assessments are two
more reasons. If the EU or UK are added later, the minimum is: analytics
opt-in (not opt-out) there, an Art. 27 representative or a documented reason
none is needed, a lawful-basis line per purpose in the policy, the EU trader
address the App Store requires, and an Online Safety Act illegal-content
risk assessment for the UK.

**Canada (a, c).** PIPEDA applies to commercial collection of personal
information about people in Canada, without a size floor; Quebec's Law 25
adds a named person in charge of personal information, a published policy,
and parental consent under 14. Because the developer collects very little
(reports, anonymous counts), the practical duties are: the policy (exists),
naming Jayden as the person responsible (exists under Contact), and treating
an under-14 Quebec user's report data with care (they can be in crews at
13). **Nice to have:** one sentence naming Jayden as "responsible for
personal information" for Quebec.

**New Zealand (a, c).** Privacy Act 2020 information privacy principles;
light-touch for this app; the policy as fixed meets them.

---

## 6. Apple App Store requirements

**Source (a):** App Review Guidelines,
https://developer.apple.com/app-store/review/guidelines/ ; App Privacy
Details, https://developer.apple.com/app-store/app-privacy-details/ .

### 6.1 Guideline 1.2 (user-generated content)

Needs: a filter for objectionable material, a way to report with timely
responses, a way to block abusive users, and published contact information.

| Requirement | Code | Verdict |
|---|---|---|
| Filter | `CrewWords` slur list on send and receive (`CrewWords.swift`, `CrewRecords.swift:178,226`, `SocialStore.swift:1188,1208`); Apple Sensitive Content Analysis on every outgoing and incoming photo, head, doodle, sticker and crew picture, entitlement now present (`Strata.entitlements`, `CrewSafety.swift:145-190`) | Meets it. Note: if the user has Sensitive Content Warning off, outgoing photos go **unchecked** (`photoIsFine` returns true when the policy is disabled) |
| Report | Win, person, crew, chat line, legacy reply (`CrewSafety.swift:31-43`), kept and retried offline (`:97-115`) | Meets it |
| Respond in time | Policy and crew rules promise "within a day" | A promise the developer must keep personally: check `tools/cloudkit/reports.sh` daily |
| Block | `CrewSafety.block` (`:193-202`); starter also removes; ban list removes an account everywhere (`PublicCrewCloud.swift:1774-1818`) | Meets it |
| Terms agreed before sharing | `CrewRules` sheet, "I Agree" (`Views/Crews/CrewRules.swift`) | Meets it. Should link the Terms of Use on that sheet so agreement covers them (clickwrap), not only the four lines |
| Contact | `jbett5@hotmail.com` in policy, terms, Settings | Meets it; add to the App Store support URL page |

### 6.2 Guideline 5.1.1 (data collection and storage)

- (i) Privacy policy in App Store Connect and in the app: yes
  (`PrivacyPolicyView`, generated by `tools/policy/policy.py`).
- (ii) Permission and consent: strings exist. **Photo library read**
  (`NSPhotoLibraryUsageDescription`) is requested for the "today's photos"
  strip (`TodaysPhotos.swift:28-31`), reading the full library with
  `.readWrite`. The string is accurate but the **policy never mentions
  library access**, and says "Choosing a photo does not give Some Wins your
  library", which is true only of the head picker. Should fix (section 8).
- (iii) Data minimisation: good.
- (v) Account sign-in and deletion: there is **no account creation**, so the
  in-app account-deletion rule does not apply (c). Crew membership is tied
  to the iCloud account, not an account the app creates. Reset All Data
  plus Leave/End crew is the deletion path. If App Review asks, point at
  them.
- (vi)/(vii): no sign-in, no SIWA requirement.

### 6.3 Guideline 5.1.2 (data use and sharing)

No tracking, no ATT prompt needed (`NSPrivacyTracking` false). 5.1.2(vi):
face data from camera APIs may not be used for marketing or data mining;
nothing does (`docs/heads-as-identity-2026-10-14.md` 3.1). Declared Age
Range results may be used only for age-appropriate experiences; they are
(b).

### 6.4 Guideline 5.1.4 (kids)

The app is not in the Kids category and is rated 13+, so 5.1.4(a)'s
third-party analytics ban does not apply. 5.1.4(b) (apps collecting from
minors must follow children's privacy law) is section 2.

### 6.5 The App Privacy label vs the code

`Strata/PrivacyInfo.xcprivacy` declares: User ID, Other User Content, Photos
or Videos, Name (all linked, app functionality, from reports); Device ID,
Product Interaction, Crash Data, Performance Data, Purchase History (not
linked, analytics). Against the code:

- **Correct**: report contents (`CrewSafety.swift:49-104`); analytics fields
  (`Analytics.swift:399-448`, closed enums); no tracking.
- **Stale reasoning, label still roughly right (must fix the comment and
  re-check the answer):** the manifest's header comment and
  `docs/crews-app-store-privacy.md` section 1 justify "crew content is not
  collected" by "private iCloud database of whoever started the crew ...
  shared through a CKShare". That architecture is gone. The new reason is
  **end-to-end sealing**: the developer holds only ciphertext it cannot open.
  Apple's test is data transmitted "in a way that allows you ... to access
  it"; sealed content plausibly is not accessible, but the **metadata is**
  (crew ids, record counts and times, each record's creator iCloud user id),
  and it is linked to an account id. That is covered by the User ID row
  already declared, as long as its purpose text in App Store Connect
  includes app functionality for crews, not only reports. **(c)**
- **Conflict between the two owner docs:** `tasks/launch-checklist.md:108-110`
  says "every row is not linked to you"; the manifest and
  `docs/crews-app-store-privacy.md` say the report rows are **linked**. The
  manifest is right (a report names an iCloud account). Enter them as
  linked.
- **Analytics rows while analytics are silent:** until the TelemetryDeck
  app id is in `Info.plist`, nothing is sent; declaring it is harmless
  over-disclosure. Put the id in before launch or the label overstates.
- **Notification extension has no privacy manifest.** `SomeWinsNotifications`
  compiles `NotifyShared/CrewNotes.swift`, which reads
  `UserDefaults(suiteName:)` (`:244`) and `CrewSeal.swift:76`. Apple's
  required-reason rule applies per bundle; the gap was already listed in
  `docs/crews-app-store-privacy.md` section 0. **Should fix:** add
  `SomeWinsNotifications/PrivacyInfo.xcprivacy` with UserDefaults `1C8F.1`
  and `NSPrivacyCollectedDataTypes` empty. (Builds have uploaded without it
  so far, so not an upload blocker today. (c))

### 6.6 Age rating

Answer **User-Generated Content: Yes**, **Messaging and Chat: Yes**,
**Age Assurance: Yes** (Declared Age Range), **Unrestricted Web: No**,
**Advertising: No** (`docs/crews-app-store-privacy.md` section 2). Under
Apple's 2025 rating system (13+, 16+, 18+ tiers) the calculated rating may
come out above 13+ because of unmoderated messaging; accept what Apple
calculates and do not under-declare. 13+ or 16+ are both fine for a
college-student audience; **16+ would also dissolve most of sections 2.3,
2.4 and 2.6**, at the cost of 13-15 year olds, who are not the launch
audience. Worth considering. **(c)**

### 6.7 Export compliance

`ITSAppUsesNonExemptEncryption = NO` (`project.pbxproj:715,757`). Crews now
use AES-256-GCM and HPKE through CryptoKit for end-to-end sealing
(`CrewSeal.swift`, `CrewRekey.swift`). Standard algorithms through Apple's
OS frameworks usually qualify for the mass-market exemption, so NO is
likely still right for US/CA/AU/NZ, but read Apple's "Complying with
Encryption Export Regulations" page once with the E2E fact in mind
(https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations).
**Nice to have / LAWYER if unsure.** France would need a declaration; it is
not a launch territory.

---

## 7. CSAM, abuse, Section 230, notifications, invites, location

### 7.1 NCMEC reporting

**Rule (a).** 18 U.S.C. 2258A
(https://www.law.cornell.edu/uscode/text/18/2258A): a **provider** of an
electronic communication service or remote computing service that obtains
**actual knowledge** of apparent child sexual abuse material on its service
must report to NCMEC's CyberTipline as soon as reasonably possible, and
preserve the report's contents (one year since the REPORT Act of 2024). No
duty to scan. Failure to report carries fines. The TAKE IT DOWN Act (2025)
adds a notice-and-removal duty for non-consensual intimate images on
"covered platforms" within 48 hours (compliance from 19 May 2026).

**Does it apply (c).** Probably yes in the narrow way that matters: the
developer runs the CloudKit public database that stores crews' records
(sealed) and receives reports with the photo in clear. A report showing
apparent CSAM is actual knowledge. The developer is a small "provider".

**What exists (b).** Policy and terms promise NCMEC reporting and a 48-hour
NCII removal process with a subject-line email. Reports arrive in the
CloudKit console; `tools/cloudkit/reports.sh` lists them and prints the
photo's download URL (it does not save the file, good).

**Gaps and fixes.**
- **Must do before crews go live:** register as an ESP with NCMEC's
  CyberTipline (https://report.cybertip.org/ , ESP registration), so a
  report can actually be filed. Write a one-page runbook in `tools/cloudkit/`:
  on apparent CSAM, **do not download, screenshot or forward**; file the
  CyberTipline report from the console data; ban the account; **keep the
  `Report` record and its asset for one year** (do not delete), then delete.
  Possessing such an image on a laptop is itself a crime; viewing in the
  console to assess is the narrow allowed path. **LAWYER** for the
  preservation step.
- **Must fix:** the NCII 48-hour promise needs a way to remove an image the
  developer cannot read. Today only a record's creator can delete it
  (`full-schema.ckdb:203-205`). Confirm the developer can delete a
  `CrewItem` in the Production public database (CloudKit Console or cktool
  with the Moderator/admin role) and write the steps in the runbook: ban the
  account, delete that account's `CrewItem` records in the named crew.
- **Should fix:** `Ban.reason` is **world-readable**
  (`full-schema.ckdb:13-15`) and `ban.sh` writes the report's reason into
  it. Never write a description there; use a fixed word like `"rules"`.
- **Should fix:** `Report` grants `READ, WRITE TO "_creator"`
  (`full-schema.ckdb:133`), so a reporter can read back and **edit or delete**
  their report, contradicting the policy ("only Some Wins can read it") and
  the earlier setup doc (`docs/crews-app-store-privacy.md` section 4: create
  only). Remove Read/Write for `_creator` in the Console, Production too.
- **Note:** when the user has Sensitive Content Warning and Communication
  Safety off, outgoing photos are not checked (`CrewSafety.swift:175-177`).
  That is Apple's design and the policy says so; it is acceptable for 1.2.

### 7.2 Section 230

47 U.S.C. 230 (https://www.law.cornell.edu/uscode/text/47/230): the
developer is not treated as the publisher of what users post, and is
protected for good-faith moderation. It does **not** cover federal criminal
law (CSAM), intellectual property, or the developer's own statements, so a
false privacy promise is not protected. **(a)**

### 7.3 Invite links

The crew key rides in the link after `#` (`CrewKeys.swift:3-35`); browsers
never send the fragment, and `docs/join.html:87-110` keeps it on the page.
**Anyone holding a link can join** (up to the 8-person cap) and read the
crew's last two weeks, including a teen's crew. Removal re-keys the crew
(`CrewRekey.swift:1-30`). **(b)** Fine for friends; say it in the policy:
"Anyone with a crew's invite link can join it, so send it only to people you
mean to." **Should fix.**

### 7.4 Notifications

Silent CloudKit pushes; the notification is written on the phone. Push
tokens go to Apple only. Pings hold one-way tags and are deleted after
about 10 minutes (`CrewNotes.swift:1-40`). The policy describes this
accurately. **(b)** No action.

### 7.5 Contacts

Not collected. No Contacts permission or string. The invite research
(`docs/invites-research-2026-10-13.md`) recommends staying that way;
contact matching would bring a Contacts permission, label rows and a teen
safety problem. **(b, c)**

### 7.6 Location and photo metadata

- Photos sent to crews are re-encoded with **no EXIF, no GPS, no maker
  notes** (`ShareDerivative.swift:5-38`), and a test reads one back. **(b)**
  The policy's "smaller copy with no place and no camera details" is true.
- **Mismatch:** a photo picked from the "today's photos" strip copies the
  library photo's own GPS onto the win (`TodaysPhotos.swift:100-107`,
  `AddWinSheet.swift:1121`), **even when Settings "remember places" is off**
  (`LocationService.remembersPlaces` is checked only for the live camera,
  `LocationService.swift:203`). The policy says the app notes a place only
  "at the moment you take it", "only while the camera is open", and that
  earlier photos "cannot be given one". It stays on the phone and in the
  user's iCloud, never to crews (b). **Should fix:** gate
  `TodaysPhotos.place(of:)` on `remembersPlaces`, and say in the policy that
  a photo from your library keeps the place it already has.

### 7.7 Analytics

TelemetryDeck, no SDK, closed field list, hashed random id, opt-out in
Settings, forgotten on Reset All Data and on opt-out
(`Analytics.swift:150-172`, `StoreReset.swift:201`). The policy describes it
accurately, including EU storage. **Default on.** Fine for US/CA/AU/NZ
(c); opt-in would be needed for EU/UK (section 5). Gate on under-13
(section 2.1).

---

## 8. Policy and terms vs the code: every mismatch found

`docs/privacy.html` (last updated 14 October 2026) and
`Strata/Views/PrivacyPolicyText.swift` are generated from
`tools/policy/policy.py`; fix the text there and regenerate.

| # | Policy says | Code does | Severity |
|---|---|---|---|
| P1 | "A crew runs on iCloud: it lives in the iCloud of whoever started it, and Apple shares it with the people in it." (Crews) | Every crew lives in the app's **public** CloudKit database, sealed end to end (`PublicCrewCloud.swift:5-26`, `CrewSeal.swift:6-13`) | **Must** |
| P2 | "Some Wins cannot read what a crew holds." | True because of the seal, but Some Wins does hold the sealed records and sees who wrote each and when | Must (reword with P1) |
| P3 | "A crew keeps two weeks of days, and older wins and their photos are deleted the next time anyone opens it." | Only a record's writer may delete it; each phone deletes **its own** old records (`SocialStore.swift:2137-2200`, comments at `:2186-2192`). Someone who deleted the app leaves sealed records in the database indefinitely | **Must** |
| P4 | "Leave a crew and your wins leave with you; end a crew you started and it is deleted for everyone." | Ending is a mark; each phone tidies its own posts when it next reads it (`PublicCrewCloud.swift:21-26`, `tidyAway` `:1330`) | Must (say "removed from every phone, and deleted from iCloud as each phone next opens") |
| P5 | "Deleting the app removes it from this device only: what is in your iCloud stays" | Also true of crew posts in Some Wins' database; not said | Must (add: "Your posts in crews stay, sealed, until you reinstall and leave, or ask Some Wins to delete them") |
| P6 | Head: "It keeps only those small cut-out pictures and where to place them, never video and never measurements of your face" | Keeps eye outlines, positions, tilt and iris colour per face (`HeadRig.swift:31-44`, `HeadStore.swift:801-825`) | **Must** |
| P7 | Head: "none of it leaves your device to be analysed" / "a smaller copy of your head goes to the crew" | `head.json` with those eye measurements goes too (`CrewHeadPack.swift:23-39`) | Must (with P6) |
| P8 | Places: "notes where a photo was taken, at the moment you take it ... only while the camera is open ... Photos you took before you turned it on have no place and cannot be given one." | Library photos from the today strip keep their own GPS, regardless of the setting (`TodaysPhotos.swift:100-107`, `AddWinSheet.swift:1121`) | Should |
| P9 | "Choosing a photo does not give Some Wins your library" | True of the head picker; the today strip asks **full** library read (`TodaysPhotos.swift:28-31`); the policy never mentions library access | Should |
| P10 | Report: "sends ... the title and, if there is one, the photo ... the random ids of the crew, the person and you, and the iCloud account identifier that sent it" | Also sends the **reported person's** iCloud account id (`senderAccount`) and, for a chat line, its **text** (`CrewSafety.swift:63-96`). For a person report it sends no head picture, so a reported head cannot be judged | Should (wording); Nice (send the head's neutral PNG with a person report) |
| P11 | Report: "only Some Wins can read it" | Schema lets the reporter read and edit their own (`full-schema.ckdb:133`) | Should (fix the schema) |
| P12 | Report: "reports are deleted after a year" | No code or script deletes them; it is a manual promise | Should (put it in the runbook, or say "kept for a year, then deleted") |
| P13 | "In short ... The only things that leave your phone are ..." | Also: crew pings (described later), ban list reads, `CLGeocoder` lookups to Apple, the key backup in your private iCloud | Nice (add "and Apple's own services the app uses, like naming a place") |
| P14 | No mention | Live face retouch on the front camera finds faces in every frame (`FaceRetouch.swift`, `LiveRetouch`) | Should (one sentence) |
| P15 | No mention | Anyone with an invite link can join a crew | Should |
| P16 | Changes: "the date at the top changes with it" | CalOPPA wants a description of how material changes are notified | Should |
| P17 | No mention | California minors' removal right (Bus. & Prof. 22581) | Should |
| P18 | No mention | Analytics continue for a known under-13 | Should (fix code, then say so) |

Present and fine: effective date, contact and identity (Jayden Betts,
California, email), rights and how to ask, Do Not Track, children's
statement, retention for heads and reports (stated), deletion, third
parties named (Apple, TelemetryDeck), no sale/share, NCII process. **(b)**

**Terms of Use** (`docs/terms.html`, last updated 8 October 2026):
- "I do not get a copy, because Some Wins has no server: crews run on
  Apple's iCloud." Partly stale for the same reason as P1: the records sit in
  Some Wins' CloudKit database, sealed, and reports do give the developer a
  copy. **Must** reword.
- "By using the app you agree": browsewrap, weak. Link the Terms on the crew
  rules sheet and the first onboarding page so there is a tap. **Should.**
- Missing: a **licence from the user** to store and transmit what they post
  (needed even E2E, because the developer's database holds it), a
  **termination** clause (ban), an **age** sentence that matches 13+ app
  rating, a **dispute** clause (small claims or courts of California is
  enough; skip arbitration for now), and **Apple as third-party beneficiary**
  (Apple's minimum terms require it in a custom EULA; using Apple's standard
  EULA, as the terms do, covers it). **Should.** **LAWYER** for a single
  review of the terms; they are short.
- "Every report is looked at within a day": keep only if it can be kept.

---

## 9. Ranked actions

### Must fix before the App Store launch with crews on

1. **Rewrite the policy's crew sections (P1-P5) and the terms' "no copy"
   line for the public, sealed database**, in `tools/policy/policy.py` and
   `docs/terms.html`, then regenerate and republish somewins.xyz/privacy.
   Also update the header comment in `Strata/PrivacyInfo.xcprivacy` and
   `docs/crews-app-store-privacy.md` section 1 to give the sealing as the
   reason crew content is not "collected". (Deception risk under the FTC Act
   and CalOPPA.)
2. **Fix the head sentences (P6, P7)** and add one line about the camera's
   face retouch (P14).
3. **Australia:** remove it from 1.0 availability, or make crews 16+ there.
4. **CSAM and NCII runbook**: register with NCMEC's CyberTipline as an ESP;
   write the no-download, report, ban, preserve-one-year steps; confirm the
   developer can delete another account's `CrewItem` in Production for the
   48-hour removal promise.
5. **CloudKit schema in Production:** `Report` create-only for everyone but
   Moderator (P11); `Ban.reason` never descriptive.
6. **App Privacy answers in App Store Connect match the manifest**: report
   rows **linked** (the launch checklist says otherwise); User ID purpose
   covers crews; TelemetryDeck app id in `Info.plist` before submission so
   the analytics rows are true.
7. **Age rating questionnaire answered truthfully** (UGC yes, messaging yes,
   age assurance yes, and since September 2026 the **social media
   capabilities** questions) and accept the calculated rating.
8. **Texas (in force since 4 June 2026):** read Declared Age Range's
   regulatory signals at launch, PermissionKit significant-change requests
   for minors, handle consent withdrawal. Or confirm with a lawyer that the
   Crews-time check suffices. (Section 2.3.)

### Should fix (first update, or before launch if time allows)

9. One-screen notice and Continue before the head maker (BIPA/MHMDA-style
   notice and consent), and a stated retention rule for earlier heads.
10. Stop analytics for a declared under-13 (`CrewAge.under13` ->
   `Analytics.shared.stopSharing()`), and say so.
11. Gate library-photo places on `remembersPlaces`; disclose library read
    access (P8, P9).
12. Policy additions: invite links (P15), California minors (P17), material
    changes notice (P16), report contents (P10), reports deleted after a year
    as a process (P12).
13. Terms: clickwrap link on the crew rules sheet; user content licence,
    termination, dispute, age lines.
14. `SomeWinsNotifications/PrivacyInfo.xcprivacy` (UserDefaults `1C8F.1`).
15. Before 1 January 2027: read the age signal at download/launch for
    California (AB 1043) and Alabama, then Utah (6 May 2027) and Louisiana
    (1 July 2027). The Texas work in item 8 covers most of it.
16. COPPA notice: name "fixing the app" as the internal operation analytics
    rely on, and publish a retention period for analytics and reports.
17. Write a one-page Australia self-assessment (eSafety recommends one)
    if Australia stays on the list.

### Nice to have

18. Send the head's neutral PNG with a person report, so a reported head
    can be judged.
19. A retouch toggle in Settings.
20. "Responsible for personal information" line for Quebec.
21. A periodic moderator sweep that deletes sealed crew records older than
    the two-week window that their writers never came back to delete (if
    CloudKit's admin path allows it), so P3's promise becomes true even for
    people who deleted the app.
22. Consider a 16+ rating for crews everywhere: it removes most teen-law
    exposure, and the launch audience is college students.

### For a lawyer (one short consult covers all of it)

- Australia's minimum-age law: is a habit app with optional invite-only
  groups an age-restricted social media platform?
- Biometric: does on-device landmarking plus stored eye outlines with a
  cut-out photo, sealed end to end, need BIPA or Washington MHMDA notice and
  consent, and does MHMDA's separate health-data policy apply to an app
  "designed with ADHD brains in mind"?
- NCMEC: the preservation and handling steps for a provider who cannot
  decrypt stored content but receives reported images in clear.
- Texas SB 2420 (in force) and the 2027 Utah/Louisiana/Alabama/California
  laws: is an age check at the feature (Crews) enough, and what is a
  "significant change"?
- Texas SCOPE Act: does a small invite-only group feature make the app a
  "digital service provider", and was a small-business exemption enacted?
- A read of the Terms of Use.

---

## Appendix: law status table

Verified by a web-research pass on 2026-10-14 unless marked [R] (recall).
Secondary sources (law-firm alerts, trackers) are marked; confirm the
primary text before relying on a row.

| Law | Status, October 2026 | Reaches Some Wins? (c) | Source |
|---|---|---|---|
| COPPA Rule amendments | Effective 23 Jun 2025, compliance 22 Apr 2026. Biometric identifiers usable for recognition are personal information; notice must name the internal operations relied on; written retention policy required | Only with actual knowledge of under 13 (section 2.1). Add a retention line and name "fixing the app" as the internal operation | https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule |
| California AADC (AB 2273) | Ninth Circuit, 12 Mar 2026: injunction partly lifted (defaults, privacy info, geolocation limits, reporting tools not enjoined) | No: CCPA-business threshold | https://www.hklaw.com/en/insights/publications/2026/03/ninth-circuit-issues-mixed-ruling-on-california-age-appropriate-design-code-act (secondary) |
| California AB 1043 | Signed 13 Oct 2025, effective 1 Jan 2027. Developers request the OS/store age signal at download and launch; the signal is actual knowledge. No size threshold; AG, $2,500 / $7,500 per child | **Yes from 2027** | https://leginfo.legislature.ca.gov/faces/billNavClient.xhtml?bill_id=202520260AB1043 |
| California SB 976 | Personalized-feed provisions enforceable (N.D. Cal., Aug 2026); appeals pending | No: chronological, private, chosen-by-user | https://www.courthousenews.com/wp-content/uploads/2026/08/j-edward-davila-order.pdf |
| **Texas App Store Accountability Act (SB 2420)** | **In force since 4 Jun 2026** (Fifth Circuit stayed the Dec 2025 injunction; Supreme Court declined to vacate, 6 Jul 2026, per tracker). Developers: Declared Age Range, PermissionKit significant-change requests, handle consent-withdrawn notifications. DTPA enforcement, no size threshold | **Yes** (section 2.3) | https://developer.apple.com/news/?id=sg176nne , https://ccianet.org/litigation/ccia-v-paxton/ |
| Utah (SB 142, amended HB 498) | Key duties delayed to **6 May 2027**; private right of action only. Apple shares age for new Utah accounts since 6 May 2026 | Yes from 2027 | https://le.utah.gov/Session/2026/bills/enrolled/HB0498.pdf |
| Louisiana HB 570 | Delayed to **1 Jul 2027** | Yes from 2027 | https://www.alstonprivacy.com/louisiana-delays-app-store-accountability-effective-date-to-july-2027/ (secondary) |
| Alabama HB 161 | Effective 1 Jan 2027 | Yes from 2027 | https://www.loeb.com/en/insights/passle/2026/02/alabama-becomes-the-fourth-state-to-enact-an-app-store-accountability-act (secondary) |
| Texas SCOPE Act (HB 18) | Fifth Circuit, 24 Jul 2026: monitoring/filtering blocked; age-registration and ad parts enforceable | **Plausibly** (any service with social interaction, posts and a profile); whether a small-business exemption (SB 1860) passed is unverified. **LAWYER** | https://capitol.texas.gov/tlodocs/88R/billtext/html/HB00018F.htm |
| Florida HB 3 | In force (injunction stayed Nov 2025) | No: needs 10% under-16 DAU at 2h/day plus algorithmic, addictive features | secondary |
| Georgia SB 351 | Social-media parts enjoined | Unlikely | [R] |
| Tennessee HB 1891 | Not enjoined | Possibly, broad definition [R] | [R] |
| Mississippi HB 1126 | Enforceable pending merits | Possibly, broad definition [R] | https://netchoice.org/netchoice-v-fitch-mississippi/ |
| Virginia SB 854 | Enjoined 27 Feb 2026 | Likely not | https://netchoice.org/netchoice-v-miyares-virginia/ |
| Nebraska LB 383 / LB 504 | LB 383 partly enjoined; LB 504 has a revenue threshold | No (LB 504); LB 383 unverified | secondary |
| Vermont AADC (S.69) | Effective 1 Jan 2027, CCPA-like thresholds [R] | Likely no | [R] |
| **Australia Social Media Minimum Age** | In force 10 Dec 2025; "significant purpose" test, exclusions only for *primary* purpose messaging/gaming/etc.; no small-service carve-out; eSafety recommends a written self-assessment | **Arguable** (section 2.6) | https://esafety.gov.au/about-us/industry-regulation/social-media-age-restrictions/assessment |
| Australia Privacy Act / Children's Online Privacy Code | Small-business exemption (turnover AUD 3M or less); code to be registered by 10 Dec 2026, binds APP entities only | No today | https://www.oaic.gov.au/privacy/privacy-registers/privacy-codes/childrens-online-privacy-code |
| Canada PIPEDA / Quebec Law 25 | PIPEDA only for "commercial activity" (a free app is uncertain); Law 25: published privacy officer (can be Jayden), plain-language policy, parent consent under 14 | Low; name the privacy officer | https://www.legisquebec.gouv.qc.ca/en/document/cs/P-39.1 |
| New Zealand Privacy Act 2020, IPP 3A | IPP 3A (notice for information collected indirectly) in force 1 May 2026 | Low; crew posts about others are the users', not the developer's | https://www.privacy.org.nz/assets/DOCUMENTS/251104-IPP3A-guidance-A1128460.pdf |
| BIPA | 2024 amendment: per-person damages, e-consent valid. **G.T. v. Samsung (7th Cir., 7 Aug 2026)**: on-device templates the company cannot access or control are not "possessed". **Doe (Hazlitt) v. Apple (S.D. Ill., 30 Sep 2026, trade press)**: face crops are not biometric identifiers; faceprint vectors may be; "capable of identifying" is the test (Zellmer); **encryption is no defence**, control means power to delete or move | Low (section 3.3). Do not add vectors or send more geometry than needed | https://caselaw.findlaw.com/court/us-7th-circuit/302932.html , https://ppc.land/apple-loses-bid-to-end-illinois-suit-over-faceprints-in-iphone-photos/ |
| Texas CUBI | Notice and consent for face geometry captured for commercial purpose; AG only, $25,000 per violation | Low | https://statutes.capitol.texas.gov/Docs/BC/htm/BC.503.htm |
| Washington RCW 19.375 / MHMDA | 19.375 excludes photographs; MHMDA covers face imagery "from which an identifier template can be extracted", private right of action, no on-device exemption found | **LAWYER** | https://app.leg.wa.gov/RCW/default.aspx?cite=19.373 |
| Colorado HB 24-1130 | Effective 1 Jul 2025, any controller of biometric identifiers; photographs carved out | Low | https://leg.colorado.gov/bills/hb24-1130 |
| CCPA | $26,625,000 since 1 Jan 2025 | No | https://cppa.ca.gov/regulations/cpi_adjustment.html |
| 18 U.S.C. 2258A / REPORT Act | Any provider, no size floor, actual knowledge only; 1-year preservation secured per NIST CSF; enticement and trafficking now reportable | Yes, via reports | https://www.congress.gov/118/bills/s474/BILLS-118s474enr.htm |
| TAKE IT DOWN Act | FTC enforcing since 19 May 2026; 48-hour removal plus known copies; about $53,088 per violation | Treat as covered | https://wilmerhale.com/en/insights/client-alerts/20260615-the-take-it-down-act-goes-live |
| Apple age ratings | 13+/16+/18+; questionnaire due 31 Jan 2026; **from Sept 2026, "social media capabilities" answers required**, giving a Social Media descriptor and iOS 27 Time Allowances (excluded for users for whom the feature is off under 13); a rating change can be a Texas "significant change" | Yes | https://developer.apple.com/news/?id=tlur8uvi |
| Apple 1.2 | Since 6 Feb 2026 explicitly covers random/anonymous chat | Already meets 1.2 | https://developer.apple.com/app-store/review/guidelines/ |
| Apple App Privacy | Silent on end-to-end encrypted data the developer cannot read | See 6.5 | https://developer.apple.com/app-store/app-privacy-details/ |
| TelemetryDeck | Declare Device ID and Product Interaction, not linked, not tracking | Matches the manifest | https://telemetrydeck.com/docs/articles/apple-app-privacy/ |
