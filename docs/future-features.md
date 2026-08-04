# Zudio — Future Feature Ideas
Copyright (c) 2026 Zack Urlocker

These are potential ieas for occasional updates to Zudio beyond V 2.0. They are intended as lightweight new additions that could improve the variety without too much work. Instruments and effects would be the easiest. New substyles would require substantially more work. 
---

## 1. New Instruments

The following instruments are present in `Zudio.sf2` but not yet assigned to any pool. Suggestions are grouped by style, with GM program codes in parentheses (encoded as `bank × 1000 + program`, matching the existing convention in `AppState.swift`).

---

### Ambient    -- may need to look for other options - these seem boring

**Shakuhachi** (`77`) → Lead 1 (DONE build 125)  
Japanese bamboo flute. Deep, breathy, slightly overblown tone — more earthy and meditative than the Flute or Ocarina already in the Lead 1 pool. Think of the solo wind voices in Harold Budd or early Loscil. Its longer attack and natural pitch wobble would sound very natural with Ambient's slow phrasing rules.

**Kalimba** (`108`) → Rhythm  (DONE build 126)
Thumb piano. Gentle, reverberant plucks with a naturally short decay and distinctive metallic overtone. Would sit beautifully in the Ambient Rhythm pool alongside Glockenspiel and Celesta — similar textural role but more organic. Widely used in ambient and minimalist composition (Jon Hopkins, Nils Frahm).

**Stereo Strings Fast** (`48`) → Pads  
We use Stereo Strings Slow (49) in the Ambient Pads pool. The Fast variant adds attack and urgency — useful for transitions or more dramatic passages without adding a new texture type. Same sonic family, different feel.

**Koto** (`107`) → Lead 2  
Japanese plucked string instrument. A gentle, sustained pluck with a long decay. Different from the Harp (already in Lead 2) — more nasal and intimate. Could work particularly well in Ambient Piano songs as a secondary melodic voice.

---

### Chill

**Detuned Tonewheel Organ** (`8016`) → Rhythm (DONE build 125)  
A Leslie-cabinet-style organ with slight detuning between its tines. Adds a vintage wobble that the clean Rock Organ and Percussive Organ in the current pool don't have. Good for more psychedelic or soul-influenced Chill tracks.

**Marimba** (`12`) → Lead 2  
Warmer and mellower than the Xylophone (already in Lead 2). The marimba's softer attack and rounder tone suits bossa nova or gentle jazz-inflected Chill songs, where xylophone would feel too bright. Pairs naturally with the vibraphone already in the pool.

**Hawaiian Guitar** (`8026`) → Rhythm  
Lap steel / Hawaiian slide guitar. A warm, singing slide quality unlike any of the current Chill rhythm instruments. Fits the laid-back, sun-drenched quality of Moby-adjacent Chill. Could also work as a secondary Lead.

---

### Kosmic

**Pulse Bass** (`11039`) → Bass (DONE build 125)  
A synth bass with a pulsing, gated quality — more rhythmically alive than the sustained Moog and Lead Bass already in the pool. Particularly interesting for Kosmic Drift where the bass breathing effect is already a design goal. The pulse character adds motion without requiring additional LFO programming.

**Shamisen** (`106`) → Lead 1 (Drift pool)  
Japanese three-string lute with a sharp, buzzy attack and quick decay. Unusual and distinctive — fits the eclectic Kosmic Drift Lead 1 pool (which already includes Shenai and Bottle Blow). Creates an unexpected, slightly alien texture against heavily-reverbed pads.

**Fantasia 2** (`12088`) → Pads (Done build 126)
A second variant of the Fantasia / New Age Pad voice. The current pool uses New Age Pad (88) in the Rhythm track. Fantasia 2 has a slightly different harmonic envelope and could add variety to the Pads pool as a dreamy, evolving alternative to Sweep Pad and Halo Pad.

**Tonewheel Organ** (`16`) → Bass (Done build 128)
Classic Hammond B3 voice played in bass register. Warm, sustained, rotary-speaker character. Added for atmospheric low-end variety in both regular Kosmic and Drift.

