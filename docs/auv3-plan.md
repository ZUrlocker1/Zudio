# Zudio AUv3 MIDI Generator — Plan
Copyright (c) 2026 Zack Urlocker

## Distribution

The AUv3 plugin is included with the existing Zudio purchase — not a separate product, not an upsell, not an in-app purchase. Existing customers get it automatically via an app update. It is a "pro" capability in the sense that it targets users who work in a DAW, but there is no paywall or tier separation.

---

## Overview

AUv3 (Audio Unit v3) is Apple's plugin standard for iOS/macOS. A **MIDI generator** AUv3 sits in a host app (Logic, GarageBand, AUM, Cubasis) and outputs MIDI events that the host routes to its own instruments. The plugin has no audio output of its own — it just sends notes.

The API is **unified across Mac and iOS/iPadOS** — the same Swift code runs on both. The only platform difference is the UI layer: `NSViewController` on Mac, `UIViewController` on iOS. Since Zudio already uses `#if os(macOS)` splits throughout, this is a familiar pattern.

The work is **moderate in scope** — roughly 3–4 weeks of focused effort. The generation code is already well-separated and does not need to change. The main work is infrastructure: a shared Framework, an App Extension target, and a playback/sync layer that ties Zudio's pre-generated sequences to the host's transport.

---

## What an AUv3 MIDI Generator Is

An AUv3 lives in an **App Extension** — a separate binary bundled inside the container app. The extension declares itself as an Audio Unit in its `Info.plist`. The host discovers it via the system's Audio Unit registry and loads it in-process.

For MIDI output the plugin uses `AUMIDIOutputEventBlock` — a callback it calls to push MIDI events to the host. The host routes those events to whatever instrument track the user has configured.

The AU type for a MIDI generator is `kAudioUnitType_MIDIProcessor`. Despite the name, it can generate MIDI without receiving any input — the input bus can be left empty.

---

## Host Sync

This is the most important architectural question for Zudio. The host provides:

- **`AUHostMusicalContextBlock`** — current tempo, time signature, current beat position
- **`AUHostTransportStateBlock`** — whether the transport is playing, recording, or in cycle mode

Zudio pre-generates entire songs. The playback approach for the AU:

- On "Generate", compute the full MIDI sequence as normal
- On each render cycle (called by the host approximately every 10ms), walk the sequence and emit any events whose song-position falls within the current render window
- Sync to host transport: map host beat position → Zudio step index, emit events accordingly

This is closer to a MIDI file player than a real-time generator. The host calls `internalRenderBlock` continuously; the AU calculates which notes should fire in the current render slice and calls `outputEventBlock` for each one.

---

## Required Work

### 1. Shared Framework target

The generation code (`MusicalFrameGenerator`, `BassGenerator`, all generators) and models (`SongState`, `Types`, `SeededRNG`) need to move into a shared Framework that both the main app and the AU extension can link against. Currently they live in the app target only.

This is mechanical — create `ZudioCore.framework`, move the ~25 generation and model files into it, fix imports. No logic changes required.

### 2. App Extension target

Create a new **Audio Unit Extension** target in Xcode (Xcode has a built-in template). It generates:

- `ZudioAU.swift` — the `AUAudioUnit` subclass
- `ZudioAUViewController.swift` — the plugin UI
- `Info.plist` with the AU component descriptor

The component descriptor declares the AU identity:

- Type: `aumi` (`kAudioUnitType_MIDIProcessor`)
- Subtype: four-char code, e.g. `zdmg`
- Manufacturer: four-char code, e.g. `Zrlo`

### 3. AUAudioUnit subclass

Key methods to implement:

```swift
// Called by host on every render cycle — runs on audio thread, no alloc, no ARC
override var internalRenderBlock: AUInternalRenderBlock { ... }

// Declare MIDI output bus
override var midiOutputNames: [String] { ["Zudio MIDI Out"] }

// Host provides these blocks at load time
var musicalContextBlock: AUHostMusicalContextBlock?
var transportStateBlock: AUHostTransportStateBlock?

// State save/restore for presets
override var fullState: [String: Any]? { get set }
```

