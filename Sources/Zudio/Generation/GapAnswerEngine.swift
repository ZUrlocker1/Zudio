// GapAnswerEngine.swift — base Motorik Lead 2 as answers in Lead 1's gaps
// Copyright (c) 2026 Zack Urlocker
//
// The old Lead 2 rules played over Lead 1 with random chord and scale notes, so the two leads
// stepped on each other. These rules answer Lead 1 instead. Lead 2 is silent while Lead 1 plays a
// phrase and speaks in the gaps between phrases, in a register below it; only the harmony and bed
// rules sound with Lead 1. It runs after ArrangementFilter, HarmonicFilter and the breakdown cut,
// so it answers only the calls that survived. See docs/Solo-improvement-plan.md, "Built: Motorik
// Lead 2".
//
// MOT-LD2-001 Echo answer       — Lead 1's last 2 to 4 notes, same rhythm, a third, sixth or octave lower
// MOT-LD2-003 Hook fragment     — the first 2 to 5 notes of Lead 1's last phrase, inverted or a step down
// MOT-LD2-004 Answer cell       — a cell paired with Lead 1's rule, restated in every answer
// MOT-LD2-006 Statement harmony — every second Lead 1 statement a third below, echo answers elsewhere
// MOT-LD2-002 Low bed           — root or fifth held under Lead 1's long notes, and alone in a long gap
//
// Every note sits on the 8th-note grid and held notes start on beats, so Lead 2 locks to the same
// kick and snare as the Lead 1 hooks.

enum GapAnswerEngine {

    static let echoAnswer       = "MOT-LD2-001"
    static let hookFragment     = "MOT-LD2-003"
    static let answerCell       = "MOT-LD2-004"
    static let statementHarmony = "MOT-LD2-006"
    static let lowBed           = "MOT-LD2-002"
    static let ruleIDs: Set<String> = [echoAnswer, hookFragment, answerCell, statementHarmony, lowBed]

    static func isGapRule(_ id: String) -> Bool { ruleIDs.contains(id) }

    // Base Kosmic Lead 2 (phase 5). The same engine with Kosmic data: a register under Lead 1,
    // slower answers, cells paired with the Kosmic hooks, and Lead 2 starting on bar lines.
    static let kosmicEcho  = "KOS-LD2-002"   // Slow echo answer
    static let kosmicCell  = "KOS-LD2-003"   // Slow answer cell
    static let kosmicReply = "KOS-LD2-004"   // Gap reply melody
    static let kosmicRuleIDs: Set<String> = [kosmicEcho, kosmicCell, kosmicReply]

    static func isKosmicGapRule(_ id: String) -> Bool { kosmicRuleIDs.contains(id) }

    /// Kosmic Lead 2's register, mostly under Lead 1's 56 to 84. Wider than an octave: at 55 to 67
    /// a two-note figure straddling the edge folded one note down an octave (Lone Spectrum, a
    /// step became a seventh).
    static let kosmicRegister = RegisterBounds(low: 52, high: 69)
    /// Kosmic cells span up to an octave and a half (Beach Scene's IV and V arpeggio covers 12
    /// semitones), so they get room to keep their shape in any key.
    private static let kosmicCellRegister = RegisterBounds(low: 52, high: 69)
    /// Kosmic harmony windows sit with Lead 1, a third under it or in unison, so they follow it up.
    private static let kosmicHarmonyRegister = RegisterBounds(low: 52, high: 79)

    /// Lead 2's register on this path, below Lead 1's 52 to 79. HarmonicFilter gets it as the
    /// track's bounds, so Pass B can't lift an answer back above 67.
    static let register = RegisterBounds(low: 50, high: 67)
    private static let bedRegister = RegisterBounds(low: 50, high: 60)
    /// The Answer cell's register: up to 69 so a song that drops an octave can sit its cell high.
    private static let cellRegister = RegisterBounds(low: 50, high: 69)
    /// An Answer cell that drops an octave may reach a little below the register.
    private static let dropRegister = RegisterBounds(low: 47, high: 69)
    /// The harmony sits a third under Lead 1 wherever Lead 1 is, so it may run above 67.
    private static let harmonyRegister = RegisterBounds(low: 50, high: 79)

    // MARK: - Answer cells

    private static func n(_ step: Int, _ deg: Int, _ len: Int, _ vel: Int) -> HookNote {
        HookNote(step: step, deg: deg, len: len, vel: vel)
    }

    /// MOT-LD2-004's cell for each Lead 1 hook, in semitones from the song tonic, all on the 8th
    /// grid with held notes on beats.
    private static let pairedCells: [String: [HookBar]] = [
        // Hallogallo hook: the pulse tail, the flat seventh into the root in soft 8ths.
        "MOT-LD1-001": [[n(0, -2, 2, 66), n(2, 0, 2, 72), n(4, 0, 2, 64),
                         n(8, -2, 2, 64), n(10, 0, 2, 70), n(12, 0, 4, 68)]],
        // Radioactive riff: the vocal line 1 1 1 1 3 2 1, re-gridded onto 8ths.
        "MOT-LD1-002": [[n(0, 0, 2, 72), n(2, 0, 2, 66), n(4, 0, 2, 70), n(6, 0, 2, 64),
                         n(8, 4, 2, 74), n(10, 2, 2, 68), n(12, 0, 4, 72)]],
        // Model riff: the riff's tail, 2 flat 7 5.
        "MOT-LD1-006": [[n(0, 2, 6, 72), n(6, -2, 2, 66), n(8, -5, 8, 70)]],
        // Tour de France riff: the cadence flat 7 flat 3 1, its last note moved onto the beat.
        "MOT-LD1-003": [[n(0, -2, 4, 72), n(4, 3, 4, 68), n(8, 0, 8, 72)]],
    ]

