# Kosmic Space — Design & Implementation Plan

Status: **design complete, ready to implement.** Builds 130 for iOS and Mac were uploaded
to App Store Connect on 2026-09-24, scheduled for release Oct 1. Those binaries are locked,
so repository changes no longer affect what ships.

**Work on a branch until the app is actually live.** If review rejects, `main` needs to be
in the state that produced the uploaded build.

Every decision below is settled. Where a value could have gone more than one way, the choice
is stated with its reason.

---

## Naming

**Kosmic Space.** Second substyle of Kosmic, alongside Kosmic Drift. Triggered by
`isKosmicSpace == true` on SongState; `displayStyleName` returns "Kosmic Space".

---

## Musical Identity

Kosmic Space is the Jean-Michel Jarre substyle: a continuous sequencer figure as the spine of
the song, very slow harmonic movement above it, long sustained string-machine pads, a narrow
high lead, and filtered-noise sweeps marking section boundaries. Where base Kosmic drifts and
Kosmic Drift floats, **Space pulses** — the sequencer never stops.

Reference albums: *Oxygène* (1976), *Équinoxe* (1978), *Magnetic Fields* (1981),
*Chronologie* (1993).

**Tie-breaker.** *Oxygène Part 4* is the reference track — the classic statement of this
style, and the one measured most closely in the Evidence Base below. Where an implementation
decision is genuinely balanced, choose the option closer to it: chordal movement over static
drone, strings over other pad timbres, a bass that pulses rhythmically while still moving
melodically, and a lead that is sparse and distinct against a dense sequencer.

---

## Method: Homage, Not Transcription

Every rule here is a **statistical constraint** — interval distribution, repeating-cell
length, register band, note duration, density. No rule encodes a melody, and none should. The
goal is output unmistakably of Jarre's world in gesture and texture, and original in note
content — the same relationship Motorik Arcade has to its arcade-soundtrack references.

`KOS-LEAD-015` needs the most discipline, because the behaviour it generalises comes from a
very recognisable source. It specifies only the envelope: band width, density, interval mix,
phrase length. Contour direction is drawn per phrase and phrase length varies within its
range, so the generator cannot settle into a fixed shape.

**Do not encode a fixed interval sequence or a characteristic opening gesture in any rule.**

---

## Evidence Base

Nine fan transcriptions analysed with `tools/jarre_analyze.py` — Oxygène Parts 2, 3 and 4,
Magnetic Fields Parts 1 and 2, Chronologie Parts 2 and 3, and two Équinoxe files — covering
more than fifty source tracks. Oxygène Part 4 is Type 0 and must be split by MIDI channel,
not by track.

The measurements that set values in this plan:

- **Parallel detuned sequencer voices.** Magnetic Fields Part 1 carries two sequencer parts
  of 1,948 and 1,946 notes with identical register (46–72) and identical density (2.74
  notes/beat). The same file pairs two pad tracks identically, so the doubling habit is
  general rather than sequencer-specific.
- **Sequencer cells run 8–21 notes, median 13.** Nothing measured below 8.
- **Bass pulses and moves at the same time.** Oxygène Part 4's bass channel: register 29–43,
  94% of intervals a 2nd–4th, 2% leaps, density 1.6 notes/beat. Magnetic Fields Part 1's
  moving bass layer agrees at 72% stepwise. Two unrelated files.
- **Two distinct lead behaviours.** Oxygène Part 4's principal riff is leap-dominant — 32% of
  intervals above a fifth, 9% stepwise, sparse at 0.81 notes/beat, inside a 12-semitone band
  above MIDI 70. The Magnetic Fields leads invert this at 85% stepwise. The catalog carries
  one rule for each.
- **Leads occupy narrow bands** — seven and thirteen semitones in Magnetic Fields Part 2.
  Leads are placed, not roamed.
- **Pads sustain 8 beats or longer**, consistent across three pad tracks.
- **Tempo**, with Magnetic Fields Part 2 corrected from its double-time transcription: 98,
  100, 120, 121, 132.
- **Percussion either runs continuously or drops out for whole sections.** Magnetic Fields
  Part 1's percussion goes silent twice for **24 bars each** across a 152-bar song — about a
  third of the song with no kit. Part 2's runs unbroken for all 276 bars. There is no middle
  behaviour: no short gaps, no fills-as-breaks.
- **Melodic voices are layered, not solo.** Counting melodic-register tracks per file:
  Magnetic Fields Part 2 has five, Équinoxe four, Oxygène Part 2 two. Only the shortest file
  is single-voiced. Registers cluster tightly (p71, p75, p76, p77 in Part 2) — the habit is
  stacking nearby voices rather than separating them widely.
- **Parts make statements, then leave.** Measured as runs of activity separated by silence,
  with the phrase boundary set adaptively from each track's own density. Per role — statement
  length, silence between, and the silence-to-statement ratio:
  - **Lead**: 4 notes / 13 steps, then 13 steps silence. **Ratio 1.0:1** — a lead is silent
    about as long as it plays.
  - **Bass**: 10 notes / 83 steps, then 93 steps silence. Ratio 1.0:1.
  - **Pads**: 26 notes / 457 steps, then 183 steps silence. Ratio 0.5:1 — long holds, long gaps.
  - **Sequencer**: 42 notes / 84 steps, then 8 steps silence. Ratio 0.3:1 — near-continuous.

  This matters more than a bare rest ratio: a part can be 90% silent either by scattering
  single notes or by playing a phrase and stopping. Only the second is a statement, and it is
  what these tracks do.
- **Parts also leave entirely.** Dropouts of two bars or more: bass 5 of 5 tracks, sequencer 5
  of 8, pads 2 of 2, lead 3 of 5. Leaving the arrangement is normal behaviour here, not a
  drum-specific habit.
