# Motorik Europe — Design Plan

Status: **implemented and shipping in 2.6 build 131.**

Motorik Europe is the Kraftwerk-derived flavour of Motorik. A coupled *sync group* of tracks
adopts Kraftwerk rules together while the rest of the song draws from normal rotation, and the
song is presented to the user as **Motorik Europe**.

This document describes the design as built. Section numbers, weights and measurements below
are the shipped values.

---

## What This Is

Motorik has four presentations: regular Motorik, Motorik Noir, Motorik Arcade and Motorik
Europe. Europe is the machine-like one — where the others differ by mood or energy, Europe
differs by *coordination*: several tracks lock to the same rigid pattern instead of each
drawing independently.

It is built differently from Noir and Arcade. Those are substyle flags that restrict every
track's rule pool for the whole song. Europe is a **sync group** — a named set of tracks that
draw Kraftwerk rules together, while every track outside the group behaves like base Motorik.
Roughly half the tracks in a Europe song are unsynced, which is deliberate: the machine
element sits inside a Motorik song rather than replacing it.

So Europe shares base Motorik's harmony, structure, effects and instrument pools. What it adds
is the sync group, a narrower tempo band, and a German-flavoured title affix.

### The name

Kraftwerk were a European act more than a narrowly German one — they recorded in German,
English and French, drew on European culture and industry, and shaped it back. "Europe" names
that sensibility without naming any of their records. It is also free of collisions with
Zudio's own title word banks, which "Maschine" and "Düsseldorf" are not: the title generator
already produces *Die Maschine* as a song name.

---

## Musical Identity

Kraftwerk's character is not primarily its basslines, which is how Zudio currently models it —
four of the five existing Kraftwerk-derived rules are bass. What makes *Autobahn* and *The
Robots* sound like themselves is the **whole arrangement agreeing**: sparse mechanical
percussion with a lot of space, short cells repeated with total rigidity, unison doubling
between parts, and deliberate silence used as a structural element.

Neu! and Kraftwerk share a pulse but differ in density and attitude. Neu! is propulsive and
organic — a drummer playing a groove. Kraftwerk is *placed* — a machine executing a pattern.
Base Motorik currently sits almost entirely on the Neu! side.

---

## Method: Homage, Not Transcription

Every rule is a statistical constraint — density, rest ratio, cell length, register band,
interval distribution — never an encoded melody or bassline. Output should be recognisably of
that world and original in content.

---

## The Sync Mechanism

**The core design decision.** Track selection is **coupled, not independent.**

Drawing per track independently would produce incoherence rather than flavour: a Kraftwerk
bass underneath a busy Neu!-style drum pattern reads as a Motorik song with an odd bass, not
as Kraftwerk. The character depends on parts agreeing with each other.

So: **one sync group is drawn per song**, and only those tracks use Kraftwerk rules.

**The roll happens inside base Motorik only**, after the existing substyle roll has already
excluded Noir and Arcade. So these percentages are of base Motorik songs, not of all Motorik
songs. At the current 61% base share, a sync fires in **20% of Motorik output overall**, which
makes the four-way split of the style: regular 41 / Noir 20 / Arcade 19 / Europe 20.

- **No sync — 67.2%.** Normal Motorik, unchanged. This must remain the common case.
- **Rhythm Section sync — 13.1%.** Bass + Drums + Lead 1. The machine rhythm section — rigid
  kick placement with a bass locked to it — carrying Kraftwerk lead statements over the top.
  The only group with Drums, and the only one without Texture.
- **Sequence Lock sync — 11.3%.** Bass + Rhythm + Texture. A repeating cell shared between
  bass and sequencer.
- **Machine Voice sync — 8.4%.** Bass + Rhythm + Lead 1, with unison or octave
  doubling between Rhythm and Lead 1. This is the most identifiable Kraftwerk gesture. Bass is
  in the group so the doubled line has a locked foundation rather than a Neu!-style rhythm
  section underneath it.

**Only Bass is in all three groups.** It is the foundation of the machine sound and has four
rules written for it. Rhythm is in two, Lead 1 in two, and Drums and Texture in one each, so
every group is three tracks and no two draw on the same set of rules.

Texture is deliberately in **one** group only. With it in all three, the two Kraftwerk texture
rules were the whole of what a sync song's texture ever did, and between them they have one
shape — sparse single notes across a wide register. Confining them to Sequence Lock sends 62%
of sync songs back to the ordinary Motorik texture pool, which is where the variety comes from.

Every track with purpose-built rules is reachable from at least one group; a test enforces that,
so a membership change cannot silently orphan a rule set.

**Pads is never synced.** It is what keeps playing through a dropout, which is what makes the
drop read as a section change rather than the song stopping. There are no Kraftwerk pads rules.

**Lead 2 is locked to Rhythm.** Both Lead 2 rules are partners — one mirrors Rhythm's cell at
a 2-step offset, the other re-emits Rhythm's events at the octave — so neither is meaningful
without Rhythm in the sync. Its behaviour is therefore fully determined:

- **Rhythm in the sync** (Sequence Lock, Machine Voice): Lead 2 takes the partner rule
  matching Rhythm's draw — `MOT-RTHM-014` pairs with `MOT-LD2-012`, `MOT-RTHM-015` pairs with
  `MOT-LD2-011` — **or rests entirely**. Split 65% partner / 35% silent, and when it partners
  the doubling is **sectional**: alternating stretches of 8-16 bars on and off, entering after a
  variable opening, so it covers about a quarter of the song's bars rather than all of them.
  Applied end to end it was either wholly absent or a rigid copy from first bar to last, and
  across songs that single gesture was all you heard. It never draws a
  normal Motorik rule here: a melodic Lead 2 over a rigid two-pitch-class sequencer is exactly
  the incoherence the sync design exists to prevent. Variety comes from presence versus
  absence, not from mixing vocabularies.
