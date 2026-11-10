# Solo improvement plan: Motorik and Kosmic leads

Status (2026-11-10): phases 1 and 2 are built, committed and approved by ear. They are the four
Motorik Lead 1 hook rules MOT-LD1-023 to 026. Phase 3, Motorik Lead 2 as gap answers
(MOT-LD2-013 to 017), is built and waiting for Zack's ear before it is committed. Phases 4 to 6
(Kosmic leads, docs) follow.

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
  takes the retired rule's slot and the retired rule moves to the end of the list at 0%, so
  restoring it is a one-line change. Each substyle's own rules stay as they are.
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

- **MOT-LD1-023 Hallogallo hook**, Neu!, *Hallogallo*: a call 5, 7, 14, 14 semitones from the
  tonic at steps 0, 2, 4 and 8, answered by 5, 7, 12, 12, with a source variant that ends on the
  fifth and a soft pulse tail in 8ths. Takes MOT-LD1-001's slot: 15% in base, 4% in Noir, 3% in
  Arcade.
- **MOT-LD1-024 Radioactive riff**, Kraftwerk, *Radioactivity*: the one-bar key-synth riff, 16th
  based with a pickup. The plain answer is the same riff two scale steps lower, and the vocal line
  1 1 1 1 3 2 1 is the source variant. Takes MOT-LD1-002's slot: 14% in base, 2% in Arcade.
- **MOT-LD1-025 Model riff**, Kraftwerk, *The Model*: a two-bar riff with a long held root. The
  vocal line alternates with it as a restatement, and a source variant ends the riff on the root.
  Takes MOT-LD1-006's slot: 12% in base, 4% in Noir.
- **MOT-LD1-026 Tour de France riff**, Kraftwerk, *Tour de France*: a rising one-bar call and a
  two-bar answer, with a variant cadence 4 3 1. The longest phrase. Takes MOT-LD1-003's slot: 11%
  in base.
- Europe's sequence-lock songs draw the base pool and get all four. MOT-LD1-001, 002, 003 and 006
  sit at the end of each list at 0%. MOT-LD1-003's B-section forcing never fires now; leave it.
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

### Where retired rules were used outside the base pool

- Motorik Noir Lead 1: MOT-LD1-001 and MOT-LD1-006, 4% each. Done.
- Motorik Arcade Lead 1: MOT-LD1-001 at 3% and MOT-LD1-002 at 2%. Done.
- Motorik Arcade Lead 2 regular pool: MOT-LD2-001, 003 and 005. Done in phase 3.
- Motorik Europe base Lead 2, when Lead 2 is not in the sync. Done in phase 3.
- Kosmic B sections and bridge melodies, base and Drift: `pickBSectionRule` and
  `pickLeadRuleDifferentFrom` can draw KOS-LEAD-001, 005 and 007. Phase 4. Those are per-bar
  contexts and hook rules are whole-song, so the retired rules come out of the candidate lists
  rather than being replaced.
- Kosmic Space does not use them. Its Lead 2 plays KOS-LEAD-004, which is kept.

## Built: Motorik Lead 2 (phase 3)

### Why Lead 2 was replaced

In base Motorik the two leads overlapped and were unrelated. Lead 2 played during Lead 1's
phrases with random chord or scale notes, in nearly the same register, and it was written before
`ArrangementFilter` and the breakdowns removed Lead 1 notes, so it answered calls that no longer
existed.

### The five rules

One is drawn per song. The cell data and the engine are in
`Sources/Zudio/Generation/GapAnswerEngine.swift`.

- **MOT-LD2-013 Echo answer**, 30% in base: Lead 1's last 2 to 4 notes in the same rhythm, a
  diatonic third, sixth or octave lower. The interval is drawn once per song, 45, 25 and 30%.
- **MOT-LD2-014 Hook fragment**, 20%: the first 2 to 5 notes of Lead 1's last phrase, inverted or
  moved one scale step down, drawn per answer: 2 notes 25%, 3 30%, 4 25%, 5 20%. Lead 1's 16ths
  fold into the 8th grid, so more of its notes are taken until the placed figure has the drawn
  count.
