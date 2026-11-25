// AmbientPianoSatin.swift — AMB-PNO-002 Satin Melody (Satie / Arnalds), split out of AmbientLeadGenerator.swift
// Copyright (c) 2026 Zack Urlocker

import Foundation

extension AmbientLeadGenerator {

    // MARK: AMB-PNO-002 — Satin Melody (Satie / Arnalds)

    static func pensiveMelodyFullSong(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG,
        introEndBar: Int = 0, isEvolvePass: Bool = false
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let upper = notesInRegister(pitchClasses: scalePCs, low: 65, high: 77)
        let lower = notesInRegister(pitchClasses: scalePCs, low: 53, high: 63)
        let all   = lower + upper   // ranges are non-overlapping (63 < 65), both already sorted
        guard upper.count >= 2, lower.count >= 2 else { return [] }

        // Setup — once per song
        // Pivot = a chord tone (5th 45%, 3rd 35%, root 20%), so the oscillation leans on harmony and
        // its neighbour is the passing colour: the rocking sounds like a sigh, not two loose notes.
        let rootPC0   = frame.keySemitoneValue % 12
        let chordPCs0 = pnoChordPCs(frame)
        let pivRoll   = rng.nextDouble()
        let wantPC    = pivRoll < 0.45 ? (rootPC0 + 7) % 12
                      : (pivRoll < 0.80 ? (chordPCs0.count > 1 ? chordPCs0[1] : rootPC0) : rootPC0)
        let pivotIdx  = upper.firstIndex(where: { Int($0) % 12 == wantPC })
                     ?? upper.firstIndex(where: { chordPCs0.contains(Int($0) % 12) })
                     ?? rng.nextInt(upperBound: upper.count)
        let pivot    = upper[pivotIdx]
        // Neighbor = adjacent scale tone; step down when pivot is already at the top of the pool
        let neighbor = pivotIdx < upper.count - 1
            ? upper[pivotIdx + 1]
            : upper[Swift.max(0, pivotIdx - 1)]
        // Turn figure (50% of songs): alternate cycles use the neighbour on the other side
        // (pivot, above, pivot, below), so the oscillation draws a small shape.
        let otherNeighbor: UInt8? = rng.nextDouble() < 0.50
            ? (pivotIdx < upper.count - 1 ? (pivotIdx > 0 ? upper[pivotIdx - 1] : lower.last) : nil)
            : nil
        // Prefer scale root (70%) or 5th (20%) for lower anchor — tonal stability a la Satie
        let rootPC  = frame.keySemitoneValue % 12
        let fifthPC = (rootPC + 7) % 12
        let anchorRoll = rng.nextDouble()
        let lowerAnchor: UInt8
        if anchorRoll < 0.70, let root = lower.first(where: { Int($0) % 12 == rootPC }) {
            lowerAnchor = root
        } else if anchorRoll < 0.90, let fifth = lower.first(where: { Int($0) % 12 == fifthPC }) {
            lowerAnchor = fifth
        } else {
            lowerAnchor = lower[rng.nextInt(upperBound: lower.count)]
        }
        let useNearLight = rng.nextDouble() < 0.30

        // Phrase windows — 4 phrases spaced through song; phrase 1 enters at bar 1-2
        let w1 = Swift.max(0, Swift.min(1 + rng.nextInt(upperBound: 2), totalBars - 8)) * 16
        let w2 = Swift.max(0, Swift.min(totalBars * 27 / 100, totalBars - 8)) * 16
        let w3 = Swift.max(0, Swift.min(totalBars * 52 / 100, totalBars - 8)) * 16
        let w4 = Swift.max(0, Swift.min(totalBars * 76 / 100, totalBars - 8)) * 16
        let wLen = 5 * 16

        // Oscillation rhythm (once per song): even, dotted, long-short-short, lilting or slow-quick.
        // The motif carries it, so its returns are recognisable by rhythm as well as pitch.
        let rhythmCells: [[Int]] = [[4], [6, 2], [4, 2, 2], [6, 2, 4, 4], [8, 4]]
        let rhythmCut: [Double]  = [0.20, 0.45, 0.65, 0.85, 1.0]
        let rhythmRoll = rng.nextDouble()
        let rhythm = rhythmCells[rhythmCut.firstIndex(where: { rhythmRoll < $0 }) ?? 0]

        // The motif (question) is built once and ends open; the answer is the same phrase landing
        // on the root. Satie repeats rather than develops, so every later statement is one of these.
        let scaleAll = notesInRegister(pitchClasses: scalePCs, low: 21, high: 108)
        let motif = pno002Phrase(type: rng.nextDouble() < 0.75 ? 0 : 1, startStep: 0,
                                 pivot: pivot, neighbor: neighbor, lowerAnchor: lowerAnchor,
                                 upper: upper, lower: lower, totalSteps: Int(Int32.max), rng: &rng,
                                 velCap: 60, rhythm: rhythm, ending: .open, frame: frame,
                                 otherNeighbor: otherNeighbor)
        let answer = pnoAnswer(motif, lower: lower, frame: frame)
        func phraseEnd(_ ev: [MIDIEvent]) -> Int { ev.map { $0.stepIndex + $0.durationSteps }.max() ?? 0 }

        var events: [MIDIEvent] = []

        // Phrase 1 — three opening characters:
        //   30% nearLight (Arnalds chord-texture)
        //   45% Jarrett sparse opening (5-note motif + long hold + bass pedal)
        //   25% the motif itself
        let p1off = rng.nextInt(upperBound: Swift.max(1, wLen / 2))
        var motifAtP1 = false
        if useNearLight {
            events += nearLightTexture(startStep: w1 + p1off, pivot: pivot,
                                       upper: upper, lower: lower, all: all,
                                       totalSteps: totalSteps, rng: &rng)
        } else if rng.nextDouble() < 0.65 {
            let ev = jarrettSparseOpening(startStep: w1 + p1off, upper: upper, lower: lower,
                                          totalSteps: totalSteps, rng: &rng)
            events += ev
        } else {
            let ev = pnoReplay(motif, at: w1 + p1off, velCap: 40, totalSteps: totalSteps)
            events += ev
            motifAtP1 = true
        }

        // Phrase 2 — the answer when phrase 1 was the motif (35% moved up the scale, a sequence);
        // otherwise the motif's first statement.
        let p2off = rng.nextInt(upperBound: Swift.max(1, wLen / 2))
        var p2src = motifAtP1 ? answer : motif
        if motifAtP1 && rng.nextDouble() < 0.35 {
            p2src = pnoMoveAlongScale(p2src, by: 1 + rng.nextInt(upperBound: 2), scale: scaleAll)
        }
        let p2ev = pnoReplay(p2src, at: w2 + p2off, velCap: 46, totalSteps: totalSteps)
        events += p2ev

        // Phrase 3 — the full statement returns at home (motif after an answer, answer after a motif)
        let p3off = rng.nextInt(upperBound: Swift.max(1, wLen / 2))
        let p3ev  = pnoReplay(motifAtP1 ? motif : answer, at: w3 + p3off, velCap: 60, totalSteps: totalSteps)
        events += p3ev
        // Echoes 1-2, each 2-4 bars after the last: the answer, the motif's head, or the motif moved a step
        let p3echoes = 1 + (rng.nextDouble() < 0.60 ? 1 : 0)
        var p3cursor = phraseEnd(p3ev)
        for _ in 0..<p3echoes {
            p3cursor += (2 + rng.nextInt(upperBound: 3)) * 16
            let r = rng.nextDouble()
            let src: [MIDIEvent]
            if r < 0.40      { src = answer }
            else if r < 0.70 { src = pnoHead(motif, pool: lower + upper, frame: frame) }
            else             { src = pnoMoveAlongScale(motif, by: rng.nextDouble() < 0.50 ? 1 : -1, scale: scaleAll) }
            guard p3cursor + phraseEnd(src) < w4 else { break }
            let eev = pnoReplay(src, at: p3cursor, velCap: 56, totalSteps: totalSteps)
            events += eev
            p3cursor = phraseEnd(eev)
        }

        // Phrases 4 & 5 — closing (suppressed for evolve passes): the answer once more, softly, or a
        // short cadence; both land on the root.
        let p4off = rng.nextInt(upperBound: Swift.max(1, wLen / 2))
        if !isEvolvePass {
            let p4ev = rng.nextDouble() < 0.50
                ? pnoReplay(answer, at: w4 + p4off, velCap: 36, totalSteps: totalSteps)
                : pno002Phrase(type: 2, startStep: w4 + p4off,
                               pivot: pivot, neighbor: neighbor, lowerAnchor: lowerAnchor,
                               upper: upper, lower: lower, totalSteps: totalSteps, rng: &rng,
                               velCap: 36, rhythm: rhythm, ending: .home, frame: frame)
            events += p4ev
            // Phrase 5 — sparse final exhale for long songs (>90 bars), very soft cadence
            if totalBars > 90 {
                let w5 = Swift.min(totalBars * 90 / 100, totalBars - 4) * 16
                if w5 > w4 + wLen {
                    let p5ev = pno002Phrase(type: 2, startStep: w5,
                                            pivot: pivot, neighbor: neighbor, lowerAnchor: lowerAnchor,
                                            upper: upper, lower: lower, totalSteps: totalSteps, rng: &rng,
                                            velCap: 24, rhythm: rhythm, ending: .home, frame: frame)
                    events += p5ev
                }
            }
        }

        // Quiet returning figure — 2 scale notes that recur every 7-10 bars between phrases.
        // More Satie than random fill: the same notes return, creating recognizable presence.
        if !upper.isEmpty {
            let qIdx1  = rng.nextInt(upperBound: Swift.max(1, upper.count / 2))
            let qIdx2  = Swift.min(qIdx1 + 1 + rng.nextInt(upperBound: 2), upper.count - 1)
            let qNote1 = upper[qIdx1]; let qNote2 = upper[qIdx2]
            var qb = 3 + rng.nextInt(upperBound: 4)
            while qb < totalBars - 1 {
                let qs = qb * 16 + rng.nextInt(upperBound: 6)
                guard qs < totalSteps else { break }
                var note = rng.nextDouble() < 0.65 ? qNote1 : qNote2
                let dur  = Swift.min(8 + rng.nextInt(upperBound: 7), totalSteps - qs)
                // Give way to the melody: the other note if this one rubs (half-step, tritone, major
                // 7th) against anything sounding, else no note this time
                let under = events.filter { $0.stepIndex < qs + dur && $0.stepIndex + $0.durationSteps > qs }
                func rubs(_ n: UInt8) -> Bool { under.contains { pnoRubs(Int($0.note), Int(n)) } }
                if rubs(note) { note = note == qNote1 ? qNote2 : qNote1 }
                if rubs(note) { qb += 7 + rng.nextInt(upperBound: 4); continue }
                // Scale velocity with song position — softer at edges, slightly warmer in middle
                let qVelBase = qb < totalBars / 4 ? 12 : (qb > 3 * totalBars / 4 ? 10 : 18)
                if dur >= 4 { events.append(MIDIEvent(stepIndex: qs, note: note, velocity: pnoVel(qVelBase + rng.nextInt(upperBound: 8)), durationSteps: dur)) }
                qb += 7 + rng.nextInt(upperBound: 4)
            }
        }

        // Satie-style left hand: bass on beat 1, a 2-note chord on beat 2, sometimes a note on beat 3.
        // Bass rocks tonic / subdominant-or-dominant (Satie's IV→I). The chord is that bass note's
        // own triad, kept under the melody: at least 3 semitones below any melody note sounding over
        // it and never a half-step, tritone or major 7th from one — so it never has to be trimmed
        // out of the melody's way. Where nothing fits under a low melody note, the hand rests.
        let lhBass  = notesInRegister(pitchClasses: scalePCs, low: pnoBassLow, high: pnoBassHigh)
        if !lhBass.isEmpty {
            let melodyNow = events
            let rootPC5   = frame.keySemitoneValue % 12
            let fifthPC5  = (rootPC5 + 7) % 12
            let fourthPC5 = (rootPC5 + 5) % 12
            let bassRoot  = lhBass.first(where: { Int($0) % 12 == rootPC5  }) ?? lhBass[0]
            let bassFifth = lhBass.first(where: { Int($0) % 12 == fifthPC5 }) ?? lhBass[lhBass.count / 2]
            let bassFour  = lhBass.first(where: { Int($0) % 12 == fourthPC5 }) ?? bassFifth
            let closingBar = w4 / 16   // bass-only (no chord/beat3) after the final phrase
            let lhStartBar = introEndBar  // suppress LH during intro so it doesn't clash with fade-in
            for bar in lhStartBar..<totalBars {
                let barStep  = bar * 16
                guard barStep < totalSteps else { break }
                let inOpening = bar < totalBars / 4
                let inClosing = bar >= closingBar
                // Bass: tonic bars vs subdominant/dominant bars (Satie's rocking alternation).
                // On the very last bar, 50% chance of resolving to the tonic regardless of parity.
                var bassNote: UInt8
                if bar == totalBars - 1 && rng.nextDouble() < 0.50 {
                    bassNote = bassRoot
                } else {
                    bassNote = bar % 2 == 0 ? bassRoot : (rng.nextDouble() < 0.60 ? bassFifth : bassFour)
                }
                // A bass that rubs (half-step, tritone, major 7th) against the melody over it gives way
                // to the next of root, 5th, 4th that doesn't
                let overBass = melodyNow.filter { $0.stepIndex < barStep + 12 && $0.stepIndex + $0.durationSteps > barStep }
                func rubs(_ b: UInt8) -> Bool { overBass.contains { pnoRubs(Int($0.note), Int(b)) } }
                if rubs(bassNote), let alt = [bassRoot, bassFifth, bassFour].first(where: { !rubs($0) }) { bassNote = alt }
                // Taper bass velocity gradually through the closing section
                let bassBase = inClosing
                    ? Swift.max(18, 30 - (bar - closingBar) * 30 / Swift.max(1, totalBars - closingBar))
                    : 30
                let bassVel  = pnoVel(bassBase + rng.nextInt(upperBound: 6))
                // Jarrett/Satie: bass held for a half note (12 steps) — pedal, not a click
                events.append(MIDIEvent(stepIndex: barStep, note: bassNote, velocity: bassVel, durationSteps: 12))
                // Beat 2 (step 8): the bass note's 3rd and 5th — omitted in the closing section
                if !inClosing, barStep + 8 < totalSteps {
                    let tones = lhTones(bass: bassNote, scalePCs: scalePCs, low: 52, high: 66, target: 60,
                                        prefer: [1, 2, 0], count: 2, melody: melodyNow,
                                        start: barStep + 8, end: barStep + 15)
                    let cv = pnoVel(22 + rng.nextInt(upperBound: 8))
                    for (k, t) in tones.enumerated() {
                        events.append(MIDIEvent(stepIndex: barStep + 8, note: t, velocity: k == 0 ? cv : cv - 3, durationSteps: 7))
                    }
                }
                // Beat 3 (step 12): frequency scales with song position — sparse at edges
                let beat3Prob = inOpening ? 0.10 : (inClosing ? 0.0 : 0.35)
                if barStep + 12 < totalSteps, rng.nextDouble() < beat3Prob,
                   let t = lhTones(bass: bassNote, scalePCs: scalePCs, low: 52, high: 66, target: 62,
                                   prefer: [2, 0], count: 1, melody: melodyNow,
                                   start: barStep + 12, end: barStep + 17).first {
                    events.append(MIDIEvent(stepIndex: barStep + 12, note: t,
                                            velocity: pnoVel(16 + rng.nextInt(upperBound: 6)), durationSteps: 5))
                }
            }
        }

        return trimDissonances(events, totalSteps: totalSteps)
    }

