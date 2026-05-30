# Kosmic Drift — Research & Implementation Plan
Copyright (c) 2026 Zack Urlocker

## Naming

The sub-style is called **Kosmic Drift**. "Drift" communicates the slower, floating quality without being a descriptor (like "downtempo") that could apply to anything. At 75 BPM the sequencer doesn't drive — it drifts. The name stays inside the Kosmic family.

---

## Musical Identity

Base Kosmic is JMJ / Tangerine Dream territory: sequencer-driven, melodic lead, cosmic and propulsive. Kosmic Drift keeps the sequencer and melodic lead entirely intact but drops the tempo to 70–90 BPM, allowing the sequencer ostinato to breathe rather than drive. A slow loping drum groove replaces Kosmic's sparse or absent rhythm — not a breakbeat in the hip-hop sense, more of a slow organic pulse that frames the sequencer without competing with it.

The sequencer is still the heartbeat. The groove is what gives it weight.

---

## Reference Artists

### Carbon Based Lifeforms — *Hydroponic Garden* (2003) *(cold end of the palette)*

The clearest model for the sequencer feel at downtempo pace. CBL are explicit inheritors of the Berlin School — TD-influenced pad textures, warm melodic leads, slow evolving sequencer patterns.

- **"Epicentre"** — rich layered sequencer textures, slow pulse, pads underneath; models the relationship between sequencer and pad bed
- **"MOS 6581"** — named after the SID chip, explicitly sequencer-driven, warm detuned lead; closest to the existing Kosmic bass sequencer character but slower
- **"Silent Running"** — sequencer with gentle groove; demonstrates the drum/sequencer balance
- **"Neuronics"** — long-form, sequencer builds slowly; good structural model

### Boards of Canada — sequencer-forward tracks only *(strange/nostalgic middle)*

BoC spans a wide range from ambient to sequencer-driven. Focus only on tracks where the sequencer is clearly present.

- **"Roygbiv"** (*Music Has the Right to Children*, 1998) — short melodic sequencer loop with loping rhythm; compact and clear
- **"Music Is Math"** (*Geogaddi*, 2002) — arpeggio sequencer front and centre, slow pulse; slightly darker character
- **"Gyroscope"** (*Geogaddi*) — hypnotic sequencer pattern, more repetitive and meditative
- **"Peacock Tail"** (*The Campfire Headphase*, 2005) — sequencer driving the whole track, warm and melodic; strong groove underneath without overpowering the sequencer
- **"Satellite Anthem Icarus"** (*The Campfire Headphase*) — slow sequencer with loping groove; probably the best single BoC track for this substyle

### Tycho — *Dive* (2011), *Awake* (2014) *(warm end of the palette)*

Tycho (Scott Hansen) brings a warmer, more melodic register than CBL or BoC — post-rock influenced lead lines, polished drum sound, sunnier emotional palette. Only instrumental tracks apply.

- **"Past Is Prologue"** (*Dive*) — **primary Tycho reference**. A clearly audible repeating sequencer-like bass/chord pattern locked underneath while the melodic lead floats freely above it; groove builds from sparse to full across the track's length. The locked-sequencer-plus-improvising-lead relationship is exactly the Kosmic engine at downtempo pace.
- **"A Walk"** (*Dive*) — melodic synth/guitar lead over a loping groove, rich pads, ~85 BPM; models the lead/groove relationship at the warmer end of the range
- **"Awake"** (*Awake*) — opens with a sequencer-adjacent synth pattern before the groove enters; good structural model for how to introduce the rhythm gradually
- **"Ascension"** (*Awake*) — groove slightly more prominent; useful for the upper tempo end (~88–90 BPM)

What Tycho adds that CBL and BoC don't: the drum groove sits higher in the mix and is clearly articulated (snare with real presence) without overpowering the melody; the lead has a sustained, singing quality; emotionally the warmest of the three references.

### Air — "La Femme d'Argent" (*Moon Safari*, 1998) *(elegant, cinematic)*

Ten minutes. The sequencer drives the whole song — a slow, locked bass arpeggio cycling under a warm melodic lead. The groove enters gradually and is never aggressive. Everything stays cool and unhurried. Closest European analog to the CBL/Tycho synthesis and a direct personal influence on the Electric Buddha Band's Kosmic work.

### Vangelis and Klaus Schulze — *for tempo and melodic character*

- **Vangelis — *Blade Runner* (1982)**: "Memories of Green", "End Title" — slow synthesizer leads at 70–80 BPM; kosmische character but fully downtempo
- **Klaus Schulze — *Mirage* (1977)**: sequencer present but meditative; bridge between classic Berlin School and the CBL/BoC sound

---

## How It Differs from Base Kosmic

**Tempo**
- Base Kosmic: two BPM modes — Mode A (115–126, 70% of songs) and Mode B (108–118, 30% of songs); both drawn from triangular distributions
- Kosmic Drift: Mode C (70–90 BPM) — a third mode used only for Drift. At this speed the sequencer ostinato feels meditative, not driving. The lower end (70–75) puts it in Vangelis Blade Runner territory; the upper end (88–90) is Tycho and BoC.

**Rhythm (the main new work)**
- Base Kosmic: sparse or absent drums; the sequencer carries the pulse
- Kosmic Drift: a slow loping groove enters — the sequencer is still present but the groove gives it grounding and human weight. The groove is never 4-on-the-floor. Three snare variants (clean, lopsided, floating — see KOS-DRUM-007). Kick doubled at beats 1 and 3 (step 0 + step 2, step 8 + step 10). Hi-hat continuous 8th notes throughout. Full spec in KOS-DRUM-007.

**Sequencer (same rules, different feel)**
- The arpeggio/bass sequencer patterns (KOS-RTHM, KOS-BASS) run unchanged. At 75 BPM they naturally feel slower and more meditative — no new rules required for the sequencer itself.
- Bass hits use a slightly reduced density gate (85% vs. default 95%) to open more breathing room between hits and complement the groove.

**What stays identical**
- Sequencer patterns and the arpeggio engine
- Melodic lead voice (same KOS-LEAD rules, same character)
- Harmonic language (same modal options, adjusted weights — see below)
- Pad texture and voicing rules
- Song structure: intro drone → body → outro

---

## Rule Applicability by Track

### Drums (`kTrackDrums`)

**Applicable in Drift:**
- **KOS-DRUM-007 Loping Groove** (new, 55%) — the primary Drift drum rule; full spec in rule catalog below
- **KOS-DRUM-008 Half-Time Lope** (new, 20%) — snare on beat 3 only (half-time feel); heavier and slower than 007; best at 70–78 BPM; full spec in rule catalog below
- **KOS-DRUM-001 Minimal** (18%) — kick every other bar + quarter hat; calm and unobtrusive
- **KOS-DRUM-003 Absent** (7%) — occasional no-drum sections; CBL uses this

**Excluded from Drift:**
- **KOS-DRUM-004 Electric Buddha Groove** — 8th-note hi-hat grid; too mechanical and busy at 75 BPM; reads as Motorik not organic
- **KOS-DRUM-005 Electric Buddha Pulse** — quarter-note hat with full backbeat; too driving at this tempo
- **KOS-DRUM-006 Electric Buddha Restrained** — still too regular; the ride-dominant feel doesn't fit the loping concept

---

### Bass (`kTrackBass`)

**New Drift-specific bass rules (see rule catalog below):**
- **KOS-BASS-014 Smooth Arpeggio** (new, 20%) — chord-tone cycling (root→3rd→5th→3rd) at quarter-note pace; smooth and continuous; Air / CBL character
- **KOS-BASS-015 Drift Groove** (new, 18%) — root beat 1, fifth on "and-of-2" (step 6), root beat 3; rhythmically shaped to lock with the loping drum; Tycho character
- **KOS-BASS-016 BoC Loop** (new, 10%) — a short 3–4 note melodic cell repeating steadily for 4 bars before a small variation; Boards of Canada character

**Applicable existing rules:**
- **KOS-BASS-001 Drone Root** — two-bar root holds; extremely CBL in character
- **KOS-BASS-004 Moroder Drift** — slow chromatic drift; CBL *Epicentre* and Air *La Femme d'Argent*
- **KOS-BASS-008 Hallogallo Lock** — two notes per bar; elegant and spacious
- **KOS-BASS-002 Root-Fifth Slow Walk** — 8-bar slow cycle; long holds natural at 75 BPM
- **KOS-BASS-009 Crawling Walk** — 2-bar approach pattern; lower velocities built in

**Excluded from Drift:**
- **KOS-BASS-003 Pedal Pulse** — four-on-the-floor quarter notes step on the loping kick; conflicts with groove
- **KOS-BASS-005 Absent** — at 75 BPM the bass must be present to give the groove grounding
- **KOS-BASS-010 Moroder Pulse** — 8th-note ostinato is too busy alongside the loping groove and slower sequencer; the density competes
- **KOS-BASS-011 Kraftwerk Autobahn** — mechanical octave trill and rigid riff; wrong idiom
- **KOS-BASS-012 McCartney PBW** — 8-note rock riff; too rock-inflected
- **KOS-BASS-007 Pulsating Tremolo** — rapid 16th-note tremolo; too frantic at slow BPM; excluded entirely
- **KOS-BASS-006 Dual Layer** — excluded; at 75 BPM the bass already fills space; staccato off-beat layer clutters

**Proposed Drift bass pool weights:**
- KOS-BASS-014 Smooth Arpeggio: 17% *(new)*
- KOS-BASS-015 Drift Groove: 15% *(new)*
- KOS-BASS-001 Drone Root: 14%
- KOS-BASS-004 Moroder Drift: 12%
- KOS-BASS-008 Hallogallo Lock: 10%
- KOS-BASS-016 BoC Loop: 10% *(new)*
- KOS-BASS-017 Four-Bar Hold: 10% *(new — Svefn / Dreamscape)*
- KOS-BASS-013 Loscil Sub-Bass Pulse: 8% *(confirmed fit)*
- KOS-BASS-002 Root-Fifth Walk: 4%

