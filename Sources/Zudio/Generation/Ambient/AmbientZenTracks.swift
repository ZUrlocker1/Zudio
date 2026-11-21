// AmbientZenTracks.swift — Ambient Zen phase 1: the bed (pads, pedal, bass)
// Copyright (c) 2026 Zack Urlocker
//
// Every note is written clash-free where it is written (docs/Ambient-Zen-plan.md, section 6):
// all notes are chord tones of the window in force, the low voices sit in fixed registers, the
// pad voicing avoids semitones and minor 9ths against each other and the pedal, and joins never
// hold an old note under a new chord.
//
// A same-pitch join abuts rather than overlaps: the sampler's note-off for the earlier note would
// otherwise cut the re-struck one short. Playback fires a step's note-offs before its note-ons,
// so an abutting re-strike sounds continuous.

import Foundation

enum AmbientZenTracks {

    // MARK: - Pads: AMB-PADS-011 Airports Breath

    /// Four voices, each breathing on its own cycle (AMB-1's numbers). A voice whose note is not
    /// in the new chord ends at the change and breathes again a second later on its new target,
    /// so the bass leads each change and the pads arrive late. The final 6 bars of music are the
    /// held breath (4 to 6 bars, by the outro's length): all four voices on the tonic chord. The pads,
    /// pedal and bass stop 1 to 2 bars apart, in an order drawn per song (dials.endOffsets).
    static func pads(plan: AmbientZenPlan, rng: inout SeededRNG,
                     usedRuleIDs: inout Set<String>) -> [MIDIEvent] {
        usedRuleIDs.insert("AMB-PADS-011")
        let voicings  = padVoicings(plan: plan)
        let sps       = plan.stepsPerSecond
        let holdStart = plan.heldBreathStartBar * 16
        let endStep   = plan.padsEndBar * 16
        let base      = 4 + 0.12 * plan.dials.breathLength
        let factors   = [1.0, 1.21, 1.43, 1.67]
        let startFraction = [0.0, 1 - 0.9, 1 - 0.82, 1 - 0.95]
        // Window starts in steps, for the chord changes inside a breath.
        let boundaries = plan.windows.dropFirst().map { $0.startBar * 16 }

        func cycleSeconds(_ v: Int) -> Double { base * factors[v] * (0.85 + 0.30 * rng.nextDouble()) }
        /// Breath velocity, nudged up to 10 percent by the swell at the breath's bar.
        func velocity(_ step: Int) -> UInt8 {
            let v = Double(50 + Int((40 * (0.6 + 0.4 * rng.nextDouble())).rounded()))
            return UInt8(Swift.max(1, Swift.min(127, Int((v * (1 + 0.1 * plan.swell(atBar: step / 16))).rounded()))))
        }

        /// A sounding voice carries across a change only if its note is a chord tone of the new
        /// chord and sits clear of the new voicing and the pedal.
        func carries(_ pitch: Int, voice: Int, into w: Int) -> Bool {
            let win = plan.windows[w]
            guard win.chordTones.contains(pitch % 12) else { return false }
            for (u, other) in voicings[w].enumerated() where u != voice {
                if [0, 1, 13].contains(abs(pitch - other)) { return false }
            }
            for p in plan.pedalNotes(win) + plan.bassNotes(win) where [1, 13].contains(abs(pitch - p)) {
                return false
            }
            return true
        }

        var events: [MIDIEvent] = []
        var lastNote: [Int?] = [nil, nil, nil, nil]   // each voice's last breath, by index
        for v in 0..<4 {
            var cycle = cycleSeconds(v)
            var t     = startFraction[v] * cycle * sps
            while true {
                let onset = Int(t.rounded())
                guard onset < holdStart else { break }
                let w      = plan.windowIndex(atBar: onset / 16)
                let pitch  = voicings[w][v]
                let steps  = cycle * sps
                var off    = Swift.min(holdStart, onset + Swift.max(1, Int((0.9 * steps).rounded())))
                var nextT  = t + steps
                var scale  = 1.0
                for b in boundaries where b > onset && b < off {
                    let nw = plan.windowIndex(atBar: b / 16)
                    if !carries(pitch, voice: v, into: nw) {
                        off   = b
                        nextT = Double(b) + 1.0 * sps
                        scale = 0.85
                        break
                    }
                }
                let ev = MIDIEvent(stepIndex: onset, note: UInt8(pitch), velocity: velocity(onset),
                                   durationSteps: off - onset)
                lastNote[v] = events.count
                events.append(ev)
                t     = Swift.max(nextT, Double(onset + 1))
                cycle = cycleSeconds(v) * scale
            }
        }

        // The held breath: each voice takes the tonic chord and holds to the end of the music.
        // A voice already sounding its held note carries straight on rather than striking again.
        let hold = voicings[voicings.count - 1]
        for v in 0..<4 {
            if let i = lastNote[v], Int(events[i].note) == hold[v],
               events[i].stepIndex + events[i].durationSteps == holdStart {
                let last = events[i]
                events[i] = MIDIEvent(stepIndex: last.stepIndex, note: last.note, velocity: last.velocity,
                                      durationSteps: endStep - last.stepIndex)
            } else {
                events.append(MIDIEvent(stepIndex: holdStart, note: UInt8(hold[v]), velocity: velocity(holdStart),
                                        durationSteps: endStep - holdStart))
            }
        }
        return abutSamePitch(events)
    }

