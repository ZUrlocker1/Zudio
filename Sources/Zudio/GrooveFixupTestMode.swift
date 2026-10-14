// GrooveFixupTestMode.swift — TEMPORARY TESTING SCAFFOLDING, not a product feature.
//
// ⌘J (menu: File ▸ Groove Fixup (test)) and ⌃G toggle the groove fixup on the current song's
// Lead 1 and Lead 2, and the MIDI lanes redraw. Flicking between the two is the diff: notes
// visibly shift and lengthen.
//
// It is a true toggle in both directions. A Latin Soho song is already fixed when it is
// generated, so the first press takes it BACK to the raw leads; anything else starts raw, so
// the first press applies. Either way the second press returns to where you started.
//
// Added 2026-10-14 to audition the fixup on Chill Soho's non-Latin grooves and on base Chill
// before widening the gate. Expected to be removed once that decision is made.
//
// TO REMOVE: delete this file, the ⌃G block in ContentView's key monitor, the menu item in
// ZudioApp's .commands (both marked "GROOVE FIXUP TEST MODE"), and the `skipGrooveFixup`
// parameter on SongGenerator.generate/generateChill.
// `SongGenerator.applyGrooveFixup(to:options:)` is NOT scaffolding — keep it; it is the
// ungated entry point that widening the gate will use.

#if os(macOS)
import Foundation

/// Both versions of the leads for one song, so the toggle can move either way.
///
/// File-scoped rather than a stored property on AppState so deleting this file removes every
/// trace. There is one AppState and this is only ever touched on the main actor.
private struct GrooveFixupSnapshot {
    let seed: UInt64
    let raw:   [Int: [MIDIEvent]]   // leads with the passes off
    let fixed: [Int: [MIDIEvent]]   // leads with the passes on
    let summary: String             // counts describing raw -> fixed
}

@MainActor private var grooveFixupSnapshot: GrooveFixupSnapshot? = nil

private let kGrooveFixupLeads = [kTrackLead1, kTrackLead2]

extension AppState {

    /// ⌘J / ⌃G. Switches the song between its raw leads and its fixed ones.
    ///
    /// Every press logs a row, including the ones that change nothing. A silent key is
    /// impossible to tell apart from one that never arrived, which is the confusion this mode
    /// exists to avoid.
    func toggleGrooveFixupTestMode() {
        guard let song = songState else { logGrooveFixup("no song loaded"); return }
        guard !isGenerating      else { logGrooveFixup("busy generating — try again"); return }

        let snap = validSnapshot(for: song) ?? buildSnapshot(for: song)
        grooveFixupSnapshot = snap

        // Already fixed → go back to raw. Otherwise → apply.
        let goingToRaw = kGrooveFixupLeads.allSatisfy { song.trackEvents[$0] == snap.fixed[$0] }
        let target     = goingToRaw ? snap.raw : snap.fixed
        var updated    = song
        for (track, events) in target {
            updated = updated.replacingEvents(events, forTrack: track)
        }
        songState = updated
        playback.load(updated)          // rebuild stepEventMap, as track regen does
        if !generationHistory.isEmpty {
            generationHistory[generationHistory.count - 1] = updated
        }
        logGrooveFixup(goingToRaw ? "Original leads restored" : snap.summary)
    }

    /// A snapshot is only trusted while it still describes the song on screen: same seed, and
    /// the leads still exactly one of the two versions it holds.
    ///
    /// The hazard is a snapshot outliving its song — generate a new song, or regenerate a lead,
    /// and a stale one would write one song's leads into another. Rather than invalidate from
    /// every place that assigns songState (there are many, and a missed one corrupts silently)
    /// it is validated here, at the point of use. Anything unexpected and it is rebuilt.
    private func validSnapshot(for song: SongState) -> GrooveFixupSnapshot? {
        guard let snap = grooveFixupSnapshot, snap.seed == song.globalSeed else { return nil }
        let isRaw   = kGrooveFixupLeads.allSatisfy { song.trackEvents[$0] == snap.raw[$0] }
        let isFixed = kGrooveFixupLeads.allSatisfy { song.trackEvents[$0] == snap.fixed[$0] }
        return (isRaw || isFixed) ? snap : nil
    }

