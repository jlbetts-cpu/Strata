# The crew screen's top-right corner (research, 2026-10-14)

The owner's question: the chat moved into the drawer at the foot
(`ChatRestBar`), so the top right of a crew (`CrewTowerView`) is empty. What
goes there? "I would keep researching this one." He wants invites and
engagement pushed "as much as possible".

Read-only pass over `~/Developer/Strata` at `29de071` (Build 138). Nothing was
built. Tags: **(a)** research, data or Apple's HIG, **(b)** seen in a shipping
product or its own help pages, **(c)** my inference. Sources at the foot. A
claim about an app's current layout that rests only on old guides is marked
"unverified".

## The answer

**Invite**, as a `person.badge.plus` glass circle (`GlassIconButton`), one
press straight to the share sheet with this crew's link. Hidden once the crew
is full, so the corner is empty only when there is nobody left to invite.
Runner-up: **Plan**, the `checklist` circle, opening "Plan with {crew}"
directly.

---

## 1. What the crew screen and its card offer today

### The screen

| Place | What it does |
|---|---|
| Top left, `BackToCrews` | Back to the list; carries the count of other crews with news |
| Middle, the bubble | Empty: the crew's card. Heads parked in it: a tap fans them out; hold: Let Everyone Out |
| Middle, the name capsule | The crew's card (`CrewInfoSheet`) |
| **Top right** | **Empty** since the chat became the drawer (`CrewTowerView.swift:635-640`) |
| Under the header | "Just you so far." tip (once a crew, 12 s, action Invite); crew plan cards waiting for I'm In |
| The tower | Tap a block: viewer. Double tap: heart. Hold: reactions |
| The slot | Tap: a win to this crew. Drag: bigger. Hold: the full Add Win, this crew ticked |
| Planned boxes | Crew plans you are in: photo, library, log, edit, Not Today |
| Foot, `ChatRestBar` | Newest line with the dot, and the field. Tap, drag up or write: the chat |
| Tab bar | **Hidden inside a crew** (line 149), so the Camera tab is out of reach here |

### The card (`CrewInfoSheet`), top to bottom

Top left: the QR code (`qrcode`). Top right: Done. Then: faces, Edit photo,
the name field, Make Your Head (if none); **Today's Strip** (disabled until a
photo or doodle is sent); **Crew Streak**, the win trend bars, **Recent Days**
with Play; **People** with **Invite** at the foot of the list; Notifications
(Mute menu, Reactions to My Wins); Hidden for You; Blocked; Report Crew, End
or Leave Crew.

### Taps from the crew screen (counted from the code, so (c))

| What someone wants | Taps today | Note |
|---|---|---|
| Add a win to this crew | **1** | The slot |
| Read or write today's chat | **1** | The drawer |
| React to or open a friend's win | **1** | Double tap, hold, or tap |
| Say I'm In to a crew plan | **1** | The card under the header |
| Other crews' news | **1** | Back |
| Streak and numbers | **1** | Name, then read |
| Today's strip | **2** | Name, Today's Strip; dead until someone sends a photo |
| Show a QR to a friend beside you | **2** | Name, `qrcode` |
| **Invite someone by link** | **2 and a long scroll** | Name, scroll past identity, strip, streak, trend bars and Recent Days, then Invite at the foot of People |
| **Plan something with the crew** | **4** | Drawer, +, Plan, type, Plan |
| **A photo win to this crew** | **about 5** | Hold the slot, the block's menu, Camera, shutter, Add. The Camera tab is hidden here |
| Mute | **3 and a scroll** | Name, scroll, Mute, a length |
| Rename, new photo | **2** | Name, field or Edit |
| Report, leave | **2 or 3 and a scroll** | At the foot of the card |

**What is not one tap away and is wanted often (c):** inviting (the one the
owner asked to push, and today the deepest common action on the screen),
planning with the crew, and a photo win. Everything else people want often
(add, chat, react, open, back, the card) is already one tap.

