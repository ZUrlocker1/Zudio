# Zudio Reverb Bus — Architecture Plan
Copyright (c) 2026 Zack Urlocker

## Purpose

Strictly CPU optimization for **live playback only**. The goal is to reduce the DSP cost of reverb by replacing 7 independent `AVAudioUnitReverb` instances (one per track) with 2 shared reverb bus instances in `PlaybackEngine`.

**M4A audio export (`OfflineExport.swift`) deliberately uses per-track reverbs** — one `AVAudioUnitReverb` per track with the original per-track presets (e.g. `.largeHall` for Kosmic leads, `.plate` for Ambient drums). This preserves the original wet/dry balance and full per-track spatial character in exported audio. Since offline rendering is not real-time and not CPU-constrained, the performance trade-off is irrelevant for export.

---

## Results (v1.8)

The refactor exceeded pre-implementation estimates:

- **Overall CPU reduction: >50%**
- Without visualizer: **under 10% CPU** (previously ~20%+)
- With visualizer: **generally under 20% CPU** (previously over 35%)

The improvement is consistent across all styles. The visualizer's orb rendering is now the dominant CPU cost at higher loads — the audio thread is no longer the bottleneck.

---

## Why Reverb Is the Target

Zudio's audio graph runs 7 independent reverb units, one per track. Cathedral and Large Hall are the most computationally expensive algorithms Apple's `AVAudioUnitReverb` offers — they maintain long delay lines and diffusion networks that consume CPU on every render cycle regardless of how much signal flows through them.

The `shouldBypassEffect` optimization already applied reduces cost when reverb is off, but the units still exist in the graph. Going from 7 active reverb instances to 1–2 is a roughly 3–6× reduction in reverb DSP cost. If reverb accounts for 20–25% of the audio graph CPU load, this is a real and measurable saving.

---

## The Core Idea

A **reverb bus** replaces per-track reverb units with a shared unit. Each track sends a portion of its signal to the shared bus at a configurable send level. The reverb output mixes back into the master output alongside all the dry tracks. This is standard DAW/console architecture.

**Current per-track chain:**
```
sampler → boost → sweepFilter → delay → comp → lowEQ → reverb → mainMixer
```

**Bus architecture:**
```
sampler → boost → sweepFilter → delay → comp → lowEQ → trackMixer → mainMixer (dry)
                                                              ↓
                                                        sendTap (gain node)
                                                              ↓
                                                        reverbBusMixer → sharedReverb → mainMixer
```

Each track keeps its dry path to the main mixer. The `sendTap` is a simple `AVAudioMixerNode` set to the desired send volume — replacing the per-track `wetDryMix` parameter. Tracks with no reverb have a send level of zero; the `shouldBypassEffect` mechanism becomes unnecessary.

---

## One Bus or Two

**One bus** — everything shares a single reverb space. Maximum CPU saving. The reverb preset becomes global per style (e.g. Cathedral for Ambient, Large Hall for Motorik). Loses the ability to put a lead in a small room while pads sit in a cathedral.

**Two buses** — a "large" bus (Cathedral/Large Hall for pads, texture, bass) and a "small" bus (Medium Hall/Room for leads, rhythm). Still 7→2, saving 5 instances. Preserves spatial differentiation between atmospheric tracks and foreground tracks. Gets ~70% of the maximum CPU reduction with more musical flexibility.

**Recommendation: two buses.** The spatial difference between a lead voice and a pad bed is musically significant in Zudio. Two buses preserves this while delivering most of the gain.

---

## Per-Style Reverb Analysis

This section documents the existing reverb configuration per style, derived from `PlaybackEngine.swift`, to inform bus assignment decisions.

### Chill

Current presets and wet levels (wet level out of 100):

- Lead1: `.mediumHall`, wet 45
- Lead2: `.mediumHall`, wet 40
- Pads: `.mediumHall`, wet 55
- Rhythm: `.mediumHall`, wet 40
- Texture: bypassed entirely — wet 0
- Bass: `.mediumRoom`, wet 35
- Drums: `.mediumHall`, wet 45

