// AmbientRhythmGenerator.swift — Ambient rhythm/arpeggio generation
// AMB-RTHM-004 (60%): silent
// AMB-RTHM-001 (20%): single tone pulse — sparse repeated note, velocity 30–54
// AMB-RTHM-002 (10%): sparse arpeggio — 3–4 chord tones cycled slowly
// AMB-RTHM-003 (10%): stochastic phrase — random scale tones, 12% hit rate per window
// Generates a short loop; AmbientLoopTiler tiles to full song length.

import Foundation

struct AmbientRhythmGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let roll = rng.nextDouble()
        if roll < 0.60 { usedRuleIDs.insert("AMB-RTHM-004"); return [] }

        let bounds    = kRegisterBounds[kTrackRhythm]!  // low:45, high:76
        let loopSteps = loopBars * 16
        let scalePCs  = Set(frame.mode.intervals.map { (frame.keySemitoneValue + $0) % 12 })
        let scaleNotes = notes(pitchClasses: scalePCs, low: bounds.low, high: bounds.high)
        guard !scaleNotes.isEmpty else { return [] }

        if roll < 0.80 {
            usedRuleIDs.insert("AMB-RTHM-001")
            return singleTonePulse(notes: scaleNotes, loopSteps: loopSteps, rng: &rng)
        }
        if roll < 0.90 {
            usedRuleIDs.insert("AMB-RTHM-002")
            let chordPCs   = tonalMap.entry(atBar: 0)?.chordWindow.chordTones ?? scalePCs
            let chordNotes = notes(pitchClasses: chordPCs, low: bounds.low, high: bounds.high)
            return sparseArpeggio(notes: chordNotes.isEmpty ? scaleNotes : chordNotes,
                                   loopSteps: loopSteps, rng: &rng)
        }
        usedRuleIDs.insert("AMB-RTHM-003")
        return stochasticPhrase(notes: scaleNotes, loopSteps: loopSteps, rng: &rng)
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
