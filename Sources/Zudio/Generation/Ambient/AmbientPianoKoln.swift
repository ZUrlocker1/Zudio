// AmbientPianoKoln.swift — AMB-PNO-003 Koln Winter Arc (Winston / Jarrett), split out of AmbientLeadGenerator.swift
// Copyright (c) 2026 Zack Urlocker

import Foundation

extension AmbientLeadGenerator {

    // MARK: AMB-PNO-003 — Koln Winter Arc (Winston / Jarrett)

    static func dramaticArcFullSong(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>, isEvolvePass: Bool = false, arcVariation: UInt64 = 0,
        reachLog: ReachLog? = nil
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let midNotes   = notesInRegister(pitchClasses: scalePCs, low: 60, high: 79)  // wider: C4-G5
        let highNotes  = notesInRegister(pitchClasses: scalePCs, low: 69, high: 89)
        let lowNotesAll   = notesInRegister(pitchClasses: scalePCs, low: pnoBassLow, high: pnoBassHigh)
        let lowNotesClean = lowNotesAll.filter { n in
            let pc = Int(n) % 12
            return !scalePCs.contains((pc + 6) % 12) && !scalePCs.contains((pc + 1) % 12)
        }
        let lowNotes      = lowNotesClean.isEmpty ? lowNotesAll : lowNotesClean
        guard !midNotes.isEmpty, !highNotes.isEmpty else { return [] }

        let use4Phrase    = rng.nextDouble() < 0.25
        let useCallResp   = rng.nextDouble() < 0.40
        let useOstinato   = rng.nextDouble() < 0.25
        let usePostClimax = rng.nextDouble() < 0.50
        let useParting    = rng.nextDouble() < 0.50

        // Arc positions per song (KolnArc): climax 45-70%, close 85-89%, and in some songs two
        // smaller peaks. p1Bar=1 ensures piano enters after at most 1 bar of silence.
        let arc          = KolnArc.draw(frame: frame, totalBars: totalBars, isEvolvePass: isEvolvePass,
                                        variation: arcVariation)
        let p1Bar        = 1
        let climaxBar    = arc.climaxBar
        let withdrawBar  = arc.withdrawBar
        let closingBar   = arc.closingBar
        // The pre-climax phrase sits at 70% of the way to the climax (42% when the climax was fixed
        // at 60%); it is dropped when a minor peak already occupies that stretch.
        let pcCandidate  = climaxBar * 70 / 100
        let preclimaxBar = use4Phrase && !arc.peakBars.contains(where: { abs($0 - pcCandidate) < 8 })
            ? pcCandidate : -1
        // Bars a minor peak owns (2 bars of run-up, 6 of peak and fall); build phrases, aftershocks
        // and connective phrases stay out of them.
        let peakZones    = arc.peakBars.map { ($0 - 3)...($0 + 6) }
        func nearPeak(_ bar: Int) -> Bool { peakZones.contains { $0.contains(bar) } }

        var events: [MIDIEvent] = []

        // Rhythm vocabulary (once per song): two cells the phrases speak in, mostly the first.
        // Gaps are for the fast (climax) pace; slower phrases stretch them.
        let kolnCells: [[Int]] = [[2, 2, 4], [4, 2, 2], [2, 2, 2, 6], [6, 2], [3, 3, 2], [2, 2, 2, 2], [4, 4, 2, 6]]
        let cellA = kolnCells[rng.nextInt(upperBound: kolnCells.count)]
        let cellB = kolnCells[rng.nextInt(upperBound: kolnCells.count)]
        // The song's motif, as scale-step moves: a Koln figure (neighbour then fall, leap then fill...)
        // plus 0-1 free steps. It opens phrase 1, asks the urgent question, and returns at the climax,
        // the withdrawal and the close; everything else wanders.
        let motifFamilies: [[Int]] = [[1, -1, -1], [2, -1, -1], [4, -1, -1], [-1, -1, 3], [1, 1, -2], [3, -1, -1, -1]]
        var motifMoves = motifFamilies[rng.nextInt(upperBound: motifFamilies.count)]
        if motifMoves.count < 4 && rng.nextDouble() < 0.50 { motifMoves.append(rng.nextDouble() < 0.60 ? -1 : 1) }

        // Helper: emit a burst-style phrase — a shaped line (arch, rise to a held top, or fall) that
        // turns back after wide leaps and wanders now and then, in the song's rhythm cells, with a
        // velocity swell to its peak and a last note on a chord tone (or the given ending).
        func emitBurst(bar: Int, pool: [UInt8], count: Int, velMin: Int, velMax: Int, ioi: Int, holdDur: Int,
                       startNear: Int = -1, head: [Int]? = nil, ending: PnoEnding = .any,
                       accents: Bool = true, endBy: Int = Int.max,
                       climb: Bool = false) -> (events: [MIDIEvent], endIdx: Int) {
            guard bar < totalBars, bar >= 0, !pool.isEmpty, count >= 1 else { return ([], pool.count / 2) }
            var ev: [MIDIEvent] = []
            var step = bar * 16 + rng.nextInt(upperBound: 4)
            // Shape: 0 arch, 1 rise to the held note, 2 fall from a high start
            let shapeRoll = rng.nextDouble()
            // `climb`: after the head, a straight climb to the held top note (Winston's burst, where the
            // long held note is the phrase's highest) — no wandering, no leaps, stops at the top.
            let shape = climb ? 1 : (head != nil ? 0 : (shapeRoll < 0.55 ? 0 : (shapeRoll < 0.75 ? 1 : 2)))
            var idx: Int
            if startNear >= 0 && startNear < pool.count {
                idx = startNear   // continue near the previous burst's endpoint
            } else if shape == 2 {
                let minStart = pool.count / 2
                idx = minStart + (pool.count - minStart > 1 ? rng.nextInt(upperBound: pool.count - minStart) : 0)
            } else {
                let maxStart = Swift.max(0, pool.count / 3)
                idx = maxStart > 0 ? rng.nextInt(upperBound: maxStart + 1) : 0
            }
            let peakAt = shape == 1 ? count - 1 : (shape == 2 ? 0 : Swift.max(1, count * 2 / 3 - 1 + rng.nextInt(upperBound: 2)))
            var idxs = [idx]
            var lastDir = 1, fillNext = false
            for i in 1..<Swift.max(1, count) {
                var mv: Int
                if let h = head, i - 1 < h.count {
                    mv = h[i - 1]
                } else if climb {
                    guard idx < pool.count - 1 else { break }
                    mv = rng.nextDouble() < 0.30 ? 2 : 1
                } else {
                    var dir = i <= peakAt ? 1 : -1
                    if fillNext { dir = -lastDir; fillNext = false }          // step back after a wide leap
                    else if rng.nextDouble() < 0.15 { dir = -dir }           // Jarrett wandering
                    let wide = i < count - 1 && rng.nextDouble() < 0.18
                    let size = wide ? 4 + rng.nextInt(upperBound: 2) : (rng.nextDouble() < 0.30 ? 2 : 1)
                    mv = dir * size
                    if wide { fillNext = rng.nextDouble() < 0.75 }
                }
                var next = Swift.max(0, Swift.min(pool.count - 1, idx + mv))
                if next == idx && mv != 0 { next = Swift.max(0, Swift.min(pool.count - 1, idx - mv)) }  // bounce off the edge
                if next != idx { lastDir = next > idx ? 1 : -1 }
                idx = next; idxs.append(idx)
            }
            // Last note: nearest pool note on an allowed tone, preferring the line's direction
            let endPCs = pnoEndingPCs(ending, frame: frame, rng: &rng)
            if let li = idxs.indices.last {
                // Avoid repeating the note before it, but never by jumping more than 3 scale steps
                let prevIdx = li > 0 ? idxs[li - 1] : -1
                let allowed = pool.indices.filter { endPCs.contains(Int(pool[$0]) % 12) }
                let near    = allowed.filter { $0 != prevIdx && abs($0 - idxs[li]) <= 3 }
                let chordPCs = pnoChordPCs(frame)
                let nearChord = pool.indices.filter { chordPCs.contains(Int(pool[$0]) % 12) && $0 != prevIdx && abs($0 - idxs[li]) <= 3 }
                var cands   = !near.isEmpty ? near : (!nearChord.isEmpty ? nearChord : allowed)
                if climb, li > 0 {
                    // The held top note stays above the note before it, so the climb doesn't sag at the end
                    let above = (cands + nearChord).filter { $0 > prevIdx }
                    if !above.isEmpty { cands = above }
                }
                if let best = cands.min(by: { abs($0 - idxs[li]) * 2 + ($0 - idxs[li] == -lastDir ? 1 : 0)
                                              < abs($1 - idxs[li]) * 2 + ($1 - idxs[li] == -lastDir ? 1 : 0) }) {
                    idxs[li] = best
                }
            }
            let peakNote = idxs.indices.max { pool[idxs[$0]] < pool[idxs[$1]] } ?? 0
            let cell = head != nil ? cellA : (rng.nextDouble() < 0.70 ? cellA : cellB)
            let stretch = Double(ioi) / 2.0
            let stop = Swift.min(totalSteps, endBy - 2)
            for i in 0..<idxs.count {
                guard step < stop else { break }
                let isLast = i == idxs.count - 1
                let note = pool[idxs[i]]
                let gap  = Swift.max(1, Int((Double(cell[i % cell.count]) * stretch).rounded()))
                let dur  = isLast ? Swift.min(holdDur, stop - step) : Swift.min(Swift.max(1, gap - 1), stop - step)
                guard dur >= 1 else { break }
                // Swell to the peak note, ease off after it
                let t: Double = i <= peakNote
                    ? (peakNote == 0 ? 1.0 : Double(i) / Double(peakNote))
                    : 1.0 - 0.5 * Double(i - peakNote) / Double(Swift.max(1, idxs.count - 1 - peakNote))
                let base = Double(velMin) + Double(velMax - velMin) * (0.35 + 0.65 * t)
                let vel  = pnoVel(Swift.max(1, Swift.min(127, Int(base.rounded()) + rng.nextInt(upperBound: 5) - 2)))
                ev.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: dur))
                // Chord accents: phrase launch and phrase peak — Jarrett/Winston style
                let isPeak = i == peakNote && i > 0
                if accents && (i == 0 || isPeak) {
                    let chordNote = pool.first(where: { Int($0) - Int(note) == 7 })  // P5 above
                                 ?? pool.first(where: { Int($0) - Int(note) == 4 })  // M3 above
                                 ?? pool.first(where: { Int($0) - Int(note) == 3 })  // m3 above
                    if let cn = chordNote {
                        ev.append(MIDIEvent(stepIndex: step, note: cn,
                                            velocity: vel > 5 ? vel - 5 : vel, durationSteps: dur))
                    }
                    // Jarrett touch: add a 3rd chord note at phrase peak (fuller chord stab)
                    if isPeak {
                        let third = pool.first(where: { Int($0) - Int(note) == 3 })   // m3 above
                               ?? pool.first(where: { Int($0) - Int(note) == 4 })     // M3 above
                        if let t = third, t != chordNote ?? 0 {
                            ev.append(MIDIEvent(stepIndex: step, note: t,
                                                velocity: vel > 8 ? vel - 8 : vel, durationSteps: dur))
                        }
                    }
                }
                step += isLast ? dur : gap
            }
            return (ev, idxs.last ?? pool.count / 2)
        }

        // Phrase 1 (opening) — enters at bar 1, no more than 1 bar of opening silence
        var burstEndIdx: Int = -1
        let p1Result = emitBurst(bar: p1Bar, pool: midNotes, count: 7 + rng.nextInt(upperBound: 4),
                                 velMin: 28, velMax: 42, ioi: 2, holdDur: 12,
                                 head: motifMoves, ending: .open)
        events += p1Result.events; burstEndIdx = p1Result.endIdx

        // Pre-climax phrase in 4-phrase form
        if preclimaxBar > 0 {
            let pcResult = emitBurst(bar: preclimaxBar, pool: midNotes, count: 8 + rng.nextInt(upperBound: 4),
                                     velMin: 38, velMax: 55, ioi: 2, holdDur: 10)
            events += pcResult.events; burstEndIdx = pcResult.endIdx
        }

        // Pre-climax ostinato (25%)
        if useOstinato && climaxBar >= 2, !midNotes.isEmpty {
            let ob    = Swift.max(0, climaxBar - 2)
            let oNote = midNotes[rng.nextInt(upperBound: midNotes.count)]
            var os    = ob * 16
            for _ in 0..<(3 + rng.nextInt(upperBound: 2)) {
                guard os < totalSteps else { break }
                events.append(MIDIEvent(stepIndex: os, note: oNote, velocity: pnoVel(36 + rng.nextInt(upperBound: 13)), durationSteps: Swift.min(6, totalSteps - os)))
                os += 8
            }
        }

        // Urgent question: a 3-5 note fragment repeated 2-3x with escalating velocity,
        // 4 bars before climax — Jarrett's classic "asking more urgently each time" device.
        // Ends with a bold foreshadow chord stab (vel 58-69) that hints at the coming climax.
        let urgentBar = climaxBar - 4
        if urgentBar > p1Bar + 4 && urgentBar >= 0 && !midNotes.isEmpty {
            // The fragment is the motif's head; 50% of songs push it up a scale step each time.
            let fragArr  = Array(midNotes.suffix(Swift.max(1, midNotes.count / 2)))
            let fragLen  = Swift.min(3 + rng.nextInt(upperBound: 2), motifMoves.count + 1)
            var fragIdx  = [0]
            for mv in motifMoves.prefix(fragLen - 1) { fragIdx.append(fragIdx.last! + mv) }
            let fragLow  = fragIdx.min() ?? 0, fragSpan = (fragIdx.max() ?? 0) - fragLow
            let fragBase = rng.nextInt(upperBound: Swift.max(1, fragArr.count - fragSpan - 2)) - fragLow
            let rising   = rng.nextDouble() < 0.50
            let repeats  = 2 + (rng.nextDouble() < 0.50 ? 1 : 0)
            var qs = urgentBar * 16 + rng.nextInt(upperBound: 4)
            for r in 0..<repeats {
                for n in 0..<fragLen {
                    guard qs < totalSteps else { break }
                    let idx = Swift.max(0, Swift.min(fragBase + fragIdx[n] + (rising ? r : 0), fragArr.count - 1))
                    let vel = pnoVel(Swift.min(64, 42 + r * 10 + rng.nextInt(upperBound: 8)))
                    let dur = Swift.min(2, totalSteps - qs)
                    guard dur >= 1 else { break }
                    events.append(MIDIEvent(stepIndex: qs, note: fragArr[idx], velocity: vel, durationSteps: dur))
                    qs += 2
                }
                qs += 4
            }
            // Foreshadow chord: bold 2-3 note stab after the repeats, previewing the climax register.
            let foreshadowLimit = (climaxBar - 2) * 16 - 4
            if qs < foreshadowLimit && !fragArr.isEmpty {
                let fNote = fragArr[Swift.max(0, Swift.min(fragArr.count - 1, fragBase + fragLen))]
                let fVel  = pnoVel(58 + rng.nextInt(upperBound: 12))
                let fDur  = Swift.min(6 + rng.nextInt(upperBound: 5), foreshadowLimit - qs)
                if fDur >= 4 {
                    events.append(MIDIEvent(stepIndex: qs, note: fNote, velocity: fVel, durationSteps: fDur))
                    if let fifth = fragArr.first(where: { Int($0) - Int(fNote) == 7 }) {
                        events.append(MIDIEvent(stepIndex: qs, note: fifth, velocity: fVel - 6, durationSteps: fDur))
                    } else if let third = fragArr.first(where: { [3, 4].contains(Int($0) - Int(fNote)) }) {
                        events.append(MIDIEvent(stepIndex: qs, note: third, velocity: fVel - 6, durationSteps: fDur))
                    }
                }
            }
        }

        // Fast 16th-note scalar run into the climax — 8-12 consecutive scale steps at 1-step IOI, vel rising 55→75.
        let scalarRunBar = climaxBar - 2
        if scalarRunBar >= 0 && scalarRunBar < totalBars && !midNotes.isEmpty {
            let runCount  = 8 + rng.nextInt(upperBound: 5)
            let ascending = rng.nextDouble() < 0.65
            let startIdx  = ascending
                ? rng.nextInt(upperBound: Swift.max(1, midNotes.count / 3))
                : midNotes.count / 2 + rng.nextInt(upperBound: Swift.max(1, midNotes.count / 2))
            let baseVel = 55 + rng.nextInt(upperBound: 10)
            var rs = scalarRunBar * 16 + rng.nextInt(upperBound: 4)
            for i in 0..<runCount {
                guard rs < totalSteps else { break }
                let idx = ascending
                    ? Swift.min(startIdx + i, midNotes.count - 1)
                    : Swift.max(0, startIdx - i)
                let vel = pnoVel(Swift.min(75, baseVel + i * 2))
                let dur = Swift.min(2, totalSteps - rs)
                guard dur >= 1 else { break }
                events.append(MIDIEvent(stepIndex: rs, note: midNotes[idx], velocity: vel, durationSteps: dur))
                rs += 1
            }
        }

        // Climax phrase — velocity ceiling 83 (Jarrett/Winston bold peak; was 88 until 2026-11-24, lowered to 78 with Lead 1 raised +2 dB, then 5 restored by Zack)
        var highestNote: UInt8 = 0
        let climaxHead: [Int]? = rng.nextDouble() < 0.70 ? motifMoves : nil   // the motif up high, then away
        // Half of the motif climaxes then climb straight to the held top note instead of arching
        let climaxClimb = climaxHead != nil && rng.nextDouble() < 0.50
        if useCallResp {
            let callResult = emitBurst(bar: climaxBar, pool: highNotes, count: 6 + rng.nextInt(upperBound: 3),
                                       velMin: 58, velMax: 83, ioi: 2, holdDur: 8, head: climaxHead,
                                       climb: climaxClimb)
            let respResult = emitBurst(bar: climaxBar + 2, pool: midNotes, count: 7 + rng.nextInt(upperBound: 3),
                                       velMin: 45, velMax: 68, ioi: 2, holdDur: 10)
            events += callResult.events + respResult.events
            highestNote = (callResult.events + respResult.events).max(by: { $0.note < $1.note })?.note ?? 0
        } else {
            let cResult = emitBurst(bar: climaxBar, pool: highNotes, count: 9 + rng.nextInt(upperBound: 4),
                                    velMin: 58, velMax: 83, ioi: 2, holdDur: 16, head: climaxHead,
                                    climb: climaxClimb)
            events += cResult.events
            highestNote = cResult.events.max(by: { $0.note < $1.note })?.note ?? 0
        }

        // Bold block chord at climax peak — 3-4 simultaneous notes (the "fist on keys" moment).
        // 50% chance of a second chord hit, either tight (2-4 steps) or a beat apart (6-10 steps).
        let chordStep = climaxBar * 16 + 4
        if chordStep < totalSteps - 8, !highNotes.isEmpty {
            let rootIdx   = rng.nextInt(upperBound: Swift.max(1, highNotes.count / 2))
            let chordRoot = highNotes[rootIdx]
            let chordVel  = pnoVel(73 + rng.nextInt(upperBound: 12))
            let chordDur  = Swift.min(8 + rng.nextInt(upperBound: 5), totalSteps - chordStep)
            events += chordHit(at: chordStep, root: chordRoot, pool: highNotes, vel: chordVel, dur: chordDur)
            if rng.nextDouble() < 0.50,
               let top = highNotes.first(where: { Int($0) - Int(chordRoot) == 12 }) {
                events.append(MIDIEvent(stepIndex: chordStep, note: top, velocity: chordVel - 12, durationSteps: chordDur))
            }
            // Second chord hit — tight double (2-4 steps) or a beat apart (6-10 steps)
            if rng.nextDouble() < 0.50 {
                let gap2  = rng.nextDouble() < 0.50 ? 2 + rng.nextInt(upperBound: 3)
                                                    : 6 + rng.nextInt(upperBound: 5)
                let step2 = chordStep + gap2
                let vel2  = pnoVel(Swift.max(60, Int(chordVel) - 8 - rng.nextInt(upperBound: 8)))
                let dur2  = Swift.min(6 + rng.nextInt(upperBound: 5), totalSteps - step2)
                if step2 < totalSteps - 4, dur2 >= 2 {
                    events += chordHit(at: step2, root: chordRoot, pool: highNotes, vel: vel2, dur: dur2)
                }
            }
        }

        // Minor peaks (KolnArc, about a third of songs): a quick run up, then a shorter, softer
        // climax in the middle register, the motif at its head half the time. They peak around
        // velocity 68 against the climax's 83, and stay under its register.
        for pb in arc.peakBars where pb >= 2 && pb < totalBars - 4 {
            let runLen = 5 + rng.nextInt(upperBound: 3)
            let runTop = Swift.min(midNotes.count - 1, midNotes.count * 2 / 3)
            var rs = (pb - 1) * 16 + 16 - runLen - 1
            var runEv: [MIDIEvent] = []
            for i in 0..<runLen where runTop - runLen + 1 + i >= 0 {
                runEv.append(MIDIEvent(stepIndex: rs, note: midNotes[runTop - runLen + 1 + i],
                                       velocity: pnoVel(44 + i * 3 + rng.nextInt(upperBound: 4)), durationSteps: 1))
                rs += 1
            }
            let peakResult = emitBurst(bar: pb, pool: midNotes, count: 6 + rng.nextInt(upperBound: 3),
                                       velMin: 42, velMax: 68, ioi: 2, holdDur: 10,
                                       startNear: runTop,
                                       head: rng.nextDouble() < 0.50 ? motifMoves : nil,
                                       endBy: (pb + 6) * 16)
            events += runEv + peakResult.events
        }

        // Post-climax descending run (50%)
        if usePostClimax && !nearPeak(climaxBar + 6) && !nearPeak(climaxBar + 10) {
            let runBar = climaxBar + 6
            if runBar < totalBars, !midNotes.isEmpty {
                var rs  = runBar * 16
                let top = midNotes.count - 1
                for i in 0..<(6 + rng.nextInt(upperBound: 5)) {
                    guard rs < totalSteps else { break }
                    let idx = Swift.max(0, top - i)
                    let vel = pnoVel(Swift.max(20, 55 - i * 5))
                    events.append(MIDIEvent(stepIndex: rs, note: midNotes[idx], velocity: vel, durationSteps: Swift.min(4, totalSteps - rs)))
                    rs += 8
                }
            }
        }

        // Post-climax echo — mid-register bridge between descending run and withdrawal phrase
        let echoBar = climaxBar + 10
        if echoBar < withdrawBar - 2 && !nearPeak(echoBar) && !nearPeak(echoBar + 3) {
            let echoEv = emitBurst(bar: echoBar, pool: midNotes,
                                   count: 6 + rng.nextInt(upperBound: 3),
                                   velMin: 35, velMax: 52, ioi: 2, holdDur: 14).events
            events += echoEv
        }


        // Withdrawal phrase
        let wPool = midNotes.filter { $0 <= 72 }.isEmpty ? midNotes : midNotes.filter { $0 <= 72 }
        let wStartIdx = burstEndIdx < wPool.count ? burstEndIdx : -1
        let wHead: [Int]? = rng.nextDouble() < 0.60 ? motifMoves : nil   // the motif again, slower and lower
        var wEvts = emitBurst(bar: withdrawBar, pool: wPool, count: 5 + rng.nextInt(upperBound: 3),
                              velMin: 25, velMax: 42, ioi: 3, holdDur: 20, startNear: wStartIdx, head: wHead).events

        // Parting gesture: copy highest climax note as first note of withdrawal phrase
        if useParting && highestNote > 0 && withdrawBar < totalBars {
            let ps = withdrawBar * 16
            if !wEvts.contains(where: { $0.stepIndex == ps && $0.note == highestNote }) {
                let pd = Swift.min(16 + rng.nextInt(upperBound: 9), totalSteps - ps)
                wEvts.insert(MIDIEvent(stepIndex: ps, note: highestNote, velocity: 42, durationSteps: pd), at: 0)
            }
        }
        events += wEvts

        // Soft pool (≤70): used by closing phrase and connective phrases — computed once
        let cPool = midNotes.filter { $0 <= 70 }.isEmpty ? midNotes : midNotes.filter { $0 <= 70 }

        // Closing phrase — soft lyric fragment in last ~17% of song
        if closingBar < totalBars - 2 {
            let closeEv = emitBurst(bar: closingBar, pool: cPool, count: 4 + rng.nextInt(upperBound: 3),
                                    velMin: 20, velMax: 35, ioi: 3, holdDur: 24,
                                    head: motifMoves, ending: .home).events
            events += closeEv
        }

        // Building arc — geometric spacing (early phrases far apart, compressing toward climax).
        // IOI tightens from quarter-note feel (4 steps) to 8th-note feel (2 steps) as arc builds.
        // Velocity range rises from 28-40 at opening to 54-68 near climax.
        let buildBars = climaxBar - p1Bar - 4
        if buildBars > 6 {
            let arcCount = 4 + rng.nextInt(upperBound: 3)
            let ratio    = 0.72   // each gap 72% of previous — compresses toward climax
            let g        = Double(buildBars) * (1.0 - ratio) / (1.0 - pow(ratio, Double(arcCount)))
            var pBar     = p1Bar + 4
            for p in 0..<arcCount {
                guard pBar < climaxBar - 4 else { break }
                let progress  = Double(p) / Double(Swift.max(1, arcCount - 1))
                let gap0      = Swift.max(2, Int(g * pow(ratio, Double(p))))
                // A minor peak owns these bars: no build phrase here.
                if nearPeak(pBar) || nearPeak(pBar + 3) {
                    pBar += gap0 + rng.nextInt(upperBound: Swift.max(1, gap0 / 3))
                    continue
                }
                let noteCount = 5 + rng.nextInt(upperBound: 4)
                let idxLo     = Int(Double(midNotes.count - 1) * progress * 0.40)
                let idxHi     = Int(Double(midNotes.count - 1) * (0.35 + progress * 0.55))
                let safeHi    = Swift.min(Swift.max(idxLo, idxHi), midNotes.count - 1)
                let startIdx  = idxLo + (safeHi > idxLo ? rng.nextInt(upperBound: safeHi - idxLo + 1) : 0)
                let velLo     = 28 + Int(progress * 26)   // 28→54 across build
                let velHi     = 40 + Int(progress * 28)   // 40→68 across build
                let phraseIOI = Swift.max(2, 4 - Int(progress * 2.5))  // 4→2 steps
                // Finish before the next set piece: the pre-climax phrase, else the urgent question
                var buildEndBy = (preclimaxBar > pBar ? preclimaxBar : climaxBar - 4) * 16
                if let nextPeak = arc.peakBars.first(where: { $0 > pBar }) {
                    buildEndBy = Swift.min(buildEndBy, (nextPeak - 3) * 16)
                }
                let buildEv   = emitBurst(bar: pBar, pool: midNotes, count: noteCount,
                                          velMin: velLo, velMax: velHi, ioi: phraseIOI,
                                          holdDur: 12 + rng.nextInt(upperBound: 9),
                                          startNear: startIdx, accents: false,
                                          endBy: buildEndBy).events
                events += buildEv
                let gap    = Swift.max(2, Int(g * pow(ratio, Double(p))))
                let jitter = rng.nextInt(upperBound: Swift.max(1, gap / 3))
                pBar += gap + jitter
            }
        }

        // Ascending bass arpeggio — Jarrett gesture: low root climbs through 3-4 scale tones into
        // mid register, landing on a held top note. Fires once very early, 50% chance.
        let arpBar = p1Bar + 2 + rng.nextInt(upperBound: 4)
        if arpBar < climaxBar - 4 && rng.nextDouble() < 0.50 && !lowNotes.isEmpty && !midNotes.isEmpty {
            let arpRoot   = lowNotes[rng.nextInt(upperBound: lowNotes.count)]
            let arpTarget = (lowNotes + midNotes).sorted().filter { $0 >= arpRoot }
            let arpPts    = Swift.min(3 + rng.nextInt(upperBound: 2), arpTarget.count)
            var arpStep   = arpBar * 16 + rng.nextInt(upperBound: 4)
            for n in 0..<arpPts {
                guard arpStep < totalSteps else { break }
                let isLast = n == arpPts - 1
                let dur = isLast
                    ? Swift.min(12 + rng.nextInt(upperBound: 9), totalSteps - arpStep)
                    : Swift.min(3, totalSteps - arpStep)
                guard dur >= 1 else { break }
                let vel = pnoVel(Swift.min(50, 24 + n * 6 + rng.nextInt(upperBound: 8)))
                events.append(MIDIEvent(stepIndex: arpStep, note: arpTarget[n], velocity: vel, durationSteps: dur))
                arpStep += dur + (isLast ? 0 : 1)
            }
        }

        // Pedal point oscillation — Jarrett gesture: a held mid-register note with 2 pitches
        // cycling above it. Fires once in the early-to-mid build zone, 60% chance.
        let pedalZone = Swift.max(1, climaxBar * 30 / 100 - (p1Bar + 4))
        let pedalBar  = p1Bar + 4 + rng.nextInt(upperBound: Swift.max(1, pedalZone))
        if pedalBar < climaxBar - 6 && rng.nextDouble() < 0.60 && midNotes.count >= 3 {
            let pedalIdx  = rng.nextInt(upperBound: Swift.max(1, midNotes.count / 2))
            let pedalNote = midNotes[pedalIdx]
            let osc1Note  = midNotes[Swift.min(pedalIdx + 2, midNotes.count - 1)]
            let osc2Note  = midNotes[Swift.min(pedalIdx + 4, midNotes.count - 1)]
            let cycleCount = 3 + rng.nextInt(upperBound: 3)
            let pedalVel  = pnoVel(26 + rng.nextInt(upperBound: 12))
            var pedalStep = pedalBar * 16
            for _ in 0..<cycleCount {
                guard pedalStep + 4 < totalSteps else { break }
                let holdDur = Swift.min(8 + rng.nextInt(upperBound: 5), totalSteps - pedalStep)
                guard holdDur >= 4 else { break }
                events.append(MIDIEvent(stepIndex: pedalStep, note: pedalNote, velocity: pedalVel, durationSteps: holdDur))
                pedalStep += holdDur
                guard pedalStep < totalSteps else { break }
                let oscNote = rng.nextDouble() < 0.60 ? osc1Note : osc2Note
                let oscDur  = Swift.min(4 + rng.nextInt(upperBound: 4), totalSteps - pedalStep)
                guard oscDur >= 2 else { break }
                events.append(MIDIEvent(stepIndex: pedalStep, note: oscNote,
                                        velocity: pnoVel(Swift.max(18, Int(pedalVel) - 4 + rng.nextInt(upperBound: 8))),
                                        durationSteps: oscDur))
                pedalStep += oscDur
            }
        }

        // High-register reach — 1-2 isolated "voice from above" notes in the build zone.
        // Single high notes, long duration, soft-to-mid velocity — distinctly Jarrett.
        let reachPool = notesInRegister(pitchClasses: scalePCs, low: 79, high: 93)
        if !reachPool.isEmpty && climaxBar - p1Bar > 8 {
            let reachCount = 1 + (rng.nextDouble() < 0.50 ? 1 : 0)
            let reachZone  = Swift.max(1, climaxBar - p1Bar - 6)
            for r in 0..<reachCount {
                let reachBar = p1Bar + 6 + (reachZone * r) / Swift.max(1, reachCount)
                              + rng.nextInt(upperBound: Swift.max(1, reachZone / Swift.max(1, reachCount) / 2))
                guard reachBar < climaxBar - 2 else { break }
                let rs   = reachBar * 16 + rng.nextInt(upperBound: 8)
                guard rs < totalSteps else { break }
                let rDur = Swift.min(12 + rng.nextInt(upperBound: 9), totalSteps - rs)
                guard rDur >= 8 else { break }
                let rNote = reachPool[rng.nextInt(upperBound: reachPool.count)]
                let rVel  = pnoVel(50 + rng.nextInt(upperBound: 18))
                events.append(MIDIEvent(stepIndex: rs, note: rNote, velocity: rVel, durationSteps: rDur))
                reachLog?.steps.append(rs)
                // Reach echoes (Zack, 2026-11-24): one roll, a third each: the reach stands alone,
                // gets one echo, or gets two echoes within the next 2 bars; an echo is the same pitch (40%) or another high scale tone within a fifth.
                // Drawn on a stream of its own so no other draw in the song moves.
                var echoRng = SeededRNG(seed: (UInt64(rs) &* 0x9E37_79B9_7F4A_7C15) ^ UInt64(rNote) ^ 0xEC40_0005_0000_0001)
                let echoRoll = echoRng.nextDouble()
                let echoes = echoRoll < 0.3333 ? 1 : echoRoll < 0.6667 ? 2 : 0
                var echoStep = rs + rDur
                for k in 0..<echoes {
                    echoStep += (k == 0 ? 3 + echoRng.nextInt(upperBound: 5) : 6 + echoRng.nextInt(upperBound: 8))
                    let eDur = 8 + echoRng.nextInt(upperBound: 5)
                    guard echoStep + eDur < climaxBar * 16 - 4, echoStep + eDur <= totalSteps else { break }
                    // 40% an exact repeat, else another high scale tone within a fifth of the reach
                    // (a step, third, fourth or fifth either way), so the echo stays in its octave.
                    let near = reachPool.filter { $0 != rNote && abs(Int($0) - Int(rNote)) <= 7 }
                    let eNote = (near.isEmpty || echoRng.nextDouble() < 0.40) ? rNote
                              : near[echoRng.nextInt(upperBound: near.count)]
                    events.append(MIDIEvent(stepIndex: echoStep, note: eNote,
                                            velocity: pnoVel(Swift.max(30, Int(rVel) - 8 - 4 * k)), durationSteps: eDur))
                    echoStep += eDur
                }
            }
        }

        // Two connective phrases between withdrawal and closing — meditative fragments, not silence
        let decayZone = withdrawBar + 4
        if decayZone < closingBar - 2 {
            let softPool = cPool   // same filter as closing phrase (≤70), computed above
            let decaySpan = closingBar - decayZone
            // First connective phrase — earlier third of the decay zone
            let conn1Bar = decayZone + rng.nextInt(upperBound: Swift.max(1, decaySpan / 3))
            let conn2Bar = decayZone + decaySpan * 2 / 3 + rng.nextInt(upperBound: Swift.max(1, decaySpan / 4))
            let c1Ev = emitBurst(bar: conn1Bar, pool: softPool,
                                 count: 7 + rng.nextInt(upperBound: 4),
                                 velMin: 22, velMax: 38, ioi: 3, holdDur: 18, startNear: wStartIdx,
                                 endBy: Swift.min(conn2Bar, closingBar) * 16).events
            if !nearPeak(conn1Bar) && !nearPeak(conn1Bar + 3) { events += c1Ev }
            // Second connective phrase — later two-thirds, fading further
            if conn2Bar < closingBar - 1 && !nearPeak(conn2Bar) && !nearPeak(conn2Bar + 3) {
                let c2Ev = emitBurst(bar: conn2Bar, pool: softPool,
                                     count: 5 + rng.nextInt(upperBound: 3),
                                     velMin: 20, velMax: 34, ioi: 3, holdDur: 20, startNear: wStartIdx,
                                     endBy: closingBar * 16).events
                events += c2Ev
            }
        }

        // Aftershock — 1-2 hard chord stabs reminiscent of the climax (vel 52-69),
        // spread between withdrawal and closing. 45% chance of a second hit per stab,
        // tight (2-4 steps) or slightly spaced (5-8 steps).
        let aftershockBase = withdrawBar + 2
        if aftershockBase < closingBar - 2 && !midNotes.isEmpty {
            let shockCount = 1 + (rng.nextDouble() < 0.50 ? 1 : 0)
            let shockZone  = Swift.max(1, closingBar - aftershockBase)
            let shockPool  = Array(midNotes.suffix(Swift.max(1, midNotes.count / 2)))
            for sh in 0..<shockCount {
                let shockBar = aftershockBase + (shockZone * sh) / Swift.max(1, shockCount)
                guard shockBar < closingBar - 1 else { break }
                if nearPeak(shockBar) { continue }   // a minor peak stands in for this stab
                let ss      = shockBar * 16 + rng.nextInt(upperBound: 4)
                guard ss < totalSteps - 6 else { break }
                let rootIdx = rng.nextInt(upperBound: Swift.max(1, shockPool.count / 2))
                let sRoot   = shockPool[rootIdx]
                let sVel    = pnoVel(52 + rng.nextInt(upperBound: 18))
                let sDur    = Swift.min(6 + rng.nextInt(upperBound: 5), totalSteps - ss)
                guard sDur >= 4 else { break }
                events += chordHit(at: ss, root: sRoot, pool: shockPool, vel: sVel, dur: sDur)
                // Second hit per stab — 45% chance
                if rng.nextDouble() < 0.45 {
                    let gap2  = rng.nextDouble() < 0.50 ? 2 + rng.nextInt(upperBound: 3)
                                                        : 5 + rng.nextInt(upperBound: 4)
                    let ss2   = ss + gap2
                    let sVel2 = pnoVel(Swift.max(38, Int(sVel) - 8 - rng.nextInt(upperBound: 8)))
                    let sDur2 = Swift.min(4 + rng.nextInt(upperBound: 4), totalSteps - ss2)
                    if ss2 < totalSteps - 4, sDur2 >= 2 {
                        events += chordHit(at: ss2, root: sRoot, pool: shockPool, vel: sVel2, dur: sDur2)
                    }
                }
            }
        }

        // Right hand over the vamp: each 2-bar slot the melody leaves nearly empty gets a short
        // phrase, climbing and louder as the vamp goes on; 40% of them repeat the last one as a
        // riff, a third open with the motif.
        if let vamp = arc.vampBars {
            var lastRiff: [MIDIEvent] = [], riffOffset = 0
            var slot = vamp.lowerBound
            while slot + 1 < vamp.upperBound {
                let s0 = slot * 16, s1 = Swift.min(vamp.upperBound, slot + 2) * 16
                let p = Double(slot - vamp.lowerBound) / Double(Swift.max(1, vamp.count - 2))
                let busy = events.filter { $0.note >= 62 && $0.stepIndex >= s0 && $0.stepIndex < s1 }.count
                    + events.filter { $0.note >= 62 && $0.stepIndex < s0 && $0.stepIndex + $0.durationSteps > s0 + 8 }.count * 2
                if busy < 3 {
                    let velHi = 48 + Int(p * 18)
                    if !lastRiff.isEmpty && rng.nextDouble() < 0.40 {
                        events += pnoReplay(lastRiff, at: s0 + riffOffset, velCap: velHi,
                                            totalSteps: totalSteps).filter { $0.stepIndex < s1 }
                    } else {
                        let start = Int(Double(midNotes.count - 1) * (0.25 + p * 0.45))
                        let ph = emitBurst(bar: slot, pool: midNotes, count: 3 + Int(p * 3) + rng.nextInt(upperBound: 2),
                                           velMin: velHi - 14, velMax: velHi, ioi: p < 0.5 ? 3 : 2,
                                           holdDur: 6 + rng.nextInt(upperBound: 5), startNear: start,
                                           head: rng.nextDouble() < 0.33 ? motifMoves : nil,
                                           accents: false, endBy: s1 - 1).events
                        events += ph
                        if let f = ph.first {
                            riffOffset = f.stepIndex % 16
                            lastRiff = ph.map { MIDIEvent(stepIndex: $0.stepIndex - f.stepIndex, note: $0.note,
                                                          velocity: $0.velocity, durationSteps: $0.durationSteps) }
                        }
                    }
                }
                slot += 2
            }
        }

        // Bass punctuation (placed once the melody exists) — low note held 1–3 bars, scattered ~every 12 bars through the build zone
        // plus one anchor in the withdrawal zone. Typically 3–5 occurrences per song.
        if !lowNotes.isEmpty {
            var bassBars: [Int] = []
            var bCursor = 4 + rng.nextInt(upperBound: 4)            // first: bar 4–7
            let bassStop = climaxBar - 4
            while bCursor < bassStop {
                bassBars.append(bCursor)
                bCursor += 10 + rng.nextInt(upperBound: 5)          // step 10–14 bars
            }
            let wAnchor = withdrawBar + 2 + rng.nextInt(upperBound: 4)
            if wAnchor < closingBar - 2 { bassBars.append(wAnchor) }
            for bBar in bassBars where bBar < totalBars {
                if let v = arc.vampBars, bBar + 3 > v.lowerBound && bBar < v.upperBound { continue }   // the vamp has its own pedal
                let bd    = Swift.min(Swift.min(16 + rng.nextInt(upperBound: 33), 48), totalSteps - bBar * 16)
                // A low note that doesn't rub (half-step, tritone, major 7th) with the melody over it
                let over  = events.filter { $0.stepIndex < bBar * 16 + bd && $0.stepIndex + $0.durationSteps > bBar * 16 }
                let clean = lowNotes.filter { n in !over.contains { pnoRubs(Int($0.note), Int(n)) } }
                let pick  = rng.nextInt(upperBound: lowNotes.count)
                guard !clean.isEmpty else { continue }
                let bn = clean[pick % clean.count]
                if bd >= 4 {
                    events.append(MIDIEvent(stepIndex: bBar * 16, note: bn,
                                            velocity: pnoVel(28 + rng.nextInt(upperBound: 18)), durationSteps: bd))
                }
            }
        }

        // Winston/Jarrett left-hand: bass + arpeggiated chord tones throughout the song.
        // lhMid at 61-72 (above middle C) so mid tones register as melody, not bass.
        // Bass changes every 2 bars for variety; mid indices cycle independently per bar.
        // Exclude bass notes whose tritone partner is also in the scale (e.g. B and F in
        // Mixolydian/Dorian) — they cause cross-register tritone clashes with the melody.
        let lhBassAll = lowNotesAll   // the same low register and clean-of-tritone filter as the bass punctuation
        let lhBass    = lowNotes
        let lhMid  = notesInRegister(pitchClasses: scalePCs, low: 61, high: 72)
        if !lhBass.isEmpty, !lhMid.isEmpty {
            let rootPC    = frame.keySemitoneValue % 12
            let lhRoot    = lhBass.first(where: { Int($0) % 12 == rootPC }) ?? lhBass[0]
            let lhRootIdx = lhBass.firstIndex(of: lhRoot) ?? 0
            // Snapshot of RH melody notes already generated — scores bass candidates and keeps the
            // inner voices under the melody.
            let melodySnap = events.filter { $0.note >= 55 }
            var prevBassNote: UInt8 = 0
            for lhBar in 0..<totalBars {
                let barStep = lhBar * 16
                guard barStep < totalSteps else { break }
                if arc.vampBars?.contains(lhBar) == true { continue }   // the vamp plays these bars
                // Bass steps through the full pool every 2 bars (previously only covered half).
                let defaultIdx = (lhRootIdx + (lhBar / 2)) % lhBass.count
                let barEnd = barStep + 16
                let melodyInBar = melodySnap.filter {
                    $0.stepIndex < barEnd && ($0.stepIndex + $0.durationSteps) > barStep
                }
                // Score each bass candidate by the harmony it creates with sustaining melody.
                // P5/P4 (open, majestic) → thirds/sixths (warm) → m7 (jazzy) → penalise clashes.
                // Repetition penalty (-3) discourages same note two bars running without overriding
                // a genuine consonance advantage.
                // Ties broken by: default cycling pattern first, then proximity to root.
                let scoreNote: (UInt8) -> Int = { candidate in
                    var score = 0
                    if candidate == prevBassNote { score -= 2 }
                    for mel in melodyInBar {
                        let ivl = abs(Int(candidate) - Int(mel.note)) % 12
                        switch ivl {
                        case 7, 5:  score += 3   // P5, P4
                        case 0:     score += 2   // octave
                        case 4, 3:  score += 2   // M3, m3
                        case 9, 8:  score += 2   // M6, m6
                        case 10:    score += 1   // m7
                        case 1, 11: score -= 10  // m2, M7
                        case 6:     score -= 10  // tritone
                        case 2 where Swift.min(candidate, mel.note) < 55:
                                    score -= 8   // bass M2
                        default:    break
                        }
                    }
                    return score
                }
                let bIdx: Int
                if melodyInBar.isEmpty {
                    bIdx = defaultIdx
                } else {
                    bIdx = lhBass.indices
                        .sorted {
                            let s0 = scoreNote(lhBass[$0]), s1 = scoreNote(lhBass[$1])
                            if s0 != s1 { return s0 > s1 }
                            if $0 == defaultIdx { return true }
                            if $1 == defaultIdx { return false }
                            return abs(Int(lhBass[$0]) - Int(lhRoot)) < abs(Int(lhBass[$1]) - Int(lhRoot))
                        }
                        .first ?? defaultIdx
                }
                let bNote = lhBass[bIdx]
                prevBassNote = bNote
                let bVel  = pnoVel(38 + rng.nextInt(upperBound: 12))
                // Beat 1 (step 0): bass alone — arrives first like Winston/Jarrett LH
                events.append(MIDIEvent(stepIndex: barStep, note: bNote, velocity: bVel, durationSteps: 7))
                // Inner voices are the bass note's own triad, kept under the melody (lhTones): 3rd and
                // 5th on beat 2, 5th and root on beat 3 (a different inversion), the 3rd on beat 4.
                // Where nothing fits under a low melody note, that beat rests.
                // Beat 2 (step 4): 2-note chord stab — skip both beats 2+3 on ~20% of bars
                // for Jarrett-style breathing space (just bass + optional beat 4).
                let skipInner = rng.nextDouble() < 0.20
                if !skipInner && barStep + 4 < totalSteps {
                    let cv    = pnoVel(30 + rng.nextInt(upperBound: 10))
                    let tones = lhTones(bass: bNote, scalePCs: scalePCs, low: 52, high: 67, target: 60,
                                        prefer: [1, 2, 0], count: 2, melody: melodySnap,
                                        start: barStep + 4, end: barStep + 10)
                    for (k, t) in tones.enumerated() {
                        events.append(MIDIEvent(stepIndex: barStep + 4, note: t, velocity: k == 0 ? cv : cv - 3, durationSteps: 6))
                    }
                }
                // Beat 3 (step 8): inner-voice repeat — 65% of bars.
                if !skipInner && barStep + 8 < totalSteps && rng.nextDouble() < 0.65 {
                    let cv2   = pnoVel(26 + rng.nextInt(upperBound: 10))
                    let tones = lhTones(bass: bNote, scalePCs: scalePCs, low: 52, high: 67, target: 61,
                                        prefer: [2, 0, 1], count: 2, melody: melodySnap,
                                        start: barStep + 8, end: barStep + 13)
                    for (k, t) in tones.enumerated() {
                        events.append(MIDIEvent(stepIndex: barStep + 8, note: t, velocity: k == 0 ? cv2 : cv2 - 3, durationSteps: 5))
                    }
                }
                // Beat 4 (step 12): single lighter note — breathing space (45% of bars).
                if barStep + 12 < totalSteps, rng.nextDouble() < 0.45,
                   let t = lhTones(bass: bNote, scalePCs: scalePCs, low: 52, high: 67, target: 62,
                                   prefer: [1, 2], count: 1, melody: melodySnap,
                                   start: barStep + 12, end: barStep + 16).first {
                    events.append(MIDIEvent(stepIndex: barStep + 12, note: t,
                                            velocity: pnoVel(22 + rng.nextInt(upperBound: 8)), durationSteps: 4))
                }
            }

            // Vamp (after Koln Part IIa): the left hand rocks between the home chord and a
            // neighbour chord over a low pedal, building to the urgent question.
            if let vamp = arc.vampBars {
                events += kolnVamp(bars: vamp, frame: frame, lhBass: lhBass, lhRoot: lhRoot,
                                   melody: melodySnap, totalSteps: totalSteps, rng: &rng)
            }
        }

        // High-note follow-up: when a melody note reaches E5 (MIDI 76+) in the build zone,
        // 55% chance of adding 2-3 scale-step notes continuing in that altitude.
        let buildCutoff  = (climaxBar - 4) * 16
        let highThresh: UInt8 = 76
        let triggerList  = events
            .filter { $0.note >= highThresh && $0.stepIndex < buildCutoff && $0.durationSteps >= 4 }
            .sorted { $0.stepIndex < $1.stepIndex }
        var lastTrigStep = -20
        for trigger in triggerList {
            guard trigger.stepIndex - lastTrigStep > 8 else { continue }
            lastTrigStep = trigger.stepIndex
            guard rng.nextDouble() < 0.55 else { continue }
            let followCount  = 2 + rng.nextInt(upperBound: 2)
            let trigPoolIdx  = highNotes.firstIndex(of: trigger.note) ?? (highNotes.count / 2)
            let descending   = rng.nextDouble() < 0.60
            var hIdx         = trigPoolIdx
            var fs           = trigger.stepIndex + trigger.durationSteps + 1 + rng.nextInt(upperBound: 3)
            for n in 0..<followCount {
                guard fs < buildCutoff, hIdx >= 0, hIdx < highNotes.count else { break }
                let isLast = n == followCount - 1
                let dur    = isLast
                    ? Swift.min(8 + rng.nextInt(upperBound: 9), buildCutoff - fs)
                    : Swift.min(2 + rng.nextInt(upperBound: 3), buildCutoff - fs)
                guard dur >= 2 else { break }
                let vel = pnoVel(Swift.max(20, Int(trigger.velocity) - 6 - n * 4))
                events.append(MIDIEvent(stepIndex: fs, note: highNotes[hIdx], velocity: vel, durationSteps: dur))
                fs += dur + (isLast ? 0 : 1 + rng.nextInt(upperBound: 2))
                let step = 1 + (rng.nextDouble() < 0.30 ? 1 : 0)
                hIdx = descending ? Swift.max(0, hIdx - step) : Swift.min(highNotes.count - 1, hIdx + step)
            }
        }

        // Jarrett-style resolution chord in the last 3 bars — suppressed for evolve passes
        // (anchor song's outro already provides the true ending chord).
        let resBar  = totalBars - 3
        let resStep = resBar * 16
        if !isEvolvePass, resStep > 0, resStep < totalSteps {
            events = events.filter { $0.stepIndex < resStep }
            let rootPC  = frame.keySemitoneValue % 12
            let fifthPC = (rootPC + 7) % 12
            let thirdPC = pnoThirdPC(of: rootPC, in: scalePCs) ?? (rootPC + 3) % 12
            let ninthPC = (rootPC + 2) % 12
            let allSorted = (midNotes + highNotes).sorted()
            let bassRoot  = lhBassAll.first { Int($0) % 12 == rootPC }
            let lowFifth  = lhMid.first     { Int($0) % 12 == fifthPC }
            let midRoot   = midNotes.first  { Int($0) % 12 == rootPC }
            let midFifth  = midNotes.first  { Int($0) % 12 == fifthPC }
            let midThird  = allSorted.first { Int($0) % 12 == thirdPC && $0 > (midFifth ?? 60) }
            let midNinth  = allSorted.first { Int($0) % 12 == ninthPC && $0 > (midFifth ?? 60) }
            let highRoot  = allSorted.last  { Int($0) % 12 == rootPC  && $0 > (midFifth ?? 60) }
            let highNinth = allSorted.first { Int($0) % 12 == ninthPC && $0 > (highRoot  ?? 72) }
            let resDur = Swift.min(40, totalSteps - resStep - 1)
            if resDur >= 8 {
                let bVel    = pnoVel(50 + rng.nextInt(upperBound: 8))
                let variant = rng.nextInt(upperBound: 3)
                if let bn = bassRoot {
                    events.append(MIDIEvent(stepIndex: resStep, note: bn,
                                            velocity: bVel, durationSteps: resDur))
                }
                switch variant {
                case 0:
                    // A: spread triad — 5th + 3rd + high root land together on beat 2
                    if let mn = midFifth {
                        events.append(MIDIEvent(stepIndex: resStep + 4, note: mn,
                                                velocity: bVel > 5  ? bVel - 5  : bVel, durationSteps: resDur - 4))
                    }
                    if let mt = midThird {
                        events.append(MIDIEvent(stepIndex: resStep + 4, note: mt,
                                                velocity: bVel > 8  ? bVel - 8  : bVel, durationSteps: resDur - 4))
                    }
                    if let hr = highRoot {
                        events.append(MIDIEvent(stepIndex: resStep + 4, note: hr,
                                                velocity: bVel > 11 ? bVel - 11 : bVel, durationSteps: resDur - 4))
                    }
                case 1:
                    // B: add9 — 5th + 9th + high root on beat 2 (open, modal colour)
                    if let mn = midFifth {
                        events.append(MIDIEvent(stepIndex: resStep + 4, note: mn,
                                                velocity: bVel > 5  ? bVel - 5  : bVel, durationSteps: resDur - 4))
                    }
                    if let ni = midNinth {
                        events.append(MIDIEvent(stepIndex: resStep + 4, note: ni,
                                                velocity: bVel > 8  ? bVel - 8  : bVel, durationSteps: resDur - 4))
                    }
                    if let hr = highRoot {
                        events.append(MIDIEvent(stepIndex: resStep + 4, note: hr,
                                                velocity: bVel > 11 ? bVel - 11 : bVel, durationSteps: resDur - 4))
                    }
                default:
                    // C: slow roll — each note enters 2 steps after the last, like a pianist
                    // settling into a final statement (most distinctly Jarrett)
                    if let lf = lowFifth {
                        events.append(MIDIEvent(stepIndex: resStep + 2, note: lf,
                                                velocity: bVel > 4  ? bVel - 4  : bVel, durationSteps: resDur - 2))
                    }
                    if let mr = midRoot {
                        events.append(MIDIEvent(stepIndex: resStep + 4, note: mr,
                                                velocity: bVel > 7  ? bVel - 7  : bVel, durationSteps: resDur - 4))
                    }
                    if let mt = midThird {
                        events.append(MIDIEvent(stepIndex: resStep + 6, note: mt,
                                                velocity: bVel > 10 ? bVel - 10 : bVel, durationSteps: resDur - 6))
                    }
                    if let hn = highNinth ?? highRoot {
                        events.append(MIDIEvent(stepIndex: resStep + 8, note: hn,
                                                velocity: bVel > 13 ? bVel - 13 : bVel, durationSteps: resDur - 8))
                    }
                }
            }
        }

        let trimmed = trimDissonances(events, totalSteps: totalSteps)
        // Log variant, settled once: "vamp" when the arc has the vamp, "jazzy improv" when the live
        // wire plays. The live wire is drawn last, so a song without it is note for note what it was
        // (Zack, 2026-11-24): 45% of Koln songs, 40+ bars, never an evolve pass.
        let hasVamp = arc.vampBars != nil
        let hasLive = !isEvolvePass && totalBars >= 40 && rng.nextDouble() < 0.45
        switch (hasVamp, hasLive) {
        case (true, true):   logVariant(AmbientPianoRule.Variant.kolnVampLive, of: .koln, in: &usedRuleIDs)
        case (true, false):  logVariant(AmbientPianoRule.Variant.kolnVamp, of: .koln, in: &usedRuleIDs)
        case (false, true):  logVariant(AmbientPianoRule.Variant.kolnLive, of: .koln, in: &usedRuleIDs)
        case (false, false): break
        }
        return hasLive ? kolnLiveTake(trimmed, frame: frame, arc: arc, totalBars: totalBars, rng: &rng) : trimmed
    }

    // MARK: AMB-PNO-003 vamp — Koln Part IIa

    /// The vamp's left hand: a low pedal (the root, struck every 2 bars and held a dotted half, an
    /// octave pair when there is room) under two chords that rock back and forth, the home chord and its neighbour (the
    /// flat 7th, else the 4th, else the 2nd). One pattern per song: straight half notes,
    /// syncopated (a pickup on the and of 2 and 4), or a bar of quarter-note pulses on each chord.
    /// Chord tones sit under the melody and never rub it (lhTones); a pedal that would rub moves
    /// to the 5th, or rests. Velocity rises through the section.
    static func kolnVamp(bars: Range<Int>, frame: GlobalMusicalFrame, lhBass: [UInt8], lhRoot: UInt8,
                                 melody: [MIDIEvent], totalSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let scalePCs = frame.scalePCs
        let rootPC   = Int(lhRoot) % 12
        guard let nPC = [10, 5, 2].map({ (rootPC + $0) % 12 }).first(where: { scalePCs.contains($0) }) else { return [] }
        let homeBass  = UInt8(48 + rootPC), nbrBass = UInt8(48 + nPC)
        let pattern   = rng.nextInt(upperBound: 3)
        // Hits per bar as (step, length); in the two-bar pattern, odd bars take the neighbour chord.
        let hits: [(Int, Int, Bool)] = {   // step, length, neighbour chord?
            switch pattern {
            case 0:  return [(0, 7, false), (8, 7, true)]
            case 1:  return [(0, 5, false), (6, 2, false), (8, 5, true), (14, 2, true)]
            default: return [(0, 3, false), (4, 3, false), (8, 3, false), (12, 3, false)]
            }
        }()
        func rubs(_ n: Int, _ s: Int, _ e: Int) -> Bool {
            melody.contains { $0.stepIndex < e && $0.stepIndex + $0.durationSteps > s
                              && pnoRubs(Int($0.note), n) }
        }
        var ev: [MIDIEvent] = []
        var pedal: UInt8? = nil
        let len = bars.count
        for (k, bar) in bars.enumerated() {
            let bs = bar * 16
            guard bs < totalSteps else { break }
            let lift = Double(k) / Double(Swift.max(1, len - 1))            // 0 to 1 across the vamp
            // Pedal, every 2 bars
            if k % 2 == 0 {
                let pd = Swift.min(32, bars.upperBound * 16 - bs, totalSteps - bs)
                let fifth = lhBass.first { Int($0) % 12 == (rootPC + 7) % 12 }
                pedal = [lhRoot, fifth].compactMap({ $0 }).first(where: { !rubs(Int($0), bs, bs + pd) })
                if let p = pedal {
                    let pv = 40 + Int(lift * 10)
                    // Held a dotted half, the low octave a half note and softer: a piano bass note
                    // doesn't ring for 2 bars, and a 2-bar hold sat heavy (Zack, 2026-11-24).
                    ev.append(MIDIEvent(stepIndex: bs, note: p, velocity: pnoVel(pv), durationSteps: Swift.min(12, pd)))
                    if p >= 40 { ev.append(MIDIEvent(stepIndex: bs, note: p - 12, velocity: pnoVel(pv - 12), durationSteps: Swift.min(8, pd))) }
                }
            }
            for (h, (s, d, nbrHit)) in hits.enumerated() {
                let useNbr = pattern == 2 ? k % 2 == 1 : nbrHit
                let st = bs + s
                guard st + d <= totalSteps else { continue }
                let tones = lhTones(bass: useNbr ? nbrBass : homeBass, scalePCs: scalePCs, low: 52, high: 67,
                                    target: 59, prefer: [1, 2, 0], count: 3, melody: melody, start: st, end: st + d)
                    .filter { t in pedal.map { !pnoRubs(Int(t), Int($0)) } ?? true }
                let accent = (pattern == 1 && (h == 1 || h == 3)) ? -6 : (s == 0 ? 4 : 0)
                let cv = 32 + Int(lift * 18) + accent + rng.nextInt(upperBound: 5)
                for (i, t) in tones.enumerated() {
                    ev.append(MIDIEvent(stepIndex: st, note: t, velocity: pnoVel(Swift.max(20, cv - i * 3)), durationSteps: d))
                }
            }
        }
        return ev
    }

    // MARK: AMB-PNO-003 live wire — Koln Live Take

    /// A live concert's liberties on a finished Koln line (Zack, 2026-11-24): blue-note grace notes
    /// and one or two slightly wrong-sounding held notes that resolve by step, fast flurries with a
    /// chromatic passing note, trills and turns on held top notes, enclosures, and an added note
    /// in the climax chord. Written after the line's own trim, so it checks its own clashes:
    /// nothing a half-step or major 7th from a sounding note within an octave, nothing chromatic
    /// on a beat, nothing that rubs the pads' drone (root, 5th) or pedal (2nd or 4th), and at most
    /// 8 chromatic notes a song. Graces are a 16th long; the pads trim leaves those alone for Koln.
    static func kolnLiveTake(_ input: [MIDIEvent], frame: GlobalMusicalFrame, arc: KolnArc,
                                     totalBars: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        var ev = input.sorted { $0.stepIndex < $1.stepIndex }
        let scale  = frame.scalePCs
        let root   = frame.keySemitoneValue % 12
        let chord  = pnoChordPCs(frame)
        let padPCs = [root, (root + 7) % 12, (root + 2) % 12, (root + 5) % 12]
        let floorN: UInt8 = 60                      // melody at or above C4; the left hand sits below
        let lastStep = (totalBars - 3) * 16         // the closing chord is left alone
        var chromaticLeft = 8
        var usedSteps: [Int] = []                   // keeps the liberties apart (2 bars)

        func isMelody(_ e: MIDIEvent) -> Bool { e.note >= floorN }
        func isTop(_ i: Int) -> Bool {
            !ev.contains { $0.stepIndex == ev[i].stepIndex && $0.note > ev[i].note }
        }
        func farFromUsed(_ step: Int) -> Bool { usedSteps.allSatisfy { abs($0 - step) >= 32 } }
        /// A glaring rub for `n` over steps step..<step+len, against every note sounding then
        /// except those `skip` says will be cut or replaced.
        func rubs(_ n: UInt8, at step: Int, len: Int, skip: (Int) -> Bool = { _ in false }) -> Bool {
            for i in ev.indices where !skip(i) {
                let e = ev[i]
                guard e.stepIndex < step + len, e.stepIndex + e.durationSteps > step else { continue }
                let d = abs(Int(e.note) - Int(n))
                if d == 1 || d == 11 { return true }
            }
            return false
        }
        func padSafe(_ pc: Int) -> Bool {
            padPCs.allSatisfy { let d = (pc - $0 + 12) % 12; return d != 1 && d != 6 && d != 11 }
        }
        func isRinging(_ e: MIDIEvent, _ a: Int) -> Bool {
            e.note >= floorN && e.stepIndex < a && e.stepIndex + e.durationSteps > a
        }
        func clip(at a: Int) {
            for i in ev.indices where isRinging(ev[i], a) {
                ev[i] = ev[i].with(durationSteps: Swift.max(1, a - ev[i].stepIndex))
            }
        }
        func onsetsFree(_ a: Int, _ b: Int) -> Bool {
            !ev.contains { isMelody($0) && $0.stepIndex >= a && $0.stepIndex < b }
        }
        func scaleNeighbour(_ n: UInt8, up: Bool) -> UInt8? {
            for d in 1...2 {
                let c = Int(n) + (up ? d : -d)
                if scale.contains(((c % 12) + 12) % 12) { return UInt8(c) }
            }
            return nil
        }
        func soft(_ v: UInt8, _ by: Int) -> UInt8 { UInt8(Swift.max(18, Int(v) - by)) }

        // 1a. Blue-note graces (2-4): a 16th crushed into a chord tone from the half-step below
        // when that note is outside the scale (the flat 3rd into the 3rd, the flat 5th into the 5th,
        // the leading tone into a minor root). Never on a beat.
        let graceTargets = ev.indices.filter { i in
            let e = ev[i], pc = Int(e.note) % 12
            return isMelody(e) && e.stepIndex > 32 && e.stepIndex < lastStep && e.durationSteps >= 2
                && chord.contains(pc) && !scale.contains((pc + 11) % 12)
                && (e.stepIndex - 1) % 4 != 0 && isTop(i)
        }.seededShuffle(&rng)
        var graces = 2 + rng.nextInt(upperBound: 3)
        var newNotes: [MIDIEvent] = []
        for i in graceTargets where graces > 0 && chromaticLeft > 0 {
            let t = ev[i], s = t.stepIndex
            let g = t.note - 1
            guard farFromUsed(s), onsetsFree(s - 1, s),
                  !rubs(g, at: s - 1, len: 1, skip: { isRinging(ev[$0], s - 1) }) else { continue }
            clip(at: s - 1)
            newNotes.append(MIDIEvent(stepIndex: s - 1, note: g, velocity: soft(t.velocity, 14), durationSteps: 1))
            usedSteps.append(s); graces -= 1; chromaticLeft -= 1
        }
        ev += newNotes; newNotes = []

        // 1b. Tension notes (1-2): a passing melody note, off the beat, nudged a half-step outside
        // the scale and held, then resolved by step into the next note. Slightly wrong on purpose.
        var tensions = 1 + (rng.nextDouble() < 0.50 ? 1 : 0)
        let melodyTops = ev.indices.filter { isMelody(ev[$0]) && isTop($0) }.sorted { ev[$0].stepIndex < ev[$1].stepIndex }
        for k in Array(1..<Swift.max(1, melodyTops.count - 1)).seededShuffle(&rng) where tensions > 0 && chromaticLeft > 0 {
            let i = melodyTops[k], e = ev[i], next = ev[melodyTops[k + 1]]
            guard e.stepIndex % 4 != 0, (2...6).contains(e.durationSteps), e.stepIndex < lastStep,
                  farFromUsed(e.stepIndex), next.stepIndex - (e.stepIndex + e.durationSteps) <= 4 else { continue }
            for alt in [Int(e.note) + 1, Int(e.note) - 1].seededShuffle(&rng) {
                let pc = alt % 12
                guard !scale.contains(pc), padSafe(pc), [1, 2].contains(abs(Int(next.note) - alt)),
                      !rubs(UInt8(alt), at: e.stepIndex, len: e.durationSteps, skip: { $0 == i }) else { continue }
                ev[i] = MIDIEvent(stepIndex: e.stepIndex, note: UInt8(alt),
                                  velocity: pnoVel(Swift.min(85, Int(e.velocity) + 4)), durationSteps: e.durationSteps)
                usedSteps.append(e.stepIndex); tensions -= 1; chromaticLeft -= 1
                break
            }
        }

        // 2. Flurries (1-2): 6-10 notes at 16th speed, mostly falling, with one chromatic passing
        // note between a whole step (off the beat), landing on a held chord tone. After the climax
        // or a minor peak first, else in the second half of the build.
        let runPool = notesInRegister(pitchClasses: scale, low: 62, high: 86)
        var zones: [ClosedRange<Int>] = []
        if arc.withdrawBar - 1 > arc.climaxBar + 3 { zones.append((arc.climaxBar + 3)...(arc.withdrawBar - 1)) }
        for pb in arc.peakBars { zones.append((pb + 3)...(pb + 7)) }
        let buildLo = totalBars * 30 / 100, buildHi = arc.climaxBar - 6
        if buildHi > buildLo { zones.append(buildLo...buildHi) }
        var flurries = 1 + (rng.nextDouble() < 0.40 ? 1 : 0)
        for zone in zones where flurries > 0 && runPool.count >= 8 {
            let runLen = 6 + rng.nextInt(upperBound: 5)
            let falling = rng.nextDouble() < 0.75
            let need = runLen + 1 + 8
            let starts = stride(from: zone.lowerBound * 16 + 2, through: zone.upperBound * 16, by: 4)
                .filter { $0 + need < lastStep && farFromUsed($0) && onsetsFree($0, $0 + need) }
            guard !starts.isEmpty else { continue }
            let start = starts[rng.nextInt(upperBound: starts.count)]
            var idx = falling ? runPool.count - 1 - rng.nextInt(upperBound: Swift.max(1, runPool.count / 3))
                              : rng.nextInt(upperBound: Swift.max(1, runPool.count / 3))
            var line: [UInt8] = []
            for _ in 0..<runLen {
                guard idx >= 0 && idx < runPool.count else { break }
                line.append(runPool[idx]); idx += falling ? -1 : 1
            }
            guard line.count >= 5 else { continue }
            // Land on the nearest chord tone past the last note, in the run's direction
            let last = Int(line.last!)
            let landing = (1...4).map { falling ? last - $0 : last + $0 }
                .first { scale.contains(($0 % 12 + 12) % 12) && chord.contains(($0 % 12 + 12) % 12) }
            if let l = landing { line.append(UInt8(l)) }
            // One chromatic passing note between two notes a whole step apart, on an odd 16th
            var chromAt: Int? = nil
            if chromaticLeft > 0 {
                for k in 1..<(line.count - 1) where abs(Int(line[k]) - Int(line[k - 1])) == 2 && (start + k) % 2 == 1 {
                    chromAt = k; break
                }
            }
            var run: [MIDIEvent] = []
            var step = start
            for k in 0..<line.count {
                if k == chromAt {
                    let c = UInt8((Int(line[k - 1]) + Int(line[k])) / 2)
                    if !rubs(c, at: step, len: 1, skip: { isRinging(ev[$0], start) }) && !scale.contains(Int(c) % 12) {
                        run.append(MIDIEvent(stepIndex: step, note: c, velocity: pnoVel(50 - k), durationSteps: 1))
                        step += 1; chromaticLeft -= 1
                    }
                }
                let isLast = k == line.count - 1
                let v = isLast ? 46 : (falling ? 56 - k * 2 : 42 + k * 2)
                run.append(MIDIEvent(stepIndex: step, note: line[k], velocity: pnoVel(Swift.max(24, v)),
                                     durationSteps: isLast ? 4 + rng.nextInt(upperBound: 3) : 1))
                step += 1
            }
            clip(at: start)
            ev += run
            usedSteps.append(start); flurries -= 1
        }

        // 3. Ornaments (1-2): a trill (note, upper, note, upper) or a turn (upper, note, lower,
        // note) at the start of a held top note, which then sounds on.
        var ornaments = 1 + (rng.nextDouble() < 0.50 ? 1 : 0)
        let held = ev.indices.filter { isMelody(ev[$0]) && ev[$0].durationSteps >= 8 && ev[$0].note >= 64
                                       && ev[$0].stepIndex > 32 && ev[$0].stepIndex < lastStep && isTop($0) }
            .seededShuffle(&rng)
        for i in held where ornaments > 0 {
            let e = ev[i], s = e.stepIndex
            guard farFromUsed(s), let up = scaleNeighbour(e.note, up: true),
                  let low = scaleNeighbour(e.note, up: false),
                  ev.allSatisfy({ !isMelody($0) || $0.stepIndex <= s || $0.stepIndex >= s + 4 }) else { continue }
            let trill = rng.nextDouble() < 0.50
            let figure: [UInt8] = trill ? [e.note, up, e.note, up] : [up, e.note, low, e.note]
            guard !figure.contains(where: { $0 != e.note && rubs($0, at: s, len: 4, skip: { $0 == i }) }) else { continue }
            ev[i] = MIDIEvent(stepIndex: s + 4, note: e.note, velocity: soft(e.velocity, 6), durationSteps: e.durationSteps - 4)
            for (k, n) in figure.enumerated() {
                ev.append(MIDIEvent(stepIndex: s + k, note: n, velocity: soft(e.velocity, k == 0 ? 0 : 8), durationSteps: 1))
            }
            usedSteps.append(s); ornaments -= 1
        }

        // 4. Enclosures (1-2): a chord tone approached from the scale note above, then the
        // half-step below (outside the scale), two 16ths, the chromatic one off the beat.
        var enclosures = 1 + (rng.nextDouble() < 0.50 ? 1 : 0)
        let encTargets = ev.indices.filter { i in
            let e = ev[i], pc = Int(e.note) % 12
            return isMelody(e) && e.stepIndex > 32 && e.stepIndex < lastStep && chord.contains(pc)
                && !scale.contains((pc + 11) % 12) && (e.stepIndex - 1) % 4 != 0 && isTop(i)
        }.seededShuffle(&rng)
        for i in encTargets where enclosures > 0 && chromaticLeft > 0 {
            let t = ev[i], s = t.stepIndex
            guard farFromUsed(s), onsetsFree(s - 2, s), let up = scaleNeighbour(t.note, up: true) else { continue }
            let below = t.note - 1
            guard !rubs(up, at: s - 2, len: 1, skip: { isRinging(ev[$0], s - 2) }),
                  !rubs(below, at: s - 1, len: 1, skip: { isRinging(ev[$0], s - 2) }) else { continue }
            clip(at: s - 2)
            ev.append(MIDIEvent(stepIndex: s - 2, note: up, velocity: soft(t.velocity, 10), durationSteps: 1))
            ev.append(MIDIEvent(stepIndex: s - 1, note: below, velocity: soft(t.velocity, 12), durationSteps: 1))
            usedSteps.append(s); enclosures -= 1; chromaticLeft -= 1
        }

        // 5. Climax cluster (75%): the block chord takes one more scale note inside it, a whole
        // step from its neighbours, so it lands like a fist on the keys without a half-step rub.
        if rng.nextDouble() < 0.75 {
            let cs = arc.climaxBar * 16 + 4
            for hit in Set(ev.filter { $0.stepIndex >= cs && $0.stepIndex <= cs + 10 && $0.note >= 69 }.map { $0.stepIndex }).sorted() {
                let notes = ev.filter { $0.stepIndex == hit && $0.note >= 69 }
                guard notes.count >= 3, let lowN = notes.min(by: { $0.note < $1.note }) else { continue }
                let add = [2, 5, 9].map { Int(lowN.note) + $0 }.first { c in
                    scale.contains(c % 12) && !notes.contains { $0.note == UInt8(c) }
                        && !rubs(UInt8(c), at: hit, len: lowN.durationSteps)
                }
                if let c = add {
                    ev.append(MIDIEvent(stepIndex: hit, note: UInt8(c), velocity: soft(lowN.velocity, 10),
                                        durationSteps: lowN.durationSteps))
                }
            }
        }

        return ev.filter { $0.durationSteps >= 1 }.sorted { $0.stepIndex < $1.stepIndex }
    }
}
