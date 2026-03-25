# Motorik Style — Research & Implementation

## Context

Motorik is Zudio's original generative music style. It is derived from the krautrock and motorik
groove tradition — specifically the hypnotic 4/4 pulse pioneered by Neu!, Harmonia, Kraftwerk, and
their contemporaries. This document covers both the research behind the style and the complete
implemented generator specification.

For a higher-level description of how Motorik fits within the app's overall architecture, see
`docs/architecture.md`. The companion implementation reference for cross-style rules (tonal
governance, generation pipeline, performance engineering) is `docs/implementation.md`.

---

## Part 1: Genre Overview

**Motorik** (German: "motor-like") is the defining rhythmic identity of the krautrock movement.
The term describes the hypnotic, mechanically precise 4/4 pulse pioneered by Klaus Dinger of Neu!
— sometimes called the "Apache beat" after its influence on hip-hop. The key characteristics:
pulse continuity above all else, sparse harmonic movement, modal tonality, and melodic material
that is motif-first and repetition-heavy. The groove never stops; everything else orbits around it.

### Research methods

Research inputs used:

- Literature and context sources on Motorik and related artists
- Track-level listening and feature extraction
- Local MP3 analysis using Apple AVFoundation via Swift scripts

Primary extraction categories:

- Tempo and pulse behavior
- Intro/outro behavior
- Section continuity and change frequency
- Density and dynamic-shape proxies
- Melodic contour proxies (interval and repetition tendencies)

Method limits:

- Full-mix analysis only (no stems, no MIDI session data)
- Numeric outputs are proxies, not exact transcriptions

### Songs analyzed

**Canonical Motorik and adjacent:**

- Neu!: `Hallogallo`, `Fur Immer`, `Neuschnee 78`, `Seeland`, `Wave Mother`
- Harmonia: `Deluxe (Immer Wieder)`, `Walky-Talky`, `Monza (Rauf Und Runter)`
- Cluster: `Breitengrad 20`, `Hollywood`

**Creator reference songs (Electric Buddha Band):**

- `Time Loops`, `Dark Sun`, `Vanishing Point`, `Into The Night`, `Blakely Lab`, `Schulers Dream 05`

### Source references

- Motorik overview: https://en.wikipedia.org/wiki/Motorik
- Neu! historical context: https://en.wikipedia.org/wiki/Neu%21
- Neu! interview context: https://www.uncut.co.uk/features/neu-how-we-made-hallogallo-34624/
- Dinger/Apache beat context: https://www.washingtonpost.com/music/2022/09/23/neu-michael-rother-motorik/
- Harmonia context: https://en.wikipedia.org/wiki/Harmonia_%28band%29
- Harmonia Deluxe context: https://en.wikipedia.org/wiki/Deluxe_%28Harmonia_album%29
- Kraftwerk Tour de France Soundtracks context: https://en.wikipedia.org/wiki/Tour_de_France_Soundtracks
- Third-party tempo/key references (approximate):
  - Hallogallo: https://songbpm.com/@neu/hallogallo
  - Fur Immer: https://songbpm.com/@neu/fur-immer
  - Neuschnee: https://getsongbpm.com/song/neuschnee/3MMX2
  - Harmonia Deluxe: https://www.shazam.com/song/1201079037/deluxe-immer-weiter
  - Harmonia Walky Talky: https://www.shazam.com/song/1201079038/walky-talky
  - Autobahn: https://songbpm.com/@kraftwerk/autobahn
  - Aero Dynamik: https://songbpm.com/@kraftwerk/aero-dynamik
  - Endless Endless: https://songbpm.com/@kraftwerk/endless-endless

---

## Part 2: Song Analysis — Measured Evidence

### Neu! / Harmonia / Cluster

- `Hallogallo`: ~607s; strong sustained pulse regularity; long intro behavior; long continuity
  blocks with controlled transitions
- `Fur Immer`: ~678s; strong sustained pulse regularity; long intro behavior; long-form continuity
  with sparse large transitions
- `Neuschnee 78`: ~153s; tighter/shorter form than Hallogallo/Fur Immer; still pulse-forward but
  with stronger melodic focus
- `Seeland`: slower/looser pulse profile than strict Motorik core; long ambient-like continuity
  windows
- `Wave Mother`: medium pulse regularity; slower/adjacent profile with broader atmospheric behavior
- `Deluxe` / `Walky-Talky` / `Monza`: repetition-forward continuity with section-level timbral
  changes; evidence for long-form pulse-first development
- `Breitengrad 20` / `Hollywood`: low-density and static-vamp behavior evidence; strong support
  for sparse and long-hold harmonic sections

### Creator reference (Electric Buddha Band)

- `Dark Sun` / `Time Loops`: stronger use of repeated-tone melodic cells plus occasional larger
  leaps; supports hook design with repetition-first then accent intervals
- `Schulers Dream 05`: lower melodic onset density and long stable spans; supports sparse lead mode
  and long continuity windows
- `Blakely Lab`: restrained density with clear block-level structure; supports minimal embellishment
  behavior over core groove

### Pass 2 lead-focused analysis (March 2026)

Analysis run on 13 tracks (Neu!/Harmonia/Cluster + Electric Buddha set).

**Canonical set (Neu!/Harmonia/Cluster, n=7):**

- Mean BPM proxy: ~129.43
- Mean pulse regularity: ~0.689
- Mean subdivision regularity: ~0.523
- Mean density proxy: ~1812.56
- Mean intro ratio: ~9.1% of track length
- Mean outro ratio: ~1.1% of track length
- Mean section-count proxy: ~7.29

