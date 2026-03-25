# Zudio Development Stages

- This document describes the stages of development for Zudio, a generative music application
- More details are defined in `implementation.md`.

## Initial version goals

In scope for the initial working version:

- One-click song generation
- Motorik style only
- Track-level regenerate
- Transport controls (play, stop, later add reverse, fast forward etc)
- Per-track mute/solo
- Per-track instrument cycling
- Piano-roll style lane visualization (display only; no note editing in v1)
- Music is randomized by applying different rules for different tracks
- MIDI export (Type-1 multi-track file to /Downloads)
- Use built-in Apple MIDI instruments

After version 0.5 is stable add:

- Additional musical styles one at a time (Kosmic, then Ambient)
- Full per track audio effects
- More complex song structures e.g. A - B - Bridge etc
- Improved MIDI instruments
- Continuous play evolution mode

## Stage plan

- **0.1 Drums & Bass, UX foundation**
  - Build:
    - Drums & Bass generation engine and playback
    - Drum and bass lane visualization
    - Minimal functional UI for play, stop, generate, mute / solo and regenerate track
    - Non-functioning track effects
    - Select different Drum kit or bass instruments, e.g. rock kit, electronic kit, electric bass, synth bass, etc.
    - Define the song structure, e.g. length, tempo, key, mood
    - Generate a proper Motorik / Apache beat track
    - Use different rules for variations in the beat, e.g.
      - DRUM-001 classic Motorik beat
      - DRUM-002 more open beat
      - BASS-001 motorik bass line
      - BASS-002 more complex bass
  - Build rules by examining classic Motorik songs or Motorik adjacent songs from Neu!, Kraftwerk, Electric Buddha Band etc
  - Create a minimal UI with transport controls (stop, play, other functions greyed out), buttons for generate
  - Test gate:
    - Playback stable; lane updates correctly on generate/play
    - Bass and drums in sync
    - Regeneration applies different random rules for Drums, Bass

- **0.2 Add Pads, Rhythm, Textures**
  - Build additional tracks that follow the song structure, key and chords
  - Each has its own rules built from analyzing songs
    - TEXT-001 light shimmer etc
    - PADS-001 motorik pads
  - Select the appropriate pool of instruments for each track, e.g. different pad or synth styles

- **0.3 Add Leads**
  - Build:
    - Lead 1 generation and playback
    - Lead 1 lane visualization
    - Lead 1 instrument cycling baseline
    - Primary minimal melody in Lead 1
    - Use Lead 2 to complement or echo Lead 1
    - Define a set of rules for Leads
    - Define instrument pool for Lead 1 and Lead 2

- **0.4 Add Effects, MIDI Save, Test mode**
  - Build:
    - Add audio effects for Boost, Reverb, Delay etc using Apple's built-in sound capabilities
    - Create some track specific effects, e.g. Compression on Drums, Low Filter on bass
    - Save the current song as a MIDI file for review or editing in a DAW
    - Define a test mode that generates shorter songs and puts recently changed rules in high rotation

- **0.5 Sound engine upgrade**
  - Build:
    - Replace the existing built-in Apple MIDI sound bank with the open source GS User MIDI sound bank
    - Bundle the soundbank into the application

- **0.6 Add Kosmic style**
  - Build a new song style Kosmic derived from Jean-Michel Jarre, Tangerine Dream, Electric Buddha Band etc
  - This should allow more complex structures, A-B, A-B-A, A-B-A-B, A-B-Bridge-A etc
  - Introduce Kosmic specific rules for each track
  - Use Kosmic specific instruments for the tracks
  - Have Claude analyze Kosmic tracks and adjust generation rules

- **0.7 Audio export and performance optimization**
  - File export to save song or a 60 second sample as an M4A audio file
  - Periodically ask Claude to optimize generation and playback to consume less CPU
  - Test, test, test!

- **0.8 Analyze songs**
  - Add a text file representation of songs (based on the log messages) so that the MIDI file and text log file can be analyzed by Claude
  - Identify problems in the generation phase as well as musical clashes
  - Develop additional rules for making the songs more coherent, e.g. more coordination around song structure, leads, etc
  - Tune the rules and code as appropriate
  - Repeat two or three times

- **0.9 Add Ambient style**
  - Build a new song style Ambient derived from Eno, Loscil, Craven Faults etc
  - Simulate varying length loops for playback rather than structured A-B sections
  - Minimal use of drums, sparse arrangements
  - Introduce Ambient specific rules
  - Use a mix of natural sounding instruments with some synths, e.g. cello, latin percussion, etc
  - Rerun Claude analysis on Ambient songs

- **Possible future development**
  - Adding more rules for improved harmony, coherence and musicality
  - Upgrade MIDI instruments to Fluid R3 MIDI sound bank
  - Continuous play / evolution mode
  - iPad and/or iPhone version
