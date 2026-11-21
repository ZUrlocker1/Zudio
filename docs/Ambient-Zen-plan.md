# Ambient Zen — substyle plan (simplified)
Copyright (c) 2026 Zack Urlocker

*Status: plan, simplified 2026-11-14 and revised the same day with the harmony and clash rules and the Zudio implementation map. No composed phrases: the bells use AMB-1's loop code and scale approach (Zack, 2026-11-14). Revised 2026-11-20: no intro, swell presets as SF2 copies. Phase 1 started 2026-11-20 (Zack's go-ahead). The full 2026-11-09 plan, with the AMB-1 code reading, the Eno research and every number, is kept in [Ambient-Zen-plan-old-2026-11-09.md](Ambient-Zen-plan-old-2026-11-09.md). Use it as a reference, not as the spec. Where the two disagree, this plan wins.*

**Contents**

1. What Ambient Zen is
2. Why the plan was simplified
3. Ground rules
4. The ZenPlan: one picture of the song
5. Harmony: modes, chords and the journey
6. No clashes: the rules every track obeys
7. Phase 1: the bed (chords, pads, pedal, bass, space)
8. Phase 2: the bells and the swell
9. Phase 3: variety
10. On the shelf
11. How it maps onto Zudio
12. Checks

---

## 1. What Ambient Zen is

