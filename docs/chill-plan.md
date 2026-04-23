# Chill Style Generator — Research & Design Plan
Copyright (c) 2026 Zack Urlocker

## Context

Zudio has Motorik (krautrock), Kosmic (Berlin School), and Ambient (Eno/drone). This is the
fourth style: **Chill** — rooted in 1990s nu-jazz, acid jazz, and chill-out, as exemplified
by St Germain, DJ Cam Quartet, and the Rebirth of Cool era. The plan covers musical research,
generator design, and architecture.

The UI style dial will become: **Motorik → Kosmic → Ambient → Chill**.

The target is **urban jazz-influenced downtempo** — sophisticated, laid-back, nocturnal. Live
jazz instrumentation (Rhodes, flute, muted trumpet, vibraphone, saxophone) over electronic or
brushed-kit beats. The emotional temperature is cool, introverted, cosmopolitan — music for a
late-night Paris jazz bar or a rooftop at dusk.

Chill has two moods depending on the sub-flavor:
- Deep/Dream moods → trip-hop adjacent (DJ Cam, Portishead influence): electronic beats,
  straight 4/4, minor tonality, darker and more cinematic
- Bright/Free moods → nu-jazz (St Germain influence): brushed kit, light swing, flute-led,
  brighter and more buoyant

---

## Part 1: What Is "Chill"? — Genre Definition

Chill-out emerged in the early 1990s as the music played in the "chill-out room" at UK rave
events — the space to decompress from the main dance floor. By the mid-1990s it had matured
into a distinct genre fusing acid jazz, trip-hop, and lounge revival.

Key characteristics distinguishing Chill from the other Zudio styles:
- **vs Motorik:** Much slower; no driving kick pulse on every beat; jazz harmony not modal
  repetition; lead instruments are wind/keyboard rather than synth
- **vs Kosmic:** Has a groove and recognizable song structure; chord changes every 4–8 bars
  not every 15–20; melodic lead lines are prominent; shorter and more song-like
- **vs Ambient:** Has a beat and a felt groove; structured sections; leads are melodic not
  textural; much higher note density per track

The harmonic DNA comes from modal jazz — specifically Miles Davis's Kind of Blue (1959), which
established the template: one mode, static harmonic field, solo improvisation over the top,
slow or absent chord changes. Nu-jazz absorbed this into an electronic production context.

---

## Part 2: Artist-by-Artist Analysis

### St Germain — The Defining Voice

Albums studied: Tourist (2000), Boulevard (1995)

**Rose Rouge (Tourist, 2000):**
- BPM: ~95 (straight 4/4, programmed electronic beats)
- Key: D minor / D Dorian
- Structure: intro (Rhodes + beats) → groove with James Brown vocal sample → flute solo →
  return to groove → extended outro
- Duration: 8 min 22 sec — one of the longest tracks on the album
- The flute line is the melodic hook: a syncopated 4-bar phrase that repeats with variation
- Rhodes comps on syncopated off-beats (not on the 1 and 3)
- Bass: deep, round, mostly root notes with occasional approach tones; sits in the
  40–60 Hz range; likely acoustic bass sampled or fretless
- Beats: programmed 4/4 with a subtle hip-hop influence; snare on 2 and 4; hi-hat
  16th-note pattern; kick is not on every beat (syncopated)
- Harmony: essentially static (one chord/mode throughout); all movement comes from the
  soloists and the vocal sample

**Sure Thing / Montego Bay Spleen (Boulevard, 1995):**
- BPM: ~88 BPM
- Key: F minor / F Dorian
- Heavier electronic beats; more trip-hop influence; less sunshine than Tourist
- Rhodes more prominent; flute less present; bass more active

**MIDI analysis — St Germain "So Flute" (118 BPM, G Dorian, 101 bars):**
Analyzed directly from the MIDI file. Key findings:
- Kick: four-on-the-floor, every beat (steps 0, 4, 8, 12) — pure driving pulse
- Snare: backbeat only, steps 4 and 12 (beats 2 and 4)
- Ride (note 59): steady 8th notes on all odd steps (0,2,4,6,8,10,12,14), ~5.6/bar
- Bass: strict 8th-note ostinato, every note exactly 2 steps (one 8th), cycling G#→G→F→D;
  50% on-beat / 50% off-beat; 5.6 notes/bar — a mechanical but driving pulse
- Piano: 4-note chords, exactly 2 strikes per bar at steps 0 and 6 (beat 1, AND of beat 2);
  velocity locked at 89; register B2–F4
- Flute: ~7.5 staccato 16th-note bursts per bar, average 1 step duration; 81% staccato;
  G-centric (47% of notes); almost no rests within phrases
These findings directly drove CHL-DRUM-008, CHL-BASS-007, corrected CHL-RHY-001 step
positions (0 and 6, not 3 and 11), and CHL-LD1-005 (sparse staccato version of the flute).

