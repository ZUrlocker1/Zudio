# Chill Blues Variation Plan

## Overview

A blues variation that appears in approximately 20% of Chill songs, adding a darker,
more organic groove feel. The effect is subtle — it sounds like a Chill song that drifted
toward late-night slow blues rather than a genre change. The variation is defined by two
new drum rules and three new bass patterns. All other track rules (pads,
leads, rhythm, Lead 2) are reweighted but unchanged in structure and work naturally
against the blues bed.

**Key insight from analyzing B.B. King "The Thrill Is Gone":** The blues groove feel comes
entirely from *pattern structure*, not from swing quantization. Every note in that song lands
on the straight 16th-note grid. No timing system changes are required. This keeps
implementation scope minimal.

---

## Activation

- Probability: ~20% of Chill songs activate the blues variation at frame generation time
- A `bluesVariation: Bool` flag is set in `ChillMusicalFrame` (or equivalent song frame)
- When active, the drum generator routes to CHL-DRUM-006 (Intro, Groove A, Breakdown, Outro)
  and CHL-DRUM-007 (Groove B only) instead of CHL-DRUM-001 through 005
- When active, the bass generator may select blues-specific patterns (see below)
- BPM is weighted toward 75–92 BPM when blues is active (the existing Chill BPM range
  already covers this, so this is a soft weight, not a hard constraint)
- Blues variation is incompatible with St Germain beat style and Hip-Hop Jazz beat style;
  the `bluesVariation` flag is decided first in frame generation, then beat style selection
  excludes .stGermain and .hipHopJazz when the flag is true (rather than clearing the flag
  after the fact)
- Blues variation always forces Dorian mode: the Im7 / IVm7 / V7 chord structure is diatonic
  to Dorian and produces wrong chord qualities in Mixolydian, Ionian, or Aeolian. When
  `bluesVariation` is true, skip the normal mode pick and set mode = .Dorian.

---

## CHL-DRUM-006 — Blues Side-Stick

The defining blues drum rule. Derived from analysis of "The Thrill Is Gone."

**Pattern character:**
- No kick drum (or very rare ghost kick at vel 30–35 on beat 3 only, ~20% of bars)
- Side-stick (MIDI 37) carries the groove — a 3+3+2 grouping across the bar
- Snare (MIDI 38) and open hi-hat (MIDI 46) together on beats 2 and 4 — the backbeat

**Side-stick hit positions (in 16-step bar, 0-indexed):**
- Step 0 — beat 1 (strong)
- Step 2 — beat 1-and (strong)
- Step 4 — beat 2 (coincides with snare)
- Step 8 — beat 3 (strong)
- Step 10 — beat 3-and (strong)
- Step 12 — beat 4 (coincides with snare)

This 3+3+2 grouping (steps 0,2,4 then 8,10,12) is the source of the lopsided forward
pull in slow blues. The side-stick velocity should vary slightly bar to bar (±5–8) to
avoid a mechanical feel.

**Snare + open hi-hat:**
- Step 4 and step 12 (beats 2 and 4) — both instruments hit simultaneously
- Snare vel 70–80; hi-hat vel 60–70

**Section variation:**
- Intro: side-stick only, no snare, vel reduced 10–15 points
- Groove A: full pattern as above
- Breakdown: side-stick at 2 events per bar only (steps 0 and 8), no snare
- Groove B: switches to CHL-DRUM-007 (Albert King pushed groove — see below) for contrast
- Outro: gradual thinning toward intro density over last 4 bars

**Does not use:** closed hi-hat pulse, ride cymbal, kick fills, tom fills.

---

## CHL-DRUM-007 — Blues Pushed Groove

A second blues drum character derived from analysis of "Born Under a Bad Sign" (Albert King /
Booker T & the MGs). Used in Groove B of Chill Blues songs as a contrast to CHL-DRUM-006.
Where CHL-DRUM-006 is sparse and patient (no kick, side-stick carries the groove),
CHL-DRUM-007 is more propulsive — a syncopated kick against a pushed snare gives it
forward momentum while staying in the slow blues idiom.

**Pattern character:**
- Kick (MIDI 36): lands on the syncopated positions — the "ands" and downbeats
- Snare (MIDI 38): pushed — one 16th note after beats 2 and 4 (steps 5 and 13), not on the
  downbeat of 2 and 4; this slight delay is the defining texture of the Albert King groove
