# Quality of life: crews, chat, banner, crest, strip (research, 2026-10-13)

The owner's ask: understand why every button and action is there, compare it
with the apps people already know, and find the missing details that read as
broken. This is research and specs only. Nothing here is built.

**Order.** The parts built next come first: the crew tower and its chat
drawer, the chat, then the Crews list and its empty state. The banner, the
crest, the crew picker and the strip viewer follow.

**How to read the tags.** (a) published research or Apple's HIG or App Review
Guidelines. (b) seen in a shipping app, with the source. (c) my inference.
Ranks: **MUST** (its absence reads as broken), **SHOULD** (polish),
**DIFFERENT ON PURPOSE** (keep it absent, with the reason).

**What I could not use.** Mobbin's tools refused every call ("requires a paid
plan"), so no Mobbin screens are cited. App claims come from the apps' own help
pages where they exist, then from tech press, and are linked. Apple's Support
pages render empty to a fetch; the HIG was read from its JSON source. A claim
about an app that rests only on memory is tagged (c) and marked "unverified".

## The owner's decisions, folded in (2026-10-13, not open)

1. **Hold a friend's line: Reply, Heart, Copy, Report.** Block is reached from
   their face. **Hold your own line: Reply, Heart, Copy, Delete.** Report and
   Block are what App Review 1.2 asks of any app where people post to each
   other: "A mechanism to report offensive content" and "The ability to block
   abusive users from the service" (a) [G1].
2. **A heart on a line shows a number only past one**: "♥ 3"; one heart is
   just the heart. The crew flame on the list stays as it is.
3. **The Crews tab opens on a list** of crews and friend chats, as Messages
   lists conversations; a row opens the crew's tower, with the chat as a
   pull-up drawer. A friend chat is a crew of two.
4. **The Crews empty state is in scope**: what someone with no crew sees, one
   tap from an invite. "Winning is better together" is retired; three
   candidate lines are in section 1.
5. Every proposed string follows `docs/voice.md`.

## Facts about this app that change the answers

From the repo. They settle many "industry standard" questions before any
comparison.

1. **The chat is one day long.** It clears at the crew's midnight
   (`CrewChatSheet.swift`, `SocialStore.messages(in:)`). So there is nothing
   older to load and no day to separate. But nothing in the chat says so
   (M6).
2. **Nothing says who has opened anything**: "No read receipts and no seen
   marks" (`CrewChatSheet.swift`). Unread is a dot, never a number (crews spec
   2.1).
3. **Today a hold on a friend's line opens the reaction bar** (🔥 👑 ❤️, +,
   stickers) with Report and Block in its ⋯, and **a hold on your own line
   does nothing**. Decision 1 replaces both.
4. **A line goes to an outbox and is drawn as sent at once**
   (`SocialStore.send`: `keep`, then `flush`). A win's back can say "Not sent
   yet" (`outboxRevision`); **a chat line has no such state.**
5. **There are no times anywhere in the chat.**
6. **The Crews list previews the newest WIN, not the newest line**
   (`CrewsListView.preview`). A message lights the dot while the row still
   says "Sam: Gym".
7. **Every new line scrolls the thread to the bottom**
   (`onChange(of: messages.last?.id)` then `scrollTo`), even while you are
   reading higher up, and the chat refreshes every three seconds.
8. **A strip or picture in the chat cannot be opened** (`CrewStripPicture`,
   120pt wide, no tap). While it loads it is blank space.
9. **A friend's face beside their line takes no tap** and is hidden from
   VoiceOver. Decision 1 makes it the way to Block.
10. **The empty state's second row says "Two is a crew. So is eight."**
    `CLAUDE.md` (Launch Pack): "Nothing advertises eight. 'Up to 8' appears
    only as a refusal." That line breaks it.
11. **Crews are listed oldest first** (`sorted { $0.createdAt < $1.createdAt }`).
12. The bounds on every spec: `docs/ten.md` (one gesture per action, four
    haptics, every state drawn, VoiceOver gets what a hold gets),
    `docs/voice.md`, "premium is subtraction", and the crew-plus rule that **a
    strip of other people's photos is never saved to Photos**.

---

## 2. Crew tower screen and the chat drawer

### What is there, and why

