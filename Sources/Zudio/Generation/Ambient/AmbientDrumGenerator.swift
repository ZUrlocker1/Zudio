// AmbientDrumGenerator.swift — Ambient percussion generation (stochastic, no tiling)
// AMB-DRUM-003 (60%): no percussion
// AMB-DRUM-001 (35%): sparse brush/ride hits, velocity 15–39
// AMB-DRUM-002 (5%): very soft kick on beat 1, brush on beat 3, velocity 20–39
// Generates for the full song (not a loop) — percussion drift is independent of pitch loops.

import Foundation

struct AmbientDrumGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        switch percussionStyle {
        case .absent:
            usedRuleIDs.insert("AMB-DRUM-003")
            return []
        case .textural:
            usedRuleIDs.insert("AMB-DRUM-001")
            return textural(frame: frame, structure: structure, rng: &rng)
        case .softPulse:
            usedRuleIDs.insert("AMB-DRUM-002")
            return softPulse(frame: frame, structure: structure, rng: &rng)
        default:
            return []
        }
    }

    // MARK: - Generators

    /// Sparse brush / ride sounds — ~25% chance per bar, random beat position.
    private static func textural(frame: GlobalMusicalFrame, structure: SongStructure,
                                  rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let colors: [GMDrum] = [.closedHat, .rideBell, .ride]
        for bar in 0..<frame.totalBars {
            guard structure.section(atBar: bar)?.label == .A else { continue }
            if rng.nextDouble() < 0.25 {
                let beat = rng.nextInt(upperBound: 4) * 4   // beat 0, 4, 8, or 12
                let vel  = UInt8(15 + rng.nextInt(upperBound: 25))  // 15–39
                let drum = colors[rng.nextInt(upperBound: colors.count)]
                events.append(MIDIEvent(stepIndex: bar * 16 + beat,
                                        note: drum.rawValue, velocity: vel, durationSteps: 1))
            }
        }
        return events
    }

    /// Very soft kick on beat 1 (~50%), brush hat on beat 3 (~30%).
    private static func softPulse(frame: GlobalMusicalFrame, structure: SongStructure,
                                   rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for bar in 0..<frame.totalBars {
            guard structure.section(atBar: bar)?.label == .A else { continue }
            if rng.nextDouble() < 0.50 {
                let vel = UInt8(20 + rng.nextInt(upperBound: 20))  // 20–39
                events.append(MIDIEvent(stepIndex: bar * 16,
                                        note: GMDrum.kick.rawValue, velocity: vel, durationSteps: 1))
            }
            if rng.nextDouble() < 0.30 {
                let vel = UInt8(12 + rng.nextInt(upperBound: 16))  // 12–27
                events.append(MIDIEvent(stepIndex: bar * 16 + 8,
                                        note: GMDrum.closedHat.rawValue, velocity: vel, durationSteps: 1))
            }
        }
        return events
    }
}
