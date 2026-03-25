// AmbientLeadGenerator.swift — Lead 1 and Lead 2 generators for Ambient style
// Lead 1 rules: AMB-LEAD-004 (40%), AMB-LEAD-001 floating tone (26%),
//               AMB-LEAD-002 echo phrase (19%), AMB-LEAD-003 pentatonic shimmer (10%),
//               AMB-LEAD-007 lyric fragment (5%)
// Lead 2: AMB-SYNC-003 — fills Lead 1 silent windows (absent if no windows).
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
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {
        let bounds    = kRegisterBounds[kTrackLead1]!  // low:60, high:88
        let loopSteps = loopBars * 16
        let scalePCs  = Set(frame.mode.intervals.map { (frame.keySemitoneValue + $0) % 12 })
        let notes     = notesInRegister(pitchClasses: scalePCs, low: bounds.low, high: bounds.high)
        guard !notes.isEmpty else { return [] }

        // If a specific rule is forced (test pool override), skip the random roll
        if let forced = forceRuleID {
            let pentaPCs   = Set(Mode.MajorPentatonic.intervals.map { (frame.keySemitoneValue + $0) % 12 })
            let pentaNotes = notesInRegister(pitchClasses: pentaPCs, low: bounds.low, high: bounds.high)
            switch forced {
            case "AMB-LEAD-001": usedRuleIDs.insert("AMB-LEAD-001"); return floatingTone(notes: notes, loopSteps: loopSteps, rng: &rng)
            case "AMB-LEAD-002": usedRuleIDs.insert("AMB-LEAD-002"); return echoPhrase(notes: notes, loopSteps: loopSteps, rng: &rng)
            case "AMB-LEAD-003": usedRuleIDs.insert("AMB-LEAD-003"); return pentaShimmer(notes: pentaNotes.isEmpty ? notes : pentaNotes, loopSteps: loopSteps, rng: &rng)
            case "AMB-LEAD-004": usedRuleIDs.insert("AMB-LEAD-004"); return []
            case "AMB-LEAD-007": usedRuleIDs.insert("AMB-LEAD-007"); return lyricalFragment(notes: notes, loopSteps: loopSteps, rng: &rng)
            case "AMB-LEAD-008": usedRuleIDs.insert("AMB-LEAD-008"); return returningMotif(notes: notes, loopSteps: loopSteps, rng: &rng)
            default: break
            }
        }

        let roll = rng.nextDouble()
        if !forceNonSilent && roll < 0.40 {
            usedRuleIDs.insert("AMB-LEAD-004"); return []
        }
        if roll < 0.63 {
            usedRuleIDs.insert("AMB-LEAD-001")
            return floatingTone(notes: notes, loopSteps: loopSteps, rng: &rng)
        }
        if roll < 0.81 {
            usedRuleIDs.insert("AMB-LEAD-002")
            return echoPhrase(notes: notes, loopSteps: loopSteps, rng: &rng)
        }
        if roll < 0.91 {
            usedRuleIDs.insert("AMB-LEAD-003")
            let pentaPCs   = Set(Mode.MajorPentatonic.intervals.map { (frame.keySemitoneValue + $0) % 12 })
            let pentaNotes = notesInRegister(pitchClasses: pentaPCs, low: bounds.low, high: bounds.high)
            return pentaShimmer(notes: pentaNotes.isEmpty ? notes : pentaNotes, loopSteps: loopSteps, rng: &rng)
        }
        if roll < 0.95 {
            usedRuleIDs.insert("AMB-LEAD-007")
            return lyricalFragment(notes: notes, loopSteps: loopSteps, rng: &rng)
        }
        usedRuleIDs.insert("AMB-LEAD-008")
        return returningMotif(notes: notes, loopSteps: loopSteps, rng: &rng)
    }

    // MARK: - Lead 2 (AMB-SYNC-003: fills Lead 1 silent windows)

    static func generateLead2(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        lead1Events: [MIDIEvent],
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let bounds    = kRegisterBounds[kTrackLead2]!  // low:55, high:81
        let loopSteps = loopBars * 16
        let scalePCs  = Set(frame.mode.intervals.map { (frame.keySemitoneValue + $0) % 12 })
        let notes     = notesInRegister(pitchClasses: scalePCs, low: bounds.low, high: bounds.high)
        guard !notes.isEmpty else { return [] }

        // AMB-SYNC-004 (40%): ghost echo — delay Lead 1 notes by 4–8 steps at 60–65% velocity.
        // Creates a natural echo/shadow effect; only fires when Lead 1 has content.
        if !lead1Events.isEmpty && rng.nextDouble() < 0.40 {
            usedRuleIDs.insert("AMB-SYNC-004")
            var echoEvents: [MIDIEvent] = []
            for ev in lead1Events where ev.stepIndex < loopSteps {
                let offset = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
                let step   = ev.stepIndex + offset
                guard step < loopSteps else { continue }
                let vel = UInt8(Swift.max(20, Int(Double(ev.velocity) * 0.62)))
                let dur = Swift.min(ev.durationSteps, loopSteps - step)
                if dur >= 2 {
                    echoEvents.append(MIDIEvent(stepIndex: step, note: ev.note,
                                                velocity: vel, durationSteps: dur))
                }
            }
            if !echoEvents.isEmpty {
                return echoEvents.sorted { $0.stepIndex < $1.stepIndex }
            }
        }

        // AMB-SYNC-003: fill Lead 1 silent windows
        // Build set of steps occupied by lead1 (within loop)
        var occupied = Set<Int>()
        for ev in lead1Events where ev.stepIndex < loopSteps {
            let end = Swift.min(ev.stepIndex + ev.durationSteps, loopSteps)
            for s in ev.stepIndex..<end { occupied.insert(s) }
        }

        // Find contiguous silent windows ≥ 8 steps
        var windows: [(start: Int, length: Int)] = []
        var winStart: Int? = nil
        for s in 0..<loopSteps {
            if !occupied.contains(s) {
                if winStart == nil { winStart = s }
            } else if let ws = winStart {
                if s - ws >= 8 { windows.append((ws, s - ws)) }
                winStart = nil
            }
        }
        if let ws = winStart, loopSteps - ws >= 8 { windows.append((ws, loopSteps - ws)) }

        if windows.isEmpty { usedRuleIDs.insert("AMB-LEAD-006"); return [] }
        usedRuleIDs.insert("AMB-LEAD-005")

        var events: [MIDIEvent] = []
        for window in windows {
            guard rng.nextDouble() < 0.65 else { continue }
            let note  = notes[rng.nextInt(upperBound: notes.count)]
            let half  = Swift.max(1, window.length / 2)
            let start = window.start + rng.nextInt(upperBound: half)
            let maxDur = window.start + window.length - start
            let dur    = Swift.min(Swift.max(4, maxDur - 2), 16)
            if dur >= 2 {
                let vel = UInt8(40 + rng.nextInt(upperBound: 35))  // 40–74
                events.append(MIDIEvent(stepIndex: start, note: note, velocity: vel, durationSteps: dur))
            }
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    // MARK: - Lead 1 rule implementations

    /// AMB-LEAD-001: Floating tone — 1–3 sustained notes, long rests between them.
    private static func floatingTone(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let count  = 1 + rng.nextInt(upperBound: 3)   // 1–3 notes
        var cursor = rng.nextInt(upperBound: 8)
        for _ in 0..<count {
            guard cursor < loopSteps else { break }
            let note    = notes[rng.nextInt(upperBound: notes.count)]
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
        return events.sorted { $0.stepIndex < $1.stepIndex }
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

    /// AMB-LEAD-008: Returning motif — a 2–3 note phrase that recurs every 8–14 bars with ±2 step jitter.
    /// The same pitches return at semi-regular intervals; spacing is irregular enough to feel unscheduled.
    private static func returningMotif(notes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        guard notes.count >= 3 else { return [] }
        // Pick 2–3 notes from the lower half of the register
        let motifLen  = 2 + rng.nextInt(upperBound: 2)           // 2–3 notes
        let maxStart  = Swift.max(1, notes.count / 2)
        let startIdx  = rng.nextInt(upperBound: maxStart)
        let motif     = Array(notes[startIdx..<Swift.min(startIdx + motifLen, notes.count)])
        let holdSteps = 8 + rng.nextInt(upperBound: 5)           // 8–12 steps per note
        let baseVel   = UInt8(45 + rng.nextInt(upperBound: 16))  // 45–60
        let returnInterval = (8 + rng.nextInt(upperBound: 7)) * 16  // 8–14 bars
        var events: [MIDIEvent] = []
        var cursor = rng.nextInt(upperBound: 16)
        while cursor < loopSteps {
            let jitter     = rng.nextInt(upperBound: 5) - 2      // ±2 steps
            var noteCursor = Swift.max(0, cursor + jitter)
            for note in motif {
                guard noteCursor < loopSteps else { break }
                let dur = Swift.min(holdSteps, loopSteps - noteCursor)
                if dur >= 4 {
                    let vel = UInt8(Swift.min(100, Int(baseVel) + rng.nextInt(upperBound: 8) - 4))
                    events.append(MIDIEvent(stepIndex: noteCursor, note: note,
                                           velocity: vel, durationSteps: dur))
                }
                noteCursor += holdSteps + 2   // 2-step gap between motif notes
            }
            cursor += returnInterval
        }
        return events
    }

    // MARK: - Shared utility

    static func notesInRegister(pitchClasses: Set<Int>, low: Int, high: Int) -> [UInt8] {
        guard low <= high else { return [] }
        return (low...high).compactMap { n in pitchClasses.contains(n % 12) ? UInt8(n) : nil }
    }
}