**Warm Pad** (`89`) → Bass (Done build 128)
Smooth, slow-attack synth pad used in bass register. No percussive transient, just a soft sustained low tone. Organ-adjacent character — more atmospheric than the synth bass options already in the pool.

---

### Motorik

**Guitar Fdbk** (`8031`) → Texture (Noir)  (Done build 126)  
Sustained guitar feedback / controlled noise. Adds a Sonic Youth / This Heat / early PiL textural layer that fits Motorik Noir's dark, angular aesthetic. Would give Noir texture tracks a rawer quality than the current FX Atmosphere and Halo Pad options.

**Harpsichord** (`6`) → Rhythm  
Unusual choice but historically grounded — Baroque keyboard sounds appear in Krautrock (early Tangerine Dream, Neu! collaborations). Adds a sharp, clipped attack distinct from the organ voices already in the Rhythm pool. Interesting textural counterpoint to the guitar-heavy options.

---

## 2. New Audio Effects

All suggestions are for additions beyond the existing reverb, delay, tremolo, sweep filter, and auto-pan already implemented.

---

### Chorus — NOT FEASIBLE with built-in Apple AUs

Apple does **not** provide a built-in chorus AU on macOS or iOS. The constant `kAudioUnitSubType_Chorus` does not exist in any Apple SDK. The complete list of Apple-manufactured Effect AUs available at runtime includes: Band/High/Low Pass Filter, High/Low Shelf, Parametric EQ, Graphic EQ, N-Band EQ, Delay, Sample Delay, Distortion, Dynamics Compressor, MultiBand Compressor, Limiter, Matrix Reverb, Reverb2, New Time Pitch, Time Pitch, AU Filter, Net Send. No chorus, flanger, phaser, or ring modulator.

Implementing a real chorus effect would require either:
- A parallel audio path (dry + pitch-shifted copy at 50% each) — significant engine restructuring
- A third-party AU plugin bundled with the app
- Manual LFO parameter updates on a SampleDelay node per render block

Estimated effort: significant (multi-day). Not a quick add. Best deferred unless chorus becomes a high priority.

---

### Distortion — DONE Build 128

`kAudioUnitSubType_Distortion` is a standard Apple AudioUnit effect with 18 parameters covering multiple distortion types: soft saturation, hard clip, linear fold-over, square fold-over, bit reduction, and more. CPU cost: very low.

**Implemented:** Soft-clip saturation (SoftClipGain +6 dB, FinalMix 50%) added as a "Dist." effect chip on Motorik Bass and Motorik Rhythm, replacing the Low and Boost chips respectively. Post-distortion gain compensation of −3 dB applied via the fanMixer to keep perceived loudness consistent. Applied probabilistically: Motorik Noir Bass and Rhythm each 75% on by default (independent rolls); regular Motorik Bass 20% on by default. All flags stored in SongState so each song's distortion state is reproducible. Old saved songs default to no distortion.

**Still to explore:** Kosmic Drift rhythm (subtle tape saturation). The harder distortion modes (hard clip, fold-over) could add more aggression for Noir if the soft-clip default feels too subtle.

---

### Bit Crusher — pure Swift DSP via installTap

A bit crusher reduces the bit depth of the audio signal, creating lo-fi quantization noise. It can be implemented with no additional AudioUnit — just an `installTap` on an `AVAudioMixerNode` that processes each buffer:

```swift
// Quantize to `bits` bit depth
let levels = Float(pow(2.0, Double(bits)))
for i in 0..<frameCount {
    channelData[i] = round(channelData[i] * levels) / levels
}
```

CPU cost: essentially zero (a few multiply/round operations per sample).

**Best use:** A potential Lo-Fi Chill substyle (see Section 3) — bitcrushing the Rhodes or rhythm track to 10–12 bits adds the characteristic lo-fi warmth. Also works for Kosmic Drift's degraded/tape-worn aesthetic on leads or texture. The depth parameter (bits: 8–16) can be interpolated smoothly.

Implementation: custom class wrapping `installTap` on the boost mixer node. Estimated effort: 1–2 days, no external dependencies.

---

### Sample Rate Reduction — pure Swift DSP

