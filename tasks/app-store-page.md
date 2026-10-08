# App Store page: preview video, screenshots, privacy label, review notes, age rating

Drafted 2026-10-06 for build 82. **Nothing here is live and nothing was
submitted.** App Store Connect is the owner's to edit. Copy for the page follows
the voice rules: plain, calm, no exclamation marks, no long dashes, no words
that read as surveillance, never name who has not posted, ADHD as the design
target and never as a treatment claim.

Read with: `tasks/app-store-metadata.md` (name, subtitle, keywords, description),
`docs/aso-plan.md`, `docs/crews-app-store-privacy.md`, `docs/monetization.md`.

---

## 0. Decide these before anything is captured

These came out of checking the existing drafts against the code. Each one would
make the page say something the app does not do (guidelines 2.3.1 and 2.3.3).

1. **Crews are dark in an App Store build.** `CrewsFlag.isOn` is true only for a
   launch flag or a TestFlight install (`sandboxReceipt`). If 1.0 ships with
   crews off, the crew screenshots, the preview's friend shot, the CREWS
   paragraph of the description and the Social Networking category all have to
   go. If crews ship on, `CrewsFlag` has to change in the release. Pick one
   before capture.
   **Decided 2026-10-07 by the owner: crews ship ON in 1.0.** `CrewsFlag` still
   has to change for the release, after the capabilities and CloudKit setup in
   `tasks/active.md` (Crews) are done; until then an App Store build hides them.
2. **"Up to 8 friends" is one too many.** `CrewCaps.members = 8` counts the
   person who started the crew. Say "up to 8 people" (the privacy policy
   already does). Affects the description and caption 5 in
   `tasks/app-store-metadata.md`. **Fixed 2026-10-07** in the description.
3. **"Reply with a short line only they see" is no longer true.** Since
   2026-10-05 a reply posts into the crew's day chat, quoting the win, where the
   crew can read it. The description sentence needs rewording, for example:
   "React to a friend's win, or say something in the day's chat." **Fixed
   2026-10-07.**
4. **"A year ago today" is no longer a screen.** The in-app line was removed on
   2026-10-06 (`4caef11`); only the evening Past Wins notification remains. A
   screenshot of it would show a notification, not the app in use. Dropped from
   the set below.
5. **Crew count.** Code caps crews at 5 (`CrewCaps.crews`); the Plus plan says 3
   free and more with Plus. Keep any number out of captions until the gate is
   built.
6. **Plus is not gated and has no paywall yet** (`PlusStore` only). Do not show
   or mention Plus on the page until the paywall ships in the same build. See
   section 5.4.

---

## 1. The preview video: "the magic moment"

### Specs (App Store Connect, iPhone 6.9")

| | |
|---|---|
| Resolution | **886 x 1920** portrait (1920 x 886 landscape). Upload the portrait one. |
| Length | **15 to 30 seconds.** This cut runs about 22 s. |
| Frame rate | 30 fps max. |
| Format | H.264 or ProRes 422 (HQ), `.mov`, `.m4v` or `.mp4`, up to 500 MB. |
| Audio | Stereo AAC, 256 kbps, 44.1 or 48 kHz. Include a track even if it is quiet; the app's own drop and landing sounds are the best audio there is. |
| Frames | **No device frame, no hands, no outside footage.** Screen capture of the app only (2.3.4). Captions laid over the capture are allowed. |
| Poster frame | Pick a frame where the tower has photo blocks and a reaction is visible (about 2.8 s in). It is what most people see, because previews autoplay muted. |
| Count | Up to 3 previews per size. One is enough. Upload at 6.9"; App Store Connect scales it down for smaller iPhones. |

Convert a capture to spec (ffmpeg, if installed):

    ffmpeg -i capture.mov -f lavfi -i anullsrc=r=44100:cl=stereo \
      -vf "scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,fps=30" \
      -map 0:v -map 0:a? -map 1:a -shortest \
      -c:v libx264 -profile:v high -pix_fmt yuv420p -b:v 12M \
      -c:a aac -b:a 256k -ar 44100 preview-6.9.mp4

