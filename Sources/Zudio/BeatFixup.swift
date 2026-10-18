// BeatFixup.swift — the "behind the beat" feel for Chill Soho Soul grooves.
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

    /// Generation-log text, or nil when the groove takes no delay (every style but Soho Soul).
    static func logDescription(for beatStyle: ChillBeatStyle) -> String? {
        let o = offsets(for: beatStyle)
        guard o.bassMs > 0 || o.backbeatMs > 0 else { return nil }
        return "Soul bass +\(o.bassMs) ms, rim/snare +\(o.backbeatMs) ms"
    }
}
