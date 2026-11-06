# Kosmic Space — Design & Implementation Plan

Status: **Phase 1 built and merged to `main` as version 2.9 (build 135), a work in progress.**
Zack's first listen (2026-11-02) was encouraging. It reads as Jarre, with the sequences and
noise sweeps. The breaks below were added after that listen to relieve the monotony. Later
listens (2026-11-03) found the songs too alike, so Space now draws from several rules per track:
base Kosmic's JMJ rules and five more Oxygene rules, each track drawn independently. It builds on
macOS and iOS. No test suite has been run. See "Phase 1 as built" below for where the code had to
interpret this plan, and its sections "Breaks" and "More Oxygene rules" for what came after.
Phase 2 (Magnetic) began on 2026-11-06: its harmony families and its drum, bass, sequencer and
Lead 1 rules are built; see "Phase 2 as built". Still to come: KOS-LD2-001 Magnetic Fields Twin,
the See-Saw thirds variant and the breakdown. Phase 3 is designed but
waits for listening. The open scoping question is whether the Phase 2 breakdown becomes the
existing bridge's in-section form (see "Open questions").

This is the single document for Kosmic Space. It replaces the original plan, written in
September before Motorik Europe and Chill Soho were built, and the corpus review of
2026-11-02, whose findings are folded in here. Where this document and either earlier
version disagree, this one wins.

**Work happens on `main`.** Zack is the only user of the repo, so work in progress goes on
`main`, marked as version 2.9 work in progress. On 2026-11-03 Zack published the 2.9 DMG as
the README's download, marked as a work-in-progress build for testing Kosmic Space.

---

## Contents

- What Kosmic Space is
- Evidence base
- Design principles
- Phase 1 — Oxygene (build now)
- Phase 2 — Magnetic
- Phase 2 as built
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
3. A **bass** with its own fixed figure, walking chord tones (Oxygene) or pumping octaves
   (later albums)
4. A **preset rhythm box**, mechanical and unvarying
5. A **theme and a riff** that take turns by section
6. **String-machine pads**
7. **Noise sweeps** landing on section boundaries

**Naming.** `isKosmicSpace` on SongState. `displayStyleName` returns "Kosmic Space".

**Three eras of source**, whose rules all draw from one pool:

- **Oxygene** (1976). Phase 1.
- **Magnetic** (Equinoxe 1978 and Magnetic Fields 1981). Phase 2.
- **Chronologie** (1993, with Oxygene 7–13 and the 1980s pieces). Phase 3, optional.

There is no per-song flavour. Every track draws its rule independently from a pool that holds
the rules of every era, each as likely as the others on its track, so a song can pair Magnetic
Fields harmony with an Oxygene sequencer. The mixing is part of the variety. The generation
log names each rule by its album, so a song's sources stay visible.

---

## Evidence base

### The corpus

Sixteen fan transcriptions in `~/Downloads/jarre-midi`, outside the repo because they are
transcriptions of copyrighted works. Zack pruned duplicates and weak files, so each is a
distinct piece except Oxygene Part 4, which has two transcriptions. The two agree on the bass,
the riff and the theme.

- **Oxygene (1976)** — Part 3 (100 BPM), Part 4 (121, two transcriptions), Part 6 (110)
- **Equinoxe (1978)** — one file, part not given (120)
- **Magnetic Fields (1981)** — Parts 1 (132), 2 (98), 4 (91), 5 (120). Parts 2 and 4 were
  transcribed in double time and are corrected in the tools.
- **Zoolook (1984)** — Arpegiator (104)
- **Rendez-Vous (1986)** — Part 2 (135, 8.8 minutes)
- **Chronologie (1993)** — Parts 2 (162 as transcribed), 4 (120), 5 (119)
- **Oxygene 7–13 (1997)** — Part 8 (136), and an unnumbered "Oxygene" (105) that is probably
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
  transposing with each chord. The only true phasing is a 3-note cell (Oxygene 8).
- **The 3-grouping is the common thread.** Figures grouped in threes against 4/4 appear in
  every era: the Equinoxe sequencer, the Oxygene 8 bass and harpsichord, the Magnetic Fields
  kick `x..xx..xx..xx..x` (Parts 1, 2 and 4), the Equinoxe and Chronologie 5 leads, and
  Oxygene 6's dotted quarters.
- **Riff and theme alternate by section.** In Oxygene 4 the slow falling theme carries the
  A sections and the fifth-rocking riff the B sections. In Equinoxe the sequencer and the lead
  never play at the same time.
- **Leads are oscillating or closed figures:**
  - see-saws: Oxygene 4 `[+7 −7 +7]`, Equinoxe `[−3 +3 −3]`
  - broken triads: Magnetic Fields 1 `[+3 +4 −7]`
  - turns descending in sequence: Magnetic Fields 2 `[+2 +1 −1 −2]`
- **Leads come and go.** Lead 1 plays in 17–93% of bars (median about 55%), and in under a
  third in the sparser pieces.
- **Modes**, across 15 pieces: Aeolian 6, Ionian 3, Dorian 2, harmonic minor 2, Phrygian 1,
  Mixolydian 1. Zudio's `Mode` enum already has `HarmonicMinor` and `Phrygian`.
- **Tempo** spans 91–136, median about 120.
- **Pads** are string machines in 13 of 15 pieces. Oxygene holds them 8 beats; the later
  albums one bar.
- **Sweeps** start just before 8-bar boundaries. Oxygene 4's land on bars 17, 25 and 33.
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
  bar over quarter-note hats, nothing like the Minipops pattern measured on Oxygene 4.
  `KOS-RTHM-003`, `005` and `008` are scale arcs found in no source.

---

## Design principles

**Homage, not copy.** Every rule is a statistical constraint measured from a named work, and
no rule encodes a melody. Signature rules transform the source in two layers:

- **Per-song draws.** Interval, grouping, rotation and register come from a measured family.
  Where the source's own value is one option, it is weighted *below* the alternatives, so no
  song reproduces the original figure exactly.
- **Within-song development.** A figure is stated twice exactly, then transposes with the
  chord, the way the Oxygene 4 riff follows its chord from i to ii. Every fourth statement
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
and every harmony family's progressions are then data.

**Determinism.** Space must not change what an existing base-Kosmic or Drift seed generates,
except that some base seeds now roll Space. That is the same trade Europe made. The Space
decision reuses Drift's existing roll value, and every *new* draw comes from a stream derived
from the song seed, so existing draws keep their order. Where Space skips a base step (the
bridge roll, the base tempo pick), it still consumes the RNG slot, as Drift already does.

---

## Phase 1 — Oxygene

Everything here is built in Phase 1. Space songs are all Oxygene until Phase 2 lands.

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

**Tempo.** 96–128, triangular with a peak at 118 (widened from 100–124 for the Magnetic Fields
and Equinoxe pieces). The corpus's Oxygene pieces run 100, 110 and 121. Draw it on the derived stream, consume the base tempo slot, and apply it before the
bar count is chosen so song length stays 225–270 seconds.

**Harmony family**, drawn per song:

- **Oxygene Dorian Vamp** — Dorian. *Oxygene 4.*
- **Oxygene Aeolian Cycle** — Aeolian. *Oxygene 8.*
- **Oxygene Two-Chord Sway** — Aeolian or Dorian 50/50. *Oxygene 3.*

Within the Oxygene three the weights are 55 / 30 / 15. Since Phase 2 they share one pool with the
four Magnetic families, each of which has the weight of an average Oxygene family; see "Phase 2
as built". The family sets the song mode. These are new `KosmicProgressionFamily` cases. The enum is
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

- **Oxygene Dorian Vamp** — i ×4, ii ×2, then a last window drawn per pass: i ×2 (50%),
  bIII ×2 (25%) or IV ×2 (25%). Measured from Oxygene 4, both transcriptions: i ×4, II ×2,
  bIII or IV or i ×2. The 1-bar bIII–IV pair in the source becomes one 2-bar window, to keep
  the even-bar rule.
- **Oxygene Aeolian Cycle** — i ×4, bVII ×2, iv ×2. Alternate last window: bVI ×2. Measured
  from Oxygene 8. Its occasional V (major) turnaround is left for Phase 2's harmonic-minor
  families.
- **Oxygene Two-Chord Sway** — i ×2, v ×2. Oxygene 3 alternates every bar; 2 bars keeps the
  even-bar rule and suits the slower pace.

Chord types: minor for i, ii, iv and v; major for bIII, IV (Dorian), bVI and bVII. Where the
mode makes a type non-diatonic, `NotePoolBuilder` already guards the clash.

### Structure

Space uses `KosmicStructureGenerator` as it is, with three changes:

- **Forms** ab 25%, aba 30%, abab 30%, abba 15%. No `single_evolving`: without a B section
  the riff never plays.
