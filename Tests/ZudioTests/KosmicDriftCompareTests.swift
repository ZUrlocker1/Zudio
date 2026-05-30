// KosmicDriftCompareTests.swift — 20-song batch comparison: Regular Kosmic vs Kosmic Drift
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/KosmicDriftCompareTests
//
// Output: ~/Downloads/Zudio/tools/batch-output/drift-compare/
//   regular/  *.MID + *.zudio   — 20 regular Kosmic songs
//   drift/    *.MID + *.zudio   — 20 Kosmic Drift songs
//   Analysis printed to console

import Testing
import Foundation
@testable import Zudio

struct KosmicDriftCompareTests {

    private static var baseDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/drift-compare")
    }

    // MARK: - Main test

    @Test func compareKosmicVsDrift() throws {
        let base    = Self.baseDir
        let regDir  = base.appendingPathComponent("regular")
        let driftDir = base.appendingPathComponent("drift")
        let fm = FileManager.default
        for dir in [regDir, driftDir] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
                .forEach { try? fm.removeItem(at: $0) }
        }

        print("\n" + String(repeating: "═", count: 70))
        print("  KOSMIC vs KOSMIC DRIFT — 20-song batch comparison")
        print(String(repeating: "═", count: 70))

        // Generate songs until we have 20 of each type.
        // isKosmicDrift is drawn at 80% so regular songs require more attempts.
        var regularSongs: [SongState] = []
        var driftSongs:   [SongState] = []
        var attempts = 0
        while regularSongs.count < 20 || driftSongs.count < 20 {
            attempts += 1
            if attempts > 500 { break }
            let seed = UInt64.random(in: .min ... .max)
            let song = SongGenerator.generate(seed: seed, style: .kosmic)
            if song.isKosmicDrift && driftSongs.count < 20 {
                driftSongs.append(song)
            } else if !song.isKosmicDrift && regularSongs.count < 20 {
                regularSongs.append(song)
            }
        }

        // Export files
        for (i, song) in regularSongs.enumerated() {
            let n = String(format: "regular_%02d_%016llx.MID", i+1, song.globalSeed)
            let url = regDir.appendingPathComponent(n)
            try MIDIFileExporter.export(song, to: url)
            try SongLogExporter.export(song, midiURL: url)
        }
        for (i, song) in driftSongs.enumerated() {
            let n = String(format: "drift_%02d_%016llx.MID", i+1, song.globalSeed)
            let url = driftDir.appendingPathComponent(n)
            try MIDIFileExporter.export(song, to: url)
            try SongLogExporter.export(song, midiURL: url)
        }

        print("\n  Generated \(regularSongs.count) regular + \(driftSongs.count) drift in \(attempts) attempts")
        print("  Output: \(base.path)\n")

        // Analysis
        printComparison(regular: regularSongs, drift: driftSongs)
    }

    // MARK: - Analysis

    private func printComparison(regular: [SongState], drift: [SongState]) {
        let sep = String(repeating: "─", count: 70)

        // ── TEMPO ──────────────────────────────────────────────────────────
        print(sep)
        print("  TEMPO (BPM)")
        printStat("Regular", values: regular.map { Double($0.frame.tempo) })
        printStat("Drift  ", values: drift.map   { Double($0.frame.tempo) })

        // ── SONG LENGTH ────────────────────────────────────────────────────
        print(sep)
        print("  SONG LENGTH (bars)")
        printStat("Regular", values: regular.map { Double($0.frame.totalBars) })
        printStat("Drift  ", values: drift.map   { Double($0.frame.totalBars) })

        // ── MODES ──────────────────────────────────────────────────────────
        print(sep)
        print("  MODES")
        printDistribution("Regular", values: regular.map { $0.frame.mode.rawValue })
        printDistribution("Drift  ", values: drift.map   { $0.frame.mode.rawValue })

        // ── KEYS ───────────────────────────────────────────────────────────
        print(sep)
        print("  KEYS (top 6)")
        printDistribution("Regular", values: regular.map { $0.frame.key }, topN: 6)
        printDistribution("Drift  ", values: drift.map   { $0.frame.key }, topN: 6)

        // ── DRUM RULES ─────────────────────────────────────────────────────
        print(sep)
        print("  DRUM RULES")
        printRuleDistribution("Regular", songs: regular, prefix: "KOS-DRUM")
        printRuleDistribution("Drift  ", songs: drift,   prefix: "KOS-DRUM")

        // ── BASS RULES ─────────────────────────────────────────────────────
        print(sep)
        print("  BASS RULES")
        printRuleDistribution("Regular", songs: regular, prefix: "KOS-BASS")
        printRuleDistribution("Drift  ", songs: drift,   prefix: "KOS-BASS")

        // ── RHYTHM RULES ───────────────────────────────────────────────────
        print(sep)
        print("  RHYTHM / ARPEGGIO RULES")
        printRuleDistribution("Regular", songs: regular, prefix: "KOS-RTHM")
        printRuleDistribution("Drift  ", songs: drift,   prefix: "KOS-RTHM")

        // ── LEAD 1 RULES ───────────────────────────────────────────────────
        print(sep)
        print("  LEAD 1 RULES")
        printRuleDistribution("Regular", songs: regular, prefix: "KOS-LEAD")
        printRuleDistribution("Drift  ", songs: drift,   prefix: "KOS-LEAD")

        // ── BRIDGE PRESENCE ────────────────────────────────────────────────
        print(sep)
        print("  BRIDGES")
        let regBridge   = regular.filter { hasBridge($0) }.count
        let driftBridge = drift.filter   { hasBridge($0) }.count
        print("  Regular: \(regBridge)/\(regular.count) songs have a bridge (\(pct(regBridge, regular.count))%)")
        print("  Drift  : \(driftBridge)/\(drift.count) songs have a bridge (\(pct(driftBridge, drift.count))%)")
        print("  Drift bridge types:")
        printDistribution("  ", values: drift.compactMap { driftBridgeType($0) })

        // ── SONG FORMS ─────────────────────────────────────────────────────
        print(sep)
        print("  SONG FORMS")
        printDistribution("Regular", values: regular.map { $0.form.rawValue })
        printDistribution("Drift  ", values: drift.map   { $0.form.rawValue })

        // ── TRACK NOTE DENSITY ─────────────────────────────────────────────
        print(sep)
        print("  TRACK NOTE COUNTS (mean per song)")
        for (label, songs) in [("Regular", regular), ("Drift  ", drift)] {
            let r = noteCounts(songs, track: kTrackRhythm)
            let b = noteCounts(songs, track: kTrackBass)
            let p = noteCounts(songs, track: kTrackPads)
            let l = noteCounts(songs, track: kTrackLead1)
            let d = noteCounts(songs, track: kTrackDrums)
            print("  \(label):  Rhythm \(fmt(r))  Bass \(fmt(b))  Pads \(fmt(p))  Lead1 \(fmt(l))  Drums \(fmt(d))")
        }

        // ── LEAD 1 ENTRY BAR ───────────────────────────────────────────────
        print(sep)
        print("  LEAD 1 FIRST ENTRY BAR (silence before first note)")
        printStat("Regular", values: regular.map { Double(leadEntryBar($0)) })
        printStat("Drift  ", values: drift.map   { Double(leadEntryBar($0)) })

        // ── PAD CHORD DENSITY ──────────────────────────────────────────────
        print(sep)
        print("  PADS: MAX SIMULTANEOUS NOTES AT ANY STEP")
        printStat("Regular", values: regular.map { Double(maxSimultaneousPadNotes($0)) })
        printStat("Drift  ", values: drift.map   { Double(maxSimultaneousPadNotes($0)) })

        // ── DRUM SILENCE WINDOWS ───────────────────────────────────────────
        print(sep)
        print("  DRUMS: BARS WITH NO EVENTS (silence windows)")
        printStat("Regular", values: regular.map { Double(drumSilentBars($0)) })
        printStat("Drift  ", values: drift.map   { Double(drumSilentBars($0)) })

        // ── LEAD REGISTER ──────────────────────────────────────────────────
        print(sep)
        print("  LEAD 1 REGISTER (mean MIDI note, C4=60)")
        printStat("Regular", values: regular.compactMap { meanLeadNote($0) })
        printStat("Drift  ", values: drift.compactMap   { meanLeadNote($0) })

        // ── ISKOSMICDRFIT FLAG ─────────────────────────────────────────────
        print(sep)
        let driftFlagged = drift.filter { $0.isKosmicDrift }.count
        let regFlagged   = regular.filter { $0.isKosmicDrift }.count
        print("  isKosmicDrift flag: Regular \(regFlagged)/\(regular.count) set  |  Drift \(driftFlagged)/\(drift.count) set")

        // ── SONG LIST ──────────────────────────────────────────────────────
        print(sep)
        print("  REGULAR KOSMIC songs:")
        for (i, s) in regular.enumerated() {
            let drum = ruleTag(s, prefix: "KOS-DRUM")
            let lead = ruleTag(s, prefix: "KOS-LEAD")
            let bass = ruleTag(s, prefix: "KOS-BASS")
            print("  \(i+1). \(s.frame.key) \(s.frame.mode.rawValue.padding(toLength:10,withPad:" ",startingAt:0))  \(s.frame.tempo) BPM  \(s.frame.totalBars)b  D:\(drum) B:\(bass) L:\(lead)  \(s.title)")
        }
        print(sep)
        print("  KOSMIC DRIFT songs:")
        for (i, s) in drift.enumerated() {
            let drum = ruleTag(s, prefix: "KOS-DRUM")
            let lead = ruleTag(s, prefix: "KOS-LEAD")
            let bridge = driftBridgeType(s).map { " [\($0)]" } ?? ""
            print("  \(i+1). \(s.frame.key) \(s.frame.mode.rawValue.padding(toLength:10,withPad:" ",startingAt:0))  \(s.frame.tempo) BPM  \(s.frame.totalBars)b  D:\(drum) L:\(lead)\(bridge)  \(s.title)")
        }
        print(String(repeating: "═", count: 70) + "\n")
    }

    // MARK: - Helpers

    private func printStat(_ label: String, values: [Double]) {
        guard !values.isEmpty else { return }
        let mean = values.reduce(0,+) / Double(values.count)
        let min  = values.min()!
        let max  = values.max()!
        print("  \(label):  mean \(String(format:"%.1f",mean))  range \(String(format:"%.0f",min))–\(String(format:"%.0f",max))")
    }

    private func printDistribution(_ label: String, values: [String], topN: Int = 99) {
        var counts: [String: Int] = [:]
        values.forEach { counts[$0, default: 0] += 1 }
        let sorted = counts.sorted { $0.value > $1.value }.prefix(topN)
        let total  = values.count
        let parts  = sorted.map { "\($0.key) \(pct($0.value, total))%" }.joined(separator: "  ")
        print("  \(label):  \(parts)")
    }

    private func printRuleDistribution(_ label: String, songs: [SongState], prefix: String) {
        var counts: [String: Int] = [:]
        for song in songs {
            let tags = song.generationLog.map(\.tag).filter { $0.hasPrefix(prefix) }
            for tag in tags { counts[tag, default: 0] += 1 }
        }
        let sorted = counts.sorted { $0.value > $1.value }
        let parts  = sorted.map { "\($0.key)×\($0.value)" }.joined(separator: "  ")
        print("  \(label):  \(parts.isEmpty ? "none" : parts)")
    }

    private func hasBridge(_ song: SongState) -> Bool {
        song.structure.sections.contains { $0.label == .bridge || $0.label == .bridgeAlt || $0.label == .bridgeMelody }
    }

    private func driftBridgeType(_ song: SongState) -> String? {
        song.stepAnnotations.values.flatMap { $0 }
            .first { $0.tag == "Bridge" }?.description
    }

    private func ruleTag(_ song: SongState, prefix: String) -> String {
        song.generationLog.first { $0.tag.hasPrefix(prefix) }?.tag
            .replacingOccurrences(of: prefix + "-", with: "") ?? "?"
    }

    private func noteCounts(_ songs: [SongState], track: Int) -> Double {
        let total = songs.reduce(0) { $0 + ($1.trackEvents.indices.contains(track) ? $1.trackEvents[track].count : 0) }
        return Double(total) / Double(max(1, songs.count))
    }

    private func leadEntryBar(_ song: SongState) -> Int {
        guard song.trackEvents.indices.contains(kTrackLead1),
              let first = song.trackEvents[kTrackLead1].first else { return 0 }
        return first.stepIndex / 16
    }

    private func maxSimultaneousPadNotes(_ song: SongState) -> Int {
        guard song.trackEvents.indices.contains(kTrackPads) else { return 0 }
        var byStep: [Int: Int] = [:]
        for ev in song.trackEvents[kTrackPads] { byStep[ev.stepIndex, default: 0] += 1 }
        return byStep.values.max() ?? 0
    }

    private func drumSilentBars(_ song: SongState) -> Int {
        guard song.trackEvents.indices.contains(kTrackDrums) else { return song.frame.totalBars }
        let bodyStart = song.structure.introSection?.endBar ?? 0
        let bodyEnd   = song.structure.outroSection?.startBar ?? song.frame.totalBars
        var activeBars = Set<Int>()
        for ev in song.trackEvents[kTrackDrums] {
            let b = ev.stepIndex / 16
            if b >= bodyStart && b < bodyEnd { activeBars.insert(b) }
        }
        return (bodyEnd - bodyStart) - activeBars.count
    }

    private func meanLeadNote(_ song: SongState) -> Double? {
        guard song.trackEvents.indices.contains(kTrackLead1),
              !song.trackEvents[kTrackLead1].isEmpty else { return nil }
        let notes = song.trackEvents[kTrackLead1].map { Double($0.note) }
        return notes.reduce(0,+) / Double(notes.count)
    }

    private func fmt(_ d: Double) -> String { String(format: "%.0f", d) }
    private func pct(_ n: Int, _ total: Int) -> Int { total == 0 ? 0 : Int(Double(n)/Double(total)*100+0.5) }
}