- Hi-hat (MIDI 42, closed): sparse — beats 1, 1-and, 2, 3, 3-and only (5 hits per bar)
  not a full 8-to-the-bar lock; leaves space between beats 2.5 and 4

**Step positions (0-indexed, 16 steps per bar):**
- Kick: steps 2, 4, 10, 12 — beat 1-and, beat 2, beat 3-and, beat 4
- Snare: steps 5, 13 — 16th note after beat 2 (step 5) and after beat 4 (step 13)
- Hi-hat: steps 0, 2, 4, 8, 10 — beat 1, beat 1-and, beat 2, beat 3, beat 3-and

The pushed snare landing on step 5 (not step 4) and step 13 (not step 12) is the
critical difference from a standard backbeat. It shifts the snare's sense of weight
slightly forward in the bar, creating a rolling, pulling quality that complements the
propulsive kick pattern.

**Velocity:** kick vel 80–90, snare vel 72–82, hi-hat vel 58–68. No ghost notes.

**Section variation:**
- Only appears in Groove B (CHL-DRUM-006 handles Intro, Groove A, Breakdown, Outro)
- In Groove B: runs continuously, no section thinning

**Section change markers (both drum rules):**
- At the bar before any Groove A → Groove B or Groove B → Outro transition:
  add a crash cymbal (MIDI 49) on step 10 (beat 3-and) of that bar
- This is the only crash in a Chill Blues song; all other bars are crash-free

**Drum fills (both drum rules):**
- Designated fill bar occurs once per section, at bar 7 of any 8-bar block
- Fill: 2–4 consecutive snare hits on steps 0, 2, 4, 6 (beats 1–2.5) at the start of the bar,
  then resume normal pattern for the rest of the bar
- Hi-hat drops out during the fill bars
- No tom fills (toms are not part of either blues drum rule)

---

## Bass Patterns With the Blues Drum

The blues drum pattern is sparse and low-density. It pairs naturally with several existing
bass patterns and motivates one or two new ones.

### Existing patterns included in blues pool

**CHL-BASS-001 — Root Sustain:** Root held 12 steps, optional 5th on beat 3. The sparseness
leaves the side-stick pattern audible and creates the slow, patient feel of classic slow blues.
Best pairing for the most minimal blues feel. In blues pool at 20%.

**CHL-BASS-003 — Walking Line:** Root, 3rd, 5th, approach tone on quarter-note steps.
This is textbook jazz-blues walking bass. In the blues context it sounds like a slow blues
jazz crossover — think Ahmad Jamal or early Bill Evans. Already exactly what a blues bassist
would play. In blues pool at 15%.

### Existing patterns excluded from blues pool

**CHL-BASS-002 — Syncopated:** Harmonically compatible — syncopated steps don't clash with
side-stick. However excluded from the blues pool to focus attention on the three new
blues-specific patterns; the blues-new patterns provide better differentiation. Still in
the standard (non-blues) Chill pool at its normal weight.

**CHL-BASS-004 — Air Ostinato:** The 4-bar repeating figure is harmonically static enough
to work, but its ambient/meditative character competes with the new blues bass patterns
for a different emotional space. Excluded from blues pool to maintain authentic blues
feel. Still in the standard Chill pool.

**CHL-BASS-007 — St Germain 8th ostinato:** Too rhythmically busy; would overwhelm the
sparse side-stick groove. Excluded.

**CHL-BASS-008 — Acid Jazz Groove:** Hip-hop jazz feel is incompatible with blues drum
character. Excluded.

---

## New Bass Patterns

Two new patterns add vocabulary specifically for the blues context, while being equally
usable in non-blues Chill songs.

### CHL-BASS-009 — Blues Pickup

Directly derived from "The Thrill Is Gone" analysis. The defining move is a pickup note
a 4th below the root landing on step 7 (the "a" of beat 2), which then jumps to the 5th
on beat 3. This single step-7 event is what makes the pattern sound like slow blues.

Step layout per bar (0-indexed):
- Steps 0–1: root, held 2 steps (strong attack)
- Step 2: root repeated (softer, vel reduced 10), 1 step — adds subtle rhythmic push
- Step 7: pickup note — 5th of the active chord (root + 7 semitones), vel 65–72,
  duration 1 step — this is the signature move; on chord changes, use the 5th of
  the active chord at that bar (not the key 5th), so the pickup stays in the chord
