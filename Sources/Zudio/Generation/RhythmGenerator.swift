// RhythmGenerator.swift — generation step 8
// Copyright (c) 2026 Zack Urlocker
// Pulse embellishment: melodic ostinato that follows chord changes.
// Register: MIDI 45–76 (low-mid to mid).
//
// Rule catalog:
//   RHY-001: 8th-note stride — alternating root/fifth/third, active Motorik pulse
//   RHY-002: Quarter-note stride — root-anchored, open and spacious
//   RHY-003: Syncopated Motorik — hits at 0,3,6,8,11,14 (3+3+2+3+3+2 feel)
//   RHY-004: 2-bar melodic riff — scale-tone riff cycling over 2 bars
//   RHY-005: Chord stab — short root+third stabs on beats 2 and 4
//   RHY-006: Arpeggio — quarter-note legato, 5 direction variants:
//              0=up, 1=down, 2=up-down bounce, 3=down-up bounce, 4=ping-pong
//   RHY-007: Chord Chug — root+fifth (or root+fourth) 8th-note power stabs; Motorik Noir only.
//            Creates the "guitar power chord texture" of PiL (Albatross, Careering) — no melodic
//            movement, pure rhythmic mass. 60% P5, 40% P4 voicing.
//   RHY-008: Sparse Stab — same root+fifth dyad as RHY-007, quarter-note spacing, 65% hit
//            probability. More open and spacious than Chord Chug — fits sparser Noir sections.
//            Motorik Noir only.
//   RHY-009: Interleave — root on beats, lower pitch on ands; Motorik Noir only.
//   RHY-010: Single-Note Pulse — single root pitch, 8th-note grid, 75% probability, accent on
//            beats 1+3. No dyad — the mechanical one-pitch throb of Joy Division bass lines
//            (Dead Souls G2 71% unison, Shadowplay E1 50%). Motorik Noir only.
//   RHY-011: Three-One Stab — 3 quick dyad hits (s0,s2,s4), shifted chord at s6, return at s10.
//            From Keith Levene's Religion guitar (PiL): 3+1+1 rhythmic grouping feel. Noir only.
//   RHY-012: Void Stab — root+fifth sustained d8 on beat 1, optional beat-3 re-hit (50%),
//            optional pickup at s14 (40%). Max 3 notes per bar — creates ambient chord wash.
//            From PiL Albatross T3 guitar long sustains. Motorik Noir only.
//   RHY-013: Levene Drop — single-note staccato hits on "and" positions only (s2,s6,s10,s14),
//            45% probability per step, 30% of bars completely silent. Root (55%) / flat7 (30%) /
//            fifth (15%) chosen once per bar — no dyad. From Keith Levene's isolated guitar drops
//            in early PiL (Theme, Annalisa). Motorik Noir only.
//
// Pattern type chosen per section; arpeggio direction fixed for the whole song.
// prevNote tracking gives smooth voice leading across bar lines.