    /// One four-voice voicing per window, plus the held breath's tonic voicing last: AMB-1's
    /// nearest-movement permutation (en_voice_lead) over the window's chord tones in MIDI 48 to 77,
    /// with Zen's extra costs (plan section 6, rule 4). No randomness: a regenerated pad track
    /// keeps the song's voicings and changes only its breathing.
    static func padVoicings(plan: AmbientZenPlan) -> [[Int]] {
        var out: [[Int]] = []
        var previous: [Int]? = nil
        for w in plan.windows {
            let v = bestVoicing(w, plan: plan, previous: previous)
            out.append(v)
            previous = v
        }
        // The held breath is the outro's tonic window voiced again from where the pads are.
        if let last = plan.windows.last { out.append(bestVoicing(last, plan: plan, previous: previous)) }
        return out
    }

    private static let permutations: [[Int]] = {
        var out: [[Int]] = []
        func build(_ prefix: [Int], _ rest: [Int]) {
            if rest.isEmpty { out.append(prefix); return }
            for (i, x) in rest.enumerated() {
                var r = rest; r.remove(at: i)
                build(prefix + [x], r)
            }
        }
        build([], [0, 1, 2, 3])
        return out
    }()

    private static func bestVoicing(_ w: ZenWindow, plan: AmbientZenPlan, previous: [Int]?) -> [Int] {
        let low = 48, high = 77
        let tones = Array(w.chordTones.prefix(4))
        // The pedal notes the window keeps and every bass note it may hold (plan.bassNotes).
        let pedal = plan.pedalNotes(w) + plan.bassNotes(w)
        // With no previous voicing, the voices start spread around these centres.
        let centres = [53, 59, 65, 71]
        let reference = previous ?? centres
        let candidates: [[Int]] = tones.map { pc in (low...high).filter { $0 % 12 == pc } }
        var best: [Int] = []
        var bestCost = Int.max
        for perm in permutations where perm.count == tones.count {
            // perm[v] is the chord tone voice v takes.
            let lists = perm.map { candidates[$0] }
            var pick = [Int](repeating: 0, count: lists.count)
            func search(_ v: Int) {
                if v == lists.count {
                    var cost = 0
                    for i in 0..<pick.count { cost += abs(pick[i] - reference[i]) }
                    for i in 0..<pick.count {
                        for j in (i + 1)..<pick.count {
                            let d = abs(pick[i] - pick[j])
                            if d == 0 || d == 1 || d == 13 { cost += 40 }
                        }
                        for p in pedal where [1, 13].contains(abs(pick[i] - p)) { cost += 40 }
                        if w.keepsTonic && pick[i] % 12 == plan.leadingTonePC && pick[i] < plan.pedalTonicNote {
                            cost += 40
                        }
                    }
                    if cost < bestCost { bestCost = cost; best = pick }
                    return
                }
                for n in lists[v] { pick[v] = n; search(v + 1) }
            }
            search(0)
        }
        return best
    }

