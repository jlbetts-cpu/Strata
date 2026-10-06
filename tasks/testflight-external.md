# TestFlight: the "Early friends" external group

Drafted 2026-10-06 for **build 82** (version 1.0). Steps for the owner in App
Store Connect. Nothing here has been done or submitted.

What testers get that the App Store will not (yet): **Crews are on in every
TestFlight install** (`CrewsFlag.isTestFlight`, the sandbox receipt). Plus is
not gated, so testers see everything.

---

## 0. Before you start (10 minutes, saves a rejected review)

- [ ] **CloudKit Production schema is deployed.** TestFlight builds use the
  Production CloudKit environment, not Development. CloudKit Console >
  `iCloud.JaydenBetts.Strata` > Schema: deploy every record type the crews use,
  including `CrewMessage` (the day chat, CLAUDE.md "Crews") and `Report` with
  its create-only security roles (`docs/crews-app-store-privacy.md` section 4).
  Without this, crews fail for testers in ways that look like bugs.
- [ ] **The privacy policy URL resolves on a phone** and shows the 5 October
  2026 page (`docs/privacy.html`). Beta App Review opens it.
- [ ] **Export compliance** is already answered in the build
  (`ITSAppUsesNonExemptEncryption = NO`), so no prompt should appear. If one
  does, answer: uses only Apple's standard encryption, exempt.
- [ ] Build 82 shows as **Complete** (processed) under TestFlight > iOS Builds.

## 1. Fill Test Information (once per app)

App Store Connect > Apps > Some Wins > **TestFlight** tab > left sidebar >
**Test Information**.

- **Beta App Description** (paste):

  > Some Wins is a done list designed with ADHD brains as the target. You log
  > the small things you already did, each one becomes a block on today's
  > tower, and a photo can be the block. Write a few lines about the day, look
  > back at your month, and share a tower for the day with up to 8 people in a
  > crew. No account, no ads, no analytics. Some Wins is not a medical app and
  > does not diagnose or treat ADHD.

- **Feedback Email:** `<your feedback email>` (the app's own Send Feedback uses
  jbett5@hotmail.com; use that or a dedicated inbox). Screenshots testers send
  from the TestFlight app also land in App Store Connect > TestFlight >
  Feedback.
- **Marketing URL:** optional, leave blank until somewins.app is live.
- **Privacy Policy URL:** the live `docs/privacy.html` URL.
- **Beta App Review Information:** your name, phone and email. **Sign-in
  required: off** (there is no account). In **Review Notes** paste:

  > No sign-in. Crews use iCloud sharing: tap Crews at the top right of the
  > Wins tab, agree to the rules, and start a crew; it works with one person.
  > Report, Block, Hide for Me and Mute are in the photo viewer menu, a held
  > chat message, and the crew's details. Photos are checked on the device
  > with Sensitive Content Analysis before they are sent.

- Save.

## 2. Create the group

1. TestFlight tab > sidebar > **External Testing** > the **+** beside it
   (or "Create Group").
2. Name: **Early friends**. Leave "Enable automatic distribution" off, so each
   build you hand them is a choice.
3. Create.

## 3. Add build 82 and the What to Test text

1. Open **Early friends** > **Builds** > **+** (Add Build).
2. Pick **1.0 (82)**.
3. In **What to Test**, paste the text in section 5 below.
4. Tick **Automatically notify testers**.
5. **Submit for Review.** The first build of a version goes through Beta App
   Review (usually within a day or two). Later builds of 1.0 are often
   approved straight away.

## 4. Invite testers, with a cap

Wait for the build's status to read **Approved** (or "Ready to Test").

**By email (best for friends you know):** Early friends > **Testers** > **+**
> Add New Testers > first name, last name, email. They get an email with a
TestFlight link. Start with **10**.

**By public link (best for a group chat):** Early friends > **Testers** >
**Create Public Link** > turn on **Limit number of testers** and set
**25**. Copy the link. Anyone with it can join until 25 have; turn the link off
when you have enough.

Keep it small. 10 to 25 people you can talk to beats 200 strangers: you need
to ask follow-up questions. Two or three of them should be in a crew together,
or crews never get tested.

