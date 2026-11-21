# Ambient Zen — substyle plan
Copyright (c) 2026 Zack Urlocker

*Status, 2026-11-21: phases 1 (the bed) and 2 (the bells and the swell) are built and committed (6cc1cbe). Zack has listened and likes it, and the first round of tuning by ear is done. Phase 3 waits until he says the bells are settled. This document describes Zen as it is now. The 2026-11-09 plan, with the AMB-1 code reading, the Eno research and every number, is kept in [Ambient-Zen-plan-old-2026-11-09.md](Ambient-Zen-plan-old-2026-11-09.md) as reference only; where the two disagree, this one wins.*

**Contents**

1. What Ambient Zen is
2. Where things stand
3. Ground rules
4. The ZenPlan: one picture of the song
5. Harmony: modes, chords and the journey
6. No clashes: the rules every track obeys
7. The bed: pads, Texture and bass
8. The bells and the swell
9. Instruments
10. The space: reverb, echo, pans and chips
11. The log
12. Regeneration and Evolve
13. Phase 3: variety
14. On the shelf
15. Where it lives in the code
16. Checks

---

## 1. What Ambient Zen is

A third Ambient flavour beside base Ambient and Ambient Piano: a "sounds like" homage to AMB-1 (Charles Vestal's generative firmware for the M-Vave FM-1), and through it to Eno's Music for Airports. It is not an exact emulation, but it must have the key characteristics we can learn from the manual and the source code. We want soothing, evolving background music that is pleasant and ever changing. We want the rich underlying drones of bass and pads. We want the elegant shifting of chord tones across instruments. We want the randomness of bells and similar sounds, so that it is as captivating and beautiful as the original AMB-1. Zudio has no dials, so each song draws those settings at random, enough to vary song to song.

The sound: pad voices that breathe in and out on their own cycles, so the chord forms and dissolves; a low bed that never stops; a slow chord journey that leaves home and comes back; and soft bells on loops of unequal length that slide past each other, all in a long hall with a long, darkening echo. It evolves over minutes: the bells thin out and fill in, and the chords drift.

What sets it apart from base Ambient, in order of how much you hear it:
- The chords move (base Ambient holds one to three windows).
- A continuous low bed: a held tonic drone on Texture and a root bass.
- Pads that breathe, with the bass leading each chord change and the pads arriving late.
- Bell loops measured in beats, so the phasing is heard every few seconds.

**No composed phrases (Zack, 2026-11-14).** AMB-1 has none. Its bell loops start empty and fill with random slots, each a chord tone 72 percent of the time and otherwise the 2nd, 4th or 6th above the chord root. Zen does the same: the melody is whatever the loops make as they phase against each other. Zen adds only the clash rules in section 6.

## 2. Where things stand

**Heard and liked.** Zack has listened to phase 2 songs: "the songs sound good." The first round of tuning (instruments, voices and the log lines) is in.

**Open, in order**
1. Gain trims for the bell programs, by ear. None are set yet.
2. Volumes still unmeasured on the bed: the Saw Bass, Pulse and Synth Swell basses have no trim.
3. By ear: the staggered endings, stop and seek tails with the 4.5 s swell release, and the iPhone speaker.
4. Moving from a base Ambient song with an audio texture to a Zen song should stop the audio player. Not yet checked in the app.
5. Phase 3 (section 13), only after Zack says the bells are settled.
6. Before release: set the Ambient shares back to their release values (section 3), and clean up the SF2.

## 3. Ground rules

- **Base Ambient and Ambient Piano do not change.** Only the shares move. tools/zen_fpcheck.sh proves it (section 16).
- **No rearchitecture.** Zen is an early-return branch in generateAmbient, the way Ambient Piano is. Zen code lives in its own files; shared files get small branches guarded by the Zen flag.
- **No new playback features.** Everything is ordinary MIDI notes and existing effect paths (reverb, echo, tremolo, filter sweep, auto-pan). New tables for existing settings are fine.
- **No clashes.** Every Zen note is in the song's mode, and section 6's rules are enforced where each note is written, not in a post-pass.
- **Determinism.** No Dictionary or Set order feeds an RNG draw. Zen draws come from its own seed block (section 4), and new dial draws go at the end of AmbientZenDials.draw so no existing song's dials move.
- **iPhone parity.** Every chip default set in TrackRowView is mirrored in AppState.restoreDefaultEffects.
- **Long sustain.** Every pad, Texture and bass instrument holds for a long time without dying away.

**Shares.** Zen reuses pianoRuleRoll, which only Piano songs read, so no new draw enters the shared prefix. Piano if pianoRoll < Piano share; Zen if not Piano and pianoRuleRoll < zenShare; otherwise base Ambient.
- **Testing (now, temporary):** Piano 10, base Ambient 10, Zen 80 (0.10 and zenShare 0.889), marked temporary in SongGenerator.
- **Release:** Piano 35, Zen about 30 (zenShare about 0.46), base about 35.
- A Zen song records "Zen" in its forced rules and reloads as Zen whatever the shares are then. A base Ambient seed that falls in the Zen share becomes Zen; that is accepted.

## 4. The ZenPlan: one picture of the song

Zudio normally rolls each track's rule on its own. Zen works only if every track reads the same picture, so the generator builds one value first, the **ZenPlan**, and every Zen rule reads it. It is a pure function of the seed and the Zen tempo, never the user's tempo scrub, so regenerating a track rebuilds the same plan.

**What the ZenPlan holds**
- The dials (below).
- The chord windows: start bar, length in bars, degree, ChordType, chord tones, safe tensions (section 5), and whether the Texture tonic and fifth may sound in that window (section 6).
- The swell, one value per bar (section 8).

**The dials.** Each song draws these from its seed:
1. **Mode:** Ionian 0.22, Dorian 0.22, Aeolian 0.20, Mixolydian 0.18, Lydian 0.18. Base Ambient doesn't draw Lydian.
2. **Tempo:** 62 to 88 bpm, triangular, peak 72. A user tempo override of 92 or below is honoured.
3. **Chord pace:** a mean window of 25 to 60 s.
4. **Breath length:** AMB-1's Swell knob, 45 to 70 (section 7).
5. **Pad colour:** Rhodes-like 0.55, or glass and strings 0.45.
6. **Restlessness ("Drift" in the log):** 0.25 to 0.45. How much the bell loops change from pass to pass, and how often the bass sits out. It's kept low because the Eno records repeat literally.
7. **Bell density:** sparse 30, medium 45 or full 60.
8. **Echo size:** 0.75 to 0.90, which sets the echo feedback.
9. **Pulse:** on in about 40 percent of songs. Unused until phase 3.
10. **Outro length:** 6 to 12 bars, uniform.
11. **End offsets:** the order the pads, Texture and bass stop in (section 7).
12. **Lead 2 lock:** in 25 percent of songs Lead 2 plays on Lead 1's instrument, as AMB-1 plays every bell loop on one voice.

The swell's depth (0.5 to 0.9) is drawn on the swell's own stream, not with the dials.

**Seed indices.** Zen draws from its own block, unused anywhere else:
- 120 dials;
- 121 chord walk;
- 122 pad breaths;
- 123 Texture;
- 124 bass;
- 125 swell;
- 126 Lead 1 bells;
- 127 reserved for the phase 3 pulse;
- 128 Lead 2 bells;
- 129 Rhythm bells.

## 5. Harmony: modes, chords and the journey

**Chords are diatonic seventh chords**, stacked thirds on each degree (AMB-1's en_chord_tones), stored as ChordWindow with a degree string and one of ChordType's maj7, min7, dom7 or min7b5. The lists below give each mode in C; transpose by the key. The weight is AMB-1's walk weight, by degree. "Safe" lists the tensions a bell may use over that chord: scale notes that are not a semitone above any chord tone. "Avoid" lists the scale notes that are, and they are never written over that chord.

**Ionian** (C D E F G A B)
- I, "1" Cmaj7 (C E G B), weight 4. Safe D, A. Avoid F.
- ii, "2" Dm7 (D F A C), weight 2. Safe E, G, B.
- iii, "3" Em7 (E G B D), weight 1. Safe A. Avoid C, F.
- IV, "4" Fmaj7 (F A C E), weight 3. Safe D, G, B.
- V, "5" G7 (G B D F), weight 3. Safe E, A. Avoid C.
- vi, "6" Am7 (A C E G), weight 3. Safe D, B. Avoid F.
- vii, "7" Bm7b5: **not used** (its root sits a semitone under the tonic drone).

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
- vii, "7" Bm7: **not used**, as in Ionian.

Zen computes its own safe set. The shared NotePoolBuilder's scaleTensions includes the avoid notes, and its avoidTones covers only chromatic notes, so Zen uses neither for bells.

**The journey**
- Window lengths are drawn first: the chord pace × random 0.7 to 1.3, in whole bars, at least 4. At 72 bpm a bar is 3.3 s, so windows run about 6 to 24 bars, and a 3 to 5 minute song gets about 3 to 8 chords.
- The first window is the tonic. After it, AMB-1's weighted random walk over the weights above, never the same chord twice running. Ionian and Lydian give vii weight 0. It is a drift, not a climb or a descent (Zack, 2026-11-20: "if AMB-1 is randomly choosing, then that's what we'll do").
- **The way home (AMB-1 never comes home).** The last body window is drawn from a cadence list instead of the walk, so the return sounds like an arrival. It takes whatever bars are left, so it can run up to 3 bars past the pace, and it skips the chord already playing.
  - Ionian: IV 0.5, ii 0.25, V 0.25;
  - Lydian: II 0.4, V 0.3, vi 0.3;
  - Mixolydian: bVII 0.4, IV 0.4, v 0.2;
  - Dorian: IV 0.5, bVII 0.3, ii 0.2;
  - Aeolian: iv 0.4, bVII 0.3, bVI 0.3.
- The outro is the tonic.
- The windows go into structure.chordPlan, and each SongSection takes the Zen mode, so TonalGovernanceBuilder, the log and the chord display follow.

## 6. No clashes: the rules every track obeys

"Clash" uses Zack's grading:
- **Glaring:** a semitone within an octave; a major 7th with the non-chord note below; or a minor 9th held two beats or more with both notes at C3 (MIDI 48) or above.
- **Mild:** two or more octaves apart, or short.

The target is zero glaring clashes in the MIDI. Each rule is enforced in the generator that writes the note.

1. **One scale.** Every note of every Zen track is in the song's mode. No chromatic notes, no borrowed chords.
2. **The Texture drone fits every chord.** It holds the tonic and the fifth. In each window it drops either one that is a semitone from a chord tone, or 1 or 13 semitones from a bass note the window may hold, and it always keeps at least one. The drops:
   - Ionian and Lydian iii and V: the tonic drops (it rubs the leading tone) and the fifth holds.
   - Aeolian ii, iv and bVII: the fifth drops (it rubs the b6) and the tonic holds.
   - Lydian II and #iv: the fifth drops (it rubs the #4) and the tonic holds.
   - Aeolian bVI: the fifth drops under the bass octave (G3 under Ab3 in C); the tonic holds.

   No window loses both notes, because vii is out of Ionian and Lydian. A drone note crossing into a window that drops it ends at that window's first step and comes back at the start of the next window that allows it.
3. **Fixed registers keep the low voices apart.**
   - Bass: MIDI 36 + the root's pitch class, so 36 to 47. Its fifth folds down an octave when it would pass 47 (59 for AMB-BASS-008's upper note).
   - Texture tonic: the tonic in 48 to 59. Texture fifth: 7 above it, 55 to 66.
   - Pads: 48 to 77.
   - With vii out, the bass never sits on the leading tone under the Texture tonic. The bass's midpoint move to the fifth is skipped when that fifth is the leading tone (Ionian and Lydian iii).
4. **Pad voicing.** AMB-1's nearest-movement permutation (en_voice_lead) over the window's four chord tones inside 48 to 77, with extra costs of 40 each for two voices on one note, two voices 1 or 13 semitones apart, a voice 1 or 13 semitones from a Texture note or from any note either bass rule may hold in the window, and a leading-tone voice below the Texture tonic. So a maj7 chord voices its 7th above its root, never as a semitone or minor 9th. Voicings are fixed per window, with no randomness.
5. **The handoff stays clean.** At a chord change, a pad voice whose note isn't in the new chord ends at the change. A voice that carries over must also sit clear (not 0, 1 or 13 semitones) of the new voicing, the Texture and every bass note the window may hold. So during the lag only clean common tones carry over.
6. **Joins.** At a window change the old bass root ends exactly where the new root starts, with no overlap. Same-pitch joins (Texture's next note, bass re-strikes) abut exactly, because the sampler's note-off for the old note would cut the new one; playback fires a step's note-offs before its note-ons, so the join is seamless. A 1-beat overlap is used only where the pitch changes inside one chord (root to fifth, and AMB-BASS-008's lower note under the upper re-strike).
7. **Bell notes.** A bell note is written only if all of these hold:
   - It is a chord tone or a safe tension of the window in force at its step.
   - A tension never falls on beat 1 or 3 (step % 16 = 0 or 8).
   - **Sounding check:** over the note's onset plus 2 beats (8 steps), it is not 1 or 13 semitones from any Pads, Texture or Bass note, nor from an earlier bell track's note. Tracks are written in the order Pads, Texture, Bass, Lead 1, Lead 2, Rhythm, each reading the finished events before it. The check covers a chord change inside the ring.
   - A candidate that fails moves to the nearest chord tone that passes (ties go down). If none passes, the slot rests for that pass.
8. **Lead 2 answers Lead 1.** Lead 2 drops any note whose onset is a Lead 1 onset.
9. **What is left is mild and accepted.** Echo and reverb tails of an in-scale bell ringing into the next chord. The echo's low-pass darkens each repeat. tools/clash_scan.py can't see tails, so this is judged by ear.

## 7. The bed: pads, Texture and bass

**Song shape.** The Ambient frame length (180 to 315 s) at the Zen tempo. One body section A, then the 6 to 12 bar outro; no intro. The pads, Texture and bass start at bar 1. The music ends 2 bars before the song (the reverb tail), and the 6 bars before that are the held breath (fewer when the outro is short). The song is trimmed to the last bed note plus the tail, as Ambient Piano trims; in practice it never cuts, because one bed track always holds to the end.

**Pads: AMB-PADS-011 Airports Breath.** Four voices, each breathing on its own cycle (AMB-1's numbers).
- **Cycle.** Seconds = (4 + 0.12 × breath length) × the voice factor (1.0, 1.21, 1.43 or 1.67) × random 0.85 to 1.15, redrawn at every breath: about 8 to 25 s. Steps = seconds × tempo / 15.
- **Start.** Voice 1 starts at once; voices 2 to 4 start within about 3 s, and the cycles then drift apart.
- **Breath.** One MIDI note per breath. The note-off falls at 90 percent of the cycle for every preset, so each voice rests briefly and the rests rarely line up. Velocity = 50 + 40 × peak, with the peak random 0.6 to 1.0, nudged by the swell (section 8).
- **Chord change.** A sounding voice whose pitch class is in the new chord carries on to the end of its breath. One that isn't ends at the change, and its next breath starts 1 s later on its new target, at 85 percent of the usual cycle. A resting voice takes its new target at its next breath. This is the bass-leads, pads-lag effect; the pads never snap to the change.
- **The held breath.** For the last bars of music all four voices take the tonic chord and hold.
- **Staggered endings.** The pads, Texture and bass don't stop together. One track holds to the end of the music; the other two stop 1 and then 1 to 2 more bars earlier, in an order drawn per song, so all three still sound together for at least 2 bars of the hold.

**Texture: AMB-TEXT-012 Pearl Pedal.** A held tonic drone, with the fifth in about 60 percent of songs (elsewhere the fifth stands in only where the tonic drops), in the registers of section 6.
- Each note lasts 3 to 5 bars, and the next starts exactly where it ends, on the same pitch, so it never gaps.
- Velocity 40 to 54, nudged by the swell.
- It ends inside the held breath (staggered endings).

**Bass**, rolled per song:
- **AMB-BASS-007 Airports Root** (0.60). The chord root, one note per window, velocity 54 to 62. Long windows are re-struck every 8 bars, never leaving a stub under 2 bars. At the window's midpoint, with probability 0.35, it moves to the fifth.
- **AMB-BASS-008 Plateaux Octave Root** (0.40). The root doubled at the octave for the first 2 bars of the window, then the upper note alone re-struck for the rest. At the midpoint, with the same 0.35 chance, the upper note moves to the fifth. It's fuller, and it carries on a phone speaker.
- **Sit-outs.** Either rule sits a window out with probability 0.3 × restlessness + 0.25 × max(−swell, 0), never the first or last window and never two windows running.

**Swell presets.** AMB-1's bed is slow swells with no audible attacks, and a stock preset re-attacks on every breath. Zen's swell sounds are copies of existing presets in a new soundfont bank (bank 14), each setting the volume envelope's attack to about 5.6 s and release to about 4.5 s. A copy is a new preset record pointing at the existing instruments and samples, so no sample data is copied and no existing program moves; editing a stock preset in place would have changed every style that uses it. They are made by tools/sf2_clone_presets.py and load through the ordinary bank decode in setProgram.

## 8. The bells and the swell

**The bell loop.** One helper (AmbientZenLoops) shared by Lead 1, Lead 2 and Rhythm, walking the song one pass at a time.
- **Loop lengths.** 13 beats for Lead 1, 17 for Lead 2 and 23 for Rhythm. They are prime, so the loops never line up.
- **Register.** AMB-1's base notes: Lead 1 72, Lead 2 67, Rhythm 79. A note's pitch is the tonic at or below the base plus the scale steps, folded into MIDI 36 to 103.
- **Slots** (AMB-1's rand_offset). One slot per quarter-note beat, each holding a scale step above the current chord's root, so the loop re-harmonises when the chord moves, even partway through a pass. A new slot is a chord tone 72 percent of the time (steps 0, 2, 4 or 6), a further octave up 30 percent of those times, and otherwise the 2nd, 4th or 6th above the root. A chord step is even within the octave (AmbientZenLoops.isChordStep); 1, 3 and 5 are the passing steps. A passing step that resolves to an avoid note, or falls on beat 1 or 3, moves to the chord tone below. A slot keeps its offset, velocity and length from pass to pass.
- **Note count.** floor(clamp(density × 0.05 × (1 + 0.8 × swell), 0, 5) + random 0 to 1).
- **Per-pass changes** (AMB-1's), with r = restlessness: add or remove notes to meet the target; rest the pass with probability 0.15 × r + 0.15 × max(−swell, 0); and with probability 0.7 × r change one slot's note or move it to an empty slot.
- **Octave ring.** With probability 0.08 + 0.12 × max(swell, 0), the note also sounds an octave up at 40 percent velocity. The roll is made for every slot, so a rest or a dropped note never shifts the draws after it.
- **Every note** passes section 6, rule 7.

**AMB-LD1-011 Airports 1/1 Loop** on Lead 1, every song. The plain AMB-1 loop, velocity 40 to 80, notes 2 beats long. After Music for Airports 1/1.

**AMB-LD2-014 Airports 1/2 Answer** on Lead 2, 85 percent of songs. The same loop, softer (velocity 42 to 70), dropping any note on a Lead 1 onset. Otherwise Lead 2 rests, logged AMB-LD2-000 No lead 2.

**AMB-RTHM-007 Lux Glass** on Rhythm, 80 percent of songs. One to three short high chord tones (2 to 4 steps) per 23-beat loop, velocity 35 to 60. Otherwise Rhythm rests, logged AMB-RTHM-000 No rhythm.

**Entries and exits.**
- Lead 1 enters at a random bar from 2 to 4, Lead 2 at bar 6 to 8, Rhythm at bar 9.
- They leave in reverse order: Rhythm first, Lead 2 4 bars later, and Lead 1 at the pads' held breath. Notes are clipped so none rings into the next exit, and no bell sounds in the held breath.

**The swell** (AMB-1's arc, renamed so it doesn't collide with base Ambient's arcs).
- A value per bar from −1 (sparse) to +1 (full). Every 50 to 150 s a new target is drawn (random −1 to 1 × (0.6 + 0.4 × random), pushed 0.25 further from the middle, clamped), and the value eases toward it with a 35 s time constant, then is scaled by the song's depth, 0.5 to 0.9.
- It is held at −0.5 or below for the first 8 bars and in the outro.
- It sets the bell note counts, the rest chance and the octave ring, adds to the bass sit-out chance, and nudges pad and Texture velocity by up to ±10 percent. It adds no draws to the bed, so the bed's notes don't depend on it.

## 9. Instruments

Zen's sounds are appended to the Ambient pools, so base Ambient and Ambient Piano keep their old indices (their pick lists are capped at the old counts). Zen draws only from its own short lists. Bells may share a sound across tracks, because AMB-1 plays every bell loop on one voice; the rule is only against unintended duplicates. Voices are kept rare: a voice on a track that holds all song is a wall of sound (Zack, 2026-11-21).

- **Pads, Rhodes-like:** Warm Pad, Halo Pad, Fantasia, FM Piano, Warm Swell, Halo Swell.
- **Pads, glass and strings:** Glass Swell, Strings 3 Swell, Strings 5 Swell.
- **Texture:** Tonewheel, Solar Swell and Sine Swell, 85 percent together; Choir Aahs and Space Voice, 15 percent together.
- **Bass:** Synth Bass 101, Saw Bass Swell, Brass Swell, Pulse Swell, Bass Swell, Synth Swell, Polysynth Swell. All synth, all long-sustaining.
- **Lead 1:** Vibraphone, Tine EP and Harp, 30 percent each; Echo Drops 10 percent. Echo Drops sounds like a choir, so it never plays two songs running (noRepeatInstruments) and the Lead 2 lock never copies it.
- **Lead 2:** Tinkling Bells, Christmas Bells, Kalimba, Harp.
- **Rhythm:** Glockenspiel, Celesta, Tinker Bell, Synth Chime, Christmas Bells.
- **Lead 2 lock.** In 25 percent of songs (the dial), when Lead 2 plays and Lead 1 isn't Echo Drops, Lead 2 takes Lead 1's instrument, logged "Lead 2 <name> locked to L1".

**Gain trims** in setProgram, by ear: Tonewheel 0.8, Solar Swell 0.8, Sine Swell 0.7 (all against the Ambient Texture boost of 2.0); Bass Swell 0.56, Polysynth Swell 0.5, Brass Swell 0.25. Not yet set: the Saw Bass, Pulse and Synth Swell basses, and every bell.

## 10. The space: reverb, echo, pans and chips

All through existing settings, in PlaybackEngine's Zen branch (applyAmbientZenAudio).
- **Reverb.** The large bus switches to .largeHall2: Pads 75, Lead 1 68, Lead 2 68, Rhythm 70, Texture 55. Bass 10 and Drums 35 go to the small .mediumHall bus, so the bass stays almost dry and centred, as in AMB-1. perTrackReverbPresets matches, for export.
- **Echo.** Feedback 0.5 + 0.32 × echo size (74 to 79 percent). Lead 1 echoes every 2 beats and Lead 2 every 1.5 (AMB-1's two tape heads), Rhythm every 1.5, Texture every 2; capped at 2.0 s. Wet: Lead 1 45, Lead 2 50, Rhythm 48, Pads 15, Texture 10, Bass none. The low-pass is 2600 Hz on the bells and 1800 Hz on Pads, so each repeat comes back darker.
- **High-pass.** Base Ambient's 250 Hz high-pass stays on the leads but is off Texture, whose fundamental is 131 to 370 Hz.
- **Pads.** Tremolo 0.06 Hz (a 17 s cycle) at depth 0.30; a filter sweep from 1000 to 3000 Hz.
- **Bass.** Tremolo 0.08 Hz at depth 0.15. The sweep, if switched on, is an ordinary LFO.
- **No per-note fade** on Pads or Bass: it is one volume ramp per track, so with overlapping notes each note-off would duck the notes still sounding. The breath comes from the note timing and the swell presets.
- **Pans.** Lead 1 −0.6, Lead 2 +0.35, Pads 0.10. Rhythm swings ±0.35 around +0.6 on a slow auto-pan, one sweep per 8 bars.
- **Chips.** Defaults: Pads Hall, Trem, Sweep and a hidden Delay (the 15 percent echo); Texture Delay, Reverb; Bass Reverb, Trem; leads Delay, Hall; Rhythm Delay, Hall, Pan; Drums none. TrackRowView and AppState.restoreDefaultEffects carry the same table.

## 11. The log

- **Title:** Zen has its own titles (AmbientZenTitleGenerator, in AmbientTitleGenerator.swift), gentle jokes on Eno with extra airport humour, at most 19 characters: "Music for Layovers" (30 percent), Eno spoofs such as "Thursday Nap" or "Neroli Ravioli" (35), place plus fraction such as "United Delay 2/1" or "1/1 (Decaf)" (20), and Oblique Strategies twists such as "Honor Thy Nap" (15). The title is the last draw, so no note depends on it.
- **Style:** "Ambient Zen – 72 bpm, 9 bar outro". There is no Form line, since every song is A and an outro.
- **Chords:** key, mode, pace and the way home, for example "G Dorian quick 7th chords drifting, home via IV7", or "home on I" when the last body chord is the tonic. The pace reads quick (under 37 s), steady (under 49 s) or slow.
- **Zen:** "Breaths: long, Echo: medium, Bells: sparse, Drift: calm, Swell: deep". The pad colour isn't named, because the Instruments line shows the pads.
- **Rules,** in track order: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums. Drums always logs AMB-DRUM-000 No percussion until the phase 3 pulse. Zen's lead rules use LD1 and LD2, because each belongs to one lead.
- No line per chord change; no style logs one.
- New rules carry the "* " testing star (GenerationLogEntry.testingMarkedRules) until a 4.0 release. Rules are starred only when Zack asks.

## 12. Regeneration and Evolve

**Regeneration.** Regenerating a Zen track rebuilds the ZenPlan from the seed and regenerates that track, then rebuilds the bells after it on their own seeds, because the sounding check depends on what came before: a bed track rebuilds all three bells, Lead 1 rebuilds Lead 2 and Rhythm, Lead 2 rebuilds Rhythm. A bell track's seed is its override in trackOverrides, or else its Zen index. A bell track with an override always plays, so a regenerated Lead 2 never comes back silent, and a reload's replay gives the same song in any order. Drums don't regenerate in Zen.

**Evolve** follows the normal passes (Zack, 2026-11-21):
- Pass 1 regenerates Lead 1 and Lead 2 and gives them new instruments.
- Pass 2 regenerates Pads and Rhythm and gives them new instruments.
- Each runs through Zen's own regenerate branches, so the bells are rebuilt clash-free against the new tracks. A Lead 2 or Rhythm that was silent in the song plays in its pass.
- Zen never adds the absent Bass or Drums in a pass (the generic drum path would bring in base Ambient percussion), and it skips the new-rule retry, since every Zen track has one rule.
- Texture stays MIDI: Zen never sets an audio texture, in generation, Evolve or regeneration.

## 13. Phase 3: variety

Each item is independent and can be built or skipped on its own. Specs are in the old plan, sections 6, 10 and 13.
- **AMB-DRUM-005 Garden Pulse.** A very quiet kick, closed hat and open hat on Euclidean patterns of 16, 12 and 7 steps, in songs whose pulse dial is on, on seed index 127. Brush Kit. It follows the swell and never goes fully silent. Songs without it keep AMB-DRUM-000.
- **AMB-PADS-015 Big Ship Cycle.** Some songs repeat one 8-chord cycle (A B T B A B T C, where T is the tonic) at 4 bars a chord, with block-chord pads, while layers add on top. Same chord table and clash rules.
- **AMB-PADS-014 Airports 2/1 Field.** Some songs hold one pitch field with no chord changes, and each pitch breathes on its own loop.
- **More Evolve.** A pass could bring a short chord walk of its own, flip the pad colour, or shift one note of the mode (Ionian to Mixolydian and similar), which must re-run section 6, rule 2 against the shifted scale.
- **AMB-TEXT-011 On Land Bell** as an alternative Texture rule: a distant tower bell on a 29-beat loop, root or fifth only.

## 14. On the shelf

These come back only if a listen says Zen is missing them. Details are in the old plan.
- **The eight named AMB-1 recipes.** The dials do the job.
- **Bass glide** (a pitch-bend slide between roots). Zack liked it in AMB-1, so expect it back. It is new playback code (RPN bend range, seek handling).
- **Drift** (a slow per-track pitch wander). A new effect chip and new playback code.
- **Edge fades on Bass and Texture.** The per-note fade can't tell an edge from a join without new engine logic.
- **The colour chord** and its clash guards.
- **Pentatonic modes.**
- **Composed phrases.** Ruled out (Zack, 2026-11-14) because AMB-1 has none.
- **Micro-timing on the bells, swing, a shared echo bus, and an audio drone on Texture.**

## 15. Where it lives in the code

**Zen's own files** (Sources/Zudio/Generation/Ambient/)
- AmbientZenPlan.swift: the dials, chord table, window layout, walk, cadence, Texture and bass keep rules, structure, swell, and the log words.
- AmbientZenTracks.swift: AMB-PADS-011, AMB-TEXT-012, AMB-BASS-007 and AMB-BASS-008.
- AmbientZenLoops.swift: the bell loop, the three bell rules, the sounding check and writeBells.

**Branches in shared files**
- **SongGenerator:** the substyle roll and shares, generateAmbientZen (dials, frame at the Zen tempo, plan, bed, bells, trim), buildAmbientZenLog, rule descriptions, and the Zen branches of regenerateTrack with the bell rebuild.
- **SongState:** isAmbientZen, passed in the initialiser and every withXxx() copy method; displayStyleName "Ambient Zen"; the testing stars.
- **AppState:** reload (forced "Zen"), the Ambient pools (instrumentPoolNames and instrumentPoolPrograms), Zen's pick lists in instrumentPickPoolStatic, noRepeatInstruments (Echo Drops), the Lead 2 lock in applyLead2Mirror, restoreDefaultEffects, and Evolve.
- **PlaybackEngine:** applyAmbientZenAudio (halls, sends, the zenDelayWet, zenDelayBeats and zenDelayLowpass tables), staticPans and startPan, the per-note fade skip, and gain trims in setProgram.
- **TrackRowView:** Zen chip defaults, mirrored in restoreDefaultEffects (and any onChange logic mirrored in PhonePlayerView).
- **assets/Zudio.sf2:** the bank 14 swell presets.

**Tools**
- tools/zen_fpcheck.sh with tools/fingerprints/ambient-zen-baseline.txt: proves base Ambient and Ambient Piano unchanged.
- tools/sf2_clone_presets.py: makes the swell presets.

## 16. Checks

- **Base Ambient and Ambient Piano unchanged.** Run tools/zen_fpcheck.sh (unsandboxed, ZEN_SCRATCH set to the build folder) after any generator change. Every line must read "identical"; the "class X -> Ambient_Zen" lines are expected while the testing shares are in force. Check again at release shares before shipping.
- **Build plus one suite** while working (InstrumentPoolDriftTests after any pool or pick-list change); no full test runs.
- **Clash checks.** At the last full check, 200 Zen songs had no glaring clashes in the bed, no bell note 1 or 13 semitones from another track, no out-of-scale notes, no unsafe tensions, no tensions on beats 1 or 3, and no bell in the held breath. Re-run after any change to the bed or the bells; any glaring hit is a generator bug.
- **Reload.** Regenerated tracks replay exactly on reload, in any order (checked on 40 songs).
- **By ear.** Zack's ear decides, and the tiebreaker is his: Zen should sound more different from base Ambient, not more similar.
