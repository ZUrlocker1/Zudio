// KosmicMusicalFrameGenerator.swift — Kosmic generation step 1
// Copyright (c) 2026 Zack Urlocker
// Produces a GlobalMusicalFrame tuned for Berlin School / Kosmic style.
// Reuses GlobalMusicalFrame (same struct as Motorik) with Kosmic distributions.

import Foundation

/// Kosmic Space's derived seed streams. Every Space-only draw comes from one of these, so the main
/// stream keeps the order base Kosmic and Drift depend on. Each is
/// `SeededRNG(seed: songSeed ^ base ^ salt)`.
/// NEVER change or reuse a value: every Space song's notes depend on them.
enum KosmicSpaceStream: UInt64 {
    /// The frame: harmony family, tempo and the Space draws made with it
    case frame            = 0
    /// Texture auto-pan rate
    case texturePan       = 0x7E87_9A17
    /// Chord-cycle builder
    case chordCycle       = 0xC7C1E
    /// The bridge (`SpaceBridge`)
    case bridge           = 0xB81D_6E
    /// The break schedule (`KosmicSpaceArrangement`)
    case arrangement      = 0xB2EA_C5
    /// The arrangement's drum and bass thinning and handclap
    case arrangementDrums = 0xD2_0B7E

    static let base: UInt64 = 0x05AC_E0A7_1976_0E04

    func rng(seed: UInt64) -> SeededRNG {
        SeededRNG(seed: seed ^ KosmicSpaceStream.base ^ rawValue)
    }
}

struct KosmicMusicalFrameGenerator {

    // Shadow root semitone: tritone partner (KOS-RULE-14)
    // Not stored in frame — derived at generation time and passed to generators that need it.
    static func shadowRoot(frame: GlobalMusicalFrame) -> Int {
        (frame.keySemitoneValue + 6) % 12
    }

    // MARK: - Substyle shares

    /// Shares of the one roll that picks Kosmic Drift, Kosmic Space or base Kosmic.
    /// TESTING split: Drift 10 / Space 80 / base 10, so a listening batch is mostly Space.
    /// Release split, to be confirmed by listening: Drift 0.30 / Space 0.25 / base 0.45.
    /// Moving `driftShare` changes which existing seeds roll Drift; the determinism
    /// fingerprint is pinned against the release values once they are restored.
    static let driftShare = 0.10
    static let spaceShare = 0.80
    /// Share of Space songs in ab and aba forms that take a bridge (`SpaceBridge`).
    /// Release value 0.30 (Zack, 2026-11-06): about 1 Space song in 6. Testing used 0.80.
    static let spaceBridgeShare = 0.30

    /// Bars per full left-right sweep of a Space song's Texture auto-pan: 2 (25%), 4 (50%) or
    /// 8 (25%). Drawn from the song seed on its own stream, so playback, regeneration and export
    /// agree without storing it.
    static func spaceTexturePanBars(seed: UInt64) -> Int {
        var rng = KosmicSpaceStream.texturePan.rng(seed: seed)
        return [2, 4, 8][rng.weightedPick([0.25, 0.50, 0.25])]
    }

