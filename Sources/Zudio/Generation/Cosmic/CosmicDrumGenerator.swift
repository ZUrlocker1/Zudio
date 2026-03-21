// CosmicDrumGenerator.swift — Cosmic drum / percussion generation
// Implements COS-RULE-08 and COS-RULE-18 with all four percussionStyle options.
// COS-RULE-22: hi-hat velocity swing (ghost/accent alternation)
// COS-RULE-21: decomposed drum voice streams
// COS-DRUM-004: Electric Buddha groove — 8th-note hi-hat + varied kick/snare patterns (space rock feel)

import Foundation

struct CosmicDrumGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {

        switch percussionStyle {
        case .absent:
            usedRuleIDs.insert("COS-DRUM-003")
            return []

        case .sparse:
            usedRuleIDs.insert("COS-DRUM-002")
            return generateSparse(frame: frame, structure: structure, rng: &rng)

        case .minimal:
            usedRuleIDs.insert("COS-DRUM-001")
            return generateMinimal(frame: frame, structure: structure, rng: &rng)

        case .motorikGrid:
            usedRuleIDs.insert("COS-DRUM-004")
            return generateRockGroove(frame: frame, structure: structure, rng: &rng)

        case .electricBuddhaPulse:
            usedRuleIDs.insert("COS-DRUM-005")
            return generateElectricBuddhaPulse(frame: frame, structure: structure, rng: &rng)

        default:
            usedRuleIDs.insert("COS-DRUM-003")
            return []
        }
    }

    // MARK: - Sparse: pitched percussion on root and fifth (COS-RULE-08)
    // One event every 4–8 beats. Use pitched drum notes (low tom, floor tom).

    private static func generateSparse(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Sparse interval: one event every 4–8 beats = every 16–32 steps
        var nextEventStep = 0

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro else { continue }

            let barStart = bar * 16

            for step in 0..<16 {
                let absStep = barStart + step
                guard absStep >= nextEventStep else { continue }

                // Root hit (MIDI 41 = low floor tom) or fifth hit (MIDI 43 = high floor tom)
                // These are pitched at approximately the right feel (COS-RULE-08)
                let useRoot = rng.nextDouble() < 0.60
                let note: UInt8 = useRoot ? GMDrum.lowFloorTom.rawValue : GMDrum.highFloorTom.rawValue
                var vel = 40 + rng.nextInt(upperBound: 26)  // 40–65
                // Outro: fade velocity
                if section.label == .outro {
                    let sectionLen = max(1, section.endBar - section.startBar)
                    let barInSec   = bar - section.startBar
                    let progress   = Double(barInSec) / Double(sectionLen)
                    vel = max(20, Int(Double(vel) * (1.0 - progress * 0.70)))
                }
                events.append(MIDIEvent(stepIndex: absStep, note: note, velocity: UInt8(vel), durationSteps: 1))

                // Schedule next event 4–8 beats (16–32 steps) later
                nextEventStep = absStep + 16 + rng.nextInt(upperBound: 17)
            }
        }

        return events
    }

    // MARK: - Minimal: JMJ Mini Pops style
    // Kick beat 1 every other bar + hi-hat quarter-note pulse (COS-RULE-22 swing)

    private static func generateMinimal(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro else { continue }

            let barStart = bar * 16

            // Outro: velocity decays over section (kick drops out in second half)
            let outroVelScale: Double
            if section.label == .outro {
                let sectionLen  = max(1, section.endBar - section.startBar)
                let barInSec    = bar - section.startBar
                let progress    = Double(barInSec) / Double(sectionLen)
                outroVelScale   = max(0.28, 1.0 - progress * 0.72)
                // Kick: only first half of outro
                if bar % 2 == 0 && progress < 0.5 {
                    let vel = UInt8(max(20, Int(Double(55 + rng.nextInt(upperBound: 15)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.kick.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            } else {
                outroVelScale = 1.0
                // Kick: beat 1 only, every other bar (very sparse)
                if bar % 2 == 0 {
                    events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.kick.rawValue,
                                            velocity: UInt8(55 + rng.nextInt(upperBound: 15)),
                                            durationSteps: 1))
                }
            }

            // Hi-hat: quarter-note pulse with ghost/accent swing (COS-RULE-22)
            for beat in 0..<4 {
                let beatStep = barStart + beat * 4
                let isAccent = beat % 2 == 0  // accent on beats 1 and 3
                let baseVel: Double = isAccent
                    ? Double(75 + rng.nextInt(upperBound: 21))
                    : Double(35 + rng.nextInt(upperBound: 21))
                let vel = UInt8(max(18, Int(baseVel * outroVelScale)))
                events.append(MIDIEvent(stepIndex: beatStep, note: GMDrum.closedHat.rawValue,
                                        velocity: vel, durationSteps: 1))
            }
        }

        return events
    }

    // MARK: - Electric Buddha Pulse: mid-weight half-time feel (COS-DRUM-005)
    // Between minimal (every-other-bar kick, quarter hats) and the full rock groove.
    // Inspired by slower/spacier Electric Buddha Band tracks.
    // Hi-hat: quarter notes every bar (not 8th), accent on beats 1+3.
    // Kick: beat 1 every bar; beat 3 added ~45% of bars for drive.
    // Snare: half-time (beat 3 only) 65% of time; full rock (beats 2+4) 35%.
    // Open hi-hat at phrase boundary "and of 4" (step 14) every 4 bars.
    // No ghost notes — keeps the spaciousness of slower cosmic tracks.

    private static func generateElectricBuddhaPulse(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Pre-check: does the intro end with a cold start pickup?
        let introColdStart: Bool
        if case .coldStart(_) = structure.introStyle { introColdStart = true } else { introColdStart = false }

        // Decide snare mode at song level for cohesion; flip at section boundaries
        var halfTimeSnare = rng.nextDouble() < 0.65  // true = snare on beat 3 only
        var addKickBeat3  = rng.nextDouble() < 0.45
        var nextChange    = 0

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            if section.label == .intro {
                if introColdStart && bar == section.endBar - 1 {
                    events += cosmicColdStartPickup(introStyle: structure.introStyle,
                                                   barStart: bar * 16, rng: &rng)
                }
                continue
            }

            let barStart     = bar * 16
            let barInSection = bar - section.startBar

            // Re-roll groove decisions every 8 bars at phrase boundaries
            if bar >= nextChange {
                halfTimeSnare = rng.nextDouble() < 0.65
                addKickBeat3  = rng.nextDouble() < 0.45
                nextChange    = bar + 8
            }

            let outroVelScale: Double
            if section.label == .outro {
                let sectionLen = max(1, section.endBar - section.startBar)
                let progress   = Double(barInSection) / Double(sectionLen)
                outroVelScale  = max(0.25, 1.0 - progress * 0.75)
            } else {
                outroVelScale = 1.0
            }

            // Hi-hat: quarter notes (steps 0, 4, 8, 12), accent on 1+3
            for i in 0..<4 {
                let step     = i * 4
                let isAccent = step == 0 || step == 8
                let baseVel: Double = isAccent
                    ? Double(72 + rng.nextInt(upperBound: 18))  // 72–89
                    : Double(38 + rng.nextInt(upperBound: 24))  // 38–61
                let vel = UInt8(max(14, Int(baseVel * outroVelScale)))
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                        velocity: vel, durationSteps: 1))
            }

            // Open hi-hat at phrase boundary "and of 4" (step 14)
            if barInSection % 4 == 3 && outroVelScale > 0.4 {
                let vel = UInt8(max(20, Int(Double(60 + rng.nextInt(upperBound: 16)) * outroVelScale)))
                events.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.openHat.rawValue,
                                        velocity: vel, durationSteps: 2))
            }

            // Kick: always beat 1; beat 3 conditionally
            let kickDropout = section.label == .outro && outroVelScale < 0.5
            if !kickDropout {
                let kickSteps = addKickBeat3 ? [0, 8] : [0]
                for kickStep in kickSteps {
                    let vel = UInt8(max(20, Int(Double(66 + rng.nextInt(upperBound: 14)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + kickStep, note: GMDrum.kick.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            }

            // Snare: half-time (beat 3, step 8) or full rock (beats 2+4, steps 4+12)
            let snareDropout = section.label == .outro && outroVelScale < 0.3
            if !snareDropout {
                let snareSteps = halfTimeSnare ? [8] : [4, 12]
                for snareStep in snareSteps {
                    let vel = UInt8(max(20, Int(Double(74 + rng.nextInt(upperBound: 18)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + snareStep, note: GMDrum.snare.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            }
        }

        return events
    }

    // MARK: - Electric Buddha Groove: spacious space-rock feel (COS-DRUM-004)
    // Inspired by Electric Buddha Band (Time Loops, Dark Sun, Mister Mosca, Caligari Drop).
    // Hi-hat: 8th-note pulse (not 16th) — half the density of Motorik, more air.
    // Kick/snare: 5 pattern variants rotate every 4 bars for groove without monotony.
    // Pattern variants:
    //   0 (35%): standard rock — kick 1+3, snare 2+4
    //   1 (22%): pushed kick — kick 1+"and of 2" (step 6), snare 2+4
    //   2 (18%): syncopated kick — kick 1+"and of 3" (step 10), snare 2+4
    //   3 (15%): half-time — kick 1 only, snare on beat 3 (step 8)
    //   4 (10%): half-time with drive — kick 1+3, snare on beat 3 (step 8)
    // Open hi-hat accent at phrase boundaries (bar 3, 7, 11… step 14 = "and of 4").
    // Ghost snare (28% per bar) one 16th before beat 2.
    // Intro: skipped. Outro: velocity fades; kick drops out second half.

    private static func generateRockGroove(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Pre-check: does the intro end with a cold start pickup?
        let introColdStart: Bool
        if case .coldStart(_) = structure.introStyle { introColdStart = true } else { introColdStart = false }

        let kickPatterns:  [[Int]] = [[0, 8], [0, 6], [0, 10], [0],    [0, 8]]
        let snarePatterns: [[Int]] = [[4, 12], [4, 12], [4, 12], [8],  [8]]
        let patternWeights: [Double] = [0.35, 0.22, 0.18, 0.15, 0.10]

        var kickPat  = kickPatterns[0]
        var snarePat = snarePatterns[0]
        var nextChange = 0

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            if section.label == .intro {
                if introColdStart && bar == section.endBar - 1 {
                    events += cosmicColdStartPickup(introStyle: structure.introStyle,
                                                   barStart: bar * 16, rng: &rng)
                }
                continue
            }

            let barStart     = bar * 16
            let barInSection = bar - section.startBar

            // Rotate pattern at 4-bar phrase boundaries
            if bar >= nextChange {
                let idx  = rng.weightedPick(patternWeights)
                kickPat  = kickPatterns[idx]
                snarePat = snarePatterns[idx]
                nextChange = bar + 4
            }

            let outroVelScale: Double
            if section.label == .outro {
                let sectionLen = max(1, section.endBar - section.startBar)
                let progress   = Double(barInSection) / Double(sectionLen)
                outroVelScale  = max(0.25, 1.0 - progress * 0.75)
            } else {
                outroVelScale = 1.0
            }

            // Hi-hat: 8th notes (steps 0, 4, 8, 12) — accent on beats 1+3
            for i in 0..<4 {
                let step     = i * 4
                let isAccent = step == 0 || step == 8
                let baseVel: Double = isAccent
                    ? Double(70 + rng.nextInt(upperBound: 16))  // 70–85
                    : Double(42 + rng.nextInt(upperBound: 22))  // 42–63
                let vel = UInt8(max(14, Int(baseVel * outroVelScale)))
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                        velocity: vel, durationSteps: 1))
            }

            // Open hi-hat at phrase boundary on "and of 4" (step 14 = bar 3, 7, 11 …)
            if barInSection % 4 == 3 && outroVelScale > 0.4 {
                let vel = UInt8(max(20, Int(Double(63 + rng.nextInt(upperBound: 16)) * outroVelScale)))
                events.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.openHat.rawValue,
                                        velocity: vel, durationSteps: 2))
            }

            // Kick — drops out in second half of outro
            let kickDropout = section.label == .outro && outroVelScale < 0.5
            if !kickDropout {
                for kickStep in kickPat {
                    let vel = UInt8(max(20, Int(Double(68 + rng.nextInt(upperBound: 12)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + kickStep, note: GMDrum.kick.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            }

            // Snare — drops out near end of outro
            let snareDropout = section.label == .outro && outroVelScale < 0.3
            if !snareDropout {
                for snareStep in snarePat {
                    let vel = UInt8(max(20, Int(Double(76 + rng.nextInt(upperBound: 16)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + snareStep, note: GMDrum.snare.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
                // Ghost snare: 28% chance, one 16th before beat 2 (step 3)
                if snarePat.contains(4) && rng.nextDouble() < 0.28 {
                    let vel = UInt8(max(14, Int(Double(20 + rng.nextInt(upperBound: 16)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + 3, note: GMDrum.snare.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            }
        }

        return events
    }

    // MARK: - Cold start pickup (Electric Buddha style)

    /// Generates a drum fill in the last intro bar that leads into the body downbeat.
    /// drumsOnly = true → starts at step 8 (last 2 beats); false → starts at step 4 (last 3 beats).
    /// Pattern: escalating hi-hat run + kick + snare flam → crash on step 15 to launch bar 1.
    /// Inspired by Time Loops (bar 0 beat 0.8 Neo Soul fill), Caligari Drop (bar 0 beat 2.7 fill).
    private static func cosmicColdStartPickup(
        introStyle: IntroStyle,
        barStart: Int,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let drumsOnly: Bool
        if case .coldStart(let d) = introStyle { drumsOnly = d } else { return [] }

        // drumsOnly: start at step 8 (2-beat pickup); bass also present: step 4 (3-beat)
        let fromStep = drumsOnly ? 8 : 4

        // Pattern: kick anchors beat 3, then hats build continuously through beat 4
        // with NO kick on beat 4 (that was the stutter — two kicks in quick succession
        // made beat 4 sound like a false landing). Snare accent on "and of 4" and
        // "ah of 4" launch into the crash on bar 1 beat 1.
        let pattern: [(step: Int, note: UInt8, vel: Int)] = [
            (4,  GMDrum.closedHat.rawValue, 50),
            (6,  GMDrum.closedHat.rawValue, 56),
            (8,  GMDrum.kick.rawValue,      72),   // beat 3 kick — groove anchor
            (8,  GMDrum.closedHat.rawValue, 62),
            (10, GMDrum.closedHat.rawValue, 70),
            (12, GMDrum.closedHat.rawValue, 80),   // beat 4 — hat continues, no kick
            (13, GMDrum.closedHat.rawValue, 88),   // e of 4 — building
            (14, GMDrum.snare.rawValue,     88),   // and of 4 — main accent
            (14, GMDrum.openHat.rawValue,   72),
            (15, GMDrum.snare.rawValue,     100),  // ah of 4 — launch
            (15, GMDrum.crash1.rawValue,    105),
        ]

        var events: [MIDIEvent] = []
        for (step, note, vel) in pattern {
            guard step >= fromStep else { continue }
            // Slight velocity randomisation (±8)
            let finalVel = UInt8(max(20, min(127, vel + rng.nextInt(upperBound: 17) - 8)))
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: finalVel, durationSteps: 1))
        }
        return events
    }
}
