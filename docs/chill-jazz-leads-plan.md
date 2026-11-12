# Chill jazz Lead 1 rules

Status (2026-11-11): work in progress. Six lick-bank rules are built: 013 to 015 (2026-11-07)
and the homage rules 001, 007 and 008 that replaced the random walks (below). 001, 007, 008 and
015 now play three themes each (below). Weights and licks are still being fine-tuned by ear. Next: Lead 2 call and response (see the end of this file).

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

## Homage rules replacing the random walks (2026-11-11)

CHL-LD1-001 Long phrase, 007 Wide interval solo and 008 Warm jazz line ran the same code: a
random walk up and down the scale with no rule-specific behaviour, about 43% of base Chill songs
(and Soho's reused 001). They are retired and cannot play anywhere. The numbers, shares and
pools are unchanged and now play lick banks built like 013 to 015, four-bar phrases, from fan
arrangements not used before. Marked with "* " in the log while being tuned by ear.

- **CHL-LD1-001 Chet sigh** (after My Funny Valentine, Chet Baker's signature tune; Chill and,
  through the forced reuse, Chill Soho). Deliberately not the tune, which is too well known to
  quote (Zack, 2026-11-11): it keeps the gesture, a short pickup into a held 2 that leans on the
  root, with its own pitches and rhythm. The sigh approached from the b7 below (b7-1-b3 into a
  held 2) and a climb to the 5 falling home; the sigh twice, turning back onto the 2; the sigh
  moved up (2-b3-5 into 4, up to the b7, settling on the 5); the arrangement trumpet's scale run
  up to a high held note, falling from the 9th; over other chords a bridge in the tune's manner.
  Every statement is varied, the first and last included.
- **CHL-LD1-007 Horace hook** (after Song for My Father, Horace Silver; Chill). The hook from a pickup on the 5
  below, with the turn on the b6 and the fall to the b7 below with a b2 grace; the B-section call
  of a repeated 5 into a held b6, answered a step higher; over other chords the horns' sighs, 4
  to 3 into a held b6, then the leading tone home. Follows the tune's A A B A.
- **CHL-LD1-008 Blues bossa** (after Blue Bossa, Kenny Dorham; Chill). The 5-4-b3-2 fall on the off-beats into
  a held root and a 5-4 tag; the same fall a step lower; the fall inverted (rising to the 5);
  over other chords the modulation's long fall through an octave.
- **Homage transformations** (Horace hook and Blues bossa from the third statement, not in the last fifth; Chet sigh always): drop a short inner
  note, nudge one inner note a 16th, add a chromatic grace into the first note, and on Chet sigh,
  Chet's turn on a held note. The seed also shifts every phrase an 8th early (001, 007) or late
  (008). Seed returns and last-note flips apply as for every Chill lead.
- **Octave:** each phrase takes the octave that folds the fewest notes out of the instrument's
  register, then the one nearest the previous phrase, so a figure is never split across octaves.
  A phrase cut short by a section end ends on its last held note, not a dangling pickup.
- **Sources** in `tools/batch-output/jazz-midi/fan/`: My Funny Valentine (melody track 1, trumpet
  track 5), Song for My Father (tenor sax track 4), Blue Bossa (upper voice of track 2).
  Considered and passed over: So What (the bass call is not transcribed), Seven Steps to Heaven
  (the vibes track is comping), Chet Baker's Weimar solos (double-time runs, no chord context).

## Three themes per solo (2026-11-11)

Zack: the solos were one hook and its variations, where a player has two or three ideas and
comes back to the first now and then. CHL-LD1-001, 007, 008 and 015 now play three themes. A is
the rule's own licks, unchanged. B is a contrasting tune and C is a blowing line from a real
solo, each from a different work, transcribed in key-root terms and fitted per song like the A
licks. Each theme has two licks that alternate. CHL-LD1-013 Moanin' and CHL-LD1-014 Cantaloupe
are left alone because they already work as call and response with solo licks.

- **Form:** A A B, then one replay of the first seed (so the opening reads A A B A), then the
  song cycles a seed-picked form of five (C B A C B, C A B C B or B C A B C). The last fifth opens
  with a plain A, then the form resumes. Seed returns still bring A back: no recalls before the
  opening is complete, and recap recalls at 30% a phrase instead of 55%.
- **Measured over 120 Chill seeds** (seed returns counted as A): A 48 to 62%, B 23 to 28%,
  C 14 to 22%. Chet sigh is highest on A because its songs run shorter.
- **CHL-LD1-001 Chet sigh:** B from Chet Baker's ballad solo on *I Fall in Love Too Easily*
  (a lean around the 3 climbing to a held 5; the repeated 3 between the blue thirds). C from his
  solo on *Let's Get Lost* (the leap to the b7 and 9, through the #4 to the 5; an arpeggio to the
  octave turning home).
