# Heads as identity: audit, research and passes (2026-10-14)

Research and audit only. Nothing in the app was changed to write this. Read
against `~/Developer/Strata` at `c2a821e`.

## The owner's brief, verbatim

> "the heads dont need to be an option in the settings for crew or settings
> like the head should just be the default unless you dont have a head for the
> map but if you do it should be the default treat the head not really as an
> optional thing but an identity like our version of the bit moji peoples
> identity remove the option for a pfp and make the head making a must I think
> that would genuinely make the app better in a fun way. because later i am
> going to add customization and things for the heads and I want to make sure
> they are pretty normalized throughout the app so that makes that easier down
> the line do the research and add this to the passes."

## What this reverses (so nobody "fixes" it back)

These are recorded decisions that the brief above overturns. Each needs its
row in `docs/design.md` struck through and re-dated 2026-10-14 in the same
change that ships the pass, the way earlier reversals were recorded.

| Where | What it says today | Becomes |
|---|---|---|
| `docs/profile-and-head-plan.md` §1 | "The head is 100% optional. Every place it can appear is its own switch, and every switch starts OFF." | The head is who you are. No switches about whether it is you. |
| `docs/profile-and-head-plan.md` §1, §4.1 | "The profile picture is a choice: initials (the default), a photograph, or the moving head." | The picture is your head. No photograph option. |
| `docs/design.md` row "Heads per crew, on or off" (2026-10-03) | A per-crew switch in the crew's details. | Gone. |
| `docs/design.md` row "One head ... A first head starts on the map and on photos; tower and profile picture are off" (2026-10-03) | Profile picture off by default. | Always the picture. Tower stays an owner's call (below). |
| `docs/design.md` row "Make Your Head ... nowhere else" (2026-10-02) | The crew pill is the only ask. | Onboarding makes it; the pill remains only as the catch-up for anyone who still has none. |
| `OnboardingView.swift:57` doc comment | "the head is offered and never required" | Required, with a way through when the camera cannot do it (§4.4). |
| `HeadStore.swift:7` doc comment | "Every switch starts OFF. The head is 100% optional" | Rewritten. |

---

## 1. Audit

### 1.1 Every place a person is drawn

"Head" below means a `HeadRig` drawn by `LivingHeadView` (alive) or
`HeadStill` (a still, eyes resting to one side). "Fallback" is what is drawn
when there is no head.

**Your own surfaces**

| Surface | File:line | Draws today | Component | Fallback |
|---|---|---|---|---|
| Wins header, the goal crest's middle | `GoalRing.swift:253` (`GoalCrest`, placed at `MainAppView.swift:1457`), `CrestFace` at `GoalRing.swift:331-343` | Your head, calm, if `headForCrews` | `LivingHeadView` at 0.76 of the circle | `ProfileAvatar`: your photo, else initials on a colour, else a `person.fill` glyph |
| Goal reached moment | `GoalRingMoment.swift:251` | Same as above | `CrestFace` | Same |
| Your Day sheet | `YourDaySheet.swift:243` | Same | `CrestFace(side: 72)` | Same |
| Onboarding goal page | `OnboardingView.swift:629` | Same | `CrestFace(side: 92)` | Same |
| Your Wins tower, the companion | `TowerCompanionLayer.swift:378`, `:614`, `:619`; layer placed at `MainAppView.swift:1329`; `CompanionDock.swift:129`, `:219` | Your head walking on the blocks, only if "Let My Head Onto the Tower" is on | `LivingHeadView` | Nothing (no companion) |
| Memories header, Profile button | `MemoriesView.swift:751` → `ProfileButton` at `ProfileAvatar.swift:134-231` | Head (calm) only if "Use as Profile Picture" is on, else photo, else initials, else `person` glyph | `LivingHeadView` at 0.76 | Photo / initials / glyph |
| Profile, the big picture | `ProfileView.swift:310` → `ProfileAvatar` at `ProfileAvatar.swift:43-125` | Same order, expressive | `LivingHeadView` at 0.76 | Photo / initials / glyph |
| Profile, head row and look row | `HeadPickerRow.swift:112`, `HeadLookPicker.swift:69` | Each head's still | `HeadStill` at 0.78 of a 60pt square | "Make Your Head" row |
| Map, where you are | `MemoriesMapView.swift:332-337` → `HeadMarker.swift:41` | Your head standing, with the contact shadow, if "Show My Head on the Map" | `LivingHeadView` | The native blue `UserAnnotation()` |
| Camera review, the sticker | `CameraView.swift:665`, `:791`, `:955`; `HeadSticker.swift:59` (baked), `:148` (overlay), `:359` (button) | Your head as a sticker on the photo, button shown if "Add My Head to Photos" | `HeadStill` baked, `LivingHeadView` live | No sticker button |
| Onboarding head page | `OnboardingView.swift:949-957` | Your head if made, else the creator's | `TappableHead` | The creator's head (`HeadRig.creatorRig`) |
| Head maker preview | `HeadMakerView.swift` | The new head, expressive | `LivingHeadView` | n/a |
| Debug parity page | `HeadParityView.swift:26-38` | Debug only | `LivingHeadView` | `HeadRig.creator()` |

