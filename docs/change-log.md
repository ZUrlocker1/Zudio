# Zudio Change Log

## V 2.9 (Build 136) — Hook leads and gap-answer leads

Build 136 is a near final version of 2.9, with minor tuning expected over a few days of listening and the App Store post likely by mid November. The plan is `docs/Solo-improvement-plan.md`.

- **Kosmic B sections play the rule they log** — (2026-11-11) When base Kosmic Lead 1 was KOS-LD1-002 Eno floating tones or KOS-LD1-003 Pentatonic drift, the B section was meant to step up to KOS-LD1-006 JMJ evolving phrase 60% of the time, and the log said so, but B played Floating tones instead, so a Floating tones song had no contrast at all. B now plays the JMJ phrase, built for the section as in a JMJ song. Songs whose Lead 1 is JMJ evolving phrase, Caligari solo or Dark Sun solo no longer list a B rule that never played. About one base Kosmic song in ten changes from its B section on.
- **Call and answer in major keys** — (2026-11-11) In Ionian, Mixolydian, Lydian and major pentatonic, MOT-LD1-005 Call and answer played its call as 1 2 2 5 and its answer as 4 2: a helper meant to find the mode's third found the second. It now plays 1 2 3 5 and 4 3, with the major third. Minor keys are unchanged.
- **Arcade drum intros and outros** — (2026-11-11) Arcade songs on MOT-DRUM-011 Light four or MOT-DRUM-012 Sparse fills played a Classic Motorik beat in an Already playing intro and a Fade or Cold stop outro, so the groove changed at both seams. They now play their own pattern there: Light four with its kick, Sparse fills with the song's backbeat or sidestick.
- **Arcade arp Lead 2 thins evenly** — (2026-11-11) When Lead 2 outweighs Lead 1, a thinning pass keeps only part of it in each 8-bar window. It kept the first third or half of the notes, so an Arcade arp (Arcade Arp, Gate Arp, Bounce Arp, Blip) played the front of each window and went silent for the back. It now keeps whole two-bar figures spread through the window, with rests between them. The Motorik Europe Lead 2 doubles (Counter Sequencer, Octave Unison) are no longer thinned at all, as the arrangement filter already left them alone.
- **Noir Rhythm weights add up** — (2026-11-11) The Noir Rhythm pool summed to 102%, which left MOT-RTHM-013 Levene Drop at 10% instead of 12%. MOT-RTHM-011 Three-One Stab is now 12% (was 14%), so Levene Drop gets its share. Some Noir songs change Rhythm rule.
- **Noir Hook ascent bass stays in register** — (2026-11-11) In Noir, MOT-BASS-007 Hook ascent plays an octave higher as the melodic voice, but an Already playing intro and a Fade or Cold stop outro played it at the normal register, a drop of an octave at both seams. They now match the body.
- **Motorik intros and outros in the song's mode** — (2026-11-11) The intro's scale was built in Dorian whatever the key, so in a major key the third and seventh of the tonic chord were marked as notes to avoid. The outro's tonic chord could also take the chord type of a different degree and become a tonic minor in a major key. Both now follow the song's mode.

- **No more long gaps in the Motorik leads** — (2026-11-11) Some songs went more than 24 bars with no Lead 1 at all, and some 30 or 40. Outside Noir, which is sparse by design, Lead 1 now never leaves more than 24 body bars silent. A hook song fills a long silence with a soft fragment of its hook: the head, the head said twice, the answer or a varied statement. A Vanishing solo or Visiting solo song adds a short return, now also before the full solo when it comes late. Stepwise sequence and Call and answer no longer let their random silent bars run past 10 in a row. A solo rule is never drawn for the B section alone, which had left B empty, up to 60 bars in a long song. The arrangement filter softens a Lead 1 block instead of resting it when a rest would open a longer silence.
- **Hook statements spread evenly** — (2026-11-11) A hook song now decides how many times it states its hook before placing any, then spreads them evenly: the first at Lead 1's entry, the last in the last fifth, each moved to the nearest bar clear of rest windows and breakdowns. The fragments above are placed in the same pass. The old layout placed statements, removed some to meet the count, added others back and then patched the gaps, and those steps undid each other. The counts are unchanged, 3 to 6 a song, but statements no longer bunch up with a long hole elsewhere. Kosmic hooks (Pulstar theme, Beach Scene sigh, Blade Runner theme) share the new layout and take no fragments. Hook songs, Motorik and Kosmic, place their statements differently from the same seed.
- **Lead 2 regen keeps the solo bars** — (2026-11-11) Regenerating Lead 2 in a Vanishing solo or Visiting solo song now sees the same solo windows that generation did, so Low bed and the answers fill the same bars as before the regen.
- **New rules replace the old lead rules** — (2026-11-10) The weakest early Lead 1 and Lead 2 rules in base Motorik and base Kosmic are gone. Each new rule plays material taken from a real record, mapped to the song's mode and reworked per song as homage, and each took the number of the rule it replaced. The old rules are deleted from the code. Songs saved earlier reload with the new rules, and a saved song that forced an old lead ID loads the rule that replaced it.
- **How much of Zudio changed** — (2026-11-10) A rough count over a few hundred songs: about 76% of base Motorik songs and 56% of base Kosmic songs now use a new or lightly changed Lead 1 rule, and about 41% of base Kosmic songs use one of the three new hooks.
- **Radioactive riff is less busy** — (2026-11-10) The full MOT-LD1-002 Radioactive riff played ten notes a bar, half of them 16ths off the 8th grid, the only Motorik hook built that way, and it was hard to hold in mind (Nacht Hamburg, Rein Nacht). It is now on 8ths like the other hooks: pickup 5, then 1 5 1 with the root held through beat 2, then 3 2 1 with the root held to the end of the bar, about 4 notes a bar. Its per-song homage only drops a note or swaps a pair, so the held roots stay. Halving the off-beat 16ths was tried first and made too little difference. Songs with this hook place their statements differently from the same seed.
- **Solo comes earlier and returns more often** — (2026-11-10) The full Vanishing solo or Visiting solo used to start in the middle third of the A section, bar 78 in Ost Hannover, so it was heard once, late. It now starts between bars 24 and 48 (short A sections are clamped so it still fits). A second shorter return is now the likelier case, 60% of songs instead of 40%, on top of the long-silence fills below. Songs from the same seed place the solo differently.
- **One Zudio at a time on Mac again** — (2026-11-10) Build 136 allowed several copies of Zudio to run at once, which made a double-clicked .zudio file open in whichever copy macOS had registered, an old one in Applications for example, and not in the copy already running. The single-instance setting (`LSMultipleInstancesProhibited`) is back, so a file always opens in the running app. A .zudio file reloads by regenerating from its seed with the code of the app that opens it, so check the "Zudio Version" line in the log if a song sounds out of date.
- **Solo songs stay filled** — (2026-11-10) In a base Motorik song with Vanishing solo or Visiting solo, any stretch of more than 24 bars with no solo gets a further shorter version near its middle, a different cut from the others, so Lead 1 does not vanish for fifty bars.
- **Lead 2 plays with the solos and fills long silences** — (2026-11-10) Lead 2 used to stay out of every Lead 1 solo, so a Visiting solo song such as Kalt Feld had about 3 Lead 2 notes. Now it plays in the solo windows: Low bed places its own beds there, Statement harmony harmonises the solo, and the answers fit the gaps in it. Motorik Lead 2 rules are also thicker and each has its own flavour: Echo answer takes 3 to 6 notes and repeats them softer, like a delay; Hook fragment comes round again a step lower; Statement harmony is a horn-section part, not a copy; Low bed carries on through every Lead 1 silence of four bars or more. Echo answer and Hook fragment state themselves 6, 8 or 10 times, plus one for every 8 silent bars, and rest 6 to 8 bars between restatements, so a long silence has gaps in it. Hook songs went from about 15 Lead 2 notes to about 60 to 80 for Echo answer and Hook fragment and about 30 for Low bed.
- **Four new Motorik Lead 1 rules** — Hooks from the records, each replacing a base rule:
  - MOT-LD1-001 Hallogallo hook replaces Neu! motif first.
  - MOT-LD1-002 Radioactive riff replaces Pentatonic cell.
  - MOT-LD1-003 Tour de France riff replaces Punch solo.
  - MOT-LD1-006 Model riff replaces Long arc solo.
  - MOT-LD1-005 Call and answer is kept in every pool.
