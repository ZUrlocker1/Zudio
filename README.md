# Zudio

Zudio is a generative music app for macOS. It generates complete multi-track songs in one click using human-curated musical rules derived from analyzing real artists rather than machine learning.

It supports four styles: **Ambient** (Brian Eno, Loscil, Craven Faults), **Chill** (Moby, St Germain), **Kosmic** (Tangerine Dream, Jean-Michel Jarre, Electric Buddha Band), and **Motorik** (Neu!, Kraftwerk). Songs are built from 7 tracks (Lead, Pads, Bass, Drums, etc.) with deterministic seed-based variation. Sometimes it even sounds like music! 

![Zudio screenshot](assets/images/Zudio%20099%20screenshot.jpg)

You can generate a song at a time, or use Endless mode for continuous listening. Songs can be saved and reloaded. Related MIDI files can be loaded into any DAW for further editing. 

Rules were developed by analyzing tracks from artists across those styles. The resulting songs were analyzed by AI to spot generation errors, tone clashes etc and then further improve the rules. 
The app includes built-in effects such as reverb, delay, auto-pan and sweep. You can export both MIDI and M4A audio.

This repository contains the macOS app source, implementation notes, and supporting design documentation all developed using Claude. 

**Listen to a sample (Ambient style):** [The-ChatGPT-Meditations](https://soundcloud.com/zurlocker/zudio-ambient) on SoundCloud

**Watch a 5-minute demo (All styles):** [Zudio Demo](https://www.youtube.com/watch?v=xWLq9HVswmo) on YouTube

[Download for macOS](https://github.com/ZUrlocker1/Zudio/releases/download/v1.0.2/Zudio-1.0.dmg)

Current release: `1.0` (build 108). Universal binary — runs natively on both Apple Silicon and Intel Macs. Download the DMG disk image file, open it, and drag Zudio to your Applications folder.

---

## Documentation

### Core

- [Zudio preso.pdf](docs/Zudio%20preso.pdf) — 5 min presentation slides on Zudio created by Claude.
- [Zudio-article-v09.docx](docs/Zudio-article-v09.docx) — Overview article covering the project motivation, genre research methodology, AI-assisted specification process, iterative development, and honest assessment of the results.
- [architecture.md](docs/architecture.md) — System overview, technology stack, generation pipeline, playback engine, UI architecture, and musical foundations. Start here.
- [development-plan.md](docs/development-plan.md) — Staged development roadmap from v0.1 through future versions.
- [implementation.md](docs/implementation.md) — Detailed implementation reference: UX specification, musical rules, generation pipeline, rule ID catalog, and performance engineering notes.
- [Zudio design prompts.rtf](docs/Zudio%20design%20prompts.rtf) — ChatGPT prompts for the initial research, design and specification of Zudio.
- [zudio code prompts.rtf](docs/zudio%20code%20prompts.rtf) — Claude prompts for most of the coding of Zudio.

### Style guides

- [motorik-plan.md](docs/motorik-plan.md) — Motorik style: genre research, song analysis, universal rules, and complete implemented specification (drums, bass, pads, leads, voicings).
- [kosmic-plan.md](docs/kosmic-plan.md) — Kosmic style: genre research, artist-by-artist analysis, universal rules, MIDI analysis findings, and complete implemented specification.
- [ambient-plan.md](docs/ambient-plan.md) — Ambient style: genre research, artist-by-artist analysis, universal rules, generator design, and MIDI analysis.
- [chill-plan.md](docs/chill-plan.md) — Chill style: genre research, artist-by-artist analysis (St Germain, Moby, Air, DJ Cam Quartet, Electric Buddha Band), universal rules, generator design, and MIDI analysis.

### Analysis and quality

- [musical-coherence-plan.md](docs/musical-coherence-plan.md) — Methods and findings from analyzing generated output for musical coherence; derived rule improvements.
- [automated-quality-loop-plan.md](docs/automated-quality-loop-plan.md) — Design for an automated batch generation and analysis pipeline for Chill: tonal clash detection, density targets, beat style verification, phrase structure, and regen variation testing.
- [optimization-plan.md](docs/optimization-plan.md) — Performance engineering research and CPU optimization techniques.
- [comps.md](docs/comps.md) — Comparable generative music applications: feature analysis and product notes.

### Feature plans

- [save-as-audio-plan.md](docs/save-as-audio-plan.md) — Audio export (M4A) feature design. (Done)
- [continuous-play.md](docs/continuous-play.md) — Continuous play and song evolution mode design. (Done)
- [distribution-plan.md](docs/distribution-plan.md) — macOS distribution and release plan. (Done)


### Future platform

- [ios-ipad-plan.md](docs/ios-ipad-plan.md) — iOS and iPad port planning, design considerations, and architecture notes.
- [ipad-layout-proposals.md](docs/ipad-layout-proposals.md) — iPad UI layout proposals and sketches.
- [sample-library-plan.md](docs/sample-library-plan.md) — Research on upgraded sound banks (Fluid R3 and alternatives) for improved instrument quality.