(Drop the `anullsrc` input and its `-map` if the capture already has sound you
want.)

### Where to capture

- **The camera shot needs a real iPhone.** The simulator has no camera. Run a
  Debug build from Xcode on the phone, put the launch arguments in the scheme
  (Product > Scheme > Edit Scheme > Run > Arguments), and record with QuickTime
  Player > File > New Movie Recording > choose the iPhone as the camera. Best on
  a 6.9" phone (Pro Max), so nothing is upscaled.
- **Every other shot can come from the simulator** on an iPhone 17 Pro Max (or
  16 Pro Max), recorded with
  `xcrun simctl io booted recordVideo --codec=h264 --force shot.mov`.
  Start recording BEFORE the launch: the drops start on their own and finish
  fast (CLAUDE.md, "Start the capture BEFORE the thing").
- Clean status bar in the simulator:
  `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`
- Skip onboarding: `xcrun simctl spawn booted defaults write JaydenBetts.Strata hasOnboarded -bool YES`
- **Give every flag a value** (`DebugHarness.argument` reads the next token).
  A flag with no value at the end of the line silently does nothing.
- **Allow about 16 s after launch** before the take you keep, or you will film
  the loading skeleton.
- Real photographs: seeded wins use gradient fixtures. For the hero shots add
  the owner's own photos (`xcrun simctl addmedia booted ~/Pictures/wins/*.jpg`)
  and log a few wins by hand in the simulator with today's photos strip. The
  crew seed and the sample replays already use the bundled `DemoPhoto` images.

### Storyboard (about 22 s)

The first 3 seconds carry the whole app with no words needed: a photo is
taken, it drops onto the tower as a block, a friend reacts. Captions are 4
words or fewer and sit in the top third, clear of the tower.