- **MOT-LD2-015 Answer cell**, 25%: a cell paired with Lead 1's rule, reworked once per song as
  homage. The first and last answers play the full cell; the others take a form drawn per answer:
  the full cell 35%, the head alone with its last note held 30%, the cell inverted around the note
  it resolves to 20%, or the cell followed by its head a scale step lower, up to three bars, 15%.
  Every form plays in the full cell's octave, chosen once per song; an inversion that would
  leave the register gives way to the head. Half the songs may drop a middle answer an octave,
  40% of the time, at most twice and never twice running; those songs sit the cell as high as
  MIDI 69 allows, and a drop plays only where it fits above 47. About one Answer cell song in
  seven drops, usually once. The cells:
  - MOT-LD1-023 Hallogallo hook: the pulse tail, flat seventh into the root in 8ths.
  - MOT-LD1-024 Radioactive riff: the vocal line 1 1 1 1 3 2 1, on 8ths.
  - MOT-LD1-025 Model riff: the tail, 2 flat 7 5.
  - MOT-LD1-026 Tour de France riff: the cadence flat 7 flat 3 1, its last note on the beat.
  - Every other Lead 1 rule: a two-bar descent 5 4 3 2 to the root.
- **MOT-LD2-016 Statement harmony**, 15%: one Lead 1 statement in three, a diatonic third below
  in Lead 1's rhythm, from an offset drawn per song. A statement is a body phrase of three notes
  or more. Only Lead 1's 8th-grid onsets are harmonised; a harmony note holds through any 16th in
  between. The harmony sits a third under Lead 1 wherever Lead 1 is, so it may run above 67. In
  the other gaps it plays echo answers.
- **MOT-LD2-017 Low bed**, 10%: the chord's root or fifth held under each Lead 1 note of a beat or
  more, and in any bar of the phrase without one from its first beat for half a bar, MIDI 50 to
  60, starting on a beat. The song's target of 4 to 6 phrases get a bed, spread evenly over the
  body. Consecutive beds on one pitch join into one note up to a bar. Once or twice a song, 50% each,
  the bed also plays alone in one of the longest Lead 1 silences, four bars or more: the chord's
  root or fifth held for one or two bars, starting on a bar line a bar after the phrase before it
  and ending half a bar before Lead 1 returns. Two bars only while the chord stays the same. These
  solo beds are outside the 4 to 6 count. It plays nothing else in the gaps.

### Pools

- Base: 013 takes MOT-LD2-001's slot, 017 takes 002's, 014 takes 003's, 015 takes 004's and 016
  takes 006's. 005's slot is gone. MOT-LD2-001 to 006 sit at the end at 0%.
- Motorik Europe draws the base pool when Lead 2 is not in the sync, which is the Rhythm Section
  group. Sequence Lock and Machine Voice keep MOT-LD2-011 and 012.
- Motorik Arcade's regular pool: 013, 014 and 015 take 001, 003 and 005 at 45, 35 and 20%. The arp
  rules MOT-LD2-007 to 010 and the dense-melody "No lead 2" are drawn as before, from the same
  stream, so those songs are unchanged.
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
  nothing. The 50% bar coin, the forced root fallback and the MOT-LD2-004 swap under Hallogallo
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

- Wins in base: 013 30%, 014 18%, 015 22%, 016 21%, 017 9%.
- Lead 2 onsets inside a Lead 1 phrase: none for 013, 014 and 015; 54% of the harmony rule's
  notes and all of the bed's, by design.
- Odd-step Lead 2 notes: none. Held notes off the beat: none, apart from harmony notes that
  mirror a Lead 1 note held off the beat.
- Appearances per song: 4 to 6 in the body for nearly every song, plus the outro echo; fewer
  only where Lead 1 leaves no room, about 3% of songs.
- Notes per song: 013 about 15, 014 about 13, 015 about 25, 016 about 31, 017 about 10. The old
  base Lead 2 averaged 84.
- Fingerprints against HEAD: Noir, Arcade's arp rules and the Sequence Lock and Machine Voice
  songs are identical on every track.

## Next: phases 4 and 5, Kosmic

### Phase 4: Kosmic Lead 1

Three hook rules replace the three weakest base rules. They share the hook engine; the engine
needs a flag for scale-step degrees for Blade Runner.

