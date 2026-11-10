// HookLeadEngine.swift — transcription-based hook rules for base Motorik and base Kosmic Lead 1
// Copyright (c) 2026 Zack Urlocker
//
// Each rule is a short phrase taken from a real piece: a call, an answer, a few variants from the
// same source and an optional tail. The engine states the phrase, varies it on return and plays it
// plain once more near the end, so the lead has a hook you could hum. All rules share this engine
// and differ only in data. See docs/Solo-improvement-plan.md, "Build spec".
//
// MOT-LD1-023 Hallogallo hook — Neu!, Hallogallo (1972), Michael Rother's Guitar 2 riff.

/// One note of a hook cell. `step` is 0–15 within its bar, `deg` is semitones from the song
/// tonic (14 is the ninth an octave up), `len` is the gate in steps.
struct HookNote: Sendable {
    let step: Int
    let deg: Int
    let len: Int
    let vel: Int
}

typealias HookBar = [HookNote]

/// A replacement for the call or the answer, taken from the same source.
struct HookSourceVariant: Sendable {
    let call: [HookBar]?
    let answer: [HookBar]?
}

struct HookRule: Sendable {
    let id: String
    let call: [HookBar]
    let answer: [HookBar]
    let sourceVariants: [HookSourceVariant]
    /// Filler for the bar after a statement, so the reply isn't always another hook.
    let tail: HookBar?
    /// Statement starts, in bars from the previous start, and their weights (sum to 1).
    let spacings: [Int]
    let spacingWeights: [Double]
}

enum HookLeadEngine {

    // MARK: - Rule data

    /// Built from Claude's sketch (`hallogallo-lead1-sketch.mid`, approved by Zack 2026-11-10), not
    /// the literal tab. The tab's Guitar 2 riff is A3 B3 F#4 F#4, then A3 B3 E4 E4: degrees 4 5 9 9
    /// answered by 4 5 1 1, the call ending open on the ninth and the answer ending home.
    static let hallogallo = HookRule(
        id: "MOT-LD1-023",
        call:   [[HookNote(step: 0, deg: 5, len: 2, vel: 84), HookNote(step: 2, deg: 7, len: 2, vel: 80),
                  HookNote(step: 4, deg: 14, len: 3, vel: 88), HookNote(step: 7, deg: 14, len: 8, vel: 82)]],
        answer: [[HookNote(step: 0, deg: 5, len: 2, vel: 84), HookNote(step: 2, deg: 7, len: 2, vel: 80),
                  HookNote(step: 4, deg: 12, len: 3, vel: 88), HookNote(step: 7, deg: 12, len: 8, vel: 82)]],
        sourceVariants: [
            // The answer ends on the fifth, so not every statement resolves.
            HookSourceVariant(call: nil, answer: [[
                HookNote(step: 0, deg: 5, len: 2, vel: 84), HookNote(step: 2, deg: 7, len: 2, vel: 80),
                HookNote(step: 4, deg: 7, len: 3, vel: 88), HookNote(step: 7, deg: 7, len: 8, vel: 82)]]),
        ],
        // From the tab's riff 1 variation: the flat seventh as a grace into the root, in soft 8ths.
        tail: [HookNote(step: 0, deg: 10, len: 2, vel: 60), HookNote(step: 2, deg: 12, len: 2, vel: 66),
               HookNote(step: 4, deg: 12, len: 2, vel: 58), HookNote(step: 8, deg: 10, len: 2, vel: 58),
               HookNote(step: 10, deg: 12, len: 2, vel: 64), HookNote(step: 12, deg: 12, len: 2, vel: 56)],
        spacings: [8, 4, 12],
        spacingWeights: [0.60, 0.20, 0.20]
    )

    static let motorikRules: [String: HookRule] = [hallogallo.id: hallogallo]

    static func isMotorikHookRule(_ id: String) -> Bool { motorikRules[id] != nil }

    // MARK: - Statement

    private enum Variation: CaseIterable { case dropNote, push, stepUp, holdOver, withhold }
    // Drop a note 30, push one 16th late 25, call a step up as a sequence 20, hold the last note
    // over the next bar 15, withhold the answer 10.
    private static let variationWeights: [Double] = [0.30, 0.25, 0.20, 0.15, 0.10]