**Conclusion: one bus is sufficient for Chill.** Five of six active tracks already share `.mediumHall`. Bass is `.mediumRoom` — a subtle difference that a slightly lower send level on a shared `.mediumHall` bus would cover without any audible regression. Texture sends nothing regardless. No sonic trade-off.

### Ambient

Current presets and wet levels:

- Lead1: `.mediumHall`, wet 65
- Lead2: `.mediumHall`, wet 60
- Pads: `.mediumHall`, wet 72
- Rhythm: `.mediumHall`, wet 50
- Texture: `.largeRoom`, wet 60
- Bass: `.mediumRoom`, wet 45
- Drums: `.plate`, wet 70

**Conclusion: two buses are justified.** Texture at `.largeRoom` and the dominant Lead/Pads/Rhythm cluster at `.mediumHall` benefit from separation — `.largeRoom` on the large bus, `.mediumHall` on the small bus. Bass (`.mediumRoom`) routes to the small bus at a slightly lower send level, same approach as Chill.

**Drums:** Ambient drums use `.plate` in the original per-track design. In live playback they route to the small bus (`.mediumHall`) — the difference is inaudible given how sparse and low-level Ambient drums are. In the M4A export they retain `.plate` via `perTrackReverbPresets`. Resolved.

### Kosmic

Current presets and wet levels:

- Lead1: `.largeHall`, wet 60
- Lead2: `.largeHall`, wet 55
- Pads: `.cathedral`, wet 62
- Texture: `.mediumHall`, wet 55
- Bass: `.largeHall`, wet 45
- Rhythm: `.mediumHall`, wet 50
- Drums: `.mediumHall`, wet 45

Three distinct presets in use, but they split cleanly:
- Large bus (`.cathedral`): Pads, Lead1, Lead2, Bass
- Small bus (`.mediumHall`): Texture, Rhythm, Drums

Note: a previous code bug caused the Bass to swap to `.cathedral` reverb during the intro drone, then back to `.largeHall` for the body. This was unintentional and has been removed — Bass stays on `.largeHall` (large bus) throughout.

For Kosmic the Leads belong on the large bus (they use `.largeHall`, close to cathedral), while Texture belongs on the small bus (`.mediumHall`). The general characterization "large bus = pads/texture/bass, small bus = leads/rhythm" does not hold for all styles — bus assignment must be determined per-style by the actual preset each track uses.

### Motorik

Current presets and wet levels:

- Lead1: `.mediumHall`, wet 55
- Lead2: `.mediumHall`, wet 50
- Pads: `.mediumHall`, wet 50
- Rhythm: `.mediumHall`, wet 45
- Texture: `.mediumHall`, wet 50
- Bass: `.mediumRoom`, wet 40
- Drums: `.mediumHall`, wet 45

**Conclusion: one bus is sufficient for Motorik**, identical situation to Chill. Every track uses `.mediumHall`; Bass uses `.mediumRoom`, handled by a slightly lower send level. No large bus needed.

### Bus assignment summary (proposed)

Bus assignments are per-style, determined by the preset each track currently uses. Chill and Motorik use only the small bus; Ambient and Kosmic use both.

**Ambient**
- Large bus (`.largeRoom`): Texture
- Small bus (`.mediumHall`): Lead1, Lead2, Pads, Rhythm, Bass, Drums (export uses `.plate` for Drums via per-track preset)

**Chill**
- Small bus (`.mediumHall`): Lead1, Lead2, Pads, Rhythm, Bass, Drums
- Texture: zero send (bypassed)
- Large bus: unused

**Kosmic**
- Large bus (`.cathedral`): Pads, Lead1, Lead2, Bass
- Small bus (`.mediumHall`): Texture, Rhythm, Drums

**Motorik**
- Small bus (`.mediumHall`): all tracks
- Large bus: unused

---

