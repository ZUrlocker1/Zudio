# Humancipator — Consolidated Functional Spec

*Attributed to Brian Eno and Peter Chilvers. This document is an informed inference from plugin screenshots, and Eno's documented compositional philosophy.*

---

## Core Philosophy

Eno has always been interested in **systems that make decisions for you** — rules that, once set in motion, generate music that surprises even their creator. The Humancipator is best understood as a **MIDI mutation engine**: it takes incoming notes and transforms them according to user-defined probabilistic rules, turning simple played material into evolving, semi-autonomous patterns.

The name points to the compositional intent — it's not "humanizer," it's "humancipator." It doesn't make music sound more human. It **emancipates** the composer from having to specify every outcome. But mechanically, what it does is *mutate*: every incoming note is a seed that may be transposed, displaced in time, and multiplied into a chain of related events.

Rather than asking "what exact notes must happen?", the composer using Humancipator asks "what kinds of things am I willing to let happen?" — and then sets the probability bounds accordingly.

---

## What Each Section Is Likely Doing

### TRANSPOSE

Given the semitone values visible (7, 6, -5) with small probabilities (6%, 9%), this is building **modal or intervallic clouds** around a root note. A note comes in, and there's a small chance it gets transposed up a fifth, up a major sixth, or down a minor third. At low percentages this creates occasional harmonic ghosts — notes that weren't explicitly played appearing in related tonal spaces. Very characteristic of Eno's ambient work, where chords seem to drift and accrue over time rather than being explicitly voiced.

The **"Stop at first transpose"** option is significant: it suggests the plugin evaluates multiple possible transpositions in sequence and stops at the first one that fires. This prevents harmonic pile-up — only one transposed variant of any given note is emitted per event, keeping the output musical rather than chaotic. Intervals may be consonant, modal, dissonant, or mixed intentionally — the musical character of the transposition slots is entirely up to the composer.

### DELAY

The Delay module is a **probabilistic rhythmic displacer** — it slips individual notes off the beat by a small rhythmic amount rather than generating echo copies. This is the most direct MIDI implementation of what tape systems produced naturally: the original note arrives slightly late, detached from the grid, with the loose drifting quality that DAWs actively work against.

This reading makes the two modules non-redundant and complementary. Repeat already handles the "subsequent copies" concept with full velocity shaping — if Delay were also an echo, the two would be doing the same thing at different scales, which would be poor design for a tool this carefully considered.

The coherent reading of the two modules together is therefore:
- **Delay** = *when* a note arrives (displacement from its original grid position forward by a small rhythmic amount)
- **Repeat** = *how many times* a note subsequently recurs, with volume shaping

A note that passes through Delay fires late. A note that passes through Repeat spawns a chain of future copies. The original note is always emitted; Delay only controls *when* it arrives.

### REPEAT

At 49% chance of repeating, with 1–8 repeats at a 1/4 note step, any incoming MIDI note has roughly a coin-flip chance of generating a chain of subsequent note events. The **"Chance repeat plays"** parameter — set to 100% in the screenshot — likely controls whether each individual repeat in the chain fires or drops out independently, adding a second layer of probability within the chain itself. Lowering it below 100% would thin the chain unpredictably, creating gaps and rhythmic irregularity within the cascade.

Combined with the velocity options (Fade In, Fade Out, Fade In & Out, Constant), this creates **self-generating rhythmic tails** — a single note spawns a decaying or swelling series of echoes that are rhythmically quantized but probabilistically unpredictable. This is the engine that turns a simple looped pattern into something that never repeats the same way twice — the core of Eno's generative work going back to *Music for Airports*.

### VELOCITY CONTOUR

Applied across the repeat chain, this gives generated notes phrase-like shape rather than flat duplication. The options visible in the screenshot:

- **Fade Out** — mimics natural echo decay; most familiar, most "tape-like"
- **Fade In** — creates reverse-swell gestures; notes grow louder as they repeat
- **Fade In & Out** — a breath or pulse shape across the chain
- **Constant** — uniform velocity; useful for rhythmic applications where consistent energy is wanted

---

## Signal Flow

Each incoming MIDI note is processed in sequence:

