# Motorik Starter Patterns (V1)

These files provide starter musical content for code generation.

- Format: JSON
- Grid: 16 steps per bar (1 step = 1/16 note)
- `step`: zero-based step index from start of pattern
- `len`: duration in steps
- `vel`: MIDI velocity (0-127)
- Pitched tracks use degrees relative to the active harmonic context:
  - `1, 2, b3, 3, 4, b5, 5, b6, 6, b7, 7`
  - `oct`: octave offset relative to track register center
- Chord-relative roles:
  - `R` = chord root, `3` = chord third, `5` = chord fifth, `7` = chord seventh

Hallogallo tab-derived variants:

- `bass-starters-hallogallo-v1.json`
- `rhythm-starters-hallogallo-v1.json`
- `lead2-starters-hallogallo-v1.json`

These were translated from a tab-driven MIDI reference in:

- `/assets/midi/references/hallogallo-tab/hallogallo-tab-translation.mid`

Use these as stylistic motif/pulse vocabulary; keep final harmony/key from the generated song context.

Super 16 tab-derived variants:

- `rhythm-starters-super16-v1.json`
- `progression-templates-super16-v1.json`

Reference MIDI:

- `/assets/midi/references/neu-super16-tab/neu-super16-tab-translation.mid`

These provide fast guitar-chug rhythm vocabulary and a section-level chord-flow template.

Generation rule:
1. Pick a starter pattern/template for each track.
   - For Lead 1 solos, prefer `lead1-solo-starters-v2.json` phrase starters, then mutate.
   - Optional cross-style rhythmic vocabulary:
     - `silly-love-songs-derived-v1.json` provides section-based Rhythm/Bass/Texture/Drums phrases extracted from a user-supplied reference MIDI.
2. Map degrees/roles to concrete MIDI notes from song key, mode, and chord map.
3. Apply section mutations (density, fills, accents, note substitutions) using prototype rules.
4. Render resulting notes as MIDI events for playback.

Reference source MIDI:

- `/assets/midi/references/wings-silly-love-songs/Wings - Silly Love Songs.mid`
