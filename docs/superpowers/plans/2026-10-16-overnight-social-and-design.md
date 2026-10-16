# The night of 2026-10-16: social first, then the design held to one standard

From the owner's notes as he went to bed (2026-10-16, between about 12:30 and 1:30am). Each item is met only when it has been seen on screen in light and dark, and tested where it can be.

## Social, first

- S1. **A reply to a story goes to your personal chat** ("reply to stories and it go to your personal chat"; "it just goes to your guys personal chat"). Friends who share a crew get a one-to-one crew without setting one up, as a Snapchat friendship has a chat. Sealed to the friend alone.
- S2. **Feedback you can trust** ("make sure there is like indicators ... if you posted or if you sent a message or if you replied ... they should know"). Every send says that it went: a story posted, a win sent to a crew, a chat line, a reply, a reaction. Researched against Messages, Snapchat and Instagram.
- S3. **Hold a head for View Profile highlights that head only** ("the whole bar highlights when it should just be that profile").
- S4. **A stronger story** ("the story design needs to feel stronger"): the viewer and the row, with nothing personal on it (no size, no colour dot).
- S5. **Your own story opens before 8pm; nobody else's does** (already the rule; walked).
- S6. The flows to post a story and to send to friends feel flawless: Add a Win, Next, Send To, Send, and what you see after.

## Design, held to one standard

- D1. **Your Stats, rebuilt** ("an actually interesting looking stats sheet that's actually researched and looks good with interesting graphs that you can interact with"). Swift Charts, with selection.
- D2. **The Wins crest says how many wins today, clearly** ("same as in the pfp middle place, it should be clear how many wins you got for that day").
- D3. **A strict type scale** ("we shouldn't have a crazy amount of text sizes ... very researched and strict"). Audit `Typography`, reduce what the screens touched tonight use to the scale, and say the scale in one place.
- D4. **Screens not up to standard, cleaned** ("really hone in on design and cleaning up screens that aren't up to standard"), social screens first.

## Rules that hold all night

Ink chrome, colour only in blocks and photos; no shadows on chrome; one component per job; no em dashes or exclamation marks; nothing that reads as watching; camera changes go to him first; no new SwiftData stored fields; crew cloud code is reviewed before it ships.

## Status, 2026-10-16 midday (builds 151-152, then main)

- S1-S6: done (personal chats, send feedback, single-head hold incl. Your Story, story viewer, before-8pm rule, Send To).
- D1 Your Stats: merged into Profile (one sheet from Memories), ink-only charts, InfoCard facts.
- D2 crest: the count past the goal ("14"), ring closes whole.
- D3 type scale: TypeSweep fails any bare text style; tallies down to heading size; NoCapitalsTests.
- D4 screens: no shadows, titles inside cards in sentence case, Hinge-style InfoCard facts (profile, streaks, photo caption), Memories banner card + calendar card, friend profile = same card.
- Owner adds: story opening as a page with bouncing heads; head personalities removed, six playful moves and moving eyebrows (BrowWarp); tower-to-Memories one block at a time; photo zoom fills the screen; Instagram one-tap share (needs Meta App ID); usernames (unique, monthly change, in setup and Edit Profile; under review).
