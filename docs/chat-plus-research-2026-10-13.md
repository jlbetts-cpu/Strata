# The chat's plus: what it is, what it should be (research, 2026-10-13)

The owner's ask: "the + button in the chat needs like real care done to it
the chat needs to be easy to use and sleek and understandable rn theres a
bunch of options for the + but no real direction or understanding the +
button menu needs to make sense for the chat and all the functions thought
through and research to a t".

Research and a proposal. Nothing here is built.

**Tags.** (a) published research, Apple's HIG or guidelines. (b) seen in a
shipping product, with the source. (c) my inference; "unverified" where a
claim about another app rests on memory, not a source.

**The rules this has to keep** (his, settled):

1. A button in the chat's plus row does its thing **in the chat**. Strip
   opening the booth with no way to send to the chat was rejected.
2. A plan made in chat becomes a checkbox block on the crew tower, and its
   line never leaves the chat.
3. Crew albums are your own photos only.
4. Never a crew invite link on a shared strip.
5. `docs/voice.md`: no em dashes, no exclamation marks, nothing that reads
   as being watched. `docs/ten.md`: one word per thing, one sheet layout
   (title middle, Cancel left, the confirming word right), every state
   drawn, a hold opens the system's menu.

---

## The short answer

**The row has one item that breaks his rule outright (Win leaves the chat
and lands on the tower), one that duplicates a card already in the chat
(Memory), one whose label lies for some people (Sticker opens the doodle
pad for anyone who may not send photos), and none of the five can be taken
back once sent.** The "no direction" feeling is real and has causes you can
point at:

- The five items are not one kind of thing. Three put something in the
  chat (Plan, Strip, Sticker), one sends an old photo (Memory), one leaves
  for another screen (Win).
- Two of the five end in a dead end on many days (Strip with no photos,
  Memory with nothing sent), and you only find out after the second tap.
- The labels are nouns for different jobs: "Win" means *add*, "Memory"
  opens a sheet titled "Bring Back", "Sticker" also holds Doodle.

**Proposed row: Win, Plan, Sticker, Strip.** Four items, each ending with
one line in this chat. Memory leaves the row (the "A year ago today" card
over the chat keeps doing that job on the day it matters). Details and the
owner's calls are below.

---

## 1. Audit: the plus row as built

From `Strata/Views/Crews/ChatPlus.swift` (`ChatPlusRow`) and
`Strata/Views/Crews/CrewChatSheet.swift` (`composer`, `choose`), and the
2026-10-13 screenshot `tmp-shots/2026-10-13-crew-plus-row.png`.

**The plus itself.** A round glass button left of the field, glyph `plus`,
VoiceOver "More to send". A tap drops the keyboard and shows one row of
five glyphs with a word under each, above the field; the plus turns to an
`xmark` ("Close"). Focusing the field or choosing an item puts the row
away. No overflow, no drawer.

**For someone who may not send photos** (`store.photosAllowed()` false)
the row is Win, Plan, Sticker, and Sticker opens the doodle pad directly.