| Control | Why |
|---|---|
| Back (chevron, top left) | Back to the Crews list. |
| Faces in the glass circle | The crew. Empty: a tap opens Crew Info. Full: a tap fans the heads out. Hold: Let Everyone Out. |
| Name capsule | Crew Info. |
| Chat bubble, top right, with dot | Opens the chat sheet today. **The drawer replaces it.** |
| The slot | Your one-tap win into this crew, as on Wins. |
| Planned boxes | Crew plans you said I'm In to. Press: photo, library, log, edit, Not Today. |
| Plan cards under the header | A crew plan still waiting for your answer, with I'm In. |
| Block press | The photo viewer among the day's wins. |
| Block double-tap | A heart, never taken back by the same gesture. |
| Block hold | The reaction bar over it; slide to choose. |

### Compared

- HIG: a resizable sheet rests at **detents** and shows a **grabber**; in iOS
  a sheet can be **nonmodal**, so people keep using the view under it (a)
  [H6]. That is the drawer. Maps and Find My work this way (c, unverified).
- HIG: "Offer alternatives to gestures ... if you use a swipe gesture to
  dismiss a view, also make a button available" (a) [H5]. A drag-up drawer
  needs a way that is not a drag.
- HIG: Messages' compose sheets "display only at full height to give people
  enough room to create content" (a) [H6]. So writing opens the drawer.

### Missing

| Item | Rank |
|---|---|
| Rest state: newest line and the composer, unread shown | **MUST** (M9) |
| What counts as seen, now the chat is always half on screen | **MUST** (M9) |
| Writing opens the drawer; VoiceOver can open and close it | **MUST** (M9) |
| The tower stays usable under the resting drawer | **MUST** (M9) |
| The chat bubble button goes | SHOULD (subtraction) |

### Spec

**M9. The drawer.** Two heights. *At rest*: the grabber, one line (the newest
line as "Sam: see you at 6", truncated to one line, with the ink `NewsDot`
before it when unread) and the composer (plus, field, Send). *Open*: the whole
thread under the crew's header, as the sheet is today. Nothing in between.

- Drag the grabber or the line up, or tap the line: open. Drag down, or
  scroll the thread past its top: rest.
- Focus the field at rest: it opens, so a reply is written with the
  conversation in view [H6]. The plus row at rest opens it too.
- At rest the tower takes touches (a nonmodal sheet,
  `presentationBackgroundInteraction` up to the rest height), and the
  tower's bottom inset grows by the rest height so its base is not hidden.
- **Seen.** The dot clears when the drawer opens, not when the crew screen
  appears. At rest you have read one line at most; clearing the dot there
  would clear it on the Crews list for lines nobody read.
- VoiceOver: the resting line is a button, "Chat, Sam: see you at 6", value
  "New messages" when unread, action Open. Open, the escape gesture brings it
  to rest. [H5]
- Under 16 without writing: the resting line, and "Writing here is off on
  this phone." where the composer would be, as the sheet says now.
- Empty: "Quiet here. Yet." as the resting line.
- Haptics: a light tap on reaching each height; nothing during the drag [H4].
- The bubble button top right goes, with its dot. The drawer's own dot is
  where the eye already is.

---

## 3. The chat itself

### What is there, and why

| Control | Why |
|---|---|
| Lines: yours right in ink, friends' left on a quiet fill | Who said it, without lines between. |
| Face and name at the start of a friend's run | Who, once per run. |
| Quoted win on a reply ("↪ Morning run"); a tap opens it | Replies on a win land here with their context. |
| Hold a friend's line: reaction bar, ⋯ Report, Block | To be replaced by decision 1. |
| Reaction chips under a line; a count only when two chose the same | What everyone chose. Already matches decision 2. |
| Plus row: Win, Plan, Strip, Memory, Sticker (the doodle inside) | Richer sends, one tidy row. |
| Field: a box that grows to five lines, 280 characters | A short line between friends. |
| Send | Sends. Refused words come back to the field. |
| A draft kept per crew until a send goes | Nothing written is lost to a swipe. |
| Plan cards and the look back over the thread | Today's plan; "A year ago today". |
| Refusals: Try other words, That's plenty for today, That sticker or photo stays with you | Each said once, calmly. |
| Undo line ("In your plan · Undo") | Taking back I'm In. |

