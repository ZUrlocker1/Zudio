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

// MARK: - Kosmic Space

// Move a MIDI note to the nearest in-scale pitch, keeping its octave as far as possible.
func snapMidiToScale(_ midi: Int, scalePCs: Set<Int>) -> Int {
    let pc = (midi % 12 + 12) % 12
    var d = snapToScale(pc, scalePCs: scalePCs) - pc
    if d > 6 { d -= 12 } else if d < -6 { d += 12 }
    return midi + d
}

// The note `steps` scale tones above `midi` (below when negative), after snapping `midi` to the
// scale. Kosmic Space measures its figures as chord tones above the root — 3rd = 2 steps,
// 5th = 4, 6th = 5, octave = 7, 9th = 8 — so every transposed figure stays in the song's scale.
func scaleStep(_ midi: Int, by steps: Int, scalePCs: Set<Int>) -> Int {
    var m = snapMidiToScale(midi, scalePCs: scalePCs)
    guard !scalePCs.isEmpty else { return m }
    let dir = steps >= 0 ? 1 : -1
    var remaining = abs(steps)
    while remaining > 0 {
        m += dir
        if scalePCs.contains((m % 12 + 12) % 12) { remaining -= 1 }
    }
    return m
}

// Pitch class of the current chord's root, snapped to the song's scale.
func spaceChordRootPC(_ entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> Int {
    snapToScale((keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12,
                scalePCs: frame.scalePCs)
}

// Per-song draws of the Kosmic Space rules, keyed by rule ID, for the generation log — so a
// song's character can be read from it, e.g. "Oxygene See-Saw Riff (sixth, 2+2+2, second half)".
// A reference box so the generators can take it as an optional parameter with a nil default.
final class KosmicSpaceDraws {
    private(set) var notes: [String: String] = [:]
    func record(_ ruleID: String, _ draws: String) { notes[ruleID] = draws }
}

// Remove the notes that start inside any of the bar ranges, and cut short the ones that would
// sound into them, so a part falls silent cleanly for a break.
func silenceBars(_ events: [MIDIEvent], _ ranges: [Range<Int>]) -> [MIDIEvent] {
    guard !ranges.isEmpty else { return events }
    return events.compactMap { ev in
        let start = ev.stepIndex
        if ranges.contains(where: { $0.contains(start / 16) }) { return nil }
        let end = start + ev.durationSteps
        guard let cut = ranges.map({ $0.lowerBound * 16 }).filter({ $0 > start && $0 < end }).min()
        else { return ev }
        return MIDIEvent(stepIndex: start, note: ev.note, velocity: ev.velocity, durationSteps: cut - start)
    }
}
