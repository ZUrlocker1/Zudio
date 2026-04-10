// KosmicTextureGenerator.swift — Kosmic texture generation
// Implements KOS-TEXT-001 through KOS-TEXT-004
// KOS-RULE-11: Bluebird/secondary arpeggio in MIDI 33–59, quarter-note durations
// Register separation from main arpeggio (55–72) is CRITICAL
//
// KOS-TEXT-001 variation: every 24 body bars (from bar 24 onward), motif lifts one octave
// for 8 bars then returns. Same pitches, same loop phase, purely a register shift.
// KOS-TEXT-004: Loscil Drip — deep low register MIDI 21–47, phrase modes A/B/C/D/E,
// minimum 2 notes per phrase, vel 48–66 for quiet modes, vel 44–124 for full shimmer (D).

import Foundation

struct KosmicTextureGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        kosmicProgFamily: KosmicProgressionFamily = .static_drone,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {

        // Clash fix: KOS-TEXT-003 (Spatial Sweep — chromatic passing) clashes with quartal
        // and suspended_resolution harmony. Exclude it from the pool for those families.
        let excludeText003 = (kosmicProgFamily == .quartal_stack || kosmicProgFamily == .suspended_resolution)
        let texRules:   [String] = excludeText003
            ? ["KOS-TEXT-001", "KOS-TEXT-002", "KOS-TEXT-004"]
            : ["KOS-TEXT-001", "KOS-TEXT-002", "KOS-TEXT-003", "KOS-TEXT-004"]
        let texWeights: [Double] = excludeText003
            ? [0.50,           0.32,           0.18]
            : [0.45,           0.27,           0.18,           0.10]
        let primaryRule = forceRuleID ?? texRules[rng.weightedPick(texWeights)]
        usedRuleIDs.insert(primaryRule)

        // Orbital motive loop length (different from arpeggio's pattern length)
        // Arpeggio uses 4 or 8 steps; texture uses 12 or 16 steps
        let texLoopLen = rng.nextDouble() < 0.5 ? 12 : 16

        let firstBodyBar = structure.sections
            .first(where: { $0.label != .intro && $0.label != .outro })?.startBar ?? 0

        var events: [MIDIEvent] = []