- **Velocity is flat** — one value per track across every file, consistent with sequencer
  programming. No dynamics rules are derived.

---

## How It Differs from Base Kosmic

Base Kosmic blends Jarre with Tangerine Dream, Vangelis, Craven Faults, Eno, Loscil and
Electric Buddha Band, and six of its rules already carry his name. Space is **subtraction and
concentration** — the same move Motorik Arcade made.

- **Rhythm is never silent.** Base Kosmic can drop the arpeggio; Space cannot.
- **Every other lineage is excluded** — no Electric Buddha, Craven Faults, Kraftwerk, Berlin
  School, Moroder, Tycho or Sigur Rós rules on any track.
- **Harmonic rhythm is much slower** — 8 to 16 bars per chord.
- **Pads are longer** — 8-beat minimum sustains.
- **Instrument pools are narrowed hard**, to raw oscillator waveforms and string machines.

---

## How It Differs from Kosmic Drift

- **Space pulses, Drift floats.** Space requires a continuous sixteenth-note sequencer at
  2.5–3.0 notes/beat. Drift has no such requirement.
- **Tempo:** Space 95–120, Drift 70–90. No overlap.
- **Mode:** Drift is Dorian-dominant (50%); Space is Aeolian-dominant (40%) and darker.
- **Drums:** Space excludes the Drift loping grooves entirely.
- **Bass:** Space excludes Drift's smooth-arpeggio and BoC-loop rules.

---

## The Seven-Track Collapse

Jarre's arrangements run 12–14 tracks; Zudio has seven.

- **Two sequencer tracks → Rhythm**, one part. Their stereo width returns as auto-pan.
- **Two bass layers → Bass.** Generate the moving layer only; never a static drone.
- **Four percussion tracks → Drums**, one kit.
- **Five melodic tracks → Lead 1 and Lead 2.** Lead 1 takes the principal melody, Lead 2 a
  high narrow counter-line; the rest are dropped.
- **Pads and drones → Pads and Texture**, split by duration: 8-beat-plus sustains to Pads,
  sparse atmospheric events to Texture.

---

## Cross-Track Coordination

The sequencer is the song; every other track is defined relative to it.

**Rhythm** carries both pulse and harmony and is excluded from random block-silencing, as
Motorik Arcade already does for Lead 1.

**One bounded exception.** The measurement shows sequencer parts dropping out in 5 of 8 source
tracks, so "never silent" would be a departure from the evidence rather than a reading of it.
The arrangement arc may remove Rhythm for **one window of 4–8 bars, in the final third only**.
Everywhere else it runs unbroken. That preserves the spine through the body of the song while
allowing the one breakdown the sources actually use.

**Bass** moves underneath at roughly half Rhythm's density — ~1.6 notes/beat against ~2.7 —
in longer note values. It shares the harmony but never competes for the pulse.

**Lead 1** sits in a narrow band above MIDI 70, clear of Rhythm's 46–72 register, so the two
never mask each other.

**Lead 2**, when present, takes a second narrow band offset from Lead 1's by at least a fifth,
at lower velocity. It never doubles Lead 1 at the unison or octave.

**Pads** hold 8-beat-plus sustains, changing only at chord boundaries.

**Texture** is event-driven, not a wash — sweeps at section boundaries.

**Stereo width comes from two sources, never both at once.** When `KOS-LEAD-017 "Second
Sequencer"` fires (30% of songs), Rhythm and Lead 2 are two real sequencer lines panned to
opposite positions — the measured `seq1l`/`seq2r` arrangement, reproduced rather than
simulated. Otherwise Rhythm auto-pans alone.

Detuning two voices onto the single Rhythm track is **not** used: it would double polyphony on
the busiest track in the substyle, where splitting the same load across Rhythm and Lead 2
costs the same and sounds more like the source.

---

## Rule Catalog

### Implementation conventions

Each rule below carries an **Implementation** paragraph specifying step placement, pitch
selection, velocity and gate. These are written against the real APIs:

- `MIDIEvent(stepIndex:note:velocity:durationSteps:)`. `stepIndex` is absolute —
  `bar * 16 + stepInBar`. One step is a sixteenth, so a bar is 16 steps and a beat is 4.
- `TonalGovernanceEntry` gives `chordWindow` (with `startBar`, `lengthBars`, `chordRoot` as a
  degree string, and `chordTones` as a `Set<Int>` of pitch classes) plus `sectionMode`.
- Rule functions follow the existing per-bar signature in the Cosmic generators, e.g.
  `(barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG, totalBars: Int, isBody: Bool) -> [MIDIEvent]`.
- Register clamps are applied after pitch-class selection, by transposing octaves until the
  note falls inside the stated MIDI range.
- **Velocity is 80 flat on every melodic track** unless a rule says otherwise. The corpus
  showed one velocity per track throughout; this is deliberate, not an oversight.

Each new rule must also be added to its generator's `rules`/`weights` arrays, which is where
the percentages below are applied.


Weights sum to 100% per track. Rules marked *(shared)* already exist; the rest are new and
continue each track's existing numbering.

### Drums

**KOS-DRUM-000 "No percussion"** *(shared)* — 35%
Many Jarre sections have no kit at all; the sequencer carries the pulse.

**KOS-DRUM-001 "JMJ Mini Pops"** *(shared)* — 35%
The existing preset-box pattern, already named for this artist. Plays continuously.

**KOS-DRUM-010 "Phased Pulse"** — 20%
The Mini Pops pattern, but **dropping out for one or two stretches of 16–32 bars** and
returning — measured from Magnetic Fields Part 1, where percussion goes silent twice for 24
bars each across 152 bars. Entries and exits land **on section boundaries**, coinciding with
the `KOS-TEXT-005` sweep, so the kit arriving or leaving reads as the section changing rather
than as an arbitrary gap.