- **KOS-LEAD-010 Blade Runner theme**, 14%, takes KOS-LEAD-007 TD Skip Sequence's slot.
- **KOS-LEAD-011 Pulstar theme**, 12%, takes KOS-LEAD-001 Slow Arc's slot.
- **KOS-LEAD-012 Beach Scene sigh**, 7%, takes KOS-LEAD-005 Arpeggio Highlight's slot.
- KOS-LEAD-001, 005 and 007 go to 0% in `pickLeadRule` and come out of the `pickBSectionRule`,
  `pickLeadRuleDifferentFrom` and bridge lists, which would otherwise hand whole-song rules to
  per-bar contexts. KOS-LEAD-001 is also in `sparseLeadRules`, which forces the B section to
  escalate; keep those lists valid for Lead 2 and the bridge melody.
- Kosmic Lead 1 register is 60 to 84, which is claimed, not checked.
- The Kosmic path needs the same filter exemptions as Motorik: a hook lead is softened, not
  thinned or silenced, and gets one octave decision per song. The Kosmic calls are near
  `SongGenerator.swift` lines 684 and 691.
- Kosmic phrases are long, so statements start every 8 or 12 bars, and Blade Runner's 12-bar
  line plays at most twice per A section. How many statements a Kosmic song should have is not
  decided.
- Kept: KOS-LEAD-002 Floating tones, KOS-LEAD-003 Pentatonic drift, KOS-LEAD-006 JMJ Phrase
  Loop, KOS-LEAD-008 Caligari Solo and KOS-LEAD-009 Dark Sun Solo.

### Phase 5: Kosmic Lead 2

Base Kosmic Lead 2 gets its own functions. Do not edit `emitLeadBar` or the bar functions, which
Kosmic Lead 1, Drift Lead 1 and the bridge melody share. Gate on not Space. Drift has no Lead 2.

- **KOS-LD2-002 Slow echo answer**, 35%: as MOT-LD2-013, in long notes.
- **KOS-LD2-003 Slow answer cell**, 40%, paired with Lead 1's rule:
  - KOS-LEAD-010 Blade Runner theme: Lead 1's held last note echoed a diatonic third lower, one
    bar later, held.
  - KOS-LEAD-011 Pulstar theme: the rising riff, 1 2 flat 3 4 5 then 1.
  - KOS-LEAD-012 Beach Scene sigh: the IV and V arpeggio answer landing on the root.
  - Kept Lead 1 rules: the KOS-LEAD-004 two-on, two-off echo cell.
- **KOS-LD2-004 Gap reply melody**, 25%: KOS-LEAD-004's shape re-gridded to start in Lead 1's
  gaps, not on `bar % 8`.
- Register 55 to 67. Silent while Lead 1 plays a phrase. Removed in base: the two-step collision
  shift, the random held-note fill after four silent bars, and the forced B escalation to
  KOS-LEAD-004.
- Kosmic Space calls `pickLeadRule2`, ignores the result, then draws again. Leave that call
  alone, because Space depends on it being one draw. This is from an audit and is not rechecked.

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

State only what is in place in `docs/motorik-plan.md`, `docs/kosmic-plan.md` and
`docs/change-log.md`, with no history of what was tried. Then mark this plan done. The README and
the change log already describe phases 1 and 2.

## Build order and checks

Each phase ends with a macOS and an iOS build and Zack listening before the next phase, and
Zack's approval before the commit.

1. Hook engine and MOT-LD1-023. Done.
2. MOT-LD1-024 to 026 and the base weights. Done.
3. Motorik Lead 2, MOT-LD2-013 to 017. Built, waiting for Zack's ear.
4. Kosmic Lead 1, KOS-LEAD-010 to 012.
5. Kosmic Lead 2, KOS-LD2-002 to 004, and the Space gate.
6. Docs.

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
  other old Lead 2 rules are retired completely.
- MOT-LD1-005 Call and answer is kept in every pool.
- A retired rule is replaced in every substyle that used it.
- Build number 136 in `Version.xcconfig`, since build 135 went to the App Store. Version 2.9 is
  unchanged.

## Open questions

- Should MOT-LD1-024 Radioactive riff keep its off-beat 16ths, or snap its held notes onto beats?
- How many statements should a Kosmic hook song have? Motorik is 3 to 6.
- `DensitySimplifier.thin` is still buggy for Arcade's arp rules and the synced Europe Lead 2.
  The gap-answer Lead 2 is written after it runs, so it never reaches the new rules. Fix the rest
  only if Zack asks.
- KOS-LEAD-004 Echo Melody as a Lead 1 rule is a possible later round.
- Is Zack willing to play or tap a short hook for a La Dusseldorf or Harmonia piece if no file
  exists?