1. Evaluate delay probability → if triggered, hold the original note-on by the displacement amount before emitting it; otherwise emit immediately
2. Evaluate transpose probability → emit transposed copy at the (possibly displaced) note-on time if triggered (stop at first match if enabled)
3. Evaluate repeat probability → if triggered, determine repeat count within min/max bounds; chain starts from the (possibly displaced) note-on time
4. For each repeat in chain, evaluate "chance repeat plays" → emit or suppress independently
5. Apply velocity contour across the emitted repeat chain
6. Output all MIDI events to destination instrument

The displaced note-on time is the anchor for both Transpose and Repeat — all generated events follow the delayed timing, so the full output cloud moves together when displacement fires.

All timing is quantized to host tempo sync.

---

## Module Interaction — The Emergent Layer

What happens when all three modules fire on the same note simultaneously — which at moderate probability settings will happen regularly — is arguably the most powerful aspect of the plugin. A single input note could be:

- transposed up a fifth
- echoed once after a quarter note at reduced velocity
- *and* repeated 3–5 times with fading velocity

The result is a small **polyphonic cloud of transformed, staggered, fading copies** spawned from a single note event. This emergent complexity from module combination is the hardest thing to predict — which is precisely the point. The composer sets the rules; the system explores the space those rules define.

---

## The Bigger Picture

Humancipator asks three questions about every note event:

1. *Should this note move harmonically?*
2. *Should this note echo in time?*
3. *Should this note multiply into a chain?*

Each is answered by a weighted dice roll. Simple, repetitive input material becomes **gradually transformed and self-differentiating** over time without further intervention from the composer. The music plays itself into new shapes.

This is consistent with Eno's work across *Discreet Music*, *Music for Airports*, *Bloom*, *Scape*, and *Reflection* — the long-running project of making music "the way a garden grows." You plant seeds and set conditions, then let the system run.

---

## Implementation Notes

For anyone building a similar system:

**Architecture:** Per-note and event-driven, not clip-based. Each incoming note spawns its own small generative process independently of others. A clip-based approach would undermine the real-time probabilistic behavior entirely.

**Delay vs. Repeat distinction:** Implement as genuinely separate modules. In the chosen v1 interpretation, Delay is a rhythmic displacer (slips the original note off the grid) and Repeat is the echo/chain mechanism. The two cover *when* vs *how many times* — non-overlapping concerns. See Part 3 for the explicit `delay_mode` flag that governs this choice.

**Timing:** Quantize all generated events to host tempo sync. Free-running timing produces phase drift — potentially interesting, but worth exposing as an explicit option rather than a default.

**Density management:** At higher probability settings across all three modules, note density multiplies quickly. Repeat alone can generate up to 8 additional events per incoming note. A global density limiter or per-channel voice cap is worth building in to prevent MIDI flooding and CPU overload.

**"Stop at first transpose" logic:** Iterate through transpose slots in order (or randomly) and halt on the first one that passes its probability check. Simple but musically important — prevents unintended chord clusters from a single input note.

**Velocity contour:** Apply as a linear or curved ramp indexed by position within the chain (repeat 1 of 5, repeat 2 of 5, etc.) rather than absolute velocity values, so the contour scales correctly regardless of the incoming note's original velocity.

**Scale/pitch constraining:** Not visible in the screenshot but a strong candidate for addition — an optional scale filter that snaps transposed notes to a chosen key or mode, preventing unintentional chromaticism when using free interval settings.

**Modulation:** Probability knobs that can be modulated by LFO, MIDI CC, or automation would extend the tool significantly. Allowing "chance" values to evolve over time rather than remaining static opens up long-form compositional arcs — moving between dense and sparse states gradually.

**Note length / gate scaling:** Not visible but likely needed — generated repeat notes probably need their gate length managed independently of the original, especially at shorter step values.

---

## Part 2: Detailed Implementation Design

This section resolves the ambiguities in Part 1 and specifies each module at the algorithm level — precise enough to implement without further interpretation.

---

### Original Note Pass-Through

The original incoming MIDI note always passes through to output — it is never suppressed or replaced by a generated copy. This is the additive invariant: Humancipator adds events; it does not consume the trigger.

**Timing qualification:** With `delay_mode = displace_original` (see Part 3), the original note's *emit time* may be shifted forward by the displacement amount. The note is still the same pitch, velocity, and channel — only its position in time changes. "Pass-through" means the note always appears in output, not that every attribute is frozen. With `delay_mode = emit_copy`, the original always fires at `noteOnTime` and a separate delayed copy is added — the note is then genuinely unchanged.

---

### TRANSPOSE Module — Algorithm

