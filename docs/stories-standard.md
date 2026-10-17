# The stories standard

Written 2026-10-17 for the owner's request: "start on the social stories layer
... keep iterating until it meets a clear set of requirements ... test for
anything and research heavily ... improve the design and function to the max
while keeping the app consistent and minimal."

This is the bar Tonight's Story is held to. Each rule names how it is
measured. `StrataUITests/StoryStandardTests.swift` drives the rules a machine
can check with real input on a seeded night; the rest are checked by looking
at the screenshots, and say so. Tags: **(a)** primary doc or paper, **(b)**
shipping product or press, **(c)** inference. The research is summarised at the
foot.

## The rules

| # | Rule | Measured by | Status |
|---|---|---|---|
| 1 | **Nothing you are doing is cut off by the timer.** The story waits while your finger is down, while the "..." menu or the reply's + menu is open, while the keyboard, a sticker or a doodle is up, and while a dialog shows. Slowly, as a parent would: an 8 second hold, a menu left open 7 seconds. | `testAHoldOfEightSecondsKeepsThePage`, `testStoryWaitsWhileItsMenuIsOpen`, `testStoryWaitsWhileThePlusMenuIsOpen`, `testTypingHoldsTheStoryAndTheCardKeepsItsSize` | met: 8s hold, ... menu, + menu, typing each keep the page (probes) |
| 2 | **The keyboard never moves or squeezes the picture.** The story stays where it is and dims; the reply rides the keyboard. (b: Instagram) | the same test reads the card's frame before and while typing | met: the card 718pt before and while typing (probe) |
| 3 | **A hold shows the picture alone.** Held, the bar, the name and the reply fade away; let go, they come back. (b: WhatsApp hides the name on hold; Instagram the chrome) | screenshot while held | met: held, the chrome is unseen, untouchable and unspoken; a tap where the close stood leaves the story open (probe) |
| 4 | **Words get time to be read.** The high, low and buffalo page stands by its length, not a photograph's 5 seconds. (a: WCAG 2.2.2; c) | unit test on the duration | met: 2s plus a third of a second a word, 5 to 12s (`StoryTimingTests`) |
| 5 | **Every send says where it went**, in the reply's own place, for a moment ("Sent to Sam"); one light haptic on a send or a heart, none on a page tap. (a: Apple, haptics for significant moments) | screenshot after a reaction | met: Sent to Ana, 1.8s; the blue Send key sends (probe) |
| 6 | **The timer waits for the picture.** A page whose photograph is still loading does not spend its time on a blank. (b: Instagram holds the bar until media is ready) | unit test or code read | met: the bar holds until the picture is on screen, 2.5s at most (code read) |
| 7 | **The next picture is ready before you get there.** The next page's and the next friend's first photograph are decoded ahead. (a: Meta's adjacent preload, 2026) | code read | met: this friend's next photograph and the next friend's first decode ahead (code read) |
| 8 | **Rings tell watched from new, everywhere and across restarts and devices.** Resume at the first page not yet watched. | existing unit tests (`TonightsStoryTests`), screenshot of the row | shipped earlier |
| 9 | **A reply or reaction lands in your conversation with them**, and you are told so. | `replyToStory` / `doodleToStory` read | shipped earlier |
| 10 | **Never a count, a viewer list, a time posted or a read mark.** | code read, screenshots | shipped earlier |
| 11 | **Consistent and minimal:** the app's glass, type, radius and dark camera framing; no shadows on chrome; no new colours; nothing added that a rule above does not ask for. | screenshots, looked at | every pass |
| 12 | **Accessible:** VoiceOver pauses the story and pages by swipe; Reduce Motion cross-fades; the largest text does not break the reply. | screenshots at the largest size, code read | met: capped at the camera's xxLarge; the reply field whole at the largest size (probe) |

## Log

The first measurement, against Build 161, failed rules 1 and 2 four times:

- An 8 second hold moved Ana's story from page 1 to page 2. `onLongPressGesture`
  reports `pressing = false` when the hold is recognised (0.25s), not when the
  finger lifts, so a hold paused the story for a quarter of a second.
- With the "..." menu open for 7 seconds, the story moved on underneath it.
- With the reply's + menu open, it moved two pages, into the next friend: what
  the launch pass called "the timer cuts off reactions".
- With the keyboard up, the card went from 718pt tall to 365pt, and the words
  page's drawing slid over its words and the bar.

Then, fixed and measured the same day:

- The hold is `TouchHeld`, one UIKit recogniser for the tap and the hold:
  a SwiftUI drag from no distance won over the swipe down to close, and a
  recogniser beside the tap began only on lift. Taps, the swipe across and
  the swipe down are probed.
- The keyboard: the pages ignore it, and the reply rides it over the dimmed
  picture; the quick reactions float over the row, never in it.
- Their name in a story opened from their page did nothing: it brings you
  back to them now.
- A two-person chat read "New Crew" over a story reply until the friend's
  phone joined it: `chatName` names it for the friend.
- A story reply carries the story beside it in the conversation, its photo
  or its colour, while the story is on (`SocialStore.storyAnswered`): found
  on each phone from the stories it already holds, by who posted it and the
  title the reply carries, so nothing new is sent and no record changes. The
  quote wraps to two lines beside it so the title is not what is cut.

Later the same day:

- **A story grows out of the ring it was opened from and goes back into the
  ring of whoever is showing when it closes**, the X, a swipe down or the end
  page alike (`GrowsFromRing`, one animatable progress: scale, place and a
  circle the ring's size opening to the screen). Built by hand, not with the
  zoom transition iOS 26 is reported to flicker on after a drag (b, Apple
  forums). Filmed at 60fps: the open about 25 frames, the close about 15,
  ending as a circle on the ring. Reduce Motion fades. The cover presents
  with no motion of its own so this is the only one.
- **A person's head carries the waiting ring before 8pm** on their page, as
  the row's does (the launch pass: "everywhere the ring appears").
- **"Watch story again" is gone on purpose** (the owner, 2026-10-17: remove
  it; "tapping the ring should be enough"): a watched story is replayed from
  the quiet ring on their head or in the row.
- Visual review: the whole stories walk shot in light and dark, end to end,
  from the row to posting your own through the camera card (`testTonightsStory`).
- Note: the 8 second hold probe missed once in a full run under load and
  passes alone (twice) and in three full runs: XCUITest's press starts a
  moment after the page is read, and a page near its end can turn in that gap.

## Research, in short

From a research pass on 2026-10-17 (sources in the session's research report,
summarised here).

- Instagram: tap and hold pauses (a, help centre); replies land in DMs (a,
  Instagram's launch post); a private heart beside the reply since February
  2022, no count (b). The ring is coloured for new; seen accounts fall to the
  end (b).
- WhatsApp: a hold pauses and hides the name; a private heart with no counter
  (b, 2024).
- Snapchat removed auto-advance after a backlash in 2016 (a, Snap newsroom): an
  evening should end, as our end card does.
- Meta (2026): adjacent preload, the next items kept ready, paused under
  device stress (a). Facebook iOS: progressive JPEGs show a usable picture
  sooner (a).
- WCAG 2.2.2: anything that moves on its own for more than 5 seconds needs a
  way to pause it (a).
- Apple (WWDC 2019, 2021): haptics for significant moments, not every tap (a).
- iOS 26: developers report the zoom transition flickers after an interactive
  drag-dismiss (b, Apple forums), a reason not to grow the story out of the
  ring yet.
