# Ambient Zen — substyle plan
Copyright (c) 2026 Zack Urlocker

*Status: plan, 2026-11-09. Nothing built. "Ambient Zen" is a working name; "Ambient Layover" is the alternative on the table. Fan Eno MIDI analysed (section 19); open questions answered (section 17); the drone is now the centre of the design (section 18). AMB-1 code and manual compared item by item and the rules aligned (section 20, which wins where it differs from an earlier section; the earlier sections still need merging). Awaiting Zack's approval to build.*

**Contents**

1. What Ambient Zen is
2. Ground rules
3. What we take from AMB-1, and what we don't
4. Selection, seeds and saved songs
5. Recipes
6. Harmony: the chord journey
7. Loops: how the bell loops work
8. Tide: the slow swing between sparse and full
9. Structure: entry, body and the unwinding ending
10. Rules by track
11. Instruments
12. Effects
13. Evolve mode and track regeneration
14. Plumbing: every place that changes
15. Build order and checks
16. Eno research: harmony and the Evolve question
17. Open questions (answered)
18. The drone: the continuous low bed
19. Eno MIDI corpus findings
20. AMB-1 alignment: the specification the build follows (wins over earlier sections where they differ)
21. Reference links

---

## 1. What Ambient Zen is

A third Ambient flavour beside base Ambient and Ambient Piano. It is inspired by AMB-1, Charles Vestal's generative firmware for the M-Vave FM-1, which in turn comes from Eno's Music for Airports and Discreet Music.

The sound: four breathing pad voices that swell in and out on their own cycles so the chord forms and dissolves, soft bells on short loops of unequal length that slide past each other, a low root that sometimes leans on the fifth, and in some songs a very quiet polyrhythmic pulse, all in a long hall with a darkening echo. Unlike base Ambient, the harmony moves: a slow chord journey of four to seven chords that leaves home, travels and comes back. A few songs instead hold one pitch field and let the chords emerge from overlapping voices, as in Music for Airports 2/1.

What makes it audibly distinct from base Ambient:
- **A continuous low drone** (section 18). A sine root on Bass that never leaves a gap, under a held tonic pedal on Texture. Listening to AMB-1's Afternoon preset, this is what makes it sound steady and evolving, and base Ambient has nothing like it. It is the first thing to build and the first thing to judge by ear.
- Chords move through the song (base Ambient holds one to three windows).
- Loops are measured in beats, not bars, so the phasing is heard every few seconds rather than every few minutes.
- Loops change a little on every pass instead of repeating exactly.
- Lydian is available, and it is not used in base Ambient.
- New instruments: vibraphone, Rhodes, choir and voice pads, synth chimes, low tower bells.

## 2. Ground rules

- **Base Ambient and Ambient Piano do not change.** No rule, weight, instrument pick or effect changes for them. The only difference is that a share of non-piano seeds become Zen songs (section 4). The fingerprint check in section 15 proves nothing else moved.
- **Tracks are ours to assign.** Pad voices may be spread across Pads, Lead 2, Rhythm or Texture if a recipe needs separate instruments. An eighth MIDI track, as Chill Soho added, is a last resort only, because it took a lot of testing there.
- **No rearchitecture.** Zen is a branch inside generateAmbient that returns early, the way Ambient Piano does. All Zen music code lives in new files. Shared files get small guarded branches only.
- **No AMB-1 code.** AMB-1 is MPL-2.0. We take ideas and our own numbers, written fresh in Swift.
- **Existing rules reused as they are.** Zen calls AMB-BASS-001, AMB-TEXT-000 and AMB-DRUM-000 unchanged. Anything that would need a tweak becomes a new Zen-only rule.
- **Determinism.** No Dictionary or Set iteration order feeds an RNG draw. Every Zen draw comes from the per-track RNGs or from a fresh trackSeed index.
- **iPhone parity.** Any effect default set in TrackRowView is mirrored in AppState.restoreDefaultEffects.

## 3. What we take from AMB-1, and what we don't

**Taken, in our own form**
- Breathing pad voices with unequal cycles, each taking its chord note at the start of a breath.
- Chord tones built as stacked diatonic thirds (sevenths in seven-note modes, open three-note chords in pentatonic).
- A weighted chord walk that never repeats the current chord. We add a shape to it (section 6), because a finite song needs a departure and a return.
- Bell notes stored as scale steps from the current chord, so the loops re-harmonise when the chord moves.
- Per-pass loop changes: a pass rests, a note is replaced, a note moves, a loop grows or thins.
- A slow tide between sparse and full.
- Euclidean pulse on three different cycle lengths, rotating slowly.
- Root bass that may move to the fifth halfway through a chord, and sometimes sits a chord out.
- Eight pieces as recipes. We write eight of our own (section 5).

**Not taken**
- FM synthesis, the formant voices and the filter bloom. Sampled instruments replace them.
- Bass glide. The Zen bass holds notes, and its existing boost fade softens the joins.
- The 5.6 s tape loop. AVAudioUnitDelay tops out at 2 s, so echo times are capped.
- Micro-timing (AMB-1 delays bells up to about 60 ms). Zudio is on a sixteenth grid.
- Live control and modulation (pitch, pan and vowel wander). Pan movement comes from auto-pan instead.

## 4. Selection, seeds and saved songs

**The roll.** generateAmbient draws two numbers before anything else: pianoRoll and pianoRuleRoll. Non-piano songs draw pianoRuleRoll and ignore it. Zen reuses it:

- Piano if pianoRoll < 0.35 (unchanged).
- Zen if not piano and pianoRuleRoll < zenShare.
- Otherwise base Ambient.

**Share.** One constant, zenShare, set as a share of non-piano songs:
- **Testing:** Zen at 80 percent of all Ambient songs. Piano takes 35, so Zen needs every non-piano song plus a temporary Piano cut to 20. During testing pianoRoll < 0.20 and zenShare = 1.0, giving Piano 20, Zen 80, base 0.
- **Release:** Zen between 25 and 35 percent of all Ambient songs, set by ear. At Piano 35 and Zen 30, zenShare = 0.46 and base Ambient is 35. Piano may come down a little.
- The testing values are a temporary edit, marked in the code, and set back before release.

This adds no new draw to the shared prefix, so the frame, structure and tracks of every base Ambient and Piano song stay identical. Zen songs consume the normal frame draws and then override what they need, so nothing downstream of them shifts either.

**Saved songs.** A seed that is base Ambient today and falls in the Zen share becomes Zen when reloaded by the new build. This is accepted: no save protection. The forced-rule log line gets forced["Zen"] = recipe name, mirroring forced["Piano"].

## 5. Recipes

Each Zen song draws one of eight recipes. A recipe biases the frame and the rule weights. It does not pick rules outright, so each track still rolls one rule. The names are ours, chosen to stay in the airport and waiting-room world.

- **Concourse** (weight 0.16). Dorian, 68 to 76 bpm. Everything, gently: Rhodes-colour pads, bells, bass, soft pulse. Restlessness 0.35, chord drift about 40 s.
- **Departure Lounge** (0.14). Ionian, 58 to 64 bpm. Low, slow bells over a quiet Rhodes pad. No bass, no pulse. Restlessness 0.30, drift about 60 s.
- **Choir Loop** (0.12). Aeolian, 54 to 60 bpm. Voice pads alone with a low bass. No bells except a rare Texture low bell. Restlessness 0.30, drift about 75 s.
- **Afternoon Light** (0.14). Lydian, 80 to 88 bpm. Bright Rhodes, busier bells, a light pulse. Restlessness 0.45, drift about 35 s. This is the recipe closest to AMB-1's Afternoon preset, the one Zack is listening to (G Lydian, 84 bpm, Rhodes pads, bass at a medium-low level, fifth in 40 percent of chords, chords about every 34 s, echo at a dotted half). Its bass fifth chance is 0.40, and it is the reference recipe for tuning the drone.
- **Late Shuttle** (0.10). Aeolian, 90 to 98 bpm. The pulse forward, metallic bells, shorter echo. Restlessness 0.50, drift about 30 s.
- **Tidewater** (0.12). Major pentatonic, 62 to 66 bpm. Dark, round bells lost in long echoes. No pulse. Restlessness 0.40, drift about 60 s.
- **Glasshouse** (0.10). Minor pentatonic, 74 to 78 bpm. Glassy bells an octave up, dense. No pulse (section 17). Restlessness 0.55, drift about 40 s.
- **Slack Water** (0.12). Mixolydian, 68 to 72 bpm. Voice pads, the most changeable recipe. A very light pulse (about 70 percent of the usual velocities). Restlessness 0.75, drift about 28 s. It is the recipe closest to AMB-1's Tides, a preset Zack likes (Bb Mixolydian, 70 bpm, Voices pads, restlessness 75, chords about every 26 s, bass fifth in 55 percent, pulse 35, "very light hand percussion or drums").

Recipe fields, set per recipe and fixed for the song:
- mode, tempo range (triangular, peak at the middle);
- key: drawn from the base Ambient key weights (the frame draw is kept);
- pad colour bias: Rhodes or Voices (section 11);
- layer presence: bass, pulse, and each of the four bell loops;
- bell density (target notes per loop, 1 to 4), bell octave bias (-1, 0, +1);
- restlessness (0 to 1): scales the per-pass loop changes and the pulse drift;
- drift: mean chord length in seconds;
- tide depth (0 to 1);
- echo time in beats and echo feedback level (section 12);
- harmony plan: journey, cycle or field (section 6), drawn once from the Pads RNG;
- bass fifth chance (0.2 to 0.5) and drone weight (section 18).

"Restlessness" is AMB-1's Evolve, renamed so it doesn't collide with Zudio's Evolve mode.

## 6. Harmony: the chord journey

The goal is a song that audibly travels: it settles at home, moves outward, reaches its furthest point around the middle, and comes home for the ending. AMB-1's pure weighted walk never comes home. A finite song needs to.

**Chord count and length**
- Window length in bars = drift seconds × bpm / 240, times a random 0.75 to 1.25, rounded to whole bars, clamped 6 to 20 bars. At 70 bpm and drift 40 s that is about 12 bars.
- Windows are laid end to end across the song. A 4-minute song gets 4 to 7 chords depending on the recipe.
- Chord changes land on bar lines. They are not forced onto a 4-bar grid, so they don't fall into a predictable metre.

**Chord tones**
- Seven-note modes: stacked thirds from the chord's degree, four notes (a seventh chord). Stored in the ChordWindow as maj7, min7 or dom7, which ChordType already has. The half-diminished chord is never chosen.
- Pentatonic modes: three notes, every other pentatonic step. These come out as open, sus-like chords (for example C E A in C major pentatonic). They are stored with explicit chordTones and the nearest ChordType for display (maj6, add9 or sus2).

