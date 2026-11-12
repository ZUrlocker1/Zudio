# Zudio

Zudio is a generative music app for macOS. It generates complete multi-track songs in one click using human-curated musical rules derived from analyzing real artists rather than machine learning.

It supports four styles: **Ambient** (Brian Eno, Loscil, Craven Faults), **Chill** (Moby, St Germain), **Kosmic** (Tangerine Dream, Jean-Michel Jarre, Electric Buddha Band), and **Motorik** (Neu!, Kraftwerk) each with their own substyles. Songs are built from 7 tracks (Lead, Pads, Bass, Drums, etc.) with deterministic seed-based variation. Sometimes it even sounds like music! 

![Zudio screenshot](assets/images/Zudio%20099%20screenshot.jpg)

You can generate a song at a time, or use Endless mode for continuous listening. Songs can be saved and reloaded. Related MIDI files can be loaded into any DAW for further editing. 

Rules were developed by analyzing tracks from artists across those styles. The resulting songs were analyzed by AI to spot generation errors, tone clashes etc and then further improve the rules. 
The app includes built-in effects such as reverb, delay, auto-pan and sweep. You can export both MIDI and M4A audio.

This repository contains the macOS app source, implementation notes, and supporting design documentation all developed using Claude. 

**Listen to a sample (Chill style):** [Cadillac Memorandum](https://soundcloud.com/zurlocker/chill) on SoundCloud

**Watch a 5-minute demo (All styles):** [Zudio Demo](https://www.youtube.com/watch?v=WlyzVsseVH8) on YouTube

[Download for macOS](https://github.com/ZUrlocker1/Zudio/releases/download/v2.9/Zudio-2.9.dmg) &nbsp; [Available for iPhone, iPad](https://apps.apple.com/us/app/zudio-music/id6762574335)

The download is `2.9` (build 136), a near final version with Kosmic Space and the new lead rules (below). Version 2.9 is nearly complete, with minor tuning expected over a few days of listening, and is likely to be posted on the App Store for iPhone and iPad by mid November. Universal binary — runs natively on both Apple Silicon and Intel Macs. Download the DMG disk image file, open it, and drag Zudio to your Applications folder.

**v2.9 Kosmic Space:** A new Kosmic substyle modelled on Jean-Michel Jarre. It has a locked sequencer over fast minor chord cycles, the Minipops preset rhythm box, a falling theme answered by a see-saw riff, string-machine pads and white-noise surf sweeps. Each part draws from several rules derived from his songs. Details are in the [Kosmic Space plan](docs/kosmic-space-plan.md).

**new lead rules for Kosmic and Motorik:** New more musical Lead 1 and Lead 2 rules replace some of the original rules in base Motorik and base Kosmic. Each plays a hook or answer taken from a real record, reworked per song rather than copied. There is also more coordination between Lead 1 and Lead 2. Roughly three in four base Motorik songs and over half of base Kosmic songs now use a new or lightly changed Lead 1 rule. Details are in the [Solo improvement plan](docs/Solo-improvement-plan.md).

**Jazz solos for Chill:** Chill's Lead 1 now plays licks from jazz tunes, including Moanin', Cantaloupe Island, Blue Monk, My Funny Valentine, Song for My Father and Blue Bossa. They are reworked per song rather than copied, and three generic random-walk rules are gone. Four of the rules play three ideas in a solo: the head, a contrasting tune and a line from a real solo by Chet Baker, Kenny Dorham, Lee Morgan, Miles Davis or Sonny Rollins. Like a player, the solo keeps coming back to the head. Lead 2 now answers Lead 1 like a second soloist trading phrases, picking up its last notes, its rhythm or its last word, and in a stop-time breakdown the soloist joins the band's climb. Details are in the [Chill jazz leads plan](docs/chill-jazz-leads-plan.md).

**Smoother Track View:** The playhead now glides across the lanes at the display's refresh rate instead of stepping, and the visualizer does less redundant drawing, both of which should lower CPU use. Details are in the [change log](docs/change-log.md).

**What's new — v2.8 iPhone Duo:** Zudio now has a layout made for the iPhone Duo, the foldable iPhone. Tested on a real Duo. Folded, it is the iPhone player it always was. Unfolded, it is the iPad layout, opening on Visuals with the track view one tap away on the Tracks tab. Fold and unfold mid-song and playback carries on.

- **Fits the unfolded screen in portrait** — the top bar drops Mood and Key, moves Reset beside BPM, and puts Help, About, Sleep and Share in a row under it, so every control is on screen and Ambient is spelled out in full. The track rows give the MIDI lane the room back
- **Fits the unfolded screen in landscape** — the generation log steps aside on the Tracks tab, the buttons and tab strip are a little smaller, and the track rows are a little shorter, so all seven tracks are visible at once
- **Chosen by window size, not by device** — the same compact layouts apply to iPad Split View, Slide Over and resizable windows, and to any future small iPad. Every current iPad and iPhone looks as it did
- **More flexible Endless** — tap a style to choose the next song's style
- **Better audio recovery** after Bluetooth and route changes
- **Multitasking on iPad** — tested on iPad simulators: Zudio runs alongside other apps in a smaller window, in Split View and in resizable floating windows. It works, with some clipping at certain widths
- Details are in the [iPhone Duo plan](docs/iphone-duo-plan.md)

**Also in this download — v2.7 Chill Soho:** A new Chill substyle modelled on the sophisti-pop records of Sade, Everything But The Girl, The Style Council, Simply Red and Roxy Music. Its rules were measured from MIDI transcriptions of those songs rather than described in prose, and almost nothing is shared with base Chill:

- **Latin and soul grooves** — bossa, samba and half-time ballad patterns, with congas, bongos, shakers and surdo layered over the kit, and an intro that builds a layer at a time
- **Jazz harmony** — 6th, 7th and 9th chords instead of triads, and a separate chord cycle for the B section. Each phrase ends on a four-bar turnaround that the whole band plays: the bass leads back to the top, the drums take a fill, the horns mark it and the shaker drops out. The bass has six ways of playing it, from a walking line to a root pedalled under a descending one, and a song draws two or three of them so its turnarounds are neither all alike nor all different
- **Horns on the Texture track** — trumpet, trombone and muted trumpet figures that land with the drum accents, struck once, twice or three times with their own rhythm, or long sustained halo notes above the pads, with vibraphone and xylophone for colour
- **Leads that sound sung** — phrases built from figures measured in the vocal lines and horn parts of the original records, played on sax, flute or recorder, with a second horn answering in the gaps. A solo has a hook: its opening phrase comes back through the song, about half the time as it was and otherwise with a note added, dropped or moved, so it is recognisable without being a copy. 
- **Solos that sit on the beat** — across every Chill song the leads are pulled into line with the rhythm section, so a phrase lands with the band rather than against it, and the notes of a phrase run into one another instead of being clipped short. Ordinary syncopation is left alone — where the groove anticipates a beat, the solo anticipates with it
- **A laid-back soul groove** — on the soul songs the bass sits 10 ms and the drum backbeat (side stick, snare, clap) 20 ms behind the beat, with the kick and hats on the grid, the relaxed pocket of the Sade and Style Council records. Playback and exported audio both have it. Latin songs stay on the grid. Some Chill Blues songs (those on the pickup, quarter-pulse, root or walking bass) get a lighter version of it
- **A Remix Break** — a short house-flavoured section mid-song, the band dropping into four-on-the-floor and hitting its way back out
- **Guitar-led rhythm** — Nylon, Jazz and Funk guitar carry most of the comping, with Rhodes and piano
- **Blue notes in Chill Blues** — in some songs the soloist slips a blue note between the 4th and 5th, rarely and over the home chord, and the log reports "blues scale"
- **Lower CPU use** — on a Mac Zudio now typically uses 15–20% CPU, and 5–10% in the compact view with no visualizer
- **Bug fixes** — audio textures, saved songs, and Endless and Evolve playback, including a dropout when Evolve changes phase on Chill Blues and Soho songs and smoother animation in the Track View


Earlier releases are covered in the [change log](docs/change-log.md).


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
- [kosmic-space-plan.md](docs/kosmic-space-plan.md) — Kosmic Space: the Jean-Michel Jarre substyle, its corpus measurements, harmony families, rules by track, and the ideas closed or on hold.
- [Solo-improvement-plan.md](docs/Solo-improvement-plan.md) — Hook-based Lead 1 and gap-answer Lead 2 rules for base Motorik and Kosmic: what is built, what is next, and the source cells.
- [ambient-plan.md](docs/ambient-plan.md) — Ambient style: genre research, artist-by-artist analysis, universal rules, generator design, and MIDI analysis.
- [chill-plan.md](docs/chill-plan.md) — Chill style: genre research, artist-by-artist analysis (St Germain, Moby, Air, DJ Cam Quartet, Electric Buddha Band), universal rules, generator design, and MIDI analysis.
- [chill-jazz-leads-plan.md](docs/chill-jazz-leads-plan.md) — Chill's jazz lick Lead 1 rules: the tunes and solos they come from, the three-theme form, shares, and open items.

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
- [iphone-duo-plan.md](docs/iphone-duo-plan.md) — iPhone Duo support: folded and unfolded layouts, the narrow-window and short-window size gates, and what was tested on a real Duo. (Done)
- [sample-library-plan.md](docs/sample-library-plan.md) — Research on upgraded sound banks (Fluid R3 and alternatives) for improved instrument quality.
