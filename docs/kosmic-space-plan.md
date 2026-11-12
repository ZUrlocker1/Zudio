# Kosmic Space — Design Document

Status (2026-11-09): **built on `main` as version 2.9; testing finished, release split set (Drift 25 / Space 35 / base 40).** Phase 1
(Oxygene), Phase 2 (Magnetic) and the first Phase 3 piece (Chronologie Pop Loop and Anticipated
Strings) are in. Builds on macOS and iOS. The Magnetic rules and the last two additions sound good
on first listens. Testing is finished. Unbuilt rule ideas are marked closed (not needed) under "On hold and closed" at the end; other unbuilt items are on hold.

This is the single document for Kosmic Space and says where the design stands. How it got here is
in git history and `docs/change-log.md`. Work happens on `main`; Zack is the only user of the repo.

---

## Contents

- What Kosmic Space is
- Evidence base
- Design principles
- Harmony
- Structure and arrangement
- Rules by track
- Reused and excluded rules
- Instruments, effects, titles and log
- Rule ledger
- Release checklist
- On hold and closed

---

## What Kosmic Space is

The Jean-Michel Jarre substyle of Kosmic, alongside Kosmic Drift. Base Kosmic blends Jarre with
Tangerine Dream, Vangelis, Eno, Craven Faults and Electric Buddha Band. Space concentrates on
Jarre alone, the same subtraction Motorik Arcade made. `isKosmicSpace` on SongState;
`displayStyleName` returns "Kosmic Space".

**What makes it Jarre**, in order of contribution:

1. A **sequencer** of one or two pitch classes in a gapped 16th-note rhythm, locked to the bar and
   moving with every chord
2. **Fast chord cycles** underneath it, 2–4 bars per chord in loops of 4–8 bars
3. A **bass** with its own fixed figure, walking chord tones (Oxygene) or pumping octaves (later)
4. A **preset rhythm box**, mechanical and unvarying
5. A **theme and a riff** that take turns by section
6. **String-machine pads**
7. **Noise sweeps** landing on section boundaries

**Three eras of source, one pool.** Oxygene (1976), Magnetic (Equinoxe 1978, Magnetic Fields 1981)
and Chronologie (1993, Oxygene 7–13). There is no per-song flavour: every track draws its rule
independently from a pool holding the rules of every era, so a song can pair Magnetic Fields
harmony with an Oxygene sequencer. The generation log names each rule by its album.

**Share of Kosmic.** One roll shared with Drift. The final split (Zack, 2026-11-09) is Drift 25 / Space 35 / base 40, kept as named constants (`driftShare`, `spaceShare`; base takes the remainder). Testing is finished and Space is a favourite, so it stays in high rotation. Drift's threshold moved from 0.30 to 0.25 earlier, so some existing Drift seeds generate differently. Lowering Space from 0.50 to 0.35 moves seeds that roll between 0.60 and 0.75 from Space to base Kosmic.

---

## Evidence base

**The corpus.** Sixteen fan transcriptions in `~/Downloads/jarre-midi`, outside the repo because
they are transcriptions of copyrighted works: Oxygene Parts 3, 4 (two transcriptions) and 6;
Equinoxe (one file, part not given); Magnetic Fields Parts 1, 2, 4 and 5 (2 and 4 corrected from
double time); Zoolook Arpegiator; Rendez-Vous Part 2; Chronologie Parts 2, 4 and 5; Oxygene 7–13
Part 8 and an unnumbered Oxygene.

**Tools** in `tools/`: `fetch_jarre_midi.py` (downloads the corpus outside the repo, needs the
sandbox bypassed), `jarre_survey.py`, `jarre_deep.py` (role-aware passes, with a hand-made `ROLES`
map), `jarre_breaks.py`, and the superseded `jarre_analyze.py`. Fan transcriptions are hard
quantised with flat velocity, so **velocity is out of scope**: rules use Kosmic's existing velocity
conventions.

**What the corpus establishes:**

- Chords change every 1–4 bars (median 2) in loops of 4–8 bars; long single chords occur only as
  pedal sections at intros and builds.
- Sequencers are small and locked to the bar, transposing with each chord: one or two pitch
  classes in a gapped 16th rhythm.
