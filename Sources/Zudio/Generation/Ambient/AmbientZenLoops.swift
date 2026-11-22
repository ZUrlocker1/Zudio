// AmbientZenLoops.swift — Ambient Zen phase 2: the bell loops (Lead 1, Lead 2, Rhythm)
// Copyright (c) 2026 Zack Urlocker
//
// AMB-1's bell loops (docs/Ambient-Zen-plan.md, section 8). Each track has one loop of a prime
// number of quarter-note beats (13, 17, 23), one slot per beat, so the three never line up. The
// loop is walked one pass at a time, never tiled: each pass may add, remove, change or move a
// note, and rests now and then. A slot holds a scale step above the current chord's root, so a
// loop re-harmonises when the chord moves, even partway through a pass. There are no composed
// phrases: the melody is whatever the loops make as they phase against each other.
//
// Every note passes section 6, rule 7 where it is written: a chord tone or a safe tension of the
// window in force, no tension on beat 1 or 3, and the sounding check (not 1 or 13 semitones from
// any bed note or earlier bell note over its onset plus 2 beats). A note that fails moves to the
// nearest chord tone that passes, ties down; if none passes, it rests for that pass.

import Foundation

enum AmbientZenLoops {

    /// One bell loop's settings.
    struct Spec {
        let loopBeats: Int
        let baseNote: Int
        let velocity: ClosedRange<Int>
        /// The slot count's floor and ceiling, after the target formula.
        let minCount: Int
        let maxCount: Int
        let chordTonesOnly: Bool
        /// Note length in steps, drawn per slot.
        let duration: ClosedRange<Int>
    }

    static let lead1Spec  = Spec(loopBeats: 13, baseNote: 72, velocity: 40...80, minCount: 0, maxCount: 5,
                                 chordTonesOnly: false, duration: 8...8)
    static let lead2Spec  = Spec(loopBeats: 17, baseNote: 67, velocity: 42...70, minCount: 0, maxCount: 5,
                                 chordTonesOnly: false, duration: 8...8)
    static let rhythmSpec = Spec(loopBeats: 23, baseNote: 79, velocity: 35...60, minCount: 1, maxCount: 3,
                                 chordTonesOnly: true, duration: 2...4)

    /// The sounding check's span: the onset plus 2 beats.
    static let checkSteps = 8

    // MARK: - The three tracks

    /// Writes Lead 1, Lead 2 and Rhythm into `tracks` in that order, each reading the bed and the
    /// bells before it. `from` is the first bell track to rebuild: a regenerated bell track rebuilds
    /// itself and every bell after it, a regenerated bed track rebuilds all three. Each bell track
    /// takes its seed from `seeds` (a regeneration's override) or its default Zen index; a track
    /// with a seed in `seeds` always plays, so a user's regeneration never comes back silent.
    /// Returns each rebuilt track's rule IDs.
    @discardableResult
    static func writeBells(plan: AmbientZenPlan, globalSeed: UInt64, seeds: [Int: UInt64],
                           tracks: inout [[MIDIEvent]], from: Int = kTrackLead1) -> [Int: Set<String>] {
        let order = [kTrackLead1, kTrackLead2, kTrackRhythm]
        guard let first = order.firstIndex(of: from) else { return [:] }
        let defaults = [kTrackLead1: AmbientZenPlan.lead1Index, kTrackLead2: AmbientZenPlan.lead2Index,
                        kTrackRhythm: AmbientZenPlan.rhythmIndex]
        var rules: [Int: Set<String>] = [:]
        for t in order[first...] {
            let seed = seeds[t] ?? SeededRNG.trackSeed(globalSeed: globalSeed, trackIndex: defaults[t]!)
            var rng = SeededRNG(seed: seed)
            var used: Set<String> = []
            let force = seeds[t] != nil
            let density = seeds[t].map { regenBellDensity(seed: $0, base: plan.dials.bellDensity) } ?? plan.dials.bellDensity
            switch t {
            case kTrackLead1:
                tracks[t] = lead1(plan: plan, band: tracks, density: density, rng: &rng, usedRuleIDs: &used)
            case kTrackLead2:
                tracks[t] = lead2(plan: plan, band: tracks, forcePlay: force, density: density,
                                  rng: &rng, usedRuleIDs: &used)
            default:
                tracks[t] = rhythm(plan: plan, band: tracks, forcePlay: force, rng: &rng, usedRuleIDs: &used)
            }
            rules[t] = used
        }
        return rules
    }

