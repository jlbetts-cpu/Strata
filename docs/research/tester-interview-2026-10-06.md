# Talking with a tester: interview guide

2026-10-06. One TestFlight friend, 15 to 20 minutes. Two testers love Some
Wins but log one or two wins a day (`docs/logging-more-wins.md`). We want her
real days, not her opinions.

Methods: **The Mom Test** (Fitzpatrick, 2013), past behaviour over opinions.
**JTBD switch interviews** (Moesta), what was going on when she started.
**Critical incident technique** (Flanagan, 1954), one specific recent moment.
**NN/g interviewing**, open questions and silence. **Day Reconstruction**
(Kahneman et al., 2004), "walk me through yesterday". **Superhuman's PMF
question** (Vohra, 2018, after Sean Ellis).

## 1. How to run it

- Ask to record: "Is it OK if I record this so I can listen instead of
  typing?" If she says no, take notes.
- Have her phone in her hand with the app on it. "Show me" beats "tell me".
- She talks about 80% of the time. Count to five in your head before
  filling a silence.
- Never defend or explain the app. Her confusion is the finding.
- Follow every answer with one of: "Tell me more about that." "When was the
  last time that happened?" "What did you do next?"
- Friends are kind. Open with: "You can't hurt my feelings. What annoys you
  helps me most."

## 2. The questions

**Her day and context**

1. "Walk me through yesterday, from waking up to going to bed."
   *Learns where the gaps in her day are. Informs when a cue can land (the
   slot bubble, the 7pm check-in).*
2. "Think of the last time something went well for you. What did you do
   with it? Tell someone, write it down, nothing?"
   *Learns the habit we compete with. Informs whether the job is a private
   record or something to share.*
3. "Take me back to when you first installed it. What was going on that
   made you try it? What were you using before, if anything?"
   *JTBD push and pull. Informs onboarding and the App Store pitch.*

**The last time she opened it**

4. "When did you last open the app? Can you open it now and show me what
   you did, step by step?"
   *Learns her real path and where she hesitates. Informs logging speed.*
5. "What made you open it right then?"
   *Learns the trigger: a cue, a crew, boredom, a win. Informs which prompt
   actually works.*

**Logging, and not logging**

6. "Yesterday, was there a moment you did something and thought about
   logging it, but didn't? Tell me about that moment."
   *The core critical incident. Informs why it is one or two a day.*
7. "What's the smallest thing you've ever logged? What made you log it?"
   *Learns her bar for what counts. Informs Win ideas and examples.*
8. "Think of a day you logged more than usual. What was different about
   that day?"
   *Learns the conditions to recreate. Informs cues and defaults.*

**The parts of the app (show me, never "do you like")**

9. "The last time you reached your goal, what happened? Show me the strip,
   if you kept it. What did you do with it?"
   *Learns if the ring motivates or pressures, and if the strip gets saved
   or shared. Informs the goal and the booth.*
10. "Show me the crew you looked at last. What did you look at first? Was
    there a win you kept to yourself? Tell me about it."
    *Learns if an audience raises her bar. Informs per-win sharing and chat.*
11. "Show me the last block you drew on, stickered or added a photo to. What
    was going on?"
    *Learns if decorating is the reward or a cost. Informs keeping logging
    fast.*
12. "Tell me about a recent hard day. What did you do with the app that day,
    if anything?"
    *Learns if Your three and Hard day get found and used. Informs whether
    the low-effort path works.*

**What she'd miss**

13. "Which part have you gone back to more than once? Show me."
    *Learns the real core of the app for her. Informs what to protect.*
14. "How would you feel if you could no longer use Some Wins? Very
    disappointed, somewhat disappointed, or not disappointed?" Then: "Why?"
    and "What's the main thing you get from it?"
    *Vohra's exact question. One answer is a signal, not a score: the 40%
    "very disappointed" benchmark needs many testers.*

**At the very end**

15. "If you had a magic wand and could change one thing, what would it be?"
    Then: "What would that let you do?"
    *A pointer to a problem, never a spec. Informs where to look next.*

## 3. Don't ask

- **Leading:** "Isn't the strip fun?" "Did the ring motivate you?"
- **Future hypotheticals:** "Would you use it more if...?" "Would you pay
  for...?" People are bad at predicting themselves.
- **Feature wishlists as decisions:** "What features should I add?" Hear
  requests, then dig for the problem behind them.
- **Yes/no:** "Do you like crews?" Ask "When did you last open a crew?"

## 4. Note-taking template

```
Date:            Length:          Recorded: yes / no

QUOTES (her exact words)
-
-

BEHAVIOURS OBSERVED (what she did on the phone, where she paused)
-
-

MOMENTS SHE DIDN'T LOG (when, what, why)
-

SURPRISES (anything that contradicts what we believed)
-

PMF ANSWER:  very / somewhat / not      Why:
MAGIC WAND:                             Problem behind it:

OPPORTUNITIES
When [situation], she [did what], because [reason].
-> What might help:
-> Seen in another tester too?  yes / no
```

**Turning answers into what to build next**

- What she did beats what she said.
- Write each finding as "When [situation], she [did], because [reason]".
  That is the problem; the fix comes after.
- Build only what shows up in at least two testers. One is a hunch.
- Check it against the rules: one cue a day, the ring only fills.
- Ship one change at a time, then compare wins per active day and the
  share of days reaching the goal, before and after.
