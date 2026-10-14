# Should the Crews tab's dot go blue? (2026-10-14)

The owner: "im honestly thinking I feel like blue should be the notification
color just because its cleaner in my opinion could you research a good color
and if we should go in this direction."

Scope: `AppColors.notify` / `notifyUI` (`Strata/Views/Crews/CrewFaces.swift`),
which paints ONE thing: the doodle dot with a white count on the Crews tab glyph
(`StrataTab.marked`, `Strata/Views/TabBarView.swift`). Every other "new" mark is
ink (`NewsDot`) and stays ink. Nothing here was changed in code.

## Verdict

**Yes, go blue, but not iOS system blue. Use a muted "dusk" blue, `#4A72C4`, the
same value in light and dark** (the way terracotta is one value in both).

Why yes: blue is iOS's own unread language and the calmest of the attention
hues, and it fixes a problem the current colour has that nobody noticed:
terracotta `#C9705F` is ΔE2000 **8.9** from the Social block's coral `#F97066`,
so the Crews dot is a near-duplicate of a block colour today (its comment says
"none of the block colours"; by distance it is the Social block's sibling).

Why not system blue: it is ΔE **7 to 10** from the Work block `#40A9FF` (same
hue, 207 to 208 degrees), it is the stock tint the app has removed from chrome
twice, and on a tab bar it is iOS's default *selected-tab* tint.

## The case, honestly

**For blue**
- iOS's own unread marks are a blue dot: Mail marks an unread message with a
  blue dot ([Dummies, iPhone Mail](https://www.dummies.com/article/technology/electronics/cell-phones/iphones/basic-e-mail-actions-to-use-on-your-iphone-157246/));
  Messages marks a conversation with unread content the same way
  ([Apple Community](https://discussions.apple.com/thread/254910250)). A blue dot
  means "something to read", not "something is wrong". (b: shipping product)
- Slack splits the same way this app wants to: red badge for things directed at
  you (DMs, mentions), **blue badge for general unread activity**
  ([Slack, Guide to notifications](https://slack.com/help/articles/360025446073)).
  A friend's win is general activity, not urgent. (b: shipping product)
- It answers the owner's own complaint that red is "scary"; terracotta already
  softened that, blue removes the warning reading entirely.
- It moves the dot off the Social block's coral (ΔE 8.9 today, ΔE 43 for dusk).

**Against blue**
- **He has turned blue down twice, on chrome.** Stock sky blue was the source of
  every "this looks like default iOS" complaint (CLAUDE.md, accent), and the blue
  primary pill lasted "about an hour" before "make the primary color black again"
  (2026-10-01). This dot is the only colour in the tab bar, so a *stock* blue
  there reintroduces exactly that look. A muted blue is the answer to that, not
  `.blue`.
- **On a tab bar, system blue means "selected".** iOS's default tint, which a
  `TabView` uses for its selected item, is system blue; the app overrides it with
  `.tint(.primary)` in `MainAppView`. A bright system-blue mark on an unselected
  tab can read as "this tab is on". (c: inference from the platform default)
- **The Work block is blue** (`#40A9FF`), and blocks scroll under the Liquid
  Glass bar, which picks up the colour beneath it. System blue sits on the same
  hue as Work; dusk is shifted 13 degrees toward indigo and is ΔE 19.6 away.
- **It loses warmth.** Grounds are warm and the ink has brown in it; blue is the
  one cool note. Taste, not a measurement, and the reason the pick is muted
  rather than saturated.
- Apple's own rule cuts both ways: "Avoid using the same color to mean different
  things" ([HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color)).
  That argues against a blue that matches Work, and equally against the current
  terracotta that matches Social.

**Colour psychology (weak, tagged as such).** "Blue is calm and trustworthy, red
is alarm" is a common claim, but the research base is thin: the main review says
the field's empirical work has been held back by methodological problems and
calls for better-controlled studies ([Elliot and Maier 2014, Annual Review of
Psychology, doi:10.1146/annurev-psych-010213-115035](https://doi.org/10.1146/annurev-psych-010213-115035);
[Elliot 2015, Frontiers in Psychology](https://www.frontiersin.org/articles/10.3389/fpsyg.2015.00368/full)).
Do not lean on it. The platform convention (Mail, Messages, Slack) is the real
argument.

## Candidates, measured

Grounds: page `WarmBackground.top` light `#FDFDFD`, dark `#1D1C1C`; light tab bar
glass as sampled in `WarmBackground`'s note, `#E8E4DF`; dark bar **not sampled**,
approximated `#2C2B2A`. Contrast is WCAG 2.x relative luminance. ΔE is CIEDE2000.
Bars: the dot is a graphic, 3:1 ([WCAG 1.4.11](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html)).
The digit is about 7.4pt semibold (a 12pt dot, font at 0.62 of it), which is
NOT large text, so 4.5:1 is the strict bar ([WCAG 1.4.3](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html));
3:1 is the brief's floor.

| | light | dark | page L | bar L | page D | bar D (approx) | white "2" L / D | ΔE to Work `#40A9FF` |
|---|---|---|---|---|---|---|---|---|
| Terracotta (now) | `#C9705F` | same | 3.46 | **2.78** | 4.83 | 4.01 | 3.52 / 3.52 | 44.4 (ΔE 8.9 to Social) |
| iOS blue, classic (Messages) | `#007AFF` | `#0A84FF` | 3.95 | 3.17 | 4.66 | 4.37 | 4.02 / 3.65 | 15.1 / 11.7 |
| iOS 26 systemBlue (HIG table) | `#0088FF` | `#0091FF` | 3.46 | **2.78** | 5.26 | 4.37 | 3.52 / 3.23 | **10.3 / 7.3** |
| Cornflower (brighter muted) | `#4C7BD9` | same | 4.01 | 3.23 | 4.16 | 3.46 | 4.08 / 4.08 | 16.1 |
| **Dusk (recommended)** | **`#4A72C4`** | **same** | **4.59** | **3.69** | **3.64** | **3.02** | **4.67 / 4.67** | **19.6** |
| Ink blue | `#26437F` | `#5B7FD0` | 9.42 | 7.57 | 4.37 | 3.63 | 9.58 / 3.90 | 39.9 / 15.7 |

Notes on the table
- iOS 26's HIG lists systemBlue as RGB 0,136,255 light and 0,145,255 dark
  (increased contrast 30,110,244 / 92,184,255), not the older `#007AFF`; the HIG
  also says not to hard-code system values because they move between releases.
- Bold = fails 3:1. Terracotta and iOS 26 systemBlue both fail on the light bar
  ground the dot actually sits on (2.78).
- Only Dusk and the light Ink blue clear **4.5** for the white digit. Everything
  else is between 3.2 and 4.1: passes the 3:1 floor, below 4.5.
- Dusk sits at the ceiling: a white digit at 4.5:1 caps how bright the dot can be,
  which caps it at about 3.78:1 on the dark page. A search over hue 214 to 222
  found nothing better than 3.66 there; dusk is 3.64.
- Ink blue's light value is 2.19:1 against the black glyph it overlaps, so it
  reads as part of the ink drawing and stops doing the job colour is kept on the
  tab bar for (being seen from another tab). It also needs two values.
- All blues are ΔE 19 to 22 from the Creativity purple `#AF9CFA`; no clash.
- `AppColors.accent` (sky, about `#4CC5FC`) is defined but has no live call site.

## Rendering

`/tmp/claude-501/overnight/notify-blue/comparison.png` (9x points) and
`actual-size.png` (phone pixels, @3x): the real `TabCrews@3x` and `TabWins@3x`
alpha, the real `DoodleDot` outline, ring and centre from `StrataTab.marked`, a
white semibold "2", on light and dark bars, with each dot beside a Work block
swatch. Approximate: the bar is a flat fill, not Liquid Glass.

What looking at it shows
- The two system blues are the loudest objects on the bar and, beside the Work
  swatch, the iOS 26 one nearly merges with it.
- Cornflower and dusk are close; dusk is a touch greyer and quieter, which is the
  "softer and more premium" direction he set for terracotta.
- In dark mode dusk reads clearly against the white glyph and the bar.
- Ink blue on light reads as a near-black dot next to black ink.

## If he says yes

Change both lines in `CrewFaces.swift` to `0x4A72C4` and update the comment
(the "none of the block colours" claim and the 3.32 / 4.83 / 3.52 numbers). The
brighter alternate, if dusk reads too grey on a real phone, is cornflower
`#4C7BD9`, which trades the digit's 4.5 for a cleaner blue (4.08). Check on a
real device over a scrolled tower with a Work block under the bar.