    /// A regenerated Lead 1 or Lead 2 goes to the opposite of the song's bell density: sparse
    /// becomes full and full becomes sparse; a medium song goes to sparse or full on its own seed
    /// (Zack, 2026-11-21). The opposite is taken from the song's dial, not the track's last
    /// density, so a reload (which only has the final seed) replays it. Separate stream, so the
    /// loop's own draws don't move. Rhythm keeps the song's dial.
    static func regenBellDensity(seed: UInt64, base: Int) -> Int {
        var rng = SeededRNG(seed: seed ^ 0xBE11_DE45)
        let flip = [30, 60][rng.nextInt(upperBound: 2)]
        return base <= 30 ? 60 : base >= 60 ? 30 : flip
    }

    /// The density in the Zen line's words: sparse, medium or full.
    static func densityWord(_ density: Int) -> String {
        density <= 30 ? "sparse" : density <= 45 ? "medium" : "full"
    }

    /// The bed and the bells already written that a bell track must keep clear of.
    private static func neighbours(_ band: [[MIDIEvent]], for track: Int) -> [MIDIEvent] {
        var tracks = [kTrackPads, kTrackTexture, kTrackBass]
        if track == kTrackLead2 || track == kTrackRhythm { tracks.append(kTrackLead1) }
        if track == kTrackRhythm { tracks.append(kTrackLead2) }
        return tracks.flatMap { band[$0] }
    }

    /// AMB-LD1-011 Airports 1/1 Loop, every Zen song. Enters at bar 2 to 4 and leaves at the
    /// pads' held breath, last of the three.
    static func lead1(plan: AmbientZenPlan, band: [[MIDIEvent]], density: Int, rng: inout SeededRNG,
                      usedRuleIDs: inout Set<String>) -> [MIDIEvent] {
        usedRuleIDs.insert("AMB-LD1-011")
        let drawn = 2 + rng.nextInt(upperBound: 3)
        let entry = plan.dials.cycle != .none ? cycleEntry(plan, half: 1, fallback: drawn, exit: exitBars(plan).lead1) : drawn
        return loop(lead1Spec, plan: plan, density: density, entryBar: entry, endBar: exitBars(plan).lead1,
                    others: neighbours(band, for: kTrackLead1), skipOnsets: [], rng: &rng)
    }

    /// AMB-LD2-014 Airports 1/2 Answer (0.85), softer, dropping any note on a beat where Lead 1
    /// strikes. Otherwise AMB-LD2-000 No lead 2. Enters at bar 6 to 8, leaves 4 bars before Lead 1.
    static func lead2(plan: AmbientZenPlan, band: [[MIDIEvent]], forcePlay: Bool, density: Int,
                      rng: inout SeededRNG, usedRuleIDs: inout Set<String>) -> [MIDIEvent] {
        let plays = rng.nextDouble() < 0.85 || forcePlay
        guard plays else { usedRuleIDs.insert("AMB-LD2-000"); return [] }
        usedRuleIDs.insert("AMB-LD2-014")
        let drawn = 6 + rng.nextInt(upperBound: 3)
        let entry = plan.dials.cycle != .none ? cycleEntry(plan, half: 2, fallback: drawn, exit: exitBars(plan).lead2) : drawn
        let lead1Onsets = Set(band[kTrackLead1].map { $0.stepIndex })
        return loop(lead2Spec, plan: plan, density: density, entryBar: entry, endBar: exitBars(plan).lead2,
                    others: neighbours(band, for: kTrackLead2), skipOnsets: lead1Onsets, rng: &rng)
    }

    /// AMB-RTHM-007 Lux Glass (0.80): one to three short high chord tones per 23-beat loop.
    /// Otherwise Rhythm is silent (AMB-RTHM-000). Enters at bar 9, leaves first.
    static func rhythm(plan: AmbientZenPlan, band: [[MIDIEvent]], forcePlay: Bool, rng: inout SeededRNG,
                       usedRuleIDs: inout Set<String>) -> [MIDIEvent] {
        let plays = rng.nextDouble() < 0.80 || forcePlay
        guard plays else { usedRuleIDs.insert("AMB-RTHM-000"); return [] }
        usedRuleIDs.insert("AMB-RTHM-007")
        let entry = plan.dials.cycle != .none ? cycleEntry(plan, half: 3, fallback: 9, exit: exitBars(plan).rhythm) : 9
        return loop(rhythmSpec, plan: plan, density: plan.dials.bellDensity, entryBar: entry, endBar: exitBars(plan).rhythm,
                    others: neighbours(band, for: kTrackRhythm), skipOnsets: [], rng: &rng)
    }

