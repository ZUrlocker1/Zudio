// PadsGenerator.swift — generation step 6
// Harmonic bed using open chord voicings (spec §Chord voicing specification).
// Register: MIDI 48–84 (mid/high sustained range).

struct PadsGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        var lastChordWindow: ChordWindow? = nil

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            // Only emit a new chord event when the chord window changes
            guard entry.chordWindow != lastChordWindow else { continue }
            lastChordWindow = entry.chordWindow

            let isIntroOutro = section.label == .intro || section.label == .outro
            if isIntroOutro && rng.nextDouble() < 0.5 { continue } // sparse in intro/outro

            let velocity: UInt8 = UInt8(50 + rng.nextInt(upperBound: 30)) // 50–79
            let durationSteps = entry.chordWindow.lengthBars * 16

            let voicing = buildVoicing(entry: entry, frame: frame, rng: &rng)
            for note in voicing {
                events.append(MIDIEvent(
                    stepIndex: bar * 16,
                    note: note,
                    velocity: velocity,
                    durationSteps: durationSteps
                ))
            }
        }

        return events
    }

    // MARK: - Open voicing builder (spec §Default open voicing template)

    private static func buildVoicing(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [UInt8] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // Root in MIDI 48–60 range
        let rootMIDI = nearestMIDI(pc: rootPC, target: 54) // target middle of 48–60

        let useRootFifthOnly = rng.nextDouble() < 0.15 // 15% chance of power/drone voicing
        if useRootFifthOnly {
            let fifth = rootMIDI + 7
            let oct   = rootMIDI + 12
            return [rootMIDI, fifth, oct].map { UInt8(clamped($0, low: 48, high: 84)) }
        }

        // Default: open four-note spread
        let offsets = entry.chordWindow.chordType == .minor
            ? [0, 7, 12, 15]  // root, fifth, octave, minor third
            : [0, 7, 12, 16]  // root, fifth, octave, major third

        return offsets.map { UInt8(clamped(rootMIDI + $0, low: 48, high: 84)) }
    }

    // MARK: - Helpers

    private static func nearestMIDI(pc: Int, target: Int) -> Int {
        // Find MIDI note closest to target with pitch class == pc
        let base = (target / 12) * 12 + pc
        let candidates = [base - 12, base, base + 12]
        return candidates.min(by: { abs($0 - target) < abs($1 - target) }) ?? base
    }

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        max(low, min(high, v))
    }
}
