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
        // Voicing varies per reattack: note count (2–4) and inversion rotate for variety.
        let reattack  = 32 + rng.nextInt(upperBound: 33)   // 32–64 steps (2–4 bars)
        let duration  = reattack - 4 - rng.nextInt(upperBound: 9)  // slightly shorter = brief gap
        let baseVel   = 55 + rng.nextInt(upperBound: 16)    // 55–70, consistent base per loop
        var invOffset = 0   // rotates through inversions

        var step = rng.nextInt(upperBound: 8)   // small random offset at start
        var primarySteps = Set<Int>()           // track primary steps for bell accent spacing
        while step < loopSteps {
            if rng.nextDouble() > 0.30 {   // 70% fire rate
                // Vary note count: 2 notes (20%), 3 notes (60%), 4 notes (20%)
                let r = rng.nextDouble()
                let noteCount = r < 0.20 ? 2 : (r < 0.80 ? 3 : Swift.min(4, allNotes.count))
                let spread = spreadNotesInverted(from: allNotes, count: noteCount, invOffset: invOffset)
                let vel = UInt8(Swift.max(40, Swift.min(95, baseVel + rng.nextInt(upperBound: 11) - 5)))
                // Plan F: 60% chance of arpeggiated harp-roll onset (low→mid→high, 1–2 steps apart)
                let doRoll  = rng.nextDouble() < 0.60
                let rollGap = doRoll ? (1 + rng.nextInt(upperBound: 2)) : 0
                for (ni, note) in spread.enumerated() {
                    let noteStep = step + (doRoll ? ni * rollGap : 0)
                    let dur = Swift.min(duration - (doRoll ? ni * rollGap : 0), loopSteps - noteStep)
                    if dur >= 4 && noteStep < loopSteps {
                        events.append(MIDIEvent(stepIndex: noteStep, note: note, velocity: vel, durationSteps: dur))
                    }
                }
                primarySteps.insert(step)
                invOffset = (invOffset + 1) % Swift.max(1, allNotes.count - 2)
            }
            step += reattack
        }

        // AMB-PAD-002: Secondary shimmer — only 40% chance; upper notes only, very soft
        if rng.nextDouble() < 0.40 {
            usedRuleIDs.insert("AMB-PADS-002")
            let offset  = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps behind primary
            let shimmer = Array(allNotes.suffix(2))          // upper two notes only
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
        // Avoids steps within ±8 of any primary chord attack to prevent crowded clusters.
        if rng.nextDouble() < 0.50 {
            usedRuleIDs.insert("AMB-PADS-006")
            let highNotes = notesInRegister(pitchClasses: chordPCs, low: 72, high: 100)
            if !highNotes.isEmpty {
                let bellCount = Swift.max(1, Int(Double(loopBars) * 0.07))
                var placed = 0
                var attempts = 0
                while placed < bellCount && attempts < bellCount * 10 {
                    attempts += 1
                    let s = rng.nextInt(upperBound: loopSteps)
                    // Skip if within 8 steps of any primary chord attack
                    let tooClose = primarySteps.contains(where: { abs($0 - s) < 8 })
                    guard !tooClose else { continue }
                    let note = highNotes[rng.nextInt(upperBound: highNotes.count)]
                    let vel  = UInt8(35 + rng.nextInt(upperBound: 21))  // 35–55
                    events.append(MIDIEvent(stepIndex: s, note: note, velocity: vel, durationSteps: 4))
                    placed += 1
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

    /// Returns `count` notes spread across `notes`, starting from `invOffset` for inversion rotation.
    private static func spreadNotesInverted(from notes: [UInt8], count: Int, invOffset: Int) -> [UInt8] {
        guard notes.count >= 2 else { return notes }
        let n = notes.count
        let start = invOffset % Swift.max(1, n - count + 1)
        // Pick evenly-spaced indices across the available range starting at `start`
        return (0..<Swift.min(count, n)).map { i in
            let idx = start + (i * (n - 1 - start)) / Swift.max(1, count - 1)
            return notes[Swift.min(idx, n - 1)]
        }
    }
}