## What Changes in the Code

**PlaybackEngine (live playback) — changed:**
- 7 `AVAudioUnitReverb` nodes removed; replaced with 2 shared bus reverbs + 2 bus mixers + 7 per-track `AVAudioMixerNode` send taps
- Post-EQ signal fan-outs: dry path → explicit `mixer` node; wet copy → send mixer → bus mixer → shared reverb → `mixer`
- `setEffect(.reverb/.space)`: sets send tap `outputVolume` to 0 or the stored send level
- Style setup methods (`setAmbientMode`, `setChillMode`, `applyMotorikAudio`, `applyKosmicAudio`): call `connectSend()` per track + `setBusPresets()` per style; also set `perTrackReverbPresets[]` for export
- `applyMuteState()`: also zeroes/restores send mixer volume when a track is muted

**OfflineExport (M4A export) — unchanged:**
- Still uses 7 per-track `AVAudioUnitReverb` nodes, one per active track
- Reads `snap.reverbPreset` (per-track preset from `perTrackReverbPresets[]`) and `snap.reverbWetDryMix` (send level × 100, equivalent to the original wetDryMix)
- Chain: `player → sweep → delay → comp → eq → reverb → mainMixerNode`

---

## What Stays Per-Track

- **Delay** — out of scope; see note below
- **Compressor** — responds to individual track dynamics; bussing destroys its purpose
- **Sweep filter** — per-track gesture by design
- **Low EQ** — per-track tonal shaping; trivially cheap DSP
- **Boost node** — gain node, essentially free CPU

---

## Why Not Delay Too

The same bussing logic technically applies to delay, and 7→1 delay units would save some CPU. However:

- Delay DSP is much cheaper than reverb — the saving is smaller
- Shared delay feedback would cause tracks to bleed into each other's echo, which requires a "send-only, no feedback" bus topology that is more complex to implement correctly
- The musical risk is higher

If the reverb bus delivers the expected CPU reduction, profile again. Only address delay if it registers meaningfully in a follow-up Instruments session.

---

## Musical Trade-offs

**Live playback:** tracks on the same bus share one reverb tail rather than having independent decay. In practice this sounds more cohesive — instruments feel like they exist in the same acoustic space. The two-bus approach (large/small) preserves the most important spatial distinction. Ambient drums move from `.plate` to the small bus (`.mediumHall`); since Ambient drums are sparse and sit low in the mix this is inaudible in context.

**M4A export:** uses the original per-track presets and wet/dry balance throughout. Ambient drums retain `.plate`. Kosmic leads/bass retain `.largeHall`. The exported audio matches the original design intent, not the live playback bus approximation.

---

## Complexity and Risk

**Medium risk.** The AVAudioEngine graph rewiring is the most dangerous step — the graph must be stopped, reconfigured, and restarted; any connection error silences the engine. Areas requiring careful testing:

- Mute/solo must still work correctly through the shared reverb tail
- Per-track effect reset on new song generation
- All style setup methods produce correct send levels
- iOS vs macOS parity (the bypass logic differs slightly today)

The changes to `setEffect`, `restoreDefaultEffects`, and the style setup methods are straightforward once the graph wiring is validated.

---

## Recommended Approach

Implement the two-bus reverb architecture as a **standalone refactor** — reverb only, no other effects touched. Profile with Instruments Time Profiler before and after. The expected result is a meaningful reduction in the `com.apple.audio.IOThread.client` load seen in the earlier profiling session.

---

## Difficulty Assessment

**This is a relatively easy, well-isolated project — the most approachable refactor in the current roadmap.** Realistic timeline: **4–6 days** including testing and CPU profiling.

**Why it's contained.** The change touches `PlaybackEngine.swift` as the primary file, plus parallel changes in the export audio graphs (`AudioFileExporter.swift`, `OfflineExport.swift`). No generator code changes. No new musical rules. No new UI. No cross-platform divergence beyond what already exists.

