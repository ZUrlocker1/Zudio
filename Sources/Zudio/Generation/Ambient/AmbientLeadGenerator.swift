// AmbientLeadGenerator.swift — Lead 1 and Lead 2 generators for Ambient style
// Copyright (c) 2026 Zack Urlocker
// Lead 1 rules: silence (20%), AMB-LEAD-001 floating tone (15%),
//               AMB-LEAD-002 echo phrase (15%), AMB-LEAD-003 pentatonic shimmer (15%),
//               AMB-LEAD-007 lyric fragment (9%), AMB-LEAD-008 returning motif (10%),
//               AMB-LEAD-009 Magnetik solo (9%), AMB-LEAD-010 Oxygenerator solo (7%)
// AMB-LEAD-009 and AMB-LEAD-010 are section-level solos: they bypass the loop tiler and
// return full-song events (require structure != nil; degrade gracefully to silence if absent).
// Lead 2: AMB-LEAD-005 (sparse tonal cell, pitch classes derived from Lead 1's actual notes),
//          AMB-LEAD-006 (descending phrase, 3–5 diatonic scale tones descending stepwise,
//                        held 10–18 steps each, placed once per co-prime loop).
//          50/50 rule selection; both loops tile at Lead 2's co-prime loop length.
// AMB-RULE-02 enforced: rest ≥ 2× note duration after each note event.
// Generates a short loop; AmbientLoopTiler tiles to full song length.

import Foundation

/// Where Koln Winter Arc (AMB-PNO-003) puts its climax, withdrawal, close and minor peaks.
/// Drawn from the frame alone, so the lead generator and the log's arc markers agree without
/// sharing an RNG, and no other draw in the song moves (Zack, 2026-11-24: the climax moves,
/// and some songs have two smaller peaks).
struct KolnArc {
    let climaxBar: Int
    let withdrawBar: Int
    let closingBar: Int
    /// 0 or 2 minor peaks, in bar order: before the climax, or one each side of it.
    let peakBars: [Int]
    /// The vamp section's bars, if the song has one (never in Evolve passes or songs under 40 bars).
    var vampBars: Range<Int>? = nil

