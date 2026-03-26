# Zudio

Zudio is a generative music app for macOS. It generates complete multi-track songs in one click using human-curated musical rules derived from analyzing real artists rather than machine learning.

It supports three styles: **Motorik** (Neu!, Kraftwerk, Harmonia), **Kosmic** (Tangerine Dream, Jean-Michel Jarre, Vangelis, Electric Buddha Band), and **Ambient** (Brian Eno, Loscil, Craven Faults). Each song is built from 7 simultaneous tracks (`Lead 1`, `Lead 2`, `Pads`, `Rhythm`, `Texture`, `Bass`, `Drums`) with deterministic seed-based variation. Sometimes it even sounds like music!

Rules were developed by analyzing tracks from artists across those styles. The resulting songs were analyzed by AI to spot generation errors, tone clashes etc and then further improve the rules. 
The app includes built-in effects such as reverb, delay, auto-pan and sweep. You can export both MIDI and M4A audio.

This repository contains the macOS app source, implementation notes, and supporting design documentation all developed using Claude. 

![Zudio screenshot](assets/images/logo/Zudio%20091a%20screenshot.jpg)

**Listen to a sample (Ambient style):** [A-Transformative-Meeting-About-Quarterly-Targets](https://soundcloud.com/zurlocker/zudio-ambient) on SoundCloud

[Download for macOS](https://github.com/ZUrlocker1/Zudio/releases/download/v0.92a/Zudio-0.92a.dmg)

Current release: `0.92a (alpha)`. This build is unsigned, so macOS Gatekeeper will likely show warnings the first time you open it.

To run it anyway, download the DMG, install the app, then right-click the app in Finder and choose `Open`. macOS will show a warning dialog, but that path lets you bypass the initial block and launch the app.

---

## Documentation

### Core

- [Zudio-article-v09.docx](docs/Zudio-article-v09.docx) — Overview article covering the project motivation, genre research methodology, AI-assisted specification process, iterative development, and honest assessment of the results.
- [architecture.md](docs/architecture.md) — System overview, technology stack, generation pipeline, playback engine, UI architecture, and musical foundations. Start here.
- [development-plan.md](docs/development-plan.md) — Staged development roadmap from v0.1 through future versions.
- [implementation.md](docs/implementation.md) — Detailed implementation reference: UX specification, musical rules, generation pipeline, rule ID catalog, and performance engineering notes.

### Style guides

- [motorik-plan.md](docs/motorik-plan.md) — Motorik style: genre research, song analysis, universal rules, and complete implemented specification (drums, bass, pads, leads, voicings).
- [kosmic-plan.md](docs/kosmic-plan.md) — Kosmic style: genre research, artist-by-artist analysis, universal rules, MIDI analysis findings, and complete implemented specification.
- [ambient-plan.md](docs/ambient-plan.md) — Ambient style: genre research, artist-by-artist analysis, universal rules, generator design, and MIDI analysis.

### Analysis and quality

- [musical-coherence-plan.md](docs/musical-coherence-plan.md) — Methods and findings from analyzing generated output for musical coherence; derived rule improvements.
- [optimization-plan.md](docs/optimization-plan.md) — Performance engineering research and CPU optimization techniques.
- [comps.md](docs/comps.md) — Comparable generative music applications: feature analysis and product notes.

### Feature plans

- [save-as-audio-plan.md](docs/save-as-audio-plan.md) — Audio export (M4A) feature design. (Done)
- [continuous-play.md](docs/continuous-play.md) — Continuous play and song evolution mode design.
- [distribution-plan.md](docs/distribution-plan.md) — macOS distribution and release plan.

### Future platform

- [ios-ipad-plan.md](docs/ios-ipad-plan.md) — iOS and iPad port planning, design considerations, and architecture notes.
- [ipad-layout-proposals.md](docs/ipad-layout-proposals.md) — iPad UI layout proposals and sketches.
- [sample-library-plan.md](docs/sample-library-plan.md) — Research on upgraded sound banks (Fluid R3 and alternatives) for improved instrument quality.
