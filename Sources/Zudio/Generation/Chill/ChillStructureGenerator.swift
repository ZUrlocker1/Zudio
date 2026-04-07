// ChillStructureGenerator.swift — Chill generation step 2
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
        rng: inout SeededRNG
    ) -> SongStructure {
        let useSimpleForm = (mood == .Deep || mood == .Dream) && rng.nextDouble() < 0.30
        let (sections, introStyle, outroStyle) = useSimpleForm
            ? buildSimpleSections(frame: frame, rng: &rng)
            : buildFullSections(frame: frame, breakdownStyle: breakdownStyle, rng: &rng)
        let chordPlan = buildChordPlan(frame: frame, sections: sections,
                                       family: chillProgFamily, rng: &rng)
        return SongStructure(sections: sections, chordPlan: chordPlan,
                             introStyle: introStyle, outroStyle: outroStyle)
    }

    // MARK: - Section builders

    /// INTRO / GROOVE-A / BREAKDOWN / GROOVE-B / OUTRO
    private static func buildFullSections(frame: GlobalMusicalFrame,
                                           breakdownStyle: ChillBreakdownStyle = .bassOstinato,
                                           rng: inout SeededRNG) -> ([SongSection], IntroStyle, OutroStyle) {
        let total = frame.totalBars
        // Section lengths drawn from plan ranges, all multiple of 4.
        // Breakdown length is style-dependent: bass ostinato is the most minimal breakdown
        // and should be short (4 bars); other styles allow 4–8 bars.
        let introBars     = roundTo4(ChillMusicalFrameGenerator.triangularInt(min: 4,  peak: 6,  max: 8,  rng: &rng))
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
        }
        let grooveTotal   = Swift.max(20, total - introBars - outroBars - breakdownBars)
        // Split groove total across A and B; B slightly longer (more active)
        let grooveA = roundTo4(Int(Double(grooveTotal) * 0.45))
        let grooveB = grooveTotal - grooveA

        var sections: [SongSection] = []
        var cursor = 0

        sections.append(SongSection(startBar: cursor, lengthBars: introBars,
                                    label: .intro, intensity: .low, mode: frame.mode))
        cursor += introBars

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

    /// Simple form: INTRO / BODY / OUTRO (no breakdown)
    private static func buildSimpleSections(frame: GlobalMusicalFrame,
                                             rng: inout SeededRNG) -> ([SongSection], IntroStyle, OutroStyle) {
        let total = frame.totalBars
        let introBars = roundTo4(ChillMusicalFrameGenerator.triangularInt(min: 4, peak: 6, max: 8, rng: &rng))
        let outroBars = roundTo4(ChillMusicalFrameGenerator.triangularInt(min: 4, peak: 6, max: 8, rng: &rng))
        let bodyBars  = Swift.max(16, total - introBars - outroBars)

        let useColdStyle = rng.nextDouble() < 0.50
        let introStyle: IntroStyle = useColdStyle ? .coldStart(drumsOnly: true) : .alreadyPlaying
        let outroStyle: OutroStyle = useColdStyle ? .coldStop : .fade
        return ([
            SongSection(startBar: 0,                        lengthBars: introBars, label: .intro,  intensity: .low,    mode: frame.mode),
            SongSection(startBar: introBars,                lengthBars: bodyBars,  label: .A,      intensity: .medium, mode: frame.mode),
            SongSection(startBar: introBars + bodyBars,     lengthBars: outroBars, label: .outro,  intensity: .low,    mode: frame.mode),
        ], introStyle, outroStyle)
    }

    // MARK: - Chord plan

    private static func buildChordPlan(frame: GlobalMusicalFrame,
                                        sections: [SongSection],
                                        family: ChillProgressionFamily,
                                        rng: inout SeededRNG) -> [ChordWindow] {
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
            windows = buildTwoChordPendulum(frame: frame, sections: sections,
                                             breakdownStart: breakdownStart, breakdownEnd: breakdownEnd,
                                             rng: &rng)

        case .minor_blues:
            windows = buildMinorBlues(frame: frame, sections: sections,
                                      breakdownStart: breakdownStart, breakdownEnd: breakdownEnd)

        case .modal_drift:
            windows = buildModalDrift(frame: frame, sections: sections,
                                      breakdownStart: breakdownStart, breakdownEnd: breakdownEnd,
                                      rng: &rng)
        }
        // Chunk any window > 8 bars into same-chord sub-windows so analyzer sees correct windows.
        // Breakdown sus4 windows are exempt — they're intentionally static.
        return chunkWindows(windows, maxBarLen: 8, key: key, mode: mode)
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
                                               rng: inout SeededRNG) -> [ChordWindow] {
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
        return windows
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

    /// Weighted chord pair per mode (CHL-SYNC-010)
    private static func pickChordPair(mode: Mode, rng: inout SeededRNG) -> (String, ChordType, String, ChordType) {
        switch mode {
        case .Dorian:
            // im7|bVIImaj7 40%, im7|IVmaj7 35%, im7|vm7 25%
            let roll = rng.nextDouble()
            if roll < 0.40 { return ("1", .min7, "b7", .major) }
            if roll < 0.75 { return ("1", .min7, "4",  .major) }
            return ("1", .min7, "5", .min7)

        case .Aeolian:
            // im7|bVIImaj7 35%, im7|ivm7 35%, im7|bVImaj7 30%
            let roll = rng.nextDouble()
            if roll < 0.35 { return ("1", .min7, "b7", .major) }
            if roll < 0.70 { return ("1", .min7, "4",  .min7) }
            return ("1", .min7, "b6", .major)

        case .Mixolydian:
            // I|bVII 45%, I|IV 35%, I|vm7 20%
            let roll = rng.nextDouble()
            if roll < 0.45 { return ("1", .major, "b7", .major) }
            if roll < 0.80 { return ("1", .major, "4",  .major) }
            return ("1", .major, "5", .min7)

        case .Ionian:
            // Imaj7|IVmaj7 35%, Imaj7|vim7 35%, Imaj7|bVIImaj7 30%
            let roll = rng.nextDouble()
            if roll < 0.35 { return ("1", .major, "4",  .major) }
            if roll < 0.70 { return ("1", .major, "6",  .min7) }
            return ("1", .major, "b7", .major)  // Moby open — bVII named exception (CHL-SYNC-012)

        default:
            return ("1", .min7, "b7", .major)
        }
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
}
