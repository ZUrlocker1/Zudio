# Solo improvement plan: Motorik and Kosmic leads

Status (2026-11-10): done. All six phases are built. The retired lead rules are deleted and each
new rule holds the number of the rule it replaced, so the rule IDs below are the final ones. The
Motorik Lead 1 hooks are MOT-LD1-001, 002, 003 and 006 and the Motorik Lead 2 gap answers are
MOT-LD2-001, 002, 003, 004 and 006. The Kosmic Lead 1 hooks are KOS-LD1-001, 005 and 007 and the
Kosmic Lead 2 gap answers are KOS-LD2-002 to 004, with KOS-LD2-005 Space echo reply for Space.
Kosmic Lead 1 rules are KOS-LD1, so no ID serves both leads. The testing star stays on every new
rule until Zack says testing is done.

## What this is

The newer substyles (Motorik Europe, Chill Soho, Kosmic Space) play leads built from real
transcriptions, and they sound far better than the base styles. Several early Lead 1 rules in base
Motorik and base Kosmic pick scale positions by rule of thumb, so nothing is stated, remembered
or brought back and the line never becomes a tune.

The fix follows the Chill jazz lead rules in `chill-jazz-leads-plan.md`. Each new rule plays a
small bank of cells taken from one real piece, mapped to the song's mode and reworked per song as
homage, never copied. The bar for each rule is a hook you could hum. Lead 2 is rebuilt to answer
Lead 1 in its gaps instead of playing over it.

## Rules that hold for every new rule

- **Replace everywhere.** A retired rule is replaced in every pool that used it. The replacement
  takes the retired rule's slot and its number, and the retired rule is deleted. Each substyle's
  own rules stay as they are.
- **Never replace MOT-LD1-005 Call and answer.** It is liked and stays in every pool.
- **Homage, not copy.** Each song transforms every cell, so no song plays the source as written.
- **Fit the beat.** Motorik drums put the kick on steps 0 and 8 and the snare on 4 and 12, with
  hats and bass on even steps. Every hook and answer note sits on the 8th-note grid, held notes on
  beats, and no variation shifts a figure a 16th late. A figure may be a native 16th riff only
  where its source is one.
- **Named for the source.** Every rule has a name no other rule uses, and one ID has one log name
  everywhere. No parentheses and no French accents in log lines. Rule IDs are always written in
  full.
- **Testing star.** Every new or changed rule ID is in `GenerationLogEntry.testingMarkedRules`
  (`Models/SongState.swift`), which prints "* " before its name in the log. Keep it until Zack
  says testing is done, the rules are final, or the build goes to the App Store, then empty it.
- **RNG.** New draws come from derived streams, so other tracks keep their output.
  `SeededRNG.weightedPick` does not normalise, so weights must sum to 1. Kosmic Space depends on
  `pickLeadRule2` being exactly one draw.

## Built: Motorik Lead 1 (phases 1 and 2)

### The four rules

- **MOT-LD1-001 Hallogallo hook**, Neu!, *Hallogallo*: a call 5, 7, 14, 14 semitones from the
  tonic at steps 0, 2, 4 and 8, answered by 5, 7, 12, 12, with a source variant that ends on the
  fifth and a soft pulse tail in 8ths. Replaces Neu! motif first: 15% in base, 4% in Noir, 3% in
  Arcade.
- **MOT-LD1-002 Radioactive riff**, Kraftwerk, *Radioactivity*: the one-bar key-synth riff, 16th
  based with a pickup. The plain answer is the same riff two scale steps lower, and the vocal line
  1 1 1 1 3 2 1 is the source variant. Replaces Pentatonic cell: 14% in base, 2% in Arcade.
- **MOT-LD1-006 Model riff**, Kraftwerk, *The Model*: a two-bar riff with a long held root. The
  vocal line alternates with it as a restatement, and a source variant ends the riff on the root.
  Replaces Long arc solo: 12% in base, 4% in Noir.
- **MOT-LD1-003 Tour de France riff**, Kraftwerk, *Tour de France*: a rising one-bar call and a
  two-bar answer, with a variant cadence 4 3 1. The longest phrase. Replaces Punch solo: 15%
  in base.
- Europe's sequence-lock songs draw the base pool and get all four. The retired rules are deleted.
- The cell data is in `HookLeadEngine.swift`. A hook drawn only for the B section keeps the A rule.

### The engine

