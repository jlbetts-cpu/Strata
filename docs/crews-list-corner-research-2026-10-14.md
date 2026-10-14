# The Crews list's top-left corner (research, 2026-10-14)

The owner's question, verbatim: "then can you research what to put on the top
left I want to add a feature there that would be useful".

Read-only pass over `~/Developer/Strata` at `545c7f5`. Nothing was built.
Tags: **(a)** research, data or Apple's HIG, **(b)** seen in a shipping
product or its own help pages, **(c)** my inference. Sources at the foot. A
claim about an app's current layout that rests on old or secondhand guides is
marked "unverified".

**A note on the code.** On `main` the top left still holds Invite a Friend
(`person.badge.plus`, `CrewsListView.swift:116-126`). The brief says that
button has just been merged into New Crew in another tree, leaving the corner
empty. This research assumes that merge lands.

## The answer

**Plan**, the `checklist` glass circle, the same glyph and the same corner as
the Plan on Wins. One press opens "Plan with {crew}", the sheet the chat's +
already opens, with a row of your crews to choose from when you have more than
one. Runner-up: **Join**, a `qrcode.viewfinder` circle that scans a friend's
crew code. Everything else on the list below is not worth a permanent spot.

---

## 1. What the Crews list offers, and what is not one tap away

### The screen today (after the merge)

| Place | What it does |
|---|---|
| Top left | **Empty** |
| Middle | "Crews", inline, centred |
| Top right | New Crew (`square.and.pencil`): name, photo, Invite. At five crews, says why not |
| A row | The crew's picture or faces, name, flame from 3 days, muted bell, time, newest thing, ink dot. Press: the crew (into the chat if a line is the news) |
| Hold a row | Mute or Unmute, Leave or End |
| Swipe a row | Leave or End, Mute |
| Pull | Refresh |
| The foot | His drawing of three friends, "For the people you'd tell anyway." |
| Tab bar | Wins, Crews, Camera, Memories (all visible on this screen) |

### What a person might want, across all crews at once

Counted from the code (c). "From the list" means starting on this screen.

| Want | From the list today | Exists? | Worth one tap from here? |
|---|---|---|---|
| **Plan something with a crew** | **4 presses and typing**: row, the rest bar's +, Plan, type, Plan (`ChatRestBar.swift:68`, `ChatPlus.swift` `GroupPlanSheet`) | Yes, one crew at a time | **Yes**: the app's one feature that makes friends come back to the same thing tomorrow, and planning is the owner's own "one press or it will not happen" case (`MainAppView.swift:1614-1617`) |
| Join a friend's crew from their code | 0 in the app: the system Camera reads the code and opens the link | Show a Code is in each crew's card (`CrewCode.swift`); nothing in the app scans | Maybe: rare, in person, and Camera already works |
| A photo win to crews | 1: the Camera tab, then the crew ticks | Yes | No, the tab bar is right there |
| Today across all crews (a combined tower or feed) | 1 per crew | No | No (below) |
| Everyone's heads in one place | 1 per crew (faces on the row, heads in the crew) | No | No (below) |
| Your crew streaks | 0: the flame is on each row from 3 days | Yes | No |
| An album or calendar across crews | Memories tab, "Shared with X" albums | Yes | No: albums are Memories' subject, and the owner wants one album, not two (2026-10-13) |
| Mute all, quiet hours | Hold or swipe each row; iOS Focus covers the rest | Per crew | No |
| Your own code to give someone | A code is a crew's link and carries its key (`CrewCode.swift` header). A personal code would need a record to look it up | No, and not cheaply | No |
| Search | Five crews at most | No | No (qol research: different on purpose) |
| Edit, reorder, pin | Sorted newest first at his pick (2026-10-13); five at most | No | No |
| Notification settings | Each crew's card; iOS Settings | Yes | No |
| Your head or profile | Memories, by his call: "Profile lives on Memories only" (`MainAppView.swift:1626-1629`) | Yes | No |

---

## 2. What shipping apps put top left on a list of chats, groups or friends