- **CHL-LD1-007 Horace hook:** B from Kenny Dorham's solo on Horace Silver's *Doodlin'* (a riff
  around the root stated three times reaching higher; the chromatic b3-3-4-#4-5 climb). C from
  Lee Morgan's solo on *The Sidewinder* (the 4 hammered in 8ths; an 8th-note run to the octave).
- **CHL-LD1-008 Blues bossa:** B from the head of *Stolen Moments* (Oliver Nelson; the climb to
  the 9 and fall, and its sequence a step up). C from Miles Davis's solo on *So What* (the root
  restated with space around it; 2-b3 into a held 4 and a slow rise home).
- **CHL-LD1-015 Blue Monk riff:** two-bar themes. B from *Parker's Mood* (the opening fanfare;
  the arpeggio to the octave into a held 4). C from Sonny Rollins's solo on *Tenor Madness* (the
  3 and root traded in a rhythm; the root hammered). Now marked "* " in the log.
- **Code:** `JazzCellState.form`, `themeLick` and the B/C banks in `ChillLeadGenerator.swift`;
  the opening-replay and recap changes are gated on `isThemed` in `generateLead1`. Other rules
  draw nothing new, so their songs are unchanged.
- **Passed over:** St. Thomas and Now's the Time (the MIDI files are truncated), Blue in Green
  (the fan file has the guitar comping, not the melody).
- **Weimar solos** in `tools/batch-output/jazz-midi/weimar/` are melody only. Fast ones
  (Sidewinder 156, Let's Get Lost 159, So What 139, Tenor Madness 176) were read at half speed so
  their 8ths become Chill 16ths; the 65 bpm ballad at double speed.

## Lead 2 answers (2026-11-11)

Zack wanted Chill's Lead 2 to sound like a second soloist riffing off Lead 1, shorter, jazzier
and not the same as Kosmic's Lead 2. Until now CHL-LD2-001 replied in Lead 1's empty bars with a
fresh scale random walk that took nothing from the phrase it answered. Base Chill and Chill Blues
now draw one of four answer rules (Chill Soho keeps CHL-LD2-001 and Shadow hold). Each is the
song's habit, used for about 70% of its answers; the rest are drawn from the other three, so a
song still varies. Marked "* " in the log while being tuned by ear.

- **CHL-LD2-003 Tail riff** (30% of answer songs): Lead 1's last two to four notes in Lead 1's
  rhythm, a scale step lower or higher, a third lower or an octave down, then a resolving chord
  tone. A two-note tail is often sequenced twice.
- **CHL-LD2-004 Rhythm trade** (25%): the rhythm of Lead 1's last notes with a new line moving
  the other way, ending on a chord tone.
- **CHL-LD2-005 Bebop enclosure** (20%): Lead 1's last note, or a chord tone next to it,
  approached from a scale step above and a semitone below (or the reverse, or from two steps
  above, or as quick 16ths), then held, sometimes with a falling tag.
- **CHL-LD2-006 Question and answer** (25%): after a phrase that ends off the root or fifth, a
  falling line home to a chord tone; after one that ends on it, a rising arpeggio left open on a
  tension. Straight, dotted or pushed 8th-note rhythm.
- **Placement:** one answer per Lead 1 phrase it replies to (A 50%, B 80%), about a bar long,
  starting an 8th after Lead 1's last note has ended and finishing two steps before Lead 1's next
  note. In a handoff window (Lead 1 lays out so Lead 2 takes over) every gap is answered and Lead
  2 keeps riffing on its own answer, up to three in a row, each a sequence of the last; now and
  then a long Groove B gap does the same. Never in breakdowns, and in Blues never in the
  turnaround (form positions 13 to 15).
- **Pitch:** each answer is fitted to the register as one block (moved by scale steps if no
  octave fits), held notes on chord tones of their bar, passing notes in the scale. A held note
  never restates the note before it. An enclosure's chromatic note is kept off the beat, where
  HarmonicFilter would remove it.
- **Register:** below the middle of Lead 1's register (CHL-RULE-12) where the instrument allows,
  otherwise the instrument's own bottom octave and a half. The old rule could ask a flute under a
  muted trumpet for 55 to 67, under the flute's floor, and the final register fold then split its
  figures across octaves. The fix applies to the answer rules; Shadow hold and Soho are unchanged.
- **Shares:** base Chill Shadow hold 35% (was 50%), answer rules 65%. Blues: answer rules only.
- **Bug fixes with it:** Lead 2 no longer starts over Lead 1's still-sounding last note, and a
  Lead 2 regen now gets Lead 1's notes and handoff windows (it replays Lead 1 on its own seed for
  the windows, as Kosmic does for its X-Files bars). A Shadow hold lead-in no longer lands in a
  breakdown bar.
