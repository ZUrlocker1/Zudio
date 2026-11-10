# Solo improvement plan: Motorik and Kosmic Lead 1

Status (2026-11-10): planning finished and approved by Zack. No code has changed yet. The build
specification is the section "Build spec" near the end. Everything above it is the reasoning
and source data it draws on.

## What this is

The newer substyles (Motorik Europe, Chill Soho, Kosmic Space) play leads built from real
transcriptions, and they sound far better than the base styles. Several of the early Lead 1 rules
in base Motorik and base Kosmic pick scale positions by rule of thumb. Nothing is stated,
remembered or brought back, so the line never becomes a tune.

The fix follows the Chill jazz lead rules (CHL-LD1-013 Moanin', CHL-LD1-014 Cantaloupe Island,
CHL-LD1-015 Blue Monk, see `chill-jazz-leads-plan.md`), which raised Chill's musicality
considerably. Each new rule plays a small bank of cells taken from one real piece, mapped to the
song's mode and reworked as homage, never copied. The new rules can be simpler than Cantaloupe or
the Kosmic Space Oxygene leads. The bar is that each one has a hook you could hum.

## Scope

Base Motorik and base Kosmic Lead 1 pools only. These stay unchanged:

- Motorik Noir, which uses MOT-LD1-001 and MOT-LD1-006 at 4% each.
- Motorik Arcade, which uses MOT-LD1-001 at 3% and MOT-LD1-002 at 2%.
- Motorik Europe.
- Kosmic Space and Kosmic Drift.
- Kosmic Lead 2, which draws KOS-LEAD-001 from its own pool.

## Rules to replace (decided by Zack)

### Base Motorik: 52% of the pool

- **MOT-LD1-001 Neu! motif first (15%).** Replays one of a few stored phrases on a 4-bar cycle,
  mutated every 8 or 12 bars, with per-bar note drops. The phrases are generic. Intro and outro
  fall back to random quarter-note picks (`lead1MotifFirst`).
- **MOT-LD1-002 Pentatonic cell (14%).** Builds a random pentatonic cell, then shifts its
  pitches every 4 bars and rebuilds its rhythm every 8, so it never settles into a hook.
- **MOT-LD1-003 Punch solo (11%).** Three or four random neighbouring chord or scale notes and a
  held last note, every 4 to 8 bars. Each burst is new, so it has no identity.
- **MOT-LD1-006 Long arc solo (12%).** Walks the mode one step at a time, turns after four steps,
  and draws a random rhythm per bar. The purest scale exercise in the pool.

Kept: MOT-LD1-004 Stepwise sequence and MOT-LD1-005 Call and answer, which are fixed transcribed
shapes, plus the composed solos MOT-LD1-007 Vanishing solo and MOT-LD1-008 Visiting solo.

### Base Kosmic: 33% of the pool

- **KOS-LEAD-005 Arpeggio Highlight (7%),** added on 2026-11-10. One held downbeat note per bar,
  chosen by a contour formula, with 35% rest bars. No phrase.

- **KOS-LEAD-001 Slow Arc (12%).** Two to four steps from the top or bottom of the scale every
  4 bars, in a random direction.
- **KOS-LEAD-007 TD Skip Sequence (14%, the second-highest weight).** Six to eight consecutive
  scale notes every bar, up or down, with ghost notes. A scale run.

Kept: KOS-LEAD-002 Floating tones and KOS-LEAD-003 Pentatonic drift, which are simple but
harmless. KOS-LEAD-006 JMJ Phrase Loop, KOS-LEAD-008 Caligari Solo and KOS-LEAD-009 Dark Sun
Solo are transcription-based already.

Possible second round: KOS-LEAD-004 Echo Melody. It plays the bottom two scale notes as whole
notes, then the same shifted by a third, so it's close to a drone. Its real share is well above
its 10% weight, because it is the forced B-section rule when the A rule is sparse and in Drift.
It is also wired into Lead 2 and the bridge code, so replacing it carries more risk.

## Sources

Two or three pieces per style. Each base style keeps its own sources, so it doesn't sound like its
substyle.

### Already taken by substyles, so avoid

- Motorik Europe: Kraftwerk's *Autobahn*, *The Robots*, *Computer Love* and *Numbers*.
- Kosmic Space: Jarre's *Oxygene* and *Magnetic Fields*.
- Ambient Zen planning: Eno's *The Pearl* and *Music for Airports*, already in
  `docs/midi-analysis/eno`.

### Motorik shortlist

- **Kraftwerk, *Neon Lights*.** The most melodic Kraftwerk lead that Europe doesn't use. A fan
  MIDI is on MidiShow.
- **Kraftwerk, *The Model*.** A strong, simple hook. MidiShow has two fan MIDIs.
- **Neu!, *Hallogallo*.** No MIDI found, but a tab analysis already exists at
  `docs/midi-analysis/analysis-hallogallo-tab-sections.json`. Rother's guitar lines are sparse, so
  this may suit a sparse rule.
- **La Dusseldorf (*Silver Cloud*, *Viva*), Harmonia (*Deluxe*, *Monza*), Michael Rother solo
  (*Flammende Herzen*).** No MIDI found on any site searched. Still possible through Guitar Pro
  tabs on Ultimate Guitar or Songsterr, which export to MIDI, or through a short hand
  transcription of the hook. Only a few bars are needed.
- Fallback: Kraftwerk's *Trans-Europe Express* or *Tour de France*.

### Kosmic shortlist

