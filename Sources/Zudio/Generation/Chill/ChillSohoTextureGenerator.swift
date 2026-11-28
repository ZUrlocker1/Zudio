// ChillSohoTextureGenerator.swift — Chill Soho MIDI texture
// Copyright (c) 2026 Zack Urlocker
//
// Chill Soho's Texture track is ALWAYS MIDI and never the audio ambience base Chill uses.
// Exactly one rule plays per song (25% each), and the track is never absent:
//
//   CHL-TEXT-001 Freddie Hubbard Riff     — a 2-bar trumpet call after Us3's Cantaloop, 2-4 a song
//   CHL-TEXT-002 Punctuation Stabs        — short chord stabs on the crashes and phrase ends
//   CHL-TEXT-003 Jimmy Cliff Riff         — a 3-bar call and response of repeated notes, after
//                                           You Can Get It If You Really Want
//   CHL-TEXT-004 Cantaloop Parallel Riff  — the three-horn 3+3+2+2 hook, then high pings
//
// No riff statement is an exact copy of its source or of the one before it: each takes one or
// two transformations (see RiffTransform). The three riffs are occasional ornaments, not a part: a statement of two to six bars, then
// rest. Every riff note is a chord tone, every statement has a second horn (the Parallel Riff a
// third in its hook bar), and no horn plays below F3 or a riff above A5.
// The old Sustained Halo (CHL-TEXT-001, a synth pad rather than a horn) was retired 2026-11-27.
//
// Whichever rule is running, the horns also answer the harmonic-drone, groove-pocket and Duo
// breakdowns: none has a voice of its own, and the silence there made them sound like base
// Chill's. See breakdownAnswer.
//
// Both were measured from the parts in the corpus that fire rarely and are remembered anyway:
// 28 pitched channels under 1.3 notes/bar, median 0.46 notes/bar; the stabs come from that
// measurement and the riffs from the horn parts of two songs. See "Texture" in
// docs/chill-soho-plan.md.
//
// Instruments are drawn independently of the rule, so every rule must suit every patch in the
// pool (trumpet, trombone, muted trumpet, vibraphone) — fast attack, sustaining or ringing body.
// The vibraphone rings rather than sustains, so a long riff note decays inside its written
// length on it; only the brass holds it, and brass is 70% of picks.

import Foundation

struct ChillSohoTextureGenerator {