    // MARK: - Texture: AMB-TEXT-012 Pearl Pedal

    /// The tonic and fifth held under everything, in MIDI 48 to 59 and 55 to 66. The fifth is
    /// present in about 60 percent of songs; otherwise it stands in only where the tonic drops.
    /// Each note lasts 3 to 5 bars and the next takes over on the same pitch, so the pedal never
    /// gaps. A pedal note that a window drops ends at that window's first step and comes back at
    /// the next window that allows it.
    static func pedal(plan: AmbientZenPlan, rng: inout SeededRNG,
                      usedRuleIDs: inout Set<String>) -> [MIDIEvent] {
        usedRuleIDs.insert("AMB-TEXT-012")
        let fifthPresent = rng.nextDouble() < 0.60
        let endStep = plan.pedalEndBar * 16
        var events: [MIDIEvent] = []
        for lane in 0..<2 {
            let note = lane == 0 ? plan.pedalTonicNote : plan.pedalFifthNote
            func active(_ w: ZenWindow) -> Bool {
                lane == 0 ? w.keepsTonic : (w.keepsFifth && (fifthPresent || !w.keepsTonic))
            }
            // Runs of windows in which this lane sounds, in steps.
            var runs: [(Int, Int)] = []
            for w in plan.windows where active(w) {
                let s = w.startBar * 16, e = Swift.min(w.endBar * 16, endStep)
                guard e > s else { continue }
                if let last = runs.last, last.1 == s { runs[runs.count - 1].1 = e } else { runs.append((s, e)) }
            }
            for (s, e) in runs {
                var cursor = s
                while cursor < e {
                    var len = (3 + rng.nextInt(upperBound: 3)) * 16
                    // A leftover under a bar joins the note before it rather than striking again.
                    if e - (cursor + len) < 16 { len = e - cursor }
                    let vel = Double(40 + rng.nextInt(upperBound: 15)) * (1 + 0.1 * plan.swell(atBar: cursor / 16))
                    events.append(MIDIEvent(stepIndex: cursor, note: UInt8(note),
                                            velocity: UInt8(Swift.max(1, Int(vel.rounded()))),
                                            durationSteps: len))
                    cursor += len
                }
            }
        }
        return abutSamePitch(events)
    }

    // MARK: - Bass: AMB-BASS-007 Airports Root / AMB-BASS-008 Plateaux Octave Root

