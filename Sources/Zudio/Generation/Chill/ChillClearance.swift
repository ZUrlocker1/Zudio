// ChillClearance.swift — keeps Chill's melody and its accompaniment from rubbing
// Copyright (c) 2026 Zack Urlocker
//
// Zack (2026-11-12): no clashes, and no rubs "unless it's a short passing note before landing on
// something that resolves properly with the chord". See docs/chill-chords-plan.md, "Clashes".
//
// - Two notes **rub** when they sound together a semitone or a minor 9th apart (1, 13, 25 or 37
//   semitones) for two steps or more. A major 7th is a colour, not a rub.
// - A **short passing note** may rub: two steps or less, with the line's next onset starting
//   within two steps of its end, a semitone or a whole tone away.
// - A melody note longer than a passing note must also not be an **avoid note**: a semitone above
//   a tone of a chord it sounds over (the 4th over a major 3rd, the b6 over a minor chord's 5th).
//
// Who yields: the soloist listens to what is already written (Pads and Bass for Lead 1; those
// and Lead 1 for Lead 2), and Rhythm, written after the leads, voices around the melody as a
// pianist does. Each line is checked as it is written, phrase by phrase or bar by bar; nothing
// passes over a finished track. No random draws.

import Foundation

struct ChillClearance {
    private struct Held { let start: Int; let end: Int; let pitch: Int }
    private var byBar: [Int: [Held]] = [:]

    static func rubs(_ a: Int, _ b: Int) -> Bool { [1, 13, 25, 37].contains(abs(a - b)) }

    /// The held notes of `tracks`; each track's own short passing notes are left out.
    init(_ tracks: [[MIDIEvent]] = []) {
        for t in tracks { add(t) }
    }

    mutating func add(_ events: [MIDIEvent]) {
        let sorted = events.sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }
        for i in sorted.indices where !Self.isPassing(i, in: sorted) {
            let e = sorted[i]
            let h = Held(start: e.stepIndex, end: e.stepIndex + Swift.max(1, e.durationSteps), pitch: Int(e.note))
            for bar in (h.start / 16)...((h.end - 1) / 16) { byBar[bar, default: []].append(h) }
        }
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

    /// True when `pitch`, sounding over `start..<end`, rubs a held note for two steps or more.
    func clashes(_ pitch: Int, start: Int, end: Int) -> Bool {
        guard end - start >= 2 else { return false }
        for bar in (start / 16)...((end - 1) / 16) {
            for h in byBar[bar] ?? [] where Swift.min(end, h.end) - Swift.max(start, h.start) >= 2
                && Self.rubs(pitch, h.pitch) {
                return true
            }
        }
        return false
    }

    /// A semitone above a tone of any chord sounding over `start..<end`, and not itself one.
    static func isAvoidNote(_ pitch: Int, start: Int, end: Int, structure: SongStructure) -> Bool {
        let pc = pitch % 12
        for bar in (start / 16)...((end - 1) / 16) {
            guard let w = structure.chordWindow(atBar: bar) else { continue }
            if !w.chordTones.contains(pc) && w.chordTones.contains((pc + 11) % 12) { return true }
        }
        return false
    }

    /// A melodic line as it is written. Each note that is not a short passing note keeps clear of
    /// the held notes here and, when it lasts two steps or more, is not an avoid note. One that
    /// fails moves to the nearest pitch that passes, at most four semitones away, inside
    /// `low...high`, in the scale: a chord tone first, then the direction of the next note. With
    /// none, the note stays as written.
    func voiceLine(_ line: [MIDIEvent], structure: SongStructure, scale: Set<Int>,
                   low: Int, high: Int) -> [MIDIEvent] {
        let order = line.indices.sorted { (line[$0].stepIndex, line[$0].note) < (line[$1].stepIndex, line[$1].note) }
        let sorted = order.map { line[$0] }
        var out = line
        for (k, idx) in order.enumerated() where !Self.isPassing(k, in: sorted) {
            let e = sorted[k]
            let written = e.stepIndex + Swift.max(1, e.durationSteps)
            let held = written - e.stepIndex >= 2
            // The span as it will sound. The groove fixup that runs after the leads are written
            // can move an onset a step and join a note legato to the next one (up to three steps
            // longer), so the check covers a step either side and, where the next onset is two
            // steps or less after the note, through to a step past it.
            let nextOnset = sorted[(k + 1)...].first { $0.stepIndex > e.stepIndex }?.stepIndex
            let joined = nextOnset.map { $0 - written <= 2 && $0 >= written ? $0 + 1 : written } ?? written
            let start = Swift.max(0, e.stepIndex - 1), end = Swift.max(written, joined) + 1
            // The harmonic filter may lift a lead an octave in a window that sits under the pads,
            // which turns a major 7th into a minor 9th, so the octave above must clear too.
            func ok(_ p: Int) -> Bool {
                !clashes(p, start: start, end: end) && !clashes(p + 12, start: start, end: end)
                    && !(held && Self.isAvoidNote(p, start: start, end: end, structure: structure))
            }
            let p0 = Int(e.note)
            guard !ok(p0) else { continue }
            let tones = structure.chordWindow(atBar: e.stepIndex / 16)?.chordTones ?? []
            let next = sorted[(k + 1)...].first { $0.stepIndex > e.stepIndex }.map { Int($0.note) }
            let toward = (next ?? p0) >= p0 ? 1 : -1
            let candidates = (1...4).flatMap { [p0 + $0 * toward, p0 - $0 * toward] }
                .filter { $0 >= low && $0 <= high && scale.contains($0 % 12) && ok($0) }
            guard let pick = candidates.first(where: { tones.contains($0 % 12) }) ?? candidates.first
            else { continue }
            out[idx] = MIDIEvent(stepIndex: e.stepIndex, note: UInt8(pick), velocity: e.velocity,
                                 durationSteps: e.durationSteps)
        }
        return out
    }

    /// One bar of accompaniment as it is written, voiced around the melody held here. A note that
    /// rubs a melody note (and is not itself a short passing note) moves down an octave where
    /// that clears it and stays at or above `floor`; otherwise it is left out, as a pianist leaves
    /// the melody's neighbour out of the chord under it.
    func voiceComping(_ bar: [MIDIEvent], floor: Int) -> [MIDIEvent] {
        let sorted = bar.sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }
        var out: [MIDIEvent] = []
        for (k, e) in sorted.enumerated() {
            let start = e.stepIndex, end = e.stepIndex + Swift.max(1, e.durationSteps)
            let p = Int(e.note)
            if Self.isPassing(k, in: sorted) || !clashes(p, start: start, end: end) {
                out.append(e)
            } else if p - 12 >= floor, !clashes(p - 12, start: start, end: end),
                      !sorted.contains(where: { $0.stepIndex == start && Int($0.note) == p - 12 }) {
                out.append(MIDIEvent(stepIndex: e.stepIndex, note: UInt8(p - 12), velocity: e.velocity,
                                     durationSteps: e.durationSteps))
            }
        }
        return out
    }
}