**The one genuinely risky step** is the AVAudioEngine graph rewire — the engine must be stopped, nodes removed and added, and connections re-established before restarting. A bad connection silences the engine entirely. However, failure is immediate and obvious (no audio at all), not a subtle regression that takes days to isolate. There is no category of "it mostly works but sometimes glitches" — it either wires correctly or it doesn't.

**Testing is methodical, not open-ended.** The checklist is finite: mute/solo through the shared reverb tail, per-track effect reset, all four style setup methods, iOS parity, one listening test for Ambient drums, before/after CPU profile. No musical tuning iteration required.

**OfflineExport is intentionally not rewired.** It keeps per-track reverbs for audio quality reasons — see Purpose section.

---

## Implementation Plan

### Phase 0 — Pre-work: Analysis (no code changes, ~1 day)

**0a. Map the complete PlaybackEngine audio graph**
Read `setupAudioGraph()` and write down every node and every `engine.connect()` call. Confirm the per-track chain is exactly:
```
samplers[i] → boosts[i] → sweepFilters[i] → delays[i] → comps[i] → lowEQs[i] → reverbs[i] → mainMixerNode
```
Confirm whether `mainMixerNode` is Apple's implicit engine mixer or an explicit node. This matters because bus outputs must connect to the same mixer.

**0b. Decide OfflineExport strategy before writing a line of code**
`OfflineExport.swift` builds a separate offline `AVAudioEngine` per M4A render. It reads a `TrackSnapshot` struct (captured in `PlaybackEngine.swift` around line 1231–1282) that includes `reverbPreset: AVAudioUnitReverbPreset` and `reverbWetDryMix: Float` per track, and builds a per-track reverb chain offline. Since offline rendering is not CPU-constrained, **keep OfflineExport per-track** — do not rewire it. Instead update the snapshot capture so it populates `reverbPreset` with the bus preset the track routes to, and `reverbWetDryMix` with a value derived from the send mixer volume. OfflineExport.swift itself does not change.

**0c. Inventory all reverb-touching call sites**
Run these greps before writing any code. Every result is a place that needs updating:
```
grep -n "reverbs\[" PlaybackEngine.swift
grep -n "reverbPresets\[" PlaybackEngine.swift
grep -n "wetDryMix" PlaybackEngine.swift
grep -n "shouldBypassEffect" PlaybackEngine.swift | grep -i reverb
grep -rn "setEffect.*reverb\|reverb.*setEffect" Sources/
grep -rn "restoreDefaultEffects" Sources/
```

**0d. Baseline CPU measurement**
In Instruments on Mac: Time Profiler, generate and play a Kosmic song for 60 seconds, record `com.apple.audio.IOThread.client` percentage. Repeat on iPhone. Save screenshots. These are the "before" numbers. Target: 10–18% total audio thread CPU reduction.

---

### Phase 1 — PlaybackEngine Graph Rewire (~2 days)

This is the only genuinely risky step. Wrap it in a feature branch.

**1a. New node declarations — add to PlaybackEngine**
```swift
private var reverbBusLarge  = AVAudioUnitReverb()   // Cathedral / LargeHall / LargeRoom
private var reverbBusSmall  = AVAudioUnitReverb()   // MediumHall / MediumRoom
private var reverbBusMixerLarge = AVAudioMixerNode()
private var reverbBusMixerSmall = AVAudioMixerNode()
private var reverbSendMixers = [AVAudioMixerNode]() // one per track, replaces reverbs[i].wetDryMix
private var reverbSendLevels = Array(repeating: Float(0), count: kTrackCount) // persisted send level per track
```
Keep the `reverbs` array alive during Phase 1 so you can compare old/new behaviour; delete in Phase 3.

