# Motorik Kraftwerk Flavour — Design Plan

Status: **design only, not implemented.** No code, README or change-log changes until after
the Oct 1 2026 App Store release of 2.5 (build 130).

Scheduled **before** [kosmic-space-plan.md](kosmic-space-plan.md). This is a surgical change
to a style that already works, not a new substyle — smaller, lower risk, and it improves
output that ships today.

Every decision below is settled, and the rule values are measured rather than estimated —
see the Evidence Base.

---

## What This Is — and Is Not

**Not a substyle.** Motorik already has Noir and Arcade. A third would fragment the style and
force a fourth `displayStyleName` case, a fourth set of pool restrictions and a fourth
sanitiser.

Instead: **a cluster of tracks within a regular Motorik song occasionally adopts Kraftwerk
rules, while the rest draw from normal rotation.** No new flag on SongState, no UI change, no
new substyle name. A Motorik song simply sometimes leans machine-like.

The aim is to widen what base Motorik can sound like, not to carve a new territory out of it.

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

## The Cluster Mechanism

**The core design decision.** Track selection is **coupled, not independent.**

Drawing per track independently would produce incoherence rather than flavour: a Kraftwerk
bass underneath a busy Neu!-style drum pattern reads as a Motorik song with an odd bass, not
as Kraftwerk. The character depends on parts agreeing with each other.

So: **one cluster is drawn per song**, and only those tracks use Kraftwerk rules.

**The roll happens inside base Motorik only**, after the existing substyle roll has already
excluded Noir and Arcade. So these percentages are of base Motorik songs, not of all Motorik
songs — at the current 60% base share, a cluster fires in about 12% of Motorik output overall.

- **No cluster — 80%.** Normal Motorik, unchanged. This must remain the common case.
- **Rhythm Section cluster — 8%.** Bass + Drums. The machine rhythm section: rigid kick
  placement with a bass locked to it.
- **Sequence Lock cluster — 7%.** Bass + Rhythm. A repeating cell shared between the two,
  the sequencer-driven texture.
- **Machine Voice cluster — 5%.** Rhythm + Lead 1, with unison or octave doubling between
  them. This is the most identifiable Kraftwerk gesture and the least represented in Zudio
  today.

**Texture joins whichever cluster is drawn.** It is not a member of any one cluster — the
scattered wide-register behaviour suits all three equally, and Texture is a supporting role
rather than part of the rhythmic interlock. So whenever a cluster fires, Texture also draws
from `MOT-TEX-001/002` instead of normal rotation.

**Lead 2 is locked to Rhythm.** Both Lead 2 rules are partners — one mirrors Rhythm's cell at
a 2-step offset, the other re-emits Rhythm's events at the octave — so neither is meaningful
without Rhythm in the cluster. Its behaviour is therefore fully determined:

- **Rhythm in the cluster** (Sequence Lock, Machine Voice): Lead 2 takes the partner rule
  matching Rhythm's draw — `MOT-RTHM-014` pairs with `MOT-LD2-012`, `MOT-RTHM-015` pairs with
  `MOT-LD2-011` — **or rests entirely**. Split 65% partner / 35% silent. It never draws a
  normal Motorik rule here: a melodic Lead 2 over a rigid two-pitch-class sequencer is exactly
  the incoherence the cluster design exists to prevent. Variety comes from presence versus
  absence, not from mixing vocabularies.
- **Rhythm not in the cluster** (Rhythm Section): Lead 2 draws from normal Motorik rotation.
  There is no sequencer for it to clash with, and a melodic line over a machine rhythm section
  is a legitimate hybrid — the "some but not all" principle working as intended.

The 65/35 split reflects the corpus: doubling appears in two of the three files, so it should
be common but not universal.

Effective track counts per song: **Rhythm Section** = Bass + Drums + Texture; **Sequence Lock**
= Bass + Rhythm + Texture (+ Lead 2 when partnering); **Machine Voice** = Rhythm + Lead 1 +
Texture (+ Lead 2 when partnering).

All remaining tracks draw from normal Motorik rotation as they do now.

**Log the cluster.** When one fires, emit a log line naming it, so a song's character can be
identified by reading its log rather than by guessing. Follow the existing convention used for
substyle and rule reporting.

**Implementation.** One roll at frame-generation time, thresholds in order, exactly as the
Motorik substyle roll already works. The result is passed to the generators as an enum, and
each generator checks whether its own track is in the drawn cluster before choosing a rule
pool. No SongState flag is needed if the cluster is derived from the song seed in each
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

