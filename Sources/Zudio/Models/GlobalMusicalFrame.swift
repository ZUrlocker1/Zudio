// GlobalMusicalFrame.swift — generation step 1 output

struct GlobalMusicalFrame: Equatable, Sendable {
    /// Key name e.g. "E", "C#", "Bb"
    let key: String
    let mode: Mode
    /// Integer BPM (20–200)
    let tempo: Int
    let mood: Mood
    let progressionFamily: ProgressionFamily
    /// Total song length in bars. Shared by all tracks — authoritative.
    let totalBars: Int

    // MARK: - Derived helpers

    var keySemitoneValue: Int { keySemitone(key) }

    /// Seconds per sixteenth-note step at this tempo.
    var secondsPerStep: Double { 60.0 / Double(tempo) / 4.0 }

    /// Seconds per bar (4 beats) at this tempo.
    var secondsPerBar: Double { 60.0 / Double(tempo) * 4.0 }

    /// Total song duration in seconds.
    var totalDurationSeconds: Double { Double(totalBars) * secondsPerBar }

    /// Returns a copy with only the tempo changed (used for real-time BPM scrubbing).
    func withTempo(_ newTempo: Int) -> GlobalMusicalFrame {
        GlobalMusicalFrame(key: key, mode: mode, tempo: newTempo, mood: mood,
                           progressionFamily: progressionFamily, totalBars: totalBars)
    }

    /// Absolute MIDI note for a given degree string and octave offset, clamped to a track's register.
    func midiNote(degree: String, oct: Int, trackIndex: Int) -> UInt8 {
        let raw = 60 + keySemitoneValue + degreeSemitone(degree) + (oct * 12)
        let bounds = kRegisterBounds[trackIndex] ?? RegisterBounds(low: 0, high: 127)
        return UInt8(bounds.clamp(raw))
    }
}