| # | Label | Glyph | One press does | Lands | Taps to finish | Flags |
|---|---|---|---|---|---|---|
| 1 | **Win** | `plus.app` | **Closes the chat**, waits 450 ms, opens Add a Win with this crew ticked (`CrewTowerView` `onAddWin`) | **On the crew's tower**, not in the chat. The chat is closed; seeing it again is one more tap | plus, Win, name and/or photo, Add: 3 taps plus typing, +1 to get back to the chat | **Leaves the chat** (breaks rule 1). **Duplicates** the tower's own + slot. A plus glyph inside the plus menu reads as "more". The word says *what*, not *what happens* |
| 2 | **Plan** | `checklist` | `GroupPlanSheet`, medium detent: "Plan with Roommates", field focused, day row (Today, Tomorrow, weekdays, Repeating) | A plan card in the chat; you are put In at once, so a box on your tower | plus, Plan, type, Plan: 3 taps plus typing; 4 with a day | Clear. **Cannot be taken back**: no way to delete your own line yet (M2). Proposing auto-joins you (right, but unsaid) |
| 3 | **Strip** | `film` | `CrewStripSendSheet`, full height: today's strip as the booth would print it, Send | Your strip in the chat | plus, Strip, Send: 3 | On a day with no photo: "No photos today. Yet." with Send greyed. **A dead end after two taps**, with only Cancel. Cannot be taken back |
| 4 | **Memory** | `clock.arrow.circlepath` | `CrewMemorySheet`: grid of your photos this crew saw, newest first; choose, then Send | Your photo in the chat with its date ("A year ago today.") | plus, Memory, photo, Send: 4 | **Duplicates** the look-back card over the chat (Send It Again). **Label mismatch**: the row says Memory, the sheet says "Bring Back", and Memories is already the name of a tab (your own album). The glyph is the system's history/restore mark (c). Dead end when nothing was sent with a photo ("Nothing sent here with a photo. Yet."). Cannot be taken back |
| 5 | **Sticker** | his drawn sticker | Medium sheet: a "Doodle" row, your stickers (or "Lift a sticker out of one of your photos."), Edit, New Sticker | A sticker or a doodle in the chat | Sticker: plus, Sticker, tile: 3, **sends on the tap**. Doodle: plus, Sticker, Doodle, draw, Send: 4+. New Sticker: plus, Sticker, New Sticker, pick a photo, lift: 4, **sends with no look first** | **The sheet has no title and no Cancel** (`ten.md` rule 3). **"Sticker" hides "Doodle"**. For someone without photos the label says Sticker and opens the doodle pad. New Sticker sends a sticker you have not seen yet |

**Other things found while looking**

- **The Undo line and the open row.** In the 2026-10-13 screenshot,
  "In your plan · Undo" sits on top of the row's labels (Plan, Strip,
  Memory). The code since moved `undoLine()` onto the thread; the row is
  part of the composer inset, so it should now sit above. *Look at it once
  on a phone before calling it fixed.*
- **The plus row is not the only door to most of these.** Strip: the
  booth's Share, and Make a Strip on a plan card. Memory: the look-back
  card. Win: the tower's slot. Doodle: Doodle on a win. Only Plan and
  Sticker are reached nowhere else in the chat.
- **Nothing sent from the row can be undone.** Chat lines have no Delete
  today (`docs/qol-research-2026-10-13.md` M2 adds it). Every row item is a
  one-way door.
- **No new sends wait in the field.** Every item sends from its own sheet;
  none puts anything above the field to add words to (Messages does, c).

---

## 2. Research: how other chats do the plus

### What they put in it

| Product | What the + holds, in order | Before an overflow | Icon and label | Sources |
|---|---|---|---|---|
| **iMessage, iOS 17 and 18** | Camera, Photos, Stickers, Cash, Audio, Location, then **More** (swipe up) for every other app | About six | Icon with a label, in a list over a blurred thread | (b) [M1] [M2] [M3] |
| **iMessage, iOS 26** | Polls added to the same menu; a caption lists "Camera, Photos, Stickers, Apple Cash, Polls, and Audio" | Same pattern | Same | (b) [M4] [M5]; exact order (c, unverified) |
| **WhatsApp, iPhone** | Photos, Camera, Document, Location, Contact, Poll, Event (and Meta AI images) | All in one tray; 2024 changed iOS from a full-screen menu to an "expandable tray" | Icon with a label | (b) [W1] [W2] [W3] |
| **WhatsApp, 2026** | The tray gains a 4 by 4 strip of **recent photos under the icons**; a tap sends or opens the editor | n/a | n/a | (b) [W4] [W5] |
| **Telegram, iOS** | Paperclip opens on **Gallery** (recent photos with the camera as the first tile), tabs File, Location, Poll, Contact | Tabs along the foot | Icon with a label | (b) [T1] [T2] |
| **Instagram DMs** | Camera and gallery live in the composer itself; the + to the right holds the rest, including **Draw** (Oct 2025) | n/a | n/a | (b) [I1]; the full list (c, unverified) |
| **Snapchat chat** | Camera, voice, stickers, photos (Memories and camera roll), games, as icons in the chat bar | No + | Icons only | (b) [S1]; order (c, unverified) |
| **BeReal (RealChat)** | One-on-one chats, private BeReals, RealMoji reactions; no attach menu of its own | n/a | n/a | (b) [B1] |
| **Locket** | No chat menu: a reply is a photo you take back, or a reaction | n/a | n/a | (b) [L1] |

