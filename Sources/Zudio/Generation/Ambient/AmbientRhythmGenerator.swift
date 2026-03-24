// AmbientRhythmGenerator.swift — Ambient rhythm/arpeggio generation
// AMB-RTHM-004 (60%): silent
// AMB-RTHM-001 (18%): single tone pulse — sparse repeated note, velocity 30–54
// AMB-RTHM-002 (9%):  sparse arpeggio — 3–4 chord tones cycled slowly
// AMB-RTHM-003 (4%):  stochastic phrase — random scale tones, 12% hit rate per window
// AMB-RTHM-005 (5%):  celestial phrase — ascending major pentatonic gesture, 4–5 notes
// AMB-RTHM-006 (4%):  bell cell — root → fifth → octave, 1–2× per loop with long silences
// Generates a short loop; AmbientLoopTiler tiles to full song length.

import Foundation

struct AmbientRhythmGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {
        let bounds    = kRegisterBounds[kTrackRhythm]!  // low:45, high:76
        let loopSteps = loopBars * 16
        let scalePCs  = Set(frame.mode.intervals.map { (frame.keySemitoneValue + $0) % 12 })
        let scaleNotes = notes(pitchClasses: scalePCs, low: bounds.low, high: bounds.high)
        guard !scaleNotes.isEmpty else { return [] }

        // Resolve rule — forced overrides random roll
        let ruleID: String
        if let forced = forceRuleID {
            ruleID = forced
        } else {
            let roll = rng.nextDouble()
            if roll < 0.60      { ruleID = "AMB-RTHM-004" }
            else if roll < 0.78 { ruleID = "AMB-RTHM-001" }
            else if roll < 0.87 { ruleID = "AMB-RTHM-002" }
            else if roll < 0.91 { ruleID = "AMB-RTHM-003" }
            else if roll < 0.96 { ruleID = "AMB-RTHM-005" }
            else                { ruleID = "AMB-RTHM-006" }
        }
        usedRuleIDs.insert(ruleID)

