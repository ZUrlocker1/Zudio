// ChillRhythmGenerator.swift — Chill generation step 7 (Rhythm track)
// Copyright (c) 2026 Zack Urlocker
// Rhythm = Rhodes active comping (Electric Piano 1, program 4).
// Six comping modes, flat-weighted (2026, mood-independent — see pickCompingMode): St Germain
// Syncopated, Moby Backbeat, Bosa Moon Arpeggiated, Chord Hold, Downbeat Pulse, plus Acid Jazz
// Stab Groove (hipHopJazz beat style only).
// Voicings: upper-structure jazz [3rd, 5th, 7th] — root omitted (CHL-SYNC-004).
// Silent in breakdown and intro (CHL-RHY rules).

import Foundation

struct ChillRhythmGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        beatStyle: ChillBeatStyle = .electronic,
        breakdownStyle: ChillBreakdownStyle = .bassOstinato,
        bluesVariation: Bool = false,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        switchAnnotation: inout (bar: Int, ruleID: String)?
    ) -> [MIDIEvent] {
        // A and B sections always use two different comping modes — keeps the comping track
        // from settling into one flavor for the whole song.
        let modeA: CompingMode
        let modeB: CompingMode
        if bluesVariation {
            // Blues: weighted pick among the four non-arpeggiated modes (Bosa Moon and Acid Jazz
            // don't suit blues phrasing); B section always takes a different one.
            modeA = pickBluesCompingMode(rng: &rng)
            modeB = pickDifferentCompingMode(from: modeA, allCandidates: Self.allBluesCompingModes,
                                              picker: pickBluesCompingMode, rng: &rng)
        } else if beatStyle.isSoho {
            // Chill Soho: pools follow the groove (see "Implementation contract" in
            // docs/chill-soho-plan.md). Latin has two modes, so A and B always play both.
            let latin  = beatStyle == .sohoLatin
            let picker = latin ? pickSohoLatinCompingMode : pickSohoSoulCompingMode
            modeA = picker(&rng)
            modeB = pickDifferentCompingMode(from: modeA,
                                             allCandidates: latin ? Self.allSohoLatinModes : Self.allSohoSoulModes,
                                             picker: picker, rng: &rng)
        } else if beatStyle == .hipHopJazz {
            // Acid jazz stab keeps its signature groove on the A section; B section switches
            // to a different mode for contrast.
            modeA = .acidJazzStab
            modeB = pickDifferentCompingMode(from: modeA, allCandidates: Self.allCompingModes,
                                              picker: pickCompingMode, rng: &rng)
        } else {
            modeA = pickCompingMode(rng: &rng)
            modeB = pickDifferentCompingMode(from: modeA, allCandidates: Self.allCompingModes,
                                              picker: pickCompingMode, rng: &rng)
        }
        usedRuleIDs.insert(modeA.ruleID)
        usedRuleIDs.insert(modeB.ruleID)
        // Blues intro: keyboard enters at bar 1 (50%) or bar 3 (50%) — not from bar 0.
        let bluesKeyboardBar: Int = bluesVariation ? (rng.nextDouble() < 0.50 ? 1 : 3) : 0
        // Simple form (single body section, no B) never gets to hear modeB via the A/B split
        // above — force a mid-body switch instead, snapped to a chord-plan boundary so it lands
        // on the song's natural phrase edge (8/12/16-bar cycles etc.) rather than an arbitrary bar.
        // Purely internal to this function — generateComping needs it to decide when to switch
        // modes, but nothing outside this file needs to know where it landed (switchAnnotation
        // below already carries the one thing callers actually use it for: bar + target rule).
        let forcedSwitchBar = forcedMidBodySwitchBar(structure: structure)
        // Report exactly where and to which rule the comping mode switches, so the live log can
        // say "Rhythm switch to <rule>" instead of a vague "evolving" — either the natural B
        // section boundary, or forcedSwitchBar for a Simple-form (single-body) song.
        let switchBar = structure.hasBSection
            ? structure.sections.first(where: { $0.label == .B })?.startBar
            : forcedSwitchBar
        switchAnnotation = switchBar.map { (bar: $0, ruleID: modeB.ruleID) }
        // Sparse fragments (2026): the whole groove/body is tiled into consecutive 12- or 16-bar
        // segments, aligned to chord-plan boundaries, and each segment independently has a 35%
        // chance of going sparse — St Germain/Bosa Moon fall back to their existing periodic
        // "sparse bar" shape for the whole segment, Moby Backbeat goes half-time. Every song has
        // this tiling; a typical 60-100 bar song ends up with 2-3 sparse segments, not zero or one.
        let sparseFragments = pickSparseFragments(structure: structure, rng: &rng)
        // Dropout fragment (2026): a single, more dramatic gesture — Rhythm goes fully silent for
        // one 12- or 16-bar stretch, giving Bass/Drums/Lead the full spotlight. Fires in 20% of
        // songs normally, but ALWAYS when Bosa Moon Arpeggiated is in play — it's the busiest mode
        // by far (100% step coverage even outside its sparse bars) and benefits most from a real
        // break rather than just the thinner sparse-fragment treatment. Takes priority over sparse
        // fragments if the two happen to overlap (silence wins over merely thinner).
        let hasBosaMoon = modeA == .bosaMoonArpeggiated || modeB == .bosaMoonArpeggiated
        // Chill Soho: in this music the strongest variation Rhythm has is to stop. Every Soho
        // song gets long dropouts — one per ~32 groove bars, 8–16 bars each — where base Chill
        // gets at most one, in 20% of songs. Base Chill's draw is unchanged.
        let dropoutFragments: [Range<Int>] = beatStyle.isSoho
            ? pickSohoDropoutFragments(structure: structure, rng: &rng)
            : [pickRhythmDropoutFragment(structure: structure, forceInclude: hasBosaMoon,
                                         rng: &rng)].compactMap { $0 }
        // CHL-RHY-009 rotates its variants on its own 8–12 bar period; drawn for Soho only.
        let eighthsPeriod = beatStyle.isSoho ? 8 + rng.nextInt(upperBound: 5) : 8
        return generateComping(frame: frame, structure: structure,
                                modeA: modeA, modeB: modeB, breakdownStyle: breakdownStyle,
                                bluesVariation: bluesVariation, bluesKeyboardBar: bluesKeyboardBar,
                                forcedSwitchBar: forcedSwitchBar, sparseFragments: sparseFragments,
                                dropoutFragments: dropoutFragments, clave: beatStyle == .sohoLatin,
                                soho: beatStyle.isSoho, eighthsPeriod: eighthsPeriod, rng: &rng)
    }

    /// Picks a single fragment (12 or 16 bars, chord-plan-boundary aligned) where the whole
    /// Rhythm track drops out completely. See call site for frequency rationale.
    private static func pickRhythmDropoutFragment(structure: SongStructure, forceInclude: Bool,
                                                   probability: Double = 0.20,
                                                   rng: inout SeededRNG) -> Range<Int>? {
        guard forceInclude || rng.nextDouble() < probability else { return nil }
        let grooveSections = structure.sections.filter { $0.label == .A || $0.label == .B }
        guard let grooveStart = grooveSections.first?.startBar,
              let grooveEnd   = grooveSections.last?.endBar else { return nil }
        let length = rng.nextDouble() < 0.5 ? 12 : 16
        guard grooveEnd - grooveStart >= length + 8 else { return nil }
        let candidates = structure.chordPlan
            .map(\.startBar)
            .filter { $0 >= grooveStart + 4 && $0 + length <= grooveEnd - 4 }
        guard !candidates.isEmpty else { return nil }
        let start = candidates[rng.nextInt(upperBound: candidates.count)]
        return start..<(start + length)
    }

    /// Chill Soho's long rhythm dropouts: one per ~32 bars of groove (at least one, at most
    /// three), each 8, 12 or 16 bars, slotted across the song so they spread rather than
    /// cluster. Each sits wholly inside one A or B section — a dropout running into a breakdown
    /// would be cut in two and heard as two short gaps — starts on a 4-bar boundary of that
    /// section, and leaves at least 4 bars of playing before the next. The first never starts
    /// within 8 bars of the groove's opening, nor does any reach the last 4 bars of the groove.
    static func pickSohoDropoutFragments(structure: SongStructure, rng: inout SeededRNG) -> [Range<Int>] {
        let groove = structure.sections.filter { $0.label == .A || $0.label == .B }
        guard let start = groove.first?.startBar, let end = groove.last?.endBar else { return [] }
        let grooveBars = groove.reduce(0) { $0 + $1.lengthBars }
        let count = Swift.max(1, Swift.min(3, grooveBars / 32))
        let slot  = (end - start) / count
        var result: [Range<Int>] = []
        var earliest = start + 8
        for w in 0..<count {
            var length = 8 + 4 * rng.nextInt(upperBound: 3)            // 8, 12 or 16 bars
            let lo = Swift.max(earliest, start + w * slot)
            let hi = start + (w + 1) * slot
            func starts(_ len: Int) -> [Int] {
                guard lo < hi else { return [] }
                return (lo..<hi).filter { b in
                    guard let sec = groove.first(where: { $0.startBar <= b && b < $0.endBar }) else { return false }
                    // Never the section's own last bar: that bar leads into whatever follows, and
                    // where a Remix Break follows it carries the band's unison hits.
                    let limit = sec.endBar == end ? end - 4 : sec.endBar - 1
                    return (b - sec.startBar) % 4 == 0 && b + len <= limit
                }
            }
            var options = starts(length)
            if options.isEmpty && length > 8 { length = 8; options = starts(8) }
            guard !options.isEmpty else { continue }
            let at = options[rng.nextInt(upperBound: options.count)]
            result.append(at..<(at + length))
            earliest = at + length + 4
        }
        return result
    }

    /// Tiles each groove/body section (A and B independently — Chill has at most one of each)
    /// into consecutive 12- or 16-bar segments, snapped to chord-plan boundaries, and
    /// independently rolls each segment (35%) for a sparse treatment — up to 2 sparse segments
    /// per section (further rolls still consume RNG for determinism but are discarded). Capping
    /// per section rather than per song means A and B — which always use different comping modes
    /// — each get their own chance to show a sparse moment, rather than one section's fragments
    /// using up the whole song's budget and leaving the other mode with none.
    private static func pickSparseFragments(structure: SongStructure, rng: inout SeededRNG) -> [Range<Int>] {
        var result: [Range<Int>] = []
        for section in structure.sections where section.label == .A || section.label == .B {
            result += pickSparseFragments(inSection: section, chordPlan: structure.chordPlan, rng: &rng)
        }
        return result
    }

    private static func pickSparseFragments(inSection section: SongSection, chordPlan: [ChordWindow],
                                             rng: inout SeededRNG) -> [Range<Int>] {
        guard section.lengthBars >= 16 else { return [] }
        let boundaries = chordPlan.map(\.startBar).filter { $0 > section.startBar && $0 < section.endBar }
        let maxSparseFragments = 2

        var sparseFragments: [Range<Int>] = []
        var cursor = section.startBar
        while cursor < section.endBar {
            let targetLength = rng.nextDouble() < 0.5 ? 12 : 16
            let target = cursor + targetLength
            let segmentEnd = boundaries.first(where: { $0 >= target }) ?? section.endBar
            guard segmentEnd > cursor else { break }
            if rng.nextDouble() < 0.35, sparseFragments.count < maxSparseFragments {
                sparseFragments.append(cursor..<min(segmentEnd, section.endBar))
            }
            cursor = segmentEnd
        }
        return sparseFragments
    }

    /// For Chill's Simple form (single body section, no B) — snaps a forced rhythm-mode switch
    /// point to the nearest chord-plan boundary near the body's midpoint. Returns nil when the
    /// song already has a real B section (the A/B split above handles it) or the body is too
    /// short to bother splitting.
    private static func forcedMidBodySwitchBar(structure: SongStructure) -> Int? {
        guard !structure.hasBSection,
              let body = structure.bodySections.first,
              body.lengthBars >= 24 else { return nil }
        let target = body.startBar + body.lengthBars / 2
        let candidates = structure.chordPlan
            .map(\.startBar)
            .filter { $0 > body.startBar + 8 && $0 < body.endBar - 8 }
        return candidates.min(by: { abs($0 - target) < abs($1 - target) })
    }

    // MARK: - Comping modes

    private enum CompingMode: Equatable {
        case stGermainSyncopated   // CHL-RHY-001
        case mobyBackbeat          // CHL-RHY-002
        case bosaMoonArpeggiated   // CHL-RHY-003
        case acidJazzStab          // CHL-RHY-004
        case chordHold             // CHL-RHY-005
        case downbeatPulse         // CHL-RHY-006
        case chordalComp           // CHL-RHY-007 — Chill Soho
        case singleNoteLine        // CHL-RHY-008 — Chill Soho
        case rootAndChordEighths   // CHL-RHY-009 — Chill Soho

        var ruleID: String {
            switch self {
            case .stGermainSyncopated: return "CHL-RHY-001"
            case .mobyBackbeat:        return "CHL-RHY-002"
            case .bosaMoonArpeggiated: return "CHL-RHY-003"
            case .acidJazzStab:        return "CHL-RHY-004"
            case .chordHold:           return "CHL-RHY-005"
            case .downbeatPulse:       return "CHL-RHY-006"
            case .chordalComp:         return "CHL-RHY-007"
            case .singleNoteLine:      return "CHL-RHY-008"
            case .rootAndChordEighths: return "CHL-RHY-009"
            }
        }
    }

    /// Fallback candidate lists for `pickDifferentCompingMode`'s rejection-sampling loop.
    private static let allCompingModes: [CompingMode] = [.stGermainSyncopated, .mobyBackbeat,
        .bosaMoonArpeggiated, .acidJazzStab, .chordHold, .downbeatPulse]
    private static let allBluesCompingModes: [CompingMode] = [.mobyBackbeat, .stGermainSyncopated,
        .chordHold, .downbeatPulse]
    private static let allSohoLatinModes: [CompingMode] = [.chordalComp, .rootAndChordEighths, .singleNoteLine]
    private static let allSohoSoulModes:  [CompingMode] = [.chordalComp, .singleNoteLine,
        .chordHold, .downbeatPulse, .rootAndChordEighths]

    /// Chill Soho, Latin pool: CHL-RHY-007 40%, CHL-RHY-009 30%, CHL-RHY-008 30%.
    /// Levelled from 45/30/25 at Zack's call (2026-10-15).
    private static func pickSohoLatinCompingMode(rng: inout SeededRNG) -> CompingMode {
        let roll = rng.nextDouble()
        if roll < 0.40 { return .chordalComp }
        if roll < 0.70 { return .rootAndChordEighths }
        return .singleNoteLine
    }

    /// Chill Soho, Soul pool: CHL-RHY-007 25%, CHL-RHY-008 25%, the reused Chord Hold and
    /// Downbeat Pulse at 15% each, and CHL-RHY-009 at 20%. 009 was 10% (both EBTG sources are
    /// non-Latin) and was raised at Zack's call (2026-10-15), from 007 and 008 equally.
    /// Bosa Moon (not a bossa) and the Moby backbeat stay excluded.
    private static func pickSohoSoulCompingMode(rng: inout SeededRNG) -> CompingMode {
        let roll = rng.nextDouble()
        if roll < 0.25 { return .chordalComp }
        if roll < 0.50 { return .singleNoteLine }
        if roll < 0.65 { return .chordHold }
        if roll < 0.80 { return .downbeatPulse }
        return .rootAndChordEighths
    }

    /// Weights (2026 flattening): this pool used to have separate weight tables for Deep/Dream
    /// vs Free/Bright moods. That made every "how often does rule X show up" question require a
    /// Monte Carlo simulation instead of a direct read of the number (mood-averaged population
    /// share isn't just the table value — it depends on the mood distribution too, and on how the
    /// "modeA always != modeB" pairing interacts with each mood's table). Flattened to one table,
    /// tuned to reproduce the same population-level shares the old mood-weighted version had
    /// (verified by simulation): Moby ~49%, St Germain ~45%, Bosa Moon ~40%, Chord Hold ~28%,
    /// Downbeat Pulse ~21%. Bosa Moon (100% step coverage, the busiest by far) still sits lowest;
    /// nothing about the audible mix changed, only how easy it is to reason about. See
    /// docs/chill-plan.md "Mood-dependent parameters" for the fuller rationale, and
    /// docs/change-log.md for the numbers this replaced.
    private static func pickCompingMode(rng: inout SeededRNG) -> CompingMode {
        let roll = rng.nextDouble()
        if roll < 0.30 { return .bosaMoonArpeggiated }
        if roll < 0.50 { return .mobyBackbeat }
        if roll < 0.69 { return .chordHold }
        if roll < 0.86 { return .stGermainSyncopated }
        return .downbeatPulse
    }

    /// Blues comping pool (2026): Moby Backbeat and St Germain Syncopated remain the dominant,
    /// "real" blues comping choices; Chord Hold and Downbeat Pulse added as lighter supporting
    /// textures. Bosa Moon and Acid Jazz stay excluded — neither suits blues phrasing.
    private static func pickBluesCompingMode(rng: inout SeededRNG) -> CompingMode {
        let roll = rng.nextDouble()
        if roll < 0.40 { return .mobyBackbeat }
        if roll < 0.65 { return .stGermainSyncopated }
        if roll < 0.85 { return .chordHold }
        return .downbeatPulse
    }

    /// Picks a comping mode guaranteed to differ from `excluded`, drawing candidates from
    /// `picker` (either `pickCompingMode` or `pickBluesCompingMode`) up to 8 times before
    /// falling back to a plain scan of `allCandidates` — astronomically unlikely to be needed,
    /// but keeps this a total function rather than risking an infinite loop. Shared by both the
    /// main pool and the Blues-only pool (2026 — previously two near-identical copies of this
    /// same rejection-sampling loop, one per pool).
    private static func pickDifferentCompingMode(from excluded: CompingMode, allCandidates: [CompingMode],
                                                  picker: (inout SeededRNG) -> CompingMode,
                                                  rng: inout SeededRNG) -> CompingMode {
        for _ in 0..<8 {
            let candidate = picker(&rng)
            if candidate != excluded { return candidate }
        }
        return allCandidates.first { $0 != excluded } ?? excluded
    }

    // MARK: - Main generator

    private static func generateComping(frame: GlobalMusicalFrame, structure: SongStructure,
                                         modeA: CompingMode, modeB: CompingMode,
                                         breakdownStyle: ChillBreakdownStyle,
                                         bluesVariation: Bool = false,
                                         bluesKeyboardBar: Int = 0,
                                         forcedSwitchBar: Int? = nil,
                                         sparseFragments: [Range<Int>] = [],
                                         dropoutFragments: [Range<Int>] = [],
                                         clave: Bool = false,
                                         soho: Bool = false,
                                         eighthsPeriod: Int = 8,
                                         rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scalePCs  = frame.scalePCs
        let snapTable = ChillPadsGenerator.makeSnapTable(scalePCs)
        // Extends a triggered rest bar to 2 bars occasionally — set to the bar right after a
        // rest bar that rolled the extension, then consumed and cleared on the next iteration.
        var extendedRestBar: Int? = nil
        let remixEntry = ChillStructureGenerator.remixEntryBars(structure: structure,
                                                                breakdownStyle: breakdownStyle)

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Cold start: bar 0 is drums-only, rhythm silent
            if case .coldStart = structure.introStyle, bar == 0 { continue }

            // Cold stop: final bar silent; crash bar gets a chord stab landing with the crash.
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar >= outroEnd - 1 { continue }
                if bar == outroEnd - 2 {
                    let chord   = structure.chordWindow(atBar: bar)
                    let voicing = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
                    let base    = bar * 16
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: 92, durationSteps: 3))
                    }
                    continue
                }
            }

            // Outro: always silent
            if label == .outro { continue }
            // Intro: silent unless blues (keyboard enters at bluesKeyboardBar). Chill Soho's
            // comping enters two bars before the groove does — it was silent through every intro,
            // which is most of why they sounded like bass and drums alone (Zack, 2026-10-12).
            if label == .intro {
                let introStart = structure.introSection?.startBar ?? 0
                if soho {
                    // The comping enters for the intro's LAST TWO bars, so the build adds one
                    // thing a bar: percussion, then comping, then the bass figure on the final
                    // bar. Tied to the end of the intro rather than to a layer number — a cold
                    // start spends the first bar on a drums-only pickup, which pushed the entry
                    // to the same bar as the bass and made the build lopsided (Zack, 2026-10-12).
                    // Whichever of the comping and the bass leads enters on the second-to-last
                    // bar; the other joins on the last.
                    let leads = !ChillStructureGenerator.sohoBassLeadsIntro(frame: frame, structure: structure)
                    guard let intro = structure.introSection,
                          bar >= intro.endBar - (leads ? 2 : 1) else { continue }
                } else if !bluesVariation {
                    continue
                } else if bar - introStart < bluesKeyboardBar {
                    continue
                }
                // Fall through to normal comping for the remaining intro bars
            }

            // Breakdown handling
            if label == .bridge {
                let breakdownBar = bar - (section?.startBar ?? bar)
                let chord   = structure.chordWindow(atBar: bar)
                let base    = bar * 16
                let sectionLen = section?.lengthBars ?? 4

                if breakdownStyle == .sohoRemix {
                    // Remix Break (Chill Soho): Rhythm reduced to short offbeat stabs — the house
                    // offbeat chord on 2, 6, 10 and 14 — and on the last bar it joins the band's
                    // unison hits on 0 and 8.
                    let voicing = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
                    let isLast  = breakdownBar == sectionLen - 1
                    for step in (isLast ? [0, 8] : [2, 6, 10, 14]) {
                        let vel = UInt8((isLast ? 70 : 48) + rng.nextInt(upperBound: 12))
                        for note in voicing {
                            events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note),
                                                    velocity: vel, durationSteps: isLast ? 2 : 1))
                        }
                    }
                    continue
                } else if breakdownStyle == .groovePocket {
                    // Rhythm plays straight through — fall through to normal comping below.
                    // For 8-bar pockets, overlay escalating tension stabs in bars 6–8.
                    if sectionLen >= 8 && breakdownBar >= 5 {
                        let voicing    = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
                        let tensionBar = breakdownBar - 5   // 0 = bar 6, 1 = bar 7, 2 = bar 8
                        let stabSteps: [Int]
                        switch tensionBar {
                        case 0:  stabSteps = [8]           // bar 6: beat 3
                        case 1:  stabSteps = [8, 12]       // bar 7: beats 3+4
                        default: stabSteps = [4, 8, 12]    // bar 8: beats 2+3+4
                        }
                        for step in stabSteps {
                            let vel = UInt8(Swift.min(95, 68 + tensionBar * 8 + rng.nextInt(upperBound: 10)))
                            for note in voicing {
                                events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note),
                                                        velocity: vel, durationSteps: 3))
                            }
                        }
                    }
                    // Fall through — normal comping runs below
                } else if breakdownStyle == .stopTime && breakdownBar % 2 == 1 {
                    // Odd (silence) bars: chord reveal — play voicing bottom to top on beats 2, 3, 4.
                    let sorted = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable).sorted()
                    let n = sorted.count
                    if n >= 1 {
                        events.append(MIDIEvent(stepIndex: base + 4,  note: UInt8(sorted[0]),
                                                velocity: UInt8(60 + rng.nextInt(upperBound: 10)), durationSteps: 3))
                    }
                    if n >= 2 {
                        events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(sorted[1]),
                                                velocity: UInt8(70 + rng.nextInt(upperBound: 10)), durationSteps: 3))
                    }
                    if n >= 3 {
                        let vel = UInt8(80 + rng.nextInt(upperBound: 10))
                        for note in sorted.suffix(n > 3 ? 2 : 1) {
                            events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(note),
                                                    velocity: vel, durationSteps: 3))
                        }
                    }
                    continue
                } else if breakdownStyle == .bassOstinato {
                    // Bass ostinato: one beat-2 chord stab keeps harmonic context
                    let voicing = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
                    let vel     = UInt8(42 + rng.nextInt(upperBound: 12))
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: base + 4, note: UInt8(note), velocity: vel, durationSteps: 4))
                    }
                    continue
                } else {
                    continue  // .harmonicDrone and .stopTime even bars: silent
                }
            }

            // The bar leading into the Remix Break: stop after beat 2, then hit beats 3 and 4
            // with the rest of the band. Overrides the rest-bar and dropout logic below — this
            // bar is the way in, and the band does not sit it out.
            if remixEntry.contains(bar) {
                let chord   = structure.chordWindow(atBar: bar)
                let voicing = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
                let base    = bar * 16
                for step in [8, 12] {
                    let vel = UInt8(76 + rng.nextInt(upperBound: 12))
                    for note in voicing {
                        events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note),
                                                velocity: vel, durationSteps: 2))
                    }
                }
                continue
            }

            // Consume a rest bar that was extended to 2 bars on the previous iteration.
            if let extended = extendedRestBar, bar == extended {
                extendedRestBar = nil
                continue
            }

            // Dropout fragment: Rhythm goes fully silent for this stretch — takes priority over
            // the rest-bar and sparse-fragment mechanics below.
            if dropoutFragments.contains(where: { $0.contains(bar) }) { continue }

            // Rest bars: comping periodically lays out completely so the track doesn't feel
            // relentless. Roughly one rest every ~23 bars on average, never on back-to-back bars.
            // ~20% of triggered rests extend to a second bar (only if that next bar is still the
            // same section, so the extension never bleeds into a breakdown/outro boundary).
            let barInSection = bar - (section?.startBar ?? bar)
            if barInSection > 0 && barInSection % 8 == 7 && rng.nextDouble() < 0.35 {
                if rng.nextDouble() < 0.20, structure.section(atBar: bar + 1)?.label == label {
                    extendedRestBar = bar + 1
                }
                continue
            }

            let chord     = structure.chordWindow(atBar: bar)
            let voicing   = buildVoicing(frame: frame, chord: chord, baseRegister: 52, snapTable: snapTable)
            let base      = bar * 16

            // B section always plays a different comping mode than A (and everything else);
            // for a single-body (Simple form) song, forcedSwitchBar does the same job mid-body.
            let useModeB = (label == .B) || (forcedSwitchBar.map { bar >= $0 } ?? false)
            let compingMode = useModeB ? modeB : modeA
            // Chill Soho's intro takes the sparse shape of whichever mode is running: it is a way
            // in, not the groove proper. Scoped to Soho — Chill Blues also comps in its intro, and
            // thinning it there changed songs that are already released.
            let forceSparse = sparseFragments.contains { $0.contains(bar) } || (soho && label == .intro)

            switch compingMode {
            case .stGermainSyncopated:
                events += stGermainSyncopated(base: base, voicing: voicing, bar: bar,
                                               sectionStart: section?.startBar ?? 0,
                                               forceSparse: forceSparse,
                                               rng: &rng)
            case .mobyBackbeat:
                events += mobyBackbeat(base: base, voicing: voicing, bar: bar,
                                        halfTime: forceSparse, rng: &rng)
            case .bosaMoonArpeggiated:
                events += bosaMoonArpeggiated(base: base, voicing: voicing, frame: frame,
                                               chord: chord, bar: bar,
                                               sectionStart: section?.startBar ?? 0,
                                               forceSparse: forceSparse,
                                               rng: &rng)
            case .acidJazzStab:
                events += acidJazzStab(base: base, voicing: voicing, bar: bar, rng: &rng)
            case .chordHold:
                events += chordHold(base: base, voicing: voicing, bar: bar,
                                     forceSparse: forceSparse, rng: &rng)
            case .downbeatPulse:
                events += downbeatPulse(base: base, voicing: voicing, bar: bar,
                                         forceSparse: forceSparse, rng: &rng)
            case .chordalComp:
                events += chordalComp(base: base, voicing: voicing, bar: bar, clave: clave,
                                      forceSparse: forceSparse, rng: &rng)
            case .singleNoteLine:
                events += singleNoteLine(base: base, chord: chord, bar: bar,
                                         forceSparse: forceSparse, rng: &rng)
            case .rootAndChordEighths:
                events += rootAndChordEighths(base: base, frame: frame, chord: chord, voicing: voicing,
                                              bar: bar, variant: (bar / eighthsPeriod) % 3,
                                              forceSparse: forceSparse, rng: &rng)
            }
        }
        return events
    }

    // MARK: - CHL-RHY-007: Chordal Comp (Chill Soho)

    /// CHL-RHY-007 Chordal Comp. Measured from the electric-piano comps of Black Cow, Your Love Is
    /// King, Smooth Operator and Holding Back the Years: 2–3 note rootless voicings, 7–13 notes a
    /// bar, short 2–3 step stabs, with steps 0, 6 and 12 carrying the weight and 4, 9, 10 and 14 as
    /// secondary placements. Velocity 48–62 — restraint here comes from touch, not from sparseness.
    ///
    /// `clave` (Latin groove): the bar pair plays a 3-2 clave — 0, 6, 12 then 4, 10, 14 — the
    /// "two-bar answer" the plan specifies. Soul: the measured 0, 6, 12 every bar, plus a
    /// secondary hit. forceSparse keeps only the downbeat and the "and of two".
    static func chordalComp(base: Int, voicing: [Int], bar: Int, clave: Bool,
                                    forceSparse: Bool, rng: inout SeededRNG) -> [MIDIEvent] {
        guard !voicing.isEmpty else { return [] }
        var steps: [Int]
        if forceSparse {
            steps = [0, 6]
        } else if clave {
            steps = bar % 2 == 0 ? [0, 6, 12] : [4, 10, 14]
        } else {
            steps = [0, 6, 12]
            let secondary = [4, 9, 10, 14]
            steps.append(secondary[rng.nextInt(upperBound: secondary.count)])
            steps = Array(Set(steps)).sorted()
        }
        // 2–3 notes per stab, measured at 2.1–2.5. Two-note stabs keep the top of the voicing,
        // which is where the 7th and 9th sit once buildVoicing has voiced it rootless.
        let sorted = voicing.sorted()
        var events: [MIDIEvent] = []
        for (i, step) in steps.enumerated() {
            let notes = (sorted.count > 2 && rng.nextDouble() < 0.5) ? Array(sorted.suffix(2)) : sorted
            let next  = i + 1 < steps.count ? steps[i + 1] : 16
            let dur   = Swift.max(1, Swift.min(2 + rng.nextInt(upperBound: 2), next - step))
            let vel   = UInt8((step == 0 ? 56 : 48) + rng.nextInt(upperBound: 7))
            for n in notes {
                events.append(MIDIEvent(stepIndex: base + step, note: UInt8(n), velocity: vel,
                                        durationSteps: dur))
            }
        }
        return events
    }

    // MARK: - CHL-RHY-008: Single-Note Line (Chill Soho)

    /// CHL-RHY-008 Single-Note Line. Measured from Avalon (8.6 notes a bar, every step), More Than
    /// This (4.6–5.4, weighted to 0, 6, 10, 12) and Do It Again: a CONTINUOUS line, strictly
    /// monophonic, 4.5–9 notes a bar, very short notes, low velocity. Being monophonic is what
    /// separates it from the comp — not where it lands. The first draft confined it to offbeats;
    /// the measurement corrected that.
    ///
    /// Moves along a ladder of chord tones inside one octave, so each step is a third or a
    /// fourth — "narrow range, mostly thirds and fourths apart". forceSparse plays quarter notes.
    static func singleNoteLine(base: Int, chord: ChordWindow?, bar: Int,
                                       forceSparse: Bool, rng: inout SeededRNG) -> [MIDIEvent] {
        guard let chord else { return [] }
        // Ordered range, so Set iteration order never reaches a pitch choice.
        let ladder = (60...72).filter { chord.chordTones.contains($0 % 12) }
        guard !ladder.isEmpty else { return [] }

        var steps: [Int]
        if forceSparse {
            steps = [0, 4, 8, 12]
        } else {
            // Steady eighths with one to three left out, and now and then a sixteenth pickup —
            // 5 to 8 notes, inside the measured 4.5–9.
            steps = Array(stride(from: 0, to: 16, by: 2))
            for _ in 0..<(1 + rng.nextInt(upperBound: 3)) where steps.count > 5 {
                steps.remove(at: 1 + rng.nextInt(upperBound: steps.count - 1))   // never the downbeat
            }
            if rng.nextDouble() < 0.30 { steps.append(15) }
            steps.sort()
        }

        var idx = ladder.count / 2
        var events: [MIDIEvent] = []
        for (i, step) in steps.enumerated() {
            if i > 0 {
                let move = rng.nextDouble() < 0.5 ? 1 : -1
                var nextIdx = idx + move
                if nextIdx < 0 || nextIdx >= ladder.count { nextIdx = idx - move }   // reflect
                idx = Swift.max(0, Swift.min(ladder.count - 1, nextIdx))
            }
            let next = i + 1 < steps.count ? steps[i + 1] : 16
            let dur  = Swift.max(1, Swift.min(1 + rng.nextInt(upperBound: 2), next - step))
            events.append(MIDIEvent(stepIndex: base + step, note: UInt8(ladder[idx]),
                                    velocity: UInt8(42 + rng.nextInt(upperBound: 12)),
                                    durationSteps: dur))
        }
        return events
    }

    // MARK: - CHL-RHY-009: Root-and-Chord Eighths (Chill Soho)

    /// CHL-RHY-009 Root-and-Chord Eighths. Measured from the Do It Again piano and the guitars of
    /// Each and Every One and Missing: one hand holds a low root while the other answers with
    /// small chords, between them filling every eighth except the "and" of 1, so the downbeat
    /// rings. The root sounds on beat 1 and its octave on the "and" of 2 and on beat 4; 2–3 note
    /// chord fragments fall on beat 2, the "and" of 3, the "and" of 4 and sometimes beat 3.
    ///
    /// Variation, so the figure is never identical for a whole song:
    /// - three variants rotate every 8–12 bars, as measured in Do It Again (36% / 22% / 17%):
    ///   all of it; without beat 3; without beat 3 and the "and" of 4
    /// - the chord fragment changes shape on every hit — Do It Again never repeats one twice in
    ///   a row — and alternate bars start on the other shape
    /// - forceSparse (the sparse stretches) keeps only the root and two fragments
    ///
    /// The low root sits at MIDI 48–59, above the bass track's register, so the two don't collide.
    static func rootAndChordEighths(base: Int, frame: GlobalMusicalFrame, chord: ChordWindow?,
                                    voicing: [Int], bar: Int, variant: Int,
                                    forceSparse: Bool, rng: inout SeededRNG) -> [MIDIEvent] {
        guard let chord, voicing.count >= 2 else { return [] }
        let rootPC = (frame.keySemitoneValue + degreeSemitone(chord.chordRoot)) % 12
        guard let low = (48...59).first(where: { $0 % 12 == rootPC }) else { return [] }

        // Two fragment shapes from the rootless voicing: its top two notes, and its lower two
        // (or lower three when there are four or more), lifted clear of the root's octave.
        let sorted = voicing.sorted().map { $0 <= low + 12 ? $0 + 12 : $0 }.sorted()
        let shapes = [Array(sorted.suffix(2)), Array(sorted.prefix(sorted.count >= 4 ? 3 : 2))]

        let rootSteps: [Int]
        let chordSteps: [Int]
        if forceSparse {
            rootSteps = [0]; chordSteps = [4, 10]
        } else {
            rootSteps = [0, 6, 12]
            switch variant {
            case 1:  chordSteps = [4, 10, 14]
            case 2:  chordSteps = [4, 10]
            default: chordSteps = [4, 8, 10, 14]
            }
        }

        var events: [MIDIEvent] = []
        for step in rootSteps {
            let note = step == 0 ? low : low + 12
            let dur  = step == 0 ? (forceSparse ? 8 : 6) : 4
            let vel  = UInt8((step == 0 ? 56 : 50) + rng.nextInt(upperBound: 8))
            events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note), velocity: vel, durationSteps: dur))
        }
        var shape = bar % 2
        for step in chordSteps {
            let vel = UInt8((step == 4 ? 50 : 46) + rng.nextInt(upperBound: 8))
            for n in shapes[shape] {
                events.append(MIDIEvent(stepIndex: base + step, note: UInt8(n), velocity: vel,
                                        durationSteps: 2))
            }
            shape = 1 - shape
        }
        return events
    }

    // MARK: - CHL-RHY-001: St Germain Syncopated

    /// Beat 1 + syncopated second hit per bar. After 16 bars:
    /// second hit slides from AND-of-2 (step 6) to AND-of-3 (step 10) every 16 bars;
    /// every 4th bar becomes a single-hit bar (beat 1 only) for breathing room.
    /// forceSparse: reuses that same single-hit shape for every bar (sparse-fragment mechanic).
    private static func stGermainSyncopated(base: Int, voicing: [Int],
                                             bar: Int, sectionStart: Int,
                                             forceSparse: Bool = false,
                                             rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        let barInSection = bar - sectionStart
        let period16     = barInSection / 16

        // Variation 2: second-hit position shifts every 16 bars.
        // Period 0, 2, 4… → AND of beat 2 (step 6, original).
        // Period 1, 3, 5… → AND of beat 3 (step 10, one beat later).
        let secondHitStep = period16 % 2 == 0 ? 6 : 10

        // Variation 3: sparse single-hit bar every 4 bars, starting from bar 16 of section.
        // Sparse bars also use shell voicing [3rd, 7th] — drop the 5th for a lighter touch.
        let isSparseBar   = forceSparse || (period16 >= 1 && barInSection % 4 == 3)
        let activeVoicing = isSparseBar && voicing.count >= 3
            ? [voicing[0], voicing[voicing.count - 1]]
            : voicing

        // Beat 1 downbeat: always present
        let vel1 = UInt8(75 + rng.nextInt(upperBound: 11))
        for note in activeVoicing {
            events.append(MIDIEvent(stepIndex: base + 0, note: UInt8(note), velocity: vel1, durationSteps: 5))
        }

        if !isSparseBar {
            // Second syncopated hit
            let vel2 = UInt8(70 + rng.nextInt(upperBound: 11))
            for note in voicing {
                events.append(MIDIEvent(stepIndex: base + secondHitStep, note: UInt8(note),
                                        velocity: vel2, durationSteps: 5))
            }
            // Occasional fill at AND of beat 3 or beat 4 (skip if second hit is already at step 10)
            if rng.nextDouble() < 0.30 {
                let fillStep = secondHitStep == 6
                    ? (rng.nextDouble() < 0.50 ? 10 : 14)
                    : 14   // period 1: second hit is at 10, so fill can only go to 14
                let vel3 = UInt8(55 + rng.nextInt(upperBound: 11))
                for note in voicing {
                    events.append(MIDIEvent(stepIndex: base + fillStep, note: UInt8(note),
                                            velocity: vel3, durationSteps: 3))
                }
            }
        }
        return events
    }

    // MARK: - CHL-RHY-002: Moby Backbeat

    /// Chord strikes on beats 2 and 4, with bar-by-bar variation so no 8 bars sound identical.
    ///
    /// Four patterns cycle every 4 bars (bar % 4), giving each 4-bar phrase a distinct texture:
    ///   0 — standard shell: beats 2+4, 2-note shell voicing
    ///   1 — add AND-of-3: beats 2+4 shell + soft ghost hit at step 10 (AND of beat 3)
    ///   2 — inversion: beats 2+4, full 3-note voicing in second inversion (top note dropped)
    ///   3 — shifted beat 2: beat 2 anticipates to step 2 (AND of beat 1); beat 4 normal
    ///
    /// Additionally, 15% chance either beat fires alone (unchanged), and a 20% chance of
    /// an extra staccato fill on step 6 (AND of beat 2) at very low velocity — subtle syncopation.
    ///
    /// halfTime (sparse-fragment mechanic): drops the beat-2/beat-4 pattern entirely for a single
    /// shell-voicing hit on beat 3 — half the harmonic rhythm, no variant cycling or embellishment.
    private static func mobyBackbeat(base: Int, voicing: [Int], bar: Int,
                                      halfTime: Bool = false,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard !voicing.isEmpty else { return events }

        if halfTime {
            let shellVoicing = voicing.count >= 2 ? Array(voicing.prefix(2)) : voicing
            let vel = UInt8(60 + rng.nextInt(upperBound: 11))
            for note in shellVoicing {
                events.append(MIDIEvent(stepIndex: base + 8, note: UInt8(note),
                                        velocity: vel, durationSteps: 6))
            }
            return events
        }

        let onlyBeat2 = rng.nextDouble() < 0.15
        let onlyBeat4 = !onlyBeat2 && rng.nextDouble() < 0.15

        // Pattern variant driven by bar position — changes every 4 bars
        let variant = bar % 4

        // Voicing selection by variant
        let shellVoicing   = voicing.count >= 2 ? Array(voicing.prefix(2)) : voicing
        let fullVoicing    = voicing
        // Second inversion: rotate so highest note comes first (drop it down one octave conceptually —
        // achieved here by reversing the sorted list to put the upper note first, giving a different
        // density feel when sustained notes overlap)
        let invertVoicing  = voicing.count >= 3 ? Array(voicing.dropFirst()) : shellVoicing

        let beat2Voicing: [Int]
        let beat4Voicing: [Int]
        let beat2Step: Int
        let beat4Step: Int = 12

        switch variant {
        case 1:
            // Add AND-of-3 ghost hit (step 10) at low velocity
            beat2Voicing = shellVoicing
            beat4Voicing = shellVoicing
            beat2Step    = 4
        case 2:
            // Full inversion on both beats — different density
            beat2Voicing = invertVoicing
            beat4Voicing = fullVoicing
            beat2Step    = 4
        case 3:
            // Anticipate beat 2 to AND of beat 1 (step 2) — creates forward lean
            beat2Voicing = shellVoicing
            beat4Voicing = shellVoicing
            beat2Step    = 2
        default:
            // Variant 0: standard shell
            beat2Voicing = shellVoicing
            beat4Voicing = shellVoicing
            beat2Step    = 4
        }

        if !onlyBeat4 {
            let vel = UInt8(65 + rng.nextInt(upperBound: 11))
            for note in beat2Voicing {
                events.append(MIDIEvent(stepIndex: base + beat2Step, note: UInt8(note),
                                        velocity: vel, durationSteps: 5))
            }
        }
        if !onlyBeat2 {
            let vel = UInt8(60 + rng.nextInt(upperBound: 11))
            for note in beat4Voicing {
                events.append(MIDIEvent(stepIndex: base + beat4Step, note: UInt8(note),
                                        velocity: vel, durationSteps: 4))
            }
        }

        // Variant 1: AND-of-3 ghost hit at step 10 (very soft)
        if variant == 1 && !onlyBeat2 && !onlyBeat4 {
            let ghostVel = UInt8(40 + rng.nextInt(upperBound: 10))
            for note in shellVoicing {
                events.append(MIDIEvent(stepIndex: base + 10, note: UInt8(note),
                                        velocity: ghostVel, durationSteps: 2))
            }
        }

        // 20% chance: extra syncopated fill at step 6 (AND of beat 2), very quiet
        if rng.nextDouble() < 0.20 && !onlyBeat2 && !onlyBeat4 {
            let fillVel = UInt8(38 + rng.nextInt(upperBound: 10))
            let fillNote = shellVoicing.first ?? voicing[0]
            events.append(MIDIEvent(stepIndex: base + 6, note: UInt8(fillNote),
                                    velocity: fillVel, durationSteps: 2))
        }

        return events
    }

    // MARK: - CHL-RHY-003: Bosa Moon Arpeggiated

    /// Chord tones played sequentially on 8th-note grid (~10 notes/bar) for the first half of an
    /// 8-bar micro-form; the second half thins out (see below). 30–40% chance of block chord on
    /// step 0 or step 8 during the dense half. Direction flips every 16 bars (cosmetic — same
    /// density, different color).
    ///
    /// 8-bar micro-form (2026 simplification): previously this mode was dense on literally every
    /// bar, with a footnote "sparse every 4th bar" exception that didn't even begin until bar 16
    /// of the section — meaning the first 16 bars of any section had zero built-in relief.
    /// Replaced with real structure, active from bar 1: bars 1-4 of every 8-bar cycle play the
    /// full dense arpeggio; bars 5-8 thin out, each bar independently choosing between a
    /// half-density arpeggio (same up/down movement, quarter-note grid — 4 notes/bar instead of
    /// 8) or the genuinely-sparse single-hit shape, for a mix of "still moving, just thinner" and
    /// real stillness.
    /// forceSparse: always the genuinely-sparse shape, skipping the half-density option — the
    /// sparse-fragment mechanic wants a plain, predictable rendering, not extra variety.
    private static func bosaMoonArpeggiated(base: Int, voicing: [Int],
                                             frame: GlobalMusicalFrame,
                                             chord: ChordWindow?,
                                             bar: Int,
                                             sectionStart: Int,
                                             forceSparse: Bool = false,
                                             rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard !voicing.isEmpty else { return events }

        let barInSection = bar - sectionStart
        let period16     = barInSection / 16   // increments every 16 bars within the section

        // Direction flip every 16 bars (cosmetic).
        // Period 0, 2, 4… → ascending then descending (original feel).
        // Period 1, 3, 5… → descending then ascending (mirror feel).
        let arpPool = period16 % 2 == 0
            ? voicing + voicing.reversed()
            : voicing.reversed() + voicing

        let isSecondHalf = (barInSection % 8) >= 4
        if forceSparse || isSecondHalf {
            if !forceSparse && rng.nextDouble() < 0.50 {
                // Half-density arpeggio: same movement, quarter-note grid (4 notes/bar).
                for (i, step) in stride(from: 0, to: 16, by: 4).enumerated() {
                    let note = arpPool[i % arpPool.count]
                    let vel  = UInt8(65 + rng.nextInt(upperBound: 14))
                    events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note), velocity: vel, durationSteps: 5))
                }
                return events
            }
            // Genuinely sparse: single beat-1 hit, half-bar duration, shell voicing [3rd, 7th].
            let shellVoicing = voicing.count >= 3
                ? [voicing[0], voicing[voicing.count - 1]]
                : voicing
            let vel = UInt8(60 + rng.nextInt(upperBound: 12))
            for note in shellVoicing {
                events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: vel, durationSteps: 8))
            }
            return events
        }

        // Dense bar (first half of the 8-bar cycle): 8th-note grid, steps 0, 2, 4, ..., 14
        for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
            let note = arpPool[i % arpPool.count]
            let vel  = UInt8(70 + rng.nextInt(upperBound: 16))
            events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note), velocity: vel, durationSteps: 3))
        }

        // Block chord accent on step 0 or step 8 (30–40% chance)
        if rng.nextDouble() < 0.35 {
            let accentStep = rng.nextDouble() < 0.50 ? 0 : 8
            let accentVel = UInt8(80 + rng.nextInt(upperBound: 16))
            for note in voicing {
                events.append(MIDIEvent(stepIndex: base + accentStep, note: UInt8(note),
                                        velocity: accentVel, durationSteps: 4))
            }
        }
        return events
    }

    // MARK: - CHL-RHY-004: Acid Jazz Stab Groove

    /// CHL-RHY-004: Four syncopated dyad stabs per bar in a repeating cell, derived from
    /// the measured Cantaloop keyboard groove. Stabs land on AND positions — off the beat —
    /// never on beat 1. Voicing is a 2-note dyad (top two notes: 5th + 7th), close position.
    /// Staccato: each stab is 2 steps. Velocity ~55–70 (lighter feel for Chill mix).
    /// Every 4 bars, one "sparse bar" fires only 2 stabs for breathing room.
    /// Target density: ~8 note events/bar (4 stabs × 2 notes); sparse bar ~4 events/bar.
    private static func acidJazzStab(base: Int, voicing: [Int], bar: Int,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard voicing.count >= 2 else { return events }

        // 2-note dyad: top two notes of voicing (5th + 7th) — upper shell, root omitted
        let dyad = Array(voicing.suffix(2))

        // Sparse bar every 4 bars — only 2 stabs (breathing room)
        let isSparseBar = (bar % 4 == 3)

        let stabPositions: [Int]
        if isSparseBar {
            // Two stabs: AND of beat 1, AND of beat 4
            stabPositions = [2, 14]
        } else {
            // Four stabs: AND of 1, AND of 2, beat 3, AND of 4 — syncopated but not every 16th
            stabPositions = [2, 6, 8, 14]
        }

        for step in stabPositions {
            let vel = UInt8(55 + rng.nextInt(upperBound: 16))
            for note in dyad {
                events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note),
                                        velocity: vel, durationSteps: 2))
            }
        }
        return events
    }

    // MARK: - CHL-RHY-005: Chord Hold

    /// CHL-RHY-005: The sparsest comping mode — one held chord per bar, full voicing, soft
    /// velocity, with a couple of steps of silence at the tail so it doesn't run straight into
    /// the next bar's attack.
    ///
    /// Variation (2026) — true sub-step swing timing isn't implemented anywhere in the engine
    /// (`swingFeel` has been a documented no-op since the original Chill design), so "swing" here
    /// means musical variety, not swung-8th timing:
    ///   - 20% of bars: syncopated entry on the AND of beat 1 (step 2) instead of beat 1 — a
    ///     laid-back push, same idiom St Germain's own comping uses (beat 1 / AND of beat 2).
    ///   - Every 4th bar (phrase-end position): ~35% chance of dropping the hold entirely for a
    ///     breath, else ~26% chance of a short staccato punctuation instead of the long hold.
    ///   - Occasional (20%) very soft single-note re-touch at beat 3, unchanged from before.
    /// forceSparse: alternates hit-bar/rest-bar (bar % 2) for a genuine 2-bar hold, bypassing all
    /// of the above — the sparse-fragment mechanic wants a plain, predictable 2-bar hold.
    private static func chordHold(base: Int, voicing: [Int], bar: Int,
                                   forceSparse: Bool = false,
                                   rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard !voicing.isEmpty else { return events }

        if forceSparse {
            if bar % 2 == 1 { return events }
            let dur = 12 + rng.nextInt(upperBound: 3)
            let vel = UInt8(50 + rng.nextInt(upperBound: 12))
            for note in voicing {
                events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: vel, durationSteps: dur))
            }
            return events
        }

        let phraseEnd = bar % 4 == 3
        if phraseEnd && rng.nextDouble() < 0.35 { return events }   // breathing gap

        let staccato = phraseEnd && rng.nextDouble() < 0.40
        let syncopated = !staccato && rng.nextDouble() < 0.20
        let step = syncopated ? 2 : 0
        let dur: Int = staccato ? (3 + rng.nextInt(upperBound: 2)) : (12 + rng.nextInt(upperBound: 3))
        let vel = UInt8((staccato ? 58 : 50) + rng.nextInt(upperBound: 12))
        for note in voicing {
            events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note), velocity: vel, durationSteps: dur))
        }
        if !staccato && rng.nextDouble() < 0.20 {
            let touchVel = UInt8(38 + rng.nextInt(upperBound: 10))
            events.append(MIDIEvent(stepIndex: base + 8, note: UInt8(voicing[0]),
                                    velocity: touchVel, durationSteps: 4))
        }
        return events
    }

    // MARK: - CHL-RHY-006: Downbeat Pulse

    /// CHL-RHY-006: A notch busier than Chord Hold — plain, unsyncopated chord on beats 1 and 3,
    /// shell voicing. No variant cycling like Moby Backbeat, but not perfectly static either:
    ///   - 25% of bars: staccato punch (short durations) instead of the sustained shell chord.
    ///   - 20% of bars: beat 3 pushes early to the AND of beat 2 (step 6) — a laid-back lean,
    ///     same idiom as Chord Hold's syncopated entry.
    ///   - 15% of bars: beat 3 drops entirely for a breath (independent of forceSparse below).
    /// forceSparse: drops beat 3 unconditionally, leaving only the beat-1 hit (true half-time) —
    /// the sparse-fragment mechanic wants a plain, predictable half-time, not extra variation.
    private static func downbeatPulse(base: Int, voicing: [Int], bar: Int,
                                       forceSparse: Bool = false,
                                       rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        guard !voicing.isEmpty else { return events }

        let shellVoicing = voicing.count >= 2 ? Array(voicing.prefix(2)) : voicing
        let staccato = !forceSparse && rng.nextDouble() < 0.25
        let dur = staccato ? (3 + rng.nextInt(upperBound: 2)) : 7
        let vel1 = UInt8((staccato ? 70 : 65) + rng.nextInt(upperBound: 10))
        for note in shellVoicing {
            events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: vel1, durationSteps: dur))
        }

        if forceSparse { return events }
        if rng.nextDouble() < 0.15 { return events }   // occasional dropped beat 3 — a breath

        let pushed = rng.nextDouble() < 0.20   // AND of beat 2 instead of beat 3 — a laid-back lean
        let beat3Step = pushed ? 6 : 8
        let vel2 = UInt8((staccato ? 65 : 60) + rng.nextInt(upperBound: 10))
        for note in shellVoicing {
            events.append(MIDIEvent(stepIndex: base + beat3Step, note: UInt8(note), velocity: vel2, durationSteps: dur))
        }
        return events
    }

    // MARK: - Voicing helper

    /// Upper-structure voicing: [3rd, 5th, 7th] in mid register MIDI 48–72.
    /// Root omitted — bass covers it (CHL-SYNC-004).
    /// All notes snapped to scale (CHL-SYNC-001).
    private static func buildVoicing(frame: GlobalMusicalFrame, chord: ChordWindow?,
                                      baseRegister: Int, snapTable: [Int]) -> [Int] {
        let chordRoot  = chord?.chordRoot ?? "1"
        let chordType  = chord?.chordType ?? .min7
        let chordRootPC = (frame.keySemitoneValue + degreeSemitone(chordRoot)) % 12

        let intervals: [Int]
        switch chordType {
        case .min7:   intervals = [3, 7, 10]
        case .major:  intervals = [4, 7, 11]
        case .dom7:   intervals = [4, 7, 10]
        case .sus4:   intervals = [5, 7, 10]
        // Extended types (Chill Soho). Without these the `default` below voiced every one of
        // them as a MINOR seventh — so add9, maj7 and maj9 chords played minor. Rootless where
        // there is a ninth: the bass has the root, and CHL-RHY-007 specifies rootless voicings.
        case .add9:   intervals = [4, 7, 14]    // 3 5 9
        case .maj7:   intervals = [4, 7, 11]    // 3 5 7
        case .maj9:   intervals = [4, 11, 14]   // 3 7 9
        case .min9:   intervals = [3, 10, 14]   // b3 b7 9
        case .maj6:   intervals = [4, 7, 9]     // 3 5 6
        case .min6:   intervals = [3, 7, 9]     // b3 5 6
        case .dom9:   intervals = [4, 10, 14]   // 3 b7 9
        case .min7b5: intervals = [3, 6, 10]    // b3 b5 b7
        default:      intervals = [3, 7, 10]
        }

        var notes: [Int] = []
        for interval in intervals {
            let pc = snapTable[(chordRootPC + interval) % 12]
            // Close-position voicing: all three notes in the same register.
            // Previously the 7th was offset +12, creating a 15-semitone open spread that
            // sounded harsh on clavinet. One octave of space is all we need here.
            let target = baseRegister
            let targetPC = target % 12
            let semisUp = (pc - targetPC + 12) % 12
            var note = target + semisUp
            while note < 48 { note -= 12 }
            while note > 72 { note -= 12 }
            notes.append(note)
        }
        return notes
    }
}
