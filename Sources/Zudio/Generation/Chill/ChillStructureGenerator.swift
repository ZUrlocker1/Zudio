// ChillStructureGenerator.swift — Chill generation step 2
// Copyright (c) 2026 Zack Urlocker
// Song form: INTRO → GROOVE-A → BREAKDOWN → GROOVE-B → OUTRO (default)
// Simple form: INTRO → BODY → OUTRO (30% of Deep/Dream songs)
// Chord plan derived from ChillProgressionFamily (CHL-SYNC-002/003/010/013).

import Foundation

struct ChillStructureGenerator {

    // MARK: - Chill section labels (mapped onto existing SectionLabel)
    // intro   = intro
    // grooveA = .A
    // breakdown = .bridge  (reusing bridge label — lowest intensity, sparse)
    // grooveB = .B
    // outro   = .outro

    static func generate(
        frame: GlobalMusicalFrame,
        chillProgFamily: ChillProgressionFamily,
        mood: Mood,
        breakdownStyle: ChillBreakdownStyle = .bassOstinato,
        noBreakdown: Bool = false,
        sohoVariation: Bool = false,
        motionSeed: UInt64,
        rng: inout SeededRNG
    ) -> SongStructure {
        generateWithChordMotion(frame: frame, chillProgFamily: chillProgFamily, mood: mood,
                                breakdownStyle: breakdownStyle, noBreakdown: noBreakdown,
                                sohoVariation: sohoVariation, motionSeed: motionSeed, rng: &rng).structure
    }

    /// As `generate`, plus a short description of the base Chill chord motion (the B section's
    /// pendulum and the phrase-end turnaround) for the log's Chords line, or nil when there is none,
    /// and the first bar of each phrase-end turnaround for the performance log.
    ///
    /// `motionSeed` feeds a derived stream for every 3.0 chord-motion draw, so the main stream
    /// consumes exactly what it did before: Chill Soho and Chill Blues, which replace this chord
    /// plan, and every later main-stream decision in base Chill are unchanged.
    static func generateWithChordMotion(
        frame: GlobalMusicalFrame,
        chillProgFamily: ChillProgressionFamily,
        mood: Mood,
        breakdownStyle: ChillBreakdownStyle = .bassOstinato,
        noBreakdown: Bool = false,
        sohoVariation: Bool = false,
        motionSeed: UInt64,
        rng: inout SeededRNG
    ) -> (structure: SongStructure, chordMotion: String?, turnaroundBars: [Int]) {
        let (sections, introStyle, outroStyle): ([SongSection], IntroStyle, OutroStyle)
        if noBreakdown {
            (sections, introStyle, outroStyle) = buildNoBreakdownSections(frame: frame, rng: &rng)
        } else {
            let useSimpleForm = (mood == .Deep || mood == .Dream) && rng.nextDouble() < 0.30
            (sections, introStyle, outroStyle) = useSimpleForm
                ? buildSimpleSections(frame: frame, soho: sohoVariation, rng: &rng)
                : buildFullSections(frame: frame, breakdownStyle: breakdownStyle,
                                    soho: sohoVariation, rng: &rng)
        }
        var motionRNG = SeededRNG(seed: motionSeed)
        let (chordPlan, motion, turnBars) = buildChordPlan(frame: frame, sections: sections,
                                                           family: chillProgFamily, rng: &rng,
                                                           motionRNG: &motionRNG)
        return (SongStructure(sections: sections, chordPlan: chordPlan,
                              introStyle: introStyle, outroStyle: outroStyle), motion, turnBars)
    }

    // MARK: - Section builders

    /// INTRO / GROOVE-A / BREAKDOWN / GROOVE-B / OUTRO
    private static func buildFullSections(frame: GlobalMusicalFrame,
                                           breakdownStyle: ChillBreakdownStyle = .bassOstinato,
                                           soho: Bool = false,
                                           rng: inout SeededRNG) -> ([SongSection], IntroStyle, OutroStyle) {
        let total = frame.totalBars
        // Section lengths drawn from plan ranges, all multiple of 4.
        // Breakdown length is style-dependent: bass ostinato is the most minimal breakdown
        // and should be short (4 bars); other styles allow 4–8 bars.
        let introBars     = sohoIntroBars(soho: soho, rng: &rng)
        let outroBars     = roundTo4(ChillMusicalFrameGenerator.triangularInt(min: 4,  peak: 6,  max: 8,  rng: &rng))
        let breakdownBars: Int
        switch breakdownStyle {
        case .bassOstinato:
            // Short: always 4 bars (bass alone is sparse; longer is boring)
            breakdownBars = 4
        case .stopTime:
            // Mostly 4 bars; occasionally 6 (pairs of bars: hit + response)
            breakdownBars = rng.nextDouble() < 0.75 ? 4 : 6
        case .harmonicDrone:
            // Always 4 bars: absence-then-reentry arc needs exactly 4 bars to breathe
            breakdownBars = 4
        case .groovePocket:
            // 4 or 8 bars — 8 gives more room for fill escalation
            breakdownBars = rng.nextDouble() < 0.50 ? 4 : 8
        case .sohoRemix:
            // Chill Soho Remix Break. 12 or 16 bars read as one fixed length by ear, so the break
            // is now 6, 8 or 12 (Zack, 2026-10-11) — a short one is a lift, a long one a section.
            breakdownBars = [6, 8, 12][rng.weightedPick([0.30, 0.40, 0.30])]
        case .sohoDuo:
            // Chill Soho Duo. Longer than bass ostinato's four: two players trading takes time to
            // establish, and at two bars a chord eight bars is only four changes.
            breakdownBars = rng.nextDouble() < 0.70 ? 8 : 12
        }
        let grooveTotal   = Swift.max(20, total - introBars - outroBars - breakdownBars)
        // Split groove total across A and B; B slightly longer (more active)
        let grooveA = roundTo4(Int(Double(grooveTotal) * 0.45))
        let grooveB = grooveTotal - grooveA

        var sections: [SongSection] = []
        var cursor = 0

        if introBars > 0 {
            sections.append(SongSection(startBar: cursor, lengthBars: introBars,
                                        label: .intro, intensity: .low, mode: frame.mode))
            cursor += introBars
        }

        sections.append(SongSection(startBar: cursor, lengthBars: grooveA,
                                    label: .A, intensity: .medium, mode: frame.mode))
        cursor += grooveA

        // Breakdown maps to .bridge (both are sparse/stripped)
        sections.append(SongSection(startBar: cursor, lengthBars: breakdownBars,
                                    label: .bridge, intensity: .low, mode: frame.mode))
        cursor += breakdownBars

        sections.append(SongSection(startBar: cursor, lengthBars: grooveB,
                                    label: .B, intensity: .high, mode: frame.mode))
        cursor += grooveB

        sections.append(SongSection(startBar: cursor, lengthBars: outroBars,
                                    label: .outro, intensity: .low, mode: frame.mode))

        let useColdStyle = rng.nextDouble() < 0.50
        let introStyle: IntroStyle = useColdStyle ? .coldStart(drumsOnly: true) : .alreadyPlaying
        let outroStyle: OutroStyle = useColdStyle ? .coldStop : .fade
        return (sections, introStyle, outroStyle)
    }

