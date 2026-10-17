# Launch pass, 2026-10-16: decision log

Tags: (a) research, (b) seen in a shipping app, (c) my inference.

## 0. The floating tower
- Not reproducible in the simulator at 1, 3, 10 or 30 wins, after home and back, across tabs, with a sheet and the keyboard. (c)
- Root cause found by forcing it: the tower's minimum height came from a page measurement taken outside its scroll view. A scroll view's content shorter than the view sits at the top, so whenever that measurement came back short the tower rose with a gap below. Forced short, it floats 300pt: the screenshot's symptom. (c, measured)
- Fix: the scroll view's own visible height is the floor (`TowerFloor`, `containerRelativeFrame`), on the Wins tower and every crew tower. Walk `testTowerFloorAfterReturning` measures the tower's foot; its self-test turns the floor off and sees it float, so it can fail.

## 10. Rare bugs that lose data or trust (audit, then fixed)
- Restore during an iCloud import doubled every win for good: merged by id after each import; restore skips a win that arrived meanwhile.
- Undo after delete didn't re-share to crews or the story: it does now.
- Signing out of iCloud and back in erased crew history and offline lines: set aside per account and merged back.
- Day keys froze in the zone the app started in (a flight): read the zone per call, reset the system zone on change.
- "Your iCloud is full" for crews was wrong: crews live in the app's shared space, so it's said as a wait.
- A delete killed mid-send could miss crew copies: every delete is queued before the first wait.
- A planned win's photo was decoded whole: downsampled.
- A story never reached a friend 16+ hours west: the sealed end is the westmost noon; each viewer's 9am still closes it.
- Not fixed, low: two people accepting at the same moment can make a crew of nine (no server to arbitrate). (c)