- Step 8: 5th of chord, vel 78–85, held 3–4 steps
- Step 12: b7 of chord, vel 68–75, duration 2 steps
- Step 14: 5th returning, vel 65–70, duration 2 steps

Works over any Chill minor chord without scale changes (the pickup note and b7 are both
natural scale tones in Dorian and minor pentatonic). The step-7 pickup also works over
major chords — it becomes a color tone rather than a blue note.

**Usability beyond blues drum:** This pattern would sound like a slightly bluesier version
of CHL-BASS-002 when paired with any standard Chill drum. It gives non-blues Chill songs
a subtle downward pull without sounding out of place. Can be added to the standard bass
pool at low probability (~8%).

### CHL-BASS-010 — Quarter Pulse (Minor Blues)

A slow, steady quarter-note pattern. Four notes per bar on beats 1–4. The simplest possible
blues bass — patient, unhurried.

Step layout (beats, not 16th steps):
- Beat 1 (step 0): root, vel 82–88
- Beat 2 (step 4): minor 3rd above root (blues inflection), vel 72–78
- Beat 3 (step 8): 5th, vel 75–80
- Beat 4 (step 12): b7 (approach back to root next bar), vel 68–74

This is the slow-blues bass equivalent of CHL-BASS-003's walking line, but with minor-3rd
character instead of the walking approach tone. At 80 BPM it feels like late-night bar blues.

**Usability beyond blues drum:** Works with any Chill drum pattern — adds a more grounded,
slower-feeling bass voice. Minor 3rd color note distinguishes it from CHL-BASS-001 without
being dissonant. Can enter the standard bass pool at low probability (~8%).

### CHL-BASS-011 — Blues Ascending Riff

Derived from "Born Under a Bad Sign" (Albert King). The defining character is that the
bass does NOT begin on the root — it starts on the 5th and walks up 5th → 6th → root,
giving the phrase a forward lean from beat 1. This creates propulsion without busyness.
The original is very active (riff-based, 5–6 notes per bar); this version is simplified
for Chill tempo and density.

Step layout per bar (0-indexed):
- Step 0: 5th of chord, vel 80–86, held 2 steps — the launch note, not the root
- Step 2: major 6th above root (natural 6th, always diatonic to Dorian), vel 74–80, 2 steps
- Step 4: root, vel 82–88, held 3–4 steps — arrival, the rhythmic emphasis lands here
- Step 8: root again (softer, vel 65–72), held 2 steps — settling
- Step 12: 9th (whole step above root) or b7, vel 68–74, duration 2 steps — resolve/color

The 5th → 6th → root ascent in the first 2 beats is the entire rule's identity. Everything
after the root on step 4 is the "tail" and can vary: occasionally hold the root for 8 steps
total (very patient), occasionally add the 9th on step 12, occasionally use the b7.

**Why it sounds different from CHL-BASS-009:** CHL-BASS-009 starts on the root (downbeat
anchor feel). CHL-BASS-011 starts on the 5th (forward-lean feel). Against the same drum
pattern these create noticeably different groove sensations — CHL-BASS-009 is grounded,
CHL-BASS-011 is slightly urgent.

**Works over chord changes:** The 5th-6th-root sequence is diatonic in Dorian for all
three Chill Blues chords (Im7, IVm7, V7). On the V7 bar, the "6th" becomes the major 7th
approaching the root — creates a strong leading-tone pull into the downbeat.

**Usability beyond blues drum:** The ascending-riff feel adds a subtle energy boost to any
Chill song. Pairs well with CHL-DRUM-002 (syncopated Chill groove). Can enter the standard
bass pool at low probability (~8%).

---

## Chord Structure — 16-Bar Blues Form

Chill Blues uses a 16-bar harmonic cycle as the repeating unit throughout Groove A and Groove B.
The cycle maps cleanly onto Chill's 4-bar section grid (four 4-bar blocks = 16 bars).

