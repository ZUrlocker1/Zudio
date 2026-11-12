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

## As built (2026-11-11, items 1, 3 and 4)

Built, compiled and traced over 60 seeds; not yet judged by ear.

**Random streams.** Every new draw is on a derived stream: 99 for base Chill motion (passed
into `ChillStructureGenerator.generateWithChordMotion` as `motionSeed`), 96 for the Blues
chorus devices. The main stream consumes exactly what it did before, so Chill Soho is
unchanged and base Chill and Blues songs change only in their chords (and the bass, pads,
rhythm and leads that follow them).

**Item 1, base Chill** (`applyChordMotion` in `ChillStructureGenerator.swift`). The family
plan is built as before, flattened to one chord per bar, reshaped, then rebuilt into windows
that never cross a section boundary and chunked at 8 bars.
- Static groove: A is the tonic vamp; B is tonic and a partner from `pickChordPair`, four bars
  each, restarting on the tonic at every 16-bar phrase.
- Simple form (no B section, 30% of Deep and Dream songs) was the worst case, up to 104 bars
  of one chord. A static groove there now runs the same pendulum over the body's second half,
  from the phrase nearest its middle. This goes beyond the plan as written; Zack to confirm.
- Two-chord pendulum: A keeps its partner and window length; B takes a different partner
  (the mode's other two options, renormalised). Both restart on the tonic every phrase, and
  intro and outro now hold the tonic (they used to carry the alternation on).
- Turnarounds as planned, one bar each, 60% every phrase and 40% section ends only, placed
  only where the bar after is on the tonic root (modal drift often is not). Not in minor blues.
- Phrases are 16 bars, and a remainder under 8 joins the phrase before, as in Soho.

**Item 3, breakdowns.** The last bar of a 4-bar breakdown, or the last two of a 6- or 8-bar
one, become a sus4 on the fifth above the chord the groove returns to. Pads (4, 5, b7, 9)
and Rhythm (4, 5, b7) already voice `.sus4` as a 7sus4, so no new chord type was needed.
Returning to the tonic, the chord is V7sus4. Modal drift often returns to another chord (the
chord after the breakdown is its second or third chord). There it takes that chord's own
dominant sus when all of root, 4, 5 and b7 are in the mode (II7sus4 into Vm7 in Dorian, for
example), and otherwise keeps the tonic sus4.
- Chill Blues has **no breakdown**: `buildNoBreakdownSections` never makes one, and the
  `.bridge` case in `buildBluesChordPlan` is dead code. Item 3 is base Chill only; in Blues the
  suspended turnaround device supplies the V7sus4.

**Breakdown bass, checked and adjusted** (`ChillBassGenerator.swift`; base rules, St Germain
CHL-BASS-007 and hip-hop CHL-BASS-008). The bass follows the chord root, so it plays the
fifth under V7sus4; no tonic pedal.
- Stop time: root hits on even bars, unchanged. In a 6-bar break the hit in bar 5 is the fifth.
- Bass ostinato: the last-bar quarter-note walk was chromatic toward the next root, which
  from the fifth passed notes outside the mode and landed a third away. It now walks the scale
  and arrives by half step (G, F, Eb, D into C; G, A, Bb, B into C). Same-root walks unchanged.
- Approach notes in the drone and ostinato rules now aim at the next bar's root (the tonic's
  leading tone) rather than the current root. Identical wherever the two roots match.
- Groove pocket: the closing climb takes the 4th over a sus4 (root, 4, 5, octave), not a third.

**Item 4, Chill Blues** (`bluesChorus` and `buildBluesChordPlan` in `SongGenerator.swift`). As
planned: the song's first chorus plain, two of the four devices per song, each at 60% per later
chorus. Each section keeps its own form clock from its first bar. With quick change and Dorian
IV7 together, the quick-change bar plays IV7 too. The Blues bass (`isIV`, `isV`) and the
"Blues" bar annotations now key on the chord root, so IV7 counts as a IV chord and not a V7.

