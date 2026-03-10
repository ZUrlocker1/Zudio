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

Generation rule:
1. Pick a starter pattern/template for each track.
2. Map degrees/roles to concrete MIDI notes from song key, mode, and chord map.
3. Apply section mutations (density, fills, accents, note substitutions) using prototype rules.
4. Render resulting notes as MIDI events for playback.
