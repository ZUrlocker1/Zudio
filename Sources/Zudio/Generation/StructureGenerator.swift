// StructureGenerator.swift — generation step 2
// Produces a SongStructure: ordered sections + chord plan.

struct StructureGenerator {
    static func generate(frame: GlobalMusicalFrame, rng: inout SeededRNG) -> SongStructure {
        let form = pickForm(rng: &rng)
        let (sections, introStyle, outroStyle) = buildSections(form: form, totalBars: frame.totalBars, rng: &rng)
        let chordPlan = buildChordPlan(frame: frame, sections: sections, rng: &rng)
        return SongStructure(sections: sections, chordPlan: chordPlan, introStyle: introStyle, outroStyle: outroStyle)
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

    private static func buildSections(form: SongForm, totalBars: Int, rng: inout SeededRNG) -> (sections: [SongSection], introStyle: IntroStyle, outroStyle: OutroStyle) {
        // Motorik intro: 2 or 4 bars (50/50 — keep it tight); Outro: 4 or 8 bars
        let introBars = rng.nextDouble() < 0.5 ? 2 : 4
        let outroBars = rng.nextDouble() < 0.5 ? 4 : 8
        let bodyBars  = max(16, totalBars - introBars - outroBars)

        var sections: [SongSection] = []
        var cursor = 0

        // Intro
        sections.append(SongSection(startBar: cursor, lengthBars: introBars, label: .intro, intensity: .low, mode: .Dorian))
        cursor += introBars

        // Body sections
        let bodySections = buildBodySections(form: form, bodyBars: bodyBars, cursor: cursor, rng: &rng)
        sections.append(contentsOf: bodySections)
        cursor += bodyBars

        // Outro
        sections.append(SongSection(startBar: cursor, lengthBars: outroBars, label: .outro, intensity: .low, mode: bodySections.last?.mode ?? .Dorian))

        // Pick intro/outro styles — equal weight across all three options.
        // coldStart gets a 50/50 sub-choice: drums-only bar 0, or bass+drums together.
        let outroStyles: [OutroStyle] = [.fade, .dissolve, .coldStop]
        let outroStyle = outroStyles[rng.nextInt(upperBound: 3)]
        let introStyle: IntroStyle
        switch rng.nextInt(upperBound: 3) {
        case 0:  introStyle = .alreadyPlaying
        case 1:  introStyle = .progressiveEntry
        default: introStyle = .coldStart(drumsOnly: rng.nextDouble() < 0.5)
        }

        return (sections, introStyle, outroStyle)
    }

    private static func buildBodySections(
        form: SongForm, bodyBars: Int, cursor: Int, rng: inout SeededRNG
    ) -> [SongSection] {
        switch form {
        case .singleA:
            return [SongSection(startBar: cursor, lengthBars: bodyBars, label: .A, intensity: .medium, mode: .Dorian)]
        case .subtleAB:
            return buildSubtleAB(bodyBars: bodyBars, cursor: cursor, rng: &rng)
        case .moderateAB:
            return buildModerateAB(bodyBars: bodyBars, cursor: cursor, rng: &rng)
        }
    }

    private static func buildSubtleAB(bodyBars: Int, cursor: Int, rng: inout SeededRNG) -> [SongSection] {
        // A section lengths: 32:25%, 48:35%, 64:30%, 80:10%
        // Clamped so A + B (≥16) fits within bodyBars (important for test mode short songs).
        let aLengths = [32, 48, 64, 80]
        let aWeights: [Double] = [0.25, 0.35, 0.30, 0.10]
        let aBars = min(aLengths[rng.weightedPick(aWeights)], max(16, bodyBars - 16))
        let bBars = max(16, bodyBars - aBars)

        let aIntensity: SectionIntensity = rng.nextDouble() < 0.20 ? .low : .medium
        let bMode = Mode.allCases[rng.nextInt(upperBound: Mode.allCases.count)]
        return [
            SongSection(startBar: cursor, lengthBars: aBars, label: .A, intensity: aIntensity, mode: .Dorian),
            SongSection(startBar: cursor + aBars, lengthBars: bBars, label: .B, intensity: .high, mode: bMode)
        ]
    }

    private static func buildModerateAB(bodyBars: Int, cursor: Int, rng: inout SeededRNG) -> [SongSection] {
        // A section lengths: 32:30%, 48:40%, 64:25%, 80:5%
        let aLengths = [32, 48, 64, 80]
        let aWeights: [Double] = [0.30, 0.40, 0.25, 0.05]
        let aLengthRaw = aLengths[rng.weightedPick(aWeights)]

        // Decide reprise first so B can be sized to exactly fill the remainder.
        let hasReprise = rng.nextDouble() < 0.30 // A/B/A' reprise variant 30%
        let aIntensity: SectionIntensity = rng.nextDouble() < 0.10 ? .low : .medium
        let bMode = Mode.allCases[rng.nextInt(upperBound: Mode.allCases.count)]
        // Always consume the reprise-length RNG draw so seed outputs stay stable.
        let repriseLength = rng.nextDouble() < 0.5 ? 16 : 32
        let repriseBars = hasReprise ? repriseLength : 0

        // Clamp A so A + B (≥16) + reprise fits within bodyBars (important for test mode short songs).
        let aBars = min(aLengthRaw, max(16, bodyBars - 16 - repriseBars))

        // B fills whatever bodyBars remain after A (and reprise), ensuring no uncovered bars.
        let bBars = max(16, bodyBars - aBars - repriseBars)

        var sections: [SongSection] = [
            SongSection(startBar: cursor, lengthBars: aBars, label: .A, intensity: aIntensity, mode: .Dorian),
            SongSection(startBar: cursor + aBars, lengthBars: bBars, label: .B, intensity: .high, mode: bMode)
        ]
        if hasReprise {
            let repriseStart = cursor + aBars + bBars
            sections.append(SongSection(startBar: repriseStart, lengthBars: repriseBars, label: .A, intensity: .medium, mode: .Dorian))
        }
        return sections
    }

    // MARK: - Chord plan

    private static func buildChordPlan(
        frame: GlobalMusicalFrame, sections: [SongSection], rng: inout SeededRNG
    ) -> [ChordWindow] {
        var plan: [ChordWindow] = []
        for section in sections {
            plan.append(contentsOf: buildChordWindows(frame: frame, section: section, rng: &rng))
        }
        return anchorIntroToBody(plan: plan, frame: frame, sections: sections)
    }

    /// Replaces the intro chord window's root+type with the first body chord's root+type.
    /// This makes the intro bass/pads sit in the same harmonic world as the opening body bar,
    /// eliminating the "different key" jump at the intro→body transition.
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

    /// One chord per section by default; body sections may get 2–3 chord windows.
    private static func buildChordWindows(
        frame: GlobalMusicalFrame, section: SongSection, rng: inout SeededRNG
    ) -> [ChordWindow] {
        let chordCount: Int
        switch section.label {
        case .intro, .outro: chordCount = 1
        case .A: chordCount = rng.nextDouble() < 0.5 ? 1 : 2
        case .B: chordCount = rng.nextInt(upperBound: 2) + 2 // 2–3
        default: chordCount = 1  // bridge / ramp sections: single chord
        }

        let barsEach = max(4, section.lengthBars / chordCount)
        var windows: [ChordWindow] = []
        var bar = section.startBar
        for i in 0..<chordCount {
            let length = (i == chordCount - 1) ? (section.endBar - bar) : barsEach
            // Consume the RNG call regardless, but anchor intro/outro to tonic so all
            // instruments (bass, pads) are tonally grounded before and after the main body.
            // Use frame.mode (actual key mode) — not section.mode which is hardcoded Dorian —
            // so chord roots and scale tension pools are diatonic to the song's real key.
            let rawRoot = pickChordRoot(mode: frame.mode, rng: &rng)
            let root = (section.label == .intro || section.label == .outro) ? "1" : rawRoot
            let type = pickChordType(mode: frame.mode, rng: &rng)
            let (tones, tensions, avoids) = NotePoolBuilder.build(
                chordRootDegree: root,
                chordType: type,
                key: frame.key,
                mode: frame.mode
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
        // Diatonic degree strings per mode — only degrees whose pitch class is in the scale.
        // Using a fixed "Aeolian" list for all modes causes borrowed roots in major modes
        // (e.g. b3=C natural in A Ionian, which has C#) producing severe cross-track clashes.
        let degrees: [String]
        switch mode {
        case .Ionian:          degrees = ["1", "2", "3", "4", "5", "6", "7"]
        case .Dorian:          degrees = ["1", "2", "b3", "4", "5", "6", "b7"]
        case .Mixolydian:      degrees = ["1", "2", "3", "4", "5", "6", "b7"]
        case .Aeolian:         degrees = ["1", "2", "b3", "4", "5", "b6", "b7"]
        case .MinorPentatonic: degrees = ["1", "b3", "4", "5", "b7"]
        case .MajorPentatonic: degrees = ["1", "2", "3", "5", "6"]
        }
        return degrees[rng.nextInt(upperBound: degrees.count)]
    }

    private static func pickChordType(mode: Mode, rng: inout SeededRNG) -> ChordType {
        // Motorik bias: minor and sus2 dominate
        let weights: [Double] = [0.15, 0.30, 0.25, 0.15, 0.15] // major, minor, sus2, dom7, min7
        let types: [ChordType] = [.major, .minor, .sus2, .dom7, .min7]
        return types[rng.weightedPick(weights)]
    }
}