- **Five new Motorik Lead 2 rules** — Base Lead 2 now answers Lead 1 in its gaps instead of playing over it. It is silent while Lead 1 plays a phrase and states an answer 4 to 6 times a song (more for some rules, see the entry below on Lead 2 and the solos). They replace Counter-response, Sustained Drone, Rhythmic Counter, Neu! counter melody, Descending line and Neu! harmony:
  - MOT-LD2-001 Echo answer, Lead 1's last notes a third, sixth or octave lower.
  - MOT-LD2-002 Low bed, the chord's root or fifth held under Lead 1's long notes.
  - MOT-LD2-003 Hook fragment, the opening of Lead 1's last phrase, inverted or a step down.
  - MOT-LD2-004 Answer cell, a short cell paired with Lead 1's rule.
  - MOT-LD2-006 Statement harmony, every second Lead 1 statement as a horn-section part: a third, a fifth or a unison under it, 60% of statements simplified to the notes on the beats.
  - Arcade's arp rules and the Europe sync rules are unchanged; Arcade's regular pool uses MOT-LD2-001, 003 and 004.
- **Three new Kosmic Lead 1 rules** — Hooks from Vangelis and Tangerine Dream, each replacing a base rule:
  - KOS-LD1-001 Pulstar theme replaces Slow arc.
  - KOS-LD1-005 Beach Scene sigh replaces Arpeggio highlight.
  - KOS-LD1-007 Blade Runner theme replaces TD skip sequence.
- **Three new Kosmic Lead 2 rules** — Base Kosmic Lead 2 is the same gap-answer design, slower: KOS-LD2-002 Slow echo answer, KOS-LD2-003 Slow answer cell and KOS-LD2-004 Gap reply melody. They replace the shared KOS-LEAD pool that either lead could draw. In every Kosmic song Lead 2 also joins Lead 1 for two to six four-bar windows, a third below it 65% of the time and in unison 35%, so it is more than a handful of notes in 100 bars without getting busy.
- **Kosmic leads renamed** — Kosmic Lead 1 rules are now KOS-LD1, so Lead 1 and Lead 2 never share an ID, as in the other styles. The old KOS-LEAD-002, 003, 004, 006, 008 and 009 are KOS-LD1-002, 003, 004, 006, 008 and 009, with the same names.
- **Kosmic Space Lead 2** — (2026-11-10) The Echo melody it borrowed from Lead 1 is now KOS-LD2-005 Space echo reply. It starts its cycle two bars later, so it falls where Echo melody rests, and the echo is always a third below.
- **Lead rule weights** — Base Kosmic Lead 1: Pulstar theme 15%, JMJ evolving phrase 15%, Beach Scene sigh 14%, Blade Runner theme 14%, Eno floating tones, Pentatonic drift and Caligari solo 9% each, Dark Sun solo 8%, Echo melody 7%. Base Kosmic Lead 2: Slow echo answer 35%, Slow answer cell 35%, Gap reply melody 30%. Base Motorik Lead 1: Hallogallo hook 15%, Tour de France riff 15%, Radioactive riff 14%, Model riff 12%, Vanishing solo 12%, Stepwise sequence 11%, Call and answer 11%, Visiting solo 10%. Base Motorik Lead 2: Answer cell 25%, Echo answer 22.5%, Hook fragment 22.5%, Low bed 15%, Statement harmony 15%.
- **How a hook plays** — The song states its hook 3 to 6 times in the body (Kosmic 3 to 6, Pulstar 4 to 6). The first statement is the full hook and the last, near the end, is the full hook with its last note ringing. Between them a statement is the full hook again or a real variation: the head alone, the head said twice, the answer alone, the call as a sequence a scale step up or down, or the hook with a dropped note, an alternate ending, a held-over last note or the answer withheld. After a variation the full hook returns often. At least one statement always falls in the last third.
- **On the beat** — Every Motorik hook note sits on the 8th-note grid with the held notes on beats, so the line locks to the kick and snare. Variations keep to the grid. The Radioactive riff, a 16th-note riff on the record, is re-gridded onto 8ths.
- **Placed around the arrangement** — Statements avoid Lead 1's rest windows and the base Motorik breakdowns. The arrangement filter only softens a hook lead and never silences a block of it. A hook stays in one octave for the whole song.
- **Kosmic solos kept whole** — KOS-LD1-008 Caligari solo and KOS-LD1-009 Dark Sun solo are no longer rested by the arrangement filter, which had taken whole windows. Caligari widens its note pool when a chord leaves it fewer than four chord tones, and Dark Sun always plays at least twice.
- **Testing marker** — While the rules are being tuned, the generation log prints a star before each new rule's name, under its new number.
- **Motorik mix** — Moog, Synth Bass 3 and Rock Bass on the bass are about 1.8 dB quieter, and Lead Bass about 2.7 dB. Synth Lead, Saw Stack and Polysynth on Lead 1 are about 2.3 dB louder. **Kosmic mix** — Mono Synth on the bass and Harpsi Pad on Rhythm are quieter so the hooks sit forward.

## V 2.9 (Build 135) — Kosmic Space

In the source on `main` (merged 2026-11-02). Published 2026-11-03 as the 2.9 download; finished 2026-11-09 (Kosmic split Drift 25 / Space 35 / base 40) and headed for the App Store after a few days of listening.

