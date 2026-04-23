// CosmicHelpers.swift — Shared pitch and velocity utilities for Kosmic generators.
// Copyright (c) 2026 Zack Urlocker
// These free functions are visible to all Kosmic generator structs in the module.

// Clamp a MIDI note number to a target register by transposing up or down in octaves.
// e.g. clampToRegister(36 + rootPC, low: 40, high: 55)
func clampToRegister(_ midi: Int, low: Int, high: Int) -> Int {
    var m = midi
    while m < low  { m += 12 }
    while m > high { m -= 12 }
    return m
}

// Snap a raw pitch class to the nearest in-scale pitch class.
// Searches outward ±1…6 semitones; returns the raw PC unchanged if no scale PC found.
func snapToScale(_ rawPC: Int, scalePCs: Set<Int>) -> Int {
    let pc = (rawPC % 12 + 12) % 12
    if scalePCs.contains(pc) { return pc }
    for d in 1...6 {
        if scalePCs.contains((pc + d) % 12) { return (pc + d) % 12 }
        if scalePCs.contains((pc - d + 12) % 12) { return (pc - d + 12) % 12 }
    }
    return pc
}

// Apply random velocity jitter centred on `base`. `range` is the full spread (default 8).
// Result is clamped to 20…127.
func jitteredVelocity(_ base: Int, range: Int = 8, rng: inout SeededRNG) -> UInt8 {
    UInt8(max(20, min(127, base + rng.nextInt(upperBound: range) - range / 2)))
}
