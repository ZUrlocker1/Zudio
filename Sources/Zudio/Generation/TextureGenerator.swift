// TextureGenerator.swift — generation step 9
// Copyright (c) 2026 Zack Urlocker
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
//   TEXT-007: Pedal Drone — tonic held (vel 45–60) in MIDI 80–96, ~once per 16 body bars
//   TEXT-008: Phase Slip — two adjacent semitone notes at same step (vel 25–35), ~once per 20 body bars
//   TEXT-009: Wide Scatter — isolated SINGLE notes across a 50+ semitone span (MIDI 36-88),
//             one event then a 6-10 step gap. ~0.5 notes/beat. Kraftwerk sync only.
//   TEXT-010: Sparse Punctuation — 2-3 notes at a section boundary, then 300-400 steps of
//             silence. MIDI 52-82, long gates. Kraftwerk sync only.
//
// Per song: TEXT-001 always active; 1–2 supplementary rules chosen at generation time.
// Noir-only:    TEXT-006 (High Tension Touch), TEXT-008 (Phase Slip)
// Regular-only: TEXT-002 (Transition Swell),  TEXT-005 (Breath Release)
// Shared:       TEXT-003 (Spatial Sweep), TEXT-004 (Shimmer Hold), TEXT-007 (Pedal Drone)