    /// `variation`: 0 for a new song; a Lead 1 regen passes its track seed, which redraws the
    /// vamp (only the vamp: the climax and peaks stay where the song has them).
    static func draw(frame: GlobalMusicalFrame, totalBars: Int, isEvolvePass: Bool = false,
                     variation: UInt64 = 0) -> KolnArc {
        // FNV-1a over the frame's fields: String.hashValue is salted per launch.
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in "\(frame.key)|\(frame.mode.rawValue)|\(frame.mood.rawValue)|\(frame.tempo)|\(totalBars)".utf8 {
            h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01b3
        }
        var rng = SeededRNG(seed: h ^ 0x4B01_A2C0_0003_0001)
        // Evolve passes are 16 bars: keep the old fixed proportions.
        guard !isEvolvePass, totalBars >= 40 else {
            return KolnArc(climaxBar: totalBars * 60 / 100, withdrawBar: totalBars * 73 / 100,
                           closingBar: totalBars * 87 / 100, peakBars: [])
        }
        // Climax anywhere from 45 to 70 percent; the close stays 85-89 percent; the withdrawal
        // falls a little under halfway between, at least 8 percent after the climax.
        let climaxPct  = 45 + rng.nextInt(upperBound: 26)
        let closingPct = 85 + rng.nextInt(upperBound: 5)
        let withdrawPct = climaxPct + Swift.max(8, (closingPct - climaxPct) * 45 / 100)
        let climaxBar   = totalBars * climaxPct / 100
        let withdrawBar = totalBars * withdrawPct / 100
        let closingBar  = totalBars * closingPct / 100
        // Two smaller peaks in 35 percent of songs long enough to hold them. An early climax
        // leaves room after it, so one peak goes each side; a late one gets both before it.
        var peaks: [Int] = []
        if totalBars >= 56 && rng.nextDouble() < 0.35 {
            let firstLo = totalBars * 20 / 100
            if climaxPct <= 55 {
                let a = firstLo + rng.nextInt(upperBound: Swift.max(1, climaxBar - 10 - firstLo))
                let bLo = climaxBar + 8, bHi = withdrawBar - 3
                if a < climaxBar - 8 && bHi > bLo {
                    peaks = [a, bLo + rng.nextInt(upperBound: bHi - bLo)]
                } else if bHi <= bLo && withdrawBar + 6 < closingBar - 4 {
                    // Short gap before the withdrawal: the second peak rises from the decay instead.
                    peaks = [a, withdrawBar + 6 + rng.nextInt(upperBound: Swift.max(1, closingBar - 4 - withdrawBar - 6))]
                }
            } else {
                let span = climaxBar - 8 - firstLo
                if span >= 14 {
                    let a = firstLo + rng.nextInt(upperBound: span / 3)
                    let b = firstLo + span * 55 / 100 + rng.nextInt(upperBound: Swift.max(1, span * 45 / 100))
                    if b - a >= 8 { peaks = [a, b] }
                }
            }
        }
        // Vamp (after Koln Part IIa, Zack 2026-11-24): in about 35 percent of songs, 6 to 14 bars
        // of rocking left hand over a pedal, ending where the urgent question starts (4 bars before
        // the climax), clear of the minor peaks' bars. Drawn after everything above, so no other
        // position moves.
        var vamp: Range<Int>? = nil
        // A regen draws the vamp on a stream of its own, so each regen can get one (Zack, 2026-11-24).
        if variation != 0 { rng = SeededRNG(seed: h ^ variation ^ 0x7A3F_0003_5EED_0002) }
        if rng.nextDouble() < 0.50 {   // about 35% of songs once the ones it doesn't fit drop out
            let end = climaxBar - 4
            // The drawn length first, then shorter ones if it doesn't fit
            // 6 to 14 bars in 2-bar steps, skewed short (Zack, 2026-11-25, 16 dropped): 6 27%,
            // 8 30%, 10 20%, 12 15%, 14 8%. The drawn length first, then shorter ones if it doesn't fit.
            let lens = [6, 8, 10, 12, 14]
            let roll = rng.nextInt(upperBound: 100)
            let drawn = roll < 27 ? 0 : roll < 57 ? 1 : roll < 77 ? 2 : roll < 92 ? 3 : 4
            for len in lens[...drawn].reversed() where vamp == nil {
                let start = end - len
                guard start >= 10 else { continue }
                let clear = peaks.allSatisfy { pb in ((pb - 3)...(pb + 6)).allSatisfy { !(start..<end).contains($0) } }
                if clear { vamp = start..<end }
            }
        }
        return KolnArc(climaxBar: climaxBar, withdrawBar: withdrawBar, closingBar: closingBar,
                       peakBars: peaks, vampBars: vamp)
    }
}

/// Collects the steps where Koln's high-note reach sounds, so the generation log can name them.
final class ReachLog { var steps: [Int] = [] }

struct AmbientLeadGenerator {

    // MARK: - Lead 1