Then send the feedback form (section 6) in the same message as the invite,
and again on day 3.

Notes:
- The app runs on iOS 18 and up. On iOS 18 the age prompt is not
  asked (it needs iOS 26) and the person is treated as "rather not say", so
  they send no photos to a crew. Ask testers to be on iOS 26 if crews matter.
- Builds expire after 90 days.
- Testers' age answer currently fails on TestFlight (the Declared Age Range
  capability is not on the App ID yet) and the app treats them as adults, so
  photos travel. Fine for invited adults; fix before the App Store.

---

## 5. What to Test (build 82)

Paste as is. 2,115 characters of the 4,000 allowed.

```
Thank you for trying Some Wins. It is a list of what you did, not what you didn't. Log small things you already did and each one lands as a block on today's tower.

Please just use it for a few days the way you would. Below is what is new in this build. Anything that feels confusing or like work is the most useful thing you can send.

DRAWING
The journal sketch, the month drawing and a doodle on a friend's win share one pen.
- Draw a stroke and keep your finger still for a moment: a nearly straight line straightens, a closed loop becomes a neat circle or oval. A scribble stays as drawn.
- Pinch to zoom in, up to 4x. Two fingers move the page.
- Tap with two fingers to undo. The undo button is still there too.

THE DAY'S JOURNAL
Open the journal from the Wins tab. On a day with photos, a row of that day's win photos sits above the note. Press one and Suggest asks you a question about that win. It never writes for you.

TODAY'S PHOTOS
In Add Win, press the tile beside the block. Today's photos run sideways at the block's size. Press one to put it on the block. It asks for photo access once, only then.

UNDO
Delete a win and it goes at once, with Undo for 5 seconds. A win you drag out of the slot also gets Undo.

LOG FROM THE REMINDER
Turn on the daily reminder in Settings. When it arrives, press and hold it and pick Quick, Regular or Deep. The win is logged without opening the app.

CREWS
Crews are on for testers. Tap Crews at the top right of the Wins tab, start one and invite people from the share sheet. Up to 8 people share a tower for the day.
- Hold a friend's block to react, or double-tap for a heart.
- The day chat is in the top right of a crew. It clears at the crew's midnight.
- If anything feels wrong, Report and Block are in the crew's details and on a held message.

WHAT HELPS MOST
- The moment you first felt unsure what to do.
- Anything you pressed that did nothing.
- Whether you opened it on the second day, and why.

Use Send Feedback in Settings, or take a screenshot and share it with TestFlight.

Some Wins is not a medical app and does not diagnose or treat ADHD.
```

---

## 6. Feedback form (paste into Tally or Google Forms)

Title: **Some Wins, first week**
Intro: "Six short questions. There are no wrong answers, and short is fine."

1. **In one sentence, what is Some Wins for?**
   Short answer.
2. **What was the first moment you were not sure what to do?**
   Paragraph. Helper text: "The screen, and what you expected to happen."
3. **Would you open it again tomorrow?**
   Multiple choice: Yes, without a reminder / Yes, if something reminded me /
   Maybe / Probably not.
   Follow-up (short answer): "What would make it a yes?"
4. **Did anything make you smile?**
   Paragraph. Helper text: "A sound, a moment, a word, anything."
5. **What felt like work?**
   Paragraph. Helper text: "Anything that took more steps or more thinking
   than it should."
6. **Did you use a crew?**
   Multiple choice: Yes, with people I know / I started one but no one joined
   / No, I did not want to / No, I did not find it.
7. **Anything else?** (optional)
   Paragraph.

Optional, at the end: "Do you have ADHD, or think you might?" Yes / No / Rather
not say. Keep it optional and last; it is for reading the answers, not for
screening anyone.

**Reading the answers:** sort question 2 and 5 answers by screen; two or more
people naming the same screen is a fix, one is a note. Question 1 is the
5-second test again, after a week (`tasks/app-store-page.md` section 3 has the
scoring). Question 3's "if something reminded me" is the reminder's case, not a
failure.
