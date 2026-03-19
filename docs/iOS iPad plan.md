# iOS/iPadOS Port — Research & Design Plan

## Context

Zudio is currently a macOS-only app. This plan covers what is required to make it run on iPhone and iPad. The audio engine and all generation code are already iOS-compatible. The primary work is: removing four AppKit dependencies, redesigning the UI for touch and smaller screens, and adapting the file export path. No code is written here.

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
- `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` — global space-bar monitor for play/stop toggle
- `event.keyCode == 49` (space bar), `event.modifierFlags` inspection
- `NSApp.keyWindow?.makeFirstResponder(nil)` — unfocus BPM text field after editing
- `NSApp.activate(ignoringOtherApps: true)` — called in `play()` and `stop()`

Fix:
- Wrap the entire space-bar monitor in `#if os(macOS)`. On iOS, play/stop is only triggered by the on-screen button — no physical keyboard needed.
- Replace `NSApp.keyWindow?.makeFirstResponder(nil)` with `@FocusState` dismissal (SwiftUI-native, works on both platforms).
- Remove `NSApp.activate()` calls — not needed on iOS.

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

Current: `MIDIFileExporter.swift` writes to `~/Downloads/` using `.downloadsDirectory`, which does not exist on iOS.

Fix:
```swift
#if os(macOS)
let baseURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
#else
let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
#endif
```

On iOS, files written to `.documentDirectory` appear in the Files app under "On My iPhone/iPad → Zudio". Users can AirDrop or share them from there.

Additionally, after saving on iOS, present a `ShareLink` or `UIActivityViewController` sheet so the user can immediately share the MIDI file to GarageBand, AirDrop it, or send it elsewhere. This is better UX than silently writing to a directory.

The `Info.plist` will need `UIFileSharingEnabled = YES` and `LSSupportsOpeningDocumentsInPlace = YES` to expose the Documents folder in the Files app.

---

## Part 5: UI Layout Strategy

This is the most significant design challenge. The current layout assumes a minimum 900×500pt window. The layouts needed:

| Device | Width | Height | Orientation | Challenge |
|--------|-------|--------|-------------|-----------|
| iPad Pro 12.9" | 1024pt | 1366pt | Portrait | Workable, needs compression |
| iPad Pro 12.9" | 1366pt | 1024pt | Landscape | Very close to current Mac layout |
| iPad mini | 768pt | 1024pt | Portrait | Needs compression |
| iPhone 15 Pro Max | 430pt | 932pt | Portrait | Complete redesign needed |
| iPhone SE | 375pt | 667pt | Portrait | Most constrained case |
| iPhone (any) | 667–932pt | 375–430pt | Landscape | Compact height, medium width |

The current fixed panels total 384pt wide (232 left + 152 right) before the MIDI lane even gets space. This exceeds the iPhone SE's total width of 375pt.

**Recommended strategy: Three layout tiers using `horizontalSizeClass`**

SwiftUI provides `@Environment(\.horizontalSizeClass)` which returns `.regular` (iPad, iPhone landscape) or `.compact` (iPhone portrait). This is the right branching point.

### Tier 1: Regular Width (iPad all orientations, iPhone landscape)
Keep the current three-column track row layout but compress:
- Left panel: reduce from 232pt → 180pt (drop the icon, abbreviate labels)
- Right effects panel: reduce from 152pt → 120pt (smaller chip text)
- Track height: reduce from 63pt → 52pt
- Top bar: keep two-row layout but reduce logo to 60pt height
- All pickers fit; no layout change needed

### Tier 2: Compact Width / Adequate Height (iPhone portrait, 375–430pt wide)
The track row layout must be completely rethought. The three-column approach (controls | MIDI lane | effects) is impossible. Recommended layout:

**Track row becomes a two-zone card:**
- **Top zone** (full width, 38pt tall): Track icon + label + Mute + Solo + Regenerate (⚡) + instrument name
- **Bottom zone** (full width, 44pt tall): MIDI lane (full width, no left/right panels)
- **Effects hidden** behind a tap — tapping anywhere on the top zone opens an effects sheet anchored to that track

This gives each track 82pt height (up from 63pt) but removes the side panels entirely. The MIDI lane gets the full width which actually improves readability.

