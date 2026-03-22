// KosmicTextureGenerator.swift — Kosmic texture generation
// Implements KOS-TEXT-001 through KOS-TEXT-004
// KOS-RULE-11: Bluebird/secondary arpeggio in MIDI 33–59, quarter-note durations
// Register separation from main arpeggio (55–72) is CRITICAL
//
// KOS-TEXT-001 variation: every 24 body bars (from bar 24 onward), motif lifts one octave
// for 8 bars then returns. Same pitches, same loop phase, purely a register shift.
// KOS-TEXT-004: Loscil aquatic shimmer — 3 closely-voiced scale tones, staggered 1-step,
// attacks, bluebird register, every 4 bars, very quiet (vel 16–30), long hold (dur 62).

import Foundation

struct KosmicTextureGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {

        let texRules:   [String] = ["KOS-TEXT-001", "KOS-TEXT-002", "KOS-TEXT-003", "KOS-TEXT-004"]
        let texWeights: [Double] = [0.45,           0.27,           0.18,           0.10]
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
                var note = rootPC + pc + 36
                while note < 33 { note += 12 }
                while note > 59 { note -= 12 }
                let vel  = UInt8(max(14, min(60, 28 + phase * 6 + rng.nextInt(upperBound: 8) - 4)))
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
                var note = rootPC + pc + 36
                while note < 33 { note += 12 }
                while note > 59 { note -= 12 }
                let vel = UInt8(isSecondHalf ? 22 : 16)
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
                var note = rootPC + pc + 36
                while note < 33 { note += 12 }
                while note > 59 { note -= 12 }
                let vel = UInt8(max(14, min(35, 20 + rng.nextInt(upperBound: 12) - 4)))
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

                switch primaryRule {
                case "KOS-TEXT-001":
                    events += orbitalMotiveBar(barStart: barStart, bar: bar, loopLen: texLoopLen,
                                               firstBodyBar: firstBodyBar,
                                               entry: entry, frame: frame, structure: structure, rng: &rng)
                case "KOS-TEXT-002":
                    events += shimmerHoldBar(barStart: barStart, bar: bar, entry: entry, frame: frame, rng: &rng)
                case "KOS-TEXT-003":
                    events += spatialSweepBar(barStart: barStart, bar: bar, entry: entry, frame: frame, rng: &rng)
                case "KOS-TEXT-004":
                    events += loscilShimmerBar(barStart: barStart, bar: bar, entry: entry, frame: frame, rng: &rng)
                default:
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
        let oct = inLiftWindow ? 3 : 2

        // Place in MIDI 33–55 register (KOS-RULE-11: Bluebird register) or one octave up
        let root   = texRegisterNote(pc: rootPC,              targetOct: oct)
        let fifth  = texRegisterNote(pc: (rootPC + 7) % 12,  targetOct: oct)
        let octave = texRegisterNote(pc: rootPC,              targetOct: oct + 1)
        let motif  = [root, fifth, octave]

        // Loop position based on bar and loopLen
        // loopLen is in steps (not bars); we pick which part of the loop falls in this bar
        let loopPosition = (bar * 16) % loopLen
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

    // MARK: - KOS-TEX-002: Shimmer Hold
    // Single note held quietly (velocity 72–84) for 4+ bars

    private static func shimmerHoldBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Only attack every 4 bars
        guard bar % 4 == 0 else { return [] }

        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let note   = texRegisterNote(pc: rootPC, targetOct: 2)
        let vel    = UInt8(86 + rng.nextInt(upperBound: 13))  // 86–98

        // Hold for 4+ bars = 64+ steps; emit as a very long note
        return [MIDIEvent(stepIndex: barStart, note: UInt8(note), velocity: vel, durationSteps: 62)]
    }

    // MARK: - KOS-TEX-003: Spatial Sweep
    // Chromatic passing notes (velocity 72) between scale tones, one per 4 bars

    private static func spatialSweepBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard bar % 4 == 0 else { return [] }

        let keyST  = keySemitone(frame.key)
        let mode   = entry.sectionMode

