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
        case 1:  ruleID = "MOT-DRUM-002"
        case 2:  ruleID = "MOT-DRUM-003"
        case 3:  ruleID = "MOT-DRUM-004"
        default: ruleID = "MOT-DRUM-001"
        }
        usedRuleIDs.insert(ruleID)

        var events: [MIDIEvent] = []

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
        case "MOT-DRUM-002": return openPocketBar(intensity: intensity, barStart: barStart)
        case "MOT-DRUM-003": return rideGrooveBar(intensity: intensity, barStart: barStart)
        case "MOT-DRUM-004": return almostMotorikBar(bar: bar, intensity: intensity, barStart: barStart)
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

    // MARK: - Intro patterns

    private static func introPattern(
        bar: Int, introSection: SongSection, ruleID: String,
        style: IntroStyle, barStart: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let offsetBar  = bar - introSection.startBar
        let totalBars  = introSection.lengthBars
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
            // Full groove from bar 0 at reduced velocity, ramping up to 100% by the last bar.
            // Sounds as if the music has been running and the listener is fading in.
            let factor = totalBars <= 1 ? 1.0 :
                0.55 + 0.45 * Double(offsetBar) / Double(totalBars - 1)
            let base = bodyBar(bar: bar, ruleID: ruleID, intensity: .low, barStart: barStart, rng: &rng)
            return withPickup(scaleVelocity(base, factor: factor))

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
            // Full groove with velocity decaying from 100% to ~30% across all outro bars.
            let factor = totalOutroBars <= 1 ? 0.30 :
                max(0.30, 1.0 - 0.70 * Double(offsetBar) / Double(totalOutroBars - 1))
            let base = bodyBar(bar: bar, ruleID: ruleID, intensity: .low, barStart: barStart, rng: &rng)
            return scaleVelocity(base, factor: factor)

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

    // MARK: - Velocity scaling utility

    private static func scaleVelocity(_ events: [MIDIEvent], factor: Double) -> [MIDIEvent] {
        events.map { ev in
            MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                      velocity: UInt8(max(1, min(127, Int(Double(ev.velocity) * factor)))),
                      durationSteps: ev.durationSteps)
        }
    }
}