    static func nearLightTexture(
        startStep: Int, pivot: UInt8, upper: [UInt8], lower: [UInt8], all: [UInt8],
        totalSteps: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let numBars = 4 + rng.nextInt(upperBound: 5)
        var events: [MIDIEvent] = []
        guard !lower.isEmpty, !upper.isEmpty else { return [] }

        var chordRoot = lower[rng.nextInt(upperBound: Swift.max(1, lower.count / 2))]
        var melNote   = upper[rng.nextInt(upperBound: upper.count)]

        for bar in 0..<numBars {
            let bs = startStep + bar * 16
            guard bs < totalSteps else { break }
            let cv: UInt8 = 45 + UInt8(rng.nextInt(upperBound: 11))
            // 3-note chord on beat 1
            for offset in [0, 7, 12] {
                let n = Int(chordRoot) + offset
                guard n >= 21 && n <= 108 else { continue }
                events.append(MIDIEvent(stepIndex: bs, note: UInt8(n), velocity: cv, durationSteps: 16))
            }
            // Melody note on beat 3
            let ms = bs + 8
            if ms < totalSteps {
                events.append(MIDIEvent(stepIndex: ms, note: melNote,
                                        velocity: pnoVel(Swift.min(55 + rng.nextInt(upperBound: 11), 65)), durationSteps: 4))
            }
            // Chord root: move 4th or 5th within scale tones
            let interval = rng.nextDouble() < 0.50 ? 5 : 7
            let dir      = rng.nextDouble() < 0.50 ? 1 : -1
            let tPC      = (Int(chordRoot) + dir * interval + 120) % 12
            if let found = all.first(where: { Int($0) % 12 == tPC }) { chordRoot = found }
            // Melody: step down 1-2 positions in upper pool
            if let ci = upper.firstIndex(of: melNote), ci > 0 {
                melNote = upper[Swift.max(0, ci - (1 + rng.nextInt(upperBound: 2)))]
            }
        }
        return events
    }