*Note: Moog and Mono Synth are excluded from Drift random selection (user can still pick them manually). Lead Bass, Rock Bass, and Synth Bass 3 form the Drift random pool — Rock Bass and Lead Bass work in the looser groove context at 75 BPM.*

---

### Rhythm / Arpeggio (`kTrackRhythm`)

The sequencer is the whole identity of Kosmic Drift — this track stays fully active. The slower BPM benefits most rules, making them sound more deliberate and meditative.

**Excellent fit for Drift:**
- **KOS-RTHM-009 Craven Faults Phase Drift** — 5-note cell drifting through a 15-bar cycle; organic phasing is very CBL; highest weight
- **KOS-RTHM-003 JMJ Oxygène** — spacious ascending/descending quarter-note legato; the most "floating" arpeggio rule; sounds better here than at 120 BPM
- **KOS-RTHM-002 JMJ Hook** — 4-note melodic hook at 8th/quarter note; at slow BPM this is the Air *La Femme d'Argent* arpeggiated character
- **KOS-RTHM-001 TD Sequencer** — multi-voice 16th-note step sequencer; at 75 BPM the 16th notes feel deliberate, not rushed; CBL *MOS 6581* character
- **KOS-RTHM-007 Pitch-Drifting Sequence** — 4-step quarter-note with slow transposition arc; the name is almost the substyle description
- **KOS-RTHM-008 Oxygène 8-bar Arc** — 5–7 notes spread over 8 bars; extremely spacious at slow BPM
- **KOS-RTHM-010 Craven Faults Modular Grit** — 7-note arch cell with ghost notes; BoC grainy-sequencer character

**Excluded from Drift:**
- **KOS-RTHM-005 JMJ Dual-Rate** — two interleaved voices at different rhythmic rates; with a loping groove already present, the dual-rate density competes rather than floats; excluded
- **KOS-RTHM-004 Electric Buddha Groove** — syncopated 16th-note interlocking voices; designed for the busier Electric Buddha feel; conflicts with the loping groove concept
- **KOS-RTHM-006 Kraftwerk Locked Pulse** — rigid staccato 8th-note cell; mechanical locked quality is anti-Drift

**Proposed Drift arpeggio pool weights:**
- KOS-RTHM-009 Craven Faults Phase Drift: 24%
- KOS-RTHM-003 JMJ Oxygène: 20%
- KOS-RTHM-002 JMJ Hook: 16%
- KOS-RTHM-001 TD Sequencer: 14%
- KOS-RTHM-007 Pitch-Drifting: 12%
- KOS-RTHM-008 Oxygène 8-bar Arc: 8%
- KOS-RTHM-010 Craven Faults Grit: 6%

---

### Lead 1 (`kTrackLead1`)

All rules are applicable in Drift. The slower tempo benefits most of them — long-held notes breathe more, arcs develop more slowly.

**New Drift-specific lead rules (see rule catalog below):**
- **KOS-LD1-010 Tycho Phrase** (new, 22%) — 4–6 note warm singing melody with rise-then-fall arc; stated then slightly varied on repeat; the warmest, most emotionally directed lead in the Drift pool
- **KOS-LD1-011 Drift Memory** (new, 18%) — 3–4 note BoC-style looping cell; pentatonic; flat velocity; slowly evolves every 8 bars; the "half-remembered tune" quality

**Applicable existing rules:**
- **KOS-LEAD-002 Floating Tones** — one note every 2–4 bars; at 75 BPM this has real weight and presence
- **KOS-LEAD-008 Caligari Solo** — 1–2 held notes per bar, slow lyrical; the Drift lead at its most spacious
- **KOS-LEAD-009 Dark Sun Solo** — sustained stepwise ascent/descent; long notes feel profound at 75 BPM
- **KOS-LEAD-003 Pentatonic Drift** — slow pentatonic movement; meditative quality enhanced at slow BPM
- **KOS-LEAD-004 Echo Melody** — question/answer transposition; works in Drift at lower weight
- **KOS-LEAD-001 Slow Arc** — 2–4 note phrase; fine but less characteristic; low weight

**Excluded from Drift:**
- **KOS-LEAD-005 Arpeggio Highlight** — picks one note from the arpeggio and holds it; too mechanical and locked to the sequencer; doesn't feel like a lead
- **KOS-LEAD-006 JMJ Phrase Loop** — looping phrase serves same purpose as KOS-LD1-011 Drift Memory but with a colder, more formal JMJ character that doesn't fit the warmer Drift palette; KOS-LD1-011 supersedes it in Drift
- **KOS-LEAD-007 TD Skip Sequence** — ascending rhythmic skip pattern; too mechanical and Berlin-School-angular; the most "base Kosmic" of the lead rules; excludes cleanly

**Proposed Drift lead pool weights:**
- KOS-LD1-010 Tycho Phrase: 20% *(new)*
- KOS-LD1-011 Drift Memory: 17% *(new)*
- KOS-LD1-012 Svefn Float: 10% *(new — Dreamscape / most atmospheric)*
- KOS-LEAD-002 Floating Tones: 13%
- KOS-LEAD-008 Caligari Solo: 13%
- KOS-LEAD-009 Dark Sun Solo: 11%
- KOS-LEAD-003 Pentatonic Drift: 9%
- KOS-LEAD-004 Echo Melody: 5%
- KOS-LEAD-001 Slow Arc: 2%

---

### Lead 2 (`kTrackLead2`)

**Track presence:**
- Base Kosmic: present in most songs as a sparse counter-melody
- **Drift: always silent.** The loping groove plus sequencer plus Lead 1 is already a full texture. A second melody voice at slow BPM clutters rather than enriches. The track is suppressed unconditionally — no rules fire, no events generated. This matches the Motorik Noir precedent where Lead 2 is always logged as `"MOT-LD2-000"` and skipped entirely.

---

### Pads (`kTrackPads`)

**Track presence:**
- Base Kosmic: variable
- **Drift: present in 90%+ of songs** — the slower tempo creates more harmonic space; pads are more important in Drift than in driving base Kosmic

**All rules applicable. Nuances:**
- **KOS-PADS-001 Eno Long Drone** — 2–4 bar whole-note holds; bedrock of the CBL sound; high weight
- **KOS-PADS-003 Steve Roach Unsync Layers** — three voices at different loop lengths; CBL *Epicentre* uses this approach explicitly; high weight
- **KOS-PADS-004 Suspended Resolution** — sus4→minor every 4 bars; gentle periodicity; good fit
- **KOS-PADS-007 Gated Chord Pulse** — per-beat re-attacks; reduce probability in Drift or gate to Absent-drum sections only; rhythmic re-attacks can fight with the loping groove

---

### Texture (`kTrackTexture`)

**Track presence:**
- Base Kosmic: B-section emphasis for KOS-TEXT-001
- **Drift: present throughout, not just B-sections** — at slow BPM the texture is part of the harmonic depth, not just a B-section intensifier

**All rules applicable. Nuances:**
- **KOS-TEXT-001 Orbital Motive** — lower-register phasing loop; use throughout body, not gated to B-sections only
- **KOS-TEXT-004 Loscil Drip** — deep aquatic shimmer; the most specifically CBL texture; ideal for Drift
- **KOS-TEXT-003 Spatial Sweep** — chromatic passing notes; use at lower probability than base (chromatic movement can feel too active at slow BPM)

---

## Instrument Pools

All Kosmic instruments are visible to the user in the picker regardless of substyle. The pools below describe what Zudio selects *randomly* — the user can always manually override to any instrument in the shared pool.

### What Changes (by track)

**Drums** *(combined pool: 808 Kit, Machine Kit, Standard Kit, Brush Kit, Jazz Kit)*
- **Drift random picks**: Standard Kit, Brush Kit, Jazz Kit — evenly weighted
- **Regular Kosmic only**: 808 Kit (electronic, CBL/BoC), Machine Kit (cold/rigid, wrong for loping feel)
- **Brush Kit (GM 40)** — brushed snare and light cymbals; warm organic loping feel; Tycho drum character; Drift-only
- **Jazz Kit (GM 32)** — loose, organic; warm alternative to Brush; Drift-only
- **Standard Kit** — shared; works for the fuller Tycho warmth

Drift drum random picks: Standard Kit, Brush Kit, Jazz Kit

---

**Bass** *(combined pool: Moog, Lead Bass, Mono Synth, Rock Bass, Synth Bass 3)*
- **Drift random picks**: Lead Bass, Rock Bass, Synth Bass 3 — evenly weighted
- **Excluded from Drift random**: Moog (available manually), Mono Synth (available manually)

All five instruments remain visible in the UI; the random restriction keeps the dominant Moog character out of auto-generated Drift songs.

---

**Rhythm / Arpeggio** *(combined pool: Moog, Wurlitzer, Rock Organ, Harpsi Pad, New Age Pad, Synth Mallet, Synth Chime, Mystery Pad)*
- **Drift random picks**: Moog, New Age Pad, Synth Mallet, Synth Chime, Mystery Pad
- **Regular Kosmic only**: Wurlitzer (Chill-adjacent), Rock Organ (too churchy), Harpsi Pad (too plucked/percussive)
- **New Age Pad (GM 88)** — soft airy sequencer sound; better than Rock Organ for BoC/Tycho warmth; Drift-only
- **Synth Mallet (GM 1098)**, **Synth Chime (GM 11098)**, **Mystery Pad (GM 11096)** — custom bank pads; Drift-only atmospheric arpeggiators
- Warm Pad was considered as a Rhythm instrument but removed — already present in Lead 1 and Pads; too many overlapping uses

Drift rhythm random picks: Moog, New Age Pad, Synth Mallet, Synth Chime, Mystery Pad

