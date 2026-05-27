// PadsGenerator.swift — generation step 6
// Copyright (c) 2026 Zack Urlocker
// Harmonic bed using open chord voicings. Register: MIDI 48–84.
//
// Rule catalog (one primary style selected per song):
//   PAD-001: Sustained whole-bar (duration 14 steps — visual gap between notes)
//            Auto-breaks into PAD-005 (Regular) or PAD-006 (Noir) after 4 consecutive bars.
//   PAD-002: Power/drone voicing (root+fifth+octave) whole-bar. Motorik Noir only.
//   PAD-003: Pulsed — one attack every 2 bars (durationSteps: 30)
//   PAD-004: Chord stabs — beat 1 (dur 4), sometimes beat 3 (dur 4)
//   PAD-005: Charleston rhythm — 3+3+2 feel, hits at steps 0, 9. Regular Motorik only.
//   PAD-006: Half-bar breathe — chord on beat 1 (dur 7), silence second half
//   PAD-007: Backbeat stabs — chord hits on beats 2+4 only (steps 4, 12 dur 3).
//            Motorik Noir only.
//   PAD-008: Transmission Block — open-5th triad (root+fifth+octave, no third) held
//            4–8 bars, then 5–8 bars silence, beat 1 only. Does not follow chord changes.
//            From Joy Division "Transmission" (1979): single D–A–D chord, 8 bars on /
//            7 bars off throughout the song. Motorik Noir only.
//
// Note: arpeggios moved to RhythmGenerator (RHY-006) — pads are purely atmospheric.

