// PadsGenerator.swift — generation step 6
// Harmonic bed using open chord voicings. Register: MIDI 48–84.
//
// Rule catalog (one primary style selected per song):
//   PAD-001: Sustained whole-bar (duration 14 steps — visual gap between notes)
//            Auto-breaks into PAD-007 after 4 consecutive whole-note bars.
//   PAD-002: Power/drone voicing (root+fifth+octave) whole-bar, same break rule.
//   PAD-003: Pulsed — one attack every 2 bars (durationSteps: 30)
//   PAD-004: Sparse intro/outro (50% skip)
//   PAD-005: Arpeggio — 8th notes cycling through chord tones
//            Direction variant chosen per song: ascending, descending, or bounce (up-down)
//   PAD-006: Chord stabs — beat 1 (dur 4), sometimes beat 3 (dur 4)
//   PAD-007: Charleston rhythm (from Silly Love Songs verse analysis):
//            3+3+2 feel — hits at steps 0, 6, 12 with durations 5, 5, 4
//   PAD-008: 16th-note chop (from Hallogallo Guitar analysis):
//            Near-every-16th staccato: steps 0-2, 4-6, 8-14 (duration 1 each)
//   PAD-009: Quarter pump (from SLS intro rhythm guitar):
//            Locked quarter-note chord hits, all 4 beats, vel-accented on 1+3
//   PAD-010: Half-bar breathe — chord on beat 1 (dur 7), silence second half; creates air
//   PAD-011: Backbeat stabs (from LA Woman guitar 2 syncopated fills):
//            Chord hits on beats 2+4 only (steps 4, 12 dur 3); off-beat emphasis