| Product | Top left | Top right | Tag |
|---|---|---|---|
| **Messages** (iOS 18) | **Edit** (Select, Edit Pins, Show Contact Photos) [M1] | Compose | (b). iOS 26: a new **Filters** button sits top right [M2][M3]; whether Edit stayed top left in 26 is unverified |
| **WhatsApp** (iOS) | A menu with list management; chat-list filters and an Edit inside them [W1] | Camera and New Chat | (b), position of the menu unverified; the camera shortcut moved several times [W2] |
| **Instagram** DMs | Back to the feed and your account name (account switch) | New message | (b, weak) [I1][I2]; current build unverified |
| **Snapchat** chat | **Your profile (Bitmoji) and Search** [S1][S2] | Add Friends | (b) |
| **Discord** (Dec 2023) | The **server list** is a rail down the left; profile, friends and settings moved to a **You** tab [D1][D2] | | (b) |
| **BeReal** | **Friends** (a person with a plus): search, invite, contacts, requests [B1][B2] | Your profile | (b) |
| **Locket** | No source found for the corner | | unverified [L1] |
| **Retro** | No source; friend list private by design [R1] | | (b) for privacy, layout unverified |
| **Find My**, People | Bottom tab; **+** opens Share My Location [F1] | | (b) |
| **Strava** clubs | Explore, then Clubs, then "Find a club"; club creation was web-only per older guides [K1] | | (b, old) |
| **GroupMe** | Your profile photo (desktop guide); New Chat in the Chats tab [G1][G2] | | (b, weak); iPhone corner unverified |
| **Partiful** | Profile is a bottom tab, not a corner [P1] | | (b, a design critique) |

### What the pattern says

1. **The leading corner of a list is "you" or "your list's housekeeping".**
   Snapchat and GroupMe put your profile there; Messages and WhatsApp put
   Edit or a list menu (b). Here, "you" lives on Memories by the owner's
   call, and housekeeping has nothing to do with five crews in activity order
   (c).
2. **"Friends" earns the corner where friends are a list you manage** (BeReal
   [B1], Discord's You tab [D2]). Some Wins has no friends list on purpose:
   no counts of people, no contact matching (`invites-research`, section 3)
   (c).
3. **Making something new sits top right everywhere** (Messages compose,
   WhatsApp New Chat, Snapchat Add Friends) (b), which is where New Crew
   already is. So the leading corner should be a second, different verb, not
   a second way to make or invite (c).
4. **The app's own rule is the strongest precedent.** On Wins the top left is
   Plan and the top right is Journal: mine on the left. A Plan in the same
   corner of Crews means one place, one glyph, one word for planning across
   both tabs, which is `docs/ten.md`'s "one word per thing" applied to
   position (c).
5. **Hidden actions are used about half as often.** NN/g: 89% use when
   visible, 44% when hidden (a) [N1]. A crew plan is four presses deep today.
6. **The leading corner is the hardest reach for a right thumb** (Hoober)
   (a) [N2]. Fine for a frequent second action; not for the primary one (c).

---

## 3. The candidates, weighed

| Candidate | For | Against | Verdict |
|---|---|---|---|
| **Plan with a crew** | Four presses to one or two. The feature that brings a crew back to one thing tomorrow (I'm In, the box on the crew's tower, Make a Strip). Same corner, glyph and word as Wins. Reuses `GroupPlanSheet`, `sendPlan`, `plan.join`. No new fields | A press that opens a crew sheet in the corner where Wins opens your own day: someone may expect their own plan. The sheet's title "Plan with Sam" answers it at once (c) | **Recommended** |
| **Join (scan a code)** | Pairs with Show a Code: receive on the list, show in the crew. College students sit beside each other (c). VisionKit's scanner, no new fields | Rare: a few times ever. The system Camera already reads the code in one step. A permanent spot for a once-a-term action | **Runner-up** |
| Today across crews | A real want for someone in three crews | A new screen to design; the rows already show the newest thing. Tempts "who hasn't" (surveillance, streak pressure) | No |
| Everyone's heads | Heads are identity, lovely | Nothing to do there: starting a crew from them needs a sealed delivery path (`invites-research`, C). A page of people is a friends count | No |
| Your head, profile | Snapchat, GroupMe pattern | Profile is Memories' by his call | No |
| Mute all, quiet hours | | Set and forget; iOS Focus does it; every app keeps mute per thread | No |
| Album or calendar across crews | | Memories owns albums; "one album not two" | No |
| Search, Edit, reorder | Messages, WhatsApp pattern | Five crews, sorted by activity | No |
| Notification settings | | Set and forget | No |
| Empty | Subtraction | He asked for a feature; the Wins header puts something in both corners | Only if Plan and Join are both refused |

---

## 4. Recommendation

### Plan

- **Glyph:** `checklist` (`DayIcon.name`), the same glass circle as the
  right-hand button. On iOS 26 a leading `ToolbarItem` with the same
  `.sheetAction(.confirm, as: .glyph)` label as New Crew, so the two corners
  match.
- **Spoken label:** "Plan". Hint: "Plan something with a crew." Title Case,
  no exclamation mark (`docs/voice.md`).
- **One press:** light tap haptic, then the existing `GroupPlanSheet` at
  `.medium`, the field focused.
  - One crew: titled "Plan with {crew name}", exactly as from the chat.
  - Two to five: titled "Plan with", and above the field one row of your
    crews, **one choice**, preselected to the list's top row (the crew with
    the newest activity). The row is `CrewPicker`'s chips in a single-choice
    mode, not a new picker (`ten.md`: one component per job).
  - **Plan** sends `store.sendPlan(title:when:in:)` for that crew and joins
    you (`plan.join`), as `CrewChatSheet.propose` does. The sheet closes and
    the list stays; the crew's row rises to the top and its preview reads
    "You planned Evening walk" once M8's plan preview is in.
  - A refused send: the list's own alert, in `CrewErrorWords`' words, with
    the words kept in the field (the sheet's `title` binding already exists
    for this).