### Compared

- **The hold menu.** HIG: "Support context menus consistently throughout your
  app. If you provide context menus for items in some places but not in
  others, people ... may think there's a problem"; "Always make context menu
  items available in the main interface, too"; destructive items go last and
  are marked (a) [H1]. WhatsApp's hold offers Reply and reactions (b) [W1];
  Instagram's offers Unsend on your own message (b) [I1].
- **Reactions.** Messages opens Tapbacks by **double-tap or touch and hold**,
  and any emoji or sticker can be one (b) [A1]. Instagram: **double-tap a
  message to like it** (b) [I2]. WhatsApp: **one reaction per message; tap
  yours to remove it; the sender is not told** (b) [W1].
- **Reply to a line.** WhatsApp: hold then Reply, or swipe right (b) [W1].
  Messages added swipe to reply in iOS 17 (b) [A2].
- **Taking back.** Instagram: hold, Unsend, hidden from everyone (b) [I1].
  Messages: unsend within 2 minutes, edit within 15, recipients told (b) [A5].
- **Failed sends.** Messages marks an undelivered message and offers **Try
  Again** (b) [A4]. HIG: "Show people when a command can't be carried out and
  help them understand why" (a) [H3].
- **Times.** Messages hides each message's time behind a swipe left and puts
  a **date and time stamp at each new day** (b) [A3].
- **The newest.** Messages has a catch-up arrow to the first unread (b) [A2].
  Discord users report the chat **jumping to new messages while they read** as
  a defect (b) [D1].
- **Disappearing chats say so.** Snapchat deletes chats by default 24 hours
  after everyone has seen them, names the rule as a setting per chat, and lets
  a message be kept (b) [S1].
- **Typing in groups.** iOS 26 Messages added group typing indicators (b)
  [A6]. See "Different on purpose".

### Missing

| Item | Rank |
|---|---|
| The hold menu, decision 1: Reply, Heart, Copy, Report or Delete | **MUST** (M2) |
| Block from a friend's face | **MUST** (M2b) |
| Reply to a line | **MUST** (M2c, now in the menu) |
| Double-tap a line to heart it | **MUST** (M3) |
| Heart count shown only past one | **MUST** (M3, decision 2) |
| Not-sent state with Try Again | **MUST** (M1) |
| Tap a strip or picture: full screen | **MUST** (M4) |
| Times in the thread | **MUST** (M5) |
| "Today's chat clears at midnight." | **MUST** (M6) |
| No jump while reading; a way to the newest | **MUST** (M7) |
| Links you can tap | SHOULD |
| A placeholder while a picture loads | SHOULD |
| One to three emoji alone, drawn larger | SHOULD |
| Typing indicator; read receipts; older pages; edit; link previews; voice notes, GIFs, polls; @mentions; swipe-left times | DIFFERENT ON PURPOSE |

### Specs

**M2. The hold menu.** A hold on any line opens the system's menu with the
bubble lifted as its preview (`ten.md` rule 2, which this brings the chat back
under; its written exception for chat lines changes with it).
- A friend's line: **Reply, Heart, Copy, Report.**
- Your own line: **Reply, Heart, Copy, Delete** (red, last [H1]).
- Copy only on a line with words; a sticker, strip or plan has no Copy. A
  quoted win's line keeps its tap to open the win.
- **Heart** gives ❤️ or, if yours is already the heart, takes it back (the
  menu says which: "Heart" or "Remove Heart"). Taking back tells nobody, as on
  WhatsApp [W1].
- **Delete** takes the line out of everyone's chat with nothing left in its
  place, and offers the existing Undo line, **"Line deleted. Undo"**, for five
  seconds before the deletion is sent (rule 3: confirmed or undoable). No time
  limit; the line is gone at midnight anyway. [I1]
