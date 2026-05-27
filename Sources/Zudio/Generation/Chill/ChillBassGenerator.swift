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
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        // Blues Chill uses dedicated blues bass pool (overrides beat-style routing)
        if bluesVariation {
            return bluesBass(frame: frame, structure: structure, rng: &rng, usedRuleIDs: &usedRuleIDs)
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
        let grooveBars = frame.totalBars - 8  // rough groove length excluding intro/outro
        let statementBar: Int? = grooveBars >= 16
            ? 4 + rng.nextInt(upperBound: grooveBars)   // somewhere in the groove
            : nil
        if statementBar != nil { usedRuleIDs.insert("CHL-BASS-006") }

        var events: [MIDIEvent] = []
        // Build 4-bar ostinato if selected
        let ostinatoPattern: [(Int, Int)]? = useOstinato ? buildOstinatoPattern(frame: frame) : nil

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A
            let chord   = structure.chordPlan.first { $0.contains(bar: bar) }
            let chordRoot = chordRootNote(frame: frame, chord: chord)
            let scale     = scaleNotes(frame: frame, chord: chord)
            let base      = bar * 16

            // Cold start: bar 0 is drums-only, bass silent
            if case .coldStart = structure.introStyle, bar == 0 { continue }

            // Cold stop: final bar silent; crash bar gets a root stab landing with the crash.
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar >= outroEnd - 1 { continue }
                if bar == outroEnd - 2 {
                    events.append(MIDIEvent(stepIndex: base, note: UInt8(clampBass(chordRoot)),
                                            velocity: 80, durationSteps: 3))
                    continue
                }
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
                    // CHL-BASS-004 Air Ostinato: 4-bar repeating figure
                    let patBar = bar % 4
                    let patNotes = ostinato.filter { $0.0 / 16 == patBar }
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
                                                     rng: &rng)
                    } else {
                        events += rootSustainPattern(base: base, chordRoot: chordRoot, scale: scale, rng: &rng)
                    }

                    // CHL-BASS-006 Bass Statement: fires on exactly one designated bar mid-song
                    if let sb = statementBar, bar == sb {
                        events += bassStatement(base: base, chordRoot: chordRoot, scale: scale, rng: &rng)
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

    private static func syncopatedPattern(base: Int, chordRoot: Int, scale: [Int],
                                           nextChordRoot: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let root = clampBass(chordRoot)
        // Step 1: root, 2 beats
        result.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                velocity: UInt8(80 + rng.nextInt(upperBound: 11)), durationSteps: 8))
        // Step 7 (AND beat 2): 5th or approach, 1 beat
        if rng.nextDouble() < 0.70 {
            let fifth = snapToScale(chordRoot + 7, scale: scale)
            result.append(MIDIEvent(stepIndex: base + 6, note: UInt8(clampBass(fifth)),
                                    velocity: UInt8(70 + rng.nextInt(upperBound: 11)), durationSteps: 2))
        }
        // Step 9 (beat 3): root, 1.5 beats
        result.append(MIDIEvent(stepIndex: base + 8, note: UInt8(root),
                                velocity: UInt8(75 + rng.nextInt(upperBound: 11)), durationSteps: 6))
        // Step 15 (AND beat 4): approach tone snapped to scale (leading-tone feel)
        let approach = clampBass(snapToScale(nextChordRoot - 1, scale: scale))
        result.append(MIDIEvent(stepIndex: base + 14, note: UInt8(approach),
                                velocity: UInt8(65 + rng.nextInt(upperBound: 11)), durationSteps: 2))
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

    private static func buildOstinatoPattern(frame: GlobalMusicalFrame) -> [(Int, Int)] {
        // Returns [(stepInPattern, degreeOffsetFromRoot)]
        // 4-bar pattern: (step 0=bar1, 16=bar2, 32=bar3, 48=bar4)
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

            // Cold start: bar 0 is drums-only, bass silent
            if case .coldStart = structure.introStyle, bar == 0 { continue }

            // Cold stop: final bar silent; crash bar gets a root stab landing with the crash.
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar >= outroEnd - 1 { continue }
                if bar == outroEnd - 2 {
                    events.append(MIDIEvent(stepIndex: base, note: UInt8(clampBass(chordRoot)),
                                            velocity: 80, durationSteps: 3))
                    continue
                }
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

            // Cold start/stop guards
            if case .coldStart = structure.introStyle, bar == 0 { continue }
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar >= outroEnd - 1 { continue }
                if bar == outroEnd - 2 {
                    events.append(MIDIEvent(stepIndex: base, note: UInt8(clampBass(chordRoot)),
                                            velocity: 80, durationSteps: 3))
                    continue
                }
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
                    for step in [0, 4, 8, 12] {
                        events.append(MIDIEvent(stepIndex: base + step, note: UInt8(root), velocity: 76, durationSteps: 3))
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

    // MARK: - Blues bass dispatcher (CHL-BASS-009 / CHL-BASS-010 / CHL-BASS-011 / CHL-BASS-012)

    /// Selects one blues bass pattern for the whole song, then applies it per bar.
    /// Pool: CHL-BASS-012 (20%), CHL-BASS-009 (22%), CHL-BASS-011 (22%), CHL-BASS-001 (14%), CHL-BASS-003 (12%), CHL-BASS-010 (10%).
    private static func bluesBass(frame: GlobalMusicalFrame, structure: SongStructure,
                                   rng: inout SeededRNG,
                                   usedRuleIDs: inout Set<String>) -> [MIDIEvent] {
        let roll = rng.nextDouble()
        let useRumba     = roll < 0.20
        let usePickup    = roll >= 0.20 && roll < 0.42
        let useAscending = roll >= 0.42 && roll < 0.64
        let useWalking   = roll >= 0.64 && roll < 0.78
        let usePulse     = roll >= 0.90

        if useRumba          { usedRuleIDs.insert("CHL-BASS-012") }
        else if usePickup    { usedRuleIDs.insert("CHL-BASS-009") }
        else if useAscending { usedRuleIDs.insert("CHL-BASS-011") }
        else if useWalking   { usedRuleIDs.insert("CHL-BASS-001") }
        else if usePulse     { usedRuleIDs.insert("CHL-BASS-010") }
        else                 { usedRuleIDs.insert("CHL-BASS-003") }

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

            // Cold start: bar 0 is drums-only, bass silent
            if case .coldStart = structure.introStyle, bar == 0 { continue }

            // Cold stop guards
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
                if bar >= outroEnd - 1 { continue }
                if bar == outroEnd - 2 {
                    events.append(MIDIEvent(stepIndex: base, note: UInt8(clampBass(chordRoot)),
                                            velocity: 80, durationSteps: 3))
                    continue
                }
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

                // IV and V chords: simplified pattern chosen once per song (ivvIsHold / ivvIsApproach / two-feel).
                // Pickup and rumba bypass this — both handle all chord contexts in their own riff.
                let isIV = chord?.chordRoot == "4" && chord?.chordType == .min7
                let isV  = chord?.chordType == .dom7  // dom7 only appears on V in the blues cycle

                // True for the first full 16-bar blues form in B section — enables B-form variants.
                let isFirstBForm = label == .B && posInForm < 32

                if (isIV || isV) && !usePickup && !useRumba {
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
                                          firstBForm: isFirstBForm,
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
                    events += quarterPulse(base: base, chordRoot: chordRoot, scale: scale, rng: &rng)
                } else {
                    events += walkingLine(bar: bar, chordRoot: chordRoot, scale: scale, rng: &rng)
                }
            }
        }
        return events
    }

    // MARK: - CHL-BASS-009: Blues Pickup

    /// CHL-BASS-009: Root-anchored bass with a pickup on step 7 (5th or b3 of active chord).
    /// Creates forward pull into beat 3; characteristic blues bass pickup feel.
    /// Song-level variants (chosen once, passed from bluesBass):
    ///   pickupIsB3     — pickup note at steps 7–8: b3 (30%) or 5th (70%)
    ///   step12Interval — note at step 12: b7/+10 (60%), b3/+3 (25%), 5th/+7 (15%)
    ///   echoStyle      — 0: root echo at step 2 (65%), 1: silence (20%), 2: ghost at step 6 (15%)
    /// firstBForm: step 14 becomes a chromatic half-step approach (adds tension into next bar).
    private static func bluesPickup(base: Int, chordRoot: Int, scale: [Int],
                                     rng: inout SeededRNG,
                                     firstBForm: Bool = false,
                                     pickupIsB3: Bool = false,
                                     step12Interval: Int = 10,
                                     echoStyle: Int = 0) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let root       = clampBass(chordRoot)
        let fifth      = clampBass(snapToScale(chordRoot + 7,  scale: scale))
        let b3         = clampBass(snapToScale(chordRoot + 3,  scale: scale))
        let pickupNote = pickupIsB3 ? b3 : fifth
        let step12Note = clampBass(snapToScale(chordRoot + step12Interval, scale: scale))
        // B-form tail: chromatic half-step below root — pulls forward into next bar's landing.
        let tail14     = firstBForm ? clampBass(chordRoot - 1) : fifth

        // Step 0: root (long hold)
        result.append(MIDIEvent(stepIndex: base, note: UInt8(root),
                                velocity: UInt8(82 + rng.nextInt(upperBound: 10)), durationSteps: 5))
        // Echo variant: root echo at step 2, silence, or ghost anticipation at step 6
        switch echoStyle {
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
    private static func quarterPulse(base: Int, chordRoot: Int, scale: [Int],
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        let root  = clampBass(chordRoot)
        let b3    = clampBass(snapToScale(chordRoot + 3,  scale: scale))
        let fifth = clampBass(snapToScale(chordRoot + 7,  scale: scale))
        let b7    = clampBass(snapToScale(chordRoot + 10, scale: scale))
        let notes = [root, b3, fifth, b7]
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
