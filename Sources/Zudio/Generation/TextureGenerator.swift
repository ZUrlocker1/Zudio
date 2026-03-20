// TextureGenerator.swift — generation step 9
// Sparse atmosphere: boundary-weighted events plus occasional one-off colour moments.
// Register: TEX-001/TEX-004/TEX-005/TEX-006: MIDI 72–108 (high)
//           TEX-002/TEX-003: MIDI 60–84 (warm mid register for depth and warmth)
//
// Rule catalog:
//   TEX-001: Sparse — boundary-weighted single scale-tension notes (always active backbone)
//   TEX-002: Transition Swell — sustained root/fifth at section boundaries, warm register
//   TEX-003: Drone Anchor — 2-bar root/fifth hold, very quiet, fires ~once per 24 bars (body only)
//   TEX-004: Shimmer Pair — two notes a maj-7/min-9 apart, off-beat, fires ~once per 10 bars
//   TEX-005: Breath Release — quiet note on last step of a section's final bar (50% per section end)
//   TEX-006: High Tension Touch — single scale-tension note, off-beat, fires ~once per 20 bars (body only)
//
// Per song: TEX-001 always active; 1–2 supplementary rules chosen at generation time.

struct TextureGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // MOT-TEXR-001 is always the backbone
        usedRuleIDs.insert("MOT-TEXR-001")

        // Select 1–2 supplementary rules per song
        let suppCandidates = ["MOT-TEXR-002", "MOT-TEXR-003", "MOT-TEXR-004", "MOT-TEXR-005", "MOT-TEXR-006"]
        let suppWeights:   [Double]  = [0.25,      0.20,      0.25,      0.15,      0.15]
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

            // --- TEX-001: Sparse boundary-weighted single note ---
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

            // --- TEX-002: Transition Swell — section boundaries, warm mid register ---
            if activeSupp.contains("MOT-TEXR-002") && (isSectionStart || isSectionEnd) {
                if rng.nextDouble() < 0.70 {
                    let pc       = rng.nextDouble() < 0.60 ? rootPC : fifthPC
                    let note     = noteInRange(pc: pc, low: 60, high: 84)
                    let duration = 24 + rng.nextInt(upperBound: 9)   // 24–32 steps
                    let velocity = UInt8(45 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: barStart, note: note,
                                           velocity: velocity, durationSteps: duration))
                }
            }

            // --- TEX-003: Drone Anchor — ~once per 24 bars, body sections only ---
            if activeSupp.contains("MOT-TEXR-003") && isBodySection && !isSectionEnd {
                if rng.nextDouble() < (1.0 / 24.0) {
                    let pc       = rng.nextDouble() < 0.65 ? rootPC : fifthPC
                    let note     = noteInRange(pc: pc, low: 60, high: 72)
                    let velocity = UInt8(28 + rng.nextInt(upperBound: 13))
                    events.append(MIDIEvent(stepIndex: barStart, note: note,
                                           velocity: velocity, durationSteps: 32))
                }
            }

            // --- TEX-004: Shimmer Pair — ~once per 10 bars ---
            if activeSupp.contains("MOT-TEXR-004") && rng.nextDouble() < (1.0 / 10.0) {
                let interval = rng.nextDouble() < 0.50 ? 11 : 14  // maj-7 or min-9
                let hiPC     = (rootPC + interval) % 12
                let loNote   = noteInRange(pc: rootPC, low: 72, high: 96)
                let hiNote   = noteInRange(pc: hiPC,   low: 72, high: 96)
                let offBeat  = [6, 10][rng.nextInt(upperBound: 2)]
                let dur      = 4 + rng.nextInt(upperBound: 3)      // 4–6 steps
                let vel      = UInt8(35 + rng.nextInt(upperBound: 16))
                events.append(MIDIEvent(stepIndex: barStart + offBeat, note: loNote,
                                        velocity: vel, durationSteps: dur))
                events.append(MIDIEvent(stepIndex: barStart + offBeat, note: hiNote,
                                        velocity: UInt8(max(30, Int(vel) - 5)), durationSteps: dur))
            }

            // --- TEX-005: Breath Release — last step of a section's final bar ---
            if activeSupp.contains("MOT-TEXR-005") && isSectionEnd && rng.nextDouble() < 0.50 {
                let note     = noteInRange(pc: rootPC, low: 72, high: 96)
                let velocity = UInt8(25 + rng.nextInt(upperBound: 11))
                events.append(MIDIEvent(stepIndex: barStart + 15, note: note,
                                        velocity: velocity, durationSteps: 2))
            }

            // --- TEX-006: High Tension Touch — ~once per 20 bars, body sections only ---
            if activeSupp.contains("MOT-TEXR-006") && isBodySection && rng.nextDouble() < (1.0 / 20.0) {
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