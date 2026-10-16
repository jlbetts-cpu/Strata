# The evening of 2026-10-15: what changed, and what is yours

Builds 147, 148 and 149 went to TestFlight for you (148 at 10:13pm with Tonight's Story, 149 at 10:30pm with its 8pm cue). None is with Friends.

## Left for you

1. **Two compliance steps outside the app**, before the social layer (your pick: compliance first):
   - Choose where to sell 1.0. The audit suggests the US, Canada and New Zealand first.
   - Register with NCMEC, and in the CloudKit Console untick Read and Write for Creator on `Report` in Production, so a reporter cannot edit or delete a report.
2. **Tonight's Story is built** (your /goal moved it ahead of the compliance steps): `docs/superpowers/plans/2026-10-15-tonights-story.md` has the 17 requirements and where each stands. @names and personal crews (slice 1) are not built. The evening violet is a starting value, yours to pick.
3. **An illustration for an empty day**, in your hand. The empty states are one component now (`EmptyPageLine`), so the drawing can go into all of them at once.
4. **Check on your phone**, because the simulator cannot show these:
   - A swipe down on Add a Win with words typed is held and says nothing; Cancel asks. Asking on the swipe needs a device to verify, so it was not shipped.
   - The hold menu on a Memories photo: Open and Share.
   - The chat's speed with your real crews.
5. **Friends on build 146 or older** see a photo sent with Send a Photo as a sticker until they update.

## Built tonight

**The chat**
- At rest a flush bar; it opens as a sheet at full height only, and a drag down puts it back.
- Typing redraws only the field: SwiftUI's change log showed 31 of 31 keystrokes redrawing the chat before, 0 after.
- Thread and field are one column. The keyboard keeps the newest line in sight and every send lands above the field.
- The + is a system menu (Add a Win, Send a Photo, Make a Plan, Send a Sticker, Send Today's Strip), and what it opens comes over the chat.
- Swipe a line right to reply; hold a line and the thread dims around it.
- Two texts in a row both go (the pacing was one a second, and the second came back to the field).
- Measured with nothing driving the app: the first frame after opening or closing is 16 to 28ms; the old drawer took 170 to 435ms. Two causes of the lag were in our code: the photo policy asked the system on every row of every draw, and the word check re-ran on every line.
- The resting bar shows each kind of line as itself, walked in 17 variations.

**Crews and profiles**
- Swipe back from anywhere on a crew, and pull to refresh it.
- Today's heads carry a small green dot for a win today.
- A friend's profile shows their score and wins (from a separate sealed Score record), their tower today, and their recent photos together.
- Your Score is Your Stats: this week against last, the streak, and the record.
- A block now reaches Some Wins as a report, and a crew you did not start can be blocked and left in one step. The privacy policy says so, in the app and on the site.

**Wins, Memories and the journal**
- A Wins block opens the carousel; Edit and Delete are in its ⋯.
- The journal keeps everything behind one +: Write My Day (drafted on the phone from the day, to edit), a question, a sketch, a sticker. A chosen sticker sits on the page.
- Photos close with a drag down. A past day names itself in the middle of the bar. Empty pages all speak one way.
- One loader, drawn and erased in the block colours.

**Checked**: the unit suite (1,600+ tests), the tower, touch-target and launch UI tests, light and dark screenshots of every change, and two code reviews with their findings fixed.