Constraints: never drop out in the first 16 bars; never leave more than half the song
drumless; gaps are whole sections, never short. The dropouts are long and deliberate — the
corpus shows no short gaps or fills-as-breaks, so neither should this.

*Implementation.* Reuses the `KOS-DRUM-001` per-bar pattern unchanged; this rule only decides
**which bars are silent**. At generation time, before emitting any bars, build the gap set:
roll 1 or 2 gaps (50/50); for each, draw a length of 16, 24 or 32 bars (weights 0.3/0.4/0.3)
and a start bar that is a multiple of 8, at least bar 16, and does not overlap an existing gap
or extend past `totalBars - 8`. If the two gaps together would exceed `totalBars / 2`, drop
the second. Then `guard !gapBars.contains(bar) else { return [] }` at the top of the per-bar
function. Because gap starts are multiples of 8 they coincide with chord-window and section
boundaries, which is what makes entries and exits read as structural.

Note this is the only drum behaviour Zudio cannot express through the arrangement filter:
`ArrangementFilter.subjectTracks` excludes Drums entirely, so the phasing must be built into
the rule itself. Motorik Arcade's `MOT-DRUM-011 "Light Four"` is the precedent — it phases
its kick in and out internally for the same reason.

**KOS-DRUM-009 "Dense Sixteenth Pulse"** — 10%
Mechanical sixteenths confined to a narrow 36–51 range. No fills, no humanisation, no
velocity variation — the preset-box character comes from its refusal to vary. Continuous
throughout, matching Magnetic Fields Part 2's unbroken 276 bars.

*Implementation.* Every bar, identically: closed hat (42) on even steps 0,2,4,6,8,10,12,14;
kick (36) on steps 0 and 8; snare (38) on steps 4 and 12. Twelve events per bar = 3.0
notes/beat. Velocity 80 on all three voices with **no variation whatsoever** — do not apply
the humanisation the other Kosmic drum rules use. `durationSteps: 1`. No fills at section
boundaries, no intro or outro variant — identical output in **every bar it plays**. When the
track enters and leaves is set by the arrangement arc (see Song Structure), not by this rule.

Excluded: `KOS-DRUM-002`, `004`, `005`, `006`, `007`, `008`.

### Bass

**KOS-BASS-018 "Pulsing Stepwise Bass"** — 50%
Register 29–46. **At least 75% of melodic intervals a 2nd through 4th, no leaps above a
fifth**, note duration ~0.5 beat, density 1.5–2.0 notes/beat.

Pulse and movement are separate axes and this rule requires both: *pulsing* is rhythm — a
steady unbroken subdivision — while *stepwise* is pitch. **Never rest, never drone.** The
pulse stays constant while the pitch keeps moving.

This applies *within the bars the bass plays*. Whether the track is playing at all is the
arrangement arc's decision, not this rule's — the same separation as `KOS-DRUM-009`. Measured
bass tracks drop out in 5 of 5 sources, so the part leaving is expected; the part idling is not.

*Implementation.* Emit on all eight even steps of every bar — 0,2,4,6,8,10,12,14 — giving 2.0
notes/beat with no rests. `durationSteps: 2` (legato, each note running into the next),
velocity 80 flat.

Pitch is a constrained walk over scale pitch classes:

1. On step 0 of each **chord window**, anchor to `chordWindow.chordRoot` transposed into
   MIDI 29–46.
2. For every subsequent note, draw a scale-degree step of ±1 or ±2 (weights 0.7 / 0.3).
3. Direction is drawn 60/40 **toward the current chord root** — measured as whether the
   candidate reduces the semitone distance to the root — which prevents the walk drifting to
   the register edges over a 16-bar window.
4. Reject and re-draw any candidate whose interval from the previous note exceeds 7 semitones,
   or which falls outside MIDI 29–46. After three rejections, snap to the nearest chord tone.
5. On step 0 of every bar, if the current note is not a chord tone, move to the nearest one.

That produces roughly 75–85% intervals of a 2nd–4th with no leaps above a fifth, matching the
measurement, without hard-coding the percentages.

**KOS-BASS-002 "Root-Fifth Slow Walk"** *(shared)* — 25%
Slow root-and-fifth movement; sits under a busy sequencer without competing.

**KOS-BASS-017 "Four-bar hold, root sustain"** *(shared)* — 25%
The long-hold option for sections where the sequencer carries everything.

Excluded: `KOS-BASS-003`, `004`, `008`, `010`, `011`, `012`, and any single-pitch drone bass.

### Lead 1

**Both Lead 1 rules draw from a single song motif rather than generating each phrase
independently.** This is what separates a memorable line from a plausible one: Jarre's
melodies are short, strongly shaped and repeated with conviction. A fresh random walk per
phrase satisfies the interval statistics and is forgettable.

*Motif construction and use.* At song start, build one motif and reuse it all song:

- The motif is an array of `(degreeOffset, stepOffset, durationSteps)`, length 4...8, where
  `degreeOffset` is a **scale-degree offset from the chord root**, not an absolute pitch. Storing
  it relatively is what lets it transpose correctly when the harmony moves.
- Build it using the interval rules of whichever Lead 1 rule was drawn — stepwise for
  `KOS-LEAD-013`, leap-dominant for `KOS-LEAD-015`. The motif inherits the rule's character.
- `stepOffset` values are drawn from the rule's placement grid and are strictly increasing.

Each time the lead enters, it **states the motif**, realised against the current chord:

