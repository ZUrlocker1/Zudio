// AmbientMusicalFrameGenerator.swift — Ambient generation step 1
// Produces a GlobalMusicalFrame tuned for Eno/Loscil/Craven Faults style.
// Tempo: beatless 62–78 (60%), slowPulse 72–92 (35%), midPulse 95–110 (5%).
// Song length: triangular min=180s, peak=240s, max=315s/5:15 (test mode 60–120s).

import Foundation

struct AmbientMusicalFrameGenerator {

    static func generate(
        rng: inout SeededRNG,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        testMode: Bool = false
    ) -> (frame: GlobalMusicalFrame, percussionStyle: PercussionStyle,
          ambientProgFamily: AmbientProgressionFamily, loopLengths: AmbientLoopLengths) {

        let key        = keyOverride   ?? pickKey(rng: &rng)
        let tempo      = tempoOverride ?? pickTempo(rng: &rng)
        let mood       = moodOverride  ?? pickMood(rng: &rng)
        let mode       = pickMode(rng: &rng)
        let total      = pickTotalBars(tempo: tempo, rng: &rng, testMode: testMode)
        let percStyle  = pickPercussionStyle(rng: &rng)
        let ambFamily  = pickAmbientProgressionFamily(rng: &rng)
        let loops      = pickLoopLengths(rng: &rng)

        let frame = GlobalMusicalFrame(
            key: key, mode: mode, tempo: tempo, mood: mood,
            progressionFamily: .static_tonic, totalBars: total
        )
        return (frame, percStyle, ambFamily, loops)
    }

    // MARK: - Private helpers

    private static func pickKey(rng: inout SeededRNG) -> String {
        // D 15%, G 12%, C 12%, Ab 8%, F 7%, Eb 6%, A 10%, D 8%, E 7%, others 15%
        let keys:    [String] = ["D",  "G",  "C",  "Ab", "F",  "Eb", "A",  "E",  "B",  "F#", "Bb", "C#"]
        let weights: [Double] = [0.15, 0.12, 0.12, 0.08, 0.07, 0.06, 0.10, 0.07, 0.04, 0.06, 0.05, 0.08]
        return keys[rng.weightedPick(weights)]
    }

    private static func pickTempo(rng: inout SeededRNG) -> Int {
        let roll = rng.nextDouble()
        let (minT, peakT, maxT): (Double, Double, Double)
        if roll < 0.60 {
            (minT, peakT, maxT) = (62.0, 70.0, 78.0)    // beatless
        } else if roll < 0.95 {
            (minT, peakT, maxT) = (72.0, 82.0, 92.0)    // slowPulse
        } else {
            (minT, peakT, maxT) = (95.0, 103.0, 110.0)  // midPulse
        }
        return triangularInt(min: minT, peak: peakT, max: maxT, rng: &rng)
    }

    private static func pickMood(rng: inout SeededRNG) -> Mood {
        let moods:   [Mood]   = [.Dream, .Deep, .Free, .Bright]
        let weights: [Double] = [0.40,   0.35,  0.15,  0.10]
        return moods[rng.weightedPick(weights)]
    }

    private static func pickMode(rng: inout SeededRNG) -> Mode {
        let modes:   [Mode]   = [.Dorian, .Aeolian, .Mixolydian, .Ionian, .MinorPentatonic]
        let weights: [Double] = [0.35,    0.30,     0.15,        0.10,    0.10]
        return modes[rng.weightedPick(weights)]
    }

    static func pickPercussionStyle(rng: inout SeededRNG) -> PercussionStyle {
        let styles:  [PercussionStyle] = [.handPercussion, .textural, .absent, .softPulse]
        let weights: [Double]          = [0.45,            0.30,      0.20,    0.05]
        return styles[rng.weightedPick(weights)]
    }

    private static func pickAmbientProgressionFamily(rng: inout SeededRNG) -> AmbientProgressionFamily {
        let families: [AmbientProgressionFamily] = [.droneSingle, .droneTwo, .modalDrift, .suspendedDrone, .dissonantHaze]
        let weights:  [Double]                   = [0.30,         0.25,      0.20,        0.15,            0.10]
        return families[rng.weightedPick(weights)]
    }

    /// Co-prime loop length assignment from {5, 7, 11, 13, 17, 19, 23}.
    /// Pads gets one of the largest (17/19/23), Rhythm one of the smallest (5/7), Bass = Pads.
    static func pickLoopLengths(rng: inout SeededRNG) -> AmbientLoopLengths {
        let primes = [5, 7, 11, 13, 17, 19, 23]
        let pads   = primes[4 + rng.nextInt(upperBound: 3)]  // 17, 19, or 23
        let rhythm = primes[rng.nextInt(upperBound: 2)]       // 5 or 7
        let bass   = pads                                      // AMB-RULE-18: bass shares pads prime
        // Shuffle remaining for lead1, lead2, texture
        var remaining = primes.filter { $0 != pads && $0 != rhythm }
        for i in stride(from: remaining.count - 1, through: 1, by: -1) {
            remaining.swapAt(i, rng.nextInt(upperBound: i + 1))
        }
        return AmbientLoopLengths(lead1: remaining[0], lead2: remaining[1],
                                   pads: pads, rhythm: rhythm, texture: remaining[2], bass: bass)
    }

    private static func pickTotalBars(tempo: Int, rng: inout SeededRNG, testMode: Bool) -> Int {
        let minS: Double  = testMode ? 60.0  : 180.0
        let peakS: Double = testMode ? 90.0  : 240.0
        let maxS: Double  = testMode ? 120.0 : 315.0   // hard cap 5:15
        let secs = Double(triangularInt(min: minS, peak: peakS, max: maxS, rng: &rng))
        let secondsPerBar = 60.0 / Double(tempo) * 4.0
        let maxBars = Int((315.0 / secondsPerBar).rounded())   // enforce 5:15 at any tempo
        let rawBars = Int((secs / secondsPerBar).rounded())
        return Swift.max(8, Swift.min(maxBars, (rawBars / 4) * 4))
    }

    private static func triangularInt(min: Double, peak: Double, max: Double, rng: inout SeededRNG) -> Int {
        let r  = rng.nextDouble()
        let fc = (peak - min) / (max - min)
        let raw: Double
        if r < fc {
            raw = min + Foundation.sqrt(r * (max - min) * (peak - min))
        } else {
            raw = max - Foundation.sqrt((1 - r) * (max - min) * (max - peak))
        }
        return Swift.max(Int(min), Swift.min(Int(max), Int(raw.rounded())))
    }
}