    static func generate(
        rng: inout SeededRNG,
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil
    ) -> (frame: GlobalMusicalFrame, percussionStyle: PercussionStyle, kosmicProgFamily: KosmicProgressionFamily,
          isKosmicDrift: Bool, isDriftDreamscape: Bool, driftVelocityBase: Int, isKosmicSpace: Bool) {

        // Kosmic Drift and Kosmic Space share one draw — the slot Drift has always used
        let substyleRoll  = rng.nextDouble()
        let isKosmicDrift = substyleRoll < driftShare
        let isKosmicSpace = !isKosmicDrift && substyleRoll < driftShare + spaceShare
        var spaceRNG = KosmicSpaceStream.frame.rng(seed: seed)
        // Space harmony family, drawn first because it sets the song mode
        let spaceFamily: KosmicProgressionFamily? = isKosmicSpace ? pickSpaceFamily(rng: &spaceRNG) : nil
        // Dreamscape variant: ~10% of Drift songs (must be Drift first)
        let isDriftDreamscape = isKosmicDrift && rng.nextDouble() < 0.15
        // Flat velocity base for BoC-style rules: drawn once per song, 85–92
        let driftVelocityBase = isKosmicDrift ? (85 + rng.nextInt(upperBound: 8)) : 89

        let key = keyOverride ?? pickKey(rng: &rng)

        // Tempo: Space 96–128 on its own stream; Drift uses Mode C (70–90); Dreamscape 70–80.
        // When isKosmicDrift, consume the same RNG slot as normal pickTempo would
        // to keep base Kosmic songs seed-stable regardless of the Drift flag.
        var tempo: Int
        if isKosmicSpace {
            let _ = pickTempo(rng: &rng)   // consume base slot
            tempo = pickSpaceTempo(rng: &spaceRNG)
        } else if isKosmicDrift {
            let _ = pickTempo(rng: &rng)   // consume base slot — keeps non-Drift songs stable
            let driftRange = isDriftDreamscape ? 11 : 21   // 70–80 vs 70–90
            tempo = 70 + rng.nextInt(upperBound: driftRange)
        } else {
            tempo = tempoOverride ?? pickTempo(rng: &rng)
            tempo = Swift.max(108, Swift.min(tempo, 126))
        }
        if let t = tempoOverride { tempo = t }

        let mood = moodOverride ?? pickMood(rng: &rng)

        // Mode: Drift uses different weights (Dorian 50%, Aeolian 22%, Mixolydian 20%, Ionian 8%, no Phrygian)
        let mode: Mode
        if let spaceFamily {
            let _ = pickMode(rng: &rng)   // consume base slot
            mode = spaceMode(for: spaceFamily, rng: &spaceRNG)
        } else if isKosmicDrift {
            let _ = pickMode(rng: &rng)   // consume base slot
            let driftModes:   [Mode]   = [.Dorian, .Aeolian, .Mixolydian, .Ionian]
            let driftWeights: [Double] = [0.50,    0.22,     0.20,        0.08]
            mode = driftModes[rng.weightedPick(driftWeights)]
        } else {
            mode = pickMode(rng: &rng)
        }

        // Progression family: Drift uses static_drone-heavy weights
        let family: ProgressionFamily
        if isKosmicDrift {
            let _ = pickProgressionFamilyMotarik(rng: &rng)  // consume base slot
            // modal_cadence_bVI_bVII_I excluded — rock/anthemic cadence, wrong for Drift
            let driftFamilies: [ProgressionFamily] = [.static_tonic, .two_chord_I_bVII, .minor_loop_i_VII, .minor_loop_i_VI]
            let driftFWeights: [Double]            = [0.37,           0.31,              0.20,              0.12]
            family = driftFamilies[rng.weightedPick(driftFWeights)]
        } else {
            family = pickProgressionFamilyMotarik(rng: &rng)
        }

        let total = pickTotalBars(tempo: tempo, rng: &rng)

        // Percussion / drum rule: Drift uses its own pool; Dreamscape forces floating snare
        let percStyle: PercussionStyle
        if isKosmicSpace {
            let _ = pickPercussionStyle(tempo: tempo, rng: &rng)  // consume base slot
            percStyle = pickSpacePercussionStyle(rng: &spaceRNG)
        } else if isKosmicDrift {
            let _ = pickPercussionStyle(tempo: tempo, rng: &rng)  // consume base slot
            if isDriftDreamscape {
                percStyle = .driftLopingGroove  // Dreamscape always uses floating snare variant
            } else {
                percStyle = pickDriftPercussionStyle(tempo: tempo, rng: &rng)
            }
        } else {
            percStyle = pickPercussionStyle(tempo: tempo, rng: &rng)
        }

        // Kosmic progression family: Drift uses static_drone-heavy weights
        let kosmicFamily: KosmicProgressionFamily
        if let spaceFamily {
            let _ = pickKosmicProgressionFamily(rng: &rng)   // consume base slot
            kosmicFamily = spaceFamily
        } else if isKosmicDrift {
            let _ = pickKosmicProgressionFamily(rng: &rng)   // consume base slot
            // quartal_stack excluded — abstract/angular, anti-Drift character
            let driftKFamilies: [KosmicProgressionFamily] = [.static_drone, .two_chord_pendulum, .modal_drift, .suspended_resolution]
            let driftKWeights:  [Double]                  = [0.37,           0.31,                0.20,          0.12]
            kosmicFamily = driftKFamilies[rng.weightedPick(driftKWeights)]
        } else {
            kosmicFamily = pickKosmicProgressionFamily(rng: &rng)
        }

        let frame = GlobalMusicalFrame(
            key: key,
            mode: mode,
            tempo: tempo,
            mood: mood,
            progressionFamily: family,
            totalBars: total
        )
        return (frame, percStyle, kosmicFamily, isKosmicDrift, isDriftDreamscape, driftVelocityBase, isKosmicSpace)
    }

