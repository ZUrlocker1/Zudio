# Chill Soho — Design & Implementation

Status: **built, in 2.7 (build 132), tuning by ear.**

Chill Soho is the third Chill presentation, after base Chill and Chill Blues. Where base Chill is
downtempo and house-adjacent (Moby, St Germain) and Chill Blues is a 16-bar form, Chill Soho is
the **British sophisticated pop of the early 80s** — Sade, Everything but the Girl, The Style
Council, Simply Red, Roxy Music — built on a Latin and soul rhythm section that nothing else in
Zudio uses. Its rules were measured from MIDI transcriptions of those records rather than written
from description.

---

## Naming

**Chill Soho.** Soho is where the London end of this music lived: the jazz-funk and Latin clubs,
the Wag Club on Wardour Street, the café culture the Style Council worked in. It names the scene
without naming a record, the same reasoning that named Motorik Europe. The critical label
"sophisti-pop" is a retrospective coinage the bands disliked, and is not used in the UI.

---

## Musical identity

### Reference artists and songs

- **Sade** — *Smooth Operator*, *Your Love Is King* (Diamond Life, 1984); *Cherish the Day*
  (Love Deluxe, 1992). The soft Latin-jazz sway at the centre of the style
- **Roxy Music** — *More Than This*, *Avalon* (Avalon, 1982). The precursor record; the
  atmosphere everything else descends from
- **Everything but the Girl** — *Each and Every One* (Eden, 1984), and *Missing* for its remix.
  The clearest bossa in the set
- **The Style Council** — *You're the Best Thing*, *My Ever Changing Moods*, *The Paris Match*
- **Simply Red** — *Holding Back the Years*. The laid-back end only
- **Steely Dan** — *Do It Again* (Latin-tinted minor vamp with congas) and *Black Cow*, cited for
  groove, bass and horn writing only — their harmony is far beyond the vamps used here
- **Samba end** — Matt Bianco, *Half a Minute*. The faster, brighter variant

### What defines the sound

- **Space is the genre.** Narrow dynamics, few instruments at once, everything at mid-level
- **Harmony is jazz, form is a loop.** 6ths, 7ths and 9ths on a short cycle that never
  modulates — hypnotic rather than developmental
- **Bass is the second voice.** Fretless and melodic; after the vocal it carries more melody than
  anything else in the arrangement
- **Sax answers the singer.** These songs have a vocal and Zudio does not, so Lead 1 plays
  vocal-shaped melody and a saxophone answers it in the gaps — a counter-melody, never a blowing
  solo
- **Rhodes and clean guitar comp**, never piano-forward
- **Restraint comes from touch as much as sparseness** — rim click instead of a struck snare,
  low velocities. *You're the Best Thing* runs 23 comp notes a bar at 84 BPM and is still the
  most relaxed record in the set

### Latin is a colour, not the defining rhythm