- Statements 1 and 2: exact, transposed to the current chord root.
- From statement 3 on, apply one variation drawn per statement: **diatonic transposition** by a
  third or fourth (0.35), **contour inversion** around the first note (0.2), **rhythmic
  displacement** by 2 or 4 steps (0.25), or **tail extension** — hold the final note twice as
  long (0.2).
- Every fourth statement is exact again, whatever the draw. Returning to the plain form is what
  makes the variations read as variations rather than as drift.
- Rest 4...12 steps between statements, as before.

Two songs generated under this scheme share a character and no material; within one song, the
listener hears the same idea developing.


**KOS-LEAD-006 "JMJ evolving phrase"** *(shared)* — 35%

**KOS-LEAD-004 "Echo melody"** *(shared)* — 25%
Sparse phrases with space around them, suited to the delay this track carries.

**KOS-LEAD-013 "Narrow Step Melody"** — 20%
Confined to a **7–13 semitone band above MIDI 70** for the whole song, with 2nd–4th intervals
dominant and leaps above a fifth rare.

*Implementation.* At song start, draw a band: low edge uniformly from 70...74, width uniformly
from 7...13. Every note is clamped into that band for the entire song.

Phrases: draw length **3...6 notes** (measured median 4). Notes land on even steps (0,2,4,...)
within the bar, starting at step 0 or step 8 (50/50). `durationSteps: 2`, velocity 80.

**Silence between phrases is drawn to roughly match the phrase's own length** — measured
ratio is 1.0:1, so a phrase spanning 13 steps is followed by about 13 steps of rest. Draw the
rest as 0.8...1.4 × the phrase span, minimum 8 steps. A fixed short rest would make the lead
chatter; matching silence to statement is what makes each phrase land.

Pitch: first note of each phrase is a member of `chordWindow.chordTones` inside the band.
Subsequent notes walk ±1 or ±2 scale degrees (weights 0.65 / 0.35); reject any interval above
5 semitones and re-draw. If a candidate leaves the band, reflect the direction rather than
clamping, so the line turns around instead of flattening against the edge.

**KOS-LEAD-015 "Wide Interval Hook"** — 20%
The inverse profile: sparse and leap-dominant, a **10–14 semitone window above MIDI 70**,
noticeably thinner than the sequencer beneath it. Fourths, fifths, sixths and octaves are the
working vocabulary.

*Implementation.* Band drawn as for `KOS-LEAD-013` but wider: low edge 70...74, width 10...14.

Placement is sparse — notes on steps 0, 6, 10 of a bar, or 0, 4, 12, chosen per phrase — giving
0.75 notes/beat. `durationSteps: 3` (longer than the step melody, so the sparseness reads as
deliberate rather than absent), velocity 80.

Pitch: first note of each phrase is a chord tone in the band. Each subsequent interval is drawn
from **5, 7, 9 or 12 semitones** (weights 0.3 / 0.3 / 0.2 / 0.2) with direction drawn fresh per
note, then snapped to the nearest scale pitch class. Roughly one note in five may instead take
a 2nd, to avoid the line becoming mechanically angular. If a candidate leaves the band, invert
the direction and retry once, then fall back to the nearest in-band chord tone.

Phrase length 4...8 notes, **contour direction drawn per phrase** rather than following any
fixed rise-and-fall. This is the rule where a fixed shape would make the output recognisable
as its source, so the shape must come from the draw.

Excluded: `KOS-LEAD-001`, `002`, `003`, `005`, `007`, `008`, `009`, and `KOS-LD1-010/011/012`.

**Glide is not used.** The pitch-bend infrastructure exists — `PlaybackEngine` runs a 60fps
per-track vibrato — but no glide was measurable in any source, so no rule depends on it.

### Lead 2

Jarre runs 10–14 tracks and layers melodic voices freely; Zudio has seven. Leaving Lead 2
idle would waste the one spare voice available, so it is active in **four songs out of five**.
It does not have to carry a melody: the corpus's most distinctive texture is two *sequencer*
lines, not two leads.

**KOS-LEAD-017 "Second Sequencer"** — 30%
Lead 2 carries a companion sequencer line rather than a melody. Same cell construction as `KOS-RTHM-016`, in the same 46–72 register, on a different
instrument, panned opposite to Rhythm.

*Implementation.* Call the same cell builder, with two differences: draw a **different cell
length** from `KOS-RTHM-016`'s (retry until they differ), and offset the emission by 2 steps.
Two coprime cell lengths of different sizes phase against each other as well as against the
bar, which is what produces the shifting interlock rather than a doubled unison. Velocity 72 —
slightly under Rhythm, so Rhythm stays the lead voice of the pair. This reproduces the measured `seq1l`/`seq2r`
pair directly instead of approximating it, and spreads the polyphony across two tracks rather
than doubling it on one.

When this rule fires, Rhythm and Lead 2 form the stereo pair and Rhythm's auto-pan is
disabled — the width comes from the two tracks sitting at opposite positions.

**KOS-LEAD-014 "High Counter-Line"** — 30%
A second narrow band offset from Lead 1's by a third to a fifth — close, not distant, matching
the tight register clustering measured in Magnetic Fields Part 2.

*Implementation.* Band low edge = Lead 1's low edge + 3...7 semitones, width 7...10. Phrases of
3...6 notes on even steps, `durationSteps: 2`, velocity 68.

**Interleaving is the point**: generate Lead 1 first, then emit Lead 2 phrases only into step
ranges where Lead 1 is resting. If Lead 1 is active for more than 70% of the song, drop every
second Lead 2 phrase rather than layering them. Pitch selection as `KOS-LEAD-013`.

**KOS-LEAD-016 "Doubling Layer"** — 20%
Thickening rather than counterpoint. The analogue of the duplicate-pair habit the corpus shows
on both sequencer and pad tracks.

