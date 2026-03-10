# Zudio Music Architecture

## Goals

- Build a native macOS prototype quickly with reliable real-time audio.
- Keep the underlying music engine portable to iPhone/iPad later with minimal rewrite.
- Support generative pattern logic with MIDI-first playback for v1.

## V1 Architecture Lock (authoritative)

This section is the source of truth for v1 implementation architecture.
If any later section conflicts with this lock, this section takes precedence.

- Platform/UI:
  - Native macOS app using Swift + SwiftUI.
- Audio engine:
  - Apple `AVAudioEngine` only in v1.
  - No AudioKit dependency in v1.
- Sound source:
  - Apple DLS / General MIDI is the default source for all tracks.
  - Drums use two kits in v1:
    - `Electronic` (GM/GS kit 24)
    - `Rock Kit` mapped to `Power` (GM/GS kit 16)
  - Starter musical content is from repo starter assets and generated MIDI notes.
- Generation/playback model:
  - Generator produces MIDI events per track from song structure, harmony, and track rules.
  - Playback renders those MIDI events through selected GM instruments.
- Product scope constraints (v1):
  - Style selector is locked to Motorik.
  - Effects UI appears as disabled placeholders; effect editing is out of scope.
  - `Previous`/`Next` transport appear but are non-functional placeholders.
  - No seed/session recall UI in v1.
  - Authoritative v1 GM instrument/kit mapping is in `docs/prototype.md` (`Apple DLS General MIDI presets (v1 core sound source)`).

## Post-v1 Considerations (not v1 implementation scope)

- Higher-quality GM soundfont upgrade path (0.75+), preserving MIDI workflow.
- Optional AudioKit integration behind an adapter boundary if iteration speed/quality requires it.
- Sample-library based instruments/effects workflows.
- Post-v1 sample-library sourcing/evaluation reference:
  - `docs/post-v1-sample-library-research.md`
- iPhone/iPad target delivery work (architecture should remain portable, but implementation is Mac-first).
- Evolution mode and advanced effects editing.

## Recommended architecture direction (for Zudio v1)

- App/UI layer: Swift + SwiftUI (macOS now, iOS/iPadOS later).
- Audio engine layer: Apple `AVAudioEngine` graph with custom scheduling/generation logic.
- Sound generation layer: MIDI-first generation rendered by Apple DLS / GM instrument mapping.
- Data model: weighted probability rules (style profile driven).

Why this direction:

- Best native integration on macOS and iOS.
- Lowest portability risk for later iPhone/iPad target.
- No engine swap required to expand from Mac to iOS/iPad.

## Technology options

### Option A: Apple-native stack (lowest portability risk)

- Core pieces:
  - `AVAudioEngine`
  - `AVAudioPlayerNode` (sample clips/loops)
  - `AVAudioUnitSampler` (sample instruments)
  - `AVAudioUnit` effects (EQ, delay, reverb, distortion)
- Pros:
  - First-party platform support, strong latency/performance.
  - Same AVFAudio concepts on macOS and iOS/iPadOS.
  - Easiest long-term App Store alignment.
- Cons:
  - Less out-of-box high-level synth tooling than third-party ecosystems.

### Option B: Apple-native + AudioKit (fast prototyping)

- Core pieces:
  - `AVAudioEngine` under the hood plus AudioKit and optionally SoundpipeAudioKit modules.
- Pros:
  - Faster instrument/effect prototyping.
  - Good Swift ergonomics and examples.
  - Still aligned with Apple platforms.
- Cons:
  - Additional dependency layer to maintain.

### Option C: Cross-platform C++ engine (JUCE-centric)

- Core pieces:
  - JUCE app/audio framework with C++ DSP graph.
- Pros:
  - Strong if desktop/mobile and plugin products are future priorities.
  - Powerful DSP and plugin-host ecosystem.
- Cons:
  - Heavier engineering overhead for this personal v1.
  - SwiftUI-native app integration is less direct.

## Instruments and sound sources: practical options

### Drums

- V1 approach:
  - GM kit playback with per-step velocity/humanization and section-level variation.
  - Two-kit policy only (`Electronic` + `Rock/Power`).
- Later:
  - sample kits and synthesized drum voices can be evaluated post-v1.

### Bass / Leads / Pads / Rhythm / Texture

- V1 approach:
  - Generate MIDI notes per track and render with GM programs (Apple DLS).
  - Use starter pattern libraries plus mutation rules for musical variation.
- Later:
  - optional sample/synth hybrid layer after v1 quality gate.

## Open-source libraries to evaluate

