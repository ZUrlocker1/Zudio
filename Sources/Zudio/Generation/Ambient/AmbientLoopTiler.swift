// AmbientLoopTiler.swift — tiles a short loop across the full song length
// Copyright (c) 2026 Zack Urlocker
// Each track in Ambient style is generated as a short co-prime loop, then tiled
// to fill totalBars. Different loop lengths create Eno-style phase shifting.

struct AmbientLoopTiler {
    /// Tiles `events` (covering [0, loopBars×16) steps) across [0, totalBars×16).
    /// Partial final tiles are included (notes starting within range are kept).
    /// `silentBars` — absolute bar indices (step/16) where note-ons are suppressed.
    /// Used by the dropout-zone coordinator to guarantee per-track rests.
    static func tile(events: [MIDIEvent], loopBars: Int, totalBars: Int,
                     silentBars: Set<Int> = []) -> [MIDIEvent] {
        tile(events: events, loopBars: loopBars, totalBars: totalBars, silentBars: silentBars,
             chords: [], track: -1)
    }

    /// Base Ambient: each copy of the loop follows the chord in force (AmbientChordFollow), with
    /// `track`'s seams, so a loop drawn on one chord never rubs against another (Zack, 2026-11-21).
    static func tile(events: [MIDIEvent], loopBars: Int, totalBars: Int,
                     silentBars: Set<Int> = [], chords: [ChordWindow], track: Int) -> [MIDIEvent] {
        guard loopBars > 0, totalBars > 0, !events.isEmpty else { return [] }
        let loopSteps  = loopBars * 16
        let totalSteps = totalBars * 16
        var result: [MIDIEvent] = []
        var tileStart = 0
        while tileStart < totalSteps {
            for ev in events {
                let newStep = tileStart + ev.stepIndex
                guard newStep < totalSteps else { continue }
                if !silentBars.isEmpty && silentBars.contains(newStep / 16) { continue }
                result.append(MIDIEvent(stepIndex: newStep, note: ev.note,
                                        velocity: ev.velocity, durationSteps: ev.durationSteps))
            }
            tileStart += loopSteps
        }
        // already sorted: tileStart is monotonically increasing and events are pre-sorted
        return chords.isEmpty ? result : AmbientChordFollow.follow(result, chords: chords, track: track)
    }
}

/// Base Ambient's chord following (Zack, 2026-11-21). Every note sounds, in each chord window it
/// spans, as a chord tone or a clear tension: a scale note a semitone from no chord tone and from
/// no other clear tension. Any other note moves to the nearest chord tone (ties go down) for that
/// window; a note held across a chord change is split there and re-struck only if its pitch moves.
/// A very short off-beat note (an eighth or less) that would rub is dropped. Base Ambient's chords never
/// hold two chord tones a semitone apart (no maj7), so two followed notes are never a semitone or
/// a minor 9th apart.
enum AmbientChordFollow {

    /// The pitch classes a note may sound on in a window, and the chord tones to move to.
    static func allowed(_ w: ChordWindow) -> (ok: Set<Int>, tones: [Int]) {
        let tones = Set(w.chordTones.map { (($0 % 12) + 12) % 12 })
        func near(_ a: Int, _ b: Int) -> Bool { let d = (a - b + 12) % 12; return d == 1 || d == 11 }
        let tensions = Set(w.scaleTensions.map { (($0 % 12) + 12) % 12 }).subtracting(tones)
            .filter { t in !tones.contains { near(t, $0) } }
        let clear = tensions.filter { t in !tensions.contains { near(t, $0) } }
        return (tones.union(clear), tones.sorted())
    }

    /// A seam's release before a chord change, and the shortest fragment kept, in steps.
    static let seamRelease = 4
    static let seamMinimum = 4

    /// How each voice crosses a chord change: the one place base Ambient's seams are set.
    /// `entryDelay`: steps after the change before a held note's new pitch enters.
    /// `rootAtChange`: a note held into a new chord continues on that chord's root rather than
    /// the nearest chord tone, so the bass names every change.
    struct Seam { let entryDelay: Int; let rootAtChange: Bool }
    static func seam(for track: Int) -> Seam {
        switch track {
        case kTrackBass: return Seam(entryDelay: 0, rootAtChange: true)   // marks the change
        case kTrackPads: return Seam(entryDelay: 8, rootAtChange: false)  // a half note, rolled
        default:         return Seam(entryDelay: 4, rootAtChange: false)  // a quarter
        }
    }

