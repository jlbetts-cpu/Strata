# Tonight's plan (2026-10-13, overnight)

From your phone notes, cleaned up. In the order I will build them: the
small fixes first so they cannot be lost behind the big ones, then the
Crew tab, which most of the rest hangs off. Each line says what "done"
means. Nothing goes to Friends; the build in the morning is for you only.

## 0. Before anything

- [x] The project folder, moved out of iCloud to `~/Developer/Strata`
      (your pick). iCloud had evicted the branch pointer itself tonight and
      git briefly could not find `main` (restored from the log, nothing
      lost). Built from the new folder.

## Your calls (2026-10-13, before the night)

- The chat is a **pull-up drawer** on the crew's tower: the latest message
  and the composer at the bottom, drag up for the whole conversation.
- The Crews tab opens on **the list of crews** (and friend chats), then
  into one. Confirmed when asked twice. My lean was the last crew, to save
  a tap; offered: list first, but straight in when there is only one crew
  and no friend chat. Not built unless you say so.
- A friend chat is **a crew of two**: the same screen, no iCloud change.

## Rules for tonight (yours, 2026-10-13)

- Every new string tonight (menus, banners, empty states, "All crews",
  TestFlight notes) is written against the voice contract in the Launch
  Pack (`docs/voice.md`). If a line could appear in another app, rewrite it.
- The Crews empty state is in scope: what a person with no crew sees, one
  tap from an invite, in our voice. "Winning is better together" goes.
- Hold menu on someone else's message: Reply, Heart, Copy, Report. Block is
  reachable from their face. Required for App Store review.
- Research (7½) for the chat and crew tower runs before sections 3 to 5
  are built, not after.
- Counts: a heart on a bubble shows a number only past one ("♥ 3"); one
  heart is just the heart (your pick). Crew flame counts stay as they are.
- The month's drawing goes at the end of Memories, after the albums and
  photos (your pick).

## 1. Small fixes (first hour)

- [x] **No shadow on the + block.** The shadow was the system glass's own,
      which cannot be switched off; the slot and the planned boxes (one
      pane) are drawn with the translucent material and their ink edge now.
      Looked at in light and dark.
- [ ] **The month's drawing goes to the end of Memories**, after the albums
      and photos.
- [ ] **Select all crews when adding a win.** One "All crews" choice on the
      Add sheet's crew row, so a win goes everywhere in one press.
- [ ] **A strip export never cuts off its top.** Find why it happens
      "sometimes" (likely the safe area or a render before layout), fix,
      and test every strip length.
- [ ] **The head that runs over the blocks after coming back from a chat.**
      Find it, fix it, and add a walk that comes back from the chat and
      checks the head stands where it should.

## 2. The Crew tab (the big one)

- [ ] **A tab of its own, right of Wins**: Wins, Crews, Camera, Memories.
      Its glyph from your drawn set if there is one, else a plain one.
      It opens on the list of your crews and friend chats.
- [ ] **Journal takes the top right of Wins**, where the crew button was,
      as its own button straight into the journal. The top left stays Plan.
- [ ] Every crew screen
      that was pushed from Wins moves into the tab: the tower, its info,
      invites, rules, the code.
- [ ] Deep links and notifications that open a crew land in the tab.

## 3. Chat and tower, one screen

- [ ] **The crew's chat lives on its tower's screen** as a pull-up drawer,
      not a separate sheet.
- [ ] **Blocks merge on a crew's tower** the way they do on yours.
- [ ] **Faces: profile photos first.** The middle of a crew's tower shows
      everyone's profile photo. Press one and that person's head comes out
      under it, as heads do today. Nobody without a head floats; they are
      their photo and nothing else.

## 4. The chat, finished

- [ ] **Double tap a message to heart it.** Hearts show on the bubble,
      with a count, and undo with another double tap.
- [ ] **A strip in the chat opens full screen**, with save and share.
- [ ] Hold a message: Reply, Heart, Copy, and Delete for your own. The
      expected things a chat has, each in the app's own menu.
- [ ] **Lots of reactions hold up**: a bubble or block with 20 reactions
      stays tidy (a few faces and a count), checked with seeded data.

## 5. Your Wins tab

- [ ] **Your face in the middle of your tower**: your head if you made one,
      else your profile photo. Press it and your head comes out onto the
      tower, as a crew face does.
- [ ] **Reactions show where your wins are**: the reactions friends put on
      your win show on its block on your tower and in Memories.
- [ ] **A new crew message shows above your tower**: the sender's face and
      the message itself, small, for a few seconds, and a tap opens that
      chat. The system notification stays for when the app is closed.

## 6. Friends (one-on-one chats)

- [ ] **Message one person** from their face in any crew. A crew of two,
      listed with your crews.

## 7. Smooth everywhere

- [ ] A pass over every screen touched tonight for jolts: a tab switch, a
      sheet rising, the keyboard, the tower redrawing under a new reaction.
      Recorded in the simulator and looked at frame by frame, not counted.
- [ ] Finish the camera review's tools (the one open issue from today:
      after a look is chosen they ignore presses for a few seconds).

## 7½. Research behind every control (all night, alongside the rest)

Your ask: "understanding why the button or action is there and researching
how the action can be improved and if it's missing anything from industry
standard apps."

- [ ] For every screen built or touched tonight, and the ones they sit
      next to (crew tower, chat, Wins header, Add sheet, strip, Memories,
      camera review): each control written down with why it is there, what
      iMessage, Instagram, BeReal, Locket, WhatsApp and Apple Photos do for
      the same job (from real screens, not memory), and what ours is missing
      that a person would expect: the vital details, like a timestamp, a
      read state, an undo, an empty state, an error that says what to do.
- [ ] Ranked: what is missing and matters, what is different on purpose
      (kept, with the reason, e.g. no streak counts, no "seen" pressure),
      and what is polish. Each claim marked as researched, seen in a
      shipping app, or my inference.
- [ ] The cheap, clearly right ones built tonight. The ones that change
      how the app feels or what it promises go to you as a short list with
      a recommendation, not built behind your back.
- [ ] Written to `docs/qol-research-2026-10-13.md`.

## 8. Before the morning build

- [ ] The full suite, every walk, and an independent review of the crew
      changes (crew code always gets a second reader before it ships).
- [ ] Build 138 to TestFlight for you only, with notes saying what to try.
      Anything not finished is written at the top of the notes and of my
      morning message.

## What I will not do tonight

- Add a field to iCloud. A friend chat is built from what crews already
  store; anything that needs a new field waits for your Console deploy.
- Send anything to Friends, or change the App Store listing.
