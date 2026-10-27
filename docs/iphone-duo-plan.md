# iPhone Duo Plan

Status: **implemented for 2.8 (version 2.8, build 133) and tested on a real iPhone Duo, where it worked
great.** The layout switch, the narrow top bar and the short-window compaction are all in the code. See
[Implemented in 2.8](#implemented-in-28) for exactly what changed and the size gates, and
[Still open](#still-open-after-device-testing) for what has not been checked.

iPhone Duo ships **2026-10-23**. Zudio will not be Duo-aware at launch, and that is the
intended sequencing rather than a slip. See [ios-ipad-plan.md](ios-ipad-plan.md) for the
current platform view inventory this builds on.

---

## Release sequencing

- **2.5 (build 130)** — live on the App Store since the 1 October submission.
- **2.6 (build 131)** — Motorik Europe, reverb restored, melodic Kraftwerk leads. Mac and iOS
  uploaded and **scheduled for App Store release 15 October 2026.** No Duo work in this release.
- **2.7** — Chill Soho, a new Chill substyle. Generation-side only; no Duo work.
  See [chill-soho-plan.md](chill-soho-plan.md).
- **2.8** — the Duo release. **Held until 2.7 (Chill Soho) has shipped**, so a layout change
  cannot be confused with a generation change. Folded and unfolded layouts, and nothing else that
  needs to ship urgently alongside it.

Keeping Duo out of 2.6 and 2.7 is deliberate. Both are generation-side releases that want to be
judged on how they sound; the Duo work is a UI-layer change that wants a device in hand. Mixing
them would make a regression in either harder to attribute. The Duo also gates on Xcode 27.1,
which has now shipped, so it is the release with an external dependency and belongs last.

---

## The two modes

The fold is treated as a **mode change, not a resize**. Zudio is a generative player: you set a
song going and listen. That maps onto a foldable more directly than most apps.

The simple rule: **a Duo unfolded is an iPad, and a Duo folded is an iPhone.**

**Folded — an iPhone.** The cover display runs `PhonePlayerView`, unchanged: song title,
transport, and the visualizer, with the Log tab. No MIDI grid, no per-track controls, no track
rows, and **no way to reach the track view**. Exactly as on every other iPhone.

**Unfolded — an iPad, with the track view as an option.** The inner display runs the iPad
layout: the four-tab strip (Visuals · Log · Tracks · Songs), the song info row, and the
scrollbar row. It does **not** open on the track view. It opens on **Visuals**, and the track
view (seven track rows with mute/solo and effect chips, where a track gets regenerated, an
instrument changed or an effect toggled) is there when the user asks for it.

Both layouts already exist and are good. 2.8 is mostly about **choosing between them correctly**
and **remembering where the user was**, not about designing anything new.

### Unfolded behaviour, step by step

- **First time unfolded:** the iPad layout appears on the **Visuals** tab. Nothing switches to
  the track view automatically, ever.
- **Track view is opt-in:** the Tracks control is the existing third button in the iPad bottom
  tab strip (lower right), visible and available. Tapping it shows the track view exactly as on
  any iPad. Tapping Visuals returns. No new buttons are added for the Duo.
- **Folding:** the app switches to `PhonePlayerView`. The Tracks control is **not available**
  while folded. Playback continues uninterrupted.
- **Unfolding again:** the app returns to **whatever the last unfolded view was**: Visuals if the
  user was on Visuals, the track view if they were on Tracks. The same applies to Log and Songs
  within a session.
- **Across app launches:** the existing iPad rule applies unchanged. Only Visuals and Tracks are
  remembered; Log and Songs reset to Visuals on the next launch. A Duo that was last used
  unfolded on Tracks therefore reopens on Tracks the next time it is unfolded.
- **Folded state never leaks into the unfolded one.** Folding does not reset the unfolded tab,
  and nothing done on the phone layout changes it.

The track view is never part of the folded layout. No current iPhone gains the track view and
none loses anything. See the constraint under Approach.

---

## Why the current code gets it wrong

A Duo reports `userInterfaceIdiom == .phone` whether folded or not, but its inner display is
iPad-shaped. Every branch below therefore picks the phone layout when unfolded, so the user would
get a stretched full-screen player with no way to reach the track view on a tablet-sized screen.

- [ContentView.swift:106](../Sources/Zudio/UI/ContentView.swift#L106) — `UIDevice.current.userInterfaceIdiom == .phone`
  selects `PhonePlayerView` over the iPad tab layout. This is the one that matters.
- [ContentView.swift:20-21](../Sources/Zudio/UI/ContentView.swift#L20-L21) — `contentWidth` and
  `contentHeight` initialise from `UIScreen.main.bounds`. Apple's guidance is to avoid
  `UIScreen.main` on a two-display device and read from `window.windowScene.screen` instead.
- [StatusBoxView.swift:178](../Sources/Zudio/UI/StatusBoxView.swift#L178) and
  [StatusBoxView.swift:187](../Sources/Zudio/UI/StatusBoxView.swift#L187) — the pinch-to-resize
  gesture on the generation log is gated to phones. Unfolded, the log should behave as it does
  on iPad.

There is **no `horizontalSizeClass` or `verticalSizeClass` usage anywhere in the codebase** as of
2.6. Apple's guidance is to branch on size class rather than idiom, which is what lets the app
tell folded from unfolded without a device-specific check. See Approach.

---

## Approach

**Hard constraint: no existing iPhone behaviour changes.** Every current iPhone keeps
`PhonePlayerView` in both orientations. iPhones do not have the room for the track view, that
was settled long ago, and this work does not revisit it. The Duo folded is an iPhone for these
purposes and gets the same treatment.

**Size classes are only the detector.** The product rule is "unfolded = iPad, folded = iPhone".
Size classes are how the code recognises *unfolded* without breaking the constraint above. Nothing
about the design depends on them.

Width alone cannot be the detector. An iPhone Pro Max in landscape is **regular width**, so a
width-only test would push existing phones into the iPad layout, which is precisely the change
that must not happen.

What does separate them is that the Duo's inner display is **regular in both size classes**.
No iPhone is ever regular in both:

- iPhone portrait — compact width, regular height → phone layout
- iPhone Pro Max landscape — regular width, **compact height** → phone layout, unchanged
- Duo folded — compact width → phone layout
- iPad full screen — regular width, regular height → iPad layout
- Duo unfolded — regular width, regular height → iPad layout

An iPad in Split View, Slide Over or a narrow window is **compact width**, and today it still gets
the iPad tab layout because it is decided by idiom. A size-class-only test would flip those to
`PhonePlayerView`, which is an iPad behaviour change and must not happen. So the test keeps the
idiom as an iPad override:

```swift
idiom == .pad || (hSizeClass == .regular && vSizeClass == .regular)   // iPad layout
                                                                      // everything else: PhonePlayerView
```

The idiom half protects every iPad exactly as it is today. The size-class half is only ever
decided for `.phone` idiom devices, where it is true only for the Duo unfolded.

This reproduces today's behaviour exactly on every shipping device. The only surface whose
layout changes is the Duo unfolded, which has no current behaviour to preserve. That is the
property to verify first, now that the simulator is here: run the existing iPhone and iPad simulators
and confirm nothing moved.

**Preserving the unfolded tab.** The iPad tab selection (`iPadTab`) is `@State` in `ContentView`,
and the phone/iPad choice is made inside `ContentView`'s body, so swapping to `PhonePlayerView`
should not destroy it. Verify that on the simulator: fold, unfold, and confirm the tab is
unchanged. If `ContentView` is rebuilt by the scene change, the tab must be held somewhere that
survives the fold (`AppState` or `@SceneStorage`).

**Split View.** The inner display supports Split View. At roughly half the inner width the class
becomes compact width, and because the Duo's idiom is `.phone` the test above sends it to
`PhonePlayerView` with no track view. That follows from the rule and is acceptable: a half-width
Zudio is an iPhone-sized Zudio. An iPad in Split View is different and keeps the iPad layout, by
the idiom override.

**Risk resolved: the inner display is regular in both size classes.** Apple's HIG is width-only
(*"a compact width layout for the outer display and a regular width layout for the inner display
give you the fundamentals for every pose"*) and never states the vertical class. The risk was that
the inner display would report compact height in landscape, so the test above would never fire.
It was measured on the iPhone Duo simulator (Xcode 27.1, iOS 27.1) on 2026-10-18 and does not
happen. See Measured on the simulator, below.

The both-classes test stays, because width alone is ruled out by the hard constraint.

**Transitions pass through odd intermediate classes.** During a fold or rotation the size classes
were seen to update one at a time, for a few milliseconds each (for example regular width with
compact height on the inner display). Only the settled values are reliable. The layout choice
should be a pure function of the current classes with no side effects, and the fold test on the
simulator should confirm the layout does not visibly flicker through `PhonePlayerView` while
unfolding.

---

## What Apple's HIG adds

[Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
was published 9 September 2026. Three things in it were not anticipated here.

**Vertical controls.** The outer display is **wider and shorter** than any current iPhone, and
the system moves toolbars, tab bars and navigation controls to the **side** to preserve vertical
space. On the inner display they stay on the side in landscape, for continuity across the fold.

This does not breach the constraint above, since `PhonePlayerView` is still unchanged, but it
qualifies "folded is just the existing iPhone layout". The *view* is unchanged; the display it
renders on has an aspect ratio no shipping iPhone has, and the system may re-place bars beneath
us. Something to check on the simulator, not to redesign for.

**Reserved regions, including the fold.** When the device is partially open, the **folding
region** is a reserved area down the centre of the inner display that content should avoid.
`ReservedRegion` (SwiftUI) repositions custom content around it. This matters most for the
**MIDI grid** on the opt-in track view, which spans the full width and would be bisected. The
Visuals tab, which is the default, is unaffected in practice. Apple's guidance for grids is an
**even number of columns** so content divides cleanly either side of the fold.

**ArrangementView.** A new SwiftUI container holding a primary and a secondary view, laid out as
either *split* or *overlay*. In an overlay arrangement, the two views **move to occupy either
side of the fold** when the device is partially open. That is the half-open posture idea below,
available as a system container rather than something to build.

Also worth knowing:

- **Device Hub in Xcode** previews an app in the Duo's poses, a second way to look besides the simulator
- The inner display supports **Split View multitasking**, which lands on the phone layout; see
  Approach
- The framing throughout is *"you're still designing for iPhone"*, which matches the folded half
  of the approach taken here

---

## What the work actually is

Not continuity. `AppState` and `PlaybackEngine` are `ObservableObject`s held above the view
layer, so a size-class change rebuilds views without touching the audio engine or the scheduler.
And the iPad layout already switches between Tracks and Visuals through its own tab strip, with
playback continuing across the switch. Folding and unfolding asks nothing of it that the tab
strip does not already do every time the user taps a tab.

Two things are genuinely new:

- **The fold transition itself:** choosing the layout from the size classes, and restoring the
  last unfolded tab on unfolding (see Approach).
- **Running the opt-in track view on the unfolded display.** The unfolded width is not yet
  known. It may be comparable to iPad mini or narrower. The MIDI grid was built for the Mac and
  adapted to iPad.

The second is a tuning job, not a design problem, and the mechanism already exists. `ContentView`
adapts the track view by width through a ladder of breakpoints:

- [ContentView.swift:166-168](../Sources/Zudio/UI/ContentView.swift#L166-L168) — song info chips
  appear progressively: style at ≥800 pt, key at ≥950 pt, BPM at ≥1100 pt
- [ContentView.swift:58](../Sources/Zudio/UI/ContentView.swift#L58) — iPad mini landscape is
  detected as `contentWidth >= 1050 && contentWidth < 1150`
- [ContentView.swift:664](../Sources/Zudio/UI/ContentView.swift#L664) — the generation log is
  hidden on the Tracks tab at that width, where there is not enough vertical room
- [ContentView.swift:675](../Sources/Zudio/UI/ContentView.swift#L675) — iPad mini portrait
  (<800 pt) drops the "Bar" chip to save horizontal space

iPad mini portrait is already about 744 pt and works. So the expectation for the Duo is another
rung on that ladder: measure the unfolded width, see which chips and rows still fit, and extend
the existing breakpoints. Minor adjustments to a system that is already doing this job, rather
than new layout code.

The unfolded width is now measured (see below): 669 pt in portrait, which is narrower than iPad
mini portrait, and 867 pt in landscape. Both need the ladder checked.

## Implementation spec

The original spec, kept for the reasoning. **It has now been built**, with additions and
changes recorded under [Implemented in 2.8](#implemented-in-28). Zack chose to go ahead before
2.7 shipped, so the "held until 2.7" sequencing no longer applies.

### Edit list

Four small edits, all in the iOS-only code paths. The macOS build is untouched.

- **A pure layout helper** (new, a few lines, in `ContentView.swift` or its own file):

  ```swift
  func usesPadLayout(idiom: UIUserInterfaceIdiom,
                     h: UserInterfaceSizeClass?, v: UserInterfaceSizeClass?) -> Bool {
      idiom == .pad || (h == .regular && v == .regular)
  }
  ```

  Pure, no side effects, so a momentary mid-rotation class cannot do harm.
- **`ContentView.body`** ([ContentView.swift:106](../Sources/Zudio/UI/ContentView.swift#L106)):
  add `@Environment(\.horizontalSizeClass)` and `@Environment(\.verticalSizeClass)` to
  `ContentView`, and replace `UIDevice.current.userInterfaceIdiom == .phone` with the negation of
  the helper, so `PhonePlayerView` is chosen when `usesPadLayout` is false. Leave both branches
  otherwise as they are, including the haptics modifier on the iPad branch.
- **`StatusBoxView`** ([StatusBoxView.swift:178](../Sources/Zudio/UI/StatusBoxView.swift#L178) and
  [:187](../Sources/Zudio/UI/StatusBoxView.swift#L187)): both `guard ... == .phone` lines gate the
  pinch-to-resize gesture. Add the same two size-class environment values to `StatusBoxView` and
  replace each guard with `guard !usesPadLayout(...)`. Net effect: pinch stays on for every iPhone
  and the folded Duo, stays off for every iPad, and turns **off** for the unfolded Duo so the log
  behaves as on iPad.
- **`contentWidth` / `contentHeight` initial values**
  ([ContentView.swift:20-21](../Sources/Zudio/UI/ContentView.swift#L20-L21)): these read
  `UIScreen.main.bounds`, which Apple advises against on a two-display device. The root
  `GeometryReader` overwrites `contentWidth` on first appear, and `contentHeight` is not used on
  iOS, so this is low risk. Replace both initial values with a neutral constant (1024 and 768) for
  iOS. Optional; do it last, and skip it if anything looks off.

### What needs no change

- **`iPadTab` and its persistence.** It is `@State` in `ContentView`, initialised from
  `UserDefaults` key `iPadTabPersist` (only `tracks` is restored, anything else opens on
  Visuals), and written on change for Visuals and Tracks only. That already gives the specified
  behaviour: first unfolded launch on Visuals, Tracks only if chosen. Nothing to add.
- **The Tracks control** is the existing third button of `iPadTabStrip`
  ([ContentView.swift:809](../Sources/Zudio/UI/ContentView.swift#L809)). No new buttons.
- **Orientations.** `ZudioiOS` supports portrait and both landscapes for iPhone and iPad, sets no
  `UIRequiresFullScreen`, and targets device family 1,2. Nothing to change.
- **Audio.** `AppState` and `PlaybackEngine` sit above the views, so a layout swap does not touch
  the engine. Per the iOS minimal-fix rule, make no audio-path changes as part of this work.

### Behaviours to verify after building

Each is a short manual check on the Duo simulator. The device ID is in `check-duo.sh`; fold and
rotate from the Simulator window.

- **Regression first:** run the existing iPhone (portrait and Pro Max landscape) and iPad
  (full screen, and Split View) simulators and confirm none of them changed layout.
- **Unfolded opens on Visuals** with the iPad strip; Tracks shows the track view; Visuals returns.
- **Fold while on Tracks, then unfold:** returns to Tracks. Same for Visuals, Log and Songs.
- **Fold:** the phone layout shows no Tracks control and no way to reach one.
- **Playback never glitches across a fold or unfold**, including a mid-song fold.
- **No visible flicker through `PhonePlayerView`** during unfolding (the classes update one at a
  time for a few milliseconds).
- **Generate a song while folded, then unfold onto the Tracks tab.** `TrackRowView` is only
  instantiated on the Tracks tab, and per-song effect setup lives in its
  `onChange(of: defaultsResetToken)`. On iPhone that is mirrored in `PhonePlayerView`. Check that
  effects, instruments and mutes are correct after unfolding, and compare with how an iPad that
  generated a song while on the Visuals tab behaves today. If it differs, mirror the setup into
  `PhonePlayerView` as the existing iPhone fix does.
- **Export while folding:** audio export shows its progress overlay and share sheet from each
  branch separately ([ContentView.swift:575-600](../Sources/Zudio/UI/ContentView.swift#L575-L600)
  and `PhonePlayerView`). Confirm a fold mid-export neither loses the export nor the share sheet.
- **Outer display in landscape** (compact in both classes, 678 by 466 pt) looks right.
- **Audio route:** a fold does not post `AVAudioEngineConfigurationChange` or restart audio.

### Breakpoint tuning (the only open design work)

The opt-in track view on the inner display has a 669 pt window in portrait and 867 pt in
landscape. Portrait is narrower than iPad mini portrait (about 744 pt), so check that the track
rows, song info row and scrollbar row fit and that nothing clips or overlaps; extend the existing
ladder in [ContentView.swift](../Sources/Zudio/UI/ContentView.swift) (lines 58, 166-168, 664, 675)
with one more tier if needed. Landscape sits between the 800 pt and 950 pt thresholds like an iPad
mini landscape-ish width, so it should mostly work as is. Treat this as visual tuning after the
branch is in.

### Suggested order

1. Regression check on existing simulators (nothing should have moved before any edit).
2. The helper, `ContentView.body` and `StatusBoxView` edits, then build and run the verification list above.
3. Breakpoint tuning for the unfolded track view.
4. Optional: the `contentWidth` initial values.
5. Optional later extras: half-open posture with `ArrangementView`, fold-region handling for the
   MIDI grid.

---

## Implemented in 2.8

Version bumped to **2.8 (build 133)** in `Sources/Zudio/Info.plist` (Mac) and all six build
configurations in `project.pbxproj`. The iOS target takes its version from the pbxproj, since
`iOS-Info.plist` has no version keys.

### The layout switch (as specced)

- `usesPadLayout(idiom:h:v:)` in `ContentView.swift`: iPad layout when `idiom == .pad`, or when the
  window is regular in both size classes. `ContentView.body` picks `PhonePlayerView` otherwise.
- `StatusBoxView` pinch-to-resize guards use the same helper: on for iPhones and the folded Duo,
  off for every iPad and the unfolded Duo.
- `contentWidth` and `contentHeight` start at 1024 and 768 instead of `UIScreen.main.bounds`.
- `iPadTab` and its persistence needed no change.

### Narrow windows, under 700 pt wide

Found on the Duo simulator: the top bar keeps its natural width, which was wider than the 669 pt
unfolded portrait window. That pushed the whole screen to lay out too wide and be clipped, so the
Songs tab, the track effect buttons and the right end of the scrollbar row were all cut off.
Fixing the top bar fixes all of them. The gate is `kNarrowTopBarWidth = 700` in `TopBarView.swift`.

- **Mood and Key are removed** below 700 pt (the existing iPad mini portrait layout already
  fits at about 744 pt, so 700 leaves it alone).
- **Reset moves** from beside the style picker to beside BPM.
- **Help, About, Sleep and Share move** from a column at the right edge to a row under BPM and
  Reset, in space that was empty. The Sleep dialog attaches to the whole bar so it works in both
  placements.
- **Style picker** is 250 pt wide at 11 pt so "Ambient" shows in full. iPad mini portrait keeps
  220 pt at 10 pt.
- **Rows two and three** (BPM and Reset, then the Help row) share a 12 pt font and small controls
  through `NarrowTopBarRowStyle`, which does nothing above 700 pt.
- **Reset stays 80 pt wide.** A 64 pt version wrapped to "Re-set" and looked worse. Reset may be
  clipped slightly at the right edge at 669 pt, which Zack accepted.
- **Track rows** (`TrackRowView.rightPanelWidth`) use natural chip width under 700 pt instead of
  the fixed 232 pt panel used for iPad mini portrait, so the MIDI lane gets the room.
- **Empty-state message** ("Press Generate or Play to create a song") wraps to two lines under
  700 pt so it stays inside the narrower lane.

### Short windows, under 660 pt tall

Found on the Duo simulator in landscape: the window is 867 by 635 pt, so seven 63 pt track rows
(441 pt) plus the top bar, log and tab strip do not fit and the top and bottom rows were clipped.
The gate is `isShortWindow` in `ContentView.swift`: `contentHeight < 660`. All of the following
apply together:

- **Generation log hidden** on the Tracks tab (the same idea as the existing iPad mini landscape
  rule).
- **Action buttons** (Generate, Save, Load, Export) use small controls with 3 pt spacing, and the
  Help column spacing drops from 6 to 3 pt. `TopBarView` takes a `compactHeight` parameter.
- **Tab strip** is 28 pt instead of 36, with each icon beside its label instead of above it.
- **Track rows** are 57 pt instead of 63. `TrackRowView` takes a `rowHeight` parameter that
  defaults to 63. Seven rows at 57 pt is 399 pt. The row content needs about 53 pt, so there is
  little room to go lower.

### Size gates, not model gates

The compaction is driven by window size so that future small iPads, Split View, Slide Over and
Stage Manager windows get it too. The layout height is safe-area adjusted.

- **Under 700 pt wide:** narrow top bar, natural-width effect chips, two-line empty message. Full
  screen iPads start at about 744 pt (mini) and are unaffected. Split View and resizable windows
  that narrow are affected.
- **Under 660 pt tall:** log hidden, compact buttons, compact tab strip, 57 pt rows. Unfolded Duo
  landscape is 635 pt. iPad mini landscape is about 700 pt after insets (744 pt screen) and stays
  untouched, as does every larger iPad. The threshold is 660 and not 700 to keep a margin under
  iPad mini landscape, whose real figure has not been measured.
- **Still by model or layout choice:** `idiom == .pad` picks the iPad layout (so every iPad keeps
  it, including in Split View), and the log pinch gesture follows that choice. The older iPad mini
  landscape log rule (1050 to 1150 pt wide) is partly by model and was left alone.

### Split View and orientations

Verified in the project settings only, not at run time: all four iPad orientations are declared,
`UIRequiresFullScreen` is absent, the device family is 1,2, and the app is a SwiftUI `WindowGroup`.
Split View is therefore on in every orientation. The narrowest splits (about 320 to 375 pt) are
still too narrow for the top bar, which needs roughly 600 pt. Sending very narrow iPad windows to
`PhonePlayerView` was considered and rejected because iPads keep the iPad layout.

### Tested on a real iPhone Duo

Zack ran the build on an actual iPhone Duo and reported that it worked great, folded and unfolded.
That covers the layout switch, the narrow portrait top bar, the compact landscape Tracks view, and
Ambient showing in full in the style picker. Along the way the portrait top bar went through several
rounds on the device: Reset back to 80 pt after the narrower version wrapped to "Re-set", the Help
row kept under BPM, rows two and three unified at 12 pt, and the effect chips and MIDI lane
re-proportioned. The landscape Tracks view then needed the log hidden, smaller buttons, a shorter
tab strip and 57 pt rows to show all seven rows.

### Still open after device testing

- **Regression pass on existing devices.** Confirm nothing moved on iPad mini, Air and Pro in
  portrait and landscape, iPad Split View, and iPhone in portrait and Pro Max landscape. The edits
  are gated so they should not, but this has not been run. The Mac build was also not compiled
  separately; its changes are limited to the version bump and two defaults that do not change its
  layout.
- **Fold behavior.** Fold and unfold mid-song, on each tab, and mid-export: the tab should survive,
  playback should not glitch, and there should be no flicker through `PhonePlayerView`.
- **Status bar overlap.** In landscape the system clock and Wi-Fi icon draw over Help and About.
  The fix is a top inset on the top bar in that state. Not done.
- **Empty bottom band.** The dark band under the tab strip is probably the home-indicator safe area
  and was left alone.
- **Simulator crash.** A `PosterBoard` crash on the Duo simulator is an iOS system process, not
  Zudio. Erase that simulator device if it recurs.

---

## Measured values and what is still open

Two earlier questions are answered by the HIG:

- **Half-open posture: yes**, and `ArrangementView` in overlay mode handles it directly. The
  two views move to either side of the fold. Visualizer above the hinge and transport below is
  therefore cheap to try. It is an optional extra, not part of the 2.8 scope above.
- **Both displays at once: no.** Outer when closed, inner when open. Controls on one surface and
  the visualizer on the other is not available.

### Measured on the simulator, 2026-10-18

Read from a temporary probe in `ContentView` (since removed) on the iPhone Duo simulator,
Xcode 27.1 (27A9275), iOS 27.1. The scale is 3x on both displays and the idiom is `.phone` in
every state. Window sizes are safe-area adjusted.

- **Outer display (folded):** screen 466 by 678 pt. Window 382 by 644 pt in portrait, which is
  84 pt narrower than the screen (likely the system moving controls to the side). Size classes:
  compact width, regular height. In landscape (678 by 466 pt screen, 594 by 432 pt window) both
  classes are compact.
- **Inner display (unfolded), portrait:** screen 669 by 951 pt, window 669 by 835 pt. Size
  classes: **regular width, regular height.**
- **Inner display (unfolded), landscape:** screen 951 by 669 pt, window 867 by 635 pt. Size
  classes: **regular width, regular height**, confirmed by a fresh launch in that state.
- **The both-classes test works.** Folded is never regular in both, unfolded always is, in both
  orientations. Apple's specs page gives pixels only (inner 1878 by 2670 px at 430 ppi, outer
  1398 by 2034 px at 460 ppi); the 3x points above agree with a third-party write-up
  ([blakecrosley.com](https://blakecrosley.com/blog/iphone-duo-day-two)). An earlier estimate of
  626 by 890 pt for the inner display was wrong.
- **What it means for the breakpoint ladder:** inner portrait (669 pt window) is **narrower than
  iPad mini portrait** (about 744 pt) and under the 800 pt chip threshold, so it drops the Bar
  chip and shows no style chip. Inner landscape (867 pt window) clears the 800 pt style chip but
  not the 950 pt key chip. The opt-in track view is therefore a real tuning job in portrait and a
  minor one in landscape.

### Still open (measurements)

The size classes and display sizes above are measured. What remains unchecked after the real-device
test is listed under [Still open after device testing](#still-open-after-device-testing): the
regression pass, fold behavior, the landscape status-bar overlap, and the audio route on a fold.

---

## Prerequisites

Xcode 27.1 carries the iPhone Duo simulator. It has now shipped: Xcode here is 27.1 (27A9275) as
of **2026-10-18**. Check with:

```
xcrun simctl list devicetypes | grep -i duo     # empty = not shipped yet
```

---

## Priority

**Low for Zudio, higher elsewhere.** Zudio does little resizing between iPhone and iPad, so
today an unfolded Duo running the phone layout looks large rather than broken. That is
suboptimal, not a defect.
The real Duo risk is in **GalacticChessInvaders, Tahoe5 and Tahoe21**, which have considerably
more complex displays. Check those first, now that the simulator is available.

The counter-argument for doing Zudio anyway: the fix is small, the iPad layout already exists,
and the size-class branch is the correct code regardless of whether a Duo ever runs it.
