// BeatFixup.swift — the "behind the beat" feel for Chill Soho Soul grooves and some Chill Blues.
//
// A playback-time offset, not a change to any note: the stored song, its seeds, its MIDI export
// and every rule are untouched. onStep fires the bass, and the backbeat voices of the drum
// track, a few milliseconds after their grid step, while everything else stays on the grid.
// The late backbeat against an on-time kick and hats is the Sade / Style Council pocket.
// See docs/chill-soho-plan.md (Behind-the-beat feel).

import Foundation

enum BeatFixup {
    /// Set 2026-10-18 after a 100 ms sanity check proved the delay audible: backbeat 20 ms
    /// (research puts a laid-back snare near 17 ms), bass half that so it stays locked to the kick.
    /// Soul only. Latin (bossa / samba) is clave-driven and bright; a late rim or bass there
    /// sounds sloppy, so its offsets are zero. Raise them here to audition it.
    static func offsets(for beatStyle: ChillBeatStyle) -> (bassMs: Int, backbeatMs: Int) {
        switch beatStyle {
        case .sohoSoul: return (bassMs: 10, backbeatMs: 20)
        default:        return (bassMs: 0, backbeatMs: 0)
        }
    }

    /// The drum notes that sit late: the backbeat voices only. Kick, hats, ride, shaker,
    /// tambourine, toms and crashes stay on the grid, so the lateness is heard against them.
    static let backbeatNotes: Set<UInt8> = [
        GMDrum.sidestick.rawValue,   // 37 — the Soul backbeat voice
        GMDrum.snare.rawValue,       // 38
        GMDrum.clap.rawValue,        // 39
        GMDrum.snare2.rawValue       // 40
    ]

    /// Chill Blues: a smaller offset than Soul, and only on the slow patient bass patterns, so the
    /// late side-stick sits against a bass that is late with it. Whole song, Groove B included.
    /// Added 2026-10-19. Not on CHL-BASS-012 Rumba (clave-driven, as Latin in Soho), CHL-BASS-011
    /// Ascending Riff (built to lean forward) or CHL-BASS-004 Air Ostinato (a steady locked loop).
    static let bluesOffsets: (bassMs: Int, backbeatMs: Int) = (bassMs: 6, backbeatMs: 15)
    static let bluesBassRules: Set<String> = [
        "CHL-BASS-009",   // Blues Pickup (B.B. King)
        "CHL-BASS-010",   // Quarter Pulse
        "CHL-BASS-001",   // Root Sustain
        "CHL-BASS-003"    // Walking
    ]

    /// The song's bass rule from a list of rule IDs. CHL-BASS-005 is the breakdown bass, not the
    /// song's pattern (same filter as ChillBassSlides).
    static func bassRule<S: Sequence>(in ids: S) -> String? where S.Element == String {
        ids.filter { $0.hasPrefix("CHL-BASS-") && $0 != "CHL-BASS-005" }.last
    }

    /// The offsets a song takes: Soho Soul, or Chill Blues on an allowed bass; zero for the rest.
    static func offsets(for song: SongState) -> (bassMs: Int, backbeatMs: Int) {
        offsets(style: song.style, beatStyle: song.chillBeatStyle, blues: song.chillBluesVariation,
                bassRule: bassRule(in: song.generationLog.map(\.tag)))
    }

    static func offsets(style: MusicStyle, beatStyle: ChillBeatStyle, blues: Bool,
                        bassRule: String?) -> (bassMs: Int, backbeatMs: Int) {
        guard style == .chill else { return (bassMs: 0, backbeatMs: 0) }
        if blues {
            guard let rule = bassRule, bluesBassRules.contains(rule) else { return (bassMs: 0, backbeatMs: 0) }
            return bluesOffsets
        }
        return offsets(for: beatStyle)
    }

    /// Generation-log text, or nil when the song takes no delay.
    static func logDescription(for song: SongState) -> String? {
        logDescription(style: song.style, beatStyle: song.chillBeatStyle, blues: song.chillBluesVariation,
                       bassRule: bassRule(in: song.generationLog.map(\.tag)))
    }

    static func logDescription(style: MusicStyle, beatStyle: ChillBeatStyle, blues: Bool,
                               bassRule: String?) -> String? {
        let o = offsets(style: style, beatStyle: beatStyle, blues: blues, bassRule: bassRule)
        guard o.bassMs > 0 || o.backbeatMs > 0 else { return nil }
        return "\(blues ? "Blues" : "Soul") bass +\(o.bassMs) ms, rim/snare +\(o.backbeatMs) ms"
    }
}
