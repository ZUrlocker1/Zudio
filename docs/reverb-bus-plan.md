# Zudio Reverb Bus — Architecture Plan
Copyright (c) 2026 Zack Urlocker

## Purpose

Strictly CPU optimization. The goal is to reduce the DSP cost of reverb by replacing 7 independent `AVAudioUnitReverb` instances (one per track) with 1–2 shared reverb bus instances. Delay and other effects are out of scope for this refactor.

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

**Drums are the one open question.** Ambient drums currently use `.plate`, which has a brighter, denser character than either bus preset. However, Ambient drums sit in the background and are sparse — the `.plate` character is not load-bearing in the way it would be for a prominent kit. The practical trade-off is acceptable. **Needs a listening test to confirm whether drums sound better on the large bus or the small bus** — both are reasonable candidates.

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
- Small bus (`.mediumHall`): Lead1, Lead2, Pads, Rhythm, Bass, Drums (pending listening test for Drums — see Musical Trade-offs)

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

- **`PlaybackEngine` setup**: remove 7 `AVAudioUnitReverb` nodes; add 2 shared reverb nodes + 7 `AVAudioMixerNode` send taps; rewire the graph connections
- **`setEffect(.reverb)`**: set send tap output volume to 0 or the configured send level instead of toggling `shouldBypassEffect` on a per-track reverb
- **Style setup methods** (`setAmbientMode`, `setChillMode`, `setKosmicMode`, `setMotorikMode`): configure per-track send levels instead of per-track wet/dry mixes
- **`restoreDefaultEffects(forTrack:)`**: restore send level instead of wet/dry mix
- **Chill and Motorik Texture track**: always zero send level — same intent as the existing bypass, simpler to express

The reverb preset (Cathedral vs Large Hall) is set once per bus rather than once per track — a simplification.

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

The main sonic change is that tracks on the same bus share one reverb tail rather than having independent decay. In practice this tends to sound more cohesive — instruments feel like they exist in the same acoustic space. The two-bus approach (large/small) preserves the most important spatial distinction without requiring per-track reverb instances.

The largest individual trade-off is Ambient drums moving off `.plate` reverb. Since Ambient drums are sparse and sit low in the mix, this is expected to be inaudible in context — but should be confirmed by ear before shipping. See the Per-Style Reverb Analysis section for the listening test note.

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

**The only pre-start check:** read `AudioFileExporter.swift` and `OfflineExport.swift` before coding to confirm whether their audio graphs mirror `PlaybackEngine`'s wiring or differ. If they differ, that is a second rewire pass — still straightforward, just needs to be scoped correctly at the start rather than discovered mid-way.
