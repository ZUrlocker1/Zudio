# Ambient Zen — substyle plan
Copyright (c) 2026 Zack Urlocker

*Status: plan, merged 2026-11-09; awaiting two AMB-1 listening tests and Zack's approval to build; coding starts after 2.9 is live on the App Store.*

**Contents**

1. What Ambient Zen is
2. Ground rules
3. AMB-1: what we use, and what cannot be followed
4. Selection, seeds and saved songs
5. Recipes
6. Harmony: journey, cycle and field
7. Bell loops
8. The arc: the slow swing between sparse and full
9. Structure: entry, body and the unwinding ending
10. Rules by track
11. Instruments
12. Effects and the space
13. Evolve mode and track regeneration
14. Plumbing: every place that changes
15. Build order and checks
16. Eno research: harmony and the Evolve question
17. Rulings
18. The drone: the continuous low bed
19. Eno MIDI corpus findings
20. Reference links

---

## 1. What Ambient Zen is

A third Ambient flavour beside base Ambient and Ambient Piano. It is inspired by AMB-1, Charles Vestal's generative firmware for the M-Vave FM-1, which in turn comes from Eno's Music for Airports and Discreet Music.

The sound: four breathing pad voices that swell in and out on their own cycles so the chord forms and dissolves, soft bells on short loops of unequal length that slide past each other, a low gliding root that sometimes leans on the fifth, and in some songs a very quiet polyrhythmic pulse, all in a long hall with a darkening echo. Unlike base Ambient, the harmony moves: in most songs a slow chord journey of about three to eight chords that leaves home, wanders and comes back. Some songs instead repeat one short chord cycle, as The Big Ship does, and a few hold one pitch field and let the chords emerge from overlapping voices, as in Music for Airports 2/1.

What makes it audibly distinct from base Ambient:
- **A continuous low drone** (section 18). A sine root on Bass that glides between chords and never leaves a gap, under a held tonic pedal on Texture. Listening to AMB-1's Afternoon preset, a steady low bed is what makes it sound steady and evolving, and base Ambient has nothing like it. It is the first thing to build and the first thing to judge by ear.
- Chords move through the song (base Ambient holds one to three windows).
- Loops are measured in beats, not bars, so the phasing is heard every few seconds rather than every few minutes.
- Loops change a little on every pass instead of repeating exactly.
- Lydian is available, and it is not used in base Ambient.
- New instruments: vibraphone, electric pianos, choir and voice pads, synth chimes, low tower bells.

## 2. Ground rules

- **Base Ambient and Ambient Piano do not change.** Their rules, weights, instrument picks and effects stay as they are. Only the shares move: a part of the non-piano seeds become Zen songs (section 4). The fingerprint check in section 15 proves nothing else moved.
- **Tracks are ours to assign.** Pad voices may be spread across Pads, Lead 2, Rhythm or Texture if a recipe needs separate instruments. An eighth MIDI track, as Chill Soho added, is a last resort only, because it took a lot of testing there.
- **No rearchitecture.** Zen is a branch inside generateAmbient that returns early, the way Ambient Piano does. All Zen music code lives in new files. Shared files get small guarded branches only.
- **AMB-1's algorithms, numbers and code fragments may be used (Zack, 2026-11-09).** This replaces the earlier "ideas only" ruling. AMB-1 is MPL-2.0, which is file-level copyleft, so any code fragment copied from amb.c goes in one file, Generation/Ambient/AmbientZenAMB1.swift, which carries the MPL-2.0 notice. Numbers and algorithms written fresh in Swift carry no obligation and live in the other Zen files.
- **Existing rules reused as they are.** Zen calls AMB-BASS-001, AMB-TEXT-000 and AMB-DRUM-000 unchanged. Anything that would need a tweak becomes a new Zen-only rule.
- **Determinism.** No Dictionary or Set iteration order feeds an RNG draw. Every Zen draw comes from the per-track RNGs or from a fresh trackSeed index (section 4).
- **iPhone parity.** Any effect default set in TrackRowView is mirrored in AppState.restoreDefaultEffects.

## 3. AMB-1: what we use, and what cannot be followed

**The rule (Zack, 2026-11-09).** Where our rules and the AMB-1 code disagree, the rules follow the code, inside our architecture: finite songs, one rule per track, MIDI events on sampled instruments, an early-return branch, no new engine. "Code" means amb.c as read on 2026-11-09. The clone is at /tmp/claude-502/amb1/repo, and https://github.com/charlesvestal/fm1-amb has it if that folder is gone.

**What the author published.** Only docs/MANUAL.md in the repo (also at charlesvestal.github.io/fm1-amb/manual/), the README and the release notes. Web searches on 2026-11-09 found no blog post, interview or video notes by him, and the firmwares derived from AMB-1 (DUB-1, NACHTFAHRT) have no design notes on it either. The useful lines are:
- "The space is most of what you hear." The echo chain and plate are the largest single element.
- Voices on notes the new chord shares hold to the end of their breath; the others fade out and breathe in again on their new notes.
- The bass is "low, soft and gliding". Glide runs from 20 ms to 1.2 s.
- Pad cycles are "around 11 to 19 seconds"; the bell loops are 13, 17, 23 and 29 beats.
- Sparse means fewer bells, a darker pad, a quieter pulse and more reverb.

It gives no reason for the glide and describes no separate drone voice.

**Time base.** The code works in seconds, Zudio in sixteenth steps. Draw each duration in seconds, then convert: steps = seconds × bpm × 4 / 60 (at 70 bpm, 1 s is about 4.7 steps). Chord changes snap to the next bar line, as in the code.

**What Zen follows from the code**
- Breathing pad voices with unequal cycles and the code's breath shape, each taking its chord note at the start of a breath, with common tones held through chord changes (section 10).
- Chord tones built as stacked diatonic thirds, and the code's weighted chord walk and chord timing (section 6). Finite songs add one thing: the first and last windows are the tonic.
- Bell notes stored as scale steps from the current chord, so the loops re-harmonise when the chord moves, on loops of 13, 17, 23 and 29 beats with the code's per-pass changes (section 7).
- The arc between sparse and full, with the code's curve and the code's list of what it moves (section 8).
- A Euclidean pulse on three cycle lengths with the code's evolve and velocity (section 10).
- A root bass that glides, may move to the fifth halfway through a chord, and sometimes sits a chord out (sections 10 and 18).
- The code's per-track pitch wander, as the Drift effect (section 12).
- The eight pieces' knob settings as the values of our eight recipes (section 5).

**What cannot be followed, and what replaces it**
- FM synthesis, the formant voices and the filter bloom: sampled instruments replace them.
- Per-sample pad swell (a smooth volume curve per voice): replaced by the swell ladder (section 12).
- Per-voice pan, vowel and pitch wander: per-track only (Drift, auto-pan).
- Continuous reverb-send automation, the filter bloom and the pad bus darkening with the arc: pad velocity only.
- The 5.6 s echo tape with two heads: AVAudioUnitDelay tops out at 2 s, so echo times are capped and the two heads are spread across Lead 1 and Lead 2; a shared echo bus is a listen-later option (section 12).
- Micro-timing (the code delays each bell by up to 60 ms): optional, off at first (section 7).
- The kick's pitch follows the chord root: a sampled kick can't.
- Freeze (REC): Zen's final "held breath" (section 9) is the nearest equivalent.

## 4. Selection, seeds and saved songs

**The roll.** generateAmbient (SongGenerator.swift:935) draws two numbers before anything else: pianoRoll, then pianoRuleRoll (line 955). Non-piano songs draw pianoRuleRoll and leave it unused (verified 2026-11-09). Zen reuses it:

- Piano if pianoRoll < 0.35 (unchanged).
- Zen if not piano and pianoRuleRoll < zenShare.
- Otherwise base Ambient.

**Shares (decided 2026-11-09).** One constant, zenShare, set as a share of non-piano songs. The shares are Claude's decision; testing may skew them as long as the edit is recorded, and release goes back to a balanced mix.
- **Testing (Zack, 2026-11-09):** Piano 10, base Ambient 10, Zen 80, so some regular base Ambient still plays during testing. That is pianoRoll < 0.10, and zenShare = 80/90, about 0.889. It is a temporary edit, marked in the code, and set back before release.
- **Release:** Piano stays at 35, so its seeds are untouched. Zen about 30 (zenShare about 0.46) and base Ambient about 35.

This adds no new draw to the shared prefix, so the frame, structure and tracks of every base Ambient and Piano song stay identical. Zen songs consume the normal frame draws and then override what they need, so nothing downstream of them shifts either.

**Seed indices (decided 2026-11-09).** Zen draws come from separate streams, so one layer's draws can't shift another's. SongGenerator already uses trackSeed indices 90 to 95, 97 and 98 (and 94 is Chill drums, a different style, which is fine). The ZenPlan (section 14) uses fresh indices:
- arc 99;
- chords 96 (the journey walk, the cycle's chords and the field's pitches);
- pad breaths 100;
- bass flags 101;
- pulse 102;
- recipe roll 103;
- harmony plan 104.

Drift's modulators draw from index 105 at load, so playback is the same every time. Each bell loop draws from its own track RNG. The recipe and harmony-plan draws no longer come from the Pads RNG.

**ZenPlan is a pure function of the seed and frame.tempo**, never the user's tempo override. A reload from a seed is exact, and regeneration can rebuild the plan from the seed (section 13).

**Saved songs.** A seed that is base Ambient today and falls in the Zen share becomes Zen when reloaded by the new build. This is accepted: no save protection. The forced-rule log line gets forced["Zen"] = recipe name, mirroring forced["Piano"].

## 5. Recipes

Each Zen song draws one of eight recipes (trackSeed index 103). A recipe sets the frame and biases the rule weights. It does not pick rules outright, so each track still rolls one rule. The names are ours, chosen to stay in the airport and waiting-room world. Each recipe takes its values from one of AMB-1's eight pieces (amb.c, the PIECES table, lines 39 to 52): Concourse is Garden, Departure Lounge is Departures, Choir Loop is Voices, Afternoon Light is Afternoon, Late Shuttle is Night Bus, Tidewater is Shoreline, Glasshouse is Glass and Slack Water is Tides.