- AudioKit + SoundpipeAudioKit (Swift/Apple platforms)
- Soundpipe (C DSP modules)
- sfizz (SFZ sampler library)
- FluidSynth (SoundFont2/3 synthesizer)
- STK (algorithmic synthesis toolkit)
- JUCE (if broader cross-platform/plugin path is chosen)
- Faust (for generating portable DSP modules)

## Samples and licensing plan

Use only sources with clear redistribution rights for app usage.

- Safe starting strategy:
  - Build an internal starter library from self-created recordings and/or clearly licensed CC0/permissive sources.
  - Maintain a license manifest per audio file (`source`, `license`, `attribution required`, `redistribution allowed`).
- Candidate sources to research further:
  - Freesound (filter to CC0 and compatible CC-BY only)
  - Curated SoundFont/SFZ sets with explicit redistributable licensing

## Sample and instrument candidates (open/CC)

### Strict inclusion filter (Motorik palette only)

- Include only:
  - synth bass, synth lead, synth pad, synth brass, synth strings, synth effects
  - electric/processed guitar for rhythm and lead layers
  - electronic and rock/acoustic drum kits
  - texture/noise/swell layers
- Exclude from v1 library curation:
  - orchestral instrument families (strings/winds/brass as acoustic orchestral sources)
  - world/folk instrument families unless repurposed as texture only

Orchestral libraries (Philharmonia, VCSL, VSCO 2 CE) are not appropriate for Motorik.

### Motorik-appropriate open/CC candidate pool

- FreePats synth/electric families (mostly CC0, some CC-BY entries by bank)
  - Good for: synth bass/lead/pad/brass/strings/effects, electric guitar, electric percussion, acoustic drum kits.
  - Format: SFZ/SF2/WAV/Hydrogen kits depending on bank.
  - Use fit: best all-in-one open source for the exact palette you listed.
- Karoryfer free libraries (project indicates free libraries are CC0 except noted exceptions)
  - Good for: characterful drums and bass instruments suitable for motorik layering.
  - Format: SFZ + WAV.
  - Use fit: strong for drums/bass personality.
- 99Sounds drum collections (royalty-free WAV)
  - Good for: additional electronic/processed drum one-shots.
  - Use fit: supplemental drum layer source (verify per-pack terms before bundling).

### Built-in fallback source (Apple system)

- Apple General MIDI DLS Sound Bank via Apple DLS Music Device (`Apple General MIDI Down-Loadable Sound (DLS) Sound Bank Synthesiser`)
  - Use fit: fallback for rapid prototyping when curated external assets are incomplete.
  - Strength: immediately available, broad coverage across drums/bass/leads/pads.
  - Limitation: less stylistically distinctive than curated Motorik sample sets.

### Motorik-focused picks to prioritize first

- Drums
  - FreePats `Electric and Synthesizer Percussion` (CC0): vintage-electronic motor pulse foundation.
  - FreePats `Acoustic Drum Kit` (CC-BY 4.0 for the listed MuldjordKit bank): rock/acoustic alternative layer.
  - Karoryfer `Big Rusty Drums` (CC0): character kit option.
- Bass
  - FreePats `Synth Bass` banks (CC0 entries available).
  - FreePats `Clean Electric Bass` (CC0).
  - Karoryfer `Big Little Bass` and `Black And Blue Basses` (CC0).
- Lead 1 / Lead 2
  - FreePats `Synth Lead` banks (CC0 entries available).
  - FreePats `Clean Electric Guitar` (CC0) for guitar-like lead timbre.
- Pads
  - FreePats `Synth Pad` banks (CC0 entries available).
  - FreePats `Synth Strings` banks (CC0 entries available).
- Rhythm
  - FreePats `Clean Electric Guitar` / `Distorted Electric Guitar` families (bank-license dependent).
  - Short synth pulse from FreePats synth banks.
- Texture
  - FreePats `Synth Effects` banks (CC0 entries available).
  - Self-recorded and processed noise/swell layers.

### Useful but with license constraints (treat carefully)

- Freesound
  - Mixed per-file licensing (`CC0`, `CC-BY`, `CC-BY-NC`, and legacy cases).
  - Implication: use only vetted `CC0` (or `CC-BY` if attribution pipeline is implemented). Exclude `NC` and unclear legacy licenses for app redistribution.

## Alternative sample-library strategy (post-v1 reference)

- Drums
  - Primary: FreePats `Electric and Synthesizer Percussion` + one Karoryfer kit.
  - Secondary: selected 99Sounds one-shots for extra kick/snare/hat variants.
