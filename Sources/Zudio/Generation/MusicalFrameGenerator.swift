// MusicalFrameGenerator.swift — generation step 1
// Copyright (c) 2026 Zack Urlocker
// Produces a GlobalMusicalFrame. Key/tempo come from UI overrides when set.

import Foundation

struct MusicalFrameGenerator {
    static func generate(
        rng: inout SeededRNG,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        motorikNoir: Bool = false
    ) -> GlobalMusicalFrame {
        let key    = keyOverride   ?? pickKey(rng: &rng)
        var tempo  = tempoOverride ?? (motorikNoir ? pickTempoNoir(rng: &rng) : pickTempo(rng: &rng))
        let mood   = moodOverride  ?? pickMood(rng: &rng)
        let mode   = motorikNoir   ? pickModeNoir(rng: &rng) : modeForMood(mood, rng: &rng)
        let family = motorikNoir   ? pickProgressionFamilyNoir(rng: &rng) : pickProgressionFamily(rng: &rng)
        let total  = pickTotalBars(tempo: tempo, rng: &rng, noir: motorikNoir)

        if motorikNoir { tempo = Swift.max(110, Swift.min(tempo, 140)) }
        else           { tempo = Swift.max(126, Swift.min(tempo, 154)) }

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

    /// Motorik Noir tempo: 110–140 BPM, peak 130. Allows Joy Division-pace urgency.
    private static func pickTempoNoir(rng: inout SeededRNG) -> Int {
        let minT: Double = 110, peakT: Double = 130, maxT: Double = 140
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

    /// Motorik Noir mode: dark minor palette — Aeolian/Dorian/Phrygian/HarmonicMinor.
    private static func pickModeNoir(rng: inout SeededRNG) -> Mode {
        let modes:   [Mode]   = [.Aeolian, .Dorian, .Phrygian, .HarmonicMinor]
        let weights: [Double] = [0.40,     0.20,    0.20,      0.20]
        return modes[rng.weightedPick(weights)]
    }

    /// Motorik Noir progression: weighted toward minor loops and modal cadences — no bright patterns.
    private static func pickProgressionFamilyNoir(rng: inout SeededRNG) -> ProgressionFamily {
        let families: [ProgressionFamily] = [
            .minor_loop_i_VII, .minor_loop_i_VI, .modal_cadence_bVI_bVII_I, .static_tonic
        ]
        let weights: [Double] = [0.32, 0.26, 0.22, 0.20]
        return families[rng.weightedPick(weights)]
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
        // Dream=20%, Deep=20%, Bright=30%, Free=30% — major/mixed lean, more open/free than dreamy
        let weights: [Double] = [0.20, 0.20, 0.30, 0.30]
        let moods: [Mood] = [.Dream, .Deep, .Bright, .Free]
        return moods[rng.weightedPick(weights)]
    }

    private static func modeForMood(_ mood: Mood, rng: inout SeededRNG) -> Mode {
        switch mood {
        case .Dream:
            return rng.nextDouble() < 0.7  ? .Dorian     : .Aeolian
        case .Deep:
            return rng.nextDouble() < 0.6  ? .Aeolian    : .Dorian
        case .Bright:
            // 3-way: 40% Mixolydian, 30% Lydian, 30% Dorian
            let r = rng.nextDouble()
            return r < 0.40 ? .Mixolydian : r < 0.70 ? .Lydian : .Dorian
        case .Free:
            // 3-way: 35% Ionian, 35% Mixolydian, 30% Lydian
            let r = rng.nextDouble()
            return r < 0.35 ? .Ionian : r < 0.70 ? .Mixolydian : .Lydian
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

    /// Triangular distribution. Noir uses tighter 150–220s arc (tension-arc structure).
    private static func pickTotalBars(tempo: Int, rng: inout SeededRNG, noir: Bool = false) -> Int {
        let minS: Double  = 150.0
        let peakS: Double = noir ? 190.0 : 210.0
        let maxS: Double  = noir ? 220.0 : 270.0
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