    // MARK: - Kosmic Space (Phase 1: Oxygene)

    /// Space harmony families, every one in one pool. Each later family takes the average weight
    /// (Zack, 2026-11-06), and the Oxygene three keep their 55/30/15 shape: Dorian Vamp 20.6%,
    /// Aeolian Cycle 11.3%, Two-Chord Sway 5.6% (Oxygene 4, 8 and 3); Magnetic Fields Arc, Magnetic
    /// Fields Turn, Equinoxe Phrygian, Magnetic Fields Descent and Chronologie Pop Loop 12.5% each.
    private static func pickSpaceFamily(rng: inout SeededRNG) -> KosmicProgressionFamily {
        let families: [KosmicProgressionFamily] = [.oxygeneDorianVamp, .oxygeneAeolianCycle, .oxygeneTwoChordSway,
                                                   .magneticArc, .magneticTurn, .equinoxePhrygian, .magneticDescent,
                                                   .chronologiePopLoop]
        let weights:  [Double]                  = [0.206,              0.113,                0.056,
                                                   0.125,        0.125,         0.125,             0.125,
                                                   0.125]
        return families[rng.weightedPick(weights)]
    }

    /// The family sets the mode. Two-Chord Sway is Aeolian or Dorian, 50/50. The two Magnetic Fields
    /// minor families are Aeolian: their major V brings its own leading tone (`spaceChordScale`), as
    /// Jarre plays harmonic minor only over the V, and the bVII of the Turn stays in the scale.
    private static func spaceMode(for family: KosmicProgressionFamily, rng: inout SeededRNG) -> Mode {
        switch family {
        case .oxygeneDorianVamp:   return .Dorian
        case .oxygeneAeolianCycle, .magneticArc, .magneticTurn: return .Aeolian
        case .equinoxePhrygian:    return .Phrygian
        case .magneticDescent, .chronologiePopLoop: return .Ionian
        default:                   return rng.nextDouble() < 0.50 ? .Aeolian : .Dorian
        }
    }

    /// Space tempo: triangular, min 96, peak 118, max 128 (widened for Magnetic Fields and
    /// Equinoxe, Zack, 2026-11-06). The Oxygene pieces run 100, 110, 121.
    private static func pickSpaceTempo(rng: inout SeededRNG) -> Int {
        let minT = 96.0, peakT = 118.0, maxT = 128.0
        let r  = rng.nextDouble()
        let fc = (peakT - minT) / (maxT - minT)
        let raw: Double
        if r < fc {
            raw = minT + Foundation.sqrt(r * (maxT - minT) * (peakT - minT))
        } else {
            raw = maxT - Foundation.sqrt((1 - r) * (maxT - minT) * (maxT - peakT))
        }
        return Swift.max(96, Swift.min(128, Int(raw.rounded())))
    }