**Top bar (iPhone portrait):** The current two-row header won't fit. Replace with:
- Row 1: Logo (left, 40pt tall) + Play/Stop (center) + Generate (right)
- Row 2: Style picker (Motorik/Cosmic/Ambient) + Mood + Key + BPM
- Logo tap still toggles Test Mode
- Help/About moved to a settings sheet (tap "..." or gear icon)

**Status log:** On iPhone, the status log takes too much vertical space. Move it to a swipe-up sheet (using `.presentationDetents([.fraction(0.3), .large])`) accessible via a small "≡ log" button in the top bar.

### Tier 3: Compact Width + Compact Height (iPhone landscape)
iPhone landscape gives ~667–932pt width but only ~375–430pt height. Seven track rows at 63pt each = 441pt — already taller than the available height. Use:
- A horizontal scroll view (SwiftUI `ScrollView(.vertical)`) for the track list
- Top bar collapses to a single row: Logo + Transport + Generate (all small)
- Status log hidden by default, accessible via sheet

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

This should be called in `PlaybackEngine.init()` inside an `#if os(iOS)` block.

Additionally, on iOS the audio session can be interrupted (phone call, Siri, etc.). The app should observe `AVAudioSession.interruptionNotification` and pause playback on interruption, resuming when interruption ends.

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
- `Sources/Zudio/AppState.swift` — `#if os(macOS)` around NSEvent monitor; cross-platform BPM field focus dismissal
- `Sources/Zudio/UI/FirstMouseFix.swift` — entire file wrapped in `#if os(macOS)`
- `Sources/Zudio/UI/TopBarView.swift` — sizeClass branching, NSColor/NSImage replacement, compact layout
- `Sources/Zudio/UI/ContentView.swift` — remove minWidth/minHeight, add ScrollView, sizeClass branching
- `Sources/Zudio/UI/TrackRowView.swift` — sizeClass branching, compact two-zone layout, larger touch targets
- `Sources/Zudio/UI/HelpView + AboutView` (in TopBarView.swift) — adaptive sheet sizing
- `Sources/Zudio/UI/StatusBoxView.swift` — inline on iPad, sheet on iPhone
- `Sources/Zudio/Playback/PlaybackEngine.swift` — add AVAudioSession setup and interruption handling in `#if os(iOS)` block
- `Sources/Zudio/Assets/MIDIFileExporter.swift` — platform-conditional output path + ShareLink on iOS
- `Package.swift` — add iOS/iPadOS platforms
- `Zudio.xcodeproj/project.pbxproj` — add iOS deployment target

**Create new:**
- `Sources/Zudio/UI/TrackEffectsSheet.swift` — the effects panel as a sheet for iPhone compact layout
- App icon assets for iOS (AppIcon.appiconset in asset catalog)
- `Sources/Zudio/Resources/Info.plist` additions — UIFileSharingEnabled, LSSupportsOpeningDocumentsInPlace, UISupportedInterfaceOrientations

**No changes:**
- All Generation files (9 files) — pure Swift, no platform dependencies
- All Model files — pure Swift
- `Sources/Zudio/UI/MIDILaneView.swift` — pure SwiftUI Canvas
- All soundfont/resource files — already cross-platform bundle resources

---

## Part 12: Implementation Order (When Work Begins)

The recommended sequence minimizes risk by getting a buildable iOS target first, then improving the UI progressively:

1. **Add iOS target to Package.swift** — first step; establishes the build target
2. **Fix AppKit imports** — wrap in `#if os(macOS)` so the app compiles on iOS at all
3. **Add AVAudioSession setup** — without this, no sound on iOS
4. **Fix file export path** — without this, Save MIDI crashes on iOS
5. **Test on iPad first** — the regular-width layout is closest to Mac; validate audio + generation work
6. **Compress regular-width layout** for iPad (reduce fixed pixel widths)
7. **Build compact-width layout** — the iPhone track row redesign; most design work
8. **Build compact top bar** for iPhone
9. **Move StatusBox to sheet** on iPhone
10. **Increase touch target sizes** for all small buttons
11. **Add haptic feedback**
12. **Test on iPhone SE (smallest screen)** — the hardest case

---

## Part 13: Verification

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
