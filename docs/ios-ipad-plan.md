# iOS/iPadOS Port — Research & Design Plan

## Context

Zudio is currently a macOS-only app. This plan covers what is required to make it run on iPhone and iPad. The audio engine and all generation code are already iOS-compatible. The primary work is: isolating AppState's platform-specific behavior behind a `ZudioPlatformHost` protocol, removing remaining AppKit dependencies in UI files with conditional compilation, redesigning the UI for touch and smaller screens, and adapting the file export path. No code is written here.

---

## Part 1: What Already Works on iOS

The good news first — the majority of Zudio's code is pure Swift and requires no changes:

- **PlaybackEngine.swift** — `AVAudioEngine`, `AVAudioUnitSampler`, `AVAudioMixerNode`, `AVAudioUnitReverb`, `AVAudioUnitDelay` are all available on iOS 14+. The step scheduler, LFO timers, and soundfont loading all work unchanged.
- **All Generation files** — pure Swift algorithms, zero platform dependencies
- **All Model files** — pure Swift data structures
- **MIDILaneView.swift** — SwiftUI Canvas, fully iOS-compatible
- **StatusBoxView.swift** — pure SwiftUI, fully iOS-compatible
- **ContentView.swift** (structure) — SwiftUI VStack, works on iOS; only the fixed `minWidth: 900` constraint needs removing

---

## Part 2: AppKit Dependencies to Remove

Four files import AppKit. Each requires a targeted fix.

### ZudioApp.swift
Current Mac-only code:
- `NSApp.activate(ignoringOtherApps: true)` — brings app to foreground on launch
- `NSImage(contentsOf: url)` + `NSApp.applicationIconImage = icon` — sets dock icon

Fix: Wrap in `#if os(macOS)` conditionals. The dock icon setter is macOS-only by definition. The `activate` call is unnecessary on iOS (apps are always in focus when launched).

### AppState.swift
Current Mac-only code:
- `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` — global keyboard monitor for play/stop toggle
- `event.keyCode == 49` (space bar), `event.modifierFlags` inspection
- `NSApp.keyWindow?.makeFirstResponder(nil)` — unfocus BPM text field after editing
- `NSApp.activate(ignoringOtherApps: true)` — called in `play()` and `stop()`
- `NSOpenPanel` — file open dialog
- `NSSound.beep()` — error feedback sound
- `NSWorkspace.shared.activateFileViewerSelecting` — reveal exported file in Finder

Fix: **Protocol injection via `ZudioPlatformHost`** (see Part 13, platform protocol subsection). All NSApp, NSEvent, NSSound, and NSWorkspace call sites in AppState move into a `MacPlatformHost` conformer that is injected at startup. AppState holds `weak var platformHost: ZudioPlatformHost?` and calls through it, with no platform imports in the shared file.

The one exception is `NSApp.keyWindow?.makeFirstResponder(nil)` — replace this with `@FocusState` dismissal (SwiftUI-native, works on both platforms without needing the platform host).

### FirstMouseFix.swift
An `NSViewRepresentable` wrapper that allows transport buttons to receive clicks without the window first needing to become focused. This is a macOS window-system concept that doesn't exist on iOS (every touch goes directly to the view).

Fix: Wrap entire file in `#if os(macOS)`. Remove `.background(FirstMouseFix())` from transport buttons on iOS via `#if os(macOS)` conditional in TopBarView.

### TopBarView.swift
Current Mac-only code:
- `import AppKit` — for `NSColor.selectedControlColor`, `NSColor.controlColor`, `NSColor.separatorColor`
- `NSImage` — used in `loadLogoImage()` return type and callers
- `NSColor` — used in `transportButtonStyle` for button background colors

Fix:
- Replace `NSColor.selectedControlColor` → `Color(UIColor.systemFill)` on iOS / `Color(NSColor.selectedControlColor)` on macOS using conditional compilation
- Replace `NSImage` logo loading with a cross-platform version using `#if os(macOS)` to return `NSImage` and `#if os(iOS)` to return `UIImage`, both wrapped in SwiftUI `Image`
- Or simpler: store the logo as a SwiftUI `Image("zudio-logo")` in the asset catalog (works on both platforms)

---

## Part 3: Platform Target Configuration

### Package.swift
Current:
```swift
platforms: [.macOS(.v14)]
```

