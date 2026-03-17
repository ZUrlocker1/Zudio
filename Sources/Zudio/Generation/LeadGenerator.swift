// LeadGenerator.swift — generation step 7
// Lead 1: primary melodic motif. Lead 2: counter-response, lower density.
// Register Lead 1: MIDI 60–96. Lead 2: MIDI 55–91 (just below or above Lead 1).

struct LeadGenerator {
    // MARK: - Lead 1

    static func generateLead1(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let density = isIntroOutro ? 0.2 : densityForIntensity(section.subPhaseIntensity(atBar: bar))
            let barStart = bar * 16

            // Generate notes on strong beats probabilistically
            for step in [0, 4, 8, 12] {
                guard rng.nextDouble() < density else { continue }
                let note = pickNote(entry: entry, frame: frame, trackIndex: kTrackLead1, rng: &rng)
                let dur  = [2, 3, 4, 6, 8][rng.nextInt(upperBound: 5)]
                events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: velocityForIntensity(section.subPhaseIntensity(atBar: bar), rng: &rng), durationSteps: dur))
            }

            // Occasional off-beat flourish
            if rng.nextDouble() < density * 0.3 {
                let offStep = [2, 6, 10, 14][rng.nextInt(upperBound: 4)]
                let note = pickNote(entry: entry, frame: frame, trackIndex: kTrackLead1, rng: &rng)
                events.append(MIDIEvent(stepIndex: barStart + offStep, note: note, velocity: 70, durationSteps: 2))
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
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Build a step-indexed set of Lead 1 occupied steps for collision avoidance
        let lead1StepSet = Set(lead1Events.map(\.stepIndex))
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            // Lead 2 uses lower density than Lead 1 (spec §Lead 2 density cap)
            let density = isIntroOutro ? 0.1 : densityForIntensity(section.subPhaseIntensity(atBar: bar)) * 0.55
            let barStart = bar * 16

            for step in [0, 4, 8, 12] {
                // Avoid simultaneous accents with Lead 1 on most strong beats
                let conflicts = lead1StepSet.contains(barStart + step)
                guard rng.nextDouble() < density && (!conflicts || rng.nextDouble() < 0.15) else { continue }
                let note = pickNote(entry: entry, frame: frame, trackIndex: kTrackLead2, rng: &rng)
                let dur  = [2, 4, 6][rng.nextInt(upperBound: 3)]
                events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: 65, durationSteps: dur))
            }
        }

        return events
    }

    // MARK: - Helpers

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
        // Prefer chord tones on strong beats (80%), scale tensions allowed (20%)
        let pool: [Int]
        if rng.nextDouble() < 0.80 {
            pool = Array(entry.chordWindow.chordTones)
        } else {
            pool = Array(entry.chordWindow.scaleTensions)
        }

        guard !pool.isEmpty else {
            return frame.midiNote(degree: "1", oct: 0, trackIndex: trackIndex)
        }
        let pc = pool[rng.nextInt(upperBound: pool.count)]
        let bounds = kRegisterBounds[trackIndex] ?? RegisterBounds(low: 60, high: 96)
        // Find a MIDI note in bounds with this pitch class
        for oct in 3...7 {
            let midi = oct * 12 + pc
            if midi >= Int(bounds.low) && midi <= Int(bounds.high) {
                return UInt8(midi)
            }
        }
        return UInt8(bounds.low)
    }
}