**Creator set (Electric Buddha, n=6):**

- Mean BPM proxy: ~127.61
- Mean pulse regularity: ~0.585
- Mean subdivision regularity: ~0.355
- Mean density proxy: ~1541.57
- Mean intro ratio: ~2.6% of track length
- Mean outro ratio: ~4.8% of track length
- Mean section-count proxy: ~4.33

**Lead-oriented observations:**

- Canonical references show higher subdivision regularity and higher density proxies than the
  creator set, supporting longer continuity-driven lead arcs over short repeated fragments
- Creator-set tracks exhibit shorter intros and comparatively larger outro windows, supporting
  delayed lead entry and clearer lead de-intensification near endings
- Higher section-count proxies in canonical tracks support multi-phrase solo development over long
  timelines instead of short loop-only lead behavior

---

## Part 3: Universal Motorik Rules

These rules are non-negotiable for the output to sound Motorik. Derived from analyzing the full
reference set.

### Rhythm

- The pulse is the song. Kick/snare backbone stability matters more than frequent pattern changes.
- Variation lives in the hats, cymbal articulation, accent placement, and occasional fills — not
  in rewriting the groove identity.
- Bass coherence comes from matching drum intensity and honoring phrase boundaries.

### Harmony

- Harmonic movement is slower than rhythmic movement. Long static or two-chord windows are not
  just acceptable — they are stylistically correct.
- Sparse harmonic rhythm and restrained re-voicing preserve the Motorik trance effect. Pad
  re-voicing should lag well behind lead mutation cadence.

### Melody and countermelody

- Lead material is most convincing when motif-first and repetition-heavy. Random note sequences
  do not sound Motorik.
- Countermelody works as a delayed, lower-density response — not as a co-equal lead.
- Vertical clarity comes from register separation and reducing simultaneous accents.

### Scale and tonality

- Minor-family and modal-minor colorations (Aeolian, Dorian, Mixolydian) are most compatible with
  the reference songs.
- Pentatonic reduction is an effective conflict-reduction fallback in dense sections.

---

## Part 4: Web Evidence and Additional Sources

### Melodic hooks and solo continuity

- Embellishing-tone evidence (Open Music Theory) supports placing non-chord tones mainly as
  controlled passing/neighbor events with stepwise resolution behavior
- Counterpoint motion evidence supports using contrary/oblique movement and avoiding excessive
  parallel lockstep when two lead lines are active
- Motive-development evidence supports systematic variation methods (sequence, inversion, rhythmic
  change, expansion/compression) for maintaining identity while avoiding repetition fatigue

Sources: https://viva.pressbooks.pub/openmusictheory/chapter/embellishing-tones/,
https://viva.pressbooks.pub/openmusictheory/chapter/species-counterpoint/,
https://viva.pressbooks.pub/openmusictheory/chapter/motive/

### Tonal governance

- Key-profile evidence (music21, Essentia, keycor profile sets) supports explicit key/mode
  estimation and confidence scoring, using Krumhansl-Kessler and Temperley profiles as practical
  tonal-center models
- Open Music Theory embellishing-tone guidance supports treating non-chord tones as controlled
  events that resolve quickly and are less stable on strong beats
- Species counterpoint guidance supports consonance emphasis on structurally strong positions and
  controlled dissonance treatment on weaker positions
- Combined implication for generative rules: one parent key/mode per section; chord-window note
  pools per section; strict strong-beat chord-tone enforcement for support layers (bass/pads/rhythm);
  explicit clash-repair pass for competing melodic layers

Sources: https://www.music21.org/music21docs/moduleReference/moduleAnalysisDiscrete.html,
https://essentia.upf.edu/reference/streaming_KeyExtractor.html,
https://github.com/jackmcarthur/keycor

### L.A. Woman reference hypothesis

User-provided observation set (treated as stylistic hypothesis, not canonical Motorik evidence):

- Four-on-floor drive is close to Motorik pulse feel
- Bass is repetitive/drive-forward but not purely root-note static
- Lead interplay (guitar foreground + electric-piano response) is relevant to Lead 1/Lead 2
  layering
- Tonal center: A-major center with D-major pitch material (Mixolydian interpretation)
- MIDI structure observed: guitar lead enters ~bar 17; rhythm guitar ~bar 28; keyboard response
  ~bar 13; additional electric-piano lead ~bar 110; two bass tracks show intro-layer then
  variation-layer entry; drums begin ~bar 3

Evidence-use boundary: treated as stylistic hypothesis for rule design; adapted under Motorik
coherence constraints.

Rules informed: `L2-002`, `L2-003`, `I-002`, `I-003`, `I-004`

### Rule ID evidence mapping

Evidence from this research maps to rule IDs in `docs/implementation.md` as follows:

- Structure/continuity evidence → `G-001`, `G-002`, `G-003`, `G-004`
- Key/mode and note-pool evidence → `T-001` through `T-007`
- Rhythm-section interaction evidence → `D-001`, `D-002`, `B-001`, `B-002`, `R-001` through `R-005`
- Bass coherence evidence → `B-003`, `B-004`, `B-005`
- Lead/counterlead evidence → `L1-001`, `L1-002`, `L1-003`, `L2-001`, `L2-004`
- L.A. Woman role-evolution hypothesis → `L2-002`, `L2-003`, `I-002`, `I-003`, `I-004`
- Texture punctuation evidence → `X-001`, `X-002`, `X-003`
- Cross-track clash findings and tonal conflict mitigation → `I-001`, `Q-001`, `Q-002`, `Q-003`, `Q-004`