**1b. setupAudioGraph() — new connection pattern**
For each track `i`, replace:
```swift
engine.connect(lowEQs[i], to: reverbs[i], format: fmt)
engine.connect(reverbs[i], to: mainMixer, format: fmt)
```
With:
```swift
// Dry path (unchanged tap before reverb)
engine.connect(lowEQs[i], to: mainMixer, format: fmt)
// Wet send path
engine.connect(lowEQs[i], to: reverbSendMixers[i], format: fmt)
// Send mixers route into bus mixers (bus assignment done in style methods)
// reverbSendMixers[i] → reverbBusMixerLarge or reverbBusMixerSmall (connected per style)
```
Bus output to main mixer:
```swift
engine.connect(reverbBusLarge,       to: mainMixer, format: fmt)
engine.connect(reverbBusSmall,       to: mainMixer, format: fmt)
engine.connect(reverbBusMixerLarge,  to: reverbBusLarge, format: fmt)
engine.connect(reverbBusMixerSmall,  to: reverbBusSmall, format: fmt)
```
Note: each `reverbSendMixers[i]` connects to ONE of the two bus mixers depending on style assignment. Bus assignment connections must be made at style-switch time (see 1c) not at graph-setup time, since the same track routes differently for Kosmic vs Chill.

**Mute/solo interaction — critical**: the `reverbSendMixers[i].outputVolume` must be zeroed when the track is muted, not just the dry sampler output. Otherwise a muted track continues to feed reverb. Audit `setMuteState()` and `setSoloState()` — these methods must also zero/restore `reverbSendMixers[i].outputVolume`. The current `muteState` array can drive this: when `muteState[i] = true`, set `reverbSendMixers[i].outputVolume = 0`; when false, restore `reverbSendLevels[i]`.

**1c. Style setup methods — send levels replace wetDryMix**

Per-track send levels (0.0–1.0, roughly equivalent to the previous wetDryMix / 100). Exact values should be tuned by ear against the existing sound, but these are starting points derived from the current wetDryMix values:

**Ambient:**
```swift
// Large bus (LargeRoom): Texture only
reverbBusLarge.loadFactoryPreset(.largeRoom)
connectSend(kTrackTexture, to: .large, level: 0.60)

// Small bus (MediumHall): all others
reverbBusSmall.loadFactoryPreset(.mediumHall)
connectSend(kTrackLead1,   to: .small, level: 0.65)
connectSend(kTrackLead2,   to: .small, level: 0.60)
connectSend(kTrackPads,    to: .small, level: 0.72)
connectSend(kTrackRhythm,  to: .small, level: 0.50)
connectSend(kTrackBass,    to: .small, level: 0.40)   // was .mediumRoom at 45
connectSend(kTrackDrums,   to: .small, level: 0.55)   // was .plate at 70 — needs listening test
```

**Chill:**
```swift
reverbBusSmall.loadFactoryPreset(.mediumHall)
connectSend(kTrackLead1,   to: .small, level: 0.45)
connectSend(kTrackLead2,   to: .small, level: 0.40)
connectSend(kTrackPads,    to: .small, level: 0.55)
connectSend(kTrackRhythm,  to: .small, level: 0.40)
connectSend(kTrackBass,    to: .small, level: 0.30)   // was .mediumRoom at 35
connectSend(kTrackDrums,   to: .small, level: 0.45)
connectSend(kTrackTexture, to: .small, level: 0.0)    // bypassed — zero send
```

**Kosmic:**
```swift
// Large bus (Cathedral): Pads, Leads, Bass, LeadSynth
reverbBusLarge.loadFactoryPreset(.cathedral)
connectSend(kTrackPads,      to: .large, level: 0.62)
connectSend(kTrackLead1,     to: .large, level: 0.60)
connectSend(kTrackLead2,     to: .large, level: 0.55)
connectSend(kTrackBass,      to: .large, level: 0.45)
connectSend(kTrackLeadSynth, to: .large, level: 0.00) // doubles Lead 1; currently runs dry

// Small bus (MediumHall): Texture, Rhythm, Drums
reverbBusSmall.loadFactoryPreset(.mediumHall)
connectSend(kTrackTexture, to: .small, level: 0.55)
connectSend(kTrackRhythm,  to: .small, level: 0.50)
connectSend(kTrackDrums,   to: .small, level: 0.45)
```

