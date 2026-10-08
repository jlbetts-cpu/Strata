# App Store metadata

**Nothing here is live.** App Store Connect is the owner's to edit and nothing
in this file has been submitted. Text for him to paste.

## Current: the ADHD positioning (owner-approved, 2026-10-05)

Some Wins is designed with ADHD brains as the target, and says so. It is the
design target, NOT a treatment claim: no word below says the app helps,
improves, treats or manages anything, and the description ends by saying it
is not a medical app. That keeps it clear of guideline 1.4.1 (health claims
are held to a medical standard) and 2.3.7 (metadata must not overclaim). The
reasoning behind each choice is in the app itself, Settings, "Why It Works
This Way" (`Strata/Views/WhyItWorksView.swift`), with its sources.

**Brand rule, still binding:** "habit" and "streak" appear nowhere in this
metadata. Checked: neither word, nor a long dash, is in any field below.

### Name (30 max)

    Some Wins: Daily Photo Journal

30 characters.

### Subtitle (30 max)

    A done list for ADHD brains

27 characters.

### Keywords (100 bytes max)

    diary,planner,friend,group,memory,mood,gratitude,accomplishment,camera,widget,adult,neurodivergent

98 bytes. No word repeats one in the name or the subtitle (Apple
combines the three), no competitor names, singular forms.

### Promotional text (170 max, changeable without review)

    Log the small things you already did. One tap, a photo if you like. Empty days stay empty, and nothing is counted against you.

126 characters.

### Description (4000 max)

1781 characters.

```
A list of what you did, not what you didn't.

Some Wins is a done list. You log the small things you already did, and each one lands as a block on today's tower. Made the bed. Sent the email. Went outside. It counts.

ONE TAP, FROM WHEREVER YOU ARE
Log a win from the Lock Screen, a widget, Control Center or the Action button without opening the app. Or open it and tap the empty slot. Hold and pull for a bigger block when it was a bigger thing.

A PHOTO, IF YOU LIKE
Take a picture with the built-in camera and the photo becomes the block. A picture is the quickest way to remember a moment later. Photos are optional, always.

THE DAY'S JOURNAL
Write a few lines about the day, or nothing at all. Give the day an emoji and it shows on that day in your calendar. Suggest offers one question about something you logged, only when you ask for it. Lock Journal keeps your notes behind Face ID.

MEMORIES
Every day you logged something is a block in your month's calendar. Open a day to see its tower and its photos. Some evenings, a win from a year ago today comes back. Weekly and monthly replays drop every win into one tower you can save as a video.

CREWS, WITHOUT A FEED
Start a crew of up to 8 people and share a tower for the day. React to a friend's win, or say something in the day's chat, and tag the people a win was with. There are no likes, no follower counts and nothing to scroll.

EMPTY DAYS ARE FINE
A day with nothing on it stays empty, and that is all it does. Nothing is counted against you, nothing resets, and nothing nags.

PRIVATE BY DEFAULT
No account. No ads. No analytics. What you log stays on your phone and in your own iCloud. A win reaches a crew only when you send it there.

Some Wins is not a medical app and does not diagnose or treat ADHD.
```

### Screenshot captions, in order

Made 2026-10-07 in the launch film's look; the files are in the launch kit
(`~/Desktop/Some Wins launch kit/App Store screenshots/`, 1320 x 2868). The
first three carry the page (about 1 in 10 people scroll past the third), so
they are who it is for, the mechanic, and the relief.

1. Made for ADHD brains. / A list of what you did, not what you didn't.
2. Snap it. It's a block. / The photo becomes the win.
3. Nothing resets. / Empty days stay empty. Small wins still count.
4. Hit your goal, get a print. / Shake to develop your day.
5. Better with friends. / A private crew. No feed, no likes.
6. Write it down. Doodle on it. / A few lines, or a drawing, for the day.
7. Every choice, explained. / The research is in the app. No account, no ads.

### Categories

- Primary: **Lifestyle**
- Secondary: **Social Networking** (the owner, 2026-10-05; it was Photo &
  Video in the 2026-10-03 plan). Crews are the social half of the app and the
  category says so; Photo & Video put it beside camera and editing apps it does
  not compete with.

### Age rating: one question to answer carefully

Crew **replies are user messaging**: a short free-text line one person writes
to another (`SocialStore.reply`). In the age rating questionnaire, answer the
user-generated content / messaging questions YES. What already limits it, and
can be cited: a reply is at most 80 characters, is seen only by the win's owner
and the writer, clears when the crew's day ends, passes a words check on both
phones (`CrewWords`), and is off for anyone whose age is unknown or who chose
not to say (`CrewAge`); crews have Report and Block (`CrewSafety`). Reactions
are a fixed set of emoji and are not messaging.

