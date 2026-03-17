// TextureGenerator.swift — generation step 9
// Sparse atmosphere: weighted toward section boundaries.
// Register: MIDI 72–108 (spectral edges, high register).

struct TextureGenerator {
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

            let isSectionStart = section.startBar == bar
            let isSectionEnd   = section.endBar - 1 == bar

            // Heavier density at boundaries; near-zero in the middle
            let density: Double
            if isSectionStart || isSectionEnd {
                density = 0.45
            } else {
                density = 0.05
            }

            guard rng.nextDouble() < density else { continue }

            // Texture: mostly non-harmonic or drone; prefer scale tensions
            // Sort sets for determinism — Set iteration order is non-deterministic in Swift.
            let pool = (entry.chordWindow.scaleTensions.isEmpty
                ? entry.chordWindow.chordTones
                : entry.chordWindow.scaleTensions).sorted()
            guard !pool.isEmpty else { continue }

            let pc = pool[rng.nextInt(upperBound: pool.count)]
            let note = noteInRange(pc: pc, low: 72, high: 108)
            let barStart = bar * 16
            let startStep = barStart + rng.nextInt(upperBound: 16)
            let duration  = [4, 8, 12, 16][rng.nextInt(upperBound: 4)]

            events.append(MIDIEvent(
                stepIndex: startStep,
                note: note,
                velocity: UInt8(40 + rng.nextInt(upperBound: 25)),
                durationSteps: duration
            ))

            _ = section
        }

        return events
    }

    private static func noteInRange(pc: Int, low: Int, high: Int) -> UInt8 {
        for oct in 5...8 {
            let midi = oct * 12 + pc
            if midi >= low && midi <= high { return UInt8(midi) }
        }
        return UInt8(min(high, low + pc))
    }
}
