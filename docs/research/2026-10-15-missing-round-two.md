# What is still missing, round two (research, 2026-10-15)

Five areas the earlier docs did not cover: the first minute and the first week,
notifications as product, identity and delight, what HEYTEA and Muse do that
reads premium, and dark mode. Every item at the end was checked against
`docs/screens.md`, tonight's five docs, the 10-13 and 10-14 research, and the
code. Tags: (a) research or Apple documentation, (b) a shipping product,
(c) inference.

## What this does not repeat

Already proposed elsewhere, so left out here: the invited first run, reply
starters, reacting and replying from a notification, cheers on the widget,
fresh start and catch-up, rooting for you, the maker's tower, body doubling,
an iMessage app for towers (`2026-10-15-social-retention.md`); the friend's
head on a chat notification and head stickers in the chat sheet
(`2026-10-15-chat.md`); Wave (`crew-corner-new-feature-2026-10-14.md`);
On This Day, Your Year, Journaling Suggestions, Lock Screen logging
(`concept-and-social.md`); North and its first-week sentence
(`north-and-goals-spec.md`); HEYTEA's site measured (`reference-board.md` 9).

Already built, so also left out (checked in the code):

- A friend's win arrives `.passive` with relevance 0.2; a reaction, a reply,
  a tag and a chat line arrive `.active` (`NotifyShared/CrewAlertLevel.swift`).
  Threads are per crew. The daily reminder has Quick, Regular and Deep actions.
- The push extension words a ping as "Sam: Gym" and **deliberately never
  attaches a photo**, because the app shows a friend's photo only after its
  on-device check (`SomeWinsNotifications/NotificationService.swift`, top
  comment). This doc keeps that rule.
- The Log a Win widget runs `Button(intent:)` in place; a Control Center
  control; Siri phrases; a Focus filter; Spotlight.
- The head reacts to a block landing (`TowerCompanionLayer`), dances at the
  goal, rides photos as a sticker (`HeadSticker.swift`), and has five captured
  faces (`HeadRig.Expression`).
- Chrome is already emoji free: the only emoji in Swift strings are reaction
  sets and debug seeds. That is exactly what HEYTEA GO's redesign did, so it is
  met.
- The app icon is an Icon Composer file (`Strata/AppIcon.icon`), so its dark,
  clear and tinted variants come from one source.

---

## 1. The first 60 seconds and the first week

### What the reference apps do

| Product | First session | First week | Tag |
|---|---|---|---|
| **Apple Journal** | One welcome screen, Continue, then a plus to write. Nothing else is asked | Insights (streak, words, days journaled) and a calendar of dots, once there is something to count | (b) [A12] |
| **Apple Fitness** | Rings are set at pairing | **New Move Record cannot be earned until you have 10 days of data.** Perfect Week runs Monday to Sunday. First Workout awards are dated | (b) [A13] |
| **Apple Invites** | The invite is a photograph from your library, then words on it. Each invite owns a shared album | Guests need no Apple device; the album keeps the event after it ends | (b) [A14] |
| **Snapchat** | After sign up it asks for contacts; skip it and you land in the camera. No tutorial; features are learned from friends | Snap's growth lead: people who start **messaging close friends early** are much more likely to stay daily active | (b) [S1][S2] |
| **Locket** | **The first screen is a preview of the Home Screen widget** with friends' photos in it, and the button is "Set up my Locket". The widget is the product | 20 friends, the widget does the returning | (b) [L1] |
| **BeReal** | You see friends' posts only after you post. "No lurking" | The daily prompt | (a, b) [B1] |
| **Duolingo** | The first lesson runs before any account is asked for | A streak goal is asked right after the first streak starts, and the choice alone improved retention weeks later | (b) [D1][D2] |

### What we do not do

1. **Nobody is told the widget exists.** Locket puts the widget on its first
   screen; we have two widgets and a crew widget and no line in the app that
   mentions any of them (grep: no widget prompt anywhere in `Strata/`). The
   crew widget is the one surface that returns people without a push (c).