**Log.** The Chords line appends the motion: base Chill gets "B Im7 – bVII" (or "second half
..." in simple form) and "turn: IV7 – Vm7" when one was placed (shortened from "- turnaround"
because the line ran long; Zack, 2026-11-11); Chill Blues gets the
devices it actually played. The Blues Chords line used to print whichever base family the
frame happened to draw; it now says "blues". Examples:
- "Eb Aeolian groove - B Im7 – bVII turn: IVm7 – Vm7" (Deep Long Lake)
- "F Dorian blues - modal turn, suspended turnaround"

**Turnaround rows** (Zack, 2026-11-11). The performance log fires "Turnaround" on the first bar
of each base Chill turnaround with its chords in the key, for example "Abm7 – Bbm7" at bars 19,
27, 47 and 67 of Deep Long Lake. `generateWithChordMotion` returns the turnaround bars, and
`buildStepAnnotations` takes them as `chillTurnaroundBars`. The Chill Blues Turnaround row (cycle
bar 12) had no description; it now lists the chords of cycle bars 12 to 15, a repeat named once,
so the modal turn ("Ebmaj7 – Bb7 – Fm7") and suspended turnaround ("C7 – Bbm7 – Gm7 – Csus4")
show in the log. Soho's row (the bass treatment name) is unchanged. The log's chord namer now
spells with flats when the mode's parent key is flat (G Aeolian gives Ebmaj7, not D#maj7); this
also touches Ambient's chord-shift rows. Ab keys still print B and E for Cb and Fb.

**Verified:** `swift build` clean; ChillSohoTests, ChillLeadRegisterTests and
ChordPlanShapeTests pass (100 tests). **Not verified:** anything by ear; ChillBatchTests and
ChillBluesBatchTests not run.

## As built (2026-11-12, rulings and round 1)

**Rulings (Zack, 2026-11-12).** Keep the simple-form second-half pendulum. Keep the modal drift
dominant sus (the breakdown ends on the 7sus4 a fifth above the chord the groove returns to,
when it is in the mode). In practice that differs from the tonic sus4 only when the return is
to Vm7 in Dorian: returning to IV, the fifth above is the tonic; returning to bVI in Aeolian,
the 7sus4 leaves the mode and the tonic sus4 stays.

**Simple form cadences every phrase.** The every-phrase draw is still made (stream use
unchanged), but simple form ignores it: section ends only left seed 15 on Abm7 for bars 1 to 56.