        switch ruleID {
        case "AMB-RTHM-004": return []
        case "AMB-RTHM-001": return singleTonePulse(notes: scaleNotes, loopSteps: loopSteps, rng: &rng)
        case "AMB-RTHM-002":
            let chordPCs   = tonalMap.entry(atBar: 0)?.chordWindow.chordTones ?? scalePCs
            let chordNotes = notes(pitchClasses: chordPCs, low: bounds.low, high: bounds.high)
            return sparseArpeggio(notes: chordNotes.isEmpty ? scaleNotes : chordNotes,
                                   loopSteps: loopSteps, rng: &rng)
        case "AMB-RTHM-003": return stochasticPhrase(notes: scaleNotes, loopSteps: loopSteps, rng: &rng)
        case "AMB-RTHM-005": return celestialPhrase(frame: frame, loopSteps: loopSteps, rng: &rng)
        default:             return bellCell(frame: frame, loopSteps: loopSteps, rng: &rng)
        }
    }

    // MARK: - Rules

    private static func singleTonePulse(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let note     = notes[rng.nextInt(upperBound: notes.count)]
        let interval = 12 + rng.nextInt(upperBound: 13)   // every 12–24 steps (3–6 beats)
        var events: [MIDIEvent] = []
        var step = rng.nextInt(upperBound: interval)
        while step < loopSteps {
            if rng.nextDouble() < 0.40 {   // ~40% hit rate — most potential positions are silent
                let vel = UInt8(28 + rng.nextInt(upperBound: 25))  // 28–52
                events.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: 2))
            }
            step += interval
        }
        return events
    }

    private static func sparseArpeggio(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let pool = Array(notes.prefix(4))   // max 4 notes
        guard !pool.isEmpty else { return [] }
        var events: [MIDIEvent] = []
        var step   = rng.nextInt(upperBound: 16)
        var idx    = 0
        while step < loopSteps {
            let vel = UInt8(30 + rng.nextInt(upperBound: 28))  // 30–57
            events.append(MIDIEvent(stepIndex: step, note: pool[idx % pool.count],
                                    velocity: vel, durationSteps: 3))
            idx  += 1
            step += 16 + rng.nextInt(upperBound: 17)  // 16–32 steps between notes (1–2 bars)
        }
        return events
    }

    private static func celestialPhrase(frame: GlobalMusicalFrame, loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let bounds = kRegisterBounds[kTrackRhythm]!
        // Major pentatonic (root, M2, M3, P5, M6) — deliberately major-feel, ignores modal context
        let rootPC    = frame.keySemitoneValue % 12
        let pentPCs   = Set([0, 2, 4, 7, 9].map { (rootPC + $0) % 12 })
        let pentNotes = (bounds.low...bounds.high).compactMap { n -> UInt8? in
            pentPCs.contains(n % 12) ? UInt8(n) : nil
        }
        guard pentNotes.count >= 4 else { return [] }

        let noteCount = 4 + rng.nextInt(upperBound: 2)             // 4 or 5 notes
        let maxStart  = max(0, Int(Double(pentNotes.count) * 0.55) - noteCount)
        let startIdx  = maxStart > 0 ? rng.nextInt(upperBound: maxStart) : 0
        let phrase    = Array(pentNotes[startIdx..<min(startIdx + noteCount, pentNotes.count)])

        let holdSteps = 8 + rng.nextInt(upperBound: 5)             // 8–12 steps per note
        let gapSteps  = 2 + rng.nextInt(upperBound: 3)             // 2–4 steps between notes
        let phraseLen = phrase.count * (holdSteps + gapSteps)
        guard phraseLen < loopSteps else { return [] }
        let offset    = rng.nextInt(upperBound: loopSteps - phraseLen)

        var events: [MIDIEvent] = []
        var step = offset
        for note in phrase {
            let vel = UInt8(33 + rng.nextInt(upperBound: 20))      // 33–52, gentle
            events.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: holdSteps))
            step += holdSteps + gapSteps
        }
        return events
    }

    /// AMB-RTHM-006: Bell cell — root → fifth → octave, 4 steps each, 1–2× per loop.
    /// Long silences (6+ bars) between repetitions. With reverb, the three tones bloom together.
    private static func bellCell(frame: GlobalMusicalFrame, loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let bounds = kRegisterBounds[kTrackRhythm]!
        let rootPC = frame.keySemitoneValue % 12

        // Find root in lower portion of register with enough headroom for an octave
        var rootNote = bounds.low
        for n in bounds.low...(bounds.high - 12) {
            if n % 12 == rootPC { rootNote = n; break }
        }
        guard rootNote + 12 <= bounds.high else { return [] }

        let cell: [UInt8] = [UInt8(rootNote), UInt8(rootNote + 7), UInt8(rootNote + 12)]
        let noteDur  = 4                                   // 4 steps per note = 1 beat
        let noteGap  = 2                                   // 2-step gap within cell
        let cellLen  = cell.count * (noteDur + noteGap)
        let minGap   = 6 * 16                              // 6-bar minimum between repetitions

        let reps = 1 + rng.nextInt(upperBound: 2)          // 1–2 per loop
        guard loopSteps >= cellLen * reps + minGap * (reps - 1) else { return [] }

        var events: [MIDIEvent] = []
        var cursor = rng.nextInt(upperBound: Swift.max(1, loopSteps / 4))   // start in first quarter

        for _ in 0..<reps {
            guard cursor + cellLen <= loopSteps else { break }
            for (i, note) in cell.enumerated() {
                let step = cursor + i * (noteDur + noteGap)
                guard step < loopSteps else { break }
                let vel = UInt8(38 + i * 7 + rng.nextInt(upperBound: 8))   // blooms: ~38, ~45, ~52
                events.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: noteDur))
            }
            cursor += cellLen + minGap + rng.nextInt(upperBound: 16)
        }
        return events
    }

    private static func stochasticPhrase(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        var step = 0
        while step < loopSteps {
            if rng.nextDouble() < 0.12 {   // ~12% per 4-step window
                let note = notes[rng.nextInt(upperBound: notes.count)]
                let vel  = UInt8(25 + rng.nextInt(upperBound: 35))  // 25–59
                let s    = step + rng.nextInt(upperBound: 4)
                if s < loopSteps {
                    events.append(MIDIEvent(stepIndex: s, note: note, velocity: vel, durationSteps: 2))
                }
            }
            step += 4
        }
        return events
    }

    // MARK: - Helper

    private static func notes(pitchClasses: Set<Int>, low: Int, high: Int) -> [UInt8] {
        guard low <= high else { return [] }
        return (low...high).compactMap { n in pitchClasses.contains(n % 12) ? UInt8(n) : nil }
    }
}