`Sources/Zudio/Generation/HookLeadEngine.swift`. A rule is data: call bars, answer bars, an
optional restatement, an answer shift, source variants, an optional tail, and statement spacings
with weights. After `generateLead1` has drawn the entry bar and `buildRestBars`, the engine lays
out the whole song in one call and returns early, owning both A and B sections.

- **Homage per song.** Every cell gets one to three changes: add a passing or neighbour note on
  the 8th grid, drop an interior note, move an off-beat 8th onto the beat before or after it, swap
  two adjacent notes, or turn a repeated note into a neighbour. The first and last notes never
  change. Every note stays on the 8th grid except a native 16th riff.
- **Count.** The body states the hook 3, 4 or 5 times, with the cap drawn 20, 40 and 40%, plus a
  soft outro statement 30% of the time, so 3 to 6. Spacings run 8 to 20 bars. Over the cap, the
  statement whose neighbours are closest goes. Under 3, the biggest gap gets one.
- **Forms.** The first statement is the full hook. Each later one is the full cell again or one of:
  - the head alone, the first half of the call with its last note held;
  - the head said twice in one bar;
  - the answer alone;
  - the call as a sequence a scale step up or down;
  - the full cell with a small variation: a source variant, a dropped note, the last note held
    over the next bar, or the answer withheld.
  - After a varied statement the full cell returns about 45% of the time. The last statement is
    always the full cell with its last note ringing.
- **Placement.** Statements avoid rest windows, the base Motorik breakdown windows and the intro.
  At least one statement falls in the last third of the song, and the last fifth plays the full
  hook. B sections restate the hook a scale step or a third up, or lean on the variants.
  Statements sit on a two-bar grid from the entry. The tail cell fills the bar after a statement
  about three times in ten.
- **Fitting.** The tonic octave is chosen once per song, with the hook's centre just below the
  middle of MIDI 52 to 79. Seven-note modes map source semitones by scale degree, so a major or
  minor third becomes the song's third; pentatonic modes snap to the nearest note, ties up. A held
  note that is an avoid tone moves to the nearest chord tone. Each statement moves as a block to
  stay in one octave. Notes hold to the next onset, since short transcribed notes sound clunky on
  synth leads.

### Wiring and filters

- `LeadGenerator.generateLead1` takes a `breakdownBars` parameter. `SongGenerator` computes the
  breakdown windows before Lead 1 and passes them, so the engine places statements around them.
  The same windows are cut at step 12.5 as before.
- `ArrangementFilter.apply(phraseTracks:)`: a hook-rule Lead 1 is softened and never thinned or
  silenced. Letting the filter rest whole blocks removed most statements.
- `HarmonicFilter.apply(uniformLead1Lift:)`: one octave decision per song. `skipLead1ClashFilter`
  skips Pass A for hook rules.
- Motorik Lead 1 regen does not run HarmonicFilter and does not pass `breakdownBars`, so regen
  and first generation differ.
- `lead1RuleDescription` in `SongGenerator.swift` holds the log names.

### Mix changes made alongside

- Motorik bass Moog and Synth Bass 3: CC7 90, about 1.8 dB down (`AppState.instrumentPoolVolumeCC7`).
- Motorik bass Lead Bass: sampler volume 0.22, about 2.7 dB below the old 0.30 (`PlaybackEngine`).
- Motorik Lead 1 Synth Lead, Saw Stack and Polysynth: boost-node multiplier 1.3, about +2.3 dB
  (`PlaybackEngine`). Saw Stack was already at the CC7 ceiling.

### Where the retired rules were replaced outside the base pool

- Motorik Noir Lead 1: MOT-LD1-001 Hallogallo hook and MOT-LD1-006 Model riff, 4% each.
- Motorik Arcade Lead 1: MOT-LD1-001 at 3% and MOT-LD1-002 at 2%.
- Motorik Arcade Lead 2 regular pool: MOT-LD2-001, 003 and 004.
- Motorik Europe base Lead 2, when Lead 2 is not in the sync.
- Kosmic B sections and bridge melodies, base and Drift: `pickBSectionRule` and
  `pickLeadRuleDifferentFrom` no longer draw the three retired Kosmic rules. Those are per-bar
  contexts and hook rules are whole-song, so the retired rules came out of the candidate lists
  rather than being replaced.
- Kosmic Space Lead 2 plays KOS-LD2-005 Space echo reply, not a Lead 1 rule.

## Built: Motorik Lead 2 (phase 3)

### Why Lead 2 was replaced

In base Motorik the two leads overlapped and were unrelated. Lead 2 played during Lead 1's
phrases with random chord or scale notes, in nearly the same register, and it was written before
`ArrangementFilter` and the breakdowns removed Lead 1 notes, so it answered calls that no longer
existed.

