// ChillMusicalFrameGenerator.swift — Chill generation step 1
// Produces a GlobalMusicalFrame tuned for nu-jazz / acid jazz / chill-out style.
// Tempo: Deep/Dream 72–92 BPM (peak 83), Bright/Free 88–110 BPM (peak 96).
// Four moods: Deep 35%, Dream 30%, Free 20%, Bright 15%.
// Four modes: Dorian 40%, Aeolian 25%, Mixolydian 20%, Ionian 15%.

import Foundation

struct ChillMusicalFrameGenerator {

    static func generate(
        rng: inout SeededRNG,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        testMode: Bool = false,
        forceBeatStyle: ChillBeatStyle? = nil
    ) -> (frame: GlobalMusicalFrame,
          chillProgFamily: ChillProgressionFamily,
          chillLeadInstrument: ChillLeadInstrument,
          chillBeatStyle: ChillBeatStyle,
          chillSwingFeel: Bool) {

        let mood   = moodOverride ?? pickMood(rng: &rng)
        let key    = keyOverride  ?? pickKey(rng: &rng)
        let mode   = pickMode(rng: &rng)

        let progFamily   = pickProgressionFamily(rng: &rng)
        let leadInst     = pickLeadInstrument(mood: mood, rng: &rng)
        // forceBeatStyle overrides generation (used by best-first-song and test mode)
        let beatStyle    = forceBeatStyle ?? (testMode ? ChillBeatStyle.stGermain : pickBeatStyle(mood: mood, rng: &rng))
        let swingFeel    = false  // swing not yet implemented (requires sub-step timing)

        // Tempo picked after beat style so stGermain can bias toward its faster range
        let tempo  = tempoOverride ?? pickTempo(mood: mood, rng: &rng, beatStyle: beatStyle)
        let total  = pickTotalBars(tempo: tempo, rng: &rng, testMode: testMode)

        let frame = GlobalMusicalFrame(
            key: key, mode: mode, tempo: tempo, mood: mood,
            progressionFamily: .static_tonic, totalBars: total
        )
        return (frame, progFamily, leadInst, beatStyle, swingFeel)
    }

    // MARK: - Private helpers

    private static func pickMood(rng: inout SeededRNG) -> Mood {
        // Deep 35%, Dream 30%, Free 20%, Bright 15%
        let moods:   [Mood]   = [.Deep, .Dream, .Free, .Bright]
        let weights: [Double] = [0.35,  0.30,   0.20,  0.15]
        return moods[rng.weightedPick(weights)]
    }

    private static func pickKey(rng: inout SeededRNG) -> String {
        // Jazz-friendly keys slightly boosted; D and G top the list
        let keys:    [String] = ["D",  "G",  "C",  "F",  "A",  "Bb", "Eb", "Ab", "E",  "B",  "F#", "C#"]
        let weights: [Double] = [0.15, 0.12, 0.12, 0.10, 0.10, 0.08, 0.07, 0.06, 0.06, 0.05, 0.05, 0.04]
        return keys[rng.weightedPick(weights)]
    }

    private static func pickTempo(mood: Mood, rng: inout SeededRNG, beatStyle: ChillBeatStyle? = nil) -> Int {
        // St Germain four-on-the-floor groove needs the higher end of the tempo range to drive
        if beatStyle == .stGermain {
            return triangularInt(min: 108, peak: 116, max: 124, rng: &rng)
        }
        switch mood {
        case .Deep, .Dream:
            // 72–92 BPM triangular (peak 83) — trip-hop / Moby range
            return triangularInt(min: 72, peak: 83, max: 92, rng: &rng)
        case .Free, .Bright:
            // 88–110 BPM triangular (peak 96) — nu-jazz / St Germain range
            return triangularInt(min: 88, peak: 96, max: 110, rng: &rng)
        }
    }

    private static func pickMode(rng: inout SeededRNG) -> Mode {
        // Dorian 40%, Aeolian 25%, Mixolydian 20%, Ionian 15%
        let modes:   [Mode]   = [.Dorian, .Aeolian, .Mixolydian, .Ionian]
        let weights: [Double] = [0.40,    0.25,     0.20,        0.15]
        return modes[rng.weightedPick(weights)]
    }

