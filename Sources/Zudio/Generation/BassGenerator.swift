// BassGenerator.swift — generation step 5
// BAS-001: Root anchor beat 1, chord tones beat 3, syncopation
// BAS-002: Motorik Drive — root on every quarter note, staccato
// BAS-003: Crawling Walk — 2-bar root/fifth/approach note pattern

struct BassGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let ruleIndex = rng.nextInt(upperBound: 3)
        let ruleID: String
        switch ruleIndex {
        case 1:  ruleID = "BAS-002"
        case 2:  ruleID = "BAS-003"
        default: ruleID = "BAS-001"
        }
        usedRuleIDs.insert(ruleID)

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let barStart = bar * 16

            if isIntroOutro {
                // Sparse root-only anchor for intro/outro
                let rootNote = chordRootNote(entry: entry, frame: frame)
                events.append(MIDIEvent(stepIndex: barStart, note: rootNote, velocity: 70, durationSteps: 8))
            } else {
                switch ruleID {
                case "BAS-002":
                    events += motorikDriveBar(barStart: barStart, entry: entry, frame: frame)
                case "BAS-003":
                    events += crawlingWalkBar(barStart: barStart, bar: bar, entry: entry, frame: frame, rng: &rng)
                default:
                    events += anchorSyncBar(barStart: barStart, entry: entry, frame: frame, rng: &rng)
                }
            }
        }

        return events
    }

    // MARK: - BAS-001: root anchor + syncopation

    private static func anchorSyncBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let density = 0.7
        let rootNote = chordRootNote(entry: entry, frame: frame)
        events.append(MIDIEvent(stepIndex: barStart, note: rootNote, velocity: 90, durationSteps: 8))

        if rng.nextDouble() < density {
            let note = randomChordTone(entry: entry, frame: frame, rng: &rng)
            events.append(MIDIEvent(stepIndex: barStart + 8, note: note, velocity: 80, durationSteps: 6))
        }
        if rng.nextDouble() < density * 0.4 {
            let offStep = [2, 6, 10, 14][rng.nextInt(upperBound: 4)]
            let note = randomChordTone(entry: entry, frame: frame, rng: &rng)
            events.append(MIDIEvent(stepIndex: barStart + offStep, note: note, velocity: 72, durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-002: Motorik Drive — steady quarter-note pulse, staccato

    private static func motorikDriveBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote = chordRootNote(entry: entry, frame: frame)
        let velocities: [UInt8] = [95, 72, 85, 68]
        for beat in 0..<4 {
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: rootNote, velocity: velocities[beat], durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-003: Crawling Walk — 2-bar root/fifth/approach pattern

    private static func crawlingWalkBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry,
        frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote = chordRootNote(entry: entry, frame: frame)
        let fifthNote  = UInt8(clamped(Int(rootNote) + 7, low: 28, high: 52))
        let approachNote = UInt8(clamped(Int(rootNote) - 2, low: 28, high: 52))

        if bar % 2 == 0 {
            // Pattern A: root long, fifth short, chromatic approach pickup
            events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,     velocity: 90, durationSteps: 8))
            events.append(MIDIEvent(stepIndex: barStart + 10, note: fifthNote,    velocity: 75, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 15, note: approachNote, velocity: 65, durationSteps: 1))
        } else {
            // Pattern B: root short, root accent, fifth sustain
            events.append(MIDIEvent(stepIndex: barStart,     note: rootNote,  velocity: 90, durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 6, note: rootNote,  velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 8, note: fifthNote, velocity: 85, durationSteps: 6))
        }
        return events
    }

    // MARK: - Note helpers

    private static func chordRootNote(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> UInt8 {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let raw = 12 + 2 * 12 + rootPC
        return UInt8(clamped(raw, low: 28, high: 52))
    }

    private static func randomChordTone(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> UInt8 {
        let tones = entry.chordWindow.chordTones.sorted()
        guard !tones.isEmpty else { return chordRootNote(entry: entry, frame: frame) }
        let pc = tones[rng.nextInt(upperBound: tones.count)]
        let raw = 12 + 2 * 12 + pc
        return UInt8(clamped(raw, low: 28, high: 52))
    }

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        max(low, min(high, v))
    }
}
