// AmbientStructureGenerator.swift — Ambient generation step 2
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
            let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: "1", chordType: .minor, key: key, mode: mode)
            let single = ChordWindow(startBar: 0, lengthBars: totalBars, chordRoot: "1", chordType: .minor,
                                     chordTones: ct, scaleTensions: st, avoidTones: at)
            return injectMidShift(tonic: single, key: key, mode: mode, totalBars: totalBars, rng: &rng)

        case .suspendedDrone:
            let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: "1", chordType: .sus2, key: key, mode: mode)
            let single = ChordWindow(startBar: 0, lengthBars: totalBars, chordRoot: "1", chordType: .sus2,
                                     chordTones: ct, scaleTensions: st, avoidTones: at)
            return injectMidShift(tonic: single, key: key, mode: mode, totalBars: totalBars, rng: &rng)

        case .dissonantHaze:
            let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: "1", chordType: .min7, key: key, mode: mode)
            let single = ChordWindow(startBar: 0, lengthBars: totalBars, chordRoot: "1", chordType: .min7,
                                     chordTones: ct, scaleTensions: st, avoidTones: at)
            return injectMidShift(tonic: single, key: key, mode: mode, totalBars: totalBars, rng: &rng)

        case .droneTwo:
            let half = Swift.max(4, (totalBars / 2 / 4) * 4)
            let second = Swift.max(4, totalBars - half)
            let (ct1, st1, at1) = NotePoolBuilder.build(chordRootDegree: "1",  chordType: .minor, key: key, mode: mode)
            let (ct2, st2, at2) = NotePoolBuilder.build(chordRootDegree: "b7", chordType: .major, key: key, mode: mode)
            return [
                ChordWindow(startBar: 0,    lengthBars: half,   chordRoot: "1",  chordType: .minor,
                            chordTones: ct1, scaleTensions: st1, avoidTones: at1),
                ChordWindow(startBar: half, lengthBars: second, chordRoot: "b7", chordType: .major,
                            chordTones: ct2, scaleTensions: st2, avoidTones: at2),
            ]

        case .modalDrift:
            let third = Swift.max(4, (totalBars / 3 / 4) * 4)
            let rem   = Swift.max(4, totalBars - third * 2)
            let (ct1, st1, at1) = NotePoolBuilder.build(chordRootDegree: "1",  chordType: .minor, key: key, mode: mode)
            let (ct2, st2, at2) = NotePoolBuilder.build(chordRootDegree: "b7", chordType: .major, key: key, mode: mode)
            let (ct3, st3, at3) = NotePoolBuilder.build(chordRootDegree: "b6", chordType: .major, key: key, mode: mode)
            return [
                ChordWindow(startBar: 0,         lengthBars: third, chordRoot: "1",  chordType: .minor,
                            chordTones: ct1, scaleTensions: st1, avoidTones: at1),
                ChordWindow(startBar: third,      lengthBars: third, chordRoot: "b7", chordType: .major,
                            chordTones: ct2, scaleTensions: st2, avoidTones: at2),
                ChordWindow(startBar: third * 2,  lengthBars: rem,   chordRoot: "b6", chordType: .major,
                            chordTones: ct3, scaleTensions: st3, avoidTones: at3),
            ]
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
            case .Ionian:     return ("4", .major)        // IV — classic major pivot
            case .Mixolydian: return ("b7", .major)       // bVII — Mixolydian's signature chord
            default:          return (rng.nextDouble() < 0.65 ? "b7" : "b6", .major)  // Dorian/Aeolian
            }
        }()
        let (ctS, stS, atS) = NotePoolBuilder.build(chordRootDegree: shiftDegree, chordType: shiftType,
                                                     key: key, mode: mode)

        // Place shift in the middle third, aligned to 4-bar grid
        let third    = Swift.max(4, totalBars / 3)
        let rawStart = third + rng.nextInt(upperBound: Swift.max(1, third))
        let shiftStart = (rawStart / 4) * 4
        let shiftLen   = rng.nextDouble() < 0.60 ? 4 : 8   // 4 bars (60%) or 8 bars (40%)
        let shiftEnd   = Swift.min(shiftStart + shiftLen, totalBars - 4)
        guard shiftEnd > shiftStart, shiftStart > 0 else { return [tonic] }

        var windows: [ChordWindow] = []
        // Tonic up to shift
        let tonicType = tonic.chordType
        let (ct1, st1, at1) = (tonic.chordTones, tonic.scaleTensions, tonic.avoidTones)
        windows.append(ChordWindow(startBar: 0, lengthBars: shiftStart, chordRoot: tonic.chordRoot,
                                   chordType: tonicType, chordTones: ct1, scaleTensions: st1, avoidTones: at1))
        // Shift window
        windows.append(ChordWindow(startBar: shiftStart, lengthBars: shiftEnd - shiftStart,
                                   chordRoot: shiftDegree, chordType: shiftType,
                                   chordTones: ctS, scaleTensions: stS, avoidTones: atS))
        // Return to tonic
        if shiftEnd < totalBars {
            let (ct2, st2, at2) = NotePoolBuilder.build(chordRootDegree: tonic.chordRoot,
                                                         chordType: tonicType, key: key, mode: mode)
            windows.append(ChordWindow(startBar: shiftEnd, lengthBars: totalBars - shiftEnd,
                                       chordRoot: tonic.chordRoot, chordType: tonicType,
                                       chordTones: ct2, scaleTensions: st2, avoidTones: at2))
        }
        return windows
    }
}