- **Report** opens the report already written ("Your report goes to Some
  Wins. Nobody in the crew is told.").
- Copy gives the tick haptic and shows nothing.
- VoiceOver: the four as actions on the line, with the line's text as its
  label (rule 9).
- *Question for the owner*: the other reactions (🔥, 👑, +, stickers) are not
  in the four. Messages draws its Tapback row above the menu [A1]; doing the
  same keeps them one hold away. Without it, a sticker reaction on a line
  goes.

**M2b. Block from their face.** A tap on a friend's face beside their line
opens their card: their face, name, "Started the crew" where true, and
**Report** and **Block** at the foot, the same two the member's ⋯ in Crew Info
already has. The face becomes a 44pt target (it is drawn smaller; the target
is not). VoiceOver: the line gains the action "Sam's Card", since the face is
hidden from it. [G1]

**M2c. Reply to a line.** Reply puts the quote above the field: "↪ Sam: see
you at 6", one line, with an x to drop it, and focuses the field. The sent
line carries it as a win's reply does; a tap on the quote scrolls to that line
and lights it briefly, if it is still in today's chat. Through the menu only,
not a swipe: rule 2 gives the swipe on a row to removing it, and the drawer
owns vertical drags. [W1, A2]

**M3. Double-tap: a heart.** The block's rule, on a line, yours or a friend's:
two taps give ❤️, a heart already given stays given, another reaction you gave
becomes the heart. The heart pops at the bubble's corner (the tower's
double-tap heart, small) and lands under the line. **The count, decision 2**:
one heart is "♥"; two or more is "♥ 3", in `inkSecondary`, monospaced digits.
This is what the chips already do for any mark two people share. On a quoted
bubble the double tap is checked first, so its single tap waits about a
quarter of a second. Light tap haptic. [I2, A1]

**M1. A line that has not gone says so.** The line appears at once, as now.
If it is still in the outbox ten seconds later, it dims to 60% and one line
under it, `inkTertiary`, `screenSubtitle`, says **"That didn't send. Try once
more."** (`docs/voice.md`'s own error line). A tap on the line tries again;
when it goes, the note leaves and the line comes up to full. One warning
haptic when the note appears. No spinner, no red, no offline banner.
VoiceOver: the label ends "not sent", action Try Again. The same for a doodle,
sticker, strip or plan line. [A4, H3]

**M4. A strip or picture opens full screen.** Tap it: the photo viewer the
crew's blocks already open, on the dark, the picture fitted. Pinch or double
tap to 3x, drag to pan, drag down to close. Close on the left and ⋯ on the
right, as `ten.md` sets for the photo viewer. At the foot: "Sam, 4:12 PM".
⋯ holds **Share** and **Save Image** only when it is yours; a friend's offers
Heart and Report. A group plan's strip (other people's photos) is never saved
or shared, the crew albums' rule. It grows from the bubble; under Reduce
Motion it fades. [H8]

**M5. Times, quietly.** A centred time, `inkTertiary`, `screenSubtitle`,
above the first line of the day and above any line that comes an hour or
more after the one before: "9:41 AM". After that gap the same sender's run
starts again, face and name shown. No time under every line, no swipe.
VoiceOver: every line's label ends with its time ("Sam, see you at 6, 4:12
PM"). [A3]

**M6. Say the chat is today's.** The empty state keeps "Quiet here. Yet." and
gains a line under it: **"Today's chat clears at midnight."** The same line
sits at the top of a full thread, where scrolling stops. When the crew's
midnight is not yours, it gives your time: "Today's chat clears at 9 PM." In
the app only. Without it, a morning's empty chat reads as lost messages.
[S1]

**M7. No jump while reading.** A new line scrolls the thread down only when
you are within one screen of the bottom, or when the line is yours. Otherwise
a round glass arrow-down button sits above the field's right end with the
ink dot on its shoulder; a press goes to the newest and the button goes.
VoiceOver: "Newest Messages", value "New messages". [D1, A2]

**SHOULD. Links open.** A web address in a line is underlined in the line's
own ink and opens in Safari. No preview card.

**SHOULD. Something while a picture loads.** Strip and picture frames draw
`quietFill` at their final shape until the image is read, so the thread does
not jump when it lands. [H7: "Show something as soon as possible"]

**SHOULD. One to three emoji alone are larger.** Twice the body size, no
bubble, as a sticker sits. (c), Messages' behaviour unverified.

### Different on purpose, and why

- **Typing indicator.** Research finds it raises "co-presence" (a) [R4] and
  holds attention through suspense, an "uncertain index" (a) [R5]. Both are
  the reasons to leave it out: it tells people who is in the chat right now,
  the feeling of being watched the app never gives (`ten.md` rule 4), and it
  invites waiting on someone. The three-second refresh would also make it lag
  (c).
