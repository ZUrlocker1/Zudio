// RhythmGenerator.swift — generation step 8
// Pulse embellishment: short 1–2 bar repeating ostinato.
// Register: MIDI 48–72 (low-mid to mid).

struct RhythmGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Generate a 2-bar motif per section, repeat it throughout
        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            let motif = generateMotif(section: section, frame: frame, tonalMap: tonalMap, rng: &rng)
            let motifLen = 2 * 16 // 2 bars in steps

            var bar = section.startBar
            while bar < section.endBar {
                let barStart = bar * 16
                let motifOffset = ((bar - section.startBar) % 2) * 16
                let sliceStart = motifOffset
                for ev in motif where ev.stepIndex >= sliceStart && ev.stepIndex < sliceStart + 16 {
                    let adjusted = MIDIEvent(
                        stepIndex: barStart + (ev.stepIndex - sliceStart),
                        note: ev.note,
                        velocity: ev.velocity,
                        durationSteps: ev.durationSteps
                    )
                    events.append(adjusted)
                }
                bar += 1
            }
            _ = motifLen
        }

        return events
    }

    private static func generateMotif(
        section: SongSection, frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard let entry = tonalMap.entry(atBar: section.startBar) else { return [] }
        var motif: [MIDIEvent] = []

        // Pick a single root pitch for the ostinato
        // Sort for determinism — Set iteration order is non-deterministic in Swift.
        let tones = entry.chordWindow.chordTones.sorted()
        let pc = tones.isEmpty ? 0 : tones[rng.nextInt(upperBound: tones.count)]
        let midiNote = noteInRange(pc: pc, low: 48, high: 72)

        // 2-bar pattern: every 2 steps (8th notes) or every 4 steps (quarter notes)
        let stride = rng.nextDouble() < 0.5 ? 2 : 4
        for step in Swift.stride(from: 0, to: 32, by: stride) {
            let vel = UInt8(65 + rng.nextInt(upperBound: 20))
            let dur = stride - 1
            motif.append(MIDIEvent(stepIndex: step, note: midiNote, velocity: vel, durationSteps: dur))
        }

        return motif
    }

    private static func noteInRange(pc: Int, low: Int, high: Int) -> UInt8 {
        for oct in 3...6 {
            let midi = oct * 12 + pc
            if midi >= low && midi <= high { return UInt8(midi) }
        }
        return UInt8(low)
    }
}