---

## Part 5: Comparison with Kosmic and Ambient

- **Tempo:** Motorik 126–154 BPM / Kosmic 88–126 BPM (slight overlap) / Ambient 66–92 BPM (no overlap)
- **Rhythm anchor:** Motorik = kick/snare groove is the primary element; Kosmic = arpeggio sequencer, no required backbeat; Ambient = no felt tempo anchor, phase relationships create variation
- **Harmonic rhythm:** Motorik = 4–16 bar windows; Kosmic = 8–32 bar windows; Ambient = loops of incommensurable lengths, no scheduled chord changes
- **Song structure:** Motorik = Intro/A/B/Outro with intensity arcs and fills; Kosmic = long evolving sections, glacial pacing, optional bridges; Ambient = co-prime loop tiling, no sections
- **Lead melody:** Motorik = motif-first, syncopated, rhythmically active; Kosmic = sparse, long-note, embedded in arpeggio pulse; Ambient = minimal or absent, occasional floating phrase
- **Drums:** Motorik = full groove is the defining element; Kosmic = sparse, optional, never a backbeat; Ambient = absent or hand percussion only
- **Energy model:** Motorik = propulsive, outward; Kosmic = immersive, inward; Ambient = static, meditative, near-timeless
- **Variation unit:** Motorik = per-section (A/B intensity change); Kosmic = per-layer cycle (staggered evolution); Ambient = phase drift between loops

---

## Detailed Implementation

Target references: Neu! (`Hallogallo`, `Fur Immer`, `Neuschnee`), Harmonia (`Deluxe`,
`Walky-Talky`, `Monza`), Kraftwerk (`Autobahn`, `Aero Dynamik`), Electric Buddha Band.

### Global profile

- Tempo: default 138 BPM, range 126–154 BPM, fixed 4/4
- Mood: Deep 55%, Dream 30%, Bright 15%
- Key-center: E 30%, A 20%, D 15%, G 10%, C 10%, B 8%, F# 7%
- Progression families:
  - Static tonic hold (I or i): 35%
  - Two-chord alternation (I-bVII): 30%
  - Minor loop (i-VII or i-VI): 20%
  - Modal rock cadence (bVI-bVII-I): 15%

### Song structure

**Forms:**

- Single-A (45%): intro | A | outro. Body in three intensity sub-phases (low 25%, medium 50%,
  high 25%) used internally for drum/track density — not formal section boundaries.
- Subtle A/B (40%): intro | A | B | outro. A = 32–80 bars (32: 25%, 48: 35%, 64: 30%, 80: 10%),
  B = bodyLength − A (min 32). B starting intensity = A ending ±1 step (clamped low/high). At
  least one of Lead 1, Pads, or Bass must change density profile at A→B boundary.
- Moderate A/B (15%): intro | A | B | outro, or with A' reprise (30% chance; A' = 16–32 bars).
  Mode may shift at A→B boundary (50% chance); allowed pairs: Aeolian↔Dorian, Ionian↔Mixolydian.
  B starting intensity = A ending + 1 step (max high). Lead 1 shifts to solo-phrase behavior in B.

Intro length: 2 bars (50%) or 4 bars (50%).
Outro length: 4 bars (50%) or 8 bars (50%).

**Chord plan rules:**

- No chord window may cross a section boundary
- Intro and outro: one chord window per section, chord root always "1" (tonic)
- After chord plan is built, intro chord root/type is replaced with first body chord's root/type
  to prevent harmonic jump at intro→body transition. Outro stays at tonic.
- Main section window lengths set by progression family:
  - static_tonic: one window per section | two-chord: 8–16 bar windows
  - minor loops: 8–12 bar windows | modal cadence: repeating 8-bar 3-chord groups

**Section intensity assignment:**

- Intro and outro: always `low`
- Subtle A/B — A: low 20%, medium 80%
- Subtle A/B — B: A-ending intensity ±1 (clamped)
- Moderate A/B — A: low 10%, medium 90%
- Moderate A/B — B: A-ending intensity +1 step (max high)

### Intro and outro behavior

**Intro types (equal 33% each):**

- *Already Playing*: all tracks present from bar 1 at low velocity (~55%), ramping to full level
  across intro bars. Actual body patterns in use throughout.
- *Progressive Entry*: simplified bass riff throughout; pads enter on final intro bar only; Lead 1,
  Lead 2, Rhythm, Texture suppress until body; drums may play sparse pattern. Simplified intro
  bass is per-rule: complex rules (BAS-005 through BAS-011) strip to rule identity; simple rules
  (BAS-001/003/004) add interest with scale walks or arpeggios.
- *Cold Start*: drum fill pickup mid-bar. Two sub-variants (50/50):
  - Drums-only: bar 0 is partial drum fill only (mid-bar pickup); bass and all others silent until bar 1
  - Bass+drums: bar 0 has drum fill + simplified bass riff; all others enter bar 1

**Outro types (equal 33% each):**

- *Fade*: all tracks thin velocity/density gradually; pads 15% per-bar skip chance
- *Dissolve*: pads never skip — the harmonic bed is the last sound; others drop progressively
- *Cold Stop*: all tracks cut on final bar; drum fill as last event; hard silence follows

**Volume fading**: `PlaybackEngine` handles all intro/outro volume shaping via
`AVAudioMixerNode.outputVolume` at runtime. Generators write notes at full body velocity; the
engine scales volume across intro and outro. On song start from step 0, `mainMixerNode` is zeroed
50ms before the scheduler fires to prevent a DSP-init click.