    static func follow(_ events: [MIDIEvent], chords: [ChordWindow], track: Int) -> [MIDIEvent] {
        guard !chords.isEmpty else { return events }
        let entryDelay = seam(for: track).entryDelay, rootAtChange = seam(for: track).rootAtChange
        let plan = chords.sorted { $0.startBar < $1.startBar }
        let rules = plan.map(allowed)
        // The root pitch class: the chord tone the chord type's intervals all stand on.
        let roots: [Int?] = plan.map { w in
            let tones = Set(w.chordTones.map { (($0 % 12) + 12) % 12 })
            return tones.sorted().first { r in w.chordType.intervals.allSatisfy { tones.contains((r + $0) % 12) } }
        }
        func rootNear(_ note: Int, _ w: Int) -> Int? {
            guard let r = roots[w] else { return nil }
            let down = note - ((note % 12 - r + 12) % 12)
            let up = down + 12
            return (up - note < note - down && up <= 127) || down < 0 ? up : down
        }
        func windowIndex(_ step: Int) -> Int {
            var i = 0
            for (k, w) in plan.enumerated() where w.startBar * 16 <= step { i = k }
            return i
        }
        func place(_ note: Int, _ w: Int) -> Int {
            let pc = note % 12
            guard !rules[w].ok.contains(pc) else { return note }
            var best = note, bestDist = Int.max
            for t in rules[w].tones {
                for cand in [note - ((pc - t + 12) % 12), note + ((t - pc + 12) % 12)] where cand >= 0 && cand <= 127 {
                    let d = abs(cand - note)
                    if d < bestDist || (d == bestDist && cand < best) { best = cand; bestDist = d }
                }
            }
            return best
        }

        var out: [MIDIEvent] = []
        // Late entries at a chord change, keyed by the change step, rolled in after the loop.
        var entries: [(change: Int, end: Int, pitch: Int, velocity: UInt8)] = []
        for e in events {
            let start = e.stepIndex, end = e.stepIndex + e.durationSteps
            // A very short off-beat note is a passing tone: kept where it is clear, dropped
            // where it would rub, so the line gets a gap rather than a repeated note.
            if e.durationSteps <= 2 && start % 4 != 0 {
                if rules[windowIndex(start)].ok.contains(Int(e.note) % 12) { out.append(e) }
                continue
            }
            // Split at each chord change; a fragment that keeps its pitch holds on.
            var frags: [(s: Int, t: Int, p: Int)] = []
            var s = start
            while s < end {
                let w = windowIndex(s)
                let next = w + 1 < plan.count ? plan[w + 1].startBar * 16 : Int.max
                let t = Swift.min(end, next)
                let p = rootAtChange && s > start ? (rootNear(Int(e.note), w) ?? place(Int(e.note), w))
                                                  : place(Int(e.note), w)
                if let last = frags.last, last.p == p { frags[frags.count - 1].t = t }
                else { frags.append((s, t, p)) }
                s = t
            }
            // Seams (Zack, 2026-11-21): where a held note must change pitch, the old pitch is
            // released up to a quarter early and the new one enters late, so the change
            // crossfades on the release tails instead of every voice flipping on the downbeat.
            // A fragment shorter than a quarter on either side is dropped, not struck.
            for (k, f) in frags.enumerated() {
                let movesIn = k > 0, movesOut = k + 1 < frags.count
                if (movesIn || movesOut) && f.t - f.s < seamMinimum { continue }
                var fs = f.s, ft = f.t
                if movesOut { ft -= Swift.min(seamRelease, (ft - fs) - seamMinimum) }
                if movesIn && !movesOut { entries.append((f.s, f.t, f.p, e.velocity)); continue }
                if movesIn { fs += Swift.min(entryDelay, (ft - fs) - seamMinimum) }
                out.append(MIDIEvent(stepIndex: fs, note: UInt8(f.p), velocity: e.velocity, durationSteps: ft - fs))
            }
        }
        // Voices entering at one change come in from the bottom up, two sixteenths apart,
        // so a pad chord rolls into the new harmony rather than landing as a block.
        let byChange = Dictionary(grouping: entries, by: { $0.change })
        for change in byChange.keys.sorted() {
            let group = byChange[change]!.sorted { $0.pitch < $1.pitch }
            for (k, v) in group.enumerated() {
                let len = v.end - v.change
                guard len >= seamMinimum else { continue }
                let delay = entryDelay == 0 ? 0 : Swift.min(entryDelay + 2 * k, len - seamMinimum)
                out.append(MIDIEvent(stepIndex: v.change + delay, note: UInt8(v.pitch), velocity: v.velocity,
                                     durationSteps: len - delay))
            }
        }
        // Two notes moved onto one pitch: the earlier ends where the later starts, so one
        // note-off never cuts the other; an exact duplicate is dropped.
        out.sort { $0.stepIndex != $1.stepIndex ? $0.stepIndex < $1.stepIndex : $0.note < $1.note }
        var lastByPitch: [UInt8: Int] = [:]
        var keep = [Bool](repeating: true, count: out.count)
        for i in out.indices {
            let e = out[i]
            if let j = lastByPitch[e.note] {
                let prev = out[j]
                if prev.stepIndex == e.stepIndex {
                    keep[i] = false
                    if e.durationSteps > prev.durationSteps {
                        out[j] = MIDIEvent(stepIndex: prev.stepIndex, note: prev.note, velocity: prev.velocity,
                                           durationSteps: e.durationSteps)
                    }
                    continue
                }
                if prev.stepIndex + prev.durationSteps > e.stepIndex {
                    out[j] = MIDIEvent(stepIndex: prev.stepIndex, note: prev.note, velocity: prev.velocity,
                                       durationSteps: e.stepIndex - prev.stepIndex)
                }
            }
            lastByPitch[e.note] = i
        }
        return out.indices.filter { keep[$0] }.map { out[$0] }
    }
}
