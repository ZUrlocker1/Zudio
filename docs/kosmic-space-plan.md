# Kosmic Space — Design & Implementation Plan

Status: **Phase 1 ready to implement (2026-11-02).** Phases 2 and 3 are designed but wait
for listening on Phase 1.

This is the single document for Kosmic Space. It replaces the original plan, written in
September before Motorik Europe and Chill Soho were built, and the corpus review of
2026-11-02, whose findings are folded in here. Where this document and either earlier
version disagree, this one wins.

**Work on a branch** so `main` stays releasable.

---

## Contents

- What Kosmic Space is
- Evidence base
- Design principles
- Phase 1 — Oxygène (build now)
- Phase 2 — Magnetic
- Phase 3 — Chronologie (optional)
- Rule ledger: new, reused and dropped
- Implementation checklist
- Verification
- Open questions

---

## What Kosmic Space is

The Jean-Michel Jarre substyle of Kosmic, alongside Kosmic Drift. Base Kosmic blends Jarre
with Tangerine Dream, Vangelis, Eno, Craven Faults and Electric Buddha Band. Space concentrates
on Jarre alone, the same subtraction Motorik Arcade made.

**What makes it Jarre**, in order of how much each contributes:

1. A **sequencer** of one or two pitch classes in a gapped 16th-note rhythm, locked to the bar
   and moving with every chord
2. **Fast minor chord cycles** underneath it, 2–4 bars per chord in loops of 4–8 bars
3. A **bass** with its own fixed figure, walking chord tones (Oxygène) or pumping octaves
   (later albums)
4. A **preset rhythm box**, mechanical and unvarying
5. A **theme and a riff** that take turns by section
6. **String-machine pads**
7. **Noise sweeps** landing on section boundaries

**Naming.** `isKosmicSpace` on SongState. `displayStyleName` returns "Kosmic Space".

**Three flavours**, one per era, each coupling its own harmony, drums, bass and sequencer:

- **Oxygène** (1976). Phase 1.
- **Magnetic** (Équinoxe 1978 and Magnetic Fields 1981). Phase 2.
- **Chronologie** (1993, with Oxygène 7–13 and the 1980s pieces). Phase 3, optional.

A rhythm section built from one album's rules reads as that album; a mixed one reads as
nothing in particular. That is the lesson of Motorik Europe's sync groups.

---

## Evidence base

### The corpus

Sixteen fan transcriptions in `~/Downloads/jarre-midi`, outside the repo because they are
transcriptions of copyrighted works. Zack pruned duplicates and weak files, so each is a
distinct piece except Oxygène Part 4, which has two transcriptions. The two agree on the bass,
the riff and the theme.

- **Oxygène (1976)** — Part 3 (100 BPM), Part 4 (121, two transcriptions), Part 6 (110)
- **Équinoxe (1978)** — one file, part not given (120)
- **Magnetic Fields (1981)** — Parts 1 (132), 2 (98), 4 (91), 5 (120). Parts 2 and 4 were
  transcribed in double time and are corrected in the tools.
- **Zoolook (1984)** — Arpegiator (104)
- **Rendez-Vous (1986)** — Part 2 (135, 8.8 minutes)
- **Chronologie (1993)** — Parts 2 (162 as transcribed), 4 (120), 5 (119)
- **Oxygène 7–13 (1997)** — Part 8 (136), and an unnumbered "Oxygene" (105) that is probably
  from the same album

### Tools

All in `tools/`:

- `fetch_jarre_midi.py` — downloads the corpus. It writes outside the repo, so it needs the
  sandbox bypassed.
- `jarre_survey.py` — every part's program, register, density and active bars
- `jarre_deep.py` — role-aware passes: `--sections`, `--harmony`, `--seq`, `--bass`, `--drums`,
  `--pads`, `--tex`, `--lead`, `--interplay`. A hand-made `ROLES` map says which part plays
  which role, because guessing roles from register misfiled half of Jarre's parts.
- `jarre_analyze.py` — the original generic pass, superseded by `jarre_deep.py`

The caveats are the usual ones for fan transcriptions: hard quantisation and flat velocity.
**Velocity is out of scope**, since Jarre is sequencer music. Rules use Kosmic's existing
velocity conventions and add no dynamics.

### What the corpus establishes

- **Harmony moves fast.** Chords change every 1–4 bars (median 2) in loops of 4–8 bars. Long
  single chords occur only as pedal sections of 12–30 bars at intros and builds.
- **Sequencers are small and locked.** Mostly one or two pitch classes (root and octave, root
  and fifth, sometimes a leading tone) in a gapped 16th rhythm, locked to the bar and
  transposing with each chord. The only true phasing is a 3-note cell (Oxygène 8).
- **The 3-grouping is the common thread.** Figures grouped in threes against 4/4 appear in
  every era: the Équinoxe sequencer, the Oxygène 8 bass and harpsichord, the Magnetic Fields
  kick `x..xx..xx..xx..x` (Parts 1, 2 and 4), the Équinoxe and Chronologie 5 leads, and
  Oxygène 6's dotted quarters.
- **Riff and theme alternate by section.** In Oxygène 4 the slow falling theme carries the
  A sections and the fifth-rocking riff the B sections. In Équinoxe the sequencer and the lead
  never play at the same time.
- **Leads are oscillating or closed figures:**
  - see-saws: Oxygène 4 `[+7 −7 +7]`, Équinoxe `[−3 +3 −3]`
  - broken triads: Magnetic Fields 1 `[+3 +4 −7]`
  - turns descending in sequence: Magnetic Fields 2 `[+2 +1 −1 −2]`
- **Leads come and go.** Lead 1 plays in 17–93% of bars (median about 55%), and in under a
  third in the sparser pieces.
- **Modes**, across 15 pieces: Aeolian 6, Ionian 3, Dorian 2, harmonic minor 2, Phrygian 1,
  Mixolydian 1. Zudio's `Mode` enum already has `HarmonicMinor` and `Phrygian`.
