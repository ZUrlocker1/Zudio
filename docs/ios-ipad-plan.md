# iOS/iPadOS Port Plan

## Platform View Inventory

Current shipped state as of v1.0. For visualizer details see [visualizer-plan.md](visualizer-plan.md).

### macOS

- **TopBarView** — transport, style, key, BPM, mood, compact toggle
- **MIDI Tracks view** — 7 track rows, song info + zoom row, scrollbar strip (default view)
- **Visualizer** (⌘Z) — swaps in place of tracks; gestures control mute/solo/effects
- **StatusBoxView** — generation log, always visible below tracks or visualizer
- No tab strip; Visualizer / Tracks is a toggle via ⌘Z or the TopBarView button

### iPad

- **TopBarView** — unchanged from Mac (transport, style, key, BPM, mood)
- **Song info row** — title, mood/key/BPM/length/bar chips, zoom slider — pinned below TopBarView, visible in all tabs
- **Bottom tab strip** (36 pt, always visible) — four tabs:
  - **Visuals** (default at launch) — VisualizerView fills body area
  - **Log** — StatusBoxView full height
  - **Tracks** — full MIDI grid: 7 track rows + scrollbar + StatusBoxView (layout unchanged from Mac)
  - **Songs** — `generationHistory` list, newest first; tap to load and play
- **Scrollbar row** — bar position strip pinned above tab strip
- iPad mini landscape: generation log hidden on the Tracks tab when `contentWidth` is 900–1150 pt

### iPhone

- **PhonePlayerView** — full-screen player, no MIDI grid, no track controls
- **Controls** (portrait: stacked column; landscape: left panel ~210 pt wide):
  - Header — "Zudio" logo + current song title
  - Transport — ⏮ ◀ ⏹/▶ ▶ ⏭  
    (⏮ navigates the Songs list in Song mode; haptic warning if already at the first song)
  - Mode selector — Song / Evolve / Endless
  - Style picker — Ambient / Chill / Kosmic / Motorik
  - Export Audio button
- **Bottom tab strip** — two tabs:
  - **Visuals** (default) — VisualizerView
  - **Log** — StatusBoxView with Reset button (red text); tapping Reset also returns to Visuals tab
- No Tracks tab — MIDI grid not shown on iPhone
- Song navigation is via the ⏮/⏭ transport buttons

---

## What Already Works on iOS

The majority of Zudio's code is pure Swift and required no changes:

- **PlaybackEngine.swift** — `AVAudioEngine`, `AVAudioUnitSampler`, `AVAudioMixerNode`, `AVAudioUnitReverb`, `AVAudioUnitDelay` are all available on iOS 14+. The step scheduler, LFO timers, and soundfont loading all work unchanged. The GS User soundfont (~30 MB) is well within memory limits on all supported devices.
- **All Generation files** — pure Swift algorithms, zero platform dependencies
- **All Model files** — pure Swift data structures
- **MIDILaneView.swift** — SwiftUI Canvas, fully iOS-compatible
- **StatusBoxView.swift** — pure SwiftUI, fully iOS-compatible

---

## AppKit Dependencies Removed

Four files imported AppKit and required targeted fixes.

### ZudioApp.swift
- `NSApp.activate(ignoringOtherApps: true)` — wrapped in `#if os(macOS)`
- `NSImage` dock icon setter — wrapped in `#if os(macOS)` (macOS-only by definition)

### AppState.swift
All NSApp/NSEvent/NSSound/NSWorkspace call sites moved behind the `ZudioPlatformHost` protocol (see Shared Code Strategy). Specifically:
- `NSEvent.addLocalMonitorForEvents` keyboard monitor
- `NSApp.activate(ignoringOtherApps: true)` in `play()` and `stop()`
- `NSOpenPanel` file picker
- `NSSound.beep()` error sound
- `NSWorkspace.shared.activateFileViewerSelecting` post-export reveal
- `NSApp.keyWindow?.makeFirstResponder(nil)` for BPM field dismissal — replaced with `@FocusState`

