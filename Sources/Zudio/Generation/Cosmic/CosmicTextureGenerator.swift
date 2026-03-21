// CosmicTextureGenerator.swift — Cosmic texture generation
// Implements COS-TEXT-001 through COS-TEXT-003
// COS-RULE-11: Bluebird/secondary arpeggio in MIDI 33–59, quarter-note durations
// Register separation from main arpeggio (55–72) is CRITICAL

import Foundation

struct CosmicTextureGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {

        let texRules:   [String] = ["COS-TEXT-001", "COS-TEXT-002", "COS-TEXT-003"]
        let texWeights: [Double] = [0.50,           0.30,           0.20]
        let primaryRule = texRules[rng.weightedPick(texWeights)]
        usedRuleIDs.insert(primaryRule)

        // Orbital motive loop length (different from arpeggio's pattern length)
        // Arpeggio uses 4 or 8 steps; texture uses 12 or 16 steps
        let texLoopLen = rng.nextDouble() < 0.5 ? 12 : 16

        var events: [MIDIEvent] = []

        for section in structure.sections {
            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16

                // Intro: shimmer appears in second half only — atmospheric build
                if section.label == .intro {
                    let midpoint = section.startBar + (section.endBar - section.startBar) / 2
                    guard bar >= midpoint && bar % 4 == 0 else { continue }
                    let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                    let note   = texRegisterNote(pc: rootPC, targetOct: 2)
                    events.append(MIDIEvent(stepIndex: barStart, note: UInt8(note),
                                            velocity: UInt8(50 + rng.nextInt(upperBound: 10)),
                                            durationSteps: 62))
                    continue
                }

                // Outro: shimmer in first half only, fades out
                if section.label == .outro {
                    let midpoint = section.startBar + (section.endBar - section.startBar) / 2
                    guard bar < midpoint && bar % 4 == 0 else { continue }
                    let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                    let note   = texRegisterNote(pc: rootPC, targetOct: 2)
                    events.append(MIDIEvent(stepIndex: barStart, note: UInt8(note),
                                            velocity: UInt8(25 + rng.nextInt(upperBound: 10)),
                                            durationSteps: 62))
                    continue
                }

                switch primaryRule {
                case "COS-TEXT-001":
                    events += orbitalMotiveBar(barStart: barStart, bar: bar, loopLen: texLoopLen,
                                               entry: entry, frame: frame, rng: &rng)
                case "COS-TEXT-002":
                    events += shimmerHoldBar(barStart: barStart, bar: bar, entry: entry, frame: frame, rng: &rng)
                case "COS-TEXT-003":
                    events += spatialSweepBar(barStart: barStart, bar: bar, entry: entry, frame: frame, rng: &rng)
                default:
                    events += orbitalMotiveBar(barStart: barStart, bar: bar, loopLen: texLoopLen,
                                               entry: entry, frame: frame, rng: &rng)
                }
            }
        }

        return events
    }

    // MARK: - COS-TEX-001: Orbital Motive
    // 3-note figure (root, 5th, octave) at different length than arpeggio.
    // Register: MIDI 33–59 (below arpeggio's 55–72) — COS-RULE-11

    private static func orbitalMotiveBar(
        barStart: Int, bar: Int, loopLen: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // Place in MIDI 33–55 register (COS-RULE-11: Bluebird register)
        let root   = texRegisterNote(pc: rootPC,         targetOct: 2)
        let fifth  = texRegisterNote(pc: (rootPC + 7) % 12, targetOct: 2)
        let octave = texRegisterNote(pc: rootPC,         targetOct: 3)
        let motif  = [root, fifth, octave]

        // Loop position based on bar and loopLen
        // loopLen is in steps (not bars); we pick which part of the loop falls in this bar
        let loopPosition = (bar * 16) % loopLen
        var evs: [MIDIEvent] = []

        // Quarter-note durations (COS-RULE-11): emit on beats, cycling through motif
        for beat in 0..<4 {
            let stepInLoop = (loopPosition + beat * 4) % motif.count
            let note = motif[stepInLoop % motif.count]
            let vel  = UInt8(45 + rng.nextInt(upperBound: 21))  // 45–65

            evs.append(MIDIEvent(stepIndex: barStart + beat * 4, note: UInt8(note),
                                 velocity: vel, durationSteps: 3))
        }
        return evs
    }

    // MARK: - COS-TEX-002: Shimmer Hold
    // Single note held very quietly (velocity 25–35) for 4+ bars

    private static func shimmerHoldBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Only attack every 4 bars
        guard bar % 4 == 0 else { return [] }

        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let note   = texRegisterNote(pc: rootPC, targetOct: 2)
        let vel    = UInt8(58 + rng.nextInt(upperBound: 13))  // 58–70

        // Hold for 4+ bars = 64+ steps; emit as a very long note
        return [MIDIEvent(stepIndex: barStart, note: UInt8(note), velocity: vel, durationSteps: 62)]
    }

    // MARK: - COS-TEX-003: Spatial Sweep
    // Chromatic passing notes (velocity 20) between scale tones, one per 4 bars

    private static func spatialSweepBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard bar % 4 == 0 else { return [] }

        let keyST  = keySemitone(frame.key)
        let mode   = entry.sectionMode

        // Pick two adjacent scale tones and place chromatic pass between them
        let intervals = mode.intervals
        let idx = rng.nextInt(upperBound: intervals.count - 1)
        let fromST = keyST + intervals[idx]
        let toST   = keyST + intervals[idx + 1]

        // Place chromatic pass in MIDI 33–59 register
        var fromMIDI = 36 + (fromST % 12)
        while fromMIDI < 33 { fromMIDI += 12 }
        while fromMIDI > 55 { fromMIDI -= 12 }

        var chromPass = fromMIDI + 1
        while chromPass < 33 { chromPass += 12 }
        while chromPass > 59 { chromPass -= 12 }

        var toMIDI = 36 + (toST % 12)
        while toMIDI < 33 { toMIDI += 12 }
        while toMIDI > 59 { toMIDI -= 12 }

        return [
            MIDIEvent(stepIndex: barStart,     note: UInt8(fromMIDI), velocity: 55, durationSteps: 4),
            MIDIEvent(stepIndex: barStart + 4, note: UInt8(chromPass), velocity: 55, durationSteps: 4),
            MIDIEvent(stepIndex: barStart + 8, note: UInt8(toMIDI),    velocity: 55, durationSteps: 4),
        ]
    }

    // MARK: - Register helper: place pitch class in texture register MIDI 33–59

    private static func texRegisterNote(pc: Int, targetOct: Int) -> Int {
        var midi = targetOct * 12 + pc
        while midi < 33 { midi += 12 }
        while midi > 59 { midi -= 12 }
        return midi
    }
}