    static func generateLead1(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceNonSilent: Bool = false,
        forceRuleID: String? = nil,
        structure: SongStructure? = nil
    ) -> [MIDIEvent] {
        let bounds    = kRegisterBounds[kTrackLead1]!  // low:60, high:88
        let loopSteps = loopBars * 16
        let scalePCs  = frame.scalePCs
        let notes     = notesInRegister(pitchClasses: scalePCs, low: bounds.low, high: bounds.high)
        guard !notes.isEmpty else { return [] }

        let minorModes: Set<Mode> = [.Aeolian, .Dorian, .MinorPentatonic]
        let pentaIntervals = minorModes.contains(frame.mode) ? [0, 3, 5, 7, 10] : Mode.MajorPentatonic.intervals
        let pentaPCs   = Set(pentaIntervals.map { (frame.keySemitoneValue + $0) % 12 })
        let pentaNotes = notesInRegister(pitchClasses: pentaPCs, low: bounds.low, high: bounds.high)

        // If a specific rule is forced (test pool override), skip the random roll
        if let forced = forceRuleID {
            switch forced {
            case "AMB-LEAD-001": usedRuleIDs.insert("AMB-LEAD-001"); return floatingTone(notes: notes, loopSteps: loopSteps, rng: &rng)
            case "AMB-LEAD-002": usedRuleIDs.insert("AMB-LEAD-002"); return echoPhrase(notes: notes, loopSteps: loopSteps, rng: &rng)
            case "AMB-LEAD-003": usedRuleIDs.insert("AMB-LEAD-003"); return pentaShimmer(notes: pentaNotes.isEmpty ? notes : pentaNotes, loopSteps: loopSteps, rng: &rng)
            case "AMB-LEAD-004": usedRuleIDs.insert("AMB-LEAD-004"); return []
            case "AMB-LEAD-007": usedRuleIDs.insert("AMB-LEAD-007"); return lyricalFragment(notes: notes, loopSteps: loopSteps, rng: &rng)
            case "AMB-LEAD-008": usedRuleIDs.insert("AMB-LEAD-008"); return returningMotif(notes: notes, loopSteps: loopSteps, rng: &rng)
            case "AMB-LEAD-009":
                usedRuleIDs.insert("AMB-LEAD-009")
                guard let str = structure else { return [] }
                return generateMagnetikSolo(frame: frame, structure: str, tonalMap: tonalMap, rng: &rng)
            case "AMB-LEAD-010":
                usedRuleIDs.insert("AMB-LEAD-010")
                guard let str = structure else { return [] }
                return generateOxygeneratorSolo(frame: frame, structure: str, tonalMap: tonalMap, rng: &rng)
            default: break
            }
        }

        let roll = rng.nextDouble()
        if !forceNonSilent && roll < 0.20 {
            usedRuleIDs.insert("AMB-LEAD-004"); return []   // 20% silence
        }
        if roll < 0.35 {
            usedRuleIDs.insert("AMB-LEAD-001")
            return floatingTone(notes: notes, loopSteps: loopSteps, rng: &rng)  // 15%
        }
        if roll < 0.50 {
            usedRuleIDs.insert("AMB-LEAD-002")
            return echoPhrase(notes: notes, loopSteps: loopSteps, rng: &rng)    // 15%
        }
        if roll < 0.65 {
            usedRuleIDs.insert("AMB-LEAD-003")
            return pentaShimmer(notes: pentaNotes.isEmpty ? notes : pentaNotes, loopSteps: loopSteps, rng: &rng)  // 15%
        }
        if roll < 0.74 {
            usedRuleIDs.insert("AMB-LEAD-007")
            return lyricalFragment(notes: notes, loopSteps: loopSteps, rng: &rng)  // 9%
        }
        if roll < 0.84 {
            usedRuleIDs.insert("AMB-LEAD-008")
            return returningMotif(notes: notes, loopSteps: loopSteps, rng: &rng)   // 10%
        }
        if roll < 0.93 {
            if let str = structure {
                usedRuleIDs.insert("AMB-LEAD-009")
                return generateMagnetikSolo(frame: frame, structure: str, tonalMap: tonalMap, rng: &rng)  // 9%
            }
        }
        if let str = structure {
            usedRuleIDs.insert("AMB-LEAD-010")
            return generateOxygeneratorSolo(frame: frame, structure: str, tonalMap: tonalMap, rng: &rng)  // 7%
        }
        // Fallback if structure not available: floating tone
        usedRuleIDs.insert("AMB-LEAD-001")
        return floatingTone(notes: notes, loopSteps: loopSteps, rng: &rng)
    }

    // MARK: - Lead 2
    // Two rules, 50/50: AMB-LEAD-005 (tonal cell) or AMB-LEAD-006 (descending phrase).
    // Both generate exactly loopBars of events; AmbientLoopTiler tiles to full song length.
    // Pitches are seeded from Lead 1's pitch classes transposed into Lead 2's lower register,
    // so the first harmonic encounter is related — subsequent encounters drift via co-prime phasing.