**Data model per transpose slot:**
- `semitones: Int` — positive or negative; no constraint on range, but typically ±12
- `probability: Float` — 0.0–1.0 (displayed as 0–100%)
- `enabled: Bool` — slot can be toggled without losing the semitone/probability values

**Slot count:** Fixed at N slots (likely 8 based on plugin layout). Unused slots have probability 0 or are disabled.

**Evaluation algorithm (per incoming note-on):**

```
for each enabled slot in order:
    roll = random(0.0, 1.0)
    if roll < slot.probability:
        emit note-on at (originalPitch + slot.semitones), same velocity, same channel
        emit note-off at (originalPitch + slot.semitones) after same gate duration as original
        if "Stop at first transpose" is enabled: break
```

**"Stop at first transpose" behaviour:** Slots are evaluated in fixed display order (top to bottom). The loop breaks after the *first* slot that passes its probability check. All subsequent slots are skipped for this note event. With the flag off, every slot is evaluated independently — multiple transpositions can fire simultaneously on the same note. This is why the flag exists: at low individual probabilities, simultaneous firing is rare; at higher settings it can produce unintended cluster chords.

**Pitch of generated note:** `originalPitch + semitones`. No scale-snapping by default (see Scale Filter in optional extensions). If the transposed pitch falls outside MIDI range (0–127), clamp and emit anyway — do not silently suppress.

**Gate duration of generated note:** Matches the original note's gate (time between its note-on and note-off). The transpose module does not alter timing.

---

### DELAY Module — Algorithm

Delay is a **rhythmic displacer**, not an echo generator. It probabilistically slips the original note off the grid by a fixed rhythmic amount — the note arrives late. No copy is created; the original note itself is held back.

**Data model:**
- `probability: Float` — chance displacement is applied to any given note (0.0–1.0)
- `displacement: Float` — how far the note is slipped forward in time, expressed as a musical fraction of a beat (e.g. 0.125 = eighth note, 0.0625 = sixteenth note); resolved to milliseconds at playback using host tempo at the moment the note arrives
- No velocity parameter — the note's velocity is unchanged; displacement affects timing only

**Evaluation algorithm (per incoming note-on):**

```
roll = random(0.0, 1.0)
if roll < probability:
    emitTime = noteOnTime + (displacement * secondsPerBeat)
else:
    emitTime = noteOnTime

schedule note-on at emitTime, pitch = originalPitch, velocity = originalVelocity
schedule note-off at emitTime + originalGateDuration
```

The note is the same in every respect except when it fires. Displacement is always forward in time (late), never early — slipping a note behind the beat is the characteristic feel; anticipating the beat is a different musical effect.

**Displacement range:** Small values are most musical — typically 1/32 to 1/8 of a beat. Larger values begin to sound like rhythmic repositioning rather than human looseness. A range of 0–1/4 note covers the full useful spectrum; the default should sit around 1/16.

**Relationship to Repeat and Transpose:** Because displacement is applied to the original note's emit time, all subsequent events spawned by Repeat and Transpose inherit the displaced time as their anchor. The full output cloud — original, transposed copy, repeat chain — moves together when displacement fires. This preserves the internal rhythmic relationships between generated events while shifting the whole cluster off the grid.

---

### REPEAT Module — Algorithm

**Data model:**
- `probability: Float` — chance any given note spawns a chain at all
- `minRepeats: Int`, `maxRepeats: Int` — bounds on chain length (e.g. 1–8)
- `stepInterval: Float` — musical fraction of a beat; same unit as Delay's stepInterval
- `chanceRepeatPlays: Float` — independent per-event dropout probability within the chain (0.0–1.0; 1.0 = all play)
- `velocityContour: Enum` — FadeOut | FadeIn | FadeInAndOut | Constant

**Evaluation algorithm (per incoming note-on):**

```
roll = random(0.0, 1.0)
if roll < probability:
    repeatCount = randomInt(minRepeats, maxRepeats)  // uniform distribution within bounds
    for i in 1...repeatCount:
        dropRoll = random(0.0, 1.0)
        if dropRoll < chanceRepeatPlays:
            eventTime = noteOnTime + (i * stepInterval * secondsPerBeat)
            velocity = applyContour(originalVelocity, position: i, total: repeatCount)
            schedule note-on at eventTime, pitch = originalPitch, velocity = velocity
            schedule note-off at eventTime + originalGateDuration
```

