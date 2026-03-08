# Zudio Research Plan

## Motorik Pulse Research Sprint

Purpose: define reliable musical rules for Zudio's `Motorik Pulse` style so one-button generation produces convincing, coherent results.

### 1) Research questions

- Rhythm: what exact drum pattern traits make a groove feel motorik rather than generic 4/4 rock?
- Tempo: what BPM range is most representative for Neu!-like pulse?
- Harmony: does the style usually stay on one tonal center, one chord, or slow-moving modal harmony?
- Bass behavior: how tightly does bass lock to kick, and how much melodic movement is typical?
- Arrangement: how much change is introduced over time, and how gradual is it?
- Timbre/effects: what mix/effect traits matter most (dry drums vs room, delay textures, saturation)?

### 2) Initial hypotheses (to validate)

- Core drum identity is a steady, repetitive 4/4 pulse with minimal fills and strong forward motion.
- Effective tempo is generally brisk (roughly high-120s to mid-150s BPM, with many references clustering near ~130-150).
- Harmonic language is often static or slow-changing, with emphasis on groove and texture over chord progression complexity.
- Musical interest comes from micro-variation in texture/phrasing, not frequent structural changes.

### 3) Corpus to analyze

Primary references:

- Neu! - `Hallogallo`
- Neu! - `Neuschnee`
- Neu! - `Fur Immer`
- Harmonia - `Deluxe`
- Harmonia - `Walky-Talky`
- Harmonia - `Monza`

Secondary comparison set (for broader motorik behavior):

- Kraftwerk - `Autobahn` (instrumental sections)
- Kraftwerk - `Aerodynamik`
- Kraftwerk - `Endless Endless`
- Later motorik-influenced tracks (shortlist during analysis)

### 4) What to extract per track

For each analyzed song, capture:

- Tempo (BPM) and meter
- 1-bar drum pattern transcription (kick/snare/hat/cymbal accents)
- Fill frequency (fills per 16 bars)
- Harmonic rhythm (chord changes per 16 bars)
- Tonal center behavior (fixed key center vs drifting/ambiguous)
- Bass role (root-pulse, ostinato, melodic counterline)
- Melody behavior (motif length, contour shape, repetition rate, phrase length)
- Instrument roles by track part (lead 1/lead 2/pads/rhythm/texture/bass/drums) and their timbral families
- Arrangement arc (where and how density changes)
- Signature production traits (delay, space, saturation, width)

### 5) Translation to generator rules

Turn findings into explicit `Motorik Pulse` rule targets:

- Drum template(s): 2-3 canonical patterns with strict fill limits
- Tempo window: default + allowable randomization range
- Harmony policy: static center by default, optional slow-shift variant
- Bass policy: kick-locked anchor notes + constrained passing tones
- Melody policy: short motifs, bounded interval leaps, repetition-with-variation schedule
- Instrument policy: style-weighted defaults for lead 1/lead 2/pads/rhythm/texture/bass/drums with compatible alternates
- Variation policy: introduce changes every N bars, one dimension at a time
- Mix/effect defaults: tighter low end, controlled ambience, moderate tape-like grit

### 6) Validation protocol

- Generate 20 seeds with `Motorik Pulse`.
- Score each on 1-5 for: forward momentum, hypnotic continuity, coherence, over-complexity.
- Reject any preset/rule variant where >30% of outputs feel busy, fill-heavy, or harmonically restless.

### 7) Deliverables

- `research.md` update with measured findings table.
- `prototype.md` update with finalized Motorik rules.
- Short `motorik-preset-spec` block (defaults + min/max bounds) ready for implementation.

## Ambient Melodic Research Sprint

Purpose: define musical rules for Zudio ambient styles (especially `Ambient Drift`) using representative melodic ambient works from Jean-Michel Jarre and Brian Eno.

### 1) Jean-Michel Jarre corpus (ambient-leaning melodic references)

- `En Attendant Cousteau` (aka `Waiting for Cousteau`)
- `Oxygene, Pt. 2`
- `Oxygene, Pt. 3`
- `Oxygene, Pt. 6`
- `Equinoxe, Pt. 1`
- `Equinoxe, Pt. 4`

Why this set:

- Captures Jarre's blend of melodic hooks plus spacious synth texture.
- Includes both slow ambient drift and more pulse-oriented but still atmospheric material.
- Useful for rules around sequenced motifs, timbral motion, and harmonic simplicity.

### 2) Brian Eno corpus (melodic ambient references)

- `1/1` (Ambient 1: Music for Airports)
- `2/1` (Ambient 1: Music for Airports)
- `An Ending (Ascent)` (Apollo)
- `Always Returning` (Apollo)
- `Deep Blue Day` (Apollo)
- `Thursday Afternoon`