    /// Space drum rule pool (Zack, 2026-11-07): KOS-DRUM-009 Oxygene Preset Box 26%, KOS-DRUM-001
    /// JMJ Mini Pops 20%, KOS-DRUM-012 Oxygene 6 Hand Percussion 15% and KOS-DRUM-010 Magnetic
    /// Gallop 15% (the last two are distinctive, so held back), KOS-DRUM-005 Electric Buddha Pulse
    /// 12% (a plain beat to take load off the Preset Box) and KOS-DRUM-000 no percussion 12%.
    static func pickSpacePercussionStyle(rng: inout SeededRNG) -> PercussionStyle {
        let r = rng.nextDouble()
        return r < 0.26 ? .spaceOxygenePresetBox
             : r < 0.46 ? .minimal
             : r < 0.61 ? .spaceOxygeneHandPercussion
             : r < 0.73 ? .absent
             : r < 0.88 ? .spaceMagneticRhythmBox
             : .spaceBuddhaPulse
    }

    /// Drift drum rule pool — evenly weighted regardless of tempo.
    /// Drift-exclusive (007/008/absent) = 78%; shared minimal (001) = 22%.
    static func pickDriftPercussionStyle(tempo: Int, rng: inout SeededRNG) -> PercussionStyle {
        let styles:  [PercussionStyle] = [.driftLopingGroove, .driftHalfTimeLope, .absent, .minimal]
        let weights: [Double]          = [0.29,                0.24,               0.25,    0.22]
        return styles[rng.weightedPick(weights)]
    }

    // MARK: - Private helpers

    /// Kosmic key weights — minor keys heavily weighted (KOS-RULE-02 confirms minor preference)
    private static func pickKey(rng: inout SeededRNG) -> String {
        // Am 20%, Em 18%, Dm 15%, Gm 12%, Cm 10%, Fm 8%, Bm 7%, others 10%
        // We pick the root and let mode determine minor/major flavour
        let keys:    [String] = ["A",  "E",  "D",  "G",  "C",  "F",  "B",  "F#", "Bb", "Eb", "Ab", "C#"]
        let weights: [Double] = [0.20, 0.18, 0.15, 0.12, 0.10, 0.08, 0.07, 0.02, 0.02, 0.02, 0.02, 0.02]
        return keys[rng.weightedPick(weights)]
    }

    /// Kosmic tempo: bimodal distribution per KOS-RULE-20
    /// Mode A (70%): triangular min=115, peak=120, max=126 — driving Kosmic
    /// Mode B (30%): triangular min=108, peak=113, max=118 — contemplative Kosmic
    /// Floor raised from 88 to 108: sub-108 BPM makes the 16th-note grid feel sluggish.
    /// Reference artists (TD Phaedra/Rubycon, Craven Faults groove tracks) bottom out ~108.
    private static func pickTempo(rng: inout SeededRNG) -> Int {
        let useDriverMode = rng.nextDouble() < 0.70
        let minT: Double  = useDriverMode ? 115.0 : 108.0
        let peakT: Double = useDriverMode ? 120.0 : 113.0
        let maxT: Double  = useDriverMode ? 126.0 : 118.0
        let r = rng.nextDouble()
        let fc = (peakT - minT) / (maxT - minT)
        let raw: Double
        if r < fc {
            raw = minT + Foundation.sqrt(r * (maxT - minT) * (peakT - minT))
        } else {
            raw = maxT - Foundation.sqrt((1 - r) * (maxT - minT) * (maxT - peakT))
        }
        return Swift.max(20, Swift.min(200, Int(raw.rounded())))
    }

    private static func pickMood(rng: inout SeededRNG) -> Mood {
        // Kosmic mood weights — Dream/Deep dominate
        let weights: [Double] = [0.35, 0.30, 0.20, 0.15]
        let moods: [Mood] = [.Dream, .Deep, .Free, .Bright]
        return moods[rng.weightedPick(weights)]
    }

