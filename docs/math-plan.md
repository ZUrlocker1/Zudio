# Math Rock Style Generator — Research & Design Plan

## Context

Zudio currently has four styles: Motorik (krautrock), Kosmic (Berlin School), Ambient (Eno/drone),
and Chill (nu-jazz). This document proposes a fifth style: **Math Rock** — rooted in the
interlocking-guitar instrumental tradition running from Television (1977) through American post-punk
(Slint, Don Caballero) and Japanese math rock (Toe, Lite), with specific attention to the Quebec
band Angine de Poitrine as a contemporary reference.

The target is **melodic instrumental math rock** — angular, intricate, propulsive, clean-toned.
Two interlocking guitar voices are the defining instrument. No vocals. No jazz harmony. Not ambient.

**Scope constraint:** This document focuses on the melodic/clean-guitar lineage (Television →
Toe → Angine de Poitrine) rather than the abrasive/noise lineage (Shellac, Polvo). The melodic
lineage is far more implementable in MIDI and produces more listenable generative output.

---

## Part 1: What Is "Math Rock"? — Genre Definition

Math rock emerged from post-punk and art rock in the late 1980s, crystallizing around Chicago and
Louisville, Kentucky. The label is imprecise — most practitioners reject it — but the defining
characteristics are consistent across the lineage:

- **Rhythmic complexity** — odd time signatures (5/4, 7/8, 11/8), metric modulation, or complex
  syncopation within 4/4 that creates ambiguity about the downbeat
- **Interlocking guitar parts** — two guitar voices that pursue independent melodic/rhythmic
  trajectories and lock together like mechanical gears, not like melody-and-accompaniment
- **No functional harmony** — chord changes do not resolve tension; harmony is often post-punk
  static or moves in unexpected parallel motion; no ii-V-I logic
- **Stop-start phrasing** — sudden silences mid-phrase; rests are structural, not decorative
- **High rhythmic precision** — despite complexity, everything is metronomically exact
- **Instrumental or nearly so** — vocals, when present, are secondary to the instrumental texture
- **Clean or lightly overdriven guitar tones** (melodic lineage) — not metal distortion

**What math rock is NOT (for Zudio purposes):**
- Not ambient or drone — high note density, continuous rhythmic activity
- Not jazz — no swing feel, no II-V-I, no improvised solos in the conventional sense
- Not prog rock — sections are shorter, less theatrical, no extended solos over static backing
- Not post-rock — math rock does not build to climaxes with reverb swells; it stays angular
  and precise throughout

**The core MIDI-implementable identity:** Two independent melodic lines that interlock rhythmically,
over a bass that moves independently of both, over drums that subdivide the bar in unusual ways.
The texture is transparent — you can hear every voice clearly.

---

## Part 2: Artist-by-Artist Analysis

### Television — The Proto-Math-Rocker

**Albums studied:** Marquee Moon (1977)

Television are not a math rock band — they predate the genre and belong to New York art punk.
But Marquee Moon is the foundational document for two-guitar interplay in a rock context, and
every math rock guitarist knows it.

**Marquee Moon (the song, ~10 minutes):**
- BPM: approximately 130 BPM, straight 4/4 throughout
- Key: C major / C Mixolydian with excursions
- Structure: verse/chorus skeleton collapses progressively until the guitar solos take over
  and the song becomes an open field for the two guitars to converse for ~5 minutes
- Tom Verlaine (Lead 1): angular, long-breathed melodic lines; favors intervals of 4th and
  5th; phrases frequently end mid-bar, creating rhythmic displacement
- Richard Lloyd (Lead 2): more chordal, rhythmically supportive, but never just strumming;
  often plays single-note countermelodies against Verlaine's lead
- The two guitars never play the same thing simultaneously; they are always in dialogue
- Bass (Fred Smith): melodically active; does not merely double the root; frequently moves
  in contrary motion to the guitar lines; eighth-note driven
- Drums: straight rock but with unusual accent placements; Billy Ficca drops accents on
  unexpected subdivisions (not math rock complexity but not standard either)

**Other Marquee Moon album tracks:**
- "See No Evil": 130 BPM, riff-based, interplay evident from bar 1
- "Friction": faster (~145 BPM), more aggressive two-guitar conversation
- "Elevation": slower, more atmospheric; shows range of approach

**Harmonic language:**
- Major and minor tonality, but not functional — changes are not cadential
- Extended unison sections where both guitars play the same line (unison = unity, divergence = tension)
- Avoids blues clichés; closer to jazz phrasing without jazz harmony

**Generative lessons from Television:**
- The two-voice texture is the instrument: one angular melodic voice, one rhythmically
  interlocking counter-voice
- Phrases end at unexpected bar positions — the downbeat is not always phrase-end
- Contrary motion between guitar and bass creates depth without harmonic complexity
- 4/4 is fine; rhythmic interest comes from where phrases start and end, not from the time
  signature itself
- Unison passages (both guitars on same line) can be used as structural events (marks
  section boundaries, creates tension before divergence)

---

### Slint — The Bridge

**Albums studied:** Spiderland (1991)

Slint are the link between the Television lineage and proper math rock. Spiderland is the
direct ancestor of Don Caballero, Tortoise, and the entire Louisville/Chicago wave.

**"Spangle":**
- Riff in 5/4 (unusual for the time)
- Quiet/loud dynamics (later adopted wholesale by post-rock)
- Two guitar voices: one sustains chords, one plays single-note angular lines
- Bass: prominent, melodic, rhythmically independent

**"Good Morning, Captain":**
- 4/4, but riff phrasing crosses bar lines creating metric ambiguity
- Whispered vocals (not relevant for instrumental MIDI version)
- Guitar tone: almost completely clean; no distortion until the final climax

**Generative lessons from Slint:**
- Bar-crossing phrases (a riff that is 5 beats long played over 4/4) create math-rock feel
  without changing the time signature — implementable in 16-step grid
- Dynamic contrast (single instrument sustain vs full texture) is a structural event
- Clean guitar is the default math rock tone; distortion is reserved for climactic moments

---

### Don Caballero — The Purist

**Albums studied:** Don Caballero 2 (1995), What Burns Never Returns (1998)

Don Caballero are the ur-text of American math rock. Completely instrumental. Two guitars,
bass, drums, nothing else. Damon Che's drumming is the rhythmic center; the guitars are
deliberately irregular around it.

