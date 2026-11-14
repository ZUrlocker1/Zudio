// Clearance.swift — the pieces Chill's and Motorik's clearance share
// Copyright (c) 2026 Zack Urlocker
//
// ChillClearance (Chill/ChillClearance.swift) and MotorikClearance (LeadGenerator.swift) both keep
// a line clear of the notes already sounding. They differ in which intervals rub and in whether
// the band's own short passing notes count. No random draws.

import Foundation

enum Clearance {

    /// `pitch` is outside the chord and a semitone from one of its tones.
    static func rubsChord(_ pitch: Int, _ chordTones: Set<Int>) -> Bool {
        let pc = ((pitch % 12) + 12) % 12
        guard !chordTones.contains(pc) else { return false }
        return chordTones.contains { [1, 11].contains(((pc - $0) % 12 + 12) % 12) }
    }

    /// `sorted[i]` is a short passing note: two steps or less, and some note of the line's next
    /// onset starts within two steps of its end, a semitone or a whole tone away.
    static func isPassing(_ i: Int, in sorted: [MIDIEvent]) -> Bool {
        let e = sorted[i]
        guard e.durationSteps <= 2 else { return false }
        let end = e.stepIndex + e.durationSteps
        guard let next = sorted[(i + 1)...].first(where: { $0.stepIndex > e.stepIndex })?.stepIndex,
              next <= end + 2 else { return false }
        return sorted[(i + 1)...].prefix { $0.stepIndex == next }
            .contains { (1...2).contains(abs(Int($0.note) - Int(e.note))) }
    }
}

/// The notes already sounding, indexed by bar. A pitch clashes with one when they sound together
/// for two steps or more at one of `intervals` semitones apart.
struct HeldNotes {
    private struct Held { let start: Int; let end: Int; let pitch: Int }
    private var byBar: [Int: [Held]] = [:]
    private let intervals: Set<Int>
    private let skipPassing: Bool

    /// With `skipPassing`, each added track's own short passing notes are left out (Chill).
    init(intervals: Set<Int>, skipPassing: Bool) {
        self.intervals = intervals
        self.skipPassing = skipPassing
    }

    mutating func add(_ events: [MIDIEvent]) {
        let sorted = skipPassing ? events.sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) } : events
        for i in sorted.indices where !(skipPassing && Clearance.isPassing(i, in: sorted)) {
            let e = sorted[i]
            let h = Held(start: e.stepIndex, end: e.stepIndex + Swift.max(1, e.durationSteps), pitch: Int(e.note))
            for bar in (h.start / 16)...((h.end - 1) / 16) { byBar[bar, default: []].append(h) }
        }
    }

    /// True when `pitch`, sounding over `start..<end`, clashes with a held note.
    func clashes(_ pitch: Int, start: Int, end: Int) -> Bool {
        guard end - start >= 2 else { return false }
        for bar in (start / 16)...((end - 1) / 16) {
            for h in byBar[bar] ?? [] where Swift.min(end, h.end) - Swift.max(start, h.start) >= 2
                && intervals.contains(abs(pitch - h.pitch)) {
                return true
            }
        }
        return false
    }
}
