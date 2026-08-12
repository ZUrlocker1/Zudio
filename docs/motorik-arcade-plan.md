# Motorik Arcade — Design & Implementation Plan
Copyright (c) 2026 Zack Urlocker

## Naming

The name is **Motorik Arcade**. "Arcade" communicates high-energy, kinetic, machine-driven music without requiring genre knowledge — the classic arcade cabinet era plus the modern synthwave revival that references it. It's clearly distinct from "Noir" in mood.

---

## Musical Identity

Base Motorik is open-road and exhilarating — the Autobahn at speed, forward motion, bright. Motorik Noir keeps the pulse but turns it nocturnal and claustrophobic. Motorik Arcade takes the same engine and makes it frantic and mechanical — the sound of a machine in combat rather than a car on a road.

### Reference artists

**Jeff Minter / Imagitec Design — *Tempest 2000* (1994, Atari Jaguar)**
The spiritual anchor for the style. High-energy UK rave and techno — sample-based, loop-driven, 4-on-floor kick, driven arpeggios — with a "thumpin', no-compromises" quality that comes from kick discipline and pattern density rather than harmonic complexity.

**Megan McDuffee — Atari Recharged series (2021–present)**
The modern target. McDuffee's own description — "a blend of Grimes, Depeche Mode, and Massive Attack" — points at strong melodic leads and punchy mixes over short, loop-optimized tracks. Arcade aims for that same variety-within-a-style approach rather than one fixed sound.

**Carpenter Brut**
Wall-of-sound darksynth at 135–155 BPM, with short 2–4 bar lead riffs recycled as ostinato rather than developed melodically. Reference for the high-BPM ceiling and the riff-as-ostinato lead concept.

**Perturbator**
120–135 BPM darksynth with a 303-adjacent monophonic bass — filter automation, resonance. Reference for the Acid Sweep bass rule.

**Sonic the Hedgehog (Sega Genesis, composer Masato Nakamura)**
The clearest classic-arcade reference for the three-layer texture Zudio's own track architecture is built around: a driving bass ostinato, a fast arpeggio voice in the mid-register, and a melodic lead on top.

---

## MIDI Analysis Findings

Sixteen tracks were analyzed for BPM, mode, arpeggio density, and lead/bass interval distributions: three primary references that anchor the style, plus thirteen classic arcade/platformer tracks (Contra, Sonic, Mega Man, Castlevania, Street Fighter, Galaga) for supporting texture.