Change to:
```swift
platforms: [.macOS(.v14), .iOS(.v16), .iPadOS(.v16)]
```

iOS 16 is the right minimum — it gives access to `presentationDetents` (for sheets), `.scrollDismissesKeyboard`, and the full modern SwiftUI API surface. As of 2026 it covers ~98% of active iPhones.

### Xcode project.pbxproj
Add iOS and iPadOS deployment targets. Add an `Info.plist` entry for `UISupportedInterfaceOrientations` to explicitly allow all four orientations on iPad and portrait + landscape-right on iPhone.

### App icon
The current `.icns` format is macOS-only. Add an `AppIcon.appiconset` to the Assets catalog with the required iOS sizes: 60×60@2x, 60×60@3x (iPhone), 76×76@1x, 76×76@2x (iPad), 83.5×83.5@2x (iPad Pro), 1024×1024 (App Store).

---

## Part 4: File Export

iOS has no shared filesystem — each app is sandboxed and there is no `~/Downloads` folder. Both export functions need an output path change and a share sheet added. The core recording/writing logic is otherwise unchanged.

### Output path (both MIDI and Audio)

Both `MIDIFileExporter.swift` and `AudioFileExporter.swift` use `.downloadsDirectory`, which does not exist on iOS. Replace with a platform conditional in both files:

```swift
#if os(macOS)
let baseURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
#else
let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
#endif
```

On iOS, files written to `.documentDirectory` appear in the Files app under "On My iPhone/iPad → Zudio" once the two Info.plist keys below are set.

### Share sheet (both MIDI and Audio)

On macOS, export silently writes a file and shows a status message. On iOS this is the wrong pattern — the user has no easy way to find the file. Instead, after the file is written, immediately present a `UIActivityViewController` with the file URL:

```swift
#if os(iOS)
let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
// present from the current UIViewController or SwiftUI sheet
#endif
```

The share sheet gives the user immediate options:
- Save to Files app (iCloud Drive, On My iPhone, etc.)
- AirDrop to a Mac or another device
- Open directly in GarageBand (appears as an import target for both MIDI and M4A)
- Share via Mail, Messages, or any other app

This is better UX than the Mac approach — no need to find the file manually after export.

### MIDI export specifics

`MIDIFileExporter.swift` writes a `.mid` file. No format change needed on iOS. After writing, trigger the share sheet with the `.mid` file URL.

### Audio export specifics

`AudioFileExporter.swift` records via an `AVAudioEngine` tap and writes an M4A file. `AVAudioEngine` tap capture is fully supported on iOS, so the recording logic is unchanged. After writing, trigger the share sheet with the `.m4a` file URL. GarageBand recognises M4A as a valid audio import, so users can bring the exported song directly into a GarageBand project.

### Info.plist additions

Two keys are required to make exported files visible in the Files app independent of the share sheet:

- `UIFileSharingEnabled = YES` — exposes the app's Documents folder in Files under "On My iPhone/iPad → Zudio"
- `LSSupportsOpeningDocumentsInPlace = YES` — allows other apps (e.g. GarageBand) to open files directly from Zudio's folder without copying them

---

## Part 5: iPad Layout Strategy (Implemented)

The iPad layout uses `contentWidth` (measured by the root GeometryReader) as the sole branching variable. Four breakpoints are active in the shipped code:

**Tested devices and their contentWidth at runtime:**
- iPad mini portrait — 744pt
- iPad 11" / Air portrait — 820–834pt
- iPad mini landscape — 1133pt
- iPad Pro landscape — 1194pt (also covers macOS at ≥1150pt)

