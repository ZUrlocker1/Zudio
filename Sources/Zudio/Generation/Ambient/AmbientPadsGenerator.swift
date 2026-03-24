// AmbientPadsGenerator.swift — Ambient pads generation
// AMB-PAD-001: Primary sustained chord layer (velocity 85–100, re-attack every 16–20 steps)
// AMB-PAD-002: Secondary shimmer layer (velocity 25–55, offset 2–4 steps after primary)
// AMB-PAD-006: Bell accent layer (~0.07 notes/bar, staccato, velocity 35–55, high register)
// Generates a short loop (loopBars); AmbientLoopTiler tiles it to full song length.

import Foundation

struct AmbientPadsGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        guard let entry = tonalMap.entry(atBar: 0) else { return [] }
        usedRuleIDs.insert("AMB-PADS-001")

        let bounds    = kRegisterBounds[kTrackPads]!   // low:48, high:84
        let loopSteps = loopBars * 16
        let chordPCs  = entry.chordWindow.chordTones
        let allNotes  = notesInRegister(pitchClasses: chordPCs, low: bounds.low, high: bounds.high)
        guard allNotes.count >= 2 else { return [] }

        var events: [MIDIEvent] = []

        // AMB-PAD-001: Primary layer — spread chord, long holds, re-attack every 2–4 bars.
        // Duration is shorter than reattack so each chord fades before the next arrives (breathing).
        // 30% chance any given re-attack is skipped to add organic gaps.
        let reattack = 32 + rng.nextInt(upperBound: 33)   // 32–64 steps (2–4 bars)
        let duration = reattack - 4 - rng.nextInt(upperBound: 9)  // slightly shorter = brief gap between
        let spread   = spreadNotes(from: allNotes, count: 3)

        var step = rng.nextInt(upperBound: 8)   // small random offset at start
        while step < loopSteps {
            if rng.nextDouble() > 0.30 {   // 70% chance each re-attack fires (30% skip = organic gap)
                let vel = UInt8(75 + rng.nextInt(upperBound: 21))  // 75–95
                for note in spread {
                    let dur = Swift.min(duration, loopSteps - step)
                    if dur >= 4 {
                        events.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: dur))
                    }
                }
            }
            step += reattack
        }

        // AMB-PAD-002: Secondary shimmer — only 40% chance; upper notes only, very soft
        if rng.nextDouble() < 0.40 {
            usedRuleIDs.insert("AMB-PADS-002")
            let offset  = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps behind primary
            let shimmer = spread.suffix(2).map { $0 }       // upper notes only
            var step2   = offset
            while step2 < loopSteps {
                if rng.nextDouble() > 0.35 {   // 65% fire rate (35% skip)
                    let vel = UInt8(20 + rng.nextInt(upperBound: 26))  // 20–45 (very soft)
                    for note in shimmer {
                        let dur = Swift.min(duration - 4, loopSteps - step2)
                        if dur >= 4 {
                            events.append(MIDIEvent(stepIndex: step2, note: note, velocity: vel, durationSteps: dur))
                        }
                    }
                }
                step2 += reattack + rng.nextInt(upperBound: 8)   // slight drift from primary
            }
        }

        // AMB-PAD-006: Bell accent — sparse staccato in high register
        if rng.nextDouble() < 0.50 {
            usedRuleIDs.insert("AMB-PADS-006")
            let highNotes = notesInRegister(pitchClasses: chordPCs, low: 72, high: 100)
            if !highNotes.isEmpty {
                let bellCount = Swift.max(1, Int(Double(loopBars) * 0.07))
                for _ in 0..<bellCount {
                    let s    = rng.nextInt(upperBound: loopSteps)
                    let note = highNotes[rng.nextInt(upperBound: highNotes.count)]
                    let vel  = UInt8(35 + rng.nextInt(upperBound: 21))  // 35–55
                    events.append(MIDIEvent(stepIndex: s, note: note, velocity: vel, durationSteps: 4))
                }
            }
        }

        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    // MARK: - Helpers

    private static func notesInRegister(pitchClasses: Set<Int>, low: Int, high: Int) -> [UInt8] {
        guard low <= high else { return [] }
        return (low...high).compactMap { n in pitchClasses.contains(n % 12) ? UInt8(n) : nil }
    }

    /// Returns [low, mid, high] spread across the available notes.
    private static func spreadNotes(from notes: [UInt8], count: Int) -> [UInt8] {
        guard notes.count >= count else { return notes }
        return [notes[0], notes[notes.count / 2], notes[notes.count - 1]]
    }
}