    /// Blues form: INTRO / GROOVE-A / GROOVE-B / OUTRO (no breakdown, preserves A+B duality for drum routing)
    private static func buildNoBreakdownSections(frame: GlobalMusicalFrame,
                                                  rng: inout SeededRNG) -> ([SongSection], IntroStyle, OutroStyle) {
        let total = frame.totalBars
        // Blues intro: 50% chance of 0 bars (jump straight into the form), 50% chance of 4 bars.
        // Lead solo must kick off within 4 bars of the A section — short intro enforces this.
        let introBars = rng.nextDouble() < 0.50 ? 0 : 4
        // Blues coldStop outro is exactly 2 bars: beat 0 of bar 0 is the crash+kick+bass+rhythm
        // landing; bar 1 is silence. This makes the cold stop land on beat 1 of the bar immediately
        // after the turnaround, merging with the turnaround's spill kick for a definitive ending.
        let outroBars  = 2
        let groovePool = total - introBars - outroBars
        // grooveTotal: largest multiple of 16 that fits, minimum 32.
        let grooveTotal = Swift.max(32, (groovePool / 16) * 16)
        // Surplus (0–15 bars that don't fill a complete 16-bar cycle) goes into grooveB as extra
        // Im7 bars before the outro. This keeps introBars at exactly 0 or 4 and outroBars at 2.
        let surplus = groovePool - grooveTotal
        // Split grooveTotal: A ≈ 45%, B ≈ 55%, both multiples of 16, minimum 16 each.
        let grooveA_target = Int(Double(grooveTotal) * 0.45)
        let grooveA = Swift.max(16, Swift.min(grooveTotal - 16, ((grooveA_target + 8) / 16) * 16))
        let grooveB = grooveTotal - grooveA + surplus

        var sections: [SongSection] = []
        var cursor = 0
        if introBars > 0 {
            sections.append(SongSection(startBar: cursor, lengthBars: introBars, label: .intro, intensity: .low, mode: frame.mode))
            cursor += introBars
        }
        sections.append(SongSection(startBar: cursor, lengthBars: grooveA,   label: .A,     intensity: .medium, mode: frame.mode))
        cursor += grooveA
        sections.append(SongSection(startBar: cursor, lengthBars: grooveB,   label: .B,     intensity: .high,   mode: frame.mode))
        cursor += grooveB
        sections.append(SongSection(startBar: cursor, lengthBars: outroBars, label: .outro,  intensity: .low,    mode: frame.mode))

        // Blues: always coldStart(drumsOnly: false) — drums pickup on bar 0, bass and
        // keyboard build in during the intro. drumsOnly=false signals generators to play
        // bass/keyboard during the intro rather than staying silent.
        // Always coldStop: blues genre ends with a definitive landing, never a fade.
        let introStyle: IntroStyle = .coldStart(drumsOnly: false)
        let outroStyle: OutroStyle = .coldStop
        return (sections, introStyle, outroStyle)
    }

    /// Simple form: INTRO / BODY / OUTRO (no breakdown)
    private static func buildSimpleSections(frame: GlobalMusicalFrame, soho: Bool = false,
                                             rng: inout SeededRNG) -> ([SongSection], IntroStyle, OutroStyle) {
        let total = frame.totalBars
        let introBars = sohoIntroBars(soho: soho, rng: &rng)
        let outroBars = roundTo4(ChillMusicalFrameGenerator.triangularInt(min: 4, peak: 6, max: 8, rng: &rng))
        let bodyBars  = Swift.max(16, total - introBars - outroBars)

        let useColdStyle = rng.nextDouble() < 0.50
        let introStyle: IntroStyle = useColdStyle ? .coldStart(drumsOnly: true) : .alreadyPlaying
        let outroStyle: OutroStyle = useColdStyle ? .coldStop : .fade
        var sections: [SongSection] = []
        if introBars > 0 {
            sections.append(SongSection(startBar: 0, lengthBars: introBars, label: .intro,
                                        intensity: .low, mode: frame.mode))
        }
        sections.append(SongSection(startBar: introBars, lengthBars: bodyBars, label: .A,
                                    intensity: .medium, mode: frame.mode))
        sections.append(SongSection(startBar: introBars + bodyBars, lengthBars: outroBars,
                                    label: .outro, intensity: .low, mode: frame.mode))
        return (sections, introStyle, outroStyle)
    }

    /// Intro length. Base Chill draws 4 or 8 bars; **Chill Soho is 4, or occasionally none at
    /// all**. An eight-bar intro of percussion and one bass note a bar is the least musical thing
    /// the substyle does — Zack heard one on *Thunder in the Side Street* (2026-10-12) — and a
    /// fair number of these records simply start on the groove. The draw count is the same either
    /// way, so base Chill is untouched.
    private static func sohoIntroBars(soho: Bool, rng: inout SeededRNG) -> Int {
        guard soho else {
            return roundTo4(ChillMusicalFrameGenerator.triangularInt(min: 4, peak: 6, max: 8, rng: &rng))
        }
        return rng.nextDouble() < 0.15 ? 0 : 4
    }

    // MARK: - Chord plan