### The five rules

One is drawn per song. The cell data and the engine are in
`Sources/Zudio/Generation/GapAnswerEngine.swift`.

- **MOT-LD2-001 Echo answer**, 22.5% in base: Lead 1's last 2 to 4 notes in the same rhythm, a
  diatonic third, sixth or octave lower. The interval is drawn once per song, 45, 25 and 30%.
- **MOT-LD2-003 Hook fragment**, 22.5%: the first 2 to 5 notes of Lead 1's last phrase, inverted or
  moved one scale step down, drawn per answer: 2 notes 25%, 3 30%, 4 25%, 5 20%. Lead 1's 16ths
  fold into the 8th grid, so more of its notes are taken until the placed figure has the drawn
  count.
- **MOT-LD2-004 Answer cell**, 25%: a cell paired with Lead 1's rule, reworked once per song as
  homage. The first and last answers play the full cell; the others take a form drawn per answer:
  the full cell 35%, the head alone with its last note held 30%, the cell inverted around the note
  it resolves to 20%, or the cell followed by its head a scale step lower, up to three bars, 15%.
  Every form plays in the full cell's octave, chosen once per song; an inversion that would
  leave the register gives way to the head. Half the songs may drop a middle answer an octave,
  40% of the time, at most twice and never twice running; those songs sit the cell as high as
  MIDI 69 allows, and a drop plays only where it fits above 47. About one Answer cell song in
  seven drops, usually once. The cells:
  - MOT-LD1-001 Hallogallo hook: the pulse tail, flat seventh into the root in 8ths.
  - MOT-LD1-002 Radioactive riff: the vocal line 1 1 1 1 3 2 1, on 8ths.
  - MOT-LD1-006 Model riff: the tail, 2 flat 7 5.
  - MOT-LD1-003 Tour de France riff: the cadence flat 7 flat 3 1, its last note on the beat.
  - Every other Lead 1 rule: a two-bar descent 5 4 3 2 to the root.
- **MOT-LD2-006 Statement harmony**, 15%: every second Lead 1 statement, a diatonic third below
  in Lead 1's rhythm, from an offset drawn per song. A statement is a body phrase of three notes
  or more. It is not drawn in a song with a Lead 1 solo, which blocks Lead 2, and is redrawn from the other four rules in their proportions, so its share is about 12% of base songs. Only Lead 1's 8th-grid onsets are harmonised; a harmony note holds through any 16th in
  between. The harmony sits a third under Lead 1 wherever Lead 1 is, so it may run above 67. In
  the other gaps it plays echo answers.
- **MOT-LD2-002 Low bed**, 15%: the chord's root or fifth held under each Lead 1 note of a beat or
  more, and in any bar of the phrase without one from its first beat for half a bar, MIDI 50 to
  60, starting on a beat. The song's target of 4 to 6 phrases get a bed, spread evenly over the
  body. Consecutive beds on one pitch join into one note up to a bar. Once or twice a song, 50% each,
  the bed also plays alone in one of the longest Lead 1 silences, four bars or more: the chord's
  root or fifth held for one or two bars, starting on a bar line a bar after the phrase before it
  and ending half a bar before Lead 1 returns. Two bars only while the chord stays the same. These
  solo beds are outside the 4 to 6 count. It plays nothing else in the gaps.

### Pools

- Base: MOT-LD2-001 Echo answer 22.5%, MOT-LD2-002 Low bed 15%, MOT-LD2-003 Hook fragment 22.5%,
  MOT-LD2-004 Answer cell 25% and MOT-LD2-006 Statement harmony 15%. Each took the number of the
  Lead 2 rule it replaced, and MOT-LD2-005 is unused. The old Lead 2 rules are deleted.
- Motorik Europe draws the base pool when Lead 2 is not in the sync, which is the Rhythm Section
  group. Sequence Lock and Machine Voice keep MOT-LD2-011 and 012.
- Motorik Arcade's regular pool: MOT-LD2-001, 003 and 004 at 45, 35 and 20%. The arp rules
  MOT-LD2-007 to 010 and the dense-melody "No lead 2" are drawn from the same stream as before.
- Noir has no Lead 2.

### How they behave

- **Phrase map.** Lead 1's onsets group into phrases wherever the gap from one note's end to the
  next onset is under 8 steps. A gap runs from one phrase's end to the next phrase's start.
- **Silence.** Lead 2 is silent while Lead 1 plays a phrase and for a tail of 2 or 4 steps after
  it, drawn per song. Only the harmony and the bed sound with Lead 1.
