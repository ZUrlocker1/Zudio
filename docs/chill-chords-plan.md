# Chill and Chill Blues chord progressions (3.0)

## What this is

Zack's wife said Chill "doesn't sound like music because it's not going anywhere" (2026-11-11).
Measured from the code: about half of base Chill songs barely change chord. Deep Long Lake is
Ebm7 for 72 bars apart from a 4-bar sus4 breakdown. This plan adds harmonic motion to base Chill
and Chill Blues for version 3.0. Chill Soho already has varied cycles, B-section cycles and
turnarounds (`buildSohoChordPlan` in `SongGenerator.swift`) and is out of scope.

## What exists (before 3.0)

- **Base Chill** draws a family in `ChillMusicalFrameGenerator.pickProgressionFamily`; the plans
  are built in `ChillStructureGenerator.buildChordPlan`:
  - Static groove 35%: the tonic chord all song, sus4 breakdown.
  - Two-chord pendulum 30%: tonic and a partner swapping every 4, 6 or 8 bars (Dorian i–bVII,
    i–IV, i–v; Aeolian i–bVII, i–iv, i–bVI; Mixolydian I–bVII, I–IV, I–v; Ionian I–IV, I–vi,
    I–bVII).
  - Minor blues 20%: a 12-bar tile, i (4) iv (2) i (2) bVII (1) IV (1) i (2).
  - Modal drift 15%: one or two changes in the whole song.
- **Chill Blues** (`buildBluesChordPlan` in `SongGenerator.swift`), always Dorian: a 16-bar cycle
  repeated unchanged, im7 (8) ivm7 (2) im7 (2) V7 (1) ivm7 (1) im7 (2). Breakdown sus4, intro and
  outro im7.

## Decisions (Zack, 2026-11-11)

- This work, with the jazz leads already committed, is **version 3.0** (Version.xcconfig is 3.0,
  build 137; 2.9 shipped from commit 12781c0). Several days of listening are fine.
- **Build items 1, 3 and 4 first.** Item 2 (tune-named progressions) comes after, and only if
  they sound hip.
- **Hip, not old-fashioned:** cool jazz, modal, hard bop, soul jazz and bossa from the 1950s and
  60s or later. Nothing that sounds like 1930s or 40s swing (no rhythm changes, no I–vi–ii–V
  turnarounds, no diminished passing chords).
- Chill Blues needs variation from chorus to chorus, including a quick change.

## Constraint: chords stay in the mode

Pads and Rhythm snap every chord note to the song's scale (`ChillPadsGenerator.makeSnapTable`).
A chord with a note outside the mode turns into a different chord (in Dorian, a V7's major third
snaps to the b7, so the existing Blues "V7" already sounds as vm7). Items 1, 3 and 4 therefore
use only chords that belong to the mode. Item 2's hippest progressions (Maiden Voyage, Song for
My Father's dominant sevenths, Blue Bossa's key change) need chord-aware snapping first: snap to
the window's chord tones and the scale together.

## Item 1: no whole-song vamps (base Chill)

- **B section moves.** Static groove keeps the tonic vamp in A; B becomes a pendulum of the
  tonic and a partner from `pickChordPair`, 4 bars each. Two-chord pendulum takes a different
  partner in B than in A. Modal drift and minor blues keep their plans.
- **Turnarounds.** The last 2 bars of each 16-bar phrase of a groove section (60% of songs), or
  only of each section (40%), as in Soho, become a 2-chord cadence back to the tonic, one bar
  each. The mode's chords only; each song picks one of two:
  - Dorian: IV7 – vm7, or bIIImaj7 – IV7.
  - Aeolian: bVImaj7 – bVII7, or ivm7 – vm7.
  - Mixolydian: bVIImaj7 – IVmaj7, or iim7 – vm7.
  - Ionian: iim7 – V7, or IVmaj7 – V7sus4.
  Not in the minor blues family, which already cadences.
- **Check first:** the bass ostinato (`useOstinato` in `ChillBassGenerator`, static groove only)
  must follow the new B chords; the log's "Chords" line should name the B motion and turnarounds.

## Item 3: breakdowns lead back in (base Chill and Blues)

- The last bar of a 4-bar breakdown, the last two of a longer one, become V7sus4 (root on 5,
  sus4 type: the key's 1, 2 and 4 over the fifth, all in the mode). The groove's return resolves
  it to the tonic.
- In a stop-time breakdown the Rhythm climb and Lead 1's join then ride the V7sus4 voicing
  (`ChillRhythmGenerator.stopTimeReveal` reads the chord window).
- **Check first:** what each breakdown style's bass plays (Bass cases for `.stopTime`,
  `.bassOstinato`, `.harmonicDrone`, `.groovePocket`); a tonic pedal under V7sus4 is acceptable,
  but it should be a decision. Rhythm's groove-pocket tension bars (6 to 8) already exist.

## Item 4: Chill Blues varies chorus to chorus

The form's seams stay where they are (positions 8, 12 and 15; leads, bass and drums depend on
them). Only the chords inside change. The first chorus is plain. Each song takes two of the four
devices as its vocabulary, and each later chorus plays each of them at 60%:
- **Quick change:** bar 2 (position 1) goes to ivm7 and back to im7 in bar 3. In a 12-bar blues,
  the quick change is the IV chord in bar 2 instead of four bars of I.
- **Dorian IV7:** the ivm7 bars (positions 8, 9 and 13) play IV7, the brighter Dorian
  subdominant of soul-jazz organ blues.
- **Modal turn:** positions 12 and 13 play bVIImaj7 – IV7 in place of V7 – ivm7.
- **Suspended turnaround:** positions 14 and 15 play iim7 – V7sus4 back to im7.
- **Check first:** the Blues bass's `isIV` test (`chord?.chordRoot == "4" && chordType == .min7`,
  `ChillBassGenerator.swift` near line 1583) must still fire on IV7; Lead 1 replays seeds only
  over form positions below 8, so a quick change puts bar 2 of a replayed seed over ivm7
  (acceptable; players do the same).
- Log the devices on the Chords line.

## Item 2: tune-named progressions (later)

Candidates, each from 1959 or later, each paired with a lead rule where one exists:
- **So What shift** (1959): the vamp moves up a semitone for 8 bars and back.
- **Song for My Father** (1964, pairs with CHL-LD1-007): a descending i – bVII – bVI – v.
- **Blue Bossa** (1963, pairs with CHL-LD1-008): minor ii–V and a lift to the relative major.
- **Cantaloupe Island** (1964, pairs with CHL-LD1-014): three 4-bar chords.
- **Maiden Voyage** (1965): suspended chords moving by step.
- **Little Sunflower** (1967): a Dorian vamp that lifts to major.
- **Chameleon** (1973): a two-chord i – IV7 Dorian vamp.

Dropped: the Autumn Leaves circle of fifths (a 1945 tune; it reads as standards-era).

**How many:** about 10 base Chill progressions in all (the four fixed families plus about six
named ones), so one recurs in about one song in ten; Soho has seven. Chill Blues: the plain form
plus the four devices, which combine into many chorus variants.

## Open items

- Items 1, 3 and 4 not started. Testing light: build, then ChillBatchTests/ChillBluesBatchTests
  as affected (ask before long batches), plus ChillLeadRegisterTests.
- Mark nothing with "* " here (chord plans are not rules), but log the new motion.
