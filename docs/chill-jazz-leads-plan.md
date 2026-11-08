# Chill Blues jazz Lead 1 rules: plan

Status (2026-11-07): three rules built, heard by Zack and placed by style: CHL-LD1-013 Moanin'
(Chill Blues only), CHL-LD1-014 Cantaloupe Island (both) and CHL-LD1-015 Blue Monk (regular
Chill only). Miles punch and Chet sparse moved to Chill Blues only. Both apps compiled (iOS
before the last two weight changes); no tests run, by Zack's instruction. The next step is more
listening; if Blues doesn't feel different enough, the options are listed under "If Blues needs
more distinction".

## Weights to restore

- Before the test, Blues: 009 35, 004 35, 002 20, 003 10.
- Before the test, Chill: 001 20, 002 20, 003 15, 004 13, 007 12, 008 12, 009 8 (CHL-LD1-005 St
  Germain staccato is a separate roll ahead of the pool and is unchanged).
- Also before: the St Germain staccato roll (CHL-LD1-005) ran at 85% on the St Germain beat and
  15% on the other four beats, about 29% of Chill songs.
- How it is wired: in `generateLead1`, a first draw picks a jazz rule (Chill 34%, Blues 30%); the
  old rules run on their own draw otherwise. Deleting the two `j <` branches, restoring the old
  ladders and the 85/15 staccato roll restores the original weights exactly.

## Current weights (2026-11-07, after listening)

Zack's verdicts: Blue Monk good in Chill, Cantaloupe good in Chill and Blues, Moanin' good in
Blues. Moanin' is out of Chill and Blue Monk out of Blues. Shares of all songs:
- Chill: 005 18 (roll now 70% on the St Germain beat, 5% on the others), 014 15, 015 15, 001 14,
  007 11, 008 11, 004 9, 009 7. CHL-LD1-002 Miles punch and CHL-LD1-003 Chet sparse are Chill
  Blues only (Zack, 2026-11-07); their old Chill shares (8 and 7) went to the rules below 15.
- Chill Blues: 013 18, 014 12, 009 18, 004 18, 002 20, 003 14.

## As built

- Code: the "Jazz cell rules" section at the end of `ChillLeadGenerator.swift`. `jazzCellPhrase`
  replaces `buildPhrase` for these rules; everything else in the Lead 1 loop (intro silence,
  lay-outs, handoffs, seams, seed replays, turnaround lick) runs as before. The blue-note overlay
  is skipped because the licks carry their own.
- Licks are written in minor blues terms relative to the chord root under the phrase's first
  bar, moved to that root in the octave nearest a per-song anchor where the whole lick fits, then
  fitted note by note: notes outside the scale and chord move to the nearest allowed note (a
  chord tone first, then the lower), except short semitone passing tones, which keep the blue note.
- Phrase lengths: Cantaloupe 3 bars, the others 2, clamped by sections and Blues seams as usual.
- Per-song draws: Moanin' ladder order (A B C A, A C B A, B A C A), pickup on beat 2 or beat 1,
  amen 4-b3 or b7-5. Blue Monk riff on the downbeat or an 8th late. Cantaloupe solo licks on the
  beat or a beat late.
- Evolution: Moanin' answers every call for the first four, then varies or drops the answer.
  Cantaloupe plays hook then restatement, then fragments, solo licks and stabs, and the full hook
  once in the last fifth. Blue Monk alternates its answer and tail, sometimes cuts the held note
  short, and plays plain in the last fifth.
- Blue Monk is from Blue Monk [1] (fan), sax on channel 15.

## What this is

Two new Lead 1 rules for Chill Blues that phrase like great jazz and blues horn players (Miles
Davis, Kenny Dorham, Lee Morgan, Cannonball Adderley and others) instead of picking notes from
a scale. Each rule is built from a small bank of short licks taken from real solos, reworked as
homage and never copied.

## Why

The current Chill Lead 1 rules (CHL-LD1-002, CHL-LD1-003, CHL-LD1-004, CHL-LD1-009 in Blues) are
generative: `buildPhrase` in `Sources/Zudio/Generation/Chill/ChillLeadGenerator.swift` picks notes
from pentatonic or Dorian scales, adding jazz bursts, blues runs, chromatic approach notes, a
blue-note lick, seed-phrase returns and a turnaround lick. Zack finds them OK, but they have no
real vocabulary: no recurring licks, no enclosures, no riff stated and answered, no Miles-style
space.