**Motorik:**
```swift
reverbBusSmall.loadFactoryPreset(.mediumHall)
connectSend(kTrackLead1,   to: .small, level: 0.55)
connectSend(kTrackLead2,   to: .small, level: 0.50)
connectSend(kTrackPads,    to: .small, level: 0.50)
connectSend(kTrackRhythm,  to: .small, level: 0.45)
connectSend(kTrackTexture, to: .small, level: 0.50)
connectSend(kTrackBass,    to: .small, level: 0.35)   // was .mediumRoom at 40
connectSend(kTrackDrums,   to: .small, level: 0.45)
```

Helper to implement (`connectSend` is a private method):
```swift
private enum ReverbBus { case large, small }
private func connectSend(_ trackIndex: Int, to bus: ReverbBus, level: Float) {
    let busMixer = bus == .large ? reverbBusMixerLarge : reverbBusMixerSmall
    engine.disconnectNodeOutput(reverbSendMixers[trackIndex])
    engine.connect(reverbSendMixers[trackIndex], to: busMixer, format: nil)
    reverbSendMixers[trackIndex].outputVolume = level
    reverbSendLevels[trackIndex] = level
}
```

**1d. setEffect(.reverb / .space, enabled:, forTrack:)**
`.reverb` and `.space` both write to the same `AVAudioUnitReverb` per track — `.space` just has higher default wet levels and the Ambient Piano Lead1 special case (wet=28). Both collapse to the same one-liner:
```swift
case .reverb, .space:
    reverbSendMixers[trackIndex].outputVolume = enabled ? reverbSendLevels[trackIndex] : 0
```
The Ambient Piano Lead1 wet difference moves to `setAmbientMode`: when `isAmbientPiano`, set `reverbSendLevels[kTrackLead1] = 0.28` instead of 0.65, and connect to the small bus.

The effective "restore defaults" path is `applyDefaultEffects()` in TrackRowView — it calls `setEffect` for every effect on `defaultsResetToken`. Once step 1d is implemented correctly, the restore path works automatically with no separate changes.

Ambient empty-track suppression (lines 1443–1448) returns early for `.reverb`/`.space` on tracks in `emptyTrackSet`. With the bus architecture, returning early leaves `reverbSendMixers[i].outputVolume` at 0 — correct behaviour, no change needed.

**Phase 1 tests:**
- Generate and play one song from each of the 4 styles. Confirm audio is present and sounds correct.
- Toggle reverb chip on/off for each track individually. Confirm send goes to zero and restores.
- Mute each track. Confirm the shared reverb tail does not continue sounding from the muted track.
- Solo each track. Confirm only that track's reverb contribution is heard.
- Switch styles mid-session (Kosmic → Chill → Ambient). Confirm bus presets update.
- Measure CPU in Instruments. Confirm reduction vs Phase 0 baseline.

---

### Phase 2 — Snapshot for OfflineExport

`OfflineExport.swift` keeps its per-track reverb graph unchanged. PlaybackEngine captures a `TrackEffectSnapshot` per track that OfflineExport reads to configure each per-track reverb node:

```swift
reverbPreset:    perTrackReverbPresets[i],   // original per-track preset (largeHall, plate, etc.)
reverbWetDryMix: reverbSendLevels[i] * 100,  // send level × 100 = equivalent wetDryMix
reverbBypassed:  reverbSendLevels[i] == 0,
```

`perTrackReverbPresets[]` is set by each style method alongside the bus sends, preserving the original per-track preset for every track:

- **Ambient:** `.mediumHall` for leads/pads/rhythm, `.largeRoom` for texture, `.mediumRoom` for bass, `.plate` for drums
- **Chill:** `.mediumHall` for leads/pads/rhythm/drums, `.mediumRoom` for bass
- **Motorik:** `.mediumHall` for leads/pads/rhythm/texture/drums, `.mediumRoom` for bass
- **Kosmic:** `.largeHall` for leads/bass/leadSynth, `.cathedral` for pads, `.mediumHall` for texture/rhythm/drums