    /// MOT-LD2-004's cell under every other Lead 1 rule: a two-bar descent 5 4 3 2 to the root.
    private static let descentCell: [HookBar] = [
        [n(0, 7, 4, 70), n(4, 5, 4, 66), n(8, 4, 4, 68), n(12, 2, 4, 64)],
        [n(0, 0, 8, 70)],
    ]

    /// KOS-LD2-003's cells for the Kosmic hooks, in semitones from the song tonic, with the
    /// homage operations that keep each one recognisable. KOS-LD1-007 Blade Runner theme has no
    /// stored cell: its answer is Lead 1's own held last note, a third lower (see `generate`).
    private static let kosmicPairedCells: [String: (cell: [HookBar], homage: [Double])] = [
        // Pulstar's rising riff, a native 16th figure: 1 2 flat 3 into 4 on the bar, 5, then
        // back to 1, held. Only a dropped middle note keeps it a rising run.
        "KOS-LD1-001": ([[n(13, 0, 1, 58), n(14, 2, 1, 60), n(15, 3, 1, 62)],
                          [n(0, 5, 2, 66), n(2, 7, 1, 62), n(3, 0, 9, 64)]],
                         [0, 1, 0, 0, 0]),
        // Beach Scene's answer: rising arpeggios on IV and V in 8ths, landing on the root.
        "KOS-LD1-005": ([[n(0, -12, 2, 60), n(2, -7, 2, 62), n(4, -3, 4, 64),
                           n(8, -10, 2, 60), n(10, -5, 2, 62), n(12, -1, 4, 64)],
                          [n(0, 0, 12, 66)]],
                         [0.5, 0.5, 0, 0, 0]),
    ]

    /// KOS-LD2-003 under every other Kosmic Lead 1 rule: KOS-LD1-004's two-on, two-off echo cell,
    /// two held notes a step apart, the fifth rising to the sixth. Every other answer plays it a
    /// third lower, as the old rule's echo did.
    private static let kosmicPairCell: [HookBar] = [[n(0, 7, 14, 62)], [n(0, 9, 14, 58)]]

    // MARK: - Phrase map

    struct Phrase {
        var notes: [MIDIEvent]
        var start: Int
        var end: Int
    }

    /// Lead 1's onsets grouped into phrases: a new phrase starts wherever the gap from one note's
    /// end to the next onset is 8 steps or more. Two notes on one step keep the higher.
    static func phraseMap(_ lead1: [MIDIEvent]) -> [Phrase] {
        var notes: [MIDIEvent] = []
        for e in lead1.sorted(by: { $0.stepIndex != $1.stepIndex ? $0.stepIndex < $1.stepIndex : $0.note > $1.note }) {
            if let last = notes.last, last.stepIndex == e.stepIndex { continue }
            notes.append(e)
        }
        var phrases: [Phrase] = []
        for e in notes {
            let end = e.stepIndex + Swift.max(1, e.durationSteps)
            if var p = phrases.last, e.stepIndex - p.end < 8 {
                p.notes.append(e)
                p.end = Swift.max(p.end, end)
                phrases[phrases.count - 1] = p
            } else {
                phrases.append(Phrase(notes: [e], start: e.stepIndex, end: end))
            }
        }
        return phrases
    }

    // MARK: - Generation

    /// `steps` moves a cell note by scale steps after its pitch is worked out.
    private struct ANote { var at: Int; var src: Int; var len: Int; var vel: Int; var steps = 0 }

    /// `steps` moves Lead 1's own note by the ANote's scale steps (the Kosmic reply and the
    /// Blade Runner answer).
    private enum Transform { case echo, stepDown, invert, cell, cellInverted, steps }

    /// The forms an MOT-LD2-004 answer takes. The first and last answers of a song are the full
    /// cell; the others are drawn: full 35, the head alone 30, inverted around its last note 20,
    /// and the full cell with its head sequenced a step lower, up to three bars, 15.
    private enum CellForm: CaseIterable { case full, short, inverted, long }
    private static let cellFormWeights: [Double] = [0.35, 0.30, 0.20, 0.15]