- **Smoother playhead in track view** — (2026-11-09) The playhead was drawn in whole 16th-note steps and sampled at 15 fps, so it jumped unevenly. It now moves by its exact position in time and redraws at 20 fps when 8 bars or fewer are showing (wider zooms stay at 8 and 4 fps), on Mac, iPad and Duo. Changed in MIDILaneView and AudioWaveformView, with `wallClockPosition` added to PlaybackEngine.
- **New Kosmic Space substyle** — (2026-11-02) A Jean-Michel Jarre substyle of Kosmic, built from rules measured on 16 MIDI transcriptions of his music. This first phase models *Oxygene*. A locked root-and-octave sequencer runs over fast minor chord cycles of 2- and 4-bar chords, with the Minipops preset rhythm box, a falling Oxygene bass, a slow falling theme in the A sections and a see-saw riff in the B sections, string-machine pads and white-noise surf sweeps into the section changes. Every rule varies its source figure per song, so no song copies the original. Six new rules: KOS-DRUM-009 Oxygene Preset Box, KOS-BASS-018 Oxygene Falling Walk, KOS-RTHM-016 Oxygene Octave Sequencer, KOS-LD1-013 Oxygene Falling Theme, KOS-LD1-014 Oxygene See-Saw Riff and KOS-TEXT-005 Oxygene Surf Sweep.
- **Space tuning after listening** — (2026-11-03) The first stretch where the drums thin always takes the bass with it. The Falling Walk bass gains a breath bar (second bar of each 8, last short note drops) and a turn (last bar before a new section, final note lifts), lighter than the Pump's variations. JMJ Mini Pops drops out completely in the first two thin stretches and returns on a 1 or 2 beat tom roll. Hand Percussion thins over every bass or drum stretch, never plays the guiro there, and is now 13% of Space songs (Preset Box 38, Mini Pops 34, none 15); its guiro is quieter. Lead 2 Saw Lead and Square Lead 2, Rhythm Moog and Lead 1 Synth Brass 2 are trimmed again. The redundant `Space Oxygene, ...` generation log line is gone.
- **Less busy, cleaner fills** — (2026-11-03) The Oxygene 8 Pump bass is no longer drawn under the Octave Sequencer, the busiest pairing at about 22 notes a bar under the lead; the Falling Walk takes its place. The Berlin School drone drops out where the other basses thin and returns under the closing fill. The claves fill, an acoustic knock against an electronic kit, is now a kick and snare fill that lands on a crash. ArrangementFilter no longer touches Space's Lead 1, Lead 2 or Pads, whose rests come from the Space arrangement.
- **Drift regen fix** — (2026-11-03) Regenerating Lead 1, Pads, Rhythm, Bass or Drums in a Kosmic Drift song with a bridge now applies the bridge's treatment again, so the bridge no longer fills back in.
- **New Space lead rule** — (2026-11-03) KOS-LD1-017 Oxygene 8 Offbeat Climb, measured from the Oxygene 8 lead: off-beat statements that climb by step from a leap to the chord root, a falling answer, and an arch figure every third phrase. It shares Space's A sections a third each with the Falling Theme and Rising Strings.
- **Space theme return** — (2026-11-03) Songs that end on a B section bring Lead 1's A theme back for 8 bars two thirds of the way into that last section.
- **Testing share** — While Space is being tuned, 50% of Kosmic songs are Space, 25% Drift and 25% base Kosmic. Drift and base stay at 25% each at release; Space comes down to its final share and base takes the remainder.
- **Breaks** — (2026-11-02) A Space song breaks its repetition as the Oxygene records do. Lead 1 rests for 16–24 bars, the sequencer thins while the lead plays and fills out while it rests, the sequencer drops out once for 4–8 bars, and a noise swell marks each return. A short tom-roll fill comes before a break or return, at most three a song. The playback log calls out the sequencer break, for example `Bar 071  Sequencer and Lead 2 drop out`.
- **Space instruments** — Synth Brass 1 and 2, 5th Saw Wave and Bright Saw Stack for Lead 1; Synth Strings 1, Saw Lead and Square Lead 2 for Lead 2; Synth Strings 3, 4 and 5 and Stereo Strings Slow for the pads; Pulse Bass on Rhythm; Fretless Bass, Synth Bass 101 and Mean Saw Bass for the bass; White Noise Wave. They are added to the end of the Kosmic pickers. Base Kosmic and Drift never draw them at random.
- **No French accents** — Rule names, log text, titles and docs use plain spellings (Oxygene, Equinoxe, Etude).
- **Click-only bass patch replaced** — (2026-11-02) The Synth Bass 1 preset in the soundfont plays a 25 ms click and then goes silent at every pitch and length, because its preset sets the volume-envelope sustain to silence. Space Rhythm now uses Pulse Bass in its place, and Motorik Bass uses Synth Bass 3. Older saved songs that picked it play the new sound.
- **Space levels** — (2026-11-02) Levels measured offline and set: Solar Wind 2 and Solar Wind raised and Starship lowered on Texture, Synth Brass 2 on Lead 1 and Saw Lead on Lead 2 pulled back, Pulse Bass on Rhythm lifted a little.
- **Space Texture auto-pan** — (2026-11-02) Texture now pans slowly, one full sweep per 2, 4 or 8 bars (25/50/25), drawn per song from its seed.
- **Thinner bass keeps the walk** — (2026-11-02) A thinned bass bar plays three of the walk's notes (steps 0, 6 and 12) with their own pitches, held longer, instead of two bare notes on beats 1 and 3.
- **Drum and bass variety** — (2026-11-02) The rhythm box drops to a simpler beat for 8 to 16 bars now and then, and the bass thins with it over the same bars, with a short fill back into the full beat. The playback log marks them with `Drums simplify`, `Drums return` and `Bass pattern evolving`. The handclap plays in about 1 song in 10, in one or two sections.
- **Varied theme** — (2026-11-02) The Falling Theme draws its note count and rhythm per song and never opens with the original figure.
- **More Texture sounds** — (2026-11-02) Space Texture picks White Noise, Solar Wind, Solar Wind 2, Starship or Interference, 20% each.
- **Shorter log** — (2026-11-02, 2026-11-03) Space rule lines, including after a single-track regeneration, carry no per-song details in parentheses.
- **Jazz Lead 1 rules for Chill (work in progress)** — (2026-11-07) Three new Lead 1 rules play licks taken from jazz tunes, reworked per song rather than copied: CHL-LD1-013 Moanin' (Chill Blues only; a two-bar call that climbs and falls through the blue note, answered by the horns' amen), CHL-LD1-014 Cantaloupe Island (both substyles; the four-bar hook, restated, then solo licks and horn stabs, with the full hook back near the end) and CHL-LD1-015 Blue Monk (regular Chill only; a chromatic climb into a held fifth with a falling answer). Licks follow the chord under each phrase and fit the song's scale. Miles punch, Chet sparse and Blues lead now play in Chill Blues only. Shares of all songs: Chill St Germain staccato 18, Blue Monk 17, Long phrase 17, Cantaloupe 15, Wide interval 13, Warm jazz 13, Jazzy blues 7; Chill Blues Miles punch 20, Blues lead 20, Moanin' 20, Chet sparse 15, Jazzy blues 13, Cantaloupe 12. The weights and the licks are still being fine-tuned by ear. Every Chill and Chill Blues song's Lead 1 changes, saved songs included; Soho is unaffected.
- **Square Lead 2** — (2026-11-03) Quieter on Space Lead 2, and always with tremolo. Space Lead 2 offers a tremolo chip in place of vibrato.
- **Machine Kit bloops** — (2026-11-03) Space picks Machine Kit in about 1 song in 4, and its fills now play the kit's own synth toms, the space-age bloops and beeps, rather than snares.
- **JMJ rules from base Kosmic** — (2026-11-03) For variety, Space now also draws JMJ Mini Pops on drums, JMJ Hook and JMJ Dual-Rate on Rhythm (an octave down, under the lead) and the JMJ Phrase Loop in Lead 1's B sections.
- **More Oxygene rules** — (2026-11-03) Five new rules from Oxygene 4, 6 and 8, each as likely as the other Space rules on its track: KOS-LD1-016 Oxygene 6 Rising Strings (A sections), KOS-BASS-020 Oxygene 8 Pump, KOS-RTHM-021 Oxygene 8 Offbeat Pedal, KOS-PADS-010 Oxygene 4 Staggered Bloom and KOS-DRUM-012 Oxygene 6 Hand Percussion. Each track's rule is drawn independently, except that the Pump never plays under Dual-Rate. The Pump varies as Oxygene 8 does: a fifth voicing on the chord loop's turnaround, a breath every 8 bars, and a turn and late entry at each new section. The guiro in the hand percussion plays only in two or three short stretches a song.
- **Chronologie Pop Loop and Anticipated Strings** — (2026-11-06) A new Space harmony family, Chronologie Pop Loop (I, V, ii, IV, then I, IV, vi in the B sections, Ionian), at an average family's weight, and a new pad rule, KOS-PADS-009 Oxygene 7-13 Anticipated Strings, the long drone with every chord change landing one 16th early, drawn slightly less often than the other two Space pads. The Space breakdown is dropped: the bridge, thinning and sequencer solo already break a song.
- **Roman numerals in Space** — (2026-11-06) The Chords log line for Kosmic Space always shows the numerals, for example "E Ionian Magnetic Descent I vi V IV". Other styles are unchanged.
- **Space effects** — Space Rhythm's echo runs on three 16ths, a cross-rhythm against the sequencer. Base Kosmic and Drift are unchanged.
- **Space Lead 2 and Bass instruments** — Space Lead 2 picks Brightness 25%, Synth Strings 1 and Saw Lead 27.5% each, Square Lead 2 20%. Space Bass picks Moog, Synth Bass 3, Fretless Bass, Synth Bass 101 and Mean Saw Bass, 20% each, appended to the Kosmic bass pickers. Mean Saw Bass plays at 85% volume; Moog bass and Synth Bass 101 are set a little louder. Base Kosmic and Drift never draw them.
- **Space levels and names** — (2026-11-03) Synth Brass 1 on Lead 1 and Moog and Harpsi Pad on Rhythm are quieter in Space songs. White Noise Wave shows as White Noise in the Texture picker.
- **Fewer bloops** — (2026-11-03) The toms in both Space kits are synth bloops, and the rhythm box's high-tom accent on beat 4 put one in every bar. Claves replace it. Space fills now vary: a snare roll, a tom roll or a cowbell figure, never the same one twice in a row, so the bloops come only in some fills. About half the rhythm-box fills land on a crash.
- **Readable Instruments line** — (2026-11-03) The log on screen names each track's instrument, for example `L1: Synth Brass 1, Bs: Fretless Bass`, instead of `L1:62 Bs:35`. Saved files still hold the program numbers, which reload uses. LS is Kosmic's hidden Lead Synth layer, which doubles Lead 1 on Polysynth.
- **B sections change chords** — (2026-11-03) Space B sections loop their own chords instead of repeating the A section's, for example F C G Am in an A minor Aeolian song, and come back to the tonic at the end of each loop. A song that returns to its A theme in the last B returns to the A chords with it.
- **Space titles** — (2026-11-03) Single-word titles repeated too often. Space titles now also come as part numbers (Fluxion Part 4), two coined words (Magnetique Cosmopod IX), French phrases (Les Chants Paradoxes), Jarre-style templates (Waiting for Kroneon, Rendez-Vous a Proxima, Pyreon & Plexion), and now and then a long-running series (Galexion V Part 7 of 42) or a gear joke (Concerto for Minipops). Saved file names collapse the gap a dropped character leaves, so Pyreon & Plexion saves as Pyreon-Plexion.
- **Lighter riff** — (2026-11-03) The Oxygene See-Saw Riff no longer climbs above C6, and rests for 2 bars in every 8.
- **Bright Saw** — (2026-11-03) Bright Saw Stack is now Bright Saw, so the name fits the instrument picker.
- **Space bridges** — (2026-11-03) A-B and A-B-A Space songs can now take a bridge of their own over the last 8 or 12 bars before the first B section, modelled on how Jarre breaks up a piece. The Magnetic Fields Breakdown drops the sequencer and leads, thins the drums, holds long bass notes and moves the pads to slower chords of their own. The Rendez-Vous Sequencer Solo leaves the sequencer alone, sometimes with the pads, under two filter sweeps, and the band comes back on a fill and a crash. 80% of eligible songs take one while testing; the release share will be lower, about 30–40%. The log shows `+ bridge` on the Form line and names the bridge at its first bar. The breakdown's drums drop to the kick alone on beats 1 and 3, as Magnetic Fields 1 does, so it no longer sounds like a thinned stretch. A Space song now has at most three breaks: a bridge and up to two stretches where the drums and bass thin, or up to three thinned stretches without a bridge.
- **Quieter Lead 2 saws** — (2026-11-03) Square Lead 2 and Saw Lead on Space Lead 2 are about 2 dB quieter.
- **No phantom fills** — (2026-11-03) While Mini Pops has dropped out, the log no longer reports drum fills that never play. The same goes for Hand Percussion, which is silent through the sequencer solo.
- **No cowbell** — (2026-11-03) The cowbell figure among Space fills sounded off genre in every kit. It now plays on claves, a Minipops voice.
- **Quieter Square Lead 2** — (2026-11-03) Square Lead 2 on Space Lead 2 is about 2.5 dB quieter again.
- **Bridge edges** — (2026-11-03) Every Space bridge now starts on a crash and ends on a short bass pickup under a 2-beat drum fill, landing on a crash in B. Hand Percussion has its own bongo and conga roll, and in the sequencer solo the bass rings one long root before it drops out.
- **Sequencer solo** — (2026-11-03) The solo bridge is logged as `Sequencer solo 8 bar`, and whatever the song's Rhythm rule, it plays the full Oxygene sequencer pattern, so the solo is never a sparse arpeggio.
- **Accurate fill lines** — (2026-11-03) Space fills are named in the log (snare roll, tom roll, claves figure, conga roll), and the breakdown's kick-only bars are no longer reported as fills. Fills at the end of a simpler drum stretch now appear too, and regenerating the drums or Lead 2 rebuilds their playback lines instead of keeping the old ones.
- **Regenerated Kosmic leads** — (2026-11-03) Regenerating Lead 1, by the lightning button or an Evolve pass, now rebuilds the hidden Polysynth layer that doubles it; it had kept doubling the old line under the new one, in every Kosmic substyle. A regenerated Kosmic Lead 1 or Lead 2 also gets the harmonic filter a generated song's leads get: the clash guard, the lift above the pads and the velocity arc.
- **Stable bass on reload** — (2026-11-03) A regenerated Space bass reads the song's own Rhythm rule, so after regenerating Rhythm and saving, the bass reloads as it was heard.
- **Kosmic Space code cleanup** — (2026-11-03) The bridge timing, theme return, seed streams and chord windows are each defined once, and unused draw logging is gone. Every Kosmic song generates exactly as before, checked note for note over 300 seeds.
- **Mini Pops out of the solo** — (2026-11-03) Mini Pops always returns from the sequencer solo on a 2-beat fill, under the bass pickup.
- **Version 2.9 (build 135)**
- **Magnetic harmony** — (2026-11-06) Phase 2 begins. Four chord cycles from *Magnetic Fields* and *Equinoxe* join the three Oxygene ones in a single pool, each as likely as an average Oxygene cycle: Magnetic Fields Arc i bVI iv V, Magnetic Fields Turn i V bVI bVII, Equinoxe Phrygian i iv bII and Magnetic Fields Descent I vi V IV. Each has its own B-section loop and breakdown chords. Over a major V chord, every Space part takes the leading tone, as Jarre plays harmonic minor only over the V. All rules still mix freely; there is no Oxygene or Magnetic flavour roll. Space tempo widens to 96–128.
- **Magnetic rules** — (2026-11-06) Five rules from *Magnetic Fields* and *Equinoxe* join the Space pools, mixing freely with the Oxygene ones: KOS-DRUM-010 Magnetic Fields Rhythm Box, with short fills at section changes and where the drums thin; KOS-BASS-019 Magnetic Fields Octave Pump, three octave figures that vary over the song, in about 12% of Space songs; KOS-RTHM-017 Equinoxe Fifth Triplets and KOS-RTHM-018 Magnetic Fields Leading-Tone Cell on the sequencer; and KOS-LD1-015 Magnetic Fields Turn Melody, falling 16th turn runs whose shape, length and start vary per song. About 3 Space songs in 5 now hold at least one Magnetic rule.
- **More Magnetic rules** — (2026-11-06) Four more, each as likely as the other rules on its track. KOS-LD1-018 Magnetic Call and Hold (Magnetic Fields 4) plays a repeated-note call with a falling tail, answered by two held notes; the phrase ends with a trill and a cadence, and in most songs an octave-bouncing phase takes every third 8-bar block. KOS-LD1-019 Equinoxe Thirds Riff is the See-Saw riff in thirds on Equinoxe's 3+3+2 rhythm, a third of the B sections. KOS-BASS-021 Magnetic Triad Walk (Magnetic Fields 5) climbs root, 3rd and 5th in dotted quarters and shifts half a bar in part of the song; it is sparse, so it also plays under the busy sequencers. KOS-LD2-001 Magnetic Twin is a third of Lead 2: half the time a stereo twin of the sequencer, panned wide opposite it, otherwise Lead 1 an octave up through the last third of the song. About 9 Space songs in 10 now hold a Magnetic rule.
- **Shorter Chords and Magnetic names** — (2026-11-06) The Chords line names the mode once, `A Phrygian Equinoxe`, and Magnetic rule and chord names drop "Fields", `Magnetic Leading-Tone Cell`.
- **Fewer Space bridges** — (2026-11-06) A bridge now comes in 30% of Space songs in AB and ABA form, about 1 Space song in 6, down from 80% while testing.
- **Space levels** — (2026-11-06) The Moog bass is a little quieter and Bright Saw on Lead 1 a little louder, in Space songs only.
- **Log and error display** — (2026-11-06) The Instruments line is compact, `L1:Brightness L2:Saw Lead`. An audio device change no longer repeats the Instruments line, and audio messages use the `Audio` tag throughout. An error also shows "Error - see log." in red in the visualizer's corner for a few seconds.
- **Rising Strings sits on the chords** — (2026-11-07) KOS-LD1-016 Oxygene 6 Rising Strings held a passing tone on its second long note in most bars, so the line was in key but off the chord. Its long notes are now chord tones, with a scale step only on the short last note of a bar. The chromatic approach into each climb is a 16th pickup before the bar instead of a held note on the downbeat. From its third pass the line starts a chord tone lower or higher or takes a reshaped climb, with every fourth pass plain, so it no longer repeats the same 8 bars through an A section. Notes stay in MIDI 58–84, turning back at the edge rather than jumping an octave.
- **Cleaner snare on Machine Kit** — (2026-11-07) In Kosmic Space on the Machine Kit, the electric snare used by the Magnetic Rhythm Box sounded harsh and mechanical. It now plays as the kit's plain snare. Playback only, so no song changes.
- **Magnetic Gallop** — (2026-11-07) KOS-DRUM-010 is renamed Magnetic Gallop. Its kick pairs now lead into each beat with a kick on beat 1, so it locks with the Space basses instead of landing a 16th after them. Simpler stretches drop to the kick on beats 1 and 3. Full B bars are lighter: 8th tops, ride bell on the beats, off-beat snare, and a plainer kick under the drone, Falling Walk and Triad Walk. Long stretches get a 1-beat fill every 8 bars, and all Space fills draw the tom roll more often (40%, was 30%).
- **B sections hold Rhythm's density, the twin rests** — (2026-11-07) A Space B section raised Rhythm to 8 to 11 notes a bar just as the bass and drums stepped up, and the Magnetic Twin doubled it, which drowned Lead 1 (Helixe, bars 37 and 53 on). Every Rhythm B bar is now trimmed to the note count of the first A section, off-beat 16ths going first and quarter notes last, and the stereo twin on Lead 2 rests through B sections. Twin detection compares against Rhythm outside B.
- **Space drum mix** — (2026-11-07) The Magnetic Gallop is distinctive, so it now plays in 15% of Space songs, down from 20%. Hand Percussion rises to 15% and Mini Pops falls to 20%. Base Kosmic's KOS-DRUM-005 Electric Buddha Pulse joins the Space pool at 12% as a plain quarter-hat beat, so the Oxygene Preset Box drops to 26%. In Space the Pulse plays through intro and outro, simplifies and fills like the other Space beats, and keeps its backbeat off the fill log.
- **Base Kosmic sequencer gives way to the lead** — (2026-11-07) Borrowed from Kosmic Space. When the sequencer is much busier than Lead 1, base Kosmic used to drop a third of its notes at random across the whole song. Now it thins only while Lead 1 plays, to under half its notes, and plays its full figure in the gaps between lead phrases, so the lead stands out and the sequencer swells when it rests. Notes go in metric order, off-beat 16ths first, so the figure stays steady. Drift and Space are unchanged.
- **Electric Buddha Pulse name** — (2026-11-07) KOS-DRUM-005 shows as Electric Buddha Pulse in every Kosmic substyle's log.
- **Batch audio export for testing** — (2026-11-07) On the Mac, launching Zudio with `ZUDIO_BATCH_EXPORT` set to a folder in Downloads fast-exports every `.zudio` there to `.m4a` and quits; `ZUDIO_BATCH_MATCH` narrows by filename. Songs loaded this way stay out of the history.
- **Space Rhythm no longer changes between launches** — (2026-11-07) The B-section density trim broke its random ties in dictionary order, which Swift reshuffles on every launch, so the same Space seed dropped different Rhythm notes each time the app started and a saved Space song came back with a different Rhythm part. Ties now break in step order. Songs saved before this fix may reload with a different Rhythm. No other track or style changed.
- **Space code tidy** — (2026-11-07) The triangular draw behind Kosmic's tempo and song length is one `SeededRNG.triangular` instead of three copies, and the Motorik drum-name table no longer carries a second copy of the Kosmic names. Same songs.
- **Kosmic code tidy** — (2026-11-07) The X-Files bridge whistle, copied into two Lead generators, is one helper; an unused function and three unused values are gone. Same songs across 8,000 seeds.
- **Motorik bass no longer doubles notes** — (2026-11-07) The pattern evolver's rotate step shifted odd-step bass notes onto even steps without checking what was there. Moroder Chase's echo notes, which fill every odd step, landed on top of the main notes, striking the same pitch twice or adding a second pitch to the bass. A note now stays put if its destination is taken. This changed the bass in 205 of 3,000 songs: base 115, Arcade 62, Noir 16, Europe 12. Nothing else in them moved.
- **Motorik code tidy** — (2026-11-07) The four-on-the-floor kick and snare, written out three times in the drum generator, is one helper, and an unmutated variable is a constant. Same songs.
- **Fewer drum fills in base Motorik** — (2026-11-07) Borrowed from Motorik Europe, which fills only at structural edges. Base Motorik filled whenever any part came back after two silent bars, about 39 fills a song, one body bar in three. Now the drummer cues only Lead 1 returning after a rest of 4 bars or more, alongside the fills every 8 bars and at section changes, about 20 a song. The longest stretch without a fill is still 8 bars. Noir, Arcade and Europe are unchanged.
- **Base Motorik breakdown** — (2026-11-07) Borrowed from Motorik Europe's dropout. In about half of base Motorik songs, Lead 1, Lead 2 and Rhythm drop out together for 4 to 8 bars while drums, bass, pads and texture keep the groove, once near a quarter and once near two thirds of the way through. A fill marks the bar before the drop and the bar before the return. The Form log line adds `+ breakdown`, and the playback log shows `Leads, Rhythm drop - 6 bars` and `Leads, Rhythm return`. Noir, Arcade and Europe are unchanged.

