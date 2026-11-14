# Clash fix plan

Started 2026-11-13. Read this first in any session working on clashing notes. Current state, remaining options and how to rescan: see "Where it stands" and "Rescanning later" near the end.

**Live state (2026-11-14, evening):** code review A3 (Soho Lead 1 cleared as written) and A4 (Space post-pass removed) done, uncommitted, not heard; see the last Log entries. Before that, committed through 36651ff (unpushed). Item 11 and its regression fixes are committed in 6992969 but not yet heard, in `CosmicStructureGenerator.swift`, `CosmicBassGenerator.swift`, `CosmicPadsGenerator.swift`, `CosmicArpeggioGenerator.swift` and `SongState.swift` (F marks). Zack still has to hear four demo folders: `~/Downloads/Zudio out-of-key third demos/`, plus the three from 9342e16 (Kosmic pads, BoC loop, Call and answer). The clash work is otherwise closed at diminishing returns. Each numbered item below is sized for one session; work them in order, tick them off here, and record what changed and what was measured.

## Summary

A clash here is two notes on different tracks a semitone or a minor ninth apart, sounding together on a beat or for a beat or more. Brief off-beat passing tones are fine. Zack's rule: a song has a problem when one track clashes more than 4 times, on strong beats or held notes, especially when it is predictable (the same note in the same place every bar or cycle).

It started with After Dark Soiree Blues, where the bass rubbed against the pads and Rhythm. The Blues bass fix (item 1) removed about 90% of those clashes. A scan of 1,400 songs on build 138 code then showed that clashes are common outside Chill base and Chill Blues:

- Kosmic Space: 83% of songs have a problem (median 21 clashes a song).
- Motorik base: 72% (median 11).
- Chill Soho: 65% (median 8).
- Kosmic base: 52%, Motorik Noir: 52%, Motorik Europe: 36%, Kosmic Drift: 33%.
- Chill Blues: 22%, Motorik Arcade: 19%, Chill base: 8%.

Regraded by severity on the same 1,400 songs (see Measuring), glaring problems only, then mild-only songs:

- Motorik base 55% (mild-only 20%), Kosmic Space 51% (35%), Chill Soho 37% (29%), Kosmic base 34% (20%).
- Kosmic Drift 28% (6%), Motorik Noir 27% (29%), Motorik Europe 21% (22%).
- Motorik Arcade 10% (15%), Chill Blues 9% (21%), Chill base 2% (6%).
- Leads and Rhythm cause most of the glaring clashes. Bass patterns are mostly mild: KOS-BASS-018 was glaring in 11% of its songs and mild in 66%. Most of the other bass rules flagged above 15% are mild-only. The glaring top of the list: KOS-LD2-005 (75% of its songs), then MOT-LD1-012, MOT-LD1-004, MOT-LD1-007, KOS-RTHM-021 and KOS-BASS-016 (50% or more), then MOT-RTHM-004 and CHL-LD1-010 (48%). CHL-LD1-012 is 34% glaring and 41% mild-only.

Two kinds of cause:

- **A pattern that writes the same wrong note every bar.** Bass and pad patterns built from fixed intervals that ignore the chord the pads hold (the Blues Rumba's 6th under the b7, KOS-BASS-018's 2nd under the minor 3rd). These are fixed inside the pattern, one at a time, and are the cheapest wins.
- **A lead or Rhythm part that never checks the band.** Chill base and Blues leads go through ChillClearance (`Sources/Zudio/Generation/Chill/ChillClearance.swift`), which steps a lead note off a semitone clash with the notes already written. Soho's Lead 1, and every Motorik and Kosmic track, have nothing like it. Extending that mechanism is one piece of work that covers many rules at once.

## Ground rules for every fix

- A note outside the chord may pass through only off the beat and short (an 8th or less). Never on a strong beat, never held. Off-beat chromatic notes: up to 6 a song, or up to 12 if it is musical (Zack, 2026-11-13).
- Off-beat chromatic passing tones can be part of what gives a song or a rule its flavour (a blues riff, a Latin bass cell). Don't neuter a song by removing them to hit a number. The scan only finds candidates; whether a run of passing tones is musical often takes a listen, so play it for Zack before cutting any (Zack, 2026-11-13).
- Colour or grating (Zack, 2026-11-13, after hearing Riviere-du-Loup Exchange Blues and West End Cornichon Blues):
  - On a beat or held a beat or more: a bug. Fix it (pre-authorized).
  - Off the beat, rubbing two or more other tracks at once, for more than a few bars: grating. Fix it; it is not an artistic choice. The scanner's "persistent rub" measures this (see Measuring).
  - Off the beat and quick (a 16th, or one track only), occasional or in a short run: colour. Leave it.
- Fix where the generator writes the note, never a post-pass over the finished track.
- Keep the code simple and avoid making code brittle or overly complicated.
- Keep random draws in the same order and number, so other tracks and other songs stay put; when a draw becomes unused, keep it with a one-line comment (see the Rumba change in `ChillBassGenerator.swift`).
- Keep the musical identity of the rule: change the one note that clashes, not the figure.
- Mark every fixed clashing rule with an F rather than a * (`GenerationLogEntry.fixMarkedRules` in `SongState.swift`). The F marks come out before the build ships; the * marks stay.
- Measure before and after on the same seeds (see Measuring), then list songs and bars for Zack to hear. Nothing counts as done until he has listened.
- Bug fixes are pre-authorized, but a change to how a rule sounds needs Zack's go-ahead. Propose first when a fix changes the figure.

## Measuring

`tools/clash_scan.py <folder> [--worst N]` reads a folder of `.MID` + `.zudio` pairs and prints problem rates by substyle and by rule, and the worst songs.

