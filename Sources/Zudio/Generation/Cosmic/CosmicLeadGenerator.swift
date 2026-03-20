// CosmicLeadGenerator.swift — Cosmic lead melody generation
// Implements COS-LD-001 through COS-LD-005
// Register: MIDI 60–96 (celestial, higher than arpeggio's 55–72)
// Velocity: 45–72 (softer than Motorik — cosmic is never aggressive)
// COS-RULE-19: harmonic tier, full 20–87 range with phrase phrasing

import Foundation

struct CosmicLeadGenerator {

    // MARK: - Lead 1

    static func generateLead1(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {

        // Pick rule for A sections
        let aRule = pickLeadRule(rng: &rng)
        usedRuleIDs.insert(aRule)

        // COS-RULE-24: commit to interval style
        let useWideInterval = rng.nextDouble() < 0.40  // 40% wide/impressionistic

        var events: [MIDIEvent] = []

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }

            let rule = aRule

            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                let scaleNotes = scaleNotesInRegister(entry: entry, frame: frame,
                                                      low: 60, high: 96)
                events += emitLeadBar(rule: rule, barStart: barStart, bar: bar,
                                      scaleNotes: scaleNotes, entry: entry, frame: frame,
                                      useWideInterval: useWideInterval, rng: &rng)
            }
        }
        return events
    }

    // MARK: - Lead 2

    static func generateLead2(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        lead1Events: [MIDIEvent],
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {

        // Lead 2 uses a different rule or offset variant of Lead 1
        let rule = pickLeadRule2(rng: &rng)
        usedRuleIDs.insert(rule)

        var events: [MIDIEvent] = []

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }

            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                let scaleNotes = scaleNotesInRegister(entry: entry, frame: frame,
                                                      low: 60, high: 88)
                events += emitLeadBar(rule: rule, barStart: barStart, bar: bar,
                                      scaleNotes: scaleNotes, entry: entry, frame: frame,
                                      useWideInterval: false, rng: &rng)
            }
        }
        return events
    }

    // MARK: - Rule selection

    private static func pickLeadRule(rng: inout SeededRNG) -> String {
        let rules:   [String] = ["COS-LEAD-001", "COS-LEAD-002", "COS-LEAD-003", "COS-LEAD-004", "COS-LEAD-005"]
        let weights: [Double] = [0.30,          0.25,          0.20,          0.15,          0.10]
        return rules[rng.weightedPick(weights)]
    }

    private static func pickLeadRule2(rng: inout SeededRNG) -> String {
        // Lead 2 prefers floating tones and pentatonic drift (sparser / softer)
        let rules:   [String] = ["COS-LEAD-002", "COS-LEAD-003", "COS-LEAD-005", "COS-LEAD-001", "COS-LEAD-004"]
        let weights: [Double] = [0.35,          0.30,          0.15,          0.12,          0.08]
        return rules[rng.weightedPick(weights)]
    }

    // MARK: - Per-bar emit dispatcher

    private static func emitLeadBar(
        rule: String,
        barStart: Int,
        bar: Int,
        scaleNotes: [Int],
        entry: TonalGovernanceEntry,
        frame: GlobalMusicalFrame,
        useWideInterval: Bool,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard !scaleNotes.isEmpty else { return [] }

        switch rule {
        case "COS-LEAD-001": return slowArcBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        case "COS-LEAD-002": return floatingTonesBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        case "COS-LEAD-003": return pentatonicDriftBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, frame: frame, entry: entry, rng: &rng)
        case "COS-LEAD-004": return echoMelodyBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        case "COS-LEAD-005": return arpeggioHighlightBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, entry: entry, frame: frame, rng: &rng)
        default:           return floatingTonesBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        }
    }

    // MARK: - COS-LD-001: Slow Arc
    // 2–4 note phrase, each note 4–8 beats, rising or falling; one phrase per 4–8 bars

    private static func slowArcBar(
        barStart: Int, bar: Int, scaleNotes: [Int], rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Only start a new phrase every 4 bars
        guard bar % 4 == 0 else { return [] }

        let noteCount = 2 + rng.nextInt(upperBound: 3)  // 2–4 notes
        let ascending = rng.nextDouble() < 0.55

        var evs: [MIDIEvent] = []
        var stepPos = 0
        var lastIdx = ascending ? 0 : (scaleNotes.count - 1)

        for _ in 0..<noteCount {
            guard stepPos < 16 else { break }
            let note = scaleNotes[Swift.max(0, Swift.min(scaleNotes.count - 1, lastIdx))]
            let dur = 4 + rng.nextInt(upperBound: 5)  // 4–8 steps (1–2 beats)
            let vel = UInt8(45 + rng.nextInt(upperBound: 28))  // 45–72

            evs.append(MIDIEvent(stepIndex: barStart + stepPos, note: UInt8(note),
                                 velocity: vel, durationSteps: Swift.min(dur, 16 - stepPos)))
            stepPos += dur

            if ascending {
                lastIdx = Swift.min(lastIdx + 1 + rng.nextInt(upperBound: 2), scaleNotes.count - 1)
            } else {
                lastIdx = Swift.max(lastIdx - 1 - rng.nextInt(upperBound: 2), 0)
            }
        }
        return evs
    }

    // MARK: - COS-LD-002: Floating Tones
    // Single notes every 2–4 bars, held until next attack

    private static func floatingTonesBar(
        barStart: Int, bar: Int, scaleNotes: [Int], rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Fire on a 2–4 bar rhythm, not every bar
        let fireInterval = 2 + rng.nextInt(upperBound: 3)
        guard bar % fireInterval == 0 else { return [] }

        let noteIdx = rng.nextInt(upperBound: scaleNotes.count)
        let note    = scaleNotes[noteIdx]
        let vel     = UInt8(50 + rng.nextInt(upperBound: 23))  // 50–72

        // Hold for a long time — 2 bars worth (32 steps)
        return [MIDIEvent(stepIndex: barStart, note: UInt8(note), velocity: vel, durationSteps: 30)]
    }

    // MARK: - COS-LD-003: Pentatonic Drift
    // Slow pentatonic movement, each step 2–4 bars

    private static func pentatonicDriftBar(
        barStart: Int, bar: Int, scaleNotes: [Int],
        frame: GlobalMusicalFrame, entry: TonalGovernanceEntry,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Build pentatonic subset from scale notes
        let penta = pentatonicNotes(entry: entry, frame: frame, low: 60, high: 96)
        guard !penta.isEmpty else { return [] }

        // Move one step every 3 bars
        guard bar % 3 == 0 else { return [] }

        let noteIdx = (bar / 3) % penta.count
        let note    = penta[noteIdx]
        let vel     = UInt8(48 + rng.nextInt(upperBound: 20))  // 48–67

        return [MIDIEvent(stepIndex: barStart, note: UInt8(note), velocity: vel, durationSteps: 28)]
    }

    // MARK: - COS-LD-004: Echo Melody
    // 4-note phrase (2 bars) → 2-bar silence → phrase transposed ±3rd; repeats

    private static func echoMelodyBar(
        barStart: Int, bar: Int, scaleNotes: [Int], rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let cycle = bar % 8  // 8-bar cycle: 2 bars phrase, 2 bars silence, 2 bars echo, 2 bars silence

        // Phrase bars: 0–1
        if cycle < 2 {
            let phraseNote = scaleNotes[Swift.min(cycle, scaleNotes.count - 1)]
            let vel = UInt8(55 + rng.nextInt(upperBound: 18))
            return [MIDIEvent(stepIndex: barStart, note: UInt8(phraseNote), velocity: vel, durationSteps: 14)]
        }
        // Silence: bars 2–3
        if cycle < 4 { return [] }
        // Echo (transposed): bars 4–5
        if cycle < 6 {
            let baseIdx = cycle - 4
            let baseNote = scaleNotes[Swift.min(baseIdx, scaleNotes.count - 1)]
            // Transpose up or down by approximately a 3rd
            let transposedNote = Swift.max(60, Swift.min(96, baseNote + (rng.nextDouble() < 0.5 ? 4 : -3)))
            let vel = UInt8(45 + rng.nextInt(upperBound: 18))
            return [MIDIEvent(stepIndex: barStart, note: UInt8(transposedNote), velocity: vel, durationSteps: 14)]
        }
        // Silence: bars 6–7
        return []
    }

    // MARK: - COS-LD-005: Arpeggio Highlight
    // Picks one arpeggio note and holds it 1 bar; changes every 4 bars

    private static func arpeggioHighlightBar(
        barStart: Int, bar: Int, scaleNotes: [Int],
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Change highlight note every 4 bars
        let highlightGroup = bar / 4
        guard !scaleNotes.isEmpty else { return [] }
        let noteIdx = highlightGroup % scaleNotes.count
        let note    = scaleNotes[noteIdx]
        let vel     = UInt8(52 + rng.nextInt(upperBound: 20))  // 52–71

        return [MIDIEvent(stepIndex: barStart, note: UInt8(note), velocity: vel, durationSteps: 14)]
    }

    // MARK: - Helpers

    private static func scaleNotesInRegister(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, low: Int, high: Int
    ) -> [Int] {
        let keyST  = keySemitone(frame.key)
        let mode   = entry.sectionMode
        var notes: [Int] = []
        for oct in 0...7 {
            for interval in mode.intervals {
                let midi = keyST + interval + (oct * 12)
                if midi >= low && midi <= high { notes.append(midi) }
            }
        }
        return notes.sorted()
    }

    private static func pentatonicNotes(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, low: Int, high: Int
    ) -> [Int] {
        let keyST = keySemitone(frame.key)
        let mode  = entry.sectionMode
        // Use the pentatonic subset: root, 3rd, 4th, 5th, b7
        let pentaIntervals = [0, mode.nearestInterval(3), 5, 7, mode.nearestInterval(10)]
        var notes: [Int] = []
        for oct in 0...7 {
            for interval in pentaIntervals {
                let midi = keyST + interval + (oct * 12)
                if midi >= low && midi <= high { notes.append(midi) }
            }
        }
        return notes.sorted().removingDuplicates()
    }
}

// MARK: - Array dedup helper

private extension Array where Element: Equatable {
    func removingDuplicates() -> [Element] {
        var seen: [Element] = []
        for element in self {
            if !seen.contains(element) { seen.append(element) }
        }
        return seen
    }
}
