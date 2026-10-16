// ChillSohoTextureGenerator.swift — Chill Soho MIDI texture
// Copyright (c) 2026 Zack Urlocker
//
// Chill Soho's Texture track is ALWAYS MIDI and never the audio ambience base Chill uses.
// Exactly one rule plays per song, and the track is never absent:
//
//   CHL-TEXT-001 Sustained Halo     — a handful of long, high notes across the whole song
//   CHL-TEXT-002 Punctuation Stabs  — short chord stabs on the section boundaries
//
// Whichever rule is running, the horns also answer the harmonic-drone and groove-pocket
// breakdowns: neither has a voice of its own, and the silence there made both sound like base
// Chill's. See breakdownAnswer.
//
// Both were measured from the parts in the corpus that fire rarely and are remembered anyway:
// 28 pitched channels under 1.3 notes/bar, median 0.46 notes/bar. Split by duration they form
// these two roles. See "Texture" in docs/chill-soho-plan.md.
//
// Instruments are drawn independently of the rule, so both rules must suit every patch in the
// pool (trumpet, trombone, muted trumpet, vibraphone) — fast attack, sustaining or ringing body.
// The vibraphone rings rather than sustains, so a Sustained Halo note decays inside its written
// length on it; only the brass holds it, and brass is 70% of picks.

import Foundation

struct ChillSohoTextureGenerator {