**Tempo & Time:**
- Constantly shifting time signatures within songs (7/8, 5/4, 4/4 sections in sequence)
- BPM typically 140–175 — faster than Television, more propulsive
- Damon Che plays with extreme precision; the polyrhythm is complex but never loose
- Guitar lines often imply a different meter than the drums — two simultaneous meters

**Harmonic language:**
- Almost no functional harmony; tonal center is implied by repetition, not by cadence
- Chords are power chords, open fifths, or single notes — rarely full triads
- Tonality: minor, or ambiguous (neither clearly major nor minor)
- Harmony serves rhythm, not the other way around

**Guitar texture:**
- Both guitars play single-note lines most of the time; chords are accents, not the texture
- Lines interlock: Guitar 1 fills Guitar 2's rests; they share the rhythmic density between them
- Large intervals dominate: 4ths, 5ths, tritones; 2nds and 3rds are passing tones

**Song structure:**
- No intro/verse/chorus/outro; instead: sections defined by time-signature or texture changes
- Section lengths: irregular (not 8 or 16 bars; more like 7, 11, 13 bars)
- Transitions: abrupt, without preparation; next section simply begins
- Total duration: 4–7 minutes typical

**Generative lessons from Don Caballero:**
- True odd time signatures (7/8, 5/4) require redesigning Zudio's bar structure — high cost
- The "bar-crossing riff in 4/4" approach (Slint method) produces similar perceptual effect
  at much lower implementation cost
- Single-note lines, not chords, are the primary texture
- Large intervals (4th, tritone, 5th) are the interval vocabulary, not scalar motion
- Two guitars share rhythmic density: when one rests, the other plays; the texture is
  always active, the individual voices are intermittent

---

### Toe — The Melodic Heir

**Albums studied:** The Book About My Idle Plot on a Vague Anxiety (2005),
                    For Long Tomorrow (2009)

Toe are a Tokyo four-piece who represent the melodic/accessible branch of math rock.
They are the bridge between the abrasive American tradition and a more song-like sensibility.
Their influence on younger math rock (including Quebec bands) is direct.

**Tempo & Time:**
- BPM range: 120–160; more varied than Don Caballero
- Mix of 4/4 and odd meters, but odd meters often feel organic rather than deliberate
- Frequent metric modulation: tempo feels like it shifts because the subdivision changes
  (e.g., 8th-note triplets at 160 BPM feel like a new tempo)

**Harmonic language:**
- More tonal than Don Caballero; actual chord changes (not just power chords)
- Minor and major modes both used; Dorian common
- Chord duration: 4–8 bars typical; harmonic rhythm is slow by rock standards
- Post-rock influence: some passages use lush reverb and layered guitar

**Guitar texture:**
- Guitar 1: melodic lead, single notes, lyrical and flowing
- Guitar 2: arpeggiated chords or complementary single-note line
- The interplay is more call-and-response than the dense interlocking of Don Caballero
- Occasional unison passages mark section boundaries

**Rhythm section:**
- Drums: highly melodic (Takashi Kashikura); fills are compositional, not ornamental
- Bass: often plays above the guitar in register; melodically independent

**Song structure:**
- More recognizable sections than American math rock: intro, development, peak, resolution
- Duration: 5–8 minutes typical
- Dynamic arc: starts sparse, builds to full texture, returns to sparse
- Endings: often fade or dissolve rather than hard stop

**Generative lessons from Toe:**
- The melodic lineage is more implementable: actual chord changes, actual melodic phrases
- Call-and-response between two guitars is simpler to generate than tight interlocking
- Chord-plus-arpeggiation (Guitar 2 arpeggiates while Guitar 1 leads) is a standard texture
- Dynamic arc (build/peak/dissolve) maps directly to Zudio's section model

---

### Angine de Poitrine — The Quebec Reference

**Background:**
Angine de Poitrine ("angina pectoris" in French) are a Quebec instrumental math rock band
operating in the 2010s–2020s. Khn de Poitrine (guitarist, the primary architect of their
sound) uses a loop pedal as a compositional instrument rather than a performance tool. Their
technique is closer to Meshuggah than to Don Caballero: they establish a rigid meter, then
use grouping shifts and polyrhythm games to create the illusion of time signature changes
while the underlying pulse never moves.

**Confirmed characteristics (MIDI analysis + performance study):**
- Loop-pedal based: every guitar part is a fixed-length repeating loop
- Melodic rather than abrasive; clean guitar tones, prominent microtonal pitch inflection
  (+17 cents constant offset on all guitar and bass tracks — see Part 9.7)
- French-Canadian melancholy: Aeolian and Dorian modal preference confirmed
- Bass is interval-loop model (octave + P5 + P4 arpeggiation — see Part 9.4)
- 8th-note hi-hat throughout; no quarter-note or 16th-note patterns
- Song durations: 5–9 minutes; dynamic arc from sparse layering to dense texture

---

**The "Locked-Length" Looping Technique**

This is the defining compositional method of ADP and the key to implementing their style in
Zudio. Unlike Television (interlocking composed phrases) or Don Caballero (through-composed
odd-meter), ADP builds music from a **fixed-duration container** (the loop pedal length) and
layers patterns of different phrase lengths inside it.

**Core principle:**
Once the loop length is set, it is a fixed physical duration. Every subsequent part must
fit exactly into that duration. The rhythmic complexity comes not from changing the loop
length but from choosing parts whose phrase lengths do not divide evenly into the container —
creating continuous drift and re-alignment within the fixed grid.

**The "SAS" example — hemiola via reinterpretation:**
- The loop is physically identical in length throughout the song
- Phase 1: the loop is counted as 4 bars of 12/8 — 48 eighth-note pulse units in a
  triplet-grouped feel (groups of 3 eighth notes = "1-2-3, 1-2-3, 1-2-3, 1-2-3")
- Phase 2: without changing the loop length, the groove shifts to 4/4 —
  the same 48 eighth notes are now re-grouped as "1-2-3-4, 1-2-3-4, ..." in straight feel
- Result: massive perceived energy shift; the listener hears a completely different time
  signature while the loop hardware never changed length
- This is a **hemiola** — two superimposed groupings of the same pulse stream

**The "prime number loop" technique:**
Instead of standard 4 or 8 bar loops, ADP records loops whose length is a non-standard
number of beats (often prime or irregular). A 17-beat loop layered with a 4-beat melody
drifts for 68 beats before re-aligning (LCM(17, 4) = 68). This continuous drift is the
"Dadaist" quality of their sound — the re-alignment event feels like a sudden structural
resolution after long ambiguity.