struct RhythmGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil,
        noirVariation: Bool = false
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Arpeggio direction is fixed for the whole song (consistent feel)
        // 0=up  1=down  2=up-down  3=down-up  4=ping-pong
        let arpDirection = rng.nextInt(upperBound: 5)

        // Forced pattern index (nil = pick randomly per section as normal)
        let ruleIDs = ["MOT-RTHM-001", "MOT-RTHM-002", "MOT-RTHM-003",
                       "MOT-RTHM-004", "MOT-RTHM-005", "MOT-RTHM-006", "MOT-RTHM-007", "MOT-RTHM-008",
                       "MOT-RTHM-009", "MOT-RTHM-010", "MOT-RTHM-011", "MOT-RTHM-012", "MOT-RTHM-013"]
        let forcedPatternType: Int? = forceRuleID.flatMap { ruleIDs.firstIndex(of: $0) }

        for section in structure.sections {
            // Rhythm is silent in intro/outro
            guard section.label != .intro && section.label != .outro else { continue }

            // Pick pattern type once per section (or use forced value for all sections)
            // Noir: Chord Chug (idx 6) dominates; dense/melodic patterns suppressed.
            let patternWeights: [Double] = noirVariation
                ? [0.04, 0.10, 0.00, 0.00, 0.00, 0.00, 0.10, 0.14, 0.12, 0.14, 0.14, 0.12, 0.12]
                : [0.30, 0.17, 0.17, 0.13, 0.08, 0.15, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00]
            let patternType = forcedPatternType ?? rng.weightedPick(patternWeights)
            usedRuleIDs.insert(ruleIDs[min(patternType, ruleIDs.count - 1)])

            // prevNote for smooth octave transitions across bar lines
            var prevNote: UInt8? = nil
            // RHY-010: phrase-silence state — resets at each new section
            var rhy010SilentGroup = false

            // For RHY-004: build a 2-bar riff once per section
            let riffPattern = buildMelodicRiff(rng: &rng)
            let riffScalePCs = frame.scalePCs

            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }

                // Intensity arc: drives how many steps actually fire
                let intensity = section.subPhaseIntensity(atBar: bar)
                let density: Double
                switch intensity {
                case .low:    density = 0.72
                case .medium: density = 0.88
                case .high:   density = 1.00
                }

                let barStart = bar * 16
                let pitches  = chordPitches(entry: entry, frame: frame, prevNote: prevNote)

                switch patternType {
                case 0:
                    // RHY-001: 8th-note pulse — root on beat 1, cycle root/fifth/third
                    let cycle: [UInt8] = [pitches.root, pitches.fifth, pitches.third, pitches.fifth]
                    for (idx, step) in (Swift.stride(from: 0, to: 16, by: 2)).enumerated() {
                        guard rng.nextDouble() < density else { continue }
                        let note = (step == 0) ? pitches.root : cycle[idx % 4]
                        let vel  = UInt8(step == 0 ? 82 : 62 + rng.nextInt(upperBound: 14))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 2))
                        prevNote = note
                    }

                case 1:
                    // RHY-002: quarter-note, root on 1+3, fifth on 2+4
                    for (i, step) in [0, 4, 8, 12].enumerated() {
                        guard rng.nextDouble() < density else { continue }
                        let note: UInt8 = (i % 2 == 0) ? pitches.root : pitches.fifth
                        let vel  = UInt8(step == 0 ? 86 : 65 + rng.nextInt(upperBound: 12))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 3))
                        prevNote = note
                    }

                case 2:
                    // RHY-003: syncopated Motorik — 3+3+2+3+3+2 pattern
                    let rhy3Cycle: [UInt8] = [pitches.root, pitches.fifth, pitches.third,
                                              pitches.root, pitches.fifth, pitches.flat7]
                    for (i, step) in [0, 3, 6, 8, 11, 14].enumerated() {
                        guard rng.nextDouble() < density else { continue }
                        let note = (step == 0) ? pitches.root : rhy3Cycle[i % rhy3Cycle.count]
                        let vel  = UInt8(step == 0 ? 84 : 63 + rng.nextInt(upperBound: 16))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 2))
                        prevNote = note
                    }

                case 3:
                    // RHY-004: 2-bar melodic riff cycling over the section
                    // Snap each note to the nearest in-scale MIDI pitch so chord-root offsets
                    // (e.g. interval 3 from D in B Dorian → F natural) don't leak through.
                    let riffBar = (bar - section.startBar) % 2
                    let riffSlice = riffBar == 0 ? Array(riffPattern.prefix(4))
                                                 : Array(riffPattern.suffix(4))
                    for (i, step) in [0, 4, 8, 12].enumerated() {
                        guard i < riffSlice.count else { continue }
                        guard rng.nextDouble() < density else { continue }
                        let rawTarget = Int(pitches.root) + riffSlice[i]
                        let note = nearestScaleMIDI(target: rawTarget, scalePCs: riffScalePCs,
                                                    low: 45, high: 76)
                        let vel = UInt8(step == 0 ? 85 : 65 + rng.nextInt(upperBound: 12))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 3))
                        prevNote = note
                    }

                case 4:
                    // RHY-005: chord stab — root+third on beats 2 and 4
                    for step in [4, 12] {
                        guard rng.nextDouble() < density else { continue }
                        let vel = UInt8(72 + rng.nextInt(upperBound: 14))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: pitches.root,
                                                velocity: vel, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: pitches.third,
                                                velocity: UInt8(vel - 6), durationSteps: 2))
                        prevNote = pitches.third
                    }

                case 6:
                    // RHY-007: Chord Chug — root+fifth (or root+P4) power stabs on every 8th, Noir only.
                    // No melodic movement — pure rhythmic texture, guitar-chug feel (PiL, Wire).
                    let chugUpper: UInt8
                    if rng.nextDouble() < 0.40 {
                        chugUpper = nearestScaleMIDI(target: Int(pitches.root) + 5,
                                                     scalePCs: riffScalePCs, low: 45, high: 76)
                    } else {
                        chugUpper = pitches.fifth
                    }
                    for step in Swift.stride(from: 0, to: 16, by: 2) {
                        guard rng.nextDouble() < density else { continue }
                        let accentBoost: UInt8 = (step % 8 == 0) ? 6 : 0
                        let velBase = UInt8(72 + rng.nextInt(upperBound: 9))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: pitches.root,
                                                velocity: velBase + accentBoost, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: chugUpper,
                                                velocity: velBase, durationSteps: 2))
                        prevNote = pitches.root
                    }

                case 7:
                    // RHY-008: Sparse Stab — same dyad as RHY-007, quarter-note hits, 65% probability.
                    // More open than Chord Chug — space between hits is the texture. Noir only.
                    let stabUpper: UInt8
                    if rng.nextDouble() < 0.40 {
                        stabUpper = nearestScaleMIDI(target: Int(pitches.root) + 5,
                                                     scalePCs: riffScalePCs, low: 45, high: 76)
                    } else {
                        stabUpper = pitches.fifth
                    }
                    for step in Swift.stride(from: 0, to: 16, by: 4) {
                        guard rng.nextDouble() < 0.65 else { continue }
                        let accentBoost: UInt8 = (step == 0) ? 6 : 0
                        let velBase = UInt8(70 + rng.nextInt(upperBound: 10))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: pitches.root,
                                                velocity: velBase + accentBoost, durationSteps: 3))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: stabUpper,
                                                velocity: velBase, durationSteps: 3))
                        prevNote = pitches.root
                    }

                case 8:
                    // RHY-009: Interleave — root on beats (0,4,8,12), lower pitch on ands (2,6,10,14).
                    // Never simultaneous — the two voices alternate, creating angular two-voice texture.
                    // Based on PiL "Not A Love Song" guitar pattern.
                    let interLower: UInt8
                    if rng.nextDouble() < 0.40 {
                        interLower = nearestMIDI(target: Int(pitches.root) - 5, low: 45, high: 74, prev: prevNote)
                    } else {
                        interLower = nearestMIDI(target: Int(pitches.root) - 7, low: 45, high: 74, prev: prevNote)
                    }
                    for beatStep in Swift.stride(from: 0, to: 16, by: 4) {
                        guard rng.nextDouble() < 0.65 else { continue }
                        let beatVel = UInt8(74 + rng.nextInt(upperBound: 10))
                        let andVel  = UInt8(62 + rng.nextInt(upperBound: 8))
                        events.append(MIDIEvent(stepIndex: barStart + beatStep,     note: pitches.root,
                                                velocity: beatVel, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: barStart + beatStep + 2, note: interLower,
                                                velocity: andVel,  durationSteps: 2))
                        prevNote = pitches.root
                    }

                case 9:
                    // RHY-010: Single-Note Pulse — 8th-note grid, accented beats 1+3. Noir only.
                    // Phrase silence: 30% of 4-bar groups go completely silent.
                    // Density follows section intensity arc (50/65/82%).
                    // Pitch: 80% root, 15% P5-below, 5% flat-7 — chosen once per bar.
                    if bar % 4 == 0 { rhy010SilentGroup = rng.nextDouble() < 0.30 }
                    if !rhy010SilentGroup {
                        let pulseDensity: Double
                        switch intensity {
                        case .low:    pulseDensity = 0.50
                        case .medium: pulseDensity = 0.65
                        case .high:   pulseDensity = 0.82
                        }
                        let pitchRoll = rng.nextDouble()
                        let pulseNote: UInt8
                        if pitchRoll < 0.80 {
                            pulseNote = pitches.root
                        } else if pitchRoll < 0.95 {
                            pulseNote = nearestMIDI(target: Int(pitches.root) - 7, low: 45, high: 76, prev: prevNote)
                        } else {
                            pulseNote = pitches.flat7
                        }
                        for step in Swift.stride(from: 0, to: 16, by: 2) {
                            guard rng.nextDouble() < pulseDensity else { continue }
                            let accentBoost: UInt8 = (step % 8 == 0) ? 8 : 0
                            let vel = UInt8(clamping: 68 + rng.nextInt(upperBound: 10) + Int(accentBoost))
                            events.append(MIDIEvent(stepIndex: barStart + step, note: pulseNote,
                                                    velocity: vel, durationSteps: 2))
                            prevNote = pulseNote
                        }
                    }

                case 10:
                    // RHY-011: Three-One Stab — 3 quick dyad hits at s0,s2,s4 (d2), then a shifted
                    // chord at s6 (d4), then root return at s10 (d5). From Keith Levene's Religion
                    // guitar (PiL): the 3+1+1 rhythmic grouping in bars 6/8/10. Noir only.
                    let toUpper: UInt8 = rng.nextDouble() < 0.40
                        ? nearestScaleMIDI(target: Int(pitches.root) + 5, scalePCs: riffScalePCs, low: 45, high: 76)
                        : pitches.fifth
                    let shiftNote: UInt8 = rng.nextDouble() < 0.60 ? pitches.flat7 : pitches.third
                    for step in [0, 2, 4] {
                        guard rng.nextDouble() < density else { continue }
                        let vel = UInt8(clamping: 72 + rng.nextInt(upperBound: 12) + (step == 0 ? 6 : 0))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: pitches.root,
                                                velocity: vel, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: toUpper,
                                                velocity: UInt8(clamping: Int(vel) - 5), durationSteps: 2))
                    }
                    if rng.nextDouble() < density {
                        let vel = UInt8(70 + rng.nextInt(upperBound: 10))
                        events.append(MIDIEvent(stepIndex: barStart + 6, note: pitches.root,
                                                velocity: vel, durationSteps: 4))
                        events.append(MIDIEvent(stepIndex: barStart + 6, note: shiftNote,
                                                velocity: UInt8(clamping: Int(vel) - 4), durationSteps: 4))
                    }
                    if rng.nextDouble() < density {
                        let vel = UInt8(68 + rng.nextInt(upperBound: 12))
                        events.append(MIDIEvent(stepIndex: barStart + 10, note: pitches.root,
                                                velocity: vel, durationSteps: 5))
                        events.append(MIDIEvent(stepIndex: barStart + 10, note: toUpper,
                                                velocity: UInt8(clamping: Int(vel) - 5), durationSteps: 5))
                    }
                    prevNote = pitches.root

                case 11:
                    // RHY-012: Void Stab — root+fifth held d8 on beat 1, optional beat-3 hit (50%),
                    // optional pickup at s14 (40%). Maximum 3 notes per bar — ambient chord wash.
                    // From PiL Albatross T3 guitar: full-bar sustains with sparse melodic fragments.
                    // Noir only.
                    let voidUpper: UInt8 = rng.nextDouble() < 0.40
                        ? nearestScaleMIDI(target: Int(pitches.root) + 5, scalePCs: riffScalePCs, low: 45, high: 76)
                        : pitches.fifth
                    let velBeat1 = UInt8(74 + rng.nextInt(upperBound: 10))
                    events.append(MIDIEvent(stepIndex: barStart, note: pitches.root,
                                            velocity: velBeat1, durationSteps: 8))
                    events.append(MIDIEvent(stepIndex: barStart, note: voidUpper,
                                            velocity: UInt8(clamping: Int(velBeat1) - 6), durationSteps: 8))
                    if rng.nextDouble() < 0.50 {
                        let velBeat3 = UInt8(65 + rng.nextInt(upperBound: 10))
                        events.append(MIDIEvent(stepIndex: barStart + 8, note: pitches.root,
                                                velocity: velBeat3, durationSteps: 4))
                        events.append(MIDIEvent(stepIndex: barStart + 8, note: voidUpper,
                                                velocity: UInt8(clamping: Int(velBeat3) - 6), durationSteps: 4))
                    }
                    if rng.nextDouble() < 0.40 {
                        events.append(MIDIEvent(stepIndex: barStart + 14, note: pitches.root,
                                                velocity: UInt8(60 + rng.nextInt(upperBound: 10)), durationSteps: 2))
                    }
                    prevNote = pitches.root

                case 12:
                    // RHY-013: Levene Drop — staccato single notes on "and" positions only.
                    // 30% of bars silent; 45% hit probability per off-beat step.
                    // Root (55%) / flat7 (30%) / fifth (15%) chosen once per bar — no dyad.
                    guard rng.nextDouble() >= 0.30 else { break }
                    let r13 = rng.nextDouble()
                    let dropNote: UInt8 = r13 < 0.55 ? pitches.root
                                       : r13 < 0.85 ? pitches.flat7
                                       : pitches.fifth
                    for step in [2, 6, 10, 14] {
                        guard rng.nextDouble() < 0.45 else { continue }
                        let vel = UInt8(clamping: 60 + rng.nextInt(upperBound: 16))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: dropNote,
                                                velocity: vel, durationSteps: 2))
                        prevNote = dropNote
                    }

                default:
                    // RHY-006: arpeggio — quarter-note legato, direction fixed per song
                    let arpNotes = buildArpNotes(entry: entry, frame: frame, direction: arpDirection)
                    guard !arpNotes.isEmpty else { break }
                    var arpEvents: [MIDIEvent] = []
                    for i in 0..<4 {
                        let note = arpNotes[i % arpNotes.count]
                        let vel  = UInt8(i == 0 ? min(110, Int(pitches.root) > 0 ? 80 : 72)
                                                : 62 + rng.nextInt(upperBound: 14))
                        arpEvents.append(MIDIEvent(stepIndex: barStart + i * 4, note: note,
                                                   velocity: vel, durationSteps: 3))
                    }
                    // Legato fill: extend each note to (next_onset − 1), min 4
                    for i in 0..<arpEvents.count {
                        let nextOnset = (i + 1 < arpEvents.count)
                            ? arpEvents[i + 1].stepIndex : barStart + 16
                        let legatoDur = max(4, min(nextOnset - arpEvents[i].stepIndex - 1, 12))
                        events.append(MIDIEvent(stepIndex: arpEvents[i].stepIndex,
                                                note:      arpEvents[i].note,
                                                velocity:  arpEvents[i].velocity,
                                                durationSteps: legatoDur))
                        prevNote = arpEvents[i].note
                    }
                }
            }
        }

        return events
    }

    // MARK: - Pitch helpers

    private struct ChordPitches {
        let root:  UInt8
        let fifth: UInt8
        let third: UInt8
        let flat7: UInt8
    }

    /// Derives root, fifth, third, and flat-7 for the current chord window.
    /// prevNote anchors the register so notes don't jump across bar lines.
    private static func chordPitches(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, prevNote: UInt8?
    ) -> ChordPitches {
        let keyS   = keySemitone(frame.key)
        let rootPC = (keyS + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        let isMajorThird = entry.chordWindow.chordType == .major ||
                           entry.chordWindow.chordType == .dom7  ||
                           entry.chordWindow.chordType == .add9  ||
                           entry.chordWindow.chordType == .sus4  ||
                           entry.chordWindow.chordType == .power
        let fifthPC = (rootPC + 7) % 12
        // Snap third and flat-7 to nearest in-scale pitch class to prevent chromatic leakage
        // when the chord root is non-tonic (e.g. Bbsus2 in G Dorian: raw minor-3rd = C# OOS).
        let scalePCsSet = frame.scalePCs
        let rawThird = (rootPC + (isMajorThird ? 4 : 3)) % 12
        let thirdPC  = nearestScalePitchClass(rawThird, in: scalePCsSet)
        let rawFlat7 = (rootPC + 10) % 12
        let flat7PC  = nearestScalePitchClass(rawFlat7, in: scalePCsSet)

        let root  = nearestMIDI(target: findMIDI(pc: rootPC,  ref: 57), low: 45, high: 72, prev: prevNote)
        let fifth = nearestMIDI(target: findMIDI(pc: fifthPC, ref: 57), low: 48, high: 76, prev: prevNote)
        let third = nearestMIDI(target: findMIDI(pc: thirdPC, ref: 57), low: 45, high: 76, prev: prevNote)
        let flat7 = nearestMIDI(target: findMIDI(pc: flat7PC, ref: 57), low: 45, high: 76, prev: prevNote)

        return ChordPitches(root: root, fifth: fifth, third: third, flat7: flat7)
    }

    // MARK: - Arpeggio builder (RHY-006)

    /// Builds an ordered MIDI note sequence from chord tones in the Rhythm register (45–76).
    ///
    /// Directions:
    ///   0 = up           (1 2 3 4 …)
    ///   1 = down         (… 4 3 2 1)
    ///   2 = up-down      (1 2 3 4 3 2 …  — no endpoint repeats)
    ///   3 = down-up      (4 3 2 1 2 3 …  — no endpoint repeats)
    ///   4 = ping-pong    (1 N 2 N-1 3 …  — alternating low/high inward)
    private static func buildArpNotes(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, direction: Int
    ) -> [UInt8] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        let chordIntervals: [Int]
        switch entry.chordWindow.chordType {
        case .major:   chordIntervals = [0, 4, 7]
        case .minor:   chordIntervals = [0, 3, 7]
        case .sus2:    chordIntervals = [0, 2, 7]
        case .sus4:    chordIntervals = [0, 5, 7]
        case .dom7:    chordIntervals = [0, 4, 7, 10]
        case .min7:    chordIntervals = [0, 3, 7, 10]
        case .add9:    chordIntervals = [0, 4, 7, 14]
        case .quartal: chordIntervals = [0, 5, 10]
        case .power:   chordIntervals = [0, 7, 12]
        }

        var ascending: [UInt8] = []
        for octave in 3...6 {
            for interval in chordIntervals {
                let pc   = (rootPC + interval) % 12
                let midi = octave * 12 + pc
                if midi >= 45 && midi <= 76 { ascending.append(UInt8(midi)) }
            }
        }
        ascending.sort()
        guard ascending.count >= 2 else { return ascending }

        switch direction {
        case 0:  // up
            return ascending

        case 1:  // down
            return Array(ascending.reversed())

        case 2:  // up-down bounce
            var seq = ascending
            seq += Array(ascending.dropFirst().dropLast().reversed())
            return seq

        case 3:  // down-up bounce
            let desc = Array(ascending.reversed())
            var seq  = desc
            seq += Array(desc.dropFirst().dropLast().reversed())
            return seq

        default: // 4 ping-pong: alternate low/high inward
            var lo = 0, hi = ascending.count - 1
            var seq: [UInt8] = []
            while lo <= hi {
                seq.append(ascending[lo]); lo += 1
                if lo <= hi { seq.append(ascending[hi]); hi -= 1 }
            }
            return seq
        }
    }

    // MARK: - Note helpers

    /// Returns the MIDI note closest to `ref` that has pitch class `pc`.
    private static func findMIDI(pc: Int, ref: Int) -> Int {
        let base = (ref / 12) * 12 + pc
        let candidates = [base - 12, base, base + 12]
        return candidates.min(by: { abs($0 - ref) < abs($1 - ref) }) ?? base
    }

    /// Picks the octave of `target` that stays in [low, high] and is closest to `prev`.
    private static func nearestMIDI(target: Int, low: Int, high: Int, prev: UInt8?) -> UInt8 {
        var candidates: [Int] = []
        var t = target
        while t > high { t -= 12 }
        while t < low  { t += 12 }
        if t >= low && t <= high { candidates.append(t) }
        var up = t + 12; while up <= high { candidates.append(up); up += 12 }
        var dn = t - 12; while dn >= low  { candidates.append(dn); dn -= 12 }
        if candidates.isEmpty { return UInt8(clamping: low) }
        if let p = prev {
            return UInt8(clamping: candidates.min(by: { abs($0 - Int(p)) < abs($1 - Int(p)) }) ?? low)
        }
        let mid = (low + high) / 2
        return UInt8(clamping: candidates.min(by: { abs($0 - mid) < abs($1 - mid) }) ?? low)
    }

    /// Builds a random 8-step (2-bar) melodic riff as semitone intervals from root.
    /// Notes are snapped to the active scale at the usage site (RHY-004), not here —
    /// snapping at the interval level is insufficient when the chord root differs from the key root.
    private static func buildMelodicRiff(rng: inout SeededRNG) -> [Int] {
        let pool = [0, 0, 2, 3, 4, 5, 7, 7, 9, 10]
        return (0..<8).map { _ in pool[rng.nextInt(upperBound: pool.count)] }
    }

    /// Returns the MIDI note in [low, high] whose pitch class is in scalePCs and is
    /// closest to target. Falls back to unclamped target if no scale note exists in range.
    private static func nearestScaleMIDI(target: Int, scalePCs: Set<Int>, low: Int, high: Int) -> UInt8 {
        let candidates = (low...high).filter { scalePCs.contains($0 % 12) }
        guard !candidates.isEmpty else { return UInt8(clamping: target) }
        return UInt8(clamping: candidates.min(by: { abs($0 - target) < abs($1 - target) }) ?? low)
    }
}
