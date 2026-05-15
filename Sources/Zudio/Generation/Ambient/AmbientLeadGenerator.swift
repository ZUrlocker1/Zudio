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

    static func generateAmbientPianoLead(
        pianoRule: String,
        frame: GlobalMusicalFrame,
        totalBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        usedRuleIDs.insert(pianoRule)
        switch pianoRule {
        case "AMB-PNO-001": return floatingTonesFullSong(frame: frame, totalBars: totalBars, rng: &rng, usedRuleIDs: &usedRuleIDs)
        case "AMB-PNO-003": return dramaticArcFullSong(frame: frame, totalBars: totalBars, rng: &rng)
        default:            return pensiveMelodyFullSong(frame: frame, totalBars: totalBars, rng: &rng)
        }
    }

    // MARK: AMB-PNO-001 — Floating Tones (Harold Budd)

    private static func floatingTonesFullSong(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let r = rng.nextDouble()
        if r < 0.25 {
            usedRuleIDs.remove("AMB-PNO-001"); usedRuleIDs.insert("AMB-PNO-001-BT")
            return floatingTonesMode1(frame: frame, totalBars: totalBars, rng: &rng)
        }
        if r < 0.75 {
            usedRuleIDs.remove("AMB-PNO-001"); usedRuleIDs.insert("AMB-PNO-001-CW")
            return floatingTonesMode2(frame: frame, totalBars: totalBars, rng: &rng)
        }
        usedRuleIDs.remove("AMB-PNO-001"); usedRuleIDs.insert("AMB-PNO-001-PD")
        return floatingTonesMode3(frame: frame, totalBars: totalBars, rng: &rng)
    }

    /// Mode 1 — Sparse floating: chord wash + 4-7 sparse events.
    private static func floatingTonesMode1(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let evtNotes = notesInRegister(pitchClasses: scalePCs, low: 55, high: 84)
        guard !evtNotes.isEmpty else { return [] }

        let colorIdx = rng.nextInt(upperBound: evtNotes.count)
        var lastIdx: Int = -1
        var events: [MIDIEvent] = []

        let minEvents  = Swift.max(16, totalBars / 5)
        let eventCount = minEvents + rng.nextInt(upperBound: 6)
        var cursor = (1 + rng.nextInt(upperBound: 2)) * 16

        for i in 0..<eventCount {
            guard cursor < totalSteps - 2 * 16 else { break }
            let roll = rng.nextDouble()

            if roll < 0.07 {
                // Single bell-tone — short, clear, not sustained beyond piano decay
                var idx = rng.nextInt(upperBound: evtNotes.count)
                if rng.nextDouble() < 0.25 && lastIdx >= 0 { idx = lastIdx }
                else if rng.nextDouble() < 0.15 { idx = colorIdx }
                lastIdx = idx
                let dur = Swift.min(8 + rng.nextInt(upperBound: 9), totalSteps - cursor)
                if dur >= 4 {
                    events.append(MIDIEvent(stepIndex: cursor, note: evtNotes[idx],
                                            velocity: UInt8(24 + rng.nextInt(upperBound: 18)),
                                            durationSteps: dur))
                }

            } else if roll < 0.24 {
                // Arpeggiated dyad — 2nd note 2-4 steps after 1st, within piano sustain (10-16 steps each)
                let idx   = rng.nextInt(upperBound: evtNotes.count)
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
                let startIdx = evtNotes.count / 2 + rng.nextInt(upperBound: Swift.max(1, evtNotes.count / 2))
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
                let resolveIdx = Swift.max(0, leapIdx - 1 - rng.nextInt(upperBound: 2))
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

        // Idea 1: Grace note connectors — for ~60% of gaps where silence follows a note end,
        // insert one very soft scale-adjacent note to bridge the space between phrases.
        let sorted = events.sorted { $0.stepIndex < $1.stepIndex }
        var connectors: [MIDIEvent] = []
        for i in 0..<sorted.count - 1 {
            let noteEnd = sorted[i].stepIndex + sorted[i].durationSteps
            let nextStart = sorted[i + 1].stepIndex
            let silence = nextStart - noteEnd
            guard silence > 24 else { continue }           // only bridge real gaps (> 1.5 bars)
            guard rng.nextDouble() < 0.60 else { continue }
            guard let lastEIdx = evtNotes.firstIndex(of: sorted[i].note) else { continue }
            let delta       = rng.nextDouble() < 0.50 ? 1 : -1
            let neighborIdx = Swift.max(0, Swift.min(evtNotes.count - 1, lastEIdx + delta))
            let connStep    = noteEnd + 4 + rng.nextInt(upperBound: Swift.max(1, silence / 2 - 4))
            let connDur     = Swift.min(6 + rng.nextInt(upperBound: 5), nextStart - connStep - 2)
            guard connDur >= 4 && connStep < nextStart - 2 else { continue }
            connectors.append(MIDIEvent(stepIndex: connStep, note: evtNotes[neighborIdx],
                                        velocity: UInt8(14 + rng.nextInt(upperBound: 9)),
                                        durationSteps: connDur))
        }
        events.append(contentsOf: connectors)

        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    /// Mode 2 — Revealed chords: two alternating chords with melodic fragments woven into every gap.
    /// Two-pass design: Pass 1 places chord events with proportional spacing (max 4-bar gap);
    /// Pass 2 emits each chord plus a continuation gesture that fills the silence with either
    /// an arpeggio reveal, a stepwise melodic drift, or a soft echo cascade. Velocity follows
    /// a gentle arc (softer opening and closing, fuller middle) for even dynamic balance.
    private static func floatingTonesMode2(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG
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
        let b3    = snapToScale(root + 3)
        let p5    = snapToScale(root + 7)
        let color = snapToScale(rng.nextDouble() < 0.50 ? root + 10 : root + 9)

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

        let chordA    = voice([root, b3, p5], bass: aBass)
        let chordB    = voice([b3, p5, color], bass: bBass)
        let baseVel   = 38 + rng.nextInt(upperBound: 12)
        let scaleHigh = notesInRegister(pitchClasses: Set(frame.scalePCs), low: 62, high: 85)
        var events:   [MIDIEvent] = []

        // ── Pass 1: distribute chord events with proportional spacing, gap capped at 4 bars ──
        struct ChordSlot { var step: Int; var chord: [UInt8]; var dur: Int; var vel: UInt8 }
        var slots:  [ChordSlot] = []
        var cursor = 0
        var useA   = true
        let target = 16 + rng.nextInt(upperBound: 10)   // 16–25 events

        for i in 0..<target {
            guard cursor < totalSteps - 16 else { break }
            let chord = useA ? chordA : chordB
            // Velocity arc: quieter at start and end, fuller in the middle third
            let songPos  = Double(cursor) / Double(totalSteps)
            let arcBoost = songPos < 0.25 ? Int(songPos * 4 * 10) :
                           songPos > 0.75 ? Int((1.0 - songPos) * 4 * 10) : 10
            let vel = UInt8(Swift.max(28, Swift.min(70, baseVel - 6 + arcBoost + rng.nextInt(upperBound: 11))))
            var dur = 0

            if rng.nextDouble() < 0.15 && i > 0 {
                // Occasional single "breath" note — one mid voice only
                let bNote = chord.count > 1 ? chord[1] : chord[0]
                let bDur  = Swift.min(10 + rng.nextInt(upperBound: 7), totalSteps - cursor)
                if bDur >= 4 { slots.append(ChordSlot(step: cursor, chord: [bNote], dur: bDur, vel: vel)) }
                dur = Swift.max(bDur, 4)
            } else {
                dur = rng.nextDouble() < 0.50
                    ? Swift.min(10 + rng.nextInt(upperBound: 7), totalSteps - cursor)   // 10-16 steps (~1 bar)
                    : Swift.min(16 + rng.nextInt(upperBound: 13), totalSteps - cursor)  // 16-28 steps (≤1.75 bars)
                if dur >= 4 { slots.append(ChordSlot(step: cursor, chord: chord, dur: dur, vel: vel)) }
            }
            useA.toggle()

            // Proportional gap capped at 64 steps (4 bars) — prevents dead zones
            let eventsLeft = target - i - 1
            let remaining  = Swift.max(1, totalSteps - cursor - dur)
            let avgGap     = eventsLeft > 0 ? remaining / (eventsLeft + 1) : remaining / 2
            let rawGap     = rng.nextDouble() < 0.60
                ? Swift.max(8,  avgGap / 2 + rng.nextInt(upperBound: Swift.max(1, avgGap / 4)))
                : Swift.max(16, avgGap     + rng.nextInt(upperBound: Swift.max(1, avgGap / 3)))
            cursor += dur + Swift.min(rawGap, 64)
        }

        // ── Pass 2: emit chord notes + immediate echo + continuation gesture ─────────
        for (idx, slot) in slots.enumerated() {
            let nextStart = idx + 1 < slots.count ? slots[idx + 1].step : totalSteps
            let gapStart  = slot.step + slot.dur + 2
            let gapEnd    = Swift.max(gapStart, nextStart - 4)
            let gapSize   = gapEnd - gapStart

            // Chord (or breath) notes
            for note in slot.chord {
                events.append(MIDIEvent(stepIndex: slot.step, note: note,
                                        velocity: slot.vel, durationSteps: slot.dur))
            }

            // Immediate echo: top voice steps to scale neighbor right after chord
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
                                                    velocity: UInt8(Swift.max(22, Int(slot.vel) - 14)),
                                                    durationSteps: e1dur))
                            let e2start = echoStart + e1dur + 1
                            if e2start < totalSteps {
                                let nb2Idx = goUp ? Swift.min(nb1Idx + 1, scaleHigh.count - 1) : Swift.max(0, nb1Idx - 1)
                                let nb2    = scaleHigh[nb2Idx]
                                let e2dur  = Swift.min(5 + rng.nextInt(upperBound: 9), totalSteps - e2start)
                                if e2dur >= 2 && nb2 != nb1 {
                                    events.append(MIDIEvent(stepIndex: e2start, note: nb2,
                                                            velocity: UInt8(Swift.max(18, Int(slot.vel) - 20)),
                                                            durationSteps: e2dur))
                                    if rng.nextDouble() < 0.60 {
                                        let e3start = e2start + e2dur + 2
                                        let e3dur   = Swift.min(4 + rng.nextInt(upperBound: 8), totalSteps - e3start)
                                        if e3start < totalSteps && e3dur >= 2 {
                                            events.append(MIDIEvent(stepIndex: e3start, note: nb1,
                                                                    velocity: UInt8(Swift.max(16, Int(slot.vel) - 24)),
                                                                    durationSteps: e3dur))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Continuation gesture — fills every gap > 2 bars with musical content
            guard gapSize >= 32, !scaleHigh.isEmpty else { continue }
            let gestureRoll = rng.nextDouble()

            if gestureRoll < 0.35 {
                // Arpeggio reveal: chord tones enter one by one, each held ~half-bar so they
                // briefly overlap before decaying. Short notes keep the sweep within piano sustain.
                var s = gapStart + 4 + rng.nextInt(upperBound: 8)
                for note in slot.chord {
                    guard s + 6 < gapEnd else { break }
                    let noteDur = Swift.min(8 + rng.nextInt(upperBound: 7), gapEnd - s)  // 8-14 steps (≤1 bar)
                    events.append(MIDIEvent(stepIndex: s, note: note,
                                            velocity: UInt8(Swift.max(14, Int(slot.vel) - 22)),
                                            durationSteps: noteDur))
                    s += 4 + rng.nextInt(upperBound: 5)
                }
            } else if gestureRoll < 0.68 {
                // Melodic drift: stepwise ascending or descending figure from the chord top,
                // last note held long — Budd's signature climbing or descending gesture.
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
                        ? Swift.min(8 + rng.nextInt(upperBound: 9), gapEnd - s)   // 8-16 steps (≤1 bar)
                        : Swift.min(3 + rng.nextInt(upperBound: 3), gapEnd - s)
                    guard noteDur >= 2 else { break }
                    events.append(MIDIEvent(stepIndex: s, note: scaleHigh[noteIdx],
                                            velocity: UInt8(Swift.max(14, Int(slot.vel) - 12 - n * 3)),
                                            durationSteps: noteDur))
                    s += noteDur + 2 + rng.nextInt(upperBound: 4)
                    // 25% chance of a 2-step leap instead of stepwise — avoids pure scale runs
                    let step = rng.nextDouble() < 0.25 ? 2 : 1
                    noteIdx = ascending
                        ? Swift.min(noteIdx + step, scaleHigh.count - 1)
                        : Swift.max(0, noteIdx - step)
                }
            } else {
                // Turn ornament: brief upward reversal then continued descent — avoids the
                // static pedal tone that results from repeating the same chord note.
                // Shape: top → +1 (reversal) → top → -1 → -2 → -3 (descent), each note
                // softer and spaced slightly further apart.
                let topNote  = slot.chord.last ?? slot.chord[0]
                let startIdx = scaleHigh.firstIndex(of: topNote) ?? (scaleHigh.count / 2)
                // Build the turn contour: up 1, back to start, then descend 2-3 steps
                let descentCount = 2 + rng.nextInt(upperBound: 2)  // 2 or 3 descending steps after reversal
                var idxOffsets = [1, 0]  // reversal: up then back
                for d in 1...descentCount { idxOffsets.append(-d) }
                var s = gapStart + 6 + rng.nextInt(upperBound: 10)
                for (n, offset) in idxOffsets.enumerated() {
                    guard s + 6 < gapEnd else { break }
                    let idx     = Swift.max(0, Swift.min(startIdx + offset, scaleHigh.count - 1))
                    let isLast  = n == idxOffsets.count - 1
                    let noteDur = isLast
                        ? Swift.min(8 + rng.nextInt(upperBound: 9), gapEnd - s)   // 8-16 steps (≤1 bar)
                        : Swift.min(3 + rng.nextInt(upperBound: 4), gapEnd - s)
                    guard noteDur >= 2 else { break }
                    events.append(MIDIEvent(stepIndex: s, note: scaleHigh[idx],
                                            velocity: UInt8(Swift.max(12, Int(slot.vel) - 14 - n * 5)),
                                            durationSteps: noteDur))
                    s += noteDur + 3 + rng.nextInt(upperBound: 5)
                }
            }
        }

        // ── Closing chord: strong tonic resolution when the song trails off too early ──
        // Fires only when the last gesture ends ≥ 9 bars before the song end.
        let lastStep   = events.map(\.stepIndex).max() ?? 0
        let trailSteps = totalSteps - lastStep
        if trailSteps > 9 * 16 {
            let closingStep = totalSteps - (9 + rng.nextInt(upperBound: 2)) * 16
            let closingDur  = Swift.min(totalSteps - closingStep - 4, 2 * 16)  // 2 bar max — piano decays past that
            if closingStep > lastStep + 16 && closingDur >= 16 {
                let closingVel = UInt8(Swift.max(50, Swift.min(72, Int(baseVel) + 20)))
                for note in chordB {
                    events.append(MIDIEvent(stepIndex: closingStep, note: note,
                                            velocity: closingVel,
                                            durationSteps: closingDur))
                }
            }
        }

        return events.filter { $0.stepIndex < totalSteps }.sorted { $0.stepIndex < $1.stepIndex }
    }

    /// Mode 3 — Chromatic pendulum: metronomic A↔B cluster oscillation every beat.
    private static func floatingTonesMode3(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG
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
        var oCursor  = 16  // bar 2
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
            let fragVel   = UInt8(Swift.max(12, velBase - 10))
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
        var step = pendStart * 16; var useA = true
        while step < pendEnd * 16 && step < totalSteps {
            let primaryNote = useA ? a0 : a1  // alternate adjacent scale tones → stepwise motion
            let harmNote    = useA ? a2 : a3  // optional chord harmony a third above
            let dur = Swift.min(3 + rng.nextInt(upperBound: 2), totalSteps - step)
            let clVel = UInt8(Swift.max(36, Swift.min(68, baseVel3 + rng.nextInt(upperBound: 13) - 6)))
            guard primaryNote >= 21 && primaryNote <= 108 else { useA.toggle(); step += 4; continue }
            events.append(MIDIEvent(stepIndex: step, note: UInt8(primaryNote), velocity: clVel, durationSteps: dur))
            if rng.nextDouble() < 0.35 && harmNote != primaryNote && harmNote >= 21 && harmNote <= 108 {
                events.append(MIDIEvent(stepIndex: step, note: UInt8(harmNote),
                                        velocity: UInt8(clVel > 8 ? clVel - 8 : clVel), durationSteps: dur))
            }
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
            let fragVel   = UInt8(Swift.max(10, velBase - 10))
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

        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    // MARK: AMB-PNO-002 — Pensive Melody (Satie / Arnalds)

    private static func pensiveMelodyFullSong(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let upper = notesInRegister(pitchClasses: scalePCs, low: 65, high: 77)
        let lower = notesInRegister(pitchClasses: scalePCs, low: 53, high: 63)
        let all   = notesInRegister(pitchClasses: scalePCs, low: 53, high: 77)
        guard upper.count >= 2, lower.count >= 2 else { return [] }

        // Setup — once per song
        let pivotIdx = rng.nextInt(upperBound: upper.count)
        let pivot    = upper[pivotIdx]
        // Neighbor = next scale tone above pivot (always in-scale, Satie-style close interval)
        let neighbor = upper[Swift.min(pivotIdx + 1, upper.count - 1)]
        // Prefer scale root (70%) or 5th (20%) for lower anchor — tonal stability à la Satie
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

        // Phrase type: 0=arc 1=oscillation 2=cadence
        func phraseType() -> Int {
            let r = rng.nextDouble()
            return r < 0.70 ? 0 : (r < 0.90 ? 1 : 2)
        }

        var events: [MIDIEvent] = []

        // Phrase 1 — three opening characters:
        //   30% nearLight (Arnalds chord-texture)
        //   40% Jarrett sparse opening (5-note motif + long hold + bass pedal)
        //   30% standard pno002Phrase arc
        let p1off = rng.nextInt(upperBound: Swift.max(1, wLen / 2))
        if useNearLight {
            events += nearLightTexture(startStep: w1 + p1off, pivot: pivot,
                                       upper: upper, lower: lower, all: all,
                                       totalSteps: totalSteps, rng: &rng)
        } else if rng.nextDouble() < 0.65 {
            events += jarrettSparseOpening(startStep: w1 + p1off, upper: upper, lower: lower,
                                           totalSteps: totalSteps, rng: &rng)
        } else {
            events += pno002Phrase(type: phraseType(), startStep: w1 + p1off,
                                   pivot: pivot, neighbor: neighbor, lowerAnchor: lowerAnchor,
                                   upper: upper, lower: lower, totalSteps: totalSteps, rng: &rng)
        }

        // Phrase 2 (optional pivot transpose — advance 1-2 pool indices to stay in scale)
        let p2Pivot: UInt8
        let p2Nb: UInt8
        if rng.nextDouble() < 0.50 {
            let shift     = 1 + rng.nextInt(upperBound: 2)  // 1 or 2 pool steps up
            let p2PivIdx  = Swift.min(pivotIdx + shift, upper.count - 1)
            p2Pivot = upper[p2PivIdx]
            p2Nb    = upper[Swift.min(p2PivIdx + 1, upper.count - 1)]
        } else { p2Pivot = pivot; p2Nb = neighbor }
        let p2off = rng.nextInt(upperBound: Swift.max(1, wLen / 2))
        events += pno002Phrase(type: phraseType(), startStep: w2 + p2off,
                               pivot: p2Pivot, neighbor: p2Nb, lowerAnchor: lowerAnchor,
                               upper: upper, lower: lower, totalSteps: totalSteps, rng: &rng)

        // Phrase 3 — revealed chord returns 2-3 times (Satie's recognizable repetition)
        let p3roll  = rng.nextDouble()
        let p3type  = p3roll < 0.80 ? (useNearLight ? 0 : phraseType()) : 2
        let p3off   = rng.nextInt(upperBound: Swift.max(1, wLen / 2))
        let p3start = w3 + p3off
        events += pno002Phrase(type: p3type, startStep: p3start,
                               pivot: pivot, neighbor: neighbor, lowerAnchor: lowerAnchor,
                               upper: upper, lower: lower, totalSteps: totalSteps, rng: &rng)
        // Echo: same chord returns 1-2 more times, 5-7 bars apart, before the closing cadence
        let p3echoes = 1 + (rng.nextDouble() < 0.60 ? 1 : 0)
        var p3cursor = p3start
        for _ in 0..<p3echoes {
            p3cursor += (5 + rng.nextInt(upperBound: 3)) * 16
            guard p3cursor < w4 else { break }
            events += pno002Phrase(type: p3type, startStep: p3cursor,
                                   pivot: pivot, neighbor: neighbor, lowerAnchor: lowerAnchor,
                                   upper: upper, lower: lower, totalSteps: totalSteps, rng: &rng)
        }

        // Phrase 4 — closing cadence
        let p4off = rng.nextInt(upperBound: Swift.max(1, wLen / 2))
        events += pno002Phrase(type: 2, startStep: w4 + p4off,
                               pivot: pivot, neighbor: neighbor, lowerAnchor: lowerAnchor,
                               upper: upper, lower: lower, totalSteps: totalSteps, rng: &rng)

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
                let note = rng.nextDouble() < 0.65 ? qNote1 : qNote2
                let dur  = Swift.min(8 + rng.nextInt(upperBound: 7), totalSteps - qs)
                if dur >= 4 { events.append(MIDIEvent(stepIndex: qs, note: note, velocity: UInt8(20 + rng.nextInt(upperBound: 10)), durationSteps: dur)) }
                qb += 7 + rng.nextInt(upperBound: 4)
            }
        }

        // Satie-style left-hand accompaniment: bass on beat 1, 2-note chord on beat 2.
        // lhChord at 62-73 (above middle C) so chord tones register as melody, not bass.
        // Bass alternates tonic / subdominant (Satie's characteristic IV→I rocking).
        let lhBass  = notesInRegister(pitchClasses: scalePCs, low: 40, high: 54)
        let lhChord = notesInRegister(pitchClasses: scalePCs, low: 62, high: 73)
        if !lhBass.isEmpty, !lhChord.isEmpty {
            let rootPC5   = frame.keySemitoneValue % 12
            let fifthPC5  = (rootPC5 + 7) % 12
            let fourthPC5 = (rootPC5 + 5) % 12
            let bassRoot  = lhBass.first(where: { Int($0) % 12 == rootPC5  }) ?? lhBass[0]
            let bassFifth = lhBass.first(where: { Int($0) % 12 == fifthPC5 }) ?? lhBass[lhBass.count / 2]
            let bassFour  = lhBass.first(where: { Int($0) % 12 == fourthPC5 }) ?? bassFifth
            // Base chord tones — two notes separated by a 3rd in the mid-treble register
            let c1BaseIdx = rng.nextInt(upperBound: Swift.max(1, lhChord.count / 2))
            for bar in 0..<totalBars {
                let barStep = bar * 16
                guard barStep < totalSteps else { break }
                // Bass: tonic bars vs subdominant/dominant bars (Satie's rocking alternation)
                let bassNote = bar % 2 == 0 ? bassRoot : (rng.nextDouble() < 0.60 ? bassFifth : bassFour)
                let bassVel  = UInt8(30 + rng.nextInt(upperBound: 8))
                // Jarrett/Satie: bass held for a half note (12 steps) — pedal, not a click
                events.append(MIDIEvent(stepIndex: barStep, note: bassNote, velocity: bassVel, durationSteps: 12))
                // Beat 2 (step 8): 2-note chord — cycle indices so chords vary bar to bar
                if barStep + 8 < totalSteps {
                    let c1Idx = (c1BaseIdx + bar) % lhChord.count
                    let c2Idx = (c1Idx + 2) % lhChord.count
                    let c1    = lhChord[c1Idx]
                    let c2    = lhChord[c2Idx]
                    let cv    = UInt8(22 + rng.nextInt(upperBound: 8))
                    events.append(MIDIEvent(stepIndex: barStep + 8, note: c1, velocity: cv, durationSteps: 7))
                    events.append(MIDIEvent(stepIndex: barStep + 8, note: c2, velocity: cv - 3, durationSteps: 7))
                }
                // Beat 3 (step 12): lighter chord note — only 35% of bars to keep breathing room
                if barStep + 12 < totalSteps, rng.nextDouble() < 0.35 {
                    let c3Idx = (c1BaseIdx + bar + 1) % lhChord.count
                    events.append(MIDIEvent(stepIndex: barStep + 12, note: lhChord[c3Idx],
                                            velocity: UInt8(16 + rng.nextInt(upperBound: 6)), durationSteps: 5))
                }
            }
        }

        return events.filter { $0.stepIndex < totalSteps }.sorted { $0.stepIndex < $1.stepIndex }
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

    private static func pno002Phrase(
        type: Int, startStep: Int, pivot: UInt8, neighbor: UInt8, lowerAnchor: UInt8,
        upper: [UInt8], lower: [UInt8], totalSteps: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard startStep < totalSteps else { return [] }
        var events: [MIDIEvent] = []
        var cur = startStep
        // Cap at 52 — ambient piano lives in ppp–mp; Satie/Arnalds/Jarrett are never forte.
        let cap: (Int) -> UInt8 = { UInt8(Swift.min($0, 52)) }

        switch type {
        case 0: // Standard two-register arc (Satie/Arnalds: spacious pivot-neighbor oscillation)
            // Opening gesture (90%) — scale neighbor above pivot, settle back; held quarter-to-half note
            if rng.nextDouble() < 0.90 && cur + 7 < totalSteps {
                let pivIdx   = upper.firstIndex(of: pivot) ?? (upper.count / 2)
                let openIdx  = Swift.min(pivIdx + 1 + rng.nextInt(upperBound: 2), upper.count - 1)
                let openNote = upper[openIdx]
                events.append(MIDIEvent(stepIndex: cur, note: openNote, velocity: cap(42), durationSteps: 6)); cur += 8
                events.append(MIDIEvent(stepIndex: cur, note: pivot,    velocity: cap(38), durationSteps: 10)); cur += 13
            }
            // Upper oscillation — 3-5 cycles with quarter-to-dotted-quarter spacing (Satie's breath)
            let cycles  = 3 + rng.nextInt(upperBound: 3)   // 3-5
            let ioi     = 3 + rng.nextInt(upperBound: 3)    // 3-5 steps
            let noteDur = 2 + rng.nextInt(upperBound: 3)    // 2-4 steps
            for c in 0..<cycles {
                guard cur < totalSteps else { break }
                let velPiv = cap(34 + c * 4 + 3)   // 37 → 51 over 5 cycles
                let velNbr = cap(32 + c * 4)        // 32 → 48
                // Broken chord variant 30%
                if rng.nextDouble() < 0.30, !lower.isEmpty {
                    let fifth = lower[rng.nextInt(upperBound: lower.count)]
                    events.append(MIDIEvent(stepIndex: cur, note: pivot, velocity: velPiv, durationSteps: noteDur)); cur += ioi
                    if cur < totalSteps { events.append(MIDIEvent(stepIndex: cur, note: fifth, velocity: velNbr, durationSteps: noteDur)); cur += ioi }
                    if cur < totalSteps { events.append(MIDIEvent(stepIndex: cur, note: neighbor, velocity: velNbr, durationSteps: noteDur)); cur += ioi }
                } else {
                    events.append(MIDIEvent(stepIndex: cur, note: pivot, velocity: velPiv, durationSteps: noteDur)); cur += ioi
                    if cur < totalSteps { events.append(MIDIEvent(stepIndex: cur, note: neighbor, velocity: velNbr, durationSteps: noteDur)); cur += ioi }
                }
            }
            // Suspension → resolution (60%) — resolve to scale neighbor below pivot
            if rng.nextDouble() < 0.60 && cur < totalSteps {
                let sd = Swift.min(6 + rng.nextInt(upperBound: 3), totalSteps - cur)
                events.append(MIDIEvent(stepIndex: cur, note: pivot, velocity: cap(50), durationSteps: sd)); cur += sd
                if cur < totalSteps {
                    let pivIdx = upper.firstIndex(of: pivot) ?? 0
                    let resIdx = Swift.max(0, pivIdx - 1 - rng.nextInt(upperBound: 2))
                    let res    = upper[resIdx]
                    events.append(MIDIEvent(stepIndex: cur, note: res, velocity: cap(44), durationSteps: Swift.min(4, totalSteps - cur))); cur += 5
                }
            }
            // Leap down to lower register — use lower pool directly for scale-correct landing
            if cur < totalSteps, !lower.isEmpty {
                let land = lower[rng.nextInt(upperBound: lower.count)]
                let ld   = Swift.min(8 + rng.nextInt(upperBound: 9), totalSteps - cur)
                events.append(MIDIEvent(stepIndex: cur, note: land, velocity: cap(40), durationSteps: ld)); cur += ld
            }
            // Lower settlement (60%)
            if rng.nextDouble() < 0.60 && cur < totalSteps, !lower.isEmpty {
                if rng.nextDouble() < 0.35 {
                    // Exhausted landing oscillation
                    let li = rng.nextInt(upperBound: lower.count)
                    for _ in 0..<(2 + rng.nextInt(upperBound: 2)) {
                        guard cur < totalSteps else { break }
                        events.append(MIDIEvent(stepIndex: cur, note: lower[li], velocity: 30, durationSteps: Swift.min(3, totalSteps - cur))); cur += 4
                        if cur < totalSteps {
                            events.append(MIDIEvent(stepIndex: cur, note: lower[Swift.max(0, li - 1)], velocity: 26, durationSteps: Swift.min(3, totalSteps - cur))); cur += 4
                        }
                    }
                }
                if cur < totalSteps {
                    let finalNote = rng.nextDouble() < 0.30 ? lower[rng.nextInt(upperBound: lower.count)] : lowerAnchor
                    let fd = Swift.min(10 + rng.nextInt(upperBound: 11), totalSteps - cur)
                    events.append(MIDIEvent(stepIndex: cur, note: finalNote, velocity: 28, durationSteps: fd))
                }
            }

        case 1: // Pure oscillation
            let osc = 3 + rng.nextInt(upperBound: 2)
            let ioi = 3 + rng.nextInt(upperBound: 3)
            for i in 0..<(osc * 2) {
                guard cur < totalSteps else { break }
                let note = i % 2 == 0 ? pivot : neighbor
                let vel  = cap(30 + i * 3)
                events.append(MIDIEvent(stepIndex: cur, note: note, velocity: vel, durationSteps: Swift.min(2 + rng.nextInt(upperBound: 3), totalSteps - cur))); cur += ioi
            }
            if cur < totalSteps, !lower.isEmpty {
                let fall = lower[rng.nextInt(upperBound: lower.count)]
                events.append(MIDIEvent(stepIndex: cur, note: fall, velocity: cap(40), durationSteps: Swift.min(5, totalSteps - cur))); cur += 7
            }
            if cur < totalSteps {
                events.append(MIDIEvent(stepIndex: cur, note: lowerAnchor, velocity: 30,
                                        durationSteps: Swift.min(12 + rng.nextInt(upperBound: 9), totalSteps - cur)))
            }

        default: // Short cadence — all notes from scale pools, stepwise descent
            guard !lower.isEmpty, !upper.isEmpty else { break }
            let startNote = lower[rng.nextInt(upperBound: lower.count)]
            let peakIdx   = rng.nextInt(upperBound: upper.count)
            let midNote   = upper[peakIdx]
            events.append(MIDIEvent(stepIndex: cur, note: startNote, velocity: 34, durationSteps: Swift.min(5, totalSteps - cur))); cur += 6
            if cur < totalSteps {
                events.append(MIDIEvent(stepIndex: cur, note: midNote, velocity: cap(46), durationSteps: Swift.min(4, totalSteps - cur))); cur += 5
            }
            let descentCount = 2 + rng.nextInt(upperBound: 2)
            for i in 0..<descentCount {
                guard cur < totalSteps else { break }
                let dnIdx = Swift.max(0, peakIdx - i - 1)
                events.append(MIDIEvent(stepIndex: cur, note: upper[dnIdx], velocity: cap(38 - i * 3), durationSteps: Swift.min(4, totalSteps - cur))); cur += 5
            }
            if cur < totalSteps {
                events.append(MIDIEvent(stepIndex: cur, note: lowerAnchor, velocity: 28,
                                        durationSteps: Swift.min(10 + rng.nextInt(upperBound: 7), totalSteps - cur)))
            }
        }
        return events
    }

    // MARK: AMB-PNO-003 — Dramatic Arc (Winston / Jarrett)

    private static func dramaticArcFullSong(
        frame: GlobalMusicalFrame, totalBars: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let scalePCs   = frame.scalePCs
        let midNotes   = notesInRegister(pitchClasses: scalePCs, low: 60, high: 79)  // wider: C4-G5
        let highNotes  = notesInRegister(pitchClasses: scalePCs, low: 69, high: 89)
        let lowNotes   = notesInRegister(pitchClasses: scalePCs, low: 28, high: 46)
        guard !midNotes.isEmpty, !highNotes.isEmpty else { return [] }

        let use4Phrase    = rng.nextDouble() < 0.25
        let useCallResp   = rng.nextDouble() < 0.40
        let useOstinato   = rng.nextDouble() < 0.25
        let usePostClimax = rng.nextDouble() < 0.50
        let useParting    = rng.nextDouble() < 0.50

        // All phrase positions scale proportionally to totalBars so the arc spans the full song.
        // Climax at 60%: long, light build (0–60%) with compressed 40% resolution tail.
        // p1Bar=1 ensures piano enters after at most 1 bar of silence.
        let p1Bar        = 1
        let climaxBar    = totalBars * 60 / 100
        let withdrawBar  = totalBars * 73 / 100
        let closingBar   = totalBars * 87 / 100
        let bass1Bar     = totalBars * 20 / 100
        let bass2Bar     = totalBars * 65 / 100
        let preclimaxBar = use4Phrase ? totalBars * 42 / 100 : -1

        var events: [MIDIEvent] = []

        // Helper: emit a burst-style phrase with directional melodic motion (Winston/Jarrett stepwise singing line)
        func emitBurst(bar: Int, pool: [UInt8], count: Int, velMin: Int, velMax: Int, ioi: Int, holdDur: Int, startNear: Int = -1) -> (events: [MIDIEvent], endIdx: Int) {
            guard bar < totalBars, bar >= 0, !pool.isEmpty else { return ([], pool.count / 2) }
            var ev: [MIDIEvent] = []
            var step = bar * 16 + rng.nextInt(upperBound: 4)
            var ascending: Bool
            var idx: Int
            if startNear >= 0 && startNear < pool.count {
                // Continue near previous burst's endpoint to avoid wide inter-phrase leaps
                ascending = startNear < pool.count / 2
                idx = startNear
            } else {
                // Default: random direction and starting position
                ascending = rng.nextDouble() < 0.60
                if ascending {
                    let maxStart = Swift.max(0, pool.count / 3)
                    idx = maxStart > 0 ? rng.nextInt(upperBound: maxStart + 1) : 0
                } else {
                    let minStart = pool.count / 2
                    idx = minStart + (pool.count - minStart > 1 ? rng.nextInt(upperBound: pool.count - minStart) : 0)
                }
            }
            for i in 0..<count {
                guard step < totalSteps else { break }
                let isLast = i == count - 1
                let note = pool[Swift.max(0, Swift.min(idx, pool.count - 1))]
                let dur  = isLast ? Swift.min(holdDur, totalSteps - step) : Swift.min(ioi, totalSteps - step)
                guard dur >= 1 else { break }
                let vel  = UInt8(velMin + rng.nextInt(upperBound: Swift.max(1, velMax - velMin + 1)))
                ev.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: dur))
                // Chord accents: phrase launch (i==0) and phrase peak (~2/3 through) — Jarrett/Winston style
                let isPeak = i == (count * 2 / 3)
                if i == 0 || isPeak {
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
                step += dur + (isLast ? 0 : 1)
                // Advance 1-2 pool indices in chosen direction for natural stepwise motion
                let advance = 1 + (rng.nextDouble() < 0.35 ? 1 : 0)
                idx = ascending ? Swift.min(idx + advance, pool.count - 1) : Swift.max(0, idx - advance)
            }
            return (ev, idx)
        }

        // Phrase 1 (opening) — enters at bar 1, no more than 1 bar of opening silence
        var burstEndIdx: Int = -1
        let p1Result = emitBurst(bar: p1Bar, pool: midNotes, count: 7 + rng.nextInt(upperBound: 4),
                                 velMin: 28, velMax: 42, ioi: 2, holdDur: 12)
        events += p1Result.events; burstEndIdx = p1Result.endIdx

        // Pre-climax phrase in 4-phrase form
        if preclimaxBar > 0 {
            let pcResult = emitBurst(bar: preclimaxBar, pool: midNotes, count: 8 + rng.nextInt(upperBound: 4),
                                     velMin: 38, velMax: 55, ioi: 2, holdDur: 10)
            events += pcResult.events; burstEndIdx = pcResult.endIdx
        }

        // Bass punctuation 1
        if bass1Bar < totalBars, !lowNotes.isEmpty {
            let bn  = lowNotes[rng.nextInt(upperBound: lowNotes.count)]
            let bd  = Swift.min(32 + rng.nextInt(upperBound: 49), totalSteps - bass1Bar * 16)
            if bd >= 4 { events.append(MIDIEvent(stepIndex: bass1Bar * 16, note: bn, velocity: UInt8(28 + rng.nextInt(upperBound: 18)), durationSteps: bd)) }
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
            let fragArr  = Array(midNotes.suffix(Swift.max(1, midNotes.count / 2)))
            let fragLen  = 3 + rng.nextInt(upperBound: 2)
            let fragBase = rng.nextInt(upperBound: Swift.max(1, fragArr.count - fragLen))
            let repeats  = 2 + (rng.nextDouble() < 0.50 ? 1 : 0)
            var qs = urgentBar * 16 + rng.nextInt(upperBound: 4)
            for r in 0..<repeats {
                for n in 0..<fragLen {
                    guard qs < totalSteps else { break }
                    let idx = Swift.min(fragBase + n, fragArr.count - 1)
                    let vel = UInt8(Swift.min(74, 42 + r * 10 + rng.nextInt(upperBound: 8)))
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
                let fNote = fragArr[Swift.min(fragArr.count - 1, fragBase + fragLen)]
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
        if useCallResp {
            let callResult = emitBurst(bar: climaxBar, pool: highNotes, count: 6 + rng.nextInt(upperBound: 3),
                                       velMin: 58, velMax: 88, ioi: 2, holdDur: 8)
            let respResult = emitBurst(bar: climaxBar + 2, pool: midNotes, count: 7 + rng.nextInt(upperBound: 3),
                                       velMin: 45, velMax: 68, ioi: 2, holdDur: 10)
            events += callResult.events + respResult.events
            highestNote = (callResult.events + respResult.events).max(by: { $0.note < $1.note })?.note ?? 0
        } else {
            let cResult = emitBurst(bar: climaxBar, pool: highNotes, count: 9 + rng.nextInt(upperBound: 4),
                                    velMin: 58, velMax: 88, ioi: 2, holdDur: 16)
            events += cResult.events
            highestNote = cResult.events.max(by: { $0.note < $1.note })?.note ?? 0
        }

        // Bold block chord at climax peak — 3-4 simultaneous notes (the "fist on keys" moment).
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
        }

        // Post-climax descending run (50%)
        if usePostClimax {
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
        if echoBar < withdrawBar - 2 {
            events += emitBurst(bar: echoBar, pool: midNotes,
                                count: 6 + rng.nextInt(upperBound: 3),
                                velMin: 35, velMax: 52, ioi: 2, holdDur: 14).events
        }

        // Bass punctuation 2
        if bass2Bar < totalBars, !lowNotes.isEmpty {
            let bn = lowNotes[rng.nextInt(upperBound: lowNotes.count)]
            let bd = Swift.min(32 + rng.nextInt(upperBound: 49), totalSteps - bass2Bar * 16)
            if bd >= 4 { events.append(MIDIEvent(stepIndex: bass2Bar * 16, note: bn, velocity: UInt8(28 + rng.nextInt(upperBound: 18)), durationSteps: bd)) }
        }

        // Withdrawal phrase
        let wPool = midNotes.filter { $0 <= 72 }.isEmpty ? midNotes : midNotes.filter { $0 <= 72 }
        let wStartIdx = burstEndIdx < wPool.count ? burstEndIdx : -1
        var wEvts = emitBurst(bar: withdrawBar, pool: wPool, count: 5 + rng.nextInt(upperBound: 3),
                              velMin: 25, velMax: 42, ioi: 3, holdDur: 20, startNear: wStartIdx).events

        // Parting gesture: copy highest climax note as first note of withdrawal phrase
        if useParting && highestNote > 0 && withdrawBar < totalBars {
            let ps = withdrawBar * 16
            if !wEvts.contains(where: { $0.stepIndex == ps && $0.note == highestNote }) {
                let pd = Swift.min(16 + rng.nextInt(upperBound: 9), totalSteps - ps)
                wEvts.insert(MIDIEvent(stepIndex: ps, note: highestNote, velocity: 42, durationSteps: pd), at: 0)
            }
        }
        events += wEvts

        // Closing phrase — soft lyric fragment in last ~17% of song
        if closingBar < totalBars - 2 {
            let cPool = midNotes.filter { $0 <= 70 }.isEmpty ? midNotes : midNotes.filter { $0 <= 70 }
            events += emitBurst(bar: closingBar, pool: cPool, count: 4 + rng.nextInt(upperBound: 3),
                                velMin: 20, velMax: 35, ioi: 3, holdDur: 24).events
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
                let noteCount = 5 + rng.nextInt(upperBound: 4)
                let ascending = rng.nextDouble() < 0.60
                let idxLo     = Int(Double(midNotes.count - 1) * progress * 0.40)
                let idxHi     = Int(Double(midNotes.count - 1) * (0.35 + progress * 0.55))
                let safeHi    = Swift.min(Swift.max(idxLo, idxHi), midNotes.count - 1)
                let startIdx  = idxLo + (safeHi > idxLo ? rng.nextInt(upperBound: safeHi - idxLo + 1) : 0)
                let velLo     = 28 + Int(progress * 26)   // 28→54 across build
                let velHi     = 40 + Int(progress * 28)   // 40→68 across build
                let phraseIOI = Swift.max(2, 4 - Int(progress * 2.5))  // 4→2 steps
                var s = pBar * 16 + rng.nextInt(upperBound: 6)
                for n in 0..<noteCount {
                    guard s < totalSteps else { break }
                    let idx = ascending
                        ? Swift.min(startIdx + n, midNotes.count - 1)
                        : Swift.max(0, startIdx - n)
                    let isLast = n == noteCount - 1
                    let dur = isLast
                        ? Swift.min(12 + rng.nextInt(upperBound: 9), totalSteps - s)
                        : Swift.min(phraseIOI, totalSteps - s)
                    guard dur >= 1 else { break }
                    let vel = UInt8(velLo + rng.nextInt(upperBound: Swift.max(1, velHi - velLo + 1)))
                    events.append(MIDIEvent(stepIndex: s, note: midNotes[idx], velocity: vel, durationSteps: dur))
                    s += dur + (isLast ? 0 : 1 + rng.nextInt(upperBound: Swift.max(1, phraseIOI)))
                }
                let gap    = Swift.max(2, Int(g * pow(ratio, Double(p))))
                let jitter = rng.nextInt(upperBound: Swift.max(1, gap / 3))
                pBar += gap + jitter
            }
        }

        // Two connective phrases between withdrawal and closing — meditative fragments, not silence
        let decayZone = withdrawBar + 4
        if decayZone < closingBar - 2 {
            let softPool = midNotes.filter { $0 <= 70 }.isEmpty ? midNotes : midNotes.filter { $0 <= 70 }
            let decaySpan = closingBar - decayZone
            // First connective phrase — earlier third of the decay zone
            let conn1Bar = decayZone + rng.nextInt(upperBound: Swift.max(1, decaySpan / 3))
            events += emitBurst(bar: conn1Bar, pool: softPool,
                                count: 7 + rng.nextInt(upperBound: 4),
                                velMin: 22, velMax: 38, ioi: 3, holdDur: 18, startNear: wStartIdx).events
            // Second connective phrase — later two-thirds, fading further
            let conn2Bar = decayZone + decaySpan * 2 / 3 + rng.nextInt(upperBound: Swift.max(1, decaySpan / 4))
            if conn2Bar < closingBar - 1 {
                events += emitBurst(bar: conn2Bar, pool: softPool,
                                    count: 5 + rng.nextInt(upperBound: 3),
                                    velMin: 20, velMax: 34, ioi: 3, holdDur: 20, startNear: wStartIdx).events
            }
        }

        // Aftershock — 1-2 hard chord stabs reminiscent of the climax (vel 68-85),
        // spread between withdrawal and closing before the song truly settles.
        let aftershockBase = withdrawBar + 2
        if aftershockBase < closingBar - 2 && !midNotes.isEmpty {
            let shockCount = 1 + (rng.nextDouble() < 0.50 ? 1 : 0)
            let shockZone  = Swift.max(1, closingBar - aftershockBase)
            let shockPool  = Array(midNotes.suffix(Swift.max(1, midNotes.count / 2)))
            for sh in 0..<shockCount {
                let shockBar = aftershockBase + (shockZone * sh) / Swift.max(1, shockCount)
                guard shockBar < closingBar - 1 else { break }
                let ss      = shockBar * 16 + rng.nextInt(upperBound: 4)
                guard ss < totalSteps - 6 else { break }
                let rootIdx = rng.nextInt(upperBound: Swift.max(1, shockPool.count / 2))
                let sRoot   = shockPool[rootIdx]
                let sVel    = UInt8(68 + rng.nextInt(upperBound: 18))   // 68–85, hard echo of climax
                let sDur    = Swift.min(6 + rng.nextInt(upperBound: 5), totalSteps - ss)
                guard sDur >= 4 else { break }
                events.append(MIDIEvent(stepIndex: ss, note: sRoot, velocity: sVel, durationSteps: sDur))
                if let third = shockPool.first(where: { [3, 4].contains(Int($0) - Int(sRoot)) }) {
                    events.append(MIDIEvent(stepIndex: ss, note: third, velocity: sVel - 4, durationSteps: sDur))
                }
                if let fifth = shockPool.first(where: { Int($0) - Int(sRoot) == 7 }) {
                    events.append(MIDIEvent(stepIndex: ss, note: fifth, velocity: sVel - 7, durationSteps: sDur))
                }
            }
        }

        // Winston/Jarrett left-hand: bass + arpeggiated chord tones throughout the song.
        // lhMid at 61-72 (above middle C) so mid tones register as melody, not bass.
        // Bass changes every 2 bars for variety; mid indices cycle independently per bar.
        let lhBass = notesInRegister(pitchClasses: scalePCs, low: 40, high: 54)
        let lhMid  = notesInRegister(pitchClasses: scalePCs, low: 61, high: 72)
        if !lhBass.isEmpty, !lhMid.isEmpty {
            let rootPC    = frame.keySemitoneValue % 12
            let lhRoot    = lhBass.first(where: { Int($0) % 12 == rootPC }) ?? lhBass[0]
            let lhRootIdx = lhBass.firstIndex(of: lhRoot) ?? 0
            // Pentatonic pools have only 4-5 notes in the lhMid range; stride-2 gives 5-7st leaps.
            // Stride-1 keeps within-chord intervals at 2-3st (step/skip), preserving lyricism.
            let lhStride  = (frame.mode == .MinorPentatonic || frame.mode == .MajorPentatonic) ? 1 : 2
            for lhBar in 0..<totalBars {
                let barStep = lhBar * 16
                guard barStep < totalSteps else { break }
                // Bass steps through pool, changing every 2 bars for harmonic variety
                let bIdx  = (lhRootIdx + (lhBar / 2) % Swift.max(1, lhBass.count / 2)) % lhBass.count
                let bNote = lhBass[bIdx]
                let bVel  = UInt8(38 + rng.nextInt(upperBound: 12))
                // Beat 1 (step 0): bass alone — arrives first like Winston/Jarrett LH
                events.append(MIDIEvent(stepIndex: barStep, note: bNote, velocity: bVel, durationSteps: 7))
                // Beat 2 (step 4): 2-note chord stab SIMULTANEOUSLY — Winston's mid-register chord touch
                if barStep + 4 < totalSteps {
                    let mIdx  = (lhBar + 1) % lhMid.count
                    let mIdx2 = (lhBar + 1 + lhStride) % lhMid.count
                    let cv    = UInt8(30 + rng.nextInt(upperBound: 10))
                    events.append(MIDIEvent(stepIndex: barStep + 4, note: lhMid[mIdx], velocity: cv, durationSteps: 6))
                    events.append(MIDIEvent(stepIndex: barStep + 4, note: lhMid[mIdx2], velocity: cv - 3, durationSteps: 6))
                }
                // Beat 3 (step 8): another 2-note chord stab (Jarrett inner-voice repeat, slightly softer)
                if barStep + 8 < totalSteps {
                    let mIdx3 = (lhBar + 2) % lhMid.count
                    let mIdx4 = (lhBar + 2 + lhStride) % lhMid.count
                    let cv2   = UInt8(26 + rng.nextInt(upperBound: 10))
                    events.append(MIDIEvent(stepIndex: barStep + 8, note: lhMid[mIdx3], velocity: cv2, durationSteps: 5))
                    events.append(MIDIEvent(stepIndex: barStep + 8, note: lhMid[mIdx4], velocity: cv2 - 3, durationSteps: 5))
                }
                // Beat 4 (step 12): single lighter note — breathing space (45% of bars)
                if barStep + 12 < totalSteps, rng.nextDouble() < 0.45 {
                    let mIdx5 = (lhBar + 2) % lhMid.count
                    events.append(MIDIEvent(stepIndex: barStep + 12, note: lhMid[mIdx5],
                                            velocity: UInt8(22 + rng.nextInt(upperBound: 8)), durationSteps: 4))
                }
            }
        }

        return events.filter { $0.stepIndex < totalSteps }.sorted { $0.stepIndex < $1.stepIndex }
    }

}