2. **The second day is not designed.** Day one ends on the goal and the 7pm
   check-in; day two opens on an empty slot like any other day. The first
   return is the moment the record first exists, and the app does not show it.
   Endowed progress: people given visible progress toward a goal complete it
   more often than people starting from zero with the same distance left
   (a) [R1]. `StrataApp.swift` already uses this idea at first launch, never at
   the first return.
3. **Comparisons arrive before there is anything to compare.** Fitness waits
   10 days before it will call anything a record [A13]. Our win trend and goal
   history can render on day one. A rule: nothing comparative appears until a
   week of days exists (c).
4. **Value before setup, for the onboarding rebuild.** Today's first run asks
   for a name, a head, a reminder time, three permissions and the lock before
   the tower is yours (`screens.md` 1). Duolingo and Journal both reach the
   core act first [D1][A12]. When onboarding is rebuilt (planned last), the
   first win should come before the name and the head. Recorded here as an
   input to the rebuild, not a change now.
5. **Do not copy BeReal's gate.** Seeing friends only after you post is a
   pressure the app has refused, and the BeReal study reports some users found
   the design limiting and even toxic (a) [B1].

---

## 2. Notifications as product

### The levers, and where we stand

| Lever | What it is | Ours |
|---|---|---|
| Interruption level | Passive and Active do not break Focus; Time Sensitive needs a capability and should be truly urgent [A8][A9] | Right. Nothing here is time sensitive, so none should be |
| Relevance score | Orders an app's notifications inside the summary [A9] | Set |
| Thread id | Groups the set, which keeps a summary coherent [A10] | Per crew |
| Apple Intelligence summary | No developer API or opt out. Front-load the concrete fact (a name, a number) in the first five or six words, since tone is dropped and facts survive [A10] | "Sam: Gym" already leads with both. Keep it that way; never open with a warm-up word |
| Rich attachment | An image on the alert | Local path only; the push path leaves the photo out on purpose. Keep |
| Content extension | A custom view when the alert is expanded, with interactive controls since iOS 12 [A7] | **None** |
| Communication notification | A person's avatar on the alert [A9] | Proposed in `2026-10-15-chat.md` |
| Widget push (iOS 26) | `WidgetPushHandler` reloads a widget from APNs [A2][A5] | Needs a server that sends APNs. We have none |
| Live Activity | An event in progress with an end, up to eight hours | Rejected twice for crews; only body doubling's local timer fits |

### The best pattern for a friend's win, for this app

A friend's win is good news that can wait, so it arrives quietly into the list
(built). What is missing is what happens when you look at it:

1. **Expanded, it is the block.** A press on the alert opens a content
   extension that draws the win as its block (colour, size, title) with the
   friend's head standing on it, and the three reactions under it as live
   buttons. A tap reacts there, and the reaction appears on the block. No
   photograph: the extension follows the same rule as the push (c) [A7].
2. **And the Home Screen catches up at the same moment.** The push extension
   already wakes for every crew ping and reads the win's title. It can write
   that one fact into the crew widget's file and ask WidgetKit to reload the
   crew widget, so the widget is current without the app having run. This is
   the server-free stand-in for iOS 26 widget push [A2][A5]. Reloads requested
   while the app is not in the foreground count against a budget of roughly
   40 to 70 a day [A6], which a crew of eight does not reach. It must apply
   the same blocked, removed and muted checks the app does, and stay
   `.privacySensitive()` (compliance doc item 10). Verify on a device that
   `WidgetCenter` reloads from a service extension.

### App Intents and Shortcuts

`LogWinIntent` already takes a Name parameter, so a personal automation
("when my Gym Focus ends, ask what I did") works today. It is undiscovered:
How Some Wins Works could show one recipe. Low value; not ranked (c).

---

## 3. Delight and identity

### What makes the others sticky