**Chain starts from the original note-on time**, not from the echo time if Delay also fired. The first repeat fires at `noteOnTime + 1 × stepInterval`, the second at `noteOnTime + 2 × stepInterval`, and so on.

**Pitch in the chain:** All repeats play at `originalPitch` — the pre-transpose pitch. If the Transpose module also fired on this note, the chain does not follow the transposed pitch. Transpose and Repeat are parallel branches from the same original event, not serial.

**`chanceRepeatPlays` evaluation:** Each event in the chain is evaluated *independently*. A chain of 5 repeats at 80% chance produces on average 4 events but the pattern is non-deterministic — gaps can appear anywhere, not just at the end. At 100% all repeats always fire.

**Velocity contour calculation:**

```
FadeOut:      velocity = originalVelocity × (1 - i/repeatCount)          // linear decay to near-zero
FadeIn:       velocity = originalVelocity × (i/repeatCount)               // linear rise to original
FadeInAndOut: velocity = originalVelocity × sin(π × i/(repeatCount+1))   // arch shape, peaks at midpoint
Constant:     velocity = originalVelocity                                  // unchanged throughout
```

All results clamped to 1–127. Contour is indexed by position `i` within the chain, not absolute velocity values — so a soft original note produces a soft chain with the same shape as a loud one.

---

### Multi-Module Interaction — Event Timeline

When all three modules fire on a single input note, the full event set emitted is:

```
d = displacement amount (0 if Delay did not fire)
g = original gate duration

t=d           Original note-on (always; displaced by d if Delay fired)
t=d+g         Original note-off
t=d           Transposed note-on (if Transpose fired; anchored to displaced time)
t=d+g         Transposed note-off
t=d+1×step    Repeat 1 note-on (if chain plays; starts from displaced anchor)
t=d+1×step+g  Repeat 1 note-off
...
t=d+N×step    Repeat N note-on
t=d+N×step+g  Repeat N note-off
```

Key properties:
- When Delay fires, every event in the output shifts by `d` — the cluster moves as a unit
- When Delay does not fire, `d=0` and all events are anchored to the original grid position
- No echo event is created — Delay produces no additional note, only a timing shift
- There is no feedback — generated events do not re-enter the Humancipator input; repeat notes do not spawn further chains

---

### Note-Off Handling