    /// The whole Lead 2 part for a gap-answer rule, through HarmonicFilter. `lead1` is the Lead 1
    /// the listener hears: after ArrangementFilter, HarmonicFilter, the breakdown cut and, in a
    /// sync that includes Lead 1, the sync dropout. `blockedBars` are the breakdown windows and
    /// a Lead 1 solo, where Lead 2 stays out. Every draw here comes from a derived stream.
    static func generate(
        ruleID: String,
        lead1: [MIDIEvent],
        lead1RuleIDs: Set<String>,
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        blockedBars: Set<Int>,
        pads: [MIDIEvent],
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var r = SeededRNG(seed: rng.next() ^ 0x4741_5041_4E53_5752)   // "GAPANSWR"
        // Kosmic (KOS-LD2-002 to 004) runs the same draws in the same order with its own data, so
        // the Motorik rules are untouched.
        let kosmic = isKosmicGapRule(ruleID)
        let echoRole = ruleID == echoAnswer || ruleID == statementHarmony || ruleID == kosmicEcho
        let cellRole = ruleID == answerCell || ruleID == kosmicCell
        let echoReg = kosmic ? kosmicRegister : register
        let cellReg = kosmic ? kosmicCellRegister : cellRegister
        let velBase = kosmic ? 62 : 70
        let phrases = phraseMap(lead1)
        guard !phrases.isEmpty else { return [] }
        let totalSteps = frame.totalBars * 16
        let tonicPC = ((frame.keySemitoneValue % 12) + 12) % 12
        let bodyEnd = structure.bodySections.map(\.endBar).max() ?? frame.totalBars

        // Drawn once per song.
        let target    = [4, 5, 6][r.weightedPick([0.30, 0.40, 0.30])]   // appearances in the body
        let tailDraw  = r.nextDouble() < 0.5                    // silence after a phrase ends
        let tailSteps = kosmic ? (tailDraw ? 4 : 8) : (tailDraw ? 2 : 4)
        let echoKind  = r.weightedPick([0.45, 0.25, 0.30])      // a third, sixth or octave lower
        let harmonyOffset = r.nextInt(upperBound: 3)
        let kosmicPaired = lead1RuleIDs.sorted().compactMap { kosmicPairedCells[$0] }.first
        let cellSource = kosmic ? (kosmicPaired?.cell ?? kosmicPairCell)
            : lead1RuleIDs.sorted().compactMap { pairedCells[$0] }.first ?? descentCell
        let cell = HookLeadEngine.homage(cellSource, count: r.nextDouble() < 0.5 ? 1 : 2,
                                         weights: kosmic ? kosmicPaired?.homage : nil, rng: &r)
        // Half the songs let a middle Answer cell drop an octave now and then. Never in Kosmic.
        let octaveDropSong = r.nextDouble() < 0.50 && !kosmic
        // KOS-LD2-003 under KOS-LD1-007 Blade Runner theme answers with Lead 1's held last note.
        let bladeRunner = ruleID == kosmicCell && lead1RuleIDs.contains("KOS-LD1-007")
        // KOS-LD1-004's two-on, two-off cell: every other answer a third lower.
        let pairCell = kosmic && kosmicPaired == nil

        func scale(atBar bar: Int) -> Set<Int> {
            guard let mode = tonalMap.entry(atBar: bar)?.sectionMode else { return [] }
            return HookLeadEngine.scalePCs(mode, tonicPC: tonicPC)
        }
        func isBody(_ bar: Int) -> Bool {
            guard let label = structure.section(atBar: bar)?.label else { return false }
            return label == .A || label == .B
        }
        func isOutro(_ bar: Int) -> Bool {
            bar >= bodyEnd || structure.section(atBar: bar)?.label == .outro
        }
        /// Every bar the notes touch is free for Lead 2.
        func free(_ notes: [ANote], outro: Bool) -> Bool {
            guard let first = notes.first, let last = notes.last else { return false }
            let endStep = last.at + last.len
            guard first.at >= 0, endStep <= totalSteps else { return false }
            for bar in (first.at / 16)...((endStep - 1) / 16) {
                if blockedBars.contains(bar) { return false }
                if !(isBody(bar) || (outro && isOutro(bar))) { return false }
            }
            return true
        }
        func lift(atBar bar: Int) -> Int {
            let intensity = structure.section(atBar: bar)?.subPhaseIntensity(atBar: bar) ?? .medium
            return intensity == .low ? -6 : intensity == .high ? 5 : 0
        }

        // Shapes, in Lead 1's own steps or the cell's steps, with their source pitches.
        func shapeFromLead1(_ src: [MIDIEvent]) -> [ANote] {
            let mean = src.map { Int($0.velocity) }.reduce(0, +) / Swift.max(1, src.count)
            return src.map { ANote(at: $0.stepIndex, src: Int($0.note), len: $0.durationSteps,
                                   vel: velBase + (Int($0.velocity) - mean) / 2) }
        }
        let cellShape: [ANote] = cell.enumerated().flatMap { bi, bar in
            bar.map { ANote(at: bi * 16 + $0.step, src: $0.deg, len: $0.len, vel: $0.vel) }
        }.sorted { $0.at < $1.at }
        // The head: the first half of the cell, at least two notes, its last note held.
        let cellHead: [ANote] = {
            var h = Array(cellShape.prefix(Swift.max(2, (cellShape.count + 1) / 2)))
            if !h.isEmpty { h[h.count - 1].len = Swift.max(h[h.count - 1].len, 6) }
            return h
        }()
        // The long form: the cell, then its head a scale step lower in the next bar.
        let cellLong: [ANote] = {
            guard let last = cellShape.last else { return cellShape }
            let bars = (last.at + last.len + 15) / 16
            return cellShape + cellHead.map {
                ANote(at: $0.at + bars * 16, src: $0.src, len: $0.len, vel: $0.vel - 4, steps: -1)
            }
        }()

        // The full cell's octave, chosen once per song; every form of it plays there, so the
        // head, the long form and the inversion never jump. A song that drops an octave now and
        // then sits its cell as high as MIDI 69 allows, so the drop has room above 47.
        let cellHomeShift: Int = {
            let firstBody = structure.bodySections.map(\.startBar).min() ?? 0
            guard let mode = tonalMap.entry(atBar: firstBody)?.sectionMode else { return 0 }
            let sc = HookLeadEngine.scalePCs(mode, tonicPC: tonicPC)
            let ps = cellShape.map { HookLeadEngine.pitch(for: $0.src, base: tonicPC + 48, mode: mode, scale: sc) }
            guard let lo = ps.min(), let hi = ps.max() else { return 0 }
            if octaveDropSong, let high = stride(from: -36, through: 36, by: 12)
                .filter({ lo + $0 >= cellRegister.low && hi + $0 <= cellRegister.high }).max() {
                return high
            }
            return fitShift(ps, in: kosmic ? cellReg : register, keepIfFits: false)
        }()

        /// Places a shape after `earliest`, keeping its beat positions, and fits it to the grid.
        /// The answer ends by `limit`, at most `maxSpan` steps long; nil if it no longer fits.
        /// A Kosmic cell (`barAligned`) keeps its place in the bar, moving by whole bars, and keeps
        /// its own rhythm, which is written on the grid or, for Pulstar's riff, in native 16ths.
        func place(_ shape: [ANote], earliest: Int, limit: Int, maxSpan: Int = 32,
                   minNotes: Int = 2, barAligned: Bool = false) -> [ANote]? {
            guard let first = shape.first else { return nil }
            var d: Int
            if barAligned {
                d = ((earliest - first.at) + 15).quotientRoundingDown(by: 16) * 16
            } else {
                d = ((earliest - first.at) + 3).quotientRoundingDown(by: 4) * 4
                // A half-bar start reads more clearly, when it still fits.
                if (first.at + d) % 8 != 0,
                   let last = shape.last, last.at + d + 4 + Swift.min(last.len, 4) <= limit { d += 4 }
            }
            var notes = shape.map { ANote(at: $0.at + d, src: $0.src, len: $0.len, vel: $0.vel, steps: $0.steps) }
            if barAligned {
                notes.removeAll { $0.at >= limit }
                if !notes.isEmpty { notes[notes.count - 1].len = Swift.min(notes[notes.count - 1].len, limit - notes[notes.count - 1].at) }
            } else {
                notes = gridFit(notes, limit: limit)
            }
            notes.removeAll { $0.at < earliest }
            while notes.count > minNotes, let f = notes.first, let l = notes.last, l.at + l.len - f.at > maxSpan {
                notes.removeFirst()
            }
            guard notes.count >= minNotes, let l = notes.last, l.at + l.len <= limit,
                  let f = notes.first, l.at + l.len - f.at <= maxSpan else { return nil }
            return notes
        }

        /// Pitches for a placed answer, worked out in the bars it lands in, then fitted to the
        /// register as a block so the figure stays in one octave.
        func realise(_ notes: [ANote], _ transform: Transform, velOffset: Int = 0,
                     octaveDown: Bool = false, rng: inout SeededRNG) -> [MIDIEvent] {
            guard let first = notes.first else { return [] }
            let firstScale = scale(atBar: first.at / 16)
            let firstSrc = snap(first.src, to: firstScale)
            var pitches: [Int] = notes.map { nt in
                let sc = scale(atBar: nt.at / 16)
                switch transform {
                case .echo:
                    let p = snap(nt.src, to: sc)
                    return echoKind == 0 ? shift(p, by: -2, in: sc)
                         : echoKind == 1 ? shift(p, by: -5, in: sc) : p - 12
                case .stepDown:
                    return shift(snap(nt.src, to: sc), by: -1, in: sc)
                case .invert:
                    let d = distance(from: firstSrc, to: snap(nt.src, to: firstScale), in: firstScale)
                    return shift(firstSrc, by: -d, in: firstScale)
                case .cell, .cellInverted:
                    guard let mode = tonalMap.entry(atBar: nt.at / 16)?.sectionMode else { return tonicPC + 48 + nt.src }
                    let p = HookLeadEngine.pitch(for: nt.src, base: tonicPC + 48, mode: mode, scale: sc)
                    return shift(p, by: nt.steps, in: sc)
                case .steps:
                    return shift(snap(nt.src, to: sc), by: nt.steps, in: sc)
                }
            }
            if transform == .cellInverted, let pivot = pitches.last, let lastNote = notes.last {
                // The cell upside down around the note it resolves to, step for step in the scale,
                // so it still lands home.
                let sc = scale(atBar: lastNote.at / 16)
                pitches = pitches.map { shift(pivot, by: -distance(from: pivot, to: $0, in: sc), in: sc) }
            }
            let isCell = transform == .cell || transform == .cellInverted
            var blockShift = isCell ? cellHomeShift
                : fitShift(pitches, in: echoReg, keepIfFits: transform == .echo || transform == .steps)
            var reg = isCell ? cellReg : echoReg
            // An octave below the cell's home, only where the whole figure fits above 47.
            if octaveDown, let lo = pitches.min(), lo + blockShift - 12 >= dropRegister.low {
                blockShift -= 12
                reg = dropRegister
            }
            // An inversion that leaves the cell's register gives way to the head, in the caller.
            if transform == .cellInverted, let lo = pitches.min(), let hi = pitches.max(),
               lo + blockShift < reg.low || hi + blockShift > reg.high { return [] }
            return zip(notes, pitches).map { nt, p in
                let vel = nt.vel + velOffset + lift(atBar: nt.at / 16) + rng.nextInt(upperBound: 7) - 3
                return MIDIEvent(stepIndex: nt.at, note: UInt8(reg.fold(p + blockShift)),
                                 velocity: UInt8(Swift.max(36, Swift.min(100, vel))),
                                 durationSteps: Swift.max(1, nt.len))
            }
        }

        /// One answer in the gap after `ph`, of the rule's kind, or nil.
        func answer(after ph: Phrase, earliest: Int, limit: Int, outro: Bool,
                    form: CellForm = .full, octaveDown: Bool = false, turn: Int = 0,
                    rng: inout SeededRNG) -> [MIDIEvent]? {
            if outro || echoRole {
                guard ph.notes.count >= 2 else { return nil }
                let count = Swift.min(ph.notes.count, outro ? 2 + rng.nextInt(upperBound: 2) : 2 + rng.nextInt(upperBound: 3))
                guard kosmic else {
                    guard let placed = place(shapeFromLead1(Array(ph.notes.suffix(count))),
                                             earliest: earliest, limit: limit),
                          free(placed, outro: outro) else { return nil }
                    return realise(placed, .echo, velOffset: outro ? -8 : 0, rng: &rng)
                }
                // KOS-LD2-002 Slow echo answer: a figure that fits in a bar is played at half
                // speed, so the echo moves in long notes. Fewer notes are taken if it won't fit.
                for c in stride(from: count, through: 2, by: -1) {
                    var shape = shapeFromLead1(Array(ph.notes.suffix(c)))
                    if let f = shape.first, let l = shape.last, l.at + l.len - f.at <= 16 {
                        shape = shape.map { ANote(at: f.at + ($0.at - f.at) * 2, src: $0.src,
                                                  len: $0.len * 2, vel: $0.vel) }
                    }
                    if let placed = place(shape, earliest: earliest, limit: limit, maxSpan: 64),
                       free(placed, outro: outro) {
                        return realise(placed, .echo, velOffset: outro ? -8 : 0, rng: &rng)
                    }
                }
                return nil
            }
            if bladeRunner {
                // Lead 1's held last note, a diatonic third lower, a bar after it starts and
                // never before the phrase has ended, held for up to two bars.
                guard let last = ph.notes.last else { return nil }
                let at = ((Swift.max(earliest, last.stepIndex + 16) + 15) / 16) * 16
                let len = Swift.min(32, limit - at)
                guard len >= 8 else { return nil }
                let shape = [ANote(at: at, src: Int(last.note), len: len, vel: velBase, steps: -2)]
                guard free(shape, outro: false) else { return nil }
                return realise(shape, .steps, rng: &rng)
            }
            if ruleID == kosmicReply {
                // KOS-LD2-004 Gap reply melody: KOS-LD1-004's two held notes a step apart, from
                // the note Lead 1 ended on; every other reply a third lower, as its echo was.
                guard let last = ph.notes.last else { return nil }
                let base = turn % 2 == 1 ? -2 : 0
                let shape = [ANote(at: 0, src: Int(last.note), len: 14, vel: velBase, steps: base),
                             ANote(at: 16, src: Int(last.note), len: 14, vel: velBase - 4, steps: base + 1)]
                guard let placed = place(shape, earliest: earliest, limit: limit, minNotes: 1, barAligned: true),
                      free(placed, outro: false) else { return nil }
                return realise(placed, .steps, rng: &rng)
            }
            if ruleID == hookFragment {
                guard ph.notes.count >= 2 else { return nil }
                // 2 to 5 notes. The grid fit folds a 16th into its neighbour, so more of Lead 1's
                // notes are taken until the placed figure reaches the drawn count.
                let want = 2 + rng.weightedPick([0.25, 0.30, 0.25, 0.20])
                let transform: Transform = rng.nextDouble() < 0.5 ? .invert : .stepDown
                var best: [ANote]?
                for take in Swift.min(ph.notes.count, want)...Swift.min(ph.notes.count, want + 6) {
                    guard let p = place(shapeFromLead1(Array(ph.notes.prefix(take))),
                                        earliest: earliest, limit: limit) else { break }
                    best = p
                    if p.count >= want { break }
                }
                guard let placed = best, free(placed, outro: false) else { return nil }
                return realise(placed, transform, rng: &rng)
            }
            if cellRole {
                var shape = form == .short ? cellHead : form == .long ? cellLong : cellShape
                if pairCell && turn % 2 == 1 { shape = shape.map { var a = $0; a.steps -= 2; return a } }
                guard let placed = place(shape, earliest: earliest, limit: limit,
                                         maxSpan: form == .long ? 48 : 32,
                                         minNotes: kosmic ? 1 : 2, barAligned: kosmic),
                      free(placed, outro: false) else { return nil }
                let out = realise(placed, form == .inverted ? .cellInverted : .cell,
                                  octaveDown: octaveDown, rng: &rng)
                return out.isEmpty ? nil : out
            }
            return nil
        }

        // MOT-LD2-006: which statements are harmonised. A statement is a body phrase of three
        // notes or more; every second one, starting from the first or the second as drawn per song.
        var harmonised: Set<Int> = []
        if ruleID == statementHarmony {
            var k = 0
            for (i, ph) in phrases.enumerated() where ph.notes.count >= 3 && isBody(ph.start / 16)
                && !(ph.start / 16...(ph.end - 1) / 16).contains(where: blockedBars.contains) {
                if k % 2 == harmonyOffset % 2 { harmonised.insert(i) }
                k += 1
            }
        }
        // MOT-LD2-002: the song's target count of phrases get a bed, spread evenly over the body
        // phrases, or every one of them if there are fewer.
        var bedded: Set<Int> = []
        var events: [MIDIEvent] = []
        if ruleID == lowBed {
            let candidates = phrases.indices.filter { i in
                isBody(phrases[i].start / 16) && !blockedBars.contains(phrases[i].start / 16)
            }
            let count = Swift.min(candidates.count, target)
            for k in 0..<count {
                bedded.insert(candidates[Int((Double(k) + 0.5) * Double(candidates.count) / Double(count))])
            }
            // One or two beds on their own, in the longest Lead 1 silences of four bars or more.
            let alone = r.nextDouble() < 0.5 ? 1 : 2
            let gaps = phrases.indices.dropLast()
                .filter { phrases[$0 + 1].start - phrases[$0].end >= 64 }
                .sorted { phrases[$0 + 1].start - phrases[$0].end > phrases[$1 + 1].start - phrases[$1].end }
            var placed = 0
            for i in gaps where placed < alone {
                if let e = standaloneBed(gapStart: phrases[i].end, gapEnd: phrases[i + 1].start,
                                         tonicPC: tonicPC, tonalMap: tonalMap, blockedBars: blockedBars,
                                         isBody: isBody, rng: &r) {
                    events.append(e)
                    placed += 1
                }
            }
        }

        // Answer slots. After each phrase there is the answer that follows it; in a Lead 1 silence
        // of four bars or more there are also restatements every four bars after that.
        struct Slot { let phrase: Int; let earliest: Int; let limit: Int; let start: Int; let natural: Bool }
        var slots: [Slot] = []
        var outroUsed = false
        for (i, ph) in phrases.enumerated() {
            if harmonised.contains(i) { events += harmony(ph, scale: scale, register: harmonyRegister, rng: &r) }
            if bedded.contains(i) {
                events += bed(ph, tonicPC: tonicPC, tonalMap: tonalMap, blockedBars: blockedBars,
                              isBody: isBody, rng: &r)
            }
            if ruleID == lowBed || harmonised.contains(i) { continue }

            // The gap after this phrase: one bar or more, answered after a short tail and ending
            // at least two steps before Lead 1 returns.
            let nextStart = i + 1 < phrases.count ? phrases[i + 1].start : totalSteps
            let gap = nextStart - ph.end
            guard gap >= 16 else { continue }
            let earliest = ph.end + tailSteps
            let limit = nextStart - 2
            let earliestBar = earliest / 16
            guard earliestBar < frame.totalBars else { continue }

            // In the outro, at most one echo of the final statement, outside the count.
            if isOutro(earliestBar) {
                guard !outroUsed, i == phrases.count - 1 || phrases[i + 1].start / 16 >= bodyEnd else { continue }
                if let a = answer(after: ph, earliest: earliest, limit: limit, outro: true, rng: &r) {
                    events += a
                    outroUsed = true
                }
                continue
            }
            // Slots are tried on a copy of the stream, so trying one draws nothing.
            var probe = r
            var from = earliest
            if let a = answer(after: ph, earliest: earliest, limit: limit, outro: false, rng: &probe),
               let f = a.first, let l = a.last {
                slots.append(Slot(phrase: i, earliest: earliest, limit: limit, start: f.stepIndex, natural: true))
                from = l.stepIndex + l.durationSteps + 32
            }
            guard gap >= 64 else { continue }
            var at = ((from + 15) / 16) * 16
            while at + 16 <= limit {
                var probe2 = r
                if let a = answer(after: ph, earliest: at, limit: limit, outro: false, rng: &probe2),
                   let f = a.first {
                    slots.append(Slot(phrase: i, earliest: at, limit: limit, start: f.stepIndex, natural: false))
                }
                at += 64
            }
        }

        // The song's target of 4 to 6 appearances. The answers after phrases come first; over the
        // target, the one whose neighbours are closest goes, never the first or the last. Under
        // it, restatements fill the longest silences, two bars or more from any other answer.
        var chosen = slots.indices.filter { slots[$0].natural }
        while chosen.count > target && chosen.count > 2 {
            var best = 1
            var bestGap = Int.max
            for k in 1..<(chosen.count - 1) {
                let g = slots[chosen[k + 1]].start - slots[chosen[k - 1]].start
                if g < bestGap { bestGap = g; best = k }
            }
            chosen.remove(at: best)
        }
        func nearestChosen(_ i: Int) -> Int {
            chosen.map { abs(slots[$0].start - slots[i].start) }.min() ?? Int.max
        }
        while chosen.count < target {
            let pool = slots.indices.filter { !chosen.contains($0) && nearestChosen($0) >= 32 }
            guard let pick = pool.max(by: { nearestChosen($0) < nearestChosen($1) }) else { break }
            chosen.append(pick)
            chosen.sort { slots[$0].start < slots[$1].start }
        }

        // In an octave-drop song, a middle answer drops 40% of the time, at most twice and never
        // twice running. It only drops where the figure still fits above MIDI 47.
        var drops = 0
        var droppedLast = false
        for (k, idx) in chosen.enumerated() {
            let s = slots[idx]
            var form = CellForm.full
            var down = false
            if cellRole && k > 0 && k < chosen.count - 1 {
                form = CellForm.allCases[r.weightedPick(cellFormWeights)]
                if octaveDropSong && drops < 2 && !droppedLast && r.nextDouble() < 0.40 { down = true }
            }
            let ph = phrases[s.phrase]
            if let a = answer(after: ph, earliest: s.earliest, limit: s.limit, outro: false,
                              form: form, octaveDown: down, turn: k, rng: &r)
                ?? answer(after: ph, earliest: s.earliest, limit: s.limit, outro: false,
                          form: .short, octaveDown: down, turn: k, rng: &r) {
                events += a
            }
            if down { drops += 1 }
            droppedLast = down
        }

        // Kosmic: now and then Lead 2 joins Lead 1 for four bars, a third under it (65%) or in
        // unison (35%), drawn per window (Zack, 2026-11-10). Two windows a song, one more when
        // Lead 1 left room for under four answers, and one more when Lead 1 plays through more
        // than 60% of the body, as KOS-LD1-006 does. A song whose Lead 2 would still have under
        // 24 notes, under a Lead 1 of long notes, takes more, up to six. Windows sit on a four-bar
        // grid from the body's start, where Lead 1 has two or more 8th-grid onsets and Lead 2 is
        // silent, and are spread evenly over the candidates. Drawn last, so no earlier draw moves.
        if kosmic {
            let bodyBars = (0..<frame.totalBars).filter { isBody($0) && !blockedBars.contains($0) }
            let lead1Bars = Set(lead1.map { $0.stepIndex / 16 })
            let coverage = Double(bodyBars.filter(lead1Bars.contains).count) / Double(Swift.max(1, bodyBars.count))
            var windowCount = 2
            if chosen.count < 4 { windowCount += 1 }
            if coverage > 0.60 { windowCount += 1 }
            let lead2Bars = Set(events.flatMap { e in (e.stepIndex / 16)...((e.stepIndex + Swift.max(1, e.durationSteps) - 1) / 16) })
            let bodySet = Set(bodyBars)
            let firstBody = bodyBars.first ?? 0
            var candidates: [Int] = []
            var onsetCount: [Int: Int] = [:]
            for start in stride(from: firstBody, to: frame.totalBars - 3, by: 4) {
                let bars = start..<(start + 4)
                guard bars.allSatisfy({ bodySet.contains($0) && !lead2Bars.contains($0) }) else { continue }
                let onsets = lead1.filter { bars.contains($0.stepIndex / 16) && $0.stepIndex % 2 == 0 }
                if onsets.count >= 2 { candidates.append(start); onsetCount[start] = onsets.count }
            }
            func spread(_ c: Int) -> [Int] {
                (0..<c).map { candidates[Int((Double($0) + 0.5) * Double(candidates.count) / Double(c))] }
            }
            var count = Swift.min(windowCount, candidates.count)
            while count < Swift.min(6, candidates.count),
                  events.count + spread(count).reduce(0, { $0 + (onsetCount[$1] ?? 0) }) < 24 {
                count += 1
            }
            for start in spread(count) {
                let lo = start * 16, hi = (start + 4) * 16
                let src = lead1.filter { $0.stepIndex >= lo && $0.stepIndex < hi }
                    .sorted { $0.stepIndex != $1.stepIndex ? $0.stepIndex < $1.stepIndex : $0.note > $1.note }
                var notes: [MIDIEvent] = []
                for e in src where notes.last?.stepIndex != e.stepIndex { notes.append(e) }
                guard let f = notes.first, let l = notes.last else { continue }
                let ph = Phrase(notes: notes, start: f.stepIndex, end: Swift.min(hi, l.stepIndex + l.durationSteps))
                let steps = r.nextDouble() < 0.65 ? -2 : 0
                events += harmony(ph, scale: scale, register: kosmicHarmonyRegister, steps: steps, rng: &r)
            }
        }

        events.sort { $0.stepIndex < $1.stepIndex }
        // One octave decision for the whole part, as the Lead 1 hooks get. Lifting answer by
        // answer put one echo above Lead 1 and its repeat two bars later a sixth below it. The
        // bed is bounded by its own ceiling, so it is never lifted out of 50 to 60.
        return HarmonicFilter.filterLead(events, track: kTrackLead2, pads: pads,
                                         frame: frame, structure: structure,
                                         bounds: kosmic ? (cellRole ? kosmicCellRegister : kosmicRegister)
                                             : ruleID == lowBed ? bedRegister : register,
                                         uniformLift: true)
    }

