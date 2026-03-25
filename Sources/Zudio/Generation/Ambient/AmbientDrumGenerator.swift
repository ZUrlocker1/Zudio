// AmbientDrumGenerator.swift — Ambient percussion generation (stochastic, no tiling)
// AMB-DRUM-004 (45%): hand percussion — congas, bongos, shakers, maracas, claves
// AMB-DRUM-001 (30%): brush kit — sparse ride/hat hits + occasional cymbal shimmer
// AMB-DRUM-003 (20%): no percussion
// AMB-DRUM-002  (5%): soft pulse — gentle kick on beat 1, hat on beat 3

import Foundation

struct AmbientDrumGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        useBrushKit: Bool = false
    ) -> [MIDIEvent] {
        switch percussionStyle {
        case .handPercussion:
            usedRuleIDs.insert("AMB-DRUM-004")
            return handPercussion(frame: frame, structure: structure, rng: &rng, useBrushKit: useBrushKit)
        case .textural:
            usedRuleIDs.insert("AMB-DRUM-001")
            return textural(frame: frame, structure: structure, rng: &rng)
        case .absent:
            usedRuleIDs.insert("AMB-DRUM-003")
            return []
        case .softPulse:
            usedRuleIDs.insert("AMB-DRUM-002")
            return softPulse(frame: frame, structure: structure, rng: &rng)
        default:
            return []
        }
    }

    // MARK: - Generators

    /// Hand percussion: congas, bongos, shakers, maracas, claves.
    /// Shaker runs a quiet 8th-note pulse on active bars (gives a breathing texture).
    /// Congas and bongos land stochastically on syncopated positions.
    private static func handPercussion(frame: GlobalMusicalFrame, structure: SongStructure,
                                       rng: inout SeededRNG, useBrushKit: Bool = false) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // GM note numbers for hand percussion (not in GMDrum enum)
        let hiConga: UInt8   = 63  // Open Hi Conga
        let midConga: UInt8  = 62  // Mute Hi Conga
        let lowConga: UInt8  = 64  // Low Conga
        let hiBongo: UInt8   = 60  // Hi Bongo
        let lowBongo: UInt8  = 61  // Low Bongo
        // Brush Kit substitutions: Maracas replaces Shaker; Open Triangle replaces Claves
        let shaker: UInt8    = useBrushKit ? 70 : 82  // 70=Maracas, 82=Shaker
        let maracas: UInt8   = 70
        let claves: UInt8    = useBrushKit ? 81 : 75  // 81=Open Triangle, 75=Claves

        // Step offsets for syncopated conga/bongo placements (16th-note grid)
        let conglacyPositions = [2, 4, 6, 8, 10, 12, 14]  // off-beats within a bar

        for bar in 0..<frame.totalBars {
            guard structure.section(atBar: bar)?.label == .A else { continue }

            // Shaker: 8th-note pulse (~70% of active bars), velocity 28–48
            if rng.nextDouble() < 0.70 {
                for step in stride(from: 0, to: 16, by: 2) {
                    let vel = UInt8(28 + rng.nextInt(upperBound: 20))  // 28–47
                    events.append(MIDIEvent(stepIndex: bar * 16 + step,
                                            note: shaker, velocity: vel, durationSteps: 1))
                }
            }

            // Congas: 1–3 hits per active bar (~75% chance), syncopated positions
            if rng.nextDouble() < 0.75 {
                let numHits = 1 + rng.nextInt(upperBound: 3)
                var positions = conglacyPositions
                for i in stride(from: positions.count - 1, through: 1, by: -1) {
                    positions.swapAt(i, rng.nextInt(upperBound: i + 1))
                }
                for h in 0..<min(numHits, positions.count) {
                    let vel = UInt8(42 + rng.nextInt(upperBound: 22))  // 42–63
                    let note: UInt8 = [hiConga, midConga, lowConga][rng.nextInt(upperBound: 3)]
                    events.append(MIDIEvent(stepIndex: bar * 16 + positions[h],
                                            note: note, velocity: vel, durationSteps: 1))
                }
            }

            // Bongos: accent hit ~35% of bars, on beat 1 or beat 3
            if rng.nextDouble() < 0.35 {
                let beat = (rng.nextDouble() < 0.5) ? 0 : 8
                let vel  = UInt8(38 + rng.nextInt(upperBound: 24))  // 38–61
                let note: UInt8 = rng.nextDouble() < 0.6 ? hiBongo : lowBongo
                events.append(MIDIEvent(stepIndex: bar * 16 + beat,
                                        note: note, velocity: vel, durationSteps: 1))
            }

            // Maracas: light accent ~25% of bars on offbeat step 6 or 10
            if rng.nextDouble() < 0.25 {
                let step = (rng.nextDouble() < 0.5) ? 6 : 10
                let vel  = UInt8(32 + rng.nextInt(upperBound: 16))  // 32–47
                events.append(MIDIEvent(stepIndex: bar * 16 + step,
                                        note: maracas, velocity: vel, durationSteps: 1))
            }

            // Claves: sparse click ~15% of bars on beat 2 (step 4)
            if rng.nextDouble() < 0.15 {
                let vel = UInt8(44 + rng.nextInt(upperBound: 20))  // 44–63
                events.append(MIDIEvent(stepIndex: bar * 16 + 4,
                                        note: claves, velocity: vel, durationSteps: 1))
            }
        }
        return events
    }

    /// Brush kit: sparse ride/hat hits (~30% chance per bar) + occasional cymbal shimmer.
    /// Crash hits land at section-A entry and every ~8 bars; ride accents every ~4 bars.
    private static func textural(frame: GlobalMusicalFrame, structure: SongStructure,
                                  rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let colors: [GMDrum] = [.closedHat, .rideBell, .ride]
        var lastCymbalBar = -8

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar), section.label == .A else { continue }

            // Regular brush/ride sparse hits
            if rng.nextDouble() < 0.30 {
                let beat = rng.nextInt(upperBound: 4) * 4
                let vel  = UInt8(35 + rng.nextInt(upperBound: 25))  // 35–59
                let drum = colors[rng.nextInt(upperBound: colors.count)]
                events.append(MIDIEvent(stepIndex: bar * 16 + beat,
                                        note: drum.rawValue, velocity: vel, durationSteps: 1))
            }

            // Cymbal shimmer: crash or open ride every 6–10 bars. Shimmers with delay + reverb.
            let barsSinceCymbal = bar - lastCymbalBar
            let isFirstBodyBar  = (bar == section.startBar)
            let cymbalThreshold = 6 + rng.nextInt(upperBound: 5)  // 6–10

            if isFirstBodyBar || barsSinceCymbal >= cymbalThreshold {
                if isFirstBodyBar || rng.nextDouble() < 0.55 {
                    let vel  = UInt8(50 + rng.nextInt(upperBound: 28))  // 50–77
                    // Alternate crash1, crash2, ride for variety
                    let cyms: [GMDrum] = [.crash1, .ride, .crash2, .ride]
                    let drum = cyms[rng.nextInt(upperBound: cyms.count)]
                    events.append(MIDIEvent(stepIndex: bar * 16,
                                            note: drum.rawValue, velocity: vel, durationSteps: 2))
                    lastCymbalBar = bar
                }
            }
        }
        return events
    }

    /// Very soft kick on beat 1 (~50%), brush hat on beat 3 (~30%).
    private static func softPulse(frame: GlobalMusicalFrame, structure: SongStructure,
                                   rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for bar in 0..<frame.totalBars {
            guard structure.section(atBar: bar)?.label == .A else { continue }
            if rng.nextDouble() < 0.50 {
                let vel = UInt8(32 + rng.nextInt(upperBound: 20))  // 32–51
                events.append(MIDIEvent(stepIndex: bar * 16,
                                        note: GMDrum.kick.rawValue, velocity: vel, durationSteps: 1))
            }
            if rng.nextDouble() < 0.30 {
                let vel = UInt8(25 + rng.nextInt(upperBound: 20))  // 25–44
                events.append(MIDIEvent(stepIndex: bar * 16 + 8,
                                        note: GMDrum.closedHat.rawValue, velocity: vel, durationSteps: 1))
            }
        }
        return events
    }
}