    private static func buildChordPlan(frame: GlobalMusicalFrame,
                                        sections: [SongSection],
                                        family: ChillProgressionFamily,
                                        rng: inout SeededRNG,
                                        motionRNG: inout SeededRNG) -> ([ChordWindow], String?, [Int]) {
        var pendulum: (partner: BarChord, windowLen: Int)? = nil
        let familyWindows = buildFamilyChordPlan(frame: frame, sections: sections, family: family,
                                                 rng: &rng, pendulum: &pendulum)
        return applyChordMotion(frame: frame, sections: sections, family: family,
                                windows: familyWindows, pendulum: pendulum, rng: &motionRNG)
    }

    /// The family's own chord plan, as before 3.0. Every main-stream draw happens here and only
    /// here, in the same order as before. `pendulum` returns the two-chord pendulum's partner
    /// and window length, which the B-section motion builds on.
    private static func buildFamilyChordPlan(frame: GlobalMusicalFrame,
                                              sections: [SongSection],
                                              family: ChillProgressionFamily,
                                              rng: inout SeededRNG,
                                              pendulum: inout (partner: BarChord, windowLen: Int)?) -> [ChordWindow] {
        let key  = frame.key
        let mode = frame.mode
        let total = frame.totalBars

        // Breakdown section always uses tonic sus4 (CHL-SYNC-009 harmonic erasure)
        // Identify breakdown bar range if present
        let breakdownSection = sections.first { $0.label == .bridge }
        let breakdownStart   = breakdownSection?.startBar
        let breakdownEnd     = breakdownSection.map { $0.startBar + $0.lengthBars }

        let windows: [ChordWindow]
        switch family {

        case .static_groove:
            windows = buildStaticGroove(key: key, mode: mode, total: total,
                                        breakdownStart: breakdownStart, breakdownEnd: breakdownEnd)

        case .two_chord_pendulum:
            let built = buildTwoChordPendulum(frame: frame, sections: sections,
                                              breakdownStart: breakdownStart, breakdownEnd: breakdownEnd,
                                              rng: &rng)
            windows = built.windows
            pendulum = (built.partner, built.windowLen)

        case .minor_blues:
            windows = buildMinorBlues(frame: frame, sections: sections,
                                      breakdownStart: breakdownStart, breakdownEnd: breakdownEnd)

        case .modal_drift:
            windows = buildModalDrift(frame: frame, sections: sections,
                                      breakdownStart: breakdownStart, breakdownEnd: breakdownEnd,
                                      rng: &rng)
        }
        return windows
    }

    // MARK: - 3.0 chord motion (base Chill)

    typealias BarChord = (root: String, type: ChordType)