## V 2.8 (Build 134) — iPhone Duo

- **iPhone Duo layout** — (2026-10-27) The foldable iPhone Duo now gets a layout made for it, tested on a real Duo. Folded, it runs the iPhone player unchanged. Unfolded, it runs the iPad layout, opening on Visuals with the track view one tap away on Tracks. Folding and unfolding mid-song leaves playback alone, and the unfolded tab is remembered. The choice is made by size class, with every iPad kept on the iPad layout by its idiom, so no existing iPhone or iPad changes.
- **Narrow windows, under 700 pt wide** — The unfolded Duo in portrait is 669 pt wide, narrower than an iPad mini. The top bar had been forcing the whole screen wider than the window, which clipped the Songs tab, the track effect buttons and the scrollbar. Below 700 pt the top bar now drops Mood and Key, moves Reset beside BPM, and puts Help, About, Sleep and Share in a row under it. The style picker is wider so Ambient is spelled out in full, and the BPM, Reset and Help rows share one type size. The track effect chips use their natural width, so the MIDI lane keeps its room, and the empty-song message wraps to two lines.
- **Short windows, under 660 pt tall** — The unfolded Duo in landscape is 635 pt tall, too short for seven track rows plus the generation log. In a window that short the log is hidden on the Tracks tab, the Generate, Save, Load and Export buttons are smaller, the tab strip is 28 pt with each icon beside its label, and track rows are 57 pt instead of 63, so all seven tracks show.
- **Chosen by size, not by model** — Both layouts are triggered by window size, so iPad Split View, Slide Over, resizable windows and any future small iPad get them too. iPad mini landscape and every larger iPad are unchanged.
- **Log pinch gesture** — Pinch-to-resize on the generation log stays on for iPhones and the folded Duo, and is off for iPads and the unfolded Duo, where the log behaves as on iPad.
- **More flexible style selection in Endless** — (2026-10-31) The style picker stays active in Endless. Tapping a style sets the next song's style, then Endless picks styles automatically again.
- **Audio engine rebuild** — (2026-10-31) An engine start that failed again after the 300 ms retry had survived Reset and needed a full quit. A third attempt now resets the engine and reconnects its output with the current hardware format first, logging `AUDIO  Audio engine rebuilt after error -50` when that works. If it still fails, a line with the session's sample rate, output and activation result comes before the red ERROR, and the message is shorter: `Audio engine fail (-50)`.
- **Shorter disconnect message** — (2026-11-01) When the audio output goes away, such as Bluetooth headphones switching off, the log now reads `AUDIO  Stopped, disconnected`.
- **Version and build number in one place** — (2026-11-02) `Version.xcconfig` at the repo root now holds the version and build number for every target: the Mac app, the iPhone and iPad app, and the Share and Quick Look extensions. A version bump is two lines in that file. They used to be typed into 14 places in the project file and the Mac Info.plist. The About box, the iPhone info sheet and exported logs read the version from the built app, as before.
- **Version 2.8 (build 134)** — The Mac download is the v2.8 release. See [iphone-duo-plan.md](iphone-duo-plan.md) for the full plan and what was tested.