    // MARK: - Harmony and bed

    /// MOT-LD2-006: a whole Lead 1 statement a diatonic third below, in Lead 1's rhythm. Only Lead
    /// 1's 8th-grid onsets are harmonised; each harmony note holds through any 16th in between.
    private static func harmony(_ ph: Phrase, scale: (Int) -> Set<Int>, register: RegisterBounds,
                                steps: Int = -2, rng: inout SeededRNG) -> [MIDIEvent] {
        let src = ph.notes.filter { $0.stepIndex % 2 == 0 }
        guard src.count >= 2 else { return [] }
        let mean = src.map { Int($0.velocity) }.reduce(0, +) / src.count
        let pitches = src.map { e -> Int in
            let sc = scale(e.stepIndex / 16)
            return shift(snap(Int(e.note), to: sc), by: steps, in: sc)
        }
        let blockShift = fitShift(pitches, in: register, keepIfFits: true)
        return src.indices.map { i in
            let e = src[i]
            let nextAt = i + 1 < src.count ? src[i + 1].stepIndex : ph.end
            let vel = 62 + (Int(e.velocity) - mean) / 2 + rng.nextInt(upperBound: 5) - 2
            return MIDIEvent(stepIndex: e.stepIndex, note: UInt8(register.fold(pitches[i] + blockShift)),
                             velocity: UInt8(Swift.max(36, Swift.min(96, vel))),
                             durationSteps: Swift.max(1, Swift.min(nextAt, ph.end) - e.stepIndex))
        }
    }