*Note: New Age Pad has slow attack. When paired with fast-arpeggiation rules (KOS-RTHM-001, 16th-note steps), individual notes blur into a sustained wash — a CBL "pad that pulses" texture. This may be intentional; monitor during testing.*

---

**Lead 1** *(combined pool: Flute, Brightness, Oboe, Recorder, Warm Pad, Sine Wave, Bottle Blow, Shenai)*
- **Drift random picks**: Warm Pad, Sine Wave, Bottle Blow, Shenai — evenly weighted
- **Regular Kosmic only**: Flute (also Ambient Lead 1), Brightness (also Ambient Lead 1), Oboe, Recorder
- **Warm Pad (GM 89)** — pad-like lead that barely surfaces above the texture; most atmospheric option; CBL character; Drift-only
- **Sine Wave (GM 8080)** — clean pure tone; floats without timbre distraction; Drift-only
- **Bottle Blow (GM 76)** — breathy, organic; Drift-only
- **Shenai (GM 111)** — reedy, exotic quality; Drift-only
- Square Lead (GM 80) was in the initial Drift pool but removed — too similar to Motorik Noir's signature character

Drift Lead 1 random picks: Warm Pad, Sine Wave, Bottle Blow, Shenai

---

**Lead 2** — **always silent in Drift.** No instrument pool needed. The loping groove + sequencer + Lead 1 is a full texture at 70–90 BPM; a second melody voice clutters rather than enriches. Implementation: `if isKosmicDrift { lead2Rules.insert("KOS-LD2-000"); return [] }`, log `"KOS-LD2-000"`. Same pattern as Motorik Noir.

---

**Pads** *(combined pool: Sweep Pad, Synth Strings, Warm Pad, Space Voice, Halo Pad, Bowed Glass)*
- **Drift random picks**: Sweep Pad, Synth Strings, Warm Pad, Halo Pad, Bowed Glass (Space Voice excluded from Drift random)
- **Added to both Regular and Drift**: Halo Pad (GM 94) — airy, ethereal shimmer; Bowed Glass (GM 92) — glassy, resonant
- **Space Voice** — available manually; excluded from Drift random picks (too Ambient-adjacent)

All six instruments are visible to the user.

---