- **No bridges.** The bridge roll still consumes its RNG draw but always fails for Space. This
  removes the Electric Buddha drum bridges, the bridgeAlt call-and-response, bridgeMelody and
  the X-Files whistle, none of which is Jarre. Space has had its own bridge since 2026-11-03, a mute
  schedule rather than a section; see "Bridges" under "Phase 1 as built".
- **Chord windows** come from the cycle builder above.

Nothing else changes. Intro, A, B and outro keep their existing lengths and intensity labels.

### Rule pools

Each track's pool when `isKosmicSpace`, as first built. Rules not listed were excluded. The pools
have since grown; the current weights are under "More Oxygene rules" in "Phase 1 as built".

- **Drums** — `KOS-DRUM-009` Oxygene Preset Box 85%, `KOS-DRUM-000` No percussion 15%
- **Bass** — `KOS-BASS-018` Oxygene Falling Walk 75%, `KOS-BASS-001` Berlin School drone 25%
  (reused)
- **Rhythm** — `KOS-RTHM-016` Oxygene Octave Sequencer 100%
- **Pads** — `KOS-PADS-001` Eno long drone 100% (reused, string instruments)
- **Lead 1** — `KOS-LD1-013` Oxygene Falling Theme in A sections, `KOS-LD1-014` Oxygene See-Saw
  Riff in B sections. Both fire in every Space song through the existing A/B rule split.
- **Lead 2** — `KOS-LD2-000` No lead 2 50%, `KOS-LEAD-004` Echo melody 50% (reused)
- **Texture** — `KOS-TEXT-005` Oxygene Surf Sweep 100%

### New rules

Steps are 16ths: 16 steps a bar, 4 a beat, `stepIndex = bar * 16 + step`. "Root" means
`chordWindow.chordRoot` in the current window. Every pitch is snapped to the song's scale
after transposition. Register clamps fold by octaves, never clamp to the edge.

#### KOS-DRUM-009 "Oxygene Preset Box"

*The Minipops pattern measured on Oxygene 4, identical in both transcriptions (104 of 104
bars).*

Every bar the same:

- **Closed hat (42)** — steps 0, 1, 4, 5, 6, 8, 9, 10, 12, 13, 14 (`xx..xxx.xxx.xxx.`)
- **Kick (36)** — steps 0, 2, 6, 10 (`x.x...x...x.....`)
- **Clap (39)** — steps 4, 12
- **Open hat (46)** — step 2
- **Accent** — one voice on step 12, drawn per song: side stick (37), high tom (50) or
  tambourine (54)

`durationSteps: 1`. **No transition fills, no cold-start pickup, no intro or outro
variants.** The preset box never varies, which is its character. It plays through intro and
outro. The one exception is the fills at the edges of the arrangement's breaks (see "Breaks"
below), which are Zudio's own addition, not the corpus's.

*Homage draws, per song:*

- **Hat mask** — the source (above, 0.25), or one of three variants that each move one gap
  (0.25 each):
  - `xx..xxx.xx.xxxx.`
  - `x.x.xxx.xxx.xxx.`
  - `xx.xxx..xxx.xxx.`
- **Kick** — the source (0.4) or steps 0, 6, 10 (0.6)

*Repeat guard:* drop one hat hit in every eighth bar, so no stretch exceeds 8 identical bars.

#### KOS-BASS-018 "Oxygene Falling Walk"

*Oxygene 4 bass, both transcriptions (89 of 105 and 94 of 114 bars in the main pattern).*

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

#### KOS-RTHM-016 "Oxygene Octave Sequencer" — and the sequencer engine

*Oxygene 4 sequencer (45 of 104 bars in the main pattern, the rest one-gap variants).*

**The engine.** One function, `jmjStepSequencer(pattern:)`, used by every Space sequencer rule
in every phase. A pattern is 16 steps, each a rest or one of the slots root, octave, fifth,
lower neighbour (a semitone below the root, or the scale tone below) or third. Each bar the
engine emits the pattern against the current chord root. Register MIDI 48–64 (measured 48–62):
root in the octave starting at 48–55, other slots above it. `durationSteps: 1`. The same pattern plays
every bar. The chord transposes it, so with 2–4-bar chords no long identical run occurs.

**The Oxygene pattern** (source):

`R . O . R O R . O O R . O R O .`, which is root and octave alternating on steps 0, 2, 4, 5, 6,
8, 9, 10, 12, 13 and 14.

*Homage draws, per song:*

- **Mask** — the source (0.25), or one of the measured thinner variants (0.25 each): without
  step 9, without steps 9 and 13, or without steps 4, 9 and 13
- **Slot swap** — in 25% of songs the octave becomes the fifth throughout

*Rhythm never rests* except where the song's form gives it silence (Phase 2 breakdowns).
`ArrangementFilter` excludes Rhythm from block-silencing for Space, as Arcade does for Lead 1.

Phase 2 and 3 sequencer rules are new presets for this engine, not new code.

#### KOS-LD1-013 "Oxygene Falling Theme"

*Oxygene 4 theme, both transcriptions. In the source it is on a second voice. Here it moves to
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

#### KOS-LD1-014 "Oxygene See-Saw Riff"

*Oxygene 4 riff, both transcriptions. B sections only.*

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

#### KOS-TEXT-005 "Oxygene Surf Sweep"

*Oxygene 4, 6 and 8. Oxygene 4's swells start a beat before the boundary and run about two
bars.*

One long note per event on the noise instrument, starting at step 12 of the bar before an
8-bar boundary and held 32 steps. Pitch is the chord root in MIDI 60–72. The direction of the
swell comes from the Texture track's `sweep` effect, not from note movement.

- **Boundaries** — every section start except the first bar of the song, plus every 8th bar
  inside a body section. Emit at 70% of them, never within 8 bars of the previous event.
- **Variant** (25% of songs) — Oxygene 6's wash: a 2-bar swell every 2 bars through B sections
  only, nothing in A.

The automatic Kosmic filter sweep is switched off for Space. Its guard already excludes Drift
and needs to exclude Space too, so the two sweeps don't stack on the same boundaries.

### Reused rules

Used unchanged, with notes on why each is close enough.

- **`KOS-PADS-001` "Eno long drone"** — root, fifth, octave and upper third, re-attacked every
  2 bars on the current chord, swelling over 32 bars. With 2- and 4-bar chord windows it
  follows every change, which makes it the Oxygene string machine once it plays a string
  instrument. Its 1-in-8 breath gap matches the corpus's pads leaving and returning.
- **`KOS-BASS-001` "Berlin School drone"** — root held 2 bars, re-attacked. It stands in for
  the long-held basses of Oxygene 3 and 6 and the unnumbered Oxygene.
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
- **Rhythm** — Pulse Bass (11/39). Synth Bass 1 (0/38) was first, but its preset plays a 25 ms click and then silence at every pitch and length (measured offline, 2026-11-02), so it was swapped out
- **Bass** — Fretless Bass (0/35)
- **Texture** — White Noise Wave (12/122, shown in the picker as "White Noise"), Solar Wind 2 (12/89), Starship (8/125), Interference (11/127). Solar Wind (11/89) was already in the pool.

**Space subsets**, enforced by both pick pools and the sanitiser:

- **Lead 1** — Brightness, Synth Brass 1, Synth Brass 2, 5th Saw Wave, Bright Saw Stack. The
  transcribers put synth brass and synth strings on Jarre's leads. The orchestral winds in the
  Kosmic pool (Flute, Oboe, Recorder, Shenai) read as Vangelis and are excluded.
- **Lead 2** — Brightness, Synth Strings 1, Saw Lead, Square Lead 2
- **Pads** — Synth Strings, Synth Strings 3, 4 and 5, Stereo Strings Slow, Sweep Pad. Strings
  are weighted to about 80% of picks.
- **Rhythm** — Moog, Pulse Bass, Harpsi Pad
- **Bass** — Moog, Synth Bass 3, Fretless Bass
- **Texture** — White Noise Wave, Solar Wind, Solar Wind 2, Starship and Interference, 20% each (Zack, 2026-11-02). The sweep rule needs a noise or wind source, so the musical pad swells (Halo Pad, Atmosphere, Sweep Pad, Bowed Glass, Space Voice) were left out. Levels were measured offline (2026-11-02): Solar Wind 2 gain 1.5 (it was half as loud as Solar Wind at 0.40), Starship 0.8 (it ran about 1.7 times White Noise Wave at the default 1.4). Interference is the quietest of the five at the default gain and is unchanged. Space Lead 1 Synth Brass 2 is trimmed to 0.20 and Space Lead 2 Saw Lead to 0.45, both measured several times louder than their neighbours.
- **Drums** — 808 Kit 75%, Machine Kit 25%. Space plays Machine Kit's own synth toms, the
  bloops, in its fills; the tom-to-snare remap written for Noir skips Space (2026-11-03).

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
- **Texture** takes an auto-pan (Zack, 2026-11-02), one full sweep per 2, 4 or 8 bars (25/50/25), drawn per song from the seed by `KosmicMusicalFrameGenerator.spaceTexturePanBars`. Solar Wind on Space Texture has its own gain of 0.85; base Kosmic and Drift keep 0.40.

