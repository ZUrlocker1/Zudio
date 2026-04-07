// ChillPadsGenerator.swift — Chill generation step 5 (Pads track)
// Pads = sustained harmonic layer (Warm Pad default) — NOT Rhodes comping.
// Three pad modes: chord sustain (70%), staggered entry (20%), absent (10%).
// All voicings snapped to scale (CHL-SYNC-004).
// Per-note audio fade-in/fade-out is handled by PlaybackEngine.chillPadsMode (boost node ramp),
// not via MIDI velocity — identical mechanism to Ambient bass/pads.

import Foundation

struct ChillPadsGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        breakdownStyle: ChillBreakdownStyle,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let roll = rng.nextDouble()
        var events: [MIDIEvent]
        if roll < 0.70 {
            usedRuleIDs.insert("CHL-PAD-001")
            events = chordSustain(frame: frame, structure: structure, rng: &rng)
        } else if roll < 0.90 {
            usedRuleIDs.insert("CHL-PAD-002")
            events = staggeredEntry(frame: frame, structure: structure, rng: &rng)
        } else {
            usedRuleIDs.insert("CHL-PAD-003")
            events = []  // absent — texture-only songs
        }
        // Overlay breakdown pad behavior based on breakdown style
        events += breakdownPad(frame: frame, structure: structure, breakdownStyle: breakdownStyle, rng: &rng)

        // Cold start: bar 0 is drums-only, pads silent
        if case .coldStart = structure.introStyle {
            events = events.filter { $0.stepIndex >= 16 }
        }

        // Cold stop: last 2 outro bars are drums-only, pads silent
        if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
            let silenceFrom = (outroEnd - 2) * 16
            events = events.filter { $0.stepIndex < silenceFrom }
        }

        return events
    }

    // MARK: - CHL-PAD-001: Chord sustain (Long Lake Winter Strings model)

    /// One sustained chord per 2–4 bars; held for most of the window; half-note rhythm.
    /// Velocity: 55–70 (mid-mix presence, not background whisper per Long Lake Winter analysis).
    private static func chordSustain(frame: GlobalMusicalFrame, structure: SongStructure,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scaleIntervals = frame.mode.intervals

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A
            let chord   = structure.chordPlan.first { $0.contains(bar: bar) }
            let base    = bar * 16

            // Pads are silent in breakdown (breakdownPad() handles bridge for all modes)
            if label == .bridge { continue }

            // Build upper-structure jazz voicing for this bar's chord
            let chordRootPC = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12
            let voiceNotes  = buildUpperStructure(chordRootPC: chordRootPC,
                                                   chordType: chord?.chordType ?? .min7,
                                                   scaleIntervals: scaleIntervals,
                                                   keyRoot: frame.keySemitoneValue,
                                                   register: 60)  // mid register for pads

            // Only emit new sustain on renewal bars (every 2–4 bars within each chord window)
            let windowStart = chord?.startBar ?? 0
            let barInWindow = bar - windowStart
            let period = 2 + rng.nextInt(upperBound: 3)  // 2, 3, or 4 bars
            guard barInWindow % period == 0 else { continue }

            // Velocity: consistent across sections; the dynamic arc in SongGenerator handles intro/outro fading.
            let baseVel = 40 + rng.nextInt(upperBound: 16)  // 40–55

            let holdBars   = Swift.min(period, (chord?.endBar ?? frame.totalBars) - bar)
            let holdSteps  = max(4, holdBars * 16 - 10)  // 10-step gap before renewal so fade-out is audible

            for note in voiceNotes {
                let vel = UInt8(Swift.max(20, Swift.min(90, baseVel + rng.nextInt(upperBound: 6) - 3)))
                events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: vel,
                                        durationSteps: holdSteps))
            }
        }
        return events
    }

    // MARK: - CHL-PAD-002: Staggered entry (Air / Winter Flight model)

    /// Four pad voices entering 8 bars apart, same harmonic content, different registers.
    /// Creates a natural swell without automation.
    private static func staggeredEntry(frame: GlobalMusicalFrame, structure: SongStructure,
                                        rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scaleIntervals = frame.mode.intervals

        // Find the first groove section start
        let grooveStart = structure.sections.first { $0.label == .A }?.startBar ?? 0

        // Each of 4 voices enters 8 bars after the previous
        let entryBars = [grooveStart, grooveStart + 8, grooveStart + 16, grooveStart + 24]
        let voiceRegisters = [48, 60, 72, 84]  // low → high

        for (voiceIdx, entryBar) in entryBars.enumerated() {
            guard entryBar < frame.totalBars else { continue }
            let register = voiceRegisters[voiceIdx]

            // Hold from entry to end of song (or end of non-breakdown sections)
            for bar in entryBar..<frame.totalBars {
                let section = structure.section(atBar: bar)
                if section?.label == .bridge { continue }

                let chord = structure.chordPlan.first { $0.contains(bar: bar) }
                let chordRootPC = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12

                // Only emit on chord change bars (or first bar)
                let windowStart = chord?.startBar ?? 0
                guard bar == windowStart || bar == entryBar else { continue }

                let vel = UInt8(40 + rng.nextInt(upperBound: 16))  // 40–55; arc handles intro/outro fading

                let holdBars = Swift.min(chord.map { $0.endBar - bar } ?? 4,
                                          frame.totalBars - bar)
                let holdSteps = max(4, holdBars * 16 - 10)  // 10-step gap before renewal so fade-out is audible

                // Single note per voice: the chord degree appropriate to the voice index
                let degree = [0, 3, 7, 10][voiceIdx]  // root, 3rd, 5th, 7th
                let notePC = (chordRootPC + degree) % 12
                // Snap to scale
                let snappedPC = scaleIntervals
                    .map { (frame.keySemitoneValue + $0) % 12 }
                    .min(by: { abs($0 - notePC) < abs($1 - notePC) }) ?? notePC
                // Correct pitch-class-to-MIDI: find note near register with pitch class snappedPC
                let targetPC = register % 12
                let semisUp = (snappedPC - targetPC + 12) % 12
                var note = register + semisUp
                while note < 36 { note += 12 }
                while note > 96 { note -= 12 }
                let clampedNote = note

                events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(clampedNote),
                                        velocity: vel, durationSteps: holdSteps))
            }
        }
        return events
    }

    // MARK: - Breakdown pad (all modes, CHL-SYNC-009)

    /// Breakdown pad behavior depends on breakdown style:
    /// - stopTime: staccato chord stab (4 steps) on beat 1 of every other bar (the unison hit)
    /// - bassOstinato: completely silent — bass carries the groove alone
    /// - harmonicDrone: whisper sustain vel 25–40, renewed every 4 bars (barely there warmth)
    private static func breakdownPad(frame: GlobalMusicalFrame, structure: SongStructure,
                                      breakdownStyle: ChillBreakdownStyle,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        guard breakdownStyle != .bassOstinato else { return [] }
        var events: [MIDIEvent] = []
        let scaleIntervals = frame.mode.intervals
        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            guard section?.label == .bridge else { continue }
            let chord = structure.chordPlan.first { $0.contains(bar: bar) }
            let chordRootPC = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12
            let voiceNotes  = buildUpperStructure(chordRootPC: chordRootPC,
                                                   chordType: chord?.chordType ?? .sus4,
                                                   scaleIntervals: scaleIntervals,
                                                   keyRoot: frame.keySemitoneValue,
                                                   register: 60)
            let base = bar * 16
            let breakdownBar = bar - (section?.startBar ?? bar)

            switch breakdownStyle {
            case .stopTime:
                if breakdownBar % 2 == 0 {
                    // Even bars: staccato stab on beat 1 synchronized with the drum/bass hit
                    for note in voiceNotes {
                        let vel = UInt8(52 + rng.nextInt(upperBound: 10))  // slightly raised
                        events.append(MIDIEvent(stepIndex: base, note: UInt8(note),
                                                velocity: vel, durationSteps: 4))
                    }
                } else {
                    // Odd (silence) bars: sustained chord reveal — notes enter bottom to top on
                    // beats 2, 3, 4 and each sustains to beat 1 of the next bar, so the full
                    // voicing accumulates and is already ringing when the hit lands.
                    let sorted = voiceNotes.sorted()
                    let n = sorted.count
                    // Step offsets: 4 (beat 2), 8 (beat 3), 12 (beat 4)
                    // Duration: sustain to step 16 from bar start, i.e. 16 - stepOffset
                    if n >= 1 {
                        let vel = UInt8(48 + rng.nextInt(upperBound: 10))
                        events.append(MIDIEvent(stepIndex: base + 4,  note: UInt8(sorted[0]),
                                                velocity: vel, durationSteps: 12))
                    }
                    if n >= 2 {
                        let vel = UInt8(55 + rng.nextInt(upperBound: 10))
                        events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(sorted[1]),
                                                velocity: vel, durationSteps: 8))
                    }
                    if n >= 3 {
                        let vel = UInt8(62 + rng.nextInt(upperBound: 10))
                        for note in sorted.suffix(n > 3 ? 2 : 1) {
                            events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(note),
                                                    velocity: vel, durationSteps: 4))
                        }
                    }
                }
            case .bassOstinato:
                break  // handled by guard above
            case .harmonicDrone:
                // Whisper sustain renewed every 4 bars — barely audible harmonic warmth
                guard breakdownBar % 4 == 0 else { continue }
                let holdBars  = Swift.min(4, frame.totalBars - bar)
                let holdSteps = holdBars * 16 - 2
                for note in voiceNotes {
                    let vel = UInt8(Swift.max(18, Swift.min(40, 25 + rng.nextInt(upperBound: 15))))
                    events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: vel,
                                            durationSteps: holdSteps))
                }
            }
        }
        return events
    }

    // MARK: - Voicing helper

    /// Upper-structure voicing: [3rd, 5th, 7th] spread over 2 octaves, root omitted.
    /// All intervals snapped to active scale (CHL-SYNC-004).
    private static func buildUpperStructure(chordRootPC: Int, chordType: ChordType,
                                             scaleIntervals: [Int], keyRoot: Int,
                                             register: Int) -> [Int] {
        let scalePCs = Set(scaleIntervals.map { (keyRoot + $0) % 12 })

        // Chord intervals above root — 4-note upper structure (3rd, 5th, 7th, 9th);
        // root omitted (bass covers it); voicing spread across 2 octaves (CHL-RULE-03).
        let rawIntervals: [Int]
        switch chordType {
        case .min7:   rawIntervals = [3, 7, 10, 14]   // b3, 5, b7, 9
        case .major:  rawIntervals = [4, 7, 11, 14]   // 3, 5, maj7, 9
        case .dom7:   rawIntervals = [4, 7, 10, 14]   // 3, 5, b7, 9
        case .sus4:   rawIntervals = [5, 7, 10, 14]   // 4, 5, b7, 9
        case .add9:   rawIntervals = [4, 7, 10, 14]   // 3, 5, b7, 9
        default:      rawIntervals = [3, 7, 10, 14]
        }

        var notes: [Int] = []
        for (i, interval) in rawIntervals.enumerated() {
            var pc = (chordRootPC + interval) % 12
            // Snap non-scale PCs to nearest scale tone
            if !scalePCs.contains(pc) {
                pc = scalePCs.min(by: { abs($0 - pc) < abs($1 - pc) }) ?? pc
            }
            // Spread 4 voices across 2 octaves: voices 0–1 in lower octave, voices 2–3 upper.
            // Use correct pitch-class-to-MIDI mapping: find the nearest note at/above
            // (register + octaveOffset) that has pitch class pc.
            let octaveOffset = i < 2 ? 0 : 12
            let target = register + octaveOffset
            let targetPC = target % 12
            let semisUp = (pc - targetPC + 12) % 12
            var note = target + semisUp
            // Keep within pads register
            while note < 48 { note -= 12 }
            while note > 84 { note -= 12 }
            notes.append(note)
        }
        return notes
    }
}