- **Bitmoji**: about 70% of Snap's daily users had one (already cited in
  `heads-as-identity-2026-10-14.md`). The part not yet used here is
  **Friendmoji**: stickers with **both** your avatar and a friend's in one
  scene, chosen from the chat with that friend, and inside the iOS Bitmoji
  keyboard in iMessage (b) [S3].
- **Memoji**: your character becomes a sticker pack in the system sticker
  drawer, next to emoji, usable in any thread. Third-party sticker packs sit
  in the same drawer after the Memoji tab (b) [A15].
- **Finch**: 40,294 reviews analysed; people name the bird, call it a
  companion and come back because it is waiting (a, review analysis) [F1].
  **Seasonal events** (an October witch event with outfits and a toad pet)
  give everyone something new each month, with no punishment for a missed
  day [F1][F2]. The cost: a diary study saw support drift into reward chasing
  (a, n small) [F1].

### How our heads go further, with no server

1. **A seasonal look, drawn by Jayden.** One accessory a month (a witch hat in
   October, a scarf in November), on every head everywhere it is drawn:
   tower, crews, widget, stickers. Everyone gets it, nothing is earned, it
   leaves at the month's end. It is the month drawings' idea worn by the
   person. It also gives under-16 placeholder heads something of their own,
   since no photograph is involved (c). It fits his rule of one normalized
   head component for future customization.
2. **Two heads together.** A win that names who you were with (`withPeople`)
   shows both heads side by side on its byline in the photo viewer and on
   that day's strip, and the chat's sticker sheet gets a "together" sticker of
   your head and that friend's. Friendmoji, made from heads the crews already
   sync (b) [S3]. Under 16, the placeholder.
3. **Your head in Messages.** A sticker-pack extension that reads your baked
   faces from the app group. Your head goes into the system sticker drawer
   beside Memoji [A15]. Nothing about a crew leaves; only your own face, which
   you made. It reuses the bake that the chat doc's head stickers need.
   Different from the iMessage app in the retention doc, which carries towers
   and conversation out of the crew; this carries only identity (c).

---

## 4. HEYTEA and Muse: what reads premium, and three moves

### HEYTEA (beyond the site, which `reference-board.md` 9 measured)

- **The app was made quieter.** The HEYTEA GO redesign dropped emojis and
  bright icons for a calmer interface, as part of a Zen, minimalist identity
  (b) [H1]. Our chrome already does this.
- **Limited editions on a rhythm.** Limited drinks arrive about every four to
  six weeks for ten to twenty days, with limited-edition sleeves and
  **numbered cups** (b, marketing analysis, treat figures as approximate) [H2].
- **You draw, they print.** The mini program's DIY cup sticker: after you pick
  a drink you draw or type a design, and the store prints it onto your cup:
  "one cup, one story" (b) [H3].
- **Premium as restraint, not features.** HEYTEA returned to fewer, direct
  stores and fewer, selective collaborations after franchising thinned the
  experience (b) [H1].

### Muse (Meta, launched 2026-09-08)

- **One conversation, no modes.** No model picker, no work or chat switch: one
  main thread, with goals and made things around it (b) [M2][M3].
- **A named, animated companion you choose.** Lenny's reviewer singled out
  the animated avatar ("Slime, the teal dragon") as top-of-craft (b) [M1].
- **Lineage.** The activity feed shows each task's step-by-step lineage, the
  feature the reviewer "immediately wished" other tools had (b) [M1].
- Its launch video's frame craft (inline objects, a grid rippling in) is
  already in `launch-video/storyboard.md`.

### Three transferable moves

1. **The month's edition.** Each month's strip paper is a drawn edition, and
   each strip prints its number on the back ("No. 12"). Editions retire; a
   strip printed in October keeps October forever. Scarcity of a look, never
   of access, and nothing to earn [H2] (c).
2. **The seasonal head look** (section 3, item 1), which is HEYTEA's sleeve
   worn by the person and Finch's event without the economy [H2][F2].
3. **A win's lineage.** Under a win's photo, one line of facts the app already
   has: "Planned Monday · Sam rooting · Done Wednesday · 3 cheers". It turns a
   photo into a small story, the way Muse turns a task into its steps [M1].
   Only facts, only people who acted, nothing about who did not (c).