        // Bridge A-1 (.bridge): sparse single note every 2 bars climbing or descending.
        // Plays in the bluebird register (MIDI 33–59), direction matching bass/arpeggio/pads.
        for section in structure.sections where section.label == .bridge {
            let bridgeLen = max(1, section.endBar - section.startBar)
            let ascending = section.startBar % 3 != 2
            for bar in section.startBar..<section.endBar {
                guard bar % 2 == 0 else { continue }  // every 2 bars — sparse
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barInBridge = bar - section.startBar
                let phase       = min(3, barInBridge * 4 / bridgeLen)
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)
                // Step through chord tones in the bluebird register
                let ascPCs  = [0, third, 7, 12]
                let descPCs = [12, 7, third, 0]
                let pc  = (ascending ? ascPCs : descPCs)[phase]
                let note = clampToRegister(rootPC + pc + 36, low: 33, high: 59)
                let vel  = UInt8(max(32, min(72, 42 + phase * 6 + rng.nextInt(upperBound: 8) - 4)))
                events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(note), velocity: vel, durationSteps: 20))
            }
        }

        // Bridge B (.bridgeMelody): sparse atmospheric texture, only for longer bridges (> 4 bars).
        // Single note in bluebird register, very quiet — supports without competing with lead.
        // First half: root (harmonically stable); second half: fifth (slightly brighter, mild tension).
        for section in structure.sections where section.label == .bridgeMelody {
            let bridgeLen = section.endBar - section.startBar
            guard bridgeLen > 4 else { continue }
            let halfLen = max(1, bridgeLen / 2)
            for bar in section.startBar..<section.endBar {
                let barInBridge = bar - section.startBar
                guard barInBridge % 4 == 0 else { continue }
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let rootPC       = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let isSecondHalf = barInBridge >= halfLen
                // Root in first half (stable); fifth in second half (brightens as melody climbs)
                let pc = isSecondHalf ? 7 : 0
                let note = clampToRegister(rootPC + pc + 36, low: 33, high: 59)
                let vel = UInt8(isSecondHalf ? 45 : 35)
                events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(note), velocity: vel, durationSteps: 10))
            }
        }

        // Bridge A-2 (.bridgeAlt): sparse optional texture on response bars only (~30% chance).
        // Root or fifth in bluebird register — harmonic support without competing with arpeggio melody.
        for section in structure.sections where section.label == .bridgeAlt {
            for bar in section.startBar..<section.endBar {
                let bridgeBar = bar - section.startBar
                guard bridgeBar % 2 == 1 else { continue }  // response bars only (odd bars)
                guard rng.nextDouble() < 0.30 else { continue }
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                // root or fifth only — avoid thirds that conflict with arpeggio phrase
                let pc = rng.nextDouble() < 0.6 ? 0 : 7
                let note = clampToRegister(rootPC + pc + 36, low: 33, high: 59)
                let vel = UInt8(max(32, min(55, 38 + rng.nextInt(upperBound: 12) - 4)))
                events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(note), velocity: vel, durationSteps: 10))
            }
        }

        for section in structure.sections {
            // Texture is silent during all bridge sections except .bridge (handled above)
            guard !section.label.isBridge else { continue }
            // preRamp uses TEXT-002 shimmer; postRamp uses TEXT-003 sweep (fall through to switch below)
            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16

                // Intro: shimmer appears in second half only — atmospheric build
                if section.label == .intro {
                    let midpoint = section.startBar + (section.endBar - section.startBar) / 2
                    guard bar >= midpoint && bar % 4 == 0 else { continue }
                    let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                    let note   = texRegisterNote(pc: rootPC, targetOct: 2)
                    events.append(MIDIEvent(stepIndex: barStart, note: UInt8(note),
                                            velocity: UInt8(86 + rng.nextInt(upperBound: 10)),
                                            durationSteps: 62))
                    continue
                }

                // PreRamp: shimmer hold signals change coming (TEXT-002 behavior)
                if section.label == .preRamp {
                    guard bar % 4 == 0 else { continue }
                    let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                    let note   = texRegisterNote(pc: rootPC, targetOct: 2)
                    events.append(MIDIEvent(stepIndex: barStart, note: UInt8(note),
                                            velocity: UInt8(72 + rng.nextInt(upperBound: 10)),
                                            durationSteps: 62))
                    continue
                }

                // PostRamp: spatial sweep signals return (TEXT-003 behavior)
                if section.label == .postRamp {
                    events += spatialSweepBar(barStart: barStart, bar: bar, entry: entry, frame: frame, rng: &rng)
                    continue
                }

                // Outro: shimmer in first half only, fades out
                if section.label == .outro {
                    let midpoint = section.startBar + (section.endBar - section.startBar) / 2
                    guard bar < midpoint && bar % 4 == 0 else { continue }
                    let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                    let note   = texRegisterNote(pc: rootPC, targetOct: 2)
                    events.append(MIDIEvent(stepIndex: barStart, note: UInt8(note),
                                            velocity: UInt8(25 + rng.nextInt(upperBound: 10)),
                                            durationSteps: 62))
                    continue
                }

                // posInBody used for 8-bar gate (TEXT-001 and TEXT-003 only).
                // TEXT-002 and TEXT-004 already have sparse phrase cycles — gating them produces
                // near-inaudible tracks (96-97% silent); no gate needed.
                let posInBody = bar - firstBodyBar
                let inWindowGap = posInBody >= 0 && (posInBody / 8) % 3 == 2

                // Bar-fire probability scales with section intensity — sparse in A, full in B/high
                let sectionIntensity = structure.section(atBar: bar)?.intensity ?? .medium
                let textureFireProb: Double
                switch sectionIntensity {
                case .low:    textureFireProb = 0.35
                case .medium: textureFireProb = 0.55
                case .high:   textureFireProb = 0.80
                }

                switch primaryRule {
                case "KOS-TEXT-001":
                    // 8-bar window rest: every 3rd window silent (prevents NO-GAPS)
                    guard !inWindowGap else { break }
                    guard rng.nextDouble() < textureFireProb else { break }
                    events += orbitalMotiveBar(barStart: barStart, bar: bar, loopLen: texLoopLen,
                                               firstBodyBar: firstBodyBar,
                                               entry: entry, frame: frame, structure: structure, rng: &rng)
                case "KOS-TEXT-002":
                    guard rng.nextDouble() < textureFireProb else { break }
                    events += distantPulseBar(barStart: barStart, bar: bar, firstBodyBar: firstBodyBar,
                                              entry: entry, frame: frame, structure: structure, rng: &rng)
                case "KOS-TEXT-003":
                    // 8-bar window rest: every 3rd window silent (prevents NO-GAPS)
                    guard !inWindowGap else { break }
                    guard rng.nextDouble() < textureFireProb else { break }
                    events += spatialSweepBar(barStart: barStart, bar: bar, entry: entry, frame: frame, rng: &rng)
                case "KOS-TEXT-004":
                    guard rng.nextDouble() < textureFireProb else { break }
                    events += loscilShimmerBar(barStart: barStart, bar: bar, firstBodyBar: firstBodyBar,
                                               entry: entry, frame: frame, rng: &rng)
                default:
                    guard !inWindowGap else { break }
                    guard rng.nextDouble() < textureFireProb else { break }
                    events += orbitalMotiveBar(barStart: barStart, bar: bar, loopLen: texLoopLen,
                                               firstBodyBar: firstBodyBar,
                                               entry: entry, frame: frame, structure: structure, rng: &rng)
                }
            }
        }

        return events
    }

    // MARK: - KOS-TEX-001: Orbital Motive
    // 3-note figure (root, 5th, octave) at different length than arpeggio.
    // Register: MIDI 33–59 (below arpeggio's 55–72) — KOS-RULE-11

    private static func orbitalMotiveBar(
        barStart: Int, bar: Int, loopLen: Int,
        firstBodyBar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // When a B section exists, lift the octave throughout B; otherwise use bar-count fallback.
        let barInBody  = bar - firstBodyBar
        let inLiftWindow: Bool
        if structure.hasBSection {
            inLiftWindow = structure.inBSection(atBar: bar)
        } else {
            inLiftWindow = barInBody >= 24 && barInBody % 24 < 8
        }
        let oct = inLiftWindow ? 5 : 4  // oct=4 → MIDI 48–59 (C3–B3); oct=5 → 60–71 (C4–B4)

        // Place in MIDI 33–55 register (KOS-RULE-11: Bluebird register) or one octave up
        let root   = texRegisterNote(pc: rootPC,              targetOct: oct)
        let fifth  = texRegisterNote(pc: (rootPC + 7) % 12,  targetOct: oct)
        let octave = texRegisterNote(pc: rootPC,              targetOct: oct + 1)
        let motif  = [root, fifth, octave]

        // Loop position: advances by 1 per bar so the motif cycles through different starting
        // positions, creating variety in which pitch/beat combination appears each bar.
        // (was `(bar * 16) % loopLen` which collapsed to 0 for loopLen=16 — all bars identical)
        let loopPosition = bar % loopLen
        var evs: [MIDIEvent] = []

        // Quarter-note durations (KOS-RULE-11): emit on beats, cycling through motif
        for beat in 0..<4 {
            let stepInLoop = (loopPosition + beat * 4) % motif.count
            let note = motif[stepInLoop % motif.count]
            let vel  = UInt8(85 + rng.nextInt(upperBound: 21))  // 85–105

            evs.append(MIDIEvent(stepIndex: barStart + beat * 4, note: UInt8(note),
                                 velocity: vel, durationSteps: 3))
        }
        return evs
    }

    // MARK: - KOS-TEX-002: Distant Pulse
    // A short melodic figure (2–4 notes) fires in bar 0 of each phrase cycle,
    // then silence for 7–11 bars before the next phrase. Cycle length and note
    // count rotate through fixed arrays so the timing feels irregular but is
    // deterministic and reproducible. Notes drawn from mode scale degrees, cycling
    // through different degrees per phrase so the signal drifts harmonically.
    // Octave lifts in B sections (same logic as KOS-TEXT-001).

    private static func distantPulseBar(
        barStart: Int, bar: Int, firstBodyBar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let barInBody = bar - firstBodyBar
        guard barInBody >= 0 else { return [] }

        // Cycle lengths (bars): phrase fires in bar 0, silent for the rest.
        // Varied to feel organic rather than metronomic.
        let cycleLens:  [Int] = [8, 9, 8, 11, 10, 8, 9, 11, 8, 10]
        // Note counts: 3 most frequent, 2 and 4 occasional
        let noteCounts: [Int] = [3, 2, 3, 4, 3, 3, 2, 4, 3, 3, 3, 2, 3, 3, 4, 3, 2, 3, 3, 4]

        // Walk cycle boundaries to find current phrase index and bar-within-cycle
        var cursor      = 0
        var phraseIndex = 0
        while cursor + cycleLens[phraseIndex % cycleLens.count] <= barInBody {
            let cycLen   = cycleLens[phraseIndex % cycleLens.count]
            cursor      += cycLen
            phraseIndex += 1
        }
        let barInCycle = barInBody - cursor
        guard barInCycle == 0 else { return [] }  // silent for all but phrase-start bars

        // Octave lift in B sections (matches KOS-TEXT-001 behaviour)
        let inLiftWindow: Bool
        if structure.hasBSection {
            inLiftWindow = structure.inBSection(atBar: bar)
        } else {
            inLiftWindow = barInBody >= 24 && barInBody % 24 < 8
        }
        let oct = inLiftWindow ? 5 : 4   // oct=4 → MIDI 48–59; oct=5 → 60–71

        let noteCount  = noteCounts[phraseIndex % noteCounts.count]
        let rootPC     = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let intervals  = entry.sectionMode.intervals
        let degreeOffset = phraseIndex % intervals.count  // rotates through scale tones per phrase

        // Step positions within a bar (16 steps = 1 bar)
        let stepOffsets: [Int]
        switch noteCount {
        case 2:  stepOffsets = [0, 8]           // beats 1 and 3
        case 3:  stepOffsets = [0, 6, 12]        // beats 1, 2.5, 3.5 — slightly offset feel
        default: stepOffsets = [0, 4, 8, 12]     // all four beats
        }

        // Build the ordered scale PC list from the frame key (not chord root) so all
        // picked PCs are guaranteed diatonic regardless of the current chord root degree.
        let keyST    = keySemitone(frame.key)
        let scalePCsOrdered = frame.mode.intervals.map { (keyST + $0) % 12 }

        var evs: [MIDIEvent] = []
        for (i, stepOff) in stepOffsets.enumerated() {
            let degIdx = (degreeOffset + i) % scalePCsOrdered.count
            let pc     = scalePCsOrdered[degIdx]
            let note   = texRegisterNote(pc: pc, targetOct: oct)
            let vel    = UInt8(68 + rng.nextInt(upperBound: 17))  // 68–84 — softer than KOS-TEXT-001
            evs.append(MIDIEvent(stepIndex: barStart + stepOff, note: UInt8(note),
                                 velocity: vel, durationSteps: 3))
        }
        return evs
    }

    // MARK: - KOS-TEX-003: Spatial Sweep
    // Chromatic passing notes (velocity 72) between scale tones, one per 4 bars

    private static func spatialSweepBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard bar % 8 == 0 else { return [] }  // every 8 bars (was 4) — wider gaps prevent NO-GAPS

        let keyST  = keySemitone(frame.key)
        let mode   = entry.sectionMode

        // Pick two adjacent scale tones and place a diatonic pass between them
        let intervals = mode.intervals
        let scalePCs  = Set(intervals.map { (keyST + $0) % 12 })
        let idx = rng.nextInt(upperBound: intervals.count - 1)
        let fromST = keyST + intervals[idx]
        let toST   = keyST + intervals[idx + 1]

        // Place pass note in MIDI 33–59 register — snap to scale so it's always diatonic
        let fromMIDI = clampToRegister(36 + (fromST % 12), low: 33, high: 55)
        let toMIDI   = clampToRegister(36 + (toST % 12),   low: 33, high: 59)
        let passPC   = snapToScale((fromMIDI + 1) % 12, scalePCs: scalePCs)
        let passNote = clampToRegister(36 + passPC,         low: 33, high: 59)

        // Only emit the pass note if it's distinct from both endpoints
        guard passNote != fromMIDI && passNote != toMIDI else {
            return [
                MIDIEvent(stepIndex: barStart,     note: UInt8(fromMIDI), velocity: 89, durationSteps: 8),
                MIDIEvent(stepIndex: barStart + 8, note: UInt8(toMIDI),   velocity: 89, durationSteps: 8),
            ]
        }
        return [
            MIDIEvent(stepIndex: barStart,     note: UInt8(fromMIDI), velocity: 89, durationSteps: 4),
            MIDIEvent(stepIndex: barStart + 4, note: UInt8(passNote),  velocity: 89, durationSteps: 4),
            MIDIEvent(stepIndex: barStart + 8, note: UInt8(toMIDI),    velocity: 89, durationSteps: 4),
        ]
    }

    // MARK: - KOS-TEX-004: Loscil Drip
    // The tight root/2nd/3rd cluster reveals itself slowly across the song.
    // Most phrases surface only 1–2 notes (long-held, barely audible).
    // The full staggered cluster (Mode D) fires at most 1–2 times in a typical song.
    //
    // Five phrase modes (14-slot rotation — all modes reachable within ~7 phrases):
    //   A: drip pair — root then 3rd, 10 steps apart, held 4–6 bars, vel 48–62
    //   B: rising pair  root→2nd, 8 steps apart, held 3–4 bars, vel 52–66
    //   C: falling pair 3rd→root, 8 steps apart, held 3–4 bars, vel 52–66
    //   D: full shimmer — original staggered 3-note cluster, envelope vel 44–124
    //   E: slow triple — all 3 notes spaced 16 steps apart, held 3 bars, vel 50–64
    // Rotation: [A,B,A,C,B,D,A,C,B,A,E,C,B,D] — Mode D at phrase 5, E at phrase 10.
    //
    // Register: MIDI 21–47 (deep low) — distinct from Distant Pulse's MIDI 48–71.
    // Cycle lengths [8,9,8,10,9,8,9,8,10,9]: avg ~8.8 bars → ~7 phrases in 60-bar body.

    private static func loscilShimmerBar(
        barStart: Int, bar: Int,
        firstBodyBar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let barInBody = bar - firstBodyBar
        guard barInBody >= 0 else { return [] }

        // Variable cycle lengths — shorter so all modes are reachable in a typical song
        let cycleLens: [Int] = [8, 9, 8, 10, 9, 8, 9, 8, 10, 9]

        // Walk cycle boundaries to find phrase index and position within cycle
        var cursor      = 0
        var phraseIndex = 0
        while cursor + cycleLens[phraseIndex % cycleLens.count] <= barInBody {
            let cycLen   = cycleLens[phraseIndex % cycleLens.count]
            cursor      += cycLen
            phraseIndex += 1
        }
        guard barInBody == cursor else { return [] }  // only fire on phrase-start bars

        // Compute the tight cluster notes (root, 2nd, 3rd) in deep low register MIDI 21–47
        let rootPC   = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let scalePCs = frame.scalePCs
        let secondPC = snapToScale((rootPC + 2) % 12, scalePCs: scalePCs)
        let thirdPC  = snapToScale((rootPC + 3) % 12, scalePCs: scalePCs)

        let n0 = clampToRegister(36 + rootPC,   low: 21, high: 47)
        let n1 = clampToRegister(36 + secondPC, low: 21, high: 47)
        let n2 = clampToRegister(36 + thirdPC,  low: 21, high: 47)

        // 14-slot rotation: all modes reachable within ~7 phrases (typical song body)
        // D appears at slot 5 and 13; E appears at slot 10
        let modeSlots: [Character] =
            ["A","B","A","C","B","D","A","C","B","A","E","C","B","D"]
        let phraseMode = modeSlots[phraseIndex % modeSlots.count]

        switch phraseMode {

        case "A":
            // Drip pair: root then 3rd, 10 steps apart — always 2 notes, minimum
            let dur0 = [16, 24, 32][phraseIndex % 3]              // 4, 6, or 8 bars
            let dur1 = dur0 - 4                                    // second note slightly shorter
            let vel0 = UInt8(48 + rng.nextInt(upperBound: 15))    // 48–62
            let vel1 = UInt8(max(1, Int(vel0) - 6))
            return [
                MIDIEvent(stepIndex: barStart,      note: UInt8(n0), velocity: vel0, durationSteps: dur0),
                MIDIEvent(stepIndex: barStart + 10, note: UInt8(n2), velocity: vel1, durationSteps: max(4, dur1)),
            ]

        case "B":
            // Rising pair: root then 2nd, spaced 8 steps (2 bars) apart
            let vel0 = UInt8(52 + rng.nextInt(upperBound: 15))  // 52–66
            let vel1 = UInt8(max(1, Int(vel0) - 6))
            let dur  = 14 + rng.nextInt(upperBound: 5)           // 14–18 steps
            return [
                MIDIEvent(stepIndex: barStart,     note: UInt8(n0), velocity: vel0, durationSteps: dur),
                MIDIEvent(stepIndex: barStart + 8, note: UInt8(n1), velocity: vel1, durationSteps: dur),
            ]

        case "C":
            // Falling pair: 3rd then root, spaced 8 steps (2 bars) apart
            let vel0 = UInt8(52 + rng.nextInt(upperBound: 15))  // 52–66
            let vel1 = UInt8(max(1, Int(vel0) - 6))
            let dur  = 14 + rng.nextInt(upperBound: 5)           // 14–18 steps
            return [
                MIDIEvent(stepIndex: barStart,     note: UInt8(n2), velocity: vel0, durationSteps: dur),
                MIDIEvent(stepIndex: barStart + 8, note: UInt8(n0), velocity: vel1, durationSteps: dur),
            ]

        case "D":
            // Full shimmer — original staggered cluster with 16-bar volume envelope.
            // Floor raised to 0.60 (was 0.40) so the quietest point stays audible in the deep low register.
            let cyclePos = bar % 16
            let t: Double = cyclePos < 8
                ? Double(cyclePos) / 7.0
                : Double(15 - cyclePos) / 7.0
            let envelopeScale = 0.60 + 0.40 * t
            let peakVel = 110 + rng.nextInt(upperBound: 15)  // 110–124
            let baseVel = max(66, min(127, Int(Double(peakVel) * envelopeScale)))
            return [
                MIDIEvent(stepIndex: barStart,     note: UInt8(n0), velocity: UInt8(baseVel),               durationSteps: 62),
                MIDIEvent(stepIndex: barStart + 1, note: UInt8(n1), velocity: UInt8(max(1, baseVel - 8)),   durationSteps: 62),
                MIDIEvent(stepIndex: barStart + 2, note: UInt8(n2), velocity: UInt8(max(1, baseVel - 15)),  durationSteps: 62),
            ]

        default: // "E"
            // Slow triple: all 3 notes spaced 16 steps (4 bars) apart — a wide slow arpeggio
            let vel = UInt8(50 + rng.nextInt(upperBound: 15))  // 50–64
            let dur = 10 + rng.nextInt(upperBound: 5)           // 10–14 steps
            return [
                MIDIEvent(stepIndex: barStart,      note: UInt8(n0), velocity: vel,                          durationSteps: dur),
                MIDIEvent(stepIndex: barStart + 16, note: UInt8(n1), velocity: UInt8(max(1, Int(vel) - 4)),  durationSteps: dur),
                MIDIEvent(stepIndex: barStart + 32, note: UInt8(n2), velocity: UInt8(max(1, Int(vel) - 8)),  durationSteps: dur),
            ]
        }
    }

    // MARK: - Register helper: place pitch class in texture register MIDI 33–59

    private static func texRegisterNote(pc: Int, targetOct: Int) -> Int {
        clampToRegister(targetOct * 12 + pc, low: 36, high: 71)  // floor: C2; ceiling: B4
    }
}