### What that teaches

1. **The photo comes first, everywhere.** iMessage: Camera, Photos.
   WhatsApp: Photos, Camera. Telegram opens straight on the gallery.
   Instagram and Snapchat put camera and photos in the bar itself, outside
   any menu. (b) [M1] [W1] [T1] [I1] [S1]. In group chats text dominates
   and images are the most sent media; stickers are the least, and 75% of
   users in one large WhatsApp study sent none, "users prefer to send
   images over stickers" (a) [R1]. Telegram groups: about 10% of messages
   carry an image (a) [R2]. *Caveat: both studies are of political
   groups, not friends (c).*
2. **Order is by use, not by importance.** HIG: "Prefer listing important
   or frequently used menu items first" and "People tend to start scanning
   a menu from the top" (a) [H1]. iMessage's first page is "your most-used
   apps" (b) [M2].
3. **About six before an overflow, and the overflow is for things nobody
   uses daily.** iMessage shows six then More (b) [M2]. HIG on submenus:
   "if a submenu contains more than about five items, consider creating a
   new menu" (a) [H1]. Apple's own compact menu layouts show three or four
   items in a top row (a) [H1].
4. **Icon and label together** when there is room. HIG's medium layout
   shows "a symbol or icon above a short label"; the icon-only layout is
   "only for closely related actions" like Bold and Italic (a) [H1]. "Don't
   display an icon if you can't find one that clearly represents the menu
   item" (a) [H1]. Every attach menu above labels its icons (b).
5. **Labels are verbs or plain nouns for the thing sent.** HIG: label an
   action "using a verb or verb phrase", "clearly and succinctly", in title
   case, with no articles (a) [H1]. In practice attach menus use the noun
   of what you send: Photos, Camera, Poll, Location (b) [M1] [W1].
6. **A chosen item returns you to the chat, fast.** WhatsApp's 2026 change
   exists to share recent media "without losing sight of the chat" (b)
   [W4]. Long-pressing + jumps straight to photos in both iMessage and
   WhatsApp (b) [M3] [W4] [W5]. In Messages a picked photo waits in the
   field for words before Send (c, unverified).
7. **The way to take a send back is on the sent line, not in the menu.**
   Messages: unsend within 2 minutes (b) [U1]. Instagram: hold, Unsend (b)
   [U2]. WhatsApp: Delete for Everyone, with a time limit that has changed
   several times (b) [U3]. BeReal launched without unsend and was called
   out for it (b) [B1].
8. **One sheet at a time.** HIG: "Display only one sheet at a time from the
   main interface", and "If something people do within a sheet results in
   another sheet appearing, close the first sheet before displaying the new
   one" (a) [H2]. Cancel on the leading edge, Done on the trailing (a) [H2].
9. **Glass is for controls, sparingly.** "Liquid Glass forms a distinct
   functional layer for controls and navigation", "Don't use Liquid Glass
   in the content layer", "Use Liquid Glass effects sparingly" (a) [H3].
   The row's five glass circles are five more glass controls over the
   thread (c).

### What this app has that they do not

- **The chat is one day long** and the app is about wins, not media. A
  photo here is already a win: it is logged, on your tower, and on the
  crew's. (c)
- **Plans are the crew's own idea** (`docs/crew-plus-design.md`). No other
  app above has them; iMessage's nearest is Polls, which "keep track of who
  voted for what", the opposite of "no count, no list of who is in" (b)
  [M5].
- **No Location, Audio, Documents, GIFs or Polls**, on purpose
  (`docs/qol-research-2026-10-13.md`, "Different on purpose": audio and
  outside GIFs cannot be checked the way words and photos are; Location
  reads as being watched). This holds.

---