## V 2.7 (Build 132) — Chill Soho

- **New Chill Soho substyle** — A third Chill form modelled on early-80s British sophisticated pop: Sade, Everything but the Girl, The Style Council, Simply Red, Roxy Music, Matt Bianco. Twenty-one new rules measured from MIDI of those records: bossa, samba, Latin sway and soul grooves with hand percussion; 6th, 7th and 9th chords with a separate B-section cycle and a four-bar turnaround the band plays; horn stabs and halos on a MIDI Texture track; sax-led leads built from vocal-line figures; and a house-style Remix Break. Soho song titles.
- **Guitar-led Soho rhythm** — Jazz and Funk Guitar added to the soundfont. Soho Rhythm is Rhodes, Stereo Piano, Nylon, Jazz and Funk Guitar at 20% each; guitars play with a slow amp tremolo by default. The unused SFX drum kit is gone; the soundfont is 21.2 MB.
- **Avalon lead** — The hook rule now draws far more varied figures, and each song applies one or two treatments to them — displace, lengthen, invert, reverse or extend. Figures sometimes run on or end on a held note. The log names the treatments. A varied hook returns to its original form after an episode or two, and the song ends on its opening hook. Episodes start on different chord tones, higher in the B section, and displaced songs no longer put every figure on the same beat.
- **A best first Chill Soho song** — The first time a Chill Soho song comes up, on Generate or in Endless, it is one of twelve chosen songs: a Latin groove in drums and bass, Operator on flute with vibraphone answering, and a Remix Break, Duo or bass break. Base Chill keeps its St Germain opener.
- **Operator, the Soho sung lead** — The Soho lead rule once called Counter-Line is now Operator, after *Smooth Operator*, the record it is mostly measured from. Its opening phrase is the song's hook: it returns about once every three phrases, at least six bars apart, half the time as it was and otherwise with one note added, dropped or moved, or starting on another chord tone. Phrases no longer end on the note they began on.
- **Groove fixup** — On every Chill song, lead notes stranded on weak sixteenths the band doesn't play are moved onto the beat, and one-sixteenth gaps inside a phrase are closed, so solos sit with the band and flow. Regenerating a lead does the same. The log reports how many notes changed.
- **Audio export — tremolo, Beat Fixup and Chill Pads fade** — Exported audio now includes the Beat Fixup delay, and Chill Pads fade in and out per chord with the filter sweep restarting closed at each chord, as in playback. Fast tremolo, vibrato and auto-pan are rendered in 60 fps blocks instead of ~90 ms ones, which had stepped an 8 Hz organ tremolo and a 4 Hz guitar tremolo instead of swelling them.
- **Beat Fixup — behind-the-beat feel (Chill Soho Soul)** — The bass sits 10 ms late and the drum backbeat (side stick, snare, clap) 20 ms late, with kick and hats on the grid, for the Sade / Style Council pocket. Playback only: no note moves. Latin and base Chill are unchanged. The log shows a `Laid back` row. The ⌘J / ⌃G test switch that briefly turned it off and on for comparison on Mac is disabled and removed; the delay is always on.
- **iPhone audio recovery and error display** — (2026-10-25) If the audio engine fails to start, for example when a Bluetooth headset has just been taken by another device, it now waits 300 ms and tries once more before giving up, and a successful retry logs a green `AUDIO  Audio engine restarted after error -50` line. The failure message is shorter, "Audio engine failed to start (error -50)", and ERROR lines show their tag in red and flash the visualizer red briefly. That covers all three audio faults: engine start failure, instrument load failure and missing MIDI patch.
- **Scrubbing no longer repeats log lines** — (2026-10-25) Dragging the progress slider within one bar no longer writes that bar's log lines on every tick: a repeat seek to the same step within a second is ignored. Dragging across bars still buzzes, since each new bar cuts all notes and restarts playback.
- **Beat Fixup test switch disabled** — (2026-10-25) The Mac-only ⌘J / ⌃G keystrokes that switched Beat Fixup off and on for A/B listening are removed, ahead of release. The behind-the-beat delay itself is unchanged and always on, on Mac, iPhone and iPad.
- **Beat Fixup in some Chill Blues** — (2026-10-19) Chill Blues songs on the B.B. King Pickup (CHL-BASS-009), Quarter Pulse (010), Root Sustain (001) or Walking (003) bass get the same behind-the-beat feel, smaller than Soul: bass 6 ms, side stick and snare 15 ms late, for the whole song including Groove B. Rumba (012), Ascending Riff (011) and Air Ostinato (004) songs stay on the grid. That is about 60% of Blues songs. The log shows `Laid back  Blues bass +6 ms, rim/snare +15 ms`. Playback and export both have it; the ⌘J / ⌃G test switch is disabled.
- **Filter sweeps in the log, and automatic ones** — (2026-10-19) Tapping or clicking empty canvas in the visualizer (Mac, iPad and iPhone) already ran a 3-second filter sweep across every track but drums, with a white flash on the canvas; it now writes `Bar 025   Filter sweep` to the log. Kosmic songs also sweep on their own: 40% of regular Kosmic songs (not Drift) get one to three sweeps, started about a bar and a half before a B section, bridge or 16-bar mark so the filter reopens on the change, at least 32 bars apart. The schedule comes from the song's seed, so it does not change a note and repeats on every pass and rewind. Evolve on a Kosmic (not Drift) song also sweeps at the start of phase 1 and phase 2. Each sweep logs and flashes the same way.
- **Endless mix retuned** — (2026-10-19) Chill is stronger with Soho, so the style walk moved from Ambient ~19.5%, Chill ~24%, Kosmic ~32%, Motorik ~24.5% to about Ambient 21%, Chill 27%, Kosmic 28%, Motorik 24%. Ambient jumps to Kosmic 25% of the time (was 32%), Chill 12% (was 8%), Kosmic steps back to Chill 10% (was 17%), and Motorik jumps to Chill 40% (was 15%). Runs of Kosmic and Motorik songs are shorter, median 6 songs (was 9); the longest is still 14. See docs/continuous-play.md.
- **Chill Blues harmony is rarer and pickier** — (2026-10-19) The second-horn harmony (3rds, 6ths or unison) now plays only in songs whose Lead 1 is the slow Blues Lead (CHL-LD1-004) or the Dyad lead (CHL-LD1-003), and never when Lead 2 is a vibraphone, which plays its normal part instead. Busy jazz-idiom lines (CHL-LD1-009) and short punches (CHL-LD1-002) no longer get it. About 15% of Blues songs, down from about 27%.
- **Chill Blues plays its blue note** — (2026-10-19) The b5 blue note (Db in G, Gb in C) never sounded: it was added at the wrong pitch and then stripped as out of mode. Now 60% of Blues songs have a soloist who uses it, as a passing tone between the 4th and 5th over the I chord, and the first move that fits becomes a lick that repeats through the song. Songs that don't fit it, or whose soloist doesn't use it, stay plain Dorian. The Chords line in the log says "blues scale" when it is heard. Blues only.
- **Leads stay in their register** — Chill leads now stay inside each instrument's own range; saxes no longer reach screechy altissimo notes.
- **Chill Soho tuning** — Six bass turnaround treatments, two or three per song. Lead solos answer a figure with a different one. The Harmonic Drone breakdown changes chord halfway and Lead 1 plays over it. Lead 2 rests 8–16 bars rather than whole sections, and a held Shadow Hold note gets a companion note (all Chill forms).
- **Chill instruments** — Each Chill picker lists the same instruments in all three forms; forms differ only in their random odds. Chill Blues pads are Strings Fast, Cello and Synth Strings 5. Soho Elec Bass plays with Low but no Comp.
- **Soho Duo breakdown** — A new Chill Soho breakdown, about one song in five: 8 or 12 bars of Rhythm and Bass alone. The bass keeps its groove, the comp plays every bar a little forward in the mix, and the chords keep moving. The kit drops to a soft shaker, closed hats or ride, and a snare pickup leads back in. Pads and leads sit out; the horns reply with a soft held chord every few bars and a stab into the return.
- **Soho horns sound like a section** — Horn stabs are two- or three-note chords far more often, turnaround stabs included, and each song has its own voicing (open, close, or with a 9th or 6th) that changes now and then. Half of the Sustained Halo's long notes are now two-note chords as well. Xylophone is gone from the Soho texture pool; Vibraphone takes its share.
- **Soho bass slides** — In Chill Soho songs on the Best Melodic bass, the bass now slides into a note from a whole or half step away now and then, from the side the line is coming from, about once every twelve bars, and often into the root after a turnaround. Chill Blues songs on the B.B. King pickup riff slide up a half step into the root at the top of every form. On any bass instrument, in playback and in exports, and marked "Bass slide" in the log.
- **Soho Rhodes tremolo** — Rhodes in Chill Soho plays with the slow amp tremolo by default, as the guitars do. Any Rhodes with tremolo switched on now uses that slow setting rather than the organ's fast Leslie.
- **Chill mix** — Lead 1, Lead 2 and Drums are drier in all Chill forms; Lead 2 and texture vibraphone are quieter.
- **Instruments stay inside their style** — One rule, for every style and play mode, now replaces an instrument carried over from the previous song that the new song's style never uses. Regular Motorik no longer gets Arcade's Metal Pad, Ice Rain or Mystery Pad. Chill songs in Endless and Evolve play their leads on the right instrument.
- **Chill and Blues solos come back to their opening phrases** — Through the middle of a song the lead now returns to its opening phrases now and then, where they fit the chord, so a solo has a theme rather than a long free stretch. Blues waits for the I chord to bring its opening lick back, and Chill Soho's two reused lead rules keep their returns clear of their rests.
- **"Lead 1 return to form" in the log** — Marks the bars where a Chill solo comes back to its opening phrase or hook in its original form.
- **Best first Soho song, refreshed** — Two of the twelve chosen songs had turned into Blues songs when the Blues share rose to 20%; they were replaced by two that meet the same list.
- **Chill mix** — Chill songs are now 30% Chill Soho, 20% Chill Blues and 50% base Chill.
- **Leads keep their shape above the pads** — When a lead is lifted an octave to clear the pads, the whole figure moves, so a step down no longer turns into a seventh up halfway through a phrase, including figures that run across the eight-bar windows the check works in. All styles.
- **Regenerated Chill leads get the full polish** — A regenerated Lead 1 or Lead 2 now goes through the same clean-up as a generated one: the clash guard, the lift above the pads, the song's dynamic arc, the instrument's range and the empty first bar on songs with no intro.
- **Saved songs replay exactly** — The first song of each style, Ambient songs on the Brush Kit, and Kosmic and Ambient songs reloaded from the Songs list now come back note for note. All three reload routes (Songs list, startup, .zudio file) share one replay.
- **Opening a .zudio file sets up its instruments fully** — The Chill leads, Ambient Piano and the Lead 2 mirror are set as on every other route before the song is saved to the Songs list.
- **Chill fade-in on reloads** — A Chill song that opens mid-groove fades in on Endless transitions, ⏮/⏭ and Songs-list taps, as it does when generated.
- **Arcade and Europe songs stay themselves** — Regenerating any track of a Motorik Arcade or Motorik Europe song, or reloading one from the Songs list, no longer turns it into plain Motorik.
- **Soho drum regenerate** — Regenerating the drums of a Chill Soho song with a Remix Break no longer picks a kit that can't play the break.
- **Soho Lead 1 randomise** — Picking a random Lead 1 in Chill Soho now uses the same odds as a generated song.
- **Soho chord cycles** — The B section's chord cycle is now drawn at its intended odds; one cycle had been taking far more than its share.
- **Flute and recorder on iPhone** — Songs replayed from the Songs list or with ⏮/⏭ played a flute or recorder lead as a saxophone. Replays now use the lead the song was written for, and songs already in the list are corrected.
- **Chill piano** — Stereo Piano on Chill Rhythm is about 3 dB quieter.
- **Muting an audio texture works** — Muting Texture now silences audio-loop textures (Chill, Chill Blues, Ambient) on every platform, and exports leave them out.
- **Lower CPU and battery use** — Playback no longer redraws the whole window on every beat, effect timers stop when playback stops and slow down when only slow effects are on, and idle reverbs and the idle texture player are switched off. On a Mac Zudio now typically uses 15–20% CPU, and 5–10% in the compact view with no visualizer.
- **Audio textures follow the song** — Fixed a bug in audio textures: they restarted from the top on Play, a seek or a texture change, so the waveform did not match what was heard. Playback, the waveform and exported audio now line up.
- **Saved songs keep your changes** — Fixed a bug where a regenerated track or a changed instrument was lost when a song was saved or reopened. Chill Blues files reopen exactly, and saved songs keep their Chill form when the mix changes.
- **Endless and Evolve** — Fixed a bug where Endless could occasionally play a song in the wrong style. In Evolve, the two leads no longer play over each other as often.
- **Evolve phase changes play through** — (2026-10-19) Fixed a dropout at both Evolve phase changes on Chill Blues and Chill Soho songs that start without an intro (about half of Blues songs, a few Soho ones). Those songs open on a drums-only pickup bar, and each Evolve phase replayed it, so the band stopped for half a bar or a whole bar mid-song. A phase now plays the same place one chord cycle later instead, with the full band. On iPhone the phase change also waited while the new instruments loaded, a short gap there only; playback now carries on and the instruments switch a moment later, as on the Mac.
- **Evolve fixes** — (2026-10-19) Opening a .zudio file in Evolve no longer plays the previous song's evolution, with its drums, bass and title, at the new song's outro. Generate in Evolve now always evolves the new song. Evolve's new instruments come from each substyle's own list, so Chill Blues no longer gets Recorder, Flute or Synth Brass, and the new Chill leads are written for the instrument that plays them. The Chill Blues behind-the-beat feel continues through both phases, and a song saved mid-Evolve keeps its title and rules.

