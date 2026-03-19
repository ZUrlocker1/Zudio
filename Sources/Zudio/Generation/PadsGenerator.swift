// PadsGenerator.swift — generation step 6
// Harmonic bed using open chord voicings. Register: MIDI 48–84.
//
// Rule catalog (one primary style selected per song):
//   PAD-001: Sustained whole-bar (duration 14 steps — visual gap between notes)
//            Auto-breaks into PAD-007 after 4 consecutive whole-note bars.
//   PAD-002: Power/drone voicing (root+fifth+octave) whole-bar, same break rule.
//   PAD-003: Pulsed — one attack every 2 bars (durationSteps: 30)
//   PAD-004: Sparse intro/outro (50% skip)
//   PAD-006: Chord stabs — beat 1 (dur 4), sometimes beat 3 (dur 4)
//   PAD-007: Charleston rhythm — 3+3+2 feel, hits at steps 0, 6, 12
//   PAD-010: Half-bar breathe — chord on beat 1 (dur 7), silence second half
//   PAD-011: Backbeat stabs — chord hits on beats 2+4 only (steps 4, 12 dur 3)
//
// Note: arpeggios moved to RhythmGenerator (RHY-006) — pads are purely atmospheric.

struct PadsGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Weighted style selection — all rules are atmospheric/harmonic
        let padRules:   [String] = ["PAD-001","PAD-002","PAD-003","PAD-006",
                                    "PAD-007","PAD-010","PAD-011"]
        let padWeights: [Double] = [0.22,     0.17,     0.15,     0.14,
                                    0.18,     0.09,     0.05]
        let primaryRule = padRules[rng.weightedPick(padWeights)]
        usedRuleIDs.insert(primaryRule)
        usedRuleIDs.insert("PAD-004")  // sparse intro/outro always applies

        let totalBars = frame.totalBars
        var sustainRunBars = 0   // tracks consecutive whole-note bars for 4-bar break rule
        var prevRootMIDI: Int? = nil  // voice-leading anchor across bar lines

        for bar in 0..<totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard let cw = structure.chordWindow(atBar: bar) else { continue }

            // Intro/outro: skip probability varies by style
            if section.label == .intro {
                let isFirstBar = bar == (structure.introSection?.startBar ?? bar)
                switch structure.introStyle {
                case .alreadyPlaying:
                    if rng.nextDouble() < 0.20 { sustainRunBars = 0; continue }
                case .progressiveEntry:
                    let isLastBar = bar == (structure.introSection?.endBar ?? bar + 1) - 1
                    if !isLastBar { sustainRunBars = 0; continue }
                case .coldStart(let drumsOnly):
                    if isFirstBar { sustainRunBars = 0; continue }
                    if drumsOnly { sustainRunBars = 0; continue }
                    if rng.nextDouble() < 0.50 { sustainRunBars = 0; continue }
                }
            } else if section.label == .outro {
                let isLastBar = bar == (structure.outroSection?.endBar ?? bar + 1) - 1
                switch structure.outroStyle {
                case .fade:
                    if rng.nextDouble() < 0.15 { sustainRunBars = 0; continue }
                case .dissolve:
                    break
                case .coldStop:
                    if isLastBar { sustainRunBars = 0; continue }
                    if rng.nextDouble() < 0.20 { sustainRunBars = 0; continue }
                }
            }

            let stepIdx = bar * 16
            let voicing = buildVoicing(chordWindow: cw, frame: frame,
                                       usePower: primaryRule == "PAD-002",
                                       prevRootMIDI: prevRootMIDI)
            if let first = voicing.first { prevRootMIDI = Int(first) }

            let velocity: UInt8
            switch section.intensity {
            case .low:    velocity = UInt8(48 + rng.nextInt(upperBound: 12))
            case .medium: velocity = UInt8(60 + rng.nextInt(upperBound: 15))
            case .high:   velocity = UInt8(72 + rng.nextInt(upperBound: 15))
            }

            // 4-bar rule: after 4 consecutive sustained bars, inject a Charleston bar
            let activePrimary: String
            if (primaryRule == "PAD-001" || primaryRule == "PAD-002") && sustainRunBars >= 4 {
                activePrimary = "PAD-007"
                usedRuleIDs.insert("PAD-007")
                sustainRunBars = 0
            } else {
                activePrimary = primaryRule
            }

            switch activePrimary {

            // MARK: Sustained whole-bar
            case "PAD-001", "PAD-002":
                sustainRunBars += 1
                for note in voicing {
                    events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                            velocity: velocity, durationSteps: 14))
                }

            // MARK: Pulsed 2-bar
            case "PAD-003":
                if bar % 2 == 0 {
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                                velocity: velocity, durationSteps: 30))
                    }
                }

            // MARK: Chord stabs (beat 1 + sometimes beat 3)
            case "PAD-006":
                for note in voicing {
                    events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                            velocity: velocity, durationSteps: 4))
                }
                if rng.nextDouble() < 0.5 {
                    let vel2 = UInt8(max(40, Int(velocity) - 12))
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: stepIdx + 8, note: note,
                                                velocity: vel2, durationSteps: 4))
                    }
                }

            // MARK: Charleston / 3+3+2
            // Hits at steps 0, 6, 12 — dotted-quarter, dotted-quarter, quarter
            case "PAD-007":
                sustainRunBars = 0
                for (offset, dur) in [(0, 5), (6, 5), (12, 4)] {
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: stepIdx + offset, note: note,
                                                velocity: velocity, durationSteps: dur))
                    }
                }

            // MARK: Half-bar breathe — chord on beat 1, silence second half
            case "PAD-010":
                for note in voicing {
                    events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                            velocity: velocity, durationSteps: 7))
                }

            // MARK: Backbeat stabs — beats 2+4 only
            case "PAD-011":
                let bbVel = UInt8(clamped(Int(velocity) - 8, low: 40, high: 110))
                for step in [4, 12] {
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: stepIdx + step, note: note,
                                                velocity: bbVel, durationSteps: 3))
                    }
                }

            default:
                break
            }
        }

        return events
    }

    // MARK: - Voicing builder

    private static func buildVoicing(
        chordWindow: ChordWindow, frame: GlobalMusicalFrame, usePower: Bool,
        prevRootMIDI: Int? = nil
    ) -> [UInt8] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(chordWindow.chordRoot)) % 12
        let rootMIDI = nearestMIDI(pc: rootPC, target: prevRootMIDI ?? 54)

        if usePower {
            return [rootMIDI, rootMIDI + 7, rootMIDI + 12]
                .map { UInt8(clamped($0, low: 48, high: 84)) }
        }

        let offsets: [Int]
        switch chordWindow.chordType {
        case .major:   offsets = [0, 7, 12, 16]
        case .minor:   offsets = [0, 7, 12, 15]
        case .sus2:    offsets = [0, 7, 12, 14]
        case .sus4:    offsets = [0, 5, 12, 17]
        case .dom7:    offsets = [0, 7, 10, 16]
        case .min7:    offsets = [0, 7, 10, 15]
        case .add9:    offsets = [0, 7, 14, 16]
        case .quartal: offsets = [0, 5, 10, 15]
        case .power:   offsets = [0, 7, 12, 19]
        }

        return offsets.map { UInt8(clamped(rootMIDI + $0, low: 48, high: 84)) }
    }

    // MARK: - Helpers

    private static func nearestMIDI(pc: Int, target: Int) -> Int {
        let base = (target / 12) * 12 + pc
        let candidates = [base - 12, base, base + 12]
        return candidates.min(by: { abs($0 - target) < abs($1 - target) }) ?? base
    }

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        max(low, min(high, v))
    }
}