- Figures grouped in threes against 4/4 appear in every era (the Equinoxe sequencer, the Oxygene 8
  bass, the Magnetic Fields kick `x..xx..xx..xx..x`, Oxygene 6's dotted quarters).
- Theme and riff alternate by section (Oxygene 4). Leads are see-saws, broken triads or turns, and
  come and go: Lead 1 plays in 17–93% of bars.
- Tempo 91–136, median about 120. Pads are string machines in 13 of 15 pieces.
- Sweeps start just before 8-bar boundaries.
- In the Oxygene pieces drums and bass never stop; the lead rests 16–23 bars once or twice, the
  sequencer is thinner while the lead plays, and short 4–8 bar sequencer breaks occur. Magnetic
  Fields 1 has two 12-bar mid-piece breakdowns (sequencer and lead out, drums thinned, new cycle).

---

## Design principles

**Homage, not copy.** Every rule is a statistical constraint measured from a named work; no rule
encodes a melody. Signature rules transform the source in two layers:

- **Per-song draws.** Interval, grouping, rotation and register come from a measured family. Where
  the source's own value is one option it is weighted below the alternatives, so no song reproduces
  the original exactly.
- **Within-song development.** A figure is stated twice exactly, then varies or transposes with the
  chord; every fourth statement returns to the plain form.

**Rules vary.** Every Lead 1 rule varies per song and evolves within it. Magnetic drums keep subtle
fills. Magnetic bass varies over time.

**Named for the work.** Each rule's name cites its album or piece. IDs continue the track's
numbering; retired IDs are never recycled.

**One pool per track, drawn independently.** Every new Space rule gets the same weight as the other
rules on its track. Exclusions exist only between two busy parts (the bass pumps are never drawn
under a busy sequencer). `SeededRNG.weightedPick` does not normalise: weights must sum to 1.

**Determinism.** Space must not change what an existing base-Kosmic or Drift seed generates. New
Space draws come last or from streams derived from the song seed (`KosmicSpaceStream`); a base step
Space skips still consumes its RNG slot.

**Keep the structure.** Space uses Kosmic's song structure (intro, A and B sections, outro; forms
ab, aba, abab, abba). Breaks are mute schedules, not new section types.

**Harmony is the one place we do not economise.** Kosmic's chord builder cannot play a repeating
cycle, so Space has its own chord-cycle builder and every family is data.

---

## Harmony

**Chord-cycle builder** (`KosmicStructureGenerator`). A cycle is an array of
`(degree, type, bars)`. Body sections loop the cycle from their first bar, cutting the last window
at the section end. Intro and outro stay on the tonic. Every window is 2 or 4 bars and starts on an
even bar, because the pad rules re-attack on even bars only. Every fourth pass takes the family's
alternate last window where it has one. B sections loop their own 8-bar B cycle (leaving the tonic
and coming home), but still draw the A cycle each pass so A-section draws are unchanged.

**Families**, eight in one pool, drawn once per song. The Oxygene three keep a 55 / 30 / 15 shape;
each other family has the weight of an average one. The family sets the mode.

- **Oxygene Dorian Vamp** (20.6%) — Dorian. A: i ×4, ii ×2, then i, bIII or IV ×2 (50/25/25). B:
  bIII ×2, IV ×2, i ×4. *Oxygene 4.*
- **Oxygene Aeolian Cycle** (11.3%) — Aeolian. A: i ×4, bVII ×2, iv ×2 (alternate last: bVI). B:
  bVI ×2, bIII ×2, bVII ×2, i ×2. *Oxygene 8.*
- **Oxygene Two-Chord Sway** (5.6%) — Aeolian or Dorian 50/50. A: i ×2, v ×2. B: i ×2, iv ×2 (iv
  major in Dorian). *Oxygene 3.*
- **Magnetic Fields Arc** (12.5%) — Aeolian, V major. A: i, bVI, iv, V ×4 each. B: bIII, bVI, V,
  i ×2 each. *Magnetic Fields 1.*
- **Magnetic Fields Turn** (12.5%) — Aeolian, V major. A: i, V, bVI, bVII ×2 each. B: iv ×2,
  V ×2, i ×4. *Magnetic Fields 2.*
- **Equinoxe Phrygian** (12.5%) — Phrygian. A: i ×8 (pedal), iv, bII, bvii, i ×2 each. B: bVI,
  bIII, bII, i ×2 each. *Equinoxe.*
- **Magnetic Fields Descent** (12.5%) — Ionian. A: I, vi, V, IV ×2 each. B: iii, IV, V, I ×2
  each. *Magnetic Fields 4.*
- **Chronologie Pop Loop** (12.5%) — Ionian. A: I, V, ii, IV ×2 each. B: I ×2, IV ×2, vi ×4.
  *Chronologie 4.*