    /// Kosmic modes — Dorian 45%, Aeolian 32%, Mixolydian 15%, Ionian 8%
    /// (KOS-RULE-02: Dorian confirmed as primary from Mister Mosca analysis)
    private static func pickMode(rng: inout SeededRNG) -> Mode {
        let modes:   [Mode]   = [.Dorian, .Aeolian, .Mixolydian, .Ionian]
        let weights: [Double] = [0.45,    0.32,     0.15,        0.08]
        return modes[rng.weightedPick(weights)]
    }

    /// Motorik-compatible ProgressionFamily used for StructureGenerator chord plan
    private static func pickProgressionFamilyMotarik(rng: inout SeededRNG) -> ProgressionFamily {
        // For Kosmic, we favour static_tonic and two_chord_I_bVII heavily
        let families: [ProgressionFamily] = [
            .static_tonic, .two_chord_I_bVII, .minor_loop_i_VII,
            .minor_loop_i_VI, .modal_cadence_bVI_bVII_I
        ]
        let weights: [Double] = [0.35, 0.30, 0.15, 0.12, 0.08]
        return families[rng.weightedPick(weights)]
    }

    /// Kosmic-specific progression family (for KosmicStructureGenerator)
    private static func pickKosmicProgressionFamily(rng: inout SeededRNG) -> KosmicProgressionFamily {
        let families: [KosmicProgressionFamily] = [
            .static_drone, .two_chord_pendulum, .modal_drift, .suspended_resolution, .quartal_stack
        ]
        let weights: [Double] = [0.30, 0.25, 0.20, 0.15, 0.10]
        return families[rng.weightedPick(weights)]
    }

    /// PercussionStyle weights (tempo >= 100):
    ///   absent 15%, sparse 21%, minimal 17%,
    ///   electricBuddhaGroove 27%, electricBuddhaPulse 10%, electricBuddhaRestrained 10%
    /// Below 100 BPM: Electric Buddha patterns redistributed to absent/sparse/restrained.
    static func pickPercussionStyle(tempo: Int, rng: inout SeededRNG) -> PercussionStyle {
        if tempo >= 100 {
            let styles:  [PercussionStyle] = [.absent, .sparse, .minimal, .motorikGrid, .electricBuddhaPulse, .electricBuddhaRestrained]
            let weights: [Double]          = [0.15,    0.21,    0.17,     0.27,          0.10,                  0.10]
            return styles[rng.weightedPick(weights)]
        } else {
            // Very slow tempo: heavier toward absent/sparse, restrained suits slow tempos well
            let styles:  [PercussionStyle] = [.absent, .sparse, .minimal, .electricBuddhaRestrained]
            let weights: [Double]          = [0.38,    0.27,    0.20,     0.15]
            return styles[rng.weightedPick(weights)]
        }
    }

    /// Song length: triangular min=225s (3:45), peak=250s, max=270s (4:30) — slightly longer than Motorik
    private static func pickTotalBars(tempo: Int, rng: inout SeededRNG) -> Int {
        let minS: Double  = 225.0
        let peakS: Double = 250.0
        let maxS: Double  = 270.0
        let r = rng.nextDouble()
        let fc = (peakS - minS) / (maxS - minS)
        let secs: Double
        if r < fc {
            secs = minS + Foundation.sqrt(r * (maxS - minS) * (peakS - minS))
        } else {
            secs = maxS - Foundation.sqrt((1 - r) * (maxS - minS) * (maxS - peakS))
        }
        let secondsPerBar = 60.0 / Double(tempo) * 4.0
        let rawBars = Int((secs / secondsPerBar).rounded())
        return Swift.max(8, (rawBars / 4) * 4)
    }
}

// MARK: - Automatic filter sweeps

