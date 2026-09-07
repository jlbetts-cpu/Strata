# Strata — sound

## Where this stands

The engine now looks for a **recorded file first** and only synthesises when it
does not find one. Drop a file named after a cue into the app's resources and it
is used immediately, with no code change:

```
win.wav        a habit or win completed
impact.wav     a block landing on the tower
chime.wav      the day is clear
milestone.wav  a round number reached
```

`.caf`, `.wav`, `.aiff` and `.m4a` are all accepted, in that order of
preference. `SoundEngine.Cue` is the list; adding a cue means adding a case.

## What I could not do, and why

I could not source the recordings. Three reasons, and none of them is a
limitation worth working around badly:

1. **I cannot listen.** Picking "genuinely serene, not cheap" from a library is
   an auditioning job. Choosing by filename would be exactly the cheap result
   you are trying to avoid.
2. **I cannot verify a licence.** A licence is a legal fact about a specific
   file at a specific URL on a specific date. Vendoring third-party audio into
   an app you intend to ship, on my say-so, is a real risk to you and not mine
   to take.
3. **A licence needs a person to accept it.** Most commercial audio licences
   are granted to a named licensee.

So the engine is built to make the swap trivial whenever you do have files, and
the synthesis is now good enough to ship in the meantime.

## Sourcing, in order of what I would actually do

**1. Record them yourself.** This is the best answer and it is not a
compromise — it is what "real sounds people made" means, and the licence is
unambiguously yours. You need three physical objects and a quiet room:

- `win` — a hardwood block or a wooden spoon on a chopping board, struck with a
  fingertip, not a hard object.
- `impact` — a heavy book dropped flat on a rug from 10cm. Soft, low, no ring.
- `chime` — a wine glass or a ceramic bowl, tapped with a fingernail.

Phone voice-memo quality is fine at these lengths. Record twenty takes of each
and keep the three best; the differences between takes are exactly the
variation the synthesis is currently faking.

**2. Freesound.org, filtered to CC0.** CC0 is public-domain dedication: no
attribution, commercial use fine, no share-alike. It is the only Creative
Commons filter you should use — CC-BY needs attribution in-app, and CC-BY-NC
forbids commercial use outright.

**3. Apple Loops.** If you have GarageBand or Logic, the bundled percussion
one-shots are professionally recorded and Apple's licence permits their use in
commercial works. This is the fastest route to genuinely crafted audio.

**4. Paid libraries** — Splice, Artlist, Epidemic Sound, Soundsnap. Straight
commercial licences, worth it if the app ships.

**Do not use the BBC Sound Effects library.** It is free and it is excellent
and its licence is personal/educational only. It is the most common way an
indie app ends up with audio it is not allowed to ship.

## What to listen for when choosing

The parts of "satisfying" that are measurable, and worth trusting:

- **Roughness.** Two partials inside one critical band beat against each other
  and the result is heard as harsh (Plomp & Levelt, 1965). This is why every
  pitch in the app is snapped to a **major pentatonic scale** — it contains no
  minor second and no tritone, so two cues overlapping cannot produce a rough
  interval. Keep that property: if you replace `win` with a recording, it should
  be roughly in tune with the others.
- **Sharpness.** Energy concentrated above ~5kHz reads as thin, plasticky and
  fatiguing, and fatigue is what "cheap" usually means for a sound you hear
  hundreds of times a day. Prefer recordings with body below 1kHz.
- **Short.** Under 500ms for `win` and `impact`. A UI sound long enough to
  notice as a sound is too long.
- **Decaying, not sustaining.** It should sound like something that happened,
  not something that is happening.
- **No silence at the head.** Trim to the first sample of the transient, or the
  sound arrives late and feels disconnected from the tap.

On dopamine specifically, be careful what you claim: the striatal-reward work
on music (Salimpoor et al., 2011) is about *music listening over minutes*, not
about 300ms interface sounds, and it does not transfer cleanly. What does
transfer is duller and more useful — consonance is reliably preferred over
roughness, sharp high-frequency onsets are reliably disliked, and an identical
repeat habituates fast. Design against those three and the result is pleasant
for real reasons rather than for a cited one.

## Technical spec for replacement files

| | |
|---|---|
| Format | 48kHz or 44.1kHz, 16- or 24-bit, mono or stereo |
| Peak | normalise to about −12 dBFS, not to 0 |
| Head | trimmed to the transient, no leading silence |
| Tail | let it decay to silence; do not hard-cut |
| Length | `win`/`impact` ≤ 0.5s, `chime` ≤ 1.5s, `milestone` ≤ 2s |

Level matters more than it sounds like it does: these play over whatever else
is happening, mixed with the user's music, and the engine deliberately never
interrupts other audio (`.ambient`, `mixWithOthers`, silent switch respected).
A file normalised to 0 dBFS will be jarring rather than satisfying.

## What the synthesis does in the meantime

Six specific defects were fixed. The full reasoning is in the header of
`SoundEngine.swift`; the short version:

1. Partials moved from **1:2:3** (an organ) to the **inharmonic ratios of real
   struck bodies** — a marimba bar's 3.93x and 9.55x, a bell's 2.76x and 5.40x.
   Measured: energy at 2x and 3x is now effectively zero.
2. **Each partial decays at its own rate**, high ones fastest. This is most of
   what makes a sound resemble an object rather than a chord.
3. A short **contact transient** — filtered noise where the two things meet.
4. A **raised-cosine attack** replacing a 2ms linear ramp, and **exponential**
   release replacing a linear one. Measured: onset step is a third of the old
   engine's.
5. **A small room and stereo.** Dry mono is a test signal. The block impact is
   also panned to the column it landed in — a parameter that already existed,
   was documented, and had never once been passed.
6. **Round-robin variation** of pitch, decay and level on every trigger, because
   a byte-identical repeat is heard as mechanical within a few plays.

And the tritone: `focus` was F#4 against a C root — the single most dissonant
interval available — on one of six equally likely categories. It is now G4.
