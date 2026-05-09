# Sub-Style Variants — Research & Design Plan
Copyright (c) 2026 Zack Urlocker

## Overview

Chill Blues demonstrated that a musically distinct sub-style surfacing ~20% of the time adds meaningful variety without fragmenting the style identity. It works because it shares the parent style's core engine (same generators, same pipeline) but changes enough musical rules — song structure, harmonic language, instrumentation weight — to feel like a genuinely different idiom.

This document captures three candidate sub-styles, one for each remaining style. Each is designed to appear 10–20% of the time, determined probabilistically at song-generation time (same mechanism as `isChillBlues`).

---

## Sub-Style 1: Motorik Noir

**Parent style:** Motorik
**Reference artists:** Joy Division (*Unknown Pleasures*), Public Image Ltd (*Metal Box*), Wire (*Chairs Missing*), early Stereolab
**Appears:** ~15% of Motorik songs

### Musical identity

Base Motorik is open-road and exhilarating — fast, bright, forward. Motorik Noir keeps the hypnotic motorik pulse but flips the affect completely: claustrophobic, nocturnal, dark. The beat is the same mechanism but the dynamics are pulled inward. Emotionally it maps to Joy Division's relationship to Neu! — same engine, opposite mood.

### How it differs from base Motorik

**Tempo**
- Base Motorik: 140–160 BPM
- Motorik Noir: 110–128 BPM — the groove feels relentless and oppressive rather than fast and exhilarating

**Harmony**
- Strictly minor modes: Aeolian or Phrygian
- Bass riff anchored on a tritone or minor sixth interval — never resolves
- No bright III–VI–VII motion; avoid anything that sounds triumphant
- When a chord change happens it moves by a minor second or tritone, not a fourth

**Instrumentation**
- Bass moves into a high register and becomes the melodic lead (Peter Hook style — prominent, melodic, upper strings)
- Guitar-like lead drops out entirely or plays a single-chord rhythmic texture — not a melody instrument
- Cold, slightly detuned synth pad underneath, often disappearing entirely during the drop section
- Drums: standard motorik kick/snare/hat pattern but stiff — no swing, no fills, quantized to the grid

**Song structure**
- Base Motorik: long hypnotic plateau, 8–12 minutes
- Motorik Noir: distinct tension arc, 4–5 minutes:
  - Intro groove (8 bars)
  - Full texture + bass melody (16–24 bars)
  - Drop to bass + kick only — no other instruments (8 bars, maximum tension)
  - Full rebuild with rising filter on the pad (16 bars)
  - Abrupt end (cut) or 4-bar fade — no resolution

### Key tracks to study

**Public Image Ltd — *Metal Box* / *Second Edition* (1979)**
- "Albatross" — the clearest Motorik Noir blueprint: 10+ minutes, Jah Wobble's bass is the entire melodic content (low, slow, cycling riff), Levene's guitar is pure dissonant texture, drums locked in a stiff groove. No lead melody whatsoever. The "bass-as-only-voice" rule taken to its extreme.
- "Poptones" — hypnotic repeating guitar figure functions as a drone rather than a riff; bass melody over it; minimal change across the full track. Study for how the motorik groove holds tension without ever building toward a release.
- "Careering" — darker and more synthesizer-forward; the bass riff is a two-note pattern over a cold synth wash. Closest to the "cold detuned pad + bass riff" texture described above.
- "Graveyard" — very slow, bass-dominant, oppressive. Models the lower end of the 110–128 BPM range — at this tempo the motorik pulse feels funereal rather than propulsive.

**Public Image Ltd — *Flowers of Romance* (1981)**
- Stripped to percussion and bass in places. Study for the structural logic of the "drop to bass + kick only" section — the album demonstrates how much tension a bass riff carries when all other elements are removed.

**Joy Division — *Unknown Pleasures* (1979)**
- "She's Lost Control," "Disorder," "Shadowplay" — the core references already cited
- "Transmission" — motorik-adjacent groove, slightly faster, useful for studying how the stiff drum pattern anchors an otherwise sparse arrangement
- "Decades" — very slow, sparse, dark; anchors the low-BPM end of the range and shows how the drop into near-silence works emotionally
- "Atmosphere" — demonstrates the abrupt structural ending and the absence of harmonic resolution