**The "silent recording" technique:**
Khn de Poitrine often records a loop silently (with the volume down) during one section,
then activates it suddenly when the section transitions. The audience hears an "impossible"
complexity appear instantaneously — it was already running, just inaudible.

**Generative lessons:**
- The unit of composition is the **loop container length**, not the bar
- Container length should be a non-power-of-2 number of steps (e.g., 24, 28, 48) that
  does not divide evenly into Zudio's 16-step bar
- Multiple voices loop at different periods within the same container
- Phase 1 → Phase 2 transitions are implemented by changing accent/grouping positions
  within the same step positions — not by adding or removing notes
- The "silent recording" technique maps to pre-generating a voice at near-zero velocity
  and ramping it up at a section boundary

---

## Part 3: Universal Math Rock Rules (What All Share)

These are the non-negotiable characteristics for any generated piece to sound like math rock
rather than like one of the other Zudio styles.

**1. Two independent melodic voices**
- Lead 1 and Lead 2 pursue separate trajectories; they do not play in unison except
  at structural moments (section boundaries, climaxes)
- When Lead 1 holds a note, Lead 2 moves; when Lead 2 rests, Lead 1 fills
- The combined density of the two voices stays roughly constant; individual voices are intermittent

**2. Large intervals as primary vocabulary**
- Interval of 4th (5 semitones): most common melodic step
- Interval of 5th (7 semitones): structural leaps, phrase-opening moves
- Tritone (6 semitones): tension marker, used at phrase peaks
- Interval of 2nd (1–2 semitones): used as passing motion only, not melodic goal
- Minor 3rd is acceptable; major 3rd is used sparingly
- Octave leaps: used for register changes, not as melodic intervals

**3. Rhythmic displacement / bar-crossing phrases**
- Phrases do not begin on beat 1 of the bar; they begin on beat 2, the "and" of 3, etc.
- Phrases do not end on beat 4 of the bar; they cross bar lines
- A riff of 5 or 7 beats played in 4/4 creates metric ambiguity without changing time signature
- This is the single most important "math rock feel" generator and is fully compatible with
  Zudio's 16-step grid

**4. Stop-start phrasing (rests are structural)**
- Phrases are followed by rests of at least 1 beat before the next phrase begins
- Rests are not empty space — they are rhythmic events; the silence is felt as part of the pattern
- Suggested minimum rest length between phrases: 1–3 16th-note steps