Bar layout (1-indexed):
- Bars 1–8: I chord (8 bars) — long patient opening, maximum space for lead improvisation
- Bars 9–10: IV chord (2 bars) — the lift, characteristic blues move
- Bars 11–12: I chord (2 bars) — return to tonic
- Bar 13: V chord (1 bar) — peak tension
- Bar 14: IV chord (1 bar) — tension resolves down before tonic
- Bars 15–16: I chord (2 bars) — resolution, cycle repeats

This is a 16-bar slow blues form — less common than 12-bar but well-suited to the Chill
tempo range (75–92 BPM) because the long 8-bar I section gives the sparse drum and bass
patterns room to breathe without the progression feeling rushed.

**Chord quality (all from Dorian, no scale changes needed):**
- I chord: Im7 (root, minor 3rd, 5th, b7) — natural in Dorian
- IV chord: IVm7 (same shape transposed) — natural in Dorian
- V chord: V7 (dominant 7th) — the key blues signal; major 3rd on V is diatonic to Dorian

**Pads and rhythm:** play from the chord tones of the active chord at each bar position.
No structural generator changes needed — just supply the chord sequence to the existing
chord-per-bar machinery.

**Bass:** follows the chord root at each bar change. CHL-BASS-009's step-7 pickup note
uses the 5th of the active chord (root + 7 semitones of whichever chord is active that bar),
so it tracks the harmony correctly across chord changes.

**Partial 16-bar cycles:** Total song bars may not divide evenly by 16. The cycle loops
as many complete times as possible; if bars remain before the outro, those bars play the
Im7 (bars 1–N of the next cycle). The outro always reverts to Im7 regardless of where in
the cycle the outro falls. No special rounding of total bars is required.

**Intro bass behavior:** Bass thins out in the Intro section to match the drum's reduced
intro density. For the Intro, bass event probability is reduced by 50% (approximately one
event every 2 bars instead of every bar). This matches the drum's "side-stick only, vel
reduced" intro character and gives the song a more gradual entry.

---

## Pads — Rule Weights for Chill Blues

Current pad rules in code (CHL-PAD-001 through CHL-PAD-007). Four newer rules were added
after the original chill-plan.md was written and are described briefly below.

**CHL-PAD-001 — Chord Sustain (Long Lake Winter Strings):** Four-voice sustained string
chord, half-note rhythm, vel 55–70. Good fit. Classic string pad behind slow blues.

**CHL-PAD-002 — Staggered Entry (Air / Winter Flight):** Same as PAD-001 but voices enter
8 bars apart. Good fit. The 8-bar I chord opening in the 16-bar structure rewards slow
layering — one voice builds into the next as the song settles in.

**CHL-PAD-003 — Moby Anchor:** Single synth pad, one attack per 4 bars, vel 75–85.
Strong fit. Maximum space, compatible with the sparse side-stick.

**CHL-PAD-004 — Open Fifth Hold** : Root + fifth only, no
third, vel 42–55, held for the full chord window. Best fit of all. The missing third makes
the voicing modally ambiguous — neither major nor minor — which is ideal for blues because
the lead's blue notes (b3, b5) land without clashing against a declared chord quality. Very
low velocity keeps it deep under the mix.

**CHL-PAD-005 — Slow Chord Build** : Additive layering —
root+fifth at bar 0, adds third at bar 4, seventh at bar 8, ninth at bar 12 (Röyksopp/Air
model). Excluded for Chill Blues. The 16-bar structure's short chord windows (1 bar on V,
1 bar on IV) reset the build before it completes, producing incomplete voicings at those
positions. Wrong for the harmonic pacing of the blues form.

**CHL-PAD-006 — Portishead String Hold** : Close-voiced 4-note
string chord (root, third, fifth, seventh) within one octave, re-attacked every 2 bars with
staggered-bowed-attack feel, vel 55–70. Good fit. The Portishead trip-hop / cinematic
aesthetic is blues-adjacent. The 2-bar re-attack aligns with the chord changes.

**CHL-PAD-007 — Absent** : No pad events in Groove sections.
Good fit. Blues often has no pad at all — drums, bass, rhythm, and lead are sufficient.

**Pad weights for Chill Blues:**
- CHL-PAD-004 (Open Fifth Hold) — 30%
- CHL-PAD-003 (Moby Anchor) — 20%
- CHL-PAD-007 (Absent) — 20%
- CHL-PAD-002 (Staggered Entry) — 15%
- CHL-PAD-001 (Chord Sustain) — 10%
- CHL-PAD-006 (Portishead Strings) — 5%
- CHL-PAD-005 (Slow Chord Build) — 0% excluded: short chord windows produce incomplete voicings