- **Shown** only when the right-hand button is (iOS 26, old enough) and you
  are in at least one crew. On the empty state there is nothing to plan with.
- **Why a permanent spot:** a crew plan is the only thing in Crews that asks
  for tomorrow, and it is four presses deep. The owner's own rule for the
  Wins corner: planning "has to be one press from the tower or it will not
  happen". On Crews, the same press from the list.

**What it must NOT be:**
- a list or calendar of plans, a count ("2 plans"), a badge or a dot;
- your own day's plan (that is Wins' corner) or a "Just Me" choice;
- a multi-select or **All**: one plan per crew, so your own plan never gets
  the same line twice;
- a menu (Plan, Join, Mute);
- anything that says who is in or who has not done it (`GroupPlanCard`'s
  rule: only the people who did it are named);
- "missed", "overdue" or a reminder notification about a plan;
- a word in type, tinted, filled or with a shadow.

**Cheapest good build (c):** no CloudKit field, no SwiftData stored property.
Parts that exist: `GroupPlanSheet`, `SocialStore.sendPlan`, `GroupPlan.join`,
`CrewPicker`. New: the leading toolbar item; a crew `@State` and the
single-choice mode on `CrewPicker`; `GroupPlanSheet` taking an optional chooser
above its field; the crew's day for "today" read from that crew's zone (the
chat uses `today`, the crew's own date: the list must compute it per chosen
crew, `CrewDay.string(for:in:)`). Tests: the one-crew title, the preselection
order, that the plan lands in the chosen crew only, and that you are joined.
It touches crew sync only through the existing `sendPlan`, but still gets the
read-only review this repo asks for any crew change (memory:
crews-public-database).

### Runner-up: Join