    /// Jarrett Köln opening motif: 5 scale notes (up a P4/P5, step back twice, step up), then
    /// a long held landing note with a bass pedal entering underneath — 4+ bars of quiet space.
    static func jarrettSparseOpening(
        startStep: Int, upper: [UInt8], lower: [UInt8],
        totalSteps: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard !upper.isEmpty else { return [] }
        var events: [MIDIEvent] = []
        var cur = startStep

        // Start low-mid in register; leap up P4/P5 (3-4 pool steps), step back down, step up, hold
        let startIdx = rng.nextInt(upperBound: Swift.max(1, upper.count / 3))
        let leapUp   = 3 + rng.nextInt(upperBound: 2)
        let indices: [Int] = [
            startIdx,
            Swift.min(startIdx + leapUp,     upper.count - 1),
            Swift.min(startIdx + leapUp - 1, upper.count - 1),
            Swift.max(startIdx - 1, 0),
            Swift.min(startIdx + 1,          upper.count - 1)
        ]
        for (i, idx) in indices.enumerated() {
            guard cur < totalSteps else { break }
            let isLast = i == indices.count - 1
            let dur = isLast
                ? Swift.min(32 + rng.nextInt(upperBound: 17), totalSteps - cur)  // 2–3 bar hold
                : Swift.min(6 + rng.nextInt(upperBound: 4),  totalSteps - cur)   // dotted-quarter–half
            guard dur >= 1 else { break }
            events.append(MIDIEvent(stepIndex: cur,
                                    note: upper[Swift.max(0, Swift.min(idx, upper.count - 1))],
                                    velocity: pnoVel(24 + rng.nextInt(upperBound: 14)),
                                    durationSteps: dur))
            if !isLast { cur += 8 + rng.nextInt(upperBound: 5) }   // half–dotted-half between notes
        }
        // Bass pedal enters under the held note — Jarrett LH grounds the harmony
        if !lower.isEmpty, cur < totalSteps {
            let bd = Swift.min(22 + rng.nextInt(upperBound: 14), totalSteps - cur)
            if bd >= 8 {
                events.append(MIDIEvent(stepIndex: cur,
                                        note: lower[rng.nextInt(upperBound: lower.count)],
                                        velocity: pnoVel(26 + rng.nextInt(upperBound: 10)),
                                        durationSteps: bd))
            }
        }
        return events
    }