Why this set:

- Captures Eno's restrained melody language and long-form ambient pacing.
- Strong references for sparse lead behavior, slow harmonic motion, and non-intrusive texture.
- Good basis for low-density arrangement and high-coherence ambient generation rules.

### 3) What to extract for Ambient rule design

- Tempo zone or pulse feel (free-time, very slow pulse, or gentle grid)
- Tonal behavior (fixed center, modal drift, or near-atonal/`Free`)
- Melody profile (phrase length, note density, interval size, repetition frequency)
- Harmonic movement (static chord, drone, two-chord alternation, slow progression)
- Bass usage (absent/subtle, drone bass, simple root anchor)
- Pad behavior (sustain length, voicing width, movement rate)
- Lead-to-pad balance (foreground melody vs blended texture)
- Instrument families (analog synth, digital bell tones, piano/Rhodes-like colors, processed guitar-like textures)
- Effect signatures (reverb depth, delay feedback, modulation amount, saturation level)
- Arrangement arc over time (how changes are introduced without breaking calm continuity)

### 4) Translation targets for Zudio rules

- `Ambient Drift` tempo/pulse defaults and ranges
- Melody density caps for lead and bass in ambient modes
- Harmonic policy presets: `Static`, `Slow Shift`, `Free`
- Instrument default matrix by mood (`Bright`, `Deep`, `Dream`, `Free`)
- Effect-character defaults emphasizing space, width, and low harshness
- Variation cadence rules (very gradual updates, one dimension at a time)

## Working references

- Motorik overview and terminology: https://en.wikipedia.org/wiki/Motorik
- Neu! style overview: https://en.wikipedia.org/wiki/Neu%21
- Dinger/"Apache beat" context: https://www.washingtonpost.com/music/2022/09/23/neu-michael-rother-motorik/
- Track metric reference (tempo/key estimate for Hallogallo): https://songbpm.com/%40neu/hallogallo

## Motorik Pulse Findings (Research Pass v0.1)

This section converts the initial source review into implementable defaults for Zudio.

### Source-backed observations

- Neu!'s core pulse is a persistent 4/4 "motorik"/"Apache" beat built on continuity and forward motion rather than frequent fills or major pattern changes.
- Dinger described the beat as a human "long line"/"endless straight" feel, not a machine groove, which implies subtle feel variation over strict mechanical quantization.
- Neu! workflow often started from a simple basic track (drums + bass/guitar), then layered parts; this supports a generation pipeline where rhythm foundation comes first.
- Harmonia `Deluxe` era is more beat-forward than earlier Harmonia material and is useful for melodic motorik variants.
- Kraftwerk references (`Autobahn`, `Aéro Dynamik`, `Endless Endless`) are useful as electronic minimalism calibration: fewer timbres, tighter sequencing, efficient repetition.

### Track metrics snapshot (reference corpus)

- Neu! `Hallogallo`: ~153 BPM, 4/4, long-form repetitive drive.
- Neu! `Fur Immer`: ~144 BPM, 4/4, forward-driving vamp.
- Neu! `Neuschnee`: ~140 BPM reference (third-party metric), melodic but still pulse-led.
- Harmonia `Deluxe (Immer Weiter)`: ~143 BPM.
- Harmonia `Walky Talky`: ~169 BPM reference (likely perceived double-time in some systems).
- Kraftwerk `Autobahn`: often represented as ~75-77 half-time or ~150+ double-time.
- Kraftwerk `Aero Dynamik`: ~126 BPM (useful lower-bound electronic motorik-adjacent anchor).
- Kraftwerk `Endless Endless`: ~111 BPM (too slow for core motorik default, useful edge-case texture reference).

Interpretation for Zudio:

- Representative motorik generation should center on a brisk pulse, generally equivalent to ~126-154 BPM in straight feel (or ~63-77 half-time display).
- Best default center for `Motorik Pulse`: 138 BPM.

### Motorik rule spec for Zudio (v0.1)

- Global defaults
  - Style: `Motorik Pulse`
  - Pace default: `Drive` (138 BPM)
  - Allowed BPM range: 126-154
  - Time signature: fixed 4/4 in v1
  - Mood default: `Deep` or `Dream`
- Drum rules
  - Core pattern: kick on 1/2/3/4, snare on 2/4, steady hat/cymbal subdivision.
  - Fill policy: max 1 short fill per 16 bars.
  - Accent policy: phrase-start crash optional every 8 or 16 bars.
  - Humanization: very small velocity/timing drift (keep "human long-line" feel).
