// StructureGenerator.swift — generation step 2
// Produces a SongStructure: ordered sections + chord plan.

struct StructureGenerator {
    static func generate(frame: GlobalMusicalFrame, rng: inout SeededRNG) -> SongStructure {
        let form = pickForm(rng: &rng)
        let sections = buildSections(form: form, totalBars: frame.totalBars, rng: &rng)
        let chordPlan = buildChordPlan(frame: frame, sections: sections, rng: &rng)
        return SongStructure(sections: sections, chordPlan: chordPlan)
    }

    // MARK: - Form selection

    private static func pickForm(rng: inout SeededRNG) -> SongForm {
        // Single-A 45%, Subtle A/B 40%, Moderate A/B 15%
        let r = rng.nextDouble()
        if r < 0.45 { return .singleA }
        if r < 0.85 { return .subtleAB }
        return .moderateAB
    }

    // MARK: - Section layout

    private static func buildSections(form: SongForm, totalBars: Int, rng: inout SeededRNG) -> [SongSection] {
        // Intro: 8 or 16 bars (50/50); Outro: 8 or 16 bars (50/50)
        let introBars = rng.nextDouble() < 0.5 ? 8 : 16
        let outroBars = rng.nextDouble() < 0.5 ? 8 : 16
        let bodyBars  = max(16, totalBars - introBars - outroBars)

        var sections: [SongSection] = []
        var cursor = 0

        // Intro
        sections.append(SongSection(startBar: cursor, lengthBars: introBars, label: .intro, intensity: .low, mode: .dorian))
        cursor += introBars

        // Body sections
        let bodySections = buildBodySections(form: form, bodyBars: bodyBars, cursor: cursor, rng: &rng)
        sections.append(contentsOf: bodySections)
        cursor += bodyBars

        // Outro
        sections.append(SongSection(startBar: cursor, lengthBars: outroBars, label: .outro, intensity: .low, mode: bodySections.last?.mode ?? .dorian))

        return sections
    }

    private static func buildBodySections(
        form: SongForm, bodyBars: Int, cursor: Int, rng: inout SeededRNG
    ) -> [SongSection] {
        switch form {
        case .singleA:
            return [SongSection(startBar: cursor, lengthBars: bodyBars, label: .A, intensity: .medium, mode: .dorian)]
        case .subtleAB:
            return buildSubtleAB(bodyBars: bodyBars, cursor: cursor, rng: &rng)
        case .moderateAB:
            return buildModerateAB(bodyBars: bodyBars, cursor: cursor, rng: &rng)
        }
    }

    private static func buildSubtleAB(bodyBars: Int, cursor: Int, rng: inout SeededRNG) -> [SongSection] {
        // A section lengths: 32:25%, 48:35%, 64:30%, 80:10%
        let aLengths = [32, 48, 64, 80]
        let aWeights: [Double] = [0.25, 0.35, 0.30, 0.10]
        let aBars = aLengths[rng.weightedPick(aWeights)]
        let bBars = max(16, bodyBars - aBars)

        let aIntensity: SectionIntensity = rng.nextDouble() < 0.20 ? .low : .medium
        let bMode = Mode.allCases[rng.nextInt(upperBound: Mode.allCases.count)]
        return [
            SongSection(startBar: cursor, lengthBars: aBars, label: .A, intensity: aIntensity, mode: .dorian),
            SongSection(startBar: cursor + aBars, lengthBars: bBars, label: .B, intensity: .high, mode: bMode)
        ]
    }

    private static func buildModerateAB(bodyBars: Int, cursor: Int, rng: inout SeededRNG) -> [SongSection] {
        // A section lengths: 32:30%, 48:40%, 64:25%, 80:5%
        let aLengths = [32, 48, 64, 80]
        let aWeights: [Double] = [0.30, 0.40, 0.25, 0.05]
        let aBars = aLengths[rng.weightedPick(aWeights)]

        // B section: remainder split roughly 40/60
        let remaining = max(32, bodyBars - aBars)
        let bBars = max(16, (remaining * 2) / 3)

        let hasReprise = rng.nextDouble() < 0.30 // A/B/A' reprise variant 30%
        let aIntensity: SectionIntensity = rng.nextDouble() < 0.10 ? .low : .medium
        let bMode = Mode.allCases[rng.nextInt(upperBound: Mode.allCases.count)]
        var sections: [SongSection] = [
            SongSection(startBar: cursor, lengthBars: aBars, label: .A, intensity: aIntensity, mode: .dorian),
            SongSection(startBar: cursor + aBars, lengthBars: bBars, label: .B, intensity: .high, mode: bMode)
        ]
        if hasReprise {
            let repriseBars = rng.nextDouble() < 0.5 ? 16 : 32
            let repriseStart = cursor + aBars + bBars
            sections.append(SongSection(startBar: repriseStart, lengthBars: repriseBars, label: .A, intensity: .medium, mode: .dorian))
        }
        return sections
    }

    // MARK: - Chord plan

    private static func buildChordPlan(
        frame: GlobalMusicalFrame, sections: [SongSection], rng: inout SeededRNG
    ) -> [ChordWindow] {
        var plan: [ChordWindow] = []
        for section in sections {
            let windows = buildChordWindows(frame: frame, section: section, rng: &rng)
            plan.append(contentsOf: windows)
        }
        return plan
    }

    /// One chord per section by default; body sections may get 2–3 chord windows.
    private static func buildChordWindows(
        frame: GlobalMusicalFrame, section: SongSection, rng: inout SeededRNG
    ) -> [ChordWindow] {
        let chordCount: Int
        switch section.label {
        case .intro, .outro: chordCount = 1
        case .A: chordCount = rng.nextDouble() < 0.5 ? 1 : 2
        case .B: chordCount = rng.nextInt(upperBound: 2) + 2 // 2–3
        }

        let barsEach = max(4, section.lengthBars / chordCount)
        var windows: [ChordWindow] = []
        var bar = section.startBar
        for i in 0..<chordCount {
            let length = (i == chordCount - 1) ? (section.endBar - bar) : barsEach
            let root = pickChordRoot(mode: section.mode, rng: &rng)
            let type = pickChordType(mode: section.mode, rng: &rng)
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

    private static func pickChordRoot(mode: Mode, rng: inout SeededRNG) -> String {
        // Diatonic degree strings for mode
        let diatonicDegrees = ["1", "2", "b3", "4", "5", "b6", "b7"]
        return diatonicDegrees[rng.nextInt(upperBound: diatonicDegrees.count)]
    }

    private static func pickChordType(mode: Mode, rng: inout SeededRNG) -> ChordType {
        // Motorik bias: minor and sus2 dominate
        let weights: [Double] = [0.15, 0.30, 0.25, 0.15, 0.15] // major, minor, sus2, dom7, min7
        let types: [ChordType] = [.major, .minor, .sus2, .dom7, .min7]
        return types[rng.weightedPick(weights)]
    }
}