All generated note-ons must have corresponding note-offs scheduled at `eventTime + originalGateDuration`. Gate duration is captured at note-on time (from the note's duration if known, or from the matching note-off if processing live). If note-off arrives before all scheduled events have fired, the scheduled events still play — their gate is fixed at capture time, not dependent on how long the user holds the key.

Edge case: if `originalGateDuration` is unknown at note-on time (e.g. live MIDI input), use a default gate equal to one step interval and correct on note-off arrival if needed.

---

### State Management Per Note

Each incoming note spawns an independent generative context:

- Store: originalPitch, originalVelocity, originalGateDuration, noteOnTime
- Scheduled events can be cancelled if a "panic" or all-notes-off message arrives
- Overlapping chains (e.g. new note arrives while previous chain is still running) are independent — they do not share state and do not cancel each other
- A per-channel voice cap (see Density Management) is evaluated at schedule time, not at note-on time

---

### Density Management — Concrete Mechanism

The spec notes the risk of MIDI flooding at high probability settings. Recommended mechanism:

**Per-channel pending event counter:** Maintain a count of scheduled-but-not-yet-fired note-ons per MIDI channel. Before scheduling any generated event (Transpose, Delay, or Repeat), check if `pendingCount[channel] >= voiceCap`. If so, drop the event silently. Decrement the counter when each note-off fires.

A reasonable default cap is **16 simultaneous pending events per channel** — high enough to allow dense cascades but low enough to prevent runaway multiplication. This cap should be user-configurable.

---

### Timing — Quantization and Resolution

All generated event times are expressed as musical fractions of a beat, resolved to absolute clock time using host tempo at the moment the original note-on fires. If tempo changes mid-chain, already-scheduled events play at the time they were originally scheduled — they are not re-quantized. This matches the behaviour of a real tape delay and prevents unexpected timing jumps.

Step interval granularity: support at minimum 1/32 note, 1/16, dotted 1/16, 1/8, dotted 1/8, 1/4, dotted 1/4, 1/2. Triplet variants (1/8T, 1/4T) are valuable additions.

---

### Optional Extensions (Not In Original Screenshot)

**Scale filter:** After any pitch is generated (Transpose result or Repeat pitch), snap it to the nearest pitch in a user-specified scale. Snapping direction: nearest, always up, always down. Prevents unintentional chromaticism when using free semitone values.

**Transpose follows chain:** A toggle that, when enabled, applies the transposed pitch to the entire Repeat chain rather than just the original's transposition. Creates a chain of transposed echoes rather than a chain at the original pitch plus a separate transposed event.

**LFO/CC modulation of probability knobs:** Each probability value can be modulated by a slow LFO or MIDI CC, allowing density to evolve over time — sparse at the start, denser in the middle, sparse at the end — without manual automation.

**Per-slot velocity scaling in Transpose:** Each transpose slot can have an independent velocity multiplier, so harmonically distant transpositions can be quieter (acting as soft harmonic ghosts) while closer intervals play at full velocity.

---

**Sparse piano to ambient ecology:** A simple piano phrase fed in. Some notes delay, some repeat with fade-out, some transpose by consonant intervals. Result: a shifting, glassy texture that feels composed but never fixed.

**Static note to living pad:** A single repeated or sustained note. Repeat creates pulse structure, delay creates stagger, transpose creates harmonic bloom. Result: an arpeggio/pad hybrid that grows organically from a single pitch.

**Simple motif to evolving loop:** A two- or three-note motif looping through the plugin. Each pass is slightly different. Result: a loop that retains identity while never playing exactly the same way twice.

**Counterpoint by displacement:** A chord fed in, notes branching differently through each module independently. Result: the chord unfolds into separated strands that behave like emergent counterpoint — composed-sounding but not explicitly written.

---

## Part 3: v1 Design Decisions and Frozen Ambiguities

This section documents the specific choices made for a first implementation, marks which design questions are intentionally deferred, and specifies infrastructure (randomness, event identity, edge cases, testing) that must be locked before writing code.

---

### v1 Frozen Ambiguities — Four Flags

The following four questions are genuinely ambiguous from the plugin screenshots. Rather than resolving them with false confidence, each is represented as an explicit named flag. v1 picks a default; the flag is exposed so the choice can be changed without refactoring the algorithm.

---

**`delay_mode`**

- `displace_original` *(v1 default)* — Delay shifts the original note's emit time forward. The note is the same event, just late. No additional event is created.
- `emit_copy` — Delay emits an additional copy of the note at `noteOnTime + displacement`. The original note fires on time and is completely unchanged.

*Why `displace_original` is the v1 default:* It is the more musically distinctive choice — the one that produces the tape-like drift that Part 1 describes. It also makes Delay and Repeat genuinely non-redundant: Delay moves the original, Repeat copies it. With `emit_copy`, Delay is just a one-shot Repeat at fixed depth.

*When to revisit:* If user testing reveals that displacing the original causes noticeable timing artefacts in melodic passages (especially when Delay probability is high), switch to `emit_copy`. The rest of the algorithm is unchanged; only whether the "original" is on-time or displaced differs.

---

**`module_topology`**

- `parallel` *(v1 default)* — All three modules evaluate independently from the same original note-on. Events from different modules do not interact. Transpose produces a pitch copy, Delay shifts the original, Repeat produces time copies — all anchored to the same source event.
- `serial` — Modules fire in a pipeline: Delay output feeds into Transpose, Transpose output feeds into Repeat. Generated events from one module can trigger the next.

*Why `parallel` is the v1 default:* Simpler to reason about, simpler to implement, and simpler to control. Serial topology creates combinatorial explosion (a transposed note that repeats spawns transposed repeats) and makes probability semantics harder to reason about from the UI.

*When to revisit:* If "Transpose follows chain" (the Optional Extension in Part 2) is promoted to a first-class feature, that is a targeted partial serial mode — easier to implement than full serial topology and more musically useful.

---

**`repeat_pitch_source`**

- `original` *(v1 default)* — All events in the Repeat chain play at `originalPitch`, regardless of whether Transpose fired.
- `transposed` — If Transpose fired, the Repeat chain plays at the transposed pitch instead of the original.

*Why `original` is the v1 default:* Matches `parallel` topology. With `transposed`, the modules become partially coupled, which contradicts the parallel model. If the user wants a chain of transposed echoes, `serial` topology with Repeat downstream of Transpose is the cleaner way to achieve it.

---

**`transpose_selection_mode`**

- `ordered` *(v1 default)* — Slots are evaluated top-to-bottom in display order. "Stop at first" halts on the first slot that passes its probability roll.
- `random_order` — Slots are evaluated in a randomly shuffled order each note event. Prevents the highest-probability slot from always being the one that wins.

*Why `ordered` is the v1 default:* Predictable and easy to explain. The display order is the evaluation order, and users can reason about which slots dominate by position.

---

### Randomness Model

**Single PRNG per plugin instance.** Use a seeded pseudo-random number generator (Mersenne Twister or xorshift64; platform RNG is acceptable) initialised once at plugin load. Do not use `Math.random()` or equivalent uncontrolled global state.

**Per-note RNG context.** When a note-on fires, draw all random numbers for that note's generative process in a defined order:

1. Delay probability roll
2. Transpose slot rolls (in slot order)
3. Repeat probability roll
4. Repeat count draw (if repeat triggered)
5. Per-chain-event `chanceRepeatPlays` rolls (in chain order, 1…N)

Drawing in fixed order makes the output reproducible given the same seed and input sequence, which is required for offline/bounce determinism.

**Reroll on transport restart.** When the host transport stops and restarts from the beginning, reset the PRNG to its initial seed. This ensures playback from bar 1 always produces the same output — important for export/bounce consistency and for composers iterating on the same passage.

**Offline bounce determinism.** Because the PRNG reseeds on transport reset and all time values are host-tempo-relative, offline render should be sample-identical to real-time playback for the same seed. If the host does not guarantee call-order during offline render (e.g. note-ons arrive in a different sequence), log a warning — do not silently produce different output.

**Seed exposure.** Expose the current seed value in the plugin state (serialised with the preset). Allow the user to manually enter a seed or click "reroll" to get a different random character while keeping all probability settings the same. This is the primary "variation" workflow: same settings, different seed = different result.

---

### Event Ownership Model

Every MIDI event produced by the plugin carries three metadata fields (internal; not transmitted in the MIDI stream, used for scheduling and cancellation):

- `sourceNoteId: UInt64` — monotonically incrementing ID assigned to each incoming note-on. Used to group all events that belong to the same generative context.
- `moduleOrigin: Enum` — `Original | Transpose | Repeat`. Identifies which module produced the event.
- `generationIndex: Int` — Position within the chain for Repeat events (1-indexed); 0 for Original and Transpose events. Used to compute velocity contour.

**Why this matters:**

- Cancellation: when "panic" or all-notes-off arrives, cancel all pending events by iterating the scheduled queue and dropping any with a matching `sourceNoteId`. This is O(pending events), not O(all notes ever played).
- Debugging: the event log can show which source note spawned which output cloud, making probability tuning observable.
- Voice cap: the per-channel pending counter tracks events by `sourceNoteId` group, so cancelling one group correctly decrements the counter.

---

### Edge Case Policies

**Overlapping same-pitch same-channel notes.** If a second note-on arrives for the same pitch/channel while the first is still generating events (including its pending Repeat chain), both chains run independently. The second note-on does not cancel the first. Note-off handling: the first note-off received for the pitch cancels the *original* note's sustain; generated events still play their pre-captured gate durations and are unaffected. (If the host sends a note-off that matches a pending generated event's pitch, ignore it — generated events own their own note-offs.)