### FirstMouseFix.swift
Entire file wrapped in `#if os(macOS)`. The macOS window-focus workaround is irrelevant on iOS (every touch goes directly to the hit view). The `.background(FirstMouseFix())` usage in TopBarView is likewise guarded.

### TopBarView.swift
- `NSColor.selectedControlColor`, `NSColor.controlColor`, `NSColor.separatorColor` — replaced with SwiftUI `Color` equivalents using `#if os(macOS)` conditionals
- `NSImage` logo loading — replaced with asset-catalog `Image("zudio-logo")` (cross-platform)

---

## Platform Target Configuration

### Package.swift
```swift
platforms: [.macOS(.v14), .iOS(.v16), .iPadOS(.v16)]
```

iOS 16 is the minimum for the full modern SwiftUI API surface (`presentationDetents`, `.scrollDismissesKeyboard`, etc.). iPhone-specific features use iOS 17+ (`sensoryFeedback` for haptics); iOS 17 covers ~95%+ of active iPhones as of 2026.

### Xcode project.pbxproj
iOS and iPadOS deployment targets added. `Info.plist` includes `UISupportedInterfaceOrientations` allowing all four orientations on iPad and portrait + landscape on iPhone.

### App Icon
The `.icns` format is macOS-only. An `AppIcon.appiconset` in the asset catalog provides the required iOS sizes: 60×60@2x, 60×60@3x (iPhone), 76×76@1x, 76×76@2x (iPad), 83.5×83.5@2x (iPad Pro), 1024×1024 (App Store).

---

## File Export on iOS

iOS has no shared filesystem — each app is sandboxed with no `~/Downloads` folder.

### Output Path
Both `MIDIFileExporter.swift` and `AudioFileExporter.swift` use a platform conditional:

```swift
#if os(macOS)
let baseURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
#else
let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
#endif
```

Files written to `.documentDirectory` appear in Files → On My iPhone/iPad → Zudio when the Info.plist keys below are set.

### Share Sheet
After a file is written on iOS, a `UIActivityViewController` presents immediately:

```swift
#if os(iOS)
let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
#endif
```

This gives the user immediate options: save to Files, AirDrop to Mac, open in GarageBand, share via Mail/Messages. GarageBand recognises both `.mid` and `.m4a` as import targets.

### Info.plist Keys Required
- `UIFileSharingEnabled = YES` — exposes the app's Documents folder in Files
- `LSSupportsOpeningDocumentsInPlace = YES` — allows other apps to open files directly from Zudio's folder
- `UIBackgroundModes = [audio]` — allows playback to continue when the user switches apps. Required for a music app; without it, AVAudioEngine stops the moment Zudio leaves the foreground. Must be paired with the `.playback` AVAudioSession category (set in `IOSPlatformHost.configureAudioSession()`).

---

## iPad Layout Details

`contentWidth` (measured by the root GeometryReader) is the sole branching variable for layout tiers within the Tracks tab.

### Tested Device Widths at Runtime
- iPad mini portrait — 744 pt
- iPad 11" / Air portrait — 820–834 pt
- iPad mini landscape — 1133 pt
- iPad Pro landscape — 1194 pt (also covers macOS at ≥1150 pt)

