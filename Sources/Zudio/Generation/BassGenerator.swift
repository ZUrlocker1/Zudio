// BassGenerator.swift — generation step 5
//
// Rule catalog:
//   BAS-001: Root Anchor — root beat 1 (long), chord tone beat 3, clean and locked
//   BAS-002: Motorik Drive — 4 quarter notes, staccato, velocity accent on 1+3
//   BAS-003: Crawling Walk — 2-bar root/fifth/approach note pattern
//   BAS-004: Hallogallo Lock — root beat 1 (long), fifth beat 3, locked to kick 1+3 pattern
//   BAS-005: McCartney Drive — 8th-note locked groove derived from SLS verse;
//            bar 1: root-root-m3↓-m3↓-5↓-5↓-m3↓-5↓ descent, bar 2: breathe + pickup
//   BAS-006: LA Woman Sustain — root holds most of bar, chromatic neighbor shimmer at end
//   BAS-007: Hook Ascent — Peter Hook / Joy Division "She's Lost Control";
//            high-register melodic riff: bar 1 hammers the M3 in 8th notes then descends,
//            bar 2 falls to root with m6 color and chromatic pickup
//   BAS-008: Moroder Pulse — Giorgio Moroder "I Feel Love" sequenced staccato 8th notes;
//            root-root-fifth-fifth-b7-b7-root-root; mechanical, relentless, pure chord tones
//   BAS-009: Vitamin Hook — Holger Czukay / CAN "Vitamin C" ascending arpeggio;
//            bar 1 climbs root→fifth→octave with chromatic pass, bar 2 descends with long root breathe
//   BAS-010: Quo Arc — Status Quo "Down Down" 2-bar boogie-woogie arc;
//            bar 1 ascends in paired 8th notes: 1-1-3-3-5-5-6-b7;
//            bar 2 descends: b7-6-5-3-1-1-1-1 back to root.
//            Uses the boogie-woogie scale (1-3-5-6-b7) — b7 always present regardless of chord type.
//   BAS-011: Quo Drive — Status Quo "Caroline" 1-bar compressed boogie arc;
//            full up-and-back arc in one bar: 1-3-5-6-b7-6-5-3.
//            Root-push variant (Paper Plane): 1-1-3-5-6-b7-6-5 — applied on even bars.
//
// All patterns hit beat 1 (step 0) as the primary anchor, matching the kick drum.
// Syncopation is deliberately minimized — Motorik bass is locked and pulse-forward.

