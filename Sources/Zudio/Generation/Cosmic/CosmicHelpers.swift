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

// A Space chord can hold a note outside the song's scale: the major V of the Magnetic Fields minor
// families carries the leading tone. Under that chord the scale swaps each such note in for the
// scale note a semitone below it, or above when that one is a chord tone, so A Aeolian over an
// E major chord reads as A harmonic minor. Returns the swaps, old pitch class to new; empty for
// a chord inside the scale, which every Oxygene chord is.
func spaceChordAlterations(chordTones: Set<Int>, scalePCs: Set<Int>) -> [Int: Int] {
    var swaps: [Int: Int] = [:]
    for t in chordTones.sorted() where !scalePCs.contains(t) {
        let below = (t + 11) % 12, above = (t + 1) % 12
        if scalePCs.contains(below) && !chordTones.contains(below) { swaps[below] = t }
        else if scalePCs.contains(above) && !chordTones.contains(above) { swaps[above] = t }
    }
    return swaps
}

// The song's scale under one Space chord: `spaceChordAlterations` applied.
func spaceChordScale(chordTones: Set<Int>, frame: GlobalMusicalFrame) -> Set<Int> {
    let swaps = spaceChordAlterations(chordTones: chordTones, scalePCs: frame.scalePCs)
    return frame.scalePCs.subtracting(swaps.keys).union(swaps.values)
}

// Every Space rule snaps its notes to the song's scale as it writes them. This moves only the
// notes the chord under them has swapped out (the minor 3rd over a major V becomes the major 3rd)
// and leaves every other note alone, so it never moves a note twice. Run once per pitched track,
// after generation and after a regen.
// KOS-PADS-009 plays each pad attack one 16th early. The Space pads track is therefore fitted
// by the chord one step ahead: no other Space pad rule attacks on step 15, so this changes nothing
// for them.
let spacePadsAnticipation = 1

func fitSpaceChordScale(_ events: [MIDIEvent], structure: SongStructure,
                        frame: GlobalMusicalFrame, lookAheadSteps: Int = 0) -> [MIDIEvent] {
    events.map { ev in
        guard let cw = structure.chordWindow(atBar: (ev.stepIndex + lookAheadSteps) / 16),
              let to = spaceChordAlterations(chordTones: cw.chordTones,
                                             scalePCs: frame.scalePCs)[Int(ev.note) % 12]
        else { return ev }
        var d = to - Int(ev.note) % 12
        if d > 6 { d -= 12 } else if d < -6 { d += 12 }
        return MIDIEvent(stepIndex: ev.stepIndex, note: UInt8(Int(ev.note) + d),
                         velocity: ev.velocity, durationSteps: ev.durationSteps)
    }
}

// The Space sequencer register: the chord root in MIDI 48–59, as the Oxygene 4 sequencer plays it.
func spaceSequencerRoot(_ entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> Int {
    clampToRegister(spaceChordRootPC(entry, frame: frame) + 48, low: 48, high: 59)
}

// Remove the notes that start inside any of the bar ranges, and cut short the ones that would
// sound into them, so a part falls silent cleanly for a break.
func silenceBars(_ events: [MIDIEvent], _ ranges: [Range<Int>]) -> [MIDIEvent] {
    guard !ranges.isEmpty else { return events }
    let starts = ranges.map { $0.lowerBound * 16 }
    return events.compactMap { ev in
        let start = ev.stepIndex
        if ranges.contains(where: { $0.contains(start / 16) }) { return nil }
        let end = start + ev.durationSteps
        guard let cut = starts.filter({ $0 > start && $0 < end }).min()
        else { return ev }
        return MIDIEvent(stepIndex: start, note: ev.note, velocity: ev.velocity, durationSteps: cut - start)
    }
}
