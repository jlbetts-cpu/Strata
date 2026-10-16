# Tonight's Story: the first slice, and what it must meet

From `docs/superpowers/specs/2026-10-15-stories-and-friends-design.md`, sections 1 to 3 and 7, built ahead of slices 1 and 2 at the owner's word (2026-10-15: "can you please start on the social stories layer as well"). Friends are, for now, the people you share a crew with; @usernames and two-person crews (slice 1) come later and do not change what is built here.

## Route

- **No new CloudKit type, no Console deploy.** A story win is a sealed record of a new kind, `Story`, written into each crew you are in, sealed with that crew's key, as every crew item is. Friends' phones collect stories from every crew and show each win once.
- **Its fields** are a shared win's (title, colour, icon, size, photo derivative, times) plus `endsAt` (noon on the poster's next day, sealed) and `day` (the poster's date it belongs to).
- **Reactions** are ordinary reactions on the story's win id, in the crew it was read from; they land on the poster's block through `SocialStore.reactionsForMyTower`, as a crew win's do.
- **Reply** opens the chat of a crew you share with the poster, with the win quoted.

## Requirements (each one checked on screen or in a test before it counts)

**Posting**
- R1. Add a Win has its own row, under the block, at the foot: an outline in the evening colour with SF `sunset` reading "Add to Tonight's Story"; on, filled, "On Tonight's Story", with "Your friends see it from 8pm. Gone by morning." under it. Off for every new win. Hidden with no crew.
- R2. Under 16, with a photo: "Your friends see the block, not the photo." and no photo is sent.
- R3. Editing a story win shows it on; turning it off, or deleting the win, removes the story from every crew at once.
- R4. Only today's wins. A story's records are deleted by the poster's phone after `endsAt`.

**Seeing**
- R5. A story opens to friends at 8pm in the viewer's zone on its day, and is gone at 9am the next morning, or at `endsAt`, whichever is first. Marked after 8pm, it shows at once. Your own story shows to you at any time.
- R6. Before 8pm, a friend with something waiting tonight wears a thin unlit ring in the evening colour. No count, anywhere.
- R7. From 8pm, the head becomes a circle cropped from their first story photo, with a lit ring and their head small at its edge; with no photo, the block's colour and icon. Watched, the ring goes thin and grey. Unwatched first, newest first; then watched; then everyone else.
- R8. You, with a story, are first in the row as "Your Story".

**The viewer**
- R9. Full screen, one win a page, segments at the top, the photo with the block's label at the foot (title, size, colour). It advances on its own, pauses on a hold, taps on and back, swipes across to the next friend, and closes with a swipe down.
- R10. The same reactions as a tower (the row, + and the sticker; a double tap is a heart), and Reply, which opens the crew chat with the win quoted.
- R11. ⋯: Report, Hide Their Story (tonight), Block. Never who viewed or how many.

**One tower**
- R12. A reaction on a story shows on that block on the poster's Wins tower, and stays after the night.
- R13. A friend's profile shows their story wins edged in the evening colour after 8pm.

**Standard**
- R14. Light and dark, Reduce Motion, VoiceOver labels on every control, 44pt targets.
- R15. Smooth: no frame drops when the row swaps to previews or the viewer pages; photos decoded off the main thread at the size drawn.
- R16. Copy passes `docs/voice.md`: no long dashes, no exclamation marks, nothing that reads as watching.
- R17. Tests: the clock windows, the record round trip, collection and order, expiry, the teen rule; UI walks for posting, the row in each state, the viewer, a reaction and a reply.

## Status, 2026-10-15 night (commits 6dd86ba, c9abfbe)

| | Met | How it was checked |
|---|---|---|
| R1 | Yes | Walk `testTonightsStory` 9 and 10, light and dark; off for a new win, on for an edited story win |
| R2 | Yes | `TonightsStoryTests.teenSendsTheBlock`: the record carries no photo; the line shows under the row |
| R3 | Yes | `postAndWithdraw`, `deleteTakesItOff`; the save observer keeps a story win current crews or none |
| R4 | Yes | `notYesterday`, `sweep` (the poster's phone deletes it past its end) |
| R5 | Yes | `windows`, `hardEnd` (New York, Honolulu), the walk at `-strataStoryHour 21` and `15` |
| R6 | Yes | Walk 8: thin unlit ring, no count; brightened to 55% after the dark capture |
| R7 | Yes | `order`, `onceAcrossCrews`; walk 0 and 6 (watched go grey and move after) |
| R8 | Yes | Walk 0 and 11 (posted from Add a Win, first in the row) |
| R9 | Yes | Walk 1 to 3: segments, tap on, auto-advance to the next friend, swipe down |
| R10 | Mostly | Bar, +, sticker, doodle and Reply into the crew chat with the win quoted. **No double-tap heart**: a double tap delays every tap-forward by the double-tap wait, and the hold is the pause; the heart is one tap in the bar. Reply goes to the crew it was read from until personal crews exist (slice 1) |
| R11 | Yes | ⋯: Hide Their Story, Report, Block; nothing about who watched |
| R12 | Yes | `reactionStays`: Sam's reaction stays on the block after the story and Sam's record are gone |
| R13 | Yes | Walk 7b: the story block edged in the evening colour on the friend's profile |
| R14 | Mostly | Light and dark looked at; VoiceOver labels and an adjustable action on the page; 44pt controls. Reduce Motion: cross-fades; not yet walked with it on |
| R15 | Yes | Photos decode off the main thread at the drawn size (`CrewPhotoView`); the segments redraw alone |
| R16 | Yes | Strings checked against `docs/voice.md` |
| R17 | Yes | 12 unit tests; one walk covering posting, the row in each state, the viewer, a reaction, a profile |

**Not built yet:** the row on the camera's review (camera changes go to the owner first); the evening cue saying "Tonight's stories are open." on a night with a story; the Locket-style widget preview.
