# Zudio Development Plan (v0.1 to v0.9)

Scope note: effects and evolution mode are out of scope for this first version.
Sound strategy note: start with Apple General MIDI (Apple DLS Music Device), then evaluate sample-based swap at 0.75.

Locked v1 controls:

- `Generate New`
- Global `Play` (green arrow)
- Per-track `Mute` / `Solo`
- Per-track `Regenerate`

Instrument minimum rule for v1:

- GM-first phase: each track has 3-6 candidate instruments/presets to audition.
- Drums in GM-first phase: 5 kit choices (Standard, Room, Power, Electronic, Jazz).
- `0.75` gate decides whether to keep GM sounds or replace selected tracks with sample-based sounds.

Named Motorik sound options (v1):

- Lead 1: `Smooth Analog Lead`, `Saturated Mono Synth Lead`, `Guitar-Like Mono Lead`
- Lead 2: `Bell/Pluck Lead`, `Soft Synth Brass`, `Narrow Pulse Lead`
- Pads: `Smooth Synth Pad`, `Analog Warm Pad`, `Synth Strings Pad`
- Rhythm: `Muted Motorik Guitar Pulse`, `Sequenced Mono Synth Pulse`, `Processed Electric Piano Pulse`
- Texture: `Tape Air Layer`, `Noise Swell Layer`, `Metallic Percussive FX Layer`
- Bass: `Analog Motor Bass`, `Digital/FM Pulse Bass`, `Electric Pick Bass`
- Drums: `Vintage Electronic`, `Rock Kit`

General MIDI-first implementation choices (preferred):

- Lead 1 (5 choices)
  - GM 82 `Saw Wave`
  - GM 87 `5th Saw Wave`
  - GM 88 `Bass & Lead`
  - GM 84 `Chiffer Lead`
  - GM 86 `Solo Vox`
- Lead 2 (5 choices)
  - GM 83 `Syn. Calliope`
  - GM 63 `Synth Brass 1`
  - GM 64 `Synth Brass 2`
  - GM 85 `Charang`
  - GM 88 `Bass & Lead`
- Pads (5 choices)
  - GM 90 `Warm Pad`
  - GM 91 `Polysynth`
  - GM 92 `Choir Pad`
  - GM 95 `Halo Pad`
  - GM 96 `Sweep Pad`
- Rhythm (5 choices)
  - GM 29 `Electric Muted Guitar`
  - GM 28 `Electric Clean Guitar`
  - GM 85 `Charang`
  - GM 91 `Polysynth` (short gate)
  - GM 5 `Electric Piano 1`
- Texture (5 choices)
  - GM 93 `Bowed Glass`
  - GM 94 `Metallic Pad`
  - GM 95 `Halo Pad`
  - GM 89 `New Age Pad`
  - GM 92 `Choir Pad`
- Bass (5 choices)
  - GM 39 `Synth Bass 1`
  - GM 40 `Synth Bass 2`
  - GM 35 `Electric Bass (Pick)`
  - GM 34 `Electric Bass (Finger)`
  - GM 36 `Fretless Bass`
- Drums (5 choices)
  - Kit 0 `Standard`
  - Kit 8 `Room`
  - Kit 16 `Power`
  - Kit 24 `Electronic`
  - Kit 32 `Jazz`
- Drums preferred defaults for Motorik: Kit 24 `Electronic`, Kit 16 `Power`

Instrument cycle control behavior (all tracks):

- Each track has an instrument button next to the instrument label.
- Pressing the button advances to the next instrument in that track's candidate list.
- Cycling wraps from last back to first.
- On change, playback switches immediately (or at next bar boundary if needed for click-free transition).
- UI always shows the current instrument name and GM program/kit value.
- In `Auto`, instrument is chosen by weighted random rule from that same track list.

Core generation user stories (cross-cutting):

- As a user, when I press `Generate New`, the app decides a complete song plan using current global parameters (`Style`, `Pace`, `Key`, `Mood`) plus controlled randomization.
- As a user, the generated song includes structure decisions (section count, section repetition, chord sequence, pattern variation) and then generates notes for each track from that plan.
- As a user, drums are generated as evolving patterns (fills/intensity changes), not a static 4-bar loop.
- As a user, bass, pads, rhythm, lead tracks are generated with repeat-and-variation behavior over time, not rigid copy loops.
- As a user, I can see each generated track as a DAW-style piano-roll/grid lane in the center panel.
- As a user, only a viewport portion of the full timeline is shown at once; resizing or scrolling pans to other timeline regions.
- As a user, each track lane uses the track family color (Lead red, Pads/Rhythm/Texture blue, Bass purple, Drums yellow).
- As a user, if a track is muted its grid lane is greyed.
- As a user, if a track is soloed, non-solo tracks are greyed and only solo-appropriate audio is heard.

Track-onboarding visualization rule (applies at every step):

- Whenever a new track is introduced in a development step, that same step must include:
  - a corresponding MIDI grid lane in the track's assigned color
  - regenerated note visualization on `Generate New`
  - real-time playhead/viewport scrolling behavior during `Play`

General MIDI audition set (optional during 0.4-0.6):

- Guitar family: GM 25 `Nylon`, 26 `Steel`, 27 `Electric Jazz`, 28 `Electric Clean`, 29 `Electric Muted`, 30 `Overdriven`, 31 `Distortion`, 32 `Harmonics`
- Keyboard family: GM 1 `Acoustic Grand`, 2 `Bright Acoustic`, 3 `Electric Grand`, 5 `Electric Piano 1`, 6 `Electric Piano 2`
- Organ family: GM 17 `Drawbar`, 18 `Percussive`, 19 `Rock Organ`, 20 `Church`, 21 `Reed`
- Quality caution: GM guitar and piano realism may be limited; use these primarily for quick functional validation.