---

### Phase 3 — Cleanup (completed with Phase 1)

All cleanup was done in the same pass as Phase 1:
- `reverbs: [AVAudioUnitReverb]` array removed entirely
- `reverbPresets: [AVAudioUnitReverbPreset]` array removed
- `shouldBypassEffect` on reverbs removed
- `setChillMode(false)` reverb restore line removed
- iOS build confirmed clean (no platform-specific reverb code)

---

### Expected CPU Gains

**Reverb DSP cost by preset (approximate):**
- Cathedral / LargeHall: highest — long delay lines, dense diffusion. Estimated 40–60% of total reverb CPU.
- MediumHall: roughly 40–60% of Cathedral cost.
- MediumRoom / LargeRoom: similar to MediumHall.

**Before:** 7 reverb instances. For a Kosmic song: 1 Cathedral (Pads), 2 LargeHall (Lead1, Lead2, Bass), 3 MediumHall (Texture, Rhythm, Drums) — all running simultaneously.

**After:** 2 reverb instances — 1 Cathedral bus + 1 MediumHall bus.

**Estimated saving:** 5 fewer instances × average ~30 DSP units = substantial reduction. If reverb accounts for 20–25% of total audio thread CPU (a reasonable estimate for a Kosmic song), and the per-instance reduction is ~70% (5 of 7 removed): **net saving ≈ 14–18% of total audio thread CPU**.

Chill and Motorik savings are smaller (all MediumHall, so less cost per instance) but still real — 6 fewer MediumHall instances → 1 shared. On iPhone where thermal throttling matters, even a 10% reduction in audio thread load translates directly to lower battery drain and fewer dropout risks at high polyphony.

**Most important benchmark:** `com.apple.audio.IOThread.client` in Instruments Time Profiler. Run a 60-second Kosmic song before and after. See Results section at the top of this document for measured outcomes.

---

## Phase 0 Findings

*Research completed 2026-06-01. All line numbers reference PlaybackEngine.swift unless noted.*

### F0a. Audio Graph Confirmed — Two-Level Mixer Architecture

The per-track chain matches the plan, but there are **two levels of mixer**, not one.

**Actual chain:**

```
samplers[i] → boosts[i] → sweepFilters[i] → delays[i] → comps[i] → lowEQs[i] → reverbs[i]
    → mixer  (explicit AVAudioMixerNode, declared line 71, attached line 2208)
    → engine.mainMixerNode  (Apple's implicit hardware mixer)
```

All 8 per-track reverb outputs connect to the explicit `mixer` node (line 2281). The explicit `mixer` connects to `engine.mainMixerNode` (line 2209). Master volume fades (Motorik/Ambient/Kosmic outros) modulate `engine.mainMixerNode.outputVolume` — they reach everything fed into the explicit `mixer`.

**Bus output connections must target the explicit `mixer`, not `engine.mainMixerNode`:**

```swift
engine.connect(reverbBusLarge, to: mixer, format: fmt)
engine.connect(reverbBusSmall, to: mixer, format: fmt)
```

This ensures bus reverb tails are included in master-volume fades at song end, identical to current per-track behaviour. If wired to `engine.mainMixerNode` directly the reverb tails would not fade with the rest of the song.

### F0b. Wet/Dry Mix Source — Inlined as Send Levels

Send levels are inlined as literals directly in each style method's `connectSend()` calls (no separate arrays). Values ordered Lead1 / Lead2 / Pads / Rhythm / Texture / Bass / Drums / LeadSynth:

- Ambient: `0.65, 0.60, 0.72, 0.50, 0.60, 0.45, 0.70, 0`
- Chill: `0.45, 0.40, 0.55, 0.40, 0, 0.35, 0.40, 0`
- Motorik: `0.55, 0.50, 0.50, 0.45, 0.50, 0.40, 0.45, 0.55`
- Kosmic: `0.60, 0.55, 0.62, 0.45 (large), 0.55, 0.50, 0.45 (small), 0`