- Bass
  - Primary: FreePats `Synth Bass` + Karoryfer electric bass options.
- Lead 1 / Lead 2
  - Primary: FreePats `Synth Lead` plus optional processed electric-guitar layers.
- Pads
  - Primary: FreePats `Synth Pad` + `Synth Strings`.
- Rhythm
  - Primary: FreePats electric guitar family + short synth pulse.
- Texture
  - Primary: FreePats `Synth Effects` + self-recorded noise/swell assets.

## Can we use Logic Pro sounds/loops?

Short answer: yes for creating your own music output; no for redistributing raw Apple sample assets as a sample library.

- Apple states Logic/MainStage sample content is royalty-free for creating your own original soundtracks.
- Apple also states individual sample assets cannot be distributed standalone or repackaged as sample libraries/sound assets.

Implication for Zudio:

- Personal/non-distributed research prototype: using Logic sounds internally is generally workable.
- If you ever ship/distribute Zudio with bundled content: avoid bundling Apple loops/samples as your app's instrument library; use your own/CC0/permissive assets instead.

## Asset-governance checklist (before import)

1. Verify license text on the source page and snapshot the URL/date.
2. Record every asset in a manifest: `asset_id`, `source_url`, `license`, `attribution_required`, `redistribution_allowed`.
3. Reject any asset with `NC`, unclear origin, or \"no redistribution/as-is\" conflict for bundled instrument use.
4. If `CC-BY` is used, generate attribution output automatically in-app and in docs.
5. Keep raw third-party files in a separate provenance folder for auditing.

## Engine design research tasks (post-v1 / contingency)

1. Build a tiny spike app with `AVAudioEngine` that plays 7 track lanes concurrently.
2. Measure latency, CPU, and glitch behavior at 128/256/512 buffer settings.
3. Validate deterministic seed replay across at least 50 generated runs.
4. Prototype optional future instrument paths:
   - sample clip scheduling
   - simple synth voice generation
5. Evaluate one third-party add-on path:
   - AudioKit-only extension path (first)
   - optional sfizz/FluidSynth integration if sampler flexibility is needed

## Decisions status (resolved for v1)

- Engine approach: Apple-native (`AVAudioEngine`) only.
- Sound direction: Apple DLS / General MIDI only for v1.
- Style scope: Motorik only in v1.
- Effects/evolution scope: excluded from functional v1 behavior (effects shown as disabled placeholders).
- Seed/session recall: excluded from v1 UI.
- iOS/iPad scope: architecture portability only; no v1 delivery target.
- Licensing posture: `CC0 + CC-BY` with attribution tracking for any external assets.

## Portability guidance (Mac -> iPhone/iPad)

To avoid engine rewrite later:

- Keep audio core in platform-shared Swift module.
- Keep style/probability rules pure-data and platform-agnostic.
- Isolate UI from audio engine API via a small command/state interface.
- Avoid macOS-only APIs in the synthesis/scheduling core.

## AVAudioEngine vs AudioKit for Motorik (focused research)

Question: can `AVAudioEngine` alone produce credible Motorik songs (in the spirit of tracks like `Hallogallo` and `Fur Immer`) or is AudioKit required in v1?

### Motorik requirements and coverage

- Timing and loop scheduling
  - Need: tight repeated pulse, deterministic loop handoff, sample/segment scheduling.
  - `AVAudioEngine` coverage: yes via `AVAudioPlayerNode` buffer/file/segment scheduling APIs.
- Sample-based drums and texture events
  - Need: low-latency one-shots and loops, overlapping events, simple kit switching.
  - `AVAudioEngine` coverage: yes via player nodes and sampler units in the engine graph.
- Instrument playback (bass/leads/pads)
  - Need: sampled instruments and/or basic synth-capable voices, MIDI-driven playback.
  - `AVAudioEngine` coverage: yes via `AVAudioUnitSampler` and `AVAudioSequencer` support.
- Effects chain (delay/reverb/distortion/EQ/tone shaping)
  - Need: per-track effect character and style presets.
  - `AVAudioEngine` coverage: yes via built-in `AVAudioUnit` effect nodes and parameter control.
- Real-time generation hooks
  - Need: custom rule-driven events and possible procedural layers.
  - `AVAudioEngine` coverage: yes via node graph plus source/sink node model.

### What AudioKit adds

- Faster high-level instrument/effect prototyping in Swift.
- Readymade ecosystem modules (for example DunneAudioKit sampler/synth/delay effects).
- More cookbook-style examples for music-app patterns.

### What AudioKit does not change fundamentally