---

## Rhythm — Rule Weights for Chill Blues

Current rhythm rules in code (CHL-RHY-001 through CHL-RHY-004). CHL-RHY-004 was added
after the original chill-plan.md and is described briefly below.

**CHL-RHY-001 — St Germain Syncopated:** Strikes at step 0 (beat 1) and step 6 (AND of
beat 2), 4-note jazz voicing. Acceptable at reduced weight. The downbeat + AND-of-2
positioning is workable but leans club/house rather than blues.

**CHL-RHY-002 — Moby Backbeat:** Strikes at steps 5 and 13 — slightly pushed off beats 2
and 4, 3-note shell voicing. Best fit. Beats 2 and 4 is canonical blues/gospel piano
comping position. Additional synergy: the pushed step 5/13 position matches CHL-DRUM-007's
pushed snare exactly — in Groove B, Rhodes and snare lock together in the same pushed
position, creating the tight rhythm-section quality of a real blues band. Currently limited
to Deep/Dream moods; open to all moods in Chill Blues mode.

**CHL-RHY-003 — Bosa Moon Arpeggiated:** 8th-note arpeggiation, ~10 notes per bar.
Excluded. Overwhelms the sparse side-stick drum completely. Wrong character.

**CHL-RHY-004 — Acid Jazz Stab Groove** : Four syncopated
2-note dyad stabs per bar on AND positions (steps 2, 6, 8, 14), derived from Cantaloop
keyboard groove. Staccato, vel 76–89, sparse bar every 4th bar. Naturally excluded —
this rule is only triggered by Hip-Hop Jazz beat style, which is already incompatible with
Chill Blues.

**Rhythm weights for Chill Blues:**
- CHL-RHY-002 (Moby Backbeat) — 70% across all moods
- CHL-RHY-001 (St Germain Syncopated) — 30% across all moods
- CHL-RHY-003 (Bosa Moon Arpeggiated) — 0% excluded: too busy, wrong character
- CHL-RHY-004 (Acid Jazz Stab) — 0% excluded: hip-hop jazz beat style incompatible

---

## Lead Rules

**Lead 1 — rule weights for Chill Blues:**
- CHL-LD1-004 (Blues Lead) — 55%. Primary choice. Blues scale emphasis, descending phrases, saxophone idiom.
- CHL-LD1-002 (Short Punch) — 25%. Derived from Miles Davis *All Blues*. Syncopated off-beat hits in the lower register are textbook slow blues phrasing.
- CHL-LD1-003 (DJ Cam Dyad) — 20%. Jazz-blues crossover feel at slow tempo. Works without modification.
- CHL-LD1-001 (St Germain Long Phrase) — 0%. Excluded. The flowing, resolved European jazz flute phrasing is wrong for blues character.
- CHL-LD1-005 (St Germain Staccato Burst) — 0%. Excluded. Club/house feel; also already excluded by St Germain beat style incompatibility.

**Lead 1 — scale for Chill Blues solos:**
Minor pentatonic (root, b3, 4, 5, b7) and minor blues scale (root, b3, 4, b5, 5, b7) are
used equally (50/50 per phrase or per song). The b5 blue note in the blues scale adds the
characteristic tension that distinguishes blues phrasing from generic minor playing. The
existing CHL-LD1-004 rule already references the blues scale; the 50/50 weighting makes
this explicit and ensures the blue note appears regularly rather than occasionally.

**Lead 1 — instruments for Chill Blues:**
The Lead 1 pool is Muted Trumpet (59), Alto Sax (65), Tenor Sax (66), Trumpet (56), and
Clarinet (71, now added). All are strong blues instruments. Tenor Sax and Clarinet are
the most idiomatic for slow blues. Flute and vibraphone belong to Lead 2, not Lead 1.

Blues mode instrument weights (replace general Chill weights when `bluesVariation` is true):
- Tenor Sax — 30% (most idiomatic for slow blues; boosted from 20%/32%)
- Alto Sax — 22% (natural blues voicing)
- Clarinet — 20% (doubled from 10% — strong blues heritage, chalumeau darkness)
- Muted Trumpet — 18% (kept; subdued tone suits blues more than open trumpet)
- Trumpet — 10% (reduced; brighter tone less typical of slow blues feel)