**Bridge chords** (12-bar form shown; the 8-bar form drops the first): Dorian Vamp bVII, v, bVII;
Aeolian Cycle iv, v, bIII; Two-Chord Sway bIII, bVI, bVII (Dorian: bIII, IV, bVII); Arc bVI, iv,
bVII; Turn bIII, bVII, i; Phrygian bIII, iv, bvii; Descent IV, ii, vi (leading to B's iii); Pop Loop
vi, IV, V (resolving onto the return's I).

**Notes stay in the scale.** Every Space rule snaps its notes to the song's scale. A chord that
carries a note outside the scale (the major V in Arc and Turn) gets its own scale
(`spaceChordScale`: the leading tone replaces the natural seventh), and `fitSpaceChordScale` runs
once per pitched track after generation and after a single-track regen, moving only the notes the
chord has swapped out. The pads track is fitted one step ahead (`spacePadsAnticipation`) so
Anticipated Strings' early notes take the chord they belong to. `HarmonicMinor` is not used.

**Tempo.** One range, 96–128, triangular, peak 118.

---

## Structure and arrangement

**Forms:** ab 25%, aba 30%, abab 30%, abba 15%. No `single_evolving`: without a B section the riff
never plays. Space does have bridges: its own mute-schedule bridge (see "Bridge" below) appears in about 30% of ab and aba songs. Only base Kosmic's bridge sections and their drum, call-and-response and whistle material are off.

**`KosmicSpaceArrangement`** builds the break schedule per song from the structure and the seed
alone, so a regenerated track rebuilds it without storing it. Every edge falls on a body section's
start or a 16-bar point inside one; nothing breaks in the first 16 body bars or the last 8 before
the outro.

- **Lead 1 rests.** One rest, two in songs over 110 bars, each 16–24 bars. Every body section keeps
  at least 8 bars of lead. Lead 2 plays on.
- **Sequencer by section.** The full source pattern plays in the intro, the outro and Lead 1's
  rests; the song's thinner variant (one of three measured masks) plays wherever Lead 1 does.
- **One sequencer break** of 4, 6 or 8 bars (20/60/20): Rhythm and Lead 2 silent, drums and bass
  carry on. Songs with a bridge have none.
- **Drum and bass thinning.** Each candidate point has a 50% chance of a stretch of 8, 12 or 16
  bars (40/20/40); 8 full bars between stretches; at least two stretches in songs over 100 bars,
  one in shorter ones. In 60% of drum stretches the bass thins over the same bars; one more stretch
  in 50% of songs thins the bass alone. The Berlin School drone drops out completely over bass
  stretches. A thin Falling Walk bar keeps the notes on steps 0, 6 and 12. Each simpler stretch
  ends on a 1- or 2-beat fill into the fuller beat.
- **At most three breaks a song, the bridge counting as one.** The bass-only stretch, drawn last,
  is the first to go.
- **Swells.** KOS-TEXT-005 adds a swell on every bar where Lead 1 or the sequencer returns.
- **Drum fills** (preset box and Mini Pops returns): a kick and snare fill, snare roll or tom roll,
  never the same as the song's previous fill; half the preset-box fills land on a crash. The
  Magnetic Gallop takes short 1-beat fills at body section changes and around its simpler
  stretches, plus one at the end of each 8-bar phrase that has none within 7 bars (`addSpaceBoxFills`). Fill weights: tom roll 40%, snare roll 35%, kick and snare 25%.
- **Theme return.** A song ending on a B section (ab, abab) replays the first A section's opening 8
  bars, with its chords, two thirds into the last B section (`SpaceThemeReturn`).
- **Live annotations.** During playback a coordinated break is called out at its bar naming the
  parts either side (`Bar 071 Sequencer and Lead 2 drop out`); thin stretches log
  `Drums simplify` / `Drums return` and `Bass pattern evolving`. A Lead 1 rest on its own gets no
  line.

**Bridge** (`SpaceBridge`, mute schedule with its own stream). In `spaceBridgeShare` = 0.30 of ab
and aba songs (about 1 Space song in 6). It takes the last 8 or 12 bars of the first A section and
ends where the first B begins, leaving A at least 16 bars. Two kinds, half each:

- **Magnetic Fields Breakdown** (8 or 12 bars). Sequencer, Lead 1 and Lead 2 out. The preset box
  drops to the kick alone on beats 1 and 3; a 12-bar breakdown rebuilds with 8th-note hats over its
  last 4 bars. Hand Percussion plays its sparse core, Mini Pops plays on. Bass holds the chord root
  an octave down, re-attacked every 2 bars. Pads carry the family's bridge chords. Swells into and
  out of it.
- **Rendez-Vous Sequencer Solo** (8 bars). The sequencer alone playing KOS-RTHM-016's full source
  pattern whatever the song's Rhythm rule, pads in half of these songs, everything else silent. Two
  automatic filter sweeps (`KosmicAutoSweep`, otherwise off in Space) reopen on its fifth bar and on
  the return. Logged as `Sequencer solo 8 bar`.
- **Edges.** In: a crash on the first downbeat; in the solo the bass holds one root for 2 bars
  before dropping out. Out: a two-note bass pickup walking up to B's first note, a 2-beat drum fill
  and a crash on B (each drum rule has its own version). The log adds "+ bridge" to the Form line
  and calls the bridge out at its first bar.

---

## Rules by track

Steps are 16ths: 16 a bar, 4 a beat. "Root" is the current chord window's root. Register clamps
fold by octaves. Weights are shares of Space songs on that track.

### Drums

KOS-DRUM-009 Preset Box 26%, KOS-DRUM-001 Mini Pops 20%, KOS-DRUM-010 Magnetic Gallop 15%,
KOS-DRUM-012 Hand Percussion 15%, KOS-DRUM-005 Electric Buddha Pulse 12%, no percussion 12%. The
Gallop and Hand Percussion are distinctive, so they are held to 15%; the Pulse takes load off the
Preset Box. Kits: 808 Kit 75%, Machine Kit 25%,
playing its own synth toms in fills; its electric snare (40) plays as the plain snare.

**KOS-DRUM-009 Oxygene Preset Box** — the Minipops pattern of Oxygene 4. Closed hat on steps 0, 1,
4, 5, 6, 8, 9, 10, 12, 13, 14; kick 0, 2, 6, 10; clap 4, 12 (in about 10% of songs only, in one or
two whole body sections; otherwise the step 12 accent is the only backbeat); open hat 2; one accent
voice on step 12 per song (side stick, claves or tambourine). Draws: hat mask (the source or three
one-gap variants, 25% each), kick (source 40% or steps 0, 6, 10 at 60%). A repeat guard drops one
hat in every eighth bar. Plays through intro and outro. Its simpler stretches either drop the 16th
hats (60%) or go to quarter hats with kick on 0 and 10 and no open hat (40%).

**KOS-DRUM-001 JMJ Mini Pops** — base Kosmic's rule, in the pool for variety. Drops out in the first
two drum stretches and returns on a 1- or 2-beat tom roll.

**KOS-DRUM-005 Electric Buddha Pulse** — base Kosmic's rule, in the pool as a plain beat. Quarter
hats accented on 1 and 3, kick on beat 1 (and beat 3 in 45% of 8-bar phrases), snare on beat 3
(65%) or on 2 and 4 (35%), re-drawn every 8 bars; an open hat on the last 8th of every fourth bar.
In Space it plays through intro and outro without a cold start, its snare is the electric snare so
the fill log never reads the backbeat as a fill, simpler stretches drop to the kick on beat 1 under
quarter hats, the breakdown plays the kick on beats 1 and 3, and it takes the Preset Box's fills.

**KOS-DRUM-010 Magnetic Gallop** — Magnetic Fields 1, 2 and 4. Kick pairs lead into each beat on steps 0, 2, 3, 6, 7, 10, 11, 14, 15 (Magnetic Fields 1's pairs straddle the beat, which put a kick a 16th after about a third of the 8th-note bass notes; this figure measured 0% there under the drone, Falling Walk and Triad Walk), under a ride or closed hat (50/50) on every 16th. Snare off, or on steps 2, 3, 6, 10, 11, 14 (50/50), on the electric snare so the fill log never mistakes it for a fill. An agogo on the quarters in 30% of songs. Simpler stretches drop the kick but keep the gallop (Zack, 2026-11-09, after Ionique VIII Part 7: kick on 1 and 3 alone lost the character): variant 0 plays soft 16th tops, variant 1 quarter tops with quiet electric-snare ghosts on the pairs 2-3, 6-7, 10-11 and 14-15. Full B bars lighten: 8th tops, a ride bell on the beats, the snare on its off-beats only, and an open hat on the last 8th of every second bar; when the bass is the drone, Falling Walk or Triad Walk the B kick is the plainer 0, 6, 8, 14 of Magnetic Fields 2 and 4 (the Pumps keep the gallop kick).

**KOS-DRUM-012 Oxygene 6 Hand Percussion** — no kick, snare or hats: low bongo 0, 8; mute conga 4;
open conga 6; low conga 12, 14; maracas 0, 6; shaker 2, 3, 4, 10, 12, 14; castanets 12, 13, 14 in
60% of songs. Shaker step 3 drops every eighth bar. The guiro plays only in two or three stretches
a song (8 or 16 bars), quietly. Thins over every bass or drum stretch.

### Bass

Where a pump may play: Falling Walk 19.2, Oxygene 8 Pump 19.2, Berlin School drone 13.6, Octave
Pump 28, Triad Walk 20 (percent). Under a busy rhythm (016, 005, 017, 018): Falling Walk 50, drone
16.7, Triad Walk 33.3. About 42% of Space songs carry a Magnetic bass.

**KOS-BASS-018 Oxygene Falling Walk** — Oxygene 4. Six notes a bar on steps 0, 4, 6, 10, 12, 14,
chord tones top, mid, top, low, mid, low. Draws: falling set octave/6th/5th, octave/5th/3rd or
octave/b7/5th (35/35/30); rhythm source (60%) or `x.x.x.x...x.x.x.` (40%). In 1 bar of 8 the
figure shifts up a step. A breath bar and a turn bar, deterministic and lighter than the Pump's.
Thin bars keep three notes.

**KOS-BASS-020 Oxygene 8 Pump** — rhythm `x.x.xx.xx.x.xx.x`: upper root on steps 0, 2, 5, 8, 10, 13;
low root with the b7 above it on 4, 7, 12, 15 (bare octaves in 30% of songs). Varies as the source
does: a fifth voicing on each 8-bar loop's turnaround window, a breath (low hit on step 15 drops)
in the second bar of each 8, a turn bar before a new body section with the leading tone raised on
the tonic chord, and a late entry into each body section after the first. Thin bars keep the upper
root only.

**KOS-BASS-019 Magnetic Fields Octave Pump** — three figures per song: Equinoxe octave eighths 40%
(30% of those on 16ths), octave pops 35% (`x..xxxxxx..xxxxx`, octave on 4, 7, 12, 15), leading-tone
neighbour pedal 25%. Root in MIDI 31–42. Varies as the Oxygene 8 Pump does, plus a density switch
over the last 8 bars of a section of 16 or more.

**KOS-BASS-021 Magnetic Triad Walk** — Magnetic Fields 5. Root, 3rd, 5th in dotted quarters on
steps 0, 6, 12, root in MIDI 29–40. A displaced bar plays the 5th on step 4, root on 8, 3rd on 14.
Draws: order root-3rd-5th 45, root-5th-3rd 30, root-5th-octave 25; displacement in B sections 40,
the second half of sections of 16+ bars 35, or the last body section after 8 bars 25. Varies as the
Pumps. Not busy, so it plays under busy rhythms.

**KOS-BASS-001 Berlin School drone** — reused; root held 2 bars.

### Rhythm (the sequencer engine)

KOS-RTHM-016, 002, 005, 021, 017 and 018, a sixth each.

**The engine** is `jmjStepSequencer(pattern:)`, used by every Space sequencer rule. A pattern is 16
steps, each a rest or one of root, octave, fifth, lower neighbour or third. Each bar the engine
emits the pattern against the current chord root, `durationSteps: 1`, root in MIDI 48–59. The
chord transposes it, so no long identical run occurs. Rhythm is never thinned by the arrangement
filter or the density guard; it rests only for the sequencer break and the bridge. The sequencer
rules play the full figure in the intro, outro, Lead 1's rests and the sequencer solo, a thinner
one under Lead 1 (`spaceSequencer`).

**B sections hold the A density.** After any Space Rhythm rule runs, `spaceHoldBDensity` trims each B
bar to the mean note count of the first A section's sounding bars, rounded up. Whole onsets go, off-beat
16ths first, then 8ths, quarter-note onsets last, and a bar never drops below the target. Ties come from
a derived stream, so no draw moves. A bars, bridges, the intro and the outro are untouched. It runs at
generation and at Rhythm regen.

- **KOS-RTHM-016 Oxygene Octave Sequencer** — `R . O . R O R . O O R . O R O .`. Mask: source or
  three thinner variants (25% each). In 25% of songs the octave becomes the fifth. Busy.
- **KOS-RTHM-017 Equinoxe Fifth Triplets** — `R . 5 5 R 5 5 R R . 5 5 R 5 5 R`; the fifth becomes
  a fourth or octave (source 40%, 30% each); three thinner variants. Busy.
- **KOS-RTHM-018 Magnetic Fields Leading-Tone Cell** — `O . R O N R R O . R N O R . O R`, N the
  lower neighbour. Rotation 0 (30%), 4 or 8 steps (35% each); octave or fifth (70/30); three thinner
  variants. Busy.
- **KOS-RTHM-021 Oxygene 8 Offbeat Pedal** — offbeat 8ths alternating a low pedal with upper chord
  tones, root in 48–59; upper line a step lower in 30% of songs. Rests through the sequencer break.
- **KOS-RTHM-002 JMJ Hook** and **KOS-RTHM-005 JMJ Dual-Rate** — base Kosmic's rules, playing an
  octave down under Lead 1 and resting through the sequencer break. Dual-Rate is busy.

### Lead 1

A sections draw one of five rules, 20% each. B sections draw one of three, a third each.

- **KOS-LD1-013 Oxygene Falling Theme** (A) — a 2-bar statement falling from a high note through
  chord tones to the root, the last note held into the next bar. Per song: note count (5 at 50%, 4
  at 25%, 6 at 25%), top note (octave, 6th, 4th), inner line (5-3-5, 5-4-5, 6-5-3), rhythm (source
  or four notes on 0, 2, 4, 6); statements 1 and 2 are never the original figure. From statement 3:
  transposed to the current chord, opening note dropped, or the final root replaced by the 5th.
  Every fourth statement exact; one in four replaced by 2 bars of rest. Top note in 72–84.
- **KOS-LD1-016 Oxygene 6 Rising Strings** (A) — three long notes a bar on steps 0, 6, 12, each bar
  a 3-note cell on the current chord. The two long notes are chord tones; the third is a scale step
  on when it is short and a chord tone when it is long. A climb rises about an octave; a fall is
  four falling cells. Source cycle: climb, climb, fall, a held note, three bars of rest. Register
  58–84; a note past the edge turns back onto the nearest chord tone inside it. Draws: chromatic
  approach, a 16th pickup a semitone below each climb on step 15 of the bar before (60%), rhythm 0,
  6, 10 (40%), 8-bar climb-and-fall cycle (40%). Passes 1 and 2 are plain; then each pass starts its
  climbs a chord tone lower or higher, or plays a reshaped cycle (neighbour cell third in the climb,
  no bounce in the fall), never the same twice running; every fourth pass is plain. The pass draws
  use a copy of the RNG, so later Lead 1 draws are unchanged.
- **KOS-LD1-017 Oxygene 8 Offbeat Climb** (A) — statements fill one bar and the next is silent,
  entering on step 2: climb, leap and turn from the current chord root, MIDI 62–73, legato. A
  16-bar phrase per A section, every third phrase a 2-bar arch figure with 7 bars of rest. Draws:
  opening leap from the 5th (40%), 6th (30%) or 4th (30%) below; the climb's top repeated, on to the
  5th, or back to the 3rd; rhythm source (60%) or 2, 4, 6, 8, 10, 13 (40%).
- **KOS-LD1-015 Magnetic Fields Turn Melody** (A) — a statement of 3 to 5 half-bar 16th runs on
  steps 2–7 and 10–15 from the start of each 4-bar block, each run a scale step lower; every fourth
  statement climbs instead. Legato. Draws: turn shape (five, the source's two at 15% each), run
  count, start on root, 3rd or 5th, 6- or 5-note runs. Range MIDI 57–84.
- **KOS-LD1-018 Magnetic Call and Hold** (A) — Magnetic Fields 4. An 8-bar phrase: call (one note
  repeated, then a 3-note tail), answer (two held half notes on the next chord), call, answer a step
  higher, trill call, answer, cadence onto the chord root, rest. In 60% of songs an octave phase
  bounces the chord root between octaves, every third 8-bar block. Legato. Draws: call note root 30,
  3rd 35, 5th 35; call rhythm source 50, two variants 25 each; tail `[-1 -2 +1]` 40 or one of three
  others 20 each; answer down 60 or up 40. Notes 54–88.
- **KOS-LD1-014 Oxygene See-Saw Riff** (B) — six notes rocking between an anchor and a pivot a fixed
  interval above it, stated each bar for 2 bars on a chord, then following the chord. Draws:
  interval fourth 30, sixth 30, octave 20, fifth 20; grouping 3+3 (40), 2+2+2 (30) or 3+2 (30);
  first or second half of the bar (60/40); anchor below or above the pivot (60/40). In 1 bar of 8 the
  anchor moves to the chord's 4th; it rests in the last 2 bars of every 8; the last B section thins
  towards the outro. Top note folded into 73–84.
- **KOS-LD1-019 Equinoxe Thirds Riff** (B) — the See-Saw with the pivot a scale third away and
  rhythm 3+3+2 on steps 0, 2, 5, 8, 10, 13, legato. In Phrygian songs the pivot is bII over the
  tonic in the last bar of every 4.
- **KOS-LD1-006 JMJ Phrase Loop** (B) — base Kosmic's rule, in B sections.

### Lead 2

KOS-LD2-005 Space echo reply, KOS-LD2-001 Magnetic Twin and KOS-LD2-000 No lead 2, a third each.

**KOS-LD2-005 Space echo reply** — Echo melody's cycle started two bars later, so its phrases fall where Echo melody rests: a held note in bars 3 and 4 of each 8-bar cycle, then the same two notes a diatonic third lower in bars 7 and 8. The echo is always below, never above.

**KOS-LD2-001 Magnetic Twin** — two variants, 50/50. **Stereo twin:** Rhythm's notes replayed on
Lead 2 outside B sections (it rests whenever B plays), 6 velocity lower; static pans Rhythm +0.45, Lead 2 −0.45; Rhythm's auto-pan holds still.
`SongState.isSpaceStereoTwin` finds the variant from the notes (Lead 2 at least 80% of Rhythm's
count outside B, 90% on Rhythm's onsets), so it survives regen and reload, and a Rhythm regen carries the twin
with it. **Late octave:** Lead 1 doubled an octave up from the first 8-bar point of the last third,
a note above 88 in unison. It runs after Rhythm and Lead 1.

### Pads

KOS-PADS-001 and KOS-PADS-010 36% each, KOS-PADS-009 28% (slightly less often, by Zack's choice).
All re-attack every 2 bars on the current chord.

- **KOS-PADS-001 Eno long drone** — root, fifth, octave and upper third; 32-bar velocity swell; a
  1-in-8 breath gap. With 2- and 4-bar chords it follows every change.
- **KOS-PADS-010 Oxygene 4 Staggered Bloom** — a close triad entering on steps 0, 4, 8 and
  releasing together after 2 bars; lowest note the first chord tone at or above MIDI 55. The bloom
  opens from the top down in 30% of songs.
- **KOS-PADS-009 Oxygene 7-13 Anticipated Strings** — KOS-PADS-001 with every attack one 16th
  early, so each chord change lands on step 15 of the bar before while bass and sequencer still
  play the old chord. Release stays on its grid. The shift runs after the arrangement's silences.

### Texture

**KOS-TEXT-005 Oxygene Surf Sweep** — one long note per event on the noise instrument, starting at
step 12 of the bar before an 8-bar boundary and held 32 steps; pitch the chord root in MIDI 60–72;
swell direction comes from the Texture track's `sweep` effect. At every section start but the
first and every 8th bar inside a body section, 70% of them, never within 8 bars of the previous
event, plus every return. Variant (25% of songs): a 2-bar swell every 2 bars through B sections
only. The automatic Kosmic filter sweep is off in Space.

---

## Reused and excluded rules

**Reused unchanged:** KOS-PADS-001, KOS-BASS-001, KOS-LD2-000, KOS-DRUM-000. Base
Kosmic's JMJ rules KOS-DRUM-001, KOS-RTHM-002, KOS-RTHM-005 and KOS-LD1-006 are in the pool
because Zack wanted the variety, though they match no transcription. KOS-DRUM-005 Electric Buddha
Pulse, an Electric Buddha Band rule, is in the drum pool as a plain beat, with Space's own fills
and thinning.

**Excluded from Space** (base Kosmic keeps all of them; nothing is removed from base Kosmic or
Drift): drums KOS-DRUM-002 to 004 and 006 to 008; every bass rule except 001; Rhythm KOS-RTHM-001 to 015 except
002 and 005; Lead 1 every base KOS-LD1 rule except KOS-LD1-006, and KOS-LD1-010 to 012; every base Pads
rule except 001; Texture KOS-TEXT-001 to 004.

**Switched off in Space:** base Kosmic's own bridge sections (Space's separate bridge stays) and the X-Files whistle; bass sub-layers (KOS-RULE-17 and
23); base drum fills and cold-start pickups; Lead 1 B-section escalation; Lead 2 lag and sparse
escalation; the automatic filter sweep; forced base rules (the curated first Kosmic song is
ignored). `ArrangementFilter` exempts Rhythm, Lead 1, Lead 2 and Pads.

---

## Instruments, effects, titles and log

**Instruments**, appended to the Kosmic pools (never reorder; all in `Zudio.sf2`). Adding one
touches four places: `poolNames`, `poolPrograms`, `instrumentPickPool`, `instrumentPickPoolStatic`.
Base Kosmic and Drift picks are capped at their pre-Space pool sizes.

- **Lead 1** — Brightness, Synth Brass 1 (0/62), Synth Brass 2 (0/63), 5th Saw Wave (0/86), Bright
  Saw Stack (11/100, shown as Bright Saw)
- **Lead 2** — Brightness 25%, Synth Strings 1 (0/50) and Saw Lead (0/81) 27.5% each, Square Lead 2
  (12/80, always with tremolo) 20%
- **Pads** — Synth Strings, Synth Strings 3 (8/50), 4 (11/50), 5 (11/51), Stereo Strings Slow
  (0/49), Sweep Pad; strings about 80% of picks
- **Rhythm** — Moog, Pulse Bass (11/39), Harpsi Pad
- **Bass** — Moog, Synth Bass 3, Fretless Bass (0/35), Synth Bass 101 (1/38), Mean Saw Bass (12/38),
  20% each
- **Texture** — White Noise Wave (12/122, shown as White Noise), Solar Wind, Solar Wind 2 (12/89),
  Starship (8/125), Interference (11/127), 20% each
- **Drums** — 808 Kit 75%, Machine Kit 25%

Per-instrument level trims were set by ear and live in code (`spaceCC7Trim` in AppState.swift and
the per-program gain tables); they are not restated here. The on-screen Instruments line names
instruments; the saved file keeps program numbers and its format is unchanged.

**Effects and stereo.**
- **Pads** — `sweep`, Space's reverb and delay, static at centre.
- **Texture** — `sweep`, delay, Space's reverb and a slow auto-pan (one sweep per 2, 4 or 8 bars,
  25/50/25).
- **Rhythm** — delay echoing on three 16ths (0.75 beat) against the sequencer's eighths and
  sixteenths, and an auto-pan of ±40% around +0.22. No reverb by default.
- **Lead 1** — delay and Space's reverb, at −0.10. **Lead 2** — Space's reverb at −0.20, with
  tremolo when the instrument is Square Lead 2.
- **Bass and Drums** — centre, no effects.
- The stereo Twin overrides the Rhythm and Lead 2 pans.
- Mean Saw Bass plays at 85% volume, Moog bass 3 below and Synth Bass 101 5 above the shared Kosmic
  level.

**Titles.** `KosmicTitleGenerator.spaceTitle`: single word 15%, part number 15%, two coined words
12%, French phrase 12%, Jarre templates 12%, long-running series 4%, gear jokes 4%, the earlier
numeral, prefix and adjective patterns 26%.

**Log.** The Chords line shows key, mode, family name and Roman numerals on every family, for
example `E Ionian Magnetic Descent I vi V IV` and `A Phrygian Equinoxe i iv bII` (other styles
still trim the numerals; `chordsDescription` takes `keepNumerals`). Rule lines have no
parentheses. Space fill, thin-stretch and bridge lines are rebuilt after a drum or Lead 2 regen.

**Lead 1 versions in the log** (Zack, 2026-11-12, reversing "rule name only"): the Lead 1 rules
KOS-LD1-013 to KOS-LD1-019 name their per-song draws after the rule, comma-joined, as the Chill
jazz leads do. Only draws that differ from the source are named, so a line with nothing after the
name played the source form; KOS-LD1-015 Magnetic Turn Melody has no single source form and names
all its draws. `KosmicLeadNotes` carries them from `KosmicLeadGenerator.generateLead1` to the log.
Examples:
- KOS-LD1-013 "Oxygene Falling lower top, squeezed" (low top; steady fall or closer middle; fewer or more notes; new rhythm)
- KOS-LD1-014 "Oxygene See-Saw Riff wide leap, even groups" (narrow or widest leap; uneven groups; starts late; rocks down)
- KOS-LD1-015 "Magnetic Turn Melody climbing, few runs" (arching, dipping, leaping, dropping; many runs; from the 3rd or 5th; short runs)
- KOS-LD1-016 "Oxygene 6 Rising Strings no lead-in, early third" (short cycle)
- KOS-LD1-017 "Oxygene 8 Offbeat Climb low start, early finish" (high start; ends higher or lower)
- KOS-LD1-018 "Magnetic Call high call, tight" (middle call, on the beat, turning or leaping tail, rising answer, octave bounce)
- KOS-LD1-019 "Equinoxe Thirds Riff rocks down" (its interval and rhythm are fixed)
Plain words, two at most (Zack, 2026-11-12); the rule's name is capitalised, the changes are lower case. A song whose A theme returns after B ends its line with "returns" when there is room.
The line a Lead 1 regen appends names the rule only, without its version, as Chill's jazz leads
do. Log text only: no draw moved, so every song plays as before.

---

## Rule ledger

**Built, new to Space (22 rules):**

- Drums: KOS-DRUM-009 Oxygene Preset Box, KOS-DRUM-010 Magnetic Gallop, KOS-DRUM-012
  Oxygene 6 Hand Percussion
- Bass: KOS-BASS-018 Oxygene Falling Walk, KOS-BASS-019 Magnetic Fields Octave Pump, KOS-BASS-020
  Oxygene 8 Pump, KOS-BASS-021 Magnetic Triad Walk
- Rhythm: KOS-RTHM-016 Oxygene Octave Sequencer (with the engine), KOS-RTHM-017 Equinoxe Fifth
  Triplets, KOS-RTHM-018 Magnetic Fields Leading-Tone Cell, KOS-RTHM-021 Oxygene 8 Offbeat Pedal
- Lead 1: KOS-LD1-013 Oxygene Falling Theme, KOS-LD1-014 Oxygene See-Saw Riff, KOS-LD1-015
  Magnetic Fields Turn Melody, KOS-LD1-016 Oxygene 6 Rising Strings, KOS-LD1-017 Oxygene 8 Offbeat
  Climb, KOS-LD1-018 Magnetic Call and Hold, KOS-LD1-019 Equinoxe Thirds Riff
- Lead 2: KOS-LD2-001 Magnetic Twin
- Pads: KOS-PADS-009 Oxygene 7-13 Anticipated Strings, KOS-PADS-010 Oxygene 4 Staggered Bloom
- Texture: KOS-TEXT-005 Oxygene Surf Sweep

**New infrastructure, built:** the chord-cycle builder; the Space flag and its plumbing; the
sequencer engine; `KosmicSpaceArrangement` and `SpaceBridge`; the chord's own scale and the fit
pass; the stereo-twin detector.

---

## Release checklist

- Release split set (2026-11-09): Drift 25, Space 35, base 40. Existing tests that read the old 30% Drift
  share or the testing split may still disagree (`KosmicDriftCompareTests`, possibly
  `KosmicAutoSweepTests`, the Kosmic `DeterminismTests` seeds). Not yet run or updated.
- Keep testing light: build both apps, then listen. Fingerprint diffs only for changes that should
  be same-output.

---

## On hold and closed

Closed means judged unnecessary on 2026-11-09 (Zack): Space sounds great without them. The notes stay
here in full in case we decide to add them later. On hold means not built and not discussed in detail.

### Closed: additional Space rules (unnecessary, kept for future consideration)

- **Phase 3 Chronologie, the rest.** KOS-DRUM-011 Chronologie Four-on-the-Floor; the Chronologie
  Andalusian Descent family (i ×2, bVII ×2, bVI ×2, v ×2, Aeolian); the Zoolook Pedal family (one
  chord for 16 bars, then i ×4, bVII ×4, v ×8). Chronologie 2 is transcribed at 162 BPM against
  119–120 for the other parts, so any Chronologie tempo needs a decision.
- **KOS-RTHM-019 Zoolook Pedal Arpeggiator.** A 3-step cell on a 16th root pedal, as a preset of the
  engine. Judged too close to Fifth Triplets and the Leading-Tone Cell on its own; worth building
  only beside the Zoolook Pedal family.
- **More Oxygene rules**, ten candidates read from the corpus: an Oxygene 4 Triplet Turn lead
  (sitar), an Oxygene 6 blues solo for the last section, an Oxygene 3 Shadow Bass, Anticipated
  Octaves with the Oxygene 6 paired-8th descent, an Oxygene 8 Phasing Cell, an Oxygene 6
  paired-descent rhythm, Oxygene 6 Close Chords pads, an Oxygene 8 Four Pulse drum, an Oxygene
  Half-Time drum. IDs are not reserved.

### On hold

- **Pedal Rise.** One non-tonic chord held 8 bars, drums out, a long swell into the return.
- **Effects-only interlude.** Pads and a held Texture effect, as the endings of Oxygene 3 and 6.
- **A Solina-type string sample.** Only if the string pads turn out not to sound like a string
  machine (about 2 MB, licence permitting redistribution).
- **`KosmicSpaceTests`.** A test suite pinning the flag through the copy methods, the pooled rules,
  chord windows on even bars and the tempo range, plus a `DeterminismTests` fingerprint at the
  release split.
- **Two unidentified source files.** The Equinoxe file has no part number, and the unnumbered
  Oxygene is probably from Oxygene 7–13. If either is recognised by ear, the rule names citing them
  can be made exact.
