// CosmicPadsGenerator.swift — Cosmic pads generation
// Implements COS-PAD-001 through COS-PAD-005 and COS-RULE-07 (Wurlitzer), COS-RULE-16 (shimmer)
// Register: MIDI 36–72 (lower than Motorik pads at 48–84 — creates depth below arpeggio)

import Foundation

struct CosmicPadsGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        cosmicProgFamily: CosmicProgressionFamily,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {

        // Pick primary pad rule
        let padRules:   [String] = ["COS-PADS-001", "COS-PADS-002", "COS-PADS-003", "COS-PADS-004", "COS-PADS-005"]
        let padWeights: [Double] = [0.30,           0.20,          0.20,           0.15,           0.15]

        // quartal_stack forces COS-PAD-005
        let primaryRule: String
        if cosmicProgFamily == .quartal_stack {
            primaryRule = "COS-PADS-005"
        } else if cosmicProgFamily == .suspended_resolution {
            primaryRule = "COS-PADS-004"
        } else {
            primaryRule = padRules[rng.weightedPick(padWeights)]
        }
        usedRuleIDs.insert(primaryRule)
        usedRuleIDs.insert("COS-PADS-006")  // shimmer always present

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard let entry = tonalMap.entry(atBar: bar) else { continue }
            let barStart = bar * 16