**What a recipe holds**, fixed for the song:
- mode, and a tempo range (triangular, peak at the middle);
- key: drawn from the base Ambient key weights (the frame draw is kept, so AMB-1's Root column is not used);
- pad colour: Rhodes or Voices (the piece's PT column; section 11);
- layer presence: bass, pulse and bells;
- Swell (sets the pad breath cycle), Motion (0 to 1: scales the arc and Drift), restlessness, chord drift, Glide, Fifth;
- Density (bell target count), bell octave, bass octave;
- Hits (the pulse), Size (echo feedback and reverb character), Bright, echo level and echo time;
- Swing, recorded for later and off in phase 1. It is possible later through the existing beatDelay hook.

"Restlessness" is AMB-1's Evolve divided by 100, renamed so it doesn't collide with Zudio's Evolve mode. "Chord drift" is AMB-1's Drift knob, renamed so it doesn't collide with the Drift pitch-wander effect (section 12) or Kosmic Drift. AMB-1's level columns (Pad, Bells, Bass, Pulse) are not copied, because Zudio's track volumes are set by ear; a level of 0 means the layer is absent. Bright is recorded as a reference for the Pads filter sweep (section 12) and drives nothing else in phase 1.

**Values (decided 2026-11-09).** AMB-1's values are used directly, except where Zudio already decided otherwise: Glasshouse has no pulse, Departure Lounge has no bass, and Choir Loop has no bell loops apart from Lead 1's rare AMB-LEAD-013 Becalmed Bell. Chord seconds are the code's mean for that chord drift (section 6). Echo time is the piece's echo time in beats at the recipe's mid tempo; if that is over 2.0 s (AVAudioUnitDelay's cap) it takes the next shorter beat value, as the code does when its tape is too short. Echo feedback is 0.5 + 0.32 × Size/100 (section 12).

**Concourse** (Garden). Everything, gently: Rhodes-colour pads, bells, bass, a soft pulse.
- Dorian, 68 to 76 bpm, weight 0.16.
- Pad colour Rhodes. Swell 60, Motion 0.50, restlessness 0.35, chord drift 25 (about 39 s).
- Glide 20, Fifth 35, Density 40, bell octave 0, bass octave 0.
- Hits 35 (kick 2, closed hat 2, open hat 1), Brush Kit.
- Size 80 (feedback 76), Bright 40, echo level 45, echo time 2 beats (AMB-1's one bar is 3.3 s at 72 bpm; 2 beats is 1.67 s). Swing 0.

**Departure Lounge** (Departures). Low, slow bells over a quiet Rhodes pad. No bass, no pulse.
- Ionian, 58 to 64 bpm, weight 0.14.
- Pad colour Rhodes. Swell 55, Motion 0.40, restlessness 0.30, chord drift 40 (about 59 s).
- No bass, so Glide (30) and Fifth (25) are unused. Density 35, bell octave -1.
- No pulse.
- Size 85 (feedback 77), Bright 20, echo level 30, echo time 2 beats (AMB-1's one bar is 3.9 s at 61 bpm; 2 beats is 1.97 s).

**Choir Loop** (Voices). Voice pads alone over a low bass. Always a field song (section 6).
- Aeolian, 54 to 60 bpm, weight 0.12.
- Pad colour Voices. Swell 70, Motion 0.55, restlessness 0.30. Chord drift 50, Glide 45 and Fifth 30 are recorded but unused, because a field song has no chord changes.
- Bass octave -1. No bell loops: Lead 1 plays AMB-LEAD-013 Becalmed Bell in 30 percent of songs and is otherwise silent (section 10). Density 30 and bell octave 0 apply to that bell.
- No pulse.
- Size 90 (feedback 79), Bright 67, echo level 20, echo time 1.5 beats (AMB-1's four bars is far over the cap; 2 beats is 2.1 s at 57 bpm, so 1.5 beats, 1.58 s).

**Afternoon Light** (Afternoon). Bright Rhodes, busier bells, a light pulse. The reference recipe for tuning the drone, closest to the AMB-1 preset Zack is listening to (G Lydian, 84 bpm, Rhodes pads, bass at a medium-low level, fifth in 40 percent of chords, chords about every 34 s, echo at a dotted half).
- Lydian, 80 to 88 bpm, weight 0.14.
- Pad colour Rhodes. Swell 50, Motion 0.55, restlessness 0.45, chord drift 20 (about 34 s).
- Glide 15, Fifth 40, Density 55, bell octave 0, bass octave 0.
- Hits 30 (kick 2, closed hat 2, open hat 1), Brush Kit.
- Size 75 (feedback 74), Bright 60, echo level 50, echo time 2 beats (the dotted half is 2.14 s at 84 bpm, over the cap; 2 beats is 1.43 s). Swing 15.

**Late Shuttle** (Night Bus). The pulse forward, metallic bells, a short echo.
- Aeolian, 90 to 98 bpm, weight 0.10.
- Pad colour Rhodes. Swell 40, Motion 0.70, restlessness 0.50, chord drift 15 (about 30 s).
- Glide 10, Fifth 45, Density 45, bell octave 0, bass octave 0.
- Hits 55 (kick 3, closed hat 4, open hat 2), Percussion Kit.
- Size 70 (feedback 72), Bright 35, echo level 55, echo time 2 beats (AMB-1's half note; 1.28 s at 94 bpm). Swing 30.

**Tidewater** (Shoreline). Dark, round bells lost in long echoes. No pulse.
- Major pentatonic, 62 to 66 bpm, weight 0.12.
- Pad colour Rhodes. Swell 80, Motion 0.85, restlessness 0.40, chord drift 40 (about 59 s).
- Glide 40, Fifth 20, Density 30, bell octave 0, bass octave 0.
- No pulse.
- Size 95 (feedback 80), Bright 30, echo level 85, echo time 2 beats (AMB-1's two bars is far over the cap; 2 beats is 1.88 s at 64 bpm).

**Glasshouse** (Glass). Glassy bells an octave up, dense, with the bass an octave up too. No pulse (Zack's ruling; AMB-1's Glass has Hits 25).
- Minor pentatonic, 74 to 78 bpm, weight 0.10.
- Pad colour Rhodes. Swell 45, Motion 0.50, restlessness 0.55, chord drift 25 (about 39 s).
- Glide 10, Fifth 30, Density 60, bell octave +1, bass octave +1 (the Glass piece raises both).
- No pulse.
- Size 80 (feedback 76), Bright 55, echo level 45, echo time 2 beats (the dotted half is 2.37 s at 76 bpm, over the cap; 2 beats is 1.58 s). Swing 10.

**Slack Water** (Tides). Voice pads, the most changeable recipe, and a very light pulse. Closest to AMB-1's Tides, a preset Zack likes (Bb Mixolydian, 70 bpm, Voices pads, restlessness 75, chords about every 26 s, bass fifth in 55 percent, "very light hand percussion or drums"). A field song in 30 percent of songs (section 6).
- Mixolydian, 68 to 72 bpm, weight 0.12.
- Pad colour Voices. Swell 60, Motion 0.95, restlessness 0.75, chord drift 10 (about 26 s).
- Glide 25, Fifth 55, Density 45, bell octave 0, bass octave 0.
- Hits 40 (kick 2, closed hat 3, open hat 1), Brush Kit, at 0.7 of the usual pulse velocity.
- Size 85 (feedback 77), Bright 60, echo level 50, echo time 2 beats (AMB-1's one bar is 3.4 s at 70 bpm; 2 beats is 1.71 s). Swing 10.

The recipes with a pulse are Concourse, Afternoon Light, Late Shuttle and Slack Water, about 52 percent of Zen songs.

## 6. Harmony: journey, cycle and field

The goal is a song that audibly travels: it settles at home, wanders, and comes home for the ending. AMB-1's pure weighted walk never comes home. A finite song needs to, so the first and last windows are the tonic; everything between follows the code.

**Three harmony plans.** Each song draws one (trackSeed index 104), after the recipe:
- **Field**: one pitch field for the whole song (AMB-PADS-014, section 10). Choir Loop always, and 30 percent of Slack Water songs. About 16 percent of Zen songs.
- **Cycle**: one short chord cycle repeated (AMB-PADS-015, below). 25 percent of the remaining songs, about 21 percent of Zen.
- **Journey**: everything else, about 63 percent of Zen.

The field and cycle pad rules are chosen by the harmony plan, not by the Pads weight roll. In journey songs the Pads track rolls its own rule (section 10).

**Chord tones** (the code's)
- Stacked thirds from the chord's degree, taking scale steps at offsets 0, 2, 4, 6, then 1, 3, 5 until there are enough distinct pitch classes. Four tones when the scale has six or more notes (a seventh chord on every degree) and three otherwise. The first tone is the root; the third tone is the fifth.
- Seven-note modes give maj7, min7, dom7 and min7b5 chords. ChordType already has all four (verified 2026-11-09). V in Ionian is a plain dominant seventh, with no sus4.
- Pentatonic modes give open three-note chords (for example C E A in C major pentatonic). They are stored with explicit chordTones and the nearest ChordType for display: maj6, add9 or sus2, which all exist.

**Journey: chord timing** (the code's)
- Each window lasts 20 × 2^(0.039069 × chord drift) × (0.7 + 0.6 × random 0 to 1) seconds, counted from the change, and the change lands on the next bar line. There is no clamp.
- The mean is about 26 s at chord drift 10, 30 s at 15, 34 s at 20, 39 s at 25, 59 s at 40 and 77 s at 50.
- The first window is the tonic and lasts the intro plus one full window. The last window is the tonic and covers the outro.
- With a 180 to 315 s song and chords of about 26 to 78 s, a journey has about 3 to 8 chords.

**Journey: the walk** (the code's)
- Seven-note modes, weights by degree: I 4, ii 2, iii 1, IV 3, V 3, vi 3, vii 0.4.
- Pentatonic modes: the tonic 3, every other degree 1.5.
- Only the current degree is excluded. There is no history, no middle-third boost and no return set.
- The half-diminished chord is allowed. In Lydian it sits on the fourth degree, with weight 3, and AMB-1's Afternoon plays it.
- If the walk lands on the tonic in the window before the last, the two tonic windows join into one.

**Example journeys.** Illustrations of plain code walks, not fixed sequences, at about 4 minutes:
- D Dorian, Concourse (chord drift 25): Dm7, G7, Em7, Am7, Bm7b5, G7, Dm7.
- G Lydian, Afternoon Light (chord drift 20): Gmaj7, Em7, C#m7b5, Dmaj7, A7, Em7, Gmaj7.
- A Aeolian, Late Shuttle (chord drift 15): Am7, Dm7, Fmaj7, Em7, Am7, G7, Cmaj7, Am7.
- Bb Mixolydian, Slack Water (chord drift 10): Bb7, Ebmaj7, Cm7, Bb7, Gm7, Abmaj7, Dm7b5, Bb7.
- C# Ionian, Departure Lounge (chord drift 40): C#maj7, F#maj7, A#m7, G#7, C#maj7.

**Who follows the chord plan.** Everything in Zen does, at every note. The Zen windows go into structure.chordPlan, and the TonalGovernanceMap is built from them in the usual way, so AMB-BASS-001 follows them unchanged. Bell loops and pads resolve their pitches against the window in force at each note's step.

**Colour chord (Zack, 2026-11-09).** In 30 percent of journey songs, once, in the middle third, one window becomes a borrowed chord:
- Ionian: bVImaj7 or bVII major.
- Lydian: bVImaj7.
- Aeolian: IV major.
- Dorian, Mixolydian and the pentatonic modes get none.

In practice that means journey songs from Departure Lounge, Afternoon Light and Late Shuttle. Never in cycle or field songs.

**Colour chord: where it could clash, and what guards it.** Everything else in Zen is diatonic, so the borrowed note is the only chromatic exposure:
- **Bells:** chord tones of the borrowed chord only during the colour window.
- **Pads:** the pitch-class common-tone test (section 10) already cuts any voice whose note is not in the borrowed chord at the change.
- **Texture pedal:** the tonic always survives. It is a chord tone or a whole tone away in every case (checked: in C Ionian, C is in Abmaj7 and a whole tone from Bb and D; in G Lydian, G is in Ebmaj7; in A Aeolian, A is in D major). The clash guard drops the fifth if it sits a semitone from a chord note (G against Ab in C Ionian, D against Eb in G Lydian).
- **The remaining risk** is echo and reverb tails of scale notes a semitone from the borrowed note, for example A and E ringing into Abmaj7 in C. Mitigation: all four bell loops rest for the 2 bars before the colour window, and AMB-LEAD-015 Apollo Echo restates only notes that are chord tones of the window in force. Listen for it at the build stop (section 15).

**Cycle: the Big Ship** (AMB-PADS-015). Taken from The Big Ship, from Another Green World (section 19). The fan file holds one 8-chord cycle, Am F C F Am F C G, 6 beats a chord, unchanged for the whole piece apart from one bass voicing, while new layers come in on top at bars 20 and 28.
- Pick three chords besides the tonic from the walk weights, without repeats: A, B and C. The cycle is A B T B A B T C, where T is the tonic, so the tonic comes round twice per cycle and C is the turnaround. In Ionian the cycle never picks vii, the half-diminished chord, whose root sits a semitone under the tonic pedal. V is a plain dominant seventh.
- Each chord lasts 4 bars, so a cycle is 32 bars, about 101 s at 76 bpm (Zack, 2026-11-09: 2 bars was too fast).
- The body repeats the cycle unchanged. Each pass, with probability 0.3, one slot puts the bass on another chord tone (the Big Ship's one voicing change).
- The intro and outro hold the tonic, as in the journey.
- Layers enter by addition at half-cycle boundaries (every 16 bars): Lead 1 at the first half-cycle after the intro, Lead 2 one half-cycle later (decided 2026-11-09: a 32-bar cycle leaves a 4-minute song under two full cycles, so whole-cycle entries would often never arrive). That replaces the entry bars in section 9 for these songs.
- Bass and Texture follow the cycle exactly as they follow the journey, including the glide.
- Clash check (2026-11-09): every chord is diatonic, and the bass and the pads move together, so there is no severe clash.

**Field** (AMB-PADS-014). No chord changes: the song is one tonic window covering everything, so there is no glide, no fifth move and no bass sit-out. The field and its voices are in section 10.

## 7. Bell loops

**Loop lengths.** Four loops of 13, 17, 23 and 29 beats, one slot per quarter-note beat: Lead 1 = 13, Lead 2 = 17, Rhythm = 23, Texture = 29. They don't have to be whole bars. A 17-beat loop is 68 sixteenth steps, 4¼ bars. All four are prime, so no two line up. At 70 bpm, 17 beats is about 15 s; a 5-minute song hears Lead 1 about twenty times, and the four loops never repeat their combined pattern. Every bell rule uses its track's loop length and base note.

**Why not a "step tiler".** The current AmbientLoopTiler copies one loop, unchanged, across the song in whole bars. Zen needs loops that aren't whole bars, and a loop that changes a little on each pass and follows the chord. So Zen doesn't tile. A new helper, the pass unroller, walks the song one pass at a time:

1. Start with the loop's slots: each is empty or holds a scale step relative to the chord, plus a velocity.
2. For each pass, apply the per-pass changes (below), then write the pass's notes into the song.
3. Resolve each note's pitch against the chord in force at its own step. A loop that straddles a chord change plays its first notes in the old chord and the rest in the new one, as AMB-1 does.
4. Skip any pass the song structure has silenced, such as before the track's entry or after its exit, and the 2 bars before a colour window (section 6).

AmbientLoopTiler is not touched, so base Ambient keeps its current behaviour.

**Register.** Each loop has a base note: 72 for Lead 1, 67 for Lead 2, 79 for Rhythm and 62 for Texture. A note's pitch = the highest pitch at or below the base with the key's root pitch class, plus the scale step above the chord's degree, plus an octave for each full wrap of the scale, plus the recipe's bell octave, folded into MIDI 36 to 103. So Lead 2 sits only 5 semitones below Lead 1, and the Rhythm loop is the highest. Rule-specific register ranges are gone (decided 2026-11-09).

**What a slot holds**
- An offset in scale steps above the current chord's degree. A new offset is a chord tone 72 percent of the time (steps 0, 2, 4 or 6), with a 30 percent chance of a further octave; otherwise a passing step of 1, 3 or 5.
- A velocity drawn once when the note is added. Generic bell velocity: the code's 50 + random 0 to 49 percent, mapped to MIDI as 40 + 0.8 × (percent − 50), so MIDI 40 to 80 (decided 2026-11-09). A rule's own velocity range overrides this.
- During a colour window, every note resolves to a chord tone of the borrowed chord (section 6).

**Target count.** floor(clamp(Density × 0.05 × (1 + 0.8 × arc), 0, 5) + random 0 to 1), with Density the recipe value (30 to 60).

**Per-pass changes**, each time a loop wraps, in this order (r = restlessness):
1. Add notes until the count reaches the target, or remove random notes until it does. This happens in one pass, not one note at a time.
2. The pass is silent with probability 0.15 × r + 0.15 × max(−arc, 0).
3. With probability 0.7 × r, pick one sounding slot at random. Half the time give it a new offset; the other half, move it to a random slot if that slot is empty (otherwise nothing happens).

At r = 0 the loops repeat exactly, apart from chord changes and the target count. Rules keep their own note lengths, velocity ranges and slot behaviour (section 10).

**Octave ring.** After a bell, with probability 0.08 + 0.12 × max(arc, 0), the same note an octave up sounds on the same step at 40 percent velocity. On a sampled vibraphone or celesta it reads as a shimmer, a stand-in for AMB-1's short ring.

**Ring length.** The code's bell rings for about 4.2 s minus 0.06 s per semitone above middle C, between 1.6 and 5 s, times a per-loop factor of 1.0, 1.35, 0.75 and 1.6. In Zudio the instrument's own decay does this; generic note lengths are about one beat.

**Human hand.** The code delays each bell by up to 60 ms. The engine already has a micro-timing hook (beatDelay, used by Chill's Beat Fixup), so this is possible as an option: a deterministic delay of 0 to 60 ms from a hash of the step. Off at first; try it by ear.

**Why the bells never clash (Zack's observation, checked in amb.c 2026-11-09).** AMB-1's bell notes are never chromatic. Each slot stores a scale step above the current chord's degree, and the pitch is looked up in the song's scale, so every bell note is a note of the song's scale, whatever the bass and pads are doing. The bass moves to a new root at once while the pads are still crossing over from the old chord (section 18), so for a few seconds the two disagree. Because everything sits in one scale, that disagreement reads as a moving chord colour and never as a clash. Zen keeps this. The colour chord is the one place the bells need extra care, which is why they use chord tones only there. Expect Zen's tonal-clash analysers (tools/ambient_analyze.py) to flag the seconds after a chord change, because of the pad lag by design. Don't tighten the pads to silence the report.

## 8. The arc: the slow swing between sparse and full

"Arc" is AMB-1's name (decided 2026-11-09). It replaces the earlier "tide", which clashed with the Tidewater recipe and AMB-1's Tides piece.

**The curve** (the code's, drawn from trackSeed index 99)
- A value from -1 (sparse) to +1 (full), stored per bar in the ZenPlan.
- A new target is picked every 50 to 150 s: random -1 to 1, times (0.6 + 0.4 × random), pushed 0.25 further from the middle in its own direction, clamped to -1 to 1.
- The value eases toward the target with a time constant of 35 s.
- The effective arc is that value times the recipe's Motion (0 to 1).
- Forced to at most -0.5 in the intro and the outro. This is a finite-song need; the code has none.

**What the arc moves**, all baked in at generation:
- Bell target count, the chance a bell pass rests, and the octave ring (section 7). It does not scale bell velocity, because the code doesn't.
- Bass sit-outs (section 10).
- Pulse level: factor clamp(1 + 1.3 × arc, 0.3, 1.15), so the pulse fades but never goes out (section 10).
- Pad breath peak velocity, ±10 percent. This approximates the code's pad filter darkening (cutoff 700 × 2^(0.03 × Bright + 0.6 × arc) Hz, about 2.4 kHz at Bright 60) and its Rhodes bloom.
- The Texture pedal's velocity, ±10 percent (section 18).

**Not followed.** The code raises the reverb send when sparse (send × (1 − 0.25 × arc)). Zudio has no reverb-send automation, so this is left out of phase 1; a slow send-level ramp could come later.

## 9. Structure: entry, body and the unwinding ending

**Length.** The same as base Ambient: triangular 180 to 315 s, peak 240 s (the frame draw is kept). Evolve mode already stretches a song by almost half. At this length a journey has about 3 to 8 chords (section 6).

**Sections.** An intro of 8 bars, one body section A, and an outro of 12 bars, using the existing section labels. That keeps Evolve's aSectionBars arithmetic working unchanged.

**Entry: the garden grows in**
- Pads: bar 0. All four voices start within about 3 s, as in the code (section 10). In field songs the voices are staggered over the first 15 to 20 s instead.
- Texture pedal: bar 0, with the pads.
- Lead 1: a random bar from 2 to 4.
- Bass: bar 4, or the first chord change, whichever comes first.
- Lead 2: a random bar from 6 to 8.
- Rhythm: the end of the intro.
- Texture bell: one Texture loop pass after the end of the intro.
- Drums (pulse): at the first chord change after the intro, at bar 16 at the earliest. Field songs have no change, so their pulse enters at bar 16.
- Cycle songs replace the Lead 1 and Lead 2 entries with cycle boundaries (section 6).

**Body.** The harmony plan, the arc and the per-pass changes do the work. Zen does not run base Ambient's dropout zones, hollow guards, Plan H breath or Plan J strip. Its own rests (silent passes, pulse rests, bass sit-outs) replace them.

**The unwinding ending.** Layers leave in roughly the reverse order they came in, during the outro, which sits on the tonic:
- The pulse stops at the start of the outro.
- Rhythm finishes its pass and stops, then the Texture bell.
- Lead 2 stops about 4 bars later.
- Lead 1 plays one last pass and stops about 3 bars from the end.
- The bass drops 4 bars from the end, with its 4 s fade-out.
- The pads end on a "held breath", an idea taken from AMB-1's freeze. At the start of the final 6 bars all four voices take the tonic chord and hold without breathing out to the last bar. The Texture pedal joins the held breath and ends with it. The existing Ambient outro master fade then carries the reverb tail away.
- Field songs drop their voices one by one in the outro instead.

**Trim.** The song is trimmed to its last pad note plus 2 bars, the way Ambient Piano trims, so it never ends on dead air. Listening check: the reverb and echo wash must not be cut short. If it is, lengthen the tail to 4 bars.

## 10. Rules by track

New IDs continue each Ambient track family. Ambient Piano used AMB-PADS-007 to AMB-PADS-010, so the numbers below are free. Each rule is named for an Eno work it descends from, as homage rather than copy.

### Pads

In journey songs the Pads track rolls AMB-PADS-011 0.55, AMB-PADS-012 0.25 and AMB-PADS-013 0.20. AMB-PADS-014 and AMB-PADS-015 are chosen by the harmony plan (section 6), not by this roll.

**Voicing, for every Zen pad rule.** On each chord change, assign the new chord's tones to the voices by the nearest-movement permutation (24 of them for four voices), inside MIDI 48 to 77. The code starts the voices at 50, 57, 64 and 71. Cost = total semitone movement, plus a heavy penalty for two voices on one note, plus a penalty for any pad note a semitone from a Texture pedal note in the same octave, which moves that voice an octave (decided 2026-11-09). The code's own cost function (en_voice_lead) can be read and used now.

**AMB-PADS-011 Airports Breath** (0.55). Four voices, each with its own breath cycle, as in the code.
- **Cycle.** Seconds = (4 + 0.12 × Swell) × the voice factor (1.0, 1.21, 1.43 or 1.67 for voices 1 to 4) × random 0.85 to 1.15, drawn fresh at every breath. With Swell 40 to 80 the base cycle runs from about 9 to 14 s and the voices from about 9 to 27 s.
- **Shape.** Volume rises over the first 40 percent of the cycle, holds from 40 to 55 percent, falls from 55 to 90 percent, then rests for the last 10 percent. A sampled note can only follow its soundfont envelope, so the swell ladder (section 12) sets where each note ends.
- **Start.** All four voices start within about 3 s. Voice 1 starts at once; the others start (1 minus their start phase) of a first cycle later, with start phases 0.9, 0.82 and 0.95 for voices 2 to 4. The cycles then drift apart by their unequal lengths.
- **MIDI form.** One note per breath, per voice, on the pitch the voice's target holds at the breath start. Velocity = 50 + 40 × peak, where the peak is random 0.6 to 1.0, scaled ±10 percent by the arc.
- **Chord change.** For each voice that is sounding (inside the first 90 percent of its cycle): if its pitch class is in the new chord it carries on unchanged to the end of its breath, whatever its length. If not, its note ends at the change, and its next breath starts 1 s later on its new target, with a freshly drawn cycle at 85 percent of the usual length. A voice that is resting or not yet started takes the new target at its next breath start. The test is by pitch class, not by octave.
- Source: Music for Airports 2/1 (voices on unequal loops).

**AMB-PADS-012 Plateaux Bloom** (0.25). Three voices, with a breath cycle of the AMB-PADS-011 cycle × 1.6, otherwise breathing as AMB-PADS-011 does. The top voice takes the chord's ninth instead of a chord tone only when the diatonic ninth is a major ninth above the chord root. So never on iii in Ionian, never on the half-diminished chord, and never on a Phrygian-type degree.
- Source: The Plateaux of Mirror (with Harold Budd).

**AMB-PADS-013 Neroli Hold** (0.20). The sparsest pad. A low root-and-fifth pair held for each whole chord window. It re-breathes 1 s after each chord change, not exactly on it, matching the code's handoff for voices whose note the new chord lacks, so the pads still lag the bass. A single high chord tone breathes in only during the middle of each window, on a 20 to 30 s breath.
- Source: Neroli.

**AMB-PADS-014 Airports 2/1 Field** (the field harmony plan: Choir Loop always, 30 percent of Slack Water). No chord windows. The song has one pitch field: 5 or 6 pitches, the mode's tonic chord plus one or two of its 9th, 11th or 13th.
- **Tracks:** each pitch is one voice on its own loop, 5 or 6 voices in all. Pads holds two or three voices (Concert Choir), and Lead 2 (Synth Voice), Texture (Space Voice or Warm Pad) and Rhythm (one high voice, Warm Pad) hold one each, so each instrument breathes on its own. The Texture rule is not rolled in field songs.
- **Timing:** loop lengths 16 to 32 s, in steps, all different, none a multiple of another. Note length 30 to 50 percent of the loop. Entries staggered over the first 15 to 20 s.
- **Swell:** the per-note boost fade shapes the single-voice tracks only (Lead 2, Rhythm and Texture), rising over half the note and falling over half, as in the recreation. This needs the fade extended to Lead 2, Rhythm and Texture, for Zen songs only. The Pads fade stays off in Zen, so the Pads voices swell through their instrument and the swell ladder.
- **Bass:** AMB-BASS-007 holds the field's root for the whole song.
- **Ending:** voices drop out one by one in the outro.
- Source: Music for Airports 2/1 (section 16).

**AMB-PADS-015 Big Ship Cycle** (the cycle harmony plan). The one Zen pad rule where the pads follow the chord. The pads play held block chords, one per chord, changing with each 4-bar chord of the cycle (section 6), voiced by the shared voicing above. The bass-leads-pads-lag principle (section 18) applies to the breathing rules; this rule is the stated exception, as in its source. Velocity as AMB-PADS-011.
- Source: The Big Ship, from Another Green World.

### Lead 1 (bell loop A, 13 beats, base 72)

All Lead 1 rules run through the pass unroller with the Lead 1 loop.

**AMB-LEAD-011 Airports 1/1 Loop** (0.50). The plain bell loop: the generic target count and velocity, per-pass changes.
- Source: Music for Airports 1/1.

**AMB-LEAD-012 Discreet Fragment** (0.30). The loop holds a 3- or 4-note descending scale fragment in adjacent slots, starting on a chord tone, plus empty space. The per-pass changes can only replace one fragment note or drop the last one, so the fragment's shape survives. Velocity falls along the fragment, 72 to 48.
- Source: Discreet Music (an Eno line fed into delay). The fragment shape is generated, not quoted.

**AMB-LEAD-013 Becalmed Bell** (0.20). One or two notes per loop, held 6 to 10 steps. Octave ring at double the usual probability. In Choir Loop it is Lead 1's only rule, in 30 percent of songs; the other 70 percent leave Lead 1 silent (logged as AMB-LEAD-016 Silent).
- Source: Becalmed, from Another Green World.

In Slack Water field songs Lead 1 rolls as usual and is the only bell loop.

### Lead 2 (bell loop B, 17 beats, base 67)

**AMB-LEAD-014 Airports 1/2 Answer** (0.60). A second loop, velocity 42 to 70. After both leads are generated, ZenCoordinator drops any Lead 2 note on a beat where Lead 1 sounds, so the two loops answer each other rather than collide.
- Source: Music for Airports 1/2.

**AMB-LEAD-015 Apollo Echo** (0.25). Built from Lead 1's generated events in ZenCoordinator, the same way AMB-LEAD-005 is seeded from Lead 1, so it has no loop of its own. On each Lead 1 pass it restates up to two of that pass's pitch classes, a beat and a half to three beats later, an octave lower, at 60 percent velocity. It restates only notes that are chord tones of the window in force at the restatement.
- Source: Apollo: Atmospheres and Soundtracks.

**AMB-LEAD-016 Silent** (0.15). Lead 2 rests for the whole song.

In field songs Lead 2 carries a field voice (AMB-PADS-014) and is not rolled.

### Rhythm (bell loop C, the high glass, 23 beats, base 79)

**AMB-RTHM-007 Lux Glass** (0.65). A 23-beat loop of 1 to 3 short notes (2 to 4 steps), the target count capped at 3, velocity 35 to 60.
- Source: Lux.

**AMB-RTHM-008 Reflection Drops** (0.35). One pitch, the chord's fifth, at two or three slots of the loop. Each slot fires with its own probability (0.4 to 0.8) each pass, so the dripping never quite settles. Velocity 30 to 52.
- Source: Reflection.

In field songs Rhythm carries a field voice and is not rolled.

### Texture (the pedal, or bell loop D, 29 beats, base 62)

Weights: AMB-TEXT-012 0.50, AMB-TEXT-011 0.35, AMB-TEXT-000 0.15. When the recipe has no bass (Departure Lounge): AMB-TEXT-012 0.75, AMB-TEXT-011 0.15, AMB-TEXT-000 0.10. Field songs use Texture for a field voice, so the rule is not rolled for them. The effect settings that depend on the rule (pan, echo wet) are set in the setAmbientMode Zen branch from the rolled rule (section 12).

**AMB-TEXT-012 Pearl Pedal**. The upper half of the drone: the tonic and fifth held as a pedal under every chord. It enters at bar 0 with the pads and ends with the pads' held breath. Full spec in section 18.
- Source: Against the Sky, from The Pearl (with Harold Budd), where two tones sound through every chord of the piece and only a third voice moves (section 19).

**AMB-TEXT-011 On Land Bell**. A 29-beat loop, one or two notes, the root or fifth only, velocity 40 to 60, long rings. In practice it reads like a distant tower bell. It enters one loop pass after the intro and leaves after Rhythm in the outro.
- Source: On Land.

**AMB-TEXT-000 No texture**. Reused unchanged.

Audio textures stay unique to base Ambient. Zen never uses them, whatever its percussion.

### Bass

The Zen bass is the lower half of the drone (section 18).

**Weights (decided 2026-11-09).** AMB-BASS-000 No bass only when the recipe has no bass (Departure Lounge), forced. Otherwise AMB-BASS-007 0.50, AMB-BASS-008 0.31 and AMB-BASS-001 0.19, because random no-bass songs work against the drone. Field songs use AMB-BASS-007 (see AMB-PADS-014 above).

**Register (the code's).** MIDI 36 + the chord root's pitch class + 12 × the recipe's bass octave, so C2 to B2 at bass octave 0. Root moves can leap up to 11 semitones, and the glide softens them.

**AMB-BASS-007 Airports Root**. One root per chord window, velocity 54 to 62. The only Zen bass rule that glides (section 18): one struck note per run, and each chord change is a slow pitch bend on it.
- **Fifth.** At the window's midpoint, with probability Fifth percent (20 to 55 per recipe), it moves to the chord's third tone (the fifth), as 36 + that pitch class + 12 × bass octave, and stays until the next change, gliding there. Only when the chord has at least three tones. The fifth can therefore sit below the root.
- **Sit-out.** At each change, it rests for the window if random 0 to 1 < 0.3 × restlessness + 0.25 × max(−arc, 0). Never the first or the last window.
- Field songs: one note on the field's root for the whole song, with no glide, no fifth move and no sit-out.
- Source: Music for Airports 1/1 (the held bass).

**AMB-BASS-008 Plateaux Octave Root**. The root doubled at the octave, as a two-note pair, held for the first 2 bars of the window. Then the upper note alone is re-struck for the rest of the window, as its source does, overlapping the pair by 1 beat. Its joins between windows use the same 1-beat overlap, and it does not glide. It is fuller than AMB-BASS-007 and reads better on small speakers. The fifth move and the sit-out chances are as in AMB-BASS-007, except that at the midpoint only the re-struck upper note moves to the fifth (the pair is not re-formed), still overlapped by 1 beat (decided 2026-11-09).
- Source: Not Yet Remembered, from The Plateaux of Mirror (with Harold Budd). In the fan file the bass is a root octave pair held about 2 bars, then its upper note re-struck. That low bed sounds about 95 percent of the piece (section 19).

**AMB-BASS-001 Loscil drone**. Reused unchanged; it follows the Zen chord plan through the tonal map and does not glide. Zack's ruling (2026-11-09): keep it for now and drop it later if Zen sounds too much like base Ambient.

**AMB-BASS-000 No bass**. Forced when the recipe has no bass (Departure Lounge). Those songs lean on the Texture pedal for their low bed.

**Listen check.** Choir Loop's bass octave -1 puts the bass at MIDI 24 to 35 (about 32 to 62 Hz). Check that the Sine Wave preset has zones that low and that the result is audible.

### Drums (the pulse)

"Pulse" here means a very quiet drum part: a soft kick, a closed hi-hat and an open hi-hat, each repeating its own short pattern so they drift against each other. It is felt more than heard, well below base Ambient's hand percussion. Many Zen songs have none.

**AMB-DRUM-005 Garden Pulse** (only when the recipe has a pulse). Three Euclidean patterns, each on its own cycle, as in the code:
- kick (GM 36), 16 steps; closed hat (42), 12 steps; open hat (46), 7 steps.
- Hits per pattern = floor((Hits × max + 50) / 100), with maxima 5, 7 and 3. At Hits 35 that is kick 2, closed hat 2 and open hat 1.
- Start rotations 0, 2 and 3.
- **Each bar:** if a rest is running, count it down; otherwise, with probability 0.015 × restlessness, start a rest of 2 to 4 bars. Then, with probability 0.25 × restlessness, pick one of the three patterns at random. If it has no home hits, do nothing. Half the time rotate it by one step either way; otherwise add or remove one hit, staying within one of its home count, at least 1 and at most its length. Rests are rare.
- **Velocity.** Level = (0.95 on step 0, otherwise 0.6) + 0.25 × random 0 to 1, times the arc factor clamp(1 + 1.3 × arc, 0.3, 1.15). MIDI velocity = round(level × 50); Slack Water multiplies it by 0.7.
- **Swing:** off in phase 1 (section 5).

**AMB-DRUM-000 No percussion.** Reused, for recipes without a pulse.

## 11. Instruments

Pools are shared by all Ambient substyles. New entries are appended to the end of each Ambient track pool, so existing indices don't move. Each addition touches all four places: poolNames, poolPrograms, instrumentPickPool and instrumentPickPoolStatic. That includes the field-song entries below.

**Seed safety.** instrumentPickPoolStatic for Ambient currently returns every index in the pool. After the additions it must return the original indices for base Ambient, so existing seeds pick exactly what they pick today, and the Zen pick list for Zen songs. Ambient Piano keeps its Stereo Piano pin. The picker still shows the whole pool for every Ambient song.

**Zen pick lists** (★ = new to that Ambient track pool; all are in Zudio.sf2)
- **Lead 1:** Vibraphone 11 ★, Tine Electric Piano 4 ★, Echo Drops 102 ★, Synth Mallet 1098 ★, Harp 46. Tine Electric Piano stays here as a bell: it decays, which suits a bell and rules it out as a pad.
- **Lead 2:** Celesta 8 ★, Marimba 12 ★, Kalimba 108 ★, Synth Chime 11098 ★, Harp 46. Field songs only: Synth Voice 54 ★.
- **Pads, Voices colour:** Concert Choir 52 ★, Synth Voice 54 ★, Space Voice 91 ★.
- **Pads, Rhodes colour** (soundfont check 2026-11-09, by reading the Zudio.sf2 zones):
  - FM Electric Piano 5 ★: a DX-style FM electric piano, the closest to AMB-1's FM "Rhodes pad"; every zone looped, holds at full level.
  - Fantasia 88 ★: a bell-attack pad; every zone looped, full level.
  - Warm Pad 89 ★: attack 0.8 s, holds within 1.6 dB.
  - Halo Pad 94: holds within 0.7 dB.
  - Rejected on the same check, because their sustain decays to silence: Tine Electric Piano 4 (falls to silence over about 30 s), Fantasia 2 (bank 12, program 88), Harpsi Pad (bank 11, program 88), Mystery Pad (bank 11, program 96) and Metal Pad 93.
  - All four sustain on paper. A looped tail can still sound static, and Zack's ear decides.

  The recipe's pad colour picks the group (section 5), then one instrument is drawn from it.
- **Rhythm:** Glockenspiel 9, Celesta 8, Tinker Bell 112, Synth Chime 11098 ★, Tinkling Bells 11008 ★. Field songs only: Warm Pad 89 ★.
- **Texture, pedal (AMB-TEXT-012)**, seven to audition, all pass the sustain check: Warm Pad 89 ★, Fantasia 88 ★, Tonewheel Organ 16 ★, Sine Wave 8080 ★, Choir Aahs 52, Bowed Glass 92, Strings 49. The last three are already in the Ambient Texture pool.
- **Texture, bell (AMB-TEXT-011):** Bell Tower 11014 ★, Carillon 9014 ★, Vibraphone 11 ★, Church Bells 8014 ★ (already in the Rhythm pool, new to Texture).
- **Texture, field songs only:** Space Voice 91 ★ or Warm Pad 89 ★.

  The Texture pick list depends on the rule rolled: the pedal draws from the pedal list, the bell from the bell list, and field songs from the field list.
- **Bass**, six to audition: Sine Wave 8080 ★, Fretless 35 ★, Synth Bass 101 1038 ★, Tonewheel Organ 16 ★, Voice Oohs 54 and Cello 42 (the last two already in the Ambient Bass pool). All pass the sustain check except Cello, which is in on Zack's say-so. Equal weights. Sine Wave is AMB-1's bass timbre (a sine with a sub-octave and a little second harmonic), but Zack is sceptical that a bare looped sine holds interest, and its sample is a single cycle, which is as static as a sound gets. It stays in for the audition and relies on Drift and tremolo. One slot is free under the seven-instrument cap: fill it after checking more synth basses for sustain (Pulse Bass 11039, Mean Saw Bass 12038, Synth Bass 1 and 2) if the six don't satisfy.
- **Drums:** Brush Kit 40 (Concourse, Afternoon Light, Slack Water) and Percussion Kit 0 (Late Shuttle).

**Long-sustain rule (Zack, 2026-11-09).** Any instrument used for Bass, for a drone (the Texture pedal) or for a pad must sustain for a long time without dying away. If a candidate doesn't, it stays out of the Zen audition lists. Checked against Zudio.sf2 on 2026-11-09 by reading each preset's zones (loop mode, sustain level, decay): the bass and pedal candidates loop in every zone, hold at or within about 2 dB of full level, and decay over 1 s or more. That check is a floor, not a verdict: a looped sample can still sound static or thin, which is why Drift (section 12) is part of the design and why Zack auditions by ear.

Failed the check, but **kept in for the audition at Zack's request** (2026-11-09, "Cello has decent sustain"): **Cello 42**. Only 39 of its 129 zones loop, and the other 90, including the whole low register from key 21 to 52, are 0.2 s one-shot samples, so on paper a held cello note dies almost at once. Zack's ear decides. If a held low Cello note does die away on the bass, drop it from the Zen list. It is already in base Ambient's Bass pool, which doesn't change. With Cello the bass cannot glide (section 18).

Not available in the soundfont: Tubular Bells, Music Box and Violin. Bell Tower and Carillon stand in for tubular bells.

**Gain trims.** Each new entry probably needs a trim in PlaybackEngine.setProgram after listening (FM Electric Piano, Tine Electric Piano and Synth Voice especially). These are set by ear during tuning.

## 12. Effects and the space

All of these go in a Zen branch of PlaybackEngine.setAmbientMode, keyed on a cached isAmbientZen, plus the chip defaults in TrackRowView.applyDefaultEffects and AppState.restoreDefaultEffects. The author's own line is "the space is most of what you hear", so the reverb, echo and Drift are built with the drone in build step 2 (section 15).

**The space in the code.** Pads send 0.6 and bells 0.85 into three stages: a short stereo Echoplex (160 ms, feedback 0.55, each repeat darker), a tape loop of up to 5.6 s with two heads (the second at 0.75 of the first; with Motion it moves between 0.667, 0.625, 0.5 and 0.375) with feedback 0.5 + 0.32 × Size/100 and each pass low-passed and high-passed, and a Dattorro plate with decay 0.6 + 0.375 × Size/100. The echo outputs also feed the plate. The second head slides to a new place every 20 to 60 s with probability Motion, bending the repeats by at most about 14 cents.

**The gap.** AVAudioUnitDelay tops out at 2 s, so the tape loop shortens to at most 2 s, and per-track delays can't share one tape or one pair of heads. With feedback near 0.75 the wash still lasts well over 10 s, but the two-head pattern and the longer echo times (the dotted half in Afternoon is 2.14 s at 84 bpm) don't survive.

**Reverb**
- The large bus gets the .largeHall2 preset in Zen (base Ambient uses .largeRoom there, for Texture only). Pads, Lead 1, Lead 2, Rhythm and Texture send to the large bus. Bass and Drums stay on the small .mediumHall bus.
- Sends: Pads 75, Lead 1 68, Lead 2 68, Rhythm 70, Texture 55, Bass 10, Drums 35. The bass is kept almost dry and centred, as in AMB-1 (bass reverb send 0.08 against the pads' 0.6). A dry fundamental is what makes the drone feel solid rather than washed out. The Texture pedal sits between the bass and the pads.
- Listen later: .cathedral against .largeHall2 on the large bus, for a longer tail.
- Known limit: M4A export ignores reverb presets and renders a default room. This is existing behaviour, and it applies to every style.

**Echo, the "two heads"**
- AMB-1's tape loop has two heads, the second at three quarters of the first. Zen spreads that across two tracks: Lead 1's echo time is the recipe's echo time (section 5), and Lead 2's is 0.75 of it.
- Rhythm uses 1.5 beats; Texture 2 beats; Pads a light 2-beat echo.
- Every time is computed at the song's own tempo and capped at 2.0 s, AVAudioUnitDelay's maximum.
- Feedback = 0.5 + 0.32 × Size/100, as the AVAudioUnitDelay feedback percent, on every track with echo: 72 to 80 percent across the recipes. Each repeat is only about 2 dB quieter, and the wash lasts about half a minute. That wash is probably part of the drone.
- Low-pass cutoff in the feedback loop: 2600 Hz on the bells and 1800 Hz on the Pads, so each repeat comes back darker. That is the darkening echo, with no new code.
- Wet at echo level 50: Lead 1 45, Lead 2 50, Rhythm 48, Texture bell 30, Texture pedal 10, Pads 15, Bass 0, Drums 10. Each recipe's wets scale in proportion to its echo level, capped at 100, so Tidewater (85) is the wettest and Choir Loop (20) the driest.
- Listen later: a shared Zen echo bus, if the space is thinner than AMB-1's. One AVAudioUnitDelay pair on a bus (head 1 at the echo time up to 2 s, head 2 at 0.75 of it, feedback 70 to 75, low-pass 2.6 kHz per pass), with the pads and bells sending into it and its output into reverbBusLarge, the way the reverb buses already work. Not verified.
- Known limit, existing behaviour: echo time is computed once when the song starts.

**Breath and swell on Pads**
- The Ambient per-note boost fade is off for Zen Pads. It is one ramp per track, and it starts from the current volume, so with four overlapping breaths every note-off of one voice would dip all of them. The breath comes from the note timing (section 10), the instrument's own attack and release, the swell ladder below, and the pad tremolo chip, slowed for Zen to 0.06 Hz (about a 17 s cycle) at depth 0.30 and on by default. That is a new rate value inside the existing tremolo path.
- **The swell ladder.** The code's voices have no attack or release in the usual sense; their volume follows the breath shape. A sampled note can only follow its soundfont envelope, so Zen climbs a ladder:
  1. **Ladder B, existing presets (built first).** Note-off at 90 percent of the cycle. The attack is the instrument's own (0.8 s for Warm Pad and Strings), so each breath is audible as a note rather than a swell.
  2. **Ladder A, swell presets (tried second).** Cloned copies of Warm Pad, Concert Choir and Strings in a new bank, with an attack of about 5 s (SF2 generator 34 = 3000 timecents) and a release of about 4.5 s (generator 38 = 2600). Note-off at 55 percent of the cycle, so the release supplies the fall and the sound ends near 90 percent. Clones of FM Electric Piano and Fantasia are an option. A small tool beside tools/sf2_copy_presets.py, which appends presets and keeps every existing byte, clones a preset and overrides those two generators. New presets are additive and in a new bank, so no existing program moves. The costs to check by ear: notes arrive late, which suits a chord that forms slowly, and a 4.5 s release must leave no tail after Stop or a seek.
  3. **Ladder C, separate tracks.** If both leave the bed choppy, put the swelling voices on separate tracks with the per-note boost fade.

**Fades on single-voice tracks.** The per-note boost fade is used only on single-voice tracks, never on Pads in Zen:
- Bass and the Texture pedal use it only at the edges of the drone (section 18): a 2.5 s fade-in on a note that follows silence, and a 4 s fade-out on a note followed by silence. Notes that join another note play at full level with no ramp, because the fade is one ramp per track and would dip the overlap.
- Field songs use it on Lead 2, Rhythm and Texture to swell each field voice (section 10).
- Today the fade covers only Pads and Bass, so Texture, Lead 2 and Rhythm are added for Zen songs only. Base Ambient keeps its 0.5 s fades unchanged.

**Drift (new effect, Zack's idea 2026-11-09).** A very slow, shallow pitch wander per track, so held notes slowly move out of tune with each other the way AMB-1's pads do. The code wobbles each pad voice on a random modulator, with no chorus, because a modulated delay on pure tones "reads as pulsing". It does the job tremolo does for the bass in Chill, keeping a held note from going monotonous, but in pitch rather than volume.
- **Rule (the code's).** Each track has one slow modulator. Every 7 to 40 s (random) it picks a new target from -1 to 1 and eases toward it exponentially, reaching it about halfway through the interval. Pitch offset = 8 cents × Motion × the modulator, so about ±3 to ±8 cents across the recipes. The pitch wanders in steps rather than sine waves. Intervals and targets draw from trackSeed index 105, so a seed plays back identically.
- **How.** It rides the existing vibrato path (PlaybackEngine's 60 fps tick sends MIDI pitch bend).
- **Why per track.** The code drifts each pad voice; Zudio's pitch bend is per MIDI channel, so every note on one track drifts together. The out-of-tune shimmer comes from different tracks drifting differently. Bass and the Texture pedal drift against the pads and against each other.
- **Defaults on (decided 2026-11-09):** Pads, Bass, the Texture pedal, and Lead 2 when it carries a field voice. Off for bells and drums, where it would sound like a detuned instrument.
- **Chip.** A new Drift chip in Types.swift beside Vibrato, switchable per track. Vibrato stays at 5.5 Hz and ±12 cents and is unchanged.
- **Bend sharing.** Glide (section 18), Drift and Vibrato can all move one channel's bend. If more than one is on, the engine sums them in one place (semitones from glide plus cents from Drift and Vibrato) and sends one value.
- **Where it has to be touched.** EffectType in Types.swift; the 60 fps tick and a startDrift/stopDrift pair in PlaybackEngine; the Zen chip defaults in TrackRowView.applyDefaultEffects and AppState.restoreDefaultEffects (iPhone parity); and the offline export snapshot, which already carries vibratoHz and depth through a time-pitch node at OfflineExport.swift:510. Check by ear that a rate this slow survives the export.
- **Risk.** Too wide or too fast reads as a seasick detune. If it does, lower the 8-cent scale by ear. Base Ambient and Piano never turn it on, so they are untouched.
- **Also in the code, not followed:** vowel and pan wander on the pads, and a 0.3 percent wow on the echo time.

**Tremolo.** Pads 0.06 Hz at depth 0.30 (above). Bass 0.05 Hz at depth 0.12, a tweak inside the existing path. Drift moves pitch and tremolo moves volume; both stay.

**Filter sweep.** On for Pads in Zen, over about 1000 to 3000 Hz with a period of about 45 s (decided 2026-11-09). This keeps AMB-1's dark pad bed, whose pad bus sits near 2.4 kHz at Bright 60. Base Ambient's 1500 to 7000 Hz range is unchanged.

**Auto-pan.** On for Rhythm in Zen at one sweep per 8 bars, centred at +0.6 with depth 0.35 (a range of 0.25 to 0.95). Its glass bells drift across the field, a stand-in for AMB-1's wandering echo heads.

**Static pans** (the code's spread): Lead 1 -0.6, Lead 2 +0.35, Rhythm +0.6 (the centre of its auto-pan, which overrides the static value while on), Texture bell -0.25, Texture pedal 0, Pads 0, Bass 0, Drums 0.

**Texture depends on its rule.** The pedal gets pan 0 and echo wet 10; the bell gets pan -0.25 and echo wet 30. The setAmbientMode Zen branch sets these from the rolled rule.

**Chip defaults**
- Pads: space, tremolo, sweep, drift.
- Lead 1: delay, space.
- Lead 2: delay, space; drift too when it carries a field voice.
- Rhythm: delay, space, pan.
- Texture: delay, space; drift too for the pedal.
- Bass: reverb, tremolo, drift.
- Drums: reverb.

**Left out.** Automatic global filter sweeps (too dramatic for this style), reverb-send automation, echo-cutoff automation over time, and swing (phase 1).

## 13. Evolve mode and track regeneration

**Evolve.** Without a Zen branch, Evolve would fall into the generic Ambient path and bring in base Ambient lead rules and instruments. Zen gets its own pass builder, buildAmbientZenPass, alongside the Piano special case in preGeneratePassContent.

- **Pass 1: new bells.** New Lead 1 and Lead 2 rules, drawn from the Zen rules with the current ones weighted down. New instruments from the Zen pick lists, excluding the current ones. The mode shifts by one note (section 16). Then, by harmony plan:
  - journey songs get a short chord walk of their own (32 to 40 bars) in the shifted mode, starting and ending on the tonic;
  - cycle songs build a new cycle in the shifted mode;
  - field songs keep the field and shift one field note.
  Log: "Evolve: new bells", the one-note shift, and the new rules.
- **Pass 2: new pads and glass.** New Pads and Rhythm rules and instruments. Field and cycle songs keep their harmony-plan pad rule, and only the instruments change. Pad colour flips (Rhodes to Voices or the reverse) in 50 percent of passes, which is the most audible change Zen can make. The mode returns home. Bass and Drums are filled only if they were silent in the body, as the generic path does.
- **Instrument swaps** use evolvePickIndex restricted to the Zen pick list for each track.
- **Kept across passes:** the key, mode, recipe, loop lengths, Motion and the drone (the bass rule and the Texture pedal), so Evolve feels like the same garden moving on over the same ground. In pass 1's one-note mode shift, the pedal keeps the tonic and its clash guard drops the fifth if the shifted note sits a semitone from it.

**Per-track regeneration** (regenerateTrack). The ZenPlan is a pure function of the seed and frame.tempo (section 4), so a Zen branch rebuilds it from the seed and calls the Zen generator for that one track. The other tracks are unchanged. Regenerating Lead 1 re-derives an AMB-LEAD-015 Lead 2 only if Lead 2 is regenerated too. The Lead 1 events it reads are the current ones.

## 14. Plumbing: every place that changes

**New files** (each under about 600 lines)
- `Generation/Ambient/AmbientZenRecipes.swift`: the eight recipes and the recipe roll.
- `Generation/Ambient/AmbientZenPlan.swift`: the ZenPlan (below).
- `Generation/Ambient/AmbientZenHarmony.swift`: the chord walk, the cycle, the field, chord tones and voicing.
- `Generation/Ambient/AmbientZenLoops.swift`: the pass unroller, per-pass changes, and the Lead, Rhythm and Texture rules.
- `Generation/Ambient/AmbientZenTracks.swift`: Pads, Bass, the pulse, structure, entry and exit, and ZenCoordinator.
- `Generation/Ambient/AmbientZenAMB1.swift`: any code fragment copied from amb.c, with the MPL-2.0 notice (section 2). Only if fragments are copied.
- `Playback/ZenBassGlide.swift`: the bass glide's playback transform (section 18).

**The coordination layer and generation order.** The code's layers all read one shared state: the current chord, the arc, restlessness. A Zudio song is generated track by track, so Zen builds that state first, once, and every track reads it. This is the same pattern as TonalGovernanceBuilder.
1. **ZenPlan, built first** from the frame and the recipe. One value type holding: the recipe; the harmony plan; the chord windows (degree, tone pitch classes, root, fifth, start step, end step), including any colour window and the bell rest before it; the arc per bar; the bass flags per window (rest, fifth move at the midpoint); the pad voices' breath schedules (start step, cycle steps, peak, per breath); the pulse's rest bars; and the bass runs. A pure function of the seed and frame.tempo, drawing from the indices in section 4.
2. **Track generation** reads the plan: Pads and Bass first, then the four bell loops (the pass unroller walks the windows from the plan), then the pulse.
3. **ZenCoordinator.finalize, after all tracks, before trimming.** It does the work that needs finished events from several tracks:
   - AMB-LEAD-015 Apollo Echo reads Lead 1's events and keeps only chord tones of the window in force.
   - AMB-LEAD-014 drops Lead 2 notes on beats where Lead 1 sounds.
   - The Texture pedal's clash guard reads the plan's windows to drop the fifth for chords with a note a semitone from it.
   - It orders the outro's unwinding (section 9) across the tracks and trims the song to its last pad note plus 2 bars.
   - It marks the bass runs for the playback transform (section 18).
4. **No harmonic filter.** Zen must not run HarmonicFilter, ArrangementFilter or DensitySimplifier, because they would cut the overlap between the bass leading and the pads lagging. Base Ambient's end runs HarmonicFilter (SongGenerator.swift:1402), so the Zen branch returns before it, as Piano does (verified 2026-11-09).
5. **Not a post-generation quantiser.** Nothing snaps the breathing pads to chord changes. The lag is the point.

**Shared files, small guarded branches**
- **SongGenerator.generateAmbient:** the Zen check after the piano check, then an early return into generateAmbientZen. Also the forced["Zen"] entry and the trim.
- **SongGenerator.buildAmbientLog:** a Zen style line ("Ambient Zen – N bpm"), a recipe line, one line per chord change, and rule descriptions for the new IDs.
- **SongGenerator.regenerateTrack:** the Zen branch (section 13).
- **SongState:** isAmbientZen: Bool and ambientZenRecipe: String, passed explicitly in the initialiser and in every withXxx() copy method (seven sites). displayStyleName gets "Ambient Zen".
- **AppState:**
  - persistence (substyleName "Ambient Zen");
  - the Evolve branches at the five Evolve sites that test isAmbientPiano;
  - instrumentPickPoolStatic (section 11);
  - restoreDefaultEffects (iPhone chips).
- **PlaybackEngine:**
  - cachedIsAmbientZen;
  - the setAmbientMode Zen branch, including the Texture settings from the rolled rule;
  - turning off the per-note Pads fade in Zen, and the edge fades on Bass and Texture, and the field fades on Lead 2 and Rhythm;
  - the Zen tremolo rates, the Zen pad sweep, and gain trims;
  - Drift, the RPN send at load, the glide ramp, and the one place that sums glide, Drift and Vibrato into a channel's bend.
- **TrackRowView:** applyDefaultEffects Zen defaults, and the Drift chip. No picker changes beyond the new pool entries.
- **Types.swift (EffectType):** the Drift chip (section 12).
- **Pools:** the four instrument places, per section 11.
- **tools:** a sibling of sf2_copy_presets.py for the swell presets, only if Ladder A is used (section 12).

**Texture as MIDI: the separation already exists** (checked in code 2026-11-09). An Ambient song's Texture is audio only when SongState.ambientAudioTexture is non-nil. Every audio path keys on that one field:
- AppState skips the MIDI program load for Texture only when it is set (AppState.swift:1068).
- The Texture picker lists the audio files only when it is set (TrackRowView.swift:73).
- The waveform lane replaces the MIDI lane only when it is set (TrackRowView.swift:211).
- The Texture effect chips switch to the audio set only when it is set (TrackRowView.swift:432).
- The audioTexture.start calls in AppState run only with a non-nil file.

Base Ambient's MIDI texture rules (AMB-TEXT-001 to AMB-TEXT-003) already run this way. So Zen needs no Soho-style pool flag: it keeps ambientAudioTexture nil and Texture behaves as an ordinary MIDI track. Chill Soho needed its isChillSoho pool switch because Chill's Texture has no MIDI pool at all; Ambient's has one, and the Zen entries are appended to it. Three Zen paths must never set the field:
- the Zen generator;
- buildAmbientZenPass in Evolve, because the generic Ambient pass can roll an audio texture;
- the Zen branch of regenerateTrack for Texture, because AMB-TEXT-005 to AMB-TEXT-010 are audio.

Moving from a base Ambient song with an audio texture to a Zen song goes through the normal song load, which stops the audio player when the new state's file is nil (AppState.swift:1786). Confirm that by ear on Mac and iPhone in step 4 of the build.

**Not touched:** AmbientLoopTiler, every base Ambient rule, every Ambient Piano function, the dropout, hollow-guard and Plan G/H/J code, the frame generator, and ChillBassSlides.

**A choice worth noting.** isAmbientPiano is a Bool tested at 34 sites (counted 2026-11-09). Turning it into an enum would be tidier, but it is a refactor of working Piano code. This plan adds a second Bool and leaves Piano alone.

## 15. Build order and checks

1. **Baseline.** Fingerprint a sample of Ambient seeds (base and Piano) with SWIFT_DETERMINISTIC_HASHING=1, before any change.
2. **Plumbing, harmony, the drone and the space.** The flag, roll, persistence, log, recipes, ZenPlan, the three harmony plans, structure, Pads (Ladder B first), Bass (AMB-BASS-007 and AMB-BASS-008, with the glide and edge fades), the Texture pedal (AMB-TEXT-012), and the setAmbientMode Zen branch's reverb and echo with Drift on Pads, Bass and Texture. The space is built here because it is most of what you hear, and judging the drone dry would mislead.
   - Engine checks: that the sampler honours RPN 0; that a held Sine Wave note sounds for minutes without clicking or fading; how a run restarts after a seek; that Stop leaves no release tail.
   - **Listening stop for Zack**, with no bells yet: Afternoon Light against AMB-1's Afternoon preset. Audition the bass and pedal instruments. Does the drone feel continuous? Does the journey travel and come home? Does the bass lead and the pads lag? Does the Big Ship cycle sit well at 4 bars a chord? Is Choir Loop's low bass audible? Is the reverb and echo wash cut short by the trim? Then try Ladder A. If the drone doesn't work, rethink the rest of the plan before building more.
3. **Bell loops.** The pass unroller, the arc, then the Lead 1, Lead 2, Rhythm and Texture bell rules. Listen for audible phasing, for loops that change without wandering, and for echo tails clashing into a colour window.
4. **Pulse and the rest of the effects.** AMB-DRUM-005, the remaining effects (tremolo, sweep, auto-pan, pans), chip defaults on Mac and iPhone, the pools and pick lists, including the field-song entries.
5. **Evolve and regeneration.**
6. **Fingerprint check.** Every base Ambient and Piano seed outside the Zen share must match the baseline exactly. Run it at release shares, not the 80 percent testing share.
7. **Device.** iPhone and iPad listen, mainly the Pads tremolo, the longer fades and the glide on iOS, and the drone on the iPhone speaker.

Tests: build plus the affected suite only.

## 16. Eno research: harmony and the Evolve question

**Sources.** Web research on 2026-11-09. No published harmonic analysis of Eno's ambient work turned up. These findings come from one detailed code recreation of Music for Airports 2/1, informal blog analysis, and general knowledge of the records. The fan MIDI analysis is in section 19.

**Music for Airports 2/1, from the ChucK recreation** (Andrew Zhu Aday, Princeton, 2024; https://chuck.cs.princeton.edu/chugl/examples/sequencers/music-for-airports.ck)
- Seven voices, each one pitch: C4, Eb4, F4, F3, Ab4, Ab3, Db4. That is an F minor field (F Ab C Db Eb) with no chord changes at all.
- Each note lasts 7 to 9.4 s and loops every 16.2 to 31.8 s, so a voice sounds for 30 to 50 percent of its loop. The envelope rises for half the note and falls for half.
- Voices enter one by one over the first 15 s.
- The "chords" are whichever notes happen to overlap: F Ab C is F minor, Db F Ab is Db major, Ab C Eb is Ab major, Db F Ab C is Dbmaj7. The harmony moves without anyone moving it.

**Music for Airports 1/1** (blog analysis, one source). Mostly D major over held D bass notes. The last Rhodes phrase adds a C natural, which tips it into D Mixolydian. The shift is one note, late, and quiet.

**The wider pattern** (general knowledge, not verified against scores)
- Discreet Music, Thursday Afternoon, Neroli and Becalmed sit in one modal field for their whole length. They have no key changes.
- The Apollo pieces (An Ending (Ascent), Deep Blue Day) are the exception. They use slow, conventional chord progressions.
- So in Eno's ambient work, harmony is either static and emergent (overlapping loops in one pitch field) or a slow, plain progression. Key changes are absent, and mode changes are at most one note.

**What this means for Zen**
- **The chord journey stays** (section 6). It is the Apollo approach, and it gives a finite song a shape.
- **A pad rule for the static approach:** AMB-PADS-014 Airports 2/1 Field (section 10). It gives Zen both of Eno's harmonic modes.
- **Evolve answer.** Not a key change or the relative mode. Instead, a one-note shift in the 1/1 manner (section 13):
  - Evolve 1 changes one scale note: Ionian to Mixolydian (flat 7), Ionian to Lydian (sharp 4), Mixolydian to Ionian, Dorian to Aeolian (flat 6), Aeolian to Dorian (raised 6), Lydian to Ionian. Pentatonic songs add the missing note instead, turning major pentatonic into Ionian.
  - Evolve 2 returns to the home mode.
  - Log: "Evolve: one note shifts, D Ionian to D Mixolydian".
  - It is subtle, and it is a move Eno actually made.

## 17. Rulings

The tiebreaker is Zack's: Zen should sound more different from base Ambient, not more similar.

**Zack's rulings**
- **The name is "Ambient Zen"**, final (Zack, 2026-11-09).
- **Testing shares** Piano 10, base Ambient 10, Zen 80, as a recorded temporary edit (Zack, 2026-11-09). Section 4.
- **Rules follow the AMB-1 code** where they disagree, inside our architecture (Zack, 2026-11-09). Section 3.
- **AMB-1's algorithms, numbers and code fragments may be used** (Zack, 2026-11-09). This reverses "no AMB-1 code, ideas only". Copied fragments go in AmbientZenAMB1.swift with the MPL-2.0 notice. Section 2.
- **Colour chord kept** at 30 percent of journey songs, middle third only, once (Zack, 2026-11-09). Not Yet Remembered (The Plateaux of Mirror) is the one corpus piece with a long-form journey, and it does exactly this: two passes of its home cycle, a departure in the middle with chromatic bass steps outside the key, then home again. Cycle and field songs stay diatonic, as The Big Ship and Against the Sky do. Clash analysis and mitigation in section 6.
- **Big Ship Cycle** pads play held block chords that follow the chord, 4 bars a chord, 32-bar cycles; no vii in Ionian; the pedal-semitone voicing penalty for every pad rule (Zack, 2026-11-09). Sections 6 and 10.
- **Tine Electric Piano removed from the Pads lists**; the Rhodes-colour list is FM Electric Piano, Fantasia, Warm Pad and Halo Pad (Zack, 2026-11-09). Section 11.
- **Pulse in four recipes**, about 52 percent, Slack Water very light, Glasshouse none (Zack, 2026-11-09). AMB-1 has a pulse in five of its eight pieces. The tiebreaker barely applies, because base Ambient already has hand percussion; the drone is what sets Zen apart.
- **The field stays narrow**, about 16 percent: Choir Loop plus 30 percent of Slack Water (decided 2026-11-09). Base Ambient already runs co-prime loops over held windows, which is close to a static field, and the corpus favours movement in its long pieces. The share freed goes to the Big Ship cycle.
- **Eno MIDI done** (2026-11-09, section 19). It gave AMB-PADS-015 Big Ship Cycle, AMB-BASS-008 Plateaux Octave Root and AMB-TEXT-012 Pearl Pedal.
- **Bass glide is part of the design**, slow and long, in both directions, as the code does (Zack, 2026-11-09). The Chill memory says only upward slides sound like slides; AMB-1 glides both ways and Zack likes it. Section 18.
- **AMB-BASS-001 Loscil drone stays** for now; drop it if Zen sounds too much like base Ambient (Zack, 2026-11-09).
- **Long-sustain rule** for bass, drone and pad instruments, with Cello kept in for the audition (Zack, 2026-11-09). Section 11.
- **Drift**, a slow per-track pitch wander, is Zack's idea (Zack, 2026-11-09). Section 12.

**Decided by Claude, Zack may overrule** (all 2026-11-09)
- Mix shares: release Piano 35, Zen about 30, base about 35 (section 4). The testing split (Piano 10, base 10, Zen 80) is Zack's.
- "Tide" renamed "arc"; the recipe's tide depth is Motion (section 8).
- The recipe's chord-timing value is called "chord drift" (section 5).
- Recipe values taken from AMB-1's PIECES table, with Glasshouse bass and bells both an octave up, and the echo-time rule under the 2.0 s cap (section 5).
- Pulse hit counts, velocity and drum kits from the code (section 10).
- Bass weights AMB-BASS-007 0.50, AMB-BASS-008 0.31, AMB-BASS-001 0.19, with AMB-BASS-000 only for Departure Lounge; only AMB-BASS-007 glides (section 10).
- Choir Loop's rare bell moves to Lead 1 (AMB-LEAD-013 Becalmed Bell, 30 percent); Slack Water field songs keep Lead 1 as their only bell loop (section 10).
- Field songs have 5 or 6 voices, and their instruments get Zen pick-list entries (sections 10 and 11).
- AMB-PADS-013 Neroli Hold re-breathes 1 s after a change; AMB-PADS-012 Plateaux Bloom's breath and ninth rule (section 10).
- Field and cycle pad rules come from the harmony plan, not the Pads roll (section 6).
- Every bell rule uses its track's loop and base note; generic bell velocity; Lead 2's collision filter in ZenCoordinator; no constant rest chance; the arc does not scale bell velocity (section 7).
- Texture entries, pans, echo wets and no-bass weights by rule (section 10).
- Effects: Drift and bass tremolo defaults, the darker Pads sweep, Rhythm auto-pan, static pans from the code (section 12).
- Reverb, echo and Drift move into build step 2 (section 15).
- Seed indices 96 and 99 to 105 (section 4).
- Chord timing from the code, with no clamp (section 6).
- Pads start within about 3 s; the trim keeps a listening check (section 9).
- ZenPlan rebuilt from the seed for regeneration; Evolve by harmony plan (section 13).

**Open, for Zack**
- **The two AMB-1 listening tests** in section 18: pads to 0 with the bass down, then reverb and echo to 0 as well.
- **Colour chord reach (for information).** Dorian, Mixolydian and pentatonic songs get none, and Choir Loop is always a field song, so in practice it plays in only about 8 percent of Zen songs (Departure Lounge, Afternoon Light, Late Shuttle). Widen it after listening if journeys sound too plain.
- **Listen later, not decided:** a shared Zen echo bus, and .cathedral against .largeHall2 (section 12).

## 18. The drone: the continuous low bed

**What AMB-1 actually does** (read from amb.c on 2026-11-09). There is no separate drone voice. The steady low bed is three things:
- **The bass never stops.** It is one sine voice with a sub-octave (fundamental 0.75, sub-octave 0.45, second harmonic 0.12), at MIDI 36 to 47 before its octave setting.
  - It follows each chord root.
  - Its amplitude is never re-triggered: only the pitch glides to the new root, with a time constant of 0.15 to 0.5 s across the pieces, so the audible slide lasts about 0.4 to 2.2 s.
  - It fades in over about 2.5 s and out over about 4 s, and only when it sits a chord out or the piece stops.
  - It has no LFO, no filter and no detune.
  - It is mixed almost dry and centred.
- **The pads overlap.** Four voices breathe on unequal cycles (about 10 to 17 s in Afternoon), each silent about 10 percent of its cycle, staggered so their rests rarely line up.
- **A long plate and tape echo** fill whatever gaps remain.

So the steadiness comes from continuity: the amplitude never dips at chord changes.

**Zack's listening test (2026-11-09).** With AMB-1's Bass turned down in the Afternoon preset, a separate long-running drone is still clearly there. So the bass is not the drone. The likely sources are the pad bed (four voices that rest only 10 percent of their cycle, through a dark low-pass) and the reverb and tape-echo wash behind it (plate decay about 0.9; tape feedback about 0.76). Two further tests are proposed to Zack: pads to 0 with the bass still down, then reverb and echo to 0 as well. Until they are run, treat this as a hypothesis. The consequences, already in the plan: the Zen pad breaths follow the code's shape and rest only 10 percent of the cycle (section 10), echo feedback follows the code's formula (section 12), and the space is built with the drone (section 15). The bass and the Texture pedal below are supporting layers, not the core. A real per-voice swell (AMB-1 rises for about 4.5 s and falls for about 4 s) can't be done on a shared track with sampled pads; the swell ladder in section 12 is the plan for it.

**What the AMB-1 code shows about the pads** (amb.c, read directly 2026-11-09; the Afternoon numbers use its own table: Swell 50, Bright 60, Size 75, Rhodes pad). There is no hidden drone voice anywhere in the file. The drone is the pad bed, made of these pieces:
- **Near-pure tones.** The Rhodes pad is one FM sine carrier plus a 12 percent second harmonic, with a mild bloom. Through the pad bus's 12 dB low-pass (about 2.4 kHz at Bright 60) it is effectively a sine. So pure tones do work in AMB-1, but only because of everything below.
- **Slow swells, not notes.** Each voice's volume follows one smooth shape per breath (section 10 has the shape). In Afternoon each voice rises over 4 to 7 s and falls over 3 to 6 s. The four voices' rests almost never coincide, so the sum of four crossfading swells is a nearly level bed. There are no note attacks to hear.
- **Common tones hold through chord changes.** A voice whose note is in the new chord carries on to the end of its breath.
- **Each voice drifts in pitch on its own** (up to ±8 cents, with a new random target every 7 to 40 s), and pans slowly around the field, so the sines never settle into a fixed beat.
- **The reverb tail is made of the same pure tones.** Pads send 0.6 to a Dattorro plate with decay about 0.88 (Size 75), and the echo repeats are fed into the plate as well. I estimate its tail at roughly 10 to 20 s, from the decay value and the tank's delay lengths. I did not measure it. Because the source is pure chord tones, the tail is a smooth chord-tone wash with no noisy smear.
- **The tape echo feeds back at about 0.74 here** (0.5 + 0.32 × Size/100), with each repeat darker than the last.

**Zack's theory, and the code behind it (2026-11-09).** Zack suggests the interest is a chord dynamic between the bass and the pads as they evolve out of time with each other. The code supports it. At a chord change the bass retargets at once and glides to the new root in about 0.2 s (Afternoon's Glide is 15). The pads do not follow. A voice on a note the new chord shares holds it to the end of its breath, which can be 17 s. A voice on a note the new chord lacks fades in about a second and re-enters on its new note, rising over several seconds. Each voice takes its new note only at the start of its own breath. So for the first seconds after every change, a new bass root sounds under pads that are still mostly the old voicing, and then the chord forms, one voice at a time. At the halfway point of a chord the bass may also lean on the fifth, which gives a slash-chord colour under the pads. The two never line up because the pad cycles (10 to 17 s) are unrelated to the chord length (about 30 to 40 s).

**Design principle: the bass leads and the pads lag.** The bass changes exactly at the chord change, and the pad voices arrive at their own breath timing. Never quantise the breathing pads to the chord change, and never give them a bar-aligned re-voicing. AMB-PADS-011 and AMB-PADS-012 work this way, AMB-PADS-013 re-breathes 1 s after the change, and AMB-BASS-007 changes at the window start. The one exception is AMB-PADS-015 Big Ship Cycle, whose block chords follow the chord as in its source. Check by ear for the lag at the build's listening stop.

**What Zudio can and can't do**
- It can hold notes as long as it likes, overlap them, and choose a pure Sine Wave preset (8080, in Zudio.sf2). Every bass and drone instrument must have long sustain (section 11), and none is relied on to be interesting on its own: Drift and a slow tremolo (section 12) keep a held note moving, because a looped sine is static.
- Every new MIDI note re-attacks the sample. With a sine or pad timbre and a small overlap, that attack is soft. The glide avoids re-attacks altogether by bending one held note.

**The Zen drone: two layers that never both stop**

*Lower: the bass* (AMB-BASS-007, AMB-BASS-008 or AMB-BASS-001, section 10)
- **Glide: a legato bend on one held note (Zack, 2026-11-09).** Zack hears AMB-1's slides when chords change and is happy to have them; they are slow and nothing like a blues bass slide. The code moves the bass pitch toward its target with a one-pole approach: time constant = 0.02 + 0.012 × Glide seconds. The recipes' Glide of 10 to 45 gives 0.14 to 0.56 s, and the audible slide lasts about three time constants, about 0.4 to 1.7 s, for jumps of up to 11 semitones, both up and down.
- **Runs.** In AMB-BASS-007, one note is struck at the start of a run (the first bass note after silence), and every chord change and fifth move after that is a pitch bend on that held note, with no re-strike. This is the code's behaviour exactly, and it needs no overlap logic. A run ends at a sit-out or the end of the song. Roots span 12 semitones from the struck note at most, so every target sits inside a bend range of 12.
- **The generator** still writes ordinary events, one note per window at the true pitch, so the piano roll, the MIDI export and regeneration are unchanged.
- **The playback transform** (new, Zen only, Playback/ZenBassGlide.swift): at load, scan the bass events and group contiguous windows into runs. For each run, record the anchor note (the first note) and, per window, the target pitch and the Glide time constant. At playback, the first note of a run strikes normally, the later note-ons and the earlier note-offs are suppressed, and each window start starts a bend ramp. It borrows startBassSlide's ramp pattern, not ChillBassSlides' map or its range.
- **Curve.** bend(t) = target − (target − start) × exp(−t / tau), in semitones, sent every 16 ms over about 4 tau. The existing startBassSlide ramp is the template, using the stepTimerQueue and the schedulerID guard so a stop or seek cancels it.
- **Bend range.** Send RPN 0 on the bass channel at load: CC 101 = 0, CC 100 = 0, CC 6 = 12, CC 38 = 0, then CC 101 = 127 and CC 100 = 127. Set it back to 2 for every other style, so the existing Chill slides keep their range. Whether the sampler honours RPN 0 is not verified; test it in step 2 of the build. If not, fall back to re-struck notes with a 1-beat overlap.
- **Seek and stop.** A seek into the middle of a run starts a new run at that window's own pitch, with no bend. Stop sends the bend back to centre, as the slide code does today.
- **Sustain requirement.** A held note must sustain for minutes. Only the looped, full-sustain instruments qualify: Sine Wave, Fretless, Synth Bass 101, Tonewheel Organ and Voice Oohs. If Cello is the picked instrument, the bass falls back to re-struck notes with the 1-beat overlap and no glide.
- **Export.** M4A export schedules notes itself, and glide is a playback-time ramp, so exports play the re-struck windows with no glide until the export path is taught the ramp. Acceptable for phase 1.
- **Overlapping joins** remain only where the bass re-strikes: AMB-BASS-008 and the Cello fallback hold each note until 1 beat after the next starts, so there is never a gap.
- **Edge fades.** A 2.5 s fade-in on the first note after silence, and a 4 s fade-out before a sit-out and at the exit. No ramps at joins.
- Almost dry (reverb send 10) and centred, with a light tremolo and Drift (section 12).

*Upper: the Texture pedal* (AMB-TEXT-012 Pearl Pedal; weights in section 10)
- Holds the song's tonic, and the fifth above it in 60 percent of songs, in register 48 to 62. It does not follow the chords. That is the Eno/Budd sound: chords move over a held tone.
- **Re-breathed, not re-struck.** Each note lasts 3 to 5 bars, drawn per note. The next starts 1 beat before the last ends. Velocity 40 to 54, scaled ±10 percent by the arc.
- **Clash guard.** When a window's chord holds a note a semitone from the pedal's fifth (the #4 or b6), the pedal drops the fifth for that window and keeps the tonic. It does the same for the colour chord. The tonic is never dropped: a seventh or ninth against it is the sound we want.
- Enters at bar 0 with the pads (fade in 2.5 s). In the outro it joins the pads' held breath and ends with them.
- Static pan 0, reverb send 55, light echo (wet 10), Drift on.

**Why two layers.** The bass gives the AMB-1 motion: the root moves and the bed moves with it. The pedal gives the Eno/Budd stillness: the tonic is always there. Most songs get both, so at any moment at least one low voice is sounding. Departure Lounge has no bass, so the pedal carries it alone.

**Small speakers.** A sine at 65 to 123 Hz all but vanishes on a phone speaker, and Choir Loop's bass sits lower still. The pedal an octave or more above and AMB-BASS-008's upper octave make the drone audible there. Check on the iPhone speaker in step 7 of the build.

**Fallback: an audio drone.** Zack's original idea was an audio file on Texture that fades in and out. A file pitched to the song's key wouldn't need swapping at chord changes, because a pedal doesn't follow the chords. But it needs a pitch-shift node in AudioTexturePlayer and a matching one in OfflineExport. That is new iOS audio code, and it crosses the ruling that audio textures stay unique to base Ambient. Keep it as phase 2, only if the MIDI pedal sounds too clean.

## 19. Eno MIDI corpus findings

**Source.** Fan sequences from Online Sequencer, fetched with tools/fetch_eno_midi.py into docs/midi-analysis/eno/ (not committed). Measured with tools/eno_analyze.py.

The site's old midi.php export is gone. The script reads the sequence protobuf from app/api/get_proto.php and writes MIDI itself. Pitch is taken as an index from C0 (MIDI = index + 12). That mapping is not verified against the site, so registers may be an octave off; intervals are unaffected. All velocities are flat in most files.

BitMidi, MIDIWorld, FreeMIDI, Midis101 and MIDI DB have no Eno. Online Sequencer has no fan files of An Ending (Ascent), Deep Blue Day, Thursday Afternoon or Discreet Music.

**Usable pieces**
- **The Big Ship** (Another Green World), 118 bpm, 171 s.
  - Pads: one 8-chord cycle, Am F C F Am F C G (vi IV I IV vi IV I V in C), five-note voicings, 6 beats a chord.
  - The cycle repeats for the whole piece. The only change between passes is one voicing, an F chord moved to C in the bass.
  - The drum loop repeats every 3 bars without change.
  - High melodic layers enter at bars 20 and 28 and never leave.
  - Harmony is entirely diatonic.
  - Basis of AMB-PADS-015.
- **Not Yet Remembered** (The Plateaux of Mirror, with Harold Budd), 47 bpm, 246 s, C# minor / E major.
  - Bass: a root octave pair held about 7.5 beats, then its upper note re-struck for about 3.75 beats. The low bed sounds about 95 percent of the time.
  - Home cycle A E A C#m, played twice.
  - Middle: a departure through F# and B, with chromatic bass steps B Bb Eb D, then back to E.
  - Return: the home cycle again.
  - Piano: two- or three-note chords on every beat, repeating every 4 bars (71 percent).
  - Melody: enters at bar 16 with the departure and leaves at bar 46, before the end.
  - Basis of AMB-BASS-008 and the colour-chord answer; supports the journey's leave-and-return shape.
- **Against the Sky** (The Pearl, with Harold Budd), 60 bpm in 3/4, 170 s.
  - Almost a pure field: F#, Bb, Eb and C# make up 97 percent of the sounding time, and only 5 distinct chord sets occur.
  - F# and Bb sound under every chord. Only a third voice moves, between Eb and C#.
  - Chords are re-struck every 3 beats with long holds (up to 12 beats), so 82 to 96 percent of the time a low voice is sounding.
  - Basis of AMB-TEXT-012.
- **A Stream With Bright Fish** (The Pearl), only 11 s. One G minor triad held under a short melody. It agrees with Against the Sky but proves little on its own.

**Rejected**
- **Among Fields Of Crystal**: the three WIP files are the same 10 bars, and use all twelve pitch classes; they look unfinished.
- **Music for Airports**: both excerpts are 3 s each, also all twelve pitch classes, so they are not usable.
- **The Big Ship remix**: the same notes as the original at another tempo.
- **Prophecy Theme** (Dune), 14 s, and **Brian Eno untitled**: too short and unverified.

**What it adds up to**
- The low register is almost never empty. Big Ship, Not Yet Remembered and Against the Sky all keep a low voice sounding about 90 percent of the time or more. That matches what Zack hears in AMB-1, and it is the case for section 18.
- Repetition is literal and long. Cycles repeat unchanged for the whole piece, and change comes from layers entering, not from the harmony mutating. The per-pass loop changes in section 7 should therefore stay gentle, at low restlessness by default.
- Common tones carry the harmony: chords change over held notes rather than all voices moving at once.
- Layers enter late and leave early: melodies in the middle of the piece, beds from start to finish.

## 20. Reference links

Read in this order for AMB-1: the manual first (it is short and is the only design writing the author published), then the code.

**AMB-1 (Charles Vestal, MPL-2.0)**
- Repository: https://github.com/charlesvestal/fm1-amb
- The manual, on GitHub: https://github.com/charlesvestal/fm1-amb/blob/main/docs/MANUAL.md
- The manual, published: https://charlesvestal.github.io/fm1-amb/manual/. Worth reading: the manual's section 5 "The garden", section 6 "The pieces", the pages in section 7 (Pad, Bells, Bass, Pulse, Space), and the parameter table in section 11.
- The engine: https://github.com/charlesvestal/fm1-amb/blob/main/app/dsp/amb.c. The line numbers below are from the copy read on 2026-11-09 and may have moved:
  - the eight pieces' table, lines 37 to 53 (the column header comment is at lines 39 and 40), and the Drift-to-seconds formula, line 86;
  - the slow modulators, lines 355 to 376;
  - the pad voices, the breath shape and chord handoffs, lines 379 to 584;
  - the bass state, line 529; the bass retarget, 599 to 607; the chord walk, 623 to 646;
  - the bell loops and their per-pass changes, 648 to 770; ringing a bell, 773 to 787;
  - the pulse, 789 to 925;
  - the echo heads and the tape, 1084 to 1135;
  - the pad bus and pad rendering, 1437 to 1545; the bass rendering, about 1547 to 1575;
  - the final mix, 1690 to 1710; the arc and the chord timer, 1717 to 1745.
- Release notes (the echo-heads change is in the version of 10 October): https://github.com/charlesvestal/fm1-amb/releases
- Browser emulator and web app, listed on the repository page, not opened: https://charlesvestal.github.io/fm1-amb/emu/ and https://charles.pizza/amb
- Platform and credits: fm1-base (https://github.com/charlesvestal/fm1-base, not opened). The reverb is Dattorro's plate (J. Dattorro, "Effect Design, Part 1", Journal of the Audio Engineering Society, 1997).

**Derived firmwares, for context only** (none has design notes on AMB-1)
- NACHTFAHRT, which says it descends from DUB-1, which descends from AMB-1: https://www.matrixsynth.com/2026/11/the-most-relaxing-firmware-for-m-wave.html
- DUB-1: https://www.matrixsynth.com/2026/11/fm-1-dub-1.html
- ZEN-1, a related FM-1 firmware (not derived from AMB-1): https://www.matrixsynth.com/2026/11/fm-1-zen-1.html

**Eno sources used for the harmony and bass findings** (fan transcriptions, private analysis only)
- The Big Ship: https://onlinesequencer.net/983336
- A Stream With Bright Fish: https://onlinesequencer.net/5003459
- Among Fields Of Crystal, work in progress: https://onlinesequencer.net/5439286, https://onlinesequencer.net/5181117 and https://onlinesequencer.net/4808484
- Against the Sky (richz): https://onlinesequencer.net/3084268
- Not Yet Remembered (richz): https://onlinesequencer.net/3056055
- Music for Airports excerpts: https://onlinesequencer.net/890687 and https://onlinesequencer.net/841635
- Music for Airports 2/1 recreated in ChucK, with exact pitches and loop lengths: https://chuck.cs.princeton.edu/chugl/examples/sequencers/music-for-airports.ck
- Music for Airports 1/1, guitar and bass arrangement on MuseScore (needs a login): https://musescore.com/user/30359691/scores/11499025

**In this repository**
- The converted MIDI files: docs/midi-analysis/eno/ (not committed).
- The download script, tools/fetch_eno_midi.py, and the analyser, tools/eno_analyze.py.
- The earlier firmware idea: /Users/urlocker/Downloads/Zenio/Zenio-on-FM-1.md.
- The Ambient plans: docs/ambient-plan.md and docs/ambient-piano-plan.md (its weights are stale; trust the code).
- The session handover: docs/2026-11-09-ambient-zen-handover.md. It is out of date where this plan differs.