### Portrait Adjustments (contentWidth < 900)
- Logo moves from the left of the transport row into the transport VStack, stacked above the buttons
- Version text is hidden below 900 pt to save space
- TrackRowView left panel narrows: 220 pt (mini portrait) or 222 pt (11"/Air portrait)
- On mini portrait (< 800 pt), the right effects panel is given an explicit 232 pt frame to prevent it being squeezed; on 11"/Air portrait (800–900 pt) it sizes naturally with adjusted padding
- StatusBoxView minimum height reduces to 44 pt on mini portrait

### iPad Mini Landscape (900–1150 pt)
Treated as a separate tier: left panel widens to 242 pt, buttons use `.small` control size. Generation log hidden on the Tracks tab (not enough vertical room for 7 tracks + log).

### Landscape / Wide (contentWidth ≥ 1150)
Uses the same layout as macOS. No structural differences.

---

## Shared Code Strategy — ZudioPlatformHost

`AppState.swift` contains macOS-specific API calls in its transport, keyboard, file, and audio methods. Rather than scattering `#if os(macOS)` throughout, AppState delegates all platform behavior through a protocol. The concrete implementations live in the platform-specific targets.

```swift
protocol ZudioPlatformHost: AnyObject {
    func activateApp()
    func showOpenPanel(completion: @escaping (URL?) -> Void)
    func playErrorSound()
    func registerKeyboardShortcuts(target: AppState)
    func revealOrShareFile(url: URL)
    func configureAudioSession()
}
```

AppState declares `weak var platformHost: ZudioPlatformHost?`. The macOS app injects `MacPlatformHost()` at startup; the iOS app injects `IOSPlatformHost()`.

**What each method does per platform:**
- `activateApp()` — Mac: `NSApp.activate(ignoringOtherApps: true)`. iOS: no-op.
- `showOpenPanel(completion:)` — Mac: `NSOpenPanel`. iOS: `UIDocumentPickerViewController`.
- `playErrorSound()` — Mac: `NSSound.beep()`. iOS: `UINotificationFeedbackGenerator(.error)`.
- `registerKeyboardShortcuts(target:)` — Mac: `NSEvent.addLocalMonitorForEvents`. iOS: `UIKeyCommand` (iPad with hardware keyboard).
- `revealOrShareFile(url:)` — Mac: `NSWorkspace.shared.activateFileViewerSelecting`. iOS: `UIActivityViewController`.
- `configureAudioSession()` — Mac: no-op. iOS: AVAudioSession category, activation, and interruption observer.

---

## Audio Session Configuration (iOS)

On iOS, `AVAudioSession` must be configured explicitly. Handled by `IOSPlatformHost.configureAudioSession()`:

```swift
try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
try AVAudioSession.sharedInstance().setActive(true)
```

The session can be interrupted (phone call, Siri, etc.). `IOSPlatformHost` also sets up an observer for `AVAudioSession.interruptionNotification` to pause playback on interruption and resume when it ends. The macOS conformer (`MacPlatformHost`) is a no-op for this method.

---

## Touch Interaction Notes

Existing interactions that are touch-compatible without changes:
- **HoldRepeater** (bar scrubbing) — uses `DragGesture`, touch-compatible
- **Drag-to-seek in MIDILane** — uses `DragGesture`, touch-compatible
- **Transport button press highlights** — `@GestureState` with `DragGesture`, works on touch
- **BPM text field + stepper** — Stepper control has large touch areas, works on iOS
- **Keyboard shortcuts** — `.keyboardShortcut` modifiers work on iOS 15+ with a hardware keyboard; keep them for iPad Pro/Air users

Touch targets that need attention on iPad Tracks tab:
- **Mute/Solo toggle chips** (22×18 pt) — Apple HIG minimum is 44×44 pt; add `.contentShape` padding to reach minimum without changing visual size
- **Effect chips** (44×20 pt) — too narrow for reliable touch; need 44×44 pt tappable area
- **Instrument arrow buttons** (◀ ▶) — add padding to increase tap target to 44×44 pt

A significant proportion of iPad Pro/Air users use a hardware keyboard. Do not remove keyboard shortcuts or hotkey indicators on button labels when running on iPad.

---

## iPad Multitasking

iPadOS supports Split View and Slide Over — the app window can be as narrow as 320 pt. The compact-width layout must handle this. At 320 pt minimum viable functionality is: Generate + Play/Stop transport, track list with name + mute/solo (MIDI lane very narrow or hidden), status log hidden.

---

## Haptic Feedback (iPhone)

Uses SwiftUI `.sensoryFeedback` (iOS 17+) attached to `@State` triggers, keeping haptic logic out of gesture handlers. No haptics on iPad or Mac.

For canvas gesture haptics (tap orb, double-tap, long-press) see [visualizer-plan.md](visualizer-plan.md).

**Transport button haptics:**
- Play — `.impact(weight: .medium)`
- Stop — `.impact(weight: .soft)`
- ⏭ Skip / generate next — `.impact(weight: .medium)`
- ⏮ Previous — `.impact(weight: .light)` (warning haptic if already at first song)
- ◀ ▶ Seek forward/back — `.selection`

**System event haptics:**
- Song generation complete — `.success`
- Export Audio complete — `.success`
- Error / disabled action — `.warning` (e.g. Export when no song loaded)

---

## Files Created / Modified

**New files:**
- `Sources/Zudio/UI/PhonePlayerView.swift`
- `Sources/Zudio/UI/VisualizerView.swift`
- `Sources/Zudio/Platform/ZudioPlatformHost.swift` — protocol, no platform imports
- `Sources/Zudio/Platform/MacPlatformHost.swift` — macOS conformer, imports AppKit
- `Sources/ZudioiOS/Platform/IOSPlatformHost.swift` — iOS conformer, imports UIKit + AVFoundation

**Modified:**
- `Sources/Zudio/ZudioApp.swift` — `#if os(macOS)` around NSApp calls
- `Sources/Zudio/AppState.swift` — all platform calls behind `ZudioPlatformHost`; `@FocusState` BPM dismissal; `loadPreviousFromHistory()`; `VisualizerNote` population in `onStep`
- `Sources/Zudio/Models/Types.swift` — `VisualizerNote` struct
- `Sources/Zudio/Playback/PlaybackEngine.swift` — `activeVisualizerNotes` publishing
- `Sources/Zudio/UI/ContentView.swift` — iPhone routing check; iPad tab navigation
- `Sources/Zudio/UI/TopBarView.swift` — `#if os(macOS)` for NSColor/NSImage
- `Sources/Zudio/UI/FirstMouseFix.swift` — entire file wrapped in `#if os(macOS)`
- `Sources/Zudio/Assets/MIDIFileExporter.swift` — platform-conditional output path
- `Package.swift` — iOS/iPadOS platforms added
- `Zudio.xcodeproj/project.pbxproj` — iOS deployment target

**No changes needed:**
- All Generation files — pure Swift
- All Model files — pure Swift
- `Sources/Zudio/UI/MIDILaneView.swift` — pure SwiftUI Canvas

---

## Port Sequencing

- **Phase 1** (done) — iOS build compiles; iPad layout working; audio and generation functional
- **Phase 2** (done) — iPad tab navigation (Visuals / Log / Tracks / Songs); iPhone PhonePlayerView; VisualizerView cross-platform
- **Phase 3** (deferred) — macOS visualizer polish; App Store submission
- **Phase 4** (deferred) — optional ZudioCore Swift Package extraction for cleaner Mac+iOS shared codebase

---

## Monetization

Two viable models for the iOS/iPadOS release.

**Option A — Flat paid (~$2.99 upfront)**
- No free tier — pay once to download
- Pros: no StoreKit/IAP infrastructure, no entitlement checks in the codebase, simpler to build and maintain, single clear value proposition
- Cons: higher friction to download, smaller discovery funnel

**Option B — Free with one-time unlock IAP (~$2.99)**
- Free tier: generate and play in one style (Motorik recommended — most immediately recognisable), full MIDI grid and per-track regen, no export
- Paid unlock: audio and MIDI export, remaining styles unlocked
- Pros: zero-friction discovery, users hear the value before paying, natural upsell when they want to keep a song
- Cons: StoreKit integration, entitlement checks at export and style-switch points, sandbox test environment — meaningful extra development time
- Key principle: never limit the number of generations; the generative loop is the core value; only gate export and style access

---
Copyright (c) 2026 Zack Urlocker