Related to bit crushing: downsamples the audio to a lower effective sample rate (e.g. 8000 Hz, 11025 Hz) then upsamples back, creating aliasing and the characteristic lo-fi texture of early digital audio or cheap samplers. Can be combined with bit crushing.

```swift
// Hold every Nth sample (effectively reduces sample rate by N)
let holdN = Int(sampleRate / targetRate)
var held: Float = 0
for i in 0..<frameCount {
    if i % holdN == 0 { held = channelData[i] }
    channelData[i] = held
}
```

**Best use:** Lo-Fi Chill substyle. Also vintage drum machine textures for Motorik.

---

### Haas Effect / Stereo Widener — using existing AVAudioUnitDelay

The Haas effect uses a very short delay (10–35ms) on one channel to create perceived stereo width from a mono source without adding audible echo. This can be achieved with the existing `AVAudioUnitDelay` at very short delay times (< 35ms) and 100% wet, applied to one channel via panning tricks.

**Best use:** Ambient and Kosmic pads and texture tracks — adds width to mono synth sources, making them feel more enveloping without using CPU-heavy reverb. Simple parameter change to existing delay node.

---

## 3. New Generation Rules

Rule additions ranked by impact: tracks with fewer existing rules benefit disproportionately from each new rule. Current non-silent rule counts are noted to frame the priority.

---

### Kosmic — Texture (4 rules — KOS-TEXT-001 through 004)

The Texture track is one of Kosmic's most defining elements — the long pad and atmospheric sounds that sit underneath everything else — but it has only 4 rules. By contrast, Kosmic Bass has 16+ rules and Rhythm has 15. New texture rules with distinct atmospheric characters would meaningfully increase how different Kosmic songs sound from each other.

**KOS-TEXT-005 — Slow Frequency Sweep Layer**  
A texture that evolves its tonal character over a long arc — beginning dark and filtered (low LP cutoff) and gradually opening up over 16–32 bars, or vice versa. Not a note-change but a continuous timbral shift. Inspired by the evolving filter sweeps in Tangerine Dream's "Phaedra" where synthesiser textures open and close over minutes. Implementation: note held for the full section, with a programmatic sweep envelope written as events at each bar boundary (or relying on the existing sweep LFO chip applied from generation time).

**KOS-TEXT-006 — Rhythmic Pulse Texture**  
Short repeated stabs of texture (eighth or quarter note) at very low velocity, creating a subliminal rhythmic grid underneath the main instruments. Different from the Rhythm track — quieter, more abstract, more pad-like. Think of the background synthesiser pulses in Klaus Schulze's "Mirage". Implementation: a simple repeated-note pattern at a fixed subdivision with random velocity variation, using one of the shorter-decay texture instruments (FX Echoes, Rain).

### Kosmic — Lead 2 (5 rules — counter-melody subset of Lead 1 rules)

Lead 2 is intentionally constrained to KOS-LEAD-001 through 005 (the sparser rules) and has special counter-melody logic — including a diatonic third offset from Lead 1 when rule 005 fires. It works well but its identity is a quieter version of Lead 1. A rule designed exclusively for Lead 2's supporting role would give it a distinctly different character rather than just being a reduced Lead 1.

**KOS-LD2-001 — Sustained Anchor Tone**  
Lead 2 holds a single long tone — the root, fifth, or major third of the current chord — for 4–8 bars without melodic movement. No phrase contour, no rhythm. Pure harmonic reinforcement. This is not a melody at all, making it entirely distinct from the existing shared rules. Inspired by the sustained wind/string layers in Harold Budd's collaborations with Brian Eno. Implementation: single note selected from chord tones, long duration (16–32 steps), very low velocity (30–50). Available to Lead 2 only.

---

### Chill — Lead 2 (2 rules — CHL-LD2-001, CHL-LD2-002)

With only 2 Lead 2 rules plus the harmony overlay (which fires conditionally), Chill Lead 2 sounds the same in nearly every song. Lead 1 has 9 rules by contrast.

**CHL-LD2-003 — Long Tone Fill**  
Lead 2 plays in the spaces where Lead 1 is resting — when Lead 1 holds a long note or is silent, Lead 2 fills with a short ornamental phrase (2–3 notes). Inspired by the interplay between horn and rhythm piano in classic Blue Note recordings. Implementation: fire only during Lead 1 silence bars, use the current chord's upper extensions.

