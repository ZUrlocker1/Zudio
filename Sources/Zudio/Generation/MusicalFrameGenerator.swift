// MusicalFrameGenerator.swift — generation step 1
// Produces a GlobalMusicalFrame. Key/tempo come from UI overrides when set.

import Foundation

struct MusicalFrameGenerator {
    static func generate(
        rng: inout SeededRNG,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil
    ) -> GlobalMusicalFrame {
        let key    = keyOverride   ?? pickKey(rng: &rng)
        let tempo  = tempoOverride ?? pickTempo(rng: &rng)
        let mood   = moodOverride  ?? pickMood(rng: &rng)
        let mode   = modeForMood(mood, rng: &rng)
        let family = pickProgressionFamily(rng: &rng)
        let total  = pickTotalBars(tempo: tempo, rng: &rng)

        return GlobalMusicalFrame(
            key: key,
            mode: mode,
            tempo: tempo,
            mood: mood,
            progressionFamily: family,
            totalBars: total
        )
    }

    // MARK: - Private helpers

    /// Motorik key-center probability table (spec §Key selector):
    /// E 30%, A 20%, D 15%, G 10%, C 10%, B 8%, F# 7%.
    private static func pickKey(rng: inout SeededRNG) -> String {
        let keys:    [String] = ["E",  "A",  "D",  "G",  "C",  "B",  "F#"]
        let weights: [Double] = [0.30, 0.20, 0.15, 0.10, 0.10, 0.08, 0.07]
        return keys[rng.weightedPick(weights)]
    }

    /// Motorik tempo: triangular distribution min=126, peak=138, max=154 BPM (spec §Tempo selector).
    private static func pickTempo(rng: inout SeededRNG) -> Int {
        let minT: Double = 126, peakT: Double = 138, maxT: Double = 154
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
        // Motorik mood weights
        let weights: [Double] = [0.35, 0.30, 0.20, 0.15]
        let moods: [Mood] = [.Dream, .Deep, .Bright, .Free]
        return moods[rng.weightedPick(weights)]
    }

    private static func modeForMood(_ mood: Mood, rng: inout SeededRNG) -> Mode {
        // Mood→mode mapping
        switch mood {
        case .Dream:  return rng.nextDouble() < 0.7  ? .Dorian     : .Aeolian
        case .Deep:   return rng.nextDouble() < 0.6  ? .Aeolian    : .Dorian
        case .Bright: return rng.nextDouble() < 0.5  ? .Dorian     : .Mixolydian
        case .Free:   return rng.nextDouble() < 0.5  ? .Ionian     : .Mixolydian
        }
    }

    /// Motorik harmonic palette — two-chord and minor-loop patterns dominate the corpus.
    /// static_tonic (Cluster-style drone), two_chord_I_bVII (classic Neu!/Harmonia),
    /// minor_loop patterns (modal Motorik), modal_cadence (rarer, more dramatic).
    private static func pickProgressionFamily(rng: inout SeededRNG) -> ProgressionFamily {
        let families: [ProgressionFamily] = [
            .static_tonic, .two_chord_I_bVII, .minor_loop_i_VII,
            .minor_loop_i_VI, .modal_cadence_bVI_bVII_I
        ]
        let weights: [Double] = [0.20, 0.30, 0.25, 0.15, 0.10]
        return families[rng.weightedPick(weights)]
    }

    /// Triangular distribution: min=210s, peak=285s, max=390s (spec §totalBars).
    private static func pickTotalBars(tempo: Int, rng: inout SeededRNG) -> Int {
        let minS: Double = 210, peakS: Double = 285, maxS: Double = 390
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
        // Round to nearest multiple of 4
        return Swift.max(8, (rawBars / 4) * 4)
    }
}
