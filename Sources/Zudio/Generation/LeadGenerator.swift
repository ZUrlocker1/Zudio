// LeadGenerator.swift — generation step 7
// LD1-001: Motif-first, chord tones 80%, scale tensions 20%
// LD1-002: Pentatonic Cell — driving short-note cell from pentatonic scale
// LD1-003: Long Breath — sparse, long sustained notes with lots of rests
// LD2-001: Counter-response, density ≤55% of Lead 1
// LD2-002: Sustained Drone — very sparse, long holds on root or 5th
// LD2-003: Rhythmic Counter — short bursts offset from Lead 1 rhythm

struct LeadGenerator {
    // MARK: - Lead 1

    static func generateLead1(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let ruleIndex = rng.nextInt(upperBound: 3)
        let ruleID: String
        switch ruleIndex {
        case 1:  ruleID = "LD1-002"
        case 2:  ruleID = "LD1-003"
        default: ruleID = "LD1-001"
        }
        usedRuleIDs.insert(ruleID)

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let intensity    = section.subPhaseIntensity(atBar: bar)
            let barStart     = bar * 16

            switch ruleID {
            case "LD1-002":
                events += lead1PentatonicCell(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, rng: &rng)
            case "LD1-003":
                events += lead1LongBreath(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, rng: &rng)
            default:
                events += lead1MotifFirst(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, rng: &rng)
            }
        }