**Intro/outro layer order:**

- Already Playing: all tracks active from bar 1
- Progressive Entry: bass only in intro; pads join final intro bar; others wait for body
- Cold Start drumsOnly: drums pickup only; all others enter bar 1 of body
- Cold Start bass+drums: bass + drums in pickup; all others enter bar 1 of body
- Outro Fade: all tracks with gradual velocity/density reduction; pads 15% skip
- Outro Dissolve: pads last; others may drop early
- Outro Cold Stop: pads cut on final bar; drum fill as last event

Spotlight and bass evolution annotations do not extend into the outro — no variation logic
generates for outro bars.

### Drum patterns

Pattern selection by section intensity: low → sparse, medium → core_a, high → core_b/ride/open hat lift.

**Groove families:**

- Core motorik pulse (55%): core_a first 8-bar phrase → core_b next 8 bars, alternating. Reset
  at section boundary.
- Accent variation (30%): ride 40%, open hat lift 40%, core_b +12 velocity 20%.
- Sparse variant (15%): sparse pattern for full phrase window.

**Structural rules:**

- Kick: syncopated Motorik pattern. Core A: steps 0, 2, 6, 8, 14. Core B: steps 0, 2, 6, 8, 10, 14.
- Snare: beats 2 and 4 (steps 4 and 12) in all non-sparse patterns
- Hat/cymbal: 8th-note positions with closed hat; open hat or ride for accent variants
- Crash accents mainly at phrase/section starts

**Fill sources (three independent triggers):**

- Section transitions: bar before each new body section
- Instrument entrances: bar before a non-drum track entering after ≥2 bars of silence
- Periodic body cadence: bars 3, 7, 11, 15… within each body section; crash lands on next phrase
  downbeat. Skip if bar already tagged by another source.

**Fill lengths:** 1 beat (60%), 2 beats (30%), 1 bar (10%). Most fills are 1-beat subtle variants
(Ghost Whisper or Sidestick Flam) — groove remains intact.

**Velocity ranges:**

- Low: kick 92–106, snare 84–100, hats 62–86
- Medium: kick 104–118, snare 96–112, hats 72–100
- High: kick 112–124, snare 104–120, hats 82–108
- Accent pulse every 2 or 4 bars: +6 to +10 velocity

**Drum rules:**

- DRM-001 — Classic Motorik Apache beat: kick 1+3, snare 2+4, 16th hi-hats with velocity gradient.
  Canonical Neu!/Apache pattern.
- DRM-002 — Open Pocket: kick 1+3, snare 2+4, 8th hats, open hat accent beat 1, ghost snares.
- DRM-003 — Dinger groove: kick 1+3, snare 2+4, ride on 8ths, pedal hat 2+4. Named for Klaus
  Dinger (Neu!).
- DRM-004 — Mostly Motorik: 4-on-the-floor kick, snare 2+4, 16th hats. Later Neu!/Can electronic
  feel.

**Intro behavior:** drums-only intro — kick+hat first; snare enters by bar 2 or 3; 35% chance of
pickup fill in final intro bar.

**Outro behavior:** reduce cymbal/hat density first; remove snare ghost accents; last bar may end
kick-only (40%).

### Bass rules

One rule selected per song. All patterns anchor beat 1 as primary attack, matching the kick drum.

**Bass variation for simple rules** (BAS-001/002/004): in B sections or after bar 48, substitutes
a slightly more complex variant to maintain musical interest without abandoning the rule's identity:

- BAS-001 variation: quarter-note walk root→third→fifth→root (mode-correct)
- BAS-002 variation: root–root–third–root quarter pulse (mode-correct third on beat 3)
- BAS-004 variation: root (long)→third→fifth arc (mode-correct passing third)

Status log emits `BASS-EVOL` when variation begins; `BASS-DEVOL` when it reverts. Variation runs
through qualifying section(s) only — alternates every other A section after bar 48.

**Bass rule catalog:**

- BAS-001 Root Anchor (10%): root beat 1 (long sustain), chord tone beat 3. Simplest Motorik bass.
- BAS-002 Motorik Drive (10%): four staccato quarter notes, velocity accented beats 1+3.
- BAS-003 Crawling Walk (7%): 2-bar root/fifth/approach-note pattern. Slow stepwise motion.
- BAS-004 Neu! Hallogallo lock (10%): root beat 1 (long), fifth beat 3, kick-locked.
- BAS-005 McCartney Drive (12%): 8th-note groove; bar 1 descends root→m3→5→m3, bar 2 breathes
  with root sustain + approach pickup. ~1/3 chance of all-drive 4-bar block.
- BAS-006 LA Woman Sustain (6%): root holds most of bar, chromatic neighbor shimmer at end.
- BAS-007 Hook Ascent (11%): high-register melodic riff; bar 1 hammers major third in 8th notes
  then descends, bar 2 falls to root with minor 6th color. Inspired by Peter Hook / Joy Division.
- BAS-008 Moroder Pulse (9%): staccato 8ths root-root-fifth-fifth-b7-b7-root-root. Mechanical,
  relentless. Inspired by Giorgio Moroder "I Feel Love".
- BAS-009 Vitamin Hook (7%): bar 1 climbs root→fifth→octave with passing tone, bar 2 descends
  and breathes. Inspired by CAN "Vitamin C".