## Decisions

- **New rules, not changes to existing ones** (Zack, 2026-11-07). Keeps old Blues seeds stable,
  allows A/B by forcing the rule, and the log names the new rule.
- **Keep it small** (Zack): one or two rules, from a handful of songs. No large corpus study.
- **Chill Blues first.** Its pool has only four rules, and Blues already tracks the chord under
  each phrase (`structure.chordWindow(atBar:)`), which lick-based rules need. If a rule works it
  can later go into base Chill at a low weight.
- **Lick bank, not statistics.** 8–12 one-to-two-bar cells per rule, stored as a 16th-step rhythm
  plus intervals from the chord root. The phrase assembler picks a cell, fits it to the current
  chord window, varies it (rhythmic displacement, truncation, last-note flip), and leaves space.
  The existing machinery (seed-phrase returns, blue-note lick, turnaround lick) stays.
- **Naming:** each rule is named for its source album or work, per the project's corpus-rule
  convention, with full canonical IDs (the next free Lead 1 IDs; check the code, CHL-LD1-012 is
  the highest seen).

## Zack's picks (2026-11-07)

He flagged six fan files: Moanin' [2], Cantaloupe Island [1], Night in Tunisia, All Blues [2],
Milestones, Blue Monk. He asked for Moanin' and Cantaloupe first.

- **Moanin' and Cantaloupe Island fit.** Both are in F minor, which matches Chill Blues' Dorian
  minor blues, both move at about 120 BPM, and both have a hook short enough for a single line.
- **Major keys are fine.** Zudio scale-maps sources to the target mode, so a major-key tune only
  becomes a little less recognisable (Zack, 2026-11-07).
- **Blue Monk became the third source.** Its head is a one-bar riff: a chromatic climb in
  8ths into a held chord tone (D-Eb-E-F on Bb7), then the same shape moved to IV (G-Ab-A-Bb),
  answered by a falling F-G-F-E-Eb line. Mapped to Dorian, the climb becomes 4-#4-5, with the
  blue note in the middle.
- **Rejected for now:** Night in Tunisia (182 BPM) and Milestones (244 BPM) are too fast and
  aren't blues-shaped. All Blues is in 3/4.
- The engine has no swing (straight 16th grid). Moanin's swung 8ths sit on step 3 of the beat
  when quantized, which reads as a dotted, shuffle-like lilt.
- Dump tool: `tools/jazz_cells_dump.py` (bar-by-bar, 16th steps, bass note per bar).

## Rule design (original proposal; the as-built notes above and the current weights win)

Intervals are from the chord root, steps are 16ths from the bar start. The next free IDs are
CHL-LD1-013 and CHL-LD1-014.

**CHL-LD1-013 Moanin'** (Bobby Timmons, from Art Blakey's *Moanin'*, 1958). A two-bar call and
response.
- Call cells (vibes/piano, bars 2–17): a pickup on beat 2 (steps 4, 7), a climb, then a long root.
  Call A climbs to b3 and drops to 5 and b7 below. Call B climbs to 4 and falls #4-4-b3-1, the
  blue note. Call C climbs to 5-b7 and takes the same fall.
- Amen tag (horns, every second bar): 4 held six steps on beat 3, then b3. This is the top voice
  of the IV-to-I answer.
- Bridge cell (bars 19–25): 5 held, #4-4-1-4, then b3 held and 1-b7-5-b7-1. Used over IV.
- Form: on I, bars 0–7 hold up to four call/amen pairs, with the call climbing A, B, C, A as in
  the head. IV (8–11) takes the bridge cell on the IV root. I (12–13) takes one call A home, and
  14 keeps the existing turnaround lick.
- Variation: the seed picks the ladder order, the pickup position, the amen interval and the
  octave. The first chorus is plain; later choruses ornament, trim or drop the amen for space;
  the last chorus is plain again.

**CHL-LD1-014 Cantaloupe Island** (Herbie Hancock, *Empyrean Isles*, 1964). A four-bar hook plus
solo cells.
- Hook (bars 8–11): 1 1 . 1 b3 4, then 4 held, b3 4 5, then b7 below and a long 1. Pure minor
  pentatonic.