**CHL-LD2-004 — Ostinato Riff**  
A simple 2-bar melodic cell repeated throughout the section — 4–5 notes that loop without variation, creating a hypnotic ground beneath Lead 1's improvisation. Think of the keyboard riffs in St Germain or the repeated vibraphone figures in Bill Evans recordings. Implementation: generate the cell once per section, repeat exactly — the simplest possible Lead 2 rule.

---

### Chill — Rhythm (4 rules — CHL-RHY-001 through 004)

The 4 existing rhythm rules (St Germain loop, Bosa Moon, etc.) all share the same character: on-beat chord placement with electric piano voicings. A rule with a fundamentally different rhythmic approach would make Chill songs feel noticeably different from each other.

**CHL-RHY-005 — Off-Beat Funk Chop**  
Chords placed exclusively on the off-beats (the "and" of beats 2 and 4, or the "and" of 1 and 3), with very short note durations (16th or 8th note). Muted, percussive quality — the rhythm instrument becomes a rhythmic accent rather than a harmonic anchor. Inspired by Nile Rodgers' guitar comping and the keyboard stabs in classic Steely Dan. Implementation: step positions constrained to off-beat 16th positions, short note durations (1–2 steps), high velocity with quick decay.

**CHL-RHY-006 — Jazz Comping Anticipations**  
Chord placements that anticipate the downbeat by an 8th note (the "and" of beat 4 going into beat 1), with occasional displaced accents on beat 2. Irregular enough to sound improvised, regular enough to feel controlled. Inspired by the piano comping style of McCoy Tyner and Herbie Hancock. Implementation: pattern-based with probabilistic anticipation offsets per bar.

---

### Ambient — Drums (3 rules — AMB-DRUM-001, AMB-DRUM-002, AMB-DRUM-004)

Ambient drums are the most heard-but-not-noticed element of Ambient songs. With only 3 rules, they contribute almost no variety. A new pattern with a clearly different character would affect how every Ambient song feels without demanding attention.

**AMB-DRUM-005 — Brushed Jazz Pulse**  
Brush kit. Snare on beat 3 only (or beats 2 and 4 for more swing), kick on beat 1, very soft hi-hat on quarters. Extremely low velocity throughout (25–45). Creates the barely-there rhythmic suggestion of ECM jazz recordings (Jan Garbarek, Eberhard Weber). No fills. Implementation: straightforward pattern, low velocity range, Brush Kit instrument locked.

**AMB-DRUM-006 — Taiko Resonance**  
Single taiko or melodic tom strikes at very sparse intervals (one every 2–4 bars), always on the downbeat, high reverb. More a textural accent than a rhythmic pattern — each hit decays into the space around it. Inspired by the minimal percussion in Japanese ambient music and Harold Budd's collaborations. Implementation: probability-based single-hit pattern, very long note spacing, Percussion Kit.

---

### Ambient — Lead 2 (shared AMB-LEAD pool — 10 rules total, but same rules as Lead 1)

Lead 1 and Lead 2 currently draw from the same rule set. Adding 1–2 rules explicitly designed as accompaniment rather than melody would give Lead 2 a distinct role.

**AMB-LEAD2-001 — Sustained Interval**  
Rather than a melodic phrase, Lead 2 holds a sustained note — the root or fifth — for 4–16 bars. No melody, just a long tone that slowly fades with the reverb tail. Anchors the harmonic space while Lead 1 moves freely above. Inspired by the sustained organ tones under melody in Brian Eno's "Discreet Music". Implementation: single note, very long duration, gentle velocity, fades at phrase boundaries.

---

### Motorik — Pads (8 rules — but Noir variant has fewer)

Motorik Pads has 8 rules total, but Motorik Noir currently uses only a subset. A rule specifically designed for Noir's darker character would make Noir songs feel more cohesive.