- **Answers.** Only in gaps of a bar or more, ending at least two steps before Lead 1 returns, at
  most two bars long, three for the Answer cell's long form.
- **Count.** Each song states Lead 2 4, 5 or 6 times in the body, drawn 30, 40 and 30%. The
  answer straight after a phrase comes first. Over the target, the one whose
  neighbours are closest goes, never the first or the last. Under it, a Lead 1 silence of four
  bars or more is a handoff: Lead 2 restates its answer there, every four bars, filling the
  longest silences first and never within two bars of another answer. The outro echo is outside
  the count.
- **Breakdowns.** Lead 2 stays out of the base Motorik breakdown windows and a Lead 1 solo, so the
  breakdown stays a drop to drums, bass, pads and texture.
- **Intro and outro.** Silent in the intro. In the outro, at most one echo of the final statement,
  softer.
- **Grid.** Every onset is on the 8th grid and held notes start on beats. A Lead 1 note on an odd
  step moves to the 8th before it. An answer keeps Lead 1's beat positions, starting on a half bar
  when it still fits. Notes hold to the next onset within 8 steps.
- **Register.** Answers fit MIDI 50 to 67 as a block, so a figure stays in one octave. An echo
  keeps its true interval when it fits. The Answer cell uses 50 to 69, and 47 for a drop.

### Wiring

- `LeadGenerator.generateLead2` draws the rule. For a gap rule it records the ID and returns
  nothing. The 50% bar coin, the forced root fallback and the Hallogallo counter swap
  are gone with the old base path.
- `SongGenerator.generateMotorik`, step 12.6, writes the part with `GapAnswerEngine.generate`,
  continuing the Lead 2 stream, from the Lead 1 the listener hears: after `ArrangementFilter` and
  `HarmonicFilter`, without the breakdown windows and, in a sync that includes Lead 1, without the
  sync dropout windows. Lead 2 is not in that sync, so it may answer in those windows.
- Lead 2 is empty when `DensitySimplifier` and `ArrangementFilter` run, so neither thins it. It
  gets its own `HarmonicFilter.filterLead` pass with one octave decision per song, bounded at 67,
  and at 60 for the bed, so Pass B cannot lift it out of its register.
- Because Lead 2 is empty when `ArrangementFilter` runs, the filter no longer counts it as an
  active melodic track in these songs. In base and Arcade songs it now rests or thins Lead 1,
  Rhythm and Pads less often, and the drum fills that follow Lead 1 can move with them. Noir,
  Arcade's arp rules and the synced Europe Lead 2 are unchanged.
- Regen: the Motorik Lead 2 regen calls the same function with the Lead 1 now playing, the base
  breakdown windows and the Lead 1 rules read from the log, so regen and first generation agree.
- Names are in `lead2RuleDescription`; all five IDs are in `testingMarkedRules`.

### Measured over Motorik seeds 1 to 600

- Wins in base, at the earlier weights: MOT-LD2-001 30%, 003 18%, 004 22%, 006 21%, 002 9%.
- Lead 2 onsets inside a Lead 1 phrase: none for MOT-LD2-001, 003 and 004; 54% of the harmony rule's
  notes and all of the bed's, by design.
- Odd-step Lead 2 notes: none. Held notes off the beat: none, apart from harmony notes that
  mirror a Lead 1 note held off the beat.
- Appearances per song: 4 to 6 in the body for nearly every song, plus the outro echo; fewer
  only where Lead 1 leaves no room, about 3% of songs.
- Notes per song: MOT-LD2-001 about 15, 003 about 13, 004 about 25, 006 about 31, 002 about 10.
  The old base Lead 2 averaged 84.
- Fingerprints against HEAD: Noir, Arcade's arp rules and the Sequence Lock and Machine Voice
  songs are identical on every track.

## Built: Kosmic (phases 4 and 5)

### Built: Kosmic Lead 1 (phase 4)

Three hook rules replace the three weakest base rules and share `HookLeadEngine` with the Motorik
hooks. The cells are in `HookLeadEngine.swift` (`kosmicRules`); the source cells are listed below.

- **KOS-LD1-007 Blade Runner theme**, 14%, replaces TD Skip Sequence. The 12-bar
  line is stored as scale steps (the `scaleSteps` flag), so it keeps its shape in any mode. The
  call is the first four bars and ends on the held fourth below; the answer is phrases 2 and 3,
  the second a step lower and the third the cadence to the long low tonic. Its homage is one
  added upper-neighbour note per cell. It states 3 or 4 times.
