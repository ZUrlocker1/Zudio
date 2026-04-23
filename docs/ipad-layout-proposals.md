# Zudio iPad Layout Proposals

These proposals start from the current Mac screen structure:

1. Top command/header area
2. Song summary strip
3. Track controls at left
4. Piano-roll / lane view in the center
5. Per-track effects at right
6. Generation log at bottom

The goal on iPad is not to shrink the Mac layout blindly. The goal is to preserve the same mental model while reallocating space for touch, thumb reach, and orientation changes.

---

## Shared iPad principles

- Keep the timeline as the visual center of the app.
- Keep transport and Generate always visible.
- Keep track identity visible at all times.
- Reduce simultaneous chrome before reducing musical visibility.
- Use larger touch targets than the Mac app.

### Touch target guidance

- Main buttons: 44-52 pt high
- Track mute / solo / regenerate: 36-44 pt minimum tap area
- Effect chips: 36-40 pt high minimum
- Instrument picker arrows: 36 pt minimum tap area
- Timeline scrub / zoom handles: 28 pt visual size, 44 pt hit area

### Recommended iPad section priorities

- Must always stay visible:
  - Transport
  - Generate
  - Style / Mood / Key / BPM
  - Timeline
  - Track names
- Can collapse or move to sheet:
  - Help / About
  - Full generation log
  - Secondary effect controls
  - Copyright text

---

## iPad Landscape Proposal A

This is the closest port of the Mac app. It works best for 11" and 12.9" iPad in landscape.

### Layout idea

- Keep the familiar three-zone editor
- Compress header chrome
- Keep the log docked at bottom
- Convert the right effects column into a narrower touch rail

### Wireframe

```text
+----------------------------------------------------------------------------------+
| Logo | Transport | Generate | Style | Mood | Key | BPM | Save | Reset | Menu   |
+----------------------------------------------------------------------------------+
| Song: Vortexe | Key: Bb Aeolian | Mood: Free | Time: 4:16 | Bars slider / zoom  |
+--------------------------+-------------------------------------------+-----------+
| Track sidebar            | Timeline / MIDI lanes                     | FX rail   |
|                          |                                           |           |
| Lead 1    Instrument     | [ full width scrolling piano roll ]       | Boost     |
| M S ⚡                    |                                           | Delay     |
| Lead 2    Instrument     |                                           | Space     |
| M S ⚡                    |                                           |           |
| Pads      Instrument     |                                           | per-track |
| M S ⚡                    |                                           | chip set  |
| Rhythm    Instrument     |                                           | aligned   |
| M S ⚡                    |                                           | to row    |
| Texture   Instrument     |                                           |           |
| M S ⚡                    |                                           |           |
| Bass      Instrument     |                                           |           |
| M S ⚡                    |                                           |           |
| Drums     Instrument     |                                           |           |
| M S ⚡                    |                                           |           |
+--------------------------+-------------------------------------------+-----------+
| Generation log preview                                                         |
| SONG / Form / Chords / Rules / Instruments ...                                 |
+----------------------------------------------------------------------------------+
```

### Recommended section sizing

- Header: 88-96 pt high
- Song strip: 40-44 pt high
- Track sidebar: 240-280 pt wide
- FX rail: 96-112 pt wide
- Log: 160-200 pt high, resizable

### Section adjustments

#### Top bar

- Shrink the logo versus Mac and make it decorative, not dominant
- Keep transport centered
- Put `Generate` beside transport, not on a second row
- Move `Help` and `About` into a single trailing `...` menu
- Replace desktop copyright text with nothing in the main UI

#### Song strip

- Keep title, key, mood, and song length in one compact strip
- Keep visible-bars slider here, right aligned
- Treat this row as a session summary, not a second toolbar

#### Track sidebar

- Preserve icon, track name, instrument, mute, solo, regenerate
- Stack `M`, `S`, and `⚡` horizontally with larger pill buttons
- Keep instrument name visible, but use tap-to-open picker instead of tiny arrows if needed

#### Timeline

- Give it the majority of horizontal space
- Keep the vertical row alignment with the track list and FX rail
- Preserve horizontal scrolling and playhead drag
- Increase line contrast slightly on iPad to compensate for finger occlusion

#### FX rail

- Keep only 2-3 most relevant effect chips per row
- Use abbreviated labels where needed
  - `Boost`, `Delay`, `Space`
  - `Pan`, `Low`, `Comp`
- Tapping a chip opens a per-track effect sheet or popover for deeper settings later

#### Log

- Show the newest lines only
- Add an expand handle or `Open Log` button for full-height reading
- Keep it docked in landscape because there is enough height

### Best use case

- Primary composing and browsing mode
- Best “desktop-like” iPad mode
- Best for users with Magic Keyboard or Apple Pencil nearby

---

## iPad Landscape Proposal B

This version is more touch-native. It reduces the permanent right rail and uses a contextual inspector.

### Layout idea

- Left track list stays visible
- Timeline gets more width
- Effects move into a slide-over inspector for the selected track

### Wireframe

```text
+----------------------------------------------------------------------------------+
| Logo | Transport | Generate | Style | Mood | Key | BPM | Save | Reset | Menu   |
+----------------------------------------------------------------------------------+
| Song strip / title / bars / zoom                                                |
+--------------------------+-------------------------------------------------------+
| Track list               | Timeline / piano roll                                 |
|                          |                                                       |
| Lead 1                   |                                                       |
| Lead 2                   |                                                       |
| Pads                     |                                                       |
| Rhythm                   |                                                       |
| Texture                  |                                                       |
| Bass                     |                                                       |
| Drums                    |                                                       |
+--------------------------+-------------------------------------------------------+
| Selected Track Inspector: Lead 1 | Instrument | FX chips | Output | More...     |
+----------------------------------------------------------------------------------+
| Generation log preview                                                          |
+----------------------------------------------------------------------------------+
```