**Crews (friends and you, as a crew sees you)**

| Surface | File:line | Draws today | Component | Fallback |
|---|---|---|---|---|
| Crews list rows | `CrewsListView.swift:221` | The crew's photo, or up to four member faces clustered Messages-style | `CrewFaces` (`CrewFaces.swift:114-140`) → `CrewFace` | Crew photo first; per member, see `CrewFace` |
| Crew details, identity | `CrewInfoSheet.swift:306` | Same, at 96 | `CrewFaces` | Same |
| Crew details, people list | `CrewInfoSheet.swift:366` | One face per member, 40pt | `CrewFace` | Photo, else initial on a palette colour |
| `CrewFace` itself | `CrewFaces.swift:55-105` | A friend's head as a still at 0.9 of the circle | `HeadStill` | Their profile photo (`member.photo`) if it passed the photo check, else their initial in white on a colour picked from their id (`:97-104`) |
| Crew tower, floating heads | `CrewHeadArena.swift:309-316` (everyone), runner `:402-404` | Each member alive, one size with the Wins head | `LivingHeadView` | A floating `CrewFace` disc at 0.78 (owner, 2026-10-03: "they shouldnt be excluded") |
| Crew tower, the bubble | `CrewHeadArena.swift:169` (empty: `CrewFaces`), `:202-205` (crammed) | Crammed heads | `LivingHeadView` | `CrewFace` at 0.8 |
| Crew tower, the fan | `CrewHeadArena.swift:701-706` | Heads on a disc at 0.92 | `LivingHeadView` | `CrewFace` |
| Chat avatars | `CrewChatSheet.swift:277` | A friend's face at the start of their run | `CrewFace` | Photo / initial |
| Reactions on a win | `CrewReactions.swift:181` | Who reacted, 40pt, emoji or sticker on the corner | `CrewFace` | Photo / initial |
| Make Your Head pill | `MakeYourHead.swift:25`, shown at `CrewInfoSheet.swift:343-346` | Up to three friends' faces, then a dashed circle with a plus | `CrewFace` | Same |
| Crew tower visibility | `CrewTowerView.swift:397`, `:627`, `:637`, `:741` | Arena, bubble and fan only when the crew's Heads switch is on | | Off: the bubble is the crew's picture |

**Places that draw a person only as words** (no face today)

| Surface | File:line | Today |
|---|---|---|
| Photo viewer byline | `PhotoViewer.swift:583` | "Sam · Quick · Today · 9:41" text |
| Crew day view | `CrewDayView.swift:183` | `CrewTowerModel.senderLine` text |
| Tag chips ("with") | `CrewWithRow.swift:69-98` | A circle glyph and the first name |
| Notifications | `SomeWinsNotifications/NotificationService.swift:206` | Title is the friend's first name; no avatar, no communication intent |
| Photo strips, strip share | `CrewStrip.swift:26`, `CrewStripShare.swift:94-112` | Signed with the crew's name; the share icon is the crew photo or a `person.2.fill` glyph |
| Share cards, replays | `ShareTowerCard.swift`, `ReplayCard.swift`, `ReplayView.swift`, `ReplayFrame.swift` | No person drawn |
| Widget | `StrataWidget` | No person drawn |

### 1.2 What this shows about normalization