- **KOS-LD1-001 Pulstar theme**, 15%, replaces Slow Arc. A pickup F F F G into
  the tonic, then four whole notes C Bb F G, said again an octave up (`answerShift` 7). Its
  homage turns a repeated pickup note into a neighbour. In a key with no room for both octaves
  the repeat comes down to a fifth, then to the same octave. It uses MIDI 52 to 84. It states 4
  to 6 times, drawn 35, 40 and 25%, every 12 to 16 bars, with the shorter answer-only form, the
  octave-up half, at 35% of the varied statements. Source variants: no pickup, and the last note
  held across two bars.
- **KOS-LD1-005 Beach Scene sigh**, 14%, replaces Arpeggio Highlight. A
  three-bar call, the sigh with its long held sixth, and a two-bar answer of rising arpeggios on
  IV and V landing on the root. One source variant falls to the fifth before rising. It states 3
  to 5 times.
- The three retired rules are deleted. KOS-LD1-002, 003, 004, 006, 008 and 009 hold the rest of
  `pickLeadRule`: 9, 9, 7, 15, 9 and 8%. `pickBSectionRule` draws 002, 003 and 004, and
  `pickLeadRuleDifferentFrom` draws 002, 003, 004, 006, 008 and 009.
- Kept: KOS-LD1-002 Floating tones, 003 Pentatonic drift, 006 JMJ Phrase Loop, 008 Caligari Solo
  and 009 Dark Sun Solo.
- Fixes to the kept window solos, found by ear:
  - KOS-LD1-008 and 009 are passed as `phraseTracks` to `ArrangementFilter`, so a block is
    softened but never rested; a rested block had taken whole windows.
  - KOS-LD1-008 Caligari Solo widens its pool to the whole scale, chord tones weighted double,
    when fewer than four chord tones fit the register, as with a minor chord on flat 7 whose third
    lies outside the mode. It never repeats the previous note and prefers steps to leaps.
  - KOS-LD1-009 Dark Sun Solo plays at least twice: when only one ten-bar window fits, a
    five-bar return is added four bars clear of it.

How they differ from the Motorik hooks, all as data on `HookRule`:

- **Entry and sections.** The hook enters four bars into the first A section and owns the A and B
  sections. The bridges and X-Files whistles stay with the existing Kosmic code. A hook rule
  makes no Technique D draw, so its B section never switches rule.
- **Forms.** No head or loop forms: those cut a one-note bar. Answer only 25%, sequence 30 to 35%
  and varied 40 to 45%. Blade Runner's sequence always steps down.
- **Count.** Per rule, as above, with a minimum of 3, and 4 for Pulstar. How many statements a Kosmic song should
  have is still Zack's call.
- **Homage.** One change per cell. Blade Runner and Pulstar restrict the operations, because a
  dropped note empties a bar of the staircase and a swap trades Pulstar's tonic with its pickup.
- **Filters.** `SongGenerator` passes `phraseTracks: [Lead 1]` to `ArrangementFilter`, and
  `skipLead1ClashFilter` and `uniformLead1Lift` to `HarmonicFilter`, when Lead 1 is a Kosmic hook.
- **Rhythm.** The base Kosmic density guard thins the arpeggio under Lead 1 whenever the arpeggio
  is more than twice as dense, so a sparse hook thins it the way the other sparse rules do.
- **Names and star.** Log names are in `kosmicLeadRuleDescription`; all three IDs are in
  `testingMarkedRules`.
- Kosmic Space, Drift and Drift Dreamscape never draw these rules.

Measured over Kosmic seeds 1 to 120 with each rule forced, on the 45 songs per rule that are not
Space or Drift: every hook song starts with the star, Blade Runner states 3 or 4 times, Pulstar 3
to 5 and Beach Scene 3 to 6, and Lead 1 averages about 64 notes a song. Moves of more than an
octave between notes less than a bar apart occur in 5 of 135 songs.

### Built: Kosmic Lead 2 (phase 5)

Base Kosmic Lead 2 is the gap-answer design. It runs on `GapAnswerEngine` with Kosmic data: the
same draws in the same order, so Motorik is unchanged. Kosmic Space and Drift are untouched.

- **The pool.** `pickLeadRule2` is one draw. KOS-LD2-002, 003 and 004 take 35, 35 and 30%. Space
  calls it, ignores the result and draws again. Space Lead 2 plays KOS-LD2-005 Space echo reply,
  KOS-LD2-001 Magnetic Twin or KOS-LD2-000 No lead 2, a third each. KOS-LD2-005 is the Echo Melody
  cycle started two bars later, so its phrases fall where Echo Melody rests, with the echo always a
  diatonic third below.
