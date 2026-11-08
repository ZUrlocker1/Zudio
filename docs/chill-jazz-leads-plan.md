# Chill jazz Lead 1 rules

Status (2026-11-07): work in progress. Three lick-bank rules are built and placed by style;
the weights are still being fine-tuned by ear.

## What this is

Three Lead 1 rules that phrase like jazz horn players instead of picking notes from a scale. Each
plays licks from a small bank taken from a real tune, reworked per song as homage and never
copied. The old Chill Lead 1 rules are unchanged.

- **CHL-LD1-013 Moanin' call and response** (Chill Blues only). Bobby Timmons, from Art Blakey's
  *Moanin'*. A two-bar call with a pickup on beat 2 climbs one of three ways and falls through the
  blue note to a long root; the horns' amen (4 held, then b3) answers it. Over IV it plays a
  bridge-shaped phrase. The song's seed picks the climb order (A B C A, A C B A or B A C A), the
  pickup position and the amen interval. Every call is answered for the first four; later the
  answer varies or drops out, and the last fifth of the song plays plain.
- **CHL-LD1-014 Cantaloupe Island hook** (both substyles). Herbie Hancock, *Empyrean Isles*. A
  three-bar phrase: the four-bar minor-pentatonic hook, then a restatement with a ghost octave and
  a 5-b7 tag, then hook fragments, 8th-note solo licks with the #4 blue note and horn stabs. Over
  IV the hook moves to the IV root or the stabs play. The full hook comes back once in the last
  fifth.
- **CHL-LD1-015 Blue Monk riff** (regular Chill only). Thelonious Monk. A one-bar chromatic climb
  into a held fifth (b3-4-#4-5 in minor blues terms), then a falling answer or a short tail.
  Later the held note sometimes cuts short to leave air; the last fifth plays plain.

## Lead 1 shares, as a share of all songs

Shared between substyles: CHL-LD1-009 and CHL-LD1-014.

- **Chill regular:** CHL-LD1-005 St Germain staccato burst 18 (the staccato roll fires on 70% of
  St Germain-beat songs and 5% of the rest), CHL-LD1-015 Blue Monk riff 17, CHL-LD1-001 Long
  phrase 17, CHL-LD1-014 Cantaloupe Island hook 15, CHL-LD1-007 Wide interval solo 13,
  CHL-LD1-008 Warm jazz line 13, CHL-LD1-009 Jazzy blues lead 7.
- **Chill Blues:** CHL-LD1-002 Miles punch 20, CHL-LD1-004 Blues lead 20, CHL-LD1-013 Moanin' 20,
  CHL-LD1-003 Chet sparse melody 15, CHL-LD1-009 Jazzy blues lead 13, CHL-LD1-014 Cantaloupe
  Island hook 12.
- Miles punch, Chet sparse and Blues lead play in Chill Blues only. Chill Soho has its own pool
  but still reuses Blues lead and Long phrase through a forced rule ID.
- The pool draw is at the top of `generateLead1` in `ChillLeadGenerator.swift`: a first draw picks
  a jazz rule (Chill 39%, Blues 32%) and the other rules draw on their own. The original weights
  from before the jazz rules are in the code comment above it.

## How it is built

- **Code:** the "Jazz cell rules" section at the end of
  `Sources/Zudio/Generation/Chill/ChillLeadGenerator.swift`. `jazzCellPhrase` replaces
  `buildPhrase` for these rules. Everything else in the Lead 1 loop runs as before: intro silence,
  lay-outs, handoffs, Blues chord seams, seed returns and the turnaround lick. The blue-note
  overlay is skipped because the licks carry their own. Seed returns still apply, so a song's
  first two phrases replay and Cantaloupe's hook can state four times early on.
- **Licks:** written in minor blues terms as semitones from the chord root, on a 16th-step grid,
  tagged by the chord under the phrase's first bar. A lick moves to that root in the octave
  nearest a per-song anchor where the whole lick fits the instrument's register, then is fitted
  note by note. Notes outside the song's scale and the chord move to the nearest allowed note
  (a chord tone first, then the lower); short semitone passing tones keep the blue note. This is
  how one bank serves Dorian Blues and the major modes of regular Chill.
- **Phrase lengths:** Cantaloupe 3 bars, the others 2, clamped by section ends and Blues seams.
- **Log names:** "Moanin' call and response", "Cantaloupe Island hook", "Blue Monk riff".
- **No swing:** the engine plays straight 16ths. Moanin's swung 8ths land on step 3 of the beat
  when quantized, which reads as a dotted, shuffle-like lilt.

## Sources

- **Moanin' [2]**, **Cantaloupe Island [1]** and **Blue Monk [1]**, full-band fan arrangements
  from bitmidi.com (the same site as the Soho and Jarre corpora). Moanin' lines come from the
  vibes and trumpet tracks, Cantaloupe from the trumpet track, Blue Monk from the sax on channel
  15.
- Sources are scale-mapped to the target mode, so a major-key tune like Blue Monk only becomes
  slightly less recognisable.
- Not used: Night in Tunisia (182 BPM) and Milestones (244 BPM) are too fast, All Blues is in 3/4.
- **Weimar Jazz Database** (Jazzomat, HfM Weimar), 456 solos under the Open Database License
  (credit Pfleiderer et al., *Inside the Jazzomat*, 2017), is downloaded but unused.
- Fetch script: `tools/fetch_jazz_midi.py <out-dir>`. Dump script: `tools/jazz_cells_dump.py`
  (bar-by-bar, 16th steps, bass note per bar). The MIDI files are in
  `tools/batch-output/jazz-midi/` (gitignored). Never commit or ship them.

## Open items

- Fine-tune the weights and the licks by ear. A Chill Blues-only fourth lick rule from the Weimar
  solos (Vierd Blues, K.C. Blues, So What) is the next option if Blues needs more distinction.
- The Blues second-horn harmony pass is limited to CHL-LD1-004 and CHL-LD1-003. The jazz rules
  never get it. Decide by ear whether Moanin' or Cantaloupe should.