- **Vangelis, *Pulstar*.** A bold brass-synth hook over a pulse, which suits Kosmic well. A
  single-track fan MIDI is on MidiShow, and Geerdes sells a professional file.
- **Vangelis, *Alpha*.** A gentle repeating melody that builds through the piece. A multi-track
  fan MIDI is on MidiShow.
- **Vangelis, *Blade Runner* (Love Theme, End Titles, Memories of Green).** Several MidiShow
  versions, plus short files on the BladeZone fan site.
- **Tangerine Dream.** Thin pickings. MidiShow has *Song of the Whale* (*Underwater Sunlight*,
  1986), which needs checking for a usable lead. No MIDI found for *Love on a Real Train*,
  *Stratosfear*, *Rubycon* or *Phaedra*, which are mostly sequencer pieces anyway. *Thief* or
  *Force Majeure* would need a hand transcription.

### MIDI sites

- **MidiShow** (midishow.com/en). The best source found for Kraftwerk, Vangelis and Tangerine
  Dream fan transcriptions. Pages list instrument count, tempo and the uploader's licence claim.
- **BitMidi** (bitmidi.com). Has a search API, and `tools/fetch_jarre_midi.py` and
  `tools/fetch_kraftwerk_midi.py` already use it. Not yet searched for these artists.
- **Geerdes Media** (geerdes.media). Commercial, professionally sequenced files, such as
  *Pulstar*. A paid fallback when a fan file is poor.
- **BladeZone** (bladezone.com). Short Blade Runner theme files.
- **Preset Patch** (presetpatch.com). User uploads, including Kraftwerk and Vangelis files.
- **MuseScore** (musescore.com). Fan scores that export to MIDI, but an account is needed.
- **Ultimate Guitar and Songsterr.** Guitar Pro tabs for Neu! and Rother, the likeliest route to
  krautrock guitar lines.

Licensing: fan uploads often claim CC0, but the compositions are under copyright. As with every
corpus rule in Zudio, we take short cells, scale-map them to the song's mode and rework them as
homage, and never ship a recognisable copy.

## How the new rules work

The same pattern as the Chill jazz rules:

- **A cell bank per source.** Pull three to six cells from the MIDI with a `tools/` analysis
  script and write them as scale degrees on a 16th-step grid: one hook, two or three answers or
  tails, and optionally a cadence figure.
- **Mode mapping.** Sources are scale-mapped to the song's mode and never rejected for being major
  or minor. A cell moves to the chord root in the octave nearest a per-song anchor where the whole
  cell fits the register, then notes outside the scale or chord move to the nearest allowed note.
  Each figure stays in one octave.
- **Form.** State the hook, then vary it on return (dropped note, octave shift, changed ending,
  rhythmic displacement), and play it plain once more in the last fifth of the song. The song
  seed picks the cell order and a few per-song details, so two songs on the same rule differ.
- **Synth phrasing.** Hold notes to the next onset on synth leads, since short transcribed notes
  sound clunky there.
- **Existing machinery stays.** Entry delay, rest windows (`buildRestBars`), A/B rule draw and
  arrangement filtering all run as before. Each new rule only replaces how a phrase is built.

### Naming and IDs

- New IDs, appended: MOT-LD1-023 onward and KOS-LEAD-010 onward. Each rule is named for its source
  work, such as "Neon Lights hook" or "Pulstar theme". One ID has one log name everywhere, with no
  parentheses in log lines.
- Each new rule takes over the weight of a rule it replaces. The old rules stay in the code at 0%
  weight in the base pool, so restoring one is a one-line change.

### Wiring to handle

- **Motorik.** MOT-LD1-003 forces the B section to MOT-LD1-001 (60%) or MOT-LD1-004 (40%). Once
  both are retired from the base pool, that forcing needs new targets. The intro and outro of
  MOT-LD1-007 and MOT-LD1-008 use `lead1MotifFirst` and are untouched.
- **Kosmic.** KOS-LEAD-001 is in `sparseLeadRules`, which forces the B section to escalate, and in
  the `pickBSectionRule` and `pickLeadRuleDifferentFrom` lists. Retiring it from Lead 1 must leave
  those lists valid for Lead 2 and for the bridge melody.
- New draws come from derived RNG streams so other tracks keep their output.
  `SeededRNG.weightedPick` does not normalise, so weights must sum to 1.

## Fetched so far

`tools/fetch_solo_midi.py` searches BitMidi and saves to `~/Downloads/solo-improvement-midi`,
outside the repo. Those files are not to be committed. On disk:

- **Motorik:** Kraftwerk *The Model*, two versions. The first has tracks "lead", "solo synth" and
  "VocalVibes", the vocal melody. Zack added *Radioactivity* and *Tour de France* by hand. Also
  the two Hallogallo reference files described below.
- **Kosmic:** Vangelis *Pulstar*, a single-track file whose likely lead is channel 8, synth brass
  in MIDI 65–89. Vangelis *Blade Runner*, an 11.5-minute file that is probably the End Titles.
  Vangelis *Chariots of Fire*, an extra.

BitMidi has nothing for *Neon Lights*, *Trans-Europe Express*, *Tour de France*, Neu!,
La Dusseldorf, Harmonia, Rother, *Alpha* or any Tangerine Dream piece. *Neon Lights*, *Alpha*
and *Song of the Whale* are on MidiShow, which needs a login, so they are fetched by hand.

## Candidate: Hallogallo hook (Motorik)