    /// A Big Ship song's layers come in by addition at half-cycles (16 bars): Lead 1 at the first,
    /// Lead 2 at the second, Rhythm at the third. A layer whose half-cycle leaves it under 12 bars
    /// before its exit comes in at the latest half-cycle that does, or at its usual bar.
    static func cycleEntry(_ plan: AmbientZenPlan, half: Int, fallback: Int, exit: Int) -> Int {
        let halfBars = 4 * AmbientZenPlan.cycleChordBars
        for h in stride(from: half, through: 1, by: -1) where exit - h * halfBars >= 12 { return h * halfBars }
        return fallback
    }

    /// The bars the bells stop at, in reverse order of entry: Lead 1 at the pads' held breath,
    /// Lead 2 4 bars earlier, Rhythm 4 bars before that. No bell note rings into the held breath.
    static func exitBars(_ plan: AmbientZenPlan) -> (lead1: Int, lead2: Int, rhythm: Int) {
        let l1 = plan.heldBreathStartBar
        return (l1, l1 - 4, l1 - 8)
    }

    // MARK: - The loop

    private struct Slot {
        var offset: Int        // scale steps above the chord root, 0 to 13
        var velocity: UInt8
        var duration: Int
    }

    /// One bell loop walked pass by pass from `entryBar` until `endBar`.
    static func loop(_ spec: Spec, plan: AmbientZenPlan, density: Int, entryBar: Int, endBar: Int,
                     others: [MIDIEvent], skipOnsets: Set<Int>, rng: inout SeededRNG) -> [MIDIEvent] {
        let startStep = entryBar * 16
        let endStep   = endBar * 16
        guard endStep - startStep >= spec.loopBeats * 4 else { return [] }
        let r      = plan.dials.restlessness
        let passSteps = spec.loopBeats * 4
        var slots  = [Slot?](repeating: nil, count: spec.loopBeats)
        var written: [MIDIEvent] = []
        // Sounding notes sorted by onset, for the check; each bell is added as it is written.
        var sounding = others.sorted { $0.stepIndex < $1.stepIndex }

        func newSlot() -> Slot {
            var offset: Int
            if spec.chordTonesOnly || rng.nextDouble() < 0.72 {
                offset = [0, 2, 4, 6][rng.nextInt(upperBound: 4)]
                if rng.nextDouble() < 0.30 { offset += 7 }
            } else {
                offset = [1, 3, 5][rng.nextInt(upperBound: 3)]
            }
            let vel = spec.velocity.lowerBound + rng.nextInt(upperBound: spec.velocity.count)
            let dur = spec.duration.lowerBound + rng.nextInt(upperBound: spec.duration.count)
            return Slot(offset: offset, velocity: UInt8(vel), duration: dur)
        }

        /// True when `pitch` sits 1 or 13 semitones from any note sounding in [s, e).
        func rubs(_ pitch: Int, _ s: Int, _ e: Int) -> Bool {
            for ev in sounding {
                if ev.stepIndex >= e { break }
                if ev.stepIndex + ev.durationSteps <= s { continue }
                if AmbientZenPlan.rubs(Int(ev.note), pitch) { return true }
            }
            return false
        }

        var passStart = startStep
        while passStart < endStep {
            let bar   = passStart / 16
            let swell = plan.swell(atBar: bar)

            // 1. Add or remove notes to meet the target.
            let raw    = Double(density) * 0.05 * (1 + 0.8 * swell)
            let target = Swift.max(spec.minCount, Swift.min(spec.maxCount,
                             Int((Swift.max(0, Swift.min(5, raw)) + rng.nextDouble()).rounded(.down))))
            var filled = slots.indices.filter { slots[$0] != nil }
            while filled.count < target {
                let empty = slots.indices.filter { slots[$0] == nil }
                guard !empty.isEmpty else { break }
                let i = empty[rng.nextInt(upperBound: empty.count)]
                slots[i] = newSlot()
                filled.append(i)
            }
            while filled.count > target {
                let k = rng.nextInt(upperBound: filled.count)
                slots[filled[k]] = nil
                filled.remove(at: k)
            }
            // 2. The pass rests now and then, more when the swell is sparse.
            let rests = rng.nextDouble() < 0.15 * r + 0.15 * Swift.max(-swell, 0)
            // 3. One slot changes its note or moves to an empty slot.
            if rng.nextDouble() < 0.7 * r, !filled.isEmpty {
                let i = filled[rng.nextInt(upperBound: filled.count)]
                if rng.nextDouble() < 0.5 {
                    let fresh = newSlot()
                    slots[i]?.offset = fresh.offset
                } else {
                    let j = rng.nextInt(upperBound: slots.count)
                    if slots[j] == nil { slots[j] = slots[i]; slots[i] = nil }
                }
            }
            let ringChance = 0.08 + 0.12 * Swift.max(swell, 0)

            if !rests {
                for (i, maybe) in slots.enumerated() {
                    guard let slot = maybe else { continue }
                    let step = passStart + i * 4
                    guard step < endStep else { break }
                    // The octave-ring draw is made for every slot so a rest or a drop never shifts
                    // the draws after it.
                    let ringRoll = rng.nextDouble()
                    if skipOnsets.contains(step) { continue }
                    let dur = Swift.min(slot.duration, endStep - step)
                    guard dur > 0,
                          let pitch = placePitch(slot.offset, step: step, plan: plan, spec: spec,
                                                 rubs: { rubs($0, step, step + checkSteps) })
                    else { continue }
                    let ev = MIDIEvent(stepIndex: step, note: UInt8(pitch), velocity: slot.velocity,
                                       durationSteps: dur)
                    written.append(ev)
                    insertSorted(&sounding, ev)
                    // The octave ring: the same note an octave up, 40 percent velocity.
                    let up = pitch + 12
                    if ringRoll < ringChance, up <= 103, !rubs(up, step, step + checkSteps) {
                        let ring = MIDIEvent(stepIndex: step, note: UInt8(up),
                                             velocity: UInt8(Swift.max(1, Int(slot.velocity) * 2 / 5)),
                                             durationSteps: dur)
                        written.append(ring)
                        insertSorted(&sounding, ring)
                    }
                }
            }
            passStart += passSteps
        }
        return AmbientZenTracks.abutSamePitch(written)
    }