    /// The chord root at MIDI 36 + its pitch class, one note per window, re-struck every 8 bars.
    /// At the window's midpoint it may move to the chord's fifth, but never onto the leading tone.
    /// 007 plays the root alone; 008 doubles it at the octave for 2 bars, then the upper note
    /// carries on alone. A window change ends the old root exactly where the new one starts.
    static func bass(plan: AmbientZenPlan, rng: inout SeededRNG, usedRuleIDs: inout Set<String>,
                     forceRuleID: String? = nil) -> [MIDIEvent] {
        let ruleID: String = {
            if let f = forceRuleID, f == "AMB-BASS-007" || f == "AMB-BASS-008" { return f }
            return rng.nextDouble() < 0.60 ? "AMB-BASS-007" : "AMB-BASS-008"
        }()
        usedRuleIDs.insert(ruleID)
        let octave  = ruleID == "AMB-BASS-008"
        let endStep = plan.bassEndBar * 16
        var events: [MIDIEvent] = []

        /// Notes on one pitch from `s` to `e`, re-struck every 8 bars; the last may run `tail` past `e`.
        func held(_ note: Int, _ s: Int, _ e: Int, _ vel: UInt8, tail: Int = 0) {
            var cursor = s
            while cursor < e {
                var len = Swift.min(128, e - cursor)
                if e - (cursor + len) < 32 { len = e - cursor }   // no stub under 2 bars
                let isLast = cursor + len >= e
                events.append(MIDIEvent(stepIndex: cursor, note: UInt8(note), velocity: vel,
                                        durationSteps: len + (isLast ? tail : 0)))
                cursor += len
            }
        }
        /// A fifth folded into a register's top.
        func fifth(of note: Int, _ w: ZenWindow, ceiling: Int) -> Int {
            let n = note + w.fifthInterval
            return n > ceiling ? n - 12 : n
        }

        let last = plan.windows.count - 1
        var satOut = false
        for (i, w) in plan.windows.enumerated() {
            let s = w.startBar * 16
            let e = Swift.min(w.endBar * 16, endStep)
            guard e > s else { continue }
            // Sits a window out now and then, more often when the swell is sparse, never the first
            // or the last, nor two in a row.
            let sitOut = rng.nextDouble() < 0.3 * plan.dials.restlessness
                + 0.25 * Swift.max(-plan.swell(atBar: w.startBar), 0)
            if i != 0 && i != last && sitOut && !satOut { satOut = true; continue }
            satOut = false
            let vel   = UInt8(54 + rng.nextInt(upperBound: 9))
            let fifthPC = (w.rootPC + w.fifthInterval) % 12
            let moves = rng.nextDouble() < 0.35 && fifthPC != plan.leadingTonePC
            let mid   = s + ((e - s) / 32) * 16          // the window's midpoint, on a bar line
            let root  = 36 + w.rootPC
            if !octave {
                if moves && mid > s {
                    // Root to fifth: both chord tones, so the root may ring a beat into the fifth.
                    held(root, s, mid, vel, tail: 4)
                    held(fifth(of: root, w, ceiling: 47), mid, e, vel)
                } else {
                    held(root, s, e, vel)
                }
            } else {
                let upper = root + 12
                let pairEnd = Swift.min(e, s + 32)
                // The pair; the lower note rings a beat into the upper note's re-strike.
                events.append(MIDIEvent(stepIndex: s, note: UInt8(root), velocity: vel,
                                        durationSteps: pairEnd - s + (pairEnd < e ? 4 : 0)))
                events.append(MIDIEvent(stepIndex: s, note: UInt8(upper), velocity: vel,
                                        durationSteps: pairEnd - s))
                guard pairEnd < e else { continue }
                let moveAt = Swift.max(mid, pairEnd)
                if moves && moveAt < e {
                    if moveAt > pairEnd { held(upper, pairEnd, moveAt, vel, tail: 4) }
                    held(fifth(of: upper, w, ceiling: 59), moveAt, e, vel)
                } else {
                    held(upper, pairEnd, e, vel)
                }
            }
        }
        return abutSamePitch(events)
    }

    // MARK: - Joins

    /// Sorted, with any note cut where a later note of the same pitch starts, so no note-off can
    /// silence a re-strike. The generators above already abut their joins; this holds them to it.
    static func abutSamePitch(_ events: [MIDIEvent]) -> [MIDIEvent] {
        var sorted = events.sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }
        var lastIndex: [UInt8: Int] = [:]
        var drop = Set<Int>()
        for i in sorted.indices {
            let ev = sorted[i]
            if let j = lastIndex[ev.note] {
                let prev = sorted[j]
                if prev.stepIndex + prev.durationSteps > ev.stepIndex {
                    let len = ev.stepIndex - prev.stepIndex
                    if len <= 0 { drop.insert(j) } else {
                        sorted[j] = MIDIEvent(stepIndex: prev.stepIndex, note: prev.note,
                                              velocity: prev.velocity, durationSteps: len)
                    }
                }
            }
            lastIndex[ev.note] = i
        }
        return sorted.indices.filter { !drop.contains($0) }.map { sorted[$0] }
    }
}