struct TextureGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        noirVariation: Bool = false,
        arcadeVariation: Bool = false,
        sync: MotorikSync = .none,
        syncWindows: [Range<Int>] = []
    ) -> [MIDIEvent] {
        // Texture rides along with EVERY sync rather than belonging to one: its scattered
        // wide-register behaviour suits all three, and it is a supporting role rather than part
        // of the rhythmic interlock. When a sync fires it draws one of these two rules only,
        // replacing the usual backbone-plus-supplementary stack.
        if sync.includes(kTrackTexture) {
            let ruleID = rng.weightedPick([0.65, 0.35]) == 1 ? "MOT-TEXT-010" : "MOT-TEXT-009"
            usedRuleIDs.insert(ruleID)
            return kraftwerkTexture(ruleID: ruleID, frame: frame, structure: structure,
                                    tonalMap: tonalMap, windows: syncWindows, rng: &rng)
        }

        var events: [MIDIEvent] = []

        // MOT-TEXT-001 is always the backbone
        usedRuleIDs.insert("MOT-TEXT-001")

        // Select 1–2 supplementary rules per song (equal weights within each pool)
        // Arcade:  shared + TEXT-006 High Tension Touch (fits "danger" aesthetic)
        // Noir:    shared + TEXT-006, TEXT-008   Regular: shared + TEXT-002, TEXT-005
        let suppCandidates: [String]
        if arcadeVariation {
            suppCandidates = ["MOT-TEXT-003", "MOT-TEXT-004", "MOT-TEXT-005", "MOT-TEXT-006", "MOT-TEXT-007"]
        } else if noirVariation {
            suppCandidates = ["MOT-TEXT-003", "MOT-TEXT-004", "MOT-TEXT-006", "MOT-TEXT-007", "MOT-TEXT-008"]
        } else {
            suppCandidates = ["MOT-TEXT-002", "MOT-TEXT-003", "MOT-TEXT-004", "MOT-TEXT-005", "MOT-TEXT-007"]
        }
        let suppWeights = [Double](repeating: 1.0 / Double(suppCandidates.count), count: suppCandidates.count)
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
                    let vel     = UInt8(42 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: barStart + offBeat,     note: noteInRange(pc: passPC, low: 72, high: 104),
                                           velocity: UInt8(max(32, Int(vel) - 8)), durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: barStart + offBeat + 2, note: noteInRange(pc: loPC,   low: 72, high: 104),
                                           velocity: vel, durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: barStart + offBeat + 6, note: noteInRange(pc: hiPC,   low: 72, high: 104),
                                           velocity: UInt8(max(32, Int(vel) - 4)), durationSteps: 4))
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
                    let vel  = UInt8(35 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: barStart, note: note,
                                           velocity: vel, durationSteps: 64 + rng.nextInt(upperBound: 17)))
                }
            }

            // --- TEXT-005: Breath Release — last step of a section's final bar ---
            if activeSupp.contains("MOT-TEXT-005") && isSectionEnd && rng.nextDouble() < 0.50 {
                let note     = noteInRange(pc: rootPC, low: 72, high: 96)
                let velocity = UInt8(40 + rng.nextInt(upperBound: 16))
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

            // --- TEXT-007: Pedal Drone — tonic held, ~once per 16 body bars ---
            // Motorik reference: constant-tonic undercurrent under moving chord changes.
            if activeSupp.contains("MOT-TEXT-007") && isBodySection && !isSectionEnd {
                if rng.nextDouble() < (1.0 / 16.0) {
                    let note    = noteInRange(pc: keyS, low: 80, high: 96)
                    let vel     = UInt8(45 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: barStart, note: note,
                                           velocity: vel, durationSteps: 32))
                }
            }

            // --- TEXT-008: Phase Slip — two adjacent semitone notes at same step, ~once per 20 body bars ---
            // Sync reference: very quiet dissonant crunch, Stockhausen-via-Sync influence.
            if activeSupp.contains("MOT-TEXT-008") && isBodySection && rng.nextDouble() < (1.0 / 20.0) {
                let chordPool = entry.chordWindow.chordTones.sorted()
                if !chordPool.isEmpty {
                    let loPC    = chordPool[rng.nextInt(upperBound: chordPool.count)]
                    let hiPC    = (loPC + 1) % 12
                    let loNote  = noteInRange(pc: loPC, low: 72, high: 96)
                    let hiNote  = noteInRange(pc: hiPC, low: 72, high: 96)
                    let offBeat = [4, 8, 12][rng.nextInt(upperBound: 3)]
                    let vel     = UInt8(35 + rng.nextInt(upperBound: 16))
                    let dur     = 2 + rng.nextInt(upperBound: 3)
                    events.append(MIDIEvent(stepIndex: barStart + offBeat, note: loNote,
                                           velocity: vel, durationSteps: dur))
                    events.append(MIDIEvent(stepIndex: barStart + offBeat, note: hiNote,
                                           velocity: UInt8(max(30, Int(vel) - 5)), durationSteps: dur))
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

    // MARK: - Kraftwerk sync texture

    /// The corpus shows isolated single notes scattered across a very wide register (spans of
    /// 20-94 and 35-107 semitones) at high silence ratios (7:1 to 31:1). These are textures of
    /// punctuation, not of sustain — which is also why the sync's instrument subset drops the
    /// warm pads in favour of the FX voices.
    private static func kraftwerkTexture(
        ruleID: String,
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        windows: [Range<Int>],
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let totalSteps = frame.totalBars * 16

        func chordPCs(atStep step: Int) -> [Int] {
            let pool = tonalMap.entry(atBar: step / 16)?.chordWindow.chordTones.sorted() ?? []
            return pool.isEmpty ? [0] : pool
        }

        if ruleID == "MOT-TEXT-009" {
            // Wide Scatter — SINGLE notes, never phrases: one event, then a gap. The register
            // span is 36-88, which is 52 semitones, comfortably past the measured 40 minimum,
            // and pitches are drawn across the whole span rather than from a band. A note every
            // 6-10 steps averages ~0.5 notes/beat, inside the measured 0.4-0.7.
            var step = 8
            while step < totalSteps {
                let pcs = chordPCs(atStep: step)
                let pc  = pcs[rng.nextInt(upperBound: pcs.count)]
                // Draw the octave independently of the pitch class — that is what produces the
                // wide scatter rather than a melodic line.
                let octave = 3 + rng.nextInt(upperBound: 5)          // MIDI 36...88
                let note   = max(36, min(88, octave * 12 + pc))
                events.append(MIDIEvent(stepIndex: step, note: UInt8(note),
                                        velocity: 72, durationSteps: 1 + rng.nextInt(upperBound: 3)))
                step += 6 + rng.nextInt(upperBound: 5)               // 6...10 steps of silence
            }
            return events
        }

        // MOT-TEXT-010 Sparse Punctuation — very rare events at STRUCTURAL positions: 2-3 notes,
        // then a long silence. Placed against the form rather than randomly, which is what makes
        // them read as punctuation of it.
        //
        // Section starts alone are not enough anchors. A Motorik song has about three sections,
        // so the rule managed roughly two bursts and six notes across four minutes — present in
        // the file, inaudible in the song. The sync's dropout windows are the other structural
        // moment, and they are where this rule earns its place: Texture plays through the drop
        // while the machine parts step out, so these bursts are the only thing in that space.
        var anchors: [Int] = structure.sections.map { $0.startBar * 16 }
        for window in windows {
            anchors.append(window.lowerBound * 16)                    // as the sync steps out
            let mid = (window.lowerBound + window.upperBound) / 2
            if mid > window.lowerBound { anchors.append(mid * 16) }   // once more inside the gap
        }
        anchors.sort()

        // Still sparse: a burst needs real distance from the one before it.
        var lastStep = -1_000
        for step in anchors {
            guard step < totalSteps else { break }
            guard step - lastStep >= 180 + rng.nextInt(upperBound: 121) else { continue }
            let pcs   = chordPCs(atStep: step)
            let count = 2 + rng.nextInt(upperBound: 2)               // 2...3 notes
            for i in 0..<count {
                let pc   = pcs[rng.nextInt(upperBound: pcs.count)]
                var note = 52 + (((pc - 52) % 12) + 12) % 12
                while note < 52 { note += 12 }
                if note > 82 { note -= 12 }
                let at = step + i * 2
                guard at < totalSteps else { break }
                events.append(MIDIEvent(stepIndex: at, note: UInt8(max(52, min(82, note))),
                                        velocity: 68, durationSteps: 4 + rng.nextInt(upperBound: 5)))
            }
            lastStep = step
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

}