/// Which steps of a Kosmic song fire an automatic global filter sweep (the same sweep a tap on
/// empty canvas triggers). 40% of regular Kosmic songs get 1-3 of them; Kosmic Drift gets none, and
/// Kosmic Space only the two in its sequencer solo bridge.
///
/// The schedule is derived from the seed and the section structure with its own SeededRNG, so it
/// consumes nothing from the generator's stream and never changes a note. The same seed always
/// gives the same sweeps, including after a reload from history or a .zudio file, so nothing is
/// stored in SongState.
///
/// The sweep closes the filter over 3 seconds and then snaps it open, so each one starts
/// tempo/5 steps before its boundary and the reopening lands on the boundary itself.
enum KosmicAutoSweep {
    static let songChance = 0.40
    static let minSpacingBars = 32
    /// Keeps sweeps off the intro and clear of the outro. The outro gap is also wider than the
    /// 12-bar Evolve look-ahead, so the schedule is identical in the original and extended state.
    static let introGuardBars = 8
    static let outroGuardBars = 16

    static func steps(for song: SongState) -> [Int] {
        guard song.style == .kosmic, !song.isKosmicDrift else { return [] }
        // Kosmic Space has its own sweeps on Texture (KOS-TEXT-005); the two would stack. The one
        // exception is the sequencer solo, where only the sequencer and perhaps the pads play.
        if song.isKosmicSpace { return spaceSoloSteps(song) }
        var rng = SeededRNG(seed: song.globalSeed ^ 0x5EE9_F11A_7E50_C0DE)
        guard rng.nextDouble() < songChance else { return [] }
        let wanted = 1 + Int(rng.next() % 3)

        let structure = song.structure
        let outroStart = structure.outroSection?.startBar ?? song.frame.totalBars
        let first = (structure.introSection?.endBar ?? 0) + introGuardBars
        let last = outroStart - outroGuardBars
        guard last > first else { return [] }

        // Section changes first (B, bridges, the A that follows them), then the 16-bar grid.
        var boundaries: [Int] = []
        var previous: SectionLabel? = nil
        for s in structure.sections {
            let isChange = s.label == .B || s.label.isBridge || s.label == .postRamp
                || (s.label == .A && previous != nil && previous != .intro)
            if isChange { boundaries.append(s.startBar) }
            previous = s.label
        }
        let grid = Array(stride(from: 16, to: outroStart, by: 16))
        var pool = shuffled(boundaries.filter { $0 >= first && $0 <= last }, rng: &rng)
        pool += shuffled(grid.filter { $0 >= first && $0 <= last && !boundaries.contains($0) }, rng: &rng)

        var chosen: [Int] = []
        for bar in pool where chosen.count < wanted {
            if chosen.allSatisfy({ abs($0 - bar) >= minSpacingBars }) { chosen.append(bar) }
        }
        let lead = Swift.max(1, song.frame.tempo / 5)
        return chosen.sorted().map { Swift.max(0, $0 * 16 - lead) }
    }

    /// The Rendez-Vous sequencer solo (`SpaceBridge`): two sweeps over the lone sequencer, the
    /// filter reopening on the solo's fifth bar and again on the downbeat where the band returns.
    private static func spaceSoloSteps(_ song: SongState) -> [Int] {
        guard let bridge = SpaceBridge.make(sections: song.structure.sections, seed: song.globalSeed),
              bridge.kind == .sequencerSolo else { return [] }
        let lead = Swift.max(1, song.frame.tempo / 5)
        return [bridge.range.lowerBound + 4, bridge.range.upperBound].map { Swift.max(0, $0 * 16 - lead) }
    }

    private static func shuffled(_ a: [Int], rng: inout SeededRNG) -> [Int] {
        var out = a
        guard out.count > 1 else { return out }
        for i in stride(from: out.count - 1, to: 0, by: -1) {
            out.swapAt(i, Int(rng.next() % UInt64(i + 1)))
        }
        return out
    }
}