- **Tempo** spans 91–136, median about 120.
- **Pads** are string machines in 13 of 15 pieces. Oxygène holds them 8 beats; the later
  albums one bar.
- **Sweeps** start just before 8-bar boundaries. Oxygène 4's land on bars 17, 25 and 33.
- **Lead timbres** chosen by the transcribers are synth strings and synth brass, not saw
  leads. This is weak evidence, but consistent across files.
- **Doubling.** Magnetic Fields 1's two sequencers are identical, and Part 4 triples its
  bass.
- **Quiet sections** occur in six pieces. Melodic density halves and two or more major parts
  leave. Magnetic Fields 1 is the clearest case: the sequencer, lead and drums go, the pads
  turn to choir, and the harmony changes cycle.

### What it overturned in the September plan

- 8–16-bar chords. The corpus moves every 1–4 bars.
- A 9–15-step scale-walk sequencer phasing against the bar. The corpus locks to the bar.
- A 120 BPM tempo cap.
- Excluding Phrygian and harmonic minor.
- A sequencer that never stops. Breakdowns drop it.
- Reusing base Kosmic's "JMJ" rules. `KOS-DRUM-001` "JMJ Mini Pops" plays a kick every other
  bar over quarter-note hats, nothing like the Minipops pattern measured on Oxygène 4.
  `KOS-RTHM-003`, `005` and `008` are scale arcs found in no source.

---

## Design principles

**Homage, not copy.** Every rule is a statistical constraint measured from a named work, and
no rule encodes a melody. Signature rules transform the source in two layers:

- **Per-song draws.** Interval, grouping, rotation and register come from a measured family.
  Where the source's own value is one option, it is weighted *below* the alternatives, so no
  song reproduces the original figure exactly.
- **Within-song development.** A figure is stated twice exactly, then transposes with the
  chord, the way the Oxygène 4 riff follows its chord from i to ii. Every fourth statement
  returns to the plain form.

**Named for the work.** Each new rule's name cites the album or piece it is measured from,
plus a short description. Its ID continues the track's numbering, and retired IDs are never
recycled. Lead rules use the `KOS-LD1-` and `KOS-LD2-` prefixes Kosmic Drift introduced.

**Bang for the buck.** We reuse an existing rule wherever one is close enough. Where several
measured figures are the same machine with different data, as every Jarre sequencer is, they
share one implementation with a preset per album.

**Keep the structure.** Space uses Kosmic's existing song structure: intro, A and B sections,
outro, and the forms ab, aba, abab and abba. Lead 1 can already play a different rule in B
sections, which delivers the theme and riff alternation for free. The one structural addition,
the Phase 2 breakdown, is a mute schedule, not a new section type.

**The one place we don't economise is harmony.** Kosmic's chord builder gives a section one
or two chords of at least 8 bars, at random roots. It cannot play a repeating cycle, and the
fast cycle under the sequencer is the core of the sound. So Phase 1 adds a chord-cycle builder,
and every flavour's progressions are then data.

**Determinism.** Space must not change what an existing base-Kosmic or Drift seed generates,
except that some base seeds now roll Space. That is the same trade Europe made. The Space
decision reuses Drift's existing roll value, and every *new* draw comes from a stream derived
from the song seed, so existing draws keep their order. Where Space skips a base step (the
bridge roll, the base tempo pick), it still consumes the RNG slot, as Drift already does.

---

## Phase 1 — Oxygène

Everything here is built in Phase 1. Space songs are all Oxygène until Phase 2 lands.

### Frame

**Space roll.** One draw, shared with Drift:

```
let roll = rng.nextDouble() // the existing Drift draw
isKosmicDrift = roll < driftShare
isKosmicSpace = !isKosmicDrift && roll < driftShare + spaceShare
```

**Testing split: Drift 10 / Space 80 / base 10**, so a test batch is mostly Space. Keep the two
shares as named constants in one place, because they will be readjusted when testing is done.
The intended release split is Drift 30 / Space 25 / base 45, to be confirmed by listening.

While the testing split is in force, Drift's threshold moves from 0.30 to 0.10, so some
existing Drift seeds generate differently. That is accepted for testing. The determinism test
below pins base and Drift seeds against the release split, and runs only once the release
values are restored.

**Tempo.** 100–124, triangular with a peak at 118. The corpus's Oxygène pieces run 100, 110
and 121. Draw it on the derived stream, consume the base tempo slot, and apply it before the
bar count is chosen so song length stays 225–270 seconds.

**Harmony family**, drawn per song:

- **Oxygène Dorian Vamp** (55%) — Dorian. *Oxygène 4.*
- **Oxygène Aeolian Cycle** (30%) — Aeolian. *Oxygène 8.*
- **Oxygène Two-Chord Sway** (15%) — Aeolian or Dorian 50/50. *Oxygène 3.*

The family sets the song mode. These are new `KosmicProgressionFamily` cases. The enum is
`Codable`, so new cases are appended and existing raw values never change.

**Percussion style.** A new `PercussionStyle` case for `KOS-DRUM-009`, appended to the enum.

### Harmony: the chord-cycle builder

New code in `KosmicStructureGenerator`, used only when `isKosmicSpace`. It replaces the 1–2
random chords per section with a cycle looped through the section.

A cycle is data: an array of `(degree: String, type: ChordType, bars: Int)`. Degree strings
are the ones `degreeSemitone` already accepts ("1", "2", "b3", "4", "b6", "b7" and so on).
Each window is built with `NotePoolBuilder.build`, exactly as today.

- **Body sections (A and B)** loop the cycle from the section's first bar, cutting the last
  window short at the section end.
- **Intro and outro** stay on the tonic, as Kosmic already forces. This doubles as the corpus's
  pedal intro.