Candidates to audition as potential additions:
- Clarinet (GM program 71): added. Strong blues heritage — New Orleans, Chicago, early
  jazz-blues. Chalumeau register gives a dark, woody tone. General Chill weight: 10%.
  Chill Blues weight: 20% (doubled — blues clarinet is more idiomatic than trumpet for
  this feel, so it earns a larger share against the blues drum bed).
- Oboe: not recommended. Little blues tradition; GM oboe sounds too classical/nasal.

**Lead 2 — rule weights for Chill Blues:**
- CHL-LD2-001 (Register Response) — 50%. Call-and-response structure is fundamental to blues. Strong fit.
- CHL-LD2-003 (Counter Stab) — 35%. Short 3rd+7th dyad stabs in Lead 1 rests = blues piano/organ comping. Strong fit.
- CHL-LD2-004 (Sparse Drone) — 15%. Harmonically neutral, not wrong, but ambient rather than blues in character.
- CHL-LD2-002 (Harmonic Shadow) — 0%. Excluded. The tight diatonic echo reads as pop/R&B harmony; its Bright/Free mood association also conflicts.

**Rhythm (Rhodes/Wurlitzer/B3 Organ):** Sparse chord comping already sounds like blues
piano comping. No changes required. The Rhodes in particular sounds completely natural over
a slow blues drum bed.

---

## Pairing Model

When the blues variation is active:

- Drum: CHL-DRUM-006 (Intro, Groove A, Breakdown, Outro); CHL-DRUM-007 (Groove B)
- Bass: CHL-BASS-009 (30%), CHL-BASS-011 (25%), CHL-BASS-001 (20%), CHL-BASS-003 (15%),
  CHL-BASS-010 (10%); CHL-BASS-002, CHL-BASS-004, CHL-BASS-007, CHL-BASS-008 excluded
- Pads: CHL-PAD-004 (30%), CHL-PAD-003 (20%), CHL-PAD-007 (20%), CHL-PAD-002 (15%),
  CHL-PAD-001 (10%), CHL-PAD-006 (5%); CHL-PAD-005 excluded
- Rhythm: CHL-RHY-002 (70%), CHL-RHY-001 (30%); CHL-RHY-003 and CHL-RHY-004 excluded
- Lead 1: CHL-LD1-004 (55%), CHL-LD1-002 (25%), CHL-LD1-003 (20%); CHL-LD1-001 and CHL-LD1-005 excluded
- Lead 2: CHL-LD2-001 (50%), CHL-LD2-003 (35%), CHL-LD2-004 (15%); CHL-LD2-002 excluded

When the blues variation is NOT active:

- CHL-BASS-009, CHL-BASS-010, CHL-BASS-011 remain available at low probability (~8% each)
  in the standard bass pool — they blend naturally with existing Chill songs

---

## BPM Behavior

When blues variation is active, weight the BPM selection toward 75–92 BPM. The existing
Chill BPM range already includes this. Implementation: if `bluesVariation` is true and the
randomly selected BPM is above 92, re-roll once (draw a new value from the 75–92 sub-range).
Simple one-line guard. Does not constrain songs to this range — just makes it less likely
to generate a 100 BPM blues song that would feel rushed.

---

## Rule IDs Summary

- CHL-DRUM-006 — Blues Side-Stick (new) — derived from B.B. King "The Thrill Is Gone"
- CHL-DRUM-007 — Blues Pushed Groove (new) — derived from Albert King "Born Under a Bad Sign"
- CHL-BASS-009 — Blues Pickup (new) — derived from B.B. King "The Thrill Is Gone"
- CHL-BASS-010 — Quarter Pulse Minor Blues (new)
- CHL-BASS-011 — Blues Ascending Riff (new) — derived from Albert King "Born Under a Bad Sign"

All other rule IDs remain unchanged.

---

## Implementation Scope

### ChillMusicalFrameGenerator
- Add `bluesVariation: Bool` to ChillMusicalFrame
- Add activation logic (~10%) before mode pick; if active, force mode = .Dorian and
  constrain beat style to exclude .stGermain and .hipHopJazz
