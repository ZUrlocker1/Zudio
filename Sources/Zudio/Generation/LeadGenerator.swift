// LeadGenerator.swift — generation step 7
// LD1-001: Motif-first — chord tones 80%, scale tensions 20%, quarter-grid + off-beats
// LD1-002: Pentatonic Cell — driving short-note cell from pentatonic scale
// LD1-003: Long Breath — sparse, long sustained notes with lots of rests
// LD1-004: Stepwise Sequence — descending 5→4→2→1 (bar A), shifted b7→5→4→2 (bar B)
//          Source: lead1_phrase_02 analysis — sequence development technique
// LD1-005: Statement-Answer — bar A ascends 1→2→b3→5, bar B silent then answers 4→b3
//          Source: lead1_phrase_01 analysis — classic Motorik call/response phrasing
// LD2-001: Counter-response — density ≤55% of Lead 1, avoids Lead 1 steps
// LD2-002: Sustained Drone — very sparse, long holds on root or 5th
// LD2-003: Rhythmic Counter — short bursts offset from Lead 1 rhythm
// LD2-004: Hallogallo Motif Counter — 16th-note pairs at steps 0,2,4,6,10,12,14,15
//          Source: lead2_hallogallo_motif_01 — Guitar 2 Motif (only 32 notes in full song)
// LD2-005: Descending Line — off-beat 2-bar arc 6→5→b3→2 with velocity diminuendo
//          Source: lead2_counter_02 analysis

struct LeadGenerator {
    // MARK: - Lead 1

    static func generateLead1(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let ld1Rules:   [String] = ["LD1-001", "LD1-002", "LD1-003", "LD1-004", "LD1-005"]
        let ld1Weights: [Double] = [0.25,      0.20,      0.15,      0.22,      0.18]
        let ruleID = ld1Rules[rng.weightedPick(ld1Weights)]
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
            case "LD1-004":
                events += lead1StepwiseSequence(barStart: barStart, bar: bar, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, rng: &rng)
            case "LD1-005":
                events += lead1StatementAnswer(barStart: barStart, bar: bar, entry: entry, frame: frame,
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
        let ld2Rules:   [String] = ["LD2-001", "LD2-002", "LD2-003", "LD2-004", "LD2-005"]
        let ld2Weights: [Double] = [0.25,      0.20,      0.20,      0.20,      0.15]
        let ruleID = ld2Rules[rng.weightedPick(ld2Weights)]
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
            case "LD2-004":
                events += lead2HallogalloCounter(barStart: barStart, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro, rng: &rng)
            case "LD2-005":
                events += lead2DescendingLine(barStart: barStart, bar: bar, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro, rng: &rng)
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

    // MARK: - LD1-004: Stepwise Sequence
    // Source: lead1_phrase_02 — descending 5→4→2→1 (bar A), shifted b7→5→4→2 (bar B).
    // Sequence development: state a descending 4-note pattern, repeat it a step lower.
    // Gives the melodic line a sense of direction and development over 2 bars.

    private static func lead1StepwiseSequence(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro && rng.nextDouble() < 0.65 { return events }
        let bounds = kRegisterBounds[kTrackLead1]!
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // Bar A (even): descend 5-4-2-1; Bar B (odd): repeat lower — b7-5-4-2
        let offsets: [Int] = (bar % 2 == 0) ? [7, 5, 2, 0] : [10, 7, 5, 2]
        let durs:    [Int] = [3, 2, 3, 4]   // longer on structurally strong positions
        let velAdj:  [Int] = [11, 5, 7, 3]  // velocity arc over the bar

        let baseVel = Int(velocityForIntensity(intensity, rng: &rng))
        for (i, step) in [0, 4, 8, 12].enumerated() {
            let pc   = (rootPC + offsets[i]) % 12
            let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
            let v    = UInt8(Swift.max(50, Swift.min(110, baseVel + velAdj[i] - 8)))
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: v, durationSteps: durs[i]))
        }
        return events
    }

    // MARK: - LD1-005: Statement-Answer
    // Source: lead1_phrase_01 — statement-answer 2-bar phrasing.
    // Bar A (statement): ascending 1→2→b3→5 fills the bar.
    // Bar B (answer): silence first half, then response 4→b3 with optional pickup.
    // Classic Motorik "breathe and respond" phrasing.