    /// Rebuilds both versions of the leads.
    ///
    /// Both come from real generations of the same seed — one with the passes on, one with them
    /// off — rather than from applying the passes to the finished song. That matters because
    /// generation runs the fixup BEFORE `HarmonicFilter`, which then removes a slightly
    /// different set of clashing notes; applying the passes afterwards produces leads that
    /// generation would never have made, and the note counts drift apart.
    ///
    /// The rebuild is only trusted when the tracks the passes never touch come back identical,
    /// which fails for an evolve state or a song whose tracks were regenerated. Then the leads
    /// on screen are taken as the raw ones and the fixed version is produced in place — an
    /// approximation, since it misses the pre-filter ordering, but the only option available.
    ///
    /// On a non-Latin song the two generations agree, because the gate kept the passes off in
    /// both. The fixed version is then produced by the ungated entry point, which is the whole
    /// point of this mode.
    private func buildSnapshot(for song: SongState) -> GrooveFixupSnapshot {
        func leads(_ s: SongState) -> [Int: [MIDIEvent]] {
            Dictionary(uniqueKeysWithValues: kGrooveFixupLeads.map { ($0, s.trackEvents[$0]) })
        }
        func summarise(_ raw: [Int: [MIDIEvent]], _ fixed: [Int: [MIDIEvent]]) -> String {
            var total = 0
            let parts = [("L1", kTrackLead1), ("L2", kTrackLead2)].map { label, track -> String in
                let was = raw[track] ?? []
                guard !was.isEmpty else { return "\(label): N/A" }
                let n = SongGenerator.differingNoteCount(before: was, after: fixed[track] ?? [])
                total += n
                return "\(label): \(n) / \(was.count)"
            }
            return total == 0 ? "No changes!" : parts.joined(separator: ",  ") + " changes"
        }

        let rawRun   = SongGenerator.generate(seed: song.globalSeed, style: song.style,
                                              skipGrooveFixup: true)
        let fixedRun = SongGenerator.generate(seed: song.globalSeed, style: song.style,
                                              skipGrooveFixup: false)
        let untouched = (0..<kTrackCount).filter { !kGrooveFixupLeads.contains($0) }
        let reproduces = untouched.allSatisfy { fixedRun.trackEvents[$0] == song.trackEvents[$0] }

        if reproduces {
            let raw = leads(rawRun)
            if leads(fixedRun) != raw {                    // Latin: generation already applied it
                return GrooveFixupSnapshot(seed: song.globalSeed, raw: raw,
                                           fixed: leads(fixedRun),
                                           summary: summarise(raw, leads(fixedRun)))
            }
            var rawState = song                            // non-Latin: apply it ourselves
            for (t, e) in raw { rawState = rawState.replacingEvents(e, forTrack: t) }
            let applied = SongGenerator.applyGrooveFixup(to: rawState)
            return GrooveFixupSnapshot(seed: song.globalSeed, raw: raw,
                                       fixed: leads(applied.state), summary: applied.summary)
        }

        // Seed does not reproduce this song — work from what is on screen.
        let raw = leads(song)
        let applied = SongGenerator.applyGrooveFixup(to: song)
        return GrooveFixupSnapshot(seed: song.globalSeed, raw: raw,
                                   fixed: leads(applied.state), summary: applied.summary)
    }

    /// Goes through `appendToLog`, which bumps `statusLogVersion`. StatusBoxView redraws on that
    /// version, not on `statusLog` itself — appending directly leaves rows invisible until some
    /// unrelated action bumps it, and they then all appear at once.
    private func logGrooveFixup(_ summary: String) {
        appendToLog([GenerationLogEntry(tag: "Groove fixup", description: summary)])
    }
}
#endif