struct PadsGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Weighted style selection — arpeggio and Charleston weighted highest (most Motorik)
        let padRules:    [String] = ["PAD-001","PAD-002","PAD-003","PAD-005","PAD-006",
                                     "PAD-007","PAD-008","PAD-009","PAD-010","PAD-011"]
        let padWeights:  [Double] = [0.12,     0.10,     0.08,     0.18,     0.10,
                                     0.12,     0.08,     0.10,     0.08,     0.04]
        let primaryRule = padRules[rng.weightedPick(padWeights)]
        usedRuleIDs.insert(primaryRule)
        usedRuleIDs.insert("PAD-004")  // sparse intro/outro always applies

        // Arpeggio direction: 0=up, 1=down, 2=bounce
        let arpDirection = rng.nextInt(upperBound: 3)

        let totalBars = frame.totalBars
        var sustainRunBars = 0  // tracks consecutive whole-note bars for 4-bar rule

        for bar in 0..<totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard let cw = structure.chordWindow(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro

            // Intro/outro: 50% skip (PAD-004)
            if isIntroOutro && rng.nextDouble() < 0.5 {
                sustainRunBars = 0
                continue
            }

            let stepIdx = bar * 16
            let voicing = buildVoicing(chordWindow: cw, frame: frame, usePower: primaryRule == "PAD-002")

            let velocity: UInt8
            switch section.intensity {
            case .low:    velocity = UInt8(48 + rng.nextInt(upperBound: 12))
            case .medium: velocity = UInt8(60 + rng.nextInt(upperBound: 15))
            case .high:   velocity = UInt8(72 + rng.nextInt(upperBound: 15))
            }

            // 4-bar rule: after 4 consecutive sustained bars, inject a Charleston bar
            let activePrimary: String
            if (primaryRule == "PAD-001" || primaryRule == "PAD-002") && sustainRunBars >= 4 {
                activePrimary = "PAD-007"  // break the monotony
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

            // MARK: Arpeggio (up / down / bounce)
            case "PAD-005":
                let arpNotes = buildArpNotes(chordWindow: cw, frame: frame, direction: arpDirection)
                guard !arpNotes.isEmpty else { break }
                for i in 0..<8 {   // 8 eighth-notes per bar
                    let note = arpNotes[i % arpNotes.count]
                    events.append(MIDIEvent(stepIndex: stepIdx + i * 2, note: note,
                                            velocity: velocity, durationSteps: 2))
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

            // MARK: Charleston / 3+3+2 (Silly Love Songs verse pattern)
            // Hits at steps 0, 6, 12 — dotted-quarter, dotted-quarter, quarter
            case "PAD-007":
                sustainRunBars = 0
                let charlstonHits: [(Int, Int)] = [(0, 5), (6, 5), (12, 4)]
                for (offset, dur) in charlstonHits {
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: stepIdx + offset, note: note,
                                                velocity: velocity, durationSteps: dur))
                    }
                }

            // MARK: 16th-note chop (Hallogallo guitar density)
            // Staccato hits on every 16th except beat's final subdivision: skip steps 3,7,15
            case "PAD-008":
                let chopSteps = [0,1,2,4,5,6,8,9,10,11,12,13,14]
                for offset in chopSteps {
                    // Thin out slightly based on intensity
                    let skipChance: Double = section.intensity == .low ? 0.25 : 0.0
                    guard rng.nextDouble() >= skipChance else { continue }
                    let vel8 = UInt8(max(40, Int(velocity) - rng.nextInt(upperBound: 20)))
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: stepIdx + offset, note: note,
                                                velocity: vel8, durationSteps: 1))
                    }
                }

            // MARK: Quarter pump (SLS intro rhythm guitar — locked quarters, all 4 beats)
            case "PAD-009":
                let qtVels: [UInt8] = [88, 70, 82, 66]   // accented on 1+3, softer 2+4
                for (i, beat) in [0, 4, 8, 12].enumerated() {
                    let v = UInt8(clamped(Int(qtVels[i]) + (Int(velocity) - 72), low: 40, high: 110))
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: stepIdx + beat, note: note,
                                                velocity: v, durationSteps: 3))
                    }
                }

            // MARK: Half-bar breathe — chord on beat 1, long sustain, silence second half
            case "PAD-010":
                for note in voicing {
                    events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                            velocity: velocity, durationSteps: 7))
                }

            // MARK: Backbeat stabs (LA Woman guitar 2 syncopated fill pattern)
            // Off-beat emphasis: beats 2+4 only — contrasts all beat-1-anchored patterns
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
        chordWindow: ChordWindow, frame: GlobalMusicalFrame, usePower: Bool
    ) -> [UInt8] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(chordWindow.chordRoot)) % 12
        let rootMIDI = nearestMIDI(pc: rootPC, target: 54)

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

    // MARK: - Arpeggio builder

    /// Builds ordered MIDI note sequence from chord tones in range 48–84.
    /// direction: 0=ascending, 1=descending, 2=bounce (up then down, alternating)
    private static func buildArpNotes(
        chordWindow: ChordWindow, frame: GlobalMusicalFrame, direction: Int
    ) -> [UInt8] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(chordWindow.chordRoot)) % 12

        let chordIntervals: [Int]
        switch chordWindow.chordType {
        case .major:   chordIntervals = [0, 4, 7]
        case .minor:   chordIntervals = [0, 3, 7]
        case .sus2:    chordIntervals = [0, 2, 7]
        case .sus4:    chordIntervals = [0, 5, 7]
        case .dom7:    chordIntervals = [0, 4, 7, 10]
        case .min7:    chordIntervals = [0, 3, 7, 10]
        case .add9:    chordIntervals = [0, 4, 7, 14]
        case .quartal: chordIntervals = [0, 5, 10]
        case .power:   chordIntervals = [0, 7, 12]
        }

        // Collect all MIDI notes in range from chord-tone PCs
        var ascending: [UInt8] = []
        for octave in 4...7 {
            for interval in chordIntervals {
                let pc = (rootPC + interval) % 12
                let midi = octave * 12 + pc
                if midi >= 48 && midi <= 84 { ascending.append(UInt8(midi)) }
            }
        }
        ascending.sort()
        guard !ascending.isEmpty else { return ascending }

        switch direction {
        case 0: return ascending
        case 1: return ascending.reversed()
        default:
            // Bounce: ascending then descending (without repeating top/bottom)
            var bounce = ascending
            if ascending.count > 1 {
                let inner = Array(ascending.dropFirst().dropLast().reversed())
                bounce += inner
            }
            return bounce
        }
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
