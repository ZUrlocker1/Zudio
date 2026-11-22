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
    // O(n): scan sorted bars once, tracking run length to find windows that fit soloLength.
    let sortedBars = bodyBarSet.sorted()
    var validStarts: [Int] = []
    var runStart = 0
    for i in 0..<sortedBars.count {
        if i > 0 && sortedBars[i] != sortedBars[i - 1] + 1 { runStart = i }
        if i - runStart + 1 >= soloLength { validStarts.append(sortedBars[i - soloLength + 1]) }
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

/// The three Ambient forms' default effects per track, in one place. TrackRowView.applyDefaultEffects
/// (Mac and iPad) and AppState.restoreDefaultEffects (iPhone) both read it, so the two can't drift.
enum AmbientEffectDefaults {
    enum Form { case zen, piano, base }

    /// `lead2Locked`: Lead 2 doubles Lead 1 (a mirrored lead), so it takes Lead 1's delay too.
    /// `audioTexture`: an audio texture file is playing, where pan and sweep do nothing.
    static func defaults(track: Int, form: Form, lead2Locked: Bool, audioTexture: Bool) -> [TrackEffect] {
        if form == .zen {
            // Ambient Zen. Pads take their light echo and slow pan across the room with no chip of
            // their own, Lead 1 has Air, and the bass has a hidden low shelf (Zack, 2026-11-22).
            switch track {
            case kTrackLead1:   return [.delay, .space, .air]
            case kTrackLead2:   return [.delay, .space]
            case kTrackPads:    return [.space, .tremolo, .sweep, .delay, .pan]
            case kTrackRhythm:  return [.delay, .space, .pan]
            case kTrackTexture: return [.delay, .space]
            case kTrackBass:    return [.reverb, .tremolo, .lowShelf]
            default:            return []
            }
        }
        // Base Ambient and Ambient Piano: a gentle Air on Lead 1 (not Piano's) and Pads, and the
        // Pads' dark echo with no chip of its own (Zack, 2026-11-22).
        switch track {
        case kTrackLead1:   return form == .piano ? [.delay, .space] : [.delay, .space, .air]
        case kTrackLead2:   return lead2Locked ? [.delay, .space] : [.space]
        case kTrackPads:    return [.space, .sweep, .delay, .air]
        case kTrackRhythm:  return [.reverb]
        case kTrackTexture: return audioTexture ? [.space] : [.space, .pan, .sweep]
        case kTrackBass:    return [.reverb, .sweep]
        case kTrackDrums:   return [.delay]
        default:            return []
        }
    }
}
