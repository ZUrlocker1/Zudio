// KosmicStructureGenerator.swift — Kosmic generation step 2
// Copyright (c) 2026 Zack Urlocker
// Produces a SongStructure for Kosmic style with long sections and glacial pacing.
//
// Supported song forms: single_evolving, ab, aba, abab, abba
// Bridge archetypes (35% of ab/aba songs):
//   .bridge       — A-1 escalating drum bridge (Mister Mosca style, 4-8 bars)
//   .bridgeAlt    — A-2 sparse hit + call-and-response (Caligari Drop style, 4-8 bars)
//   .bridgeMelody — Archetype B melody bridge (Dark Sun style, 16-24 bars + pre/post ramps)
//
// Kosmic Space never takes a base bridge section (the roll is still consumed), and its body sections
// loop a chord cycle of 2- and 4-bar windows instead of the 1–2 long random chords
// (`buildSpaceChordPlan`). Its own bridge is a mute schedule over the end of the first A section
// (`SpaceBridge`), not a section.

struct KosmicStructureGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        kosmicForm: KosmicSongForm,
        kosmicProgFamily: KosmicProgressionFamily,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG,
        forceBridge: Bool = false,
        isKosmicDrift: Bool = false,
        isKosmicSpace: Bool = false,
        seed: UInt64 = 0
    ) -> SongStructure {
        let (sections, introStyle, outroStyle) = buildSections(
            form: kosmicForm,
            totalBars: frame.totalBars,
            percussionStyle: percussionStyle,
            rng: &rng,
            forceBridge: forceBridge,
            isKosmicDrift: isKosmicDrift,
            isKosmicSpace: isKosmicSpace
        )
        // Space still runs the base chord builder so the main stream is consumed exactly as
        // before (the title is drawn from it afterwards), then replaces the plan with its cycle.
        let basePlan = buildChordPlan(
            frame: frame,
            sections: sections,
            kosmicProgFamily: kosmicProgFamily,
            rng: &rng
        )
        let chordPlan: [ChordWindow]
        if isKosmicSpace {
            var cycleRNG = KosmicSpaceStream.chordCycle.rng(seed: seed)
            let cyclePlan = buildSpaceChordPlan(frame: frame, sections: sections,
                                                family: kosmicProgFamily, rng: &cycleRNG)
            chordPlan = applySpaceBridgeChords(plan: cyclePlan, frame: frame, family: kosmicProgFamily,
                                               bridge: SpaceBridge.make(sections: sections, seed: seed))
        } else {
            chordPlan = basePlan
        }
        return SongStructure(sections: sections, chordPlan: chordPlan,
                             introStyle: introStyle, outroStyle: outroStyle)
    }

    // MARK: - Section layout

    private static func buildSections(
        form: KosmicSongForm,
        totalBars: Int,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG,
        forceBridge: Bool = false,
        isKosmicDrift: Bool = false,
        isKosmicSpace: Bool = false
    ) -> (sections: [SongSection], introStyle: IntroStyle, outroStyle: OutroStyle) {

        // Kosmic intro: 2 bars (25%), 4 bars (62.5%), 8 bars (12.5%).
        // Every intro and outro length is even, and totalBars is a multiple of 4, so every
        // section starts on an even bar — which Kosmic Space's chord cycle relies on.
        let introLengths: [Int]    = [2,    4,     8    ]
        let introWeights: [Double] = [0.25, 0.625, 0.125]
        let introBars = introLengths[rng.weightedPick(introWeights)]
        // Kosmic outro: mirrors intro distribution — 2 bars (25%), 4 bars (62.5%), 8 bars (12.5%)
        let outroLengths:        [Int]    = [2,    4,     8    ]
        let outroLengthWeights:  [Double] = [0.25, 0.625, 0.125]
        let outroBars = outroLengths[rng.weightedPick(outroLengthWeights)]
        let bodyBars  = Swift.max(4, totalBars - introBars - outroBars)

        var sections: [SongSection] = []
        var cursor = 0

        // Intro
        sections.append(SongSection(startBar: cursor, lengthBars: introBars,
                                    label: .intro, intensity: .low, mode: .Dorian))
        cursor += introBars

        // Body — build raw sections then optionally insert bridge
        var bodySections = buildBodySections(form: form, bodyBars: bodyBars, cursor: cursor, rng: &rng)
        bodySections = insertBridgeIfNeeded(form: form, sections: bodySections, rng: &rng,
                                            forceBridge: forceBridge, isKosmicDrift: isKosmicDrift,
                                            isKosmicSpace: isKosmicSpace)
        sections.append(contentsOf: bodySections)
        cursor += bodyBars

        // Outro
        let lastMode = bodySections.last?.mode ?? .Dorian
        sections.append(SongSection(startBar: cursor, lengthBars: outroBars,
                                    label: .outro, intensity: .low, mode: lastMode))

        // Intro style
        let introStyle: IntroStyle
        let usesRockGroove = (percussionStyle == .motorikGrid || percussionStyle == .electricBuddhaPulse)
        if usesRockGroove {
            let r = rng.nextDouble()
            if r < 0.60      { introStyle = .coldStart(drumsOnly: true) }
            else if r < 0.80 { introStyle = .progressiveEntry }
            else             { introStyle = .alreadyPlaying }
        } else {
            switch rng.nextInt(upperBound: 3) {
            case 0:  introStyle = .alreadyPlaying
            case 1:  introStyle = .progressiveEntry
            default: introStyle = .coldStart(drumsOnly: false)
            }
        }

        // Outro style
        let outroStyles: [OutroStyle] = [.dissolve, .fade, .coldStop]
        let outroWeights: [Double]    = [0.50,      0.40, 0.10]
        let outroStyle = outroStyles[rng.weightedPick(outroWeights)]

        return (sections, introStyle, outroStyle)
    }

    // MARK: - Body section builders

    private static func bMode(_ rng: inout SeededRNG) -> Mode {
        // Aeolian 45%, Mixolydian 35%, Aeolian (Phrygian flavour) 20% → Aeolian 65%, Mixolydian 35%
        let modes:   [Mode]   = [.Aeolian, .Mixolydian, .Aeolian]
        let weights: [Double] = [0.45,     0.35,         0.20]
        return modes[rng.weightedPick(weights)]
    }

    private static func buildBodySections(
        form: KosmicSongForm, bodyBars: Int, cursor: Int, rng: inout SeededRNG
    ) -> [SongSection] {
        switch form {

        case .single_evolving:
            return [SongSection(startBar: cursor, lengthBars: bodyBars,
                                label: .A, intensity: .medium, mode: .Dorian)]

        case .ab, .two_world:
            // A (60%) → B (40%), each at least 16 bars
            let aLen = Swift.max(24, (Int(Double(bodyBars) * 0.60) / 4) * 4)
            let bLen = Swift.max(16, bodyBars - aLen)
            return [
                SongSection(startBar: cursor,        lengthBars: aLen, label: .A, intensity: .low,    mode: .Dorian),
                SongSection(startBar: cursor + aLen, lengthBars: bLen, label: .B, intensity: .medium, mode: bMode(&rng))
            ]

        case .aba, .build_and_dissolve:
            // A1 (35%) → B (30%) → A2 (35%), each at least 16 bars (A) / 16 bars (B)
            let aLen1 = Swift.max(24, (Int(Double(bodyBars) * 0.35) / 4) * 4)
            let bLen  = Swift.max(16, (Int(Double(bodyBars) * 0.30) / 4) * 4)
            let aLen2 = Swift.max(16, bodyBars - aLen1 - bLen)
            let bm = bMode(&rng)
            return [
                SongSection(startBar: cursor,                    lengthBars: aLen1, label: .A, intensity: .low,    mode: .Dorian),
                SongSection(startBar: cursor + aLen1,            lengthBars: bLen,  label: .B, intensity: .high,   mode: bm),
                SongSection(startBar: cursor + aLen1 + bLen,     lengthBars: aLen2, label: .A, intensity: .medium, mode: .Dorian)
            ]

        case .abab:
            // A1 (25%) → B1 (25%) → A2 (25%) → B2 (25%), each at least 16 bars
            let quarter = Swift.max(16, (bodyBars / 4 / 4) * 4)
            let leftover = bodyBars - quarter * 3
            let a1Len = quarter; let b1Len = quarter; let a2Len = quarter
            let b2Len = Swift.max(16, leftover)
            let bm1 = bMode(&rng)
            let bm2 = bMode(&rng)
            var pos = cursor
            var secs: [SongSection] = []
            secs.append(SongSection(startBar: pos, lengthBars: a1Len, label: .A, intensity: .low,    mode: .Dorian)); pos += a1Len
            secs.append(SongSection(startBar: pos, lengthBars: b1Len, label: .B, intensity: .medium, mode: bm1));    pos += b1Len
            secs.append(SongSection(startBar: pos, lengthBars: a2Len, label: .A, intensity: .medium, mode: .Dorian)); pos += a2Len
            secs.append(SongSection(startBar: pos, lengthBars: b2Len, label: .B, intensity: .high,   mode: bm2))
            return secs

        case .abba:
            // A1 (25%) → B1 (25%) → B2 (25%) → A2 (25%), B2 same mode as B1
            let quarter = Swift.max(16, (bodyBars / 4 / 4) * 4)
            let leftover = bodyBars - quarter * 3
            let a1Len = quarter; let b1Len = quarter; let b2Len = quarter
            let a2Len = Swift.max(16, leftover)
            let bm = bMode(&rng)
            var pos = cursor
            var secs: [SongSection] = []
            secs.append(SongSection(startBar: pos, lengthBars: a1Len, label: .A, intensity: .low,    mode: .Dorian)); pos += a1Len
            secs.append(SongSection(startBar: pos, lengthBars: b1Len, label: .B, intensity: .medium, mode: bm));     pos += b1Len
            secs.append(SongSection(startBar: pos, lengthBars: b2Len, label: .B, intensity: .high,   mode: bm));     pos += b2Len
            secs.append(SongSection(startBar: pos, lengthBars: a2Len, label: .A, intensity: .medium, mode: .Dorian))
            return secs
        }
    }

    // MARK: - Bridge insertion

    /// Probabilistically inserts a bridge between the first A and first B section.
    /// Only for ab/aba forms. 35% chance. Bars are taken from the preceding A section.
    private static func insertBridgeIfNeeded(
        form: KosmicSongForm, sections: [SongSection], rng: inout SeededRNG,
        forceBridge: Bool = false, isKosmicDrift: Bool = false, isKosmicSpace: Bool = false
    ) -> [SongSection] {
        // Only ab/aba forms get bridges
        guard form == .ab || form == .two_world || form == .aba || form == .build_and_dissolve else {
            return sections
        }
        // Kosmic Space: no bridges. The roll is still drawn so the stream stays in step.
        if isKosmicSpace {
            if !forceBridge { _ = rng.nextDouble() }
            return sections
        }
        // Drift: 80% during testing (reduce to 30% for release); base Kosmic: 35%.
        let bridgeProb: Double = isKosmicDrift ? 0.80 : 0.35
        guard forceBridge || rng.nextDouble() < bridgeProb else { return sections }

        // Find the index of the first A→B boundary
        guard let aIdx = sections.firstIndex(where: { $0.label == .A }),
              aIdx + 1 < sections.count,
              sections[aIdx + 1].label == .B else { return sections }

        let aSection = sections[aIdx]

        let archetype: String = rng.nextDouble() < 0.50 ? "drumBridge" : "melodyBridge"

        // Drift songs are shorter (~80 bars vs ~120). Reduce the minimum A-section remainder
        // so bridges can fit — otherwise the length guard blocks most bridge attempts.
        let minARemain = forceBridge ? 12 : (isKosmicDrift ? 16 : 24)

        if archetype == "drumBridge" {
            // A-1 or A-2: 4 bars (70%) or 8 bars (30%)
            let bridgeBars = rng.nextDouble() < 0.70 ? 4 : 8
            guard aSection.lengthBars - bridgeBars >= minARemain else { return sections }

            let subVariant: SectionLabel = rng.nextDouble() < 0.50 ? .bridge : .bridgeAlt
            let newALen  = aSection.lengthBars - bridgeBars
            let bridgeStart = aSection.startBar + newALen

            var result = sections
            result[aIdx] = SongSection(startBar: aSection.startBar, lengthBars: newALen,
                                       label: .A, intensity: aSection.intensity, mode: aSection.mode)
            result.insert(SongSection(startBar: bridgeStart, lengthBars: bridgeBars,
                                      label: subVariant, intensity: .high, mode: aSection.mode),
                          at: aIdx + 1)
            return reassignStartBars(result)

        } else {
            // Archetype B (melody bridge): 8 bars (40%), 12 bars (35%), 16 bars (18%), 24 bars (7%)
            let bridgeLengths: [Int]    = [8,    12,   16,   24  ]
            let bridgeWeights: [Double] = [0.40, 0.35, 0.18, 0.07]
            let bridgeBars = bridgeLengths[rng.weightedPick(bridgeWeights)]
            // Ramps: normally 6-8 bars each; shorten aggressively if A section is tight
            var rampLen = rng.nextInt(upperBound: 3) + 6  // 6-8
            let totalExtra = bridgeBars + rampLen * 2
            if aSection.lengthBars - totalExtra < 24 { rampLen = 4 }
            if aSection.lengthBars - (bridgeBars + rampLen * 2) < minARemain { rampLen = 0 }
            let totalExtrafinal = bridgeBars + rampLen * 2
            guard aSection.lengthBars - totalExtrafinal >= minARemain else { return sections }

            let newALen    = aSection.lengthBars - totalExtrafinal
            var pos        = aSection.startBar + newALen

            var result = sections
            result[aIdx] = SongSection(startBar: aSection.startBar, lengthBars: newALen,
                                       label: .A, intensity: aSection.intensity, mode: aSection.mode)
            let preRamp = SongSection(startBar: pos, lengthBars: rampLen,
                                      label: .preRamp, intensity: .medium, mode: aSection.mode)
            pos += rampLen
            let bridgeSec = SongSection(startBar: pos, lengthBars: bridgeBars,
                                        label: .bridgeMelody, intensity: .high, mode: aSection.mode)
            pos += bridgeBars
            let postRamp = SongSection(startBar: pos, lengthBars: rampLen,
                                       label: .postRamp, intensity: .medium, mode: aSection.mode)

            result.insert(contentsOf: [preRamp, bridgeSec, postRamp], at: aIdx + 1)
            return reassignStartBars(result)
        }
    }

    /// Reassigns startBars sequentially after insertion/modification.
    /// Preserves the offset of the first section so body sections remain correctly
    /// positioned after the intro (cursor is already baked into sections[0].startBar).
    private static func reassignStartBars(_ sections: [SongSection]) -> [SongSection] {
        guard !sections.isEmpty else { return sections }
        var result: [SongSection] = []
        var pos = sections[0].startBar
        for sec in sections {
            result.append(SongSection(startBar: pos, lengthBars: sec.lengthBars,
                                      label: sec.label, intensity: sec.intensity, mode: sec.mode))
            pos += sec.lengthBars
        }
        return result
    }

    // MARK: - Chord plan (Kosmic: very slow harmonic changes)

    private static func buildChordPlan(
        frame: GlobalMusicalFrame,
        sections: [SongSection],
        kosmicProgFamily: KosmicProgressionFamily,
        rng: inout SeededRNG
    ) -> [ChordWindow] {
        var plan: [ChordWindow] = []
        // Track the first A section's chord type so all A sections stay harmonically consistent.
        // Prevents the return A in A-B-A from picking a different chord type (e.g. sus4 after quartal).
        var firstAChordType: ChordType? = nil
        for section in sections {
            let windows = buildChordWindows(
                frame: frame,
                section: section,
                kosmicProgFamily: kosmicProgFamily,
                rng: &rng,
                forceChordType: section.label == .A ? firstAChordType : nil
            )
            if section.label == .A && firstAChordType == nil {
                firstAChordType = windows.first?.chordType
            }
            plan.append(contentsOf: windows)
        }
        return anchorIntroToBody(plan: plan, frame: frame, sections: sections)
    }

    private static func anchorIntroToBody(
        plan: [ChordWindow], frame: GlobalMusicalFrame, sections: [SongSection]
    ) -> [ChordWindow] {
        guard let introSection = sections.first(where: { $0.label == .intro }),
              let firstBodyChord = plan.first(where: { $0.startBar >= introSection.endBar })
        else { return plan }

        let (tones, tensions, avoids) = NotePoolBuilder.build(
            chordRootDegree: firstBodyChord.chordRoot,
            chordType: firstBodyChord.chordType,
            key: frame.key,
            mode: frame.mode
        )
        return plan.map { window in
            guard window.startBar >= introSection.startBar,
                  window.startBar < introSection.endBar else { return window }
            return ChordWindow(
                startBar: window.startBar, lengthBars: window.lengthBars,
                chordRoot: firstBodyChord.chordRoot, chordType: firstBodyChord.chordType,
                chordTones: tones, scaleTensions: tensions, avoidTones: avoids
            )
        }
    }

    /// Kosmic chord windows — fewer chords per section, longer holds (8–32 bars)
    private static func buildChordWindows(
        frame: GlobalMusicalFrame,
        section: SongSection,
        kosmicProgFamily: KosmicProgressionFamily,
        rng: inout SeededRNG,
        forceChordType: ChordType? = nil
    ) -> [ChordWindow] {
        let chordCount: Int
        switch section.label {
        case .intro, .outro,
             .bridge, .bridgeAlt, .bridgeMelody,
             .preRamp, .postRamp:
            chordCount = 1  // bridge/ramp sections always tonic, single chord
        case .A:
            switch kosmicProgFamily {
            case .static_drone, .quartal_stack:
                chordCount = 1
            default:
                chordCount = rng.nextDouble() < 0.35 ? 2 : 1
            }
        case .B:
            chordCount = rng.nextDouble() < 0.50 ? 2 : 1
        }

        // Bridge/ramp sections always use root-position tonic
        let forceTonic = (section.label == .bridge || section.label == .bridgeAlt ||
                          section.label == .bridgeMelody ||
                          section.label == .preRamp || section.label == .postRamp)

        // Always use frame.mode (the song's actual key) for chord selection.
        // section.mode for B sections (Aeolian/Mixolydian) is a melodic flavor hint, not an
        // independent harmonic key — using it for chord roots allowed bVI chords whose tones
        // (e.g. B natural in G#m) clash with the Dorian scale's Bb. Generators all draw from
        // frame.mode so chords must also be within that mode.
        let effectiveMode = frame.mode

        let barsEach = Swift.max(8, section.lengthBars / chordCount)
        var windows: [ChordWindow] = []
        var bar = section.startBar
        for i in 0..<chordCount {
            let length = (i == chordCount - 1) ? (section.endBar - bar) : barsEach
            let rawRoot = pickKosmicChordRoot(mode: effectiveMode, progFamily: kosmicProgFamily, rng: &rng)
            let root = (section.label == .intro || section.label == .outro || forceTonic) ? "1" : rawRoot
            // Always call pickKosmicChordType when not forceTonic — this preserves the RNG
            // consumption sequence so that seeds produce the same title/output when replayed.
            // forceChordType overrides the picked value but does NOT skip the RNG call.
            let pickedType = forceTonic ? ChordType.minor
                : pickKosmicChordType(progFamily: kosmicProgFamily, mode: effectiveMode, rng: &rng)
            var type: ChordType = (!forceTonic && forceChordType != nil) ? forceChordType! : pickedType
            // Issue 6: In long songs (> 80 bars) with static drone, B sections get at least
            // one textural chord shift — replace minor with sus2 or power so there is some
            // audible harmonic contrast even though the root doesn't move.
            if frame.totalBars > 80 && kosmicProgFamily == .static_drone
               && section.label == .B && type == .minor {
                type = rng.nextDouble() < 0.60 ? .sus2 : .power
            }
            let (tones, tensions, avoids) = NotePoolBuilder.build(
                chordRootDegree: root,
                chordType: type,
                key: frame.key,
                mode: effectiveMode
            )
            windows.append(ChordWindow(
                startBar: bar, lengthBars: length,
                chordRoot: root, chordType: type,
                chordTones: tones, scaleTensions: tensions, avoidTones: avoids
            ))
            bar += length
        }
        return windows
    }

    private static func pickKosmicChordRoot(
        mode: Mode,
        progFamily: KosmicProgressionFamily,
        rng: inout SeededRNG
    ) -> String {
        switch progFamily {
        case .static_drone:
            return "1"
        case .two_chord_pendulum, .oxygeneDorianVamp, .oxygeneAeolianCycle, .oxygeneTwoChordSway,
             .magneticArc, .magneticTurn, .equinoxePhrygian, .magneticDescent, .chronologiePopLoop:
            // Space families reach the base builder only to consume its draws (see generate).
            // b6 (bVI) is diatonic only in Aeolian (natural minor). In Dorian and Mixolydian
            // the 6th is raised — using b6 creates a borrowed root whose chord tones are
            // entirely outside the key. Fall back to "4" (IV — always diatonic) for those modes.
            let altRoot = (mode == .Aeolian || mode == .MinorPentatonic) ? "b6" : "4"
            return rng.nextDouble() < 0.6 ? "1" : altRoot
        case .modal_drift:
            // b7 is diatonic in Dorian, Aeolian, Mixolydian. b6 only in Aeolian.
            // Replace b6 with "4" for non-Aeolian modes: i - bVII - IV is equally atmospheric.
            let b6Degree = (mode == .Aeolian || mode == .MinorPentatonic) ? "b6" : "4"
            let degrees = ["1", "b7", b6Degree, "b7"]
            return degrees[rng.nextInt(upperBound: degrees.count)]
        case .suspended_resolution:
            return "1"
        case .quartal_stack:
            let degrees = ["1", "4", "b7"]
            return degrees[rng.nextInt(upperBound: degrees.count)]
        }
    }

    private static func pickKosmicChordType(
        progFamily: KosmicProgressionFamily,
        mode: Mode,
        rng: inout SeededRNG
    ) -> ChordType {
        let isMinorMode = mode == .Aeolian || mode == .Dorian
        let isMajorMode = mode == .Ionian

        switch progFamily {
        case .static_drone:
            // Clash fix: never assign minor to Ionian/Lydian (their scale has a major 3rd),
            // never assign major to Aeolian/Dorian/Phrygian (their scale has a minor 3rd).
            if isMajorMode {
                let types:   [ChordType] = [.major, .power, .sus2]
                let weights: [Double]    = [0.65,   0.20,   0.15]
                return types[rng.weightedPick(weights)]
            } else if isMinorMode {
                let types:   [ChordType] = [.minor, .power, .sus2]
                let weights: [Double]    = [0.75,   0.15,   0.10]
                return types[rng.weightedPick(weights)]
            } else {
                // Mixolydian — major-leaning scale, minor/sus2/power all acceptable
                let types:   [ChordType] = [.minor, .sus2, .power]
                let weights: [Double]    = [0.40,   0.35,  0.25]
                return types[rng.weightedPick(weights)]
            }
        case .two_chord_pendulum, .oxygeneDorianVamp, .oxygeneAeolianCycle, .oxygeneTwoChordSway,
             .magneticArc, .magneticTurn, .equinoxePhrygian, .magneticDescent, .chronologiePopLoop:
            // Clash fix: avoid major chord in minor modes — the major 3rd clashes with scale
            if isMinorMode {
                let types:   [ChordType] = [.minor, .sus2]
                let weights: [Double]    = [0.75,   0.25]
                return types[rng.weightedPick(weights)]
            } else {
                let types:   [ChordType] = [.minor, .major, .sus2]
                let weights: [Double]    = [0.50,   0.35,   0.15]
                return types[rng.weightedPick(weights)]
            }
        case .modal_drift:
            let types:   [ChordType] = [.minor, .minor, .sus2, .power]
            let weights: [Double]    = [0.40,   0.30,   0.20,  0.10]
            return types[rng.weightedPick(weights)]
        case .suspended_resolution:
            return rng.nextDouble() < 0.60 ? .sus4 : .minor
        case .quartal_stack:
            return rng.nextDouble() < 0.70 ? .quartal : .sus4
        }
    }

    // MARK: - Kosmic Space chord cycles

    /// One window of a Space chord cycle: a degree string `degreeSemitone` accepts, a chord
    /// type and a length of 2 or 4 bars.
    struct SpaceChord {
        let degree: String
        let type: ChordType
        let bars: Int
    }

    /// One pass through the family's cycle. `pass` counts passes across the whole song, so the
    /// variation lands every fourth pass whatever the section lengths.
    ///   Oxygene Dorian Vamp (Oxygene 4) — i ×4, ii ×2, then i (50%), bIII (25%) or IV (25%) ×2.
    ///     The source's 1-bar bIII–IV pair becomes one 2-bar window to keep the even-bar rule.
    ///   Oxygene Aeolian Cycle (Oxygene 8) — i ×4, bVII ×2, iv ×2; every fourth pass ends bVI ×2.
    ///   Oxygene Two-Chord Sway (Oxygene 3) — i ×2, v ×2.
    ///   Magnetic Fields Arc (Magnetic Fields 1) — i, bVI, iv, V ×4 each; V is major, its leading
    ///     tone from the chord's own scale (`spaceChordScale`).
    ///   Magnetic Fields Turn (Magnetic Fields 2) — i, V, bVI, bVII ×2 each, V major.
    ///   Equinoxe Phrygian (Equinoxe) — i ×8 as two windows, then iv, bII, bvii, i ×2 each.
    ///   Magnetic Fields Descent (Magnetic Fields 4) — I, vi, V, IV ×2 each.
    ///   Chronologie Pop Loop (Chronologie 4) — I, V, ii, IV ×2 each.
    static func spaceCycle(family: KosmicProgressionFamily, pass: Int,
                           rng: inout SeededRNG) -> [SpaceChord] {
        switch family {
        case .oxygeneDorianVamp:
            let r = rng.nextDouble()
            let last = r < 0.50 ? SpaceChord(degree: "1",  type: .minor, bars: 2)
                     : r < 0.75 ? SpaceChord(degree: "b3", type: .major, bars: 2)
                     :            SpaceChord(degree: "4",  type: .major, bars: 2)
            return [SpaceChord(degree: "1", type: .minor, bars: 4),
                    SpaceChord(degree: "2", type: .minor, bars: 2),
                    last]
        case .oxygeneAeolianCycle:
            let last = pass % 4 == 3 ? SpaceChord(degree: "b6", type: .major, bars: 2)
                                     : SpaceChord(degree: "4",  type: .minor, bars: 2)
            return [SpaceChord(degree: "1",  type: .minor, bars: 4),
                    SpaceChord(degree: "b7", type: .major, bars: 2),
                    last]
        case .magneticArc:
            return [SpaceChord(degree: "1",  type: .minor, bars: 4),
                    SpaceChord(degree: "b6", type: .major, bars: 4),
                    SpaceChord(degree: "4",  type: .minor, bars: 4),
                    SpaceChord(degree: "5",  type: .major, bars: 4)]
        case .magneticTurn:
            return [SpaceChord(degree: "1",  type: .minor, bars: 2),
                    SpaceChord(degree: "5",  type: .major, bars: 2),
                    SpaceChord(degree: "b6", type: .major, bars: 2),
                    SpaceChord(degree: "b7", type: .major, bars: 2)]
        case .equinoxePhrygian:
            return [SpaceChord(degree: "1",  type: .minor, bars: 4),
                    SpaceChord(degree: "1",  type: .minor, bars: 4),
                    SpaceChord(degree: "4",  type: .minor, bars: 2),
                    SpaceChord(degree: "b2", type: .major, bars: 2),
                    SpaceChord(degree: "b7", type: .minor, bars: 2),
                    SpaceChord(degree: "1",  type: .minor, bars: 2)]
        case .magneticDescent:
            return [SpaceChord(degree: "1", type: .major, bars: 2),
                    SpaceChord(degree: "6", type: .minor, bars: 2),
                    SpaceChord(degree: "5", type: .major, bars: 2),
                    SpaceChord(degree: "4", type: .major, bars: 2)]
        case .chronologiePopLoop:
            return [SpaceChord(degree: "1", type: .major, bars: 2),
                    SpaceChord(degree: "5", type: .major, bars: 2),
                    SpaceChord(degree: "2", type: .minor, bars: 2),
                    SpaceChord(degree: "4", type: .major, bars: 2)]
        default:
            return [SpaceChord(degree: "1", type: .minor, bars: 2),
                    SpaceChord(degree: "5", type: .minor, bars: 2)]
        }
    }

    /// The B-section loop (Zack, 2026-11-03, from Fluxion III: B must not repeat A's chords). Each
    /// leaves the tonic for the family's other chords and comes home at the end, so the section
    /// still reads as the same song. The Dorian and Aeolian pairs are the B-cycles this plan
    /// designed for Phase 2's breakdowns, extended to an 8-bar loop.
    ///   Oxygene Dorian Vamp — bIII ×2, IV ×2, i ×4.
    ///   Oxygene Aeolian Cycle — bVI ×2, bIII ×2, bVII ×2, i ×2.
    ///   Oxygene Two-Chord Sway — i ×2, iv ×2; iv is major in Dorian, where the minor iv is
    ///     out of the scale.
    ///   Magnetic Fields Arc — bIII, bVI, V, i ×2 each.
    ///   Magnetic Fields Turn — iv ×2, V ×2, i ×4.
    ///   Equinoxe Phrygian — bVI, bIII, bII, i ×2 each, home by the Phrygian cadence.
    ///   Magnetic Fields Descent — iii, IV, V, I ×2 each.
    ///   Chronologie Pop Loop — I ×2, IV ×2, vi ×4 (Chronologie 4).
    static func spaceBCycle(family: KosmicProgressionFamily, mode: Mode) -> [SpaceChord] {
        switch family {
        case .oxygeneDorianVamp:
            return [SpaceChord(degree: "b3", type: .major, bars: 2),
                    SpaceChord(degree: "4",  type: .major, bars: 2),
                    SpaceChord(degree: "1",  type: .minor, bars: 4)]
        case .oxygeneAeolianCycle:
            return [SpaceChord(degree: "b6", type: .major, bars: 2),
                    SpaceChord(degree: "b3", type: .major, bars: 2),
                    SpaceChord(degree: "b7", type: .major, bars: 2),
                    SpaceChord(degree: "1",  type: .minor, bars: 2)]
        case .magneticArc:
            return [SpaceChord(degree: "b3", type: .major, bars: 2),
                    SpaceChord(degree: "b6", type: .major, bars: 2),
                    SpaceChord(degree: "5",  type: .major, bars: 2),
                    SpaceChord(degree: "1",  type: .minor, bars: 2)]
        case .magneticTurn:
            return [SpaceChord(degree: "4", type: .minor, bars: 2),
                    SpaceChord(degree: "5", type: .major, bars: 2),
                    SpaceChord(degree: "1", type: .minor, bars: 4)]
        case .equinoxePhrygian:
            return [SpaceChord(degree: "b6", type: .major, bars: 2),
                    SpaceChord(degree: "b3", type: .major, bars: 2),
                    SpaceChord(degree: "b2", type: .major, bars: 2),
                    SpaceChord(degree: "1",  type: .minor, bars: 2)]
        case .magneticDescent:
            return [SpaceChord(degree: "3", type: .minor, bars: 2),
                    SpaceChord(degree: "4", type: .major, bars: 2),
                    SpaceChord(degree: "5", type: .major, bars: 2),
                    SpaceChord(degree: "1", type: .major, bars: 2)]
        case .chronologiePopLoop:
            return [SpaceChord(degree: "1", type: .major, bars: 2),
                    SpaceChord(degree: "4", type: .major, bars: 2),
                    SpaceChord(degree: "6", type: .minor, bars: 4)]
        default:
            return [SpaceChord(degree: "1", type: .minor, bars: 2),
                    SpaceChord(degree: "4", type: mode == .Dorian ? .major : .minor, bars: 2)]
        }
    }

    /// Kosmic Space chord plan. Intro and outro hold the tonic, as base Kosmic forces (this is
    /// also the corpus's pedal intro). Body sections loop the cycle from their first bar and cut
    /// the last window short at the section end. Every window is 2 or 4 bars and starts on an
    /// even bar, because KOS-PADS-001 re-attacks on even bars only.
    /// B sections loop `spaceBCycle`, but still draw the A cycle each pass, so the A sections'
    /// draws are the same as when B repeated A. The theme return's 8 bars carry the first A
    /// section's opening chords, so the replayed theme sits on the chords it was written over.
    private static func buildSpaceChordPlan(
        frame: GlobalMusicalFrame,
        sections: [SongSection],
        family: KosmicProgressionFamily,
        rng: inout SeededRNG
    ) -> [ChordWindow] {
        var plan: [ChordWindow] = []
        var pass = 0
        let themeReturn = SpaceThemeReturn.make(sections: sections)
        for section in sections {
            guard section.label == .A || section.label == .B else {
                plan.append(spaceWindow(frame, section.startBar, section.lengthBars, "1",
                                        frame.mode == .Ionian ? .major : .minor))
                continue
            }
            var bar = section.startBar
            while bar < section.endBar {
                let aCycle = spaceCycle(family: family, pass: pass, rng: &rng)
                pass += 1
                if let themeReturn, bar == themeReturn.range.lowerBound {
                    let source = themeReturn.sourceRange
                    for w in plan where source.contains(w.startBar) {
                        let length = Swift.min(w.lengthBars, source.upperBound - w.startBar)
                        plan.append(spaceWindow(frame, w.startBar + themeReturn.shift, length, w.chordRoot, w.chordType))
                    }
                    bar = themeReturn.range.upperBound
                    continue
                }
                // A window never runs over the return, so the copy above always starts on a window
                // edge. Every B cycle divides 8 today, so this cuts nothing yet.
                let end = themeReturn.map { $0.range.lowerBound > bar ? Swift.min(section.endBar, $0.range.lowerBound) : section.endBar }
                    ?? section.endBar
                let cycle = section.label == .B ? spaceBCycle(family: family, mode: frame.mode) : aCycle
                bar = laySpaceChords(cycle, from: bar, to: end, frame: frame, into: &plan)
            }
        }
        return plan
    }

    /// One Space chord window, its note pools built on the chord's scale (`spaceChordScale`).
    private static func spaceWindow(_ frame: GlobalMusicalFrame, _ start: Int, _ length: Int,
                                    _ degree: String, _ type: ChordType) -> ChordWindow {
        let (tones, _, _) = NotePoolBuilder.build(
            chordRootDegree: degree, chordType: type, key: frame.key, mode: frame.mode)
        // The chord's own scale, so a major V's leading tone is a chord tone, not an avoid tone.
        let scale = spaceChordScale(chordTones: tones, frame: frame)
        let tensions = scale.subtracting(tones)
        let avoids = Set(0..<12).subtracting(scale)
        return ChordWindow(startBar: start, lengthBars: length,
                           chordRoot: degree, chordType: type,
                           chordTones: tones, scaleTensions: tensions, avoidTones: avoids)
    }

    /// Lays `chords` end to end from `bar`, cutting the last one short at `end`. Returns the bar
    /// after the last window laid.
    private static func laySpaceChords(_ chords: [SpaceChord], from bar: Int, to end: Int,
                                       frame: GlobalMusicalFrame, into plan: inout [ChordWindow]) -> Int {
        var bar = bar
        for chord in chords where bar < end {
            let length = Swift.min(chord.bars, end - bar)
            plan.append(spaceWindow(frame, bar, length, chord.degree, chord.type))
            bar += length
        }
        return bar
    }

    /// The Magnetic Fields breakdown's chords. Magnetic Fields 1 changes cycle for its breakdowns,
    /// so these are 4-bar windows, half the song's pace, on chords neither of the song's loops leans
    /// on, and the last leads into the B section's first chord:
    ///   Oxygene Dorian Vamp — v ×4, bVII ×4 (12 bars: bVII, v, bVII), bVII leading to B's bIII
    ///   Oxygene Aeolian Cycle — v ×4, bIII ×4 (12 bars: iv, v, bIII), bIII leading to B's bVI
    ///   Oxygene Two-Chord Sway — bVI ×4, bVII ×4 in Aeolian (12 bars: bIII, bVI, bVII), the
    ///     Aeolian cadence home to B's i; in Dorian, where bVI is out of the scale, bIII ×4, bVII ×4
    ///     (12 bars: bIII, IV, bVII)
    ///   Magnetic Fields Arc — iv ×4, bVII ×4 (12 bars: bVI, iv, bVII), bVII leading to B's bIII
    ///   Magnetic Fields Turn — bIII ×4, i ×4 (12 bars: bIII, bVII, i), i leading to B's iv
    ///   Equinoxe Phrygian — iv ×4, bvii ×4 (12 bars: bIII, iv, bvii), bvii stepping to B's bVI
    ///   Magnetic Fields Descent — ii ×4, vi ×4 (12 bars: IV, ii, vi), vi leading to B's iii
    ///   Chronologie Pop Loop — IV ×4, V ×4 (12 bars: vi, IV, V), V resolving to the return's I
    /// Applied over the finished cycle plan, so every cycle draw is the same as without a bridge.
    /// The sequencer solo keeps the song's cycle.
    static func spaceBridgeChords(family: KosmicProgressionFamily, mode: Mode,
                                  bars: Int) -> [SpaceChord] {
        let long = bars >= 12
        let degrees: [(String, ChordType)]
        switch family {
        case .oxygeneDorianVamp:
            degrees = long ? [("b7", .major), ("5", .minor), ("b7", .major)]
                           : [("5", .minor), ("b7", .major)]
        case .oxygeneAeolianCycle:
            degrees = long ? [("4", .minor), ("5", .minor), ("b3", .major)]
                           : [("5", .minor), ("b3", .major)]
        case .magneticArc:
            degrees = long ? [("b6", .major), ("4", .minor), ("b7", .major)]
                           : [("4", .minor), ("b7", .major)]
        case .magneticTurn:
            degrees = long ? [("b3", .major), ("b7", .major), ("1", .minor)]
                           : [("b3", .major), ("1", .minor)]
        case .equinoxePhrygian:
            degrees = long ? [("b3", .major), ("4", .minor), ("b7", .minor)]
                           : [("4", .minor), ("b7", .minor)]
        case .magneticDescent:
            degrees = long ? [("4", .major), ("2", .minor), ("6", .minor)]
                           : [("2", .minor), ("6", .minor)]
        case .chronologiePopLoop:
            degrees = long ? [("6", .minor), ("4", .major), ("5", .major)]
                           : [("4", .major), ("5", .major)]
        default:
            if mode == .Dorian {
                degrees = long ? [("b3", .major), ("4", .major), ("b7", .major)]
                               : [("b3", .major), ("b7", .major)]
            } else {
                degrees = long ? [("b3", .major), ("b6", .major), ("b7", .major)]
                               : [("b6", .major), ("b7", .major)]
            }
        }
        return degrees.map { SpaceChord(degree: $0.0, type: $0.1, bars: 4) }
    }

    private static func applySpaceBridgeChords(
        plan: [ChordWindow], frame: GlobalMusicalFrame, family: KosmicProgressionFamily,
        bridge: SpaceBridge?
    ) -> [ChordWindow] {
        guard let bridge, bridge.kind == .breakdown else { return plan }
        let range = bridge.range
        func part(_ w: ChordWindow, _ bars: Range<Int>) -> ChordWindow {
            ChordWindow(startBar: bars.lowerBound, lengthBars: bars.count,
                        chordRoot: w.chordRoot, chordType: w.chordType,
                        chordTones: w.chordTones, scaleTensions: w.scaleTensions, avoidTones: w.avoidTones)
        }
        // Keep each window's bars either side of the bridge. The bridge ends on A's last bar today,
        // so nothing yet runs past its far edge.
        var result: [ChordWindow] = []
        for w in plan {
            let bars = w.startBar..<(w.startBar + w.lengthBars)
            guard bars.overlaps(range) else { result.append(w); continue }
            if bars.lowerBound < range.lowerBound { result.append(part(w, bars.lowerBound..<range.lowerBound)) }
            if bars.upperBound > range.upperBound { result.append(part(w, range.upperBound..<bars.upperBound)) }
        }
        _ = laySpaceChords(spaceBridgeChords(family: family, mode: frame.mode, bars: range.count),
                           from: range.lowerBound, to: range.upperBound, frame: frame, into: &result)
        return result.sorted { $0.startBar < $1.startBar }
    }
}