        // Pick two adjacent scale tones and place chromatic pass between them
        let intervals = mode.intervals
        let idx = rng.nextInt(upperBound: intervals.count - 1)
        let fromST = keyST + intervals[idx]
        let toST   = keyST + intervals[idx + 1]

        // Place chromatic pass in MIDI 33–59 register
        var fromMIDI = 36 + (fromST % 12)
        while fromMIDI < 33 { fromMIDI += 12 }
        while fromMIDI > 55 { fromMIDI -= 12 }

        var chromPass = fromMIDI + 1
        while chromPass < 33 { chromPass += 12 }
        while chromPass > 59 { chromPass -= 12 }

        var toMIDI = 36 + (toST % 12)
        while toMIDI < 33 { toMIDI += 12 }
        while toMIDI > 59 { toMIDI -= 12 }

        return [
            MIDIEvent(stepIndex: barStart,     note: UInt8(fromMIDI), velocity: 89, durationSteps: 4),
            MIDIEvent(stepIndex: barStart + 4, note: UInt8(chromPass), velocity: 89, durationSteps: 4),
            MIDIEvent(stepIndex: barStart + 8, note: UInt8(toMIDI),    velocity: 89, durationSteps: 4),
        ]
    }

    // MARK: - KOS-TEX-004: Loscil Aquatic Shimmer
    // 3 closely-voiced scale tones with staggered 1-step attacks — dissolving into each other.
    // Fires every 4 bars. Long hold (62 steps) creates the blurred, underwater quality.
    // Very quiet (vel 16–30) so it sits beneath everything else as pure atmosphere.

    private static func loscilShimmerBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard bar % 4 == 0 else { return [] }

        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let mode   = entry.sectionMode
        let second = mode.nearestInterval(2)
        let third  = mode.nearestInterval(3)

        // 3 closely-voiced tones: root, 2nd, 3rd — one octave below bluebird (MIDI 21–47)
        var n0 = 36 + rootPC
        var n1 = 36 + rootPC + second
        var n2 = 36 + rootPC + third
        while n0 < 21 { n0 += 12 }; while n0 > 47 { n0 -= 12 }
        while n1 < 21 { n1 += 12 }; while n1 > 47 { n1 -= 12 }
        while n2 < 21 { n2 += 12 }; while n2 > 47 { n2 -= 12 }

        // 16-bar volume cycle: 8 bars ascending (40%→100%), 8 bars descending (100%→40%).
        // Rule fires every 4 bars, so the audible steps in the cycle are at positions 0, 4, 8, 12.
        let cyclePos = bar % 16
        let t: Double = cyclePos < 8
            ? Double(cyclePos) / 7.0          // 0.0 → 1.0 over bars 0–7
            : Double(15 - cyclePos) / 7.0     // 1.0 → 0.0 over bars 8–15
        let envelopeScale = 0.40 + 0.60 * t   // 40% at trough, 100% at peak

        // Stagger attacks by 1 step each — creates slow-motion cluster dissolve
        let peakVel = 110 + rng.nextInt(upperBound: 15)  // 110–124
        let baseVel = max(1, min(127, Int(Double(peakVel) * envelopeScale)))
        return [
            MIDIEvent(stepIndex: barStart,     note: UInt8(n0), velocity: UInt8(baseVel),      durationSteps: 62),
            MIDIEvent(stepIndex: barStart + 1, note: UInt8(n1), velocity: UInt8(max(1, baseVel - 10)), durationSteps: 62),
            MIDIEvent(stepIndex: barStart + 2, note: UInt8(n2), velocity: UInt8(max(1, baseVel - 20)), durationSteps: 62),
        ]
    }

    // MARK: - Register helper: place pitch class in texture register MIDI 33–59

    private static func texRegisterNote(pc: Int, targetOct: Int) -> Int {
        var midi = targetOct * 12 + pc
        while midi < 33 { midi += 12 }
        while midi > 59 { midi -= 12 }
        return midi
    }
}
