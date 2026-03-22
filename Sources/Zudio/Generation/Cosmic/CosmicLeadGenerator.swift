// KosmicLeadGenerator.swift — Kosmic lead melody generation
// Implements KOS-LEAD-001 through KOS-LEAD-006
// KOS-LEAD-006  JMJ Phrase Loop: 4–6 note melodic phrase generated once per body section,
//              repeated identically for 4 bars, then one note shifts a scale step on bar 5,
//              another shifts on bar 7. JMJ keyboard-solo-over-sequencer feel.
// Register: MIDI 60–96 (celestial, higher than arpeggio's 55–72)
// Velocity: 45–72 (softer than Motorik — kosmic is never aggressive)
// KOS-RULE-19: harmonic tier, full 20–87 range with phrase phrasing

import Foundation

struct KosmicLeadGenerator {

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

        // Technique D: 60% chance to use a different lead rule in B sections
        let bRule: String
        if rng.nextDouble() < 0.60 {
            bRule = pickLeadRuleDifferentFrom(aRule, rng: &rng)
            usedRuleIDs.insert(bRule)
        } else {
            bRule = aRule
        }

        // Bridge melody sections always use a distinct rule (independent of Technique D)
        let bridgeMelodyRule = pickLeadRuleDifferentFrom(aRule, rng: &rng)

        // KOS-LEAD-006 uses section-level phrase generation — bypass per-bar dispatch
        if aRule == "KOS-LEAD-006" {
            return generateJMJPhraseLoop(frame: frame, structure: structure,
                                         tonalMap: tonalMap, bRule: bRule, rng: &rng)
        }

        // KOS-RULE-24: commit to interval style
        let useWideInterval = rng.nextDouble() < 0.40

        var events: [MIDIEvent] = []

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            // Drum bridges (A-1, A-2): Lead is silent — density rule
            guard section.label != .bridge && section.label != .bridgeAlt else { continue }
            // Melody bridge (B): distinct lead melody repeated twice
            if section.label == .bridgeMelody {
                events += generateBridgeMelodySection(section: section, frame: frame,
                                                      tonalMap: tonalMap, bridgeRule: bridgeMelodyRule,
                                                      rng: &rng)
                continue
            }
            // B sections: use Technique D rule if selected
            let activeRule = (section.label == .B) ? bRule : aRule
            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                let scaleNotes = scaleNotesInRegister(entry: entry, frame: frame,
                                                      low: 60, high: 96)
                events += emitLeadBar(rule: activeRule, barStart: barStart, bar: bar,
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

        if rule == "KOS-LEAD-006" {
            return generateJMJPhraseLoop(frame: frame, structure: structure,
                                         tonalMap: tonalMap, rng: &rng)
        }

        var events: [MIDIEvent] = []

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            // Lead 2 is always silent during all bridge sections
            guard !section.label.isBridge else { continue }
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
        let rules:   [String] = ["KOS-LEAD-001", "KOS-LEAD-002", "KOS-LEAD-003", "KOS-LEAD-004", "KOS-LEAD-005", "KOS-LEAD-006"]
        let weights: [Double] = [0.22,           0.18,           0.15,           0.12,           0.08,           0.25]
        return rules[rng.weightedPick(weights)]
    }

    private static func pickLeadRule2(rng: inout SeededRNG) -> String {
        // Lead 2 prefers floating tones and pentatonic drift (sparser / softer)
        let rules:   [String] = ["KOS-LEAD-002", "KOS-LEAD-003", "KOS-LEAD-005", "KOS-LEAD-001", "KOS-LEAD-004", "KOS-LEAD-006"]
        let weights: [Double] = [0.28,           0.22,           0.12,           0.10,           0.07,           0.21]
        return rules[rng.weightedPick(weights)]
    }

    /// Pick a lead rule that is different from `current`. Used by Technique D and bridge melody.
    private static func pickLeadRuleDifferentFrom(_ current: String, rng: inout SeededRNG) -> String {
        let allRules = ["KOS-LEAD-001", "KOS-LEAD-002", "KOS-LEAD-003", "KOS-LEAD-004", "KOS-LEAD-005", "KOS-LEAD-006"]
        let candidates = allRules.filter { $0 != current }
        guard !candidates.isEmpty else { return current }
        return candidates[rng.nextInt(upperBound: candidates.count)]
    }

