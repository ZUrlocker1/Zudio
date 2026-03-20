// CosmicDrumGenerator.swift — Cosmic drum / percussion generation
// Implements COS-RULE-08 and COS-RULE-18 with all three percussionStyle options.
// COS-RULE-22: hi-hat velocity swing (ghost/accent alternation)
// COS-RULE-21: decomposed drum voice streams

import Foundation

struct CosmicDrumGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {

        switch percussionStyle {
        case .absent:
            usedRuleIDs.insert("COS-DRUM-003")
            return []

        case .sparse:
            usedRuleIDs.insert("COS-DRUM-002")
            return generateSparse(frame: frame, structure: structure, rng: &rng)

        case .minimal:
            usedRuleIDs.insert("COS-DRUM-001")
            return generateMinimal(frame: frame, structure: structure, rng: &rng)

        default:
            usedRuleIDs.insert("COS-DRUM-003")
            return []
        }
    }

    // MARK: - Sparse: pitched percussion on root and fifth (COS-RULE-08)
    // One event every 4–8 beats. Use pitched drum notes (low tom, floor tom).

    private static func generateSparse(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Sparse interval: one event every 4–8 beats = every 16–32 steps
        var nextEventStep = 0

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro else { continue }

            let barStart = bar * 16

            for step in 0..<16 {
                let absStep = barStart + step
                guard absStep >= nextEventStep else { continue }

                // Root hit (MIDI 41 = low floor tom) or fifth hit (MIDI 43 = high floor tom)
                // These are pitched at approximately the right feel (COS-RULE-08)
                let useRoot = rng.nextDouble() < 0.60
                let note: UInt8 = useRoot ? GMDrum.lowFloorTom.rawValue : GMDrum.highFloorTom.rawValue
                var vel = 40 + rng.nextInt(upperBound: 26)  // 40–65
                // Outro: fade velocity
                if section.label == .outro {
                    let sectionLen = max(1, section.endBar - section.startBar)
                    let barInSec   = bar - section.startBar
                    let progress   = Double(barInSec) / Double(sectionLen)
                    vel = max(20, Int(Double(vel) * (1.0 - progress * 0.70)))
                }
                events.append(MIDIEvent(stepIndex: absStep, note: note, velocity: UInt8(vel), durationSteps: 1))

                // Schedule next event 4–8 beats (16–32 steps) later
                nextEventStep = absStep + 16 + rng.nextInt(upperBound: 17)
            }
        }

        return events
    }

    // MARK: - Minimal: JMJ Mini Pops style
    // Kick beat 1 every other bar + hi-hat quarter-note pulse (COS-RULE-22 swing)

    private static func generateMinimal(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro else { continue }

            let barStart = bar * 16

            // Outro: velocity decays over section (kick drops out in second half)
            let outroVelScale: Double
            if section.label == .outro {
                let sectionLen  = max(1, section.endBar - section.startBar)
                let barInSec    = bar - section.startBar
                let progress    = Double(barInSec) / Double(sectionLen)
                outroVelScale   = max(0.28, 1.0 - progress * 0.72)
                // Kick: only first half of outro
                if bar % 2 == 0 && progress < 0.5 {
                    let vel = UInt8(max(20, Int(Double(55 + rng.nextInt(upperBound: 15)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.kick.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            } else {
                outroVelScale = 1.0
                // Kick: beat 1 only, every other bar (very sparse)
                if bar % 2 == 0 {
                    events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.kick.rawValue,
                                            velocity: UInt8(55 + rng.nextInt(upperBound: 15)),
                                            durationSteps: 1))
                }
            }

            // Hi-hat: quarter-note pulse with ghost/accent swing (COS-RULE-22)
            for beat in 0..<4 {
                let beatStep = barStart + beat * 4
                let isAccent = beat % 2 == 0  // accent on beats 1 and 3
                let baseVel: Double = isAccent
                    ? Double(75 + rng.nextInt(upperBound: 21))
                    : Double(35 + rng.nextInt(upperBound: 21))
                let vel = UInt8(max(18, Int(baseVel * outroVelScale)))
                events.append(MIDIEvent(stepIndex: beatStep, note: GMDrum.closedHat.rawValue,
                                        velocity: vel, durationSteps: 1))
            }
        }

        return events
    }
}