- **Rhythm not in the sync** (Rhythm Section): Lead 2 draws from normal Motorik rotation.
  There is no sequencer for it to clash with, and a melodic line over a machine rhythm section
  is a legitimate hybrid — the "some but not all" principle working as intended.

The 65/35 split reflects the corpus: doubling appears in two of the three files, so it should
be common but not universal.

Effective track counts per song: **Rhythm Section** = Bass + Drums + Lead 1; **Sequence Lock**
= Bass + Rhythm + Texture (+ Lead 2 when partnering); **Machine Voice** = Bass + Rhythm +
Lead 1 (+ Lead 2 when partnering). Five membership shapes reach the log.

All remaining tracks draw from normal Motorik rotation as they do now.

**Log it.** The tag is `Sync` plus the track count — `Sync 4` — never `Cluster`, which is a
krautrock band and the name of
several existing texture rules, so the word is already taken in this codebase.

**What is logged.** When one fires, emit a `GenerationLogEntry` with tag `Sync` naming the
tracks that actually adopted Kraftwerk rules, so a song's character can be identified by
reading its log rather than by guessing:

```
Sync 3     Bass, Drums, Ld 1
Sync 3     Bass, Rhythm, Texture
Sync 4     Bass, Rhythm, Texture, Ld 2
Sync 4     Bass, Rhythm, Ld 1, Texture
Sync 5     Bass, Rhythm, Ld 1, Texture, Ld 2
```

List **actual membership**, not the sync group's name — Texture always joins and Lead 2 joins only
when partnering, so the line should reflect what happened in this song rather than which of the
three sync groups was drawn. A song where Lead 2 drew silence omits it.

Emit nothing when no sync fires; the absence is the signal. The entry is written into
`generationLog`, so it reaches the `.zudio` file and survives reload like every other rule line.

**Implementation.** One roll at frame-generation time, thresholds in order, exactly as the
Motorik substyle roll already works. The result is passed to the generators as an enum, and
each generator checks whether its own track is in the drawn sync before choosing a rule
pool. No SongState flag is needed if the sync is derived from the song seed in each
generator — but a stored value is simpler to log and to reason about.

---

## Subtraction — Four Bass Rules Retired From Base Motorik

Base Motorik's bass pool carries 15 rules, several of which are neither distinctive nor
compatible with a machine aesthetic. Thinning it concentrates the style and makes room for the
Kraftwerk rules to be heard.

**Criterion: a rule may be retired only if it survives elsewhere AND is not core to Motorik's
identity.** The second half matters — `MOT-BASS-004` "Neu! Hallogallo lock" is technically
retire-safe because Arcade also uses it, but retiring the Neu! rule from base Motorik would be
precisely wrong. Motorik *is* Neu!.

Retire from base Motorik (all four remain available in Noir or Arcade):

- **`MOT-BASS-005` McCartney drive** — 9%. Rock bass; the least machine-compatible rule in the
  pool. Survives in Arcade.
- **`MOT-BASS-007` Hook Ascent** — 8%. Survives in Noir.
- **`MOT-BASS-006` LA Woman Sustain** — 5%. Doors-derived. Survives in Noir.
- **`MOT-BASS-010` Quo Arc** — 3%. Boogie rock. Survives in Arcade.

**Explicitly kept:** Neu! Hallogallo lock, both Moroder rules (machine-sequencer music sits
naturally alongside Kraftwerk rather than against it), and both existing Kraftwerk rules.

### Redistributed weights

The freed 25% goes mostly to the rules that pull toward this plan's goal. Base Motorik bass
becomes eleven rules:

- `MOT-BASS-001` Root Anchor — 9%
- `MOT-BASS-002` Motorik Drive — 11%
- `MOT-BASS-003` Crawling Walk — 8%
- `MOT-BASS-004` Neu! Hallogallo lock — 9% *(raised from 4%)*
- `MOT-BASS-008` Moroder Pulse — 11%
- `MOT-BASS-009` Vitamin Hook — 8%
- `MOT-BASS-011` Quo Drive — 4%
- `MOT-BASS-012` Moroder Chase — 9%
- `MOT-BASS-013` Kraftwerk robotic bass — 10% *(raised from 4%)*
- `MOT-BASS-014` McCartney melodic drive — 10%
- `MOT-BASS-015` Kraftwerk driving bass — 11%

Sums to 100%. Net effect: the two existing Kraftwerk bass rules rise from 15% combined to 21%,
and Neu! more than doubles — so base Motorik gets **more** characterful in both directions, not
just one.

Two rules were trimmed afterwards on listening, each having grown too dominant.
`MOT-BASS-015` was first set to 16% and is back to 11%, its 5% spread over Moroder Chase,
Neu! Hallogallo, McCartney melodic drive and Crawling Walk. `MOT-BASS-002` Motorik Drive went
14% -> 11%, its 3% spread over Crawling Walk, Root Anchor and Vitamin Hook. The pool is flatter
than it started — nothing sits above 11% — so no single bass figure defines base Motorik.

---

## Evidence Base

Three transcriptions analysed with `tools/jarre_analyze.py` (corpus-agnostic despite the
name): *The Robots* (Type 1, 18 named tracks, 113 bars), *Autobahn* (Type 0, 237 bars,
analysed **from bar 65** — the melodic section, since Motorik songs are minutes not album
sides) and *Computer Love* (Type 0, 156 bars). Type 0 files were split by MIDI channel.

Same caveats as the Jarre corpus: fan transcriptions, flat velocity, hard quantisation.

**Cells are tiny, and this is the sharpest finding.** Computer Love's lead sequencer runs a
**4-step cell using only 3 pitch classes** at density 3.84 with 28% rest. Autobahn's bass
figure is a **3-step cell over 6 pitch classes**. Compare the Jarre corpus, where cells
measured 8–21 notes with a median of 13. Kraftwerk's sequencer is a very small figure repeated
with total rigidity — not a long phasing pattern.

**The pitch vocabulary is severely restricted.** Three pitch classes on a part carrying 2,321
notes. Six on a bass line. The repetition is what carries the music, not the material.

