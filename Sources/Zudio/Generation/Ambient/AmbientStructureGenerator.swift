// AmbientStructureGenerator.swift — Ambient generation step 2
// Copyright (c) 2026 Zack Urlocker
// Three forms: pureDrone 40% (no intro/outro), minimalArc 45% (4-bar), breathingArc 15% (6-bar).
// Chord plan built from AmbientProgressionFamily.

import Foundation

struct AmbientStructureGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        ambientProgFamily: AmbientProgressionFamily,
        rng: inout SeededRNG
    ) -> SongStructure {
        let (sections, introStyle, outroStyle) = buildSections(totalBars: frame.totalBars, frame: frame, rng: &rng)
        let chordPlan = buildChordPlan(frame: frame, totalBars: frame.totalBars,
                                       ambientProgFamily: ambientProgFamily, rng: &rng)
        return SongStructure(sections: sections, chordPlan: chordPlan,
                             introStyle: introStyle, outroStyle: outroStyle)
    }

    // MARK: - Sections

    private static func buildSections(totalBars: Int, frame: GlobalMusicalFrame,
                                       rng: inout SeededRNG) -> ([SongSection], IntroStyle, OutroStyle) {
        let formRoll = rng.nextDouble()
        let introBars: Int
        let outroBars: Int
        if formRoll < 0.40 {
            introBars = 0; outroBars = 0  // pureDrone
        } else if formRoll < 0.85 {
            introBars = 4; outroBars = 4  // minimalArc
        } else {
            introBars = 6; outroBars = 6  // breathingArc
        }
        let bodyBars = Swift.max(4, totalBars - introBars - outroBars)
        var sections: [SongSection] = []
        var cursor = 0

        if introBars > 0 {
            sections.append(SongSection(startBar: cursor, lengthBars: introBars,
                                        label: .intro, intensity: .low, mode: frame.mode))
            cursor += introBars
        }
        sections.append(SongSection(startBar: cursor, lengthBars: bodyBars,
                                    label: .A, intensity: .medium, mode: frame.mode))
        cursor += bodyBars
        if outroBars > 0 {
            sections.append(SongSection(startBar: cursor, lengthBars: outroBars,
                                        label: .outro, intensity: .low, mode: frame.mode))
        }
        return (sections, .alreadyPlaying, .fade)
    }

    // MARK: - Chord plan

    private static func buildChordPlan(frame: GlobalMusicalFrame, totalBars: Int,
                                        ambientProgFamily: AmbientProgressionFamily,
                                        rng: inout SeededRNG) -> [ChordWindow] {
        let key  = frame.key
        let mode = frame.mode

        switch ambientProgFamily {

        case .droneSingle:
            let single = makeWindow(root: "1", type: tonicType(for: mode), start: 0, length: totalBars, key: key, mode: mode)
            return injectMidShift(tonic: single, key: key, mode: mode, totalBars: totalBars, rng: &rng)

        case .suspendedDrone:
            // sus2 has no 3rd, so it's mode-neutral — works for all modes
            let single = makeWindow(root: "1", type: .sus2, start: 0, length: totalBars, key: key, mode: mode)
            return injectMidShift(tonic: single, key: key, mode: mode, totalBars: totalBars, rng: &rng)

        case .dissonantHaze:
            let single = makeWindow(root: "1", type: hazeType(for: mode), start: 0, length: totalBars, key: key, mode: mode)
            return injectMidShift(tonic: single, key: key, mode: mode, totalBars: totalBars, rng: &rng)

        case .droneTwo:
            let half   = Swift.max(4, (totalBars / 2 / 4) * 4)
            let second = Swift.max(4, totalBars - half)
            let (deg2, type2) = secondChord(for: mode)
            return [
                makeWindow(root: "1",  type: tonicType(for: mode), start: 0,    length: half,   key: key, mode: mode),
                makeWindow(root: deg2, type: type2,                 start: half, length: second, key: key, mode: mode),
            ]

        case .modalDrift:
            let third = Swift.max(4, (totalBars / 3 / 4) * 4)
            let rem   = Swift.max(4, totalBars - third * 2)
            let (deg2, type2) = secondChord(for: mode)
            let (deg3, type3) = thirdChord(for: mode)
            return [
                makeWindow(root: "1",  type: tonicType(for: mode), start: 0,         length: third, key: key, mode: mode),
                makeWindow(root: deg2, type: type2,                 start: third,      length: third, key: key, mode: mode),
                makeWindow(root: deg3, type: type3,                 start: third * 2,  length: rem,   key: key, mode: mode),
            ]
        }
    }

    // MARK: - Mode-appropriate chord type helpers

    /// Tonic chord type: major modes use major triad, minor modes use minor triad.
    private static func tonicType(for mode: Mode) -> ChordType {
        switch mode {
        case .Ionian, .Mixolydian: return .major
        default:                   return .minor
        }
    }

    /// Dissonant haze tonic — adds colour without chromatic notes.
    /// Mixolydian: dom7 (G B D F in G Mixolydian — F is the natural b7, fully diatonic).
    /// Ionian:     add9 (all four notes stay in the scale).
    /// Minor modes: min7 (all four notes in Dorian/Aeolian scale).
    private static func hazeType(for mode: Mode) -> ChordType {
        switch mode {
        case .Mixolydian: return .dom7
        case .Ionian:     return .add9
        default:          return .min7
        }
    }

    /// Second chord (for droneTwo and modalDrift).
    /// Every returned (degree, type) pair is fully diatonic to its mode.
    private static func secondChord(for mode: Mode) -> (String, ChordType) {
        switch mode {
        case .Ionian:          return ("4", .major)   // IV — C E G fully in G Ionian
        case .MinorPentatonic: return ("b3", .major)  // bIII — C E G fully in A MinorPentatonic
        default:               return ("b7", .major)  // bVII — fully diatonic in Mixolydian/Dorian/Aeolian
        }
    }

    /// Third chord (for modalDrift only).
    /// Every returned (degree, type) pair is fully diatonic to its mode.
    private static func thirdChord(for mode: Mode) -> (String, ChordType) {
        switch mode {
        case .Ionian:          return ("5", .major)   // V — D F# A fully in G Ionian
        case .Mixolydian:      return ("4", .major)   // IV — C E G fully in G Mixolydian
        case .Aeolian:         return ("b6", .major)  // bVI — F A C fully in A Aeolian
        case .MinorPentatonic: return ("4", .sus2)    // IV sus2 — D E A fully in A MinorPentatonic
        default:               return ("4", .major)   // IV — G B D fully in D Dorian
        }
    }

    // MARK: - Plan I: Mid-song chord shift

    /// 50% chance of injecting a 4–8 bar harmonic excursion mid-song, then returning to tonic.
    /// Applied only to single-chord families (droneSingle, suspendedDrone, dissonantHaze).
    /// Bass and leads follow automatically via TonalGovernanceMap; pads remain on original chord tones.
    private static func injectMidShift(
        tonic: ChordWindow, key: String, mode: Mode, totalBars: Int, rng: inout SeededRNG
    ) -> [ChordWindow] {
        guard totalBars >= 16, rng.nextDouble() < 0.50 else { return [tonic] }

        // Mode-appropriate shift chord
        let (shiftDegree, shiftType): (String, ChordType) = {
            switch mode {
            case .Ionian:          return ("4", .major)   // IV — classic major pivot
            case .Mixolydian:      return ("b7", .major)  // bVII — Mixolydian's signature chord
            case .Dorian:          return ("b7", .major)  // bVII — diatonic in Dorian (b6 is not)
            case .MinorPentatonic: return ("b3", .major)  // bIII — only fully-diatonic major choice
            default:               return (rng.nextDouble() < 0.65 ? "b7" : "b6", .major)  // Aeolian
            }
        }()

        // Place shift in the middle third, aligned to 4-bar grid
        let third    = Swift.max(4, totalBars / 3)
        let rawStart = third + rng.nextInt(upperBound: Swift.max(1, third))
        let shiftStart = (rawStart / 4) * 4
        let shiftLen   = rng.nextDouble() < 0.60 ? 4 : 8   // 4 bars (60%) or 8 bars (40%)
        let shiftEnd   = Swift.min(shiftStart + shiftLen, totalBars - 4)
        guard shiftEnd > shiftStart, shiftStart > 0 else { return [tonic] }

        var windows: [ChordWindow] = []
        windows.append(makeWindow(root: tonic.chordRoot, type: tonic.chordType,
                                  start: 0, length: shiftStart, key: key, mode: mode))
        windows.append(makeWindow(root: shiftDegree, type: shiftType,
                                  start: shiftStart, length: shiftEnd - shiftStart, key: key, mode: mode))
        if shiftEnd < totalBars {
            windows.append(makeWindow(root: tonic.chordRoot, type: tonic.chordType,
                                      start: shiftEnd, length: totalBars - shiftEnd, key: key, mode: mode))
        }
        return windows
    }

    // MARK: - Helper

    private static func makeWindow(root: String, type: ChordType,
                                    start: Int, length: Int,
                                    key: String, mode: Mode) -> ChordWindow {
        let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: root, chordType: type, key: key, mode: mode)
        return ChordWindow(startBar: start, lengthBars: length, chordRoot: root, chordType: type,
                           chordTones: ct, scaleTensions: st, avoidTones: at)
    }
}
