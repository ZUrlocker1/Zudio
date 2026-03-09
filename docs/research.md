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
  - Key-center probabilities: E 30%, A 20%, D 15%, G 10%, C 10%, B 8%, F# 7%
  - Mood probabilities: Deep 55%, Dream 30%, Bright 15%
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
- `Jenny Ondioline`: confirms two-chord, high-repetition motorik drive as a valid strict template.
- `Rheinita`: supports brighter melodic variant with cycling chord movement while retaining pulse consistency.
- `Theme for Great Cities`: supports minor/modal melodic loop variant with recurring hook gestures.
- `Trans-Europe Express`: supports sequence-first, tighter grid variant at slightly lower motorik-adjacent tempo.
- `Mother Sky` and `Hollywood`: support long-vamp and low harmonic-turnover variants with stronger timbral evolution.

### Additional template rules from selected songs

- Template A (strict motorik): two-chord loop, very low fill count, high ostinato repetition.
- Template B (bright melodic): 4-chord bright cycle with pulse-first rhythm section.
- Template C (melodic minor): minor/modal loop with delayed hook entry and repeat-heavy phrasing.
- Template D (sequencer-leaning): lower-mid tempo pocket, machine-tight sequence behavior.
- Template E (long-vamp): static harmony windows with texture-driven development.

### Updated probability constraints for musicality

- Bass micro-variation every 8 bars: 60%; every 16 bars: 40%.
- Rhythm timbre-variation event every 8 bars: 55%; every 16 bars: 45%.
- Chord progression family weights:
  - Static tonic hold (I or i): 35%
  - Two-chord alternation (I-bVII): 30%
  - Minor loop (i-VII or i-VI): 20%
  - Modal rock cadence (bVI-bVII-I): 15%
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
  - Align chord-change moments to strong pulse boundaries (bar starts / kick anchors).
  - Keep key stable by default; if key shift occurs, prefer step/fifth relation to prior key.
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

## Motorik-Adjacent Study: Electric Buddha Band Set (v0.1)

Reference tracks analyzed:

- `08 Time Loops.mp3`
- `09 Dark Sun.mp3`
- `12 Vanishing Point.mp3`
- `14 Into The Night.mp3`
- `15 Blakely Lab.mp3`
- `16 Schulers Dream 05.mp3`

Method note:

- Analysis used direct audio-feature extraction (tempo/pulse proxy, section/energy changes, intro/outro envelope behavior, density metrics).
- Tonal/instrument/effect observations below are inferred from full mix, not stem-level transcription.

### Per-song observations and rule candidates

- `08 Time Loops`
  - Observations: short runtime (~122s), brisk pulse (~120-133), short intro/outro, moderate section turnover.
  - Rule candidates:
    - Support fast-entry intros (1-2 bars).
    - Trigger structural changes via density/timbre shifts every ~16-32 bars.
    - Favor short subtractive outros (2-4 bars).
- `09 Dark Sun`
  - Observations: long runtime (~247s), fast pulse (~150), long intro (~17s), high section count.
  - Rule candidates:
    - Allow long atmospheric intro variant (8-12 bars) in long-form seeds.
    - Prefer frequent micro-arrangement changes over harmonic churn.
    - Use this as a template for evolving long-form Motorik.
- `12 Vanishing Point`
  - Observations: slower pulse (~92), very static macro form, high pulse regularity.
  - Rule candidates:
    - Add `Slow Cruise` motorik pocket (92-108 BPM).
    - Increase probability of static tonic or two-chord loop.
    - Keep Lead 1 sparse with longer motif repetition windows.
- `14 Into The Night`
  - Observations: short form (~58s), fast pulse (~150), lower regularity vs other tracks (more rhythmic contrast).
  - Rule candidates:
    - Add short-sketch mode (1-2 minute structures).
    - Allow controlled rhythmic looseness in non-drum tracks while drums stay anchored.
    - Use concise arc: quick entry -> one lift -> quick exit.
- `15 Blakely Lab`
  - Observations: mid pulse (~120), lower density profile, clear multi-block arc.
  - Rule candidates:
    - Increase sparse arrangement probability in A-sections.
    - Keep bass/drums central while pads/texture carry atmosphere.
    - Cap simultaneous active upper-mid tracks.
- `16 Schulers Dream 05`
  - Observations: mid pulse (~120), long stable middle region, stronger late transition behavior.
  - Rule candidates:
    - Favor long steady-state middles (64+ bars) in selected seeds.
    - Delay major lead mutation to later song stages.
    - Prefer texture-led late outros.

