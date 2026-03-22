// KosmicStructureGenerator.swift — Kosmic generation step 2
// Produces a SongStructure for Kosmic style with long sections and glacial pacing.
//
// Supported song forms: single_evolving, ab, aba, abab, abba
// Bridge archetypes (35% of ab/aba songs):
//   .bridge       — A-1 escalating drum bridge (Mister Mosca style, 4-8 bars)
//   .bridgeAlt    — A-2 sparse hit + call-and-response (Caligari Drop style, 4-8 bars)
//   .bridgeMelody — Archetype B melody bridge (Dark Sun style, 16-24 bars + pre/post ramps)

struct KosmicStructureGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        kosmicForm: KosmicSongForm,
        kosmicProgFamily: KosmicProgressionFamily,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG,
        forceBridge: Bool = false,
        forceBridgeArchetype: String? = nil
    ) -> SongStructure {
        let (sections, introStyle, outroStyle) = buildSections(
            form: kosmicForm,
            totalBars: frame.totalBars,
            percussionStyle: percussionStyle,
            rng: &rng,
            forceBridge: forceBridge,
            forceBridgeArchetype: forceBridgeArchetype
        )
        let chordPlan = buildChordPlan(
            frame: frame,
            sections: sections,
            kosmicProgFamily: kosmicProgFamily,
            rng: &rng
        )
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
        forceBridgeArchetype: String? = nil
    ) -> (sections: [SongSection], introStyle: IntroStyle, outroStyle: OutroStyle) {

        // Kosmic intro: 2 bars (25%), 4 bars (62.5%), 8 bars (12.5%)
        let introLengths: [Int]    = [2,    4,     8    ]
        let introWeights: [Double] = [0.25, 0.625, 0.125]
        let introBars = introLengths[rng.weightedPick(introWeights)]
        // Kosmic outro: 8 or 16 bars
        let outroBars = rng.nextDouble() < 0.5 ? 8 : 16
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
                                            forceBridge: forceBridge, forceBridgeArchetype: forceBridgeArchetype)
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
        forceBridge: Bool = false, forceBridgeArchetype: String? = nil
    ) -> [SongSection] {
        // Only ab/aba forms get bridges
        guard form == .ab || form == .two_world || form == .aba || form == .build_and_dissolve else {
            return sections
        }
        // In normal generation: 35% chance. When forced (test mode): always insert.
        guard forceBridge || rng.nextDouble() < 0.35 else { return sections }

        // Find the index of the first A→B boundary
        guard let aIdx = sections.firstIndex(where: { $0.label == .A }),
              aIdx + 1 < sections.count,
              sections[aIdx + 1].label == .B else { return sections }

        let aSection = sections[aIdx]

        // Choose archetype — honour forceBridgeArchetype when set
        let archetype: String
        if let forced = forceBridgeArchetype {
            archetype = (forced == "melody") ? "melodyBridge" : "drumBridge"
        } else {
            archetype = rng.nextDouble() < 0.50 ? "drumBridge" : "melodyBridge"
        }

        if archetype == "drumBridge" {
            // A-1 or A-2: 4 bars (70%) or 8 bars (30%)
            let bridgeBars = rng.nextDouble() < 0.70 ? 4 : 8
            // A section must retain at least 24 bars
            guard aSection.lengthBars - bridgeBars >= 24 else { return sections }

            let subVariant: SectionLabel
            if forceBridgeArchetype == "drumAlt" {
                subVariant = .bridgeAlt
            } else if forceBridgeArchetype == "drum" {
                subVariant = .bridge
            } else {
                subVariant = rng.nextDouble() < 0.50 ? .bridge : .bridgeAlt
            }
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
            // Archetype B (melody bridge): 16 bars (60%) or 24 bars (40%)
            let bridgeBars = rng.nextDouble() < 0.60 ? 16 : 24
            // Ramps: normally 6-8 bars each; shorten to 4 if A section too small
            var rampLen = rng.nextInt(upperBound: 3) + 6  // 6-8
            let totalExtra = bridgeBars + rampLen * 2
            if aSection.lengthBars - totalExtra < 24 { rampLen = 4 }
            let totalExtrafinal = bridgeBars + rampLen * 2
            guard aSection.lengthBars - totalExtrafinal >= 24 else { return sections }

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
        for section in sections {
            plan.append(contentsOf: buildChordWindows(
                frame: frame,
                section: section,
                kosmicProgFamily: kosmicProgFamily,
                rng: &rng
            ))
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
            mode: introSection.mode
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
        rng: inout SeededRNG
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

        let barsEach = Swift.max(8, section.lengthBars / chordCount)
        var windows: [ChordWindow] = []
        var bar = section.startBar
        for i in 0..<chordCount {
            let length = (i == chordCount - 1) ? (section.endBar - bar) : barsEach
            let rawRoot = pickKosmicChordRoot(section: section, progFamily: kosmicProgFamily, rng: &rng)
            let root = (section.label == .intro || section.label == .outro || forceTonic) ? "1" : rawRoot
            let type = forceTonic ? .minor :
                pickKosmicChordType(progFamily: kosmicProgFamily, mode: section.mode, rng: &rng)
            let (tones, tensions, avoids) = NotePoolBuilder.build(
                chordRootDegree: root,
                chordType: type,
                key: frame.key,
                mode: section.mode
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
        section: SongSection,
        progFamily: KosmicProgressionFamily,
        rng: inout SeededRNG
    ) -> String {
        switch progFamily {
        case .static_drone:
            return "1"
        case .two_chord_pendulum:
            return rng.nextDouble() < 0.6 ? "1" : "b6"
        case .modal_drift:
            let degrees = ["1", "b7", "b6", "b7"]
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
        switch progFamily {
        case .static_drone:
            let types:   [ChordType] = [.minor, .minor, .power, .sus2]
            let weights: [Double]    = [0.50,   0.25,   0.15,   0.10]
            return types[rng.weightedPick(weights)]
        case .two_chord_pendulum:
            let types:   [ChordType] = [.minor, .major, .sus2]
            let weights: [Double]    = [0.50,   0.35,   0.15]
            return types[rng.weightedPick(weights)]
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
}