// MARK: - Kosmic Space bridge

/// Kosmic Space's bridge (Zack, 2026-11-03). Base Kosmic's bridges are Electric Buddha drum bridges
/// and melody bridges, none of them Jarre; this one is built from how Jarre himself breaks a piece in
/// the middle, measured with tools/jarre_deep.py --sections. Either kind is half the songs that
/// take one:
///   Magnetic Fields Breakdown, 8 or 12 bars (Magnetic Fields 1, bars 73–84 and 137–148): the
///     sequencer, Lead 1 and Lead 2 drop out, the preset box drops to the kick alone on beats 1 and 3
///     (rebuilding with 8th hats over the last 4 bars of a 12-bar one), the bass holds long
///     roots and the pads carry slower chords of their own (`spaceBridgeChords`). A swell into it
///     and out of it.
///   Rendez-Vous Sequencer Solo, 8 bars (Rendez-Vous 2, bars 81–96): the sequencer alone, the pads
///     with it in half of these songs, under two filter sweeps (`KosmicAutoSweep`), and the drums
///     come back with a 2-beat fill and a crash on the downbeat.
/// Only in ab and aba forms, as base Kosmic's bridges, at `spaceBridgeShare` of them. It takes the
/// last bars of the first A section and ends where the first B begins, as base Kosmic's bridge sits
/// between A and B, leaving A at least 16 bars. It is a mute schedule over those bars rather than a
/// section, so the A and B rules, the chord cycle and every track's draws are unchanged; a song with
/// a bridge drops the sequencer break, which does the same job. Drawn from its own stream on the song
/// seed, so the chord plan, the arrangement and per-track regen all rebuild it without storing it.
struct SpaceBridge {
    enum Kind { case breakdown, sequencerSolo }
    let kind: Kind
    let range: Range<Int>
    /// The solo keeps the pads under the sequencer in half of its songs; the breakdown always does.
    let padsPlay: Bool