### Titles

`KosmicTitleGenerator` needs no new logic. Weight Space toward patterns 1, 2, 7 and 8 (a
coined word, a coined word plus a Roman numeral, fake-Greek, fake-Greek plus a numeral), which
echo the "Part IV" convention.

### Logging

The harmony family shows on the `Chords` line of the generation log, for example
`Oxygene Dorian Vamp i ii` or `Magnetic Fields Arc i bVI iv V`. Each new rule's log line names its per-song draws, for example
`KOS-LD1-014 Oxygene See-Saw Riff (sixth, 2+2+2, second half)`, so a song's character can be
read from its log.

---

## Phase 2 — Magnetic

Begins after Phase 1 has been listened to. It adds the Magnetic rules, the breakdown, and the
Magnetic Fields and Equinoxe harmony families.

### One pool, no flavour roll

Phase 2's rules join Phase 1's in a single Space pool. There is no flavour enum, no flavour roll
and no new SongState field. Each track draws independently, as it does in Phase 1, and every new
rule carries the same weight as the other rules on its track. Exclusions exist only between two
busy parts, as the Pump and the Octave Sequencer. Tempo is the one Space range, 96–128, peak 118.
The "Phase 2 pools" below list the rules each track gains rather than separate Magnetic and
Oxygene pools.

### Breakdown

The one structural addition. It is a **mute schedule**, built the way Motorik Europe's section
dropout is:

- One breakdown per song, at a single share for all Space songs. 8 or 12 bars,
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

Built 2026-11-06; see "Phase 2 as built". Each family is a KosmicProgressionFamily case with its
own A cycle, B cycle and breakdown chords:

- **Magnetic Fields Arc** — i ×4, bVI ×4, iv ×4, V ×4, with V major. Aeolian. *Magnetic Fields 1.*
  B-cycle: bIII, bVI, V, i ×2 each.
- **Magnetic Fields Turn** — i ×2, V ×2, bVI ×2, bVII ×2, with V major. Aeolian. *Magnetic Fields 2.*
  B-cycle: iv ×2, V ×2, i ×4.
- **Equinoxe Phrygian** — i ×8 (pedal), then iv ×2, bII ×2, bvii ×2, i ×2. Phrygian. *Equinoxe.*
  B-cycle: bVI, bIII, bII, i ×2 each.
- **Magnetic Fields Descent** — I ×2, vi ×2, V ×2, IV ×2. Ionian. *Magnetic Fields 4.* B-cycle:
  iii, IV, V, I ×2 each.

**Oxygene B-cycles** (built in Phase 1): Dorian Vamp bIII ×2, IV ×2, i ×4; Aeolian Cycle bVI, bIII,
bVII, i ×2 each; Two-Chord Sway i ×2, iv ×2.

### New rules, Phase 2

**KOS-DRUM-010 "Magnetic Fields Rhythm Box"** — *Magnetic Fields 1, 2 and 4.*