---

## 5. Light and dark mode

### What Apple says, and what the best apps do

- **Base and elevated.** Dark mode has two background sets: base, dimmer, so
  the interface behind recedes; elevated, brighter, so a sheet or popover in
  front advances. The system switches to elevated automatically for a modal
  sheet (a) [A1].
- **Test with Increase Contrast and Reduce Transparency, each and together.**
  Dark text on dark grounds is where it fails (a) [A1].
- **Soften white inside images.** A content image with a white background
  should be slightly darkened so it does not glow in dark mode (a) [A1].
- **Adjust illustrations for dark**, or details are lost (a) [A1].
- **Dark only is for media.** Photos and Stocks go dark because the media is
  the point (a) [A1]. Our camera is pinned dark; the photo viewer's charcoal
  versus black question is already with him
  (`photo-viewer-photos-app-2026-10-14.md`).
- **iOS 26.1 added Clear and Tinted Liquid Glass.** Tinted raises opacity and
  contrast and applies to third-party glass too, separate from Reduce
  Transparency (b) [A11].
- **Widgets on a tinted or clear Home Screen** are drawn in accented mode:
  content goes white, the background becomes glass or tint. An image without
  `widgetAccentedRenderingMode` turns white or a grey square; Apple advises
  `fullColor` for media and desaturated for decoration (a) [A2][A3].
  Desaturated modes have been reported to break taps (b, forum) [A4].

### What the code shows

- `WarmBackground.top` reads only `userInterfaceStyle`; nothing in the app
  reads `userInterfaceLevel`. It is drawn under 64 call sites, sheets
  included, so **a sheet in dark mode is the same 0.112 as the page under
  it**. The base and elevated step does not exist (c, from the code).
- **No view reads `colorSchemeContrast`.** Increase Contrast changes nothing
  of ours (c).
- **No widget sets `widgetAccentedRenderingMode`.** The Today widget's photos
  (`Shared/TowerWidgetView.swift:48`) and the crew widget's faces
  (`Shared/CrewWidgetView.swift:139`) go flat on a tinted or clear Home
  Screen (c, from [A2][A3]).
- StandBy at night (monochrome red) has never been captured
  (`reference-board.md`, `design.md`).

### Checklist for every screen

1. Light, dark, and dark with Increase Contrast, Reduce Transparency, and
   both together.
2. iOS 26.1 Liquid Glass set to Tinted, in both appearances.
3. A sheet over a page in dark: is the sheet one step brighter.
4. Hairlines and secondary ink at 4.5:1 or more; small text aims for 7:1 [A1].
5. Any image with a white ground (stickers, the strip's paper, drawings on a
   card) a touch darker in dark mode.
6. Ink drawings: the line follows the appearance (built for month drawings);
   check the ones on photographs.
7. Widgets: default, dark, tinted, clear, StandBy at night. Tap every
   control in each.
8. The head: no glow or halo around the cutout on a dark ground.
9. Notifications and the expanded view (if built) in dark.
10. Nothing pure white in dark mode (his rule, `strata-dark-on-dark`): buttons,
    film, map, cards.

---

## 6. Twelve buildable items, ranked

None of these is built or proposed in the docs listed at the top.