    /// How a piano phrase ends: open (5th, or Satie's suspended 2nd/4th), home (root), or any
    /// settled tone (chord tone, sometimes a 2nd or 6th colour).
    enum PnoEnding { case open, home, any }

    /// Root, 3rd and 5th pitch classes of the song's tonic chord (the 3rd is whichever the mode has).
    static func pnoChordPCs(_ frame: GlobalMusicalFrame) -> [Int] {
        let scale = frame.scalePCs
        let root  = frame.keySemitoneValue % 12
        return [root, pnoThirdPC(of: root, in: scale), (root + 7) % 12].compactMap { $0 }.filter { scale.contains($0) }
    }

    /// Pitch classes a phrase may end on, all in the song's scale.
    static func pnoEndingPCs(_ ending: PnoEnding, frame: GlobalMusicalFrame, rng: inout SeededRNG) -> [Int] {
        let scale = frame.scalePCs
        let root  = frame.keySemitoneValue % 12
        let chord = pnoChordPCs(frame)
        func degrees(_ d: [Int]) -> [Int] {
            let f = d.map { (root + $0) % 12 }.filter { scale.contains($0) }
            return f.isEmpty ? (ending == .open ? [(root + 7) % 12] : chord) : f
        }
        let r = rng.nextDouble()
        switch ending {
        case .home: return r < 0.85 ? [root] : degrees([7])
        case .open: return r < 0.50 ? degrees([7]) : (r < 0.75 ? degrees([2]) : degrees([5]))
        case .any:  return r < 0.70 ? chord : degrees([2, 9])
        }
    }

