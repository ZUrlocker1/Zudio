# Sub-Style Variants — Research & Design Plan
Copyright (c) 2026 Zack Urlocker

## Overview

Chill Blues demonstrated that a musically distinct sub-style surfacing ~20% of the time adds meaningful variety without fragmenting the style identity. It works because it shares the parent style's core engine (same generators, same pipeline) but changes enough musical rules — song structure, harmonic language, instrumentation weight — to feel like a genuinely different idiom.

This document identifies 3 more sub-styles, one for each remaining style. Each is designed to appear 20-35% of the time, determined probabilistically at song-generation time (same mechanism as `isChillBlues`).

---

## Current Substyle Probabilities (as in code)

These are the live values in the codebase as of this writing. Target release probabilities are noted separately where they differ.

- **Chill Blues** — `20%` of Chill songs (`rng.nextDouble() < 0.20` in `ChillMusicalFrameGenerator.swift`)
- **Motorik Noir** — `23%` of Motorik songs (`rng.nextDouble() < 0.23` in `SongGenerator.swift`)
- **Kosmic Drift** — `30%` of Kosmic songs (`rng.nextDouble() < 0.30` in `CosmicMusicalFrameGenerator.swift`)
- **Kosmic Drift — Dreamscape variant** — `15%` of Drift songs, i.e. ~4.5% of all Kosmic songs (`rng.nextDouble() < 0.15`, also in `CosmicMusicalFrameGenerator.swift`)
- **Ambient Piano** — `35%` of Ambient songs (`pianoRoll < 0.35` in `SongGenerator.swift`)

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

## Sub-Style 3: Kosmic Drift

**Parent style:** Kosmic
**Appears:** ~15% of Kosmic songs
**Full plan:** [kosmic-drift-plan.md](kosmic-drift-plan.md)

### Musical identity

Base Kosmic is JMJ / Tangerine Dream territory — sequencer-driven, melodic lead, cosmic and propulsive. Kosmic Drift keeps the sequencer and melodic lead entirely intact but drops the tempo to 70–90 BPM, allowing the sequencer ostinato to breathe rather than drive. A slow loping drum groove replaces Kosmic's sparse or absent rhythm — not a breakbeat in the hip-hop sense, more of a slow pulse that frames the sequencer without competing with it.

The primary references are **Carbon Based Lifeforms — *Hydroponic Garden*** (cold end), **Boards of Canada** sequencer-forward tracks (strange/nostalgic middle), **Tycho** (warm, melodic end), and **Air — "La Femme d'Argent"** (elegant, cinematic). All keep the Berlin School sequencer logic intact; they just run it slower and wrap it in warmer, more organic textures than classic TD.

*Note: "Kosmische Spiritual" (Popol Vuh, drone-based, raga-adjacent) was considered and rejected. Tangerine Dream — Zeit and Steve Roach — Structures from Silence were also set aside as too close to Ambient territory. None of these are part of this substyle.*

### How it differs from base Kosmic

- **Tempo** — 70–90 BPM (new BPM Mode C) vs. base Kosmic's Mode A (115–126) and Mode B (88–105). The sequencer ostinato feels meditative, not driving.
- **Rhythm** — slow loping groove with snare slightly behind beat 2, ghost hits, sparse hi-hats; replaces sparse or absent Kosmic rhythm. Never 4-on-the-floor.
- **Sequencer / bass** — same patterns at lower BPM; bass hit density slightly reduced (85% gate) to complement the groove rather than compete.
- **Lead and pads** — unchanged; the slower tempo naturally gives them more room to breathe.
- **Song structure** — identical to base Kosmic (intro drone → body → outro).

### Implementation notes

Low risk. One new drum rule (KOS-DRUM-007 Loping Groove) and a BPM mode change are the only new work. The sequencer engine, lead, pads, and harmonic language are untouched. See [kosmic-drift-plan.md](kosmic-drift-plan.md) for full implementation detail.

---

## Implementation Priority

- **Motorik Noir** — highest priority. Most distinct emotional impact, lowest implementation risk. Same generator structure, different tempo + harmony + register rules. No new instruments needed.
- **Ambient Piano** — second priority. Genuinely different from loop-phasing Ambient, elegant to implement, already has the right instruments (piano, Wurlitzer).
- **Kosmic Drift** — third. Keeps the JMJ/TD melodic DNA intact; only new work is a slow loping drum rule (KOS-DRUM-007) and a BPM mode change. Carbon Based Lifeforms, Boards of Canada, and Tycho are the clearest reference points.

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
