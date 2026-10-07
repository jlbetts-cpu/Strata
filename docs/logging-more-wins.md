# Logging more wins, without guilt

2026-10-06. Two internal testers "dont really post really anything during
there day maybe 1 or 2 max", while saying they love the app. The owner asked
for the scientific reason and the recommended fixes. This is the record.

## Why people log one or two

1. **No prompt after the first win.** The only cue was the morning reminder,
   and it was withdrawn the moment a day had a win. A behaviour happens when
   motivation, ability and a prompt meet (Fogg 2009); notifications alone
   raise logging (Bentley and Tollmar, CHI 2013).
2. **Recall loses the small things.** Asked "what did you do?", people find
   the salient wins and lose the rest (Kahneman et al. 2004, the Day
   Reconstruction Method). Recognising is easier than recalling: the system
   proposes, the person confirms (Choe et al. 2017).
3. **The bar for "what counts".** Minor progress drives motivation but people
   discount it (Amabile and Kramer 2011, small wins).
4. **An audience raises the bar.** Visible entries drift toward the notable
   (Marwick and boyd 2011; Hogan 2010; Cordeiro et al. 2015). Sharing here is
   already a per-win choice.
5. **ADHD and timing.** Cues must be external and at the point of
   performance (Barkley 2012). More notifications causally worsen inattention
   (Kushlev, Proulx and Dunn, CHI 2016), so nagging is harm, not noise.

## What shipped

| Change | Mechanism | Where |
|---|---|---|
| The dark bubble over the slot, once a day | Prompt at the point of performance | `WinCue`, `MainAppView.winCueLayer` |
| 7pm "Anything else today?", with Quick, Regular, Deep | Prompt for days the app is not opened | `EveningCheckIn` |
| One cue a day across all three | Avoid notification harm | `EveningCheckIn.when` |
| Ideas over the add sheet's keyboard | Recognition over recall; examples lower the bar | `WinIdeas` |
| The goal ring, the dance at the goal | Self-set specific goal (Locke and Latham 2002); goal gradient (Kivetz et al. 2006) | `GoalRing`, `DailyGoal` |
| Rest days | A broken streak makes people stop | `Streaks.Rest` |
| Do It Too | A friend's win becomes your plan | `DayComposing.doItToo` |
| Everyone's in | The crew's shared peak | `CrewTowerModel.everyoneIn` |

## Rules these leave behind

- One cue a day, however it comes. Never a second.
- Cues ask; they never count, never say "forgot", "missed" or "only".
- The ring only fills. No red, no remaining count, full past the goal.
- Nothing is chosen for the person: ideas are offered, never pre-ticked.

## Measure next

Wins per active day and the share of days reaching the goal, before and after,
one change at a time. None of this was tested on ADHD adults logging positive
events; treat the effects as hypotheses.

## Premium feel (the second video, 2026-10-06)

Wyatt Feaster's checklist, against this app, so the next pass knows where to
look: anticipate needs (ideas over the keyboard, Do It Too); intentional
transitions (the token ladder, the lift moment); delight (the dance at the
goal, the sticker stepping out); know when not to animate (Reduce Motion
paths, no animation on logging itself); extreme consistency (tokens, the
`SourceSweep` gates); purposeful empty states (Plan's ghost row, the
Journal's "Nothing written. Yet."); reward discovery (stickers, doodles,
the crow's smile); prescriptive errors ("Couldn't find anything to lift. Try
another photo.", `AddWinFailure`).
