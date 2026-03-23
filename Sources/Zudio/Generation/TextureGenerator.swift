// TextureGenerator.swift — generation step 9
// Sparse atmosphere: boundary-weighted events plus occasional one-off colour moments.
// Register: TEXT-001/TEXT-003–TEXT-008: MIDI 72–108 (high)
//           TEXT-002: MIDI 60–84 (warm mid register for depth and warmth)
//
// Rule catalog:
//   TEXT-001: Sparse — boundary-weighted single scale-tension notes (always active backbone)
//   TEXT-002: Transition Swell — sustained root/fifth at section boundaries, warm register
//   TEXT-003: Spatial Sweep — chromatic passing pair between scale tones, ~once per 14 body bars
//   TEXT-004: Shimmer Hold — single scale tone sustained 4+ bars, very quiet, ~once per 16 bars
//   TEXT-005: Breath Release — quiet note on last step of a section's final bar (50% per section end)
//   TEXT-006: High Tension Touch — single scale-tension note, off-beat, fires ~once per 20 bars (body only)
//   TEXT-007: Pedal Drone — tonic held quietly (vel 28–38) in MIDI 80–96, ~once per 32 body bars
//   TEXT-008: Phase Slip — two adjacent semitone notes at same step (vel 25–35), ~once per 20 body bars
//
// Per song: TEXT-001 always active; 1–2 supplementary rules chosen at generation time.