- Bass rules
  - Function: lock propulsion with drums; prioritize root + fifth anchors.
  - Pattern length: 1-2 bars, repeat-dominant.
  - Passing tones: sparse and diatonic; max 1-2 per bar.
  - Density: medium-high but rhythmically conservative.
- Rhythm track rules
  - Function: ostinato motor driver (muted guitar pulse or mono synth sequence).
  - Motif length: 1-2 bars.
  - Variation cadence: mutate one small detail every 8-16 bars.
- Pad and texture rules
  - Pads: restrained harmonic bed, slower motion than rhythm/bass.
  - Texture: sparse transitions (noise swells, filtered artifacts, tails), no constant busy motion.
  - Harmonic clutter guard: texture events should be mostly non-chord-defining.
- Lead 1 and Lead 2 rules
  - Lead 1: short motifs (2-6 notes), repetition with minor contour variation.
  - Lead 2: 30-60% of Lead 1 density, complementary intervals or off-beat answers.
  - Anti-clutter: if Lead 1 conflict occurs, thin Lead 2 first.
- Harmony policy
  - Default: static tonal center windows of 8-32 bars.
  - Chord-change ceiling: no more than 1-2 functional changes per 16 bars.
  - "Free" mood variant: reduce cadence behavior, keep interval leaps bounded.
- Arrangement policy
  - Long-form continuity over sectional contrast.
  - Add/remove one layer at a time (every 8 or 16 bars).
  - Avoid abrupt full-stop transitions.
- Effects/mix defaults
  - Drums: controlled room/space, moderate grit, avoid huge tails.
  - Bass: focused low-mid tone, low reverb.
  - Rhythm: tempo-locked echo at low mix, moderate width.
  - Pads/Texture: higher space/width but controlled low-end.
  - Global: light tape-like saturation and subtle bus glue.

### Motorik part-writing rules (v0.2: bass, rhythm, lead focus)

This pass tightens part-writing behavior using the target corpus (`Hallogallo`, `Fur Immer`, `Neuschnee`, Harmonia references, and Kraftwerk calibration tracks).

- Bass rules (clearer)
  - Core role: ostinato anchor, not melodic showcase.
  - Phrase length: mostly 1-bar or 2-bar loops.
  - Note vocabulary: tonal-center note + fifth + occasional stepwise approach notes.
  - Repetition target: 70-90% repeated cells per 16 bars.
  - Register: low-mid with little octave jumping.
  - Variation types allowed: rest placement shift, one passing tone insertion, octave reinforcement.
  - Variation frequency: one micro-change every 8-16 bars.
- Rhythm rules (clearer)
  - Core role: perpetual motion lane (guitar/synth pulse), complementing drums not replacing them.
  - Pattern type: short 8th/16th-note chug or sequenced pulse with minimal syncopation.
  - Chord behavior: often single-note or dyad-centric; avoid dense chord-strumming.
  - Dynamic contour: small pulse-level modulation over long spans rather than frequent riffs.
  - Fill policy: no "lick fills"; only timbre/accent changes.
- Lead 1 rules (clearer)
  - Core role: color and contour over the moving bed; motif-first writing.
  - Motif size: 2-6 notes; phrase length 1-2 bars.
  - Leap policy: mostly stepwise/small interval movement, occasional larger leap as event.
  - Repetition policy: repeated motif with one changed note/rhythm event every 4-8 bars.
  - Density guard: never continuous busy lead for more than 2 consecutive bars.
- Lead 2 rules (clearer)
  - Entry timing: randomized at bar 8 or 16 (existing rule).
  - Function: counterline/echo, not co-lead.
  - Density: 30-60% of Lead 1 events.
  - Counterpoint policy: prefer off-beat answers or interval complements; avoid unison doubling except occasional emphasis points.

### Song-linked observations that inform the rules

- `Hallogallo`: archetypal straight-ahead drive, long-loop continuity, motif-over-progression feel.
- `Fur Immer`: same propulsion family with pressure/release through texture/intensity rather than harmonic complexity.
- `Neuschnee`: melodic content present but still pulse-led and repetition-heavy.
- Harmonia (`Deluxe`, `Walky-Talky`, `Monza`): one-note/octave bass and pulse interplay; tension comes from layering/timbre shifts more than chord churn.
- Kraftwerk calibration (`Autobahn`, `Aero Dynamik`, `Endless Endless`): electronic minimalism reinforces the "few parts, long consistency, controlled mutation" rule.

### Updated probability constraints for musicality

- Bass micro-variation every 8 bars: 60%; every 16 bars: 40%.
- Rhythm timbre-variation event every 8 bars: 55%; every 16 bars: 45%.
- Lead 1 activity per 8 bars:
  - low density: 35%
  - medium density: 50%
  - high density: 15%