    /// The way back in, shared by every drum rule and the bass: a 2-beat fill over the second half
    /// of the bridge's last bar, with the bass's two-note pickup on its steps 12 and 14.
    static let returnFillBeats = 2
    /// First step of the return fill.
    var returnFillStep: Int { range.upperBound * 16 - SpaceBridge.returnFillBeats * 4 }
    /// First step of the bass pickup into B.
    var pickupStep: Int { range.upperBound * 16 - 4 }

    static func make(sections: [SongSection], seed: UInt64) -> SpaceBridge? {
        let body = SongStructure.bodySections(sections)
        let labels = body.map(\.label)
        guard labels == [.A, .B] || labels == [.A, .B, .A] else { return nil }
        var rng = KosmicSpaceStream.bridge.rng(seed: seed)
        guard rng.nextDouble() < KosmicMusicalFrameGenerator.spaceBridgeShare else { return nil }
        let isSolo = rng.nextDouble() < 0.50
        let length = isSolo ? 8 : (rng.nextDouble() < 0.50 ? 8 : 12)
        let padsPlay = isSolo ? rng.nextDouble() < 0.50 : true
        let firstA = body[0]
        guard firstA.lengthBars - length >= 16 else { return nil }
        return SpaceBridge(kind: isSolo ? .sequencerSolo : .breakdown,
                           range: (firstA.endBar - length)..<firstA.endBar, padsPlay: padsPlay)
    }
}