    /// Generate a bridge melody for Archetype B (Melody Bridge).
    ///
    /// Generates a repeating 2-bar phrase with actual note density — quarter-note to dotted-quarter
    /// rhythm, melodic arch across the phrase, then repeats the identical phrase for the rest of the
    /// bridge. The A-section lead rules (slowArc, floatingTones, etc.) are intentionally NOT used here
    /// because they are designed for sparse ambient behaviour and produce whole-note holds in a bridge.
    ///
    /// Structure:
    ///   - 2-bar phrase (32 steps) is generated once from scale + rhythm skeleton
    ///   - Phrase repeats for all bars in first half of bridge
    ///   - Second half replays first half identically (same pitches, same rhythm)
    private static func generateBridgeMelodySection(
        section: SongSection, frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap, bridgeRule: String,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let bridgeLen = section.endBar - section.startBar
        guard bridgeLen >= 2,
              let entry = tonalMap.entry(atBar: section.startBar) else { return [] }

        // Bridge melody uses a slightly extended register — feels bright and distinct from A section
        let scale = scaleNotesInRegister(entry: entry, frame: frame, low: 69, high: 86)
        guard scale.count >= 3 else { return [] }

        // === Rhythm skeleton: (stepInBar, durationSteps) for bar 0 and bar 1 of the 2-bar phrase ===
        // All skeletons have 3–6 notes per bar so there is audible melodic activity each bar.
        let rhythmVariant = rng.nextInt(upperBound: 4)
        let bar0rhythm: [(Int, Int)]
        let bar1rhythm: [(Int, Int)]
        switch rhythmVariant {
        case 0:  // Quarter-note pulse — clean and steady, Kraftwerk sequencer feel
            bar0rhythm = [(0,3),(4,3),(8,3),(12,3)]
            bar1rhythm = [(0,3),(4,3),(8,6),(12,3)]     // beat 3 held for tension in bar 2
        case 1:  // Syncopated JMJ — off-beat emphasis with some 8th-note movement
            bar0rhythm = [(0,2),(3,2),(6,2),(10,3),(14,2)]
            bar1rhythm = [(0,2),(4,2),(8,3),(11,2),(14,2)]
        case 2:  // 3-note motif with breath — short phrase then space, then answer
            bar0rhythm = [(0,3),(4,3),(9,4)]
            bar1rhythm = [(0,4),(5,3),(10,4)]
        default: // Driving 8th-note sequencer — most active, Dark Sun feel
            bar0rhythm = [(0,2),(2,2),(4,2),(8,4),(12,2),(14,2)]
            bar1rhythm = [(0,2),(4,2),(6,2),(10,4),(14,2)]
        }

        // === Melodic arch across all slots in the 2-bar phrase ===
        // Collect slots in order: (bar01, stepInBar, dur)
        let allSlots: [(Int, Int, Int)] = bar0rhythm.map { (0, $0.0, $0.1) }
                                        + bar1rhythm.map { (1, $0.0, $0.1) }
        let n = allSlots.count

        // Arch peaks at ~60% through the phrase (asymmetric, feels more musical than symmetric)
        let peakAt   = max(1, n * 3 / 5)
        let lowIdx   = max(0, scale.count / 5)
        let highIdx  = min(scale.count - 1, scale.count * 4 / 5)
        let goUp     = rng.nextDouble() < 0.55   // slight preference for rising bridges

        var pitchIdxs: [Int] = []
        for i in 0..<n {
            let archVal: Double = i < peakAt
                ? Double(i) / Double(peakAt)
                : Double(n - i) / Double(max(1, n - peakAt))
            let span = highIdx - lowIdx
            let base = goUp
                ? lowIdx  + Int(Double(span) * archVal)
                : highIdx - Int(Double(span) * archVal)
            let jitter = rng.nextInt(upperBound: 3) - 1   // ±1 step for natural variation
            pitchIdxs.append(max(0, min(scale.count - 1, base + jitter)))
        }

        // === Build phrase note table (deterministic from here — no more RNG) ===
        struct PhraseNote { let bar01: Int; let step: Int; let note: UInt8; let vel: UInt8; let dur: Int }
        var phrase: [PhraseNote] = []
        for (i, (bar01, step, dur)) in allSlots.enumerated() {
            let note = UInt8(scale[pitchIdxs[i]])
            let isStrong  = step == 0 || step == 8
            let vel       = UInt8(max(1, min(127, (isStrong ? 80 : 70) + rng.nextInt(upperBound: 12))))
            phrase.append(PhraseNote(bar01: bar01, step: step, note: note, vel: vel, dur: dur))
        }

        // === Emit: 2-bar phrase repeats for every bar in first half; second half = first half ===
        let halfLen = max(1, bridgeLen / 2)
        var evs: [MIDIEvent] = []
        for bar in section.startBar..<section.endBar {
            let bridgeBar  = bar - section.startBar
            let phraseBar  = bridgeBar % halfLen        // reset at second half
            let barIn2     = phraseBar % 2              // position in the 2-bar phrase (0 or 1)
            let barStart   = bar * 16
            for pn in phrase where pn.bar01 == barIn2 {
                evs.append(MIDIEvent(stepIndex: barStart + pn.step, note: pn.note,
                                     velocity: pn.vel, durationSteps: pn.dur))
            }
        }
        return evs
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
        case "KOS-LEAD-001": return slowArcBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        case "KOS-LEAD-002": return floatingTonesBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        case "KOS-LEAD-003": return pentatonicDriftBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, frame: frame, entry: entry, rng: &rng)
        case "KOS-LEAD-004": return echoMelodyBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        case "KOS-LEAD-005": return arpeggioHighlightBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, entry: entry, frame: frame, rng: &rng)
        default:           return floatingTonesBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        }
    }

    // MARK: - KOS-LD-001: Slow Arc
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

    // MARK: - KOS-LD-002: Floating Tones
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

    // MARK: - KOS-LD-003: Pentatonic Drift
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

    // MARK: - KOS-LD-004: Echo Melody
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

    // MARK: - KOS-LD-005: Arpeggio Highlight
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

    // MARK: - KOS-LEAD-006: JMJ Phrase Loop

    private static func generateJMJPhraseLoop(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, bRule: String = "KOS-LEAD-006", rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            // Silent during drum bridges; melody bridge uses its own path
            guard !section.label.isBridge else { continue }
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

    /// Scale notes for KOS-LEAD-006 phrase loop: MIDI 65–84 (upper-mid solo register)
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