- BAS-010 Quo Arc (10%): 2-bar boogie-woogie arc; bar 1 ascends 1-1-3-3-5-5-6-b7, bar 2
  descends. Always uses boogie scale (1-3-5-6-b7). Inspired by Status Quo "Down Down".
- BAS-011 Quo Drive (8%): compressed 1-bar boogie arc; root-push variant on even bars. Inspired
  by Status Quo "Caroline" / "Paper Plane".
- BAS-012 Moroder Chase (7%): delay-echo 16th-note ostinato; primary 8th notes cycle
  root–mode3rd–fifth; quieter echo fills intermediate 16th steps simulating digital delay
  doubling. Even bars: full three-note cycling; odd bars: root–root–fifth–root. Inspired by
  Moroder "Chase" (Midnight Express). Always emits BASS-EVOL.
- BAS-013 Kraftwerk robotic bass (7%): octave-jump 3-note cell root(8th)–root+octave(8th)–
  mode3rd(quarter), twice per bar. Bars 0–1 of 4-bar group: mode3rd landing; bars 2–3: fifth for
  harmonic lift. Every 8th bar is root-only lock. Inspired by "The Robots". Always emits BASS-EVOL.
- BAS-014 McCartney melodic drive (8%): 8-note Mixolydian riff root–fifth–root–b7–fifth–root–
  mode3rd–root in 8th notes on even bars; odd bars breathe with root hold + root–fifth–root
  walkup. Flat-seventh gives blues/Mixolydian edge; reverts to fifth in pure major contexts.
  Inspired by "Paperback Writer". Always emits BASS-EVOL.
- BAS-015 Kraftwerk Autobahn driving bass: three rotating patterns cycling at section boundaries
  and every 16 bars — Pattern D (sparse anchor: beats 1, 2, 3 with octave jump on beat 2),
  Pattern E (canonical Autobahn hook with root, octave, passing tone, fifth), Pattern C (8th-note
  root/octave trill for sustained momentum). Inspired by Kraftwerk "Autobahn".

**Bass writing rules:**

- Phrase length: 1–2 bars; repetition target: 70–90% repeated cells per 16 bars
- Passing tones: max 1–2 per bar, weak-beat biased, resolve within ≤1 bar
- Register: MIDI 28–64 (center 40–56)
- Strong-beat targets: root 60–75%, fifth 15–30%, other chord tones 5–15%
- Drum-bass lock: 75–90% of bass onsets align to kick grid; avoid snare backbeats (beats 2/4)
  except intentional accents

### Pads

One primary style per song. PAD-004 always applied on top of primary style for intro/outro skip
behavior.

**Pad style catalog:**

- PAD-001 Harmonia sustained notes whole-bar (22%): one chord attack per bar, duration 14 steps.
  After 4 consecutive sustained bars, auto-injects PAD-007 charleston bar to break monotony, then
  resets the run counter.
- PAD-002 Power/drone voicing (17%): root+fifth+octave whole-bar (no third — maximally open and
  modal). Same 4-bar break rule applies.
- PAD-003 Pulsed 2-bar (15%): one attack every 2 bars, duration 30 steps. Very sparse.
- PAD-004 La Dusseldorf sparse (always active on top): controls intro/outro skip behavior per bar.
- PAD-006 Chord stabs (14%): beat 1 hit (dur 4), 50% chance secondary hit on beat 3 at lower
  velocity.
- PAD-007 Harmonia charleston / 3+3+2 (18%): hits at steps 0 (dur 5), 6 (dur 5), 12 (dur 4).
  Derived from Silly Love Songs verse rhythm guitar analysis.
- PAD-010 Half-bar breathe (9%): chord on beat 1 (dur 7), silence second half. Maximum air.
- PAD-011 Backbeat stabs (5%): hits on beats 2+4 only (steps 4 and 12, dur 3). Off-beat emphasis.
  Derived from LA Woman guitar 2 analysis.

All chord voicings use 4-note open spread, register MIDI 48–84. No thirds below MIDI 60.

**PAD-004 intro behavior:** Progressive Entry — pads skip until final intro bar. Already Playing —
20% skip per bar. Cold Start drumsOnly — pads suppress entire intro. Cold Start bass+drums — 50%
skip on bars after bar 0.

**PAD-004 outro behavior:** Fade — 15% skip per bar. Dissolve — pads never skip; they are the
final sound. Cold Stop — pads cut on final outro bar.

**Pad writing rules:**

- Chord-change ceiling: 1–2 functional changes per 16 bars
- Progression shape: loop-first, linear/modal movement; no circle-of-fifths
- Re-voice less often than Lead 1 motif mutation cadence (target every 8–16 bars)
- If Lead 1 activity is high, reduce pad re-voicing and keep stable shell voicings

### Lead 1

**Writing rules:**

- Motif-first behavior, 2–6 note motifs; micro-motif length 1–2 bars; macro phrase blocks 4–8 bars
- Mostly stepwise/small intervals
- Anti-fragment rule: at least one 3+ note cell per phrase; 1–2 note cells only as
  pickups/echoes/cadence
- Repetition limit: max 2 consecutive identical bars; in any 8-bar window require ≥3 variation
  events (rhythmic displacement, note-length change, interval expansion/compression, sequence copy,
  contour inversion, extension/truncation)
- Rest-space: 25–45% silent steps; force one breath every 4 bars (half-bar rest or one silent bar)
- No high-density run longer than 2 bars; avoid repeated peak-note hammering (>3 hits)
- After large leap (≥6 semitones), recover in opposite direction within 1–2 notes
- Hook-identity model: one primary hook cell per section (3–7 notes), restated every 4–8 bars in
  transformed form (rhythmic displacement 30%, ending-tone change 25%, interval change 20%,
  sequence up/down 15%, contour inversion 10%). At least two anchor events unchanged across
  restatements (same opening interval, or same rhythmic accent, or same cadence degree).