    /// Note in `pool` with one of `pcs` nearest to `target`.
    static func pnoNearest(_ pool: [UInt8], to target: Int, pcs: [Int]) -> UInt8? {
        pool.filter { pcs.contains(Int($0) % 12) }.min { abs(Int($0) - target) < abs(Int($1) - target) }
    }

    /// Left-hand chord tones kept under the melody: notes of `bass`'s triad in the scale (prefer
    /// slots: 0 root, 1 third, 2 fifth), between `low` and `high`, nearest `target`. Each sits at least
    /// 3 semitones below every melody note sounding over [start, end) and is never a half-step,
    /// tritone or major 7th from one. Up to `count` notes, one per slot; empty when nothing fits.
    static func lhTones(bass: UInt8, scalePCs: Set<Int>, low: Int, high: Int, target: Int,
                                prefer: [Int], count: Int, melody: [MIDIEvent], start: Int, end: Int) -> [UInt8] {
        let b = Int(bass) % 12
        let third = pnoThirdPC(of: b, in: scalePCs)
        let fifth: Int? = scalePCs.contains((b + 7) % 12) ? (b + 7) % 12 : nil
        let triad: [Int?] = [b, third, fifth]
        let sounding = melody.filter { $0.stepIndex < end && $0.stepIndex + $0.durationSteps > start }
        let ceiling  = Swift.min(high, (sounding.map { Int($0.note) }.min() ?? 200) - 3)
        guard ceiling >= low else { return [] }
        var out: [UInt8] = []
        for slot in prefer where out.count < count {
            guard slot < triad.count, let pc = triad[slot] else { continue }
            let cands = (low...ceiling).filter { $0 % 12 == pc }
                .filter { n in !sounding.contains { pnoRubs(Int($0.note), n) } }
            if let n = cands.min(by: { abs($0 - target) < abs($1 - target) }) { out.append(UInt8(n)) }
        }
        return out
    }

