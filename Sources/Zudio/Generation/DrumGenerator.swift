// DrumGenerator.swift — generation step 4
// Copyright (c) 2026 Zack Urlocker
//
// Rule catalog:
//   DRM-001: Classic Motorik — kick 1+3, snare 2+4, 16th-hat velocity gradient (Apache beat)
//   DRM-002: Open Pocket — kick 1+3, snare 2+4, 8th-hat, open hat on 1, ghost snares
//   DRM-003: Ride Groove — kick 1+3, snare 2+4, ride 8ths, pedal hat 2+4
//   DRM-004: Almost Motorik — 4-on-the-floor kick, snare 2+4, 16th-hat gradient (disco/motorik hybrid)
//   DRM-005: Albatross Grid — kick 1+3, snare 2+4, 16th-hat gradient + open hat locked on "and of 4"
//            (step 14 every bar). Based on the Albatross (PiL, 1979) tom-less grid feel.
//            Same velocity gradient as DRM-001; the open hat accent is the only structural addition.
//            Motorik Noir only.
//   DRM-006: Annalisa March — snare all 4 beats, open hat all 8 8th-note positions, kick on
//            syncopated offbeats (steps 2, 6, 10 — NOT beat 1). No closed hats.
//            Based on PiL "Annalisa" (1979 Metal Box). At high intensity, ~25% of bars
//            add a double snare at steps 14-15 (built-in micro-fill into the next downbeat).
//            Motorik Noir only.
//   DRM-007: Inverted Beat — snare on beats 1+3 (steps 0, 8), kick on beats 2+4 (steps 4, 12).
//            Inverts the Apache convention — urgency and claustrophobia without losing the grid.
//            Based on Joy Division "Disorder" (1979). 8th-note hat. At high intensity (odd bars):
//            extra syncopated kick on "and of 2" (step 6) and "and of 4" (step 14).
//            Motorik Noir only.
//   DRM-013: Sequenced Timekeeper — one dense single-pitch timekeeping voice (closed hat or
//            wood block) on all eight even steps, plus kick 1+3, snare on beat 3 only, and two
//            fixed accent steps. Flat velocity 80, identical every bar, no fills. Kraftwerk
//            sync only (Rhythm Section).
//   DRM-014: Sparse Accents — no timekeeper at all. Kick 1+3 (or 1 and the "and" of 3), snare
//            every second bar, one accent every fourth bar. Under 1.5 notes/beat; the space is
//            the point. Kraftwerk sync only (Rhythm Section).
//   DRM-008: Tribal — NO hi-hat. Kick syncopated on steps 2, 4, 12, 14. Snare on beats 1+3.
//            Based on Joy Division "She's Lost Control" (1980) — purely percussive, tom-driven.
//            At high intensity every 6th bar: a mechanical descending tom cascade replaces the
//            normal bar (hi-mid tom → low-mid tom → floor tom roll with kick+snare launch).
//            Motorik Noir only.
//
// ALL patterns have snare on beats 2 AND 4 (steps 4+12). This is the defining
// characteristic of the Apache/Motorik beat — not snare on beat 3 alone.
// Exception: DRM-006 has snare on ALL 4 beats (0, 4, 8, 12) — the Annalisa march feel.
//
// Hi-hat velocity gradient creates human groove feel:
//   Beat 1 (step 0): 80    Beat 2 (step 4): 72    Beat 3 (step 8): 78    Beat 4 (step 12): 72
//   8th offbeats (2,6,10,14): 64    16th subdivisions (odd steps): 50

struct DrumGenerator {

