// CosmicStructureGenerator.swift — Cosmic generation step 2
// Produces a SongStructure for Cosmic style with long sections and glacial pacing.

struct CosmicStructureGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        cosmicForm: CosmicSongForm,
        cosmicProgFamily: CosmicProgressionFamily,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG
    ) -> SongStructure {
        let (sections, introStyle, outroStyle) = buildSections(
            form: cosmicForm,
            totalBars: frame.totalBars,
            percussionStyle: percussionStyle,
            rng: &rng
        )
        let chordPlan = buildChordPlan(
            frame: frame,
            sections: sections,
            cosmicProgFamily: cosmicProgFamily,
            rng: &rng
        )
        return SongStructure(sections: sections, chordPlan: chordPlan,
                             introStyle: introStyle, outroStyle: outroStyle)
    }

    // MARK: - Section layout

    private static func buildSections(
        form: CosmicSongForm,
        totalBars: Int,
        percussionStyle: PercussionStyle,
        rng: inout SeededRNG
    ) -> (sections: [SongSection], introStyle: IntroStyle, outroStyle: OutroStyle) {

        // Cosmic intro: 2 bars (25%), 4 bars (50%), 8 bars (25%)
        let introLengths: [Int]    = [2,    4,    8   ]
        let introWeights: [Double] = [0.25, 0.50, 0.25]
        let introBars = introLengths[rng.weightedPick(introWeights)]
        // Cosmic outro: 8 or 16 bars
        let outroBars = rng.nextDouble() < 0.5 ? 8 : 16
        let bodyBars  = Swift.max(4, totalBars - introBars - outroBars)

        var sections: [SongSection] = []
        var cursor = 0

        // Intro
        sections.append(SongSection(startBar: cursor, lengthBars: introBars,
                                    label: .intro, intensity: .low, mode: .Dorian))
        cursor += introBars

        // Body
        let bodySections = buildBodySections(form: form, bodyBars: bodyBars, cursor: cursor, rng: &rng)
        sections.append(contentsOf: bodySections)
        cursor += bodyBars

        // Outro
        let lastMode = bodySections.last?.mode ?? .Dorian
        sections.append(SongSection(startBar: cursor, lengthBars: outroBars,
                                    label: .outro, intensity: .low, mode: lastMode))

        // Cosmic intro styles.
        // Electric Buddha groove / minimal beat → cold start preferred (drums-alone pickup).
        // Other percussion → equal three-way split as before.
        let introStyle: IntroStyle
        let usesRockGroove = (percussionStyle == .motorikGrid || percussionStyle == .electricBuddhaPulse)
        if usesRockGroove {
            // 60% cold start (always drumsOnly: true for the Electric Buddha feel),
            // 20% progressive entry, 20% already playing
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

        // Cosmic outro styles — mapped to existing OutroStyle cases
        let outroStyles: [OutroStyle] = [.dissolve, .fade, .coldStop]
        let outroWeights: [Double]    = [0.50,      0.40, 0.10]
        let outroStyle = outroStyles[rng.weightedPick(outroWeights)]

        return (sections, introStyle, outroStyle)
    }

    private static func buildBodySections(
        form: CosmicSongForm, bodyBars: Int, cursor: Int, rng: inout SeededRNG
    ) -> [SongSection] {
        switch form {
        case .single_evolving:
            // One very long section — Roach/TD model
            return [SongSection(startBar: cursor, lengthBars: bodyBars,
                                label: .A, intensity: .medium, mode: .Dorian)]

        case .two_world:
            // A section (spacious) → B section (denser) — ABA optional reprise
            let aLen = Swift.max(32, Int(Double(bodyBars) * 0.55) / 4 * 4)
            let bLen = Swift.max(32, bodyBars - aLen)
            let bMode = rng.nextDouble() < 0.5 ? Mode.Aeolian : Mode.Mixolydian
            return [
                SongSection(startBar: cursor,        lengthBars: aLen, label: .A, intensity: .low,    mode: .Dorian),
                SongSection(startBar: cursor + aLen,  lengthBars: bLen, label: .B, intensity: .medium, mode: bMode)
            ]

        case .build_and_dissolve:
            // Builds from nothing, reaches peak density, dissolves
            // Use A/B/A structure with intensity arc
            let aLen1 = Swift.max(32, Int(Double(bodyBars) * 0.35) / 4 * 4)
            let bLen  = Swift.max(32, Int(Double(bodyBars) * 0.40) / 4 * 4)
            let aLen2 = Swift.max(16, bodyBars - aLen1 - bLen)
            return [
                SongSection(startBar: cursor,              lengthBars: aLen1, label: .A, intensity: .low,    mode: .Dorian),
                SongSection(startBar: cursor + aLen1,      lengthBars: bLen,  label: .B, intensity: .high,   mode: .Dorian),
                SongSection(startBar: cursor + aLen1 + bLen, lengthBars: aLen2, label: .A, intensity: .medium, mode: .Dorian)
            ]
        }
    }

    // MARK: - Chord plan (Cosmic: very slow harmonic changes)

    private static func buildChordPlan(
        frame: GlobalMusicalFrame,
        sections: [SongSection],
        cosmicProgFamily: CosmicProgressionFamily,
        rng: inout SeededRNG
    ) -> [ChordWindow] {
        var plan: [ChordWindow] = []
        for section in sections {
            plan.append(contentsOf: buildChordWindows(
                frame: frame,
                section: section,
                cosmicProgFamily: cosmicProgFamily,
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

    /// Cosmic chord windows — fewer chords per section, longer holds (8–32 bars)
    private static func buildChordWindows(
        frame: GlobalMusicalFrame,
        section: SongSection,
        cosmicProgFamily: CosmicProgressionFamily,
        rng: inout SeededRNG
    ) -> [ChordWindow] {
        // Cosmic: chord changes every 8–32 bars (not 4–8 like Motorik)
        // For most sections: 1 chord per section; B sections may get 2
        let chordCount: Int
        switch section.label {
        case .intro, .outro: chordCount = 1
        case .A:
            // static_drone and quartal_stack prefer single chord per section
            switch cosmicProgFamily {
            case .static_drone, .quartal_stack:
                chordCount = 1
            default:
                chordCount = rng.nextDouble() < 0.35 ? 2 : 1
            }
        case .B:
            chordCount = rng.nextDouble() < 0.50 ? 2 : 1
        }

        let barsEach = Swift.max(8, section.lengthBars / chordCount)
        var windows: [ChordWindow] = []
        var bar = section.startBar
        for i in 0..<chordCount {
            let length = (i == chordCount - 1) ? (section.endBar - bar) : barsEach
            let rawRoot = pickCosmicChordRoot(section: section, progFamily: cosmicProgFamily, rng: &rng)
            let root = (section.label == .intro || section.label == .outro) ? "1" : rawRoot
            let type = pickCosmicChordType(progFamily: cosmicProgFamily, mode: section.mode, rng: &rng)
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

    private static func pickCosmicChordRoot(
        section: SongSection,
        progFamily: CosmicProgressionFamily,
        rng: inout SeededRNG
    ) -> String {
        switch progFamily {
        case .static_drone:
            return "1"  // always tonic
        case .two_chord_pendulum:
            // Alternate between root and bVI (Vangelis i → bVI = F#m → D)
            return rng.nextDouble() < 0.6 ? "1" : "b6"
        case .modal_drift:
            // i → bVII → bVI → bVII → i movement
            let degrees = ["1", "b7", "b6", "b7"]
            return degrees[rng.nextInt(upperBound: degrees.count)]
        case .suspended_resolution:
            return "1"  // sus stays on tonic
        case .quartal_stack:
            let degrees = ["1", "4", "b7"]
            return degrees[rng.nextInt(upperBound: degrees.count)]
        }
    }

    private static func pickCosmicChordType(
        progFamily: CosmicProgressionFamily,
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
            // Alternate sus4 and minor
            return rng.nextDouble() < 0.60 ? .sus4 : .minor
        case .quartal_stack:
            return rng.nextDouble() < 0.70 ? .quartal : .sus4
        }
    }
}