// MARK: - Kosmic Space theme return

/// The theme return (Zack, 2026-11-03): a song whose last body section is B (ab, abab) never hears
/// its A theme again, so 8 bars two thirds into the last B replay the first A section's opening 8
/// bars, lead and chords alike. On an 8-bar point at least 8 bars into the last B. Nil when the song
/// ends on A, or the sections are too short. No draws, so the chord plan and Lead 1 regen both
/// rebuild it.
struct SpaceThemeReturn {
    static let bars = 8
    /// The replayed bars, in the last B section.
    let range: Range<Int>
    /// The first A section's opening bars, which they replay.
    let sourceRange: Range<Int>
    /// Bars from the source to the replay.
    var shift: Int { range.lowerBound - sourceRange.lowerBound }

    static func make(sections: [SongSection]) -> SpaceThemeReturn? {
        let body = SongStructure.bodySections(sections)
        guard let lastB = body.last, lastB.label == .B,
              let firstA = body.first(where: { $0.label == .A }), firstA.lengthBars >= bars else { return nil }
        let start = lastB.startBar + (lastB.lengthBars * 2 / 3) / 8 * 8
        guard start >= lastB.startBar + 8 && start + bars <= lastB.endBar else { return nil }
        return SpaceThemeReturn(range: start..<(start + bars),
                                sourceRange: firstA.startBar..<(firstA.startBar + bars))
    }
}

