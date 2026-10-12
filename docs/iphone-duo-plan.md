# iPhone Duo Plan

Status: **planned for 2.8.** Not started — the simulator does not exist yet.

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
- **2.8** — the Duo release. Folded and unfolded layouts, and nothing else that needs to ship
  urgently alongside it.

Keeping Duo out of 2.6 and 2.7 is deliberate. Both are generation-side releases that want to be
judged on how they sound; the Duo work is a UI-layer change that wants a device in hand. Mixing
them would make a regression in either harder to attribute. The Duo also gates on Xcode 27.1,
which has not shipped, so it is the release with an external dependency and belongs last.

---

## The two modes

The fold is treated as a **mode change, not a resize**. Zudio is a generative player: you set a
song going and listen. That maps onto a foldable more directly than most apps.

**Folded — listening.** The cover display gets a player and nothing else: song title, transport,
and the visualizer. No MIDI grid, no per-track controls, no track rows. This is close to the
existing `PhonePlayerView` and may end up being exactly it, or a trimmed version of it.

**Unfolded — working.** The inner display gets the iPad layout: the four-tab strip
(Visuals · Log · Tracks · Songs), the song info row, seven track rows with mute/solo and effect
chips, and the scrollbar row. This is where a track gets regenerated, an instrument changed or
an effect toggled — the things that need width.

Both layouts already exist and are good. 2.8 is mostly about **choosing between them correctly**,
not about designing anything new.

The folded layout is the existing iPhone one, unchanged. No current iPhone gains the track view
and none loses anything — see the constraint under Approach.

---

## Why the current code gets it wrong

A Duo reports `userInterfaceIdiom == .phone`, but its inner display is **regular in both size
classes** — iPad-shaped. Every branch below therefore picks the phone layout when unfolded, and
would stretch a full-screen player with no track controls across a tablet-sized screen.

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
2.6. Apple's guidance is to branch on size class rather than idiom, which is also what makes the
fold work without a device-specific check — though it has to be both size classes, not width
alone. See Approach.

---

## Approach

**Hard constraint: no existing iPhone behaviour changes.** Every current iPhone keeps
`PhonePlayerView` in both orientations. iPhones do not have the room for the track view, that
was settled long ago, and this work does not revisit it. The Duo folded is an iPhone for these
purposes and gets the same treatment.

That rules out branching on `horizontalSizeClass` alone. An iPhone Pro Max in landscape is
**regular width**, so a horizontal-only test would push existing phones into the iPad layout —
precisely the change that must not happen.

The distinguishing property is that the Duo's inner display is **regular in both size classes**.
No iPhone is ever regular in both:

- iPhone portrait — compact width, regular height → phone layout
- iPhone Pro Max landscape — regular width, **compact height** → phone layout, unchanged
- Duo folded — compact width → phone layout
- iPad, any orientation — regular width, regular height → iPad layout
- Duo unfolded — regular width, regular height → iPad layout

So the test is both together:

```swift
hSizeClass == .regular && vSizeClass == .regular   // iPad layout
                                                   // everything else: PhonePlayerView
```

This reproduces today's behaviour exactly on every shipping device — the only surface whose
layout changes is the Duo unfolded, which has no current behaviour to preserve. That is the
property to verify first when the simulator lands: run the existing iPhone and iPad simulators
and confirm nothing moved.

**Risk: Apple's guidance is width-only, and does not confirm the vertical class.** The HIG says
*"a compact width layout for the outer display and a regular width layout for the inner display
give you the fundamentals for every pose"* — it never states that the inner display is regular
*height*. If the inner display reports **compact height** in landscape, the test above never
fires and the Duo silently gets the phone layout. That is a quiet failure, not a visible one.

Width alone is still ruled out by the hard constraint, so the both-classes test stays. But the
vertical class is now the **first thing to measure**, not an assumption. If it turns out to be
compact, the fallback is a width test with an explicit idiom or screen-size exclusion for
existing phones — uglier, and only if forced.

The same test replaces the idiom checks in `StatusBoxView`, where the pinch-to-resize gesture on
the generation log is currently gated to phones and should follow the layout rather than the
device.

## What Apple's HIG adds

[Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
was published 9 September 2026. Three things in it were not anticipated here.

**Vertical controls.** The outer display is **wider and shorter** than any current iPhone, and
the system moves toolbars, tab bars and navigation controls to the **side** to preserve vertical
space. On the inner display they stay on the side in landscape, for continuity across the fold.

This does not breach the constraint above — `PhonePlayerView` is still unchanged — but it
qualifies "folded is just the existing iPhone layout". The *view* is unchanged; the display it
renders on has an aspect ratio no shipping iPhone has, and the system may re-place bars beneath
us. Something to check on the simulator, not to redesign for.

**Reserved regions, including the fold.** When the device is partially open, the **folding
region** is a reserved area down the centre of the inner display that content should avoid.
`ReservedRegion` (SwiftUI) repositions custom content around it. This matters most for the
**MIDI grid**, which spans the full width and would be bisected. Apple's guidance for grids is
an **even number of columns** so content divides cleanly either side of the fold.

**ArrangementView.** A new SwiftUI container holding a primary and a secondary view, laid out as
either *split* or *overlay*. In an overlay arrangement, the two views **move to occupy either
side of the fold** when the device is partially open. That is the half-open posture idea below,
available as a system container rather than something to build.

Also worth knowing:

- **Device Hub in Xcode** previews an app in the Duo's poses, which may allow a first look before
  the 27.1 simulator lands
- The inner display supports **Split View multitasking**, so Zudio could run at roughly half the
  inner width — narrower than anything the current breakpoint ladder handles
- The framing throughout is *"you're still designing for iPhone"*, which matches the approach
  taken here

---

## What the work actually is

Not continuity. `AppState` and `PlaybackEngine` are `ObservableObject`s held above the view
layer, so a size-class change rebuilds views without touching the audio engine or the scheduler.
And the iPad layout already switches between Tracks and Visuals through its own tab strip, with
playback continuing across the switch — folding and unfolding asks nothing of it that the tab
strip does not already do every time the user taps a tab.

The one genuinely new thing is **running the track view on a smaller regular-width display**. The
MIDI grid was built for the Mac and adapted to iPad; the Duo unfolded would be an even narrower
regular-width surface than iPad mini.

That is a tuning job, not a design problem, and the mechanism already exists. `ContentView`
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

The thing to confirm rather than assume is the **unfolded width in points**, which decides
whether anything needs to change at all. If it lands near iPad mini portrait, it may already be
handled.

## Open questions — need the simulator

Two earlier questions are now answered by the HIG:

- **Half-open posture: yes**, and `ArrangementView` in overlay mode handles it directly — the
  two views move to either side of the fold. Visualizer above the hinge and transport below is
  therefore cheap to try.
- **Both displays at once: no.** Outer when closed, inner when open. Controls on one surface and
  the visualizer on the other is not available.

Still open:

- **What vertical size class does the inner display report?** The one that decides whether the
  layout branch fires at all. See the risk note under Approach.
- What is the **unfolded width in points**, and the **outer display's** dimensions? The first
  decides how much of the breakpoint ladder needs extending; the second decides whether
  `PhonePlayerView` needs anything at all.
- Does folding change the **audio route** — a foldable may have different speaker arrangements
  open and closed, which would post `AVAudioEngineConfigurationChange` and run `restartAudio()`
  mid-song. A quick check rather than an expected problem, but the one audio question the fold
  genuinely raises.

These are assumptions to check, not established facts. Nothing in this plan should be built on
them until the simulator is in hand.

---

## Prerequisites

Xcode 27.1 carries the iPhone Duo simulator. As of **2026-10-09** it has not shipped; Xcode here
is 27.0 (27A266a). Check with:

```
xcrun simctl list devicetypes | grep -i duo     # empty = not shipped yet
```

---

## Priority

**Low for Zudio, higher elsewhere.** Zudio does little resizing between iPhone and iPad, so an
unfolded Duo running the phone layout looks large rather than broken — suboptimal, not a defect.
The real Duo risk is in **GalacticChessInvaders, Tahoe5 and Tahoe21**, which have considerably
more complex displays. Check those first when the simulator lands.

The counter-argument for doing Zudio anyway: the fix is small, the iPad layout already exists,
and the size-class branch is the correct code regardless of whether a Duo ever runs it.