**Percussion is built from single-pitch voices, each separately sequenced.** The Robots spreads
drums across eight tracks — kick, two snares, two hats, two brushes, toms — every one of them
a **single pitch** with its own density, from 3.30 notes/beat on the busiest hat down to 0.21
on a tom. This is machine sequencing, not a kit performance.

**The percussion section drops out together.** The decisive measurement. In The Robots, voices
leave at the *same bars*: around bar 28 (`brush1` for 14 bars, `ophihat2` for 11, `snaredr6`
for 10, `snaredr1` for 6, `mtomtom1` for 5) and again around bar 73 (four voices for 4–5 bars).
The pad drops for 12 bars at bar 18. These are **coordinated arrangement events**, not
independent rests — roughly a quarter and two-thirds of the way through.

**Bass makes short statements and stops.** `elbass1`: phrases of 7 notes over 10 steps, then
8 steps of silence — a **0.8:1 silence-to-statement ratio**. Punchy and intermittent, quite
unlike the continuous pulsing bass measured in the Jarre corpus.

**Tracks are doubled.** Autobahn's `ch0` and `ch1` are identical — 1,271 notes each, same
register, same density, both dropping for 32 bars at bar 68. Computer Love's `ch4`/`ch5` are
near-identical. The same habit the Jarre corpus showed.

---

## Rule Catalog

Twelve rules, two per track. Each pair is two **measured** behaviours from the corpus, not one
behaviour plus a variation — a single rule per track would make every sync song identical.