The invites research of yesterday counted the same gap: "Invite lives in Crew
Info only", 5 taps from the list to a sent invite for a second crew
(`invites-research-2026-10-13.md`, table "Taps from first launch", and "Where
someone gets stuck" item 3: "A crew of one is a dead end... the Invite two
taps deep in Crew Info").

---

## 2. What group spaces put in the top-right corner

| Product | Top right of the group space | Where invite / add people lives | Tag |
|---|---|---|---|
| **Messages** (iOS 15 to 26) | The **FaceTime** button. The old "i" is gone; the group's name and photo in the middle open the details | Details, reached from the name | (b) [M1][M2][M3]. iOS 26 detail page specifics unverified |
| **WhatsApp** group | **Call** (phone; newer builds a menu for voice or video) | Group info, from the name: Add Participants, **Invite to Group via Link** (with a QR) | (b) [W1][W2][W3] |
| **Instagram** group DM | **Phone and video** icons | Thread details, from the name (c, unverified) | (b) [I1], older guides |
| **Snapchat** group chat | Call and video (current layout unverified; 2016 coverage put them at the foot) | | (b, weak) [S1][S2] |
| **Discord** channel (2023 redesign) | A **members** icon; the channel name opens details (search, threads, notifications, settings) | Server invite, elsewhere | (b) [D1][D2] |
| **BeReal** feed | Profile top right; **Friends (person with a plus) top left** | That top-left button | (b) [B1][B2]. A feed, not a group space |
| **Apple Fitness, Sharing tab** | The **add a friend / account** icon, "Invite a Friend" one step in | That corner | (b) [F1][F2]. The list level, not one friend's page |
| **Apple Photos, shared album** (iOS 18) | **More** (`ellipsis.circle`); the iOS 17 "People" button was folded into it | More, Shared Album details, Add Participants | (b) [P1][P2] |
| **Apple Invites** event | **More** (Duplicate and so on); preview top right while editing | Share link or invite contacts | (b) [V1][V2] |
| **Strava** club | **Settings** | "Share the Club" under the description | (b) [K1][K2] |
| **Partiful** event | A filter top right (inside the guest list) | **Invite** and Copy Link on the event page itself | (b) [T1]. Secondary source |
| **Locket**, **Retro** | No source found for a group-level corner | Invite by text or a personal link; Retro's "keys" | (b) [L1][R1]; layouts unverified |

### What the pattern says

1. **Messaging apps give the corner to the live way of being together, the
   call** (Messages, WhatsApp, Instagram, Snapchat) (b). Some Wins has no
   calls and should not get one for a corner (c).
2. **Apple's own group spaces that are not chats put adding people in the
   corner or one press from it**: Fitness Sharing's top right is "Invite a
   Friend" (b) [F1]; Photos folded People into More (b) [P1].
3. **Nobody duplicates the name.** Where the middle opens details (Messages,
   WhatsApp, Discord), the corner does something else (b). So "the crew's
   card" in the corner would be a third way to the same sheet, after the
   bubble and the pill (c).
4. **Mute is never in the corner.** Messages and WhatsApp keep it in details
   (b) [W1]; this app already does.
5. **Empty on purpose:** none of the products above leaves the trailing
   corner empty (b). The HIG reserves the trailing edge for "important items
   that need to remain available" and says to "Choose items deliberately to
   avoid overcrowding" (a) [H1]. Read together: empty is right only if
   nothing on this screen is that important. Here one thing is, and it is
   buried (section 1).
6. **Hidden actions get used about half as much.** In NN/g's study, people
   used navigation 89% of the time when visible and 44% when hidden (a) [N1].
   Invite at the foot of a card is the hidden case.
7. **Reach.** Top corners are the stretch zone in Hoober's one-handed model
   (a) [N2][N3]. Fine for a frequent but second action; the primary ones
   (the slot, the drawer) already sit low (c).

---

## 3. The options, weighed

| Candidate | For | Against | Verdict |
|---|---|---|---|
| **Invite to this crew** | The owner's stated priority. Deepest common action today (2 taps and a long scroll). Fitness Sharing does exactly this (b). A glyph on glass, not the bare word he rejected under the name. Hides at the cap, so the cap is never advertised | Permanent once a crew is settled at, say, 4; a crew of two from Invite a Friend grows into a group with it (c, his call whether that is fine) | **Recommended** |
| Plan with this crew | His own rule on Wins: planning "has to be one press from the tower or it will not happen" (`MainAppView.swift`, the Plan button's comment). Today 4 taps through the chat | A second way into the chat's + (still a real shortcut); plan cards already float under the header | **Runner-up** |
| A camera, photo win to this crew | Photos make the strip and the best engagement; today about 5 taps, and the Camera tab is hidden in a crew | He removed the top-right "+" as "kinda useless because there is already a + block" (2026-10-05). A camera reads as a second +. Needs a new camera route that sends to one crew | Third |
| Today's strip | Lovely object | Dead half the day (disabled until a photo is sent); 2 taps already; also in the chat's + | No |
| The crew's card | | Already two ways (bubble, pill); nobody duplicates the name (b) | No |
| Mute | | Set and forget; every app keeps it in details (b) | No |
| Empty | Subtraction | The trailing edge is for what must stay available (a); NN/g's halving (a); his priority is invites | Only if Invite is refused |

---

## 4. Recommendation

### Invite

- **Glyph:** `person.badge.plus`, on the 44pt page glass circle
  (`GlassIconButton(systemName:onPage:true)`). The same symbol the card's
  Invite row already draws (`CrewInfoSheet.swift:59`), so one thing has one
  picture.
- **Spoken label:** "Invite". Hint: "Sends a link to join this crew." (Title
  Case, one word per thing, no exclamation mark, per `docs/voice.md` and
  `ten.md` rule 4.)
- **One press:** light tap haptic, then `CrewSharing.invite(crewID)`: the
  system share sheet, with the people you text most on its first row and the
  rich card. Nothing in between. Counted only when sent (that is already how
  `crewInviteSent` fires).
- **Shown** while `crew.members.count < CrewCaps.members`, as the card's row
  and QR are. At eight it leaves and the corner is empty, with no word about
  why.
- **A real object for the heads**: record its frame in `parking.controls`,
  as the back button does, so a head meets it rather than passing through.
- **Optional (c):** pass today's crew tower as the share card
  (`CrewSharing.invite(_:card:)` already takes one), so the invitation shows
  something happening, not just a name.

**What it must NOT be:**
- a word ("Invite" in type), which is what he rejected;
- a menu (Invite, Code, Mute): the code stays in the card's top left, mute in
  Notifications;
- a count or progress ("3 of 8", "Add 2 more"), a badge, a dot, a pulse or a
  shimmer: nothing that counts people or nags;
- a sheet of members or a contact picker in front of the share sheet;
- tinted, filled or with a shadow; it is the same clear glass as Back;
- shown at the cap, or saying the cap exists.

**Leave as is:** the card's Invite row and QR (for someone who went there to
look at People), and the one-time "Just you so far." tip, whose action now
does the same as the corner.

### Runner-up: Plan

`checklist` (the glyph Wins uses for its Plan, and the chat's + uses for
Plan), spoken "Plan", hint "Plan something with this crew." One press opens
the same "Plan with {crew}" sheet the chat's + opens (`CrewChatSheet`
`case .plan: planning = true`), without opening the chat. Not a list of
plans, not the chat, not a calendar.