*Implementation.* This rule generates no rhythm of its own. Take Lead 1's emitted events and,
for each, emit a matching event at the same `stepIndex` and `durationSteps`, transposed by a
fixed offset drawn once per song: **+12 semitones (0.5), +4 (0.25), or +9 (0.25)**, snapped to
the nearest scale pitch class so thirds and sixths stay diatonic. Velocity 60 — well under Lead
1's 80, so the pair reads as one enriched voice.

If Lead 1 draws `KOS-LEAD-015` (the sparse hook), skip every second doubled note; doubling a
sparse line note-for-note thickens it into something less sparse, which defeats that rule.

**The effects are what make this work.** Doubled at the same register with the same treatment,
the second voice just adds volume. Lead 2 therefore takes a different chain from Lead 1:

- **Vibrato** — slow and shallow. This is the substitute for the parallel-detuned-oscillator
  shimmer described in kosmic-plan.md §2: an LFO on pitch against a dry Lead 1 produces the
  same beating, and Zudio drives it through the existing 60fps per-track modulation rather
  than needing anything new.
- **Pan** — offset from Lead 1's position, so the pair occupies width rather than stacking in
  the centre.
- **Air** — presence peak plus high shelf, placing the double *above* Lead 1 in brightness so
  the ear reads it as sheen rather than as a second player.

Lead 1 stays comparatively dry so the contrast is audible. If Lead 1 already carries delay,
Lead 2 should not — two delays on near-identical phrase rhythms smear into mud.

**KOS-LD2-000 "No lead 2"** *(shared)* — 20%
Reserved for the sparsest songs, where Lead 1 alone over the sequencer is the point.

### Rhythm

**KOS-RTHM-016 "Long Sequencer Cell"** — 30%
A repeating cell of **9–15 steps**, sixteenth notes, register 46–72. Intervals weighted to
2nds and 3rds with leaps above a fifth under 10%. The cell repeats unchanged for the whole
chord window.

*Implementation.* Build the cell once per chord window, then loop it continuously.

1. Draw cell length `N` uniformly from 9...15. **Do not draw 16 or a divisor of 16.** A cell
   whose length is coprime with the 16-step bar phases against the barline — a 13-step cell
   starts three steps later each bar and realigns only after 13 bars. That drift is the
   Berlin-school sequencer character and the main reason this rule exists; a 16-step cell
   would lock to the bar and sound static.
2. Each of the `N` cell elements is a note with probability 0.7, otherwise a rest. Redraw the
   whole cell if it yields fewer than 6 notes. At ~70% fill this gives ~2.8 notes/beat,
   matching the measured 2.74.
3. Pitch per note element: start on `chordWindow.chordRoot` in MIDI 46–72, then walk ±1 or ±2
   scale degrees (weights 0.6 / 0.4), rejecting any interval above 7 semitones. Every third
   note element, snap to the nearest member of `chordWindow.chordTones`.
4. Emit by absolute step: for each step `t` in the chord window, the cell element is
   `t % N`; if it is a note, emit at `stepIndex = barStart + t`.
5. `durationSteps: 1`, velocity 80 flat.

The cell is regenerated at each new chord window, so harmony changes bring a new figure while
the character stays constant.

**KOS-RTHM-008 "JMJ Oxygen 8-bar arc"** *(shared)* — 30%

**KOS-RTHM-005 "JMJ dual arpeggio"** *(shared)* — 25%
The closest existing rule to the measured stereo sequencer pair, and the natural home for the
auto-pan treatment.

**KOS-RTHM-003 "JMJ oscillation"** *(shared)* — 15%

Excluded: `KOS-RTHM-001`, `002`, `004`, `006`, `009`, `010`, and `011`–`015` — Space's Rhythm
track is a sequencer, not a comping instrument.

### Pads

**KOS-PADS-009 "Long Sustain Layer"** — 40%
Note durations of **8 beats or longer**, 2–4 simultaneous voices, changing only at chord
boundaries.

*Implementation.* Emit only on step 0 of a chord window, and again every 8 bars within a window
longer than 8 bars (so a 16-bar chord re-attacks once, keeping the sound alive without
introducing movement).

Voice count drawn 2...4 per song and held. Pitches are members of `chordWindow.chordTones`,
voiced in MIDI 51–72, spaced at least 3 semitones apart, lowest voice on the chord root.
`durationSteps: 32` for an 8-bar window, or 128 for a 16-bar window — i.e. the full span to
the next attack, so voices sustain without gaps. Velocity 70.

Voices enter staggered: first at step 0, each subsequent voice 1...3 steps later. That
stagger is what keeps a stacked chord from sounding like one triggered sample, and is the
cheap approximation of the layered string machines in the source.

**KOS-PADS-001 "Eno long drone"** *(shared)* — 35%

**KOS-PADS-002 "Vangelis swell"** *(shared)* — 25%

Excluded: `KOS-PADS-003`, `006`, `007` — the gating fights the sequencer.

### Texture

**KOS-TEXT-005 "Oxygène Sweep"** — 40%
Filtered noise rising or falling across 2–4 bars, **placed at section boundaries rather than
randomly** — the placement is what makes it structural rather than decorative. Uses White
Noise Wave (bank 12, program 122).

*Implementation.* Identify boundary bars: the first bar of each section, plus the first bar of
any chord window at least 8 bars long. At each, with probability 0.7, emit a sweep.

A sweep is a **single long note**, not a run: one event at step 0 of the boundary bar minus
2...4 bars — i.e. it begins *before* the boundary and lands on it — with
`durationSteps: 32...64` (2–4 bars). Pitch is the chord root transposed into MIDI 60–72;
direction is carried by the `sweep` filter effect on the Texture track rather than by note
movement, which is why one held note suffices.