Sade is a soft sway, not samba; the genuinely Latin records (*Each and Every One*, *Half a
Minute*, *Smooth Operator*'s congas) are a minority. *More Than This*, *You're the Best Thing*,
*Your Love Is King* and *Holding Back the Years* are not Latin at all. So the substyle is split
into a **Latin half and a Soul half**, and what holds the identity together across both is the
non-modulating vamp, the melodic bass, the sax counter-melody and the restraint — not the drums.

---

## Evidence base

Fourteen MIDI files, measured per channel with `tools/soho_analyze.py` and per named track with
`tools/soho_tracks.py`. The Guitar Pro exports put every pitched part on channel 0 under named
tracks ("Fretless Bass", "Rhythm Guitar", "Vocals"), so the track reader is what recovered their
bass and vocal lines. Chord cycles come from `tools/soho_harmony.py`, sustained-note phrases from
`tools/soho_sustained.py`.

What each record contributed:

- *Smooth Operator* — the Latin kick, the bossa bass, the half-bar pad, the main counter-line
  and the minor `Im9 – bVIImaj9` cycle
- *Your Love Is King* — the turnaround, the comp, a major cycle, Lead 2 as alto sax and synth brass
- *Cherish the Day* — the `Im7 – Vm7` cycle (2 roots in 79 bars), a single-chord pad, the one
  genuine shadow-hold second voice
- *More Than This* — the soft-soul backbeat with quarter-note hats, the single-note guitar line,
  the four-chord major cycle, and the sustained-tone sax (13 notes in a whole song)
- *Avalon* — the three-hook lead, conga over a straight kit, the `Imaj9 – IV6` cycle
- *Holding Back the Years* — muted-trumpet stabs, comp voicings
- *Black Cow* — the syncopated pocket bass (Chuck Rainey), the busiest horn section
- *Do It Again* — the root-and-chord comp, the modal minor cycle, the heaviest Latin percussion
- *Half a Minute* — the samba pickup bass, the busiest Latin bass leaps, flute and bari sax lines
- *You're the Best Thing* — the fretless melodic bass, the `I – V – I – bVII` cycle
- *Each and Every One* — vocal phrasing, the root-and-chord guitar comp
- *My Ever Changing Moods* — the root-pedal-walk bass, vocal phrasing
- *Missing* — the Todd Terry house remix, model for the Remix Break and one source for the
  root-and-chord comp
- *The Paris Match* — a 3/4 jazz waltz; corroborates the tempo band and the soul hat profile,
  but its meter is not used

### Findings that shaped the design

- **Latin percussion is an overlay, not a separate kit.** Latin percussion's share of drum hits:
  *Do It Again* 55%, *Half a Minute* 52%, *Avalon* 46%, *Smooth Operator* 37%, *Your Love Is
  King* 25% — and 0% in five others. *Avalon* and *Your Love Is King* are soul songs with congas
  over a straight kit. So the drums are a kit pattern plus an optional percussion layer
- **Harmony is narrow but moves.** Chords change every 1–1.5 bars over only 5–7 roots — a short
  cycle going round quickly, not two chords held four bars each. Almost every chord measures as
  a 6th, 7th or 9th; plain triads barely appear
- **Tempo is bimodal**, 80–88 and 121–130, so one wide band (84–128) covers it. The fast songs
  do not feel fast — *More Than This* at 127 has quarter-note hats and a bass playing four notes
  a bar
- **The vocal lines are the best Lead 1 model.** Sung lines run 2–3 notes a bar held 2–4 steps,
  open-ended, and they repeat pitches: `[0, 0, 0]` is the commonest figure. A generator that
  always moves does not sound like this music
- **The second voice answers rather than accompanies.** The share of Lead 2 notes sounding
  under Lead 1 has a median of 17%; only *Cherish the Day* genuinely holds under the melody.
  Second voices run 1.3–2.0 notes a bar, below the main line in register
- **Fills are rare**, one per 20–30 bars, a bar or less, at the end of a four- or eight-bar
  group — a tom figure, a snare pickup, or a percussion flare where the kit holds steady.
  Nothing plays a rolling sixteenth fill
- **Seven tracks against ten-channel records.** Each recurring role maps to one Zudio track;
  the doubled comp guitars (*Avalon* has six pad-and-guitar channels) are not reproduced

---

## How it differs from base Chill and Chill Blues

- **Rhythm section** — base Chill has no Latin drum rule. Soho adds five drum rules plus a Latin
  percussion layer, and reuses only base Chill's `003` on the soul half
- **Form** — a short non-modulating cycle with a separate B cycle and a played turnaround,
  against base Chill's moving chord plans and Blues's 16-bar form
- **Tempo** — 84–128 in one band
- **Bass** — a melodic voice rather than an anchor
- **Texture** — MIDI horns and bells instead of base Chill's café audio loops
- **Density** — lower on every track, with long silences built in

---

## Activation and the groove

- `SongState.chillSohoVariation: Bool`, alongside `chillBluesVariation`; a song is never both.
  Every `withXxx()` copy method passes it explicitly
- `displayStyleName` is `"Chill Soho"`; `.zudio` files write it on `Substyle:`, `Style:` stays
  `Chill`
- **Share:** Blues 15% on the main stream, then `sohoShareOfNonBlues` (`70/85`) — **70% Soho /
  15% Blues / 15% base**. This is a **testing mix**; before release restore `0.20` for Blues and
  `0.25` for `sohoShareOfNonBlues` (60/20/20) and re-pin the fingerprint baseline
- **Groove**, once per song: `ChillBeatStyle.sohoLatin` 55%, `.sohoSoul` 45%
- **Tempo:** 84–128 BPM, triangular with a peak at 100, independent of the groove
- **Mode:** base Chill's weights — Dorian 40%, Aeolian 25%, Mixolydian 20%, Ionian 15%
- Soho's draws use derived RNG streams (`SeededRNG.trackSeed`, indices 90–98) so they never shift
  base Chill's main stream and existing songs still reproduce

**The groove is the coordination mechanism.** `ChillBeatStyle` already reaches the drum, bass and
rhythm generators, and each picks its pool from it, so a soul bass line can never appear under a
bossa clave. Pads, Lead 1, Lead 2 and Texture do not carry the groove and draw from one pool.
Only two things read another track's output: the groove fixup (leads against drums and bass) and
the Texture stabs (against the drum crashes).

---

## Harmony

Built in `SongGenerator.buildSohoChordPlan`, from the measured cycles. Each song draws one cycle
for A and a different one from the same pool for B, so the two halves move differently; cycles
tile in 16-bar phrases, each opening on the tonic.

**Minor** (Dorian, Aeolian):

- `Im9 – bVIImaj9` 40% — *Smooth Operator*
- `Im7 – Vm7` 35% — *Cherish the Day*, *Holding Back the Years*
- `Im9 ×3 – Vm7` 25% — *Do It Again*, the modal one

**Major** (Ionian, Mixolydian):

- `Imaj9 – IV6` 30% — *Avalon*, *Half a Minute*
- `I – V – I – bVII` 30% — *You're the Best Thing*, the Style Council sound
- `Imaj9 – IVmaj9` 25% — *Your Love Is King*
- `I6 – IIIm7 – IIm7 – V5` 15% — *More Than This*

In Mixolydian the tonic is a dominant 9th; in Aeolian bVII is a dominant 9th.

### Turnaround

Measured in *Your Love Is King*: a four-bar chord detour **inside** the groove, roughly every
16 bars, while the band plays on. It falls at the end of every 16-bar phrase in 60% of songs and
at section ends only in the rest. Each song takes the measured shape or a plain bright cadence,
50/50:

- Ionian — `IIm9 – IIIm7 – IIm9 – IVmaj9`, or `IVmaj9 – V9 – Imaj9 – V9`
- Mixolydian — `IIm9 – Vm7 – IIm9 – IVmaj9`, or `IVmaj9 – bVIImaj9 – I9 – bVIImaj9`
- Dorian — `IV9 – Vm7 – IV9 – I`
- Aeolian — `IVm9 – Vm7 – IVm9 – I`

The measured major shapes carry three minor chords in four, which is much of why a major-key
Soho song still reads as minor-tinged. The band performs it: the bass plays a turnaround figure
(see Bass), the drums fill on 60% of exits, the horns stab its downbeat in 55% of songs, and the
shaker rests throughout. `ChillStructureGenerator.sohoTurnaroundBars` reads the turnarounds back
from the finished chord plan, and every track keys off that.

---

## Song structure

- **Intro: 4 bars, or none in 15% of songs.** It builds a layer a bar — the drum rule's own
  voice, then the Latin percussion and low end, then rhythm and bass (which enters first
  alternates per song, `sohoBassLeadsIntro`) — with a fill and a crash into A. A cold start
  spends the first bar on a drums-only pickup
- **Sections:** A then B, A taking about 45% of the groove

### Breakdowns

These are instrumental songs over a non-modulating vamp, so mid-song contrast has to come from
arrangement. Breakdowns are `ChillBreakdownStyle` cases; Soho never uses base Chill's stop-time.

**Remix Break (`.sohoRemix`).** Modelled on Todd Terry's remix of *Missing*: kick four-on-the-
floor, clap on 2 and 4, and a shaker on every sixteenth — the same shaker layer Soft Samba runs.
Todd Terry kept the percussion and swapped the kit, which is why the break is the shaker carrying
on while the kit underneath changes.

- Eligible only when the Latin percussion overlay is on, tempo is above 105 and the drum rule is
  not Ballad Half-Time (`013`) or `003`; fires in 33% of eligible songs, about one Soho song in
  fourteen
- 6, 8 or 12 bars; the song's own cycle continues at two bars a chord
- Backbeat voice drawn per song: handclap 45%, tambourine 30%, side stick 25%
- **In:** the band stops after beat 2 of the bar before and hits beats 3 and 4 in unison, with a
  crash on the break's downbeat
- **Out:** unison stabs on steps 0 and 8, or a fill, 50/50. Lead 1 picks up on steps 10, 12 and
  14 either way, so the sax answers in the gaps and everyone lands together

**Otherwise:** bass ostinato 35%, duo 25%, groove pocket 22%, harmonic drone 18%.

- **Bass ostinato** — the fretless alone, the best base Chill fit for this music
- **Groove pocket** — under Latin the kit steps back to the kick and the hand percussion comes
  forward; under Soul the rule holds and takes handclaps
- **Duo** (`.sohoDuo`, added 2026-10-15) — 8 bars (70%) or 12, Rhythm and Bass alone. The bass
  keeps its own groove; the comp plays every bar with no rests or dropouts, 8 velocity up, as
  chordal comp (`007`) — rootless, leaving the low end to the bass — or as the single-note line
  (`008`) when that is the song's A rule, making the duo two lines in counterpoint. Root-and-chord
  eighths is never used, since its low root sits on the bass. The song's A cycle continues at two
  bars a chord, as in the Remix Break. The kit keeps one soft timekeeper and no kick: shaker
  eighths when the song is Latin or has the percussion overlay, closed-hat quarters otherwise,
  ride quarters under the reused Brush Kit. The way out is a soft snare pickup on steps 12 and 14
  and a crash. Pads and both leads sit out. The horns reply sparingly, whichever Texture rule is
  running — a soft two-note held chord on the duo's third bar and every four bars after, and a
  stab with the snare pickup on the last bar's beat 4 — because Rhythm and Bass alone was too
  bare
- **Harmonic drone** — four bars from an unresolved Isus4 that moves once, halfway: resolving to
  I (40%), lifting to IV (35%) or stepping to bVII and back (25%). Lead 1 plays through it
- The horns answer the drone, the groove pocket and the duo, which otherwise have no voice

---

## Rule catalog

Rule names describe the figure, never the instrument that plays it. New Soho rules continue
Chill's numbering; reused base Chill rules keep their IDs.

### Drums

- **Latin pool:** `CHL-DRUM-009` Bossa clave 40%, `010` Soft samba 30%, `011` Latin sway 30%
- **Soul pool:** `CHL-DRUM-012` Soft soul backbeat 55%, `013` Ballad half-time 25%, base Chill's
  `003` Jazz quarter-note pulse 20%

**`009` Bossa clave** — the EBTG end. Rim click carries a two-bar clave (steps 0, 6, 12 and 20,
26); closed hats run steady eighths, alternating strong and weak; the kick plays 0, 6, 8 plus 14
in about 60% of bars — the measured *Smooth Operator* kick, not the textbook tresillo. No snare.

**`010` Soft samba** — the Matt Bianco end. Continuous soft shaker sixteenths drive it; the surdo
weight falls on step 8 with step 0 lighter; rim on 4 and 12; hats on the offbeat eighths.

**`011` Latin sway** — the Sade end, half-time and conga-led, the quietest drum rule in Chill.
Conga on 0, 3, 6, 10, 13; rim on 8 only; sparse hats; kick on 0 and on 11 in alternate bars. It
leaves the bass exposed.

**`012` Soft soul backbeat** — *More Than This* and *You're the Best Thing*, which agree on
everything except the hat. Rim click (preferred) or snare on 4 and 12; kick on 0 plus 8, or a
push from 7 into 8; hats in eighths (*You're the Best Thing*) or quarters (*More Than This*),
50/50. Flat, low hat velocity and **no ghost notes** — what separates it from base Chill's
neo-soul `002`.

**`013` Ballad half-time** — the sparsest rule. Snare or rim on beat 3 only, kick on 0 and on 6
in alternate bars, hats on 0 and 8 or absent; a single pickup into step 8 in a quarter of bars.

**`003` Jazz quarter-note pulse** (reused) — ride quarters with brush snare on 2 and 4 and
minimal kick: restrained and brush-voiced, the soul half's third colour.

**`CHL-DRUM-014` Latin percussion** — conga, bongo, shaker and cabasa layered over whichever rule
fired, in 85% of Latin songs and 40% of Soul. It plays from the intro's second layer to the end.
The rule and the overlay are drawn together (`ChillDrumGenerator.sohoDrumPlan`) on a derived
stream, so the breakdown choice can read them before the drums exist.

**Fills** follow the measurement: rare, at four- and eight-bar group ends and turnaround exits,
never rolling sixteenths.

**Shaker rests.** Left alone the shaker would run nearly every bar. It rests for every
turnaround, for one or two 8–16 bar windows per section, and for the 4–8 bars before a
breakdown — around 68% of bars, never below 60%, rests capped at a third of the song. A window's
return bar takes a crash.

### Bass — the second voice

Every corpus bass hits step 0 hardest, with step 6 (the "and" of two) and step 14 (the pickup)
next, and repeated pitches are the commonest interval — these basses drive by rhythm and
repetition. They split by leap content and sustain, which is what separates the rules.

- **Latin, minor:** `CHL-BASS-013` Bossa root-fifth 35%, `012` Rumba bass 25%, `015` Syncopated
  pocket 20%, `016` Samba pickup 20%
- **Latin, major:** `013` 35%, `015` 35%, `016` 30% (Rumba is minor-only)
- **Soul:** `CHL-BASS-014` Best melodic bass 23.5%, `017` Stylish root pedal walk 23.5%, `015`
  23%, and base Chill's `002` Syncopated groove 15%, `004` Air ostinato 10%, `001` Moby root
  sustain 5%
- **Breakdowns:** `005` Breakdown root drone

**`013` Bossa root-fifth** — *Smooth Operator*. 4–6 short notes a bar (2–3 steps — detached, not
ringing) on 0, 6, 8, 14 with 10 and 12 secondary, root–fifth leaps, octave drops on chord changes.

**`014` Best melodic bass** — the fretless track of *You're the Best Thing*. Sparse and sustained:
about 3 notes a bar held a quarter note or more, on step 0 and then 12–15, almost nothing on
step 6, monophonic. Defined by space, the opposite of `013`.

**`015` Syncopated pocket** — *Black Cow*, Chuck Rainey's playing: attacks on 0, 3, 6 with 11
and 15, the one corpus bass that plays off the sixteenth grid.

**`016` Samba pickup** — *Half a Minute*, which plays this figure in 96% of its bars. The beat-1
root repeats on the sixteenth before beat 2 and lands on the fifth; the same pickup leads into
beat 4; about seven short notes a bar. Three variants rotate every 12–18 bars.

**`017` Stylish root pedal walk** — *My Ever Changing Moods*. The first half-bar pedals the root
in eighths, the second walks away from it; 36% repeated pitches are the engine of the figure.

**`012` Rumba bass** (shared with Chill Blues) — root, minor 3rd, 5th, 6th and a tail on 0, 6,
10, 12, 14. The pattern is genuinely Latin; its one blues-coded moment, a ♭7 for the 6th, is
forced off in Soho.

**Reused from base Chill, soul half only:** `002` Syncopated groove (a soul pocket under the
backbeat), `004` Air ostinato (a four-bar figure that reads as hypnotic over a vamp), `001` Moby
root sustain (a sustained root under the half-time snare). The three are capped at 30% between
them.

Every rule cycles small variants every 12–18 bars, because a figure that is hypnotic for three
minutes under a vocal is monotonous for six minutes without one.

**Turnaround treatment.** The bass leaves the groove for the turnaround's last two bars and plays
one of six figures, named in the log: walking quarters, root and approach, descending, root
pedal descent (one root held under a descending line, "ba-baa, ba-baa"), pedal descent (each bar
pedals its own root), or original form (the groove rides through). Each song draws two (56%) or
three (44%), plays each once, then repeats from that set, so its turnarounds are neither all the
same nor all different. The pedal holds one note in one octave (40–52); a pedal that would equal
the line note beside it is dropped, and the line itself is never moved. `sohoTurnaroundPalette`
and `sohoTurnaroundStyle` are pure functions, so the generator and the log agree.

**Slides** (`ChillBassSlides`, prototype 2026-10-15) — Best Melodic Bass (`014`) songs only, any
bass instrument. Every bass bend in the corpus is a slide up into a note, a whole step (most) or a
half step, over one to two sixteenths: a slide along one string. Holding Back the Years' fretless
slides about once per 8 bars, always on the same note of its figure. The slides are pitch bend over
notes already in the track, so the notes, the MIDI lane and the fingerprints do not change; playback
(`PlaybackEngine.startBassSlide`) and export (`OfflineExport.slideEvents`) read the same pure
function.
- The root after each turnaround slides in half the time
- Otherwise a note held a quarter or longer slides in 5% of the time
- Slides stay at least four bars apart, landings placed first; bars 29 and 30 both sliding read as a
  habit, not a gesture
- From below after a lower note and from above after a higher one; from the previous note itself
  when it is a half or whole step away, otherwise a whole step (65%) or a half step. Two and a half sixteenths, at most half the note: the starting pitch holds for the first
  quarter of the glide, then moves steadily. Only after a move of a half step to a fourth — after a
  wider leap or into a repeated note it is heard as a bend. The first version (a sixteenth and a
  half, leaving at once, always from below, up to three quarters of the note) sounded like bends
- **Scope is settled** (Zack, 2026-10-15): slides stay on these two rules only — Soho `014` and
  Blues `009` — as a rare touch. They took more tuning than expected, so they are not being spread
  to other bass rules, and bass vibrato is not being pursued
- **Chill Blues**, on the B.B. King pickup riff (`009`) only: a half-step slide over a sixteenth
  and a half into the root at the top of every form, where the turnaround ends on the b7 below it.
  Every form, so it belongs to the riff — one that came and went sounded arbitrary in a form this
  repetitive, and a whole step over most of a beat sounded artificial. Zack slides into the IV and
  V playing *The Thrill Is Gone*, but this riff reaches those roots from above: forced upward they
  were bends, following the line they were pull-offs
- Off while the bass has the Vibrato effect on, which drives the same pitch wheel
- Over 51 songs: median 9 slides a song (3–16), 0.7 per 8 bars (before the leap rule)

### Rhythm — comping

Two measured families, separated by voicing size rather than density: chordal comps of 2–3
notes and monophonic lines.

- **Latin:** `CHL-RHY-007` Chordal comp 40%, `009` Root-and-chord eighths 30%, `008` Single-note
  line 30%
- **Soul:** `007` 25%, `008` 25%, `009` 20%, and base Chill's `005` Chord hold 15%, `006` Downbeat
  pulse 15%

A and B always take different rules.

**`007` Chordal comp** — *Black Cow*, *Your Love Is King*, *Holding Back the Years*, *Smooth
Operator*. Rootless 2–3 note voicings on steps 0, 6 and 12 (the two-bar answer on 20, 26),
short and soft. In both pools, since most of its sources are soul records.

**`008` Single-note line** — *Avalon*, *More Than This*. A continuous monophonic line, 4.5–9
notes a bar, narrow range and very short notes; dense but quiet, controlled by velocity rather
than note count.

**`009` Root-and-chord eighths** — the *Do It Again* piano and the guitars of *Each and Every
One* and *Missing*. A low root on beat 1 with its octave on the "and" of 2 and on beat 4,
answered by 2–3 note chord fragments on the other eighths so the downbeat rings. Three variants
rotate every 8–12 bars and the fragment shape changes on every hit. Root at MIDI 48–59, above
the bass.

**Reused:** `005` Chord hold and `006` Downbeat pulse — plain shell chords on beats 1 and 3,
which is exactly the comping on *More Than This*. Base Chill's Bosa Moon (`003`) is excluded: it
is named after Bosa in Sardinia, not bossa nova, and its even arpeggio would fight the clave.

**Silence is the strongest variation.** Long dropouts of 8, 12 or 16 bars (one per ~32 groove
bars, up to three, each inside one section on a four-bar boundary), plus the sparse stretches
every Chill rhythm part has. Rhythm is silent in about 37% of groove bars.

### Lead 1 — the sung line

Measured from the named vocal tracks and the flute channels that stand in for the singer, with
the reed lines for the counter-line. Phrases are open-ended — only 16% return to their starting
pitch — so Motorik Europe's closed-cell machinery is not used.

- `CHL-LD1-010` Soho counter-line 30%
- `CHL-LD1-012` Avalon 20%
- base Chill's `CHL-LD1-004` Blues lead 20%
- base Chill's `CHL-LD1-001` Long phrase 15%
- `CHL-LD1-011` Sustained tone 15%

**`010` Soho counter-line** — *Smooth Operator*, *Cherish the Day*, *Black Cow*. Flowing phrases
of about 8 notes in eighths and sixteenths, mostly stepwise, with rests of about a bar and a
half. Built from `counterLineCells`, the sax and flute figures at full weight — ascending thirds
and tones such as `[+3, +2, +2]`, neighbour-tone turns, descending answers — with a leap at most
cell boundaries, since leaps of a fourth or more are 17–20% of measured intervals. Phrase start
offsets and rest lengths vary per phrase.

The first phrase is the song's hook. It returns in about 35% of later phrases, never within six
bars of its last statement — seven to nine recognisable statements in a 110-bar song. Half the
returns are the hook itself: its rhythm, its place in the bar, its first pitch when that is in the
chord. The other half are one change from it, weighted as the corpus vocals vary a returning
figure — a note added 40%, dropped 28%, the rhythm moved 19%, a pitch moved a scale step 13% —
and a quarter of those start on another chord tone. A phrase the scale snap brings back to its
first pitch has its last note moved a step on.

The rule's cell and opening-rhythm picks pass raw counts to `weightedPick`, so every phrase is
built from `[0, 0, -2]` turned to follow the contour and opens on three eighths and a quarter.
This is deliberate: the shared opening turn and repeated notes are what tie the fresh phrases to
the hook and make the line sound like one song. With the bank properly weighted the line wandered,
and the hook stopped standing out (Zack, by ear, 2026-10-16). See `counterLinePhrase`.

**`011` Sustained tone** — *More Than This*, whose sax plays 13 notes in a whole song. Each phrase
is a short figure with one held note of 1–2.5 bars (weighted 22/32/28/18), the held note last
65% of the time and first 35%. Measured from every corpus phrase holding three beats or more,
the notes beside it are short, close (unison, a tone, a minor third) and two steps apart. A held
tone alone reads as a stall, so every phrase has its figure.

**`012` Avalon** — *Avalon*'s lead plays 13 phrases on three recurring contours, weighted 7/3/2:
a dominant figure and two foils. So each song has three hooks, weighted 55/25/20, differing in
note count and rhythm, drawn from `counterLineCells` (Avalon's hook is a flute line). Episodes
alternate them — `A B A` reads as a call and its answer where `A A A` reads as a copy — and the
next episode usually leads with the hook that answered. A figure that fails to move is repaired
rather than redrawn. Each song draws one treatment (a third of songs) or two (two thirds),
applied to all its hooks, giving fifteen song characters:

- `displace` — the figure starts off the downbeat, on even sixteenths
- `lengthen` — every note twice as long, with one or two interior notes kept short for motion
- `invert` — the moves upside down
- `reverse` — moves and rhythm backwards in time
- `extend` — the figure grows to 6–8 notes

About one figure in seven runs on with 2–3 extra notes, and a figure may end on a held chord tone
of a half, dotted half or whole bar (55% at phrase ends, 25% mid-phrase), ringing through a chord
change only on a common tone. The log reads, for example, `Avalon displace lengthen`.

Hooks come home. A mutation — one hook at a time, every 24–32 bars — is a variation on that
hook's original form: it plays for one or two episodes, then the original returns. The last
episode that can start leads with the opening hook in its original form, as Avalon and most of
the corpus end on their first figure.

Each episode starts on one of the chord tones nearest its section's home — a third of the way up
the range in the A section, a third or a fifth higher in B — kept far enough from the edges for
the hooks' reach, and every statement in the episode anchors near it, so a call and its answer
start together. On a displaced song, half the statements land an eighth either side of the song's
offset. The cell bank and opening rhythms are weighted properly here, unlike `010`.

**Reused:** `004` Blues lead and `001` Long phrase run base Chill's code, then take Soho's rest
windows, stretch cap and Remix pickup. A rest window that would land on a replayed seed moves to
just after it, so the seeds still come back about six times a song. St Germain staccato (`005`)
never plays here.

**Registers are per instrument** (`ChillLeadGenerator.register(for:)`), not per track — a tenor
sax tops out at 72 where Lead 1's general ceiling is 79. The harmonic filter's octave lift uses
the instrument registers, and anything still outside is folded back by octaves rather than
clamped, which would squash a melody onto one note.

### Lead 2 — the answer

- `CHL-LD2-001` Counter-melody 75% — answers in Lead 1's gaps, the singer-and-sax dialogue
- `CHL-LD2-002` Shadow hold 25% — a held chord tone under Lead 1 (*Cherish the Day*), with a short
  companion note beside 70% of holds, a unison or within a tone or two, leading in two thirds of
  the time. Used by base Chill too

Second voices measure 1.3–2.0 notes a bar, so Lead 2 is capped at 2 notes a bar, sits below
Lead 1 in register, and about a third of groove sections open with it sitting out for 8–16 bars.
A sax that replies to everything stops sounding like a reply.

### Pads

Pads measure one or two onsets a bar — mostly step 0 alone, held — with true voicings of 2–5
notes. Two of nine records have no pad at all (the Steely Dan ones, where horns and electric
piano do the job), which sets the weight of `000`.

- `CHL-PAD-000` No pads 20% — no pad notes anywhere in the song
- `CHL-PAD-007` Soho chord hold 20% — one 3–5 note chord a bar, anticipating onto step 15 in 15%
  of bars as *Your Love Is King* does, with a second onset on step 8 in about a quarter of bars
- `CHL-PAD-008` Half-bar pad 20% — *Smooth Operator*: 2–3 note chords on steps 0 and 8, each half
  a bar, which keeps a slow vamp moving against a clave
- base Chill's `001` Chord sustain 13%, `005` Slow chord build 11%, `006` String hold 7%, `002`
  Staggered entry 5%, `004` Open fifth hold 4%. Moby anchor (`003`) is excluded

Chill's pad rest windows then thin whatever plays, so pads have long absences. Held chords are
capped so the next attack is not cut off by the pad fade.

### Texture — horns and bells

Soho runs a MIDI Texture track instead of base Chill's audio loops. The corpus's rarely-firing
pitched parts (median under half a note a bar) split into two roles, and exactly one runs per
song:

- `CHL-TEXT-001` Sustained halo 45% — *Smooth Operator*'s synth pad plays five notes in 149
  bars. A few very long, high notes at section boundaries and over breakdowns, and every 16 bars
  in long sections. Half of them are two-note chords — the held tone over a chord tone a
  third to a sixth below, slightly softer — so one horn reads as a section; the rest stay single
- `CHL-TEXT-002` Punctuation stabs 55% — *Holding Back the Years*' brass. Horn figures struck
  once, twice or three times (53% / 34% / 12%) — *bap-bap*, *bap-baaa* — on every drum crash,
  and as lighter pickups on beat 4 at phrase ends. One horn playing a chord reads as a section, so
  accents are 3 notes 60%, 2 notes 34%, 1 note 6%; pickups 2 notes 50%, 3 notes 30%, 1 note 20%;
  turnaround stabs 2 or 3 notes evenly. Each song draws a home voicing (`StabVoicing`) — spread
  40%, close 35%, colour (a 9th or 6th in place of an inner note, refused if a semitone from
  another) 25% — and moves off it on about one stab in four

The stabs read the finished drum track, so they land with the crashes. Either rule also answers
the harmonic drone and groove pocket, and 55% of songs mark each turnaround with a stab.

---

## Groove fixup — every Chill song

The lead generators write on their own grid without reading the rhythm section, so a lead note
could land where the kick, the rim and the bass are all silent, and the line read as being in a
different time from the band. It was built for the Latin grooves, where that was most audible,
but runs on Lead 1 and Lead 2 of **every Chill song** once the other tracks are final — in
generation, `regenerateTrack` and `applyGrooveFixup` — through `SongGenerator.grooveFixup`:

1. **Placement** (`fixupLeadsToGroove`) — a note moves one sixteenth onto the eighth grid only
   when its position is metrically weak **and** the band rarely plays there. Both tests matter:
   a samba bass ties over beat 3, so beat 3 carries few attacks while staying the bar's second
   strongest position; and where the groove itself anticipates a beat, a lead note there is in
   step with the band. Only the onset moves — the note keeps its end point, never crosses a
   barline, and notes of a bar or more stay put
2. **Articulation** (`smoothLeadArticulation`) — closes one-sixteenth holes inside a phrase.
   Corpus horn and organ lines join flush 79–92% of the time; Chill's leads had single-sixteenth
   gaps, long enough to clip a note and too short to hear as a rest. Joins now run flush about
   90% in every Chill form
3. **Collisions** (`trimSamePitchOverlaps`) — ends a note before the same pitch re-attacks, since
   the sampler has one voice per pitch

`GrooveFixupOptions.standard` is in use: anticipations protected (`weakStep 0.05`), holes the pass
opened closed, same-pitch collisions resolved; second-choice targets, preferring played targets,
and legato overlap (`legatoOverlapSteps 0`) off — fluid lines come from flush joins, not overlap.
`.refined` turns everything on for A/B listening. The log reports `L1: 80/128, L2: 1/25 fixes`
or `No changes!`.

---

## Instruments

All three Chill forms share one instrument pool per track, so every picker lists the same
instruments and any song can be auditioned on any of them; `instrumentPickPoolStatic` sets each
form's random odds, and the single sanitiser (`AppState.sanitisedOverrides`) re-picks anything a
new song's form never draws. The Texture track is the exception — Soho's pool is MIDI horns, base
Chill's and Blues's is audio files.

- **Drums** — Brush Kit and Jazz Drums, 50/50. Never the 808
- **Bass** — Fretless 37.5%, Acoustic 37.5%, Elec Bass 25%. Fretless is the sound of the genre.
  Elec Bass takes the Low effect and plays at engine volume 0.40
- **Rhythm** — Rhodes, Stereo Piano, Nylon Guitar, Jazz Guitar and Funk Guitar, 20% each. Stereo
  Piano plays through a 1.4× rhythm boost in every Chill form (it was 2.0, too loud). Guitar
  is the corpus's dominant comping voice (Jazz Guitar in 8 of the 14 records, Clean Guitar in 7).
  Every guitar plays with a 4 Hz, 0.32-depth amp tremolo on by default, not the organ's Leslie;
  so does the Rhodes in Soho (2026-10-15), and any Rhodes with tremolo on uses that setting.
  Jazz Guitar is lifted with CC7 127 and a 1.5× rhythm boost; Funk Guitar is trimmed to CC7 80. Jazz and Funk Guitar were copied
  into `Zudio.sf2` from GeneralUser GS 2.0.3 with `tools/sf2_copy_presets.py`
- **Lead 1** — Tenor Sax 25%, Alto Sax 25%, Flute 24%, Soprano Sax 13%, Recorder 13%. Tenor is in
  6 corpus files, alto and flute in 4 each, the flute standing in for the singer. Chosen in
  `ChillMusicalFrameGenerator.pickLeadInstrumentSoho` and synced to the picker after generation.
  Delay off by default
- **Lead 2** — Alto Sax, Tenor Sax, Trombone, Synth Brass 1 (CC7 70) and Vibraphone (CC7 75),
  evenly, never the same as Lead 1. These are what answer the singer in the corpus; alto sax in
  four of seven songs
- **Pads** — Strings Slow 42% (the corpus's main sustained voice), Halo Pad 33%, Bowed Glass 25%
  (CC7 127). Choir and voice pads are out — artificial on this soundfont
- **Texture** — Trumpet 30% (CC7 80), Trombone 20%, Muted Trumpet 20%, Vibraphone 30% (CC7 60);
  real horns, no synth brass. Xylophone came out on 2026-10-15 — it never sounded like much — and
  its 10% went to Vibraphone. Panned 0.30 right, a horn section off to
  one side

**Effects:** lead vibrato on 20% of songs for saxes, open trumpet and trombone; reverb on Lead 1,
Lead 2 and Drums at 22 across Chill.

---

## Titles

`ChillTitleGenerator` builds Soho titles in eight forms — place, café, period, prepositional,
venue, late-night, paired nouns, gerund and clock — about 1,690 distinct titles. Banks: Soho
streets (Wardour, Berwick, Dean, Frith, Greek, Carnaby), London districts, Hull (where Tracey
Thorn and Ben Watt met), café words, period objects (Filofax, Walkman, Wine Bar) and venues. The
tone is light, continuing base Chill's wry register.

---

## How it fits into generation

- **Files:** `ChillMusicalFrameGenerator` (activation, groove, tempo, lead instrument),
  `ChillStructureGenerator` (intro, turnarounds, breakdown helpers), `ChillDrumGenerator`,
  `ChillBassGenerator`, `ChillRhythmGenerator`, `ChillSohoLeadGenerator` (Lead 1),
  `ChillLeadGenerator` (Lead 2, registers), `ChillPadsGenerator`, `ChillSohoTextureGenerator`,
  `ChillTitleGenerator`, `SongGenerator` (chord plan, breakdown choice, groove fixup, rule
  names), `AppState` (pools, odds, sanitiser, effect defaults)
- **Nothing else in Motorik, Kosmic or Ambient changes** beyond the harmonic filter's whole-figure
  lift, and base Chill and Blues reproduce their songs apart from the deliberate all-Chill
  changes: the groove fixup, Shadow Hold's companion note and the quieter Stereo Piano
- **Log:** the Chords line gives key, mode and A cycle (`Ab Aeolian Im7 – Vm7`); the Form line
  groove, sections and breakdown (`Soul groove - A/B - bass ostinato 4`); turnarounds are marked
  `Turnaround` with the treatment (`walking quarters`) on the bar the bass treatment plays; one Groove fixup row
- **Weighted picks:** `SeededRNG.weightedPick` expects weights that sum to 1. Picks over raw
  corpus counts go through `weightedIndex`, which normalises them; the one deliberate exception
  is Counter-Line (see `010`)
- **Harmonic filter (all styles):** when a lead sits within four semitones of the pads, Pass B
  lifts a figure an octave whole — notes less than a bar apart, found across the whole track and
  decided by the window it starts in — if any of it dips below the pads' median and all of it
  fits the register, so a figure never splits across octaves
- **Copy methods:** `SongStateCopyTests` compares every field before and after each SongState
  copy method by reflection, so a field a copy forgets fails the suite
- **Drum regen:** on a Remix Break song a regenerated drum rule is redrawn away from
  `ChillDrumGenerator.remixIneligibleRules` (Ballad Half-Time, Brush Kit), the same set the
  breakdown pick uses
- **Lead 1 randomise:** reads `ChillMusicalFrameGenerator.sohoLeadWeights`, the generator's table
- **Log — "Lead 1 return to form":** marked on each bar where a Chill lead comes back to its
  original form: `010`'s hook returning exactly, an Avalon episode led by the opening hook in its
  original form (after the song's first), or a base Chill seed coming back after the two opening
  replays (changed at most in its last note or a note length). Not marked where the bar already says "Lead 1 steps back", or where a later
  pass removed the notes. Re-marked when Lead 1 is regenerated. Recorded without drawing from
  the RNG, so no note changes
- **Instruments on replay:** a song is written to the persisted history only after its
  instruments are final, and replaying one re-pins the Chill leads to what the generator chose
- **Load paths (AppState):** `regenerateSong` is the one replay of a saved song (Songs list,
  startup preload, .zudio file), passing every recorded forced setting; `applyLoadedInstruments`
  and `configurePlaybackStyle` are the instrument and playback set-up every load runs. A forced
  texture (Chill's first song) and Ambient's Brush Kit are recorded in `forcedRules` so a replay
  sees them. `ReplayFidelityTests` pins replay note for note
- **Regenerated leads:** `HarmonicFilter.filterLead` and SongGenerator's
  `chillLeadSkippingBarZero` / `foldedIntoRegister` are shared by generation and regeneration

---

## Open items

- **Behind-the-beat feel.** Nothing in Chill shifts notes off the grid; everything lands exactly
  on its sixteenth. The Sade and Style Council sound depends on the rim and bass sitting a few
  milliseconds late with the hats on time. Proposal: a small per-track delay for Soho only — rim and
  snare +10–20 ms, bass +5–10 ms — which adds "relaxed" without changing a note
- **A Soho-specific ending**, floated, not taken up
- **Replay without the forced substyle.** Regenerating a saved song from history does not pass
  whether Soho or Blues was forced, so a forced song can come back as another form
- **Motorik base rhythm weights** sum to 1.02 — a negligible bias toward the earlier patterns
- **Fingerprint baseline** needs re-pinning: every Soho song, and the songs in every style whose
  leads the harmonic filter now lifts whole, differ from it deliberately

## Verification

- `bash tools/fpcheck.sh` fingerprints 300 seeds × 4 styles against
  `tools/fingerprints/baseline.txt`. Run after any change to shared code, and re-pin only when
  every difference is deliberate
- `swift test --filter ChillSohoTests` is the behavioural suite; `ChillLeadRegisterTests`,
  `InstrumentPoolDriftTests` and `WeightedPickTests` pin the registers, pools and weights

**Before a real release:** revert the 70/15/15 activation mix, and remove the ⌘J / ⌃G Groove
Fixup test toggle (`GrooveFixupTestMode.swift`, its menu item and key monitor).