- **Measured over 400 Chill seeds:** answer notes sounding over Lead 1 fell to 2 (excluding the
  harmony windows, which double Lead 1 on purpose), against 134 for Soho's CHL-LD2-001; leaps
  over a sixth inside a figure are about 1% of answer notes.
- **Code:** `jazzAnswers` in `ChillLeadGenerator.swift`; the rule draw in `generateLead2`.

## Stop-time breakdown solo (2026-11-11)

In a stop-time breakdown the band hits on the even bars, and on the odd bars Rhythm (and Pads)
climb the chord on beats 2, 3 and 4. Lead 1 used to play random scale notes in up to four or six
odd bars, often falling while the band rose on the same beats (Deep Long Lake, bar 32). Zack asked
that the soloist play in every stop-time breakdown, a bit differently each time, and only in the
last few bars of a long one.

- **Which bars:** all the odd bars of a 4-bar breakdown, the last two of an 8-bar one, the last
  three of a 12-bar one.
- **Earlier solo bars:** the song's opening phrase, its first four notes, in the gaps around the
  band's beats (one of three rhythms: in the gaps; a quick call on beat 1 and a pickup; the
  off-beats only), a scale step higher each bar, ending on a chord tone.
- **Last solo bar (the join):** the soloist's own note on beat 1, then the band's climb on its
  beats: a chord tone above each band note (45%), in unison with it (25%), or from beat 3 only
  after two notes of its own (30%). The climb is kept whole in the register. Half the time an
  8th-note pickup leads into the groove.
- **Every song:** a lay-out or rest that steps over the whole breakdown no longer skips it. St
  Germain staccato burst (CHL-LD1-005) plays the same solo, its fragment from its latest notes.
- **Code:** `stopTimeSolo` in `ChillLeadGenerator.swift`; the band's notes come from
  `ChillRhythmGenerator.stopTimeReveal`, which the Rhythm track also uses. Its draws come from a
  stream derived for the breakdown, so songs without a stop-time breakdown are unchanged.

## Lead 1 shares, as a share of all songs

Shared between substyles: CHL-LD1-009 and CHL-LD1-014.

- **Chill regular:** CHL-LD1-005 St Germain staccato burst 18 (the staccato roll fires on 70% of
  St Germain-beat songs and 5% of the rest), CHL-LD1-015 Blue Monk riff 17, CHL-LD1-001 Chet
  sigh 17, CHL-LD1-014 Cantaloupe Island hook 15, CHL-LD1-007 Horace hook 13,
  CHL-LD1-008 Blues bossa 13, CHL-LD1-009 Jazzy blues lead 7.
- **Chill Blues:** CHL-LD1-002 Miles punch 20, CHL-LD1-004 Blues lead 20, CHL-LD1-013 Moanin' 20,
  CHL-LD1-003 Chet sparse melody 15, CHL-LD1-009 Jazzy blues lead 13, CHL-LD1-014 Cantaloupe
  Island hook 12.
- Miles punch, Chet sparse and Blues lead play in Chill Blues only. Chill Soho has its own pool
  but still reuses Blues lead and Chet sigh through a forced rule ID.
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
- Lead 2 answers (CHL-LD2-003 to 006) and the stop-time solo are built (2026-11-11) and not yet
  heard. Tune by ear: rule shares and the 70% habit in `generateLead2` and `jazzAnswers`, the
  answer rates (A 50%, B 80%), the chain length, and the join styles in `stopTimeSolo`.
- Chill Soho's Lead 2 still plays CHL-LD2-001's random-walk replies, capped at two notes a bar.
  The answer rules could serve Soho too if Zack wants it.
