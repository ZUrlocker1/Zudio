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
        // forceBeatStyle overrides generation (used by best-first-song)
        let beatStyle    = forceBeatStyle ?? pickBeatStyle(mood: mood, rng: &rng)
        let swingFeel    = false  // swing not yet implemented (requires sub-step timing)

        // Tempo picked after beat style so stGermain can bias toward its faster range
        let tempo  = tempoOverride ?? pickTempo(mood: mood, rng: &rng, beatStyle: beatStyle)
        let total  = pickTotalBars(tempo: tempo, rng: &rng)

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

    private static func pickTotalBars(tempo: Int, rng: inout SeededRNG) -> Int {
        let minS: Double  = 180.0
        let peakS: Double = 240.0
        let maxS: Double  = 315.0
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
        // Lead 1 pool: muted trumpet, tenor sax, alto sax, trumpet — ~30% muted trumpet across moods.
        // Soprano sax, vibraphone, trombone, flute are Lead 2 only.
        switch mood {
        case .Deep, .Dream:
            // Muted Trumpet 30%, Alto Sax 20%, Trumpet 25%, Tenor Sax 25%
            let insts:   [ChillLeadInstrument] = [.mutedTrumpet, .saxophone, .trumpet, .tenorSax]
            let weights: [Double]              = [0.30,          0.20,       0.25,     0.25]
            return insts[rng.weightedPick(weights)]
        case .Free, .Bright:
            // Muted Trumpet 30%, Trumpet 25%, Tenor Sax 35%, Alto Sax 10%
            let insts:   [ChillLeadInstrument] = [.mutedTrumpet, .trumpet, .tenorSax, .saxophone]
            let weights: [Double]              = [0.30,          0.25,     0.35,      0.10]
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
