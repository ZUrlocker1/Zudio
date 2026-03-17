// BassGenerator.swift — generation step 5
// Anchors key downbeats using chord tones; may syncopate on off-beats.
// Register: MIDI 28–52 (low register).

struct BassGenerator {
    static func generate(
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
            let density: Double = isIntroOutro ? 0.3 : 0.7
            let barStart = bar * 16

            // Always anchor beat 1 on chord root
            let rootNote = chordRootNote(entry: entry, frame: frame)
            events.append(MIDIEvent(stepIndex: barStart, note: rootNote, velocity: 90, durationSteps: 8))

            // Probabilistic beat 3 (half-bar anchor)
            if rng.nextDouble() < density {
                let beat3 = barStart + 8
                let note = randomChordTone(entry: entry, frame: frame, rng: &rng)
                events.append(MIDIEvent(stepIndex: beat3, note: note, velocity: 80, durationSteps: 6))
            }

            // Occasional syncopation on off-beat steps
            if rng.nextDouble() < density * 0.4 {
                let offStep = [2, 6, 10, 14][rng.nextInt(upperBound: 4)]
                let note = randomChordTone(entry: entry, frame: frame, rng: &rng)
                events.append(MIDIEvent(stepIndex: barStart + offStep, note: note, velocity: 72, durationSteps: 2))
            }
        }

        return events
    }

    // MARK: - Note helpers

    private static func chordRootNote(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> UInt8 {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // Target octave: MIDI 36–48 range (C2–C3)
        let baseOct = 2
        let raw = 12 + baseOct * 12 + rootPC
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
