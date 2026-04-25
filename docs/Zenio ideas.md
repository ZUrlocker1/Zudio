# Zenio Ideas
Copyright (c) 2026 Zack Urlocker

## Overview
Zenio is intended as a follow up to Zudio as more of a fun groovebox app for Mac, iPad, iPhone. It should be more interactive, allowing the user to create songs.

## Competitive Landscape

### Closest Competitor: Ampify Groovebox (by Novation/Focusrite)

The most relevant benchmark for Zenio. Three built-in instruments: Drumbox (beat creator), Retrobass (analogue-style bass synth), and Poly-8 (8-voice poly synth). Hundreds of starter patterns included; more available as paid packs. The app gets a first-time user to something listenable in under 5 minutes — the lowest barrier to entry of any groovebox app.

**What it does well:** Beautiful visual design, instant gratification, strong Novation/Launchpad brand DNA, free to download.

**Where it falls short:** No song mode — you cannot chain patterns into a complete arrangement within the app. No MIDI learn, no user preset saving, no MIDI out. Deliberately limited to push users toward purchasing sound packs ($2–$5 each). Experienced users consistently describe it as too shallow for sustained use. The business model prioritizes monetization over depth.

**The Zenio opportunity:** An app that matches Ampify's ease of entry but adds chord-aware melodic sequencing, generative backing, and visual expressivity — without the artificial limitations — would occupy territory Ampify explicitly avoids.

---

### Beat-First Grooveboxes (drums + bass + synth + step sequencer)

- **Groove Rider GR-16 / GR-2 (JimAudio, $15–$35)** — The gold standard hardware-feel groovebox on iPad. Everything on one screen, Electribe-inspired. GR-2 (2025) adds 3-layer synthesis per part and a clip launcher. Best for users who want a hardware replacement; moderate learning curve.
- **Korg Gadget 3 (Korg, ~$40)** — 40+ mini synthesizers ("gadgets") that combine freely. Cross-platform iOS + Mac with the same purchase. Widest synth variety in the category; moderate complexity; some gadgets sold separately.
- **BLEASS Groovebox (BLEASS, ~$14)** — Solid mid-tier option with monosynth, poly synth, and drum machine. More MIDI-capable than Ampify; saveable presets; less deep than GR-16. A good middle ground that few people know about.
- **Drambo (BeepStreet, $20)** — Modular groovebox with 140+ modules, automatic cable routing, MI Plaits macro oscillator (24 Eurorack synth engines). The most powerful and flexible iOS groovebox; steep learning curve; for expert users only.

### Sampler-Based Beat Makers

- **Koala Sampler (Elf Audio, free + $7 IAP)** — Sample-based beat maker beloved by lo-fi and hip-hop producers. Record from mic, chop, sequence. Extremely fast workflow; no built-in synth engines; best for sample-based genres.
- **BeatMaker 3 (Intua, $25)** — The deepest sampler-DAW hybrid on iPad; 14 effect types, unlimited tracks, full AU parameter automation. Closest to a full desktop DAW on iPad; steep learning curve; no built-in synthesizer.

### Circular / Unconventional Sequencers

- **Patterning 3 (Olympia Noise Co., $15)** — Circular drum machine where each track is a ring rather than a grid row. Polyrhythm and odd meters feel natural in a way linear grids cannot match. Drum-only; pairs well with melodic apps. Now available on macOS.
- **Borderlands Granular** — No tempo, no grid, no steps. Place circular "cloud" players on waveforms and manipulate them by touch. Ambient and textural; closer to painting than programming.

### Full DAWs with Groovebox Modes

- **Logic Pro for iPad (Apple, $5/month)** — Full professional DAW with Live Loops (clip grid), Step Sequencer, and Beat Breaker. The only professional DAW on iPad with a genuine groovebox mode; shares project files with Logic Pro for Mac.
- **GarageBand for iPad (Apple, free)** — Apple's entry-level environment. Live Loops grid is groovebox-style. Free, excellent onboarding; not a professional tool; best as a starting point.
- **Ableton Live (Mac/Windows, $99–$749)** — The de facto standard for clip-based performance on Mac. Session View is the original software groovebox grid. Best hardware controller integration; overkill for casual use.
- **Bitwig Studio (Mac/Windows, from $99/year)** — Direct Ableton rival with a clip launcher plus a built-in modular system. Any parameter can have an LFO or step sequencer attached without a plugin. More flexible than Ableton for modular-style sound design.

### Custom / Looper Hybrid

- **Loopy Pro (A Tasty Pixel, $30)** — Fully customizable looper where you design your own performance surface from scratch. MIDI looping added in v2.0 (2025). No fixed UI — you assemble loops, buttons, sliders, XY pads as you like. Professional live performance tool; setup-heavy.

---

## Gaps — Where Zenio Could Live

The research points to a cluster of underserved needs that no single app addresses:

- **Chord-aware melodic sequencing** — almost no app guarantees harmonically correct results without music theory knowledge. Zudio already solves this.
- **Generative + interactive hybrid** — no app bridges beat production with evolving generative/probabilistic music in one approachable package. Wotja does generative ambient; GR-2 does beats; nobody does both.
- **Visual expressivity** — most groovebox UIs are functional grids. Very few make the music visible in an expressive or emotionally resonant way. Zudio's visualizer is already ahead of the field.
- **Long-form ambient + beat hybrid** — completely open territory; no product owns it.
- **Song mode / arrangement** — the most consistently cited gap across all apps. Most grooveboxes are excellent at creating loops but have no way to arrange those loops into a complete song within the same app.
- **iPad Pro screen real estate** — most apps were designed for smaller screens and simply scaled up. Few use the large iPad Pro display with a purpose-built layout.

**Positioning summary:** An app that matches Ampify's ease of entry, adds Zudio's chord-aware generation and visual style, and solves the song-mode gap would occupy territory that is genuinely unoccupied.

### Ampify History

Ampify grew entirely within Focusrite/Novation — it was never an outside acquisition. Around 2014 Focusrite set up a dedicated London app team called **Blocs**, which released the Novation Launchpad iOS app and Blocs Wave (a loop-slicing app). In June 2017 they launched Groovebox and rebranded the team to **Ampify Music**. Novation's hardware synth engineers contributed directly to the three synth engines. The app was well regarded at launch and genuinely distinctive. Around 2022 development stalled; since then it has received only periodic bug fixes with no new features. The community considers it effectively in maintenance mode — praised for sound quality, criticized for missing AUv3, MIDI out, preset saving, and a real song mode. Features users have been requesting for years that never arrived. A ready-made frustrated audience for a well-maintained competitor.

---

## Bouncing Ball Sequencer

Users place colored bars and targets on a canvas. Balls bounce around the space, hitting bars to trigger notes. The physics create natural syncopation and variation — no two bounces are ever quite the same.

User controls:
- Place, move, and resize bars (each bar = a pitch or instrument)
- Adjust gravity, ball speed, and number of balls
- Color of bar determines instrument family (e.g. blue = pads, red = lead, yellow = percussion)
- Bar angle affects note velocity or duration

Musical behavior:
- Ball hits trigger notes in the style's scale (same rule-based approach as Zudio)
- Multiple balls create polyrhythm naturally from their different trajectories
- Longer bars = sustained notes; short bars = staccato hits
- Balls can interact with each other (collide, split, merge)

Visual style: dark canvas, glowing balls with comet trails, bars that pulse on hit. Similar aesthetic to Zudio's visualizer.

Tech approach: SwiftUI Canvas + a simple physics engine (either a lightweight custom one or GameplayKit). AVAudioEngine + GeneralUser GS soundfont reused from Zudio.

---

## Cellular Automaton Music

A grid where the user draws an initial pattern of live cells. Conway's Game of Life (or a musical variant) evolves the grid each beat — each live cell triggers a note based on its grid position.

User controls:
- Draw initial cell pattern by tapping/clicking cells
- Choose grid size and evolution speed (tied to BPM)
- Assign rows or columns to pitches, instruments, or velocity tiers
- Pause, step forward one generation, or reset to initial state
- Save and share interesting starting patterns

Musical behavior:
- x-position = pitch (left = low, right = high)
- y-position = instrument or octave
- Cell density in a region = velocity (denser = louder)
- Stable patterns (still lifes, oscillators) create repetitive loops; gliders create melodic movement
- User can nudge a few cells while running to perturb the pattern

Interesting variant: use a musical rule set instead of Conway (e.g. a cell survives if it has 2–3 neighbors *in the same row* — creating more horizontal melodic lines than vertical noise).

Visual style: glowing grid cells, color-coded by instrument, fading trails as cells die.

Tech approach: pure Swift 2D array simulation, SwiftUI Canvas for rendering, same AVAudio stack as Zudio.

---

## Gesture / Paint-to-Music

Users draw on a dark canvas with their finger or mouse. The app scans the drawing left-to-right like a DAW playhead and plays back what was painted.

Gesture mappings:
- x-position = time (left = earlier, right = later)
- y-position = pitch (top = high, bottom = low)
- Stroke color = instrument (chosen from a palette before drawing)
- Stroke width = velocity / loudness
- Stroke speed while drawing = attack character (fast stroke = sharp attack)

User flow:
- Pick an instrument color from a sidebar palette
- Paint phrases, chords, rhythmic hits anywhere on the canvas
- Hit play — playhead scans left to right, triggering notes as it crosses strokes
- Loop, erase sections, overdub new layers in different colors
- Export as MIDI or audio

Layering: multiple passes can be painted on the same canvas in different colors, creating a visual score that is also the UI.

Visual style: the painted strokes glow softly on a black background; the playhead is a vertical line of light sweeping across. Notes light up as they trigger.

Tech approach: SwiftUI Canvas for drawing and playback rendering, stroke data stored as arrays of points, pitch quantized to scale on playback. Same AVAudio + soundfont stack as Zudio.