    // MARK: - Velocity tables
    private static let motorikHatGradient:       [UInt8] = [80,50,64,50,72,50,64,50,78,50,64,50,72,50,64,50]
    private static let almostMotorikHatGradient: [UInt8] = [78,50,62,50,70,50,62,50,76,50,62,50,70,50,62,50]
    private static let marchHatVels:   [UInt8] = [74,60,70,58,72,60,68,56]
    private static let marchSnareVels: [UInt8] = [92,86,90,84]
    private static let marchKickVels:  [UInt8] = [98,90,94]
    private static let rideGrooveVels: [UInt8] = [58,50,55,48]
    private static let rideKickVels:   [UInt8] = [95,88,92]
    private static let tribalKickVels: [UInt8] = [90,98,96,88]

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil,
        noirVariation: Bool = false,
        arcadeVariation: Bool = false,
        sync: MotorikSync = .none
    ) -> [MIDIEvent] {
        let ruleID: String
        if let forced = forceRuleID {
            ruleID = forced
        } else if sync.includes(kTrackDrums) {
            // Kraftwerk sync: Sequenced Timekeeper 60% / Sparse Accents 40%.
            ruleID = rng.weightedPick([0.60, 0.40]) == 1 ? "MOT-DRUM-014" : "MOT-DRUM-013"
        } else if noirVariation {
            // Noir: Classic, Open Pocket, Ride, Albatross, Annalisa, Inverted Beat, Tribal.
            let ruleWeights: [Double] = [0.12, 0.06, 0.12, 0.20, 0.20, 0.10, 0.20]
            switch rng.weightedPick(ruleWeights) {
            case 1:  ruleID = "MOT-DRUM-002"
            case 2:  ruleID = "MOT-DRUM-003"
            case 3:  ruleID = "MOT-DRUM-005"
            case 4:  ruleID = "MOT-DRUM-006"
            case 5:  ruleID = "MOT-DRUM-007"
            case 6:  ruleID = "MOT-DRUM-008"
            default: ruleID = "MOT-DRUM-001"
            }
        } else if arcadeVariation {
            // Arcade: Sparse Fills 15%, Light Four 25%, Four-on-Floor 16%, Machine Step 14%, Classic 15%, Albatross 15%
            let ruleWeights: [Double] = [0.15, 0.25, 0.16, 0.14, 0.15, 0.15]
            switch rng.weightedPick(ruleWeights) {
            case 1:  ruleID = "MOT-DRUM-011"
            case 2:  ruleID = "MOT-DRUM-009"
            case 3:  ruleID = "MOT-DRUM-010"
            case 4:  ruleID = "MOT-DRUM-001"
            case 5:  ruleID = "MOT-DRUM-005"
            default: ruleID = "MOT-DRUM-012"
            }
        } else {
            // Weighted rule selection: DRM-001 30%, DRM-002 25%, DRM-003 20%, DRM-004 25%
            let ruleWeights: [Double] = [0.30, 0.25, 0.20, 0.25]
            let ruleIndex = rng.weightedPick(ruleWeights)
            switch ruleIndex {
            case 1:  ruleID = "MOT-DRUM-002"
            case 2:  ruleID = "MOT-DRUM-003"
            case 3:  ruleID = "MOT-DRUM-004"
            default: ruleID = "MOT-DRUM-001"
            }
        }
        usedRuleIDs.insert(ruleID)
        if ruleID == "MOT-DRUM-000" { return [] }

        // The two Kraftwerk kit rules bypass the bar loop entirely. That loop adds section
        // crashes, fills and intro/outro variants, and the measured character depends on none
        // of that happening — every bar is identical, and the arrangement interest comes from
        // the sync's section dropout instead.
        if ruleID == "MOT-DRUM-013" || ruleID == "MOT-DRUM-014" {
            return kraftwerkKit(ruleID: ruleID, totalBars: frame.totalBars, rng: &rng)
        }

        var events: [MIDIEvent] = []

        // MOT-DRUM-006 relief: full march bursts of 4–7 bars, then 8–12 bars of either
        // half-march or ride groove (chosen randomly each cycle).
        var marchRunLen    = 0
        var marchReliefLen = 0
        var marchReliefType = 0  // 0 = half-march, 1 = ride groove
        var marchCap       = ruleID == "MOT-DRUM-006" ? 4 + rng.nextInt(upperBound: 4) : 0

        // MOT-DRUM-011 kick-phase state: starts with 4–12 bars no kick, then alternates
        // kick-on (6–13 bars) and kick-off (4–10 bars) to achieve ~40% no-kick overall.
        var lf4KickOn         = false
        var lf4PhaseRemaining = ruleID == "MOT-DRUM-011" ? 4 + rng.nextInt(upperBound: 9) : 0

        // MOT-DRUM-012 Sparse Fills: one silent window early in the song, timekeeping everywhere else.
        // Timekeeping style chosen per song: 60% Option A (8th hats + soft snare backbeat),
        //                                    40% Option B (quarter hats + sidestick on 2+4).
        let s012SilentStart: Int
        let s012SilentEnd:   Int
        let s012UseBackbeat: Bool
        if ruleID == "MOT-DRUM-012" {
            let bodyStart = structure.bodySections.first?.startBar ?? 4
            let bodyEnd   = structure.outroSection?.startBar ?? frame.totalBars
            let halfBody  = bodyStart + max(4, (bodyEnd - bodyStart) / 2)
            let winLen    = 4 + rng.nextInt(upperBound: 5)           // 4–8 bars
            let earliest  = bodyStart + 2
            let latest    = max(earliest, halfBody - winLen)
            let range     = max(1, latest - earliest + 1)
            s012SilentStart = earliest + rng.nextInt(upperBound: range)
            s012SilentEnd   = s012SilentStart + winLen
            s012UseBackbeat = rng.nextDouble() < 0.60
        } else {
            s012SilentStart = 0; s012SilentEnd = 0; s012UseBackbeat = true
        }

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            let barStart = bar * 16
            let isFirstBarOfBodySection = section.startBar == bar && section.label != .intro && section.label != .outro

            if let intro = structure.introSection, intro.contains(bar: bar) {
                events += introPattern(bar: bar, introSection: intro, ruleID: ruleID,
                                       style: structure.introStyle, barStart: barStart, rng: &rng)
            } else if let outro = structure.outroSection, outro.contains(bar: bar) {
                events += outroPattern(bar: bar, outroSection: outro, ruleID: ruleID,
                                       style: structure.outroStyle, barStart: barStart, rng: &rng)
            } else {
                let intensity = section.subPhaseIntensity(atBar: bar)
                if isFirstBarOfBodySection {
                    events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.crash1.rawValue, velocity: 95, durationSteps: 1))
                }
                if ruleID == "MOT-DRUM-006" {
                    if marchReliefLen > 0 {
                        marchReliefLen -= 1
                        events += marchReliefType == 1
                            ? annalisaRideGrooveBar(barStart: barStart)
                            : annalisaHalfMarchBar(barStart: barStart)
                    } else {
                        events += annalisaMarchBar(bar: bar, intensity: intensity, barStart: barStart, rng: &rng)
                        // Only count medium/high bars — low intensity returns motorikSparseBar
                        // and should not trigger a relief window before any real march has played.
                        if intensity != .low {
                            marchRunLen += 1
                            if marchRunLen >= marchCap {
                                marchRunLen    = 0
                                marchReliefLen = 8 + rng.nextInt(upperBound: 5)  // 8–12 bars
                                marchReliefType = rng.nextInt(upperBound: 2)      // 0=half-march, 1=ride
                                marchCap       = 4 + rng.nextInt(upperBound: 4)  // next cap: 4–7 bars
                            }
                        }
                    }
                } else if ruleID == "MOT-DRUM-011" {
                    if lf4PhaseRemaining == 0 {
                        lf4KickOn = !lf4KickOn
                        lf4PhaseRemaining = lf4KickOn
                            ? 6 + rng.nextInt(upperBound: 8)   // kick on: 6–13 bars
                            : 4 + rng.nextInt(upperBound: 7)   // kick off: 4–10 bars
                    }
                    lf4PhaseRemaining -= 1
                    events += lightFourBar(bar: bar, intensity: intensity, barStart: barStart, kickEnabled: lf4KickOn)
                } else if ruleID == "MOT-DRUM-012" {
                    let inSilentWindow = bar >= s012SilentStart && bar < s012SilentEnd
                    if !inSilentWindow {
                        events += s012UseBackbeat
                            ? sparseFillsBackbeatBar(barStart: barStart)
                            : sparseFillsRimshotBar(barStart: barStart)
                    }
                } else {
                    events += bodyBar(bar: bar, ruleID: ruleID, intensity: intensity, barStart: barStart, rng: &rng)
                }
            }
        }

        return events
    }

    // MARK: - Pattern routing

    private static func bodyBar(
        bar: Int, ruleID: String, intensity: SectionIntensity, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        switch ruleID {
        case "MOT-DRUM-002": return openPocketBar(intensity: intensity, barStart: barStart)
        case "MOT-DRUM-003": return rideGrooveBar(intensity: intensity, barStart: barStart)
        case "MOT-DRUM-004": return almostMotorikBar(bar: bar, intensity: intensity, barStart: barStart)
        case "MOT-DRUM-005": return albatrossGridBar(bar: bar, intensity: intensity, barStart: barStart)
        case "MOT-DRUM-006": return annalisaMarchBar(bar: bar, intensity: intensity, barStart: barStart, rng: &rng)
        case "MOT-DRUM-007": return invertedBeatBar(bar: bar, intensity: intensity, barStart: barStart)
        case "MOT-DRUM-008": return tribalBar(bar: bar, intensity: intensity, barStart: barStart)
        case "MOT-DRUM-009": return fourOnFloorBar(bar: bar, intensity: intensity, barStart: barStart)
        case "MOT-DRUM-010": return machineStepBar(bar: bar, intensity: intensity, barStart: barStart)
        default:             return classicMotorikBar(bar: bar, intensity: intensity, barStart: barStart)
        }
    }

    // MARK: - DRM-001: Classic Motorik (Apache beat)
    // Kick 1+3, snare 2+4, 16th hi-hats with velocity gradient

    private static func classicMotorikBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        switch intensity {
        case .low:    return motorikSparseBar(barStart: barStart)
        case .medium: return motorikCoreBar(barStart: barStart, addSyncopatedKick: false)
        case .high:   return motorikCoreBar(barStart: barStart, addSyncopatedKick: bar % 4 >= 2)
        }
    }

    /// The definitive Apache/Motorik groove: kick 1+3, snare 2+4, 16th hats.
    private static func motorikCoreBar(barStart: Int, addSyncopatedKick: Bool) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // 16th-note hi-hats — velocity gradient creates human groove
        for step in 0..<16 {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: motorikHatGradient[step], durationSteps: 1))
        }

        // Kick on beats 1 and 3 (steps 0, 8)
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue,  velocity: 105, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue,  velocity: 100, durationSteps: 1))

        // Snare on beats 2 and 4 (steps 4, 12) — THE Apache beat
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 95, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 92, durationSteps: 1))

        // Syncopated kick on "and of 3" (step 10) for high-intensity bars — classic Motorik variation
        if addSyncopatedKick {
            events.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.kick.rawValue, velocity: 82, durationSteps: 1))
        }

        return events
    }

    /// Low-intensity Motorik: groove preserved, just quieter and with 8th hats instead of 16ths
    private static func motorikSparseBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        // 8th-note hats (half density) at reduced velocity
        for step in Swift.stride(from: 0, to: 16, by: 2) {
            let vel: UInt8 = (step % 8 == 0) ? 62 : 52
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: vel, durationSteps: 1))
        }
        // Kick 1+3 — soft
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue,  velocity: 88, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue,  velocity: 82, durationSteps: 1))
        // Snare 2+4 — soft
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 72, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 68, durationSteps: 1))
        return events
    }

    // MARK: - DRM-005: Albatross Grid — Classic Motorik + open hat locked on "and of 4"
    // Structurally identical to DRM-001 with one addition: the closed hat at step 14
    // ("and of 4") is replaced by an open hat every bar. The open hat stays open for
    // 2 steps, giving a slight "tss" tail before the next downbeat.
    // Same velocity gradient as DRM-001; syncopated kick variation preserved at high intensity.
    // Inspired by the drum grid on PiL "Albatross" (1979) — the recurring open hat on the
    // last eighth of bar gives the groove its slightly unsettled, nocturnal quality.

    private static func albatrossGridBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        switch intensity {
        case .low:    return motorikSparseBar(barStart: barStart)  // sparse intro/outro: 8th hats, no open accent
        case .medium: return albatrossGridCoreBar(barStart: barStart, addSyncopatedKick: false)
        case .high:   return albatrossGridCoreBar(barStart: barStart, addSyncopatedKick: bar % 4 >= 2)
        }
    }

    private static func albatrossGridCoreBar(barStart: Int, addSyncopatedKick: Bool) -> [MIDIEvent] {
        // Same as Classic Motorik but with the closed hat at step 14 replaced by an open hat.
        var events = motorikCoreBar(barStart: barStart, addSyncopatedKick: addSyncopatedKick)
        events.removeAll { $0.stepIndex == barStart + 14 && $0.note == GMDrum.closedHat.rawValue }
        events.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.openHat.rawValue,
                                velocity: 72, durationSteps: 2))
        return events
    }

    // MARK: - DRM-006: Annalisa March — PiL "Annalisa" (1979) all-open-hat marching grid
    // Snare on all 4 beats (quarter notes), open hat on all 8 8th-note positions, kick
    // syncopated on offbeat steps 2, 6, 10 — NOT on beat 1. No closed hats.
    // The kick never landing on beat 1 creates an unsettled, forward-lurching quality;
    // the snare-on-every-beat replaces the hat's timekeeping role and drives like a march.
    // At high intensity, ~25% of bars add a double snare at steps 14-15 — a built-in
    // micro-fill that marks the bar boundary without derailing the locked grid.

    private static func annalisaMarchBar(
        bar: Int, intensity: SectionIntensity, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        switch intensity {
        case .low:    return motorikSparseBar(barStart: barStart)
        case .medium: return annalisaMarchCoreBar(barStart: barStart, doubleSnareTail: false)
        case .high:   return annalisaMarchCoreBar(barStart: barStart, doubleSnareTail: rng.nextDouble() < 0.25)
        }
    }

    private static func annalisaMarchCoreBar(barStart: Int, doubleSnareTail: Bool) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Open hat on all 8 8th-note positions — beat positions slightly louder
        for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.openHat.rawValue,
                                    velocity: marchHatVels[i], durationSteps: 2))
        }

        // Snare on all 4 beats (0, 4, 8, 12) — the march
        for (i, step) in [0, 4, 8, 12].enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.snare.rawValue,
                                    velocity: marchSnareVels[i], durationSteps: 1))
        }

        // Kick on syncopated offbeats (steps 2, 6, 10) — never on beat 1
        for (i, step) in [2, 6, 10].enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.kick.rawValue,
                                    velocity: marchKickVels[i], durationSteps: 1))
        }

        // Double snare tail at steps 14-15 — micro-fill into next downbeat (~25% of high bars)
        if doubleSnareTail {
            events.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.snare.rawValue,
                                    velocity: 78, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 15, note: GMDrum.snare.rawValue,
                                    velocity: 96, durationSteps: 1))
        }

        return events
    }

    // Half-march relief: snare on beats 2+4 only (standard backbeat), open hat locked to
    // beats 2+4 — hat and snare lock together, beats 1+3 left open for the syncopated kick.
    private static func annalisaHalfMarchBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Open hat on beats 2+4 only — locks with snare, 2 hits per bar
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.openHat.rawValue, velocity: 66, durationSteps: 2))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.openHat.rawValue, velocity: 63, durationSteps: 2))

        // Snare on beats 2+4 only (steps 4, 12) — standard backbeat, not a march
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 86, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 84, durationSteps: 1))

        // Syncopated kick on offbeats (steps 2, 6, 10) — identical to full march
        for (i, step) in [2, 6, 10].enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.kick.rawValue,
                                    velocity: marchKickVels[i], durationSteps: 1))
        }

        return events
    }

    // Ride groove relief: ride cymbal on quarter notes (thinned), snare on 2+4.
    // Same skeleton as the march but with a controlled ride character — Can/Sync feel.
    private static func annalisaRideGrooveBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Ride on all 4 beats at low velocity — textural rather than driving
        for (i, step) in [0, 4, 8, 12].enumerated() {
            let note: GMDrum = (i == 0) ? .rideBell : .ride
            events.append(MIDIEvent(stepIndex: barStart + step, note: note.rawValue,
                                    velocity: rideGrooveVels[i], durationSteps: 2))
        }

        // Snare on beats 2+4 only (steps 4, 12)
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 84, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 82, durationSteps: 1))

        // Syncopated kick on offbeats (steps 2, 6, 10) — identical to full march
        for (i, step) in [2, 6, 10].enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.kick.rawValue,
                                    velocity: rideKickVels[i], durationSteps: 1))
        }

        return events
    }

    // MARK: - DRM-007: Inverted Beat — Joy Division "Disorder" inverted backbeat
    // Snare on beats 1+3 (steps 0, 8), kick on beats 2+4 (steps 4, 12).
    // Inverts the standard Apache convention — unsettled urgency without breaking the grid.
    // At high intensity (odd bars): extra kick on "and of 2" (step 6) and "and of 4" (step 14).

    private static func invertedBeatBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        switch intensity {
        case .low:    return motorikSparseBar(barStart: barStart)
        case .medium: return invertedBeatCoreBar(barStart: barStart, addExtraKicks: false)
        case .high:   return invertedBeatCoreBar(barStart: barStart, addExtraKicks: bar % 2 == 1)
        }
    }

    private static func invertedBeatCoreBar(barStart: Int, addExtraKicks: Bool) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // 8th-note hi-hats — slightly restrained velocity to let snare/kick dominate
        for step in Swift.stride(from: 0, to: 16, by: 2) {
            let vel: UInt8 = (step % 8 == 0) ? 68 : 55
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: vel, durationSteps: 1))
        }

        // Snare on beats 1+3 — the inverted anchor
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.snare.rawValue, velocity: 96, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.snare.rawValue, velocity: 92, durationSteps: 1))

        // Kick on beats 2+4 — inverted from Apache convention
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.kick.rawValue, velocity: 100, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.kick.rawValue, velocity: 96,  durationSteps: 1))

        // Extra syncopated kicks on "and of 2" and "and of 4" at high intensity
        if addExtraKicks {
            events.append(MIDIEvent(stepIndex: barStart + 6,  note: GMDrum.kick.rawValue, velocity: 78, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.kick.rawValue, velocity: 76, durationSteps: 1))
        }

        return events
    }

    // MARK: - DRM-008: Tribal — Joy Division "She's Lost Control" tom-driven grid
    // No hi-hat. Kick syncopated on steps 2, 4, 12, 14. Snare on beats 1+3 (steps 0, 8).
    // Every 6th bar at high intensity: descending tom cascade replaces the normal pattern.

    private static func tribalBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        switch intensity {
        case .low:    return tribalSparseBar(barStart: barStart)
        case .medium: return tribalCoreBar(barStart: barStart)
        case .high:   return (bar % 6 == 5) ? tribalTomCascade(barStart: barStart)
                                            : tribalCoreBar(barStart: barStart)
        }
    }

    private static func tribalSparseBar(barStart: Int) -> [MIDIEvent] {
        return [
            MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.snare.rawValue, velocity: 75, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 2,  note: GMDrum.kick.rawValue,  velocity: 82, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.snare.rawValue, velocity: 70, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 12, note: GMDrum.kick.rawValue,  velocity: 80, durationSteps: 1),
        ]
    }

    private static func tribalCoreBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        // Snare on beats 1+3
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.snare.rawValue, velocity: 95, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.snare.rawValue, velocity: 90, durationSteps: 1))
        // Kick syncopated: steps 2, 4, 12, 14
        for (i, step) in [2, 4, 12, 14].enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.kick.rawValue,
                                    velocity: tribalKickVels[i], durationSteps: 1))
        }
        return events
    }

    /// Mechanical descending tom cascade — "She's Lost Control" fill.
    /// Kick+snare launch → hi-mid tom triplet → low-mid tom triplet → floor tom roll.
    private static func tribalTomCascade(barStart: Int) -> [MIDIEvent] {
        return [
            MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.kick.rawValue,          velocity: 105, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.snare.rawValue,          velocity: 95,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.hiMidTom.rawValue,       velocity: 88,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 5,  note: GMDrum.hiMidTom.rawValue,       velocity: 82,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 6,  note: GMDrum.hiMidTom.rawValue,       velocity: 76,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.lowMidTom.rawValue,      velocity: 88,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 9,  note: GMDrum.lowMidTom.rawValue,      velocity: 82,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 10, note: GMDrum.lowMidTom.rawValue,      velocity: 76,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 12, note: GMDrum.highFloorTom.rawValue,   velocity: 90,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 13, note: GMDrum.highFloorTom.rawValue,   velocity: 84,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 14, note: GMDrum.highFloorTom.rawValue,   velocity: 80,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 15, note: GMDrum.highFloorTom.rawValue,   velocity: 88,  durationSteps: 1),
        ]
    }

    // MARK: - MOT-DRUM-009: Four-on-Floor — defining Arcade kick pattern
    // Kick on every quarter note (steps 0,4,8,12). Snare on beats 2+4 (steps 4,12) — shared with kick.
    // 16th-note hi-hat at moderate velocity with beat-position accent (+8). Open hat on steps 6 and 14
    // (the "and of 2" and "and of 4") — classic house/techno open-hat flourish.
    // Low intensity: 8th-note hat, open hat suppressed. Arcade drum pool weight: 45%.

    private static func fourOnFloorBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        switch intensity {
        case .low:    return fourOnFloorSparseBar(barStart: barStart)
        case .medium: return fourOnFloorCoreBar(barStart: barStart, addOpenHat: true)
        case .high:   return fourOnFloorCoreBar(barStart: barStart, addOpenHat: true)
        }
    }

    private static func fourOnFloorCoreBar(barStart: Int, addOpenHat: Bool) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // 16th-note hi-hats with beat-position accent (+8 on beat positions)
        for step in 0..<16 {
            let isBeat = step % 4 == 0
            let vel: UInt8 = isBeat ? 72 : 62
            // Open hat replaces closed hat at steps 6 and 14
            let isOpenHatStep = addOpenHat && (step == 6 || step == 14)
            if isOpenHatStep {
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.openHat.rawValue,
                                        velocity: 70, durationSteps: 2))
            } else {
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                        velocity: vel, durationSteps: 1))
            }
        }

        // 4-on-the-floor kick (all 4 beats) — the defining Arcade character
        events.append(MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.kick.rawValue, velocity: 105, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.kick.rawValue, velocity: 92,  durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.kick.rawValue, velocity: 100, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.kick.rawValue, velocity: 90,  durationSteps: 1))

        // Snare on beats 2+4 — shared accent with kick on those steps
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 95, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 92, durationSteps: 1))

        return events
    }

    private static func fourOnFloorSparseBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        // 8th-note hats (reduced density for low intensity)
        for step in Swift.stride(from: 0, to: 16, by: 2) {
            let vel: UInt8 = (step % 8 == 0) ? 60 : 50
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: vel, durationSteps: 1))
        }
        // 4-on-floor kick and snare still present — just quieter
        events.append(MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.kick.rawValue,  velocity: 90, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.kick.rawValue,  velocity: 78, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.kick.rawValue,  velocity: 86, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.kick.rawValue,  velocity: 76, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 78, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 75, durationSteps: 1))
        return events
    }

    // MARK: - MOT-DRUM-010: Machine Step — 4-on-floor with doubled 8th-note hat feel
    // Identical kick+snare to MOT-DRUM-009. Hat: 8th-note base with an additional 16th on
    // steps 6 and 14 (the "and of beats 2 and 4") — creates a subtle syncopated swing without
    // breaking the machine feel. Open hat suppressed — the identity is the doubled-8th pattern.
    // At max intensity: stays at the doubled-8th pattern (never fills to 16 steps, preserving
    // the distinction from Four-on-Floor's dense 16th-note grid). Arcade drum pool weight: 30%.

    private static func machineStepBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        switch intensity {
        case .low: return fourOnFloorSparseBar(barStart: barStart)  // shared sparse fallback
        default:   return machineStepCoreBar(barStart: barStart)
        }
    }

    private static func machineStepCoreBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // 8th-note hi-hats (steps 0,2,4,6,8,10,12,14) — the base grid
        for step in Swift.stride(from: 0, to: 16, by: 2) {
            let isBeat = step % 4 == 0
            let vel: UInt8 = isBeat ? 70 : 60
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: vel, durationSteps: 1))
        }
        // Extra 16th-note closed hat on steps 6 and 14 — the syncopated "skip" that defines Machine Step
        events.append(MIDIEvent(stepIndex: barStart + 6,  note: GMDrum.closedHat.rawValue, velocity: 54, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.closedHat.rawValue, velocity: 54, durationSteps: 1))

        // 4-on-the-floor kick — same as Four-on-Floor
        events.append(MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.kick.rawValue, velocity: 105, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.kick.rawValue, velocity: 92,  durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.kick.rawValue, velocity: 100, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.kick.rawValue, velocity: 90,  durationSteps: 1))

        // Snare on beats 2+4
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 95, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 92, durationSteps: 1))

        return events
    }

    // MARK: - DRM-002: Open Pocket
    // Kick 1+3, snare 2+4, 8th hats, open hat accent on beat 1, ghost snares

    private static func openPocketBar(intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // 8th-note closed hats
        for step in Swift.stride(from: 0, to: 16, by: 2) {
            let vel: UInt8 = (step == 0) ? 0 : (step % 8 == 0 ? 70 : 62)  // beat 1 replaced by open hat
            if vel > 0 {
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                        velocity: vel, durationSteps: 1))
            }
        }
        // Open hat on beat 1 (replaces closed hat)
        events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.openHat.rawValue, velocity: 82, durationSteps: 2))

        // Kick 1+3
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue,  velocity: 105, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue,  velocity: 100, durationSteps: 1))

        // Snare 2+4
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 92, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 90, durationSteps: 1))

        // Ghost snares at medium/high — subtle accents between backbeats
        if intensity >= .medium {
            events.append(MIDIEvent(stepIndex: barStart + 2,  note: GMDrum.snare.rawValue, velocity: 35, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.snare.rawValue, velocity: 35, durationSteps: 1))
        }
        return events
    }

    // MARK: - DRM-003: Ride Groove
    // Kick 1+3, snare 2+4, ride 8ths, pedal hat 2+4

    private static func rideGrooveBar(intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Ride on 8ths with velocity variation
        for step in Swift.stride(from: 0, to: 16, by: 2) {
            let vel: UInt8 = (step % 8 == 0) ? 78 : 65
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.ride.rawValue,
                                    velocity: vel, durationSteps: 1))
        }

        // Kick 1+3
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue,  velocity: 105, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue,  velocity: 100, durationSteps: 1))

        // Snare 2+4
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 94, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 91, durationSteps: 1))

        // Pedal hat on 2+4 (reinforces snare backbeat — very common in Motorik-adjacent)
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.pedalHat.rawValue, velocity: 60, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.pedalHat.rawValue, velocity: 60, durationSteps: 1))

        // Ride bell accent on beat 1 at high intensity
        if intensity == .high {
            events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.rideBell.rawValue, velocity: 72, durationSteps: 1))
        }

        return events
    }

    // MARK: - DRM-004: Almost Motorik (4-on-the-floor hybrid)
    // Full 4-on-the-floor kick + snare 2+4 + 16th hats = the disco/electronic Motorik feel
    // Think: later Neu!, Can, early electronic Motorik-adjacent

    private static func almostMotorikBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // 16th-note hi-hats — same velocity gradient as DRM-001
        for step in 0..<16 {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: almostMotorikHatGradient[step], durationSteps: 1))
        }

        // 4-on-the-floor kick (all 4 beats) — what makes this "almost" rather than classic Motorik
        events.append(MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.kick.rawValue, velocity: 105, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.kick.rawValue, velocity: 92,  durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.kick.rawValue, velocity: 100, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.kick.rawValue, velocity: 90,  durationSteps: 1))

        // Snare 2+4 (overlaps kick on those beats — classic dance/rock hybrid)
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 94, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 91, durationSteps: 1))

        // High intensity: add open hat on "and of 4" (step 14)
        if intensity == .high && bar % 2 == 1 {
            events.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.openHat.rawValue, velocity: 72, durationSteps: 1))
        }

        return events
    }

    // MARK: - Intro patterns

    private static func introPattern(
        bar: Int, introSection: SongSection, ruleID: String,
        style: IntroStyle, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let offsetBar  = bar - introSection.startBar
        let isLastBar  = bar == introSection.endBar - 1

        // All styles add a 2-step snare pickup on the last intro bar to launch the body
        func withPickup(_ evs: [MIDIEvent]) -> [MIDIEvent] {
            guard isLastBar else { return evs }
            return evs + [
                MIDIEvent(stepIndex: barStart + 14, note: GMDrum.snare.rawValue, velocity: 82, durationSteps: 1),
                MIDIEvent(stepIndex: barStart + 15, note: GMDrum.snare.rawValue, velocity: 96, durationSteps: 1)
            ]
        }

        switch style {

        case .alreadyPlaying:
            // Full groove from bar 0 — PlaybackEngine fades the master in over the intro duration.
            return withPickup(bodyBar(bar: bar, ruleID: ruleID, intensity: .low, barStart: barStart, rng: &rng))

        case .progressiveEntry:
            // Full Motorik sparse groove from bar 0 (kick+snare+hat all present).
            // Bass will play a simplified root+fifth pattern; pads enter on last bar.
            return withPickup(motorikSparseBar(barStart: barStart))

        case .coldStart(let drumsOnly):
            // Bar 0: kick/tom pickup fill that starts mid-bar so the groove launches on bar 1 beat 1.
            // drumsOnly = true → 2-3 beat fill only (nothing else plays bar 0).
            // drumsOnly = false → random 1-4 beat fill with bass grounding it.
            // Bar 1+: full sparse Motorik groove.
            if offsetBar == 0 {
                let pickupStarts = drumsOnly ? [4, 8] : [0, 4, 8, 12]
                let fromStep = pickupStarts[rng.nextInt(upperBound: pickupStarts.count)]
                return coldStartPickup(fromStep: fromStep, barStart: barStart, rng: &rng)
            }
            return withPickup(motorikSparseBar(barStart: barStart))
        }
    }

    /// Cold start drum pickup: silence before `fromStep`, then a fill leading to the body downbeat.
    /// `fromStep` 0 = full bar, 4 = 3-beat, 8 = 2-beat, 12 = 1-beat.
    /// Three variants picked randomly:
    ///   v0  Tom cascade     — descending kick/tom/snare weave (original)
    ///   v1  Retro Rock      — NEU!-style tom descend from beat 2, tom cascade beat 4
    ///   v2  Funk snare build — snare accents building with kick, climaxes step 14
    private static func coldStartPickup(fromStep: Int, barStart: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let variant = rng.nextInt(upperBound: 3)
        let pattern: [(Int, UInt8, UInt8)]

        switch variant {

        case 0: // Descending kick/tom cascade (original)
            pattern = [
                (0,  GMDrum.kick.rawValue,          100),
                (4,  GMDrum.kick.rawValue,          95),
                (8,  GMDrum.hiTom.rawValue,         80),
                (9,  GMDrum.snare.rawValue,         70),
                (10, GMDrum.hiMidTom.rawValue,      82),
                (11, GMDrum.snare.rawValue,         76),
                (12, GMDrum.lowMidTom.rawValue,     85),
                (13, GMDrum.snare.rawValue,         82),
                (14, GMDrum.highFloorTom.rawValue,  88),
                (15, GMDrum.snare.rawValue,         96),
            ]

        case 1: // Retro Rock — snare+hat on beat 2, tom descend through beats 3–4, tom cascade climax
            pattern = [
                (4,  GMDrum.snare.rawValue,         70),
                (4,  GMDrum.closedHat.rawValue,     65),
                (6,  GMDrum.lowMidTom.rawValue,     72),
                (7,  GMDrum.hiMidTom.rawValue,      76),
                (8,  GMDrum.kick.rawValue,          88),
                (9,  GMDrum.lowMidTom.rawValue,     80),
                (10, GMDrum.highFloorTom.rawValue,  84),
                (11, GMDrum.kick.rawValue,          90),
                (12, GMDrum.lowMidTom.rawValue,     78),
                (13, GMDrum.hiMidTom.rawValue,      85),
                (14, GMDrum.highFloorTom.rawValue,  95),
            ]

        default: // Funk snare build — snare accents + kick build to beat 4 accent
            pattern = [
                (8,  GMDrum.snare.rawValue,         65),
                (9,  GMDrum.snare2.rawValue,        72),
                (10, GMDrum.kick.rawValue,          85),
                (10, GMDrum.snare.rawValue,         78),
                (11, GMDrum.kick.rawValue,          88),
                (12, GMDrum.snare2.rawValue,        82),
                (13, GMDrum.hiMidTom.rawValue,      88),
                (14, GMDrum.snare.rawValue,         100),
            ]
        }

        return pattern.compactMap { (offset, note, velocity) in
            guard offset >= fromStep else { return nil }
            return MIDIEvent(stepIndex: barStart + offset, note: note,
                             velocity: velocity, durationSteps: 1)
        }
    }

    // MARK: - Outro patterns

    private static func outroPattern(
        bar: Int, outroSection: SongSection, ruleID: String,
        style: OutroStyle, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let offsetBar     = bar - outroSection.startBar
        let totalOutroBars = outroSection.lengthBars
        let isLastBar     = offsetBar == totalOutroBars - 1

        switch style {

        case .fade:
            // Full groove at body velocity — PlaybackEngine fades the master out.
            return bodyBar(bar: bar, ruleID: ruleID, intensity: .low, barStart: barStart, rng: &rng)

        case .dissolve:
            // Drums strip back progressively; pads hold to the final bar.
            if offsetBar < totalOutroBars / 2 {
                return motorikSparseBar(barStart: barStart)
            } else if offsetBar < totalOutroBars - 2 {
                return [
                    MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue,      velocity: 85, durationSteps: 1),
                    MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue,      velocity: 80, durationSteps: 1),
                    MIDIEvent(stepIndex: barStart + 0, note: GMDrum.closedHat.rawValue, velocity: 55, durationSteps: 1),
                    MIDIEvent(stepIndex: barStart + 8, note: GMDrum.closedHat.rawValue, velocity: 50, durationSteps: 1),
                ]
            } else {
                return [
                    MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue, velocity: 75, durationSteps: 1),
                    MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue, velocity: 70, durationSteps: 1),
                ]
            }

        case .coldStop:
            // Full body groove until the final bar, which is a dramatic 4-beat closing fill.
            if isLastBar {
                return coldStopFill(barStart: barStart)
            }
            return bodyBar(bar: bar, ruleID: ruleID, intensity: .medium, barStart: barStart, rng: &rng)
        }
    }

    /// Dramatic 4-beat closing fill: crash launch → descending tom cascade → final crash+kick.
    private static func coldStopFill(barStart: Int) -> [MIDIEvent] {
        return [
            MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.crash1.rawValue,       velocity: 110, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.kick.rawValue,          velocity: 110, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 1,  note: GMDrum.hiTom.rawValue,         velocity: 90,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 2,  note: GMDrum.snare.rawValue,         velocity: 95,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 3,  note: GMDrum.hiTom.rawValue,         velocity: 85,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.kick.rawValue,          velocity: 100, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 5,  note: GMDrum.hiMidTom.rawValue,      velocity: 88,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 6,  note: GMDrum.snare.rawValue,         velocity: 92,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 7,  note: GMDrum.hiMidTom.rawValue,      velocity: 83,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.kick.rawValue,          velocity: 105, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 9,  note: GMDrum.lowMidTom.rawValue,     velocity: 90,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 10, note: GMDrum.snare.rawValue,         velocity: 96,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 11, note: GMDrum.lowMidTom.rawValue,     velocity: 86,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 12, note: GMDrum.highFloorTom.rawValue,  velocity: 92,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 13, note: GMDrum.snare.rawValue,         velocity: 100, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 14, note: GMDrum.lowFloorTom.rawValue,   velocity: 95,  durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 15, note: GMDrum.crash1.rawValue,        velocity: 115, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 15, note: GMDrum.kick.rawValue,          velocity: 115, durationSteps: 1),
        ]
    }

    // MARK: - MOT-DRUM-011: Light Four
    // Phase-based kick scheduling: starts 4–12 bars no kick, then alternates kick-on (6–13 bars)
    // and kick-off (4–10 bars) — ~40% of body bars have no kick. Within kick-on phases, beats 2+4
    // carry a soft kick 2-of-every-3 bars, and bars 12–15 of every 16-bar cycle drop to quiet
    // 8th-hat timekeeping. No-kick phases use full 16th hats + normal snare — musical, not minimal.

    private static func lightFourBar(bar: Int, intensity: SectionIntensity, barStart: Int, kickEnabled: Bool) -> [MIDIEvent] {
        if intensity == .low { return lightFourSparseBar(barStart: barStart) }
        if !kickEnabled      { return lightFourNoKickBar(bar: bar, barStart: barStart) }
        if bar % 16 >= 12   { return lightFourTimeKeepBar(barStart: barStart) }
        return lightFourCoreBar(bar: bar, barStart: barStart)
    }

    private static func lightFourCoreBar(bar: Int, barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // 16th-note hi-hat with open hat at "and of 2" (step 6) and "and of 4" (step 14)
        for step in 0..<16 {
            if step == 6 || step == 14 {
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.openHat.rawValue,
                                        velocity: 66, durationSteps: 2))
            } else {
                let isBeat = step % 4 == 0
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                        velocity: isBeat ? 70 : 60, durationSteps: 1))
            }
        }

        // Beats 1 and 3: always present, full strength
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue, velocity: 105, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue, velocity: 98,  durationSteps: 1))

        // Beat 2: soft kick, present when bar % 3 != 2
        if bar % 3 != 2 {
            events.append(MIDIEvent(stepIndex: barStart + 4, note: GMDrum.kick.rawValue, velocity: 62, durationSteps: 1))
        }
        // Beat 4: soft kick, present when bar % 3 != 0 (offset phase from beat 2)
        if bar % 3 != 0 {
            events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.kick.rawValue, velocity: 58, durationSteps: 1))
        }

        // Snare on beats 2+4 — slightly lighter than Four-on-Floor (88/85 vs 95/92)
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 88, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 85, durationSteps: 1))

        return events
    }

    // No-kick phase: full 16th hats + open hat + normal snare — feels musical, not stripped
    private static func lightFourNoKickBar(bar: Int, barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for step in 0..<16 {
            if step == 6 || step == 14 {
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.openHat.rawValue,
                                        velocity: 60, durationSteps: 2))
            } else {
                let isBeat = step % 4 == 0
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                        velocity: isBeat ? 64 : 54, durationSteps: 1))
            }
        }
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 85, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 82, durationSteps: 1))
        return events
    }

    // Kick-free timekeeping: bars 12–15 of every 16-bar kick-on cycle — quiet 8th hats + ghost snare
    private static func lightFourTimeKeepBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for step in Swift.stride(from: 0, to: 16, by: 2) {
            let vel: UInt8 = (step % 8 == 0) ? 52 : 44
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: vel, durationSteps: 1))
        }
        // Ghost snares on beats 2 and 4 — barely audible, just marking time
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 52, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 48, durationSteps: 1))
        return events
    }

    // MARK: - MOT-DRUM-012: Sparse Fills
    // One silent window (4–8 bars) placed early in the song; timekeeping everywhere else.
    // Style chosen per song: 60% Option A (backbeat snare), 40% Option B (sidestick + quarter hats).
    // Section-boundary crashes fire naturally via the isFirstBarOfBodySection path.

    // Option A: 8th hats + very soft snare on 2+4 — clear backbeat pulse, no kick
    private static func sparseFillsBackbeatBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for step in Swift.stride(from: 0, to: 16, by: 2) {
            let vel: UInt8 = step % 8 == 0 ? 48 : 38
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: vel, durationSteps: 1))
        }
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 50, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 46, durationSteps: 1))
        return events
    }

    // Option B: quarter-note hats + sidestick on 2+4 — dry rimshot tick, more minimal feel
    private static func sparseFillsRimshotBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for step in [0, 4, 8, 12] {
            let vel: UInt8 = step == 0 ? 52 : 44
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: vel, durationSteps: 1))
        }
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.sidestick.rawValue, velocity: 54, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.sidestick.rawValue, velocity: 50, durationSteps: 1))
        return events
    }

    // Low intensity: beats 1+3 kick only, 8th hats, lighter snare
    private static func lightFourSparseBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for step in Swift.stride(from: 0, to: 16, by: 2) {
            let vel: UInt8 = (step % 8 == 0) ? 56 : 46
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: vel, durationSteps: 1))
        }
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue,  velocity: 88, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue,  velocity: 82, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 72, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 68, durationSteps: 1))
        return events
    }


    // MARK: - Kraftwerk sync kits

    /// The corpus splits percussion into two tiers: one near-continuous timekeeping voice at
    /// ~3.3 notes/beat with 18-20% rest, and accent voices at 0.27-0.98 with 76-93% rest. Every
    /// voice is a SINGLE pitch on a fixed every-other-step figure, separately sequenced — machine
    /// sequencing rather than a kit performance. These two rules are "with a timekeeper" and
    /// "without one".
    ///
    /// Velocities are accented but do not swing: a sequencer's per-step accent, not the
    /// hi-hat gradient that gives normal Motorik its human groove. Wood block is deliberately
    /// absent from both rules — a hard transient eight times a bar reads as knocking rather
    /// than timekeeping, and it does not belong in Motorik at all.
    private static func kraftwerkKit(ruleID: String, totalBars: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        func hit(_ bar: Int, _ step: Int, _ note: GMDrum, _ vel: UInt8 = 80) {
            events.append(MIDIEvent(stepIndex: bar * 16 + step, note: note.rawValue,
                                    velocity: vel, durationSteps: 1))
        }

        if ruleID == "MOT-DRUM-013" {
            // Four independent single-pitch voices, each on a fixed step set, every bar alike.
            //
            // The timekeeper runs eight to the bar for the whole song, so it is the one voice
            // that decides whether this rule is a groove or a nuisance. Two things keep it from
            // becoming one:
            //
            //   * It is ACCENTED, not flat. The corpus reads as flat velocity, but the Evidence
            //     Base lists that as a caveat of the fan transcriptions rather than a property
            //     of the records — and a step sequencer has a per-step accent control. Taking
            //     the transcription literally reproduced an artefact, and eight identical hits
            //     a bar with no dynamic shape is fatiguing however authentic the placement is.
            //   * It can SPLIT ACROSS TWO VOICES. The Robots spreads its percussion over eight
            //     separately sequenced single-pitch tracks, two of them hats, so beats on the
            //     closed hat and offbeats on the pedal hat is the more faithful reading as well
            //     as the more listenable one. Same eight positions, same density, two timbres.
            let splitVoices = rng.nextDouble() < 0.65
            let offbeatVoice: GMDrum = splitVoices ? .pedalHat : .closedHat
            let accent:       GMDrum = rng.nextDouble() < 0.5 ? .lowMidTom : .sidestick
            // Two accent steps drawn ONCE and held all song — the figure never varies.
            var offbeats = [2, 6, 10, 14]
            let a = offbeats.remove(at: rng.nextInt(upperBound: offbeats.count))
            let b = offbeats.remove(at: rng.nextInt(upperBound: offbeats.count))
            let accentSteps = [a, b].sorted()

            for bar in 0..<totalBars {
                for step in stride(from: 0, to: 16, by: 2) {
                    let onBeat = step % 4 == 0
                    // Step 0 carries the bar; the other beats sit just under it; the "and"
                    // steps drop well back so the ear hears quarters with filigree between.
                    let velocity: UInt8 = step == 0 ? 90 : onBeat ? 84 : 60
                    hit(bar, step, onBeat ? .closedHat : offbeatVoice, velocity)
                }
                hit(bar, 0, .kick, 92)
                hit(bar, 8, .kick, 92)
                // Measured snare density is 0.54 notes/beat — far below a backbeat, so beat 3 only.
                hit(bar, 8, .snare, 84)
                for step in accentSteps { hit(bar, step, accent, 72) }
            }
        } else {
            // MOT-DRUM-014 Sparse Accents — no timekeeper at all, under 1.5 notes/beat total.
            // The space is the point; this is the furthest departure from current Motorik drums.
            let secondKick = rng.nextDouble() < 0.5 ? 8 : 10
            let accent:    GMDrum = rng.nextDouble() < 0.5 ? .lowMidTom : .sidestick
            let accentStep = rng.nextDouble() < 0.5 ? 6 : 14

            for bar in 0..<totalBars {
                hit(bar, 0, .kick, 92)
                hit(bar, secondKick, .kick, 84)
                if bar % 2 == 0 { hit(bar, 8, .snare, 84) }
                if bar % 4 == 0 { hit(bar, accentStep, accent, 72) }
            }
        }
        return events
    }

}
