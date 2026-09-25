# Motorik Kraftwerk Flavour — Design Plan

Status: **implemented and shipping in 2.6 build 131.**

Motorik occasionally leans machine-like rather than Neu!-like. A coupled *cluster* of tracks
adopts Kraftwerk rules together while the rest of the song draws from normal rotation. This is
not a substyle: there is no new `displayStyleName`, no UI change and no fourth sanitiser.

This document describes the design as built. Section numbers, weights and measurements below
are the shipped values.

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
from `MOT-TEXT-009/002` instead of normal rotation.

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

**Log the cluster.** When one fires, emit a `GenerationLogEntry` with tag `Cluster` naming the
tracks that actually adopted Kraftwerk rules, so a song's character can be identified by
reading its log rather than by guessing:

```
Cluster    KW Bass + Drums + Texture
Cluster    KW Bass + Rhythm + Texture + Lead 2
Cluster    KW Rhythm + Lead 1 + Texture
```

List **actual membership**, not the cluster's name — Texture always joins and Lead 2 joins only
when partnering, so the line should reflect what happened in this song rather than which of the
three clusters was drawn. A song where Lead 2 drew silence omits it.

Emit nothing when no cluster fires; the absence is the signal. The entry is written into
`generationLog`, so it reaches the `.zudio` file and survives reload like every other rule line.

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
section crashes and intro/outro variants; `DrumVariationEngine` runs in its restricted cluster
form. Measured output: Sequenced Timekeeper 13 hits/bar (3.25 notes/beat against a ~3.3 target)
on 4 pitches; Sparse Accents ~0.6 notes/beat on 3 pitches.

**MOT-DRUM-014 "Sparse Accents"** — no timekeeper at all.

*Implementation.* Three voices, all sparse, total density under 1.5 notes/beat:
- **Kick (36)** — steps 0 and 8, or 0 and 10 (drawn per song).
- **Snare (38)** — step 8, every **second** bar only.
- **Accent** — a tom or rim on a single step drawn from {6, 14}, every fourth bar.

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

**MOT-LD1-022 "Long Run"**

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

**MOT-TEXT-009 "Wide Scatter"**

*Implementation.* **Single notes**, never phrases — one event then a gap. Register spans at
least **40 semitones**, pitches drawn from chord tones across the full span rather than a band.
Density 0.4–0.7 notes/beat, silence-to-statement **7:1 or wider**. `durationSteps: 1...3`,
velocity 72.

**MOT-TEXT-010 "Sparse Punctuation"**

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
  `MOT-LD1-022` Long Run 40%.
- **Texture** (all clusters) — `MOT-TEXT-009` Wide Scatter 65%,
  `MOT-TEXT-010` Sparse Punctuation 35%.
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

Held on `MotorikCluster.instrumentSubset(forTrack:)` so the index lists live in one place,
read by the pick pools and by `sanitiseClusterInstruments`. Lead 2's subset applies whenever
Rhythm is clustered: it only partners on a 65/35 draw made during generation, but applying the
subset to both outcomes is harmless, since a silent Lead 2 has no audible instrument either way.


Cluster tracks draw from a restricted subset of the **existing** Motorik pools. No pool is
reordered, extended or renamed — this uses the same `instrumentPickPool` /
`instrumentPickPoolStatic` mechanism Arcade already uses to return an index array, so the
surrounding pool-selection code is untouched.

The problem being solved: the Rhythm pool contains three guitars and an acoustic bass, and a
rigid two-pitch-class cell played on Fuzz Guitar is a guitar riff, not a sequencer.

- **Rhythm** `[3, 6, 9]` — Doctor Solo, Synth Bass 3, Electric Piano 1. Excludes the three
  guitars, both acoustic basses, Charang and Harpsi Pad. (Clavinet was removed from the Motorik
  pool entirely in build 131 — its sound is absent from `Zudio.sf2`, so it played silent.)
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

## Title Signal

When a cluster fires, the song title takes a German-flavoured affix so the character is
visible in the Songs list, not only audible. Applies **only** when a cluster is active —
non-cluster Motorik titles are unchanged.

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

- **Instruments.** No new samples and no pool extensions — a cluster draws a restricted
  *subset* of each existing Motorik pool, through the same mechanism Arcade already uses.
- **Effects, mode, harmony, structure.** All inherited from base Motorik. Constraining the
  progressions would make this a substyle in all but name.
- **Tempo and titles** are the two exceptions: a cluster song sits in the 120-132 band and takes
  a German-flavoured affix. Both are cluster-only, and base Motorik is untouched by either.
- **Noir and Arcade.** Untouched. Clusters apply to base Motorik only.
- **Neu! identity.** Protected deliberately — the Hallogallo rule's weight doubles rather than
  being diluted.

---

## How It Fits Into Generation

The cluster is drawn once per song, on a stream derived from the seed so it does not shift any
other draw. Everything below follows from that one value.

1. **Cluster roll** at frame-generation time — none 80 / Rhythm Section 8 / Sequence Lock 7 /
   Machine Voice 5, of base Motorik songs.
2. **Tempo band.** A cluster song is remapped from base Motorik's 126-154 into **120-132**,
   centred on 125. The corpus measures 120-128, and at Motorik's usual pace a sequencer on top
   still reads as Neu!. The existing triangular spread is compressed rather than clamped, so the
   distribution keeps its shape instead of piling onto the ceiling, and it is applied before the
   bar count is chosen so songs keep their intended duration. Non-cluster songs are untouched.