    /// A Lead 1 note this long or longer gets a bed under it.
    private static let bedMinLength = 4

    /// MOT-LD2-002: the chord's root or fifth held under each of Lead 1's long notes in a phrase,
    /// and in each bar without one, MIDI 50 to 60, starting on a beat. A bed on the same pitch as
    /// the one before it carries on as one held note, up to a bar.
    private static func bed(_ ph: Phrase, tonicPC: Int, tonalMap: TonalGovernanceMap,
                            blockedBars: Set<Int>, isBody: (Int) -> Bool,
                            rng: inout SeededRNG) -> [MIDIEvent] {
        // Where the bed sounds: under each long note, and in any bar of the phrase with no long
        // note, from its first beat for up to half a bar, so a riff of short notes still gets one.
        var spans: [(at: Int, end: Int)] = []
        for e in ph.notes where e.durationSteps >= bedMinLength {
            var at = e.stepIndex
            if at % 2 != 0 { at += 1 }
            if at % 4 != 0 { at += 2 }
            spans.append((at, e.stepIndex + e.durationSteps))
        }
        for bar in (ph.start / 16)...((ph.end - 1) / 16) {
            let lo = bar * 16, hi = lo + 16
            guard !spans.contains(where: { $0.at < hi && $0.end > lo }) else { continue }
            let at = ((Swift.max(ph.start, lo) + 3) / 4) * 4
            spans.append((at, Swift.min(at + 8, ph.end)))
        }
        spans.sort { $0.at < $1.at }
        var out: [MIDIEvent] = []
        for (at, end) in spans {
            let len = Swift.min(end - at, 16)
            let bar = at / 16
            guard len >= 4, isBody(bar), !blockedBars.contains(bar),
                  let window = tonalMap.entry(atBar: bar)?.chordWindow else { continue }
            if let last = out.last, last.stepIndex + last.durationSteps > at { continue }
            let rootPC = (tonicPC + degreeSemitone(window.chordRoot)) % 12
            guard let pitch = bedPitch(rootPC: rootPC, rng: &rng) else { continue }
            let note = UInt8(pitch)
            if let last = out.last, last.note == note, last.stepIndex + last.durationSteps >= at - 2,
               at + len - last.stepIndex <= 16 {
                out[out.count - 1] = MIDIEvent(stepIndex: last.stepIndex, note: note, velocity: last.velocity,
                                               durationSteps: at + len - last.stepIndex)
                continue
            }
            out.append(MIDIEvent(stepIndex: at, note: note,
                                 velocity: UInt8(54 + rng.nextInt(upperBound: 7)), durationSteps: len))
        }
        return out
    }

