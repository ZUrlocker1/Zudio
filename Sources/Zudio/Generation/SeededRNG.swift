// SeededRNG.swift — SplitMix64 deterministic PRNG
// Copyright (c) 2026 Zack Urlocker
// Same seed + same controls => same output. Do not substitute arc4random or SystemRandomNumberGenerator.

import Foundation

struct SeededRNG: Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }

    /// Returns a Double in [0, 1).
    mutating func nextDouble() -> Double {
        Double(next()) / Double(UInt64.max)
    }

    /// Returns an Int in [0, upperBound).
    mutating func nextInt(upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }

    /// Picks an index from a weighted probability array (values must sum to 1.0).
    mutating func weightedPick(_ weights: [Double]) -> Int {
        var r = nextDouble()
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return i }
        }
        return weights.count - 1
    }
}

// MARK: - Track sub-seed derivation (spec §Randomization guardrails)

extension SeededRNG {
    /// Derives the sub-seed for a track from the global seed.
    /// Formula: trackSeed = splitmix64(globalSeed XOR (trackIndex * 0x9e3779b97f4a7c15))
    static func trackSeed(globalSeed: UInt64, trackIndex: Int) -> UInt64 {
        let mixed = globalSeed ^ (UInt64(trackIndex) &* 0x9e3779b97f4a7c15)
        var rng = SeededRNG(seed: mixed)
        return rng.next()
    }

    /// Returns the effective seed for a track, respecting per-track overrides.
    static func effectiveSeed(songState: SongState, trackIndex: Int) -> UInt64 {
        if let override = songState.trackOverrides[trackIndex] { return override }
        return trackSeed(globalSeed: songState.globalSeed, trackIndex: trackIndex)
    }
}

// MARK: - Triangular draw

extension SeededRNG {
    /// A value from a triangular distribution over `lo ... hi` with its mode at `peak`. One
    /// `nextDouble()` per call. This was the same six-line inverse-CDF block in eleven places across
    /// the frame generators; the arithmetic is unchanged, so every seed draws what it drew before.
    mutating func triangular(min lo: Double, peak: Double, max hi: Double) -> Double {
        let r  = nextDouble()
        let fc = (peak - lo) / (hi - lo)
        return r < fc
            ? lo + Foundation.sqrt(r * (hi - lo) * (peak - lo))
            : hi - Foundation.sqrt((1 - r) * (hi - lo) * (hi - peak))
    }
}

// MARK: - Velocity

extension SeededRNG {
    /// A MIDI velocity in `lo ..< lo + span`.
    ///
    /// This existed as an identical five-word local `func v(_:_:)` in nine places across the
    /// Chill bass and drum generators, plus a tenth variant in the Soho texture generator that
    /// took the RNG explicitly (2026-10-14). The body is unchanged, so the numbers a given seed
    /// produces are unchanged.
    mutating func velocity(_ lo: Int, _ span: Int) -> UInt8 {
        UInt8(lo + nextInt(upperBound: span))
    }
}
