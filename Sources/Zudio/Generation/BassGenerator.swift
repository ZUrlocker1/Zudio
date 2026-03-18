// BassGenerator.swift — generation step 5
//
// Rule catalog:
//   BAS-001: Root Anchor — root beat 1 (long), chord tone beat 3, clean and locked
//   BAS-002: Motorik Drive — 4 quarter notes, staccato, velocity accent on 1+3
//   BAS-003: Crawling Walk — 2-bar root/fifth/approach note pattern
//   BAS-004: Hallogallo Lock — root beat 1 (long), fifth beat 3, locked to kick 1+3 pattern
//   BAS-005: McCartney Drive — 8th-note locked groove derived from SLS verse;
//            bar 1: root-root-m3↓-m3↓-5↓-5↓-m3↓-5↓ descent, bar 2: breathe + pickup
//   BAS-006: LA Woman Sustain — root holds most of bar, chromatic neighbor shimmer at end
//
// All patterns hit beat 1 (step 0) as the primary anchor, matching the kick drum.
// Syncopation is deliberately minimized — Motorik bass is locked and pulse-forward.

struct BassGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        // Weighted selection — BAS-001/002/004 slightly favoured (most Motorik-locked)
        let rules:   [String] = ["BAS-001", "BAS-002", "BAS-003", "BAS-004", "BAS-005", "BAS-006"]
        let weights: [Double] = [0.20,      0.20,      0.12,      0.20,      0.18,      0.10]
        let ruleID = rules[rng.weightedPick(weights)]
        usedRuleIDs.insert(ruleID)

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let barStart = bar * 16

            if isIntroOutro {
                // Intro/outro: sparse root-only anchor locked to kick
                let rootNote = chordRootNote(entry: entry, frame: frame)
                let vel: UInt8 = section.label == .intro ? 72 : 65
                events.append(MIDIEvent(stepIndex: barStart, note: rootNote, velocity: vel, durationSteps: 7))
            } else {
                switch ruleID {
                case "BAS-002":
                    events += motorikDriveBar(barStart: barStart, entry: entry, frame: frame)
                case "BAS-003":
                    events += crawlingWalkBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
                case "BAS-004":
                    events += hallogalloLockBar(barStart: barStart, entry: entry, frame: frame)
                case "BAS-005":
                    events += mccartneyDriveBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
                case "BAS-006":
                    events += laWomanSustainBar(barStart: barStart, entry: entry, frame: frame)
                default:
                    events += rootAnchorBar(barStart: barStart, entry: entry, frame: frame, rng: &rng)
                }
            }
        }

        return events
    }

    // MARK: - BAS-001: Root Anchor — clean, locked to beat 1 and 3

    private static func rootAnchorBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote = chordRootNote(entry: entry, frame: frame)
        let chordTones = entry.chordWindow.chordTones.sorted()

        // Beat 1: root, long sustain (fills most of first half-bar)
        events.append(MIDIEvent(stepIndex: barStart, note: rootNote, velocity: 92, durationSteps: 6))

        // Beat 3: chord tone (fifth preferred) — clean landing locked to kick
        let beat3Note: UInt8
        if let fifth = chordTones.first(where: { ($0 - (Int(rootNote) % 12) + 12) % 12 == 7 }) {
            let pc = fifth
            beat3Note = noteInBassRegister(pc: pc, frame: frame)
        } else {
            beat3Note = rootNote
        }
        events.append(MIDIEvent(stepIndex: barStart + 8, note: beat3Note, velocity: 80, durationSteps: 5))

        return events
    }

    // MARK: - BAS-002: Motorik Drive — steady quarter pulse, velocity-accented

    private static func motorikDriveBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote = chordRootNote(entry: entry, frame: frame)
        // Accents on beats 1+3 (locked to kick), quieter on 2+4
        let velocities: [UInt8] = [96, 70, 88, 68]
        let durations:  [Int]   = [3,  2,  3,  2]
        for beat in 0..<4 {
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: rootNote,
                                    velocity: velocities[beat], durationSteps: durations[beat]))
        }
        return events
    }

    // MARK: - BAS-003: Crawling Walk — 2-bar root/fifth/approach pattern

    private static func crawlingWalkBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote    = chordRootNote(entry: entry, frame: frame)
        let fifthNote   = UInt8(clamped(Int(rootNote) + 7, low: 28, high: 52))
        let approachNote = UInt8(clamped(Int(rootNote) - 2, low: 28, high: 52))

        if bar % 2 == 0 {
            // Pattern A: root long, fifth, chromatic approach into bar 2
            events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,      velocity: 92, durationSteps: 7))
            events.append(MIDIEvent(stepIndex: barStart + 10, note: fifthNote,     velocity: 76, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 15, note: approachNote,  velocity: 65, durationSteps: 1))
        } else {
            // Pattern B: root short accent, fifth sustain (resolves the approach)
            events.append(MIDIEvent(stepIndex: barStart,     note: rootNote,  velocity: 92, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 5, note: rootNote,  velocity: 78, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 8, note: fifthNote, velocity: 85, durationSteps: 6))
        }
        return events
    }

    // MARK: - BAS-004: Hallogallo Lock — most authentic Motorik bass
    // Root on beat 1 (long, matches kick), fifth on beat 3 (matches kick), nothing on 2+4.
    // Very simple, very locked — the bass you hear in Hallogallo and Fur Immer.

    private static func hallogalloLockBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote = chordRootNote(entry: entry, frame: frame)
        let fifthNote = UInt8(clamped(Int(rootNote) + 7, low: 28, high: 52))

        // Root on beat 1 — long, fills the first half of the bar
        events.append(MIDIEvent(stepIndex: barStart,     note: rootNote,  velocity: 96, durationSteps: 7))
        // Fifth on beat 3 — locked to kick, sustains through beat 4
        events.append(MIDIEvent(stepIndex: barStart + 8, note: fifthNote, velocity: 80, durationSteps: 6))

        return events
    }

    // MARK: - BAS-005: McCartney Drive — 8th-note locked groove from SLS verse
    // Bar 1 (even): 8th-note drive descending root→m3-below→5th-below→m3→5th — the SLS "pump"
    // Bar 2 (odd):  breathe — long root, fifth sustain, chromatic pickup into next bar
    // Source: Wings "Silly Love Songs" verse bass (steps 0-15: 36-36-33-33-31-31-33-31)

    private static func mccartneyDriveBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote    = chordRootNote(entry: entry, frame: frame)
        // Descending bass neighbors (clamped to register): m3 and fifth below root
        let lowerThird = UInt8(clamped(Int(rootNote) - 3, low: 28, high: 52))
        let lowerFifth = UInt8(clamped(Int(rootNote) - 5, low: 28, high: 52))
        let approach   = UInt8(clamped(Int(rootNote) - 2, low: 28, high: 52))

        if bar % 2 == 0 {
            // Pattern A: 8th-note drive — root pair, lowerThird pair, lowerFifth pair, reverse tail
            // Rhythmically identical to SLS verse bar 1; interval shape derived from analysis
            let pitches: [UInt8] = [rootNote, rootNote, lowerThird, lowerThird,
                                    lowerFifth, lowerFifth, lowerThird, lowerFifth]
            let vels:    [UInt8] = [92, 84, 78, 74, 82, 76, 72, 68]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
        } else {
            // Pattern B: breathe — SLS bar 2 feel (long notes, chromatic pickup)
            events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,   velocity: 92, durationSteps: 7))
            events.append(MIDIEvent(stepIndex: barStart + 8,  note: lowerFifth, velocity: 82, durationSteps: 5))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: approach,   velocity: 65, durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-006: LA Woman Sustain — long root hold with chromatic shimmer at bar end
    // Source: The Doors "L.A. Woman" intro bass — root sustains ~11 steps (almost a full bar),
    // then brief chromatic ornament (root→upper-neighbor→root) before the next bar.
    // Creates a heavy, organ-like bass bed that breathes differently from the Motorik patterns.

    private static func laWomanSustainBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote      = chordRootNote(entry: entry, frame: frame)
        // Upper chromatic neighbor (one semitone above root) — the LA Woman "shimmer"
        let upperNeighbor = UInt8(clamped(Int(rootNote) + 1, low: 28, high: 52))

        // Root sustains most of the bar
        events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,      velocity: 90, durationSteps: 11))
        // Chromatic ornament at bar end: root → upper-neighbor → root (pickup)
        events.append(MIDIEvent(stepIndex: barStart + 12, note: rootNote,      velocity: 76, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 13, note: upperNeighbor, velocity: 68, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 14, note: rootNote,      velocity: 72, durationSteps: 2))

        return events
    }

    // MARK: - Note helpers

    private static func chordRootNote(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> UInt8 {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let raw = 12 + 2 * 12 + rootPC  // octave 3 (MIDI 36-47)
        return UInt8(clamped(raw, low: 28, high: 52))
    }

    private static func noteInBassRegister(pc: Int, frame: GlobalMusicalFrame) -> UInt8 {
        for oct in 2...4 {
            let midi = oct * 12 + pc
            if midi >= 28 && midi <= 52 { return UInt8(midi) }
        }
        return 36
    }

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        max(low, min(high, v))
    }
}