    /// The bed's pitch: the chord's root 60% of the time, otherwise its fifth, near the middle of
    /// 50 to 60. The other chord tone stands in when this one has no octave there or only a low one.
    private static func bedPitch(rootPC: Int, rng: inout SeededRNG) -> Int? {
        let fifthPC = (rootPC + 7) % 12
        let pick = rng.nextDouble() < 0.60
        var choice = nearest(pick ? rootPC : fifthPC, to: 57, in: bedRegister)
        let other = nearest(pick ? fifthPC : rootPC, to: 57, in: bedRegister)
        if choice == nil || (choice! < 56 && (other ?? 0) >= 56) { choice = other }
        return choice
    }

    /// MOT-LD2-002 on its own: the chord's root or fifth held for one or two bars in a long Lead 1
    /// silence, with no Lead 1 above it. It starts on a bar line at least a bar after the phrase
    /// before it ends and finishes half a bar before Lead 1 returns. Two bars only if the chord
    /// stays the same; nil if the gap can't hold it or isn't all body.
    private static func standaloneBed(gapStart: Int, gapEnd: Int, tonicPC: Int,
                                      tonalMap: TonalGovernanceMap, blockedBars: Set<Int>,
                                      isBody: (Int) -> Bool, rng: inout SeededRNG) -> MIDIEvent? {
        let at = ((gapStart + 15) / 16) * 16 + 16
        var len = rng.nextDouble() < 0.5 ? 16 : 32
        let velocity = 56 + rng.nextInt(upperBound: 7)
        while len >= 16 && at + len > gapEnd - 8 { len -= 16 }
        guard len >= 16, let window = tonalMap.entry(atBar: at / 16)?.chordWindow else { return nil }
        if len > 16, let next = tonalMap.entry(atBar: at / 16 + 1)?.chordWindow,
           next.chordRoot != window.chordRoot { len = 16 }
        guard (at / 16...(at + len - 1) / 16).allSatisfy({ isBody($0) && !blockedBars.contains($0) }) else { return nil }
        let rootPC = (tonicPC + degreeSemitone(window.chordRoot)) % 12
        guard let pitch = bedPitch(rootPC: rootPC, rng: &rng) else { return nil }
        return MIDIEvent(stepIndex: at, note: UInt8(pitch), velocity: UInt8(velocity), durationSteps: len)
    }

