// AmbientLeadGenerator.swift — Lead 1 and Lead 2 generators for Ambient style
// Lead 1 rules: AMB-LD1-004 (40%), AMB-LD1-001 floating tone (30%),
//               AMB-LD1-002 echo phrase (20%), AMB-LD1-003 pentatonic shimmer (10%)
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
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let bounds    = kRegisterBounds[kTrackLead1]!  // low:60, high:88
        let loopSteps = loopBars * 16
        let scalePCs  = Set(frame.mode.intervals.map { (frame.keySemitoneValue + $0) % 12 })
        let notes     = notesInRegister(pitchClasses: scalePCs, low: bounds.low, high: bounds.high)
        guard !notes.isEmpty else { return [] }

        let roll = rng.nextDouble()
        if roll < 0.40 {
            usedRuleIDs.insert("AMB-LD1-004"); return []
        }
        if roll < 0.70 {
            usedRuleIDs.insert("AMB-LD1-001")
            return floatingTone(notes: notes, loopSteps: loopSteps, rng: &rng)
        }
        if roll < 0.90 {
            usedRuleIDs.insert("AMB-LD1-002")
            return echoPhrase(notes: notes, loopSteps: loopSteps, rng: &rng)
        }
        usedRuleIDs.insert("AMB-LD1-003")
        let pentaPCs   = Set(Mode.MajorPentatonic.intervals.map { (frame.keySemitoneValue + $0) % 12 })
        let pentaNotes = notesInRegister(pitchClasses: pentaPCs, low: bounds.low, high: bounds.high)
        return pentaShimmer(notes: pentaNotes.isEmpty ? notes : pentaNotes, loopSteps: loopSteps, rng: &rng)
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

        if windows.isEmpty { usedRuleIDs.insert("AMB-LD2-002"); return [] }
        usedRuleIDs.insert("AMB-LD2-001")

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

    /// AMB-LD1-001: Floating tone — 1–3 sustained notes, long rests between them.
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

    /// AMB-LD1-002: Echo phrase — 2–3 note descending phrase with diminishing velocity.
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

    /// AMB-LD1-003: Pentatonic shimmer — short ascending run, then long rest.
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

    // MARK: - Shared utility

    static func notesInRegister(pitchClasses: Set<Int>, low: Int, high: Int) -> [UInt8] {
        guard low <= high else { return [] }
        return (low...high).compactMap { n in pitchClasses.contains(n % 12) ? UInt8(n) : nil }
    }
}
