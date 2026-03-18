// DrumGenerator.swift — generation step 4
//
// Rule catalog:
//   DRM-001: Classic Motorik — kick 1+3, snare 2+4, 16th-hat velocity gradient (Apache beat)
//   DRM-002: Open Pocket — kick 1+3, snare 2+4, 8th-hat, open hat on 1, ghost snares
//   DRM-003: Ride Groove — kick 1+3, snare 2+4, ride 8ths, pedal hat 2+4
//   DRM-004: Almost Motorik — 4-on-the-floor kick, snare 2+4, 16th-hat gradient (disco/motorik hybrid)
//
// ALL patterns have snare on beats 2 AND 4 (steps 4+12). This is the defining
// characteristic of the Apache/Motorik beat — not snare on beat 3 alone.
//
// Hi-hat velocity gradient creates human groove feel:
//   Beat 1 (step 0): 80    Beat 2 (step 4): 72    Beat 3 (step 8): 78    Beat 4 (step 12): 72
//   8th offbeats (2,6,10,14): 64    16th subdivisions (odd steps): 50

struct DrumGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        // Weighted rule selection: DRM-001 50%, DRM-002 20%, DRM-003 15%, DRM-004 15%
        let ruleWeights: [Double] = [0.50, 0.20, 0.15, 0.15]
        let ruleIndex = rng.weightedPick(ruleWeights)
        let ruleID: String
        switch ruleIndex {
        case 1:  ruleID = "DRM-002"
        case 2:  ruleID = "DRM-003"
        case 3:  ruleID = "DRM-004"
        default: ruleID = "DRM-001"
        }
        usedRuleIDs.insert(ruleID)

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            let barStart = bar * 16
            let isFirstBarOfBodySection = section.startBar == bar && section.label != .intro && section.label != .outro

            if let intro = structure.introSection, intro.contains(bar: bar) {
                events += introPattern(bar: bar, introSection: intro, ruleID: ruleID, barStart: barStart, rng: &rng)
            } else if let outro = structure.outroSection, outro.contains(bar: bar) {
                events += outroPattern(bar: bar, outroSection: outro, barStart: barStart)
            } else {
                let intensity = section.subPhaseIntensity(atBar: bar)
                // Crash on first bar of each new body section
                if isFirstBarOfBodySection {
                    events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.crash1.rawValue, velocity: 95, durationSteps: 1))
                }
                events += bodyBar(bar: bar, ruleID: ruleID, intensity: intensity, barStart: barStart, rng: &rng)
            }
        }

        return events
    }

    // MARK: - Pattern routing

    private static func bodyBar(
        bar: Int, ruleID: String, intensity: SectionIntensity, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        switch ruleID {
        case "DRM-002": return openPocketBar(intensity: intensity, barStart: barStart)
        case "DRM-003": return rideGrooveBar(intensity: intensity, barStart: barStart)
        case "DRM-004": return almostMotorikBar(bar: bar, intensity: intensity, barStart: barStart)
        default:        return classicMotorikBar(bar: bar, intensity: intensity, barStart: barStart)
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
        let hatVelocities: [Int] = [80, 50, 64, 50, 72, 50, 64, 50, 78, 50, 64, 50, 72, 50, 64, 50]
        for step in 0..<16 {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: UInt8(hatVelocities[step]), durationSteps: 1))
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
        let hatVelocities: [Int] = [78, 50, 62, 50, 70, 50, 62, 50, 76, 50, 62, 50, 70, 50, 62, 50]
        for step in 0..<16 {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                    velocity: UInt8(hatVelocities[step]), durationSteps: 1))
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

    // MARK: - Intro pattern (progressive build — Hallogallo style)
    // Bar 0: kick only | Bar 1: kick + sparse hat | Bar 2-3: kick + 8th hats |
    // Bar 4+: full sparse groove | Last bar: full groove + fill

    private static func introPattern(
        bar: Int, introSection: SongSection, ruleID: String, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let offsetBar = bar - introSection.startBar
        let isLastBar = bar == introSection.endBar - 1

        switch offsetBar {
        case 0:
            // Bar 0: just the kick on 1+3 — pure pulse start
            events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue, velocity: 100, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue, velocity: 95,  durationSteps: 1))
        case 1:
            // Bar 1: kick 1+3 + hat on beats 1+3
            events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue,      velocity: 100, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue,      velocity: 95,  durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.closedHat.rawValue, velocity: 60,  durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.closedHat.rawValue, velocity: 55,  durationSteps: 1))
        case 2, 3:
            // Bars 2-3: kick 1+3 + 8th hats (no snare yet)
            for step in Swift.stride(from: 0, to: 16, by: 2) {
                let vel: UInt8 = (step % 8 == 0) ? 65 : 52
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue, velocity: vel, durationSteps: 1))
            }
            events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue, velocity: 100, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue, velocity: 95,  durationSteps: 1))
        default:
            // Remaining intro bars: sparse groove (snare enters here)
            events += motorikSparseBar(barStart: barStart)
        }

        // Last intro bar: fill into body (snare run on last 2 steps)
        if isLastBar {
            events += [
                MIDIEvent(stepIndex: barStart + 14, note: GMDrum.snare.rawValue, velocity: 82, durationSteps: 1),
                MIDIEvent(stepIndex: barStart + 15, note: GMDrum.snare.rawValue, velocity: 96, durationSteps: 1)
            ]
        }

        return events
    }

    // MARK: - Outro pattern (subtractive fade — reverses the intro build)

    private static func outroPattern(bar: Int, outroSection: SongSection, barStart: Int) -> [MIDIEvent] {
        let offsetBar = bar - outroSection.startBar
        let totalOutroBars = outroSection.lengthBars

        if offsetBar < totalOutroBars / 2 {
            return motorikSparseBar(barStart: barStart)
        } else if offsetBar < totalOutroBars - 2 {
            // Just kick 1+3 and sparse hat
            return [
                MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue,      velocity: 85, durationSteps: 1),
                MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue,      velocity: 80, durationSteps: 1),
                MIDIEvent(stepIndex: barStart + 0, note: GMDrum.closedHat.rawValue, velocity: 55, durationSteps: 1),
                MIDIEvent(stepIndex: barStart + 8, note: GMDrum.closedHat.rawValue, velocity: 50, durationSteps: 1),
            ]
        } else {
            // Final 2 bars: kick only
            return [
                MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue, velocity: 75, durationSteps: 1),
                MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue, velocity: 70, durationSteps: 1),
            ]
        }
    }
}