        return events
    }

    // MARK: - Lead 2

    static func generateLead2(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        lead1Events: [MIDIEvent],
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let ruleIndex = rng.nextInt(upperBound: 3)
        let ruleID: String
        switch ruleIndex {
        case 1:  ruleID = "LD2-002"
        case 2:  ruleID = "LD2-003"
        default: ruleID = "LD2-001"
        }
        usedRuleIDs.insert(ruleID)

        let lead1StepSet = Set(lead1Events.map(\.stepIndex))
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let intensity    = section.subPhaseIntensity(atBar: bar)
            let barStart     = bar * 16

            switch ruleID {
            case "LD2-002":
                events += lead2SustainedDrone(barStart: barStart, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro, rng: &rng)
            case "LD2-003":
                events += lead2RhythmicCounter(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, lead1StepSet: lead1StepSet, rng: &rng)
            default:
                events += lead2CounterResponse(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, lead1StepSet: lead1StepSet, rng: &rng)
            }
        }

        return events
    }

    // MARK: - LD1-001: motif-first

    private static func lead1MotifFirst(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let density = isIntroOutro ? 0.2 : densityForIntensity(intensity)
        for step in [0, 4, 8, 12] {
            guard rng.nextDouble() < density else { continue }
            let note = pickNote(entry: entry, frame: frame, trackIndex: kTrackLead1, rng: &rng)
            let dur  = [2, 3, 4, 6, 8][rng.nextInt(upperBound: 5)]
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                velocity: velocityForIntensity(intensity, rng: &rng), durationSteps: dur))
        }
        if rng.nextDouble() < density * 0.3 {
            let offStep = [2, 6, 10, 14][rng.nextInt(upperBound: 4)]
            let note = pickNote(entry: entry, frame: frame, trackIndex: kTrackLead1, rng: &rng)
            events.append(MIDIEvent(stepIndex: barStart + offStep, note: note, velocity: 70, durationSteps: 2))
        }
        return events
    }

    // MARK: - LD1-002: pentatonic cell — short, driving, repetitive

    private static func lead1PentatonicCell(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro && rng.nextDouble() < 0.65 { return events }
        let density = isIntroOutro ? 0.25 : min(1.0, densityForIntensity(intensity) * 1.3)
        let pcs    = pentatonicPCs(frame: frame)
        let bounds = kRegisterBounds[kTrackLead1]!

        for step in [0, 4, 8, 12] {
            guard rng.nextDouble() < density else { continue }
            let pc   = pcs[rng.nextInt(upperBound: pcs.count)]
            let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
            let dur  = [1, 2, 2, 3][rng.nextInt(upperBound: 4)]
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                velocity: velocityForIntensity(intensity, rng: &rng), durationSteps: dur))
        }
        if rng.nextDouble() < density * 0.4 {
            let offStep = [2, 6, 10, 14][rng.nextInt(upperBound: 4)]
            let pc   = pcs[rng.nextInt(upperBound: pcs.count)]
            let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
            events.append(MIDIEvent(stepIndex: barStart + offStep, note: note, velocity: 68, durationSteps: 1))
        }
        return events
    }

    // MARK: - LD1-003: long breath — sparse, sustained

    private static func lead1LongBreath(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let prob: Double = isIntroOutro ? 0.10 : (intensity == .high ? 0.40 : 0.22)
        guard rng.nextDouble() < prob else { return events }
        let step = [0, 4, 8][rng.nextInt(upperBound: 3)]
        let note = pickNote(entry: entry, frame: frame, trackIndex: kTrackLead1, rng: &rng)
        let dur  = [6, 8, 10, 12][rng.nextInt(upperBound: 4)]
        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
            velocity: velocityForIntensity(intensity, rng: &rng), durationSteps: dur))
        return events
    }

    // MARK: - LD2-001: counter-response

    private static func lead2CounterResponse(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, lead1StepSet: Set<Int>, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let density = isIntroOutro ? 0.1 : densityForIntensity(intensity) * 0.55
        for step in [0, 4, 8, 12] {
            let conflicts = lead1StepSet.contains(barStart + step)
            guard rng.nextDouble() < density && (!conflicts || rng.nextDouble() < 0.15) else { continue }
            let note = pickNote(entry: entry, frame: frame, trackIndex: kTrackLead2, rng: &rng)
            let dur  = [2, 4, 6][rng.nextInt(upperBound: 3)]
            events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: 65, durationSteps: dur))
        }
        return events
    }

    // MARK: - LD2-002: sustained drone — sparse long holds on root or 5th

    private static func lead2SustainedDrone(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let prob: Double = isIntroOutro ? 0.08 : 0.22
        guard rng.nextDouble() < prob else { return events }
        let bounds  = kRegisterBounds[kTrackLead2]!
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        let pc      = rng.nextDouble() < 0.65 ? fifthPC : rootPC
        let note    = midiNoteForPC(pc, bounds: bounds, rng: &rng)
        let dur     = [8, 12, 16][rng.nextInt(upperBound: 3)]
        events.append(MIDIEvent(stepIndex: barStart, note: note, velocity: 55, durationSteps: dur))
        return events
    }

    // MARK: - LD2-003: rhythmic counter — short bursts in gaps left by Lead 1

    private static func lead2RhythmicCounter(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, lead1StepSet: Set<Int>, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro { return events }
        let density = densityForIntensity(intensity) * 0.55
        for step in [2, 4, 6, 8, 10, 12, 14] {
            guard !lead1StepSet.contains(barStart + step) else { continue }
            guard rng.nextDouble() < density * 0.5 else { continue }
            let note = pickNote(entry: entry, frame: frame, trackIndex: kTrackLead2, rng: &rng)
            events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: 62, durationSteps: 2))
        }
        return events
    }

    // MARK: - Shared helpers

    private static func densityForIntensity(_ intensity: SectionIntensity) -> Double {
        switch intensity {
        case .low:    return 0.25
        case .medium: return 0.55
        case .high:   return 0.80
        }
    }

    private static func velocityForIntensity(_ intensity: SectionIntensity, rng: inout SeededRNG) -> UInt8 {
        let base: Int
        switch intensity {
        case .low:    base = 60
        case .medium: base = 75
        case .high:   base = 90
        }
        return UInt8(base + rng.nextInt(upperBound: 15))
    }

    private static func pickNote(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, trackIndex: Int, rng: inout SeededRNG
    ) -> UInt8 {
        let pool: [Int]
        if rng.nextDouble() < 0.80 {
            pool = entry.chordWindow.chordTones.sorted()
        } else {
            pool = entry.chordWindow.scaleTensions.sorted()
        }
        guard !pool.isEmpty else {
            return frame.midiNote(degree: "1", oct: 0, trackIndex: trackIndex)
        }
        let pc     = pool[rng.nextInt(upperBound: pool.count)]
        let bounds = kRegisterBounds[trackIndex] ?? RegisterBounds(low: 60, high: 96)
        for oct in 3...7 {
            let midi = oct * 12 + pc
            if midi >= Int(bounds.low) && midi <= Int(bounds.high) { return UInt8(midi) }
        }
        return UInt8(bounds.low)
    }

    private static func pentatonicPCs(frame: GlobalMusicalFrame) -> [Int] {
        let root = keySemitone(frame.key)
        let intervals: [Int]
        switch frame.mode {
        case .Ionian, .MajorPentatonic, .Mixolydian:
            intervals = [0, 2, 4, 7, 9]   // major pentatonic
        default:
            intervals = [0, 3, 5, 7, 10]  // minor pentatonic
        }
        return intervals.map { (root + $0) % 12 }
    }

    private static func midiNoteForPC(_ pc: Int, bounds: RegisterBounds, rng: inout SeededRNG) -> UInt8 {
        for oct in 3...7 {
            let midi = oct * 12 + pc
            if midi >= bounds.low && midi <= bounds.high { return UInt8(midi) }
        }
        return UInt8(bounds.low)
    }
}