Velocity 64 rising to 80 across the song's sweeps, so later boundaries land harder. Never emit
two sweeps within 8 bars of each other; if boundaries fall closer than that, keep the first.

**KOS-TEXT-003 "Spatial sweep chromatic"** *(shared)* — 30%

**KOS-TEXT-002 "Distant Pulse"** *(shared)* — 30%

Excluded: `KOS-TEXT-001` (competes with the sequencer), `004`.

---

## Instruments

### The source instruments

What Jarre actually played, which determines what to reach for and what to avoid:

- **RMI Harmonic Synthesizer** — early *digital additive* synth. Provided the signature
  chorused sound of the Oxygène Part 4 hook. Additive, not subtractive: the tone is built
  from summed harmonics, bright and chorused rather than filtered.
- **Eminent 310 Unique** — electric organ with an integrated string-synthesiser section.
  Routed through an **Electro-Harmonix Small Stone phaser**, this produced the sweeping
  string pads. The phaser is not optional — it is what makes the sound move.
- **ARP 2600** — semi-modular. Analogue basslines, sound effects, rhythmic noise.
- **EMS Synthi AKS** — suitcase synth with patch matrix; primary melodic and sound-design tool.
- **EMS VCS3** ("The Putney") — pin-matrix modular, used for bubbling effects and unstable
  analogue modulation.
- **Mellotron M400** — tape replay, used for atmospheric and organic textural layers.

Three consequences for the picks below:

1. **The lead is additive and chorused, not a filtered sawtooth.** The Part 4 hook came from
   the RMI Harmonic. A bright, shimmering, slightly chorused tone is closer than a resonant
   saw lead — and closer still than a bare oscillator waveform.
2. **The string pad needs modulation.** An unmodulated string ensemble is only half the
   sound. See Effects Defaults.
3. **Noise and bubbling belong on Texture**, from the ARP 2600 and VCS3 — which is what
   `KOS-TEXT-005` and the FX presets are for. Mellotron sits here too, as atmospheric layer,
   not as the string pad.


**No new samples required.** All of the following are already present and unused in
`Zudio.sf2`. Because unused presets share sample data with used ones, wiring them up costs
approximately **zero megabytes and zero additional CPU**, while giving Kosmic Space sounds
heard nowhere else in the app.

- **Lead 1** — **Brightness** (0/100, already at pool index 1), **5th Saw Wave** (0/86),
  **Bright Saw Stack** (11/100), **Saw Lead** (0/81). Ordered by expected fit: the Part 4
  hook came from an additive synth, so favour bright and chorused over resonant-and-filtered.
  Brightness and the stacked/fifths presets get closer to an additive shimmer than a plain
  saw lead does. All four are harmonically rich enough to carry a melody over a dense
  sequencer, which is the baseline requirement.

  *Raw Sine Wave and raw Square Wave are deliberately excluded.* A GM sine is a pure tone
  with no harmonics, no filter movement and no envelope character — it either disappears
  under the sequencer or reads as a test tone. Square is nearly as static. What Jarre played
  was sawtooth through a resonant, envelope-shaped filter: harmonically dense and *moving*.
  Sawtooth presets are the closest the bank gets; a bare oscillator waveform is authentic to
  the synthesis method and wrong for the result.

  Also excludes the orchestral winds in the base Kosmic pool (Flute, Oboe, Recorder,
  Shenai) — those read as Vangelis.

- **Lead 2** — **Saw Lead 2** (12/81), **Sawtooth Stab** (11/81), Square Lead 2 (12/80).
  Square is defensible *here* but not on Lead 1: a doubling or counter voice benefits from
  being thinner than the part it sits against, which is the same reason Air is applied to it.

  **Pool extension required.** Neither the Kosmic Lead 1 pool
  (`[73, 100, 68, 74, 89, 8080, 76, 111]`) nor Lead 2 (`[100, 70, 84, 85, 98]`) currently
  contains these programs, so they must be **appended**. Appending is safe — it leaves every
  existing index untouched, as adding Long Lake to the texture pool did. **Never reorder a
  pool**: instrument assignments are persisted as indices, so reordering silently repoints
  every previously saved song.
- **Rhythm** — Moog (existing pool index 0; program 39 in this bank), Square Lead 3
  (13/80). Moog sits in the sequencer's 46–72 register naturally, which is why it belongs
  here rather than on Lead 1, where it would be too dark.
- **Pads** — Synth Strings 3 (8/50), Synth Strings 4 (11/50), Synth Strings 5 (11/51), plus
  the existing Synth Strings. **Weight these above the non-string pads** — strings are central
  to the target sound.
- **Bass** — Moog, Mono Synth, Synth Bass 3 (all existing in pool).
- **Texture** — White Noise Wave (12/122), Starship (8/125), Shooting Star (12/127), Solar
  Wind 2 (12/89), Echo Pan (2/102). This track carries the ARP 2600 noise and VCS3 bubbling
  roles, and is also where a **Mellotron** sample would belong if one is added — as an
  atmospheric layer, never as the string pad.
- **Drums** — 808 Kit, Machine Kit (existing).

**These picks are a starting point, not a final answer.** They were chosen by reading preset
names and reasoning about synthesis, not by listening. Expect to audition more of the bank
before settling — `Zudio.sf2` holds 156 presets and the audit found 64 unused, so there is
substantial unheard material. `5th Saw Wave` is the one I would try first, since parallel
fifths in the oscillator is characteristic of this repertoire.