- **Read receipts, "seen", last active.** Linked to anxiety, avoidance and
  more checking (a) [R2]; bad feelings arrive sooner when a message is read
  and unanswered than when unread (a) [R1]; researchers propose letting people
  turn them off (a) [R3], which Instagram and WhatsApp both had to add [I2].
  Already absent. Keep it so.
- **Older messages, day separators.** One day only; M6 says so instead.
- **Edit.** Delete and Reply cover it; Messages' edit carries a visible history
  and a 15-minute clock [A5], more chrome for 280 characters.
- **Link previews.** A preview is a request to someone else's server on a
  friend's behalf, and a card is chrome.
- **Voice notes, GIFs.** The crew's safety floor checks words (`CrewWords`)
  and photos; audio and outside GIFs cannot be checked the same way, and 1.2
  asks for "A method for filtering objectionable material" [G1]. (c)
- **Polls.** Messages' polls "keep track of who voted for what" [A6]. A group
  plan does this job, and its rule is "no count, no list of who is in".
- **@mentions, search, pin.** Eight people, five crews, one day.
- **Swipe left for times.** A hidden gesture (rule 2); M5 shows the times that
  matter.

---

## 1. The Crews tab: list, friend chats, empty state

### What is there, and why

| Control | Why |
|---|---|
| Row press | Opens the crew's tower and its drawer. |
| Row: faces or photo, name, time, two-line preview | Who, what happened last, when. Messages' row. |
| Unread dot (left) | Something new: a win, a reaction to yours, or a line. No number. |
| Flame and number after the name, from 3 days | The crew's streak, together. Stays (decision 2). |
| Bell with a slash | Muted. |
| Hold: Mute or Unmute, Leave Crew or End Crew | The row's actions without opening it. |
| Swipe: Leave or End, Mute | Messages' swipe actions (`ten.md` exception). |
| Compose glyph, top right | Start a Crew; at five it says why not. |
| Pull to refresh | Fetch now. |
| The drawing at the list's foot, "Winning is better together" | What crews are for. **Line retired** (decision 4). |
| Empty: drawing, three rows, Start a Crew | Who, what happens, who sees it; the action at the foot. |
| Under 13, joining, signed out, old iOS | One sentence each (rule 8). |

A friend chat is a crew of two; an unnamed pair is already shown by the other
person's name ("Shared with X" rule).

### Compared

- Messages and WhatsApp list a conversation by its **last message**; the crews
  spec copied Messages' row on purpose (crews spec 2.2). (c) for the apps.
- WhatsApp's mute: **8 Hours, 1 Week, Always**; you still read and write (b)
  [W2]. Ours has these in Crew Info but the row sets Always only.
- Locket's store page sells the app on who it is for, a few close friends,
  rather than on features (b) [L1]. BeReal leads with "friends", never
  "followers", and shows no friend count (b) [B1].

### Missing

| Item | Rank |
|---|---|
| Preview shows the newest thing, line or win | **MUST** (M8) |
| Empty state: a new line, one tap to an invite, no "eight" | **MUST** (M14) |
| The tab carries the unread dot | **MUST** (M13) |
| Mute durations from the row | SHOULD |
| A kept draft shows in the row | SHOULD |
| Order by recent activity | Question for the owner |
| Unread numbers; search, pin, archive | DIFFERENT ON PURPOSE (no numbers; five crews at most) |

### Specs