- **Every window is 2 or 4 bars** and starts on an even bar. `KOS-PADS-001` re-attacks on even
  bars only, so an odd-bar change would leave the pad holding the old chord for a bar. If any
  Kosmic intro length is odd, round it to even for Space.
- **Variation.** Every fourth pass through the cycle takes its alternate last window, where
  the family has one.

**Phase 1 cycles:**

- **Oxygène Dorian Vamp** — i ×4, ii ×2, then a last window drawn per pass: i ×2 (50%),
  bIII ×2 (25%) or IV ×2 (25%). Measured from Oxygène 4, both transcriptions: i ×4, II ×2,
  bIII or IV or i ×2. The 1-bar bIII–IV pair in the source becomes one 2-bar window, to keep
  the even-bar rule.
- **Oxygène Aeolian Cycle** — i ×4, bVII ×2, iv ×2. Alternate last window: bVI ×2. Measured
  from Oxygène 8. Its occasional V (major) turnaround is left for Phase 2's harmonic-minor
  families.
- **Oxygène Two-Chord Sway** — i ×2, v ×2. Oxygène 3 alternates every bar; 2 bars keeps the
  even-bar rule and suits the slower pace.

Chord types: minor for i, ii, iv and v; major for bIII, IV (Dorian), bVI and bVII. Where the
mode makes a type non-diatonic, `NotePoolBuilder` already guards the clash.

### Structure

Space uses `KosmicStructureGenerator` as it is, with three changes:

- **Forms** ab 25%, aba 30%, abab 30%, abba 15%. No `single_evolving`: without a B section
  the riff never plays.
- **No bridges.** The bridge roll still consumes its RNG draw but always fails for Space. This
  removes the Electric Buddha drum bridges, the bridgeAlt call-and-response, bridgeMelody and
  the X-Files whistle, none of which is Jarre.
- **Chord windows** come from the cycle builder above.

Nothing else changes. Intro, A, B and outro keep their existing lengths and intensity labels.

### Rule pools

Each track's pool when `isKosmicSpace`, with weights. Rules not listed are excluded.

- **Drums** — `KOS-DRUM-009` Oxygène Preset Box 85%, `KOS-DRUM-000` No percussion 15%
- **Bass** — `KOS-BASS-018` Oxygène Falling Walk 75%, `KOS-BASS-001` Berlin School drone 25%
  (reused)
- **Rhythm** — `KOS-RTHM-016` Oxygène Octave Sequencer 100%
- **Pads** — `KOS-PADS-001` Eno long drone 100% (reused, string instruments)
- **Lead 1** — `KOS-LD1-013` Oxygène Falling Theme in A sections, `KOS-LD1-014` Oxygène See-Saw
  Riff in B sections. Both fire in every Space song through the existing A/B rule split.
- **Lead 2** — `KOS-LD2-000` No lead 2 50%, `KOS-LEAD-004` Echo melody 50% (reused)
- **Texture** — `KOS-TEXT-005` Oxygène Surf Sweep 100%

### New rules

Steps are 16ths: 16 steps a bar, 4 a beat, `stepIndex = bar * 16 + step`. "Root" means
`chordWindow.chordRoot` in the current window. Every pitch is snapped to the song's scale
after transposition. Register clamps fold by octaves, never clamp to the edge.

#### KOS-DRUM-009 "Oxygène Preset Box"

*The Minipops pattern measured on Oxygène 4, identical in both transcriptions (104 of 104
bars).*

Every bar the same:

- **Closed hat (42)** — steps 0, 1, 4, 5, 6, 8, 9, 10, 12, 13, 14 (`xx..xxx.xxx.xxx.`)
- **Kick (36)** — steps 0, 2, 6, 10 (`x.x...x...x.....`)
- **Clap (39)** — steps 4, 12
- **Open hat (46)** — step 2
- **Accent** — one voice on step 12, drawn per song: side stick (37), high tom (50) or
  tambourine (54)

`durationSteps: 1`. **No fills, no transition fills, no cold-start pickup, no intro or outro
variants.** The preset box never varies, which is its character. It plays through intro and
outro.

*Homage draws, per song:*

- **Hat mask** — the source (above, 0.25), or one of three variants that each move one gap
  (0.25 each):
  - `xx..xxx.xx.xxxx.`
  - `x.x.xxx.xxx.xxx.`
  - `xx.xxx..xxx.xxx.`
- **Kick** — the source (0.4) or steps 0, 6, 10 (0.6)

*Repeat guard:* drop one hat hit in every eighth bar, so no stretch exceeds 8 identical bars.

#### KOS-BASS-018 "Oxygène Falling Walk"

*Oxygène 4 bass, both transcriptions (89 of 105 and 94 of 114 bars in the main pattern).*

Six notes a bar, rhythm `x...x.x...x.x.x.` (steps 0, 4, 6, 10, 12, 14). Pitches are chord
tones relative to the root, measured as octave, b7, octave, 5, b7, 5:

- step 0: **top**, held 4 steps
- step 4: **mid**, held 2 steps
- step 6: **top**, held 4 steps
- step 10: **low**, held 1 step
- step 12: **mid**, held 2 steps
- step 14: **low**, held 1 step

Register MIDI 29–46, with the top note an octave above the root.

*Homage draws, per song:*

- **Falling set (top, mid, low)** — octave/6th/5th (0.35), octave/5th/3rd (0.35),
  octave/b7/5th (0.30, the source)
- **Rhythm** — the source (0.6), or `x.x.x.x...x.x.x.` (0.4), the second transcription's
  alternate

*Within song:* in 1 bar of 8 the figure shifts up a step, with 9th, octave and 6th in place of
top, mid and low (measured in 5 of 105 bars), so it does not repeat for a whole song.

#### KOS-RTHM-016 "Oxygène Octave Sequencer" — and the sequencer engine

*Oxygène 4 sequencer (45 of 104 bars in the main pattern, the rest one-gap variants).*