### Questions for the owner

1. Invite in the corner for **every** crew under eight, including a pair made
   by Invite a Friend (so a pair can grow into a group from there)? Or only
   for crews of three or more?
2. The invitation's preview: today's crew tower, or the crew's name only?

---

## Sources

Apple
- [H1] HIG, Toolbars ("The trailing edge contains important items that need
  to remain available"; "Choose items deliberately to avoid overcrowding"):
  https://developer.apple.com/design/human-interface-guidelines/toolbars
- [M1] Use Group FaceTime (FaceTime button upper right of a group
  conversation): https://support.apple.com/en-us/102415 via
  https://apple.co/2NFmbMN ; Gadget Hacks:
  https://ios.gadgethacks.com/how-to/start-calls-facetimes-from-ios-12s-messages-app-your-iphone-0186594/
- [M2] Apple Community, the "i" replaced, name the group from the top:
  https://discussions.apple.com/thread/255024217
- [M3] iOS 26 group chat changes (Tom's Guide):
  https://www.tomsguide.com/phones/iphones/finally-ios-26-fixes-this-annoying-group-message-problem ;
  MacRumors, Group FaceTime from Messages:
  https://macrumors.com/how-to/use-group-facetime
- [F1] Activity sharing, top-right icon then Invite a Friend (Apple Support,
  via search excerpt): https://support.apple.com/en-us/HT207014 ; iMore:
  https://www.imore.com/how-set-and-use-activity-sharing-apple-watch
- [F2] Nerdschalk, "Add Friend icon at the top right":
  https://nerdschalk.com/share-apple-watch-fitness-data/
- [P1] Shared Albums in Photos (iOS 18: More, Add Participants; iOS 17:
  People button): https://support.apple.com/en-us/108314
- [P2] Apple Community, inviting to a shared album:
  https://discussions.apple.com/thread/255788303
- [V1] Introducing Apple Invites:
  https://www.apple.com/newsroom/2025/02/introducing-apple-invites-a-new-app-that-brings-people-together
- [V2] Apple Invites how-to (three dots top right, Duplicate):
  https://www.aol.com/news/send-free-digital-invitations-iphone-115549487.html

Apps
- [W1] WhatsApp group calls from the top-right icon:
  https://www.fonearena.com/blog/271251/whatsapp-easier-group-calls-iphone-android.html/amp ;
  https://wabetainfo.com/whatsapp-beta-for-ios-23-11-0-76-whats-new/
- [W2] WhatsApp, group name opens info, Invite to Group via Link:
  https://maketecheasier.com/create-whatsapp-group-link/
- [W3] https://chatfuel.com/blog/create-whatsapp-group-link
- [I1] Instagram, phone and video top right (older guides):
  https://rfgcreative.com/misc/how-to-make-calls-on-instagram.html ;
  https://siliconrepublic.com/?p=764177
- [S1] Snapchat group video chat (2018):
  https://www.techadvisor.com/article/731323/how-to-group-video-chat-on-snapchat.html
- [S2] Snapchat Chat 2.0 (icons at the foot, 2016):
  https://pastemagazine.com/tech/snapchat-latest-update-turns-the-messaging-app-int
- [D1] Discord mobile redesign:
  https://techcrunch.com/2023/12/05/discord-app-redesign-mobile
- [D2] Discord community, channel name opens details, members top right:
  https://support.discord.com/hc/ko/community/posts/19660229409175-Mobile-UI-Changes-Are-Bad-A-Compilation-of-Feedback-and-Critisism ;
  https://support.discord.com/hc/articles/12654190110999
- [B1] BeReal, friends button top left: https://www.androidauthority.com/what-is-bereal-3201044/
- [B2] BeReal, profile top right: https://shotkit.com/bereal-ultimate-guide/
- [K1] Strava, Clubs on the Mobile App (settings top right):
  https://support.strava.com/hc/en-us/articles/221622188-Clubs-on-the-Mobile-App
- [K2] Strava, Share the Club:
  https://support.strava.com/hc/en-us/articles/4418607378189-How-to-Get-and-Share-Links-From-Strava
- [T1] Partiful FAQ (Invite on the event page; filter top right; Copy Link),
  via search excerpt: https://getpartiful.com/faq/cm
- [L1] Locket invite link: https://apkmirror.com/apk/locket-labs-inc/locket-widget/locket-widget-1-181-2-release ;
  https://apps.apple.com/us/app/1600525061
- [R1] Retro: https://techcrunch.com/2023/07/07/retro-is-a-deeply-personal-photo-journaling-app-for-close-friends/

Research
- [N1] NN/g, hidden vs visible navigation on mobile (89% vs 44%):
  https://www.nngroup.com/articles/find-navigation-mobile-even-hamburger/
- [N2] Hoober, how people hold phones (Smashing):
  https://smashingmagazine.com/2016/09/the-thumb-zone-designing-for-mobile-users
- [N3] Parachute, thumb zone summary: https://parachutedesign.ca/blog/thumb-zone-ux/

In the repo: `Strata/Views/Crews/CrewTowerView.swift` (header, 629-725),
`CrewInfoSheet.swift`, `ChatRestBar.swift`, `CrewSharing.swift`,
`ChatPlus.swift`, `CrewsListView.swift`, `MainAppView.swift` (Wins header
and the Plan button's comment), `docs/qol-research-2026-10-13.md` section 2,
`docs/invites-research-2026-10-13.md`, `docs/voice.md`.
