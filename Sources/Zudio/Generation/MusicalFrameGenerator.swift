// MusicalFrameGenerator.swift — generation step 1
// Produces a GlobalMusicalFrame. Key/tempo come from UI overrides when set.

struct MusicalFrameGenerator {
    static func generate(
        rng: inout SeededRNG,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil
    ) -> GlobalMusicalFrame {
        let key    = keyOverride  ?? pickKey(rng: &rng)
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

    private static func pickKey(rng: inout SeededRNG) -> String {
        kAllKeys[rng.nextInt(upperBound: kAllKeys.count)]
    }

    /// Motorik tempo range 80–140 BPM with probability peak around 115 BPM.
    /// Full app range: 20–200 BPM (per UI spec).
    private static func pickTempo(rng: inout SeededRNG) -> Int {
        // Triangular distribution: min=80, peak=115, max=140 for Motorik
        let r = rng.nextDouble()
        let min: Double = 80, peak: Double = 115, max: Double = 140
        let fc = (peak - min) / (max - min)
        let raw: Double
        if r < fc {
            raw = min + (max - min) * fc * r / fc
        } else {
            raw = max - (max - min) * (1 - fc) * (1 - r) / (1 - fc)
        }
        return max(80, min(140, Int(raw.rounded())))
    }

    private static func pickMood(rng: inout SeededRNG) -> Mood {
        // Weights: Trance 35%, Melancholic 30%, Hypnotic 20%, Free 15%
        let weights: [Double] = [0.35, 0.30, 0.20, 0.15]
        let all = Mood.allCases
        return all[rng.weightedPick(weights)]
    }

    private static func modeForMood(_ mood: Mood, rng: inout SeededRNG) -> Mode {
        // Mood→mode mapping (spec §Mood-to-mode mapping)
        switch mood {
        case .trance:     return rng.nextDouble() < 0.7 ? .dorian : .aeolian
        case .melancholic: return rng.nextDouble() < 0.6 ? .aeolian : .phrygian
        case .hypnotic:   return rng.nextDouble() < 0.5 ? .dorian : .mixolydian
        case .free:       return rng.nextDouble() < 0.4 ? .lydian : .mixolydian
        }
    }

    private static func pickProgressionFamily(rng: inout SeededRNG) -> ProgressionFamily {
        let all = ProgressionFamily.allCases
        return all[rng.nextInt(upperBound: all.count)]
    }

    /// Triangular distribution: min=210s, peak=285s, max=390s (spec §totalBars)
    /// +20s bias for Moderate A/B (applied by StructureGenerator after form pick).
    private static func pickTotalBars(tempo: Int, rng: inout SeededRNG) -> Int {
        let min: Double = 210, peak: Double = 285, max: Double = 390
        let r = rng.nextDouble()
        let fc = (peak - min) / (max - min)
        let secs: Double
        if r < fc {
            secs = min + (max - min) * fc * r / fc
        } else {
            secs = max - (max - min) * (1 - fc) * (1 - r) / (1 - fc)
        }
        let secondsPerBar = 60.0 / Double(tempo) * 4.0
        let rawBars = Int((secs / secondsPerBar).rounded())
        // Round to nearest multiple of 4
        return max(8, (rawBars / 4) * 4)
    }
}