**M8. The row says the newest thing.** The preview is the newest of today's:
a line ("Sam: see you at 6"), a picture ("Sam sent a photo strip", "Sam sent a
sticker"), a plan ("Sam planned Evening walk") or a win ("Sam: Gym", as now).
The time is that thing's. Yours read "You: ...". After the crew's midnight the
chat is gone, so the row falls back to the newest win or "No wins yet today."

**M14. The empty state.** The drawing stays (the owner's, 2026-10-08), with a
new line under it, then the three rows, then the one button.

- **The button invites in one tap**: **Invite a Friend** makes an unnamed
  crew and opens the system share sheet with its link at once (an unnamed crew
  is called by its people's names, so nothing is lost by skipping the name
  sheet). If the share sheet closes with nobody sent the link, the crew of one
  is ended quietly, so nothing is left behind that the person did not choose.
  Naming and a photo stay in Crew Info. The compose glyph keeps the full New
  Crew sheet. (c)
- **The second row**: "Two is a crew. So is eight." advertises eight, which
  the Launch Pack forbids. Make it **"Two is a crew."**
- **The line under the drawing**, three candidates in the voice (spare, one
  idea, could only be this app):
  1. **"For the people you'd tell anyway."** The crews spec's own phrase. Warm
     by understanding: everyone has two or three people they would text about
     a good day. Recommended.
  2. **"One tower for today, built with a friend."** The most specific to this
     app; plain, no warmth beat.
  3. **"Your win, landing next to theirs."** The tower's drop, said as a
     picture; quietest of the three.

**M13. The tab carries the dot.** With Crews a tab, its "something new" must
come with it, or a friend's line is invisible from Wins. The tab item shows
the ink dot, no number, lit by the same `hasNews`. iOS draws tab badges red
with text; check on iOS 26 whether a plain ink dot can be drawn. If it cannot,
an empty system badge is better than none. (c), verify on device. HIG:
"Make sure badging isn't the only method you use to communicate essential
information" (a) [H2]; the rows' dots are the other method.

**SHOULD. Mute durations from the row.** The hold menu's Mute becomes a
one-level submenu: 1 Hour, 8 Hours, 1 Week, Always (the four Crew Info has).
The swipe stays one tap and means Always. [W2, H1]

**SHOULD. Draft in the row.** When `CrewDrafts` holds words for a crew, the
preview reads "Draft: half a sentence", the time hidden. Drafts live while the
app is open, and so does this. (c)

---

## 4. The in-app message banner

### What it is for

A crew line that arrives while you are elsewhere in the app. Today the
system banner shows in the app for any crew not on screen
(`StrataAppDelegate.willPresent`).

### Compared

- HIG: in the foreground, present new information "in a way that's
  discoverable but not distracting or invasive, such as incrementing a badge
  or subtly inserting new data into the current view" (a) [H2].
- HIG: "Avoid sending multiple notifications for the same thing" (a) [H2].
  Chat alerts are already held to one a crew an hour (`ChatAlerts`).

### Spec, MUST (M10)

- **Content**: the sender's small face, then "Sam: see you at 6", one line,
  truncated; a picture is "Sam sent a photo strip". In a crew of three or
  more, the crew's name above in `inkTertiary`. No app name, no count.
- **Where**: just under the Wins header, over the tower.
- **Press**: opens that crew with the drawer open. **Drag up**: away. Four
  seconds, then it goes up.
- **One at a time.** A newer line from the same crew replaces the words in
  place; another crew's waits. Lines in quick succession fold: "Sam and Ana
  wrote", no number.
- **Never**: for a muted crew (its dot still lights), for your own lines from
  another device, while that crew's screen is open, or while the camera, Add a
  Win, the booth, a replay or any full-screen page is up.
- **Not twice**: in the foreground the system banner for a chat line is
  suppressed (`willPresent` returns none), so a line never shows both ways.
- **Motion**: springs down with `motionSnappy`; under Reduce Motion it fades.
  No haptic: a banner nobody asked for should not buzz [H4].
- **VoiceOver**: one announcement, "Sam in Roommates: see you at 6", queued
  behind speech; while up, the banner is a button.

---

## 5. Wins header crest, reactions on your blocks, the crew picker

### What is there, and why

| Control | Why |
|---|---|
| Crest: ring, your head or picture, "3/5" | Today against your goal; the ring only fills. Press opens Your day. VoiceOver: "3 wins today", "Goal 5", "Opens your day." |
| Crews button, top left, with dot | The way in today; **the tab replaces it** (M13). |
| Crew picker in Add a Win: one tick per crew | Where this win goes, sticky from last time. |

### Compared

- Locket: a reaction shows a friend "you've seen their photo", drawn as emoji
  raining on it, and its store page says it does not "count or track the
  reactions" (b) [L1]. BeReal draws RealMojis on the post (b) [B1].
- Locket lets you send to certain friends or to everyone (b) [L1]. Snapchat
  has no select-all; it uses saved Shortcuts (b) [SC2].

### Missing

| Item | Rank |
|---|---|
| Friends' reactions on your own blocks | **MUST** (M11) |
| All, in the crew picker | **MUST** (M12) |
| The crest says "Goal reached" to VoiceOver | SHOULD |
| A count on a block's reactions | DIFFERENT ON PURPOSE: decision 2 is for chat lines; a block stays a picture, not a score |

### Specs

**M11. Reactions on your block.** Up to three marks, overlapping, at the
block's top right corner on your own tower, newest on top, no number; a
sticker is its picture at chip size. Your own reaction is not shown there.
A new one pops the first time you see it (`elasticPop`); under Reduce Motion
it fades. The viewer a press opens already lists who chose what. VoiceOver:
the block's label ends "Sam and Ana reacted". [L1, B1]

**M12. All, in the crew picker.** With three or more crews, the row starts
with **All**: ticking it ticks every crew and friend chat, unticking any one
unticks All, and it is sticky like the rest. Friend chats are named by the
person, in the Crews list's order. Tick haptic, `isSelected`, label "All
crews". [L1, SC2]

**SHOULD. The crest at the goal.** VoiceOver's value becomes "Goal reached"
once wins reach the goal. Nothing visual changes.

---

## 6. Photo strip viewer and sharing

### What is there, and why

| Control | Why |
|---|---|
| Booth: print, shake or tap to develop, turn in the hand, pinch to 3x | The strip's moment. |
| Booth tools: paper, doodle, sticker, share, save | Make it yours, send it out. |
| Share as a posed, transparent PNG | For a story. |
| Plus row Strip: today's strip and Send | Into the crew's chat. |
| Make a Strip on a group plan | Those photos, kept in the crew. |
| In the chat: the strip at 120pt, no bubble | The thing itself. |

### Missing

| Item | Rank |
|---|---|
| Open a strip from the chat, full screen | **MUST** (M4) |
| Save and Share your own strip from the chat | **MUST**, inside M4 |
| Heart a strip by double tap or the menu | inside M2 and M3 |
| A placeholder while it loads | SHOULD (section 3) |
| Save a friend's strip | DIFFERENT ON PURPOSE: their photos are theirs, the crew albums' rule. A screenshot cannot be stopped and should not be policed. |

---

## Cross-cutting

- **Haptics.** HIG: use patterns consistently; "Avoid overusing haptics" (a)
  [H4]. Every spec uses the app's four and adds none.
- **VoiceOver.** HIG: "Offer alternatives to gestures" (a) [H5]; `ten.md` rule
  9. Every new menu item, the double tap, the face and the drawer have a named
  action above.
- **Dynamic Type.** The owner set large-text polish aside for the launch
  audience. The chat already uses `fitsLargeType` on names and quotes; M5's
  time should too. Not ranked.
- **Keyboard.** Already right: the field grows to five lines, scrolling
  dismisses the keyboard interactively, the plus row takes the keyboard's
  place. The drawer adds one rule: focus opens it (M9).

---

## The MUST list, in build order

Built next (sections 2, 3, 1):
1. **M9** The drawer: rest state, seen on open, focus opens it, VoiceOver.
2. **M2** The hold menu: Reply, Heart, Copy, Report or Delete. **M2b** Block
   from the face. **M2c** Reply to a line.
3. **M3** Double-tap heart; "♥ 3" only past one.
4. **M1** "That didn't send. Try once more." with Try Again.
5. **M7** No jump while reading; the newest button.
6. **M5** Times after an hour's gap.
7. **M6** "Today's chat clears at midnight."
8. **M4** Full screen for strips and pictures; Save and Share only your own.
9. **M8** The list row previews the newest thing.
10. **M14** The empty state: new line, Invite a Friend in one tap, no "eight".
11. **M13** The tab's dot.

After: **M10** the banner, **M11** reactions on your blocks, **M12** All in
the picker.

## Questions for the owner

1. The other reactions on a line (🔥, 👑, +, stickers): keep them as a row
   above the hold menu, as Messages does, or let the menu's Heart be the only
   reaction on a line?
2. The empty state's line: 1, 2 or 3 (recommended 1).
3. Invite a Friend with no name sheet, and a crew of one ended if nobody is
   sent the link: yes or no?
4. The Crews list order: stable, oldest first (as now, and the picker
   matches), or newest activity first, as Messages?

## Sources

Apple
- [G1] App Review Guidelines 1.2, User-Generated Content: https://developer.apple.com/app-store/review/guidelines/
- [H1] HIG, Context menus: https://developer.apple.com/design/human-interface-guidelines/context-menus
- [H2] HIG, Notifications: https://developer.apple.com/design/human-interface-guidelines/notifications
- [H3] HIG, Feedback: https://developer.apple.com/design/human-interface-guidelines/feedback
- [H4] HIG, Playing haptics: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- [H5] HIG, Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- [H6] HIG, Sheets: https://developer.apple.com/design/human-interface-guidelines/sheets
- [H7] HIG, Loading: https://developer.apple.com/design/human-interface-guidelines/loading
- [H8] HIG, Activity views: https://developer.apple.com/design/human-interface-guidelines/activity-views

Research
- [R1] Kato, Kato and Ozawa (2020), reply speed with a read receipt display: https://www.igi-global.com/article/reply-speed-as-nonverbal-cue-in-text-messaging-with-a-read-receipt-display-function/239530/
- [R2] Lynden and Rasmussen (2017), read receipts in mobile instant messaging: https://tidsskrift.dk/mef-journal/article/view/28781
- [R3] Hoyle et al., CHI 2017: https://www.cs.oberlin.edu/~rhoyle/papers/hoyle-chi17.pdf
- [R4] Iftikhar, Ma and Huang, typing indicators, CHI 2023: https://jeffhuang.com/papers/LiveTyping_CHI23.pdf
- [R5] "Stay with Me: Uncertain Indices and Attentional Presence in Chat Interfaces": https://tidsskrift.dk/nja/article/view/140199

Apps
- [A1] Messages Tapbacks: https://www.idownloadblog.com/2024/06/26/how-to-add-emoji-reactions-messages/ and https://www.macrumors.com/guide/ios-18-messages/
- [A2] Messages swipe to reply, catch-up arrow: https://www.tomsguide.com/how-to/how-to-quick-reply-in-ios-messages and https://www.tomsguide.com/news/ios-17-messages
- [A3] Messages timestamps and day stamps: https://iphonelife.com/blog/31961/tip-day-where-did-timestamps-go
- [A4] Messages not delivered, Try Again: https://support.apple.com/en-gb/118433 and https://www.slashgear.com/1845603/messages-app-red-exclamation-mark-meaning
- [A5] Messages unsend and edit limits: https://appleinsider.com/articles/22/06/06/new-imessage-edit-and-unsend-features-have-15-minute-time-limit
- [A6] iOS 26 Messages, group typing indicators and polls: https://9to5mac.com/2026/01/12/ios-26s-messages-app-adds-five-great-new-group-chat-features/ and https://www.tomsguide.com/phones/iphones/ios-26-messages
- [W1] WhatsApp, react and reply: https://faq.whatsapp.com/424198503229937/ and https://faq.whatsapp.com/en/general/26000014/
- [W2] WhatsApp mute durations: https://www.iphoneincanada.ca/news/whatsapp-mute-chat-forever/
- [I1] Instagram unsend: https://help.instagram.com/491370017690934/
- [I2] Instagram double-tap like; read receipt toggle: https://www.businessinsider.nl/how-to-like-messages-on-instagram/ and https://9to5google.com/2023/11/08/instagram-read-receipts-dms/
- [S1] Snapchat chat deletion: https://help.snapchat.com/hc/en-us/articles/7012334940948-When-does-Snapchat-delete-Snaps-and-Chats
- [SC2] Snapchat sending to many: https://www.guidingtech.com/send-a-snap-to-everyone-at-once/
- [L1] Locket reactions and recipients: https://apps.apple.com/us/app/1600525061 and https://www.vodafone.co.uk/newscentre/?p=49765
- [B1] BeReal RealMojis, no friend counts: https://sociality.io/blog/what-is-bereal/
- [D1] Discord, new-message jumps reported as defects: https://support.discord.com/hc/en-us/community/posts/12175689699351 and https://support.discord.com/hc/en-us/community/posts/360043444572