## V 2.6 (Build 131)  Motorik Europe, reverb restored

- **New Motorik Europe substyle** — About one Motorik song in five: a synchronised group of tracks plays twelve new Kraftwerk-derived rules — rigid sequencer percussion and cells, octave doubling, short lead statements — dropping out together twice a song. 120–132 BPM, German-flavoured titles, a `Sync` line in the log.
- **Melodic Motorik leads** — The Kraftwerk lead rules use figures measured from Autobahn, The Robots and Computer Love, anchored to the chord, with no leap over an octave.
- **Motorik leads breathe** — Rest windows scale with song length, replayed phrases vary, phrases end on a held note, and the two densest rules are capped at twenty bars.
- **Motorik bass pool** — McCartney Drive, LA Woman Sustain, Hook Ascent and Quo Arc moved out of base Motorik (still in Noir or Arcade); the Kraftwerk rules rise to 26% and Neu! Hallogallo doubles.
- **Instrument variety** — Every track gets a real choice when a style starts; Mono Synth is weighted down in Europe and never repeats.
- **Kosmic levels** — Moog, Mono Synth and Synth Bass 3 on bass, and Synth Chime on rhythm, turned down.
- **Motorik lead mix** — Call and Answer down from 14% to 11%.
- **Chill pads breathe** — Pads now rest for a few bars at a time, decaying into the gap.
- **Reverb restored** — Playback had lost all reverb since build 124; it's back, and the reverb chip now decides whether a track is wet on every platform.
- **Audio timers thread-safe** — Removes a source of rare glitches and crashes in long playback.
- **Saved songs reload note-for-note** — The same seed now always produces the same song.
- **Crash fix** — A song could fail to generate depending on how its sections lined up.
- **Minor fixes** — Removed Clavinet from Motorik (missing from the soundfont); iPhone info sheet showed v2.4.
- **Regression tests** — Determinism, Motorik Europe, reverb routing, lead density and annotation tests.

