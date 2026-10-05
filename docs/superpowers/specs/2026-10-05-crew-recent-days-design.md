# Crew recent days

Owner, 2026-10-05: "being able to see the previous day from the middle menu
or just seeing images from previous days saved in the chat till they are
deleted like recents".

## What he picked

- **Where:** in the crew's middle menu (Crew Info), not a new tab or a swipe.
- **How long:** 14 days, then a day goes.
- **Who deletes:** whoever posted it, or the person who started the crew.
  Anyone can hide a photo for themselves, or report it.

This reverses the 2026-10-02 rule that crew photos are not kept overnight.
What stays: counts are kept on the phone for good (`CrewHistory`), and
photos are never kept in the cloud past their window.

## Why 14 days (research brief, 2026-10-05)

- Every app where friends' posts expire keeps the archive for the poster
  only: BeReal, Instagram. A history the whole group shares is a chat
  pattern: iMessage, WhatsApp, Locket. Retro's rolling 4 weeks is the
  closest fit to a crew.
- Expiry lowers the pressure to post (Xu et al., CSCW 2016). People still
  want to look back, and the paper suggests "permanent but limited" over
  all-or-nothing.
- Space: a crew photo is 1080px, about 300 KB. A full crew posting one
  photo each a day for 14 days is about 35 MB, on the iCloud of whoever
  started the crew. Once that iCloud is full, every post fails, so the
  window is also a safety margin.

## Design

**One place, already there.** Crew Info has a **Days** section: each day
the crew holds, with its win count, played as a video on tap. It becomes
**Recent Days**:

- A tap opens the day itself, not the video.
- The section reaches back 14 days, not about 3.
- Footer: "Wins stay for two weeks. Play a day to save it as a video."

**The day page**, pushed from the row:

- **Title:** the day ("Yesterday", "Saturday", "Sep 28").
- **Top:** that day's tower, read-only, as it stood at the crew's midnight.
  It uses the same blocks as today's tower, so a past day looks like one.
- **Under it:** that day's photos in a 3-column grid, newest first. A tap
  opens the photo viewer with reactions, as today's photos do.
- **Toolbar:** a play button for the day's video, as the row does now.
- **Not on the page:** no counts and no "seen by". The page carries no
  wording that sounds like watching.

**Deleting.** These all live in the viewer's ⋯:

- **Remove from Crew:** shown to the poster (this exists) and to the person
  who started the crew (new). The win goes from everyone's phone.
- **Hide for Me:** a new, local list. It travels with the block and mute
  choices (`CrewChoicesSync`), so it holds on all of a person's phones.
- **Report:** as now.

**Keeping.** `SocialStore.prune` moves its cutoff from the crew's day −3
to day −14. Two caps go with it:

- **Photos:** at most 300 per crew in the window. The oldest past that go
  early.
- **Leaving:** someone who leaves, or is removed, takes their wins with
  them. The store already keeps only members' wins.

**Copy that changes:**

- The privacy texts move from "a few days" to "two weeks":
  `PrivacyPolicyView`, `docs/privacy.html` and
  `docs/crews-app-store-privacy.md`.
- Crew Info's footer, and `CrewHistory`'s doc comment.

## Tests

- `prune` keeps day −13 and removes day −15.
- The 300-photo cap drops the oldest first.
- The crew starter can remove a friend's win. A member who is neither the
  poster nor the starter cannot.
- A hidden win is gone from the day page and the viewer, and it travels
  through `CrewChoicesSync`.
- Capture the day page in the simulator, light and dark, and look at it.
