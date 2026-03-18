// DrumGenerator.swift — generation step 4
// DRM-001: Motorik classic — 4-on-the-floor, closed-hat 16ths, snare beat 3
// DRM-002: Open pocket — 4-on-the-floor, closed-hat 8ths, open hat beat 1, ghost snares
// DRM-003: Ride groove — 4-on-the-floor, ride 8ths, snare beat 3, pedal hi-hat beats 2+4

struct DrumGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        // Select groove rule for the whole song
        let ruleIndex = rng.nextInt(upperBound: 3)
        let ruleID: String
        switch ruleIndex {
        case 1:  ruleID = "DRM-002"
        case 2:  ruleID = "DRM-003"
        default: ruleID = "DRM-001"
        }
        usedRuleIDs.insert(ruleID)

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            let barStart = bar * 16

            if let intro = structure.introSection, intro.contains(bar: bar) {
                events += introPattern(bar: bar, introSection: intro, barStart: barStart, rng: &rng)
            } else if let outro = structure.outroSection, outro.contains(bar: bar) {
                events += sparseBar(barStart: barStart)
            } else {
                let intensity = section.subPhaseIntensity(atBar: bar)
                events += bodyBar(bar: bar, ruleID: ruleID, intensity: intensity, barStart: barStart, rng: &rng)
            }
        }

        return events
    }

    // MARK: - Pattern routing

    private static func introPattern(
        bar: Int, introSection: SongSection, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let offsetBar = bar - introSection.startBar
        switch offsetBar {
        case 0:
            return kickHatBar(barStart: barStart)
        case 1:
            return sparseBar(barStart: barStart)
        default:
            let isLastBar = (bar == introSection.endBar - 1)
            let useSparse = rng.nextDouble() < 0.5
            var events = useSparse ? sparseBar(barStart: barStart) : coreABar(barStart: barStart)
            if isLastBar && rng.nextDouble() < 0.35 {
                events += halfBeatFill(barStart: barStart)
            }
            return events
        }
    }

    private static func bodyBar(
        bar: Int, ruleID: String, intensity: SectionIntensity, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        switch ruleID {
        case "DRM-002": return openPocketBar(bar: bar, intensity: intensity, barStart: barStart)
        case "DRM-003": return rideGrooveBar(bar: bar, intensity: intensity, barStart: barStart)
        default:        return motorikBodyBar(bar: bar, intensity: intensity, barStart: barStart)
        }
    }

    // MARK: - DRM-001 body (Motorik classic)

    private static func motorikBodyBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        switch intensity {
        case .low:
            return sparseBar(barStart: barStart)
        case .medium:
            let phase = (bar / 8) % 2
            return phase == 0 ? coreABar(barStart: barStart) : coreBBar(barStart: barStart)
        case .high:
            return coreBBar(barStart: barStart)
        }
    }

    // MARK: - DRM-002: open pocket

    private static func openPocketBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        // 4-on-the-floor kick
        for beat in 0..<4 {
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: GMDrum.kick.rawValue, velocity: 100, durationSteps: 1))
        }
        // Closed hat on 8ths (every 2 steps)
        for step in stride(from: 0, to: 16, by: 2) {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue, velocity: 68, durationSteps: 1))
        }
        // Open hat accent on beat 1
        events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.openHat.rawValue, velocity: 80, durationSteps: 2))
        // Snare on beat 3
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.snare.rawValue, velocity: 88, durationSteps: 1))
        // Ghost snares on steps 2 and 10 at medium/high intensity
        if intensity >= .medium {
            events.append(MIDIEvent(stepIndex: barStart + 2,  note: GMDrum.snare.rawValue, velocity: 38, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.snare.rawValue, velocity: 38, durationSteps: 1))
        }
        // Extra kick at step 10 at high intensity
        if intensity == .high {
            events.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.kick.rawValue, velocity: 82, durationSteps: 1))
        }
        return events
    }

    // MARK: - DRM-003: ride groove

    private static func rideGrooveBar(bar: Int, intensity: SectionIntensity, barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        // 4-on-the-floor kick
        for beat in 0..<4 {
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: GMDrum.kick.rawValue, velocity: 100, durationSteps: 1))
        }
        // Ride cymbal on 8ths
        for step in stride(from: 0, to: 16, by: 2) {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.ride.rawValue, velocity: 72, durationSteps: 1))
        }
        // Snare on beat 3
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.snare.rawValue, velocity: 90, durationSteps: 1))
        // Pedal hi-hat on beats 2 and 4
        events.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.pedalHat.rawValue, velocity: 65, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.pedalHat.rawValue, velocity: 65, durationSteps: 1))
        // Extra kick at high intensity
        if intensity == .high {
            events.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.kick.rawValue, velocity: 85, durationSteps: 1))
        }
        return events
    }

    // MARK: - Pattern primitives

    private static func sparseBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.kick.rawValue,      velocity: 100, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 0, note: GMDrum.closedHat.rawValue, velocity: 70,  durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.closedHat.rawValue, velocity: 65,  durationSteps: 1))
        return events
    }

    private static func kickHatBar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for beat in 0..<4 {
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: GMDrum.kick.rawValue,      velocity: 100, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: GMDrum.closedHat.rawValue, velocity: 75,  durationSteps: 1))
        }
        return events
    }

    private static func coreABar(barStart: Int) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for step in 0..<16 {
            events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue, velocity: 70, durationSteps: 1))
        }
        for beat in 0..<4 {
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: GMDrum.kick.rawValue, velocity: 100, durationSteps: 1))
        }
        events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.snare.rawValue, velocity: 90, durationSteps: 1))
        return events
    }

    private static func coreBBar(barStart: Int) -> [MIDIEvent] {
        var events = coreABar(barStart: barStart)
        events.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.kick.rawValue, velocity: 85, durationSteps: 1))
        return events
    }

    private static func halfBeatFill(barStart: Int) -> [MIDIEvent] {
        return [
            MIDIEvent(stepIndex: barStart + 14, note: GMDrum.snare.rawValue, velocity: 80, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 15, note: GMDrum.snare.rawValue, velocity: 95, durationSteps: 1)
        ]
    }
}