### Cross-song generalized rules (for Motorik generation)

- Tempo family weights:
  - Fast drive (132-150 BPM): 45%
  - Mid motorik (116-126 BPM): 40%
  - Slow cruise (92-108 BPM): 15%
- Intro family weights:
  - Fast lock-in intro (1-2 bars): 50%
  - Medium intro (4 bars): 35%
  - Long atmospheric intro (8-12 bars): 15%
- Outro family weights:
  - Short subtractive (2-4 bars): 60%
  - Medium subtractive/tail (4-8 bars): 30%
  - Extended atmospheric tail (8+ bars): 10%
- Form/structure weights:
  - 3-6 macro blocks (standard): 70%
  - 7-10 micro-variation blocks (long-form): 30%
  - In both modes, prefer timbral/rhythmic mutation over harmonic mutation.
- Track-writing emphasis:
  - Bass: root/fifth anchor as default; sparse passing tones; density tied to drum intensity.
  - Lead 1: motif-first with small mutation every 8-16 bars.
  - Lead 2: delayed entry (8/16 bars), lower density than Lead 1, response role.
  - Rhythm: pulse continuity lane, low syncopation, low harmonic movement.
  - Pads: slow harmonic bed with low chord-change frequency.
  - Texture: section-boundary events, avoid continuous clutter.
- Instrument/effect guidance (for later effects phase):
  - Drums/Bass: tighter space, mild saturation, minimal long tails.
  - Leads: tempo-locked echo, moderate stereo width.
  - Pads/Texture: wider space and longer tails, controlled low-end.
  - Keep modulation slow to preserve hypnotic continuity.

## Classic Motorik Calibration: Neu! + Harmonia + Cluster (v0.1)

Reference tracks analyzed:

- Neu!: `Hallogallo`, `Fur Immer`, `Neuschnee 78`, `Seeland`, `Wave Mother`
- Harmonia: `Deluxe (Immer Wieder)`, `Walky-Talky`, `Monza (Rauf Und Runter)`
- Cluster: `Breitengrad 20`, `Hollywood`

### Structure and pulse observations

- `Hallogallo` and `Fur Immer` show very long-form motorik drive with high pulse regularity and long intros.
- `Neuschnee 78` retains pulse drive but with shorter form and more melodic concentration.
- `Seeland` and `Wave Mother` validate slower/looser motorik-adjacent modes.
- Harmonia `Deluxe`/`Walky-Talky`/`Monza` support long development arcs and repetition-first movement.
- Cluster `Hollywood` supports extreme static-vamp behavior; `Breitengrad 20` supports section-rich but low-density evolution.

### Bass, Lead, Rhythm rule deltas (highest priority)

- Bass rules (updated)
  - Strict motorik mode (`Hallogallo`/`Fur Immer` profile):
    - 1-2 bar anchor ostinato
    - root/fifth dominance
    - sparse passing tones at phrase boundaries
  - Melodic motorik-adjacent mode (`Neuschnee`/`Wave Mother` profile):
    - slightly freer note choice, but still pulse-locked
  - Slow mode (`Seeland`/`Hollywood` profile):
    - lower attack rate, longer note values
  - Probability defaults:
    - anchor ostinato: 65%
    - anchor + sparse passing tones: 25%
    - melodic/stepwise bass: 10%
- Lead rules (updated)
  - Lead 1 entry in strict mode should often be delayed (long intros are valid).
  - Lead 1 remains motif-first with mutation cadence every 8-16 bars.
  - Lead 2 remains response-layer, lower density, delayed vs Lead 1.
  - Probability defaults:
    - Lead 1 entry <=8 bars: 20%
    - Lead 1 entry 9-16 bars: 45%
    - Lead 1 entry >16 bars: 35%
    - Lead 2 entry bar 8: 35%
    - Lead 2 entry bar 16: 45%
    - Lead 2 entry >16 bars: 20%
- Rhythm rules (updated)
  - Strict mode: continuous subdivision lock with low syncopation.
  - Evolution should come from accent/timbre changes, not riff complexity.
  - Slow mode: reduce rhythmic density and increase spacing.
  - Probability defaults:
    - strict pulse rhythm: 60%
    - pulse + light accent variation: 30%
    - sparse/atmospheric rhythm: 10%

### Intro/Outro and form deltas

- Intro family defaults (revised):
  - short lock-in (1-4 bars): 25%
  - medium intro (4-8 bars): 40%
  - long build (8-32 bars): 35%
