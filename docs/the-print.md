# The print

Research for "make all the wins look like that when you click and interact
with them", 2026-09-22. Figma node `13258-6988` in the Apollo file.

## What the design actually is

Not a Polaroid. Pulled out of Figma rather than read off the screenshot, and
the two are different:

- **342 x 452** — a 3:4 portrait.
- **Full-bleed photograph**, `object-cover`. There is no white frame and no
  caption band. What looked like a border in the render was the wall in the
  photograph.
- **8pt corner radius.**
- **A 0.2px `#e4e4e4` hairline** round the edge.
- **"Apollo." bottom-right**, 66 x 22, 16pt in from both edges, at 80%
  opacity.

So it is a PRINT, not a Polaroid: the photograph, squared off to one format,
signed in the corner. That is what "clean and modern with just subtle
branding" turned out to mean, and it is a better fit for this app than a
white-framed Polaroid would have been — a caption band would have put type on
every photograph, and he has already ruled that out once ("the titles
shouldn't be on the cards with photos").

## The format is the point

3:4 is a crop, and the app's wins are three different shapes (1x1, 2x1, 2x2).
Fixing the print at 3:4 means every win comes out the same object regardless
of what it was shot at — which is exactly what a film format does, and is the
reason a shoebox of prints looks like a set.

It also resolves a tension rather than creating one. **Size reads while you
are browsing; format reads when you are holding one.** The folder's cards stay
three sizes because that is where size means something; the print is one shape
because that is where the photograph means something. The two are deliberately
different and each is right where it is.

The crop is not arbitrary: `HabitLog.cropPositionX/Y` already stores where the
owner dragged the frame, and the print must honour it.

## Where it goes

The test is whether a photograph is being **presented** or **browsed**.
Presented: one image, held still, looked at or sent. Browsed: many images at
once, scrolling. A frame that is right on one is noise on the other — repeat
a hairline and a corner radius twenty times down a scroll and the eye starts
reading frames instead of pictures. His own instinct, "not when you are
scrolling through the photos", is the correct rule and this is why.

**Presented — the print belongs:**

| Surface | Why |
|---|---|
| Tapping a win | His specification, and it fixes a real gap — see below |
| `PhotoViewer` (909 lines, full screen, reached from Memories, day albums, replays, collections) | The one screen in the app whose entire job is one photograph |
| The camera's review, after the shutter | The moment a frame becomes an Apollo photograph; it pairs with the blink |
| `ReplayFrame` | A replay is single photographs held one at a time |
| Sharing / export | The one place the mark is doing real work |
| The feed, later | One post is one print |

**Browsed — it does not:**

`WinCardFace` in the folder's stack and in the masonry inside it,
`PhotoGalleryGrid`, `AlbumCoverView`, the map's markers, the replay shelf.

## The gap it fixes

**Tapping a win today opens the edit sheet.** `expandedBlockID` routes to
`AddWinSheet` in editing mode — a form. On a photograph-led app whose premise
is looking back at what you did, the first thing a tap gives you should be the
photograph, not four fields about it. The print is the fix: tap shows the win,
and editing is one step further in rather than the only destination.

## The mark, and the one caution

Putting a wordmark on every photograph is the thing most likely to go wrong
here. It is a signature where the image LEAVES the app — a share, an export,
a friend's feed — and it is a watermark where it does not, because the person
looking at it already has the app.

So the component takes the mark as a parameter rather than baking it in.
Recommended on: share and export, the feed, and the camera's review. Optional
and lower on: the in-app viewer. That keeps it a signature.
