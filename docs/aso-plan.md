# App Store plan for Some Wins (research, 2026-10-03)

Research only: nothing submitted or changed in App Store Connect.

## Rules that bind it
- "habit" and "streak" are kept out of the name, subtitle, keywords and
  description (docs/brand.md §2, tasks/app-store-metadata.md).
- No competitor names (guideline 2.3.7); singular forms; never repeat a word
  across name, subtitle and keywords (Apple combines them).
- `tools/name-check.py "some wins"` flags RISK (Wink, Instagram surface in the
  search). The name itself is free: no app, no USPTO mark. Search it on a
  phone before submitting; a descriptive suffix anchors it.

## Positioning, chosen 2026-10-05
**ADHD as the design target, not a treatment claim.** Subtitle "A done list
for ADHD brains"; the full set is in `tasks/app-store-metadata.md`. Why: the
app's choices (a list of what you did, logging at the point of performance,
an immediate block, no penalty for an empty day) are the ones the ADHD
literature argues for, and saying who it is designed for is a sharper
position than "photo journal". Why NOT a claim: guideline 1.4.1 holds health
claims to a medical standard, and 2.3.7 rejects metadata that overclaims, so
nothing says "helps", "treats" or "manages", and the description ends "Some
Wins is not a medical app and does not diagnose or treat ADHD." Secondary
category changed to Social Networking (owner, 2026-10-05).

## Metadata (counts measured)
**Chosen 2026-10-03: A. Superseded on 2026-10-05 by the positioning above.**

A (recommended, chosen)
- Name: `Some Wins: Daily Photo Journal` (30)
- Subtitle: `Small wins, kept with friends` (29)
- Keywords (95 bytes): `proof,done,list,accomplishment,gratitude,diary,camera,tower,share,group,recap,memory,motivation`

B: `Some Wins: Photo Diary` / `Proof you did something` /
`small,daily,journal,done,list,accomplishment,gratitude,camera,tower,block,friend,share,recap,memory`

C: `Some Wins: Win Journal` / `Daily photo wins with friends` /
`small,proof,done,list,accomplishment,gratitude,diary,camera,tower,block,share,group,recap,memory`

## Search, as indexed now
Name, subtitle, keyword field (100 bytes), categories, promoted IAP names.
Not the description, not promotional text. Custom product pages can carry
keywords (2025). Ranking also reads downloads, ratings and conversion.

## Category and charts
Charts rank recent install velocity within the category. Lifestyle (primary)
+ Social Networking (secondary; it was Photo & Video until the owner's call on
2026-10-05): the lowest bar for an indie, and no health framing (1.4.1). Productivity is Google, Microsoft and AI apps.

## Launch, in order
1. Featuring Nomination, "App Launch", 3+ weeks ahead.
2. Pre-order (2 to 180 days).
3. Pack promotion into 48 to 72 hours: short videos of blocks dropping, the
   camera, a head on the tower; Product Hunt the same day.
4. Crew invites are the built-in loop (up to 7 installs a crew).
5. An in-app event at launch ("First week tower").
6. A small Apple Ads budget on the name and "small wins".

## Product page
First three screenshots: the day's tower with photo blocks; camera to block;
a crew tower. A preview video starts on the drop. Test icons with product
page optimization. Ratings prompt (3 a year): after a third win on day 3+,
after a first crew reaction, after a first recap; never at launch or by a
paywall. Spanish (Mexico) metadata as a second keyword field.

## Pitfalls
Screenshots show the app in use (2.3.3); previews are screen captures
(2.3.4); no medical claims; the support URL must resolve; have the
trademark cleared.