## 3. Proposal

### The row: Win, Plan, Sticker, Strip

Each item ends with **one line in this chat**. Order is by how often a
college friend group would use it (c, from the research above): a photo of
what you did, then making plans, then the quick reply, then the once-a-day
thing.

| # | Label | Glyph | What it does | Lands | Spoken (VoiceOver) |
|---|---|---|---|---|---|
| 1 | **Win** | a tower or block glyph, not `plus.app` (c) | Opens Add a Win **over the chat**, this crew ticked. On Add, the win goes to the crew as now **and** a line in the chat quotes it with its photo | The chat (and the tower, as every win does) | "Add a win to this crew" |
| 2 | **Plan** | `checklist` | As now | The chat; you are In; a box on your tower | "Plan something with this crew" |
| 3 | **Sticker** | his drawn sticker | Your stickers; a tap sends. Doodle stays inside, first row | The chat | "Send a sticker or a doodle" |
| 4 | **Strip** | `film` | Today's strip, shown, Send | The chat | "Send today's photo strip" |

**For someone who may not send photos:** Win, Plan, **Doodle** (glyph
`scribble`, spoken "Send a doodle"). Their row says what it opens.

**Cut: Memory.** Why: the look-back card already brings back the right
photo on the right day with Send It Again, which is the moment that
matters; browsing every photo you ever sent this crew is rare (c); the
word collides with the Memories tab and with its own sheet's title
("Bring Back"), two breaks of `ten.md` rule 4; and four items read as a
choice, five as a list (c). Nothing else is lost: the sheet's code can
stay for a later "From Earlier" inside Win (below).

**Not added**, each considered:
- **Photo** (send any picture, not a win): the #1 item everywhere else.
  It is technically cheap (`SocialStore.sendPicture` exists and passes the
  photo check), but it turns the crew chat into a general messenger and
  every photo here is meant to be a win. **Owner's call.** Recommended
  no, for launch; Win with a photo covers it.
- **Camera as its own item**: Add a Win already opens on Take Photo. Two
  doors to one camera is a duplicate.
- **Polls, Location, Audio, GIFs**: different on purpose (section 2).

### Interaction details

1. **Choosing an item folds the row, then opens one sheet over the chat.**
   As now for Plan, Sticker, Strip. Win changes to the same: the chat stays
   open underneath. (HIG [H2])
2. **Every send lands, and the thread shows it.** Already true: the thread
   scrolls to your new line (`onChange(of: messages.last?.id)`). The
   keyboard stays down after a sheet send.
3. **Preview before send where the thing is new to you.** Strip and the
   old Memory already show first. **New Sticker** should not send on the
   lift: the lifted sticker lands in your grid, chosen, and one tap sends.
   A sticker you already have sends on the tap, as WhatsApp and Telegram
   stickers do (c, unverified).
4. **Undo lives on the line, for every kind.** M2's Delete on your own line
   ("Line deleted. Undo", five seconds) is the undo for the whole row: a
   plan, a strip, a sticker, a doodle, a win's line. Build M2 before or
   with this. No "Sent · Undo" toast after each send: that is a second
   undo with a different shape (c).
5. **Empty days say so before the tap, or give a way forward after it.**
   Strip on a day with no photo: keep it in its place (a row that changes
   shape day to day costs muscle memory, c) and give the empty page one
   way on: "No photos today. Yet." with **Add a Win**, which goes to the
   same place the row's Win does.
6. **The Sticker sheet gets the sheet layout**: title "Stickers", Cancel on
   the left (`ten.md` rule 3, HIG [H2]).
7. **No long-press on the plus.** iMessage and WhatsApp use it as a
   shortcut to photos (b) [M3] [W4], but `ten.md` rule 2 keeps a hold for
   the system's menu, and a hidden shortcut is what a new app should not
   rely on (c).
8. **The plus stays a plus,** turns to an x while open, and the row keeps
   the keyboard's place. Writing folds the row (already true).
9. **VoiceOver**: each item keeps its spoken line; the plus says "More to
   send" and "Close". Fine as is.

### Wording (all against `docs/voice.md`)

