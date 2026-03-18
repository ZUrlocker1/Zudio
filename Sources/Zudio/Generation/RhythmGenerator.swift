// RhythmGenerator.swift — generation step 8
// Pulse embellishment: melodic ostinato that follows chord changes.
// Register: MIDI 45–76 (low-mid to mid).
//
// Rule catalog:
//   RHY-001: 8th-note stride — alternating root/fifth, active Motorik pulse
//   RHY-002: Quarter-note stride — root-anchored, open and spacious
//   RHY-003: Syncopated Motorik — hits at 0,3,6,8,11,14 (3+3+2+3+3+2 feel)
//
// Key improvement over v0: pitches update per chord window, pattern type is
// chosen per section, and intensity arc drives density within each section.

struct RhythmGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for section in structure.sections {
            // Rhythm is silent in intro/outro
            guard section.label != .intro && section.label != .outro else { continue }

            // Pick pattern type once per section
            let patternType = rng.nextInt(upperBound: 3) // 0=8th, 1=quarter, 2=syncopated
            switch patternType {
            case 0:  usedRuleIDs.insert("RHY-001")
            case 1:  usedRuleIDs.insert("RHY-002")
            default: usedRuleIDs.insert("RHY-003")
            }

            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }

                // Intensity arc: drives how many steps actually fire
                let intensity = section.subPhaseIntensity(atBar: bar)
                let density: Double
                switch intensity {
                case .low:    density = 0.55
                case .medium: density = 0.80
                case .high:   density = 1.00
                }

                let barStart = bar * 16
                let pitches  = chordPitches(entry: entry, frame: frame)

                switch patternType {
                case 0:
                    // RHY-001: 8th-note pulse, root on downbeats, fifth on off-beats
                    for step in Swift.stride(from: 0, to: 16, by: 2) {
                        guard rng.nextDouble() < density else { continue }
                        let note: UInt8 = (step % 4 == 0) ? pitches.root : pitches.fifth
                        let vel  = UInt8(step == 0 ? 82 : 62 + rng.nextInt(upperBound: 14))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 2))
                    }
                case 1:
                    // RHY-002: quarter-note, root on 1+3, fifth on 2+4
                    for (i, step) in [0, 4, 8, 12].enumerated() {
                        guard rng.nextDouble() < density else { continue }
                        let note: UInt8 = (i % 2 == 0) ? pitches.root : pitches.fifth
                        let vel  = UInt8(step == 0 ? 86 : 65 + rng.nextInt(upperBound: 12))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 3))
                    }
                default:
                    // RHY-003: syncopated Motorik — 3+3+2+3+3+2 pattern
                    for (i, step) in [0, 3, 6, 8, 11, 14].enumerated() {
                        guard rng.nextDouble() < density else { continue }
                        let note: UInt8 = (i % 2 == 0) ? pitches.root : pitches.fifth
                        let vel  = UInt8(step == 0 ? 84 : 63 + rng.nextInt(upperBound: 16))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 2))
                    }
                }
            }
        }

        return events
    }

    // MARK: - Pitch helpers

    private struct ChordPitches {
        let root: UInt8
        let fifth: UInt8
    }

    /// Derives the root and fifth MIDI notes for the current chord window.
    private static func chordPitches(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> ChordPitches {
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        return ChordPitches(
            root:  noteInRange(pc: rootPC,  low: 45, high: 72),
            fifth: noteInRange(pc: fifthPC, low: 48, high: 76)
        )
    }

    private static func noteInRange(pc: Int, low: Int, high: Int) -> UInt8 {
        for oct in 2...7 {
            let midi = oct * 12 + pc
            if midi >= low && midi <= high { return UInt8(midi) }
        }
        return UInt8(low)
    }
}