A third Ambient flavour beside base Ambient and Ambient Piano: a "sounds like" homage to AMB-1 (Charles Vestal's generative firmware for the M-Vave FM-1), and through it to Eno's Music for Airports. It is not an exact emulation.
But it must have the key characteristics which we can learn from the manual and from the source code. We want 
soothing, evolving background music that is pleasant and ever changing.  We want the rich underlying drones 
of bass and pads. We want the elegant shifting of chord tones across instruments. We want the randomness of 
bells and similar sounds so that it is captivating and beautiful as the original AMB-1. 
However, since Zudio does not have dials, we will somewhat randomly assign certain values so that there is 
sufficient variation song to song.

The sound: pad voices that breathe in and out on their own cycles so the chord forms and dissolves, a low bed that never stops, a slow chord journey that leaves home and comes back, and soft bells on loops of unequal length that slide past each other, all in a long hall with a long, darkening echo. It evolves over minutes: the bells thin out and fill in, and the chords drift.

What sets it apart from base Ambient, in order of how much you hear it:
- The chords move (base Ambient holds one to three windows).
- A continuous low bed: a held tonic pedal and a root bass.
- Pads that breathe, with the bass leading each chord change and the pads arriving late.
- Bell loops measured in beats, so the phasing is heard every few seconds.

## 2. Why the plan was simplified

The 2026-11-09 plan followed AMB-1's code closely: eight recipes copied from its presets, three harmony plans, about 17 new rules, a pitch-bend bass glide, a new Drift effect, a colour chord with its own clash guards, and a one-note Evolve mode shift. That is several weeks of work, and the glide and Drift touch live playback, the riskiest code in the app.

Most of the sound comes from four mechanisms: the moving chords, the breathing pads, the beat-length bell loops and the low bed, plus the reverb and echo. So this plan builds the mechanisms first, draws a few per-song dials from the seed in place of named recipes, and leaves the rest on the shelf until a listen says it's missing (Zack, 2026-11-14).

**No composed phrases (Zack, 2026-11-14).** AMB-1 has none. Its four bell loops start empty and fill with random slots, each a chord tone 72 percent of the time and otherwise the 2nd, 4th or 6th above the chord root (amb.c, rand_offset and loop_add, checked 2026-11-14 against commit da0047d). Zen does the same: the melody is whatever the loops make as they phase against each other. Zen adds only the clash rules in section 6.

## 3. Ground rules

- **Base Ambient and Ambient Piano do not change.** Only the shares move. A fingerprint check proves it (section 12).
- **No rearchitecture.** Zen is an early-return branch in generateAmbient, the way Ambient Piano is. Zen code lives in new files; shared files get small guarded branches.
- **No new playback features in phases 1 to 3.** Everything is ordinary MIDI notes and existing effect paths (reverb, echo, tremolo, filter sweep, auto-pan, the per-note boost fade). New tables for existing settings are fine.
- **No clashes.** Every Zen note is in the song's mode or a short passing note, and section 6's rules are enforced where each note is written, preferably not a post-pass unless required.
- **Determinism.** No Dictionary or Set order feeds an RNG draw. Zen draws come from the fresh trackSeed block 120 to 127 (section 4).
- **iPhone parity.** Any effect default set in TrackRowView is mirrored in AppState.restoreDefaultEffects.
- **Long sustain.** Every pad, pedal and bass instrument must hold for a long time without dying away. We can use techniques from Kosmic or Ambient for long sustains. 

**Shares.** Zen reuses pianoRuleRoll, which only Piano songs read (to pick their Piano rule), so no new draw enters the shared prefix. Piano if pianoRoll < 0.35, Zen if not Piano and pianoRuleRoll < zenShare, otherwise base Ambient. Testing: Piano 10, base Ambient 10, Zen 80 (pianoRoll < 0.10, zenShare = 0.889), marked in the code as temporary (Zack, 2026-11-09). Release: Piano 35, Zen about 30 (zenShare about 0.46), base about 35. A base Ambient seed that falls in the Zen share becomes Zen on reload; that is accepted.

## 4. The ZenPlan: one picture of the song

Zudio normally rolls each track's rule on its own. Zen works only if every track reads the same picture, so the generator builds one value first, the **ZenPlan**, and every Zen rule reads it. It is a pure function of the seed and the Zen tempo, never the user's tempo scrub, so regenerating a track rebuilds the same plan.

**What the ZenPlan holds**
- The dials (below).
- The chord windows: start bar, length in bars, degree string, ChordType, chord-tone pitch classes, and Zen's safe tensions (section 5).
- The pedal's pitch set per window (section 6).
- The swell, one value per bar (phase 2).

**The dials, in place of recipes.** Each song draws these from its seed. Unlike AMB-1, Zudio has no dials for these, so they are generated randomly.
1. **Mode:** Ionian 0.22, Dorian 0.22, Aeolian 0.20, Mixolydian 0.18, Lydian 0.18. Lydian is Zen's own; base Ambient doesn't draw it.
2. **Tempo:** 62 to 88 bpm, triangular, peak 72. The floor is 62 because the Ambient frame clamps there.
3. **Chord pace:** a mean window of 25 to 60 s.
4. **Breath length:** AMB-1's Swell knob, 45 to 70 (section 7).
5. **Pad colour:** Rhodes-like 0.55 or glass and strings 0.45 (was voices; choir removed from pads 2026-11-20).
6. **Restlessness:** 0.25 to 0.45. This is how much the bell loops change from pass to pass. It's kept low because the Eno records repeat literally.
7. **Bell density** (phase 2): sparse 30, medium 45 or full 60.
8. **Echo size** (phase 1): 75 to 90, which sets echo feedback.
9. **Pulse** (phase 3): on in about 40 percent of songs.

The log names the dials in plain words, for example "Ambient Zen: G Lydian, slow chords, voices, sparse bells".

**Seed indices.** The old plan's 96 and 99 are now taken: Chill Blues uses 96 and Chill motion uses 99 (checked 2026-11-14). Those are another style, but a clean block is clearer. Indices 120 to 127 are unused anywhere:
- 120 dials;
- 121 chord walk;
- 122 pad breaths;
- 123 pedal;
- 124 bass flags;
- 125 swell;
- 126 spare;
- 127 pulse.

The bell loops draw from their own track RNGs.

## 5. Harmony: modes, chords and the journey

**Chords are diatonic seventh chords**, stacked thirds on each degree (AMB-1's en_chord_tones), stored as ChordWindow with a degree string and one of ChordType's existing maj7, min7, dom7 or min7b5. The table below gives each mode in C; transpose by the key. The weight is AMB-1's walk weight, by degree position. "Safe" lists the tensions a bell may use over that chord: scale notes that are not a semitone above any chord tone. "Avoid" lists the scale notes that are, and they are never written over that chord. Computed by script on 2026-11-14.

**Ionian** (C D E F G A B)
- I, "1" Cmaj7 (C E G B), weight 4. Safe D, A. Avoid F.
- ii, "2" Dm7 (D F A C), weight 2. Safe E, G, B.
- iii, "3" Em7 (E G B D), weight 1. Safe A. Avoid C, F.
- IV, "4" Fmaj7 (F A C E), weight 3. Safe D, G, B.
- V, "5" G7 (G B D F), weight 3. Safe E, A. Avoid C.
- vi, "6" Am7 (A C E G), weight 3. Safe D, B. Avoid F.
- vii, "7" Bm7b5: **not used in Zen** (its root sits a semitone under the tonic pedal).

**Dorian** (C D Eb F G A Bb)
- i, "1" Cm7 (C Eb G Bb), weight 4. Safe D, F, A.
- ii, "2" Dm7 (D F A C), weight 2. Safe G. Avoid Eb, Bb.
- bIII, "b3" Ebmaj7 (Eb G Bb D), weight 1. Safe C, F, A.
- IV, "4" F7 (F A C Eb), weight 3. Safe D, G. Avoid Bb.
- v, "5" Gm7 (G Bb D F), weight 3. Safe C, A. Avoid Eb.
- vi, "6" Am7b5 (A C Eb G), weight 3. Safe D, F. Avoid Bb.
- bVII, "b7" Bbmaj7 (Bb D F A), weight 0.4. Safe C, G. Avoid Eb.

**Mixolydian** (C D E F G A Bb)
- I, "1" C7 (C E G Bb), weight 4. Safe D, A. Avoid F.
- ii, "2" Dm7 (D F A C), weight 2. Safe E, G. Avoid Bb.
- iii, "3" Em7b5 (E G Bb D), weight 1. Safe C, A. Avoid F.
- IV, "4" Fmaj7 (F A C E), weight 3. Safe D, G. Avoid Bb.
- v, "5" Gm7 (G Bb D F), weight 3. Safe C, E, A.
- vi, "6" Am7 (A C E G), weight 3. Safe D. Avoid F, Bb.
- bVII, "b7" Bbmaj7 (Bb D F A), weight 0.4. Safe C, E, G.

**Aeolian** (C D Eb F G Ab Bb)
- i, "1" Cm7 (C Eb G Bb), weight 4. Safe D, F. Avoid Ab.
- ii, "2" Dm7b5 (D F Ab C), weight 2. Safe G, Bb. Avoid Eb.
- bIII, "b3" Ebmaj7 (Eb G Bb D), weight 1. Safe C, F. Avoid Ab.
- iv, "4" Fm7 (F Ab C Eb), weight 3. Safe D, G, Bb.
- v, "5" Gm7 (G Bb D F), weight 3. Safe C. Avoid Eb, Ab.
- bVI, "b6" Abmaj7 (Ab C Eb G), weight 3. Safe D, F, Bb.
- bVII, "b7" Bb7 (Bb D F Ab), weight 0.4. Safe C, G. Avoid Eb.

**Lydian** (C D E F# G A B)
- I, "1" Cmaj7 (C E G B), weight 4. Safe D, F#, A.
- II, "2" D7 (D F# A C), weight 2. Safe E, B. Avoid G.
- iii, "3" Em7 (E G B D), weight 1. Safe F#, A. Avoid C.
- #iv, "#4" F#m7b5 (F# A C E), weight 3. Safe D, B. Avoid G. AMB-1's Afternoon plays this chord.
- V, "5" Gmaj7 (G B D F#), weight 3. Safe E, A. Avoid C.
- vi, "6" Am7 (A C E G), weight 3. Safe D, F#, B.
- vii, "7" Bm7: **not used in Zen**, as in Ionian.

Zen computes its own safe set. The shared NotePoolBuilder's scaleTensions includes the avoid notes (it marks F as a tension of Cmaj7), and its avoidTones covers only chromatic notes, so Zen must not use either for bells.

**The journey**
- The first window is the tonic and is one full window long. The last window is the tonic and covers the outro.
- In between: AMB-1's weighted walk over the weights above, excluding the current chord. Ionian and Lydian give vii weight 0.
- Each window lasts the chord pace × random 0.7 to 1.3, converted to bars (bars = seconds × tempo / 240) and rounded to a whole bar, at least 4 bars. At 72 bpm a bar is 3.3 s, so windows run about 6 to 24 bars. A 3 to 5 minute song gets about 3 to 8 chords.
- **The way home (new; AMB-1 never comes home).** The window before the outro tonic is drawn from a cadence list instead of the walk, so the return sounds like an arrival:
  - Ionian: IV 0.5, ii 0.25, V 0.25;
  - Lydian: II 0.4, V 0.3, vi 0.3;
  - Mixolydian: bVII 0.4, IV 0.4, v 0.2;
  - Dorian: IV 0.5, bVII 0.3, ii 0.2;
  - Aeolian: iv 0.4, bVII 0.3, bVI 0.3.
- If the walk lands on the tonic just before the cadence window, it redraws once.
- The windows go into structure.chordPlan, and each SongSection takes the Zen mode, so TonalGovernanceBuilder, the log and the chord display follow for free ("#4" already displays as #IV).

## 6. No clashes: the rules every track obeys

"Clash" uses Zack's grading:
- **Glaring:** a semitone within an octave; a major 7th with the non-chord note below; or a minor 9th held two beats or more with both notes at C3 (MIDI 48) or above.
- **Mild:** two or more octaves apart, or short.

Zen's target is zero glaring clashes in the MIDI. Each rule is enforced in the generator that writes the note.

1. **One scale.** Every note of every Zen track is in the song's mode. No chromatic notes, no borrowed chords. The colour chord stays on the shelf.
2. **The pedal fits every chord.** The Texture pedal holds the tonic and the fifth. In each window it drops any of the two that is a semitone from a chord tone, and it always keeps at least one. From the table, the only drops are:
   - Ionian and Lydian iii and V: the tonic drops (it rubs the leading tone) and the fifth holds.
   - Aeolian ii, iv and bVII: the fifth drops (it rubs the b6) and the tonic holds.
   - Lydian II and #iv: the fifth drops (it rubs the #4) and the tonic holds.

   No window loses both notes, because vii is out of Ionian and Lydian. A pedal note crossing into a window that drops it ends at that window's first step, and it comes back at the start of the next window that allows it.
3. **Registers are fixed so the low voices can't rub.**
   - Bass: MIDI 36 + the root's pitch class, so 36 to 47.
   - Pedal tonic: the tonic in 48 to 59. Pedal fifth: 7 above it, 55 to 66.
   - Pads: 48 to 77.
   - Because vii is out, the bass never sits on the leading tone under the pedal tonic (B2 against C3 was the glaring case).
   - The bass's midpoint move to the fifth is skipped when that fifth is the leading tone (Ionian and Lydian iii).
4. **Pad voicing.** Use AMB-1's nearest-movement permutation (en_voice_lead) over the window's four chord tones inside 48 to 77, with extra costs:
   - +40 for two voices on one note (AMB-1's own);
   - +40 for any two voices 1 or 13 semitones apart;
   - +40 for any voice 1 or 13 semitones from a pedal note the window keeps;
   - +40 for a leading-tone voice below the pedal tonic.

   So a maj7 chord voices its 7th above its root, never as a semitone or minor 9th.
5. **The handoff stays clean.** At a chord change, a pad voice whose note isn't in the new chord ends at the change (section 7). So during the lag only common tones carry over, and they are chord tones of both chords.
6. **Bass joins.**
   - At a window change, the old root ends exactly where the new root starts, with no overlap. An overlap would hold the old root under the new chord: for example, F under Em7 is a major 7th with the outside note below.
   - The 1-beat overlap is used only where both notes belong to the same chord: a re-strike of the same pitch, or the root-to-fifth move.
   - The Ambient per-note fade is off on Bass in Zen (section 11), so a join doesn't dip.
7. **Bell notes.** A bell note is written only if all of these hold:
   - It is a chord tone of the window in force at its step, or a safe tension of that window.
   - A tension never falls on beat 1 or 3 (step % 16 = 0 or 8). These are diatonic extensions, not chromatic notes, so the off-beat chromatic cap doesn't apply, but they are kept off the strong beats all the same.
   - **Sounding check:** over the note's onset plus 2 beats (8 steps), it is not 1 or 13 semitones from any Pads, Texture or Bass note already written, nor from an earlier bell track's note. This uses the finished events of the tracks generated before it (Pads, Texture, Bass, then Lead 1, Lead 2, Rhythm). The check covers a chord change inside the ring.
   - A candidate that fails moves to the nearest chord tone that passes (ties go down). If none passes, the slot rests for that pass.
8. **Lead 2 answers Lead 1.** Lead 2 drops any note on a beat where Lead 1 sounds.
9. **What is left is mild and accepted.** Echo and reverb tails of an in-scale bell ringing into the next chord. The echo's low-pass darkens each repeat. tools/clash_scan.py can't see tails, so this is judged by ear.

## 7. Phase 1: the bed (chords, pads, pedal, bass, space)

The goal is to hear whether the core works before building anything else: a song that travels and comes home over a bed that never stops. No bells yet.

**Plumbing, structure and the ZenPlan.** Sections 4, 5 and 11.
- The song uses the Ambient frame length (180 to 315 s) at the Zen tempo.
- It has one body section A and an outro of 6 to 12 bars (drawn per song, uniform; Zack, 2026-11-20), with no intro (Zack, 2026-11-20). The pads, pedal and bass start at bar 1; the outro carries the cadence window's arrival and the held breath.
- The song is trimmed to its last pad note plus 2 bars, the way Ambient Piano trims. If the reverb and echo wash is cut short, the tail becomes 4 bars.

**Pads: AMB-PADS-011 Airports Breath.** Four voices, each breathing on its own cycle (AMB-1's numbers).
- **Cycle.** Seconds = (4 + 0.12 × breath length) × the voice factor (1.0, 1.21, 1.43 or 1.67) × random 0.85 to 1.15, redrawn at every breath. With breath length 45 to 70, the voices run from about 8 to 25 s.
- **Converting to steps.** steps = seconds × tempo / 15. At 72 bpm, 1 s is 4.8 steps.
- **Start.** Voice 1 starts at once. Voices 2 to 4 start (1 − 0.9), (1 − 0.82) and (1 − 0.95) of a first cycle later, all within about 3 s. The cycles then drift apart.
- **Breath.** One MIDI note per breath. The note-off falls at 90 percent of the cycle, so each voice rests briefly and the rests rarely line up. Velocity = 50 + 40 × peak, with the peak random 0.6 to 1.0.
- **Chord change.** If a sounding voice's pitch class is in the new chord, it carries on to the end of its breath. If not, its note ends at the change, and its next breath starts 1 s later on its new target, with a cycle at 85 percent of the usual length. A resting voice takes its new target at its next breath. This is the bass-leads, pads-lag effect. Never snap the pads to the chord change.
- **Outro: the held breath.** At the start of the final 4 to 6 bars of music (6, or the outro less the 2-bar tail when that is fewer), all four voices take the tonic chord and hold. **Staggered endings (2026-11-20):** the pads, pedal and bass do not stop together. One track holds to the end of the music; the other two stop 1 and then 1 to 2 more bars earlier, in an order drawn per song from the seed (dials.endOffsets, at most held breath less 2 bars, so all three still sound together for at least 2 bars of the hold).

**Pads must swell, not strike.** AMB-1's bed is slow swells: each voice rises over 4 to 7 s, so the four voices merge into one level wash with no audible attacks. A stock preset re-attacks on every breath. Phase 1 therefore builds both of these and compares them at the listening stop:
1. **Stock presets** with the list below. Warm Pad (0.8 s attack) and Halo Pad come first because they attack slowest.
2. **Swell presets.** Copies of Warm Pad, Halo Pad, Concert Choir and Space Voice in a new soundfont bank. Each copy sets SF2 generator 34 (attackVolEnv) to 3000 timecents (about 5.6 s) and generator 38 (releaseVolEnv) to 2600 (about 4.5 s).
   - **Why copies (decided 2026-11-20).** The sampler has no API to change a preset's envelope at playback, a track-wide volume ramp would swell and duck all four voices together, and editing Warm Pad in place would change base Ambient and every style that uses it. A copy is a new preset record in a new bank pointing at the existing instruments and samples: no sample data is copied. Each copy is about 200 to 350 bytes, about 1 KB for all four on a 21.2 MB file.
   - Preset-level generators add to the instrument's own value, so each copy sets the offset that brings the total to about 3000 (attack) and 2600 (release). Instrument attacks today: Warm Pad −386, Concert Choir −2786, Halo Pad and Space Voice −3986. If the sampler ignores preset-level envelope generators, copy the instrument records as well, still with no sample data (a few KB).
   - The note-off moves to 55 percent of the cycle, so the release supplies the fall and the voice goes quiet near 90 percent.
   - The tool is a sibling of tools/sf2_copy_presets.py, which appends presets and keeps every existing byte, so no existing program moves.
   - This is a soundfont edit and needs no playback code.
   - Check that AVAudioUnitSampler honours the copied envelope, and that a 4.5 s release leaves no tail after Stop or a seek.

**Texture: AMB-TEXT-012 Pearl Pedal.**
- The tonic and fifth from section 6, rule 2, in the section 6 registers. The fifth is present in about 60 percent of songs; the other songs hold the tonic alone, except in windows where the tonic drops and the fifth stands in.
- Each note lasts 3 to 5 bars, and the next starts 1 beat before it ends, on the same pitch, so it never gaps.
- Velocity 40 to 54.
- It enters with the pads and ends with their held breath.

**Bass**, rolled per song:
- **AMB-BASS-007 Airports Root** (0.60).
  - The chord root at MIDI 36 + its pitch class, one note per window, velocity 54 to 62.
  - Long windows are re-struck every 8 bars, on the same pitch with a 1-beat overlap.
  - At the window's midpoint, with probability 0.35, it moves to the fifth (except as section 6, rule 3 says).
  - It sits a window out with probability 0.3 × restlessness, never the first or the last window.
- **AMB-BASS-008 Plateaux Octave Root** (0.40).
  - The root doubled at the octave for the first 2 bars of the window.
  - Then the upper note alone is re-struck for the rest of the window, overlapping the pair by 1 beat.
  - At the midpoint only the upper note moves to the fifth.
  - It's fuller, and it carries on a phone speaker.

**The space.** A Zen branch in PlaybackEngine.setAmbientMode, using existing settings only (numbers from the old plan, section 12):
- **Reverb.** The large bus switches to .largeHall2 in Zen. Pads 75, Lead 1 68, Lead 2 68, Rhythm 70 and Texture 55 go to the large bus. Bass 10 and Drums 35 go to the small .mediumHall bus. The bass stays almost dry and centred, as in AMB-1. perTrackReverbPresets matches, for export.
- **Echo.**
  - Feedback is 0.5 + 0.32 × echo size, so 74 to 79 percent.
  - Echo time is 2 beats, capped at 2.0 s (AVAudioUnitDelay's limit).
  - The low-pass is 2600 Hz on bells and 1800 Hz on Pads, so each repeat comes back darker.
  - Wet: Pads 15, Texture 10, Bass none.
- **High-pass.** Base Ambient puts a 250 Hz high-pass on Lead 1, Lead 2 and Texture. Zen leaves it off Texture, because the pedal's fundamental is 131 to 370 Hz and the filter would remove it.
- **Pads.** Tremolo at 0.06 Hz (a 17 s cycle) and depth 0.30. A filter sweep from 1000 to 3000 Hz.
- **Fades.** The Ambient per-note boost fade is off on both Pads and Bass in Zen. It is one volume ramp per track, so with overlapping notes each note-off would duck the notes still sounding. The breath comes from the note timing and the swell presets.

**Instruments**, short lists to start. New entries are appended to each Ambient pool in all four places, with base Ambient's pick list held to its old indices so existing seeds don't move:
- **Pads, Rhodes-like:** Warm Pad 89, Halo Pad 94, Fantasia 88, FM Electric Piano 5.
- **Pads, glass and strings (swell copies, bank 14):** Glass Swell 14092, Strings 3 Swell 14050, Strings 5 Swell 14051, Slow Strings Swell 14049. Choir voices are out of the pads (Zack, 2026-11-20).
- **Texture pedal:** Tonewheel Organ 16, Solar Wind Swell 14088 and Sine Swell 14080 (about 27 percent each), and the only choir on any Zen track: Choir Aahs 52, Synth Voice 54, Space Voice 91, about 6.7 percent each (20 percent together). No MIDI patch repeats across Zen tracks and no organic instruments (2026-11-20). Volumes by ear: Solar Wind Swell 0.8, Sine Swell 0.7 (the Ambient Texture boost is 2.0).
- **Bass:** Synth Bass 101 1038 and five synth swell copies: Saw Bass Swell 14038 (Mean Saw Bass), Brass Swell 14062 (Synth Brass 1, volume 0.25, lowered from 0.40), Pulse Bass Swell 14039, Lead Bass Swell 14087 (volume 0.56) Synth Bass 3 Swell 14037 and Polysynth Swell 14090 (moved from the pedal 2026-11-20, volume 0.5). No Voice Oohs, Cello, Sine Wave or Fretless Bass (2026-11-20).

All passed the sustain check in the old plan (section 11).

**Evolve and regeneration, minimal.**
- Regenerating a track rebuilds the ZenPlan from the seed and regenerates only that track.
- Evolve must not fall into the generic Ambient path, which would bring in base Ambient rules and audio textures.
- In phase 1, an Evolve pass keeps the chord plan, the pedal and the bass, and swaps instruments from the Zen lists only.

**Listening stop.** Zack listens to a handful of songs, with AMB-1's Afternoon preset (G Lydian, 84 bpm) as the reference, and the stock pads against the swell presets.
- Does the bed feel continuous?
- Do the chords travel and come home, and does the cadence window sound like an arrival?
- Do the pads lag the bass?
- Is the hall and echo wash right?

If the bed doesn't work, rethink before phase 2.

### Phase 1 as built (2026-11-20)

Built and checked by script; not yet heard. Uncommitted.

- **Files.** New: Generation/Ambient/AmbientZenPlan.swift (dials, chord table, layout, walk, cadence, pedal and bass keep rules, structure, chord names) and AmbientZenTracks.swift (AMB-PADS-011, AMB-TEXT-012, AMB-BASS-007, AMB-BASS-008). Branches in SongGenerator (roll, generateAmbientZen, Zen log, regenerateTrack), SongState (isAmbientZen, "Ambient Zen"), AppState (reload, pools, pick lists, effect defaults, Evolve), PlaybackEngine (setAmbientMode Zen branch) and TrackRowView.
- **Shares.** SongGenerator.ambientPianoShare and ambientZenShare, set to the testing values 0.10 and 0.889 and marked temporary; the release values 0.35 and 0.46 are in the comment.
- **Reload.** A Zen song records "Zen" in its forced rules and reloads as Zen whatever the shares are then. A base Ambient song saved at testing shares with a piano roll between 0.10 and 0.35 reloads as Ambient Piano at release shares.
- **Song shape.** The Ambient frame at the Zen tempo; section A, then the 6 to 12 bar outro. The music ends 2 bars before the song (the reverb tail); the held breath is the 6 bars before that. The trim is in place but never cuts, because the pads always hold to the end of the music.
- **Layout.** Window lengths are drawn first, then the chords. The last body window (the cadence) takes whatever is left, so it can run up to 3 bars past the pace. The cadence draw skips the chord already playing.
- **Pad breaths.** The note-off is at 90 percent of the cycle for every preset, stock and swell alike: the MIDI is written once and the picker chooses the sound, so the 55 percent swell timing is not used. Voicings are fixed per window (no randomness), so regenerating Pads changes only the breathing. A carried voice must also sit clear (not 0, 1 or 13 semitones) of the new voicing, the pedal and every bass note the window may hold.
- **Bass and pads.** The voicing cost and the carry check also avoid every note either bass rule may hold in the window (root, its octave, both fifths). This was the one glaring clash found in testing: AMB-BASS-008's upper A3 against a pad G#3 over Amaj7.
- **Pedal and bass.** A pedal note also drops when it sits 1 or 13 semitones from a bass note the window may hold. Only Aeolian's bVI in C to Eb does this (the pedal fifth G3 under the bass octave Ab3); the tonic holds.
- **Same-pitch joins abut.** The pedal's next note and the bass re-strikes start exactly where the last note ends, with no 1-beat overlap: the sampler's note-off for the old note would cut the new one. Playback fires a step's note-offs before its note-ons, so the join is seamless. The 1-beat overlap is kept where the pitch changes (root to fifth, and AMB-BASS-008's lower note under the upper re-strike).
- **Bass details.** Re-strikes every 8 bars, never leaving a stub under 2 bars. The fifth folds down an octave when it would pass MIDI 47 (59 for AMB-BASS-008's upper note). AMB-BASS-008 moves to the fifth with the same 0.35 chance as 007. The bass never sits out two windows running (the first build left a 37-bar gap).
- **Log (2026-11-20).** "Ambient Zen – N bpm"; "Chords": key, mode, "seventh chords", the chord pace and the way home as a Roman numeral, for example "D Aeolian quick 7th chords drifting, home via IVm7" (updated 2026-11-20; "home on I" when the last body chord is the tonic); a "Zen" line with the other dials only, for example "Breaths: long, Echo: light, Bells: sparse" (the pad colour is left to the Instruments line, Zack, 2026-11-21); then the three rules, each marked "* ". No Form line (every song is A and an outro), no key and mode on the Zen line, no line per chord change (Zack, 2026-11-20: no style logs one).
- **Instruments.** Appended to the Ambient pools (base Ambient keeps picking from its old indices): Pads add Warm Pad, Fantasia, FM Piano, Warm Swell, Halo Swell, Concert Choir, Synth Voice, Space Voice, Choir Swell, Voice Swell; Texture adds Warm Pad and Tonewheel; Bass adds Sine Wave, Fretless Bass, Synth Bass 101. Zen pads draw by the colour dial: Rhodes-like (Warm Pad, Halo Pad, Fantasia, FM Piano, Warm Swell, Halo Swell) or voices (Glass Swell, Strings 3 Swell, Strings 5 Swell, Slow Strings Swell; the choir voices were removed from the picker 2026-11-20). The Swell presets are bank 14 (program 14089 and so on) and load through the ordinary bank decode in setProgram.
- **Effects.** Chips: Rhythm shows Pan, Delay, Hall and Texture Pan, Delay, Reverb (its Hall chip is labelled Reverb); Bass shows Sweep, Trem, Reverb. Defaults: Pads Hall, Trem, Sweep and a hidden Delay (the 15 percent echo, which has no chip of its own); Texture Delay, Reverb; Bass Reverb, Trem; leads Delay, Hall; Rhythm Delay, Hall, Pan; Drums none. TrackRowView and AppState.restoreDefaultEffects (iPhone) carry the same table. Bass tremolo is 0.08 Hz at depth 0.15 (not in the plan; by ear). Rhythm auto-pan is one sweep per 8 bars. Tonewheel on Texture is trimmed to 0.8 (the Ambient Texture boost is 2.0). The bass sweep, if switched on, is an ordinary LFO in Zen, not tied to the fade.
- **Evolve.** A Zen pass copies the song's first bars and regenerates nothing (no absent-track additions). Pass 1 swaps the Pads instrument, pass 2 the Texture instrument, both from the Zen lists. Superseded 2026-11-21: Zen now follows the normal passes (see phase 2 as built).
- **Checks.** Base Ambient and Ambient Piano are identical on seeds 1 to 300 at testing and release shares. tools/clash_scan.py on 200 Zen songs: no clashes at all. A stricter script (any two Pads, Texture or Bass notes 1 or 13 semitones apart for half a beat or more, chord tones included) also finds none. Reload after Pads and Bass regenerations reproduces every song.
- **Not checked.** Whether AVAudioUnitSampler honours the Swell presets' envelopes, stuck notes or tails after Stop or a seek, and the iPhone speaker check. All need the app and an ear.

## 8. Phase 2: the bells and the swell

**The bell loop helper.** One helper (AmbientZenLoops.swift) shared by Lead 1, Lead 2 and Rhythm. It walks the song one pass at a time, never tiling.
- **Loop lengths.** A loop is a fixed number of quarter-note beats: 13 for Lead 1, 17 for Lead 2 and 23 for Rhythm. They are prime, so the loops never line up.
- **Register.** The base notes are AMB-1's: Lead 1 72, Lead 2 67, Rhythm 79. A note's pitch is the tonic at or below the base, plus the scale steps from section 5, folded into MIDI 36 to 103.
- **Slots** (AMB-1's rand_offset). A slot holds a scale step above the current chord's root, so the loop re-harmonises when the chord moves, even partway through a pass. A new slot is a chord tone 72 percent of the time (steps 0, 2, 4 or 6), a further octave up 30 percent of those times, and otherwise the 2nd, 4th or 6th above the chord root (steps 1, 3 or 5). The only Zen change: a passing step that resolves to an avoid note of the window in force (section 5), or that falls on beat 1 or 3, moves to the chord tone below.
- **Note count.** The target is floor(clamp(density × 0.05 × (1 + 0.8 × swell), 0, 5) + random 0 to 1).
- **Per-pass changes** (AMB-1's), with r = restlessness:
  1. Add or remove notes to meet the target.
  2. The pass rests with probability 0.15 × r + 0.15 × max(−swell, 0).
  3. With probability 0.7 × r, one slot either changes its note or moves to an empty slot.
- **Octave ring.** With probability 0.08 + 0.12 × max(swell, 0), the same note sounds an octave up at 40 percent velocity.
- **Every note** passes section 6, rule 7.

**AMB-LD1-011 Airports 1/1 Loop** on Lead 1, every Zen song. The plain AMB-1 loop: generic note count, velocity 40 to 80 (AMB-1's 50 to 99 percent mapped to MIDI as 40 + 0.8 × (percent − 50)), and per-pass changes.
- Source: Music for Airports 1/1.

**AMB-LD2-014 Airports 1/2 Answer** on Lead 2 (0.85). The AMB-1 loop, softer (velocity 42 to 70), dropping any note on a beat where Lead 1 sounds. In the other 15 percent of songs Lead 2 rests, logged as AMB-LD2-000 No lead 2 (the "-000" convention, as AMB-RTHM-000 No rhythm; Zack, 2026-11-20).

**AMB-RTHM-007 Lux Glass** on Rhythm (0.80). One to three short high notes (2 to 4 steps) per 23-beat loop, velocity 35 to 60, chord tones only. Rhythm is silent in the other 20 percent of songs.

**The swell** (AMB-1's arc, renamed so it doesn't collide with base Ambient's arcs).
- A value per bar from −1 (sparse) to +1 (full).
- Every 50 to 150 s a new target is drawn: random −1 to 1 × (0.6 + 0.4 × random), pushed 0.25 further from the middle, clamped.
- The value eases toward the target with a 35 s time constant, then is scaled by 0.5 to 0.9 per song.
- It is held at −0.5 or below for the first 8 bars and in the outro.
- It sets the bell note counts, the rest chance, the octave ring and the bass sit-outs, and it nudges pad and pedal velocity by ±10 percent.

**Entries and exits.**
- Lead 1 enters at a random bar from 2 to 4, Lead 2 at bar 6 to 8, and Rhythm at bar 9.
- In the outro they leave in reverse order: Rhythm first, Lead 2 about 4 bars later, then Lead 1 after one last pass, about 3 bars from the end.
- All of them are gone before the pads' held breath.

**Instruments.**
- Lead 1: Vibraphone 11, Tine Electric Piano 4, Echo Drops 102, Harp 46.
- Lead 2: Tinkling Bells 11008, Christmas Bells 12010, Kalimba 108, Harp 46 (2026-11-21: Celesta is on Rhythm only, Marimba 12 is out as too wooden, Xylophone was tried and dropped).
- Rhythm: Glockenspiel 9, Celesta 8, Tinker Bell 112, Synth Chime 11098, Christmas Bells 12010 (added 2026-11-21 to audition beside Lead 2).

**Effects.**
- Echo on the bells: Lead 1 wet 45, Lead 2 50, Rhythm 48.
- Lead 2's echo time is 0.75 of Lead 1's, a nod to AMB-1's two tape heads. Rhythm uses 1.5 beats.
- Static pans: Lead 1 −0.6, Lead 2 +0.35. Rhythm sits at +0.6 on a slow auto-pan (one sweep per 8 bars, depth 0.35).

**Listening stop.**
- Is the phasing audible?
- Do the loops change without wandering?
- Does the swell make the song move?

### Phase 2 as built (2026-11-20)

Built and checked by script; not yet heard. Uncommitted, on top of phase 1.

- **Files.** New: Generation/Ambient/AmbientZenLoops.swift (the loop, the three bell rules, the sounding check, writeBells). The swell is in AmbientZenPlan (swellCurve, swell(atBar:), index 125). Branches in SongGenerator (generation step 4, the log, regenerateTrack for Lead 1, Lead 2 and Rhythm), AppState (bell pools and pick lists) and PlaybackEngine (pans).
- **Seeds.** The bells' default seeds are Zen indices 126 (Lead 1), 128 (Lead 2) and 129 (Rhythm); 127 stays the pulse's.
- **The loop.** One slot per quarter-note beat. A slot keeps its offset, velocity and length from pass to pass. Lead 1 and Lead 2 notes are 8 steps (2 beats) long, the same span as the sounding check; Rhythm's are 2 to 4. The octave-ring roll is made for every slot so a rest or a dropped note never shifts the draws after it. A chord step is an even step within the octave (0, 2, 4, 6, then 7, 9, 11, 13); 1, 3 and 5 are the passing steps.
- **Lead 2 answer.** Lead 2 drops any note whose onset is a Lead 1 onset.
- **Exits.** Lead 1 stops at the pads' held breath, Lead 2 4 bars earlier, Rhythm 4 bars before that. Notes are clipped so none rings into the next exit.
- **The swell on the bed.** Pad breath and pedal velocity times (1 + 0.1 × swell); bass sit-out chance 0.3 × restlessness + 0.25 × max(−swell, 0) (the old plan's numbers). No extra draws, so the bed's notes are unchanged; only velocities and sit-outs move.
- **Regeneration.** Regenerating any Zen track but Drums rebuilds the bells after it on their own seeds: a bed track rebuilds all three, Lead 1 rebuilds Lead 2 and Rhythm, Lead 2 rebuilds Rhythm. A bell track with an override always plays (a regenerated Lead 2 never comes back Silent), so a reload's replay gives the same song in any order. Checked on 40 songs with four regenerations each.
- **Instruments.** Appended to the Ambient pools, so base Ambient and Ambient Piano keep their old indices (their pick lists are now capped at the old counts). As the plan lists them, sharing included: AMB-1 plays every bell loop on one voice, so a shared sound is fine (Zack, 2026-11-20: the no-repeat rule was only against unintended duplicates). Lead 1: Vibraphone, Tine EP, Echo Drops, Harp. Lead 2: Tinkling Bells, Christmas Bells, Kalimba, Harp (2026-11-21: Celesta moved to Rhythm only, Marimba out as too wooden, Xylophone tried and dropped; the SF2 has no Music Box). Lead 1 draws Echo Drops in only 10 percent of picks, never two songs running, and the Lead 2 lock skips it, because it sounds like a choir (Zack, 2026-11-21). Texture drops Synth Voice; Choir Aahs and Space Voice are 15 percent of its picks together (Zack, 2026-11-21: a voice on Texture is a wall of sound). Picker names were shortened (Zack, 2026-11-21): Solar Swell, Bass Swell (was Lead Bass Swell), Synth Swell (was Synth Bass 3 Swell), Pulse Swell; Slow Strings Swell is gone from the pads, which keep Strings 3 and Strings 5 Swell. Rhythm: Glockenspiel, Celesta, Tinker Bell, Synth Chime. In 25 percent of songs (a dial, lead2SyncsLead1, drawn last from index 120) Lead 2 plays on Lead 1's instrument through the existing Lead 2 lock, logged "Lead 2 <name> locked to L1" (Zack, 2026-11-20); a song with no Lead 2 skips it. No gain trims yet; by ear.
- **Effects.** The echo table, sends and Rhythm's 8-bar auto-pan were already in place from phase 1. New: static pans Lead 1 −0.6, Lead 2 +0.35, Rhythm +0.6, and Rhythm's auto-pan swings ±0.35 around +0.6 instead of the full width around the centre.
- **Log.** The rules in track order (Lead 1, Lead 2, Pads, Rhythm, Texture, Bass); a silent Lead 2 logs AMB-LD2-000 No lead 2 and a silent Rhythm AMB-RTHM-000 No rhythm, and Drums always logs AMB-DRUM-000 No percussion until the phase 3 pulse. The Zen line reads "Breaths: long, Echo: medium, Bells: sparse, Drift: calm, Swell: deep" (Zack, 2026-11-21). Drift is the restlessness dial; Swell is the swell depth (swellCurve's scale). The Style line carries the outro, for example "Ambient Zen – 72 bpm, 9 bar outro".
- **Evolve (changed 2026-11-21).** Zen now follows the normal Evolve passes (Zack): pass 1 regenerates Lead 1 and Lead 2 with new instruments, pass 2 regenerates Pads and Rhythm with new instruments, each through Zen's own regenerate branches, so the bells are rebuilt clash-free against the new tracks. Zen never adds the absent Bass or Drums in a pass, and the new-rule retry is skipped (one rule per Zen track). A silent Lead 2 or Rhythm in the song plays in its pass.
- **Checks.** 200 Zen songs: no bell note 1 or 13 semitones from any other track's note, and no major 7th with the bell's tension below; no out-of-scale notes, no unsafe tensions, no tensions on beat 1 or 3, no bell in the held breath. About 42 Lead 1 notes a song, and 23 Lead 2 and 18 Rhythm notes in the songs where they play; Lead 2 silent in 17 percent, Rhythm in 24 percent. Base Ambient and Ambient Piano identical on seeds 1 to 300. InstrumentPoolDriftTests pass; Mac and iOS builds succeed.

## 9. Phase 3: variety

Each item is independent and can be built or skipped on its own. Specs are in the old plan, sections 6, 10 and 13.
- **AMB-DRUM-005 Garden Pulse.** A very quiet kick, closed hat and open hat on Euclidean patterns of 16, 12 and 7 steps, in songs whose pulse dial is on. Brush Kit. It follows the swell and never goes fully silent.
- **AMB-PADS-015 Big Ship Cycle.** Some songs repeat one 8-chord cycle (A B T B A B T C, where T is the tonic) at 4 bars a chord, with block-chord pads, while layers add on top. It uses the same chord table and clash rules.
- **AMB-PADS-014 Airports 2/1 Field.** Some songs hold one pitch field with no chord changes, and each pitch breathes on its own loop.
- **Fuller Evolve.** Pass 1 brings regrown bell loops and a short chord walk of its own. Pass 2 brings new pads and flips the pad colour. A one-note mode shift (Ionian to Mixolydian and similar) is optional, and it must re-run section 6, rule 2 against the shifted scale.
- **AMB-TEXT-011 On Land Bell** as an alternative Texture rule: a distant tower bell on a 29-beat loop, root or fifth only.

## 10. On the shelf

These come back only if a listen says Zen is missing them. Details are in the old plan.
- **The eight named recipes.** The dials do the job.
- **Bass glide** (a pitch-bend slide between roots). Zack liked it in AMB-1, so expect it back. It is new playback code (RPN bend range, seek handling).
- **Drift** (a slow per-track pitch wander). A new effect chip and new playback code.
- **Edge fades on Bass and Texture** (2.5 s in, 4 s out at a sit-out). The per-note fade can't tell an edge from a join without new engine logic.
- **The colour chord** and its clash guards.
- **Pentatonic modes.**
- **Composed phrases** (a Lead 1 motif, the Discreet Fragment). Ruled out by Zack (2026-11-14) because AMB-1 has none.
- **Micro-timing on the bells, swing, a shared echo bus, and an audio drone on Texture.**

## 11. How it maps onto Zudio

Each piece below names the existing code it reuses or the small branch it needs (all checked 2026-11-14).

**Generation**
- **The roll and early return.** SongGenerator.generateAmbient already draws pianoRoll and pianoRuleRoll before the frame (lines 970 and 971). Zen tests after the Piano decision and returns early before the base Ambient loops, dropout zones and HarmonicFilter, like the Piano branch at line 1017.
- **Frame.**
  - Zen draws its tempo from index 120 and passes it to AmbientMusicalFrameGenerator.generate as tempoOverride, so the bar count is computed at the Zen tempo, as Piano does. A user tempo override of 92 or below is honoured.
  - Then frame.withMode(zenMode).
  - The key comes from the frame's own draw, or keyOverride.
- **Structure.** Zen builds its own SongStructure: two SongSections (A, outro) with the Zen mode, and chordPlan from the ZenPlan windows. Each ChordWindow is made the way AmbientStructureGenerator.makeWindow does (NotePoolBuilder for chordTones). Zen keeps its own safe-tension set in the ZenPlan (section 5).
- **Tonal map.** TonalGovernanceBuilder.build(frame:structure:) as Ambient already calls it.
- **Events.** MIDIEvent is step-based (16 steps a bar) with a duration in steps, so breaths, pedal notes and bells are plain events. Seconds convert with steps = seconds × tempo / 15.
- **Order inside generateAmbientZen:**
  1. ZenPlan;
  2. Pads, Texture, Bass;
  3. Lead 1, Lead 2, Rhythm, each reading the finished events of the tracks before it for the sounding check;
  4. Drums (phase 3);
  5. trim, log, SongState.
- **New files:**
  - Generation/Ambient/AmbientZenPlan.swift (dials, chord table, walk, cadence, pedal sets, swell);
  - AmbientZenTracks.swift (pads, pedal, bass, structure, trim);
  - AmbientZenLoops.swift in phase 2 (loop helper, bell rules, sounding check).
- **Rule IDs.** All free (checked 2026-11-14): AMB-PADS-011, AMB-TEXT-012, AMB-BASS-007, AMB-BASS-008, AMB-LD1-011, AMB-LD2-014, AMB-LD2-000 (was 016; the three lead rules were AMB-LEAD-011, 014 and 000 until 2026-11-21, renamed LD1 and LD2 because each belongs to one lead, Zack), AMB-RTHM-007, and in phase 3 AMB-DRUM-005, AMB-PADS-014, AMB-PADS-015, AMB-TEXT-011.
- **Log.** buildAmbientLog gets a Zen style line ("Ambient Zen – N bpm"), the dials line and rule descriptions. No line per chord change. forced["Zen"] mirrors forced["Piano"]. Every new rule goes in GenerationLogEntry.testingMarkedRules.
- **regenerateTrack** gets a Zen branch that rebuilds the ZenPlan and regenerates one track. Regenerating Pads, Texture or Bass also re-checks the bells, by regenerating the bell tracks with the same seeds, because the sounding check depended on them.

**SongState and AppState**
- SongState gets isAmbientZen, passed explicitly in the initialiser and in every withXxx() copy method, and displayStyleName "Ambient Zen".
- AppState:
  - persistence (substyle name);
  - the seven isAmbientPiano sites, which each need a Zen decision, Evolve among them;
  - the four instrument places: instrumentPoolNames, instrumentPoolPrograms, instrumentPickPool and instrumentPickPoolStatic. The last returns the original indices for base Ambient and the Zen lists for Zen;
  - restoreDefaultEffects.
- **Texture stays MIDI.** Zen never sets ambientAudioTexture: not in the generator, not in Evolve, not in Texture regeneration.

**PlaybackEngine** (existing paths, new values)
- A cachedIsAmbientZen beside cachedIsAmbientPiano, set in setAmbientMode.
- **setAmbientMode's Zen branch:**
  - setBusPresets(large: .largeHall2, small: .mediumHall) and the section 7 sends;
  - perTrackReverbPresets to match;
  - Zen echo tables in place of ambientDelayWet, Feedback, Lowpass and Beats. Base Ambient has Pads at −1 (no echo); Zen gives Pads a light echo. These tables are read at line 1994 as well, so that read takes the Zen table too;
  - the high-pass set without Texture;
  - the Pads sweep floor 1000 and half-range 1000.
- **Per-note fade.** The Ambient fade (lines 978 to 994) skips Bass and Pads when cachedIsAmbientZen.
- **Bass sweep.** It is amplitude-coupled to the boost volume (line 2181). With the fade off it would sit wide open, so the Zen bass default leaves the sweep chip off.
- **Gain trims** for the new programs in setProgram, by ear.

**TrackRowView.** Zen chip defaults (Pads: space, tremolo, sweep. Bass: reverb, tremolo. Texture: delay, space. Leads: delay, space. Rhythm: delay, space, pan), mirrored in AppState.restoreDefaultEffects.

## 12. Checks

- **Baseline first.** Fingerprint a sample of base Ambient and Piano seeds (SWIFT_DETERMINISTIC_HASHING=1) before any change. Check them again at release shares at the end of each phase. They must match exactly.
- **Build plus the Ambient suite** while working; no full test runs.
- **Clash scan.** tools/clash_scan.py on 20 Zen seeds per phase: zero glaring is the bar, and any glaring hit is a generator bug.
- **Engine checks in phase 1:**
  - A held pad or Sine Wave note sounds for minutes without clicking or dying.
  - The swell presets' attack and release are honoured.
  - Stop and seek leave no stuck notes or long tails.
  - Moving from a base Ambient song with an audio texture to a Zen song stops the audio player.
- **Device.** An iPhone speaker check for the bass and pedal, which is why AMB-BASS-008's upper octave and the pedal's register matter.
- **By ear** at the end of each phase. Zack's ear decides, and the tiebreaker is his: Zen should sound more different from base Ambient, not more similar.