| # | Time | Shot | Caption | How to capture |
|---|---|---|---|---|
| 1 | 0.0 to 1.0 | Camera tab, a real moment (a made bed, a plant watered, a run's shoes). Shutter pressed. | none | **Real iPhone**, Debug build. Scheme args: `-strataStartTab camera -strataCrews 1 -strataSeedCrew 5 -strataSeedHistory 20`. Tap the shutter by hand. |
| 2 | 1.0 to 2.2 | Hard cut to the Wins tab: the new photo block falls from off screen and lands on today's tower. Landing sound. | none | Same take: Use Photo, Add. The fall and landing are the app's own. Keep the crew ticked so the win goes to the crew. |
| 3 | 2.2 to 3.0 | The crew tower: the same block is there, and a heart lands on it. | none | Same phone, open the crew. Strongest true version: a second TestFlight phone in the crew double-taps the win. Harness version: add `-strataCrewHeartEvery 4` (this hearts a friend's block from your side, so frame it as a friend's block). |
| 4 | 3.0 to 6.0 | Wins tab, a fuller tower of photo blocks. Tap the empty slot at the top: a block drops. | **One tap. It counts.** | Simulator: `-strataStartTab tower -strataSeedHistory 30 -strataSeedTodayPhotos 1 -strataAutoWin 2`. Record from launch; `-strataAutoWin` presses the slot every 2 s. |
| 5 | 6.0 to 9.0 | Add Win: drag a bigger block out of the slot, then pick one of today's photos from the strip beside it. | **Bigger thing, bigger block** | Simulator, by hand: grant photos first (`xcrun simctl privacy booted grant photos JaydenBetts.Strata`), launch with `-strataTodaysPhotos all` so the added photos count as today's. Drag from the slot, press a photo tile. |
| 6 | 9.0 to 12.5 | A crew tower with friends' blocks; a new one drops in; hold a block and the reactions open. | **Friends, one tower** | `-strataCrews 1 -strataSeedCrew 5 -strataSeedCrewWins 8 -strataOpenCrew 0 -strataCrewDropEvery 3 -strataCrewHold 1` |
| 7 | 12.5 to 15.5 | The day's journal: the row of the day's photos above the note; press one and a question about that win appears. | **Photos start the journal** | `-strataStartTab tower -strataSeedHistory 30 -strataSeedTodayPhotos 1 -strataOpenJournal today -strataDayTab journal`. Press a photo by hand. Suggest needs Apple Intelligence for the model's question; without it the plain question still appears. |
| 8 | 15.5 to 18.5 | Memories: the month calendar, days with blocks, empty days left plain. | **Empty days are fine** | `-strataStartTab memories -strataSeedHistory 45` |
| 9 | 18.5 to 22.0 | A weekly replay: every win of the week drops into one tower. End on the full tower, then the app name. | **Your week, kept** | `-strataOpenReplay sampleWeek` (bundled demo photos). End card: app icon and "Some Wins" on the app's warm background, no slogan. |

Rules for the cut: no fades longer than 0.3 s (the drop is the transition), no
music that fights the landing sound, no text over the falling block. Never show
a friend's name next to anything that says who has not posted.

---

## 2. Screenshots (6.9", up to 10)

**Size:** 1320 x 2868 portrait (iPhone 17 Pro Max / 16 Pro Max simulator gives
this natively; 1290 x 2796 is also accepted). PNG or JPEG, no transparency.
Upload 6.9" only; App Store Connect scales it for smaller phones.

**Layout:** caption band at the top on the app's warm background, the full
screen capture below it, no device frame (consistent with the preview).
Headline in the app's type at one weight, subline smaller and quieter.

**Common setup:** status bar override and `hasOnboarded` as in section 1; wait
16 s after launch; capture with `xcrun simctl io booted screenshot NN.png`.
The first three carry the page (most people never swipe): the tower with photo
blocks, photo to block, a crew tower (`docs/aso-plan.md`).

| # | Headline (5 words max) | Subline (optional) | Screen | How to capture |
|---|---|---|---|---|
| 1 | **One tap. It counts.** | A list of what you did | Wins tab, today's tower of photo blocks with the empty slot on top | `-strataStartTab tower -strataSeedHistory 30 -strataSeedTodayPhotos 1`. Better: the owner's own photos logged by hand (section 1). |
| 2 | **A photo becomes the block** | Optional, always | Add Win holding a photo, today's photos running sideways beside the block | Grant photos, `-strataTodaysPhotos all -strataOpenSheet add`, then press the strip's tile by hand. Fallback without a real photo: `-strataOpenSheet addphoto` (gradient fixture, weaker). |
| 3 | **Friends, one tower** | Up to 8 people. No feed. | A crew tower with friends' photo blocks and heads | `-strataCrews 1 -strataSeedCrew 5 -strataSeedCrewWins 9 -strataOpenCrew 0 -strataSeedMadeHead 1`. Only if crews ship on (section 0.1). |
| 4 | **React, no likes** | A few emoji. No counts. | The reactions a hold on a friend's block opens | Same as 3 plus `-strataCrewHold 1`; capture about 3 s after the crew opens. |
| 5 | **Log without opening it** | Widget, Lock Screen, reminder | Home Screen with the Some Wins widget, or the reminder with Quick, Regular, Deep | Add the widget by hand in the simulator (long-press the Home Screen, +). The reminder's actions need a real phone: Settings > reminder on, wait for it, long-press. Shows the system UI around the app's own widget, which 2.3.3 allows. |
| 6 | **Photos start the journal** | Press one for a question | The day's journal with the photo row above the note | `-strataStartTab tower -strataSeedHistory 30 -strataSeedTodayPhotos 1 -strataSeedJournal 3 -strataOpenJournal today -strataDayTab journal` |
| 7 | **Draw the day** | Hold a stroke to straighten it | A journal sketch on the ink canvas | `-strataStartTab tower -strataOpenJournal today -strataDayTab journal -strataJournalSketch open` (the editor, on a seeded sun over a hill) or `seed` (the sketch under the note). Draw more by hand on a real phone; a simulator stroke looks like a mouse. |
| 8 | **Empty days are fine** | Nothing resets. Nothing nags. | Memories month: blocks on some days, plain on others | `-strataStartTab memories -strataSeedHistory 45` |
| 9 | **Your week, in one tower** | Replays every week and month | A replay's finished tower | `-strataOpenReplay sampleWeek`, capture once the drops end. |
| 10 | **Private by default** | No account. No ads. | Settings, the "Why It Works This Way" page or the privacy section | `-strataOpenSheet settings -strataOpenWhy 1` (pushes Why It Works This Way), or `-strataOpenSheet settings -strataScrollSettings data`. |

Check every capture for: another app's name or icon (share sheet, status bar),
a long dash in any visible string, a friend's name beside "has not posted",
and the word "streak" (the crew stats show a crew streak; keep that screen out).

---

## 3. The 5-second test

**Who:** 5 friends who have not seen the app. Separately, not in a group.
Ideally at least 2 who would call themselves ADHD or easily distracted.

**What to show:** the top of the product page as a phone would show it: icon,
name, subtitle, and the first three screenshots side by side. Mock it as one
image at phone size (a Figma frame or the screenshots in a row under the name
and subtitle). Do not show the preview video; test that separately later.

**Script, word for word:**

> "I am going to show you an app's store page for five seconds. Just look at
> it. I will not explain anything."

Show it. Count five seconds. Hide it. Then ask the single question:

> **"What does this app do?"**

Write down the first sentence they say, verbatim. Do not prompt, nod, or
correct. Thank them; tell them what it is only after all five are done.

**Scoring (0, 1 or 2 per person):**

| Score | Their answer contains |
|---|---|
| 2 | Logging things you already did (wins, small things, a done list) AND either photos or friends. |
| 1 | Only one half: "a photo diary", "a journal", "share stuff with friends", "log your day". |
| 0 | Something else: a to-do list or planner, a habit app, a camera or editing app, a social feed, a game, an ADHD treatment or medical app. |

**What the result means (total out of 10):**

| Result | Change |
|---|---|
| 8 to 10 | Ship the page as it is. |
| Most 0s say **to-do list or planner** | "Done list" is being read as "to-do". Make screenshot 1's subline carry it: "Things you already did". Consider the subtitle "Log what you already did". |
| Most 0s say **camera or photo app** | The photo is reading as the product. Swap screenshots 1 and 3 order so the tower with mixed blocks (some without photos) leads, and the crew is second. |
| Most 0s say **habit app** | The tower is reading as a scoreboard. Remove the win count from screenshot 1's header in the capture, or pick a tower with fewer blocks. |
| Most 0s say **social app / feed** | Crews are reading as the product. Move the crew screenshot to 4. |
| Anyone says **medical / treatment** | The ADHD word is carrying too much. Keep it in the subtitle only, never in screenshot captions. |
| 1s mostly "photo diary" | Close. Screenshot 1's headline is not landing; try "Log what went right". |

Re-run with 5 new people after any change. Never reuse a tester: the second
look is not a first impression.

---

## 4. App Privacy ("nutrition label")

### What was checked in the code

- **No third-party code.** `project.pbxproj` has zero Swift package references,
  there is no `Package.resolved`, and every `import` across `Strata`,
  `StrataWidget`, `SomeWinsNotifications`, `NotifyShared`, `Shared` is an Apple
  framework.
- **No networking of its own.** No `URLSession`, `URLRequest`, `WKWebView`,
  `SFSafariViewController` or `NWConnection` anywhere in the app, widget or
  extension sources.
- **What does leave the phone, all through Apple:**
  - SwiftData mirrors wins and the journal to the user's **private** iCloud
    database (`SharedModelContainer`, `cloudKitDatabase: .private(...)`). The
    developer cannot read a user's private database.
  - Crews: one zone in the starter's private database, shared by `CKShare`
    (`publicPermission = .none`, invite to specified recipients only).
  - Pings: a short public `Ping` record per win or reaction (scrambled tags,
    a random id, a kind), deleted by the sender after about ten minutes.
  - **Reports**: a `Report` record in the **public** database that only the
    developer can read. This is the one thing collected.
  - Push tokens go to Apple (APNs), never to the developer.
  - `PlaceNames` asks Apple (`CLGeocoder`) what a coordinate is called, in real
    time, not retained. MapKit draws the map. StoreKit handles purchases.
  - Suggest uses on-device Foundation Models; nothing is sent.
  - Blocks and mutes sync through the user's own iCloud key-value store.

### The answers

**Do you or your third-party partners collect data from this app?** Yes.
(Only because of reports.)

| Data type | Collected? | Linked | Tracking | Purpose | Why |
|---|---|---|---|---|---|
| **Identifiers > User ID** | Yes | Yes | No | App Functionality | A report carries the random profile ids of the reporter and the reported person, and the reporting iCloud account's CloudKit id, so the account can be banned. Pings use one-way tags of the same ids. |
| **User Content > Photos or Videos** | **Yes (new)** | Yes | No | App Functionality | `CrewSafety.report` attaches the reported thing's picture as a `CKAsset`: a win's photo, a person's photo, a crew picture, or a doodle. **The privacy manifest says "No photo" and does not declare this; it is out of date.** Fix `PrivacyInfo.xcprivacy` and App Store Connect together. |
| **User Content > Other User Content** | Yes | Yes | No | App Functionality | The reported win's title, or the reported chat line's text, and the reason picked from a fixed list. |
| **Contact Info > Name** | **Owner's call, recommended Yes** | Yes | No | App Functionality | A report on a person or a crew writes their first name or the crew's name into the title ("Person: Sam"). It is the reported person's name, readable by the developer. Declaring it is the cautious reading. |
| Location | No | | | | Coordinates are stored beside the photo on the device and never sent; a crew copy has no place. The place-name lookup is a real-time Apple request, not retained. |
| Contacts | No | | | | Invites go through the system share sheet; contacts never pass through the app. |
| Health and Fitness | No | | | | No HealthKit code. ADHD is the design target, not data the app holds. |
| **Usage Data > Product Interaction** | **Yes (2026-10-08)** | No | No | Analytics | Anonymous usage counts to TelemetryDeck (`Analytics.swift`): which features are used, never content. Off in Settings, Share Anonymous Usage. Diagnostics stays No: no crash SDK. |
| **Purchases > Purchase History** | **Yes (2026-10-08)** | No | No | Analytics | A `tip_purchased` count with its tier, nothing else. The purchase itself is Apple's. |
| **Identifiers > Device ID** | **Yes (2026-10-08)** | No | No | Analytics | A random install id, hashed, for TelemetryDeck's counts. Not the advertising or vendor id. |
| User Content (photos, names, journal) shared within a crew | No | | | | It lives in users' own iCloud, shared by Apple, and the developer cannot read it (Apple's definition of "collect" is "transmitting data off the device in a way that allows you ... to access it"). Reasoning in `docs/crews-app-store-privacy.md` and the manifest comments. |