    /// Harmonic motion layered over the family plan (docs/chill-chords-plan.md, items 1 and 3).
    ///
    /// - **B section moves.** Static groove keeps the tonic vamp in A and makes B a pendulum of
    ///   the tonic and a partner, four bars each. Two-chord pendulum takes a different partner in
    ///   B than in A. Both restart on the tonic at every 16-bar phrase, so a turnaround resolves
    ///   home; intro and outro hold the tonic. Modal drift and minor blues keep their plans.
    /// - **Turnarounds.** The last two bars of each 16-bar phrase of a groove section (60% of
    ///   songs), or of each section only (40%), play a two-chord cadence in the mode, one bar
    ///   each, wherever the bar after is the tonic. Not in minor blues, which already cadences.
    /// - **Breakdowns lead back in.** The last bar of a four-bar breakdown, the last two of a
    ///   longer one, become a sus4 on the fifth above the chord the groove returns to: V7sus4
    ///   when it returns to the tonic. Pads and Rhythm already voice sus4 as 4, 5, b7, so the
    ///   window sounds as a 7sus4. If that chord would leave the mode, the tonic sus4 stays.
    ///
    /// Every chord used is diatonic: Pads and Rhythm snap chord notes to the scale, so a chord
    /// outside the mode would sound as some other chord.
    private static func applyChordMotion(frame: GlobalMusicalFrame, sections: [SongSection],
                                         family: ChillProgressionFamily, windows: [ChordWindow],
                                         pendulum familyPendulum: (partner: BarChord, windowLen: Int)?,
                                         rng: inout SeededRNG) -> ([ChordWindow], String?, [Int]) {
        let key = frame.key, mode = frame.mode, total = frame.totalBars
        let tonic: BarChord = tonicChord(mode: mode)

        // One chord per bar; a window that overruns the song is clipped.
        var bars = [BarChord](repeating: tonic, count: total)
        for w in windows {
            for b in Swift.max(0, w.startBar)..<Swift.min(total, w.endBar) {
                bars[b] = (w.chordRoot, w.chordType)
            }
        }

        // 16-bar phrases of a section; a remainder under 8 bars joins the phrase before it.
        func phrases(_ section: SongSection) -> [Range<Int>] {
            var out: [Range<Int>] = []
            var start = section.startBar
            while start < section.endBar {
                let end = section.endBar - start < 24 ? section.endBar : start + 16
                out.append(start..<end)
                start = end
            }
            return out
        }
        // Tonic and partner, `every` bars each, from the top of every phrase.
        func pendulum(_ phraseList: [Range<Int>], partner: BarChord, every: Int) {
            for phrase in phraseList {
                for b in phrase {
                    bars[b] = ((b - phrase.lowerBound) / every) % 2 == 0 ? tonic : partner
                }
            }
        }
        func pendulum(_ section: SongSection, partner: BarChord, every: Int) {
            pendulum(phrases(section), partner: partner, every: every)
        }

        var bLabel: String? = nil
        switch family {
        case .static_groove:
            let (_, _, r2, t2) = pickChordPair(mode: mode, rng: &rng)
            let partner: BarChord = (r2, t2)
            for section in sections where section.label == .B {
                pendulum(section, partner: partner, every: 4)
                bLabel = "B \(chordName(tonic)) – \(chordName(partner))"
            }
            // Simple form has no B section: the body's second half moves instead, from the
            // phrase nearest its middle, so no song is one chord from start to finish.
            if !sections.contains(where: { $0.label == .B }),
               let body = sections.first(where: { $0.label == .A }) {
                let list = phrases(body)
                if list.count >= 2 {
                    pendulum(Array(list[(list.count / 2)...]), partner: partner, every: 4)
                    bLabel = "second half \(chordName(tonic)) – \(chordName(partner))"
                }
            }
        case .two_chord_pendulum:
            // The A partner and window length are the ones the family plan already drew.
            guard let fp = familyPendulum else { break }
            let every = fp.windowLen
            let bPartner = pickOtherPartner(mode: mode, avoiding: fp.partner.root, rng: &rng)
            for section in sections {
                switch section.label {
                case .A:
                    pendulum(section, partner: fp.partner, every: every)
                case .B:
                    pendulum(section, partner: bPartner, every: every)
                    bLabel = "B \(chordName(tonic)) – \(chordName(bPartner))"
                case .intro, .outro:
                    for b in section.startBar..<Swift.min(total, section.endBar) { bars[b] = tonic }
                default:
                    break
                }
            }
        case .minor_blues, .modal_drift:
            break
        }

        // Turnarounds. Both draws are made for every family so the stream's use is uniform.
        let everyPhrase = rng.nextDouble() < 0.60
        let turn = turnaround(mode: mode, second: rng.nextDouble() < 0.50)
        var turnBars: [Int] = []   // first bar of each placed turnaround, for the performance log
        if family != .minor_blues {
            for section in sections where section.label == .A || section.label == .B {
                for phrase in phrases(section) {
                    let end = phrase.upperBound
                    guard phrase.count >= 8, everyPhrase || end == section.endBar else { continue }
                    // Only where the cadence resolves: the bar after must be on the tonic root.
                    guard end >= total || bars[end].root == "1" else { continue }
                    bars[end - 2] = turn[0]
                    bars[end - 1] = turn[1]
                    turnBars.append(end - 2)
                }
            }
        }

        // Breakdown: the last bar (or two) on the dominant sus of the chord the groove returns to.
        if let bd = sections.first(where: { $0.label == .bridge }), bd.endBar <= total {
            let returning = bd.endBar < total ? bars[bd.endBar] : tonic
            if let dominant = dominantSus(of: returning.root, mode: mode) {
                let n = bd.lengthBars > 4 ? 2 : 1
                for b in (bd.endBar - n)..<bd.endBar where b >= bd.startBar { bars[b] = (dominant, .sus4) }
            }
        }

        // Back to windows: consecutive equal bars merge, never across a section boundary.
        let boundaries = Set(sections.map(\.startBar))
        var out: [ChordWindow] = []
        var start = 0
        for b in 1...total {
            if b == total || boundaries.contains(b) || bars[b].root != bars[start].root
                || bars[b].type != bars[start].type {
                let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: bars[start].root,
                                                          chordType: bars[start].type, key: key, mode: mode)
                out.append(ChordWindow(startBar: start, lengthBars: b - start,
                                       chordRoot: bars[start].root, chordType: bars[start].type,
                                       chordTones: ct, scaleTensions: st, avoidTones: at))
                start = b
            }
        }
        // Chunk any window > 8 bars into same-chord sub-windows so analyzer sees correct windows.
        // Breakdown sus4 windows are exempt — they're intentionally static.
        // "turn:" rather than " - turnaround": the Chords line runs long (Zack, 2026-11-11).
        let turnLabel = turnBars.isEmpty ? nil : "turn: \(turn.map(chordName).joined(separator: " – "))"
        let label = [bLabel, turnLabel].compactMap { $0 }.joined(separator: " ")
        return (chunkWindows(out, maxBarLen: 8, key: key, mode: mode), label.isEmpty ? nil : label, turnBars)
    }

    /// The two-chord phrase-end cadence back to the tonic, one bar each. All diatonic.
    ///
    /// - Dorian:     IV7 – Vm7, or bIIImaj7 – IV7
    /// - Aeolian:    bVImaj7 – bVII7, or IVm7 – Vm7
    /// - Mixolydian: bVIImaj7 – IVmaj7, or IIm7 – Vm7
    /// - Ionian:     IIm7 – V7, or IVmaj7 – V7sus4
    static func turnaround(mode: Mode, second: Bool) -> [BarChord] {
        switch mode {
        case .Dorian:     return second ? [("b3", .maj7), ("4", .dom7)] : [("4", .dom7), ("5", .min7)]
        case .Aeolian:    return second ? [("4", .min7), ("5", .min7)] : [("b6", .maj7), ("b7", .dom7)]
        case .Mixolydian: return second ? [("2", .min7), ("5", .min7)] : [("b7", .maj7), ("4", .maj7)]
        case .Ionian:     return second ? [("4", .maj7), ("5", .sus4)] : [("2", .min7), ("5", .dom7)]
        default:          return [("4", .min7), ("5", .min7)]
        }
    }

    /// The degree a fifth above `root`, when a 7sus4 there (root, 4, 5, b7) is all in the mode.
    static func dominantSus(of root: String, mode: Mode) -> String? {
        let names = ["1", "b2", "2", "b3", "3", "4", "#4", "5", "b6", "6", "b7", "7"]
        let scale = Set(mode.intervals)
        let fifth = (degreeSemitone(root) + 7) % 12
        guard [0, 5, 7, 10].allSatisfy({ scale.contains((fifth + $0) % 12) }) else { return nil }
        return names[fifth]
    }

    /// A partner for the B section's pendulum other than the A section's, weighted as in
    /// `pickChordPair` and renormalised over what is left.
    private static func pickOtherPartner(mode: Mode, avoiding: String?, rng: inout SeededRNG) -> BarChord {
        let all = chordPairOptions(mode: mode)
        let options = all.filter { $0.root != avoiding }
        let pool = options.isEmpty ? all : options
        let sum = pool.reduce(0) { $0 + $1.weight }
        let pick = pool[rng.weightedPick(pool.map { $0.weight / sum })]
        return (pick.root, pick.type)
    }

    /// Roman-numeral name for the log, in the Soho Chords line's style: "Im7", "bVII", "IV7".
    static func chordName(_ chord: BarChord) -> String {
        let roman: [String: String] = ["1": "I", "b2": "bII", "2": "II", "b3": "bIII", "3": "III",
                                       "4": "IV", "#4": "#IV", "5": "V", "b6": "bVI", "6": "VI",
                                       "b7": "bVII", "7": "VII"]
        let suffix: String
        switch chord.type {
        case .major:  suffix = ""
        case .minor:  suffix = "m"
        case .min7:   suffix = "m7"
        case .dom7:   suffix = "7"
        case .maj7:   suffix = "maj7"
        case .sus4:   suffix = "7sus4"
        default:      suffix = chord.type.rawValue
        }
        return (roman[chord.root] ?? chord.root) + suffix
    }

    // MARK: - static_groove: one tonic chord the entire song (with sus4 breakdown)

    private static func buildStaticGroove(key: String, mode: Mode, total: Int,
                                           breakdownStart: Int?, breakdownEnd: Int?) -> [ChordWindow] {
        let (tonicRoot, tonicType) = tonicChord(mode: mode)
        if let bs = breakdownStart, let be = breakdownEnd, bs > 0, be < total {
            let (ctT, stT, atT) = NotePoolBuilder.build(chordRootDegree: tonicRoot, chordType: tonicType, key: key, mode: mode)
            let (ctS, stS, atS) = NotePoolBuilder.build(chordRootDegree: "1", chordType: .sus4, key: key, mode: mode)
            let (ctR, stR, atR) = NotePoolBuilder.build(chordRootDegree: tonicRoot, chordType: tonicType, key: key, mode: mode)
            return [
                ChordWindow(startBar: 0,   lengthBars: bs,        chordRoot: tonicRoot, chordType: tonicType,
                            chordTones: ctT, scaleTensions: stT, avoidTones: atT),
                ChordWindow(startBar: bs,  lengthBars: be - bs,   chordRoot: "1",       chordType: .sus4,
                            chordTones: ctS, scaleTensions: stS, avoidTones: atS),
                ChordWindow(startBar: be,  lengthBars: total - be, chordRoot: tonicRoot, chordType: tonicType,
                            chordTones: ctR, scaleTensions: stR, avoidTones: atR),
            ]
        }
        let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: tonicRoot, chordType: tonicType, key: key, mode: mode)
        return [ChordWindow(startBar: 0, lengthBars: total, chordRoot: tonicRoot, chordType: tonicType,
                            chordTones: ct, scaleTensions: st, avoidTones: at)]
    }

    // MARK: - two_chord_pendulum: alternating pair with section-aware window lengths

    private static func buildTwoChordPendulum(frame: GlobalMusicalFrame,
                                               sections: [SongSection],
                                               breakdownStart: Int?, breakdownEnd: Int?,
                                               rng: inout SeededRNG)
    -> (windows: [ChordWindow], partner: BarChord, windowLen: Int) {
        let (root1, type1, root2, type2) = pickChordPair(mode: frame.mode, rng: &rng)
        let windowLen = pickWindowLength(rng: &rng)
        let key = frame.key
        let mode = frame.mode
        var windows: [ChordWindow] = []
        var bar = 0
        var chord1IsActive = true
        while bar < frame.totalBars {
            let isBreakdown = breakdownStart.map { bar >= $0 && bar < (breakdownEnd ?? 0) } ?? false
            var chunkEnd: Int
            if isBreakdown {
                chunkEnd = breakdownEnd ?? (bar + 4)
            } else {
                chunkEnd = Swift.min(bar + windowLen, frame.totalBars)
                // Don't cross section boundary
                if let next = nextSectionBoundary(sections: sections, afterBar: bar) {
                    chunkEnd = Swift.min(chunkEnd, next)
                }
            }
            let len = Swift.max(4, chunkEnd - bar)
            let (root, type_) = isBreakdown ? ("1", ChordType.sus4) : (chord1IsActive ? (root1, type1) : (root2, type2))
            let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: root, chordType: type_, key: key, mode: mode)
            windows.append(ChordWindow(startBar: bar, lengthBars: len, chordRoot: root, chordType: type_,
                                       chordTones: ct, scaleTensions: st, avoidTones: at))
            bar += len
            if !isBreakdown { chord1IsActive.toggle() }
        }
        return (windows, (root2, type2), windowLen)
    }

    // MARK: - minor_blues: 12-bar tile in groove sections

    private static func buildMinorBlues(frame: GlobalMusicalFrame,
                                         sections: [SongSection],
                                         breakdownStart: Int?, breakdownEnd: Int?) -> [ChordWindow] {
        let key = frame.key
        let mode = frame.mode
        let (tonicRoot, tonicType) = tonicChord(mode: mode)
        let subdominantRoot = subdominantDegree(mode: mode)
        var windows: [ChordWindow] = []

        for section in sections {
            let s = section.startBar
            let e = s + section.lengthBars

            if section.label == .bridge {
                // Breakdown: single tonic sus4
                let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: "1", chordType: .sus4, key: key, mode: mode)
                windows.append(ChordWindow(startBar: s, lengthBars: section.lengthBars, chordRoot: "1",
                                           chordType: .sus4, chordTones: ct, scaleTensions: st, avoidTones: at))
            } else {
                // Tile 12-bar blues: i (4) | iv (2) | i (2) | bVII (1) | IV (1) | i (2)
                // Mapped to bars; any remainder uses tonic
                let pattern: [(String, ChordType, Int)] = [
                    (tonicRoot,      tonicType, 4),
                    (subdominantRoot, .min7,    2),
                    (tonicRoot,      tonicType, 2),
                    ("b7",           .major,    1),
                    (subdominantRoot, .major,   1),
                    (tonicRoot,      tonicType, 2),
                ]
                var bar = s
                var patIdx = 0
                var patBar = 0
                while bar < e {
                    let (root, type_, len) = pattern[patIdx % pattern.count]
                    let remaining = len - patBar
                    let chunkLen = Swift.min(remaining, e - bar)
                    let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: root, chordType: type_, key: key, mode: mode)
                    windows.append(ChordWindow(startBar: bar, lengthBars: chunkLen, chordRoot: root, chordType: type_,
                                               chordTones: ct, scaleTensions: st, avoidTones: at))
                    bar += chunkLen
                    patBar += chunkLen
                    if patBar >= len { patIdx += 1; patBar = 0 }
                }
            }
        }
        return windows
    }

    // MARK: - modal_drift: 2–3 slow chord changes over the full song

    private static func buildModalDrift(frame: GlobalMusicalFrame,
                                         sections: [SongSection],
                                         breakdownStart: Int?, breakdownEnd: Int?,
                                         rng: inout SeededRNG) -> [ChordWindow] {
        let key = frame.key
        let mode = frame.mode
        let total = frame.totalBars
        let (tonicRoot, tonicType) = tonicChord(mode: mode)
        let useThreeChords = rng.nextDouble() < 0.40

        // First change placed at Groove A midpoint ±4 bars
        let grooveASection = sections.first { $0.label == .A }
        let firstChangeMid = grooveASection.map { $0.startBar + $0.lengthBars / 2 } ?? (total / 2)
        let firstChangeBar = roundTo4(firstChangeMid + rng.nextInt(upperBound: 9) - 4)

        let secondChord = pickSecondChord(mode: mode, rng: &rng)

        var windows: [ChordWindow] = []
        var bar = 0

        // Tonic up to first change
        if firstChangeBar > 0 {
            let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: tonicRoot, chordType: tonicType, key: key, mode: mode)
            windows.append(ChordWindow(startBar: 0, lengthBars: firstChangeBar, chordRoot: tonicRoot, chordType: tonicType,
                                       chordTones: ct, scaleTensions: st, avoidTones: at))
            bar = firstChangeBar
        }

        if useThreeChords {
            // Second chord from first change to Groove B start
            let grooveBSection = sections.first { $0.label == .B }
            let secondEnd = grooveBSection?.startBar ?? (total - (sections.last?.lengthBars ?? 8))
            let clampedEnd = Swift.min(secondEnd, total)
            if clampedEnd > bar {
                let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: secondChord.0, chordType: secondChord.1, key: key, mode: mode)
                windows.append(ChordWindow(startBar: bar, lengthBars: clampedEnd - bar,
                                           chordRoot: secondChord.0, chordType: secondChord.1,
                                           chordTones: ct, scaleTensions: st, avoidTones: at))
                bar = clampedEnd
            }
            // Third chord (different from second) for Groove B onward
            let thirdChord = pickThirdChord(mode: mode, avoiding: secondChord.0, rng: &rng)
            if bar < total {
                let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: thirdChord.0, chordType: thirdChord.1, key: key, mode: mode)
                windows.append(ChordWindow(startBar: bar, lengthBars: total - bar,
                                           chordRoot: thirdChord.0, chordType: thirdChord.1,
                                           chordTones: ct, scaleTensions: st, avoidTones: at))
            }
        } else {
            // Two-chord version: second chord for the remainder
            if bar < total {
                let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: secondChord.0, chordType: secondChord.1, key: key, mode: mode)
                windows.append(ChordWindow(startBar: bar, lengthBars: total - bar,
                                           chordRoot: secondChord.0, chordType: secondChord.1,
                                           chordTones: ct, scaleTensions: st, avoidTones: at))
            }
        }

        // Overlay breakdown sus4 if present (replace any overlapping windows)
        if let bs = breakdownStart, let be = breakdownEnd {
            return overlayBreakdown(windows: windows, breakdownStart: bs, breakdownEnd: be,
                                    key: key, mode: mode, total: total)
        }
        return windows
    }

    // MARK: - Helpers

    private static func tonicChord(mode: Mode) -> (String, ChordType) {
        switch mode {
        case .Ionian, .Mixolydian: return ("1", .major)
        default:                   return ("1", .min7)
        }
    }

    private static func subdominantDegree(mode: Mode) -> String {
        return "4"  // scale degree 4 is the subdominant root in all supported modes
    }

    /// The tonic's partners per mode with their weights (CHL-SYNC-010).
    private static func chordPairOptions(mode: Mode) -> [(root: String, type: ChordType, weight: Double)] {
        switch mode {
        case .Dorian:     // im7|bVIImaj7 40%, im7|IVmaj7 35%, im7|vm7 25%
            return [("b7", .major, 0.40), ("4", .major, 0.35), ("5", .min7, 0.25)]
        case .Aeolian:    // im7|bVIImaj7 35%, im7|ivm7 35%, im7|bVImaj7 30%
            return [("b7", .major, 0.35), ("4", .min7, 0.35), ("b6", .major, 0.30)]
        case .Mixolydian: // I|bVII 45%, I|IV 35%, I|vm7 20%
            return [("b7", .major, 0.45), ("4", .major, 0.35), ("5", .min7, 0.20)]
        case .Ionian:     // Imaj7|IVmaj7 35%, Imaj7|vim7 35%, Imaj7|bVIImaj7 30%
            // bVII is the Moby open — a named exception (CHL-SYNC-012)
            return [("4", .major, 0.35), ("6", .min7, 0.35), ("b7", .major, 0.30)]
        default:
            return [("b7", .major, 1.0)]
        }
    }

    /// Weighted chord pair per mode (CHL-SYNC-010). One draw, cumulative thresholds, as before.
    private static func pickChordPair(mode: Mode, rng: inout SeededRNG) -> (String, ChordType, String, ChordType) {
        let (tonicRoot, tonicType) = tonicChord(mode: mode)
        let options = chordPairOptions(mode: mode)
        guard options.count > 1 else { return (tonicRoot, tonicType, options[0].root, options[0].type) }
        let roll = rng.nextDouble()
        var threshold = 0.0
        for option in options.dropLast() {
            threshold += option.weight
            if roll < threshold { return (tonicRoot, tonicType, option.root, option.type) }
        }
        let last = options[options.count - 1]
        return (tonicRoot, tonicType, last.root, last.type)
    }

    private static func pickWindowLength(rng: inout SeededRNG) -> Int {
        // 4 bars 25%, 6 bars 45%, 8 bars 30%
        let roll = rng.nextDouble()
        if roll < 0.25 { return 4 }
        if roll < 0.70 { return 6 }
        return 8
    }

    private static func pickSecondChord(mode: Mode, rng: inout SeededRNG) -> (String, ChordType) {
        switch mode {
        case .Dorian:     return rng.nextDouble() < 0.55 ? ("b7", .major) : ("4", .major)
        case .Aeolian:    return rng.nextDouble() < 0.50 ? ("b7", .major) : ("b6", .major)
        case .Mixolydian: return rng.nextDouble() < 0.55 ? ("b7", .major) : ("4", .major)
        case .Ionian:     return rng.nextDouble() < 0.50 ? ("4", .major) : ("6", .min7)
        default:          return ("b7", .major)
        }
    }

    private static func pickThirdChord(mode: Mode, avoiding: String, rng: inout SeededRNG) -> (String, ChordType) {
        let options: [(String, ChordType)]
        switch mode {
        case .Dorian:     options = [("4", .major), ("b7", .major), ("5", .min7)]
        case .Aeolian:    options = [("b6", .major), ("b7", .major), ("4", .min7)]
        case .Mixolydian: options = [("4", .major), ("b7", .major), ("5", .min7)]
        case .Ionian:     options = [("4", .major), ("6", .min7), ("b7", .major)]
        default:          options = [("4", .major), ("b7", .major)]
        }
        let filtered = options.filter { $0.0 != avoiding }
        return filtered.isEmpty ? options[0] : filtered[rng.nextInt(upperBound: filtered.count)]
    }

    /// Replace windows that overlap [breakdownStart, breakdownEnd) with a sus4 window.
    private static func overlayBreakdown(windows: [ChordWindow], breakdownStart: Int, breakdownEnd: Int,
                                          key: String, mode: Mode, total: Int) -> [ChordWindow] {
        var result: [ChordWindow] = []
        for w in windows {
            if w.endBar <= breakdownStart || w.startBar >= breakdownEnd {
                result.append(w)
            } else {
                // Pre-breakdown fragment
                if w.startBar < breakdownStart {
                    let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: w.chordRoot, chordType: w.chordType, key: key, mode: mode)
                    result.append(ChordWindow(startBar: w.startBar, lengthBars: breakdownStart - w.startBar,
                                              chordRoot: w.chordRoot, chordType: w.chordType,
                                              chordTones: ct, scaleTensions: st, avoidTones: at))
                }
                // Breakdown sus4
                if result.last?.chordType != .sus4 || result.last?.startBar != breakdownStart {
                    let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: "1", chordType: .sus4, key: key, mode: mode)
                    result.append(ChordWindow(startBar: breakdownStart, lengthBars: breakdownEnd - breakdownStart,
                                              chordRoot: "1", chordType: .sus4,
                                              chordTones: ct, scaleTensions: st, avoidTones: at))
                }
                // Post-breakdown fragment
                if w.endBar > breakdownEnd {
                    let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: w.chordRoot, chordType: w.chordType, key: key, mode: mode)
                    result.append(ChordWindow(startBar: breakdownEnd, lengthBars: w.endBar - breakdownEnd,
                                              chordRoot: w.chordRoot, chordType: w.chordType,
                                              chordTones: ct, scaleTensions: st, avoidTones: at))
                }
            }
        }
        return result
    }

    private static func nextSectionBoundary(sections: [SongSection], afterBar bar: Int) -> Int? {
        sections.compactMap({ $0.startBar > bar ? $0.startBar : nil }).min()
    }

    private static func roundTo4(_ n: Int) -> Int { (n / 4) * 4 }

    /// Split any chord window longer than maxBarLen into same-chord sub-windows.
    /// Breakdown sus4 windows are left intact (intentionally static, their length is by design).
    private static func chunkWindows(_ windows: [ChordWindow], maxBarLen: Int,
                                      key: String, mode: Mode) -> [ChordWindow] {
        var result: [ChordWindow] = []
        for w in windows {
            if w.lengthBars <= maxBarLen || w.chordType == .sus4 {
                result.append(w)
                continue
            }
            var bar = w.startBar
            while bar < w.endBar {
                let len = min(maxBarLen, w.endBar - bar)
                let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: w.chordRoot,
                                                          chordType: w.chordType,
                                                          key: key, mode: mode)
                result.append(ChordWindow(startBar: bar, lengthBars: len,
                                          chordRoot: w.chordRoot, chordType: w.chordType,
                                          chordTones: ct, scaleTensions: st, avoidTones: at))
                bar += len
            }
        }
        return result
    }

    /// The unison hits around a Remix Break. Into it, beats 3 and 4 of the bar before (after the
    /// band stops on beat 2); out of it, steps 0 and 8 of its last bar, with steps 9–15 left for
    /// the Lead 1 pickup. Drums, bass and rhythm all play these steps.
    static let remixEntryHitSteps = [8, 12]
    static let remixExitHitSteps  = [0, 8]

    /// The bar immediately before a Remix Break, where the band hits that lead into it land.
    /// The exit from the break is a unison figure, and the way in should answer it.
    static func remixEntryBars(structure: SongStructure, breakdownStyle: ChillBreakdownStyle) -> Set<Int> {
        guard breakdownStyle == .sohoRemix else { return [] }
        return Set(structure.sections.filter { $0.label == .bridge }
                       .map { $0.startBar - 1 }.filter { $0 >= 0 })
    }

    /// How far into the intro's build a bar sits, or nil outside the intro.
    ///
    /// A cold start spends the intro's first bar on a drums-only pickup, so the layers that follow
    /// start a bar later — otherwise the staircase loses its first step and everything arrives at
    /// once, which is what Zack heard on *Thunder in the Side Street* (2026-10-12). The pickup bar
    /// returns -1, which fails every `>= n` test on its own.
    static func sohoIntroLayer(bar: Int, structure: SongStructure) -> Int? {
        guard let intro = structure.sections.first(where: { $0.label == .intro }),
              bar >= intro.startBar, bar < intro.endBar else { return nil }
        var offset = 0
        if case .coldStart = structure.introStyle, intro.startBar == 0 { offset = 1 }
        return bar - intro.startBar - offset
    }

    /// Which of the bass and the comping enters first in a Chill Soho intro's build.
    ///
    /// The two are generated independently on different RNG streams and cannot share a draw, so
    /// this is a pure function of the song's own frame and structure: both generators see the same
    /// inputs and reach the same answer with no coupling between them. Whichever leads enters on
    /// the intro's second-to-last bar and the other on its last, so the build still adds one thing
    /// a bar either way — it just alternates which (Zack, 2026-10-12).
    static func sohoBassLeadsIntro(frame: GlobalMusicalFrame, structure: SongStructure) -> Bool {
        (frame.tempo + frame.keySemitoneValue + structure.chordPlan.count) % 2 == 0
    }

    /// The bars occupied by a four-bar Soho turnaround, read back from the finished chord plan.
    ///
    /// `buildSohoChordPlan` decides per song whether every 16-bar phrase turns around or only the
    /// section ends, on its own RNG stream, so a generator cannot recompute that choice. It can
    /// recognise the result: a turnaround is four consecutive one-bar windows whose roots are
    /// exactly the turnaround's, and no cycle in the pool produces that sequence by accident.
    static func sohoTurnaroundBars(frame: GlobalMusicalFrame, structure: SongStructure) -> Set<Int> {
        let tonicType = structure.chordPlan.first?.chordType ?? .min7
        // Major modes have two turnarounds — the measured one and a brighter cadence — and which
        // a song took is decided on the chord plan's own stream. Both are recognised here.
        let shapes = [false, true].map {
            SongGenerator.sohoTurnaround(mode: frame.mode, tonicType: tonicType, bright: $0).map(\.0)
        }
        func root(_ bar: Int) -> String {
            structure.chordWindow(atBar: bar)?.chordRoot ?? ""
        }
        var out = Set<Int>()
        for section in structure.sections where section.label == .A || section.label == .B {
            var bar = section.startBar + 3
            while bar < section.endBar {
                if shapes.contains(where: { shape in (0..<4).allSatisfy { root(bar - 3 + $0) == shape[$0] } }) {
                    out.formUnion((bar - 3)...bar)
                }
                bar += 1
            }
        }
        return out
    }

    /// A song's turnarounds, read once: the bars they occupy, each one's first and last bar in
    /// bar order, and the bass treatment each plays, keyed by its last bar. Pure, so every
    /// generator and the performance log see the same answer on their own streams.
    struct SohoTurnarounds {
        let bars:   Set<Int>
        /// The last bar of each turnaround — the bar that leads back to the top.
        let exits:  [Int]
        /// The first bar of each turnaround — where its chords leave the cycle.
        let starts: [Int]
        let treatments: [Int: SohoTurnaroundTreatment]
    }

    static func sohoTurnarounds(frame: GlobalMusicalFrame, structure: SongStructure) -> SohoTurnarounds {
        let bars   = sohoTurnaroundBars(frame: frame, structure: structure)
        let exits  = bars.filter { !bars.contains($0 + 1) }.sorted()
        let starts = bars.filter { !bars.contains($0 - 1) }.sorted()
        let treatments = Dictionary(uniqueKeysWithValues: exits.enumerated().map { i, exit in
            (exit, sohoTurnaroundTreatment(frame: frame, structure: structure, index: i))
        })
        return SohoTurnarounds(bars: bars, exits: exits, starts: starts, treatments: treatments)
    }

    /// The six turnaround bass treatments, in the order the palette draws from. `original`
    /// leaves the groove alone; the rest are figures that break it. Three of them are descents,
    /// differing only in what the root does underneath: nothing, one held note, or a new note
    /// each bar. Raw values are the numbers the tests and older notes use.
    enum SohoTurnaroundTreatment: Int, CaseIterable {
        case original = -1
        case walkingQuarters, rootAndApproach, descending, rootPedalDescent, pedalDescent

        /// The name used in the performance log and in `ChillSohoTests`.
        var name: String {
            switch self {
            case .original:         return "original form"
            case .walkingQuarters:  return "walking quarters"
            case .rootAndApproach:  return "root & approach"
            case .descending:       return "descending"
            case .rootPedalDescent: return "root pedal descent"
            case .pedalDescent:     return "pedal descent"
            }
        }
    }

    /// The two or three treatments a single song draws on. Four turnarounds all playing the same
    /// figure sounded mechanical, but four different ones had no shape either — two or three,
    /// with repeats, is the ask (Zack, 2026-10-12).
    ///
    /// Pure, like the rest of the turnaround helpers, because the bass generator and the
    /// performance log both need it and run on different streams.
    static func sohoTurnaroundPalette(frame: GlobalMusicalFrame,
                                      structure: SongStructure) -> [SohoTurnaroundTreatment] {
        let seed = frame.tempo * 31 + frame.keySemitoneValue * 17 + structure.chordPlan.count * 13
        var pool = SohoTurnaroundTreatment.allCases
        var out: [SohoTurnaroundTreatment] = []
        var h = seed
        for _ in 0..<((seed / 7) % 100 < 55 ? 2 : 3) {
            h = (h &* 1103515245 &+ 12345) & 0x7fffffff
            out.append(pool.remove(at: h % pool.count))
        }
        return out
    }

    /// The treatment the `index`-th turnaround of the song uses, counting from 0 in bar order.
    ///
    /// The first turnarounds take the palette's entries in order, so every treatment the song
    /// drew is actually heard; any beyond that repeat from the same palette. A song therefore
    /// never plays one figure throughout, and never plays four different ones.
    static func sohoTurnaroundTreatment(frame: GlobalMusicalFrame, structure: SongStructure,
                                        index: Int) -> SohoTurnaroundTreatment {
        let palette = sohoTurnaroundPalette(frame: frame, structure: structure)
        guard index >= palette.count else { return palette[index] }
        let h = (frame.tempo * 11 + frame.keySemitoneValue * 29
                 + structure.chordPlan.count * 7 + index * 37) % 100
        return palette[h % palette.count]
    }

    // Integer views of the treatments, for `ChillSohoTests`, which predates the enum.
    static let sohoTurnaroundOriginal   = SohoTurnaroundTreatment.original.rawValue
    static let sohoTurnaroundTreatments = SohoTurnaroundTreatment.allCases.map(\.rawValue)
    static let sohoTurnaroundStyleNames = SohoTurnaroundTreatment.allCases.filter { $0 != .original }.map(\.name)
    static func sohoTurnaroundStyle(frame: GlobalMusicalFrame, structure: SongStructure,
                                    index: Int) -> Int {
        sohoTurnaroundTreatment(frame: frame, structure: structure, index: index).rawValue
    }
}