**The engine.** One function, `jmjStepSequencer(pattern:)`, used by every Space sequencer rule
in every phase. A pattern is 16 steps, each a rest or one of the slots root, octave, fifth,
lower neighbour (a semitone below the root, or the scale tone below) or third. Each bar the
engine emits the pattern against the current chord root. Register MIDI 48–64 (measured 48–62):
root in the octave starting at 48–55, other slots above it. `durationSteps: 1`. The same pattern plays
every bar. The chord transposes it, so with 2–4-bar chords no long identical run occurs.

**The Oxygène pattern** (source):

`R . O . R O R . O O R . O R O .`, which is root and octave alternating on steps 0, 2, 4, 5, 6,
8, 9, 10, 12, 13 and 14.

*Homage draws, per song:*

- **Mask** — the source (0.25), or one of the measured thinner variants (0.25 each): without
  step 9, without steps 9 and 13, or without steps 4, 9 and 13
- **Slot swap** — in 25% of songs the octave becomes the fifth throughout

*Rhythm never rests* except where the song's form gives it silence (Phase 2 breakdowns).
`ArrangementFilter` excludes Rhythm from block-silencing for Space, as Arcade does for Lead 1.

Phase 2 and 3 sequencer rules are new presets for this engine, not new code.

#### KOS-LD1-013 "Oxygène Falling Theme"

*Oxygène 4 theme, both transcriptions. In the source it is on a second voice. Here it moves to
Lead 1 for the A sections, which is how the source alternates theme and riff.*

A 2-bar statement. Five notes in rhythm `x.....x.x.x...x.` (steps 0, 6, 8, 10, 14), falling
from high through chord tones to the root:

- step 0: **top**, held 6 steps
- step 6: **5th**, held 2
- step 8: **3rd**, held 3
- step 10: **5th**, held 3
- step 14: **root**, held through the next bar (about 16 steps)

The second bar of each statement is the held root, then the next statement begins. Register:
the top note in 72–84, the root an octave below it.

*Homage draws, per song:*

- **Top note** — the octave above the root (0.3, the source), the 6th (0.35, measured as the
  second pattern) or the 4th (0.35)
- **Inner line** — 5–3–5 (0.35, the source), 5–4–5 (0.35), or 6–5–3 (0.3)
- **Rhythm** — the source (0.6), or the compressed form both transcriptions also use: four
  notes on steps 0, 2, 4, 6 falling by step to the root, the last held through the bar (0.4)

*Within song:* statements 1 and 2 exact. From statement 3, one variation per statement:

- transposed to the current chord root (0.4)
- the opening note dropped and the figure starting on step 6 (0.3)
- the final root replaced by the 5th, left open (0.3)

Every fourth statement is exact. One statement in four is replaced by 2 bars of rest, so the
theme breathes. Measured: the theme sounds in about half the bars of its sections.

#### KOS-LD1-014 "Oxygène See-Saw Riff"

*Oxygène 4 riff, both transcriptions. B sections only.*

Six notes rocking between an **anchor** (a chord tone) and a **pivot** a fixed interval above
it: anchor on steps 0, 2 and 5, pivot on steps 1, 4 and 6, step 3 silent. The last pivot is
held about 9 steps, through the rest of the bar. Notes 1 step long. Register 72–84,
a 12-semitone band.

Stated once a bar for 2 bars on a chord, then following the chord, so the anchor moves to the
new root. The source's interval also follows the chord (fifth, then minor sixth), so the pivot
is snapped to the scale after transposition.

*Homage draws, per song:*

- **Interval** — fourth (0.3), sixth (0.3), octave (0.2), fifth (0.2, the source)
- **Grouping** — 3+3 as source (0.4), 2+2+2 on steps 0, 1, 3, 4, 6, 7 (0.3), or 3+2 on
  steps 0, 1, 2, 4, 5 (0.3). All fit in half a bar.
- **Position** — first half of the bar (0.6, source) or second half, starting step 8 (0.4)
- **Anchor** — below the pivot (0.6, source) or above it, rocking downwards (0.4)

*Within song:*

- In 1 bar of 8, the anchor moves up to the chord's 4th (measured in 5 of 45 bars).
- The riff plays every bar of its B section, as in both transcriptions. The breathing comes
  from the A sections, where the theme rests about half the time.
- In the last B section, every second statement may drop to a single 3-note group, thinning
  the riff towards the outro.

#### KOS-TEXT-005 "Oxygène Surf Sweep"

*Oxygène 4, 6 and 8. Oxygène 4's swells start a beat before the boundary and run about two
bars.*

One long note per event on the noise instrument, starting at step 12 of the bar before an
8-bar boundary and held 32 steps. Pitch is the chord root in MIDI 60–72. The direction of the
swell comes from the Texture track's `sweep` effect, not from note movement.

- **Boundaries** — every section start except the first bar of the song, plus every 8th bar
  inside a body section. Emit at 70% of them, never within 8 bars of the previous event.
- **Variant** (25% of songs) — Oxygène 6's wash: a 2-bar swell every 2 bars through B sections
  only, nothing in A.

The automatic Kosmic filter sweep is switched off for Space. Its guard already excludes Drift
and needs to exclude Space too, so the two sweeps don't stack on the same boundaries.

### Reused rules

Used unchanged, with notes on why each is close enough.

- **`KOS-PADS-001` "Eno long drone"** — root, fifth, octave and upper third, re-attacked every
  2 bars on the current chord, swelling over 32 bars. With 2- and 4-bar chord windows it
  follows every change, which makes it the Oxygène string machine once it plays a string
  instrument. Its 1-in-8 breath gap matches the corpus's pads leaving and returning.
- **`KOS-BASS-001` "Berlin School drone"** — root held 2 bars, re-attacked. It stands in for
  the long-held basses of Oxygène 3 and 6 and the unnumbered Oxygène.