**Tracking:** No. No ATT prompt, `NSPrivacyTracking` false, no tracking
domains.

**Expected label:** Data Linked to You: Identifiers, User Content (and Contact
Info if Name is declared). Nothing under Data Used to Track You.

**Must agree on the same day:** `Strata/PrivacyInfo.xcprivacy`, this label,
`docs/privacy.html` (which already says a report carries the photo) and
`PrivacyPolicyView`. The policy URL in App Store Connect must open the current
page on a phone.

---

## 5. App Review notes

Paste into App Store Connect > the version > App Review Information > Notes.
Keep under 4000 characters. Attach a short screen recording of two phones in a
crew (a link in the notes is fine) because a reviewer cannot be added to a crew
by email.

### 5.1 Notes text

```
Some Wins is a done list: you log small things you already did, each becomes a block on today's tower, and a photo can be the block. Everything runs on the device and in the user's own iCloud. There is no account, no server and no third-party code.

CREWS (testing the social part)
A crew is up to 8 people who share a tower for the day. It runs on iCloud sharing: a crew lives in the private iCloud database of whoever started it, and invitations go only to the people they are sent to.
1. Tap the Crews button at the top right of the Wins tab.
2. Agree to the crew rules, then answer the age prompt (Declared Age Range).
3. Start a crew. You can use it alone: log a win with the crew ticked, react to it, and open the day chat.
4. To see two people, invite a second Apple ID from the share sheet (Messages or Mail) on a second device. A recording of two phones in one crew is here: [link].

SAFEGUARDS (guideline 1.2)
- Rules: crew rules (zero tolerance for hateful, sexual, violent or cruel content) are agreed to before Crews opens.
- Filter: every photo is checked on the device with Apple's Sensitive Content Analysis before it is sent and when it arrives; a flagged photo is not sent or shown. Chat lines pass a words filter on both phones.
- Report: a win (photo viewer menu, Report), a chat message (press and hold, Report), a person (crew details, tap the person, Report), or the crew itself (crew details, Report Crew). Reports go only to the developer and are reviewed within 24 hours; a ban removes the account from every crew.
- Block: crew details, tap the person, Block; also from a chat message. Their wins, head and name disappear from every crew on the blocker's devices. They are not told. Blocked people are listed with Unblock.
- Hide: Hide for Me on a friend's win in the photo viewer. Mute a crew from the crew list.
- The crew's starter can remove any win or person. Chat clears at the crew's midnight.

AGE
Crews ask for an age range through Apple's Declared Age Range, never a birthday. Under 13, Crews do not open. 13 to 15, crews work but photos are never sent and the profile photo is never shared. Declining to answer is treated as 13 to 15 for sending photos.

PERMISSIONS
- Camera: so a win can be a photograph, and to make your head if you choose to.
- Photo library (read): "So a photo you took today can go on a win." Asked only when you press the tile beside the block in Add Win, which shows today's photos in a sideways strip.
- Photo library (add only): Save to Photos and saving a replay video.
- Location when in use: only while the camera is open, so a photo can appear on your map. Stays on the device.
- Face ID: only if you turn on Lock Journal.
- Notifications: asked from Settings when you turn on the daily reminder, Replays or Past Wins, and the first time you start or join a crew. Never at launch. The daily reminder has Quick, Regular and Deep actions (press and hold) that log a win without opening the app. Crew alerts tell you about reactions and replies to your wins; a friend's new win arrives quietly.

CONTACT
jbett5@hotmail.com
```