The render block must be real-time safe — no Swift ARC, no allocation. The standard pattern is to pre-compute the event list on the main thread and hand it to the render thread via a lock-free queue or simple double-buffer.

### 4. Sequencer layer

A thin layer that takes a `SongState` (with its pre-generated `[MIDIEvent]` arrays) and, given a host beat position and render window size, emits the right events. Zudio's `MIDIEvent` struct maps directly to `AUMIDIEvent`:

```swift
outputEventBlock(AUEventSampleTime, channel, eventType, data, dataSize)
```

**MIDI channel mapping: 7 separate channels.** This is decided — not an open question. Each track outputs on its own channel so the host user can route each to a different instrument:

- Lead 1 → ch 1
- Lead 2 → ch 2
- Pads → ch 3
- Rhythm → ch 4
- Texture → ch 5
- Bass → ch 6
- Drums → ch 10 (GM standard)

Single-channel output would collapse the entire arrangement into one instrument, destroying the multi-track value of the plugin. The sequencer layer must be designed for 7 channels from the start.

### 5. Plugin UI (AUViewControllerBase)

The plugin view is a `UIViewController` / `NSViewController` subclass. For Zudio the controls are minimal:

- Style picker (Ambient / Chill / Kosmic / Motorik)
- Generate button
- Seed display
- Tempo mode toggle: use host tempo vs Zudio's own tempo

The view communicates with the AU via `AUParameterTree` for simple values, or a shared state object for the song state. The UI runs on the main thread; the render block runs on the audio thread — they must not share mutable state directly.

### 6. Entitlements

- Extension needs `com.apple.security.app-sandbox: true`
- macOS additionally needs `com.apple.security.temporary-exception.audio-unit-host: true`
- Container app declares it hosts the extension in its own entitlements

---

## Mac vs iPad/iOS Differences

- API: identical on both platforms — same `AUAudioUnit`, same `AUMIDIOutputEventBlock`
- UI base class: `NSViewController` on macOS, `UIViewController` on iOS
- Host apps on macOS: Logic Pro, GarageBand for Mac, MainStage, AUM
- Host apps on iOS/iPadOS: GarageBand, AUM, Cubasis, BeatMaker 3
- Sandbox rules are stricter on iOS; macOS needs the audio-unit-host exception entitlement
- **Catalyst does NOT support AUv3** — this is not a concern since Zudio has a native Mac target

---

## What Does Not Need to Change

- All generation code — unchanged, just moves to the Framework
- `SongState`, `SeededRNG`, `MIDIEvent` — unchanged
- The main app's `AVAudioEngine` playback — completely untouched

The AU is purely a MIDI source. Sounds come from whatever instrument the host places on the receiving track. Zudio's own synth engine is irrelevant to the plugin.

---

## Biggest Risks

**Real-time render block**
Swift on the audio thread is tricky. The render block cannot allocate memory or touch ARC-managed objects. The event scheduling layer needs a pre-allocated structure — likely a ring buffer of pre-serialized MIDI bytes — that the main thread writes and the audio thread reads without locking.

**Host tempo sync**
If the user changes host tempo mid-song, Zudio's step grid (generated at a fixed BPM) needs to remap. Simplest approach: regenerate on tempo change with the new BPM as `tempoOverride`, or lock to Zudio's internal tempo and ignore host tempo after generation. The second is simpler but less integrated.

**App Store / notarization**
AU extensions have stricter sandbox rules on macOS. Worth validating early with `auval -v aumi Zrlo zdmg` before any App Store submission work.

---

## What Is Still Missing / Not Decided

- Whether to support **MIDI input** (e.g. a MIDI note triggers "generate new song") — would make the plugin more useful in hosts that route MIDI to plugins
- **Preset system** — AUv3 has a built-in preset mechanism via `fullState`; Zudio's existing `.zudio` save format could map to this
- **Per-track mute/solo** from within the plugin UI — useful but optional
- **Loop mode** — whether the generated song loops automatically at the end or stops
- **Host tempo follow vs internal tempo lock** — recommend: follow host tempo, regenerate when BPM changes by more than a threshold (e.g. ±5 BPM). Simpler than mid-song step-grid remapping. Decide before Phase 3.
- **Mac-only first release vs Mac+iOS simultaneous** — shipping Mac first halves the test matrix for the initial release. iOS can follow in a point update.