---

## V 2.5 (Build 130)  Improvements to Endless, Chill, bug fixes

- **Endless mix** — Ambient ~19.5%, Chill ~24%, Kosmic ~32%, Motorik ~24.5%.
- **Endless streak cap** — After 8 Ambient/Chill songs or 12 Kosmic/Motorik songs in a row, Endless switches to the other pair.
- **Chill variety** — Bass and Rhythm evolve within a song: Rhythm switches between A and B and takes rest bars; repetitive bass patterns vary every 16 bars.
- **Chill Rhythm rebalance** — Bosa Moon reduced. New **CHL-RHY-005 Chord Hold** and **CHL-RHY-006 Downbeat Pulse** (also in Chill Blues). Sections tile into 12–16 bar segments that may go sparse, and 20% of songs get a full dropout.
- **Chill Blues bass variation** — One small variation per pass through the long I-chord stretch.
- **Chill comping and lead selection** — No longer vary by mood.
- **Chill bass levels** — All three Chill basses turned down.
- **Ambient Piano mix** — More reverb and a soft echo.
- **New Ambient texture** — "Long Lake" (AMB-TEXT-010), loon calls over a lake.
- **Audio texture on reload** — A reloaded song now plays its audio texture.
- **Instruments on reload** — Restored from the song's own log; Ambient Piano no longer pins Stereo Piano onto later songs.
- **Stem export Air effect** — Now matches playback.
- **Audio interruption logging** — The log notes when another app or a disconnected device stops playback.
- **Sleep timer** — Starts and cancels with playback.
- **Chill breakdown bass** — The Acid Jazz rule's harmonic-drone bridge now follows a four-bar arc instead of repeating the root.
- **Song sharing on iOS 26/27** — "Copy to Zudio" works again, and Zudio appears in the share sheet, via a Quick Look extension, an opaque `.zudio` type on iOS and a Share Extension. Reported to Apple as FB24777501.
- **Regression tests** — `.zudio` document types and playback/export effect-chain parity.