- **KOS-LD2-002 Slow echo answer**: as MOT-LD2-001, Lead 1's last 2 to 4 notes a third, sixth or
  octave lower, but a figure that fits in a bar plays at half speed, so the echo moves in long
  notes. It takes fewer notes when the gap is short, and may run to four bars.
- **KOS-LD2-003 Slow answer cell**, paired with Lead 1's rule:
  - KOS-LD1-007 Blade Runner theme: Lead 1's held last note a diatonic third lower, on the bar
    line a bar after it starts and never before the phrase ends, held up to two bars.
  - KOS-LD1-001 Pulstar theme: the rising riff 1 2 flat 3 into 4 on the bar, 5, then 1 held, in
    native 16ths. Its homage only drops a middle note, so it stays a rising run.
  - KOS-LD1-005 Beach Scene sigh: the IV and V arpeggios in 8ths landing on the root. Its homage
    adds a passing note or drops one.
  - Every other Lead 1 rule: KOS-LD1-004's two-on, two-off cell, the fifth held into the sixth,
    every other answer a third lower.
  - The cells keep their place in the bar, moving by whole bars, and take the same forms as
    MOT-LD2-004, without the octave drop.
- **KOS-LD2-004 Gap reply melody**: KOS-LD1-004's two held notes a step apart, started from the
  note Lead 1 ended on, on a bar line in Lead 1's gap; every other reply a third lower.
- **Harmony windows**, every Kosmic rule: Lead 2 joins Lead 1 for four bars, a diatonic third
  under it 65% of the time and in unison 35%, drawn per window, in MIDI 52 to 79. Two windows a
  song, one more when Lead 1 left room for under four answers, one more when Lead 1 plays
  through more than 60% of the body, and more, up to six, while Lead 2 would have under 24
  notes. Windows sit on a four-bar grid from the body's start where Lead 1 has two or more
  8th-grid onsets and Lead 2 is silent, spread evenly. They are drawn after everything else.
- **Behaviour** otherwise as Motorik Lead 2: silent through Lead 1's phrases outside the harmony
  windows, 4 to 6 answers in the body,
  one outro echo, a tail of 4 or 8 steps after a phrase. Register 52 to 69; at 55 to 67, one octave, a
  figure straddling the edge folded a note down an octave.
- **Wiring.** `generateLead2` records the rule and writes only the bridge A-2 figure.
  `SongGenerator.generateKosmic` writes the answers after `ArrangementFilter` and
  `HarmonicFilter`, from the Lead 1 the listener hears. Regen does the same, reading the hook
  rule from the log, and adds the answers after its own Lead 2 filter pass. The collision shift,
  the held-note fill and the B escalation stay on the old path only.
- **Regen fix found here.** A regenerated Kosmic hook Lead 1 now skips the clash guard and gets
  one octave decision, as generation gives it.
- Names are in `kosmicLeadRuleDescription`; all three IDs are in `testingMarkedRules`.

Measured over Kosmic seeds 1 to 300, on the 114 base songs:

- No Lead 2 onset inside a Lead 1 phrase before the harmony windows were added; now only the
  harmony notes sit inside one.
- No off-grid notes outside the Pulstar riff.
- Range 52 to 69.
- Every song shows the star.
- 4 to 6 answers in nearly every song.
- Lead 2 notes per song, with the harmony windows: 20 to 53 by Lead 1 rule, most 24 to 30. The
  old Lead 2 averaged about 60.

Fingerprints against HEAD on seeds 1 to 120: every Motorik track, and every track of the 74
Space and Drift songs, is identical.

### Source cells for the Kosmic rules

Cells are semitones from the phrase's tonic on a 16-step bar. "@n" is the onset step and "/n" the
length. Negative steps are pickups. Everything is scale-mapped to the song's mode.

- **K1, Vangelis, *Blade Runner* End Titles.** Track 4, bars 13 to 26, long notes. A four-bar
  unit: whole note, two half notes, a two-bar hold, each note a scale step lower, then sequenced
  down one scale step, twice.
  - Phrase 1: C/16, Bb/8 Ab/8, G/32. Scale steps 0, -1, -2, -3.
  - Phrase 2 starts a step lower: Bb, A G, F.
  - Phrase 3 starts lower again: Ab, G F, C/24, then Eb/8 into a long low C. It breaks the
    sequence and drops to the tonic, so it is the cadence.
  - Store it as scale steps. The rule picks a start degree so the 12-bar line fits the register.
