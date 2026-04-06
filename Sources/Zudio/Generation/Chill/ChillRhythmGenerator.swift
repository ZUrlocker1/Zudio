// ChillRhythmGenerator.swift — Chill generation step 7 (Rhythm track)
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
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        // Hip-hop jazz beat style always uses the acid jazz stab groove
        let compingMode: CompingMode
        if beatStyle == .hipHopJazz {
            compingMode = .acidJazzStab
        } else {
            compingMode = pickCompingMode(mood: mood, rng: &rng)
        }
        usedRuleIDs.insert(compingMode.ruleID)
        return generateComping(frame: frame, structure: structure,
                                compingMode: compingMode, breakdownStyle: breakdownStyle, rng: &rng)
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
        case .Deep, .Dream:
            return .mobyBackbeat
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
                                         rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Cold start: bar 0 is drums-only, rhythm silent
            if case .coldStart = structure.introStyle, bar == 0 { continue }

            // Cold stop: last 2 outro bars are drums-only, rhythm silent
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar,
               bar >= outroEnd - 2 { continue }

            // Intro and outro: silent
            if label == .intro || label == .outro { continue }

            // Breakdown: silent except bass ostinato — one beat-2 chord keeps harmonic context
            if label == .bridge {
                if breakdownStyle == .bassOstinato {
                    let chord   = structure.chordPlan.first { $0.contains(bar: bar) }
                    let voicing = buildVoicing(frame: frame, chord: chord, baseRegister: 52)
                    let base    = bar * 16
                    let vel     = UInt8(42 + rng.nextInt(upperBound: 12))
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: base + 4, note: UInt8(note), velocity: vel, durationSteps: 4))
                    }
                }
                continue
            }

            let chord     = structure.chordPlan.first { $0.contains(bar: bar) }
            let voicing   = buildVoicing(frame: frame, chord: chord, baseRegister: 52)
            let base      = bar * 16

            switch compingMode {
            case .stGermainSyncopated:
                events += stGermainSyncopated(base: base, voicing: voicing, rng: &rng)
            case .mobyBackbeat:
                events += mobyBackbeat(base: base, voicing: voicing, rng: &rng)
            case .bosaMoonArpeggiated:
                events += bosaMoonArpeggiated(base: base, voicing: voicing, frame: frame,
                                               chord: chord, rng: &rng)
            case .acidJazzStab:
                events += acidJazzStab(base: base, voicing: voicing, bar: bar, rng: &rng)
            }
        }
        return events
    }

    // MARK: - CHL-RHY-001: St Germain Syncopated

    /// Chord strikes on beat 1 (step 0) and AND of beat 2 (step 6) — matching St Germain
    /// "So Flute" piano: steps 1 and 7 in the MIDI (0-indexed: 0 and 6).
    /// Occasional fill on step 10 or 14 (AND of beat 3 or beat 4) at 30%.
    private static func stGermainSyncopated(base: Int, voicing: [Int],
                                             rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        // Beat 1 downbeat: step 0
        let vel1 = UInt8(75 + rng.nextInt(upperBound: 11))
        for note in voicing {
            events.append(MIDIEvent(stepIndex: base + 0, note: UInt8(note), velocity: vel1, durationSteps: 5))
        }
        // AND of beat 2: step 6
        let vel2 = UInt8(70 + rng.nextInt(upperBound: 11))
        for note in voicing {
            events.append(MIDIEvent(stepIndex: base + 6, note: UInt8(note), velocity: vel2, durationSteps: 5))
        }
        // Occasional fill at step 10 (AND of beat 3) or step 14 (AND of beat 4)
        if rng.nextDouble() < 0.30 {
            let fillStep = rng.nextDouble() < 0.50 ? 10 : 14
            let vel3 = UInt8(55 + rng.nextInt(upperBound: 11))
            for note in voicing {
                events.append(MIDIEvent(stepIndex: base + fillStep, note: UInt8(note), velocity: vel3, durationSteps: 3))
            }
        }
        return events
    }

    // MARK: - CHL-RHY-002: Moby Backbeat

    /// Chord strikes on beats 2 (step 4) and 4 (step 12) only.
    /// Shell voicing [root, 5th, 7th]. 30% chance only one strike fires per bar.
    private static func mobyBackbeat(base: Int, voicing: [Int],
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let onlyBeat2 = rng.nextDouble() < 0.15
        let onlyBeat4 = !onlyBeat2 && rng.nextDouble() < 0.15
        let shellVoicing = voicing.count >= 2 ? Array(voicing.prefix(2)) : voicing  // shell: 2 notes

        if !onlyBeat4 {
            let vel = UInt8(65 + rng.nextInt(upperBound: 11))
            for note in shellVoicing {
                events.append(MIDIEvent(stepIndex: base + 4, note: UInt8(note), velocity: vel, durationSteps: 5))
            }
        }
        if !onlyBeat2 {
            let vel = UInt8(60 + rng.nextInt(upperBound: 11))
            for note in shellVoicing {
                events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(note), velocity: vel, durationSteps: 4))
            }
        }
        return events
    }

    // MARK: - CHL-RHY-003: Bosa Moon Arpeggiated

    /// Chord tones played sequentially on 8th-note grid (~10 notes/bar).
    /// 30–40% chance of block chord on step 0 or step 8.
    private static func bosaMoonArpeggiated(base: Int, voicing: [Int],
                                             frame: GlobalMusicalFrame,
                                             chord: ChordWindow?,
                                             rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard !voicing.isEmpty else { return events }

        // Build extended arpeggiation pool: cycle through voicing ascending then descending
        let arpPool = voicing + voicing.reversed()
        // 8th-note grid: steps 0, 2, 4, 6, 8, 10, 12, 14
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
    /// never on beat 1. Voicing is a 2-note dyad (top two notes: 5th + 7th). Staccato:
    /// each stab is 1–2 steps. Velocity uniform ~76–89 (programmed feel, minimal dynamics).
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
            let vel = UInt8(76 + rng.nextInt(upperBound: 14))
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
                                      baseRegister: Int) -> [Int] {
        let chordRoot  = chord?.chordRoot ?? "1"
        let chordType  = chord?.chordType ?? .min7
        let chordRootPC = (frame.keySemitoneValue + degreeSemitone(chordRoot)) % 12
        let scalePCs   = Set(frame.mode.intervals.map { (frame.keySemitoneValue + $0) % 12 })

        let intervals: [Int]
        switch chordType {
        case .min7:   intervals = [3, 7, 10]
        case .major:  intervals = [4, 7, 11]
        case .dom7:   intervals = [4, 7, 10]
        case .sus4:   intervals = [5, 7, 10]
        default:      intervals = [3, 7, 10]
        }

        var notes: [Int] = []
        for (i, interval) in intervals.enumerated() {
            var pc = (chordRootPC + interval) % 12
            if !scalePCs.contains(pc) {
                pc = scalePCs.min(by: { abs($0 - pc) < abs($1 - pc) }) ?? pc
            }
            // Correct pitch-class-to-MIDI: find nearest note at/above (baseRegister + octaveOffset)
            // with pitch class pc. Avoids the subtraction bug that produced wrong pitch classes.
            let octaveOffset = i == 2 ? 12 : 0
            let target = baseRegister + octaveOffset
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