**The shape**
- Window 1 is always the tonic, and it lasts at least the intro plus one full window.
- The last window is always the tonic and covers the outro.
- The window before it comes from a soft return set: IV or ii in Ionian, II (major) or vi in Lydian (its IV is the half-diminished chord), IV or bVII in Mixolydian and Dorian, bVI or bVII in Aeolian. Never V7 to I: the pull is too functional for this style.
- Every window between is a weighted walk.

**Walk weights** (seven-note modes, by scale degree)
- I 2, ii 2, iii 1, IV 3, V 2, vi 3, vii 0.
- The current chord is excluded.
- The chord from two windows back is weighted × 0.3, so it rarely ping-pongs.
- The tonic may return in the middle at most once, and only after two or more moves. That is the "home visit".
- In the middle third of the song, iii, vi and the mode's characteristic chord are weighted × 1.5. This is the furthest point.
- Characteristic chords, weighted × 1.5 throughout: Dorian IV (major), Lydian II (major), Mixolydian bVII, Aeolian bVI.
- V in Ionian and Lydian is voiced as a sus4 chord, so there is no leading-tone pull.

**Pentatonic weights**: I 2, each other degree 1.5. Same shape rules.

**Example journeys** (about 5 minutes, drift around 40 s)
- D Dorian, Concourse: Dm7, G7, Em7, Cmaj7, Am7, G7, Dm7.
- G Lydian, Afternoon Light: Gmaj7, A7, Em7, Bm7, F#m7, A7, Gmaj7.
- A Aeolian, Choir Loop: Am7, Fmaj7, Dm7, Cmaj7, Em7, G7, Am7.
- Bb Mixolydian, Slack Water: Bb7, Ebmaj7, Gm7, Abmaj7, Cm7, Abmaj7, Bb7.
- C# Ionian, Departure Lounge: C#maj7, F#maj7, A#m7, D#m7, G#sus4, F#maj7, C#maj7.

**Who follows the chord plan.** Everything in Zen does, at every note. The Zen windows go into structure.chordPlan, and the TonalGovernanceMap is built from them in the usual way, so AMB-BASS-001 follows them unchanged. Bell loops and pads resolve their pitches against the window in force at each note's step.

**Colour chord (decided, section 17).** In 30 percent of journey songs, once, in the middle third, one window becomes a borrowed chord: bVImaj7 in Ionian or Lydian, IV major in Aeolian, bVII major in Ionian. During that window the bells resolve to chord tones only, so they never clash with the scale, and the Texture pedal keeps only the tonic (section 18). Never in cycle or field songs.

**Three harmony plans.** Each song draws one, from the Pads RNG, after the recipe:
- **Field**: AMB-PADS-014 Airports 2/1 Field (section 16). Choir Loop always, and 30 percent of Slack Water songs. About 16 percent of Zen songs.
- **Cycle**: AMB-PADS-015 Big Ship Cycle (below). 25 percent of the remaining songs, about 21 percent of Zen.
- **Journey**: the shape above, for everything else, about 63 percent of Zen.