(Count after editing; the version above is 3,089 characters.)

### 5.2 Why each permission (for the owner, matches the built strings)

| Permission | Built string | When it is asked |
|---|---|---|
| Camera | "Some Wins uses the camera so a win can be a photograph, and to make your head if you choose to." | Camera tab / head maker |
| Photo library (read/write) | "So a photo you took today can go on a win." | Pressing the quiet tile beside the block in Add Win (`TodaysPhotos`) |
| Photo library (add only) | "Some Wins saves your photos and replays to your camera roll." | Save to Photos, Save Video |
| Location when in use | "Photos you take in Some Wins keep the place they were taken, so your wins can appear on your map. It only checks while the camera is open." | First camera use with places on |
| Face ID | "Some Wins uses Face ID to open your journal." | Lock Journal |
| Notifications | (system) | Settings switches; first crew start or join (`CrewNotifications.askOnce`) |

Before submitting, check the BUILT `Info.plist` in Release (CLAUDE.md rule): the
read-write photo key is present because the strip reads the library itself.

### 5.3 Safeguards: where they live in the code

- Report: `CrewSafety.report` (win, person, crew, reply, message); UI in
  `PhotoViewer` (Report, Hide for Me, Remove from Crew), `CrewDayView`
  ("Report this win?"), `CrewChatSheet` ("Report this message?", Block),
  `CrewInfoSheet` (Report Crew, Report / Block / Remove a person, Unblock,
  Mute, Leave or End Crew), `CrewsListView` (Mute, Leave).