3. **Rule pools.** Each generator checks whether its track is in the drawn cluster and, if so,
   draws from the Kraftwerk pool instead of normal rotation.
4. **Instrument subsets**, held on `MotorikCluster.instrumentSubset(forTrack:)` so the pick pool
   and the sanitiser share one definition.
5. **Lead 2** is resolved after Rhythm, since both its rules derive from Rhythm's actual events.
6. **Fills only at the dropout edges.** In every cluster song, including those where Drums is
   not a member, the drum pass runs in a restricted form: no periodic every-eighth-bar fills, no
   generic instrument-entrance fills, none at ordinary section boundaries. A cluster fills at one
   kind of moment only — the bar before the whole cluster drops out, and the bar before it
   returns — held to 1 or 2 beats, never 3, averaging under two fills a song.

   Entrance fills in particular have to go: Texture and Lead 1 are 88-95% rest in a cluster, so
   a rule that fires whenever a part returns fires almost continuously. The dropout schedule is
   decided after this pass runs, so the bars come from `clusterDropoutWindows` and are handed in.

   **The log reads the drum track, not the fill logic.** `buildStepAnnotations` mirrors the
   normal drum pass rather than the engine's output, and `fillBeats` infers a fill's length from
   where the hi-hat stops — which measures every bar as a 3-beat cascade on kits that have no
   continuous hat, as neither Kraftwerk kit does. For a cluster the annotation therefore keys on
   toms the kits never play. Crash is not a marker: it also lands on the first bar of a section
   as an accent.

7. **Section dropout** drops the whole cluster together, twice a song.
8. **Repeat guard** caps any cluster track at 12 identical bars.
9. **Title affix** and the `Cluster` log line make the song identifiable without listening.

### Instrument enforcement needs two halves

The pick pool alone is not sufficient, and this is worth stating plainly because it is not
obvious: **only two instruments are re-picked per song.** The other five carry over from the
previous song untouched. A cluster that only consulted the pick pool would routinely inherit
Fuzz Guitar on Rhythm — a guitar riff rather than a sequencer, the exact case the subsets exist
to prevent.

So the cluster has a **sanitiser** as well, `sanitiseClusterInstruments`, which forces every
member track into its subset. Noir and Arcade each have one for the same reason. Both the
instance path and the static Endless-mode path need it.

### Repeat guard — 12 bars

The corpus behaviour is a figure repeated with **no** variation, and the rules implement that
literally. Over a 128-bar song that gives stretches of 30-50 identical bars: true to the source,
and tiring.

A cluster track therefore plays at most **12 identical bars** before the pattern takes a slight
change — one note displaced by an octave, or one note dropped. The cell is not rewritten and the
groove does not move. Percussion only ever drops a hit, never shifts an octave, since a drum
note selects the instrument rather than a pitch. Empty bars reset the count, because a dropout
window already breaks the repetition. Drums are covered in every cluster song, member or not,
because the variation engine that would otherwise break up a long run is skipped throughout.

The guard runs on Rhythm *before* Lead 2 derives from it, so the partner rules inherit the
variation rather than drifting out of unison.

This is a deliberate departure from the measured behaviour, chosen for listenability.

### Which passes a cluster skips, and why

- **`ArrangementFilter`** — spotlights one track and thins the others independently, which is
  the opposite of a cluster. It also breaks `MOT-LD2-012`'s strict unison by thinning Rhythm but
  not Lead 2. The section dropout is the cluster's arrangement device instead.
- **`DrumVariationEngine`** — runs in a restricted form rather than being skipped: fills only
  at dropout edges, and no cymbal run variations, since the 12-bar repeat guard already covers
  long identical runs. Bass locking is skipped when Bass is a cluster member, because
  `MOT-BASS-027` already takes every kick and `MOT-BASS-026` is a cell that must not be
  perturbed.
- **`PatternEvolver`** — skipped for `MOT-BASS-026` only. That rule alone is "drawn once and
  repeated with no variation"; the other three options in the cluster bass pool are pre-existing
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

Pinned by `MotorikClusterTests` and `DeterminismTests`:

- the cluster survives every `SongState` copy method, and the roll is deterministic
- Noir and Arcade never draw a cluster; the distribution matches 80/8/7/5
- every cluster track draws a Kraftwerk rule, and Lead 2 either partners or rests
- `MOT-LD2-012` never drifts off Rhythm's grid
- no cluster track exceeds 12 identical bars
- cluster tempo stays within 120-132 and the base band stays 126-154
- cluster fills occur only at dropout edges, at most four a song

`RetiredRuleReloadTests` covers the retired bass rules: still playable when a saved song names
one, absent from the base pool, and reachable from Noir or Arcade.

---

## Open Questions

- **Cluster share.** 20% of base Motorik, about 12% of all Motorik. If Kraftwerk-flavoured songs
  feel too frequent, reduce the three weights proportionally rather than removing a cluster.
- **Machine Voice is the weakest of the three.** It clusters Rhythm + Lead 1 + Texture and
  leaves Drums and Bass on normal rotation — the two tracks that most determine whether music
  reads as Kraftwerk. The tempo band and fill suppression narrow the gap; whether it needs the
  drum pool constrained as well is a listening question.
- **Whether Machine Voice needs its own instrument treatment.** Unison doubling between Rhythm
  and Lead 1 may sound thin without a timbral difference between them.
