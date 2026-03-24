// AmbientBassGenerator.swift — Ambient bass generation
// AMB-BASS-001: Root-held drone — long holds using the active chord root, with silences.
// AMB-BASS-002: Bass absent (30% chance).
// AMB-BASS-003: Root+fifth drone — holds alternate root / fifth; occasional major third (10%).
// Chord-following: iterates every chord window in the TonalGovernanceMap so bass pitch tracks
// harmonic changes (b7, b6, etc.) throughout the song. No loop tiling — full-song events.

import Foundation

struct AmbientBassGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {
        // 30% absent (suppressable by forcing a specific rule)
        if forceRuleID == nil && rng.nextDouble() < 0.30 {
            usedRuleIDs.insert("AMB-BASS-002")
            return []
        }

        // Choose bass rule: AMB-BASS-001 (root only) or AMB-BASS-003 (root+fifth)
        let ruleID       = forceRuleID ?? (rng.nextDouble() < 0.50 ? "AMB-BASS-003" : "AMB-BASS-001")
        let useRootFifth = ruleID == "AMB-BASS-003"
        usedRuleIDs.insert(ruleID)

        let bounds = kRegisterBounds[kTrackBass]!   // low:40, high:64
        var events: [MIDIEvent] = []

        for entry in tonalMap {
            let cw        = entry.chordWindow
            let startStep = cw.startBar * 16
            let endStep   = cw.endBar   * 16

            let rootPC   = (frame.keySemitoneValue + degreeSemitone(cw.chordRoot)) % 12
            let rootNote = closestNote(pitchClass: rootPC, near: 47, low: bounds.low, high: bounds.high)

            var holdIndex = 0
            var cursor    = startStep
            while cursor < endStep {
                let hold   = 32 + rng.nextInt(upperBound: 33)   // 32–64 steps
                let silent = 16 + rng.nextInt(upperBound: 17)   // 16–32 steps
                let dur    = Swift.min(hold, endStep - cursor)
                if dur >= 4 {
                    let vel = UInt8(55 + rng.nextInt(upperBound: 11))  // 55–65

                    let noteToPlay: Int
                    if useRootFifth && holdIndex % 2 == 1 {
                        // Odd holds: fifth, with 10% chance of major third instead
                        if rng.nextDouble() < 0.10 {
                            let thirdPC = (rootPC + 4) % 12
                            noteToPlay  = closestNote(pitchClass: thirdPC, near: rootNote,
                                                      low: bounds.low, high: bounds.high)
                        } else {
                            let fifthPC = (rootPC + 7) % 12
                            noteToPlay  = closestNote(pitchClass: fifthPC, near: rootNote,
                                                      low: bounds.low, high: bounds.high)
                        }
                    } else {
                        noteToPlay = rootNote
                    }

                    events.append(MIDIEvent(stepIndex: cursor, note: UInt8(noteToPlay),
                                            velocity: vel, durationSteps: dur))
                    holdIndex += 1
                }
                cursor += hold + silent
            }
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