---

## Development Phases

The work is structured in six phases. Each phase ends with a testable gate — the next phase does not start until that gate passes. Any phase can pause without stranding unfinished work.

---

### Phase 0 — Pre-work: ZudioCore.framework extraction

**This is required before any AUv3 code is written.** Every phase that follows depends on the generation and model code being in a shared framework that both the app target and the extension target can link against.

**What changes:**
- Create `ZudioCore.framework` target in Xcode (Mac + iOS, both platforms)
- Move ~25 generation and model files: all generators, `SongState`, `MIDIEvent`, `SeededRNG`, `Types`, `MusicalFrameGenerator`, and all sub-generators
- Fix access control — everything the extension needs must be `public`; internal helpers stay `internal`
- Add `import ZudioCore` to the main app wherever the moved files were used

**Pre-extraction audit (do this first):**
- Check every generator file for any import of `AppState`, `PlaybackEngine`, or any UI type — those are blockers that need to be removed before the file can move
- Check for any use of `UserDefaults`, `Bundle.main`, or `UIKit`/`AppKit` inside generators — same problem
- There should be none, but verify before starting

**This is its own standalone PR — no other changes.**

**Tests:**
- All 4 styles generate correctly after extraction (Ambient, Chill, Kosmic, Motorik)
- Both Mac and iOS targets build without errors or warnings
- Existing unit tests pass unchanged
- Generate 5 songs per style and confirm titles, structures, and bar counts are identical to pre-extraction output (use a fixed seed to compare)
- Build the stub extension target (do-nothing, no AU logic) and confirm it links against `ZudioCore` without errors

**Estimated time: 3–5 days. Do not underestimate this.**

---

### Phase 1 — Extension registers and loads in a host

**Goal:** The plugin appears in Logic Pro's and GarageBand's AU browser and loads without crashing. No generation, no MIDI output yet.

**What gets built:**
- Fill out `ZudioAU.swift` — the `AUAudioUnit` subclass skeleton
- Declare the MIDI output bus (`midiOutputNames`)
- Implement `internalRenderBlock` as a no-op (returns `noErr`, emits nothing)
- Fill in the component descriptor in `Info.plist`: type `aumi`, subtype `zdmg`, manufacturer `Zrlo`
- Get entitlements right on both Mac and iOS — this always takes longer than expected
  - Extension: `com.apple.security.app-sandbox: true`
  - macOS: `com.apple.security.temporary-exception.audio-unit-host: true`
  - Container app: declares it hosts the extension

**Tests:**
- `auval -v aumi Zrlo zdmg` passes with no errors — run this first, before opening any host
- Plugin appears in Logic Pro's Audio Unit browser under Instruments → MIDI
- Plugin loads in Logic without crashing the host process
- Plugin loads in GarageBand Mac (different host, different loading path)
- Plugin unloads cleanly when the host track is deleted
- Open and close the plugin window 10 times — no memory leaks or crashes
- On iOS: plugin appears in GarageBand for iPad's instrument selector

**Estimated time: 2–3 days, mostly entitlement configuration.**

---

### Phase 2 — Generate → static MIDI playback (no host sync)

**Goal:** Press Generate in the plugin UI, get a pre-generated song, hear notes firing correctly on 7 MIDI channels when the host plays. Uses a fixed internal beat counter — ignores host transport position for now.

**What gets built:**

- **Sequencer layer:** A pre-allocated flat C struct array holding all MIDI events for the current song, sorted by tick position. Written on the main thread at generation time. Read-only on the audio thread during playback.
  - Each entry: `{ uint32_t tickOffset; uint8_t channel; uint8_t status; uint8_t data1; uint8_t data2; }`
  - The main thread serializes from `SongState.trackEvents` into this buffer after generation
  - The render block walks the array with a simple index pointer — no allocation, no ARC, no locking beyond an atomic pointer swap for the double-buffer