**Joy Division — *Closer* (1980)**
- "Twenty Four Hours" — propulsive but claustrophobic; Peter Hook's bass is high and melodic throughout; guitar is rhythmic texture only
- "Atrocity Exhibition" — angular, dissonant, almost industrial; good study for the Phrygian minor harmonic language

**Wire — *Chairs Missing* (1978)**
- "Map Ref. 41°N 93°W" — motorik pulse, concise 3-minute structure; demonstrates that the tension arc can work in a short form
- "I Am the Fly" — angular, rhythmic guitar-as-texture approach

### Implementation notes

Low risk. The drum generator runs at a lower BPM with a stricter grid. Harmonic rules tighten (minor mode only, tritone bass interval). The bass rule changes register. No new instruments required. Generator structure is identical to base Motorik.

---

## Sub-Style 2: Ambient Piano

**Parent style:** Ambient
**Reference artists:** Harold Budd & Brian Eno (*Ambient 2: The Plateaux of Mirror*), Erik Satie (*Gymnopédies*, *Gnossiennes*), Nils Frahm (*Felt*)
**Appears:** ~15% of Ambient songs
**Full plan:** [ambient-piano.md](ambient-piano.md)

### Musical identity

Base Ambient uses co-prime loop phasing — variation emerges mathematically and continuously. Ambient Piano inverts this: a sparse, deliberate piano phrase stated once, allowed to fully decay into silence, then slightly varied and restated. The silence between phrases is structural. Feels composed and fragile rather than machine-generated. Closer to a Satie Gnossienne than to Eno's airport music.

### How it differs from base Ambient

- Single piano voice as the sole melody — no multi-layer loop phasing
- Phrases are placed as deliberate events (3–5 notes each), not tiled loops
- 4–8 bars of near-silence between phrases — the pad drone is the only continuity
- Rhythm, Bass, Texture, Drums all silent
- Pads simplified to a single sustained root + fifth chord throughout
- Heavy reverb on piano (wet/dry ~0.75, decay 4–6 s) — the reverb tail is the body of each note
- Duration: 3–5 minutes, shorter than base Ambient

### Implementation notes

Low risk. New full-song generator rule AMB-PIANO-001 (bypasses loop tiler, like AMB-LEAD-009/010). AMB-PIANO-PAD replaces standard pads rule. `isAmbientPiano` flag suppresses hollow guards. No new instruments needed. See [ambient-piano.md](ambient-piano.md) for full implementation detail.

---

## Sub-Style 3: Kosmische Spiritual

**Parent style:** Kosmic
**Reference artists:** Popol Vuh (*Hosianna Mantra*, *Seligpreisung*), Klaus Schulze (*Irrlicht*), Jon Hassell & Brian Eno (*Fourth World Vol. 1: Possible Musics*)
**Appears:** ~15% of Kosmic songs

### Musical identity

Base Kosmic is driven by a bass sequencer ostinato — the Berlin School engine. Kosmische Spiritual removes this engine entirely and replaces it with devotional stillness. The reference is Popol Vuh's *Hosianna Mantra* (1972): Florian Fricke abandoned synthesizers for acoustic piano, oboe, tambura drone, and voice — glacial, meditative, raga-adjacent. Where Kosmic is propulsive and cosmic, Kosmische Spiritual is inward and devotional.

### How it differs from base Kosmic

**Structure**
- Base Kosmic: sequencer-driven build with melodic improvisation over it, glacial development, rhythm patterns
- Kosmische Spiritual: two-movement arc:
  - Movement 1 — pure drone introduction: tambura-like pad on root + fifth, no rhythm, a wind/oboe-like synth moving very slowly (long held notes, ornaments around a single pitch). 5–8 minutes.
  - Movement 2 — sparse melodic development: lead ornaments around the modal root like a raga *alap*. If rhythm appears at all, it enters briefly in the final third and exits before the end — cymbal pulse or hand drum, no more than once every 4–8 bars.

