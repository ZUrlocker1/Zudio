// DrumGenerator.swift — generation step 4
// Motorik groove: 4-on-the-floor kick + closed hat grid + structured fills.
// Spec §Core musical behavior, §Drum pattern within-family selection.

struct DrumGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let totalSteps = frame.totalBars * 16

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            let barStart = bar * 16

            if let intro = structure.introSection, intro.contains(bar: bar) {
                events += introPattern(bar: bar, introSection: intro, barStart: barStart, rng: &rng)
            } else if let outro = structure.outroSection, outro.contains(bar: bar) {
                events += sparseBar(barStart: barStart)
            } else {
                let intensity = section.subPhaseIntensity(atBar: bar)
                events += bodyBar(bar: bar, intensity: intensity, barStart: barStart, rng: &rng)
            }

            _ = totalSteps
        }

        return events
    }

    // MARK: - Pattern builders

    /// Drums-only intro override sequence (spec §Drums-only intro override).
    private static func introPattern(
        bar: Int, introSection: SongSection, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let offsetBar = bar - introSection.startBar
        switch offsetBar {
        case 0:
            return kickHatBar(barStart: barStart)      // drum_intro_kickhat
        case 1:
            return sparseBar(barStart: barStart)       // drum_sparse
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
        bar: Int, intensity: SectionIntensity, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        switch intensity {
        case .low:
            return sparseBar(barStart: barStart)
        case .medium:
            // Core: core_a first 8 bars, core_b next 8, alternates every 8
            let phase = (bar / 8) % 2
            return phase == 0 ? coreABar(barStart: barStart) : coreBBar(barStart: barStart)
        case .high:
            return coreBBar(barStart: barStart)
        }
    }

    // MARK: - Pattern primitives (GM drum numbers from spec)

    private static func sparseBar(barStart: Int) -> [MIDIEvent] {
        // Kick beat 1 only, closed hat beats 1+3
        var events: [MIDIEvent] = []
        events.append(MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.kick.rawValue,      velocity: 100, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 0,  note: GMDrum.closedHat.rawValue, velocity: 70,  durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.closedHat.rawValue, velocity: 65,  durationSteps: 1))
        return events
    }

    private static func kickHatBar(barStart: Int) -> [MIDIEvent] {
        // 4-on-the-floor kick + every-step closed hat
        var events: [MIDIEvent] = []
        for beat in 0..<4 {
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: GMDrum.kick.rawValue,      velocity: 100, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: GMDrum.closedHat.rawValue, velocity: 75,  durationSteps: 1))
        }
        return events
    }

    private static func coreABar(barStart: Int) -> [MIDIEvent] {
        // 4-on-the-floor kick, snare beat 3, closed hat every step
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
        // core_a + extra kick at step 10
        var events = coreABar(barStart: barStart)
        events.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.kick.rawValue, velocity: 85, durationSteps: 1))
        return events
    }

    /// Tail-end 1/2-beat fill (last 2 steps of bar).
    private static func halfBeatFill(barStart: Int) -> [MIDIEvent] {
        return [
            MIDIEvent(stepIndex: barStart + 14, note: GMDrum.snare.rawValue, velocity: 80, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 15, note: GMDrum.snare.rawValue, velocity: 95, durationSteps: 1)
        ]
    }
}
