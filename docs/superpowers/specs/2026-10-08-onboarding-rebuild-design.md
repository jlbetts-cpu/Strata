# Onboarding, rebuilt around the film

2026-10-08. The owner: "we should have the vertical trailer in there and the
screens need to look better rn they fall flat." His picks: a 15 to 20 second
vertical cut; specs then build overnight.

## Evidence it rests on

- Reading tutorial cards does not help: NN/g, 70 users, 91% task success after
  reading cards against 94% skipping them (a). Doing beats reading (HIG).
- A 12 to 15 second clip is watched to the end most often; 18 s 74%, 30 s 47%
  (a, small sample). So 15 s.
- Skip from the first frame; WCAG 2.2.2 wants a stop for motion over 5 s.
  Respect the silent switch (ambient audio). Reduce Motion: a still and Play.
- Ask for a permission in the context it is for (USENIX 2021, (a)): the map
  asks for places when it is opened, not in onboarding.

## The flow: nine pages become seven

| # | Page | What changed |
|---|---|---|
| 0 | **The film** (new) | 15 s, full screen, plays once, Skip top right, sound follows the silent switch, ends into page 1 |
| 1 | **Every win is a block** | the try-it board (was page 2), now first: the "aha" is doing it |
| 2 | Make your head | unchanged, optional |
| 3 | Thank you, genuinely | unchanged, his note |
| 4 | A goal for each day | unchanged |
| 5 | Three you can always do | unchanged, skippable |
| 6 | Your first win | unchanged, LOCKED: it ends on the first win |

Cut, because the film shows them and doing them is better than a slide: the
opening tower picture (the film opens on it), "A win can be a photograph" (the
film's camera), "Every photo keeps its place" (the map asks for places itself,
`MemoriesMapView` "Turn On Places"). Their code stays and is skipped, one
revert from back.

## The look

The titles are centred over the composition, as the film and the App Store
pages set them, still at the top (his 2026-09-23 rule). The rest of each page
is unchanged tonight; the screens to redraw next are the ones he names after
seeing these.

## The film's cut

From the vertical film, on the beat, music from the drop: Every day has
big/medium/small wins; Hit your goal, and your day prints; the strip turns
and the stickers land; Every win. Stacked.; Made for ADHD brains.; the logo
and the name. No App Store badge (it is inside the app). 4.4 MB, 1080x1920,
`Strata/OnboardingFilm.mp4`; the still is `OnboardingFilmPoster.jpg` (the grid).

## Measured

`onboarding_step` (shown, done, skipped by index) and `trailer` (played,
finished, skipped, sound_on) through `Analytics`, so where people leave is
known after launch.
