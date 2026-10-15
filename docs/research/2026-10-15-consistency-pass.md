# Look-alike things that look different (consistency pass, 2026-10-15)

The owner's rule, 2026-10-15: "blind understanding: if someone goes through a
flow very similar it should feel the same, it shouldnt feel different or look
any different." And: "liquid glass is our thing, like the clean liquid glass
button and messages; in the plan the bar didn't use liquid glass, that's a key
indicator."

**Method.** Read only. No Swift was changed, nothing was built or run. Each
pair below was found by taking one kind of thing (a sheet's corner, a choice
control, a writing bar, an empty line, a delete, a head) and reading every
place it is drawn, then comparing. Line numbers are as of the working tree on
2026-10-15; other sessions are editing, so search for the quoted code if a
number has moved. Rules cited are `docs/ten.md`'s nine. Nothing here was
looked at on a screen; where a finding is about how something reads, it is a
prediction from the code, and the shot that would prove it is named.

**What is already right, so nobody "fixes" it.** Every sheet's words come
through `sheetAction` (one ink step, 44pt, `SheetAction.swift:54-84`). Every
sheet title comes through `sheetTitle` except the two named in finding 11.
The `drawn:` flag on `sheetTitle` is moot now: `StrataFont.relative` is SF
Bold and `covers` is always true (`Shared/StrataFont.swift:85-107`), so "Add a
win" and "Plan with Sam" are already the same face. The writing bar is one
look in all four places (Plan, Journal, crew plan, chat): `glassField` plus a
glass Send. Leave Crew asks the same question from the list's swipe and from
the crew's details. Deleting a win offers Undo from both doors (the edit sheet
and the photo viewer). Head disc sizes agree everywhere they mean the same
thing (finding 16).

---

## The ranked list

Ranked by how soon a first-time user would see it, not by how much code it
is. "Standard" is the one the others should become.

### 1. Add a win has two choice bars in two materials, one above the other

- **Glass:** "Plan for Later" opens `GlassChoiceBar`, a 44pt glass capsule
  with a sliding `chosenFill` pill (`PlanScope.swift:274`,
  `GlassChoiceBar.swift:46-50`).
- **Not glass:** Quick / Regular / Deep under it is `Picker(.segmented)`
  (`AddWinSheet.swift:1844-1856`), drawn by the UIKit appearance proxy as a
  flat well with a flat thumb (`EtherealControls.swift:70-78`), 32pt tall.
- **The same flat control again** on Your Score and on a crew's page, Day /
  Week / Month (`WinTrendSection.swift:80-86`, reached from
  `ProfileHeader.swift:150` and `CrewStatsSections.swift:220`).

Two drawings of "choose one of these words" (rule 1), one of them under 44
(rule 5). `EtherealControls.swift:43-66` is the written exception for the
32pt height; it was written when nothing else in the app was a segmented
bar, and it rests on "the control stays Apple's". The owner's 2026-10-15 call
makes the glass bar the app's control, so the exception's premise is gone.