            // Intro: single continuous root+fifth note spanning entire section.
            // Volume fade-in (0 → 1) handled by PlaybackEngine boost ramp.
            if section.label == .intro {
                guard bar == section.startBar else { continue }
                let dur    = max(1, (section.endBar - section.startBar) * 16 - 1)
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
                let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
                events += [
                    MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 50, durationSteps: dur),
                    MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 44, durationSteps: dur),
                ]
                continue
            }

            // Outro: single continuous root+fifth note spanning entire section.
            // Volume fade-out (1 → 0) handled by PlaybackEngine boost ramp.
            if section.label == .outro {
                guard bar == section.startBar else { continue }
                let dur    = max(1, (section.endBar - section.startBar) * 16 - 1)
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
                let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
                events += [
                    MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 50, durationSteps: dur),
                    MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 44, durationSteps: dur),
                ]
                continue
            }

            switch primaryRule {
            case "COS-PADS-001":
                events += longDroneBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
            case "COS-PADS-002":
                events += swellChordBar(barStart: barStart, entry: entry, frame: frame, rng: &rng)
            case "COS-PADS-003":
                events += unsyncLayersBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
            case "COS-PADS-004":
                events += suspendedResolutionBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
            case "COS-PADS-005":
                events += quartalStackBar(barStart: barStart, entry: entry, frame: frame)
            default:
                events += longDroneBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
            }

            // COS-RULE-07: Wurlitzer chord track — bIII voicing, velocity ramp
            if rng.nextDouble() < 0.55 {
                events += wurlitzerChordBar(barStart: barStart, entry: entry, frame: frame)
            }

            // COS-RULE-16: Shimmer layer — high register, velocity ramp
            if rng.nextDouble() < 0.45 {
                events += shimmerLayerBar(barStart: barStart, entry: entry, frame: frame, rng: &rng)
            }
        }

        return events
    }

    // MARK: - COS-PAD-001: Long Drone
    // Whole notes held 2–4 bars (but we emit per bar with overlap),
    // voicing: root+5th+octave+(3rd at octave up), velocity 40–55

    private static func longDroneBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        // Only re-attack every 2 bars to simulate held notes
        guard bar % 2 == 0 else { return [] }

        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let root    = noteInPadsRegister(pc: rootPC, targetOct: 2)
        let fifth   = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
        let octave  = noteInPadsRegister(pc: rootPC, targetOct: 3)
        let mode = frame.mode
        let thirdInterval = mode.nearestInterval(4)  // major or minor 3rd
        let thirdHigh = noteInPadsRegister(pc: (rootPC + thirdInterval) % 12, targetOct: 3)

        // Hold for 32 steps (2 bars) — slightly less than 32 for visual gap
        let dur = 30
        let vel = UInt8(50 + Int.random(in: 0...10))

        return [
            MIDIEvent(stepIndex: barStart, note: UInt8(root),      velocity: vel,       durationSteps: dur),
            MIDIEvent(stepIndex: barStart, note: UInt8(fifth),     velocity: vel - 5,   durationSteps: dur),
            MIDIEvent(stepIndex: barStart, note: UInt8(octave),    velocity: vel - 3,   durationSteps: dur),
            MIDIEvent(stepIndex: barStart, note: UInt8(thirdHigh), velocity: vel - 8,   durationSteps: dur),
        ]
    }

    // MARK: - COS-PAD-002: Swell Chord
    // Velocity ramps 20→80 over the bar (Vangelis brass swell)

    private static func swellChordBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
        let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)

        // Simulate velocity ramp with sub-events at different velocities
        // Attack at 20, mid at 50, sustain at 75
        return [
            MIDIEvent(stepIndex: barStart,      note: UInt8(root),  velocity: 35, durationSteps: 6),
            MIDIEvent(stepIndex: barStart + 4,  note: UInt8(root),  velocity: 55, durationSteps: 6),
            MIDIEvent(stepIndex: barStart + 8,  note: UInt8(root),  velocity: 70, durationSteps: 8),
            MIDIEvent(stepIndex: barStart,      note: UInt8(fifth), velocity: 30, durationSteps: 6),
            MIDIEvent(stepIndex: barStart + 4,  note: UInt8(fifth), velocity: 45, durationSteps: 6),
            MIDIEvent(stepIndex: barStart + 8,  note: UInt8(fifth), velocity: 60, durationSteps: 8),
        ]
    }

    // MARK: - COS-PAD-003: Unsync Layers
    // Three voices at 8, 10, 12 bar loop lengths (Roach-style unsync)

    private static func unsyncLayersBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var evs: [MIDIEvent] = []
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // Voice 1: 8-bar loop — root voicing
        if bar % 8 == 0 {
            let root = noteInPadsRegister(pc: rootPC, targetOct: 2)
            let fifth = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
            evs += [
                MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 50, durationSteps: 14 * 8),
                MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 45, durationSteps: 14 * 8),
            ]
        }

        // Voice 2: 10-bar loop — different voicing
        if bar % 10 == 0 {
            let oct = noteInPadsRegister(pc: rootPC, targetOct: 3)
            let mode = frame.mode
            let thirdHigh = noteInPadsRegister(pc: (rootPC + mode.nearestInterval(4)) % 12, targetOct: 3)
            evs += [
                MIDIEvent(stepIndex: barStart, note: UInt8(oct),      velocity: 45, durationSteps: 14 * 10),
                MIDIEvent(stepIndex: barStart, note: UInt8(thirdHigh), velocity: 42, durationSteps: 14 * 10),
            ]
        }

        // Voice 3: 12-bar loop — inversion
        if bar % 12 == 0 {
            let rootHigh = noteInPadsRegister(pc: rootPC, targetOct: 3)
            evs.append(MIDIEvent(stepIndex: barStart, note: UInt8(rootHigh), velocity: 42, durationSteps: 14 * 12))
        }

        return evs
    }

    // MARK: - COS-PAD-004: Suspended Resolution
    // sus4 for 3 bars, minor for 1 bar (per 4-bar cycle)

    private static func suspendedResolutionBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
        let cycle  = bar % 4

        if cycle < 3 {
            // sus4: root + fourth + fifth
            let fourth = noteInPadsRegister(pc: (rootPC + 5) % 12, targetOct: 2)
            let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
            return [
                MIDIEvent(stepIndex: barStart, note: UInt8(root),   velocity: 50, durationSteps: 14),
                MIDIEvent(stepIndex: barStart, note: UInt8(fourth),  velocity: 45, durationSteps: 14),
                MIDIEvent(stepIndex: barStart, note: UInt8(fifth),   velocity: 48, durationSteps: 14),
            ]
        } else {
            // minor resolution: root + minor third + fifth
            let mode = frame.mode
            let minor3rd = noteInPadsRegister(pc: (rootPC + mode.nearestInterval(3)) % 12, targetOct: 2)
            let fifth    = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
            return [
                MIDIEvent(stepIndex: barStart, note: UInt8(root),     velocity: 55, durationSteps: 14),
                MIDIEvent(stepIndex: barStart, note: UInt8(minor3rd), velocity: 50, durationSteps: 14),
                MIDIEvent(stepIndex: barStart, note: UInt8(fifth),    velocity: 52, durationSteps: 14),
            ]
        }
    }

    // MARK: - COS-PAD-005: Quartal Stack
    // Stacked fourths: 0, 5, 10 semitones (very spacious)

    private static func quartalStackBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
        let fourth = noteInPadsRegister(pc: (rootPC + 5) % 12, targetOct: 2)
        let flat7  = noteInPadsRegister(pc: (rootPC + 10) % 12, targetOct: 2)

        return [
            MIDIEvent(stepIndex: barStart, note: UInt8(root),   velocity: 65, durationSteps: 14),
            MIDIEvent(stepIndex: barStart, note: UInt8(fourth), velocity: 60, durationSteps: 14),
            MIDIEvent(stepIndex: barStart, note: UInt8(flat7),  velocity: 57, durationSteps: 14),
        ]
    }

    // MARK: - COS-RULE-07: Wurlitzer chord track (bIII voicing, velocity ramp)

    private static func wurlitzerChordBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // bIII = flat minor 3rd up from root
        let bIIIpc = (rootPC + 3) % 12
        let bIIIroot = noteInPadsRegister(pc: bIIIpc, targetOct: 2)
        let bIIIfifth = noteInPadsRegister(pc: (bIIIpc + 7) % 12, targetOct: 2)

        // Velocity ramp 15→65 simulated with two events
        return [
            MIDIEvent(stepIndex: barStart,     note: UInt8(bIIIroot),  velocity: 35, durationSteps: 8),
            MIDIEvent(stepIndex: barStart + 6, note: UInt8(bIIIroot),  velocity: 60, durationSteps: 10),
            MIDIEvent(stepIndex: barStart,     note: UInt8(bIIIfifth), velocity: 30, durationSteps: 8),
            MIDIEvent(stepIndex: barStart + 6, note: UInt8(bIIIfifth), velocity: 50, durationSteps: 10),
        ]
    }

    // MARK: - COS-RULE-16: Shimmer layer (high register, velocity ramp 15→55)

    private static func shimmerLayerBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // 1–3 notes from upper register (root + 2 or 3 octaves = MIDI 60+key+24 or +36)
        let noteCount = 1 + rng.nextInt(upperBound: 3)
        var evs: [MIDIEvent] = []

        let semitones = [0, 7, 12]  // root, fifth, octave
        for i in 0..<noteCount {
            let st = semitones[i % semitones.count]
            let base = 60 + rootPC + st
            var midi = base
            while midi < 60 { midi += 12 }
            while midi > 84 { midi -= 12 }

            // Velocity ramp 52→72 over 4–8 beats
            let dur = 4 * (1 + rng.nextInt(upperBound: 2))  // 4 or 8 steps
            evs.append(MIDIEvent(stepIndex: barStart, note: UInt8(midi), velocity: 52, durationSteps: dur / 2))
            if barStart + dur / 2 < barStart + 16 {
                evs.append(MIDIEvent(stepIndex: barStart + dur / 2, note: UInt8(midi),
                                     velocity: 72, durationSteps: dur / 2))
            }
        }
        return evs
    }

    // MARK: - Register helper: put pitch class in pads register (MIDI 36–72)

    private static func noteInPadsRegister(pc: Int, targetOct: Int) -> Int {
        var midi = targetOct * 12 + pc
        while midi < 36 { midi += 12 }
        while midi > 72 { midi -= 12 }
        return midi
    }
}