| Where | Line |
|---|---|
| Row labels | Win · Plan · Sticker · Strip (Doodle for no photos) |
| Strip, nothing today | "No photos today. Yet." Button: **Add a Win** |
| Sticker sheet title | Stickers |
| A win's line in the chat (as the crew sees it) | The win's photo, its title under it, the line's usual quote mark. No sentence: the win speaks for itself |
| Delete on your own line (M2) | "Line deleted." Undo |

No em dashes, no exclamation marks, nothing that says who looked.

---

## 4. Cheap and clearly right, versus the owner's call

### Cheap, clearly right (no change to what the chat promises)

1. **Sticker sheet: a title and Cancel** (`ten.md` rule 3). Small.
2. **"Doodle" as the label and glyph for someone who may not send photos**,
   instead of "Sticker" opening the doodle pad. Small.
3. **New Sticker shows the sticker before it sends** (lands chosen in the
   grid; a tap sends). Small.
4. **Strip's empty page gets Add a Win.** Small.
5. **Win's glyph**: not a plus inside the plus menu. Small; pick from SF
   Symbols, as tools stay SF under his icon rule.
6. **Look once at the Undo line with the row open** on a phone (the
   screenshot shows them overlapping; the code may already be fixed).
7. **M2 Delete on your own line**, already on the MUST list, is what makes
   every row item undoable. Build it with this.

### Owner's call (changes what the chat or a button promises)

1. **Win lands in the chat**, or **Win leaves the row**. Recommended:
   lands in the chat. It is the only way to put a fresh photo in the
   chat, and photos are what groups send most [R1]. Once the chat is a
   drawer on the tower (M9), the tower's own slot sits right under it, so
   if he would rather subtract, Win can go and the row is three.
   - *What it costs:* the line is an ordinary chat line, its text the
     win's title, quoting the win by `quoteWinID`. **No new iCloud field**
     (`CrewRecords.messageKeys` already holds `text` and `quoteWinID`), so
     no CloudKit Console deploy. Drawing the win's photo on that line is a
     view change. An older build sees "↪ Gym / Gym".
   - *To handle:* the crew is already told of the win; the line must not
     ring a second time (`CrewNotifications.chatNews` counts every friend's
     line). Local logic, no field.
   - *Then:* "send a win from earlier today to this crew" (his overnight
     list, 3½) belongs inside this same Win sheet as From Today, rather
     than as a sixth item.
2. **Memory leaves the row.** He approved it on 2026-10-12, so cutting it
   is his. Recommended: cut; the look-back card keeps the job. If kept, it
   goes last and is renamed to match its sheet (both "Bring Back", or both
   something else), since "Memory" is the Memories tab's word.
3. **The order: Win, Plan, Sticker, Strip.** His approved order was Win,
   Plan, Strip, Memory, Sticker ("highest-value first"). This keeps his
   first two and moves Sticker ahead of Strip because a sticker can be
   sent every day and a strip at most once.
4. **A plain Photo item.** Recommended no for launch (section 3).
5. **Deleting a plan's line (once M2 lands).** His rule is that a plan's
   line never leaves the chat. Does the sender's Delete still take it out?
   And do the boxes on the towers of people who said I'm In stay (they are
   lines in their own plans) or go? Recommended: the sender may delete it
   within the day; boxes already on someone's tower stay, as their own
   line.

---

## Sources

