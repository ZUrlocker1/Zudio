# Export Audio — Implementation Notes

## Overview

Export the current song to an M4A audio file in the Downloads folder, capturing the fully-rendered
output of all 7 tracks with all effects (reverb, EQ, delay, compression, filters, LFOs).

A confirmation dialog shows the expected duration before export begins. A progress overlay tracks
capture in real time. A Cancel button stops capture and keeps the partial file. No playback resumes
after export.

---

## Format: M4A at 128 kbps AAC

128 kbps AAC is perceptually equivalent to ~192 kbps MP3. A 4-minute song ≈ 3.8 MB.

File named `Zudio-{SongName}.m4a` in Downloads. If that file already exists, appends `-2`, `-3`,
etc. (e.g., `Zudio-NightDrift-2.m4a`). Song names are sanitized: alphanumeric, spaces (converted
to dashes), and dashes/underscores only.

Same naming convention applies to MIDI export (`Zudio-{SongName}.MID`).

Format comparison:
- WAV — lossless but ~90 MB for a 4-minute song. Impractical.
- MP3 — no Apple-native encoder in AVFoundation. Would require third-party LAME. Skip.
- M4A (AAC) — recommended. Native Apple support, small files, good quality.

---

## Approach: Real-time tap capture (NOT offline rendering)

### Why offline rendering was rejected

The original plan used `AVAudioEngine.enableManualRenderingMode(.offline, ...)`. This was
implemented and produced severe clicking and stuttering artifacts in both the exported file
and subsequent live playback. Root causes:

**MIDI timing quantization.** `AVAudioUnitSampler.startNote()` queues MIDI messages that are
consumed at the start of the next `renderOffline()` chunk (4096 frames ≈ 93 ms). All notes
that should begin anywhere within a 93 ms window fire simultaneously at the chunk boundary.
The instantaneous onset of many notes produces an audible click. This is a fundamental
limitation of the AUSampler API in offline mode — there is no mechanism for sub-chunk MIDI
scheduling via `startNote`/`stopNote`.

**LFO timers running concurrently.** Sweep, pan, and tremolo `DispatchSourceTimer`s are not
stopped by `stop()`. They continued firing `DispatchQueue.main.async` parameter updates
(filter cutoff, pan position, volume) during the render loop running in `Task.detached`.
Concurrent writes to audio unit parameters from the main thread while the render thread
consumes them caused unpredictable stuttering.

**Engine state corruption after offline mode.** `disableManualRenderingMode()` followed by
`engine.start()` left the `AVAudioUnitSampler` nodes in a damaged internal state. All
subsequent live playback had the same clicking artifacts until the app was restarted.

### Correct approach: installTap on mainMixerNode

Install a tap on `engine.mainMixerNode` to capture PCM buffers from the live audio graph
while the song plays normally from bar 0:

```swift
mixerNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buf, _ in
    try audioFile.write(from: buf)
    // track progress, stop when totalFrames reached
}
load(state)
play()
```

Advantages:
- Captures exactly what the user hears — samplers, effects, LFOs, reverb tails all included
- Engine lifecycle is never disturbed — no stop/restart, no mode switches
- No MIDI timing quantization — notes fire from StepScheduler exactly as during normal playback
- All modulation (sweep, pan, tremolo, kosmic fades) captured naturally
- Engine remains fully functional for playback after export

Disadvantage: export runs at real-time speed (a 4-minute song takes 4 minutes to export).

### Reverb tail

An extra 2.5 seconds is appended beyond `totalBars × 16 × secondsPerStep` to capture reverb
decay after the last note. The `onSongEnd()` path calls `allNotesOff()` (CC120) which silences
the samplers, but the reverb units continue decaying — the tap captures this decay.

---

## UX Flow

1. User presses **E** / **⌘E** / "Export Audio" button
2. Confirmation sheet: *"This will play the song and export to an M4A file taking x:xx"*
   — Continue / Cancel
3. Continue → export overlay appears: filename, determinate progress bar (0→100% = music portion),
   Cancel button
4. Export completes → overlay dismisses, playback stops, metadata is written to the file
5. Cancel → tap removed immediately, partial file kept in Downloads, overlay dismisses

---

## Post-export metadata (iTunes tags)

After the tap capture completes, `AVAssetExportSession` with `AVAssetExportPresetPassthrough`
re-containers the M4A file with iTunes metadata — no audio re-encoding occurs:

- Title: song name (from `SongState.title`)
- Artist: "Zudio"
- Genre: style name ("Motorik" or "Kosmic")
- Album art: app icon rendered to 500×500 PNG

The metadata pass is best-effort. If `AVAssetExportSession` fails (e.g., passthrough not
compatible), the original file is left untouched and an error is logged. No retry is attempted.

---

## Cancel behaviour

A `cancelExport()` method on `PlaybackEngine` sets `ExportTapState.done = true`, calls
`removeTap(onBus: 0)`, and calls `stop()`. The `AVAudioFile` is released when the tap closure
is deallocated — `AVAudioFile` finalizes the M4A container properly on deallocation, so the
partial file is a valid (though truncated) M4A. No temp file or rename is needed.

`CancellationError` is passed to the `onComplete` callback so AppState can distinguish cancel
from a real error and skip the metadata pass.

---

## Engine state diagram

```
Idle/playing  →  requestExport()  →  confirmation sheet
                                  →  Cancel: nothing
                                  →  Continue → startExport()
                                             → stop(), seek to bar 0
                                             → installTap on mainMixerNode
                                             → load(state), play()
                                             → progress overlay shown
                                             → [totalFrames + tail captured]
                                             → finishExport(): removeTap, stop()
                                             → addMetadata() (passthrough, no re-encode)
                                             → idle (no resume)
```

---

## Files

- `Sources/Zudio/Playback/PlaybackEngine.swift` — `exportAudio()`, `cancelExport()`,
  `finishExport()`; `ExportTapState` inner class; instance vars `currentExportTap` /
  `currentExportOnComplete`
- `Sources/Zudio/AppState.swift` — `requestExport()`, `startExport()`, `cancelExport()`;
  `showExportConfirmation`, `isExportingAudio`, `audioExportProgress`, `audioExportFilename`
- `Sources/Zudio/Assets/AudioFileExporter.swift` — `nextURL(songName:)`, `sanitizedName()`,
  `addMetadata()`, `appIconPNGData()`
- `Sources/Zudio/Assets/MIDIFileExporter.swift` — `nextFilename(for:in:)` uses same song-name
  convention
- `Sources/Zudio/UI/ContentView.swift` — `ExportConfirmationView` sheet; progress overlay with
  Cancel button
- `Sources/Zudio/UI/TopBarView.swift` — "Export Audio" (E underlined, ⌘E); "Save MIDI"
  (S underlined, ⌘S); help text updated
- `Sources/Zudio/ZudioApp.swift` — File menu: "Export Audio" (⌘E), "Save MIDI" (⌘S)

---

## Verification

1. Generate a song → press E → confirm dialog shows correct duration
2. Press Continue → overlay appears, progress bar advances in real time
3. File appears in Downloads as `Zudio-{SongName}.m4a` when complete
4. Open in Music.app or QuickTime → confirm title, artist "Zudio", genre, album art visible
5. Export a second song with the same name → confirm `-2` suffix appended
6. Export a MIDI file → confirm `Zudio-{SongName}.MID` naming
7. During export, press Cancel → overlay dismisses, partial `.m4a` remains in Downloads
8. After export completes, confirm live playback works normally (engine not damaged)
9. Verify file size for a 4-minute song is approximately 3.8 MB

---
Copyright (c) 2026 Zack Urlocker
