// SongLogExporter.swift — writes a companion analysis log alongside a saved MIDI file.
// Output: same base name as the MIDI file, .txt extension.
// Used by the Musical Coherence analysis workflow (docs/musical-coherence-plan.md).

import Foundation

struct SongLogExporter {

    // MARK: - Public entry points

    /// Writes a temp .zudio file and returns its URL for sharing (nil on failure).
    static func shareURL(for song: SongState) -> URL? {
        let tmpBase = FileManager.default.temporaryDirectory
            .appendingPathComponent(song.title)
            .appendingPathExtension("midi")
        try? export(song, midiURL: tmpBase)
        let shareURL = tmpBase.deletingPathExtension().appendingPathExtension("zudio")
        return FileManager.default.fileExists(atPath: shareURL.path) ? shareURL : nil
    }

    /// Writes a .zudio log file next to `midiURL` (same stem, .zudio extension).
    static func export(_ song: SongState, midiURL: URL) throws {
        // Batch tests never call applyCurrentInstrumentsToPlayback(), so the Instruments entry
        // won't be in generationLog yet. Compute it from SongState so batch files match app files.
        var song = song
        if !song.generationLog.contains(where: { $0.tag == "Instruments" }) {
            song.generationLog.append(GenerationLogEntry(
                tag: "Instruments", description: generationInstrumentsLine(song), isTitle: false))
        }
        let logURL = midiURL.deletingPathExtension().appendingPathExtension("zudio")
        guard let data = buildLog(song).data(using: .utf8) else { return }
        try data.write(to: logURL, options: .atomic)
        // Note: do NOT call NSWorkspace.setIcon here — it writes the full icon image into
        // the resource fork, bloating every .zudio file from ~2 KB to 128 KB.
        // Finder shows the correct document icon via the UTI registration in Info.plist.
    }

    // MARK: - Log construction

