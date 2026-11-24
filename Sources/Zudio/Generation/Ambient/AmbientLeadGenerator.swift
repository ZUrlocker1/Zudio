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
        // Vamp (after Koln Part IIa, Zack 2026-11-24): in 35 percent of songs, 8, 12 or 16 bars
        // of rocking left hand over a pedal, ending where the urgent question starts (4 bars before
        // the climax), clear of the minor peaks' bars. Drawn after everything above, so no other
        // position moves.
        var vamp: Range<Int>? = nil
        // A regen draws the vamp on a stream of its own, so each regen can get one (Zack, 2026-11-24).
        if variation != 0 { rng = SeededRNG(seed: h ^ variation ^ 0x7A3F_0003_5EED_0002) }
        if rng.nextDouble() < 0.50 {   // about 35% of songs once the ones it doesn't fit drop out
            let end = climaxBar - 4
            // The drawn length first, then shorter ones if it doesn't fit
            let lens = [16, 12, 8]
            for len in lens[rng.nextInt(upperBound: 3)...] where vamp == nil {
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
            let vel     = UInt8(35 + rng.nextInt(upperBound: 28))  // 35–62, softer than Lead 1
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
            let vel = UInt8(baseVel + rng.nextInt(upperBound: 8))
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
                let vel = UInt8(50 + rng.nextInt(upperBound: 30))  // 50–79
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
                    let vel = UInt8(Swift.max(20, baseVel + rng.nextInt(upperBound: 10)))
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
                let vel  = UInt8(Swift.min(80, 40 + i * 8 + rng.nextInt(upperBound: 10)))
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
            let vel = UInt8(Swift.min(100, baseVels[i] + rng.nextInt(upperBound: 8)))
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
                let vel = UInt8(Swift.max(25, Swift.min(100, baseVel + velBoost + rng.nextInt(upperBound: 8) - 4)))
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
                    let vel  = UInt8(38 + rng.nextInt(upperBound: 31))  // 38–68

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
                        let vel  = UInt8(12 + rng.nextInt(upperBound: 16))  // 12–27
                        events.append(MIDIEvent(stepIndex: barStart + step, note: allNotes[idx],
                                                velocity: vel, durationSteps: 2))
                        step += 2
                    }
                }
            }
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    // MARK: - Ambient Piano Lead (full-song, no loop tiler)

    /// Measurement hook for tests: when non-nil, the piano rules append each melody phrase here
    /// (label + its events). Nil in the app. Never touches the RNG, so output is unchanged.
    struct PianoProbePhrase { let label: String; let events: [MIDIEvent] }
    nonisolated(unsafe) static var pianoProbe: [PianoProbePhrase]? = nil
    private static func probe(_ label: String, _ ev: [MIDIEvent]) {
        if pianoProbe != nil, !ev.isEmpty { pianoProbe!.append(PianoProbePhrase(label: label, events: ev)) }
    }

    static func generateAmbientPianoLead(
        pianoRule: String,
        frame: GlobalMusicalFrame,
        totalBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        introEndBar: Int = 0,
        isEvolvePass: Bool = false,
        arcVariation: UInt64 = 0
    ) -> [MIDIEvent] {
        usedRuleIDs.insert(pianoRule)
        switch pianoRule {
        case "AMB-PNO-001": return floatingTonesFullSong(frame: frame, totalBars: totalBars, rng: &rng, usedRuleIDs: &usedRuleIDs, isEvolvePass: isEvolvePass)
        case "AMB-PNO-003": return dramaticArcFullSong(frame: frame, totalBars: totalBars, rng: &rng,
                                                       usedRuleIDs: &usedRuleIDs, isEvolvePass: isEvolvePass,
                                                       arcVariation: arcVariation)
        default:            return pensiveMelodyFullSong(frame: frame, totalBars: totalBars, rng: &rng, introEndBar: introEndBar, isEvolvePass: isEvolvePass)
        }
    }

    // MARK: AMB-PNO-001 — Floating Buds (Harold Budd)

    private static func floatingTonesFullSong(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>, isEvolvePass: Bool = false
    ) -> [MIDIEvent] {
        let r = rng.nextDouble()
        if r < 0.40 {
            usedRuleIDs.remove("AMB-PNO-001"); usedRuleIDs.insert("AMB-PNO-001-BT")
            return floatingTonesMode1(frame: frame, totalBars: totalBars, rng: &rng, isEvolvePass: isEvolvePass)
        }
        if r < 0.75 {
            usedRuleIDs.remove("AMB-PNO-001"); usedRuleIDs.insert("AMB-PNO-001-CW")
            return floatingTonesMode2(frame: frame, totalBars: totalBars, rng: &rng, isEvolvePass: isEvolvePass)
        }
        usedRuleIDs.remove("AMB-PNO-001"); usedRuleIDs.insert("AMB-PNO-001-PD")
        return floatingTonesMode3(frame: frame, totalBars: totalBars, rng: &rng, isEvolvePass: isEvolvePass)
    }

    /// Mode 1 — Sparse floating: chord wash + 4-7 sparse events.
    private static func floatingTonesMode1(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG, isEvolvePass: Bool = false
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let evtNotes = notesInRegister(pitchClasses: scalePCs, low: 55, high: 84)
        guard !evtNotes.isEmpty else { return [] }

        // Colour constellation (once per song): 3-4 notes within about an octave that the floating
        // notes keep coming back to — root and 5th, usually the 9th, sometimes the 6th or the 3rd.
        // Figures still wander between them, but they start and come to rest on these bells.
        let rootPC = frame.keySemitoneValue % 12
        var constPCs = [rootPC, (rootPC + 7) % 12]
        if rng.nextDouble() < 0.70 { constPCs.append((rootPC + 2) % 12) }
        if rng.nextDouble() < 0.50 { constPCs.append((rootPC + (rng.nextDouble() < 0.50 ? 9 : (scalePCs.contains((rootPC + 4) % 12) ? 4 : 3))) % 12) }
        constPCs = constPCs.filter { scalePCs.contains($0) }
        let constCenter = 66 + rng.nextInt(upperBound: 7)   // F#4-C5
        let constIdx: [Int] = Array(Set(constPCs.compactMap { pc in
            evtNotes.indices.filter { Int(evtNotes[$0]) % 12 == pc }
                .min { abs(Int(evtNotes[$0]) - constCenter) < abs(Int(evtNotes[$1]) - constCenter) }
        })).sorted()
        // Nearest constellation note within `within` scale steps, else the index unchanged
        func snapConst(_ i: Int, within: Int = 2) -> Int {
            guard let c = constIdx.min(by: { abs($0 - i) < abs($1 - i) }), abs(c - i) <= within else { return i }
            return c
        }
        func randomConst() -> Int { constIdx.isEmpty ? rng.nextInt(upperBound: evtNotes.count) : constIdx[rng.nextInt(upperBound: constIdx.count)] }
        var lastIdx: Int = -1
        var events: [MIDIEvent] = []

        let minEvents  = Swift.max(16, totalBars / 5)
        let eventCount = minEvents + rng.nextInt(upperBound: 6)
        var cursor = isEvolvePass ? rng.nextInt(upperBound: 8) : (1 + rng.nextInt(upperBound: 2)) * 16

        for i in 0..<eventCount {
            guard cursor < totalSteps - 2 * 16 else { break }
            let roll = rng.nextDouble()

            if roll < 0.07 {
                // Single bell-tone — short, clear, not sustained beyond piano decay
                var idx = rng.nextDouble() < 0.85 ? randomConst() : rng.nextInt(upperBound: evtNotes.count)
                if rng.nextDouble() < 0.25 && lastIdx >= 0 { idx = lastIdx }
                lastIdx = idx
                let dur = Swift.min(8 + rng.nextInt(upperBound: 9), totalSteps - cursor)
                if dur >= 4 {
                    events.append(MIDIEvent(stepIndex: cursor, note: evtNotes[idx],
                                            velocity: UInt8(24 + rng.nextInt(upperBound: 18)),
                                            durationSteps: dur))
                }

            } else if roll < 0.24 {
                // Arpeggiated dyad — 2nd note 2-4 steps after 1st, within piano sustain (10-16 steps each)
                let idx   = rng.nextDouble() < 0.80 ? randomConst() : rng.nextInt(upperBound: evtNotes.count)
                let note1 = evtNotes[idx]
                let note2 = evtNotes.first(where: { abs(Int($0) - Int(note1)) == 7 })
                         ?? evtNotes.first(where: { abs(Int($0) - Int(note1)) == 4 })
                         ?? evtNotes.first(where: { abs(Int($0) - Int(note1)) == 5 })
                let dur1 = Swift.min(10 + rng.nextInt(upperBound: 7), totalSteps - cursor)
                if dur1 >= 6 {
                    let vel = UInt8(26 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: cursor, note: note1, velocity: vel, durationSteps: dur1))
                    if let n2 = note2 {
                        let offset = 2 + rng.nextInt(upperBound: 3)
                        let dur2 = Swift.min(dur1 - offset, totalSteps - cursor - offset)
                        if dur2 >= 4 {
                            events.append(MIDIEvent(stepIndex: cursor + offset, note: n2,
                                                    velocity: UInt8(Swift.max(18, Int(vel) - 6)),
                                                    durationSteps: dur2))
                        }
                    }
                    lastIdx = idx
                }

            } else if roll < 0.46 {
                // Descending figure with variation: optional initial upward turn, occasional 2-step skip.
                // Avoids pure scale motion; creates melodic interest without predictability.
                let startIdx = rng.nextDouble() < 0.70 ? randomConst()
                             : evtNotes.count / 2 + rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 2))
                let figLen   = 3 + rng.nextInt(upperBound: 4)
                var noteIdx  = startIdx
                var s        = cursor
                let hasTurn  = rng.nextDouble() < 0.45
                for fi in 0..<figLen {
                    guard s + 2 < totalSteps else { break }
                    let isLast = fi == figLen - 1
                    // Idea 3: 55% chance to extend the final note (1.25-1.75 bars) so it breathes into the gap.
                    let raw    = isLast ? (rng.nextDouble() < 0.55 ? 20 + rng.nextInt(upperBound: 9)
                                                                   : 10 + rng.nextInt(upperBound: 7))
                                       :  2 + rng.nextInt(upperBound: 4)
                    let dur    = Swift.min(raw, totalSteps - s - 1)
                    guard dur >= 2 else { break }
                    let vel = UInt8(Swift.max(18, 40 - fi * 4 + rng.nextInt(upperBound: 7)))
                    if isLast { noteIdx = snapConst(noteIdx) }   // come to rest on a bell
                    events.append(MIDIEvent(stepIndex: s, note: evtNotes[noteIdx],
                                            velocity: vel, durationSteps: dur))
                    s += raw + 1 + rng.nextInt(upperBound: 2)
                    lastIdx = noteIdx
                    if hasTurn && fi == 0 {
                        noteIdx = Swift.min(noteIdx + 1, evtNotes.count - 1)  // turn: up first
                    } else {
                        let skip = rng.nextDouble() < 0.30 ? 2 : 1
                        noteIdx  = Swift.max(0, noteIdx - skip)
                    }
                }

            } else if roll < 0.68 {
                // Ascending figure with variation: optional arch (dip before peak), occasional 2-step leap.
                let startIdx = rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 2))
                let figLen   = 4 + rng.nextInt(upperBound: 4)
                var noteIdx  = startIdx
                var s        = cursor
                let hasArch  = rng.nextDouble() < 0.40
                let peakFi   = figLen - 2
                for fi in 0..<figLen {
                    guard s + 2 < totalSteps else { break }
                    let isLast = fi == figLen - 1
                    // Idea 3: 55% chance to extend the final note so it breathes into the gap.
                    let raw    = isLast ? (rng.nextDouble() < 0.55 ? 20 + rng.nextInt(upperBound: 9)
                                                                   : 10 + rng.nextInt(upperBound: 7))
                                       :  2 + rng.nextInt(upperBound: 4)
                    let dur    = Swift.min(raw, totalSteps - s - 1)
                    guard dur >= 2 else { break }
                    let vel = isLast ? UInt8(30 + rng.nextInt(upperBound: 14))
                                    : UInt8(22 + rng.nextInt(upperBound: 10))
                    if isLast { noteIdx = snapConst(noteIdx) }   // come to rest on a bell
                    events.append(MIDIEvent(stepIndex: s, note: evtNotes[noteIdx],
                                            velocity: vel, durationSteps: dur))
                    s += raw + 1 + rng.nextInt(upperBound: 2)
                    lastIdx = noteIdx
                    if hasArch && fi == peakFi {
                        noteIdx = Swift.max(startIdx, noteIdx - 1)  // arch: dip before final peak
                    } else {
                        let skip = rng.nextDouble() < 0.25 ? 2 : 1
                        noteIdx  = Swift.min(noteIdx + skip, evtNotes.count - 1)
                    }
                }

            } else if roll < 0.82 {
                // Skip-and-resolve: approach note → leap P4-P5 up → step back down 1-2.
                // The jump creates tension; the stepwise resolution releases it.
                let lowIdx = rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 2))
                let low    = evtNotes[lowIdx]
                let leap   = evtNotes.first(where: { Int($0) - Int(low) >= 5 && Int($0) - Int(low) <= 8 })
                          ?? evtNotes[Swift.min(lowIdx + 3, evtNotes.count - 1)]
                let leapIdx = evtNotes.firstIndex(of: leap) ?? Swift.min(lowIdx + 3, evtNotes.count - 1)
                var s = cursor
                let d0 = Swift.min(3 + rng.nextInt(upperBound: 3), totalSteps - s - 6)
                if d0 >= 2 {
                    events.append(MIDIEvent(stepIndex: s, note: low,
                                            velocity: UInt8(24 + rng.nextInt(upperBound: 8)),
                                            durationSteps: d0))
                    s += d0 + 1; lastIdx = lowIdx
                }
                let d1 = Swift.min(4 + rng.nextInt(upperBound: 5), totalSteps - s - 4)
                if d1 >= 2 && s < totalSteps {
                    events.append(MIDIEvent(stepIndex: s, note: leap,
                                            velocity: UInt8(32 + rng.nextInt(upperBound: 14)),
                                            durationSteps: d1))
                    s += d1 + 1; lastIdx = leapIdx
                }
                var resolveIdx = Swift.max(0, leapIdx - 1 - rng.nextInt(upperBound: 2))
                let resolveBell = snapConst(resolveIdx, within: 1)
                if resolveBell < leapIdx { resolveIdx = resolveBell }   // resolve down onto a bell
                // Idea 3: 55% chance to extend the resolve note so it breathes into the gap.
                let d2raw = rng.nextDouble() < 0.55 ? 20 + rng.nextInt(upperBound: 9)
                                                    : 10 + rng.nextInt(upperBound: 7)
                let d2 = Swift.min(d2raw, totalSteps - s)
                if d2 >= 4 && s < totalSteps {
                    events.append(MIDIEvent(stepIndex: s, note: evtNotes[resolveIdx],
                                            velocity: UInt8(22 + rng.nextInt(upperBound: 10)),
                                            durationSteps: d2))
                    lastIdx = resolveIdx
                }

            } else {
                // Chord wash: 3-4 consonant notes rolled with 2-3 step stagger, each 8-12 steps.
                // Gives sparse Mode 1 songs occasional harmonic substance without dominating.
                let chordRootIdx = rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 2))
                let chordRoot    = evtNotes[chordRootIdx]
                var washNotes: [UInt8] = [chordRoot]
                if let third = evtNotes.first(where: { Int($0) - Int(chordRoot) == 4 || Int($0) - Int(chordRoot) == 3 }) {
                    washNotes.append(third)
                }
                if let fifth = evtNotes.first(where: { Int($0) - Int(chordRoot) == 7 }) {
                    washNotes.append(fifth)
                }
                if rng.nextDouble() < 0.40,
                   let color = evtNotes.first(where: { [10, 11, 12].contains(Int($0) - Int(chordRoot)) }) {
                    washNotes.append(color)
                }
                let washVel = UInt8(52 + rng.nextInt(upperBound: 18))
                var s = cursor
                for (ci, note) in washNotes.enumerated() {
                    guard s < totalSteps - 4 else { break }
                    let dur = Swift.min(12 + rng.nextInt(upperBound: 9), totalSteps - s)
                    if dur >= 4 {
                        events.append(MIDIEvent(stepIndex: s, note: note,
                                                velocity: UInt8(Swift.max(28, Int(washVel) - ci * 5)),
                                                durationSteps: dur))
                    }
                    s += 2 + rng.nextInt(upperBound: 2)
                }
                lastIdx = chordRootIdx
            }

            // Proportional gap capped at 3 bars (down from 5) — keeps song active without dead zones.
            let eventsLeft = eventCount - i - 1
            let remaining  = Swift.max(0, totalSteps - cursor) / 16
            let minGap = eventsLeft > 0 ? Swift.max(2, remaining / (eventsLeft + 1)) : 2
            let maxGap = Swift.min(minGap + 1, 3)
            cursor += (minGap + rng.nextInt(upperBound: Swift.max(1, maxGap - minGap + 1))) * 16
        }

        // Section anchors: fire a quiet chord wash at 1/3 and 2/3 if that region is bare.
        // Ensures long songs have harmonic landmarks even when the random event loop skips over them.
        let anchorBars = [totalBars / 3, (totalBars * 2) / 3]
        for anchorBar in anchorBars {
            let anchorStep = anchorBar * 16
            guard anchorStep < totalSteps - 32 else { continue }
            let hasNearby = events.contains { abs($0.stepIndex - anchorStep) < 32 }
            guard !hasNearby else { continue }
            let aRootIdx = evtNotes.count / 4 + rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 4))
            let aRoot = evtNotes[Swift.min(aRootIdx, evtNotes.count - 1)]
            var aChord: [UInt8] = [aRoot]
            if let third = evtNotes.first(where: { Int($0) - Int(aRoot) == 4 || Int($0) - Int(aRoot) == 3 }) {
                aChord.append(third)
            }
            if let fifth = evtNotes.first(where: { Int($0) - Int(aRoot) == 7 }) {
                aChord.append(fifth)
            }
            if let oct = evtNotes.first(where: { Int($0) - Int(aRoot) == 12 }) {
                aChord.append(oct)
            }
            let aVel = UInt8(42 + rng.nextInt(upperBound: 12))
            for (ci, note) in aChord.enumerated() {
                let step = anchorStep + ci * 2
                let dur  = Swift.min(14 + rng.nextInt(upperBound: 6), totalSteps - step)
                if dur >= 4 && step < totalSteps {
                    events.append(MIDIEvent(stepIndex: step, note: note,
                                            velocity: UInt8(Swift.max(26, Int(aVel) - ci * 5)),
                                            durationSteps: dur))
                }
            }
        }

        // Connector pass: bridge inter-phrase gaps with soft linking gestures.
        // Four improvements over the original single-grace-note approach:
        //   1. Perceived-gap correction: very soft sustains (vel ≤ 25) are treated as ending
        //      10 steps early, because the piano decay makes them inaudible before their MIDI off.
        //   2. Lower threshold (14 steps / ~1 bar) and higher probability (75%) — catches
        //      edge-case gaps that the old 24-step threshold missed.
        //   3. Long gaps (> 40 steps): use a sustained hold note (16–24 steps) instead of a
        //      brief grace note, so there's a real tone in the space rather than a flicker.
        //   4. Very long gaps (> 48 steps): add a second connector note, stepwise toward
        //      the incoming phrase's register, making it a 2-note bridge figure.
        let sorted = events.sorted { $0.stepIndex < $1.stepIndex }
        var connectors: [MIDIEvent] = []
        for i in 0..<sorted.count - 1 {
            let ev       = sorted[i]
            let next     = sorted[i + 1]
            // Idea 1: shorten effective end of very soft sustains for perceived-gap purposes
            let perceivedEnd = (ev.velocity <= 25 && ev.durationSteps > 12)
                ? ev.stepIndex + ev.durationSteps - 10
                : ev.stepIndex + ev.durationSteps
            let perceivedGap = next.stepIndex - perceivedEnd
            guard perceivedGap > 14 else { continue }       // idea 2: lower threshold
            guard rng.nextDouble() < 0.75 else { continue } // idea 2: higher probability
            guard let lastEIdx = evtNotes.firstIndex(of: ev.note) else { continue }

            let connVel  = UInt8(22 + rng.nextInt(upperBound: 9))
            let delta    = rng.nextDouble() < 0.50 ? 1 : -1
            let nbIdx    = Swift.max(0, Swift.min(evtNotes.count - 1, lastEIdx + delta))

            if perceivedGap > 48 {
                // Idea 4: two-note bridge — first note early in gap, second steps toward next phrase
                let midStep  = perceivedEnd + 4 + rng.nextInt(upperBound: Swift.max(1, perceivedGap / 3))
                let midDur   = Swift.min(16 + rng.nextInt(upperBound: 9), next.stepIndex - midStep - 4)
                if midDur >= 8 && midStep < next.stepIndex - 6 {
                    connectors.append(MIDIEvent(stepIndex: midStep, note: evtNotes[nbIdx],
                                                velocity: connVel, durationSteps: midDur))
                    // Second note: step toward the register of the incoming phrase
                    let incomingIdx  = evtNotes.firstIndex(of: next.note) ?? nbIdx
                    let stepToward   = nbIdx < incomingIdx ? 1 : (nbIdx > incomingIdx ? -1 : 0)
                    let nb2Idx       = Swift.max(0, Swift.min(evtNotes.count - 1, nbIdx + stepToward))
                    let lateStep     = midStep + midDur + 2 + rng.nextInt(upperBound: 4)
                    let lateDur      = Swift.min(12 + rng.nextInt(upperBound: 9), next.stepIndex - lateStep - 2)
                    if lateDur >= 6 && lateStep < next.stepIndex - 4 {
                        connectors.append(MIDIEvent(stepIndex: lateStep, note: evtNotes[nb2Idx],
                                                    velocity: UInt8(Swift.max(20, Int(connVel) - 3)),
                                                    durationSteps: lateDur))
                    }
                }
            } else if perceivedGap > 40 {
                // Idea 3: sustained hold note — fills most of the gap with a ringing tone
                let holdStep = perceivedEnd + 3 + rng.nextInt(upperBound: 4)
                let holdDur  = Swift.min(16 + rng.nextInt(upperBound: 9), next.stepIndex - holdStep - 2)
                if holdDur >= 10 && holdStep < next.stepIndex - 4 {
                    connectors.append(MIDIEvent(stepIndex: holdStep, note: evtNotes[snapConst(nbIdx)],
                                                velocity: connVel, durationSteps: holdDur))
                }
            } else {
                // Short gap: original brief grace note, now with longer duration range
                let connStep = perceivedEnd + 4 + rng.nextInt(upperBound: Swift.max(1, perceivedGap / 2 - 4))
                let connDur  = Swift.min(8 + rng.nextInt(upperBound: 7), next.stepIndex - connStep - 2)
                if connDur >= 4 && connStep < next.stepIndex - 2 {
                    connectors.append(MIDIEvent(stepIndex: connStep, note: evtNotes[nbIdx],
                                                velocity: connVel, durationSteps: connDur))
                }
            }
        }
        events.append(contentsOf: connectors)

        return trimDissonances(events, totalSteps: totalSteps)
    }

    /// Mode 2 — Revealed chords: two alternating chords with melodic fragments woven into every gap.
    /// Two-pass design: Pass 1 places chord events with proportional spacing (max 4-bar gap);
    /// Pass 2 emits each chord plus a continuation gesture that fills the silence with either
    /// an arpeggio reveal, a stepwise melodic drift, or a soft echo cascade. Velocity follows
    /// a gentle arc (softer opening and closing, fuller middle) for even dynamic balance.
    private static func floatingTonesMode2(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG, isEvolvePass: Bool = false
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let root     = frame.keySemitoneValue
        let scaleSet = Set(frame.scalePCs)
        func snapToScale(_ raw: Int) -> Int {
            let t = ((raw % 12) + 12) % 12
            if scaleSet.contains(t) { return t }
            for d in [1, -1, 2, -2] { let c = (t + d + 12) % 12; if scaleSet.contains(c) { return c } }
            return t
        }

        // Scale degrees used in voicings
        let b3   = snapToScale(root + 3)
        let p5   = snapToScale(root + 7)
        let p4   = snapToScale(root + 5)
        let maj6 = snapToScale(root + 9)
        let sus2 = snapToScale(root + 2)

        // Two bass registers
        var bBass = root + 48; while bBass > 50 { bBass -= 12 }; while bBass < 41 { bBass += 12 }
        let aOff  = rng.nextDouble() < 0.50 ? 7 : 3
        var aBass = bBass - aOff; while aBass < 39 { aBass += 12 }
        let aBassPC = snapToScale(aBass % 12)
        aBass = aBass - (aBass % 12) + aBassPC
        while aBass < 39 { aBass += 12 }
        while aBass > 54 { aBass -= 12 }

        func voice(_ pcs: [Int], bass: Int) -> [UInt8] {
            var notes: [UInt8] = []
            if bass >= 39 && bass <= 54 { notes.append(UInt8(bass)) }
            var midNotes: [Int] = []
            for pc in pcs {
                var m = pc + 60; while m > 75 { m -= 12 }; while m < 60 { m += 12 }
                let tooClose = midNotes.contains(where: { abs($0 - m) <= 2 })
                if m >= 60 && m <= 75 && !tooClose && !notes.contains(UInt8(m)) {
                    notes.append(UInt8(m)); midNotes.append(m)
                }
            }
            return Array(notes.sorted().prefix(4))
        }

        // Six distinct voicings spanning different scale-tone combinations (Idea 1).
        // Voicings where two melody-register notes form a tritone are filtered out:
        // in minor/Dorian keys voice([b3, maj6]) places a tritone (e.g. C–F# in A Dorian).
        let voicingPool: [[UInt8]] = [
            voice([root, b3, p5],   bass: aBass),   // root triad
            voice([root, b3, maj6], bass: aBass),   // major 6th chord (Harold Budd signature)
            voice([root, p4, p5],   bass: aBass),   // sus4 open voicing
            voice([b3, p5],         bass: bBass),   // 5th bass, upper dyad
            voice([b3, maj6],       bass: bBass),   // 5th bass, 3rd+6th
            voice([sus2, p5],       bass: aBass),   // sus2 feel
        ].filter { v in
            guard v.count >= 2 else { return false }
            let rh = v.filter { $0 >= 57 }
            for i in 0..<rh.count {
                for j in (i+1)..<rh.count {
                    if (Int(rh[j]) - Int(rh[i])) % 12 == 6 { return false }
                }
            }
            return true
        }

        let baseChordVel = 22 + rng.nextInt(upperBound: 14)   // 22-35: chords sit behind the melody (Idea 3)
        let scaleHigh    = notesInRegister(pitchClasses: Set(frame.scalePCs), low: 62, high: 85)
        var events: [MIDIEvent] = []

        // ── Pass 1: distribute chord events with density arc (Idea 4) ──
        struct ChordSlot { var step: Int; var chord: [UInt8]; var dur: Int; var chordVel: UInt8; var melVel: UInt8 }
        var slots: [ChordSlot] = []
        var cursor = 0
        var lastVoicingIdx = -1
        let target = 16 + rng.nextInt(upperBound: 10)   // 16–25 events

        for i in 0..<target {
            guard cursor < totalSteps - 16 else { break }

            // Beat anchor: 30% chance of snapping to nearest half-bar boundary (Idea 2)
            var startStep = cursor
            if rng.nextDouble() < 0.30 {
                let snapped = ((cursor + 4) / 8) * 8
                if snapped < totalSteps - 16 { startStep = snapped }
            }

            // Pick voicing, avoiding consecutive repeats (Idea 1)
            var vIdx = rng.nextInt(upperBound: voicingPool.count)
            if voicingPool.count > 1 {
                var tries = 0
                while vIdx == lastVoicingIdx && tries < 4 { vIdx = rng.nextInt(upperBound: voicingPool.count); tries += 1 }
            }
            lastVoicingIdx = vIdx
            let chord = voicingPool[vIdx]

            // Chord velocity: soft wash with gentle arc at edges (Idea 3)
            let songPos  = Double(startStep) / Double(totalSteps)
            let arcFade  = songPos < 0.15 ? Int(songPos / 0.15 * 6) :
                           songPos > 0.80 ? Int((1.0 - songPos) / 0.20 * 6) : 6
            let chordVel = UInt8(Swift.max(18, Swift.min(38, baseChordVel - 3 + arcFade + rng.nextInt(upperBound: 7))))
            // Melody notes sit noticeably above the chord wash (Idea 3)
            let melVel   = UInt8(Swift.max(32, Swift.min(58, Int(chordVel) + 14 + rng.nextInt(upperBound: 12))))

            var dur = 0
            if rng.nextDouble() < 0.15 && i > 0 {
                // Occasional single "breath" note — one mid voice only
                let bNote = chord.count > 1 ? chord[1] : chord[0]
                let bDur  = Swift.min(10 + rng.nextInt(upperBound: 7), totalSteps - startStep)
                if bDur >= 4 { slots.append(ChordSlot(step: startStep, chord: [bNote], dur: bDur, chordVel: chordVel, melVel: melVel)) }
                dur = Swift.max(bDur, 4)
            } else {
                dur = rng.nextDouble() < 0.50
                    ? Swift.min(10 + rng.nextInt(upperBound: 7),  totalSteps - startStep)
                    : Swift.min(16 + rng.nextInt(upperBound: 13), totalSteps - startStep)
                if dur >= 4 { slots.append(ChordSlot(step: startStep, chord: chord, dur: dur, chordVel: chordVel, melVel: melVel)) }
            }

            // Gap with density arc: sparse at edges (×1.75), denser in the middle (×0.85) (Idea 4)
            let eventsLeft = target - i - 1
            let remaining  = Swift.max(1, totalSteps - startStep - dur)
            let avgGap     = eventsLeft > 0 ? remaining / (eventsLeft + 1) : remaining / 2
            let denseMult: Double = isEvolvePass ? 0.85 :
                                    (songPos < 0.15 || songPos > 0.80) ? 1.75 :
                                    (songPos < 0.30 || songPos > 0.65) ? 1.20 : 0.85
            let scaledAvg  = Swift.max(8, Int(Double(avgGap) * denseMult))
            let rawGap = rng.nextDouble() < 0.60
                ? Swift.max(8,  scaledAvg / 2 + rng.nextInt(upperBound: Swift.max(1, scaledAvg / 4)))
                : Swift.max(16, scaledAvg     + rng.nextInt(upperBound: Swift.max(1, scaledAvg / 3)))
            cursor = startStep + dur + Swift.min(rawGap, 80)   // 5-bar max gap
        }

        // ── Pass 2: emit chord notes + immediate echo + continuation gesture ──
        for (idx, slot) in slots.enumerated() {
            let nextStart = idx + 1 < slots.count ? slots[idx + 1].step : totalSteps
            let gapStart  = slot.step + slot.dur + 2
            let gapEnd    = Swift.max(gapStart, nextStart - 4)
            let gapSize   = gapEnd - gapStart

            // Chord notes (soft wash)
            for note in slot.chord {
                events.append(MIDIEvent(stepIndex: slot.step, note: note,
                                        velocity: slot.chordVel, durationSteps: slot.dur))
            }

            // Immediate echo: top voice steps to scale neighbor — melVel keeps it above the wash
            if slot.chord.count > 1, let topNote = slot.chord.last,
               let ci = scaleHigh.firstIndex(of: topNote) {
                let echoStart = slot.step + slot.dur + 3 + rng.nextInt(upperBound: 5)
                if echoStart < totalSteps {
                    let goUp   = rng.nextDouble() < 0.55
                    let nb1Idx = goUp ? Swift.min(ci + 1, scaleHigh.count - 1) : Swift.max(0, ci - 1)
                    let nb1    = scaleHigh[nb1Idx]
                    if nb1 != topNote {
                        let e1dur = Swift.min(5 + rng.nextInt(upperBound: 7), totalSteps - echoStart)
                        if e1dur >= 2 {
                            events.append(MIDIEvent(stepIndex: echoStart, note: nb1,
                                                    velocity: slot.melVel,
                                                    durationSteps: e1dur))
                            let e2start = echoStart + e1dur + 1
                            if e2start < totalSteps {
                                let nb2Idx = goUp ? Swift.min(nb1Idx + 1, scaleHigh.count - 1) : Swift.max(0, nb1Idx - 1)
                                let nb2    = scaleHigh[nb2Idx]
                                let e2dur  = Swift.min(5 + rng.nextInt(upperBound: 9), totalSteps - e2start)
                                if e2dur >= 2 && nb2 != nb1 {
                                    events.append(MIDIEvent(stepIndex: e2start, note: nb2,
                                                            velocity: UInt8(Swift.max(22, Int(slot.melVel) - 8)),
                                                            durationSteps: e2dur))
                                    if rng.nextDouble() < 0.60 {
                                        let e3start = e2start + e2dur + 2
                                        let e3dur   = Swift.min(4 + rng.nextInt(upperBound: 8), totalSteps - e3start)
                                        if e3start < totalSteps && e3dur >= 2 {
                                            events.append(MIDIEvent(stepIndex: e3start, note: nb1,
                                                                    velocity: UInt8(Swift.max(18, Int(slot.melVel) - 14)),
                                                                    durationSteps: e3dur))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Continuation gesture — fills every gap > 2 bars with musical content.
            // Skip if the gap starts in the final 15% to avoid ghost-note tails.
            let isInCoda = Double(gapStart) / Double(totalSteps) > 0.85
            guard gapSize >= 32, !scaleHigh.isEmpty, !isInCoda else { continue }
            let gestureRoll = rng.nextDouble()
            let gVel = slot.melVel

            if gestureRoll < 0.35 {
                // Arpeggio reveal: chord tones enter one by one
                var s = gapStart + 4 + rng.nextInt(upperBound: 8)
                for note in slot.chord {
                    guard s + 6 < gapEnd else { break }
                    let noteDur = Swift.min(8 + rng.nextInt(upperBound: 7), gapEnd - s)
                    events.append(MIDIEvent(stepIndex: s, note: note,
                                            velocity: UInt8(Swift.max(18, Int(gVel) - 8)),
                                            durationSteps: noteDur))
                    s += 4 + rng.nextInt(upperBound: 5)
                }
            } else if gestureRoll < 0.68 {
                // Melodic drift: stepwise figure from chord top — Budd's climbing/descending gesture
                let topNote  = slot.chord.last ?? slot.chord[0]
                let startIdx = scaleHigh.firstIndex(of: topNote) ?? (scaleHigh.count / 2)
                let ascending = rng.nextDouble() < 0.50
                let count    = 3 + rng.nextInt(upperBound: 4)
                var s        = gapStart + 8 + rng.nextInt(upperBound: 14)
                var noteIdx  = startIdx
                for n in 0..<count {
                    guard s + 6 < gapEnd else { break }
                    let isLast  = n == count - 1
                    let noteDur = isLast
                        ? Swift.min(8 + rng.nextInt(upperBound: 9), gapEnd - s)
                        : Swift.min(3 + rng.nextInt(upperBound: 3), gapEnd - s)
                    guard noteDur >= 2 else { break }
                    events.append(MIDIEvent(stepIndex: s, note: scaleHigh[noteIdx],
                                            velocity: UInt8(Swift.max(18, Int(gVel) - n * 4)),
                                            durationSteps: noteDur))
                    s += noteDur + 2 + rng.nextInt(upperBound: 4)
                    let step = rng.nextDouble() < 0.25 ? 2 : 1
                    noteIdx = ascending
                        ? Swift.min(noteIdx + step, scaleHigh.count - 1)
                        : Swift.max(0, noteIdx - step)
                }
            } else {
                // Turn ornament: brief upward reversal then descent
                let topNote  = slot.chord.last ?? slot.chord[0]
                let startIdx = scaleHigh.firstIndex(of: topNote) ?? (scaleHigh.count / 2)
                let descentCount = 2 + rng.nextInt(upperBound: 2)
                var idxOffsets = [1, 0]
                for d in 1...descentCount { idxOffsets.append(-d) }
                var s = gapStart + 6 + rng.nextInt(upperBound: 10)
                for (n, offset) in idxOffsets.enumerated() {
                    guard s + 6 < gapEnd else { break }
                    let idx     = Swift.max(0, Swift.min(startIdx + offset, scaleHigh.count - 1))
                    let isLast  = n == idxOffsets.count - 1
                    let noteDur = isLast
                        ? Swift.min(8 + rng.nextInt(upperBound: 9), gapEnd - s)
                        : Swift.min(3 + rng.nextInt(upperBound: 4), gapEnd - s)
                    guard noteDur >= 2 else { break }
                    events.append(MIDIEvent(stepIndex: s, note: scaleHigh[idx],
                                            velocity: UInt8(Swift.max(20, Int(gVel) - n * 6)),
                                            durationSteps: noteDur))
                    s += noteDur + 3 + rng.nextInt(upperBound: 5)
                }
            }
        }

        // ── Closing chord: tonic resolution when song trails off ──
        let lastStep   = events.max(by: { $0.stepIndex < $1.stepIndex })?.stepIndex ?? 0
        let trailSteps = totalSteps - lastStep
        if !isEvolvePass && trailSteps > 9 * 16 {
            let closingStep = totalSteps - (9 + rng.nextInt(upperBound: 2)) * 16
            let closingDur  = Swift.min(totalSteps - closingStep - 4, 2 * 16)
            if closingStep > lastStep + 16 && closingDur >= 16 {
                let closingVel = UInt8(Swift.max(32, Swift.min(52, baseChordVel + 12)))
                for note in voicingPool[0] {
                    events.append(MIDIEvent(stepIndex: closingStep, note: note,
                                            velocity: closingVel,
                                            durationSteps: closingDur))
                }
            }
        }

        return trimDissonances(events, totalSteps: totalSteps)
    }

    /// Mode 3 — Chromatic pendulum: metronomic A↔B cluster oscillation every beat.
    private static func floatingTonesMode3(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG, isEvolvePass: Bool = false
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let allMid     = notesInRegister(pitchClasses: scalePCs, low: 59, high: 73)
        guard allMid.count >= 3 else { return [] }

        // Build clusters using stride-2 pool indices — gives m3/M3 intervals (consonant thirds)
        // rather than stride-1 (M2/m2 seconds which sound dissonant in dense repetition).
        let anchorIdx = rng.nextInt(upperBound: Swift.max(1, allMid.count - 6))
        let a0 = Int(allMid[anchorIdx])
        let a2 = Int(allMid[Swift.min(anchorIdx + 2, allMid.count - 1)])  // skip a1: m3/M3 instead of M2
        let a4 = Int(allMid[Swift.min(anchorIdx + 4, allMid.count - 1)])
        let a1 = Int(allMid[Swift.min(anchorIdx + 1, allMid.count - 1)])
        let a3 = Int(allMid[Swift.min(anchorIdx + 3, allMid.count - 1)])
        var clA: [Int] = [a0, a2]   // third apart
        if rng.nextDouble() < 0.50 { clA.append(a4) }
        var clB: [Int] = [a1, a3]   // third apart, interleaved with clA
        if rng.nextDouble() < 0.50 { clB.append(Int(allMid[Swift.min(anchorIdx + 5, allMid.count - 1)])) }

        // Bass progression (G2–G3 range — mid-bass register, avoids sub-bass crowding)
        let bassPool  = notesInRegister(pitchClasses: scalePCs, low: 43, high: 55)
        let numBass   = 4 + rng.nextInt(upperBound: 3)
        let bassSeq   = (0..<numBass).map { _ in bassPool.isEmpty ? UInt8(28) : bassPool[rng.nextInt(upperBound: bassPool.count)] }
        let baseVel3  = 46 + rng.nextInt(upperBound: 12)  // base velocity; per-cluster variation applied below

        var events: [MIDIEvent] = []

        // Pendulum section: 12-20 bars in the middle — metronomic oscillation as a contained body, not the whole song
        let pendLength = 12 + rng.nextInt(upperBound: 9)
        let pendStart  = totalBars * 30 / 100
        let pendEnd    = Swift.min(pendStart + pendLength, totalBars * 72 / 100)

        // Opening — descending melodic phrases + growing pendulum fragments, no silent gaps.
        // Each cycle: a 3-5 note phrase (3-10 steps/note, short piano-appropriate durations)
        // descending through allMid, then 2-3 bars of a0/a1 fragments. Melody stays above
        // anchorIdx+1 so it never collides with the pendulum register until handoff.
        var oCursor  = isEvolvePass ? 0 : 16  // bar 1 for evolve passes, bar 2 otherwise
        var melIdx   = allMid.count - 1 - rng.nextInt(upperBound: 2)  // near top of register
        var oFlip    = true
        let openEnd  = pendStart * 16
        while oCursor < openEnd - 16 {
            let progress = openEnd > 16 ? Double(oCursor) / Double(openEnd) : 0.0
            let velBase  = 22 + Int(progress * 30)  // 22→52 approaching pendulum

            // Melodic phrase: 3-5 notes, mostly stepwise descending, each 3-10 steps
            let phraseLen = 3 + rng.nextInt(upperBound: 3)
            var pIdx = melIdx
            var s    = oCursor
            for n in 0..<phraseLen {
                guard s + 4 < openEnd else { break }
                let note   = allMid[pIdx]
                let isLast = n == phraseLen - 1
                let raw    = isLast ? 6 + rng.nextInt(upperBound: 5)   // dotted-quarter → half
                                    : 3 + rng.nextInt(upperBound: 4)   // 16th → dotted-quarter
                let dur    = Swift.min(raw, openEnd - s - 2)
                if dur >= 2 && note >= 21 && note <= 108 {
                    let vel = UInt8(Swift.max(20, Swift.min(56, velBase + rng.nextInt(upperBound: 10) - 4)))
                    events.append(MIDIEvent(stepIndex: s, note: note, velocity: vel, durationSteps: dur))
                }
                let mv = rng.nextDouble()
                if mv < 0.65      { pIdx = Swift.max(anchorIdx + 1, pIdx - 1) }
                else if mv < 0.85 { /* stay */ }
                else              { pIdx = Swift.min(allMid.count - 1, pIdx + 1) }
                s += raw + 1 + rng.nextInt(upperBound: 3)
            }

            // Pendulum fragments fill the gap after the phrase (2-3 bars)
            let fragBars  = 2 + rng.nextInt(upperBound: 2)
            let fragEnd   = Swift.min(s + fragBars * 16, openEnd)
            let fragCount = 1 + Int(progress * 3.5) + rng.nextInt(upperBound: 2)
            var fs = s + 2 + rng.nextInt(upperBound: 6)
            let fragVel   = UInt8(Swift.max(20, velBase - 10))
            for _ in 0..<fragCount {
                guard fs + 3 < fragEnd else { break }
                let fNote = oFlip ? a0 : a1
                guard fNote >= 21 && fNote <= 108 else { oFlip.toggle(); fs += 4; continue }
                let dur = Swift.min(3 + rng.nextInt(upperBound: 3), fragEnd - fs)
                if dur >= 2 {
                    events.append(MIDIEvent(stepIndex: fs, note: UInt8(fNote),
                                            velocity: fragVel, durationSteps: dur))
                    oFlip.toggle()
                }
                fs += dur + 2
            }
            melIdx  = Swift.max(anchorIdx + 2, melIdx - 1)  // floor at anchorIdx+2, step down each cycle
            oCursor = fragEnd
        }

        // Pendulum body — A/B single-note alternation for stepwise melody; 35% chance adds chord texture
        // (cluster-only approach produced 0% stepwise — all within-cluster intervals are thirds)
        let pendTotalSteps = Swift.max(1, (pendEnd - pendStart) * 16)
        var step = pendStart * 16; var useA = true
        while step < pendEnd * 16 && step < totalSteps {
            let primaryNote = useA ? a0 : a1  // alternate adjacent scale tones → stepwise motion
            let harmNote    = useA ? a2 : a3  // optional chord harmony a third above
            let dur = Swift.min(3 + rng.nextInt(upperBound: 2), totalSteps - step)
            // Slow sine breath (±10) over ~2.5 cycles through the pendulum + small per-note jitter (±4).
            // Produces 2-3 dynamic swells so the section breathes rather than sitting uniformly loud.
            let t = Double(step - pendStart * 16) / Double(pendTotalSteps)
            let breathBoost = Int(sin(t * .pi * 2.5) * 10.0)
            let clVel = UInt8(Swift.max(22, Swift.min(54, baseVel3 + breathBoost + rng.nextInt(upperBound: 9) - 4)))
            guard primaryNote >= 21 && primaryNote <= 108 else { useA.toggle(); step += 4; continue }
            events.append(MIDIEvent(stepIndex: step, note: UInt8(primaryNote), velocity: clVel, durationSteps: dur))
            if rng.nextDouble() < 0.35 && harmNote != primaryNote && harmNote >= 21 && harmNote <= 108 {
                events.append(MIDIEvent(stepIndex: step, note: UInt8(harmNote),
                                        velocity: UInt8(clVel > 8 ? clVel - 8 : clVel), durationSteps: dur))
            }
            // Primary bass every 2 bars (full velocity, octave doubled).
            // Secondary lighter hit at every 1-bar mark (40% chance) fills sparse stretches like bars 29-33.
            if step % 32 == 0 {
                let bassIdx = (step / 32) % bassSeq.count
                let br = Int(bassSeq[bassIdx])
                let bd = Swift.min(28 + rng.nextInt(upperBound: 5), totalSteps - step)
                let bVel = UInt8(Swift.max(36, Swift.min(65, baseVel3 + rng.nextInt(upperBound: 11) - 5)))
                if bd >= 4 && br >= 21 && br <= 108 {
                    events.append(MIDIEvent(stepIndex: step, note: UInt8(br), velocity: bVel, durationSteps: bd))
                    let br2 = br + 12
                    if br2 <= 50 { events.append(MIDIEvent(stepIndex: step, note: UInt8(br2), velocity: bVel, durationSteps: bd)) }
                }
            } else if step % 16 == 0 && rng.nextDouble() < 0.40 {
                let bassIdx = (step / 32) % bassSeq.count
                let br = Int(bassSeq[bassIdx])
                let bd = Swift.min(14 + rng.nextInt(upperBound: 7), totalSteps - step)
                let bVel = UInt8(Swift.max(26, Swift.min(48, baseVel3 - 12 + rng.nextInt(upperBound: 9) - 4)))
                if bd >= 4 && br >= 21 && br <= 108 {
                    events.append(MIDIEvent(stepIndex: step, note: UInt8(br), velocity: bVel, durationSteps: bd))
                }
            }
            useA.toggle(); step += 4
        }

        // Pendulum melody overlay — 2-4 note phrases floating above the oscillation every 2-4 bars.
        // Notes stay above anchorIdx+1, use same short durations as opening/closing phrases.
        // This adds melodic interest over the repeating a0/a1 figure without replacing it.
        var mStep   = pendStart * 16 + (1 + rng.nextInt(upperBound: 2)) * 16  // starts 1-2 bars in
        var mMelIdx = Swift.min(anchorIdx + 3, allMid.count - 1)
        while mStep < pendEnd * 16 - 16 {
            let pLen = 2 + rng.nextInt(upperBound: 3)  // 2-4 notes
            var mIdx = mMelIdx
            var ms   = mStep
            for mn in 0..<pLen {
                guard ms + 4 < pendEnd * 16 else { break }
                let mNote   = allMid[mIdx]
                let mIsLast = mn == pLen - 1
                let mRaw    = mIsLast ? 8 + rng.nextInt(upperBound: 5)   // half note
                                      : 3 + rng.nextInt(upperBound: 4)   // 16th → dotted-quarter
                let mDur    = Swift.min(mRaw, pendEnd * 16 - ms - 2)
                if mDur >= 2 && mNote >= 21 && mNote <= 108 {
                    let mVel = UInt8(Swift.max(28, Swift.min(58, Int(baseVel3) - 6 + rng.nextInt(upperBound: 10))))
                    events.append(MIDIEvent(stepIndex: ms, note: mNote, velocity: mVel, durationSteps: mDur))
                }
                let mm = rng.nextDouble()
                if mm < 0.42      { mIdx = Swift.max(anchorIdx + 1, mIdx - 1) }
                else if mm < 0.78 { mIdx = Swift.min(allMid.count - 1, mIdx + 1) }
                ms += mRaw + 1 + rng.nextInt(upperBound: 3)
            }
            mMelIdx = Swift.min(anchorIdx + 2 + rng.nextInt(upperBound: Swift.max(1, allMid.count - anchorIdx - 2)),
                                allMid.count - 1)
            mStep  += (2 + rng.nextInt(upperBound: 3)) * 16
        }

        // Closing — ascending melodic phrases + shrinking fragments, mirror of opening.
        // Each cycle: a 3-5 note ascending phrase, then 2-3 bars of fragments.
        // melody ascends anchorIdx+2 → top of register over the closing span.
        var cCursor   = pendEnd * 16
        var melIdxC   = Swift.min(anchorIdx + 2, allMid.count - 1)
        var cFlip     = true
        let closePend = pendEnd * 16
        let closeSpan = Swift.max(1, totalSteps - closePend)
        while cCursor < totalSteps - 16 {
            let progress  = 1.0 - Double(cCursor - closePend) / Double(closeSpan)  // 1→0
            let velBase   = 18 + Int(progress * 34)  // 52→18 as we fade

            // Ascending phrase: 3-5 notes, mostly stepwise upward, each 3-10 steps
            let phraseLen = 3 + rng.nextInt(upperBound: 3)
            var pIdx = melIdxC
            var s    = cCursor
            for n in 0..<phraseLen {
                guard s + 4 < totalSteps else { break }
                let note   = allMid[pIdx]
                let isLast = n == phraseLen - 1
                let raw    = isLast ? 6 + rng.nextInt(upperBound: 5) : 3 + rng.nextInt(upperBound: 4)
                let dur    = Swift.min(raw, totalSteps - s - 2)
                if dur >= 2 && note >= 21 && note <= 108 {
                    let vel = UInt8(Swift.max(16, Swift.min(54, velBase + rng.nextInt(upperBound: 10) - 4)))
                    events.append(MIDIEvent(stepIndex: s, note: note, velocity: vel, durationSteps: dur))
                }
                let mv = rng.nextDouble()
                if mv < 0.60      { pIdx = Swift.min(allMid.count - 1, pIdx + 1) }
                else if mv < 0.80 { /* stay */ }
                else              { pIdx = Swift.max(anchorIdx + 1, pIdx - 1) }
                s += raw + 1 + rng.nextInt(upperBound: 3)
            }

            // Fragments fill the gap after each phrase (2-3 bars)
            let fragBars  = 2 + rng.nextInt(upperBound: 2)
            let fragEnd   = Swift.min(s + fragBars * 16, totalSteps)
            let fragCount = 1 + Int(progress * 3.5) + rng.nextInt(upperBound: 2)
            var fs = s + 2 + rng.nextInt(upperBound: 6)
            let fragVel   = UInt8(Swift.max(20, velBase - 10))
            for _ in 0..<fragCount {
                guard fs + 3 < fragEnd else { break }
                let fNote = cFlip ? a0 : a1
                guard fNote >= 21 && fNote <= 108 else { cFlip.toggle(); fs += 4; continue }
                let dur = Swift.min(3 + rng.nextInt(upperBound: 3), fragEnd - fs)
                if dur >= 2 {
                    events.append(MIDIEvent(stepIndex: fs, note: UInt8(fNote),
                                            velocity: fragVel, durationSteps: dur))
                    cFlip.toggle()
                }
                fs += dur + 2
            }
            melIdxC = Swift.min(allMid.count - 1, melIdxC + (rng.nextDouble() < 0.65 ? 1 : 0))
            cCursor = fragEnd
        }

        return trimDissonances(events, totalSteps: totalSteps)
    }

    // MARK: AMB-PNO-002 — Satin Melody (Satie / Arnalds)

    private static func pensiveMelodyFullSong(
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
        let w1 = Swift.min(1 + rng.nextInt(upperBound: 2), totalBars - 8) * 16
        let w2 = Swift.min(totalBars * 27 / 100, totalBars - 8) * 16
        let w3 = Swift.min(totalBars * 52 / 100, totalBars - 8) * 16
        let w4 = Swift.min(totalBars * 76 / 100, totalBars - 8) * 16
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
            probe("p1-opening", ev.filter { $0.note >= 64 }); events += ev
        } else {
            let ev = pnoReplay(motif, at: w1 + p1off, velCap: 40, totalSteps: totalSteps)
            probe("p1", ev); events += ev
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
        probe("p2", p2ev); events += p2ev

        // Phrase 3 — the full statement returns at home (motif after an answer, answer after a motif)
        let p3off = rng.nextInt(upperBound: Swift.max(1, wLen / 2))
        let p3ev  = pnoReplay(motifAtP1 ? motif : answer, at: w3 + p3off, velCap: 60, totalSteps: totalSteps)
        probe("p3", p3ev); events += p3ev
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
            probe("p3-echo", eev); events += eev
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
            probe("p4", p4ev); events += p4ev
            // Phrase 5 — sparse final exhale for long songs (>90 bars), very soft cadence
            if totalBars > 90 {
                let w5 = Swift.min(totalBars * 90 / 100, totalBars - 4) * 16
                if w5 > w4 + wLen {
                    let p5ev = pno002Phrase(type: 2, startStep: w5,
                                            pivot: pivot, neighbor: neighbor, lowerAnchor: lowerAnchor,
                                            upper: upper, lower: lower, totalSteps: totalSteps, rng: &rng,
                                            velCap: 24, rhythm: rhythm, ending: .home, frame: frame)
                    probe("p5", p5ev); events += p5ev
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
                func rubs(_ n: UInt8) -> Bool { under.contains { [1, 6, 11].contains(abs(Int($0.note) - Int(n)) % 12) } }
                if rubs(note) { note = note == qNote1 ? qNote2 : qNote1 }
                if rubs(note) { qb += 7 + rng.nextInt(upperBound: 4); continue }
                // Scale velocity with song position — softer at edges, slightly warmer in middle
                let qVelBase = qb < totalBars / 4 ? 12 : (qb > 3 * totalBars / 4 ? 10 : 18)
                if dur >= 4 { events.append(MIDIEvent(stepIndex: qs, note: note, velocity: UInt8(qVelBase + rng.nextInt(upperBound: 8)), durationSteps: dur)) }
                qb += 7 + rng.nextInt(upperBound: 4)
            }
        }

        // Satie-style left hand: bass on beat 1, a 2-note chord on beat 2, sometimes a note on beat 3.
        // Bass rocks tonic / subdominant-or-dominant (Satie's IV→I). The chord is that bass note's
        // own triad, kept under the melody: at least 3 semitones below any melody note sounding over
        // it and never a half-step, tritone or major 7th from one — so it never has to be trimmed
        // out of the melody's way. Where nothing fits under a low melody note, the hand rests.
        let lhBass  = notesInRegister(pitchClasses: scalePCs, low: 40, high: 54)
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
                func rubs(_ b: UInt8) -> Bool { overBass.contains { [1, 6, 11].contains(abs(Int($0.note) - Int(b)) % 12) } }
                if rubs(bassNote), let alt = [bassRoot, bassFifth, bassFour].first(where: { !rubs($0) }) { bassNote = alt }
                // Taper bass velocity gradually through the closing section
                let bassBase = inClosing
                    ? Swift.max(18, 30 - (bar - closingBar) * 30 / Swift.max(1, totalBars - closingBar))
                    : 30
                let bassVel  = UInt8(bassBase + rng.nextInt(upperBound: 6))
                // Jarrett/Satie: bass held for a half note (12 steps) — pedal, not a click
                events.append(MIDIEvent(stepIndex: barStep, note: bassNote, velocity: bassVel, durationSteps: 12))
                // Beat 2 (step 8): the bass note's 3rd and 5th — omitted in the closing section
                if !inClosing, barStep + 8 < totalSteps {
                    let tones = lhTones(bass: bassNote, scalePCs: scalePCs, low: 52, high: 66, target: 60,
                                        prefer: [1, 2, 0], count: 2, melody: melodyNow,
                                        start: barStep + 8, end: barStep + 15)
                    let cv = UInt8(22 + rng.nextInt(upperBound: 8))
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
                                            velocity: UInt8(16 + rng.nextInt(upperBound: 6)), durationSteps: 5))
                }
            }
        }

        return trimDissonances(events, totalSteps: totalSteps)
    }

    private static func nearLightTexture(
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
                                        velocity: UInt8(Swift.min(55 + rng.nextInt(upperBound: 11), 65)), durationSteps: 4))
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
    private static func jarrettSparseOpening(
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
                                    velocity: UInt8(24 + rng.nextInt(upperBound: 14)),
                                    durationSteps: dur))
            if !isLast { cur += 8 + rng.nextInt(upperBound: 5) }   // half–dotted-half between notes
        }
        // Bass pedal enters under the held note — Jarrett LH grounds the harmony
        if !lower.isEmpty, cur < totalSteps {
            let bd = Swift.min(22 + rng.nextInt(upperBound: 14), totalSteps - cur)
            if bd >= 8 {
                events.append(MIDIEvent(stepIndex: cur,
                                        note: lower[rng.nextInt(upperBound: lower.count)],
                                        velocity: UInt8(26 + rng.nextInt(upperBound: 10)),
                                        durationSteps: bd))
            }
        }
        return events
    }

    /// How a piano phrase ends: open (5th, or Satie's suspended 2nd/4th), home (root), or any
    /// settled tone (chord tone, sometimes a 2nd or 6th colour).
    enum PnoEnding { case open, home, any }

    /// Root, 3rd and 5th pitch classes of the song's tonic chord (the 3rd is whichever the mode has).
    private static func pnoChordPCs(_ frame: GlobalMusicalFrame) -> [Int] {
        let scale = frame.scalePCs
        let root  = frame.keySemitoneValue % 12
        let third = scale.contains((root + 4) % 12) ? (root + 4) % 12 : (root + 3) % 12
        return [root, third, (root + 7) % 12].filter { scale.contains($0) }
    }

    /// Pitch classes a phrase may end on, all in the song's scale.
    private static func pnoEndingPCs(_ ending: PnoEnding, frame: GlobalMusicalFrame, rng: inout SeededRNG) -> [Int] {
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
    private static func pnoNearest(_ pool: [UInt8], to target: Int, pcs: [Int]) -> UInt8? {
        pool.filter { pcs.contains(Int($0) % 12) }.min { abs(Int($0) - target) < abs(Int($1) - target) }
    }

    /// Left-hand chord tones kept under the melody: notes of `bass`'s triad in the scale (prefer
    /// slots: 0 root, 1 third, 2 fifth), between `low` and `high`, nearest `target`. Each sits at least
    /// 3 semitones below every melody note sounding over [start, end) and is never a half-step,
    /// tritone or major 7th from one. Up to `count` notes, one per slot; empty when nothing fits.
    private static func lhTones(bass: UInt8, scalePCs: Set<Int>, low: Int, high: Int, target: Int,
                                prefer: [Int], count: Int, melody: [MIDIEvent], start: Int, end: Int) -> [UInt8] {
        let b = Int(bass) % 12
        let third: Int? = scalePCs.contains((b + 4) % 12) ? (b + 4) % 12
                        : (scalePCs.contains((b + 3) % 12) ? (b + 3) % 12 : nil)
        let fifth: Int? = scalePCs.contains((b + 7) % 12) ? (b + 7) % 12 : nil
        let triad: [Int?] = [b, third, fifth]
        let sounding = melody.filter { $0.stepIndex < end && $0.stepIndex + $0.durationSteps > start }
        let ceiling  = Swift.min(high, (sounding.map { Int($0.note) }.min() ?? 200) - 3)
        guard ceiling >= low else { return [] }
        var out: [UInt8] = []
        for slot in prefer where out.count < count {
            guard slot < triad.count, let pc = triad[slot] else { continue }
            let cands = (low...ceiling).filter { $0 % 12 == pc }
                .filter { n in !sounding.contains { [1, 6, 11].contains(abs(Int($0.note) - n) % 12) } }
            if let n = cands.min(by: { abs($0 - target) < abs($1 - target) }) { out.append(UInt8(n)) }
        }
        return out
    }

    /// Re-places a phrase built at step 0, scaling its velocities so the loudest note sits at
    /// `velCap` (never louder than built; swell shape kept), clipped to the song.
    private static func pnoReplay(_ phrase: [MIDIEvent], at start: Int, velCap: Int, totalSteps: Int) -> [MIDIEvent] {
        let loudest = Double(phrase.map { Int($0.velocity) }.max() ?? 1)
        let velScale = Swift.min(1.0, Double(velCap) / loudest)
        return phrase.compactMap { e in
            let s = start + e.stepIndex
            guard s < totalSteps else { return nil }
            let v = Swift.max(14, Swift.min(127, Int((Double(e.velocity) * velScale).rounded())))
            return MIDIEvent(stepIndex: s, note: e.note, velocity: UInt8(v),
                             durationSteps: Swift.max(1, Swift.min(e.durationSteps, totalSteps - s)))
        }
    }

    /// Moves every note `k` steps along the scale (a sequence), keeping rhythm and velocity.
    private static func pnoMoveAlongScale(_ phrase: [MIDIEvent], by k: Int, scale: [UInt8]) -> [MIDIEvent] {
        phrase.map { e in
            guard let i = scale.firstIndex(of: e.note) else { return e }
            let n = scale[Swift.max(0, Swift.min(scale.count - 1, i + k))]
            return MIDIEvent(stepIndex: e.stepIndex, note: n, velocity: e.velocity, durationSteps: e.durationSteps)
        }
    }

    /// The answer: the motif note for note, but its last note lands on the nearest root and holds longer.
    private static func pnoAnswer(_ motif: [MIDIEvent], lower: [UInt8], frame: GlobalMusicalFrame) -> [MIDIEvent] {
        guard let lastIdx = motif.indices.max(by: { motif[$0].stepIndex < motif[$1].stepIndex }) else { return motif }
        let last = motif[lastIdx]
        let root = frame.keySemitoneValue % 12
        let home = pnoNearest(lower, to: Int(last.note), pcs: [root]) ?? last.note
        var out = motif
        out[lastIdx] = MIDIEvent(stepIndex: last.stepIndex, note: home, velocity: last.velocity,
                                 durationSteps: last.durationSteps + 4)
        // If the note before is already that root, move it to another chord tone so the root lands fresh
        if let prevIdx = motif.indices.filter({ motif[$0].stepIndex < last.stepIndex })
                                      .max(by: { motif[$0].stepIndex < motif[$1].stepIndex }),
           motif[prevIdx].note == home,
           let alt = pnoNearest(lower.filter { $0 != home }, to: Int(home), pcs: pnoChordPCs(frame).filter { $0 != root }) {
            let pv = motif[prevIdx]
            out[prevIdx] = MIDIEvent(stepIndex: pv.stepIndex, note: alt, velocity: pv.velocity, durationSteps: pv.durationSteps)
        }
        return out
    }

    /// The motif's head: its first half (at least 3 notes), the last one moved to the nearest chord
    /// tone and held, so the fragment still sounds finished.
    private static func pnoHead(_ motif: [MIDIEvent], pool: [UInt8], frame: GlobalMusicalFrame) -> [MIDIEvent] {
        let sorted = motif.sorted { $0.stepIndex < $1.stepIndex }
        let keep = Swift.min(sorted.count, Swift.max(3, (sorted.count + 1) / 2))
        var head = Array(sorted.prefix(keep))
        guard let last = head.last else { return head }
        let tone = pnoNearest(pool, to: Int(last.note), pcs: pnoChordPCs(frame)) ?? last.note
        head[head.count - 1] = MIDIEvent(stepIndex: last.stepIndex, note: tone, velocity: last.velocity,
                                         durationSteps: Swift.max(12, last.durationSteps))
        return head
    }

    private static func pno002Phrase(
        type: Int, startStep: Int, pivot: UInt8, neighbor: UInt8, lowerAnchor: UInt8,
        upper: [UInt8], lower: [UInt8], totalSteps: Int, rng: inout SeededRNG,
        velCap: Int = 52, rhythm: [Int] = [4], ending: PnoEnding = .any, frame: GlobalMusicalFrame,
        otherNeighbor: UInt8? = nil
    ) -> [MIDIEvent] {
        guard startStep < totalSteps else { return [] }
        var events: [MIDIEvent] = []
        var cur = startStep
        let cap: (Int) -> UInt8 = { UInt8(Swift.min($0, velCap)) }
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

    // MARK: AMB-PNO-003 — Koln Winter Arc (Winston / Jarrett)

    private static func dramaticArcFullSong(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>, isEvolvePass: Bool = false, arcVariation: UInt64 = 0
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let midNotes   = notesInRegister(pitchClasses: scalePCs, low: 60, high: 79)  // wider: C4-G5
        let highNotes  = notesInRegister(pitchClasses: scalePCs, low: 69, high: 89)
        let lowNotesAll   = notesInRegister(pitchClasses: scalePCs, low: 40, high: 54)
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
                let vel  = UInt8(Swift.max(1, Swift.min(127, Int(base.rounded()) + rng.nextInt(upperBound: 5) - 2)))
                ev.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: dur))
                // Chord accents: phrase launch and phrase peak — Jarrett/Winston style
                let isPeak = i == peakNote && i > 0
                if accents && (i == 0 || isPeak) {
                    let chordNote = pool.first(where: { Int($0) - Int(note) == 7 })  // P5 above
                                 ?? pool.first(where: { Int($0) - Int(note) == 4 })  // M3 above
                                 ?? pool.first(where: { Int($0) - Int(note) == 3 })  // m3 above
                    if let cn = chordNote {
                        ev.append(MIDIEvent(stepIndex: step, note: cn,
                                            velocity: UInt8(vel > 5 ? vel - 5 : vel), durationSteps: dur))
                    }
                    // Jarrett touch: add a 3rd chord note at phrase peak (fuller chord stab)
                    if isPeak {
                        let third = pool.first(where: { Int($0) - Int(note) == 3 })   // m3 above
                               ?? pool.first(where: { Int($0) - Int(note) == 4 })     // M3 above
                        if let t = third, t != chordNote ?? 0 {
                            ev.append(MIDIEvent(stepIndex: step, note: t,
                                                velocity: UInt8(vel > 8 ? vel - 8 : vel), durationSteps: dur))
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
        probe("p1", p1Result.events)

        // Pre-climax phrase in 4-phrase form
        if preclimaxBar > 0 {
            let pcResult = emitBurst(bar: preclimaxBar, pool: midNotes, count: 8 + rng.nextInt(upperBound: 4),
                                     velMin: 38, velMax: 55, ioi: 2, holdDur: 10)
            events += pcResult.events; burstEndIdx = pcResult.endIdx
            probe("preclimax", pcResult.events)
        }

        // Pre-climax ostinato (25%)
        if useOstinato && climaxBar >= 2, !midNotes.isEmpty {
            let ob    = Swift.max(0, climaxBar - 2)
            let oNote = midNotes[rng.nextInt(upperBound: midNotes.count)]
            var os    = ob * 16
            for _ in 0..<(3 + rng.nextInt(upperBound: 2)) {
                guard os < totalSteps else { break }
                events.append(MIDIEvent(stepIndex: os, note: oNote, velocity: UInt8(36 + rng.nextInt(upperBound: 13)), durationSteps: Swift.min(6, totalSteps - os)))
                os += 8
            }
        }

        // Urgent question: a 3-5 note fragment repeated 2-3x with escalating velocity,
        // 4 bars before climax — Jarrett's classic "asking more urgently each time" device.
        // Ends with a bold foreshadow chord stab (vel 68-79) that hints at the coming climax.
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
            let urgentStart = events.count
            for r in 0..<repeats {
                for n in 0..<fragLen {
                    guard qs < totalSteps else { break }
                    let idx = Swift.max(0, Swift.min(fragBase + fragIdx[n] + (rising ? r : 0), fragArr.count - 1))
                    let vel = UInt8(Swift.min(74, 42 + r * 10 + rng.nextInt(upperBound: 8)))
                    let dur = Swift.min(2, totalSteps - qs)
                    guard dur >= 1 else { break }
                    events.append(MIDIEvent(stepIndex: qs, note: fragArr[idx], velocity: vel, durationSteps: dur))
                    qs += 2
                }
                qs += 4
            }
            probe("urgent", Array(events[urgentStart...]))
            // Foreshadow chord: bold 2-3 note stab after the repeats, previewing the climax register.
            let foreshadowLimit = (climaxBar - 2) * 16 - 4
            if qs < foreshadowLimit && !fragArr.isEmpty {
                let fNote = fragArr[Swift.max(0, Swift.min(fragArr.count - 1, fragBase + fragLen))]
                let fVel  = UInt8(68 + rng.nextInt(upperBound: 12))
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

        // Fast 16th-note scalar run into the climax — 8-12 consecutive scale steps at 1-step IOI, vel rising 60→80.
        let scalarRunBar = climaxBar - 2
        if scalarRunBar >= 0 && scalarRunBar < totalBars && !midNotes.isEmpty {
            let runCount  = 8 + rng.nextInt(upperBound: 5)
            let ascending = rng.nextDouble() < 0.65
            let startIdx  = ascending
                ? rng.nextInt(upperBound: Swift.max(1, midNotes.count / 3))
                : midNotes.count / 2 + rng.nextInt(upperBound: Swift.max(1, midNotes.count / 2))
            let baseVel = 60 + rng.nextInt(upperBound: 10)
            var rs = scalarRunBar * 16 + rng.nextInt(upperBound: 4)
            for i in 0..<runCount {
                guard rs < totalSteps else { break }
                let idx = ascending
                    ? Swift.min(startIdx + i, midNotes.count - 1)
                    : Swift.max(0, startIdx - i)
                let vel = UInt8(Swift.min(80, baseVel + i * 2))
                let dur = Swift.min(2, totalSteps - rs)
                guard dur >= 1 else { break }
                events.append(MIDIEvent(stepIndex: rs, note: midNotes[idx], velocity: vel, durationSteps: dur))
                rs += 1
            }
        }

        // Climax phrase — velocity ceiling raised to 88 (Jarrett/Winston bold peak)
        var highestNote: UInt8 = 0
        let climaxHead: [Int]? = rng.nextDouble() < 0.70 ? motifMoves : nil   // the motif up high, then away
        // Half of the motif climaxes then climb straight to the held top note instead of arching
        let climaxClimb = climaxHead != nil && rng.nextDouble() < 0.50
        if useCallResp {
            let callResult = emitBurst(bar: climaxBar, pool: highNotes, count: 6 + rng.nextInt(upperBound: 3),
                                       velMin: 58, velMax: 88, ioi: 2, holdDur: 8, head: climaxHead,
                                       climb: climaxClimb)
            let respResult = emitBurst(bar: climaxBar + 2, pool: midNotes, count: 7 + rng.nextInt(upperBound: 3),
                                       velMin: 45, velMax: 68, ioi: 2, holdDur: 10)
            events += callResult.events + respResult.events
            probe("climax-call", callResult.events); probe("climax-resp", respResult.events)
            highestNote = (callResult.events + respResult.events).max(by: { $0.note < $1.note })?.note ?? 0
        } else {
            let cResult = emitBurst(bar: climaxBar, pool: highNotes, count: 9 + rng.nextInt(upperBound: 4),
                                    velMin: 58, velMax: 88, ioi: 2, holdDur: 16, head: climaxHead,
                                    climb: climaxClimb)
            events += cResult.events
            probe("climax", cResult.events)
            highestNote = cResult.events.max(by: { $0.note < $1.note })?.note ?? 0
        }

        // Bold block chord at climax peak — 3-4 simultaneous notes (the "fist on keys" moment).
        // 50% chance of a second chord hit, either tight (2-4 steps) or a beat apart (6-10 steps).
        let chordStep = climaxBar * 16 + 4
        if chordStep < totalSteps - 8, !highNotes.isEmpty {
            let rootIdx   = rng.nextInt(upperBound: Swift.max(1, highNotes.count / 2))
            let chordRoot = highNotes[rootIdx]
            let chordVel  = UInt8(78 + rng.nextInt(upperBound: 12))
            let chordDur  = Swift.min(8 + rng.nextInt(upperBound: 5), totalSteps - chordStep)
            events.append(MIDIEvent(stepIndex: chordStep, note: chordRoot, velocity: chordVel, durationSteps: chordDur))
            if let third = highNotes.first(where: { [3, 4].contains(Int($0) - Int(chordRoot)) }) {
                events.append(MIDIEvent(stepIndex: chordStep, note: third, velocity: chordVel - 4, durationSteps: chordDur))
            }
            if let fifth = highNotes.first(where: { Int($0) - Int(chordRoot) == 7 }) {
                events.append(MIDIEvent(stepIndex: chordStep, note: fifth, velocity: chordVel - 7, durationSteps: chordDur))
            }
            if rng.nextDouble() < 0.50,
               let top = highNotes.first(where: { Int($0) - Int(chordRoot) == 12 }) {
                events.append(MIDIEvent(stepIndex: chordStep, note: top, velocity: chordVel - 12, durationSteps: chordDur))
            }
            // Second chord hit — tight double (2-4 steps) or a beat apart (6-10 steps)
            if rng.nextDouble() < 0.50 {
                let gap2  = rng.nextDouble() < 0.50 ? 2 + rng.nextInt(upperBound: 3)
                                                    : 6 + rng.nextInt(upperBound: 5)
                let step2 = chordStep + gap2
                let vel2  = UInt8(Swift.max(60, Int(chordVel) - 8 - rng.nextInt(upperBound: 8)))
                let dur2  = Swift.min(6 + rng.nextInt(upperBound: 5), totalSteps - step2)
                if step2 < totalSteps - 4, dur2 >= 2 {
                    events.append(MIDIEvent(stepIndex: step2, note: chordRoot, velocity: vel2, durationSteps: dur2))
                    if let third = highNotes.first(where: { [3, 4].contains(Int($0) - Int(chordRoot)) }) {
                        events.append(MIDIEvent(stepIndex: step2, note: third, velocity: vel2 > 4 ? vel2 - 4 : vel2, durationSteps: dur2))
                    }
                    if let fifth = highNotes.first(where: { Int($0) - Int(chordRoot) == 7 }) {
                        events.append(MIDIEvent(stepIndex: step2, note: fifth, velocity: vel2 > 7 ? vel2 - 7 : vel2, durationSteps: dur2))
                    }
                }
            }
        }

        // Minor peaks (KolnArc, about a third of songs): a quick run up, then a shorter, softer
        // climax in the middle register, the motif at its head half the time. They peak around
        // velocity 68 against the climax's 88, and stay under its register.
        for pb in arc.peakBars where pb >= 2 && pb < totalBars - 4 {
            let runLen = 5 + rng.nextInt(upperBound: 3)
            let runTop = Swift.min(midNotes.count - 1, midNotes.count * 2 / 3)
            var rs = (pb - 1) * 16 + 16 - runLen - 1
            var runEv: [MIDIEvent] = []
            for i in 0..<runLen where runTop - runLen + 1 + i >= 0 {
                runEv.append(MIDIEvent(stepIndex: rs, note: midNotes[runTop - runLen + 1 + i],
                                       velocity: UInt8(44 + i * 3 + rng.nextInt(upperBound: 4)), durationSteps: 1))
                rs += 1
            }
            let peakResult = emitBurst(bar: pb, pool: midNotes, count: 6 + rng.nextInt(upperBound: 3),
                                       velMin: 42, velMax: 68, ioi: 2, holdDur: 10,
                                       startNear: runTop,
                                       head: rng.nextDouble() < 0.50 ? motifMoves : nil,
                                       endBy: (pb + 6) * 16)
            events += runEv + peakResult.events
            probe("minor-peak", runEv + peakResult.events)
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
                    let vel = UInt8(Swift.max(20, 55 - i * 5))
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
            probe("echo", echoEv); events += echoEv
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
        probe("withdrawal", wEvts)

        // Soft pool (≤70): used by closing phrase and connective phrases — computed once
        let cPool = midNotes.filter { $0 <= 70 }.isEmpty ? midNotes : midNotes.filter { $0 <= 70 }

        // Closing phrase — soft lyric fragment in last ~17% of song
        if closingBar < totalBars - 2 {
            let closeEv = emitBurst(bar: closingBar, pool: cPool, count: 4 + rng.nextInt(upperBound: 3),
                                    velMin: 20, velMax: 35, ioi: 3, holdDur: 24,
                                    head: motifMoves, ending: .home).events
            probe("closing", closeEv); events += closeEv
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
                probe("build", buildEv)
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
                let vel = UInt8(Swift.min(50, 24 + n * 6 + rng.nextInt(upperBound: 8)))
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
            let pedalVel  = UInt8(26 + rng.nextInt(upperBound: 12))
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
                                        velocity: UInt8(Swift.max(18, Int(pedalVel) - 4 + rng.nextInt(upperBound: 8))),
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
                events.append(MIDIEvent(stepIndex: rs, note: reachPool[rng.nextInt(upperBound: reachPool.count)],
                                        velocity: UInt8(50 + rng.nextInt(upperBound: 18)), durationSteps: rDur))
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
            if !nearPeak(conn1Bar) && !nearPeak(conn1Bar + 3) { probe("connective", c1Ev); events += c1Ev }
            // Second connective phrase — later two-thirds, fading further
            if conn2Bar < closingBar - 1 && !nearPeak(conn2Bar) && !nearPeak(conn2Bar + 3) {
                let c2Ev = emitBurst(bar: conn2Bar, pool: softPool,
                                     count: 5 + rng.nextInt(upperBound: 3),
                                     velMin: 20, velMax: 34, ioi: 3, holdDur: 20, startNear: wStartIdx,
                                     endBy: closingBar * 16).events
                probe("connective", c2Ev); events += c2Ev
            }
        }

        // Aftershock — 1-2 hard chord stabs reminiscent of the climax (vel 68-85),
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
                let sVel    = UInt8(56 + rng.nextInt(upperBound: 18))
                let sDur    = Swift.min(6 + rng.nextInt(upperBound: 5), totalSteps - ss)
                guard sDur >= 4 else { break }
                events.append(MIDIEvent(stepIndex: ss, note: sRoot, velocity: sVel, durationSteps: sDur))
                if let third = shockPool.first(where: { [3, 4].contains(Int($0) - Int(sRoot)) }) {
                    events.append(MIDIEvent(stepIndex: ss, note: third, velocity: sVel - 4, durationSteps: sDur))
                }
                if let fifth = shockPool.first(where: { Int($0) - Int(sRoot) == 7 }) {
                    events.append(MIDIEvent(stepIndex: ss, note: fifth, velocity: sVel - 7, durationSteps: sDur))
                }
                // Second hit per stab — 45% chance
                if rng.nextDouble() < 0.45 {
                    let gap2  = rng.nextDouble() < 0.50 ? 2 + rng.nextInt(upperBound: 3)
                                                        : 5 + rng.nextInt(upperBound: 4)
                    let ss2   = ss + gap2
                    let sVel2 = UInt8(Swift.max(38, Int(sVel) - 8 - rng.nextInt(upperBound: 8)))
                    let sDur2 = Swift.min(4 + rng.nextInt(upperBound: 4), totalSteps - ss2)
                    if ss2 < totalSteps - 4, sDur2 >= 2 {
                        events.append(MIDIEvent(stepIndex: ss2, note: sRoot, velocity: sVel2, durationSteps: sDur2))
                        if let third = shockPool.first(where: { [3, 4].contains(Int($0) - Int(sRoot)) }) {
                            events.append(MIDIEvent(stepIndex: ss2, note: third, velocity: sVel2 > 4 ? sVel2 - 4 : sVel2, durationSteps: sDur2))
                        }
                        if let fifth = shockPool.first(where: { Int($0) - Int(sRoot) == 7 }) {
                            events.append(MIDIEvent(stepIndex: ss2, note: fifth, velocity: sVel2 > 7 ? sVel2 - 7 : sVel2, durationSteps: sDur2))
                        }
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
                        probe("vamp", ph)
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
                let clean = lowNotes.filter { n in !over.contains { [1, 6, 11].contains(abs(Int($0.note) - Int(n)) % 12) } }
                let pick  = rng.nextInt(upperBound: lowNotes.count)
                guard !clean.isEmpty else { continue }
                let bn = clean[pick % clean.count]
                if bd >= 4 {
                    events.append(MIDIEvent(stepIndex: bBar * 16, note: bn,
                                            velocity: UInt8(28 + rng.nextInt(upperBound: 18)), durationSteps: bd))
                }
            }
        }

        // Winston/Jarrett left-hand: bass + arpeggiated chord tones throughout the song.
        // lhMid at 61-72 (above middle C) so mid tones register as melody, not bass.
        // Bass changes every 2 bars for variety; mid indices cycle independently per bar.
        // Exclude bass notes whose tritone partner is also in the scale (e.g. B and F in
        // Mixolydian/Dorian) — they cause cross-register tritone clashes with the melody.
        let lhBassAll   = notesInRegister(pitchClasses: scalePCs, low: 40, high: 54)
        let lhBassClean = lhBassAll.filter { n in
            let pc = Int(n) % 12
            return !scalePCs.contains((pc + 6) % 12) && !scalePCs.contains((pc + 1) % 12)
        }
        let lhBass      = lhBassClean.isEmpty ? lhBassAll : lhBassClean
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
                let bVel  = UInt8(38 + rng.nextInt(upperBound: 12))
                // Beat 1 (step 0): bass alone — arrives first like Winston/Jarrett LH
                events.append(MIDIEvent(stepIndex: barStep, note: bNote, velocity: bVel, durationSteps: 7))
                // Inner voices are the bass note's own triad, kept under the melody (lhTones): 3rd and
                // 5th on beat 2, 5th and root on beat 3 (a different inversion), the 3rd on beat 4.
                // Where nothing fits under a low melody note, that beat rests.
                // Beat 2 (step 4): 2-note chord stab — skip both beats 2+3 on ~20% of bars
                // for Jarrett-style breathing space (just bass + optional beat 4).
                let skipInner = rng.nextDouble() < 0.20
                if !skipInner && barStep + 4 < totalSteps {
                    let cv    = UInt8(30 + rng.nextInt(upperBound: 10))
                    let tones = lhTones(bass: bNote, scalePCs: scalePCs, low: 52, high: 67, target: 60,
                                        prefer: [1, 2, 0], count: 2, melody: melodySnap,
                                        start: barStep + 4, end: barStep + 10)
                    for (k, t) in tones.enumerated() {
                        events.append(MIDIEvent(stepIndex: barStep + 4, note: t, velocity: k == 0 ? cv : cv - 3, durationSteps: 6))
                    }
                }
                // Beat 3 (step 8): inner-voice repeat — 65% of bars.
                if !skipInner && barStep + 8 < totalSteps && rng.nextDouble() < 0.65 {
                    let cv2   = UInt8(26 + rng.nextInt(upperBound: 10))
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
                                            velocity: UInt8(22 + rng.nextInt(upperBound: 8)), durationSteps: 4))
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
                let vel = UInt8(Swift.max(20, Int(trigger.velocity) - 6 - n * 4))
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
            let thirdPC = scalePCs.contains((rootPC + 4) % 12) ? (rootPC + 4) % 12 : (rootPC + 3) % 12
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
                let bVel    = UInt8(50 + rng.nextInt(upperBound: 8))
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
        // The vamp logs as "Koln Winter Arc - vamp" under AMB-PNO-003 (no separate rule).
        if arc.vampBars != nil { usedRuleIDs.remove("AMB-PNO-003"); usedRuleIDs.insert("AMB-PNO-003-VP") }
        // Live wire (Koln's live take): drawn last, so a song without it is note for note what it was.
        // Logged as "AMB-PNO-003 Koln Winter Arc - jazzy improv" (Zack, 2026-11-24).
        guard !isEvolvePass, totalBars >= 40, rng.nextDouble() < 0.45 else { return trimmed }   // 45% of Koln songs (Zack, 2026-11-24)
        usedRuleIDs.remove("AMB-PNO-003"); usedRuleIDs.remove("AMB-PNO-003-VP")
        usedRuleIDs.insert(arc.vampBars != nil ? "AMB-PNO-003-VL" : "AMB-PNO-003-LW")
        return kolnLiveTake(trimmed, frame: frame, arc: arc, totalBars: totalBars, rng: &rng)
    }

    // MARK: AMB-PNO-003 vamp — Koln Part IIa

    /// The vamp's left hand: a low pedal (the root, struck every 2 bars and held a dotted half, an
    /// octave pair when there is room) under two chords that rock back and forth, the home chord and its neighbour (the
    /// flat 7th, else the 4th, else the 2nd). One pattern per song: straight half notes,
    /// syncopated (a pickup on the and of 2 and 4), or a bar of quarter-note pulses on each chord.
    /// Chord tones sit under the melody and never rub it (lhTones); a pedal that would rub moves
    /// to the 5th, or rests. Velocity rises through the section.
    private static func kolnVamp(bars: Range<Int>, frame: GlobalMusicalFrame, lhBass: [UInt8], lhRoot: UInt8,
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
                              && [1, 6, 11].contains(abs(Int($0.note) - n) % 12) }
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
                    ev.append(MIDIEvent(stepIndex: bs, note: p, velocity: UInt8(pv), durationSteps: Swift.min(12, pd)))
                    if p >= 40 { ev.append(MIDIEvent(stepIndex: bs, note: p - 12, velocity: UInt8(pv - 12), durationSteps: Swift.min(8, pd))) }
                }
            }
            for (h, (s, d, nbrHit)) in hits.enumerated() {
                let useNbr = pattern == 2 ? k % 2 == 1 : nbrHit
                let st = bs + s
                guard st + d <= totalSteps else { continue }
                let tones = lhTones(bass: useNbr ? nbrBass : homeBass, scalePCs: scalePCs, low: 52, high: 67,
                                    target: 59, prefer: [1, 2, 0], count: 3, melody: melody, start: st, end: st + d)
                    .filter { t in pedal.map { ![1, 6, 11].contains(abs(Int(t) - Int($0)) % 12) } ?? true }
                let accent = (pattern == 1 && (h == 1 || h == 3)) ? -6 : (s == 0 ? 4 : 0)
                let cv = 32 + Int(lift * 18) + accent + rng.nextInt(upperBound: 5)
                for (i, t) in tones.enumerated() {
                    ev.append(MIDIEvent(stepIndex: st, note: t, velocity: UInt8(Swift.max(20, cv - i * 3)), durationSteps: d))
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
    private static func kolnLiveTake(_ input: [MIDIEvent], frame: GlobalMusicalFrame, arc: KolnArc,
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
                ev[i] = MIDIEvent(stepIndex: ev[i].stepIndex, note: ev[i].note, velocity: ev[i].velocity,
                                  durationSteps: Swift.max(1, a - ev[i].stepIndex))
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
                                  velocity: UInt8(Swift.min(90, Int(e.velocity) + 4)), durationSteps: e.durationSteps)
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
                        run.append(MIDIEvent(stepIndex: step, note: c, velocity: UInt8(50 - k), durationSteps: 1))
                        step += 1; chromaticLeft -= 1
                    }
                }
                let isLast = k == line.count - 1
                let v = isLast ? 46 : (falling ? 56 - k * 2 : 42 + k * 2)
                run.append(MIDIEvent(stepIndex: step, note: line[k], velocity: UInt8(Swift.max(24, v)),
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

    // MARK: - Shared helpers

    /// Removes Lead 1 notes that form dissonant intervals with simultaneously sustained Pads notes.
    /// Operates cross-track — `trimDissonances` only sees a single track, so this fills that gap.
    /// `keepGraces`: Koln (AMB-PNO-003) keeps its 16th-note grace notes, which pass too quickly to
    /// clash and are checked against the drone when written (the live wire take).
    static func trimLeadAgainstPads(_ lead: [MIDIEvent], pads: [MIDIEvent], totalSteps: Int,
                                    keepGraces: Bool = false) -> [MIDIEvent] {
        func isDissonant(_ a: UInt8, _ b: UInt8) -> Bool {
            // A major 2nd only clashes as a real close second low down; a 9th over a low root or
            // drone is colour, and treating it as a clash dropped Satie's suspended-2nd endings.
            let ivl = abs(Int(a) - Int(b)) % 12
            return ivl == 1 || ivl == 6 || ivl == 11 || (abs(Int(a) - Int(b)) == 2 && Swift.min(a, b) < 55)
        }
        guard !pads.isEmpty else { return lead }
        var result = lead.sorted { $0.stepIndex < $1.stepIndex }
        var dropIndices = Set<Int>()
        for i in 0..<result.count where !dropIndices.contains(i) && !(keepGraces && result[i].durationSteps <= 1) {
            for pad in pads {
                let overlapStart = max(result[i].stepIndex, pad.stepIndex)
                let overlapEnd   = min(result[i].stepIndex + result[i].durationSteps,
                                       pad.stepIndex      + pad.durationSteps)
                guard overlapEnd > overlapStart else { continue }
                guard isDissonant(result[i].note, pad.note) else { continue }
                if pad.stepIndex > result[i].stepIndex {
                    let trimmedDur = pad.stepIndex - result[i].stepIndex - 1
                    if trimmedDur >= 4 {
                        result[i] = MIDIEvent(stepIndex: result[i].stepIndex, note: result[i].note,
                                              velocity: result[i].velocity, durationSteps: trimmedDur)
                    } else { dropIndices.insert(i) }
                } else {
                    dropIndices.insert(i)
                }
                break
            }
        }
        return result.indices.filter { !dropIndices.contains($0) }.map { result[$0] }
    }

    /// Trims or drops notes that form dissonant intervals when sustained simultaneously.
    /// Catches: minor 2nd (1), tritone (6), major 7th (11), bass major 2nd (2 when both < 57).
    private static func trimDissonances(_ events: [MIDIEvent], totalSteps: Int) -> [MIDIEvent] {
        func isDissonant(_ a: UInt8, _ b: UInt8) -> Bool {
            // A major 2nd only clashes as a real close second low down; a 9th over a low root or
            // drone is colour, and treating it as a clash dropped Satie's suspended-2nd endings.
            let ivl = abs(Int(a) - Int(b)) % 12
            return ivl == 1 || ivl == 6 || ivl == 11 || (abs(Int(a) - Int(b)) == 2 && Swift.min(a, b) < 55)
        }
        var trimmed = events.filter { $0.stepIndex < totalSteps }.sorted { $0.stepIndex < $1.stepIndex }
        var dropIndices = Set<Int>()
        for i in 0..<trimmed.count where !dropIndices.contains(i) {
            for j in (i + 1)..<trimmed.count where !dropIndices.contains(j) {
                let b = trimmed[j]
                guard b.stepIndex < trimmed[i].stepIndex + trimmed[i].durationSteps else { break }
                if isDissonant(trimmed[i].note, b.note) {
                    if b.stepIndex == trimmed[i].stepIndex {
                        // Same start step — drop the quieter note
                        dropIndices.insert(trimmed[i].velocity >= b.velocity ? j : i)
                    } else {
                        let trimmedDur = b.stepIndex - trimmed[i].stepIndex - 1
                        if trimmedDur >= 4 {
                            // If the later note is much shorter (bass intruding on a sustained
                            // melody), drop the intruder rather than truncating the melody.
                            if b.durationSteps * 2 < trimmed[i].durationSteps {
                                dropIndices.insert(j)
                            } else {
                                trimmed[i] = MIDIEvent(stepIndex: trimmed[i].stepIndex, note: trimmed[i].note,
                                                       velocity: trimmed[i].velocity, durationSteps: trimmedDur)
                            }
                        } else if b.durationSteps < trimmed[i].durationSteps {
                            dropIndices.insert(j)
                        } else if trimmedDur >= 1 {
                            trimmed[i] = MIDIEvent(stepIndex: trimmed[i].stepIndex, note: trimmed[i].note,
                                                   velocity: trimmed[i].velocity, durationSteps: trimmedDur)
                        } else {
                            dropIndices.insert(trimmed[i].velocity >= b.velocity ? j : i)
                        }
                    }
                }
            }
        }
        return trimmed.indices.filter { !dropIndices.contains($0) }.map { trimmed[$0] }
    }

}

private extension Array {
    /// Fisher-Yates with the song's own RNG (SeededRNG isn't a RandomNumberGenerator).
    func seededShuffle(_ rng: inout SeededRNG) -> [Element] {
        var a = self
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) { a.swapAt(i, rng.nextInt(upperBound: i + 1)) }
        return a
    }
}