// MARK: - Kosmic Space arrangement

/// Where a Kosmic Space song breaks its own repetition. Measured on the corpus with
/// tools/jarre_breaks.py:
///
/// - In the Oxygene pieces drums and bass never stop (104 bars in Oxygene 4, 112 in Oxygene 6).
///   What comes and goes is the lead: one or two rests of 16–23 bars (Oxygene 4, 6 and 8), each
///   starting and ending on or near a section edge.
/// - The sequencer answers the lead: thinner while it plays, fuller while it rests
///   (Oxygene 6: 3.1–3.3 against 5.5 notes a bar; Oxygene 4: 8.9–9.0 against 9.7–9.9).
/// - Short sequencer breaks of 4–8 bars happen while drums and bass carry on, with Lead 2
///   dropping out alongside (Oxygene 8: 6, 4, 8 bars; Oxygene 4's second transcription: 6, 6).
/// - A noise swell marks the returns (Oxygene 6; three of four in Oxygene 8).
///
/// Drum fills are Zudio's own addition (Zack, 2026-11-02) — the Oxygene preset-box pieces have
/// none. They follow Motorik Europe's sync: only in the bar before a break or a return, 1 beat
/// mostly and 2 at most, never more than three a song.
///
/// Every edge sits on a landing bar: a body section's start or a 16-bar point inside a body
/// section. Nothing breaks in the first 16 body bars or the last 8 before the outro. Derived
/// from the structure and the song seed alone, so per-track regeneration rebuilds the same
/// schedule without storing it.
struct DrumThin {
    let range: Range<Int>
    /// 0 = eighth-note hats (no 16ths); 1 = quarter hats, kick on 0 and 10 only, no open hat.
    let variant: Int
}

