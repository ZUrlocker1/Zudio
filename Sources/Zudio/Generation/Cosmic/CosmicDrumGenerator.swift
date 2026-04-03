// KosmicDrumGenerator.swift — Kosmic drum / percussion generation
// Implements KOS-RULE-08 and KOS-RULE-18 with all four percussionStyle options.
// KOS-RULE-22: hi-hat velocity swing (ghost/accent alternation)
// KOS-RULE-21: decomposed drum voice streams
// KOS-DRUM-004: Electric Buddha groove — 8th-note hi-hat + varied kick/snare patterns (space rock feel)

import Foundation

struct KosmicDrumGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {

        switch percussionStyle {
        case .absent:
            usedRuleIDs.insert("KOS-DRUM-003")
            return []

        case .sparse:
            usedRuleIDs.insert("KOS-DRUM-002")
            return generateSparse(frame: frame, structure: structure, rng: &rng)

        case .minimal:
            usedRuleIDs.insert("KOS-DRUM-001")
            return generateMinimal(frame: frame, structure: structure, rng: &rng)

        case .motorikGrid:
            usedRuleIDs.insert("KOS-DRUM-004")
            return generateRockGroove(frame: frame, structure: structure, rng: &rng)

        case .electricBuddhaPulse:
            usedRuleIDs.insert("KOS-DRUM-005")
            return generateElectricBuddhaPulse(frame: frame, structure: structure, rng: &rng)

        case .electricBuddhaRestrained:
            usedRuleIDs.insert("KOS-DRUM-006")
            return generateElectricBuddhaRestrained(frame: frame, structure: structure, rng: &rng)

        default:
            usedRuleIDs.insert("KOS-DRUM-003")
            return []
        }
    }

    // MARK: - Sparse: dub-techno minimal groove (KOS-DRUM-002)
    // Inspired by Basic Channel / Maurizio dub techno — a real groove that holds tempo
    // without being a full drum track.
    //
    // Core pattern (every bar):
    //   Kick beat 1 (step 0)          — always, the tempo anchor
    //   Kick beat 3 (step 8)          — 72% probability, creates half-time vs full pulse variation
    //   Closed hat 8th notes          — steps 0,2,4,6,8,10,12,14, velocity 38–58, alternating
    //                                   accent/ghost for swing (on-beat hat louder than off-beat)
    //   Side stick beat 4 (step 12)   — every other bar, 75% chance — sparse backbeat
    //
    // Every 4-bar phrase: 40% chance of a "stripped" 2-bar window (hats only + kick beat 1)
    // Open hat accent step 6 or 10 every 4 bars at 35% chance — slight syncopation
    // Outro fade.

    private static func generateSparse(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let transitionBars = computeTransitionBars(structure: structure)

        // Pre-compute stripped windows (hats + beat-1 kick only) — 2 bars per 4-bar phrase
        var strippedBars = Set<Int>()
        var ph = 0
        while ph < frame.totalBars {
            if rng.nextDouble() < 0.40 {
                let offset = rng.nextInt(upperBound: 3)   // which pair in the phrase
                strippedBars.insert(ph + offset)
                strippedBars.insert(ph + offset + 1)
            }
            ph += 4
        }

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro else { continue }
            guard !section.label.isBridge else { continue }
            if transitionBars.contains(bar) && section.label != .outro {
                events += kosmicTransitionFill(barStart: bar * 16, variant: 0, rng: &rng)
                continue
            }

            let barStart = bar * 16
            let outroScale: Double
            if section.label == .outro {
                let sectionLen = max(1, section.endBar - section.startBar)
                let barInSec   = bar - section.startBar
                outroScale     = max(0.15, 1.0 - Double(barInSec) / Double(sectionLen) * 0.85)
            } else {
                outroScale = 1.0
            }

            let isStripped = strippedBars.contains(bar) && section.label != .outro

            // Closed hat — quarter notes (4 per bar), 75% per-step gate for minimal dub sparseness
            for i in 0..<4 {
                let step = i * 4
                guard rng.nextDouble() < 0.75 else { continue }
                let onBeat = (step % 8 == 0)
                let baseVel = onBeat ? (38 + rng.nextInt(upperBound: 12)) : (26 + rng.nextInt(upperBound: 10))
                let vel = Int(Double(baseVel) * outroScale)
                events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.closedHat.rawValue,
                                        velocity: UInt8(max(18, vel)), durationSteps: 1))
            }

            // Kick beat 1 — always
            let kickVel = Int(Double(58 + rng.nextInt(upperBound: 12)) * outroScale)
            events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.kick.rawValue,
                                    velocity: UInt8(max(30, kickVel)), durationSteps: 1))

            guard !isStripped else { continue }   // stripped bars: hats + beat-1 kick only

            // Kick beat 3 — 72% chance
            if rng.nextDouble() < 0.72 {
                let vel = Int(Double(50 + rng.nextInt(upperBound: 12)) * outroScale)
                events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.kick.rawValue,
                                        velocity: UInt8(max(28, vel)), durationSteps: 1))
            }

            // Side stick beat 4 (step 12) — every other bar, 75% chance
            if bar % 2 == 1 && rng.nextDouble() < 0.75 {
                let vel = Int(Double(44 + rng.nextInt(upperBound: 18)) * outroScale)
                events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.sidestick.rawValue,
                                        velocity: UInt8(max(24, vel)), durationSteps: 1))
            }

            // Open hat accent — off-beat step 6 or 10, every 4 bars, 35% chance
            if bar % 4 == 2 && rng.nextDouble() < 0.35 {
                let accentStep = rng.nextDouble() < 0.60 ? 6 : 10
                let vel = Int(Double(36 + rng.nextInt(upperBound: 16)) * outroScale)
                events.append(MIDIEvent(stepIndex: barStart + accentStep, note: GMDrum.openHat.rawValue,
                                        velocity: UInt8(max(20, vel)), durationSteps: 1))
            }
        }

        return events
    }

    // MARK: - Minimal: JMJ Mini Pops style
    // Kick beat 1 every other bar + hi-hat quarter-note pulse (KOS-RULE-22 swing)

    private static func generateMinimal(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let transitionBars = computeTransitionBars(structure: structure)

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro else { continue }

            let barStart = bar * 16

            if section.label == .bridge {
                events += bridgeA1Bar(barStart: barStart, bar: bar, section: section, rng: &rng)
                // no continue — main groove runs underneath the fills
            } else if section.label == .bridgeAlt {
                events += bridgeA2Bar(barStart: barStart, bar: bar, section: section, rng: &rng); continue
            } else if section.label == .bridgeMelody {
                events += bridgeBBar(barStart: barStart, bar: bar, section: section, rng: &rng); continue
            }
            if transitionBars.contains(bar) && section.label != .outro && !section.label.isBridge {
                events += kosmicTransitionFill(barStart: barStart, variant: 0, rng: &rng)  // minimal: v0 only
                continue
            }

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

            // Hi-hat: quarter-note pulse with ghost/accent swing (KOS-RULE-22)
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

    // MARK: - Electric Buddha Pulse: mid-weight half-time feel (KOS-DRUM-005)
    // Between minimal (every-other-bar kick, quarter hats) and the full rock groove.
    // Inspired by slower/spacier Electric Buddha Band tracks.
    // Hi-hat: quarter notes every bar (not 8th), accent on beats 1+3.
    // Kick: beat 1 every bar; beat 3 added ~45% of bars for drive.
    // Snare: half-time (beat 3 only) 65% of time; full rock (beats 2+4) 35%.
    // Open hi-hat at phrase boundary "and of 4" (step 14) every 4 bars.
    // No ghost notes — keeps the spaciousness of slower kosmic tracks.

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
        let transitionBars = computeTransitionBars(structure: structure)

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            if section.label == .intro {
                if introColdStart && bar == section.endBar - 1 {
                    events += kosmicColdStartPickup(introStyle: structure.introStyle,
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

            // Bridge and transition fill handling
            if section.label == .bridge {
                events += bridgeA1Bar(barStart: barStart, bar: bar, section: section, rng: &rng)
                // no continue — main groove runs underneath the fills
            } else if section.label == .bridgeAlt {
                events += bridgeA2Bar(barStart: barStart, bar: bar, section: section, rng: &rng); continue
            } else if section.label == .bridgeMelody {
                events += bridgeBBar(barStart: barStart, bar: bar, section: section, rng: &rng); continue
            }
            if transitionBars.contains(bar) && section.label != .outro && !section.label.isBridge {
                events += kosmicTransitionFill(barStart: barStart, variant: rng.nextInt(upperBound: 3), rng: &rng)
                continue
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

    // MARK: - Electric Buddha Groove: spacious space-rock feel (KOS-DRUM-004)
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
        let transitionBars = computeTransitionBars(structure: structure)

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            if section.label == .intro {
                if introColdStart && bar == section.endBar - 1 {
                    events += kosmicColdStartPickup(introStyle: structure.introStyle,
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

            // Bridge and transition fill handling
            if section.label == .bridge {
                events += bridgeA1Bar(barStart: barStart, bar: bar, section: section, rng: &rng)
                // no continue — main groove runs underneath the fills
            } else if section.label == .bridgeAlt {
                events += bridgeA2Bar(barStart: barStart, bar: bar, section: section, rng: &rng); continue
            } else if section.label == .bridgeMelody {
                events += bridgeBBar(barStart: barStart, bar: bar, section: section, rng: &rng); continue
            }
            if transitionBars.contains(bar) && section.label != .outro && !section.label.isBridge {
                events += kosmicTransitionFill(barStart: barStart, variant: rng.nextInt(upperBound: 3), rng: &rng)
                continue
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

    // MARK: - Electric Buddha Restrained: ride-driven with aggressive variation (KOS-DRUM-006)
    //
    // Base pattern: ride every beat, rideBell beat 1.5, pedal hat off-beats,
    // 4-on-the-floor kick (moderate vel), snare backbeat beats 2+4.
    //
    // Three layers of variation — all pre-computed so the song breathes organically:
    //
    // 1. STRIPPED ZONES (heaviest reduction, 4-6 bars):
    //    • Always placed around A↔B section transitions (2 bars before + 2 bars after boundary)
    //    • Also placed randomly every 20-32 bars (55% chance) — 4-6 bar stretches
    //    • In stripped zones: kick is always absent; dropMode forced to 0, 3, or 5
    //
    // 2. HALF-TIME KICK ZONES (subtler, 4-8 bars):
    //    • 50% chance every 8-12 bars; replaces 4-on-floor with beats 1+3 only
    //    • Floor tom ghost on beat 4 replaces the absent kick beats — lighter pulse
    //    • NOT stripped (snare + ride still full)
    //
    // 3. DROPOUT MODES per 8-bar phrase (45% chance, 2 bars):
    //    • 0: ride + pedal hat only
    //    • 1: kick + ride + rideBell (no snare, no pedal hat)
    //    • 2: snare + ride + rideBell + pedal hat (no kick)
    //    • 3: rideBell + pedal hat only (ultra-minimal)
    //    • 4: half-time kick + ride + pedal hat (no snare)
    //    • 5: ride + rideBell + sidestick beat 3 (extremely sparse)

    private static func generateElectricBuddhaRestrained(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        let introColdStart: Bool
        if case .coldStart(_) = structure.introStyle { introColdStart = true } else { introColdStart = false }

        // --- Pre-compute stripped zones ---
        var strippedBars = Set<Int>()

        // Around A↔B boundaries: 2 bars before + 2 bars after transition
        let boundaries = zip(structure.sections, structure.sections.dropFirst())
            .compactMap { (cur, nxt) -> Int? in
                guard cur.label != nxt.label,
                      !cur.label.isBridge, !nxt.label.isBridge,
                      cur.label != .intro, nxt.label != .outro else { return nil }
                return nxt.startBar
            }
        for b in boundaries {
            for bar in max(0, b - 2)..<min(frame.totalBars, b + 3) {
                strippedBars.insert(bar)
            }
        }

        // Random stripped zones every 20-32 bars
        var nextStrip = 16 + rng.nextInt(upperBound: 12)
        while nextStrip < frame.totalBars - 6 {
            if rng.nextDouble() < 0.55 {
                let len = 4 + rng.nextInt(upperBound: 3)   // 4-6 bars
                for bar in nextStrip..<min(frame.totalBars, nextStrip + len) {
                    strippedBars.insert(bar)
                }
            }
            nextStrip += 16 + rng.nextInt(upperBound: 16)
        }

        // --- Pre-compute half-time kick zones ---
        var halfTimeBars = Set<Int>()
        var nextHalf = 8 + rng.nextInt(upperBound: 6)
        while nextHalf < frame.totalBars {
            if rng.nextDouble() < 0.50 {
                let len = 4 + rng.nextInt(upperBound: 5)   // 4-8 bars
                for bar in nextHalf..<min(frame.totalBars, nextHalf + len) {
                    halfTimeBars.insert(bar)
                }
            }
            nextHalf += 8 + rng.nextInt(upperBound: 6)
        }

        // --- Per-phrase dropout modes (2-bar stretches, 45% chance) ---
        var dropoutMode = [Int: Int]()
        var phraseStart = 0
        while phraseStart < frame.totalBars {
            if rng.nextDouble() < 0.45 {
                let mode = rng.weightedPick([0.25, 0.15, 0.20, 0.15, 0.15, 0.10])
                dropoutMode[phraseStart]     = mode
                dropoutMode[phraseStart + 1] = mode
            }
            phraseStart += 8
        }

        let transitionBars = computeTransitionBars(structure: structure)

        var bodySectionEntryBars = Set<Int>()
        var prevLabel: SectionLabel? = nil
        for sec in structure.sections where sec.label != .intro && sec.label != .outro {
            if sec.label != prevLabel {
                bodySectionEntryBars.insert(sec.startBar)
                prevLabel = sec.label
            }
        }

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            if section.label == .intro {
                if introColdStart && bar == section.endBar - 1 {
                    events += kosmicColdStartPickup(introStyle: structure.introStyle,
                                                   barStart: bar * 16, rng: &rng)
                }
                continue
            }

            let barStart     = bar * 16
            let barInSection = bar - section.startBar

            if section.label == .bridge {
                events += bridgeA1Bar(barStart: barStart, bar: bar, section: section, rng: &rng)
                // no continue — main groove runs underneath the fills
            } else if section.label == .bridgeAlt {
                events += bridgeA2Bar(barStart: barStart, bar: bar, section: section, rng: &rng); continue
            } else if section.label == .bridgeMelody {
                events += bridgeBBar(barStart: barStart, bar: bar, section: section, rng: &rng); continue
            }
            if transitionBars.contains(bar) && section.label != .outro && !section.label.isBridge {
                events += kosmicTransitionFill(barStart: barStart, variant: 0, rng: &rng); continue
            }

            let outroVelScale: Double
            if section.label == .outro {
                let sectionLen = max(1, section.endBar - section.startBar)
                let progress   = Double(barInSection) / Double(sectionLen)
                outroVelScale  = max(0.20, 1.0 - progress * 0.80)
            } else {
                outroVelScale = 1.0
            }

            let isStripped  = strippedBars.contains(bar) && section.label != .outro
            let isHalfTime  = halfTimeBars.contains(bar) && !isStripped && section.label != .outro

            // In stripped zones, force to sparse modes only (0, 3, or 5)
            let rawMode = (section.label != .outro) ? dropoutMode[bar] : nil
            let dropMode: Int?
            if isStripped {
                dropMode = rng.weightedPick([0.40, 0.35, 0.25]) == 0 ? 0
                         : rng.weightedPick([0.55, 0.45]) == 0      ? 3 : 5
            } else {
                dropMode = rawMode
            }

            // Crash on section entry
            if bodySectionEntryBars.contains(bar) {
                let vel = UInt8(max(20, Int(Double(38 + rng.nextInt(upperBound: 10)) * outroVelScale)))
                events.append(MIDIEvent(stepIndex: barStart, note: GMDrum.crash2.rawValue,
                                        velocity: vel, durationSteps: 1))
            }

            // Ride: every beat — absent only in mode 3 and mode 5
            let rideActive = dropMode != 3 && dropMode != 5
            if rideActive {
                // In stripped zones reduce ride velocity further
                let baseVel = isStripped ? 32 : 43
                for beat in 0..<4 {
                    let vel = UInt8(max(10, Int(Double(baseVel + rng.nextInt(upperBound: 8)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: GMDrum.ride.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            }

            // Ride bell beat 1.5 — always present unless stripped (then 50% chance)
            if outroVelScale > 0.35 && (!isStripped || rng.nextDouble() < 0.50) {
                let vel = UInt8(max(14, Int(Double(36 + rng.nextInt(upperBound: 8)) * outroVelScale)))
                events.append(MIDIEvent(stepIndex: barStart + 2, note: GMDrum.rideBell.rawValue,
                                        velocity: vel, durationSteps: 1))
            }

            // Pedal hat off-beats — absent in modes 1 and 4 (kick-led motor feel)
            if dropMode != 1 && dropMode != 4 {
                for offbeat in [2, 6, 10, 14] {
                    let vel = UInt8(max(8, Int(Double(18 + rng.nextInt(upperBound: 12)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + offbeat, note: GMDrum.pedalHat.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            }

            // Sidestick: only in mode 5 (extremely sparse) — beat 3 (step 8)
            if dropMode == 5 {
                let vel = UInt8(max(20, Int(Double(42 + rng.nextInt(upperBound: 14)) * outroVelScale)))
                events.append(MIDIEvent(stepIndex: barStart + 8, note: GMDrum.sidestick.rawValue,
                                        velocity: vel, durationSteps: 1))
            }

            // Kick: never in stripped zones; half-time (beats 1+3) when isHalfTime or mode 4
            let kickDropout = section.label == .outro && outroVelScale < 0.4
            let kickActive  = !isStripped && (dropMode == nil || dropMode == 1 || dropMode == 4)
            if kickActive && !kickDropout {
                let useHalfTime = isHalfTime || dropMode == 4
                let kickBeats: [Int] = useHalfTime ? [0, 8] : [0, 4, 8, 12]
                for step in kickBeats {
                    let vel = UInt8(max(20, Int(Double(48 + rng.nextInt(upperBound: 10)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + step, note: GMDrum.kick.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
                // In half-time, floor tom ghost on beat 4 (step 12) fills the absent kicks
                if useHalfTime {
                    let vel = UInt8(max(12, Int(Double(22 + rng.nextInt(upperBound: 10)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.highFloorTom.rawValue,
                                            velocity: vel, durationSteps: 1))
                } else {
                    // Ghost kick anticipation beat 4.5 (step 14)
                    let vel = UInt8(max(14, Int(Double(24 + rng.nextInt(upperBound: 6)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.kick.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            }

            // Snare backbeat beats 2+4 — active in normal and mode 2 only
            let snareActive    = !isStripped && (dropMode == nil || dropMode == 2)
            let snareOutDropout = section.label == .outro && outroVelScale < 0.25
            if snareActive && !snareOutDropout {
                for snareStep in [4, 12] {
                    let vel = UInt8(max(20, Int(Double(58 + rng.nextInt(upperBound: 14)) * outroVelScale)))
                    events.append(MIDIEvent(stepIndex: barStart + snareStep, note: GMDrum.snare.rawValue,
                                            velocity: vel, durationSteps: 1))
                }
            }
        }

        return events
    }

    // MARK: - Transition fill (A→B / B→A section boundaries)
    // Replaces the normal bar pattern to signal an imminent change.
    // v0 Hat strip: sparse beats 1+3 hat + kick + snare beat 4 — "something is coming"
    // v1 Snare build: building ghost-to-full snare on back half of bar
    // v2 Tom cascade: floor→rack→snare (reverse register, descending intensity)

    private static func kosmicTransitionFill(
        barStart: Int, variant: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        func jitter(_ vel: Int) -> UInt8 { UInt8(max(20, min(127, vel + rng.nextInt(upperBound: 9) - 4))) }
        func ev(_ step: Int, _ note: GMDrum, _ vel: Int) -> MIDIEvent {
            MIDIEvent(stepIndex: barStart + step, note: note.rawValue, velocity: jitter(vel), durationSteps: 1)
        }
        switch variant {
        case 0: // Hat strip
            return [ev(0,.kick,78), ev(0,.closedHat,68), ev(8,.closedHat,60), ev(12,.snare,92)]
        case 1: // Snare build
            return [ev(0,.kick,78), ev(8,.snare,30), ev(10,.snare,55), ev(12,.snare,75), ev(14,.snare,100)]
        default: // v2: Tom cascade
            return [ev(0,.kick,78), ev(4,.lowFloorTom,70), ev(8,.hiMidTom,80), ev(12,.snare,92)]
        }
    }

    // MARK: - Bridge A-1 escalation fills (Mister Mosca archetype)
    // Fill-only overlay — the main groove generator runs underneath; this adds layered tension fills.
    // Phase 0: silence (no fills — let the groove breathe in the opening bars).
    // Phase 1: ghost snares on "and of 2" and "and of 4" — whisper tension.
    // Phase 2: ascending snare build — steps 8, 10, 12 (crescendo into beat 4).
    // Phase 3: tom cascade + crash climax — signals the B section launch.

    private static func bridgeA1Bar(
        barStart: Int, bar: Int, section: SongSection, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let bridgeLen   = max(1, section.endBar - section.startBar)
        let barInBridge = bar - section.startBar
        let phase       = min(3, barInBridge * 4 / bridgeLen)
        func j(_ vel: Int) -> UInt8 { UInt8(max(20, min(127, vel + rng.nextInt(upperBound: 7) - 3))) }
        var evs: [MIDIEvent] = []
        switch phase {
        case 0:
            break  // no fills — main groove alone
        case 1:
            // Ghost snares on "and of 2" (step 6) and "and of 4" (step 14)
            evs.append(MIDIEvent(stepIndex: barStart + 6,  note: GMDrum.snare.rawValue, velocity: j(44), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.snare.rawValue, velocity: j(48), durationSteps: 1))
        case 2:
            // Snare roll build: steps 8, 10, 12 — ascending velocity
            evs.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.snare.rawValue, velocity: j(58), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.snare.rawValue, velocity: j(66), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: j(74), durationSteps: 1))
        default:  // phase 3: tom cascade + full crash climax
            evs.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.hiMidTom.rawValue,    velocity: j(82), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.lowFloorTom.rawValue,  velocity: j(88), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue,        velocity: j(96), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.kick.rawValue,         velocity: j(100), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.crash1.rawValue,       velocity: 100,   durationSteps: 4))
        }
        return evs
    }

    // MARK: - Bridge A-2 call-and-response (Caligari Drop archetype)
    // Call bars (even): heavy kick beat 1 + hats beats 2,3,4 + snare beat 3 — bold punctuation.
    // Response bars (odd): snare pickup roll on beats 3+4 — foreshadows next call, bridges the silence.

    private static func bridgeA2Bar(
        barStart: Int, bar: Int, section: SongSection, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let barInBridge = bar - section.startBar
        func j(_ vel: Int) -> UInt8 { UInt8(max(20, min(127, vel + rng.nextInt(upperBound: 7) - 3))) }
        var evs: [MIDIEvent] = []
        if barInBridge % 2 == 0 {
            // Call bar: synchronized hit (kick), hats on off-beats, snare beat 3
            evs.append(MIDIEvent(stepIndex: barStart,      note: GMDrum.kick.rawValue,      velocity: j(100), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.closedHat.rawValue, velocity: j(60),  durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.snare.rawValue,     velocity: j(82),  durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.closedHat.rawValue, velocity: j(64),  durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.closedHat.rawValue, velocity: j(58),  durationSteps: 1))
        } else {
            // Response bar: ascending snare pickup roll building back to the next call
            evs.append(MIDIEvent(stepIndex: barStart + 8,  note: GMDrum.snare.rawValue, velocity: j(46), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 10, note: GMDrum.snare.rawValue, velocity: j(56), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: j(66), durationSteps: 1))
            evs.append(MIDIEvent(stepIndex: barStart + 14, note: GMDrum.snare.rawValue, velocity: j(76), durationSteps: 1))
        }
        return evs
    }

    // MARK: - Bridge B (Dark Sun archetype)
    // Kick beat 1, snare beats 2+4. No hats. Final 4 bars: hats gradually return.

    private static func bridgeBBar(
        barStart: Int, bar: Int, section: SongSection, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let bridgeLen   = max(1, section.endBar - section.startBar)
        let barInBridge = bar - section.startBar
        var evs: [MIDIEvent] = []
        evs.append(MIDIEvent(stepIndex: barStart,      note: GMDrum.kick.rawValue,  velocity: 72, durationSteps: 1))
        evs.append(MIDIEvent(stepIndex: barStart + 4,  note: GMDrum.snare.rawValue, velocity: 66, durationSteps: 1))
        evs.append(MIDIEvent(stepIndex: barStart + 12, note: GMDrum.snare.rawValue, velocity: 70, durationSteps: 1))
        // Final 4 bars: quietly reintroduce hats
        if barInBridge >= bridgeLen - 4 {
            let phase = barInBridge - (bridgeLen - 4)
            for beat in 0..<4 {
                let vel = UInt8(max(14, 18 + phase * 10 + beat * 5 + rng.nextInt(upperBound: 8)))
                evs.append(MIDIEvent(stepIndex: barStart + beat * 4, note: GMDrum.closedHat.rawValue,
                                     velocity: vel, durationSteps: 1))
            }
        }
        return evs
    }

    // MARK: - Compute transition bars (bar immediately before any body section label change)

    private static func computeTransitionBars(structure: SongStructure) -> Set<Int> {
        Set(zip(structure.sections, structure.sections.dropFirst())
            .compactMap { (cur, next) -> Int? in
                guard cur.label != .intro && next.label != .outro else { return nil }
                guard cur.label != next.label else { return nil }
                return max(0, next.startBar - 1)
            })
    }

    // MARK: - Cold start pickup (Electric Buddha style)

    /// Generates a drum fill in the last intro bar that leads into the body downbeat.
    /// drumsOnly = true → starts at step 8 (last 2 beats); false → starts at step 4 (last 3 beats).
    ///
    /// Five variants selected randomly:
    ///   v0  Hat Crescendo     — 16th-note closed hat run, single snare on step 14, silence step 15.
    ///   v1  Bonham Launch     — tom cascade hi→floor from beat 3, snare step 14, silence step 15.
    ///   v2  Crescendo Roll    — ghost snare roll building exponentially, peaks step 14, silence step 15.
    ///   v3  Manchester Ride   — soft ride cymbal throughout, ghost snares, sparse kick (atmospheric).
    ///   v4  Indie Disco       — kick+snare hits with ghost snares and tom, high energy.
    ///
    /// All variants: no notes on step 15 (1-step gap so bar 1 beat 1 kick+crash arrives clean).
    private static func kosmicColdStartPickup(
        introStyle: IntroStyle,
        barStart: Int,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let drumsOnly: Bool
        if case .coldStart(let d) = introStyle { drumsOnly = d } else { return [] }

        // drumsOnly: start at step 8 (2-beat pickup); bass also present: step 4 (3-beat)
        let fromStep = drumsOnly ? 8 : 4
        let variant = rng.nextInt(upperBound: 5)

        let pattern: [(step: Int, note: UInt8, vel: Int)]

        switch variant {

        case 0: // Hat Crescendo — 16th-note closed hats building from beat 2 or 3, snare climax
            let hatSteps: [(step: Int, vel: Int)] = [
                (4,  45), (5,  50), (6,  55), (7,  60),
                (8,  58), (9,  63), (10, 68), (11, 73),
                (12, 78), (13, 85),
            ]
            pattern = hatSteps.map { ($0.step, GMDrum.closedHat.rawValue, $0.vel) }
                    + [(14, GMDrum.snare.rawValue, 100)]

        case 1: // Bonham Launch — tom cascade from beat 3 into snare, inspired by 2-beat Bonham fill.
            // 3-beat variant (fromStep=4): precede with hats on beats 2–2.5 to fill the space.
            let hatPrefix: [(step: Int, note: UInt8, vel: Int)] = [
                (4, GMDrum.closedHat.rawValue, 45),
                (5, GMDrum.closedHat.rawValue, 52),
                (6, GMDrum.closedHat.rawValue, 58),
                (7, GMDrum.closedHat.rawValue, 64),
            ]
            let tomCascade: [(step: Int, note: UInt8, vel: Int)] = [
                (8,  GMDrum.hiTom.rawValue,        72),
                (9,  GMDrum.hiTom.rawValue,        76),
                (10, GMDrum.hiMidTom.rawValue,     80),
                (11, GMDrum.lowMidTom.rawValue,    84),
                (12, GMDrum.lowFloorTom.rawValue,  88),
                (13, GMDrum.highFloorTom.rawValue, 94),
                (14, GMDrum.snare.rawValue,        105),
            ]
            pattern = hatPrefix + tomCascade

        case 2: // Crescendo Roll — ghost snare roll building exponentially to full accent.
            // Steps 4–14 (or 8–14 for 2-beat), velocity curve 18→105, silence on 15.
            let rollStart = 4
            let rollEnd   = 14   // inclusive; step 15 stays silent
            let count = rollEnd - rollStart + 1
            pattern = (rollStart...rollEnd).map { s in
                let i = s - rollStart
                let t = Double(i) / Double(count - 1)
                let vel = Int(18 + t * t * 87)  // exponential 18→105
                return (s, GMDrum.snare.rawValue, vel)
            }

        case 3: // Manchester Ride — atmospheric ride-driven pickup, very soft (EB bluebird style)
            // Ride cymbal on every even step, ghost snare on beat 2.5 (step 6) and beat 4 (step 12)
            pattern = [
                (4,  GMDrum.ride.rawValue,      42),
                (5,  GMDrum.ride.rawValue,      40),
                (6,  GMDrum.ride.rawValue,      45),
                (6,  GMDrum.snare.rawValue,     35),   // ghost snare beat 2.5
                (7,  GMDrum.ride.rawValue,      42),
                (8,  GMDrum.ride.rawValue,      48),
                (9,  GMDrum.ride.rawValue,      45),
                (10, GMDrum.ride.rawValue,      50),
                (11, GMDrum.ride.rawValue,      47),
                (12, GMDrum.ride.rawValue,      55),
                (12, GMDrum.snare.rawValue,     55),   // snare on beat 4
                (13, GMDrum.ride.rawValue,      52),
                (14, GMDrum.ride.rawValue,      62),   // ride accent before downbeat
            ]

        default: // Indie Disco — kick+snare hits with ghost snares and low-mid tom
            // Beat 2 launch: kick+snare+hat, then ghost snares + kicks through beat 3-4
            pattern = [
                (4,  GMDrum.kick.rawValue,      80),
                (4,  GMDrum.snare.rawValue,     72),
                (4,  GMDrum.closedHat.rawValue, 60),
                (6,  GMDrum.hiMidTom.rawValue,  68),
                (7,  GMDrum.snare.rawValue,     42),   // ghost snare
                (8,  GMDrum.kick.rawValue,      85),
                (9,  GMDrum.snare.rawValue,     78),
                (10, GMDrum.snare.rawValue,     48),   // ghost snare
                (11, GMDrum.kick.rawValue,      88),
                (12, GMDrum.lowMidTom.rawValue, 82),
                (14, GMDrum.snare.rawValue,     100),  // snare accent before downbeat
            ]
        }

        var events: [MIDIEvent] = []
        for (step, note, vel) in pattern {
            guard step >= fromStep else { continue }
            let finalVel = UInt8(max(20, min(127, vel + rng.nextInt(upperBound: 11) - 5)))
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: finalVel, durationSteps: 1))
        }
        return events
    }
}