- Solo-journey arc (16-bar): bars 1–4 low/medium statement | bars 5–8 answer | bars 9–12
  development (slightly wider range or denser rhythm) | bars 13–16 resolution and cadence
- One clear intensity peak per 16 bars; de-intensify within 1–2 bars after peak
- Reuse at least one transformed hook from prior section to preserve song identity

Entry: suppressed in intro by default; 20% chance of pickup motif in last intro bar.
Exit: ends 1–2 bars before final stop (except subtractive fade).
Register: MIDI 60–88; max 2 simultaneous notes.

**Lead 1 rules:**

- LD1-001 — Neu! motif first: 4-bar phrase seeds cycling with slow mutation; chord tones 80%,
  tensions 20%.
- LD1-002 — Pentatonic Cell: short driving cell from pentatonic scale, locked 16 bars then
  one-interval mutation.
- LD1-003 — Long Breath: sparse, long sustained notes with generous rests.
- LD1-004 — Stepwise Sequence: descending sequence development (5→4→2→1 bar A, b7→5→4→2 bar B).
- LD1-005 — Statement-Answer: bar A ascends 1→2→b3→5; bar B silent then answers 4→b3. From
  Hallogallo analysis.

### Lead 2

- Entry: bar 8 (60%) or bar 16 (40%)
- Density: 30–55% of Lead 1 event density
- Response mode: off-beat echo (50%), interval complement 3rd/6th/octave (35%), sparse unison
  punctuation (15%)
- Counter-hook policy: builds from Lead 1 anchors (rhythmic echo, interval complement, delayed
  answer); does not introduce independent long-form hook when Lead 1 is active; ≥60% of phrases
  begin after Lead 1 phrase onset (call/response feel)
- Role-handoff: if Lead 1 absent for a section, Lead 2 may assume Lead 1 foreground role; returns
  to response within 1–2 bars when Lead 1 returns; the 55% density cap is suspended during handoff
- Doubling windows: Lead 2 and Rhythm (or Lead 1) may play same motif in unison/octave; typical
  1–4 bars (extended jam up to 8); require ≥2 bars of divergence after
- Never active during intro; drops before Lead 1 in outro
- Register: MIDI 55–81; max 1 simultaneous note

**Lead 2 rules:**

- LD2-001 — Counter-response: density ≤55% of Lead 1, avoids Lead 1 steps.
- LD2-002 — Sustained Drone: very sparse, long holds on root or 5th.
- LD2-003 — Rhythmic Counter: short bursts offset from Lead 1 rhythm.
- LD2-004 — Neu! counter melody: 16th-note pairs at steps 0, 2, 4, 6, 10, 12, 14, 15. From
  guitar 2 analysis.
- LD2-005 — Descending Line: off-beat 2-bar arc 6→5→b3→2 with velocity diminuendo.
- LD2-006 — Neu! harmony: interval-shadow counterline following Lead 1 contour at consonant
  interval.

### Scale and hook rules (Lead 1/2)

**Scale pool:** Natural Minor (Aeolian) 35%, Dorian 20%, Mixolydian 20%, Major (Ionian) 15%,
Minor Pentatonic 7%, Major Pentatonic 3%. This is a lead-writing default and does not override
section key/mode selected by tonal governance.

**Lead 1 hook construction:**

- 5-note subset of active scale for most motifs
- Degree priority: minor-family modes: 1, 2, b3, 5, b7; major-family: 1, 2, 3, 5, 6
- Add one mode color tone occasionally as signature note event

**Lead 1 interval profile:** repeated (0) 25–40%, step 1–2 semitones 30–45%, small leaps
3–5 semitones 15–25%, large leaps 6+ 5–12%. After large leap, reverse direction 70%.

**Lead 2 scale policy:** same parent scale as Lead 1; simpler subset (often pentatonic-biased);
prefer 3rd/6th/octave complementary intervals and contrary/oblique motion; avoid continuous
parallel lockstep with Lead 1. Strong-beat chord-tone targets: Lead 1 70–85%, Lead 2 80–90%.

**Phrase landing stability:** phrase-end notes should land on stable tones (root/third/fifth)
≥80% of phrase endings.

### Rhythm

**Rhythm rules:**

- RHY-001 — 8th-note stride: alternating root/fifth/third cycle, active Motorik pulse.
- RHY-002 — Quarter-note stride: root-anchored open quarter notes, spacious feel.
- RHY-003 — Syncopated Motorik: hits at steps 0, 3, 6, 8, 11, 14 (3+3+2+3+3+2 feel),
  root/fifth alternation.
- RHY-004 — 2-bar melodic riff: scale-tone riff cycling over 2 bars, quarter-note grid.
- RHY-005 — Chord stab: root+third short hits on beats 2 and 4.
- RHY-006 — Harmonia arpeggio: quarter-note legato through chord tones; direction fixed per song
  (up, down, up-down bounce, down-up bounce, or ping-pong).

**Writing rules:**

- 1–2 bar ostinato, repeat-first
- 8th/16th pulse bias, minimal syncopation
- 20–45% silent steps in active rhythm bars
- Do not keep identical subdivision density for more than 4 bars; change every 2–4 bars
- Keep event density below drum transient density; thin or shorten notes if masking Lead 1 range
- Rhythm is a pulse enhancer, not a harmonic lead
- Usually absent in first half of intro (75%); drops before bass and drums in most outros