struct KosmicSpaceArrangement {
    /// Body bars where Lead 1 sits out.
    let leadRests: [Range<Int>]
    /// Bars where Rhythm (and Lead 2) sit out.
    let sequencerBreak: Range<Int>?
    /// Bars that take a drum fill.
    let fillBars: [Int]
    /// Stretches where the preset box drops to a simpler beat, at section starts and 32-bar points.
    let drumThins: [DrumThin]
    /// Stretches where the Falling Walk bass drops to half its notes. Some match a drum stretch
    /// exactly, so both return to the full pattern together; others stand alone.
    let bassThins: [Range<Int>]
    /// Body stretches where the preset box adds its handclap on beats 2 and 4. Empty in about 90%
    /// of songs.
    let clapRanges: [Range<Int>]
    /// The song's bridge, in ab and aba songs only (`SpaceBridge`).
    let bridge: SpaceBridge?
    /// First and last-plus-one bars of the body.
    let bodyStart: Int
    let bodyEnd: Int

    // Derived from the fields above once, in init.

    /// Bars that take a guaranteed surf sweep: every bar a part returns on, and the start of a
    /// breakdown.
    let swellBars: [Int]
    /// The sequencer solo's bars, or nothing.
    let soloRange: [Range<Int>]
    /// The breakdown's bars, or nothing.
    let breakdownRange: [Range<Int>]
    /// Lead 1 sits out its rests and the bridge.
    let lead1Silences: [Range<Int>]
    /// Lead 2 sits out the sequencer break and the bridge.
    let lead2Silences: [Range<Int>]
    /// The solo leaves the pads out in half of its songs.
    let padsSilences: [Range<Int>]
    /// The solo silences Texture until its last bar, where the swell into the return begins.
    let textureSilences: [Range<Int>]
    /// Every drum or bass stretch, overlaps merged. Hand Percussion thins over all of them.
    let thinRanges: [Range<Int>]
    /// The first two drum stretches, where JMJ Mini Pops drops out completely.
    let miniPopsDropouts: [Range<Int>]