    private struct Statement {
        var startBar: Int
        var bars: [HookBar]
        var callCount: Int
        /// Scale steps applied to the whole statement (B sections).
        var shift = 0
        /// Bar indices moved one further scale step (the call-a-step-up sequence).
        var stepUpBars: Set<Int> = []
        var push = 0
        var velOffset = 0
        var ringSteps = 0
        /// Bars the statement occupies, counting a held last note that rings into the next bar.
        var spanBars: Int { bars.count + (ringSteps > 0 ? 1 : 0) }
        var endBar: Int { startBar + spanBars }
    }

    // MARK: - Generation

    /// Generates the whole Lead 1 part for a hook rule. The caller has already drawn the entry
    /// bar and the rest windows, so those keep their place in the Lead 1 stream; every draw made
    /// here comes from a derived stream.
    static func generate(
        rule: HookRule,
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        entryBar: Int,
        restBars: Set<Int>,
        register: RegisterBounds,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var r = SeededRNG(seed: rng.next() ^ 0x484F_4F4B_4C45_4144)   // "HOOKLEAD"
        let tonicPC = ((frame.keySemitoneValue % 12) + 12) % 12
        guard let bodyEnd = structure.bodySections.map(\.endBar).max() else { return [] }

        let plain: [HookBar] = rule.call + rule.answer
        let base = anchorTonic(rule: rule, tonicPC: tonicPC, register: register)

        func isBody(_ bar: Int) -> Bool {
            guard let label = structure.section(atBar: bar)?.label else { return false }
            return label == .A || label == .B
        }
        func isFree(_ bar: Int) -> Bool {
            bar >= entryBar && bar < bodyEnd && isBody(bar) && !restBars.contains(bar)
        }

        // B sections restate the hook a scale step or a third up, or lean on the variants.
        let bRoll  = r.nextDouble()
        let bShift = bRoll < 0.40 ? 1 : bRoll < 0.70 ? 2 : 0

        func vary(_ st: inout Statement, moreVariants: Bool) {
            // One varied statement in five returns to form instead.
            if !moreVariants && r.nextDouble() < 0.20 { return }
            let count = r.nextDouble() < 0.30 ? 2 : 1
            var kinds: [Variation] = []
            var usedSource = false
            for _ in 0..<count {
                if !rule.sourceVariants.isEmpty && !usedSource
                    && r.nextDouble() < (moreVariants ? 0.70 : 0.50) {
                    usedSource = true
                    let v = rule.sourceVariants[r.nextInt(upperBound: rule.sourceVariants.count)]
                    if let call = v.call { st.bars.replaceSubrange(0..<st.callCount, with: call); st.callCount = call.count }
                    if let answer = v.answer { st.bars = Array(st.bars.prefix(st.callCount)) + answer }
                    continue
                }
                let k = Variation.allCases[r.weightedPick(variationWeights)]
                if !kinds.contains(k) { kinds.append(k) }
            }
            if kinds.contains(.stepUp) {
                let calls = Array(st.bars.prefix(st.callCount))
                st.bars.insert(contentsOf: calls, at: st.callCount)
                for i in st.callCount..<(st.callCount * 2) { st.stepUpBars.insert(i) }
                st.callCount *= 2
            }
            // Withholding the answer leaves the question open; pointless if a variant just
            // rewrote that answer.
            if kinds.contains(.withhold) && !usedSource && st.bars.count > st.callCount {
                st.bars = Array(st.bars.prefix(st.callCount))
            }
            if kinds.contains(.dropNote) {
                // Never the first note or the held last note of a bar.
                let candidates = (0..<st.callCount).filter { st.bars[$0].count >= 3 }
                if !candidates.isEmpty {
                    let b = candidates[r.nextInt(upperBound: candidates.count)]
                    st.bars[b].remove(at: 1 + r.nextInt(upperBound: st.bars[b].count - 2))
                }
            }
            if kinds.contains(.push) { st.push = 1 }
            if kinds.contains(.holdOver) { st.ringSteps = 16 }
        }

        // Lay out the body statements.
        var statements: [Statement] = []
        var bar = entryBar
        while bar < bodyEnd {
            var st = Statement(startBar: bar, bars: plain, callCount: rule.call.count)
            let inB = structure.section(atBar: bar)?.label == .B
            // The first two statements are always plain, so the hook is learned before it moves.
            if statements.count >= 2 { vary(&st, moreVariants: inB && bShift == 0) }
            if inB { st.shift = bShift }
            guard (st.startBar..<st.endBar).allSatisfy(isFree) else {
                bar += 2      // stay on the two-bar grid from the entry
                continue
            }
            statements.append(st)
            let spacing = rule.spacings[r.weightedPick(rule.spacingWeights)]
            bar = Swift.max(bar + spacing, st.endBar + 1)
        }

        // The last fifth of the song plays the plain hook once, with its last note ringing on.
        let lateStart = Swift.max(entryBar, frame.totalBars * 4 / 5)
        let plainLen  = plain.count
        if statements.last.map({ $0.startBar < lateStart }) ?? true {
            var at = Swift.max(lateStart, statements.last?.endBar ?? entryBar)
            if (at - entryBar) % 2 != 0 { at += 1 }
            if at + plainLen <= bodyEnd {
                statements.append(Statement(startBar: at, bars: plain, callCount: rule.call.count))
            }
        }
        if let i = statements.indices.last {
            var final = Statement(startBar: statements[i].startBar, bars: plain, callCount: rule.call.count)
            let next = final.startBar + plainLen
            // Ring through the following bar when nothing else wants it.
            if next < frame.totalBars && (next >= bodyEnd || isFree(next)) { final.ringSteps = 16 }
            statements[i] = final
        }

        // Outro: at most one soft plain statement.
        var outroStatement: Statement? = nil
        if let outro = structure.outroSection, outro.lengthBars >= plainLen + 1, r.nextDouble() < 0.40 {
            var st = Statement(startBar: outro.startBar, bars: plain, callCount: rule.call.count)
            st.velOffset = -18
            if let last = statements.last, last.endBar > st.startBar { statements[statements.count - 1].ringSteps = 0 }
            outroStatement = st
        }

        var events: [MIDIEvent] = []
        for (i, st) in statements.enumerated() {
            events += realise(st, base: base, tonicPC: tonicPC, frame: frame, structure: structure,
                              tonalMap: tonalMap, register: register, rng: &r)
            // The bar after a statement: silence, or about three times in ten the tail.
            guard let tail = rule.tail else { continue }
            let tailBar = st.endBar
            let nextStart = i + 1 < statements.count ? statements[i + 1].startBar : bodyEnd
            if i + 1 < statements.count, tailBar < nextStart, isFree(tailBar), r.nextDouble() < 0.30 {
                let t = Statement(startBar: tailBar, bars: [tail], callCount: 1)
                events += realise(t, base: base, tonicPC: tonicPC, frame: frame, structure: structure,
                                  tonalMap: tonalMap, register: register, legato: false, rng: &r)
            }
        }
        if let st = outroStatement {
            events += realise(st, base: base, tonicPC: tonicPC, frame: frame, structure: structure,
                              tonalMap: tonalMap, register: register, rng: &r)
        }
        return events.filter { $0.stepIndex < frame.totalBars * 16 }
    }