Status: chosen by Zack on 2026-11-10, not yet built. ID MOT-LD1-023, log name
"Hallogallo hook". It replaces MOT-LD1-001 Neu! motif first and takes its 15% of the base pool.
Build it from `hallogallo-lead1-sketch.mid`, not from the literal tab. Zack judged the sketch
solid apart from the octave jump in bar 25, which is dropped.

### Source

Neu!, *Hallogallo* (1972), from a fan guitar tab Zack supplied on 2026-11-10. The piece is a
one-chord vamp in E. The tab has three parts.

- **Riff 1 (Guitar 1).** Fret 7 on the A string, which is E3 (MIDI 52), in 16ths. "X" marks a
  muted ghost hit. The bar's sixteen slots, with dots for sounding notes:
  `E E E x E E E x E E E E . E E E`, so notes on slots 0–2, 4–6, 8–11 and 13–15, mutes on 3 and
  7, and slot 12 empty.
- **Riff 1 variation.** The same, except slots 0, 4 and 8 play fret 5, which is D3 (MIDI 50). The
  flat-seventh grace note lands on each beat and resolves to the root.
- **Guitar 2 riff,** heard a few times through the song. D string fret 7 is A3 (57), fret 9 is
  B3 (59). G string fret 11 is F#4 (66), fret 9 is E4 (64). Reading the tab columns as 16ths from
  the first note:
  - Call: A3 at step 0, B3 at 2, F#4 at 4, F#4 at 7. As degrees of E: 4, 5, 9, 9. It ends open,
    on the ninth.
  - Answer: A3 at step 17, B3 at 19, E4 at 21, E4 at 23. Degrees 4, 5, 8, 8. It ends home, on
    the root an octave up.
  - The answer starts one 16th after the bar line. That may be loose tab spacing or a real push.
    The literal MIDI keeps it, and the sketch treats it as an optional variation.

### Already in Zudio

- **The Guitar 2 riff is MOT-LD2-004 Hallogallo Motif Counter** (Lead 2, `lead2HallogalloCounter`
  in `LeadGenerator.swift`). It uses offsets 5, 7, 2, 2, 5, 7, 0, 0 from the song tonic, which
  confirms the reading above. Each note fires independently 38% of the time as a one-step blip,
  so the hook is never heard whole. The new rule states it whole, as a melody.
- **Riff 1 is already in the Motorik Rhythm data,** from Guitar 1 in
  `docs/midi-analysis/analysis-hallogallo-tab-sections.json`.
- **MOT-LD1-005 Call and answer** cites "Hallogallo analysis", but its shape (1, 2, b3, 5 then
  4, b3) is not this riff.

### Reference MIDI

Saved outside the repo in `~/Downloads/solo-improvement-midi/motorik/`, at 140 BPM in E. The
script that wrote them is not kept; this section holds all the data.

- **`hallogallo-tab-literal.mid`.** Riff 1 for four bars, the variation for four, then riff 1 for
  eight bars with the Guitar 2 riff over it every second bar.
- **`hallogallo-lead1-sketch.mid`.** The proposed rule over E2 bass 8ths and a plain motorik beat,
  32 bars, using the cells and form below.

### Cells

Written as semitones from the song tonic. One bar each on the 16-step grid, with onsets at steps
0, 2, 4 and 7. On synth leads each note holds to the next onset, and the last note holds to about
step 15.

- **Call:** 5, 7, 14, 14 (4, 5, 9, 9). Velocities 84, 80, 88, 82.
- **Answer:** 5, 7, 12, 12 (4, 5, root, root).
- **Answer ending on the fifth:** 5, 7, 7, 7. Used to avoid resolving every time.
- **Call a step up:** each note moved up one scale step: 7, 9, 16, 16 in major, or the minor
  equivalent after snapping. A homage transformation, not in the tab.
- **Pulse tail, from the riff 1 variation:** flat seventh into root, root, in 8ths, twice per bar,
  soft (velocity 56–66). Steps 0, 2, 4 and 8, 10, 12. It fills the bars after a statement so the
  call and response has a reply that isn't another hook.

### Form

The unit is a four-bar statement: call bar, answer bar, then two bars of silence or the pulse
tail. The sketch lays it out like this:

- Bars 1–4: the groove only, matching Lead 1's entry delay.
- Statement 1, bars 5–6: plain.
- Statement 2, bars 9–10: plain, then the pulse tail in bar 11.
- Statement 3, bars 13–14: the call drops its second note; the answer ends on the fifth.
- Statement 4, bars 17–19: call, call a step up, answer. Three bars, a sequence.
- Statement 5, bars 21–22: both halves pushed one 16th late, as in the tab.
- Statement 6, bars 25–26: the held ninth jumps up an octave on its repeat (F#4 to F#5).
  Rejected by ear; the rule does not use it.
- Last statement, bars 29–30: plain, with the root ringing to the end of bar 32.

In the rule itself:

- **The first two statements are always plain,** so the hook gets learned before it changes.
- **Later statements draw one or two variations** from: drop one note (the second or third), answer
  ends on the fifth, call a step up (as a three-bar sequence), push by one 16th, call alone with the answer withheld (rare, leaves the question open).
- **Statement spacing:** every 8 bars by default, sometimes 4 (back to back) or 12. The gaps take
  silence or the pulse tail, about 30% pulse.
- **The last fifth of the song plays the plain call and answer once.**
- **Intro silent; outro may play one soft plain statement.** `buildRestBars` rest windows still
  apply on top.

### Fitting to the song

- **Anchor to the song tonic,** as MOT-LD2-004 does. Hallogallo is a vamp, and Motorik's chord
  changes are slow. Then snap each note to the scale with `nearestScalePitchClass`.
- **Mode check across the Motorik scale pool** (Aeolian, Dorian, Mixolydian, Ionian, minor and
  major pentatonic): the 4, 5, 9 and root exist in the four modes. In minor pentatonic the ninth
  snaps to the root or flat third. In major pentatonic the fourth snaps to the third or fifth.
  Those are acceptable, because the rhythm and contour carry the hook.
- **Held notes only:** if the held ninth or root is an avoid note against the current chord, as
  given by `NotePoolBuilder`, move it to the nearest chord tone. Passing notes keep their pitch.
- **Register:** Lead 1 is MIDI 52–79. The hook spans 57–66 untransposed. Anchor each statement so the whole cell fits in one octave band. Never re-anchor
  mid-statement.

### Wiring for the build

- **Coordinate with Lead 2.** When Lead 1 is MOT-LD1-023, Lead 2 should not draw MOT-LD2-004,
  because two versions of the same riff, one whole and one scattered, would blur each other.
- **New draws come from a derived RNG stream,** so other tracks keep their output.
- **Log description:** add "Hallogallo hook" to `lead1RuleDescription` in `SongGenerator.swift`.

## Candidates from the source MIDI

Zack flagged six files as strong on 2026-11-10: *Tour de France*, *Radioactivity*, *The Model 2*,
*Beach Scene*, *Blade Runner* and *Pulstar*. *Chariots of Fire* is rejected as too familiar. The
phrases below were found with a phrase miner, which splits a track at rests and ranks shapes that
recur, and by reading bar dumps.

**What these rules are.** Short melodic phrases that are stated, shifted, varied and then return
in their original form. They are not long fluid solos like Kosmic Space. Long or short notes,
whichever suits the genre.

**Audition excerpts.** `~/Downloads/solo-improvement-midi/excerpts/` holds each phrase cut from its
source track at the source tempo. The file names start M1–M5 for Motorik and K1–K4 for Kosmic, as
below.

**Notation.** Cells are in semitones from the phrase's tonic on a 16-step bar. "@n" is the onset
step and "/n" the length in steps. Negative steps are pickups before the bar line. At build time
everything is scale-mapped to the song's mode, so major and minor sources both work. A source's
major or minor third becomes the song's third.

### Motorik: three more rules, for the slots of MOT-LD1-002, MOT-LD1-003 and MOT-LD1-006

With Hallogallo these make four new rules for the four retired slots. Weights are a later decision.

**M1, Kraftwerk *Radioactivity*: key-synth riff.** Track "Key Synthesizer", bars 20–35 and 73–81.
It is the strongest hook found: one bar, 15 statements in the file.
- Cell: pickup -5@-1, then 0@0/2, 0@2, -5@3, 0@4, -5@5/2, 0@7, 4@8/2, 2@10, 0@11/4. That is 5 | 1 1 5 1 5 1 3 2 1. It
  rocks between the root and the fifth below, then turns through 3–2–1.
- In the source it alternates every two bars between A minor and F major, which is the same shape
  a third lower. In Zudio: state it on the tonic, restate it a diatonic third down, then return.
- **M2, the vocal line, is answer material** (track "Ralf Hutter", bars 74–84): 0@0, 0@2, 0@4/3,
  0@7, 4@8/2, 2@10, 0@11/2, so 1 1 1 1 3 2 1. It works as a Lead 2 reply, or as a Lead 1 variation
  with the root pulse in place of the fifth-rocking.

**M3, Kraftwerk *The Model*: synth riff.** Track "Synth 2", bars 9–12, two bars, in A minor.
- Cell: bar 1 0@0/10, 3@10, 2@12, 0@14 | bar 2 2@0/6, -2@6, -5@8/6, -5@14. That is 1 (held) b3 2 1 |
  2 b7 5 5. The held first note gives it the Motorik long-note feel.
- **M4, the vocal line** (track "Voice", bars 12–22) is the same contour with a repeated-note
  start: pickup -5@-2, 0@0, 0@2, 0@4, 0@6, 0@8, 3@10, 2@12, 0@14 | 2@0/6, -2@6, -5@8/6. Use it as
  the restatement, so the riff and the vocal alternate the way the record does.
- The tail 2 b7 5 is a natural Lead 2 echo.
- Track "Synth 1" (A–C and E–G alternation) is an accompaniment figure, not a lead. Not used.

**M5, Kraftwerk *Tour de France*: guitar theme.** Track "guitar", bars 13–16 and 29–32, in B.
- Three bars: -5@0/4, 0@4, 2@6, 7@8/6 | 4@14, 7@16, 9@18, 2@20, 4@22, 7@24/4, 0@28 | -2@32/4,
  3@36, 0@38/8. That is 5 1 2 5 | 3 5 6 2 3 5 1 | b7 b3 1.
- Bar 1 (5–1–2–5, rising) is the call. Bars 2–3 are the answer. The source mixes a major third
  (bar 2) with a flat third and flat seventh (bar 3); scale mapping settles both into the song's
  mode.
- The longest of the Motorik candidates. Statement every 8 bars at most.

### Kosmic: two or three rules, for the slots of KOS-LEAD-001 and KOS-LEAD-007

Three candidates for two slots. The third could take KOS-LEAD-005 Arpeggio Highlight (7%), another
weak rule that plays one contour-driven held note per bar. That decision is Zack's.

**K1, Vangelis *Blade Runner*: End Titles theme.** Track 4 (ch 11, synth strings), bars 13–26.
Long notes; the best fit for Kosmic's slow tempo.
- A four-bar unit: whole note, two half notes, a two-bar hold, each note a scale step lower. Then
  it is sequenced down one scale step, twice.
  - Phrase 1: C/16 | Bb/8 Ab/8 | G/32. Scale steps 0, -1, -2, -3 from the start.
  - Phrase 2 starts a step lower: Bb | A G | F.
  - Phrase 3 starts lower again: Ab | G F | C/24, then Eb/8 into a long low C. It breaks the
    sequence and drops to the tonic, so it works as the cadence.
- Store it as scale steps, not semitones. The rule picks a start degree so the whole 12-bar line
  fits the register.

**K2, Vangelis *Pulstar*: brass theme.** Channel 8, bars 119–134.
- Pickup: 4@8, 4@10, 4@12, 5@14 into 1 on the bar. Then four whole notes, one per bar: 0, -2, -7,
  -5. That is 1 b7 4 5. Repeated an octave up.
- Variation by register (low then high), by dropping the pickup, or by holding the last note
  across two bars.
- **K3, the rising riff** (channel 3, bars 8–40, 15 statements): a 16th-note pickup run, 0@13,
  2@14, 3@15, 5@16/2, 7@18, then 0@19. That is 1 2 b3 4 5 and down to 1, landing on the bar.
  Also stated a third higher. Too busy for Lead 1 but ideal as a short Lead 2 answer between the
  theme's long notes.

**K4, Tangerine Dream *Beach Scene*: guitar sigh with arpeggio answer.** Track "Distortion
Guitar", bars 51–66, in A.
- Call, two bars: 0@0/2, -1@2/4, -1@6/6, -1@12/4 | -1@0/4, -3@4/28. The root slips to the
  seventh, repeats, and sinks to the sixth, held. A sigh.
- Answer, two bars: rising arpeggios on IV and V landing on the root. -12@0, -7@2, -3@4/4,
  -10@8, -5@10, -1@12/4 | 0@0/12. Bar 65's version is used because it stays inside MIDI 52–79.
- Variant call (bar 63): the repeats fall to the fifth (-5) before rising to the sixth.
- One source supplies call and response, and could serve Lead 1 and Lead 2 together.

## Lead 2: coordination with Lead 1

Zack's complaint: in base Motorik and base Kosmic the two leads overlap and are unrelated, so
Lead 2 steps on Lead 1. The goal is call and response. Lead 1 states a phrase, and Lead 2 answers
in the gap with something related, or at least a small phrase of its own. Rewriting Lead 2 rules
and thinning is in scope. An audit of both generators on 2026-11-10 found the following.

### Why they collide

- **Lead 2 plays during Lead 1's phrases.** In Motorik, Lead 2 rests in a bar where Lead 1 plays
  only on a 50% coin flip (`LeadGenerator.generateLead2`, the "Bar-level silencing" block).
  MOT-LD2-006 skips even that. In Kosmic there is no gating at all, so Lead 2 plays every body bar.
- **Unrelated pitch material.** Most Lead 2 rules pick random chord or scale notes. Only
  MOT-LD2-006 uses Lead 1's pitches.
- **Same register.** Motorik Lead 1 is MIDI 52–79 and Lead 2 is 55–81, and `nearestMIDI` centres
  both near 68. Kosmic Lead 2 is 55–80 against Lead 1's 60–84, except in low-intensity sections.
- **Collision handling makes flams.** Kosmic moves a Lead 2 attack that lands on a Lead 1 step two
  steps later, so it still overlaps.
- **Lead 2 answers calls that were cut.** Lead 2 is generated against Lead 1 before
  `ArrangementFilter` and the breakdowns remove Lead 1 notes.
- **The Motorik density guard does nothing.** `DensitySimplifier.thin` keeps an event while its
  index in the window, mod 100, is under the keep rate. Any window with fewer than 35 or 55 Lead 2
  events, which is nearly all of them, is untouched. A busier one loses its tail instead of being
  thinned evenly. This is a bug. It is not fixed yet, because fixing it would start thinning Lead 2
  in every Motorik song, Europe and Arcade included. It is called only from the Motorik path
  (`SongGenerator.swift:312`).
- **Specified but never built.** `motorik-plan.md` describes Lead 2 entering after Lead 1, role
  handoff and doubling windows. Kosmic's KOS-SYNC-004 asks for under 30% overlap. None of this is
  enforced.

### Rule verdicts

Motorik base Lead 2:

- MOT-LD2-001 Counter-response (20%): random chord tones on the off-beat 8ths. **Replace.**
- MOT-LD2-002 Sustained Drone (20%): root or fifth held 8–16 steps in about a fifth of bars, near
  MIDI 68, inside Lead 1's band. **Rework:** move it lower, as a bed under the hook.
- MOT-LD2-003 Rhythmic Counter (10%): random two-step scale notes. **Replace.**
- MOT-LD2-004 Neu! counter melody (10%): the Hallogallo riff as scattered blips. **Rework** into a
  whole-cell answer, and keep it out of songs where Lead 1 is MOT-LD1-023.
- MOT-LD2-005 Descending line (20%): two tonic-anchored notes a bar on an 8-bar descent, in about
  80% of bars. **Rework:** its two-bar descent becomes a gap answer.
- MOT-LD2-006 Neu! harmony (20%): Lead 1's rhythm a diatonic third below or a fourth above, on a
  random 55% of its notes. It doubles and never responds, and the random 55% sounds like dropouts.
  **Rework:** harmonise whole statements, about one statement in three.
- MOT-LD2-007 to MOT-LD2-010 are Arcade only and out of scope.

Kosmic base Lead 2 reuses Lead 1's bar functions through `emitLeadBar`:

- KOS-LEAD-001 Slow arc (15%): a scale walk. **Replace.**
- KOS-LEAD-002 Floating tones (30%, the most common): its fire interval is redrawn every bar, so
  random held notes land anywhere in MIDI 55–80, across Lead 1's phrases. **Replace.**
- KOS-LEAD-003 Pentatonic drift (20%): a deterministic two-note figure, but it builds its own range
  of 60–84, Lead 1's band. **Rework:** gaps only, lower.
- KOS-LEAD-004 Echo melody (25%, and the forced B rule after 001–003): two on, two off, which suits
  call and response, but its grid is fixed to `bar % 8` and ignores Lead 1. **Rework:** align it to
  Lead 1's gaps.
- KOS-LEAD-005 Arpeggio highlight (10%): one held downbeat note in 65% of bars, always colliding
  with Lead 1's step 0. **Replace.**

### Proposed design, base Motorik and base Kosmic only

- **Phrase map from Lead 1's events.** Group Lead 1 onsets that sit less than 8 steps apart into
  phrases. Run it after `ArrangementFilter` and the breakdowns, so Lead 2 only answers calls that
  survived, and regen agrees with first generation. It works for new and kept Lead 1 rules alike.
- **Silent while Lead 1 plays,** through each phrase plus a 2–4 step tail.
- **Answer in the gap.** In 60–75% of gaps of one bar or more, Lead 2 plays one answer of at most
  two bars, ending at least two steps before Lead 1 returns. Each song picks one kind of answer:
  - an echo of Lead 1's last 2–4 notes in the same rhythm, a diatonic third, sixth or octave lower;
  - a fragment of the hook, inverted or sequenced;
  - or a short cell of Lead 2's own that comes back in every gap.
- **Answer cells from the sources:**
  - Radioactivity vocal: 1 1 1 1 3 2 1.
  - The Model tail: 2 b7 5.
  - Hallogallo pulse tail: b7 into the root.
  - The reworked MOT-LD2-005 descent.
  - Pulstar rising riff: 1 2 b3 4 5, landing on 1.
  - Beach Scene arpeggio: IV, V, then the root.
  - Kosmic Echo melody, re-gridded to Lead 1's gaps.
- **Handoff.** In Lead 1 rest windows of four bars or more (`buildRestBars`), Lead 2 states its
  own cell once or twice.
- **Doubling, rarely.** The reworked MOT-LD2-006 harmonises a whole statement, about one in three.
- **Register below Lead 1.** About MIDI 50–67 for Motorik and 55–67 for Kosmic at all intensities.
  Pass it through `registerOverrides` (`HarmonicFilter.swift:35`) so Pass B can't lift it back.
- **Remove in base:**
  - Motorik: the 50% coin and the forced root-note fallback after four silent bars.
  - Kosmic: the two-step collision shift, the random held-note fill after four silent bars, and
    the forced B escalation to KOS-LEAD-004.
- **Kosmic code.** New Lead 2 rules get their own functions. Don't edit `emitLeadBar` or the bar
  functions: Kosmic Lead 1, Drift Lead 1 and the bridge melody share them.

### Protecting the other substyles

- **Motorik Europe** songs run base `generateLead2` when Lead 2 isn't in the sync group. Gate the
  new behaviour on no sync; this needs a new parameter.
- **Arcade** shares the bar loop. Gate on not Arcade.
- **Noir** never calls Lead 2.
- **Kosmic Space** runs KOS-LEAD-004 through the same loop in about a third of its songs. Gate on
  not Space.
- **Kosmic Drift** has no Lead 2.

### RNG notes

- Kosmic Space depends on `pickLeadRule2` being exactly one draw. Put new draws after it, or on a
  derived stream (as `spaceHoldBDensity` does at `SongGenerator.swift:600`).
- In Motorik the 50% coin draws only in bars where Lead 1 plays, so the new Lead 1 rules reshuffle
  Lead 2 anyway. Keep the rule pick as one draw, with Arcade's extra draw after it.
- Moving Lead 2 later in the pipeline is safe, because it has its own stream. Changing which tracks
  `ArrangementFilter` treats as subjects is not, because that shifts the filter's draws for Lead 1,
  Rhythm and Pads.

## Build spec

The sections above hold the source cells and the reasoning. This section says what to build.

### New rule IDs and weights

All IDs are appended; none is reused. Retired rules stay in the code at 0% in the base pool, so
restoring one is a one-line change. Weights must sum to 1, because `SeededRNG.weightedPick` does
not normalise.

**Base Motorik Lead 1** (`pickLd1Rule`, base branch). Noir and Arcade pools are untouched.

- MOT-LD1-023 "Hallogallo hook": 15%, taking MOT-LD1-001's share.
- MOT-LD1-024 "Radioactivity riff": 14%, taking MOT-LD1-002's share. Strongest hook, biggest share.
- MOT-LD1-025 "The Model riff": 12%, taking MOT-LD1-006's share.
- MOT-LD1-026 "Tour de France theme": 11%, taking MOT-LD1-003's share. Longest phrase, smallest share.
- MOT-LD1-001, 002, 003 and 006 go to 0% in the base pool. MOT-LD1-004, 005, 007 and 008 keep
  their weights. Because 003 can no longer win the A draw, its B-section forcing never fires; leave
  it in place.

**Base Kosmic Lead 1** (`pickLeadRule`).

- KOS-LEAD-010 "Blade Runner theme": 14%, taking KOS-LEAD-007's share. Long notes suit Kosmic
  best, so it gets the biggest slot.
- KOS-LEAD-011 "Pulstar theme": 12%, taking KOS-LEAD-001's share.
- KOS-LEAD-012 "Beach Scene sigh": 7%, taking KOS-LEAD-005's share.
- KOS-LEAD-001, 005 and 007 go to 0% in `pickLeadRule`. Leave them in `pickBSectionRule`,
  `pickLeadRuleDifferentFrom` and the bridge melody lists, which serve old A rules and the bridge.
  Base Lead 2 no longer uses `pickLeadRule2`'s result (see below), so their Lead 2 use ends there.

**Log descriptions:** add each name above to `lead1RuleDescription` and the Kosmic equivalent in
`SongGenerator.swift`. No parentheses, no French accents.

### Lead 1: one hook engine, seven data sets

All seven new rules share one engine and differ only in data. Put it in a new file,
`Sources/Zudio/Generation/HookLeadEngine.swift`, so neither `LeadGenerator.swift` (3,800 lines)
nor `CosmicLeadGenerator.swift` grows much.

**Data per rule:**

- A **hook**: the call, one to four bars, as (step, degree, length, velocity) on the 16-step grid.
  Degrees are semitones from the tonic, or scale steps for Blade Runner.
- An **answer**: what completes the call. For Hallogallo it's a separate bar; for Blade Runner the
  next sequence step; for Pulstar the second half of the four whole notes.
- A **variant bank**, from the source: answer ending on the fifth (Hallogallo), restatement a third
  down (Radioactivity), vocal version (The Model), alternate call (Beach Scene, bar 63), and so on.
- An optional **tail cell** for the bars after a statement: Hallogallo's pulse tail.
- A **cadence**, used for the final statement: Blade Runner's phrase 3; the plain hook elsewhere.

**Generic variations**, applied after the first two statements, one or two per statement:

- drop one note, never the first or the held last note;
- push the statement one 16th late;
- move the call up one scale step as a sequence;
- hold the last note over the next bar;
- withhold the answer (rare, 10%).

The source-specific variants above come first: about half of varied statements use one.

**Form:**

- The entry delay is the existing Lead 1 one: 8 or 16 bars into A for Motorik, and Kosmic's own.
- Statements start every 8 bars, sometimes 4 or 12. Kosmic rules use 8 or 12 only, because their
  phrases are long. Blade Runner's three-phrase line is 12 bars, so it plays at most twice per A
  section with long gaps.
- The first two statements are plain. The last fifth of the song plays one plain statement, then
  the cadence.
- B sections restate the hook a diatonic step or third up, or use the variant bank more.
- Intro silent. Outro: at most one soft plain statement.
- `buildRestBars` rest windows apply on top in Motorik; Kosmic has its own rest machinery.
- Each new rule generates the whole song in one call and returns early, as KOS-LEAD-008, KOS-LEAD-009
  and the Motorik Europe rules do. The A/B pick is still drawn for RNG continuity, but the new rule
  owns both sections. This keeps the engine out of the per-bar loops.

**Fitting**, as described in the Hallogallo section:

- anchor to the song tonic;
- snap to the scale with `nearestScalePitchClass`;
- move only held notes onto chord tones when they clash (`NotePoolBuilder`);
- choose an anchor octave once per statement so the whole cell fits the register, never
  re-anchoring mid-statement;
- on synth leads, hold each note to the next onset;
- registers: Motorik Lead 1 MIDI 52–79, Kosmic Lead 1 60–84.

**RNG:** new draws come from a derived stream (`rng.next() ^ constant`, as
`spaceHoldBDensity` does), so other tracks keep their output.

### Lead 2: the gap-answer design

Base Motorik and base Kosmic Lead 2 are rebuilt around Lead 1's phrases. The old Lead 2 rules
and loops stay for the protected substyles: Motorik Europe (when Lead 2 isn't in sync), Arcade
and Kosmic Space.

**When it runs:** after `ArrangementFilter` and the Motorik breakdowns, so Lead 2 only answers
calls that survived. The regen paths (`SongGenerator.swift` around 1745 and 1776) call the same
function with the filtered Lead 1, so regen and first generation agree. Base songs change
completely anyway with the new Lead 1 rules; the protected substyles keep the old call order.

**Phrase map:** group Lead 1 onsets into phrases wherever the gap between one note's end and the
next onset is under 8 steps. A gap is the space from one phrase's end to the next phrase's start.

**New rule IDs** (one is drawn per song; weights sum to 1):

- Base Motorik:
  - MOT-LD2-013 "Echo answer", 30%: Lead 1's last 2–4 notes, same rhythm, a diatonic third,
    sixth or octave lower. Choose once per song.
  - MOT-LD2-014 "Hook fragment", 20%: the first 2–3 notes of Lead 1's last phrase, inverted or
    moved one scale step down.
  - MOT-LD2-015 "Own cell", 25%: a cell paired with Lead 1's rule, restated in every answer:
    - MOT-LD1-023 Hallogallo: the pulse tail, b7 into the root.
    - MOT-LD1-024 Radioactivity: the vocal line, 1 1 1 1 3 2 1.
    - MOT-LD1-025 The Model: the tail, 2 b7 5.
    - MOT-LD1-026 Tour de France: the cadence, b7 b3 1.
    - Kept old rules (MOT-LD1-004, 005, 007, 008): MOT-LD2-005's two-bar descent.
  - MOT-LD2-016 "Statement harmony", 15%: harmonises one whole Lead 1 statement in three, a
    diatonic third below, the rule MOT-LD2-006 meant to be. In other gaps it plays an echo answer.
  - MOT-LD2-017 "Low bed", 10%: root or fifth held under Lead 1's long notes, MIDI 50–60, in at
    most half the phrases. The one rule allowed to sound with Lead 1, because it isn't melodic.
- Base Kosmic:
  - KOS-LD2-002 "Echo answer", 35%: as MOT-LD2-013, in long notes.
  - KOS-LD2-003 "Own cell", 40%, paired with Lead 1's rule:
    - KOS-LEAD-010 Blade Runner: Lead 1's held last note echoed a diatonic third lower, one bar
      later, held.
    - KOS-LEAD-011 Pulstar: the rising riff, 1 2 b3 4 5 then 1.
    - KOS-LEAD-012 Beach Scene: the IV–V arpeggio answer landing on the root.
    - Kept old rules: the KOS-LEAD-004 two-on, two-off echo cell.
  - KOS-LD2-004 "Gap echo melody", 25%: KOS-LEAD-004's shape re-gridded to start in Lead 1's
    gaps, not on `bar % 8`.

**Shared rules for every answer:**

- Silent while Lead 1 plays a phrase, plus a 2–4 step tail. MOT-LD2-016's harmony and
  MOT-LD2-017's bed are the only exceptions.
- Answer only in gaps of one bar or more, in a share of gaps drawn once per song between 60% and
  75%.
- An answer is at most two bars, and ends at least two steps before Lead 1's next phrase.
- Handoff: in Lead 1 rest windows of four bars or more, Lead 2 states its cell once or twice.
- Silent in the intro. In the outro, at most one echo of the final statement.
- Register below Lead 1: Motorik MIDI 50–67, Kosmic 55–67, passed through `registerOverrides`
  (`HarmonicFilter.swift:35`) so Pass B can't lift it back.

**Removed in base** (kept for the protected substyles):

- Motorik: the 50% bar coin, the forced root fallback after four silent bars, and the Lead 2
  branch of `DensitySimplifier`. That branch is unnecessary for a gap-only Lead 2 and buggy (see
  "Why they collide").
- Kosmic: the two-step collision shift, the random held-note fill after four silent bars, and the
  forced B escalation to KOS-LEAD-004.

**Gates**, so the protected substyles don't change:

- Motorik: new path only when `motorikSync == .none`, not Arcade, not Noir. `generateLead2` needs a
  sync parameter for this.
- Kosmic: new path only when not Space; Drift has no Lead 2.
- Kosmic Space depends on `pickLeadRule2` being exactly one draw. Leave Space's call untouched.

**Log descriptions:** add each new name to `lead2RuleDescription` in `SongGenerator.swift`.

## Build order

Each phase ends with a macOS and an iOS build, and Zack listening before the next phase.

1. **Hook engine + Hallogallo** (MOT-LD1-023). The approved sketch is the reference for the sound.
2. **Remaining Motorik Lead 1 rules** (MOT-LD1-024 to 026), and the base weights.
3. **Motorik Lead 2** (MOT-LD2-013 to 017), the phrase map, the post-filter call site, regen, and
   removing the coin, fallback and density branch in base.
4. **Kosmic Lead 1** (KOS-LEAD-010 to 012) and weights.
5. **Kosmic Lead 2** (KOS-LD2-002 to 004) and the Space gate.
6. **Docs:** state only what is in place in `motorik-plan.md`, `kosmic-plan.md` and
   `change-log.md`, with no history of what was tried. Then mark this plan done.

**Checks, kept light:**

- Builds: macOS and iOS each phase.
- One temporary `swift test --filter` measurement per style, deleted before commit: the share of
  Lead 2 onsets inside a Lead 1 phrase (target near zero, apart from the harmony and bed rules),
  and how often each new rule wins.
- A fingerprint check (`tools/fpcheck.sh`) only to confirm that Noir, Arcade, Europe, Space and
  Drift are unchanged. Run it with `SWIFT_DETERMINISTIC_HASHING=1`.
- No `xcodebuild test` and no `run_loop.sh` unless Zack asks.

## Decisions (2026-11-10)

- All five excerpts Zack heard "sound good". Motorik takes Hallogallo, Radioactivity, The Model
  and Tour de France.
- Kosmic takes all three candidates: Blade Runner, Pulstar and Beach Scene replace KOS-LEAD-001,
  KOS-LEAD-007 and KOS-LEAD-005. Claude chose the slots, as Zack asked.
- Base Lead 2 in both styles is replaced by the gap-answer design.

## Open questions

- `DensitySimplifier.thin` is still buggy for Europe and Arcade. Fix it only if Zack asks.
- KOS-LEAD-004 Echo Melody as a Lead 1 rule: a possible later round.
- Hand transcription: is Zack willing to play or tap a short hook for a La Dusseldorf or Harmonia
  piece if no file exists?
