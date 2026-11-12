// KosmicLeadGenerator.swift — Kosmic lead melody generation
// Copyright (c) 2026 Zack Urlocker
// Implements the Kosmic Lead 1 rules KOS-LD1-002 to 004, 006, 008 and 009, the Drift and Space
// Lead 1 rules, and the bar-by-bar Lead 2 rules. The hooks KOS-LD1-001, 005 and 007 are in
// HookLeadEngine and the base Lead 2 gap answers KOS-LD2-002 to 004 in GapAnswerEngine.
// KOS-LD1-006  JMJ Phrase Loop: 4–6 note melodic phrase built with arch contour (peaks at ~65%),
//              repeated identically for 4 bars, then one note shifts a scale step on bar 5,
//              another shifts on bar 7. Final phrase note lands on a chord tone. JMJ feel.
// KOS-LD1-008  Caligari Solo: slow lyrical chord-tone lead (from Caligari Drop bars 10–18).
//              1–2 chord-tone notes per bar, held 2–3 beats, slight rhythmic offset.
//              Plays in 2–3 windows of 8 bars with ≥6-bar gaps between repeats.
// KOS-LD1-009  Dark Sun Solo: spacious 70s analog synth lead (from Dark Sun bars 21–46).
//              One sustained note per bar, stepwise ascent then descent through scale.
//              Occasional chromatic trill ornament. Lower register (MIDI 60–76).
//              Plays in 2–3 windows of 10 bars with ≥8-bar gaps between repeats.
// Lead 1 register: MIDI 60–84 (C4–C6, one octave lower ceiling than original 96)
// Lead 2 register: MIDI 55–80 for KOS-LD2-005; the gap answers use 52–69
// Velocity: 45–72 (softer than Motorik — kosmic is never aggressive)

import Foundation