### Texture

TEX-001 (always active) is the backbone; 1–2 supplementary rules are selected per song and layered
on top. Texture must remain sparser than Rhythm and Lead 2.

- TEX-001 — Cluster sparse backbone (always): single scale-tension notes, boundary-weighted
  (45% at section start/end bars, 5% elsewhere). Register MIDI 72–108.
- TEX-002 — Transition Swell: sustained root or fifth at section boundaries, warm register
  (MIDI 60–84), duration 24–32 steps; fires at ~70% of boundary bars.
- TEX-003 — Harmonia drone anchor: 2-bar root/fifth hold, very low velocity (28–40), ~once per
  24 bars, body sections only. Register MIDI 60–72.
- TEX-004 — Shimmer Pair: two notes a major-7th or minor-9th apart, short (4–6 steps), off-beat
  (step 6 or 10), ~once per 10 bars. Evokes the Rother/Roedelius shimmer.
- TEX-005 — Eno Cluster breath release: quiet note (vel 25–35) on last step of each section's
  final bar, 50% probability per section end.
- TEX-006 — High Tension Touch: single scale-tension note, off-beat, duration 8–10 steps,
  ~once per 20 bars, body sections only.

TEX-001 and TEX-005 also fire in intro/outro. TEX-003 and TEX-006 are body-only.

### Chord voicing specification

**Fundamental rule:** Never place a minor or major third as the lowest interval in a pad voicing
below MIDI 60. The lowest interval must be a perfect fourth, perfect fifth, or octave. Thirds
belong in middle and upper voices only. Muddy low-register thirds are the most common voicing
mistake in this style.

**Pad chord root placement:** MIDI 48–60 (C3–C4). Allows voicing to spread upward into the pad
register (MIDI 48–84) while keeping the root grounded.

**Default open voicing (major and minor triads):**

- Major triad: 0, +7, +12, +16 (root — fifth — octave — major third)
- Minor triad: 0, +7, +12, +15 (root — fifth — octave — minor third)

The defining interval (the third) sits at the top of the voicing where it sings clearly. The bass
register carries only the stable fifth and octave. Use this for the large majority of pad events.

**Alternative voicings:**

Power/drone: root+fifth only (0, +7 or 0, +7, +12). No third; lead or bass defines quality.
Use over static drone sections, when melody would clash with the third, or to break up full-triad
voicings.

Sus2 (primary Motorik color chord): 0, +7, +12, +14 (root — fifth — octave — major second).
Neither major nor minor; no directional pull; sits indefinitely. Use as substitute for major triad
on long-held chords for floating quality; when melody note is the 2nd/9th; over pedal tones.
Can alternate slowly between sus2 and parent major chord on same root. Use 1–2 times per 16-bar
section.

Sus4: 0, +7, +12, +17 (root — fifth — octave — perfect fourth). Tension that demands resolution.
Use only where resolution follows immediately (same bar or next). No more than 1 per 8-bar window.
Do not hold sus4 unchanged for 4+ bars.

Add9: 0, +7, +16, +26 (or omit octave: 0, +7, +16). Ninth must sit above the third — never
adjacent to root in low register (that is a harsh cluster). Use on tonic or IV chords where ninth
is diatonic; as slow variation by adding ninth voice to an already-held major triad. 1–2 per
section on stable tonic/IV chords. Do not use on vii or where ninth is chromatic.

Dom7 shell: 0, +4, +10 (A-voicing) or 0, +10, +16 (B-voicing). The tritone between third (+4)
and seventh (+10) is the color; keep both. In Motorik/modal contexts, 7th chords do not resolve —
they are sustained color chords. Use in Mixolydian sections (b7 is diatonic). Do not use major 7th
chord type (too romantic/jazz-adjacent for this style).

Min7 shell: 0, +3, +10 (A-voicing) or 0, +10, +15 (B-voicing). Use as tonic chord in Dorian
sections (Dm7 is the natural Dorian tonic).

Quartal: 0, +5, +10 (root — fourth — minor seventh). Maximum modal ambiguity; stacking fourths
produces a floating, unresolved sound. Use sparingly — one event per section at most.

**Voice leading between chords:**

- Common tone rule: pitch classes shared by both chords stay in place (same MIDI pitch)
- Minimal motion rule: other voices move by smallest available interval (prefer 1–2 semitones)
- Use inversions: choose the voicing of the new chord whose notes are nearest the current voicing
- Avoid parallel fifths and octaves: move in contrary motion or hold one voice while the other moves

**Voicing probability summary (per 16-bar section):**

- Plain major/minor open spread: 70% | Sus2: 15% | Add9: 8% | Dom7/Min7: 5% | Sus4 (with
  resolution): 2% | Quartal: occasional (up to 1 event per section)

**Before emitting a voicing as MIDI events:**

- Confirm no note below MIDI 48
- Confirm no two adjacent notes less than 3 semitones apart below MIDI 60; if so, remove or
  move the lower of the two
- Confirm all voicing notes are in the active chord window (chordTones + scaleTensions only)
- If a voicing note is an avoidTone on a strong beat, remap to nearest chordTone

### Execution parameters

**Velocity profiles (0–127):**

- Drums: kick 104–122, snare 96–118, hat/cymbal 72–104; accent pulse every 2–4 bars +6 to +10
- Bass: 78–108; phrase-start accents +5 to +8
- Rhythm: 70–100 with light up/down alternation
- Lead 1: 76–108 with motif peak note +8 max
- Lead 2: 64–96 (lower foreground than Lead 1)