    private static func pickTotalBars(tempo: Int, rng: inout SeededRNG, testMode: Bool) -> Int {
        let minS: Double  = testMode ?  60.0 : 180.0
        let peakS: Double = testMode ?  90.0 : 240.0
        let maxS: Double  = testMode ? 120.0 : 315.0
        let secs = Double(triangularInt(min: Int(minS), peak: Int(peakS), max: Int(maxS), rng: &rng))
        let secondsPerBar = 60.0 / Double(tempo) * 4.0
        let rawBars = Int((secs / secondsPerBar).rounded())
        return Swift.max(68, Swift.min(116, (rawBars / 4) * 4))
    }

    private static func pickProgressionFamily(rng: inout SeededRNG) -> ChillProgressionFamily {
        // static_groove 35%, two_chord_pendulum 30%, minor_blues 20%, modal_drift 15%
        let families: [ChillProgressionFamily] = [.static_groove, .two_chord_pendulum, .minor_blues, .modal_drift]
        let weights:  [Double]                 = [0.35,           0.30,                0.20,          0.15]
        return families[rng.weightedPick(weights)]
    }

    private static func pickLeadInstrument(mood: Mood, rng: inout SeededRNG) -> ChillLeadInstrument {
        // Muted trumpet is the signature Chill lead voice — heavily preferred across all moods.
        // Soprano Sax moved to Lead 2 pool; Alto Sax (.saxophone) replaces it in Lead 1.
        // Vibraphone is Lead 2 only.
        switch mood {
        case .Deep, .Dream:
            // Muted Trumpet 55%, Alto Sax 25%, Trumpet 20%
            let insts:   [ChillLeadInstrument] = [.mutedTrumpet, .saxophone, .trumpet]
            let weights: [Double]              = [0.55,          0.25,       0.20]
            return insts[rng.weightedPick(weights)]
        case .Free, .Bright:
            // Muted Trumpet 40%, Trumpet 30%, Flute 15%, Alto Sax 15%
            let insts:   [ChillLeadInstrument] = [.mutedTrumpet, .trumpet, .flute, .saxophone]
            let weights: [Double]              = [0.40,          0.30,     0.15,   0.15]
            return insts[rng.weightedPick(weights)]
        }
    }

    private static func pickBeatStyle(mood: Mood, rng: inout SeededRNG) -> ChillBeatStyle {
        switch mood {
        case .Deep:
            // Electronic 45%, brushKit 35%, hipHopJazz 20%
            let r = rng.nextDouble()
            if r < 0.45 { return .electronic }
            if r < 0.80 { return .brushKit }
            return .hipHopJazz
        case .Dream:
            // brushKit 35%, electronic 30%, hipHopJazz 20%, neoSoul 15%
            let r = rng.nextDouble()
            if r < 0.35 { return .brushKit }
            if r < 0.65 { return .electronic }
            if r < 0.85 { return .hipHopJazz }
            return .neoSoul
        case .Free:
            // brushKit 35%, neoSoul 30%, hipHopJazz 20%, stGermain 15%
            let r = rng.nextDouble()
            if r < 0.35 { return .brushKit }
            if r < 0.65 { return .neoSoul }
            if r < 0.85 { return .hipHopJazz }
            return .stGermain
        case .Bright:
            // brushKit 30%, stGermain 30%, hipHopJazz 25%, neoSoul 15%
            let r = rng.nextDouble()
            if r < 0.30 { return .brushKit }
            if r < 0.60 { return .stGermain }
            if r < 0.85 { return .hipHopJazz }
            return .neoSoul
        }
    }

    // MARK: - Triangular distribution

    static func triangularInt(min: Int, peak: Int, max: Int, rng: inout SeededRNG) -> Int {
        let minD = Double(min), peakD = Double(peak), maxD = Double(max)
        let r  = rng.nextDouble()
        let fc = (peakD - minD) / (maxD - minD)
        let raw: Double
        if r < fc {
            raw = minD + Foundation.sqrt(r * (maxD - minD) * (peakD - minD))
        } else {
            raw = maxD - Foundation.sqrt((1 - r) * (maxD - minD) * (maxD - peakD))
        }
        return Swift.max(min, Swift.min(max, Int(raw.rounded())))
    }
}