- Block: `CrewSafety.block`, synced via the blocker's iCloud key-value store.
- Filters: `CrewSafety.photoIsFine` / `verdict` (Sensitive Content Analysis;
  the entitlement is now in `Strata.entitlements`), `CrewWords` on chat text
  (sender and receiver).
- Rules: `CrewRulesSheet`, "I Agree" before anything in Crews opens.
- Age: `CrewAge`, `CrewsListView` (`requestAgeRange(ageGates: 13, 16)`).

**Before App Store:** turn on the Declared Age Range capability for the App ID.
The code's own comment says TestFlight currently fails the age request because
the capability is not on the app ID yet, and treats testers as adults.

### 5.4 The subscription (guideline 3.1.2(a)), for when the paywall ships

Not yet: `PlusStore` loads and buys products, but nothing is gated and there is
no paywall. **Do not submit the three products until the build that shows
them**; App Review rejects an in-app purchase it cannot find in the app.

When it ships, add to the notes:

```
SOME WINS PLUS
Plus is an optional subscription (yearly with a 7-day free trial, or monthly) or a one-time lifetime purchase. Logging wins, the tower, photos, the camera, the journal, widgets, backup and crews stay free.
Plus gives ongoing value that keeps arriving while subscribed: a new replay of your wins is made every week and every month and can be saved as a video, Your Month is made each month, crews are a live shared service between friends (more crews with Plus), and Suggest offers new questions on the plan and the journal each day.
To find the paywall: [the exact tap path].
```