---

## V 2.4 (Build 129)  Motorik Arcade

- **Motorik Arcade** — New Motorik substyle in the style of classic arcade music: four-on-the-floor kick, mid-register bass, Lydian/Mixolydian, and arpeggio leads (Octave Bounce, Triad Climb, Arcade Arp, Gate Arp). Motorik is 60% base, 21% Noir, 19% Arcade.
- **Bug fix** — Opening a Zudio file while the app wasn't running could launch with no window. Diagnostic logging remains, off by default (`kAppOpenDebugLog` in `ZudioApp.swift`).

---

## V 2.3 (Build 128)  Audio engine crash fix

- **New instruments** — Tonewheel Organ and Warm Pad on Kosmic Bass.
- **Distortion effect** — "Dist." chip on Motorik Bass and Rhythm; on by default for ~75% of Noir and ~20% of regular Motorik bass.
- **Vibrato effect** — On Chill and Kosmic leads, applied to suitable instruments (~20% of songs, 50% in Kosmic Drift).
- **Air effect** — Presence and high-shelf boost on Motorik leads (~25% regular, ~45% Noir on Lead 1).
- **Probabilistic effects** — Sweep, tremolo, pan and delay applied randomly on several Kosmic and Motorik tracks.
- **Style chip** — Mac and iPad show the style or substyle next to the title.
- **iOS fixes** — Regenerating a Noir track no longer changes the substyle; no "Generating…" flash.
- **Crash fix** — Rare Mac crash after 2+ hours of playback.

---

## V 2.2 (Build 126)  Optional stem export + new icon + new instruments

- **Stem export** — Mac export can write separate track stems with full EQ and reverb.
- **New instruments** — Guitar Fdbk (Motorik Noir Texture), Fantasia 2 (Kosmic Pads), Kalimba (Ambient Rhythm).
- **New app icon** — Periodic-table style "Zu".

---

## V 2.1 (Build 125)  Substyle shown in song list

- **Song list shows substyle** — e.g. "Chill Blues", "Motorik Noir".
- **iOS Save Song fix** — Now exports the MIDI file.
- **New instruments** — Shakuhachi (Ambient Lead 1), Tonewheel (Chill Rhythm), Pulse Bass (Kosmic Bass); Fuzz Guitar in regular Motorik.

---

## V 2.0 (Build 124)  Reduced CPU by 50% with reverb bus

- **Reverb buses** — Two shared reverb buses replace seven per-track reverbs, more than halving CPU load.
- **M4A export** — Keeps per-track reverbs and now renders auto-pan, tremolo and sweep.

---

## V 1.7 (Build 123)  Kosmic Drift

- **Kosmic Drift** — New Kosmic substyle (~50% of Kosmic songs), after Boards of Canada, Portishead and Sigur Rós: 70–90 BPM, sparse, with new drum, bass, lead and rhythm rules.
- **Kosmic instruments** — New pads, textures, Drift leads and Drift rhythm voices; Tremolo replaces Low Filter on Kosmic Bass.
- **Kosmic bass** — Berlin School drone breathes and varies; the tremolo bass layer avoids semitone clashes.
- **Chill** — Lead instruments no longer mood-weighted; second-horn harmony in ~20% of regular Chill songs.
- **Generation log** — Shorter descriptions.

---

## V 1.6 (Build 122)  Motorik Noir + improved gestures

- **Motorik Noir** — New dark Motorik substyle (~30%): 110–128 BPM, always minor, after Public Image Ltd and Joy Division.
- **Motorik instruments** — Rhythm pool grows to 8; Machine Kit, Techno Bass, Synth Lead and Saw Stack added; Harpsi Pad on Kosmic Rhythm.
- **Swipe up / down** — Changes tempo by 5 BPM on all platforms.
- **Orb gestures** — Regenerate both instrument and track.
- **Fixes** — Evolve tempo clamping, Kosmic intro effects, bass/drum sync, export respects Mute and Solo, Evolve Next Track.
- **First-best rules** — Only on a true first run or after a reset.
- **Smoother playhead** — Driven by wall-clock time.

---

## V 1.5.1 (Build 121)  Minor improvements

- **Chill Blues lead** — More varied runs and note lengths; Short Punch flows better.

---

## V 1.5.1 (Build 120)  Bug fix

- **Audio export fix** — Save as Audio restored.

---

## V 1.5 (Build 119)  Ambient Piano and new instruments

- **Ambient Piano** — New Ambient substyle (~20%): solo piano with optional pads.
- **New instruments** — Church Bells, Windchime and Tinker Bell (Ambient Rhythm); new synth basses in Kosmic and Motorik; Saw Lead 3 and Night Vision in Motorik.
- **SC55 Stereo piano** — Used in Ambient, Ambient Piano and Chill.
- **New drum kits** — Jazz Drums (Chill), Dance Drums (Motorik).
- **Custom Zudio.sf2** — Trimmed GeneralUser GS from 29.8 MB to 20.9 MB.

---

## V 1.4 (Build 118)  New Chill Blues

- **Chill Blues** — New Chill form (~1 in 5): a 16-bar blues with brushed drums, horns and reeds, sparse pads and a blues soloist.
- **Chill Blues horn harmony** — A second horn in 25% of songs.
- **Jazzy blues lead (CHL-LD1-009)** — In Chill Blues and occasionally regular Chill.
- **Chill rhythm variety** — St Germain and Bosa Moon vary after 16 bars.
- **Trumpet register** — Floors at Bb3.
- **Performance** — Lower main-thread CPU.
- **Visualizer gestures** — Fully regenerate the track.
- **iOS 17 fix** — Turning off Reverb no longer silences a track.

---

## V 1.3 (Build 117)  Bug fixes

- **Lock screen** — Play/pause reflects playback state.
- **Kosmic export on iOS** — Fixed.

---

## V 1.1 (Build 116)  Fast audio export and musical improvements

- **Fast audio export** — Offline render, 20–40× faster; share sheet on iOS.
- **Ambient** — New bass rules and a descending secondary lead.
- **Chill** — More melodic solos, four new pad rules, more rhythm variety, a new secondary lead, less trumpet.
- **Kosmic** — Improved leads, pad variation and driving bass.
- **Drums** — Better 808 fills; more Motorik variety.

---

## 1.02 (Build 115)  App Store fixes

- **Mac App Store** — Save panels instead of writing to ~/Downloads.
- **Keyboard** — Shortcuts no longer fire while a dialog is open.
- **Fixes** — Chill outro, iPad BPM selector, lock screen and audio texture.

---

## 1.01 (Build 113)  Minor musical improvements and bug fixes

- iPhone save fix, instrument override persistence, rain/wind textures for Ambient, Chill groove pocket breakdown, evolve mode track addition.