**Modal drift swings** (`applyChordMotion`, `.modal_drift`). The drift plan could hold its
second or third chord through B and the outro, 40 bars or more, and end the song there (seed
26: Cm7 bars 41 to 84 in F Dorian). Now any groove phrase that is entirely one non-tonic chord,
where that chord was already sounding in the bar before, becomes a pendulum of the tonic and
that chord, four bars each, from the tonic. The first phrase of B (after the breakdown's sus)
and a drift chord's first appearance in A are untouched, so the drift is still heard and the
dominant sus still resolves to the chord it names. The outro holds the tonic. Turnarounds then
fire wherever the next phrase starts on the tonic. The Chords line adds "then Im7 – Vm7".

**Turnaround rows name chords as they sound** (`turnaroundChords` in `buildStepAnnotations`,
Chill only). `nearestScalePitchClass` breaks a tie toward the lower absolute pitch class, so a
third outside the mode lands differently by key:
- Blues V7 in Dorian (major third is the key's 7): Vm7 in most keys, V7sus4 in C and C#.
- Blues IVm7 in Dorian (minor third is the key's b6): root, 9, 5, b7 (IV7sus2) in most keys,
  IV7 in Eb and E. In those two keys the Dorian IV7 device is inaudible.
The rows now name the snapped quality, and sus4 reads 7sus4. The plan's chord types are
unchanged; making the Blues plan diatonic so every key sounds alike is an open question.

**MIDI check (2026-11-12).** ChillBluesBatchTests (30 songs) exported and parsed: in each device
bar, the Bass, Rhythm and Pads notes were scored against the device chord and the plain chord
it replaced. Quick change 44 of 44 bars closer to the device, suspended turnaround 70 of 72,
Dorian IV7 61 of 70, modal turn 51 of 64. The misses are bars whose voicing lacks the one note
that differs: Chill Blues Pads play root and fifth only, so the chord's colour is in the Rhythm
part, and bVIImaj7 shares three notes with the Vm7 it replaces (the bass root is the main
change). That is why the Dorian IV7 and the modal turn are subtle by ear. Every bass rule
re-roots on the new chords; CHL-BASS-010 and CHL-BASS-011 start their figures off the root by
design, CHL-BASS-010 walking down b7, 5, b3, root on alternate choruses.

**Demo files** in `~/Downloads/Zudio 3.0 chord demos/`; they regenerate from the seed, so they
need a 3.0 build with this round in it.

## As built (2026-11-12, round 2: Chill Blues voicings)

Zack heard Still Water Scotts Valley (seed 25) and Summer Dorval (seed 99) and liked the
"subtle jazzy chords". In Chill Blues he could not hear the changes beyond the quick change, and
asked for jazzier chords in Rhythm or Pads, built when the voicing is generated, not in a later
pass. Both cannot be two- or three-note chords.

**Diatonic plan.** The plain form is now Im7 ×8, IV7sus4 ×2, Im7 ×2, Vm7, IV7sus4, Im7 ×2
(`bluesChorus`). This settles the open question from round 1 (the plain IV and V sounded
different by key). Option A as offered would have kept the IV as root, 9, 5, b7; the sus4 is
used instead because its 4th resolving to the major third makes the Dorian IV7 device audible.
Bass `isIV` keys on root 4, `isV` on root 5 when not a sus; the "Blues" bar row says "V chord".

**Rhythm** (`bluesVoicing` in `ChillRhythmGenerator.swift`, reached through `buildVoicing(blues:)`
in every `generateComping` call). Four notes, rootless, stacked up from the third (fourth for a
sus) in MIDI 50 to 61, every note in the mode:
- m7: b3 5 b7 9 (IIm7 takes the 11, its 9 leaving Dorian)
- 7: 3 b7 9 13 (IV13, the soul-jazz organ sound)
- 7sus4: 4 5 b7 9
- maj7: 3 5 7 9
Returned guide tones first (3rd or 4th, 7th, tension, 5th), since the comping modes use
`prefix(2)` as a two-note shell and `[0]` with `[last]` in sparse bars. Base Chill and Soho keep
the old three-note voicing.

**Pads** (`openFifthHold(bluesShell:)`, Blues only): root, 7th above, 3rd (4th for a sus) an
octave above that, three notes in place of root and fifth. Same draws.

**Rest bars.** Rhythm rested in section positions 7 and 15 at 35%, extending into the next bar
at 20%. Position 15 is the suspended turnaround's V7sus4 and position 8 the IV arrival, and the
A section has no Blues pads, so a rest there left the change to the bass. Blues now rests only
in position 7 and never extends. Base Chill and Soho unchanged.

**Quick change per song.** 30% of Blues songs play it in every chorus, the first too; the rest
never do (Zack: all or none, 20 to 40% of songs). The others draw two of the remaining three
devices at 60% per later chorus. Chords line: "sus turnaround" for "suspended turnaround".

**MIDI check** (ChillBluesBatchTests, 30 songs; seeds 1 to 600 for shares). Every chord type
sounds as named in Rhythm and Pads with no snapped notes. Rhythm attacks: 4 notes about 36%, 2
(the guide-tone shell) about 51%. Pads: 3 notes. Device bars closer to the device chord than
to the plain one: Dorian IV7 111 of 113, quick change 31 of 31, suspended turnaround 107 of 114,
modal turn 59 of 78 (bVIImaj9 and Vm9 share three notes; the measure undercounts it). Quick
change songs 26 of 105 Blues songs in seeds 1 to 600, none broken mid-song.

**Verified:** build clean; ChillSohoTests, ChillLeadRegisterTests, ChordPlanShapeTests and
ChillBluesBatchTests pass. **Not verified:** by ear.

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

- Items 1, 3 and 4 committed (be74994) plus round 1 (2026-11-12); Zack to listen.
- Simple-form pendulum and modal drift dominant sus confirmed (2026-11-12).
- Chill Blues plan made diatonic with jazz voicings (round 2); Zack to listen.
- ChillBluesBatchTests run 2026-11-12 (MIDI check above); ChillBatchTests not run.
- Item 2 later, after chord-aware snapping.
- Mark nothing with "* " here (chord plans are not rules), but log the new motion.
