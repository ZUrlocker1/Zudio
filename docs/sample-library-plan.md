# Zudio / Zenio Synth Library Plan

**Shipped sound bank (Zudio):** Zudio uses the **GeneralUser GS** soundfont by S. Christian Collins, adopted for the v1.0 release and current across all platforms (Mac, iPad, iPhone).

- GeneralUser GS: https://schristiancollins.com/generaluser.php
- License/readme: https://github.com/sfzinstruments/GeneralUser-GS

---

## Synthesizer Library for Zenio

The preferred direction for Zenio is real synthesis rather than soundfont-based playback — oscillators, filters, and envelopes that can produce pads, drones, and groovebox synth tones natively.  

---

## AudioKit v5 — Recommended

The only Swift-native synthesis library with active maintenance, SPM integration, and iOS + Mac support. MIT licensed. All packages updated through April 2026.

AudioKit v5 is modular — pull only what you need. The practical starting set for Zenio:

- **AudioKit** — core audio graph, engine, MIDI, scheduling. Required by all other packages.
- **AudioKitEX** — C/C++ DSP extension, required by the synthesis packages.
- **SoundpipeAudioKit** — the main synthesis workhorse: 50+ DSP nodes including oscillators, filters, reverbs, and effects.
- **DunneAudioKit** — polyphonic Synth (32 voices) and Sampler, plus Chorus, Flanger, Stereo Delay.
- **Tonic** — Swift music theory: notes, chords, scales, intervals. Standalone, no audio dependency. Pairs well with Zenio's chord-aware sequencing.

### Full Package List

**Core**
- `AudioKit` — audio graph, MIDI, scheduling. ~117 MB source (git history; compiled binary much smaller). v5.7.2 Mar 2026.
- `AudioKitEX` — C/C++ DSP layer. 0.4 MB. v5.7.0 Apr 2026.

**Synthesis + Effects**
- `SoundpipeAudioKit` — FM/PWM/Morphing oscillators, Moog Ladder + Korg filters, Zita/Chowning/Costello reverbs, phaser, pitch shifter, tremolo, auto-panner. 3.3 MB. v5.7.4 Apr 2026.
- `DunneAudioKit` — polyphonic Synth, Sampler (SFZ/EXS24), Chorus, Flanger, Stereo Delay, Transient Shaper. 0.6 MB. v5.6.2 Apr 2026.
- `STKAudioKit` — physical models: Clarinet, Flute, Mandolin, Rhodes Piano, Shaker, Tubular Bells. 0.7 MB. v5.5.1 Aug 2025.
- `SporthAudioKit` — stack-based DSP scripting for custom patches. 0.2 MB. Jan 2023 (older, less maintained).
- `DevoloopAudioKit` — guitar amp/cabinet simulation only. Not relevant for Zenio. 0.4 MB. Dec 2022.

**UI Components**
- `Controls` — SwiftUI knobs, sliders, XY pads. 0.3 MB. v1.0.0 Sep 2023.
- `Keyboard` — SwiftUI music keyboard view. 1.7 MB. v1.4.0 Dec 2024.
- `PianoRoll` — touch piano roll editor. 0.2 MB. v1.0.1 Jul 2024.
- `AudioKitUI` — waveform plots and visualizers. 0.8 MB. v0.3.6 Oct 2023.
- `Waveform` — GPU/Metal waveform renderer. 4.7 MB. No formal releases.
- `Flow` — node graph patch bay editor UI. 1.1 MB. No formal releases.

**Music Theory**
- `Tonic` — notes, chords, scales, intervals, chord recognition. Standalone. 1.2 MB. v2.0.0 Dec 2025.
- `Microtonality` — microtonal tuning table support (.scl/.kbm). 0.1 MB. Jan 2023.

**Utility**
- `KissFFT` — FFT library, pulled in automatically. 0.02 MB.

### Key Capabilities and Honest Limitations

**DunneAudioKit Synth** is polyphonic (32 voices, voice stealing) with dual ADSR (amplitude + filter), filter cutoff/resonance, vibrato depth, and pitch bend. The oscillator configuration is hardwired in C++ as saw + square + organ drawbar — not configurable from Swift. Good for an instant dense pad; not a fully tweakable synth.