- `MOT-BASS-001` Root Anchor — 8%
- `MOT-BASS-002` Motorik Drive — 14%
- `MOT-BASS-003` Crawling Walk — 5%
- `MOT-BASS-004` Neu! Hallogallo lock — 8% *(raised from 4%)*
- `MOT-BASS-008` Moroder Pulse — 11%
- `MOT-BASS-009` Vitamin Hook — 7%
- `MOT-BASS-011` Quo Drive — 4%
- `MOT-BASS-012` Moroder Chase — 8%
- `MOT-BASS-013` Kraftwerk robotic bass — 10% *(raised from 4%)*
- `MOT-BASS-014` McCartney melodic drive — 9%
- `MOT-BASS-015` Kraftwerk driving bass — 16% *(raised from 11%)*

Sums to 100%. Net effect: the two existing Kraftwerk bass rules rise from 15% combined to 26%,
and Neu! doubles — so base Motorik gets **more** characterful in both directions, not just one.

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
behaviour plus a variation — a single rule per track would make every cluster song identical.

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
- **Timekeeper** — closed hat (42) or wood block (76), drawn per song, on **all eight even
  steps**. This is the ~3.3 notes/beat voice.
- **Kick (36)** — steps 0 and 8.
- **Snare (38)** — step 8 only. The measured snare density is 0.54 notes/beat, far below a backbeat.
- **Accent** — tom (45) or rim (37), two steps drawn once from {2, 6, 10, 14} and held all song.

Velocity 80 flat, `durationSteps: 1`, **no fills anywhere** including section boundaries.

**MOT-DRUM-014 "Sparse Accents"** — no timekeeper at all.

*Implementation.* Three voices, all sparse, total density under 1.5 notes/beat:
- **Kick (36)** — steps 0 and 8, or 0 and 10 (drawn per song).
- **Snare (38)** — step 8, every **second** bar only.
- **Accent** — one tom or block pitch on a single step drawn from {6, 14}, every fourth bar.

The space is the point. This is the rule that makes a cluster song feel mechanical rather than
driven, and it is the furthest departure from current Motorik drums.

### Bass

Two measured behaviours: a tiny locked cell that never stops (3 pitch classes, `cell 3`, no
dropouts), and longer runs over a restricted vocabulary that do stop (4–5 pitch classes,
statements of 30–120 notes, silence ratio 0.2–0.4:1).

**MOT-BASS-026 "Locked Micro-Cell"** — for the Sequence Lock cluster.

*Implementation.* A cell of **3 or 4 steps** using only **3 pitch classes** (chord root, fifth,
octave), drawn once per song and repeated with no variation. Register MIDI 29–48, density
0.7–1.0 notes/beat, `durationSteps: 2`, velocity 80. **Never rests** within its active bars —
the measured source has zero dropouts.

**MOT-BASS-027 "Restricted Run"** — for the Rhythm Section cluster.

*Implementation.* **4 or 5 pitch classes** drawn from the chord, register MIDI 27–43.
Density 1.1–1.2 notes/beat. Emits in **long statements of 30...120 notes**, then rests
**0.2...0.4 × the statement span**. In the Rhythm Section cluster, at least half its onsets
must coincide with `MOT-DRUM-013`/`014`'s kick steps.

### Rhythm

**MOT-RTHM-014 "Two-Note Lock"** — the most extreme measurement in the corpus: a 4-step cell
over **2 pitch classes** carrying 2,321 notes at density 3.84 with only 28% rest.

*Implementation.* A cell of **2, 3 or 4 steps** using **2 or 3 pitch classes only**, repeated
with **no variation for the entire song**, transposing with the chord but never changing shape.
Register MIDI 44–70, density 3.0–4.0, `durationSteps: 1`, velocity 80.

Because cell length divides evenly into 16, it **locks to the barline** rather than phasing.
That is the opposite of Kosmic Space's sequencer and is intentional: Kraftwerk's rigidity comes
from perfect alignment, Jarre's motion from drift.

