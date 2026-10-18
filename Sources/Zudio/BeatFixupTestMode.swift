// BeatFixupTestMode.swift — TEMPORARY TESTING SCAFFOLDING, not a product feature.
//
// ⌘J and ⌃G (key monitor only — the menu item was removed 2026-10-18) switch the behind-the-beat delay on and off for
// the playing song, so it can be A/B'd by ear. The delay is a playback flag: no note moves, so
// the MIDI lanes do not redraw and the log row is the confirmation. It takes the same keys the
// Groove Fixup test mode used (removed 2026-10-18).
//
// TO REMOVE: delete this file and the ⌃G / ⌘J block in ContentView's key monitor (marked
// "BEAT FIXUP TEST MODE"), and PlaybackEngine's `beatFixupEnabled` switch if the delay ships
// unconditionally.

#if os(macOS)
import Foundation

extension AppState {

    /// Every press logs a row, including one that changes nothing, so a dead key is never
    /// mistaken for a live one.
    func toggleBeatFixupTestMode() {
        guard let song = songState else { logBeatFixup("no song loaded"); return }
        let enabled = !playback.beatFixupEnabled
        playback.setBeatFixupEnabled(enabled)
        if let on = BeatFixup.logDescription(for: song.chillBeatStyle), song.style == .chill {
            logBeatFixup(enabled ? on : "off, notes on the grid")
        } else {
            logBeatFixup(enabled ? "on, but this song takes no delay (Chill Soho Soul only)"
                                 : "off")
        }
    }

    /// Goes through `appendToLog`, which bumps `statusLogVersion`; StatusBoxView redraws on that.
    private func logBeatFixup(_ summary: String) {
        appendToLog([GenerationLogEntry(tag: "Laid back", description: summary)])
    }
}
#endif