It measures two things. **Strong clashes:** on a beat or overlapping a beat, more than 4 for one track. **Persistent rubs:** a note outside the chord that rubs against two or more other tracks at once, in a run of more than 4 bars (a one-bar gap doesn't break the run). A rub is a minor 2nd or minor 9th at any octave, or a major 7th with the note outside the chord at the bottom; an extension a major 7th above a chord tone (Blues Rhythm's 13th over the bass's b7) is a voicing and doesn't count. Calibrated on Zack's ears: West End Cornichon Blues before the 009 fix is flagged (8-bar run), Riviere-du-Loup Exchange Blues is not (16ths, longest two-track run 4 bars). Add each song Zack judges to this list and check the scanner still agrees.

**Severity, glaring or mild** (Zack, 2026-11-13, on Quantique Minipod's Falling Walk: "not that bad, not like B against Bb"). Every clash and run is graded, and every analysis must say which kind it is:

- Glaring: the two notes are within an octave of each other, either a semitone (B against Bb) or a major 7th with the outside note below. A minor 9th held two beats or more with both notes at C3 or above also counts as glaring. A minor 9th held one beat that steps on is mild. Example: Quantique Minipod's lead plays E, G#, A over E major, with the A against the pad's G#3, then moves to B.
- Mild: everything else. That covers notes two or more octaves apart (a low bass note under the pad's octave) and a minor 9th that is short or has one note in the bass register. Quantique Minipod's D# in the bass two octaves under the pad's E is mild.
- The scanner measures MIDI note length, not what you hear. On a patch that fades fast, a held note's clash is shorter than its length (Zack on Orpheon II's Lead 2, 2026-11-13). The same goes for a plucked or muted Rhythm patch. A fast decay is no reason to skip a glaring clash, though. The same rule plays on other patches from its pool, and some of them sustain (Zack, 2026-11-13). Fix glaring clashes at the rule whatever the patch. The instrument only explains why one song sounds milder than the numbers.
- A strong clash is graded by its own interval. A persistent run is glaring when the glaring rubs alone make a run of more than 4 bars.

A song is a problem when either measure fires on glaring clashes. Songs flagged only by mild ones are reported separately as mild-only: worth fixing when a fix is cheap and keeps the flavour, but they are not urgent. `--worst N` also lists the worst songs and the longest persistent runs per substyle, each marked glaring or mild.

Calibration still holds with the grading: West End Cornichon Blues (grating) is a glaring persistent run, Riviere-du-Loup Exchange Blues is not flagged, and Quantique Minipod before the item 3 fix is mild.

To generate songs in-session, use a throwaway XCTest (Swift Testing `@Test` functions do not run under `xctest -XCTest`) that reads `style seedhex` lines from `seeds.txt` in a folder named by an env var, calls `SongGenerator.generate(seed:style:forceBluesVariation:)`, and writes `MIDIFileExporter.export` and `SongLogExporter.export` per song. The build and run commands are in memory (reference-claude-session-toolchain). 1,400 songs take about 10 seconds to generate and 20 to scan. Delete the test afterwards.

For a before/after comparison, generate the same seeds once with the change stashed (`git stash push -- Sources`) and once with it. Check that tracks you did not touch are unchanged, or change only by a few notes where they react to the fixed track (Chill leads and Rhythm clear around the bass).

## Fixes, in priority order

### 1. Chill Blues bass (done, heard and approved 2026-11-13)

Changed 2026-11-13, uncommitted at time of writing, build 138:

- CHL-BASS-012 Rumba takes the chord's own 3rd, and in Blues plays the chord's 7th on beat 4 instead of the 6th. Soho keeps the 6th as its Latin colour.
- CHL-BASS-011 Ascending riff: the downward opener is 7th, 5th, root instead of 6th, 5th, root.
- CHL-BASS-004 Air ostinato in Blues: the 2nd becomes the b7 below the root.
- Refactor: `ChordType.chillThird` and `chillSeventh` (shared with the pads), one `ostinatoBar` helper.

Measured on 151 Blues seeds: strong bass clashes 1,551 to 167. Notes in `docs/chill-blues-plan.md` (3.0 entry).

To do: Zack listens to After Dark Soiree Blues (seed 633285336541947677) bars 13, 29, 33–40, 45 and 61, then commit.

### 2. Chill Blues beat-4 approach note (done, heard and approved 2026-11-13)

Done 2026-11-13, uncommitted, same batch as item 1. All 147 beat-4 clashes on the 151 seeds came from the IV/V `ivvIsApproach` branch; the walking line's beat 4 (a scale note, usually the b7) and the variation passing tone never clashed and are unchanged. Beat 4 now plays the current chord's 5th; the half step below the next root passes on step 14 as an 8th, once per 16-bar form (tracked by section start bar and form index), the first time the chord changes, capped at 12 a song. Songs on this option now get 4 to 7. No new random draws. Marked F: CHL-BASS-001, 003, 010 (011 already F).

Measured: beat-4 clashes 147 to 0; strong bass clashes 167 to 20; songs over 4 from 18 to 2 (CHL-BASS-004 and 009, untouched); Chill Blues problem songs 19% to 7%. Base Chill and Soho identical; a few Blues Lead 1, Lead 2 and Rhythm notes moved where they clear around the new bass.

Follow-up the same day, after Zack heard `~/Downloads/Zudio passing chromatic demos/` (Riviere-du-Loup fine, West End Cornichon grating) and set the colour-or-grating rule:

- CHL-BASS-009 Pickup: the "b3" pickup and the step-12 b3/b7 are now the chord's own 3rd and 7th (`chillThird`, `chillSeventh`). A fixed +3 snapped to the scale gave C# under the pads' D on a IV7sus4 in E Dorian, held through beat 3. The first-B-form tail on step 14 played the half step under the current root in every bar for 32 bars, against the pads and Rhythm; it now plays the b7, and the half step below the next root only into a chord change, from the same allowance as the approach (one per form, 12 a song; `chromaticPassAllowed` in `bluesBass`). Marked F.
- CHL-BASS-011 upward opener: the 6th passes only as a 16th (rhythm template C, as in Riviere-du-Loup's A section). As an 8th (templates A and B, and the first B form) it sat under the b7 in pads and Rhythm through the I-chord stretch; it is now the chord's 7th (5th, 7th, root). Riviere-du-Loup changes in bars 37–67 only.
- 012 Rumba's off-beat notes don't make persistent rubs; unchanged.

Measured after all of it: strong bass clashes 167 to 10, songs over 4 from 18 to 1 (one CHL-BASS-004); persistent rubs in Blues 7 songs to 0; Blues problem songs 19% to 7%. Base Chill and Soho unchanged; a few lead notes in 009 and 011 songs clear around the new bass.

To do: Zack listens to the five demo songs below; after-fix versions are in `~/Downloads/Zudio beat-4 approach demos/after fix/` (made before the 009 and 011 follow-up; reload the .zudio files for the current notes). Then commit with item 1.

Original notes: Zack listened (2026-11-13): it sounds bad. A chromatic approach is fine as an off-beat passing tone (later the same day: up to 6 a song, or 12 if musical), never on a strong beat. Same file as item 1, so do it in the same session if there is room.

- What: before a chord change, the bass plays a chromatic half step into the next chord's root on beat 4 (step 12). About 2 a song; 16 of 151 Blues songs have more than 4, up to 9. Heard in CHL-BASS-001, 003, 010 and 011 songs.
- Where (`ChillBassGenerator.swift`, `bluesBass` and `walkingLine`):
  - The IV/V "approach" option in the dispatcher (`ivvIsApproach`): root to step 11, then `nextRoot - 1` on step 12 for 2 steps. Every IV and V bar in a third of the songs that use 001, 003, 010 or 011.
  - `walkingLine` (CHL-BASS-003): quarter notes root, 3rd, 5th, then an approach (`snapToScale(chordRoot - 1)`) on beat 4 for a full beat.
  - Check also the Blues variation "passing tone" (`applyBassVariation`), which can drop a chromatic note into a gap, and the B-form tails of CHL-BASS-009 and 012 (already on step 14, off the beat; confirm they stay short).
- Fix: beat 4 plays a chord tone of the current chord (the root or the 5th, held), and the chromatic approach, if kept, moves to the "and of 4" (step 14) as an 8th. The walking line's beat 4 becomes a chord tone that steps toward the next root, with any chromatic note only on step 14.
- Verify: rerun the 151 Blues seeds; strong beat-4 clashes should go to near zero. Re-listen to the five songs in `~/Downloads/Zudio beat-4 approach demos/` (YYZ Memorandum Blues bars 10, 13, 14, 26, 41; Alpina Document Blues bars 13, 26, 29, 30; L'Avenir File Blues bars 17, 33, 45, 49; Dark Detroit Blues bars 6, 14, 18, 33; Low Light Cornichon Blues bars 13, 29, 41, 45).

### 3. Kosmic Space bass, KOS-BASS-018 Oxygene Falling Walk (done in code, not heard)

The worst single rule by volume: in 70% of 103 Space songs, median 12 clashes, up to 100. Space is about 40% of Kosmic songs.

Done 2026-11-13, uncommitted. The walk is top, mid, low on a locked 16th grid (Oxygene 4), so the rhythm stays put and only the clashing note changes (Zack: Space is sequencer-based; option 1).

- Cause, measured on the 103 songs: mostly the mid note on beats 2 and 4, held across the beat, not the lift. The walk counts scale steps above the chord root, which ignores the chord. The 6th set's mid note is a b6 over minor chords (and over the major V with a leading tone), a semitone above the pad's 5th. The b7 set's mid note is a major 7th over the I and IV (and bIII, bVI) major chords, a semitone under the pad's root. Together about 5,500 of 9,500 raw bass clashes. The lift bar (last of each 8) plays the 9th on beat 1, a semitone under a minor 3rd, or the b2 over a Phrygian-coloured chord: about 1,400 more (Pyreon Part IV bars 8 and 16).
- Fix (`walkDegrees` in `CosmicBassGenerator.swift`): when the mid note is a semitone from a chord tone it takes the other of 6th and 7th (b6 becomes b7, major 7th becomes 6th), so the fall stays top, mid, low. When the lift's 9th rubs, it becomes the 10th (the chord's 3rd an octave up). The octave-5th-3rd set and the short off-beat low notes are unchanged. Thin bars keep the plain figure, as before. No new draws. Marked F.
- Measured on 500 Kosmic seeds: only the Bass track changed, in 102 of the 103 Falling Walk songs. Clashes caused by the Space bass 2,258 to 111. KOS-BASS-018 no longer appears in the problem list (was 77%, persistent rubs in 23 songs). Space problem songs 86% to 73%, songs with persistent rubs 40 to 19. What remains in these songs comes from other rules: Rhythm and leads holding a major 7th or b2 against the bass root.
- Hear: `~/Downloads/Zudio Falling Walk demos/` (before is MIDI only; a before .zudio would reload with the new code). Bars that change: Hypnotique Part 8 (kosmic_02ceb8ad2b3c179b) 5–6, 11–14; Vortexe Pulsotron (kosmic_bd173ff001f3165b) 5–6, 8, 11–14; Inner Luminare (kosmic_0dfebe14cb10c60b) 5–14; Quantique Minipod (kosmic_c051260e59c90139) 5–6, 11–14. Same pattern every 8 bars after.
- Heard 2026-11-13 (Quantique Minipod): keep the fix, but it was a mild clash, not a glaring one. The walk was E, D#, B over E and A, G#, E over A, with the bass two octaves under the pad. Graded by severity, KOS-BASS-018 was glaring in 11% of its songs and mild in 66%. Quantique's Lead 1 (KOS-LD1-014) has six one-beat minor 9ths that step on (bars 5, 7, 21, 23, 105, 107). They are mild, and with the fix the song has no glaring clashes.

### 4. Chill Soho Lead 1: bring it under ChillClearance (done in code 2026-11-13, uncommitted, not heard)

Soho Lead 1 was left out only by scope: Soho was frozen for the 2.7 release when ChillClearance went in. Done: `sohoLead1` takes the `band` and voices its finished line through `ChillClearance.voiceLine`, for all five Soho rules (010, 011, 012 and the reused 001 and 004, which base Chill already clears). In Soho, Rhythm is written before Lead 1, so the band is Pads, Bass and Rhythm. The Lead 1 regen sites pass the same band. No new draws. Marked F: CHL-LD1-010, 011, 012.

- Measured on 1,501 Chill seeds (461 Soho). Base Chill and Blues are byte-identical. In Soho, Lead 1 changed, and Lead 2 changed in 339 songs where it answers the new Lead 1. Soho glaring problem songs went from 37% to 2%, and Soho Lead 1 glaring clashes from 1,945 to 311. No Soho rule is left on the problem list (010 was at 50%, 012 at 30%, 011 at 29%). What's left is mostly short passing notes, which the clearance allows.
- About 15% of Soho Lead 1 notes moved, mostly by a semitone or a tone, against about 9% in base Chill.
- For Zack to judge by ear: hooks flatten where a moved note lands on its neighbour. Thunder in the Lobby's Avalon hook goes from C#–C#–D–B (the D is the 4th over A's major 3rd, against the pad's C#4) to C#–C#–C#–B. Hackney Evening's Operator hook goes from D–Eb–Eb–C (Eb is the b7 over F6, a major 7th under the pad's D5) to D–D–D–C. The hook's returns change the same way, so the repetition level is kept. The clearance also checks the octave above, because the lead filter can lift a figure, so a chord tone under a pad's 9th sometimes moves too (Hackney Evening bar 7: Bb4 to G4 under A5).
- Hear: `~/Downloads/Zudio Soho Lead 1 clash demos/` (before is MIDI only). Thunder in the Lobby bars 2–13, Hackney Evening bars 5–11 and 21–29, Oxford Street Terrace bars 5–15, Carnaby Street Espresso (Sustained tone) bars 8, 15, 23 and 35.
- Committed 229214c. Zack heard the demos (2026-11-14) and chose option 2 of three: keep the clearance, but a moved note keeps the hook moving. Done, uncommitted, not heard. `voiceLine` takes `avoidRepeat` (default false, so base Chill is unchanged); Soho's `voiced` passes true. A moved note doesn't land on the note before it (as voiced) or after it (as written) unless the line repeated there, and a written repeat follows the previous note's move. With no other clear note, the old pick stands.
  - Hooks: Thunder in the Lobby C#–C#–D–B is now C#–C#–E–B (was C#–C#–C#–B), and C#–D–E–E is C#–B–E–E (a first try that skipped only the note before gave C#–E–E–E). Hackney Evening D–Eb–Eb–C is D–F–F–C (was D–D–D–C), and A–A–G–C–D is Bb–Bb–G–C–F (was G–G–G–C–C). Oxford Street Terrace C–D–D–D is C–Bb–Bb–Bb (was four Cs).
  - Measured on the same 1,501 seeds against 229214c: base Chill and Blues byte-identical; Soho Lead 1 changed in 447 songs (5.9% of its notes), Lead 2 in 247. Soho glaring problem songs unchanged at 2% (12 to 13 songs); Soho Lead 1 glaring clashes 311 to 314. Runs of three or more of the same note in Soho Lead 1: 5,244 as written, 5,258 at 229214c, 4,611 now.
  - Hear: `~/Downloads/Zudio Soho Lead 1 clash demos/after (no repeats)/`, same bars. Carnaby Street Espresso is unchanged from 229214c.

Original notes:

- Rules: CHL-LD1-012 Avalon (76% of its songs, median 6, up to 32), CHL-LD1-010 Operator (70%), CHL-LD1-011 Sustained tone (67%). Soho Lead 1 caused 957 of Soho's clashes.
- Cause (confirmed): Soho Lead 1 is deliberately outside ChillClearance (change log, "Chill leads no longer rub against the band": "Soho's Lead 1, Pads, Rhythm and Bass are unchanged"). It holds the 4th over a major 3rd and the 11th over maj9 (Dean Street Lights, bars 19 and 22).
- Investigate first: why Soho Lead 1 was left out. If it was only scope, passing Soho Lead 1 through the existing clearance is likely a small change. Operator (010) is a Zack favourite with a preferred repetition level; check that clearance does not break its hook.
- Hear: Thunder in the Lobby (chill_4619e5dbcbf5514c) bars 2–13.
- Also in Soho: CHL-PAD-008 Half-bar pad (Sloane Square Morning, chill_5c2472e5f9e65abf, bars 38–68; Denmark Street, chill_74e69a5d0dd27a65, persistent rub bars 66–78) and CHL-BASS-015 (persistent rubs: Small Hours on a Wednesday, chill_8aa4248c8857f9a4, bars 89–98; Denmark Street bars 23–27, 65–70). Look at these in the same session.

### 5. Motorik leads: a clearance pass for Motorik (done in code 2026-11-13, uncommitted, not heard)

Done: `MotorikClearance` (end of `LeadGenerator.swift`; it isn't a new file because the Xcode project lists files by name). A lead note that lasts an 8th or more and starts on a beat, or lasts a beat or more, moves when it is outside the chord and a semitone from a chord tone. It moves to the nearest clear scale note, a chord tone on a tie, almost always one semitone. Short notes off the beat and short passing notes (`ChillClearance.isPassing`) keep their pitch. No random draws.

- Lead 1 is written before Bass and Pads, so it is checked against the chord's tones, at the end of `generateLead1` and on the hook rules' output. MOT-LD1-005 (Zack's standing rule) and MOT-LD1-012 Chromatic Descent are skipped; they are the only Motorik lead rules still over 15% glaring (005 29%, 012 57%). Propose before touching either.
- Lead 2 gap answers (MOT-LD2-001 to 004, 006) are also checked against the Pads, Bass, Rhythm and Lead 1 notes already sounding (a semitone, major 7th or minor 9th). This happens at the end of `GapAnswerEngine.generate`, Motorik only; Kosmic's gap rules are unchanged. Both call sites pass `band:`.
- MOT-LD1-016 Machine Answer bug: every 8 bars its call starts on the chord's root, then 3rd, then 5th. It built a triad on that note with the key's 3rd, so out-of-key notes landed on every beat (an Ab major triad over E in Vienna). Pass A of the harmonic filter then cut about half of them, leaving two or three notes a bar, one out of key. The call is now the chord itself from that note (root position, then the inversions), so Vienna's Lead 1 goes from 181 to 252 notes, four chord tones a bar as designed.
- Measured on 500 Motorik seeds (Rhythm fix in both runs). About 8% of Lead 1 notes moved, almost all by a semitone, and about 7% of Lead 2 notes. Glaring problem songs: base 52% to 13%, Europe 17% to 4%, Arcade 10% to 3%, Noir 27% to 18%. Noir's Rhythm count rose 107 to 153 only because of attribution (a clash with both notes outside the chord counts against the later note). Noir's total glaring clashes fell 506 to 290. Kosmic unchanged.
- Marked F: MOT-LD1-004, 009, 010, 011, 013, 014, 016 to 020 (001 to 003 and 006 to 008, and the Lead 2 gap rules, already carry the testing star).
- Hear: `~/Downloads/Zudio Motorik clash demos/` (before is MIDI only). Sud Munchen bars 17–19 (B4 under the pad's C5 now C5: E–D–C–A). C Pulse bars 15 and 17 (Lead 2's Ab3 held 2 beats under the pad's G4 now G3). Vienna bars 12, 20, 28 (Machine Answer complete).

MOT-LD1-012 Chromatic Descent, checked 2026-11-13 (Zack asked whether its clashes are real): **they are real, and glaring.**

- It plays only in Noir: 7 of 500 Motorik seeds, glaring in 4.
- Lead 1 is a sustaining saw lead (program 81). The descent holds each chromatic step for 3 to 4 beats, nearly a bar, a semitone from a note the Pads or Rhythm hold in the same octave.
- E Tone (motorik_75cfef7f85616709, E harmonic minor, 24 glaring): Bb4 for 3¼ beats over the pad's A3 and the Rhythm's A4, bar 16; B4 for 3¾ beats under the pad's C5, bar 28.
- Tone Rad (motorik_59a071a9c984e3cd, E Phrygian, 10): F#4 for 4 beats over the pad's F4, bars 17, 18, 30; Bb4 over the pad's A4, bar 14.
- Dunkel Dusseldorf (motorik_8e469e6f14388e02, A Aeolian, 11): F#4 and Bb4 held 3 to 3½ beats a minor 9th over the Rhythm's F3 and A3, bars 16, 19, 20, 23.
- It is chromatic by design, so the general clearance would turn the descent into repeated notes. Three options were put to Zack: (1) hold only clear notes, with the chromatic step as a short off-beat passing note; (2) keep the held steps but shorten each to a beat; (3) descend through the scale where a step would rub. Zack chose option 1 (2026-11-13: "I hear it on long sustain instruments"; keep the code simple).
- Fixed 2026-11-13, uncommitted, not heard. In `lead1ChromaticDescent`, a step a semitone from a chord tone is not held: the bar holds the nearest clear scale note behind it (above on the way down, below on the arc's way up), and in the bar before the line moves on, the step itself plays as an 8th on the "and" of 4 (`hold`). Up to 12 passing notes a song (`chromaPassCount`); after that the clear note is held alone. Tone Rad bars 17–18: F#4 held over F becomes G4 with F#4 passing into F4. The 20% echo repeats the held note. The fast runs are unchanged, and 012 stays in `clearanceSkipBars` because the fix does not rely on the clearance. No new draws. Marked F.
- Measured on the 113 Noir songs that use 012 among 5,000 Motorik seeds: Lead 1 changed in all 113, and Pads and Rhythm changed in one (Sud Middelbrau, where they react to Lead 1). Lead 1 glaring clashes went from 1,231 to 62 and Noir problem songs from 65% to 15%. MOT-LD1-012 dropped off the problem list (it was at 64% glaring). The uncapped first version gave a median of 16 passing notes a song, so the cap is 12 and most songs reach it.
- What remains: a held step that is clear of the chord but sits a minor 9th over a Rhythm note that isn't in the chord. Example: Dunkel Dusseldorf bars 19–20, Bb4 over Fsus2 with the Rhythm's A3. Lead 1 is written before the Rhythm and can't see it. These are rare, so they are left alone.
- Hear: `~/Downloads/Zudio Motorik clash demos/chromatic descent (fixed)/`. E Tone bars 13–16 and 28, Tone Rad bars 13–21 and 30, Dunkel Dusseldorf bars 15–16 and 22–24.

Original notes: the biggest group of rules. Motorik base is 72% problem songs, mostly Lead 1 and Lead 2.

- Lead 1: MOT-LD1-012 Chromatic Descent (7 of 7 songs, median 14), MOT-LD1-016 Machine Answer (73%), MOT-LD1-013 Slow arc (71%), MOT-LD1-004 Stepwise sequence (66%), MOT-LD1-007 Vanishing solo (62%), MOT-LD1-003 Tour de France riff (57%), and MOT-LD1-008, 011, 005, 014 at 40–48%.
- Lead 2: MOT-LD2-003 Hook fragment (52%), MOT-LD2-001 Echo answer (48%), MOT-LD2-006 (43%).
- Typical case: Motorik songs sit on one chord for most of the song (a power chord or drone, often for 100+ bars). A scale note a semitone from the drone, held on a beat, clashes (Dunkel Helles bar 56: Lead 2 C# against D in Pads and Rhythm).
- Proposed approach: one session to design a Motorik clearance modelled on ChillClearance (check each held lead note against the Pads, Rhythm and Bass already written; move a clashing note to the nearest clear scale note, preferring chord tones; leave short passing notes). Then apply it where the Motorik lead rules write notes. MOT-LD1-012 Chromatic Descent is chromatic by design and may need its own treatment.
- Never replace MOT-LD1-005 (Zack's standing rule); clearance that moves a note is fine, but propose it.
- Hear: Nord Leipzig (motorik_de98ae789a2ac845, Arcade) bars 33–40; Spur Radler (motorik_c18caf101da8886a, Arcade) bars 33–38, 57–58.

### 6. Motorik Rhythm, MOT-RTHM-004 2-bar Melodic Riff (done in code 2026-11-13, uncommitted, not heard)

Done: the riff counts intervals from the chord root and ignored the chord, so a 2nd over a minor chord or a 4th over a major one sat a semitone from the pad's 3rd. Bewegt Bahn (motorik_0d15bba5325737a8) played A4 under the pad's Bb4 over G minor on beats 3 and 4, 34 times. Such a note now moves to the nearest chord root (`clearOfChordTones` in `RhythmGenerator.swift`). The first version moved it to the nearest clear scale note, which gave Bewegt Bahn C–Bb–Bb–Bb; Zack: "3 Bb in a row doesn't sound very musical", so it now plays C–Bb–G–Bb. No new draws. Marked F. Measured on 500 Motorik seeds: only Rhythm changed. Motorik base Rhythm glaring clashes 641 to 97, Europe 168 to 61; MOT-RTHM-004 no longer in the list. Zack (2026-11-13): fix glaring clashes even on a fast-decay patch like this one's muted guitar, because the pool has patches that sustain. Hear: `~/Downloads/Zudio Motorik clash demos/` Bewegt Bahn bars 11–12.

Original notes:

- 52% of its songs, median 10, up to 123. The worst song in Motorik base and Europe.
- Investigate: a melodic riff over a fixed chord; likely fixed intervals that land a semitone from the pad or bass. Fix in the pattern if so, or add Rhythm to the clearance from item 5.
- Hear: Stollen Blitz (motorik_885f376a645a3f72) bars 5–8, 17–22; Zentral Zeit Bahn (motorik_94ed1f6837e22146, Europe) bars 5–15.

### 7. Kosmic leads and Rhythm

- Lead 2: KOS-LD2-005 Space echo reply (done in code 2026-11-13, uncommitted, not heard). Its held note counted scale steps up from the bottom of the register and ignored the chord, so it landed a semitone from a pad note. Example: Orpheon II (kosmic_7464fed5d7788341) held G#3 for 3 to 3½ beats under the pad's A3 over F# minor, in bars 7, 15, 23, 79 and 87. Zack didn't hear it as a problem (quiet: pad velocity 31, Lead 2 41 in bar 7), but it was a same-octave semitone, so it was fixed.
  - Fix (`spaceEchoReplyBar` in `CosmicLeadGenerator.swift`): a held note a semitone from a chord tone, or within a semitone, major 7th or minor 9th of a Rhythm or Lead 1 note in the bar, moves to the nearest clear scale note (0, +1, -1, +2, -2 steps). The second note of each pair tries the first note's move and never repeats it, so the two-note step survives: Orpheon II's G#–A becomes A–B. The pads are written after Lead 2, so the chord's tones stand in for them. No new draws. Marked F.
  - Measured on 500 Kosmic seeds: only Lead 2 changed, in all 60 songs on this rule. Glaring Lead 2 clashes 557 to 12; songs over 4 from 45 to 0. Kosmic Space glaring problem songs 48% to 33%.
  - Hear: `~/Downloads/Zudio glaring clash check/` has Orpheon II.MID (before) and the `Orpheon II after` folder, bars 7–8 and 15–16.
- Rhythm: KOS-RTHM-021 Oxygene 8 Offbeat Pedal (60%), KOS-RTHM-005 JMJ dual arpeggio (56%), KOS-RTHM-007, 002, 006 at 20–26%.
- Rhythm 021 and 005 (done in code 2026-11-14, uncommitted, not heard). Both write fixed notes that ignore the chord. Zack chose the recommended fix for each.
  - KOS-RTHM-021 (`generateOxygeneOffbeatPedal`): the upper voices are scale steps above the chord-root pedal. Most clashes came from the 30% variant (6th, 5th, 4th). Rotonde Part VI (kosmic_a5081794cf3d3dcd, E Aeolian): C, the b6, over E minor against the pad's B every bar; over B major (V), G and E against the pad's F# and D#; over C major, F# against G. Fix: an upper note a semitone from a chord tone steps off it. The 6th goes up to the 7th; the 4th and the 7th go down a step. Steps count in the chord's own scale (`spaceChordScale`), so the V's leading tone is counted. E C E B C A becomes E D E B D A; over B major G becomes A and E becomes D#; over C, F# becomes E. Rhythm and draws unchanged.
  - KOS-RTHM-005 (`dualRateNotes`): the pool is anchored to the key's tonic (root, 3rd, 5th, b7), from the Phase 3 coherence fix. Pneumex III (kosmic_d4b59c0536cdf8a1, D Aeolian): D against the pad's C# over A major, A against Bb over Bb major. Fix, Kosmic Space only (`followChord`): a pool note a semitone from a chord tone takes that tone. Under the i nothing changes; over A major the pool is C#, E, A, C#; over Bb it is D, F, Bb, C. Base Kosmic is left alone because its pads don't voice the logged Modal Drift chord. A first version that applied there moved Luxieme's Rhythm onto Ab in A Aeolian (the log says "b6 minor", the pads play F, B, E).
  - Measured on 1,000 Kosmic seeds: base Kosmic and Drift byte-identical. In Space, Rhythm changed in 114 songs and Lead 2 in 41 (the echo reply clears around the Rhythm). Space glaring problem songs 33% to 19%; Space Rhythm glaring clashes 3,184 to 374; neither rule left on the problem list (021 was 48%, 005 45%). Space Lead 1's count rose 502 to 520 by attribution only (Lead 1 unchanged). No Rhythm note outside the key and the chord, before or after.
  - Hear: `~/Downloads/Zudio Kosmic Rhythm clash demos/` (before is MIDI only). Rotonde Part VI and Gravitone Laserharp (021, every bar from bar 1; Gravitone's Bb over D minor becomes C). Pneumex III bars 7–10 and 15–18, Vortexe Part VII bars 9–10 and 17–20 (005, the V and bVI bars).
  - Marked F: KOS-RTHM-021, KOS-RTHM-005.
- Lead 1: KOS-LD1-013, 015, 018, 006, 007, 014, 016 at 33–50%.
- Proposed approach: reuse the clearance from item 5 for Kosmic leads. For the Rhythm rules, check first whether the arpeggio notes are fixed intervals (pattern fix) or follow the chord (then the clash is with a pad or lead and clearance applies).

### 8. Bass and pad outliers

Rarer rules with very high counts when they fire. Probably fixed note choices in the pattern; one look each.

- MOT-BASS-007 Hook Ascent: one Noir song at 162 (Axis 1 Apocalypse, motorik_3dab50b876bc3709, bars 3–12).
- MOT-BASS-016 Wobble Pulse: Wumms Kreis (motorik_24dbbefdba8ed768) at 62, bars 15–30.
- KOS-BASS-016 BoC loop (57% of its songs): Trans Dimensione (kosmic_8e36749508b7b7c7) bars 12–29.
  - Checked 2026-11-14 on the 1,000 Kosmic seeds: glaring in 14 of 32 songs, all Drift. The cell is root, 2nd, root, 5th, a quarter each, every bar (`bocLoopBar`), with the 2nd a fixed +2 semitones. Over a chord whose pads voice a minor 3rd, the 2nd sits on beat 2 for a full beat a semitone under it: 229 of 254 glaring clashes (90%). Duophonic Aureon (Eb Dorian): bass Eb3 F3 Eb3 Bb2 under the pads' and Rhythm's Gb3. Chronique VII (A Aeolian, logged sus4): bass B2 under the pads' C3. The 30% shift raises the 2nd to a fixed minor 3rd, which is out of the key over a major chord (Hyper Paradoxe: C3 under the pads' C#3).
  - Fixed 2026-11-14, Zack's choice (Kosmic is sequencer-driven: change the note, keep the shape, no passing tones). In `bocLoopBar`, where the key's 3rd above the root is minor, the 2nd plays the minor 3rd: root, b3, root, 5th. A sus2 chord keeps the 2nd, because its Rhythm plays it (a first version without this put Duophonic Aureon's bass F#3 against the Rhythm's F3 over sus2). The 30% shift raises the 2nd to the key's own 3rd instead of a fixed minor 3rd. No new draws. Marked F.
  - Measured on the 1,000 Kosmic seeds: only Bass changed, in 29 Drift songs, all on this rule. KOS-BASS-016 glaring 14 of 32 songs to 6, its glaring clashes 254 to 112. Drift problem songs 24% to 20% (with the pads fix). What's left is mostly the Rhythm's out-of-key minor 3rd on a degree whose third is major in the key (89 clashes; Faint Spectrum, E Mixolydian: Rhythm C3 over A, bass B2), the side finding under KOS-PADS-005.
  - Hear: `~/Downloads/Zudio BoC loop clash demos/` (before is MIDI only). Duophonic Aureon 31 to 0, Chronique VII 26 to 0 (bass A2 C3 A2 E3 under the pads' C3 E3), Inner Flexure 16 to 0.
- KOS-PADS-005 Stacked fourths: up to 110 (Flummoxx V, kosmic_97e62536048704f6; Exo Cosmique, kosmic_d324e5299f067c31). Stacked fourths over a minor chord may put a fourth a semitone from the third.
  - Checked 2026-11-14 on the 1,000 Kosmic seeds (random seed 11), against the actual notes. Glaring in 28 of 90 songs. The cause is not the third. `quartalStackBar` stacks root, 4th and b7, and snaps a voice that leaves the key upward. A b7 out of the key becomes the major 7th, a semitone under the root that the Bass, Rhythm and leads play (419 of 582 glaring pad clashes, 72%). Examples: Cold Matter (Ab Mixolydian, Db chord) plays Db, Gb, C against the bass's Db3; Sub Hexalon (A Dorian, G chord) plays F#4 against Lead 1's G4. On the chord whose 4th is out too, the 4th becomes the #4, a semitone under the 5th (Axiome in Stereo, D Aeolian, Bb chord: Bb, E, A).
  - This also explains the handover gotcha: Luxieme's "F, B, E" over the logged F minor is this rule's snapped 4th and b7, not a different chord.
  - Prototype (option 1 below, patch saved in the session scratchpad, reverted): an out-of-key b7 becomes the 5th (a fourth below the root), and an out-of-key 4th becomes the 9th (a fourth below the 5th), so the stack stays in perfect fourths and in the key. Measured: only Pads changed, in 34 base and 4 Drift songs. Lead 1 and Lead 2 moved an octave in 2 songs (they read the pad register). Space byte-identical. KOS-PADS-005 songs over 4 glaring clashes 28 to 7; the rule drops off the problem list. Base Kosmic problem songs 28% to 25%, glaring persistent runs 21 to 15, base pad glaring clashes 707 to 332. Exo Aetheron 68 to 0, Spandexx 42 to 0, Oxidane 29 to 2.
  - The 7 left come from other tracks playing notes outside the key: a bVII chord root in Ionian, which the pads snap up and the bass doesn't (Cyber Transcendome: pads C#, bass C; 10 of 627 base and Drift songs have this root); a "minor" chord on a degree whose third is major in the key (Solaxe V, E Mixolydian: Rhythm and bass play F natural over D); and a Rhythm playing the major 3rd under the quartal 4th (Still Interval, Still Canopy).
  - Options put to Zack: (1) stack down, as prototyped; (2) snap down instead (b7 to 6th, #4 to 3rd), which turns the stack into a triad; (3) drop the out-of-key voice. Zack chose option 1 (2026-11-14). Done in `quartalStackBar`, uncommitted, not heard; no draws. Marked F.
  - Hear: `~/Downloads/Zudio Kosmic pads clash demos/` (before is MIDI only; after has .MID and .zudio).
- KOS-PADS-003 Steve Roach unsync layers (Eideon VII, kosmic_ee429e47a3bb2b8f, bars 12–27): the layers drift against each other by design. Ask Zack before treating these as a bug.

### 9. Lower priority

- CHL-LD1-007 Horace hook in base Chill: 19% of its songs, up to 24 (Summer Kirkland, chill_8052b13cdc7e351e). It goes through ChillClearance already, so find what slips past: probably a version transformation (filled, laid back) after clearance.
- Chill Blues Rhythm plays the 9th or 13th (A in G) a major seventh above the pad's Bb. Mild, and common jazz voicing; listen before acting.
- Motorik Arcade (19%) and Chill base (8%) are mostly covered by item 5 and the Horace hook above.

### 10. Not yet scanned

- Ambient (all substyles). Its pads and textures may use clusters on purpose. Zack (2026-11-14): don't worry about Ambient; leave it unscanned unless he hears something.
- Regenerated tracks and Evolve passes: the scan covers fresh songs only.

### 11. Out-of-key chord 3rd, Kosmic Drift and Space (done in code 2026-11-14, uncommitted, not heard)

Zack asked for this after a rescan showed it was the one structural cause left. Three small fixes, all no new draws. Measured on the same 1,000 Kosmic seeds (random seed 11) as item 8, before (9342e16) and after.

- **The chord type** (`keyThird` in `CosmicStructureGenerator.swift`, called in `buildChordWindows`). The base and Drift chord pickers draw "minor" whatever the degree. That gave a minor tonic in Mixolydian, a minor IV in Dorian, a minor bVII in Mixolydian and a minor bVI in Aeolian. The pads voice the key's 3rd (they follow the mode), but Rhythm and Bass follow the type, so they played the out-of-key 3rd against it. Solaxe V (E Mixolydian): Rhythm and Bass F natural under the pads' F# over D. Now a minor or major chord takes the key's own 3rd on its root, after every draw. A root outside the key (the bVII in Ionian) is left alone. Space builds its own chord plan and is unaffected.
  - Measured: half of Drift's glaring clashes had an out-of-key chord 3rd (477 of 907, in 42 songs); now none. In Drift, Rhythm changed in 56 songs, Lead 1 in 7 and Bass in 1. Base Kosmic carried the same mislabelled windows but had no glaring clashes from them. Its Lead 1, Lead 2 and Bass changed in about 35 songs; glaring clashes in those songs went from 296 to 283 (Omni Prism 8 to 4, Empyrion's Rhythm 8 to 1).
- **KOS-BASS-014 Smooth Arpeggio** (`smoothArpeggioBar` in `CosmicBassGenerator.swift`, Drift). Its 3rd was the tonic's 3rd (`Mixolydian or Ionian ? 4 : 3`) over every root. That gave B natural over Ab in C Aeolian (Frozen Void) and F natural over D in E Dorian (Spectrion Dream). It agreed with the wrong chord type before, so the chord fix exposed it. Now it plays the key's 3rd above the chord root, the same line as the BoC fix. Bass changed in 11 Drift songs; their glaring clashes went from 90 to 42 (Orthodoxx II 59 to 32, Spectrion Dream 8 to 0). Marked F.
- **KOS-RTHM-002 JMJ Hook in Space** (`jmjHookNotes` and the harmony voice in `generateJMJHook`, `CosmicArpeggioGenerator.swift`). Over the major V of Magnetic Arc and Turn, the hook's 3rd (the leading tone) was snapped to the key and rounded up to the tonic, against the pads' leading tone. Rendez-Vous a Vectore (D Aeolian): D over A major under the pads' C#, every V bar. `fitSpaceChordScale` couldn't catch it because the tonic is in the key. In Space (`followChord`), a chord tone is now taken as it is, and any other note snaps to the key and then takes the chord's alteration (`spaceChordAlterations`). The harmony voice counts its thirds in the chord's scale (`spaceChordScale`). Base Kosmic passes the mode as before and is unchanged.
  - A first version snapped every note to the chord's scale. Over G major in C Aeolian, that took the hook's 2nd down to Ab, a semitone over the root (Waiting for Sputnique bar 33: G Ab D). It also left the harmony's key-scale third above B as Eb, now an octave up against the pads' D (Les Chants Cosmiques). The current version plays G B B D with harmony B D D F.
  - Measured: Rhythm changed in 11 Space songs and Lead 2 in 1; their glaring clashes went from 167 to 111. Space Rhythm glaring clashes 374 to 312. Rendez-Vous a Vectore 26 to 5. KOS-RTHM-002 drops off the problem list. Marked F.
- **Regressions the chord fix exposed, and their fixes** (Zack: fix them without complicating the code). Each is the same move inside the rule: the rule's 3rd follows the chord, and over a major 3rd a held 4th steps aside. No new draws, except in KOS-RTHM-008 (below).
  - **KOS-PADS-004 Suspended sus4 minor** (`suspendedResolutionBar` in `CosmicPadsGenerator.swift`). The pad holds root, 4th, 5th for 3 bars of 4, under a Rhythm that plays the full chord. Over a major chord its 4th sat a semitone above the Rhythm's 3rd. Slow Nimbus (E Mixolydian) went from 13 to 39 with item 11's chord fix: Rhythm G#3 under the pads' A3. The 4th bar was also meant to resolve to the 3rd, but `mode.nearestInterval(3)` ties 2 and 4 in a major-3rd mode and picked the 2nd, so it never resolved there. Now, over a major 3rd, the suspension is the 2nd (a whole tone under the 3rd), and the resolution plays the chord's own 3rd. A chord with no 3rd (sus4, power, quartal) keeps the old code. Pads changed in 38 songs; glaring clashes in those songs went from 529 to 342 (base 380 to 316, Drift 149 to 26). Slow Nimbus 13 to 0. Marked F.
  - **KOS-PADS-005 Stacked fourths** (`quartalStackBar`). Picked over a chord that is now major, its 4th sat on the Rhythm's 3rd (Formless Expanse, D Dorian: F over C major against the Rhythm's E; base songs with this went from 1 to 4). Over a chord with a major 3rd, the 4th now becomes the 9th, the same move its out-of-key fix already makes. Quartal and sus chords are unchanged. Pads changed in 18 songs; Formless Expanse back to 0. Already marked F.
  - **KOS-RTHM-008 Oxygene 8-bar Arc** (`generateOxygene8Bar`). The same `nearestInterval(3)` tie meant the arc had no 3rd in major modes, and its 4th, held about a bar, sat over the major 3rd (Void Perihelion, A Mixolydian: D over the pads' C#). The arc's 3rd now follows the chord, and over a major 3rd the 4th becomes the 6th. This one does add draws: in a major-3rd mode the old 3rd was the 2nd, a duplicate, so the pool grows from 5 notes to 6. The arc plays `min(noteCount, pool.count)` notes with three draws each, and the start-index draw's range moves, so a 6- or 7-note arc draws more (corrected 2026-11-14 in the code review; the pool is one octave, not the two its old comment claimed). Rhythm changed in 18 songs: base 69 to 60 glaring, Drift 11 to 14 (single clashes where the restored 3rd meets a passing lead note). Marked F.
- **Totals against 9342e16, all fixes:** Kosmic Drift problem songs 20% to 9%. Base 25% to 24%. Space 19% to 19% (73 to 72 songs). In the songs that changed, glaring clashes went from 601 to 100 in Drift, 761 to 627 in base and 167 to 111 in Space. KOS-BASS-016, KOS-BASS-006 and KOS-RTHM-002 drop off the problem list. Motorik and Chill code was not touched.
- **Regression check.** Every one of the 1,000 songs was compared before and after, and every song whose glaring total rose by 3 or more was read. One is left: Polar Aurora (base, B Mixolydian), 4 to 9. Lead 1 and Lead 2 hold E, the 4th, over B major, on KOS-PADS-004's resolution bars (80, 84, 92, 108). The pad now plays the 3rd there, where it used to play the 2nd by mistake. The pad is right. Moving the lead note would take a Kosmic lead clearance, which Zack ruled out, so it stays.
- Hear: `~/Downloads/Zudio out-of-key third demos/` (before is MIDI at 9342e16; after has .MID and .zudio on the final code):
  - Solaxe V 51 to 0, bars 29–48.
  - Paraphonic Flexure 38 to 0, bars 33–55.
  - Algorhythme VII 29 to 0, bars 14–39.
  - Rendez-Vous a Vectore 26 to 5, every V bar (8, 15–16, 23–24 and so on).
  - Slow Nimbus 13 to 0 (KOS-PADS-004), bars 20–76: the sus2 suspension and the real resolution every 4th bar.
  - Waiting for Sputnique 12 to 12 (the hook over the V, bar 33: G B D, unchanged from before).
  - Formless Expanse 0 to 0 (KOS-PADS-005's 9th over C major, bars 21–26).
  - Void Perihelion 4 to 3 (KOS-RTHM-008's arc over A major).
  - Polar Aurora 4 to 9, the one leftover, bars 80, 84, 92, 108.

## Where it stands (2026-11-14) and what's left

Glaring problem songs after items 1 to 11 (from 1,000 seeds per style; Chill from 1,501):

- Chill base 2%, Chill Soho 2%, Chill Blues 7%.
- Motorik base 11%, Noir 7%, Europe 6%, Arcade 6%. Median glaring clashes per song: 0.
- Kosmic Drift 9%, Space 19%, base 24%.

This is the point of diminishing returns. No rule is glaring in more than a quarter of its songs, and no single cause stands out. In base Kosmic, 97% of the remaining glaring clashes have both notes in the key: scale neighbours spread across Lead 1, Lead 2, Bass and Rhythm, with no pattern behind them. The only general fix would be a Kosmic clearance pass, which Zack ruled out (Kosmic is sequencer-driven; counts are small).

Future work, only if Zack hears a problem (each needs his go-ahead, because each changes a figure):

1. **KOS-RTHM-002 scale walk over minor.** The hook's third shape (root, 2nd, 3rd, 5th) puts the 2nd a semitone under the pads' minor 3rd. In the quarter and dotted-8th versions it lands on a beat: 182 glaring clashes in 7 songs, and the rule's worst song. Le Grand Eideon (kosmic_22ffc9ccac21941d, B Dorian) has 61, with C#3 against the pads' D3 from bar 1. A fix like MOT-LD1-005's would climb root, b3, 4, 5 over minor chords.
2. **Leads holding the 4th over a major chord** (Polar Aurora, item 11). Spread thin: 1 to 3 per song across Space, base and Drift. Only a Kosmic lead clearance would move them, which Zack ruled out.
3. **The major V's 4-3 in Space.** Leads and pads hold the tonic over the leading tone, 1 to 3 per song across about 35 songs. A suspension by nature; leave it unless it is heard.
4. **The bVII root in Ionian** (Cyber Transcendome: pads C#, bass C). Only 2 songs have glaring clashes from it (47 in total).
5. **Next Kosmic rules on the list:** KOS-LD1-018 (25% glaring, 24 songs), KOS-BASS-004 (23%), KOS-LD1-002 and KOS-LD1-007 (21%). Small counts each.
6. **The Motorik log omits a B-section Lead 1 rule** that differs from the A rule (`bRule` in `LeadGenerator.swift`). It's a log gap, not a clash; it only matters to scans that pick songs by the logged rule.

Before the App Store build, the F marks (`fixMarkedRules` in `SongState.swift`) come out.

## Rescanning later

To check whether new code has added clashes, or to look at a style again:

1. **Seeds.** Use the same seeds each time so runs compare. From the repo root:
   `python3 -c "import random; r=random.Random(11); [print(s, '%016x'%r.getrandbits(64)) for s in ['kosmic']*1000+['motorik']*1000]" > <folder>/seeds.txt`
   For Chill, use `['chill']*1500`. Style names are the lowercased `MusicStyle` raw values.
2. **Throwaway test.** Create `Tests/ZudioTests/TmpClashDump.swift` (XCTest, because Swift Testing `@Test` functions don't run under `xctest -XCTest`):

   ```swift
   import XCTest
   @testable import Zudio

   final class TmpClashDump: XCTestCase {
       func testDump() throws {
           guard let dir = ProcessInfo.processInfo.environment["ZUDIO_DUMP_DIR"] else { return }
           let base = URL(fileURLWithPath: dir)
           let text = try String(contentsOf: base.appendingPathComponent("seeds.txt"), encoding: .utf8)
           for line in text.split(separator: "\n") {
               let parts = line.split(separator: " ")
               guard parts.count == 2, let seed = UInt64(parts[1], radix: 16),
                     let style = MusicStyle.allCases.first(where: { $0.rawValue.lowercased() == parts[0] })
               else { continue }
               let song = SongGenerator.generate(seed: seed, style: style)
               let url = base.appendingPathComponent("\(parts[0])_\(parts[1]).MID")
               try MIDIFileExporter.export(song, to: url)
               try SongLogExporter.export(song, midiURL: url)
           }
       }
   }
   ```

3. **Build and generate** with the real toolchain and the sandbox off (Claude: memory `reference_claude_session_toolchain`). In short: `swift build --build-tests --build-system native --scratch-path <scratch>/build` with the `-F` framework flags, then `SWIFT_DETERMINISTIC_HASHING=1 ZUDIO_DUMP_DIR=<folder> xctest -XCTest ZudioTests.TmpClashDump <scratch>/build/debug/ZudioPackageTests.xctest`. 2,000 songs take about 15 seconds.
4. **Scan:** `python3 tools/clash_scan.py <folder> --worst 3`. Read the problem rate per substyle and the per-rule list. Compare with the numbers under "Where it stands" above. A new rule over 15% glaring, or a substyle that rises a few points, is worth a look.
5. **Before and after a change:** generate once with the change stashed (`git stash push -- Sources`, then `git stash pop`) into a second folder. Diff the `.MID` files track by track to see which tracks moved, and check that untouched substyles are byte-identical. A count that rises on a track you didn't touch is usually attribution: the clash is counted against the later or out-of-chord note, so a fix elsewhere moves it. Read the actual notes before believing a rise. Totals hide regressions, so also compare every song's glaring total and read each song that rose by 3 or more. A fix to the chord, or to one track, often exposes another rule that was quietly agreeing with the old wrong note (item 11: KOS-BASS-014, KOS-PADS-004, KOS-RTHM-008).
6. **Sort by cause before fixing.** For each glaring clash, ask whether either note is outside the key, and if so whether the logged chord itself has an out-of-key tone. That split found item 11. Then read the notes in two or three of the worst songs, bar by bar, before proposing anything.
7. **Delete the throwaway test** afterwards.

The analysis helpers used in these sessions (`pdump_lib.py` for glaring clashes per track with the scanner's grading, `bars.py` for notes per bar, `changed.py` for the track diff, and the by-cause split) live in session scratchpads and get cleared. They are short; rewrite them from the description above, or ask for them to be moved into `tools/` if rescans become routine.

## Listening sets

- `~/Downloads/Zudio clash scan demos/`: two worst songs per substyle, named "Substyle - Title", each with .MID and .zudio. Generated on build 138 code; a .zudio reloads from its seed with whatever code the app runs.
- `~/Downloads/Zudio beat-4 approach demos/`: five Chill Blues songs for item 2.

## Log

- 2026-11-13: item 1 coded and measured; 1,400-song scan run; this plan written. Zack heard the beat-4 approach demos and ruled it must be fixed (item 2).
- 2026-11-13: F marker added for fixed rules (`fixMarkedRules`, cleared before shipping; * stays). Item 2 coded and measured, not heard.
- 2026-11-13: Zack set the colour-or-grating rule. Persistent-rub measure added to clash_scan.py. CHL-BASS-009 and the 011 upward opener fixed under it (in item 2's notes). Not heard.
- 2026-11-13: Zack heard items 1 and 2: "sounds better". Committed together (ec1a239).
- 2026-11-13: item 3 coded and measured, not heard. clash_scan.py wording: a clash is counted against the rule that wrote the note, not "blamed" on a track (Zack: "we don't blame people, only rules").
- 2026-11-13: items 5, 6 and 7 (KOS-LD2-005), the Motorik clearance and the Machine Answer fix committed together (5f13599). MOT-LD1-012 fixed with option 1, measured, not heard.
- 2026-11-14: Zack heard the Soho Lead 1 demos and chose option 2 (no repeated notes where a hook note moves). Done in item 4, uncommitted.
- 2026-11-14: KOS-RTHM-021 and 005 fixed (item 7), uncommitted, not heard. Fresh scan of 1,000 Kosmic and 1,000 Motorik seeds on current code, before the Rhythm fix: Kosmic Space 33%, base 28%, Drift 24%; Motorik base 14%, Noir, Europe and Arcade 6–7%. Still worth a look: MOT-LD1-005 (38% glaring, propose first), KOS-BASS-016 (44%), KOS-PADS-005 (31%). Kosmic Lead 1 rules are now 3–25% with small counts, so no Kosmic lead clearance.
- 2026-11-14: KOS-PADS-005 analysed and prototyped (item 8), reverted pending Zack's choice. MOT-LD1-005 analysed on 1,000 Motorik seeds, nothing changed: 399 glaring clashes in 80 songs, 30 over 4. The call (1, 2, 3, 5 on the beats) plays its 2 on beat 2 for a dotted 8th; over a minor chord that is a semitone under the b3 the pads and Rhythm hold, often struck at the same moment (253 clashes, 63%; Summt Nudnik bar 73: F#4 against the pads' and Rhythm's G4 over E minor). The answer's 4 on beat 3 over a major chord rubs the 3rd for a beat before it resolves (about 76; Schlep Wunderwaffe bar 12: G4 against the Rhythm's F#4). Over a sus2 chord the figure's b3 rubs the pad's 2nd (about 60). Fixing the call alone would take songs over 4 from 30 to about 10; the call and the answer, to 0. KOS-BASS-016 analysed (item 8). Options for all three put to Zack.
- 2026-11-14: Zack chose the recommended option for all three ("Kosmic is sequencer driven, change the notes rather than making passing tones; keep the shapes"). Done, uncommitted, not heard, no new draws, all marked F. KOS-PADS-005 and KOS-BASS-016: see item 8. MOT-LD1-005 (`lead1StatementAnswer`): over a minor chord (the chord type has a minor 3rd) the call climbs 1, b3, 4, 5 instead of 1, 2, 3, 5; same rhythm, answer unchanged. Measured on the 1,000 Motorik seeds: only Lead 1 changed (62 songs) and Lead 2 (22, where its gap answers clear around Lead 1); no other track. The call's clashes are gone. MOT-LD1-005 glaring songs 30 of 80 to 14; Motorik base problem songs 14% to 11%. What's left is the answer's 4 on beat 3 over a major chord (its 4 to 3 suspension, kept by choice) and the figure's b3 over sus2. One changed song, Blinken Schnork, plays 005 in its B section only, which the log doesn't list (the log shows the A rule). Hear: `~/Downloads/Zudio Call and answer clash demos/` (before is MIDI only): Summt Nudnik 46 to 0 (bar 73: E4 G4 A4 B4 over E minor), Wunderwaffen Zeig 22 to 0, Schlep Wunderwaffe 26 to 12 (bar 37: A4 C5 D5 E5 over A min7; the rest are answers).
- 2026-11-14: committed 9342e16 on Zack's word. A rescan put every style at diminishing returns except one cause: a chord type whose 3rd is outside the key, half of Drift's glaring clashes. Zack asked for the fix (Drift and Space; not Ambient). Item 11: the chord type takes the key's 3rd, KOS-BASS-014's 3rd follows the chord root, and the Space JMJ hook snaps to the chord's scale. Drift 20% to 11%. Uncommitted, not heard. Added "Where it stands and what's left" and "Rescanning later".
- 2026-11-14: Zack asked for the regressions item 11 exposed to be fixed without complicating the code. KOS-PADS-004, KOS-PADS-005 and KOS-RTHM-008: the rule's 3rd follows the chord, and over a major 3rd a held 4th steps aside (to the 2nd, 9th and 6th). The Space hook revised: chord tones as they are, other notes key-snapped then altered, harmony thirds in the chord's scale. Checked every song for a rise; one leftover (Polar Aurora, leads' 4th). Drift 9%, base 24%, Space 19%. Uncommitted, not heard.
- Rescan step to add on any fix: compare every song's glaring total before and after, and read each song that rose by 3 or more (see "Rescanning later", step 5).
- 2026-11-14 (code review, `docs/2026-11-14-clash-code-review-handover.md`): pending work committed as 6992969. Batch B done, uncommitted: one shared `Clearance` and `HeldNotes` (`Generation/Clearance.swift`) under ChillClearance and MotorikClearance, with `Clearance.rubsChord` replacing four copies in Rhythm and Kosmic; `snapToScale` in place of four Kosmic Pads copies; `ChordType.third` and `keyThirdAbove`; `noirDeepRoot(entry, frame)` with the dead companion clamps removed; Chill tidy-ups (one track-list helper for generation and regen, ChillClearance holds structure and scale, Blues pads voice Rhythm once); the KOS-RTHM-008 pool loop. Fingerprints on 1,000 seeds per style and 300 regens: byte-identical. A1 (Motorik hook clearance inside `HookLeadEngine.realise`): no song changes. A2 (Motorik Lead 1 cleared bar by bar, `clearanceSkipBars` gone; Zack chose prevNote reading the bar as written): Lead 1 changes one note in V2Kolsch Level (motorik seed 486, bar 63, G4 to F#4); Fettig V2 (seed 58) swaps the order of two same-pitch events, no audible change. A5 (`finishedChillLead`: each Chill lead finished as it is written, so Lead 2 and Rhythm hear Lead 1 as it sounds; the harmonic filter no longer re-runs on the leads): Lead 2 changes one held note in 14 of 1,000 Chill songs and a repeated figure note in Five to Two (chill seed 998); nothing else moved. Not heard.
- 2026-11-14 (code review, A3 and A4, uncommitted, not heard). A3: Soho Lead 1 is cleared as it is written, not as a finished track. The reused base rules 001 and 004 pass the band into base Chill's `generateLead1` with `sohoReuse` (avoidRepeat, and seed phrases kept as written so each replay is cleared where it lands; base Chill replays its cleared seed, unchanged). Operator, Avalon Hook and Sustained Tone clear each phrase or statement as written; Avalon's held figure endings are decided on the written line (same draws) and held only as long as `ChillClearance.holdsClear` allows; each remix pickup is cleared on its own. Measured on 1,000 Chill seeds: only Soho changes (Lead 1 in 170 of 335 songs, median 2 notes, 131 songs at 2 or fewer; Lead 2 follows in 62); base Chill and Blues byte-identical, generation and regen. Two songs flip a phrase an octave through the harmonic filter's lift: Kicking Out Time (chill seed 892, bars 9 to 13 F4 to F5) and Lights in the Side Street (312, bar 74 down an octave). Clash scan, 1,500 Chill seeds: Soho glaring 566 to 567, no song up by 3; base and Blues unchanged. A4: `fitSpaceChordScale` is gone; every Space rule fits its notes to the chord's scale as it writes each bar or line (`fitSpaceNotes`: bass and pads per bar, Lead 1 per rule line, Lead 2 per bar or line, Rhythm and Texture per line). No song changes in 4,000 seeds or 1,200 regens. `ReplayFidelityTests/firstSohoSeedsStillQualify` already failed before this work (seed 48701 no longer draws CHL-LD1-010).