    static func generateLead2(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        lead1Events: [MIDIEvent],
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {
        let bounds    = kRegisterBounds[kTrackLead2]!  // low:55, high:81
        let loopSteps = loopBars * 16

        // Derive pitch pool from Lead 1's actual pitch classes, placed in Lead 2's register.
        // Falls back to full scale if Lead 1 is silent.
        let lead1PCs = Set(lead1Events.map { Int($0.note) % 12 })
        let pitchPCs = lead1PCs.isEmpty ? frame.scalePCs : lead1PCs
        let notes    = notesInRegister(pitchClasses: pitchPCs, low: bounds.low, high: bounds.high)
        guard !notes.isEmpty else { return [] }

        let validForce = forceRuleID.flatMap { ($0 == "AMB-LEAD-005" || $0 == "AMB-LEAD-006") ? $0 : nil }
        let ruleID = validForce ?? (rng.nextDouble() < 0.70 ? "AMB-LEAD-005" : "AMB-LEAD-006")
        usedRuleIDs.insert(ruleID)

        if ruleID == "AMB-LEAD-006" {
            return descendingPhrase(notes: notes, loopSteps: loopSteps, rng: &rng)
        }

        // AMB-LEAD-005: sparse tonal cell — 2–4 sustained notes, generous rests (AMB-RULE-02).
        var events: [MIDIEvent] = []
        let noteCount = 2 + rng.nextInt(upperBound: 3)
        var cursor    = rng.nextInt(upperBound: Swift.max(1, loopSteps / 4))

        for _ in 0..<noteCount {
            guard cursor < loopSteps else { break }
            let note    = notes[rng.nextInt(upperBound: notes.count)]
            let dur     = Swift.min(8 + rng.nextInt(upperBound: 17), loopSteps - cursor)  // 8–24 steps
            guard dur >= 4 else { break }
            let vel     = pnoVel(35 + rng.nextInt(upperBound: 28))  // 35–62, softer than Lead 1
            events.append(MIDIEvent(stepIndex: cursor, note: note, velocity: vel, durationSteps: dur))
            cursor += dur + dur + rng.nextInt(upperBound: Swift.max(1, loopSteps / 4))
        }
        return events
    }

    // MARK: - AMB-LEAD-006: Descending phrase
    // 3–5 diatonic scale tones descending stepwise from the upper register.
    // Each note held 10–18 steps; velocity fades gently as the phrase descends (38→~26).
    // Placed once per loop at a randomised offset so co-prime tiling phases it against
    // Lead 1 differently on every pass — the Eno tape-loop effect.
    private static func descendingPhrase(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        guard notes.count >= 3 else { return [] }

        let phraseLen  = 3 + rng.nextInt(upperBound: 3)     // 3–5 notes
        let holdSteps  = 10 + rng.nextInt(upperBound: 9)    // 10–18 steps per note
        let gapSteps   = 2  + rng.nextInt(upperBound: 3)    // 2–4 steps between notes
        let phraseSpan = phraseLen * (holdSteps + gapSteps)
        guard phraseSpan < loopSteps else { return [] }

        // Start in upper third of register; walk downward 1–2 scale steps per note
        let minStart = Swift.max(phraseLen - 1, (notes.count * 2) / 3)
        let startIdx = minStart + rng.nextInt(upperBound: Swift.max(1, notes.count - minStart))
        var indices  = [startIdx]
        for _ in 1..<phraseLen {
            let step = 1 + rng.nextInt(upperBound: 2)
            indices.append(Swift.max(0, indices.last! - step))
        }

        // Offset spans full available range so different loop lengths phase at different positions
        let offset = rng.nextInt(upperBound: Swift.max(1, loopSteps - phraseSpan))
        var cursor = offset
        var events: [MIDIEvent] = []

        for (i, noteIdx) in indices.enumerated() {
            guard cursor < loopSteps else { break }
            let note = notes[Swift.max(0, Swift.min(notes.count - 1, noteIdx))]
            let dur  = Swift.min(holdSteps, loopSteps - cursor)
            guard dur >= 4 else { break }
            let baseVel = Swift.max(22, 38 - i * 3)   // 38 at top, fades to ~26 at bottom
            let vel = pnoVel(baseVel + rng.nextInt(upperBound: 8))
            events.append(MIDIEvent(stepIndex: cursor, note: note, velocity: vel, durationSteps: dur))
            cursor += holdSteps + gapSteps
        }
        return events
    }

    // MARK: - Lead 1 rule implementations

    /// AMB-LEAD-001: Floating tone — 1–3 sustained notes, long rests between them.
    /// Each note is guaranteed to differ from the previous one (when the pool has ≥ 2 notes),
    /// so tiled loops never sound like a single repeated pitch.
    private static func floatingTone(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let count   = 1 + rng.nextInt(upperBound: 3)   // 1–3 notes
        var cursor  = rng.nextInt(upperBound: 8)
        var lastIdx = -1
        for _ in 0..<count {
            guard cursor < loopSteps else { break }
            // Pick an index that differs from the previous one when the pool allows it.
            var idx = rng.nextInt(upperBound: notes.count)
            if notes.count >= 2 && idx == lastIdx {
                idx = (idx + 1 + rng.nextInt(upperBound: notes.count - 1)) % notes.count
            }
            lastIdx = idx
            let note    = notes[idx]
            let dur     = 8 + rng.nextInt(upperBound: 17)   // 8–24 steps
            let safeDur = Swift.min(dur, loopSteps - cursor)
            if safeDur >= 4 {
                let vel = pnoVel(50 + rng.nextInt(upperBound: 30))  // 50–79
                events.append(MIDIEvent(stepIndex: cursor, note: note, velocity: vel, durationSteps: safeDur))
            }
            // AMB-RULE-02: rest ≥ 2× note duration
            cursor += safeDur + safeDur * 2 + rng.nextInt(upperBound: 8)
        }
        return events
    }

    /// AMB-LEAD-002: Echo phrase — 2–3 note descending phrase with diminishing velocity.
    private static func echoPhrase(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let phraseCount = 1 + rng.nextInt(upperBound: 2)
        var cursor = 4 + rng.nextInt(upperBound: 8)
        for _ in 0..<phraseCount {
            guard cursor < loopSteps else { break }
            let phraseStart = cursor
            let noteCount   = 2 + rng.nextInt(upperBound: 2)  // 2–3 notes
            var idx         = rng.nextInt(upperBound: notes.count)
            for i in 0..<noteCount {
                guard cursor < loopSteps else { break }
                let note    = notes[idx]
                let dur     = 4 + rng.nextInt(upperBound: 5)     // 4–8 steps
                let gap     = 2 + rng.nextInt(upperBound: 4)     // 2–5 steps gap
                let safeDur = Swift.min(dur, loopSteps - cursor)
                let baseVel = 65 - i * 12
                if safeDur >= 2 {
                    let vel = pnoVel(Swift.max(20, baseVel + rng.nextInt(upperBound: 10)))
                    events.append(MIDIEvent(stepIndex: cursor, note: note, velocity: vel, durationSteps: safeDur))
                }
                cursor += safeDur + gap
                // Stepwise motion
                let delta = rng.nextDouble() < 0.5 ? 1 : -1
                idx = Swift.max(0, Swift.min(notes.count - 1, idx + delta))
            }
            // AMB-RULE-02: long rest after phrase (≥ phrase duration)
            let phraseDur = cursor - phraseStart
            cursor += phraseDur + rng.nextInt(upperBound: 8)
        }
        return events   // cursor only advances — events are already in step order
    }

    /// AMB-LEAD-003: Pentatonic shimmer — short ascending run, then long rest.
    private static func pentaShimmer(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        var cursor = rng.nextInt(upperBound: 4)
        while cursor < loopSteps {
            let count    = 3 + rng.nextInt(upperBound: 2)  // 3–4 notes
            let startIdx = rng.nextInt(upperBound: Swift.max(1, notes.count - count))
            for i in 0..<count {
                let step = cursor + i * 3
                guard step < loopSteps else { break }
                let idx  = Swift.min(startIdx + i, notes.count - 1)
                let vel  = pnoVel(Swift.min(80, 40 + i * 8 + rng.nextInt(upperBound: 10)))
                events.append(MIDIEvent(stepIndex: step, note: notes[idx], velocity: vel, durationSteps: 2))
            }
            // AMB-RULE-02: long rest after shimmer
            cursor += count * 3 + 24 + rng.nextInt(upperBound: 16)
        }
        return events
    }

    /// AMB-LEAD-007: Lyric fragment — 4-note arc with intentional contour: low → mid → peak → step-down.
    /// Uses scale tones; each note held 10–14 steps; 6-step gaps. One occurrence per loop.
    private static func lyricalFragment(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        guard notes.count >= 5 else { return [] }

        // Start in the lower third of the register; build arc upward then resolve down
        let maxStart = Swift.max(1, notes.count / 3)
        let startIdx = rng.nextInt(upperBound: maxStart)
        let step1    = 2 + rng.nextInt(upperBound: 2)           // +2 or +3 positions
        let step2    = 2 + rng.nextInt(upperBound: 2)           // +2 or +3 positions
        let step3    = -(1 + rng.nextInt(upperBound: 2))        // -1 or -2 from peak

        let idx0 = startIdx
        let idx1 = Swift.min(notes.count - 1, startIdx + step1)
        let idx2 = Swift.min(notes.count - 1, idx1 + step2)
        let idx3 = Swift.max(0, idx2 + step3)
        let phrase = [notes[idx0], notes[idx1], notes[idx2], notes[idx3]]

        let holdSteps = 10 + rng.nextInt(upperBound: 5)         // 10–14 steps per note
        let gapSteps  = 6
        let phraseLen = phrase.count * (holdSteps + gapSteps)
        guard phraseLen < loopSteps else { return [] }
        let offset = rng.nextInt(upperBound: loopSteps - phraseLen)

        // Velocity arc mirrors the pitch arc: rises to peak, settles at resolution
        let baseVels: [Int] = [52, 63, 72, 60]
        var events: [MIDIEvent] = []
        var cursor = offset
        for (i, note) in phrase.enumerated() {
            let vel = pnoVel(Swift.min(100, baseVels[i] + rng.nextInt(upperBound: 8)))
            let dur = Swift.min(holdSteps, loopSteps - cursor)
            if dur >= 4 {
                events.append(MIDIEvent(stepIndex: cursor, note: note, velocity: vel, durationSteps: dur))
            }
            cursor += holdSteps + gapSteps
        }
        return events
    }

    /// AMB-LEAD-008: Returning motif — statement / bar gap / statement / bar gap / variation, cycle repeats.
    /// A short melodic phrase (2–5 notes) is stated twice unchanged, then varied on the third repetition
    /// (transposed, a note substituted, or rhythmically shifted by 2 steps). A 2–4 bar rest follows
    /// before the cycle repeats, either with the same phrase or a new variation.
    /// All repetitions are bar-aligned: each statement begins on a bar boundary.
    private static func returningMotif(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        guard notes.count >= 3 else { return [] }

        // Build a short stepwise motif in the lower-mid register
        let motifLen = 2 + rng.nextInt(upperBound: 4)              // 2–5 notes
        let maxStart = Swift.max(1, notes.count / 2)
        var idx      = rng.nextInt(upperBound: maxStart)
        var motifIndices = [Int]()
        for _ in 0..<motifLen {
            motifIndices.append(Swift.min(idx, notes.count - 1))
            let delta = rng.nextDouble() < 0.65 ? 1 : -1
            idx = Swift.max(0, Swift.min(notes.count - 1, idx + delta))
        }

        let noteDur    = 4 + rng.nextInt(upperBound: 4)            // 4–7 steps per note
        let noteGap    = 1 + rng.nextInt(upperBound: 2)            // 1–2 step gap within phrase
        let noteStride = noteDur + noteGap
        let phraseSpan = motifLen * noteStride                      // steps the phrase occupies
        let baseVel    = 45 + rng.nextInt(upperBound: 20)          // 45–64

        // Advance to start of next bar boundary
        func nextBar(after step: Int) -> Int { ((step / 16) + 1) * 16 }

        // Emit one statement; velBoost applied on top of baseVel
        func emit(at start: Int, indices: [Int], velBoost: Int) -> [MIDIEvent] {
            var evts: [MIDIEvent] = []
            for (i, noteIdx) in indices.enumerated() {
                let step = start + i * noteStride
                guard step < loopSteps else { break }
                let dur = Swift.min(noteDur, loopSteps - step)
                guard dur >= 2 else { break }
                let vel = pnoVel(Swift.max(25, Swift.min(100, baseVel + velBoost + rng.nextInt(upperBound: 8) - 4)))
                evts.append(MIDIEvent(stepIndex: step, note: notes[noteIdx],
                                      velocity: vel, durationSteps: dur))
            }
            return evts
        }

        var events: [MIDIEvent] = []
        var cursor = rng.nextInt(upperBound: 8)   // slight random offset before first cycle

        while cursor + phraseSpan < loopSteps {
            // --- Statement 1: plain ---
            events += emit(at: cursor, indices: motifIndices, velBoost: 0)
            cursor = nextBar(after: cursor + phraseSpan)
            guard cursor + phraseSpan < loopSteps else { break }

            // --- Statement 2: same phrase, slightly louder (confirmation) ---
            events += emit(at: cursor, indices: motifIndices, velBoost: 3)
            cursor = nextBar(after: cursor + phraseSpan)
            guard cursor + phraseSpan < loopSteps else { break }

            // --- Statement 3: variation ---
            let varType = rng.nextInt(upperBound: 3)
            var varIndices = motifIndices
            var rhythmShift = 0

            switch varType {
            case 0:
                // Transpose: shift all indices ±1 scale step
                let shift = rng.nextDouble() < 0.5 ? 1 : -1
                varIndices = motifIndices.map { Swift.max(0, Swift.min(notes.count - 1, $0 + shift)) }
            case 1:
                // Substitute: replace one note with a scale-step neighbor (+2 or −2 positions)
                let pos   = rng.nextInt(upperBound: varIndices.count)
                let delta = rng.nextDouble() < 0.5 ? 2 : -2
                varIndices[pos] = Swift.max(0, Swift.min(notes.count - 1, varIndices[pos] + delta))
            default:
                // Rhythmic shift: same pitches, phrase starts 2 steps later
                rhythmShift = 2
            }

            events += emit(at: cursor + rhythmShift, indices: varIndices, velBoost: 6)
            cursor = nextBar(after: cursor + rhythmShift + phraseSpan)

            // Long rest before next cycle: 2–4 bars
            cursor += (2 + rng.nextInt(upperBound: 3)) * 16
        }

        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    // MARK: - AMB-LEAD-009: Magnetik solo
    // Inspired by Magnetik bars 10–18 "Keyboard Player - Freely": 70s freely-played analog lead.
    // Character: chord tones at "after-beat" positions (notes land just past the beat, legato),
    // 2–4 events per bar, short durations, occasional 2-note event. Soft, floaty velocity.
    // Plays in exactly 2 windows of 8 bars with ≥12-bar gap. Sparse: ~35% rest bars.

    private static func generateMagnetikSolo(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let windows = pickSoloWindows(structure: structure, soloLength: 8, windowCount: 2,
                                      minGap: 12, rng: &rng)
        guard !windows.isEmpty else { return [] }

        let scalePCs = frame.scalePCs
        let allNotes = notesInRegister(pitchClasses: scalePCs, low: 62, high: 78)
        guard !allNotes.isEmpty else { return [] }
        var events: [MIDIEvent] = []

        for window in windows {
            for bar in window {
                // ~35% rest bar
                if rng.nextDouble() < 0.35 { continue }

                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16

                // Prefer chord tones (60% bias)
                let chordTonePCs = Set(entry.chordWindow.chordTones.map { $0 % 12 })
                let chordNotes   = allNotes.filter { chordTonePCs.contains(Int($0) % 12) }
                let pool = chordNotes.isEmpty ? allNotes : chordNotes

                // "After-beat" positions: just past beats 1-4 (steps 2, 6, 10, 14) ± 1 jitter
                let baseOffsets = [2, 6, 10, 14]
                let eventCount  = 2 + rng.nextInt(upperBound: 3)  // 2–4 events
                var used = Set<Int>()

                for _ in 0..<eventCount {
                    // Pick an unused base offset
                    let candidates = baseOffsets.filter { !used.contains($0) }
                    guard !candidates.isEmpty else { break }
                    let base   = candidates[rng.nextInt(upperBound: candidates.count)]
                    let jitter = rng.nextInt(upperBound: 3) - 1   // -1, 0, +1
                    let step   = Swift.max(0, Swift.min(15, base + jitter))
                    used.insert(base)

                    let note = pool[rng.nextInt(upperBound: pool.count)]
                    let dur  = Swift.min(4 + rng.nextInt(upperBound: 5), 16 - step)  // 4–8 steps
                    guard dur >= 2 else { continue }
                    let vel  = pnoVel(38 + rng.nextInt(upperBound: 31))  // 38–68

                    events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                            velocity: vel, durationSteps: dur))
                }
            }
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    // MARK: - AMB-LEAD-010: Oxygenerator solo
    // Inspired by Oxygenerator "Synth Lead 2" bars 21–23: classic analog pad ornamental melody.
    // Character: flowing 8th-note run of scale tones (all very soft) peaking at one chord tone,
    // with occasional trill ornament (X, X+semitone, X → resolve). Dense within active bars,
    // but ~30% rest bars keep it sparse.
    // Plays in exactly 2 windows of 9 bars with ≥12-bar gap.

    private static func generateOxygeneratorSolo(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let windows = pickSoloWindows(structure: structure, soloLength: 9, windowCount: 2,
                                      minGap: 12, rng: &rng)
        guard !windows.isEmpty else { return [] }

        let scalePCs = frame.scalePCs
        let allNotes = notesInRegister(pitchClasses: scalePCs, low: 64, high: 80)
        guard allNotes.count >= 4 else { return [] }
        var events: [MIDIEvent] = []

        for window in windows {
            for bar in window {
                // ~30% rest bar
                if rng.nextDouble() < 0.30 { continue }

                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16

                let chordTonePCs = Set(entry.chordWindow.chordTones.map { $0 % 12 })
                let chordNotes   = allNotes.filter { chordTonePCs.contains(Int($0) % 12) }

                // Pick ascending run start — lower portion of register
                let runLen   = 5 + rng.nextInt(upperBound: 3)    // 5–7 notes
                let maxStart = Swift.max(0, allNotes.count - runLen - 2)
                let startIdx = rng.nextInt(upperBound: Swift.max(1, maxStart / 2 + 1))

                // Occasional trill ornament on one note in the run (25%)
                let trillPos = rng.nextDouble() < 0.25 ? rng.nextInt(upperBound: runLen) : -1

                var step = 0
                var peakPlaced = false

                for i in 0..<runLen {
                    guard step < 12 else { break }
                    let noteIdx = Swift.min(startIdx + i, allNotes.count - 1)
                    let note    = Int(allNotes[noteIdx])

                    if i == trillPos && step + 3 < 12 && noteIdx + 1 < allNotes.count {
                        // Trill ornament: note, diatonic upper neighbour, note (3 steps at soft vel)
                        let upper = Int(allNotes[noteIdx + 1])  // next scale tone — avoids chromatic clashes
                        events.append(MIDIEvent(stepIndex: barStart + step,     note: UInt8(note),  velocity: 22, durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: barStart + step + 1, note: UInt8(upper), velocity: 28, durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: barStart + step + 2, note: UInt8(note),  velocity: 18, durationSteps: 1))
                        step += 3
                        continue
                    }

                    // Last note in run or a chord tone: make it the "peak" (louder, held longer)
                    let isChordTone = chordTonePCs.contains(note % 12)
                    let isPeak = (i == runLen - 1 || isChordTone) && !peakPlaced
                    if isPeak { peakPlaced = true }
                    let vel = isPeak ? UInt8(62 + rng.nextInt(upperBound: 19))  // 62–80
                                     : UInt8(14 + rng.nextInt(upperBound: 22))  // 14–35 (soft)
                    let dur = isPeak ? Swift.min(5 + rng.nextInt(upperBound: 3), 16 - step)  // 5–7 steps
                                     : 2                                                       // 2 steps (8th note)
                    guard dur >= 1 else { break }
                    events.append(MIDIEvent(stepIndex: barStart + step, note: UInt8(note),
                                            velocity: vel, durationSteps: dur))
                    step += isPeak ? dur : 2
                }

                // Optional gentle descent after peak (2–3 notes, very soft)
                if peakPlaced && step < 14 && rng.nextDouble() < 0.55 {
                    let descentLen = 2 + rng.nextInt(upperBound: 2)
                    let topIdx     = Swift.min(startIdx + runLen - 1, allNotes.count - 1)
                    for j in 1...descentLen {
                        guard step < 15 else { break }
                        let idx  = Swift.max(0, topIdx - j)
                        let vel  = pnoVel(12 + rng.nextInt(upperBound: 16))  // 12–27
                        events.append(MIDIEvent(stepIndex: barStart + step, note: allNotes[idx],
                                                velocity: vel, durationSteps: 2))
                        step += 2
                    }
                }
            }
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

}
