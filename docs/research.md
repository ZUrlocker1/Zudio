# Zudio Research Evidence

## Scope and ownership

This document is evidence only.

- It captures source-backed observations and analysis outputs.
- It does not define implementation rules or app behavior.
- Implementation rules and UX requirements are owned by `prototype.md`.
- Build sequencing is owned by `development-plan.md`.

## Method summary

Research inputs used:

- Literature/context sources on Motorik and related artists.
- Track-level listening and feature extraction.
- Local MP3 analysis using Apple `AVFoundation` via Swift scripts.

Primary extraction categories:

- tempo/pulse behavior
- intro/outro behavior
- section continuity and change frequency
- density and dynamic-shape proxies
- melodic contour proxies (interval/repetition tendencies)

Method limits:

- Full-mix analysis only (no stems, no MIDI session data).
- Numeric outputs are proxies, not exact transcriptions.

## Source references

- Motorik overview: https://en.wikipedia.org/wiki/Motorik
- Neu! historical context: https://en.wikipedia.org/wiki/Neu%21
- Neu! interview context: https://www.uncut.co.uk/features/neu-how-we-made-hallogallo-34624/
- Dinger/Apache beat context: https://www.washingtonpost.com/music/2022/09/23/neu-michael-rother-motorik/
- Harmonia context: https://en.wikipedia.org/wiki/Harmonia_%28band%29
- Harmonia Deluxe context: https://en.wikipedia.org/wiki/Deluxe_%28Harmonia_album%29
- Kraftwerk Tour de France Soundtracks context: https://en.wikipedia.org/wiki/Tour_de_France_Soundtracks
- MIDI Association General MIDI overview: https://midi.org/general-midi
- MIDI Association General MIDI 2 overview: https://midi.org/general-midi-2
- Roland GM2 rhythm set naming/program mapping reference: https://cdn.roland.com/assets/media/pdf/Fantom-G_Soundlist.pdf
- Open Music Theory, embellishing tones: https://viva.pressbooks.pub/openmusictheory/chapter/embellishing-tones/
- Open Music Theory, species counterpoint: https://viva.pressbooks.pub/openmusictheory/chapter/species-counterpoint/
- Open Music Theory, motives and transformations: https://viva.pressbooks.pub/openmusictheory/chapter/motive/
- Journal of Experimental Psychology (melodic expectancy): https://pubmed.ncbi.nlm.nih.gov/9377644/
- Earworm melodic-feature study summary (Goldsmiths): https://research.gold.ac.uk/id/eprint/17510/
- PNAS earworm study record: https://www.pnas.org/doi/10.1073/pnas.1612226114

Third-party tempo/key reference examples (approximate):

- Hallogallo: https://songbpm.com/@neu/hallogallo
- Fur Immer: https://songbpm.com/@neu/fur-immer
- Neuschnee: https://getsongbpm.com/song/neuschnee/3MMX2
- Harmonia Deluxe: https://www.shazam.com/song/1201079037/deluxe-immer-weiter
- Harmonia Walky Talky: https://www.shazam.com/song/1201079038/walky-talky
- Autobahn: https://songbpm.com/@kraftwerk/autobahn
- Aero Dynamik: https://songbpm.com/@kraftwerk/aero-dynamik
- Endless Endless: https://songbpm.com/@kraftwerk/endless-endless

## Corpus analyzed

### Canonical Motorik and adjacent

- Neu!: `Hallogallo`, `Fur Immer`, `Neuschnee 78`, `Seeland`, `Wave Mother`
- Harmonia: `Deluxe (Immer Wieder)`, `Walky-Talky`, `Monza (Rauf Und Runter)`
- Cluster: `Breitengrad 20`, `Hollywood`

### Creator reference set (Electric Buddha Band)

- `Time Loops`
- `Dark Sun`
- `Vanishing Point`
- `Into The Night`
- `Blakely Lab`
- `Schulers Dream 05`

## Measured evidence snapshots

### Neu!/Harmonia/Cluster (structure and pulse)

- `Hallogallo`:
  - duration ~607s
  - strong sustained pulse regularity
  - long intro behavior
  - long continuity blocks with controlled transitions
- `Fur Immer`:
  - duration ~678s
  - strong sustained pulse regularity
  - long intro behavior
  - long-form continuity with sparse large transitions
- `Neuschnee 78`:
  - duration ~153s
  - tighter/shorter form than Hallogallo/Fur Immer
  - still pulse-forward but with stronger melodic focus
- `Seeland`:
  - slower/looser pulse profile than strict Motorik core
  - long ambient-like continuity windows
- `Wave Mother`:
  - medium pulse regularity
  - slower/adjacent profile with broader atmospheric behavior
- `Deluxe` / `Walky-Talky` / `Monza`:
  - repetition-forward continuity with section-level timbral changes
  - evidence for long-form pulse-first development
- `Breitengrad 20` / `Hollywood`:
  - low-density and static-vamp behavior evidence
  - strong support for sparse and long-hold harmonic sections

### Creator set (Electric Buddha) - structure and melodic contour

