// AmbientBassGenerator.swift — Ambient bass generation
// Copyright (c) 2026 Zack Urlocker
// AMB-BASS-001: Root-held drone — long holds using the active chord root, with silences.
// AMB-BASS-002: Bass absent (30% chance).
// AMB-BASS-003: Root+fifth drone — holds alternate root / fifth; occasional major third (10%).
// AMB-BASS-004: ECM pluck — short staccato plucks (6–10 steps) spaced 3–5 bars apart,
//               walking stepwise through scale tones. Eberhard Weber / ECM records feel.
// AMB-BASS-005: Octave double — root note at two octaves simultaneously; long holds.
//               Thick organ-pipe quality. Harold Budd / Eno Ambient 2 feel.
// AMB-BASS-006: Slow pendulum — alternates root with b7 (minor modes) or 4th (major),
//               each held 3–5 bars. Deep, slow harmonic rocking motion.
//
// Rule weights: absent 30%; remaining 70% split equally across 5 active rules (14% each).
// Rhythm template + chord-following pitch resolution (001/003):
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

        let activeRules = ["AMB-BASS-001", "AMB-BASS-003", "AMB-BASS-004", "AMB-BASS-005", "AMB-BASS-006"]
        let ruleID      = forceRuleID ?? activeRules[rng.nextInt(upperBound: activeRules.count)]
        usedRuleIDs.insert(ruleID)

        let bounds     = kRegisterBounds[kTrackBass]!   // low:40, high:64
        let totalSteps = frame.totalBars * 16
        let scaleNotes = (bounds.low...bounds.high).filter { frame.scalePCs.contains($0 % 12) }

        switch ruleID {
        case "AMB-BASS-004":
            return ecmPluckWalk(frame: frame, rng: &rng, scaleNotes: scaleNotes,
                                totalSteps: totalSteps, silentBars: silentBars)
        case "AMB-BASS-005":
            return octaveDouble(frame: frame, tonalMap: tonalMap, rng: &rng,
                                low: bounds.low, high: bounds.high,
                                totalSteps: totalSteps, silentBars: silentBars)
        case "AMB-BASS-006":
            return slowPendulum(frame: frame, tonalMap: tonalMap, rng: &rng,
                                low: bounds.low, high: bounds.high,
                                totalSteps: totalSteps, silentBars: silentBars)
        default:
            break  // AMB-BASS-001 and AMB-BASS-003: template-based drone below
        }

        // MARK: AMB-BASS-001 / AMB-BASS-003: long drone template
        let useRootFifth = ruleID == "AMB-BASS-003"
        let loopSteps    = loopBars * 16

        // Pre-compute one loop's worth of hold/silence pairs.
        // These govern attack timing and silence gaps only — pitch is resolved later.
        struct HoldSlot { let hold: Int; let silent: Int }
        var template: [HoldSlot] = []
        var tCursor = 0
        while tCursor < loopSteps {
            let hold   = 32 + rng.nextInt(upperBound: 33)   // 32–64 steps
            let silent = 24 + rng.nextInt(upperBound: 25)   // 24–48 steps
            template.append(HoldSlot(hold: hold, silent: silent))
            tCursor += hold + silent
        }
        guard !template.isEmpty else { return [] }

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
                var didNeighbour = false
                if !useRootFifth && noteToPlay == rootNote && dur >= 12 && rng.nextDouble() < 0.20 {
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

    // MARK: - AMB-BASS-004: ECM Pluck Walk

    /// Short staccato plucks (6–10 steps) spaced 3–5 bars apart, each at a different
    /// scale tone walking stepwise up or down through the bass register.
    private static func ecmPluckWalk(
        frame: GlobalMusicalFrame,
        rng: inout SeededRNG,
        scaleNotes: [Int],
        totalSteps: Int,
        silentBars: Set<Int>
    ) -> [MIDIEvent] {
        guard !scaleNotes.isEmpty else { return [] }
        var events: [MIDIEvent] = []

        // Start in the lower third of the scale range
        var walkIdx = rng.nextInt(upperBound: Swift.max(1, scaleNotes.count / 3))
        var cursor  = rng.nextInt(upperBound: 16)  // slight rhythmic offset within bar 0

        while cursor < totalSteps {
            let currentBar = cursor / 16
            if silentBars.contains(currentBar) { cursor += 16; continue }

            let note    = scaleNotes[walkIdx]
            let dur     = 6 + rng.nextInt(upperBound: 5)           // 6–10 steps
            let safeDur = Swift.min(dur, totalSteps - cursor)
            if safeDur >= 4 {
                let vel = UInt8(40 + rng.nextInt(upperBound: 16))  // 40–55
                events.append(MIDIEvent(stepIndex: cursor, note: UInt8(note),
                                        velocity: vel, durationSteps: safeDur))
            }

            // Stepwise walk: ±1 position (75%) or ±2 (25%), slight upward bias
            let step = rng.nextDouble() < 0.75 ? 1 : 2
            let dir  = rng.nextDouble() < 0.55 ? 1 : -1
            let next = walkIdx + dir * step
            if next >= 0 && next < scaleNotes.count {
                walkIdx = next
            } else {
                // Hit boundary — reverse
                walkIdx = Swift.max(0, Swift.min(scaleNotes.count - 1, walkIdx - dir * step))
            }

            // Long silence: 48–80 steps (3–5 bars)
            let silent = 48 + rng.nextInt(upperBound: 33)
            cursor += safeDur + silent
        }
        return events
    }

    // MARK: - AMB-BASS-005: Octave Double

    /// Root note sounded at two octaves simultaneously. Long holds (32–64 steps),
    /// long silences (24–48 steps). Thick organ-pipe quality.
    private static func octaveDouble(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        low: Int, high: Int,
        totalSteps: Int,
        silentBars: Set<Int>
    ) -> [MIDIEvent] {
        let bounds = (low: low, high: high)
        var events: [MIDIEvent] = []
        var cursor = 0

        while cursor < totalSteps {
            let hold   = 32 + rng.nextInt(upperBound: 33)  // 32–64 steps
            let silent = 24 + rng.nextInt(upperBound: 25)  // 24–48 steps
            let dur    = Swift.min(hold, totalSteps - cursor)

            let currentBar = cursor / 16
            if dur >= 4, !silentBars.contains(currentBar), let entry = tonalMap.entry(atBar: currentBar) {
                let cw     = entry.chordWindow
                let rootPC = (frame.keySemitoneValue + degreeSemitone(cw.chordRoot)) % 12
                // Lower root capped at bounds.high - 12 so the octave stays within register
                let lo     = closestNote(pitchClass: rootPC, near: 43,
                                         low: bounds.low, high: bounds.high - 12)
                let hi     = lo + 12
                let velLo  = UInt8(38 + rng.nextInt(upperBound: 10))  // 38–47
                let velHi  = UInt8(28 + rng.nextInt(upperBound: 8))   // 28–35, softer upper voice
                events.append(MIDIEvent(stepIndex: cursor, note: UInt8(lo),
                                        velocity: velLo, durationSteps: dur))
                events.append(MIDIEvent(stepIndex: cursor, note: UInt8(hi),
                                        velocity: velHi, durationSteps: dur))
            }

            cursor += hold + silent
        }
        return events
    }

    // MARK: - AMB-BASS-006: Slow Pendulum

    /// Alternates root with b7 (minor modes) or perfect 4th (major/Mixolydian),
    /// each position held 3–5 bars (48–80 steps). Deep, slow harmonic rocking motion.
    private static func slowPendulum(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        low: Int, high: Int,
        totalSteps: Int,
        silentBars: Set<Int>
    ) -> [MIDIEvent] {
        let bounds = (low: low, high: high)
        var events:   [MIDIEvent] = []
        var cursor    = 0
        var position  = 0  // 0 = root, 1 = second note

        // b7 for minor modes, perfect 4th for major/Mixolydian
        let minorModes: Set<Mode> = [.Aeolian, .Dorian, .MinorPentatonic]
        let secondInterval = minorModes.contains(frame.mode) ? 10 : 5

        while cursor < totalSteps {
            let hold   = 48 + rng.nextInt(upperBound: 33)  // 48–80 steps (3–5 bars)
            let silent = 4  + rng.nextInt(upperBound: 9)   // 4–12 steps (short articulation gap)
            let dur    = Swift.min(hold, totalSteps - cursor)

            let currentBar = cursor / 16
            if dur >= 4, !silentBars.contains(currentBar), let entry = tonalMap.entry(atBar: currentBar) {
                let cw       = entry.chordWindow
                let rootPC   = (frame.keySemitoneValue + degreeSemitone(cw.chordRoot)) % 12
                let rootNote = closestNote(pitchClass: rootPC, near: 47, low: bounds.low, high: bounds.high)

                let noteToPlay: Int
                if position == 1 {
                    let secondPC = (rootPC + secondInterval) % 12
                    noteToPlay = closestNote(pitchClass: secondPC, near: rootNote,
                                            low: bounds.low, high: bounds.high)
                } else {
                    noteToPlay = rootNote
                }

                let vel = UInt8(52 + rng.nextInt(upperBound: 14))  // 52–65
                events.append(MIDIEvent(stepIndex: cursor, note: UInt8(noteToPlay),
                                        velocity: vel, durationSteps: dur))
            }

            cursor   += hold + silent
            position  = 1 - position  // alternate root ↔ second note
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
