// AmbientHelpers.swift — Shared utilities for Ambient generators.
// Copyright (c) 2026 Zack Urlocker

/// Returns all MIDI notes in [low…high] whose pitch class is in `pitchClasses`.
func notesInRegister(pitchClasses: Set<Int>, low: Int, high: Int) -> [UInt8] {
    guard low <= high else { return [] }
    return (low...high).compactMap { n in pitchClasses.contains(n % 12) ? UInt8(n) : nil }
}

/// Picks `windowCount` non-overlapping `soloLength`-bar windows from body sections of `structure`.
/// Enforces `minGap` bars between windows; gap is reduced gracefully if the body is too short.
/// Windows are biased toward the first half of available starts so they spread across the song.
func pickSoloWindows(
    structure: SongStructure,
    soloLength: Int,
    windowCount: Int,
    minGap: Int,
    rng: inout SeededRNG
) -> [Range<Int>] {
    var bodyBarSet = Set<Int>()
    for section in structure.sections {
        guard section.label != .intro && section.label != .outro else { continue }
        guard !section.label.isBridge && section.label != .bridgeMelody else { continue }
        for b in section.startBar..<section.endBar { bodyBarSet.insert(b) }
    }
    let validStarts = bodyBarSet.sorted().filter { start in
        (start..<(start + soloLength)).allSatisfy { bodyBarSet.contains($0) }
    }
    guard !validStarts.isEmpty else { return [] }

    // Reduce gap gracefully if the body is too short for the requested minGap.
    let minNeeded    = soloLength * windowCount + minGap * (windowCount - 1)
    let effectiveGap = bodyBarSet.count >= minNeeded
        ? minGap
        : Swift.max(4, (bodyBarSet.count - soloLength * windowCount) / Swift.max(1, windowCount - 1))

    var windows: [Range<Int>] = []
    var earliestNext = validStarts[0]
    for _ in 0..<windowCount {
        let available = validStarts.filter { $0 >= earliestNext }
        guard !available.isEmpty else { break }
        let pickFrom    = Swift.max(1, available.count / 2)
        let chosenStart = available[rng.nextInt(upperBound: pickFrom)]
        windows.append(chosenStart..<(chosenStart + soloLength))
        earliestNext = chosenStart + soloLength + effectiveGap
    }
    return windows
}