    private static func buildLog(_ song: SongState) -> String {
        var lines: [String] = []

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateStr = df.string(from: Date())

        // ── Header ───────────────────────────────────────────────────────────────
        lines += [
            "=== Zudio Song Analysis Log ===",
            col("Title:",          16) + song.title,
            col("Generated:",      16) + dateStr,
            col("Zudio Version:",  16) + "1.0",
            col("Seed:",           16) + "\(song.globalSeed)",
            col("Style:",          16) + song.style.rawValue.capitalized,
        ]
        if !song.trackOverrides.isEmpty {
            let overridesStr = song.trackOverrides.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }.joined(separator: "  ")
            lines.append(col("Track Overrides:", 16) + overridesStr)
        }
        if !song.forcedRules.isEmpty {
            let forcedStr = song.forcedRules.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }.joined(separator: "  ")
            lines.append(col("Forced Rules:", 16) + forcedStr)
        }
        // Only write override lines when the user explicitly set a value before generating.
        // The informational Key:/Tempo:/Mood: fields below are NOT read back on load.
        if let k = song.keyOverride   { lines.append(col("Key Override:",   16) + k) }
        if let t = song.tempoOverride { lines.append(col("Tempo Override:", 16) + "\(t)") }
        if let m = song.moodOverride  { lines.append(col("Mood Override:",  16) + m.rawValue) }
        lines += [
            col("Key:",       16) + "\(song.frame.key)  \(song.frame.mode.rawValue)",
            col("Tempo:",     16) + "\(song.frame.tempo) BPM",
            col("Bars:",      16) + "\(song.frame.totalBars)",
            col("Mood:",      16) + song.frame.mood.rawValue,
            ""
        ]

        // ── Structure ────────────────────────────────────────────────────────────
        lines.append("--- Structure ---")
        for s in song.structure.sections {
            guard s.lengthBars > 0 else { continue }   // suppress zero-bar ramp stubs
            let label = col(s.label.rawValue, 10)
            let range = "Bars \(barStr(s.startBar))–\(barStr(s.endBar - 1))"
            let len   = "(\(s.lengthBars) bars)"
            lines.append("  \(label) \(col(range, 20)) \(len)")
        }
        // Ambient-only: log co-prime loop lengths so QA can check for duplicate assignments.
        // Only show a track's loop length if it produced events — silent tracks (e.g. AMB-BASS-002,
        // AMB-RTHM-004) are omitted so the log isn't misleading.
        if let loops = song.ambientLoopLengths {
            let te = song.trackEvents
            var loopLines: [String] = []
            if te.indices.contains(kTrackLead1),  !te[kTrackLead1].isEmpty  { loopLines.append("    Lead 1:  \(loops.lead1)") }
            if te.indices.contains(kTrackLead2),  !te[kTrackLead2].isEmpty  { loopLines.append("    Lead 2:  \(loops.lead2)") }
            if te.indices.contains(kTrackPads),   !te[kTrackPads].isEmpty   { loopLines.append("    Pads:    \(loops.pads)") }
            if te.indices.contains(kTrackBass),   !te[kTrackBass].isEmpty   { loopLines.append("    Bass:    \(loops.bass)") }
            if te.indices.contains(kTrackRhythm), !te[kTrackRhythm].isEmpty { loopLines.append("    Rhythm:  \(loops.rhythm)") }
            if te.indices.contains(kTrackTexture),!te[kTrackTexture].isEmpty { loopLines.append("    Texture: \(loops.texture)") }
            if !loopLines.isEmpty {
                lines.append("")
                lines.append("  Loop lengths (bars):")
                lines.append(contentsOf: loopLines)
            }
        }
        lines.append("")

        // ── Chord plan ───────────────────────────────────────────────────────────
        lines.append("--- Chord Plan ---")
        for c in song.structure.chordPlan {
            let range = "Bars \(barStr(c.startBar))–\(barStr(c.endBar - 1))"
            lines.append("  \(col(range, 20)) root=\(c.chordRoot)  type=\(c.chordType)")
        }
        lines.append("")

        // ── Note counts ──────────────────────────────────────────────────────────
        lines.append("--- Note Counts Per Track ---")
        for (i, events) in song.trackEvents.enumerated() {
            guard !events.isEmpty else { continue }  // skip unpopulated tracks (e.g. Lead Synth in Motorik)
            let name = i < kTrackNames.count ? kTrackNames[i] : "Track \(i)"
            lines.append("  \(col(name, 12)) \(events.count) notes")
        }
        lines.append("")

        // ── Generation log ───────────────────────────────────────────────────────
        // Includes the "Instruments" entry written by applyCurrentInstrumentsToPlayback().
        lines.append("--- Generation Log ---")
        for entry in song.generationLog where !entry.tag.isEmpty || !entry.description.isEmpty {
            lines.append("  \(col(entry.tag, 16)) \(entry.description)")
        }
        lines.append("")

        // ── Playback annotations (sorted by bar) ─────────────────────────────────
        let sorted = song.stepAnnotations.sorted { $0.key < $1.key }
        if !sorted.isEmpty {
            lines.append("--- Playback Annotations ---")
            for (step, entries) in sorted {
                let bar = step / 16 + 1
                let barLabel = String(format: "Bar %03d", bar)
                for entry in entries {
                    lines.append("  \(col(barLabel, 10)) \(col(entry.tag, 12)) \(entry.description)")
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Helpers

    /// Left-pads `s` to exactly `width` characters (truncates if longer).
    private static func col(_ s: String, _ width: Int) -> String {
        if s.count >= width { return s }
        return s + String(repeating: " ", count: width - s.count)
    }

    /// 1-based bar number as a 3-digit string.
    private static func barStr(_ bar: Int) -> String {
        String(format: "%3d", bar + 1)
    }

    /// Derives the Instruments line from SongState without requiring PlaybackEngine.
    /// Used by batch tests which never call applyCurrentInstrumentsToPlayback().
    /// Chill Lead 1/2 use the generation instrument (chillLeadInstrument/chillLead2Instrument);
    /// all other tracks use pool[0] from instrumentPoolPrograms — the same default the app loads.
    private static func generationInstrumentsLine(_ song: SongState) -> String {
        let shortNames = ["L1", "L2", "Pd", "Ry", "Tx", "Bs", "Dr", "LS"]
        var parts: [String] = []
        for i in 0..<kTrackCount {
            if i == kTrackTexture && song.style == .chill {
                parts.append("Tx:audio")
                continue
            }
            let p = generationProgram(forTrack: i, song: song)
            if p != 255 { parts.append("\(shortNames[i]):\(p)") }
        }
        return parts.joined(separator: " ")
    }

    private static func generationProgram(forTrack i: Int, song: SongState) -> UInt8 {
        if song.style == .chill {
            if i == kTrackLead1 { return song.chillLeadInstrument.gmProgram }
            if i == kTrackLead2 { return song.chillLead2Instrument.gmProgram }
        }
        if i == kTrackLeadSynth { return kDefaultGMPrograms[kTrackLeadSynth] ?? 90 }
        let pool = AppState.instrumentPoolPrograms(trackIndex: i, style: song.style)
        return pool.first ?? 255
    }

}