**Standard:** `GlassChoiceBar` (the owner's own pick, 2026-10-15; rule 1).
**Smallest change:** give `GlassChoiceBar` a `fills` mode (equal widths, no
scroll, no edge fade) for three fixed words; use it for Size and for Wins per;
drop the four `UISegmentedControl.appearance()` lines. It already gives the
tick, the selected trait and the 44pt height. What is lost is VoiceOver's
adjustable swipe on the segmented control; `accessibilityAdjustableAction`
on the bar puts it back (rule 9).
**Proof shot:** `testFlowsPass` already opens Add with a photo; add one with
"Plan for Later" pressed.

### 2. The day sheet's Plan / Journal switch is plain words, directly over the new glass days bar

`DaySheet.swift:442-468` draws the two tabs as two words with only the ink
moving, in the title slot. Under it, the first thing on the Plan tab is
`PlanScopeRow` (`DaySheet.swift:512`), which became a `GlassChoiceBar` today
(`PlanScope.swift:116-125`). Two "pick one" rows stacked, one glass and one
not.

**This one is LOCKED** in `docs/design.md` (2026-10-05: "no capsule, no glass,
no segmented control"), and the owner chose it after "the tabs i feel like
look a little off". It needs his call, not a fix.
**If he says glass:** the same `GlassChoiceBar` in `fills` mode with two
items, in the principal slot (`DayTitleOrTabs`, `DaySheet.swift:1086-1101`).
**If he says keep:** write it into `ten.md`'s exceptions, since by today's
rule it reads as the odd one out.

Also stale: `PlanScopeRow`'s own doc still says "plain words, the chosen one
in ink, as the sheet's own Plan and Journal are" (`PlanScope.swift:98-99`).

### 3. "Back" is two materials depending on which page you pushed

- **The app's glass back** (`GlassIconButton`, `onPage`): a day album
  (`DayAlbumDetailView.swift:149`), a place album
  (`PhotoCollectionView.swift:89`), a crew's day (`CrewDayView.swift:47`), via
  `glassBackButton()`. The map's `MapBackButton` is the same button.
- **The system's back** in iOS 26's own `.regular` toolbar capsule: Settings,
  pushed from Memories' gear (`MemoriesView.swift:781-784`, destination
  `:435`), and all four of its own pushes: Month Drawing, Removed Albums, Why
  It Works, Privacy (`SettingsView.swift:528, 541, 827, 837`). None of them
  calls `glassBackButton()`.

Memories pushes both kinds from one header. `GlassBackButton.swift:4-14`
records exactly this as the "sore thumb" it was written to remove.
**Standard:** `glassBackButton()` (rule 1; GlassBackButton's own reason).
**Smallest change:** `.glassBackButton()` on `SettingsView`'s body and on the
four views it pushes. While there, `RemovedAlbumsView` is the one pushed page
using a bare `.navigationTitle` (`SettingsView.swift:1513`), which the system
sets in Semibold, a third weight (`StrataTitle.swift:48-50`); it wants
`.sheetTitle("Removed Albums", drawn: false)`.

### 4. "Plan for Later" is a flat grey chip that turns into glass

`WhenRow`'s closed state (`PlanScope.swift:288-302`) is a private capsule:
`quietFill`, a literal 34pt height, `headerSmall` in `inkSecondary`. Pressed,
it becomes the glass bar of finding 1. On the first sheet a new user opens,
the one control that leads to glass is the one control that is not.

The same 34pt filled pill is drawn twice more, privately, as a small primary:
`TipCard.swift:120-131` and a copy in `HouseCard.swift:92-101` (its own `34`
and `44` literals).

**Standard:** `glassCapsule(onPage: true)` at 44 for the chip (rule 1; the
owner's "clean liquid glass button"); one `SmallPrimary` for the tip and house
pills (rule 1, rule 7).
**Smallest change:** swap the chip's `.frame(height: 34).background(Capsule…
quietFill)` for `.frame(minHeight: 44).glassCapsule(onPage: true)`. HouseCard
calls TipCard's pill rather than copying it.

### 5. The writing bars' placeholder is the system's grey, which the add sheet measured at 1.73:1

The add sheet's own note (`AddWinSheet.swift:643-649`) sampled a bare
`TextField`'s placeholder at 1.73:1 and fixed it with
`prompt: Text(…).foregroundStyle(AppColors.inkTertiary)`. So did New Crew
(`CrewsListView.swift:596`), onboarding (`OnboardingView.swift:615`) and Your
Three (`YourThreePicker.swift:37`). The writing bars did not:

- Journal: `TextField(invitation, …)` (`DaySheet.swift:820`)
- Chat: `TextField("Message", …)` (`CrewChatSheet.swift:1116`)
- Crew plan: `TextField(scope.prompt(), …)` (`ChatPlus.swift:178`)
- Plan: `field.placeholder = placeholder`, UIKit's grey
  (`PlanTextField.swift:88`)

And the chat's resting bar draws its fake field's "Message" in `inkTertiary`
(`ChatRestBar.swift:73-75`), so the one word visibly changes ink as the bar
rises into the chat, the move its own comment calls "one field rising".
**Standard:** `inkTertiary` (rule 6; four sites already).
**Smallest change:** `DayComposer` takes the placeholder string and builds the
`prompt`; `CrewChatSheet` passes the prompt; `PlanTextField` sets
`attributedPlaceholder` in `inkTertiary`.

### 6. "Plan with Roommates" has two layouts, depending on the door

- **From the crew's chat (+, Plan) and from the Crews list's Plan:**
  `GroupPlanSheet` (`ChatPlus.swift:163-195`). Days bar at the top, the glass
  writing bar at the foot, the arrow sends, Done top right. This is "your own
  plan's shape", the owner's pick of 2026-10-14 ("Same as my plan").
- **From the crew tower's slot, Add a Win, Plan for Later:** `AddWinSheet` in
  plan mode, titled the same "Plan with Roommates" (`AddWinSheet.swift:93-96`).
  A bare text field at the top, "Plan" as a word top right
  (`AddWinSheet.swift:1362`), Cancel turning into Done top left
  (`:1330`), Return for the next line, a list of what was planned under it.

Your own plan does not have this problem: choosing a day on the add sheet
hands off to the Plan page (`AddWinSheet.swift:433-441`). That hand-off is
skipped only for a crew (`guard … planCrew == nil`).
**Standard:** `GroupPlanSheet` (rule 3; the owner's 2026-10-14 pick).
**Smallest change:** for a crew, do what your own plan does: close the add
sheet and open `GroupPlanSheet` with the crew, the words typed and the day
chosen. The plan-mode branches in `AddWinSheet` then serve no crew and can
go.

Also stale: `GroupPlanSheet`'s doc still says "Cancel on the left, Plan on the
right" (`ChatPlus.swift:105-107`); it ships Done alone.

### 7. The Journal's empty line is quieter than every other empty line

`DaySheet.swift:609-613`: "Nothing written. Yet." in `bodyLarge`,
`inkTertiary`, and its comment says it is there "as the chat does". The chat
does "Quiet here. Yet." in `headerMedium`, `inkPrimary`
(`CrewChatSheet.swift:452-457`), as do "No photos today. Yet."
(`ChatPlus.swift:614-616`), "Nothing sent here with a photo. Yet."
(`ChatPlus.swift:683-685`) and "No photos here." (`PhotoCollectionView.swift:
176-181`, whose doc records why: the page's one sentence was its quietest
object).

Rule 1 lists "an empty state" among the things drawn once; it is drawn five
times, by hand.
**Standard:** `headerMedium` in `inkPrimary`, centred (four of five, and the
measured argument).
**Smallest change:** an `EmptyLine(_:)` view with those two tokens; at the
least, the Journal's two lines change. "No photos here." is the one without
"Yet."; that is copy, for the owner.

### 8. Deleting a plan line: Undo from the list, a question from its own sheet

- Swipe or menu on the line: gone at once, "Line deleted" with Undo
  (`PlanLines.swift:667-685`, which even names this split as the reason it
  was written).
- The line's sheet, Delete Line: a dialog, "Delete this line? It will not come
  back." (`PlanItemDetailSheet.swift:412-434`).

Same thing destroyed, two answers, and the sheet's sentence is untrue of the
other door. The app's pattern for a small thing that can come back is Undo:
a win (`AddWinSheet.swift:2370`, `PhotoViewer.swift:754`), a chat line
(`CrewChatSheet.swift:915`), an album (`MemoriesView.swift:654`), Hide for Me
(`UndoLine.swift:132`).
**Standard:** Undo (rule 3 allows either; the app chose Undo for this size).
**Smallest change:** Delete Line closes the sheet and runs the list's delete
(the line hidden, `PlanItem.remove` on expiry); the dialog goes. The sheet's
`delete()` also uses `modelContext.delete` where the list uses
`PlanItem.remove` (`PlanItemDetailSheet.swift:437-440`), which may treat a
repeating line differently: worth one look.

### 9. The only bare glyph in a sheet's corner: the crew details' QR code

`CrewInfoSheet.swift:140-150` puts `qrcode` top left as a bare glyph
(`sheetAction(.confirm, as: .glyph)`). Every other glyph in a corner of this
app stands on glass: the day sheet's sticker (`DaySheet.swift:971`), the crew
tower's Invite (`CrewTowerView.swift:888`), both corners of the Crews list
(`CrewsListView.swift:48, 60`). `design.md` records the owner on this exact
corner's neighbour: "a glyph on glass, never the bare word".
**Standard:** `GlassIconButton(onPage: true)` (rule 1).
**Smallest change:** `GlassIconButton(systemName: "qrcode", onPage: true,
accessibilityLabel: "Show a code")` inside the existing `BareToolbarItem`.

### 10. The chat's title is two styles, depending on how it opened

- As a sheet: "Roommates / Today", `TwoToneTitle` at 17 Bold
  (`CrewChatSheet.swift:1622-1625`), like every sheet title
  (`StrataTitle.swift:93-96`).
- As the drawer off the crew's page: "Today" at 15 Bold in `inkSecondary`
  (`CrewChatSheet.swift:1652-1657`), with a literal 72pt side inset.

The drawer is the door almost everyone uses. The word "Today" is the owner's
(2026-10-14) and stays; only its type differs.
**Standard:** `headerMedium` in `inkPrimary`, the sheet title's (rule 3).
**Smallest change:** those two modifiers in `ChatDrawerTitle`; `TwoToneTitle`
when the name comes back at full height.

### 11. Two sheets outside the sheet table

Rule 3's table, read across every sheet. All but two fit:

| Sheet | Left | Right | Fits |
|---|---|---|---|
| Add a win / Edit (`AddWinSheet.swift:1286`) | Cancel (Done once planned) | Add / Save / Plan | yes |
| Day (`DaySheet.swift:1063`) | sticker glass on Journal, empty on Plan | Done | yes |
| Line (`PlanItemDetailSheet.swift:331`) | empty | Done | yes |
| Plan with a crew (`ChatPlus.swift:190`) | empty | Done | yes |
| Crew details (`CrewInfoSheet.swift:140`) | QR (finding 9) | Done | yes |
| Your Score, Edit Profile, Your Day, Your Three, Show a Code | empty | Done | yes |
| Doodle, Today's Strip, Bring Back | Cancel | Send | yes |
| Ink editors, Move Photo | Cancel | Done | yes |
| Booth, story, replay, head maker | | x top right | yes (written exception) |
| **Stickers, in the chat** (`CrewChatSheet.swift:1528-1533`) | **Cancel** | **nothing** | **no** |
| **New Crew** (`CrewsListView.swift:623-629`) | Cancel | nothing; Invite is a capsule at the foot | title **no** |

- **Stickers:** "Cancel" when nothing is thrown away (rule 3: Cancel only
  when leaving throws work away). Picking is the confirm. Change: Done top
  right, as Your Three and Show a Code do.
- **New Crew:** `.navigationTitle`, so the system sets it in Semibold, the
  third weight `sheetTitle` exists to stop. Change:
  `.sheetTitle(CrewLine.newCrew, drawn: false)`. Invite at the foot is the
  owner's merged flow (2026-10-14) and stays.

### 12. A disabled Send is two greys in the same chat

`InkSheetToolbar` dims its confirm twice: `sheetAction` already turns a
disabled word to `inkQuiet` (`SheetAction.swift:58-63, 77-78`), and the
toolbar adds `.opacity(0.4)` on top (`InkCanvas.swift:949`). So the Doodle
sheet's empty Send (`DoodleSheet.swift:43`) is far fainter than Today's
Strip's empty Send (`ChatPlus.swift:637-644`), and both open from the same
chat + row. It also dims every ink editor's Done.
**Standard:** `sheetAction`'s own dim (its doc: "`.disabled` is the whole of
the dim").
**Smallest change:** delete line 949.

---

## Below the top twelve

### 13. Two glass buttons play two haptics

`GlassIconButton` already plays `lightTap` (`GlassIconButton.swift:86-88`).
Two callers play it again in their action: the Crews list's Plan
(`CrewsListView.swift:49`) and Memories' Settings (`MemoriesView.swift:783`).
Rule 5: one haptic. Felt, not seen. Change: delete both lines.

### 14. The bare toolbar item is rebuilt eight times

`BareToolbarItem` exists (`SheetAction.swift:147-160`). Private copies of it:
`AddWinSheet.swift:1286-1296`, `PlanItemDetailSheet.swift:331-338`,
`ProfileView.swift:675-682`, `DaySheet.swift:124-135` (JournalToolbarItem),
`:1063-1077` (DaySheetToolbar), `:1092-1101` (DayTitleOrTabs),
`CrewChatSheet.swift:1606-1619` (ChatSheetToolbar), `InkCanvas.swift:928-939`.
They also disagree on placement: `.confirmationAction` (Add, Edit Profile,
Your Score at `ProfileHeader.swift:157`) against `.topBarTrailing` everywhere
else. Nothing on screen differs today; rule 1 says this is how it starts to.
Change: each becomes `BareToolbarItem`.

### 15. The chat's writing bar is a copy of `DayComposer`

`CrewChatSheet.swift:1108-1129` builds the plus, the `glassField` and Send by
hand, the same pieces as `DayComposer` (`DayComposer.swift:27-45`), whose own
doc says it is "the same pieces as `CrewChatSheet`'s composer". The resting
bar (`ChatRestBar.swift:65-95`) is a third, deliberately a picture of a
field. Today they match. Change: the chat passes its plus as `leading:` and
its `TextField` as `field:`.

### 16. Head sizes agree, as literals

Rows and Today's heads at 56 (`CrewsListView.swift:298`, `TodayHeads.swift:
55`), member and who-reacted lists at 40 (`CrewInfoSheet.swift:404`,
`CrewReactions.swift:207`), chat faces at 28 (`CrewChatSheet.swift:133`,
`ChatRestBar.swift:181`, `WinsChatBanner.swift:80`, `MakeYourHead.swift:25`).
Every pair that means the same thing is the same number, so nothing is wrong
on screen; each is its own literal (rule 7). Change: three named sizes on
`PersonHead` (row, list, chat).

### 17. Deleting your head asks, though it can be brought back

`ProfileView.swift:138-145` confirms, and its message says the head waits
under Earlier Heads. It is the one recoverable delete that asks; a win, which
is gone for good five seconds later, offers Undo. **For the owner:** a head
is minutes of work, and asking may be what he wants. If not: delete at once,
"Head deleted" with Undo through `EarlierHeads.bringBack`.

### 18. Small drift, each one line

- The back-to-Crews count is `.body.weight(.semibold)`, a third weight, with a
  literal 14 of padding (`CrewTowerView.swift:1192, 1199`). `headerSmall` and
  a gap token.
- The head maker's close glyph is 16 (`HeadMakerView.swift:427`); every other
  close is the default 17.
- The photo viewer's two dialogs back out with "Cancel" and "Keep It"
  (`PhotoViewer.swift:256, 267`); the Journal says "Keep It", the line sheet
  "Cancel". One word for "don't" (rule 4).
- "Remove this photo?" says "Only the photo is deleted"
  (`PhotoViewer.swift:260`): Remove and Delete in one dialog, against
  `ten.md`'s written split.
- The day's sticker or emoji comes off from its hold menu at once, with
  neither a question nor Undo (`DaySheet.swift:1012-1015`). Rule 3. Small,
  since it can be chosen again.
- `GlassIconButton.swift:20-24` still calls glass on the page "the open
  question". Today's rule answers it; the comment should say so.

---

## For the owner

1. **Plan / Journal on glass** (finding 2): it is locked as plain words. Keep,
   or the glass bar in two?
2. **Deleting your head** (finding 17): keep the question, or Undo like a win?
3. **"No photos here."** (finding 7): add "Yet." like the other four?

## The two changes that move the most

Findings 1 and 3. One `fills` mode on `GlassChoiceBar` takes the last
non-glass choice controls out of Add a win, Your Score and every crew's page.
Five `.glassBackButton()` calls make every push in Memories leave the same way.