    private static func insertSorted(_ list: inout [MIDIEvent], _ ev: MIDIEvent) {
        var lo = 0, hi = list.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if list[mid].stepIndex <= ev.stepIndex { lo = mid + 1 } else { hi = mid }
        }
        list.insert(ev, at: lo)
    }

    // MARK: - Pitch

    /// The pitch of a slot at a step, or nil when no chord tone passes the sounding check.
    /// A passing step that is not a safe tension of the window, or that falls on beat 1 or 3,
    /// moves to the chord tone below. A note that rubs moves to the nearest chord tone that
    /// passes, ties down.
    static func placePitch(_ offset: Int, step: Int, plan: AmbientZenPlan, spec: Spec,
                           rubs: (Int) -> Bool) -> Int? {
        let w = plan.windows[plan.windowIndex(atBar: step / 16)]
        var k = offset
        if !isChordStep(k) {
            let pc = pitch(k, window: w, plan: plan, base: spec.baseNote + plan.dials.bellShift) % 12
            let strong = step % 16 == 0 || step % 16 == 8
            if spec.chordTonesOnly || strong || !w.safeTensions.contains(pc) { k -= 1 }
        }
        let p = pitch(k, window: w, plan: plan, base: spec.baseNote + plan.dials.bellShift)
        if !rubs(p) { return p }
        // The nearest chord tones either side, within an octave and a half.
        let candidates = stride(from: k - 6, through: k + 10, by: 1)
            .filter { isChordStep($0) && $0 != k }
            .map { pitch($0, window: w, plan: plan, base: spec.baseNote + plan.dials.bellShift) }
            .filter { $0 != p }
            .sorted { (abs($0 - p), $0) < (abs($1 - p), $1) }
        return candidates.first { !rubs($0) }
    }

    /// A chord tone is an even step within the octave (0, 2, 4, 6); 1, 3 and 5 are passing steps.
    static func isChordStep(_ k: Int) -> Bool { (((k % 7) + 7) % 7) % 2 == 0 }

    /// The MIDI note `k` scale steps above the window's chord root, from the tonic at or below
    /// the loop's base note, folded into MIDI 36 to 103.
    static func pitch(_ k: Int, window w: ZenWindow, plan: AmbientZenPlan, base: Int) -> Int {
        let scale  = plan.mode.intervals
        let n      = scale.count
        let tonic  = base - ((base - plan.tonicPC) % 12 + 12) % 12
        let degree = w.degreeNumber - 1
        let idx    = degree + k
        let octave = idx >= 0 ? idx / n : (idx - n + 1) / n
        let within = ((idx % n) + n) % n
        var p = tonic + scale[within] + 12 * octave
        while p > 103 { p -= 12 }
        while p < 36 { p += 12 }
        return p
    }
}