**Generative lessons from St Germain:**
- The groove is almost completely static harmonically — one mode, one implied chord
- All interest comes from surface: flute melody, vocal sample (can't do in MIDI),
  Rhodes comping pattern, subtle beat variations
- Rhodes comps on beat 1 and the AND of beat 2 — not the AND of beats 1 and 3 as
  initially assumed; confirmed from direct MIDI analysis
- Flute is much denser and more staccato than the sparse phrase model used for other
  Chill lead rules — a continuous flutter, not discrete phrases
- Bass is a strict 8th-note ostinato cycling chord tones — not root sustain or syncopated
- Song duration is long: 6–10 minutes. The groove is the journey.

---

### DJ Cam Quartet — The Darker Side

Albums studied: The Rebirth of Cool (2002), Substances (1996)

**Character:**
- Quartet format: drums, bass, vibraphone, Rhodes/piano
- More cinematic, less sunny than St Germain
- BPM: ~80–92; occasionally dipping to 75 for the heaviest moods
- Minor tonality (Aeolian or Dorian); no major-mode tracks in the darker material
- Vibraphone used as the primary melodic/chordal voice alongside Rhodes
- Beats more acoustic-sounding (brushed kit) despite the hip-hop influence

**Harmonic approach:**
- Two-chord oscillation is common: i → bVII or i → iv, repeating for the entire track
- Chord changes at 4 or 8-bar boundaries — slow but not glacial
- Jazz voicings: all chords are at least 7ths; minor9 appears frequently
- Melody uses the full Dorian scale including the characteristic raised 6th (the note
  that distinguishes Dorian from Aeolian and gives it its "bittersweet" quality)

**Generative lessons from DJ Cam Quartet:**
- Vibraphone as both comping instrument AND primary lead voice — it can play sustained
  chord stabs AND single-note melodic lines in the same song
- Two-chord progression is musically sufficient for 6+ minutes if the surface is rich
- The brushed drum kit must have room — it should never be dense; space is everything
- Minor9 chord voicings (root, b3, 5, b7, 9) are the signature sound

---

### The Rebirth of Cool Compilations — The Acid Jazz Scene

Compilations studied: Rebirth of Cool 4 (1994), Rebirth of Cool 5 (1996)

**Brand New Heavies:**
- BPM: ~95–102; funk-jazz crossover
- Bright major keys (G major, C major); more New Jack Swing influence
- Brass section (muted trumpet, alto sax) as the arrangement's highlight
- Represents the Bright/Free end of the spectrum

**Incognito:**
- BPM: ~90–100; British acid jazz
- Key: Often D minor, F minor, Bb major
- Mode: Dorian for minor tracks; Ionian for the major ones
- Rhodes + strings + horns; very lush production
- Two-chord and three-chord progressions; more harmonic movement than St Germain

**US3 "Cantaloop":**
- BPM: ~94; straight 4/4 with hip-hop beats + jazz samples
- Blue Note Records samples over hip-hop beats — the formula for nu-jazz
- Flute sample (Herbie Hancock) used as the melodic hook

**Generative lessons from the acid jazz scene:**
- Bright moods use muted trumpet and alto sax; heavier moods use flute and vibraphone
- Muted trumpet has a specific attack character: short, punchy phrases with rests between;
  it rarely holds long notes (unlike flute which sustains naturally)
- The bass line in acid jazz is more active than in trip-hop — root + approach tones +
  occasional 5th movement at bar boundaries

---

### Miles Davis Kind of Blue (1959) — The Harmonic Template

Not chill-out per se, but the parent genre's harmonic foundation.

**So What:**
- BPM: ~136 (too fast for Chill — but the harmonic approach is the reference)
- Mode: D Dorian (bass vamp) → Eb Dorian (bridge) → back to D Dorian
- Structure: bass intro → head → solo → head; the "head" is 32 bars (AABA form)
- The bass vamp (root → 5th → octave) repeated under the entire solo = the model for
  the Chill bass generator's primary pattern
- No chord changes during soloing: the mode IS the harmony

**All Blues:**
- BPM: ~96 (closest to Chill tempo)
- 6/8 feel over a 12-bar blues in G; brushed kit
- Muted trumpet (Miles) phrases in 2-bar units with long rests between
- Demonstrates: short phrases + long silence = sophisticated; density is not musicality

**Generative lessons from Kind of Blue:**
- Dorian is the natural home key for sophisticated-minor chill; it has the raised 6th
  that prevents it from sounding gloomy or Gothic
- Solo phrases should be short (2–4 bars) with deliberate rests between them
- The bass can sustain a root for many bars — the soloist provides all the movement
- Brushed kit playing quarter notes on the ride with occasional snare accents =
  the minimal jazz kit texture

---

### Moby — Play (1999) — The Minimal End of the Spectrum

Albums studied: Play (1999) — specifically Porcelain, Why Does My Heart Feel So Bad,
Natural Blues, Down Slow, Inside

**Key tracks and data:**

Porcelain (~98 BPM, E minor / E Aeolian):
- Piano-led (acoustic or electric, not clearly Rhodes — very clean tone)
- Extremely sparse: intro has piano only for 16+ bars; beat enters very gradually
- Chord movement: slow; i → bVII oscillation throughout
- Beat: minimal 4/4 drum machine; kick on 1 and 3 only; very restrained
- Duration: 4:00 (shorter than St Germain; leaner structure)

Why Does My Heart Feel So Bad (~97 BPM, A minor / A Dorian):
- 2-chord progression only: Am7 → C (or Em7 → G in the second section)
- Piano stabs on beats 2 and 4 only (backbeat comping — exactly the Chill-rule approach)
- Drum machine: programmed but with a slightly analog/lo-fi quality; snare has a
  distinct crack; kick syncopated (not on all 4 beats)
- Gospel vocal samples are the melodic hook — not reproducible in MIDI. In the
  instrumental version, the piano and chord stabs ARE the melody
- This track validates static_groove progression family completely: 2 chords × 100 bars
  is musically sufficient when the surface and timbre are right

Natural Blues (~90 BPM, G minor / G Dorian):
- Uses "Oh Lordy" Vera Hall vocal sample. Instrumentally: drum machine, piano chords,
  deep bass synth on root
- Slower feel despite similar BPM to Porcelain — shorter note values, more space

Down Slow (~60 BPM, D minor):
- Much slower than the other tracks — closest to Ambient territory
- Minimal: sustained piano chords, almost no percussion, bass pedal point
- This represents the absolute slow end of the Chill range

Inside (~80 BPM, F minor / F Aeolian):
- More trip-hop adjacent; heavier beat; bass more prominent
- Synth pad under the piano; slightly darker texture

**What Moby adds to the genre picture:**

1. BPM range extension downward: Down Slow at ~60 BPM and Inside at ~80 BPM suggest
   the Deep/Dream slow end should reach 72–78 BPM, not just 78 as initially planned.
   Revise Deep/Dream lower bound to 72 BPM.

2. Simpler chord vocabulary is valid: Why Does My Heart Feel So Bad is Am7 → C for the
   entire track. Not every Chill song needs 9th extensions. The 7ths-only option is
   musically legitimate, especially for the deepest/slowest moods.

3. Backbeat piano comping validated: Piano/Rhodes on beats 2 and 4 only (not syncopated
   off-beats) is an equally valid comping pattern. The ChillPadsGenerator should have
   two comping patterns: syncopated (St Germain style) and backbeat (Moby style).
   Deep/Dream moods use backbeat comping; Bright/Free use syncopated comping.

4. Grand Piano as instrument option: Moby uses a very clean piano tone (possibly
   acoustic Grand Piano, program 0). This is already in Zudio's instrument palette
   and should be added as a Chill Pads alternate — most appropriate for deepest moods.

5. Structure can be even simpler: No breakdown required for the most minimal sub-style.
   Down Slow and Inside barely have sections. The full INTRO/GROOVE-A/BREAKDOWN/GROOVE-B
   structure should be the default, but a simpler INTRO/BODY/OUTRO option should exist
   for Deep/Dream moods (30% of the time), paralleling how Ambient sometimes skips
   bridge sections.

6. Beats are quiet: Moby's drum machine events have low velocity (55–70). The
   ChillDrumGenerator should use a lower velocity ceiling (max 80) than Motorik (max 110)
   to maintain the subdued character.

**Generative lessons from Moby:**
- The instrumental equivalent of a gospel vocal sample is a simple pentatonic phrase
  repeating with variation — the Lead generator's 2–4 bar phrase that recurs is the
  analogue. Keep it simple and let repetition do the work.
- Extreme simplicity in chord vocabulary is a feature when the timbre and space are
  right. Static_groove with a single chord for the entire song is a valid option.
- Grand Piano or clean Electric Piano is equally valid as the primary harmonic voice
  alongside Rhodes.
- The deepest moods can be very close to Ambient — the distinction is the presence of
  a felt beat (even a very quiet one) and a recognizable comping pattern.

**Parameter updates from Moby analysis:**
- Deep/Dream BPM range revised: 72–92 BPM (lower bound 72 not 78; Down Slow influence)
- Pads comping patterns: add backbeat mode (beats 2+4 only) for Deep/Dream moods
- Add Grand Piano (program 0) to Pads instrument options for Deep/Dream moods
- Add simple INTRO/BODY/OUTRO structure option (30% for Deep/Dream) alongside full form
- Drum velocity ceiling: 80 (not 100) for Deep/Dream electronic beats

---

### Air — Moon Safari (1998) — The French Touch

Albums studied: Moon Safari (1998) — La Femme D'Argent, Ce Matin La

Air's sound is sometimes called "space age bachelor pad music" — a blend of 1960s French
easy-listening and lounge, Moog synthesis, and understated electronic production. The French
Touch adds a warmth and analog haze that distinguishes it from St Germain's more percussive
nu-jazz and Moby's gospel minimalism.

**La Femme D'Argent (~100 BPM, D minor / D Dorian, 7:11):**
- Opens with a Moog bass riff — a stepwise descending diatonic line in D minor repeated
  as an ostinato for the entire track. The bass is not static root notes; it is an
  active melodic figure 4 bars long that cycles continuously.
- Fender Rhodes enters after 8 bars: sparse chord stabs, mostly on beat 2 and
  occasionally beat 4. Shell voicings [root, 5th, 7th].
- Drum machine: very back in the mix; kick on 1 and 3 (not all 4 beats); hi-hat 8th notes
  at low velocity (~55); snare on 2 and 4. Almost inaudible in the mix.
- Moog synth pads: slow filter-sweep pads that gradually emerge over the first 2 minutes
- No chord changes throughout — D Dorian static harmonic field for 7 minutes
- Melody only enters around bar 48: a Moog lead line, very slow, 2-bar phrases with
  4-bar rests between. Each phrase is 3–5 notes, all within the Dorian scale.
- Structure: gradual layering — bass alone → bass + Rhodes → bass + Rhodes + drums →
  bass + Rhodes + drums + pads → full texture with Moog melody → gradual unwind

**Ce Matin La (~96 BPM, C major / C Ionian or G Mixolydian):**
- The contrast track to La Femme D'Argent: brighter, more melodic, morning feeling
- Vibraphone or marimba-style melodic line is the primary voice (plucked/percussive sustain)
- String arrangement (or lush synth strings) provides warmth and swell
- Chord changes occur every 4 bars (more movement than La Femme D'Argent)
- Drum machine: slightly more active; adds a shuffle feel without being a full swing

**What Air adds to the Chill picture:**

1. Moog ostinato bass riff as structural element: rather than root pedal point or walking
   lines, a repeating 4-bar melodic bass figure IS the groove. The bass has melodic
   identity. This is a new bass archetype for the ChillBassGenerator:
   "ostinato" mode — a fixed 4-bar diatonic riff that repeats throughout the song.

2. Gradual layering as a structural approach: the song builds by adding one instrument
   at a time rather than having distinct sections (intro/groove/breakdown). This is an
   alternative to the INTRO/GROOVE/BREAKDOWN/GROOVE-B form — a "dawn" form where
   each instrument enters once and sustains through to the end, creating a long arc.
   This should be an optional structure for Deep/Dream moods.

3. Strings as primary texture (not just background): in Ce Matin La, strings are as
   prominent as the Rhodes. They should be a first-class texture voice in Chill,
   not just a quiet warmth layer. Synth Strings (program 50) or String Ensemble (program 48)
   at velocity 55–75 in the middle ground of the mix.

4. Vibraphone as melody in major-mode songs: Ce Matin La uses the vibraphone for the
   primary melodic line in a major (or Mixolydian) context, not just for jazzy fills.
   This reinforces the Lead assignment: vibraphone for Bright/Free moods is valid.

5. The "lounge sub-style": Air points to a brighter, more major-key version of Chill —
   closer to 1960s French pop and easy listening than to jazz or trip-hop. This suggests
   Ionian (major) songs should have a distinct character: vibraphone lead, string pads,
   lighter drum pattern, the most buoyant of the four moods (Bright/Free + Ionian).

6. BPM confirmation: both tracks sit in the 96–100 BPM range, consistent with the
   Bright/Free BPM target. The ostinato bass feel makes 100 BPM feel slower than it is.

**Parameter updates from Air analysis:**
- Add "ostinato" bass mode: a 4-bar melodic figure (diatonic, 4–6 notes) repeating
  throughout; most appropriate for static_groove progression family
- Add "layered dawn" structure option (alternative to breakdown form): gradual entry
  of instruments across the first 32 bars, no breakdown, no rebuild; 20% of Deep songs
- Strings (synth strings or string ensemble) elevated from pure background to
  prominent texture role — velocity 55–75, active throughout groove sections
- Vibraphone confirmed as primary melodic instrument for major-mode Bright/Free songs

---

## Part 2b: Electric Buddha Band — MIDI Analysis

Note: the EBB songs appear to be produced in Logic Pro using AI Session Players (Logic's
built-in "Keyboard Player", "Bass Player", "Drummer" plugins) plus manually recorded piano.
This explains the many duplicate tracks (volume/panning automation = separate MIDI regions),
the track naming conventions ("Broken Chords", "Retro Rock", "Neo Soul"), and the large
track counts. All findings below are from the musical content regardless of production method.

---

### Bosa Moon (110 BPM, D major, 128 bars = 4.65 min)

Key: D major / D Ionian (pitch classes D, A, E, G, B, F# — major pentatonic feel)
Drum style: "Drummer - Neo Soul" — NOT a bossa nova clave. The title is misleading;
the actual groove is neo soul: syncopated kick, ghost-note snare, variable hi-hat.

Track breakdown:
- "Keyboard Player - Broken Chords": arpeggiated chord voicings, velocity 53–81;
  D/A/E/B/G pitch classes = D major or G major area; the "broken chord" pattern means
  notes of the chord played in sequence (not simultaneously), creating a flowing texture
- "Keyboard Player - Freely": improvised melodic sections, velocity 53–67; B/G/D/E/A/F#
  pitch classes; register 35–74 MIDI; this is the "solo" section equivalent
- "Organ Solo from Piano" / "Organ Soli from bass": organ-register keyboard solo, velocity
  36–80; G/B/A/E/C pitch classes — pentatonic; the "bass" version of the organ solo suggests
  call-and-response between high and low register phrases
- "Bass Player - Retro Rock": multiple tracks; D/G/A/E/B pitch classes; velocity 82–106
  for more active sections; range 40–65 MIDI; this is an active melodic bass, not root-only
- "Chorus": very sparse, n=10/9 notes total; B/E/G pitch classes; likely a brief melodic
  accent (a few notes, not a full section)

What Bosa Moon contributes to Chill rules:

1. Neo soul drumming is a better Chill drum model than strict bossa nova or straight hip-hop:
   syncopated kick, ghost notes, laid-back feel. This is exactly the "electronic beat" mode
   we described for Deep/Dream moods but warmer and more organic. Consider adding "neo soul"
   as a drum sub-style distinct from "808 hip-hop" for Bright/Free moods.

2. Broken chord keyboard pattern: instead of block chord stabs or pure syncopated strikes,
   arpeggiated voicings (notes of the chord played sequentially, 8th-note grid) create
   a flowing harmonic texture. This is a new Pads comping mode: "arpeggiated broken chords."
   Most appropriate for Bright/Free moods where the energy is more buoyant.

3. Call-and-response between high and low register phrases ("Organ Solo from Piano" vs
   "Organ Soli from bass") — the lead generator's Lead 1/Lead 2 relationship should
   explicitly use register alternation: Lead 1 phrases in high register; Lead 2 responds
   in low-mid register.

4. 110 BPM: slightly above our current 105 ceiling for Bright/Free. Given this EBB song
   sits comfortably at this tempo, extend the Bright/Free upper bound to 110 BPM.

5. D major / Ionian is the natural home key for this sub-style. Key weight for D should
   be maintained at the top of the distribution.

Verdict: Fits Chill well. Neo soul drum style + arpeggiated chords + major key =
the clearest "nu-jazz / Bright/Free" template in the EBB catalog.

---

### Five Below Blues (80 BPM, C minor, 128 bars = 6.4 min)

Key: C minor / C Aeolian (pitch classes C, Eb, Bb, G, F — C minor pentatonic)
Named tracks: "Acoustic Piano" throughout (manually played)
Piano density: 0.12–0.94 notes/bar — extremely sparse
"Drummer" track present at velocity ~93 (standard kit)

Track breakdown:
- Multiple "Acoustic Piano" tracks play in distinct song sections (bars 4–22 only active);
  the rest of the 128-bar song is empty — this is a short composition embedded in a long file
- Pitch classes C, Eb, Bb, G, F = exactly C minor pentatonic
- Note durations: mostly 8th notes with occasional 16ths; no sustained whole notes
- The active section (approximately 20 bars) has the piano improvising freely

What Five Below Blues contributes to Chill rules:

1. Blues pentatonic [root, b3, 4, 5, b7] is a valid harmonic palette for Deep moods,
   simpler than full Dorian/Aeolian. It produces an immediately recognizable "blues" quality.
   For our ChillLeadGenerator, the blues pentatonic could be the pitch pool for the darkest
   Deep songs (Aeolian mode), replacing the full scale for that sub-style.

2. Confirms 80 BPM deep minor feel — right in our Deep/Dream range.

3. The short active section within a longer file represents a compositional approach where
   most of the "song" is silence or atmospheric content not captured in MIDI. The Chill
   generator should not try to replicate this — our songs need full MIDI density throughout.

Verdict: Confirms Deep/Dream blues-minor approach. Too sparse to generate rule parameters
directly (the active musical content is only ~20 bars). Useful as mood reference.

---

### Long Lake Winter (108 BPM, ~E minor / A minor area, 128 bars = 4.74 min)

Key estimate: Eb minor (algorithm), but actual pitch classes suggest a modulating song:
- Verse: E, C, A, G — E minor or A minor (natural minor)
- Chorus: A, G, F, C — A minor (Aeolian) or C major
- Bridge: A, F#, D, Bb — D major or D Mixolydian (the bright bridge)
- Outro: A, F#, D, C — D major area

This song modulates or has distinct harmonic areas per section — more complex than our
target static-harmony approach.

Track breakdown:
- "Verse piano (corrected)" / "Verse Piano (with flourishes)": 0.60–0.82 notes/bar, vel 62–64;
  E/C/A/G pitch classes; 8th-note duration predominant
- "Chorus Piano (slight corrections)" / "(with flourishes)": 0.30–0.39 notes/bar, vel 62;
  A/G/F/C pitch classes — different harmonic area from verse
- "Bridge Piano 1 (corrected)": 0.39–0.41 notes/bar, vel 67–68; A/F#/D/Bb — major feel
- "Outro (corrected)": 0.12–0.55 notes/bar; G/F/A/C and A/F#/D/C pitch classes
- "Strings": 0.23–0.38 notes/bar, vel 61–63 — E/C/G/A and A/F/C/G; mid-velocity strings
- "SoCal" (drums): 0.02–0.74 notes/bar, vel 75–91 — clearly a drum kit preset
- "Intro": 5 notes, velocity 83

What Long Lake Winter contributes to Chill rules:

1. Clear section structure with distinct piano voicings per section validates our structural
   thinking. The ChillStructureGenerator should give each section a distinct harmonic identity.

2. Strings at mid-velocity (61–63) are a prominent arrangement element — not background
   texture but a full second layer alongside piano. The ChillTextureGenerator should support
   strings at this prominence level (velocity 55–70, not 25–45).

3. "Flourish" versions of piano parts: the concept of having a basic rhythmic version
   of a phrase AND an ornamented version maps to: Groove B having a denser lead than Groove A
   (more ornaments/fills).

4. Strings prominence and section distinction are immediately actionable.
   Modulating harmony (section-by-section key change) is a future enhancement target.

Verdict: Fits Chill well. Strings are prominent, structure is section-based, key modulation
is more complex than version 1 needs.

---

### Mobyesque (100 BPM average, F minor / G Dorian area, ~15 min)

Type 1 MIDI, 57 tracks, 399 tempo changes (BPM range 83–127, avg ~100, starts/ends 102).
The extreme length reflects tempo rubato following the analog piano — the actual felt
duration at consistent tempo would be substantially shorter.

Critical note: there is no piano MIDI track. The analog piano was recorded as audio only.
The MIDI contains only the accompaniment instruments: pads, bass, drums. The piano melody
is the "soul" of the song — present on audio, not analyzable from MIDI.

Key estimate: G Dorian (dominant pitch classes: G, D, C, F, A, Bb — bass root appears to be G).

Track breakdown:

Synth pads (tracks 1–3):
- Extremely sparse: 0.01–0.04 notes/bar
- Duration 4–5 beats (whole note / dotted half) — very sustained
- Velocity 78–81 (moderate — these are felt, not barely audible)
- MIDI range 43–55 (G2 to G3 — low-mid register)
- Pitch classes G, D, C, F, A — act as a static harmonic anchor

Bass tracks (P-Bass light/medium, Electric, Bass Solo):
- Multiple overlapping bass tracks at different velocities (40–60) = Logic volume automation
- Main bass line (track 17, "Electric"): 401 notes, 1.05 notes/bar, vel~79, MIDI 43–50
  — primary groove bass; G/C/D/B pitch classes; deep register G2–D3
- Bass Solo (tracks 12, 21): 75 notes, 0.20 notes/bar, vel~56, MIDI 39–57 — melodic
  figure that appears occasionally; G/A/F/C/E pitch classes; wider range = melodic function
- P-Bass light (tracks 4, 10): very gentle, vel~40–41, long durations (4–5 beats) —
  a sustained "bass pad" rather than a rhythmic bass line

Drums — "Darcy" (tracks 25–56):
- Logic Pro AI drummer named "Darcy" — smooth, laid-back, brush-adjacent character
- Low-activity sections: 0.02–0.10 notes/bar (nearly absent)
- Medium sections: 0.13–0.20 notes/bar
- High-activity sections (tracks 50–55): 0.37–0.41 notes/bar
- Velocity 51–82; no hits above 82 — restrained throughout
- MIDI range 33–57 — GM drum kit notes

What Mobyesque contributes to Chill rules:

1. Synth pads as harmonic anchor at moderate velocity (78–81) are distinct from Rhodes
   comping. The pad layer sustains for 4+ beats with no rhythmic activity — it is harmonic
   glue, not a voiced comping instrument. Maps to a sub-layer of the Texture track: a slow
   "chord pad" (program 88–95 range) held for 4 bars at velocity 75–85, below the Rhodes.

2. The bass has two personalities in the same song:
   - Groove bass: 1.0 notes/bar, tight register (G2–D3), rhythmically active — the pattern
   - Solo bass: 0.20 notes/bar, wider range (B1–A3), melodic and occasional — the comment
   ChillBassGenerator should alternate between a short repeated rhythmic figure AND occasional
   single-note melodic "statements" once every 8–16 bars (mini-solos between groove sections).

3. Drum density for deep/minimal chill is 0.20–0.41 notes/bar in active sections.
   Revise Deep/Dream drum density target to 2–4 events/bar (not 4–7).

4. No melodic MIDI = the bass groove IS the melody when piano is absent. When Lead 1 is
   most minimal (0–0.3 notes/bar in Deep songs), the bass must be interesting enough to
   carry the listener on its own.

User description of the piano part (recorded as audio, not MIDI):
- Played on a slightly out-of-tune piano; style: mostly broken chords with some block chords
- Progression: DM → C → G, then F → Am → G (repeating 6-chord loop)
- Very much inspired by Moby's chill songs (Play album aesthetic)

Harmonic analysis of the progression:
- In G major: DM (V) → C (IV) → G (I) → F (bVII, borrowed) → Am (ii) → G (I)
- The F major chord is the Mixolydian "bVII" — borrowed; gives the "open" folk/Moby quality
- The progression is in triads only — challenges our "7ths minimum" rule but is musically
  correct for this sub-style

Broken chord piano measured from MIDI conversion (4 bars, 98 BPM):
- ~10 notes/bar — 8th-note arpeggiation rate
- 36% chord-cluster rate — 1 in 3 notes struck simultaneously (block chord moments)
- MIDI range 48–69 (C3–A4): mid register, 21-semitone span across 2 octaves

Parameter updates from Mobyesque:
- Deep/Dream drum density revised: target 2–4 events/bar (not 4–7)
- Add "bass statement" mode: once every 8–16 bars, ChillBassGenerator emits a 2–4 note
  melodic figure (wider register, softer velocity 50–65) as a momentary solo voice
- Synth pad layer under Rhodes: whole-note duration, velocity 75–85, MIDI 43–60
- "7ths minimum" rule relaxed: Deep/Dream songs may use triads; 7ths remain the default
- bVII chord added to Ionian/Mixolydian progression options (the "Moby open" sound)
- Arpeggiated comping confirmed: ~10 notes/bar, 30–40% block chord accent rate
- Two-bar chord windows valid in Chill (feels spacious at slow BPM with sparse accompaniment)

---

### Winter Flight (120 BPM, E minor, 133 bars = 4.43 min)

Key: E minor (pitch classes E, G, C, A, B, F — E natural minor)
Tracks: Multiple "Chorected Strings" layers only
Note velocity: 20–37 — extremely soft; barely above silence

Track structure: Four string parts, each entering 8 bars later than the previous
(T1 starts bar 2, T2 starts bar 10, T3 starts bar 18, T4 starts bar 26) — confirming
the "gradual layering" / "dawn form" identified from Air's La Femme D'Argent.

What Winter Flight contributes:
- Confirms the gradual string layering technique: 4 voices entering 8 bars apart in
  different registers, creates a natural swell without automation

Verdict: BORDERLINE for Chill. At 120 BPM with no rhythm, no melody, no bass, and
only ambient-velocity strings, this sits in Ambient territory. The string layering
technique is captured from the Air analysis. Not used as a direct rule source.

---

### Summary

- Bosa Moon: fits well — nu-jazz / bright / neo soul drums. Use as Bright/Free template.
- Five Below Blues: fits (mood/BPM) — too sparse for density rules. Deep/blues mood reference.
- Long Lake Winter: fits well — strings prominence and section structure are actionable.
- Mobyesque: analyzed — confirms minimal deep style; two-personality bass; low drum density.
- Winter Flight: borderline — outside BPM range, no groove. String layering technique noted.

---

### Parameter Updates

- Bright/Free BPM upper bound: 105 → 110 (Bosa Moon at 110 BPM fits the style)
- Drums: add "neo soul" as distinct sub-style for Bright/Free (syncopated kick,
  ghost-note snare, variable hi-hat — warmer than 808 hip-hop)
- Pads: add "arpeggiated broken chords" comping mode for Bright/Free
  (chord notes played sequentially on 8th-note grid, not struck simultaneously)
- Strings: promote from pure background (velocity 25–45) to mid-mix layer
  (velocity 55–70) in section-specific contexts
- Lead: formalize call-and-response register alternation between Lead 1 (high) and
  Lead 2 (low-mid) — confirmed from Bosa Moon's high/low organ call-and-response
- Future enhancement target: relative major bridge (bIII chord) for section contrast

---

## Part 3: Extracted Rules

**CHILL-RULE-01 — Dorian is the home mode**
Dorian minor is the characteristic mode of modal jazz and nu-jazz. It has a raised 6th
(natural 6, not flat 6) which gives it a sophisticated, not-quite-sad character.
Dorian should appear in ~40% of Chill songs.

**CHILL-RULE-02 — Harmonic stasis with melodic movement**
The chord or mode rarely changes. All melodic interest comes from the soloists improvising
over a static or slow-moving harmonic field. Maximum 4–8 bar chord changes in groove
sections; a single sustained chord in breakdown sections.

**CHILL-RULE-03 — Jazz voicings minimum (7ths throughout)**
Every chord is at least a 7th chord. Triads do not appear in Chill except in Deep/Dream
songs at the Moby-influenced extreme. The minimum voicing is [root, 3rd, 5th, 7th].
Extended to [root, 3rd, 7th, 9th] for the signature min9 and maj9 sounds. Voicings are
typically open (spread across multiple octaves).

**CHILL-RULE-04 — Rhodes is the harmonic anchor**
The electric piano (Rhodes, program 4) is the primary harmonic voice — not a pad in the
Kosmic synth sense, but an active comping instrument with rhythmic character. Rhodes comps
syncopatedly: strikes land on the AND of beats, not on the downbeats themselves.

**CHILL-RULE-05 — The beat has space**
Chill drums are much sparser than Motorik. In Deep/Dream moods (electronic beats), the kick
is syncopated (not on all four beats). In Bright/Free moods (brush kit), the snare brushes
the quarter note on the ride cymbal. Neither pattern should have more than 4–6 events per bar.
Silence is a feature, not a deficiency.

**CHILL-RULE-06 — Short phrases with deliberate rests**
Lead phrases (flute, trumpet, vibraphone, saxophone) are 2–4 bars long, followed by a rest
of at least 1–2 bars. The rest is not dead space — it is part of the phrase, allowing the
sound to ring and the listener to absorb what was played. Dense lead writing is a mistake.

**CHILL-RULE-07 — Pentatonic + blue note for solos**
Lead lines draw primarily from the mode's pentatonic subset, with occasional blue note (b5)
inflections. The blue note should appear at most once every 4–8 bars — it is a spice,
not a scale degree. In Dorian, the pentatonic is [root, 2, b3, 5, 6] (or [0,2,3,7,9]).

**CHILL-RULE-08 — Bass is round and supportive**
The bass voice (fretless bass for upright feel, or electric bass finger for a rounder tone)
plays root notes on beat 1, with occasional approach tones a semitone below the root before
chord changes. Active walking bass lines appear only in the groove body sections of Bright/Free
songs. The bass is never flashy or melodically dominant.

**CHILL-RULE-09 — Wind instrument character by mood**
Deep/Dream moods: muted trumpet and saxophone lead (darker, more introspective phrasing).
Bright/Free moods: flute and vibraphone lead (lighter, more buoyant phrasing). The
instrument selection is fixed for the song at generation time and logged as a forced rule.

**CHILL-RULE-10 — Swing by mood**
Deep/Dream moods play straight 4/4 (electronic beats quantized to the grid). Bright/Free
moods use a light swing feel — 8th notes at approximately 55/45 ratio (not heavy bebop
swing). Straight feel is produced by normal step quantization; swing is simulated by
advancing odd 8th-note steps by 1 tick (2 ticks = 1 step).

**CHILL-RULE-11 — Breakdown section is essential**
Every Chill song has a breakdown section (bass + sparse Rhodes or bass + drums only) that
strips the texture down before rebuilding. The breakdown is 8–12 bars. It is harmonically
static (single chord or bass pedal point). It creates the tension that makes the groove
return feel satisfying.

**CHILL-RULE-12 — Instrument register separation**
Lead 1 (primary solo voice) instrument registers: flute 65–85, muted trumpet 53–80,
trumpet 55–79, vibraphone 60–80, saxophone 50–70, soprano sax 58–80, trombone 45–65.
Lead 2 (counter-melody or comping) sits at least 5 semitones below Lead 1 minimum.
The Rhodes comps in mid register (48–72). Bass stays in kTrackBass bounds (MIDI 40–64).

---

## Part 4: Proposed Generator Architecture

### ChillMusicalFrameGenerator

Produces the GlobalMusicalFrame and Chill-specific metadata:

Tempo distribution:
- Deep/Dream moods: 72–92 BPM, triangular distribution (min 72, peak 83, max 92)
- Bright/Free moods: 88–110 BPM, triangular distribution (min 88, peak 96, max 110)
- Overall range: 72–110 BPM

Mode weights:
- Dorian: 40% (modal jazz home; raised 6th = sophistication)
- Aeolian: 25% (minor sadness; trip-hop weight)
- Mixolydian: 20% (bluesy major feel; Bright/Free songs)
- Ionian: 15% (clean major; used in brightest songs)

Mood weights:
- Deep: 35%
- Dream: 30%
- Free: 20%
- Bright: 15%

Key weights: jazz-friendly keys slightly boosted
- D 15%, G 12%, C 12%, F 10%, A 10%, Bb 8%, Eb 7%, Ab 6%, others 20%

Progression families (new ChillProgressionFamily enum):
- static_groove: one chord for entire song; all interest from soloists (35%)
- two_chord_pendulum: i ↔ bVII or I ↔ IV; alternates every 4–8 bars (30%)
- minor_blues: i → iv → v with jazz voicings; 12-bar structure repeating (20%)
- modal_drift: two or three chord changes across the full song; very slow (15%)

Chill-specific metadata output:
- chillProgFamily: ChillProgressionFamily
- leadInstrument: ChillLeadInstrument (Flute, MutedTrumpet, Vibraphone, Saxophone)
  assigned here based on mood; logged as a forced rule
- swingFeel: Bool (true for Bright/Free moods)
- beatStyle: ChillBeatStyle (electronic / neoSoul / brushKit) based on mood

---

### ChillStructureGenerator

Song form: always INTRO → GROOVE-A → BREAKDOWN → GROOVE-B → OUTRO

Section lengths:
- Intro: 4–8 bars (triangular, peak 6; sparse — Rhodes + bass only, lead silent)
- Groove A: 24–40 bars (full texture; lead phrases begin ~4 bars in)
- Breakdown: 8–12 bars (style-specific texture — see below)
- Groove B: 20–32 bars (full texture returns; lead is most active here)
- Outro: 4–8 bars (triangular, peak 6; lead sparse and fading, 2-bar phrases max)

Total: ~60–108 bars at ~92 BPM = ~3:00–5:00 minutes

**Intro and outro** are intentionally short (4–8 bars). The intro is Rhodes + bass only —
no lead — establishing mood before the groove arrives. The outro uses the same sparse
texture with the lead reduced to occasional 2-bar phrases at low velocity, trailing off
rather than sustaining full activity.

**Breakdown types** (picked by flat random roll, independent of drum instrument):

- **Stop-time** (35%): Unison hit on beat 1 of every other bar — kick + snare + staccato
  bass root + pad chord stab (~4 steps each). Lead plays freely in the silent bars between
  stabs (2–4 note phrases). Classic acid jazz and nu-jazz technique (Incognito, Greyboy
  Allstars).

- **Bass ostinato** (35%): All instruments drop out except bass. Bass plays a syncopated
  riff: root (step 0, 3 steps) → 5th (step 6) → root (step 9) → approach tone (step 13).
  Drums, pads, and lead completely silent. Genre reference: Billy Cobham "Stratus", Galactic,
  DJ Cam.

- **Harmonic drone** (30%): Beat continues at reduced velocity (no fills or texture mode
  switches). Bass simplifies to quarter-note root pulse. Pads at whisper volume (vel 18–40).
  Lead plays freely — the most melodically active lead writing in the song. Genre reference:
  St Germain "Rose Rouge", Jazzanova, Kyoto Jazz Massive.

The breakdown style is logged in the Form line: e.g. `Groove · breakdown (bass ostinato)`.
The style is always independent of the drum instrument choice.

Chord plan: uses ChillProgressionFamily

No chord window may cross a section boundary. Breakdown chord is always tonic-root sus4
(no 3rd, modal identity erased per CHL-SYNC-009) regardless of progression family.

**static_groove** — tonic chord for the entire song.
- Chord root: degree "1" (tonic), always
- Chord type by mode: Dorian → min7; Aeolian → min7; Mixolydian → maj7; Ionian → maj7
- One ChordWindow spanning the full song (excluding Breakdown which gets sus4)

**two_chord_pendulum** — alternates between two chord roots on a fixed window length.

Window length selected once at frame time: 4 bars (25%), 6 bars (45%), 8 bars (30%).

Chord pair weights by mode (select one pair at frame time, use both chords throughout):
- Dorian: im7|bVIImaj7 (40%), im7|IVmaj7 (35%), im7|vm7 (25%)
- Aeolian: im7|bVIImaj7 (35%), im7|ivm7 (35%), im7|bVImaj7 (30%)
- Mixolydian: I|bVII (45%), I|IV (35%), I|vm7 (20%)
- Ionian: Imaj7|IVmaj7 (35%), Imaj7|vim7 (35%), Imaj7|bVIImaj7 (30% — Moby borrow)

Chord type assignment: tonic-root chord uses min7 (minor modes) or maj7 (major modes).
Non-tonic chord: bVII always maj7; IV in Dorian = maj7 (raised 6th); iv in Aeolian = min7;
bVI in Aeolian = maj7; vm7 = min7; vim7 = min7.

Pendulum starts on the tonic chord. Grooves alternate at each window boundary. Breakdown
uses tonic-root sus4 (breaks the pendulum for the structural clear-out; re-enters tonic on
Groove B bar 1).

**minor_blues** — 12-bar tile repeating through Groove sections (see Part 11 per-mode pattern).
No chord selection needed; the tile is fixed by mode. Breakdown = tonic-root sus4.

**modal_drift** — 2 or 3 chords total, placed at section boundaries.

Number of chords: 2 (60%) or 3 (40%).

Two-chord drift: tonic chord for Intro + first half of Groove A → second chord for second
half of Groove A → tonic returns for Groove B. Second chord selected by mode:
- Dorian: IVmaj7 (50%), bVIImaj7 (50%)
- Aeolian: bVImaj7 (50%), bVIImaj7 (50%)
- Mixolydian: bVII (50%), IV (50%)
- Ionian: IVmaj7 (50%), vim7 (50%)

Three-chord drift: tonic (Intro + early Groove A) → chord 2 (late Groove A, selected as above)
→ chord 3 (Groove B, selected from remaining diatonic options not yet used). The arc moves
away from tonic and then settles on a different chord for Groove B rather than returning —
creates a sense of having arrived somewhere new.

First change placement in Groove A: midpoint of section ± 4 bars, rounded to nearest 2-bar
boundary. For a 32-bar Groove A, change fires at bar 12, 14, 16, 18, or 20 (uniform random).

Breakdown always = tonic-root sus4 regardless of which chord was active when Breakdown starts.

Alternate structure for Deep/Dream moods (30% probability):
- INTRO/BODY/OUTRO only (no breakdown) — Moby Down Slow / Inside style
- Body: 40–60 bars continuous
- Simpler internal structure; density arc achieved through instrument entry/exit rather
  than a structural break

---

### ChillDrumGenerator

Three distinct modes selected at frame generation time based on mood:

Electronic mode (Deep/Dream moods, 808 Kit / Standard Kit):
- Kick: syncopated pattern — beat 1 always present, beat 3 sometimes
- Snare: on 2 and 4; occasional ghost notes on adjacent 16th-note positions (30% chance)
- Hi-hat: 16th-note pattern at ~50% step probability; 8th-note gaps for breathing
- Total density: 2–4 events per bar (Mobyesque Darcy model — velocity ceiling 80)
- No fills in Intro or Breakdown; occasional 2-beat fill at section transitions

Neo soul mode (Bright/Free moods, Standard Kit with softer character):
- Kick: step 1 (always, vel 88–95); step 3 (30% prob, vel 60–70)
- Electric snare: step 3 (vel 80–90); step 13 (vel 75–85)
- Crash: step 1 of section-start bar only (vel 95–100)
- Hi-hat 16ths: steps 1,3,5,7,9,11,13,15 at 65% each, vel 50–65
- Ghost snare: steps 4, 8, 12 at 30% prob, vel 30–45
- Total density: 5–9 events per bar

Brush kit mode (Bright/Free moods, Brush Kit):
- Ride cymbal: steps 1, 5, 9, 13 (all four beats, always, vel 45–60)
- Snare brush: steps 5 and 13 (beats 2 and 4, vel 40–55)
- Kick: step 1 (always, vel 60–70); step 9 (40% prob, vel 50–60)
- Hi-hat closed: steps 3 and 11 (AND of beats 1 and 3, vel 35–50)
- Total density: 3–5 events per bar

Breakdown section (all modes): all percussion silent for first 4 bars; sparse single
element returns at bar 5 (hi-hat or ride only) at very low velocity (35–50)

---

### ChillBassGenerator

**Pattern A — Root sustain** (static_groove, breakdown sections; Mobyesque P-Bass model)
- Step 1: root, duration 4 beats, velocity 75–85
- Optional step 9: 5th of chord, duration 2 beats, velocity 65–75 (40% probability)
- Character: anchoring, unhurried

**Pattern B — Syncopated root-fifth** (groove sections; Mobyesque Electric Bass model)
- Step 1: root, 2 beats, vel 80–90
- Step 7 (AND of beat 2): 5th or approach tone, 1 beat, vel 70–80
- Step 9 (beat 3): root, 1.5 beats, vel 75–85
- Step 11 (AND of beat 3): passing tone (4th or 3rd), 0.5 beats, vel 60–70
- Step 13 (beat 4): root or 5th, 1 beat, vel 75–85
- Step 15 (AND of beat 4): approach tone (semitone below next bar root), 0.5 beats, vel 65–75
- Fires at 60% probability per bar in groove sections; other bars use Pattern A

**Pattern C — Walking line** (Bright/Free moods, chord-change bars only)
- Steps 1, 5, 9, 13 (one note per beat, quarter-note durations)
- Root → 3rd → 5th → approach tone (semitone below next chord root)
- Velocity: 85–95; fires only in bars immediately before a chord change

**Pattern D — Ostinato riff** (Air / La Femme D'Argent style, static_groove Deep moods)
- A 4-bar diatonic figure repeating throughout; 5–7 notes total over 4 bars
- Bar 1: root (step 1, 2 beats) → 2nd (step 5, 1 beat) → root (step 9, 2 beats)
- Bar 2: 5th (step 1, 2 beats) → 4th (step 5, 1 beat) → 5th (step 9, 1 beat) → root (step 13, 1 beat)
- Bar 3: 3rd (step 1, 2 beats) → 2nd (step 9, 2 beats)
- Bar 4: root (step 1, 4 beats, held to next bar)
- All within one octave; stepwise motion; velocity 80–90

**Bass "statement" moments** (Mobyesque Bass Solo model):
- Once every 8–16 bars in Deep/Dream songs, emit a 2–4 note melodic figure
- Notes drawn from scale; wider register span (up to 1.5 octaves)
- Duration: 0.5–1 beat each; velocity 50–65 (softer than groove bass)
- Acts as a brief melodic comment in the absence of a sustained lead

Instrument mapping:
- Fretless Bass (program 35) as default (warm, slightly undefined pitch — closest to upright)
- Acoustic Bass (program 32) for Deep moods (warmest upright tone)
- Electric Bass finger (program 33) for Bright/Free moods (punchier, rounder)

---

### ChillPadsGenerator

Sustained harmonic cushion beneath the Rhythm comping voice — consistent with the Pads
role in all Zudio styles. Uses actual pad and string instruments with long sustain and slow
attack. Never rhythmically active. Always present in Groove sections (unless Absent rule
fires); always plays a sus4/sus2 chord in Breakdown.

**String sustain — Long Lake Winter model** (35%):
- One sustained chord per 2 bars; half-note rhythm
- Four voices in registers: MIDI 36–48 (low), 48–60 (mid-low), 60–72 (mid-high), 72–84 (high)
- Velocity 55–70; all voices on same harmonic content
- Intro: high voice only (vel 30–45); Groove A: voices enter progressively; full texture by bar 9

**Staggered string entry — Air/Winter Flight model** (20%):
- Same as above but voices enter 8 bars apart (confirmed from Winter Flight MIDI analysis)
- Voice 1 (high) at Groove A bar 1; Voice 2 bar 9; Voice 3 bar 17; Voice 4 bar 25
- Groove B restarts the stagger compressed to 4-bar offsets

**Synth pad anchor — Mobyesque model** (15%):
- One sustained chord per 4 bars; held full 4 bars (no re-attack)
- Single voice, register MIDI 43–60 (Mobyesque pads confirmed MIDI 43–55)
- Velocity 75–85; harmonic glue under the Rhythm track

**Absent** (Deep/Dream minimal, 20%):
- No Pads events in Groove sections; Rhythm carries harmonic weight alone
- Breakdown sus4 chord still fires (always)

**Breakdown sustain (always active):**
- sus4 or sus2 voicing (no 3rd) held for full Breakdown duration; velocity 45–60
- Erases modal identity; creates tension resolved by Groove B return
- Fires regardless of which primary Pads rule is selected, including Absent

Instrument: Warm Pad (program 89) as default; String Ensemble 1 (program 48); String
Ensemble 2 (program 49); Synth Strings 1 (program 50); Choir Aahs (program 52)

---

### ChillLeadGenerator

Lead 1 (primary solo voice):

Instrument selection (assigned in musical frame, same for entire song):
- Deep/Dream: Muted Trumpet (GM 59) 40%, Saxophone/Alto Sax (GM 65) 35%,
  Flute (GM 73) 15%, Vibraphone (GM 11) 10%
- Bright/Free: Flute (GM 73) 40%, Vibraphone (GM 11) 30%,
  Saxophone 20%, Muted Trumpet 10%

Phrase structure (all instruments):
- Phrase length: 2–4 bars
- Rest after phrase: 1–2 bars minimum (CHILL-RULE-06)
- Phrase starts on beat 1 or the AND of beat 4 (anticipation)
- Notes drawn from mode's pentatonic [0, 2, 3, 7, 9 for Dorian] plus occasional blue
  note (b5 = +6 semitones from root) at ≤15% of phrases

Instrument-specific behavior:
- **Flute** (Bright/Free model; 4-bar phrase): 3–4 notes on strong beats in bar 1;
  continuation/question in bar 2 ending on unresolved degree (2nd or 6th); bars 3–4 rest;
  held notes 6–12 steps (legato); range MIDI 65–85; vel 65–85 groove, 45–65 intro
- **Muted Trumpet** (Deep/Dream model; 2-bar phrase): 2–3 punchy notes in bar 1;
  bar 2 rest; notes 0.75–1 beat each, syncopated timing; range MIDI 55–75;
  vel 70–90; staccato feel (note shorter than step duration); mostly steps with one leap
- **Vibraphone** (DJ Cam model; 2-4 bars): can play 2-note dyads (3rd + 7th);
  3–5 notes per 2 bars; steps 60% / leaps 40%; range MIDI 60–80; vel 65–80 (even dynamics)
- **Saxophone** (Deep/Dream blues model; 2-3 bars): 4–6 notes per phrase;
  0.5–1 beat per note; blues scale b3/b5/b7 at ~30% of notes; descending phrases preferred;
  range MIDI 50–70; vel 65–85; phrase endings on b7 or 5th (slightly unresolved)

Section behavior:
- Intro: Lead 1 silent for first 4 bars; then 1 phrase only, very soft (velocity 45–60)
- Groove A: active; 1 phrase per 4 bars average; velocity 65–85
- Breakdown: silent (Lead 1 completely absent; creates tension)
- Groove B: most active; 1 phrase per 2–3 bars; velocity 70–90; occasional blue note
- Outro: 1 phrase every 6–8 bars; diminishing velocity; trail off

Lead 2 (counter-melody / comping; call-and-response):
- Instrument: Vibraphone (if Lead 1 is not vibraphone), or Flute (if Lead 1 is trumpet/sax)
- Groove sections only: sparse 2-bar phrases between Lead 1 phrases (call-and-response)
- Median pitch ≥ 5 semitones below Lead 1 median (CHILL-RULE-12; Bosa Moon confirmed)
- Velocity: always 10–15 points lower than Lead 1 (supporting role)

---

### ChillRhythmGenerator

Active harmonic voice in Chill — the Rhodes electric piano that defines the style. Comps
rhythmically over the Pads sustained layer. Absent in the first 8 bars of Intro and silent
throughout Breakdown. This is the primary keyboard generator; ChillPadsGenerator provides
the sustained backdrop beneath it.

**St Germain Syncopated — Bright/Free** (35%):
- Strikes at step 3 (AND of beat 1) and step 11 (AND of beat 3)
- 4-note jazz voicing [3rd, 5th, 7th, 9th], root omitted; held 1.5 beats; vel 75–85
- Fill strike at step 7 or 15 at 30% probability; register MIDI 48–72

**Moby Backbeat — Deep/Dream** (35%):
- Strikes at step 5 (beat 2) and step 13 (beat 4); shell voicing [root, 5th, 7th]
- Step 5 held 1.5 beats vel 65–75; step 13 held 1 beat vel 60–70
- 30% chance only one strike fires per bar; velocity ceiling 75

**Bosa Moon Broken Chord — Bright/Free** (20%):
- 8th-note grid: steps 1, 3, 5, 7, 9, 11, 13, 15; chord tones cycled ascending/descending
- Duration 0.75 beats each; ~10 notes/bar; register MIDI 48–69
- 30–40% block chord accent on step 1 or 9; vel 70–85 arpeggio, 80–95 block

**Deep Sustain — Deep/Dream slowest BPM** (10%):
- One chord per 2 bars on step 1; held 1.8 bars; shell voicing; vel 60–70
- Suited to songs where even backbeat comping feels too dense

Space Rule (always active): 15% silent bars in Groove A, 20% in Groove B;
maximum 1 consecutive silent bar.

Instrument: Electric Piano 1 (program 4) as default (Rhodes); Electric Piano 2 /
Wurlitzer (program 5) alternate; Grand Piano (program 0) for deepest Deep/Dream moods

---

### ChillTextureGenerator

Audio ambient loop only — no MIDI texture layer. MIDI harmonic sustain is fully covered
by ChillPadsGenerator (sustained pad/string chords) and ChillRhythmGenerator (Rhodes
comping). A third MIDI harmonic layer would be muddy and architecturally redundant.

**Audio texture (~30% of songs):**
- A looping ambient audio clip plays from song start to end at fixed low volume
- One clip selected at random:
  - Soft rain — gentle rainfall, no thunder; 30-sec loop
  - Cafe murmur — low conversations, background clatter, occasional espresso machine
  - Vinyl crackle — lo-fi surface noise with occasional pop; no music bleeding through
  - Late night city — distant traffic, occasional siren, urban air; very low energy
  - Tape hiss — analog warmth, slight flutter/warble; almost subliminal
  - Cocktail hour — ice and glass sounds, murmured conversation; brighter feel
  - Distant thunder — low rolling thunder, light rain, no lightning crack
  - Jazz club bleed — muffled trumpet and bass line from an adjacent room; very quiet
- Implementation: `AudioTexturePlayer` using `AVAudioPlayerNode` for seamless WAV looping,
  separate from the MIDI sampler pipeline
- Audio files bundled in `Resources/Textures/` as 44.1kHz mono WAV, ~30-sec loops
- Volume: fixed at -18 to -12 dB relative to master (never audible on its own; only felt)
- Clip selection logged to .zudio file as chillAudioTexture field (or "none")

**Absent (~70% of songs):** No texture track. ChillPadsGenerator provides sufficient warmth.

---

## Part 5: Musical Frame Parameter Summary

Tempo:
- Deep/Dream: 72–92 BPM, triangular (peak 83)
- Bright/Free: 88–110 BPM, triangular (peak 96)

Modes: Dorian 40%, Aeolian 25%, Mixolydian 20%, Ionian 15%

Moods: Deep 35%, Dream 30%, Free 20%, Bright 15%

Keys: D 15%, G 12%, C 12%, F 10%, A 10%, Bb 8%, Eb 7%, Ab 6%, others 20%

Chord types used: min7, maj7, dom7, min9, maj9, dom7sus4 (triads permitted for Deep/Dream only)

Chord change rate:
- Groove sections: 2–8 bars per chord (2-bar windows valid at slow BPM)
- Breakdown: single chord, static

Song length: 68–116 bars ≈ 3:00–5:00 min

---

## Part 6: Instrument Presets

Lead 1 (ChillLead1, primary solo):
- Flute (program 73) — Bright/Free primary; register 65–85
- Muted Trumpet (program 59) — Deep/Dream primary; register 53–80
- Trumpet (program 56) — Deep/Dream alternate; register 55–79
- Alto Sax (program 65) — Deep/Dream secondary; register 50–70
- Soprano Sax (program 64) — alternate; register 58–80
- Vibraphone (program 11) — all moods; register 60–80
- Trombone (program 57) — Lead 2 counter-melody register; register 45–65

Lead 2 (ChillLead2, counter-melody):
- Vibraphone (program 11) — default when Lead 1 is not vibraphone
- Flute (program 73) — when Lead 1 is trumpet or saxophone
- Trombone (program 57) — low counter-melody voice

Pads (sustained harmonic layer):
- Warm Pad (program 89) — default
- String Ensemble 1 (program 48) — alternate (acoustic feel)
- String Ensemble 2 (program 49) — alternate (lower strings; Deep moods)
- Synth Strings 1 (program 50) — Bright/Free (brighter attack)
- Choir Aahs (program 52) — optional atmospheric Deep/Dream
- Pad 3 Poly Synth (program 90) — optional electronic Deep/Dream

Rhythm (Rhodes active comping):
- Rhodes (program 4) — default (primary harmonic voice)
- Wurlitzer (program 5) — alternate
- Grand Piano (program 0) — deepest Deep/Dream moods

Bass:
- Fretless Bass (program 35) — default (upright-adjacent warmth)
- Acoustic Bass (program 32) — Deep moods (warmest upright tone)
- Electric Bass finger (program 33) — Bright/Free moods (round, punchy)

Drums:
- 808 Kit (program 25) — Deep/Dream moods (electronic)
- Standard Kit for neo soul mode — Bright/Free moods
- Brush Kit (program 40) — Bright/Free moods (acoustic feel)

Texture (audio mode only, ~30% of songs):
- Soft rain, Cafe murmur, Vinyl crackle, Late night city, Tape hiss,
  Cocktail hour, Distant thunder, Jazz club bleed
- Implemented via AudioTexturePlayer (AVAudioPlayerNode, WAV loops in Resources/Textures/)
- No MIDI instruments; MIDI harmonic sustain is handled by Pads

---

## Part 7: Coherence Targets

Harmonic consonance (fraction of notes in active scale):
- Bass: ≥ 95%
- Pads (sustained): ≥ 92%
- Rhythm (Rhodes comping): ≥ 90%
- Lead 1: ≥ 72% (pentatonic + blue note; blues scale inflections intentionally chromatic)
- Lead 2: ≥ 85%
- Texture: N/A (audio only; no MIDI pitch content)

Note density per bar by section:
- Lead 1 intro: 0–0.8 notes/bar (first 4 bars always silent; max 2-bar phrases after that)
- Lead 1 groove A: 1.0–3.0 notes/bar (45% silence probability per phrase window)
- Lead 1 groove B: 1.0–3.0 notes/bar (20% silence probability — most active section)
- Lead 1 breakdown: 0 notes/bar (completely silent, no exception)
- Lead 1 outro: 0–1.5 notes/bar (70% silence probability; declining)
- Lead 2 groove A: 0.5–2.5 notes/bar (responds in Lead 1 rests; 65% fill rate)
- Lead 2 groove B: 0.5–2.5 notes/bar
- Bass groove: 1.5–4.0 notes/bar (avg 3.0–3.2/bar observed)
- Bass breakdown: ~1.0 notes/bar (root whole-note, velocity ≤65)
- Drums electronic groove: 2–4 events/bar (Deep/Dream)
- Drums neo soul groove: 5–9 events/bar (Bright/Free)
- Drums brush groove: 3–5 events/bar (Bright/Free)
- Drums breakdown: 0–1 events/bar (sparse; first 4 bars near-silent)
- Rhythm (Rhodes) comping: 0–10 events/bar depending on rule (avg 4–5/bar observed)
- Pads (sustained): ≤1 re-attack per 2 bars; bridge: ≤1.5 notes/bar (sparse sus4 sustain)

---

---

## Part 9: Known Implementation Challenges

Jazz voicings in MIDI:
- 4-note open voicings can sound muddy in the MIDI instrument palette. The solution is
  to omit the root (bass covers it) and spread the remaining notes across 2 octaves.
  This is already the approach used by Kosmic's PadsGenerator and proven to work.

Swing simulation:
- True swing requires timing microvariations below the 16th-note step grid. Zudio's
  step system quantizes to 16th notes. Swing can be approximated by advancing every
  even-numbered 8th-note step (steps 2, 4, 6... within a bar) by 1 tick out of 16.
  This produces a light shuffle without requiring sub-step timing.

New GM programs:
- Muted Trumpet (59) and Alto Sax (65) are standard GM programs and will be available
  in the system's General MIDI soundfont. They need to be added to the instrument picker
  in TrackRowView.swift only; no other changes required. Sound quality depends on the
  system MIDI synth — these programs should be tested on macOS at first.

Breakdown transition:
- The structural transition into and out of the breakdown needs to feel musical, not
  mechanical. Use a 1-bar "fill" in the drum track (for electronic beats) or a
  cymbal crash + rest (for brush kit) at the Groove A → Breakdown boundary.
  The opposite transition (Breakdown → Groove B) should bring instruments back
  gradually: bass first (bar 1), then drums (bar 2), then Rhodes (bar 3), then lead (bar 5+).

Audio texture sourcing:
- WAV files must be royalty-free and cleared for app distribution (CC0 or equivalent).
  Freesound.org (CC0 filter) is the primary source. Each clip should be edited to loop
  seamlessly (fade out matches fade in). Do not use any clip containing recognizable music
  (even muffled) unless it is clearly royalty-free.
- AudioTexturePlayer must handle the case where no texture file is found gracefully (silent).

Lead melodic navigation — full scale, not pentatonic:
- The note-to-note navigation in ChillLeadGenerator uses the full 7-note scale as the
  ordered pool, not the pentatonic. This is counterintuitive given the jazz context but
  necessary: the pentatonic has 2–4 semitone gaps between adjacent notes, so a ±1 pool-index
  move often measures as a "leap" (>2 semitones) by the analyzer. The 7-note scale has only
  1–2 semitone gaps, so all adjacent moves are genuine steps. Pentatonic character is
  preserved through landing-note selection (phrase endings are still snapped to
  pentatonic-derived root/3rd/5th tones). Do not change the pool back to pentatonic without
  re-running the batch analyzer — the step ratio will drop below 55%.

Pads voicing: 4-note upper structure:
- `buildUpperStructure()` emits [3rd, 5th, 7th, 9th] — root omitted (bass covers it).
  The 9th is interval 14 (major 9th = octave + major 2nd). All 4 voices are spread across
  2 octaves: voices 0–1 in the lower octave, voices 2–3 one octave up. This matches the
  plan spec and produces rich jazz voicings. Do not reduce to 3 notes (removes the 9th,
  which is the defining color of the min9/maj9 sound).

Lead 2 register cap:
- Lead 2's upper register is capped at `regLow1 - 2` (2 semitones below the lowest note
  of Lead 1's register range). This is stricter than a median-based cap: it ensures Lead 2
  stays completely below Lead 1 regardless of where Lead 1 actually plays. If Lead 1
  register ranges change, verify Lead 2 still has ≥12 semitones of usable range.

Bass is not boring:
- After adding bass melodic quality metrics (same-note ratio, mean interval, pitch variety
  per 4-bar window), the bass tested well: avg 25.7% same-note ratio, 3.9 semitone mean
  interval, 4.2 distinct pitches per 4-bar window. The concern that root-only patterns
  dominate is not borne out — CHL-BASS-002 (syncopated), CHL-BASS-003 (walking), and
  CHL-BASS-006 (bass statement) together ensure most songs have melodic bass movement.

Chord root degree parsing in analyzer:
- The analyzer's `degree_to_pc()` function uses a direct semitone-offset table for chord
  root degrees, not scale interval lookup. This is necessary because degrees like `"b7"`
  and `"b6"` appear in chord plans (Dorian bVII, Aeolian bVI) but cannot be parsed as
  integers. The table maps: '1'→0, '2'→2, 'b3'→3, '3'→4, '4'→5, '5'→7, 'b6'→8,
  '6'→9, 'b7'→10, '7'→11. Extend this table if new chord root labels are added.

---

---

## Part 10: Generator-Ready Note Patterns

Derived from MIDI analysis of EBB songs. Step positions use 1-based 16-step bar (step 1 = beat 1,
step 5 = beat 2, step 9 = beat 3, step 13 = beat 4). Duration in beats (quarter notes).

### Bass Patterns

**Pattern A — Root sustain** (static_groove, all deep/minimal sections; Mobyesque P-Bass light)
- Step 1: root, duration 4 beats, velocity 75–85
- Optional: step 9 (beat 3): 5th of chord, duration 2 beats, velocity 65–75 (40% probability)
- Character: anchoring, unhurried; the groove is in the pad and drums, not the bass

**Pattern B — Syncopated root-fifth** (groove sections; Mobyesque Electric Bass)
- Step 1: root, duration 2 beats, velocity 80–90
- Step 7 (AND of beat 2): 5th or approach tone, duration 1 beat, velocity 70–80
- Step 9 (beat 3): root, duration 1.5 beats, velocity 75–85
- Step 11 (AND of beat 3): passing tone (4th or 3rd), duration 0.5 beats, velocity 60–70
- Step 13 (beat 4): root or 5th, duration 1 beat, velocity 75–85
- Step 15 (AND of beat 4): approach tone (semitone below next bar root), 0.5 beats, vel 65–75
- This pattern fires at 60% probability per bar in groove sections; other bars use Pattern A

**Pattern C — Walking line** (Bright/Free moods, chord-change bars only; Five Below Blues walkdown)
- Steps 1, 5, 9, 13 (one note per beat, quarter-note durations)
- Root → 3rd → 5th → approach tone (semitone below next chord root)
- Velocity: 85–95, slightly accent on step 1
- Fires only in bars immediately before a chord change (approach function)

**Pattern D — Ostinato riff** (Air / La Femme D'Argent style, static_groove Deep moods)
- A 4-bar diatonic figure repeating throughout; 5–7 notes total over 4 bars
- Bar 1: root (step 1, 2 beats) → 2nd (step 5, 1 beat) → root (step 9, 2 beats)
- Bar 2: 5th (step 1, 2 beats) → 4th (step 5, 1 beat) → 5th (step 9, 1 beat) → root (step 13, 1 beat)
- Bar 3: 3rd (step 1, 2 beats) → 2nd (step 9, 2 beats)
- Bar 4: root (step 1, 4 beats, held to next bar)
- All within one octave; stepwise motion; velocity 80–90 consistent

**Bass "statement" moments** (Mobyesque Bass Solo model):
- Once every 8–16 bars in Deep/Dream songs, emit a 2–4 note melodic figure
- Notes: drawn from scale (any degree); wider register span (up to 1.5 octaves)
- Duration: 0.5–1 beat each; velocity 50–65 (softer than groove bass)
- Acts as a brief melodic comment in the absence of a lead instrument

---

### Drum Patterns

**Electronic mode — Deep/Dream** (derived from Mobyesque "Darcy" drummer analysis)
- Total events per bar: 2–4 target
- Kick (note 36): step 1 (always, vel 65–80); step 9 (40% prob, vel 55–70)
- Snare (note 38): step 5 (60% prob, vel 55–70); step 13 (85% prob, vel 60–75)
- Closed hi-hat (note 42): steps 3, 7, 11, 15 (8th-note off-beats, 50% each, vel 40–55)
- All velocity ceilings: 80 max (Mobyesque Darcy never exceeded 82)
- Breakdown: kick step 1 only (vel 55); snare and hi-hat silent for first 4 bars

**Neo soul mode — Bright/Free** (derived from Bosa Moon "Drummer - Neo Soul")
- Kick (note 36): step 1 (always, vel 88–95); step 3 (30% prob, vel 60–70)
- Electric snare (note 40): step 3 (primary snare position, vel 80–90); step 13 (vel 75–85)
- Crash (note 49): step 1 of section-start bar only (vel 95–100)
- Hi-hat 16ths (note 42): steps 1,3,5,7,9,11,13,15 at 65% each, vel 50–65
- Ghost snare (note 38): steps 4, 8, 12 at 30% prob, vel 30–45 (ghost notes)
- Total events: 5–9 per bar

**Brush kit mode — Bright/Free** (derived from genre knowledge; no direct EBB example)
- Ride cymbal (note 51): steps 1, 5, 9, 13 (all four beats, always, vel 45–60)
- Snare brush (note 38): steps 5 and 13 (beats 2 and 4, vel 40–55)
- Kick (note 36): step 1 (always, vel 60–70); step 9 (40% prob, vel 50–60)
- Closed hi-hat (note 42): steps 3 and 11 (AND of beats 1 and 3, vel 35–50)
- Total events: 3–5 per bar

---

### Pads / Rhodes Patterns

Chord voicing structure confirmed from Long Lake Winter analysis:
interval stack [12, 4, 3] = octave + major 3rd + minor 3rd = spread maj7 voicing.
For bass-omitted jazz voicing: [3rd, 5th, 7th, 9th] of chord voiced across 2 octaves.

**Syncopated comping — Bright/Free** (St Germain Rose Rouge model)
- Step 3 (AND of beat 1): chord strike, 4-note voicing [3rd, 5th, 7th, 9th], vel 75–85, held 1.5 beats
- Step 11 (AND of beat 3): chord strike, same voicing, vel 70–80, held 1.5 beats
- Step 7 or step 15: occasional fill strike at vel 55–65 (30% probability per bar)
- Register: MIDI 48–72 (C3–C5)

**Backbeat comping — Deep/Dream** (Moby Why Does My Heart Feel So Bad model)
- Step 5 (beat 2): chord strike, 3-note shell voicing [root, 5th, 7th], vel 65–75, held 1.5 beats
- Step 13 (beat 4): chord strike, same shell, vel 60–70, held 1 beat
- 30% chance: only one of the two strikes fires per bar (more space)
- Velocity ceiling: 75

**Arpeggiated broken chord — Bosa Moon model** (confirmed from MIDI: ~10 notes/bar)
- 8th-note grid: notes at steps 1, 3, 5, 7, 9, 11, 13, 15
- Chord tones [root, 3rd, 5th, 7th, 9th] cycled ascending then descending
- Duration: 0.75 beats each (slightly overlapping)
- 30–40% chance of two simultaneous notes on step 1 or step 9 (block chord accent)
- Register: MIDI 48–69 (C3–A4), max 2-octave span per voicing
- Velocity: 70–85 arpeggiated notes; 80–95 block chord accents

**Sustained chord layer** (under all comping patterns):
- One chord every 4 bars, held 3 bars, then released
- Voicing: same jazz voicing transposed up one octave from comping register
- Velocity: 40–55 (cushion, not dominant)

---

### Lead Patterns

**Flute — Bright/Free** (St Germain Rose Rouge model; 4-bar phrase structure)
- Bar 1: 3–4 notes on strong beats, pentatonic degrees, duration 1.5–2 beats each
- Bar 2: continuation; question phrase; ends on 2nd or 6th scale degree (unresolved)
- Bars 3–4: rest
- Note range: MIDI 65–85 (F4–C6)
- Blue note (b5): once per phrase at bar 1–2 beat 3 position, max (≤15% of phrases)
- Velocity: 65–85 in groove; 45–65 in intro; 50–70 in outro

**Muted Trumpet — Deep/Dream** (Miles Davis All Blues phrasing model; 2-bar phrase)
- Bar 1: 2–3 punchy notes, duration 0.75–1 beat each, syncopated timing (off beats)
- Bar 2: rest
- Interval character: mostly steps (1–2 semitones) with one leap (3–5 semitones) at peak
- Phrase endings: root or 5th (strong landing, ≥ 60% of phrases)
- Note range: MIDI 55–75 (G3–Eb5)
- Velocity: 70–90; staccato feel (note duration shorter than step duration)

**Vibraphone** (DJ Cam Quartet model; 2-4 bars; can be primary or counter-melody)
- 2-note dyads are valid: 3rd + 7th struck together (vibraphone sustains naturally)
- Density slightly higher than flute/trumpet: 3–5 notes per 2 bars
- Interval character: steps 60% / leaps 40% (vibraphone has a more angular quality)
- Note range: MIDI 60–80 (C4–Ab5)
- Velocity: 65–80 (even across phrase; vibraphone sustain handles dynamics)

**Saxophone — Deep/Dream** (blues-adjacent; Bosa Moon "Organ Solo" register model)
- Notes per phrase: 4–6 over 2–3 bars (denser than trumpet, less sustained than flute)
- Duration per note: 0.5–1 beat (medium articulation)
- Blues scale emphasis: b3, b5, b7 appear in ~30% of notes (beyond standard pentatonic)
- Phrase direction: descending preferred (falling phrases = melancholic character)
- Phrase ending: b7 or 5th (can leave slightly unresolved — saxophone blues idiom)
- Note range: MIDI 50–70 (D3–Bb4)
- Velocity: 65–85

**Lead 2 call-and-response register rule** (Bosa Moon high/low organ alternation confirmed):
- Lead 2 phrases occur in the rests between Lead 1 phrases (call-and-response)
- Lead 2 median pitch must be ≥ 5 semitones below Lead 1 median pitch
- Velocity: 10–15 points lower than Lead 1 (supporting, not competing)

---

### Rhythm / Secondary Keyboard Patterns

From Five Below Blues Acoustic Piano analysis (steps 1, 5, 11, 15; vel 76):
- Step 1 (beat 1): chord, held 1 beat
- Step 5 (beat 2): chord, held 0.5 beats
- Step 11 (AND of beat 3): chord, held 0.25 beats (short accent)
- Step 15 (AND of beat 4): chord, held 0.25 beats (anticipation of next bar)

Rhythm track applies this pattern to the secondary keyboard (Wurlitzer or Vibraphone):
- Velocity: 55–70 (background; never dominates)
- Groove sections only; silent in Breakdown and Intro

---

### String Texture Patterns

From Long Lake Winter strings analysis (vel 61–63, duration ~2 beats, mid-register):
- One sustained chord per 2 bars (half-note rhythm)
- Pitch class content matching active chord (same harmony as Pads)
- Velocity: 55–70 (prominent — Long Lake Winter strings are full mid-mix presence)
- Four voices in different registers: MIDI 36–48 (low), 48–60 (mid-low), 60–72 (mid-high), 72–84 (high)
- Staggered-entry variant: each voice enters 8 bars after the previous (Air / Winter Flight style)
- Active in all sections except Breakdown; velocity reduced to 30–45 in Intro

---

## Part 11: Chord Progressions by Mode

All progressions expressed as scale-degree sequences. Roman numerals use jazz convention:
uppercase = major chord, lowercase = minor chord, 7th extensions implicit (see voicing table below).
Chord durations given in bars; harmonic rhythm is slow by design (this is chill, not bebop).

---

### Chord Voicing Formulas (MIDI semitones from root)

The Pads generator omits the root (bass plays it) and voices the upper structure across 2 octaves.
"Upper structure" = the 3rd, 5th, 7th, and optionally 9th of the chord.

- **maj7** (e.g. Cmaj7 = C-E-G-B): full = [0,4,7,11]; upper [4,7,11,14] — E, G, B, D (add9)
- **min7** (e.g. Am7 = A-C-E-G): full = [0,3,7,10]; upper [3,7,10,14] — C, E, G, B (add9)
- **dom7** (e.g. G7 = G-B-D-F): full = [0,4,7,10]; upper [4,7,10] shell, or [4,10,14] no 5th
- **dom7sus4** (e.g. G7sus4 = G-C-D-F): full = [0,5,7,10]; upper [5,10,14] — floating, unresolved
- **min9** (e.g. Dm9 = D-F-A-C-E): upper (no root) = [3,7,10,14] — DJ Cam signature voicing
- **maj9** (e.g. Cmaj9 = C-E-G-B-D): upper (no root) = [4,7,11,14] — bright and airy
- **m7b5** (e.g. Dm7b5 = D-F-Ab-C): full = [0,3,6,10]; jazz minor ii chord, dark

Drop-2 shell voicings for the Rhythm track (3-note, more open):
- **min7 shell**: [0, 10, 15] — root, min7 (down), min3 (up an octave)
- **maj7 shell**: [0, 11, 16] — root, maj7 (down), maj3 (up an octave)
- **dom7 shell**: [0, 10, 16] — root, min7 (down), maj3 (up an octave)

---

### Dorian Mode Progressions

Dorian scale: [0,2,3,5,7,9,10] — minor with raised 6th (natural 6, not flat 6).
Characteristic sound: bittersweet minor; the raised 6th gives the major IV chord its colour.
Diatonic chords: im7, iim7, bIIImaj7, IVmaj7, vm7, vim7b5, bVIImaj7

**Two-chord pendulum options (each chord 4–8 bars):**
- im7 | bVIImaj7 — the defining Dorian vamp; St Germain Rose Rouge (Ebm7 | Db); e.g. Dm7 | C
  - bVII is major, giving a lift; "bittersweet oscillation" is the result
- im7 | IVmaj7 — also characteristic Dorian (funky, hopeful); e.g. Dm7 | Gmaj7
  - IV is the "Dorian identifier" chord; the raised 6th is the 3rd of IV
- im7 | vm7 — darker, less movement; e.g. Am7 | Em7 (close relative motion)

**Modal drift (2–3 chord changes over full song):**
- im7 (body) → bVIImaj7 (breakdown) → IVmaj7 (groove B) — gradual brightening arc
- im7 (32 bars) → IVmaj7 (12 bars) → im7 (return, 20 bars) — simple two-change drift

**Minor blues adaptation (12-bar structure tiling groove sections):**
- im7 (4 bars) | ivm7 (2 bars) | im7 (2 bars) | bVIImaj7 (1 bar) | IVmaj7 (1 bar) | im7 (2 bars)
- The IVmaj7 and ivm7 in the same progression creates the blues major/minor tension

**ii-V-i jazz cadence (slow, used at section transitions, not as a repeating loop):**
- iim7b5 (2 bars) | V7sus4 (2 bars) | im7 (resolve, 8+ bars)
- Example in D Dorian: Em7b5 (2 bars) | A7sus4 (2 bars) | Dm9 (8 bars)
- The sus4 delays the resolution — never sounds "resolved" in the classical sense

---

### Aeolian Mode Progressions

Aeolian scale: [0,2,3,5,7,8,10] — natural minor; flat 6 is the dark note.
Characteristic sound: melancholic, introspective, darker than Dorian.
Diatonic chords: im7, iim7b5, bIIImaj7, ivm7, vm7, bVImaj7, bVIImaj7

**Two-chord pendulum options:**
- im7 | bVIImaj7 — the default Aeolian loop; e.g. Am7 | G; darker than Dorian version
  because the b6 is in the scale, making the im7 denser
- im7 | ivm7 — pure minor; e.g. Am7 | Dm7; very dark, very still
- im7 | bVImaj7 — e.g. Am7 | F; the "relative major" chord, gives warmth to the dark

**Modal drift:**
- i | bVII | bVI | bVII (the classic Aeolian 4-chord loop, very slow: 4–6 bars each)
  — e.g. Am7 | G | F | G; the bVII as a "rocking chair" chord creates forward motion
- i | bVI | bIII | bVII (borrowed Phrygian feel; darker, more cinematic)

**Minor blues adaptation:**
- im7 (4 bars) | ivm7 (2 bars) | vm7 (2 bars) | im7 (4 bars) — avoids dom V
  for a more natural minor feel without the bebop cadence

---

### Mixolydian Mode Progressions

Mixolydian scale: [0,2,4,5,7,9,10] — major with b7; bluesy, open.
Characteristic sound: sunny with an undertow; the bVII is the signature.
Diatonic chords: Imaj7 (with b7 available), iim7, iiim7b5, IVmaj7, vm7, vim7, bVIImaj7

**Two-chord pendulum options:**
- I | bVII — THE Mixolydian vamp; e.g. G | F; Mobyesque piano (G→F area)
  - The bVII has no leading tone pull; rocks between tonic and neighbour
- I | IV — also common; e.g. G | C; open and resolved-feeling
- I | vm7 — e.g. G | Dm; mixing major tonic with minor v; Porcelain-adjacent

**Three-chord loop (modal drift territory):**
- I | bVII | IV — the "power ballad" Mixolydian loop; e.g. G | F | C; 4–6 bars each
  — Mobyesque piano: DM-C-G then F-Am-G maps to this pattern
- I | IV | bVII | I — same chords in a slightly different order; more circular

**Four-chord Moby/Porcelain model:**
- I | vm7 | bVImaj7 | bVIImaj7 — alternating major/minor gives cinematic floating quality
  — Use for static_groove songs where harmonic rhythm is 4–8 bars per chord

---

### Ionian Mode Progressions

Ionian scale: [0,2,4,5,7,9,11] — standard major; brightest of the four Chill modes.
Characteristic sound: buoyant, resolved, sunlit — the Bright/Free extreme.
Diatonic chords: Imaj7, iim7, iiim7, IVmaj7, V7, vim7, viim7b5

**Two-chord pendulum options:**
- Imaj7 | IVmaj7 — the most serene major vamp; e.g. Cmaj7 | Fmaj7
- Imaj7 | bVIImaj7 — Mixolydian borrow ("Moby open"); e.g. C | Bb; unresolved floating quality
- Imaj7 | vim7 — e.g. C | Am7; vi is the relative minor; gives bittersweet tinge

**I-vi-IV-V (acid jazz staple, Incognito / Brand New Heavies model):**
- Imaj7 (4 bars) | vim7 (4 bars) | IVmaj7 (4 bars) | V7sus4 (4 bars) = 16-bar cycle
  — V7sus4 instead of straight V7 delays resolution; avoids bebop snap
  — Use for Bright/Free songs in the most active groove sections

**ii-V-I (jazz cadence, slow — for section transitions or modal_drift):**
- iim7 (4 bars) | V7sus4 (2 bars) | Imaj7 (resolve, 8 bars)
  — Example in C: Dm7 | G7sus4 | Cmaj7
  — Works as a 1-time event at Groove A → Groove B return, not a looping pattern

**With Mixolydian bVII borrow** (Mobyesque style):
- Imaj7 | IVmaj7 | bVIImaj7 | Imaj7 — e.g. C | F | Bb | C
  — The bVII is non-diatonic to Ionian but so common in this genre it is a first-class option

---

### Sus4 Chord Usage

sus4 chords appear at V positions to delay or soften resolution. Also used as a standalone
vamp to create harmonic ambiguity (the "floating" quality characteristic of chill).

- **V7sus4 in cadences**: replaces V7 at all ii-V-I and I-vi-IV-V cadences; mandatory in Chill
- **Isus4 vamp**: a single sus4 chord held for 8+ bars; use in Breakdown section as the
  "harmonic zero point" — neither major nor minor, neither resolved nor dissonant
- **Chord at Breakdown**: always sus4 or plain 5th (power chord voicing) to erase harmonic
  identity; the rebuild back into groove re-establishes the mode identity
- MIDI voicing: dom7sus4 = [0, 5, 7, 10]; upper structure no root = [5, 10, 14] (4th, b7, 9th)

---

### Progression Selection Logic for ChillStructureGenerator

At song generation time, assign the progression family first (static_groove 35%,
two_chord_pendulum 30%, minor_blues 20%, modal_drift 15%), then select specific chords:

- **static_groove**: pick one chord from the tonic column for the active mode; hold all song
- **two_chord_pendulum**: pick one of the two-chord pairs listed for the active mode above;
  alternate every 4–8 bars in groove sections; use tonic chord only in breakdown
- **minor_blues**: use the 12-bar blues adaptation for the active mode; tile groove sections;
  use tonic chord for entire breakdown
- **modal_drift**: pick a 2–3 chord sequence from the modal drift list for the active mode;
  assign bars for each chord across the full song timeline; no bar changes in breakdown

All V7 chords become V7sus4. All chord roots must be diatonic to the active mode (no borrowed
roots except the explicit bVII option in Ionian/Mixolydian and the minor blues adaptations above).

---

## Part 12: Track Rule Catalog

One rule is selected per track per song (except where noted as always-active). Rules define
the primary pattern, section-by-section evolution, and velocity behavior. All rules log their
ID to the .zudio status file so the analyzer can correlate metrics to specific rule choices.

Format: `CHL-[TRACK]-[NNN] — Name — description. (probability%)`

---

### Drums

One drum rule selected per song. Beat style (electronic / neo soul / brush kit) is assigned
at the musical frame level before rule selection; rules within a beat style are weighted
below.

**CHL-DRUM-001 — Mobyesque Minimal** (electronic mode, 40% of Deep/Dream songs)
Kick step 1 always (vel 65–80); snare step 13 always (vel 60–75), step 5 at 60% probability;
closed hi-hat at steps 3, 7, 11, 15 with 50% probability each (vel 40–55). Total density
target 2–4 events/bar. Velocity ceiling 80. Derived from Mobyesque "Darcy" Logic drummer.
Evolution: Intro = kick only (steps 1, vel 60), hi-hat optional; Groove A = primary pattern;
Breakdown = kick step 1 only (vel 50), all else silent for first 4 bars, hi-hat returns bar 5
at vel 35; Groove B = primary pattern, ghost snare steps 4 and 12 at 20% probability added;
Outro = hi-hat removed by bar 4, snare removed by bar 6, kick-only final 2 bars.

**CHL-DRUM-002 — Electronic Pulse** (electronic mode, 35% of Deep/Dream songs)
Kick step 1 always (vel 70–85); kick step 9 at 50% (vel 60–70); snare steps 5 and 13
(vel 65–80); closed hi-hat 16th grid at 65% probability each (vel 45–60). Total density
4–6 events/bar. Slightly busier than CHL-DRUM-001 while remaining subdued.
Evolution: Intro = kick + snare only (no hi-hat); Groove A = full primary pattern;
Breakdown = silent 4 bars, hi-hat grid at 30% probability returns bar 5 (vel 35–45);
Groove B = full pattern plus open hi-hat accent step 1 of every 4th bar (vel 55–65);
Outro = hi-hat drops first (bar 2), snare drops (bar 6), kick-only last bar.

**CHL-DRUM-003 — Neo Soul Pocket** (neo soul mode, 60% of Bright/Free neo soul songs)
Kick step 1 (vel 88–95); kick step 3 at 30% (vel 60–70); electric snare step 3 (vel 80–90)
and step 13 (vel 75–85); hi-hat 16th grid steps 1,3,5,7,9,11,13,15 at 65% each (vel 50–65);
ghost snare steps 4, 8, 12 at 30% probability (vel 30–45). Crash note 49 on step 1 of the
first bar of each new section only (vel 95–100). Derived from Bosa Moon "Drummer - Neo Soul".
Evolution: Intro = kick + snare backbone only, no ghost notes, no hi-hat; Groove A = primary
pattern; Breakdown = kick step 1 only, all else silent (neo soul songs still take the breakdown);
Groove B = full pattern plus additional ghost snare at step 16 (30%), and occasional open hi-hat
step 9 (20%); Outro = ghost notes removed, hi-hat thins to 8th notes only.

**CHL-DRUM-004 — Neo Soul Laid Back** (neo soul mode, 40% of Bright/Free neo soul songs)
Like CHL-DRUM-003 but kick step 3 fires at 15% only (more space); ghost snare at 20% (softer
pocket feel); hi-hat fires at 50% per step (more open). Closer to a brushed feel while still
using the standard kit. Suitable for slower Bright/Free songs (88–95 BPM).
Evolution: same section arc as CHL-DRUM-003 but with shallower density peak in Groove B.

**CHL-DRUM-008 — St Germain Four-on-the-Floor** (stGermain beat style, Bright/Free moods, 35–40%)
Inspired by the main drum track of St Germain "So Flute" (118 BPM). Kick on all four beats
(steps 0, 4, 8, 12) every bar — the driving four-on-the-floor foundation. Snare on beats 2
and 4 (steps 4 and 12) only (backbeat). Ride cymbal on every 8th note (steps 0,2,4,6,8,10,12,14)
as the steady motor. Velocity ceiling 95; ride vel 68–82; kick vel 80–91; snare vel 76–90.
Variation: ride alternates between 8th-note and quarter-note density in 4–8 bar blocks
(70% prefer 8th-note pulse) — creates subtle textural evolution without breaking the groove.
Fills: approximately 1 per 15 bars. Fill types: snare roll (escalating 16th notes into bar
end, steps 8→10→12→13→14→15, vel 55→98) or snare accent (steps 12 and 15, vel 82–100).
Fills occur mid-groove only, never at intro or section boundaries.
Breakdown: kick step 0 only (vel 55) first 4 bars; sparse ride returns at vel 30–45 in
later breakdown bars (50% probability per bar).
Intro: full four-on-the-floor from bar 1 at reduced velocity (kick 55, snare 60, ride 45).

**CHL-DRUM-005 — Brush Ride** (brush kit mode, 60% of Bright/Free brush kit songs)
Ride cymbal note 51 steps 1, 5, 9, 13 always (vel 45–60); snare brush note 38 steps 5 and 13
(vel 40–55); kick note 36 step 1 always (vel 60–70), step 9 at 40% (vel 50–60); closed hi-hat
note 42 steps 3 and 11 (vel 35–50). Total density 3–5 events/bar. Derived from jazz quartet
brush kit model (Kind of Blue All Blues / DJ Cam Quartet).
Evolution: Intro = ride only (steps 1, 5, 9, 13 at vel 40); Groove A = full pattern;
Breakdown = silent 4 bars, ride returns bar 5 (vel 35, beats 1 and 3 only); Groove B = full
pattern with optional snare fill on beat 4 of every 8th bar (1-bar fill, vel 55–65);
Outro = kick removed bar 4, ride thins to beats 1 and 3 only bar 6, last 2 bars ride only.

**CHL-DRUM-006 — Brush Sparse** (brush kit mode, 40% of Bright/Free brush kit songs)
Ride cymbal steps 1 and 9 only (half-time feel, vel 40–55); snare brush step 9 only (vel 35–50);
kick step 1 only (vel 55–65). Total density 2–3 events/bar. Very restrained; suited to slow
Bright/Free songs or any song where lead is very dense.
Evolution: Intro = ride step 1 only; Groove A through B = primary pattern without variation;
Outro = ride step 1 only last 4 bars.

**CHL-DRUM-007 — Ghost Accent Rule** (always active, applied on top of primary rule)
After bar 24 in Groove A, and throughout Groove B: add one ghost snare event per bar at a
weak-beat step not already occupied (step 4, 8, 10, or 14; pick randomly). Velocity 25–40.
This rule fires only for electronic and neo soul modes; brush kit handles its own subtle
variations internally.

**Drum writing rules (all rules):**
- Maximum velocity by mode: electronic 80, neo soul 100, brush kit 65
- Kick always step 1 in all patterns (Chill anchors the downbeat even in sparse patterns)
- No fills longer than 1 bar; fills occur only at section boundaries
- Crash cymbal: section-start bars only; never in Breakdown or Outro
- Breakdown: CHL-DRUM-001 and 002 go silent 4 bars then return hi-hat only; 003 and 004 go
  kick-only; 005 and 006 go ride-only at lowest velocity

**Drum instrument pool:**
- Standard Kit (program 0) — default for electronic and neo soul modes
- 808 Kit (program 25) — optional, Deep/Dream electronic mode only
- Brush Kit (program 40) — **default for brush kit mode**; only kit used in that mode
- Jazz Kit (program 32) — optional alternative to Brush Kit

---

### Bass

One rule selected per song. All patterns anchor beat 1 as primary attack. Evolution
behavior varies by section; see each rule's evolution note.

**CHL-BASS-001 — Mobyesque Root Sustain** (static_groove family, Deep/Dream moods, 20%)
Step 1: root, duration 4 beats (held most of bar), vel 75–85. Step 9 at 40% probability:
5th of chord, duration 2 beats, vel 65–75. Simplest Chill bass. Derived from Mobyesque
P-Bass light track.
Evolution: Intro = as written, slightly softer (vel 65–75); Groove A = primary pattern;
after bar 24 in Groove A, step 9 fires at 60% (more movement); Breakdown = root whole bar,
duration all 16 steps, vel 75; Groove B = primary pattern with step 9 at 70%, and once every
8 bars a bass statement (CHL-BASS-006) substitutes for one bar; Outro = step 9 removed,
velocity declines to 60–70 over last 8 bars.

**CHL-BASS-002 — Syncopated Groove** (all families, all moods, 30%)
Step 1: root 2 beats vel 80–90; step 7: 5th or approach tone 1 beat vel 70–80; step 9: root
1.5 beats vel 75–85; step 11: passing tone (4th or 3rd) 0.5 beats vel 60–70; step 13: root
or 5th 1 beat vel 75–85; step 15: approach tone (semitone below next bar root) 0.5 beats
vel 65–75. Derived from Mobyesque Electric Bass track. Pattern fires at 60% probability per
bar; other bars use CHL-BASS-001 pattern.
Evolution: Intro = root only (CHL-BASS-001 behavior, no syncopation); Groove A bars 1–8
= 40% probability, ramps to 60%; Groove A bars 24+ = 70% probability; Breakdown = root
whole bar; Groove B = 75% probability; bass statements (CHL-BASS-006) appear every 8–12
bars; Outro = probability drops to 30% over last 8 bars, ending on root hold.

**CHL-BASS-003 — Walking Approach** (two_chord_pendulum and minor_blues families, Bright/Free, 15%)
Fires only in bars immediately before a chord change. Steps 1, 5, 9, 13 (quarter notes):
root → 3rd → 5th → approach tone (semitone below next chord root). Velocity 85–95, accent
on step 1. Derived from Five Below Blues walkdown. Between chord-change bars, CHL-BASS-002
or CHL-BASS-001 applies.
Evolution: Intro = absent; Groove A = fires at chord-change bars only; Groove A after bar
24 = also fires one bar before chord-change in anticipation; Breakdown = approach tone only
(step 15 single note); Groove B = fires at chord-change bars and the bar before; Outro = fires
at final chord change then root sustain to end.

**CHL-BASS-004 — Air Ostinato** (static_groove family, Deep moods, 15%)
A 4-bar diatonic figure cycling throughout. Bar 1: root (step 1, 2 beats) → 2nd (step 5,
1 beat) → root (step 9, 2 beats). Bar 2: 5th (step 1, 2 beats) → 4th (step 5, 1 beat) →
5th (step 9, 1 beat) → root (step 13, 1 beat). Bar 3: 3rd (step 1, 2 beats) → 2nd (step 9,
2 beats). Bar 4: root (step 1, 4 beats). All notes within one octave, stepwise, vel 80–90.
Derived from Air La Femme D'Argent Moog bass riff.
Evolution: Intro = bars 3 and 4 of the 4-bar riff only (entering mid-phrase feel); Groove A
= full 4-bar cycle tiling; Breakdown = bar 4 only (root held); Groove B = full 4-bar cycle,
bass statements allowed in bar 4 position every other cycle; Outro = bars 3 and 4 only
(reverse of intro entry), velocity declining.

**CHL-BASS-005 — Deep Root Drone** (all families, Dream moods at slowest BPM 72–80, 10%)
Root only, held for the full bar (all 16 steps), vel 70–80. Resolves to 5th at chord
changes (one bar of 5th, then back to root). Most minimal bass possible; suited to songs
where the pad layer IS the groove. Derived from Mobyesque P-Bass sustained pad behavior.
Evolution: Same throughout all sections; Breakdown uses the same pattern (root holds are
not disrupted by structural sections); Outro = velocity declines to 55–65 over last 8 bars.

**CHL-BASS-007 — St Germain 8th-Note Ostinato** (stGermain beat style, Bright/Free moods)
Inspired by the bass track of St Germain "So Flute": strict 8th-note pulse (one note every 2
steps) cycling through chord tones. Base distribution: root 50%, 5th 25%, b7 15%, 4th 10%.
Parabolic evolution arc — variety peaks at song midpoint (most chord-tone variety mid-song)
then returns to root-heavy form by the outro, giving the song a natural arc shape. Occasionally
a note is held for 4–8 steps (breathing room) instead of the strict 8th — probability rises
slightly at the arc peak (up to 13%). Monophonic; vel 82–90 consistent (locked feel).
Breakdown: root whole-note held 16 steps, vel 60. Intro/outro: root sustain with optional
5th on beat 3. Does not co-exist with CHL-BASS-001 through 006 — stGermain beat style always
routes to this rule exclusively.

**CHL-BASS-006 — Mobyesque Bass Statement** (supplementary rule, applied on top of any primary rule)
Once every 8–16 bars in Deep/Dream songs (once every 12–20 bars in Groove A, every 8–12
bars in Groove B): emit a 2–4 note melodic figure. Notes drawn from scale, wider register
span than primary pattern (up to 1.5 octaves), duration 0.5–1 beat each, vel 50–65
(noticeably softer than groove bass). Always in a bar where Lead 1 is resting. Acts as the
melodic comment that replaces the absent vocal. Derived from Mobyesque Bass Solo tracks.
Does not fire in Intro, Breakdown, or Outro. Absent for Bright/Free songs (Lead 2 covers
the call-and-response role instead).

**Bass writing rules (all rules):**
- Beat 1 always has a bass note in active sections; only Breakdown allows beat-1 silence
- Approach tone (semitone below root) fires only on step 15 (AND of beat 4) max once per bar
- Register: MIDI 40–64 (kTrackBass bounds; center 44–56); bass statement moments may use wider range within bounds
- Velocity accent: step 1 always 5–10 velocity points above other steps in same bar
- Drum-bass lock: step 1 of bass aligns with kick drum in all patterns; avoid snare beats
  (steps 5 and 13) for sustained notes
- No chromatic walking unless the destination is a chord tone within 2 bars

**Bass instrument pool:**
- Fretless Bass (program 35) — **default** (upright-adjacent warmth; slightly undefined pitch)
- Acoustic Bass (program 32) — Deep moods, warmest upright tone
- Electric Bass finger (program 33) — Bright/Free moods, round punchy tone
- Electric Bass pick (program 34) — optional brighter Bright/Free alternative
- Synth Bass 1 (program 38) — optional for Deep/Dream electronic sub-style (Moog bass feel)

---

### Lead 1

One rule selected per song at frame generation. Lead instrument (flute / trumpet / vibraphone
/ saxophone) is assigned at frame level; the rule shapes phrasing character within that
instrument's idiom.

**CHL-LD1-001 — St Germain Long Phrase** (Bright/Free moods, 25%)
4-bar phrase structure: bar 1 has 3–4 notes on strong beats, pentatonic degrees, duration
1.5–2 beats each; bar 2 continues as a question phrase, ending on the 2nd or 6th scale
degree (unresolved); bars 3–4 are rest. Range MIDI 65–85. Velocity 65–85 in groove.
Derived from St Germain Rose Rouge flute solo model.
Evolution: Intro bars 1–4 = silent; Intro bars 5+ = 1 phrase only (vel 45–60); Groove A =
1 phrase per 4 bars (rest bars 3–4 of each cycle); Breakdown = completely silent; Groove B =
1 phrase per 2–3 bars (rest compressed to 1 bar); Outro = 1 phrase every 6–8 bars,
velocity declining, final phrase resolves to root.

**CHL-LD1-002 — Short Punch** (Deep/Dream moods, 25%)
2-bar phrase: bar 1 has 2–3 punchy notes at syncopated off-beat positions (steps 3, 7, or 11),
duration 0.75–1 beat each; bar 2 is rest. Interval character: mostly steps (1–2 semitones)
with one leap of 3–5 semitones at phrase peak. Range MIDI 55–75. Velocity 70–90. Staccato
feel (note duration shorter than step grid). Derived from Miles Davis All Blues phrasing.
Evolution: Intro = silent 4 bars, then 1 phrase (vel 50–65); Groove A = 1 phrase per 4 bars
(bar 1 active, bars 2–4 rest); Breakdown = silent; Groove B = 1 phrase per 2 bars (alternating
active/rest bars); Outro = 1 phrase per 6 bars, velocity 55–70.

**CHL-LD1-003 — DJ Cam Dyad** (all moods, 20%)
2–4 bar phrases mixing single-note lines and 2-note dyads (3rd + 7th struck simultaneously —
vibraphone sustain makes dyads ring naturally). Density 3–5 notes per 2 bars. Interval
character steps 60% / leaps 40%. Range MIDI 60–80. Velocity 65–80 even across phrase.
Derived from DJ Cam Quartet vibraphone model.
Evolution: Intro = single-note phrases only (no dyads, vel 45–60); Groove A = primary
pattern; Breakdown = silent; Groove B = dyads more frequent (50% of phrase notes), occasional
3-note chord at phrase peak (vel 75–85); Outro = single notes only, vel declining.

**CHL-LD1-004 — Blues Lead** (Deep/Dream moods, 20%)
2–3 bar phrases with 4–6 notes. Duration per note 0.5–1 beat (medium articulation). Blues
scale emphasis: b3, b5, b7 appear in ~30% of notes beyond standard pentatonic. Phrase
direction: descending preferred (falling phrases = melancholic character). Phrase endings
on b7 or 5th (slightly unresolved). Range MIDI 50–70. Velocity 65–85.
Derived from blues saxophone idiom; register confirmed from Bosa Moon "Organ Solo" analysis.
Evolution: Intro = silent 4 bars, 1 short phrase bars 5+ (vel 50–65, no blue notes); Groove A =
1 phrase per 3–4 bars; Breakdown = silent; Groove B = 1 phrase per 2–3 bars, blue notes at full
30% rate; Outro = 1 phrase every 6 bars, velocity declining, endings resolve to root or 5th.

**CHL-LD1-005 — St Germain Staccato Burst** (stGermain beat style, 85%; other styles, 15%)
Inspired by the flute/melody style of St Germain "So Flute" — short staccato bursts of
2–4 notes (1–2 steps each, 16th or 8th duration) in active periods of 4–8 bars with one
burst every 2 bars, separated by silent gaps of 4–8 bars. Far sparser than the source
(which runs ~7.5 notes/bar continuously), but retains the staccato 16th-note articulation
character that defines the St Germain lead sound. Instrument-agnostic — pitch pool from
full scale regardless of lead instrument. Each burst navigates by scale index (±1 step,
±2 leap) from the previous note, anchored near the tonic. Velocity 62–81.
Intro/outro: gaps only (no active periods). Breakdown: always silent.
In code: fired by stGermain beat style with 85% probability; available at 15% probability
for other beat styles as a contrast option.

**CHL-LD1-006 — Pentatonic Restraint Rule** (always active, all Lead 1 rules; was CHL-LD1-005)
Notes draw from mode's pentatonic [0,2,3,7,9 for Dorian; 0,2,3,5,7 for Aeolian;
0,2,4,7,9 for Mixolydian/Ionian] as the primary pitch pool. The blue note (b5 =
+6 semitones from root) may appear at most once per phrase and in no more than 15% of
all phrases. Strong-beat notes must be chord tones (root, 3rd, 5th) at ≥65% rate.
Phrase-end notes land on root, 3rd, or 5th in ≥60% of phrases (strong landing).

**CHL-LD1-006 — Section Silence Arc** (always active, all Lead 1 rules)
Silence is not absence — it is structure. Enforces: Lead 1 silent for first 4 bars of
intro; Lead 1 completely absent during the entire breakdown; Lead 1 density diminishes
in outro (each successive phrase has ≥2 bars of rest before it). Violations of this rule
create the most common "busy" failure mode in chill generation.

**CHL-LD1-007 — Phrase Anti-Cluster** (always active, all Lead 1 rules)
No two Lead 1 phrases may start within 2 bars of each other. If the phrase-rest cycle would
produce phrases closer than 2 bars (due to shortened rests in Groove B), insert an extra 1-bar
rest. Lead 1 and Lead 2 phrases must not overlap for more than 2 consecutive beats — if Lead 2
enters before Lead 1 finishes, Lead 2 defers to the next rest window.

**Lead 1 writing rules:**
- Motif variation: repeat a melodic cell for 4–8 bars before mutating one interval
- Interval profile: steps (1–2 semitones) 45–55%, small leaps (3–5) 25–35%, large leaps
  (6+) 10–15%; after large leap, reverse direction 70%
- Velocity shape: notes within a phrase have a mild arc (first note 5–10 vel below peak;
  last note 5–10 vel below peak; peak at mid-phrase); avoids flat velocity lines
- Register bias by instrument: flute MIDI 65–85; trumpet MIDI 55–75; vibraphone MIDI 60–80;
  saxophone MIDI 50–70

**Lead 1 instrument pool:**
- Flute (program 73) — **default for Bright/Free**
- Muted Trumpet (program 59) — **default for Deep/Dream**; NEW to Zudio instrument palette
- Alto Sax (program 65) — Deep/Dream secondary; NEW to palette
- Tenor Sax (program 66) — optional alternative to Alto Sax
- Vibraphone (program 11) — all moods, tertiary option
- Oboe (program 68) — optional Deep/Dream alternative (melancholic, nasal quality)

---

### Lead 2

Lead 2 is always the call-and-response counter-voice to Lead 1. Instrument assigned at frame
level (opposite family from Lead 1). One behavior rule is selected per song.

**CHL-LD2-001 — Bosa Moon Register Response** (all moods, 35%)
Lead 2 phrases occur exclusively in the rests between Lead 1 phrases. Median pitch of Lead 2
in Groove sections must be ≥5 semitones below Lead 1 median (CHILL-RULE-12). Duration 1–2
bars. Velocity always 10–15 points below Lead 1. Density ≤50% of Lead 1 event count per
8-bar window. Derived from Bosa Moon "Organ Solo from Piano" vs "Organ Soli from bass".
Evolution: Intro = absent; Groove A enters after Lead 1 has completed 2 phrases (~bar 10–14);
Groove A = 1 phrase per 8 bars initially; Breakdown = absent; Groove B = 1 phrase per 4–6
bars; Outro = absent (Lead 1 carries out alone).

**CHL-LD2-002 — Harmonic Shadow** (Bright/Free moods, 30%)
Lead 2 echoes Lead 1 at the phrase level — not note by note. When Lead 1 begins a phrase,
Lead 2 schedules an identical phrase delayed by the shadow delay, with every note transposed
down by the shadow interval. Creates the Incognito / Brand New Heavies close-harmony effect.

Shadow interval: selected once at frame generation time. Diatonic 3rd (60%) or diatonic 6th
(40%). "Diatonic" means the transposed pitch class must be in the active scale per
effectiveMode; snap to nearest diatonic PC if not (CHL-SYNC-004 applies).

Shadow delay: 2 bars in early Groove A; compresses to 1 bar after Groove A bar 24 and
throughout Groove B. Fixed per song (not randomised per phrase).

If the shadow phrase would run past the next Lead 1 phrase onset, truncate the shadow at
Lead 1's next onset bar — Lead 2 yields immediately.

Groove B unison peak: at the highest-pitch note in each shadow phrase, 20% chance Lead 2
plays the same pitch as Lead 1 (no transposition) for that single note, then returns to the
shadow interval. Reinforces the "brass section unison hit" effect at phrase climaxes.

Evolution: Intro = absent; Groove A = enters bar 8 with 2-bar delay; Groove A after bar 24
= 1-bar delay; Breakdown = absent; Groove B = 1-bar delay with unison peak option; Outro = absent.

**CHL-LD2-003 — Counter Stab** (Deep/Dream moods, 20%)
Lead 2 plays short 2-note chord stabs (3rd + 7th dyad) on the AND of beat 2 or beat 4
when Lead 1 is resting. Stab duration 0.5 beats. Velocity 50–65 (softer than Lead 1
or Rhodes). Acts as a harmonic punctuation between Lead 1 phrases.
Evolution: Intro = absent; Groove A bars 1–8 = absent; Groove A bar 9+ = stabs at
30% probability per qualifying rest bar; Breakdown = absent; Groove B = 50% probability;
Outro = absent.

**CHL-LD2-004 — Sparse Drone** (Deep/Dream moods, 15%)
Lead 2 plays a single note (root or 5th) held for 2–4 bars at very low velocity (35–55),
then rests for 4–8 bars. Creates a sustained harmonic anchor below the Lead 1 activity.
Suited to the most minimal Deep songs where bass is also near-silent.
Evolution: Same behavior throughout Groove A and Groove B; Intro and Breakdown absent;
in Outro, held notes only on root (no 5th).

**CHL-LD2-005 — Groove B Emergence Rule** (always active, all Lead 2 rules)
Lead 2 activity level in Groove B must be measurably higher than in Groove A. If the
primary rule produces ≤1 phrase per 8 bars in Groove A, Groove B should produce ≥1 phrase
per 4–6 bars. This creates the structural sense that the second groove section has evolved
from the first — the arrangement has learned something during the breakdown.

**CHL-LD2-006 — Chord-Tone Bias** (always active, all Lead 2 rules)
Strong-beat notes in Lead 2 land on chord tones (root, 3rd, 5th, 7th) in ≥80% of
phrase events. Lead 2 carries more harmonic responsibility than Lead 1 (which can use
blue notes and passing tones more freely). Lead 2 never uses the blue note (b5).

**Lead 2 writing rules:**
- Velocity always 10–15 points below current Lead 1 bar velocity
- Register must remain ≥5 semitones below Lead 1 median at all times
- Never active during Intro, Breakdown, or Outro
- Phrases begin only during a Lead 1 rest; never interrupts an active Lead 1 phrase
- Maximum 1 simultaneous note (no chords except vibraphone dyads in CHL-LD2-003)
- Scale: same parent scale as Lead 1; simpler pentatonic-biased subset

**Lead 2 instrument pool:**
- Vibraphone (program 11) — **default** when Lead 1 is not vibraphone
- Flute (program 73) — when Lead 1 is muted trumpet or saxophone
- Celesta (program 8) — optional lounge sub-style (Bright/Ionian songs)
- Marimba (program 12) — optional brighter Bright/Free variation
- Oboe (program 68) — when Lead 1 is flute (darker counter-voice)

---

### Pads

One rule selected per song. Pads provide the sustained harmonic cushion beneath the Rhythm
(Rhodes) comping voice — consistent with the Pads role in all Zudio styles. Pads use actual
pad and string instruments with long sustain and slow attack. CHL-PAD-006 (Breakdown Sustain)
always applies regardless of which primary rule is active.

**CHL-PAD-001 — Long Lake Winter Strings** (35%)
One sustained string chord per 2 bars. Half-note rhythm. Pitch class content matching active
chord. Four voices in different registers: MIDI 36–48 (low), 48–60 (mid-low), 60–72
(mid-high), 72–84 (high). Velocity 55–70 (prominent mid-mix presence; confirmed from Long
Lake Winter vel 61–63).
Evolution: Intro = high voice only (MIDI 60–72), vel 30–45; Groove A bars 1–8 = high and
mid-high voices; Groove A bar 9+ = all four voices; Breakdown = CHL-PAD-006; Groove B =
all four voices, vel 60–75; Outro = voices drop out one by one every 4 bars (high drops
first), last 4 bars low voice only.

**CHL-PAD-002 — Air Staggered Entry** (20%)
Same harmonic content as CHL-PAD-001 but voices enter sequentially 8 bars apart. Voice 1
(high, MIDI 72–84) enters at Groove A bar 1. Voice 2 (mid-high, 60–72) enters bar 9.
Voice 3 (mid-low, 48–60) enters bar 17. Voice 4 (low, 36–48) enters bar 25. Creates a
natural crescendo without automation. Derived from Winter Flight string layering (4 voices
× 8-bar offset confirmed).
Evolution: Breakdown = CHL-PAD-006 (all voices silent); Groove B restarts the stagger from
voice 1 only (4 bars apart instead of 8 to signal the return).

**CHL-PAD-003 — Mobyesque Pad Anchor** (15%)
One sustained synth pad chord per 4 bars. Whole-note duration (held full 4 bars, no
re-attack). Single voice only. Register MIDI 43–60 (low-mid; Mobyesque pads confirmed
MIDI 43–55). Velocity 75–85 (moderate presence; harmonic glue under Rhodes).
Derived from Mobyesque synth pad tracks (0.01–0.04 notes/bar, vel 78–81).
Evolution: Groove A and Groove B = same level; Intro = vel 55–65; Breakdown = CHL-PAD-006;
Outro = velocity declines to 40–50 over last 8 bars.

**CHL-PAD-004 — Absent** (Deep/Dream minimal songs, 20%)
No Pads MIDI events in Groove sections. Rhythm (Rhodes) carries the harmonic weight alone.
Breakdown still receives CHL-PAD-006 (the sus4 chord provides harmonic grounding even in
the most minimal arrangements).

**CHL-PAD-005 — Velocity Restraint Rule** (always active, all Pads rules)
Pads velocity must never exceed Rhythm (Rhodes) velocity in the same bar. Pads is felt
beneath the comping, not heard as a distinct voice above it.

**CHL-PAD-006 — Breakdown Sustain** (always active in Breakdown and Outro final bars)
One sustained chord held for the full Breakdown duration. Voicing: sus4 or sus2 (no 3rd)
— erases modal identity. Velocity 45–60. No rhythmic pattern. Also fires as the final state
in the Outro when Rhythm has fully declined. Applies regardless of which primary Pads rule
is selected, including CHL-PAD-004 Absent.

**Pads writing rules:**
- Note duration always ≥2 beats (Pads is a sustain voice, never rhythmic)
- Register: MIDI 36–84; spread across low and mid registers, complementing Rhythm
- Chord content: always matches active chord from chord plan (no independent harmony)
- Half-note or whole-note durations only; never rhythmically active
- Absent in Intro for first 4 bars; enters by bar 5 at reduced velocity

**Pads instrument pool:**
- Warm Pad (program 89) — **default**
- String Ensemble 1 (program 48) — alternate (more acoustic feel)
- String Ensemble 2 (program 49) — alternate (lower strings; Deep moods)
- Synth Strings 1 (program 50) — Bright/Free moods (brighter attack)
- Choir Aahs (program 52) — optional atmospheric Deep/Dream
- Pad 3 Poly Synth (program 90) — optional electronic Deep/Dream

---

### Rhythm

One primary comping rule selected per song based on mood and beat style. Rhythm is the
active harmonic voice in Chill — the Rhodes electric piano that defines the style. Unlike
Pads (which sustains), Rhythm comps rhythmically and drives the groove feel. Absent in
the first 8 bars of Intro and completely silent in Breakdown. CHL-RHY-005 (Space Rule)
always applies.

**CHL-RHY-001 — St Germain Syncopated** (Bright/Free moods, 35%)
Chord strikes at step 0 (beat 1 downbeat) and step 6 (AND of beat 2) — confirmed from
direct MIDI analysis of St Germain "So Flute" piano track (two strikes per bar at these
exact positions, 4-note voicings, vel locked at 89). 4-note jazz voicing [3rd, 5th, 7th,
9th] — root omitted (bass covers root). Each strike held 1.5 beats (5 steps).
Velocity 75–85 primary. Occasional fill strike at step 10 (AND of beat 3) or step 14
(AND of beat 4) at 30% probability per bar, vel 55–65. Register MIDI 48–72.
Note: earlier plan versions had wrong step positions (3 and 11); corrected to match source.
Evolution: Intro bars 1–8 = absent; Intro bars 9+ = sparse (1 strike per 4 bars, vel
50–65); Groove A = primary pattern; Groove A after bar 24 = occasional CHL-RHY-003
variant substitutes for 1 in 4 bars; Breakdown = absent; Groove B = primary pattern at
vel 80–90; Outro = velocity declines 5 per 4 bars, last 4 bars = single sustained chord only.

**CHL-RHY-002 — Moby Backbeat** (Deep/Dream moods, 35%)
Chord strikes at step 5 (beat 2) and step 13 (beat 4). 3-note shell voicing [root, 5th,
7th]. Step 5 held 1.5 beats (vel 65–75); step 13 held 1 beat (vel 60–70). 30% probability
per bar that only one of the two strikes fires. Velocity ceiling 75.
Derived from Moby "Why Does My Heart Feel So Bad" backbeat piano model.
Evolution: Intro bars 1–8 = absent; Intro bars 9+ = step 5 only (no step 13), vel 45–55,
1 strike per 2 bars; Groove A = primary pattern; Breakdown = absent; Groove B = primary
pattern, step 13 fires at 80% (was 70%); Outro = velocity declines, step 5 only last 4 bars.

**CHL-RHY-003 — Bosa Moon Broken Chord** (Bright/Free moods, 20%)
8th-note grid: notes at steps 1, 3, 5, 7, 9, 11, 13, 15. Chord tones [root, 3rd, 5th,
7th, 9th] cycled ascending then descending. Duration 0.75 beats each. 30–40% chance of
two simultaneous notes on step 1 or step 9 (block chord accent). Register MIDI 48–69
(max 2-octave span). Velocity 70–85 arpeggiated; 80–95 block accents. ~10 notes/bar.
Derived from Bosa Moon "Keyboard Player - Broken Chords" MIDI analysis.
Evolution: Intro bars 1–8 = absent; Intro bars 9+ = descending arpeggio only (steps 9,
11, 13, 15), vel 50–65; Groove A = full pattern; Breakdown = absent; Groove B = full
pattern with 40–50% block chord rate; Outro = ascending arpeggio only (steps 1, 3, 5, 7),
velocity declining.

**CHL-RHY-004 — Deep Sustain** (Deep/Dream moods, slowest BPM 72–80, 10%)
One chord per 2 bars, struck on step 1, held for 1.8 bars. Shell voicing [root, 5th, 7th].
Velocity 60–70. No syncopation; chords land on the beat. Suited to the most minimal Deep
songs (Moby Down Slow model) where even backbeat comping feels too dense.
Evolution: Intro bars 1–8 = absent; Intro bars 9+ = same pattern; Groove A and Groove B =
primary pattern unchanged; Breakdown = absent; Outro = velocity declines to 40–50, sustain
extended to full 2 bars.

**CHL-RHY-005 — Space Rule** (always active, all Rhythm rules)
Every primary comping rule has a per-bar probability of producing a completely silent bar
(no strikes): 15% in Groove A, 20% in Groove B. Silent bars cannot be consecutive (maximum
1 silent bar before next strike fires). This prevents Rhodes from becoming a relentless
clock — silence between strikes is a feature.

**CHL-RHY-006 — Breakdown and Intro Silence** (always active)
Rhythm is completely absent for the first 8 bars of Intro and throughout the entire
Breakdown. In Outro, comping density declines (probability halved every 4 bars) and stops
entirely in the final 4 bars.

**Rhythm writing rules:**
- Jazz voicing: root omitted (bass covers it); upper structure [3rd, 5th, 7th, 9th]
  voiced across 2 octaves; no thirds below MIDI 48
- Chord changes follow ChillStructureGenerator chord plan; no anticipation of changes
- If Lead 1 density in a bar is ≥3 notes, Rhythm velocity ceiling drops by 10 for that bar
- Note duration always ≥0.75 beats (no staccato except in CHL-RHY-003 arpeggiation)
- Register: MIDI 48–72 (mid range; Pads occupies low-mid beneath)

**Rhythm instrument pool:**
- Electric Piano 1 (program 4) — **default** (Rhodes feel; primary harmonic voice)
- Electric Piano 2 (program 5) — alternate (Wurlitzer; brighter attack)
- Grand Piano (program 0) — deepest Deep/Dream moods (Moby influence)
- Harpsichord (program 6) — optional very bright Bright/Free alternative

---

### Texture

Texture is exclusively the audio ambient loop track. MIDI harmonic sustain is handled by
the Pads track (pad/string instruments); no MIDI texture layer exists in Chill. Adding a
third MIDI harmonic layer on top of Pads and Rhythm would be muddy. One rule applies per song.

**CHL-TEX-001 — Audio Ambient Texture** (~30% of songs)
A looping ambient audio clip plays from song start to end at fixed low volume. One clip
selected at random: Soft rain, Cafe murmur, Vinyl crackle, Late night city, Tape hiss,
Cocktail hour, Distant thunder, Jazz club bleed. Volume: -18 to -12 dB relative to master.
No section-based evolution (clip runs continuously at fixed level). Clip selection logged
to .zudio file as chillAudioTexture field.

**CHL-TEX-002 — Absent** (~70% of songs)
No texture track. Pads and Rhythm provide sufficient harmonic depth and warmth.

**Texture rules:**
- Audio clips bundled in Resources/Textures/ as 44.1kHz mono WAV, ~30-sec loops
- AudioTexturePlayer uses AVAudioPlayerNode for seamless looping, separate from MIDI pipeline
- Volume fixed at -18 to -12 dB; never audible on its own, only felt as room ambience
- If no texture file is found, AudioTexturePlayer is silent (no error)

For audio texture mode, no MIDI instrument is used. AudioTexturePlayer handles playback.


## Part 13: Effects and Panning

---

### 13.1 — Signal Chain (reference)

All Chill tracks use the same signal chain already in place for other styles:

`sampler → boost (gain/pan LFO) → sweepFilter (LFO low-pass) → delay (AVAudioUnitDelay) → comp → lowEQ → reverb (AVAudioUnitReverb) → master mixer`

The effect buttons the user sees (Boost, Delay, Reverb/Space, Trem, Comp, Low, Sweep, Pan)
map to nodes already in this chain. Chill configures their defaults differently from Ambient —
notably shorter reverb tails, tighter delays, and lower wet/dry mixes, reflecting the groove-
oriented rather than purely atmospheric character of the style.

---

### 13.2 — Effects Philosophy for Chill

Chill sits between Ambient (very wet, very spacious) and Motorik (relatively dry, mechanical)
on the reverb/space spectrum. The reference sound — St Germain, DJ Cam, Moby Play — is
sophisticated and warm but not cavernous. The groove must remain audible and felt; excessive
reverb washes out the Rhodes comping rhythm.

Key differences from Ambient defaults:
- Reverb tails are shorter (large chamber or plate, not cathedral)
- Reverb wet % is 10–25 points lower across all tracks
- Delays are shorter and have less feedback (groove must not smear)
- Compression is more prominent (programmed beats need it; Rhodes dynamics benefit from it)
- Tremolo is used on the Rhythm (Rhodes) track — the classic tremolo-Rhodes sound is central
  to the nu-jazz and downtempo aesthetic

---

### 13.3 — Per-Track Effect Defaults

---

**Lead 1** (Flute, Muted Trumpet, Vibraphone, Saxophone)

- Space (Reverb) ON — preset: Large Chamber, wet 62%
  Gives the lead voice a sense of a real performance space without blurring the rhythm.
  Large Chamber is warm but has a shorter tail than Cathedral — appropriate for a groove track.

- Delay ON — delay time: dotted quarter note (0.75 beats at current BPM), feedback 45%,
  low-pass cutoff 4200 Hz, wet 38%
  A rhythmically locked delay adds sustain and depth to sparse melodic phrases (2–4 bar
  phrases with rests benefit from a lingering tail). The low-pass cutoff darkens the repeats
  so they recede naturally. Formula: `delayTime = (60.0 / bpm) * 0.75`

- Comp ON — gentle, ratio ~2:1, slow attack (15 ms) to preserve phrase attack transients,
  fast release (80 ms)
  Evens out the velocity arc within phrases without squashing the lead character.

---

**Lead 2** (Vibraphone, Flute, Celesta, Oboe)

- Space (Reverb) ON — preset: Large Chamber, wet 55%
  Same preset as Lead 1 but drier — Lead 2 is the subordinate voice and should sit slightly
  further back in the stereo image.

- Delay ON — delay time: quarter note (1.0 beat), feedback 30%, low-pass cutoff 3800 Hz,
  wet 28%
  Shorter, less present delay than Lead 1. The counter-melody needs less sustain; too much
  delay on Lead 2 would obscure the call-and-response relationship with Lead 1.
  Formula: `delayTime = (60.0 / bpm) * 1.0`

- Comp ON — same settings as Lead 1; ensures Lead 2 dynamics track Lead 1's dynamic envelope
  (since Lead 2 velocity is set 10–15 points below Lead 1, compression prevents it from
  being inaudible in quieter passages)

---

**Rhythm** (Rhodes — Electric Piano 1, Wurlitzer, Grand Piano)

- Trem ON — rate 3.5 Hz, depth 30%
  The tremolo-Rhodes sound is the defining timbre of nu-jazz and downtempo. A slow, gentle
  tremolo on the gain LFO (the Boost node) produces the classic Rhodes "heartbeat" quality
  heard on St Germain Tourist and Moby Play. Rate 3.5 Hz is slow enough to feel organic
  (not a fast vibrato); depth 30% is audible but not dramatic.

- Space (Reverb) ON — preset: Plate, wet 48%
  Plate reverb has a bright, even tail with less low-frequency buildup than chamber reverbs.
  For a comping instrument that must stay rhythmically clear (syncopated hits, broken chords),
  plate keeps the attack crisp while adding warmth. Lower wet % than leads — the Rhodes must
  stay in the groove.

- Comp ON — ratio ~3:1, medium attack (8 ms), medium release (120 ms)
  More aggressive compression than the leads. Rhodes voicings (3–4 simultaneous notes)
  benefit from compression to even out inter-note level differences. The Moby backbeat and
  Bosa Moon broken chord patterns especially benefit — the block chord accents would
  otherwise be significantly louder than the arpeggiated notes.

---

**Pads** (Warm Pad, String Ensemble, Synth Strings, Choir Aahs)

- Space (Reverb) ON — preset: Medium Hall, wet 75%
  The sustained pad layer should feel spacious — more reverb than the active voices but
  less than Ambient's cathedral presets. Medium Hall gives the strings warmth and room
  presence without overwhelming the groove.

- Sweep ON (very slow) — LFO period: 8–16 bars, depth 0.4
  A very slow low-pass filter sweep on the Warm Pad or String Ensemble creates gentle
  tonal movement in the sustained chord layer. This prevents the pad from sounding static
  over long sections. At an 8–16 bar period, the movement is felt but not consciously heard
  as an effect. OFF by default for Choir Aahs (the vowel formant already provides movement).

- Boost ON — +3 dB presence boost
  The sustained pad competes with the reverb tail of all other tracks. A small presence
  boost ensures the harmonic cushion remains audible in the mix without increasing the
  fader level. Applies to String Ensemble and Synth Strings; lower boost (+1 dB) for
  Warm Pad which already occupies the mid-frequency space.

---

**Bass** (Fretless Bass, Acoustic Bass, Electric Bass finger)

- Low (shelf) ON — +4 dB at 80 Hz
  Fretless and Acoustic Bass GM programs can sound thin on standard MIDI playback. A
  low-shelf boost at 80 Hz restores the warmth and body of an upright or fretless bass
  tone. Reduce to +2 dB for Electric Bass finger (already has more low-end in the GM
  sample).

- Comp ON — ratio ~4:1, fast attack (3 ms), medium release (150 ms)
  Bass compression is essential for groove styles. The Chill bass alternates between
  sustained root holds (very quiet) and syncopated active patterns (louder), and between
  Primary patterns A/B (moderate velocity) and Bass Statement moments (softer, mel). A
  4:1 ratio keeps all bass activity at a consistent level within the mix.

- Space (Reverb) ON — preset: Medium Room, wet 35%
  Minimal reverb on bass — just enough to remove the completely dry "MIDI DI" quality.
  Medium Room with low wet % adds a small room ambience without blurring the groove.
  Bass must remain tight; more reverb here than 35% degrades groove feel noticeably.

---

**Drums** (Standard Kit, 808 Kit, Brush Kit)

- Comp ON — ratio ~5:1, fast attack (2 ms), fast release (60 ms)
  Programmed beats need compression more than live drums. The Chill drum patterns
  (electronic and neo soul modes) have kick/snare events at 65–95 velocity alongside
  ghost notes at 30–45 velocity. Compression prevents the ghost notes from disappearing
  while controlling the kick transient. Punch-style compression (fast attack, fast release)
  is most appropriate for a groove context.

- Space (Reverb) ON — preset: Plate, wet 42%
  Plate reverb is the most appropriate for programmed beats — it has an even, classic
  quality associated with 1980s–1990s drum machines and samplers (the gear that generated
  the reference sounds). 42% wet sits between Ambient's washy drums and a fully dry
  programmed beat; gives the kit a sense of physical space without sounding like a
  live room.

- Low (shelf) ON — +2 dB at 60 Hz
  Adds weight to the kick drum (MIDI note 36). Electronic and neo soul mode kick drums
  in GM kits often lack the low-end weight of a produced track. A gentle +2 dB shelf at
  60 Hz reinforces the kick without introducing boom. Not applied to Brush Kit (brush
  drums have a different frequency character; the low shelf would make brush patterns
  sound unnatural).

  Implementation note: apply Low shelf only when beatStyle == .electronic or .neoSoul;
  bypass for .brushKit.

---

### 13.4 — Default Pan Positions

Pan values use the range -1.0 (full left) to +1.0 (full right), 0.0 = center.
These are static panning positions set at song load — not the LFO auto-pan effect.

The stereo image is designed around a late-night jazz performance perspective: rhythm
section centered, melody instruments spread left and right, countermelody answering
from the opposite side to Lead 1.

- **Bass:** 0.0 (center)
  Bass is always center. Sub-bass energy is mono by convention; panning it loses energy.

- **Drums:** 0.0 (center)
  Kick and snare centered. Hi-hat is allowed a minor offset (+0.10) in implementation
  if a more live feel is wanted, but the default is fully centered.

- **Rhythm (Rhodes):** +0.20 (slightly right)
  Traditional jazz recording placement for piano. Also separates the comping voice from
  Lead 1 (which sits left), creating the natural dialogue between soloist and accompanist.

- **Pads:** -0.15 (slightly left)
  The sustained pad layer balances the Rhodes. A slight left offset fills the left-center
  space. If the Sweep LFO is active, the slow filter movement combined with the pan offset
  creates a sense of width without an explicit stereo effect.

- **Lead 1:** -0.30 (moderate left)
  Primary solo voice. Left-of-center placement is standard for the lead instrument in a
  jazz recording and separates it clearly from the Rhodes (right) in the mid field.

- **Lead 2:** +0.40 (moderate right)
  The counter-melody answers Lead 1 from the opposite side. The +0.40 placement creates
  a clear stereo conversation: phrases travel left → right (Lead 1 asks, Lead 2 answers)
  or right → left depending on which voice initiates. Wider than Pads or Rhodes to
  maximise the sense of spatial separation.

- **Texture (audio clips):** 0.0 (center)
  Audio texture files (rain, cafe murmur, etc.) are mono WAVs and play centered. The
  ambient character fills both channels naturally via the room acoustics of the recording.

Summary table:

- Bass: 0.0
- Drums: 0.0
- Rhythm (Rhodes): +0.20
- Pads: -0.15
- Lead 1: -0.30
- Lead 2: +0.40
- Texture: 0.0

---

### 13.5 — configureChillEffects(bpm:)

Called at song load alongside the existing style configuration functions:

```
func configureChillEffects(bpm: Double) {
    let beat = 60.0 / bpm

    // --- Delays ---
    lead1Delay.delayTime     = beat * 0.75   // dotted quarter
    lead1Delay.feedback      = 45
    lead1Delay.lowPassCutoff = 4200
    lead1Delay.wetDryMix     = 38

    lead2Delay.delayTime     = beat * 1.0    // quarter note
    lead2Delay.feedback      = 30
    lead2Delay.lowPassCutoff = 3800
    lead2Delay.wetDryMix     = 28

    // Rhythm (Rhodes): no delay — groove must not smear
    rhythmDelay.wetDryMix = 0

    // --- Reverb presets ---
    lead1Reverb.loadFactoryPreset(.largeChamber);  lead1Reverb.wetDryMix = 62
    lead2Reverb.loadFactoryPreset(.largeChamber);  lead2Reverb.wetDryMix = 55
    rhythmReverb.loadFactoryPreset(.plate);        rhythmReverb.wetDryMix = 48
    padsReverb.loadFactoryPreset(.mediumHall);     padsReverb.wetDryMix = 75
    bassReverb.loadFactoryPreset(.mediumRoom);     bassReverb.wetDryMix = 35
    drumsReverb.loadFactoryPreset(.plate);         drumsReverb.wetDryMix = 42

    // --- Rhodes tremolo ---
    rhythmTrem.rate  = 3.5   // Hz
    rhythmTrem.depth = 0.30  // 30% amplitude modulation

    // --- Static pan positions ---
    bassTrack.pan    =  0.0
    drumsTrack.pan   =  0.0
    rhythmTrack.pan  = +0.20
    padsTrack.pan    = -0.15
    lead1Track.pan   = -0.30
    lead2Track.pan   = +0.40
    textureTrack.pan =  0.0

    // --- Drum Low shelf: electronic/neoSoul only ---
    if beatStyle == .electronic || beatStyle == .neoSoul {
        drumsLowEQ.gain      = +2.0   // dB
        drumsLowEQ.frequency = 60.0   // Hz
    } else {
        drumsLowEQ.bypass = true
    }
}
```

---

## Part 14: Title Generator

Short (1–3 words), urban, nocturnal, cosmopolitan. Mixes French and English, evoking late-night city atmosphere, jazz-bar culture, and cool minimalism.

Six pools, mood-shaded (Deep/Dream weight French + city; Bright/Free weight English + adj+noun):
- French single words: Velours, Brume, Nuit, Crépuscule, Nocturne, Étude, Reverie, Minuit, Lumière, Calme
- English two-word: Blue Hour, Glass City, Slow Burn, Still Frame, Warm Static, Cold Burn, Slow Exposure
- City districts: Marais, Belleville, Brixton, Shoreditch, Saint-Germain, Bastille, Amsterdam, Ladbroke Grove, Lisbon, Baie d'Urfé, Montreal, Dorval, Pointe-Claire, Sainte-Anne-de-Bellevue, Saint-Laurent, Traverse City, Detroit
- Cool adjective + noun (generative, 13×14 = 182 combos): Quiet Signal, Dark Dissolve, Long Exposure, Faint Echo
- Time-of-day: After Midnight, Three AM, Last Set, Before Dawn, Midnight Minus One
- Jazz first names: Chet, Miles, Bill, Monk, Gil, Wes

**Examples:** Brume, Belleville, Quiet Pulse, Blue Hour, Three AM, Chet, Saint-Germain, Dark Dissolve, Nocturne, Last Set

---

## Part 15: Tonal Consistency Rules (CHILL-SYNC)

Always-active rules that prevent the tonal clash problems documented in Motorik (Studies 01–02)
and Kosmic (Studies 02–03). Every generator must implement these before shipping. They are
not probabilistic — they fire on every note, every bar, every song.

---

**CHL-SYNC-001 — Scale pools anchor to song tonic**

All note pools derive from `frame.key + effectiveMode`, never from `chord.root`. When the
chord root shifts (bVII, bVI, IV, etc.), upper voices stay diatonic to the song tonic. Only
the bass lowest voice moves with the chord root. Passing the active chord root to a note
pool builder instead of the song tonic was the root cause of catastrophic clashes in both
Motorik Study 02 and Kosmic Study 03.

---

**CHL-SYNC-002 — Mode-aware chord root selection**

ChillStructureGenerator uses mode-specific permitted root lists. Never hardcode a single
mode's degree list for all modes. Chill-specific lists:

- Dorian: [1, 2, b3, 4, 5, 6, b7] — note: raised 6th, no b6
- Aeolian: [1, 2, b3, 4, 5, b6, b7] — b6 only here
- Mixolydian: [1, 2, 3, 4, 5, 6, b7] — no b3, no b6
- Ionian: [1, 2, 3, 4, 5, 6, 7] — no b3, no b6, no b7 except explicit bVII borrow

bVII chord in Ionian/Mixolydian songs is a permitted explicit special case ("Moby open").
It must be coded as a named exception — not as a generic b7 degree — so it cannot
accidentally activate in minor-mode songs where bVII has a different scale meaning.

b6 is diatonic only in Aeolian. Using b6 as a chord root in Dorian, Ionian, or Mixolydian
causes the same catastrophic clash pattern seen in Kosmic Study 03 (Auxese-test-bridge,
28 bars on b6 root in C Dorian: 40.8% consonance, 118 simultaneous semitone clashes).

---

**CHL-SYNC-003 — effectiveMode computation**

The variable passed to NotePoolBuilder must be `effectiveMode`, not `section.mode`.
A-sections (Groove A, Intro, Outro) default their `section.mode` to Dorian by design —
but the actual song mode is in `frame.mode`. Using `section.mode` directly caused scale
tension pools to reflect Dorian in Mixolydian and Ionian songs (Kosmic Study 02 root cause).

Rule: `effectiveMode = frame.mode` for Intro, Groove A, Breakdown, Outro;
`effectiveMode = section.mode` for Groove B bridge/solo sections if they carry a distinct mode.

---

**CHL-SYNC-004 — Rhythm voicing snapped to scale after interval arithmetic**

After applying jazz chord intervals [3rd, 5th, 7th, 9th] or shell voicings [root, 5th, 7th],
snap each resulting pitch class to the nearest diatonic PC of `effectiveMode`. This catches
chromatic tones that slip in through standard interval arithmetic.

Example: IVmaj7 in D Dorian. Interval arithmetic gives [G, B, D, F#]. All diatonic. But
IVmaj7 in G Aeolian gives [C, E, G, B]. E natural is not in G Aeolian (has Eb). Snap E→Eb.

Root omission is also enforced here: the lowest note in any Rhythm voicing must not be
the chord root (bass covers it). If interval arithmetic produces root as lowest note,
invert the voicing upward until root is not the lowest voice.

---

**CHL-SYNC-005 — No hardcoded pitch classes**

All note pools derived from `frame.key + effectiveMode` at runtime. Never hardcode a
pentatonic pattern as a fixed semitone array such as `[0, 2, 4, 7, 9]` (major pentatonic)
or `[0, 3, 5, 7, 10]` (minor pentatonic).

The Chill lead pentatonic for Dorian [0, 2, 3, 7, 9] must be computed as the 1st, 2nd,
b3rd, 5th, and 6th degrees of the runtime Dorian scale — not hardcoded. If the song is
in A Dorian, the pentatonic must be [A, B, C, E, F#] not a transposition of a fixed array
that might carry a wrong accidental.

Blues note (b5 = +6 semitones from root) is a known intentional chromatic exception for
Lead 1 rules. It is exempt from snap but must appear in ≤15% of phrases and never on a
structurally strong beat (beat 1 or beat 3).

---

**CHL-SYNC-006 — Override state cleared after generation**

`frame.keyOverride`, `frame.modeOverride`, `frame.tempoOverride` must all be set to `nil`
immediately after `SongGenerator.generateChill()` completes. Chill's mood-dependent
parameters (BPM range, beat style, lead instrument) make it especially vulnerable to
override lock-in if the previous song's state persists. This was confirmed in Motorik as
a key clustering bug (five consecutive E Dorian songs).

---

**CHL-SYNC-007 — Lead 1 primary; Lead 2 strictly subordinate**

Lead 2 receives Lead 1's phrase onset array so it can schedule responses in the gaps.
Lead 2 note count must not exceed Lead 1 note count in any 8-bar Groove window. When
Lead 1 is sparse or silent, Lead 2 defers — it never fills the space created by Lead 1's
restraint. The silence is the point.

If both leads are silent for more than 8 consecutive bars in Groove A, inject a single
held note (root or 5th, vel 45–55) into Lead 2 to maintain minimal harmonic presence.
This prevents dead arrangements while preserving the sparse character.

Lead 2 never plays simultaneously with Lead 1. If a Lead 2 phrase onset would overlap
an active Lead 1 note, defer Lead 2 to the next available rest window.

---

**CHL-SYNC-008 — Bass root at bar boundaries**

The first note in each bar of the Bass track must have pitch class matching the active
chord root from the chord plan. Permitted exceptions:

- Approach tone (semitone below root) on beat 4 of the bar immediately before a chord change
- Bass statement moments (CHL-BASS-006 Mobyesque Bass Statement): one bar every 8–16 bars in Groove B only

Any bass note on beat 1 that is not the chord root and not a permitted exception is a
guaranteed tonal clash source, particularly when Pads and Rhythm are voicing the same chord.

---

**CHL-SYNC-009 — Breakdown modal identity erasure (architectural)**

During Breakdown, the following are enforced unconditionally — not probabilistically:

- Pads: sus4 or sus2 voicing only (no 3rd; mode identity erased)
- Rhythm: completely absent (not reduced — absent)
- Lead 1: completely absent
- Lead 2: completely absent
- Bass: root only, held for full bar
- Drums: mode-dependent (electronic: kick only; neo soul: kick only; brush: ride only)

The Breakdown must strip the texture to a point where the mode is unidentifiable.
This creates the tension that makes the Groove B return feel like a resolution. A Breakdown
that still has comping or lead notes fails musically even if it passes consonance metrics.

---

**CHL-SYNC-010 — Progression family chord root validation**

Before writing any chord root to the chord plan, ChillStructureGenerator verifies it is
in the permitted list for the active mode (CHL-SYNC-002).

Two_chord_pendulum: both chord roots validated. If a pendulum pairing includes a
mode-inappropriate root (e.g., b6 in Dorian), substitute with the nearest diatonic
alternative from the permitted list (e.g., 4 or b7).

Modal_drift: each root in the drift sequence validated individually.

Minor_blues: the 12-bar pattern per mode (as defined in Part 11) uses only verified
diatonic roots. Do not derive the minor blues pattern from a generic template — use the
mode-specific version from the chord progression catalog.

---

**CHL-SYNC-011 — Hard density ceilings (labeled breaks)**

Generator loops that produce notes must exit via a labeled break once the per-bar ceiling
is reached. Density overruns were a confirmed source of mush in Kosmic Study 02 (Rhythm
track at 13.9 notes/bar).

Ceilings per track per bar:
- Lead 1: ≤6 notes/bar
- Lead 2: ≤3 notes/bar
- Rhythm (Rhodes): ≤10 notes/bar (Bosa Moon broken chord ~10 is the maximum; never exceed)
- Bass: ≤6 notes/bar (ostinato riff mode); ≤2 notes/bar (root sustain/drone modes)
- Pads: ≤1 re-attack per 2 bars (sustain voice only)
- Drums Deep/Dream: ≤5 events/bar; neo soul: ≤12 events/bar; brush: ≤6 events/bar

---

**CHL-SYNC-012 — Instrument collision prevention**

At frame generation time:

- If Lead 2's selected instrument program equals Lead 1's program, re-pick Lead 2.
- CHL-RHY-004 Off-Beat Shimmer requires a specific instrument character (sustaining mid
  register). If the intended program is already assigned to Lead 1 or Lead 2, that rule
  is excluded from Rhythm selection for that song.
- Rhythm (Rhodes, program 4) and Pads must never share the same program number in the
  same song. If Grand Piano (program 0) is selected for Rhythm, Pads must not also be
  Grand Piano — select a different Pads instrument.

---

**CHL-SYNC-013 — Chill-specific: bVII in Ionian/Mixolydian is a named exception**

The "Moby open" bVII chord is coded as an explicit named option in the chord plan, not
derived from a generic borrowed-degree mechanism. When bVII is the active chord in an
Ionian or Mixolydian song:

- The chord root is confirmed as the b7 degree of the major scale
- The Rhythm voicing uses [b7root, 3rd, 5th] of the bVII chord — but each note is then
  checked against the parent key scale (CHL-SYNC-004 snap applies)
- In G Ionian with bVII (F major): Rhythm voicing [F, A, C]. F and C are in G major;
  A natural is in G major. No snap required. This is why bVII works — its chord tones
  are already diatonic to the parent major scale.
- If any voicing tone is not in the parent scale, snap to nearest diatonic PC as usual.

---

**Coherence testing checklist (run after every generator change):**

- Generate 10 songs per mood (40 total); run batch_analyze.py
- Verify consonance rates meet Part 7 targets per track
- Cross-check bass beat-1 note against chord root for every bar
- Verify no single key appears in >3 of 10 songs (lock-in check)
- Verify no single Rhythm rule appears in >6 of 10 songs (weight balance check)
- Plot Lead 1 density curve: must show Breakdown silence and Groove B > Groove A
- Confirm Breakdown bars contain: bass + Pads sus chord only (no other pitched content)
- Audit chord roots in chord plan against mode-permitted list (CHL-SYNC-002)
- Spot-check 3 Rhythm voicings per song for chromatic PCs (CHL-SYNC-004)

---

## Part 16: Quality Fix History

### Round 1 — 2026-04-04 (post first batch run, 10 Chill songs)

**Analyzer:** `tools/chill_analyze.py`. Batch size: 10 songs, all moods.

**Issues found and fixed:**

- **Pads tonal clash (34.6%) and Rhythm tonal clash (38.9%) — FIXED**
  Root cause: voicing arithmetic bug in `ChillPadsGenerator.buildUpperStructure()` and
  `ChillRhythmGenerator.buildVoicing()`. Both used `register + pc - (keyRoot % 12)` to
  place a pitch class as a MIDI note, which is wrong when `pc < keyRoot % 12` — the
  subtraction produces a note with the wrong pitch class entirely.
  Fix: replaced with `target + ((pc - target%12 + 12) % 12)` where `target = register + octaveOffset`.
  This correctly finds the nearest MIDI note at or above `target` that has pitch class `pc`.
  Result: Pads clash 34.6% → 0%, Rhythm clash 38.9% → 0%.

- **Bass tonal clash (11.5%) — FIXED**
  Root cause: approach tone in `syncopatedPattern` and `walkingLine` computed as
  `chordRoot - 1` (a raw chromatic semitone below the chord root), never snapped to scale.
  Fix: `snapToScale(chordRoot - 1, scale: scale)` applied before `clampBass`, so the
  approach lands on the nearest diatonic note (typically the 7th scale degree — musically
  correct leading tone).
  Result: Bass clash 11.5% → 2.1%.

- **Lead 1 too leap-heavy (step ratio 47%) — PARTIALLY FIXED**
  Fix: step probability raised from 60% to 70%; added `lastWasLeap` flag that forces
  85% step probability on the note immediately following a leap.
  Result: step ratio 47% → 53.2% (target ≥55% — still slightly under, acceptable).

- **Lead 2 register inverted (avg -0.5 semitones below Lead 1) — FIXED**
  Root cause: Lead 2 used `register(for: inst2)` raw without constraining it relative
  to Lead 1. When Lead 1 = saxophone (50–70) and Lead 2 = vibraphone (60–80), Lead 2
  was systematically higher.
  Fix: `regHigh2` capped at `lead1Median - 5` in `generateLead2`; `regLow2` floored at
  `max(36, regHigh2 - 12)` to maintain at least a 12-semitone playable range.
  Result: register separation -0.5 → +7.5 semitones avg (target ≥5).

- **Chord window too long (avg 13.8 bars) — FIXED**
  Root cause: `static_groove` produced 1–3 giant chord windows spanning entire sections
  (30+ bars); `modal_drift` also produced 20–40 bar windows. Two_chord_pendulum was
  fine at 4–8 bars but its windows were swamped in the average.
  Fix: `chunkWindows()` helper in `ChillStructureGenerator` splits any chord window
  longer than 8 bars into same-chord sub-windows of ≤8 bars. Breakdown sus4 windows
  are exempt (intentionally static).
  Result: chord window avg 13.8 → 5.7 bars (target 4–8).

- **Pads 7th-chord voicing detection (9.1%) — FIXED (via voicing bug fix)**
  The voicing arithmetic bug above was also producing wrong-pitch-class notes that
  landed outside chord tone clusters. Once the arithmetic was corrected, simultaneous
  multi-note clusters appeared at the expected steps.
  Result: Pads 7th-chord events 9.1% → 20.9% (target ≥10%).

- **Groove B rebuild (4/10 songs flat) — IMPROVED**
  Fix: Groove A silence probability raised from 0.40 to 0.50; Groove B lowered from
  0.25 to 0.20. This widens the density contrast so Groove B is reliably more active.
  Result: rebuild-flat 4/10 → 1/10.

**Other changes in this round:**

- **Brush kit promoted to first default** across all moods:
  Deep/Dream: brushKit 50% / electronic 50% (was pure electronic);
  Free: brushKit 60% / neoSoul 40% (was neoSoul 60%);
  Bright: brushKit 70% / neoSoul 30% (was brushKit 55%).

- **Contrabass removed** from Chill bass instrument picker in TrackRowView.
  Chill bass options: Fretless Bass (35), Acoustic Bass (32), Elec Bass (33) only.

**Remaining minor issues after Round 1 (not yet addressed):**
- Lead 1 step ratio 53.2% vs 55% target — 2 percentage points under, low priority.
- Bass root coverage 71.9% vs 75% target — minor_blues and walking-line bars pull it down.
- `!! CHORD-FAST` in minor_blues songs — the 12-bar tile has 1-bar bVII/IV slots by design.
- Lead 2 sparse in some Groove B sections — call-and-response structure naturally produces gaps.
- `!! CHILL-NO-7THS` per-song in staggered-entry pad songs — batch avg (20.9%) passes.

---

### Round 2 — 2026-04-04 (breakdown quality + effect label + titles)

**Effect label rename:**
- `TrackEffect.space` rawValue renamed from `"Space"` to `"Hall"`. The "Space" label implied
  the Ambient cathedral sound. "Hall" (as in concert hall) is the standard audio term and
  applies correctly to both Ambient (cathedral-class hall) and Chill (chamber/medium hall).
  No functional change — the underlying `AVAudioUnitReverb` node and preset assignments
  are unchanged.

**Breakdown too bare — FIXED:**
The breakdown section was bass drone + ghost kick only. The plan says "bass + sparse Rhodes,"
but Pads was completely silent in bridge for all three pad modes. Two fixes:

- `ChillPadsGenerator.breakdownPad()` — new dedicated function that emits a quiet sus4 upper-
  structure voicing (vel 38–50) renewed every 4 bars, applied on top of all pad modes
  (chordSustain, staggeredEntry, and absent). Previously the breakdown chord was only handled
  inside `chordSustain` and was missing for the other 30% of songs.
- Bass bridge velocity lowered: `velocity: 80` → `65`. The bass whole-note should be subdued
  and supportive in the breakdown, not at the same level as the groove.

New analyzer checks added (`!! BREAKDOWN-*`):
- `BREAKDOWN-EMPTY-PADS` — Pads has zero notes in bridge (must have ≥1 chord per 4 bars)
- `BREAKDOWN-PADS-DENSE` — Pads > 1.5 notes/bar in bridge (should be sparse sustain only)
- `BREAKDOWN-BASS-LOUD` — bass mean velocity > 75 in bridge
- `BREAKDOWN-DRUM-DENSE` — drum events/bar > 2.0 overall in bridge
- `BREAKDOWN-DRUM-EARLY-DENSE` — drum events/bar > 1.5 in bridge bars 1–4 (kick only)
- `BREAKDOWN-RHYTHM-ACTIVE` — Rhythm (Rhodes comping) has any notes in bridge (must be silent)
All now passing after fixes. Batch averages: Pads 0.8/bar, bass vel 65, drums 0.5/bar.

**Location-based titles — ADDED:**
New `locationPhrase()` pool added to `ChillTitleGenerator`, weighted at 25% across all moods.
Combines a mood modifier with a place name: e.g. "Late Night Baie d'Urfé", "Cool Amsterdam",
"Winter Marais", "Early Saint-Laurent", "North Shore Detroit".
- Modifiers: Late Night, After Dark, Cool, Still, Low Light, West End, East Side, North Shore,
  Early, Quiet, Winter, Summer Night
- Places: Montreal-area (Baie d'Urfé, Dorval, Pointe-Claire, Sainte-Anne, Saint-Laurent),
  Paris districts (Saint-Germain, Marais, Belleville, Montmartre, Oberkampf),
  London (Shoreditch, Brixton, Hackney), plus Lisbon, Brooklyn, Detroit, Amsterdam
Other pool weights adjusted downward proportionally to accommodate the 25% location slice.

---

### Round 3 — 2026-04-04 (automated batch, bass quality + lead quality + harmony + drum balance)

**Motivation:** Second automated batch (10 songs) after Round 2 fixes. New bass melodic
quality metrics added to the analyzer first, then a third batch run was used to find and
fix the issues below.

**Bass melodic quality metrics — ADDED to analyzer:**
Three new metrics in `[BASS]` section:
- Same-note ratio: consecutive same-pitch bass intervals (target ≤50%; avg 25.7%)
- Mean interval: semitones between consecutive bass notes (target ≥1.5; avg 3.9)
- Pitch variety per 4-bar window: distinct MIDI pitches in each 4-bar groove slice (target ≥2.5; avg 4.2)
- `[BASS RULES]` section showing which bass patterns (001–006) appeared across the batch.

Conclusion: bass is performing adequately (all batch averages pass). No bass code changes needed.
The ostinato pattern (CHL-BASS-004) appears ~1/10 songs — expected given its narrow condition.

**Analyzer `degree_to_pc` bug — FIXED:**
Chord root degrees like `"b7"` and `"b6"` are used in two-chord pendulum progressions
(e.g. im7 | bVIImaj7 in Dorian). The analyzer's `degree_to_pc()` could not parse these
as integers, so it returned the tonic pitch class, causing all bVII-chord bars to fail the
bass root coverage check (50% root coverage instead of ~100%). Fixed with a direct
semitone-offset table for all common degree labels.

**Pads 4-note voicings — FIXED (CHILL-NO-7THS: 5/10 → 0/10):**
`buildUpperStructure()` in ChillPadsGenerator was producing 3-note upper structures
[3rd, 5th, 7th]. The plan spec calls for 4-note voicings [3rd, 5th, 7th, 9th]. Added the
major 9th (interval 14) to every chord type's rawIntervals. Result: 97.5% of Pads chord
events now have ≥4 simultaneous notes, up from 0% for chord-sustain songs.

**Drum style imbalance — FIXED (8/10 brushKit → 4–5/10):**
BrushKit (CHL-DRUM-003) was appearing in ~55% of songs by design and ~80% by sample
variance. Rebalanced pickBeatStyle():
- Deep: 40% brushKit / 60% electronic (was 50/50; electronic suits darker moods better)
- Dream: 45% brushKit / 55% electronic (was 50/50)
- Free: 50% brushKit / 50% neoSoul (was 60/40)
- Bright: 60% brushKit / 40% neoSoul (was 70/30)
Expected distribution: ~43% drum003 (brushKit), ~39% drum001 (electronic), ~16% drum002 (neoSoul).

**Chord-fast false positive — FIXED in analyzer:**
The minor blues 12-bar pattern has 1–2 bar chord windows in its turnaround chords
(bVII 1 bar + IV 1 bar). The CHORD-FAST threshold was changed from `avg < 3 bars` to
`avg < 2.0 bars` — minor blues songs correctly produce ~2-bar averages and should not flag.

**Lead 1 intro too dense (7/10 → 0/10):**
Three-part fix:
- Hard silence gate: Lead 1 forced silent for the first 4 bars of every intro section
- Increased silenceProb after gate: 0.70 → 0.90 (very sparse; at most one brief phrase)
- Capped intro phrase length at 2 bars (prevents a long flute phrase from filling the intro)

**Lead 1 step ratio — FIXED (52% → 63.9%):**
Root cause: the previous semitone-step approach targeted non-pentatonic pitches, which
`snapToRegister` mapped to the nearest pentatonic note — often 3 semitones away, which
the analyzer counts as a leap. Two attempts were made:
- Attempt 1 (pool-index with pentatonic): backfired — pentatonic adjacent notes are 2–3
  semitones apart, most "pool steps" measured as leaps. Avg dropped to 39.7%.
- Attempt 2 (pool-index with full 7-note scale): success — all adjacent scale tones are
  ≤2 semitones apart. Every ±1 pool-index move is a genuine step. Avg 63.9%.
The full scale is now used for note navigation; pentatonic character is preserved via
the phrase landing-note selection (which still draws from pentatonic-derived strong tones).

**Lead 1 strong landing — IMPROVED (60% → 71.7% avg):**
Landing probability raised from 60% to 75%. Fixed landing lookup to use the in-register
orderedPool directly (avoids cases where the pitchPool filter finds no notes).

**Lead 1 outro too dense — FIXED:**
SilenceProb in outro increased from 0.55 to 0.70. Target: ≤1.5 notes/bar.

**Lead 1 Groove A slightly sparse — FIXED:**
SilenceProb in Groove A decreased from 0.50 to 0.45 to maintain ≥1.0 notes/bar average.

**Lead 2 register separation — FIXED (3 songs failing → 0):**
The old cap (`lead1Median - 5`) used the theoretical (not actual) Lead 1 median, allowing
Lead 2 to overlap when Lead 1 played in the upper half of its range. New cap: `regLow1 - 2`
(2 semitones below the bottom of Lead 1's register). Ensures Lead 2 is always below Lead 1
regardless of where Lead 1 actually plays. Register separation avg improved to 17 semitones.

**Lead 2 density — IMPROVED:**
Gap-fill probability increased from 50% to 65%. Lead 2 Groove A avg improved from 0.7 to 1.1/bar.

**Batch result after all Round 3 fixes:** 0 CRITICAL, 12 flags across 10 songs. All batch
averages green. Step ratio 63.9%, strong landing 71.7%, pads 7th-chord 93.7%.

---

### Round 4 — 2026-04-05

- **Lead outro restraint**: Lead silence probability raised to 85% in outro; phrases capped at 2 bars and 2 notes/bar. Lead fades rather than playing freely through the outro.
- **Lead phrase resolution**: Landing probability on root/3rd/5th raised to 85%; fallback pitch search added when no suitable note exists in the narrow register window.
- **Groove A restraint**: Groove A silence probability raised to 50% (was 45%) to ensure Groove B is reliably the energy peak after the breakdown return.
- **Drum fills wired**: `DrumVariationEngine.apply()` now called after Chill drum generation (same as Motorik). Section-transition fills (tom cascades, snare rolls, etc.) now correctly appear in the MIDI output.


### Round 5 — 2026-04-05

- **Brass/blues lead breathing room**: Trumpet, muted trumpet, and saxophone now occasionally take 4 or 8 bar extended rests in groove sections (~12% probability), giving these leads the jazz "laying out" quality characteristic of the genre.
- **Stop-time breakdown solo capped**: Lead 1 now plays in at most 4 or 6 bars (randomly chosen) of a stop-time breakdown, leaving later odd bars silent. Prevents the solo from running through the entire breakdown without rest.
- **Groove B density floor**: Groove B silence probability reduced to 10% (Groove A stays at 50%) and post-phrase rests capped at 1 bar in Groove B. Groove B is now reliably the most active section.
- **Lead 2 call-and-response improved**: Response probability raised to 80%, post-phrase rest removed. Lead 2 fills gaps between Lead 1 phrases much more consistently.
- **Melody variety**: Boundary ping-pong prevention (now jumps 2–3 steps inward when hitting pool edge) and same-pitch-class guard added to phrase builder. Phrases now consistently use ≥3 distinct pitch classes.
- **NeoSoul drums available in Dream mood**: CHL-DRUM-002 added to Dream at 15% probability (alongside brushKit 35%, electronic 30%, hipHopJazz 20%). Previously only available in Free and Bright moods, causing it to be absent from Deep-heavy batches.
