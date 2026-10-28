# iPhone Duo Plan

Status: **implemented in 2.8 (build 133) and tested on a real iPhone Duo, where it worked great.**
The layout switch, the narrow top bar and the short-window compaction are all in the code. What has
not been checked is listed under [Still open](#still-open). See [ios-ipad-plan.md](ios-ipad-plan.md)
for the platform view inventory this builds on.

---

## Release sequencing

- **2.7** — Chill Soho, a new Chill substyle. Generation-side only; no Duo work.
  See [chill-soho-plan.md](chill-soho-plan.md).
- **2.8** — the Duo release: folded and unfolded layouts. It is a UI-layer change, kept out of the
  generation-side releases so a regression in either is easy to attribute. The Duo simulator needs
  Xcode 27.1 (here 27A9275, iOS 27.1).

---

## The two modes

The fold is a **mode change, not a resize**. The rule: **a Duo unfolded is an iPad, and a Duo
folded is an iPhone.**

**Folded — an iPhone.** The cover display runs `PhonePlayerView`, unchanged: song title, transport
and the visualizer, with the Log tab. No MIDI grid, no per-track controls, and **no way to reach
the track view**, exactly as on every other iPhone.

**Unfolded — an iPad, with the track view as an option.** The inner display runs the iPad layout:
the four-tab strip (Visuals · Log · Tracks · Songs), the song info row and the scrollbar row. The
track view is compacted for the smaller window (see [Size gates](#size-gates)).

### Unfolded behaviour

- **First time unfolded:** opens on **Visuals**. Nothing switches to the track view automatically.
- **Track view is opt-in:** the Tracks control is the existing third button of the iPad tab strip.
  No Duo-specific buttons exist.
- **Folding:** switches to `PhonePlayerView`, with no Tracks control. Playback continues.
- **Unfolding again:** returns to the last unfolded tab (Visuals, Log, Tracks or Songs), because
  `iPadTab` is `@State` in `ContentView` and survives the swap.
- **Across launches:** the existing iPad rule applies. Only Visuals and Tracks are remembered
  (`UserDefaults` key `iPadTabPersist`); Log and Songs reopen on Visuals.
- **Folded state never changes the unfolded tab.**

No current iPhone gains the track view and none loses anything.

---

## How the layout is chosen

A Duo reports `userInterfaceIdiom == .phone` folded or unfolded, so an idiom test alone would give
the unfolded inner display the phone layout. The choice is therefore made from the size classes,
with the idiom kept as an iPad override:

```swift
func usesPadLayout(idiom:h:v:) -> Bool {
    idiom == .pad || (h == .regular && v == .regular)
}
```

It lives at the top of [ContentView.swift](../Sources/Zudio/UI/ContentView.swift) (iOS only).
`ContentView.body` picks `PhonePlayerView` when it returns false.

Why both classes, and why the idiom override:

- Width alone cannot be the detector. An iPhone Pro Max in landscape is regular width, and must stay
  on the phone layout.
- No iPhone is ever regular in both classes. The Duo's inner display always is.
- The idiom override keeps every iPad on the iPad layout, including compact-width Split View and
  Slide Over windows.

Resulting layouts:

- iPhone portrait (compact width, regular height): phone
- iPhone Pro Max landscape (regular width, compact height): phone
- Duo folded (compact width): phone
- iPad, any size or window: iPad
- Duo unfolded (regular, regular): iPad

The function is pure, so a momentary mid-fold class cannot do harm. The only surface whose layout
changed is the unfolded Duo, which had no earlier behaviour to preserve.

**Split View on the Duo's inner display:** at roughly half width the class turns compact, and since
the idiom is `.phone` it gets `PhonePlayerView`. That is intended: a half-width Zudio is an
iPhone-sized Zudio.

**Pinch-to-resize on the generation log** ([StatusBoxView.swift](../Sources/Zudio/UI/StatusBoxView.swift))
uses the same helper: on for every iPhone and the folded Duo, off for every iPad and the unfolded
Duo.

**Other code.** `contentWidth` and `contentHeight` start at 1024 and 768 on iOS instead of
`UIScreen.main.bounds`, which Apple advises against on a two-display device; the root
`GeometryReader` overwrites them on first appear. Audio is untouched: `AppState` and
`PlaybackEngine` sit above the views, so a layout swap does not reach them. Orientations needed no
change (portrait and both landscapes, no `UIRequiresFullScreen`, device family 1,2).

---

## Measured on the iPhone Duo simulator

Idiom is `.phone` and the scale is 3x in every state. Window sizes are safe-area adjusted.

- **Outer display (folded):** screen 466 by 678 pt. Portrait window 382 by 644 pt, compact width and
  regular height. Landscape window 594 by 432 pt, compact in both.
- **Inner display (unfolded), portrait:** screen 669 by 951 pt, window 669 by 835 pt, regular in both.
- **Inner display (unfolded), landscape:** screen 951 by 669 pt, window 867 by 635 pt, regular in both.

The inner portrait window is narrower than iPad mini portrait (about 744 pt), and the landscape
window is 635 pt tall, which is why the two size gates below exist.

---

## Size gates

The compaction is driven by window size, not model, so future small iPads, Split View, Slide Over
and Stage Manager windows get it too.

### Under 700 pt wide

The top bar keeps its natural width unless told otherwise, which would clip the Songs tab, the track
effect buttons and the scrollbar row on the 669 pt unfolded portrait window. The gate is
`kNarrowTopBarWidth = 700` in [TopBarView.swift](../Sources/Zudio/UI/TopBarView.swift). iPad mini
portrait (about 744 pt) is unaffected.

- **Mood and Key are removed.**
- **Reset moves** from beside the style picker to beside BPM, and stays 80 pt wide (a narrower one
  wraps to "Re-set"). It may be slightly clipped at the right edge at 669 pt, which is accepted.
- **Help, About, Sleep and Share** move from a right-edge column to a row under BPM and Reset. The
  Sleep dialog attaches to the whole bar so it works in both placements.
- **Style picker** is 250 pt wide at 11 pt so "Ambient" shows in full. iPad mini portrait keeps
  220 pt at 10 pt.
- **Rows two and three** (BPM and Reset, then the Help row) use a 12 pt font and small controls via
  `NarrowTopBarRowStyle`, which does nothing above 700 pt.
- **Track rows** (`TrackRowView.rightPanelWidth`) use natural chip width instead of the fixed
  232 pt panel, so the MIDI lane gets the room.
- **Empty-state message** ("Press Generate or Play to create a song") wraps to two lines.

### Under 660 pt tall

Seven 63 pt track rows plus the top bar, log and tab strip do not fit in the 635 pt landscape
window. The gate is `isShortWindow` (`contentHeight < 660`) in
[ContentView.swift](../Sources/Zudio/UI/ContentView.swift). All of these apply together:

- **Generation log hidden** on the Tracks tab.
- **Action buttons** (Generate, Save, Load, Export) use small controls with 3 pt spacing, and the
  Help column spacing drops from 6 to 3 pt. `TopBarView` takes a `compactHeight` parameter.
- **Tab strip** is 28 pt instead of 36, with each icon beside its label.
- **Track rows** are 57 pt instead of 63 (`TrackRowView.rowHeight`, default 63). Seven rows are
  399 pt. The row content needs about 53 pt, so there is little room to go lower.

iPad mini landscape is about 700 pt tall after insets and is untouched. The threshold is 660 to keep
a margin under it; that figure has not been measured.

### Breakpoints that were left alone

The existing width ladder still applies on the unfolded display. Portrait (669 pt) drops the "Bar"
chip and shows no style chip; landscape (867 pt) shows the style chip but not the key chip.
Reference points in `ContentView.swift`: song info chips at 800, 950 and 1100 pt (around line 187),
the iPad mini landscape range of 1050 to 1150 pt (line 72, which hides the log on Tracks), and the
mini-portrait "Bar" chip rule under 800 pt (line 704). The older mini landscape rule is by width
range and was not changed.

---

## What Apple's HIG adds

[Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
(published 9 September 2026) describes things this plan does not use but may later:

- **Vertical controls.** The outer display is wider and shorter than any iPhone, and the system may
  move bars to the side. `PhonePlayerView` is unchanged, but the display it renders on has an
  aspect ratio no other iPhone has.
- **Reserved regions.** When partially open, the folding region down the centre of the inner display
  should be avoided; `ReservedRegion` repositions custom content. It matters most for the full-width
  MIDI grid on the Tracks tab. Apple's guidance for grids is an even number of columns.
- **ArrangementView.** A SwiftUI container with a primary and a secondary view, in split or overlay
  arrangement; in overlay the views occupy either side of the fold when half open. Visualizer above
  the hinge and transport below is a cheap optional extra. Not in 2.8.
- **Both displays at once is not possible.** Outer when closed, inner when open.
- **Device Hub** in Xcode previews the Duo's poses.

---

## Still open

- **Regression pass on existing devices.** Confirm nothing moved on iPad mini, Air and Pro in
  portrait and landscape, iPad Split View, and iPhone in portrait and Pro Max landscape. The edits
  are gated so they should not, but this has not been run. The Mac build was not compiled
  separately; its changes are limited to the version bump.
- **Fold behaviour.** Fold and unfold mid-song, on each tab and mid-export. The tab should survive,
  playback should not glitch, there should be no flicker through `PhonePlayerView`, and a fold
  should not post `AVAudioEngineConfigurationChange` or restart audio. Export shows its progress
  overlay and share sheet from each layout separately (`isExportingAudio` in `ContentView` and
  `PhonePlayerView`), so confirm a fold mid-export loses neither.
- **Generate while folded, then unfold onto Tracks.** `TrackRowView` only exists on the Tracks tab,
  and per-song effect setup lives in its `onChange(of: defaultsResetToken)`, mirrored in
  `PhonePlayerView` on iPhone. Check that effects, instruments and mutes are correct after
  unfolding, and compare with an iPad that generated a song on the Visuals tab. If it differs,
  mirror the setup into `PhonePlayerView`.
- **Status bar overlap.** In landscape the system clock and Wi-Fi icon draw over Help and About. The
  fix would be a top inset on the top bar in that state.
- **Empty bottom band.** The dark band under the tab strip is probably the home-indicator safe area
  and was left alone.
- **Simulator crash.** A `PosterBoard` crash on the Duo simulator is an iOS system process, not
  Zudio. Erase that simulator device if it recurs.

---

## Version

**2.8 (build 133)** is set in `Sources/Zudio/Info.plist` (Mac) and all six build configurations in
`project.pbxproj`. The iOS target takes its version from the pbxproj, since `iOS-Info.plist` has no
version keys. `check-duo.sh` in the repo root reports whether a Duo simulator is installed.