- Add BPM soft-guard: if bluesVariation and BPM > 92, re-roll once from the 75–92 range
- When bluesVariation is true, override Lead 1 instrument weights with the blues-specific
  table (Tenor Sax 30%, Alto Sax 22%, Clarinet 20%, Muted Trumpet 18%, Trumpet 10%)

### ChillDrumGenerator
- Add CHL-DRUM-006 (Blues Side-Stick): side-stick 3+3+2 at steps 0,2,4,8,10,12;
  snare+open-hat at steps 4,12; optional ghost kick at step 8 (~20% of bars)
- Add CHL-DRUM-007 (Blues Pushed Groove): kick at steps 2,4,10,12; snare at steps 5,13;
  hi-hat at steps 0,2,4,8,10
- Route 006 → Intro, Groove A, Breakdown, Outro; 007 → Groove B
- Add fill behavior: steps 0,2,4,6 snare run at bar 7 of each 8-bar block; hi-hat drops out
- Add crash cymbal (MIDI 49, step 10) on the bar before any Groove A→B or B→Outro transition

### ChillBassGenerator
- Add CHL-BASS-009, CHL-BASS-010, CHL-BASS-011 with their step layouts
- Blues pool weights: 009(30%), 011(25%), 001(20%), 003(15%), 010(10%)
- Standard pool: add 009, 010, 011 each at ~8%; existing patterns retain their weights
- Intro section: reduce bass event probability by 50% when bluesVariation is true

### ChillSongGenerator / chord machinery
- Supply 16-bar chord sequence: Im7×8, IVm7×2, Im7×2, V7×1, IVm7×1, Im7×2
- Cycle repeats for Groove A and Groove B; outro reverts to Im7 regardless of cycle position

### ChillPadsGenerator
- Blues weights: PAD-004(30%), PAD-003(20%), PAD-007(20%), PAD-002(15%), PAD-001(10%),
  PAD-006(5%); PAD-005 excluded (weight = 0)

### ChillRhythmGenerator
- Blues weights: RHY-002(70%), RHY-001(30%); RHY-003 and RHY-004 excluded
- Open RHY-002 to all moods when bluesVariation is true (normally restricted to Deep/Dream)

### ChillLeadGenerator
- Blues Lead 1 rule weights: LD1-004(55%), LD1-002(25%), LD1-003(20%); LD1-001 and LD1-005 excluded
- When blues active and rule = CHL-LD1-004: pick scale 50% minor pentatonic / 50% minor blues
- Blues Lead 2 weights: LD2-001(50%), LD2-003(35%), LD2-004(15%); LD2-002 excluded

### Files NOT changing
ChillStructureGenerator, PlaybackEngine, StepScheduler, all audio engine code, any UI files.
The timing system is untouched. No new GM programs (Clarinet/71 is already wired in).

---

## Implementation Log

### Build 116 (May 2026) — 16-bar form awareness in solos + polish

**Lead form awareness (ChillLeadGenerator):**
- Phrases now clamp to the 16-bar form seams: no phrase crosses bar 8 (IV entry), bar 12 (V entry), or bar 15 (turnaround end)
- At position 14 (turnaround): 50% chance of a 3–4 note descending `bluesTurnaroundLick`; position 15 is always silent
- Chord-tone targeting at IVm7 and V7 entries — starting note biased toward the incoming chord's tones
- Lead 2 always silences in the turnaround zone (positions 13–15)
- `forceBluesEntry` mechanism ensures Lead 1 enters within 4 bars of section start (prevents long instrumental-only stretches)

**Song structure:**
- Intro shortened from 4–8 bars to 0 or 4 bars (50/50), so the solo starts sooner
- Total song capped at 86 bars (5 × 16-bar forms max)
- Generation log now shows "Form: 16-bar blues I-IV-V" instead of "Groove"

**Bug fix — SongState.withChillAudioTexture:**
- `withChillAudioTexture` was missing `chillBluesVariation: chillBluesVariation` in its copy constructor
- The Texture TrackRowView's `onChange` called this immediately after generation, resetting the flag to `false`
- Fixed: one line added; all copy methods now preserve the field

**Delay effect chip (TrackRowView):**
- Delay chip on Lead 1 and Lead 2 now greys out and disables for Chill Blues songs