    // MARK: - Fitting

    /// The MIDI note of the song tonic that the hook is built on, chosen once per song so the
    /// figure stays in one octave. Three semitones of headroom cover a step-up or a third-up.
    private static func anchorTonic(rule: HookRule, tonicPC: Int, register: RegisterBounds) -> Int {
        var degs = (rule.call + rule.answer).flatMap { $0 }.map(\.deg)
        degs += (rule.tail ?? []).map(\.deg)
        for v in rule.sourceVariants { degs += ((v.call ?? []) + (v.answer ?? [])).flatMap { $0 }.map(\.deg) }
        let lo = degs.min() ?? 0, hi = (degs.max() ?? 0) + 3
        let target = Double(register.low + register.high) / 2 - 2      // a little below the middle
        let candidates = stride(from: tonicPC, through: 127, by: 12)
            .filter { $0 + lo >= register.low && $0 + hi <= register.high }
        if let best = candidates.min(by: {
            abs(Double($0) + Double(lo + hi) / 2 - target) < abs(Double($1) + Double(lo + hi) / 2 - target)
        }) { return best }
        var t = tonicPC
        while t + lo < register.low { t += 12 }
        return t
    }

    private static func scalePCs(_ entry: TonalGovernanceEntry, tonicPC: Int) -> Set<Int> {
        Set(entry.sectionMode.intervals.map { (tonicPC + $0) % 12 })
    }