Also required for an auto-renewing subscription: the paywall shows the title,
length, price per period and the trial terms, with working links to the
Privacy Policy and Terms of Use (EULA); the product page description ends with
a Terms of Use link (Apple's standard EULA is fine). Restore Purchases must be
reachable. Verify each "ongoing value" line against the shipped build: the
monthly drawing claim in `docs/monetization.md` was not verified in this pass.

---

## 6. Age rating questionnaire

Apple's current questionnaire (13+, 16+, 18+ tiers, with in-app controls and
capabilities). Wording may differ slightly; answer by these facts.

| Question | Answer | Reasoning |
|---|---|---|
| Parental Controls | No | The app has none of its own. |
| Age Assurance | **Yes** | Declared Age Range is asked the first time Crews opens; under 13 Crews do not open; 13 to 15 no photos are sent. |
| Unrestricted Web Access | No | No web view, no browser. |
| User-Generated Content | **Yes** | A crew sees titles, photos, doodles and chat lines other people made. |
| Messaging and Chat | **Yes** | The crew day chat (`CrewChatSheet`): text up to 280 characters and doodles, between crew members. **This supersedes "No" in `docs/crews-app-store-privacy.md` section 2**, written before the chat landed on 2026-10-05. Also update the "80 characters" line in `tasks/app-store-metadata.md`. |
| Advertising | No | No ads, no ad SDK (owner ruled out ads, `docs/monetization.md`). |
| Profanity or Crude Humor | None | The app's own words have none. People's words are covered by the UGC answer, with a filter. |
| Horror / Fear Themes | None | |
| Alcohol, Tobacco or Drug Use or References | None | |
| Mature or Suggestive Themes | None | |
| Sexual Content or Nudity / Graphic Sexual Content | None | Not in the app; photos to crews are checked by Sensitive Content Analysis. |
| Cartoon or Fantasy Violence / Realistic Violence / Prolonged Graphic Violence | None | The blocks fall and land; nothing is hurt. |
| Guns or Other Weapons | None | |
| Medical or Treatment Information | None | The app gives no medical information and says it is not a medical app. |
| Health or Wellness Topics | **Yes, infrequent (owner's call)** | "Why It Works This Way" and the product page discuss ADHD research as the design reasoning. Answering Yes is the honest reading; it does not change the 13+ target. |
| Gambling / Simulated Gambling | No / None | |
| Contests | No | |
| Loot Boxes | No | |

**Rating: 13+.** If the calculated rating comes out lower, choose 13+ as the
override (owner's decision, 2026-10-02). Also mark the app as **not Made for
Kids**.