| # | What | Why (source) | Effort | Files |
|---|---|---|---|---|
| 1 | **Widgets survive tinted and clear Home Screens**: `widgetAccentedRenderingMode(.fullColor)` on photos and heads; test taps in every mode | Photos and faces go white or grey in accented mode; Apple advises full colour for media [A2][A3][A4] | S | `Shared/TowerWidgetView.swift`, `Shared/CrewWidgetView.swift` |
| 2 | **Sheets lift in dark mode**: `WarmBackground.top` reads `userInterfaceLevel`; elevated is one step brighter | Apple's base and elevated grounds; today a sheet equals its page [A1] | S | `Strata/Views/WarmBackground.swift`, sheets with `presentationBackground` |
| 3 | **Put your crew on your Home Screen**: one tip, once, after the first friend's win arrives, showing your own crew widget live (the view is in `Shared/`) and the three steps | Locket's first screen is the widget; nothing in our app mentions one [L1] | S | `Strata/Views/TipCard.swift`, `Shared/CrewWidgetView.swift`, the Crews list |
| 4 | **The first return**: on the first open of day two, yesterday's tower stands small beside the slot for that visit | Endowed progress [R1]; Snap's early engagement finding [S1] | S | `Strata/Views/MainAppView.swift`, `Strata/Views/MonthTowerView.swift` |
| 5 | **The crew widget wakes with the ping**: the push extension writes the newest win to the widget file and reloads `StrataCrew`, with block, removal and mute checks | Widget push needs a server we do not have; reload budget allows it [A2][A5][A6] | M | `SomeWinsNotifications/NotificationService.swift`, `Strata/Social/CrewWidgetPublisher.swift`, `NotifyShared/` |
| 6 | **Seasonal head look**: one drawn accessory a month on every head, everyone, nothing earned | Finch's events; HEYTEA's limited sleeves [F1][F2][H2] | M | `Strata/Views/PersonHead.swift`, `Strata/Views/LivingHeadView.swift`, `Strata/Models/HeadFraming.swift`, assets |
| 7 | **A friend's win, expanded**: content extension draws the block with their head and three live reactions, no photo | Interactive custom notification UI [A7] | M | new content-extension target, `NotifyShared/`, `Strata/Social/CrewNotifications.swift` (category) |
| 8 | **A win's lineage**: one line of facts under a win's photo | Muse's activity lineage [M1] | S to M | `Strata/Views/PhotoViewer.swift`, `Strata/Models/PlanItem.swift`, crew reactions |
| 9 | **Increase Contrast and Tinted glass pass**: a high-contrast step for inks and hairlines; glass checked under Tinted | No view reads `colorSchemeContrast`; HIG asks for it [A1][A11] | S to M | `Strata/Views/WarmBackground.swift`, `Strata/Models/Typography.swift`, `Strata/Views/GlassIconButton.swift` |
| 10 | **Two heads together**: both heads on a "with" win's byline and strip, and a together sticker | Friendmoji [S3] | M | `Strata/Views/PhotoViewer.swift`, `Strata/Views/PersonHead.swift`, `Strata/Views/Crews/ChatPlus.swift` |
| 11 | **The month's edition, numbered strips**: drawn strip paper per month, "No. 12" on the back | HEYTEA's numbered cups and sleeves [H2] | S | `Strata/Models/PhotoStrip.swift`, `Strata/Models/CrewStrip.swift`, the booth view |
| 12 | **Your head in Messages' sticker drawer**: a sticker-pack extension reading your baked faces | Memoji and third-party packs share the drawer [A15] | M | new Messages extension, `Strata/Models/HeadStore.swift` (export to the app group) |

Not ranked, recorded: win before name and head in the onboarding rebuild
(section 1, item 4); comparisons wait for a week of days (section 1, item 3);
a Shortcuts recipe in How Some Wins Works (section 2).

**For his call:** item 6 and item 11 need his drawings; item 12 adds a target
and a review surface; item 7 adds a target.

---

## Sources