The same idea, "a head in a circle", is drawn at **five different shares of
the circle**: 0.76 (`ProfileAvatar.headShare`, the crest, the sticker
button), 0.78 (`HeadPickerRow`, `HeadLookPicker`, the runner's fallback), 0.8
(the bubble's fallback), 0.9 (`CrewFace`) and 0.92 (`CrewFan`). And there are
**two decision trees for "who is this"**: `CrestFace`/`ProfileAvatar` for you
(head, photo, initials, glyph, governed by `isProfilePicture`) and
`CrewHeads.rig`/`CrewFace` for crews (head, photo, initial, governed by
`isSomewhere`, the photo check and age). They can disagree on one screen: with
"Use as Profile Picture" off, the Memories button shows your initials while
the Wins crest and every crew show your head. Customization would have to be
taught to both trees and all five sizes. That is the concrete case for one
component.

### 1.3 Every toggle or setting about heads or profile photos

| Setting | Where | Stored | Effect |
|---|---|---|---|
| Use as Profile Picture | `ProfileView.swift:613`; also the picture menu `:283-294` | `headIsProfilePicture` (`HeadStore.swift:236`) | Head vs photo/initials in `ProfileAvatar` and `ProfileButton` only |
| Let My Head Onto the Tower | `ProfileView.swift:683` | `headOnTower` | Your Wins tower companion |
| Show My Head on the Map | `ProfileView.swift:694` | `headOnMap` | `HeadMarker` vs native dot |
| Add My Head to Photos | `ProfileView.swift:705` | `headCameraSticker` | Sticker button on the camera review |
| Look (film look on the head) | `ProfileView.swift:647` disclosure, `HeadLookPicker` | `headLook` | Hidden unless `isSomewhere` |
| Choose Photo / Remove Photo / Use Photo or Initials | `ProfileView.swift:285`, `:296`, `:307` | `Profile/photo.jpg` (`ProfileStore.swift:197-200`) | The profile photograph; also sent to crews as `member.photo` for 16+ (`SocialStore.swift:57`, `:813`) |
| Background Colour | `ProfileView.swift:302` | `profileBackground` | Colour behind head or initials |
| Heads (per crew) | `CrewInfoSheet.swift:72-85` | `crews.headsHidden` (`SocialStore.swift:2207-2221`) | Hides arena, bubble and fan on that crew, this phone only |
| Hidden: `isSomewhere` | `HeadStore.swift:395-419`, `:623` | derived | **A head switched off everywhere is not sent to crews** (`headForCrews`, `crewHeadDirectory`). With all four switches off you look headless to friends while you have a head |
| Delete head | `ProfileView.swift:720`, `HeadStore.delete` `:494-528` | | Back to no head, every switch off |
| Settings | `SettingsView.swift:698` | | Only Reset All Data mentions the head; Settings has no head switch |

### 1.4 Every way to end up without a head

1. **Onboarding "Not Now"** on the head page (`OnboardingView.swift:1318`,
   `decline` at `:1355-1360`). The page is shown step 4 of the five shown
   steps (`skipped` at `:143`).
2. **Closing the maker** without saving leaves you on the head page, where
   Not Now is one press away (`:257-266`).
3. **Camera denied or absent**: the maker's only exit is "Open Settings" or
   "Close" (`HeadMakerView.swift:456-459`, `:580-593`). There is no library
   route, so a denied camera means no head.
4. **Face not found / capture failed**: "Try Again" (`HeadMakerModel.swift:336`,
   `:411`, `:535`). Repeating forever is the only path; there is no other way
   to make one.
5. **Existing users** who finished onboarding before the head page, or
   skipped it.
6. **Delete** in Profile.
7. **Under 16 as friends see you**: you have a head on your phone but it
   never leaves it (`SocialStore.swift:838-845`, `CrewAge.sendsPhotos` at
   `CrewAge.swift:66-68`). Friends see your initial.
8. **Switched off everywhere** (`isSomewhere` false): friends see your photo
   or initial.
9. **A friend's head held back** by the photo check on the sender's phone
   (`SocialStore.swift:822-831`) or on yours (`CrewFaces.swift:26`).
10. **A viewer under 16 with Sensitive Content analysis off**:
    `CrewSafety.incoming` is `.hide` (`CrewSafety.swift:145-148`), so every
    friend's head and photo is withheld and they see initials only.

---

## 2. Research

Tags: **(a)** research or data, **(b)** seen in a shipping product or its
official docs, **(c)** inference.

### 2.1 Is avatar creation mandatory anywhere?

- **Snapchat / Bitmoji: not required.** You create one from Profile, "Create
  My Avatar", any time after sign-up. (b)
  https://help.snapchat.com/hc/en-us/articles/7012345832596-How-do-I-create-and-edit-my-Bitmoji-avatar
- Snap reported about 70% of daily users with a Bitmoji (147M of 210M, 2020),
  so roughly 30% of daily users had none. (a, company-reported)
  https://techcrunch.com/?p=1977631 ; and 85% of US 13 to 24 year olds in
  2022 (a, company-reported, not independently verified)
  https://www.axios.com/2022/04/28/snapchat-monthly-daily-users-summit-2022
- **Apple, My Card / Name and Photo: never required.** Photo, Memoji, emoji
  or monogram, chosen in Contacts; sharing is "Contacts Only" or "Always Ask".
  (b) https://support.apple.com/guide/iphone/add-your-contact-info-iph18b749db1/ios ,
  https://support.apple.com/en-au/guide/messages/ichta791c41e/mac . The
  monogram is the zero-effort default. (c)
- **Nintendo: a Mii is optional** on a Nintendo Account (the icon defaults to
  the nickname's first letter) and on a Switch user (pick a character icon or
  a Mii). (b)
  https://en-americas-support.nintendo.com/app/answers/detail/a_id/15997/~/nintendo-account-faq ,
  https://en-americas-support.nintendo.com/app/answers/detail/a_id/22377 .
  **Wii U is the one counter-example found**: creating a user includes
  "Create a Mii character, or select one". (b)
  https://en-americas-support.nintendo.com/app/answers/detail/a_id/1716
- **Zepeto**: "select a default avatar or take a selfie". Whether the step
  itself can be skipped could not be verified. (b)
  https://www.gadgetmatch.com/zepeto-lets-you-create-a-3d-character-version-of-yourself/
- **BeReal**: sign-up asks phone, name, age, username; the profile picture
  is added later from a BeReal, the gallery or the camera. (b)
  https://help.bereal.com/hc/en-us/articles/7531181915293-Profile-Picture .
  **Locket**: optional per a parent guide; sign-up requirement not verified.
  (b, weak)
- **Meta Quest** lets you skip avatar creation at setup, per third-party
  guides only. (b, weak)

**No data was found comparing a mandatory avatar step with an optional one.**
The studies below are about avatars people chose to make. (c)

### 2.2 What a required step costs at onboarding

- Nielsen Norman Group: onboarding should be "brief, optional", with a
  visible skip, and visual customization "doesn't belong in onboarding". (a)
  https://www.nngroup.com/articles/mobile-app-onboarding/
- Apple HIG, Onboarding: "Postpone nonessential setup flows or customization
  steps." (b) https://developer.apple.com/design/human-interface-guidelines/onboarding
- Apple HIG, Managing accounts: people "often abandon apps when they're forced
  to sign in". (b) https://developer.apple.com/design/human-interface-guidelines/managing-accounts
- Baymard: about 18 to 19% of US shoppers abandoned an order because an
  account was required (n = 1,026). E-commerce, so an analogy for a forced
  step, not a measure of this one. (a) https://baymard.com/lists/cart-abandonment-rate
- Per-field conversion losses quoted in vendor blogs have no stated method and
  should not be cited. (a, low quality)
- **What argues the other way here** (c): the head is not "customization" in
  NN/g's sense. It is the app's social identity and the thing that makes a
  crew feel alive; the owner's friends did not discover it when it was
  optional (design.md, 2026-10-02: "one of my friends didnt even realize you
  could make a head at all"). And the app already requires one identity step:
  the name page is "not optional" (`OnboardingView.swift:118-124`, owner
  2026-10-12). Requiring the head is the same kind of call, at higher cost
  (camera, about fifteen seconds, a face).
- **The cheapest evidence is already being collected.** `Analytics` sends
  `onboarding_step` with `.skipped` and `head_made`
  (`OnboardingView.swift:1358`, `HeadStore.swift:456`) to TelemetryDeck. If
  the app ID is set, the dashboard already says what share of TestFlight
  people press Not Now on the head page. Read it before deciding §4.4's
  strictness. (c)

### 2.3 Does a self-avatar earn its place?

- Proteus effect meta-analysis, 46 studies: a small to medium effect
  (about 0.22 to 0.26) of an avatar's traits on behaviour. Ratan et al.
  2019, *Media Psychology*, doi 10.1080/15213269.2019.1623698. (a)
- Avatar identification predicts time spent playing and in the editor (Kao
  and Harrell, CHI 2018). (a) https://people.csail.mit.edu/dkao/pdf/kao2018chi.pdf
- Fostering intrinsic motivation through avatar identification (Birk et al.,
  CHI 2016). Citation verified; findings not read. (a)
  https://doi.org/10.1145/2858036.2858062
- Already in this repo: a likeness of yourself that responds to your own
  behaviour increased that behaviour, an unchanging one did not (Fox and
  Bailenson 2009, cited in `docs/profile-and-head-plan.md` §2). (a)

### 2.4 Someone who refuses, or cannot

Every system found has a path that needs no camera, and **none makes a face
photo the only route** (c, from the sources below):

- Meta: "If you do not want to use a live selfie ... you can choose to create
  manually instead"; selfie mode "is not available everywhere". (b)
  https://www.meta.com/help/connected-experiences/3531951367126680/
- Bitmoji: start from a default avatar, the selfie is an optional start and
  only for first-time users; features editable after. (b, from the help
  article's search snippet; the page returned 403)
  https://support.bitmoji.com/hc/en-us/articles/360001493806-Create-Bitmoji-with-a-Selfie
- 3DS Mii Maker: "Start from Scratch" or "Create from Photo". (b, secondary)
  https://www.gamepeople.co.uk/family_3ds_miimaker.htm
- Apple: the monogram; Nintendo: the initial or a character icon. (b)

**What a missing avatar looks like:**

- Snap Map: someone without a Bitmoji appears "as a blank Bitmoji outline".
  (b) https://help.snapchat.com/hc/en-us/articles/7012324804628-How-do-I-use-Bitmoji-on-the-Snap-Map-and-what-is-Actionmoji ;
  Snapchat calls these "default placeholder avatars". (b)
  https://help.snapchat.com/hc/en-us/articles/7012353965076-How-do-I-link-or-unlink-my-Bitmoji-with-Snapchat
- That is the model for §4.2: a placeholder in the shape of a head, not a
  photo and not an initial in a circle. (c)

### 2.5 One canonical identity component that customization plugs into

- Snap: one avatar, many poses chosen by context. Snap Map's Actionmoji picks
  a pose from where you are and what you are doing, plus a "My Pose" you set
  for four hours; the profile's Selfie and Scene are edited in one place. (b)
  Snap Map URL above.
- Apple: one My Card picture, shared out by Name and Photo to every
  conversation, with one sharing control. (b) URLs above.
- What both have, and this app does not yet (c): **the avatar is data, and
  each surface renders it**. Customization changes the data once; every
  surface, on every phone, follows. Here a friend's head arrives as baked
  PNGs (`CrewHeadPack`), and the one customization that exists, the film look,
  is applied on your phone only (`HeadStore.look`, `dress()`); a friend never
  sees your look. Normalizing means the pack carries "what I am wearing" as
  fields and the receiver dresses the head with the same code you do.

---

## 3. Constraints

### 3.1 App Store Review Guidelines

https://developer.apple.com/app-store/review/guidelines/

- **5.1.1(iv)**: "Apps must respect the user's permission settings and not
  attempt to manipulate, trick, or force people to consent to unnecessary
  data access", and "Where possible, provide alternative solutions for users
  who don't grant consent." (b) A head that can only be made with the camera,
  in a flow you cannot pass without it, is the shape this rule describes. A
  library route removes the problem. (c)
- **PhotosPicker needs no permission.** PHPicker "manages its life cycle in a
  separate process ... The user doesn't need to explicitly authorize your app
  to select photos." (b)
  https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app ;
  WWDC20: do not prompt for library access before showing the picker. (b)
  https://developer.apple.com/videos/play/wwdc2020/10652/ . The app already
  uses `PhotosPicker` for the profile photo and crew picture.
- **Feasible here** (c, from reading the code): the cut-out pipeline is
  static functions over a `Take` (`HeadCaptureEngine.swift:50-60`, `cutOut`
  `:339`, `lift` `:498`), which is a still image plus Vision's face and eye
  results. A chosen photo can become one neutral `Take`. The result is a head
  with one face that does not blink or smile, which the rig already supports
  (the maker keeps only expressions that came through, and
  `HeadMakerView.previewCaption` at `:1010-1019` already words a head that
  "won't blink or smile").
- **5.1.2(vi)**: data from "depth and/or facial mapping tools (e.g. ARKit,
  Camera APIs, or Photo APIs) may not be used for marketing, advertising or
  use-based data mining". (b) The maker uses Vision on camera frames
  (`VNDetectFaceLandmarksRequest`, `VNDetectFaceCaptureQualityRequest`,
  `VNGenerateForegroundInstanceMaskRequest`, `HeadCaptureEngine.swift:213-214`,
  `:499`), no ARKit and no TrueDepth. Analytics never carries the head
  (`docs/superpowers/specs/2026-10-08-analytics-design.md` §2). Compliant as
  is; keep it that way when customization arrives. (c)
- **5.1.1(v)** (sign-in) does not apply: there is no account. (c)
- **5.1.4(b)**: apps collecting personal information from a minor, including
  "photos, videos, drawings", must have a privacy policy and follow children's
  privacy law. (b) Crews are 13+, and under 13 crews do not open.

### 3.2 The privacy label and policy

https://developer.apple.com/app-store/app-privacy-details/

- There is no "face data" category; "Biometric data" sits under Sensitive
  Info. Data "processed only on device is not 'collected'". (b) On-device
  face detection to make a head is not collected. (c)
- A head sent to a crew goes through iCloud shared databases, which
  `docs/crews-app-store-privacy.md` §1 reasons is not "collected" (no Some Wins
  server). If the owner takes that doc's conservative alternative, a head is
  **User Content > Photos or Videos** (it is cut from a photo) or **Other User
  Content**. Making heads mandatory does not change which category; it changes
  how many people have one. (c)
- **Copy that becomes untrue** the day the head is required:
  - `PrivacyPolicyText.swift:13` "if you add them, your name, a profile photo
    and a head"
  - `:35` "If you make a head ... Your head appears only where you turn it
    on, and Delete Head removes it."
  - `:36` "a smaller copy of your head goes to the crew while it shows
    anywhere" (the `isSomewhere` rule, which goes)
  - `:47`, `:63`, `:66` mention the profile photo
  - `NSCameraUsageDescription` in `Strata.xcodeproj/project.pbxproj` (both
    configurations): "and to make your head if you choose to." CLAUDE.md
    already asks that both built Info.plists be re-read.
  - `docs/privacy.html` mirrors the in-app policy.
- **Delete must stay.** A person can always remove the picture of their face.
  Deleting returns them to the placeholder and the catch-up ask (§4.4), not to
  a locked app. (c)

### 3.3 Under 16

- Today: 13 to 15, and anyone who declined to say, **never send a head**
  (`CrewAge.swift:66-68`; `SocialStore.swift:838-845`, "a head is cut out of
  a photograph of you"). The privacy policy promises it
  (`PrivacyPolicyText.swift:63`: "your photos, profile photo and head are
  never sent"). **So yes, a head is a "photo" under that rule today**, by code,
  by comment and by published promise.
- Age is asked the first time Crews opens, not in onboarding. So making the
  head in onboarding is the same for everyone; the age rule only decides
  whether it leaves the phone. (c)
- **What a 13 to 15 year old sees of themselves**: their own head everywhere
  on their own phone, including in their crews (`CrewFaces.swift:23` returns
  your own head without the age check). Their friends see the placeholder.
  This is honest and safe, and it is the recommendation for now. (c)
- **What a 13 to 15 year old sees of friends**: with Sensitive Content
  analysis off on their phone, every friend's head is withheld
  (`CrewSafety.swift:145-148`), so the crew tower is all placeholders. With
  it on, heads that pass the check show. (b, code) Whether Communication
  Safety is on by default for 13 to 17 on iOS 26 was not verified. (c)
- COPPA covers images of a child's face under 13, and the 2025 amendments add
  facial biometric identifiers; it does not reach 13 to 15. (b)
  https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-finalizes-changes-childrens-privacy-rule-limiting-companies-ability-monetize-kids-data .
  The app's 13 to 15 rule is stricter than the law by choice. (c)
- A photo-cut head is not privacy-neutral the way a built avatar is (Roblox,
  for instance, keeps teen identity avatar-only and allows no image exchange
  in chat (b) https://about.roblox.com/safety-faqs). **The future fix for teens
  is customization itself**: a head that is drawn or built rather than cut
  from a photo could travel under 16. That is a later pass and the owner's
  call. (c)

### 3.4 Friends who have no head yet

- Everyone who joined before the change, everyone who skips through a camera
  failure, everyone under 16, and anyone whose head the check held back.
- Today they float as a `CrewFace` disc: photo, or initial on a colour.
- After the change: **the placeholder head** (§4.2), in the same place and the
  same size a head would be, alive enough to walk the crew tower, never a
  photograph. A friend on an older build that still sends `member.photo` is
  drawn as the placeholder too, so there is one rule. (c)
- Mixed builds are safe: the Member record keeps its `head` and `photo` asset
  fields (`CrewRecords.swift:265-266`); new builds stop writing `photo` and
  stop drawing it. Old builds keep drawing a new build's head, or its initial
  when there is none. (c)

---

## 4. Proposal

### 4.1 One identity component: `PersonHead`

```swift
/// Who is drawn. The only way any screen asks for a person.
enum HeadPerson: Hashable {
    case me
    case member(CrewMember, in: CrewID)
}

struct PersonHead: View {
    let person: HeadPerson
    /// The frame's side. The head inside is sized by `setting`, never by the
    /// caller, so a head in a circle is one share of it everywhere.
    let side: CGFloat
    var life: Life = .calm          // .still | .calm | .expressive
    var setting: Setting = .disc(.onPage)
    var take: HeadTake.Played? = nil

    enum Life { case still, calm, expressive }
    enum Setting {
        case disc(Ground)   // a head on a circle: rows, chat, reactions, Profile, crest
        case free           // no disc, nothing under it: crew tower floating, bubble, sticker
        case standing       // free, plus the contact shadow: map, your tower
    }
    enum Ground { case onPage, overPhoto, onGlass }
}
```

Behind it, one resolver, `HeadIdentity` (a `@MainActor` enum or the existing
`CrewHeads` grown into it), answers two questions and owns every rule that is
scattered today:

1. **`rig(for:) -> HeadRig?`** Your identity head; or a friend's unpacked pack
   (`CrewHeads.rig`), after the photo check (`photoIsShown`), the block list
   and the incoming policy. No `isProfilePicture`, no `isSomewhere`, no
   `member.photo`.
2. **`dress(for:) -> HeadDress`** What the head is wearing: today only the
   film look, and only for `.me`; later every customization, for everyone,
   read from the pack (§4.6).

`life` maps to what exists: `.still` is `HeadStill`, `.calm` and
`.expressive` are `LivingHeadView`'s two `Liveliness` values. `setting` owns
the share: one named constant for a head in a disc (pick one of today's
0.76 / 0.9 by looking at both side by side, then delete the others) and the
existing `TowerCompanion.side(forCell:)` for free heads. The contact shadow is
only in `.standing`, which keeps CLAUDE.md's rule (no shadow unless it is
standing on something) in one place.

`ProfileAvatar`, `ProfileButton`'s label, `CrestFace` and `CrewFace` become
thin wrappers or go. `CrewFaces` (the crew's cluster) stays as a layout and
draws `PersonHead` for each slot.

### 4.2 What it draws when there is no head

A **placeholder head**, not a photo and not an initial in a circle, on the
Snap Map precedent (§2.4):

- The maker's own outline, `HeadOutline` (`HeadMakerView.swift:1073`),
  filled with the person's colour from the palette that `CrewFace.fill`
  already picks by profile id (`CrewFaces.swift:97-104`), so two headless
  friends are still told apart, and the same on every phone.
- No face drawn on it. A blank head is a slot, which is the app's word for
  something not there yet; a drawn face would be a fake person. (c)
- In `.free` and `.standing` it walks the crew tower like a head (the owner's
  "they shouldnt be excluded" holds), with no eyes to animate.
- Owner's call: an initial on it or not (§5).
- The `person.fill` glyph and the initials path in `ProfileAvatar` go.

### 4.3 Every call site that moves

| Today | Becomes |
|---|---|
| `GoalRing.swift:331-343` `CrestFace` (used at `GoalRing.swift:253`, `GoalRingMoment.swift:251`, `YourDaySheet.swift:243`, `OnboardingView.swift:629`) | `PersonHead(.me, setting: .free, life: .calm)` |
| `ProfileAvatar.swift:43-125` (Profile, `ProfileView.swift:310`) | `PersonHead(.me, setting: .disc(.onPage), life: .expressive)` |
| `ProfileAvatar.swift:134-231` `ProfileButton` label (`MemoriesView.swift:751`) | `PersonHead(.me, side: 44, setting: .disc(.onGlass))` inside the existing glass button |
| `CrewFaces.swift:55-105` `CrewFace` (`CrewInfoSheet.swift:366`, `CrewChatSheet.swift:277`, `CrewReactions.swift:181`, `MakeYourHead.swift:25`, and inside `CrewFaces`) | `PersonHead(.member(m, in: crew), life: .still, setting: .disc(.onPage))` |
| `CrewHeadArena.swift:402-404` runner | `PersonHead(..., setting: .free, take: take)` |
| `CrewHeadArena.swift:202-205` bubble, `:701-706` fan | `PersonHead(..., setting: .free)` and `.disc(.onGlass)` |
| `TowerCompanionLayer.swift:614`, `:619`; `CompanionDock.swift:219` | `PersonHead(.me, setting: .standing, take:)` |
| `HeadMarker.swift:41`, `MemoriesMapView.swift:332-337` | `PersonHead(.me, setting: .standing)`; native dot only with no head |
| `HeadSticker.swift:148`, `:359` | `PersonHead(.me, setting: .free)`; the baked still (`:59`) keeps `HeadStill` but takes its dress from the resolver |
| `HeadPickerRow.swift:112`, `HeadLookPicker.swift:69` | Stay `HeadStill` swatches (they show a specific head or look, not a person) |
| `OnboardingView.swift:953` (creator fallback) | The page's own concern; leave |
| `PhotoViewer.swift:583`, `CrewDayView.swift:183` bylines; notifications | No change now. Later candidates: a 20pt `PersonHead(.still)` before a friend's byline; a communication notification with the head as the sender's image. Owner's call |

### 4.4 Required, without a dead end

**The head page in onboarding** (`OnboardingView.swift:949`, step 4):

- No "Not Now" on the page as first seen. One action, "Make My Head".
- The maker gets a second way in, **"Use a Photo"**, through `PhotosPicker`
  (no permission prompt). A chosen photo goes through the same lift and eye
  painting as a capture and gives a one-face head.
- **Camera denied or unavailable** (`HeadMakerView.swift:456-459`): the
  screen offers "Use a Photo" beside "Open Settings". Never only Settings.
- **Face not found, or the lift fails** (`HeadMakerModel.swift:336`, `:411`):
  "Try Again" and "Use a Photo".
- **A way through when both fail.** After a failure or a denial, and only
  then, a quiet "Later" appears on the head page. The person continues with
  the placeholder, and the catch-up asks (below) take over. Without it, a
  reviewer who denies the camera and has no face photos in the simulator
  library is stuck at step 4, which is the 5.1.1(iv) rejection waiting to
  happen. (c)
- Accessibility: the maker already announces its hints
  (`HeadMakerView.swift:140`); the expression steps (blink, smile, brows)
  stay optional inside the capture, as they are, and the photo route asks for
  no expression at all, which covers anyone the sequence does not suit. (c)

**Catch-up, for anyone without a head after onboarding:**

- Existing users on the update, once: a full page over Wins, "Make your
  head", the maker and "Use a Photo", and "Later". Owner's call whether
  existing users may defer (§5).
- The crew details pill (`MakeYourHead.swift`) stays, now the one standing
  ask. A tap on your own placeholder anywhere (crest, Profile, your floating
  placeholder on a crew tower) opens the maker. (c)

**Proposed copy** (held to `docs/voice.md`: spare, no exclamation marks, no
em dashes, nothing that reads as watching):

| Where | Line |
|---|---|
| Head page title (unchanged) | Make your own head |
| Head page line, replacing `OnboardingView.swift:1273` | It's you, in every crew. About fifteen seconds with the front camera. ("see you" was caught by the voice test) |
| Head page, after it is made (replacing `:1276`) | That's you, on your wins and in your crews. |
| Maker, second way in | Use a Photo |
| Maker, camera off | Turn the camera on in Settings, or use a photo of you. |
| Maker, nothing found in a chosen photo | We couldn't find a face in that one. Try another photo. |
| Way through after a failure | Later |
| Catch-up page line | Your crews see this head beside your wins. Make yours. |
| Profile footer with no head (replacing `ProfileView.swift:776-778`) | About fifteen seconds with the front camera, or one photo of you. |
| Camera permission string | Some Wins uses the camera so a win can be a photo, and to make your head. |

Words to keep out of any face-capture line: scan, detect, recognise, track,
analyse, watch, see you, look at you, face data. "Find a face" is the most
technical it should get, and only on a failure.

### 4.5 Toggles and options to remove

| Remove | Where | Migration |
|---|---|---|
| Crew "Heads" switch | `CrewInfoSheet.swift:72-85`; `SocialStore.swift:2207-2221`; `CrewBubble.showsHeads` `CrewHeadArena.swift:159-164`; `CrewTowerView.swift:397`, `:627`, `:637`, `:741` | Clear `crews.headsHidden` once |
| Use as Profile Picture | `ProfileView.swift:613`; menu items `:283-294`; `HeadStore.isProfilePicture`, `headForPicture` | Delete the key |
| Show My Head on the Map | `ProfileView.swift:694`; `showsOnMap`, `headForMap` | Head on the map whenever there is one, per the brief |
| Add My Head to Photos | `ProfileView.swift:705`; `showsCameraSticker`, `headForSticker` | The sticker button is already a per-photo choice; it shows whenever you have a head |
| Choose Photo, Remove Photo, Use Photo or Initials | `ProfileView.swift:285-307`; `ProfileStore.photo`, `setPhotoData`, `removePhoto`, `preparedPhotoData`; `SocialStore.myPhoto` (`:57`, `:813`, `:862`); `CrewMember.photo` drawing (`CrewFaces.swift:77-82`, `:100`) | Stop sending (`photo: nil` on the next `shareMyself`, which takes it back from crews); delete `Profile/photo.jpg` once (owner's call on timing, §5) |
| `isSomewhere` as the crews gate | `HeadStore.swift:395-419`, `:623`; the look picker's gate `ProfileView.swift:647` | `headForCrews` is the head. Your crews see it whenever you have one (16+) |
| Onboarding "Not Now" on first sight | `OnboardingView.swift:1318`, `offersHead` `:1443` | Replaced by the failure-only "Later" (§4.4) |

**Keep:** Background Colour (the colour behind your head; the first
customization there is), Look, Delete, and the crew's own picture (a crew
photo is the crew, not a person; owner, 2026-10-02).

Tests that pin behaviour being removed: `CrewStoreTests.swift:313-321`
(`aMemberWithNoHeadSharesTheirPhotoButNotUnderSixteen`) becomes "no photo is
ever sent for a member"; the under-16 half stays. Per CLAUDE.md's gate rule,
rewrite it with the reason, do not delete it.

### 4.6 Making customization a plug-in, not a rewrite

- **Separate "you" from "a head you made".** `HeadStore` is a roster
  (2026-09-23, "add your friend's head for instance to your tower instead of
  yours"), and the active entry is what your crews receive as you
  (`headForCrews`). Once the head is identity, a friend's face must never be
  sendable as you. Proposal: one `identityID` in the roster (the head made of
  you), used by `.me` everywhere; any other heads are companions for your
  tower only. Owner's call, since design.md row 120 says "One head" and the
  roster UI may already be moot.
- **Carry the dress in the pack.** Add a `dress` field to the pack's manifest
  (`CrewHeadPack`, `HeadStore.Manifest`) holding the look today and future
  items later; the receiver applies it with the same `dress()` code. Then
  "customize once, everyone sees it" holds by construction, and a teen's
  future non-photo head can ride the same field.
- **Every surface goes through `PersonHead`**, so a new hat or outfit is drawn
  in one view and appears on 20 call sites.

### 4.7 Passes, in order

**Pass A: the component, no visible change.** Build `HeadPerson`,
`HeadIdentity`, `PersonHead`, the placeholder. Move every call site in §4.3,
keeping today's sizes as named constants. Screenshot each surface before and
after; they should match except the placeholder.
Risk: `CrewFaces.swift`, `CrewHeadArena.swift`, `CrewChatSheet.swift` and
`CrewTowerView.swift` are live in the other agents' worktrees
(`/tmp/claude-501/overnight/wt-chat`, `wt-wins`); land after them or
coordinate per file. `MainAppView` is at the type-checker's ceiling; its two
touch points (`:1329`, `:1457`) should not need to change because the
wrappers keep their names.

**Pass B: the switches go** (cheap and clearly right, the owner asked in
words). Crew Heads switch, Use as Profile Picture, Map, Photos, the photo
option and `isSomewhere`. Copy changes in Profile. Privacy policy, the
camera string and `docs/privacy.html` in the same commit. Strike the
design.md rows in the table at the top.
Risk: someone who had switched their head off everywhere is sent to their
crews on the update (16+, after the photo check). That is the point, but it
should be said in the TestFlight notes. Someone with only a profile photo
becomes a placeholder until they make a head; pass C is what catches them.

**Pass C: required in onboarding, with the photo route.** "Use a Photo" in
the maker, the failure-only "Later", the catch-up page for existing users.
Verification is device-only: the maker does not run in the simulator
(`profile-and-head-plan.md` §9). Test: camera denied, glasses, low light, a
face turned away, a photo with no face, a photo with two faces, a pet.
Risk: highest of the four. A wrong move here costs sign-ups; read the
TelemetryDeck skip rate first (§2.2).

**Pass D: customization-ready.** Identity vs companion heads in the roster;
the dress field in the pack; the look visible to friends.

**Cheap and clearly right:** A, B (all but the photo-file deletion timing),
the copy, the privacy text, the placeholder.
**Needs the owner:** §5.

---

## 5. The owner's calls

1. **How strict is "a must".** Recommended: no skip on first sight, a "Later"
   only after the camera is refused or making fails. The alternative, no way
   through at all, risks review under 5.1.1(iv) and strands anyone whose
   camera or face the maker cannot handle.
2. **"Use a Photo" as a second way to make a head.** Recommended yes; it is
   what makes "required" defensible. The cost: a photo head is one face that
   does not blink or smile.
3. **Existing users** on the update: a one-time page with "Later", or the
   same rule as new users.
4. **Your own tower's companion** ("Let My Head Onto the Tower"). The brief
   says no head options, but on 2026-10-03 and 2026-10-05 you kept the head
   off the home screen by default. Recommended: keep this one switch, since it
   is about how busy Wins is, not about who you are.
5. **13 to 15**: keep the rule that their head never leaves the phone (their
   friends see a placeholder), as the policy promises. Recommended yes, until
   a non-photo head exists.
6. **The placeholder**: a blank head in their colour, with or without their
   initial on it.
7. **The old profile photo file**: delete it on the update, or when a head is
   made.
8. **One head or a collection**: whether heads of other people stay possible
   at all, and if so only as tower companions, never as you.
