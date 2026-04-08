// AmbientTextureGenerator.swift — Ambient texture generation
// AMB-TEXT-004 (40%): silent
// AMB-TEXT-001 (30%): orbital shimmer — sparse high notes, velocity 18–39
// AMB-TEXT-002 (20%): ghost tone — 1–2 very low-velocity long-held notes
// AMB-TEXT-003 (10%): chime scatter — 2–5 staccato notes at random positions
// Generates a short loop; AmbientLoopTiler tiles to full song length.

import Foundation

struct AmbientTextureGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceNonSilent: Bool = false
    ) -> [MIDIEvent] {
        let roll = rng.nextDouble()
        if !forceNonSilent && roll < 0.40 { usedRuleIDs.insert("AMB-TEXT-004"); return [] }

        let bounds    = kRegisterBounds[kTrackTexture]!  // low:36, high:96
        let loopSteps = loopBars * 16
        let scalePCs  = Set(frame.mode.intervals.map { (frame.keySemitoneValue + $0) % 12 })
        let chordPCs  = tonalMap.entry(atBar: 0)?.chordWindow.chordTones ?? scalePCs

        if roll < 0.70 {
            usedRuleIDs.insert("AMB-TEXT-001")
            return orbitalShimmer(scalePCs: scalePCs, bounds: bounds, loopSteps: loopSteps, rng: &rng)
        }
        if roll < 0.90 {
            usedRuleIDs.insert("AMB-TEXT-002")
            return ghostTone(chordPCs: chordPCs, bounds: bounds, loopSteps: loopSteps, rng: &rng)
        }
        usedRuleIDs.insert("AMB-TEXT-003")
        return chimeScatter(scalePCs: scalePCs, bounds: bounds, loopSteps: loopSteps, rng: &rng)
    }

    // MARK: - Rules

    /// Slowly cycling high notes — sparse, velocity 18–39.
    private static func orbitalShimmer(scalePCs: Set<Int>, bounds: RegisterBounds,
                                        loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let highNotes = notesInRegister(pitchClasses: scalePCs, low: Swift.max(bounds.low, 72), high: bounds.high)
        guard !highNotes.isEmpty else { return [] }
        var events: [MIDIEvent] = []
        var step = rng.nextInt(upperBound: 12)
        while step < loopSteps {
            if rng.nextDouble() < 0.45 {
                let note = highNotes[rng.nextInt(upperBound: highNotes.count)]
                let vel  = UInt8(18 + rng.nextInt(upperBound: 22))  // 18–39
                let dur  = Swift.min(6 + rng.nextInt(upperBound: 11), loopSteps - step)  // 6–16
                if dur >= 2 {
                    events.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: dur))
                }
            }
            step += 8 + rng.nextInt(upperBound: 8)  // 8–15 steps between opportunities
        }
        return events
    }

    /// Very low velocity long-held tone — 1–2 per loop.
    private static func ghostTone(chordPCs: Set<Int>, bounds: RegisterBounds,
                                   loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let pool = notesInRegister(pitchClasses: chordPCs, low: bounds.low, high: bounds.high)
        guard !pool.isEmpty else { return [] }
        var events: [MIDIEvent] = []
        let count = 1 + rng.nextInt(upperBound: 2)
        let slot  = Swift.max(8, loopSteps / count)
        for i in 0..<count {
            let start = slot * i + rng.nextInt(upperBound: Swift.max(1, slot / 2))
            if start >= loopSteps { break }
            let dur = Swift.min(slot - 4, loopSteps - start)
            if dur >= 8 {
                let note = pool[rng.nextInt(upperBound: pool.count)]
                let vel  = UInt8(12 + rng.nextInt(upperBound: 18))  // 12–29
                events.append(MIDIEvent(stepIndex: start, note: note, velocity: vel, durationSteps: dur))
            }
        }
        return events
    }

    /// Sparse scatter of 2–5 short notes at random positions.
    private static func chimeScatter(scalePCs: Set<Int>, bounds: RegisterBounds,
                                      loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let pool = notesInRegister(pitchClasses: scalePCs, low: bounds.low, high: bounds.high)
        guard !pool.isEmpty else { return [] }
        let count = 2 + rng.nextInt(upperBound: 4)  // 2–5
        var events: [MIDIEvent] = []
        for _ in 0..<count {
            let step = rng.nextInt(upperBound: loopSteps)
            let note = pool[rng.nextInt(upperBound: pool.count)]
            let vel  = UInt8(25 + rng.nextInt(upperBound: 30))  // 25–54
            events.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: 3))
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

}