- **`KOS-LEAD-004` "Echo melody"** — a 2-bar phrase, 2 bars rest, the phrase a third away, 2
  bars rest. That is the corpus's statement-then-equal-silence. On Lead 2 it answers the theme
  without competing.
- **`KOS-LD2-000` "No lead 2"** and **`KOS-DRUM-000` "No percussion"** — as named.

### Things Kosmic does that Space switches off

Each is a flag check, following the existing Drift checks:

- **Bridges, and the X-Files whistle** that lives in them
- **Bass sub-layers** — the `KOS-RULE-17` staccato layer and the `KOS-RULE-23` tremolo layer.
  `KOS-BASS-018` is a complete figure, and extra layers blur it.
- **Drum fills and pickups** — the transition fill before section changes and the cold-start
  pickup
- **Lead 1 B-section escalation** ("Technique D"). Space sets its own A and B rules instead.
- **Lead 2 same-rule lag and sparse escalation.** Lead 2's pool here never draws a Lead 1 rule.
- **The automatic filter sweep**, as above

### Instruments

**Appended to the Kosmic pools.** Appending keeps every existing index, so saved songs still
point at the same sounds. Never reorder a pool. All are already in `Zudio.sf2` and unused by
Kosmic, so they cost no memory.

- **Lead 1** — Synth Brass 1 (0/62), Synth Brass 2 (0/63), 5th Saw Wave (0/86), Bright Saw
  Stack (11/100)
- **Lead 2** — Synth Strings 1 (0/50), Saw Lead (0/81), Square Lead 2 (12/80)
- **Pads** — Synth Strings 3 (8/50), Synth Strings 4 (11/50), Synth Strings 5 (11/51), Stereo
  Strings Slow (0/49)
- **Rhythm** — Synth Bass 1 (0/38)
- **Bass** — Fretless Bass (0/35)
- **Texture** — White Noise Wave (12/122)

**Space subsets**, enforced by both pick pools and the sanitiser:

- **Lead 1** — Brightness, Synth Brass 1, Synth Brass 2, 5th Saw Wave, Bright Saw Stack. The
  transcribers put synth brass and synth strings on Jarre's leads. The orchestral winds in the
  Kosmic pool (Flute, Oboe, Recorder, Shenai) read as Vangelis and are excluded.
- **Lead 2** — Brightness, Synth Strings 1, Saw Lead, Square Lead 2
- **Pads** — Synth Strings, Synth Strings 3, 4 and 5, Stereo Strings Slow, Sweep Pad. Strings
  are weighted to about 80% of picks.
- **Rhythm** — Moog, Synth Bass 1, Harpsi Pad
- **Bass** — Moog, Synth Bass 3, Fretless Bass
- **Texture** — White Noise Wave only in Phase 1, since the sweep rule needs a noise source
- **Drums** — 808 Kit, Machine Kit

**Where pools live.** Adding instruments touches four places: `poolNames`, `poolPrograms`,
`instrumentPickPool` and `instrumentPickPoolStatic`. The static one is the one usually missed.
Check the user-facing instrument picker in `TrackRowView` and its iPhone mirror in
`PhonePlayerView` show the appended names.

