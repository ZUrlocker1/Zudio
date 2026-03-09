# Zudio Starter Pack Research (Motorik-Focused)

Purpose: identify free/open assets for a v1 starter pack aligned with the Motorik palette.

## License tiers used in this list

- `CC0`: safest for app bundling and redistribution.
- `CC-BY-4.0`: usable if attribution is implemented in app/docs.
- `Royalty-free (custom terms)`: usable for production; verify redistribution rights per pack before shipping.

## Recommended baseline for v1

- Prefer `CC0` assets first.
- Use `CC-BY` when needed (for example a better rock drum kit), with explicit attribution handling.
- Avoid unclear/custom licenses in the initial shipped pack.
- If curated assets are missing for a track, use Apple DLS (General MIDI) as a temporary fallback sound source during prototyping.

## Licensing decision (locked)

- Approved for v1: `CC0 + CC-BY-4.0`.
- Attribution policy for CC-BY: include attribution in both:
  - in-app About/Credits screen
  - repository documentation (`README` or `ATTRIBUTION.md`)

## Drums (v1 target: 2 kits)

1. Vintage Electronic Kit
- Source: FreePats `Electric and Synthesizer Percussion`
- Link: https://freepats.zenvoid.org/Percussion/electric-percussion.html
- License: CC0
- Why fit: explicitly designed as vintage electronic drum approximations.

2. Rock Kit
- Source: DrumGizmo `DRS Kit` (SFZ port)
- Link: https://sfzinstruments.github.io/drums/drs_kit/
- License: CC-BY-4.0
- Why fit: acoustic rock kit profile, good complement to electronic kit.

Alternative rock-ish option (CC0):
- Karoryfer `Big Rusty Drums`
- Link: https://shop.karoryfer.com/pages/free-big-rusty-drums
- License: verify on pack page before import (Karoryfer libraries often list permissive terms, but confirm per pack)

## Bass (>=3 options)

1. `Lately Bass` (TX-style)
- Link: https://freepats.zenvoid.org/Synthesizer/synth-bass.html
- License: CC0

2. `Synth Bass #1`
- Link: https://freepats.zenvoid.org/Synthesizer/synth-bass.html
- License: CC0

3. `Synth Bass #2` (DX-style)
- Link: https://freepats.zenvoid.org/Synthesizer/synth-bass.html
- License: CC0

Optional electric bass layer:
- `Clean Electric Bass` (Bass Guitar YR)
- Link: https://freepats.zenvoid.org/ElectricGuitar/clean-electric-bass.html
- License: CC0

## Lead 1 (>=3 options)

1. `Synth Fifths`
- Link: https://freepats.zenvoid.org/Synthesizer/synth-lead.html
- License: CC0

2. `Synth Bass & Lead`
- Link: https://freepats.zenvoid.org/Synthesizer/synth-lead.html
- License: CC0

3. `Clean Electric Guitar #1` (processed as mono lead)
- Link: https://freepats.zenvoid.org/ElectricGuitar/clean-electric-guitar.html
- License: CC0

## Lead 2 (>=3 options)

1. `Synth Brass #1`
- Link: https://freepats.zenvoid.org/Synthesizer/synth-brass.html
- License: CC0

2. `Synth Brass #2`
- Link: https://freepats.zenvoid.org/Synthesizer/synth-brass.html
- License: CC0

3. `Synth Bass & Lead` (thin high-register mapping)
- Link: https://freepats.zenvoid.org/Synthesizer/synth-lead.html
- License: CC0

## Pads (>=3 options)

1. `Synth Pad Choir`
- Link: https://freepats.zenvoid.org/Synthesizer/synth-pad.html
- License: CC0

2. `New Age` (Synth Pad 1)
- Link: https://freepats.zenvoid.org/Synthesizer/synth-pad.html
- License: CC0

3. `Sweep Pad` (Synth Pad 8)
- Link: https://freepats.zenvoid.org/Synthesizer/synth-pad.html
- License: CC0

Optional extension:
- `Synth Strings #1/#2`
- Link: https://freepats.zenvoid.org/Synthesizer/synth-strings.html
- License: CC0

## Rhythm (>=3 options)

1. `Clean Electric Guitar #1`
- Link: https://freepats.zenvoid.org/ElectricGuitar/clean-electric-guitar.html
- License: CC0

2. `Clean Electric Guitar #2 (Jazz)`
- Link: https://freepats.zenvoid.org/ElectricGuitar/clean-electric-guitar.html
- License: CC0

3. `Synth Lead` pulse source (short-gate mapping)
- Link: https://freepats.zenvoid.org/Synthesizer/synth-lead.html
- License: CC0

## Texture (>=3 options)

1. `Synth Goblins`
- Link: https://freepats.zenvoid.org/Synthesizer/synth-effects.html
- License: CC0

2. `Synth Soundtrack`
- Link: https://freepats.zenvoid.org/Synthesizer/synth-effects.html
- License: CC0

3. 99Sounds texture pack element (prototype-friendly)
- Link: https://99sounds.org/sounds/
- License: royalty-free under pack terms (verify redistribution constraints)

## Additional open source instrument pool

- Karoryfer free libraries index
- Link: https://shop.karoryfer.com/pages/free-samples
- Important note: confirm each library's license on its own page before bundling.

- SFZ Instruments index (license catalog)
- Link: https://sfzinstruments.github.io/
- Use fit: quickly identify CC0/CC-BY SFZ instruments by category.

## Proposed v1 import set (minimal and sufficient)

- Drums: FreePats Electric Percussion (CC0), DRS Kit (CC-BY) or Big Rusty Drums (CC0 fallback)
- Bass: Lately Bass, Synth Bass #1, Synth Bass #2 (all CC0)
- Lead 1: Synth Fifths, Synth Bass & Lead, Clean Electric Guitar #1 (all CC0)
- Lead 2: Synth Brass #1, Synth Brass #2, Synth Bass & Lead (all CC0)
- Pads: Synth Pad Choir, New Age, Sweep Pad (all CC0)
- Rhythm: Clean Electric Guitar #1/#2, Synth Lead pulse source (all CC0)
- Texture: Synth Goblins, Synth Soundtrack, one vetted royalty-free texture source

## Fallback option if any track is under-supplied

- Use Apple built-in General MIDI bank via Apple DLS Music Device for temporary placeholder sounds:
  - Drums: Standard/Room kits
  - Bass: Synth Bass programs
  - Leads: Synth Lead programs
  - Pads: Synth Pad/Strings programs
- Replace DLS placeholders with curated CC0/CC-BY assets as they are validated.