    static func generate(frame: GlobalMusicalFrame,
                         structure: SongStructure,
                         drumEvents: [MIDIEvent],
                         breakdownStyle: ChillBreakdownStyle = .bassOstinato,
                         rng: inout SeededRNG,
                         usedRuleIDs: inout Set<String>) -> [MIDIEvent] {
        let useStabs = rng.nextDouble() < 0.55
        usedRuleIDs.insert(useStabs ? "CHL-TEXT-002" : "CHL-TEXT-001")
        let crashes = CrashPoints(drumEvents)
        let voicing = StabVoicing(rng: &rng)
        var events = useStabs
            ? punctuationStabs(frame: frame, structure: structure, crashes: crashes,
                               voicing: voicing, rng: &rng)
            : sustainedHalo(frame: frame, structure: structure, crashes: crashes,
                            breakdownStyle: breakdownStyle, rng: &rng)
        // The horns answer a harmonic drone whichever rule is running. Without them the drone is
        // the one Soho break with no voice at all — bass and pads hold, drums tick, and the rhythm
        // part and both leads are out — which is why it sounded like base Chill (Zack, 2026-10-11).
        if [.harmonicDrone, .groovePocket, .sohoDuo].contains(breakdownStyle) {
            events += breakdownAnswer(structure: structure, style: breakdownStyle,
                                      taken: Set(events.map(\.stepIndex)), rng: &rng)
        }
        // Rather over half of songs mark their turnarounds with a horn, announcing the chord
        // detour the way a section would announce itself. Not all of them: at every turnaround of
        // every song it stops being a gesture (Zack, 2026-10-12).
        if rng.nextDouble() < 0.55 {
            events += turnaroundStabs(frame: frame, structure: structure,
                                      taken: Set(events.map(\.stepIndex)), voicing: voicing, rng: &rng)
        }
        // Three separate figures write to this track — the stabs, the turnaround marker and the
        // breakdown answer — so a pitch can be struck twice at one step. Keep the longer.
        var longest: [Int: MIDIEvent] = [:]
        for ev in events {
            let key = ev.stepIndex << 8 | Int(ev.note)
            if let had = longest[key], had.durationSteps >= ev.durationSteps { continue }
            longest[key] = ev
        }
        return longest.values.sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }
    }

    // MARK: - Horns on a turnaround

    /// A short two-note stab on the downbeat of each turnaround — the moment the chords leave the
    /// cycle. Voiced in the stab register and soft enough to mark the change rather than take it
    /// over; the bass is already leading back to the top underneath.
    private static func turnaroundStabs(frame: GlobalMusicalFrame, structure: SongStructure,
                                        taken: Set<Int>, voicing: StabVoicing,
                                        rng: inout SeededRNG) -> [MIDIEvent] {
        let turns = ChillStructureGenerator.sohoTurnaroundBars(frame: frame, structure: structure)
        var events: [MIDIEvent] = []
        for bar in turns.sorted() where !turns.contains(bar - 1) {
            // Never struck on a step the stabs or the halo already sound on: two figures at one
            // instant with different lengths is the staggered chord this track avoids.
            guard !taken.contains(bar * 16) else { continue }
            guard let c = structure.chordWindow(atBar: bar) else { continue }
            let pool = notes(c.chordTones, 58, 71)
            guard pool.count >= 2 else { continue }
            // A single hit here, deliberately: the bass is already walking back to the top and the
            // drums take a fill, so the turnaround does not need a horn figure as well
            // (Zack, 2026-10-12).
            // Length drawn once for the whole hit. Drawing it per note gave the two pitches
            // different lengths, which is the staggered chord that reads as mush rather than as
            // one "bap" (Zack, 2026-10-12).
            // Two notes or three, evenly: three reads as the section rather than a pair of
            // players (Zack, 2026-10-15).
            let count = rng.nextDouble() < 0.5 ? 3 : 2
            let voiced = voicing.voice(pool, tensions: notes(c.scaleTensions, 58, 71),
                                       count: count, rng: &rng)
            let vel = rng.velocity(60, 12)
            let length = 2 + rng.nextInt(upperBound: 3)
            for n in voiced {
                events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(n), velocity: vel,
                                        durationSteps: length))
            }
        }
        return events
    }

    // MARK: - Horns through a breakdown

    /// The horns answer the three breakdowns that otherwise have no voice of their own.
    ///
    /// - **Harmonic drone**: a soft pair of notes on the downbeat of every other bar, voiced low
    ///   so they sit under the pads rather than announcing themselves — the section is still
    ///   about space — then a single short note on the last bar's fourth beat, into the return
    /// - **Groove pocket**: nothing until the last three bars, then a rising figure — one hit,
    ///   two, then three — doubling the escalation the rhythm part already plays there, so the
    ///   section winds up into the groove instead of merely stopping
    ///
    /// - **Duo**: a soft held two-note chord every four bars from the third, and a stab with the
    ///   snare pickup on the last bar's fourth beat
    ///
    /// Designed rather than measured: no reference song has a section of either kind to measure.
    private static func breakdownAnswer(structure: SongStructure, style: ChillBreakdownStyle,
                                        taken: Set<Int>, rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        func hits(_ bar: Int, _ steps: [Int], _ lo: Int, _ hi: Int, _ vel: UInt8, _ dur: Int) {
            guard let c = structure.chordWindow(atBar: bar) else { return }
            let pool = notes(c.chordTones, lo, hi)
            guard pool.count >= 2 else { return }
            // Never on a step the stabs or the halo already sound on — two figures at one instant
            // with different lengths is the staggered chord this track avoids.
            // The lowest tone and the middle one, but never a semitone apart (the 7th and root
            // of a maj7 can sit side by side): the upper note is at least a minor third up.
            let upper = pool.first { $0 - pool[0] >= 3 && $0 >= pool[pool.count / 2] }
                ?? pool.first { $0 - pool[0] >= 3 }
            guard let upper else { return }
            for step in steps where !taken.contains(bar * 16 + step) {
                for n in [pool[0], upper] {
                    events.append(MIDIEvent(stepIndex: bar * 16 + step, note: UInt8(n),
                                            velocity: vel, durationSteps: dur))
                }
            }
        }

        for section in structure.sections where section.label == .bridge {
            let last = section.endBar - 1
            guard last >= section.startBar else { continue }
            if style == .sohoDuo {
                // The Duo: Rhythm and Bass alone was too bare (Zack, 2026-10-15), so the horns
                // reply sparingly — a soft two-note held chord on the duo's third bar and every
                // four bars after, letting the two players establish first, then a short stab on
                // beat 4 of the last bar with the snare pickup into the return.
                for bar in stride(from: section.startBar + 2, to: last, by: 4) {
                    hits(bar, [0], 58, 71, rng.velocity(48, 8), 10 + rng.nextInt(upperBound: 5))
                }
                hits(last, [12], 58, 71, rng.velocity(62, 8), 2)
                continue
            }
            if style == .groovePocket {
                // The last three bars only, rising: 1 hit, 2, then 3.
                let figure: [[Int]] = [[8], [8, 12], [4, 8, 12]]
                for (i, steps) in figure.enumerated() {
                    let bar = last - (figure.count - 1 - i)
                    guard bar >= section.startBar else { continue }
                    hits(bar, steps, 58, 71, rng.velocity(64 + i * 6, 10), 2)
                }
                continue
            }
            for bar in stride(from: section.startBar, to: section.endBar, by: 2) {
                hits(bar, [0], 56, 68, rng.velocity(46, 10), 4 + rng.nextInt(upperBound: 5))
            }
            // The way out: a single short note on beat 4 of the last bar, into the return.
            if let c = structure.chordWindow(atBar: last), let n = notes(c.chordTones, 58, 71).last {
                events.append(MIDIEvent(stepIndex: last * 16 + 12, note: UInt8(n),
                                        velocity: rng.velocity(60, 10), durationSteps: 2))
            }
        }
        return events
    }

    // MARK: - Stab voicings

    /// How a horn stab is voiced. Every stab used to take the lowest, middle and highest chord
    /// tone in 58–71, so a chord was always voiced the same way and the section had one sound.
    /// A song now has a home voicing and moves off it on about one stab in four, which is what an
    /// arranger does: a consistent section sound with the occasional different colour.
    ///
    /// - `spread` — lowest, middle and highest tone: open, the original voicing
    /// - `close`  — neighbouring chord tones at the top of the register: the tight section sound
    /// - `colour` — the spread voicing with a 9th or 6th in place of one tone, the extension that
    ///   makes this harmony sound like this music; refused if it would sit a semitone from
    ///   another note, which on one horn reads as a wrong note rather than a colour
    struct StabVoicing {
        enum Kind { case spread, close, colour }
        let home: Kind

        init(rng: inout SeededRNG) {
            home = [Kind.spread, .close, .colour][rng.weightedPick([0.40, 0.35, 0.25])]
        }

        /// `count` notes from `pool` (chord tones, ascending), with `tensions` for the colour.
        func voice(_ pool: [Int], tensions: [Int], count: Int, rng: inout SeededRNG) -> [Int] {
            playable(rawVoice(pool, tensions: tensions, count: count, rng: &rng))
        }

        /// No two notes a semitone apart. Adjacent chord tones can be — the 7th and the root of a
        /// maj7 — and on one horn that reads as a wrong note. The lower of a clashing pair goes.
        private func playable(_ v: [Int]) -> [Int] {
            var out: [Int] = []
            for n in v.sorted().reversed() where out.last.map({ $0 - n >= 2 }) ?? true { out.append(n) }
            return out.reversed()
        }

        private func rawVoice(_ pool: [Int], tensions: [Int], count: Int, rng: inout SeededRNG) -> [Int] {
            let others = [Kind.spread, .close, .colour].filter { $0 != home }
            let kind = rng.nextDouble() < 0.75 ? home : others[rng.nextInt(upperBound: others.count)]
            let spread: [Int]
            switch count {
            case ...1: spread = [pool[pool.count / 2]]
            case 2:    spread = [pool[pool.count / 2], pool[pool.count - 1]]
            default:   spread = [pool[0], pool[pool.count / 2], pool[pool.count - 1]]
            }
            switch kind {
            case .spread:
                break
            case .close:
                // The top `count` tones, or the cluster one tone lower, so the lead note varies.
                let n = Swift.min(count, pool.count)
                let top = pool.count - n
                let start = top > 0 && rng.nextDouble() < 0.4 ? top - 1 : top
                return Array(pool[start..<(start + n)])
            case .colour:
                // Replace an inner note (the lower of two) with the nearest tension.
                guard count >= 2, !tensions.isEmpty else { break }
                let at = count == 2 ? 0 : 1
                let target = spread[at]
                guard let t = tensions.min(by: { abs($0 - target) < abs($1 - target) }) else { break }
                var v = spread
                v[at] = t
                v = Array(Set(v)).sorted()
                let clash = zip(v, v.dropFirst()).contains { $1 - $0 < 2 }
                if v.count == count && !clash { return v }
            }
            return Array(Set(spread)).sorted()
        }
    }

    // MARK: - Shared

    /// Bars whose downbeat carries a crash in the drum track: the return from a section-end
    /// fill, the return from a breakdown, and the cold-stop final hit.
    ///
    /// Read from the generated drums rather than recomputed, so the stabs land with the kit by
    /// construction — two independent random streams never have to agree. The plan proposed a
    /// shared `sohoAccentSteps(forBar:)` helper for this; reading the drum track is stricter,
    /// because the two can never drift apart.
    /// Where the kit crashes, read once from the finished drum track.
    ///
    /// `steps` is every step carrying a crash — including the Remix Break exit, whose unison
    /// stabs fall on steps 0 AND 8 of its last bar — and `bars` is the bars whose downbeat
    /// carries one. Both exclude step 0 of the song.
    ///
    /// Built in a single pass and handed to the rules, which previously each re-scanned the
    /// whole drum track: up to three scans of a median 1,601 drum events per song (2026-10-14).
    struct CrashPoints {
        let steps: [Int]
        let bars:  [Int]

        init(_ drumEvents: [MIDIEvent]) {
            let crash = Int(GMDrum.crash1.rawValue)
            var stepSet = Set<Int>(), barSet = Set<Int>()
            for e in drumEvents where Int(e.note) == crash && e.stepIndex > 0 {
                stepSet.insert(e.stepIndex)
                if e.stepIndex % 16 == 0 { barSet.insert(e.stepIndex / 16) }
            }
            // Sorted, so Set iteration order never reaches a musical decision — see the header
            // of DeterminismTests.
            steps = stepSet.sorted()
            bars  = barSet.sorted()
        }
    }

    /// Absolute MIDI notes in [lo, hi] whose pitch class is in `pcs`, in ascending order.
    /// Ranges are ordered, so Set iteration order never reaches a musical decision — see the
    /// header of DeterminismTests.
    private static func notes(_ pcs: Set<Int>, _ lo: Int, _ hi: Int) -> [Int] {
        (lo...hi).filter { pcs.contains(($0 % 12 + 12) % 12) }
    }

    // MARK: - CHL-TEXT-002 Punctuation Stabs

    /// Short mid-register chord stabs at structural moments only — never on a per-bar roll,
    /// which scatters them and reads as mistakes. Measured from Holding Back the Years' brass
    /// (0.51/bar, 1.1-step notes) and Avalon's synth lead and guitar.
    ///
    /// - Every drum crash downbeat gets a stab, doubling the kit (horns with the band hit)
    /// - Inside A and B sections, the last bar of every 8–16 bar phrase gets a pickup stab on
    ///   beat 4, leading into the next phrase
    ///
    /// A real section does not punch the same block chord every time. Each stab is 1, 2 or 3
    /// notes, and when it has more than one they are given their own lengths — short then long,
    /// long then short, or all equal — so the figure has a shape instead of being a single block.
    private static func punctuationStabs(frame: GlobalMusicalFrame, structure: SongStructure,
                                         crashes: CrashPoints, voicing: StabVoicing,
                                         rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        // Any bar carrying a crash, not only one on the downbeat: a crash on beat 4 draws an
        // accent to step 12, which is exactly where a phrase-end pickup goes, and the two
        // doubled up on the same step.
        let crashBarSet = Set(crashes.steps.map { $0 / 16 }).union(crashes.bars)
        let phrase = 8 + 2 * rng.nextInt(upperBound: 5)          // 8, 10, 12, 14 or 16 bars

        /// One horn figure. `weights` picks how many notes are in the chord — the accents want a
        /// fuller one than the pickups — and `maxHits` how many times it is struck.
        ///
        /// A single hit every time reads as the same punctuation over and over, however many
        /// notes are in the chord: two or three notes sounding together is still one "bap"
        /// (Zack, 2026-10-12). A real section plays figures, so most stabs are now two or three
        /// hits of the same chord with their own rhythm — short-short, short-long, short-short-long.
        func stab(_ bar: Int, step: Int, weights: [Double], vel: UInt8, maxHits: Int, room: Int) {
            guard let c = structure.chordWindow(atBar: bar) else { return }
            let pool = notes(c.chordTones, 58, 71)
            guard !pool.isEmpty else { return }
            let count = Swift.min(1 + rng.weightedPick(weights), pool.count)
            let voiced = voicing.voice(pool, tensions: notes(c.scaleTensions, 58, 71),
                                       count: count, rng: &rng)
            for (offset, length, accent) in stabFigure(maxHits: maxHits, room: room, rng: &rng) {
                let v = UInt8(Swift.max(40, Swift.min(110, Int(vel) + accent)))
                for n in voiced {
                    events.append(MIDIEvent(stepIndex: bar * 16 + step + offset, note: UInt8(n),
                                            velocity: v, durationSteps: length))
                }
            }
        }

        // Accents: 3 notes 60% of the time, 2 a third, 1 rarely, and up to three hits. One horn
        // playing a two- or three-note chord reads as a section, which is the sound this track is
        // for, so single notes came down from 16% and 40% (Zack, 2026-10-15).
        //
        // A figure has to finish before the next accent in the same bar. The Remix Break's exit
        // crashes on steps 0 AND 8, and a bar can crash on 8 and 12, so a figure left to run the
        // rest of the bar would strike the same instant as the next one with a different length.
        let accents = crashes.steps
        for (i, at) in accents.enumerated() where at / 16 < frame.totalBars {
            let nextInBar = i + 1 < accents.count && accents[i + 1] / 16 == at / 16
                ? accents[i + 1] % 16 : 16
            stab(at / 16, step: at % 16, weights: [0.06, 0.34, 0.60],
                 vel: rng.velocity(78, 12), maxHits: 3, room: nextInBar - at % 16)
        }

        // Pickups are lighter: mostly 2 notes.
        for section in structure.sections where section.label == .A || section.label == .B {
            var bar = section.startBar + phrase - 1
            while bar < section.endBar - 1 {
                // Leave the section's own last bar to the drum fill and the crash that follows.
                if !crashBarSet.contains(bar) && !crashBarSet.contains(bar + 1) {
                    // A pickup sits on beat 4 with only a beat of room, so at most two hits.
                    stab(bar, step: 12, weights: [0.20, 0.50, 0.30],
                         vel: rng.velocity(64, 12), maxHits: 2, room: 4)
                }
                bar += phrase
            }
        }
        return events.sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }
    }

    /// Horn figures, as (offset, length, velocity accent) in sixteenths from the first hit.
    /// Filtered to those that finish inside the bar, then weighted so single hits are the
    /// minority — a song of them has no punctuation, only repetition.
    private static func stabFigure(maxHits: Int, room: Int,
                                   rng: inout SeededRNG) -> [(Int, Int, Int)] {
        let one: [[(Int, Int, Int)]] = [
            [(0, 2, 0)],                                        // bap
        ]
        let two: [[(Int, Int, Int)]] = [
            [(0, 1, 0), (2, 2, -4)],                            // bap-bap
            [(0, 1, -4), (2, 6, 4)],                            // bap-baaa
            [(0, 3, 2), (4, 2, -4)],                            // baaa-bap
            [(0, 1, -2), (3, 4, 3)],                            // bap--baaa
        ]
        let three: [[(Int, Int, Int)]] = [
            [(0, 1, -4), (2, 1, -2), (4, 6, 5)],                // bap-bap-baaa
            [(0, 1, 0), (2, 4, 3), (7, 2, -4)],                 // bap-baaa-bap
            [(0, 2, 2), (4, 1, -4), (6, 4, 3)],                 // baa-bap-baaa
        ]
        func fits(_ f: [(Int, Int, Int)]) -> Bool {
            guard let last = f.last else { return false }
            return last.0 + last.1 <= Swift.max(1, room)
        }
        let pools = [one.filter(fits), maxHits >= 2 ? two.filter(fits) : [],
                     maxHits >= 3 ? three.filter(fits) : []]
        // 35% one hit, 40% two, 25% three. Pushing singles below this was an over-correction —
        // about half of all figures being a single hit reads correctly (Zack, 2026-10-12).
        // A pool with nothing that fits the bar is dropped and
        // the weights renormalised — `weightedPick` requires them to sum to 1 and otherwise falls
        // through to the last index, which would be the empty pool.
        let candidates = zip(pools, [0.35, 0.40, 0.25]).filter { !$0.0.isEmpty }
        guard !candidates.isEmpty else { return [(0, 1, 0)] }
        let total = candidates.reduce(0.0) { $0 + $1.1 }
        let pool = candidates[rng.weightedPick(candidates.map { $0.1 / total })].0
        return pool[rng.nextInt(upperBound: pool.count)]
    }

    // MARK: - CHL-TEXT-001 Sustained Halo

    /// A few long, high notes across the whole song — 3–10 events, 8–16 steps each, above the
    /// pads, half of them with a second chord tone a third to a sixth below. Measured from Smooth Operator's synth pad (five notes in 149 bars, MIDI
    /// 88), its guitar (13-step notes) and Holding Back the Years' strings. A far sparser
    /// density than anything else in Chill; that is the point of it.
    ///
    /// Placed where an arrangement would reach for colour: the start of each groove section,
    /// the breakdown, and the returns marked by the drum crashes.
    private static func sustainedHalo(frame: GlobalMusicalFrame, structure: SongStructure,
                                      crashes: CrashPoints, breakdownStyle: ChillBreakdownStyle,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var candidates = Set<Int>(crashes.bars)
        for section in structure.sections {
            switch section.label {
            case .A, .B:
                candidates.insert(section.startBar)
                // Long sections get a halo every 16 bars as well, so a 52-bar B is not bare.
                var b = section.startBar + 16
                while b < section.endBar - 2 { candidates.insert(b); b += 16 }
            case .bridge:
                candidates.insert(section.startBar)
            default:
                break
            }
        }
        let ordered = candidates.filter { $0 > 0 && $0 < frame.totalBars - 1 }.sorted()
        guard !ordered.isEmpty else { return [] }

        // 3–10 events, spread evenly across the candidates rather than clustered.
        let want = Swift.min(ordered.count, 3 + rng.nextInt(upperBound: 8))
        var chosen: [Int] = []
        for i in 0..<want {
            chosen.append(ordered[i * ordered.count / want])
        }

        var events: [MIDIEvent] = []
        for bar in chosen {
            guard let c = structure.chordWindow(atBar: bar) else { continue }
            // Prefer a colour tone (a scale tension such as the 9th) over a bare chord tone; it
            // is what makes a single held note read as harmony rather than as a stray pitch.
            let colour = notes(c.scaleTensions, 72, 84)
            let tones  = notes(c.chordTones, 72, 84)
            let pool   = (!colour.isEmpty && rng.nextDouble() < 0.6) ? colour : tones
            guard !pool.isEmpty else { continue }
            let note = pool[rng.nextInt(upperBound: pool.count)]
            let dur  = 8 + rng.nextInt(upperBound: 9)            // 8–16 steps
            let vel  = rng.velocity(50, 14)
            events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(note),
                                    velocity: vel, durationSteps: dur))
            // Half the halos are a two-note chord: the held tone over a chord tone a third to a
            // sixth below, which on one horn reads as a section swelling rather than a soloist.
            // The rest stay single so the rule keeps its sparseness (Zack, 2026-10-15). Same
            // length as the top note — two lengths at one instant is the staggered chord this
            // track avoids — and a little softer, so the top note still leads.
            if rng.nextDouble() < 0.5 {
                let under = notes(c.chordTones, note - 9, note - 3).filter { $0 != note }
                if !under.isEmpty {
                    let low = under[rng.nextInt(upperBound: under.count)]
                    events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(low),
                                            velocity: UInt8(Swift.max(30, Int(vel) - 6)),
                                            durationSteps: dur))
                }
            }
        }
        return events
    }
}