    init(leadRests: [Range<Int>], sequencerBreak: Range<Int>?, fillBars: [Int], drumThins: [DrumThin],
         bassThins: [Range<Int>], clapRanges: [Range<Int>], bridge: SpaceBridge?,
         bodyStart: Int, bodyEnd: Int) {
        self.leadRests = leadRests
        self.sequencerBreak = sequencerBreak
        self.fillBars = fillBars
        self.drumThins = drumThins
        self.bassThins = bassThins
        self.clapRanges = clapRanges
        self.bridge = bridge
        self.bodyStart = bodyStart
        self.bodyEnd = bodyEnd

        let bridgeRange = bridge.map { [$0.range] } ?? []
        let breakRange = sequencerBreak.map { [$0] } ?? []
        soloRange = bridge.flatMap { $0.kind == .sequencerSolo ? [$0.range] : nil } ?? []
        breakdownRange = bridge.flatMap { $0.kind == .breakdown ? [$0.range] : nil } ?? []
        let returnBars = leadRests.map(\.upperBound) + breakRange.map(\.upperBound) + bridgeRange.map(\.upperBound)
        swellBars = returnBars + breakdownRange.map(\.lowerBound)
        lead1Silences = leadRests + bridgeRange
        lead2Silences = breakRange + bridgeRange
        padsSilences = bridge?.padsPlay == false ? bridgeRange : []
        textureSilences = soloRange.map { $0.lowerBound..<($0.upperBound - 1) }
        var merged: [Range<Int>] = []
        for r in (drumThins.map(\.range) + bassThins).sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, r.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<Swift.max(last.upperBound, r.upperBound)
            } else {
                merged.append(r)
            }
        }
        thinRanges = merged
        miniPopsDropouts = Array(drumThins.prefix(2).map(\.range))
    }

    /// The solo silences the bass; the breakdown replaces it with held roots.
    func bridgeKind(atBar bar: Int) -> SpaceBridge.Kind? {
        guard let bridge, bridge.range.contains(bar) else { return nil }
        return bridge.kind
    }

    func bassThins(atBar bar: Int) -> Bool { bassThins.contains { $0.contains(bar) } }
    func drumThin(atBar bar: Int) -> DrumThin? { drumThins.first { $0.range.contains(bar) } }
    func clapPlays(atBar bar: Int) -> Bool { clapRanges.contains { $0.contains(bar) } }
    func leadRests(atBar bar: Int) -> Bool { lead1Silences.contains { $0.contains(bar) } }
    /// The sequencer sits out its break and the breakdown, and plays alone in the solo.
    func sequencerRests(atBar bar: Int) -> Bool {
        sequencerBreak?.contains(bar) == true || bridgeKind(atBar: bar) == .breakdown
    }
    /// True in body bars where Lead 1 is playing; the sequencer thins under it.
    func leadPlays(atBar bar: Int) -> Bool { bar >= bodyStart && bar < bodyEnd && !leadRests(atBar: bar) }

    static func make(structure: SongStructure, totalBars: Int, seed: UInt64) -> KosmicSpaceArrangement {
        let body = structure.bodySections
        guard let first = body.first, let last = body.last else {
            return KosmicSpaceArrangement(leadRests: [], sequencerBreak: nil, fillBars: [],
                                          drumThins: [], bassThins: [], clapRanges: [], bridge: nil,
                                          bodyStart: 0, bodyEnd: totalBars)
        }
        let bridge = SpaceBridge.make(sections: structure.sections, seed: seed)
        let bridgeRanges = bridge.map { [$0.range] } ?? []
        var rng = KosmicSpaceStream.arrangement.rng(seed: seed)
        let earliest = first.startBar + 16
        let latest   = last.endBar - 8

        // Landing bars, a section start weighted above a 16-bar point
        var landings: [Int: Double] = [:]
        for sec in body {
            if sec.startBar > first.startBar { landings[sec.startBar] = 3 }
            for b in stride(from: sec.startBar + 16, to: sec.endBar, by: 16) where landings[b] == nil {
                landings[b] = 1
            }
        }
        let landingBars = landings.keys.sorted()

        // Draw order is load-bearing here: no draw is taken when there are no options, so adding or
        // removing a candidate can change every later draw on this stream.
        func weightedChoice(_ options: [(Range<Int>, Double)]) -> Range<Int>? {
            guard !options.isEmpty else { return nil }
            return options[rng.weightedPick(options.map(\.1))].0
        }
        func leadBarsLeft(_ sec: SongSection, resting: [Range<Int>]) -> Int {
            (sec.startBar..<sec.endBar).filter { b in !resting.contains { $0.contains(b) } }.count
        }

        // Lead 1 rests: from one landing bar to another 16–24 bars later. Every body section keeps
        // at least 8 bars of lead, so the theme and the riff are both still heard.
        var rests: [Range<Int>] = []
        let restCount = totalBars > 110 ? 2 : 1
        for _ in 0..<restCount {
            var options: [(Range<Int>, Double)] = []
            for s in landingBars where s >= earliest {
                for l in landingBars where l - s >= 16 && l - s <= 24 && l <= latest {
                    let r = s..<l
                    // 16 bars clear of each other and of the bridge, which silences the lead too
                    guard (rests + bridgeRanges).allSatisfy({ r.lowerBound >= $0.upperBound + 16 || r.upperBound + 16 <= $0.lowerBound })
                    else { continue }
                    guard body.allSatisfy({ leadBarsLeft($0, resting: rests + [r] + bridgeRanges) >= 8 }) else { continue }
                    options.append((r, (landings[s] ?? 1) * (landings[l] ?? 1)))
                }
            }
            if let r = weightedChoice(options) { rests.append(r) }
        }
        rests.sort { $0.lowerBound < $1.lowerBound }

        // One sequencer break of 4, 6 or 8 bars, ending on a landing bar while Lead 1 is playing
        let length = [4, 6, 8][rng.weightedPick([0.2, 0.6, 0.2])]
        var breakOptions: [(Range<Int>, Double)] = []
        for l in landingBars where l <= latest && l - length >= earliest {
            let r = (l - length)..<l
            guard rests.allSatisfy({ r.upperBound + 4 <= $0.lowerBound || r.lowerBound >= $0.upperBound + 4 })
            else { continue }
            breakOptions.append((r, landings[l] ?? 1))
        }
        // A song with a bridge has no sequencer break; the bridge does its job.
        let seqBreak = bridge == nil ? weightedChoice(breakOptions) : nil

        // Fills: the bar before the bridge ends, then the bar before each return, then the bar
        // before the break begins
        var fills: [Int] = bridgeRanges.map { $0.upperBound - 1 }
        if let b = seqBreak { fills.append(b.upperBound - 1) }
        fills += rests.map { $0.upperBound - 1 }
        if let b = seqBreak { fills.append(b.lowerBound - 1) }
        var seen = Set<Int>()
        fills = Array(fills.filter { seen.insert($0).inserted }.prefix(3)).sorted()

        // Drum changes come from their own stream, so the schedule above is unchanged by them.
        var drumRNG = KosmicSpaceStream.arrangementDrums.rng(seed: seed)

        // Simpler beat, and a simpler bass: candidate points are each body section start after the
        // first and every 16 bars after it, never into the last 8 before the outro. Each point has a
        // 50% chance of a stretch of 8, 12 or 16 bars, with 8 bars of full pattern between stretches
        // and none over the sequencer break (whose own thinning is enough) or within 16 bars of the
        // bridge. A song of over 100 bars gets at least two, a shorter one or one with a bridge at
        // least one.
        // In 60% of drum stretches the bass thins over exactly the same bars, so both return to the
        // full pattern together under the closing fill; in the rest the bass plays on. One more
        // stretch of 8 or 12 bars, 50% of songs, thins the bass alone, apart from any drum stretch.
        var points: [(bar: Int, end: Int)] = []
        for sec in body {
            let end = Swift.min(sec.endBar, last.endBar - 8)
            if sec.startBar > first.startBar { points.append((sec.startBar, end)) }
            for b in stride(from: sec.startBar + 16, to: end - 3, by: 16) { points.append((b, end)) }
        }
        points.sort { $0.bar < $1.bar }
        var thinRanges: [Range<Int>] = []
        var thins: [DrumThin] = []
        var bassThins: [Range<Int>] = []
        func fits(_ r: Range<Int>) -> Bool {
            guard r.count >= 4 else { return false }
            if let b = seqBreak, !(r.upperBound <= b.lowerBound || r.lowerBound >= b.upperBound) { return false }
            if let b = bridge?.range, !(r.upperBound + 16 <= b.lowerBound || r.lowerBound >= b.upperBound + 16) { return false }
            return (thinRanges + bassThins).allSatisfy { r.lowerBound >= $0.upperBound + 8 || r.upperBound + 8 <= $0.lowerBound }
        }
        // At most three breaks a song, the bridge counting as one (Zack, 2026-11-03): three thin
        // stretches without a bridge, two with one. The bass-only stretch, drawn last, is the first
        // to go.
        let maxStretches = bridge == nil ? 3 : 2
        // Draw order is load-bearing: the three draws below come before the guard, so a stretch that
        // is refused still takes all three, and the draw in `together` is taken before
        // `thins.isEmpty` is read. Reordering either changes every later stretch.
        func addDrumStretch(_ point: (bar: Int, end: Int)) {
            let length = [8, 12, 16][drumRNG.weightedPick([0.4, 0.2, 0.4])]
            let variant = drumRNG.nextDouble() < 0.6 ? 0 : 1
            // The first stretch always takes the bass with it (Zack, 2026-11-03: both thinning
            // together is the dramatic moment); later ones do so 60% of the time.
            let together = drumRNG.nextDouble() < 0.60 || thins.isEmpty
            let r = point.bar..<Swift.min(point.bar + length, point.end)
            guard thins.count < maxStretches, fits(r) else { return }
            thinRanges.append(r)
            thins.append(DrumThin(range: r, variant: variant))
            if together { bassThins.append(r) }
        }
        for point in points where drumRNG.nextDouble() < 0.50 { addDrumStretch(point) }
        // A song with a bridge needs only one: the bridge is its big moment (Zack, 2026-11-03).
        let wanted = bridge == nil && totalBars > 100 ? 2 : 1
        var spare = points.filter { p in !thins.contains { $0.range.contains(p.bar) } }
        while thins.count < wanted && !spare.isEmpty {
            addDrumStretch(spare.remove(at: drumRNG.nextInt(upperBound: spare.count)))
        }
        thins.sort { $0.range.lowerBound < $1.range.lowerBound }
        if drumRNG.nextDouble() < 0.50 {
            let length = drumRNG.nextDouble() < 0.5 ? 8 : 12
            let options = points.map { $0.bar..<Swift.min($0.bar + length, $0.end) }.filter(fits)
            if !options.isEmpty && thins.count < maxStretches {
                bassThins.append(options[drumRNG.nextInt(upperBound: options.count)])
            }
        }
        bassThins.sort { $0.lowerBound < $1.lowerBound }

        // Handclap: rare, in about 10% of songs, and then in one or two body sections only.
        var claps: [Range<Int>] = []
        if drumRNG.nextDouble() < 0.10 {
            var secs = body
            let n = drumRNG.nextDouble() < 0.5 ? 1 : 2
            for _ in 0..<Swift.min(n, secs.count) {
                let sec = secs.remove(at: drumRNG.nextInt(upperBound: secs.count))
                claps.append(sec.startBar..<sec.endBar)
            }
        }

        return KosmicSpaceArrangement(leadRests: rests, sequencerBreak: seqBreak, fillBars: fills,
                                      drumThins: thins, bassThins: bassThins, clapRanges: claps,
                                      bridge: bridge, bodyStart: first.startBar, bodyEnd: last.endBar)
    }
}