    /// Re-places a phrase built at step 0, scaling its velocities so the loudest note sits at
    /// `velCap` (never louder than built; swell shape kept), clipped to the song.
    static func pnoReplay(_ phrase: [MIDIEvent], at start: Int, velCap: Int, totalSteps: Int) -> [MIDIEvent] {
        let loudest = Double(phrase.map { Int($0.velocity) }.max() ?? 1)
        let velScale = Swift.min(1.0, Double(velCap) / loudest)
        return phrase.compactMap { e in
            let s = start + e.stepIndex
            guard s < totalSteps else { return nil }
            let v = Swift.max(14, Swift.min(127, Int((Double(e.velocity) * velScale).rounded())))
            return MIDIEvent(stepIndex: s, note: e.note, velocity: pnoVel(v),
                             durationSteps: Swift.max(1, Swift.min(e.durationSteps, totalSteps - s)))
        }
    }

    /// Moves every note `k` steps along the scale (a sequence), keeping rhythm and velocity.
    static func pnoMoveAlongScale(_ phrase: [MIDIEvent], by k: Int, scale: [UInt8]) -> [MIDIEvent] {
        phrase.map { e in
            guard let i = scale.firstIndex(of: e.note) else { return e }
            let n = scale[Swift.max(0, Swift.min(scale.count - 1, i + k))]
            return e.with(note: n)
        }
    }

    /// The answer: the motif note for note, but its last note lands on the nearest root and holds longer.
    static func pnoAnswer(_ motif: [MIDIEvent], lower: [UInt8], frame: GlobalMusicalFrame) -> [MIDIEvent] {
        guard let lastIdx = motif.indices.max(by: { motif[$0].stepIndex < motif[$1].stepIndex }) else { return motif }
        let last = motif[lastIdx]
        let root = frame.keySemitoneValue % 12
        let home = pnoNearest(lower, to: Int(last.note), pcs: [root]) ?? last.note
        var out = motif
        out[lastIdx] = last.with(note: home, durationSteps: last.durationSteps + 4)
        // If the note before is already that root, move it to another chord tone so the root lands fresh
        if let prevIdx = motif.indices.filter({ motif[$0].stepIndex < last.stepIndex })
                                      .max(by: { motif[$0].stepIndex < motif[$1].stepIndex }),
           motif[prevIdx].note == home,
           let alt = pnoNearest(lower.filter { $0 != home }, to: Int(home), pcs: pnoChordPCs(frame).filter { $0 != root }) {
            let pv = motif[prevIdx]
            out[prevIdx] = pv.with(note: alt)
        }
        return out
    }

    /// The motif's head: its first half (at least 3 notes), the last one moved to the nearest chord
    /// tone and held, so the fragment still sounds finished.
    static func pnoHead(_ motif: [MIDIEvent], pool: [UInt8], frame: GlobalMusicalFrame) -> [MIDIEvent] {
        let sorted = motif.sorted { $0.stepIndex < $1.stepIndex }
        let keep = Swift.min(sorted.count, Swift.max(3, (sorted.count + 1) / 2))
        var head = Array(sorted.prefix(keep))
        guard let last = head.last else { return head }
        let tone = pnoNearest(pool, to: Int(last.note), pcs: pnoChordPCs(frame)) ?? last.note
        head[head.count - 1] = last.with(note: tone, durationSteps: Swift.max(12, last.durationSteps))
        return head
    }