**Bank audition.** The picks above come from preset names and the transcribers' choices, not
from listening. Audition them in Phase 1. The string pad matters most. If no preset in the
bank sounds like a string machine, an external Solina-type sample is justified: about 2 MB for
a single extracted preset, licence permitting redistribution in a paid app, with
musical-artifacts.com the place to look (search "Solina", "string ensemble", "string
machine"). That is a Phase 1 listening decision, not a build step.

### Effects and stereo

- **Pads** take `sweep` in addition to Space's default reverb, slow and shallow, as the
  stand-in for the Small Stone phaser on Jarre's string machine
- **Rhythm** auto-pans across about ±40%
- **Bass and Drums** hard centre
- **Lead 1** centre or about 10% off
- **Lead 2** about 20% opposite Rhythm's current side
- **Pads** widest
- **Texture** keeps its existing panning

### Titles

`KosmicTitleGenerator` needs no new logic. Weight Space toward patterns 1, 2, 7 and 8 (a
coined word, a coined word plus a Roman numeral, fake-Greek, fake-Greek plus a numeral), which
echo the "Part IV" convention.

### Logging

One `GenerationLogEntry` with tag `Space` naming the flavour and harmony family, for example
`Space Oxygène, Dorian Vamp`. Each new rule's log line names its per-song draws, for example
`KOS-LD1-014 Oxygène See-Saw Riff (sixth, 2+2+2, second half)`, so a song's character can be
read from its log.

---

## Phase 2 — Magnetic

Begins after Phase 1 has been listened to. It adds the second flavour, the breakdown, and the
harmonic-minor and Phrygian families.

### Flavour roll

A `KosmicSpaceFlavour` enum (`oxygene`, `magnetic`, later `chronologie`), stored on SongState
and drawn on the derived stream: **Oxygène 50 / Magnetic 50** until Phase 3. The flavour picks
the harmony family, drums, bass and sequencer preset. Lead 1, Lead 2, Pads and Texture draw
from the shared Space pools, weighted toward the flavour.

**Magnetic tempo:** 92–132, peak 120.

### Breakdown

The one structural addition. It is a **mute schedule**, built the way Motorik Europe's section
dropout is:

- One breakdown per song, in Magnetic songs (70%) and Oxygène songs (30%). 8 or 12 bars,
  starting on an 8-bar boundary inside the second half of a body section, never in the first
  24 bars or the last 16.
- **Silent during it:** Rhythm, Lead 1 and Drums
- **Changed:** Bass switches to long held roots, as `KOS-BASS-001` does. The chord-cycle
  builder uses the family's **B-cycle** for those bars.
- **Unchanged:** Pads continue, and Texture emits a surf sweep into it and out of it.
- **Return:** drums re-enter on the next 8-bar boundary with the sweep landing.

Measured from Magnetic Fields 1, whose two 12-bar breakdowns drop sequencer, lead and drums
and change chord cycle.

### Harmony families, Magnetic

- **Magnetic Fields Harmonic Minor Arc** — i ×4, bVI ×4, iv ×4, V ×4, with V major. Mode
  `HarmonicMinor`. *Magnetic Fields 1.* B-cycle: bIII ×2, i ×2, bVI ×2, V ×2.
- **Magnetic Fields Harmonic Minor Turn** — i ×2, V ×2, bVI ×2, bVII ×2. Mode
  `HarmonicMinor`. *Magnetic Fields 2.* B-cycle: iv ×2, V ×2, i ×4.
- **Équinoxe Phrygian Cadence** — i ×8 (pedal), then iv ×2, bII ×2, bVII ×2, i ×2. Mode
  `Phrygian`. *Équinoxe.* B-cycle: bVI ×4, bIII ×4.
- **Magnetic Fields Major Descent** — I ×2, vi ×2, V ×2, IV ×2. Mode `Ionian`. *Magnetic
  Fields 4.* B-cycle: iii ×2, IV ×2, ii ×2, V ×2.

Weights: Arc 35, Turn 25, Phrygian 25, Major Descent 15.

**Oxygène B-cycles**, added in this phase for Oxygène breakdowns:

- Dorian Vamp: bIII ×2, IV ×2
- Aeolian Cycle: bVI ×2, bIII ×2
- Two-Chord Sway: iv ×4

### New rules, Phase 2

**KOS-DRUM-010 "Magnetic Fields Rhythm Box"** — *Magnetic Fields 1, 2 and 4.*

- Kick on steps 0, 3, 4, 7, 8, 11, 12, 15 (`x..xx..xx..xx..x`)
- Ride (51) or closed hat on all 16 steps
- Snare: off (0.5), or on steps 2, 3, 6, 10, 11, 14 (0.5, Part 2's pattern)
- In 30% of songs, an agogo-style voice on the quarters, from Part 4

No fills. *Homage:* the kick grouping rotates by 0, 3 or 6 steps per song.

**KOS-BASS-019 "Magnetic Octave Pump"** — one rule, three variants drawn per song:

- **Équinoxe octave eighths** (0.4) — root and octave alternating on the eight even steps.
  *Équinoxe, Chronologie 2.* 30% of these songs run 16ths instead, as Magnetic Fields 4 and
  Arpegiator do.
- **Magnetic Fields octave pops** (0.35) — a root pedal on 16ths, rhythm `x..xxxxxx..xxxxx`,
  with the octave on steps 4, 7, 12 and 15. *Magnetic Fields 2.* A sub-option alternates
  root and b7 instead (*Oxygène 8*).
- **Magnetic Fields leading-tone pedal** (0.25) — the octave with its lower neighbour a
  semitone below, rhythm `x..x.xxxx..x.xxx`, neighbour on steps 6 and 14. *Magnetic Fields
  1.* In `HarmonicMinor` songs, on the V chord, the neighbour is the leading tone.

Register MIDI 29–48.

**KOS-RTHM-017 "Équinoxe Fifth Triplets"** — a sequencer-engine preset. Root–fifth–fifth
groups across the bar, `R . 5 5 R 5 5 R R . 5 5 R 5 5 R`, 14 notes. *Équinoxe.*
*Homage:* the fifth becomes a fourth or octave per song (0.3 each, the source 0.4).

**KOS-RTHM-018 "Magnetic Fields Leading-Tone Cell"** — a sequencer-engine preset. Octave
and lower neighbour, 13 notes, `O . R O N R R O . R N O R . O R`, where N is the lower
neighbour. *Magnetic Fields 1.*

**KOS-LD1-015 "Magnetic Fields Turn Melody"** — *Magnetic Fields 2.* A turn figure
(`[+2 +1 −1 −2]`, `[−1 −2 +3]` and three relatives) in two 6-note 16th runs per bar on steps
2–7 and 10–15 (`..xxxxxx..xxxxxx`). Each half bar starts one scale step lower, so the line
sequences down over 3–5 steps, then resets. About 45% repeated notes. Register 62–84.
*Homage:* the turn shape is drawn per song from the five, and the sequence length per
statement. Within-song development as in Design principles.

**Équinoxe thirds as a See-Saw variant** — not a new rule. `KOS-LD1-014` gains two draws for
Magnetic songs: interval a minor or major third (Équinoxe's `[−3 +3 −3]`), and the rhythm
3+3+2 on steps 0, 2, 5, 8, 10, 13 (`x.x..x..x.x..x..`). In Phrygian songs the pivot may land
on bII.

**KOS-LD2-001 "Magnetic Fields Twin"** — one rule, two variants drawn per song:

- **Stereo twin** (0.5) — replays Rhythm's notes exactly on a different instrument, panned
  opposite. Rhythm's auto-pan is disabled when this fires. *Magnetic Fields 1, whose two
  sequencers are identical.*
- **Late octave** (0.5) — doubles Lead 1 an octave up, from the start of the last third of
  the song only. *Magnetic Fields 2.*

It generates no rhythm of its own, so it runs after Rhythm and Lead 1 and after any filter
that thins them. Motorik Europe's `MOT-LD2-012` is the code precedent.

### Phase 2 pools

**Magnetic songs:**

- **Drums** — `KOS-DRUM-010` 70%, `KOS-DRUM-009` 15%, `KOS-DRUM-000` 15%
- **Bass** — `KOS-BASS-019` 80%, `KOS-BASS-001` 20%
- **Rhythm** — `KOS-RTHM-017` 45%, `KOS-RTHM-018` 40%, `KOS-RTHM-016` 15%
- **Lead 1** — A sections `KOS-LD1-015` 60% or `KOS-LD1-013` 40%. B sections `KOS-LD1-014`
  (thirds variant weighted up) 60% or `KOS-LD1-015` 40%, never the same rule as A.
- **Lead 2** — `KOS-LD2-001` 45%, `KOS-LD2-000` 30%, `KOS-LEAD-004` 25%
- **Pads**, **Texture** — as Phase 1

**Oxygène songs:** as Phase 1, plus `KOS-LD2-001` at 25% of Lead 2 (No lead 2 drops to 35%,
Echo melody to 40%).

### Phase 2 instruments

Append Concert Choir (0/52) and Synth Voice (0/54) to Pads, for breakdowns only. Zudio picks
instruments per song, not per section, so the choir rides on **Texture** during a breakdown: a
held chord-root-and-fifth on Texture's instrument switched to Concert Choir for those bars. If
a per-section program change on Texture proves awkward, drop the choir. Pads already continue
through the breakdown, so the contrast holds without it.

---

## Phase 3 — Chronologie (optional)

Only if Phases 1 and 2 leave room for a third flavour after listening. Flavour split becomes
Oxygène 35 / Magnetic 35 / Chronologie 30. Tempo 108–136, peak 122.

### Harmony families, Chronologie

- **Chronologie Andalusian Descent** — i ×2, bVII ×2, bVI ×2, v ×2. Aeolian. *Chronologie 2,
  the unnumbered Oxygène.* B-cycle: a chromatic bass climb from i to v over a held tonic, 4
  bars, as a transition (*Chronologie 2*).
- **Chronologie Pop Loop** — I ×2, V ×2, ii ×2, IV ×2, alternating with I ×2, IV ×2, vi ×4.
  Ionian. *Chronologie 4.*
- **Zoolook Pedal** — one chord for 16 bars, then i ×4, bVII ×4, v ×8. Aeolian or Mixolydian.
  *Arpegiator, Rendez-Vous 2.*

### New rules, Phase 3

**KOS-DRUM-011 "Chronologie Four-on-the-Floor"** — kick on the quarters, snare or clap on 2
and 4. Hats drawn per song: 16th closed hats with tambourine `x.....xxx.....xx` (*Équinoxe*),
or eighth hats with a single high woodblock ticking 16ths (*Chronologie 4 and 5*). The tick
alone may run through an intro.

**KOS-RTHM-019 "Zoolook Pedal Arpeggiator"** — a sequencer-engine preset. A 16th root pedal
with an inserted note every third step, `[0 0 N 0 0 N 0 0 5 0 0 5 0 0 3 0]`, where N is the
lower neighbour. *Arpegiator.* *Homage:* the inserted slots are drawn from chord tones per
song.

**KOS-PADS-009 "Oxygène 7–13 Anticipated Strings"** — `KOS-PADS-001` with every attack moved
one 16th early, so each chord change lands on step 15 of the bar before. *Oxygène 8, the
unnumbered Oxygène.* A wrapper, not a new voicing.

### Reused in Phase 3

- **`KOS-LEAD-004` "Echo melody"** as the Chronologie Lead 1. It matches the measured
  Chronologie short calls: 2–6 notes, silence about equal to the statement.

### Phase 3 pools, Chronologie songs

- **Drums** — `KOS-DRUM-011` 75%, `KOS-DRUM-009` 10%, `KOS-DRUM-000` 15%
- **Bass** — `KOS-BASS-019` (eighths variant weighted up) 60%, `KOS-BASS-001` 40%
- **Rhythm** — `KOS-RTHM-019` 40%, `KOS-RTHM-016` 35%, `KOS-RTHM-017` 25%
- **Lead 1** — A sections `KOS-LEAD-004` 60% or `KOS-LD1-015` 40%. B sections `KOS-LD1-014`.
- **Lead 2** — as Magnetic
- **Pads** — `KOS-PADS-009` 60%, `KOS-PADS-001` 40%
- **Texture** — as Phase 1

---

## Rule ledger

### New: 15 rule IDs, 11 implementations

Phase 1, six rules:

- `KOS-DRUM-009` Oxygène Preset Box
- `KOS-BASS-018` Oxygène Falling Walk
- `KOS-RTHM-016` Oxygène Octave Sequencer, together with the sequencer engine
- `KOS-LD1-013` Oxygène Falling Theme
- `KOS-LD1-014` Oxygène See-Saw Riff
- `KOS-TEXT-005` Oxygène Surf Sweep

Phase 2, six rule IDs and four implementations:

- `KOS-DRUM-010` Magnetic Fields Rhythm Box
- `KOS-BASS-019` Magnetic Octave Pump
- `KOS-LD1-015` Magnetic Fields Turn Melody
- `KOS-LD2-001` Magnetic Fields Twin
- `KOS-RTHM-017` Équinoxe Fifth Triplets (a preset of the sequencer engine)
- `KOS-RTHM-018` Magnetic Fields Leading-Tone Cell (a preset)

Phase 3, three rule IDs and one-and-a-half implementations:

- `KOS-DRUM-011` Chronologie Four-on-the-Floor
- `KOS-RTHM-019` Zoolook Pedal Arpeggiator (a preset)
- `KOS-PADS-009` Oxygène 7–13 Anticipated Strings (a wrapper around `KOS-PADS-001`)

New infrastructure:

- Phase 1 — the chord-cycle builder, the Space flag and its plumbing
- Phase 2 — the flavour enum and the breakdown mute schedule

### Reused unchanged

- `KOS-PADS-001` Eno long drone
- `KOS-BASS-001` Berlin School drone
- `KOS-LEAD-004` Echo melody
- `KOS-LD2-000` No lead 2
- `KOS-DRUM-000` No percussion

### Excluded from Space

Base Kosmic keeps all of these. Nothing is removed from base Kosmic or Drift.

- **Drums** — `KOS-DRUM-001` through `008`. `001` "JMJ Mini Pops" does not match the measured
  Minipops pattern, and `009` replaces it for Space.
- **Bass** — every rule except `001`. Several are other artists' signatures: Tangerine Dream,
  Moroder, Neu!, Kraftwerk, McCartney, Loscil, Boards of Canada.
- **Rhythm** — `KOS-RTHM-001` through `015`, including the three "JMJ" ones (`003`, `005`,
  `008`), which match no source
- **Lead 1** — every `KOS-LEAD-` rule except `004`, and `KOS-LD1-010` to `012`
- **Pads** — every rule except `001`
- **Texture** — `KOS-TEXT-001` to `004`

### Considered and dropped

Each was a single-source nicety rather than central to the sound:

- Rendez-Vous statement drums
- the Oxygène 7–13 three-note phasing cell
- Rendez-Vous string eighths
- the Magnetic Fields broken-chord lead
- the Chronologie octave flicker
- the Équinoxe sustained answer
- Magnetic Fields bar-chord pads
- the Chronologie chromatic glissando
- the Chronologie bell bursts

The Oxygène reverse swell is folded into `KOS-TEXT-005`'s variant. The September plan's
`KOS-LEAD-013`, `015`, `016` and `017`, `KOS-RTHM-016` "Long Sequencer Cell", `KOS-BASS-018`
"Pulsing Stepwise Bass" and `KOS-DRUM-010` "Phased Pulse" were never built. Their IDs are
reassigned here, which is safe because no saved song can name them.

---

## Implementation checklist — Phase 1

Missing any one of these produces a half-existing substyle.

1. **`SongState.isKosmicSpace`** — a new stored property, plus **every `withXxx()` copy
   method**. Omitting one silently defaults it to false.
2. **`SongState.displayStyleName`** — returns "Kosmic Space", checked above the Drift case.
3. **`PersistedSong.displaySubstyleName`** (`AppState.swift`) — recognises Space songs.
4. **`CosmicMusicalFrameGenerator`** — the shared roll, tempo band and harmony family. New
   draws come from a derived stream.
5. **`KosmicProgressionFamily`** — three appended cases. **`PercussionStyle`** — one appended
   case.
6. **The chord-cycle builder** in `KosmicStructureGenerator`, with the even-bar alignment
   rule.
7. **`SongGenerator`** — Space form weights, and the bridge roll consumed but forced false.
8. **Thread `isKosmicSpace`** through the seven Cosmic generators, as `isKosmicDrift` already
   is, and through `PlaybackEngine` wherever Drift has a cached flag that affects Kosmic
   behaviour.
9. **Rule pools and the six new rules** in their generators:
   - `CosmicDrumGenerator` — `KOS-DRUM-009`
   - `CosmicBassGenerator` — `KOS-BASS-018`
   - `CosmicArpeggioGenerator` — the sequencer engine and `KOS-RTHM-016`
   - `CosmicLeadGenerator` — `KOS-LD1-013` and `014`, and the Lead 2 pool
   - `CosmicTextureGenerator` — `KOS-TEXT-005`
10. **Switch-offs** — bridges, bass sub-layers, drum fills and pickups, Lead 1 escalation,
    Lead 2 lag and escalation, the automatic filter sweep.
11. **`ArrangementFilter`** — exclude Rhythm from block-silencing when `isKosmicSpace`.
12. **Instruments** — append to the six Kosmic pools in all four places (`poolNames`,
    `poolPrograms`, `instrumentPickPool`, `instrumentPickPoolStatic`). Add the Space subsets,
    and a Space branch in `sanitiseInstruments`. Only two instruments are re-picked per song,
    so without the sanitiser a Space song inherits Flute on Lead 1 from the previous song.
13. **Rule-ID → description map** — the six new IDs.
14. **Log line** — the `Space` entry and the per-rule draw descriptions.
15. **Endless mode** — Space counts as Kosmic for style weighting and the streak cap.
16. **Effects defaults** — sweep on Pads, Rhythm auto-pan, stereo positions.
17. **iPhone** — check that `PhonePlayerView` mirrors anything `TrackRowView` does for Drift,
    especially `onChange(defaultsResetToken)` logic.

---

## Verification

Kept light, as usual: build, the affected suite, and a generated batch to listen to.

**Tests** (a new `KosmicSpaceTests`, pinning measurable behaviour as `MotorikSyncTests`
does):

- the flag survives every `SongState` copy method, and the roll is deterministic
- base Kosmic and Drift seeds that do not roll Space generate exactly what they did before.
  This is a `DeterminismTests` fingerprint on a fixed seed set, run against the release split.
- Space never has a bridge section or a `single_evolving` form
- every chord window in a Space song is 2 or 4 bars and starts on an even bar
- every Space song uses only the pooled rules, and Lead 1 plays `KOS-LD1-013` in A sections
  and `KOS-LD1-014` in B sections
- every Rhythm note is in key and on one of the pattern's steps
- `KOS-DRUM-009` emits identical bars apart from the 1-in-8 repeat guard
- tempo stays within 100–124

**Listening batch** — 20 Space songs. Listen for:

- whether the sequencer and chord cycle read as Jarre within the first 16 bars
- whether the theme and riff alternation is audible
- whether `KOS-PADS-001` on strings sounds like a string machine, or the bank needs a sample
- the Space share for release (testing runs 80%; the intended release share is 25%)

---

## Open questions

- **Two unidentified files.** The Équinoxe file has no part number, and the unnumbered
  Oxygène (105 BPM, fretless bass, choir, no lead) is probably from Oxygène 7–13. If either is
  recognised by ear, the rule names that cite them can be made exact.
- **Chronologie 2's tempo.** It is transcribed at 162 against 119–120 for the other
  Chronologie parts. It sets no number in this plan.
- **Phase 2 choir.** Whether a per-section program change on Texture is cheap enough, or the
  choir is dropped.
- **Phase 3 at all.** Decided after listening to Phases 1 and 2.