**5. Static or slowly-moving harmony**
- Chord changes every 8–16 bars (much slower than rock's 2-bar changes)
- No functional cadences (no V→I resolution)
- Minor modes preferred: Aeolian (darkest), Dorian (slightly warmer), Phrygian (most angular)
- Chord voicings: open fifths (power chords) or two-note voicings rather than full triads
- Occasional sus2 or sus4 for ambiguity

**6. Bass independence**
- Bass does NOT double the guitar rhythm
- Bass moves in different subdivision from guitars (guitars in 16ths, bass in 8ths, or vice versa)
- Bass often plays above expected register for the genre — melodically active
- Bass to guitar contrary motion: when guitars ascend, bass may descend

**7. High rhythmic precision, zero swing**
- Everything on the grid; no shuffle or swing
- Quantized to 16th notes (or 8th-note triplets if implementing metric modulation)
- The precision IS the feel; "looseness" would destroy the math rock aesthetic

**8. Transparency of texture**
- Never more than 4–5 voices at once
- No thick pad layers, no orchestral density
- Each voice is audible as a distinct line
- Reverb and effects are present but do not obscure lines (vs. post-rock's reverb walls)

---

## Part 4: Math Rock vs. Other Zudio Styles

- **vs Motorik:** Math rock has comparable tempo (130–170 BPM vs 126–154) but completely
  different feel — Motorik has an unwavering pulse; math rock has rhythmic ambiguity and
  displacement. Motorik uses arpeggios/pads; math rock uses two-voice counterpoint.
  Motorik is hypnotic and forward-moving; math rock is angular and surprising.

- **vs Kosmic:** Opposite poles. Kosmic: slow, static, inward, timbre-primary.
  Math rock: fast, active, outward, rhythm-primary. Kosmic avoids large intervals;
  math rock depends on them. Kosmic has no drums or sparse pulse; math rock has complex,
  precise drums.

- **vs Ambient:** Also opposite. Ambient: no pulse, no rhythm, no events. Math rock:
  all pulse, all rhythm, constant events. The only shared characteristic is modal tonality.

- **vs Chill:** Chill uses jazz harmony (extensions, ii-V, modal jazz). Math rock uses
  no jazz harmony whatsoever. Chill has swing feel and melodic lead instruments (trumpet,
  sax). Math rock has zero swing and guitar-only leads. Both are groove-based, but Chill's
  groove is relaxed; math rock's groove is tense. Both are often 4/4, but Chill's 4/4 is
  comfortable; math rock's 4/4 feels unstable.

---

## Part 5: The Odd-Time Question — Implementation Strategy

The most fundamental design decision for a Zudio math rock generator is **whether to implement
odd time signatures**. This choice drives all subsequent architecture decisions.

### Option A: 4/4 with rhythmic displacement

Use Zudio's existing 16-step-per-bar grid. Achieve math-rock feel through:
- Bar-crossing phrases (riffs of 5, 6, 7, 9 or 10 steps played in a 16-step bar)
- Phrases starting on non-downbeat steps
- Stop-start rests between phrases
- Independent bass and drum rhythms

- **Pros:** No changes to StepScheduler, PlaybackEngine, or bar structure. Implementable
  with existing generator architecture. Perceptually math-rock without structural math.
- **Cons (original assessment):** Lacks true odd-meter character; would not sound like
  Don Caballero. Television and Toe can be approximated; Slint "Spangle" in 5/4 cannot.

### Option B: Fixed odd time signature (5/4 or 7/8)

Change the step count per bar to 20 (for 5/4) or 14 (for 7/8) for the math rock style.
Requires changes to StepScheduler's steps-per-bar assumption.

- **Pros:** Immediately sounds like math rock. True 5/4 = immediately distinctive.
  One time-signature choice; no mid-song switching.
- **Cons:** Requires StepScheduler changes. Visualizer bar-progress display breaks.
  Tempo-to-bar calculations change throughout the engine.

### Option C: Mixed meters (section by section)

Different sections use different time signatures. Most authentic to Don Caballero.

- **Pros:** Most authentic. Genuinely surprising.
- **Cons:** Highest engineering cost. Requires real-time meter changes mid-song.
  Out of scope for a first implementation.

---

### Part 5 Addendum: Option A Validated — Phrase Phasing Captures Odd Meter Perceptually

**Research question:** Can 7/4, 5/4, 7/8 etc. be mapped into Zudio's 16-step bar structure
in a way that sounds genuinely math rock? The answer is yes — and the mechanism is well-understood
in music theory as **metric phase cycling**.

#### The core insight

When a riff of odd length N is played repeatedly inside a 4/4 grid, it shifts its starting
position within the bar by `N mod 16` steps on each repetition. This creates the perception of
metric ambiguity — the riff "floats" against the bar grid, landing on different beats each time.
This is not an approximation of odd meter; it is what odd meter SOUNDS LIKE from the inside.

At high enough tempos (130+ BPM), and without strong harmonic downbeat anchors, the listener
cannot distinguish a 7-note phrase cycling in 4/4 from a true 7/4 bar. The perceptual cue for
"what time signature is this?" is not the bar structure — it is phrase length and accent placement.

#### The math: phase cycling of odd-length phrases

For a phrase of length P steps played in a 16-step bar:
- Repetition 1: starts at step 0 (bar 0, beat 1)
- Repetition 2: starts at step P within the absolute timeline
- The phrase returns to bar alignment after `L = LCM(P, 16)` absolute steps = `L/16` bars

**Key phrase lengths and their cycle durations:**

- P=5 (5 steps = 1.25 beats): cycles every 16 bars (5 reps of phrase); short, fast-spinning
- P=6 (6 steps = 1.5 beats): cycles every 8 bars (very fast, 8 reps)
- P=7 (7 steps = 1.75 beats): cycles every 16 bars (16 reps)  ← core math rock phrase
- P=9 (9 steps = 2.25 beats): cycles every 16 bars (16 reps)
- P=10 (10 steps = 2.5 beats): cycles every 8 bars
- P=12 (12 steps = 3 beats): cycles every 4 bars (not interesting — too regular)
- P=14 (14 steps = 3.5 beats): cycles every 8 bars  ← ADP Fabienk's actual cycle
- P=28 (28 steps = 7 beats = 7/4): cycles every 7 bars (4 reps)  ← Don Caballero's riff length

The 7/4 song is simply a P=28 phrase in a 16-step bar: it repeats every 7 bars and begins
on a different beat of the bar each time. Don Caballero's 7/4 metric structure maps EXACTLY
to this, with the same note-position output.

#### Architecture confirmation

Zudio generators already support this natively. They iterate all bars themselves (`for bar in
section.startBar..<section.endBar`) and compute `barStart = bar * 16`. An odd-meter generator
needs only one additional computation:

```swift
let phraseLength = 28  // 7 beats × 4 steps/beat = 7/4
for bar in section.startBar..<section.endBar {
    let barStart = bar * 16
    // Where in the phrase does this bar begin?
    let phraseOffset = (bar * 16) % phraseLength
    for step in 0..<16 {
        let phrasePos = (phraseOffset + step) % phraseLength
        // emit note if phrase[phrasePos] is active
    }
}
```

No StepScheduler changes. No bar structure changes. The 16-step grid is preserved. The
scheduler, PlaybackEngine, and all UI components are untouched.

#### When Option A is NOT sufficient

Phrase phasing works perceptually only when:
1. **No strong harmonic downbeat anchor** — if the chord changes on bar 1 every time,
   the listener hears the 4/4 bar, not the phrase cycle. Don Caballero avoids this with
   a permanent pedal bass. A generator for this model must also avoid bar-aligned chord changes.
2. **No bar-1 kick** — if the kick always hits on step 0, the 4/4 pulse is marked and the
   phrase phasing is perceived as syncopation rather than meter. Don Caballero's anti-metric
   kick (never on a downbeat) is what makes the 7/4 feel genuine. A generator must replicate
   the off-beat kick.
3. **Phrase length must be odd relative to 16** — phrases of 4, 8, or 16 steps have no
   displacement effect; they realign immediately. Phrases of 5, 6, 7, 9, 10, 11, 13, 14 all
   produce the desired phasing.

If a song has slow harmonic changes (every 8+ bars) and no bar-1 kick anchor, Option A
produces genuine odd-meter perception, not an approximation of it.

#### Verdict

**Option A covers everything in the corpus.** Television (4/4 with phrase displacement),
Toe (4/4 with step-14 pickups), Slint (4/4 with chromatic bass), ADP Fabienk (P=14 phrase
cycle), and Don Caballero (P=28 phrase cycle with no harmonic anchoring and anti-metric kick)
are all fully implementable within Zudio's 16-step grid. Option B and Option C remain
available for future work but are not required for a compelling first version.

### Recommendation

**Option A, using phrase phasing** — no scheduler changes required. The key generator
rules are:
- Choose phrase length P from {5, 6, 7, 9, 10, 11, 14, 28} weighted toward 7 and 14
- Track `phraseOffset = (bar * 16) % P` within the bar loop
- Do not place chord changes on bar 1 of repeating sections (avoids 4/4 anchoring)
- Do not place kick on step 0 of any bar (anti-metric kick = the sound)

---

## Part 6: Proposed Generator Design

### 6.1 MathMusicalFrameGenerator

**Tempo:** Bimodal distribution
- Mode A (60%): 140–165 BPM triangular, peak 152 — Don Caballero / active math rock
- Mode B (40%): 120–142 BPM triangular, peak 132 — Television / Toe / atmospheric

**Keys:** Angular keys slightly favored
- E (18%), A (16%), D (14%), B (10%), G (10%), F# (8%), C (8%), others split remaining 16%
- Minor modes heavily favored; root is the same; mode determines feel

**Modes:**
- Aeolian 45% — dark, most math rock
- Dorian 30% — warm darkness (Toe, Quebec bands)
- Phrygian 15% — angular, tritone-heavy, most abrasive
- Mixolydian 10% — rare, used for brighter sections

**Progression families:**
- `static_tonic` 40% — single chord for 8–16 bars; all interest from rhythm and melody
- `two_chord_angular` 30% — two chords a 4th or tritone apart, alternating every 8 bars
- `modal_descent` 20% — stepwise movement: i → bVII → bVI → bVII → i over 16 bars
- `power_chord_riff` 10% — 3-chord riff (i, bVII, bVI) cycling every 4 bars (faster movement)

**Song length:** Triangular distribution min=180s, peak=270s, max=360s

---

### 6.2 MathStructureGenerator

**Song forms:**
- `through_developed` 45% — continuous development with no repeated sections; closest to
  Don Caballero model; high rhythmic complexity throughout
- `arc_form` 40% — sparse intro → build → dense peak → sparse outro; Toe / Quebec model;
  more dynamic range
- `riff_cycle` 15% — 2–3 riffs alternated with variations; most accessible; Television model

**Section lengths:** 12–32 bars (shorter than Kosmic; more events per unit time)

**Section intensity levels:**
- `sparse` — single guitar voice + bass (no drums); used for intros and transitions
- `medium` — one guitar + bass + drums; second guitar absent or very sparse
- `full` — both guitars + bass + drums; maximum density

**Transitions:** Abrupt (no fill, no ramp); next section begins on beat 1 of the bar immediately
following the previous section. The abruptness IS the math rock transition style.

---

### 6.3 MathLeadGenerator (two voices)

This is the core of the style. Unlike other Zudio styles where Lead 1 is primary and Lead 2
is secondary, in math rock both voices are equal and interdependent.

**Lead 1 (primary):**
- Plays angular melodic phrases of 4–8 notes
- Phrase length in steps: 5, 6, 7, or 9 steps (never exactly 4 or 8 — bar-displacement rule)
- Phrase start position: offset from bar start (steps 2, 3, 5, 6, 10 — never step 0 except
  at section boundaries)
- Rest between phrases: 2–4 steps minimum
- Interval vocabulary: P4 (5 semitones) 35%, P5 (7 semitones) 20%, tritone 15%,
  m3 10%, M3 8%, octave 7%, m2 5%
- Velocity: 80–110, no dynamics within a phrase (consistent attack = mechanical precision)

**Lead 2 (countervoice):**
- Plays during Lead 1's rests; rests during Lead 1's longer phrases
- When Lead 1 sustains, Lead 2 moves; when Lead 1 moves, Lead 2 holds or rests
- Phrase lengths: 3–6 steps (shorter than Lead 1)
- Interval vocabulary: same as Lead 1
- May play the same note as Lead 1 at section boundary bars (unison = structural marker)
- Velocity: 70–95 (slightly quieter than Lead 1; the countervoice recedes slightly)

**Unison rule:**
- On bar 1 of a new section, both voices may play the same line for 4–8 steps before
  diverging — marks the section change and gives the ear a reference point

---

### 6.3b ADP Locked-Length Generator Model (sub-style)

When the generator selects the ADP model, it uses a different compositional logic than
the Television or Don Caballero models. The unit of composition is the **container** —
a fixed-length loop whose length is the organizing principle of the whole song.

**Step 1 — Choose a container length C:**

- C=24 (1.5 bars): 12/8 feel; fast re-alignment with 4/4 in 12 bars; most consonant
- C=28 (1.75 bars): 7/4 feel; re-aligns after 7 Zudio bars; medium tension
- C=48 (3 bars): "SAS" type; 12/8 → 4/4 hemiola shift available; re-aligns after 3 bars
- C=68 (4.25 bars): prime-loop; re-aligns after 17 Zudio bars; longest drift; most "Dadaist"

Weighted distribution: C=28 (40%), C=24 (30%), C=48 (20%), C=68 (10%)

**Step 2 — Assign each voice a phrase length P:**

Each voice loops its phrase independently. P must not equal C (no instant re-alignment):
- Bass: P = C (bass IS the container; it defines the anchor)
- Guitar Loop 1: P = 7 or 9 (shorter than C; fast drift against bass)
- Guitar Loop 2: P = 4 or 6 (even shorter; creates additional cross-layer texture)
- Melody (Layer 5): P = 14 or 11 (longer phrases; slower drift; more lyrical)

The drift speed = how quickly each pair of voices moves through their phase cycle.
Fast drift (small P against large C) = dense polyrhythmic texture.
Slow drift (P close to C) = gradual metric evolution.

**Step 3 — Implement hemiola shift (the "SAS" technique):**

If C=48 is chosen, the song may contain a hemiola transition. Implementation:
- Phase 1 (first N bars): accent guitar notes on steps 0, 6, 12, 18, 24, 30, 36, 42
  within each 48-step container (every 6 steps = dotted-quarter feel = 12/8 grouping)
- Phase 2 (after transition bar): accent guitar notes on steps 0, 8, 16, 24, 32, 40
  within the same 48-step container (every 8 steps = quarter-note feel = 4/4 grouping)
- The bass loop and step timing do not change — only the accent positions shift
- The listener hears a meter change; the step grid stays fixed at 16 steps/bar

Velocity implementation of accents: primary accent = velocity 90–100; non-accented
notes on the grid = velocity 55–65. The "shift" is a velocity redistribution, not a
note-on/note-off change. Any notes already placed can stay; their velocity values change.

**Step 4 — Implement "silent loop" entry:**

On section transitions, one guitar layer may enter at velocity 5–10 for the first 2–4 bars
(barely audible, establishing phase position), then ramp to full velocity at the section
peak. This creates the ADP "impossible entrance" effect — the part seems to arrive fully
formed because the ear didn't consciously register it building in.

**Step 5 — Apply pitch bend (+17 cent offset):**

All guitar voices send a MIDI pitchwheel value of +682 (= +17 cents) one tick before each
note-on. The melody voice (Layer 5 equivalent) uses random variation between +682 and
+2730 (17–67 cents) per note. Bass applies the same +682 offset. See Part 9.7 for full
pitch bend implementation.

---

### 6.4 MathBassGenerator

- Plays in 8th notes primarily (not 16th); the guitars fill the 16th-note subdivisions
- Root position mostly, but uses passing tones on weak beats
- Contrary motion to Lead 1 as often as possible (if Lead 1 ascends, bass descends)
- No fills; minimal ornamentation; the bass defines the harmonic center, not the melody
- Occasional pedal point (same note for 4–8 bars) under harmonic changes above

---

### 6.5 MathDrumGenerator

- **Kick:** Syncopated; does NOT fall on all 4 beats; typical pattern has kick on beat 1
  and one unexpected position per bar (beat 2-and, beat 3, etc.)
- **Snare:** Backbeat on 2 and 4 as default, but with ghost notes on adjacent 16th steps
- **Hi-hat:** 16th-note pattern but with deliberate velocity variation (not all the same
  velocity — accents on unexpected subdivisions)
- **Rim shots / cross-stick:** Used in sparse sections as primary "snare" sound
- **No brushes; no jazz swing feel** — this is a rock kit played with precision

---

## Part 7: MIDI Analysis Findings

Seven MIDI files were analyzed using Python mido: per-track note profiling, interval
distribution, onset step mapping (position within a 16-step bar), and time-signature
extraction. Files analyzed:

- Television — "See No Evil" (Marquee Moon, 1977)
- Television — "Marquee Moon" (Marquee Moon, 1977)
- Angine de Poitrine — "Fabienk"
- Angine de Poitrine — "Sarniezz"
- Toe — "Goodbye" (The Book About My Idle Plot, 2005)
- Toe — "My Longest Wish" (For Long Tomorrow, 2009)
- Slint — "Good Morning Captain" (Spiderland, 1991)

---

### 7.1 Television — "See No Evil"

**Tempo:** 150 BPM  
**Time signature:** 4/4; brief 3/4 insertions (1–2 bars) mid-song

**Verlaine (Lead 1) — interval profile:**
- P4 (5 semitones) 32%, P5 (7 semitones) 28%, octave (12) 20%, m3 8%, M3 5%
- Combined large-leap total: 80%
- Onset concentration: steps 0 (342 hits), 2 (332), 6 (270) — front-loaded; phrases anchor on beat 1 and beat 1-and

**Lloyd (Lead 2) — interval profile:**
- M2 (2 semitones) 43%, unison 19%, m2 (1 semitone) 18%, m3 12%, P4 8%
- Combined step/unison total: 80%
- Almost entirely contrary to Verlaine's vocabulary

**Key finding:** The two-voice contrast is near-perfectly complementary — one voice is
entirely leap-based, the other is entirely step-based. This is not stylistic coincidence;
it is the structural identity of the two-guitar grammar. The generators must encode this
as a hard asymmetry, not just different probability weights.

---

### 7.2 Television — "Marquee Moon"

**Tempo:** 122 BPM  
**Time signature:** 4/4; brief 3/4 insertions (tempo-feel modulation, not structural)

- Same two-voice architecture as "See No Evil" — leap voice + step voice
- Longer phrase lengths at slower tempo (8–12 note phrases vs 4–8 in SNE)
- More passages where both voices pause simultaneously; structural silence is more frequent
- Bass (Fred Smith): contrary motion to guitars confirmed; melodically active at 8th-note grid

---

### 7.3 Angine de Poitrine — "Fabienk"

**Tempo:** 128 BPM  
**Time signature:** 14-beat repeating cycle = 3 bars of 4/4 + 1 bar of 2/4

**Loop stacking:** Guitar 1, Guitar 2, and Bass all share root motion G→D→A→E at a perfect
8th-note grid. Onset counts per even step were exactly equal (84 hits per step across all
three tracks) — mechanical loop alignment, not coincidence. All three voices independently
loop the same root-motion framework at different phrase lengths.

**Bass interval profile:** octave 25%, P5 18%, P4 14% — perpetual arpeggiation: root, then
fifth, then octave, cycling independently of the guitars

**Drums:** steady 8th-note hi-hat

**Key finding:** ADP's primary technique is loop stacking — multiple voices looping
independently at the same harmonic framework. The odd bar length (14 beats) produces the
math-rock metric displacement without requiring true polyrhythm. The 14-beat cycle is
entirely implementable as Option B (fixed odd-length loop: 14 steps × 2 = 28 per cycle,
or treated as 3.5 bars of 16 steps = 56 steps per full cycle).

---

### 7.4 Angine de Poitrine — "Sarniezz"

**Tempo:** 145–174 BPM (variable; accelerating sections)  
**Time signatures used:** 12/8, 6/4, 5/4, 3/8 — genuinely mixed meter throughout

- Bass + Guitar Loop 1 share D→Eb→E→G chromatic figure: m2 + M2 motion (semitone + whole-tone)
- More through-composed than Fabienk; less loop-stacked, more contrapuntal
- At 174 BPM the 8th-note hi-hat creates extreme forward drive; the time-sig changes provide
  rhythmic surprise without slowing down

**Key finding:** Sarniezz is Option C territory — true mixed meter. It confirms that ADP
uses mixed meter as a core technique, but also confirms this is high-implementation-cost.
For a first math rock generator, Fabienk's 14-beat cycle is the accessible ADP model.

---

### 7.5 Toe — "Goodbye"

**Tempo:** 138 BPM  
**Time signature:** 4/4

- **Bass:** unison 80% — root-locked; stays tightly on the root note, adding only
  occasional octave displacements; near-pedal behavior
- **Step 14** (beat 4-and of bar) prominent as pickup note — phrases launch from beat 4-and
  into the next bar, creating bar-crossing entry points
- **Hi-hat:** 8th-note pattern — forward drive
- Two guitar voices follow Television's leap/step grammar but with more lyrical, longer phrases

**Key finding:** Toe's bass provides harmonic stability (root-locked) while the guitars
handle all rhythmic displacement. This is the opposite of Slint (where bass is the
melodically active voice). The two models are complementary and both valid for the generator.

---

### 7.6 Toe — "My Longest Wish"

**Tempo:** 171 BPM  
**Time signature:** 4/4 with brief 9/8 insertions (1–2 bars)

- Same bass root-anchoring as "Goodbye"
- At 171 BPM, 8th-note hi-hat has maximum forward drive
- Brief 9/8 insertions create momentary displacement without restructuring the whole song —
  the insertion lasts 1 bar, then 4/4 resumes as if nothing happened

**Key finding:** Odd-meter insertions of 1–2 bars within otherwise 4/4 songs (Toe's
approach) are a viable bridge between Option A and Option B — single displacement bars
rather than full meter changes. This is implementable without StepScheduler restructuring:
one bar has 18 steps (9/8) instead of 16, which is a one-time extension, not an ongoing change.

---

### 7.7 Slint — "Good Morning Captain"

**Tempo:** 100 BPM  
**Time signature:** 4/4 (straight throughout; no meter insertions)

- **Bass:** m2 36%, unison 33% — chromatic crawl; entirely different from Toe's root-locking;
  the bass is the most melodically active voice in the texture
- **Hi-hat:** quarter-note pattern — one hit per beat, nothing more; creates the menacing,
  spacious feel that Spiderland is built on
- Much slower than all other files analyzed; 100 BPM is the floor of the math-rock range

**Key finding:** Slint's quarter-note hi-hat is the single most distinctive drum characteristic
in the corpus. Sparse hi-hat + chromatic bass + angular guitar = the Slint sound. These three
elements together, and only together, produce it; individually they are insufficient.

---

### 7.8 Don Caballero — "Fire Back About Your New Baby's Sex"

**Tempo:** 120 BPM  
**Time signatures (sequential):**
- 8/4 — 2 bars (opening; 8 beats = two common-time bars joined)
- 7/16 — 1 bar (transitional splice)
- 21/16 — 1 bar (= 3×7/16; extended transition)
- **7/4 — 13 bars (the main body of the song)**

The song lives in 7/4. Seven quarter-note beats per bar = 28 16th-note steps. There is
no 4/4 anywhere in the body of the song. This is Option C (true mixed meter) confirmed.

**Guitar voices (Tracks 1 and 2) — interval profiles:**
- Track 1: M2 44%, P5 43%, Unison 7%, P4 6%
- Track 2: P5 44%, M2 44%, Unison 6%, P4 6%

Both guitars use nearly identical vocabulary — equal parts large leap (P5) and stepwise
motion (M2). This is the opposite of Television's leap/step split. Don Caballero's two
guitars are not differentiated by interval type; their interlock is rhythmic, not tonal.

**Track 3 (textural/riff guitar) — directional intervals:**
- Unison +0: 30%, up P5 (+7): 18%, down P5 (−7): 18%, up M6 (+9): 13%, down M6 (−9): 13%

Track 3 is a pendulum riff: one anchor note, symmetric leaps up and down a fifth or major
sixth, returning to the anchor. The M6 (9 semitones) is a distinctively large interval not
prominent in Television, Toe, Slint, or ADP — it is characteristic of Don Caballero's wider
harmonic palette.

**Bass (Track 4) — extreme pedal point:**
- E2: 46%, E1: 46% — the bass plays a single pitch (E) alternating between two octaves
- Unison 90% in interval analysis = all octave jumps between E1 and E2
- Zero harmonic movement for the entire song. The bass is a pedal engine, not a melodic voice.
- Range: E1–F#2; occasional B1 and F#2 on transitions only

**Percussion — kick avoids all downbeats:**
- Open hi-hat (MIDI 46): 37% of all hits — dominant; 16th-note pattern
- Kick (MIDI 36): 30% of hits — hits ONLY on the "e" and "ah" 16th subdivisions
  (steps 1, 3, 5, 7, 9, 11… in a 32-step grid) — never on any beat downbeat or "+"
- Snare: ~22% of hits

The kick pattern is the most extreme finding in the corpus. By landing exclusively on the
2nd and 4th 16th note of every beat (never the 1st or 3rd), Damon Che creates a kick that
has no relationship to any conventional pulse. The kick is purely anti-metric.

**Pitch bends:** Zero (none in any track)

**Key findings:**
- Don Caballero's primary grammar is 7/4, not 4/4. Option A (4/4 with displacement) cannot
  approximate this song — the bar length IS the odd meter.
- Both guitars use the same interval vocabulary (P5 + M2 in equal measure) — no leap/step
  split; interlock is rhythmic only
- Bass = single-note pedal across two octaves for the entire song
- Kick avoids all downbeats — pure rhythmic displacement at the percussion level
- M6 (major sixth = 9 semitones) as a structural interval is unique to Don Caballero in
  this corpus; add it to the interval vocabulary for the Don Caballero model

---

### 7.9 Cross-File Confirmed Rules

**Tempo range:** 100–174 BPM across all eight files. Bimodal distribution from Part 6.1
is validated; add a third mode for the Slint floor (see Part 9 calibration). Don Caballero
at 120 BPM is slower than expected for the most "extreme" band — but in 7/4, 120 BPM
produces a bar duration of 3.5 seconds, which feels dense because of the non-standard meter.

**Two-voice split — Television model vs Don Caballero model:**
- Television: Lead 1 is leap-only (P4/P5/octave), Lead 2 is step-only (M2/m2/unison) —
  hard asymmetry; the two voices have entirely different grammars
- Don Caballero: both guitars use equal P5 and M2 (44%/44%) — symmetric vocabulary;
  no intervallic differentiation; interlock is rhythmic, not tonal
- These are two different two-guitar grammars; a generator should choose one per song

**Hi-hat models — three archetypes confirmed:**
- Quarter-note (Slint): one hit per beat; sparse; angular; menacing
- 8th-note (Toe, ADP): driving; standard math rock forward motion
- 16th-note open hi-hat (Don Caballero): every 16th step, open hi-hat; creates a wash of
  cymbal activity that blurs the pulse while the kick displacement does the rhythmic work

**Bass models — four archetypes confirmed:**
- Root-locked / pedal (Toe): unison 80%; stability under guitar displacement
- Chromatic crawl (Slint): m2 + unison dominant; bass is the melodic voice
- Interval-loop (ADP Fabienk): octave + P5 + P4 arpeggiation; perpetual-motion engine
- Octave-pedal (Don Caballero): single pitch in two octaves; E2/E1 46%/46%; bass as
  harmonic anchor only; the most static bass in the corpus

**Onset step concentration:**
- Television Verlaine: steps 0, 2, 6 dominant (front half of bar, downbeat-anchored)
- Toe: step 14 as pickup (back end of bar, into next-bar phrase entry)
- Slint: even distribution across all steps (no concentration)
- ADP Fabienk: perfectly even 8th-note grid (steps 0, 2, 4, 6, 8, 10, 12, 14 equal)
- Don Caballero: flat distribution across all 28 steps of the 7/4 bar (no preferred position)

**Kick patterns — two archetypes confirmed:**
- Standard backbeat-variant (Television, Toe, Slint): kick lands on or near beats 1 and 3;
  some syncopation but beats are marked
- Anti-metric (Don Caballero): kick NEVER lands on a beat downbeat; exclusively on "e" and
  "ah" subdivisions; the kick has no relationship to any conventional pulse

**Time signature distribution (confirmed across all eight files):**
- Straight 4/4: Television "Marquee Moon", Toe "Goodbye", Slint (Option A fully covers these)
- 4/4 with single displacement bars: Television "See No Evil" (3/4 inserts), Toe "My Longest
  Wish" (9/8 inserts) — Option A plus occasional displacement bar
- Fixed odd cycle: ADP "Fabienk" (14-beat cycle = Option B variant)
- True mixed meter throughout: ADP "Sarniezz" (12/8, 6/4, 5/4, 3/8), Don Caballero 7/4 —
  Option C; not implementable without StepScheduler restructuring

---

## Part 9: Generator Calibration Updates (from MIDI Data)

These revisions supersede the provisional numbers in Part 6 wherever they conflict.

---

### 9.1 Lead 1 Interval Weights (revised from Television SNE Verlaine)

Part 6.3 had Lead 1 at P4 35%, P5 20%, octave 7%. Octave was significantly underweighted.

**Revised Lead 1 (leap voice):**
- P4 (5 semitones): 32%
- P5 (7 semitones): 25%
- Octave (12 semitones): 18%
- m3 (3 semitones): 10%
- M3 (4 semitones): 8%
- Tritone (6 semitones): 5%
- m2 / M2 (1–2 semitones): 2% (chromatic approach only; not melodic goals)

---

### 9.2 Lead 2 Interval Weights (CORRECTED — entirely new)

Part 6.3 said Lead 2 uses "same interval vocabulary as Lead 1." This is wrong.
The MIDI data from Television SNE shows Lead 2 is a fundamentally different voice.

**Revised Lead 2 (step voice):**
- M2 (2 semitones): 40%
- Unison (0 semitones): 20%
- m2 (1 semitone): 18%
- m3 (3 semitones): 12%
- P4 (5 semitones): 8%
- P5 and above: 2% total

Lead 2 moves in small steps and repeated notes. Lead 1 moves in leaps. These are not
variations of the same voice; they are different instruments with different grammars.

---

### 9.3 Hi-Hat Model (CORRECTED)

Part 6.5 said "16th-note pattern with velocity variation." No analyzed file uses a
sustained 16th-note hi-hat. Two correct models:

- **8th-note hi-hat (60% of songs):** Toe, ADP model; steady 8th on every even step
- **Quarter-note hi-hat (30% of songs):** Slint model; one hit per beat (steps 0, 4, 8, 12);
  creates maximum spaciousness
- **16th-note hi-hat (10% of songs):** reserved for climactic peak sections only; not the
  default texture

---

### 9.4 Bass Model Selection (3-way, not continuous)

Choose one model per song; do not blend within a song:

- **Root-locked** (40% of songs): Toe model; unison + octave dominant; stays on chord
  root; provides stability under angular guitar displacement
- **Chromatic-crawl** (30% of songs): Slint model; m2 + unison dominant; bass is the
  melodic lead; guitars above become more rhythmic
- **Interval-loop** (30% of songs): ADP Fabienk model; octave + P5 + P4 arpeggiation
  cycling; perpetual-motion feel; works best with loop-stacked guitar textures

---

### 9.5 Tempo Distribution (revised with three modes)

Confirmed range 100–174 BPM across all seven files:

- **Mode A** (50%): 140–165 BPM, triangular peak 150 — Toe / ADP active math rock
- **Mode B** (35%): 122–140 BPM, triangular peak 130 — Television / ADP Fabienk
- **Mode C** (15%): 100–122 BPM, triangular peak 110 — Slint-model; sparse, menacing;
  pair with quarter-note hi-hat and chromatic-crawl bass for full Slint character

---

### 9.6 Onset Step Distribution by Model

- **Television / Lead 1 style:** weight steps 0, 2, 6 higher for phrase starts; phrases
  are front-loaded and anchor on or near beat 1
- **Toe style:** weight step 14 as pickup; phrases cross the bar line from beat 4-and
- **Slint / ADP style:** flat distribution; no step weighting; all steps equally likely

---

### 9.7 Pitch Bend Analysis (CONFIRMED FROM MIDI DATA)

Pitch bend events were extracted from all seven files. Results:

**Angine de Poitrine "Fabienk":** 1,499 pitch bend events across 5 tracks
- Layers 2, 1, Bass: +16.7 cents (MIDI value 682 = exactly 1/12 of full range = 1/6 semitone)
- Layer 4: up to +33.3 cents (MIDI 1365 = 1/6 of range = 1/3 semitone)
- Layer 5 (lead): up to +66.7 cents (MIDI 2730 = 1/3 of range = 2/3 semitone)
- All bends are upward only (minimum pitch = 0; never below equal temperament)

**Angine de Poitrine "Sarniezz":** 3,810 pitch bend events across 5 tracks
- All 5 tracks: uniform +16.7 cents (MIDI 682) applied to most notes
- Bass Loop has the highest density (1,014 bends)
- Same systematic +1/6-semitone offset as Fabienk

**Television "See No Evil":** 505 pitch bend events — solo passages only
- Richard Lloyd (rhythmic part): up to +16.7 cents
- Richard Lloyd Solo: up to +66.7 cents
- Verlaine's lines: zero bends (the leap voice is pure chromatic, no pitch inflection)

**Television "Marquee Moon":** 624 pitch bend events — guitar solos only
- Both solo tracks: -20.7 to +83.3 cents (wide expressive range; these are the long solos)

**Toe "Goodbye", Toe "My Longest Wish", Slint "Good Morning Captain":** Zero pitch bends

**Interpretation:**
- ADP's microtonality is **systematic**, not ornamental. MIDI value 682 = exactly 8192÷12,
  which is 1/12 of the pitch wheel range. It appears to be a deliberate 1/6-semitone (≈17
  cent) upward tuning offset applied to every note. This is the "slightly out of tune but
  intentionally so" quality that defines their guitar sound.
- The lead voice in Fabienk gets up to 4× that offset (+2/3 semitone) for expressive bends
  on phrase peaks, while the supporting voices all sit at the constant +1/6-semitone base.
- Television bends only in solo passages; the structured interlocking parts are clean.
- Toe and Slint are pitch-pure — no microtonality whatsoever.

**Implementation plan for ADP model songs:**
- On every guitar note-on event, send a pitchwheel message 1 tick before the note
- Base offset: +17 cents (MIDI value 682) for Loop layers and bass
- Lead offset: randomly vary between +17 and +67 cents per note for the lead voice
- On note-off, reset pitchwheel to 0 before the next note
- `AVAudioUnitSampler` accepts MIDI pitch bend natively — no AVAudioEngine-level changes needed
- Tie this to the "interval-loop" bass model: if a song draws ADP Fabienk bass model, also
  apply the microtonal pitch system to both guitar voices

---

## Part 8: Relationship to Existing Zudio Styles

Math rock would sit at the high end of the energy spectrum — faster and more complex than
anything currently in the style axis. The natural position on the style dial would be at
one end:

**Math Rock → Motorik → Chill → Kosmic → Ambient**

(ordered from most rhythmically active to least)

Math rock and Motorik are closest in energy but differ fundamentally: Motorik has a
hypnotic, unwavering pulse that is reassuring; math rock has rhythmic displacement and
angularity that keeps the listener slightly off-balance throughout. They are neighbors on
the energy axis but opposite in rhythmic intent.