struct PadsGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        noirVariation: Bool = false
    ) -> [MIDIEvent] {
        // Motorik Noir: pads absent 50% of songs — industrial austerity without wasting
        // the Noir-specific rules. Joy Division used pads meaningfully (Transmission, LWTUA).
        if noirVariation && rng.nextDouble() < 0.50 {
            usedRuleIDs.insert("MOT-PADS-000")
            return []
        }

        var events: [MIDIEvent] = []

        // Weighted style selection — all rules are atmospheric/harmonic
        // Noir fallback: bias toward the sparsest rule (PAD-003 pulsed) when pads do fire.
        //                             001   002   003   004   005   006   007   008
        let padRules:   [String] = ["MOT-PADS-001","MOT-PADS-002","MOT-PADS-003","MOT-PADS-004",
                                    "MOT-PADS-005","MOT-PADS-006","MOT-PADS-007","MOT-PADS-008"]
        let padWeights: [Double] = noirVariation
            // 002/007/008 Noir-only; 005 excluded
            ? [0.05, 0.17, 0.20, 0.08, 0.00, 0.20, 0.15, 0.15]
            // 002/007/008 excluded; 005 Regular-only
            : [0.20, 0.00, 0.22, 0.19, 0.22, 0.17, 0.00, 0.00]
        let primaryRule = padRules[rng.weightedPick(padWeights)]
        usedRuleIDs.insert(primaryRule)

        let totalBars = frame.totalBars
        var sustainRunBars = 0   // tracks consecutive whole-note bars for 4-bar break rule
        var prevRootMIDI: Int? = nil  // voice-leading anchor across bar lines
        // PADS-003 phrase gate: silence a whole 4-bar cycle 30% of the time for breathing room
        var pads003SilentCycle = false
        // PADS-008 block state: -1 = fire on first body bar; otherwise = bar to fire next chord
        var pads008NextFireAt = -1

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

            // Noir: even when pads are "on" (the 15% that pass the song-level gate),
            // skip 70% of individual bars to stay sparse and atmospheric.
            // PAD-008 manages its own spacing so the draw is consumed but not applied.
            let noirGateRoll = noirVariation ? rng.nextDouble() : 0.0
            if noirVariation && primaryRule != "MOT-PADS-008" && noirGateRoll < 0.70 {
                sustainRunBars = 0; continue
            }

            let stepIdx = bar * 16
            let voicing = buildVoicing(chordWindow: cw, frame: frame,
                                       usePower: primaryRule == "MOT-PADS-002",
                                       prevRootMIDI: prevRootMIDI)
            if let first = voicing.first { prevRootMIDI = Int(first) }

            let velocity: UInt8
            switch section.intensity {
            case .low:    velocity = UInt8(48 + rng.nextInt(upperBound: 12))
            case .medium: velocity = UInt8(60 + rng.nextInt(upperBound: 15))
            case .high:   velocity = UInt8(72 + rng.nextInt(upperBound: 15))
            }

            // 4-bar rule: after 4 consecutive sustained bars, inject a rhythmic break.
            // Regular uses Charleston (005); Noir uses Half-bar Breathe (006) — 005 is Regular-only.
            let activePrimary: String
            if (primaryRule == "MOT-PADS-001" || primaryRule == "MOT-PADS-002") && sustainRunBars >= 4 {
                let breakRule = noirVariation ? "MOT-PADS-006" : "MOT-PADS-005"
                activePrimary = breakRule
                usedRuleIDs.insert(breakRule)
                sustainRunBars = 0
            } else {
                activePrimary = primaryRule
            }

            switch activePrimary {

            // MARK: Sustained whole-bar
            case "MOT-PADS-001", "MOT-PADS-002":
                sustainRunBars += 1
                for note in voicing {
                    events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                            velocity: velocity, durationSteps: 14))
                }

            // MARK: Pulsed 2-bar with phrase step-out and pattern variation
            case "MOT-PADS-003":
                // Re-roll phrase gate at the start of each 4-bar cycle: 30% full silence.
                if bar % 4 == 0 { pads003SilentCycle = rng.nextDouble() < 0.30 }
                if !pads003SilentCycle && bar % 2 == 0 {
                    // Occasionally use a 4-bar long pulse instead of 2-bar (20% of active hits)
                    let longPulse = rng.nextDouble() < 0.20
                    let dur = longPulse ? 62 : 30
                    let stabNotes = voicing.count >= 2 ? [voicing[0], voicing[voicing.count - 1]] : voicing
                    for note in stabNotes {
                        events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                                velocity: velocity, durationSteps: dur))
                    }
                }

            // MARK: Chord stabs (beat 1 + sometimes beat 3) — 2-note sparse voicing
            case "MOT-PADS-004":
                let stabNotes = voicing.count >= 2 ? [voicing[0], voicing[voicing.count - 1]] : voicing
                for note in stabNotes {
                    events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                            velocity: velocity, durationSteps: 4))
                }
                if rng.nextDouble() < 0.35 {
                    let vel2 = UInt8(max(40, Int(velocity) - 12))
                    for note in stabNotes {
                        events.append(MIDIEvent(stepIndex: stepIdx + 8, note: note,
                                                velocity: vel2, durationSteps: 4))
                    }
                }

            // MARK: Charleston / 3+3+2
            // Hits at steps 0, 9 — dotted-quarter + dotted-quarter (2 hits, more space)
            case "MOT-PADS-005":
                sustainRunBars = 0
                let charlNotes = voicing.count >= 2 ? [voicing[0], voicing[voicing.count - 1]] : voicing
                for (offset, dur) in [(0, 7), (9, 6)] {
                    for note in charlNotes {
                        events.append(MIDIEvent(stepIndex: stepIdx + offset, note: note,
                                                velocity: velocity, durationSteps: dur))
                    }
                }

            // MARK: Half-bar breathe — chord on beat 1, silence second half
            case "MOT-PADS-006":
                for note in voicing {
                    events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                            velocity: velocity, durationSteps: 7))
                }

            // MARK: Backbeat stabs — beats 2+4 only
            case "MOT-PADS-007":
                let bbVel = UInt8(clamped(Int(velocity) - 8, low: 40, high: 110))
                for step in [4, 12] {
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: stepIdx + step, note: note,
                                                velocity: bbVel, durationSteps: 3))
                    }
                }

            // MARK: Transmission Block — open-5th triad held 4–8 bars, 5–8 bars silence
            case "MOT-PADS-008":
                // Lazy init: fire on first body bar we reach in the switch
                if pads008NextFireAt < 0 { pads008NextFireAt = bar }
                guard bar == pads008NextFireAt else { break }
                let holdBars = 4 + rng.nextInt(upperBound: 5)   // 4–8 bars of sustain
                let silBars  = 5 + rng.nextInt(upperBound: 4)   // 5–8 bars of silence
                pads008NextFireAt = bar + holdBars + silBars
                let holdSteps = holdBars * 16 - 2               // micro-gap before next chord
                let txVel = UInt8(clamped(55 + rng.nextInt(upperBound: 16), low: 40, high: 84))
                // Open-5th voicing: root + fifth + octave, no third (hollow JD sound)
                let txVoicing = buildVoicing(chordWindow: cw, frame: frame,
                                             usePower: true, prevRootMIDI: prevRootMIDI)
                for note in txVoicing {
                    events.append(MIDIEvent(stepIndex: stepIdx, note: note,
                                            velocity: txVel, durationSteps: holdSteps))
                }
                if let first = txVoicing.first { prevRootMIDI = Int(first) }

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

        // Snap each chord tone to the nearest in-scale pitch class.
        // Chord type intervals can add chromatic tones even when the chord root is diatonic
        // (e.g. dom7 adds a minor 7th that may not be in the mode; F#m7 adds C# in E Aeolian).
        // Snapping keeps voicings audible and in-key without removing notes entirely.
        let scalePCs = frame.scalePCs
        return offsets.map { offset -> UInt8 in
            let rawMidi   = clamped(rootMIDI + offset, low: 48, high: 84)
            let pc        = rawMidi % 12
            let nearestPC = nearestScalePitchClass(pc, in: scalePCs)
            let dist      = (nearestPC - pc + 12) % 12
            let shift     = dist <= 6 ? dist : dist - 12   // shortest semitone path
            return UInt8(clamped(rawMidi + shift, low: 48, high: 84))
        }
    }

    // MARK: - Helpers

    private static func nearestMIDI(pc: Int, target: Int, low: Int = 48, high: Int = 84) -> Int {
        let base = (target / 12) * 12 + pc
        let candidates = [base - 12, base, base + 12].filter { $0 >= low && $0 <= high }
        return candidates.min(by: { abs($0 - target) < abs($1 - target) }) ?? clamped(base, low: low, high: high)
    }

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        max(low, min(high, v))
    }
}
