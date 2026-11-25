// AmbientPianoBuds.swift — AMB-PNO-001 Floating Buds (Harold Budd), split out of AmbientLeadGenerator.swift
// Copyright (c) 2026 Zack Urlocker

import Foundation

extension AmbientLeadGenerator {

    // MARK: AMB-PNO-001 — Floating Buds (Harold Budd)

    static func floatingTonesFullSong(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>, isEvolvePass: Bool = false
    ) -> [MIDIEvent] {
        let r = rng.nextDouble()
        if r < 0.40 {
            logVariant(AmbientPianoRule.Variant.budsSparse, of: .buds, in: &usedRuleIDs)
            return floatingTonesMode1(frame: frame, totalBars: totalBars, rng: &rng, isEvolvePass: isEvolvePass)
        }
        if r < 0.75 {
            logVariant(AmbientPianoRule.Variant.budsChordWash, of: .buds, in: &usedRuleIDs)
            return floatingTonesMode2(frame: frame, totalBars: totalBars, rng: &rng, isEvolvePass: isEvolvePass)
        }
        logVariant(AmbientPianoRule.Variant.budsPendulum, of: .buds, in: &usedRuleIDs)
        return floatingTonesMode3(frame: frame, totalBars: totalBars, rng: &rng, isEvolvePass: isEvolvePass)
    }