Apple
- [H1] HIG, Menus (read from its JSON source): https://developer.apple.com/design/human-interface-guidelines/menus
- [H2] HIG, Sheets: https://developer.apple.com/design/human-interface-guidelines/sheets
- [H3] HIG, Materials (Liquid Glass): https://developer.apple.com/design/human-interface-guidelines/materials
- [M1] Messages plus menu, rearranging (iOS 17): https://www.tomsguide.com/phones/iphones/how-to-rearrange-ios-messages-plus-menu and https://appleinsider.com/inside/ios-17/tips/how-to-rearrange-your-imessage-apps-in-ios-17
- [M2] MacStories, first look at Messages in iOS 17 (most-used first, top six, then More): https://www.macstories.net/news/wwdc-2023-a-first-look-at-messages-in-ios-17/ ; Apple, iOS 17 announcement ("a sleeker look"): https://www.apple.com/newsroom/2023/06/ios-17-makes-iphone-more-personal-and-intuitive/
- [M3] Long-press + for the photo picker: https://9to5mac.com/2023/09/20/ios-17-imessage-apps-photos-more/ and https://daringfireball.net/linked/2024/06/02/iphone-messages-long-press-plus-button
- [M4] iOS 26 Messages, Polls in the + menu: https://www.gearpatrol.com/tech/iphone-messages-app-polls
- [M5] iOS 26 Messages changes: https://www.tomsguide.com/phones/iphones/ios-26-messages
- [U1] Messages unsend and edit limits: https://appleinsider.com/articles/22/06/06/new-imessage-edit-and-unsend-features-have-15-minute-time-limit

Apps
- [W1] WhatsApp attach items on iPhone: https://unanswered.io/guide/how-to-send-message-whatsapp-iphone and https://dev.to/amullagaliev/osd700-how-llms-and-messengers-handling-attachments-ui-4264
- [W2] WhatsApp help, sending media: https://whatsapp.com/faq/en/web/28080001
- [W3] WhatsApp 2024 redesign, iOS menu to an expandable tray: https://alternativeto.net/news/2024/5/whatsapp-launches-new-ui-redesign-with-darker-dark-mode--better-attachment-layout-and-more
- [W4] WhatsApp redesigned media sheet (recents grid, long-press +): https://www.macrumors.com/2026/05/19/whatsapp-redesigned-media-share-sheet-ios
- [W5] WABetaInfo, WhatsApp for iOS 26.19.75: https://wabetainfo.com/whatsapp-for-ios-26-19-75-whats-new/
- [U3] WhatsApp Delete for Everyone, launch and limits: https://blog.whatsapp.com/deleting-messages-for-everyone
- [T1] Telegram attach menu tabs (Gallery, File, Location, Poll, Contact): https://bugs.telegram.org/c/15545
- [T2] Telegram 2022 attachment menu redesign (camera inside the gallery): https://9to5mac.com/2022/03/11/telegram-ios-update/
- [I1] Instagram DMs, Draw in the + menu: https://www.socialmediatoday.com/news/instagram-adds-option-draw-on-dms-chats-stickers/803702/
- [U2] Instagram unsend: https://help.instagram.com/491370017690934/
- [S1] Snapchat chat bar and Memories: https://www.howtogeek.com/287633/how-to-use-snapchat/ and https://www.imore.com/how-access-and-use-memories-snapchat-iphone-and-ipad
- [B1] BeReal RealChat (one-on-one, RealMoji, no unsend at launch): https://www.phonearena.com/news/BeReal-unveils-RealChat-a-new-instant-messaging-feature_id147869 and https://www.slashgear.com/1302690/bereal-testing-direct-messaging/
- [L1] Locket replies and reactions: https://www.imore.com/locket-puts-your-friends-photos-your-home-screen-using-widgets and https://protectyoungeyes.com/apps/locket-widget-app-review

Research
- [R1] "A Sticker is Worth a Thousand Words", stickers in WhatsApp groups (2024): https://arxiv.org/pdf/2406.08429
- [R2] "Topic-wise Exploration of the Telegram Group-verse" (2024): https://arxiv.org/pdf/2409.02525

This repo
- `Strata/Views/Crews/ChatPlus.swift`, `Strata/Views/Crews/CrewChatSheet.swift`, `Strata/Views/Crews/CrewTowerView.swift`, `Strata/Views/StickerPicker.swift`, `Strata/Social/SocialStore.swift`, `Strata/Social/CrewRecords.swift`, `Strata/Social/CrewNotifications.swift`
- `docs/crew-plus-design.md`, `docs/qol-research-2026-10-13.md`, `docs/voice.md`, `docs/ten.md`, `tasks/overnight-2026-10-13.md`
- `tmp-shots/2026-10-13-crew-plus-row.png`