- [ ] **0.1 Drums Only**
  - Build: Generate Motorik/APACHE-style drums with global settings (`Style`, `Pace`, `Key`, `Mood`), dynamic intensity over time, and kit choice (`Vintage Electronic`, `Rock Kit`).
  - Test gate: 20 seeds sound recognizably motorik; no static 4-bar copy-loop feel; yellow drum MIDI grid updates correctly on generate/play.
  - User stories:
    - As a user, I can press `Generate New` and hear a full dynamic drum performance in motorik style.
    - As a user, I can press the drum instrument button to cycle kits and hear the change while the track plays.
    - As a user, I can see the active drum kit name in the UI at all times.
    - As a user, I see a yellow drum MIDI grid lane that refreshes to the newly generated notes each time I press `Generate New`.
    - As a user, when I press `Play`, the MIDI grid playhead and viewport scroll in time like a standard DAW.

- [ ] **0.2 Add Bass**
  - Build: Add bass generation that locks to drums, follows pulse/intensity changes, and supports at least 3 synth bass instrument options.
  - Test gate: bass and kick interplay feels coherent in 20 seeds; no frequent rhythmic collisions.
  - User stories:
    - As a user, I hear bass that follows and supports the drum pulse.
    - As a user, I can cycle bass sounds and immediately hear how the same line changes timbre.
    - As a user, I see the selected bass instrument name update after each cycle.

- [ ] **0.3 Add Pads**
  - Build: Add pad chords; enforce shared key with bass; bass follows chord pattern.
  - Test gate: harmonic coherence across full track; no out-of-key bass notes.
  - User stories:
    - As a user, pads establish the chord bed and the bass remains harmonically aligned.
    - As a user, I can cycle pad sounds to test warmth/brightness without changing harmony.

- [ ] **0.4 Add Rhythm Track**
  - Build: Add rhythm ostinato lane (muted guitar pulse / synth sequence), tightly aligned with drums+bass, with at least 3 rhythm instrument options.
  - Test gate: stronger forward motion without clutter; rhythm does not mask bass/pad space.
  - User stories:
    - As a user, rhythm adds motion and locks with drums+bass.
    - As a user, I can cycle rhythm instruments (muted guitar/synth/keys) to compare groove character quickly.

- [ ] **0.5 Add Lead 1**
  - Build: Add melodic motif generator for Lead 1 with controlled density and phrase variation, with at least 3 Lead 1 instrument options.
  - Test gate: melodies feel musical but restrained; Lead 1 does not overpower groove.
  - User stories:
    - As a user, Lead 1 adds recognizable melodic motifs without overcrowding the mix.
    - As a user, I can cycle through lead timbres and keep the same motif structure for comparison.

- [ ] **0.6 Add Lead 2**
  - Build: Add Lead 2 counterline with delayed entry (bar 8 or 16 randomized by rule), lower density than Lead 1, and at least 3 Lead 2 instrument options.
  - Test gate: complementary interaction with Lead 1; no persistent unison clutter.
  - User stories:
    - As a user, Lead 2 enters later and complements Lead 1 rather than competing with it.
    - As a user, I can cycle Lead 2 sounds independently of Lead 1 to test layering choices.

- [ ] **0.7 Add Texture**
  - Build: Add texture events (swells/noise/transition accents) with sparse placement and at least 3 texture instrument options.
  - Test gate: arrangement feels more alive without adding harmonic clutter.
  - User stories:
    - As a user, texture events make transitions feel evolving while staying subtle.
    - As a user, I can cycle texture sounds and hear ambient character changes without breaking groove.

- [ ] **0.75 MIDI vs Sample Decision Gate**
  - Build: run A/B comparison between Apple DLS General MIDI implementation and a starter sample-based layer for key tracks.
  - Test gate: decide whether to keep GM sounds for v1 or swap to sample-based sounds for `0.8+` based on musical quality, consistency, and implementation speed.
  - Specific check: if GM guitar/piano timbres reduce perceived quality, prioritize sample-based replacement for Rhythm/Lead lanes first.
  - User stories:
    - As a user, I can compare the same generated song with GM sounds vs sample-based sounds.
    - As a team, we can choose track-by-track whether to keep GM or switch to samples for v1.

- [ ] **0.8 Full Generate + UI Cohesion**
  - Build: One-button full-song generation for all tracks, track-level regenerate, M/S, instrument selection, compact per-row piano roll.
  - Test gate: workflow is fast and stable; each track updates correctly and independently.
  - User stories:
    - As a user, I can generate a full song with one click and play it immediately.
    - As a user, I can mute/solo tracks and regenerate a single track without losing the rest.
    - As a user, I can cycle instruments per track and always see which instrument is active.
    - As a user, I see per-track piano-roll lanes with color coding, viewport panning behavior, and correct mute/solo grey-state visuals.

- [ ] **0.9 Stabilize and Tune**
  - Build: lock probabilities/ranges, improve determinism, performance tuning, preset polishing, and regression tests.
  - Test gate: same seed reproduces same song; CPU/glitch targets met; Motorik coherence pass rate is acceptable.
  - User stories:
    - As a user, I can return to a seed and hear the same musical result.
    - As a user, playback remains stable while switching instruments and muting/soloing tracks.

- [ ] **1.1 Add Evolution Mode (post-1.0)**
  - Build: add continuous playback evolution where the current song morphs into successor states using probabilistic mutation rules, while `Generate` still creates fully new songs.
  - Test gate: transitions are seamless, no hard-loop feel, and long sessions avoid obvious repetition while maintaining musical coherence.