    /// The nearest scale pitch to `pitch`; a tie goes up, so a flat seventh becomes the leading
    /// tone in Ionian and a minor third becomes the major third.
    private static func snap(_ pitch: Int, to scale: Set<Int>) -> Int {
        let pc = ((pitch % 12) + 12) % 12
        if scale.isEmpty || scale.contains(pc) { return pitch }
        for d in 1...6 {
            if scale.contains((pc + d) % 12) { return pitch + d }
            if scale.contains((pc - d + 12) % 12) { return pitch - d }
        }
        return pitch
    }

    /// Moves a scale pitch by `steps` scale steps.
    private static func scaleShift(_ pitch: Int, by steps: Int, in scale: Set<Int>) -> Int {
        guard !scale.isEmpty, steps != 0 else { return pitch }
        var p = pitch
        for _ in 0..<abs(steps) {
            repeat { p += steps > 0 ? 1 : -1 } while !scale.contains(((p % 12) + 12) % 12)
        }
        return p
    }

    private static func realise(
        _ st: Statement, base: Int, tonicPC: Int,
        frame: GlobalMusicalFrame, structure: SongStructure, tonalMap: TonalGovernanceMap,
        register: RegisterBounds, legato: Bool = true, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        struct Placed { var step: Int; var pitch: Int; var len: Int; var vel: Int; let bar: Int }
        var notes: [Placed] = []
        for (bi, barNotes) in st.bars.enumerated() {
            let barIdx = st.startBar + bi
            guard let entry = tonalMap.entry(atBar: barIdx) else { continue }
            let scale = scalePCs(entry, tonicPC: tonicPC)
            let shift = st.shift + (st.stepUpBars.contains(bi) ? 1 : 0)
            for n in barNotes {
                let p = scaleShift(snap(base + n.deg, to: scale), by: shift, in: scale)
                notes.append(Placed(step: barIdx * 16 + n.step + st.push, pitch: p,
                                    len: n.len, vel: n.vel, bar: barIdx))
            }
        }
        guard !notes.isEmpty else { return [] }
        notes.sort { $0.step < $1.step }

        // Hold each note to the next onset inside a phrase; short transcribed notes sound
        // clunky on synth leads. The last note keeps its own length, plus any ring.
        for i in notes.indices {
            if i + 1 < notes.count {
                let gap = notes[i + 1].step - notes[i].step
                if legato && gap <= 8 { notes[i].len = gap } else { notes[i].len = Swift.min(notes[i].len, gap) }
            } else {
                notes[i].len += st.ringSteps
            }
        }

        // A held note that is an avoid tone over the current chord moves to the nearest chord
        // tone. Passing notes keep their pitch.
        for i in notes.indices where notes[i].len >= 4 {
            guard let window = tonalMap.entry(atBar: notes[i].bar)?.chordWindow else { continue }
            let pc = ((notes[i].pitch % 12) + 12) % 12
            guard window.avoidTones.contains(pc), !window.chordTones.isEmpty else { continue }
            let target = nearestScalePitchClass(pc, in: window.chordTones)
            notes[i].pitch += ((target - pc) + 18) % 12 - 6
        }

        // Keep the whole statement in one octave band: move it as a block first, and fold a
        // single note only if the block can't fit.
        let lo = notes.map(\.pitch).min()!, hi = notes.map(\.pitch).max()!
        var blockShift = 0
        if hi > register.high && lo - 12 >= register.low { blockShift = -12 }
        else if lo < register.low && hi + 12 <= register.high { blockShift = 12 }

        return notes.map { n in
            let pitch = register.fold(n.pitch + blockShift)
            let intensity = structure.section(atBar: n.bar)?.subPhaseIntensity(atBar: n.bar) ?? .medium
            let lift = intensity == .low ? -6 : intensity == .high ? 5 : 0
            let vel = n.vel + st.velOffset + lift + rng.nextInt(upperBound: 7) - 3
            return MIDIEvent(stepIndex: n.step, note: UInt8(pitch),
                             velocity: UInt8(Swift.max(30, Swift.min(120, vel))),
                             durationSteps: Swift.max(1, n.len))
        }
    }
}