**Harmony**
- Raga-adjacent: a single scale (Phrygian or Bhairavi equivalent) held throughout the entire piece
- No chord changes
- Melodic interest comes from ornaments and micro-inflections around the root and dominant — not from harmonic motion
- Continuous drone on root + fifth throughout

**Instrumentation**
- Lead: wind or oboe-like synth timbre (replaces the standard synth lead)
- Optional secondary voice: piano or Rhodes, single notes with very long decay — no chords
- Pad: tambura-style drone, root + fifth, constant throughout
- Bass: absent or minimal pedal note — no sequencer motion
- Drums: very sparse (cymbal, hand drum equivalent), optional, late-appearing only

**What is removed from base Kosmic**
- Driving bass sequencer — entirely absent
- Melodic arpeggios
- Active rhythm patterns in the first two-thirds
- Synth density and layering

### Key tracks to study

**Popol Vuh — *Hosianna Mantra* (1972)**
- "Kyrie" — acoustic piano + oboe + tambura drone; the entire harmonic content is a single sustained root pedal with a slowly orbiting melody; no chord changes across the track's full duration
- "Hosianna" — voice enters over piano and drone; demonstrates how a second melodic voice (here vocal, in Zudio an oboe-like synth) can weave around the lead without competing

**Popol Vuh — *Seligpreisung* (1973)**
- 30-minute continuous piece; atavistic grand piano, sparse drums entering very late and then leaving again; the clearest structural model for the two-movement arc (long drone intro → brief rhythmic arrival → dissolution)

**Popol Vuh — *Einsjäger & Siebenjäger* (1974)**
- "Ah! Die ewige Frage" — piano + cymbals opening a 19-minute suite before fuller sound arrives; guitar solos appear as meditative and ornamental, not as a lead voice

**Popol Vuh — *Aguirre* (1975)**
- Werner Herzog film soundtrack; some of the most purely devotional material in the catalog; the wind-timbre synth lead is the closest existing reference to the oboe-like voice described in the instrumentation plan

**Klaus Schulze — *Irrlicht* (1972)**
- "Ebene" — pre-sequencer Schulze; broken organ drones, processed orchestral samples, no ostinato pattern at all; demonstrates that the Berlin School identity survives without the sequencer if the drone logic is strong enough

**Tangerine Dream — *Zeit* (1972)**
- Four sides of pure drone; cello quartets, organ, and early synthesizers with no pulse; the earliest Berlin School record and the one that most directly prefigures Kosmische Spiritual; study for how harmonic stasis creates its own forward motion

**Jon Hassell & Brian Eno — *Fourth World Vol. 1: Possible Musics* (1980)**
- "Charm" — raga-inflected trumpet processed into near-synth timbres over an ambient groove with Indian-adjacent rhythm patterns; the best existing example of how to apply the "ornament around the modal root" rule to an electronic context

**Dark Kosmic key tracks**
- Klaus Schulze — *Timewind* (1975), side 2 "Wahnfried 1883": sequencer present but very slow and ominous; Phrygian-adjacent mode; good tempo and mood target for Dark Kosmic
- Steve Roach — *Structures from Silence* (1984), "Quiet Friend": sequencer-driven but meditative rather than propulsive; demonstrates the slow-tempo sequencer at 65–75 BPM
- Tangerine Dream — *Phaedra* (1974): sequencer returns but in a darker, more dissonant context than the later JMJ-influenced material; useful for the timbre target (sawtooth leads, minor mode)

### Implementation notes

Medium risk. Removing the sequencer bass means the primary engine that drives Kosmic energy is absent. Careful tuning is needed to ensure the result is identifiably "Kosmic family" rather than sounding like base Ambient. The wind-timbre lead voice is the distinguishing marker. If implementation proves difficult, the fallback sub-style below is lower risk.

### Alternative: Dark Kosmic

A safer Kosmic sub-style that keeps the sequencer engine intact:

- Same bass sequencer and rhythm patterns as base Kosmic
- Slower tempo: 65–80 BPM
- Strictly dark modes: Phrygian or Locrian
- Sawtooth lead voice, darker timbre, more ominous tone
- Reduced harmonic motion — fewer chord changes, longer dwells
- References: Steve Roach *Structures from Silence*, Klaus Schulze *Timewind* side 2

Dark Kosmic is straightforward to implement (tempo + mode + lead timbre adjustment only) and produces a clearly distinct mood from the current JMJ / Tangerine Dream palette without architectural changes.

### Kosmic Substyle Candidates: Genre Analysis

Three other electronic genres were evaluated as potential Kosmic substyles: downtempo, house, and techno. Summary findings:

**Downtempo — strongest candidate after Kosmische Spiritual / Dark Kosmic**

Reference artists: Massive Attack, Boards of Canada, Amon Tobin, Portishead. Tempo 70–100 BPM — overlaps almost exactly with Kosmic's contemplative Mode B (88–105). Same emotional register as Kosmic: introspective, atmospheric, not a dancefloor style. The distinguishing feature is the **hip-hop breakbeat** replacing Kosmic's sparse or absent drums — slow, loping, slightly swung snare on the 2-and, ghost hits, off-beat bass hits. Harmonic and pad infrastructure is nearly identical to existing Kosmic generators; only the drum rule and bass syncopation pattern would need new work. Implementation cost is low: one new drum rule type and a bass variation, everything else reuses existing generators. Most coherent tonal fit with Zudio's overall palette.

**House — not recommended**

Defined by 4-on-the-floor kick (every quarter note) plus offbeat hi-hats and soulful chord stabs. Energy register is dancefloor, not contemplative — a significant departure from Zudio's atmospheric character. Tempo (120–130 BPM) overlaps with Kosmic's upper range, which would cause genre confusion in the style selector. Requires a new drum pattern, new bass groove style, and chord-stab pattern; implementation cost is moderate. The fundamental mismatch in emotional register makes it a poor fit for the app as currently positioned.

**Techno — not recommended**

Tempo 130–150 BPM — entirely above Kosmic's ceiling of 126; would require a separate BPM zone and is effectively a fifth standalone style, not a substyle. Even darker and more minimal than house; more repetitive and rhythm-driven. Competes directly with Motorik for the "driving rhythmic electronic" territory. Implementation cost is high (separate generator infrastructure). Pass.

**Conclusion:** Downtempo is worth adding to the Kosmic substyle roadmap after Kosmische Spiritual and Dark Kosmic. It is distinct, recognizable (Boards of Canada fans would identify it immediately), and low-effort to build on the existing Kosmic infrastructure.

---

## Implementation Priority

- **Motorik Noir** — highest priority. Most distinct emotional impact, lowest implementation risk. Same generator structure, different tempo + harmony + register rules. No new instruments needed.
- **Ambient Piano** — second priority. Genuinely different from loop-phasing Ambient, elegant to implement, already has the right instruments (piano, Wurlitzer).
- **Kosmische Spiritual or Dark Kosmic** — third. Kosmische Spiritual is the more interesting musical statement; Dark Kosmic is the safer build. Decision should be made when the Kosmic generator is being extended.

---

## Reference: Chill Blues as the Model

Chill Blues (V1.4) established the sub-style pattern:

- Triggered by `isChillBlues` flag set probabilistically in `ChillMusicalFrameGenerator` (~20% of Chill songs)
- Different song form: 16-bar blues (I–IV–V) vs. Chill's verse/chorus/bridge/breakdown
- Different instrument mix: warm horns and reeds (tenor sax, clarinet, muted trumpet), brushed drums
- Different bass rule: blues walking bass with B-section variation
- Different lead phrasing: blues-scale inflections, turnaround licks across the 16-bar form
- Effects change: delay removed from lead voices for drier, more authentic tone
- No breakdown section

Each new sub-style should follow the same pattern: one probabilistic flag, separate musical-frame generator branch (or dedicated generator file for complex cases), minimal changes to the shared infrastructure.