- Kick on steps 0, 3, 4, 7, 8, 11, 12, 15 (`x..xx..xx..xx..x`)
- Ride (51) or closed hat on all 16 steps
- Snare: off (0.5), or on steps 2, 3, 6, 10, 11, 14 (0.5, Part 2's pattern)
- In 30% of songs, an agogo-style voice on the quarters, from Part 4

*Homage:* the kick grouping rotates by 0, 3 or 6 steps per song. Jarre plays no fills, but the
Magnetic rhythm box gets short, subtle ones at section boundaries and where drums drop out or come
back, so a hundred bars of sequenced drums do not sit unbroken.

**KOS-BASS-019 "Magnetic Fields Octave Pump"** — one rule, three variants drawn per song. (Its Oxygene 8
root-and-b7 sub-option was built early as `KOS-BASS-020` Oxygene 8 Pump, 2026-11-03, and can be
dropped from this rule.)

- **Equinoxe octave eighths** (0.4) — root and octave alternating on the eight even steps.
  *Equinoxe, Chronologie 2.* 30% of these songs run 16ths instead, as Magnetic Fields 4 and
  Arpegiator do.
- **Magnetic Fields octave pops** (0.35) — a root pedal on 16ths, rhythm `x..xxxxxx..xxxxx`,
  with the octave on steps 4, 7, 12 and 15. *Magnetic Fields 2.* A sub-option alternates
  root and b7 instead (*Oxygene 8*).
- **Magnetic Fields leading-tone pedal** (0.25) — the octave with its lower neighbour a
  semitone below, rhythm `x..x.xxxx..x.xxx`, neighbour on steps 6 and 14. *Magnetic Fields
  1.* On a major V chord, the neighbour is the leading tone (spaceChordScale).

Register MIDI 29–48. Like the drums, the Magnetic bass varies over the song rather than playing one
unchanging pattern, as the Pump and the Falling Walk already do.

**KOS-RTHM-017 "Equinoxe Fifth Triplets"** — a sequencer-engine preset. Root–fifth–fifth
groups across the bar, `R . 5 5 R 5 5 R R . 5 5 R 5 5 R`, 14 notes. *Equinoxe.*
*Homage:* the fifth becomes a fourth or octave per song (0.3 each, the source 0.4).

**KOS-RTHM-018 "Magnetic Fields Leading-Tone Cell"** — a sequencer-engine preset. Octave
and lower neighbour, 13 notes, `O . R O N R R O . R N O R . O R`, where N is the lower
neighbour. *Magnetic Fields 1.*

**KOS-LD1-015 "Magnetic Fields Turn Melody"** — *Magnetic Fields 2.* A turn figure
(`[+2 +1 −1 −2]`, `[−1 −2 +3]` and three relatives) in two 6-note 16th runs per bar on steps
2–7 and 10–15 (`..xxxxxx..xxxxxx`). Each half bar starts one scale step lower, so the line
sequences down over 3–5 steps, then resets. About 45% repeated notes. Register 62–84.
*Homage:* the turn shape is drawn per song from the five, and the sequence length per
statement. Within-song development as in Design principles. Like the Oxygene lead rules, every new Lead 1
rule varies its figure from song to song, so the new rules bring different melodies and not just a
different tempo, key or scale.

**Equinoxe thirds as a See-Saw variant** — not a new rule. `KOS-LD1-014` gains two draws for
Magnetic songs: interval a minor or major third (Equinoxe's `[−3 +3 −3]`), and the rhythm
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

Every track keeps one Space pool, and the Magnetic rules join it (see "One pool, no flavour roll"
and, for the weights as built, "Phase 2 as built"):

- **Drums** — gains `KOS-DRUM-010`
- **Bass** — gains `KOS-BASS-019`; neither pump plays under a busy sequencer
- **Rhythm** — gains `KOS-RTHM-017` and `KOS-RTHM-018`, both busy
- **Lead 1** — A sections gain `KOS-LD1-015`. B sections keep `KOS-LD1-014` or `KOS-LEAD-006`; the
  See-Saw's thirds variant, above, is not built yet
- **Lead 2** — will gain `KOS-LD2-001`, not built yet
- **Pads**, **Texture** — as Phase 1

### Phase 2 instruments

Append Concert Choir (0/52) and Synth Voice (0/54) to Pads, for breakdowns only. Zudio picks
instruments per song, not per section, so the choir rides on **Texture** during a breakdown: a
held chord-root-and-fifth on Texture's instrument switched to Concert Choir for those bars. If
a per-section program change on Texture proves awkward, drop the choir. Pads already continue
through the breakdown, so the contrast holds without it.

---

## Phase 3 — Chronologie (optional)

Only if Phases 1 and 2 leave room for a third era of source after listening. Its rules join the
same single pool. Tempo 108–136, peak 122.

### Harmony families, Chronologie

- **Chronologie Andalusian Descent** — i ×2, bVII ×2, bVI ×2, v ×2. Aeolian. *Chronologie 2,
  the unnumbered Oxygene.* B-cycle: a chromatic bass climb from i to v over a held tonic, 4
  bars, as a transition (*Chronologie 2*).
- **Chronologie Pop Loop** — I ×2, V ×2, ii ×2, IV ×2, alternating with I ×2, IV ×2, vi ×4.
  Ionian. *Chronologie 4.*
- **Zoolook Pedal** — one chord for 16 bars, then i ×4, bVII ×4, v ×8. Aeolian or Mixolydian.
  *Arpegiator, Rendez-Vous 2.*

### New rules, Phase 3

**KOS-DRUM-011 "Chronologie Four-on-the-Floor"** — kick on the quarters, snare or clap on 2
and 4. Hats drawn per song: 16th closed hats with tambourine `x.....xxx.....xx` (*Equinoxe*),
or eighth hats with a single high woodblock ticking 16ths (*Chronologie 4 and 5*). The tick
alone may run through an intro.

**KOS-RTHM-019 "Zoolook Pedal Arpeggiator"** — a sequencer-engine preset. A 16th root pedal
with an inserted note every third step, `[0 0 N 0 0 N 0 0 5 0 0 5 0 0 3 0]`, where N is the
lower neighbour. *Arpegiator.* *Homage:* the inserted slots are drawn from chord tones per
song.

**KOS-PADS-009 "Oxygene 7–13 Anticipated Strings"** — `KOS-PADS-001` with every attack moved
one 16th early, so each chord change lands on step 15 of the bar before. *Oxygene 8, the
unnumbered Oxygene.* A wrapper, not a new voicing.

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

- `KOS-DRUM-009` Oxygene Preset Box
- `KOS-BASS-018` Oxygene Falling Walk
- `KOS-RTHM-016` Oxygene Octave Sequencer, together with the sequencer engine
- `KOS-LD1-013` Oxygene Falling Theme
- `KOS-LD1-014` Oxygene See-Saw Riff
- `KOS-TEXT-005` Oxygene Surf Sweep

Phase 2, six rule IDs; five built 2026-11-06:

- `KOS-DRUM-010` Magnetic Fields Rhythm Box — built
- `KOS-BASS-019` Magnetic Fields Octave Pump — built
- `KOS-LD1-015` Magnetic Fields Turn Melody — built
- `KOS-RTHM-017` Equinoxe Fifth Triplets (a preset of the sequencer engine) — built
- `KOS-RTHM-018` Magnetic Fields Leading-Tone Cell (a preset) — built
- `KOS-LD2-001` Magnetic Fields Twin — not built yet

Phase 3, three rule IDs and one-and-a-half implementations:

- `KOS-DRUM-011` Chronologie Four-on-the-Floor
- `KOS-RTHM-019` Zoolook Pedal Arpeggiator (a preset)
- `KOS-PADS-009` Oxygene 7–13 Anticipated Strings (a wrapper around `KOS-PADS-001`)

New infrastructure:

- Phase 1 — the chord-cycle builder, the Space flag and its plumbing
- Phase 2 — the chord's own scale and the fit pass (spaceChordScale, fitSpaceChordScale), built;
  the breakdown mute schedule, not built

### Reused unchanged

- `KOS-PADS-001` Eno long drone
- `KOS-BASS-001` Berlin School drone
- `KOS-LEAD-004` Echo melody
- `KOS-LD2-000` No lead 2
- `KOS-DRUM-000` No percussion

### Added after the first listens (2026-11-03)

- Base Kosmic's JMJ rules, which match no transcription but which Zack wanted for variety:
  `KOS-DRUM-001` JMJ Mini Pops, `KOS-RTHM-002` JMJ Hook, `KOS-RTHM-005` JMJ Dual-Rate and
  `KOS-LEAD-006` JMJ Phrase Loop (B sections)
- Five new Oxygene rules: `KOS-LD1-016` Oxygene 6 Rising Strings, `KOS-BASS-020` Oxygene 8 Pump,
  `KOS-RTHM-021` Oxygene 8 Offbeat Pedal, `KOS-PADS-010` Oxygene 4 Staggered Bloom and
  `KOS-DRUM-012` Oxygene 6 Hand Percussion; then `KOS-LD1-017` Oxygene 8 Offbeat Climb. Ten more
  candidates are listed under "More Oxygene rules".

### Excluded from Space

Base Kosmic keeps all of these. Nothing is removed from base Kosmic or Drift.

- **Drums** — `KOS-DRUM-002` through `008`. `001` "JMJ Mini Pops" was excluded at first, as it
  does not match the measured Minipops pattern, and joined the pool on 2026-11-03.
- **Bass** — every rule except `001`. Several are other artists' signatures: Tangerine Dream,
  Moroder, Neu!, Kraftwerk, McCartney, Loscil, Boards of Canada.
- **Rhythm** — `KOS-RTHM-001` through `015` except `002` and `005`, which joined on 2026-11-03.
  The other "JMJ" ones, `003` and `008`, are slow solo lines and stay out.
- **Lead 1** — every `KOS-LEAD-` rule except `004` and `006`, and `KOS-LD1-010` to `012`
- **Pads** — every base rule except `001`
- **Texture** — `KOS-TEXT-001` to `004`

### Considered and dropped

Each was a single-source nicety rather than central to the sound:

- Rendez-Vous statement drums
- the Oxygene 7–13 three-note phasing cell
- Rendez-Vous string eighths
- the Magnetic Fields broken-chord lead
- the Chronologie octave flicker
- the Equinoxe sustained answer
- Magnetic Fields bar-chord pads
- the Chronologie chromatic glissando
- the Chronologie bell bursts

The Oxygene reverse swell is folded into `KOS-TEXT-005`'s variant. The September plan's
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

## Phase 1 as built (2026-11-02)

Where the plan left a gap or could not be followed literally, the code does this:

- **Sequencer register.** The root sits in MIDI 48–59, with the octave above it. The plan's
  48–64 cannot hold root and octave for all twelve keys.
- **Bass register.** The root (never played) sits in 23–34, so the top note lands in 35–46.
  With the octave/5th/3rd set, the low note can reach 26 in the keys of B, C and C#.
- **Bass alternate rhythm.** `x.x.x.x...x.x.x.` has seven hits. Their roles are top, mid,
  top, mid, low, mid, low, keeping the same fall.
- **Theme, compressed rhythm.** The four notes on steps 0, 2, 4 and 6 fall by scale step:
  4th, 3rd, 2nd, root. The top-note draw does not apply to this form.
- **Riff register.** The anchor and pivot pair is folded by octaves so its midpoint lies in
  72–84.
- **Preset box.** The open hat owns step 2, so a hat mask's closed hat there is not played.
  The repeat guard drops the mask's last hat in every eighth bar.
- **Rhythm is never thinned.** Besides the `ArrangementFilter` exemption, Space skips base
  Kosmic's density guard and the second-B Rhythm thinning, because either would break the
  locked pattern. Since 2026-11-03 Lead 1, Lead 2 and Pads are exempt from `ArrangementFilter`
  too (Zack): their rests come from `KosmicSpaceArrangement`. Measured over 50 songs, the filter
  had never touched them, so no song changed.
- **Forced base rules are ignored** by Space, as Drift's bass already does. The curated first
  Kosmic song forces KOS-BASS-010, KOS-RTHM-002 and the Electric Buddha groove; under the
  testing split it usually rolls Space, and would otherwise be a hybrid.
- **Texture takes `sweep`** by default, since KOS-TEXT-005 relies on it for the swell's shape.
- **Panning.** Lead 1 is at −0.10 and Lead 2 at −0.20, opposite Rhythm's home at +0.22.
  Rhythm auto-pans ±40% around it, which is a new `panDepth`, also applied in offline
  export. Pads stay centred: a single sampler cannot be panned wider than that.
- **Per-song draws in the log.** First built so each new rule's log line carried its draws, for
  example `KOS-LD1-014 Oxygene See-Saw Riff (sixth, 2+2+2, second half, anchor below)`. Dropped
  on 2026-11-02 (Zack: keep the log short), and the recorder that collected them
  (`KosmicSpaceDraws`) was removed on 2026-11-03. Rule lines, regen lines included, carry the
  rule's name only.
- **Titles.** Space draws from the same pattern list, with 80% of the weight on patterns
  1, 2, 7 and 8. Superseded 2026-11-03 (Zack: single words repeat): Space has its own patterns,
  single word 15%, part number 15%, two coined words 12%, French phrase 12%, Jarre templates 12%,
  long-running series 4%, gear jokes 4%, and the earlier numeral, prefix and adjective patterns
  26%. Weights and word lists are in `KosmicTitleGenerator.spaceTitle`.
- **Base Kosmic and Drift instrument picks** are capped at the pool sizes they had before
  Space appended to them, so they never draw a Space instrument.

### Breaks (added 2026-11-02, after the first listen)

Zack's first listen: it reads as Jarre, but 100 bars of unbroken drums, bass and sequencer
are monotonous. `tools/jarre_breaks.py` measured how the corpus itself breaks the repetition:

- **In the Oxygene pieces, drums and bass never stop**: 104 bars in Oxygene 4, 112 in Oxygene 6,
  and likewise in Oxygene 3, 8 and the unnumbered Oxygene. The preset-box pieces (Oxygene 3, 4
  and 6) have no drum fills.
- **The lead comes and goes.** Lead 1 rests for 16–23 bars once or twice a piece (Oxygene 4:
  16; Oxygene 6: 20; Oxygene 8: 18 and 18; Oxygene 4's second transcription: 23). Each rest
  starts and ends on or within 4 bars of a section edge.
- **The sequencer answers the lead, by section.** It is thinner while the lead plays: 3.1–3.3
  against 5.5 notes a bar in Oxygene 6, and 8.9–9.0 against 9.7–9.9 in Oxygene 4.
- **Short sequencer breaks of 4–8 bars** while drums and bass carry on (Oxygene 8: 6, 4, 8;
  Oxygene 4's second transcription: 6, 6), with Lead 2 dropping out alongside.
- **A noise swell marks the returns** (Oxygene 6; three of four in Oxygene 8).
- Drum breaks (Magnetic Fields 1: 4 bars twice, with bass and lead) and regular fills
  (Equinoxe, Magnetic Fields 1) belong to the later albums. They stay in Phase 2.

`KosmicSpaceArrangement`, in `CosmicStructureGenerator.swift`, builds this schedule per song
from the structure and the seed alone, so a regenerated track rebuilds it without storing it:

- **Landing bars.** Every edge falls on a body section's start or a 16-bar point inside a body
  section. Nothing breaks in the first 16 body bars or the last 8 before the outro.
- **Lead 1 rests.** One rest, two in songs over 110 bars, each running from one landing bar to
  another 16–24 bars later. A section start is weighted 3:1 over a 16-bar point. Every body
  section keeps at least 8 bars of lead, so theme and riff are both heard. Lead 2 plays on.
- **Sequencer by section.** The full source pattern plays in the intro, the outro and Lead 1's
  rests. The song's thinner variant (one of the three measured masks) plays wherever Lead 1
  does. This replaces the per-song mask draw.
- **One sequencer break** of 4, 6 or 8 bars (20/60/20), ending on a landing bar at least 4 bars
  clear of any lead rest. Rhythm and Lead 2 are silent; drums and bass carry on. A simulation
  over the range of Space song shapes found a place for it in 94 of 100 songs. The rest are long
  abab and abba songs whose two lead rests leave no room.
- **A swell on every return.** KOS-TEXT-005 adds a swell on each bar where Lead 1 or the
  sequencer returns, whatever its 70% draw and 8-bar spacing would say. The wash variant adds
  one too, where its B-section swells do not already cover it.
- **Drum fills, Zudio's addition** (Zack, 2026-11-02, "like Motorik Europe"). They go in the bar
  before the sequencer returns, the bar before each lead return, and the bar before the
  sequencer break, in that order of priority, at most three a song. Each is a falling tom roll
  over the last 1 beat (80%) or 2 beats (20%); the kick and the clap stay. They play only with
  KOS-DRUM-009, not when the song draws no percussion.
- **The log** carries no `Breaks` line and no per-song draws in parentheses (Zack, 2026-11-02:
  keep it short). During playback a coordinated break is called out at its bar, naming only
  the parts actually playing either side of it, e.g. `Bar 071  Sequencer and Lead 2 drop out`
  and `Bar 077  Sequencer and Lead 2 return`. A Lead 1 rest on its own gets no live line,
  since leads come and go in every style (Zack, 2026-11-02).

- **Drum variety and the handclap** (Zack, 2026-11-02, from the song Spectrion). The 808 box was
  relentless, and the handclap on beats 2 and 4 read as disco. `KosmicSpaceArrangement` holds
  `drumThins`, `bassThins` and `clapRanges`, drawn on their own stream so the break schedule is
  unchanged.
  - Variant 0 (60%) drops the 16th hats. Variant 1 (40%) goes to quarter hats, kick on steps 0 and
    10, no open hat.
  - The clap plays in about 10% of songs, in one or two whole body sections, and not in a thin
    stretch. Otherwise the song's step 12 accent is the only backbeat.
- **Coordinated thinning of drums and bass** (Zack, 2026-11-02, from Kroneon II and Sub-Nexione,
  where only 8 bars in 124 had thinned and the bass never did). Candidate points are each body
  section start after the first and every 16 bars after it, never into the last 8 before the
  outro. Each has a 50% chance of a stretch of 8, 12 or 16 bars (40/20/40), with 8 full bars
  between stretches and none over the sequencer break. A song over 100 bars gets at least two, a
  shorter one at least one.
  - In 60% of drum stretches the bass thins over exactly the same bars, so both go back to the
    full pattern together under the closing fill. In the rest the bass plays on.
  - One more stretch of 8 or 12 bars, in 50% of songs, thins the bass alone, apart from any drum
    stretch.
  - A thin bass bar (KOS-BASS-018 only) keeps the walk's notes on steps 0, 6 and 12 with their own
    pitches, held 6, 6 and 4 steps. The short notes drop out (3 of 6, or 3 of 7 in the alternate rhythm). The Berlin School drone (KOS-BASS-001) is already sparse, so it drops out
    completely over every bass stretch and returns under the closing fill (Zack, 2026-11-03). The
    first drum stretch always takes the bass, so every drone song has one full drop.
  - The edges of a bass stretch are annotated with the existing `Bass pattern evolving` line,
    through `bassEvolutionBars`. That also replaces the fingerprint detector's chord-change
    lines for Falling Walk songs. Drum stretches get `Drums simplify` at their first bar and `Drums return` at the bar after their last (Zack's wording), for preset-box songs only.
- **Theme variation and thin-stretch fills** (Zack, 2026-11-02). KOS-LD1-013 draws a note count
  (5 at 50%, 4 at 25%, 6 at 25%) and a rhythm per song. The 5-note source onsets (0, 6, 8, 10, 14)
  are 35% of that draw, and are never used with the source top note and the 5-3-5 inner line
  together, so statements 1 and 2 are never the original figure. The 4-note form drops the inner
  third. The 6-note form adds a passing step above the first inner note, and is only used when
  there is room for it. Each simpler drum stretch ends on a 1- or 2-beat fill into the fuller beat,
  in addition to the three break fills.
- **Machine Kit bloops and Square Lead 2** (Zack, 2026-11-03). Space draws Machine Kit for 25% of
  songs (808 Kit 75%), and plays its own synth toms, so the tom-roll fills bloop. The engine's
  tom-to-snare remap, written for Noir, now skips Space. No second drum voice. Square Lead 2 on Lead 2
  has gain 0.60 and always takes tremolo; Space Lead 2's chips are tremolo, delay and space.
- **Base JMJ rules in the Space mix** (Zack, 2026-11-03, "a bit more variety before Phase 2"). The
  plan had excluded them as matching no source; Zack overruled that.
  - Drums: KOS-DRUM-001 JMJ Mini Pops joins the pool (current weights below). Simpler-stretch and
    fill annotations apply to the preset box only.
  - Lead 1: in 50% of songs KOS-LEAD-006 JMJ Phrase Loop plays the B sections in place of the riff.
    The theme is unchanged; it is drawn after the theme and riff.
  - Rhythm: KOS-RTHM-002 JMJ Hook and KOS-RTHM-005 JMJ Dual-Rate join the pool. Chosen as the
    two closest to a sequencer (8th-note grids that follow the chords). They play an octave down, under
    Lead 1, and rest through the sequencer break. They do not thin under the lead. RTHM-003 and 008 are
    slow solo lines and stay out.

### More Oxygene rules (added 2026-11-03)

Zack found the songs very Jarre but too alike: one rule per track. The other Oxygene files were
re-read part by part (Oxygene 3, 6, 8, the second Oxygene 4 transcription and the unnumbered
Oxygene). Sixteen candidates came out; the first batch below is one per track, the most distinct
of each. Zack's rulings: parts are drawn independently, for the happy accidents, with only a few
exclusions between two busy parts; each new rule is as likely as the other Space rules in its track.

- **KOS-LD1-016 "Oxygene 6 Rising Strings"** (A sections). Oxygene 6 strings, bars 34–53 and
  again 76–95. Three long notes a bar on steps 0, 6 and 12, each bar a 3-note cell on the current
  chord. A climb is up, neighbour, up, up, each cell starting on a chord tone near where the last
  ended, so the line rises about an octave; a fall is four falling cells from the top. Source cycle,
  16 bars: climb, climb, fall, a held note, three bars of rest. Register 58–84. Draws: a chromatic
  approach into each climb (60%), rhythm 0, 6, 10 (40%), and an 8-bar climb-and-fall cycle (40%).
- **KOS-BASS-020 "Oxygene 8 Pump"**. Oxygene 8 synth bass, 124 bars. `x.x.xx.xx.x.xx.x`: the upper
  root on steps 0, 2, 5, 8, 10 and 13; the low root with the b7 above it on 4, 7, 12 and 15. Upper
  root in 36–47. Draw: bare octaves, no b7 (30%). A thin bar keeps the upper root only.
  Variation (Zack, 2026-11-03: too relentless), as the source varies over its 124 bars, the rhythm
  fixed except in the turn:
  - Fifth voicing (22 source bars, always the iv chord's 2 bars in every 8): upper hits become the 5th
    and octave, low hits root and 4th. Here on each 8-bar chord loop's turnaround, the non-tonic window
    that hands back to the tonic: the Aeolian Cycle's iv, the Dorian Vamp's last window (when not i),
    every second v of the Two-Chord Sway.
  - Breath (10 bars): the low hit on step 15 drops, in the second bar of each 8.
  - Turn (2 bars): `x.x.xx.xx.x.x.xx`, with the 7th and upper root together on step 15, the 7th
    raised to the leading tone on the tonic chord. Here the last bar before a new body section.
  - Late entry (2 bars): the bar starts on step 2. Here the first bar of each body section after the
    first.
  The B-section voicing swap that was also offered is not in the corpus and was left out.
- **KOS-RTHM-021 "Oxygene 8 Offbeat Pedal"**. Oxygene 8 reverse-cylinder part, bars 51–65. Offbeat
  8ths alternating a low pedal with upper chord tones: steps 2–12 pedal, octave, pedal, 7th, octave,
  5th; then a short bar on 6–12, pedal, 5th, 7th, octave. Root in 48–59. Rests through the sequencer
  break. Draw: the upper line a step lower (6th, 5th, 4th), as bar 64 has it (30%).
- **KOS-PADS-010 "Oxygene 4 Staggered Bloom"**. Oxygene 4 bowed glass, bars 35–118. A close triad
  whose notes enter on steps 0, 4 and 8 and release together after 2 bars; the lowest note is the
  first chord tone at or above MIDI 55. Draw: the bloom opens from the top down (30%).
- **KOS-DRUM-012 "Oxygene 6 Hand Percussion"**. Oxygene 6, 105 identical bars, no kick, snare or
  hats: low bongo 0, 8; mute conga 4; open conga 6; low conga 12, 14; maracas 0, 6; guiro 0, 6, 8;
  shaker 2, 3, 4, 10, 12, 14; castanets 12, 13, 14 (in 60% of songs). Shaker step 3 drops every
  eighth bar.
  The guiro took over when it played every bar (Zack, 2026-11-03), so it plays only in two or three
  stretches a song, 8 or 16 bars each, on a body section start or 16-bar point, at least 8 bars apart,
  at velocity 50 and 40.

**Levels and names (Zack, 2026-11-03):** Space Lead 1 Synth Brass 1 (62) at 0.65; Space Rhythm Moog
(39) at 0.45 and Harpsi Pad (11088) at 0.50, base Kosmic keeping 0.65 and 0.75. The White Noise Wave
preset shows as "White Noise" in the Texture picker, so it is not abbreviated.

**Theme return (Zack, 2026-11-03, from Aztraeon):** a song that ends on a B section (ab, abab) never
hears its A theme again; aba and abba return on their own. So 8 bars two thirds into the last B section
(at an 8-bar point, at least 8 bars in) replay the first A section's opening 8 bars in place of the B
rule. Those 8 bars also take the first A section's opening chords (`SpaceThemeReturn`, shared by
the chord plan and Lead 1). No draws; a lead rest over the window still silences it.

**B-section chords and the riff (Zack, 2026-11-03, from Fluxion III):** a Two-Chord Sway song played
i–v for all 132 bars, and the riff ran 40 bars without a break up to E6. B sections now loop their own
8-bar cycle (`spaceBCycle`), leaving the tonic and coming home at the end: Dorian Vamp bIII ×2, IV ×2,
i ×4; Aeolian Cycle bVI ×2, bIII ×2, bVII ×2, i ×2; Two-Chord Sway i ×2, iv ×2 (iv major in Dorian).
B passes still draw the A cycle, so A-section chords are unchanged for a seed. KOS-LD1-014 folds its
top note into 73–84 (it was the pair's midpoint in 72–84) and rests in the last 2 bars of every 8 of
its section, after the last-B thinning draw so Lead 1's later draws are unchanged. The Lead Synth
doubling of Lead 1 stays, as in all Kosmic.

**Tuning after listening (Zack, 2026-11-03):** the first drum stretch always thins the bass too. KOS-BASS-018 gains a breath bar and a turn bar, deterministic and lighter than the Pump's. KOS-DRUM-001 Mini Pops drops out in the first two drum stretches and returns on a 1 or 2 beat tom roll (Space only). KOS-DRUM-012 thins over every bass or drum stretch (bongo, low conga, quiet shaker), keeps the guiro out of them, plays the guiro at velocity 38 and 30, and is drawn 13% of the time. Trims: Square Lead 2 0.48, Saw Lead 0.36, Moog rhythm 0.38, Synth Brass 2 0.16. The `Space Oxygene, ...` log line was dropped as redundant.

**Fills and bloops (Zack, 2026-11-03, from Eternal-Cosmos):** both Space kits' toms are synth bloops
(808 Kit pitched sines, Machine Kit an electric tom), so the preset box's high-tom accent put one in
every bar. The accent draw is now side stick, claves or tambourine. Every Space fill, in the preset
box and on Mini Pops returns, draws snare roll 45%, tom roll 30% or claves figure 25% (steps 0, 3, 6
and an open hat into the downbeat), never the same as the song's previous fill. The claves figure
became a kick and snare fill on 2026-11-03 (see "Open questions"). The figure was first on
cowbell, which sounded off genre in every kit (Zack, 2026-11-03, Chronique); no Space rule plays the
cowbell now. Square Lead 2 on Space Lead 2 is now 0.28. Half the preset-box
fills land on a crash on the next downbeat; Mini Pops is too sparse for one. Lead 2 trims: Square
Lead 2 0.38, Saw Lead 0.28. Bright Saw Stack shows as Bright Saw. The on-screen Instruments line
names instruments; the saved file keeps program numbers.

- **KOS-LD1-017 "Oxygene 8 Offbeat Climb"** (A sections, added 2026-11-03). Oxygene 8 lead (alto sax,
  piano and clarinet in unison), bars 17–49 and 67–138, read bar by bar. Statements fill one bar and
  the next is silent, entering off the beat on step 2: climb (5th below, root, 2nd, 3rd, 4th, 4th on
  steps 2, 4, 6, 8, 11, 14), leap (5th, root, 5th, 6th, 7th on 2, 6, 8, 11, 14) and turn (the climb's
  first four, then root and 2nd), each from the current chord root in MIDI 62–73. A 16-bar phrase per
  A section: pickup root, climb, leap, turn, pickup, climb, leap, and a falling answer from the key's
  6th to the 5th below. Every third phrase, as bars 41–49: pickup, climb, a 2-bar arch three times
  (key 3rd-4th-5th across the bar line, falling to the tonic), then 7 bars of rest. Draws: opening leap
  from the 5th below 40% (source), 6th below 30%, 4th below 30%; the climb's top repeated 40% (source),
  on to the 5th 30%, back to the 3rd 30%; rhythm source 60% or 2, 4, 6, 8, 10, 13 40%, never the
  source rhythm with both source pitch draws. Drawn last in Lead 1 at one in three, so the three
  A-section rules share evenly and earlier draws are unchanged for a seed.
  Smoothed after the first listen (Zack, 2026-11-03, Aztraeon: clunky, not fluid). Every note is
  held to the next, a statement's last note rings 10 steps into the silent bar and the pickup holds
  into the entry. The leap statement steps down to the 4th, not the root. The phrase starts 2 bars
  into the section, so each statement lands in the second bar of its chord window as in the source.
  Register: tonic in 62–73, each chord root the nearest to it from a fourth below to a fifth above;
  a statement over 84 drops an octave whole. The harmonic filter had lifted single short statements
  above the pads (Aztraeon bar 36 an octave up, the arch at bars 38–39 not); legato joins each half
  phrase into one figure, which reaches above 67 and so is never lifted.

**Bridges (Zack, 2026-11-03).** The earlier "no bridges" ruling is superseded for Space's own
bridge; base Kosmic's bridge sections stay off. `tools/jarre_deep.py --sections` found four ways Jarre
breaks a piece in the middle, all subtractive: Magnetic Fields 1 bars 73–84 and 137–148 (sequencer
and lead out, drums at a third of their density, bass, pads and noise on a new cycle), Rendez-Vous 2
bars 81–96 (the sequencer alone), Arpegiator bars 41–56 (drums and sequencer only), and the
effects-only endings of Oxygene 3 and 6. Zack chose the first two:

- **Where.** ab and aba forms only, `spaceBridgeShare` of them: 0.30 (about 1 Space song in 6,
  since ab and aba are 55% of Space forms). The bridge
  takes the last 8 or 12 bars of the first A section and ends where the first B begins, leaving A at
  least 16 bars. It is a mute schedule (`SpaceBridge`, in `CosmicStructureGenerator.swift`), not a
  section, so the A and B rules, the chord cycle draws and every track's rule draws are unchanged. It
  has its own stream on the song seed, so the chord plan, the arrangement, the auto sweep and
  per-track regen all rebuild it without storing it. The main-stream bridge roll is still discarded.
- **Magnetic Fields Breakdown**, half the bridges, 8 or 12 bars. Sequencer, Lead 1 and Lead 2 out.
  The preset box drops to the kick alone on beats 1 and 3, as Magnetic Fields 1 does for bars 72–79;
  a 12-bar breakdown rebuilds with 8th-note hats over its last 4 bars, as bars 80–87 do. (It first
  reused the thin stretches' quarter-hat beat, which made it sound like one; changed 2026-11-03.)
  Hand Percussion plays its sparse core, Mini Pops plays on.
  The bass holds the chord root an octave down, re-attacked every 2 bars. Pads carry 4-bar chords the
  song's loops do not lean on, the last leading into B's first chord: Dorian Vamp v, bVII (12 bars:
  bVII, v, bVII); Aeolian Cycle v, bIII (12: iv, v, bIII); Two-Chord Sway in Aeolian bVI, bVII
  (12: bIII, bVI, bVII), in Dorian bIII, bVII (12: bIII, IV, bVII). Swells into it and out of it.
- **Rendez-Vous Sequencer Solo**, the other half, 8 bars. The sequencer alone, playing its full
  source pattern, with the pads in half of these songs; everything else silent. Two automatic filter
  sweeps (`KosmicAutoSweep`, otherwise off in Space) reopen on its fifth bar and on the return. The
  band comes back on a 2-beat fill and a crash (preset box; Mini Pops on its own dropout fill), with
  the surf swell landing on B. Whatever the song's Rhythm rule, the solo's 8 bars play KOS-RTHM-016's
  full source pattern, root and octave in 48–59 (Zack, 2026-11-03, La Nuit Hypnotique: under Dual-Rate
  the solo was 2–4 notes a bar). It is logged as `Sequencer solo 8 bar`, since "Rendez-Vous solo"
  read as a lead solo.
- **Edges** (Zack, 2026-11-03: the swell alone did not mark them). No draws, so nothing else moves.
  In: a crash on the bridge's first downbeat for every drum rule, and in the solo the bass holds one
  root an octave down for 2 bars before it drops out. Out: a two-note bass pickup on steps 12 and 14
  of the last bar, walking up by scale step to the bass's first note in B, under a 2-beat drum fill,
  then a crash on B. Preset box: its own fill, as before. Mini Pops: its dropout fill out of the solo,
  a snare roll out of the breakdown. Hand Percussion: a falling bongo and conga roll (60, 61, 63, 62,
  64). No percussion: the pickup alone. The fill length and the fill and pickup steps live on
  `SpaceBridge` (`returnFillBeats`, `returnFillStep`, `pickupStep`), which every drum rule and the
  bass read.
- **Around it.** A song with a bridge has no sequencer break. Lead 1 rests and drum and bass thin
  stretches stay 16 bars clear of it, and the song needs only one thin stretch, not two. At most
  three breaks a song, the bridge counting as one: a bridge and at most two thin stretches, or at
  most three thin stretches without one (Zack, 2026-11-03: three thinnings and a bridge is too many,
  and they sounded alike). The bass-only stretch, drawn last, is the first to go. Its return fill
  takes the first of the three fill slots.
- **Measured** over 200 Space ab and aba songs (a temporary test reading `KosmicSpaceArrangement`).
  Before these limits, bridge songs had 2 thin stretches in 110 of 160 and 3 or 4 in 26. Now the
  160 bridge songs have none in 9, one in 70 and two in 81; the 40 without a bridge have two in 20
  and three in 19. Drops of any kind cover about 23% of body bars on average, from 27%. The
  sequencer break, in songs without a bridge, is not counted as a break here. Lead 1 rests often fall
  on the same bars as a thin stretch, since both pick the same landing bars. The log
  adds "+ bridge" to the Form line and calls it out at its first bar under the Bridge tag, as Drift
  does: `Magnetic breakdown 8 bar` or `Sequencer solo 8 bar` (Zack, 2026-11-03).
- **Fill lines in the log.** The Kosmic call never passed the drum rules to the annotation builder, so
  the Space fill names and the dropout guard never ran. Space songs now pass them; base Kosmic and
  Drift still do not, so their logs are unchanged. A Space fill is read from the voices only fills
  play (snare, toms, claves; the high bongo for Hand Percussion), which also stops kick-only
  breakdown bars being logged as fills. It is read from the drum track (`spaceFillLines`), not the
  structural fill candidates, so thin-stretch and break fills appear. A drum or Lead 2 regen rebuilds
  its Space lines (`appendSpaceDrumLines`, `appendSpaceBreakLines`).
- **Regen fixes, all Kosmic** (2026-11-03, from a code review). A Lead 1 regen rebuilds the Lead Synth
  doubling, and Kosmic lead regen runs `HarmonicFilter.filterLead` as generation does. Space bass regen
  reads `spaceBusyRhythm` from the log up to the first regen line only, so reload matches. Mini Pops'
  fill out of the solo is always 2 beats. Drift's bridge processing now
  also runs on a Drift track regen (`applyDriftBridges`, 2026-11-03).

**Weights now:**

- Lead 1, A sections: KOS-LD1-013, KOS-LD1-016 and KOS-LD1-017, a third each. B sections: KOS-LD1-014 50%, KOS-LEAD-006 50%.
- Rhythm: KOS-RTHM-016, 002, 005 and 021, 25% each.
- Bass: KOS-BASS-018 and 020, 37.5% each, KOS-BASS-001 25%. The Pump is never drawn under
  KOS-RTHM-005 Dual-Rate or KOS-RTHM-016 Octave Sequencer (`spaceBusyRhythms`); the walk takes
  its share, so the Pump plays in about 15% of Space songs.
- Pads: KOS-PADS-001 and 010, 50% each.
- Drums: KOS-DRUM-009 38%, 001 34%, 012 13%, none 15%.

**Still on the list** (not built): KOS-LD1-018 Oxygene 4
Triplet Turn (sitar), an Oxygene 6 blues solo for the last section, KOS-BASS-021 Oxygene 3 Shadow
Bass, KOS-BASS-022 Anticipated Octaves with the Oxygene 6 paired-8th descent, KOS-RTHM-020
Oxygene 8 Phasing Cell, an Oxygene 6 paired-descent rhythm, KOS-PADS-011 Oxygene 6 Close Chords,
KOS-PADS-009 brought forward from Phase 3, KOS-DRUM-013 Oxygene 8 Four Pulse, KOS-DRUM-014 Oxygene
Half-Time. The regen log no longer appends draws in parentheses either.

Not yet done:

- `KosmicSpaceTests`, and the `DeterminismTests` fingerprint at the release split.
- Existing tests that read the old 30% Drift share or base-Kosmic fingerprints will
  disagree under the testing split. These include `KosmicDriftCompareTests`, possibly
  `KosmicAutoSweepTests`, and the Kosmic `DeterminismTests` seeds. This is expected until
  the release split is restored.

## Phase 2 as built

### Harmony (2026-11-06)

The four Magnetic harmony families are in the single Space pool with the three Oxygene families.
Each Magnetic family has the weight of an average Oxygene family (about 14.3% each); the Oxygene
three keep their 55 / 30 / 15 shape and come to 23.6, 12.8 and 6.4%. Magnetic harmony therefore
opens about 57% of Space songs. Counted over 1,203 Space songs, the shares matched. The new
KosmicProgressionFamily cases are appended: magneticArc, magneticTurn, equinoxePhrygian and
magneticDescent, with log labels "Magnetic Fields Arc i bVI iv V", "Magnetic Fields Turn i V bVI
bVII", "Equinoxe Phrygian i iv bII" and "Magnetic Fields Descent I vi V IV".

**Modes.** The family sets the mode. Arc and Turn are Aeolian, with the V chord major; the
leading tone belongs to that chord alone, as Jarre plays harmonic minor only over the V, and the
Turn's bVII stays in the scale. Equinoxe Phrygian is Phrygian. Descent is Ionian, and its intro
and outro tonic is a major chord. The HarmonicMinor mode is not used.

**Tempo.** One Space range, 96–128, triangular, peak 118.

**Cycle data.** spaceCycle, spaceBCycle and spaceBridgeChords in KosmicStructureGenerator each
carry the four families, with the same even-bar rule and 2- and 4-bar windows. The Arc and the
Phrygian's tonic pedal are 4-bar windows. Breakdown chords for the bridge: Arc iv ×4, bVII ×4
(12 bars: bVI, iv, bVII); Turn bIII ×4, i ×4 (12 bars: bIII, bVII, i); Phrygian iv ×4, bvii ×4
(12 bars: bIII, iv, bvii); Descent ii ×4, vi ×4 (12 bars: IV, ii, vi).

### Notes stay in the scale

Every Space rule already snaps its notes to the song's scale (snapToScale, snapMidiToScale and
scaleStep in CosmicHelpers.swift). A chord that carries a note outside the scale needed two more
steps, both in CosmicHelpers.swift:

- **The chord's own scale.** spaceChordScale swaps into the song's scale each chord tone that is
  outside it, in place of the scale note a semitone below (above, when that one is itself a chord
  tone). E major over A Aeolian reads as A harmonic minor. spaceWindow builds each Space chord
  window's tensions and avoid tones on that scale, so the leading tone is a chord tone, and
  HarmonicFilter's clash guard keeps the major third and removes the natural seventh. An
  Oxygene chord is always inside the scale, so for those songs nothing changes.
- **One fit pass.** fitSpaceChordScale runs once per pitched track after generation, and after a
  single-track regen, in SongGenerator. It moves only the notes the chord under them has swapped
  out, and leaves every other note alone, so a note the rule already snapped is never adjusted
  twice. Drums are skipped. Before the Magnetic families existed it left the determinism
  fingerprint identical.

Measured over 1,500 seeds, no Arc or Turn song held the natural seventh over a V chord, and the
leading tone sounded there.

### Rules (2026-11-06)

Five Magnetic rules, each in its track's single Space pool. A rule joining a pool of unequal
weights takes the average weight of the rules already there, and they keep their shape.

- **KOS-DRUM-010 Magnetic Fields Rhythm Box** — 20% of Space songs, with Preset Box 30.4, Mini Pops
  27.2, Hand Percussion 10.4 and no percussion 12. The paired kick x..xx..xx..xx..x, rotated by 3
  or 6 steps (35% each) or the source (30%), under a ride or closed hat (50/50) on every 16th.
  Snare off, or on Magnetic Fields 2's steps 2, 3, 6, 10, 11 and 14 (50/50), on the electric snare
  (40), which no Space fill uses, so the fill log never mistakes the pattern for a fill. An agogo on
  the quarters in 30% of songs. B sections add an open hat on the last 8th of every second bar.
  Jarre plays no fills here, but the box takes short 1-beat Space fills at every body section
  change and on both sides of its simpler stretches, as well as the arrangement's break fills; the
  bridge return fill stays 2 beats. The fill code is shared with the Preset Box
  (addSpaceBoxFills). Simpler stretches and the breakdown work as the Preset Box's.
- **KOS-BASS-019 Magnetic Fields Octave Pump** — 35% of the bass pool wherever a pump may play
  (Falling Walk and Oxygene 8 Pump 24 each, Berlin School drone 17), but never under a busy
  sequencer, so it plays in 12.0% of Space songs (144 of 1,203; raised from 25% and about 7% to reach
  Zack's 10–15%). Three figures per song: octave eighths 40% (30% of those on 16ths), octave pops
  35%, neighbour pedal 25%, as designed above; root in MIDI 31–42. It varies as the Oxygene 8
  Pump does: thin bars keep held quarter notes, the fifth on the loop's turnaround, a breath in
  the second bar of each 8, a root–3rd–5th–octave turn before each new body section and a late
  entry into each one after the first. The eighths also switch density over the last 8 bars of a
  section of 16 or more.
- **KOS-RTHM-017 Equinoxe Fifth Triplets** and **KOS-RTHM-018 Magnetic Fields Leading-Tone Cell**
  — sequencer-engine presets, each a sixth of the Rhythm pool with the four earlier rules. They
  play as the Octave Sequencer does: the full figure in the intro, the outro, Lead 1's rests and
  the sequencer solo, a thinner one under Lead 1, silent through the sequencer break (the shared
  helper spaceSequencer). 017 draws its upper note, fifth 40% (source), fourth or octave 30% each,
  and one of three thinner variants. 018 draws a rotation of 0 (30%), 4 or 8 steps (35% each), the
  octave or the fifth (70/30) and one of three thinner variants; its neighbour is a semitone below
  the root where the scale has one. The engine's slots gained a fourth. Both count as busy
  (about 12 notes a bar), so neither pump plays under them.
- **KOS-LD1-015 Magnetic Fields Turn Melody** — the fourth A-section rule, a quarter of songs, with
  the Falling Theme, Rising Strings and Offbeat Climb. A statement of 3 to 5 half-bar 16th runs on
  steps 2–7 and 10–15 from the start of each 4-bar block, each run a scale step lower, the rest of
  the block silent; every fourth statement climbs instead. Each run starts from the current chord.
  Per-song draws, so the melody differs from song to song and not only in key or tempo: the turn
  shape (five, the source's two at 15% each), the run count, the start on root, 3rd or 5th, and 6-
  or 5-note runs. Legato, each note held to the next. Measured range MIDI 57–84.

Measured over 600 seeds (479 Space songs): 304 Space songs held at least one Magnetic rule. Notes
a bar: Rhythm Box 24.9 drum hits, Fifth Triplets 11.9, Leading-Tone Cell 11.3, Octave Pump 8.6.
Every pitched note stayed in its chord's scale but for the Oxygene 8 Pump's deliberate raised
leading tone in its turn bar.

### Space levels and bridge share (2026-11-06)

spaceBridgeShare is 0.30, its release value: a bridge in about 30% of Space songs in ab and aba
form, 1 Space song in 6. Moog on Bass is 8 CC7 steps lower and Bright Saw on Lead 1 is 10 higher,
in Space songs only (spaceCC7Trim in AppState.swift); base Kosmic and Drift keep the shared
values.

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
- tempo stays within 96–128

**Listening batch** — 20 Space songs. Listen for:

- whether the sequencer and chord cycle read as Jarre within the first 16 bars
- whether the theme and riff alternation is audible
- whether `KOS-PADS-001` on strings sounds like a string machine, or the bank needs a sample
- the Space share for release (testing runs 80%; the intended release share is 25%)

---

## Open questions

- **Busyness (Zack, 2026-11-03), settled.** Measured over the first 100 Space songs (a temporary
  test, since removed): runs of over 32 bars with Lead 1 sounding, Rhythm at 4 or more notes a bar
  and Bass at 4 or more are rare. None if every bar must be dense, 2 to 6 songs if gaps of up to 2
  bars are bridged; the arrangement's rests and stretches break the band within 32 bars in 95 of 100
  songs. What differed was notes a bar: Rhythm 016 about 9 to 10, 005 6, 021 5, 002 4; Bass 020 Pump
  12 (its thin bars keep 6), 018 5 to 6, 001 under 1. The Octave Sequencer with the Pump, about 22
  notes a bar under the lead, was the busiest pair by far, so the Pump is no longer drawn under
  KOS-RTHM-016 (Zack chose this alone, not the 32-bar guard, which would have changed about 2 songs
  in 100).
- **ArrangementFilter in Space, settled.** Lead 1, Lead 2 and Pads exempt, as Rhythm already was
  (Zack, 2026-11-03). Measured before: it never fired on them, so no song changed.
- **Ruled and built 2026-11-03.** The Berlin School drone (KOS-BASS-001) drops out in Space's bass
  thin stretches and returns under the closing fill. The Space gain trims for programs 63, 81 and
  12080 stay on for all Kosmic. A Drift track regen repeats Drift's bridge processing
  (`applyDriftBridges`), for Lead 1, Pads, Rhythm, Bass and Drums (Pads too: the bridges soften,
  transpose or fade them).
- **Fills (Zack, 2026-11-03, Le Grand Orthodoxx).** The claves figure read as an acoustic knock
  against an electronic kit, and its closing open hat could not be heard, so it gave no lift. It is
  now a kick and snare fill: in 1 beat a kick then three 16th snares, in 2 beats snares with a kick
  on beat 4, rising into the downbeat, and the preset box always lands it on a crash. Same weight
  and draw. The claves accent on step 12 is unchanged.

- **Bridges in Space** — built 2026-11-03 (see "Bridges" under "Phase 1 as built"); the release
  share is 0.30. Still open: whether the Phase 2 breakdown becomes the in-section form of the
  Magnetic Fields Breakdown rather than a second build. Not built and kept in reserve: a Pedal Rise
  (one non-tonic chord held 8 bars, drums out, a long swell into the return) and an effects-only
  interlude (pads and a held Texture effect).

- **Two unidentified files.** The Equinoxe file has no part number, and the unnumbered
  Oxygene (105 BPM, fretless bass, choir, no lead) is probably from Oxygene 7–13. If either is
  recognised by ear, the rule names that cite them can be made exact.
- **Chronologie 2's tempo.** It is transcribed at 162 against 119–120 for the other
  Chronologie parts. It sets no number in this plan.
- **Phase 2 choir.** Whether a per-section program change on Texture is cheap enough, or the
  choir is dropped.
- **Phase 3 at all.** Decided after listening to Phases 1 and 2.