- Outro family defaults (revised):
  - short subtractive (2-4 bars): 55%
  - medium subtractive/tail (4-8 bars): 35%
  - extended tail (8+ bars): 10%
- Form defaults (revised):
  - long-vamp or long-block form is strongly represented in classic corpus.
  - default should prefer fewer harmonic changes and longer continuity windows.

## Focused melodic rule extraction (v0.1)

Selected tracks for focused melodic/rhythm pass:

- Neu! `Neuschnee 78`
- Harmonia `Deluxe (Immer Wieder)`
- Cluster `Hollywood`

### Lead 1 rules (clearer)

- Motif shape:
  - 1-2 bar phrase cells with repeat-first behavior.
  - Mutation cadence every 8-16 bars (pitch contour or one rhythm event).
- Motion constraints:
  - Primary mode: repeated tones and small movement.
  - Secondary mode: occasional 3-5 semitone jumps for hook emphasis.
  - Large leap events should stay rare and phrase-local.
- Density constraints:
  - Keep note-event density below rhythm ostinato density in strict mode.
  - In melodic variant mode (`Neuschnee`-like), allow temporary Lead 1 density lift for one phrase window.
- Probability defaults:
  - conservative/repetition-first Lead 1: 60%
  - melodic/contour-active Lead 1: 30%
  - sparse/atmospheric Lead 1: 10%

### Lead 2 counter-melody rules (clearer)

- Functional role:
  - Response layer, not a co-lead.
  - Enter after Lead 1 in most seeds.
- Counterline strategy:
  - Off-beat response phrases first.
  - Interval complement (third/sixth/octave) second.
  - Unison punctuation only as occasional accent.
- Density and register:
  - 30-55% of Lead 1 note-event density.
  - Keep a register offset from Lead 1 to avoid masking.
- Probability defaults:
  - off-beat response: 50%
  - interval complement: 35%
  - sparse unison punctuation: 15%

### Rhythm instrument rules (clearer)

- Core behavior:
  - Continuous pulse lane with low syncopation in strict mode.
  - 1-bar or 2-bar ostinato loops with subtle accent shifts.
- Variation behavior:
  - Change timbre/accent before changing pattern shape.
  - Pattern-shape changes no more than once per 8-16 bars.
- Density modes:
  - strict pulse rhythm: 60%
  - pulse + accent variation: 30%
  - sparse/atmospheric rhythm: 10%

### Pads rules (clearer)

- Harmonic role:
  - Slow bed with low change frequency.
  - Hold chord windows long; avoid frequent re-voicing.
- Motion role:
  - Evolve tone/width before changing harmony.
  - Reserve stronger pad movement for section boundaries.
- Density limits:
  - Keep pad harmonic events below lead/rhythm event rates.
  - In sparse seeds (`Hollywood`-like), allow very long static pad/drone spans.
- Probability defaults:
  - long-hold static bed: 55%
  - slow-shift pad bed: 35%
  - motion-rich pad variant: 10%

## Creator profile extension: Electric Buddha melodic traits (v0.1)

Focused tracks used:

- `Dark Sun`
- `Time Loops`
- `Schulers Dream 05`
- `Blakely Lab`

### Additional melodic constraints to include

- Lead 1 contour behavior:
  - repeated-note and pedal behavior is strong (high same-note motion share)
  - stepwise movement is present but secondary
  - larger interval events are used as phrase accents
- Lead 1 interval-mode weights:
  - repeated/pedal motion: 45%
  - stepwise (1-2 semitone) motion: 20%
  - mid leaps (3-5 semitone): 15%
  - large leap accents (6+ semitone): 20%
- Lead 1 density modes:
  - low onset rate (`Schulers Dream`-like): 30%
  - medium onset rate (`Dark Sun`/`Blakely Lab`-like): 45%
  - high onset rate (`Time Loops`-like): 25%

### Lead 2 adjustments from creator profile

- Lead 2 should emphasize contrast against Lead 1's repeated-tone tendency.
- Recommended Lead 2 mode weights:
  - sparse off-beat punctuations: 45%
  - short answering phrases: 35%
  - interval-shadow counterline: 20%
- Keep Lead 2 density cap at <=55% of Lead 1 events.

### Pads adjustments from creator profile

- Pads should stabilize harmony when leads use wider leap accents.
- Pad mode weights (creator profile):
  - static/long-hold bed: 60%
  - slow-shift harmonic bed: 30%
  - motion-rich pad movement: 10%
- Voice-leading rule:
  - when Lead 1 enters high-leap mode, reduce pad re-voicing rate in the same window.

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