## 3 and 3½. Stories, profiles and messages as one place
- A person's page is their profile with your conversation resting at its foot, rising into the full chat like a crew's (`PersonPage`). No separate message thread screen. (b: Instagram story replies land in DMs; Hinge ties a match's profile to the chat)
- Kept: conversations stay as rows in the Crews list, newest first, so an unread one can be found; the row opens the person's page, not a thread. The brief says "no separate DM inbox"; a row in the same list is not a separate inbox. (c) Recommend keeping.
- Their story plays over their page ("Watch Sam's story") and closes back onto it.
- The story timer already freezes for the keyboard, a doodle, a sticker and the reaction bar (`busy`). Verified in code. (c)
- Rings: your own goes quiet once watched; watched on one phone is watched on the other (iCloud key-value store); the nightly sweep no longer forgets the words page's mark.
- High, low and buffalo: a visible, optional row under Tonight's Story on Send To; still in Tonight's Story; editable from your own story.

## 5. Crews
- A crew explains itself: where it is named (what it is, and that one person is a message), and once ever on the first shared tower.

## 5½. Parents
- A slow tap on the empty slot no longer logs a win (0.28s to 0.5s, the system long press). (a: Apple's long-press duration)
- The largest text grows controls instead of clipping; a crew row stacks at accessibility sizes.
- Show Tab Names: a setting, off. Recommend ON by default. (a: Apple HIG tab bars, "Include tab labels"; NN/g icon usability; older adults misread unlabelled icons)

## Add-on: notifications and one planner
- Crews top-left is Activity: reactions and replies to your wins and story, messages, plans, someone joining, grouped, newest first, a quiet dot, no counts.
- One planner on Wins: share the next line with a crew; shared lines say "With Roommates". Crew plans you joined were already lines of your plan, so none moved or were lost.

## Intentional drawing on the tower
- The accident was real and measurable: the slot's drag started on touch down, so a swipe up the tower that began on the slot drew a Deep block and logged it on release. (c, read in code)
- Now three beats: rest 0.35s to arm (UIKit's long press, which hands a moving finger to the scroll, as the crew block hold already does), drag to preview with soft ticks, rest 0.45s at one size to lock (the edge fills round in the block's colour, two faint ticks, a firm one at the lock). Let go early and it springs back, nothing logged.
- Why those lengths: the system long press is 0.5s (a: UIKit `minimumPressDuration` default); Android lowered its own to 0.4s to feel faster (a: AOSP ViewConfiguration commit). Arm plus lock is 0.8s for a Quick, under the one-second limit where an action stops feeling continuous (a: Nielsen's response-time limits). The arm matches the crew hold so one finger learns one length. (c)
- Walk `testOnlyAHeldSlotLogs`: a swipe over the slot, a drag let go early, and a rest let go early log nothing; the same hold kept still logs one, so the test can fail.
- Found while testing: a busy main thread can squeeze a synthetic rest, and the hold rightly refuses to arm. Real fingers are not squeezed; the walks rest a full second.

## Add a Win is the camera (inline)
- The slot, a crew's slot, a chat's Add a Win and the day's cue open a rounded camera card over the dimmed page; nothing tapped to grow from, it rises from the foot. (b: your ChatGPT screens; Photos' thumbnail-to-photo growth)
- Morph: the card's face scales to cover a window that runs from the slot's rectangle and radius to the card's, on one spring (0.42s, a little bounce); close runs back with no bounce. The face dissolves in over the first 0.14s and out over the last of the close, so the slot is what is left, not a tiny picture. (c, filmed frame by frame)
- Filmed at 60fps in the simulator: no repeated frame inside either motion after moving the lens start and location off the first frames; the system sheet on the same film drops one. 120Hz and a real lens need your phone. (measured)
- Before the first frame the card is the slot's own glass, never black. The lens is configured early and never started before a tap, so no camera dot lights up while you look at your tower. (c)
- One camera at a time: a camera that starts stops the last one, which is the Camera tab and the inline one never fighting. (c)
- Shot, then a name if you want it, then Drop (the block itself, in the shutter's shape). Just Words is one tap at the top left; More holds Choose a Photo, Draw It and More Options (the full sheet with whatever the card had). A refused camera opens on words with one tap to Settings.
- The shutter keeps the hold-to-commit rule (`HoldLock`), as on the Camera tab.
- Not moved to the card yet: the full sheet's own Take Photo and a planned win's camera still open the full-screen camera. Chats' + sends pictures from the library only (no camera there today).
- Switch: Settings, Add Wins with the Camera, on. Recommend keeping it on.

## The black tab bar on the Camera tab
- It is a drawing over the real bar (`CameraTabBarSkin`), so the real bar's own drag-between-tabs response happens underneath, unseen. The root fix is the system bar owning the dark look, which is the forced-scheme lag you rejected (0.8s). Not changed tonight; needs a phone to judge. Options: keep the drawing (today), or drop it and let the bar stay light. (c)

## No counts on posts
- A crew block's reactions show one emoji, or two overlapping when more than one person cheered; no number on screen or aloud. Who reacted reads "Sam, Jo and others". (add-on brief)

## Second reader (independent review of crew and messaging since 861aae5), 2026-10-17
Found and fixed:
1. A conversation became unreachable once you no longer shared a group crew: it stays reachable now.
2. Merging duplicate wins withdrew them from every crew and the story: a twin deleted while its id lives is ignored, and the merge saves before deleting the emptied kind of win.
3. Watched stories never left iCloud's shared key-value table (1 MB, shared with blocks): pruned both ways; test added.
4. The camera card's Drop sent to your last crews unnamed: a To chip names them, Drop is the yes, Undo follows.
5. Your own story kept yesterday's wins all of today after the end-time change: yours ends at your own 9am; test added.
6. Unsent crew photos were lost across sign-out: set aside with the outbox, outboxes merged; test added.
7. A plan line the crew didn't get looked shared: it says so now.
8. The Activity dot rebuilt the whole feed every render: cached.
9. A busy camera at warm-up disabled the card for the app's life: only "no camera" is remembered.
10. Undo of a delete dropped who the win was with: kept.
11. A person's page skipped the crews gate: it goes through it.
Not fixed: deleting a shared plan line leaves its line in the crew's chat (needs a withdraw path); the duplicate-merge fix has no end-to-end test (it needs the shared store's save notifications). Checked sound: no schema change, no new server, blocked people unreachable, no presence or read receipts.

## 4. Friends from contacts: researched, not built
- Apple's own route, CloudKit user discoverability (find iCloud users by email or phone in your contacts), was deprecated in iOS 17 and returns nothing for new apps. (a: CKContainer discoverAllIdentities / userDiscoverability deprecation)
- Every other route means sending your contacts' numbers or hashes off the phone to be matched: a server, or the shared crew database, both of which the brief rules out. Hashed phone numbers are reversible by brute force (the number space is small), so hashing is not privacy. (a: published attacks on hashed contact discovery; c)
- So there is no switch to flip. Recommend: keep invites as links sent from Messages (the preview card is already there), and make the invite itself the friend request. An App Clip so a link opens straight into joining is still the best next step (`docs/invites-research-2026-10-13.md`).

## The drop moment
- Checked, not changed: a block lands with its own sound, haptic and settle every time, and the inline camera hands it over while the card folds back into the slot it is falling toward. (c)

## Your calls, 2026-10-17 morning
- Show Tab Names: on by default (the Camera tab's black bar draws the names too).
- Quick Post: stays off.
- The Camera tab's black bar drawing: kept.
- Conversations: kept in Crews, under their own Messages heading after the crews.

## 5. Crews, lived in (2026-10-17, seeded, in the simulator)
- A crew of eight on a busy day: the tower fills warm, reactions sit as one or two emoji in a corner (never a number), and the heads stand in the crest. Nothing cold there. (seen)
- A crew still waiting for a friend: "Just you so far. A crew starts when one friend joins." with Invite, over the first block. Clear. (seen)
- No crews: the owner's drawing, "For the people you'd tell anyway", three plain promises, New Crew one tap away, and the line for a link. It is the recruiting screen it should be. (seen)
- Crews and people now tell apart by shape: a crew is a rounded square (a block), a person a round head; a crew of two shows both faces. (built tonight)
- Thin spots found and fixed tonight: a conversation that became unreachable; Activity flooding on a busy day (now grouped by day and person); a person's page that read like a stats sheet (now the two of you).
- Not walked: a real week of days (the simulator holds one day at a time) and someone going silent for days; reading the code, a quiet member is never named or counted, which is right. (c)

### Best ideas not on the list, ranked
1. **A crew's week, in a card, on the crew's Sunday night** (build first): the week's photos as a strip and who showed up, in the chat, once. It is the "end of a crew's week" moment the brief names, and the personal replay already knows how to make one. (c; b: Strava clubs' weekly summary, BeReal's recap)
2. **The first reaction someone ever gets, made to land**: a one-time note on Activity's first item ("Your first cheer"), the moment that brings a person back. (c)
3. **"Everyone showed up today"**: the crest closes in the crew's colour the first time every member has a win on the same day. Quiet, once a day, no names for who did not. (c)
4. **A late joiner's welcome**: someone joining after the crew's first week gets the last few days' photos as a strip in their first look, so they meet the crew, not an empty tower. (c)
5. **Invite from the tower's empty cells** for a crew of one: the faint cells say "Room for a friend" and are the Invite. (c)

## Profile as the relationship, ranked (built: 1 to 3)
1. No score or count on a person's page. 2. The crews you share, by name, and "Friends here since". 3. Between you two: cheers traded and things you both did the same day. 4. (next) Photos from your conversation, under theirs, while they last. 5. (later) A colour of your own for that person's page, chosen by you, seen only by you.

## 10. App Store blockers (audited 2026-10-17)
- Report and Block: stories, crew chat, crew wins and crews had both. Fixed tonight: Block on any line of a person's in a chat, and Report or Block on a person's page.
- Filtering: the word list both ways and Apple's sensitive content check when it is on. Weak for adults with the check off; acceptable, worth knowing.
- Contact: Send Feedback and the policy's address. App Store Connect still needs a Support URL (yours).
- Reports: you read them with tools/cloudkit/reports.sh; nothing alerts you, and the app promises "looked at within a day". Run it daily.
- Delete everything: Reset All Data now takes you out of every crew and conversation too (crews you started end). Tested.
- Privacy policy: regenerated and true of tonight's app, dated 17 October.
- Privacy labels: the manifest now declares Emails or Text Messages (a reported message reaches you). Match it in App Store Connect: Emails or Text Messages, App Functionality, Linked, not tracking.
- Age gate: present and holds for stories and messages.
- CloudKit, for you to deploy (production schema, Console only): `tools/cloudkit/ban.sh` writes a `BanNote` record type that production does not have, so a ban saves and then the script errors. Add: `RECORD TYPE BanNote (account STRING, reason STRING, GRANT CREATE, READ, WRITE TO "Moderator")`. Nothing else in the app needs a schema change tonight.
- Naming: no user-facing "Strata" left; Plus is "Some Wins Plus" in the app. SomeWins.storekit has only the tips (no Plus group to test locally); check the Plus group's names in App Store Connect.

### The Meta App ID, for Instagram Stories
1. developers.facebook.com, log in, register as a developer (free).
2. My Apps, Create App, use case Other, type Consumer, name "Some Wins", your email.
3. App settings, Basic: privacy policy URL https://somewins.xyz/privacy.html; add the iOS platform with bundle ID JaydenBetts.Strata.
4. Copy the numeric App ID (not the secret).
5. Put it in Strata/Social/InstagramShare.swift, `static let appID = "<ID>"`. The Share to Instagram button appears once it is set.
6. Test on a phone with Instagram. If Instagram says the app is not supported, switch the Meta app to Live (it needs the policy URL from step 3).

## Second reader, rounds three and four (2026-10-17)
Fixed: a kept chat photo posting to a crew nobody named; the camera running after the card went; a chat camera starting location; a snap encoded on the main thread; expired chat photos left on disk; "did it" on the wrong day; Reset's leaving lost offline (now kept and retried); blocking from a page silently removing someone from a group you run; a dead conversation after an unblock; a blank sheet after blocking; a plan line lost in the full sheet.
Not fixed, low: a shareMyself on a 1.5s timer can land a blank member record in a crew being ended by its owner (only matters if Reset ended crews, which it no longer does).

## Waiting for your call
- **Reset All Data and crews you started.** Built: Reset leaves every crew you joined, and keeps crews you started for the people in them, without your wins or name. Ending them would delete their tower and chat too. Recommend keeping it this way; App Review wants your data gone, and it is.
- Show Tab Names on by default (recommended).