- `Dark Sun` / `Time Loops`:
  - stronger use of repeated-tone melodic cells plus occasional larger leaps
  - supports hook design with repetition-first then accent intervals
- `Schulers Dream 05`:
  - lower melodic onset density and long stable spans
  - supports sparse lead mode and long continuity windows
- `Blakely Lab`:
  - restrained density with clear block-level structure
  - supports minimal embellishment behavior over core groove

## Cross-corpus evidence conclusions

### Rhythm section evidence

- Core Motorik identity is carried by persistent pulse continuity.
- Kick/snare backbone stability is more important than frequent pattern rewrites.
- Variation is most effective in hats/cymbal articulation, accents, and occasional fills.
- Bass coherence improves when onset behavior follows drum intensity and phrase boundaries.
- GM/GS drum-set evidence supports using `Power` as a rock-leaning default and `Electronic` as the electronic alternative in a two-kit v1 setup (inference from GM2 kit naming/program families).

### Harmony and pad evidence

- Harmonic movement is usually slower than rhythmic movement.
- Long static or two-chord windows are common and stylistically credible.
- Sparse harmonic rhythm and restrained re-voicing preserve motorik trance effect.

### Melody and countermelody evidence

- Lead material is most convincing when motif-first and repetition-heavy.
- Countermelody is more successful as delayed, lower-density response than co-lead.
- Vertical clarity improves with register separation and reduced simultaneous accents.

### Scale evidence

- Minor-family and modal-minor colorations appear most compatible with target corpus.
- Pentatonic reduction is effective as a conflict-reduction fallback in dense sections.

## Ambient and melodic-ambient evidence notes

Jarre/Eno-related corpus research indicates:

- Ambient coherence benefits from slower variation cadence.
- Harmonic shifts are often gradual, with texture taking a larger structural role.
- Melodic density caps are important to avoid over-busy ambient outputs.

(Implementation-specific adaptation remains in `prototype.md`.)

## Confidence and gaps

Confidence by category:

- high: pulse architecture, long-form continuity patterns, rhythm-section interaction direction
- medium: exact tempo center boundaries (half-time vs double-time representation can differ)
- medium: exact harmonic labels from full-mix audio without transcription

Remaining gaps:

- No stem-level decomposition of individual parts.
- No bar-by-bar symbolic transcription.

## Data reproducibility

Local analysis tooling:

- `tools/audio-analysis/analyze-mp3-music.swift`

Output location convention:

- Choose an output path per run (for example in a temporary working directory or a local analysis folder).

## Pass 2 lead-focused evidence (March 10, 2026)

Analysis run:

- `xcrun swift tools/audio-analysis/analyze-mp3-music.swift --json docs/analysis-motorik-lead-pass2.json ...`
- Output file: `docs/analysis-motorik-lead-pass2.json`
- Corpus in this pass: 13 tracks (Neu!/Harmonia/Cluster + Electric Buddha set)

Measured aggregate snapshot (from the JSON output):

- Canonical set (Neu!/Harmonia/Cluster, n=7):
  - mean BPM proxy: ~129.43
  - mean pulse regularity: ~0.689
  - mean subdivision regularity: ~0.523
  - mean density proxy: ~1812.56
  - mean intro ratio: ~9.1% of track length
  - mean outro ratio: ~1.1% of track length
  - mean section-count proxy: ~7.29
- Creator set (Electric Buddha, n=6):
  - mean BPM proxy: ~127.61
  - mean pulse regularity: ~0.585
  - mean subdivision regularity: ~0.355
  - mean density proxy: ~1541.57
  - mean intro ratio: ~2.6% of track length
  - mean outro ratio: ~4.8% of track length
  - mean section-count proxy: ~4.33

Lead-oriented observations from this pass (evidence interpretation):

- Canonical references show higher subdivision regularity and higher density proxies than the creator set, supporting longer continuity-driven lead arcs over short repeated fragments.
- Creator-set tracks exhibit shorter intros and comparatively larger outro windows, which supports delayed lead entry and clearer lead de-intensification near endings.
- Higher section-count proxies in canonical tracks support multi-phrase solo development over long timelines instead of short loop-only lead behavior.

## Additional web evidence for melodic hooks and solo continuity

- Embellishing-tone evidence (Open Music Theory) supports placing non-chord tones mainly as controlled passing/neighbor events with stepwise resolution behavior.
- Counterpoint motion evidence (Open Music Theory) supports using contrary/oblique movement and avoiding excessive parallel lockstep when two lead lines are active.
- Motive-development evidence (Open Music Theory) supports systematic variation methods (sequence, inversion, rhythmic change, expansion/compression) for maintaining identity while avoiding repetition fatigue.
- Melodic-expectancy evidence (Journal of Experimental Psychology) supports stepwise continuation and directional recovery after leaps as listener-coherent continuation behavior.
- Earworm-feature evidence (Goldsmiths/PNAS record) supports memorable hooks using mostly simple contours plus selective distinctive intervals and repetition.

Inference boundary:

- These web sources support general melodic cognition/composition behavior.
- Motorik-specific adaptation remains an implementation-layer decision in `prototype.md`.