    // MARK: - Grid and pitch helpers

    /// Puts every onset on the 8th grid and every held note on a beat. Notes hold to the next
    /// onset within an 8-step gap, as the Lead 1 hooks do; the last keeps its own length, up to
    /// `limit`.
    private static func gridFit(_ input: [ANote], limit: Int) -> [ANote] {
        var out: [ANote] = []
        for var nt in input.sorted(by: { $0.at < $1.at }) {
            if nt.at % 2 != 0 {
                if out.last.map({ $0.at < nt.at - 1 }) ?? true { nt.at -= 1 } else { nt.at += 1 }
            }
            if let l = out.last, l.at >= nt.at { continue }
            out.append(nt)
        }
        for i in out.indices {
            if i + 1 < out.count {
                let gap = out[i + 1].at - out[i].at
                out[i].len = gap <= 8 ? gap : Swift.min(Swift.max(out[i].len, 2), gap)
            } else {
                out[i].len = Swift.min(out[i].len, limit - out[i].at)
            }
        }
        out.removeAll { $0.len < 1 }
        for i in out.indices where out[i].len >= 4 && out[i].at % 4 != 0 {
            if i == out.count - 1 && out[i].len >= 6 {
                // The last note moves onto the next beat and still rings.
                out[i].at += 2
                out[i].len -= 2
            } else {
                out[i].len = 2
            }
        }
        return out
    }

