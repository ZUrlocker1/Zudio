# Ambient Piano — Research & Implementation Plan
Copyright (c) 2026 Zack Urlocker

## Overview

Ambient Piano is a sub-style of Ambient, appearing ~15% of the time. Where base Ambient generates variation through co-prime loop phasing — a mathematical, machine-like process — Ambient Piano inverts this completely. The sole melodic voice is a piano making deliberate statements into a field of near-silence, with long rests between phrases and no looping or layering.

Each Ambient Piano song is shaped by one of three **lead rules** for Lead 1, chosen probabilistically at generation time. The rules have genuinely different generative logic — not just different parameters — because the three reference aesthetics have fundamentally different structural approaches:

- **AMB-PNO-001 — Floating Tones:** individual notes floating in space, no phrase direction, stochastic placement *(Harold Budd reference)*
- **AMB-PNO-002 — Pensive Melody:** true melodic phrases with stepwise oscillation and varied returns *(Satie / Arnalds reference)*
- **AMB-PNO-003 — Dramatic Arc:** fuller phrases shaped by a global dynamic arc across the song *(George Winston reference)*

**The governing idea:** every other Ambient track generates texture, density, and layering. This one generates *events in a field of near-silence*.

---

## What makes it different from base Ambient

Base Ambient: multiple tracks phasing against each other, continuous sonic activity at low density, variation automatic and imperceptible moment-to-moment.

Ambient Piano: one instrument, deliberate human gesture, long silences, the listener can count the notes.