    static func generate(frame: GlobalMusicalFrame,
                         structure: SongStructure,
                         drumEvents: [MIDIEvent],
                         breakdownStyle: ChillBreakdownStyle = .bassOstinato,
                         leadEvents: [MIDIEvent] = [],
                         rng: inout SeededRNG,
                         usedRuleIDs: inout Set<String>) -> [MIDIEvent] {
        // The horns never step on Lead 1 or Lead 2 (Zack, 2026-11-27). Both are final before this
        // runs, so every figure below asks `lead` whether it fits before it is written.
        let lead = LeadOccupancy(leadEvents)
        let pick = rng.weightedPick([0.25, 0.25, 0.25, 0.25])
        var ruleID = ["CHL-TEXT-001", "CHL-TEXT-002", "CHL-TEXT-003", "CHL-TEXT-004"][pick]
        let crashes = CrashPoints(drumEvents)
        let voicing = StabVoicing(rng: &rng)
        func stabs(_ rng: inout SeededRNG, around lead: LeadOccupancy) -> [MIDIEvent] {
            punctuationStabs(frame: frame, structure: structure, crashes: crashes,
                             voicing: voicing, lead: lead, rng: &rng)
        }
        var events: [MIDIEvent]
        switch pick {
        case 0:  events = hubbardRiffs(frame: frame, structure: structure, crashes: crashes,
                                       lead: lead, rng: &rng)
        case 2:  events = cliffRiffs(frame: frame, structure: structure, crashes: crashes,
                                     lead: lead, rng: &rng)
        case 3:  events = parallelRiffs(frame: frame, structure: structure, crashes: crashes,
                                        lead: lead, rng: &rng)
        default: events = stabs(&rng, around: lead)
        }
        // A song too short or too crowded for any riff to fit plays the stabs, so the track is
        // never absent.
        if events.isEmpty && pick != 1 {
            ruleID = "CHL-TEXT-002"
            events = stabs(&rng, around: lead)
        }
        // The horns answer a harmonic drone, a groove pocket or a Duo whichever rule is running.
        // Without them the drone is the one Soho break with no voice at all — bass and pads hold,
        // drums tick, and the rhythm part and both leads are out — which is why it sounded like
        // base Chill (Zack, 2026-10-11).
        if [.harmonicDrone, .groovePocket, .sohoDuo].contains(breakdownStyle) {
            events += breakdownAnswer(structure: structure, style: breakdownStyle,
                                      taken: Set(events.map(\.stepIndex)), lead: lead, rng: &rng)
        }
        // Rather over half of songs mark their turnarounds with a horn, announcing the chord
        // detour the way a section would announce itself. Not all of them: at every turnaround of
        // every song it stops being a gesture (Zack, 2026-10-12).
        if rng.nextDouble() < 0.55 {
            events += turnaroundStabs(frame: frame, structure: structure,
                                      taken: Set(events.map(\.stepIndex)), voicing: voicing,
                                      lead: lead, rng: &rng)
        }
        // Every figure was refused by the leads: the track is never absent, so the stabs play
        // regardless, the one case where the horns may meet a lead.
        if events.isEmpty {
            ruleID = "CHL-TEXT-002"
            events = stabs(&rng, around: LeadOccupancy([]))
        }
        usedRuleIDs.insert(ruleID)
        // Three separate figures write to this track — the texture rule, the turnaround marker and the
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
                                        lead: LeadOccupancy, rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for bar in ChillStructureGenerator.sohoTurnarounds(frame: frame, structure: structure).starts {
            // Never struck on a step the texture rule already sounds on: two figures at one
            // instant with different lengths is the staggered chord this track avoids.
            guard !taken.contains(bar * 16) else { continue }
            guard let c = structure.chordWindow(atBar: bar) else { continue }
            let pool = notes(c.chordTones, 58, 71)
            guard pool.count >= 2 else { continue }
            // One gesture, not a repeated figure: the bass is already walking back to the top and
            // the drums take a fill (Zack, 2026-10-12). Since 2026-11-27 the gesture is a single
            // hit only some of the time; mostly it is a short two- or three-note phrase moving
            // through the chord — a scoop up, a climb, a fall-off — so it is not always one
            // "bap" (Zack, 2026-11-27).
            // Two notes or three, evenly: three reads as the section rather than a pair of
            // players (Zack, 2026-10-15).
            let count = rng.nextDouble() < 0.5 ? 3 : 2
            let voiced = voicing.voice(pool, tensions: notes(c.scaleTensions, 58, 71),
                                       count: count, rng: &rng)
            let figure = stabFigure(maxHits: 1, room: 8, rng: &rng)
            guard figure.allSatisfy({ !taken.contains(bar * 16 + $0.0) }) else { continue }
            let hit = figureEvents(at: bar * 16, voiced: voiced, pool: pool, figure: figure,
                                   velocity: rng.velocity(60, 12))
            if lead.fits(hit) { events += hit }
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
    /// - **Duo**: a soft held two-note chord every four bars from the third, and a stab with the
    ///   snare pickup on the last bar's fourth beat
    ///
    /// Designed rather than measured: no reference song has a section of any of these kinds.
    private static func breakdownAnswer(structure: SongStructure, style: ChillBreakdownStyle,
                                        taken: Set<Int>, lead: LeadOccupancy,
                                        rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        func hits(_ bar: Int, _ steps: [Int], _ lo: Int, _ hi: Int, _ vel: UInt8, _ dur: Int) {
            guard let c = structure.chordWindow(atBar: bar) else { return }
            let pool = notes(c.chordTones, lo, hi)
            guard pool.count >= 2 else { return }
            // Never on a step the texture rule already sounds on — two figures at one instant
            // with different lengths is the staggered chord this track avoids.
            // The lowest tone and the middle one, but never a semitone apart (the 7th and root
            // of a maj7 can sit side by side): the upper note is at least a minor third up.
            let upper = pool.first { $0 - pool[0] >= 3 && $0 >= pool[pool.count / 2] }
                ?? pool.first { $0 - pool[0] >= 3 }
            guard let upper else { return }
            var unit: [MIDIEvent] = []
            for step in steps where !taken.contains(bar * 16 + step) {
                for n in [pool[0], upper] {
                    unit.append(MIDIEvent(stepIndex: bar * 16 + step, note: UInt8(n),
                                          velocity: vel, durationSteps: dur))
                }
            }
            if lead.fits(unit) { events += unit }
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
            // The way out: a short two-note stab on beat 4 of the last bar, into the return. It
            // was a single note, which on one horn reads as one player (Zack, 2026-11-27).
            hits(last, [12], 58, 71, rng.velocity(60, 10), 2)
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
            playable(rawVoice(pool, tensions: tensions, count: count, rng: &rng), pool: pool)
        }

        /// No two notes a semitone apart. Adjacent chord tones can be — the 7th and the root of a
        /// maj7 — and on one horn that reads as a wrong note. The lower of a clashing pair is
        /// swapped for the nearest chord tone that clashes with nothing; it used to be dropped,
        /// which turned two-note stabs into single notes (Zack, 2026-11-27). Dropped only when
        /// no chord tone fits.
        private func playable(_ v: [Int], pool: [Int]) -> [Int] {
            var out = Array(Set(v)).sorted()
            var i = 0
            while i + 1 < out.count {
                guard out[i + 1] - out[i] < 2 else { i += 1; continue }
                let gone = out.remove(at: i)
                let ok = pool.filter { p in out.allSatisfy { abs($0 - p) >= 2 } }
                if let sub = ok.min(by: { (abs($0 - gone), $0) < (abs($1 - gone), $1) }) {
                    out = (out + [sub]).sorted()
                }
                i = 0
            }
            return out
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

    /// Where Lead 1 and Lead 2 sound, step by step, read once from the finished lead tracks. The
    /// horns are an ornament: they may share a couple of notes with a lead or sit in its gaps, but
    /// never play over it (Zack, 2026-11-27).
    struct LeadOccupancy {
        let steps: Set<Int>

        init(_ events: [MIDIEvent]) {
            var s = Set<Int>()
            for e in events { for i in 0..<Swift.max(1, e.durationSteps) { s.insert(e.stepIndex + i) } }
            steps = s
        }

        /// How many of the figure's onsets (a chord is one) sound while a lead does.
        func overlap(_ events: [MIDIEvent]) -> (hit: Int, onsets: Int) {
            let groups = Dictionary(grouping: events, by: \.stepIndex)
            var hit = 0
            for (step, g) in groups {
                let len = g.map(\.durationSteps).max() ?? 1
                if (step..<(step + Swift.max(1, len))).contains(where: { steps.contains($0) }) { hit += 1 }
            }
            return (hit, groups.count)
        }

        /// A figure fits when at most a third of its onsets, and never more than two, meet a
        /// lead: a stab of one or two hits keeps clear of it altogether, a three-hit figure may
        /// touch it once and a riff of six or more notes twice.
        func fits(_ events: [MIDIEvent]) -> Bool {
            let o = overlap(events)
            guard o.onsets > 0 else { return true }
            return o.hit <= Swift.min(2, o.onsets / 3)
        }
    }

    /// Where the kit crashes, read once from the finished drum track: the return from a
    /// section-end fill, the return from a breakdown, and the cold-stop final hit.
    ///
    /// `steps` is every step carrying a crash — including the Remix Break exit, whose unison
    /// stabs fall on steps 0 AND 8 of its last bar — and `bars` is the bars whose downbeat
    /// carries one. Both exclude step 0 of the song.
    ///
    /// Read from the generated drums rather than recomputed, so the stabs land with the kit by
    /// construction — two independent random streams never have to agree. The plan proposed a
    /// shared `sohoAccentSteps(forBar:)` helper for this; reading the drum track is stricter,
    /// because the two can never drift apart.
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
    /// A real section does not punch the same block chord every time. Each stab is a chord of 2
    /// or 3 notes, struck once, twice or three times with its own rhythm — short then long, long
    /// then short — or moving through the chord as a short phrase, so the figure has a shape
    /// instead of being a single block (see `stabFigure`).
    private static func punctuationStabs(frame: GlobalMusicalFrame, structure: SongStructure,
                                         crashes: CrashPoints, voicing: StabVoicing,
                                         lead: LeadOccupancy, rng: inout SeededRNG) -> [MIDIEvent] {
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
            guard pool.count >= 2 else { return }
            let count = Swift.min(2 + rng.weightedPick(weights), pool.count)
            let voiced = voicing.voice(pool, tensions: notes(c.scaleTensions, 58, 71),
                                       count: count, rng: &rng)
            let figure = figureEvents(at: bar * 16 + step, voiced: voiced, pool: pool,
                                      figure: stabFigure(maxHits: maxHits, room: room, rng: &rng),
                                      velocity: vel)
            // A stab that would land on a lead is left out; the figure is not thinned, since a
            // figure with a hit missing is not the figure.
            if lead.fits(figure) { events += figure }
        }

        // Accents: 3 notes 64% of the time, otherwise 2, and up to three hits. One horn playing a
        // two- or three-note chord reads as a section, which is the sound this track is for, so
        // single notes came down from 16% and 40% (Zack, 2026-10-15) and went on 2026-11-27.
        //
        // A figure has to finish before the next accent in the same bar. The Remix Break's exit
        // crashes on steps 0 AND 8, and a bar can crash on 8 and 12, so a figure left to run the
        // rest of the bar would strike the same instant as the next one with a different length.
        let accents = crashes.steps
        for (i, at) in accents.enumerated() where at / 16 < frame.totalBars {
            let nextInBar = i + 1 < accents.count && accents[i + 1] / 16 == at / 16
                ? accents[i + 1] % 16 : 16
            stab(at / 16, step: at % 16, weights: [0.36, 0.64],
                 vel: rng.velocity(78, 12), maxHits: 3, room: nextInBar - at % 16)
        }

        // Pickups are lighter: mostly 2 notes.
        for section in structure.sections where section.label == .A || section.label == .B {
            var bar = section.startBar + phrase - 1
            while bar < section.endBar - 1 {
                // Leave the section's own last bar to the drum fill and the crash that follows.
                if !crashBarSet.contains(bar) && !crashBarSet.contains(bar + 1) {
                    // A pickup sits on beat 4 with only a beat of room, which limits it to the
                    // figures that finish inside four sixteenths.
                    stab(bar, step: 12, weights: [0.62, 0.38],
                         vel: rng.velocity(64, 12), maxHits: 3, room: 4)
                }
                bar += phrase
            }
        }
        return events.sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }
    }

    /// Horn figures, as (offset, length, velocity accent, chord shift) in sixteenths from the
    /// first hit. The shift moves every voice of that hit by that many chord tones (see
    /// `shifted`), which is how a phrase climbs or falls; repeated-chord figures keep it at 0.
    /// Filtered to those that finish inside `room`, and never longer than eight sixteenths, so a
    /// figure on a crash is done by beat 3.
    ///
    /// `maxHits` 1 asks for one gesture — a single hit or a short phrase — and is what the
    /// turnaround uses; the crash accents allow up to three hits.
    private static func stabFigure(maxHits: Int, room: Int,
                                   rng: inout SeededRNG) -> [(Int, Int, Int, Int)] {
        let one: [[(Int, Int, Int, Int)]] = [
            [(0, 2, 0, 0)],                                     // bap
            [(0, 4, 2, 0)],                                     // baaap
        ]
        // Two or three different chords in a row, a little longer than a hit (2026-11-27).
        let phrase: [[(Int, Int, Int, Int)]] = [
            [(0, 1, -3, -1), (2, 2, 3, 0)],                     // da-daa: a scoop up into the chord
            [(0, 1, -4, -2), (1, 1, -2, -1), (2, 2, 4, 0)],     // da-da-daa: a three-note climb
            [(0, 1, -3, -1), (2, 5, 3, 0)],                     // da-daaah
            [(0, 3, 3, 0), (4, 2, -5, -1)],                     // daah-dup: a fall-off
            [(0, 2, 2, 0), (3, 1, -2, -1), (5, 2, -4, -2)],     // daa-da-dup: stepping down
        ]
        let two: [[(Int, Int, Int, Int)]] = [
            [(0, 1, 0, 0), (2, 2, -4, 0)],                      // bap-bap
            [(0, 1, -3, 0), (1, 3, 3, 0)],                      // ba-daaa
            [(0, 1, -4, 0), (2, 6, 4, 0)],                      // bap-baaa
            [(0, 3, 2, 0), (4, 2, -4, 0)],                      // baaa-bap
            [(0, 5, 3, 0), (6, 1, -4, 0)],                      // baaaaap-bap
            [(0, 1, -2, 0), (3, 4, 3, 0)],                      // bap--baaa
        ]
        let three: [[(Int, Int, Int, Int)]] = [
            [(0, 1, -2, 0), (1, 1, -4, 0), (2, 2, 4, 0)],       // ba-ba-baa
            [(0, 1, -4, 0), (2, 1, -2, 0), (4, 4, 5, 0)],       // bap-bap-baaap
            [(0, 1, 0, 0), (2, 3, 3, 0), (6, 2, -4, 0)],        // bap-baaa-bap
            [(0, 2, 2, 0), (3, 1, -4, 0), (5, 3, 3, 0)],        // baa-bap-baaa
            [(0, 3, 3, 0), (4, 1, -3, 0), (6, 2, -1, 0)],       // baaap-bap-bap
        ]
        func fits(_ f: [(Int, Int, Int, Int)]) -> Bool {
            guard let last = f.last else { return false }
            return last.0 + last.1 <= Swift.max(1, room)
        }
        let pools = [one.filter(fits), phrase.filter(fits), maxHits >= 2 ? two.filter(fits) : [],
                     maxHits >= 3 ? three.filter(fits) : []]
        // 15% a single hit, 25% a moving phrase, 35% two hits, 25% three. Single hits were 35%
        // (Zack, 2026-10-12); on 2026-11-27 he asked for two- and three-note figures more
        // often, in different shapes, with some single hits kept.
        // A pool with nothing that fits the bar is dropped and
        // the weights renormalised — `weightedPick` requires them to sum to 1 and otherwise falls
        // through to the last index, which would be the empty pool.
        let candidates = zip(pools, [0.15, 0.25, 0.35, 0.25]).filter { !$0.0.isEmpty }
        guard !candidates.isEmpty else { return [(0, 1, 0, 0)] }
        let total = candidates.reduce(0.0) { $0 + $1.1 }
        let pool = candidates[rng.weightedPick(candidates.map { $0.1 / total })].0
        return pool[rng.nextInt(upperBound: pool.count)]
    }

    /// A stab figure written out: every hit strikes all of `voiced` together, with one length,
    /// moved through `pool` by the hit's chord shift.
    private static func figureEvents(at start: Int, voiced: [Int], pool: [Int],
                                     figure: [(Int, Int, Int, Int)], velocity: UInt8) -> [MIDIEvent] {
        var out: [MIDIEvent] = []
        for (offset, length, accent, shift) in figure {
            let v = UInt8(Swift.max(40, Swift.min(110, Int(velocity) + accent)))
            for n in shifted(voiced, by: shift, pool: pool) {
                out.append(MIDIEvent(stepIndex: start + offset, note: UInt8(n),
                                     velocity: v, durationSteps: length))
            }
        }
        return out
    }

    /// `voiced` with every note moved `by` chord tones along `pool` (a colour tension moves from
    /// the chord tone nearest it), so a moving phrase stays on chord tones. Falls back to the
    /// voicing unmoved when a note would leave the pool, two notes would merge, or two would
    /// sit a semitone apart.
    private static func shifted(_ voiced: [Int], by: Int, pool: [Int]) -> [Int] {
        guard by != 0 else { return voiced }
        var out: [Int] = []
        for n in voiced {
            guard let i = pool.indices.min(by: { (abs(pool[$0] - n), $0) < (abs(pool[$1] - n), $1) }),
                  pool.indices.contains(i + by) else { return voiced }
            out.append(pool[i + by])
        }
        out.sort()
        let ok = Set(out).count == out.count && !zip(out, out.dropFirst()).contains { $1 - $0 < 2 }
        return ok ? out : voiced
    }

    // MARK: - Horn riffs: CHL-TEXT-001, CHL-TEXT-003 and CHL-TEXT-004

    /// One note of a riff. `rung` is a step on the chord-tone ladder, counted from the statement's
    /// anchor note (0 = the anchor, 1 = the next chord tone up, -1 = the next one down), so a riff
    /// keeps its contour over whatever chord is sounding and every note is a chord tone. `bar` and
    /// `step` are inside the statement. `solo` notes get no second horn.
    private struct RiffNote: Equatable {
        let bar: Int
        let step: Int
        let length: Int
        let rung: Int
        let accent: Int
        var solo = false
    }

    /// How the other horns sit against the line.
    private enum RiffHarmony {
        /// A chord tone about a third below, moving with the line: two players in thirds. A
        /// statement low enough that a third below would fall under `hornFloor` takes its
        /// harmony a third above instead, for the whole statement.
        case thirds
        /// The Cantaloop section as the record voices it (2026-11-27): in the hook bar (even
        /// bars of the statement) the line, a chord tone about a fourth below and the line an
        /// octave down, all inside one octave (F5, C5, F4 in the source); in the answer bar (odd
        /// bars) the line and a chord tone about a fifth below (C4 over F3). It used to put the
        /// third voice an octave under the lower one, which spread past an octave and reached
        /// the bass at C3.
        case parallel
    }

    /// No horn note below F3, the lowest note of the Cantaloop section, which keeps the horns
    /// out of the bass (Zack, 2026-11-27).
    private static let hornFloor = 53
    /// No riff note above A5: an octave-up statement reached C6, shrill on a trumpet
    /// (Zack, 2026-11-27).
    private static let hornCeiling = 81

    /// **CHL-TEXT-001 Freddie Hubbard Riff** — after the trumpet in Us3's *Cantaloop*, which
    /// samples Hubbard. A beat-4 pickup climbs three chord tones to a held note; a quick
    /// three-note rise answers it and drops away, and then the bar rests. The original is F Ab Bb
    /// (held), Ab Bb C, Eb, F (MIDI bars 10 to 12 of the transcription); Zack asked for it
    /// shortened (2026-11-27), so the third bar, a soft held root, is cut and the held note is
    /// six sixteenths, not eight.
    private static let hubbardRiff: [RiffNote] = [
        RiffNote(bar: 0, step: 6,  length: 1, rung: 0,  accent: -4),
        RiffNote(bar: 0, step: 8,  length: 2, rung: 1,  accent: 0),
        RiffNote(bar: 0, step: 10, length: 2, rung: 2,  accent: 2),
        RiffNote(bar: 0, step: 12, length: 6, rung: 2,  accent: 4),
        RiffNote(bar: 1, step: 6,  length: 2, rung: 1,  accent: 0),
        RiffNote(bar: 1, step: 9,  length: 2, rung: 2,  accent: 2),
        RiffNote(bar: 1, step: 12, length: 2, rung: 3,  accent: 4),
        RiffNote(bar: 1, step: 14, length: 2, rung: -1, accent: -4),
    ]

    /// **CHL-TEXT-003 Jimmy Cliff Riff** — after the trumpet in *You Can Get It If You Really
    /// Want*. Three bars, call and response, almost all repeated notes: one pitch struck three
    /// times then a step down twice; a leap to a repeated high note that falls away; and a drop to
    /// the bottom that is held. Cut from the transcription's four bars (its second bar, down and
    /// back up, is gone) because Zack wanted three at most (2026-11-27). Bent by one or two transformations every
    /// time it comes round (`varied`), never an exact copy (Zack, 2026-11-27).
    private static let cliffRiff: [RiffNote] = [
        RiffNote(bar: 0, step: 4,  length: 2, rung: 0,  accent: 0),
        RiffNote(bar: 0, step: 6,  length: 2, rung: 0,  accent: -2),
        RiffNote(bar: 0, step: 8,  length: 4, rung: 0,  accent: 3),
        RiffNote(bar: 0, step: 12, length: 2, rung: -1, accent: -2),
        RiffNote(bar: 0, step: 14, length: 2, rung: -1, accent: -4),
        RiffNote(bar: 1, step: 4,  length: 2, rung: 2,  accent: 0),
        RiffNote(bar: 1, step: 6,  length: 2, rung: 2,  accent: -2),
        RiffNote(bar: 1, step: 8,  length: 2, rung: 2,  accent: 0),
        RiffNote(bar: 1, step: 10, length: 2, rung: 0,  accent: -2),
        RiffNote(bar: 1, step: 12, length: 4, rung: 1,  accent: 3),
        RiffNote(bar: 2, step: 0,  length: 2, rung: 2,  accent: 0),
        RiffNote(bar: 2, step: 6,  length: 6, rung: -2, accent: 3),
    ]

    /// The `loops` two-bar figures and the closing pings of **CHL-TEXT-004 Cantaloop Parallel
    /// Riff**, after the three-horn hook in Us3's *Cantaloop*. Steps 2, 5, 8 and 10 — a 3+3+2+2
    /// — all on one pitch, the last a step up; the second bar answers a fifth lower; then, now and
    /// then, a single high note on step 6 for one or two bars.
    private static func parallelRiff(loops: Int, pings: Int) -> [RiffNote] {
        var out: [RiffNote] = []
        for loop in 0..<loops {
            let b = loop * 2
            for (i, step) in [2, 5, 8, 10].enumerated() {
                out.append(RiffNote(bar: b, step: step, length: 2, rung: i == 3 ? 1 : 0,
                                    accent: [3, 0, 0, 2][i]))
                out.append(RiffNote(bar: b + 1, step: step, length: 2, rung: i == 3 ? -1 : -2,
                                    accent: [0, -3, -3, -1][i]))
            }
        }
        for p in 0..<pings {
            out.append(RiffNote(bar: loops * 2 + p, step: 6, length: 2, rung: 4,
                                accent: -4 - 3 * p, solo: true))
        }
        return out
    }

    /// The ways a statement is bent away from the transcription. Every statement of every riff
    /// takes one or two of them, never the same set as the statement before it, so no statement
    /// is an exact copy of the source or of its neighbour (Zack, 2026-11-27).
    private enum RiffTransform: CaseIterable {
        /// One hit moves a sixteenth early or late.
        case rhythm
        /// One or two notes move a chord tone up or down.
        case contour
        /// Only the first or the second half is played.
        case fragment
        /// A pickup before the first note, or the last note struck again.
        case extend
        /// The whole statement a chord tone higher or lower. It moved an octave until
        /// 2026-11-27, which no riff can do inside F3 to A5 without crushing its contour: up ran
        /// past A5, down put the Cantaloop section into the bass.
        case register
    }

    /// What a transformation may touch in one riff.
    private struct RiffRules {
        let allowed: [RiffTransform]
        /// Fragment may keep the second half (false for the Parallel Riff, whose second half is
        /// only its closing pings).
        let allowSecond: Bool
        /// The chord-tone moves the register transformation may make.
        let registerShifts: [Int]
        /// Which notes the contour transformation may change.
        let contourOK: (RiffNote) -> Bool
    }

    /// `riff` bent by one or two transformations drawn from `rules`, avoiding `avoid` (the set
    /// the previous statement used). Returns the notes and the set used.
    private static func varied(_ riff: [RiffNote], rules: RiffRules,
                               avoid: Set<RiffTransform>, rng: inout SeededRNG)
        -> (notes: [RiffNote], used: Set<RiffTransform>) {
        var pool = rules.allowed.filter { !avoid.contains($0) }
        if pool.isEmpty { pool = rules.allowed }
        var order: [RiffTransform] = []
        while !pool.isEmpty { order.append(pool.remove(at: rng.nextInt(upperBound: pool.count))) }
        let want = order.count > 1 && rng.nextDouble() < 0.4 ? 2 : 1
        var notes = riff, used: Set<RiffTransform> = []
        for t in order where used.count < want {
            var next = notes
            switch t {
            case .register:
                guard !rules.registerShifts.isEmpty else { break }
                let shift = rules.registerShifts[rng.nextInt(upperBound: rules.registerShifts.count)]
                next = next.map {
                    RiffNote(bar: $0.bar, step: $0.step, length: $0.length, rung: $0.rung + shift,
                             accent: $0.accent, solo: $0.solo)
                }
            case .rhythm:
                for _ in 0..<6 {
                    let i = 1 + rng.nextInt(upperBound: Swift.max(1, next.count - 1))
                    guard i < next.count, !next[i].solo else { continue }
                    let step = next[i].step + (rng.nextDouble() < 0.5 ? -1 : 1)
                    let clash = next.contains { $0.bar == next[i].bar && $0.step == step }
                    guard (0...15).contains(step), !clash else { continue }
                    next[i] = RiffNote(bar: next[i].bar, step: step, length: next[i].length,
                                       rung: next[i].rung, accent: next[i].accent, solo: next[i].solo)
                    break
                }
            case .contour:
                let picks = next.indices.filter { rules.contourOK(next[$0]) && $0 != next.count - 1 }
                for _ in 0..<Swift.min(picks.count, 1 + rng.nextInt(upperBound: 2)) {
                    let i = picks[rng.nextInt(upperBound: picks.count)]
                    let n = next[i]
                    next[i] = RiffNote(bar: n.bar, step: n.step, length: n.length,
                                       rung: n.rung + (rng.nextDouble() < 0.5 ? -1 : 1),
                                       accent: n.accent, solo: n.solo)
                }
            case .fragment:
                let maxBar = next.map(\.bar).max() ?? 0
                guard maxBar >= 1 else { break }
                let mid = (maxBar + 1) / 2
                if rules.allowSecond && rng.nextDouble() < 0.5 {
                    next = next.filter { $0.bar >= mid }.map {
                        RiffNote(bar: $0.bar - mid, step: $0.step, length: $0.length,
                                 rung: $0.rung, accent: $0.accent, solo: $0.solo)
                    }
                } else {
                    next = next.filter { $0.bar < mid }
                }
            case .extend:
                guard let last = next.last else { break }
                if let first = next.first, first.step >= 2, rng.nextDouble() < 0.5 {
                    next.insert(RiffNote(bar: first.bar, step: first.step - 2, length: 1,
                                         rung: first.rung - 1, accent: -4), at: 0)
                } else if last.step + last.length + 1 <= 14 {
                    next.append(RiffNote(bar: last.bar, step: last.step + last.length + 1, length: 2,
                                         rung: last.rung, accent: -3, solo: last.solo))
                }
            }
            if next != notes {
                notes = next; used.insert(t)
            }
        }
        // One line, so a note never runs into the next one's onset; a doubled onset goes.
        notes.sort { ($0.bar, $0.step) < ($1.bar, $1.step) }
        var fixed: [RiffNote] = []
        for (i, n) in notes.enumerated() {
            let at = n.bar * 16 + n.step
            if let prev = fixed.last, prev.bar * 16 + prev.step == at { continue }
            let nextAt = i + 1 < notes.count ? notes[i + 1].bar * 16 + notes[i + 1].step : Int.max
            fixed.append(RiffNote(bar: n.bar, step: n.step, length: Swift.max(1, Swift.min(n.length, nextAt - at)),
                                  rung: n.rung, accent: n.accent, solo: n.solo))
        }
        return (fixed, used)
    }

    /// Start bars where a riff of `span` bars fits: inside a groove section (A or B), leaving the
    /// section's last bar to its fill, clear of every drum crash and every turnaround, and over
    /// one chord. A song with no such place relaxes the chord rule rather than lose the rule.
    private static func riffSlots(frame: GlobalMusicalFrame, structure: SongStructure,
                                  crashes: CrashPoints, span: Int, first: Int, gap: Int)
        -> [(bar: Int, section: Int)] {
        let crashBars = Set(crashes.steps.map { $0 / 16 }).union(crashes.bars)
        let turnarounds = ChillStructureGenerator.sohoTurnaroundBars(frame: frame, structure: structure)
        func slots(oneChord: Bool) -> [(bar: Int, section: Int)] {
            var out: [(bar: Int, section: Int)] = []
            for (i, section) in structure.sections.enumerated()
            where section.label == .A || section.label == .B {
                var bar = section.startBar + first
                while bar + span <= section.endBar - 1 && bar + span <= frame.totalBars - 1 {
                    let bars = bar..<(bar + span)
                    let clear = bars.allSatisfy { !crashBars.contains($0) && !turnarounds.contains($0) }
                    let window = structure.chordWindow(atBar: bar)?.startBar
                    let same = !oneChord || bars.allSatisfy { structure.chordWindow(atBar: $0)?.startBar == window }
                    if clear && same { out.append((bar, i)) }
                    bar += gap
                }
            }
            return out
        }
        let strict = slots(oneChord: true)
        return strict.isEmpty ? slots(oneChord: false) : strict
    }

    /// Plays one statement of a riff from `startBar`. The anchor is the lowest chord tone at or
    /// above `anchorLow` in the first bar's chord; each note is the chord tone `rung` places from
    /// the anchor in its own bar's chord. The second horn is always a chord tone, never closer
    /// than a minor third, so no pair of notes clashes however the chord changes.
    private static func riffStatement(_ riff: [RiffNote], startBar: Int, anchorLow: Int,
                                      harmony: RiffHarmony?, velocity: UInt8,
                                      structure: SongStructure) -> [MIDIEvent] {
        guard let first = structure.chordWindow(atBar: startBar),
              let anchor = notes(first.chordTones, anchorLow, anchorLow + 12).first else { return [] }
        // The line first, so the harmony can be placed for the statement as a whole.
        var line: [(note: RiffNote, pitch: Int, step: Int, vel: Int, tones: Set<Int>)] = []
        for n in riff {
            guard let c = structure.chordWindow(atBar: startBar + n.bar) else { continue }
            let ladder = notes(c.chordTones, 55, hornCeiling)
            guard let nearest = ladder.indices.min(by: { abs(ladder[$0] - anchor) < abs(ladder[$1] - anchor) })
            else { continue }
            let pitch = ladder[Swift.max(0, Swift.min(ladder.count - 1, nearest + n.rung))]
            line.append((n, pitch, (startBar + n.bar) * 16 + n.step,
                         Swift.max(36, Swift.min(110, Int(velocity) + n.accent)), c.chordTones))
        }
        func thirdBelow(_ x: (note: RiffNote, pitch: Int, step: Int, vel: Int, tones: Set<Int>)) -> Int? {
            nearestTone(x.tones, to: x.pitch - 4, lo: Swift.max(hornFloor, x.pitch - 8), hi: x.pitch - 3)
        }
        // Thirds sit under the line unless the line runs so low that a note would have none
        // above F3; then the second horn takes the thirds above for the whole statement, so the
        // two players never cross.
        let above = line.contains { !$0.note.solo && thirdBelow($0) == nil }
        var events: [MIDIEvent] = []
        for x in line {
            let (n, pitch, step, vel) = (x.note, x.pitch, x.step, x.vel)
            events.append(MIDIEvent(stepIndex: step, note: UInt8(pitch), velocity: UInt8(vel),
                                    durationSteps: n.length))
            guard !n.solo, let harmony else { continue }
            var lows: [Int] = []
            switch harmony {
            case .thirds:
                let t = above
                    ? nearestTone(x.tones, to: pitch + 4, lo: pitch + 3, hi: Swift.min(hornCeiling, pitch + 8))
                    : thirdBelow(x)
                lows = t.map { [$0] } ?? []
            case .parallel where n.bar % 2 == 0:
                lows = [nearestTone(x.tones, to: pitch - 5, lo: Swift.max(hornFloor, pitch - 7), hi: pitch - 3),
                        pitch - 12 >= hornFloor ? pitch - 12 : nil].compactMap { $0 }
            case .parallel:
                lows = nearestTone(x.tones, to: pitch - 7, lo: Swift.max(hornFloor, pitch - 9),
                                   hi: pitch - 5).map { [$0] } ?? []
            }
            for l in lows {
                events.append(MIDIEvent(stepIndex: step, note: UInt8(l),
                                        velocity: UInt8(Swift.max(30, vel - 8)),
                                        durationSteps: n.length))
            }
        }
        return events
    }

    /// The chord tone in [lo, hi] closest to `target`, lower on a tie.
    /// Nil when the floor or ceiling leaves no room (`lo` above `hi`).
    private static func nearestTone(_ pcs: Set<Int>, to target: Int, lo: Int, hi: Int) -> Int? {
        guard lo <= hi else { return nil }
        return notes(pcs, lo, hi).min { abs($0 - target) < abs($1 - target) }
    }

    /// Picks `want` of `bars`, spread evenly rather than clustered.
    private static func spread(_ bars: [Int], want: Int) -> [Int] {
        guard !bars.isEmpty else { return [] }
        let n = Swift.min(want, bars.count)
        return (0..<n).map { bars[$0 * bars.count / n] }
    }

    /// Writes one statement near each spot, keeping it off the leads. A spot offers a preferred
    /// bar and other bars it may use instead, nearest first; the first that fits `lead` wins, and
    /// a spot where none fits stays silent. Statements keep four bars between them. If every spot
    /// fails, the least intrusive attempt is played, so the rule is never absent.
    private static func placeStatements(_ spots: [(bar: Int, alts: [Int])], lead: LeadOccupancy,
                                        rng: inout SeededRNG,
                                        make: (Int, inout SeededRNG) -> [MIDIEvent]) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        var used: [Int] = []
        var best: (ratio: Double, events: [MIDIEvent])?
        for spot in spots {
            let others = spot.alts.filter { $0 != spot.bar }
                .sorted { (abs($0 - spot.bar), $0) < (abs($1 - spot.bar), $1) }
            for bar in ([spot.bar] + others).filter({ b in !used.contains { abs($0 - b) < 4 } }).prefix(8) {
                let e = make(bar, &rng)
                guard !e.isEmpty else { continue }
                if lead.fits(e) { events += e; used.append(bar); break }
                let o = lead.overlap(e)
                let ratio = Double(o.hit) / Double(Swift.max(1, o.onsets))
                if best == nil || ratio < best!.ratio { best = (ratio, e) }
            }
        }
        if events.isEmpty, let best { return best.events }
        return events
    }

    /// CHL-TEXT-001: two to four statements a song at the start of a groove phrase.
    private static func hubbardRiffs(frame: GlobalMusicalFrame, structure: SongStructure,
                                     crashes: CrashPoints, lead: LeadOccupancy,
                                     rng: inout SeededRNG) -> [MIDIEvent] {
        let slots = riffSlots(frame: frame, structure: structure, crashes: crashes,
                              span: 3, first: 1, gap: 8).map(\.bar)
        let rules = RiffRules(allowed: RiffTransform.allCases, allowSecond: true, registerShifts: [-1, 1],
                              contourOK: { $0.length < 6 })
        let spots = spread(slots, want: 2 + rng.nextInt(upperBound: 3)).map { (bar: $0, alts: slots) }
        var previous: Set<RiffTransform> = []
        return placeStatements(spots, lead: lead, rng: &rng) { bar, rng in
            let v = varied(hubbardRiff, rules: rules, avoid: previous, rng: &rng)
            previous = v.used
            // Every statement in two parts: a single line on one horn sounded like a lone player
            // (Zack, 2026-11-27; it was 75%).
            return riffStatement(v.notes, startBar: bar, anchorLow: 64, harmony: .thirds,
                                 velocity: rng.velocity(66, 8), structure: structure)
        }
    }

    /// CHL-TEXT-003: at most one statement in a groove section, never in two sections running,
    /// and three in a song at the most.
    private static func cliffRiffs(frame: GlobalMusicalFrame, structure: SongStructure,
                                   crashes: CrashPoints, lead: LeadOccupancy,
                                   rng: inout SeededRNG) -> [MIDIEvent] {
        let slots = riffSlots(frame: frame, structure: structure, crashes: crashes,
                              span: 3, first: 2, gap: 4)
        let sections = Array(Set(slots.map(\.section))).sorted()
        var chosen: [Int] = []
        for s in sections where chosen.count < 3 {
            if chosen.last == s - 1 && !chosen.isEmpty { continue }
            if rng.nextDouble() < 0.6 { chosen.append(s) }
        }
        if chosen.isEmpty, let s = sections.first { chosen = [s] }
        let rules = RiffRules(allowed: RiffTransform.allCases, allowSecond: true, registerShifts: [-1, 1],
                              contourOK: { $0.length < 6 })
        let spots: [(bar: Int, alts: [Int])] = chosen.map { s in
            let inSection = slots.filter { $0.section == s }.map(\.bar)
            return (inSection[rng.nextInt(upperBound: inSection.count)], inSection)
        }
        var previous: Set<RiffTransform> = []
        return placeStatements(spots, lead: lead, rng: &rng) { bar, rng in
            let v = varied(cliffRiff, rules: rules, avoid: previous, rng: &rng)
            previous = v.used
            // Anchored at A4, down from C5, so the repeated high note stays under A5
            // (2026-11-27). Always in two parts, like the Hubbard riff.
            return riffStatement(v.notes, startBar: bar, anchorLow: 69, harmony: .thirds,
                                 velocity: rng.velocity(62, 8), structure: structure)
        }
    }

    /// CHL-TEXT-004: one statement in the last groove section that has room, and in 40% of songs
    /// a second in an earlier one. Two bars of the hook and its answer, and now and then one or
    /// two closing pings.
    private static func parallelRiffs(frame: GlobalMusicalFrame, structure: SongStructure,
                                      crashes: CrashPoints, lead: LeadOccupancy,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        // Mostly two bars, the hook and its answer (Zack, 2026-11-27): 80% stop there, 15% add
        // one high ping, 5% two.
        let loops = 1
        let pings = [0, 1, 2][rng.weightedPick([0.80, 0.15, 0.05])]
        let riff = parallelRiff(loops: loops, pings: pings)
        let slots = riffSlots(frame: frame, structure: structure, crashes: crashes,
                              span: loops * 2 + pings, first: 2, gap: 4)
        let sections = Array(Set(slots.map(\.section))).sorted()
        guard let last = sections.last else { return [] }
        var chosen = [last]
        if sections.count > 1 && rng.nextDouble() < 0.4 {
            chosen.append(sections[rng.nextInt(upperBound: sections.count - 1)])
        }
        // The 3+3+2+2 rhythm is the hook, so it stays; the last hit of each bar, the pings, the
        // length and the register are what move. The register only rises: a step down puts the
        // answer bar's lower horn under F3.
        let rules = RiffRules(allowed: [.contour, .fragment, .extend, .register], allowSecond: false,
                              registerShifts: [1], contourOK: { $0.step == 10 || $0.solo })
        let spots: [(bar: Int, alts: [Int])] = chosen.map { s in
            let inSection = slots.filter { $0.section == s }.map(\.bar)
            return (inSection[rng.nextInt(upperBound: inSection.count)], inSection)
        }
        var previous: Set<RiffTransform> = []
        return placeStatements(spots, lead: lead, rng: &rng) { bar, rng in
            let v = varied(riff, rules: rules, avoid: previous, rng: &rng)
            previous = v.used
            return riffStatement(v.notes, startBar: bar, anchorLow: 69, harmony: .parallel,
                                 velocity: rng.velocity(64, 8), structure: structure)
        }
    }
}