**Portrait mode adjustments** (contentWidth < 900):
- Logo moves from the left of the transport row into the transport VStack, stacked above the buttons
- Version text ("V 0.99b") is hidden below 900pt to save space
- TrackRowView left panel narrows: 220pt (mini portrait) or 222pt (11"/Air portrait)
- On mini portrait (< 800pt), the right effects panel is given an explicit 232pt frame to prevent it from being squeezed to zero; on 11"/Air portrait (800–900pt) it sizes naturally with adjusted leading/trailing padding
- StatusBoxView minimum height reduces to 44pt on mini portrait
- iPad mini landscape (900–1150pt) treated as a separate tier: left panel widens to 242pt, buttons use `.small` control size

**Landscape mode** (contentWidth ≥ 900) uses the same layout as macOS, just narrower. No structural differences.

---

## Part 16: iPhone Player Mode Strategy

iPhone is a fundamentally different form factor. At 393 × 852pt (portrait) or 852 × 393pt (landscape), the MIDI grid layout is not viable — 7 track rows at 63pt each alone exceed the landscape screen height, and the left+right panels (220 + 232 = 452pt) are wider than the portrait screen. Rather than compressing the existing layout, iPhone gets a minimal dedicated **Player Mode** — a pure listening and experimentation experience with no MIDI grid, no track controls, and no instrument editing.

**Controls:**
- Minimal transport: ⏮ ◀ ▶/■ ▶ ⏭
- Mode selector: Song / Evolve / Endless
- Style picker: Ambient / Chill / Kosmic / Motorik
- Export Audio (only action button; no Save / Load)

**Main body:** Abstract generative visual (Eno Reflection / JMJ Eon aesthetic) toggled with the generation log via a tab strip at the bottom. Canvas-based per-note orbs spawn on note-on events, positioned by pitch (vertical axis) and track (horizontal spread), sized by velocity, color-coded by track, fading over 1.5–3s. Background gradient is keyed to the current style. Driven by `activeVisualizerNotes: [VisualizerNote]` published by `PlaybackEngine` and a 30fps `TimelineView`.

**Touch interactions on the visual canvas:**
The canvas is a playable surface. Eight gestures across three groups:

| Gesture | Target | Action |
|---------|--------|--------|
| Tap | Orb | 4-bar solo of that track, auto-releases |
| Double-tap | Orb | 4-bar mute → auto-restore with new instrument |
| Long-press | Orb | Toggle: strip all effects (dry) ↔ restore track defaults |
| Tap | Empty canvas | Play / pause |
| Long-press | Empty canvas | Regen a random non-drum track (pattern + instrument) |
| Swipe right | Canvas | Instrument shuffle on a random non-drum track |
| Swipe left | Canvas | Undo last instrument shuffle |
| Two-finger any | Canvas | Trigger automated filter sweep across all tracks (~2 bars) |

Implementation notes:
- **Tap orb / solo:** uses existing `soloState` in AppState. Tapped orb brightens to confirm. Note: single-tap has ~350ms iOS delay while waiting to rule out double-tap.
- **Double-tap orb / mute + new instrument:** orb fades out for 4 bars, track restores with a freshly selected instrument, orb pulses white briefly on re-entry.
- **Long-press orb / effects toggle:** a `Set<Int>` in `PhonePlayerView` tracks which tracks are currently stripped dry. First long-press → call per-track "clear effects" path; second → call per-track "restore defaults" path (each track has different defaults already in the engine). Orb gains a faint grey ring while in dry state.
- **Long-press empty / regen:** uses existing per-track regen path. Track's orbs visibly shift character to signal the change.
- **Swipe / shuffle:** previous instrument stored in a `[Int: String]` dict keyed by track index for the undo. Affected track's orbs flash briefly.
- **Two-finger / filter sweep:** new `AVAudioUnitEQ` or low-pass filter node added to the engine chain. Sweep is automated (~2 bars open then return); the gesture is a trigger, not a continuous control.

Orb hit-testing: an orb is "hit" if the tap lands within 1.5× its display radius of the orb centre, using the same position calculation as the canvas draw pass.

**Orb appearance — track colors match the MIDI grid family, with hue shifts to distinguish tracks within the same family:**
- Lead 1: pure red (hue 0.02) — solid orb
- Lead 2: warm orange-red (hue 0.06) — same family, visually distinguishable
- Pads: soft blue (hue 0.60) — large, slow float drift
- Rhythm: cyan-blue (hue 0.54) — tighter, faster fade, less drift
- Texture: blue-indigo (hue 0.66) — wide lateral drift, larger and more translucent
- Bass: purple (hue 0.78)
- Drums: yellow (hue 0.14)

Within-family distinction strategy: reds differ by hue (0.02 vs 0.06); blues differ by both hue shift and drift behaviour (speed and direction) so they remain distinguishable even at small sizes on a dark background.

**Orb appearance — note duration is visually encoded:**
- Short notes (1/16–1/8, durationSteps 1–4): small tight circle, very bright core, fast fade (~0.8s). Appears and vanishes like a spark.
- Medium notes (1/4, durationSteps 4–8): standard orb, ~1.5s fade.
- Long notes (half–whole note, durationSteps 8–16): larger orb, slow 2.5–3s fade, plus a **comet tail** — 3–4 ghost circles at the orb's previous drift positions, each more transparent than the last. The tail reads immediately as "still ringing."
- Very long notes (2+ bars, durationSteps 32+): same comet tail plus a slow-expanding sonar ring that fades as it grows, re-asserting the note's presence across multiple seconds.

**Haptic feedback:**
All haptics use SwiftUI `.sensoryFeedback` (iOS 17+, no import needed) attached to state triggers, keeping haptic logic out of the canvas gesture handlers.

Gesture haptics:
- Tap orb (solo): `.impact(weight: .medium)` — confirms track grab
- Double-tap orb (mute): `.impact(weight: .light)` — lighter, distinct from solo
- Long-press orb (effects toggle): `.impact(weight: .heavy)` on toggle; `.success` notification on restore — the "thunk / tada" pair makes the two states feel different
- Tap empty canvas (play): `.impact(weight: .medium)`; (pause): `.impact(weight: .soft)` — start feels assertive, stop feels gentle
- Long-press empty (regen): `.impact(weight: .heavy)` on completion — something significant regenerated
- Swipe right (shuffle): `.selection` — light tick like a slot machine advancing
- Swipe left (undo): `.impact(weight: .soft)` — feels like a step back rather than a new action
- Two-finger filter sweep: `.impact(weight: .rigid)` at sweep start — one crisp pulse to confirm the trigger

Transport button haptics:
- Play: `.impact(weight: .medium)`
- Stop: `.impact(weight: .soft)`
- ⏭ Skip / generate next: `.impact(weight: .medium)`
- ⏮ Previous: `.impact(weight: .light)`
- Seek forward/back (◀ ▶): `.selection`

System event haptics:
- Song generation complete: `.success` notification
- Export Audio complete: `.success` notification
- Error / disabled action: `.warning` notification (e.g. tapping Export when no song loaded)

**Orientation:**
- Portrait: VStack — header / transport / mode / style / export / body (visual or log) / tab strip
- Landscape: HStack — left controls column (~210pt) / right body + tab strip

**Routing:** `ContentView.body` detects `UIDevice.current.userInterfaceIdiom == .phone` and renders `PhonePlayerView` instead of the full grid layout. iPad path is completely unchanged.

**New files:** `PhonePlayerView.swift`, `VisualizerView.swift`. Modifications: `ContentView.swift` (routing check), `PlaybackEngine.swift` (VisualizerNote population + reverb mix parameter), `Types.swift` (VisualizerNote struct), `AppState.swift` (`loadPreviousFromHistory()` for ⏮ button).

A detailed implementation plan is in the Claude plan file (`polished-painting-zephyr.md`).

---

## Part 6: Specific View Changes

### ContentView.swift
- Remove `.frame(minWidth: 900, minHeight: 500)`
- Add `@Environment(\.horizontalSizeClass) var sizeClass`
- Use `ScrollView` wrapping the track list (tracks may not fit on screen; scroll is natural on iOS)
- The zoom slider (visible bars) remains useful on iPad; on iPhone it may be removed or placed in a settings sheet

### TopBarView.swift
- Three layout branches by sizeClass (see Part 5)
- Replace `NSColor` with `Color` SwiftUI equivalents (cross-platform)
- Replace `NSImage` logo with asset catalog image (cross-platform)
- Move Help/About to a settings sheet on iPhone
- `.keyboardShortcut` modifiers on Generate and Test Mode buttons work on iOS 15+ with hardware keyboards (iPad/iPhone with keyboard attached) — keep them
- A significant proportion of iPad users (especially iPad Pro/Air) use a hardware keyboard. Do not remove keyboard shortcuts or the underline hotkey indicators on button labels when porting to iPad — they are useful and expected by that audience

### TrackRowView.swift
- Add sizeClass environment variable
- For `.regular`: current layout compressed to 180+MIDI+120 column widths
- For `.compact`: two-zone card layout (see Part 5, Tier 2)
- Effects sheet: new `TrackEffectsSheet` view presented as `.sheet` or `.popover` on tap
- The instrument picker arrows (◀ Name ▶) work fine on both layouts; keep them

### HelpView / AboutView
- Current fixed sizes (600×430 and 440×316) don't fit iPhone
- Replace `.frame(width: 600, height: 430)` with `.frame(maxWidth: .infinity, maxHeight: .infinity)` and let `presentationDetents` control size
- Use `.presentationDetents([.large])` on iPhone, `.presentationDetents([.medium, .large])` on iPad

### MIDILaneView.swift
- No structural changes needed; it already uses flexible framing
- On iPhone compact layout, it will be full-width which is actually better

### StatusBoxView.swift
- On iPad: keep inline at bottom of ContentView as today
- On iPhone: move to a detent sheet (pull-up from bottom), triggered by a button in the top bar

---

## Part 7: Touch Interaction Considerations

**Current interactions that need touch adaptation:**

- **HoldRepeater** (backward/forward bar scrubbing): Works with `DragGesture` which is touch-compatible. No changes needed.
- **Drag-to-seek in MIDILane**: Uses `DragGesture`, touch-compatible. No changes needed.
- **Transport button press highlights**: Use `@GestureState` with `DragGesture` — works on touch. No changes needed.
- **BPM text field + stepper**: Works on iOS. The Stepper control is touch-friendly (large hit areas).
- **Mute/Solo toggle chips**: Currently 22×18pt — very small for touch targets. Apple HIG minimum is 44×44pt. Need to increase to at least 32×28pt on iPhone, or increase padding so the tappable area is 44×44pt while the visual chip remains small.
- **Effect chips** (44×20pt): Too small for reliable touch. Need 44×44pt minimum tap target (add `.contentShape(Rectangle().inset(by: -12))` or increase the chip size).
- **Instrument arrow buttons** (◀ ▶): Currently very small. Add padding to increase tap target.

**New touch-specific interactions to add:**
- Swipe to dismiss status log sheet
- Tap track row to expand/collapse on iPhone
- Long-press on track row → context menu (regenerate, clear, effects) as an alternative to the effects column

---

## Part 8: Audio Session Configuration (iOS-specific)

On iOS, `AVAudioSession` must be configured explicitly to play audio. The macOS audio engine works without this; iOS requires:

```swift
#if os(iOS)
try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
try AVAudioSession.sharedInstance().setActive(true)
#endif
```

This is handled by `ZudioPlatformHost.configureAudioSession()` — the platform protocol method AppState calls during engine startup. The macOS conformer (`MacPlatformHost`) is a no-op; the iOS conformer (`IOSPlatformHost`) runs the AVAudioSession setup shown above. This keeps AVFoundation session imports out of the shared `AppState.swift`.

Additionally, on iOS the audio session can be interrupted (phone call, Siri, etc.). The app should observe `AVAudioSession.interruptionNotification` and pause playback on interruption, resuming when interruption ends. This notification observer is also set up inside `IOSPlatformHost.configureAudioSession()`.

---

## Part 9: iPad Multitasking

iPadOS supports Split View and Slide Over — the app window can be as narrow as 320pt. The compact-width layout (Tier 2) must handle this case. The key requirement: when the window is in Split View at minimum width, the app should remain functional (generate, play, stop) even if the MIDI lanes are too narrow to be useful.

Minimum viable at 320pt width:
- Top bar with Generate + Play/Stop
- Track list with name + mute/solo only (MIDI lane hidden or extremely narrow)
- Status log hidden

---

## Part 10: Haptic Feedback (iOS enhancement)

On iOS, brief haptic feedback on Generate completion and Play/Stop would improve the feel. Use `UIImpactFeedbackGenerator` wrapped in `#if os(iOS)`:
- Generate complete: `.medium` impact
- Song end (natural stop): `.light` impact
- Stop button tap: `.rigid` impact

---

## Part 11: Files to Create/Modify

**Modify (platform adaptation):**
- `Sources/Zudio/ZudioApp.swift` — `#if os(macOS)` around NSApp calls
- `Sources/Zudio/AppState.swift` — replace all NSApp/NSEvent/NSSound/NSWorkspace call sites with `platformHost?.method()` calls; add `weak var platformHost: ZudioPlatformHost?`; replace NSApp BPM dismissal with `@FocusState`
- `Sources/Zudio/UI/FirstMouseFix.swift` — entire file wrapped in `#if os(macOS)`
- `Sources/Zudio/UI/TopBarView.swift` — sizeClass branching, NSColor/NSImage replacement, compact layout
- `Sources/Zudio/UI/ContentView.swift` — remove minWidth/minHeight, add ScrollView, sizeClass branching
- `Sources/Zudio/UI/TrackRowView.swift` — sizeClass branching, compact two-zone layout, larger touch targets
- `Sources/Zudio/UI/HelpView + AboutView` (in TopBarView.swift) — adaptive sheet sizing
- `Sources/Zudio/UI/StatusBoxView.swift` — inline on iPad, sheet on iPhone
- `Sources/Zudio/Playback/PlaybackEngine.swift` — no AVAudioSession changes needed here; session is configured via `ZudioPlatformHost.configureAudioSession()` called from AppState
- `Sources/Zudio/Assets/MIDIFileExporter.swift` — platform-conditional output path + ShareLink on iOS
- `Package.swift` — add iOS/iPadOS platforms
- `Zudio.xcodeproj/project.pbxproj` — add iOS deployment target

**Create new:**
- `Sources/Zudio/Platform/ZudioPlatformHost.swift` — protocol definition; lives in ZudioCore; no platform imports
- `Sources/Zudio/Platform/MacPlatformHost.swift` — macOS conformer; Zudio target only; imports AppKit
- `Sources/ZudioiOS/Platform/IOSPlatformHost.swift` — iOS conformer; created during Phase 1; imports UIKit and AVFoundation
- `Sources/Zudio/UI/TrackEffectsSheet.swift` — the effects panel as a sheet for iPhone compact layout
- App icon assets for iOS (AppIcon.appiconset in asset catalog)
- `Sources/Zudio/Resources/Info.plist` additions — UIFileSharingEnabled, LSSupportsOpeningDocumentsInPlace, UISupportedInterfaceOrientations

**No changes:**
- All Generation files (9 files) — pure Swift, no platform dependencies
- All Model files — pure Swift
- `Sources/Zudio/UI/MIDILaneView.swift` — pure SwiftUI Canvas
- All soundfont/resource files — already cross-platform bundle resources

---

## Part 12: Implementation Strategy — Why iPad First

### The Right Approach: iPad + iPhone Landscape Before Portrait

This is the correct professional sequence, not just the easier one.

**Music apps live on iPad.** GarageBand, Korg Gadget, AUM, Moog's apps, Drambo — virtually every serious iOS music app is designed iPad-first. The larger screen is the right form factor for a DAW-like track layout with MIDI lanes, effects columns, and a transport bar. iPhone portrait is a valuable addition but not the primary mobile use case for this type of app.

**iPad and iPhone landscape share exactly one code path.** `horizontalSizeClass == .regular` covers both iPad (all orientations) and iPhone landscape. Implement the compressed regular-width layout once and both devices work. The only difference is screen height, which a `ScrollView` handles automatically.

**AppKit removal is prerequisite work regardless.** Fixing the four AppKit-dependent files is required to get any iOS build. Once done, you have a compilable iOS target. The jump from "compiles" to "works well on iPad" is then a day of layout compression, not a redesign.

**iPhone portrait is a separate project of equal size.** The compact track row redesign (two-zone card, effects sheet, condensed top bar, status log as pull-up sheet) is essentially building a second UI. Deferring it lets the iPad version ship while that work is planned and executed separately.

**App Store supports iPad-only or "Designed for iPad" apps.** Shipping Phase 1+2 as an iPad app is a fully legitimate release. iPhone support can be added in a subsequent update.

---

### Phase 1: Get It Building on iOS (Est. 1–2 days)
Goal: A compilable iOS target that runs on an iPad simulator with full audio and generation.

1. Add `.iOS(.v16)` and `.iPadOS(.v16)` to `Package.swift` platforms array
2. Add iOS deployment target to `Zudio.xcodeproj/project.pbxproj`
3. Wrap `ZudioApp.swift` NSApp dock-icon calls in `#if os(macOS)`
4. Create `ZudioPlatformHost.swift` (protocol) and `MacPlatformHost.swift` (macOS conformer); inject `MacPlatformHost` into `AppState` from the macOS `ZudioApp`; replace all NSApp/NSEvent/NSSound/NSWorkspace call sites in AppState with `platformHost?.method()` calls; replace BPM field NSApp dismissal with `@FocusState`
5. Create `IOSPlatformHost.swift` (iOS conformer) with `configureAudioSession()` handling AVAudioSession setup and interruption notification; inject from the iOS `ZudioApp` entry point
6. Wrap `FirstMouseFix.swift` entirely in `#if os(macOS)`; remove its `.background()` usage in TopBarView on iOS
7. Replace `NSColor` in `TopBarView.swift` with SwiftUI `Color` equivalents
8. Replace `NSImage` logo loading with asset-catalog `Image` (cross-platform)
9. Fix `MIDIFileExporter.swift` to use `.documentDirectory` on iOS
10. Add iOS app icon assets to asset catalog
11. Add `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` to Info.plist
12. **Verify:** `xcodebuild -scheme Zudio -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build` passes with no errors on both Mac and iOS targets

---

### Phase 2: iPad + iPhone Landscape — Working UI (Est. 2–3 days)
Goal: The app looks good and is fully usable on iPad (all orientations) and iPhone landscape.

Layout strategy: `horizontalSizeClass == .regular` covers all these cases.

13. Remove `.frame(minWidth: 900, minHeight: 500)` from `ContentView.swift`; wrap track list in `ScrollView(.vertical)`
14. Compress `TrackRowView` regular-width layout: left panel 232pt → 180pt, right effects panel 152pt → 120pt, row height 63pt → 52pt
15. Compress `TopBarView` regular-width: logo height 84pt → 60pt; verify all pickers still fit
16. Fix `HelpView` and `AboutView` fixed frame sizes — use `presentationDetents` instead of fixed pixel dimensions
17. Increase touch target sizes for small buttons (mute/solo chips, instrument arrows) to meet 44×44pt Apple HIG minimum via `.contentShape` padding
18. **Verify on iPad Pro 13" simulator:** generate, play, stop, save MIDI, mute/solo, effects all work
19. **Verify on iPad mini simulator:** same checks at narrower width
20. **Verify on iPhone 15 Pro Max in landscape:** `horizontalSizeClass` is `.regular` in landscape — same layout path, narrower height handled by scroll
21. **Test on a real iPad device** if available — validates AVAudioSession and audio output

At this point the app is shippable as an iPad app.

---

### Phase 3: Ship iPad Version (Optional milestone)
- Submit to App Store as iPad-compatible app
- Gather real-world feedback on the track layout, touch targets, and workflow before committing to the iPhone portrait design

---

### Phase 4: iPhone Player Mode (Est. 2–3 days, separate project)
Goal: Full iPhone support via a dedicated player mode UI (no MIDI grid).

See Part 16 for the design rationale. Implementation plan is in `polished-painting-zephyr.md`.

22. Add `VisualizerNote` struct to `Types.swift`
23. Add `activeVisualizerNotes` publishing to `PlaybackEngine.onStep`; expose reverb mix parameter
24. Add `loadPreviousFromHistory()` to `AppState`
25. Create `VisualizerView.swift` — Canvas-based per-note orb animation at 30fps + touch interactions (tap orb → 4-bar solo, double-tap → mute/unmute, tap empty → play/pause, long-press → regen random track, pinch → reverb)
26. Create `PhonePlayerView.swift` — portrait + landscape layouts, tab strip for visual/log toggle
27. Add iPhone routing check to `ContentView.body`
28. **Verify on iPhone 15 Pro simulator** (393 × 852pt) — portrait and landscape
29. Add haptic feedback (`UIImpactFeedbackGenerator`) for Play, Stop, Generate complete, orb-tap solo — iOS-only via `#if os(iOS)`

---

## Part 13: Shared Code Strategy — Keeping Mac and iPad in Sync

All musical logic (generators, rules, models, playback engine, exporters) should be extracted into a local **Swift Package** (`ZudioCore`) that both the Mac and iPad app targets depend on. This means any improvement to a musical rule, generator, or model is made once and automatically applies to both platforms.

**What goes in ZudioCore:** everything under `Generation/`, `Models/`, `Playback/`, and `Assets/` — the entire non-UI layer.

**What stays platform-specific:** all UI views, `NSApp`/`AppKit` code on Mac, and `UIKit`/share sheet code on iPad.

This refactor should be done at the start of the iPad port, not before. It is mechanical work (moving files, fixing imports) — the musical logic itself does not change. Once in place, the workflow is: edit a generator in ZudioCore, both apps update on next build.

### Platform Abstraction — ZudioPlatformHost

`AppState.swift` contains macOS-specific API calls scattered through its transport, keyboard, file, and audio methods. The shared ZudioCore version of AppState must call none of these directly. The solution is **protocol injection**: AppState holds a reference to a `ZudioPlatformHost` conformer and delegates all platform behavior through it. The concrete implementations live in the platform-specific targets.

**Why not `#if os(macOS)` in AppState?** Conditional compilation works for isolated one-liners. AppState's platform divergence is behavioral — the keyboard monitor is set up in one place and torn down in another, the file picker has async completion semantics, the audio session interacts with engine startup. A single protocol makes the platform surface explicit and keeps AppState free of platform imports and testable without a macOS environment. All other files with simpler, isolated divergences (ZudioApp dock icon, TopBarView colors, FirstMouseFix, MIDIFileExporter paths) continue to use `#if os(macOS)` conditionals.

**Protocol definition** (in `ZudioPlatformHost.swift`, ZudioCore — no platform imports):

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

**Injection point** — AppState declares:

```swift
weak var platformHost: ZudioPlatformHost?
```

`ZudioApp.swift` (macOS) sets it at startup before any playback:

```swift
appState.platformHost = MacPlatformHost()
```

`ZudioApp.swift` (iOS, created during Phase 1) injects `IOSPlatformHost()` instead.

**What each method does on each platform:**

- `activateApp()` — Mac: `NSApp.activate(ignoringOtherApps: true)`. iOS: no-op.
- `showOpenPanel(completion:)` — Mac: `NSOpenPanel` sheet. iOS: `UIDocumentPickerViewController`.
- `playErrorSound()` — Mac: `NSSound.beep()`. iOS: `UINotificationFeedbackGenerator(.error)`.
- `registerKeyboardShortcuts(target:)` — Mac: `NSEvent.addLocalMonitorForEvents`. iOS: `UIKeyCommand` registration (iPad with hardware keyboard only).
- `revealOrShareFile(url:)` — Mac: `NSWorkspace.shared.activateFileViewerSelecting([url])`. iOS: `UIActivityViewController` share sheet.
- `configureAudioSession()` — Mac: no-op. iOS: `AVAudioSession` category, activation, and interruption observer setup.

---

## Part 14: Monetization Options

Two viable models for the iOS/iPadOS release at a price point under $5.

**Option A — Flat paid (~$2.99 upfront)**
- Free tier: none — pay once to download
- Pros: no StoreKit/IAP infrastructure, no entitlement checks throughout the codebase, simpler to build and maintain, no "crippled demo" perception, single clear value proposition
- Cons: higher friction to download, smaller top-of-funnel, harder to grow audience organically in a crowded App Store

**Option B — Free with one-time unlock IAP (~$2.99)**
- Free tier: generate and play in one style (Motorik is the most immediately recognizable), full MIDI grid and per-track regen, no export
- Paid unlock: audio and MIDI export, Kosmic and Ambient styles unlocked
- Pros: zero-friction discovery, users hear the value before paying, natural upsell moment when they want to keep a song they made
- Cons: significant added complexity (StoreKit integration, entitlement checks at export and style-switch points, sandbox/test environment), meaningful extra development time for a solo project
- Key principle: never limit the number of generations — the generative loop is the core value and capping it would undermine the whole experience; only gate export and style access

---

## Part 15: Verification

1. `xcodebuild -scheme Zudio -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' build` — must build without errors
2. App launches on iPhone SE simulator — no crashes
3. Generate a song on iPhone — audio plays
4. Play/Stop on iPhone — works via on-screen button
5. Save MIDI on iPhone — file appears in Files app → Zudio → Documents
6. All 7 track rows visible on iPhone portrait (with scroll if needed)
7. Effects accessible on iPhone (via tap-to-expand sheet)
8. App launches on iPad — regular layout used
9. iPad Split View at minimum width — app doesn't crash
10. AVAudioSession interruption (simulate phone call) — playback pauses and resumes cleanly