**MOT-RTHM-015 "Paired Sequencer"** — the doubling habit, measured twice (Autobahn's `ch0`/`ch1`
are identical; Computer Love's `ch4`/`ch5` near-identical).

*Implementation.* A **6-pitch-class** cell, register 53–77, density 2.6–3.1, rest ~50%. When
Lead 2 draws `MOT-LD2-011`, the two form the pair — same cell, opposite pan, different
instrument. When Lead 2 does not, this plays alone.

### Lead 1

Two measured shapes: short compact statements with proportionate silence (4–6 notes over 6–34
steps, ratio 0.9–4.3:1), and long runs followed by very long silences (38–127 notes, then
37–608 steps, ratio 4.8–5.8:1).

**MOT-LD1-021 "Short Statement"**

*Implementation.* Register 65–86, **5 or 6 pitch classes**. Statements of **4...6 notes** over
6...34 steps, then silence of **1.0...4.0 ×** the statement span. Rest ratio lands 88–95%.
`durationSteps: 2`, velocity 80.

**MOT-LD1-022 "Long Run, Long Silence"**

*Implementation.* Register 77–106, 5 pitch classes. A continuous run of **40...130 notes** at
~1.0 notes/beat, then **4...6 × that span** in silence. Typically two or three statements in a
song. This is the rule that makes the lead feel like an announcement.

### Lead 2

Used as an additional sequencer voice rather than a second melody, which is how the corpus uses
its extra parts.

**MOT-LD2-011 "Counter Sequencer"** — fires only when Rhythm draws `MOT-RTHM-015`.

*Implementation.* The same cell as Rhythm, **offset by 2 steps** and on a different instrument,
panned opposite. Velocity 72. Two near-identical lines slightly displaced is the measured
arrangement.

**MOT-LD2-012 "Octave Unison"** — fires only when Rhythm draws `MOT-RTHM-014`.

*Implementation.* Generates no rhythm. Re-emits Rhythm's events at the same `stepIndex` and
`durationSteps`, transposed **+12 or +24** (70/30 per song). Velocity 72, different instrument.
Strict unison — no thirds, no offset. The machine quality comes from exact lock.

### Texture

Texture rides along with **any** cluster rather than belonging to one. The corpus shows a
clear textural behaviour: isolated single notes scattered across a very wide register (spans of
20–94 and 35–107 semitones) at high silence ratios (7:1 to 31:1).

**MOT-TEX-001 "Wide Scatter"**

*Implementation.* **Single notes**, never phrases — one event then a gap. Register spans at
least **40 semitones**, pitches drawn from chord tones across the full span rather than a band.
Density 0.4–0.7 notes/beat, silence-to-statement **7:1 or wider**. `durationSteps: 1...3`,
velocity 72.

**MOT-TEX-002 "Sparse Punctuation"**

*Implementation.* Very rare events at structural positions: **2...3 notes**, then **300...400
steps** of silence — measured ratio 12:1 with twelve dropouts across a song. Place at section
boundaries rather than randomly. Register 52–82. `durationSteps: 4...8`, velocity 68.

### Rule selection within a cluster

Every track with more than one option needs a split. These are the weights:

- **Drums** (Rhythm Section only) — `MOT-DRUM-013` Sequenced Timekeeper 60%,
  `MOT-DRUM-014` Sparse Accents 40%.
- **Rhythm** (Sequence Lock, Machine Voice) — `MOT-RTHM-014` Two-Note Lock 55%,
  `MOT-RTHM-015` Paired Sequencer 45%. This draw also determines which Lead 2 partner is
  available.
- **Lead 1** (Machine Voice only) — `MOT-LD1-021` Short Statement 60%,
  `MOT-LD1-022` Long Run, Long Silence 40%.
- **Texture** (all clusters) — `MOT-TEX-001` Wide Scatter 65%,
  `MOT-TEX-002` Sparse Punctuation 35%.
- **Lead 2** — partner 65% / silent 35%, as above.

**Bass draws from four options per cluster**, not one. The three existing Kraftwerk bass rules
are reused rather than duplicated — they are already written, already good, and reusing them
is what gives Bass the variety the other tracks get from having two new rules each:

- **Rhythm Section** — `MOT-BASS-027` Restricted Run 35%, `MOT-BASS-013` Kraftwerk robotic 25%,
  `MOT-BASS-015` Kraftwerk driving 25%, `MOT-BASS-025` Electro Pump 15%.
- **Sequence Lock** — `MOT-BASS-026` Locked Micro-Cell 40%, `MOT-BASS-013` 25%,
  `MOT-BASS-015` 20%, `MOT-BASS-025` 15%.

`MOT-BASS-025` is currently Arcade-only; using it inside a base-Motorik cluster extends its
reach without changing its behaviour or its Arcade weighting.

Note the **redistributed base-Motorik bass weights above apply only to non-cluster songs**.
When a cluster fires, Bass draws from the lists here instead.

---

### Instrument subsets

Cluster tracks draw from a restricted subset of the **existing** Motorik pools. No pool is
reordered, extended or renamed — this uses the same `instrumentPickPool` /
`instrumentPickPoolStatic` mechanism Arcade already uses to return an index array, so the
surrounding pool-selection code is untouched.

The problem being solved: the Rhythm pool contains three guitars and an acoustic bass, and a
rigid two-pitch-class cell played on Fuzz Guitar is a guitar riff, not a sequencer.

- **Rhythm** `[3, 6, 9, 10]` — Doctor Solo, Synth Bass 3, Electric Piano 1, Clavinet.
  Excludes Guitar Pulse, Crunch Guitar, Fuzz Guitar, Acoustic Bass, Pick Bass, Charang,
  Harpsi Pad.
- **Bass** `[0, 1, 4, 5, 6]` — Moog, Lead Bass, Mean Saw Bass, Techno Bass, Synth Bass 1.
  Excludes Rock Bass and Elec Bass.
- **Drums** `[2, 3]` — Dance Drums, Machine Kit. Electronic kits only.
- **Lead 1** `[0, 1, 3, 5, 6]` — Mono Synth, Saw Lead 3, Polysynth, Square Lead, Synth Lead.
  Excludes Soft Brass.
- **Lead 2** `[0, 2, 4, 5, 6, 7]` — Polysynth, Moog, Square Lead, Synth Lead, Saw Lead,
  5th Saw Wave. Excludes Elec Guitar and Brightness.
- **Texture** `[0, 3, 4, 6, 8, 9]` — Fifths Lead, FX Atmosphere, FX Echoes, Interference,
  Metal Pad, Ice Rain. Excludes Guitar Fdbk and the two warm pads, which suit sustain rather
  than scatter.

Tracks outside the drawn cluster keep their full pools.

---

### Section Dropout — a cluster behaviour, not a rule

The most distinctive measured feature, and it spans tracks so it belongs to the cluster.

*Implementation.* When any cluster is drawn, build a dropout schedule:
- **Two windows**, at roughly **25% and 65%** through the song (the measured positions),
  snapped to multiples of 8 bars.
- Lengths drawn independently: **4...14 bars**.
- During a window, **every track in the drawn cluster goes silent together — including
  Texture, and Lead 2 when partnering**. Tracks outside the cluster keep playing, which is what
  makes the drop read as a section change rather than the song stopping.
- Never drop in the first 16 bars or the last 8.

## What Is Not Changing

- **Instruments.** Uses the existing Motorik pools unchanged. No new samples, no pool
  extensions, no pick-pool restrictions.
- **Effects, mode, harmony, structure, titles, tempo.** All inherited from base Motorik.
  Deliberately so: the corpus measures 120–128 BPM, but Motorik's own tempo and progressions
  are not busy enough to fight the rigidity, and constraining them would make this a substyle
  in all but name.
- **Noir and Arcade.** Untouched. Clusters apply to base Motorik only.
- **Neu! identity.** Protected deliberately — the Hallogallo rule's weight doubles rather than
  being diluted.

---

## Implementation Checklist

1. Cluster roll at frame-generation time, thresholds in order (none 70 / rhythm-section 12 /
   sequence-lock 10 / machine-voice 8).
2. Thread the cluster through `BassGenerator`, `DrumGenerator`, `RhythmGenerator`,
   `LeadGenerator` and `TextureGenerator`; each checks whether its track is in the drawn
   cluster. Texture is in scope for **every** cluster, not any single one.
3. Retire the four bass rules from the base Motorik pool and apply the redistributed weights.
4. Add all twelve new rule IDs to the rule-ID → description map: `MOT-DRUM-013/014`,
   `MOT-BASS-026/027`, `MOT-RTHM-014/015`, `MOT-LD1-021/022`, `MOT-LD2-011/012`,
   `MOT-TEX-001/002`. **Do not reuse the retired numbers** — saved `.zudio` logs
   record rule IDs, so a recycled number would make an old song's log misreport itself.
5. Build the section-dropout schedule when a cluster is drawn, and silence the whole cluster
   together during its windows.
6. Log the cluster name when one fires.
7. Batch-generate and listen, checking specifically that non-cluster songs still sound like
   today's Motorik.

---

## Open Questions

- **Cluster share.** 30% total is a starting figure. If Kraftwerk-flavoured songs feel too
  frequent, reduce the three cluster weights proportionally rather than removing a cluster.
- **Whether Machine Voice needs its own instrument treatment.** Unison doubling between Rhythm
  and Lead 1 may sound thin without a timbral difference between them — the Kosmic Space
  doubling rule solves the same problem with vibrato, pan and Air. Decide after listening.
- **Drum rule risk.** A sparse mechanical kit is the furthest departure from current Motorik
  drums. It is also the biggest gap. Worth prototyping first, since it is the rule most likely
  to sound wrong against the rest of the arrangement.