### Why it may be stronger than Proposal A

- More space for notes and phrase shapes
- Cleaner touch behavior
- Better path for future iPad editing features
- Easier to extend later if iPhone shares the same inspector model

### Tradeoff

- Less immediate visibility of all per-track effects at once

---

## iPad Portrait Proposal A

This should be the default portrait mode. It accepts that the Mac three-column row will not scale well vertically.

### Layout idea

- Put the timeline first
- Collapse track controls into a compact left rail plus lower inspector
- Keep transport at the top
- Move the generation log into a half-height drawer

### Wireframe

```text
+--------------------------------------------------------------------+
| Logo | Play | Stop | Generate | Save | Menu                        |
| Style | Mood | Key | BPM | Zoom                                   |
+--------------------------------------------------------------------+
| Song: Vortexe | Bb Aeolian | Free | 4:16                           |
+---------+----------------------------------------------------------+
| Track   | Timeline / piano roll                                    |
| rail    |                                                          |
| L1      |                                                          |
| L2      |                                                          |
| Pd      |                                                          |
| Rh      |                                                          |
| Tx      |                                                          |
| Bs      |                                                          |
| Dr      |                                                          |
+---------+----------------------------------------------------------+
| Selected Track Card                                               |
| Lead 1 | Ocarina | M | S | ⚡ | Boost | Delay | Space              |
+--------------------------------------------------------------------+
| Log drawer handle: Generation Log                                  |
+--------------------------------------------------------------------+
```

### Recommended section sizing

- Header: 96-112 pt across two compact rows
- Song strip: 36-40 pt
- Track rail: 64-80 pt wide
- Selected track card: 88-120 pt high
- Log: collapsed by default, opens to 30-45% screen height

### Section adjustments

#### Top bar

- Break into two rows in portrait
- Row 1: transport and primary actions
- Row 2: style, mood, key, BPM, zoom
- Remove large decorative logo treatment

#### Track list

- Convert from full Mac-style track row labels to a narrow icon rail
- Show short labels:
  - `L1`, `L2`, `Pd`, `Rh`, `Tx`, `Bs`, `Dr`
- Active track is highlighted strongly

#### Selected track card

- This becomes the portrait replacement for both left and right desktop columns
- Shows:
  - full track name
  - instrument picker
  - mute / solo / regenerate
  - top effect chips
- This card can optionally expand to show additional settings

#### Timeline

- Still occupies the majority of the screen
- The track rail anchors vertical alignment
- Horizontal scroll remains essential

#### Log

- Default to collapsed
- Open as a drawer from the bottom
- In portrait, persistent full-height log wastes too much valuable editor height

### Best use case

- Browsing and auditioning while holding the iPad
- Casual generation and playback
- Fast track selection and comparison

---

## iPad Portrait Proposal B

This version is more “sectioned” and may feel friendlier for touch-first users who are less DAW-oriented.

### Layout idea

- Stack workspace into three major bands
- Top: controls
- Middle: timeline
- Bottom: horizontally scrollable track cards

### Wireframe

```text
+--------------------------------------------------------------------+
| Transport / Generate / Save / Menu                                 |
| Style / Mood / Key / BPM                                           |
+--------------------------------------------------------------------+
| Song summary strip                                                  |
+--------------------------------------------------------------------+
| Timeline / piano roll                                               |
|                                                                    |
|                                                                    |
|                                                                    |
+--------------------------------------------------------------------+
| Track cards: [Lead1] [Lead2] [Pads] [Rhythm] [Texture] [Bass] ...  |
| Selected card shows instrument, M/S/⚡, effects                     |
+--------------------------------------------------------------------+
| Log button / drawer                                                 |
+--------------------------------------------------------------------+
```

### Why this one is useful

- Easier to understand for users coming from touch music apps
- Stronger separation between “song overview” and “track operations”
- Track cards can be reused almost directly on iPhone later

### Tradeoff

- Less immediate row-to-row comparison against the timeline
- Feels less like a classic DAW

---

## Recommended direction

If Zudio wants to stay recognizably “DAW-like,” the strongest pair is:

- Landscape: Proposal A
- Portrait: Proposal A

That pair preserves the same mental model in both orientations:

- transport always top
- timeline always central
- track identity always visible
- effects available but not allowed to dominate the screen
- log still present, but less intrusive in portrait

If you want a more touch-native evolution that prepares for iPhone later, use:

- Landscape: Proposal B
- Portrait: Proposal B

---

## Concrete adaptations from the Mac screenshot

Based on the screenshot you shared, these specific changes should happen on iPad:

### Remove or reduce

- Oversized logo block at top left
- Permanent Help and About buttons
- Copyright line in the live workspace
- Full-width bottom log in portrait
- Full per-row right-side FX column in portrait

### Keep

- Track color coding
- One horizontal lane per track
- Visible transport cluster
- Visible song title and key/tempo summary
- Per-track regenerate control

### Convert

- Mac side effect column:
  - keep in landscape as narrow pills
  - move into selected-track card or inspector in portrait
- Instrument selector:
  - keep inline in landscape
  - move into selected-track card in portrait
- Generation log:
  - docked in landscape
  - drawer or sheet in portrait

---

## Suggested next design step

Build three SwiftUI preview targets before writing the full iPad port:

1. `ZudioPadLandscapePreview`
2. `ZudioPadPortraitPreview`
3. `ZudioPadTrackInspectorPreview`

That will let you validate spacing, hit targets, and information density before touching the full production layout logic.

---
Copyright (c) 2026 Zack Urlocker