**SoundpipeAudioKit oscillators** are monophonic but more configurable. Most useful for pads and drones:
- `MorphingOscillator` — morphs between triangle/square/sine/saw via an `index` parameter; animating `index` slowly creates evolving pad textures
- `FMOscillator` — carrier/modulator ratio and modulation index; good for metallic and bell textures
- `PWMOscillator` — pulse width control; animating it creates a wide, chorus-y pad sound
- `MoogLadder` filter — Huovilainen DaFX04 model, resonance up to 2.0 (self-oscillation); the best filter in the package

**No dedicated LFO node.** Modulation is driven by a Swift timer loop, or via the `Tremolo`, `AutoPanner`, and `Vibrato` effect nodes as workarounds.

- GitHub: https://github.com/AudioKit/AudioKit

---

## Loading Preset Libraries — The Fastest Path to Ready-Made Sounds

Rather than programming oscillators from scratch, the quickest route to out-of-the-box synth sounds is loading real sampled presets. AudioKit supports two formats via two different samplers:

**DunneAudioKit Sampler + SFZ**
- Loads SFZ format: `sampler.loadUsingSfzFile(folderPath:, sfzFileName:)`
- SFZ is a plain-text mapping referencing bundled WAV files — widely supported, large library of free presets
- Call `sampler.unloadAllSamples()` before switching preset sets or memory stacks up
- No SF2 or EXS24 support

**AudioKit MIDISampler + SF2/EXS24**
- Wraps Apple's AUSampler: `sampler.loadMelodicSoundFont(...)`, `sampler.loadEXS24(...)`
- Same approach as Zudio's GeneralUser GS, just pointed at a synth-focused soundfont
- No SFZ support

### Free SFZ/SF2 Preset Libraries for Synth Sounds

**Pads**
- FreePats Synth Pad collection (CC0, SFZ+WAV) — Synth Pad Choir, Sweep Pad, New Age, Bowed Pad. Small files, high quality. freepats.zenvoid.org/Synthesizer/synth-pad.html
- Minifreak Pads (CC0, SFZ) — 5 multi-sampled soundscapes from an Arturia Minifreak. 265 MB. sfzinstruments.github.io
- Wavestate Pads (CC0, SFZ) — 3 Korg Wavestate landscapes. 160 MB. sfzinstruments.github.io
- Synthetic Vortices (free, SFZ) — 90 ambient pad samples from an Ensoniq Fizmo synth. samplescience.ca

**Bass**
- FreePats Synth Bass #1 (CC0, SFZ) — modeled analog bass. github.com/freepats/synth-bass-1
- FreePats Synth Bass #2 (CC0, SFZ) — DX7-style FM bass. github.com/freepats/synth-bass-2
- Bass City by 99Sounds (free, SFZ) — 26 analog and FM bass patches from real hardware. 99sounds.org/bass-city/

**FM Electric Piano**
- FreePats DX7 Electric Piano (CC0, SFZ) — emulation of the classic DX7 "E. Piano 1" patch. freepats.zenvoid.org/ElectricPiano/synthesized-piano.html
- Musical Artifacts (musical-artifacts.com) — search SF2 + FM tags for many DX7 reconstructions made with Dexed

**Lead Synths**
- sfzinstruments.github.io synthesizers section — curated CC0 SFZ instruments
- FreePats Synth Lead collection — freepats.zenvoid.org/Synthesizer/

**Best Browsable Catalogs**
- FreePats (freepats.zenvoid.org) — all CC0, all SFZ+WAV. 44 repos, consistently high quality.
- Musical Artifacts (musical-artifacts.com) — filter by SFZ or SF2 format, add sound tags.
- sfzinstruments.github.io — curated index of CC0/CC-BY SFZ instruments by category.
- KVR Audio "Best SFZ/SF2 sources" thread — community-maintained, updated regularly.

### AUv3 Plugin Hosting

AudioKit can load any AUv3 plugin already installed on the user's device:

```swift
let au = AudioEngine.findAudioUnit(named: "Moog Model D")
engine.avEngine.attach(au!)
engine.avEngine.connect(au!, to: engine.avEngine.mainMixerNode, format: nil)
```

This gives access to the full App Store AUv3 ecosystem (Moog Model D, Korg iMono/Poly, etc.) at no cost. The constraint: the user must have that plugin's app installed — you cannot bundle a third-party AUv3 inside your own app. Useful as a power-user feature for Zenio, not a core dependency.