    /// The octave shift that fits a figure in `reg`: none if `keepIfFits` and it already fits,
    /// otherwise the fitting shift nearest `toward`, or the register's middle. A figure wider than
    /// the register keeps its top note inside and folds the rest.
    private static func fitShift(_ pitches: [Int], in reg: RegisterBounds, keepIfFits: Bool,
                                 toward: Double? = nil) -> Int {
        guard let lo = pitches.min(), let hi = pitches.max() else { return 0 }
        let shifts = stride(from: -36, through: 36, by: 12).map { $0 }
        let fits = shifts.filter { lo + $0 >= reg.low && hi + $0 <= reg.high }
        if keepIfFits && fits.contains(0) { return 0 }
        let middle = toward ?? Double(reg.low + reg.high) / 2
        if let best = fits.min(by: {
            abs(Double(lo + hi) / 2 + Double($0) - middle) < abs(Double(lo + hi) / 2 + Double($1) - middle)
        }) { return best }
        return shifts.filter { hi + $0 <= reg.high }.max() ?? 0
    }

    private static func nearest(_ pc: Int, to target: Int, in reg: RegisterBounds) -> Int? {
        (reg.low...reg.high).filter { (($0 % 12) + 12) % 12 == pc }
            .min(by: { abs($0 - target) < abs($1 - target) })
    }

    private static func snap(_ pitch: Int, to scale: Set<Int>) -> Int {
        let pc = ((pitch % 12) + 12) % 12
        if scale.isEmpty || scale.contains(pc) { return pitch }
        for d in 1...6 {
            if scale.contains((pc - d + 12) % 12) { return pitch - d }
            if scale.contains((pc + d) % 12) { return pitch + d }
        }
        return pitch
    }

    private static func shift(_ pitch: Int, by steps: Int, in scale: Set<Int>) -> Int {
        HookLeadEngine.scaleShift(pitch, by: steps, in: scale)
    }

    /// Scale steps from `a` up to `b`, negative when `b` is lower. Both are scale pitches.
    private static func distance(from a: Int, to b: Int, in scale: Set<Int>) -> Int {
        guard a != b, !scale.isEmpty else { return 0 }
        let dir = b > a ? 1 : -1
        var count = 0
        var p = a
        while p != b {
            p += dir
            if scale.contains(((p % 12) + 12) % 12) { count += dir }
        }
        return count
    }
}

private extension Int {
    /// Floor division for a positive divisor.
    func quotientRoundingDown(by d: Int) -> Int {
        self >= 0 ? self / d : -((-self + d - 1) / d)
    }
}