**MOT-PADS-009 — Noir Tension Cluster**  
Noir-specific. Pads play a minor second or tritone interval (two notes, not a full chord) held for 4–8 bars at low velocity, creating controlled dissonance. The two notes are the root and a semitone or tritone above — tension without resolution. Inspired by Joy Division's keyboard washes and the dissonant pads in early PiL ("Metal Box"). Implementation: two-note voicing with dissonant interval selection from the current key's tension tones, Noir variant only.

---

## 4. New Substyles

One proposed substyle for each of the four existing styles. These are sketch-level ideas — brief descriptions of the artistic direction and what would make them distinct from existing substyles.

---

### Ambient — "Glacial"

**Inspired by:** Ólafur Arnalds, Nils Frahm, Jóhann Jóhannsson, Stars of the Lid  
**Character:** Nordic cold, vast open space, long silences, very slow harmonic movement. Not piano-led like Ambient Piano — the lead voices are more wind-like and spectral (flute, Shakuhachi, Ocarina). Bass is minimal or absent. Notes are sparse with deliberate rests between phrases. Harmonies favour suspended and pentatonic intervals that avoid resolution.  
**Distinguishing features vs existing Ambient:** No drum track. Lead phrasing has much longer inter-note silence. Texture is the primary "melody" — slow-evolving pad swells dominate. Mode locked to major pentatonic or modal scales (Dorian, Lydian). Tempo very slow (40–55 BPM). Could use the Stereo Strings Fast + Shakuhachi combination for a clean, cold tone.

---

### Chill — "Lo-Fi"

**Inspired by:** Nujabes, j dilla, Knxwledge, Idealism, lo-fi hip hop radio  
**Character:** Vinyl warmth, slightly degraded audio quality, repetitive hypnotic loops, simple 2–3 chord progressions, lazy laid-back groove. Rhodes or Warm Pad dominant. Vinyl crackle texture always present. Simpler melodic content — shorter phrases that loop rather than develop.  
**Distinguishing features vs existing Chill:** Bit crusher applied to one or two tracks (Rhodes, drums). Lower tempo ceiling (60–80 BPM). Vinyl crackle texture always on. Drum patterns simpler and more repetitive (fewer variations). Lead lines shorter and more cyclical — closer to a riff than a solo. Bass is minimal and in the pocket. Fewer chord changes per section. Could use the Kalimba or Marimba as secondary melodic voices for a distinctive textural quality.

---

### Kosmic — "Berlin School"

**Inspired by:** Tangerine Dream ("Phaedra", "Rubycon"), Klaus Schulze, Cluster, Conrad Schnitzler  
**Character:** Analogue-sequencer-driven arpeggios, very long evolving pads, no conventional rhythm section. The "sequencer" feel — repeating 8–16 note cycling bass or rhythm patterns that slowly shift pitch and timbre over many bars. Dense modular-synth textures that evolve rather than resolve.  
**Distinguishing features vs existing Kosmic:** Bass uses a fast-cycling arpeggio rule (like KOS-BASS-014 but as the primary mode, not a sub-rule). Rhythm track runs a repeating sequencer-style pattern rather than chord stabs. Lead enters very late and improvises over the top of the sequence. Pads sustain for very long (8–16 bars). Drums absent. Tempo slower (60–80 BPM). A "Berlin School" intro could run 8+ bars of pure texture before the sequencer locks in.

---

### Motorik — "Post-Punk"

**Inspired by:** Wire, Gang of Four, The Fall, early Talking Heads, Cabaret Voltaire  
**Character:** Angular, minimal, tense. The steady 4/4 motorik pulse is there but the textures are spare and abrasive rather than hypnotic. Bass is prominent and melodic (often the lead voice). Guitar rhythm is choppy, staccato. Leads are skronky or minimal. No warmth — everything is slightly cold and functional.  
**Distinguishing features vs existing Motorik:** Different from Motorik Noir (which is darker, more sustained, more bass-heavy). Post-Punk is faster and more angular (120–145 BPM). Rhythm uses Distortion Guitar or Feedback Guitar rather than synth-heavy options. Bass is more melodic and forward in the mix (Pick Bass, Fretless Bass). Lead uses Square Wave or Sawtooth Stab for a raw, unprocessed quality. Pads are minimal or absent. Fewer effects overall — drier sound than standard Motorik. Fills are sparse, drum patterns simple and insistent.

---