**Sustain pedal (CC64).** Sustain held down extends the *original* note's gate as seen from the host, but the plugin captures `originalGateDuration` from the note-off arrival (or from a fixed default if using live MIDI). If sustain is held when the note-off arrives, treat the gate as the time from note-on to the CC64=0 event, not to the literal note-off. Generated events use this extended gate. This requires tracking sustain state per channel.

**Panic / all-notes-off (CC120 / CC123).** On receipt of all-notes-off or a MIDI panic: cancel all pending scheduled events immediately, send note-offs for any events already emitted that have not yet received their scheduled note-off, and reset the per-channel pending counter to zero. Do not reset the PRNG — the randomness state continues from where it was.

**Tempo change mid-chain.** Already-scheduled events play at the absolute clock time calculated from the tempo at the moment their source note-on fired. They are not re-quantized. New events (from new note-ons after the tempo change) use the new tempo. This is consistent with tape delay behaviour and prevents jarring re-timing of in-progress cascades.

**Transport stop with pending events.** When the host transport stops, cancel all pending scheduled events immediately (same as panic policy). Send note-offs for any events already emitted without their note-off. On transport restart, re-seed the PRNG if restarting from the beginning (see Randomness Model).

---

### Test Matrix

The following scenarios must produce specified, verifiable behaviour:

- **All probabilities at 0%:** No generated events. Every incoming note passes through unchanged at `noteOnTime`. Output is identical to bypassing the plugin.
- **All probabilities at 100%, `chanceRepeatPlays` at 100%:** Every note produces: one original (possibly displaced), one transposed copy per enabled slot, and `maxRepeats` repeat events. Total output events = 1 + numEnabledTransposeSlots + maxRepeats per input note. Verify count exactly.
- **`minRepeats == maxRepeats`:** Chain length is always exactly that value (no randomness in count). Verify over 100 consecutive notes.
- **Overlapping same-pitch notes:** Send two note-ons for the same pitch 50ms apart, both with high repeat probability. Verify both chains run to completion independently and no note-off from chain 1 cancels a note in chain 2.
- **Short gate + long chain:** Note gate = 1/32 note, step interval = 1/4 note, maxRepeats = 8. Chain runs 8 steps past the original note-off. Verify all 8 repeats fire with correct pitch and velocity contour. Verify no spurious note-off arrives for repeat events before their scheduled time.
- **Tempo change during repeats:** At 120 BPM, fire a note that spawns a 4-step chain at 1/4 note intervals. Change tempo to 240 BPM after repeat 1 fires. Verify repeats 2–4 play at their originally scheduled absolute clock times (not re-quantized to the new tempo).
- **Panic mid-chain:** Fire a note with maxRepeats = 8, step interval = 1/4 note. After repeat 3 fires, send all-notes-off (CC123). Verify repeats 4–8 are cancelled and no stuck notes remain.
- **Transport stop mid-chain:** Same as panic test but using transport stop. Verify all pending events cancelled, no stuck notes, PRNG is at the correct state for restart.
- **Seed determinism:** Set seed to a fixed value, play a 4-bar loop twice without changing seed or settings. Verify the event output sequence is bit-identical on both passes.
- **Voice cap at limit:** Set voice cap to 2. Send a rapid burst of 10 note-ons with high repeat probability. Verify that no channel ever has more than 2 pending events at once and that dropped events produce no note-on without a note-off.

---

### Density Macro Control

In addition to per-module probability knobs, a top-level **Density** macro (0–100%) scales all probability values simultaneously without altering their relative ratios:

```
effectiveProbability(module) = userProbability(module) × (density / 100)
```

At Density = 100%, all modules run at their configured probabilities. At 50%, every probability is halved. At 0%, the plugin is effectively bypassed — all events pass through unchanged.

This gives performers a single gesture to move between sparse and dense without adjusting three separate knobs. It also makes the tool usable as a live performance control: automate Density from 0% → 80% over 8 bars to build a passage from clean to generative.

**Entropy variant:** An optional **Entropy** macro increases the maximum randomness in each chain — specifically, it widens `chanceRepeatPlays` variance (pushing it away from 100% as Entropy increases) and enables `random_order` for `transpose_selection_mode`. High Entropy at moderate Density produces unpredictable sparse output; low Entropy at high Density produces dense but predictable output. These two axes give the composer fine control over the character of the generative space.

---

### Gate Contour

Alongside velocity contour, a **Gate contour** shapes the *duration* of events across the Repeat chain. The same four shapes apply:

- **FadeOut** — gate shrinks across the chain; later repeats are shorter (staccato at the end)
- **FadeIn** — gate grows; earlier repeats are shorter than later ones
- **FadeInAndOut** — arch shape; notes in the middle of the chain are longest
- **Constant** — all repeats use the original gate duration

```
FadeOut:      gateDuration(i) = originalGate × (1 - i/repeatCount)   // floors at min gate (e.g. 1/64 note)
FadeIn:       gateDuration(i) = originalGate × (i/repeatCount)
FadeInAndOut: gateDuration(i) = originalGate × sin(π × i/(repeatCount+1))
Constant:     gateDuration(i) = originalGate
```

Minimum gate floor: 1/64 note (or the smallest host-supported duration). Never emit a note-on with zero gate.

Gate contour is an optional v1 feature — implement after velocity contour is stable. The data model and evaluation slot are defined now so it can be added without restructuring the chain.

---