**Texture** *(combined pool: Pad 3 Poly, Fifths Lead, Solar Wind, FX Echoes, Rain)*
- **Drift random picks**: all five
- **Regular Kosmic random picks**: Pad 3 Poly, Fifths Lead, Solar Wind, FX Echoes (Rain excluded)
- **Removed**: FX Atmosphere (GM 99) — present in Motorik Texture, Ambient Texture, and Ambient Lead 2; not unique enough for Kosmic
- **Added**: Solar Wind (GM 11089) — custom bank; also in Motorik Texture; adds motion and depth
- **Added**: FX Echoes (GM 102) — also in Motorik Texture; no-repeat instrument (won't appear in consecutive songs)
- **Rain (GM 96)** — Drift-only; ambient shimmer; excluded from Regular Kosmic random

Drift texture random picks: Pad 3 Poly, Fifths Lead, Solar Wind, FX Echoes, Rain

---

### Quick Reference: Drift-only vs. Base-only (random selection)

**Drift-only random instruments (excluded from Regular Kosmic random selection):**
- Brush Kit, Jazz Kit (Drums)
- Warm Pad, Sine Wave, Bottle Blow, Shenai (Lead 1)
- New Age Pad, Synth Mallet, Synth Chime, Mystery Pad (Rhythm)
- Rain (Texture)

**Regular Kosmic only (excluded from Drift random selection):**
- 808 Kit, Machine Kit (Drums)
- Moog, Mono Synth — excluded from Drift random (manual pick allowed) (Bass)
- Wurlitzer, Rock Organ, Harpsi Pad (Rhythm)
- Flute, Brightness, Oboe, Recorder (Lead 1)
- Space Voice — excluded from Drift random (manual pick allowed) (Pads)

**Lead 2 track: always silent in Drift — no instrument pool**

---

## Scales, Keys, and Modes

### Modes

Base Kosmic distribution: Dorian 45%, Aeolian 32%, Mixolydian 15%, Ionian 8%

**Drift adjustments:**
- **Dorian: 50%** (up from 45%) — Dorian's raised 6th gives warmth; CBL *Hydroponic Garden* and Tycho both favour Dorian or warm-minor modal centers; this is the primary Drift mode
- **Mixolydian: 20%** (up from 15%) — the flat-7 creates a floating, unresolved quality without darkness; Tycho's warmer songs feel Mixolydian; Air *La Femme d'Argent* has this open, major-adjacent quality
- **Aeolian: 22%** (down from 32%) — pure natural minor is valid but Dorian is warmer and more characteristic of the Drift references; reduce
- **Ionian: 8%** — keep as is; occasional brightness valid; Tycho has some major-key material
- **Phrygian: 0%** — exclude entirely from Drift. Phrygian's flat-2 creates a tense, Spanish/mysterious quality that fits base Kosmic but is wrong for CBL/Tycho warmth; not characteristic of any Drift reference artist

### Progression Families

Base Kosmic: static_drone 30%, two_chord_pendulum 25%, modal_drift 20%, suspended_resolution 15%, quartal_stack 10%

**Drift adjustments:**
- **static_drone: 35%** (up from 30%) — the locked harmonic center over a repeating sequencer is the defining quality of all Drift references; CBL *Epicentre* is essentially this
- **two_chord_pendulum: 30%** (up from 25%) — Air *La Femme d'Argent* is a two-chord pendulum; Tycho uses this constantly; raise significantly
- **modal_drift: 20%** — keep; slow stepwise harmonic movement works at this tempo
- **suspended_resolution: 12%** (down from 15%) — sus chords add gentle tension; slight reduction
- **quartal_stack: 3%** (down from 10%) — stacked fourths feel abstract and angular; least characteristic of CBL/Tycho/Air; retain only rarely

### Keys

The existing base Kosmic key weighting (minor-heavy, Am/Em/Dm most common) is appropriate for Drift. No fundamental changes. Notes for reference:
- A minor / A Dorian: CBL *Hydroponic Garden* tends toward A modal centers
- D minor / D Dorian: very CBL and JMJ (Oxygène is D minor); high weight
- G minor / G Dorian: Tycho uses warmer flat key centers
- E minor: BoC uses E minor and E Dorian frequently

---

## Drift Rule Catalog

All rules below are Kosmic Drift only. They do not appear in the base Kosmic pool.

---

### Drum Rules

**KOS-DRUM-007 "Loping Groove"**
The primary Drift groove. MIDI analysis of Roygbiv and Aquarius revised the pattern significantly from the original spec.

**Kick:** step 0 (beat 1) + step 2 (8th after beat 1), step 8 (beat 3) + step 10 (8th after beat 3). Velocity 88–98. The doubled-kick at beats 1 and 3 — each beat immediately followed by an 8th-note ghost kick — creates the loping forward-lean. Not a syncopated "and-of-3" pattern.

**Snare — three variants (choose once per song):**
- *Clean* (40%): step 4 (beat 2) and step 12 (beat 4) only. On the beat. Roygbiv pattern — grounded, most readable.
- *Lopsided* (40%): step 4 (beat 2), step 7 (three 16ths after beat 2), step 12 (beat 4), step 15 (last 16th of bar). Aquarius pattern — the double snare creates the stumbling, behind-the-beat lope. More distinctively BoC.
- *Floating* (20%): snare NOT on the conventional backbeat (not steps 4 or 12). Instead: step 0 (beat 1), step 6 (and-of-2), step 8 (beat 3). The listener's ear cannot find a down-beat anchor — the groove becomes suspended and dreamlike. Sigur Rós "Svefn-g-englar" pattern. Most appropriate at the lower BPM end (70–78) and for the most meditative Drift songs. Pairs with KOS-BASS-017 (Four-Bar Hold).

**Hi-hat:** pedal hi-hat continuous 8th notes across all steps (0, 2, 4, 6, 8, 10, 12, 14). Velocity 88–98 flat. Not sparse quarters — the continuous pedal hat is what all analysed songs actually use. Closed hi-hat (42) layered at quarter-note positions (steps 0, 4, 8, 12) at 40% probability for additional texture. For the Floating snare variant, ride cymbal (51) may substitute for pedal hat — Svefn uses continuous ride 8th notes in the same role.

**Velocity:** all drum hits locked to base velocity 88–96 ± 4 random wobble. Zero dynamic shaping. Flat velocity is confirmed universal across Roygbiv, Aquarius, and Svefn-g-englar.

**Fills:** 30% of songs using this rule have any fills at all. When fills do appear: section-transition, 1 beat maximum, no Bonham descents. The Floating snare variant has fills in 10% of songs maximum — the unanchored groove makes fills feel intrusive.

**No fills variant:** 70% of KOS-DRUM-007 songs play the pattern identically bar-to-bar for the full song duration. Roygbiv does this exactly: bars 9–48 are an unchanged pattern.

*Reference: Boards of Canada "Roygbiv" (clean), "Aquarius" (lopsided), Sigur Rós "Svefn-g-englar" (floating)*

---

**KOS-DRUM-008 "Half-Time Lope"**
An even slower, heavier groove for the 70–78 BPM range of Drift. The snare falls on beat 3 only (step 8) — a half-time feel that makes the bar feel twice as long and the groove twice as heavy. No snare on beat 2 or 4.

- Kick: beat 1 (step 0, vel 90–100); optional second kick at step 6 ("and-of-2", vel 70–80, 40% of bars) — pushes forward just before the half-bar
- Snare: step 8 (beat 3, vel 82–92) — the only backbeat; lands hard after two full beats of kick-only groove
- Ghost snare: step 6 or step 10 (vel 22–34, 30% of bars) — just before or just after the snare hit
- Hi-hats: beat 1 and beat 3 only (steps 0 and 8, 55% probability); no continuous hat grid — the open space is essential to the half-time feel
- Open hi-hat: step 14 (25% of bars, vel 50–65) — the pre-downbeat "breathe"
- Fills: section-transition only, 1 beat maximum; even sparser than 007

*Reference: CBL slow sections, early Portishead-adjacent feel; most appropriate when BPM ≤ 78*

---

### Bass Rules

**KOS-BASS-014 "Smooth Arpeggio"**
A continuous chord-tone cycling bass in the Air / CBL tradition. The pattern moves smoothly through root → 3rd → 5th → 3rd in four quarter-note steps, filling the bar with a melodic, legato motion rather than a rhythmic pulse. The cycle sounds like the bass arpeggiating the chord — it implies harmonic colour (the 3rd) without breaking from the root.

- Pattern: step 0 = root, step 4 = 3rd, step 8 = 5th, step 12 = 3rd; each note duration 4 steps (quarter note), creating smooth overlap when the sequencer re-attacks
- 3rd: mode-aware — minor 3rd in Aeolian/Dorian, major 3rd in Mixolydian/Ionian
- Register: MIDI 38–55; slightly lower floor than standard Kosmic bass for warmth
- Velocity: 75–88, nearly flat — the smoothness is the character, not the accent
- Variation (B sections / variation windows): insert b7 between 5th and returning 3rd (root → 3rd → 5th → b7 → 3rd); the b7 adds Dorian/jazz colour without breaking the smooth cycle
- Blocks dual-layer (KOS-BASS-006) and pulsating-layer (KOS-BASS-007) — they would interrupt the legato flow

*Reference: Air "La Femme d'Argent" bass arpeggio; CBL "Epicentre" cycling bass; the melodic bass that you follow as a voice rather than feel as a rhythm*

---

**KOS-BASS-015 "Drift Groove"**
A rhythmically shaped bass that locks with KOS-DRUM-007 Loping Groove. Where Hallogallo Lock places notes on beats 1 and 3 (every 4 steps), Drift Groove places notes on beat 1, the "and-of-2" (step 6 — where the ghost kick often lands), and beat 3, creating a bass that feels like part of the groove rather than just a harmonic anchor.

- Step 0: root, vel 90–98, dur 4 (beat 1 anchor)
- Step 6: fifth, vel 72–82, dur 3 ("and-of-2" syncopation — the defining off-beat hit)
- Step 8: root, vel 84–92, dur 4 (beat 3 re-anchor)
- Step 13: fifth, vel 62–72, dur 3 (optional, 55% of bars — light preparation for the next bar's beat 1)
- The step-6 fifth is the character of this rule; it aligns with the syncopated kick and snare-lag position to create a pocket
- Register: MIDI 40–55
- Variation (B sections): step 6 can substitute a b7 or 4th (50/50) for colour; step 13 probability increases to 75%

*Reference: Tycho "Past Is Prologue" bass rhythm — a locked melodic-rhythmic pattern that grooves*

---

**KOS-BASS-016 "BoC Loop"**
A short repeating melodic cell in the Boards of Canada tradition. BoC bass lines are often simple loops — 3–4 notes repeating identically for several bars before a small change. The repetition is not monotony; it is the whole point. The loop creates the hypnotic quality.

- Cell construction (chosen once per song): root → mode-2nd → root → 5th (4 notes, one per beat)
  - In Dorian: e.g. G → A → G → D — the 2nd gives a lifted, nostalgic quality
  - The 5th on beat 4 is a mild cadential marker that lands just before the next bar's root
- Each note: duration 4 steps (quarter note), velocity 85–95, relatively flat
- The cell repeats identically for 4 bars
- Bar 5 onward: **fresh 30% roll every 4-bar cycle** — one note in the cell may shift, either the 2nd → 3rd (one step warmer) or the 5th → 4th (one step more suspended). The shift holds for the next 4 bars, then a new roll determines whether it shifts again or reverts. Cell can drift gradually or stay static depending on how rolls land.
- Variation (B sections): add a passing 4th or b3 as a 5th event on step 14 (one 16th before the bar end) as a brief approach note into the next bar's root
- Register: MIDI 40–55
- Blocks dual-layer (KOS-BASS-006) — the rhythmic regularity doesn't need additional staccato layer

*Reference: Boards of Canada "Roygbiv" and "Gyroscope" bass loops; simple, slightly woozy repeating figures*

---

**KOS-BASS-017 "Four-Bar Hold"**
The most spacious bass rule in the Drift pool. The bass sustains the chord root for an entire 4-bar phrase (16 beats) without movement, then changes to follow the next chord. No syncopation, no ornament, no approach notes — just the held root creating a tonal floor beneath everything else. The harmonic rhythm of the song is defined entirely by the chord changes, not by the bass moving within bars.

Confirmed by Sigur Rós "Svefn-g-englar": every bass note lasts 4–6 beats at a time, with chord roots following the rhythm guitar at the same 4-bar change rate.

- Note placement: step 0 only, once per bar (or once per chord change = once per 4 bars)
- Duration: 16 beats (4 full bars) — the bass note is held for the entire chord zone
- Velocity: base ± 4, completely flat
- Register: MIDI 28–48 — low and warm; the note should be felt as much as heard
- Mode-aware root selection: reads from the **tonal governance map** (same as all other bass rules). At each 4-bar boundary, takes the chord root from the current governance entry and holds it for 4 bars. No special logic needed — just the standard chord root, held longer.
- No passing notes, no 5th, no variation. Simplicity is the rule.
- Pairs with: KOS-DRUM-007 Floating snare variant and KOS-PADS-001 Eno Long Drone. The three together produce the Svefn-g-englar timbral bed.
- Pairs poorly with: KOS-BASS-015 (Drift Groove) — the syncopated groove bass conflicts with this rule's stillness. Use one or the other.

*Reference: Sigur Rós "Svefn-g-englar" bass — root held across entire chord zones; Radiohead "How To Disappear Completely" Ondes Martenot sustained tones*

---

### Lead 1 Rules

**KOS-LD1-010 "Tycho Phrase"**
A warm, melodic phrase with a clear emotional arc — the most directed and "composed-feeling" of the Drift lead rules. Unlike the floating or drifting rules that place notes independently, Tycho Phrase builds a 4–6 note phrase with internal shape: it rises toward a peak note, then descends. The phrase is stated once, then repeated with one note changed — the Tycho practice of slight variation over direct repetition.

- **Phrase construction** (chosen once per song; restated every 10–14 bars):
  - Opening note: root or 3rd (step 0 of the phrase window, vel 48–58)
  - Rise: 2–3 stepwise or small-leap notes ascending toward the 5th, 6th, or 7th (vel swell, peaking at 68–78)
  - Peak: the highest note, held 12–20 steps (3–5 beats) — the emotional goal of the phrase; on a chord tone (5th or 7th)
  - Descent: 1–2 notes stepping back down toward root or 3rd; shorter durations (4–8 steps each)
  - Total notes: 4–6; total phrase length: 6–9 bars
- **Velocity arc**: rise → swell → fall mirrors the pitch arc; each note's velocity tracks the contour (quieter at the bottom, louder at the peak, quieter again on descent)
- **Repeat with variation**: after a silence of 8–12 bars, the phrase reappears with one note changed. Selection: a random note from the phrase shifts ±1 diatonic step (50/50 up or down). The changed note is re-selected each repetition independently — different note may change each time. Velocity arc and register unchanged.
- **Register**: MIDI 60–80 — warm, not thin
- **Phrase spacing**: 10–14 bars of silence between phrases; pads and sequencer fill the silence

*Reference: Tycho "Past Is Prologue" melodic lead; "A Walk" — the rising, breathing quality of the melodic line over the locked sequencer*

---

**KOS-LD1-011 "Drift Memory"**
A short looping cell in the BoC lead tradition. Roygbiv MIDI confirms the approach: the exact same 10-note phrase (ascending triplet figure × 3 → held peak note) repeats identically 8 times across 48 bars, appearing every 4th bar and silent for the other 3. No evolution, no variation — the repetition is the point. The Olson MIDI confirms pentatonic pitch content and octave doubling.

- **Cell construction** (chosen once per song):
  - 3–5 notes from the pentatonic subset of the song's mode: root, 2nd, 3rd, 5th, or 6th (b7 and 4th excluded for floating quality)
  - Roygbiv cell: quick ascending run (scale degrees 1→2→3, 16th-note duration each) × 3 repetitions, landing on a held 4th (2–3 beats). Simple, asymmetric, hypnotic.
  - Start on the 3rd or 5th — beginning off the tonic gives the unmoored, floating quality
  - Cell cycle length: 1 bar (16 steps) or 2 bars (32 steps)
- **Velocity**: locked to base value ± 4 random wobble. Roygbiv: velocity 89 on every note of every repetition. No shaped arc whatsoever. This flat velocity IS the BoC lo-fi quality.
- **Appearance pattern**: every 4th bar starting from the lead's **entry bar** (appears at entry bar, entry+4, entry+8, etc.). Silent the other 3 bars. No continuous looping — the silences are part of the character. The grid is anchored to the lead's first appearance, not to the song start.
- **Evolution — two variants** (choose at song generation):
  - *Static* (60%): cell is identical every appearance for the full song. Roygbiv does this. More hypnotic.
  - *Drifting* (40%): one note shifts by a diatonic step every 8–12 bars. More varied, BoC "Music Is Math" character.
- **Register**: MIDI 60–78 — pentatonic range, compact
- **Octave doubling option** (40%): confirmed by Olson — notes appear simultaneously one octave apart (e.g. D#4 + D#5). Adds body without harmonic colour. Applicable when the lead instrument is Flute, Square Lead, or Brightness.
- **Long absence**: the cell disappears entirely for 8–16 bars at the structural midpoint (the bridge equivalent). Roygbiv: silent bars 25–35. Re-enters unchanged.

*Reference: Boards of Canada "Roygbiv" (static cell, triplet figure); "Olson" (pentatonic, octave doubling, drumless context)*

---

**KOS-LD1-012 "Svefn Float"**
The most sparse and atmospheric lead rule in the Drift pool. A single note or two-note phrase floats above the texture — not a cell, not a melodic arc, just an occasional tone that surfaces and dissolves. Inspired by the vocal line of Sigur Rós "Svefn-g-englar", where the lead enters far into the song and offers single held tones that barely disturb the harmonic fabric.

- **Entry**: very late — not before bar 20, and often bar 30–50. The texture must be fully established before the lead appears. This is the defining constraint of the rule. No other rule delays the lead this long.
- **Phrase character**: 1–3 notes per phrase. A single note held 4–8 beats is the primary gesture. Occasionally a step up or down followed by another long hold. No melodic arc, no rise-and-fall shape — just a note that exists, sustains, and disappears.
- **Pitch selection**: mode-aware chord tones only — root, 3rd, 5th, or 7th of the current chord. Never chromatic, never pentatonic scale running. **Never repeat the previous appearance's pitch** — always choose a different chord tone. Track the previous pitch and exclude it from the selection. With 4 chord tones available and 1 excluded, each appearance draws from the remaining 3.
- **Spacing**: phrase appears every 8–16 bars. Between appearances: complete silence on Lead 1. The rests are as structural as the notes.
- **Velocity**: locked flat (base ± 3). No accent, no swell.
- **Duration**: 4–12 beats per note. Long notes that decay into the reverb tail.
- **Register**: MIDI 60–80 — mid-range, warm. Never thin or high.
- **Instrument**: Warm Pad (GM 89) as lead is ideal — the slow attack of the pad means the note fades in rather than striking, reinforcing the floating quality. Flute or Brightness also work.
- **Pairs with**: KOS-DRUM-007 Floating snare variant, KOS-BASS-017 Four-Bar Hold, KOS-PADS-001 Eno Long Drone. These four together produce the full Svefn dreamscape.
- **Appearance rate for the full song**: 5–8 notes total across the entire song is typical. Not a melody — a presence.

*Reference: Sigur Rós "Svefn-g-englar" vocal line; Radiohead "How To Disappear Completely" Ondes Martenot drift tones. Both use single sustained notes separated by long silences as the primary lead gesture.*

---

### Quick Reference: What's New vs. Excluded

**Drift-only rules (do not appear in base Kosmic):**
- KOS-DRUM-007 Loping Groove (three snare variants: clean / lopsided / floating)
- KOS-DRUM-008 Half-Time Lope
- KOS-BASS-014 Smooth Arpeggio
- KOS-BASS-015 Drift Groove
- KOS-BASS-016 BoC Loop
- KOS-BASS-017 Four-Bar Hold *(new — Svefn-g-englar)*
- KOS-LD1-010 Tycho Phrase
- KOS-LD1-011 Drift Memory
- KOS-LD1-012 Svefn Float *(new — most sparse, very late entry)*

**Excluded from Drift (base Kosmic only):**
- KOS-DRUM-004 Electric Buddha Groove
- KOS-DRUM-005 Electric Buddha Pulse
- KOS-DRUM-006 Electric Buddha Restrained
- KOS-BASS-003 Pedal Pulse
- KOS-BASS-005 Absent
- KOS-BASS-010 Moroder Pulse
- KOS-BASS-011 Kraftwerk Autobahn
- KOS-BASS-012 McCartney PBW
- KOS-BASS-006 Dual Layer (additive)
- KOS-BASS-007 Pulsating Tremolo (additive)
- KOS-RTHM-004 Electric Buddha Groove
- KOS-RTHM-005 JMJ Dual-Rate (dual-voice density conflicts with loping groove)
- KOS-RTHM-006 Kraftwerk Locked Pulse
- KOS-LEAD-005 Arpeggio Highlight
- KOS-LEAD-006 JMJ Phrase Loop
- KOS-LEAD-007 TD Skip Sequence
- Lead 2 track — always silent

---

## Song Structure

The intro drone builds from near-silence; the body develops the sequencer + groove relationship; the outro dissolves — same as base Kosmic. Bar count is lower at 75 BPM (~3.2s/bar vs ~2.0s), so a standard-length song runs 56–94 bars. Song duration in seconds stays the same; no generator changes needed.

### Dreamscape variant (~10% of Drift songs)

A distinct long-form structure inspired by Sigur Rós "Svefn-g-englar" (9 min, 261 bars at 116 BPM) and Radiohead "How To Disappear Completely" (78 BPM, 5.8 min). Applies only when all three of the following are selected: KOS-DRUM-007 Floating snare, KOS-BASS-017 Four-Bar Hold, and KOS-LD1-012 Svefn Float.

- **BPM**: lower end of Drift range only — 70–80 BPM. At 75 BPM the 4-bar chord holds last 12.8 seconds each, creating the suspended harmonic time.
- **Intro**: 20–28 bars before drums enter (longer than standard 8–16 bar Drift intro). Pads and bass only. The length is the point.
- **Drums enter**: bar 20–28 — without fills, without drama, just the pattern beginning.
- **Lead enters**: bar 40–60 — the lead's late arrival is the structural event of the song. Nothing precedes it except a long zone of pure texture.
- **Form**: `single_evolving` only. No formal A/B sections. The song moves by gradual addition and subtraction, never by sectional contrast.
- **Song length**: 300–540 seconds (5–9 minutes). Standard Drift song lengths are too short for this structure to breathe properly.
- **Chord change rate**: every 4 bars — the pads, bass, and sequencer all follow this harmonic rhythm. Nothing moves faster than 4 bars harmonically.
- **Sequencer (Rhythm track)**: KOS-RTHM-003 JMJ Oxygène or KOS-RTHM-008 Oxygène 8-bar Arc preferred — the most spacious arpeggio rules. KOS-RTHM-001 (dense 16th-note sequencer) excluded from this variant; it is too busy for the harmonic stasis.
- **Key**: Dorian or Aeolian strongly preferred. E Dorian (Svefn), D Dorian, and A Aeolian are the most natural modal centers for this texture.

### Form weights

The reference artists (CBL, BoC) favour continuous single-form evolution over sectional structures. Tycho and Air are the only references that use clear A/B sections. Drift weights accordingly:

- `single_evolving` — **40%** (up from base Kosmic). The CBL and BoC default. No formal sections; the texture evolves continuously. Bridges, when present, are embedded density shifts rather than contrasting sections.
- `ab` — **25%**. Tycho and Air territory. A clean A zone followed by a B zone with different density or tonal centre; no return to A.
- `aba` — **15%** (down from base Kosmic). Valid but less characteristic of the references.
- `abab` — **15%**. BoC's loose cyclic repetition feel — two zones, two passes, gradual variation each time.
- `abba` — **5%**. Rare.

### Bridges

Bridges appear in **30–35% of Drift songs** — less often than base Kosmic, consistent with CBL and BoC almost never using formal bridges. When a bridge occurs it should feel earned: the texture needs 40+ bars to establish itself before the break lands with weight.

**Bridge length: 12–16 bars.** At 75 BPM a 12-bar bridge is ~38 seconds — substantial and spacious. Base Kosmic's shorter bridges feel rushed at this tempo.

**Bridge types (priority order):**

- **Harmonic Dissolution** *(primary)*. Sequencer stops. Pads sustain and blur toward harmonic ambiguity for 12–16 bars. Lead is silent. The sequencer re-enters in a new key at the end. The bridge IS the silence — the most ambient-native bridge type and the most Drift-appropriate.
- **Modulation + Thinned Groove** *(secondary)*. Groove continues but strips to kick-only (snare and hats drop). Sequencer density thins. Pads slide to the new key over 4 bars, then the full groove re-enters in the new key. Preserves rhythmic continuity during the harmonic shift — the Tycho approach.
- **Solo Breath** *(tertiary)*. Everything drops except Lead 1 and a held root pad. The lead plays unaccompanied for 8–12 bars. No key change; the drama is density, not harmony. Groove and sequencer re-enter in the original key.
- **Textural Fade** *(fourth)*. Gradual volume reduction to near-silence over the bridge span. Reverb tails only. Sequencer and groove re-enter from silence in the original key. Used in `single_evolving` songs as the structural division point.
- **Bass Exit** *(fifth, BoC-specific)*. Bass drops entirely for 8, 12, or 16 bars while the groove, pads, and horn/lead continue unchanged in the original key. The simplest bridge: one element leaves silently, everything else continues. No harmonic change, no tempo change. Confirmed by Roygbiv MIDI (bass absent bars 25–32). Most appropriate for BoC-style songs using KOS-BASS-016 and KOS-DRUM-007.
- **Ascending / Melodic bridge** *(low weight)*. Base Kosmic bridge types remain available at low residual probability for Tycho-adjacent songs.

**Modulation intervals.** When a bridge changes key, the shift is ±3 semitones (minor 3rd — subtle lift or deepening, ambient-native) or +5 semitones (perfect 4th — stronger sense of opening up). The transition uses the pad sustain as a hinge: pads hold a chord that functions in both keys, the sequencer silences for 1–2 bars, then re-enters in the new key. Whole-step or perfect-5th modulations are excluded — too obvious or too cinematic for the Drift register.

No bridge may use the excluded drum rules (KOS-DRUM-004/005/006). Bridges that thin the groove must use KOS-DRUM-001 Minimal or silence only.

---

## KOS-DRUM-007 Implementation Notes

The authoritative pattern spec is in the Drift Rule Catalog above. This section adds implementation guidance only.

The primary new implementation work for Kosmic Drift is KOS-DRUM-007. All other changes are parametric (BPM mode, pool weights, gate probability).

- **Zone-based density**: in intro, outro, and stripped-bar zones — drop CHat (42) entirely; thin PHat (44) to quarter-note positions only (steps 0, 4, 8, 12). Full groove (all 8th-note PHat positions + CHat layer) resumes in body sections. Same zone mechanism used by all existing Kosmic drum rules. `frame.intensity` is not used.
- **Snare variant selection**: chosen once at song generation time from the three variants (clean 40% / lopsided 40% / floating 20%). Not varied bar-to-bar.
- **Kick ghost note**: step 2 and step 10 kicks are lighter than step 0 and step 8 (vel ≈ 70% of primary kick velocity).
- **KOS-DRUM-008 weight**: flat pool regardless of tempo — 007 29%, 008 24%, absent 25%, minimal 22%. Tempo-dependent redistribution was considered but not implemented; the flat pool was simpler and adequate.

---

## Triggering

Same mechanism as `isChillBlues`, `isAmbientPiano`, `isMotorkNoir`:

```swift
// In CosmicMusicalFrameGenerator.generate()
let isKosmicDrift = rng.nextDouble() < 0.15   // ~15% of Kosmic songs

// If isKosmicDrift: use BPM Mode C
let driftTempo: Int? = isKosmicDrift
    ? (70 + rng.nextInt(upperBound: 21))   // 70–90
    : nil
```

When `isKosmicDrift` is true:
- BPM drawn from Mode C (70–90); Mode A / Mode B bimodal split does not apply
- **Flat velocity base**: draw once per song from 85–92; all BoC-style rules (KOS-DRUM-007, KOS-BASS-016, KOS-LD1-011, KOS-LD1-012) use this base ± 4. Other rules use their own velocity logic.
- Mode weights: Dorian 50%, Mixolydian 20%, Aeolian 22%, Ionian 8%, Phrygian 0%
- Progression family weights: static_drone 35%, two_chord_pendulum 30%, modal_drift 20%, suspended_resolution 12%, quartal_stack 3%
- Drum generator selects from Drift pool: KOS-DRUM-007 55%, KOS-DRUM-008 20%, KOS-DRUM-001 18%, KOS-DRUM-003 7% — KOS-DRUM-008 is BPM ≤ 78 only; its eligibility is gated at the frame generator level (same mechanism as `pickPercussionStyle`), not inside the drum generator
- Drum instrument pool: Brush Kit (primary), Standard Kit, 808 Kit; Machine Kit excluded
- Bass pool: KOS-BASS-001/002/004/008/009 plus new rules 013/014/015/016/017; KOS-BASS-010/011/012 excluded; KOS-BASS-007 (pulsating tremolo) excluded; Lead Bass excluded
- KOS-BASS-006 (Dual Layer): excluded from Drift generally — staccato off-beats clutter the spacious feel. **Exception**: when KOS-BASS-008 (Hallogallo Lock) is the primary rule, KOS-BASS-006 fires as its required additive layer (KOS-BASS-008 sounds thin without it per generator code).
- KOS-BASS-013 (Loscil Sub-Bass Pulse): included in Drift at low weight (~8%). Sub-bass register MIDI 28–43, doublet beat-1 pulse, low velocity (48–62), "underwater pumping" feel. Confirmed by Zack as a likely fit. Listen and adjust weight after first implementation.
- Bass density gate: **85% gate applied per-rule** — not uniform. Each bass rule should implement its own gate appropriate to its character. Looping cells (016) gate per bar; arpeggios (014) gate per note; held roots (017) do not gate at all — the hold IS the character.
- Pads present in **95%** of Drift songs (5% skip)
- KOS-PADS-007 (Gated Chord Pulse): fires **only when KOS-DRUM-003 (Absent drums) is active**. Rhythmic re-attacks conflict with the loping groove; allowed in drum-free songs where there is no groove to fight.
- Arpeggio pool: KOS-RTHM-001/002/003/007/008/009/010 only; KOS-RTHM-004/005/006 excluded; KOS-RTHM-001 excluded from Dreamscape variant
- Lead 2: always silent — `if isKosmicDrift { return [] }` at top of `generateLead2()`, log `"KOS-LD2-000"`
- Texture present throughout body (not B-section gated)
- Instrument pools: use Drift-specific pools per track (see Instrument Pools above)

### Dreamscape variant triggering (~10% of Drift songs)

When `isKosmicDrift` is true, draw a second flag:

```swift
let isDriftDreamscape = rng.nextDouble() < 0.10
```

When `isDriftDreamscape` is true, force:
- BPM: drawn from lower end only (70 + rng.nextInt(upperBound: 11)) — 70–80 BPM
- Drum rule: KOS-DRUM-007 with **Floating snare variant** forced
- Bass rule: KOS-BASS-017 (Four-Bar Hold) forced
- Lead 1 rule: KOS-LD1-012 (Svefn Float) forced
- Arpeggio: KOS-RTHM-001 (dense 16th-note sequencer) excluded; prefer KOS-RTHM-003 or KOS-RTHM-008
- Form: `single_evolving` only
- Intro length: 20–28 bars before drums (not the standard 8–16)
- Pad presence: forced (no skip)
- Variation within Dreamscape rules: each of the three forced rules should still draw their internal variation (e.g. KOS-DRUM-007 Floating still varies its kick ghost hits; KOS-BASS-017 still follows chord changes; KOS-LD1-012 still selects different pitch and timing per appearance). The flag forces the rule *type*, not a single fixed performance.
- Display name: `"Kosmic Drift"` — no separate Dreamscape label shown to user

---

## Display Name

```swift
var displayStyleName: String {
    if isKosmicDrift       { return "Kosmic Drift" }
    if isAmbientPiano      { return "Ambient Piano" }
    if chillBluesVariation { return "Chill Blues" }
    if isMotorkNoir        { return "Motorik Noir" }
    return style.rawValue.capitalized
}
```

---

## Implementation Files

Changes are localized to:

- **CosmicMusicalFrameGenerator.swift** — `isKosmicDrift` flag draw + `isDriftDreamscape` flag draw, BPM Mode C, Drift-specific mode and progression weights; Dreamscape forces BPM 70–80 and specific rules
- **CosmicDrumGenerator.swift** — KOS-DRUM-007 Loping Groove rule; Drift-specific drum pool weights
- **CosmicBassGenerator.swift** — Drift-specific bass pool weights; KOS-BASS-006/007 probability gating
- **CosmicArpeggioGenerator.swift** — Drift-specific arpeggio pool weights (exclude RTHM-004/006)
- **CosmicLeadGenerator.swift** — Lead 2 unconditionally suppressed when `isKosmicDrift` (no events generated; rule log: `"KOS-LD2-000"`)
- **CosmicPadsGenerator.swift** — Drift presence gate (90%+); KOS-PADS-007 reduced probability
- **CosmicTextureGenerator.swift** — KOS-TEXT-001 fires throughout body (not B-section gated) in Drift
- **SongState.swift** — add `isKosmicDrift: Bool` stored property (default false); update `displayStyleName`; update all `withXxx()` copy methods to pass the field explicitly
- **SongGenerator.swift** — pass `isKosmicDrift` to `generateKosmic()` and all sub-generators; update generation log
- **AppState.swift** — add Drift-specific instrument name and program arrays per track (`instrumentPoolNames`, `instrumentPoolPrograms`); select Drift pool when `songState.isKosmicDrift`

No new generator files required.

---

## Codebase Integration

### SongState.swift

```swift
let isKosmicDrift: Bool        // default false
let isDriftDreamscape: Bool    // default false; only true when isKosmicDrift is also true
```

Update `displayStyleName` as above. Update all `withXxx()` copy methods to pass both fields explicitly — every field must be passed or it silently defaults.

### CosmicMusicalFrameGenerator.swift

Add `isKosmicDrift` flag draw immediately after `var rng = SeededRNG(seed: seed)`. When active: override BPM draw with Mode C (70–90), override mode weights, override progression family weights, suppress mid-song tempo lift. Return the flag alongside the frame.

### CosmicDrumGenerator.swift

Add new static function:

```swift
static func generateLopingGroove(
    frame: GlobalMusicalFrame,
    totalBars: Int,
    rng: inout SeededRNG
) -> [MIDIEvent]
```

Dispatched when `isKosmicDrift && drumRule == "KOS-DRUM-007"`. Builds kick / snare / hat streams per bar using section label and zone-based density modulation (same mechanism as existing Kosmic drum rules: stripped-bar zones, intro/outro thinning). Does not use `frame.intensity` — that field is not referenced by any Kosmic drum rule. Rule log: `"KOS-DRUM-007"`.

### AppState.swift — Instrument pools (as implemented)

All Kosmic instruments are stored in a single combined pool visible to the user. `instrumentPickPool()` restricts random selection by substyle. Current pools:

- **Drums** (combined): `["808 Kit","Machine Kit","Standard Kit","Brush Kit","Jazz Kit"]` / `[25,24,0,40,32]`
  - Drift random: indices [2,3,4] = Standard Kit, Brush Kit, Jazz Kit
  - Regular random: indices [0,1,2] = 808 Kit, Machine Kit, Standard Kit
- **Bass** (combined): `["Moog","Lead Bass","Mono Synth","Rock Bass","Synth Bass 3"]` / `[39,87,81,34,8038]`
  - Drift random: indices [1,3,4] = Lead Bass, Rock Bass, Synth Bass 3
  - Regular random: all indices
- **Rhythm** (combined): `["Moog","Wurlitzer","Rock Organ","Harpsi Pad","New Age Pad","Synth Mallet","Synth Chime","Mystery Pad"]` / `[39,5,18,11088,88,1098,11098,11096]`
  - Drift random: indices [0,4,5,6,7] = Moog + four Drift-only instruments
  - Regular random: indices [0,1,2,3]
- **Lead 1** (combined): `["Flute","Brightness","Oboe","Recorder","Warm Pad","Sine Wave","Bottle Blow","Shenai"]` / `[73,100,68,74,89,8080,76,111]`
  - Drift random: indices [4,5,6,7]
  - Regular random: indices [0,1,2,3]
- **Lead 2**: always silent in Drift
- **Pads** (combined): `["Sweep Pad","Synth Strings","Warm Pad","Space Voice","Halo Pad","Bowed Glass"]` / `[95,50,89,91,94,92]`
  - Drift random: indices [0,1,2,4,5] (Space Voice excluded)
  - Regular random: all indices
- **Texture** (combined): `["Pad 3 Poly","Fifths Lead","Solar Wind","FX Echoes","Rain"]` / `[90,86,11089,102,96]`
  - Drift random: all indices (Rain included)
  - Regular random: indices [0,1,2,3] (Rain excluded)

---

## Risk Assessment

**Low risk overall.** The main additions:

- KOS-DRUM-007 and KOS-DRUM-008 are new drum rules (CosmicDrumGenerator)
- KOS-BASS-014, 015, 016 are new bass rules (CosmicBassGenerator)
- KOS-LD1-010 and 011 are new lead rules (CosmicLeadGenerator); both require cross-bar phrase state, but this is a solved problem — KOS-LEAD-006 (JMJ Phrase Loop) already uses the same pattern (phrase generated once per section, repeated with per-bar variation across the section) and is the direct implementation template
- Pool weight adjustments are table changes in existing switch/array structures
- Instrument pool switching uses the same pattern already in AppState for other per-state instrument variations
- Mode and progression weight overrides are simple float substitutions in `CosmicMusicalFrameGenerator`
- Lead 2 suppression is unconditional — one `if isKosmicDrift { return [] }` guard at the top of `generateLead2()`

The main musical unknowns: (1) does the loping groove sit right with the existing sequencer patterns at 75 BPM? (2) is step 5 the right snare position or should it be step 4? Both need a listening test after first implementation. See Open Issues below.

---

## MIDI Analysis Findings

MIDI files analysed: BoC Roygbiv (83 BPM, 48 bars), BoC Aquarius (84 BPM, 124 bars), BoC Olson (110 BPM, 40 bars), Portishead Wandering Star (80 BPM, 97 bars), Portishead Roads (75 BPM, 96 bars), Sigur Rós Svefn-g-englar (116 BPM MIDI = ~58 BPM felt, 261 bars, 9 min), Radiohead How To Disappear Completely (78 BPM, 113 bars). Tycho Awake (176 BPM half-time, distortion guitars) and Mogwai Fear Satan (110 BPM, post-rock) were analysed but discarded as not representative of Drift.

### Which songs are representative of Drift

- **Roygbiv** — primary model. 83 BPM, E Dorian, looping bass cell, repeating lead cell, loping drums. All rule specs derived from this song are validated.
- **Aquarius** — representative of the sound and long-form structure. Same 84 BPM, flat velocity throughout. Good model for extended texture drops (guitar absent 56 bars). Drum pattern is more complex (see below).
- **Olson** — outlier on **tempo** (110 BPM, outside the 70–90 Drift range) but valuable as the drumless archetype. 4 simultaneous pad layers, pentatonic lead, short form, piano closing section. Not a tempo reference.
- **Tycho Awake** — outlier on **instruments and idiom**. All distortion guitar, post-rock character. 176 BPM with cut-time feel. Usable for structural layering patterns (bass enters bar 9, second layer enters bar 29) but the sound is completely wrong for Drift. Not a sound reference.

### Universal finding: flat velocity is the BoC/Tycho signature

Every note in every track across all 4 songs is velocity 89 — exactly flat. Lead, bass, drums, pads, piano, guitar. Not near-flat: exactly flat with no dynamic shaping. This is the defining characteristic of the drum-machine lo-fi quality these artists produce. All BoC-style rules (KOS-DRUM-007, KOS-BASS-016, KOS-LD1-011) must use locked base velocity ± 4–6 random wobble. No shaped arcs.

### Drum findings from Roygbiv + Aquarius

Two distinct loping groove patterns at the same 83–84 BPM:

**Roygbiv (clean):** Kick at steps 0, 2, 8, 10 (doubled kick at beats 1 and 3). Snare on beat 2 (step 4) and beat 4 (step 12) exactly. Continuous 8th-note pedal hat. Pattern identical bars 9–48: zero variation.

**Aquarius (lopsided):** Kick adds step 5 (e-of-2) and step 14 (last 16th). Snare at steps 4, 7, 12, 15 — the step-7 snare (three 16ths after beat 2) is what creates the stumbling, behind-the-beat lope. This is the more distinctively BoC of the two patterns.

These are now the two variants of KOS-DRUM-007 (see rule spec above).

Tycho Awake at 88 BPM half-time: snare on step 8 only (beat 3) — pure half-time feel, one backbeat per bar. Confirms KOS-DRUM-008 (Half-Time Lope) is on the right track.

### Bass findings from Roygbiv

The 4-bar looping cell (KOS-BASS-016) confirmed. Actual cell from Roygbiv:
- Bar 1 (F# root): busy — held note + syncopated 16th ornaments at steps 7–10 + return at step 12
- Bar 2 (A root): 3 notes — A2 held 1.5b, E3 on **step 6** (the and-of-2 syncopation from KOS-BASS-015), D2 at step 8
- Bar 3 (A root variant): similar with different ornament
- Bar 4 (B root): single note held for the entire bar (4 beats) — maximum space

Harmonic cycle: ii → IV → IV → V without ever touching the tonic. The deliberately unresolved cycle is characteristic. The single held bar (bar 4) is essential to the spacious feel.

### Lead findings from Roygbiv and Olson

**Roygbiv:** Identical 10-note phrase repeated 8 times across the song with zero variation (see KOS-LD1-011 revision). Appears every 4th bar (bars 12, 16, 20, 24), then absent 11 bars (bars 25–35), then returns (36, 40, 44, 48). Lead enters at bar 12 — never appears in the first 11 bars.

**Olson:** Pentatonic lead confirmed (5 pitch classes only: C#, D#, F#, G#, A# — pure pentatonic). Lead plays in octave pairs (D#4+D#5, F#4+F#5 simultaneously). Mean note duration 2.7 beats — very long held notes. Enters at bar 8.

### Structure findings across all songs

Every song builds in layers; nothing starts with the full texture:

- All songs: solo instrumental texture for 4–16 bars before anything else enters (BoC: 8 bars, Portishead Wandering Star: 16 bars)
- Bass / drums enter around bar 8–16 in all songs with those elements
- Lead always enters late: bar 8 (Olson), bar 12 (Roygbiv), bar 17 (Wandering Star melody)
- The "bridge" in all analysed songs is a **texture drop** (one element leaves) rather than a key change

**New bridge type confirmed: Bass Exit.** In Roygbiv: bass absent bars 25–32 (8 bars) while drums, piano, and horn continue. This is simpler than Harmonic Dissolution and more idiomatic: the bass drops silently while the groove continues unchanged. No key change, no tempo change. Bridge length: 8, 12, or 16 bars.

**Drumless song archetype (from Olson):** Pads from bar 1 in 4 layers → lead enters bar 8 → sustained for body → piano takes over for final 8 bars as pads and lead drop. No drums throughout. Supports KOS-DRUM-003 (Absent) at 15–20% of all Drift songs (not just absent-in-one-section).

### Plan amendments from MIDI analysis

- **KOS-DRUM-007**: snare position revised to two variants (step 4 clean / steps 4+7 lopsided); kick revised to doubled-beat pattern (0,2,8,10); hat revised to continuous 8th notes; fills made optional (70% of songs have none)
- **KOS-LD1-011**: static variant (no evolution) added at 60%; octave doubling added at 40%; appearance rhythm confirmed as 4-bar grid; long mid-song absence confirmed
- **Velocity**: flat velocity (base ± 4–6) must be explicit in every BoC-style rule implementation
- **Intro length**: bass-only or instrument-only intro of **8–16 bars** before drums enter; lead enters 4–8 bars after drums. Confirmed across BoC (8 bars), Portishead Wandering Star (16 bars), Portishead Roads (16 bars synth-only before drums).
- **New minimal bass option**: quarter-note root pulse — single note, chord root only, steps 0/4/8/12, duration 1 beat, flat velocity. No syncopation, no movement, no ornament. Confirmed by Portishead Wandering Star (B1/F#2/B2 on every beat for the full song). Simpler than KOS-BASS-016 and more meditative; works at any Drift tempo. Should be added to the bass pool as a low-weight option or a sub-variant of KOS-BASS-001 (Drone Root).
- **Drumless Drift songs**: supported at ~15% probability; use 4-layer pads + lead only; no bass track; Olson is the template
- **Bass Exit bridge**: added to bridge type catalog (see Song Structure section); length 8, 12, or 16 bars
- **Open question resolved — snare position**: step 4 (on beat 2) is correct for the clean variant; the behind-the-beat feel in the lopsided variant comes from the *additional* step-7 hit, not from moving the primary snare off the beat

---

## Testing Notes

Listen for:
- **Tempo**: 70–90 BPM should feel meditative, not sluggish. 70 BPM is Vangelis-slow; 88 BPM is BoC-paced. Both should feel intentional.
- **Groove vs. sequencer balance**: the loping groove should give the sequencer weight without competing with it. If the groove is too prominent, reduce kick/snare velocities or increase hi-hat sparsity.
- **Snare variant character**: clean (step 4/12) should feel grounded; lopsided (step 4/7/12/15) should feel slightly stumbling; floating (step 0/6/8) should feel suspended and dreamlike. If lopsided feels too disorienting at a given BPM, fall back to clean.
- **Kick ghost**: step 2 and step 10 secondary kicks should be audible but lighter than the primary. If they dominate, reduce their velocity toward 65% of the primary kick.
- **Mode character**: Dorian and Mixolydian should dominate; verify no Phrygian songs appear.
- **Progression character**: most songs should feel harmonically locked — static drone or simple two-chord pendulum. Avoid quartal songs feeling too abstract.
- **Lead 1 character**: at this tempo lead phrases have more room to breathe; KOS-LEAD-008 and 009 should sound particularly well-suited.
- **Lead 2 presence**: always silent in Drift — verify no Lead 2 events appear in any Drift song.
- **Pad presence**: almost every song should have pads; they should be felt more than noticed.
- **Sequencer instrument palette**: Moog and Wurlitzer are the core; New Age Pad and Warm Pad as sequencer instruments should create a softer, more pad-like arpeggio texture on some songs.
- **Song bar count**: a 240-second Drift song at 75 BPM is ~75 bars — verify section lengths don't feel truncated.

### Reference comparisons

Generate 5 base Kosmic songs, then 5 Kosmic Drift songs. Drift songs should feel:
- Slower and more meditative — not faster or more propulsive
- More grounded (the groove gives the sequencer a floor to sit on)
- Warmer in feel — the slower tempo and warmer instruments naturally soften the sound
- Still unmistakably Kosmic — the sequencer engine is the same

---

## Default Effects — Kosmic Drift vs Regular Kosmic

Three effects are **ON by default** for Kosmic Drift songs and **OFF by default** for regular Kosmic. They appear as blue chips in the Tracks view immediately after generation.

**Bass — Tremolo ON**
A 5 Hz volume tremolo (25% depth) on all Drift bass instruments. The volume oscillates between the track's calibrated base level and 50% of that — a gentle flutter on each note. The tremolo peak is clamped to the track's base volume via `tremBaseVolume` so the effect never raises the bass above its calibrated level. Regular Kosmic bass: Tremolo chip visible but OFF.

**Pads — Sweep ON**
Filter sweep LFO applied to sustained pad chords. The low-pass filter slowly opens and closes, adding tonal movement to what would otherwise be static chord blocks. Especially effective with the new Drift chord rules (Downbeat Chord, Slow Chord Pulse, Four-Bar Chord Hold) where chords are held for multiple beats or bars. CBL Epicentre character — the sweeping pad texture is the defining CBL sound. Regular Kosmic pads: Sweep chip visible but OFF.

**Texture — Pan ON**
Auto-pan LFO at a tempo-aware slow rate: one full left-to-right sweep per 4 bars (`hz = tempo / 960.0`). At 75 BPM this is ~12.8 seconds per sweep — the texture instrument drifts slowly through the stereo field. BoC spatial movement quality. Regular Kosmic texture: Pan chip visible but OFF.

**Implementation**: `AppState.restoreDefaultEffects()` and `TrackRowView.applyDefaultEffects()` both check `songState?.isKosmicDrift == true` in the `.kosmic` case and enable these three effects accordingly. Both copies must be kept in sync whenever effect defaults change.

---

## Polysynth Doubling Layer — Make It More Prominent in Drift

Kosmic has a hidden Lead 1 doubling layer (`kTrackLeadSynth`, track 7): **GM 90 Polysynth**, loaded unconditionally at unity `trackBaseVolume`. It mirrors Lead 1's events exactly but with velocity scaled to **60%** (`* 60 / 100` in SongGenerator.swift line 453). In base Kosmic this sits quietly under the lead. For Drift — where the lead is more spacious and each phrase carries more weight — the doubler could be pushed forward to add warmth and body without needing a new instrument.

**Goal:** make the Polysynth layer more audible in Drift so it thickens the lead voice, CBL/Tycho-style, without competing with it.

**Implementation options (try in order, listen after each):**

- **Raise velocity multiplier** — change `* 60 / 100` to `* 75 / 100` (or higher) in SongGenerator.swift inside the Kosmic generation block. The simplest lever; requires no PlaybackEngine changes. Could be gated with `isKosmicDrift` so base Kosmic is unaffected.
- **Add a trackBaseVolume boost for kTrackLeadSynth in Drift** — in the per-track volume section of `PlaybackEngine.swift` (the large `if/else` chain around line 975), add a branch: `if trackIndex == kTrackLeadSynth && kosmicStyle { vol = 1.3 }` (or similar). This raises the sampler output independently of velocity. Could also be conditioned on `isKosmicDrift` once that flag is plumbed through to PlaybackEngine.
- **Try a different doubling patch for Drift** — GM 90 Polysynth is bright and slightly buzzy. For the warmer Drift palette, alternatives worth testing: **GM 89 Warm Pad** (softer, more diffuse — closer to the CBL pad-as-lead texture), **GM 88 New Age Pad** (airy, slow attack — blends behind the lead rather than doubling it directly). Patch is set via `kDefaultGMPrograms[kTrackLeadSynth]` and the fallback in AppState.swift line 3352 — a Drift-specific override would substitute a different program when `isKosmicDrift` is true.
- **Add reverb to the doubler** — `kTrackLeadSynth` currently shares Lead 1's reverb settings (it uses the same sampler slot routing). A deeper or wetter reverb on the doubler would push it back spatially while keeping it audible — effectively widening the lead sound without adding pitch mass. This requires a dedicated reverb node for the doubler in PlaybackEngine, which is more invasive.

**Starting point for implementation:** raise velocity multiplier to `* 75 / 100` conditioned on `isKosmicDrift`, listen, then adjust from there.

---

## What Is Still Missing (Future Work)

- **Tycho-specific lead variation**: Tycho's leads have a sustained "singing" quality — long held notes with subtle vibrato-like expression and phrase endings that trail off rather than cut. A future KOS-LEAD rule could model this explicitly.
- **Air-style sequencer bass**: "La Femme d'Argent" has a bass arpeggio that is looser and more chord-like than the standard Kosmic sequencer. A variation could allow the sequencer to arpeggiate a fuller chord voicing (root + 3rd + 5th) rather than just root/fifth cycling.
- **Groove-aware bass gating**: the 85% gate is a blunt reduction. A smarter version would gate bass hits on beat positions that complement the kick — lock with kick (step 0), open up on steps 6 and 10 where there is more space.
- **Drift title suffix**: base Kosmic and Motorik Noir have title generation logic. A Drift song title variant — perhaps dropping the multi-word titles toward single evocative words, or adding suffixes like "Drift", "Float", "Current" — could be a small characterful addition.

---

## Open Issues

Items requiring a decision or listening session before implementation begins.

---

### Decisions Required

**KOS-BASS-013 — RESOLVED: include at ~8%.**
Code inspection: "Loscil Sub-Bass Pulse" — sub-bass register MIDI 28–43, doublet beat-1 pulse (primary + quieter repeat 2 steps later), optional beat-3 note (50% chance), low velocity (48–62). Character: deep, underwater pumping. Blocks dual and pulsating layers. Confirmed good fit for Drift by Zack. Include at 8% weight in Drift bass pool. Listen after first implementation and adjust.

**KOS-PADS-007 Gated Chord Pulse — RESOLVED: gate to absent-drums only.**
Fires only when `drumRule == "KOS-DRUM-003"` (KOS-DRUM-003 Absent drums). When a loping groove is present, the rhythmic re-attacks conflict with the groove; when drums are absent, pulsed pads can carry rhythmic structure without conflict.

**Pad presence — RESOLVED: 5% skip (pads in 95% of songs).**

**Bass 85% gate — RESOLVED: per-rule, not uniform.**
Each bass rule handles its own gating:
- KOS-BASS-016 (BoC Loop): gate per bar (85% of bars have bass; 15% go silent — preserves the cell character)
- KOS-BASS-014 (Smooth Arpeggio): gate per note (85% of individual notes fire; creates breathing within the cycle)
- KOS-BASS-017 (Four-Bar Hold): no gate — the 4-bar hold is the whole character; gating would break it
- KOS-BASS-001/013/015: gate per bar at 85%

**KOS-TEXT-001 body-gating — read CosmicTextureGenerator before writing implementation note**
The plan says KOS-TEXT-001 should fire throughout the body, not just B-sections. But the exact current gating mechanism is unverified — CosmicTextureGenerator hasn't been read. Before implementation, read the texture generator to understand how the current B-section gate works, then write a precise note about what changes for Drift.

---

### Listening Research Required

**Snare step position — RESOLVED by MIDI analysis.**
Roygbiv: snare on step 4 (beat 2) and step 12 (beat 4) exactly. Aquarius: snare on steps 4, 7, 12, 15 — the lopsided feel comes from the *additional* step-7 hit, not from moving the primary snare off the beat. KOS-DRUM-007 now specifies two variants (clean / lopsided) with this information baked in. No further listening research needed for this question.

**Air "La Femme d'Argent" bass arpeggio — confirm KOS-BASS-014 interval structure**
KOS-BASS-014 (Smooth Arpeggio) models the bass line of this track as root → 3rd → 5th → 3rd at quarter-note pace with a mode-aware 3rd. Confirm by listening:
- Is the 3rd consistently present, or is it sometimes skipped?
- Is the cycle genuinely 4 quarter notes, or does it sometimes move faster?
- Is the b7 variation (present in the plan's "B-section variation") actually audible in the track or was that inferred?

Getting this wrong affects the primary Air/CBL character of the rule.

**CBL reference track tempos — validate KOS-RTHM-001 at Drift BPM**
KOS-RTHM-001 (TD Sequencer, 16th-note step sequencer) is in the Drift arpeggio pool on the basis that CBL's *MOS 6581* and *Epicentre* use this pattern. Before confirming its inclusion, check the actual BPM of those tracks. If CBL runs them at 80–90 BPM, the 16th-note density is validated for Drift. If they run at 110–120 BPM, a 16th-note sequencer at 75 BPM will feel noticeably slower and more deliberate than the reference — probably still valid, but the plan should say so explicitly.

---

## Reference: Chill Blues as the Model

Chill Blues (V1.4), Motorik Noir (V1.6), and Ambient Piano (V1.5) all establish the same pattern:
- One probabilistic flag at song generation time
- Separate musical constraints (mode, BPM, instrument pool, song length)
- All generators receive the flag as a parameter
- Stored in SongState so per-track regen stays consistent
- `displayStyleName` returns the sub-style name in the UI

Kosmic Drift follows this exact pattern.
