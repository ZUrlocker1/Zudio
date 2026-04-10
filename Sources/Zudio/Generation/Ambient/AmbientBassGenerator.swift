// AmbientBassGenerator.swift — Ambient bass generation
// AMB-BASS-001: Root-held drone — long holds using the active chord root, with silences.
// AMB-BASS-002: Bass absent (30% chance).
// AMB-BASS-003: Root+fifth drone — holds alternate root / fifth; occasional major third (10%).
//
// Rhythm template + chord-following pitch resolution:
//   A hold/silence template is pre-computed for one loop cycle (loopBars long) using rng.
//   That template is then tiled across the full song length. At each note position the pitch
//   is resolved from the TonalGovernanceMap at that moment, so chord/root changes still track
//   section boundaries while the rhythmic pattern repeats independently at its own loop length.

import Foundation

struct AmbientBassGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        loopBars: Int,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil,
        silentBars: Set<Int> = []
    ) -> [MIDIEvent] {
        // 30% absent (suppressable by forcing a specific rule)
        if forceRuleID == nil && rng.nextDouble() < 0.30 {
            usedRuleIDs.insert("AMB-BASS-002")
            return []
        }

        let ruleID       = forceRuleID ?? (rng.nextDouble() < 0.50 ? "AMB-BASS-003" : "AMB-BASS-001")
        let useRootFifth = ruleID == "AMB-BASS-003"
        usedRuleIDs.insert(ruleID)

        let bounds     = kRegisterBounds[kTrackBass]!   // low:40, high:64
        let loopSteps  = loopBars * 16
        let totalSteps = frame.totalBars * 16

        // Pre-compute one loop's worth of hold/silence pairs.
        // These govern attack timing and silence gaps only — pitch is resolved later.
        struct HoldSlot { let hold: Int; let silent: Int }
        var template: [HoldSlot] = []
        var tCursor = 0
        while tCursor < loopSteps {
            let hold   = 32 + rng.nextInt(upperBound: 33)   // 32–64 steps
            let silent = 24 + rng.nextInt(upperBound: 25)   // 24–48 steps — wider gap for breathing room
            template.append(HoldSlot(hold: hold, silent: silent))
            tCursor += hold + silent
        }
        guard !template.isEmpty else { return [] }

        // Tile the template across the full song, resolving pitch from the tonal map at each step.
        var events:    [MIDIEvent] = []
        var cursor     = 0
        var slotIdx    = 0
        var holdIndex  = 0   // tracks root/fifth alternation for AMB-BASS-003

        while cursor < totalSteps {
            let slot = template[slotIdx % template.count]
            let dur  = Swift.min(slot.hold, totalSteps - cursor)

            let currentBar = cursor / 16
            if dur >= 4, !silentBars.contains(currentBar), let entry = tonalMap.entry(atBar: currentBar) {
                let cw       = entry.chordWindow
                let rootPC   = (frame.keySemitoneValue + degreeSemitone(cw.chordRoot)) % 12
                let rootNote = closestNote(pitchClass: rootPC, near: 47, low: bounds.low, high: bounds.high)
                let vel      = UInt8(55 + rng.nextInt(upperBound: 11))   // 55–65

                let noteToPlay: Int
                if useRootFifth && holdIndex % 2 == 1 {
                    // Odd holds: fifth, with 10% chance of third instead.
                    // Use minor third for minor modes to avoid chromatic clashes.
                    if rng.nextDouble() < 0.10 {
                        let minorModes: Set<Mode> = [.Aeolian, .Dorian, .MinorPentatonic]
                        let thirdInterval = minorModes.contains(frame.mode) ? 3 : 4
                        let thirdPC  = (rootPC + thirdInterval) % 12
                        noteToPlay   = closestNote(pitchClass: thirdPC, near: rootNote,
                                                   low: bounds.low, high: bounds.high)
                    } else {
                        let fifthPC = (rootPC + 7) % 12
                        noteToPlay  = closestNote(pitchClass: fifthPC, near: rootNote,
                                                  low: bounds.low, high: bounds.high)
                    }
                } else {
                    noteToPlay = rootNote
                }

                // Plan L: 20% chance of neighbour-tone inflection for AMB-BASS-001 root holds.
                // Splits hold: root (60%) → scale neighbour (25%) → root (15%).
                var didNeighbour = false
                if !useRootFifth && noteToPlay == rootNote && dur >= 12 && rng.nextDouble() < 0.20 {
                    let scalePCs   = frame.scalePCs
                    let scaleNotes = (bounds.low...bounds.high).filter { scalePCs.contains($0 % 12) }
                    if let rootIdx = scaleNotes.firstIndex(of: rootNote) {
                        let neighbour: Int? = rootIdx > 0 && rootIdx < scaleNotes.count - 1
                            ? (rng.nextDouble() < 0.5 ? scaleNotes[rootIdx - 1] : scaleNotes[rootIdx + 1])
                            : rootIdx > 0 ? scaleNotes[rootIdx - 1]
                            : rootIdx < scaleNotes.count - 1 ? scaleNotes[rootIdx + 1] : nil
                        if let neigh = neighbour {
                            let rootPart  = Int(Double(dur) * 0.60)
                            let neighPart = Int(Double(dur) * 0.25)
                            let retPart   = dur - rootPart - neighPart
                            let neighVel  = UInt8(Swift.max(20, Int(vel) - 10))
                            events.append(MIDIEvent(stepIndex: cursor, note: UInt8(rootNote),
                                                    velocity: vel, durationSteps: rootPart))
                            events.append(MIDIEvent(stepIndex: cursor + rootPart, note: UInt8(neigh),
                                                    velocity: neighVel, durationSteps: neighPart))
                            if retPart >= 4 {
                                events.append(MIDIEvent(stepIndex: cursor + rootPart + neighPart,
                                                        note: UInt8(rootNote), velocity: vel,
                                                        durationSteps: retPart))
                            }
                            didNeighbour = true
                        }
                    }
                }
                if !didNeighbour {
                    events.append(MIDIEvent(stepIndex: cursor, note: UInt8(noteToPlay),
                                            velocity: vel, durationSteps: dur))
                }
                holdIndex += 1
            }

            cursor  += slot.hold + slot.silent
            slotIdx += 1
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