New IDs continue each track's numbering. **Retired IDs are never recycled**: saved `.zudio`
logs record rule IDs, so reusing a retired number would make an old song's log misreport
itself. Rule names deliberately avoid existing instrument names (there is already a "Machine
Kit" instrument in the Motorik drum pool).

### Drums

The corpus splits percussion cleanly into two tiers: one near-continuous timekeeping voice at
~3.3 notes/beat with 18–20% rest, and a set of accent voices at 0.27–0.98 with 76–93% rest.
Every voice is a **single pitch** with `cell 2` — an every-other-step figure. The two rules are
"with a timekeeper" and "without one".

**MOT-DRUM-013 "Sequenced Timekeeper"** — one dense voice plus sparse accents.

*Implementation.* Four independent single-pitch voices, each on a fixed step set repeated
identically every bar:
- **Timekeeper** — on **all eight even steps**, the ~3.3 notes/beat voice. Per song it either
  stays on the closed hat (42) throughout, or splits across two hat voices — closed hat on the
  beats, pedal hat (44) on the "and" steps — at 65% split / 35% single. Same eight positions
  and the same density either way. The split is the more faithful reading as well as the more
  listenable one: The Robots spreads its percussion over eight separately sequenced single-pitch
  tracks, two of them hats.
- **Kick (36)** — steps 0 and 8.
- **Snare (38)** — step 8 only. The measured snare density is 0.54 notes/beat, far below a backbeat.
- **Accent** — tom (45) or rim (37), two steps drawn once from {2, 6, 10, 14} and held all song.

`durationSteps: 1`, **no fills anywhere** including section boundaries.

**Velocities are accented, not flat** — step 0 at 90, the other beats at 84, the "and" steps at
60, kick 92, snare 84, accent 72. The corpus reads as flat velocity, but the Evidence Base lists
that as a caveat of the fan transcriptions rather than a property of the records, and a step
sequencer has a per-step accent control. Implementing the flat reading literally reproduced a
measurement artefact: eight identical hits a bar with no dynamic shape is fatiguing however
authentic the placement is. The accent is a sequencer's, not a drummer's — it never swings, and
the hi-hat gradient that gives normal Motorik its human groove stays out.

*Implementation note.* Both rules bypass `DrumGenerator`'s bar loop, which would otherwise add
section crashes and intro/outro variants; `DrumVariationEngine` runs in its restricted sync
form. Measured output: Sequenced Timekeeper 13 hits/bar (3.25 notes/beat against a ~3.3 target)
on 4 pitches; Sparse Accents ~0.6 notes/beat on 3 pitches.

**MOT-DRUM-014 "Sparse Accents"** — no timekeeper at all.

*Implementation.* Three voices, all sparse, total density under 1.5 notes/beat:
- **Kick (36)** — steps 0 and 8, or 0 and 10 (drawn per song).
- **Snare (38)** — step 8, every **second** bar only.
- **Accent** — a tom or rim on a single step drawn from {6, 14}, every fourth bar.

The space is the point. This is the rule that makes a sync song feel mechanical rather than
driven, and it is the furthest departure from current Motorik drums.

### Bass

Two measured behaviours: a tiny locked cell that never stops (3 pitch classes, `cell 3`, no
dropouts), and longer runs over a restricted vocabulary that do stop (4–5 pitch classes,
statements of 30–120 notes, silence ratio 0.2–0.4:1).

**MOT-BASS-026 "Locked Micro-Cell"** — for the Sequence Lock sync.

*Implementation.* A cell of **3 or 4 steps** using only **3 pitch classes** (chord root, fifth,
octave), drawn once per song and repeated with no variation. Register MIDI 29–48, density
0.7–1.0 notes/beat, `durationSteps: 2`, velocity 80. **Never rests** within its active bars —
the measured source has zero dropouts.

**MOT-BASS-027 "Restricted Run"** — for the Rhythm Section sync.

*Implementation.* **4 or 5 pitch classes** drawn from the chord, register MIDI 27–43.
Density 1.1–1.2 notes/beat. Emits in **long statements of 30...120 notes**, then rests
**0.2...0.4 × the statement span**. In the Rhythm Section sync, at least half its onsets
must coincide with `MOT-DRUM-013`/`014`'s kick steps.

### Bass — 4-bar cells, not one cell per song

**The corpus distinguishes its drum machine from its bass, and we had not.** In The Robots the
percussion voices are as rigid as the design assumed — `bassdrm2` holds one rhythm for 97% of
bars, `ophihat1` for 99%, each on a single pitch. But `elbass1`, the electric bass, uses **23
distinct rhythms over 90 bars**, 39 bar patterns and 10 pitch classes, and its most common
rhythm appears in only **17%** of bars. Its mean run of truly identical consecutive bars is 1.1.

Read bar by bar, that variation is not random. It is **4-bar cells**:

- an extra attack at the top of the group's first bar
- the last note dropped on the fourth bar, so the cell breathes before it restarts
- a genuinely different cell every four bars, returning to an earlier one later
- density swinging between cells, from 8-note eighths to 13-14 note near-continuous sixteenths

`MOT-BASS-025` and `MOT-BASS-026` had taken the percussion character instead, measuring at 96%
and 98% one rhythm — the two most monotonous bass lines in the style. Both now carry the four
behaviours above: an opening attack on beat 2 of each group, the turnaround on the fourth bar,
a moving accent (one group in three accents beat 3 instead of the downbeat), and two or three
cells alternated at 4-bar boundaries.

Measured over 2,500 songs, most common rhythm as a share of bars:

- `MOT-BASS-025` Electro Pump — 96% to **30%**, and 8.5 to **39.5** distinct bar patterns,
  which is `elbass1`'s figure exactly
- `MOT-BASS-026` Locked Micro-Cell — 98% to **53%**. Still the most rigid of the five, which
  is the rule's character; it is no longer the same bar for a whole song.

`MOT-BASS-013`, `015` and `027` already varied (34-50%) and are untouched. `MOT-BASS-015` at
34% is the closest of the originals to the corpus.

Caveat: these are fan transcriptions with hard quantisation, and `elbass1` contains doubled
onsets that are probably octave doubling or transcription noise, so treat 23 rhythms as
indicative. The 4-bar cell structure is visible directly and does not depend on it.

### Rhythm

**MOT-RTHM-014 "Two-Note Lock"** — the most extreme measurement in the corpus: a 4-step cell
over **2 pitch classes** carrying 2,321 notes at density 3.84 with only 28% rest.

*Implementation.* A cell of **2 or 4 steps** using **2 or 3 pitch classes only**, repeated with
**no variation for the entire song**, transposing with the chord but never changing shape.
Register MIDI 44–70, density 3.0–4.0, `durationSteps: 1`, velocity 80. Three is excluded because
it does not divide into 16 and would phase across the barline, which contradicts the locking
requirement below.

**The degrees are drawn, not fixed.** The root always leads — it is what anchors the cell to the
chord — and the remaining one or two are drawn from the fifth, octave, third and fourth. Taking
them in a fixed order made every song root+fifth or root+fifth+octave, so the rule had two
pitch vocabularies in total and every Two-Note Lock song was a variation on the same drone.
Drawing them yields fourteen, including root+third, root+fourth and root+2nd+fifth.

A cell may drop one slot to a rest — one of three positions in a 4-step cell (50%), or its
offbeat in a 2-step cell (35%), which takes density to the bottom of the band.

**Every offset is snapped onto the scale.** A fixed interval above the chord root is not
diatonic in every mode — a minor third above the root is G natural in E Lydian, where the scale
has G# — and three of `MOT-RTHM-015`'s six offsets were non-diatonic in that key. Nothing
downstream catches it either: `HarmonicFilter`'s clash pass covers only the two leads and never
examines Rhythm's pitches. Snapping keeps the intervallic shape as close as the scale allows
while guaranteeing the notes belong; a restricted vocabulary is the point, a wrong one is not.
`MOT-BASS-026` and `MOT-BASS-027` are snapped for the same reason.

Because cell length divides evenly into 16, it **locks to the barline** rather than phasing.
That is the opposite of Kosmic Space's sequencer and is intentional: Kraftwerk's rigidity comes
from perfect alignment, Jarre's motion from drift.

**MOT-RTHM-015 "Paired Sequencer"** — the doubling habit, measured twice (Autobahn's `ch0`/`ch1`
are identical; Computer Love's `ch4`/`ch5` near-identical).

*Implementation.* A **6-pitch-class** cell, register 53–77, density 2.6–3.1, rest ~50%. When
Lead 2 draws `MOT-LD2-011`, the two form the pair — same cell, opposite pan, different
instrument. When Lead 2 does not, this plays alone.

### Lead 1

Both Kraftwerk Lead 1 rules build their line from **closed cells** measured in the corpus by
`tools/kraftwerk_lead_phrases.py`, rather than from a per-note random walk.

**The finding.** Across all three transcriptions, the figures that recur are short and their
intervals **sum to zero** — the figure returns to the pitch it began on, so the line cycles in
place instead of wandering:

- *The Robots* "steampad": `[+5 +3 -8]` ×204 — a fourth up, a minor third up, a minor sixth back down
- *Autobahn* ch2: `[+9 -4 -5]` ×20 and its inversion `[-9 +5 +4]` ×19
- *Computer Love* ch0: `[+5 -2 +4 -7]` ×8
- *Autobahn* ch10: `[-12 +0 +12]` ×77 — octave oscillation
- *Autobahn* ch6: `[+0 +0 -5 +5]` ×27 — a repeated note, then a fourth away and back
- *The Robots* "steeldrm": `[+0 -2 +0 +2]` ×40 — neighbour-tone oscillation

Two corrections to earlier assumptions come out of this. Kraftwerk leads are **not stepwise**:
4–33% of motion is a step and the median interval is a perfect fourth, so wide intervals are
correct here. What makes them melodic rather than shrill is that **every leap is answered**.
And **repeated notes are structural** — `+0` is among the most common intervals.

**How it is built.** A cell is drawn once per song from `kraftwerkCells`, anchored to start on a
chord tone with the whole figure inside the register band, and realised as actual pitches. Each
pitch snaps to the nearest usable pitch class, but only when that is within two semitones —
two notes snapping in opposite directions each shift their shared interval, and an unbounded
snap turns a cell's octave into a minor tenth. Notes outside the band are folded by octaves, not
clamped; clamping collapses them onto the edge pitch and breaks the closure exactly where it is
most exposed.

Variation follows the corpus: *The Robots* states `[+5 +3 -8]` then `[+2 -7 +5]`, each interval
nudged with the sum unchanged. `varyCell` nudges one interval and takes the same amount back out
of another, never touching index 0 — that entry is the cell's own starting offset, which the
realiser skips, so changing it moves nothing while its compensating partner still moves, leaving
the cell open. Restatements keep the same anchor 75% of the time; a transposition, when it
happens, lands on a chord tone.

**Three places the figure can quietly come open**, each found by ear first and then measured:

- **The closing interval must not be emitted.** `[0 +5 +3 -8]` is the three notes 0, +5, +8
  cycling — the final interval is the return home, which the *next* statement's first note
  already supplies. Emitting it too puts a repeated note at every seam, which is what produced
  bars of `82 81 77 82 | 82 81 77 82` and drove repeated-note moves to 32% of a part.
- **Variation may only touch the interior intervals.** Index 0 is the starting offset and the
  last is the return home, and the realiser emits neither, so nudging either moves nothing
  while its compensating partner still moves — leaving the cell open and letting the figure
  climb. Both ends caused a 15-semitone leap in a part whose widest cell interval is an octave.
- **Re-anchoring is a transposition, not a jump.** Left free to pick any chord tone in a
  19-semitone band, a mid-run move reads as the line teleporting; it is held to a fifth of
  where the line already was.

**Measured over 800 Europe songs:** 9.0 distinct pitches per lead, 9% repeated-note moves
(corpus 2–31%), stepwise motion 24% and median interval 5.5 semitones — both inside the corpus
range — and end-to-end pitch drift with a median of 1.6 semitones and a worst case of 5.8.
`MotorikSyncTests` pins the leap ceiling and the drift bound.

**Phrase endings are shaped in a final pass**, taking two ideas from the Chill lead
(`applyLastNoteDuration` and `applyLastNoteFlip`), which solve the same problem for a solo:

- A note followed by half a bar or more of silence **holds** — 10 to 20 steps rather than the
  2 to 3 the body runs at. A statement that stops on a blip before four bars of nothing sounds
  cut off rather than finished. Measured: 11.3 steps at endings against 2.6 elsewhere.
- That note **resolves onto the tonic** 45% of the time, but only where the harmony admits it,
  only within five semitones, and never by a wider interval than the phrase was already making
  — resolving is a settling gesture, and reaching the tonic by a bigger leap defeats it.
  Measured: 50% of endings land on the tonic, counting those that were already there.

The same pass clamps every note to end before the next begins. Long Run's legato branch could
draw a duration longer than the gap it sat in, overlapping the following note — 412 times
across 600 songs — which muddies a line meant to read as a single voice. Chill assigns its
durations last for exactly this reason. Now zero.

**The lead has to stop, and it has to move.** Two failures measured in a finished song:
30 consecutive sounding bars with no rest, and eleven strikes of one pitch in a row.

- A breath inside a run opens into **two to four bars one time in three**. At one in four with
  a two-bar ceiling, a thirteen-bar run had no real gap in it.
- A pitch may be struck **twice** — several cells repeat their first note, which is how
  Autobahn's `[+0 +0 -5]` goes — but a third strike in a row is dropped and the space left
  instead. The gap that opens then feeds the phrase-ending pass, so the pair before it holds.
  A tonic resolution never lands on the pitch just played, which would undo this.

Measured over 600 songs: longest same-pitch run 3, longest unbroken stretch 14 bars, and the
lead sounds in 32% of bars with multi-bar gaps averaging 5.7 bars.

The 8-step boundary is shared: the generator ends a phrase there, and `MotorikSyncTests`
measures leaps only below it, so a jump across a rest counts as a new phrase rather than as a
leap within a line.

Long Run draws a fresh cell for 40% of its runs, so a song states two or three related ideas
across its length rather than one figure for several minutes.

### Lead 2

Used as an additional sequencer voice rather than a second melody, which is how the corpus uses
its extra parts.

Both partner rules double at **velocity 44** against Rhythm's 80 — roughly 45% below it once
the velocity arc has shaped both. The double is a shadow of the sequencer, not a second voice:
at the original 72 it blurred the very line it was doubling.

**MOT-LD2-011 "Counter Sequencer"** — fires only when Rhythm draws `MOT-RTHM-015`.

*Implementation.* The same cell as Rhythm, **offset by 2, 4 or 6 steps** — drawn per song, since
a half-beat, a beat and a beat-and-a-half are three distinctly different feels from the one rule
— on a different instrument, panned opposite. Two near-identical lines slightly displaced is the
measured arrangement.

**MOT-LD2-012 "Octave Unison"** — fires only when Rhythm draws `MOT-RTHM-014`.

*Implementation.* Generates no rhythm. Re-emits Rhythm's events at the same `stepIndex` and
`durationSteps`, transposed **+12 or +24** (70/30 per song), on a different instrument. Strict
unison — no thirds, no offset. The machine quality comes from exact lock.

### Texture

Texture is in **one** of the three groups, Sequence Lock. It is also the one member that plays
**through** a dropout window, alongside the never-synced Pads and whatever else is outside the
group: with it silenced too, a four-track group leaves only two parts in the window and the drop
reads as empty rather than as a change. It does not become relentless as a result — the rules
are sparse by construction and each song carves two 12-16 bar windows where the part is absent
entirely. The corpus shows a
clear textural behaviour: isolated single notes scattered across a very wide register (spans of
20–94 and 35–107 semitones) at high silence ratios (7:1 to 31:1).

**MOT-TEXT-009 "Wide Scatter"**

*Implementation.* Isolated events in a wide space, pitches drawn from chord tones. Velocity 72.

**Three things are drawn once per song**, because with a single character available every Wide
Scatter song sounded like the last — the same full-register scatter of the same tiny blips, and
the register *shape* is the dimension the ear notices:

- **Register band** — 36-64 (a dark undertow, 30%), 58-88 (glassy and distant, 30%), or the full
  36-88 (40%). The corpus measured spans of 20-94 *and* 35-107 semitones, so the span varied
  there too.
- **Sustain** — blips of `durationSteps: 1...3`, or in 35% of songs long tones of **8...16**. The
  gap scales with the note, so a sustained song is one long voice every few bars rather than a
  drone.
- **Dyads** — in 25% of songs, an occasional octave or fifth struck with the note at velocity 64.
  It breaks the uniformity of "always exactly one note" without adding density.

**The two measurements conflict, and the ratio wins.** Density 0.4–0.7 notes/beat and a
silence-to-statement ratio of 7:1 or wider cannot both hold when notes are 1–3 steps long: the
density figure forces a gap of about eight steps, which is 3.8:1. Built to the density figure
this rule put a note in every bar of the song and read as a constant presence — evenly thin is
not the same as sparse, and the ear hears the regularity rather than the space. Built to the
ratio it lands near 19:1, mid-range of the measured 7:1–31:1, at about 0.12 notes/beat. Gaps are
14–30 steps, and one in six stretches to two-to-four bars so the part breathes instead of
ticking. A sustained song stretches the gap to 48–96 steps to hold the same ratio.

**Two rest windows of 12–16 bars** are drawn per song, in both texture rules, where the part is
simply absent. Sparse note-to-note is not the same as absent: without them Texture was present
in some form for the whole song and stopped registering as colour. The windows avoid the sync's
dropout, which is the one place Texture is wanted.

**MOT-TEXT-010 "Sparse Punctuation"**

*Implementation.* Very rare events at structural positions: **2...3 notes**, then **300...400
steps** of silence — measured ratio 12:1 with twelve dropouts across a song. Place at section
boundaries rather than randomly. Register 52–82. `durationSteps: 4...8`, velocity 68.

### Rule selection within a sync

Every track with more than one option needs a split. These are the weights:

- **Drums** (Rhythm Section only) — `MOT-DRUM-013` Sequenced Timekeeper 60%,
  `MOT-DRUM-014` Sparse Accents 40%.
- **Rhythm** (Sequence Lock, Machine Voice) — `MOT-RTHM-014` Two-Note Lock 55%,
  `MOT-RTHM-015` Paired Sequencer 45%. This draw also determines which Lead 2 partner is
  available.
- **Lead 1** (Machine Voice only) — `MOT-LD1-021` Short Statement 60%,
  `MOT-LD1-022` Long Run 40%.
- **Texture** (all sync groups) — `MOT-TEXT-009` Wide Scatter 65%,
  `MOT-TEXT-010` Sparse Punctuation 35%.
- **Lead 2** — partner 65% / silent 35%, as above.

**Bass draws from four options per sync**, not one. The three existing Kraftwerk bass rules
are reused rather than duplicated — they are already written, already good, and reusing them
is what gives Bass the variety the other tracks get from having two new rules each:

- **Rhythm Section** — `MOT-BASS-027` Restricted Run 35%, `MOT-BASS-013` Kraftwerk robotic 25%,
  `MOT-BASS-015` Kraftwerk driving 25%, `MOT-BASS-025` Electro Pump 15%.
- **Sequence Lock** — `MOT-BASS-026` Locked Micro-Cell 40%, `MOT-BASS-013` 25%,
  `MOT-BASS-015` 20%, `MOT-BASS-025` 15%.

`MOT-BASS-025` is currently Arcade-only; using it inside a base-Motorik sync extends its
reach without changing its behaviour or its Arcade weighting.

Note the **redistributed base-Motorik bass weights above apply only to non-sync songs**.
When a sync fires, Bass draws from the lists here instead.

---

### Instrument subsets

Sync tracks draw from a restricted subset of the **existing** Motorik pools. No pool is
reordered, extended or renamed — this uses the same `instrumentPickPool` /
`instrumentPickPoolStatic` mechanism Arcade already uses to return an index array, so the
surrounding pool-selection code is untouched.

The lists live in one place, on `MotorikSync.instrumentSubset(forTrack:)`, read by both pick
pools and by `sanitiseSyncInstruments`. Lead 2's subset applies whenever Rhythm is synced: it
only partners on a 65/35 draw made during generation, but applying the subset to both outcomes
is harmless, since a silent Lead 2 has no audible instrument either way.

The problem being solved: the Rhythm pool contains three guitars and an acoustic bass, and a
rigid two-pitch-class cell played on Fuzz Guitar is a guitar riff, not a sequencer.

- **Rhythm** `[3, 6, 9]` — Doctor Solo, Synth Bass 3, Electric Piano 1. Excludes the three
  guitars, both acoustic basses, Charang and Harpsi Pad. (Clavinet was removed from the Motorik
  pool entirely in build 131 — its sound is absent from `Zudio.sf2`, so it played silent.)
- **Bass** `[0, 1, 4, 5, 6]` — Moog, Lead Bass, Mean Saw Bass, Techno Bass, Synth Bass 1.
  Excludes Rock Bass and Elec Bass.
- **Drums** `[2, 3]` — Dance Drums, Machine Kit. Electronic kits only.
- **Lead 1** `[0, 1, 3, 5, 6, 7]` — Mono Synth, Saw Lead 3, Polysynth, Square Lead, Synth Lead,
  Saw Stack. Weights Mono Synth down to roughly one song in twelve, and never two running, since it reads thin where Polysynth and Saw Stack read full; excludes Soft Brass, which reads as orchestral against a rigid sequencer; and Chiff
  Lead, whose breathy attack blurs the note placement the rules depend on.
- **Lead 2** `[0, 2, 4, 5, 6, 7]` — Polysynth, Moog, Square Lead, Synth Lead, Saw Lead,
  5th Saw Wave. Excludes Elec Guitar and Brightness.
- **Texture** `[0, 3, 4, 6, 8, 9]` — Fifths Lead, FX Atmosphere, FX Echoes, Interference,
  Metal Pad, Ice Rain. Excludes Guitar Fdbk and the two warm pads, which suit sustain rather
  than scatter.

Tracks outside the drawn sync keep their full pools.

---

### Section Dropout — a sync behaviour, not a rule

The most distinctive measured feature, and it spans tracks so it belongs to the sync.

*Implementation.* When any sync is drawn, build a dropout schedule:
- **Two windows**, at roughly **25% and 65%** through the song (the measured positions),
  snapped to multiples of 8 bars.
- Lengths drawn independently: **4...14 bars**.
- During a window, **every track in the drawn sync goes silent together — including
  Texture, and Lead 2 when partnering**. Tracks outside the sync keep playing, which is what
  makes the drop read as a section change rather than the song stopping.
- Never drop in the first 16 bars or the last 8.

## Title Signal

When a sync fires, the song title takes a German-flavoured affix so the character is
visible in the Songs list, not only audible. Applies **only** when a sync is active —
non-sync Motorik titles are unchanged.

`TitleGenerator` already has the machinery: `motorikCities`, `motorikCityPrefixes` and a
German-noun-compound pattern. This adds two word banks and one formation step.

**Prefixes** — `Der`, `Die`, `Das`, `Neo`, `Elektro`, `Trans`, `Ultra`, `Hyper`, `Mikro`,
`Tele`, `Zentral`, `Stahl`, `Nacht`, `Schnell`, `Fern`, `Tekno`

**Nouns and suffixes**, grouped by field:

- *Industry* — `Werk`, `Maschine`, `Motor`, `Apparat`, `Anlage`, `Getriebe`, `Turbine`,
  `Dynamo`, `Montage`, `Automat`
- *Energy* — `Strom`, `Energie`, `Funke`, `Blitz`, `Netz`, `Leitung`, `Kontakt`, `Magnet`
- *Transport* — `Bahn`, `Fahrt`, `Strecke`, `Gleis`, `Tunnel`
- *Signal* — `Signal`, `Impuls`, `Frequenz`, `Kanal`, `Welle`, `Takt`, `Echo`
- *Abstract* — `Form`, `System`, `Struktur`, `Muster`, `Licht`, `Zeit`

Words are kept recognisable to an English speaker — either cognates (`Motor`, `Signal`,
`System`, `Magnet`) or short and concrete (`Werk`, `Netz`, `Blitz`, `Licht`). Anything that
reads as English rather than German is out, which is why `Sender` was dropped.

**Formation**, drawn per song. **Exactly one affix — a prefix or a suffix, never both.**
A title is never wrapped on both sides ("Elektro Pulse Werk" is wrong):

- *Prefix + existing title* (45%) — "Elektro Pulse", "Neo Grid", "Stahl Circuit"
- *Existing title + suffix* (25%) — "Signal Werk", "Drift Bahn", "Pulse Takt"

The remaining two patterns **replace** the generated title rather than affixing to it, so the
one-affix rule does not apply — they are standalone German titles:

- *German compound* (20%) — prefix joined to a noun, no space: "Stahlwelle", "Impulswerk",
  "Fernsignal"
- *Article + noun* (10%) — "Der Apparat", "Die Anlage", "Das Getriebe"

**One guard.** Compound formation can accidentally produce a real Kraftwerk song title —
`Auto` + `bahn` being the obvious case. Keep a small blocklist of actual titles and re-draw on
a hit. The same principle as the rules: evoke the idiom, never reproduce the work. For that
reason `Auto` and `Radio` are deliberately absent from the prefix bank, since both compound
straight into real titles.

---

## What Is Not Changing

- **Instruments.** No new samples and no pool extensions — a sync draws a restricted
  *subset* of each existing Motorik pool, through the same mechanism Arcade already uses.
- **Effects, mode, harmony, structure.** All inherited from base Motorik. Constraining the
  progressions would pull Europe away from Motorik rather than colouring it.
- **Tempo and titles** are the two exceptions: a sync song sits in the 120-132 band and takes
  a German-flavoured affix. Both are sync-only, and base Motorik is untouched by either.
- **Noir and Arcade.** Untouched. Sync groups apply to base Motorik only, so a song is
  never both Europe and Noir, or both Europe and Arcade.
- **Neu! identity.** Protected deliberately — the Hallogallo rule's weight doubles rather than
  being diluted.

---

## How It Fits Into Generation

The sync is drawn once per song, on a stream derived from the seed so it does not shift any
other draw. Everything below follows from that one value.

1. **Sync roll** at frame-generation time — none 67.2 / Rhythm Section 13.1 / Sequence Lock 11.3 /
   Machine Voice 8.4, of base Motorik songs. Set together with the substyle roll, since the
   two only mean anything in combination: the target is the four-way split of the whole style,
   regular 41 / Noir 20 / Arcade 19 / Europe 20.
2. **Tempo band.** A sync song is remapped from base Motorik's 126-154 into **120-132**,
   centred on 125. The corpus measures 120-128, and at Motorik's usual pace a sequencer on top
   still reads as Neu!. The existing triangular spread is compressed rather than clamped, so the
   distribution keeps its shape instead of piling onto the ceiling, and it is applied before the
   bar count is chosen so songs keep their intended duration. Non-sync songs are untouched.
3. **Rule pools.** Each generator checks whether its track is in the drawn sync and, if so,
   draws from the Kraftwerk pool instead of normal rotation.
4. **Instrument subsets**, held on `MotorikSync.instrumentSubset(forTrack:)` so the pick pool
   and the sanitiser share one definition.
5. **Lead 2** is resolved after Rhythm, since both its rules derive from Rhythm's actual events.
6. **Fills only at the dropout edges.** In every sync song, including those where Drums is
   not a member, the drum pass runs in a restricted form: no periodic every-eighth-bar fills, no
   generic instrument-entrance fills, none at ordinary section boundaries. A sync fills at one
   kind of moment only — the bar before the whole sync drops out, and the bar before it
   returns — held to 1 or 2 beats, never 3, averaging under two fills a song.

   Entrance fills in particular have to go: Texture and Lead 1 are 88-95% rest in a sync, so
   a rule that fires whenever a part returns fires almost continuously. The dropout schedule is
   decided after this pass runs, so the bars come from `syncDropoutWindows` and are handed in.

   **The log reads the drum track, not the fill logic.** `buildStepAnnotations` mirrors the
   normal drum pass rather than the engine's output, and `fillBeats` infers a fill's length from
   where the hi-hat stops — which measures every bar as a 3-beat cascade on kits that have no
   continuous hat, as neither Kraftwerk kit does. For a sync the annotation therefore keys on
   toms the kits never play. Crash is not a marker: it also lands on the first bar of a section
   as an accent.

7. **Section dropout** drops the whole sync together, twice a song.
8. **Repeat guard** caps any synced track at 12 identical bars.
9. **Title affix** and the `Sync` log line make the song identifiable without listening.

### Instrument enforcement needs two halves

The pick pool alone is not sufficient, and this is worth stating plainly because it is not
obvious: **only two instruments are re-picked per song.** The other five carry over from the
previous song untouched. A sync that only consulted the pick pool would routinely inherit
Fuzz Guitar on Rhythm — a guitar riff rather than a sequencer, the exact case the subsets exist
to prevent.

So the sync has a **sanitiser** as well, `sanitiseSyncInstruments`, which forces every
member track into its subset. Noir and Arcade each have one for the same reason. Both the
instance path and the static Endless-mode path need it.

### Repeat guard — 12 bars

The corpus behaviour is a figure repeated with **no** variation, and the rules implement that
literally. Over a 128-bar song that gives stretches of 30-50 identical bars: true to the source,
and tiring.

A synced track therefore plays at most **12 identical bars** before the pattern takes a slight
change — one note displaced by an octave, or one note dropped. The cell is not rewritten and the
groove does not move. Percussion only ever drops a hit, never shifts an octave, since a drum
note selects the instrument rather than a pitch. Empty bars reset the count, because a dropout
window already breaks the repetition. Drums are covered in every sync song, member or not,
because the variation engine that would otherwise break up a long run is skipped throughout.

The guard runs on Rhythm *before* Lead 2 derives from it, so the partner rules inherit the
variation rather than drifting out of unison.

This is a deliberate departure from the measured behaviour, chosen for listenability.

### Which passes a sync skips, and why

- **`ArrangementFilter`** — spotlights one track and thins the others independently, which is
  the opposite of a sync. It also breaks `MOT-LD2-012`'s strict unison by thinning Rhythm but
  not Lead 2. The section dropout is the sync's arrangement device instead.
- **`DrumVariationEngine`** — runs in a restricted form rather than being skipped: fills only
  at dropout edges, and no cymbal run variations, since the 12-bar repeat guard already covers
  long identical runs. Bass locking is skipped when Bass is a sync member, because
  `MOT-BASS-027` already takes every kick and `MOT-BASS-026` is a cell that must not be
  perturbed.
- **`PatternEvolver`** — skipped for `MOT-BASS-026` only. That rule alone is "drawn once and
  repeated with no variation"; the other three options in the sync bass pool are pre-existing
  rules that have always evolved, and they still do.

### Rule ID conventions

New IDs continue each track's existing numbering: `MOT-DRUM-013/014`, `MOT-BASS-026/027`,
`MOT-RTHM-014/015`, `MOT-LD1-021/022`, `MOT-LD2-011/012`, `MOT-TEXT-009/010`. Note the texture
prefix is `MOT-TEXT-`, matching `MOT-TEXT-001`...`008`.

**Retired IDs are never recycled.** A saved `.zudio` records rule IDs, so a reused number would
make an old song's log misreport itself.

### Two places the measurements could not be taken literally

- **`MOT-RTHM-014` uses a 2- or 4-step cell.** Three does not divide into 16, so a 3-step cell
  would phase across the barline — contradicting the locking requirement, which is the musical
  point.
- **`MOT-BASS-027` takes every kick rather than half its onsets.** "At least half its onsets
  coincide with kick steps" cannot hold at 1.1-1.2 notes/beat: a bar has two kick steps but
  ~4.5 bass onsets. Covering every kick is the intent — the rhythm section reading as locked.

Cells hold the specified pitch-class counts, but the parts transpose with the chord, so the
absolute count measured over a whole song is necessarily higher. Song-average densities read
below target for the same reason statement/rest shapes and dropout windows exist; per active bar
they sit in band.

---

## Verification

Pinned by `MotorikSyncTests` and `DeterminismTests`:

- the sync survives every `SongState` copy method, and the roll is deterministic
- Noir and Arcade never draw a sync; the distribution matches none 67.2 / Rhythm Section 13.1 / Sequence Lock 11.3 / Machine Voice 8.4
- every synced track draws a Kraftwerk rule, and Lead 2 either partners or rests
- `MOT-LD2-012` never drifts off Rhythm's grid
- no synced track exceeds 12 identical bars
- sync tempo stays within 120-132 and the base band stays 126-154
- sync fills occur only at dropout edges, at most four a song
- every synced note is in key: Rhythm exactly, the other tracks within 0.4%

`RetiredRuleReloadTests` covers the retired bass rules: still playable when a saved song names
one, absent from the base pool, and reachable from Noir or Arcade.

---

## Open Questions

- **Sync share.** 32.8% of base Motorik, 20% of all Motorik. If Kraftwerk-flavoured songs feel
  too frequent, reduce the three weights proportionally rather than removing a group — but the
  substyle roll has to move with them, or the four-way split stops adding up.
- **Whether Lead 1 has enough reach.** It sits in two groups and lands in 10.4% of Motorik
  songs, which puts its two rules in the same range as an ordinary Lead 1 rule rather than the
  4-to-6x rarer they were when Machine Voice was their only route.
- **Whether Machine Voice needs its own instrument treatment.** Unison doubling between Rhythm
  and Lead 1 may sound thin without a timbral difference between them.