- [A1] Apple HIG, Dark Mode: https://developer.apple.com/design/human-interface-guidelines/dark-mode
- [A2] WWDC25 278, What's new in widgets (accented rendering, push updates): https://developer.apple.com/videos/play/wwdc2025/278/
- [A3] Apple Developer Forums, Transparency mode and images in widgets under iOS 26: https://developer.apple.com/forums/thread/800783
- [A4] Apple Developer Forums, widget link broken by desaturated mode: https://developer.apple.com/forums/thread/763804
- [A5] WidgetKit, WidgetPushHandler (iOS 26): https://developer.apple.com/documentation/widgetkit/widgetpushhandler
- [A6] WidgetKit, Keeping a widget up to date (budget): https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- [A7] UserNotificationsUI, Customizing the appearance of notifications: https://developer.apple.com/documentation/usernotificationsui/customizing-the-appearance-of-notifications
- [A8] Apple HIG, Managing notifications: https://developer.apple.com/design/human-interface-guidelines/managing-notifications
- [A9] WWDC21 10091, Send communication and Time Sensitive notifications: https://developer.apple.com/videos/play/wwdc2021/10091/
- [A10] Pushwoosh, iOS 27 notification changes and push copy (2026-09-08): https://www.pushwoosh.com/blog/ios-27-notification-changes-push-copy/
- [A11] 9to5Mac, iOS 26.1 beta 4 Liquid Glass Clear and Tinted: https://9to5mac.com/2025/10/20/ios-26-1-beta-4-adds-new-setting-to-tone-down-liquid-glass-transparency/
- [A12] 9to5Mac, Journal in iOS 18: https://9to5mac.com/2024/09/19/ios-18-brings-much-needed-features-to-journal-app/ ; Cult of Mac, first launch: https://www.cultofmac.com/how-to/how-to-start-journaling-with-apple-iphone-journal-app
- [A13] Macworld, Apple Watch Activity awards: https://www.macworld.com/article/672553/how-to-get-every-apple-watch-activity-achievement-badge.html
- [A14] Six Colors, Apple's Invites: https://sixcolors.com/link/2025/02/apples-invites-invites-you-to-send-invitations/ ; AlternativeTo: https://alternativeto.net/news/2025/2/apple-launches-invites-a-new-event-planning-app-with-management-tools-and-shared-albums/
- [A15] 9to5Mac, stickers in iOS 17 Messages: https://9to5mac.com/2023/08/01/how-to-make-use-iphone-messages-stickers-ios-17/
- [S1] Snap Investor Day 2023: https://newsroom.snap.com/investor-day-2023
- [S2] Leanplum, Snapchat onboarding walkthrough: https://www.leanplum.com/?p=9818
- [S3] Digital Trends, Friendmoji: https://www.digitaltrends.com/?p=1386005
- [L1] Lazyweb, Locket onboarding flow: https://lazyweb.com/canvas/flows/locket/onboarding
- [B1] "Sharing, Not Showing Off", BeReal's design (CSCW): https://arxiv.org/html/2408.02883v3
- [D1] Appcues, Duolingo onboarding: https://goodux.appcues.com/blog/duolingo-user-onboarding
- [D2] Lazyweb, Duolingo retention experiments (secondary, from a public thread): https://lazyweb.com/research/duolingo-retention-experiments
- [F1] Appbot, Finch reviews and attachment: https://appbot.co/blog/finch-app-reviews-emotional-attachment-user-retention-product-loyalty/
- [F2] FoxData, Finch as Editors' Choice (seasonal events): https://foxdata.com/en/blogs/finch-as-app-store-editors-choice-a-self-care-companion/
- [H1] China Skinny, HEYTEA's return to premium: https://chinaskinny.com/blog/heytea-china-premiumization-lessons
- [H2] Latterly, HEYTEA marketing strategy (secondary; figures approximate): https://www.latterly.org/heytea-marketing-strategy/
- [H3] CIPLawyer, HEYTEA's hand-drawn custom cup sticker: https://www.ciplawyer.com/articles/158012.html
- [M1] Lenny's Newsletter, Muse review: https://www.lennysnewsletter.com/p/muse-review-the-personal-ai-agent
- [M2] ExplainX, three design choices behind Muse: https://explainx.ai/blog/what-meta-got-right-with-muse-one-chat-ad-funded-tokens-personality-2026
- [M3] TechRepublic, Meta launches Muse: https://www.techrepublic.com/article/news-meta-muse-ai-agent-us-launch/
- [R1] Nunes and Drèze, "The Endowed Progress Effect", Journal of Consumer Research 32(4), 2006: https://doi.org/10.1086/500480
