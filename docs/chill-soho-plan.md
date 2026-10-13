# Chill Soho — Design & Implementation

Status: **built, in 2.7 (build 132), tuning by ear.** The **Implementation contract** near the
end of this document is the authoritative description of what the code does; the sections before
it record what was measured from the corpus and why the rules are shaped as they are.

A third Chill presentation, after Chill Blues. Where base Chill is downtempo and house-adjacent
(Moby, St Germain) and Chill Blues is a 16-bar form, Chill Soho is the **British sophisticated
pop of the early 80s** — Sade, Everything but the Girl, The Style Council — built on a Latin
rhythm section that nothing else in Zudio uses.

---

## Naming

**Chill Soho.** Soho is where the London end of this music lived: the jazz-funk and Latin clubs,
the Wag Club on Wardour Street, the café culture the Style Council worked in. It names the scene
without naming a record, the same reasoning that settled Motorik Europe.

Checked against the Chill title bank: **Soho is free.** `London`, `Midnight`, `Nocturne`,
`Quiet` and `Soiree` all collide with it and are therefore unusable.

The genre's critical label is "sophisti-pop", which is a retrospective coinage the bands
themselves disliked. It is not used anywhere in this plan or in the UI.

---

## Musical identity

### Reference artists and songs

- **Sade** — *Smooth Operator*, *Your Love Is King* (Diamond Life, 1984); *The Sweetest Taboo*,
  *Is It a Crime* (Promise, 1985); *No Ordinary Love* (Love Deluxe, 1992)
- **Roxy Music** — *More Than This*, *Avalon* (Avalon, 1982). The precursor record; the
  atmosphere everything else here descends from
- **Everything but the Girl** — *Night and Day* (1982, the Cole Porter cover), *Each and Every
  One* (Eden, 1984). The clearest bossa in the reference set
- **The Style Council** — *The Paris Match*, *You're the Best Thing*, *Long Hot Summer*.
  *The Paris Match* features Tracey Thorn, which ties the two bands together
- **Steely Dan** — *Do It Again* (Latin-tinted minor vamp with congas) and *Black Cow* (Aja,
  1977) for the non-Latin half: a relaxed soul backbeat with Chuck Rainey's melodic bass well
  forward, which is the bass role this substyle wants. Cited for **groove, bass and texture
  only** — Steely Dan's harmony is far beyond the 2–4 chord vamp here, and *Deacon Blues* and
  *Peg* are out of scope
- **Simply Red** — *Holding Back the Years*. The laid-back end only; most of the catalogue is
  too brash for this substyle
- **Samba end** — Matt Bianco (*Half a Minute*), Basia (*Time and Tide*). The faster, brighter
  variant

### What defines the sound

- **Space is the genre.** Narrow dynamics, few instruments sounding at once, everything at
  mid-level. Restraint matters more than any single pattern
- **Harmony is jazz, form is a loop.** Minor 9ths, major 7ths, 11ths — but deployed as a two- or
  four-chord vamp that never modulates. Hypnotic rather than developmental
- **Bass is the second voice.** Fretless, melodic, unhurried. After the vocal it carries more
  melody than anything else in the arrangement
- **Latin rhythm section.** Rim-click clave, brushes, congas and shakers. Never a backbeat
- **Sax is the signature.** Mid-register tenor or soprano, a counter-melody rather than a solo

---


## Is Sade samba? No — and this matters for the beat rules

Sade is a **soft Latin-jazz sway**, not samba. *Smooth Operator* has a gentle shuffle with
congas over it; *The Sweetest Taboo* is half-time. The groove is Latin-tinted without being
Brazilian.

What is closest in the reference set to true bossa nova is **Everything but the Girl's
*Night and Day***, and the genuinely samba-leaning acts are **Matt Bianco and Basia**.

---

## Latin is a colour here, not the defining rhythm

An all-Latin substyle would misrepresent the genre. Laid against the reference set, the
genuinely Latin songs are a **minority**:

- **Not Latin at all** — *More Than This* (steady eighths, plain backbeat; its hypnotic quality
  comes from simplicity, not rhythm), *You're the Best Thing*, *Your Love Is King*,
  *No Ordinary Love*, *Holding Back the Years*
- **Latin** — *Night and Day*, Matt Bianco, Basia, and the conga tint on *Smooth Operator*
  and *Avalon*

So the substyle carries **five drum rules, roughly half Latin and half not**:

- **Bossa** — rim-click clave. The EBTG end
- **Latin sway** — half-time, sparse, conga-led. The Sade end
- **Soft samba** — busier, shaker-driven. The Matt Bianco / Basia end
- **Soft soul backbeat** — understated 2 and 4. *You're the Best Thing*, *More Than This*
- **Ballad half-time** — snare on 3 only, very sparse. *No Ordinary Love*

### Then what makes it distinct?

Not the drums. These hold across every reference, Latin or not, and they are what actually
carries the identity:

- a **2–4 chord vamp that does not modulate** — *More Than This* is essentially a two-chord verse
- **fretless bass as a melodic voice** — *No Ordinary Love* and Chuck Rainey's playing on *Aja*
  are both carried by the bass
- **sax as counter-melody**, never a blowing solo
- **chorused clean guitar** — the defining texture of *More Than This*
- **Rhodes and DX7**, never piano-forward
- a **narrow tempo band** and **low density**

The risk this creates is that the non-Latin half collapses into base Chill. It is avoided by
making those beats **new rules too**, differentiated by restraint rather than by pattern — no
ghost notes, slower, sparser — and by coupling the rhythm section to a single Latin/Soul
groove choice. See Soho groove.

**All rhythmic figures in this document are starting points from listening, not measurements.**
They need verifying against MIDI before implementation, the way the Kraftwerk cells and the
Motorik bass tables were. The numbers below are hypotheses.

---

## How it differs from base Chill and Chill Blues

- **Rhythm section.** Base Chill has eight drum rules and **none is Latin**. Chill Soho adds
  five new rules, roughly half of them Latin, and reuses exactly one base rule
  (`CHL-DRUM-003` Brush Kit) at low weight on the non-Latin half. Every groove is either new or
  restrained past where base Chill takes it.
  This is the single largest differentiator
- **Form.** Base Chill uses chord plans with movement; Chill Blues uses a 16-bar blues form.
  Chill Soho uses a **short cycle of 4–7 chords that does not modulate** — measured, see
  Corpus findings
- **Tempo.** Base Chill spans 72–124 depending on mood and beat style. Chill Soho is
  **84–128** — a wide band, because the corpus is bimodal
- **Bass role.** Base Chill bass anchors a groove. Chill Soho bass is a **melodic voice** with
  its own line
- **Density.** Lower than base Chill across every track
- **Mode.** Base Chill is Dorian 40 / Aeolian 25 / Mixolydian 20 / Ionian 15. Chill Soho pushes
  minor harder — see Mode and Harmony below

Reuse is deliberate but bounded, and gated on the groove — see Soho groove. The one
Latin-adjacent bass rule already in the style, **CHL-BASS-012 Rumba**, is **shared** with Chill
Blues rather than duplicated; the two use it differently, and the reasoning is under Bass below.

---

## Activation

A new `chillSohoVariation: Bool` on `SongState`, mirroring `chillBluesVariation`.

Roll in `ChillMusicalFrameGenerator` on a derived stream so existing songs still reproduce.
Chill splits **70% Soho, 15% Blues, 15% base**. Blues and Soho are mutually exclusive — a song is
never both.

`displayStyleName` returns `"Chill Soho"` when the flag is set, and the `.zudio` file carries it
on the `Substyle:` line. `Style:` stays `Chill` so the loader still parses it.

---

## Soho groove — the one coupling

`ChillBeatStyle` gains **two** cases, not five: `.sohoLatin` and `.sohoSoul`. One is drawn per
song, at **Latin 55% / Soul 45%**, matching the reference set.

That single value is the whole coordination mechanism. `ChillBeatStyle` is already on
`SongState` and is already passed into the drum, bass, rhythm and lead generators, so nothing
new has to be plumbed — each generator picks its pool from it:

- **`.sohoLatin`** — drums from Bossa Clave / Soft Samba / Latin Sway; bass from Bossa
  Root-Fifth / Syncopated Pocket / Rumba; rhythm from `CHL-RHY-007` / `008`
- **`.sohoSoul`** — drums from Soft Soul Backbeat / Ballad Half-Time / Brush Kit; bass from
  Melodic Bass / Syncopated Pocket / Syncopated Groove / Air Ostinato; rhythm from `CHL-RHY-007` / `008` /
  `005` / `006`

Within a pool the rule is an ordinary weighted draw, as everywhere else in Chill. The three
Latin drum rules are near-equal, which is where samba lands at about a third of 55%.

This is what guarantees the rhythm section agrees: a soul bass line can never appear under a
bossa clave, because the pools are never both open. It is one binary, read in three places.

**Tempo is independent of the groove.** One band for the whole substyle — **84–128, peak
around 100** — drawn separately, the way base Chill does it.

The original 88–108 was from memory and the corpus does not support it. Measured, the records
are bimodal: a slow cluster (*Cherish the Day* 80, *You're the Best Thing* 84, *Holding Back
the Years* 85, *Your Love Is King* 88, *Black Cow* 98, *Half a Minute* 106) and a brisk one
(*Smooth Operator* 121, *More Than This* 127, *Do It Again* 130). Nothing sits in a narrow band
around 98.

The brisk group does not *feel* fast, and that is the lesson: *More Than This* at 127 reads
relaxed because its hats are **quarter notes** and its bass plays four notes a bar. **Restraint
is not a function of BPM** — it comes from density on Bass and Lead 1, and from velocity and
touch on Drums and Rhythm (see Restraint comes from touch). A narrow slow band would have
excluded three of the strongest references for no musical reason.

The data does correlate tempo with groove — the Latin songs are the faster ones — but they stay
independent per the design decision, and one band covers both.

Tracks that do not carry the groove — Pads, Texture, Lead 1 — draw from one pool regardless, and
`CHL-RHY-008` is in both rhythm pools, because that texture is the constant across the
references.

**Not using the Motorik Europe `MotorikSync` type.** It carries track-set membership and
instrument subsets that Soho does not need — the substyle flag already restricts instruments —
and it exempts its tracks from arrangement thinning, which is the opposite of what this
substyle wants. The two-case groove above is the same idea at a fraction of the size.

---

## Rule naming

**Rule names describe the figure, never the instrument that plays it.** A rule is a pattern of
steps, durations and intervals; which patch it lands on is decided by the instrument pool and
can change without the rule changing. "Melodic Bass" rather than "Fretless Counter-Line",
"Single-Note Line" rather than "Chorused Guitar Figure".

Instrument preferences still belong in a rule's body — `CHL-BASS-013` noting that fretless
suits it is useful — but not in its name. Rule IDs stay canonical with no suffixes.

---

## Drums

### CHL-DRUM-009 — Bossa Clave

The defining rule. Rim click (side stick) carries the clave across two bars; hi-hat or ride runs
steady eighths; kick plays the dotted figure underneath.

- Rim click, 2-bar clave: steps **0, 6, 12** in bar 1 and **20, 26** across the pair
- Kick: steps **0, 6, 8**, plus **14** in ~60% of bars — the **measured** Latin kick from
  *Smooth Operator*, not the 3-3-2 tresillo the pattern is often described as
- Closed hat: steady eighths, steps 0–14 even, velocity alternating strong/weak
- No snare backbeat at any point. The rim click replaces it entirely
- Kit: Brush Kit or Jazz Drums

### CHL-DRUM-010 — Soft Samba

The Matt Bianco / Basia end. Busier, shaker-led, still restrained.

- Shaker: continuous sixteenths at low velocity, the engine of the pattern
- Surdo accent (low tom or kick): step **8** emphasised, step 0 lighter — the characteristic
  samba weight on the second half of the bar
- Rim click: steps 4 and 12
- Hat: offbeat eighths only, steps 2, 6, 10, 14