The two styles share the same harmonic world (modal, static, no chord progression) and the same sonic palette (piano timbre is already in base Ambient's instrument pool). What is radically different is the generative philosophy: base Ambient is *continuous and mathematical*; Ambient Piano is *sparse and composed-feeling*.

The hollow guard logic in `generateAmbient` must check `isAmbientPiano` and skip fill logic — intentional near-silence must not be overridden by any automatic density correction.

---

## Source references

**Harold Budd & Brian Eno — *Ambient 2: The Plateaux of Mirror* (1980)** *(AMB-PNO-001)*
- Analysed: *A Stream With Bright Fish* — 55 BPM, G minor (MIDI file encodes 110 BPM; actual musical tempo is 55 BPM). 5-bar loop. Structure: G minor triad chord wash (G2+Bb2+D3, vel 4–8) strikes on every bar downbeat (every 16 steps), held 16 steps (1 full bar), continuous throughout. Above it: ascending-burst-with-mirror-fall events (burst 1: IOI 1 step / 16th-note pace; burst 2: IOI 2 steps / 8th-note pace). Each burst preceded by a quiet pickup note (vel 25, 1 step, chord tone) one step before the burst starts. Burst peaks on chromatic note one semitone above a chord tone (Eb4, Ab4); final burst note held 4–5 steps. Velocity contrast: chord wash vel 4–8, burst events vel 50 — ratio ~6:1.
- Analysed: *Among Fields Of Crystal* — 45 BPM, E Aeolian. Structure: 3-note chord cells (E minor → F#dim7 → F major → C major) repeating 2–4 times at vel 9, with single flash notes (vel 50, 0.25 beats) sounding above each cell group. Flash notes are scale tones at the 5th above or octave above the chord's highest voice. No long silences; continuous harmonic shimmer across a 52-second slow harmonic journey.

**Harold Budd — *The Plateaux of Mirror* / solo works** *(AMB-PNO-001)*
- Analysed: *Not-yet-remembered* — 60 BPM, C# Aeolian, 3.2 min, 573 notes, vel flat at 80. Mode 3 (chromatic pendulum): metronomic oscillation between two 3-note chromatic clusters (`[Eb4,E4,Ab4]` ↔ `[C#4,Eb4,F#4]`) every 1 beat (IOI 4 steps) for the full song. Bass octave pairs (A1+A2, E1+E2, C#2+C#3) anchor each 2-bar section at very low register (MIDI 21–49), held 28–32 steps. Two-part structure: main clusters (bars 0–16, 32–48) + contrasting middle chords (bars 16–24).
- Analysed: *Against the Sky* — 66 BPM, 4.6 min, only 56 chord events, vel flat at 64. Mode 2 (gong chord): two chord states Eb minor (`Eb2/3/4, F#3/4, Bb3/4`) ↔ F# major (`F#2/3/4, Bb3/4, C#3/4`), each voiced as 7 notes across 3 octaves, held 12–60 steps with silences of 12–60 steps between. Single breath notes (lone Eb3, Eb4) appear between chord strikes as tonal remnants. No melody, no velocity variation — the chord resonating IS the music.

**Erik Satie — *Gymnopédies* (1888), *Gnossiennes* (1890)** *(AMB-PNO-002)*
- The harmonic and structural ancestor. Analysed: Gnossienne 1 (two-register arch, ABCD repeat, cross-phrase +7 connection, 22 suspension figures), Gnossienne 2 (pure oscillation IOI 0.67–1.1 beats, 3–4 steps at 60 BPM), Gymnopedie 1 (22 suspension→resolution figures, 30% suspended phrase endings). Core idioms: stepwise oscillation around a pivot then large leap DOWN into lower register; suspended phrase endings on 2nd, b3, 4th, b7; exact phrase repetition rather than development.

**Ólafur Arnalds — *re:member* (2018), *some kind of peace* (2020)** *(AMB-PNO-002)*
- *Saman* (110 BPM) — continuous arpeggiation; contributes velocity swell shape and broken-chord vocabulary, not phrase structure
- *Near Light* (60 BPM, B minor) — sparse 9-bar piano opening over held chords; staggered string entry model
- *Raein* (60 BPM, E minor, 7.7 min) — named tracks Acoustic Piano / Synthesizer / Violin / Violin 2 / Viola; primary reference for string voice behavior

**Nils Frahm — *Felt* (2011)** *(timbre reference, all rules)*
- Recorded with dampers on the piano strings; every note has a soft onset and long reverb tail. Target timbre: fragile and intimate, not percussive.

**George Winston — *December* (1982), *Autumn* (1980)** *(AMB-PNO-003)*
- Solo piano, no pad drone. The right reference for dynamic range, phrasing patience, and emotional directness. Winston's songs build and release — the mid-song phrase is the loudest, most elaborated statement.

**Keith Jarrett — *Köln Concert Part 1* (1975)** *(AMB-PNO-003)*
- Fully improvised. Analysed for arc, motif repetition, call-and-response, riff ostinato, and chromatic vocabulary. Key findings: climax is a density event (2.2 → 4.3 notes/sec); the highest note is often a parting gesture at withdrawal; the signature motif `(+1, -1, -2)` — chromatic neighbor then fall — appears 15 times; 24 call-and-response pairs with responses typically lower than calls; 5% of notes are chromatic (approach and passing only); riff ostinato cells cluster in the build zone just before the climax.

---

## Harmonic language

- **Modes**: Dorian (50%) or Aeolian (35%) — both produce the characteristic open-but-melancholy quality; Mixolydian (15%) only for lighter moods, never if mood is Dream or Deep
- **No chord changes** — tonal map stays on the tonic for the full song; `droneSingle` progression family
- **Scale constraint**: piano notes are drawn from the song's key + mode scale wherever possible. Out-of-scale chromatic tones are permitted as approach notes (half-step to a target, duration 1–2 steps), passing tones (b3, b7 as brief transit notes), and cluster shimmer notes (Mode 3). Because only Lead 1 and occasional Pads are active, tonal collision risk is low and chromatic colour is a feature, not an error.
- **Pad voicing**: root + fifth (no third) — implies neither major nor minor; harmonic ambiguity is structural

---

## Timing — BPM and step definition

All note timing in the Lead rules below is expressed in **steps**, where **1 step = 1/16th note**. At the Ambient Piano target BPM this maps to:

- **BPM range: 58–72.** Generate once per song, uniform draw. This range covers the source pieces (*Near Light* and *Raein* are both 60 BPM; *December* is 72 BPM).
- At 60 BPM: 1 step = 0.25 seconds; 1 bar (16 steps) = 4 seconds
- At 72 BPM: 1 step = 0.208 seconds; 1 bar (16 steps) = 3.33 seconds
- **16 steps = 1 bar** throughout this document

Phrase window positions below are stated in both bars and steps (at 16 steps/bar) to avoid BPM-dependent arithmetic in the generator.

---

## Track allocation

- **Lead 1** — piano, sole melodic voice — active (one of AMB-PNO-001 / 002 / 003)
- **Lead 2** — silent
- **Pads** — present conditionally (90% / 75% / 50% for Floating Tones / Pensive Melody / Dramatic Arc); when active uses AMB-PADS-007 / 008 / 009 matched to the piano rule
- **Rhythm** — silent
- **Bass** — silent
- **Texture** — silent
- **Drums** — silent (`percussionStyle = .absent`)

---

## Effects

The dreamy quality comes almost entirely from the effects chain, not the notes. The same MIDI sequence played dry sounds ordinary; through a long hall reverb at high wet/dry it becomes otherworldly.

### Lead 1 — piano (all three rules)

- **Reverb**: wet 0.70–0.85, decay 4–6 seconds, pre-delay 30–60 ms. Pre-delay lets the dry attack breathe before the wash arrives — prevents smear on the note onset.
- **Delay**: off. Each phrase statement must feel singular; delay adds repetition that undercuts this.
- **Low-pass filter**: gentle roll-off above ~3 kHz — removes harshness from the reverb tail, adds distance and intimacy.
- **Velocity ceiling per rule**:
  - AMB-PNO-001: max velocity 50 — every note arrives at the same quiet intensity
  - AMB-PNO-002: max velocity 68 — intimate, never projected
  - AMB-PNO-003: max velocity 92 at climax — the only rule where real dynamic weight is allowed

### Pads (AMB-PADS-007 / AMB-PADS-008 drone layer / AMB-PADS-009 — Sweep Pad or Halo Pad GM 94)

- **Reverb**: wet 0.50–0.65, decay 2–3 seconds
- Slow attack: pad swells in over 2–4 seconds (use volume ramp over the first 32–64 steps after re-attack, not an instantaneous onset)

### Pads (AMB-PADS-008 string voices — Synth Strings GM 50)

- **Reverb**: wet 0.45–0.55, decay 1–2 seconds. GM 50 has a long built-in release; reverb adds air only.
- Keep string reverb lighter than Lead 1 — prevents the two timbres blurring together.

### All other tracks

Silent — no effects needed.

---

## Lead rule 1 — AMB-PNO-001: Floating Tones

**Probability within Ambient Piano: 30%**  
*Style reference: Harold Budd / Brian Eno*

Four Budd MIDI files were analysed, revealing three structurally distinct Budd modes. All share one structural principle: **the music is the chord resonating into the reverb, not a melody above it.** No Budd piece has melodic direction; what varies is *how the chord is presented* — as a sparse individual note, as a thick multi-octave gong strike, or as a metronomic chromatic oscillation. A second shared principle: **flat velocity throughout** — three of the four pieces use a single velocity for every note; dynamics come entirely from reverb decay and chord voicing, not from MIDI velocity variation.

### Song mode selection — choose once per song

- **Mode 1 — Sparse floating** (40%): *A Stream With Bright Fish, Among Fields Of Crystal*. Individual events (notes, bursts, flash pairs) scattered over a quiet chord wash. The A Stream / Pearl aesthetic.
- **Mode 2 — Gong chord** (35%): *Against the Sky*. Thick multi-octave chord strikes, held very long, with silence between. Only two chord states exist in the whole song. The primary texture IS the chord itself resonating and decaying.
- **Mode 3 — Chromatic pendulum** (25%): *Not-yet-remembered*. Metronomic oscillation between two chromatic clusters, every single beat, for the full song. Hypnotic and continuous, not sparse.

---

### Mode 1 — Sparse floating

**Setup:**
- **Chord wash root**: one scale tone, MIDI 40–52 — the song's harmonic anchor
- **Chord type**: minor triad (root + b3 + 5)
- **Velocity mode**: contrast (chord wash vel 4–12; events vel 45–55) — the only Budd mode with layered dynamics

**Chord wash (continuous):**
Re-strike the 3-note chord cluster on every bar downbeat (every 16 steps), all three notes simultaneously. Held 16 steps, then re-struck. These notes are extremely quiet (vel 4–12); through reverb they bloom into the harmonic field. The chord wash root may move once mid-song (25% chance) — a 5th below or major 2nd above the original root, chosen randomly 50/50.

**Events (4–7, scattered across the song body):**
- Gaps between events: 8–18 bars (128–288 steps), drawn uniformly
- Last event no later than 8 bars before song end
- Event type chosen independently per event:
  - **Single floating note** (40%): one scale tone, MIDI 55–76; duration 16–24 steps; vel 40–55; 25% chance of reusing the previous pitch (hovering)
  - **Ascending burst with mirror fall** (35%): see idioms below
  - **Flash-over-chord** (25%): see idioms below

**Form:**
- Opening: 6–10 bars of chord wash only
- Events scattered, separated by 8–18 bar silences (chord wash present throughout)
- Duration: 3–4 minutes

---

### Mode 2 — Gong chord

*Against the Sky: 66 BPM, 76 bars, only 56 onset events in 4.6 minutes. Two chord states; chords held 12–60 steps.*

**Setup:**
- **Chord A** and **Chord B**: two chord voicings chosen once per song; used for the entire song
  - Each chord is 5–7 notes spanning 2–3 octaves (span 24–36 semitones)
  - Registers covered: low (MIDI 39–52), mid (MIDI 52–67), high (MIDI 67–79) — one or two notes per register

- **Construction algorithm** (choose once per song):
  1. Select a 4-pitch-class palette: {root, b3, P5, color\_tone} where color\_tone is b7 (50%) or M2 (50%), all from the song's mode scale.
  2. Chord A draws from {root, b3, P5}; Chord B draws from {b3, P5, color\_tone}. They share b3 and P5 — two common tones — so the two chords sound like facets of the same harmonic object.
  3. Chord B bass root: song's root pitch class placed in MIDI 41–50.
  4. Chord A bass root: Chord B bass root minus 7 (P5 below, 50%) or minus 3 (m3 below, 50%); clamp to MIDI 39–46.
  5. Voice each chord to 5–7 notes by placing each pitch class at its lowest valid position within each octave zone (low 39–52, mid 52–67, high 67–79), adding doublings until the note count is reached.

- **Velocity**: flat throughout, vel 60–72 — every note in the song, the same velocity

**Event sequence:**
- Place 10–20 chord strike events across the song body (one chord or the other, alternating)
- **Short strike** (33%): chord held 12–16 steps (3–4 beats), then silence — a brief resonance flash
- **Long strike** (50%): chord held 36–60 steps (9–15 beats) — a large resonating event; the chord blooms slowly and decays over nearly 15 seconds
- **Single breath note** (17%): one isolated note from the chord (typically the middle root, e.g. Eb3), held 12–24 steps — a tonal remnant floating between two full strikes; appears between chords when the previous strike has mostly decayed

**IOI between chord strikes:** 12–60 steps; draw non-uniformly — 60% of gaps are 12–16 steps (rapid chord exchange), 40% are 36–60 steps (long silence).

**Form:**
- Song opens immediately on the first chord strike (no pad-only introduction)
- Chord A and Chord B alternate throughout, with occasional single breath notes between them
- The song ends on a long chord strike (48–64 steps) that decays into silence; optionally follow with one final isolated single note after 24–32 steps of silence
- Duration: 4–5 minutes

---

### Mode 3 — Chromatic pendulum

*Not-yet-remembered: 60 BPM, 48 bars, 573 notes, perfectly metronomic. Clusters fire every single beat (IOI 4 steps). Two cluster states alternate in a hypnotic oscillation for the entire piece.*

**Setup:**
- **Cluster A** and **Cluster B**: two small chord clusters, each 2–3 notes, chosen once per song
  - Each cluster spans 3–7 semitones total
  - **At least one half-step interval** within each cluster — this creates the signature chromatic shimmer through reverb (chromatic tones outside the mode are permitted here; the shimmer effect depends on it)
  - Clusters share 1 pitch class so they sound like variations of the same harmonic object
  - Cluster register: MIDI 59–72 (all in mid range, a compact zone)

- **Construction algorithm** (choose once per song):
  1. Pick anchor A1: a scale tone in MIDI 59–72.
  2. Cluster A: {A1, A1+1} (chromatic half-step pair — the shimmer source); add A1+4 as a third note (60% chance).
  3. Cluster B: {A1+1, A1+3} (shares A1+1 with Cluster A; adds a whole step above it); add A1+6 as a third note (same 60% chance as step 2). Total span ≤7 semitones by construction.
  4. Verify all notes are in MIDI 59–72; transpose individual notes by ±12 if needed.

- **Mid-section clusters C and D** (used at bars 16–24): pick a new anchor C1 from scale tones in MIDI 59–72, distinct from A1. Cluster C = {C1, C1+2}; Cluster D = {C1+2, C1+4} — whole-step pairs with no half-step, giving a clearly lighter quality for the 8-bar contrast section. Return to A/B after bar 24.
- **Bass root**: a very low note, MIDI 20–38, used as the section anchor (always struck as an octave pair — same note, 12 semitones apart — e.g., A1 + A2 simultaneously)
- **Velocity**: flat throughout, vel 75–85

**Beat-pulse structure (fills the entire song):**
- Fire cluster A, then cluster B, then cluster A, then cluster B... every 4 steps (one beat), perfectly metronomic, for the full song duration
- Duration of each cluster: 3–4 steps (nearly fills the beat; slight overlap with next)
- This is not sparse — it is continuous oscillation without pauses

**Sectional structure (bass anchor sections):**
Every 2 bars (32 steps), a new section begins:
1. Strike the bass octave pair (2 notes, vel 75–85, held 28–32 steps — 2 full bars) on the downbeat
2. Continue the A↔B cluster oscillation above it for those 2 bars
3. On the next 2-bar downbeat: strike a *different* bass note pair, continuing the oscillation
- The bass note follows a slow harmonic progression: choose 4–6 different bass roots across the song; each bass root is a scale tone in MIDI 20–38; change every 2 bars
- Example progression from analysis: A1/A2 (4 bars) → E1/E2 (4 bars) → C#2/C#3 (4 bars) → Ab1/Ab2 (2 bars) → B1/B2 (4 bars)...

**Mid-section chord type change (once per song, around bar 16–24):**
Introduce a new cluster pair C and D, different pitch classes from A/B, for 8 bars. Then return to A/B for the remainder. This is the "middle section" in Not-yet-remembered where different chord types appear briefly.

**Form:**
- The song begins immediately on the first A↔B beat with a bass octave pair on bar 1
- Continuous oscillation throughout with no rests — the piece is hypnotic and never pauses
- Song ends by simply stopping the oscillation mid-bar; do not add a ritardando or fade — it stops cleanly
- Duration: 3–4 minutes

---

### Budd musical idioms (from all four analyses)

**Flat velocity (dominant pattern)**: *Against the Sky* and *Not-yet-remembered* use a single velocity throughout — vel 64 and vel 80 respectively. Every single note is the same velocity. The dynamics come entirely from reverb decay and chord voicing. Only *A Stream With Bright Fish* uses velocity contrast (chord wash vel 4–8 vs. burst vel 50). For Modes 2 and 3, apply flat velocity; for Mode 1 only, apply the contrast layering.

**Binary chord pendulum (all four pieces)**: every Budd piece oscillates between exactly two chord states. Not a progression — a binary pendulum. *Against the Sky*: Eb minor ↔ F# major. *Not-yet-remembered*: [Eb,E,Ab] ↔ [C#,Eb,F#] and [E,A] ↔ [C#,Ab]. *A Stream*: G minor wash ↔ quiet. The two states are chosen once and maintained. This is the deepest structural principle.

**Bass octave pair**: very low notes always arrive as an octave pair — the same pitch at root and root+12 struck simultaneously (e.g., A1+A2, E1+E2, C#2+C#3 in *Not-yet-remembered*; Eb2 in both octave registers in *Against the Sky*). Never a single isolated bass note alone. The octave doubling creates a resonant low-frequency bloom distinct from a solo bass tone.

**Chromatic shimmer cluster**: *Not-yet-remembered*'s clusters deliberately contain a semitone interval — `[Eb4, E4, Ab4]` has Eb–E = 1 semitone; `[C#4, Eb4, F#4]` has C#–Eb = 2 semitones. This is dissonant on paper but through a long reverb blurs into a characteristic hazy shimmer. The dissonance is the point. Use in Mode 3; also available as an event variant in Mode 1 (replacing the single floating note with a 2-note semitone pair, vel 45–55).

**Thick multi-octave gong chord** (*Against the Sky*): 5–7 notes of the same chord voiced across 3 octaves, struck simultaneously (or within 1 step). All the same velocity. The chord is held 12–60 steps while it slowly decays through reverb. In a 4.6-minute piece at 66 BPM, the longest held chord is 60 steps = ~14 seconds. This is not decorative — the chord IS the music.

**Single breath note** (*Against the Sky*): occasionally a single isolated pitch (typically a chord-tone from the previous chord strike, not from the next one) floats in the silence between two full chord events. Duration 12–24 steps. This is the sonic remnant of the previous chord — the listener hears it as the room still ringing. Appears between ~15% of chord transitions.

**Ascending burst with mirror fall** (*A Stream With Bright Fish*): 5–8 notes ascending to a chromatic peak (one semitone above a chord tone), IOI 1–2 steps each (16th-note flutter pace), then falling back by near-mirror path. Final note held 4–8 steps. Preceded by a quiet pickup note (vel 20–28, 1 step, chord tone) one step before the burst starts — a soft breath-in.

**Flash-over-chord** (*Among Fields Of Crystal*): a brief single note (vel 45–55, 1–2 steps) piercing above a repeating 3-note chord cell (vel 9). Flash pitch: 5th above or octave above the chord's highest note. Appears on one of 2–4 repetitions of the cell. The cell then continues and falls silent.

**Harmonic progression — Among Fields style** (Mode 1 option, 25% chance): chord wash root moves once mid-song, a 5th below or major 2nd above the original. Eb minor → C minor, or E minor → A minor. The shift happens in silence; the new chord wash is already present before the next event fires.

### Form summary by mode

- **Mode 1**: 6–10 bar opening → 4–7 sparse events over continuous chord wash → silence at end. Duration 3–4 min.
- **Mode 2**: immediate first chord → 10–20 gong chord events with long silences between → final long decay into silence. Duration 4–5 min.
- **Mode 3**: immediate start → continuous beat-pulse oscillation throughout with bass octave anchors every 2 bars → abrupt stop. Duration 3–4 min.

---

## Lead rule 2 — AMB-PNO-002: Pensive Melody

**Probability within Ambient Piano: 45%**  
*Style reference: Erik Satie (Gnossiennes, Gymnopédies), Ólafur Arnalds (Saman, Near Light)*

The Satie/Arnalds model has true melodic phrases with internal logic. The listener can follow and hum the melody. The fundamental structure is a **two-register architecture**: each phrase opens in a higher register, oscillates around a pivot pitch, then descends — via a large leap of 6–12 semitones — into a lower settlement zone where the phrase ends. The descent into the lower register is the emotional release of the phrase. This asymmetry — quick oscillating upper section, slow settling lower section — is the emotional signature of the style.

Three sources inform the piano algorithm: **Satie** (Gnossienne 1 and 2, Gymnopedie 1) provides the phrase architecture — the two-register shape, the oscillation pattern, the suspension figures, the long silences, the exact phrase repetition. **Arnalds** (*Saman*) contributes velocity swell character. **Arnalds** (*Near Light*) contributes the chord texture variant. String and pad behaviour is in **AMB-PADS-008** below.

### Algorithm

**Setup — choose once per song:**
- **Pivot pitch**: one scale tone, MIDI 65–76 (F4–E5) — upper register
- **Neighbor pitch**: one scale step away from the pivot — either 1 semitone (half step) or 2 semitones (whole step); whole step preferred for a more suspended feeling
- **Lower register anchor**: MIDI 53–62 (F3–D4) — where phrases descend and settle

**Phrase type** (chosen independently per phrase):
- Standard two-register arc (70%): upper oscillation → suspension figure → large leap down → lower settlement
- Pure oscillation (20%): stays in upper register throughout — pure back-and-forth then one resolution fall then long hold (Gnossienne 2 style)
- Short cadence (10%): 3–5 notes; begins in lower register; leaps up; stepwise descent back; long held ending

**Phrase placement** — 3 phrases placed in fixed windows:
- Phrase 1: bars 9–14 (steps 129–224)
- Phrase 2: bars 28–34 (steps 433–544)
- Phrase 3: bars 50–56 (steps 785–896)
- Within each window, pick a random bar boundary for the phrase start

**Phrase window compression** — when `totalBars < 65`, scale all three windows proportionally rather than using fixed bar numbers:
- Phrase 1 start: `round(totalBars * 0.14)` (≈ bar 9 of 65)
- Phrase 2 start: `round(totalBars * 0.43)` (≈ bar 28 of 65)
- Phrase 3 start: `round(totalBars * 0.77)` (≈ bar 50 of 65)
- Each window remains 5–6 bars wide; clamp so the window end does not exceed `totalBars − 4`

**Standard two-register arc — note sequence:**

1. **Opening gesture** (neighbor_up, 75% of phrases): first note = pivot; second note = pivot +1–3 semitones above; third note = pivot or pivot −1 semitone. This gives a sense of the melody arriving from slightly above and settling on its starting pitch.
2. **Upper oscillation** (2–4 full cycles): alternate pivot → neighbor → pivot → neighbor. Total oscillation notes: 4–8.
   - **IOI between oscillation notes: 3–5 steps** (note onset to next onset). This is the correct Satie tempo — approximately 0.75–1.25 beats at 60 BPM. The notes are close together; the hypnotic quality comes from repetition, not from slow floating.
   - Note duration within oscillation: 2–4 steps; gap (silence): 1–2 steps
3. **Suspension→resolution figure** (60% of phrases, placed at the end of the oscillation zone): hold the pivot pitch for 6–8 steps (1.5–2 beats), then step down 1 or 2 semitones to a scale tone. The held note is the suspension; the step-down is the resolution into the descent. Gymnopedie 1 has 22 of these figures; it is Satie's most characteristic gesture.
4. **Leap down** (lower register entry): fall 6–12 semitones below the pivot, landing in MIDI 53–62. The leap is a sixth, minor seventh, or octave. Duration of the arrival note: 8–16 steps. This is the phrase's longest note and its harmonic goal.
5. **Lower settlement** (optional, ~60% of phrases): 2–3 more notes in the lower register, moving by step or small interval, ending with a held note 10–20 steps.
6. **Lower oscillation — "exhausted landing"** (~35% of phrases): before the final held note, insert 2–3 turns of oscillation between two adjacent lower-register pitches (step or half-step), IOI 3–5 steps, velocity 38–48. Mirrors the upper oscillation but feels settling rather than energised.

**Pure oscillation phrase (Gnossienne 2 style):**
- All notes in upper register (MIDI 65–76)
- Oscillation: 6–8 notes (3–4 full turns), IOI 3–5 steps
- Single resolution fall after oscillation ends: drop 3–5 semitones, duration 4–8 steps
- Final held note: duration 12–20 steps
- No lower register section — the entire phrase is horizontal oscillation with a brief closing fall

**Short cadence phrase:**
- 3–5 notes total
- First note: lower register (MIDI 53–62), below the upper pivot zone
- Leap up: 5–8 semitones into the upper zone
- Stepwise descent: 2–3 steps downward back toward the lower register
- Final held note: duration 10–16 steps; ends in the lower zone
- Provides contrast by beginning where a two-register arc phrase ends — acts as a structural answer

**Phrase ending scale degree:**
- 70%: root or 5th — settled
- 30%: suspended degree — scale's 2nd, b3, 4th, or b7 — introspective, unresolved; Satie's signature. Applied to the final held note of the phrase.

**Velocity — Arnalds swell shape:**
- Overall range: 35–68
- First oscillation note: 45–52 (softest)
- Swell rises smoothly across oscillation notes, peaking at the suspension figure or just before the leap down: 60–68
- Lower settlement notes: decay back toward 40–52
- Pivot note carries +3–5 velocity units more than the neighbor note within the swell curve
- No step changes; the swell is linear or smoothly curved

**Phrase-to-phrase variation:**
- Phrase 2: same pivot and neighbor pitch class as Phrase 1; optionally transpose the pair up by a major second (2 semitones) or minor third (3 semitones) — 50% chance. When transposing, aim for the first note of Phrase 2 to be approximately +7 semitones (a perfect fifth) above the final note of Phrase 1's lower settlement — the cross-phrase connection Gnossienne 1 uses between phrase groups.
- Phrase 3: 30% exact repeat of Phrase 1 (same pitches, same durations, same velocities — verbatim); 50% compressed repeat (same contour and phrase type as Phrase 1, oscillation trimmed to 2–3 cycles, velocity 35–52); 20% new variation. Satie does not develop; he repeats. The exact repeat IS the statement.

**Arnalds broken-chord variant (30% of upper oscillation sections):**
Replace one oscillation pair with a 3-note broken chord: pivot → scale tone a 5th below → neighbor. Uses the same per-note IOI as the regular oscillation notes. Replaces one unit; does not extend phrase length.

### Satie musical idioms (from analysis)

These devices are drawn directly from the Gnossienne and Gymnopedie MIDI analysis and are what make phrases feel composed and emotionally shaped rather than procedurally generated:

**Two-register leap as emotional pivot**: the large downward leap (6–12 semitones) from the upper oscillation zone into the lower register is not a continuation — it is the pivot moment. The upper section builds tension through oscillation and the suspension figure; the leap releases it downward. The landing note must be the longest note in the phrase (8–20 steps). This asymmetry is the emotional engine of the style.

**Suspension→resolution figure** (hold → step down): a note held longer than the surrounding notes (6–8 steps, 1.5–2 beats), then a step down of 1–2 semitones. Creates a sigh just before the descent. Present in 22 instances in Gymnopedie 1 alone; appears at nearly every phrase boundary in Gnossienne 1. Already incorporated into the standard arc (step 3) but can appear independently in any phrase type.

**Exact phrase repetition** (ABCD-ABCD form): Satie does not develop his phrases. He repeats them verbatim — same pitches, same timing, same dynamics — in the second half of the piece. Phrase 3 has a 30% chance of being a byte-for-byte repeat of Phrase 1. Do not modify for variety; the repetition is the structural statement.

**Lower-register oscillation** ("exhausted landing"): Gnossienne 1 Phrase 3 ends with small-interval oscillation in the lower register before the final held note. The lower oscillation pitches are adjacent scale tones in MIDI 53–64. IOI 3–5 steps, velocity 38–48 — quieter and more settled than the upper oscillation. Present in ~35% of phrases (see arc step 6).

**Suspended phrase endings**: 30% of Satie phrases end on the scale's 2nd, b3, 4th, or b7 rather than root or 5th. This is a deliberate choice that leaves the listener in introspective suspension. When selecting the final held note, apply this 30% bias.

**Oscillation IOI note**: actual Gnossienne 2 oscillation runs at IOI 0.67–1.1 beats (3–4 steps at 60 BPM). The notes are close together in time. Do not treat oscillation as slow floating — the pattern moves at walking pace or slightly faster.

### Near Light piano texture variant (~40% of AMB-PNO-002 songs)

*Arnalds — Near Light* opens with a different piano texture: **held 3-note chords with a single floating melody note** appearing on beat 3 of each bar, rather than the Satie oscillation. Use this for the first phrase only (4–8 bars); phrases 2 and 3 revert to the Satie oscillation pattern.

**When active, replace Phrase 1 with this texture:**
- Each bar: strike a 3-note chord on beat 1 (step 1 of the bar), held for the full bar (16 steps)
  - Low root: MIDI 47–54
  - Mid voice: MIDI 57–64 (a 3rd, 5th, or 7th above root)
  - High voice: MIDI 64–72 (chord tone or scale 2nd/6th above root)
  - All three notes same velocity: 45–55
- On beat 3 (step 9 of the bar): add one floating melody note, duration 4 steps (one beat)
  - Register: MIDI 69–78, 1–3 scale steps above the high chord voice
  - Velocity: 55–65 (louder than the chord by +6–10 units)
- Chord root changes by a 4th or 5th each bar (slow harmonic rhythm) — direction is random (up or down), but the new root must be a scale tone within the song's mode; re-draw if it would land outside the scale
- The floating melody notes across bars should descend stepwise within the key (e.g. bar 1 = scale degree 6, bar 2 = degree 5, bar 3 = degree 4...)
- After 4–8 bars, transition to the Satie oscillation pattern for phrases 2 and 3

### Form

- Opening: 4–8 bars of pad/shimmer only (synth shimmer counts as part of the pad layer; its bar 3–4 entry is within this opening zone)
- Phrase 1 (bars ~9–14): two-register arc or pure oscillation; 6–12 notes total; full velocity range
- Silence (bars ~14–28): pad only — the absence is intentional
- Phrase 2 (bars ~28–34): variation; optionally transposed +7 semitones above Phrase 1's final lower note
- Silence (bars ~34–50): longest silence, the centre of the piece
- Phrase 3 (bars ~50–55): exact or compressed repeat of Phrase 1 (80%), or new short cadence (20%); quietest
- Closing: pad fades; no final piano statement
- Duration: 4–5 minutes

---

## Lead rule 3 — AMB-PNO-003: Dramatic Arc

**Probability within Ambient Piano: 25%**  
*Style reference: George Winston (December, Midnight, Snow), Keith Jarrett (Köln Concert Part 1)*

The Winston model has a global emotional arc. The song builds from a quiet opening through a mid-song climax, then withdraws. Phrases are wider in range and more expressive in dynamic weight than the other two rules. Where Floating Tones and Pensive Melody feel suspended and timeless, Dramatic Arc feels like something is being said. The Jarrett jazz vocabulary makes this rule distinctly more modern in feel than AMB-PNO-001 and AMB-PNO-002.

**From Winston**: large interval leaps (5ths, octaves) are normal vocabulary — *Midnight* has 58% of intervals as leaps ≥5 semitones. Notes are held very long; even a sparse phrase leaves a harmonic cloud that persists into the silence.

**From Jarrett** (Köln Concert Part 1 — entirely improvised): the full MIDI analysis reveals five specific idioms worth lifting beyond just the arc shape:
- **Arc**: climax is primarily a *density* event — note rate nearly doubles (2.2 → 4.3 notes/sec). The absolute highest note often appears as a *parting gesture* at the start of the withdrawal, not at the density peak.
- **Neighbor-note figure**: the single most-repeated 3-interval motif across the piece is `(+1, -1, -2)` — half-step up, return, whole-step fall — appearing 15 times; variant `(-1, +1, -1)` (chromatic oscillation) also 15 times. These ornamental neighbors give phrases a jazz quality absent from Satie-style stepwise motion.
- **Call and response**: 24 detected pairs; gaps 2–10 beats; responses come more often from a *lower* register than the call (12 of 24 lower, 9 higher). A big upper-register statement can be answered by a compact lower-register phrase.
- **Riff ostinato**: in the build zone (bars 50–75% of piece), Jarrett locks onto a 2–4 note cell and repeats it 3–4 times consecutively before releasing into the climax. Common cells: same-note pedal, ascending minor third pair, ascending whole-step pair.
- **Post-climax descending run**: after the peak, 6–10 notes descend at 8th-note pace (IOI 8 steps), predominantly stepwise, with 1–2 chromatic passing tones woven in. This run IS the transition from climax to withdrawal.
- **Chromatic vocabulary**: 5% of all notes are outside the 7 home pitch classes in the recording. Used as chromatic approach notes (half-step to target, duration 1–2 steps, arrives from above or below) and blue-note passing tones (b3, b7). Never as phrase endpoints.

### Algorithm

**Setup — choose once per song:**
- Number of phrases: 3 (standard) or 4 (25% of songs — adds a pre-climax phrase)
- Registral peak placement: 50% chance the song's highest note falls at the end of the climax phrase; 50% chance it falls as the first note of Phrase 3 (the parting gesture)
- Call-response split for Phrase 2: 40% chance (see jazz idioms below)
- Pre-climax ostinato: 25% chance (see jazz idioms below)

**Phrase placement** (3-phrase form):
- Phrase 1: bars 6–11 (steps 81–176)
- Phrase 2 — climax: bars 22–30 (steps 337–480)
- Phrase 3: bars 42–47 (steps 657–752)

**Phrase placement** (4-phrase form — 25% of songs, adds a pre-climax phrase):
- Phrase 1 (opening): bars 6–11 (unchanged)
- Phrase 2 (pre-climax bridge): bars 17–22 — 6–7 notes, velocity 65–80, register one zone below the climax peak; functions as a runway building tension toward Phrase 3
- Phrase 3 — climax: bars 28–36 (shifted to accommodate Phrase 2)
- Phrase 4 (withdrawal): bars 47–53 (shifted accordingly)
- "Phrase 2" in setup flags (call-response split, registral peak) refers to the climax phrase — Phrase 3 in the 4-form, Phrase 2 in the 3-form

**Per-phrase note count, velocity, and register:**

- Phrase 1 (opening): 4–5 notes; velocity 52–68; register MIDI 57–72 (mid-range)
- Phrase 2 (climax): 6–7 notes standard; 10–14 notes when call-response split active; velocity 72–92; register peaks high (MIDI 72–88)
- Phrase 3 (withdrawal): 3–4 notes; velocity 42–60; register MIDI 52–68 (mid-low)

**Within-phrase note vocabulary:**
- Interval leaps of a 5th (7 semitones), 6th (9), or octave (12) are fully normal — use them freely
- Stepwise motion (~38% of intervals): a minority, not the default
- Mix per phrase: 1–2 stepwise moves, 1–2 third/fourth moves (3–5 semitones), 1–2 large leaps (7–12 semitones)
- After a large leap (≥7 semitones): 74% of the time the next interval reverses direction; lean toward this in generation

**Within-phrase rhythm — burst pattern:**
- 2–3 notes arrive in quick succession (IOI 2–3 steps at climax, 3–5 steps at opening/closing)
- Then one note held long (12–28 steps) — this is the phrase's harmonic goal
- The long held note is the highest pitch in the phrase
- Approach note duration: 4–8 steps; long held note duration: 12–28 steps

**Registral peak rule** (applied at generation time after all phrases are built):
- Identify the single highest MIDI pitch across all phrases
- If parting gesture option was chosen: insert that pitch as the first note of Phrase 3 (held 16–24 steps), then continue Phrase 3's other notes descending from it. This is a copy, not a move — the original occurrence stays in Phrase 2. If the highest pitch already IS the first note of Phrase 3, skip the insertion.

**Bass punctuation** — placed in silences between phrases, not during a phrase:
- 1–2 single very low notes: MIDI 28–45 (A0–A2; as low as A1 confirmed by Winston, F#1 by Jarrett)
- Duration: 8–20 beats (32–80 steps) — held so long they overlap the next phrase's opening
- Velocity: 40–72 — struck with weight
- Placement: bars 13–15 (steps 193–240) and bars 34–36 (steps 529–576)

### Jarrett jazz idioms

**Chromatic approach notes** (applied to any long held note): place one approach note a half-step away (above or below the target) immediately before it. Duration: 1–2 steps. Velocity: 10–15% below the target note. The approach pitch may fall outside the mode — this is intentional; it is the note's identity as an approach that matters, not its scale membership.

**Neighbor-note figure** (25% of phrases, used as the phrase opening): `(target) → (target ± 1 semitone) → (target) → (target − 2 semitones)`. Each note: duration 2–4 steps. The figure arrives before the phrase's main burst and creates an ornamental jazz-ornament quality; keep its velocity within the phrase's lower range.

**Phrase 2 call-and-response split** (40% of songs): instead of one continuous burst, split Phrase 2 into two sub-bursts:
- Sub-burst A (call): 3–4 notes in upper register (MIDI 72–85), IOI 2–3 steps, ends on a note left unresolved
- Gap: 12–20 steps of silence within the phrase window
- Sub-burst B (response): 4–5 notes in mid-register (MIDI 60–75), IOI 3–5 steps, velocity 60–80 (quieter than the call), completes the harmonic idea
- The response must be in a lower register than the call

**Pre-climax ostinato** (25% of songs, placed 8–16 steps before the climax phrase): a 2–3 note cell repeating 3–4 consecutive times at 8th-note pace (IOI 8 steps each), in mid-low register (MIDI 55–69), velocity 52–64. Cell shape: ascending minor third `[+3]`, or ascending whole-step pair `[+2, +2]`, or plateau `[+2, 0]`. The final repetition rises by step or leap into the first note of the climax phrase, making the ostinato feel like a runway into the peak.

**Post-climax descending run** (50% of songs, placed at the very start of the silence after Phrase 2, or as the opening of Phrase 3 when using the parting gesture option): 6–10 notes descending at 8th-note pace (IOI 8 steps), mostly stepwise, with 1–2 chromatic passing tones allowed. Duration per note: 4–6 steps. Velocity decays from Phrase 2's peak level down toward Phrase 3's quiet range. This run is the transition from climax to withdrawal — it makes the descent feel earned.

**Blue-note passing tones** (throughout the song, not just in runs): b3 and b7 relative to the mode may appear as brief passing tones (duration ≤ 4 steps) within any phrase. They may not be phrase endpoints. Together with approach notes, chromatic content should stay near 5% of total melody events.

### Form

**3-phrase form (75% of songs):**
- Opening: 4–6 bars of pad only
- Phrase 1 (bars ~6–11): mid-register, 4–5 notes, sparse burst pattern; optional neighbor-note figure at opening
- Bass punctuation (bars ~13–15): one low note resonating into silence
- Silence (bars ~11–22): pad only; optional pre-climax ostinato at bars ~20–21
- Phrase 2 — climax (bars ~22–30): dense burst or call-response split, 6–14 notes, loudest, highest pitch
- Post-climax descending run (if active): immediately after Phrase 2 peak
- Silence (bars ~30–42): longest silence
- Bass punctuation (bars ~34–36): second low note
- Phrase 3 (bars ~42–47): 3–4 notes; either opens on song's highest pitch then descends, or stays low and quiet; optional parting gesture = post-climax run leads directly into it

**4-phrase form (25% of songs):**
- Opening: 4–6 bars of pad only
- Phrase 1 (bars ~6–11): same as 3-phrase
- Bass punctuation (bars ~13–15): one low note
- Phrase 2 — pre-climax bridge (bars ~17–22): 6–7 notes, velocity 65–80, register one zone below the climax peak
- Silence (bars ~22–28): pad only; optional pre-climax ostinato at bars ~26–27
- Phrase 3 — climax (bars ~28–36): dense burst or call-response split, 6–14 notes, loudest
- Post-climax descending run (if active): immediately after Phrase 3 peak
- Silence (bars ~36–47): longest silence
- Bass punctuation (bars ~38–40): second low note
- Phrase 4 (bars ~47–53): withdrawal; same shape as Phrase 3 in 3-form
- Closing: pad fades; ends in near-silence
- Duration: 4–5 minutes

---

## Pad rules (AMB-PADS)

AMB-PADS-007 through 009 are Ambient Piano specialisations, continuing the existing numbering after AMB-PADS-006 (Bell accent). AMB-PADS-001/002/003/006 remain unchanged for base Ambient.

All three Ambient Piano pad rules share a **common drone foundation**: root + fifth, open voicing (no third); re-attack every 48–64 bars (768–1024 steps) with a slow stagger onset (notes spaced 2–3 steps apart, low to high); velocity 28–40; register MIDI 48–67 (C3–G4); present from step 1 through the end of the song. The root + fifth voicing preserves harmonic ambiguity regardless of mode.

Above that drone, each style layers strings differently.

---

### AMB-PADS-007: Sparse Drone

*Paired with AMB-PNO-001 (Floating Tones). Style reference: Harold Budd.*

**Pad present: 90% of AMB-PNO-001 songs.** The Eno ambient wash is structural to the Budd aesthetic; without it the floating notes have no field to float in. The 10% no-pad case produces pure silence beneath each note — valid but extreme.

No active string voices. The drone is the entire pad layer.

- Instrument: Sweep Pad (GM 95) or Halo Pad (GM 94) — austere; even the pad is barely present
- The absence of strings is intentional — active melodic string voices would compete with the non-directional piano notes
- Drone velocity: 28–36 (quietest of the three rules)

---

### AMB-PADS-008: Staggered Strings

*Paired with AMB-PNO-002 (Pensive Melody). Style reference: Ólafur Arnalds — Near Light and Raein.*

**Pad present: 75% of AMB-PNO-002 songs.** The bare Gnossienne recordings have no accompaniment; the 25% no-pad case gives the most austere, just-piano Satie feel. When pads are present, **60% of those** activate the full string voices (`ambientPianoStrings = true`); the other 40% use drone only with Sweep/Halo Pad.

When strings are active, four voices layer over the drone:

**Entry sequence (bars from song start):**
- Drone from bar 1 throughout
- **Synth shimmer** (MIDI 71–86, B4–D6): enters bar 3–4 (steps 33–64); sparse ghost — mostly the key's 5th above middle register, occasionally stepping to the 6th and 7th; durations 2–4 beats (8–16 steps); gaps of 14–58 beats (56–232 steps) between notes; vel=64; never continuous
- **Violin 1 / high melody voice** (MIDI 66–83, F#4–B5): enters bar 6 (step 81) with one long held note (key 5th, 4–8 beats / 16–32 steps, vel=48), then silent for ~11 bars, then begins the full phrase arc
- **Violin 2 / inner-high voice** (MIDI 67–81, G4–A5): enters bar 7 (step 97), vel=48; begins with whole-note ascent (see phrase arc below)
- **Viola / inner-low voice** (MIDI 59–74, B3–D5): enters bar 8 (step 113), vel=48; begins with whole-note ascent

**Portamento entrance:** each string note onset is preceded by two discrete chromatic grace-note events stepping up to the target pitch — one note at target−2 semitones (duration 1–2 steps), one at target−1 semitone (duration 1–2 steps), then the target pitch itself. MIDI cannot slide continuously; these two short notes are the implementation of the Arnalds string breath-in from *Near Light*. Both grace notes are at the same velocity as the target note.

**The Raein string phrase arc** — each string voice follows this shape on every active appearance:
1. **Entry held note** — scale 5th or key tone, 16–32 steps (4–8 beats), vel=48
2. **Stepwise ascent** — one new pitch per bar (16 steps each), climbing 3–5 semitones toward the phrase peak; 3–4 bars total
3. **Flutter figure at the peak** — 3–4 quick descending notes at 8th-note values (8 steps each), stepping down diatonically from the peak (e.g. D→D→C→C→B in E minor); the Arnalds string agitation before settling
4. **Slow stepwise descent** — 2-beat steps (8 steps each) back down, covering 4–6 semitones over several bars
5. **Bottom oscillation** — two adjacent pitches alternating at 2-beat steps (8 steps each) for 2–4 turns; mirrors the Satie piano oscillation above
6. **Long rest** — 70–90 beats (280–360 steps / 17–22 bars) silent before repeating

**Stepwise rule**: 84–88% of all string intervals are stepwise (≤2 semitones). Within any active phrase, strings move entirely by step; the only pitch leaps occur at re-entry after the rest.

**Silence budget**: strings are silent ~70% of the piece. Do not sustain continuously.

**Instrument**: Synth Strings GM 50 for all active string voices.

**Dissolution**: voices drop out in reverse entry order — Viola first, then Violin 2, then Violin 1 — leaving piano + synth shimmer for the final section.

---

### AMB-PADS-009: Warm Sustain

*Paired with AMB-PNO-003 (Dramatic Arc). Style reference: George Winston, Keith Jarrett.*

**Pad present: 50% of AMB-PNO-003 songs.** Winston's and Jarrett's source pieces are all solo piano with no accompaniment; omitting the pad for half these songs is the more faithful interpretation. When absent, the bass punctuation notes in AMB-PNO-003 already anchor the harmony.

When present:
- Instrument: Synth Strings GM 50 (warm); 60% probability; otherwise Sweep Pad (GM 95) or Halo Pad (GM 94)
- Drone velocity: 35–48 — slightly louder than AMB-PADS-007; Winston's world is more physical
- **No active string arc, no flutter figure, no staggered entry, no bottom oscillation**
- **Optional warm pedal tone** (`winstonPedalTone`, 50% chance when pads active): a single string voice holds one long tone — the scale's 2nd or 4th above the root — for the full song at vel=38–48. This tone does not move or swell; it is static harmonic colour. This is a separate flag from `ambientPianoStrings` (which applies to AMB-PNO-002 only).
- The bass punctuation notes in AMB-PNO-003 (MIDI 28–45) are generated by the piano rule, not the pad rule

---

## How it is triggered

Same flag mechanism as `isChillBlues`:

```swift
let isAmbientPiano = rng.nextDouble() < 0.15
```

When true, a second roll picks the lead rule:

```swift
// AMB-PNO-001: 30%  AMB-PNO-002: 45%  AMB-PNO-003: 25%
let r = rng.nextDouble()
let pianoRule: String
if r < 0.30      { pianoRule = "AMB-PNO-001" }
else if r < 0.75 { pianoRule = "AMB-PNO-002" }
else             { pianoRule = "AMB-PNO-003" }
```

Third, fourth, and fifth rolls determine pad and string configuration:

```swift
// Pad presence probability by piano rule
let padPresenceThreshold: Double
switch pianoRule {
case "AMB-PNO-001": padPresenceThreshold = 0.90  // Budd: wash is structural
case "AMB-PNO-002": padPresenceThreshold = 0.75  // Satie: bare piano valid 25%
case "AMB-PNO-003": padPresenceThreshold = 0.50  // Winston: solo piano is source
default:            padPresenceThreshold = 0.75
}
let ambientPianoPadsActive = rng.nextDouble() < padPresenceThreshold

// Arnalds staggered string arc (AMB-PADS-008 only)
let ambientPianoStrings = ambientPianoPadsActive
    && pianoRule == "AMB-PNO-002"
    && rng.nextDouble() < 0.60

// Winston warm pedal tone (AMB-PADS-009 only)
let winstonPedalTone = ambientPianoPadsActive
    && pianoRule == "AMB-PNO-003"
    && rng.nextDouble() < 0.50
```

When `isAmbientPiano` is true:
- `percussionStyle` forced to `.absent`
- Lead 1 uses the selected piano rule (full-song generator, bypasses loop tiler)
- Lead 2 events cleared (forced silent)
- If `ambientPianoPadsActive`: run matched AMB-PADS rule (AMB-PADS-007 for AMB-PNO-001, AMB-PADS-008 for AMB-PNO-002, AMB-PADS-009 for AMB-PNO-003); instrument index set by that rule. Otherwise: Pads events cleared.
- Rhythm, Bass, Texture events cleared
- Hollow guards in `generateAmbient` skip fill logic
- Lead 1 effect defaults: reverb wet boosted to 0.70–0.85, delay off

---

## Implementation files

No new generator files required. No changes to PlaybackEngine, AppState, or UI.

---

## Codebase integration details

### SongState.swift

Add two new stored properties with defaults:

```swift
let isAmbientPiano: Bool      // default false
let ambientPianoRule: String  // "AMB-PNO-001" / "AMB-PNO-002" / "AMB-PNO-003"; "" when not active
```

Add to the custom `init` with defaults (`isAmbientPiano: Bool = false`, `ambientPianoRule: String = ""`).

Update `displayStyleName`:
```swift
var displayStyleName: String {
    if isAmbientPiano { return "Ambient Piano" }
    if chillBluesVariation { return "Chill Blues" }
    return style.rawValue.capitalized
}
```

Update all three `withXxx()` copy methods (`withAmbientBrushKit`, `withFrame`, `withAmbientAudioTexture`, `withChillAudioTexture`) to pass `isAmbientPiano: isAmbientPiano, ambientPianoRule: ambientPianoRule` through — every field must be passed explicitly or it silently defaults.

---

### SongGenerator.swift — `generateAmbient()`

**New parameter** (for test forcing):
```swift
forceAmbientPianoRule: String? = nil   // "AMB-PNO-001" / "AMB-PNO-002" / "AMB-PNO-003"
```

**Flag draws** — add immediately after `var rng = SeededRNG(seed: seed)`, before `AmbientMusicalFrameGenerator.generate()`:

```swift
let isAmbientPiano: Bool
let ambientPianoRule: String
if let forced = forceAmbientPianoRule {
    isAmbientPiano = true
    ambientPianoRule = forced
} else {
    isAmbientPiano = rng.nextDouble() < 0.15
    if isAmbientPiano {
        let r = rng.nextDouble()
        if r < 0.30      { ambientPianoRule = "AMB-PNO-001" }
        else if r < 0.75 { ambientPianoRule = "AMB-PNO-002" }
        else             { ambientPianoRule = "AMB-PNO-003" }
    } else {
        ambientPianoRule = ""
    }
}

// Pad / string / pedal-tone flags (consumed only when isAmbientPiano)
let padPresenceThreshold: Double
switch ambientPianoRule {
case "AMB-PNO-001": padPresenceThreshold = 0.90
case "AMB-PNO-003": padPresenceThreshold = 0.50
default:            padPresenceThreshold = 0.75
}
let ambientPianoPadsActive = isAmbientPiano && rng.nextDouble() < padPresenceThreshold
let ambientPianoStrings    = ambientPianoPadsActive && ambientPianoRule == "AMB-PNO-002" && rng.nextDouble() < 0.60
let winstonPedalTone       = ambientPianoPadsActive && ambientPianoRule == "AMB-PNO-003" && rng.nextDouble() < 0.50
```

**BPM override** — when `isAmbientPiano`, compute a piano-mode BPM (58–72) and pass it as `tempoOverride` to `AmbientMusicalFrameGenerator.generate()`:

```swift
let pianoTempo: Int? = isAmbientPiano
    ? (58 + rng.nextInt(upperBound: 15))   // 58–72
    : nil
let (frame, percStylePicked, ambientProgFamily, loopLengths) = AmbientMusicalFrameGenerator.generate(
    rng: &rng, keyOverride: keyOverride,
    tempoOverride: tempoOverride ?? pianoTempo,
    moodOverride: moodOverride
)
```

**Mode constraint** — after the frame is generated, when `isAmbientPiano` and `frame.mood` is `.Dream` or `.Deep`, the frame's mode must not be Mixolydian (spec: Mixolydian only for lighter moods). If the frame generator produced Mixolydian and mood is Dream/Deep, replace with Dorian. Do this by re-drawing the frame with a mode override, or build a wrapper that fixes the mode after generation.

**Guards to skip when `isAmbientPiano`** — wrap each of the following in `if !isAmbientPiano { ... }`:
- Dropout zone coordinator (Option C) — no zones needed; all tracks are intentionally silent
- The `lead1Loop.isEmpty && !padLoop.isEmpty` hollow retry (Lead 1 piano generators never return empty)
- The `isMinimalistLead` / `isAmbSectionSolo` tiler dispatch — the piano lead is a full-song generator, never tiled
- Hollow guard A (force texture non-silent)
- Hollow guard B (force bass)
- Hollow guard C (force rhythm for section solos)
- Plan J (intro/outro strip for Rhythm and Texture)
- Staggered entry/exit (chooses one track to silence for 12-bar head/tail)
- Texture 16-bar head/tail filter
- Plan H (coordinated breath silence — piano songs have their own built-in silence structure)
- Plan G (dynamic arc velocity scaling — each piano rule has its own velocity logic)
- Void guard (intentional silence must not be filled)
- X-Files whistle injection

**Lead 1 generation** — add a new static function to `AmbientLeadGenerator`:

```swift
static func generateAmbientPianoLead(
    pianoRule: String,
    frame: GlobalMusicalFrame,
    totalBars: Int,
    rng: inout SeededRNG,
    usedRuleIDs: inout Set<String>
) -> [MIDIEvent]
```

This returns full-song events (like the existing `generateMagnetikSolo` / `generateOxygeneratorSolo`). No loop tiler is applied. Dispatch from `generateAmbient()` when `isAmbientPiano`, bypassing `generateLead1()` entirely. Lead 2 events: set to `[]` directly.

**Pads generation** — add a new static function to `AmbientPadsGenerator`:

```swift
static func generateAmbientPianoPads(
    pianoRule: String,
    ambientPianoStrings: Bool,
    winstonPedalTone: Bool,
    frame: GlobalMusicalFrame,
    tonalMap: TonalGovernanceMap,
    totalBars: Int,
    rng: inout SeededRNG,
    usedRuleIDs: inout Set<String>
) -> [MIDIEvent]
```

Returns full-song events. No loop tiler. Called only when `ambientPianoPadsActive`. When not active, set `trackEvents[kTrackPads] = []` directly.

**Generation log** — pass `isAmbientPiano` and `ambientPianoRule` to `buildAmbientLog()` so the status box can display e.g. `Piano: AMB-PNO-002 Pensive Melody` and `Pads: AMB-PADS-008 Staggered Strings`.

**SongState return** — pass `isAmbientPiano: isAmbientPiano, ambientPianoRule: ambientPianoRule`.

---

### SongGenerator.swift — `regenerateTrack()`

After the existing `isAmbient` / `isChill` style checks, add:

```swift
let isAmbPiano = songState.isAmbientPiano
```

For `kTrackLead1` when `isAmbPiano`: call `AmbientLeadGenerator.generateAmbientPianoLead(...)` with the new track seed. Do not tile.

For `kTrackPads` when `isAmbPiano`: call `AmbientPadsGenerator.generateAmbientPianoPads(...)` with the new track seed. Do not tile. Re-derive `ambientPianoStrings` and `winstonPedalTone` flags from the new RNG draw (same rolls as original generation, seeded from new track seed).

For `kTrackLead2`, `kTrackBass`, `kTrackRhythm`, `kTrackTexture`, `kTrackDrums` when `isAmbPiano`: return `[]` (these tracks are always silent in Ambient Piano).

---

### AmbientLeadGenerator.swift

Add three private functions dispatched by `generateAmbientPianoLead`:
- `floatingTonesFullSong(frame:totalBars:rng:)` — AMB-PNO-001; uses `notesInRegister` with MIDI 55–76
- `pensiveMelodyFullSong(frame:totalBars:rng:)` — AMB-PNO-002; places 3 phrases at the fixed bar windows with step-offset arithmetic
- `dramaticArcFullSong(frame:totalBars:rng:)` — AMB-PNO-003; 3–4 phrase structure with arc shape

All three use `notesInRegister(pitchClasses: frame.scalePCs, low: X, high: Y)` (same helper already used throughout this file). Velocity ceilings enforced at the event level: clamp to 50 / 68 / 92 per rule before appending to the event list.

---

### AmbientPadsGenerator.swift

Add three private functions dispatched by `generateAmbientPianoPads`:
- `sparseDroneFullSong(frame:totalBars:rng:)` — AMB-PADS-007; root + fifth drone, re-attack every 768–1024 steps, vel 28–36, GM 94 or GM 95
- `staggeredStringsFullSong(frame:totalBars:ambientPianoStrings:rng:)` — AMB-PADS-008; drone foundation always; when `ambientPianoStrings`, layer four Raein string voices above it using the phrase arc defined in the pad rule
- `warmSustainFullSong(frame:totalBars:winstonPedalTone:rng:)` — AMB-PADS-009; drone, optional pedal tone

GM instrument numbers: Halo Pad = GM **94**, Sweep Pad = GM **95**, Synth Strings = GM **50**.

---

### Tests/ZudioTests/AmbientPianoBatchTests.swift

New test class. Force each rule via `forceAmbientPianoRule`. Test matrix:
- AMB-PNO-001 with pads active / pads silent
- AMB-PNO-002 + `ambientPianoStrings = true` / `= false`
- AMB-PNO-002 + Near Light texture variant
- AMB-PNO-003 + `winstonPedalTone = true` / `= false`

Each test: assert Lead 2 / Bass / Rhythm / Texture / Drums are empty; assert Lead 1 has events; assert pads have events only when pads active; assert BPM in 58–72 range; assert no event outside the total bar count.
