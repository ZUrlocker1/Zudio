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
        forceRuleID: String? = nil,
        lead1BaseRule: inout String,
        xFilesBars: inout [Int]
    ) -> [MIDIEvent] {

        let aRule = forceRuleID ?? pickLeadRule(rng: &rng)
        lead1BaseRule = aRule
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
                                         tonalMap: tonalMap, bRule: bRule, rng: &rng,
                                         xFilesBars: &xFilesBars)
        }

        // KOS-RULE-24: commit to interval style
        let useWideInterval = rng.nextDouble() < 0.40

        var events: [MIDIEvent] = []

        // Bridge A-1: sustained 5th for the full bridge duration
        events += generateDrumBridgeLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)
        // Bridge A-2: short descending melodic response on odd (non-hit) bars
        events += generateBridgeAltLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            // Drum bridges handled above — skip in main loop
            guard section.label != .bridge && section.label != .bridgeAlt else { continue }
            // Melody bridge (B): X-Files whistle 25% of the time; otherwise generated melody
            if section.label == .bridgeMelody {
                var melodyEvents = generateBridgeMelodySection(section: section, frame: frame,
                                                               tonalMap: tonalMap, bridgeRule: bridgeMelodyRule,
                                                               rng: &rng)
                if rng.nextDouble() < 0.25 {
                    // X-Files appears symmetrically: bookend (first+last) or middle-pair (two bars with a gap).
                    let bridgeLen = section.endBar - section.startBar
                    let xBars: [Int]
                    if rng.nextDouble() < 0.50 {
                        // Bookend: opening bar and closing bar mirror each other
                        xBars = bridgeLen >= 2
                            ? [section.startBar, section.endBar - 1]
                            : [section.startBar]
                    } else {
                        // Middle pair: spaced ~1/3 and ~2/3 through the bridge
                        let a = section.startBar + max(1, bridgeLen / 3)
                        let b = section.startBar + max(2, (bridgeLen * 2) / 3)
                        xBars = (b > a) ? [a, b] : [a]
                    }
                    for xBar in xBars {
                        let barEvs = xFilesWhistleBar(bar: xBar, frame: frame, tonalMap: tonalMap, rng: &rng)
                        guard !barEvs.isEmpty else { continue }
                        xFilesBars.append(xBar)
                        let xStart = xBar * 16; let xEnd = xStart + 16
                        // 6-beat (24-step) silence pad before and after so the whistle stands out
                        let prePadStart = xBar > section.startBar     ? xStart - 24 : xStart
                        let postPadEnd  = xBar < section.endBar - 1   ? xEnd + 24   : xEnd
                        melodyEvents = melodyEvents.filter {
                            $0.stepIndex < prePadStart || $0.stepIndex >= postPadEnd
                        }
                        melodyEvents += barEvs
                    }
                }
                events += melodyEvents
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
        usedRuleIDs: inout Set<String>,
        lead1BaseRuleID: String? = nil
    ) -> [MIDIEvent] {

        let rule = pickLeadRule2(rng: &rng)
        usedRuleIDs.insert(rule)

        // If both leads share the same JMJ rule, generate sparse version for Lead 2
        if rule == "KOS-LEAD-006" {
            let sparseMode = (lead1BaseRuleID == "KOS-LEAD-006")
            var discard: [Int] = []
            return generateJMJPhraseLoop(frame: frame, structure: structure,
                                         tonalMap: tonalMap, sparseMode: sparseMode, rng: &rng,
                                         xFilesBars: &discard)
        }

        // When Lead 2 draws the same rule as Lead 1, shift bar index by 1 so Lead 2
        // always fires at least one bar after Lead 1, and skip the first bar of each section.
        let sameRule = (lead1BaseRuleID != nil && rule == lead1BaseRuleID)

        var events: [MIDIEvent] = []

        // Bridge A-2: Lead 2 plays a complementary ascending figure on response bars
        events += generateBridgeAltLead2(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            // Lead 2 silent in A-1 and melody bridges; bridgeAlt handled above
            guard section.label != .bridge && section.label != .bridgeMelody else { continue }
            guard section.label != .bridgeAlt else { continue }
            for bar in section.startBar..<section.endBar {
                // Same-rule fixup: skip section's first bar (Lead 1 fires there), lag by 1 bar
                if sameRule && bar == section.startBar { continue }
                let virtualBar = sameRule ? bar - 1 : bar
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                let scaleNotes = scaleNotesInRegister(entry: entry, frame: frame,
                                                      low: 60, high: 88)
                events += emitLeadBar(rule: rule, barStart: barStart, bar: virtualBar,
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

        // === Build evolved phrase for second half (bridges > 4 bars only) ===
        // Raises the melodic peak +1 scale step and nudges the note before it too — the second
        // half feels like it reaches higher, a classic TD/JMJ variation technique.
        var phraseVariant = phrase
        if bridgeLen > 4 && peakAt < phraseVariant.count {
            // Raise the peak note
            let oldIdx = pitchIdxs[peakAt]
            if oldIdx + 1 < scale.count {
                let p = phraseVariant[peakAt]
                phraseVariant[peakAt] = PhraseNote(bar01: p.bar01, step: p.step,
                                                    note: UInt8(scale[oldIdx + 1]),
                                                    vel: UInt8(min(127, Int(p.vel) + 6)),
                                                    dur: p.dur)
            }
            // Also nudge the note immediately before the peak (+1 step if possible)
            let preIdx = max(0, peakAt - 1)
            if preIdx != peakAt && preIdx < phraseVariant.count {
                let oldPre = pitchIdxs[preIdx]
                if oldPre + 1 < scale.count {
                    let p = phraseVariant[preIdx]
                    phraseVariant[preIdx] = PhraseNote(bar01: p.bar01, step: p.step,
                                                        note: UInt8(scale[oldPre + 1]),
                                                        vel: p.vel, dur: p.dur)
                }
            }
        }

        // === Build middle-repetition variant: shifts note at ~2/3 position by ±1 scale step ===
        // Middle repetitions within each half use this to avoid sounding identical to the outer reps.
        // The shift is subtle — one note moves one step — so the phrase is still recognisable.
        let midShiftIdx = max(0, min(n - 1, n * 2 / 3))
        let midOldIdx   = pitchIdxs[midShiftIdx]
        var phraseMid = phrase
        if midOldIdx + 1 < scale.count {
            let p = phraseMid[midShiftIdx]
            phraseMid[midShiftIdx] = PhraseNote(bar01: p.bar01, step: p.step,
                                                note: UInt8(scale[midOldIdx + 1]),
                                                vel: p.vel, dur: p.dur)
        }
        var phraseMidVariant = phraseVariant
        if midOldIdx + 1 < scale.count && midShiftIdx < phraseMidVariant.count {
            let p = phraseMidVariant[midShiftIdx]
            phraseMidVariant[midShiftIdx] = PhraseNote(bar01: p.bar01, step: p.step,
                                                       note: UInt8(scale[midOldIdx + 1]),
                                                       vel: p.vel, dur: p.dur)
        }

        // === Emit: first and last reps per half are exact; middle reps use the evolved variant ===
        let halfLen          = max(1, bridgeLen / 2)
        let totalRepsInHalf  = max(1, halfLen / 2)
        var evs: [MIDIEvent] = []
        for bar in section.startBar..<section.endBar {
            let bridgeBar    = bar - section.startBar
            let phraseBar    = bridgeBar % halfLen
            let barIn2       = phraseBar % 2
            let barStart     = bar * 16
            let repInHalf    = phraseBar / 2
            let isFirstOrLast = repInHalf == 0 || repInHalf == totalRepsInHalf - 1
            let inSecondHalf  = bridgeLen > 4 && bridgeBar >= halfLen
            let useMid        = !isFirstOrLast && totalRepsInHalf > 2
            let activePhrase: [PhraseNote]
            if inSecondHalf {
                activePhrase = useMid ? phraseMidVariant : phraseVariant
            } else {
                activePhrase = useMid ? phraseMid : phrase
            }
            for pn in activePhrase where pn.bar01 == barIn2 {
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
        tonalMap: TonalGovernanceMap, bRule: String = "KOS-LEAD-006",
        sparseMode: Bool = false, rng: inout SeededRNG,
        xFilesBars: inout [Int]
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Bridge A-1 and A-2: same bridge lead as regular rules
        events += generateDrumBridgeLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)
        events += generateBridgeAltLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)

        // Bridge melody rule: pick once, different from JMJ
        let jmjBridgeMelodyRule = pickLeadRuleDifferentFrom("KOS-LEAD-006", rng: &rng)

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            // Drum bridges handled above
            guard section.label != .bridge && section.label != .bridgeAlt else { continue }
            // Melody bridge: same path as generateLead1
            if section.label == .bridgeMelody {
                var melodyEvents = generateBridgeMelodySection(section: section, frame: frame,
                                                               tonalMap: tonalMap, bridgeRule: jmjBridgeMelodyRule,
                                                               rng: &rng)
                if rng.nextDouble() < 0.25 {
                    let bridgeLen = section.endBar - section.startBar
                    let xBars: [Int]
                    if rng.nextDouble() < 0.50 {
                        xBars = bridgeLen >= 2
                            ? [section.startBar, section.endBar - 1]
                            : [section.startBar]
                    } else {
                        let a = section.startBar + max(1, bridgeLen / 3)
                        let b = section.startBar + max(2, (bridgeLen * 2) / 3)
                        xBars = (b > a) ? [a, b] : [a]
                    }
                    for xBar in xBars {
                        let barEvs = xFilesWhistleBar(bar: xBar, frame: frame, tonalMap: tonalMap, rng: &rng)
                        guard !barEvs.isEmpty else { continue }
                        xFilesBars.append(xBar)
                        let xStart = xBar * 16; let xEnd = xStart + 16
                        // 6-beat (24-step) silence pad before and after so the whistle stands out
                        let prePadStart = xBar > section.startBar     ? xStart - 24 : xStart
                        let postPadEnd  = xBar < section.endBar - 1   ? xEnd + 24   : xEnd
                        melodyEvents = melodyEvents.filter {
                            $0.stepIndex < prePadStart || $0.stepIndex >= postPadEnd
                        }
                        melodyEvents += barEvs
                    }
                }
                events += melodyEvents
                continue
            }
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

            // Precompute the shifted notes once — inputs are constant across all bars in this section.
            // Avoids O(scaleNotes) firstIndex scans on every bar tick.
            let shiftedNote1: Int = {
                let idx = scaleNotes.firstIndex(of: phraseNotes[var1Idx]) ?? (scaleNotes.count / 2)
                return scaleNotes[max(0, min(scaleNotes.count - 1, idx + shift1))]
            }()
            let shiftedNote2: Int = {
                let idx = scaleNotes.firstIndex(of: phraseNotes[var2Idx]) ?? (scaleNotes.count / 2)
                return scaleNotes[max(0, min(scaleNotes.count - 1, idx + shift2))]
            }()

            for bar in section.startBar..<section.endBar {
                let posInSection = bar - section.startBar
                // Sparse mode (Lead 2 doubling JMJ): skip first bar of section; 40% gate elsewhere
                if sparseMode && posInSection == 0 { continue }
                if sparseMode && rng.nextDouble() > 0.40 { continue }

                let posInBlock   = posInSection % 8  // 8-bar phrase block

                // Bars 0–3: base phrase. Bars 4–5: shift note 1. Bars 6–7: shift note 2.
                var activeNotes = phraseNotes
                if posInBlock >= 4 { activeNotes[var1Idx] = shiftedNote1 }
                if posInBlock >= 6 { activeNotes[var2Idx] = shiftedNote2 }

                let barStart = bar * 16
                var stepPos  = 0
                // Sparse mode: use only the first 1–2 notes per bar (subtle punctuation)
                let noteLimit = sparseMode ? min(2, activeNotes.count) : activeNotes.count
                for (i, note) in activeNotes.prefix(noteLimit).enumerated() {
                    guard stepPos < 16 else { break }
                    let dur = phraseDurs[i]
                    // Sparse mode: softer velocity (43–57) so Lead 1 stays prominent
                    let vel = UInt8(sparseMode ? 43 + rng.nextInt(upperBound: 15)
                                               : 58 + rng.nextInt(upperBound: 15))
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

    // MARK: - Bridge A-2 Lead 2 (call+response bridge)
    // Plays on odd bars alongside Lead 1, ascending 3rd→5th in mid register (MIDI 64–76).
    // Dotted-quarter durations contrast with Lead 1's quarter-note pulse; different register
    // (64–76 vs 72–84) so they weave together rather than doubling.

    static func generateBridgeAltLead2(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard section.label == .bridgeAlt else { continue }
            for bar in section.startBar..<section.endBar {
                let bridgeBar = bar - section.startBar
                guard bridgeBar % 2 == 1 else { continue }   // odd bars = response bars
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)
                let fifth  = 7

                func place(_ pc: Int) -> Int {
                    var m = 64 + rootPC + pc
                    while m > 76 { m -= 12 }
                    while m < 64 { m += 12 }
                    return m
                }

                // 2-note ascending complement: 3rd → 5th (dotted quarters = 6 steps each)
                let barStart = bar * 16
                let vel1 = UInt8(60 + rng.nextInt(upperBound: 14))   // 60–73
                let vel2 = UInt8(55 + rng.nextInt(upperBound: 14))   // 55–68
                events.append(MIDIEvent(stepIndex: barStart,     note: UInt8(place(third)), velocity: vel1, durationSteps: 6))
                events.append(MIDIEvent(stepIndex: barStart + 6, note: UInt8(place(fifth)), velocity: vel2, durationSteps: 6))
            }
        }
        return events
    }

    // MARK: - Bridge A-1 lead (escalating drums bridge)
    // Default: single sustained 5th held quietly for the full bridge.
    // 25% chance: X-Files whistle repeats on every bar instead — more dramatic.

    static func generateDrumBridgeLead(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG,
        xFilesBars: inout [Int]
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard section.label == .bridge else { continue }
            guard let entry = tonalMap.entry(atBar: section.startBar) else { continue }
            let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
            let useXFiles = rng.nextDouble() < 0.25

            if useXFiles {
                // X-Files whistle on 1–2 bars only — the theme lands harder as a brief appearance
                let candidates = Array(section.startBar..<section.endBar)
                let xBars = pickXFilesBars(from: candidates, minGap: 2, rng: &rng)
                for bar in xBars {
                    let barEvs = xFilesWhistleBar(bar: bar, frame: frame, tonalMap: tonalMap, rng: &rng)
                    guard !barEvs.isEmpty else { continue }
                    xFilesBars.append(bar)
                    events += barEvs
                }
            } else {
                // Default: single sustained 5th for the full bridge
                var note = 72 + rootPC + 7
                while note > 84 { note -= 12 }
                while note < 72 { note += 12 }
                let vel = UInt8(58 + rng.nextInt(upperBound: 12))
                let durationSteps = section.lengthBars * 16
                events.append(MIDIEvent(stepIndex: section.startBar * 16,
                                        note: UInt8(note), velocity: vel, durationSteps: durationSteps))
            }
        }
        return events
    }

    // MARK: - X-Files whistle — single bar helper
    // Emits the whistle phrase (5th→b7→root→2nd→5th→4th) for one bar.
    // Used by drum bridge (every bar) and melody bridge (middle bar only).

    private static func xFilesWhistleBar(
        bar: Int, frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard let entry = tonalMap.entry(atBar: bar) else { return [] }
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let mode   = entry.sectionMode
        let fifth  = 7; let flat7 = mode.nearestInterval(10)
        let second = mode.nearestInterval(2); let fourth = mode.nearestInterval(5)

        func place(_ pc: Int) -> Int {
            var m = 72 + rootPC + pc
            while m > 84 { m -= 12 }
            while m < 72 { m += 12 }
            return m
        }

        let xPhrase: [(Int, Int, Int)] = [
            (place(fifth),   0,  4),
            (place(flat7),   4,  2),
            (place(0),       6,  2),
            (place(second),  8,  4),
            (place(fifth),  12,  2),
            (place(fourth), 14,  4),
        ]
        let barStart = bar * 16
        return xPhrase.map { (note, step, dur) in
            MIDIEvent(stepIndex: barStart + step,
                      note: UInt8(note),
                      velocity: UInt8(72 + rng.nextInt(upperBound: 16)),
                      durationSteps: dur)
        }
    }

    // MARK: - X-Files bar picker
    // Returns 1–2 absolute bar numbers from `candidates` to play the X-Files theme.
    // With ≥4 candidates, 50% chance of picking two bars; guarantees a minimum gap
    // between them so repetition feels spaced out. Falls back to one bar if no valid
    // pair is found after several attempts.
    private static func pickXFilesBars(from candidates: [Int], minGap: Int, rng: inout SeededRNG) -> [Int] {
        guard !candidates.isEmpty else { return [] }
        let tryDouble = candidates.count >= 4 && rng.nextDouble() < 0.50
        if !tryDouble { return [candidates[rng.nextInt(upperBound: candidates.count)]] }
        for _ in 0..<15 {
            let i = rng.nextInt(upperBound: candidates.count)
            let j = rng.nextInt(upperBound: candidates.count)
            guard i != j else { continue }
            let (a, b) = candidates[i] < candidates[j]
                ? (candidates[i], candidates[j]) : (candidates[j], candidates[i])
            if b - a >= minGap { return [a, b] }
        }
        return [candidates[rng.nextInt(upperBound: candidates.count)]]
    }

    // MARK: - Bridge A-2 lead (call+response bridge)
    // The "call" is the drum+pads+bass hit on even bars.
    // Lead 1 provides the melodic "response" on odd bars — a short descending
    // 3-note phrase (5th→3rd→root) in the upper register, opposite direction to
    // the arpeggio's ascending figure, making the response clearly audible.

    static func generateBridgeAltLead(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG,
        xFilesBars: inout [Int]
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard section.label == .bridgeAlt else { continue }
            // ~30% chance: X-Files whistle on 1–2 response bars (spaced ≥4 bars apart)
            let useXFiles = rng.nextDouble() < 0.30
            let responseCandidates = (section.startBar..<section.endBar).filter { ($0 - section.startBar) % 2 == 1 }
            let xFilesSelected = useXFiles ? pickXFilesBars(from: responseCandidates, minGap: 4, rng: &rng) : []
            // Note: xFilesBars is populated per-bar below, only when events are confirmed generated
            let xFilesResponseBars: Set<Int> = Set(xFilesSelected)
            for bar in section.startBar..<section.endBar {
                let bridgeBar = bar - section.startBar
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)
                let fifth  = 7
                let flat7  = mode.nearestInterval(10)
                let second = mode.nearestInterval(2)
                let fourth = mode.nearestInterval(5)

                func place(_ pc: Int) -> Int {
                    var m = 72 + rootPC + pc
                    while m > 84 { m -= 12 }
                    while m < 72 { m += 12 }
                    return m
                }

                let barStart = bar * 16

                if bridgeBar % 2 == 0 {
                    // Call bar: sustained background note from beat 2
                    let note = useXFiles ? place(fourth) : place(fifth)
                    let vel  = UInt8(60 + rng.nextInt(upperBound: 14))   // 60–73, softer
                    events.append(MIDIEvent(stepIndex: barStart + 4, note: UInt8(note),
                                            velocity: vel, durationSteps: 11))
                } else if xFilesResponseBars.contains(bar) {
                    // X-Files whistle: 5th → b7 → root → 2nd → 5th → 4th
                    // Transposed from E–G–A–B–E–D in A minor to any key.
                    // Timing: quarter, eighth, eighth, quarter, eighth, eighth
                    let xPhrase: [(Int, Int, Int)] = [
                        (place(fifth),   0,  4),   // 5th — quarter
                        (place(flat7),   4,  2),   // b7  — eighth
                        (place(0),       6,  2),   // root — eighth
                        (place(second),  8,  4),   // 2nd — quarter
                        (place(fifth),  12,  2),   // 5th — eighth
                        (place(fourth), 14,  4),   // 4th — eighth (spills slightly)
                    ]
                    xFilesBars.append(bar)  // confirmed: entry valid, events will be generated
                    for (note, step, dur) in xPhrase {
                        let vel = UInt8(74 + rng.nextInt(upperBound: 16))   // 74–89
                        events.append(MIDIEvent(stepIndex: barStart + step,
                                                note: UInt8(note), velocity: vel, durationSteps: dur))
                    }
                } else {
                    // Standard descending response: 5th → 3rd → root (quarter notes)
                    let phrase = [place(fifth), place(third), place(0)]
                    for (i, note) in phrase.enumerated() {
                        let vel = UInt8(72 + rng.nextInt(upperBound: 18))   // 72–89
                        events.append(MIDIEvent(stepIndex: barStart + i * 4,
                                                note: UInt8(note), velocity: vel, durationSteps: 4))
                    }
                }
            }
        }
        return events
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
