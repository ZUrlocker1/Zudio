// CosmicDrumGenerator.swift — Cosmic drum / percussion generation
// Implements COS-RULE-08 and COS-RULE-18 with all four percussionStyle options.
// COS-RULE-22: hi-hat velocity swing (ghost/accent alternation)
// COS-RULE-21: decomposed drum voice streams
// COS-DRUM-004: motorikGrid — full 16th-note grid (Electric Buddha Band: Time Loops, Dark Sun)

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

        case .motorikGrid:
            usedRuleIDs.insert("COS-DRUM-004")
            return generateMotoriKGrid(frame: frame, structure: structure, rng: &rng)

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

    // MARK: - Motorik Grid: full 16th-note hi-hat + kick/snare backbone (COS-DRUM-004)
    // Observed in Electric Buddha Band's Time Loops and Dark Sun.
    // Hi-hat: continuous 16th-note grid with ghost/accent swing (COS-RULE-22).
    // Kick: beats 1 and 3. Snare: beats 2 and 4.
    // Intro: skipped entirely. Outro: velocity fades over section.

    private static func generateMotoriKGrid(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro else { continue }

            let barStart = bar * 16

            let outroVelScale: Double
            if section.label == .outro {
                let sectionLen = max(1, section.endBar - section.startBar)
                let barInSec   = bar - section.startBar
                let progress   = Double(barInSec) / Double(sectionLen)
                outroVelScale  = max(0.25, 1.0 - progress * 0.75)
            } else {
                outroVelScale = 1.0
            }

            // Hi-hat: 16 16th-note steps per bar, ghost/accent swing (COS-RULE-22)
            for step in 0..<16 {
                // Accent on even 16ths within each beat (steps 0,2,4,6,8,10,12,14);
                // ghost on odd 16ths (steps 1,3,5,7,9,11,13,15)
                let isAccent = step % 2 == 0
                let baseVel: Double = isAccent
                    ? Double(75 + rng.nextInt(upperBound: 16))  // 75–90
                    : Double(18 + rng.nextInt(upperBound: 28))  // 18–45 ghost
                let vel = UInt8(max(12, Int(baseVel * outroVelScale)))
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                        velocity: vel, durationSteps: 1))
            }

            // Kick: steps 0 and 8 (beats 1 and 3)
            // Velocity kept below hi-hat accents (75–90) — kick grounds the groove
            // rather than dominating it in the Cosmic context.
            for beatStep in [0, 8] {
                // Outro: kick drops out in second half
                if section.label == .outro {
                    let progress = 1.0 - outroVelScale
                    guard progress < 0.5 else { continue }
                }
                let vel = UInt8(max(20, Int(Double(65 + rng.nextInt(upperBound: 11)) * outroVelScale)))
                events.append(MIDIEvent(stepIndex: barStart + beatStep, note: GMDrum.kick.rawValue,
                                        velocity: vel, durationSteps: 1))
            }

            // Snare: steps 4 and 12 (beats 2 and 4)
            // 20% chance of one-16th early syncopation per hit (COS-RULE-21)
            for beatStep in [4, 12] {
                if section.label == .outro {
                    let progress = 1.0 - outroVelScale
                    guard progress < 0.7 else { continue }
                }
                let offset = rng.nextDouble() < 0.20 ? -1 : 0
                let snareStep = max(0, barStart + beatStep + offset)
                let vel = UInt8(max(20, Int(Double(80 + rng.nextInt(upperBound: 16)) * outroVelScale)))
                events.append(MIDIEvent(stepIndex: snareStep, note: GMDrum.snare.rawValue,
                                        velocity: vel, durationSteps: 1))
            }
        }

        return events
    }
}