**Ambient Piano override:** `connectSend(kTrackLead1, to: .small, level: 0.28)` called after the general Ambient setup.

### F0c. Reverb Reset Locations — 3 Sites

`for rev in reverbs { rev.reset() }` appears in three places. After the refactor, each becomes `reverbBusLarge.reset(); reverbBusSmall.reset()`:

- Line 554: `stopSchedulerOnly()`
- Line 1119: `startAmbientOutroFade()`
- Line 1993: `onSongEnd()`

### F0d. OfflineExport — Per-Track by Design

OfflineExport.swift uses per-track `AVAudioUnitReverb` nodes intentionally. The bus architecture produces a drier sound than the original wetDryMix model — audible on Ambient and Kosmic where reverb levels are 60–72%. Since export is not CPU-constrained, per-track reverbs are correct.

Each track's reverb is configured from `TrackEffectSnapshot`:
- `snap.reverbPreset` — original per-track preset from `perTrackReverbPresets[]` in PlaybackEngine
- `snap.reverbWetDryMix` — send level × 100, equivalent to the original wetDryMix
- Chain: `player → sweep → delay → comp → eq → reverb → fxEngine.mainMixerNode`

### F0e. Mute/Solo — Sampler Only; Reverb Bus Needs Explicit Zero

`applyMuteState()` (line 2348) zeroes `samplers[i].volume` when muted. Reverb nodes currently stay active and process silence (cheap but non-zero cost). After the bus refactor, a muted track whose send mixer is still open would continue to feed the shared bus, leaking that track's reverb tail. The mute/solo handler must also set `reverbSendMixers[i].outputVolume = 0` when muting and restore `reverbSendLevels[i]` when unmuting.

### F0f. shouldBypassEffect Elimination

PlaybackEngine dual-sets `shouldBypassEffect = !enabled` and `wetDryMix = 0` together in `setEffect(.reverb)` (lines 1504–1505). OfflineExport reads only `wetDryMix` (line 214). The bus architecture eliminates `shouldBypassEffect` entirely — bypass becomes `reverbSendMixers[i].outputVolume = 0`. Clean and unambiguous.

### F0g. iOS Parity

No iOS-specific reverb handling anywhere in PlaybackEngine. No `#if os(iOS)` blocks near any reverb code. Phase 1 should build and behave identically on both platforms with no platform-specific work.

### F0h. Complete Call Site Inventory

All reverb-touching lines in PlaybackEngine:

**Declarations:**
- Line 70: `private var reverbs = [AVAudioUnitReverb]()`
- Line 108: `private var reverbPresets = ...`

**Graph setup (setupEngine):**
- Lines 2218, 2261–2264: instantiation, preset, wetDryMix=0, bypass=true
- Line 2280: `engine.connect(lowEQs[i], to: reverbs[i])`
- Line 2281: `engine.connect(reverbs[i], to: mixer)` ← target is the explicit `mixer`, not mainMixerNode

**Style configuration:**
- Lines 1302–1327: `setAmbientMode` (including Ambient Piano Lead1 override at 1322–1327)
- Lines 1357–1367: `setChillMode`
- Lines 1391–1395: `applyMotorikAudio`
- Lines 1410–1416: `applyKosmicAudio`

**Effect toggle:**
- Lines 1498–1514: `setEffect(.reverb)` / `setEffect(.space)` — both cases set bypass and wetDryMix

**Snapshot capture:**
- Lines 1275–1276: `reverbWetDryMix` and `reverbBypassed` (update in Phase 2)

**Reset:**
- Lines 554, 1119, 1993: `for rev in reverbs { rev.reset() }`

Total: **14 distinct call sites** across 6 categories. All update in Phase 1 except lines 1275–1276 (Phase 2).
