// MIDIEvent.swift — one MIDI note event, step-addressed
// Copyright (c) 2026 Zack Urlocker

struct MIDIEvent: Equatable, Hashable, Sendable {
    /// Absolute step index within the full song (bar × 16 + step-within-bar).
    let stepIndex: Int
    /// MIDI note number 0–127.
    let note: UInt8
    /// MIDI velocity 0–127.
    let velocity: UInt8
    /// Gate length in steps (1 step = one sixteenth note).
    let durationSteps: Int

    /// Wall-clock time of this event's note-on, in seconds from the song start.
    func timeSeconds(tempo: Int) -> Double {
        let secondsPerStep = 60.0 / Double(tempo) / 4.0
        return Double(stepIndex) * secondsPerStep
    }

    /// Wall-clock time of the corresponding note-off.
    func noteOffTimeSeconds(tempo: Int) -> Double {
        let secondsPerStep = 60.0 / Double(tempo) / 4.0
        return Double(stepIndex + durationSteps) * secondsPerStep
    }
}
