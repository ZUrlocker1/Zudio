// SongLogExporter.swift — writes a companion analysis log alongside a saved MIDI file.
// Output: same base name as the MIDI file, .txt extension.
// Used by the Musical Coherence analysis workflow (docs/musical-coherence-plan.md).

import Foundation

struct SongLogExporter {

    // MARK: - Public entry point

    /// Writes a .txt log file next to `midiURL` (same stem, .txt extension).
    static func export(_ song: SongState, midiURL: URL) throws {
        let logURL = midiURL.deletingPathExtension().appendingPathExtension("txt")
        try buildLog(song).write(to: logURL, atomically: true, encoding: .utf8)
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
            col("Zudio Version:",  16) + "0.93",
            col("Seed:",           16) + "\(song.globalSeed)",
            col("Style:",          16) + song.style.rawValue.capitalized,
        ]
        if !song.trackOverrides.isEmpty {
            let overridesStr = song.trackOverrides.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }.joined(separator: "  ")
            lines.append(col("Track Overrides:", 16) + overridesStr)
        }
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
            let name = i < kTrackNames.count ? kTrackNames[i] : "Track \(i)"
            lines.append("  \(col(name, 12)) \(events.count) notes")
        }
        lines.append("")

        // ── Generation log ───────────────────────────────────────────────────────
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
}