**AMB-PADS-015 Big Ship Cycle.** Taken from The Big Ship, from Another Green World (section 19). The fan file holds one 8-chord cycle, Am F C F Am F C G, 6 beats a chord, unchanged for the whole piece apart from one bass voicing, while new layers come in on top at bars 20 and 28.
- Pick three chords besides the tonic from the walk weights, without repeats: A, B and C. The cycle is A B T B A B T C, where T is the tonic, so the tonic comes round twice per cycle and C is the turnaround. In Ionian and Lydian, V is voiced sus4 as usual.
- Each chord lasts 2 bars, so a cycle is 16 bars (about 50 s at 76 bpm). That is much faster than the journey, and nothing like base Ambient's held windows.
- The body repeats the cycle unchanged. Each pass, with probability 0.3, one slot puts the bass on another chord tone (the Big Ship's one voicing change).
- The intro and outro hold the tonic, as in the journey.
- Layers enter by addition at cycle boundaries: Lead 1 at the second cycle, Lead 2 at the third. That replaces the entry bars in section 9 for these songs.
- Bass and Texture follow it exactly as they follow the journey.

## 7. Loops: how the bell loops work

**Loop lengths.** Each bell loop is a fixed number of beats, so its length doesn't have to be a whole number of bars. A 17-beat loop is 68 sixteenth steps, which is 4¼ bars. Zen's own lengths, all prime so no two loops line up:

- Lead 1: 13 or 17 beats.
- Lead 2: 19 or 23 beats.
- Rhythm: 11 beats (the short, glassy loop).
- Texture: 29 or 31 beats (the slow, low loop).

At 70 bpm, 17 beats is about 15 s. A 5-minute song hears Lead 1 about twenty times, and the four loops never repeat their combined pattern.

**Why not a "step tiler".** The current AmbientLoopTiler copies one loop, unchanged, across the song in whole bars. Zen needs two things it can't do: loops that aren't whole bars, and a loop that changes a little on each pass and follows the chord. So Zen doesn't tile. A new helper, the pass unroller, walks the song one pass at a time:

1. Start with the loop's slots: each is empty or holds a scale step relative to the chord, plus a velocity.
2. For each pass, apply the per-pass changes (below), then write the pass's notes into the song.
3. Resolve each note's pitch against the chord in force at its own step. A loop that straddles a chord change plays its first notes in the old chord and the rest in the new one, as AMB-1 does.
4. Skip any pass the song structure has silenced, such as before the track's entry bar or after its exit bar.

AmbientLoopTiler is not touched, so base Ambient keeps its current behaviour.

**What a slot holds**
- 70 percent chord tone (step 0, 2, 4 or 6 above the chord root, in scale steps), with a 25 percent chance of an octave lift.
- 30 percent passing tone (step 1, 3 or 5).
- Velocity drawn once when the note is added, from the rule's range.

**Why the bells never clash (Zack's observation, checked in amb.c 2026-11-09).** AMB-1's bell notes are never chromatic. Each slot stores a scale step above the current chord's degree (72 percent a chord tone, sometimes an octave up; 28 percent a passing 2nd, 4th or 6th), and the pitch is looked up in the song's scale. So every bell note is a note of the song's scale, whatever the bass and pads are doing. The bass moves to a new root at once while the pads are still crossing over from the old chord (section 18), so for a few seconds the two disagree. Because everything sits in one scale, that disagreement reads as a moving chord colour and never as a clash. Zen keeps this: bells are always scale tones, resolved against the chord in force at their own step. It also means the colour chord (section 6) is the one place the bells need extra care, which is why they use chord tones only there. Expect Zen's tonal-clash analysers (tools/ambient_analyze.py) to flag the seconds after a chord change, because of the pad lag by design. Don't tighten the pads to silence the report.

**Per-pass changes** (r = the recipe's restlessness, s = how sparse the tide is now, 0 to 1)
- The pass rests entirely: probability 0.08 + 0.15 r + 0.15 s.
- One note is replaced with a new step, keeping its slot and velocity: 0.35 r.
- One note moves to an empty slot: 0.25 r.
- The loop grows or thins by one note toward its target count. Target = recipe density × (1 + 0.6 × tide), clamped 0 to 4.
- At r = 0 the loops repeat exactly, apart from chord changes.

**Octave ring.** After a bell note, with probability 0.08 + 0.10 × max(tide, 0), the same note an octave up sounds on the same step at 40 percent velocity. On a sampled vibraphone or celesta it reads as a shimmer, which is a reasonable stand-in for AMB-1's 7 to 50 ms ring.

## 8. Tide: the slow swing between sparse and full

**The curve**
- One tide value per bar, from -1 (sparse) to +1 (full), drawn once per song from its own RNG (trackSeed index 99).
- A new target is picked every 12 to 36 bars, about 50 to 150 s at 70 bpm. The curve eases toward it with a lag of about 8 bars.
- Targets are scaled by the recipe's tide depth.
- The tide is forced at or below -0.5 in the intro and the outro.

**What it moves, all baked in at generation**
- Bell loop target density (section 7).
- The chance a bell pass rests.
- The octave ring chance.
- Bell velocity, ± 15 percent.
- Pad breath peak velocity, ± 10 percent.
- Pulse velocity, ± 25 percent. When the tide is below -0.6 the pulse also takes 2 to 4 bar rests.
- Bass: the chance a chord is skipped rises by 0.2 × sparse.

There is no reverb-send automation in Zudio, so AMB-1's "more reverb when sparse" is left out. It's not worth new playback code for phase 1.

## 9. Structure: entry, body and the unwinding ending

**Length.** The same as base Ambient: triangular 180 to 315 s, peak 240 s (the frame draw is kept). Evolve mode already stretches a song by almost half. At this length the chord journey has 4 to 7 chords, so drift values in section 5 are a little shorter than AMB-1's.

**Sections.** An intro of 8 bars, one body section A, and an outro of 12 bars, using the existing section labels. That keeps Evolve's aSectionBars arithmetic working unchanged.

**Entry: the garden grows in**
- Pads: bar 0, voice 1 first, the others joining over the next breaths as their staggered cycles come round.
- Lead 1: a random bar from 2 to 4.
- Bass: bar 4, or the first chord change, whichever comes first.
- Lead 2: a random bar from 6 to 8.
- Rhythm: the end of the intro.
- Texture: one Texture loop pass after the end of the intro.
- Drums (pulse): at the first chord change after the intro, at bar 16 at the earliest.

**Body.** The chord journey, tide and per-pass changes do the work. Zen does not run base Ambient's dropout zones, hollow guards, Plan H breath or Plan J strip. Its own rests (silent passes, pulse rests, bass skips) replace them.

**The unwinding ending.** Layers leave in roughly the reverse order they came in, during the outro, which sits on the tonic:
- The pulse stops at the start of the outro.
- Rhythm finishes its pass and stops, then Texture.
- Lead 2 stops about 4 bars later.
- Lead 1 plays one last pass and stops about 3 bars from the end.
- The bass drops 4 bars from the end.
- The pads end on a "held breath", an idea taken from AMB-1's freeze. At the start of the final 6 bars all four voices take the tonic chord and hold without breathing out to the last bar. The existing Ambient outro master fade then carries the reverb tail away.

The song is then trimmed to its last pad note plus 2 bars, the way Ambient Piano trims, so it never ends on dead air.

## 10. Rule IDs and track rules

New IDs continue each Ambient track family. Ambient Piano used AMB-PADS-007 to 010, so the numbers below are free. Each rule is named for an Eno work it descends from, as homage rather than copy.

### Pads

**AMB-PADS-011 Airports Breath** (weight 0.55). Four voices, each with its own breath cycle.
- Cycle length = recipe base (10 to 16 s) × voice factor 1.0, 1.23, 1.47 or 1.71 × random 0.85 to 1.15, re-drawn each breath. The factors are ours, not AMB-1's.
- One breath is one note. It lasts 88 to 92 percent of the cycle, followed by silence for the rest. (AMB-1's breath rests only for the last 10 percent of its cycle; an earlier draft here used 70 to 80, which left more gaps and a less continuous bed. Changed 2026-11-09 after Zack found the AMB-1 drone survives with the bass turned down.)
- Voices start staggered: voice 1 at bar 0, the others at random offsets within their first cycle.
- Each breath takes its voice's chord note from a nearest-movement voicing of the chord in force at its start. Voicing: try every voice-to-tone assignment, cost = total semitone movement, plus a heavy penalty for two voices on one note. Register 48 to 76.
- At a chord change, a voice holding a tone the new chord shares carries on to the end of its breath. A voice holding a tone the new chord lacks is cut 1 bar after the change and starts its next breath on its new note.
- Velocity = 46 + 30 × breath peak, where the peak is random 0.6 to 1.0 times the tide factor.
- Source: Music for Airports 2/1 (voices on unequal loops).

**AMB-PADS-012 Plateaux Bloom** (0.25). Three voices with longer breaths (16 to 24 s base). The top voice takes the chord's ninth instead of a chord tone when the chord allows it (not on the half-diminished chord, which is never chosen anyway). Prefers Rhodes colour.
- Source: The Plateaux of Mirror (with Harold Budd).

**AMB-PADS-013 Neroli Hold** (0.20). A low root-and-fifth pair held for each whole chord window and re-breathed at each change. A single high chord tone breathes in only during the middle of each window, on a 20 to 30 s breath. The sparsest pad.
- Source: Neroli.

### Lead 1 (bell loop A)

All Lead 1 rules run through the pass unroller with the Lead 1 loop length.

**AMB-LEAD-011 Airports 1/1 Loop** (0.50). The plain bell loop: 1 to 4 notes, velocity 50 to 80, register 60 to 84, per-pass changes.
- Source: Music for Airports 1/1.

**AMB-LEAD-012 Discreet Fragment** (0.30). The loop holds a 3- or 4-note descending scale fragment in adjacent slots, starting on a chord tone, plus empty space. The per-pass changes can only replace one fragment note or drop the last one, so the fragment's shape survives. Velocity falls along the fragment, 72 to 48.
- Source: Discreet Music (an Eno line fed into delay). The fragment shape is generated, not quoted.

**AMB-LEAD-013 Becalmed Bell** (0.20). One or two notes per loop, held 6 to 10 steps. Octave ring at double the usual probability. Register 67 to 88.
- Source: Becalmed, from Another Green World.

### Lead 2 (bell loop B)

**AMB-LEAD-014 Airports 1/2 Answer** (0.60). A second loop pitched lower (55 to 76), velocity 42 to 70. Its slots avoid steps where Lead 1 has a note in the same pass, so the two loops answer each other rather than collide.
- Source: Music for Airports 1/2.

**AMB-LEAD-015 Apollo Echo** (0.25). Each pass, Lead 2 restates up to two of Lead 1's pitch classes from that pass, a beat and a half to three beats later, an octave lower, at 60 percent velocity. Built from Lead 1's generated events, the same way AMB-LEAD-005 is seeded from Lead 1.
- Source: Apollo: Atmospheres and Soundtracks.

**AMB-LEAD-016 Silent** (0.15). Lead 2 rests for the whole song.

### Rhythm (bell loop C, the high glass)

**AMB-RTHM-007 Lux Glass** (0.65). An 11-beat loop, register 72 to 96, 1 to 3 short notes (2 to 4 steps), velocity 35 to 60, octave bias from the recipe.
- Source: Lux.

**AMB-RTHM-008 Reflection Drops** (0.35). One pitch, the chord's fifth, at two or three slots of the loop. Each slot fires with its own probability (0.4 to 0.8) each pass, so the dripping never quite settles. Velocity 30 to 52.
- Source: Reflection.

### Texture (bell loop D, the low bell)

**AMB-TEXT-012 Pearl Pedal** (0.50). The upper half of the drone (section 18): the tonic and fifth held as a pedal under every chord. Source: Against the Sky, from The Pearl (with Harold Budd), where two tones sound through every chord of the piece and only a third voice moves (section 19).

**AMB-TEXT-011 On Land Bell** (0.35). A 29- or 31-beat loop, one or two notes, register 48 to 67. The root or fifth only, velocity 40 to 60, long rings. In practice it reads like a distant tower bell.
- Source: On Land.

**AMB-TEXT-000 No texture** (0.15). Reused unchanged.

Field songs (AMB-PADS-014) use Texture for one field voice, so the Texture rule is not rolled for them.

Audio textures stay unique to base Ambient. Zen never uses them, whatever its percussion.

### Bass

The Zen bass is the lower half of the drone. Section 18 has the continuity rules both bass rules follow: no gaps, overlapping joins, glides on small steps, and fades only at the edges.

**AMB-BASS-007 Airports Root** (0.40). One root per chord window, nearest MIDI 43 (register 36 to 52), velocity 54 to 62.
- Each note is held until 1 beat after the next note starts, so the joins overlap and there is never a gap. (The earlier draft ended each note a bar early, which would have left a hole at every chord change.)
- At the window's midpoint, with the recipe's fifth chance (0.2 to 0.5), it moves to the fifth for the rest of the window, overlapping in the same way.
- It sits a window out with probability 0.06 + 0.25 × sparse (AMB-1 uses restlessness × 0.3 + 0.25 × sparse). It never sits out the first or the last window.
- Source: Music for Airports 1/1 (the held bass).

**AMB-BASS-008 Plateaux Octave Root** (0.25). The root doubled at the octave, as a two-note pair, held for the first 2 bars of the window. Then the upper note alone is re-struck for the rest of the window, overlapping the pair by 1 beat. It is fuller than 007 and reads better on small speakers. The fifth move and the sit-out chances are as in 007.
- Source: Not Yet Remembered, from The Plateaux of Mirror (with Harold Budd). In the fan file the bass is a root octave pair held about 2 bars, then its upper note re-struck. That low bed sounds about 95 percent of the piece (section 19).

**AMB-BASS-001 Loscil drone** (0.15). Reused unchanged; it follows the Zen chord plan through the tonal map. Zack's ruling (2026-11-09): keep it for now and drop it later if Zen sounds too much like base Ambient.

**AMB-BASS-000 No bass** (0.20). Forced when the recipe has no bass (Departure Lounge). Those songs lean on the Texture pedal for their low bed: its weight rises to 0.75 there.

### Drums (the pulse)

"Pulse" here means a very quiet drum part: a soft kick, a closed hi-hat and an open hi-hat, each repeating its own short pattern so they drift against each other. It is felt more than heard, well below base Ambient's hand percussion. Many Zen songs have none.

**AMB-DRUM-005 Garden Pulse** (used only when the recipe has a pulse). Three Euclidean patterns, each on its own cycle:
- kick (GM 36), 16 steps, 2 or 3 hits;
- closed hat (42), 12 steps, 2 to 4 hits;
- open hat (46), 7 steps, 1 or 2 hits.

Hit counts come from the recipe. Start rotations are random.
- Each bar, with probability 0.2 × restlessness, one pattern rotates by one step or gains or loses one hit. A pattern stays within one hit of its home count and never drops below one.
- Velocity: kick 34 to 48 on its first hit and 26 to 38 otherwise; hats 20 to 36. Scaled by the tide.
- Rests of 2 to 4 bars when the tide is low (section 8).

**AMB-DRUM-000 No percussion.** Reused, for recipes without a pulse.

Recipes with a pulse: Concourse, Afternoon Light, Late Shuttle and Slack Water (very light, at about 70 percent velocity, after Zack's note on AMB-1's Tides), about 52 percent of Zen songs. Section 17 had three recipes and about 40 percent; this restores a fourth.

## 11. Instruments

Pools are shared by all Ambient substyles. New entries are appended to the end of each Ambient track pool, so existing indices don't move, and each addition touches all four places: poolNames, poolPrograms, instrumentPickPool and instrumentPickPoolStatic.

**Seed safety.** instrumentPickPoolStatic for Ambient currently returns every index in the pool. After the additions it must return the original indices for base Ambient, so existing seeds pick exactly what they pick today, and the Zen pick list for Zen songs. Ambient Piano keeps its Stereo Piano pin. The picker still shows the whole pool for every Ambient song.

**Zen pick lists** (★ = new to the Ambient pool; all are in Zudio.sf2)
- **Lead 1:** Vibraphone 11 ★, Tine Electric Piano 4 ★, Echo Drops 102 ★, Synth Mallet 1098 ★, Harp 46.
- **Lead 2:** Celesta 8 ★, Marimba 12 ★, Kalimba 108 ★, Synth Chime 11098 ★, Harp 46.
- **Pads, Voices colour:** Concert Choir 52 ★, Synth Voice 54 ★, Space Voice 91 ★.
- **Pads, Rhodes colour:** Tine Electric Piano 4 ★, Warm Pad 89 ★, Halo Pad 94.

  The recipe's colour bias picks the group (Concourse, Departure Lounge and Afternoon Light lean Rhodes; Choir Loop and Slack Water lean Voices; the rest are 50/50). Then one instrument is drawn from that group.
- **Rhythm:** Glockenspiel 9, Celesta 8, Tinker Bell 112, Synth Chime 11098 ★, Tinkling Bells 11008 ★.
**Long-sustain rule (Zack, 2026-11-09).** Any instrument used for Bass or for a drone (the Texture pedal) must sustain for a long time without dying away. If a candidate doesn't, it stays out of the Zen audition lists. Checked against Zudio.sf2 on 2026-11-09 by reading each preset's zones (loop mode, sustain level, decay): all candidates below loop in every zone, hold at or within about 2 dB of full level, and decay over 1 s or more. That check is a floor, not a verdict: a looped sample can still sound static or thin, which is why Drift (section 12) is part of the design and why Zack auditions by ear.

Failed the check, but **kept in for the audition at Zack's request** (2026-11-09, "Cello has decent sustain"): **Cello 42**. Only 39 of its 129 zones loop, and the other 90, including the whole low register from key 21 to 52, are 0.2 s one-shot samples, so on paper a held cello note dies almost at once. Zack's ear decides. If a held low Cello note does die away on the bass, drop it from the Zen list. It is already in base Ambient's Bass pool, which doesn't change.

- **Texture, pedal (AMB-TEXT-012)**, seven to audition, all pass: Warm Pad 89 ★, Fantasia 88 ★, Tonewheel Organ 16 ★, Sine Wave 8080 ★, Choir Aahs 52, Bowed Glass 92, Strings 49. The last three are already in the Ambient Texture pool.
- **Texture, bell (AMB-TEXT-011):** Bell Tower 11014 ★, Carillon 9014 ★, Vibraphone 11 ★, Church Bells 8014 ★ (already in the Rhythm pool, new to Texture).

  The Texture pick list depends on the rule rolled: the pedal draws from the pedal list and the bell from the bell list.
- **Bass**, six to audition: Sine Wave 8080 ★, Fretless 35 ★, Synth Bass 101 1038 ★, Tonewheel Organ 16 ★, Voice Oohs 54 and Cello 42 (the last two already in the Ambient Bass pool). All pass the sustain check except Cello, which is in on Zack's say-so. Equal weights. Sine Wave is AMB-1's bass timbre (a sine with a sub-octave and a little second harmonic), but Zack is sceptical that a bare looped sine holds interest, and its sample is a single cycle, which is as static as a sound gets. It stays in for the audition and relies on Drift and tremolo. One slot is free under the seven-instrument cap: fill it after checking more synth basses for sustain (Pulse Bass 11039, Mean Saw Bass 12038, Synth Bass 1 and 2) if the five don't satisfy.
- **Drums:** Brush Kit 40 (Concourse, Afternoon Light) and Percussion Kit 0 (Late Shuttle, Glasshouse).

Not available in the soundfont: Tubular Bells, Music Box and Violin. Bell Tower and Carillon stand in for tubular bells.

**Gain trims.** Each new entry probably needs a trim in PlaybackEngine.setProgram after listening (Tine Electric Piano and Synth Voice especially). These are set by ear during tuning.

## 12. Effects

All of these go in a Zen branch of PlaybackEngine.setAmbientMode, keyed on a cached isAmbientZen, plus the chip defaults in TrackRowView.applyDefaultEffects and AppState.restoreDefaultEffects.

**Reverb**
- The large bus gets the .largeHall2 preset in Zen (base Ambient uses .largeRoom there, for Texture only). Pads, Lead 1, Lead 2, Rhythm and Texture send to the large bus. Bass and Drums stay on the small .mediumHall bus.
- Sends: Pads 75, Lead 1 68, Lead 2 68, Rhythm 70, Texture 55, Bass 10, Drums 35. The bass is kept almost dry and centred, as in AMB-1 (bass reverb send 0.08 against the pads' 0.6). A dry fundamental is what makes the drone feel solid rather than washed out. The Texture pedal sits between the bass and the pads.
- Known limit: M4A export ignores reverb presets and renders a default room. This is existing behaviour, and it applies to every style.

**Echo, the "two heads"**
- AMB-1's tape loop has two heads, the second at three quarters of the first. Zen spreads that idea across two tracks: Lead 1 echo time = the recipe's echo beats (1.5 or 2), and Lead 2 = 0.75 of that.
- Rhythm uses 1.5 beats; Texture 2 beats; Pads a light 2-beat echo.
- Every time is capped at 2.0 s, AVAudioUnitDelay's maximum.
- Feedback 55 to 65 on Pads and Texture, and 65 to 75 on Lead 1, Lead 2 and Rhythm, with the recipe's echo level. AMB-1's tape echo runs 0.5 to 0.82 (about 0.76 in Afternoon), so each repeat is only about 2 dB quieter and the wash lasts about half a minute. That wash is probably part of the drone. Tune by ear. Low-pass cutoff in the feedback loop: 2600 Hz on the bells and 1800 Hz on the Pads, so each repeat comes back darker. That is the darkening echo, with no new code.
- Wet: Lead 1 45, Lead 2 50, Rhythm 48, Texture 30, Pads 15, Bass 0, Drums 10.
- Late Shuttle uses half the echo time and less feedback (its short echoes).
- Known limit, existing behaviour: echo time is computed once when the song starts.

**Breath and swell on Pads**
- The Ambient per-note boost fade must be off for Zen Pads. It is one ramp per track, and it starts from the current volume. With four overlapping breaths, every note-off of one voice would dip all of them. The breath comes from three things instead:
  - the staggered note timing;
  - the slow attack and release of the pad and choir instruments;
  - the existing pad tremolo chip, slowed for Zen to 0.06 Hz (about a 17 s cycle) at depth 0.30. It is on by default in Zen. This is a new rate value inside the existing tremolo path.
- Bass and Texture use the per-note boost fade only at the edges of the drone (section 18): a 2.5 s fade-in on a note that follows silence, and a 4 s fade-out on a note followed by silence. Notes that join another note play at full level with no ramp, because the fade is one ramp per track and would dip the overlap. Base Ambient keeps its 0.5 s fades unchanged. Today the fade covers only Pads and Bass, so Texture is added for Zen songs only.

**Drift (new effect, Zack's idea 2026-11-09).** A very slow, shallow pitch wander per track, so held notes slowly move out of tune with each other the way AMB-1's pads do (it wobbles each pad up to ±8 cents on random modulators, with no chorus, because a modulated delay on pure tones "reads as pulsing"). The same job tremolo does for the bass in Chill, which keeps a held note from going monotonous, but in pitch rather than volume.
- **How.** It rides the existing vibrato path (PlaybackEngine's 60 fps tick sends MIDI pitch bend, ±200 cents default range, so ±8 cents is a bend of about ±330 in 14 bits). Drift uses a much lower rate and depth, a random start phase per track, and two sine components at unrelated rates added together (for example 0.031 and 0.047 Hz) so the wander never visibly repeats. Depth ±5 to ±8 cents. Rates and phases draw from a fresh trackSeed index, so a seed reloads identically.
- **Why per track.** Pitch bend is per MIDI channel, so every note on one track drifts together. The out-of-tune shimmer comes from different tracks drifting differently, which is one more reason to spread the pad voices and the drone across Pads, Lead 2, Rhythm and Texture, as the plan already allows. Bass and the Texture pedal drift against the pads and against each other.
- **Defaults on:** Pads, Lead 2 when it carries pad or field voices, Texture pedal, Bass. Off for bells and drums, where it would sound like a detuned instrument.
- **Chip.** A new Drift chip in Types.swift beside Vibrato, switchable per track. It is not Vibrato: Vibrato stays at 5.5 Hz and ±12 cents and is unchanged.
- **Where it has to be touched.** EffectType in Types.swift; the 60 fps tick and a startDrift/stopDrift pair in PlaybackEngine; the Zen chip defaults in TrackRowView.applyDefaultEffects and AppState.restoreDefaultEffects (iPhone parity); and the offline export snapshot, which already carries vibratoHz and depth through a time-pitch node at OfflineExport.swift:510. Check by ear that a rate this slow survives the export.
- **Risk.** Too wide or too fast reads as a wobbly, seasick detune. Start at ±5 cents and widen only by ear. Base Ambient and Piano never turn it on, so they are untouched.
- **Not a substitute for tremolo.** The slow pad tremolo already in the plan (0.06 Hz, depth 0.30) stays. Drift moves pitch, tremolo moves volume, and the bass gets a very light tremolo as well (rate 0.05 Hz, depth 0.12), which is a tweak inside the existing path.

**Filter sweep.** On for Pads in Zen, using the existing Ambient Pads range (1500 to 7000 Hz). The period is slowed from about 28 s to about 45 s.

**Auto-pan.** On for Rhythm in Zen at one sweep per 8 bars and depth 0.4. Its glass bells drift across the field, a stand-in for AMB-1's wandering echo heads.

**Static pans.** Lead 1 -0.45, Lead 2 +0.35, Pads 0, Rhythm +0.5 (centre of its auto-pan), Texture -0.30, Bass 0, Drums 0. These follow AMB-1's spread of bells left and right.

**Chip defaults**
- Pads: space, tremolo, sweep.
- Lead 1: delay, space.
- Lead 2: delay, space.
- Rhythm: delay, space, pan.
- Texture: delay, space.
- Bass: reverb.
- Drums: reverb.

**Left out.** Automatic global filter sweeps (too dramatic for this style), reverb-send automation, and echo-cutoff automation over time.

## 13. Evolve mode and track regeneration

**Evolve.** Without a Zen branch, Evolve would fall into the generic Ambient path and bring in base Ambient lead rules and instruments. Zen gets its own pass builder, buildAmbientZenPass, alongside the Piano special case in preGeneratePassContent.

- **Pass 1: new bells.** New Lead 1 and Lead 2 rules, drawn from the Zen rules with the current ones weighted down. New instruments from the Zen pick lists, excluding the current ones. The mode shifts by one note (section 16), and the pass gets its own short chord walk (32 to 40 bars) in the shifted mode, starting and ending on the tonic. Log: "Evolve: new bells", the one-note shift, and the new rules.
- **Pass 2: new pads and glass.** New Pads and Rhythm rules and instruments. Pad colour flips (Rhodes to Voices or the reverse) in 50 percent of passes, which is the most audible change Zen can make. The mode returns home. Bass and Drums are filled only if they were silent in the body, as the generic path does.
- **Instrument swaps** use evolvePickIndex restricted to the Zen pick list for each track.
- **Kept across passes:** the key, mode, recipe, loop lengths, tide depth and the drone (the bass rule and the Texture pedal), so Evolve feels like the same garden moving on over the same ground. In pass 1's one-note mode shift, the pedal keeps the tonic and its clash guard drops the fifth if the shifted note sits a semitone from it.

**Per-track regeneration** (regenerateTrack). A Zen branch calls the Zen generator for that one track, using the song's stored recipe, chord plan and tide. The other tracks are unchanged. Regenerating Lead 1 re-derives an AMB-LEAD-015 Lead 2 only if Lead 2 is regenerated too. The Lead 1 events it reads are the current ones.

## 14. Plumbing: every place that changes

**New files** (each under about 600 lines)
- `Generation/Ambient/AmbientZenRecipes.swift`: the eight recipes and the recipe roll.
- `Generation/Ambient/AmbientZenHarmony.swift`: the chord journey, chord tones and voicing.
- `Generation/Ambient/AmbientZenLoops.swift`: the pass unroller, per-pass changes, the tide, and the Lead, Rhythm and Texture rules.
- `Generation/Ambient/AmbientZenTracks.swift`: Pads, Bass, the pulse, structure and entry/exit.

**Shared files, small guarded branches**
- **SongGenerator.generateAmbient:** the Zen check after the piano check, then an early return into generateAmbientZen. Also the forced["Zen"] entry and the trim.
- **SongGenerator.buildAmbientLog:** a Zen style line ("Ambient Zen – N bpm"), a recipe line, one line per chord change, and rule descriptions for the new IDs.
- **SongGenerator.regenerateTrack:** the Zen branch (section 13).
- **SongState:** isAmbientZen: Bool and ambientZenRecipe: String, passed explicitly in the initialiser and in every withXxx() copy method (seven sites). displayStyleName gets "Ambient Zen".
- **AppState:**
  - persistence (substyleName "Ambient Zen");
  - the Evolve branches at the five sites that test isAmbientPiano;
  - instrumentPickPoolStatic (section 11);
  - restoreDefaultEffects (iPhone chips).
- **PlaybackEngine:**
  - cachedIsAmbientZen;
  - the setAmbientMode Zen branch;
  - turning off the per-note Pads fade in Zen, and the longer Bass fade;
  - the Zen tremolo rate, the slower pad sweep, and gain trims.
- **TrackRowView:** applyDefaultEffects Zen defaults, and the Drift chip. No picker changes beyond the new pool entries.
- **Types.swift (EffectType) and the Drift effect:** section 12.
- **Pools:** the four instrument places, per section 11.

**Texture as MIDI: the separation already exists** (checked in code 2026-11-09). An Ambient song's Texture is audio only when SongState.ambientAudioTexture is non-nil. Every audio path keys on that one field:
- AppState skips the MIDI program load for Texture only when it is set (AppState.swift:1068).
- The Texture picker lists the audio files only when it is set (TrackRowView.swift:73).
- The waveform lane replaces the MIDI lane only when it is set (TrackRowView.swift:211).
- The Texture effect chips switch to the audio set only when it is set (TrackRowView.swift:432).
- The audioTexture.start calls in AppState run only with a non-nil file.

Base Ambient's MIDI texture rules (AMB-TEXT-001 to 003) already run this way. So Zen needs no Soho-style pool flag: it keeps ambientAudioTexture nil and Texture behaves as an ordinary MIDI track. Chill Soho needed its isChillSoho pool switch because Chill's Texture has no MIDI pool at all; Ambient's has one, and the Zen entries are appended to it. Three Zen paths must never set the field:
- the Zen generator;
- buildAmbientZenPass in Evolve, because the generic Ambient pass can roll an audio texture;
- the Zen branch of regenerateTrack for Texture, because AMB-TEXT-005 to 010 are audio.

Moving from a base Ambient song with an audio texture to a Zen song goes through the normal song load, which stops the audio player when the new state's file is nil (AppState.swift:1786). Confirm that by ear on Mac and iPhone in step 4 of the build.

**Bass glide.** Superseded by section 20.5: a legato bend on one held note, with a new Playback/ZenBassGlide.swift, a bend range of 12 set by RPN 0 for Zen only, and one place that sums glide and Drift. It borrows startBassSlide's ramp pattern but not ChillBassSlides' map or its ±2 range.

**Not touched:** AmbientLoopTiler, every base Ambient rule, every Ambient Piano function, the dropout, hollow-guard and Plan G/H/J code, and the frame generator.

**A choice worth noting.** isAmbientPiano is a Bool tested at about 35 sites. Turning it into an enum would be tidier, but it is a refactor of working Piano code. This plan adds a second Bool and leaves Piano alone.

## 15. Build order and checks

1. **Baseline.** Fingerprint a sample of Ambient seeds (base and Piano) with SWIFT_DETERMINISTIC_HASHING=1, before any change.
2. **Plumbing, harmony and the drone.** The flag, roll, persistence, log, recipes, the three harmony plans, structure, Pads, Bass (AMB-BASS-007 and 008, with the glide and edge fades) and the Texture pedal (AMB-TEXT-012). Stop here for Zack to listen, with no bells yet: start with Afternoon Light against AMB-1's Afternoon preset, and audition the bass and pedal instruments. Does the drone feel continuous? Does the journey travel and come home? If the drone doesn't work, rethink the rest of the plan before building more.
3. **Bell loops.** The pass unroller, the tide, then the Lead 1, Lead 2, Rhythm and Texture rules. Listen for audible phasing and for loops that change without wandering.
4. **Pulse and effects.** AMB-DRUM-005, the setAmbientMode Zen branch, chip defaults on Mac and iPhone, the pools and pick lists.
5. **Evolve and regeneration.**
6. **Fingerprint check.** Every base Ambient and Piano seed outside the Zen share must match the baseline exactly. Run it at release shares, not the 80 percent testing share.
7. **Device.** iPhone and iPad listen, mainly the Pads tremolo and the longer fades on iOS.

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
- **A new pad rule for the static approach:** AMB-PADS-014 Airports 2/1 Field (below). It gives Zen both of Eno's harmonic modes.
- **Evolve answer.** Not a key change or the relative mode. Instead, a one-note shift in the 1/1 manner:
  - Evolve 1 changes one scale note: Ionian to Mixolydian (flat 7), Ionian to Lydian (sharp 4), Mixolydian to Ionian, Dorian to Aeolian (flat 6), Aeolian to Dorian (raised 6), Lydian to Ionian. Pentatonic songs add the missing note instead, turning major pentatonic into Ionian.
  - Evolve 2 returns to the home mode.
  - Log: "Evolve: one note shifts, D Ionian to D Mixolydian".
  - It is subtle, and it is a move Eno actually made.

**AMB-PADS-014 Airports 2/1 Field** (Choir Loop recipe only, and 30 percent of Slack Water songs). No chord windows. The song has one pitch field: 5 to 7 pitches drawn from the mode's tonic chord plus its 9th, 11th or 13th. The Choir Loop recipe uses the field in place of the journey.
- **Tracks:** each pitch is one voice on its own loop. Voices are spread across Pads (two or three voices, Concert Choir), Lead 2 (Synth Voice), Texture (Space Voice or Warm Pad) and Rhythm (one high voice, Warm Pad), so each instrument breathes on its own.
- **Timing:** loop lengths 16 to 32 s, in steps, all different, none a multiple of another. Note length 30 to 50 percent of the loop. Entries staggered over the first 15 to 20 s.
- **Swell:** each voice is alone on its track, so the per-note boost fade can shape it properly. This needs the fade extended from Pads and Bass to Lead 2, Rhythm and Texture, for Zen songs only. The ramp rises over half the note and falls over half, as in the recreation.
- **Bass:** AMB-BASS-007 holds the field's root.
- **Ending:** voices drop out one by one in the outro.

## 17. Open questions (answered 2026-11-09, pending Zack's approval)

The tiebreaker is Zack's: Zen should sound more different from base Ambient, not more similar.

1. **Colour chord: keep it, 30 percent of journey songs, middle third only.** Not Yet Remembered (The Plateaux of Mirror) is the one corpus piece with a long-form journey. It does exactly this: two passes of its home cycle, a departure in the middle with chromatic bass steps (B, Bb, Eb, D) outside the key, then home again for the rest. Base Ambient never leaves its scale. Cycle and field songs stay diatonic, as The Big Ship and Against the Sky do.
2. **Pulse: four recipes, about 52 percent, the fourth very light.** Concourse, Afternoon Light and Late Shuttle keep it, and Slack Water gets a very light one (revised 2026-11-09 after Zack said AMB-1's Tides has very light percussion that works). Glasshouse loses it. AMB-1 has a pulse in five of its eight pieces (Garden 40, Afternoon 25, Night Bus 60, Glass 20, Tides 35), so this is still fewer than AMB-1. Only one corpus piece has drums (The Big Ship), and the Plateaux and Pearl pieces have none. AMB-1's Afternoon, the reference, does have a pulse. The tiebreaker barely applies, because base Ambient already has hand percussion, so the pulse isn't what sets Zen apart; the drone is.
3. **The 2/1 field: keep it narrow, about 16 percent** (Choir Loop plus 30 percent of Slack Water). On reflection the field is the plan's least distinctive option. Base Ambient already runs co-prime loops over one to three held windows, which is close to a static field. The corpus also favours movement in its long pieces: The Big Ship cycles and Not Yet Remembered journeys. Against the Sky is static, but its lesson is the held common tones, and that now lives in the Texture pedal for most Zen songs. The share freed goes to the new Big Ship cycle (section 6).
4. **Eno MIDI: done** (section 19). Three new rules came out of it: AMB-PADS-015 Big Ship Cycle, AMB-BASS-008 Plateaux Octave Root and AMB-TEXT-012 Pearl Pedal.

**Zack's rulings, 2026-11-09**
- The bass glide: first ruled an off-by-default experiment (the Chill slides sounded clumsy), then, after Zack heard AMB-1's long slides, accepted as part of the design if it can be done slowly (section 20.5).
- Where the rules and the AMB-1 code disagree, the rules follow the code, inside our architecture (section 20).
- AMB-BASS-001 Loscil drone stays in Zen for now at 0.15. Drop it if Zen sounds too much like base Ambient.

## 18. The drone: the continuous low bed

**What AMB-1 actually does** (read from amb.c on 2026-11-09; ideas only). There is no separate drone voice. The steady low bed is three things:
- **The bass never stops.** It is one sine voice with a sub-octave (fundamental 0.75, sub-octave 0.45, second harmonic 0.12), at MIDI 36 to 47.
  - It follows each chord root.
  - Its amplitude is never re-triggered: only the pitch glides (about 0.15 to 0.5 s) to the new root.
  - It fades in over about 2.5 s and out over about 4 s, and only when it sits a chord out or the piece stops.
  - It has no LFO, no filter and no detune.
  - It is mixed almost dry and centred.
- **The pads overlap.** Four voices breathe on unequal cycles (10 to 19 s in Afternoon), each silent about 10 percent of its cycle, staggered so their rests rarely line up.
- **A long plate and tape echo** fill whatever gaps remain.

So the steadiness comes from continuity: the amplitude never dips at chord changes.

**Zack's listening test (2026-11-09).** With AMB-1's Bass turned down in the Afternoon preset, a separate long-running drone is still clearly there. So the bass is not the drone. The likely sources are the pad bed (four voices that rest only 10 percent of their cycle, through a dark low-pass at about 1.6 kHz) and the reverb and tape-echo wash behind it (plate decay about 0.9; tape feedback about 0.76). Two further tests are proposed to Zack: pads to 0 with the bass still down, then reverb and echo to 0 as well. Until they are run, treat this as a hypothesis. The consequences, already applied above: Zen pad breaths cover 88 to 92 percent of their cycle, and bell echo feedback rises to 65 to 75. The bass and the Texture pedal below are supporting layers, not the core. A real per-voice swell (AMB-1 rises for about 4.5 s and falls for about 4 s) can't be done on a shared track with sampled pads. Listen first with slow-attack pads (Warm Pad and Strings attack in 0.8 s). If the bed still isn't continuous, put the swelling voices on separate tracks, or use the swell presets below.

**What the AMB-1 code shows about the pads** (amb.c, read directly 2026-11-09; the Afternoon numbers use its own table: Swell 50, Bright 60, Size 75, Rhodes pad). There is no hidden drone voice anywhere in the file. The drone is the pad bed, made of these pieces:
- **Near-pure tones.** The Rhodes pad is one FM sine carrier plus a 12 percent second harmonic, with a mild bloom. Through the pad bus's 12 dB low-pass (about 2.4 kHz at Bright 60) it is effectively a sine. So pure tones do work in AMB-1, but only because of everything below.
- **Slow swells, not notes.** Each voice's volume follows one smooth shape per breath: a raised-cosine rise over the first 40 percent of the cycle, a hold to 55 percent, a fall to 90 percent, then a 10 percent rest. In Afternoon the cycles are about 10, 12, 14 and 17 s (each re-drawn ±15 percent every breath), so each voice rises over 4 to 7 s and falls over 3 to 6 s. The four voices start staggered, and their rests almost never coincide, so the sum of four crossfading swells is a nearly level bed. There are no note attacks to hear.
- **Common tones hold through chord changes.** A voice whose note is in the new chord carries on to the end of its breath.
- **Each voice drifts in pitch on its own** (up to ±8 cents, with a new random target every 7 to 40 s), and pans slowly around the field, so the sines never settle into a fixed beat.
- **The reverb tail is made of the same pure tones.** Pads send 0.6 to a Dattorro plate with decay about 0.88 (Size 75), and the echo repeats are fed into the plate as well. I estimate its tail at roughly 10 to 20 s, from the decay value and the tank's delay lengths. I did not measure it. Because the source is pure chord tones, the tail is a smooth chord-tone wash with no noisy smear.
- **The tape echo feeds back at about 0.74 here** (0.5 + 0.32 × Size), with each repeat darker than the last.

**Zack's theory, and the code behind it (2026-11-09).** Zack suggests the interest is a chord dynamic between the bass and the pads as they evolve out of time with each other. The code supports it. At a chord change the bass retargets at once and glides to the new root in about 0.2 s (Afternoon's Glide is 15). The pads do not follow. A voice on a note the new chord shares holds it to the end of its breath, which can be 17 s. A voice on a note the new chord lacks fades in about a second and re-enters on its new note, rising over several seconds. Each voice takes its new note only at the start of its own breath. So for the first seconds after every change, a new bass root sounds under pads that are still mostly the old voicing, and then the chord forms, one voice at a time. At the halfway point of a chord the bass may also lean on the fifth, which gives a slash-chord colour under the pads. The two never line up because the pad cycles (10 to 17 s) are unrelated to the chord length (about 30 to 40 s).

**Design principle (new): the bass leads and the pads lag.** The bass changes exactly at the chord change, and the pad voices arrive at their own breath timing. Never quantise the pads to the chord change, and never give the pads a bar-aligned re-voicing. AMB-PADS-011 already works this way (voices take a new note at the start of a breath), and AMB-BASS-007 changes at the window start. Make it the rule for every Zen pad and bass rule, and check by ear for it at the build's listening stop.

**Swell presets, a possible way to get per-voice swell on a shared track.** Zudio's sampler gives each note an attack and release from the soundfont's volume envelope. Cloned copies of Warm Pad, Choir and Strings with an attack of about 4 s and a release of about 4 s (SF2 generators 34 and 38) would swell and fade each note on its own, even with four voices on one track, with no change to the playback code. tools/sf2_copy_presets.py appends presets and keeps every existing byte, so a small sibling tool that copies a preset and overrides those two generators would fit. It would be new, additive data in Zudio.sf2, in a new bank so existing programs don't move. The costs to check by ear: notes arrive late (about 4 s to full level, which suits a chord that forms slowly), and a 4 s release must not leave a tail after Stop or a seek. Not decided; first listen with the existing presets.

**What Zudio can and can't do**
- It can hold notes as long as it likes, overlap them, and choose a pure Sine Wave preset (8080, in Zudio.sf2). Every bass and drone instrument must have long sustain (section 11), and none is relied on to be interesting on its own: Drift and a slow tremolo (section 12) keep a held note moving, because a looped sine is static.
- It can't glide a sampled note over large intervals. The existing bass-slide bend stays inside the default ±2 semitone range.
- Every new MIDI note re-attacks the sample. With a sine or pad timbre and a small overlap, that attack is soft.

**The Zen drone: two layers that never both stop**

*Lower: the bass* (AMB-BASS-007 or 008, section 10)
- Notes overlap by 1 beat at every join, so the bass has no gaps between its entry and its exit, apart from deliberate sit-outs.
- **Joins.** Every root move relies on the 1-beat overlap. On a sine the overlap reads as a soft crossfade.
- **Glide: part of the design, slow and long.** Superseded: this was an off-by-default experiment, until Zack said he hears AMB-1's slides when chords change and is happy to have them. AMB-1's slides last about 0.4 to 2.2 s. See section 20.5 for the legato bend design.
- **Edge fades.** A 2.5 s fade-in on the first note after silence, and a 4 s fade-out before a sit-out and at the exit. No ramps at joins.
- Almost dry (reverb send 10) and centred.

*Upper: the Texture pedal* (AMB-TEXT-012 Pearl Pedal, 50 percent of songs; 75 percent when the recipe has no bass)
- Holds the song's tonic, and the fifth above it in 60 percent of songs, in register 48 to 62. It does not follow the chords. That is the Eno/Budd sound: chords move over a held tone.
- **Re-breathed, not re-struck.** Each note lasts 3 to 5 bars, drawn per note. The next starts 1 beat before the last ends. Velocity 40 to 54, scaled ± 10 percent by the tide.
- **Clash guard.** When a window's chord holds a note a semitone from the pedal's fifth (the #4 or b6), the pedal drops the fifth for that window and keeps the tonic. It does the same for the colour chord. The tonic is never dropped: a seventh or ninth against it is the sound we want.
- Enters at bar 0 with the pads (fade in 2.5 s). In the outro it joins the pads' held breath and ends with them.
- Static pan 0 (the bell rule keeps -0.30). Reverb send 55, light echo (wet 10).

**Why two layers.** The bass gives the AMB-1 motion: the root moves and the bed moves with it. The pedal gives the Eno/Budd stillness: the tonic is always there. Most songs get both, so at any moment at least one low voice is sounding. Departure Lounge has no bass, so the pedal carries it alone.

**Small speakers.** A sine at 65 to 123 Hz all but vanishes on a phone speaker. The pedal an octave or more above and AMB-BASS-008's upper octave make the drone audible there. Check on the iPhone speaker in step 7 of the build.

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

## 20. AMB-1 alignment: the specification the build follows

**The rule (Zack, 2026-11-09).** Where our rules and the AMB-1 code disagree, the rules follow the code, inside our architecture: finite songs, one rule per track, MIDI events on sampled instruments, an early-return branch, no new engine. This section is the specification. Where an earlier section says something different, this section wins, and the earlier text is merged before the build starts (superseded: the chord-walk shape, colour chord, window formula, loop lengths and registers, tide numbers, bass register, glide experiment, Drift's two sines, pulse evolve numbers, and the pad start offsets). "Code" means amb.c as read on 2026-11-09. The clone is at /tmp/claude-502/amb1/repo, and https://github.com/charlesvestal/fm1-amb has it if that folder is gone.

**What the author published.** Only docs/MANUAL.md in the repo (also at charlesvestal.github.io/fm1-amb/manual/), the README and the release notes. Web searches on 2026-11-09 found no blog post, interview or video notes by him, and the firmwares derived from AMB-1 (DUB-1, NACHTFAHRT) have no design notes on it either. The useful lines are:
- "The space is most of what you hear." The echo chain and plate are the largest single element.
- Voices on notes the new chord shares hold to the end of their breath; the others fade out and breathe in again on their new notes.
- The bass is "low, soft and gliding". Glide runs from 20 ms to 1.2 s.
- Pad cycles are "around 11 to 19 seconds"; the bell loops are 13, 17, 23 and 29 beats.
- Sparse means fewer bells, a darker pad, a quieter pulse and more reverb.

It gives no reason for the glide and describes no separate drone voice. A different FM-1 firmware called ZEN-1 exists (listed on MatrixSynth on 2026-11-04, not tied to AMB-1), so "Ambient Zen" could be confused with it. "Ambient Layover" stays on the table.

**Time base.** The code works in seconds, Zudio in sixteenth steps. Draw each duration in seconds, then convert: steps = seconds × bpm × 4 / 60 (at 70 bpm, 1 s is about 4.7 steps). Chord changes snap to the next bar line, as in the code.

### 20.1 Harmony
- **Chord walk.** Code: for seven-note scales the weights by degree are I 4, ii 2, iii 1, IV 3, V 3, vi 3, vii 0.4. For other scale pools the tonic is 3 and every other degree 1.5. Only the current degree is excluded; there is no history. Earlier plan: I 2, V 2, vii 0, a two-back penalty, a middle-third boost, characteristic-chord boosts, V as sus4, a return set, one tonic visit, and the half-diminished chord banned. Decision: the code's weights and nothing else. The one thing finite songs force is that the first window and the last window are the tonic. Everything between is the plain weighted walk. The colour chord is dropped from phase 1, because AMB-1 has none; revisit it after listening. The half-diminished chord is allowed: in Lydian the code gives it weight 3, and Afternoon plays it. V is a plain dominant seventh.
- **Chord tones.** Stacked thirds from the degree, taking scale steps at offsets 0, 2, 4, 6, then 1, 3, 5 until it has enough distinct pitch classes. It wants four tones when the scale has six or more notes (a seventh chord on every degree) and three otherwise. The first tone is the root, the third tone is the fifth.
- **Chord timing.** Code: interval in seconds = 20 × 2 to the power (0.039069 × Drift) × (0.7 + 0.6 × a random 0 to 1), counted from each change, and the change lands on the next bar line. So Drift 10 is about 26 s, 20 about 34 s, 25 about 39 s, 40 about 59 s and 50 about 78 s. Earlier plan: 0.75 to 1.25 and a clamp of 6 to 20 bars. Decision: the code's formula, no clamp. The first window must still cover the intro plus a full window, and the last the outro.
- **Recipe drift values.** Each recipe stores the Drift value. Our seconds map to it as: 26 s is 10, 34 s is 20, 39 s is 25, 59 s is 40, 78 s is 50. The recipes in section 5 become: Concourse 25, Departure Lounge 40, Choir Loop 49, Afternoon Light 20, Late Shuttle 15, Tidewater 40, Glasshouse 25, Slack Water 10.

### 20.2 Pads (replaces the timing in AMB-PADS-011)
- **Cycle.** Seconds = (4 + 0.12 × Swell) × the voice factor (1.0, 1.21, 1.43, 1.67 for voices 1 to 4) × a random 0.85 to 1.15, drawn fresh at every breath. Swell is a recipe value from 40 to 80, so base cycles run from about 9 to 14 s and the voices from about 9 to 27 s.
- **Shape.** Volume rises over the first 40 percent of the cycle, holds at full from 40 to 55 percent, falls from 55 to 90 percent, then rests for the last 10 percent. Each breath has a peak of 0.6 to 1.0.
- **Start.** All four voices start within about 3 s, not spread over a cycle as the earlier plan said. Voice 1 starts at once; the others start (1 minus their start phase) of a first cycle later, with start phases 0.9, 0.82 and 0.95 for voices 2 to 4. The cycles then drift apart by their unequal lengths.
- **MIDI form.** One note per breath, per voice, at velocity 50 + 40 × peak, on the pitch the voice's target holds at the breath start. The note's length depends on the swell ladder (20.3).
- **Chord change.** For each voice that is sounding (inside the first 90 percent of its cycle): if its pitch class is in the new chord it carries on unchanged to the end of its breath, whatever its length. If it is not, its note ends at the change, and its next breath starts 1 s later on its new target, with a freshly drawn cycle at 85 percent of the usual length. A voice that is resting or not yet started simply takes the new target at its next breath start. The pitch class test is by pitch class, not by octave.
- **Voicing.** On each chord change, assign the new chord's tones to the four voices by the nearest-movement permutation (24 of them, cost = total semitone movement) inside MIDI 48 to 77. The code starts the voices at 50, 57, 64 and 71. Its exact cost function (en_voice_lead) was not read, so Zen keeps its own doubled-note penalty from section 10.
- **Arc effect on pads.** The code darkens the pad bus when sparse (cutoff 700 × 2 to the power (0.03 × Bright + 0.6 × arc) Hz, about 2.4 kHz at Bright 60) and blooms the Rhodes as it swells. Zen approximates this with pad velocity ± 10 percent by arc, and nothing else.

### 20.3 Swell: the ladder
The code's voices have no attack or release in the usual sense; their volume follows the breath shape. A sampled note can only follow its soundfont envelope, so the ladder is:
1. **Ladder A, swell presets (preferred).** Cloned copies of Warm Pad, Concert Choir and Strings in a new bank, with attack of about 5 s (generator 34 = 3000 timecents, about 5 s) and release of about 4.5 s (generator 38 = 2600). Note-off at 55 percent of the cycle, so the release supplies the fall; the sound ends near 90 percent. A small tool beside tools/sf2_copy_presets.py clones a preset and overrides those two generators. New presets are additive and in a new bank, so no existing program moves.
2. **Ladder B, existing presets.** Note-off at 90 percent of the cycle. The attack is the instrument's own (0.8 s for Warm Pad and Strings), so each breath is audible as a note rather than a swell.
3. **Ladder C.** If both leave the bed choppy, put the swelling voices on separate tracks with the per-note boost fade.
Build Ladder B first, listen, then try Ladder A. Check by ear that a 4.5 s release leaves no tail after Stop or a seek.

### 20.4 Bass
- **Pitch.** Code: MIDI 36 + the chord root's pitch class (C2 to B2), plus 12 times the bass octave (-1, 0 or +1 per recipe). Earlier plan: the root nearest MIDI 43. Decision: the code's fixed band. This means root moves can leap up to 11 semitones, which the code softens with a slide (20.5).
- **Fifth.** At the halfway point of each window, with probability Fifth percent (20 to 55 per recipe), the bass moves to the chord's third tone (the fifth), as 36 + that pitch class, and stays until the next change. Only when the chord has at least three tones. The fifth can therefore sit below the root. Same as the earlier plan except for the register.
- **Sit-out.** At each change, rest = random 0 to 1 < 0.3 × restlessness + 0.25 × max(minus arc, 0). Earlier plan: 0.06 + 0.25 × sparse. Decision: the code's. Never the first or last window.
- **Fades.** The code's amplitude rises with a time constant of 2.5 s and falls with 4 s, and never restarts at a chord change. Fades apply only at a run's start, at a sit-out and at the end, as already in section 18.
- **Which rules.** AMB-BASS-007 and AMB-BASS-008 follow this. AMB-BASS-001 (Loscil, reused) does not change.

### 20.5 Bass glide: legato bend (Zack, 2026-11-09)
Zack hears AMB-1's slides when chords change and is happy to have them in Zen; they are slow and nothing like a blues bass slide. They are long. The code moves the bass pitch toward its target with a one-pole approach: time constant = 0.02 + 0.012 × Glide seconds. Glide 10 to 45 gives 0.14 to 0.56 s, and the audible slide lasts about three time constants, so 0.4 to 1.7 s (up to 2.2 s at Glide 55), for jumps up to 11 semitones, both up and down. The earlier plan's 0.3 s glide on small steps was wrong on both counts.
- **Design.** One note is struck at the start of a run (the first bass note after silence), and every chord change after that is a pitch bend on that held note, with no re-strike. This is the code's behaviour exactly, and it needs no overlap logic. A run ends at a sit-out or the end of the song. Roots span 36 to 47, so with the struck note as the reference every target is at most 11 semitones away, inside a bend range of 12.
- **The generator** still writes ordinary events, one note per window at the true pitch, so the piano roll, the MIDI export and regeneration are unchanged.
- **The playback transform** (new, Zen only, in the style of ChillBassSlides, a new file Playback/ZenBassGlide.swift): at load, scan the bass events and group contiguous windows into runs. For each run, record the anchor note (the first note) and, per window, the target pitch and the Glide time constant. At playback, the first note of a run strikes normally, the later note-ons and the earlier note-offs are suppressed, and each window start starts a bend ramp.
- **Curve.** bend(t) = target - (target - start) × exp(-t / tau), in semitones, sent every 16 ms over about 4 tau. The existing startBassSlide ramp is a template, using the stepTimerQueue and the schedulerID guard so a stop or seek cancels it.
- **Bend range.** Send RPN 0 on the bass channel at load: CC 101 = 0, CC 100 = 0, CC 6 = 12, CC 38 = 0, then CC 101 = 127 and CC 100 = 127. Set it back to 2 for every other style, so the existing Chill slides keep their range. Whether the sampler honours RPN 0 is not verified; test it in step 2 of the build. If not, fall back to re-struck notes with a 1-beat overlap.
- **Seek and stop.** A seek into the middle of a run starts a new run at that window's own pitch, with no bend. Stop sends the bend back to centre, as the slide code does today.
- **Bend sharing.** Glide and Drift (section 12) both move the bass channel's bend. The engine sums them in one place (semitones from glide + cents from drift) and sends one value.
- **Sustain requirement.** A held note must sustain for minutes. Only the looped, full-sustain instruments qualify: Sine Wave, Fretless, Synth Bass 101, Tonewheel Organ and Voice Oohs. If Cello is the picked instrument, the bass falls back to re-struck notes with the 1-beat overlap and no glide.
- **Export.** M4A export schedules notes itself, and glide is a playback-time ramp, so exports play the re-struck windows with no glide until the export path is taught the ramp. Acceptable for phase 1.

### 20.6 Bells (replaces the numbers in section 7)
- **Loops.** Four loops of 13, 17, 23 and 29 beats, one slot per quarter-note beat, mapped Lead 1 = 13, Lead 2 = 17, Rhythm = 23, Texture = 29. Earlier plan: 13 or 17, 19 or 23, 11, and 29 or 31.
- **Registers.** Each loop has a base note: 72, 67, 79 and 62 for Lead 1, Lead 2, Rhythm and Texture. A note's pitch = the highest pitch at or below the base that has the key's root pitch class, plus the scale step above the chord's degree, plus an octave for each full wrap of the scale, plus the recipe's bell octave, folded into 36 to 103. So Lead 2 is not lower than Lead 1 by much (5 semitones), and the Rhythm loop is the highest. Static pans follow: -0.6, +0.35, +0.7, -0.25. Earlier plan: Lead 1 -0.45, Lead 2 +0.35, Rhythm +0.5, Texture -0.30.
- **Slot contents.** Each slot is empty or holds an offset in scale steps above the current chord's degree. A new offset: 72 percent of the time a chord tone (2 times a random pick among the chord's tones, so steps 0, 2, 4 or 6), with a 30 percent chance of a further octave; otherwise a passing step of 1, 3 or 5. Velocity 50 + a random 0 to 49 percent, scaled to Zen's MIDI range of 40 to 80 for soft bells. Every note is a scale tone. The pitch is resolved against the chord in force at the slot's own beat.
- **Target count.** floor(clamp(Density × 0.05 × (1 + 0.8 × arc), 0, 5) + a random 0 to 1). Density is a recipe value of 30 to 60. Earlier plan: 1 to 4 notes, times (1 + 0.6 × tide).
- **Each pass** (when a loop wraps), in this order:
  1. Add notes until the count reaches the target, or remove random notes until it does. This happens in one pass, not by one note.
  2. This pass is silent with probability 0.15 × restlessness + 0.15 × max(minus arc, 0). Earlier plan had a 0.08 constant too.
  3. With probability 0.7 × restlessness, pick one sounding slot at random. Half the time give it a new offset; the other half, move it to a random slot if that slot is empty (otherwise nothing happens).
- **Octave ring.** After a bell, with probability 0.08 + 0.12 × max(arc, 0), the same note an octave up at 40 percent velocity, on the same step.
- **Ring length.** The code's bell rings for about 4.2 s minus 0.06 s per semitone above middle C, between 1.6 and 5 s, times a per-loop factor of 1.0, 1.35, 0.75 and 1.6. In Zudio the instrument's own decay does this; note lengths are about one beat.
- **Human hand.** The code delays each bell by up to 60 ms. The engine already has a micro-timing hook (beatDelay, used by Chill's Beat Fixup), so this is possible as an option: a deterministic delay from a hash of the step, 0 to 60 ms. Off at first; try it by ear.

### 20.7 The arc (replaces the tide in section 8)
- **Curve.** Value from -1 (sparse) to +1 (full). A new target is picked every 50 to 150 s: random -1 to 1, times (0.6 + 0.4 × random), pushed 0.25 further from the middle in its own direction, clamped to -1 to 1. The value eases toward it with a time constant of 35 s. The effective arc is that value times the recipe's Motion (0 to 1). Earlier plan: 12 to 36 bars and a lag of 8 bars. The code is in seconds, so Zen draws in seconds and converts. Forced to at most -0.5 in the intro and the outro (a finite-song need; the code has none).
- **What the arc moves in the code**, with what Zen does:
  - Bell target count, bell pass rest, octave ring: yes, as in 20.6.
  - Bass sit-out: yes, as in 20.4.
  - Pulse level: factor clamp(1 + 1.3 × arc, 0.3, 1.15); the pulse fades but never goes out. Yes, as velocity.
  - Pad filter and bloom: approximated by pad velocity (20.2).
  - Reverb send: the code raises it when sparse (send times (1 - 0.25 × arc)). Zudio has no reverb-send automation. Not followed in phase 1; consider a slow send-level ramp later.

### 20.8 Pulse (replaces the numbers in AMB-DRUM-005)
- **Patterns.** Three Euclidean patterns: kick on 16 steps, closed hat on 12, open hat on 7. Hits per pattern = (Hits × max + 50) / 100 rounded down, with maxima 5, 7 and 3. At Hits 35 that is 2, 3 and 1. The start rotations are 0, 2 and 3.
- **Each bar:** if a rest is running, count it down; otherwise with probability 0.015 × restlessness start a rest of 2 to 4 bars. Then with probability 0.25 × restlessness pick one of the three patterns at random. If it has no home hits, do nothing. Half the time rotate it by one step either way; otherwise add or remove one hit, staying within one of its home count and at least 1 and at most its length.
- **Velocity.** (0.95 on step 0, otherwise 0.6) + 0.25 × a random 0 to 1, times the pulse arc factor. Swing delays off-sixteenths by the recipe's swing (0 to 25 percent of a step).
- Earlier plan: rotation chance 0.2 × restlessness, rests whenever the tide fell below -0.6. Decision: the code's; rests are rare.

### 20.9 Drift: the code's wander (replaces Drift's two sines in section 12)
- **Rule.** Each track has one slow modulator: every 7 to 40 s (random) it picks a new target from -1 to 1 and eases toward it exponentially, reaching it about halfway through the interval. Pitch offset = 8 cents × Motion × the modulator. So a track's pitch wanders in steps rather than sine waves, and the interval and target are random. Motion is the recipe value (0.40 to 0.95).
- **Per voice vs per track.** The code does this per pad voice. Zudio's pitch bend is per MIDI channel, so Drift is per track; the shimmer comes from different tracks drifting differently (section 12).
- **Also in the code, not followed:** vowel and pan wander on the pads, and a 0.3 percent wow on the echo time.

### 20.10 Space (the author's "most of what you hear")
- **The chain in the code.** Pads send 0.6 and bells 0.85 into three stages: a short stereo Echoplex (160 ms, feedback 0.55, each repeat darker), a tape loop of up to 5.6 s with two heads (the second at 0.75 of the first; with Motion it moves between 0.667, 0.625, 0.5 and 0.375) with feedback 0.5 + 0.32 × Size/100 and each pass low-passed and high-passed, and a Dattorro plate with decay 0.6 + 0.375 × Size/100. The echo outputs are also fed into the plate. The second head slides to a new place every 20 to 60 s with probability Motion, bending the repeats by at most about 14 cents.
- **Gap.** AVAudioUnitDelay tops out at 2 s, so the tape loop shortens to at most 2 s, and per-track delays can't share one tape or one pair of heads. With feedback near 0.75 the wash still lasts well over 10 s, but the two-head pattern and the dotted-half echo (2.1 s at 84 bpm) don't survive.
- **Decision for phase 1.** Per-track delays as in section 12, with feedback raised as already set. Then listen. If the space is thinner than AMB-1's, add a shared Zen echo bus: one AVAudioUnitDelay pair on a bus (head 1 at the echo time up to 2 s, head 2 at 0.75 of it, feedback 0.7 to 0.75, low-pass 2.6 kHz per pass) with the pads and bells sending into it and its output into reverbBusLarge, the way the reverb buses already work. Also audition .cathedral against .largeHall2 on the large bus for a longer tail. Neither is verified.

### 20.11 Recipe values (rounded starting points, to be set by ear)
The values below come from AMB-1's pieces' knob settings, rounded to the nearest 5. They are starting points. Each recipe lists Swell, Motion (as 0 to 100), Evolve (as restlessness), Drift value, Glide, Fifth, bell Density, and the pulse's Hits.
- Concourse: Swell 60, Motion 50, restlessness 0.35, Drift 25, Glide 20, Fifth 35, Density 40, Hits 35.
- Departure Lounge: Swell 55, Motion 40, restlessness 0.30, Drift 40, no bass, Density 35, bells an octave down, no pulse.
- Choir Loop: Swell 70, Motion 55, restlessness 0.30, Drift 50, Glide 45, Fifth 30, bass octave -1, no bell loops except one rare low bell, no pulse.
- Afternoon Light: Swell 50, Motion 55, restlessness 0.45, Drift 20, Glide 15, Fifth 40, Density 55, Hits 30.
- Late Shuttle: Swell 40, Motion 70, restlessness 0.50, Drift 15, Glide 10, Fifth 45, Density 45, Hits 55.
- Tidewater: Swell 80, Motion 85, restlessness 0.40, Drift 40, Glide 40, Fifth 20, Density 30, no pulse.
- Glasshouse: Swell 45, Motion 50, restlessness 0.55, Drift 25, Glide 10, Fifth 30, bass octave +1, Density 60, no pulse.
- Slack Water: Swell 60, Motion 95, restlessness 0.75, Drift 10, Glide 25, Fifth 55, Density 45, Hits 40 (very light, about 70 percent velocity).

### 20.12 What cannot be followed, and what replaces it
- Per-sample pad swell (a smooth volume curve per voice): replaced by the swell ladder (20.3).
- Per-voice pan, vowel and pitch wander: per-track only (Drift, auto-pan).
- Continuous reverb-send automation, the filter bloom and the pad bus darkening with the arc: velocity only.
- Echo tape of 5.6 s with two heads: capped at 2 s; maybe a shared echo bus (20.10).
- Micro-timing by up to 60 ms: optional, by ear (20.6).
- The kick's pitch follows the chord root: a sampled kick can't.
- Freeze (REC): Zen's final "held breath" in section 9 is the nearest equivalent.

### 20.13 The coordination layer and generation order
The code's layers all read one shared state: the current chord, the arc, Evolve. A song in Zudio is generated track by track, so Zen builds that state first, once, and every track reads it. This is the same pattern as TonalGovernanceBuilder, and it fits the architecture.
1. **ZenPlan (built first, from the frame and the recipe).** One value type holding: the recipe; the chord windows (degree, four tone pitch classes, root, fifth, start step, end step); the arc per bar; the bass flags per window (rest, fifth move at the window midpoint); the four pad voices' breath schedules (start step, cycle steps, peak, per breath); the pulse's rest bars; and the bass runs. Built by a new file Generation/Ambient/AmbientZenPlan.swift. Pure function of the seed.
2. **Track generation** reads the plan: Pads and Bass first, then the four bell loops (the pass unroller walks the chord windows from the plan), then the pulse.
3. **ZenCoordinator.finalize, after all tracks, before trimming.** It does the work that needs finished events from several tracks:
   - Lead 2's AMB-LEAD-015 Apollo Echo reads Lead 1's generated events.
   - The Texture pedal's clash guard (section 18) reads the plan's windows to drop the fifth for chords that put a note a semitone from it.
   - It orders the outro's unwinding (section 9) across the tracks and trims the song to its last pad note plus 2 bars.
   - It marks the bass runs for the playback transform (20.5).
4. **No harmonic filter.** Zen must not run HarmonicFilter, ArrangementFilter or DensitySimplifier, because they would cut the overlap between the bass leading and the pads lagging. Check that the Ambient early-return path never calls them (the Ambient Piano branch returns before them; confirm for Zen).
5. **Not a post-generation quantiser.** Nothing snaps the pads to chord changes. The lag is the point.

### 20.14 Determinism
Zen draws come from separate streams so one track's draws can't shift another's: ZenPlan uses fresh trackSeed indices (tide 99 as in section 8, chords 98, pad breaths 97, bass flags 96, pulse 95), and each bell loop draws from its own track RNG. No Dictionary or Set order feeds a draw. Zen's reload from a seed is exact, and base Ambient and Piano are unchanged (the fingerprint check in section 15).

### 20.15 Build map, additions to section 14
- New: Generation/Ambient/AmbientZenPlan.swift (20.13) and Playback/ZenBassGlide.swift (20.5).
- PlaybackEngine: the RPN send at load, the glide ramp, and one place that sums glide and Drift into the bass channel's bend.
- Types.swift: the Drift chip (section 12).
- tools: a sibling of sf2_copy_presets.py for the swell presets (20.3), only if Ladder A is used.
- Check in build step 2: that the sampler honours RPN 0; that a held Sine Wave note sounds for minutes without clicking or fading; how the run restarts after a seek; that Stop leaves no release tail.

### 20.16 For Zack
- **MPL and the numbers.** Following the code now means using AMB-1's probabilities, weights and time constants, as functions written fresh in Swift, which keeps the "ideas only, no code" ruling. The recipe numbers in 20.11 are rounded from its pieces. Say so if you would rather change them to your own.
- **Glide on downward moves.** The Chill memory says only upward slides sound like slides. AMB-1 glides both ways and you like it. The plan follows the code.
- **Ambient Layover.** Because of ZEN-1, keep the rename option open.

## 21. Reference links

Read in this order for AMB-1: the manual first (it is short and is the only design writing the author published), then the code.

**AMB-1 (Charles Vestal, MPL-2.0)**
- Repository: https://github.com/charlesvestal/fm1-amb
- The manual, on GitHub: https://github.com/charlesvestal/fm1-amb/blob/main/docs/MANUAL.md
- The manual, published: https://charlesvestal.github.io/fm1-amb/manual/. Worth reading: section 5 "The garden", section 6 "The pieces", the pages in section 7 (Pad, Bells, Bass, Pulse, Space), and the parameter table in section 11.
- The engine: https://github.com/charlesvestal/fm1-amb/blob/main/app/dsp/amb.c. The line numbers below are from the copy read on 2026-11-09 and may have moved:
  - the eight pieces' table, lines 36 to 50, and the Drift-to-seconds formula, line 86;
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
- ZEN-1, a different firmware with a name close to ours: https://www.matrixsynth.com/2026/11/fm-1-zen-1.html

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