- Lead 2 response mode:
  - off-beat echo response: 50%
  - interval complement (third/sixth/octave): 35%
  - sparse unison punctuations: 15%

### Probability defaults for generative Motorik (v0.1)

- Lead 2 entry timing
  - Bar 8: 60%
  - Bar 16: 40%
- Drum pattern family
  - Core motorik: 55%
  - Accent variation: 30%
  - Sparse variant: 15%
- Bass pattern family
  - Root/fifth anchor: 50%
  - Anchor + passing tones: 35%
  - Syncopated anchor: 15%
- Harmonic mode
  - Static center: 65%
  - Slow shift: 30%
  - Free drift: 5%
- A/B section contrast
  - Single-A continuity: 45%
  - Subtle A/B: 40%
  - Moderate A/B: 15%
- Texture event chance
  - Per 8 bars: 35%
  - At section boundary: 70%
- Auto instrument family weights
  - Lead 1: synth lead 50%, guitar-like 20%, brass-synth 15%, piano/Rhodes 15%
  - Lead 2: bell/pluck 40%, secondary synth 40%, guitar-like counter 20%
  - Pads: warm analog 40%, glass/digital 30%, string/choir 30%
  - Rhythm: muted guitar pulse 45%, mono synth sequence 45%, arpeggiated poly 10%
  - Texture: noise bed 45%, tape/air 35%, metallic/percussive FX 20%
  - Bass: analog synth bass 45%, FM/digital 30%, electric/upright 25%
  - Drums: vintage electronic 45%, modern electronic 45%, acoustic variants 10%
- Effect profile weights
  - Drums: tight 60%, roomy 25%, gritty 15%
  - Bass: focused 65%, warm 25%, saturated 10%
  - Rhythm: dry pulse 35%, echo pulse 50%, wide pulse 15%
  - Pads/Texture: deep space 55%, wide haze 35%, filtered air 10%
  - Leads: echo-forward 50%, dry-forward 30%, saturated echo 20%
- Coherence constraints
  - Use linked probabilities so high-density choices on one track suppress high-density options on neighbors.
  - Block high-fill drums + high-density Lead 1 coincidence in the same 8-bar window.
  - Keep full determinism via seeded randomization.

### Generation algorithm mapping

- Step 1: select BPM, tonal center, instrument family defaults from style profile.
- Step 2: generate Lead 1 motif; derive Lead 2 counterline at lower density.
- Step 3: generate pads with static/slow harmonic map.
- Step 4: generate rhythm ostinato from bass/drum grid constraints.
- Step 5: place sparse texture events and apply style-weighted effect presets.
- Step 6: generate bass anchor pattern and drums pulse using hard lock constraints.
- Step 7: run collision and density checks; simplify in this order: Lead 2 -> Texture -> Lead 1.
- Internal dependency execution can still evaluate drums+bass+rhythm first for stability.

### Confidence and gaps

- High confidence: pulse architecture, repetition strategy, drum/bass role, long-form variation approach.
- Medium confidence: exact BPM centers for some tracks due cross-source disagreement and half-time/double-time reporting.
- V1 status: complete enough to implement Motorik generation rules and probability model.
- Optional future refinement: direct bar-level transcriptions for narrower BPM and micro-variation calibration.

### Motorik sources used for this pass

- Motorik overview: https://en.wikipedia.org/wiki/Motorik
- Neu! historical context: https://en.wikipedia.org/wiki/Neu%21
- Neu! and Dinger interview context: https://www.uncut.co.uk/features/neu-how-we-made-hallogallo-34624/
- Dinger/"Apache beat" overview article: https://www.washingtonpost.com/music/2022/09/23/neu-michael-rother-motorik/
- Harmonia context: https://en.wikipedia.org/wiki/Harmonia_%28band%29
- Harmonia `Deluxe` context: https://en.wikipedia.org/wiki/Deluxe_%28Harmonia_album%29
- Kraftwerk track context (`Aero Dynamik`, `Endless Endless`): https://en.wikipedia.org/wiki/Tour_de_France_Soundtracks
- Track metric references (third-party, approximate):
  - Hallogallo: https://songbpm.com/@neu/hallogallo
  - Fur Immer: https://songbpm.com/@neu/fur-immer
  - Neuschnee: https://getsongbpm.com/song/neuschnee/3MMX2
  - Harmonia Deluxe: https://www.shazam.com/song/1201079037/deluxe-immer-weiter
  - Harmonia Walky Talky: https://www.shazam.com/song/1201079038/walky-talky
  - Autobahn: https://songbpm.com/@kraftwerk/autobahn
  - Aero Dynamik: https://songbpm.com/@kraftwerk/aero-dynamik
  - Endless Endless: https://songbpm.com/@kraftwerk/endless-endless