**Tempest 2000** is the "spot on" reference. It sits in Major/Ionian, its lead is built almost entirely from octave leaps (the #1 interval by a 5:1 margin over the next-most-common), and its arpeggio density runs 57% — the arpeggio texture is nearly continuous. Its bass is a pure root pulse.

**Raiden II** sits in Lydian — the raised 4th is what gives the shmup genre its celestial quality — with a wide, sweeping lead built from 6th leaps rather than steps, and an arpeggio density of 93%, essentially wall-to-wall.

**Gyruss**, the fastest track in the corpus at 170 BPM, sits in Harmonic minor (its baroque, Bach-adjacent character comes through directly), with P4/P5-dominant lead intervals producing a "galloping" quality, 71% arpeggio density, and a root-pulse bass with occasional P5 jumps for a more heroic push.

The **classic corpus** leans Mixolydian, clusters around 120–145 BPM, favors 3rd-based melodic movement in the lead, and — distinctively — contains chromatic-descent and chord-arpeggio bass patterns that don't otherwise exist anywhere in Motorik.

**What actually shipped:** the analysis pointed toward a bright-mode-heavy palette spanning Major, Lydian, Mixolydian, and Harmonic minor. What shipped uses Lydian and Mixolydian for that brightness, but drops Major and Harmonic minor from the final mode weights (see below). The three primary references' lead gestures each became a distinct Lead 1 rule — Tempest's octave leap became Octave Bounce, the corpus's 3rd-based movement became Arcade Riff, the broader arpeggio-density finding became Triad Climb — and the corpus's chromatic/arpeggiated bass patterns became Chrome Walk and Arcade Drive. The uniformly high arpeggio density across all three primary references is why Lead 2 leans on arp rules for 75–80% of its picks rather than staying in a supporting role.

---

## How It Differs from Base Motorik

- **BPM:** 130–160, peak 148 — a higher floor than base Motorik.
- **Mode:** Lydian, Mixolydian, Dorian, Aeolian, and Phrygian, weighted toward the bright end, paired with a matching bright/minor-conditioned chord progression family.
- **Song length:** runs shorter on average than base Motorik — the high BPM and arpeggio density are exhausting at greater length.
- **Lead 2:** active and prominent, leaning on dedicated arp rules most of the time — the opposite of base Motorik, where Lead 2 plays a thinner, more occasional role.
- **Pads and texture:** both present far more often than they're suppressed, favoring pulsed/staccato patterns over sustained atmosphere.
- **Drums:** built around a 4-on-floor kick (plus a phase-based no-kick variant) rather than base Motorik's Apache 1+3 pattern.
- **Bass register:** sits in the mid-range, heard as a melodic/rhythmic voice rather than a sub-bass rumble.

---

## How It Differs from Motorik Noir

| Parameter | Motorik Noir | Motorik Arcade |
|---|---|---|
| Tempo | Lower and more restrained | Higher, peaking at 148 |
| Mode | Aeolian-dominant, always minor | Bright-mode-dominant (Lydian, Mixolydian) with minor modes in support |
| Kick pattern | Apache or inverted | 4-on-floor, with a phased no-kick variant |
| Lead 2 | Suppressed toward silence | Active and arp-forward |
| Pads / texture | Suppressed in about half of songs | Suppressed less often |
| Bass register | Deep, sub-bass territory | Mid-register, heard melodically |
| Fills | Variable length | Always short, only at section transitions |
| Bass distortion | Can apply | Never applies |

---

## Cross-Track Coordination: How the Parts Fit Together

The Arcade sound comes from layering a handful of simple, mechanical parts rather than one complex one: a locked or phased kick, a rhythm-track arpeggio, a staccato Lead 1 motif, and — when there's room — a second, faster arpeggio on Lead 2. Left uncoordinated, that's a recipe for clutter — three or four busy voices all competing for the same rhythmic and harmonic space at once.

**This is the single most important coordination rule in the whole substyle: when Lead 1 picks one of its busiest, most arp-like rules — Arcade Riff, Pentatonic Blitz, Octave Bounce, or Triad Climb — both Bass and Lead 2 automatically back off into sparser roles for that stretch of the song.** Bass shifts toward its plainest, most locked-pulse rules (Moroder Pulse and Electro Pump become the dominant choices instead of the more melodically active bass rules). Lead 2 shifts toward its sparsest arp options, and there's a real chance it drops out entirely rather than adding a second busy voice on top of Lead 1. The result is that the arrangement always has exactly one clearly "busy" voice at a time — never three fighting for attention — which is what keeps the dense, arpeggio-heavy Arcade sound from turning into noise.

Lead 1's other new rule, Synth Hook, is deliberately excluded from triggering this pullback. It's phrased more like a call-and-answer hook than a dense arp, so it doesn't need the rest of the band to clear out from under it.

The exact per-rule weight shifts this coordination produces are called out in each rule's own description below (Bass and Lead 2 sections).

---

## Arcade Rule Catalog

Rules are grouped by track and listed in ascending ID order, with the actual coded selection weight for each. Rules marked *(shared)* are unmodified rules reused from base Motorik or Noir rather than written for Arcade specifically.

### Drums

**MOT-DRUM-001 "Classic Motorik"** *(shared)* — 15%
The standard Apache kick (beats 1 and 3), snare on 2 and 4, 16th-note hats. A grounding option that still works at Arcade's lower tempos.

**MOT-DRUM-005 "Albatross Grid"** *(shared)* — 15%
The same grid with one open-hat "breathe" moment before the downbeat, borrowed from the Noir catalog.

**MOT-DRUM-009 "Four-on-Floor"** — 16%
The defining Arcade kick pattern: kick on every beat, snare doubling it on 2 and 4, and a dense 16th-note hat pattern with an open-hat accent for lift. This is the pattern that makes Arcade read as techno rather than motorik.

**MOT-DRUM-010 "Machine Step"** — 14%
A lighter cousin of Four-on-Floor — same kick and snare, but a sparser, syncopated hat pattern that always reads as less dense, even at high intensity.

**MOT-DRUM-011 "Light Four"** — 25% (the highest-weighted drum rule)
Keeps the 4-on-floor palette from feeling relentless across a whole song by phasing the kick in and out — opening with a stretch of no kick at all, then cycling through kick-on and kick-off passages so a meaningful share of the song plays without a kick underneath. Hats and snare keep the groove alive through the kick-off stretches, so it never goes fully minimal.

**MOT-DRUM-012 "Sparse Fills"** — 15%
The most stripped-down option — a single quiet window early in the song with no kick at all, and plain timekeeping everywhere else. Built for songs that need a place to breathe.

Fills across every Arcade drum rule are always short and only appear at section transitions — there's no periodic body fill or instrument-entrance flourish.

### Bass

**MOT-BASS-001 "Root Anchor"** *(shared)* — 7%
Root on beat 1, chord tone on beat 3 — clean and locked.

**MOT-BASS-002 "Motorik Drive"** *(shared)* — 6%
Four staccato quarter notes, accented on the downbeats.

**MOT-BASS-004 "Hallogallo Lock"** *(shared)* — 6%
Root and fifth locked to the kick's 1-and-3 pattern.

**MOT-BASS-005 "McCartney Drive"** *(shared)* — 8%
An 8th-note locked groove built around a short descending phrase with a breathing pickup bar.

**MOT-BASS-008 "Moroder Pulse"** *(shared)* — 3% normally, but the primary choice (35%) whenever Lead 1 is busy
The plain locked 8th-note root — the Motorik "engine bass."

**MOT-BASS-010 "Quo Arc"** *(shared)* — 6%
A 2-bar boogie-woogie arc, up through the scale and back down.

**MOT-BASS-012 "Moroder Chase"** *(shared)* — 7% normally, 15% when Lead 1 is busy
The double-density 16th-note version of Moroder Pulse.

**MOT-BASS-022 "Chrome Walk"** — 16% normally, 12% when Lead 1 is busy
A 2-bar chromatic descent from the 5th down to the root, then a simple rooted resolve — one of the most distinctive bass patterns found anywhere in the classic-arcade source material, and something no other Motorik substyle does.

**MOT-BASS-023 "Acid Sweep"** — 15% normally, 3% when Lead 1 is busy
A 303-style acid-bass approximation cycling through root, fifth, and flat-7th, with its own filter sweep opening gradually across the phrase for that classic squelch-and-open acid quality.

**MOT-BASS-024 "Arcade Drive"** — 14% normally, 5% when Lead 1 is busy
A 1-bar arpeggio climbing up through the chord and back down — the most overtly melodic of the Arcade-specific bass rules, giving the bass a kinetic, forward-driving quality rather than a locked pulse.

**MOT-BASS-025 "Electro Pump"** — 12% normally, but the second choice (30%) whenever Lead 1 is busy
A sustained root on the downbeats with a short syncopated approach note in between — a Kraftwerk/early-Depeche-Mode-style pump rather than a purely locked pulse.

### Lead 1

**MOT-LD1-001 "Neu! Motif First"** *(shared)* — 3%
The opening statement of the classic Neu! motif, carried over at low weight for an occasional base-Motorik anchor moment.

**MOT-LD1-002 "Neu! Motif Repeat"** *(shared)* — 2%
The repeat pass of the same motif.

**MOT-LD1-005 "Call and Answer"** *(shared)* — 3%
The organic, varying call-and-answer rule from base Motorik.

**MOT-LD1-015 "Arcade Riff"** — 17%
The core Arcade lead concept: a 2-bar ascending staccato motif built mostly from 3rd-based movement, with an occasional wider leap at the peak. It repeats unchanged for a while, then can shift up a step for an "energy boost" moment. The repetition is deliberate — it's what makes the lead feel mechanical rather than developing.

**MOT-LD1-016 "Machine Answer"** — 13%
A 4-bar call-and-answer figure with exact mechanical symmetry — the "answer" is the literal reverse of the "call," rather than a varied response like the shared Call and Answer rule.

**MOT-LD1-017 "Pentatonic Blitz"** — 14%
A 1-bar cycle of fast ascending-then-descending 16th-note bursts, separated by short rests — the chiptune fast-arp aesthetic translated to a modern synth voice. It reads as a rhythmic accent more than a melody.

**MOT-LD1-018 "Octave Bounce"** — 17%
The defining Tempest 2000 gesture: a lead that bounces a chord tone up and down an octave with metronomic regularity, moving to a neighboring chord tone every couple of bars. Works across all five Arcade modes.

**MOT-LD1-019 "Triad Climb"** — 18% (the highest-weighted Lead 1 rule)
An ascending broken-chord arpeggio through the triad that climbs a step higher every couple of bars, rather than repeating in place — where Octave Bounce oscillates between two fixed pitches, Triad Climb keeps moving forward through the chord.

**MOT-LD1-020 "Synth Hook"** — 13%
A short diatonic call-and-answer phrase — not an arpeggio — followed by a couple of bars of silence that hand the spotlight to Bass and Lead 2. Because it isn't one of the "busy" dense-arp rules, picking it doesn't trigger the bass/Lead 2 pullback the way the other four new Lead 1 rules do.

Lead 1 also enters earlier in Arcade than elsewhere in Motorik, and is exempt from the spotlight-rotation thinning that other tracks get during solo sections.

### Lead 2

**MOT-LD2-001 "Counter-response"** *(shared)*, **MOT-LD2-003 "Rhythmic Counter"** *(shared)*, **MOT-LD2-005 "Descending Line"** *(shared)*
The three base-Motorik Lead 2 rules Arcade draws from when it isn't leaning on a dedicated arp — respectively a low-density counter-melody offset from Lead 1, short bursts placed in Lead 1's rhythmic gaps, and a slow descending 2-bar arc.

**MOT-LD2-007 "Arcade Arp"** — the primary Arcade textural differentiator
A continuous 16th-note arpeggio cycling through the current chord, staccato throughout, running in blocks with a short rest between them. It sits below Lead 1 in the mix, so it reads as texture rather than a competing melody.

**MOT-LD2-008 "Gate Arp"**
An 8th-note arpeggio at half the density of Arcade Arp, in a lower register — a gentler, more open "classic analog arpeggiator" feel.

**MOT-LD2-009 "Bounce Arp"**
A quarter-note bounce between the root and the 5th/octave — the sparsest of the three dedicated arp rules, for moments that need the chord marked without much textural busyness.

**MOT-LD2-010 "Blip"**
An ultra-sparse accent pattern — a root stab and a fifth stab per 2-bar block, then silence — that only ever appears when Lead 1 is already busy and the goal is to leave harmonic space rather than add another voice.

In a typical Arcade song, roughly three-quarters of Lead 2's picks land on one of the three dedicated arp rules (Arcade Arp, Gate Arp, Bounce Arp); the rest fall back to the shared base pool above. When Lead 1 is on a busy rule, that balance shifts further toward sparseness — there's a real chance of no Lead 2 at all, and what does play favors Blip and Bounce Arp over the denser options.

### Rhythm

**MOT-RTHM-006 "Arpeggio"** — 40% (dominant)
An 8th-note chord arpeggio cycling through the triad — the rhythm-track counterpart to Lead 2's arp rules. Having two arpeggiating voices at different registers and densities is a big part of what makes the layered arcade texture work.

**MOT-RTHM-001 "8th-note Stride"** — 20%
Locked 8th-note chord stabs — the mechanical chug.

**MOT-RTHM-007 "Chord Chug"** *(shared)* — 18%
Root-plus-fifth stabs on every 8th-note position, borrowed from the Noir catalog.

**MOT-RTHM-002 "Quarter Stride"** — 12%
The same idea as 8th-note Stride, but lighter — quarter-note chord stabs.

**MOT-RTHM-005 "Chord Stab"** — 10%
The standard chord stab pattern.

### Pads

Roughly a quarter of Arcade songs have no pads at all. When pads are active:

**MOT-PADS-003 "Pulsed"** — 35% (dominant)
A beat-1 chord "pump" synchronized to the kick — the primary Arcade pad.

**MOT-PADS-007 "Backbeat Stabs"** *(shared)* — 25%
Chord hits on beats 2 and 4 only, borrowed from Noir — where it reads as nervous and unsettled, in Arcade it reads as an energetic, syncopated accent.

**MOT-PADS-004 "Chord Stabs"** — 20%
Short, energetic stabs.

**MOT-PADS-001 "Sustained"** — 10%
A long-hold pad.

**MOT-PADS-006 "Half-bar Breathe"** — 10%
A short sustain with a mid-bar release.

### Texture

Roughly 40% of Arcade songs have no texture track. When active, one rule is picked from an equal-weight set — Spatial Sweep, Shimmer Hold, High Shimmer, High Tension Touch, and Pedal Drone — with a real chance a second one plays alongside it.

### Instruments

Each track draws from a restricted, equal-weight subset of the shared Motorik instrument pool. Base Motorik itself is largely unrestricted, so the more meaningful comparison is against Noir, which applies its own separate restriction on the same pool — instruments below marked *(Arcade-only)* are available to Arcade but not to Noir:

- **Lead 1:** Mono Synth *(Arcade-only)*, Saw Lead 3, Synth Lead, Saw Stack.
- **Lead 2:** Moog, Synth Lead, 5th Saw Wave.
- **Bass:** Lead Bass, Elec Bass *(Arcade-only)*, Mean Saw Bass, Techno Bass, Synth Bass 1 *(Arcade-only)*.
- **Rhythm:** Guitar Pulse *(Arcade-only)*, Synth Bass 3, Electric Piano 1 *(Arcade-only)*, Clavinet *(Arcade-only)*.
- **Pads:** Halo Pad, Sweep Pad, Synth Strings.
- **Texture:** Fifths Lead, FX Atmosphere, Solar Wind, Interference, Metal Pad *(Arcade-only)*, Ice Rain *(Arcade-only)*, Mystery Pad *(Arcade-only)*.
- **Drums:** Dance Drums, Machine Kit.

---

## Effects Defaults

Arcade doesn't have its own effects logic — it inherits base Motorik's defaults across the board: Lead 1 always carries delay plus a modest chance of Air; Lead 2 has a smaller chance of delay and otherwise stays dry; Pads always carry reverb-style Space plus a small chance of a filter Sweep; Texture stays panned; Rhythm always carries delay. The one place Arcade genuinely diverges is bass distortion, which base Motorik applies by default some of the time — Arcade is specifically excluded from that roll, so Arcade bass is never distorted by default (Acid Sweep's own built-in filter sweep is unrelated and still applies).

---

## Song Structure

There's no verse/chorus model in Zudio's Motorik generator at all — every Motorik song, including Arcade, is built from an **intro → body → outro** shape, where the body is either a single continuous section or splits into an A and a B section. Arcade favors having a B section far more often than base Motorik does, since a shorter, faster song benefits from that harmonic movement:

- **Intro:** a few bars of drums (and usually bass) only, entering in one of a few different styles — already playing, building in gradually, or a cold start.
- **A section:** the main body, or its lower-intensity first half when there's a B section too. Lead 1 comes in earlier here than it does elsewhere in Motorik, so the lead motif establishes itself quickly.
- **B section** (when present): higher intensity than A, and generated in a different mode — that mode change, not a chord progression or a verse/chorus device, is what gives a B section its lift. It's the closest thing Arcade has to a "drop."
- **Outro:** a short wind-down, ending cleanly rather than fading, in keeping with Arcade's short, section-transition-only fills.

---

## Mode and Harmony

Arcade picks from five modes — Lydian, Mixolydian, Dorian, Aeolian, and Phrygian — weighted toward the bright end (Lydian and Mixolydian together outweigh the three minor modes). The chord-progression choice is conditioned on which kind of mode got picked: bright-mode songs and minor-mode songs draw from separate sets of progressions, so they don't share harmonic vocabulary even though every rule in the catalog above is written generically enough to work correctly in any of the five.

---

## Title Generation

Short single-word titles have a high chance of getting a kinetic, machine-sounding suffix appended — words like Overdrive, Grid, Vector, System, Circuit, Zero, Warp. Multi-word or longer titles are left unchanged. Example: "Schmutz" → "Schmutz Grid".

---

## Reference: Motorik Noir as the Implementation Model

Motorik Arcade follows the same implementation pattern as Motorik Noir: a probabilistic substyle flag decided at song generation time, separate musical constraints per track generator activated by that flag, and `displayStyleName` returning "Motorik Arcade" in the UI. It went through several batches of listening tests across the full rule catalog, mode range, and BPM range described above before being considered ready.