### CHL-DRUM-011 — Latin Sway

The Sade end. Half-time, sparse, conga-forward. The quietest drum rule in Chill.

- Conga: steps **0, 3, 6, 10, 13** — a loose tumbao-derived figure, velocity 50–70
- Rim click: step **8** only. One per bar, half-time
- Hat: steps 0, 8 — barely present
- Kick: step 0, and step 11 on alternate bars only
- Intended to leave the bass exposed

### CHL-DRUM-012 — Soft Soul Backbeat

The *You're the Best Thing* / *More Than This* rule, and the most likely to fire. **Both
references were measured and they agree on everything except the hat.**

- **Backbeat on steps 4 and 12**, every bar. Confirmed in both: *More Than This* snare 124/126
  hits on those two steps across 133 bars; *You're the Best Thing* splits the same positions
  between rim click and snare. Rim click preferred — a struck snare is too hard here
- **Kick on step 0**, plus **step 8** (*More Than This*) or a push at **step 7 into 8**
  (*You're the Best Thing*). Occasional step 14 pickup
- **Hat subdivision is a 50/50 variant, not a constant** — this is the one thing the draft got
  wrong. *You're the Best Thing* runs straight **eighths** (8.8 hits/bar); *More Than This*
  runs **quarter notes**, on beats only (4.1/bar). Both are correct for the style, and the
  quarter-note variant is the stronger signal of restraint
- Hat velocity 45–58 and flat
- **No ghost notes.** The entire difference from `CHL-DRUM-002`, and the thing to guard
- Kit: Brush Kit or Jazz Drums, never the standard kit

### CHL-DRUM-013 — Ballad Half-Time

The *No Ordinary Love* rule. The sparsest in the style, and the one that leaves the fretless
bass most exposed.

- Snare or rim click on step **8** only — beat 3, once per bar
- Kick: step **0**, and step **6** on alternate bars
- Hat: steps 0 and 8 only, velocity under 45, or absent entirely on a third of bars
- A single closed-hat or shaker sixteenth may lead into step 8 as a pickup, 25% of bars
- The sparsest rule in the style; works across the whole tempo band, best at its lower end

### Fills — rare, small, and mostly not kit

Measured by finding bars whose drum density spikes well above the song's median:

- *Black Cow* **1%** of bars · *Each and Every One* **1%** · *My Ever Changing Moods* **4%** ·
  *Smooth Operator* **5%**

**Nothing in this corpus plays a rolling sixteenth fill.** That is the headline. Fills are
roughly **one per 20–30 bars**, they last a bar or less, and they land on the **last bar of a
4- or 8-bar group** — `bar % 4` of 2 or 3 in every song measured.

Three types, all worth having:

- **Tom figure** — *Each and Every One* (+35pp toms in fill bars), *Black Cow* (+22pp). A short
  tom-around, not a roll
- **Snare pickup** — *My Ever Changing Moods* (+16pp snare, +5pp ride, +4pp crash). A couple of
  snare notes leading to a crash on the following downbeat
- **Percussion flourish** — *Smooth Operator* (+11pp cabasa and high percussion, kick actually
  *down* 6pp). **Not a kit fill at all**: the congas and cabasa flare while the kit holds
  steady. Latin pool only, and the most characteristic of the three

**Measurement caveat:** *You're the Best Thing* reads as 14% fills, but the over-represented
voice is the closed hat — that is hat-density variation, not fills. Density spikes alone do not
identify a fill; check which voice drives the spike.

**Implementation:** `ChillDrumGenerator` already carries `stopTimeFill` with A/B/C variants plus
`chillColdStartPickup` and `chillColdStopFill`. Map the tom figure and snare pickup onto those,
and add the percussion flourish as a Latin-only variant. Fire at **section boundaries only**,
not on a per-bar probability — at roughly 3–5% of bars, a random roll would scatter them.

This also supports preferring **stabs over a fill** on the Remix Break exit: the corpus has
plenty of unison hits and almost no fills.

### Existing drum rules

**Reuse: `CHL-DRUM-003` Brush Kit**, in the `.sohoSoul` pool only.

It is a ride quarter-note pulse with brush snare on 2 and 4, minimal kick, 3–5 events per bar —
restrained, brush-voiced and free of ghost notes, which is the profile the non-Latin half wants.
It is also the only base Chill drum rule that is not coded to a specific reference artist. It
gives the soul and ballad grooves a third colour without anything being written for it.

**Exclude the rest.** `001` Moby syncopated and `004` St Germain four-on-floor are coded to
their references. `005` hip-hop jazz is the wrong idiom. `006`, `007` and `008` are Chill Blues.

`CHL-DRUM-002` neo-soul deserves a specific note: it is the nearest neighbour to
`CHL-DRUM-012`, and excluding it is deliberate. It is **ghost-note driven with sixteenth hats**,
which is a 90s neo-soul signature rather than an 80s one, and running both would make the new
rule indistinguishable in the log while sounding busier than the references.

---

## Bass — the second voice

### CHL-BASS-013 — Bossa Root-Fifth

The signature bossa bass and the rule that should fire most often.

**Measured from *Smooth Operator*.** The record plays four to six short notes a bar, not the two
long ringing ones this bass is usually described as.

- Attacks on steps **0, 6, 8, 14** as the core figure, with **10** and **12** as secondary
  placements. Step 6 is the "and of two" and step 14 the pickup into the next bar
- **4–6 notes per bar**, not two
- **Short durations, 2–3 steps.** Median measured duration is 0.46 beats — detached, not
  ringing. Anything near 5–6 steps sounds sluggish here
- Octave drop on chord-change bars, 30% of the time
- Fretless Bass for preference

### CHL-BASS-014 — Melodic Bass

Bass as melodic voice rather than anchor. The Sade model.

- 4–6 notes per bar, drawn from chord tones plus the 9th and 6th
- Syncopated: avoids step 0 on roughly one bar in three, entering on step 2 or 3 instead
- Phrases of 2 bars with a 1-bar rest between — the bass breathes like a horn
- Slides implied by long durations into a repeated pitch

### CHL-BASS-015 — Syncopated Pocket

For the Latin pool, paired with Soft Samba. Movement without becoming a walking bass.

- Root on 0, approach tone on step 12, next root on the following downbeat
- Fills steps 6 and 8 on alternate bars
- Never a four-to-the-bar walk — that is jazz, not samba

### Measured bass behaviour — three rules

Interval histograms and step placement, measured across the corpus. (Phrase-splitting is the
wrong lens here: bass rarely rests a full beat, so `soho_lead_phrases.py --role bass` reports
whole songs as single 150–480 note "phrases". Use it for intervals, not for phrasing.)

**What every bass in the corpus shares** — the signature, and it holds across both halves:

- **Step 0 is always the strongest attack**, in every file
- **Step 6** ("and of two") and **step 14** (end-of-bar pickup) are consistently next
- **Note durations are short in the groove rules**: median 0.8–2.5 steps for `CHL-BASS-013` and
  `015` — these do not ring. **`CHL-BASS-014` is the exception** — see below
- **Repeated pitches dominate.** Interval 0 is the most common "interval" in every file
  (153–408 occurrences). These basses drive by rhythm and repetition, not by melody

Where they split is **leap content**, and that separates cleanly into three rules:

**`CHL-BASS-013` Bossa Root-Fifth** — the Latin, arpeggiated model. *Half a Minute* is the
extreme at **51% leaps of a fourth or more** (5th x154, octave x40); *Smooth Operator* and
*Do It Again* sit at 23%. Steps **0, 6, 8, 14** with 10 and 12 secondary. 4–6 notes/bar,
2–3 step durations, compass 17–24 semitones.

**`CHL-BASS-014` Melodic Bass** — the melodic, sparse, **sustained** model, and the one rule
that breaks the short-duration pattern.

Measured directly from the **Fretless Bass track** of *You're the Best Thing*, recovered once
the Guitar Pro files were read by track:

- **2.8 notes/bar** — roughly half the corpus median of 5.3. This is a sparse part
- **4.0 step durations** — a quarter note held, against 2–3 steps elsewhere. Sustained, not
  detached
- Steps **0** (dominant), then a cluster at **12, 14, 15**, with light weight on 4 and 8.
  Almost nothing on step 6 — which is where the Latin rules put their second attack
- Monophonic throughout

*More Than This* corroborates the character from the other direction: compass of just **12
semitones** and **18% leaps**, mostly stepwise. *Avalon* matches at 18% with octave drops as
the one wide gesture.

So this rule is defined by **space and sustain**, not by placement — the opposite of
`CHL-BASS-013`. The earlier spec of "steps 0, 6, 10, 12, 14" was inferred and is superseded.

**`CHL-BASS-015` Syncopated Pocket** — replaces the one-sentence walk-up draft. *Black Cow*
is the model: attacks on **steps 0, 3, 6** with further placement on **11 and 15** — genuine
sixteenth-level syncopation, the only bass in the corpus that plays off the 16th grid. Chuck
Rainey's playing, and the busiest bass measured at 5.3 notes/bar.

Assign by groove: `013` and `015` in the Latin pool, `014` and `015` in the Soul pool.

### Existing bass rules

**Reuse: `CHL-BASS-012` Rumba**, with `blues7th` forced **off**.

Its provenance is misleading — the code comment derives it from the Beatles' *Ballad of John and
Yoko* and calls it "laid-back jazz-blues pocket" — but the pattern itself is genuinely Latin:

- step **0** root, step **6** minor 3rd, step **10** fifth, step **12** sixth, step **14** tail

Step 6 is the "and of two", which is exactly where bossa and rumba bass place their second
attack, and root–m3–P5–M6 is a tumbao-adjacent shape rather than a blues line. The five-attack
cell with its descending velocity ramp (85 down to 71) is a real Latin pocket.

The one blues-coded moment is **step 12**, where the `blues7th` variant substitutes a ♭7 for the
major 6th on 20% of bars. That flag must be off in Chill Soho; the major 6th is the Latin
colour and the ♭7 is what makes it read as blues.

Sharing a rule with Chill Blues is acceptable here because the two use it differently — Blues
runs it inside a 16-bar form with the ♭7 substitution live, Soho runs it over a modal vamp
without.

**Also reuse:** `CHL-BASS-005` Breakdown root drone, for breakdown sections only.

**Also reuse, in the `.sohoSoul` pool only:**

- `CHL-BASS-002` Syncopated groove — a soul-pocket bass line, which is exactly what sits under
  `CHL-DRUM-012`. Low weight
- `CHL-BASS-004` Air ostinato — its 4-bar repeating figure is the right shape under a
  non-modulating vamp, and the repetition reads as hypnotic rather than static at these tempos.
  Low weight
- `CHL-BASS-001` Moby root sustain — lowest weight in the pool. Despite the name, a sustained
  root under a half-time snare is generic rather than Moby-coded, and it is the right bass
  under Ballad Half-Time

These three were excluded in the all-Latin draft because nothing in the style could carry them.
With the non-Latin half in place they have somewhere to sit, and they reduce how much new bass
code 2.7 needs.

**Exclude:** `006` Moby bass statement and `007` St Germain ostinato are coded to their
references. `008` Acid jazz chord-tone groove is the closest call — acid jazz descends from this
music — but it is busier than any reference here, so it stays out. `003` Walking approach is the
wrong idiom under both halves: bossa bass never walks, and the non-Latin references do not walk
either. `009`, `010` and `011` are Chill Blues rules.

---

## Rhythm — comping

### CHL-RHY-007 — Chordal Comp

With Bosa Moon excluded, this becomes **the only genuinely syncopated comping rule in Chill**,
which makes it more important rather than less.

**In both pools.** It was drafted as "Bossa Comp" and assigned to Latin, but the measurements
come mostly from *Soul* songs — *Black Cow*, *Your Love Is King*, *Holding Back the Years* —
with *Smooth Operator* the only Latin source. The figure is general, so the rule is general and
its name does not claim otherwise.

- Chord stabs on the clave positions: steps **0, 6, 12** with the two-bar answer at 20, 26
- Voicings: rootless, 7th and 9th in the right hand, no doubled root
- Short durations, 2–3 steps. Percussive rather than sustained
- Velocity 48–62. Sits under everything

### CHL-RHY-008 — Single-Note Line

The clean, chorused, muted single-note line characteristic of the genre. Never strummed.

- 2–4 notes per bar on offbeats, steps 2, 6, 10, 14
- Narrow range, mostly thirds and fourths apart
- Very short durations, 1–2 steps

### Measured comping behaviour

Two families, cleanly separated by **voicing size**. That turns out to be the discriminator,
not density.

**Chordal comp — `CHL-RHY-007`.** Voicings of **2–3 notes**, 7–13 notes/bar, durations 1.7–2.8
steps. Placement is consistent across every reference: **steps 0, 6 and 12** carry the weight —
beat 1, the "and of two", and beat 4 — with 4, 9, 10 and 14 as secondary.

- *Black Cow* ch1 (EP) 7.9/bar, voicing 2.1, hits on 0, 6, 12
- *Your Love Is King* ch0 (EP) 12.9/bar, voicing 2.5, hits on 0, 6, 9, 12, 14
- *Smooth Operator* ch2 (EP) 10.2/bar, voicing 2.1, hits on 0, 3, 4, 8, 10, 12, 14
- *Holding Back the Years* ch0/ch6 ~7/bar, voicing 1.9–2.0

**This validates the draft.** `CHL-RHY-007` already specified stabs on 0, 6 and 12 and short
2–3 step durations, from listening. The measurement agrees. What it adds is the **voicing size
(2–3 notes, rootless) and the density (7–13/bar)**, neither of which was specified.

**Single-note line — `CHL-RHY-008`, and the draft is wrong.** It was written as "2–4 notes per
bar on offbeats, steps 2, 6, 10, 14". Measured, these lines are **continuous and not
offbeat-confined**:

- *Avalon* ch8 8.6/bar, voicing **1.0**, hitting **every one of the 16 steps**
- *More Than This* ch15 4.6/bar, voicing 1.0, near-continuous
- *More Than This* ch8 5.4/bar, voicing 1.0, weighted to 0, 6, 10, 12
- *Do It Again* ch2/ch5 — continuous across all steps

Revised: a **continuous single-note line, 4.5–9 notes/bar, voicing strictly 1.0**, narrow
range, very short durations (0.07–0.48 beats). The defining property is that it is
**monophonic** — that is what separates it from the comp, not where it lands.

This also fits the velocity-not-density correction: a continuous line at low velocity is the
texture these records run under everything, and it is why `CHL-RHY-008` belongs in both pools.

### Existing rhythm rules

**Exclude `CHL-RHY-003` Bosa Moon — it is not a bossa.** The name comes from **Bosa in
Sardinia**, where the original song was written. It has no connection to bossa nova, and the
pattern bears that out. It plays an **even eighth-note arpeggio** at steps
0, 2, 4, 6, 8, 10, 12, 14, running up the voicing and back down, with a quarter-note variant
(0, 4, 8, 12) and a single-hit sparse variant.

There is no syncopation anywhere in it. Bossa comping is defined by chords landing off the beat
and anticipating the next bar; an even arpeggio up and down a chord is nearer an Alberti figure.
Worse, those even eighths would fight the clave the drums are playing. Recorded here so the name
does not tempt anyone to re-add it.

**Reuse:** `CHL-RHY-005` Chord Hold at low weight for variety.

**Also reuse: `CHL-RHY-006` Downbeat Pulse**, in the `.sohoSoul` pool. It plays a shell
chord on beats 1 and 3 with no syncopation, which is unremarkable under a Latin clave but is
precisely the comping on *More Than This*. It already pushes beat 3 early to the "and of two"
on 20% of bars and drops it entirely on 15%, so it is not as static as the name suggests. The
all-Latin draft excluded it for being plain; plain is the point here.

**Exclude:** `001` St Germain, `002` Moby Backbeat, `004` Acid jazz off-beat stab.

---

## Lead 1 — the sax voice

### CHL-LD1-010 — Soho Counter-Line

The signature lead. Mid-register, answering an implied vocal rather than soloing.

**Measured from the reed channels of the corpus.** Prose descriptions of this line ("long note
values, 6–12 steps") are off by roughly a factor of five and produce a rule that resembles no sax
line in the references. The numbers below are the measurement.

- **Phrase length: median 8 notes**, range 2–24. The draft said 3–5
- **Note duration: median 1.3 steps.** The draft said 6–12. This is the single largest error —
  these are flowing lines in eighths and sixteenths, not held tones
- **Rest between phrases: median 1.4 bars**, occasionally much longer. The draft said 2–4 bars
- **Motion is stepwise.** Intervals of 2 and 3 semitones dominate; leaps of a fourth or more
  are only **17–20%** of all intervals
- Compass 19–27 semitones, wider than the one octave first specified

### Phrases do NOT close — unlike Kraftwerk

**Only 16% of sax phrases return to their starting pitch** (16 of 97).

This matters for implementation. Motorik Europe's `kraftwerkCells` are closed figures that sum
to zero, and `realise`/`varyCell` in `LeadGenerator.swift` are built around preserving that
closure. **Do not copy that machinery here.** Soho phrases are open-ended: they land somewhere
new and let the harmony resolve underneath. Enforcing closure would produce a line that
circles rather than answers.

### Candidate cells

Interval figures that recur across the corpus, as semitone steps. These are a **starting bank
to vary, not a finished set** — see Implementation readiness.

- `[+3, +2, +2]` x29 and `[+2, +3, +2]` x24 — ascending scalar thirds-and-tones, the most
  common shape by a distance
- `[+2, +2, +1]` x22 — ascending to a semitone, a leading-tone approach
- `[+2, -5, +3]` x22 — **closed**. Up a tone, down a fourth, up a minor third: a turn figure,
  and the most useful of the closed shapes
- `[+3, +2, +2, +1]` x21 — the four-note extension of the first
- `[-2, +2, -2]` x20 — a neighbour-tone oscillation
- `[-3, -2, +2]` x18 and `[+1, -3, -2]` x17 — descending answers
- `[+2, +1, -3]` x17 — **closed**

**Caveat on the sample.** *Black Cow* contributes three reed channels and about half the notes,
and Steely Dan's horn writing is busier and more jazz-inflected than Sade's or Roxy Music's.
The aggregate is therefore skewed toward the most active line in the corpus.

### Vocal-derived cells — measured

Extracted from the named **Vocal** tracks. These supersede the aggregated sax bank above for
`CHL-LD1-010` and `012`.

**Repeated pitches are the defining feature, not noise.** `[+0, +0, +0]` is the most common
figure by a wide margin (x92), and `[+0, +0, +0, +0]` second (x55). These melodies sit on a
note and repeat it, then step away. **A generator that always moves will not sound like this
music** — which is the easiest mistake to make here.

Cells, with repeats included deliberately:

- `[+0, +0, -2]` x30 and `[+0, +0, +2]` x24 — repeat, then step
- `[+2, -2, +2]` x25 and `[-2, +2, -2]` x22 — neighbour-tone oscillation
- `[+0, +2, -2]` x19 — **closed**
- `[+0, -2, +2]` x17 — **closed**
- `[+0, +0, +2, -2]` x13 — **closed**
- `[-2, -1, +0]` x12 — chromatic descent onto a held note
- `[+2, -2, -3]` x12

**Rhythm template** — the part the sax bank was missing. Measured durations in 16th steps for
the opening four notes of a phrase:

- `[2, 2, 2, 4]` x26 — three eighths then a quarter. **The dominant shape**
- `[2, 2, 4, 2]` x10, `[2, 2, 2, 2]` x7, `[2, 2, 4, 4]` x6, `[4, 2, 2, 2]` x5

So: **eighths with a longer note at the phrase end**, which is what the original prose
intended and the sax data contradicted.

Phrase length: median **6–11 notes**. Closure ~15% overall, but *Each and Every One* reaches
38% — consistent with closure belonging to `CHL-LD1-012` Tight Hook.

### Why the vocal lines are the better Lead 1 model

Reading the Guitar Pro files by track recovered **named Vocal tracks** in three of them, and
they are much closer to what this substyle wants than the horn sections are:

- *Each and Every One* — **2.2 notes/bar**, 4.0 step durations
- *Missing* — 3.0 notes/bar, 3.0 step durations
- *My Ever Changing Moods* — 3.1 notes/bar, 2.0 step durations

That is **2–3 notes per bar with notes held 2–4 steps** — against the sax aggregate's 8-note
phrases at 1.3 steps. The vocal lines are sparser and more sustained, which is much nearer the
original prose intent of this rule than the horn data was.

These generations have no vocal, so a Lead 1 shaped like a sung melody is what makes the output
sound like a song rather than a backing track. Weight vocal-derived cells **above** sax-derived
ones when building the bank, and extract with `tools/soho_tracks.py`, which reports the track
name directly rather than guessing role from GM program.

### Three lead rules, not one

Measured per song rather than in aggregate, the corpus shows three incompatible behaviours.
Note durations alone span 0.8 to 47.6 steps — a factor of sixty. No single rule covers that.

**`CHL-LD1-010` Soho Counter-Line** — the figures above. *Smooth Operator* ch4,
*Cherish the Day* ch0, *Black Cow*. 7–8 note phrases, 1–2 step durations, 1–2 bar rests, wide
compass (29 semitones), **open-ended** (0/22 closed in *Smooth Operator*). Weight ~50%.

**`CHL-LD1-011` Sustained Tone** — *More Than This* ch5. **Thirteen notes in the entire song**,
median duration **47.6 steps** (nearly three bars), one note per phrase, rests of 5 bars and
more. A sax holding long tones, closer to a pad than a melody. Compass 12 semitones.
Weight ~20% — striking, and tiring if overused.

**`CHL-LD1-012` Tight Hook** — *Avalon* ch3. Phrase length pinned at **3–6 notes**, compass only
**10 semitones**, short rests (0.4 bars), and **30% closed**. A narrow repeating figure rather
than a line — it recurs and varies instead of developing. Weight ~30%.

### Closure is per-rule, not corpus-wide

Only 16% of Soho phrases close, which argues against porting Motorik Europe's closure machinery
wholesale. That aggregate is misleading.

Closure clusters in the **hook** behaviour — 10/33 in *Avalon* ch3, 6/38 in *Cherish the Day* —
and is absent from the counter-line (0/22 in *Smooth Operator*, 0/22 across *Half a Minute*
ch2 and *Black Cow* ch8).

So `varyCell`'s interval-preserving logic from `LeadGenerator.swift` **is** reusable, scoped to
`CHL-LD1-012` only. `CHL-LD1-010` and `011` must stay open-ended.

### Mine the vocal lines too

The flute and pipe channels in these transcriptions are mostly **the sung melody**, not a
second instrument — *Cherish the Day* ch0 (p74) is one, and it yielded clean phrase data.

They are currently filtered out as "not sax". That is backwards for this substyle. These are
instrumental generations with no vocal, so a Lead 1 that plays vocal-shaped melodies is what
makes the output sound like a song rather than a backing track. Extract from them deliberately
when building the cell bank, and label the source so the vocal-derived and sax-derived cells
can be weighted separately by ear.

### Existing lead rules

**Reuse:** `CHL-LD1-007` Wide interval solo, `001` Long phrase, `003` Sparse melodic solo,
`008` Warm jazz line. All four are melodic and leave space, which is what this substyle needs.

**Exclude:** `002` Short punch and `005` St Germain staccato burst are too staccato. `004` Blues
lead and `009` Jazzy blues lead belong to Chill Blues. `006` Bright melodic solo is optional at
low weight.

**Lead 2:** reuse `CHL-LD2-001` Call-and-response and `CHL-LD2-002` Shadow hold — no new
rules needed, but the **weighting must change**. See below.

### Lead 2 — measured

`CHL-LD2-001` answers in the gaps between Lead 1 phrases; `CHL-LD2-002` holds chord tones
underneath Lead 1 simultaneously. `ChillLeadGenerator` currently picks between them at
**50/50**.

**The corpus says call-and-response, strongly.** Measuring what fraction of the second voice's
notes sound while the main line is sounding:

- *Smooth Operator* 0%, *Your Love Is King* 1%, *Half a Minute* 2%, *Do It Again* 17%,
  *Black Cow* 20% — all call-and-response
- *Cherish the Day* 80%, *Avalon* 100% — shadow hold
- **Median 17%**

*Avalon*'s 100% is misleading: both voices have **exactly 159 notes**, so it is unison
doubling, not a shadow hold. That leaves *Cherish the Day* as the only genuine case.

**So weight `CHL-LD2-001` at ~75% and `CHL-LD2-002` at ~25%**, rather than the inherited 50/50.
The singer-and-sax dialogue is the sound of this music; a pad-like second voice sustaining under
the melody is the exception.

### What answers the lead

The main melodic voice in these transcriptions is almost always a **flute patch standing in for
the vocal** — *Black Cow*'s is named "vocal" on p73, *Cherish the Day*'s is named "Sade" on
p74. So the second voice is literally what answers the singer, and it is a **saxophone** nearly
every time:

- **Alto Sax (p65)** — *Smooth Operator*, *Avalon*, *Your Love Is King*, *Black Cow*. Four of
  seven songs, and the clear first choice
- **Tenor Sax (p66)** — *Black Cow*
- **Bari Sax (p67)** — *Half a Minute*
- **Synth Brass 1 (p62)** — *Your Love Is King*, as a third voice
- **Trombone (p57)** — *Black Cow*
- **Vibraphone (p11)** — appears as a *main* voice in *Smooth Operator*

**Density: Lead 2 is sparse, and should stay that way.** Measured notes per bar for the
answering voice:

- *Black Cow* tenor sax 1.3, trombone 1.3, alto sax 1.3
- *Your Love Is King* synth brass 1.3, alto sax 1.9
- *Do It Again* 1.5 · *Half a Minute* bari sax 1.8 · *Smooth Operator* alto sax 2.0 ·
  *Avalon* alto sax 2.0

**1.3–2.0 notes/bar**, always below the main line (1.7–3.0). And because `CHL-LD2-001` only
plays in Lead 1's gaps, the effective density across a whole song is lower still — this is a
part that speaks a few times and stays quiet.

Two consequences for the rule: cap it at **2 notes/bar**, and let it sit out whole sections
rather than answering every phrase. A sax that replies to everything stops sounding like a
reply.

**Register: Lead 2 sits below Lead 1.** Second voices measure at 58–65, main lines at 62–80 —
a gap of roughly 2–15 semitones. `ChillLeadGenerator` already enforces register separation, so
this confirms the existing behaviour rather than asking for new code.

Pool recommendation: **Alto Sax, Tenor Sax, Synth Brass 1, Trombone, Vibraphone.** (Baritone Sax, p67, is measured in *Half a Minute* but is **not in `Zudio.sf2`** and would play silent.)
---

## Pads

**Two new rules, and substantial reuse.**

**Reuse:** `CHL-PAD-001` Chord sustain, `002` Staggered entry, `004` Open fifth hold,
`005` Slow chord build, `006` Portishead string hold, and `000` Absent.
**Exclude:** `003` Moby anchor — coded to its reference.

**`000` Absent means the pad never appears in the song at all** — not that it plays sparsely.
Sparse is a different mechanism entirely: a pad rule that fires, then gets thinned by the 2.6
rest windows. Keep the two separate.

Measured, **2 of 9 songs have no pad track whatsoever** — about **20%**, and a reasonable
weight for `000`.

Both are **Steely Dan** (*Do It Again*, *Black Cow*), and the reason is instructive: those
arrangements use **horns and electric piano where the others use pads**. The pad is not missing,
it was never the plan. That suggests `000` should be weighted up when MIDI Texture draws a brass
patch, since the horns are then doing the pad's job — though keeping the draws independent is
the safer default, and the correlation is better confirmed by ear than assumed.

**Do not recount this from the raw corpus.** A naive count gives 6 of 13, but four of those six
are the Guitar Pro exports, which merge every pitched part onto one channel — their missing
pads are an export artefact, not a musical fact.

For everything else, the pad plays and the **2.6 rest windows thin it**. A pad audible in every
bar would undo the space this substyle depends on, but that is a thinning problem, not an
absence problem.

The rest-window pass added to `ChillPadsGenerator` in 2.6 applies unchanged and matters more
here than in base Chill — pads audible in every bar would undo the space the substyle depends
on.

### Measured pad behaviour

Pads were prose only. Measured across every pad and string channel in the corpus:

- **One or two onsets per bar.** The dominant placement is **step 0 alone** — one chord per
  bar, held. *Smooth Operator* ch10 uses **steps 0 and 8** (half notes). Nothing in the corpus
  plays a pad more often than twice a bar except *Avalon*
- **Voicing 1.5–4.9 notes, median ~2.1.** *Cherish the Day* ch4 is the archetype and the
  outlier both: **a single onset per bar carrying a 4.9-note voicing**, held across the whole
  bar. That is the sound this substyle wants
- **Durations 1.7–4.0 beats**, i.e. half a bar to a full bar
- **Density 1.2–6.2 notes/bar**, median around 2.3

**Anticipation is a real device.** *Your Love Is King* ch4 places its pad onset on **step 15** —
pushing into the following bar rather than landing on its downbeat. Worth building in at low
probability (~15% of chord changes); it is a large part of why these records feel unhurried
rather than square.

*Avalon* ch4 (6.2/bar, voicing 2.8, spread across offbeats) is the one pad that behaves like a
rhythm part. Treat it as out of scope — that arrangement has six pad-ish channels and is the
densest thing in the corpus.

### Voicing size is understated by the measurements

**Multi-channel pad stacks split one voicing across several channels.** *Avalon* has six
pad-ish channels; any single one measures 1.0–2.8 notes while the real chord is their sum.

The reliable guide is the songs with a **single** pad channel. *Cherish the Day* ch4 carries
**4.9 notes in one voicing** — a true chord, not a fragment. True voicings across the corpus
run **2–5 notes, median around 3**.

Do not read the per-channel 1.0 figures as "pads play single notes". Where a channel does hold
a genuine single sustained note in the upper register, that is `CHL-TEXT-001`, not a pad.

### CHL-PAD-007 — Soho Chord Hold

One onset per bar on step 0, voicing of 3–5 notes, duration a full bar, with a **15% chance of
anticipating onto step 15** of the previous bar, and a second onset on step 8 in roughly a
quarter of bars. The 2.6 rest windows then thin it further.

The signature pad and the one that should fire most often.

### CHL-PAD-008 — Half-Bar Pad

Measured from *Smooth Operator* ch10: onsets on **steps 0 and 8**, voicing 2–3 notes, each held
roughly half a bar (1.6–2.0 beats). Density 1.5 notes/bar.

Distinct from `007` rather than a variant of it: the chord restates mid-bar, which keeps a
slow vamp moving without adding density. It suits the Latin grooves, where a full-bar hold can
feel static against a clave.

Both continue the existing `CHL-PAD-000`–`006` numbering.

---

## Texture

**Chill Soho skips the audio textures entirely, as Chill Blues does, and runs a MIDI Texture
track instead.**

Base Chill routes Texture to an audio file: `SongGenerator.swift:3810` carries
`// Texture track: audio-only — no MIDI events generated here` and empties
`trackEvents[kTrackTexture]`. Soho branches there and generates MIDI events instead, the way
Motorik and Kosmic already do.

**The track is never absent.** It always plays — horns, bells or one of the other patches in
the pool below. There is no audio-versus-MIDI draw and no `CHL-TEXT-000` for this substyle.

The café ambience is a real loss and worth noting: *Another bar*, *Bar sounds* and *City at
night* suit a Soho café at midnight. But one track cannot be both, and pitched horn
punctuation does more for the arrangement than background noise does.

### Measured — the channels nothing else claims

Isolating every pitched channel under 1.3 notes/bar across the corpus gives 28 of them, and
they are a coherent group: **median 0.46 notes/bar, median pitch 66, median duration 2 steps**.
These are the parts that fire rarely and are remembered anyway.

They split cleanly by duration into **three texture roles**, two of them new.

**`CHL-TEXT-001` Sustained Halo.** Very long notes, very few of them, high register.

- *Smooth Operator* ch6 (synthpad): **five notes in a 149-bar song**, pitch 88, 16.2-step
  durations. The whole part is five events
- *Smooth Operator* ch5 (guitar) 0.17/bar, 13.3 steps; ch7 (synthpad) 0.40/bar, 7.9 steps
- *Holding Back the Years* ch10 0.07/bar, 5.1 steps; *Avalon* ch6 1.23/bar, 4.8 steps

Shape: **3–10 events in an entire song**, durations of 5–16 steps, register above the pads
(MIDI 72–88), entering at section boundaries and over breakdowns. This is a far sparser density
regime than anything else in Chill and closer to how Ambient textures behave — worth checking
`TextureGenerator` for a reusable mechanism before writing one.

**`CHL-TEXT-002` Punctuation Stabs.** Short, mid-register accents.

- *Holding Back the Years* ch3 (brass) 0.51/bar, **1.1-step** durations, pitch 67
- *Avalon* ch13 (synthlead) 0.35/bar, 1.9 steps; ch10 (guitar) 0.58/bar, 1.7 steps
- *Cherish the Day* ch1 (pipe) 0.12/bar, 1.2 steps

Shape: 2–4 note stabs, 1–2 steps long, landing at **section boundaries and the last bar of a
phrase** rather than distributed evenly. Brass is the idiomatic voice — the Style Council and
Simply Red both carried horn sections.

**This pairs directly with the Remix Break exit.** Horn stabs at a section boundary and the
unison band hits leaving the break are the same gesture; `CHL-TEXT-002` should fire on the break's
final bar alongside the drum stabs, so the punctuation is the full band rather than the kit
alone.

**Latin percussion overlay** — **part of the drum rule, not a separate track.** Conga, bongo,
shaker and cabasa are all GM channel-10 voices, so the overlay is extra voices inside
`CHL-DRUM-*` rather than anything that needs its own generator.

### Lead 2 is reserved for counter-melody

Punctuation and occasional stabs are not melodic writing and do not belong on a melodic track.
Loading them onto Lead 2 was the alternative, but Lead 2 carries the second melodic line in the
seven-track mapping, and a track doing three jobs is how a part stops having a character. Keep
Lead 2 for lines that answer Lead 1.

Because Texture is always MIDI here, the horn stabs are **always available** — including on the
Remix Break exit, where `CHL-TEXT-002` doubles the drum hits. No coupling between draws is
needed, which was the awkward part of the earlier audio-or-MIDI design.

### MIDI texture instrument pool

Instruments are drawn **independently of the rule**, so every patch must work for *both* texture
rules — long high halo notes and short mid-register stabs. That means a **fast attack with a
sustaining or long-decaying body**: no slow-attack strings or conventional pads (dead stabs),
no short-decay tuned percussion like marimba (cannot hold a halo).

**Brass leads the pool.** A horn section is the idiomatic stab voice for this music — the Style
Council and Simply Red both carried real horns — and a section patch sustains into a creditable
horn swell for the halo rule.

- ~~Brass Section (p61)~~ — **not in `Zudio.sf2`; would play silent.** Synth Brass 1 and 2
  carry the horn-section role instead, which is the more period-correct sound anyway
- **Synth Brass 1 (p62)** — *Your Love Is King* ch2. The 80s-synthetic end of the same idea
- **Synth Brass 2 (p63)** — fatter, more aggressive; good where the mix is already busy
- **Muted Trumpet (p59)** — *Holding Back the Years* ch3, at 1.1-step durations. The intimate
  solo alternative to the section
- **Vibraphone (p11)** — *More Than This* ch3. The best non-brass dual-purpose patch: rings
  when held, percussive when short
- ~~Clean Guitar (p27)~~ — **not in `Zudio.sf2`; would play silent**
- **Synth Lead (p85)** — *Avalon* ch13
- **Celesta (p8)** — not measured, but bells decay naturally so they serve both rules, and they
  suit the Roxy Music end

Five of these are measured in the corpus. No strings and no conventional pads.

### Deploying the stabs

`CHL-TEXT-002` fires on **specific structural moments**, not on a per-bar probability. Stabs
scattered randomly read as mistakes; stabs on boundaries read as arrangement.

Triggers, in priority order:

- **The last bar of a section**, before a change
- **The final bar of a breakdown**, doubling the drum stabs — see below
- **Every 8 or 16 bars** inside a long section, as punctuation
- Nothing else. A song should carry roughly 8–20 stab events total

### Doubling the drum hits

Making the stabs land with the kit is the whole point of having them, and it is mechanically
simple: **both rules read their step positions from one shared helper**, something like
`sohoAccentSteps(forBar:)`, deterministic on the bar index.

That avoids coordinating two independent RNG streams, which is the thing that usually makes
cross-track alignment fragile. The drum rule places its accents there; `CHL-TEXT-002` places
its stab there; they land together because they read the same function, not because two random
draws happened to agree.

The same helper serves the Remix Break exit, where the band hits on steps 0 and 8 and the
Lead 1 pickup answers in 10–15.

### How the two combine

Only **one** of the two rules should be active per song. Both are event-based and sparse;
running both turns Texture into a fourth rhythm part, which is the failure mode to avoid — *Avalon* has six pad-and-texture channels and is the densest, least
characteristic arrangement in the corpus.

---

## Instruments

Restrict each pool rather than adding anything new:

- **Lead 1** — Tenor Sax and Alto Sax weighted heavily, Muted Trumpet third. Drop Clarinet and
  Trumpet; both are too bright for this
- **Lead 2** — Alto/Tenor/Bari Sax, Synth Brass 1, Trombone, Vibraphone (measured; see Lead 2)
- **Bass** — **Fretless Bass** dominant, Acoustic Bass second, Elec Bass at low weight. The
  fretless is the sound of the genre
- **Drums** — Brush Kit and Jazz Drums only. **808 Kit excluded**
- **Rhythm** — Rhodes dominant, Wurlitzer second. Exclude B3 Organ, Perc Organ, Rock Organ and
  Tonewheel — all too churchy or rock-coded
- **Pads** — Warm Pad and String Pad

Per the instrument checklist, any pool restriction has to be applied in **both**
`instrumentPickPool` and `instrumentPickPoolStatic`, which are now a single table after the 2.6
consolidation, plus the sanitiser.

---

## Mode and harmony

Minor-leaning, more so than base Chill:

- **Dorian 50%** — the Latin-jazz mode, and Sade's default colour
- **Aeolian 30%**
- **Mixolydian 15%**
- **Ionian 5%**

Chord vocabulary is jazz: minor 9ths, major 7ths, 11ths, 6ths. Avoid dominant-function movement
and avoid anything that resolves strongly — the vamp should feel suspended.

**Harmonic rhythm is the structural signature.** Two chords alternating every 2 bars, or four
chords over 8, repeated for the whole section without modulation. This is the thing most likely
to make a generated song read as this genre rather than as base Chill played slowly.

---

## Song structure and bridges

- Longer sections than base Chill: the vamp needs time to become hypnotic
- **Breakdown style** — prefer `groovePocket` (percussion holds, bass and leads drop) and
  `harmonicDrone`. Avoid `stopTime`, which is too dramatic for the genre
- Cold starts suit this substyle; a bar of percussion before anything else enters is idiomatic
- No key change at the bridge. The vamp persists

---

## Title generation

Follow the existing Chill two-word pattern. All words below were checked against the current
Chill title bank and **none collide**.

**Soho streets** — Wardour, Berwick, Dean, Frith, Greek, Carnaby, Brewer

**London** — Fitzrovia, Marylebone, Mayfair, Camden, Islington, Hackney, Brixton, Portobello,
Ladbroke, Kensington, Chelsea

**Hull** — Hull, Humber, Hessle, Beverley, Spurn, Holderness, Cottingham, Hedon, Withernsea.
Tracey Thorn and Ben Watt met at Hull University, which is the reason this set belongs here

**Café** — Cafe, Espresso, Cappuccino, Latte, Macchiato, Croissant, Demitasse, Brasserie, Bistro,
Patisserie, Pavement, Terrace, Booth, Banquette, Formica, Saucer, Crema, Gaggia

**Period** — Filofax, Walkman, Wine Bar, Cassette, Pastel, Linen, Chrome, Neon, Discotheque

The existing Chill bank is wry — Escargot, Fromage, Cornichon, Pamplemousse sit beside real
Montreal place names. **Gaggia**, **Filofax** and **Wine Bar** continue that register and should
be kept in. The tone is light, not reverent.

---

## Corpus findings — measured from the MIDI

14 files, measured per MIDI channel with `tools/soho_analyze.py`. Where these contradict the
draft, the measurement wins and the rule above has been rewritten.

### Latin percussion is an overlay, not a pool divider

The single most useful finding, and it simplifies the design.

The draft treats Latin and Soul as two separate drum worlds. The records do not. Latin
percussion as a share of all drum hits:

- *Do It Again* 55%, *Half a Minute* 52%, **Avalon 46%**, *Smooth Operator* 37%,
  **Your Love Is King 25%**, *Cherish the Day* 7%
- *More Than This*, *Holding Back the Years*, *Black Cow*, *You're the Best Thing*,
  *Each and Every One* — all **0%**

*Avalon* and *Your Love Is King* are Soul-pool songs carrying heavy conga, bongo, maracas and
cabasa **over a straight kit**. The congas are not an alternative to the backbeat; they sit on
top of it.

So the model is **kit + optional percussion layer**, not two kits:

- The **kit** pattern comes from the groove, as designed
- A **Latin percussion overlay** is a separate draw **inside the drum generator** — conga,
  bongo, shaker and cabasa are GM channel-10 voices, so it is extra voices layered on whichever
  kit pattern fired. Probability ~85% under `.sohoLatin`, ~40% under `.sohoSoul`

This keeps the two-case groove while matching what the records actually do, and it keeps the
overlay on the channel that already owns those voices.

### Harmonic rhythm

Measured from the bass root per bar: chords change about every **1.0–1.5 bars**, with only
**5–7 distinct roots** across a whole song — not the "2–4 chord vamp" this music is usually
described as.

So the vamp is **harmonically narrow but rhythmically active** — a short cycle going round
quickly, not two chords held for four bars each. *Cherish the Day* is the extreme at **2 roots
over 110 bars**; *Do It Again* is the slowest-moving at 3.1 bars per change. The
"does not modulate" half of the claim holds strongly; the "2–4 chords" half does not.

This matters for Rhythm and Pads: a voicing held four bars will sound wrong against a cycle
that turns over every bar and a half.

### Seven tracks against ten-channel records

Channel counts: median 9, max 15 (*Avalon*). Selection is unavoidable. The roles that recur
across every arrangement map cleanly:

- **Drums** — kit
- **Bass** — always one channel, always distinct, 3.8–8.1 notes/bar (median 5.3)
- **Rhythm** — the main comp: Rhodes/piano or chorused guitar, 5–13 notes/bar
- **Lead 1** — sax or reed counter-line, **1.1–3.0 notes/bar**: a sparse counter-melody
- **Lead 2** — the second melodic line, present in most records
- **Pads** — strings/synth, 1.2–6.2 notes/bar, long durations (1.7–4.0 beats)
- **Texture** — MIDI horns or bells: `CHL-TEXT-001` halo or `CHL-TEXT-002` stabs

What gets dropped: the secondary comp guitars. *Black Cow* has three, *Avalon* six. One Rhythm
track carries that function; the rest is doubling that Zudio cannot and need not reproduce.

### Ruled out

- ***Missing*** — 123 bpm, 59% shaker, two channels. The 1994 Todd Terry house remix, not the
  *Eden*-era band. Wrong decade and wrong genre
- ***My Ever Changing Moods*** — 133 bpm, 0% Latin, snare-forward. Bright uptempo pop-soul,
  outside the style
- ***The Paris Match*** was first ruled out on a meter error; it is now **deferred**, see below
- ***Do It Again*** — kept for density and percussion share, but its **step data is unusable**:
  snare lands on 3 and 11 and hats on 3/7/11/15, a one-step grid offset that indicates a
  shuffle or triplet subdivision the 16-step reading cannot represent

### The Paris Match — deferred, not excluded

First measured as 6/4 and ruled out. That was an analyser bug: `soho_analyze.py` read the
time-signature numerator without the denominator, so **6/8 was barred as 6/4**, double its real
length. Fixed.

Measured correctly it is **3/4, 142 bars, 98 bpm** — a jazz waltz:

- kick on steps **0 and 2**, snare on **step 8** — a single backbeat on beat 3
- hats and ride straight eighths across all three beats, 5.8 drum notes/bar
- 0% Latin percussion

**The conversion to 4/4 is exact and lossless.** Four bars of 3/4 are three bars of 4/4, and
every onset in the file lands on a duple eighth — zero triplet placements — so nothing falls
between Zudio's 16 steps. Re-barred, the snare rotates through steps 8, 4, 0, 12 on a
three-bar cycle, which is one modulo on the global quarter count rather than a new mechanism.
It would also *sound* like 3/4, because meter is perceptual: if drums, bass and rhythm all
follow the three-quarter cycle, the listener hears a waltz wherever the engine puts its
barlines.

The obstacle is **structure, not groove**. A three-quarter cycle realigns with the 4/4 barline
only every three bars, so sections would have to be multiples of three bars. Chill's sections
are 4, 8 and 16, and a 16-bar section would strand phrases mid-cycle. That means changes in
`ChillStructureGenerator` plus three-cycle variants of every rhythm-section rule.

**Deferred rather than dropped.** One reference out of fourteen does not justify that reach in
2.7. If it is ever wanted, it is a third groove — `.sohoWaltz` — and the work is bounded and
understood. Its non-positional data is used meanwhile: 98 bpm sits inside the band, and it
corroborates the eighth-note hat and single-backbeat profile of the Soul pool.

### Guitar Pro exports

They are **Type 1 files with properly named tracks** — "Fretless Bass", "Rhythm Guitar",
"Vocals", "Drums". Nothing is merged. But all the pitched tracks share **MIDI channel 0**, and
`soho_analyze.py` groups by channel, so four real parts collapsed into one 35-note/bar blob
that looked like a merge.

`tools/soho_tracks.py` groups by track instead and recovers them. The track **name** is also
the most reliable role label in the corpus — better than inferring role from GM program or
pitch range, which is all the bitmidi files allow.

These are also simply **simpler arrangements** — four parts against *Black Cow*'s fourteen —
which is a property of the music, not of the export.

**What this unlocked**, measured per track:

- ***You're the Best Thing* has a Fretless Bass track.** The canonical reference for
  `CHL-BASS-014`, which this plan had listed as blocked. See Bass
- **Vocal melody lines** in three files, at 2.2–3.1 notes/bar — a far better Lead 1 model than
  the *Black Cow* horn section. See Lead 1
- **Guitar comping voicings** of 2.6–4.4 notes, against 2–3 for the keyboard comps

### Restraint comes from touch, not only from sparseness

*You're the Best Thing* is the clearest case and it corrects an assumption in this plan. It
runs **84 bpm with 23 comp notes per bar** — dense by any measure — and still reads as the most
relaxed track in the corpus.

What makes it relaxed is **rim click instead of a struck snare**, low velocities, and the slow
tempo. Not sparseness.

The plan leans heavily on low density as its restraint mechanism. That is still right for
Lead 1 and Bass, but for Rhythm it is the wrong lever: a busy comp at low velocity with a soft
backbeat is both authentic and characteristic. `CHL-RHY-008` allows a dense syncopated figure,
controlled by velocity rather than by note count.

---

## Breakdowns and bridges

These are instrumental songs over a non-modulating vamp, so contrast has to come from
arrangement. A 90-bar song on 4–7 chords needs a mid-song event.

### Remix Break — a new `ChillBreakdownStyle` case (proposed)

Breakdowns in Chill are **`ChillBreakdownStyle` enum cases, not numbered rules** — `stopTime`,
`bassOstinato`, `harmonicDrone`, `groovePocket`. This adds a fifth, `.sohoRemix`. There is no
`CHL-BRK-` prefix in the codebase and this plan should not invent one.

*Missing* was ruled out as a style reference — it is the 1994 Todd Terry house remix, not the
*Eden*-era band. But measuring it turned up a real link.

Its pattern: kick four-on-the-floor (steps **0, 4, 8, 12**, with 0 and 8 accented), clap on
**4 and 12**, open hats offbeat, and **shaker on all sixteen steps** at 7.3 hits/bar.

That shaker is the same device `CHL-DRUM-010` Soft Samba already specifies — "continuous
sixteenths at low velocity, the engine of the pattern". **The house track and the bossa rule
run the identical percussion layer.** Which is also why Todd Terry's remix works at all: he
kept the percussion and swapped the kit.

So the break is not a house section bolted onto a bossa song. It is *the shaker never stops and
the kit underneath it changes*, which makes entry and exit seamless.

Twelve to sixteen bars, mid-song:

- **Shaker continues unchanged** — the pivot
- Kick to four-on-the-floor, clap on 4 and 12, open hat on the offbeats
- Bass out for 2 bars, then a repeated root-octave figure
- Rhythm reduced to offbeat stabs; **Lead 1 silent**
- Pads sustain throughout as the harmonic anchor
- Exit by dropping the four-on-floor; the shaker carries the return

### Exiting the break — fill, pickup, lift

Entering is easy because it is additive. Exiting is where breaks usually sound clumsy, so the
last bar does three things at once over the continuing shaker:

- **Stop-time stabs or a drum fill, drawn 50/50** and compared by ear before either is made
  the default. Both ship as options; the weighting is a tunable constant, not a decision baked
  into the rule. Expected result is that stabs win — two or three **unison hits** — kick, snare
  and crash together on steps **0 and 8**, with silence between — rather than a rolling
  sixteenth fill, which is too busy for a style built on restraint. Stabs make the silence
  deliberate instead of a hole. Chill already speaks this vocabulary: the `stopTime` breakdown
  is "unison stabs on beat 1 of every other bar". `ChillDrumGenerator` detects `isLastBDBar`
  and carries `stopTimeFill` with A/B/C variants, so both options hook the existing path and
  neither needs a new mechanism. The Lead 1 pickup fires with **both** exits, so the A/B test
  isolates the drum behaviour rather than confounding two changes at once
- **Lead 1 pickup.** Lead 1 has been silent for the whole break, so its re-entry is the
  strongest cue available: 2–4 ascending notes in steps **10–15** of the last break bar,
  landing on the downbeat of the return. This is the measured end-of-bar pickup gesture — the
  corpus bass clusters at steps 12–15 going into a new bar — applied at section scale.

  **The two interlock.** With stabs on 0 and 8, the sax answers in the gaps at 10–15 and
  everyone lands together on the downbeat — the big-band shout-chorus exit, and how these
  records actually get out of a middle eight. Pick the stab steps and the pickup steps so they
  do not collide
- **A lift on the return**, using variants that already exist rather than a new groove:
  - **flip the hat subdivision** — `CHL-DRUM-012` carries quarters and eighths as a 50/50
    variant, so going in on quarters and out on eighths costs nothing and is clearly audible
  - **turn the Latin percussion overlay on**, or raise its density, if it was off before
  - **thicken Rhythm**, which is safe now that restraint is known to come from velocity rather
    than note count

**Do not change the beat style across the break.** Going in `.sohoLatin` and out `.sohoSoul`
would break the single-groove-per-song coupling and read as two songs spliced together. Vary
parameters within the groove, never the groove itself.

**Gating** — this is what stops it becoming a gimmick:

- **Only when the Latin percussion overlay is active.** No shaker, no pivot, no break
- **Only above ~105 bpm.** Four-on-the-floor at 84 is sluggish
- Never under Ballad Half-Time
- 20–25% of eligible songs

The percussion gate excludes the Style Council and Steely Dan material structurally rather than
by taste — those songs measure 0% Latin percussion.

### Other bridges

- **Percussion break** — all but kit and Latin percussion drop for 4–8 bars. The Latin
  *descarga*. Nearly free to implement
- **Rhodes/sax duet** — drums and bass drop, Rhythm and Lead 1 in dialogue. The most
  characteristic option, and the natural middle eight for *Avalon*-type material
- **Half-time drop** — the groove halves for 8 bars; a Sade device, and it reuses the Ballad
  Half-Time pattern

### Reuse from base Chill

Two existing `ChillBreakdownStyle` cases fit with no new code:

- **`bassOstinato`** — syncopated bass alone, drums and harmonic instruments silent. The best
  fit of the four, because fretless-as-melodic-voice is central to this substyle
- **`groovePocket`** — bass and leads drop, pads/rhythm/texture hold

`stopTime` and `harmonicDrone` are weaker fits but not excluded.

---

## Harmony — measured chord cycles

Extracted with `tools/soho_harmony.py`: root from the bass per bar, quality from the pitch
classes in the chordal channels, degrees relative to the song's most frequent root. Melody is
excluded, or a sung 9th would turn every bar into an extended chord.

**The single most important finding: these are not triads.** Almost every chord measures as a
**6th, 7th or 9th** — `Imaj9`, `Im7`, `IV6`, `Vmaj9`, `IIm7`. A plain major or minor triad
barely appears. This is the sophisti-pop signature and it belongs in the voicing code, not just
in the chord choice.

**The dominant form is two chords alternating, one bar each.** Use these six cycles:

**Minor:**

- **`Im9 | bVIImaj9`** — *Smooth Operator*. 5 roots total, this pair dominates
- **`Im7 | Vm7`** — *Cherish the Day* (**2 distinct roots in 79 bars**), *Holding Back the
  Years*
- **`Im7` modal** with occasional `IVm9` and `Vm7` — *Do It Again*. A single chord held for
  long stretches

**Major:**

- **`Imaj9 | IV6`** — *Avalon*, *Half a Minute* (which measures as a clean repeating 2-chord
  cycle)
- **`Imaj9 | Vmaj9`**, with a **`VIm9 | VIIm7 | VIm9 | Imaj9`** turnaround every 8 bars —
  *Your Love Is King*
- **`I6 | IIIm9 | IIm7 | V5`** — *More Than This*. The one 4-chord cycle worth having

Weight the two-chord cycles well above the four-chord one: five of the six references alternate
between two chords.

**Out of scope:** *Black Cow* (9 roots) and *Each and Every One* (11 roots). Steely Dan's
harmony was already excluded by the reference list and the measurement confirms it.

### The Guitar Pro files needed a track-aware reader

Reading these files by channel reports `?` for every quality, and its roots are not usable
either. Checked against the real Fretless Bass track of *You're the Best Thing*, the
channel-based reading got the root wrong in **60% of bars** — the
Rhythm Guitar has roughly 15 times more notes than the bass, so the most common pitch class in
a merged channel is usually a chord tone, not the root.

`soho_harmony.py` now groups by **track** where tracks are named, falling back to channel
otherwise, and identifies the bass part by track name as well as by GM program. That recovers
the Guitar Pro harmony properly and adds one cycle worth having:

- **`I | V | I | bVII`** — *You're the Best Thing*, tonic B, 7 roots. A major cycle leaning on
  the flat seventh, which is the Style Council sound and is not covered by any of the six
  cycles above

*The Paris Match* reads as `IVm9 | IIIM | bIImaj7 | I` repeating — a descending four-chord
cycle — but it is in 3/4 and deferred, so it stays out of the pool.

*Each and Every One* measures 8 roots and is too harmonically busy for this substyle, matching
its exclusion on tempo.

---

## Variation and space — the convention every track follows

**The corpus is more repetitive than Zudio should be, and that is not a contradiction.** These
records have a vocal, lyrics and a three-minute radio form carrying the listener. A Zudio song
is instrumental, often longer, and has none of that. A bass figure that is hypnotic for three
minutes under Sade is monotonous for six minutes under nothing.

So **measure the records for what the parts play, and follow Zudio's own conventions for how
often they change.** Motorik Europe is the worked example; the mechanisms below already exist.

### Bass — evolve every 12–18 bars

`BassGenerator` cycles three micro-variants on an 8-bar window so "A sections never go more
than 8 bars with the same pattern before a subtle change appears" — root quarters, then
root–fifth–root–root, then half-time.

Soho is slower and sparser, so stretch that to **12–18 bars**. The variant should be small:
drop the step-8 attack, move the step-14 pickup to 13, substitute the octave below on the
fifth. The figure stays recognisable; it just stops being identical.

Apply on top of this, not instead of it: B sections and anything past roughly bar 48 should
draw from a more active variant, as `BassGenerator` already does.

### Lead 1 — variation *and* long silences

Three mechanisms from `LeadGenerator`, all directly reusable:

- **`buildRestBars`** — one rest window per **~22 bars of body**, each **4–8 bars** long,
  slotted across the song so they spread rather than cluster, with at least 8 active bars
  before the first. The comment records why: a fixed window count meant "a 112-bar song got a
  single gap and the lead ran 19 bars without stopping"
- **`capUnbrokenStretch`** — finds any run longer than the cap and cuts a **2–3 bar** rest near
  its middle, "so the rest lands inside the phrase, not at its edge". Motorik uses
  `maxBars: 20`; **Soho should use 14–16**, because this substyle is built on space
- **`lead1PhraseReplay` + `mutatePhraseOnce`** — the phrase persists across episodes and
  mutates slightly on each return, "once per 4-cycle (16 bars)". For Soho, mutate every
  **8–12 bars**: the cells are short, so they wear out faster

The target is a Lead 1 that states a phrase, varies it on return, and **is simply absent for
whole sections**. Occasional single empty bars are not enough on their own.

### Drums and Rhythm — vary at structure, not at random

Neither should run 64 bars identical. Change on **section boundaries** and on **chord-cycle
turnarounds**, which is where a listener expects it:

- **Drums** — swap the hat subdivision (`CHL-DRUM-012` already carries quarters and eighths as
  a variant), add or drop the Latin percussion overlay, thin the kick in a quiet section
- **Rhythm** — the strongest variation available is **silence**. `CHL-RHY-008` running
  continuously for a whole song is the failure mode; drop it for 8–16 bars at a time. The
  existing `pickSparseFragments` in `ChillRhythmGenerator` already does this and should be
  weighted up for Soho

### Pads — long absences

`ChillPadsGenerator.applyRestWindows` from 2.6 applies unchanged: one window per ~18 bars,
alternating short (2–3 bars) and long (5–8 bars). That matters more here than in base Chill.

Combined with `CHL-PAD-000` at 20%, roughly one Soho song in five has no pad at all, and the
rest have substantial holes.

### The shape to aim for

A Soho song should not sound the same at bar 10, bar 40 and bar 70. At any moment some tracks
are out — that is what makes the arrangement feel written rather than generated, and it is the
main defence against a non-modulating vamp becoming wallpaper.

---

## Implementation contract

Everything by rule ID, in one place, as the code stands. **Where this disagrees with prose
earlier in the document, this section wins** — the prose records what was measured, this records
what was built.

### State

- `SongState.chillSohoVariation: Bool`, mirroring `chillBluesVariation`. **Every `withXxx()` copy
  method must pass it explicitly** or it silently defaults
- `ChillBeatStyle` gains `.sohoLatin` and `.sohoSoul`
- `displayStyleName` returns `"Chill Soho"`; `.zudio` writes it on `Substyle:`, `Style:` stays
  `Chill`
- Soho draws on derived RNG streams (`SeededRNG.trackSeed`, indices 90–98) so adding Soho
  behaviour cannot shift base Chill's main stream. The pattern is: make the base-Chill draw,
  discard the result, then use the derived stream

### Activation, tempo and mode

- Chill splits **70% Soho / 15% Blues / 15% base** (Zack, 2026-10-13). Blues and Soho are
  mutually exclusive. Blues takes its 15% first, on the main stream;
  `ChillMusicalFrameGenerator.sohoShareOfNonBlues` is `70/85`, the Soho share of what is left.
  Measured over 4,000 songs: 70.0% / 15.2% / 14.8%
- Blues moved from 20% to 15% to make room. That draw is on the main stream, so it is the one
  Soho-era change that reclassifies existing Blues songs: **11 of 300 baseline seeds stop being
  Blues** (none become Blues), 8 of them becoming Soho and 3 base Chill
- Groove: **`.sohoLatin` 55% / `.sohoSoul` 45%**, drawn once per song
- Tempo: one band, **84–128, peak ~100**, independent of groove
- Modes: base Chill's weights — **Dorian 40%, Aeolian 25%, Mixolydian 20%, Ionian 15%**, giving
  65% minor keys and 59% minor chord-bars. The substyle's character depends on that balance;
  brightening it toward 47% minor loses it

### Song structure

- **Intro: 4 bars, or none in 15% of songs.** Never 8
- The four bars **build**, one layer a bar: the drum rule's own voice, then the Latin percussion
  and the low end, then the Rhythm track, then the bass figure, with a fill across the last beat
  and a crash onto the downbeat of A
- Which of the bass and the comping enters first **alternates per song**, from
  `ChillStructureGenerator.sohoBassLeadsIntro(frame:structure:)` — a pure function, because the
  two generators run on different streams and cannot share a draw. Whichever leads enters on the
  intro's second-to-last bar, the other on its last
- A **cold start** spends the intro's first bar on a drums-only pickup, so layers are counted
  with `ChillStructureGenerator.sohoIntroLayer(bar:structure:)`, which returns −1 for that bar

### Turnaround

Four bars of chord detour **inside** the groove, not a section. At the end of every 16-bar phrase
in 60% of songs, at section ends only in the other 40%:

- Ionian — `IIm9 – IIIm7 – IIm9 – IVmaj9`
- Mixolydian — `IIm9 – Vm7 – IIm9 – IVmaj9`
- Dorian — `IV9 – Vm7 – IV9 – Im`
- Aeolian — `IVm9 – Vm7 – IVm9 – Im`

The major shapes carry three minor chords out of four, which is most of why a major-key song
still reads 21% minor by the bar.

Every chord is diatonic, so nothing needs snapping. `ChillStructureGenerator.sohoTurnaroundBars`
reads them back from the finished chord plan by matching roots; the shaker
rests, the bass approach, the drum fill, the horn stab and the log annotation all key off it.

The band performs it: **bass approach** on the exit bar, **drum fill** on 60% of exits,
**horn stab** on the downbeat in 55% of songs, **shaker silent** throughout.

### Breakdowns

`ChillBreakdownStyle` gains `.sohoRemix`. Stop-time is excluded — it is base Chill's own gesture.

- **Remix Break** — eligible only when the Latin percussion overlay is active **and** tempo > 105
  **and** the drum rule is not `013` or `003`. Fires in **33%** of eligible songs — about one
  Soho song in fourteen — and runs **6, 8 or 12 bars**
- Its backbeat voice is drawn per song: **handclap 45%, tambourine 30%, side stick 25%**. The
  pattern stays on beats 2 and 4; only the voice changes, because every break sounding identical
  is what gives the device away
- Otherwise **bass ostinato 45%, groove pocket 30%, harmonic drone 25%**
- **Into the remix**: the band stops after beat 2 of the bar before and hits beats 3 and 4 in
  unison — drums, bass and rhythm on the same two steps — with a crash on the break's downbeat
- **Out of it**: unison stabs on steps 0 and 8 of the last bar, or a fill, 50/50. Lead 1 picks up
  on steps 10, 12 and 14 either way
- **Groove pocket** is a percussion feature in Soho: under a Latin groove the kit steps back to
  the kick and the hand percussion comes forward; a Soul groove keeps its rule and takes handclaps
- **Harmonic drone** and **groove pocket** are answered by the horns — neither has a voice
  otherwise

### Drums

Latin pool — `009` 40%, `010` 30%, `011` 30%.
Soul pool — `012` 55%, `013` 25%, `003` 20%.

**Latin percussion overlay** (`CHL-DRUM-014`) is a second draw inside the drum generator, layering
conga, bongo, shaker and cabasa on whichever kit pattern fired: **85% under `.sohoLatin`, 40%
under `.sohoSoul`**. It plays through the groove, the intro from its second layer, and the outro.
It is not a separate track.

**Shaker rests.** Left alone the shaker runs 86–96% of bars, in unbroken stretches as long as the
song. It now stops in three places, keeping it around **68% of bars and never below 60%**:

- every four-bar turnaround
- one or two windows per section of 8, 12 or 16 bars, opening on the bar after a turnaround
  resolves, or on a four-bar phrase boundary where a song turns around only at section ends
- the four or eight bars leading into a breakdown

Rests are capped at **33% of the song's bars** so the shaker is lightened, not removed. A window's
return bar takes a crash.

### Bass

Latin pool, minor — `013` 35%, `012` Rumba 25% (**`blues7th` forced off**), `015` 20%, `016` 20%.
Latin pool, major — `013` 35%, `015` 35%, `016` 30% (Rumba is minor-only; its third and sixth are
snapped to the scale on the Soho path).
Soul pool — `014` 23.5%, `017` 23.5%, `015` 23%, `002` 15%, `004` 10%, `001` 5%. The three
borrowed from base Chill are **capped at 30% between them**.
Breakdowns — `005` root drone, both pools.

Every rule evolves on a **12–18 bar** micro-variant cycle.

**Turnaround treatment.** The bass stops playing the groove for the turnaround's **last two
bars** and plays a turnaround. One of three figures, named in the performance log:

- **walking quarters** — four quarters a bar: the root, two scale steps toward the next chord,
  then a chromatic leading tone into it. Where the next chord is only a step away, the middle
  notes arc away and back rather than repeating the root
- **root & approach** — the root held through the bar with a two-note pickup into the next chord;
  sparser than the groove, so the turnaround reads as a clearing
- **descending** — one scalar descent across both bars, two notes a bar, arriving a step above
  the chord the phrase restarts on
- **root pedal descent** — the same descent with the chord root pedalled under it: the root short
  on the beat, the descending note answering on the eighth and ringing through to the next cell,
  "ba-baa, ba-baa" (Zack, 2026-10-12). A true **pedal point** — one note under all four pairs,
  the turnaround's first bar's root at its lowest instance in the 40–52 bass window, held through
  the chord change between the two bars
- **pedal descent** — the same, but each bar pedals its *own* chord root, so the pedal re-roots
  mid-figure

The pedal must not move: a root that changes octave mid-figure lurches by a seventh or a ninth,
and that is the first thing a listener hears. Holding one note matters more than always sitting
under the line.

Two notes in a row at the same pitch read as one repeated note rather than as an alternation, and
are eliminated entirely. A pair whose pedal would equal the line note on either side of it
**drops its pedal** and plays the line note alone; 78% of pedal slots are filled, and no figure
loses all four. The **line is never moved** to dodge the pedal — its last note has to land a step
from the chord the phrase restarts on, and lifting it breaks that resolution. Nor is the root
lifted out of the bass register: it stays within 40–52.

**Which treatments a song uses.** `sohoTurnaroundPalette(frame:structure:)` draws two treatments
(56% of songs) or three (44%) from the six, and `sohoTurnaroundStyle(frame:structure:index:)`
gives the first turnarounds the palette's entries in order so each one is actually heard, then
repeats from the same palette. Across 251 songs carrying four turnarounds, none plays the same
figure throughout and none plays four different ones. Usage runs 13–20% per treatment.

Two bars rather than four: a turnaround fires every 16 bars in most songs, and four would put the
bass out of its own part for a quarter of the song. The way into a Remix Break takes precedence
where a bar is both.

**The treatment varies within the song.** A long song carries four or five turnarounds, and the
same figure at every one of them reads as mechanical. Only the **first** turnaround
uses the song's primary treatment; each later one steps to a figure the previous turnaround did
not play, and about a quarter of them use the **original form** — no figure at all, the groove
rides straight through the chord detour. Over 300 songs the mix is roughly 23% descending, 22%
root & approach, 21% walking quarters and 14% original form. `sohoTurnaroundStyle(frame:
structure:index:)` is pure, like the song-level picker, because the bass generator and the
performance log need it on different streams.

### Rhythm

Latin pool — `007` 45%, `009` 30%, `008` 25%.
Soul pool — `007` 30%, `008` 30%, `005` 15%, `006` 15%, `009` 10%.

`007` is in both pools. A and B always take different modes, so a Latin song plays two of the
three.

**Silence is the strongest variation this track has.** Every Soho song gets long dropouts: one per
~32 groove bars, up to three, each 8, 12 or 16 bars, each wholly inside one A or B section on a
four-bar boundary, at least 4 bars apart, never in the first 8 or last 4 groove bars, and never on
a section's last bar. With the sparse stretches and rest bars, Rhythm is silent in about **37% of
groove bars**.

### Lead 1 — groove-independent

`010` Counter-Line 30%, `012` Tight Hook 20%, `004` Blues lead 20%, `001` Long phrase 15%,
`011` Sustained Tone 15%.

`004` and `001` are base Chill's, generated by base Chill's own lead code including its intro and
breakdown behaviour, then given Soho's rest windows, stretch cap and remix pickup. St Germain
staccato (`005`) never plays here.

Counter-Line draws on its own cell bank — the sax cells at full weight rather than a third — and
places a leap at most cell boundaries, because the cells never step more than 3 semitones and the
measured line leaps on 17–20% of intervals.

### Lead 2 — groove-independent

`CHL-LD2-001` Call-and-response **75%**, `CHL-LD2-002` Shadow hold **25%** — measured at 17%
median overlap across the corpus. No new Lead 2 rules; punctuation belongs on Texture.

Pool: Alto Sax, Tenor Sax, Synth Brass 1, Trombone, Vibraphone, never the same as Lead 1.
**Synth Brass 1 is at CC7 70** — it is the loudest patch in that pool. **Vibraphone is at CC7 75**, set on the name so it applies to Lead 2 in *every* Chill form, base and Blues included, which share a pool carrying it (Zack, 2026-10-12); it matches the cut the texture track's vibraphone takes, for the same reason. Baritone Sax is measured in
the corpus but is not in `Zudio.sf2`.

**Density cap 2 notes/bar**, and a 35% chance of sitting out each groove section. Regeneration
keeps the song's instrument, because playback still has that patch loaded.

### Pads — groove-independent

`000` Absent **20%**, `007` 30%, `008` 15%, `001` 12%, `005` 10%, `006` 6%, `002` 4%, `004` 3%.
Excludes `003`. The 2.6 rest windows then thin whatever fired.

**`000` means absent**: no pad notes anywhere, not even in the breakdown. (Base Chill's `000`
still plays breakdown pads. That contradicts the ruling but is left alone — changing it would
alter released songs.)

Holds are bounded by the pad fade: every Chill pad note fades over a quarter of its length before
it is stopped, so a chord restruck on the same pitches must leave a longer gap or the delayed stop
cuts off the new attack. That caps a once-a-bar hold at 12 steps.

### Texture — groove-independent, always MIDI

`CHL-TEXT-001` Sustained Halo 45%, `CHL-TEXT-002` Punctuation Stabs 55%. Never absent, never
audio — Soho skips the audio texture path entirely. Exactly one rule per song.

**Stabs are figures, not single chords.** Two or three notes sounding together is still one
"bap"; the rhythm has to carry it. Each stab is struck 1–3 times — *bap-bap*, *bap-baaa*,
*bap-bap-baaa* — at **53% one hit, 34% two, 12% three**. All notes of a hit share one length.
Accents land on every drum crash, 1–3 notes thick; phrase-end pickups land on beat 4 of every
8–16 bar phrase, lighter, capped at two hits, and skip any bar already carrying a crash.

The horns also answer the harmonic drone and the groove pocket, and mark the turnaround in 55% of
songs with a single hit.

### Instruments

Soho has its own pools where base Chill's are wrong:

- **Texture**: Trumpet 30%, Trombone 20%, Muted Trumpet 20%, Vibraphone 20%, Xylophone 10% —
  brass leads at 70% of picks, the two mallets are colour. Brass Section
  (61), Clean Guitar (27) and Baritone Sax (67) are **not in `Zudio.sf2`** and would play silent.
  **Trumpet is at CC7 80, Vibraphone and Xylophone at 75.** A mallet attack cuts through the horn
  punctuation harder than the brass it shares the pool with, and open trumpet is the loudest patch
  there — brighter than the muted trumpet, higher than the trombone. The trumpet takes the lighter
  cut because it is the pool's main voice. **No synth brass and no French horn**: this music wants
  real horns. Nothing in the pool sustains except the brass, so a Sustained Halo song drawing one
  of the mallets gets a note that rings and decays inside its written length rather than holding —
  the brass covers 70% of picks
- **Lead 2**: as above
- **Bass**: Fretless 37%, Acoustic 37%, **Elec Bass 25%** — base Chill draws all three evenly,
  Soho leans away from the electric. When Elec Bass is drawn the bass track takes **Low and Comp**
  on top of its reverb, set in both `AppState.restoreDefaultEffects` and
  `TrackRowView.applyDefaultEffects`, which must stay in step; the chips and the audio chain are
  the same switch, so they cannot drift
- **Drums**: Brush Kit and Jazz Drums only — never the 808
- **Lead 1 delay is off** by default; a delayed lead is a St Germain signature
- Lead 1, Rhythm, Pads and Bass still draw from base Chill's pools

Stereo: the Chill stage, with the **Texture panned 0.30 right** — a horn section off to one side.

### Titles

Eight forms, all built from parts, giving **~1,690 effectively distinct titles**: place, cafe,
period, prepositional, venue, late-night, paired nouns, gerund and clock.

Banks are exposed on `ChillTitleGenerator` and read by the tests rather than copied. Streets keep
their "Street" except the eight best known; `sohoNamedStreets` (King's Road) and the squares take
none. Venues carry an article flag and an `alone` flag — "Live at the BBC" is a phrase, "The BBC"
is not a title.

### Logging

- **Chords** line: key, mode and the A cycle only — `Ab Aeolian Im7 – Vm7`
- **Form** line: groove, sections, break and its length — `Soul groove - A/B - bass ostinato 4`
- **Turnarounds** are marked in the performance log as `Bar nnn  Turnaround`, in **both Chill
  Soho and Chill Blues**. Soho names the bass treatment — `Turnaround  walking quarters` — while
  Blues, which has none, carries no description and marks the V7 at cycle bar 12
- The Soho mark fires on the bar the turnaround is **played**, not the bar its chords begin. The
  detour's first two bars are still the ordinary groove, so marking the chord change read two
  bars early against the ear. An **original form** turnaround has no bass figure to hear, so it
  is marked where its chords turn — the only cue there is

### Verification

`tools/fpcheck.sh` fingerprints 300 seeds × 4 styles against `tools/fingerprints/baseline.txt`.
**Run it after every step that touches shared Chill code.** Zudio's regressions are silent — a
changed song does not error, it just sounds different — and this has already caught a change that
altered 27 released Chill Blues songs.

The baseline holds the **intended** output, not a historical snapshot, so a deliberate change to
Chill means re-pinning it:

```
bash tools/fpcheck.sh && cp tools/fingerprints/all_now.txt tools/fingerprints/baseline.txt
```

Re-pin only once every reported difference is accounted for as deliberate. Doing it to silence a
difference you cannot explain is how a real regression gets baked in. A baseline left stale is no
better: the expected differences accumulate until they drown the one that matters.

`ChillSohoTests` is the behavioural suite: `swift test --filter ChillSohoTests`.

---

## Implementation scope

- **Types.swift** — `ChillBeatStyle` gains two cases, `.sohoLatin` and `.sohoSoul`
- **SongState.swift** — `chillSohoVariation` flag, every `withXxx()` copy method updated (all
  fields must be passed explicitly or they silently default)
- **ChillMusicalFrameGenerator** — activation roll, one tempo band, mode weights
- **ChillDrumGenerator** — five new rules, split into a Latin pool and a Soul pool
- **ChillBassGenerator** — three new rules, a Latin/Soul pool split, and a `blues7th`-off path
  for the reused `CHL-BASS-012`
- **ChillRhythmGenerator** — two new rules, a Latin/Soul pool split
- **ChillLeadGenerator** — one new rule, pool weights
- **ChillPadsGenerator** — pool weights only
- **ChillStructureGenerator** — breakdown style weighting
- **ChillTitleGenerator** — five new word banks
- **AppState** — instrument pool restriction and a `sanitiseSohoInstruments` following the
  pool-driven shape of `sanitiseInstrumentsToPool`
- **SongGenerator** — rule description strings for the eleven new rule IDs

The reuse added above means the new-rule count rose from nine to eleven, but the amount of new
*generator* code fell: the non-Latin half leans on five existing rules
(`CHL-DRUM-003`, `CHL-BASS-001/002/004`, `CHL-RHY-005/006`) rather than needing its own.

### Files not changing

Nothing in Ambient, Kosmic or Motorik. No playback or export changes. No new instruments or
soundfont work — every patch this substyle needs is already in the Chill pools.

### Harmonic Drone

Four bars, opening on an unresolved Isus4.

- **The harmony moves once, halfway.** The suspension either resolves onto the tonic (40%), lifts
  to IV (35%), or steps to bVII and returns unresolved into the re-entry (25%). Two bars each, so
  the section is no busier for it. Set in `buildSohoChordPlan` only, so no other breakdown style
  and no other substyle is touched
- **Lead 1 plays through it** — the one breakdown where it does, since the drone is a held chord
  with nothing else carrying a melody. Drone bars are removed from the lead's rest mask as well: a
  single rest landing on a four-bar section would otherwise silence the lead for all of it
- 11% of drone bars have nothing pitched playing; Lead 1 reaches 49% of them

**Open:** the drone has no genuinely sustained bed. Pads are absent from 15% of these songs
entirely (`CHL-PAD-000`), and the ABSENT ruling says an absent track does not appear at all, so a
bed would have to come from the rhythm instrument.

### CHL-LD1-011 Sustained Tone — the phrase around the held note

**Every phrase carries an answering figure** — two to four notes, exactly one of them long. A
held tone on its own does not work here: the lead is often the only thing moving, so it reads as
a stall rather than as space.

The **held note is 1, 1.5, 2 or 2.5 bars** (16, 24, 32 or 40 steps), weighted 22/32/28/18. A
figure's length belongs to the figure, not to each statement of it, so a restatement is the same
phrase again rather than the same ornament with a new tail.

The figure beside it is **measured, not invented** — `tools/soho_sustained.py` finds every phrase
in the corpus containing a note of three beats or more (42 of them across the 14 files) and
reports its shape:

- the held tone lands **last** in 55%, first in 29%, mid-phrase in 17%. `sustainedCells` is
  weighted 65/35 last-to-first, which is that split with the mid-phrase cases set aside
- the notes beside it are **short** — 1–2 steps in 80% of cases
- they sit **very close**: unison (43 occurrences), a tone above (41), a tone below (26) and a
  minor third above (16) are the whole top of the interval histogram
- their onsets are **2 steps apart**, not 4

The cells are lifted from Holding Back the Years, Black Cow and Your Love Is King. Their
intervals are semitones from the held tone, snapped to the scale at use, so the contour is the
measurement and the pitches stay diatonic.

### CHL-LD1-012 Tight Hook — three hooks in conversation

Measured from **Avalon**, whose lead channel plays **13 phrases across three recurring contours**
— `[+2,-2]` seven times, `[0,+2]` three, `[+3,0]` twice — each appearing in one or two rhythms.
A dominant figure and two foils, not one figure and not thirty.

- **Three hooks per song**, weighted 55 / 25 / 20 as Avalon weights its own (7 / 3 / 2 across its three recurring contours). Each must differ in note count *and* rhythm, and must move rather
  than repeat pitches. Each mutates independently as the song goes
- **A hook that just played gets one chance to be passed over**, which keeps episodes from
  stacking into long runs of the same statement
- **Alternation is the norm, repetition the exception.** Three statements of one hook read as a
  carbon copy; `A B A` reads as a call and its answer. An episode's plan is drawn by its length:
  a pair is `A B` 65% of the time, a three is `A B A` 46% / `A A B` 24% / `A B B` 20% / `A A A`
  10%, and a four alternates in four shapes with `A A A A` at 7%. B is a *different hook*, so it
  differs in notes, not only in phrasing
- **The next episode usually leads with the hook that just answered** — after an `A B A` the
  natural move is `B A B`, so 60% of the time the previous episode's second hook leads the next
- Straight copies now run 19% of two-statement episodes, 2% of threes, 0% of fours — **6%
  overall**, rare enough to build a little tension when one does land
- **Hooks are drawn from `counterLineCells`**, the bank that gives the reed and flute cells their
  full weight — Avalon's hook is a flute line. The vocal-weighted `cellBank` has `[0, 0, -2]` as
  its heaviest entry, and since hooks are built by concatenating cells it yields figures that
  stutter one pitch rather than play a shape
- **A measured fallback.** A drawn hook can still come out mostly repeated pitches, so if
  twenty-four draws all fail the movement test, Avalon's own figures stand in: `[+2, -2]` over
  durs `[2, 1, 3]` and `[0, +5, -5, 0]` over `[2, 1, 2, 3, 1]`

Across 96 Tight Hook songs: 3% of statements are mostly repeated pitch, the commonest statement
takes a median 17% of a song, and distinct shapes run 39% of statements against Avalon's 56%.

### CHL-LD2-002 Shadow Hold — a companion for the held note

**Every Chill form**, base and Soho alike. A lone held note does not work here any more than it
does on Lead 1's Sustained Tone, so **70% of holds get a companion** — about 76% end up with one
once placement constraints are applied.

This is the one Soho change that deliberately alters released base Chill songs. Base Chill draws
Shadow Hold on 53% of its songs (the gate is 50%; Soho's is 25%, drawing 17%), so **92 of the
~178 base Chill songs in the fingerprint sample changed when it went in — 52%, matching
the share that use the rule**. Nothing else in the substyle touches base Chill: re-gating this one
change to Soho returns 229 of 229 base Chill songs identical.

Shape and intervals come from the same corpus measurement as Sustained Tone
(`tools/soho_sustained.py`): a short note of two steps, on the unison or within a tone or two of
the held pitch (weighted 0.34 / 0.32 / 0.21 / 0.13 across unison, +2, −2, +3), leading in two
thirds of the time and answering the rest. Velocity stays soft — six above the hold's, so the
shadow still sits under Lead 1 rather than competing with it.

Soho caps Lead 2 at two notes a bar, so a lead-in shares the hold's bar and an answer falls in
the bar after the hold lets go; neither can make a third note in one bar.

### Lead 2 sitting out

Lead 2 sits out the opening **8–16 bars** of a groove section about a third of the time — the
section opens without the reply and the sax arrives later. It is bounded deliberately: sitting
out a whole section would mean vanishing for more than half of a two-section song while the log
still listed a rule and a note count for the track. 2% of Soho songs have Lead 2 silent for more
than 40% of their length, and the longest silence across 400 songs is 62 bars.