- **Double-buffer swap:** Main thread writes into buffer A, then atomically swaps a pointer so the render thread picks up buffer B on the next cycle (the previous buffer A). Standard pattern; safe without a lock.

- **Render block:** On each host render call, read the current beat position from `musicalContextBlock`, compute the render window in ticks, advance the event pointer, fire matching events via `outputEventBlock` on the correct channel (1–6, 10 for drums).

- **Plugin UI (minimal):** Style picker, Generate button, seed display. No tempo control yet.

- **Channel assignment** (as decided above):
  - Lead 1 → ch 1, Lead 2 → ch 2, Pads → ch 3, Rhythm → ch 4, Texture → ch 5, Bass → ch 6, Drums → ch 10

**Tests:**
- Generate a Motorik song. Route all 7 MIDI channels in Logic to separate software instruments (e.g. drums → EXS24 kit, bass → Moog patch). Hit play. Hear the full arrangement on all 7 channels.
- Generate a Chill song. Confirm the blues variation fires notes on the correct channels.
- Generate an Ambient song. Confirm the texture track (ch 5) and pads (ch 3) are present and distinct.
- Stop and start the host transport 10 times — no duplicate note-ons, no stuck notes (all notes-off fire correctly on transport stop).
- Generate a new song while the host is playing — confirm the double-buffer swap happens cleanly with no glitch or dropped notes.
- Confirm no notes fire on channels other than 1, 2, 3, 4, 5, 6, 10.
- Run under Logic's AU sandbox with validation enabled — no crashes.

**Estimated time: 4–5 days. The real-time render block is the hardest code problem in the entire project.**

---

### Phase 3 — Host transport sync

**Goal:** Plugin follows the host's play position, tempo, loop points, and transport state correctly. This is the hardest integration problem.