`qrcode.viewfinder`, spoken "Join", hint "Scan a friend's crew code." One
press: VisionKit's `DataScannerViewController` for QR only, full screen, Close
top left; a code whose URL is `somewins.xyz/join` goes to `CrewRouter` as a
tapped link would; anything else says "That isn't a Some Wins code." Uses the
camera permission the app already has. No new fields. Not a paste box (reading
the clipboard was turned down as watching), not a code to type (a code cannot
carry the crew's key, `CrewCode.swift`).

### Clearly not worth it

Search, Edit or reorder, Mute All or quiet hours, notification settings, your
head or profile, a streaks page, an album or calendar across crews, a page of
everyone's heads, a combined "today" across crews, and contact discovery.

---

## 5. Questions for the owner

1. **Plan or Join** in the corner? (Recommended: Plan.)
2. **Same glyph as Wins' Plan** (`checklist`, one picture for planning), or a
   different one so the two corners do not read as the same button?
   (Recommended: the same.)
3. **After Plan is pressed**: stay on the list, the row rising with "You
   planned ...", or open that crew so you see the box land on its tower?
   (Recommended: stay.)

---

## Sources

Apps
- [M1] Messages, Edit top left, Edit Pins: https://ios.gadgethacks.com/how-to/pin-unpin-conversations-top-messages-ios-14-0319228/ ; https://www.popsci.com/diy/pin-messages-ios/
- [M2] iOS 26 Messages, filter button top right: https://9to5mac.com/2025/08/18/imessage-gets-a-new-drafts-folder-in-ios-26/
- [M3] Apple Support, Filters in Messages: https://support.apple.com/en-gb/125068
- [W1] WhatsApp iOS chat-list filters and Edit: https://wabetainfo.com/whatsapp-is-rolling-out-a-new-system-to-manage-chat-lists-on-ios/
- [W2] WhatsApp camera shortcut history: https://gulfnews.com/technology/camera-shortcut-for-iphone-users-on-whatsapp-1.1662903058037
- [I1] Instagram DM icon and account switch test: https://beebom.com/instagram-swaps-profile-direct-messaging-icon-positions-for-easier-accessibility/amp/
- [I2] Instagram DM entry points: https://www.socialmediatoday.com/news/instagram-tests-making-the-messaging-icon-the-main-focus-in-the-app/721824/
- [S1] Snapchat universal search at the top: https://www.imore.com/how-use-snapchats-new-universal-search-bar
- [S2] Snapchat search across screens: https://www.pocket-lint.com/apps/news/snapchat/140078-snapchat-adds-universal-search-here-s-how-it-lets-you-quickly-find-friends-and-chat
- [D1] Discord mobile redesign (server rail, Messages, You): https://9to5google.com/2023/12/05/discord-new-app-android-ios/
- [D2] https://androidcentral.com/apps-software/major-discord-mobile-ui-update-rollout
- [B1] BeReal, friends button top left: https://www.androidauthority.com/what-is-bereal-3201044/
- [B2] BeReal help, adding friends: https://help.bereal.com/hc/articles/7537949847069
- [L1] Locket overview: https://maketecheasier.com/locket-minimalist-social-app/
- [R1] Retro, private friend list: https://apps.apple.com/app/id6443709020 ; https://techcrunch.com/2023/07/07/retro-is-a-deeply-personal-photo-journaling-app-for-close-friends/
- [F1] Find My, People and +: https://iphonelife.com/node/277862
- [K1] Strava clubs on mobile (older guides): https://www.pdx.edu/recreation/strava-club ; https://RUNTOGETHER.CO.UK/media/157645/strava-clubs-guide-runtogether.pdf
- [G1] GroupMe, start a group (New Chat in Chats): https://support.microsoft.com/en-gb/office/how-do-i-start-a-group-in-groupme-d7488e15-4429-43ff-85fa-a5c7775305e2
- [G2] GroupMe, profile photo top left (desktop guide): https://cincihomeless.org/wp-content/uploads/2020/07/computer-groupme.pdf
- [P1] Partiful design critique (profile a bottom tab): https://ixd.prattsi.org/2025/02/design-critique-partiful/

Research
- [N1] NN/g, hidden vs visible navigation (89% vs 44%): https://www.nngroup.com/articles/find-navigation-mobile-even-hamburger/
- [N2] Hoober, how people hold phones: https://smashingmagazine.com/2016/09/the-thumb-zone-designing-for-mobile-users

In the repo: `Strata/Views/Crews/CrewsListView.swift`, `ChatPlus.swift`
(`GroupPlanSheet`, `GroupPlanCard`, `GroupPlanActions`), `CrewChatSheet.swift`
(`propose`, 1132-1150), `ChatRestBar.swift`, `CrewPicker.swift`,
`CrewCode.swift`, `MainAppView.swift` (Wins header, 1429-1629),
`SocialStore.swift` (`sendPlan`, `Mute`), `docs/crew-corner-research-2026-10-14.md`,
`docs/qol-research-2026-10-13.md`, `docs/invites-research-2026-10-13.md`,
`docs/voice.md`.