- **K2, Vangelis, *Pulstar* brass theme.** Channel 8, bars 119 to 134. Pickup 4@8, 4@10, 4@12,
  5@14 into 1 on the bar, then four whole notes, one per bar: 0, -2, -7, -5. Repeated an octave
  up. Vary by register, by dropping the pickup, or by holding the last note across two bars.
  - The rising riff, channel 3: 0@13, 2@14, 3@15, 5@16/2, 7@18, then 0@19, which is 1 2 flat 3 4
    5 and down to 1. Too busy for Lead 1, ideal as a Lead 2 answer.
- **K4, Tangerine Dream, *Beach Scene* guitar sigh.** Track "Distortion Guitar", bars 51 to 66,
  in A.
  - Call, two bars: 0@0/2, -1@2/4, -1@6/6, -1@12/4 | -1@0/4, -3@4/28. The root slips to the
    seventh, repeats and sinks to the sixth.
  - Answer, two bars, rising arpeggios on IV and V landing on the root: -12@0, -7@2, -3@4/4,
    -10@8, -5@10, -1@12/4 | 0@0/12. Bar 65's version stays inside MIDI 52 to 79.
  - Variant call from bar 63: the repeats fall to the fifth before rising to the sixth.

## Phase 6: docs

Done. `docs/motorik-plan.md`, `docs/kosmic-plan.md`, `docs/change-log.md` and the README state what
is in place, and the lead-rule IDs in the other plans use the final numbers.

## Build order and checks

Each phase ends with a macOS and an iOS build and Zack listening before the next phase, and
Zack's approval before the commit.

1. Hook engine and MOT-LD1-001. Done.
2. MOT-LD1-002, 003 and 006 and the base weights. Done.
3. Motorik Lead 2, MOT-LD2-001, 002, 003, 004 and 006. Done.
4. Kosmic Lead 1, KOS-LD1-001, 005 and 007. Done.
5. Kosmic Lead 2, KOS-LD2-002 to 004, and the Space gate. Done.
6. Docs. Done.

Checks stay light:

- macOS and iOS Debug builds each phase.
- One temporary `swift test --filter` measurement, deleted before commit: the share of Lead 2
  onsets inside a Lead 1 phrase, which should be near zero apart from the harmony and bed rules,
  how often each new rule wins, and that every note is on the 8th grid.
- A comparison of fingerprints against HEAD to confirm that only the intended songs changed. Run
  it with `SWIFT_DETERMINISTIC_HASHING=1`.
- No `xcodebuild test` and no `run_loop.sh` unless Zack asks.

## Sources and tools

- **Motorik:** Neu!, *Hallogallo*, from a fan guitar tab. A one-chord vamp in E, with Guitar 1's
  riff in 16ths and Guitar 2's call and answer. Kraftwerk, *Radioactivity*, *The Model* and
  *Tour de France*, from fan MIDI files.
- **Kosmic:** Vangelis, *Pulstar* and *Blade Runner*, and Tangerine Dream, *Beach Scene*.
- **Rejected:** Vangelis, *Chariots of Fire*, as too familiar. Already taken by substyles, so
  avoided: Kraftwerk's *Autobahn*, *The Robots*, *Computer Love* and *Numbers*, Jarre's *Oxygene*
  and *Magnetic Fields*, and Eno's *The Pearl* and *Music for Airports*.
- **MIDI sources:** MidiShow needs a login, so Zack fetches those by hand. BitMidi, Geerdes Media,
  BladeZone, Preset Patch, MuseScore, and Guitar Pro tabs from Ultimate Guitar and Songsterr.
  Fan uploads claim CC0 but the compositions are copyrighted, so Zudio takes short cells,
  scale-maps them and reworks them as homage.
- **Files, outside the repo and never committed:** `~/Downloads/solo-improvement-midi/`, with
  audition excerpts in `excerpts/`. `tools/fetch_solo_midi.py` fetches from BitMidi. The mining
  tool is `python3 -I tools/midi_phrase_mine.py FILE TRACK CHANNEL [--top N] [--dump A-B]`.
- **Not ours:** `tools/eno_analyze.py` and `tools/fetch_eno_midi.py` belong to the Ambient Zen
  work and are not committed here.

## Decisions

- Motorik takes Hallogallo, Radioactivity, The Model and Tour de France. Kosmic takes Blade
  Runner, Pulstar and Beach Scene, with the slots chosen as above.
- Base Lead 2 in both styles is replaced by the gap-answer design, and the Motorik drone and the
  other old Lead 2 rules are deleted.
