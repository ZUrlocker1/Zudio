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

// MARK: - Ambient filter tide schedule

/// The automatic slow filter effects (a tide out or a tide in, three to one) of Ambient and Ambient Zen (not Ambient Piano): the Ambient
/// counterpart of `KosmicAutoSweep`. 35% of songs get 1 or 2 tides, at least 32 bars apart,
/// away from the intro and well clear of the outro. A tide runs 16 to 24 seconds, closing the
/// filters to 600 Hz, holding, and reopening (see `PlaybackEngine.triggerSlowFilterTide`).
///
/// The schedule comes from the seed with its own SeededRNG, so it consumes nothing from the
/// generator's stream and never changes a note. The same seed always gives the same tides,
/// including after a reload, so nothing is stored in SongState.
enum AmbientAutoTide {
    static let songChance = 0.35
    static let minSpacingBars = 32
    static let introGuardBars = 8
    static let outroGuardBars = 16
    /// Tides start on a bar of this grid, so they follow the song's own phrasing.
    static let gridBars = 8

    /// Which way a scheduled tide runs: out (slowly darkens, then back) or in (dark at once, then
    /// slowly brightens), three outs to one in. A pure function of the seed and the step, so the same song
    /// always plays the same tide at the same bar, and the schedule itself is unchanged.
    static func isTideIn(seed: UInt64, step: Int) -> Bool {
        var rng = SeededRNG(seed: seed ^ 0xD4A1_9E5C_0B77_31F3 ^ UInt64(truncatingIfNeeded: step) &* 0x9E37_79B9_7F4A_7C15)
        _ = rng.next()
        return rng.next() % 4 == 0
    }

    /// How long a scheduled tide runs, in seconds: 16 to 24, from its own draw of the seed and the
    /// step (a different salt from `isTideIn`, so length and direction are independent).
    static func tideSeconds(seed: UInt64, step: Int) -> Int {
        var rng = SeededRNG(seed: seed ^ 0x5B3C_A7E1_62D9_0F48 ^ UInt64(truncatingIfNeeded: step) &* 0x9E37_79B9_7F4A_7C15)
        _ = rng.next()
        return 16 + Int(rng.next() % 9)
    }

    static func steps(for song: SongState) -> [Int] {
        guard song.style == .ambient, !song.isAmbientPiano else { return [] }
        var rng = SeededRNG(seed: song.globalSeed ^ 0x71DE_F117_5EED_0A3B)
        guard rng.nextDouble() < songChance else { return [] }
        let wanted = 1 + Int(rng.next() % 2)

        let outroStart = song.structure.outroSection?.startBar ?? song.frame.totalBars
        let first = (song.structure.introSection?.endBar ?? 0) + introGuardBars
        let last = outroStart - outroGuardBars
        guard last > first else { return [] }

        var pool = Array(stride(from: 0, to: song.frame.totalBars, by: gridBars))
            .filter { $0 >= first && $0 <= last }
        if pool.count > 1 {
            for i in stride(from: pool.count - 1, to: 0, by: -1) {
                pool.swapAt(i, Int(rng.next() % UInt64(i + 1)))
            }
        }
        var chosen: [Int] = []
        for bar in pool where chosen.count < wanted {
            if chosen.allSatisfy({ abs($0 - bar) >= minSpacingBars }) { chosen.append(bar) }
        }
        return chosen.sorted().map { $0 * 16 }
    }
}
