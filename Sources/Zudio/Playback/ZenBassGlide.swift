// ZenBassGlide.swift — AMB-BASS-009 Slow Glide: Ambient Zen's bass as one held note that bends
// Copyright (c) 2026 Zack Urlocker
//
// AMB-1's bass is never re-attacked at a chord change: its pitch glides to the new root. The
// generator writes AMB-BASS-007's ordinary notes (so the piano roll, MIDI export and regeneration
// are unchanged), and playback turns each run of touching notes into one struck key plus pitch
// bends (docs/Ambient-Zen-plan.md, section 7).
//
// - A run is a stretch of bass notes with no gap; a sit-out ends it. The run's first note is
//   struck at its own pitch (the key), and every later pitch is a bend away from that key.
// - Roots sit in one octave and fifths fold into it, so every bend is within 11 semitones of the
//   key. The bass channel's bend range is set to 12 (RPN 0) at each run start.
// - The key is struck again, at the same bend, after 24 bars, so no sample is asked to hold for
//   minutes; the pitch doesn't move at a re-strike.
// - A glide is a one-pole approach to the new pitch, time constant 0.45 s (audible for about
//   1.5 s), as AMB-1 does.
// - After a seek, the first step struck re-primes the run: the key at the bend of the note in
//   force there.

import Foundation

struct ZenBassGlide: Sendable {
    /// The notes the sampler plays: one held key per strike.
    let played: [MIDIEvent]
    /// Step → the bend to glide to, in semitones from the sounding key.
    let bends: [Int: Double]
    /// Steps where a run starts: the bend goes back to centre before the key is struck.
    let runStarts: Set<Int>
    /// Each written note, for priming after a seek: its span, the key it sounds on and its bend.
    let segments: [Segment]

    struct Segment: Sendable {
        let start: Int
        let end: Int
        let key: UInt8
        let bend: Double
        let velocity: UInt8
    }

    static let restrikeSteps = 24 * 16
    static let tau = 0.45
    static let bendRange = 12.0

    /// The glide for a song whose bass is AMB-BASS-009 Slow Glide (the dial for a new song, the
    /// regeneration's roll for a regenerated bass), or nil for any other song.
    static func make(for state: SongState) -> ZenBassGlide? {
        guard state.isAmbientZen, AmbientZenTracks.bassGlides(in: state) else { return nil }
        let notes = state.trackEvents[kTrackBass].sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }
        guard !notes.isEmpty else { return nil }

        var played: [MIDIEvent] = []
        var bends: [Int: Double] = [:]
        var runStarts: Set<Int> = []
        var segments: [Segment] = []
        var key = 0, strikeStart = 0, runEnd = -1
        var strikeVelocity: UInt8 = 0
        var current = 0.0

        func close(at end: Int) {
            played.append(MIDIEvent(stepIndex: strikeStart, note: UInt8(key), velocity: strikeVelocity,
                                    durationSteps: end - strikeStart))
        }
        for e in notes {
            let pitch = Int(e.note)
            let end   = e.stepIndex + e.durationSteps
            let inRun = runEnd >= 0 && e.stepIndex <= runEnd && abs(pitch - key) <= Int(bendRange)
            if inRun {
                if e.stepIndex - strikeStart >= restrikeSteps {
                    close(at: e.stepIndex)
                    strikeStart = e.stepIndex
                    strikeVelocity = e.velocity
                }
                let target = Double(pitch - key)
                if target != current { bends[e.stepIndex] = target; current = target }
                runEnd = Swift.max(runEnd, end)
            } else {
                if runEnd >= 0 { close(at: runEnd) }
                key = pitch
                strikeStart = e.stepIndex
                strikeVelocity = e.velocity
                current = 0
                runStarts.insert(e.stepIndex)
                runEnd = end
            }
            segments.append(Segment(start: e.stepIndex, end: end, key: UInt8(key), bend: current,
                                    velocity: e.velocity))
        }
        close(at: runEnd)
        return ZenBassGlide(played: played, bends: bends, runStarts: runStarts, segments: segments)
    }

    /// The written note in force at `step` (the latest to start), if the bass is sounding there.
    func segment(at step: Int) -> Segment? {
        segments.last { $0.start <= step && step < $0.end }
    }

    /// The 14-bit pitch-bend value for `semitones` at the glide's range of ±12.
    static func bendValue(semitones: Double) -> Int {
        Swift.max(0, Swift.min(16383, Int((8192.0 + semitones / bendRange * 8192.0).rounded())))
    }
}