    /// Mode 1 — Sparse floating: a chord wash, then sparse figures that keep returning to a colour constellation.
    static func floatingTonesMode1(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG, isEvolvePass: Bool = false
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let evtNotes = notesInRegister(pitchClasses: scalePCs, low: 55, high: 84)
        guard !evtNotes.isEmpty else { return [] }

        // Colour constellation (once per song): 3-4 notes within about an octave that the floating
        // notes keep coming back to — root and 5th, usually the 9th, sometimes the 6th or the 3rd.
        // Figures still wander between them, but they start and come to rest on these bells.
        let rootPC = frame.keySemitoneValue % 12
        var constPCs = [rootPC, (rootPC + 7) % 12]
        if rng.nextDouble() < 0.70 { constPCs.append((rootPC + 2) % 12) }
        if rng.nextDouble() < 0.50 { constPCs.append((rootPC + (rng.nextDouble() < 0.50 ? 9 : (scalePCs.contains((rootPC + 4) % 12) ? 4 : 3))) % 12) }
        constPCs = constPCs.filter { scalePCs.contains($0) }
        let constCenter = 66 + rng.nextInt(upperBound: 7)   // F#4-C5
        let constIdx: [Int] = Array(Set(constPCs.compactMap { pc in
            evtNotes.indices.filter { Int(evtNotes[$0]) % 12 == pc }
                .min { abs(Int(evtNotes[$0]) - constCenter) < abs(Int(evtNotes[$1]) - constCenter) }
        })).sorted()
        // Nearest constellation note within `within` scale steps, else the index unchanged
        func snapConst(_ i: Int, within: Int = 2) -> Int {
            guard let c = constIdx.min(by: { abs($0 - i) < abs($1 - i) }), abs(c - i) <= within else { return i }
            return c
        }
        func randomConst() -> Int { constIdx.isEmpty ? rng.nextInt(upperBound: evtNotes.count) : constIdx[rng.nextInt(upperBound: constIdx.count)] }
        var lastIdx: Int = -1
        var events: [MIDIEvent] = []

        let minEvents  = Swift.max(16, totalBars / 5)
        let eventCount = minEvents + rng.nextInt(upperBound: 6)
        var cursor = isEvolvePass ? rng.nextInt(upperBound: 8) : (1 + rng.nextInt(upperBound: 2)) * 16

        for i in 0..<eventCount {
            guard cursor < totalSteps - 2 * 16 else { break }
            let roll = rng.nextDouble()

            if roll < 0.07 {
                // Single bell-tone — short, clear, not sustained beyond piano decay
                var idx = rng.nextDouble() < 0.85 ? randomConst() : rng.nextInt(upperBound: evtNotes.count)
                if rng.nextDouble() < 0.25 && lastIdx >= 0 { idx = lastIdx }
                lastIdx = idx
                let dur = Swift.min(8 + rng.nextInt(upperBound: 9), totalSteps - cursor)
                if dur >= 4 {
                    events.append(MIDIEvent(stepIndex: cursor, note: evtNotes[idx],
                                            velocity: pnoVel(24 + rng.nextInt(upperBound: 18)),
                                            durationSteps: dur))
                }

            } else if roll < 0.24 {
                // Arpeggiated dyad — 2nd note 2-4 steps after 1st, within piano sustain (10-16 steps each)
                let idx   = rng.nextDouble() < 0.80 ? randomConst() : rng.nextInt(upperBound: evtNotes.count)
                let note1 = evtNotes[idx]
                let note2 = evtNotes.first(where: { abs(Int($0) - Int(note1)) == 7 })
                         ?? evtNotes.first(where: { abs(Int($0) - Int(note1)) == 4 })
                         ?? evtNotes.first(where: { abs(Int($0) - Int(note1)) == 5 })
                let dur1 = Swift.min(10 + rng.nextInt(upperBound: 7), totalSteps - cursor)
                if dur1 >= 6 {
                    let vel = pnoVel(26 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: cursor, note: note1, velocity: vel, durationSteps: dur1))
                    if let n2 = note2 {
                        let offset = 2 + rng.nextInt(upperBound: 3)
                        let dur2 = Swift.min(dur1 - offset, totalSteps - cursor - offset)
                        if dur2 >= 4 {
                            events.append(MIDIEvent(stepIndex: cursor + offset, note: n2,
                                                    velocity: pnoVel(Swift.max(18, Int(vel) - 6)),
                                                    durationSteps: dur2))
                        }
                    }
                    lastIdx = idx
                }

            } else if roll < 0.46 {
                // Descending figure with variation: optional initial upward turn, occasional 2-step skip.
                // Avoids pure scale motion; creates melodic interest without predictability.
                let startIdx = rng.nextDouble() < 0.70 ? randomConst()
                             : evtNotes.count / 2 + rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 2))
                let figLen   = 3 + rng.nextInt(upperBound: 4)
                var noteIdx  = startIdx
                var s        = cursor
                let hasTurn  = rng.nextDouble() < 0.45
                for fi in 0..<figLen {
                    guard s + 2 < totalSteps else { break }
                    let isLast = fi == figLen - 1
                    // Idea 3: 55% chance to extend the final note (1.25-1.75 bars) so it breathes into the gap.
                    let raw    = isLast ? (rng.nextDouble() < 0.55 ? 20 + rng.nextInt(upperBound: 9)
                                                                   : 10 + rng.nextInt(upperBound: 7))
                                       :  2 + rng.nextInt(upperBound: 4)
                    let dur    = Swift.min(raw, totalSteps - s - 1)
                    guard dur >= 2 else { break }
                    let vel = pnoVel(Swift.max(18, 40 - fi * 4 + rng.nextInt(upperBound: 7)))
                    if isLast { noteIdx = snapConst(noteIdx) }   // come to rest on a bell
                    events.append(MIDIEvent(stepIndex: s, note: evtNotes[noteIdx],
                                            velocity: vel, durationSteps: dur))
                    s += raw + 1 + rng.nextInt(upperBound: 2)
                    lastIdx = noteIdx
                    if hasTurn && fi == 0 {
                        noteIdx = Swift.min(noteIdx + 1, evtNotes.count - 1)  // turn: up first
                    } else {
                        let skip = rng.nextDouble() < 0.30 ? 2 : 1
                        noteIdx  = Swift.max(0, noteIdx - skip)
                    }
                }

            } else if roll < 0.68 {
                // Ascending figure with variation: optional arch (dip before peak), occasional 2-step leap.
                let startIdx = rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 2))
                let figLen   = 4 + rng.nextInt(upperBound: 4)
                var noteIdx  = startIdx
                var s        = cursor
                let hasArch  = rng.nextDouble() < 0.40
                let peakFi   = figLen - 2
                for fi in 0..<figLen {
                    guard s + 2 < totalSteps else { break }
                    let isLast = fi == figLen - 1
                    // Idea 3: 55% chance to extend the final note so it breathes into the gap.
                    let raw    = isLast ? (rng.nextDouble() < 0.55 ? 20 + rng.nextInt(upperBound: 9)
                                                                   : 10 + rng.nextInt(upperBound: 7))
                                       :  2 + rng.nextInt(upperBound: 4)
                    let dur    = Swift.min(raw, totalSteps - s - 1)
                    guard dur >= 2 else { break }
                    let vel = isLast ? pnoVel(30 + rng.nextInt(upperBound: 14))
                                    : pnoVel(22 + rng.nextInt(upperBound: 10))
                    if isLast { noteIdx = snapConst(noteIdx) }   // come to rest on a bell
                    events.append(MIDIEvent(stepIndex: s, note: evtNotes[noteIdx],
                                            velocity: vel, durationSteps: dur))
                    s += raw + 1 + rng.nextInt(upperBound: 2)
                    lastIdx = noteIdx
                    if hasArch && fi == peakFi {
                        noteIdx = Swift.max(startIdx, noteIdx - 1)  // arch: dip before final peak
                    } else {
                        let skip = rng.nextDouble() < 0.25 ? 2 : 1
                        noteIdx  = Swift.min(noteIdx + skip, evtNotes.count - 1)
                    }
                }

            } else if roll < 0.82 {
                // Skip-and-resolve: approach note → leap P4-P5 up → step back down 1-2.
                // The jump creates tension; the stepwise resolution releases it.
                let lowIdx = rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 2))
                let low    = evtNotes[lowIdx]
                let leap   = evtNotes.first(where: { Int($0) - Int(low) >= 5 && Int($0) - Int(low) <= 8 })
                          ?? evtNotes[Swift.min(lowIdx + 3, evtNotes.count - 1)]
                let leapIdx = evtNotes.firstIndex(of: leap) ?? Swift.min(lowIdx + 3, evtNotes.count - 1)
                var s = cursor
                let d0 = Swift.min(3 + rng.nextInt(upperBound: 3), totalSteps - s - 6)
                if d0 >= 2 {
                    events.append(MIDIEvent(stepIndex: s, note: low,
                                            velocity: pnoVel(24 + rng.nextInt(upperBound: 8)),
                                            durationSteps: d0))
                    s += d0 + 1; lastIdx = lowIdx
                }
                let d1 = Swift.min(4 + rng.nextInt(upperBound: 5), totalSteps - s - 4)
                if d1 >= 2 && s < totalSteps {
                    events.append(MIDIEvent(stepIndex: s, note: leap,
                                            velocity: pnoVel(32 + rng.nextInt(upperBound: 14)),
                                            durationSteps: d1))
                    s += d1 + 1; lastIdx = leapIdx
                }
                var resolveIdx = Swift.max(0, leapIdx - 1 - rng.nextInt(upperBound: 2))
                let resolveBell = snapConst(resolveIdx, within: 1)
                if resolveBell < leapIdx { resolveIdx = resolveBell }   // resolve down onto a bell
                // Idea 3: 55% chance to extend the resolve note so it breathes into the gap.
                let d2raw = rng.nextDouble() < 0.55 ? 20 + rng.nextInt(upperBound: 9)
                                                    : 10 + rng.nextInt(upperBound: 7)
                let d2 = Swift.min(d2raw, totalSteps - s)
                if d2 >= 4 && s < totalSteps {
                    events.append(MIDIEvent(stepIndex: s, note: evtNotes[resolveIdx],
                                            velocity: pnoVel(22 + rng.nextInt(upperBound: 10)),
                                            durationSteps: d2))
                    lastIdx = resolveIdx
                }

            } else {
                // Chord wash: 3-4 consonant notes rolled with 2-3 step stagger, each 8-12 steps.
                // Gives sparse Mode 1 songs occasional harmonic substance without dominating.
                let chordRootIdx = rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 2))
                let chordRoot    = evtNotes[chordRootIdx]
                var washNotes: [UInt8] = [chordRoot]
                if let third = evtNotes.first(where: { Int($0) - Int(chordRoot) == 4 || Int($0) - Int(chordRoot) == 3 }) {
                    washNotes.append(third)
                }
                if let fifth = evtNotes.first(where: { Int($0) - Int(chordRoot) == 7 }) {
                    washNotes.append(fifth)
                }
                if rng.nextDouble() < 0.40,
                   let color = evtNotes.first(where: { [10, 11, 12].contains(Int($0) - Int(chordRoot)) }) {
                    washNotes.append(color)
                }
                let washVel = pnoVel(52 + rng.nextInt(upperBound: 18))
                var s = cursor
                for (ci, note) in washNotes.enumerated() {
                    guard s < totalSteps - 4 else { break }
                    let dur = Swift.min(12 + rng.nextInt(upperBound: 9), totalSteps - s)
                    if dur >= 4 {
                        events.append(MIDIEvent(stepIndex: s, note: note,
                                                velocity: pnoVel(Swift.max(28, Int(washVel) - ci * 5)),
                                                durationSteps: dur))
                    }
                    s += 2 + rng.nextInt(upperBound: 2)
                }
                lastIdx = chordRootIdx
            }

            // Proportional gap capped at 3 bars (down from 5) — keeps song active without dead zones.
            let eventsLeft = eventCount - i - 1
            let remaining  = Swift.max(0, totalSteps - cursor) / 16
            let minGap = eventsLeft > 0 ? Swift.max(2, remaining / (eventsLeft + 1)) : 2
            let maxGap = Swift.min(minGap + 1, 3)
            cursor += (minGap + rng.nextInt(upperBound: Swift.max(1, maxGap - minGap + 1))) * 16
        }

        // Section anchors: fire a quiet chord wash at 1/3 and 2/3 if that region is bare.
        // Ensures long songs have harmonic landmarks even when the random event loop skips over them.
        let anchorBars = [totalBars / 3, (totalBars * 2) / 3]
        for anchorBar in anchorBars {
            let anchorStep = anchorBar * 16
            guard anchorStep < totalSteps - 32 else { continue }
            let hasNearby = events.contains { abs($0.stepIndex - anchorStep) < 32 }
            guard !hasNearby else { continue }
            let aRootIdx = evtNotes.count / 4 + rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 4))
            let aRoot = evtNotes[Swift.min(aRootIdx, evtNotes.count - 1)]
            var aChord: [UInt8] = [aRoot]
            if let third = evtNotes.first(where: { Int($0) - Int(aRoot) == 4 || Int($0) - Int(aRoot) == 3 }) {
                aChord.append(third)
            }
            if let fifth = evtNotes.first(where: { Int($0) - Int(aRoot) == 7 }) {
                aChord.append(fifth)
            }
            if let oct = evtNotes.first(where: { Int($0) - Int(aRoot) == 12 }) {
                aChord.append(oct)
            }
            let aVel = pnoVel(42 + rng.nextInt(upperBound: 12))
            for (ci, note) in aChord.enumerated() {
                let step = anchorStep + ci * 2
                let dur  = Swift.min(14 + rng.nextInt(upperBound: 6), totalSteps - step)
                if dur >= 4 && step < totalSteps {
                    events.append(MIDIEvent(stepIndex: step, note: note,
                                            velocity: pnoVel(Swift.max(26, Int(aVel) - ci * 5)),
                                            durationSteps: dur))
                }
            }
        }

        // Connector pass: bridge inter-phrase gaps with soft linking gestures.
        // Four improvements over the original single-grace-note approach:
        //   1. Perceived-gap correction: very soft sustains (vel ≤ 25) are treated as ending
        //      10 steps early, because the piano decay makes them inaudible before their MIDI off.
        //   2. Lower threshold (14 steps / ~1 bar) and higher probability (75%) — catches
        //      edge-case gaps that the old 24-step threshold missed.
        //   3. Long gaps (> 40 steps): use a sustained hold note (16–24 steps) instead of a
        //      brief grace note, so there's a real tone in the space rather than a flicker.
        //   4. Very long gaps (> 48 steps): add a second connector note, stepwise toward
        //      the incoming phrase's register, making it a 2-note bridge figure.
        let sorted = events.sorted { $0.stepIndex < $1.stepIndex }
        var connectors: [MIDIEvent] = []
        for i in sorted.indices.dropLast() {
            let ev       = sorted[i]
            let next     = sorted[i + 1]
            // Idea 1: shorten effective end of very soft sustains for perceived-gap purposes
            let perceivedEnd = (ev.velocity <= 25 && ev.durationSteps > 12)
                ? ev.stepIndex + ev.durationSteps - 10
                : ev.stepIndex + ev.durationSteps
            let perceivedGap = next.stepIndex - perceivedEnd
            guard perceivedGap > 14 else { continue }       // idea 2: lower threshold
            guard rng.nextDouble() < 0.75 else { continue } // idea 2: higher probability
            guard let lastEIdx = evtNotes.firstIndex(of: ev.note) else { continue }

            let connVel  = pnoVel(22 + rng.nextInt(upperBound: 9))
            let delta    = rng.nextDouble() < 0.50 ? 1 : -1
            let nbIdx    = Swift.max(0, Swift.min(evtNotes.count - 1, lastEIdx + delta))

            if perceivedGap > 48 {
                // Idea 4: two-note bridge — first note early in gap, second steps toward next phrase
                let midStep  = perceivedEnd + 4 + rng.nextInt(upperBound: Swift.max(1, perceivedGap / 3))
                let midDur   = Swift.min(16 + rng.nextInt(upperBound: 9), next.stepIndex - midStep - 4)
                if midDur >= 8 && midStep < next.stepIndex - 6 {
                    connectors.append(MIDIEvent(stepIndex: midStep, note: evtNotes[nbIdx],
                                                velocity: connVel, durationSteps: midDur))
                    // Second note: step toward the register of the incoming phrase
                    let incomingIdx  = evtNotes.firstIndex(of: next.note) ?? nbIdx
                    let stepToward   = nbIdx < incomingIdx ? 1 : (nbIdx > incomingIdx ? -1 : 0)
                    let nb2Idx       = Swift.max(0, Swift.min(evtNotes.count - 1, nbIdx + stepToward))
                    let lateStep     = midStep + midDur + 2 + rng.nextInt(upperBound: 4)
                    let lateDur      = Swift.min(12 + rng.nextInt(upperBound: 9), next.stepIndex - lateStep - 2)
                    if lateDur >= 6 && lateStep < next.stepIndex - 4 {
                        connectors.append(MIDIEvent(stepIndex: lateStep, note: evtNotes[nb2Idx],
                                                    velocity: pnoVel(Swift.max(20, Int(connVel) - 3)),
                                                    durationSteps: lateDur))
                    }
                }
            } else if perceivedGap > 40 {
                // Idea 3: sustained hold note — fills most of the gap with a ringing tone
                let holdStep = perceivedEnd + 3 + rng.nextInt(upperBound: 4)
                let holdDur  = Swift.min(16 + rng.nextInt(upperBound: 9), next.stepIndex - holdStep - 2)
                if holdDur >= 10 && holdStep < next.stepIndex - 4 {
                    connectors.append(MIDIEvent(stepIndex: holdStep, note: evtNotes[snapConst(nbIdx)],
                                                velocity: connVel, durationSteps: holdDur))
                }
            } else {
                // Short gap: original brief grace note, now with longer duration range
                let connStep = perceivedEnd + 4 + rng.nextInt(upperBound: Swift.max(1, perceivedGap / 2 - 4))
                let connDur  = Swift.min(8 + rng.nextInt(upperBound: 7), next.stepIndex - connStep - 2)
                if connDur >= 4 && connStep < next.stepIndex - 2 {
                    connectors.append(MIDIEvent(stepIndex: connStep, note: evtNotes[nbIdx],
                                                velocity: connVel, durationSteps: connDur))
                }
            }
        }
        events.append(contentsOf: connectors)

        return trimDissonances(events, totalSteps: totalSteps)
    }

    /// Mode 2 — Revealed chords: two alternating chords with melodic fragments woven into every gap.
    /// Two-pass design: Pass 1 places chord events with proportional spacing (max 4-bar gap);
    /// Pass 2 emits each chord plus a continuation gesture that fills the silence with either
    /// an arpeggio reveal, a stepwise melodic drift, or a soft echo cascade. Velocity follows
    /// a gentle arc (softer opening and closing, fuller middle) for even dynamic balance.
    static func floatingTonesMode2(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG, isEvolvePass: Bool = false
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let root     = frame.keySemitoneValue
        let scaleSet = Set(frame.scalePCs)
        func snapToScale(_ raw: Int) -> Int {
            let t = ((raw % 12) + 12) % 12
            if scaleSet.contains(t) { return t }
            for d in [1, -1, 2, -2] { let c = (t + d + 12) % 12; if scaleSet.contains(c) { return c } }
            return t
        }

        // Scale degrees used in voicings
        let b3   = snapToScale(root + 3)
        let p5   = snapToScale(root + 7)
        let p4   = snapToScale(root + 5)
        let maj6 = snapToScale(root + 9)
        let sus2 = snapToScale(root + 2)

        // Two bass registers
        var bBass = root + 48; while bBass > 50 { bBass -= 12 }; while bBass < 41 { bBass += 12 }
        let aOff  = rng.nextDouble() < 0.50 ? 7 : 3
        var aBass = bBass - aOff; while aBass < 39 { aBass += 12 }
        let aBassPC = snapToScale(aBass % 12)
        aBass = aBass - (aBass % 12) + aBassPC
        while aBass < 39 { aBass += 12 }
        while aBass > 54 { aBass -= 12 }

        func voice(_ pcs: [Int], bass: Int) -> [UInt8] {
            var notes: [UInt8] = []
            if bass >= 39 && bass <= 54 { notes.append(UInt8(bass)) }
            var midNotes: [Int] = []
            for pc in pcs {
                var m = pc + 60; while m > 75 { m -= 12 }; while m < 60 { m += 12 }
                let tooClose = midNotes.contains(where: { abs($0 - m) <= 2 })
                if m >= 60 && m <= 75 && !tooClose && !notes.contains(UInt8(m)) {
                    notes.append(UInt8(m)); midNotes.append(m)
                }
            }
            return Array(notes.sorted().prefix(4))
        }

        // Six distinct voicings spanning different scale-tone combinations (Idea 1).
        // Voicings where two melody-register notes form a tritone are filtered out:
        // in minor/Dorian keys voice([b3, maj6]) places a tritone (e.g. C–F# in A Dorian).
        let voicingPool: [[UInt8]] = [
            voice([root, b3, p5],   bass: aBass),   // root triad
            voice([root, b3, maj6], bass: aBass),   // major 6th chord (Harold Budd signature)
            voice([root, p4, p5],   bass: aBass),   // sus4 open voicing
            voice([b3, p5],         bass: bBass),   // 5th bass, upper dyad
            voice([b3, maj6],       bass: bBass),   // 5th bass, 3rd+6th
            voice([sus2, p5],       bass: aBass),   // sus2 feel
        ].filter { v in
            guard v.count >= 2 else { return false }
            let rh = v.filter { $0 >= 57 }
            for i in 0..<rh.count {
                for j in (i+1)..<rh.count {
                    if (Int(rh[j]) - Int(rh[i])) % 12 == 6 { return false }
                }
            }
            return true
        }
        guard !voicingPool.isEmpty else { return [] }   // an unusual scale can filter every voicing out

        let baseChordVel = 22 + rng.nextInt(upperBound: 14)   // 22-35: chords sit behind the melody (Idea 3)
        let scaleHigh    = notesInRegister(pitchClasses: Set(frame.scalePCs), low: 62, high: 85)
        var events: [MIDIEvent] = []

        // ── Pass 1: distribute chord events with density arc (Idea 4) ──
        struct ChordSlot { var step: Int; var chord: [UInt8]; var dur: Int; var chordVel: UInt8; var melVel: UInt8 }
        var slots: [ChordSlot] = []
        var cursor = 0
        var lastVoicingIdx = -1
        let target = 16 + rng.nextInt(upperBound: 10)   // 16–25 events

        for i in 0..<target {
            guard cursor < totalSteps - 16 else { break }

            // Beat anchor: 30% chance of snapping to nearest half-bar boundary (Idea 2)
            var startStep = cursor
            if rng.nextDouble() < 0.30 {
                let snapped = ((cursor + 4) / 8) * 8
                if snapped < totalSteps - 16 { startStep = snapped }
            }

            // Pick voicing, avoiding consecutive repeats (Idea 1)
            var vIdx = rng.nextInt(upperBound: voicingPool.count)
            if voicingPool.count > 1 {
                var tries = 0
                while vIdx == lastVoicingIdx && tries < 4 { vIdx = rng.nextInt(upperBound: voicingPool.count); tries += 1 }
            }
            lastVoicingIdx = vIdx
            let chord = voicingPool[vIdx]

            // Chord velocity: soft wash with gentle arc at edges (Idea 3)
            let songPos  = Double(startStep) / Double(totalSteps)
            let arcFade  = songPos < 0.15 ? Int(songPos / 0.15 * 6) :
                           songPos > 0.80 ? Int((1.0 - songPos) / 0.20 * 6) : 6
            let chordVel = pnoVel(Swift.max(18, Swift.min(38, baseChordVel - 3 + arcFade + rng.nextInt(upperBound: 7))))
            // Melody notes sit noticeably above the chord wash (Idea 3)
            let melVel   = pnoVel(Swift.max(32, Swift.min(58, Int(chordVel) + 14 + rng.nextInt(upperBound: 12))))

            var dur = 0
            if rng.nextDouble() < 0.15 && i > 0 {
                // Occasional single "breath" note — one mid voice only
                let bNote = chord.count > 1 ? chord[1] : chord[0]
                let bDur  = Swift.min(10 + rng.nextInt(upperBound: 7), totalSteps - startStep)
                if bDur >= 4 { slots.append(ChordSlot(step: startStep, chord: [bNote], dur: bDur, chordVel: chordVel, melVel: melVel)) }
                dur = Swift.max(bDur, 4)
            } else {
                dur = rng.nextDouble() < 0.50
                    ? Swift.min(10 + rng.nextInt(upperBound: 7),  totalSteps - startStep)
                    : Swift.min(16 + rng.nextInt(upperBound: 13), totalSteps - startStep)
                if dur >= 4 { slots.append(ChordSlot(step: startStep, chord: chord, dur: dur, chordVel: chordVel, melVel: melVel)) }
            }

            // Gap with density arc: sparse at edges (×1.75), denser in the middle (×0.85) (Idea 4)
            let eventsLeft = target - i - 1
            let remaining  = Swift.max(1, totalSteps - startStep - dur)
            let avgGap     = eventsLeft > 0 ? remaining / (eventsLeft + 1) : remaining / 2
            let denseMult: Double = isEvolvePass ? 0.85 :
                                    (songPos < 0.15 || songPos > 0.80) ? 1.75 :
                                    (songPos < 0.30 || songPos > 0.65) ? 1.20 : 0.85
            let scaledAvg  = Swift.max(8, Int(Double(avgGap) * denseMult))
            let rawGap = rng.nextDouble() < 0.60
                ? Swift.max(8,  scaledAvg / 2 + rng.nextInt(upperBound: Swift.max(1, scaledAvg / 4)))
                : Swift.max(16, scaledAvg     + rng.nextInt(upperBound: Swift.max(1, scaledAvg / 3)))
            cursor = startStep + dur + Swift.min(rawGap, 80)   // 5-bar max gap
        }

        // ── Pass 2: emit chord notes + immediate echo + continuation gesture ──
        for (idx, slot) in slots.enumerated() {
            let nextStart = idx + 1 < slots.count ? slots[idx + 1].step : totalSteps
            let gapStart  = slot.step + slot.dur + 2
            let gapEnd    = Swift.max(gapStart, nextStart - 4)
            let gapSize   = gapEnd - gapStart

            // Chord notes (soft wash)
            for note in slot.chord {
                events.append(MIDIEvent(stepIndex: slot.step, note: note,
                                        velocity: slot.chordVel, durationSteps: slot.dur))
            }

            // Immediate echo: top voice steps to scale neighbor — melVel keeps it above the wash
            if slot.chord.count > 1, let topNote = slot.chord.last,
               let ci = scaleHigh.firstIndex(of: topNote) {
                let echoStart = slot.step + slot.dur + 3 + rng.nextInt(upperBound: 5)
                if echoStart < totalSteps {
                    let goUp   = rng.nextDouble() < 0.55
                    let nb1Idx = goUp ? Swift.min(ci + 1, scaleHigh.count - 1) : Swift.max(0, ci - 1)
                    let nb1    = scaleHigh[nb1Idx]
                    if nb1 != topNote {
                        let e1dur = Swift.min(5 + rng.nextInt(upperBound: 7), totalSteps - echoStart)
                        if e1dur >= 2 {
                            events.append(MIDIEvent(stepIndex: echoStart, note: nb1,
                                                    velocity: slot.melVel,
                                                    durationSteps: e1dur))
                            let e2start = echoStart + e1dur + 1
                            if e2start < totalSteps {
                                let nb2Idx = goUp ? Swift.min(nb1Idx + 1, scaleHigh.count - 1) : Swift.max(0, nb1Idx - 1)
                                let nb2    = scaleHigh[nb2Idx]
                                let e2dur  = Swift.min(5 + rng.nextInt(upperBound: 9), totalSteps - e2start)
                                if e2dur >= 2 && nb2 != nb1 {
                                    events.append(MIDIEvent(stepIndex: e2start, note: nb2,
                                                            velocity: pnoVel(Swift.max(22, Int(slot.melVel) - 8)),
                                                            durationSteps: e2dur))
                                    if rng.nextDouble() < 0.60 {
                                        let e3start = e2start + e2dur + 2
                                        let e3dur   = Swift.min(4 + rng.nextInt(upperBound: 8), totalSteps - e3start)
                                        if e3start < totalSteps && e3dur >= 2 {
                                            events.append(MIDIEvent(stepIndex: e3start, note: nb1,
                                                                    velocity: pnoVel(Swift.max(18, Int(slot.melVel) - 14)),
                                                                    durationSteps: e3dur))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Continuation gesture — fills every gap > 2 bars with musical content.
            // Skip if the gap starts in the final 15% to avoid ghost-note tails.
            let isInCoda = Double(gapStart) / Double(totalSteps) > 0.85
            guard gapSize >= 32, !scaleHigh.isEmpty, !isInCoda else { continue }
            let gestureRoll = rng.nextDouble()
            let gVel = slot.melVel

            if gestureRoll < 0.35 {
                // Arpeggio reveal: chord tones enter one by one
                var s = gapStart + 4 + rng.nextInt(upperBound: 8)
                for note in slot.chord {
                    guard s + 6 < gapEnd else { break }
                    let noteDur = Swift.min(8 + rng.nextInt(upperBound: 7), gapEnd - s)
                    events.append(MIDIEvent(stepIndex: s, note: note,
                                            velocity: pnoVel(Swift.max(18, Int(gVel) - 8)),
                                            durationSteps: noteDur))
                    s += 4 + rng.nextInt(upperBound: 5)
                }
            } else if gestureRoll < 0.68 {
                // Melodic drift: stepwise figure from chord top — Budd's climbing/descending gesture
                let topNote  = slot.chord.last ?? slot.chord[0]
                let startIdx = scaleHigh.firstIndex(of: topNote) ?? (scaleHigh.count / 2)
                let ascending = rng.nextDouble() < 0.50
                let count    = 3 + rng.nextInt(upperBound: 4)
                var s        = gapStart + 8 + rng.nextInt(upperBound: 14)
                var noteIdx  = startIdx
                for n in 0..<count {
                    guard s + 6 < gapEnd else { break }
                    let isLast  = n == count - 1
                    let noteDur = isLast
                        ? Swift.min(8 + rng.nextInt(upperBound: 9), gapEnd - s)
                        : Swift.min(3 + rng.nextInt(upperBound: 3), gapEnd - s)
                    guard noteDur >= 2 else { break }
                    events.append(MIDIEvent(stepIndex: s, note: scaleHigh[noteIdx],
                                            velocity: pnoVel(Swift.max(18, Int(gVel) - n * 4)),
                                            durationSteps: noteDur))
                    s += noteDur + 2 + rng.nextInt(upperBound: 4)
                    let step = rng.nextDouble() < 0.25 ? 2 : 1
                    noteIdx = ascending
                        ? Swift.min(noteIdx + step, scaleHigh.count - 1)
                        : Swift.max(0, noteIdx - step)
                }
            } else {
                // Turn ornament: brief upward reversal then descent
                let topNote  = slot.chord.last ?? slot.chord[0]
                let startIdx = scaleHigh.firstIndex(of: topNote) ?? (scaleHigh.count / 2)
                let descentCount = 2 + rng.nextInt(upperBound: 2)
                var idxOffsets = [1, 0]
                for d in 1...descentCount { idxOffsets.append(-d) }
                var s = gapStart + 6 + rng.nextInt(upperBound: 10)
                for (n, offset) in idxOffsets.enumerated() {
                    guard s + 6 < gapEnd else { break }
                    let idx     = Swift.max(0, Swift.min(startIdx + offset, scaleHigh.count - 1))
                    let isLast  = n == idxOffsets.count - 1
                    let noteDur = isLast
                        ? Swift.min(8 + rng.nextInt(upperBound: 9), gapEnd - s)
                        : Swift.min(3 + rng.nextInt(upperBound: 4), gapEnd - s)
                    guard noteDur >= 2 else { break }
                    events.append(MIDIEvent(stepIndex: s, note: scaleHigh[idx],
                                            velocity: pnoVel(Swift.max(20, Int(gVel) - n * 6)),
                                            durationSteps: noteDur))
                    s += noteDur + 3 + rng.nextInt(upperBound: 5)
                }
            }
        }

        // ── Closing chord: tonic resolution when song trails off ──
        let lastStep   = events.max(by: { $0.stepIndex < $1.stepIndex })?.stepIndex ?? 0
        let trailSteps = totalSteps - lastStep
        if !isEvolvePass && trailSteps > 9 * 16 {
            let closingStep = totalSteps - (9 + rng.nextInt(upperBound: 2)) * 16
            let closingDur  = Swift.min(totalSteps - closingStep - 4, 2 * 16)
            if closingStep > lastStep + 16 && closingDur >= 16 {
                let closingVel = pnoVel(Swift.max(32, Swift.min(52, baseChordVel + 12)))
                for note in voicingPool[0] {
                    events.append(MIDIEvent(stepIndex: closingStep, note: note,
                                            velocity: closingVel,
                                            durationSteps: closingDur))
                }
            }
        }

        return trimDissonances(events, totalSteps: totalSteps)
    }

    /// Mode 3 — Pendulum: metronomic A↔B oscillation every beat between two clusters of scale thirds, over a slow bass line.
    static func floatingTonesMode3(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG, isEvolvePass: Bool = false
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let allMid     = notesInRegister(pitchClasses: scalePCs, low: 59, high: 73)
        guard allMid.count >= 3 else { return [] }

        // Build clusters using stride-2 pool indices — gives m3/M3 intervals (consonant thirds)
        // rather than stride-1 (M2/m2 seconds which sound dissonant in dense repetition).
        let anchorIdx = rng.nextInt(upperBound: Swift.max(1, allMid.count - 6))
        let a0 = Int(allMid[anchorIdx])
        let a2 = Int(allMid[Swift.min(anchorIdx + 2, allMid.count - 1)])  // skip a1: m3/M3 instead of M2
        let a4 = Int(allMid[Swift.min(anchorIdx + 4, allMid.count - 1)])
        let a1 = Int(allMid[Swift.min(anchorIdx + 1, allMid.count - 1)])
        let a3 = Int(allMid[Swift.min(anchorIdx + 3, allMid.count - 1)])
        var clA: [Int] = [a0, a2]   // third apart
        if rng.nextDouble() < 0.50 { clA.append(a4) }
        var clB: [Int] = [a1, a3]   // third apart, interleaved with clA
        if rng.nextDouble() < 0.50 { clB.append(Int(allMid[Swift.min(anchorIdx + 5, allMid.count - 1)])) }

        // Bass progression (G2–G3 range — mid-bass register, avoids sub-bass crowding)
        let bassPool  = notesInRegister(pitchClasses: scalePCs, low: 43, high: 55)
        let numBass   = 4 + rng.nextInt(upperBound: 3)
        let bassSeq   = (0..<numBass).map { _ in bassPool.isEmpty ? UInt8(28) : bassPool[rng.nextInt(upperBound: bassPool.count)] }
        let baseVel3  = 46 + rng.nextInt(upperBound: 12)  // base velocity; per-cluster variation applied below

        var events: [MIDIEvent] = []

        // Pendulum section: 12-20 bars in the middle — metronomic oscillation as a contained body, not the whole song
        let pendLength = 12 + rng.nextInt(upperBound: 9)
        let pendStart  = totalBars * 30 / 100
        let pendEnd    = Swift.min(pendStart + pendLength, totalBars * 72 / 100)

        // Opening — descending melodic phrases + growing pendulum fragments, no silent gaps.
        // Each cycle: a 3-5 note phrase (3-10 steps/note, short piano-appropriate durations)
        // descending through allMid, then 2-3 bars of a0/a1 fragments. Melody stays above
        // anchorIdx+1 so it never collides with the pendulum register until handoff.
        var oCursor  = isEvolvePass ? 0 : 16  // bar 1 for evolve passes, bar 2 otherwise
        var melIdx   = allMid.count - 1 - rng.nextInt(upperBound: 2)  // near top of register
        var oFlip    = true
        let openEnd  = pendStart * 16
        while oCursor < openEnd - 16 {
            let progress = openEnd > 16 ? Double(oCursor) / Double(openEnd) : 0.0
            let velBase  = 22 + Int(progress * 30)  // 22→52 approaching pendulum

            // Melodic phrase: 3-5 notes, mostly stepwise descending, each 3-10 steps
            let phraseLen = 3 + rng.nextInt(upperBound: 3)
            var pIdx = melIdx
            var s    = oCursor
            for n in 0..<phraseLen {
                guard s + 4 < openEnd else { break }
                let note   = allMid[pIdx]
                let isLast = n == phraseLen - 1
                let raw    = isLast ? 6 + rng.nextInt(upperBound: 5)   // dotted-quarter → half
                                    : 3 + rng.nextInt(upperBound: 4)   // 16th → dotted-quarter
                let dur    = Swift.min(raw, openEnd - s - 2)
                if dur >= 2 && note >= 21 && note <= 108 {
                    let vel = pnoVel(Swift.max(20, Swift.min(56, velBase + rng.nextInt(upperBound: 10) - 4)))
                    events.append(MIDIEvent(stepIndex: s, note: note, velocity: vel, durationSteps: dur))
                }
                let mv = rng.nextDouble()
                if mv < 0.65      { pIdx = Swift.max(anchorIdx + 1, pIdx - 1) }
                else if mv < 0.85 { /* stay */ }
                else              { pIdx = Swift.min(allMid.count - 1, pIdx + 1) }
                s += raw + 1 + rng.nextInt(upperBound: 3)
            }

            // Pendulum fragments fill the gap after the phrase (2-3 bars)
            let fragBars  = 2 + rng.nextInt(upperBound: 2)
            let fragEnd   = Swift.min(s + fragBars * 16, openEnd)
            let fragCount = 1 + Int(progress * 3.5) + rng.nextInt(upperBound: 2)
            var fs = s + 2 + rng.nextInt(upperBound: 6)
            let fragVel   = pnoVel(Swift.max(20, velBase - 10))
            for _ in 0..<fragCount {
                guard fs + 3 < fragEnd else { break }
                let fNote = oFlip ? a0 : a1
                guard fNote >= 21 && fNote <= 108 else { oFlip.toggle(); fs += 4; continue }
                let dur = Swift.min(3 + rng.nextInt(upperBound: 3), fragEnd - fs)
                if dur >= 2 {
                    events.append(MIDIEvent(stepIndex: fs, note: UInt8(fNote),
                                            velocity: fragVel, durationSteps: dur))
                    oFlip.toggle()
                }
                fs += dur + 2
            }
            melIdx  = Swift.max(anchorIdx + 2, melIdx - 1)  // floor at anchorIdx+2, step down each cycle
            oCursor = fragEnd
        }

        // Pendulum body — A/B single-note alternation for stepwise melody; 35% chance adds chord texture
        // (cluster-only approach produced 0% stepwise — all within-cluster intervals are thirds)
        let pendTotalSteps = Swift.max(1, (pendEnd - pendStart) * 16)
        var step = pendStart * 16; var useA = true
        while step < pendEnd * 16 && step < totalSteps {
            let primaryNote = useA ? a0 : a1  // alternate adjacent scale tones → stepwise motion
            let harmNote    = useA ? a2 : a3  // optional chord harmony a third above
            let dur = Swift.min(3 + rng.nextInt(upperBound: 2), totalSteps - step)
            // Slow sine breath (±10) over ~2.5 cycles through the pendulum + small per-note jitter (±4).
            // Produces 2-3 dynamic swells so the section breathes rather than sitting uniformly loud.
            let t = Double(step - pendStart * 16) / Double(pendTotalSteps)
            let breathBoost = Int(sin(t * .pi * 2.5) * 10.0)
            let clVel = pnoVel(Swift.max(22, Swift.min(54, baseVel3 + breathBoost + rng.nextInt(upperBound: 9) - 4)))
            guard primaryNote >= 21 && primaryNote <= 108 else { useA.toggle(); step += 4; continue }
            events.append(MIDIEvent(stepIndex: step, note: UInt8(primaryNote), velocity: clVel, durationSteps: dur))
            if rng.nextDouble() < 0.35 && harmNote != primaryNote && harmNote >= 21 && harmNote <= 108 {
                events.append(MIDIEvent(stepIndex: step, note: UInt8(harmNote),
                                        velocity: clVel > 8 ? clVel - 8 : clVel, durationSteps: dur))
            }
            // Primary bass every 2 bars (full velocity, octave doubled).
            // Secondary lighter hit at every 1-bar mark (40% chance) fills sparse stretches like bars 29-33.
            if step % 32 == 0 {
                let bassIdx = (step / 32) % bassSeq.count
                let br = Int(bassSeq[bassIdx])
                let bd = Swift.min(28 + rng.nextInt(upperBound: 5), totalSteps - step)
                let bVel = pnoVel(Swift.max(36, Swift.min(65, baseVel3 + rng.nextInt(upperBound: 11) - 5)))
                if bd >= 4 && br >= 21 && br <= 108 {
                    events.append(MIDIEvent(stepIndex: step, note: UInt8(br), velocity: bVel, durationSteps: bd))
                    let br2 = br + 12
                    if br2 <= 50 { events.append(MIDIEvent(stepIndex: step, note: UInt8(br2), velocity: bVel, durationSteps: bd)) }
                }
            } else if step % 16 == 0 && rng.nextDouble() < 0.40 {
                let bassIdx = (step / 32) % bassSeq.count
                let br = Int(bassSeq[bassIdx])
                let bd = Swift.min(14 + rng.nextInt(upperBound: 7), totalSteps - step)
                let bVel = pnoVel(Swift.max(26, Swift.min(48, baseVel3 - 12 + rng.nextInt(upperBound: 9) - 4)))
                if bd >= 4 && br >= 21 && br <= 108 {
                    events.append(MIDIEvent(stepIndex: step, note: UInt8(br), velocity: bVel, durationSteps: bd))
                }
            }
            useA.toggle(); step += 4
        }

        // Pendulum melody overlay — 2-4 note phrases floating above the oscillation every 2-4 bars.
        // Notes stay above anchorIdx+1, use same short durations as opening/closing phrases.
        // This adds melodic interest over the repeating a0/a1 figure without replacing it.
        var mStep   = pendStart * 16 + (1 + rng.nextInt(upperBound: 2)) * 16  // starts 1-2 bars in
        var mMelIdx = Swift.min(anchorIdx + 3, allMid.count - 1)
        while mStep < pendEnd * 16 - 16 {
            let pLen = 2 + rng.nextInt(upperBound: 3)  // 2-4 notes
            var mIdx = mMelIdx
            var ms   = mStep
            for mn in 0..<pLen {
                guard ms + 4 < pendEnd * 16 else { break }
                let mNote   = allMid[mIdx]
                let mIsLast = mn == pLen - 1
                let mRaw    = mIsLast ? 8 + rng.nextInt(upperBound: 5)   // half note
                                      : 3 + rng.nextInt(upperBound: 4)   // 16th → dotted-quarter
                let mDur    = Swift.min(mRaw, pendEnd * 16 - ms - 2)
                if mDur >= 2 && mNote >= 21 && mNote <= 108 {
                    let mVel = pnoVel(Swift.max(28, Swift.min(58, Int(baseVel3) - 6 + rng.nextInt(upperBound: 10))))
                    events.append(MIDIEvent(stepIndex: ms, note: mNote, velocity: mVel, durationSteps: mDur))
                }
                let mm = rng.nextDouble()
                if mm < 0.42      { mIdx = Swift.max(anchorIdx + 1, mIdx - 1) }
                else if mm < 0.78 { mIdx = Swift.min(allMid.count - 1, mIdx + 1) }
                ms += mRaw + 1 + rng.nextInt(upperBound: 3)
            }
            mMelIdx = Swift.min(anchorIdx + 2 + rng.nextInt(upperBound: Swift.max(1, allMid.count - anchorIdx - 2)),
                                allMid.count - 1)
            mStep  += (2 + rng.nextInt(upperBound: 3)) * 16
        }

        // Closing — ascending melodic phrases + shrinking fragments, mirror of opening.
        // Each cycle: a 3-5 note ascending phrase, then 2-3 bars of fragments.
        // melody ascends anchorIdx+2 → top of register over the closing span.
        var cCursor   = pendEnd * 16
        var melIdxC   = Swift.min(anchorIdx + 2, allMid.count - 1)
        var cFlip     = true
        let closePend = pendEnd * 16
        let closeSpan = Swift.max(1, totalSteps - closePend)
        while cCursor < totalSteps - 16 {
            let progress  = 1.0 - Double(cCursor - closePend) / Double(closeSpan)  // 1→0
            let velBase   = 18 + Int(progress * 34)  // 52→18 as we fade

            // Ascending phrase: 3-5 notes, mostly stepwise upward, each 3-10 steps
            let phraseLen = 3 + rng.nextInt(upperBound: 3)
            var pIdx = melIdxC
            var s    = cCursor
            for n in 0..<phraseLen {
                guard s + 4 < totalSteps else { break }
                let note   = allMid[pIdx]
                let isLast = n == phraseLen - 1
                let raw    = isLast ? 6 + rng.nextInt(upperBound: 5) : 3 + rng.nextInt(upperBound: 4)
                let dur    = Swift.min(raw, totalSteps - s - 2)
                if dur >= 2 && note >= 21 && note <= 108 {
                    let vel = pnoVel(Swift.max(16, Swift.min(54, velBase + rng.nextInt(upperBound: 10) - 4)))
                    events.append(MIDIEvent(stepIndex: s, note: note, velocity: vel, durationSteps: dur))
                }
                let mv = rng.nextDouble()
                if mv < 0.60      { pIdx = Swift.min(allMid.count - 1, pIdx + 1) }
                else if mv < 0.80 { /* stay */ }
                else              { pIdx = Swift.max(anchorIdx + 1, pIdx - 1) }
                s += raw + 1 + rng.nextInt(upperBound: 3)
            }

            // Fragments fill the gap after each phrase (2-3 bars)
            let fragBars  = 2 + rng.nextInt(upperBound: 2)
            let fragEnd   = Swift.min(s + fragBars * 16, totalSteps)
            let fragCount = 1 + Int(progress * 3.5) + rng.nextInt(upperBound: 2)
            var fs = s + 2 + rng.nextInt(upperBound: 6)
            let fragVel   = pnoVel(Swift.max(20, velBase - 10))
            for _ in 0..<fragCount {
                guard fs + 3 < fragEnd else { break }
                let fNote = cFlip ? a0 : a1
                guard fNote >= 21 && fNote <= 108 else { cFlip.toggle(); fs += 4; continue }
                let dur = Swift.min(3 + rng.nextInt(upperBound: 3), fragEnd - fs)
                if dur >= 2 {
                    events.append(MIDIEvent(stepIndex: fs, note: UInt8(fNote),
                                            velocity: fragVel, durationSteps: dur))
                    cFlip.toggle()
                }
                fs += dur + 2
            }
            melIdxC = Swift.min(allMid.count - 1, melIdxC + (rng.nextDouble() < 0.65 ? 1 : 0))
            cCursor = fragEnd
        }

        return trimDissonances(events, totalSteps: totalSteps)
    }
}
