// CosmicLeadGenerator.swift — Cosmic lead melody generation
// Implements COS-LEAD-001 through COS-LEAD-006
// COS-LEAD-006  JMJ Phrase Loop: 4–6 note melodic phrase generated once per body section,
//              repeated identically for 4 bars, then one note shifts a scale step on bar 5,
//              another shifts on bar 7. JMJ keyboard-solo-over-sequencer feel.
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
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {

        let aRule = forceRuleID ?? pickLeadRule(rng: &rng)
        usedRuleIDs.insert(aRule)

        // COS-LEAD-006 uses section-level phrase generation — bypass per-bar dispatch
        if aRule == "COS-LEAD-006" {
            return generateJMJPhraseLoop(frame: frame, structure: structure,
                                         tonalMap: tonalMap, rng: &rng)
        }

        // COS-RULE-24: commit to interval style
        let useWideInterval = rng.nextDouble() < 0.40

        var events: [MIDIEvent] = []

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                let scaleNotes = scaleNotesInRegister(entry: entry, frame: frame,
                                                      low: 60, high: 96)
                events += emitLeadBar(rule: aRule, barStart: barStart, bar: bar,
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

        let rule = pickLeadRule2(rng: &rng)
        usedRuleIDs.insert(rule)

        if rule == "COS-LEAD-006" {
            return generateJMJPhraseLoop(frame: frame, structure: structure,
                                         tonalMap: tonalMap, rng: &rng)
        }

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
        let rules:   [String] = ["COS-LEAD-001", "COS-LEAD-002", "COS-LEAD-003", "COS-LEAD-004", "COS-LEAD-005", "COS-LEAD-006"]
        let weights: [Double] = [0.22,           0.18,           0.15,           0.12,           0.08,           0.25]
        return rules[rng.weightedPick(weights)]
    }

    private static func pickLeadRule2(rng: inout SeededRNG) -> String {
        // Lead 2 prefers floating tones and pentatonic drift (sparser / softer)
        let rules:   [String] = ["COS-LEAD-002", "COS-LEAD-003", "COS-LEAD-005", "COS-LEAD-001", "COS-LEAD-004", "COS-LEAD-006"]
        let weights: [Double] = [0.28,           0.22,           0.12,           0.10,           0.07,           0.21]
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

    // MARK: - COS-LEAD-006: JMJ Phrase Loop

    private static func generateJMJPhraseLoop(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            guard let firstEntry = tonalMap.entry(atBar: section.startBar) else { continue }

            let scaleNotes = jmjPhraseScaleNotes(entry: firstEntry, frame: frame)
            guard scaleNotes.count >= 4 else { continue }

            // Build the phrase once per section: 4–6 notes with quarter/8th-note durations
            let phraseLen = 4 + rng.nextInt(upperBound: 3)
            var phraseNotes: [Int] = []
            var phraseDurs:  [Int] = []
            var stepAccum = 0
            for _ in 0..<phraseLen {
                guard stepAccum < 16 else { break }
                phraseNotes.append(scaleNotes[rng.nextInt(upperBound: scaleNotes.count)])
                let dur = 4 + rng.nextInt(upperBound: 5)  // 4–8 steps (1–2 beats)
                phraseDurs.append(dur)
                stepAccum += dur
            }
            guard !phraseNotes.isEmpty else { continue }

            // Which note index shifts and in which direction for each variation
            let var1Idx   = rng.nextInt(upperBound: phraseNotes.count)
            let var2Idx   = (var1Idx + 1 + rng.nextInt(upperBound: max(1, phraseNotes.count - 1))) % phraseNotes.count
            let shift1    = rng.nextDouble() < 0.5 ? 1 : -1
            let shift2    = rng.nextDouble() < 0.5 ? 1 : -1

            func shiftedNote(_ note: Int, by delta: Int) -> Int {
                let baseIdx = scaleNotes.firstIndex(of: note) ?? (scaleNotes.count / 2)
                return scaleNotes[max(0, min(scaleNotes.count - 1, baseIdx + delta))]
            }

            for bar in section.startBar..<section.endBar {
                let posInSection = bar - section.startBar
                let posInBlock   = posInSection % 8  // 8-bar phrase block

                // Bars 0–3: base phrase. Bars 4–5: shift note 1. Bars 6–7: shift note 2.
                var activeNotes = phraseNotes
                if posInBlock >= 4 {
                    activeNotes[var1Idx] = shiftedNote(phraseNotes[var1Idx], by: shift1)
                }
                if posInBlock >= 6 {
                    activeNotes[var2Idx] = shiftedNote(phraseNotes[var2Idx], by: shift2)
                }

                let barStart = bar * 16
                var stepPos  = 0
                for (i, note) in activeNotes.enumerated() {
                    guard stepPos < 16 else { break }
                    let dur = phraseDurs[i]
                    let vel = UInt8(58 + rng.nextInt(upperBound: 15))  // 58–72
                    events.append(MIDIEvent(stepIndex: barStart + stepPos,
                                            note: UInt8(note), velocity: vel,
                                            durationSteps: min(dur, 16 - stepPos)))
                    stepPos += dur
                }
            }
        }
        return events
    }

    // MARK: - Helpers

    /// Scale notes for COS-LEAD-006 phrase loop: MIDI 65–84 (upper-mid solo register)
    private static func jmjPhraseScaleNotes(entry: TonalGovernanceEntry,
                                             frame: GlobalMusicalFrame) -> [Int] {
        return scaleNotesInRegister(entry: entry, frame: frame, low: 65, high: 84)
    }

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