/// Kosmic Space Lead 1: each homage rule's per-song draws in a few plain words, for the log beside
/// the rule's name ("Oxygene See-Saw Riff sixth, 2+2+2"). Only draws that differ from the source
/// are named; empty when a rule played its source form. Zack, 2026-11-12, after the Chill jazz
/// lead versions: name the transformations.
final class KosmicLeadNotes {
    var byRule: [String: String] = [:]
    /// The log words for a song's draws: plain words, at most two (the rule's name comes first).
    static func words(_ list: [String?], limit: Int = 2) -> String {
        list.compactMap { $0 }.prefix(limit).joined(separator: ", ")
    }
}

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
        xFilesBars: inout [Int],
        isKosmicDrift: Bool = false,
        isDriftDreamscape: Bool = false,
        driftVelocityBase: Int = 89,
        isKosmicSpace: Bool = false,
        spaceArrangement: KosmicSpaceArrangement? = nil,
        notes: KosmicLeadNotes? = nil
    ) -> [MIDIEvent] {

        // Kosmic Space: KOS-LD1-013 Falling Theme, KOS-LD1-016 Rising Strings or KOS-LD1-017 Offbeat
        // Climb in A sections, a third each, the
        // KOS-LD1-014 riff or KOS-LD1-006 Phrase Loop in B sections. Space sets its own A and B rules,
        // so Technique D escalation never runs.
        if isKosmicSpace {
            let _ = pickLeadRule(rng: &rng)   // consume base slot
            lead1BaseRule = "KOS-LD1-013"
            usedRuleIDs.insert("KOS-LD1-013")
            if structure.sections.contains(where: { $0.label == .B }) { usedRuleIDs.insert("KOS-LD1-014") }
            var themeNote = "", riffNote = ""
            var theme = generateOxygeneFallingTheme(frame: frame, structure: structure, tonalMap: tonalMap,
                                                    rng: &rng, note: &themeNote)
            var riff = generateOxygeneSeeSawRiff(frame: frame, structure: structure, tonalMap: tonalMap,
                                                 rng: &rng, note: &riffNote)
            // In 50% of songs KOS-LD1-006 JMJ Phrase Loop plays the B sections in place of the riff,
            // for variety. Drawn after the theme and riff, so they are unchanged for a given seed.
            var phrase: [MIDIEvent] = []
            if rng.nextDouble() < 0.50, structure.sections.contains(where: { $0.label == .B }) {
                var discard: [Int] = []
                let bSections = structure.sections.filter { $0.label == .B }
                func inB(_ ev: MIDIEvent) -> Bool {
                    bSections.contains { ($0.startBar..<$0.endBar).contains(ev.stepIndex / 16) }
                }
                phrase = generateJMJPhraseLoop(frame: frame, structure: structure, tonalMap: tonalMap,
                                               rng: &rng, xFilesBars: &discard).filter(inB)
                riff = riff.filter { !inB($0) }
                usedRuleIDs.remove("KOS-LD1-014")
                usedRuleIDs.insert("KOS-LD1-006")
            }
            // In 50% of songs KOS-LD1-016 Rising Strings plays the A sections in place of the theme.
            // Drawn last, so the other Lead 1 draws are unchanged for a given seed.
            if rng.nextDouble() < 0.50 {
                theme = generateOxygeneRisingStrings(frame: frame, structure: structure, tonalMap: tonalMap,
                                                     rng: &rng, note: &themeNote)
                lead1BaseRule = "KOS-LD1-016"
                usedRuleIDs.remove("KOS-LD1-013")
                usedRuleIDs.insert("KOS-LD1-016")
            }
            // In a third of songs KOS-LD1-017 Offbeat Climb plays the A sections instead, so the three
            // A-section rules share them evenly. Drawn last, so the earlier draws are unchanged.
            if rng.nextDouble() < 1.0 / 3.0 {
                theme = generateOxygeneOffbeatClimb(frame: frame, structure: structure, tonalMap: tonalMap,
                                                    rng: &rng, note: &themeNote)
                lead1BaseRule = "KOS-LD1-017"
                usedRuleIDs.remove("KOS-LD1-013")
                usedRuleIDs.remove("KOS-LD1-016")
                usedRuleIDs.insert("KOS-LD1-017")
            }
            // In a quarter of songs KOS-LD1-015 Magnetic Fields Turn Melody plays the A sections
            // instead, so the four A-section rules share them evenly. Drawn last, as above.
            if rng.nextDouble() < 0.25 {
                theme = generateMagneticTurnMelody(frame: frame, structure: structure, tonalMap: tonalMap,
                                                   rng: &rng, note: &themeNote)
                lead1BaseRule = "KOS-LD1-015"
                usedRuleIDs.subtract(["KOS-LD1-013", "KOS-LD1-016", "KOS-LD1-017"])
                usedRuleIDs.insert("KOS-LD1-015")
            }
            // In a fifth of songs KOS-LD1-018 Magnetic Call and Hold plays the A sections instead, so
            // the five A-section rules share them evenly. Drawn last, as above.
            if rng.nextDouble() < 0.20 {
                theme = generateMagneticCallAndHold(frame: frame, structure: structure, tonalMap: tonalMap,
                                                    rng: &rng, note: &themeNote)
                lead1BaseRule = "KOS-LD1-018"
                usedRuleIDs.subtract(["KOS-LD1-013", "KOS-LD1-015", "KOS-LD1-016", "KOS-LD1-017"])
                usedRuleIDs.insert("KOS-LD1-018")
            }
            // In a third of songs with a B section KOS-LD1-019 Equinoxe Thirds Riff plays the B sections
            // in place of the riff or the Phrase Loop, so the three B-section rules share them evenly.
            if structure.sections.contains(where: { $0.label == .B }), rng.nextDouble() < 1.0 / 3.0 {
                riff = generateOxygeneSeeSawRiff(frame: frame, structure: structure, tonalMap: tonalMap,
                                                 rng: &rng, equinoxeThirds: true, note: &riffNote)
                phrase = []
                usedRuleIDs.subtract(["KOS-LD1-014", "KOS-LD1-006"])
                usedRuleIDs.insert("KOS-LD1-019")
            }
            var lead = theme + riff + phrase
            if let notes {
                notes.byRule[lead1BaseRule] = themeNote
                for id in ["KOS-LD1-014", "KOS-LD1-019"] where usedRuleIDs.contains(id) { notes.byRule[id] = riffNote }
            }
            // Theme return (Zack, 2026-11-03): a song that ends on B (ab, abab) never hears its A theme
            // again, so 8 bars two thirds into the last B replay the first A section's opening 8 bars
            // in place of the B rule. The chord plan gives those 8 bars the first A section's opening
            // chords (SpaceThemeReturn). No draws, so regen rebuilds it exactly.
            if let themeReturn = SpaceThemeReturn.make(sections: structure.sections) {
                let window = (themeReturn.range.lowerBound * 16)..<(themeReturn.range.upperBound * 16)
                let source = (themeReturn.sourceRange.lowerBound * 16)..<(themeReturn.sourceRange.upperBound * 16)
                let shift = themeReturn.shift * 16
                lead.removeAll { window.contains($0.stepIndex) }
                lead += theme.filter { source.contains($0.stepIndex) }.map {
                    MIDIEvent(stepIndex: $0.stepIndex + shift, note: $0.note, velocity: $0.velocity,
                              durationSteps: Swift.min($0.durationSteps, source.upperBound - $0.stepIndex))
                }
                // The log says the theme comes back when the line has room (two words at most).
                if let notes {
                    let draws = (notes.byRule[lead1BaseRule] ?? "").components(separatedBy: ", ")
                        .filter { !$0.isEmpty }
                    notes.byRule[lead1BaseRule] = (draws.count < 2 ? draws + ["returns"] : draws)
                        .joined(separator: ", ")
                }
            }
            // The lead's rests are the arrangement's main relief, as in Oxygene 4, 6 and 8. It sits out
            // the bridge too.
            return silenceBars(lead, spaceArrangement?.lead1Silences ?? [])
        }

        // Drift lead pool — different weights and includes new rules 010/011/012
        let aRule: String
        if isKosmicDrift {
            let _ = pickLeadRule(rng: &rng)   // consume base slot for seed stability
            if isDriftDreamscape {
                aRule = forceRuleID ?? "KOS-LD1-012"
            } else {
                // Drift-exclusive (010/011/012) = 78%; shared = 22%
                // KOS-LD1-004 (Echo Melody) excluded — question-answer structure is too composed for Drift
                let driftRules:   [String] = ["KOS-LD1-010", "KOS-LD1-011", "KOS-LD1-012",
                                              "KOS-LD1-002", "KOS-LD1-008", "KOS-LD1-009",
                                              "KOS-LD1-003"]
                let driftWeights: [Double] = [0.28,           0.27,           0.23,
                                              0.09,           0.05,           0.05,
                                              0.03]
                aRule = forceRuleID ?? driftRules[rng.weightedPick(driftWeights)]
            }
        } else {
            aRule = forceRuleID ?? pickLeadRule(rng: &rng)
        }
        lead1BaseRule = aRule
        usedRuleIDs.insert(aRule)

        // Dispatch Drift-specific section-level rules before the base rules
        if aRule == "KOS-LD1-010" {
            return generateTychoPhrase(frame: frame, structure: structure, tonalMap: tonalMap,
                                       rng: &rng, velBase: driftVelocityBase)
        }
        if aRule == "KOS-LD1-011" {
            usedRuleIDs.insert("KOS-LD1-011")
            let evolving = rng.nextDouble() >= 0.30   // 70% evolving, 30% static-with-micro-evolution
            return generateDriftMemory(frame: frame, structure: structure, tonalMap: tonalMap,
                                       rng: &rng, velBase: driftVelocityBase, evolving: evolving)
        }
        if aRule == "KOS-LD1-012" {
            usedRuleIDs.remove("KOS-LD1-012")
            usedRuleIDs.insert("KOS-LD1-012")
            return generateSvefnFloat(frame: frame, structure: structure, tonalMap: tonalMap,
                                      rng: &rng, velBase: driftVelocityBase)
        }

        // Technique D: B sections use a different rule for contrast.
        // Sparse ambient rules (001, 002, 003) always escalate to a denser rule in B sections
        // so the song has a genuine arc: ambient A → melodic B → return.
        // Other Lead 1 rules keep the original 60% Technique D probability.
        // bRule is KOS-LD1-002, 003 or 004 (played by emitLeadBar) or KOS-LD1-006 (played a
        // section at a time by jmjPhraseSection). The section-level A rules KOS-LD1-006, 008 and
        // 009 play every section themselves and ignore bRule, so their draw is kept for seed
        // stability but not logged.
        let sparseLeadRules: Set<String> = ["KOS-LD1-002", "KOS-LD1-003"]
        let sectionLevelRules: Set<String> = ["KOS-LD1-006", "KOS-LD1-008", "KOS-LD1-009"]
        let hasBSection = structure.sections.contains { $0.label == .B }
        // A transcription hook (KOS-LD1-001, 005 or 007) owns both the A and the B sections, so it
        // makes no Technique D draw.
        let hook = HookLeadEngine.kosmicRules[aRule]
        let bRule: String
        if hook != nil {
            bRule = aRule
        } else if sparseLeadRules.contains(aRule) {
            // Escalate to a denser rule for B sections.
            // Drift: KOS-LD1-006 excluded — escalate to 004 (Echo Melody) only.
            bRule = isKosmicDrift ? "KOS-LD1-004" : pickDenseLeadRule(rng: &rng)
            if hasBSection { usedRuleIDs.insert(bRule) }
        } else if rng.nextDouble() < 0.60 {
            bRule = pickBSectionRule(excluding: aRule, isKosmicDrift: isKosmicDrift, rng: &rng)
            if hasBSection && bRule != aRule && !sectionLevelRules.contains(aRule) {
                usedRuleIDs.insert(bRule)
            }
        } else {
            bRule = aRule
        }

        // Bridge melody sections always use a distinct rule (independent of Technique D)
        // Drift: exclude KOS-LD1-006 from bridge melody selection.
        let bridgeMelodyRule = isKosmicDrift
            ? pickLeadRuleDifferentFrom(aRule, excluding: ["KOS-LD1-006"], rng: &rng)
            : pickLeadRuleDifferentFrom(aRule, rng: &rng)

        // KOS-LD1-006/008/009 use section-level phrase generation — bypass per-bar dispatch
        if aRule == "KOS-LD1-006" {
            return generateJMJPhraseLoop(frame: frame, structure: structure,
                                         tonalMap: tonalMap, bRule: bRule, rng: &rng,
                                         xFilesBars: &xFilesBars)
        }
        if aRule == "KOS-LD1-008" {
            return generateCaligariSolo(frame: frame, structure: structure,
                                        tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)
        }
        if aRule == "KOS-LD1-009" {
            return generateDarkSunSolo(frame: frame, structure: structure,
                                       tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)
        }

        // KOS-RULE-24: commit to interval style
        let useWideInterval = rng.nextDouble() < 0.40

        var events: [MIDIEvent] = []

        // Bridge A-1: sustained 5th for the full bridge duration
        events += generateDrumBridgeLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)
        // Bridge A-2: short descending melodic response on odd (non-hit) bars
        events += generateBridgeAltLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)

        // The hook rules lay out the whole song in one call. The bridges, and anything else outside
        // the A and B sections, stay with the code below.
        if let hook {
            let aStart = structure.sections.first(where: { $0.label == .A })?.startBar ?? 0
            events += HookLeadEngine.generate(
                rule: hook, frame: frame, structure: structure, tonalMap: tonalMap,
                entryBar: aStart + 4, restBars: [],
                register: HookLeadEngine.kosmicRegister, rng: &rng)
        }

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
                    addXFilesWhistles(to: &melodyEvents, section: section, frame: frame, tonalMap: tonalMap,
                                           rng: &rng, xFilesBars: &xFilesBars)
                }
                events += melodyEvents
                continue
            }
            // B sections: use Technique D rule if selected
            let activeRule = (section.label == .B) ? bRule : aRule
            if hook != nil { continue }
            // KOS-LD1-006 JMJ phrase loop is built a section at a time, so a B section escalated
            // to it gets the JMJ section phrase instead of the per-bar rules below.
            if activeRule == "KOS-LD1-006" {
                events += jmjPhraseSection(section: section, frame: frame, tonalMap: tonalMap,
                                           sparseMode: false, rng: &rng)
                continue
            }
            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                let scaleNotes = scaleNotesInRegister(entry: entry, frame: frame,
                                                      low: 60, high: 84)
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
        lead1BaseRuleID: String? = nil,
        xFilesBars: [Int] = [],
        isKosmicSpace: Bool = false,
        spaceArrangement: KosmicSpaceArrangement? = nil,
        rhythmEvents: [MIDIEvent] = []
    ) -> [MIDIEvent] {

        let baseRule = pickLeadRule2(rng: &rng)
        // Kosmic Space: KOS-LD2-005 Space echo reply, KOS-LD2-001 Magnetic Twin and KOS-LD2-000 No
        // lead 2, a third each.
        let rule: String
        if isKosmicSpace {
            let r = rng.nextDouble()
            if r >= 2.0 / 3.0 {
                usedRuleIDs.insert("KOS-LD2-000")
                return []
            }
            if r >= 1.0 / 3.0 {
                usedRuleIDs.insert("KOS-LD2-001")
                return rng.nextDouble() < 0.50
                    ? spaceStereoTwin(rhythm: rhythmEvents, structure: structure)
                    : magneticLateOctave(lead1: lead1Events, totalBars: frame.totalBars)
            }
            rule = "KOS-LD2-005"
        } else {
            rule = baseRule
        }
        usedRuleIDs.insert(rule)

        // A gap-answer rule is written later by SongGenerator, from the Lead 1 the listener hears
        // after the filters. Only the bridge A-2 response figure is written here.
        if GapAnswerEngine.isKosmicGapRule(rule) {
            return generateBridgeAltLead2(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng,
                                          xFilesBars: xFilesBars)
        }

        // KOS-LD2-005 Space echo reply, the only Lead 2 rule written bar by bar.
        var events: [MIDIEvent] = []

        // Bridge A-2: Lead 2 plays a complementary ascending figure on response bars (silent on X-Files bars)
        events += generateBridgeAltLead2(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng,
                                         xFilesBars: xFilesBars)

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            // Lead 2 silent in A-1 and melody bridges; bridgeAlt handled above
            guard section.label != .bridge && section.label != .bridgeMelody else { continue }
            guard section.label != .bridgeAlt else { continue }
            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                // In .low sections constrain Lead 2 to lower half (55–67) leaving 67–80 for Lead 1
                let lead2High = section.intensity == .low ? 67 : 80
                let scaleNotes = scaleNotesInRegister(entry: entry, frame: frame,
                                                      low: 55, high: lead2High)
                events += spaceEchoReplyBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
            }
        }

        // Phase 2 — Step-level avoidance: if a Lead 2 note attacks on the exact same step
        // as a Lead 1 note, shift it forward by 2 steps (the "and" of the beat) rather than
        // removing it. This keeps Lead 2 audible as a staggered response voice even when
        // Lead 1 is dense (e.g. KOS-LD1-006 which fires at step 0 of every bar).
        let lead1StepSet = Set(lead1Events.map(\.stepIndex))
        events = events.map { ev -> MIDIEvent in
            guard lead1StepSet.contains(ev.stepIndex) else { return ev }
            let barStart  = (ev.stepIndex / 16) * 16
            let barEnd    = barStart + 16
            let shifted   = ev.stepIndex + 2
            // Only shift if the new position is still within the same bar and not also occupied
            guard shifted < barEnd, !lead1StepSet.contains(shifted) else { return ev }
            return MIDIEvent(stepIndex: shifted, note: ev.note,
                             velocity: ev.velocity, durationSteps: max(1, ev.durationSteps - 2))
        }

        // Phase 3 — Simultaneous-silence safety net:
        // Scan body sections in 4-bar windows. If both Lead 1 and Lead 2 are completely
        // silent in a window, inject a single held tone in Lead 2 at the window start.
        let lead1ActiveBars = Set(lead1Events.map { $0.stepIndex / 16 })
        let lead2ActiveBars = Set(events.map      { $0.stepIndex / 16 })
        for section in structure.sections {
            guard !section.label.isBridge else { continue }
            guard section.label != .intro && section.label != .outro else { continue }
            guard section.label != .bridgeMelody else { continue }
            var bar = section.startBar
            while bar < section.endBar {
                let windowEnd = min(bar + 4, section.endBar)
                let lead2Present = (bar..<windowEnd).contains { lead2ActiveBars.contains($0) }
                let lead1Present = (bar..<windowEnd).contains { lead1ActiveBars.contains($0) }
                if !lead2Present && !lead1Present {
                    if let entry = tonalMap.entry(atBar: bar) {
                        let scaleNotes = scaleNotesInRegister(entry: entry, frame: frame, low: 55, high: 80)
                        if !scaleNotes.isEmpty {
                            let note = scaleNotes[rng.nextInt(upperBound: scaleNotes.count)]
                            let vel  = UInt8(48 + rng.nextInt(upperBound: 15))
                            events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(note),
                                                    velocity: vel, durationSteps: 28))
                        }
                    }
                }
                bar += 4
            }
        }

        // Kosmic Space: Lead 2 drops out with the sequencer, as in Oxygene 8 and Oxygene 4, and
        // through the bridge.
        if let silences = spaceArrangement?.lead2Silences {
            events = silenceBars(events, silences)
        }
        return events
    }

    // MARK: - KOS-LD1-013 Oxygene Falling Theme (Kosmic Space, A sections)
    // Oxygene 4 theme, both transcriptions. In the source it is on a second voice; here it moves to
    // Lead 1 for the A sections, which is how the source alternates theme and riff.
    // A 2-bar statement: five notes on steps 0, 6, 8, 10, 14 (x.....x.x.x...x.), falling from high
    // through chord tones to the root — top (6 steps), 5th (2), 3rd (3), 5th (3), root held through
    // the second bar. Register: the root in MIDI 60–71, so an octave top lands in 72–83.
    // Homage draws per song:
    //   top — octave 30% (source), 6th 35% (the second measured pattern), 4th 35%
    //   inner line — 5-3-5 35% (source), 5-4-5 35%, 6-5-3 30%
    //   rhythm — the source 60%, or the compressed form both transcriptions also use 40%: four notes
    //            on steps 0, 2, 4, 6 falling by scale step to the root, the last held through
    // Within song (statements counted across all A sections): statements 1 and 2 exact. From
    // statement 3 one variation each — transposed to the current chord root 40%, the opening note
    // dropped so the figure starts on step 6 30%, or the final root replaced by the 5th, left open
    // 30%. Every fourth statement is exact, and one in four is 2 bars of rest, so the theme breathes.

    private static func generateOxygeneFallingTheme(
        frame: GlobalMusicalFrame, structure: SongStructure, tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG, note: inout String
    ) -> [MIDIEvent] {
        let tops: [(steps: Int, name: String)] = [(7, "octave top"), (5, "lower top"), (3, "low top")]
        let top = tops[rng.weightedPick([0.30, 0.35, 0.35])]
        let inners: [(steps: [Int], name: String)] = [([4, 2, 4], "5-3-5"), ([4, 3, 4], "closer middle"),
                                                      ([5, 4, 2], "steady fall")]
        let inner = inners[rng.weightedPick([0.35, 0.35, 0.30])]
        let compressed = rng.nextDouble() < 0.40

        // Note count and rhythm. The source form (5 notes on 0, 6, 8, 10, 14) is one option among
        // several, and a song never plays it with the source top note and inner line as well:
        // statements 1 and 2 are exact within the song's own draws, so they must not be the original.
        let sourceShape = top.steps == 7 && inner.steps == [4, 2, 4]
        let countRoll = rng.nextDouble()
        var noteCount = countRoll < 0.50 ? 5 : (countRoll < 0.75 ? 4 : 6)
        if noteCount == 6 && top.steps <= inner.steps[0] + 1 { noteCount = 5 }   // no room for a passing note
        var onsets: [Int]
        switch noteCount {
        case 4:
            onsets = rng.nextDouble() < 0.5 ? [0, 6, 10, 14] : [0, 8, 10, 14]
        case 6:
            onsets = rng.nextDouble() < 0.5 ? [0, 4, 6, 8, 10, 14] : [0, 6, 8, 10, 12, 14]
        default:
            let r = rng.nextDouble()
            onsets = r < 0.35 ? [0, 6, 8, 10, 14] : (r < 0.70 ? [0, 4, 8, 10, 14] : [0, 6, 10, 12, 14])
            if sourceShape && onsets == [0, 6, 8, 10, 14] {
                onsets = rng.nextDouble() < 0.5 ? [0, 4, 8, 10, 14] : [0, 6, 10, 12, 14]
            }
        }
        // The log names what differs from the source; the compressed run replaces the whole figure.
        var words: [String] = []
        if compressed { words = ["squeezed"] } else {
            if top.steps != 7 { words.append(top.name) }
            if inner.steps != [4, 2, 4] { words.append(inner.name) }
            if noteCount != 5 { words.append(noteCount == 4 ? "fewer notes" : "more notes") }
            else if onsets != [0, 6, 8, 10, 14] { words.append("new rhythm") }
        }
        note = KosmicLeadNotes.words(words)

        // Scale steps above the root for each note, falling to the root
        var pitchSteps: [Int]
        switch noteCount {
        case 4:  pitchSteps = [top.steps, inner.steps[0], inner.steps[2], 0]
        case 6:  pitchSteps = [top.steps, inner.steps[0] + 1, inner.steps[0], inner.steps[1], inner.steps[2], 0]
        default: pitchSteps = [top.steps] + inner.steps + [0]
        }
        let scalePCs = frame.scalePCs
        let tonicRoot = clampToRegister(snapToScale(keySemitone(frame.key), scalePCs: scalePCs) + 60,
                                        low: 60, high: 71)
        // (step, scale steps above the root, duration)
        var figure: [(step: Int, steps: Int, dur: Int)] = []
        if compressed {
            figure = [(0, 3, 2), (2, 2, 2), (4, 1, 2), (6, 0, 26)]
        } else if onsets == [0, 6, 8, 10, 14] {
            figure = [(0, pitchSteps[0], 6), (6, pitchSteps[1], 2), (8, pitchSteps[2], 3),
                      (10, pitchSteps[3], 3), (14, pitchSteps[4], 16)]
        } else {
            for (i, onset) in onsets.enumerated() {
                let last = i == onsets.count - 1
                figure.append((onset, pitchSteps[i], last ? 16 : Swift.max(1, onsets[i + 1] - onset)))
            }
        }

        var events: [MIDIEvent] = []
        var statement = 0
        for section in structure.sections where section.label == .A {
            var bar = section.startBar
            while bar < section.endBar {
                defer { bar += 2; statement += 1 }
                let exact = statement < 2 || statement % 4 == 0
                if !exact && statement % 4 == 3 { continue }   // 2 bars of rest
                var transpose = false, dropOpening = false, openEnding = false
                if !exact {
                    let r = rng.nextDouble()
                    if r < 0.40 { transpose = true } else if r < 0.70 { dropOpening = true } else { openEnding = true }
                }
                var root = tonicRoot
                if transpose, let entry = tonalMap.entry(atBar: bar) {
                    root = clampToRegister(spaceChordRootPC(entry, frame: frame) + 60, low: 60, high: 71)
                }
                let start = bar * 16
                let end   = Swift.min(bar + 2, section.endBar) * 16
                for (i, note) in figure.enumerated() {
                    if dropOpening && i == 0 { continue }
                    let isLast = i == figure.count - 1
                    let pitch = scaleStep(root, by: isLast && openEnding ? 4 : note.steps, scalePCs: scalePCs)
                    let onset = start + note.step
                    guard onset < end else { continue }
                    events.append(MIDIEvent(stepIndex: onset, note: UInt8(pitch),
                                            velocity: i == 0 ? 66 : (isLast ? 58 : 62),
                                            durationSteps: Swift.min(note.dur, end - onset)))
                }
            }
        }
        return events
    }

    // MARK: - KOS-LD1-016 Oxygene 6 Rising Strings (Kosmic Space, A sections)
    // Oxygene 6 strings, bars 34–53, played identically again at bars 76–95. Three long notes a bar
    // on steps 0, 6 and 12 (held 6, 6 and 4), each bar a 3-note cell on the current chord:
    //   climb, 4 bars — up, neighbour, up, up: each cell starts on a chord tone, a step above or
    //                   below where the last one ended, so the line rises by about an octave
    //   fall, 4 bars  — four falling cells from the top, the third bouncing back up
    //   hold          — one chord tone a step above the fall's end, held a bar
    // The source cycle, 16 bars: climb, climb, fall, hold, three bars of rest. Register MIDI 58–84.
    // Chord tones on the long notes (Zack, 2026-11-07: stepwise cells held passing tones for 3/8 of
    // the bar and did not sit on the chord): the first two notes of a cell are chord tones, the
    // third is a scale step on when it is short (steps 12–15) and another chord tone when it is long.
    // Homage draws per song:
    //   chromatic approach — each climb is led in by a 16th a semitone below its first note on
    //                        step 15 of the bar before, as the source's F#-G-A does, 60%
    //   rhythm — the source 60%, or steps 0, 6 and 10 (held 6, 4 and 6) 40%
    //   cycle — the source 60%, or an 8-bar climb and fall with no hold or rest 40%
    // Within-song development: passes 1 and 2 of the cycle are plain, then each pass starts its
    // climbs a chord tone lower or higher, or plays the reshaped cycle (the neighbour cell third in
    // the climb, no bounce in the fall), never the same variant twice running; every fourth pass is
    // plain. The pass draws use a copy of the RNG, so the draws after this rule are unchanged.

    private enum RisingCell { case up, neighbour, down, hold, rest }
    private enum RisingVariant { case plain, lower, higher, reshaped }

    private static func generateOxygeneRisingStrings(
        frame: GlobalMusicalFrame, structure: SongStructure, tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG, note: inout String
    ) -> [MIDIEvent] {
        let approach = rng.nextDouble() < 0.60
        let onsets: [(step: Int, dur: Int)] = rng.nextDouble() < 0.40
            ? [(0, 6), (6, 4), (10, 6)] : [(0, 6), (6, 6), (12, 4)]
        let longCycle = rng.nextDouble() >= 0.40
        note = KosmicLeadNotes.words([approach ? nil : "no lead-in", onsets[2].step == 10 ? "early third" : nil,
                                      longCycle ? nil : "short cycle"])
        var peek = rng
        var passRNG = SeededRNG(seed: peek.next() ^ 0x0E06_A5C3_1976_0016)
        func cycle(_ v: RisingVariant) -> [RisingCell] {
            let climb: [RisingCell] = v == .reshaped ? [.up, .up, .neighbour, .up] : [.up, .neighbour, .up, .up]
            let fall:  [RisingCell] = [.down, .down, .down, .down]
            return longCycle ? climb + climb + fall + [.hold, .rest, .rest, .rest] : climb + fall
        }
        let cycleLength = longCycle ? 16 : 8
        let thirdIsShort = onsets[2].dur <= 4
        let scalePCs = frame.scalePCs

        var events: [MIDIEvent] = []
        var pass = -1
        var variant = RisingVariant.plain
        var lastVariant = RisingVariant.plain
        for section in structure.sections where section.label == .A {
            var last = 62
            for bar in section.startBar..<section.endBar {
                let pos = (bar - section.startBar) % cycleLength
                if pos == 0 {
                    pass += 1
                    if pass < 2 || pass % 4 == 3 {
                        variant = .plain
                    } else {
                        let options = [RisingVariant.lower, .higher, .reshaped].filter { $0 != lastVariant }
                        variant = options[passRNG.nextInt(upperBound: options.count)]
                        lastVariant = variant
                    }
                }
                let cell = cycle(variant)[pos]
                guard cell != .rest, let entry = tonalMap.entry(atBar: bar) else { continue }
                let root = spaceChordRootPC(entry, frame: frame) + 60
                let tones = Set([root, scaleStep(root, by: 2, scalePCs: scalePCs),
                                 scaleStep(root, by: 4, scalePCs: scalePCs)].map { $0 % 12 })
                func toneAbove(_ t: Int) -> Int { (t...(t + 12)).first { tones.contains($0 % 12) } ?? t }
                func toneBelow(_ t: Int) -> Int { stride(from: t, through: t - 12, by: -1).first { tones.contains($0 % 12) } ?? t }
                func step(_ m: Int, _ by: Int) -> Int { scaleStep(m, by: by, scalePCs: scalePCs) }

                // Where a climb opens: the chord tone at or above D4, or one chord tone either side.
                let climbStart: Int
                switch variant {
                case .lower:  climbStart = toneBelow(toneAbove(62) - 1)
                case .higher: climbStart = toneAbove(toneAbove(62) + 1)
                default:      climbStart = toneAbove(62)
                }
                let bounce = variant != .reshaped

                // The cell's first chord tone, placed against where the last cell ended. An up cell
                // on a 4-bar boundary always opens a climb, which starts again from the bottom.
                var start: Int
                switch (cell, pos % 4) {
                case (.hold, _):              start = toneAbove(step(last, 1))
                case (.up, 0):                start = climbStart
                case (.neighbour, _):         start = toneAbove(step(last, 1))
                case (.up, 2):                start = toneAbove(step(last, -1))
                case (.up, _):                start = toneAbove(step(last, 1))
                case (.down, 0):              start = toneBelow(last)
                case (.down, 2) where bounce: start = toneAbove(step(last, 2))
                default:                      start = toneBelow(step(last, -1))
                }
                if start > 79 { start = toneBelow(start - 12) }
                if start < 58 { start = toneAbove(start + 12) }

                var notes: [Int]
                switch cell {
                case .up:
                    let second = toneAbove(start + 1)
                    notes = [start, second, thirdIsShort ? step(second, 1) : toneAbove(second + 1)]
                case .neighbour:
                    notes = [start, toneBelow(start - 1), start]
                case .down:
                    let second = toneBelow(start - 1)
                    notes = [start, second, thirdIsShort ? step(second, -1) : toneBelow(second - 1)]
                default:
                    notes = [start]
                }
                // A cell reaching past the register turns back at its edge onto the nearest chord
                // tone inside it, so the line bends there rather than jumping an octave.
                notes = notes.map { $0 < 58 ? toneAbove(58) : $0 > 84 ? toneBelow(84) : $0 }
                let end = section.endBar * 16
                // The chromatic lead-in, a 16th before the climb, cutting short any note under it; none when
                // the note before already is that pitch.
                if cell == .up && pos % 4 == 0 && approach && bar > section.startBar,
                   !events.contains(where: { $0.stepIndex == bar * 16 - 4 && Int($0.note) == start - 1 }) {
                    let pickup = bar * 16 - 1
                    events = events.map { ev in
                        ev.stepIndex < pickup && ev.stepIndex + ev.durationSteps > pickup
                            ? MIDIEvent(stepIndex: ev.stepIndex, note: ev.note, velocity: ev.velocity,
                                        durationSteps: pickup - ev.stepIndex)
                            : ev
                    }
                    events.append(MIDIEvent(stepIndex: pickup, note: UInt8(start - 1), velocity: 58,
                                            durationSteps: 1))
                }
                if cell == .hold {
                    events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(start), velocity: 62,
                                            durationSteps: Swift.min(16, end - bar * 16)))
                } else {
                    for (i, note) in notes.enumerated() {
                        let onset = bar * 16 + onsets[i].step
                        guard onset < end else { continue }
                        events.append(MIDIEvent(stepIndex: onset, note: UInt8(note),
                                                velocity: i == 0 ? 66 : 60,
                                                durationSteps: Swift.min(onsets[i].dur, end - onset)))
                    }
                }
                last = notes.last ?? start
            }
        }
        return events
    }

    // MARK: - KOS-LD1-017 Oxygene 8 Offbeat Climb (Kosmic Space, A sections)
    // Oxygene 8 lead, alto sax, piano and clarinet in unison, bars 17–49 and 67–138. Each statement
    // fills one bar and the next is silent. It enters off the beat on step 2 and climbs by step from
    // a leap up to the chord root: steps 2, 4, 6, 8, 11 and 14, the last two dotted 8ths apart.
    // Statements, in scale steps from the current chord root:
    //   climb — 5th below, root, 2nd, 3rd, 4th, 4th
    //   leap  — 5th, 4th, 5th, 6th, 7th, on steps 2, 6, 8, 11, 14 (the source drops to the root and
    //           back; a step down is smoother on a synth lead)
    //   turn  — the climb's first four, then back to the root and the 2nd
    // Phrase, 16 bars, starting 2 bars into each A section so that, as in the source, every
    // statement lands in the second bar of its chord window: a single root on step 0 as a pickup,
    // climb, leap, turn, pickup, climb, leap, and a falling answer from the tonic's 6th to the 5th
    // below on steps 6, 8, 10, 13 and 15. Every third phrase, as the source's bars 41–49 do: pickup,
    // climb, then a 2-bar arch three times, 3rd, 4th and 5th of the key rising across the bar line and
    // falling back to the tonic, then 7 bars of rest.
    // Legato (Zack, 2026-11-03: the source's short notes sounded clunky on a synth lead): each note is
    // held to the next, the last of a statement rings 10 steps into the silent bar, and the pickup
    // holds into the statement's entry, so the line flows and never restarts from silence.
    // Register: the tonic in MIDI 62–73 and each chord root within a fifth of it, as the source
    // places them; a statement that would pass 84 drops an octave whole. Legato joins each half
    // phrase into one figure that reaches above 67, so the harmonic filter's lift above the pads never
    // moves one statement without the others.
    // Homage draws per song:
    //   opening leap — from the 5th below 40% (source), the 6th below 30%, the 4th below 30%
    //   climb's top — the 4th repeated 40% (source), on to the 5th 30%, turning back to the 3rd 30%
    //   rhythm — the source 60%, or steps 2, 4, 6, 8, 10 and 13 40%; always the latter when the leap
    //            and the top are both the source's

    private static func generateOxygeneOffbeatClimb(
        frame: GlobalMusicalFrame, structure: SongStructure, tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG, note: inout String
    ) -> [MIDIEvent] {
        let leap = [-3, -2, -4][rng.weightedPick([0.40, 0.30, 0.30])]
        let top = [[3, 3], [3, 4], [3, 2]][rng.weightedPick([0.40, 0.30, 0.30])]
        // A song never plays the source leap, top and rhythm together, so it never copies the tune.
        let rhythmRoll = rng.nextDouble()
        let altRhythm = rhythmRoll < 0.40 || (leap == -3 && top == [3, 3])
        let sixOnsets  = altRhythm ? [2, 4, 6, 8, 10, 13] : [2, 4, 6, 8, 11, 14]
        let fiveOnsets = altRhythm ? [2, 6, 8, 10, 13] : [2, 6, 8, 11, 14]
        note = KosmicLeadNotes.words([leap == -2 ? "high start" : leap == -4 ? "low start" : nil,
                                      top == [3, 4] ? "ends higher" : top == [3, 2] ? "ends lower" : nil,
                                      altRhythm ? "early finish" : nil])
        let scalePCs = frame.scalePCs
        let tonic = clampToRegister(snapToScale(keySemitone(frame.key), scalePCs: scalePCs) + 60,
                                    low: 62, high: 73)

        // (onset, scale steps, duration); chord-relative unless noted. Each note is held to the next.
        func figure(_ onsets: [Int], _ steps: [Int]) -> [(Int, Int, Int)] {
            onsets.enumerated().map { i, o in
                (o, steps[i], i == onsets.count - 1 ? 10 : onsets[i + 1] - o)
            }
        }
        let climb  = figure(sixOnsets, [leap, 0, 1, 2] + top)
        let leapUp = figure(fiveOnsets, [4, 3, 4, 5, 6])
        let turn   = figure(sixOnsets, [leap, 0, 1, 2, 0, 1])
        let answer: [(Int, Int, Int)] = [(6, 5, 2), (8, 4, 2), (10, 0, 3), (13, -2, 2), (15, -3, 10)]
        let archUp:   [(Int, Int, Int)] = [(6, 2, 2), (8, 3, 4), (12, 4, 4)]
        let archDown: [(Int, Int, Int)] = [(0, 5, 2), (2, 4, 2), (4, 2, 2), (6, 0, 10)]
        enum Part { case pickup, climb, leap, turn, answer, archUp, archDown }
        let standard: [Int: Part] = [0: .pickup, 1: .climb, 3: .leap, 5: .turn,
                                     8: .pickup, 9: .climb, 11: .leap, 13: .answer]
        let arch: [Int: Part] = [0: .pickup, 1: .climb, 3: .archUp, 4: .archDown, 5: .archUp,
                                 6: .archDown, 7: .archUp, 8: .archDown]

        var events: [MIDIEvent] = []
        var phrase = 0
        for section in structure.sections where section.label == .A {
            let end = section.endBar * 16
            let first = section.startBar + 2
            guard first < section.endBar else { continue }
            for bar in first..<section.endBar {
                let pos = (bar - first) % 16
                if pos == 0 && bar > first { phrase += 1 }
                guard let part = (phrase % 3 == 2 ? arch : standard)[pos],
                      let entry = tonalMap.entry(atBar: bar) else { continue }
                // The chord root nearest the tonic, from a fourth below to a fifth above
                var offset = (spaceChordRootPC(entry, frame: frame) - tonic % 12 + 12) % 12
                if offset > 7 { offset -= 12 }
                let root = tonic + offset
                let notes: [(Int, Int, Int)]
                var base = root
                switch part {
                case .pickup:   notes = [(0, 0, 18)]
                case .climb:    notes = climb
                case .leap:     notes = leapUp
                case .turn:     notes = turn
                case .answer:   notes = answer;   base = tonic
                case .archUp:   notes = archUp;   base = tonic
                case .archDown: notes = archDown; base = tonic
                }
                var pitches = notes.map { scaleStep(base, by: $0.1, scalePCs: scalePCs) }
                if (pitches.max() ?? 0) > 84 { pitches = pitches.map { $0 - 12 } }
                for (i, n) in notes.enumerated() {
                    let onset = bar * 16 + n.0
                    guard onset < end else { continue }
                    events.append(MIDIEvent(stepIndex: onset, note: UInt8(pitches[i]),
                                            velocity: i == 0 ? 66 : (i == notes.count - 1 ? 58 : 62),
                                            durationSteps: Swift.min(n.2, end - onset)))
                }
            }
            phrase += 1
        }
        return events
    }

    // MARK: - KOS-LD1-015 Magnetic Fields Turn Melody (Kosmic Space, A sections)
    // Magnetic Fields 2 lead: a turn figure in 16th runs on steps 2–7 and 10–15 of the bar, each half
    // bar's run starting one scale step lower, so the line sequences down, then resets. Here a
    // statement is 3 to 5 runs from the start of each 4-bar block of the A section, and the rest of
    // the block is silent. Every run starts from the current chord, so the figure follows the chords;
    // every fourth statement climbs instead of falling. Legato: each note is held to the next, the
    // last of a statement for 6 steps. Register: the chord root nearest a tonic in MIDI 62–73, and a
    // statement that leaves 57–84 moves an octave whole.
    // Homage draws per song, so no two songs share a melody:
    //   turn shape — [+2 +1 -1 -2] or [-1 -2 +3] (the source's, 15% each), or [+1 +1 -2], [+2 -1 -1]
    //                or [-2 +1 +1] (about 23% each), in scale steps, repeated through the run
    //   run length — 3, 4 or 5 runs a statement, a third each
    //   start — on the chord's root 30%, 3rd 35% or 5th 35%
    //   run — 6 notes 60%, or 5 with the last held 40%

    private static func generateMagneticTurnMelody(
        frame: GlobalMusicalFrame, structure: SongStructure, tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG, note: inout String
    ) -> [MIDIEvent] {
        let shapes: [[Int]] = [[2, 1, -1, -2], [-1, -2, 3], [1, 1, -2], [2, -1, -1], [-2, 1, 1]]
        let shape = shapes[rng.weightedPick([0.15, 0.15, 0.24, 0.23, 0.23])]
        let runs = 3 + rng.nextInt(upperBound: 3)
        let startDegree = [0, 2, 4][rng.weightedPick([0.30, 0.35, 0.35])]
        let runLength = rng.nextDouble() < 0.60 ? 6 : 5
        // Every song draws its own melody here, so the log names all four draws.
        let shapeNames = ["arching", "dipping", "climbing", "leaping", "dropping"]
        note = KosmicLeadNotes.words([shapeNames[shapes.firstIndex(of: shape)!],
                                      runs == 3 ? "few runs" : runs == 5 ? "many runs" : nil,
                                      [nil, "from the 3rd", "from the 5th"][startDegree / 2],
                                      runLength == 5 ? "short runs" : nil])
        let scalePCs = frame.scalePCs
        let tonic = clampToRegister(snapToScale(keySemitone(frame.key), scalePCs: scalePCs) + 60,
                                    low: 62, high: 73)

        var events: [MIDIEvent] = []
        var statement = 0
        for section in structure.sections where section.label == .A {
            let end = section.endBar * 16
            for block in stride(from: section.startBar, to: section.endBar, by: 4) {
                let direction = statement % 4 == 3 ? 1 : -1
                statement += 1
                var notes: [(onset: Int, pitch: Int)] = []
                for k in 0..<runs {
                    let bar = block + k / 2
                    guard let entry = tonalMap.entry(atBar: bar) else { continue }
                    // The chord root nearest the tonic, from a fourth below to a fifth above
                    var offset = (spaceChordRootPC(entry, frame: frame) - tonic % 12 + 12) % 12
                    if offset > 7 { offset -= 12 }
                    var pitch = scaleStep(tonic + offset, by: startDegree + direction * k, scalePCs: scalePCs)
                    for i in 0..<runLength {
                        notes.append((bar * 16 + (k % 2 == 0 ? 2 : 10) + i, pitch))
                        pitch = scaleStep(pitch, by: shape[i % shape.count], scalePCs: scalePCs)
                    }
                }
                let shift = (notes.map(\.pitch).max() ?? 0) > 84 ? -12 : (notes.map(\.pitch).min() ?? 60) < 57 ? 12 : 0
                for (i, n) in notes.enumerated() where n.onset < end {
                    let next = i + 1 < notes.count ? notes[i + 1].onset : n.onset + 6
                    events.append(MIDIEvent(stepIndex: n.onset, note: UInt8(n.pitch + shift),
                                            velocity: i == 0 ? 68 : (n.onset % 8 == 2 ? 64 : 58),
                                            durationSteps: Swift.min(next - n.onset, end - n.onset)))
                }
            }
        }
        return events
    }

    // MARK: - KOS-LD2-001 Magnetic Twin (Kosmic Space)
    // One rule, two variants, a half each. It generates no rhythm of its own.
    //   stereo twin — Rhythm's notes outside B sections, on Lead 2's instrument, panned opposite Rhythm, whose
    //                 auto-pan is off (Magnetic Fields 1, whose two sequencers are identical). The
    //                 playback side finds it with SongState.isSpaceStereoTwin.
    //   late octave — Lead 1 an octave up from the first 8-bar point of the song's last third
    //                 (Magnetic Fields 2); a note that would pass MIDI 88 doubles in unison instead.

    /// The stereo twin of a Space Rhythm part. Also used to refresh the twin after a Rhythm regen.
    /// The twin rests in B sections, where Rhythm and Lead 1 share the foreground.
    static func spaceStereoTwin(rhythm: [MIDIEvent], structure: SongStructure) -> [MIDIEvent] {
        rhythm.filter { structure.section(atBar: $0.stepIndex / 16)?.label != .B }.map {
            MIDIEvent(stepIndex: $0.stepIndex, note: $0.note,
                      velocity: UInt8(max(20, Int($0.velocity) - 6)), durationSteps: $0.durationSteps)
        }
    }

    private static func magneticLateOctave(lead1: [MIDIEvent], totalBars: Int) -> [MIDIEvent] {
        let startBar = (totalBars * 2 / 3 + 7) / 8 * 8
        return lead1.filter { $0.stepIndex >= startBar * 16 }.map {
            let up = Int($0.note) + 12
            return MIDIEvent(stepIndex: $0.stepIndex, note: UInt8(up > 88 ? up - 12 : up),
                             velocity: UInt8(max(20, Int($0.velocity) - 10)), durationSteps: $0.durationSteps)
        }
    }

    // MARK: - KOS-LD1-018 Magnetic Call and Hold (Kosmic Space, A sections)
    // Magnetic Fields 4 lead, bars 2-8 and 21-28. An 8-bar phrase of call bars and answer bars:
    //   call   — one note repeated on the off-beat 16ths (steps 2, 4, 5, 7 in the source), then a
    //            3-note tail on steps 10, 12 and 13 (C C C C, Bb G Ab)
    //   answer — two held half notes a step apart, on the next chord (F, Eb)
    //   bars   — call, answer, call, answer a step higher, trill call (the note repeated, then rocking
    //            with the step below on 12-15), answer, cadence (two notes falling onto the chord root,
    //            held into the 8th bar), rest
    // The source's second idea, the octave phase, bounces the chord root between two octaves on a
    // fixed 16th rhythm: 4 bars of one rhythm, 3 of a second and a bar of 16th pairs. Every note is
    // held to the next. The call sits on the current chord, nearest a tonic in MIDI 62-73, and a block
    // that leaves 57-84 moves an octave whole.
    // Homage draws per song:
    //   call note — the chord's root 30%, 3rd 35% or 5th 35%
    //   call rhythm — the source's steps 2, 4, 5, 7 50%, or 0, 2, 3, 6 or 2, 3, 5, 7 25% each
    //   tail — the source's [-1 -2 +1] 40%, or [-1 -1 -1], [+1 -1 -2] or [-2 +1 -1] 20% each
    //   answer — stepping down 60% (source) or up 40%
    //   octave phase — in 60% of songs, every third 8-bar block of the A sections
    // Within song: the octave phase, and in songs without it every second phrase calls from the next
    // chord tone up, so the line rises as the song goes on.

    private static func generateMagneticCallAndHold(
        frame: GlobalMusicalFrame, structure: SongStructure, tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG, note: inout String
    ) -> [MIDIEvent] {
        let callDegree = [0, 2, 4][rng.weightedPick([0.30, 0.35, 0.35])]
        let callRhythm = [[2, 4, 5, 7], [0, 2, 3, 6], [2, 3, 5, 7]][rng.weightedPick([0.50, 0.25, 0.25])]
        let tail = [[-1, -2, 1], [-1, -1, -1], [1, -1, -2], [-2, 1, -1]][rng.weightedPick([0.40, 0.20, 0.20, 0.20])]
        let answerDown = rng.nextDouble() < 0.60
        let octavePhase = rng.nextDouble() < 0.60
        let tailNames: [[Int]: String] = [[-1, -1, -1]: "falling tail", [1, -1, -2]: "turning tail",
                                          [-2, 1, -1]: "leaping tail"]
        note = KosmicLeadNotes.words([[nil, "middle call", "high call"][callDegree / 2],
                                      callRhythm == [0, 2, 3, 6] ? "on the beat" : callRhythm == [2, 3, 5, 7] ? "tight" : nil,
                                      tailNames[tail], answerDown ? nil : "rising answer",
                                      octavePhase ? "octave bounce" : nil])
        let scalePCs = frame.scalePCs
        let tonic = clampToRegister(snapToScale(keySemitone(frame.key), scalePCs: scalePCs) + 60,
                                    low: 62, high: 73)
        func step(_ m: Int, _ by: Int) -> Int { scaleStep(m, by: by, scalePCs: scalePCs) }
        // The chord root nearest the tonic, from a fourth below to a fifth above
        func rootNearTonic(_ entry: TonalGovernanceEntry) -> Int {
            var offset = (spaceChordRootPC(entry, frame: frame) - tonic % 12 + 12) % 12
            if offset > 7 { offset -= 12 }
            return tonic + offset
        }
        func chordToneAtOrBelow(_ m: Int, _ entry: TonalGovernanceEntry) -> Int {
            let root = rootNearTonic(entry)
            let tones = Set([root, step(root, 2), step(root, 4)].map { $0 % 12 })
            return stride(from: m, through: m - 12, by: -1).first { tones.contains($0 % 12) } ?? m
        }

        var events: [MIDIEvent] = []
        var block = 0
        var phrase = 0
        for section in structure.sections where section.label == .A {
            let end = section.endBar * 16
            for blockStart in stride(from: section.startBar, to: section.endBar, by: 8) {
                defer { block += 1 }
                // (onset, pitch, velocity); durations come from the next onset
                var notes: [(onset: Int, pitch: Int, vel: Int)] = []
                var holdLast = 6
                if octavePhase && block % 3 == 2 {
                    let rhythms: [(low: [Int], high: [Int])] = [
                        ([0, 7], [2, 4, 6, 9, 11, 12, 13, 14]),
                        ([0, 2, 9], [4, 5, 7, 11, 13, 15]),
                        ([0, 1, 2, 3, 8, 9, 10, 11], [4, 6, 12, 14]),
                    ]
                    for k in 0..<8 {
                        let bar = blockStart + k
                        guard let entry = tonalMap.entry(atBar: bar) else { continue }
                        var low = rootNearTonic(entry)
                        while low > 71 { low -= 12 }
                        while low < 60 { low += 12 }
                        let r = rhythms[k < 4 ? 0 : k < 7 ? 1 : 2]
                        for s in (r.low + r.high).sorted() {
                            let isLow = r.low.contains(s)
                            notes.append((bar * 16 + s, isLow ? low : low + 12, isLow ? 58 : 62))
                        }
                    }
                    holdLast = 2
                } else {
                    let lift = !octavePhase && phrase % 2 == 1 ? 2 : 0
                    phrase += 1
                    var lastCall = tonic
                    for k in 0..<7 {
                        let bar = blockStart + k
                        guard let entry = tonalMap.entry(atBar: bar) else { continue }
                        let call = step(rootNearTonic(entry), callDegree + lift)
                        switch k {
                        case 0, 2:
                            lastCall = call
                            for (i, s) in callRhythm.enumerated() { notes.append((bar * 16 + s, call, i == 0 ? 68 : 62)) }
                            var p = call
                            for (s, by) in zip([10, 12, 13], tail) {
                                p = step(p, by)
                                notes.append((bar * 16 + s, p, 60))
                            }
                        case 4:
                            lastCall = call
                            for (i, s) in [2, 4, 5, 7, 9, 11].enumerated() { notes.append((bar * 16 + s, call, i == 0 ? 68 : 62)) }
                            for s in 12...15 { notes.append((bar * 16 + s, s % 2 == 0 ? step(call, -1) : call, 60)) }
                        case 6:
                            // The chord root in the octave below the last call
                            var land = rootNearTonic(entry)
                            while land >= lastCall { land -= 12 }
                            while land < lastCall - 12 { land += 12 }
                            notes.append((bar * 16 + 3, step(land, 2), 62))
                            notes.append((bar * 16 + 4, step(land, 1), 64))
                            notes.append((bar * 16 + 8, land, 66))
                            holdLast = 24
                        default:
                            // Answer: two held notes a step apart, below the call, on this bar's chord;
                            // the second answer of the phrase sits a step higher, as the source's does
                            let first = chordToneAtOrBelow(step(lastCall, k == 3 ? -3 : -4), entry)
                            notes.append((bar * 16, first, 64))
                            notes.append((bar * 16 + 8, step(first, answerDown ? -1 : 1), 60))
                        }
                    }
                }
                guard !notes.isEmpty else { continue }
                let hi = notes.map(\.pitch).max()!, lo = notes.map(\.pitch).min()!
                let shift = hi > 84 ? -12 : lo < 57 ? 12 : 0
                for (i, n) in notes.enumerated() where n.onset < end {
                    let next = i + 1 < notes.count ? notes[i + 1].onset : n.onset + holdLast
                    events.append(MIDIEvent(stepIndex: n.onset, note: UInt8(n.pitch + shift),
                                            velocity: UInt8(n.vel),
                                            durationSteps: Swift.min(next - n.onset, end - n.onset)))
                }
            }
        }
        return events
    }

    // MARK: - KOS-LD1-014 Oxygene See-Saw Riff (Kosmic Space, B sections)
    // Oxygene 4 riff, both transcriptions. Six notes rocking between an anchor (the current chord
    // root) and a pivot a fixed interval above it: anchor on steps 0, 2, 5, pivot on 1, 4, 6, step 3
    // silent; notes 1 step long, the last held through the rest of the bar (about 9 steps). It plays
    // every bar of its B sections but the last 2 of every 8, and follows the chord. The pivot is a
    // scale step count, so it stays in the scale (the source's fifth becomes a minor sixth on the
    // next chord in just this way). The pair is folded by octaves so its top note lands in MIDI
    // 73–84. It used to be centred in 72–84, which put an octave riff's top note as high as 90 and
    // played 40 bars without a break (Zack, 2026-11-03, Fluxion III).
    // Homage draws per song:
    //   interval — fourth 30%, sixth 30%, octave 20%, fifth 20% (source)
    //   grouping — 3+3 40% (source), 2+2+2 on steps 0, 1, 3, 4, 6, 7 30%, 3+2 on steps 0, 1, 2, 4, 5 30%
    //   position — first half of the bar 60% (source) or second half from step 8 40%
    //   anchor — below the pivot 60% (source) or above it, rocking downwards 40%
    // Within song: in 1 bar of 8 the anchor moves up to the chord's 4th (measured in 5 of 45 bars).
    // In the last B section every second statement may drop to a single 3-note group (50%),
    // thinning the riff towards the outro.

    // KOS-LD1-019 Equinoxe Thirds Riff (equinoxeThirds) is this riff as Equinoxe plays it: the pivot a
    // third away (a minor or major third, whichever the scale gives, [-3 +3 -3]) and the 3+3+2 rhythm
    // across the whole bar on steps 0, 2, 5, 8, 10 and 13, each note held to the next. In Phrygian
    // songs the pivot lands on bII over the tonic chord in the last bar of every 4. The same draws are
    // taken, so the anchor's side and the thinning still vary per song.

    private static func generateOxygeneSeeSawRiff(
        frame: GlobalMusicalFrame, structure: SongStructure, tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG, equinoxeThirds: Bool = false, note: inout String
    ) -> [MIDIEvent] {
        let intervals: [(steps: Int, name: String)] = [(3, "fourth"), (5, "sixth"), (7, "octave"), (4, "fifth")]
        var interval = intervals[rng.weightedPick([0.30, 0.30, 0.20, 0.20])]
        let groupings: [(steps: [Int], name: String)] = [([0, 1, 2, 4, 5, 6], "3+3"),
                                                         ([0, 1, 3, 4, 6, 7], "2+2+2"),
                                                         ([0, 1, 2, 4, 5],    "3+2")]
        var grouping = groupings[rng.weightedPick([0.40, 0.30, 0.30])]
        var offset = rng.nextDouble() < 0.60 ? 0 : 8
        let anchorAbove = rng.nextDouble() >= 0.60
        if equinoxeThirds {
            interval = (2, "third")
            grouping = ([0, 2, 5, 8, 10, 13], "3+3+2")
            offset = 0
        }
        // The source is a fifth, 3+3, first half, anchor below; KOS-LD1-019 keeps only the anchor draw.
        let intervalWords = ["fourth": "narrow leap", "sixth": "wide leap", "octave": "widest leap"]
        let groupWords = ["2+2+2": "even groups", "3+2": "uneven groups"]
        note = KosmicLeadNotes.words((equinoxeThirds ? [] : [intervalWords[interval.name],
                                                             groupWords[grouping.name],
                                                             offset == 8 ? "starts late" : nil])
                                     + [anchorAbove ? "rocks down" : nil])

        let scalePCs = frame.scalePCs
        let lastB = structure.sections.last(where: { $0.label == .B })
        var events: [MIDIEvent] = []
        for section in structure.sections where section.label == .B {
            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barInSection = bar - section.startBar
                var anchor = spaceChordRootPC(entry, frame: frame) + 72
                if barInSection % 8 == 5 { anchor = scaleStep(anchor, by: 3, scalePCs: scalePCs) }
                var pivot = scaleStep(anchor, by: anchorAbove ? -interval.steps : interval.steps,
                                      scalePCs: scalePCs)
                if equinoxeThirds, frame.mode == .Phrygian, barInSection % 4 == 3,
                   spaceChordRootPC(entry, frame: frame) == keySemitone(frame.key) % 12 {
                    pivot = anchor + 1
                }
                while Swift.max(anchor, pivot) > 84 { anchor -= 12; pivot -= 12 }
                while Swift.max(anchor, pivot) < 73 { anchor += 12; pivot += 12 }
                var steps = grouping.steps
                if let lastB, section.startBar == lastB.startBar, barInSection % 2 == 1,
                   rng.nextDouble() < 0.50 {
                    steps = Array(steps.prefix(3))
                }
                // The riff breathes in the last 2 bars of every 8, before its chord loop restarts.
                // After the draw above, so Lead 1's later draws are unchanged.
                if barInSection % 8 >= 6 { continue }
                for (i, step) in steps.enumerated() {
                    let isLast = i == steps.count - 1
                    let pitch  = i % 2 == 0 ? anchor : pivot
                    // The thirds riff is legato, each note held to the next
                    let dur = isLast ? 16 - offset - step : equinoxeThirds ? steps[i + 1] - step : 1
                    events.append(MIDIEvent(stepIndex: bar * 16 + offset + step, note: UInt8(pitch),
                                            velocity: i % 2 == 0 ? 64 : 58,
                                            durationSteps: dur))
                }
            }
        }
        return events
    }

    // MARK: - Rule selection

    private static func pickLeadRule(rng: inout SeededRNG) -> String {
        // Lead 1 rule pool. The transcription hooks Pulstar theme, Beach Scene sigh and Blade Runner
        // theme hold 001, 005 and 007 and take 43% between them.
        let rules:   [String] = ["KOS-LD1-001", "KOS-LD1-002", "KOS-LD1-003", "KOS-LD1-004", "KOS-LD1-005", "KOS-LD1-006", "KOS-LD1-007", "KOS-LD1-008", "KOS-LD1-009"]
        let weights: [Double] = [0.15,           0.09,           0.09,           0.07,           0.14,           0.15,           0.14,           0.09,           0.08]
        return rules[rng.weightedPick(weights)]
    }

    private static func pickLeadRule2(rng: inout SeededRNG) -> String {
        // Base Kosmic Lead 2 answers Lead 1 in its gaps (GapAnswerEngine).
        // Kosmic Space calls this, ignores the result and draws again: it must stay one draw.
        let rules:   [String] = ["KOS-LD2-002", "KOS-LD2-003", "KOS-LD2-004"]
        let weights: [Double] = [0.35,          0.35,          0.30]
        return rules[rng.weightedPick(weights)]
    }

    /// Pick a dense lead rule for B-section escalation when Lead 1 is a sparse ambient rule.
    /// Only 004 (Echo Melody) and 006 (JMJ Phrase Loop) qualify — both produce clearly
    /// audible melodic content that contrasts with a sparse A section.
    private static func pickDenseLeadRule(rng: inout SeededRNG) -> String {
        return rng.nextDouble() < 0.60 ? "KOS-LD1-006" : "KOS-LD1-004"
    }

    /// Pick a lead rule that is different from `current`. Used by bridge melody selection.
    private static func pickLeadRuleDifferentFrom(_ current: String,
                                                   excluding: [String] = [],
                                                   rng: inout SeededRNG) -> String {
        // The hook rules 001, 005 and 007 are whole-song rules, so a bridge melody never uses them.
        let allRules = ["KOS-LD1-002", "KOS-LD1-003", "KOS-LD1-004", "KOS-LD1-006", "KOS-LD1-008", "KOS-LD1-009"]
        let excluded = Set(excluding + [current])
        let candidates = allRules.filter { !excluded.contains($0) }
        guard !candidates.isEmpty else { return current }
        return candidates[rng.nextInt(upperBound: candidates.count)]
    }

    /// Pick a B-section rule for Technique D. Restricted to per-bar-compatible rules only.
    /// Only 002, 003 and 004 qualify: 001, 005 and 007 are hooks, and 006 bypasses emitLeadBar.
    private static func pickBSectionRule(excluding current: String,
                                          isKosmicDrift: Bool = false,
                                          rng: inout SeededRNG) -> String {
        let perBarRules: [String] = ["KOS-LD1-002", "KOS-LD1-003", "KOS-LD1-004"]
        let candidates = perBarRules.filter { $0 != current }
        guard !candidates.isEmpty else { return current }
        return candidates[rng.nextInt(upperBound: candidates.count)]
    }

    /// X-Files whistle on a melody bridge, after the 25% roll has passed. It appears symmetrically:
    /// a bookend (first and last bar) or a middle pair (about a third and two thirds in). The melody is
    /// silenced around each phrase and the whistle events are added last, so the silence filters never
    /// clip a prior whistle phrase.
    private static func addXFilesWhistles(to melodyEvents: inout [MIDIEvent], section: SongSection,
                                          frame: GlobalMusicalFrame, tonalMap: TonalGovernanceMap,
                                          rng: inout SeededRNG, xFilesBars: inout [Int]) {
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
        // Collect whistle events separately so per-bar silence filters only affect
        // the generated melody and never clip notes from a prior whistle phrase.
        var whistleEvents: [MIDIEvent] = []
        for xBar in xBars {
            let barEvs = xFilesWhistleBar(bar: xBar, frame: frame, tonalMap: tonalMap, rng: &rng)
            guard !barEvs.isEmpty else { continue }
            xFilesBars.append(xBar)
            let xStart = xBar * 16
            // Whistle: pickup at xStart+12, last note ends at xStart+40 (half note at step 32).
            // Silence: 6 beats (24 steps) before pickup; 2 beats (8 steps) after last held note.
            let prePadStart = xBar > section.startBar     ? xStart - 24 : xStart
            let postPadEnd  = xBar < section.endBar - 1   ? xStart + 48 : xStart + 40
            melodyEvents = melodyEvents.filter {
                $0.stepIndex < prePadStart || $0.stepIndex >= postPadEnd
            }
            whistleEvents += barEvs
        }
        melodyEvents += whistleEvents
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
        // Variant is biased toward the character of the lead rule so the bridge feels like it
        // belongs to the song (60% rule-matched, 40% any variant for variety).
        //   bridgeRule 006 (JMJ)            → variant 1 syncopated JMJ
        //   bridgeRule 004 (Echo Melody)    → variant 3 driving 8th sequencer
        //   bridgeRule 002 (Floating Tones) → variant 0 quarter-note pulse
        //   any other rule                  → variant 2 3-note motif with breath
        let preferredVariant: Int
        switch bridgeRule {
        case "KOS-LD1-006": preferredVariant = 1
        case "KOS-LD1-004": preferredVariant = 3
        case "KOS-LD1-002": preferredVariant = 0
        default:             preferredVariant = 2   // restrained
        }
        let rhythmVariant = rng.nextDouble() < 0.60
            ? preferredVariant
            : rng.nextInt(upperBound: 4)
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
        case "KOS-LD1-003": return pentatonicDriftBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, frame: frame, entry: entry, rng: &rng)
        case "KOS-LD1-004": return echoMelodyBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        default:
            // Only KOS-LD1-002 Floating Tones lands here. Any other ID is a section-level rule
            // routed to the per-bar player by mistake (how the B-section bug fixed in 3b8f778 hid),
            // so debug builds and tests stop rather than quietly playing it as Floating Tones.
            assert(rule == "KOS-LD1-002", "Kosmic Lead 1 rule \(rule) has no per-bar case")
            return floatingTonesBar(barStart: barStart, bar: bar, scaleNotes: scaleNotes, rng: &rng)
        }
    }

    // MARK: - KOS-LD1-002: Floating Tones
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

    // MARK: - KOS-LD1-003: Pentatonic Drift
    // Slow 2-note pentatonic figure every 4 bars, following a ping-pong arc through the pentatonic
    // scale: ascends from lowest to highest position over several phrases, then descends back down.
    // Key-derived offset staggers the starting point across songs.
    // Attack at the "and" of beat 1 to avoid colliding with rules that fire on step 0.

    private static func pentatonicDriftBar(
        barStart: Int, bar: Int, scaleNotes: [Int],
        frame: GlobalMusicalFrame, entry: TonalGovernanceEntry,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let penta = pentatonicNotes(entry: entry, frame: frame, low: 60, high: 84)
        guard penta.count >= 3 else { return [] }

        // Fire a 2-note figure every 4 bars
        guard bar % 4 == 0 else { return [] }

        // Ping-pong through pentatonic positions for a directional arc that bounces at the extremes.
        // steps = number of upward moves in one half-cycle (e.g. 4 for a 5-note penta).
        // Key offset ensures different songs start at different arc positions.
        let steps  = penta.count - 1
        let period = steps * 2
        let keyOff = frame.keySemitoneValue % max(1, period)
        let pos    = (bar / 4 + keyOff) % period
        // pos ≤ steps → ascending half; pos > steps → descending half
        let idx1      = pos <= steps ? pos : period - pos   // bounces in [0, steps]
        let ascending = pos < steps

        // Second note: one step further along the current arc direction
        let idx2: Int
        if ascending {
            idx2 = min(idx1 + 1, steps)
        } else {
            idx2 = max(idx1 - 1, 0)
        }

        let note1 = penta[idx1]
        let note2 = penta[idx2]
        let vel1  = UInt8(50 + rng.nextInt(upperBound: 18))   // 50–67
        let vel2  = UInt8(45 + rng.nextInt(upperBound: 18))   // 45–62, slightly softer

        // First note on the "and" of beat 1 (step 2); second note on beat 3 (step 10)
        var evs: [MIDIEvent] = [
            MIDIEvent(stepIndex: barStart + 2,  note: UInt8(note1), velocity: vel1, durationSteps: 10)
        ]
        // Skip second note only at arc boundary turns where both pitches are identical
        if note2 != note1 {
            evs.append(MIDIEvent(stepIndex: barStart + 10, note: UInt8(note2), velocity: vel2, durationSteps: 10))
        }
        return evs
    }

    // MARK: - KOS-LD1-004: Echo Melody
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
            // Transpose by exact diatonic 3rd: shift ±2 scale positions (one 3rd interval in any mode)
            let origIdx = scaleNotes.firstIndex(of: baseNote) ?? (scaleNotes.count / 2)
            let shift = rng.nextDouble() < 0.5 ? 2 : -2
            let transposedNote = scaleNotes[Swift.max(0, Swift.min(scaleNotes.count - 1, origIdx + shift))]
            let vel = UInt8(45 + rng.nextInt(upperBound: 18))
            return [MIDIEvent(stepIndex: barStart, note: UInt8(transposedNote), velocity: vel, durationSteps: 14)]
        }
        // Silence: bars 6–7
        return []
    }

    // MARK: - KOS-LD2-005: Space Echo Reply
    // Kosmic Space Lead 2. The Echo melody cycle two bars later, so its phrase falls where Echo
    // melody rests: a held note in bars 3 and 4 of each 8-bar cycle, started a diatonic third above
    // the register's lowest scale note, then the same two notes a third lower in bars 7 and 8.

    private static func spaceEchoReplyBar(
        barStart: Int, bar: Int, scaleNotes: [Int], rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard !scaleNotes.isEmpty else { return [] }
        let cycle = (bar + 6) % 8
        // Phrase: bars 0–1 of the shifted cycle
        if cycle < 2 {
            let phraseNote = scaleNotes[Swift.min(cycle + 2, scaleNotes.count - 1)]
            let vel = UInt8(55 + rng.nextInt(upperBound: 18))
            return [MIDIEvent(stepIndex: barStart, note: UInt8(phraseNote), velocity: vel, durationSteps: 14)]
        }
        if cycle < 4 { return [] }
        // Echo: always a diatonic third below the phrase
        if cycle < 6 {
            let echoNote = scaleNotes[Swift.min(cycle - 4, scaleNotes.count - 1)]
            let vel = UInt8(45 + rng.nextInt(upperBound: 18))
            return [MIDIEvent(stepIndex: barStart, note: UInt8(echoNote), velocity: vel, durationSteps: 14)]
        }
        return []
    }

    // MARK: - KOS-LD1-006: JMJ Phrase Loop

    private static func generateJMJPhraseLoop(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, bRule: String = "KOS-LD1-006",
        sparseMode: Bool = false, rng: inout SeededRNG,
        xFilesBars: inout [Int],
        suppressXFiles: Bool = false,
        readonlyXFilesBars: [Int] = []
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Bridge A-1 and A-2: same bridge lead as regular rules
        // (When suppressXFiles=true this is Lead 2 — skip bridgeAlt since caller handles it via generateBridgeAltLead2)
        events += generateDrumBridgeLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)
        if !suppressXFiles {
            events += generateBridgeAltLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)
        }

        // Bridge melody rule: pick once, different from JMJ
        let jmjBridgeMelodyRule = pickLeadRuleDifferentFrom("KOS-LD1-006", rng: &rng)

        for section in structure.sections {
            guard section.label != .intro && section.label != .outro else { continue }
            // Drum bridges handled above
            guard section.label != .bridge && section.label != .bridgeAlt else { continue }
            // Melody bridge: same path as generateLead1
            if section.label == .bridgeMelody {
                var melodyEvents = generateBridgeMelodySection(section: section, frame: frame,
                                                               tonalMap: tonalMap, bridgeRule: jmjBridgeMelodyRule,
                                                               rng: &rng)
                if suppressXFiles {
                    // Lead 2: no whistle; just silence around Lead 1's X-Files bars (2 beats before, 2 after held note)
                    for xb in readonlyXFilesBars {
                        let xStart = xb * 16
                        let prePadStart = xStart - 8    // 2 beats before pickup (xStart+12)
                        let postPadEnd  = xStart + 48   // whistle end (xStart+40) + 2 beats (8)
                        melodyEvents = melodyEvents.filter {
                            $0.stepIndex < prePadStart || $0.stepIndex >= postPadEnd
                        }
                    }
                } else if rng.nextDouble() < 0.25 {
                    addXFilesWhistles(to: &melodyEvents, section: section, frame: frame, tonalMap: tonalMap,
                                           rng: &rng, xFilesBars: &xFilesBars)
                }
                events += melodyEvents
                continue
            }
            events += jmjPhraseSection(section: section, frame: frame, tonalMap: tonalMap,
                                       sparseMode: sparseMode, rng: &rng)
        }
        return events
    }

    /// One A or B section of KOS-LD1-006 JMJ phrase loop: a phrase built for the section, played
    /// 8 bars on and 8 bars off with two one-note variations. The JMJ rule calls it for every
    /// section; a sparse A rule (KOS-LD1-002, KOS-LD1-003) calls it for its B sections.
    private static func jmjPhraseSection(
        section: SongSection, frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap, sparseMode: Bool,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard let firstEntry = tonalMap.entry(atBar: section.startBar) else { return [] }

        let scaleNotes = jmjPhraseScaleNotes(entry: firstEntry, frame: frame)
        guard scaleNotes.count >= 4 else { return [] }

        // Build the phrase once per section: 4–6 notes with quarter/8th-note durations.
        // Arch shape: rises to peak at ~65% through the phrase (slightly later than bridge's 60%),
        // giving a sense of reach before settling. Final note snapped to a chord tone.
        let phraseLen  = 4 + rng.nextInt(upperBound: 3)
        var phraseNotes: [Int] = []
        var phraseDurs:  [Int] = []
        var stepAccum = 0
        let archPeak   = max(1, phraseLen * 2 / 3)
        let archAscend = rng.nextDouble() < 0.55
        let snLow  = max(0, scaleNotes.count / 5)
        let snHigh = min(scaleNotes.count - 1, scaleNotes.count * 4 / 5)
        let snSpan = max(1, snHigh - snLow)
        let chordTonePCs = Set(firstEntry.chordWindow.chordTones.map { $0 % 12 })
        for i in 0..<phraseLen {
            guard stepAccum < 16 else { break }
            let archFrac: Double = i < archPeak
                ? Double(i) / Double(archPeak)
                : Double(phraseLen - i) / Double(max(1, phraseLen - archPeak))
            let base = archAscend
                ? snLow  + Int(Double(snSpan) * archFrac)
                : snHigh - Int(Double(snSpan) * archFrac)
            let jitter = rng.nextInt(upperBound: 3) - 1  // ±1 step for natural variation
            let noteIdx = max(0, min(scaleNotes.count - 1, base + jitter))
            phraseNotes.append(scaleNotes[noteIdx])
            let dur = 4 + rng.nextInt(upperBound: 5)  // 4–8 steps (1–2 beats)
            phraseDurs.append(dur)
            stepAccum += dur
        }
        guard !phraseNotes.isEmpty else { return [] }
        // Stable landing: snap last phrase note to nearest chord tone in the scale
        let chordScaleNotes = scaleNotes.filter { chordTonePCs.contains($0 % 12) }
        if !chordScaleNotes.isEmpty {
            let lastNote = phraseNotes[phraseNotes.count - 1]
            let nearest = chordScaleNotes.min(by: { abs($0 - lastNote) < abs($1 - lastNote) }) ?? chordScaleNotes[0]
            phraseNotes[phraseNotes.count - 1] = nearest
        }

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

        // 8-bar-on / 8-bar-rest breathing cycle — prevents relentless unbroken output.
        // Per-section RNG offset (0–3) staggers the rest window so it doesn't always
        // align with the section boundary.
        let restOffset = sparseMode ? 0 : rng.nextInt(upperBound: 4)

        for bar in section.startBar..<section.endBar {
            let posInSection = bar - section.startBar
            // Sparse mode (Lead 2 doubling JMJ): skip first bar of section; 40% gate elsewhere
            if sparseMode && posInSection == 0 { continue }
            if sparseMode && rng.nextDouble() > 0.40 { continue }
            // Normal mode: 8 bars active, 8 bars silence in each 16-bar window
            if !sparseMode && (posInSection + restOffset) % 16 >= 8 { continue }

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
        return events
    }

    // MARK: - KOS-LD1-008: Caligari Solo
    // Slow, lyrical chord-tracking lead inspired by Caligari Drop bars 10–18.
    // "Freely soft" character: 1–2 chord-tone notes per bar, held 2–3 beats, slight rhythmic offset.
    // Plays in 2–3 windows of 8 bars with ≥6-bar gaps between repeats.

    private static func generateCaligariSolo(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG,
        xFilesBars: inout [Int]
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        events += generateDrumBridgeLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)
        events += generateBridgeAltLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)

        let windowCount = 2 + rng.nextInt(upperBound: 2)   // 2 or 3 windows
        let windows = pickSoloWindows(structure: structure, soloLength: 8, windowCount: windowCount,
                                      minGap: 6, rng: &rng)

        for window in windows {
            var lastNote: Int? = nil
            for bar in window {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                let allNotes   = scaleNotesInRegister(entry: entry, frame: frame, low: 67, high: 82)
                guard !allNotes.isEmpty else { continue }
                let chordTonePCs = Set(entry.chordWindow.chordTones.map { $0 % 12 })
                let chordNotes   = allNotes.filter { chordTonePCs.contains($0 % 12) }
                // A minor chord whose third lies outside the mode (Gb minor in Ab Aeolian) leaves only
                // two chord tones in the register, and the line shuttled between them. With fewer
                // than four, the whole scale is the pool and chord tones are weighted up.
                let pool = chordNotes.count >= 4 ? chordNotes : allNotes
                func pickNext() -> Int {
                    let cands = pool.filter { $0 != lastNote }
                    let list = cands.isEmpty ? pool : cands
                    var weights: [Double] = list.map { n in
                        var w = 1.0
                        if let l = lastNote {
                            let d = abs(n - l)
                            w = d <= 4 ? 3.0 : (d <= 7 ? 2.0 : (d <= 12 ? 1.0 : 0.2))
                        }
                        return chordTonePCs.contains(n % 12) ? w * 2.0 : w
                    }
                    let total = weights.reduce(0, +)
                    weights = weights.map { $0 / total }
                    var r = rng.nextDouble()
                    for (i, w) in weights.enumerated() {
                        if r < w { return list[i] }
                        r -= w
                    }
                    return list[list.count - 1]
                }

                // First note: offset 0, 1, or 1.5 beats (0, 4, or 6 steps)
                let offsets = [0, 4, 6]
                let offset1   = offsets[rng.nextInt(upperBound: 3)]
                let dur1      = 8 + rng.nextInt(upperBound: 7)     // 8–14 steps (2–3.5 beats)
                let playedDur1 = min(dur1, 16 - offset1)           // actual duration after bar clamp
                let vel1      = UInt8(50 + rng.nextInt(upperBound: 19))
                let note1     = pickNext()
                lastNote = note1
                events.append(MIDIEvent(stepIndex: barStart + offset1, note: UInt8(note1),
                                        velocity: vel1, durationSteps: playedDur1))

                // Second note (55% chance): starts immediately after the first ends
                if rng.nextDouble() < 0.55 {
                    let offset2 = offset1 + playedDur1   // use actual played duration, not requested
                    guard offset2 < 15 else { continue }
                    let note2 = pickNext()
                    lastNote = note2
                    let vel2  = UInt8(48 + rng.nextInt(upperBound: 17))
                    let dur2  = 6 + rng.nextInt(upperBound: 7)    // 6–12 steps
                    events.append(MIDIEvent(stepIndex: barStart + offset2, note: UInt8(note2),
                                            velocity: vel2, durationSteps: min(dur2, 16 - offset2)))
                }
            }
        }
        return events
    }

    // MARK: - KOS-LD1-009: Dark Sun Solo
    // Spacious 70s analog synth lead inspired by Dark Sun bars 21–46.
    // One sustained note per bar, stepwise ascent then descent through scale (MIDI 60–76).
    // Occasional chromatic trill ornament (4 alternating semitone steps at very low velocity).
    // Plays in 2–3 windows of 10 bars with ≥8-bar gaps between repeats.

    private static func generateDarkSunSolo(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG,
        xFilesBars: inout [Int]
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        events += generateDrumBridgeLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)
        events += generateBridgeAltLead(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng, xFilesBars: &xFilesBars)

        let windowCount = 2 + rng.nextInt(upperBound: 2)   // 2 or 3 windows
        var windows = pickSoloWindows(structure: structure, soloLength: 10, windowCount: windowCount,
                                      minGap: 8, rng: &rng)

        // The solo always comes back at least once. When only one full window fits, a shortened
        // five-bar return is added that clears the first by four bars; it starts from its own
        // random direction and start note, so it is a variation, not a copy.
        if windows.count == 1 {
            let first = windows[0]
            var body = Set<Int>()
            for section in structure.sections {
                guard section.label != .intro && section.label != .outro else { continue }
                guard !section.label.isBridge && section.label != .bridgeMelody else { continue }
                for b in section.startBar..<section.endBar { body.insert(b) }
            }
            let starts = body.sorted().filter { start in
                (start..<(start + 5)).allSatisfy { body.contains($0) }
                    && (start >= first.upperBound + 4 || start + 5 + 4 <= first.lowerBound)
            }
            if !starts.isEmpty {
                let start = starts[rng.nextInt(upperBound: starts.count)]
                windows.append(start..<(start + 5))
                windows.sort { $0.lowerBound < $1.lowerBound }
            }
        }

        for window in windows {
            guard !window.isEmpty, let firstEntry = tonalMap.entry(atBar: window.lowerBound) else { continue }
            let refScale = scaleNotesInRegister(entry: firstEntry, frame: frame, low: 60, high: 76)
            guard refScale.count >= 4 else { continue }

            let winLen    = window.upperBound - window.lowerBound
            let ascending = rng.nextDouble() < 0.60          // 60% ascend first
            let peakBar   = winLen / 2 + rng.nextInt(upperBound: Swift.max(1, winLen / 4))
            // Ascending: start in lower third and climb; descending: start in upper third and fall.
            var scaleIdx: Int
            if ascending {
                scaleIdx = rng.nextInt(upperBound: Swift.max(1, refScale.count / 3))
            } else {
                let topThirdBase = refScale.count * 2 / 3
                scaleIdx = topThirdBase + rng.nextInt(upperBound: Swift.max(1, refScale.count / 3))
                scaleIdx = Swift.min(scaleIdx, refScale.count - 1)
            }

            for (i, bar) in window.enumerated() {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                let scale = scaleNotesInRegister(entry: entry, frame: frame, low: 60, high: 76)
                guard !scale.isEmpty else { continue }

                // Advance scale position: ascend to peak, then descend
                if i > 0 {
                    if ascending {
                        scaleIdx = i < peakBar
                            ? Swift.min(scaleIdx + 1, scale.count - 1)
                            : Swift.max(scaleIdx - 1, 0)
                    } else {
                        scaleIdx = i < peakBar
                            ? Swift.max(scaleIdx - 1, 0)
                            : Swift.min(scaleIdx + 1, scale.count - 1)
                    }
                }
                let note = scale[Swift.min(scaleIdx, scale.count - 1)]

                // Diatonic trill ornament (20%, not on first bar)
                var mainOffset = 0
                if i > 0 && rng.nextDouble() < 0.20 {
                    let ornStart  = 2 + rng.nextInt(upperBound: 3)  // start at step 2–4
                    // Snap the upper trill note to the nearest scale tone above the main note
                    let keyST2    = keySemitone(frame.key)
                    let scalePCs2 = Set(entry.sectionMode.intervals.map { (keyST2 + $0) % 12 })
                    let snapPC    = snapToScale((note + 1) % 12, scalePCs: scalePCs2)
                    let baseOct   = (note / 12) * 12
                    var upper     = baseOct + snapPC
                    if upper <= note { upper += 12 }  // ensure upper > note
                    for j in 0..<4 {
                        let ornStep = ornStart + j
                        guard ornStep < 14 else { break }
                        let ornNote = (j % 2 == 0) ? note : upper
                        let ornVel  = UInt8(18 + rng.nextInt(upperBound: 14))
                        events.append(MIDIEvent(stepIndex: barStart + ornStep, note: UInt8(ornNote),
                                                velocity: ornVel, durationSteps: 1))
                    }
                    mainOffset = ornStart + 4
                }

                // Main held note: nearly fills the bar
                let mainStart = Swift.max(0, mainOffset)
                let dur  = 14 - mainOffset + rng.nextInt(upperBound: 3)  // 14–16 steps
                let vel  = UInt8(52 + rng.nextInt(upperBound: 20))
                events.append(MIDIEvent(stepIndex: barStart + mainStart, note: UInt8(note),
                                        velocity: vel, durationSteps: Swift.min(dur, 16 - mainStart)))
            }
        }
        return events
    }

    // MARK: - Helpers

    /// Pitch class of the current chord root (0–11).
    private static func chordRootPC(frame: GlobalMusicalFrame, entry: TonalGovernanceEntry) -> Int {
        (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
    }

    /// Scale notes for KOS-LD1-006 phrase loop: MIDI 65–84 (upper-mid solo register)
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
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG,
        xFilesBars: [Int] = []
    ) -> [MIDIEvent] {
        // Silence Lead 2 on xFiles bar + 2 bars after (whistle spans 2.25 bars, plus 2-beat padding)
        var silencedBars: Set<Int> = []
        for xb in xFilesBars { silencedBars.insert(xb); silencedBars.insert(xb + 1); silencedBars.insert(xb + 2) }
        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard section.label == .bridgeAlt else { continue }
            for bar in section.startBar..<section.endBar {
                let bridgeBar = bar - section.startBar
                guard bridgeBar % 2 == 1 else { continue }   // odd bars = response bars
                guard !silencedBars.contains(bar) else { continue }   // silent during/after X-Files whistle
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let rootPC = chordRootPC(frame: frame, entry: entry)
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)
                let fifth  = 7

                func place(_ pc: Int) -> Int { clampToRegister(64 + rootPC + pc, low: 64, high: 76) }

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
            let rootPC = chordRootPC(frame: frame, entry: entry)
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
                let note = clampToRegister(72 + rootPC + 7, low: 72, high: 84)
                let vel = UInt8(58 + rng.nextInt(upperBound: 12))
                let durationSteps = section.lengthBars * 16
                events.append(MIDIEvent(stepIndex: section.startBar * 16,
                                        note: UInt8(note), velocity: vel, durationSteps: durationSteps))
            }
        }
        return events
    }

    // MARK: - X-Files whistle — single bar helper
    // Emits the 6-note whistle phrase verbatim from the reference MIDI.
    // In A minor (root = A3 = MIDI 57): A3–E4–D4–E4–G4–E4(half).
    // Phrase starts at beat 4 of `bar` (step +12) and spills ~2 bars forward.
    // Transposed to any key by shifting root; intervals never change.
    // Used by drum bridge (every bar) and melody bridge / Ambient (once per block).

    static func xFilesWhistleBar(
        bar: Int, frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard let entry = tonalMap.entry(atBar: bar) else { return [] }
        let rootPC = chordRootPC(frame: frame, entry: entry)

        // Root at MIDI 48 + rootPC — places A at A3 (MIDI 57), matching reference MIDI.
        // Keys C–E (rootPC 0–4) land at C3–E3 which sounds ~an octave too low; push them up.
        // Ascending intervals: root, +7, +5, +7, +10, +7.
        var root = 48 + rootPC   // e.g. A3=57, Bb3=58, F#3=54
        if root < 53 { root += 12 }  // C3–E3 → C4–E4, keeps all keys in the F3–E4 range

        // Step offsets match reference MIDI exactly: pickup on beat 4 (+12),
        // then beats 1–4 of bar+1 (+16–+28), then held half note at bar+2 beat 1 (+32).
        let xPhrase: [(Int, Int, Int)] = [
            (root,      12, 4),   // root  (A3) — beat 4 pickup
            (root +  7, 16, 4),   // 5th   (E4) — bar+1 beat 1
            (root +  5, 20, 4),   // 4th   (D4) — beat 2
            (root +  7, 24, 4),   // 5th   (E4) — beat 3
            (root + 10, 28, 4),   // b7    (G4) — beat 4
            (root +  7, 32, 8),   // 5th   (E4) — bar+2 beat 1, half note
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
                let rootPC = chordRootPC(frame: frame, entry: entry)
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)
                let fifth  = 7
                let fourth = 5   // exact — no scale snapping for X-Files intervals
                let flat7  = 10  // exact — no scale snapping for X-Files intervals

                func place(_ pc: Int) -> Int { clampToRegister(72 + rootPC + pc, low: 72, high: 84) }

                let barStart = bar * 16

                if bridgeBar % 2 == 0 {
                    // Call bar: sustained background note from beat 2
                    let note = useXFiles ? place(fourth) : place(fifth)
                    let vel  = UInt8(60 + rng.nextInt(upperBound: 14))   // 60–73, softer
                    events.append(MIDIEvent(stepIndex: barStart + 4, note: UInt8(note),
                                            velocity: vel, durationSteps: 11))
                } else if xFilesResponseBars.contains(bar) {
                    // X-Files whistle: A–E–D–E–G–E = root→5th→4th→5th→b7→5th held
                    // All quarter notes; final E is whole note (held). Spans ~2.25 bars.
                    let xPhrase: [(Int, Int, Int)] = [
                        (place(0),       0,  4),   // A — quarter (root)
                        (place(fifth),   4,  4),   // E — quarter
                        (place(fourth),  8,  4),   // D — quarter
                        (place(fifth),  12,  4),   // E — quarter
                        (place(flat7),  16,  4),   // G — quarter (spills into next bar)
                        (place(fifth),  20, 16),   // E — whole note held
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

    // MARK: - KOS-LD1-010: Tycho Phrase (Drift)
    // 4–6 note phrase with rise-to-peak arc, then descent.
    // Stated once, then repeated with one random note shifted ±1 diatonic step after 10–14 bar silence.
    // Velocity arc mirrors pitch contour.
    private static func generateTychoPhrase(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG, velBase: Int
    ) -> [MIDIEvent] {
        let bodyStart = structure.introSection?.endBar ?? 0
        let bodyEnd   = structure.outroSection?.startBar ?? frame.totalBars
        guard bodyEnd > bodyStart + 8 else { return [] }

        // Build phrase: 4–6 diatonic notes, rise then fall
        let phraseNotes: Int = 4 + rng.nextInt(upperBound: 3)
        guard let firstEntry = tonalMap.entry(atBar: bodyStart) ?? tonalMap.first else { return [] }
        let scaleNotes = scaleNotesInRegister(
            entry: firstEntry,
            frame: frame, low: 60, high: 80
        )
        guard scaleNotes.count >= 4 else { return [] }

        // Start near middle, rise to peak, descend
        let peakIdx  = phraseNotes * 2 / 3   // peak at ~65% through phrase
        let startIdx = rng.nextInt(upperBound: Swift.max(1, scaleNotes.count / 3))
        var phraseIndices: [Int] = []
        for i in 0..<phraseNotes {
            if i < peakIdx {
                phraseIndices.append(Swift.min(scaleNotes.count - 1,
                    startIdx + Int(Double(i) * 2.5 / Double(peakIdx))))
            } else if i == peakIdx {
                phraseIndices.append(Swift.min(scaleNotes.count - 1, startIdx + 4 + rng.nextInt(upperBound: 3)))
            } else {
                let down = i - peakIdx
                phraseIndices.append(Swift.max(startIdx, phraseIndices[peakIdx] - down * 2))
            }
        }
        let phrase = phraseIndices.map { scaleNotes[Swift.max(0, Swift.min($0, scaleNotes.count - 1))] }

        // Durations: ascending notes 3–5 steps, peak held 12–20, descent 4–8
        var durations: [Int] = []
        for i in 0..<phraseNotes {
            if i == peakIdx {
                durations.append(12 + rng.nextInt(upperBound: 9))
            } else if i < peakIdx {
                durations.append(3 + rng.nextInt(upperBound: 3))
            } else {
                durations.append(4 + rng.nextInt(upperBound: 5))
            }
        }

        // Phrase spacing: appears every 12–16 bars starting from bodyStart + entry delay
        let spacing = 12 + rng.nextInt(upperBound: 5)
        let phraseLen = durations.reduce(0, +)

        var events: [MIDIEvent] = []
        var appearanceIdx = 0
        var phrasePitch = phrase  // may shift each repetition

        var bar = bodyStart + (spacing / 2)  // first appearance partway in
        while bar < bodyEnd - 4 {
            guard tonalMap.entry(atBar: bar) != nil else { bar += spacing; continue }

            // Velocity arc: low at start, peak at peak note, low again at end
            var step = bar * 16
            for (i, (note, dur)) in zip(phrase.indices, zip(phrasePitch, durations)) {
                let normPos = Double(i) / Double(phraseNotes - 1)
                let peakNorm = Double(peakIdx) / Double(phraseNotes - 1)
                let proximity = 1.0 - abs(normPos - peakNorm)
                let vel = UInt8(54 + Int(proximity * 18))  // 54–72, soft melodic arc
                let clampedNote = UInt8(clampToRegister(note, low: 60, high: 80))
                if step < frame.totalBars * 16 {
                    events.append(MIDIEvent(stepIndex: step, note: clampedNote,
                                            velocity: vel, durationSteps: dur))
                }
                step += dur
            }

            // Next repetition: always vary the final (cadential) note ±1 diatonic step.
            // The last note is the most audible variation point — the phrase ending changes
            // each time like a musician varying their cadence. Also shift one interior note
            // occasionally for additional colour.
            if appearanceIdx > 0 {
                let lastIdx = phraseNotes - 1
                let delta = rng.nextDouble() < 0.50 ? 1 : -1
                let newLastIdx = Swift.max(0, Swift.min(scaleNotes.count - 1,
                    phraseIndices[lastIdx] + delta))
                phraseIndices[lastIdx] = newLastIdx
                var newPhrase = phrasePitch
                newPhrase[lastIdx] = scaleNotes[newLastIdx]
                // Also shift one random interior note 40% of the time for additional colour
                if rng.nextDouble() < 0.40 {
                    let interiorNote = rng.nextInt(upperBound: phraseNotes - 1)  // exclude last
                    let iDelta = rng.nextDouble() < 0.50 ? 1 : -1
                    let newIIdx = Swift.max(0, Swift.min(scaleNotes.count - 1,
                        phraseIndices[interiorNote] + iDelta))
                    phraseIndices[interiorNote] = newIIdx
                    newPhrase[interiorNote] = scaleNotes[newIIdx]
                }
                phrasePitch = newPhrase
            }
            appearanceIdx += 1
            bar += phraseLen / 16 + spacing
        }
        return events
    }

    // MARK: - KOS-LD1-011: Drift Memory (Drift)
    // Short pentatonic cell, appears every 3–5 bars (jittered grid) from first entry.
    // Evolving (70%): 30% chance per 8-bar window to shift one note.
    // Static (30%): 10% chance per 16-bar window for micro-shift — cell never fully locks.
    // Octave doubling in 40% of songs.
    private static func generateDriftMemory(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG,
        velBase: Int, evolving: Bool
    ) -> [MIDIEvent] {
        let bodyStart = structure.introSection?.endBar ?? 0
        let bodyEnd   = structure.outroSection?.startBar ?? frame.totalBars
        guard bodyEnd > bodyStart + 8 else { return [] }

        let entryBar = bodyStart + 8 + rng.nextInt(upperBound: 9)
        guard entryBar < bodyEnd - 4 else { return [] }

        let cellSize = 3 + rng.nextInt(upperBound: 3)
        guard let entryEntry = tonalMap.entry(atBar: entryBar) ?? tonalMap.first else { return [] }
        let penta = pentatonicNotes(entry: entryEntry, frame: frame, low: 60, high: 78)
        guard penta.count >= 3 else { return [] }

        let keyST = keySemitone(frame.key)
        let minor3PC = (keyST + 3) % 12
        let major3PC = (keyST + 4) % 12
        let thirdNote = penta.first(where: { $0 % 12 == minor3PC || $0 % 12 == major3PC }) ?? penta[1]
        let startNote = rng.nextDouble() < 0.60 ? thirdNote : (penta.count > 2 ? penta[2] : penta[0])
        guard let startIdx = penta.firstIndex(of: startNote) else { return [] }

        var cell = Array(penta[startIdx..<Swift.min(startIdx + cellSize, penta.count)])
        if cell.count < cellSize && penta.count >= cellSize { cell = Array(penta.prefix(cellSize)) }

        let cellDurs = (0..<cell.count).map { _ in 6 + rng.nextInt(upperBound: 3) }
        let useOctave = rng.nextDouble() < 0.40

        let midpoint    = bodyStart + (bodyEnd - bodyStart) / 2
        let absenceLen  = 8 + rng.nextInt(upperBound: 9)
        let absenceStart = midpoint - absenceLen / 2
        let absenceEnd   = absenceStart + absenceLen

        let vb = UInt8(clamping: velBase)
        var events: [MIDIEvent] = []
        var bar = entryBar
        // Evolution tracking
        var lastEvolveWin  = -1
        var lastStaticWin  = -1
        var appearanceCount = 0   // guaranteed shift of last note every 3 appearances

        while bar < bodyEnd {
            if bar >= absenceStart && bar < absenceEnd { bar += 3 + rng.nextInt(upperBound: 3); continue }
            guard let _ = tonalMap.entry(atBar: bar) else { bar += 4; continue }

            // Guaranteed: last note shifts every 3rd appearance (both evolving and static).
            // This ensures audible variation in every song regardless of window luck.
            if appearanceCount > 0 && appearanceCount % 3 == 0 {
                let lastIdx = cell.count - 1
                let pIdx = penta.firstIndex(of: cell[lastIdx]) ?? 0
                let delta = rng.nextDouble() < 0.50 ? 1 : -1
                let newPIdx = Swift.max(0, Swift.min(penta.count - 1, pIdx + delta))
                cell[lastIdx] = penta[newPIdx]
            }

            // Additional window-based evolution on top of the guaranteed shift
            let evolveWin = bar / 8
            let staticWin = bar / 16
            if evolving && evolveWin != lastEvolveWin {
                lastEvolveWin = evolveWin
                if rng.nextDouble() < 0.40 {   // raised from 30% to 40% for more audible change
                    let shiftIdx = rng.nextInt(upperBound: cell.count - 1)  // interior note, not last
                    let pIdx = penta.firstIndex(of: cell[shiftIdx]) ?? 0
                    let delta = rng.nextDouble() < 0.50 ? 1 : -1
                    let newPIdx = Swift.max(0, Swift.min(penta.count - 1, pIdx + delta))
                    cell[shiftIdx] = penta[newPIdx]
                }
            } else if !evolving && staticWin != lastStaticWin {
                lastStaticWin = staticWin
                if rng.nextDouble() < 0.20 {   // raised from 10% for static micro-evolution
                    let shiftIdx = rng.nextInt(upperBound: cell.count - 1)
                    let pIdx = penta.firstIndex(of: cell[shiftIdx]) ?? 0
                    let delta = rng.nextDouble() < 0.50 ? 1 : -1
                    let newPIdx = Swift.max(0, Swift.min(penta.count - 1, pIdx + delta))
                    cell[shiftIdx] = penta[newPIdx]
                }
            }
            appearanceCount += 1

            // Place the cell
            var step = bar * 16
            for (i, note) in cell.enumerated() {
                let midi = clampToRegister(note, low: 60, high: 78)
                let vel  = UInt8(clamping: Int(vb) + rng.nextInt(upperBound: 9) - 4)
                let dur  = cellDurs[i]
                if step < frame.totalBars * 16 {
                    events.append(MIDIEvent(stepIndex: step, note: UInt8(midi), velocity: vel, durationSteps: dur))
                    if useOctave {
                        let octMidi = clampToRegister(note + 12, low: 60, high: 92)
                        events.append(MIDIEvent(stepIndex: step, note: UInt8(octMidi), velocity: vel, durationSteps: dur))
                    }
                }
                step += dur
            }

            // Jittered grid: 3, 4, or 5 bars until next appearance
            bar += 3 + rng.nextInt(upperBound: 3)
        }
        return events
    }

    // MARK: - KOS-LD1-012: Svefn Float (Drift / Dreamscape)
    //
    // Enters after 1/3 of the song. Each appearance is a short 3–5 note melodic phrase
    // using scale notes in stepwise motion — not random chord tones, but a slow singing line.
    // Notes held 2–5 beats each. Silences of 6–10 bars between phrases. 6–10 appearances.
    // Never starts a phrase on the same pitch class as the previous phrase's first note.
    // Velocity near-flat. The phrase should feel like a held breath surfacing from the texture.
    private static func generateSvefnFloat(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG, velBase: Int
    ) -> [MIDIEvent] {
        let bodyStart = structure.introSection?.endBar ?? 0
        let bodyEnd   = structure.outroSection?.startBar ?? frame.totalBars
        let bodyLen   = bodyEnd - bodyStart

        // Entry: after 1/3 of the song from the body start
        let minEntry  = bodyStart + Swift.max(bodyLen / 3, 8)
        let entryBar  = minEntry + rng.nextInt(upperBound: Swift.max(1, bodyLen / 10))
        guard entryBar < bodyEnd - 6 else { return [] }

        var prevPitchClass: Int = -1
        var events: [MIDIEvent] = []

        // 6–10 total phrases, spaced 6–10 bars apart
        let phraseCount = 6 + rng.nextInt(upperBound: 5)
        var bar = entryBar

        for _ in 0..<phraseCount {
            guard bar < bodyEnd - 4 else { break }
            guard let entry = tonalMap.entry(atBar: bar) else { bar += 8; continue }

            // Get scale notes in a comfortable register
            let scaleNotes = scaleNotesInRegister(entry: entry, frame: frame, low: 60, high: 79)
            guard scaleNotes.count >= 3 else { bar += 8; continue }

            // Pick start note — avoid the same pitch class as previous phrase's start
            let startCandidates = scaleNotes.filter { $0 % 12 != prevPitchClass }
            guard !startCandidates.isEmpty else { bar += 8; continue }
            let startNote = startCandidates[rng.nextInt(upperBound: startCandidates.count)]
            guard let startIdx = scaleNotes.firstIndex(of: startNote) else { bar += 8; continue }
            prevPitchClass = startNote % 12

            // Build a 3–5 note phrase moving stepwise from the start
            // Direction: ascending (0), descending (1), or arch up then down (2)
            let phraseLen = 3 + rng.nextInt(upperBound: 3)
            let direction = rng.nextInt(upperBound: 3)  // 0=up, 1=down, 2=arch

            var phraseNotes: [Int] = [startNote]
            var idx = startIdx
            let peak = phraseLen * 2 / 3

            for i in 1..<phraseLen {
                let goUp: Bool
                switch direction {
                case 0: goUp = true
                case 1: goUp = false
                default: goUp = (i <= peak)  // arch: up then down
                }
                let step = goUp ? 1 : -1
                idx = Swift.max(0, Swift.min(scaleNotes.count - 1, idx + step))
                phraseNotes.append(scaleNotes[idx])
            }

            // Place notes: each held 2–5 beats (8–20 steps)
            // Velocity soft and near-flat — 46–62 so the float surfaces gently from the texture.
            var tickStep = bar * 16
            for note in phraseNotes {
                let dur = (2 + rng.nextInt(upperBound: 4)) * 4   // 8–16 steps (2–4 beats)
                if tickStep < bodyEnd * 16 {
                    let vel = UInt8(46 + rng.nextInt(upperBound: 17))
                    events.append(MIDIEvent(stepIndex: tickStep, note: UInt8(note),
                                            velocity: vel, durationSteps: dur))
                }
                tickStep += dur
            }

            // Silence before next phrase: 6–10 bars
            bar += 6 + rng.nextInt(upperBound: 5)
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