---

## History: the 2026-09-23 draft for the 4.1(a) resubmission (superseded)

Kept for the reasoning about the rejection and the reply to App Review. The
name, subtitle, keywords and copy in it are superseded by the section above.


Drafted 2026-09-23. **Nothing here is live.** App Store Connect is the owner's
to edit and this is text for him to paste, once he has settled the name by
saying it out loud a few times.

## The rejection, in one paragraph

Guideline **4.1(a) Copycats**: "the app's metadata contains third-party content
similar to a popular app or game already available on the App Store... This
creates a misleading association with another developer's app." Apple did not
say which part of the metadata, and the account is already under extended
review, so a guess that misses costs another cycle.

The strongest candidate found from outside App Store Connect: **there is
already an App Store app called Strata that captures everyday moments, and its
own feature is called Strata Capture.** Same word, same category, same verb.
Strava was the first guess and is weaker: it is a near-name but a different
category. The head maker was considered and ruled out by the owner as entirely
original work.

Note that the listing already reads "Strata Wins", so **adding a second word is
not on its own the remedy**. The distinguishing word has to be one the other
app cannot claim.

## Name

    Strata Neo

11 characters against the 30 allowed. Clear on the App Store. Chosen because
the owner's brief for the whole design is "that Tokyo neo aesthetic... the
1990s Japanese future": Neo Tokyo is Akira, 1988, and neo simply means new, so
the name points forward while the design language points back at how 1988
imagined forward.

**Before anyone prints it:** NEOSTRATA is a registered skincare mark, fifty
years old, built from the same two roots in the other order, sold in 85
countries. Different trademark class and a different industry, and it is not an
app, so App Review is unlikely to see an association. A lawyer rather than an
agent should confirm the trademark side.

**Both targets have to say it.** Today the app ships as "Strata" on the home
screen and the widget ships as "Strata Wins", because only the widget target
sets `INFOPLIST_KEY_CFBundleDisplayName`.

## Subtitle

    Proof you did something

23 of 30. Superseded the earlier "a photo for every small win", because this
one says what the app is FOR rather than what it contains, and it carries the
brand's whole argument in three words. See `docs/brand.md`. It says what the app does in its own words, names no category that
belongs to somebody else, and contains no comparison.

## Keywords

100 characters, comma separated, no spaces after the commas. **No other app's
name appears here, deliberately**: an irrelevant reference to a popular app in
the keywords is one of the examples Apple gives for this exact guideline.

    win,wins,photo,journal,diary,camera,film,memory,proof,daily,log,blocks,tower,record,evidence

**"Habit" and "streak" are deliberately absent.** The owner: "I don't want to
hear no habit in the description." Both words belong to the commodity category
this app is not in, and "streak" names the scoreboard the whole design refuses.
Losing them costs a little search traffic and buys the positioning.

## Promotional text

170 characters, and it can be changed without a review, so it is the right
place for anything seasonal.

    Photograph the small things that went right. They stack into a tower for
    the day, and the day keeps itself.

## Description, opening paragraph

The rest can follow the existing copy, but the opening has to carry the app on
its own:

    Strata Neo is a camera for the things that went right. Photograph a win,
    and it becomes a block: small, medium or big, in its own colour. The
    blocks stack into a tower for the day, the days keep themselves, and the
    photographs stay on your phone.

Rules the copy is held to, from `CLAUDE.md` and the owner: no em dashes, no
comparison to another app, and nothing that reads as watching or surveillance.

## The reply to App Review

Send in Resolution Center, with the resubmission. Short, factual, and it asks
the question rather than guessing twice:

    Thank you for the review. We have renamed the app to Strata Neo and
    updated the name, subtitle, keywords and screenshots so that the listing
    describes only our own app and references no other developer's app or
    product.

    We were not able to identify which element was read as third-party
    content, and we want to fix the right thing rather than guess. If any part
    of the metadata still creates a misleading association, please tell us
    which element it is and we will change it immediately.

    All artwork, photography, icon and interface design in this app is our own
    original work.

## What else to check before resubmitting

- **The screenshots.** They are metadata too. Nothing in a screenshot may show
  another app's interface, name or icon, including anything visible in a status
  bar or a share sheet.
- **The app preview video**, if there is one, under the same rule.
- **The support and marketing URLs.** `tasks/app-store-readiness.md` records
  that `strataapp.co` did not resolve at all. A dead support URL is its own
  rejection, separate from this one.
- **The widget's display name**, which today says something different from the
  app's.