**Note length defaults:**

- Drums: one-shot/staccato
- Bass: mostly 8th-note gate; occasional held note at phrase boundary
- Rhythm: short gate (35–60% of step length)
- Pads: long sustain (70–100% of harmonic window)
- Lead 1: mixed short/medium; avoid continuous legato runs
- Lead 2: shorter than Lead 1 by default
- Texture: long tails / sparse one-shots

**Polyphony caps:**

- Lead 1: max 2 simultaneous | Lead 2: max 1 | Pads: max 4-note voicings
- Rhythm: max 2-note dyad | Bass: monophonic | Texture: max 2 concurrent

**Groove/swing microtiming:** swing amount 50–52% (nearly straight). Per-event drift: drums ±6ms,
bass ±8ms, rhythm ±7ms, leads ±10ms.

---

## Tonal Consistency Rules (MOT-SYNC)

These are structural invariants, not probabilistic firing rules. They hold for every song and every note. For the study findings and bug history that produced them, see `musical-coherence-plan.md` (Motorik Studies 01–02).

**MOT-SYNC-001: Scale pools anchor to song tonic**
All note-pool derivations use `keySemitone(frame.key)` as root. When chord roots are non-tonic (e.g. bVII in a Dorian song), generators stay in the global key. The flat7 in bass patterns is snapped to the nearest in-scale pitch class. LD2-004 Hallogallo Counter and LD2-005 Descending Line use the song tonic as their reference pitch — they are fixed tonic-anchored motifs and must not shift when chord roots change.

**MOT-SYNC-002: Chord root selection is mode-aware**
`pickChordRoot` uses a mode-specific degree list. Aeolian: `[1,2,b3,4,5,b6,b7]`. Dorian: `[1,2,b3,4,5,6,b7]` (raised 6th, no b6). Ionian: `[1,2,3,4,5,6,7]`. Mixolydian: `[1,2,3,4,5,6,b7]`. Using a hardcoded Aeolian list for all modes introduces non-diatonic chord roots that cause system-wide consonance failures.

**MOT-SYNC-003: NotePoolBuilder receives frame.mode**
`buildChordWindows` passes `frame.mode` (not `section.mode`) to both `pickChordRoot` and `NotePoolBuilder.build`. Section mode for A sections is hardcoded Dorian and must not be used as the scale reference.

**MOT-SYNC-004: Pad voicing snapped to scale**
After applying chord-type interval offsets, each voiced note's pitch class is snapped to the nearest diatonic PC. Chord type offsets (e.g. dom7, min7) can land on chromatic pitches that are not in the key; the snap corrects this without removing the note from the voicing.

**MOT-SYNC-005: Lead role separation**
Lead 2 receives the Lead 1 event array before generating. When Lead 1 picks a sparse rule (LD1-003 Long Breath) for the A section, the B section escalates to an active melodic rule (LD1-001 or LD1-004). Lead 2 note share should stay below 60% of total lead notes.

**Consonance targets** (verified via MIDI batch analysis — see musical-coherence-plan.md):
- Bass: > 92%
- Pads and Rhythm: > 85%
- Leads: > 80%
- Drum fill rate: < 1 fill per 8 bars

---

## Title Generator

New title on each Generate; unchanged on per-track regen. Seed-deterministic. 1–3 words. Short,
pulse-oriented, slightly cryptic. English + Germanic mix.

**Generation patterns (weighted):**

- `Place + Motion` 22% | `Texture + Motion` 20% | `Name + Motion` 14% | `MusicWord + Motion` 14%
- `Adj + Noun` 12% | `Three-word cinematic` 10% | `Phonetic parody blend` 8%

**Word banks:**

- Place/scene: Koln, Dusseldorf, Berlin, Ruhr, Autobahn, Tunnel, Nordhausen, Detroit, Forest,
  Flughafen, Ausgang, Ausfahrt, Strasse, See, Fluss
- Motion/energy: Drive, Pulse, Drift, Flow, Run, Loop, Roll, Counter, Motor, Velocity, Nonstop,
  Speed, Fast, Schnell, Tempo, Geschwindigkeit, Exit
- Texture/tone: Chrome, Static, Neon, Halo, Tape, Glass, Metal, Buzz, Klang, Kosmiche,
  Elektronischer, Light, Dark, Licht, Dunkel, Night, Moon, Sun, Stars, Zen, Zeitgeist
- Music-structure: Chord, Pattern, Sequence, Ostinato, Motif, Echo, Signal, Flux, Phase
- Musician names: Klaus, Dinger, Michael, Rother, Thomas, Hans, Roedelius, Dieter, Moebius,
  Ralf, Hutter, Florian, Schneider, Karl, Bartos, Wolfgang, Flur
- Album/track-derived (rearranged): Hallo, Immer, Neu, Deluxe, Monza, Hollywood, Express,
  Europe, Endlos, Dynamik, Weiter, Zentrale, Zignal
- Approved numerics: 1977, '85, No. 7, Part 1, Part 2

**Post-processing:**

- Avoid exact known song titles; require at least one token change/reorder
- Avoid repeating same first token in consecutive titles
- Prefer hard consonants and short vowels for one-word titles

**Examples:** Mittelwerk Pulse, Detroit Driftline, Neon Nordhausen, Klaus in Tunnel, Rother Flux,
Von Braun Drive, Flur Motor, Panzinger Echo