### No Plug-and-Play Swift Synth Libraries

There is no SPM package outside the AudioKit ecosystem that ships ready-made FM synth, pad, or bass instrument objects callable from Swift. AudioKit Synth One is open source (MIT) but is an app, not an importable library. The practical Zenio approach is: **AudioKit + SFZ/SF2 presets for instant sound, SoundpipeAudioKit oscillators for procedural generation**.

---

## Alternatives Evaluated

**JUCE** — The industry standard C++ audio framework, used by most professional iOS synth companies. Has a proper configurable synth stack (any waveform oscillator, Moog ladder filter, ADSR, polyphony). But C++ only — requires Objective-C++ bridging from Swift, CMake/Projucer build system instead of SPM, and no community Swift wrapper exists. Free under $50k revenue. Viable if C++ DSP work is acceptable; not the easy path.

**iPlug2** — C++ plugin/standalone framework with LFO, ADSR, and voice allocation built in, but no filters (must add separately) and the Swift bridge is rough in practice. Permissive zlib license.

**miniaudio** — Excellent lightweight C audio I/O library, solid filters, basic waveform generation. No envelopes, LFOs, or polyphony. A foundation for hand-rolling synthesis in C, not a ready-made synth.

**Not viable:** SoLoud (dormant since 2021), Maximilian (unmaintained since 2021), Faust (iOS JIT prohibited by Apple), Superpowered (not a synth engine, commercial license), Surge XT (desktop plugins only), Oboe (Android only).

---

## Post-v1 Sample Library Research

Research into free/open sample assets as an alternative or complement to real synthesis. Less preferred than the synthesizer path but documented here for reference.

### License Tiers

- `CC0` — safest for app bundling and redistribution.
- `CC-BY-4.0` — usable if attribution is included in app/docs.
- `Royalty-free (custom terms)` — verify redistribution rights per pack before shipping.

### Drums

- Vintage Electronic Kit — FreePats Electric and Synthesizer Percussion. CC0. https://freepats.zenvoid.org/Percussion/electric-percussion.html
- Rock Kit — DrumGizmo DRS Kit (SFZ port). CC-BY-4.0. https://sfzinstruments.github.io/drums/drs_kit/
- Big Rusty Drums — Karoryfer. Verify license per pack. https://shop.karoryfer.com/pages/free-big-rusty-drums

### Bass

- Lately Bass (TX-style), Synth Bass #1, Synth Bass #2 (DX-style) — all CC0. https://freepats.zenvoid.org/Synthesizer/synth-bass.html
- Clean Electric Bass — CC0. https://freepats.zenvoid.org/ElectricGuitar/clean-electric-bass.html

### Lead 1

- Synth Fifths, Synth Bass & Lead — CC0. https://freepats.zenvoid.org/Synthesizer/synth-lead.html
- Clean Electric Guitar #1 (processed as mono lead) — CC0. https://freepats.zenvoid.org/ElectricGuitar/clean-electric-guitar.html

### Lead 2

- Synth Brass #1, Synth Brass #2 — CC0. https://freepats.zenvoid.org/Synthesizer/synth-brass.html
- Synth Bass & Lead (thin high-register mapping) — CC0.

### Pads

- Synth Pad Choir, New Age (Synth Pad 1), Sweep Pad (Synth Pad 8) — CC0. https://freepats.zenvoid.org/Synthesizer/synth-pad.html
- Synth Strings #1/#2 — CC0. https://freepats.zenvoid.org/Synthesizer/synth-strings.html

### Rhythm

- Clean Electric Guitar #1/#2 — CC0. https://freepats.zenvoid.org/ElectricGuitar/clean-electric-guitar.html
- Synth Lead pulse source — CC0. https://freepats.zenvoid.org/Synthesizer/synth-lead.html

### Texture

- Synth Goblins, Synth Soundtrack — CC0. https://freepats.zenvoid.org/Synthesizer/synth-effects.html
- 99Sounds texture packs — royalty-free (verify redistribution terms). https://99sounds.org/sounds/

### Additional Sources

- Karoryfer free libraries: https://shop.karoryfer.com/pages/free-samples — confirm license per library before bundling.
- SFZ Instruments index: https://sfzinstruments.github.io/ — quickly identify CC0/CC-BY instruments by category.

---
Copyright (c) 2026 Zack Urlocker
