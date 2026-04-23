// StructureGenerator.swift — generation step 2
// Copyright (c) 2026 Zack Urlocker
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
            let type = pickChordType(mode: frame.mode, rootDegree: rawRoot, rng: &rng)
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
        // Only degrees whose perfect-5th lands on a scale note are included.
        // Degrees whose diatonic triad is diminished (P5 is chromatic) are excluded because
        // none of our chord types (major/minor/sus2/dom7/min7/power) can represent them
        // without introducing out-of-scale tones:
        //   Ionian "7"    — vii dim (e.g. C# in D Ionian: P5=G#, scale has G)
        //   Dorian "6"    — vi dim  (e.g. D# in F# Dorian: P5=A#, scale has A)
        //   Mixolydian "3"— iii dim (e.g. G# in E Mixolydian: P5=D#, scale has D)
        //   Aeolian "2"   — ii dim  (e.g. F# in E Aeolian: P5=C#, scale has C)
        let degrees: [String]
        switch mode {
        case .Ionian:          degrees = ["1", "2", "3", "4", "5", "6"]          // removed "7"
        case .Dorian:          degrees = ["1", "2", "b3", "4", "5", "b7"]        // removed "6"
        case .Mixolydian:      degrees = ["1", "2", "4", "5", "6", "b7"]         // removed "3"
        case .Aeolian:         degrees = ["1", "b3", "4", "5", "b6", "b7"]       // removed "2"
        case .MinorPentatonic: degrees = ["1", "b3", "4", "5", "b7"]
        case .MajorPentatonic: degrees = ["1", "2", "3", "5", "6"]
        }
        return degrees[rng.nextInt(upperBound: degrees.count)]
    }

    private static func pickChordType(mode: Mode, rootDegree: String,
                                       rng: inout SeededRNG) -> ChordType {
        // ─────────────────────────────────────────────────────────────────────────────
        // EXHAUSTIVE mode × degree matrix — one guard per valid (mode, degree) pair.
        //
        // Chord-tone analysis (all intervals are fixed, not scale-relative):
        //   major  = root + M3 + P5       clashes when scale has b3 instead of M3
        //   minor  = root + m3 + P5       clashes when scale has M3 instead of m3
        //   dom7   = root + M3 + P5 + m7  clashes when scale lacks M3 or the m7 pitch
        //   min7   = root + m3 + P5 + M7  clashes when scale lacks m3
        //   sus2   = root + M2 + P5       clashes when scale lacks the M2 above that root
        //   power  = root + P5            always diatonic (P5 is preserved in all modes here)
        //
        // Every case below admits only chord types whose tones are ALL in the 7-note scale.
        // The default case is a safe fallback for pentatonic modes (not reached in practice
        // from StructureGenerator, which is only called by the Motorik path).
        //
        // Exactly one rng.weightedPick call is made — RNG advance count is invariant.
        // ─────────────────────────────────────────────────────────────────────────────

        // ── IONIAN  (scale: 1 2 3 4 5 6 7  e.g. D E F# G A B C#) ───────────────────
        if mode == .Ionian {
            switch rootDegree {
            case "1":
                // I major tonic. dom7 adds b7 (C in D Ionian, scale has C#) — clash.
                let t: [ChordType] = [.major, .sus2, .power]
                return t[rng.weightedPick([0.60, 0.25, 0.15])]
            case "2":
                // ii minor. sus2 OK: M2 of 2nd = scale deg 3 (F# in D Ionian ✓).
                let t: [ChordType] = [.minor, .sus2, .min7, .power]
                return t[rng.weightedPick([0.40, 0.30, 0.20, 0.10])]
            case "3":
                // iii minor. sus2 clashes: M2 of 3rd = chromatic (G# not in D Ionian).
                // dom7 adds b7 of 3rd (C natural not in D Ionian).
                let t: [ChordType] = [.minor, .min7, .power]
                return t[rng.weightedPick([0.65, 0.25, 0.10])]
            case "4":
                // IV major. dom7 adds b7 of IV = the chromatic leading tone (F in D Ionian,
                // scale has F#) — clash.
                let t: [ChordType] = [.major, .sus2, .power]
                return t[rng.weightedPick([0.55, 0.30, 0.15])]
            case "5":
                // V major. V7 (dom7) = the diatonic dominant seventh — fully in scale.
                // sus2 OK: M2 of 5th = scale deg 6 (B in D Ionian ✓).
                let t: [ChordType] = [.major, .dom7, .sus2, .power]
                return t[rng.weightedPick([0.40, 0.25, 0.25, 0.10])]
            case "6":
                // vi minor. sus2 OK: M2 of 6th = scale deg 7 (C# in D Ionian ✓).
                let t: [ChordType] = [.minor, .sus2, .min7, .power]
                return t[rng.weightedPick([0.40, 0.30, 0.20, 0.10])]
            default:
                let t: [ChordType] = [.minor, .sus2, .power]
                return t[rng.weightedPick([0.50, 0.30, 0.20])]
            }
        }

        // ── DORIAN  (scale: 1 2 b3 4 5 6 b7  e.g. D E F G A B C) ──────────────────
        if mode == .Dorian {
            switch rootDegree {
            case "1":
                // i minor tonic. major/dom7 need M3 (F# in D Dorian, scale has F) — clash.
                let t: [ChordType] = [.minor, .sus2, .min7, .power]
                return t[rng.weightedPick([0.45, 0.30, 0.15, 0.10])]
            case "2":
                // ii minor. sus2 clashes: M2 of 2nd = chromatic (F# in D Dorian, scale has F).
                // major/dom7 also need M3 of 2nd (G# not in scale).
                let t: [ChordType] = [.minor, .min7, .power]
                return t[rng.weightedPick([0.55, 0.30, 0.15])]
            case "b3":
                // bIII major (e.g. F major in D Dorian: F A C — all in scale).
                // minor adds m3 of bIII (Ab) — not in scale.
                let t: [ChordType] = [.major, .sus2, .power]
                return t[rng.weightedPick([0.55, 0.30, 0.15])]
            case "4":
                // IV major (e.g. G major in D Dorian: G B D — B = Dorian char. 6th ✓).
                // IV7 = G B D F — all in D Dorian ✓ (the bluesy Dorian IV7).
                // minor on IV needs m3 (Bb in D Dorian) — not in scale.
                let t: [ChordType] = [.major, .sus2, .dom7, .power]
                return t[rng.weightedPick([0.40, 0.30, 0.20, 0.10])]
            case "5":
                // v minor (e.g. Am in D Dorian: A C E — all in scale).
                // major/dom7 need M3 of 5th (C# in D Dorian) — clash.
                // sus2 OK: M2 of 5th = scale deg 6 (B in D Dorian ✓).
                let t: [ChordType] = [.minor, .sus2, .min7, .power]
                return t[rng.weightedPick([0.45, 0.25, 0.20, 0.10])]
            case "b7":
                // bVII major (e.g. C major in D Dorian: C E G — all in scale).
                // dom7 on bVII adds m7 of bVII (Bb in D Dorian) — not in scale.
                // minor adds m3 of bVII (Eb) — not in scale.
                let t: [ChordType] = [.major, .sus2, .power]
                return t[rng.weightedPick([0.60, 0.25, 0.15])]
            default:
                let t: [ChordType] = [.minor, .sus2, .power]
                return t[rng.weightedPick([0.50, 0.30, 0.20])]
            }
        }

        // ── MIXOLYDIAN  (scale: 1 2 3 4 5 6 b7  e.g. G A B C D E F) ────────────────
        if mode == .Mixolydian {
            switch rootDegree {
            case "1":
                // I major tonic. dom7 = the defining Mixolydian colour (G7 in G Mixolydian ✓).
                // minor adds b3 (Bb in G Mixolydian) — not in scale.
                let t: [ChordType] = [.major, .sus2, .dom7, .power]
                return t[rng.weightedPick([0.35, 0.30, 0.20, 0.15])]
            case "2":
                // ii minor (e.g. Am in G Mixolydian: A C E — all in scale).
                // major/dom7 need M3 of 2nd (C# in G Mixolydian) — clash.
                // sus2 OK: M2 of 2nd = scale deg 3 (B in G Mixolydian ✓).
                let t: [ChordType] = [.minor, .sus2, .min7, .power]
                return t[rng.weightedPick([0.45, 0.25, 0.20, 0.10])]
            case "4":
                // IV major (e.g. C major in G Mixolydian: C E G — all in scale).
                // dom7 on IV = C7 = C E G Bb — Bb not in G Mixolydian (has F) — clash.
                // minor adds m3 of IV (Eb) — not in scale.
                let t: [ChordType] = [.major, .sus2, .power]
                return t[rng.weightedPick([0.55, 0.30, 0.15])]
            case "5":
                // v minor (e.g. Dm in G Mixolydian: D F A — all in scale).
                // major/dom7 need M3 of 5th (F# in G Mixolydian) — clash.
                // sus2 OK: M2 of 5th = scale deg 6 (E in G Mixolydian ✓).
                let t: [ChordType] = [.minor, .sus2, .min7, .power]
                return t[rng.weightedPick([0.50, 0.25, 0.15, 0.10])]
            case "6":
                // vi minor (e.g. Em in G Mixolydian: E G B — all in scale).
                // sus2 of 6th needs M2 = the raised 7th (F# in G Mixolydian, scale has F) — clash.
                let t: [ChordType] = [.minor, .min7, .power]
                return t[rng.weightedPick([0.60, 0.25, 0.15])]
            case "b7":
                // bVII major (e.g. F major in G Mixolydian: F A C — all in scale).
                // minor/dom7/min7 all add chromatic tones not in Mixolydian.
                let t: [ChordType] = [.major, .sus2, .power]
                return t[rng.weightedPick([0.55, 0.30, 0.15])]
            default:
                let t: [ChordType] = [.minor, .sus2, .power]
                return t[rng.weightedPick([0.50, 0.30, 0.20])]
            }
        }

        // ── AEOLIAN  (scale: 1 2 b3 4 5 b6 b7  e.g. E F# G A B C D) ────────────────
        if mode == .Aeolian {
            switch rootDegree {
            case "1":
                // i minor tonic. major/dom7 need M3 (G# in E Aeolian) — clash.
                // sus2 OK: M2 of tonic = scale deg 2 (F# in E Aeolian ✓).
                let t: [ChordType] = [.minor, .sus2, .min7, .power]
                return t[rng.weightedPick([0.45, 0.30, 0.15, 0.10])]
            case "b3":
                // bIII major (e.g. G major in E Aeolian: G B D — all in scale).
                // dom7 on bIII = G7 = G B D F — F not in E Aeolian (has F#) — clash.
                // minor adds m3 of bIII (Bb) — not in scale.
                let t: [ChordType] = [.major, .sus2, .power]
                return t[rng.weightedPick([0.55, 0.30, 0.15])]
            case "4":
                // iv minor (e.g. Am in E Aeolian: A C E — all in scale).
                // major/dom7 need M3 of 4th (C# in E Aeolian) — clash.
                // sus2 OK: M2 of 4th = scale deg 5 (B in E Aeolian ✓).
                let t: [ChordType] = [.minor, .sus2, .min7, .power]
                return t[rng.weightedPick([0.45, 0.25, 0.20, 0.10])]
            case "5":
                // v minor (e.g. Bm in E Aeolian: B D F# — all in scale).
                // sus2 clashes: M2 of 5th = C# — scale has C natural — clash.
                // major/dom7 need the leading tone (D# in E Aeolian) — clash.
                let t: [ChordType] = [.minor, .min7, .power]
                return t[rng.weightedPick([0.65, 0.25, 0.10])]
            case "b6":
                // bVI major (e.g. C major in E Aeolian: C E G — all in scale).
                // dom7 on bVI adds m7 of bVI (Bb in E Aeolian) — not in scale.
                // minor adds m3 of bVI (Eb) — not in scale.
                let t: [ChordType] = [.major, .sus2, .power]
                return t[rng.weightedPick([0.55, 0.30, 0.15])]
            case "b7":
                // bVII major (e.g. D major in E Aeolian: D F# A — all in scale).
                // bVII7 = D7 = D F# A C — C = b6 of E Aeolian ✓ — fully diatonic.
                // minor adds m3 of bVII (F in E Aeolian) — scale has F# — clash.
                let t: [ChordType] = [.major, .dom7, .sus2, .power]
                return t[rng.weightedPick([0.45, 0.20, 0.25, 0.10])]
            default:
                let t: [ChordType] = [.minor, .sus2, .power]
                return t[rng.weightedPick([0.50, 0.30, 0.20])]
            }
        }

        // ── FALLBACK  (MinorPentatonic / MajorPentatonic — not reached from StructureGenerator) ──
        let t: [ChordType] = [.minor, .sus2, .power]
        return t[rng.weightedPick([0.50, 0.30, 0.20])]
    }
}
