// ChillRhythmGenerator.swift — Chill generation step 7 (Rhythm track)
// Copyright (c) 2026 Zack Urlocker
// Rhythm = Rhodes active comping (Electric Piano 1, program 4).
// Four comping modes: St Germain syncopated (Bright/Free), Moby backbeat (Deep/Dream),
// Bosa Moon arpeggiated (Bright/Free), Acid jazz stab groove (hipHopJazz).
// Voicings: upper-structure jazz [3rd, 5th, 7th] — root omitted (CHL-SYNC-004).
// Silent in breakdown and intro (CHL-RHY rules).

import Foundation

struct ChillRhythmGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        mood: Mood,
        beatStyle: ChillBeatStyle = .electronic,
        breakdownStyle: ChillBreakdownStyle = .bassOstinato,
        bluesVariation: Bool = false,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let compingMode: CompingMode
        if bluesVariation {
            // Blues: mobyBackbeat 70%, stGermainSyncopated 30% — open to all moods.
            compingMode = rng.nextDouble() < 0.70 ? .mobyBackbeat : .stGermainSyncopated
        } else if beatStyle == .hipHopJazz {
            compingMode = .acidJazzStab
        } else {
            compingMode = pickCompingMode(mood: mood, rng: &rng)
        }
        usedRuleIDs.insert(compingMode.ruleID)
        // Blues intro: keyboard enters at bar 1 (50%) or bar 3 (50%) — not from bar 0.
        let bluesKeyboardBar: Int = bluesVariation ? (rng.nextDouble() < 0.50 ? 1 : 3) : 0
        return generateComping(frame: frame, structure: structure,
                                compingMode: compingMode, breakdownStyle: breakdownStyle,
                                bluesVariation: bluesVariation, bluesKeyboardBar: bluesKeyboardBar,
                                rng: &rng)
    }

    // MARK: - Comping modes

    private enum CompingMode {
        case stGermainSyncopated   // CHL-RHY-001
        case mobyBackbeat          // CHL-RHY-002
        case bosaMoonArpeggiated   // CHL-RHY-003
        case acidJazzStab          // CHL-RHY-004

        var ruleID: String {
            switch self {
            case .stGermainSyncopated: return "CHL-RHY-001"
            case .mobyBackbeat:        return "CHL-RHY-002"
            case .bosaMoonArpeggiated: return "CHL-RHY-003"
            case .acidJazzStab:        return "CHL-RHY-004"
            }
        }
    }

    private static func pickCompingMode(mood: Mood, rng: inout SeededRNG) -> CompingMode {
        switch mood {
        case .Deep:
            // Backbeat 50%, Syncopated 25%, Arpeggiated 25%
            let roll = rng.nextDouble()
            if roll < 0.50 { return .mobyBackbeat }
            if roll < 0.75 { return .stGermainSyncopated }
            return .bosaMoonArpeggiated
        case .Dream:
            // Backbeat 50%, Arpeggiated 30%, Syncopated 20%
            let roll = rng.nextDouble()
            if roll < 0.50 { return .mobyBackbeat }
            if roll < 0.80 { return .bosaMoonArpeggiated }
            return .stGermainSyncopated
        case .Free:
            // Syncopated 50%, Arpeggiated 50%
            return rng.nextDouble() < 0.50 ? .stGermainSyncopated : .bosaMoonArpeggiated
        case .Bright:
            // Arpeggiated 40%, Syncopated 40%, Backbeat 20%
            let roll = rng.nextDouble()
            if roll < 0.40 { return .bosaMoonArpeggiated }
            if roll < 0.80 { return .stGermainSyncopated }
            return .mobyBackbeat
        }
    }

    // MARK: - Main generator

    private static func generateComping(frame: GlobalMusicalFrame, structure: SongStructure,
                                         compingMode: CompingMode,
                                         breakdownStyle: ChillBreakdownStyle,
                                         bluesVariation: Bool = false,
                                         bluesKeyboardBar: Int = 0,
                                         rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scalePCs  = frame.scalePCs
        let snapTable = ChillPadsGenerator.makeSnapTable(scalePCs)

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Cold start: bar 0 is drums-only, rhythm silent
            if case .coldStart = structure.introStyle, bar == 0 { continue }

            // Cold stop: final bar silent; crash bar gets a chord stab landing with the crash.
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar >= outroEnd - 1 { continue }
                if bar == outroEnd - 2 {
                    let chord   = structure.chordPlan.first { $0.contains(bar: bar) }
                    let voicing = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
                    let base    = bar * 16
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: 92, durationSteps: 3))
                    }
                    continue
                }
            }

            // Outro: always silent
            if label == .outro { continue }
            // Intro: silent unless blues (keyboard enters at bluesKeyboardBar)
            if label == .intro {
                if !bluesVariation { continue }
                let introStart = structure.introSection?.startBar ?? 0
                if bar - introStart < bluesKeyboardBar { continue }
                // Fall through to normal comping for remaining intro bars
            }

            // Breakdown handling
            if label == .bridge {
                let breakdownBar = bar - (section?.startBar ?? bar)
                let chord   = structure.chordPlan.first { $0.contains(bar: bar) }
                let base    = bar * 16
                let sectionLen = section?.lengthBars ?? 4

                if breakdownStyle == .groovePocket {
                    // Rhythm plays straight through — fall through to normal comping below.
                    // For 8-bar pockets, overlay escalating tension stabs in bars 6–8.
                    if sectionLen >= 8 && breakdownBar >= 5 {
                        let voicing    = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
                        let tensionBar = breakdownBar - 5   // 0 = bar 6, 1 = bar 7, 2 = bar 8
                        let stabSteps: [Int]
                        switch tensionBar {
                        case 0:  stabSteps = [8]           // bar 6: beat 3
                        case 1:  stabSteps = [8, 12]       // bar 7: beats 3+4
                        default: stabSteps = [4, 8, 12]    // bar 8: beats 2+3+4
                        }
                        for step in stabSteps {
                            let vel = UInt8(Swift.min(95, 68 + tensionBar * 8 + rng.nextInt(upperBound: 10)))
                            for note in voicing {
                                events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note),
                                                        velocity: vel, durationSteps: 3))
                            }
                        }
                    }
                    // Fall through — normal comping runs below
                } else if breakdownStyle == .stopTime && breakdownBar % 2 == 1 {
                    // Odd (silence) bars: chord reveal — play voicing bottom to top on beats 2, 3, 4.
                    let sorted = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable).sorted()
                    let n = sorted.count
                    if n >= 1 {
                        events.append(MIDIEvent(stepIndex: base + 4,  note: UInt8(sorted[0]),
                                                velocity: UInt8(60 + rng.nextInt(upperBound: 10)), durationSteps: 3))
                    }
                    if n >= 2 {
                        events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(sorted[1]),
                                                velocity: UInt8(70 + rng.nextInt(upperBound: 10)), durationSteps: 3))
                    }
                    if n >= 3 {
                        let vel = UInt8(80 + rng.nextInt(upperBound: 10))
                        for note in sorted.suffix(n > 3 ? 2 : 1) {
                            events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(note),
                                                    velocity: vel, durationSteps: 3))
                        }
                    }
                    continue
                } else if breakdownStyle == .bassOstinato {
                    // Bass ostinato: one beat-2 chord stab keeps harmonic context
                    let voicing = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
                    let vel     = UInt8(42 + rng.nextInt(upperBound: 12))
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: base + 4, note: UInt8(note), velocity: vel, durationSteps: 4))
                    }
                    continue
                } else {
                    continue  // .harmonicDrone and .stopTime even bars: silent
                }
            }

            let chord     = structure.chordPlan.first { $0.contains(bar: bar) }
            let voicing   = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
            let base      = bar * 16

            switch compingMode {
            case .stGermainSyncopated:
                events += stGermainSyncopated(base: base, voicing: voicing, bar: bar,
                                               sectionStart: section?.startBar ?? 0,
                                               rng: &rng)
            case .mobyBackbeat:
                events += mobyBackbeat(base: base, voicing: voicing, bar: bar, rng: &rng)
            case .bosaMoonArpeggiated:
                events += bosaMoonArpeggiated(base: base, voicing: voicing, frame: frame,
                                               chord: chord, bar: bar,
                                               sectionStart: section?.startBar ?? 0,
                                               rng: &rng)
            case .acidJazzStab:
                events += acidJazzStab(base: base, voicing: voicing, bar: bar, rng: &rng)
            }
        }
        return events
    }

    // MARK: - CHL-RHY-001: St Germain Syncopated

    /// Beat 1 + syncopated second hit per bar. After 16 bars:
    /// second hit slides from AND-of-2 (step 6) to AND-of-3 (step 10) every 16 bars;
    /// every 4th bar becomes a single-hit bar (beat 1 only) for breathing room.
    private static func stGermainSyncopated(base: Int, voicing: [Int],
                                             bar: Int, sectionStart: Int,
                                             rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        let barInSection = bar - sectionStart
        let period16     = barInSection / 16

        // Variation 2: second-hit position shifts every 16 bars.
        // Period 0, 2, 4… → AND of beat 2 (step 6, original).
        // Period 1, 3, 5… → AND of beat 3 (step 10, one beat later).
        let secondHitStep = period16 % 2 == 0 ? 6 : 10

        // Variation 3: sparse single-hit bar every 4 bars, starting from bar 16 of section.
        // Sparse bars also use shell voicing [3rd, 7th] — drop the 5th for a lighter touch.
        let isSparseBar   = period16 >= 1 && barInSection % 4 == 3
        let activeVoicing = isSparseBar && voicing.count >= 3
            ? [voicing[0], voicing[voicing.count - 1]]
            : voicing

        // Beat 1 downbeat: always present
        let vel1 = UInt8(75 + rng.nextInt(upperBound: 11))
        for note in activeVoicing {
            events.append(MIDIEvent(stepIndex: base + 0, note: UInt8(note), velocity: vel1, durationSteps: 5))
        }

        if !isSparseBar {
            // Second syncopated hit
            let vel2 = UInt8(70 + rng.nextInt(upperBound: 11))
            for note in voicing {
                events.append(MIDIEvent(stepIndex: base + secondHitStep, note: UInt8(note),
                                        velocity: vel2, durationSteps: 5))
            }
            // Occasional fill at AND of beat 3 or beat 4 (skip if second hit is already at step 10)
            if rng.nextDouble() < 0.30 {
                let fillStep = secondHitStep == 6
                    ? (rng.nextDouble() < 0.50 ? 10 : 14)
                    : 14   // period 1: second hit is at 10, so fill can only go to 14
                let vel3 = UInt8(55 + rng.nextInt(upperBound: 11))
                for note in voicing {
                    events.append(MIDIEvent(stepIndex: base + fillStep, note: UInt8(note),
                                            velocity: vel3, durationSteps: 3))
                }
            }
        }
        return events
    }

    // MARK: - CHL-RHY-002: Moby Backbeat

    /// Chord strikes on beats 2 and 4, with bar-by-bar variation so no 8 bars sound identical.
    ///
    /// Four patterns cycle every 4 bars (bar % 4), giving each 4-bar phrase a distinct texture:
    ///   0 — standard shell: beats 2+4, 2-note shell voicing
    ///   1 — add AND-of-3: beats 2+4 shell + soft ghost hit at step 10 (AND of beat 3)
    ///   2 — inversion: beats 2+4, full 3-note voicing in second inversion (top note dropped)
    ///   3 — shifted beat 2: beat 2 anticipates to step 2 (AND of beat 1); beat 4 normal
    ///
    /// Additionally, 15% chance either beat fires alone (unchanged), and a 20% chance of
    /// an extra staccato fill on step 6 (AND of beat 2) at very low velocity — subtle syncopation.
    private static func mobyBackbeat(base: Int, voicing: [Int], bar: Int,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard !voicing.isEmpty else { return events }

        let onlyBeat2 = rng.nextDouble() < 0.15
        let onlyBeat4 = !onlyBeat2 && rng.nextDouble() < 0.15

        // Pattern variant driven by bar position — changes every 4 bars
        let variant = bar % 4

        // Voicing selection by variant
        let shellVoicing   = voicing.count >= 2 ? Array(voicing.prefix(2)) : voicing
        let fullVoicing    = voicing
        // Second inversion: rotate so highest note comes first (drop it down one octave conceptually —
        // achieved here by reversing the sorted list to put the upper note first, giving a different
        // density feel when sustained notes overlap)
        let invertVoicing  = voicing.count >= 3 ? Array(voicing.dropFirst()) : shellVoicing

        let beat2Voicing: [Int]
        let beat4Voicing: [Int]
        let beat2Step: Int
        let beat4Step: Int = 12

        switch variant {
        case 1:
            // Add AND-of-3 ghost hit (step 10) at low velocity
            beat2Voicing = shellVoicing
            beat4Voicing = shellVoicing
            beat2Step    = 4
        case 2:
            // Full inversion on both beats — different density
            beat2Voicing = invertVoicing
            beat4Voicing = fullVoicing
            beat2Step    = 4
        case 3:
            // Anticipate beat 2 to AND of beat 1 (step 2) — creates forward lean
            beat2Voicing = shellVoicing
            beat4Voicing = shellVoicing
            beat2Step    = 2
        default:
            // Variant 0: standard shell
            beat2Voicing = shellVoicing
            beat4Voicing = shellVoicing
            beat2Step    = 4
        }

        if !onlyBeat4 {
            let vel = UInt8(65 + rng.nextInt(upperBound: 11))
            for note in beat2Voicing {
                events.append(MIDIEvent(stepIndex: base + beat2Step, note: UInt8(note),
                                        velocity: vel, durationSteps: 5))
            }
        }
        if !onlyBeat2 {
            let vel = UInt8(60 + rng.nextInt(upperBound: 11))
            for note in beat4Voicing {
                events.append(MIDIEvent(stepIndex: base + beat4Step, note: UInt8(note),
                                        velocity: vel, durationSteps: 4))
            }
        }

        // Variant 1: AND-of-3 ghost hit at step 10 (very soft)
        if variant == 1 && !onlyBeat2 && !onlyBeat4 {
            let ghostVel = UInt8(40 + rng.nextInt(upperBound: 10))
            for note in shellVoicing {
                events.append(MIDIEvent(stepIndex: base + 10, note: UInt8(note),
                                        velocity: ghostVel, durationSteps: 2))
            }
        }

        // 20% chance: extra syncopated fill at step 6 (AND of beat 2), very quiet
        if rng.nextDouble() < 0.20 && !onlyBeat2 && !onlyBeat4 {
            let fillVel = UInt8(38 + rng.nextInt(upperBound: 10))
            let fillNote = shellVoicing.first ?? voicing[0]
            events.append(MIDIEvent(stepIndex: base + 6, note: UInt8(fillNote),
                                    velocity: fillVel, durationSteps: 2))
        }

        return events
    }

    // MARK: - CHL-RHY-003: Bosa Moon Arpeggiated

    /// Chord tones played sequentially on 8th-note grid (~10 notes/bar).
    /// 30–40% chance of block chord on step 0 or step 8.
    /// After 16 bars: direction flips every 16 bars; sparse quarter-note bar every 4 bars.
    private static func bosaMoonArpeggiated(base: Int, voicing: [Int],
                                             frame: GlobalMusicalFrame,
                                             chord: ChordWindow?,
                                             bar: Int,
                                             sectionStart: Int,
                                             rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard !voicing.isEmpty else { return events }

        let barInSection = bar - sectionStart
        let period16     = barInSection / 16   // increments every 16 bars within the section

        // Variation 2: direction flip every 16 bars.
        // Period 0, 2, 4… → ascending then descending (original feel).
        // Period 1, 3, 5… → descending then ascending (mirror feel).
        let arpPool = period16 % 2 == 0
            ? voicing + voicing.reversed()
            : voicing.reversed() + voicing

        // Variation 3: sparse quarter-note bar every 4 bars, starting from bar 16 of the section.
        // Shell voicing [3rd, 7th] — drop the 5th for a lighter harmonic touch on the sparse bar.
        let isSparseBar = period16 >= 1 && barInSection % 4 == 3
        if isSparseBar {
            let shellVoicing = voicing.count >= 3
                ? [voicing[0], voicing[voicing.count - 1]]
                : voicing
            for step in [0, 4, 8, 12] {
                let vel = UInt8(63 + rng.nextInt(upperBound: 14))
                for note in shellVoicing {
                    events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note), velocity: vel, durationSteps: 6))
                }
            }
            return events
        }

        // Dense bar: 8th-note grid, steps 0, 2, 4, 6, 8, 10, 12, 14
        for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
            let note = arpPool[i % arpPool.count]
            let vel  = UInt8(70 + rng.nextInt(upperBound: 16))
            events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note), velocity: vel, durationSteps: 3))
        }

        // Block chord accent on step 0 or step 8 (30–40% chance)
        if rng.nextDouble() < 0.35 {
            let accentStep = rng.nextDouble() < 0.50 ? 0 : 8
            let accentVel = UInt8(80 + rng.nextInt(upperBound: 16))
            for note in voicing {
                events.append(MIDIEvent(stepIndex: base + accentStep, note: UInt8(note),
                                        velocity: accentVel, durationSteps: 4))
            }
        }
        return events
    }

    // MARK: - CHL-RHY-004: Acid Jazz Stab Groove

    /// CHL-RHY-004: Four syncopated dyad stabs per bar in a repeating cell, derived from
    /// the measured Cantaloop keyboard groove. Stabs land on AND positions — off the beat —
    /// never on beat 1. Voicing is a 2-note dyad (top two notes: 5th + 7th), close position.
    /// Staccato: each stab is 2 steps. Velocity ~55–70 (lighter feel for Chill mix).
    /// Every 4 bars, one "sparse bar" fires only 2 stabs for breathing room.
    /// Target density: ~8 note events/bar (4 stabs × 2 notes); sparse bar ~4 events/bar.
    private static func acidJazzStab(base: Int, voicing: [Int], bar: Int,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard voicing.count >= 2 else { return events }

        // 2-note dyad: top two notes of voicing (5th + 7th) — upper shell, root omitted
        let dyad = Array(voicing.suffix(2))

        // Sparse bar every 4 bars — only 2 stabs (breathing room)
        let isSparseBar = (bar % 4 == 3)

        let stabPositions: [Int]
        if isSparseBar {
            // Two stabs: AND of beat 1, AND of beat 4
            stabPositions = [2, 14]
        } else {
            // Four stabs: AND of 1, AND of 2, beat 3, AND of 4 — syncopated but not every 16th
            stabPositions = [2, 6, 8, 14]
        }

        for step in stabPositions {
            let vel = UInt8(55 + rng.nextInt(upperBound: 16))
            for note in dyad {
                events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note),
                                        velocity: vel, durationSteps: 2))
            }
        }
        return events
    }

    // MARK: - Voicing helper

    /// Upper-structure voicing: [3rd, 5th, 7th] in mid register MIDI 48–72.
    /// Root omitted — bass covers it (CHL-SYNC-004).
    /// All notes snapped to scale (CHL-SYNC-001).
    private static func buildVoicing(frame: GlobalMusicalFrame, chord: ChordWindow?,
                                      baseRegister: Int, snapTable: [Int]) -> [Int] {
        let chordRoot  = chord?.chordRoot ?? "1"
        let chordType  = chord?.chordType ?? .min7
        let chordRootPC = (frame.keySemitoneValue + degreeSemitone(chordRoot)) % 12

        let intervals: [Int]
        switch chordType {
        case .min7:   intervals = [3, 7, 10]
        case .major:  intervals = [4, 7, 11]
        case .dom7:   intervals = [4, 7, 10]
        case .sus4:   intervals = [5, 7, 10]
        default:      intervals = [3, 7, 10]
        }

        var notes: [Int] = []
        for interval in intervals {
            let pc = snapTable[(chordRootPC + interval) % 12]
            // Close-position voicing: all three notes in the same register.
            // Previously the 7th was offset +12, creating a 15-semitone open spread that
            // sounded harsh on clavinet. One octave of space is all we need here.
            let target = baseRegister
            let targetPC = target % 12
            let semisUp = (pc - targetPC + 12) % 12
            var note = target + semisUp
            while note < 48 { note -= 12 }
            while note > 72 { note -= 12 }
            notes.append(note)
        }
        return notes
    }
}
