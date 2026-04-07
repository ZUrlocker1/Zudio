// ChillDrumGenerator.swift — Chill generation step 3
// Three beat styles:
//   electronic  — syncopated 808/standard kit, 2–4 events/bar (Deep/Dream)
//   neoSoul     — programmed ghost-note kit, 5–9 events/bar (Bright/Free)
//   brushKit    — acoustic brushed jazz kit, 3–5 events/bar (Bright/Free)
// Breakdown: kick step 1 only for first 4 bars, then sparse ride/hat returns.

import Foundation

struct ChillDrumGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        beatStyle: ChillBeatStyle,
        breakdownStyle: ChillBreakdownStyle,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        fillBars: inout [Int]
    ) -> [MIDIEvent] {
        switch beatStyle {
        case .electronic:
            usedRuleIDs.insert("CHL-DRUM-001")
            return electronic(frame: frame, structure: structure, breakdownStyle: breakdownStyle, rng: &rng)
        case .neoSoul:
            usedRuleIDs.insert("CHL-DRUM-002")
            return neoSoul(frame: frame, structure: structure, breakdownStyle: breakdownStyle, rng: &rng)
        case .brushKit:
            usedRuleIDs.insert("CHL-DRUM-003")
            return brushKit(frame: frame, structure: structure, breakdownStyle: breakdownStyle, rng: &rng)
        case .stGermain:
            usedRuleIDs.insert("CHL-DRUM-004")
            return stGermainGroove(frame: frame, structure: structure,
                                   breakdownStyle: breakdownStyle, rng: &rng, fillBars: &fillBars)
        case .hipHopJazz:
            usedRuleIDs.insert("CHL-DRUM-005")
            return hipHopJazz(frame: frame, structure: structure, breakdownStyle: breakdownStyle, rng: &rng)
        }
    }

    // MARK: - Cold start / cold stop helpers

    /// Cold start pickup fill for Chill — jazz-appropriate (snare roll or ride+snare launch).
    /// `fromStep` 4 = 3-beat fill (steps 4–15), `fromStep` 8 = 2-beat fill (steps 8–15).
    private static func chillColdStartPickup(barStart: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let fromStep = rng.nextDouble() < 0.50 ? 8 : 4   // 2-beat or 3-beat
        let variant  = rng.nextInt(upperBound: 3)
        var events: [MIDIEvent] = []

        switch variant {
        case 0:  // Snare roll — 6 escalating hits, ending with crash+snare
            let steps = [8, 10, 11, 12, 13, 14, 15].filter { $0 >= fromStep }
            let vels: [UInt8] = [45, 52, 60, 68, 78, 90, 100]
            for (i, step) in steps.enumerated() {
                let vi = i + (7 - steps.count)
                events.append(MIDIEvent(stepIndex: barStart + step,
                                        note: GMDrum.snare.rawValue,
                                        velocity: vels[Swift.min(vi, 6)], durationSteps: 1))
            }
            events.append(MIDIEvent(stepIndex: barStart + 15, note: GMDrum.crash1.rawValue,
                                    velocity: 100, durationSteps: 1))

        case 1:  // Ride groove launch — ride 8ths + snare on 2 and 4
            for step in stride(from: fromStep, to: 16, by: 2) {
                let vel = UInt8(45 + (step - fromStep) * 3)
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.ride.rawValue,
                                        velocity: vel, durationSteps: 1))
            }
            for step in [4, 8, 12].filter({ $0 >= fromStep }) {
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.snare.rawValue,
                                        velocity: UInt8(55 + rng.nextInt(upperBound: 15)), durationSteps: 1))
            }
            events.append(MIDIEvent(stepIndex: barStart + 15, note: GMDrum.crash1.rawValue,
                                    velocity: 95, durationSteps: 1))

        default:  // Sidestick + snare build — sidestick ghost then strong snare landing
            for step in [4, 6, 8, 10].filter({ $0 >= fromStep }) {
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.sidestick.rawValue,
                                        velocity: UInt8(40 + rng.nextInt(upperBound: 20)), durationSteps: 1))
            }
            events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue,
                                    velocity: 82, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.snare.rawValue,
                                    velocity: 92, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 15, note: GMDrum.crash1.rawValue,
                                    velocity: 100, durationSteps: 1))
        }
        return events
    }

    /// Cold stop: 1-beat snare roll on steps 12–15 (used in penultimate outro bar).
    private static func chillColdStopFill(barStart: Int) -> [MIDIEvent] {
        return [
            MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 60, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 13, note: GMDrum.snare.rawValue, velocity: 72, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 14, note: GMDrum.snare.rawValue, velocity: 86, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 15, note: GMDrum.snare.rawValue, velocity: 100, durationSteps: 1),
        ]
    }

    // MARK: - Electronic (Deep/Dream) — Mobyesque Minimal

    /// CHL-DRUM-001: 2–4 events/bar max. Kick step 1 always; snare 2+4; hi-hat off-beats sparse.
    /// Velocity ceiling 80 (restrained — Mobyesque Darcy never exceeded 82).
    private static func electronic(frame: GlobalMusicalFrame, structure: SongStructure,
                                    breakdownStyle: ChillBreakdownStyle,
                                    rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let kick  = GMDrum.kick.rawValue
        let snare = GMDrum.snare.rawValue
        let hat   = GMDrum.closedHat.rawValue
        let fillOpt = rng.nextInt(upperBound: 3)   // A/B/C fill used across all breakdown styles

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let isBreakdown = section?.label == .bridge
            let isIntro     = section?.label == .intro
            let isOutro     = section?.label == .outro
            let base = bar * 16

            // Cold start: bar 0 is a jazz pickup fill — other instruments are silent this bar
            if case .coldStart = structure.introStyle, bar == 0 {
                events += chillColdStartPickup(barStart: base, rng: &rng)
                continue
            }

            // Cold stop: final bar is crash+kick only; penultimate bar gets normal generation then 1-beat fill
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar == outroEnd - 1 {
                    events.append(MIDIEvent(stepIndex: base, note: GMDrum.crash1.rawValue, velocity: 110, durationSteps: 1))
                    events.append(MIDIEvent(stepIndex: base, note: GMDrum.kick.rawValue,   velocity: 105, durationSteps: 1))
                    continue
                }
            }

            var isColdStopPenultimate = false
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar, bar == outroEnd - 2 {
                isColdStopPenultimate = true
            }

            if isBreakdown {
                let breakdownBar = bar - (section?.startBar ?? bar)
                let sectionLen   = section?.lengthBars ?? 4
                let isLastBDBar  = (breakdownBar == sectionLen - 1)
                switch breakdownStyle {
                case .stopTime:
                    // Even bars: unison hit on beat 1; odd bars: 2–3 beat fill
                    if breakdownBar % 2 == 0 {
                        events.append(MIDIEvent(stepIndex: base, note: kick,  velocity: 90, durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: base, note: snare, velocity: 85, durationSteps: 1))
                    } else {
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    }
                case .bassOstinato:
                    if isLastBDBar {
                        // Last bar: kick on beat 1 then 3-beat momentum fill into groove return
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    } else {
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: UInt8(55 + rng.nextInt(upperBound: 11)), durationSteps: 1))
                        for step in stride(from: 0, to: 16, by: 2) {
                            let vel = UInt8(32 + rng.nextInt(upperBound: 12))
                            events.append(MIDIEvent(stepIndex: base + step, note: hat, velocity: vel, durationSteps: 1))
                        }
                        if rng.nextDouble() < 0.40 {
                            events.append(MIDIEvent(stepIndex: base + 8, note: snare, velocity: UInt8(35 + rng.nextInt(upperBound: 15)), durationSteps: 1))
                        }
                    }
                case .harmonicDrone:
                    if isLastBDBar {
                        // Last bar: kick on beat 1 then 3-beat momentum fill into groove return
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    } else if breakdownBar < 2 {
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 55, durationSteps: 1))
                    } else if rng.nextDouble() < 0.40 {
                        let vel = UInt8(30 + rng.nextInt(upperBound: 15))
                        events.append(MIDIEvent(stepIndex: base + 2, note: hat, velocity: vel, durationSteps: 1))
                    }
                }
                continue
            }

            // Kick: step 1 always; step 9 (beat 3) 40% prob
            let kickVel: UInt8 = isIntro ? 50 : UInt8(65 + rng.nextInt(upperBound: 16))
            events.append(MIDIEvent(stepIndex: base, note: kick, velocity: kickVel, durationSteps: 1))
            if !isIntro && !isOutro, rng.nextDouble() < 0.40 {
                let vel2 = UInt8(55 + rng.nextInt(upperBound: 16))
                events.append(MIDIEvent(stepIndex: base + 8, note: kick, velocity: vel2, durationSteps: 1))
            }

            // Snare: step 5 (beat 2) 60% prob; step 13 (beat 4) 85% prob
            if rng.nextDouble() < (isIntro ? 0.30 : 0.60) {
                let vel = UInt8(55 + rng.nextInt(upperBound: 16))
                events.append(MIDIEvent(stepIndex: base + 4, note: snare, velocity: vel, durationSteps: 1))
            }
            if rng.nextDouble() < (isIntro ? 0.50 : 0.85) {
                let vel = UInt8(60 + rng.nextInt(upperBound: 16))
                events.append(MIDIEvent(stepIndex: base + 12, note: snare, velocity: vel, durationSteps: 1))
            }

            // Hi-hat: 8th-note off-beats (steps 2,6,10,14) at 50% each, vel 40–55
            for step in [2, 6, 10, 14] {
                if rng.nextDouble() < 0.50 {
                    let vel = UInt8(40 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: base + step, note: hat, velocity: vel, durationSteps: 1))
                }
            }

            if isColdStopPenultimate {
                events = events.filter { $0.stepIndex < base + 12 }
                events += chillColdStopFill(barStart: base)
            }
        }
        return events
    }

    // MARK: - Neo Soul (Bright/Free) — Bosa Moon model

    /// CHL-DRUM-002: 5–9 events/bar. Syncopated kick, ghost-note snare, variable hi-hat.
    private static func neoSoul(frame: GlobalMusicalFrame, structure: SongStructure,
                                 breakdownStyle: ChillBreakdownStyle,
                                 rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let kick    = GMDrum.kick.rawValue
        let snare   = GMDrum.snare.rawValue    // acoustic snare (note 38) — maps correctly on both standard and brush kits
        let ghost   = GMDrum.snare.rawValue    // acoustic snare for ghost notes
        let hat16   = GMDrum.closedHat.rawValue
        let crash   = GMDrum.crash1.rawValue
        let fillOpt = rng.nextInt(upperBound: 3)   // A/B/C fill used across all breakdown styles

        // Track section-start bars for crash
        let sectionStartBars = Set(structure.sections.map { $0.startBar })

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let isBreakdown = section?.label == .bridge
            let isIntro     = section?.label == .intro
            let base = bar * 16

            // Cold start: bar 0 is a jazz pickup fill — other instruments are silent this bar
            if case .coldStart = structure.introStyle, bar == 0 {
                events += chillColdStartPickup(barStart: base, rng: &rng)
                continue
            }

            // Cold stop: final bar is crash+kick only; penultimate bar gets normal generation then 1-beat fill
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar == outroEnd - 1 {
                    events.append(MIDIEvent(stepIndex: base, note: GMDrum.crash1.rawValue, velocity: 110, durationSteps: 1))
                    events.append(MIDIEvent(stepIndex: base, note: GMDrum.kick.rawValue,   velocity: 105, durationSteps: 1))
                    continue
                }
            }

            var isColdStopPenultimate = false
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar, bar == outroEnd - 2 {
                isColdStopPenultimate = true
            }

            if isBreakdown {
                let breakdownBar = bar - (section?.startBar ?? bar)
                let sectionLen   = section?.lengthBars ?? 4
                let isLastBDBar  = (breakdownBar == sectionLen - 1)
                switch breakdownStyle {
                case .stopTime:
                    if breakdownBar % 2 == 0 {
                        events.append(MIDIEvent(stepIndex: base, note: kick,  velocity: 90, durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: base, note: snare, velocity: 85, durationSteps: 1))
                    } else {
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat16, rng: &rng)
                    }
                case .bassOstinato:
                    if isLastBDBar {
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat16, rng: &rng)
                    } else {
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: UInt8(58 + rng.nextInt(upperBound: 12)), durationSteps: 1))
                        for step in stride(from: 0, to: 16, by: 2) {
                            let vel = UInt8(32 + rng.nextInt(upperBound: 12))
                            events.append(MIDIEvent(stepIndex: base + step, note: hat16, velocity: vel, durationSteps: 1))
                        }
                        if rng.nextDouble() < 0.40 {
                            events.append(MIDIEvent(stepIndex: base + 8, note: ghost, velocity: UInt8(35 + rng.nextInt(upperBound: 15)), durationSteps: 1))
                        }
                    }
                case .harmonicDrone:
                    if isLastBDBar {
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat16, rng: &rng)
                    } else if breakdownBar < 2 {
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 60, durationSteps: 1))
                    } else if rng.nextDouble() < 0.50 {
                        let vel = UInt8(40 + rng.nextInt(upperBound: 20))
                        events.append(MIDIEvent(stepIndex: base + 2, note: hat16, velocity: vel, durationSteps: 1))
                    }
                }
                continue
            }

            // Crash on section starts (groove sections only)
            if sectionStartBars.contains(bar) && (section?.label == .A || section?.label == .B) {
                events.append(MIDIEvent(stepIndex: base, note: crash, velocity: 95, durationSteps: 2))
            }

            // Kick: step 1 always; step 3 (AND of beat 1) 30% prob
            let kickVel: UInt8 = isIntro ? 60 : UInt8(88 + rng.nextInt(upperBound: 8))
            events.append(MIDIEvent(stepIndex: base, note: kick, velocity: kickVel, durationSteps: 1))
            if !isIntro, rng.nextDouble() < 0.30 {
                events.append(MIDIEvent(stepIndex: base + 2, note: kick, velocity: UInt8(60 + rng.nextInt(upperBound: 11)), durationSteps: 1))
            }

            // Snare: step 3 (primary, beat 1.5) 85% prob; step 13 (beat 4) 85% prob
            if rng.nextDouble() < (isIntro ? 0.40 : 0.85) {
                let vel = UInt8(80 + rng.nextInt(upperBound: 11))
                events.append(MIDIEvent(stepIndex: base + 2, note: snare, velocity: vel, durationSteps: 1))
            }
            if rng.nextDouble() < (isIntro ? 0.60 : 0.85) {
                let vel = UInt8(75 + rng.nextInt(upperBound: 11))
                events.append(MIDIEvent(stepIndex: base + 12, note: snare, velocity: vel, durationSteps: 1))
            }

            // Hi-hat 16ths: each 16th position 65% prob, vel 50–65
            for step in stride(from: 0, to: 16, by: 1) {
                if rng.nextDouble() < 0.65 {
                    let vel = UInt8(50 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: base + step, note: hat16, velocity: vel, durationSteps: 1))
                }
            }

            // Ghost snare: steps 4, 8, 12 at 30% each, vel 30–45
            for step in [4, 8, 12] {
                if rng.nextDouble() < 0.30 {
                    let vel = UInt8(30 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: base + step, note: ghost, velocity: vel, durationSteps: 1))
                }
            }

            if isColdStopPenultimate {
                events = events.filter { $0.stepIndex < base + 12 }
                events += chillColdStopFill(barStart: base)
            }
        }
        return events
    }

    // MARK: - St Germain Groove (Bright/Free) — CHL-DRUM-004

    /// CHL-DRUM-004: Four-on-the-floor kick + backbeat snare + 8th-note ride, inspired by
    /// St Germain "So Flute" (118 BPM). Kick on every beat; snare on 2+4; ride on all 8th notes.
    /// Ride variation in 4–8 bar blocks (always 8th notes, four texture modes):
    ///   - Normal: steady 8ths, uniform velocity
    ///   - Swell: 8ths with velocity rising across the bar (75% → 95%) — builds energy
    ///   - Sparse: 8ths drop the off-beats of 2+4 (steps 6,14 omitted) — opens up the feel
    ///   - Hat layer: 8ths on ride + closed hi-hat on the AND of beats 1+3 (steps 2,10)
    /// Fills: ~1 per 16 bars — snare roll or snare accent.
    private static func stGermainGroove(frame: GlobalMusicalFrame, structure: SongStructure,
                                         breakdownStyle: ChillBreakdownStyle,
                                         rng: inout SeededRNG, fillBars: inout [Int]) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let kick  = GMDrum.kick.rawValue
        let snare = GMDrum.snare.rawValue
        let ride  = GMDrum.ride.rawValue
        let hat   = GMDrum.closedHat.rawValue

        // Ride texture mode schedule: 4–8 bar blocks cycling through Normal/Swell/Sparse/Hat
        // 0=Normal, 1=Swell, 2=Sparse, 3=HatLayer
        enum RideMode { case normal, swell, sparse, hat }
        var rideModeSchedule = [RideMode](repeating: .normal, count: frame.totalBars)
        var schedBar = 0
        var currentMode: RideMode = .normal
        while schedBar < frame.totalBars {
            let blockLen = 4 + rng.nextInt(upperBound: 5)
            for b in schedBar..<min(schedBar + blockLen, frame.totalBars) {
                rideModeSchedule[b] = currentMode
            }
            schedBar += blockLen
            // Transition: Normal ↔ Swell ↔ Hat ↔ Sparse, biased back toward Normal
            let roll = rng.nextDouble()
            currentMode = roll < 0.50 ? .normal
                        : roll < 0.70 ? .swell
                        : roll < 0.85 ? .hat
                        :               .sparse
        }

        // Fill probability: ~1 fill per 16 bars
        let fillProb = 1.0 / 16.0

        // Find the bar where the first groove section starts (for velocity ramp-in)
        let grooveStartBar = structure.sections.first { $0.label == .A || $0.label == .B }?.startBar ?? 0
        let rampBars = 4  // ramp velocities up over this many bars after intro ends
        let fillOpt = rng.nextInt(upperBound: 3)   // A/B/C fill used across all breakdown styles

        for bar in 0..<frame.totalBars {
            let section     = structure.section(atBar: bar)
            let isBreakdown = section?.label == .bridge
            let isIntro     = section?.label == .intro
            let base        = bar * 16

            // Cold start: bar 0 is a jazz pickup fill — other instruments are silent this bar
            if case .coldStart = structure.introStyle, bar == 0 {
                events += chillColdStartPickup(barStart: base, rng: &rng)
                continue
            }

            // Cold stop: final bar is crash+kick only; penultimate bar gets normal generation then 1-beat fill
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar == outroEnd - 1 {
                    events.append(MIDIEvent(stepIndex: base, note: GMDrum.crash1.rawValue, velocity: 110, durationSteps: 1))
                    events.append(MIDIEvent(stepIndex: base, note: GMDrum.kick.rawValue,   velocity: 105, durationSteps: 1))
                    continue
                }
            }

            var isColdStopPenultimate = false
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar, bar == outroEnd - 2 {
                isColdStopPenultimate = true
            }

            // Ramp factor: 0.0 at grooveStartBar, 1.0 at grooveStartBar+rampBars
            let rampFactor: Double
            if bar < grooveStartBar {
                rampFactor = 0.0
            } else if bar < grooveStartBar + rampBars {
                rampFactor = Double(bar - grooveStartBar) / Double(rampBars)
            } else {
                rampFactor = 1.0
            }

            if isBreakdown {
                let breakdownBar = bar - (section?.startBar ?? bar)
                let sectionLen   = section?.lengthBars ?? 4
                let isLastBDBar  = (breakdownBar == sectionLen - 1)
                switch breakdownStyle {
                case .harmonicDrone:
                    if isLastBDBar {
                        // Last bar: kick on beat 1 then 3-beat momentum fill into groove return
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    } else {
                        // Beat continues at full density, slightly reduced velocity — lead plays over it
                        let dVel = UInt8(62 + rng.nextInt(upperBound: 12))
                        for step in [0, 4, 8, 12] {
                            events.append(MIDIEvent(stepIndex: base + step, note: kick, velocity: dVel, durationSteps: 1))
                        }
                        let snareVel = UInt8(55 + rng.nextInt(upperBound: 10))
                        events.append(MIDIEvent(stepIndex: base + 4,  note: snare, velocity: snareVel, durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: base + 12, note: snare, velocity: snareVel, durationSteps: 1))
                        let rideVel = UInt8(45 + rng.nextInt(upperBound: 12))
                        for step in stride(from: 0, to: 16, by: 2) {
                            events.append(MIDIEvent(stepIndex: base + step, note: ride, velocity: rideVel, durationSteps: 1))
                        }
                    }
                case .stopTime:
                    // Even bars: unison kick+snare hit on beat 1; odd bars: momentum fill
                    if breakdownBar % 2 == 0 {
                        events.append(MIDIEvent(stepIndex: base, note: kick,  velocity: 92, durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: base, note: snare, velocity: 88, durationSteps: 1))
                    } else {
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    }
                case .bassOstinato:
                    if isLastBDBar {
                        // Last bar: kick on beat 1 then 3-beat momentum fill into groove return
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    } else {
                        // Ride on all 4 beats (time reference) + kick on beat 1 + snare on beat 3 (50%)
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: UInt8(55 + rng.nextInt(upperBound: 12)), durationSteps: 1))
                        for step in [0, 4, 8, 12] {
                            let vel = UInt8(32 + rng.nextInt(upperBound: 16))
                            events.append(MIDIEvent(stepIndex: base + step, note: ride, velocity: vel, durationSteps: 1))
                        }
                        if rng.nextDouble() < 0.50 {
                            events.append(MIDIEvent(stepIndex: base + 8, note: snare, velocity: UInt8(42 + rng.nextInt(upperBound: 14)), durationSteps: 1))
                        }
                    }
                }
                continue
            }

            // Velocity ramp helper: interpolates intro vel → full groove vel over rampBars
            func rampVel(introVel: Int, grooveVel: Int) -> UInt8 {
                let v = Double(introVel) + rampFactor * Double(grooveVel - introVel)
                return UInt8(Swift.max(30, Swift.min(127, Int(v.rounded()) + rng.nextInt(upperBound: 8) - 4)))
            }

            // Kick: every beat (0, 4, 8, 12)
            let kickVel = isIntro ? 55 : rampVel(introVel: 55, grooveVel: 85)
            for step in [0, 4, 8, 12] {
                events.append(MIDIEvent(stepIndex: base + step, note: kick,
                                        velocity: kickVel, durationSteps: 1))
            }

            // Fill or normal snare (no fills during ramp-in)
            let isFillBar = !isIntro && rampFactor >= 1.0 && rng.nextDouble() < fillProb
            if isFillBar {
                let vel2 = UInt8(78 + rng.nextInt(upperBound: 12))
                events.append(MIDIEvent(stepIndex: base + 4, note: snare, velocity: vel2, durationSteps: 1))
                if rng.nextDouble() < 0.60 {
                    // Snare roll: escalating 16ths at steps 8, 10, 12, 13, 14, 15
                    fillBars.append(bar)
                    let rollVels: [UInt8] = [55, 62, 70, 78, 88, 98]
                    for (i, step) in [8, 10, 12, 13, 14, 15].enumerated() {
                        events.append(MIDIEvent(stepIndex: base + step, note: snare,
                                                velocity: rollVels[i], durationSteps: 1))
                    }
                } else {
                    // Snare accent: beat 4 + sharp 16th before next bar
                    events.append(MIDIEvent(stepIndex: base + 12, note: snare,
                                            velocity: UInt8(82 + rng.nextInt(upperBound: 10)), durationSteps: 1))
                    events.append(MIDIEvent(stepIndex: base + 15, note: snare,
                                            velocity: UInt8(92 + rng.nextInt(upperBound: 8)),  durationSteps: 1))
                }
            } else {
                let snareVel = isIntro ? rampVel(introVel: 60, grooveVel: 60)
                                       : rampVel(introVel: 60, grooveVel: 83)
                events.append(MIDIEvent(stepIndex: base + 4,  note: snare, velocity: snareVel, durationSteps: 1))
                events.append(MIDIEvent(stepIndex: base + 12, note: snare, velocity: snareVel, durationSteps: 1))
            }

            // Ride: always 8th notes; texture varies by mode
            let mode = isIntro ? RideMode.normal : rideModeSchedule[bar]
            let baseRideVel = isIntro ? 45 : Int(45.0 + rampFactor * 23.0)  // 45→68 over ramp
            // Steps to omit in sparse mode (off-beats of beats 2 and 4)
            let sparseOmit: Set<Int> = [6, 14]

            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                if mode == .sparse && sparseOmit.contains(step) { continue }
                let vel: UInt8
                switch mode {
                case .normal:
                    vel = UInt8(baseRideVel + rng.nextInt(upperBound: 15))
                case .swell:
                    // Velocity rises across the bar: ~72 at start, ~92 at end
                    vel = UInt8(baseRideVel + i * 3 + rng.nextInt(upperBound: 8))
                case .sparse:
                    vel = UInt8(baseRideVel + rng.nextInt(upperBound: 15))
                case .hat:
                    vel = UInt8(baseRideVel + rng.nextInt(upperBound: 12))
                }
                events.append(MIDIEvent(stepIndex: base + step, note: ride,
                                        velocity: Swift.min(vel, 95), durationSteps: 1))
            }

            // Hat layer mode: add closed hi-hat on AND of beats 1 and 3 (steps 2, 10)
            if mode == .hat {
                for step in [2, 10] {
                    let vel = UInt8(50 + rng.nextInt(upperBound: 20))
                    events.append(MIDIEvent(stepIndex: base + step, note: hat,
                                            velocity: vel, durationSteps: 1))
                }
            }

            if isColdStopPenultimate {
                events = events.filter { $0.stepIndex < base + 12 }
                events += chillColdStopFill(barStart: base)
            }
        }
        return events
    }

    // MARK: - Brush Kit (Bright/Free)

    /// CHL-DRUM-003: 3–5 events/bar. Ride quarter-note pulse; snare brush 2+4; minimal kick.
    private static func brushKit(frame: GlobalMusicalFrame, structure: SongStructure,
                                  breakdownStyle: ChillBreakdownStyle,
                                  rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let ride  = GMDrum.ride.rawValue
        let snare = GMDrum.snare.rawValue   // brush snare
        let kick  = GMDrum.kick.rawValue
        let hat   = GMDrum.closedHat.rawValue
        let fillOpt = rng.nextInt(upperBound: 3)   // A/B/C fill used across all breakdown styles

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let isBreakdown = section?.label == .bridge
            let isIntro     = section?.label == .intro
            let base = bar * 16

            // Cold start: bar 0 is a jazz pickup fill — other instruments are silent this bar
            if case .coldStart = structure.introStyle, bar == 0 {
                events += chillColdStartPickup(barStart: base, rng: &rng)
                continue
            }

            // Cold stop: final bar is crash+kick only; penultimate bar gets normal generation then 1-beat fill
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar == outroEnd - 1 {
                    events.append(MIDIEvent(stepIndex: base, note: GMDrum.crash1.rawValue, velocity: 110, durationSteps: 1))
                    events.append(MIDIEvent(stepIndex: base, note: GMDrum.kick.rawValue,   velocity: 105, durationSteps: 1))
                    continue
                }
            }

            var isColdStopPenultimate = false
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar, bar == outroEnd - 2 {
                isColdStopPenultimate = true
            }

            if isBreakdown {
                let breakdownBar = bar - (section?.startBar ?? bar)
                let sectionLen   = section?.lengthBars ?? 4
                let isLastBDBar  = (breakdownBar == sectionLen - 1)
                switch breakdownStyle {
                case .stopTime:
                    // Even bars: kick + snare hit; odd bars: momentum fill
                    if breakdownBar % 2 == 0 {
                        events.append(MIDIEvent(stepIndex: base, note: kick,  velocity: 85, durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: base, note: snare, velocity: 80, durationSteps: 1))
                    } else {
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    }
                case .bassOstinato:
                    if isLastBDBar {
                        // Last bar: kick on beat 1 then 3-beat momentum fill into groove return
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    } else {
                        // Ride on all 4 beats (steady pulse) + kick on beat 1 + snare brush on beat 3 (40%)
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: UInt8(52 + rng.nextInt(upperBound: 12)), durationSteps: 1))
                        for step in [0, 4, 8, 12] {
                            let vel = UInt8(32 + rng.nextInt(upperBound: 16))
                            events.append(MIDIEvent(stepIndex: base + step, note: ride, velocity: vel, durationSteps: 1))
                        }
                        if rng.nextDouble() < 0.40 {
                            events.append(MIDIEvent(stepIndex: base + 8, note: snare, velocity: UInt8(38 + rng.nextInt(upperBound: 14)), durationSteps: 1))
                        }
                    }
                case .harmonicDrone:
                    if isLastBDBar {
                        // Last bar: kick on beat 1 then 3-beat momentum fill into groove return
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    } else {
                        // Light ride pulse continues; beat doesn't fully stop
                        if breakdownBar >= 2 || rng.nextDouble() < 0.60 {
                            let vel = UInt8(30 + rng.nextInt(upperBound: 18))
                            events.append(MIDIEvent(stepIndex: base, note: ride, velocity: vel, durationSteps: 1))
                        }
                    }
                }
                continue
            }

            // Ride: beats 1 & 3 mandatory (jazz pulse backbone); beats 2 & 4 at 75%
            for step in [0, 8] {
                let vel = UInt8(45 + rng.nextInt(upperBound: 16))
                events.append(MIDIEvent(stepIndex: base + step, note: ride, velocity: vel, durationSteps: 1))
            }
            for step in [4, 12] {
                if rng.nextDouble() < 0.75 {
                    let vel = UInt8(42 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: base + step, note: ride, velocity: vel, durationSteps: 1))
                }
            }

            // Snare brush: beat 2 at 85%, beat 4 at 90%, vel 40–55
            if rng.nextDouble() < (isIntro ? 0.50 : 0.85) {
                let vel = UInt8(40 + rng.nextInt(upperBound: 16))
                events.append(MIDIEvent(stepIndex: base + 4, note: snare, velocity: vel, durationSteps: 1))
            }
            if rng.nextDouble() < (isIntro ? 0.70 : 0.90) {
                let vel = UInt8(40 + rng.nextInt(upperBound: 16))
                events.append(MIDIEvent(stepIndex: base + 12, note: snare, velocity: vel, durationSteps: 1))
            }

            // Kick: beat 1 always; beat 3 40% in non-intro sections
            let kickVel: UInt8 = isIntro ? 45 : UInt8(60 + rng.nextInt(upperBound: 11))
            events.append(MIDIEvent(stepIndex: base, note: kick, velocity: kickVel, durationSteps: 1))
            if !isIntro, rng.nextDouble() < 0.40 {
                let vel = UInt8(50 + rng.nextInt(upperBound: 11))
                events.append(MIDIEvent(stepIndex: base + 8, note: kick, velocity: vel, durationSteps: 1))
            }

            // Closed hi-hat: AND of beats 1 and 3 (steps 2, 10) at 70%; off-beat step 6 at 25%
            for step in [2, 10] {
                if rng.nextDouble() < 0.70 {
                    let vel = UInt8(35 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: base + step, note: hat, velocity: vel, durationSteps: 1))
                }
            }
            if rng.nextDouble() < 0.25 {
                let vel = UInt8(30 + rng.nextInt(upperBound: 13))
                events.append(MIDIEvent(stepIndex: base + 6, note: hat, velocity: vel, durationSteps: 1))
            }

            if isColdStopPenultimate {
                events = events.filter { $0.stepIndex < base + 12 }
                events += chillColdStopFill(barStart: base)
            }
        }
        return events
    }

    // MARK: - Hip-Hop Jazz — CHL-DRUM-005

    /// CHL-DRUM-005: Kick on beats 1+3, snare on beats 2+4, steady 8th-note closed hat,
    /// tambourine on all 16th-note positions. Tambourine runs for 8–16 bars then
    /// drops out for 4–8 bars; occasionally the groove drops out leaving tambourine alone.
    /// 9–14 events/bar when full; 5–6 without tambourine; 8 tambourine-only.
    private static func hipHopJazz(frame: GlobalMusicalFrame, structure: SongStructure,
                                    breakdownStyle: ChillBreakdownStyle,
                                    rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let kick   = GMDrum.kick.rawValue
        let snare  = GMDrum.snare.rawValue
        let hat    = GMDrum.closedHat.rawValue
        let tamb   = GMDrum.tambourine.rawValue

        // Decide tambourine schedule: alternating on/off runs seeded from song seed.
        // Use a simple block structure: tambourine is on for onLen bars, off for offLen bars.
        let tambOnLen  = 8  + rng.nextInt(upperBound: 9)   // 8–16 bars on
        let tambOffLen = 4  + rng.nextInt(upperBound: 5)   // 4–8 bars off
        let cycle      = tambOnLen + tambOffLen
        // grooveDropout: within a tambourine-on run, occasionally 1–2 bars play tambourine only
        // (groove drops out). Happens ~once per 10 bars on average.
        let fillOpt = rng.nextInt(upperBound: 3)   // A/B/C fill used across all breakdown styles

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A
            let base    = bar * 16
            let isBreakdown = label == .bridge
            let isIntro     = label == .intro

            // Cold start: bar 0 is pickup fill only
            if case .coldStart = structure.introStyle, bar == 0 {
                events += chillColdStartPickup(barStart: base, rng: &rng)
                continue
            }

            // Cold stop: final outro bar = crash+kick; penultimate = normal then 1-beat fill
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar == outroEnd - 1 {
                    events.append(MIDIEvent(stepIndex: base, note: GMDrum.crash1.rawValue, velocity: 108, durationSteps: 1))
                    events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 100, durationSteps: 1))
                    continue
                }
            }
            var isColdStopPenultimate = false
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar,
               bar == outroEnd - 2 { isColdStopPenultimate = true }

            if isBreakdown {
                let breakdownBar = bar - (section?.startBar ?? bar)
                let sectionLen   = section?.lengthBars ?? 4
                let isLastBDBar  = (breakdownBar == sectionLen - 1)
                switch breakdownStyle {
                case .stopTime:
                    if breakdownBar % 2 == 0 {
                        events.append(MIDIEvent(stepIndex: base, note: kick,  velocity: 88, durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: base, note: snare, velocity: 82, durationSteps: 1))
                    } else {
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    }
                case .bassOstinato:
                    if isLastBDBar {
                        // Last bar: kick on beat 1 then 3-beat momentum fill into groove return
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    } else {
                        // Quarter-note tambourine pulse — light time reference (4 events/bar)
                        for step in [0, 4, 8, 12] {
                            let vel = UInt8(30 + rng.nextInt(upperBound: 14))
                            events.append(MIDIEvent(stepIndex: base + step, note: tamb, velocity: vel, durationSteps: 1))
                        }
                    }
                case .harmonicDrone:
                    if isLastBDBar {
                        // Last bar: kick on beat 1 then 3-beat momentum fill into groove return
                        events.append(MIDIEvent(stepIndex: base, note: kick, velocity: 70, durationSteps: 1))
                        events += stopTimeFill(barStart: base, option: fillOpt,
                                               kick: kick, snare: snare, hat: hat, rng: &rng)
                    } else {
                        // 8th-note tambourine — slightly more active than bass-ostinato, beat still minimal
                        for step in stride(from: 0, to: 16, by: 2) {
                            let vel = UInt8(28 + rng.nextInt(upperBound: 12))
                            events.append(MIDIEvent(stepIndex: base + step, note: tamb, velocity: vel, durationSteps: 1))
                        }
                    }
                }
                continue
            }

            // Tambourine schedule: on for first tambOnLen bars of each cycle, off for tambOffLen bars
            let posInCycle   = bar % cycle
            let tambActive   = posInCycle < tambOnLen
            // Groove dropout: within a tambourine-on run, 1 bar in ~12 plays tambourine only
            let grooveDropout = tambActive && !isIntro && rng.nextDouble() < (1.0 / 12.0)

            // ── Kick: beats 1 and 3 ────────────────────────────────────────────
            if !grooveDropout {
                let kickVel: UInt8 = isIntro ? 52 : UInt8(75 + rng.nextInt(upperBound: 14))
                events.append(MIDIEvent(stepIndex: base,     note: kick, velocity: kickVel,          durationSteps: 1))
                events.append(MIDIEvent(stepIndex: base + 8, note: kick, velocity: UInt8(kickVel - 6), durationSteps: 1))
                // Occasional syncopated anticipation on the AND of beat 2 (step 6), ~20%
                if !isIntro, rng.nextDouble() < 0.20 {
                    let vel = UInt8(55 + rng.nextInt(upperBound: 12))
                    events.append(MIDIEvent(stepIndex: base + 6, note: kick, velocity: vel, durationSteps: 1))
                }
            }

            // ── Snare: beats 2 and 4 (95% reliability) ─────────────────────────
            if !grooveDropout {
                for step in [4, 12] {
                    if !isIntro || rng.nextDouble() < 0.50 {
                        let vel = UInt8((isIntro ? 48 : 72) + rng.nextInt(upperBound: 14))
                        events.append(MIDIEvent(stepIndex: base + step, note: snare, velocity: vel, durationSteps: 1))
                    }
                }
            }

            // ── Closed hat: every 8th note (steps 0,2,4,6,8,10,12,14) ──────────
            if !grooveDropout {
                for step in stride(from: 0, to: 16, by: 2) {
                    let vel = UInt8((isIntro ? 35 : 50) + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: base + step, note: hat, velocity: vel, durationSteps: 1))
                }
            }

            // ── Tambourine: all 16th positions when active ──────────────────────
            if tambActive {
                let baseVel: Int = isIntro ? 28 : 38
                for step in stride(from: 0, to: 16, by: 1) {
                    let vel = UInt8(baseVel + rng.nextInt(upperBound: 14))
                    events.append(MIDIEvent(stepIndex: base + step, note: tamb, velocity: vel, durationSteps: 1))
                }
            }

            if isColdStopPenultimate {
                events = events.filter { $0.stepIndex < base + 12 }
                events += chillColdStopFill(barStart: base)
            }
        }
        return events
    }

    // MARK: - Stop-time fill helper (shared across all drum styles)

    /// 2–3 beat momentum fill for stop-time silence bars, building into the next unison hit.
    /// Fires on beats 2–4 (steps 4–15) of each odd breakdown bar.
    /// option 0 = snare escalation, 1 = kick stutter + snare crack, 2 = hat cascade + snare crack.
    /// Same option used for all fills within a breakdown (picked once per song).
    private static func stopTimeFill(
        barStart: Int, option: Int,
        kick: UInt8, snare: UInt8, hat: UInt8,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var ev: [MIDIEvent] = []
        switch option {
        case 0:  // Snare escalation: ghost on beat 2, pair on beat 3, 4-note roll on beat 4
            ev.append(MIDIEvent(stepIndex: barStart + 4,  note: snare,
                                velocity: UInt8(35 + rng.nextInt(upperBound: 10)), durationSteps: 1))
            ev.append(MIDIEvent(stepIndex: barStart + 8,  note: snare,
                                velocity: UInt8(50 + rng.nextInt(upperBound: 10)), durationSteps: 1))
            ev.append(MIDIEvent(stepIndex: barStart + 10, note: snare,
                                velocity: UInt8(58 + rng.nextInt(upperBound: 10)), durationSteps: 1))
            for (i, step) in [12, 13, 14, 15].enumerated() {
                ev.append(MIDIEvent(stepIndex: barStart + step, note: snare,
                                    velocity: UInt8(63 + i * 9), durationSteps: 1))
            }
        case 1:  // Kick stutter + snare crack: sparse and heavy
            ev.append(MIDIEvent(stepIndex: barStart + 10, note: kick,
                                velocity: UInt8(60 + rng.nextInt(upperBound: 10)), durationSteps: 1))
            ev.append(MIDIEvent(stepIndex: barStart + 14, note: kick,
                                velocity: UInt8(70 + rng.nextInt(upperBound: 10)), durationSteps: 1))
            ev.append(MIDIEvent(stepIndex: barStart + 15, note: snare,
                                velocity: UInt8(80 + rng.nextInt(upperBound: 10)), durationSteps: 1))
        default: // Hat cascade + snare crack: pulsing 8th-note build
            for (i, step) in [8, 10, 12, 14].enumerated() {
                ev.append(MIDIEvent(stepIndex: barStart + step, note: hat,
                                    velocity: UInt8(35 + i * 10), durationSteps: 1))
            }
            ev.append(MIDIEvent(stepIndex: barStart + 15, note: snare,
                                velocity: UInt8(72 + rng.nextInt(upperBound: 12)), durationSteps: 1))
        }
        return ev
    }
}