- Restatement (bars 12–16): the hook with a ghost octave on its second note and a 5-b7 tag.
- Stab riff (bars 30–36): hits on steps 6, 9, 12 and 14, top voice 1 1 1 b3. Then single hits on
  step 10.
- Solo cells (Freddie Hubbard, bars 63–66): 8th-note pentatonic lines with the #4 blue note,
  such as 4 b3 4, b3 1 b3 4 #4 4 b3 1, and 5 5 #4 #4 4 b3.
- Form: in the first chorus, the hook takes I bars 0–3 and the restatement 4–7. IV (8–11) takes
  the hook's first two bars on the IV root (Cantaloupe moves its own hook to Db7) or the stab
  riff. I (12–13) resolves b7 to 1. Middle choruses swap the restatement for solo cells and
  keep two-bar hook fragments. The final chorus states the full hook again.

**Shared (both rules)**
- Both rules get their own form-aware builder in place of `buildPhrase`. They keep intro/outro
  silence, handoffs, lay-outs, seams and the turnaround lick. They skip the blue-passing-tone
  overlay because the cells carry the blue note. The seed-return logic still runs over them, so a
  song's first two phrases are replayed (Cantaloupe's hook can state four times early on).
- Weights: superseded; see "Current weights" above. Cantaloupe went into base Chill after
  listening, as the original proposal suggested.

## Constraints from the existing code

- Chill Blues tempo is 85–92 BPM (`ChillMusicalFrameGenerator.swift`). Sources at 110–120 BPM
  fit when slowed; 160+ BPM bebop lines are too dense.
- The Blues form is 16 bars: I for bars 0–7, IV for 8–11, I for 12–13, V/I for 14–15. It is not a
  12-bar blues, so licks are tagged by chord (I, IV, V), not by bar of a 12-bar chorus.
- Blues Lead 1 instruments are trumpet, muted trumpet, alto sax, tenor sax and clarinet. Lead 2 is
  vibes, soprano sax or trombone.
- Current Blues pool weights: CHL-LD1-009 35%, CHL-LD1-004 35%, CHL-LD1-002 20%, CHL-LD1-003 10%.
  New rules take share from 009 and 004.

## Sources

- **Weimar Jazz Database** (Jazzomat, HfM Weimar): 456 hand-transcribed solos, solo line only,
  unquantized MIDI on a piano patch. Open Database License (ODbL); credit Pfleiderer et al.,
  *Inside the Jazzomat* (2017). https://jazzomat.hfm-weimar.de/download/download.html
- **bitmidi.com** fan arrangements (full band, quality varies), the same site as the Soho and
  Jarre corpora.
- Fetch script: `tools/fetch_jazz_midi.py <out-dir>`. Files are in
  `tools/batch-output/jazz-midi/` (gitignored): `weimar/` has 27 picked solos plus the full zip,
  `fan/` has 22 files. Never commit or ship them.
- Not found anywhere: Freddie Freeloader. Blue in Green fan files have no horn part.

## Listening shortlist given to Zack

- Weimar: Miles Davis Vierd Blues, K.C. Blues, So What; Kenny Dorham Doodlin'; Dizzy Gillespie
  Cognac Blues; J.J. Johnson Blue Mode (trombone, could later feed Lead 2); Chet Baker I Fall in
  Love Too Easily; Charlie Parker K.C. Blues.
- Fan: Parker's Mood, Moanin', All Blues file [2], My Funny Valentine, Cantaloupe Island, Song for
  My Father.

## Next steps

1. Listen to a handful of Chill and Chill Blues songs each and judge the fit.
2. Harmony: the Blues second-horn pass is still limited to CHL-LD1-004 and CHL-LD1-003; the new
   rules never get it. Decide by ear whether Moanin' or Cantaloupe should.
3. Commit when Zack asks. Never commit the MIDI files.

## If Blues needs more distinction

About half of Blues songs (49%) use Blues-only rules (002, 003, 013); 51% use rules shared with
regular Chill (004, 009, 014). Options: take 009 out of regular Chill, raise Moanin' and trim 004
in Blues, or add a Blues-only third lick rule from the Weimar solos already downloaded (Vierd
Blues, K.C. Blues, So What). Listen first.
