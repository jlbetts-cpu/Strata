# Apollo's design system, as it actually exists

Written 2026-09-23, after: "I want to make sure we can make this experience
feel as premium as possible — make sure we are using a specific design system
so we can easily implement and change certain things on the fly."

**This is a map of what is already in the code, not a proposal.** Every entry
below is a real symbol with one definition and every screen going through it.
That is what makes something changeable on the fly: not that a system exists
on paper, but that there is exactly one place to change.

---

## The rule

**If two screens draw the same thing, the drawing lives in one place and both
call it.** Every entry here exists because that was not true and something
drifted — usually silently, usually caught by the owner rather than by a
test.

| Piece | One definition | What drifted before it |
|---|---|---|
| `ApolloGround` / `ApolloSheet` | The warm white sheet over the camera's black, with the dark showing as a strip | Built inline in `HomeView`; the folder's inside and the print both lost the strip |
| `PhotoFinish` / `PhotoCorner` | Every photograph's corner and hairline | Three corners for the same photo: 16 inside a folder, 7 on the stack, 8 on the print |
| `ScatterLayout.tidied` | The two-column grid: one column wide, the picture's own height | A landscape photo came out portrait on the shelf and landscape inside |
| `FolderTint` | The six folder colours, and the deal that picks one | — held by `FolderStyleTests` |
| `Typography` | Five sizes, two weights, and the serif for titles | A different title size per screen |
| `GridConstants` | Spacing, radii, `bottomStrip`, the motion springs | `stripBreathing` was a private 20 in `CameraView` |
| `HapticsEngine` | Every haptic | — |
| `WinPrint` | The 3:4 print, and the format's ratio | — |

## The tokens worth knowing

**Ground.** `HomeGround.top` is the warm white; `Grey.g950` is the dark.
`GridConstants.bottomStrip` (20) is how much of the dark shows, and
`ApolloGround.radius` (40) is the sheet's bottom corner — both the camera's
own numbers, shared rather than copied.

**Ink.** `AppColors.inkPrimary` / `inkSecondary` / `inkTertiary` / `inkQuiet`,
all adaptive and all derived from a contrast target rather than chosen by eye.
**Never `.primary.opacity(x)`** — that is a colour in light mode and a
different weight of voice in dark.

**Type.** `Typography.screenTitleSerif` (New York, Medium) names a screen;
`sectionSerif` names a section inside one; `headerMedium`, `bodyLarge`,
`bodySmall`, `sectionLabel`, `caption2` are the rest. Two weights, Regular and
Medium. SF Pro, not Rounded.

**Photographs.** `.photoFinish()` for the corner and edge,
`GridConstants.photoCornerRatio` for how round, `WinPrint.aspect` for the
print's format, `ScatterLayout` for how they are laid out together.

**Motion.** `GridConstants` carries the springs. The convention is that motion
goes through a token rather than an inline `.spring(...)`, and it is widely
violated in older code — including some written this week, where a gesture
needed a curve the ladder does not have. Fixing the existing ones is a
worthwhile separate pass; do not add to it casually.

## Where to change things

- **The app's colour** — `FolderTint.all`. Six entries, each held between 0.06
  and 0.34 saturation by a test, so a neon cannot be added by accident and
  nor can a grey.
- **How round a photograph is** — `GridConstants.photoCornerRatio`, one
  number, every photograph in the app.
- **How much dark shows at the bottom** — `GridConstants.bottomStrip`. The
  camera and every other screen move together.
- **The title face or weight** — `Typography.screenTitleSerif`.
  `-strataTypeLab` sets every weight against the mark so the choice is made by
  looking.
- **The folder's glass** — `WinFolder.front`, four layers with a sentence each
  saying what they are for.

## What is NOT a system yet, honestly

- **Motion tokens are not enforced.** There is no gate that fails an inline
  spring.
- **`docs/design-system.md`** (542 lines) predates all of this and still
  describes the tower, four tabs and a light-only app. It is the older
  document and this one wins where they disagree, but it has not been
  reconciled.
- **Memories has not joined.** It still follows the system appearance and sets
  its title in the drawn face rather than the serif. It is the next screen to
  come across.