struct TextureGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // MOT-TEXT-001 is always the backbone
        usedRuleIDs.insert("MOT-TEXT-001")

        // Select 1–2 supplementary rules per song
        let suppCandidates = ["MOT-TEXT-002", "MOT-TEXT-003", "MOT-TEXT-004", "MOT-TEXT-005",
                               "MOT-TEXT-006", "MOT-TEXT-007", "MOT-TEXT-008"]
        let suppWeights:   [Double]  = [0.16, 0.14, 0.14, 0.12, 0.12, 0.16, 0.16]
        let primaryIdx = rng.weightedPick(suppWeights)
        var activeSupp: Set<String> = [suppCandidates[primaryIdx]]
        if rng.nextDouble() < 0.40 {
            let remaining = suppCandidates.enumerated().filter { $0.offset != primaryIdx }.map { $0.element }
            activeSupp.insert(remaining[rng.nextInt(upperBound: remaining.count)])
        }
        for r in activeSupp { usedRuleIDs.insert(r) }

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isSectionStart = section.startBar == bar
            let isSectionEnd   = section.endBar - 1 == bar
            let isBodySection  = section.label != .intro && section.label != .outro
            let barStart       = bar * 16

            // Pitch-class helpers
            let keyS    = keySemitone(frame.key)
            let rootPC  = (keyS + degreeSemitone(entry.chordWindow.chordRoot)) % 12
            let fifthPC = (rootPC + 7) % 12

            // --- TEXT-001: Sparse boundary-weighted single note ---
            let density: Double = (isSectionStart || isSectionEnd) ? 0.45 : 0.05
            if rng.nextDouble() < density {
                let tensionPool = entry.chordWindow.scaleTensions.sorted()
                let chordPool   = entry.chordWindow.chordTones.sorted()
                let pool = tensionPool.isEmpty ? chordPool : tensionPool
                if !pool.isEmpty {
                    let pc       = pool[rng.nextInt(upperBound: pool.count)]
                    let note     = noteInRange(pc: pc, low: 72, high: 108)
                    let startStep = barStart + rng.nextInt(upperBound: 16)
                    let duration  = [4, 8, 12, 16, 24, 32][rng.nextInt(upperBound: 6)]
                    events.append(MIDIEvent(stepIndex: startStep, note: note,
                                           velocity: UInt8(40 + rng.nextInt(upperBound: 25)),
                                           durationSteps: duration))
                }
            }

            // --- TEXT-002: Transition Swell — section boundaries, warm mid register ---
            if activeSupp.contains("MOT-TEXT-002") && (isSectionStart || isSectionEnd) {
                if rng.nextDouble() < 0.70 {
                    let pc       = rng.nextDouble() < 0.60 ? rootPC : fifthPC
                    let note     = noteInRange(pc: pc, low: 60, high: 84)
                    let duration = 24 + rng.nextInt(upperBound: 9)   // 24–32 steps
                    let velocity = UInt8(45 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: barStart, note: note,
                                           velocity: velocity, durationSteps: duration))
                }
            }

            // --- TEXT-003: Motorik Spatial Sweep — chromatic pair between scale tones, ~once per 14 body bars ---
            // Adapted from KOS-TEXT-003 Spatial Sweep; pairs a scale tone with its chromatic lower neighbour.
            if activeSupp.contains("MOT-TEXT-003") && isBodySection && rng.nextDouble() < (1.0 / 14.0) {
                let pool = entry.chordWindow.chordTones.sorted()
                if pool.count >= 2 {
                    let loPC    = pool[rng.nextInt(upperBound: pool.count)]
                    let passPC  = (loPC + 11) % 12   // chromatic lower neighbour
                    let hiPC    = pool[rng.nextInt(upperBound: pool.count)]
                    let offBeat = rng.nextInt(upperBound: 8)
                    let vel     = UInt8(30 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: barStart + offBeat,     note: noteInRange(pc: passPC, low: 72, high: 104),
                                           velocity: UInt8(max(22, Int(vel) - 8)), durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: barStart + offBeat + 2, note: noteInRange(pc: loPC,   low: 72, high: 104),
                                           velocity: vel, durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: barStart + offBeat + 6, note: noteInRange(pc: hiPC,   low: 72, high: 104),
                                           velocity: UInt8(max(22, Int(vel) - 4)), durationSteps: 4))
                }
            }

            // --- TEXT-004: Motorik Shimmer Hold — single scale tone sustained 4+ bars very quietly ---
            // Adapted from KOS-TEXT-002 EB Shimmer Hold; here rooted in scale tensions, not chord tones.
            if activeSupp.contains("MOT-TEXT-004") && isBodySection && rng.nextDouble() < (1.0 / 16.0) {
                let pool = (entry.chordWindow.scaleTensions.isEmpty
                            ? entry.chordWindow.chordTones : entry.chordWindow.scaleTensions).sorted()
                if !pool.isEmpty {
                    let pc   = pool[rng.nextInt(upperBound: pool.count)]
                    let note = noteInRange(pc: pc, low: 72, high: 100)
                    let vel  = UInt8(20 + rng.nextInt(upperBound: 13))
                    events.append(MIDIEvent(stepIndex: barStart, note: note,
                                           velocity: vel, durationSteps: 64 + rng.nextInt(upperBound: 17)))
                }
            }

            // --- TEXT-005: Breath Release — last step of a section's final bar ---
            if activeSupp.contains("MOT-TEXT-005") && isSectionEnd && rng.nextDouble() < 0.50 {
                let note     = noteInRange(pc: rootPC, low: 72, high: 96)
                let velocity = UInt8(25 + rng.nextInt(upperBound: 11))
                events.append(MIDIEvent(stepIndex: barStart + 15, note: note,
                                        velocity: velocity, durationSteps: 2))
            }

            // --- TEXT-006: High Tension Touch — ~once per 20 bars, body sections only ---
            if activeSupp.contains("MOT-TEXT-006") && isBodySection && rng.nextDouble() < (1.0 / 20.0) {
                let pool = entry.chordWindow.scaleTensions.sorted()
                if !pool.isEmpty {
                    let pc       = pool[rng.nextInt(upperBound: pool.count)]
                    let note     = noteInRange(pc: pc, low: 72, high: 108)
                    let offBeat  = [2, 6, 10, 14][rng.nextInt(upperBound: 4)]
                    let dur      = 8 + rng.nextInt(upperBound: 3)   // 8–10 steps
                    let vel      = UInt8(35 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: barStart + offBeat, note: note,
                                           velocity: vel, durationSteps: dur))
                }
            }

            // --- TEXT-007: Pedal Drone — tonic held quietly, ~once per 32 body bars ---
            // Motorik reference: constant-tonic undercurrent under moving chord changes.
            if activeSupp.contains("MOT-TEXT-007") && isBodySection && !isSectionEnd {
                if rng.nextDouble() < (1.0 / 32.0) {
                    let note    = noteInRange(pc: keyS, low: 80, high: 96)
                    let vel     = UInt8(28 + rng.nextInt(upperBound: 11))
                    events.append(MIDIEvent(stepIndex: barStart, note: note,
                                           velocity: vel, durationSteps: 32))
                }
            }

            // --- TEXT-008: Phase Slip — two adjacent semitone notes at same step, ~once per 20 body bars ---
            // Cluster reference: very quiet dissonant crunch, Stockhausen-via-Cluster influence.
            if activeSupp.contains("MOT-TEXT-008") && isBodySection && rng.nextDouble() < (1.0 / 20.0) {
                let chordPool = entry.chordWindow.chordTones.sorted()
                if !chordPool.isEmpty {
                    let loPC    = chordPool[rng.nextInt(upperBound: chordPool.count)]
                    let hiPC    = (loPC + 1) % 12
                    let loNote  = noteInRange(pc: loPC, low: 72, high: 96)
                    let hiNote  = noteInRange(pc: hiPC, low: 72, high: 96)
                    let offBeat = [4, 8, 12][rng.nextInt(upperBound: 3)]
                    let vel     = UInt8(25 + rng.nextInt(upperBound: 11))
                    let dur     = 2 + rng.nextInt(upperBound: 3)
                    events.append(MIDIEvent(stepIndex: barStart + offBeat, note: loNote,
                                           velocity: vel, durationSteps: dur))
                    events.append(MIDIEvent(stepIndex: barStart + offBeat, note: hiNote,
                                           velocity: UInt8(max(20, Int(vel) - 5)), durationSteps: dur))
                }
            }
        }

        return events
    }

    private static func noteInRange(pc: Int, low: Int, high: Int) -> UInt8 {
        for oct in 3...8 {
            let midi = oct * 12 + pc
            if midi >= low && midi <= high { return UInt8(midi) }
        }
        return UInt8(min(high, low + pc))
    }
}