If the bank cannot supply a convincing lead or a usable filtered-noise sweep after that,
an external sample is justified. The SC55 piano is the precedent: several free SF2 banks were
compared — **Florestan, SC-55 variants, Velocity Grand, Yamaha PSR**, against the
**GeneralUser GS** bank Zudio originally shipped — the best one chosen by ear, and a single
preset extracted to a ~2 MB file rather than bundling a whole bank. Budget for Kosmic Space
is 10–30 MB, which is generous by that standard.

### Where to look

**[musical-artifacts.com](https://musical-artifacts.com/)** — the same library the SC55 piano
came from (recorded in ambient-plan.md §6.1a). Libre soundfont resources, browsable by tag,
format and licence.

The single highest-value target is the **string machine**. The instrument behind the string
sound on *Oxygène* and *Équinoxe* was the **Eminent 310**, whose string section was later sold
separately as the **Solina String Ensemble** — so "Solina", "ARP String Ensemble" and
"string machine" are the search terms, not "synth strings". That timbre is widely sampled
because it is a well-loved classic, and it is the one colour most likely to make Kosmic Space
instantly recognisable. It maps directly onto `KOS-PADS-009 "Long Sustain Layer"`.

Secondary targets, in order of likely value:

- **Analogue lead** — Moog- or ARP-derived. The bank's sawtooth presets are a reasonable
  stand-in, but a sampled analogue lead with real filter character would serve
  `KOS-LEAD-015` better than anything currently available.
- **Filtered noise / sweep** — if White Noise Wave (12/122) proves unusable for
  `KOS-TEXT-005`, a dedicated noise or sweep sample is the fallback. This is the one rule in
  the plan with no confirmed-good sound behind it.
- **Sequencer/pulse timbre** — lower priority. Moog already covers the Rhythm track
  adequately.

**Confirmed to exist on the site** (found by search; none auditioned):

- **[Mellotron soundfonts sf2](https://musical-artifacts.com/artifacts/500)** — the strongest
  lead. Its contents include an **M400 String Section**, and an M400 is exactly the Mellotron
  Jarre used. Also carries M300A/B Violins and MKII 3 Violins. For Texture, not for the
  string pad.
- **[Mellotron 02 Soundfont](https://musical-artifacts.com/artifacts/8005)** — a more recent
  Mellotron upload; worth comparing against the above.
- **[Moog Disco Bass](https://musical-artifacts.com/artifacts/1651)** — bass register. Low
  priority, since Moog already covers Rhythm and the bank's synth basses cover Bass.
- **[Patch93's SC-55](https://musical-artifacts.com/artifacts/1228)** — the SC-55 family the
  Stereo Piano came from. Not a Kosmic Space need, listed for provenance.
- **[Florestan Basic GM GS](https://musical-artifacts.com/artifacts/400)** — sampled from a
  Roland Sound Canvas. General-purpose; unlikely to beat the existing bank.

**Not found, still wanted.** Searching did not surface any Solina, Eminent, ARP 2600, EMS
VCS3 or Synthi soundfont on the site. They may well be there — the site returns 403 to
automated requests, so its catalogue could not be browsed directly. These need a manual look:

- [SF2 tagged retro + synth](https://musical-artifacts.com/artifacts?formats=sf2&tags=retro,synth)
- [SF2 tagged synth](https://musical-artifacts.com/artifacts?formats=sf2&tags=synth)
- [SF2 tagged mellotron](https://musical-artifacts.com/artifacts?formats=sf2&tags=mellotron)

On-site search terms, in priority order: **Solina**, **string ensemble**, **string machine**,
**Eminent**, **ARP**, **EMS**, **Synthi**, **VCS3**, **Polymoog**, **analog strings**.

**What to listen for.** For the pad: a continuous, chorused, slightly detuned ensemble that
sustains indefinitely with no tape loop point and no re-trigger. If it wobbles or runs out
after a few seconds it is a Mellotron — useful for Texture, wrong for the pad. For the lead:
brightness that *changes across the note*. Static samples are why the existing bank's presets
may disappoint.

Three constraints on anything chosen:

- **Licence must permit redistribution in a paid App Store app.** Licensing on the site is
  per upload, not site-wide, so it has to be checked artifact by artifact.
- **Extract the single preset**, not the bank. The SC55 piano is 2 MB for exactly this reason.
- **Audition against the existing bank first.** Only spend the budget where the difference is
  obvious in an A/B of the same generated passage.

I have not heard any of these candidates — they are search directions, not recommendations.

---

## Effects Defaults

Kosmic Space inherits base Kosmic's effect defaults, with two divergences, both serving
stereo width rather than colour.

**Rhythm** auto-pans when it is the only sequencer. When `KOS-LEAD-017 "Second Sequencer"`
fires, Rhythm and Lead 2 sit at opposite fixed positions instead and neither auto-pans.

**Lead 2** always differs from Lead 1 in treatment, whichever rule it draws. Under
`KOS-LEAD-016 "Doubling Layer"` that means vibrato, offset pan and Air, with Lead 1 kept dry
by comparison. Under the other two rules a pan offset alone is enough, since those voices are
already distinct in pitch content.

**Pads take Sweep in addition to Space.** The Eminent 310's string section went through an
Electro-Harmonix Small Stone phaser, and that modulation is what produces the sweeping string
pad this substyle is built around. Zudio has no phaser; `sweep` (LFO-driven low-pass) is the
closest available and should be enabled on Pads by default here, slow and shallow. An
unmodulated string ensemble is only half the sound — this is the difference between "strings"
and *that* string sound.

**Stereo layout.** Everything else defaults to centre, which sounds narrow against records
where every element is placed. Kosmic Space specifies positions:

- **Bass and Drums** — hard centre, always. Low frequencies stay centred; this is not a
  stylistic choice.
- **Rhythm** — left of centre (~30%) when Lead 2 carries the second sequencer, otherwise
  auto-panning across a ±40% span.
- **Lead 2** — right of centre (~30%) under `KOS-LEAD-017`, forming the pair with Rhythm.
  Under the other rules, offset ~20% opposite whichever side Rhythm occupies.
- **Lead 1** — centre or ~10% off. The melody stays in the middle so the width around it reads
  as space rather than as a hole.
- **Pads** — widest element. When `KOS-PADS-009` draws 3 or 4 voices, spread them across
  ±50%, lowest voice centred.
- **Texture** — retains its existing panning, which suits the sweeps.

The intent is a wide bed with a centred spine: bass and drums anchoring, sequencers opposed,
pads filling the edges, lead in the middle.

---

## Song Structure

No verse/chorus model — but not a flat drone either. Jarre's long tracks **accumulate and
release**, and a substyle that runs every track from bar 1 to the end will sound static however
good the individual rules are.

**Entry schedule.** Tracks enter in a fixed order, at bar positions drawn per song:

- **Rhythm** — bar 1, always. The sequencer is the spine and it never rests.
- **Bass** — bar 8 or 16 (50/50).
- **Pads** — bar 16 or 24.
- **Texture** — first boundary sweep, typically bar 16–32.
- **Lead 1** — bar 24, 32 or 40. Latest entry of the melodic parts, so the sequencer is
  established before a melody arrives over it.
- **Lead 2** — at least 16 bars after Lead 1, when present.

Entries land on multiples of 8 so they coincide with chord-window and section boundaries.

**Withdrawal.** In the final third, remove one or two of Pads, Lead 2 or Drums for 8–16 bars,
then optionally restore. This is the release half of the arc. `KOS-DRUM-010` already does this
for Drums; when that rule is active, do not also withdraw Drums here.

**Ending.** Tracks drop out in reverse entry order over the last 8–16 bars, leaving the
sequencer last. No fade, no fanfare — the song thins until only the spine remains, then stops.

**Section boundaries** are marked by `KOS-TEXT-005` sweeps, and **Lead 1 and Rhythm may swap
program** at one. Tempo is fixed for the whole song.

---

## Mode and Harmony

- **Modes:** Aeolian 40%, Dorian 35%, Ionian 15%, Mixolydian 10%. No Phrygian, no Lydian.
- **Tempo: 95–120.** Below the 121+ band that reads as Motorik. Overlaps base Kosmic
  deliberately — Space is identified by its sequencer and harmonic rate, not its BPM.
- **Harmonic rhythm:** chord duration 8 bars (60%), 16 bars (30%), 4 bars (10%). Adjacent
  chords share **at least 3 pitch classes**. Exactly one chromatic pivot per song, in the final
  third.
- **Meter: 4/4 only.**

---

## Title Generation

`KosmicTitleGenerator` needs no new logic. Weight Kosmic Space toward patterns 1, 2, 7 and 8 —
single coined word, coined word plus Roman numeral, fake-Greek, fake-Greek plus numeral — and
away from the two-word English patterns, which read as generic ambient. The Roman-numeral
patterns echo the "Part II / Part IV" convention directly.

---

## Implementation Checklist

Missing any one of these produces a half-existing substyle.

1. `SongState.isKosmicSpace` — new stored property, **plus every `withXxx()` copy method**.
   Omitting one silently defaults it to false.
2. `SongState.displayStyleName` — add the case above the existing Drift case.
3. `CosmicMusicalFrameGenerator` — one ordered roll, following the Motorik pattern:
   `isKosmicDrift = roll < 0.30`, `isKosmicSpace = !isKosmicDrift && roll < 0.55`.
   **Split: Drift 30% / Space 25% / base 45%.** Then tempo and mode per above.
4. Thread `isKosmicSpace` through all seven Cosmic generators, as `isKosmicDrift` already is.
5. `instrumentPickPool` **and** `instrumentPickPoolStatic` — both. The static one is the one
   usually missed.
6. Add `sanitiseSpaceInstruments`, alongside the existing Blues/Noir/Drift sanitisers, so an
   instrument carried over from the previous song is replaced when outside Space's set.
7. Rule-ID → description map for every new ID: `KOS-DRUM-009`, `KOS-BASS-018`, `KOS-LEAD-013`,
   `KOS-LEAD-014`, `KOS-LEAD-015`, `KOS-RTHM-016`, `KOS-PADS-009`, `KOS-TEXT-005`,
   `KOS-DRUM-010`, `KOS-LEAD-016`.
8. `PersistedSong.displaySubstyleName` — the pre-build-125 inference list.
9. `ArrangementFilter` — exclude Rhythm from block-silencing when `isKosmicSpace`.
9a. **Arrangement arc** — per-track entry bars, the final-third withdrawal, and the
   reverse-order ending. This is new machinery, not a rule: it gates which bars each track
   emits into, above whatever its rule produces. Nearest existing analogue is
   `KOS-DRUM-010`'s gap set, which it should not double up with when that rule is active.
10. Endless-mode weighting — decide whether Space counts as Kosmic for the streak cap.

Generate a batch and listen before treating the 25% share as final.

---

## Reference: Kosmic Drift as the Implementation Model

Kosmic Space follows the same pattern as Kosmic Drift: a probabilistic substyle flag decided at
frame-generation time, separate musical constraints per track generator activated by that flag,
narrowed instrument pick pools, and `displayStyleName` returning the substyle name in the UI.
Drift also demonstrates the sanitiser pattern for carried-over instruments and the ordered-roll
approach to substyle selection, both reused directly here.

Expect several batches of listening tests across the full rule catalog, mode range and BPM
range before it is ready — the same process Arcade went through.