    private static func lead1StatementAnswer(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro && rng.nextDouble() < 0.65 { return events }
        let bounds = kRegisterBounds[kTrackLead1]!
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let baseVel = Int(velocityForIntensity(intensity, rng: &rng))

        if bar % 2 == 0 {
            // Statement: ascending 1→2→b3→5 at quarter-note grid
            let offsets = [0, 2, 3, 7]
            let durs    = [4, 3, 3, 5]
            let velBump = [0, -6, -3, +2]
            for (i, step) in [0, 4, 8, 12].enumerated() {
                let pc   = (rootPC + offsets[i]) % 12
                let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
                let v    = UInt8(Swift.max(50, Swift.min(110, baseVel + velBump[i])))
                events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                        velocity: v, durationSteps: durs[i]))
            }
        } else {
            // Answer: silence beats 1-2, optional pickup at step 6, response at steps 8 & 12
            if rng.nextDouble() < 0.40 {
                // Pickup (4th = softer approach into the answer)
                let pc   = (rootPC + 5) % 12
                let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
                events.append(MIDIEvent(stepIndex: barStart + 6, note: note, velocity: 65, durationSteps: 2))
            }
            let answerOffsets = [5, 3]   // 4th, b3 — descending answer to the statement's ascent
            let answerDurs    = [4, 5]
            for (i, step) in [8, 12].enumerated() {
                let pc   = (rootPC + answerOffsets[i]) % 12
                let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
                let v    = UInt8(Swift.max(50, Swift.min(105, baseVel - i * 5)))
                events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                        velocity: v, durationSteps: answerDurs[i]))
            }
        }
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

    // MARK: - LD2-004: Hallogallo Motif Counter
    // Source: lead2_hallogallo_motif_01 — Guitar 2 Motif (only 32 notes across the full song).
    // Quick 16th-note pairs on degrees 4, 5, 2, 1 with small register jumps.
    // Steps 0,2,4,6 (cluster 1), 10,12,14,15 (cluster 2) — mirroring the Hallogallo stutter.
    // Not all 8 fire per bar — 75% probability per hit keeps it from being dense.

    private static func lead2HallogalloCounter(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro { return events }
        let bounds = kRegisterBounds[kTrackLead2]!
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // Degrees: 4th, 5th, 2nd, 2nd (cluster 1) then 4th, 5th, root, root (cluster 2)
        let noteOffsets = [5, 7, 2, 2,   5, 7, 0, 0]
        let steps       = [0, 2, 4, 6,  10,12,14,15]
        let vels: [UInt8] = [84, 82, 82, 80,  84, 82, 80, 76]

        for (i, step) in steps.enumerated() {
            guard rng.nextDouble() < 0.75 else { continue }
            let pc   = (rootPC + noteOffsets[i]) % 12
            let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: vels[i], durationSteps: 1))
        }
        return events
    }

    // MARK: - LD2-005: Descending Diatonic Line
    // Source: lead2_counter_02 — 2-bar phrase, ~8-step off-beat spacing, 6→5→b3→2 descent.
    // Velocity diminuendo (70→66) creates a gently falling countermelody.
    // Fires on off-beats (steps 5, 13) to avoid clashing with Lead 1 downbeats.

    private static func lead2DescendingLine(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro && rng.nextDouble() < 0.60 { return events }
        let bounds = kRegisterBounds[kTrackLead2]!
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // Bar A (even): 6th at step 5, 5th at step 13
        // Bar B (odd):  b3 at step 5, 2nd at step 13 — continuation of the descent
        let (off1, off2): (Int, Int) = (bar % 2 == 0) ? (9, 7) : (3, 2)
        let (vel1, vel2): (UInt8, UInt8) = (bar % 2 == 0) ? (70, 72) : (68, 66)

        for (pcOffset, step, vel) in [(off1, 5, vel1), (off2, 13, vel2)] {
            let pc   = (rootPC + pcOffset) % 12
            let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: vel, durationSteps: 2))
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
