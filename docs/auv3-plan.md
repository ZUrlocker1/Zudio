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

**MIDI channel mapping decision:** output all 7 tracks as separate MIDI channels (Lead1=ch1, Lead2=ch2, Pads=ch3, Rhythm=ch4, Texture=ch5, Bass=ch6, Drums=ch10), or collapse to a single channel. Multi-channel is more flexible — the host user routes each channel to a different instrument.

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
