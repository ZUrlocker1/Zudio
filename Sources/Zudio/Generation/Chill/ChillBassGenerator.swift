// ChillBassGenerator.swift — Chill generation step 4
// Copyright (c) 2026 Zack Urlocker
// Four patterns (CHL-BASS-001 to CHL-BASS-004), section-aware.
// All notes snapped to active scale (CHL-SYNC-001).
// Bass root lands on chord root at bar boundaries (CHL-SYNC-008).

import Foundation

struct ChillBassGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        chillProgFamily: ChillProgressionFamily,
        beatStyle: ChillBeatStyle,
        breakdownStyle: ChillBreakdownStyle,
        bluesVariation: Bool = false,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        variationAnnotations: inout [(bar: Int, kind: String)]
    ) -> [MIDIEvent] {
        // Blues Chill uses dedicated blues bass pool (overrides beat-style routing)
        if bluesVariation {
            return bluesBass(frame: frame, structure: structure, rng: &rng, usedRuleIDs: &usedRuleIDs,
                             variationAnnotations: &variationAnnotations)
        }

        // St Germain beat style always uses the 8th-note ostinato (CHL-BASS-007)
        if beatStyle == .stGermain {
            usedRuleIDs.insert("CHL-BASS-007")
            return stGermainOstinato(frame: frame, structure: structure, breakdownStyle: breakdownStyle, rng: &rng)
        }

        // Hip-hop jazz beat style uses the chord-tone arpeggio groove (CHL-BASS-008)
        if beatStyle == .hipHopJazz {
            usedRuleIDs.insert("CHL-BASS-008")
            return acidJazzGroove(frame: frame, structure: structure, breakdownStyle: breakdownStyle, rng: &rng)
        }

        // Choose primary groove pattern for the whole song — one rule, consistent throughout.
        let useOstinato   = chillProgFamily == .static_groove && rng.nextDouble() < 0.25
        let useWalking    = (beatStyle == .neoSoul || beatStyle == .brushKit) && rng.nextDouble() < 0.40
        // 001 vs 002 decided once here, not per bar
        let useSyncopated = !useOstinato && rng.nextDouble() < 0.55

        if useOstinato      { usedRuleIDs.insert("CHL-BASS-004") }
        else if useSyncopated { usedRuleIDs.insert("CHL-BASS-002") }
        else                  { usedRuleIDs.insert("CHL-BASS-001") }
        if useWalking { usedRuleIDs.insert("CHL-BASS-003") }

        // CHL-BASS-006 Bass Statement: fires on exactly ONE groove bar mid-song.
        // Pick the bar now so the statement is placed deliberately, not randomly per bar.
        // Note: the picked bar may land in a section (bridge/intro/outro) that never reaches
        // the rendering check below, so tagging as "used" happens only once it actually renders.
        let grooveBars = frame.totalBars - 8  // rough groove length excluding intro/outro
        let statementBar: Int? = grooveBars >= 16
            ? 4 + rng.nextInt(upperBound: grooveBars)   // somewhere in the groove
            : nil

        var events: [MIDIEvent] = []
        // Build 4-bar ostinato if selected, plus a mildly varied tile swapped in every third
        // repeat (~every 12 bars) so the figure isn't note-for-note identical the whole song.
        let ostinatoPattern: [(Int, Int)]? = useOstinato ? buildOstinatoPattern(variant: false) : nil
        let ostinatoVariant: [(Int, Int)]? = useOstinato ? buildOstinatoPattern(variant: true) : nil

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A
            let chord   = structure.chordPlan.first { $0.contains(bar: bar) }
            let chordRoot = chordRootNote(frame: frame, chord: chord)
            let scale     = scaleNotes(frame: frame, chord: chord)
            let base      = bar * 16

            switch coldEdgeAction(bar: bar, base: base, chordRoot: chordRoot, structure: structure) {
            case .skip: continue
            case .stabAndSkip(let stab): events.append(stab); continue
            case .proceed: break
            }

            switch label {
            case .bridge:
                usedRuleIDs.insert("CHL-BASS-005")
                let breakdownBar = bar - (section?.startBar ?? bar)
                switch breakdownStyle {
                case .stopTime:
                    // Even bars: staccato root hit (the "unison stab"); odd bars: silent
                    if breakdownBar % 2 == 0 {
                        events.append(MIDIEvent(stepIndex: base, note: UInt8(clampBass(chordRoot)),
                                                velocity: 88, durationSteps: 4))
                    }
                case .bassOstinato:
                    // Progressive embellishment arc — ostinato "corrupts" toward resolution.
                    // Bar 0: bare root riff; bar 1: adds 5th; bar 2: adds chromatic neighbor;
                    // bar 3 (last): quarter-note chromatic walk into groove root.
                    let root     = clampBass(chordRoot)
                    let fifth    = clampBass(snapToScale(chordRoot + 7, scale: scale))
                    let neighbor = clampBass(chordRoot + 1)  // half-step above root — mild dissonance
                    let grooveRoot = clampBass(nextChordRootNote(bar: bar, frame: frame, structure: structure))
                    let sectionLen   = section?.lengthBars ?? 4
                    let isLastBDBar  = (breakdownBar == sectionLen - 1)

                    if isLastBDBar {
                        // Last bar: chromatic quarter-note walk toward groove chord root
                        let walkTarget = grooveRoot
                        let walkStart  = root
                        let diff = walkTarget - walkStart
                        let step = diff == 0 ? 0 : (diff > 0 ? 1 : -1)
                        var walkNote = walkStart
                        for (i, s) in [0, 4, 8, 12].enumerated() {
                            let vel = UInt8(72 + i * 6)  // rising: 72, 78, 84, 90
                            events.append(MIDIEvent(stepIndex: base + s, note: UInt8(clampBass(walkNote)),
                                                    velocity: vel, durationSteps: 3))
                            walkNote = clampBass(walkNote + step)
                        }
                    } else {
                        // Base riff: root (3 steps) → 5th (2 steps) → root (2 steps) → approach (2 steps)
                        let approach = clampBass(snapToScale(chordRoot - 1, scale: scale))
                        events.append(MIDIEvent(stepIndex: base,      note: UInt8(root),  velocity: 90, durationSteps: 3))
                        if breakdownBar >= 1 {
                            // Bar 1+: add 5th
                            events.append(MIDIEvent(stepIndex: base + 6,  note: UInt8(fifth), velocity: 78, durationSteps: 2))
                        } else {
                            events.append(MIDIEvent(stepIndex: base + 6,  note: UInt8(root),  velocity: 76, durationSteps: 2))
                        }
                        events.append(MIDIEvent(stepIndex: base + 9,  note: UInt8(root),  velocity: 84, durationSteps: 2))
                        if breakdownBar >= 2 {
                            // Bar 2+: swap approach for chromatic neighbor (tension note)
                            events.append(MIDIEvent(stepIndex: base + 13, note: UInt8(neighbor), velocity: 74, durationSteps: 2))
                        } else {
                            events.append(MIDIEvent(stepIndex: base + 13, note: UInt8(approach), velocity: 72, durationSteps: 2))
                        }
                    }
                case .harmonicDrone:
                    // Absence → reentry arc: bars 1-2 silent (tension from void);
                    // bar 3: whisper root reentry; bar 4: rising velocity into drum fill + groove.
                    let sectionLen  = section?.lengthBars ?? 4
                    let isLastBDBar = (breakdownBar == sectionLen - 1)
                    let root = clampBass(chordRoot)
                    if isLastBDBar {
                        // Bar 4: bass returns at full voice, rising velocity — groove is coming
                        let fifth = clampBass(snapToScale(chordRoot + 7, scale: scale))
                        events.append(MIDIEvent(stepIndex: base,     note: UInt8(root),  velocity: 80, durationSteps: 4))
                        events.append(MIDIEvent(stepIndex: base + 4, note: UInt8(fifth), velocity: 85, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: base + 8, note: UInt8(root),  velocity: 88, durationSteps: 2))
                        // Chromatic approach into groove on beat 4
                        let approach = clampBass(snapToScale(chordRoot - 1, scale: scale))
                        events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(approach), velocity: 92, durationSteps: 3))
                    } else if breakdownBar == sectionLen - 2 {
                        // Bar 3: whisper root reentry — barely there, tension peaking
                        events.append(MIDIEvent(stepIndex: base, note: UInt8(root), velocity: 45, durationSteps: 12))
                    }
                    // Bars 1-2 (breakdownBar 0-1): bass silent — pad holds the void alone
                case .groovePocket:
                    // Last bar of 8-bar pocket: ascending pickup into groove return
                    let sectionLen = section?.lengthBars ?? 4
                    guard breakdownBar == sectionLen - 1 else { break }
                    let root  = clampBass(chordRoot)
                    let third = clampBass(snapToScale(chordRoot + 3, scale: scale))
                    let fifth = clampBass(snapToScale(chordRoot + 7, scale: scale))
                    let oct   = clampBass(chordRoot + 12)
                    for (i, note) in [root, third, fifth, oct].enumerated() {
                        events.append(MIDIEvent(stepIndex: base + 8 + i * 2, note: UInt8(note),
                                                velocity: UInt8(50 + i * 12), durationSteps: 2))
                    }
                }

            case .intro:
                // Intro: simplified syncopated pattern — hints at groove without full density
                let rootNote = clampBass(chordRoot)
                let introFifth = clampBass(snapToScale(chordRoot + 7, scale: scale))
                let introApproach = clampBass(nextChordRootNote(bar: bar, frame: frame, structure: structure) - 1)
                events.append(MIDIEvent(stepIndex: base,      note: UInt8(rootNote),    velocity: UInt8(60 + rng.nextInt(upperBound: 9)), durationSteps: 8))
                if rng.nextDouble() < 0.70 {
                    events.append(MIDIEvent(stepIndex: base + 8, note: UInt8(introFifth), velocity: UInt8(52 + rng.nextInt(upperBound: 9)), durationSteps: 4))
                }
                if rng.nextDouble() < 0.35 {
                    events.append(MIDIEvent(stepIndex: base + 14, note: UInt8(introApproach), velocity: UInt8(48 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                }

            case .outro:
                // Outro: root + 5th sustain, diminishing velocity
                let outroBar  = bar - (section?.startBar ?? bar)
                let outroBase = UInt8(max(38, 68 - outroBar * 8))
                let rootNote  = clampBass(chordRoot)
                let outroFifth = clampBass(snapToScale(chordRoot + 7, scale: scale))
                events.append(MIDIEvent(stepIndex: base,      note: UInt8(rootNote),    velocity: outroBase, durationSteps: 8))
                if rng.nextDouble() < 0.60 {
                    events.append(MIDIEvent(stepIndex: base + 8, note: UInt8(outroFifth), velocity: UInt8(max(30, Int(outroBase) - 10)), durationSteps: 4))
                }

            default:
                // Groove sections
                if let ostinato = ostinatoPattern {
                    // CHL-BASS-004 Air Ostinato: 4-bar repeating figure, with the variant tile
                    // swapped in on every third cycle (bars 9-12, 21-24, ...) for relief.
                    let patBar = bar % 4
                    let cycleIndex = bar / 4
                    let activePattern = (ostinatoVariant != nil && cycleIndex % 3 == 2) ? ostinatoVariant! : ostinato
                    let patNotes = activePattern.filter { $0.0 / 16 == patBar }
                    for (step, deg) in patNotes {
                        let note = snapToScale(chordRoot + deg, scale: scale)
                        events.append(MIDIEvent(stepIndex: base + (step % 16), note: UInt8(clampBass(note)),
                                                velocity: UInt8(80 + rng.nextInt(upperBound: 11)), durationSteps: 2))
                    }
                } else if useWalking && isBeforeChordChange(bar: bar, structure: structure) {
                    // CHL-BASS-003 Walking line: root → 3rd → 5th → approach tone
                    events += walkingLine(bar: bar, chordRoot: chordRoot, scale: scale, rng: &rng)
                } else {
                    // CHL-BASS-001 or CHL-BASS-002 — chosen once per song, consistent throughout
                    if useSyncopated {
                        events += syncopatedPattern(base: base, chordRoot: chordRoot, scale: scale,
                                                     nextChordRoot: nextChordRootNote(bar: bar, frame: frame, structure: structure),
                                                     bar: bar, rng: &rng)
                    } else {
                        events += rootSustainPattern(base: base, chordRoot: chordRoot, scale: scale, rng: &rng)
                    }

                    // CHL-BASS-006 Bass Statement: fires on exactly one designated bar mid-song
                    if let sb = statementBar, bar == sb {
                        events += bassStatement(base: base, chordRoot: chordRoot, scale: scale, rng: &rng)
                        usedRuleIDs.insert("CHL-BASS-006")
                    }
                }
            }
        }
        return events
    }

    // MARK: - Root sustain (CHL-BASS-001)

    /// firstBForm: guaranteed two-feel (root beats 1–2, 5th beats 3–4) — replaces the
    /// probabilistic 5th and approach embellishments with locked movement for B-section contrast.
    private static func rootSustainPattern(base: Int, chordRoot: Int, scale: [Int],
                                            rng: inout SeededRNG,
                                            firstBForm: Bool = false) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let rootNote = clampBass(chordRoot)
        let fifth    = clampBass(snapToScale(chordRoot + 7, scale: scale))

        if firstBForm {
            // B-form: locked two-feel — root on beats 1–2, 5th on beats 3–4.
            result.append(MIDIEvent(stepIndex: base,     note: UInt8(rootNote), velocity: UInt8(80 + rng.nextInt(upperBound: 10)), durationSteps: 8))
            result.append(MIDIEvent(stepIndex: base + 8, note: UInt8(fifth),    velocity: UInt8(72 + rng.nextInt(upperBound: 10)), durationSteps: 7))
        } else {
            // A-section: long root sustain with optional embellishments.
            result.append(MIDIEvent(stepIndex: base, note: UInt8(rootNote),
                                    velocity: UInt8(75 + rng.nextInt(upperBound: 11)), durationSteps: 12))
            // Optional 5th on beat 3 (60%)
            if rng.nextDouble() < 0.60 {
                result.append(MIDIEvent(stepIndex: base + 8, note: UInt8(fifth),
                                        velocity: UInt8(65 + rng.nextInt(upperBound: 11)), durationSteps: 4))
            }
            // Occasional approach tone (25%) — adds forward motion between bars
            if rng.nextDouble() < 0.25 {
                let approach = clampBass(snapToScale(chordRoot - 1, scale: scale))
                if approach != clampBass(chordRoot) {
                    result.append(MIDIEvent(stepIndex: base + 12, note: UInt8(approach),
                                            velocity: UInt8(60 + rng.nextInt(upperBound: 8)), durationSteps: 3))
                }
            }
        }
        return result
    }

    // MARK: - Syncopated pattern (CHL-BASS-002)

    /// Evolution: the shape cycles every 4 bars (bar % 4) so the same cell doesn't repeat
    /// unbroken for the whole song — bar 1 shifts the embellishment to a b7 offbeat, bar 3
    /// thins out to root + approach only for breathing room.
    private static func syncopatedPattern(base: Int, chordRoot: Int, scale: [Int],
                                           nextChordRoot: Int, bar: Int,
                                           rng: inout SeededRNG) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let root     = clampBass(chordRoot)
        let approach = clampBass(snapToScale(nextChordRoot - 1, scale: scale))

        switch bar % 4 {
        case 1:
            // b7 offbeat variant: AND of beat 3 (step 10) instead of AND of beat 2.
            let b7 = clampBass(snapToScale(chordRoot + 10, scale: scale))
            result.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                    velocity: UInt8(80 + rng.nextInt(upperBound: 11)), durationSteps: 8))
            if rng.nextDouble() < 0.70 {
                result.append(MIDIEvent(stepIndex: base + 10, note: UInt8(b7),
                                        velocity: UInt8(70 + rng.nextInt(upperBound: 11)), durationSteps: 2))
            }
            result.append(MIDIEvent(stepIndex: base + 8, note: UInt8(root),
                                    velocity: UInt8(75 + rng.nextInt(upperBound: 11)), durationSteps: 4))
            result.append(MIDIEvent(stepIndex: base + 14, note: UInt8(approach),
                                    velocity: UInt8(65 + rng.nextInt(upperBound: 11)), durationSteps: 2))
        case 3:
            // Sparse bar: root long hold + approach only — breathing room every 4th bar.
            result.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                    velocity: UInt8(78 + rng.nextInt(upperBound: 11)), durationSteps: 12))
            result.append(MIDIEvent(stepIndex: base + 14, note: UInt8(approach),
                                    velocity: UInt8(62 + rng.nextInt(upperBound: 11)), durationSteps: 2))
        default:
            // Original shape (bars 0 and 2 of the cycle)
            result.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                    velocity: UInt8(80 + rng.nextInt(upperBound: 11)), durationSteps: 8))
            if rng.nextDouble() < 0.70 {
                let fifth = snapToScale(chordRoot + 7, scale: scale)
                result.append(MIDIEvent(stepIndex: base + 6, note: UInt8(clampBass(fifth)),
                                        velocity: UInt8(70 + rng.nextInt(upperBound: 11)), durationSteps: 2))
            }
            result.append(MIDIEvent(stepIndex: base + 8, note: UInt8(root),
                                    velocity: UInt8(75 + rng.nextInt(upperBound: 11)), durationSteps: 6))
            result.append(MIDIEvent(stepIndex: base + 14, note: UInt8(approach),
                                    velocity: UInt8(65 + rng.nextInt(upperBound: 11)), durationSteps: 2))
        }
        return result
    }

    // MARK: - Walking line (CHL-BASS-003)

    private static func walkingLine(bar: Int, chordRoot: Int, scale: [Int],
                                     rng: inout SeededRNG) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let base = bar * 16
        let root  = clampBass(chordRoot)
        let third = clampBass(snapToScale(chordRoot + 3, scale: scale))
        let fifth = clampBass(snapToScale(chordRoot + 7, scale: scale))
        let approach = clampBass(snapToScale(chordRoot - 1, scale: scale))
        let notes = [root, third, fifth, approach]
        for (i, note) in notes.enumerated() {
            let vel: UInt8 = i == 0 ? UInt8(85 + rng.nextInt(upperBound: 11)) : UInt8(75 + rng.nextInt(upperBound: 11))
            result.append(MIDIEvent(stepIndex: base + i * 4, note: UInt8(note), velocity: vel, durationSteps: 4))
        }
        return result
    }

    // MARK: - Air Ostinato pattern (CHL-BASS-004)

    private static func buildOstinatoPattern(variant: Bool) -> [(Int, Int)] {
        // Returns [(stepInPattern, degreeOffsetFromRoot)]
        // 4-bar pattern: (step 0=bar1, 16=bar2, 32=bar3, 48=bar4)
        if variant {
            // Swapped in every third cycle: bar 3 descends through the 5th instead of
            // climbing to the 3rd, and bar 4 adds a late approach tone instead of just holding.
            return [
                (0,  0), (4,  2), (8,  0),            // bar 1: root, 2nd, root
                (16, 0), (20, 5), (24, 7), (28, 0),   // bar 2: root, 4th, 5th, root
                (32, 7), (40, 5), (44, 3),             // bar 3: 5th, 4th, 3rd (descending)
                (48, 0), (60, -2),                     // bar 4: root, then approach tone
            ]
        }
        return [
            (0,  0), (4,  2), (8,  0),           // bar 1: root, 2nd, root
            (16, 0), (20, 5), (24, 7), (28, 0),  // bar 2: root, 4th, 5th, root ← bar 2 now starts on root
            (32, 3), (40, 2),                     // bar 3: 3rd, 2nd (only non-root start)
            (48, 0),                              // bar 4: root, held
        ]
    }

    // MARK: - Bass statement (CHL-BASS-006)

    private static func bassStatement(base: Int, chordRoot: Int, scale: [Int],
                                       rng: inout SeededRNG) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let noteCount = 2 + rng.nextInt(upperBound: 3)  // 2–4 notes
        let startStep = rng.nextInt(upperBound: 12)
        var prevNote = clampBass(chordRoot) + 12  // wider register (1 octave up)
        for i in 0..<noteCount {
            let degOffset = [-7, -5, -3, 0, 3, 5, 7][rng.nextInt(upperBound: 7)]
            let note = snapToScale(prevNote + degOffset, scale: scale)
            let noteNote = max(36, min(57, note))  // bass statement: slightly wider range
            let vel = UInt8(50 + rng.nextInt(upperBound: 16))
            let step = base + startStep + i * 2
            if step < base + 16 {
                result.append(MIDIEvent(stepIndex: step, note: UInt8(noteNote), velocity: vel, durationSteps: 2))
            }
            prevNote = note
        }
        return result
    }

    // MARK: - CHL-BASS-007: St Germain 8th-note ostinato

    /// CHL-BASS-007: Inspired by St Germain "So Flute" — strict 8th-note pulse cycling through
    /// chord tones (root-heavy, with 5th, b7, 4th). Evolution arc peaks at song midpoint then
    /// returns to base: more chord-tone variety mid-song. Occasional breathing-room notes
    /// (4–8 steps) replace the strict 8th to avoid mechanical feel. Section-aware:
    /// breakdown uses root whole-note; intro/outro use root sustain.
    private static func stGermainOstinato(frame: GlobalMusicalFrame, structure: SongStructure,
                                           breakdownStyle: ChillBreakdownStyle,
                                           rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A
            let chord   = structure.chordPlan.first { $0.contains(bar: bar) }
            let chordRoot = chordRootNote(frame: frame, chord: chord)
            let scale     = scaleNotes(frame: frame, chord: chord)
            let base      = bar * 16

            switch coldEdgeAction(bar: bar, base: base, chordRoot: chordRoot, structure: structure) {
            case .skip: continue
            case .stabAndSkip(let stab): events.append(stab); continue
            case .proceed: break
            }

            switch label {
            case .bridge:
                let breakdownBar = bar - (section?.startBar ?? bar)
                let root = clampBass(chordRoot)
                switch breakdownStyle {
                case .harmonicDrone:
                    // Half-note root + quarter 5th pattern with velocity swell toward groove return.
                    // (a) beat 1: root half-note; beat 3: 5th quarter; beat 4: root quarter
                    // (b) velocity swell: bars 0-1 = 58-65, bars 2-3 = 72-82
                    // (c) last beat of final breakdown bar: chromatic approach tone (root-1) signals return
                    let fifth = clampBass(snapToScale(chordRoot + 7, scale: scale))
                    let breakdownSection = section
                    let bdStart = breakdownSection?.startBar ?? bar
                    let bdLen   = breakdownSection?.lengthBars ?? 4
                    let bdBar   = bar - bdStart  // 0-based position within breakdown
                    let isFinalBreakdownBar = (bdBar == bdLen - 1)

                    // Velocity swell: quiet early, building late
                    let swellBase = 58 + (bdBar * 8)          // 58, 66, 74, 82 across 4 bars
                    let vel1 = UInt8(min(swellBase,     82))  // beat 1 root
                    let vel3 = UInt8(min(swellBase + 4, 86))  // beat 3 fifth
                    let vel4 = UInt8(min(swellBase + 6, 90))  // beat 4 root / approach

                    // Beat 1: root, half note (8 steps)
                    events.append(MIDIEvent(stepIndex: base,     note: UInt8(root),  velocity: vel1, durationSteps: 7))
                    // Beat 3: 5th, quarter note (4 steps)
                    events.append(MIDIEvent(stepIndex: base + 8, note: UInt8(fifth), velocity: vel3, durationSteps: 3))
                    // Beat 4: approach tone on final bar, root otherwise
                    if isFinalBreakdownBar {
                        // Chromatic approach: semitone below the root that will return on Groove B beat 1
                        let approach = clampBass(chordRoot - 1)
                        events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(approach), velocity: vel4, durationSteps: 3))
                    } else {
                        events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(root), velocity: vel4, durationSteps: 3))
                    }
                case .stopTime:
                    // Even bars only: staccato root hit (the unison stab); odd bars silent
                    if breakdownBar % 2 == 0 {
                        events.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                                velocity: 88, durationSteps: 4))
                    }
                case .bassOstinato:
                    // Syncopated riff: root + 5th with funk articulation
                    let fifth    = clampBass(snapToScale(chordRoot + 7, scale: scale))
                    let approach = clampBass(chordRoot - 1)
                    events.append(MIDIEvent(stepIndex: base,      note: UInt8(root),     velocity: 90, durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: base + 6,  note: UInt8(fifth),    velocity: 78, durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: base + 9,  note: UInt8(root),     velocity: 84, durationSteps: 2))
                    if bar < frame.totalBars - 1 {
                        events.append(MIDIEvent(stepIndex: base + 13, note: UInt8(approach), velocity: 72, durationSteps: 2))
                    }
                case .groovePocket:
                    let sectionLen = section?.lengthBars ?? 4
                    guard breakdownBar == sectionLen - 1 else { break }
                    let third  = clampBass(snapToScale(chordRoot + 3, scale: scale))
                    let fifth2 = clampBass(snapToScale(chordRoot + 7, scale: scale))
                    let oct    = clampBass(chordRoot + 12)
                    for (i, note) in [root, third, fifth2, oct].enumerated() {
                        events.append(MIDIEvent(stepIndex: base + 8 + i * 2, note: UInt8(note),
                                                velocity: UInt8(50 + i * 12), durationSteps: 2))
                    }
                }
            case .intro:
                // Intro: punchy 8th-note hits — same shape as groove but softer.
                // Colour note: 5th (50%), b7 (30%), or 3rd (20%) for variety across songs.
                // Two rhythmic shapes: base (65%) starts on beat 1; late-entry (35%) starts on beat 2.
                let introRoot   = clampBass(chordRoot)
                let introFifth  = clampBass(snapToScale(chordRoot + 7,  scale: scale))
                let introBb7    = clampBass(snapToScale(chordRoot + 10, scale: scale))
                let introThird  = clampBass(snapToScale(chordRoot + 4,  scale: scale))
                let colourNote: Int = {
                    let r = rng.nextDouble()
                    if r < 0.50 { return introFifth }
                    if r < 0.80 { return introBb7 }
                    return introThird
                }()

                if rng.nextDouble() < 0.35 {
                    // Late-entry variant: beat 1 silent, root enters on beat 2 — laid-back pickup feel
                    events.append(MIDIEvent(stepIndex: base + 4,  note: UInt8(introRoot),
                                            velocity: UInt8(62 + rng.nextInt(upperBound: 8)), durationSteps: 2))
                    if rng.nextDouble() < 0.60 {
                        events.append(MIDIEvent(stepIndex: base + 6, note: UInt8(colourNote),
                                                velocity: UInt8(54 + rng.nextInt(upperBound: 8)), durationSteps: 2))
                    }
                    events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(introRoot),
                                            velocity: UInt8(58 + rng.nextInt(upperBound: 8)), durationSteps: 2))
                } else {
                    // Base shape: root on beat 1, optional passing root, colour note on 2-AND, root on beat 3
                    events.append(MIDIEvent(stepIndex: base,     note: UInt8(introRoot),
                                            velocity: UInt8(60 + rng.nextInt(upperBound: 8)), durationSteps: 2))
                    if rng.nextDouble() < 0.40 {
                        events.append(MIDIEvent(stepIndex: base + 2, note: UInt8(introRoot),
                                                velocity: UInt8(53 + rng.nextInt(upperBound: 8)), durationSteps: 2))
                    }
                    if rng.nextDouble() < 0.65 {
                        events.append(MIDIEvent(stepIndex: base + 6, note: UInt8(colourNote),
                                                velocity: UInt8(52 + rng.nextInt(upperBound: 8)), durationSteps: 2))
                    }
                    events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(introRoot),
                                            velocity: UInt8(57 + rng.nextInt(upperBound: 8)), durationSteps: 2))
                }
            case .outro:
                // Outro: same 8th-note shape as intro, diminishing velocity bar by bar.
                let outroBar   = bar - (section?.startBar ?? bar)
                let outroVBase = max(38, 68 - outroBar * 10)
                let outroRoot  = clampBass(chordRoot)
                let outroFifth = clampBass(snapToScale(chordRoot + 7, scale: scale))
                events.append(MIDIEvent(stepIndex: base,     note: UInt8(outroRoot),
                                        velocity: UInt8(outroVBase), durationSteps: 2))
                if rng.nextDouble() < 0.65 {
                    events.append(MIDIEvent(stepIndex: base + 6, note: UInt8(outroFifth),
                                            velocity: UInt8(max(30, outroVBase - 8)), durationSteps: 2))
                }
                events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(outroRoot),
                                        velocity: UInt8(max(30, outroVBase - 4)), durationSteps: 2))
            default:
                // Groove: St Germain 8th-note cell — punchy 2-step hits, root-anchored.
                // Base bar: root on 1, occasional passing root on 1-AND, 5th on 2-AND, root on 3,
                //   occasional passing note on 3-AND, approach/ornament on 4-AND.
                // Three bar types: base (~80%), breath (~8%), fill (~12% at peak mid-song).
                // Evolution modulates passing-note density and fill probability — not random pitch per note.
                let t = Double(bar) / Double(max(1, frame.totalBars))
                let evolutionPhase = 4.0 * t * (1.0 - t)  // 0 at edges, 1.0 at midpoint

                let root     = clampBass(chordRoot)
                let fifth    = clampBass(snapToScale(chordRoot + 7, scale: scale))
                let fourth   = clampBass(snapToScale(chordRoot + 5, scale: scale))
                let nextRoot = nextChordRootNote(bar: bar, frame: frame, structure: structure)
                let approach = clampBass(snapToScale(nextRoot - 1, scale: scale))

                let breathChance = 0.08 - evolutionPhase * 0.04   // 8% → 4% → 8%
                let fillChance   = 0.06 + evolutionPhase * 0.14   // 6% → 20% → 6%
                let roll = rng.nextDouble()

                if roll < breathChance {
                    // Breath bar: root sustained almost the whole bar — one long held note
                    events.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                            velocity: UInt8(78 + rng.nextInt(upperBound: 9)), durationSteps: 14))

                } else if roll < breathChance + fillChance {
                    // Fill bar: denser 8th-note run for variety; 6 events across the bar
                    events.append(MIDIEvent(stepIndex: base,      note: UInt8(root),   velocity: UInt8(86 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: base + 2,  note: UInt8(fifth),  velocity: UInt8(79 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: base + 4,  note: UInt8(root),   velocity: UInt8(82 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(root),   velocity: UInt8(84 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: base + 10, note: UInt8(fourth), velocity: UInt8(76 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: base + 14, note: UInt8(fifth),  velocity: UInt8(75 + rng.nextInt(upperBound: 9)), durationSteps: 2))

                } else {
                    // Base bar: the core cell — 4–5 punchy 8th-note events.
                    // Beat 1 downbeat: root (always present)
                    events.append(MIDIEvent(stepIndex: base,     note: UInt8(root),
                                            velocity: UInt8(85 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    // Beat 1-AND (step 2): passing root — sparse early, more common mid-song
                    if rng.nextDouble() < 0.30 + evolutionPhase * 0.30 {
                        events.append(MIDIEvent(stepIndex: base + 2, note: UInt8(root),
                                                velocity: UInt8(76 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    }
                    // Beat 2-AND (step 6): 5th — the St Germain signature; mostly present
                    if rng.nextDouble() < 0.72 {
                        events.append(MIDIEvent(stepIndex: base + 6, note: UInt8(fifth),
                                                velocity: UInt8(75 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    }
                    // Beat 3 (step 8): root (always present)
                    events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(root),
                                            velocity: UInt8(83 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    // Beat 3-AND (step 10): root or 5th passing note — more common mid-song
                    if rng.nextDouble() < 0.25 + evolutionPhase * 0.25 {
                        let passing = rng.nextDouble() < 0.65 ? root : fifth
                        events.append(MIDIEvent(stepIndex: base + 10, note: UInt8(passing),
                                                velocity: UInt8(76 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    }
                    // Beat 4-AND (step 14): approach before chord change; sparse ornament otherwise
                    if isBeforeChordChange(bar: bar, structure: structure) {
                        events.append(MIDIEvent(stepIndex: base + 14, note: UInt8(approach),
                                                velocity: UInt8(71 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    } else if rng.nextDouble() < 0.22 {
                        events.append(MIDIEvent(stepIndex: base + 14, note: UInt8(fourth),
                                                velocity: UInt8(68 + rng.nextInt(upperBound: 9)), durationSteps: 2))
                    }
                }
            }
        }
        return events
    }

    // MARK: - Cold start/stop guard

    /// What to do with a bar at the cold-start/cold-stop edges of the song, shared by every
    /// bass render function (`generate`, `stGermainOstinato`, `acidJazzGroove`, `bluesBass`).
    private enum ColdEdgeAction {
        case proceed
        case skip
        case stabAndSkip(MIDIEvent)
    }

    /// Cold start: bar 0 is drums-only, bass silent. Cold stop: final bar silent; the bar
    /// before it gets a root stab landing with the crash.
    private static func coldEdgeAction(bar: Int, base: Int, chordRoot: Int,
                                        structure: SongStructure) -> ColdEdgeAction {
        if case .coldStart = structure.introStyle, bar == 0 { return .skip }
        if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
            if bar >= outroEnd - 1 { return .skip }
            if bar == outroEnd - 2 {
                return .stabAndSkip(MIDIEvent(stepIndex: base, note: UInt8(clampBass(chordRoot)),
                                              velocity: 80, durationSteps: 3))
            }
        }
        return .proceed
    }

    // MARK: - Scale/chord helpers

    private static func chordRootNote(frame: GlobalMusicalFrame, chord: ChordWindow?) -> Int {
        let rootDeg = chord?.chordRoot ?? "1"
        return 60 + frame.keySemitoneValue + degreeSemitone(rootDeg) - 24  // bass register
    }

    private static func nextChordRootNote(bar: Int, frame: GlobalMusicalFrame, structure: SongStructure) -> Int {
        let nextChord = structure.chordPlan.first { $0.contains(bar: bar + 1) }
            ?? structure.chordPlan.first { $0.contains(bar: bar) }
        return chordRootNote(frame: frame, chord: nextChord)
    }

    private static func scaleNotes(frame: GlobalMusicalFrame, chord: ChordWindow?) -> [Int] {
        // CHL-SYNC-001: scale pool anchors to frame.key + frame.mode (never chord root)
        let root = 60 + frame.keySemitoneValue
        return frame.mode.intervals.map { (root + $0) % 12 }
    }

    private static func snapToScale(_ note: Int, scale: [Int]) -> Int {
        let pc = note % 12
        let octave = note / 12
        let nearest = scale.min(by: { abs($0 - pc) < abs($1 - pc) }) ?? pc
        return octave * 12 + nearest
    }

    private static func clampBass(_ note: Int) -> Int {
        // Bass register: MIDI 40–52 (ceiling 52 = E3; prevents chord roots like F3=53 from sitting too high)
        var n = note
        while n > 52 { n -= 12 }
        while n < 40 { n += 12 }
        return n
    }

    // MARK: - CHL-BASS-008: Acid Jazz Groove

    /// CHL-BASS-008: Chord-tone arpeggio groove — root, 5th, and b7 (or 3rd) played in a
    /// syncopated 3–4 note pattern each bar, all within the active chord's pentatonic.
    /// No chromatic approach tones; all notes are chord tones or scale tones.
    /// Variation: every 8–12 bars, one "fill bar" walks through 5 chord tones (denser, more
    /// linear), then immediately reverts to the syncopated arpeggio. Maintains harmonic clarity.
    /// Breakdown: root whole-note sustain (stop-time/ostinato), root quarter pulse (drone).
    private static func acidJazzGroove(frame: GlobalMusicalFrame, structure: SongStructure,
                                        breakdownStyle: ChillBreakdownStyle,
                                        rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Fill interval: one walking-fill bar every fillInterval bars, then back to arpeggio
        let fillInterval = 8 + rng.nextInt(upperBound: 5)  // 8–12 bars between fill bars

        for bar in 0..<frame.totalBars {
            let section   = structure.section(atBar: bar)
            let label     = section?.label ?? .A
            let chord     = structure.chordPlan.first { $0.contains(bar: bar) }
            let chordRoot = chordRootNote(frame: frame, chord: chord)
            let scale     = scaleNotes(frame: frame, chord: chord)
            let base      = bar * 16

            switch coldEdgeAction(bar: bar, base: base, chordRoot: chordRoot, structure: structure) {
            case .skip: continue
            case .stabAndSkip(let stab): events.append(stab); continue
            case .proceed: break
            }

            let root  = clampBass(chordRoot)
            let fifth = clampBass(snapToScale(chordRoot + 7,  scale: scale))
            let third = clampBass(snapToScale(chordRoot + 3,  scale: scale))
            let b7    = clampBass(snapToScale(chordRoot + 10, scale: scale))

            switch label {
            case .bridge:
                let breakdownBar = bar - (section?.startBar ?? bar)
                switch breakdownStyle {
                case .stopTime:
                    if breakdownBar % 2 == 0 {
                        events.append(MIDIEvent(stepIndex: base, note: UInt8(root), velocity: 85, durationSteps: 4))
                    }
                case .bassOstinato:
                    // Syncopated 2-bar arpeggio riff
                    events.append(MIDIEvent(stepIndex: base,     note: UInt8(root),  velocity: 88, durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: base + 6, note: UInt8(fifth), velocity: 76, durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: base + 9, note: UInt8(root),  velocity: 82, durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: base + 13, note: UInt8(snapToScale(chordRoot - 1, scale: scale) == root ? b7 : clampBass(snapToScale(chordRoot - 1, scale: scale))), velocity: 70, durationSteps: 2))
                case .harmonicDrone:
                    // Alternating pulse / motion arc. This used to be a root quarter-note on
                    // every beat of every breakdown bar — four identical bars, 16 identical
                    // notes, which reads as a stuck loop rather than a breakdown.
                    //
                    // Shape: even bars pulse (repetition builds tension), odd bars move, and
                    // the last bar always releases into the groove. Alternating means no more
                    // than one repetitive bar ever lands in a row, at any breakdown length.
                    //
                    //   bar 1  root funk cell, quarters      — establish the drone
                    //   bar 2  root/b7/5th, mixed durations  — motion
                    //   bar 3  root funk cell, tighter       — tension tightens
                    //   bar 4  walk-up + chromatic approach  — release into the return
                    //
                    // Every bar opens with the same funk cell — accent on the beat, ghost on
                    // the "a", push on the "and" — so the pocket carries across all four even
                    // though bars 1 and 3 never leave the root. Ghosts are near-silent muted
                    // notes: felt as groove, not heard as pitches.
                    let sectionLen  = section?.lengthBars ?? 4
                    let isLastBDBar = (breakdownBar == sectionLen - 1)
                    let swell       = UInt8(min(72 + breakdownBar * 5, 92))
                    let ghost       = UInt8(36)

                    if isLastBDBar {
                        // Release: syncopated chord-tone walk, chromatic approach on beat 4.
                        // Matches the approach-tone convention used by the other two
                        // harmonicDrone bass rules so the return lands the same way.
                        // True chromatic leading tone, deliberately NOT snapped to the scale:
                        // chordRoot-1 sits one semitone from both the root and the b7, so
                        // snapToScale's tie-break could collapse it onto the root and leave
                        // beat 4, beat 1 and the B-section downbeat all on the same note.
                        let approach = clampBass(chordRoot - 1)
                        events.append(MIDIEvent(stepIndex: base,      note: UInt8(root),     velocity: 84,    durationSteps: 3))
                        events.append(MIDIEvent(stepIndex: base + 3,  note: UInt8(root),     velocity: ghost, durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: base + 6,  note: UInt8(b7),       velocity: 84,    durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: base + 10, note: UInt8(fifth),    velocity: 88,    durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: base + 14, note: UInt8(approach), velocity: 92,    durationSteps: 2))
                    } else if breakdownBar % 2 == 0 {
                        // Pulse bar — still one note, but a funk cell instead of flat quarters:
                        // accent on the beat, ghost on the "a", push on the "and". The cell
                        // repeats across both halves, so the bar stays highly repetitive while
                        // sitting in a pocket. Later pulses are shorter and louder, so the
                        // repetition reads as intensifying rather than as bar 1 coming round again.
                        let gate = breakdownBar == 0 ? 3 : 2
                        for half in [0, 8] {
                            events.append(MIDIEvent(stepIndex: base + half,     note: UInt8(root), velocity: swell,     durationSteps: gate))
                            events.append(MIDIEvent(stepIndex: base + half + 3, note: UInt8(root), velocity: ghost,     durationSteps: 1))
                            events.append(MIDIEvent(stepIndex: base + half + 6, note: UInt8(root), velocity: swell - 8, durationSteps: 2))
                        }
                    } else {
                        // Motion bar: opens with the same funk cell so the feel carries across
                        // bars, then leaves the root — b7 on the "and of 3", 5th swung onto the
                        // "and of 4" so the bar lifts into the next downbeat rather than closing
                        // square on beat 4.
                        events.append(MIDIEvent(stepIndex: base,      note: UInt8(root),  velocity: swell,     durationSteps: 3))
                        events.append(MIDIEvent(stepIndex: base + 3,  note: UInt8(root),  velocity: ghost,     durationSteps: 1))
                        events.append(MIDIEvent(stepIndex: base + 6,  note: UInt8(root),  velocity: swell - 8, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: base + 10, note: UInt8(b7),    velocity: swell + 4, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: base + 14, note: UInt8(fifth), velocity: swell + 2, durationSteps: 2))
                    }
                case .groovePocket:
                    let sectionLen = section?.lengthBars ?? 4
                    guard breakdownBar == sectionLen - 1 else { break }
                    let oct = clampBass(chordRoot + 12)
                    for (i, note) in [root, third, fifth, oct].enumerated() {
                        events.append(MIDIEvent(stepIndex: base + 8 + i * 2, note: UInt8(note),
                                                velocity: UInt8(50 + i * 12), durationSteps: 2))
                    }
                }
            case .intro:
                // Intro: simplified Cell A (root → 5th) at lower velocity, hinting at the groove
                events.append(MIDIEvent(stepIndex: base,     note: UInt8(root),  velocity: UInt8(62 + rng.nextInt(upperBound: 8)), durationSteps: 6))
                if rng.nextDouble() < 0.70 {
                    events.append(MIDIEvent(stepIndex: base + 9, note: UInt8(fifth), velocity: UInt8(52 + rng.nextInt(upperBound: 8)), durationSteps: 4))
                }
            case .outro:
                // Outro: root + 5th sustain, decaying velocity
                let outroBar  = bar - (section?.startBar ?? bar)
                let decayBase = UInt8(max(38, 68 - outroBar * 8))
                events.append(MIDIEvent(stepIndex: base,     note: UInt8(root),  velocity: decayBase, durationSteps: 7))
                if rng.nextDouble() < 0.60 {
                    events.append(MIDIEvent(stepIndex: base + 9, note: UInt8(fifth), velocity: UInt8(max(30, Int(decayBase) - 12)), durationSteps: 5))
                }
            default:
                // Every fillInterval bars: walking fill bar covering more chord tones
                let isFillBar = (bar % fillInterval == fillInterval - 1)
                if isFillBar {
                    // Walking fill: root → 3rd → 5th → b7 → root (5 notes across the bar)
                    let fillNotes = [root, third, fifth, b7, root]
                    let fillSteps = [0, 3, 7, 11, 14]
                    let fillDurs  = [3, 4, 4, 3, 2]
                    for (note, step, dur) in zip(zip(fillNotes, fillSteps), fillDurs).map({ ($0.0, $0.1, $1) }) {
                        events.append(MIDIEvent(stepIndex: base + step, note: UInt8(note),
                                                velocity: UInt8(82 + rng.nextInt(upperBound: 10)), durationSteps: dur))
                    }
                } else {
                    // Primary syncopated arpeggio: root → 5th → b7 (or root → 5th → 3rd) → root
                    // Alternate between two cells across bars for variety
                    let useAltCell = rng.nextDouble() < 0.30
                    let vel1 = UInt8(82 + rng.nextInt(upperBound: 10))
                    let vel2 = UInt8(70 + rng.nextInt(upperBound: 10))
                    let vel3 = UInt8(76 + rng.nextInt(upperBound: 10))
                    if useAltCell {
                        // Cell B: root (4) → 3rd (2) → 5th (2) → root anticipation (1)
                        events.append(MIDIEvent(stepIndex: base,      note: UInt8(root),  velocity: vel1, durationSteps: 4))
                        events.append(MIDIEvent(stepIndex: base + 6,  note: UInt8(third), velocity: vel2, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: base + 10, note: UInt8(fifth), velocity: vel3, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: base + 14, note: UInt8(root),  velocity: vel2, durationSteps: 2))
                    } else {
                        // Cell A: root (3) → 5th (2) → b7 (4)  [3 notes/bar; syncopated acid jazz feel]
                        // Steps 6 and 10 ("and of 2", "and of 3") lock with the 8th-note hi-hat grid.
                        events.append(MIDIEvent(stepIndex: base,       note: UInt8(root),  velocity: vel1, durationSteps: 3))
                        events.append(MIDIEvent(stepIndex: base + 6,   note: UInt8(fifth), velocity: vel2, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: base + 10,  note: UInt8(b7),    velocity: vel3, durationSteps: 4))
                    }
                }
            }
        }
        return events
    }

    // MARK: - Blues bass dispatcher (CHL-BASS-001 / 003 / 004 / 009 / 010 / 011 / 012)

    /// Selects one blues bass pattern for the whole song, then applies it per bar.
    /// Pool: CHL-BASS-012/009/011/001/010/003 at 15% each, CHL-BASS-004 (Air Ostinato, trial
    /// addition) at 10% — deliberately a bit less common than the others.
    private static func bluesBass(frame: GlobalMusicalFrame, structure: SongStructure,
                                   rng: inout SeededRNG,
                                   usedRuleIDs: inout Set<String>,
                                   variationAnnotations: inout [(bar: Int, kind: String)]) -> [MIDIEvent] {
        let roll = rng.nextDouble()
        let useRumba     = roll < 0.15
        let usePickup    = roll >= 0.15 && roll < 0.30
        let useAscending = roll >= 0.30 && roll < 0.45
        let useWalking   = roll >= 0.45 && roll < 0.60
        let usePulse     = roll >= 0.60 && roll < 0.75
        let useOstinato  = roll >= 0.75 && roll < 0.85
        // else (roll >= 0.85): CHL-BASS-003 walking line

        if useRumba          { usedRuleIDs.insert("CHL-BASS-012") }
        else if usePickup    { usedRuleIDs.insert("CHL-BASS-009") }
        else if useAscending { usedRuleIDs.insert("CHL-BASS-011") }
        else if useWalking   { usedRuleIDs.insert("CHL-BASS-001") }
        else if usePulse     { usedRuleIDs.insert("CHL-BASS-010") }
        else if useOstinato  { usedRuleIDs.insert("CHL-BASS-004") }
        else                 { usedRuleIDs.insert("CHL-BASS-003") }

        // CHL-BASS-004 Air Ostinato (trial addition to the blues pool): same 4-bar tile as
        // regular Chill, re-rooted to whatever chord is active each bar — including through
        // the IV/V changes of the 12-bar form, same as every other blues bass rule here.
        let ostinatoPattern: [(Int, Int)]? = useOstinato ? buildOstinatoPattern(variant: false) : nil
        let ostinatoVariant: [(Int, Int)]? = useOstinato ? buildOstinatoPattern(variant: true) : nil

        // IV/V chord bass style — chosen once, applied to every IV and V bar in the song.
        let ivvRoll = rng.nextDouble()
        let ivvIsHold     = ivvRoll < 1.0 / 3.0
        let ivvIsApproach = ivvRoll < 2.0 / 3.0
        // else: two-feel

        // CHL-BASS-011 ascending riff variant parameters (1a/1b/1c) — chosen once for the whole song.
        let riffRhythmTemplate = rng.nextInt(upperBound: 3)   // 0=A (default), 1=B (long land), 2=C (dotted)
        let riffAscendingOpener = rng.nextDouble() < 0.50     // true = 5th→6th, false = 6th→5th
        let riffTailRoll = rng.nextDouble()
        let riffTailInterval = riffTailRoll < 0.60 ? 10 : (riffTailRoll < 0.85 ? 5 : 12)  // b7 / 4th / root8va

        // CHL-BASS-009 pickup variant parameters — chosen once for the whole song.
        let pickupIsB3    = rng.nextDouble() < 0.30           // pickup note: b3 (30%) or 5th (70%)
        let step12Roll    = rng.nextDouble()
        let step12Interval = step12Roll < 0.60 ? 10 : (step12Roll < 0.85 ? 3 : 7)  // b7 / b3 / 5th
        let echoRoll      = rng.nextDouble()
        let echoStyle     = echoRoll < 0.65 ? 0 : (echoRoll < 0.85 ? 1 : 2)  // 0=echo, 1=silence, 2=ghost

        // CHL-BASS-012 rumba variant parameters — chosen once for the whole song.
        let rumbaIsTight     = rng.nextDouble() < 0.20   // 4-attack: omit step 14 (tight pocket)
        let rumbaBlues7th    = rng.nextDouble() < 0.50   // enable per-bar 20% b7 sub at step 12
        let rumbaOctaveReset = rng.nextDouble() < 0.30   // step 14 = nextRoot−12 on chord-change bars

        // One subtle bass variation per 16-bar blues-form repeat, landing at random in bars 4-6
        // of the 8-bar I-chord span (never near a chord change) — applied uniformly regardless
        // of which bass rule is active, so the long stretch of I chord doesn't feel static.
        let variationKinds = ["octave shift", "passing tone", "note repeat", "reorder"]
        var variationBarKinds: [Int: String] = [:]
        for section in structure.sections where section.label == .A || section.label == .B {
            var cycleStart = section.startBar
            while cycleStart < section.endBar {
                let bar = cycleStart + 3 + rng.nextInt(upperBound: 3)   // bars 4-6 (0-indexed 3-5)
                if bar < section.endBar {
                    variationBarKinds[bar] = variationKinds[rng.nextInt(upperBound: variationKinds.count)]
                }
                cycleStart += 16
            }
        }

        var events: [MIDIEvent] = []
        // Turnaround bar: bar 16 of each 16-bar blues cycle — plain root hold (non-rumba rules).
        // A and B sections each have their own form clock so turnarounds fire in both.
        let bSectionStart = structure.sections.first { $0.label == .B }?.startBar ?? -1
        let aSectionStart = structure.sections.first { $0.label == .A }?.startBar ?? bSectionStart

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A
            let chord   = structure.chordPlan.first { $0.contains(bar: bar) }
            let chordRoot = chordRootNote(frame: frame, chord: chord)
            let scale     = scaleNotes(frame: frame, chord: chord)
            let base      = bar * 16

            switch coldEdgeAction(bar: bar, base: base, chordRoot: chordRoot, structure: structure) {
            case .skip: continue
            case .stabAndSkip(let stab): events.append(stab); continue
            case .proceed: break
            }

            switch label {
            case .bridge:
                usedRuleIDs.insert("CHL-BASS-005")
                let breakdownBar = bar - (section?.startBar ?? bar)
                // Blues breakdown: root sustain with simple embellishment
                let root = clampBass(chordRoot)
                let fifth = clampBass(snapToScale(chordRoot + 7, scale: scale))
                let sectionLen  = section?.lengthBars ?? 4
                let isLastBDBar = (breakdownBar == sectionLen - 1)
                if isLastBDBar {
                    events.append(MIDIEvent(stepIndex: base,      note: UInt8(root),  velocity: 88, durationSteps: 6))
                    events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(fifth), velocity: 78, durationSteps: 4))
                    events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(root),  velocity: 84, durationSteps: 3))
                } else {
                    events.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                            velocity: UInt8(78 + rng.nextInt(upperBound: 10)), durationSteps: 14))
                }

            default:
                // Turnaround bar: bar 16 of each 16-bar blues cycle.
                // Each section uses its own form clock so turnarounds align in both A and B sections.
                let posInForm     = (label == .B) ? (bar - bSectionStart) : (bar - aSectionStart)
                let isTurnaroundBar = (label == .A || label == .B) && posInForm >= 15 && (posInForm + 1) % 16 == 0
                // Turnaround bar: rumba and pickup — root on beat 1, beats 2–3 rest,
                // P5+b7 on beat 4 as announcement pickup into the new form's bar 1.
                // All other rules: plain root hold.
                if isTurnaroundBar {
                    let tRoot = UInt8(clampBass(chordRoot))
                    if useRumba || usePickup {
                        let tP5 = UInt8(clampBass(chordRoot + 7))
                        let tB7 = UInt8(clampBass(chordRoot + 10))
                        events.append(MIDIEvent(stepIndex: base,      note: tRoot, velocity: 88, durationSteps: 4))
                        // beats 2–3 (steps 4–11): rest
                        events.append(MIDIEvent(stepIndex: base + 12, note: tP5,  velocity: 76, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: base + 14, note: tB7,  velocity: 72, durationSteps: 2))
                    } else {
                        events.append(MIDIEvent(stepIndex: base, note: tRoot, velocity: 88, durationSteps: 14))
                    }
                    break
                }

                // Capture the range of events this bar is about to append, so a scheduled
                // variation bar can mutate just this bar's notes regardless of which rule rendered them.
                let beforeCount = events.count

                // IV and V chords: simplified pattern chosen once per song (ivvIsHold / ivvIsApproach / two-feel).
                // Pickup, rumba, and ostinato bypass this — all three handle every chord context
                // in their own riff, so add any future rule with the same trait to this list.
                let usesOwnChordHandling = usePickup || useRumba || useOstinato
                let isIV = chord?.chordRoot == "4" && chord?.chordType == .min7
                let isV  = chord?.chordType == .dom7  // dom7 only appears on V in the blues cycle

                // True for the first full 16-bar blues form in B section — enables B-form variants.
                let isFirstBForm = label == .B && posInForm < 32

                if (isIV || isV) && !usesOwnChordHandling {
                    let root = clampBass(chordRoot)
                    if ivvIsHold {
                        // Root hold: single sustained note spotlights the chord change.
                        events.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                                velocity: UInt8(84 + rng.nextInt(upperBound: 8)), durationSteps: 14))
                    } else if ivvIsApproach {
                        // Root + chromatic approach: root holds through beat 3, half-step below
                        // the next chord's root on beat 4 — pulls into the resolution.
                        let nextRoot = nextChordRootNote(bar: bar, frame: frame, structure: structure)
                        let approach = clampBass(nextRoot - 1)
                        events.append(MIDIEvent(stepIndex: base,      note: UInt8(root),     velocity: UInt8(86 + rng.nextInt(upperBound: 8)), durationSteps: 11))
                        events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(approach),  velocity: UInt8(76 + rng.nextInt(upperBound: 8)), durationSteps: 2))
                    } else {
                        // Two-feel: root on beat 1, fifth on beat 3 — half-time groove.
                        let fifth = clampBass(snapToScale(chordRoot + 7, scale: scale))
                        events.append(MIDIEvent(stepIndex: base,     note: UInt8(root),  velocity: UInt8(84 + rng.nextInt(upperBound: 8)), durationSteps: 7))
                        events.append(MIDIEvent(stepIndex: base + 8, note: UInt8(fifth), velocity: UInt8(76 + rng.nextInt(upperBound: 8)), durationSteps: 7))
                    }
                } else if usePickup {
                    events += bluesPickup(base: base, chordRoot: chordRoot, scale: scale, rng: &rng,
                                          firstBForm: isFirstBForm, formPosition: posInForm,
                                          pickupIsB3: pickupIsB3, step12Interval: step12Interval, echoStyle: echoStyle)
                } else if useAscending {
                    events += bluesAscendingRiff(base: base, chordRoot: chordRoot, scale: scale, rng: &rng,
                                                 rhythmTemplate: riffRhythmTemplate,
                                                 ascendingOpener: riffAscendingOpener,
                                                 tailInterval: riffTailInterval,
                                                 bSection: isFirstBForm,
                                                 echoAsFifth: isFirstBForm,
                                                 forceTemplateB: isFirstBForm)
                } else if useRumba {
                    let isInBSection   = (label == .B)
                    let isChanging     = isBeforeChordChange(bar: bar, structure: structure)
                    let beforeChange   = isInBSection && isChanging
                    let doOctaveReset  = rumbaOctaveReset && isChanging && !isInBSection
                    let nextRoot       = nextChordRootNote(bar: bar, frame: frame, structure: structure)
                    events += rumbaBassCell(base: base, chordRoot: chordRoot, rng: &rng,
                                            isTight: rumbaIsTight,
                                            blues7th: rumbaBlues7th,
                                            isBeforeChange: beforeChange,
                                            doOctaveReset: doOctaveReset,
                                            nextChordRoot: nextRoot)
                } else if useWalking {
                    events += rootSustainPattern(base: base, chordRoot: chordRoot, scale: scale, rng: &rng,
                                                 firstBForm: isFirstBForm)
                } else if usePulse {
                    events += quarterPulse(base: base, chordRoot: chordRoot, scale: scale,
                                           formPosition: posInForm, rng: &rng)
                } else if useOstinato {
                    let patBar = bar % 4
                    let cycleIndex = bar / 4
                    let activePattern = (cycleIndex % 3 == 2) ? ostinatoVariant! : ostinatoPattern!
                    let patNotes = activePattern.filter { $0.0 / 16 == patBar }
                    for (step, deg) in patNotes {
                        let note = snapToScale(chordRoot + deg, scale: scale)
                        events.append(MIDIEvent(stepIndex: base + (step % 16), note: UInt8(clampBass(note)),
                                                velocity: UInt8(80 + rng.nextInt(upperBound: 11)), durationSteps: 2))
                    }
                } else {
                    events += walkingLine(bar: bar, chordRoot: chordRoot, scale: scale, rng: &rng)
                }

                if let kind = variationBarKinds[bar] {
                    let (mutated, appliedKind) = applyBassVariation(Array(events[beforeCount...]), kind: kind,
                                                                     chordRoot: chordRoot, scale: scale, rng: &rng)
                    events.replaceSubrange(beforeCount..., with: mutated)
                    variationAnnotations.append((bar, appliedKind))
                }
            }
        }
        return events
    }

    /// Mutates one bar's worth of already-generated bass events for CHL-BASS variation bars —
    /// rule-agnostic so it works the same regardless of which of the 7 blues bass rules rendered
    /// the bar. `scale` anchors the diatonic passing-tone case to the active key (CHL-SYNC-001);
    /// `chordRoot` anchors the blues blue-note case and the end-of-bar resolution target.
    /// Returns the events plus the kind actually applied — note repeat and passing tone fall back
    /// to octave shift whenever they'd otherwise produce no audible change (no room, or a
    /// "passing" tone that collapses back onto a note already there).
    private static func applyBassVariation(_ barEvents: [MIDIEvent], kind: String, chordRoot: Int,
                                            scale: [Int], rng: inout SeededRNG)
                                            -> (events: [MIDIEvent], appliedKind: String) {
        guard !barEvents.isEmpty else { return (barEvents, kind) }
        let result = barEvents.sorted { $0.stepIndex < $1.stepIndex }

        // Reach outside the usual narrow bass register for a short run of 1-3 notes together —
        // clampBass would clamp right back into range and erase the effect, so widen it here.
        // Direction is biased, not a coin flip: a note already in the upper half of the normal
        // register shifts down (never compounding an already-high note even higher).
        func octaveShift() -> [MIDIEvent] {
            var r = result
            let runLen = min(r.count, 1 + rng.nextInt(upperBound: 3))   // 1-3 notes
            let startIdx = rng.nextInt(upperBound: r.count - runLen + 1)
            for i in startIdx..<(startIdx + runLen) {
                let dir = Int(r[i].note) >= 46 ? -12 : 12
                let shifted = max(28, min(64, Int(r[i].note) + dir))
                r[i] = MIDIEvent(stepIndex: r[i].stepIndex, note: UInt8(shifted),
                                 velocity: r[i].velocity, durationSteps: r[i].durationSteps)
            }
            return r
        }

        switch kind {
        case "octave shift":
            return (octaveShift(), "octave shift")

        case "note repeat":
            // Short, quiet echo of a 1-3 note motif from the start of the bar (not just one
            // note), trimmed to however many actually fit before the bar ends or collide.
            var mutated = result
            let motifLen = min(result.count, 1 + rng.nextInt(upperBound: 3))   // 1-3 notes
            let motif = Array(result[0..<motifLen])
            let barEnd = (result[0].stepIndex / 16) * 16 + 16
            var echoEvents: [MIDIEvent] = []
            var cursor = motif.last!.stepIndex + motif.last!.durationSteps
            for note in motif {
                guard cursor + 2 <= barEnd else { break }
                let collides = result.contains { $0.stepIndex >= cursor && $0.stepIndex < cursor + 2 }
                guard !collides else { break }
                let echoVel = UInt8(max(30, Int(note.velocity) - 20))
                echoEvents.append(MIDIEvent(stepIndex: cursor, note: note.note,
                                            velocity: echoVel, durationSteps: 2))
                cursor += 3   // short gap between echoed notes
            }
            guard !echoEvents.isEmpty else { return (octaveShift(), "octave shift") }
            mutated.append(contentsOf: echoEvents)
            mutated.sort { $0.stepIndex < $1.stepIndex }
            return (mutated, "note repeat")

        case "reorder":
            // Reverse the pitch sequence across the bar while keeping the rhythm exactly as-is.
            guard result.count >= 2 else { return (result, "reorder") }
            var mutated = result
            let pitches = Array(result.map { $0.note }.reversed())
            for i in mutated.indices {
                mutated[i] = MIDIEvent(stepIndex: mutated[i].stepIndex, note: pitches[i],
                                       velocity: mutated[i].velocity, durationSteps: mutated[i].durationSteps)
            }
            return (mutated, "reorder")

        case "passing tone":
            // Slip a genuine passing tone into the widest gap between notes (or between the
            // last note and the bar's resolution toward the next chord root), if there's room.
            var mutated = result
            let barStart = (result[0].stepIndex / 16) * 16
            let barEnd = barStart + 16
            var bestGapStart = -1, bestGapLen = 0, bestFromIdx = 0
            for i in 0..<result.count {
                let gapStart = result[i].stepIndex + result[i].durationSteps
                let gapEnd = (i + 1 < result.count) ? result[i + 1].stepIndex : barEnd
                let len = gapEnd - gapStart
                if len > bestGapLen { bestGapLen = len; bestGapStart = gapStart; bestFromIdx = i }
            }
            guard bestGapLen >= 4 else { return (octaveShift(), "octave shift") }

            let fromNote = Int(result[bestFromIdx].note)
            let toNote = (bestFromIdx + 1 < result.count) ? Int(result[bestFromIdx + 1].note) : clampBass(chordRoot)
            let interval = toNote - fromNote
            let sign = interval >= 0 ? 1 : -1

            // Blues signature: a 4th-to-5th gap (either direction) gets the blue note (b5) —
            // the note the blues scale adds on top of the minor pentatonic specifically to
            // pass between those two degrees. Deliberately off-scale.
            let fourthPC = (chordRoot + 5) % 12, fifthPC = (chordRoot + 7) % 12
            var passingNote: Int? = nil
            if Set([fromNote % 12, toNote % 12]) == Set([fourthPC, fifthPC]) {
                passingNote = clampBass(chordRoot + 6)
            } else if abs(interval) >= 3 {
                // Diatonic passing tone: genuinely between the two flanking notes (they're a
                // third or more apart, so this can't just collapse back onto either endpoint).
                passingNote = snapToScale((fromNote + toNote) / 2, scale: scale)
            } else if abs(interval) == 2 {
                // Chromatic passing tone: the only note that fills a whole-step gap is off-scale.
                passingNote = fromNote + sign
            }
            // abs(interval) <= 1: no real gap to pass through — falls through to the guard below.

            guard let pn = passingNote, pn != fromNote, pn != toNote else {
                return (octaveShift(), "octave shift")
            }
            let insertStep = bestGapStart + bestGapLen / 2
            mutated.append(MIDIEvent(stepIndex: insertStep, note: UInt8(max(28, min(64, pn))),
                                     velocity: UInt8(55 + rng.nextInt(upperBound: 10)), durationSteps: 2))
            mutated.sort { $0.stepIndex < $1.stepIndex }
            return (mutated, "passing tone")

        default:
            return (result, kind)
        }
    }

    // MARK: - CHL-BASS-009: Blues Pickup

    /// CHL-BASS-009: Root-anchored bass with a pickup on step 7 (5th or b3 of active chord).
    /// Creates forward pull into beat 3; characteristic blues bass pickup feel.
    /// Song-level variants (chosen once, passed from bluesBass):
    ///   pickupIsB3     — pickup note at steps 7–8: b3 (30%) or 5th (70%)
    ///   step12Interval — note at step 12: b7/+10 (60%), b3/+3 (25%), 5th/+7 (15%)
    ///   echoStyle      — 0: root echo at step 2 (65%), 1: silence (20%), 2: ghost at step 6 (15%)
    /// Evolution: `formPosition` (this bar's position within the running 16-bar blues form) flips
    /// the pickup note and cycles the echo style each time the form repeats, so the pattern
    /// doesn't stay frozen on the same shape for the whole song. Takes the raw position (not a
    /// pre-divided form index) for the same reason `quarterPulse` does — keeps the "which form
    /// repeat is this" math in one place, next to the code that uses it, instead of split between
    /// the call site and here.
    /// firstBForm: step 14 becomes a chromatic half-step approach (adds tension into next bar).
    private static func bluesPickup(base: Int, chordRoot: Int, scale: [Int],
                                     rng: inout SeededRNG,
                                     firstBForm: Bool = false,
                                     formPosition: Int = 0,
                                     pickupIsB3: Bool = false,
                                     step12Interval: Int = 10,
                                     echoStyle: Int = 0) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let formIndex = formPosition / 16
        let effectivePickupIsB3 = formIndex % 2 == 0 ? pickupIsB3 : !pickupIsB3
        let effectiveEchoStyle  = (echoStyle + formIndex) % 3
        let root       = clampBass(chordRoot)
        let fifth      = clampBass(snapToScale(chordRoot + 7,  scale: scale))
        let b3         = clampBass(snapToScale(chordRoot + 3,  scale: scale))
        let pickupNote = effectivePickupIsB3 ? b3 : fifth
        let step12Note = clampBass(snapToScale(chordRoot + step12Interval, scale: scale))
        // B-form tail: chromatic half-step below root — pulls forward into next bar's landing.
        let tail14     = firstBForm ? clampBass(chordRoot - 1) : fifth

        // Step 0: root (long hold)
        result.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                velocity: UInt8(82 + rng.nextInt(upperBound: 10)), durationSteps: 5))
        // Echo variant: root echo at step 2, silence, or ghost anticipation at step 6
        switch effectiveEchoStyle {
        case 1:  // silence — open space after root hit
            break
        case 2:  // ghost note at step 6 — soft anticipation one step before the pickup
            result.append(MIDIEvent(stepIndex: base + 6, note: UInt8(pickupNote),
                                    velocity: UInt8(42 + rng.nextInt(upperBound: 8)), durationSteps: 1))
        default: // root echo at step 2
            result.append(MIDIEvent(stepIndex: base + 2, note: UInt8(root),
                                    velocity: UInt8(60 + rng.nextInt(upperBound: 10)), durationSteps: 4))
        }
        // Step 7: pickup (the characteristic blues feel — 5th or b3)
        result.append(MIDIEvent(stepIndex: base + 7, note: UInt8(pickupNote),
                                velocity: UInt8(72 + rng.nextInt(upperBound: 10)), durationSteps: 1))
        // Step 8: pickup hold
        result.append(MIDIEvent(stepIndex: base + 8, note: UInt8(pickupNote),
                                velocity: UInt8(78 + rng.nextInt(upperBound: 10)), durationSteps: 4))
        // Step 12: b7 / b3 / 5th
        result.append(MIDIEvent(stepIndex: base + 12, note: UInt8(step12Note),
                                velocity: UInt8(68 + rng.nextInt(upperBound: 10)), durationSteps: 2))
        // Step 14: A-section = 5th (stable); B-form = chromatic approach (tension)
        result.append(MIDIEvent(stepIndex: base + 14, note: UInt8(tail14),
                                velocity: UInt8(64 + rng.nextInt(upperBound: 10)), durationSteps: 2))
        return result
    }

    // MARK: - CHL-BASS-010: Blues Quarter Pulse

    /// CHL-BASS-010: Quarter-note walking feel on chord tones — root, b3, 5th, b7.
    /// Steady and grounded; works under all blues beat styles.
    /// Evolution: `formPosition` (this bar's position within the running 16-bar blues form)
    /// reverses the note order every time the form repeats, and every 4th bar thins out to a
    /// half-time root+5th "breathing" bar so the pattern doesn't loop identically all song long.
    private static func quarterPulse(base: Int, chordRoot: Int, scale: [Int],
                                      formPosition: Int = 0,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let root  = clampBass(chordRoot)
        let b3    = clampBass(snapToScale(chordRoot + 3,  scale: scale))
        let fifth = clampBass(snapToScale(chordRoot + 7,  scale: scale))
        let b7    = clampBass(snapToScale(chordRoot + 10, scale: scale))

        let formIndex   = formPosition / 16
        let reversed    = formIndex % 2 == 1
        let isBreathBar = formPosition % 4 == 3

        if isBreathBar {
            let (n1, n2) = reversed ? (b7, b3) : (root, fifth)
            result.append(MIDIEvent(stepIndex: base,     note: UInt8(n1),
                                    velocity: UInt8(75 + rng.nextInt(upperBound: 12)), durationSteps: 8))
            result.append(MIDIEvent(stepIndex: base + 8, note: UInt8(n2),
                                    velocity: UInt8(70 + rng.nextInt(upperBound: 12)), durationSteps: 8))
            return result
        }

        let ascending: [Int] = [root, b3, fifth, b7]
        let notes: [Int] = reversed ? Array(ascending.reversed()) : ascending
        let steps = [0, 4, 8, 12]
        for (note, step) in zip(notes, steps) {
            let vel = UInt8(75 + rng.nextInt(upperBound: 12))
            result.append(MIDIEvent(stepIndex: base + step, note: UInt8(note),
                                    velocity: vel, durationSteps: 4))
        }
        return result
    }

    // MARK: - CHL-BASS-011: Blues Ascending Riff

    /// CHL-BASS-011: Starts on the 5th (or 6th) — ascending/descending opener into a root landing.
    /// Song-level variants:
    ///   rhythmTemplate — A (default), B (longer landing), C (dotted approach)
    ///   ascendingOpener — true: 5th→6th (up), false: 6th→5th (down) into root
    ///   tailInterval   — +10 b7 (60%), +5 4th (25%), +12 root-octave (15%)
    /// First-16-bar-B-form variants (revert to A behavior afterward):
    ///   bSection       — halves the echo note duration for a tighter feel (2a)
    ///   echoAsFifth    — echo note plays the 5th instead of the root (2b)
    ///   forceTemplateB — overrides rhythmTemplate with B (long landing) (2c)
    private static func bluesAscendingRiff(base: Int, chordRoot: Int, scale: [Int],
                                            rng: inout SeededRNG,
                                            rhythmTemplate: Int,
                                            ascendingOpener: Bool,
                                            tailInterval: Int,
                                            bSection: Bool,
                                            echoAsFifth: Bool = false,
                                            forceTemplateB: Bool = false) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let fifth    = clampBass(snapToScale(chordRoot + 7, scale: scale))
        let sixth    = clampBass(snapToScale(chordRoot + 9, scale: scale))
        let root     = clampBass(chordRoot)
        let tailNote = clampBass(snapToScale(chordRoot + tailInterval, scale: scale))

        // 1b: opener direction — ascending (5th→6th) or descending (6th→5th)
        let opener1 = ascendingOpener ? fifth : sixth
        let opener2 = ascendingOpener ? sixth : fifth

        // 1a/2c: rhythmic templates — [step offsets], [durations] for the 5 events
        // A (default): fast opener, square landing+echo
        // B (long land): opener same, landing holds to step 10, tight echo
        // C (dotted): dotted-eighth opener feel (3+1), square landing+echo
        let steps: [Int]
        let durs:  [Int]
        switch forceTemplateB ? 1 : rhythmTemplate {
        case 1:  // B — longer landing
            steps = [0, 2,  4, 10, 12]
            durs  = [2, 2,  6,  2,  4]
        case 2:  // C — dotted approach
            steps = [0, 3,  4,  8, 12]
            durs  = [3, 1,  4,  4,  4]
        default: // A — original
            steps = [0, 2,  4,  8, 12]
            durs  = [2, 2,  4,  4,  4]
        }

        // 2a: B-section echo halved (index 3 = echo)
        let echoDur  = bSection ? max(1, durs[3] / 2) : durs[3]
        // 2b: echo note — 5th instead of root in first B-form
        let echoNote = echoAsFifth ? fifth : root

        let notes     = [opener1, opener2, root, echoNote, tailNote]
        let durations = [durs[0], durs[1], durs[2], echoDur, durs[4]]
        let vels      = [80, 76, 85, 62, 68]

        for i in 0..<5 {
            result.append(MIDIEvent(stepIndex: base + steps[i],
                                    note: UInt8(notes[i]),
                                    velocity: UInt8(vels[i] + rng.nextInt(upperBound: 10)),
                                    durationSteps: durations[i]))
        }
        return result
    }

    // MARK: - CHL-BASS-012: Rumba Bass

    /// CHL-BASS-012: Five-attack rumba cell (root / m3 / P5 / M6 / tail) derived from the
    /// Beatles "Ballad of John and Yoko" bass part — a laid-back jazz-blues pocket feel.
    /// Steps: 0 (root, Q), 6 (m3, offbeat Q), 10 (P5, 8th), 12 (M6, 8th), 14 (tail, 8th).
    /// m3 (+3 semitones) sits in Dorian and keeps the minor tonality of the surrounding arrangement.
    /// Song-level variants (chosen once, passed from bluesBass):
    ///   isTight       — 4-attack: omit step 14 (20% of songs)
    ///   blues7th      — enables 20%-per-bar substitution of M6 → b7 at step 12
    ///   isBeforeChange — B-section chord-change bars: step 14 = chromatic half-step approach
    ///   doOctaveReset — non-B chord-change bars: step 14 = nextRoot−12 (octave drop)
    /// Turnaround bar (bar 16): handled by the dispatcher as a plain root hold, same as other rules.
    private static func rumbaBassCell(base: Int, chordRoot: Int,
                                       rng: inout SeededRNG,
                                       isTight: Bool,
                                       blues7th: Bool,
                                       isBeforeChange: Bool,
                                       doOctaveReset: Bool,
                                       nextChordRoot: Int) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let root   = clampBass(chordRoot)
        let minor3 = clampBass(chordRoot + 3)   // m3 — in scale for Dorian; matches minor tonality
        let fifth  = clampBass(chordRoot + 7)
        let m6     = clampBass(chordRoot + 9)
        let b7     = clampBass(chordRoot + 10)
        let step12Note = (blues7th && rng.nextDouble() < 0.20) ? b7 : m6

        let vel1 = UInt8(85 + rng.nextInt(upperBound: 8))
        let vel2 = UInt8(80 + rng.nextInt(upperBound: 8))
        let vel3 = UInt8(77 + rng.nextInt(upperBound: 8))
        let vel4 = UInt8(74 + rng.nextInt(upperBound: 8))
        let vel5 = UInt8(71 + rng.nextInt(upperBound: 8))

        result.append(MIDIEvent(stepIndex: base,      note: UInt8(root),       velocity: vel1, durationSteps: 4))
        result.append(MIDIEvent(stepIndex: base + 6,  note: UInt8(minor3),     velocity: vel2, durationSteps: 4))
        result.append(MIDIEvent(stepIndex: base + 10, note: UInt8(fifth),      velocity: vel3, durationSteps: 2))
        result.append(MIDIEvent(stepIndex: base + 12, note: UInt8(step12Note), velocity: vel4, durationSteps: 2))

        if !isTight {
            let tail: Int
            if isBeforeChange {
                tail = clampBass(nextChordRoot - 1)   // chromatic half-step approach (B section)
            } else if doOctaveReset {
                tail = clampBass(nextChordRoot - 12)  // octave drop into next chord root
            } else {
                tail = fifth                          // standard: P5
            }
            result.append(MIDIEvent(stepIndex: base + 14, note: UInt8(tail), velocity: vel5, durationSteps: 2))
        }
        return result
    }

    private static func isBeforeChordChange(bar: Int, structure: SongStructure) -> Bool {
        let current = structure.chordPlan.first { $0.contains(bar: bar) }
        let next    = structure.chordPlan.first { $0.contains(bar: bar + 1) }
        return current?.chordRoot != next?.chordRoot
    }
}