- MOT-LD1-005 Call and answer is kept in every pool.
- A retired rule is replaced in every substyle that used it, and deleted. The new rule takes its number.
- Kosmic Lead 1 rules are KOS-LD1 and Lead 2 rules are KOS-LD2, so no ID serves both leads, as in
  the other styles.
- Build number 136 in `Version.xcconfig`, since build 135 went to the App Store. Version 2.9 is
  unchanged.

## Open questions

- Should MOT-LD1-002 Radioactive riff keep its off-beat 16ths, or snap its held notes onto beats?
- How many statements should a Kosmic hook song have? Motorik is 3 to 6.
- `DensitySimplifier.thin` is still buggy for Arcade's arp rules and the synced Europe Lead 2.
  The gap-answer Lead 2 is written after it runs, so it never reaches the new rules. Fix the rest
  only if Zack asks.
- Is Zack willing to play or tap a short hook for a La Dusseldorf or Harmonia piece if no file
  exists?

## Measured effect on musicality

Base Motorik (262 songs) and base Kosmic (166 songs), seeds 1 to 400, with the new rules and
weights against the code from before the Solo work. Structure only: these numbers show craft, not
whether a melody is good. Zack's ear is the test of that. Noir, Arcade, Space and Drift are not
included.

What is better:

- **More coordination between the leads.** Lead 2 plays far less over Lead 1, and where it does
  the clash is much rarer. Notes where Lead 2 sounds over Lead 1 that form a minor second,
  tritone or major seventh: Motorik 3.9% before, 1.4% now; Kosmic 9.8% before, 0.9% now. Motorik
  Lead 2 notes on off-beat 16th steps: 22% before, 6% now, so Lead 2 sits on the grid with the
  drums. Kosmic Lead 2 still sounds over Lead 1 in 59% of its notes, by design in the harmony
  windows, and those are now clean.
- **Recognisable tunes.** This matters most. Bars that recur exactly elsewhere in the song:
  Motorik 38% before, 62% now; Kosmic 72% before, 82% now. The most repeated two-bar figure:
  Motorik 3.6 times before, 3.8 now; Kosmic 2.6 before, 3.3 now.
- **Less clutter.** Lead 2 notes a song: Motorik 104 before, 58 now; Kosmic 56 before, 28 now.
  Lead 1 notes a song: Motorik 95 before, 72 now; Kosmic 115 before, 68 now.
- **Steadier melodic lines.** Leaps of more than an octave between neighbouring notes: Motorik
  0.9% before, 0.3% now; Kosmic 5.6% before, 3.3% now. Out-of-scale notes were already rare and
  are near zero.

How many songs hear the new work, a crude gauge from seeds 1 to 300 with Europe-style songs
excluded:

- **Base Motorik** (148 songs): about 76% use a new or lightly changed Lead 1 rule. That counts
  the hooks MOT-LD1-001, 002, 003 and 006 and the lightly changed solos MOT-LD1-007 Vanishing solo
  and MOT-LD1-008 Visiting solo.
- **Base Kosmic** (124 songs): about 56% use a new or lightly changed Lead 1 rule. About 41% got
  one of the new hooks KOS-LD1-001, 005 or 007; another 15% got a lightly changed solo, KOS-LD1-008
  Caligari Solo or KOS-LD1-009 Dark Sun Solo.
- **Lead 2** is left out of these shares. Every base Kosmic song draws one of the three new
  gap-answer rules, and base Motorik Lead 2 is almost all new, so counting it would only inflate
  the figures.

What may be too much, to investigate:

- **Bars with no lead sounding.** Counting a bar as sounding when a note rings in it, the share of
  bars with neither Lead 1 nor Lead 2 is Motorik 43% before, 71% now, and Kosmic 35% before, 54%
  now. Bars sounding Lead 1: Motorik 33% before, 22% now; Kosmic 45% before, 38% now. Some of this
  is intended, since Lead 2 waits for gaps and a hook leaves room between statements, but 71% empty
  in Motorik may be too sparse. Check by ear on full songs. If it is, the levers are the hook
  statement counts (how many statements a Kosmic hook song should have is still open), the rest
  windows and breakdown windows that hooks share, and the number of Lead 2 answers a song.
- **More exact repetition** comes with the stronger hooks. If songs feel looped, look at the
  statement forms and the full-cell returns before the counts.

Rerun the same measurement after any change to these weights or counts, and keep the three
properties above: less overlap and clash between the leads, tunes you can recognise, and less
clutter.