- It still sits in the same Apple audio ecosystem and typically uses `AVAudioEngine` concepts underneath.
- It is mostly a productivity layer, not a strict capability prerequisite for Motorik v1.

### Risks to track

- `AVAudioUnitSampler` edge-case reports exist in Apple forums for some advanced sample-zone packaging strategies; avoid monolith-zone complexity in v1 and prefer straightforward per-sample/per-zone layouts first.
- If synthesis depth or sound-design velocity becomes a bottleneck, add AudioKit selectively rather than replacing the engine.

### Recommendation

- Start v1 with `AVAudioEngine`-first implementation.
- Keep an adapter boundary so AudioKit modules can be introduced per track later without redesign.
- Default path: defer AudioKit to post-v1.
- Exception path: add AudioKit during v1 only if early spikes show a hard blocker:
  - slow sound-design iteration, or
  - missing instrument/effect quality relative to target.

### Decision checkpoint for v1

- Proceed with `AVAudioEngine` only for first spike.
- Re-evaluate after 2 technical spikes:
  - 7-lane playback + effect-chain stability test
  - instrument-quality A/B test (native-only vs AudioKit-assisted patch)

## Sources

- Apple AVAudioEngine docs: https://developer.apple.com/documentation/avfaudio/avaudioengine
- Apple Audio and music overview: https://developer.apple.com/documentation/technologyoverviews/audio-and-music
- AVAudioPlayerNode (scheduling): https://developer.apple.com/documentation/avfaudio/avaudioplayernode
- AVAudioUnitSampler: https://developer.apple.com/documentation/avfaudio/avaudiounitsampler
- AVAudioSequencer: https://developer.apple.com/documentation/avfaudio/avaudiosequencer
- AVAudioSourceNode: https://developer.apple.com/documentation/avfaudio/avaudiosourcenode
- AVAudioUnitDelay: https://developer.apple.com/documentation/avfaudio/avaudiounitdelay
- AVAudioUnitReverb: https://developer.apple.com/documentation/avfaudio/avaudiounitreverb
- AVAudioUnitDistortion: https://developer.apple.com/documentation/avfaudio/avaudiounitdistortion
- AudioKit: https://github.com/AudioKit/AudioKit
- SoundpipeAudioKit: https://github.com/AudioKit/SoundpipeAudioKit
- DunneAudioKit: https://github.com/AudioKit/DunneAudioKit
- JUCE features: https://juce.com/juce/features/
- sfizz: https://github.com/sfztools/sfizz
- FluidSynth: https://www.fluidsynth.org/
- FluidSynth GitHub: https://github.com/FluidSynth/fluidsynth
- STK: https://github.com/thestk/stk
- Faust: https://github.com/grame-cncm/faust
- Soundpipe: https://github.com/PaulBatchelor/Soundpipe
- Freesound licensing FAQ: https://freesound.org/help/faq/
- Freesound licenses overview: https://freesound.org/help/faq/#licenses
- FreePats homepage: https://freepats.zenvoid.org/
- FreePats synth bass category: https://freepats.zenvoid.org/Synth_Bass/
- FreePats synth lead category: https://freepats.zenvoid.org/Synth_Lead/
- FreePats synth pad category: https://freepats.zenvoid.org/Synth_Pad/
- FreePats synth strings category: https://freepats.zenvoid.org/Synth_Strings/
- FreePats synth brass category: https://freepats.zenvoid.org/Synth_Brass/
- FreePats synth effects category: https://freepats.zenvoid.org/Synth_Effects/
- FreePats electric/synth percussion: https://freepats.zenvoid.org/Percussion/electric-percussion.html
- FreePats acoustic drum kit page (license details): https://freepats.zenvoid.org/Drums/acoustic-drum-kit.html
- FreePats clean electric guitar category: https://freepats.zenvoid.org/Clean_Electric_Guitar/
- FreePats distorted electric guitar category: https://freepats.zenvoid.org/Distorted_Electric_Guitar/
- Karoryfer samples (CC0 announcement and library links): https://www.karoryfer.com/karoryfer-samples
- Big Rusty Drums: https://www.karoryfer.com/karoryfer-samples/big-rusty-drums
- Gogodze Phu Vol II: https://www.karoryfer.com/karoryfer-samples/gogodze-phu-vol-ii
- FreePats license matrix: https://freepats.zenvoid.org/SoundSets/general-midi.html
- 99Sounds (royalty free sample packs): https://99sounds.org/
- Apple Developer Forums sampler edge-case example: https://developer.apple.com/forums/thread/776291
