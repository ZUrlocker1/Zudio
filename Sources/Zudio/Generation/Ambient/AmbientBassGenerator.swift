// AmbientBassGenerator.swift — Ambient bass generation
// AMB-BASS-001: Root-held drone, 32–64 steps per note, velocity 55–65, register 40–64.
// 30% chance bass is absent entirely (AMB-BASS-002).
// AMB-SYNC-002/009: root matches chord plan at bar 0 (loop is based on opening chord).
// Generates a short loop; AmbientLoopTiler tiles to full song length.

import Foundation

struct AmbientBassGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        // 30% absent
        if rng.nextDouble() < 0.30 {
            usedRuleIDs.insert("AMB-BASS-002")
            return []
        }

        guard let entry = tonalMap.entry(atBar: 0) else { return [] }
        usedRuleIDs.insert("AMB-BASS-001")

        let bounds    = kRegisterBounds[kTrackBass]!   // low:40, high:64
        let loopSteps = loopBars * 16

        // Root pitch class → MIDI note near middle of bass register
        let rootPC   = (frame.keySemitoneValue + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let rootNote = closestNote(pitchClass: rootPC, near: 47, low: bounds.low, high: bounds.high)

        var events: [MIDIEvent] = []
        var cursor = 0
        while cursor < loopSteps {
            let hold   = 32 + rng.nextInt(upperBound: 33)   // 32–64 steps
            let silent = 16 + rng.nextInt(upperBound: 17)   // 16–32 steps
            let dur    = Swift.min(hold, loopSteps - cursor)
            if dur >= 4 {
                let vel = UInt8(55 + rng.nextInt(upperBound: 11))  // 55–65
                events.append(MIDIEvent(stepIndex: cursor, note: UInt8(rootNote),
                                        velocity: vel, durationSteps: dur))
            }
            cursor += hold + silent
        }
        return events
    }

    // MARK: - Helper

    private static func closestNote(pitchClass: Int, near target: Int, low: Int, high: Int) -> Int {
        var best = low; var bestDist = Int.max
        for oct in -1...9 {
            let note = pitchClass + oct * 12
            if note >= low && note <= high {
                let dist = abs(target - note)
                if dist < bestDist { best = note; bestDist = dist }
            }
        }
        return best
    }
}