    static func pno002Phrase(
        type: Int, startStep: Int, pivot: UInt8, neighbor: UInt8, lowerAnchor: UInt8,
        upper: [UInt8], lower: [UInt8], totalSteps: Int, rng: inout SeededRNG,
        velCap: Int = 52, rhythm: [Int] = [4], ending: PnoEnding = .any, frame: GlobalMusicalFrame,
        otherNeighbor: UInt8? = nil
    ) -> [MIDIEvent] {
        guard startStep < totalSteps else { return [] }
        var events: [MIDIEvent] = []
        var cur = startStep
        let cap: (Int) -> UInt8 = { pnoVel(Swift.min($0, velCap)) }
        let chord = pnoChordPCs(frame)
        let scale = frame.scalePCs
        let allNotes = (lower + upper).sorted()
        // Oscillation gaps cycle through the song's rhythm cell
        var gapIdx = 0
        func nextGap() -> Int { defer { gapIdx += 1 }; return rhythm[gapIdx % rhythm.count] }
        func oscDur(_ gap: Int) -> Int { Swift.max(2, gap - 1) }

        switch type {
        case 0: // Standard two-register arc (Satie/Arnalds: spacious pivot-neighbor oscillation)
            // Opening gesture (90%) — scale neighbor above pivot, settle back; held quarter-to-half note
            if rng.nextDouble() < 0.90 && cur + 7 < totalSteps {
                let pivIdx   = upper.firstIndex(of: pivot) ?? (upper.count / 2)
                var openIdx  = Swift.min(pivIdx + 1 + rng.nextInt(upperBound: 2), upper.count - 1)
                if openIdx == pivIdx { openIdx = Swift.max(0, pivIdx - 1) }   // pivot at the top: arrive from below
                let openNote = upper[openIdx]
                events.append(MIDIEvent(stepIndex: cur, note: openNote, velocity: cap(42), durationSteps: 6)); cur += 8
                events.append(MIDIEvent(stepIndex: cur, note: pivot,    velocity: cap(38), durationSteps: 10)); cur += 13
            }
            // Upper oscillation — 2-4 cycles in the song's rhythm cell; with a turn figure the odd
            // cycles use the neighbour on the other side of the pivot
            let cycles = 2 + rng.nextInt(upperBound: 3)   // 2-4
            for c in 0..<cycles {
                guard cur < totalSteps else { break }
                let neighbor = (c % 2 == 1 ? otherNeighbor : nil) ?? neighbor
                let velPiv = cap(34 + c * 4 + 3)   // 37 → 51 over 5 cycles
                let velNbr = cap(32 + c * 4)        // 32 → 48
                // Broken chord variant 30% — pivot, the scale tone a 5th below it, neighbor
                if rng.nextDouble() < 0.30 {
                    let below = Int(pivot) - 7
                    let fifth = scale.contains((below + 120) % 12) ? UInt8(below)
                              : (allNotes.min { abs(Int($0) - below) < abs(Int($1) - below) } ?? pivot)
                    var g = nextGap()
                    events.append(MIDIEvent(stepIndex: cur, note: pivot, velocity: velPiv, durationSteps: oscDur(g))); cur += g
                    g = nextGap()
                    if cur < totalSteps { events.append(MIDIEvent(stepIndex: cur, note: fifth, velocity: velNbr, durationSteps: oscDur(g))); cur += g }
                    g = nextGap()
                    if cur < totalSteps { events.append(MIDIEvent(stepIndex: cur, note: neighbor, velocity: velNbr, durationSteps: oscDur(g))); cur += g }
                } else {
                    var g = nextGap()
                    events.append(MIDIEvent(stepIndex: cur, note: pivot, velocity: velPiv, durationSteps: oscDur(g))); cur += g
                    g = nextGap()
                    if cur < totalSteps { events.append(MIDIEvent(stepIndex: cur, note: neighbor, velocity: velNbr, durationSteps: oscDur(g))); cur += g }
                }
            }
            // Suspension → resolution (60%) — resolve to scale neighbor below pivot
            var lastNote = pivot
            if rng.nextDouble() < 0.60 && cur < totalSteps {
                let sd = Swift.min(6 + rng.nextInt(upperBound: 3), totalSteps - cur)
                events.append(MIDIEvent(stepIndex: cur, note: pivot, velocity: cap(50), durationSteps: sd)); cur += sd
                if cur < totalSteps {
                    let pivIdx = upper.firstIndex(of: pivot) ?? 0
                    let resIdx = Swift.max(0, pivIdx - 1 - rng.nextInt(upperBound: 2))
                    let res    = upper[resIdx]
                    lastNote = res
                    events.append(MIDIEvent(stepIndex: cur, note: res, velocity: cap(44), durationSteps: Swift.min(4, totalSteps - cur))); cur += 5
                }
            }
            // Leap down (about a sixth) to a chord tone in the lower register. Without a settlement
            // the landing is the phrase's last note, so it takes the phrase ending instead.
            let settle = rng.nextDouble() < 0.60
            let endPCs = pnoEndingPCs(ending, frame: frame, rng: &rng)
            let landChord = chord.filter { !endPCs.contains($0) }
            var land = lowerAnchor
            if cur < totalSteps, !lower.isEmpty {
                let pcs = settle ? (landChord.isEmpty ? chord : landChord) : endPCs
                land = pnoNearest(lower, to: Int(lastNote) - 9, pcs: pcs) ?? lowerAnchor
                let ld = Swift.min(8 + rng.nextInt(upperBound: 9) + (settle ? 0 : 4), totalSteps - cur)
                events.append(MIDIEvent(stepIndex: cur, note: land, velocity: cap(40), durationSteps: ld)); cur += ld
            }
            // Lower settlement (60%)
            if settle && cur < totalSteps, !lower.isEmpty {
                var prev = land
                if rng.nextDouble() < 0.35 {
                    // Exhausted landing oscillation, turning on the landing note
                    let li = lower.firstIndex(of: land) ?? 0
                    for _ in 0..<(2 + rng.nextInt(upperBound: 2)) {
                        guard cur < totalSteps else { break }
                        // Below the landing first, then back to it — so the landing isn't struck twice
                        events.append(MIDIEvent(stepIndex: cur, note: lower[Swift.max(0, li - 1)], velocity: 30, durationSteps: Swift.min(3, totalSteps - cur))); cur += 4
                        if cur < totalSteps {
                            prev = lower[li]
                            events.append(MIDIEvent(stepIndex: cur, note: prev, velocity: 26, durationSteps: Swift.min(3, totalSteps - cur))); cur += 4
                        }
                    }
                }
                if cur < totalSteps {
                    let finalNote = pnoNearest(lower.filter { $0 != prev }, to: Int(prev), pcs: endPCs)
                                 ?? pnoNearest(lower, to: Int(prev), pcs: endPCs) ?? lowerAnchor
                    let fd = Swift.min(10 + rng.nextInt(upperBound: 11), totalSteps - cur)
                    events.append(MIDIEvent(stepIndex: cur, note: finalNote, velocity: 28, durationSteps: fd))
                }
            }

        case 1: // Pure oscillation
            let osc = 3 + rng.nextInt(upperBound: 2)
            var lastOscNote: UInt8 = 0; var sameRun = 0
            for i in 0..<(osc * 2) {
                guard cur < totalSteps else { break }
                let nb = ((i / 2) % 2 == 1 ? otherNeighbor : nil) ?? neighbor
                var note = i % 2 == 0 ? pivot : nb
                // Never repeat the same pitch more than 3 times in a row
                if note == lastOscNote { sameRun += 1 } else { sameRun = 0 }
                if sameRun >= 3 { note = note == pivot ? nb : pivot; sameRun = 0 }
                lastOscNote = note
                let g = nextGap()
                events.append(MIDIEvent(stepIndex: cur, note: note, velocity: cap(30 + i * 3), durationSteps: Swift.min(oscDur(g), totalSteps - cur))); cur += g
            }
            // Resolution fall to a chord tone, then the held ending
            var fall = lowerAnchor
            let endPCs = pnoEndingPCs(ending, frame: frame, rng: &rng)
            let fallChord = chord.filter { !endPCs.contains($0) }
            if cur < totalSteps, !lower.isEmpty {
                fall = pnoNearest(lower, to: Int(lastOscNote) - 9, pcs: fallChord.isEmpty ? chord : fallChord) ?? lowerAnchor
                events.append(MIDIEvent(stepIndex: cur, note: fall, velocity: cap(40), durationSteps: Swift.min(5, totalSteps - cur))); cur += 7
            }
            if cur < totalSteps {
                let endNote = pnoNearest(lower.filter { $0 != fall }, to: Int(fall), pcs: endPCs) ?? lowerAnchor
                events.append(MIDIEvent(stepIndex: cur, note: endNote, velocity: 30,
                                        durationSteps: Swift.min(12 + rng.nextInt(upperBound: 9), totalSteps - cur)))
            }

        default: // Short cadence — chord tone, leap up to a chord tone, stepwise descent, held ending
            guard !lower.isEmpty, !upper.isEmpty else { break }
            let lowChord  = lower.filter { chord.contains(Int($0) % 12) }
            let highIdx   = upper.indices.filter { chord.contains(Int(upper[$0]) % 12) }
            let startNote = lowChord.isEmpty ? lower[rng.nextInt(upperBound: lower.count)]
                                             : lowChord[rng.nextInt(upperBound: lowChord.count)]
            let peakIdx   = highIdx.isEmpty ? rng.nextInt(upperBound: upper.count)
                                            : highIdx[rng.nextInt(upperBound: highIdx.count)]
            events.append(MIDIEvent(stepIndex: cur, note: startNote, velocity: 34, durationSteps: Swift.min(5, totalSteps - cur))); cur += 6
            if cur < totalSteps {
                events.append(MIDIEvent(stepIndex: cur, note: upper[peakIdx], velocity: cap(46), durationSteps: Swift.min(4, totalSteps - cur))); cur += 5
            }
            var lastNote = upper[peakIdx]
            let descentCount = 2 + rng.nextInt(upperBound: 2)
            for i in 0..<descentCount {
                guard cur < totalSteps else { break }
                lastNote = upper[Swift.max(0, peakIdx - i - 1)]
                events.append(MIDIEvent(stepIndex: cur, note: lastNote, velocity: cap(38 - i * 3), durationSteps: Swift.min(4, totalSteps - cur))); cur += 5
            }
            if cur < totalSteps {
                let pcs = pnoEndingPCs(ending, frame: frame, rng: &rng)
                let endNote = pnoNearest(lower, to: Int(lastNote), pcs: pcs) ?? lowerAnchor
                events.append(MIDIEvent(stepIndex: cur, note: endNote, velocity: 28,
                                        durationSteps: Swift.min(10 + rng.nextInt(upperBound: 7), totalSteps - cur)))
            }
        }
        return events
    }
}
