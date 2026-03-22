# Save as Audio — Plan

## Overview

Export the current song to an M4A audio file in the Downloads folder, capturing the fully-rendered
output of all 7 tracks with all effects (reverb, EQ, delay, compression, filters).

UX mirrors Logic Pro: stop playback, show a modal progress sheet, render offline (faster than
real-time), dismiss when done. No resume of playback after export.

---

## Format: M4A at 128 kbps AAC

128 kbps AAC is perceptually equivalent to ~192 kbps MP3 (AAC is more efficient).
A 4-minute song ≈ 3.8 MB. File named `Zudio-NNNN-MM-DD-YYYY.m4a` in Downloads,
same numbering scheme as MIDI export.

Single settings dict change to go higher/lower quality later: just change `AVEncoderBitRateKey`.

Format comparison:
- WAV — lossless, simplest, but ~90 MB for a 4-minute song. Impractical for storage/sharing.
- MP3 — Apple provides no MP3 encoder in AVFoundation. Would need LAME (third-party). Skip.
- M4A (AAC) — recommended. Native Apple support. AVAudioFile handles PCM→AAC internally. 3.8 MB/song.

---

## Approach: Offline rendering

`AVAudioEngine.enableManualRenderingMode(.offline, format:maximumFrameCount:)` puts the engine
into offline mode — no hardware I/O, no real-time constraint. Frames are pushed on demand and
the entire effects chain renders synchronously. Expected speed: 3–8× faster than real-time
(reverb is the heaviest unit; 7 reverbs in the chain may limit gains).

This works with the existing architecture because all MIDIEvent data already exists as pre-generated
sorted arrays of `(stepIndex, note, velocity, durationSteps)`. We convert stepIndex →
AVAudioFramePosition once, then drive a render loop — no StepScheduler or DispatchSourceTimer needed.

---

## Implementation

### Step 1 — Pre-convert events to frame timeline

```swift
struct FrameEvent {
    let frame: AVAudioFramePosition
    let trackIndex: Int
    let note: UInt8
    let velocity: UInt8
    let isNoteOn: Bool
}
```

For each `MIDIEvent` in each track, emit two `FrameEvent`s:
- NoteOn at `stepIndex × framesPerStep`
- NoteOff at `(stepIndex + durationSteps) × framesPerStep`

where `framesPerStep = sampleRate × secondsPerStep` (both known from `SongState.frame`).
Sort the full list by `frame`.

### Step 2 — Switch engine to offline mode

```swift
let format = engine.mainMixerNode.outputFormat(forBus: 0)
try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
try engine.start()
```

Requires engine stopped first. After export: `engine.disableManualRenderingMode()` + `engine.stop()`
to return to normal.

### Step 3 — Render loop (background Task)

```swift
let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
var eventIdx = 0
var currentFrame: AVAudioFramePosition = 0

while currentFrame < totalFrames {
    let chunkEnd = currentFrame + 4096

    // Fire all events in this chunk window
    while eventIdx < frameEvents.count && frameEvents[eventIdx].frame < chunkEnd {
        let ev = frameEvents[eventIdx]
        if ev.isNoteOn {
            samplers[ev.trackIndex].startNote(ev.note, withVelocity: ev.velocity, onChannel: 0)
        } else {
            samplers[ev.trackIndex].stopNote(ev.note, onChannel: 0)
        }
        eventIdx += 1
    }

    let framesToRender = AVAudioFrameCount(min(4096, totalFrames - currentFrame))
    try engine.renderOffline(framesToRender, to: outputBuffer)
    try audioFile.write(from: outputBuffer)

    currentFrame += AVAudioFramePosition(framesToRender)
    await MainActor.run { progress = Double(currentFrame) / Double(totalFrames) }
}
```

### Step 4 — AppState orchestration

New properties:
```swift
@Published var isExportingAudio = false
@Published var audioExportProgress: Double = 0   // 0.0 – 1.0
```

New function `exportAudio()`:
1. Guard `songState != nil`
2. Call `stop()` on playback (no resume)
3. Set `isExportingAudio = true`
4. Launch `Task.detached(priority: .userInitiated)` with the render loop
5. On completion: `engine.disableManualRenderingMode()`, set `isExportingAudio = false`

### Step 5 — UI: modal progress sheet

A SwiftUI `.sheet(isPresented: $appState.isExportingAudio)` showing:
- Title: "Exporting Audio…"
- `ProgressView(value: appState.audioExportProgress)` — determinate progress bar
- Subtitle: e.g. "Writing Zudio-0042-03-22-2026.m4a"
- No cancel button (export is fast)

Sheet dismisses automatically when `isExportingAudio` flips to `false`.

---

## Engine state transitions

```
Normal playback  →  exportAudio()
                 →  stop() engine
                 →  enableManualRenderingMode(.offline)
                 →  render loop on background thread
                 →  disableManualRenderingMode()
                 →  idle (no playback resume)
```

---

## Files to Modify / Add

- `Sources/Zudio/Playback/PlaybackEngine.swift` — add `exportAudio(songState:progressHandler:completionHandler:)`; offline render loop; frame event pre-computation
- `Sources/Zudio/AppState.swift` — add `isExportingAudio`, `audioExportProgress`, `exportAudio()`; guard `onSongEnd` to not interfere during export
- `Sources/Zudio/Assets/AudioFileExporter.swift` (new, ~25 lines) — `nextURL()` mirroring MIDIFileExporter, returns `.m4a` path
- `Sources/Zudio/UI/` — add "Save Audio" button + progress sheet

---

## Verification

1. Build clean: `xcodebuild -scheme Zudio -configuration Debug build`
2. Generate a Kosmic song, press Save Audio — confirm modal appears with progressing bar
3. Confirm file appears in Downloads as `Zudio-NNNN-MM-DD-YYYY.m4a` when complete
4. Open in QuickTime — confirm duration, stereo audio, effects (reverb audible)
5. Confirm playback does NOT resume after export
6. Confirm engine returns to normal (can generate and play a new song)
7. Verify file size for a 4-minute song is approximately 3.8 MB