**What gets built:**
- Read `musicalContextBlock` on every render cycle for current beat position and tempo
- Map host beat position → Zudio tick index (beat × stepsPerBeat, accounting for the song's BPM)
- Respond to transport start: reset the event pointer to the correct position
- Respond to transport stop: send all-notes-off on all 7 channels
- Respond to loop/cycle mode: when the host wraps back to the loop start point, reset the event pointer and re-fire from the beginning
- Respond to scrub backward: detect beat position moving backward, reset pointer accordingly
- Handle "host starts mid-bar": skip events whose tick position is already in the past
- Tempo follow: if host BPM differs from the generated song's BPM by more than ±5 BPM, trigger a regeneration with `tempoOverride` set to the new BPM. Show a brief "Regenerating…" state in the plugin UI.

**Tests:**
- Set a Logic cycle region shorter than the full song (e.g. 8 bars). Hit play. Confirm the plugin loops the first 8 bars correctly without note doubling or silence.
- Start the host mid-song (bar 20 of a 48-bar song). Confirm notes fire from bar 20, not from bar 1.
- Scrub backward in Logic's timeline. Confirm the plugin resets cleanly and no stuck notes remain.
- Change host tempo from 110 to 130 BPM while playing. Confirm regeneration fires and the new song plays at 130 BPM.
- Play for a full song length, confirm the plugin stops (or loops, per the loop mode setting) at the end rather than continuing to fire stale events.
- Test with Logic's "count-in" feature active — confirm no early notes fire during the count-in bars.
- On iPad: repeat the loop and scrub tests in GarageBand for iPad.

**Estimated time: 3–4 days plus host-specific edge case debugging.**

---

### Phase 4 — Plugin UI polish and preset system

**Goal:** Plugin UI is complete and usable. Presets save and restore correctly.

**What gets built:**
- Tempo mode toggle in UI: "Use host tempo" vs "Use Zudio tempo"
- Loop mode toggle: loop song at end vs stop
- Per-track mute buttons (optional — add if time allows; useful for users who want, e.g., drums-only or bass+drums)
- `fullState` implementation for AUv3 preset save/restore — maps to seed + style + instrumentOverrides
- Factory presets: one preset per style (Ambient, Chill, Kosmic, Motorik) with a representative seed

**Tests:**
- Save a preset in Logic. Close Logic. Reopen. Confirm the preset restores the correct style, seed, and instrument choices.
- Load a factory preset. Confirm generation produces the expected style.
- Toggle loop mode on. Confirm the song loops. Toggle off. Confirm it stops.
- Toggle per-track mutes (if implemented). Confirm muted channels produce no MIDI output.
- Resize the plugin window (if the UI supports it). Confirm layout adapts correctly on both Mac and iPad.
- Test preset save/restore in GarageBand (different preset handling from Logic).

**Estimated time: 2–3 days.**

---

### Phase 5 — Multi-host hardening and release

**Goal:** Works reliably in Logic, GarageBand, AUM on Mac, and GarageBand + AUM on iPad. App Store submission ready.

**What to do:**
- Test in AUM (iOS) — different transport model, different MIDI routing
- Test in Cubasis (iPad) if accessible
- Fix any host-specific edge cases found in testing
- App Store sandbox validation — run `codesign --verify` and `spctl --assess` on the extension binary
- Final `auval` pass after all additions
- Update README and App Store description to mention the AUv3 plugin

**Tests:**
- Full smoke test in every target host: Logic Pro, GarageBand Mac, GarageBand iPad, AUM iOS
- `auval -v aumi Zrlo zdmg` passes on a clean machine that has never run the plugin before
- Install via App Store sandbox build (TestFlight for iOS, notarized DMG for Mac) — confirm the plugin registers correctly without a developer-signed build
- Generate 20 songs across all 4 styles in each host, confirm no crashes or stuck notes
- Leave the plugin loaded in Logic for 30 minutes of continuous playback — no memory growth, no crashes

**Estimated time: 3–5 days, variable depending on host-specific issues found.**

---

## Revised Timeline

Phase 0: 3–5 days (framework extraction — prerequisite, standalone)
Phase 1: 2–3 days (extension loads in host)
Phase 2: 4–5 days (generate → 7-channel MIDI playback)
Phase 3: 3–4 days (host transport sync)
Phase 4: 2–3 days (UI polish, presets)
Phase 5: 3–5 days (multi-host hardening)

**Total: 5–7 weeks.** The plan's original 3–5 week estimate is optimistic. Each phase above has a clear test gate and can pause without stranding work in progress.

---

## Difficulty Assessment

**This is a hard project — the hardest in the current roadmap.** Three problems stack on top of each other, each capable of consuming a week independently:

**Real-time render block.** The `internalRenderBlock` runs on the audio thread, which forbids Swift ARC, memory allocation, and any locking. The lock-free queue (or double-buffer) between the main thread and the audio thread is the kind of code that passes unit tests and then deadlocks intermittently under Logic's actual scheduling. This is a different category of problem from anything else in the Zudio codebase.

**Framework extraction.** Moving ~25 generator and model files into `ZudioCore.framework` is mechanically straightforward until it isn't. Import cycles, missing type visibility between targets, and build configuration drift are all real time sinks. Any generator file with an implicit dependency on something that doesn't belong in the framework causes a cascade of build errors to unravel.

**Multi-host DAW testing.** `auval` is strict and fails for non-obvious reasons. Logic Pro, GarageBand, and AUM behave differently as hosts. iPad adds a second test surface. Bugs that only reproduce in a specific host/transport-state combination (e.g. the host loops, or scrubs backward, or starts mid-bar) are slow to isolate and reproduce.

**Open decisions mid-implementation.** The unresolved items (MIDI input, preset system, loop mode, per-track mute/solo) will get answered during implementation rather than before it, and some answers will require rework of already-written code.

**Realistic timeline: 5–7 weeks** using the phased approach above. The original 3–5 week estimate assumed the framework extraction was trivial and that multi-host testing would be quick — neither is reliable. Compare to a new substyle (~1 week) or the reverb bus refactor (~4–6 days). This project is best approached as a standalone sprint with no other music generation work in parallel. The phased structure means each phase ships something testable, so the project can pause between phases without losing progress.