struct BassGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let rules:   [String] = ["BAS-001","BAS-002","BAS-003","BAS-004",
                                  "BAS-005","BAS-006","BAS-007","BAS-008","BAS-009",
                                  "BAS-010","BAS-011"]
        let weights: [Double] = [0.10,     0.10,     0.07,     0.10,
                                  0.12,     0.06,     0.11,     0.09,     0.07,
                                  0.10,     0.08]
        let ruleID = rules[rng.weightedPick(weights)]
        usedRuleIDs.insert(ruleID)

        // BAS-005: pre-roll per-4-bar-group flags — ~1/3 chance the phrase is all-drive
        // (bass sits on the descent groove for 4 straight bars instead of alternating breathe bars).
        var mccartney4BarDrive: [Bool] = []
        if ruleID == "BAS-005" {
            let groups = frame.totalBars / 4 + 1
            mccartney4BarDrive = (0..<groups).map { _ in rng.nextDouble() < 0.33 }
        }

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }
            let barStart = bar * 16

            if let introSec = structure.introSection, introSec.contains(bar: bar) {
                events += introBar(bar: bar, introSection: introSec, ruleID: ruleID,
                                   barStart: barStart, entry: entry, frame: frame, rng: &rng,
                                   mccartney4BarDrive: mccartney4BarDrive, style: structure.introStyle)
            } else if let outroSec = structure.outroSection, outroSec.contains(bar: bar) {
                events += outroBar(bar: bar, outroSection: outroSec, ruleID: ruleID,
                                   barStart: barStart, entry: entry, frame: frame, rng: &rng,
                                   mccartney4BarDrive: mccartney4BarDrive, style: structure.outroStyle)
            } else {
                events += bodyBar(ruleID: ruleID, barStart: barStart, bar: bar, entry: entry,
                                  frame: frame, rng: &rng, mccartney4BarDrive: mccartney4BarDrive)
            }
        }

        return events
    }

    // MARK: - Body bar dispatcher

    private static func bodyBar(
        ruleID: String, barStart: Int, bar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, mccartney4BarDrive: [Bool]
    ) -> [MIDIEvent] {
        switch ruleID {
        case "BAS-002": return motorikDriveBar(barStart: barStart, entry: entry, frame: frame)
        case "BAS-003": return crawlingWalkBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "BAS-004": return hallogalloLockBar(barStart: barStart, entry: entry, frame: frame)
        case "BAS-005":
            let allDrive = mccartney4BarDrive[min(bar / 4, mccartney4BarDrive.count - 1)]
            return mccartneyDriveBar(barStart: barStart, bar: bar, entry: entry, frame: frame, allDrive: allDrive)
        case "BAS-006": return laWomanSustainBar(barStart: barStart, entry: entry, frame: frame)
        case "BAS-007": return hookAscentBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "BAS-008": return motoroderPulseBar(barStart: barStart, entry: entry, frame: frame)
        case "BAS-009": return vitaminHookBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "BAS-010": return quoArcBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "BAS-011": return quoDriveBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        default:        return rootAnchorBar(barStart: barStart, entry: entry, frame: frame, rng: &rng)
        }
    }

    // MARK: - Intro bass

    private static func introBar(
        bar: Int, introSection: SongSection, ruleID: String,
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, mccartney4BarDrive: [Bool], style: IntroStyle
    ) -> [MIDIEvent] {
        let offsetBar = bar - introSection.startBar
        let totalBars = introSection.lengthBars

        switch style {
        case .alreadyPlaying:
            // Play the actual bass pattern at reduced velocity, ramping up bar by bar.
            let factor = totalBars <= 1 ? 1.0 :
                0.55 + 0.45 * Double(offsetBar) / Double(totalBars - 1)
            let base = bodyBar(ruleID: ruleID, barStart: barStart, bar: bar, entry: entry,
                               frame: frame, rng: &rng, mccartney4BarDrive: mccartney4BarDrive)
            return scaleVelocity(base, factor: factor)

        case .progressiveEntry:
            // Simplified riff derived from the song's bass rule — signals "something is coming"
            // without playing the actual groove. Ramps 65%→82% so the body arrival is still felt.
            let factor = totalBars <= 1 ? 0.75 :
                0.65 + 0.17 * Double(offsetBar) / Double(totalBars - 1)
            return scaleVelocity(simplifiedIntroBar(ruleID: ruleID, barStart: barStart,
                                                    entry: entry, frame: frame), factor: factor)

        case .coldStart(let drumsOnly):
            // drumsOnly bar 0: drums alone, bass silent — full impact lands on bar 1.
            // All other bars: simplified riff at near-full velocity (the groove arrives at body).
            if drumsOnly && offsetBar == 0 { return [] }
            let factor: Double
            if !drumsOnly && offsetBar == 0 {
                factor = 0.72   // ground the drum pickup without dominating
            } else {
                // Bars 1+ ramp 82%→95% — just below body level so the body still "arrives".
                let playedOffset = drumsOnly ? (offsetBar - 1) : offsetBar
                let playedTotal  = drumsOnly ? max(1, totalBars - 1) : totalBars
                factor = playedTotal <= 1 ? 0.92 :
                    0.82 + 0.13 * Double(playedOffset) / Double(playedTotal - 1)
            }
            return scaleVelocity(simplifiedIntroBar(ruleID: ruleID, barStart: barStart,
                                                    entry: entry, frame: frame), factor: factor)
        }
    }

    // MARK: - Simplified intro riff (derived-from-rule, not the full pattern)
    //
    // For COMPLEX rules: strip back to a recognisable skeleton that signals the groove.
    // For SIMPLE rules (BAS-001/003/004): go in the OPPOSITE direction — add interest
    // with an ascending scale/arpeggio figure so the intro isn't more boring than the body.
    //
    //   BAS-001  Root Anchor       → quarter-note arpeggio: root→3rd→5th→root (hints at chord)
    //   BAS-002  Motorik Drive     → root only, half-time (beats 1+3, long sustain)
    //   BAS-003  Crawling Walk     → ascending quarter notes: root→2nd→3rd→5th
    //   BAS-004  Hallogallo Lock   → 8th-note scale walk root→2nd→3rd then lands on 5th (held)
    //   BAS-005  McCartney Drive   → breathe-bar pattern (bar 2): root sustain + low fifth + approach
    //   BAS-006  LA Woman          → root whole-bar sustain, no chromatic shimmer
    //   BAS-007  Hook Ascent       → root 8th notes (rhythmic signal, melody withheld)
    //   BAS-008  Moroder Pulse     → root only staccato 8ths (omit fifth and b7)
    //   BAS-009  Vitamin Hook      → root on 1, fifth on 3 (omit arpeggio movement)
    //   BAS-010  Quo Arc           → alternating root–third 8th notes (omit fifth, sixth, b7)
    //   BAS-011  Quo Drive         → alternating root–third 8th notes (same stripped feel)

    private static func simplifiedIntroBar(
        ruleID: String, barStart: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root  = chordRootNote(entry: entry, frame: frame)
        let fifth = UInt8(clamped(Int(root) + 7, low: 28, high: 56))

        switch ruleID {

        case "BAS-002":   // Motorik Drive → root only, half-time beats 1+3
            return [
                MIDIEvent(stepIndex: barStart,     note: root, velocity: 82, durationSteps: 7),
                MIDIEvent(stepIndex: barStart + 8, note: root, velocity: 74, durationSteps: 7),
            ]

        case "BAS-003":   // Crawling Walk (simple) → ascending quarter notes root→2nd→3rd→5th
            // Body has root/fifth/approach; intro hints at more by climbing the scale.
            let second3 = UInt8(clamped(Int(root) + frame.mode.nearestInterval(2), low: 28, high: 56))
            let third3  = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 56))
            return [
                MIDIEvent(stepIndex: barStart,      note: root,    velocity: 82, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: second3, velocity: 80, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 8,  note: third3,  velocity: 84, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 12, note: fifth,   velocity: 88, durationSteps: 4),
            ]

        case "BAS-004":   // Hallogallo Lock (simple) → 8th-note scale walk root→2nd→3rd, lands on 5th
            // Body is just root+fifth; intro builds anticipation by walking up to that fifth.
            let second4 = UInt8(clamped(Int(root) + frame.mode.nearestInterval(2), low: 28, high: 56))
            let third4  = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 56))
            return [
                MIDIEvent(stepIndex: barStart,      note: root,    velocity: 84, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 2,  note: second4, velocity: 80, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 4,  note: third4,  velocity: 82, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 6,  note: fifth,   velocity: 88, durationSteps: 10),
            ]

        case "BAS-005":   // McCartney Drive → breathe bar: root sustain + low fifth + approach
            let lowerFifth = UInt8(clamped(Int(root) - 5, low: 28, high: 52))
            let approach   = UInt8(clamped(Int(root) - 2, low: 28, high: 52))
            return [
                MIDIEvent(stepIndex: barStart,      note: root,       velocity: 84, durationSteps: 7),
                MIDIEvent(stepIndex: barStart + 8,  note: lowerFifth, velocity: 74, durationSteps: 5),
                MIDIEvent(stepIndex: barStart + 14, note: approach,   velocity: 60, durationSteps: 2),
            ]

        case "BAS-006":   // LA Woman → root whole-bar, no shimmer
            return [MIDIEvent(stepIndex: barStart, note: root, velocity: 86, durationSteps: 14)]

        case "BAS-007":   // Hook Ascent → root 8th notes (rhythm signal, melody withheld)
            var evs7: [MIDIEvent] = []
            let vels7: [UInt8] = [86, 72, 78, 68, 82, 68, 76, 66]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                evs7.append(MIDIEvent(stepIndex: barStart + step, note: root,
                                      velocity: vels7[i], durationSteps: 2))
            }
            return evs7

        case "BAS-008":   // Moroder Pulse → root only staccato 8ths (omit fifth and b7)
            var evs8: [MIDIEvent] = []
            let vels8: [UInt8] = [90, 74, 80, 70, 84, 70, 80, 72]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                evs8.append(MIDIEvent(stepIndex: barStart + step, note: root,
                                      velocity: vels8[i], durationSteps: 1))
            }
            return evs8

        case "BAS-009":   // Vitamin Hook → root on 1, fifth on 3 (omit arpeggio movement)
            return [
                MIDIEvent(stepIndex: barStart,     note: root,  velocity: 86, durationSteps: 7),
                MIDIEvent(stepIndex: barStart + 8, note: fifth, velocity: 76, durationSteps: 7),
            ]

        case "BAS-010", "BAS-011":   // Quo Arc / Quo Drive → root–third alternating 8ths
            let third = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 62))
            let quoNotes: [UInt8] = [root, third, root, third, root, third, root, third]
            let quoVels:  [UInt8] = [90,   76,    86,   72,    88,   74,    84,   70  ]
            var evsQuo: [MIDIEvent] = []
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                evsQuo.append(MIDIEvent(stepIndex: barStart + step, note: quoNotes[i],
                                        velocity: quoVels[i], durationSteps: 2))
            }
            return evsQuo

        default:   // BAS-001 Root Anchor (simple) → quarter-note chord arpeggio: root→3rd→5th→root
            // Body alternates just two notes; intro hints at the full chord with a short arpeggio.
            let third1 = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 56))
            return [
                MIDIEvent(stepIndex: barStart,      note: root,   velocity: 86, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: third1, velocity: 80, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 8,  note: fifth,  velocity: 86, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 12, note: root,   velocity: 78, durationSteps: 4),
            ]
        }
    }

    // MARK: - Outro bass

    private static func outroBar(
        bar: Int, outroSection: SongSection, ruleID: String,
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, mccartney4BarDrive: [Bool], style: OutroStyle
    ) -> [MIDIEvent] {
        let offsetBar = bar - outroSection.startBar
        let totalBars = outroSection.lengthBars

        switch style {
        case .fade:
            // Actual bass pattern with velocity fading to ~25% by the final bar.
            let factor = totalBars <= 1 ? 0.25 :
                max(0.25, 1.0 - 0.75 * Double(offsetBar) / Double(totalBars - 1))
            let base = bodyBar(ruleID: ruleID, barStart: barStart, bar: bar, entry: entry,
                               frame: frame, rng: &rng, mccartney4BarDrive: mccartney4BarDrive)
            return scaleVelocity(base, factor: factor)

        case .dissolve:
            // Bass plays a simplified anchor in the first half, then drops out — pads hold alone.
            if offsetBar < totalBars / 2 {
                return simplifiedBassBar(barStart: barStart, entry: entry, frame: frame)
            }
            return []  // silent — pads carry the final bars

        case .coldStop:
            // Bass plays body pattern until the final bar; cuts one bar before the drum fill.
            if offsetBar >= totalBars - 1 { return [] }
            return bodyBar(ruleID: ruleID, barStart: barStart, bar: bar, entry: entry,
                           frame: frame, rng: &rng, mccartney4BarDrive: mccartney4BarDrive)
        }
    }

    // MARK: - Simplified bass (root on 1, fifth on 3) — intro/outro anchor

    private static func simplifiedBassBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root  = chordRootNote(entry: entry, frame: frame)
        let fifth = UInt8(clamped(Int(root) + 7, low: 28, high: 56))
        return [
            MIDIEvent(stepIndex: barStart,     note: root,  velocity: 78, durationSteps: 7),
            MIDIEvent(stepIndex: barStart + 8, note: fifth, velocity: 70, durationSteps: 7),
        ]
    }

    // MARK: - Velocity scaling utility

    private static func scaleVelocity(_ events: [MIDIEvent], factor: Double) -> [MIDIEvent] {
        events.map { ev in
            MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                      velocity: UInt8(max(1, min(127, Int(Double(ev.velocity) * factor)))),
                      durationSteps: ev.durationSteps)
        }
    }

    // MARK: - BAS-001: Root Anchor — clean, locked to beat 1 and 3

    private static func rootAnchorBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote = chordRootNote(entry: entry, frame: frame)
        let chordTones = entry.chordWindow.chordTones.sorted()

        events.append(MIDIEvent(stepIndex: barStart, note: rootNote, velocity: 92, durationSteps: 6))

        let beat3Note: UInt8
        if let fifth = chordTones.first(where: { ($0 - (Int(rootNote) % 12) + 12) % 12 == 7 }) {
            beat3Note = noteInBassRegister(pc: fifth, frame: frame)
        } else {
            beat3Note = rootNote
        }
        events.append(MIDIEvent(stepIndex: barStart + 8, note: beat3Note, velocity: 80, durationSteps: 5))
        return events
    }

    // MARK: - BAS-002: Motorik Drive — steady quarter pulse, velocity-accented

    private static func motorikDriveBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote = chordRootNote(entry: entry, frame: frame)
        let velocities: [UInt8] = [96, 70, 88, 68]
        let durations:  [Int]   = [3,  2,  3,  2]
        for beat in 0..<4 {
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: rootNote,
                                    velocity: velocities[beat], durationSteps: durations[beat]))
        }
        return events
    }

    // MARK: - BAS-003: Crawling Walk — 2-bar root/fifth/approach pattern

    private static func crawlingWalkBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote    = chordRootNote(entry: entry, frame: frame)
        let fifthNote   = UInt8(clamped(Int(rootNote) + 7, low: 28, high: 52))
        let approachNote = UInt8(clamped(Int(rootNote) - 2, low: 28, high: 52))

        if bar % 2 == 0 {
            events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,     velocity: 92, durationSteps: 7))
            events.append(MIDIEvent(stepIndex: barStart + 10, note: fifthNote,    velocity: 76, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 15, note: approachNote, velocity: 65, durationSteps: 1))
        } else {
            events.append(MIDIEvent(stepIndex: barStart,     note: rootNote,  velocity: 92, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 5, note: rootNote,  velocity: 78, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 8, note: fifthNote, velocity: 85, durationSteps: 6))
        }
        return events
    }

    // MARK: - BAS-004: Hallogallo Lock — most authentic Motorik bass

    private static func hallogalloLockBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote  = chordRootNote(entry: entry, frame: frame)
        let fifthNote = UInt8(clamped(Int(rootNote) + 7, low: 28, high: 52))
        events.append(MIDIEvent(stepIndex: barStart,     note: rootNote,  velocity: 96, durationSteps: 7))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: fifthNote, velocity: 80, durationSteps: 6))
        return events
    }

    // MARK: - BAS-005: McCartney Drive — 8th-note locked groove from SLS verse

    private static func mccartneyDriveBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, allDrive: Bool = false
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote   = chordRootNote(entry: entry, frame: frame)
        // lowerThird: 3rd interval going down — tracks mode (major 3rd=4 in Ionian, minor 3rd=3 in Aeolian/Dorian)
        let lowerThird = UInt8(clamped(Int(rootNote) - frame.mode.nearestInterval(4), low: 28, high: 52))
        let lowerFifth = UInt8(clamped(Int(rootNote) - 5, low: 28, high: 52))  // P5 down, always mode-neutral
        let approach   = UInt8(clamped(Int(rootNote) - 2, low: 28, high: 52))  // chromatic approach, intentional

        // allDrive: bass "sits on" the descent groove for 4 bars straight (1/3 of phrases).
        // Normal alternation: drive on even bars, breathe on odd bars.
        if allDrive || bar % 2 == 0 {
            let pitches: [UInt8] = [rootNote, rootNote, lowerThird, lowerThird,
                                    lowerFifth, lowerFifth, lowerThird, lowerFifth]
            let vels:    [UInt8] = [92, 84, 78, 74, 82, 76, 72, 68]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
        } else {
            events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,   velocity: 92, durationSteps: 7))
            events.append(MIDIEvent(stepIndex: barStart + 8,  note: lowerFifth, velocity: 82, durationSteps: 5))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: approach,   velocity: 65, durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-006: LA Woman Sustain — long root hold with chromatic shimmer at bar end

    private static func laWomanSustainBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote      = chordRootNote(entry: entry, frame: frame)
        let upperNeighbor = UInt8(clamped(Int(rootNote) + 1, low: 28, high: 52))
        events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,      velocity: 90, durationSteps: 11))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: rootNote,      velocity: 76, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 13, note: upperNeighbor, velocity: 68, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 14, note: rootNote,      velocity: 72, durationSteps: 2))
        return events
    }

    // MARK: - BAS-007: Hook Ascent — Peter Hook / Joy Division "She's Lost Control"
    // Melodic riff in standard bass register, 2-bar pattern.
    // Bar 1 (drive): 8 eighth-note attacks, hammering the mode 3rd, descending tail 3rd→2nd.
    // Bar 2 (descent): steps down from 3rd through 2nd to root, lands on mode 6th, chromatic pickup.
    // All scale degrees (3rd, 2nd, 6th) snap to the song's mode — minor songs get minor 3rd etc.

    private static func hookAscentBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root   = chordRootNote(entry: entry, frame: frame)
        let third  = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 36, high: 60))  // mode 3rd
        let second = UInt8(clamped(Int(root) + frame.mode.nearestInterval(2), low: 36, high: 60))  // mode 2nd
        let sixth  = UInt8(clamped(Int(root) + frame.mode.nearestInterval(9), low: 36, high: 60))  // mode 6th

        if bar % 2 == 0 {
            // Drive bar: six M3 hits, step down to M2, return to M3 (descending tail)
            let pitches: [UInt8] = [third, third, third, third, third, third, second, third]
            let vels:    [UInt8] = [90, 86, 84, 80, 80, 78, 76, 74]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
        } else {
            // Descent bar: M3 → M2 → M3 → root (long) → m6 → root pickup
            events.append(MIDIEvent(stepIndex: barStart,      note: third,  velocity: 88, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 4,  note: second, velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 6,  note: third,  velocity: 76, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 8,  note: root,   velocity: 82, durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 12, note: sixth,  velocity: 72, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: root,   velocity: 68, durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-008: Moroder Pulse — Giorgio Moroder "I Feel Love" sequenced staccato 8ths
    // Mechanical 8th-note ostinato: root-root-fifth-fifth-b7-b7-root-root.
    // All notes staccato (dur 1). The b7 pair gives a dominant-7th / Mixolydian colour;
    // in major chord context, the b7 slots are replaced with root to stay diatonic.
    // The wrap-around (steps 12-14 repeat root) creates subtle 6-against-8 metric displacement.

    private static func motoroderPulseBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root  = chordRootNote(entry: entry, frame: frame)
        let fifth = UInt8(clamped(Int(root) + 7, low: 28, high: 52))
        // b7 only in minor/Dorian/Mixolydian chord contexts; stay on root in pure major
        let isMajorContext: Bool
        switch entry.chordWindow.chordType {
        case .major, .sus2, .sus4, .add9: isMajorContext = true
        default:                          isMajorContext = false
        }
        let flatSeven = isMajorContext ? root : UInt8(clamped(Int(root) + 10, low: 28, high: 52))

        let pitches: [UInt8] = [root, root, fifth, fifth, flatSeven, flatSeven, root, root]
        let vels:    [UInt8] = [92,   80,   84,    78,    84,        78,        82,   76  ]
        for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                    velocity: vels[i], durationSteps: 1))
        }
        return events
    }

    // MARK: - BAS-009: Vitamin Hook — Holger Czukay / CAN "Vitamin C" ascending arpeggio
    // 2-bar rolling arpeggio spanning root→fifth→octave with chromatic passing tones.
    // Bar 1 (ascent): root×2 drive, fifth, tritone passing note, octave arrival, m3 colour, fifth tail.
    // Bar 2 (descent): octave→fifth→root (long breathe), minor-6th upper neighbour, fifth, root pickup.
    // Source: Ege Bamyasi (1972) — Czukay's signature ascending string-crossing arpeggiation.

    private static func vitaminHookBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root       = chordRootNote(entry: entry, frame: frame)
        let fifth      = UInt8(clamped(Int(root) + 7,  low: 28, high: 56))
        let octave     = UInt8(clamped(Int(root) + 12, low: 28, high: 56))  // wide range for arpeggio
        let minorThird = UInt8(clamped(Int(root) + 3,  low: 28, high: 56))  // b3 Dorian colour
        let tritPass   = UInt8(clamped(Int(root) + 6,  low: 28, high: 56))  // passing between 5th and octave
        let upperNeigh = UInt8(clamped(Int(root) + 8,  low: 28, high: 56))  // m6 upper neighbour of 5th

        if bar % 2 == 0 {
            // Ascent bar: root pump → fifth → chromatic pass → octave arrival → m3 colour → fifth tail
            events.append(MIDIEvent(stepIndex: barStart,      note: root,       velocity: 90, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 2,  note: root,       velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 4,  note: fifth,      velocity: 86, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 7,  note: tritPass,   velocity: 72, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 8,  note: octave,     velocity: 88, durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 12, note: minorThird, velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: fifth,      velocity: 72, durationSteps: 2))
        } else {
            // Descent bar: octave → fifth → long root breathe → m6 upper neighbour → fifth → root pickup
            events.append(MIDIEvent(stepIndex: barStart,      note: octave,     velocity: 86, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 2,  note: fifth,      velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 4,  note: root,       velocity: 90, durationSteps: 6))
            events.append(MIDIEvent(stepIndex: barStart + 10, note: upperNeigh, velocity: 70, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 12, note: fifth,      velocity: 76, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: root,       velocity: 68, durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-010: Quo Arc — Status Quo "Down Down" 2-bar boogie-woogie arc
    // Boogie-woogie scale: 1, 3, 5, 6, b7 (major 3rd and b7 always used — the blues/boogie colour).
    // Bar 1 (even, ascent): paired 8th notes climbing 1-1-3-3-5-5-6-b7.
    //   The pairs give a "pumping" double-hit feel — root and root, 3rd and 3rd, etc.
    //   b7 marks the arc apex on beat 4 with a solo hit (no pair), creating forward lean.
    // Bar 2 (odd, descent): b7-6-5-3-1-1-1-1 — falls back to root, which is then held
    //   as four repeated 8th notes, locking to the kick on the next downbeat.
    // Source: Alan Lancaster / Status Quo, "Down Down" (1974).

    private static func quoArcBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root  = chordRootNote(entry: entry, frame: frame)
        let third = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 62))  // mode 3rd
        let fifth = UInt8(clamped(Int(root) + 7,  low: 28, high: 62))  // P5, mode-neutral
        let sixth = UInt8(clamped(Int(root) + frame.mode.nearestInterval(9), low: 28, high: 62))  // mode 6th
        let flatSeven = UInt8(clamped(Int(root) + 10, low: 28, high: 62))  // b7 boogie apex — intentional chromatic

        if bar % 2 == 0 {
            // Ascent bar: 1-1-3-3-5-5-6-b7 (paired doubles, solo b7 at beat 4)
            let pitches: [UInt8] = [root, root, third, third, fifth, fifth, sixth, flatSeven]
            let vels:    [UInt8] = [92,   82,   80,    76,    88,    80,    78,    76]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
        } else {
            // Descent bar: b7-6-5-3-1-1-1-1 (falls to root, then root holds for locking)
            let pitches: [UInt8] = [flatSeven, sixth, fifth, third, root, root, root, root]
            let vels:    [UInt8] = [88,        80,    78,    76,    86,   80,   76,   72]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
        }
        return events
    }

    // MARK: - BAS-011: Quo Drive — Status Quo "Caroline"/"Paper Plane" 1-bar boogie arc
    // Full up-and-back arc compressed into a single bar — all 8 8th-note slots.
    // Even bars use the "Paper Plane" root-push variant: 1-1-3-5-6-b7-6-5.
    //   The double root at steps 0-2 gives a punchy launch before climbing.
    // Odd bars use the "Caroline" full-arc variant: 1-3-5-6-b7-6-5-3.
    //   Symmetric up-and-back — every note in the boogie-woogie scale visited once.
    // Both variants sit within a single bar, making this a dense, relentless driver.
    // Source: Alan Lancaster / Status Quo, "Caroline" (1973), "Paper Plane" (1972).

    private static func quoDriveBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root      = chordRootNote(entry: entry, frame: frame)
        let third     = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 62))  // mode 3rd
        let fifth     = UInt8(clamped(Int(root) + 7,  low: 28, high: 62))  // P5, mode-neutral
        let sixth     = UInt8(clamped(Int(root) + frame.mode.nearestInterval(9), low: 28, high: 62))  // mode 6th
        let flatSeven = UInt8(clamped(Int(root) + 10, low: 28, high: 62))  // b7 boogie apex — intentional chromatic

        let pitches: [UInt8]
        let vels:    [UInt8]

        if bar % 2 == 0 {
            // Paper Plane root-push: 1-1-3-5-6-b7-6-5 (double root, then climb, partial descent)
            pitches = [root, root, third, fifth, sixth, flatSeven, sixth, fifth]
            vels    = [92,   82,   80,    78,    86,    80,        78,    74]
        } else {
            // Caroline full arc: 1-3-5-6-b7-6-5-3 (complete up-and-back in one bar)
            pitches = [root, third, fifth, sixth, flatSeven, sixth, fifth, third]
            vels    = [92,   82,    80,    78,    88,        80,    78,    74]
        }

        for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                    velocity: vels[i], durationSteps: 2))
        }
        return events
    }

    // MARK: - Note helpers

    private static func chordRootNote(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> UInt8 {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let raw = 12 + 2 * 12 + rootPC  // octave 3 (MIDI 36-47)
        return UInt8(clamped(raw, low: 28, high: 52))
    }

    private static func noteInBassRegister(pc: Int, frame: GlobalMusicalFrame) -> UInt8 {
        for oct in 2...4 {
            let midi = oct * 12 + pc
            if midi >= 28 && midi <= 52 { return UInt8(midi) }
        }
        return 36
    }

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        max(low, min(high, v))
    }

}
