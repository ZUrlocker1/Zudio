// ChillBatchTests.swift — headless Chill batch generator + regen variation test.
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/ChillBatchTests
//
// Output: ~/Downloads/Zudio/tools/batch-output/chill/
//   *.MID + *.zudio   — 10 freshly generated Chill songs
//   regen/            — 5 drum regens + 5 Lead 1 regens for 3 fixed seeds
//
// Then run: python3 tools/chill_analyze.py ~/Downloads/Zudio/tools/batch-output/chill/

import Testing
import Foundation
@testable import Zudio

struct ChillBatchTests {

    // MARK: - Output directory

    private static var batchDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/chill")
    }

    private static var regenDir: URL {
        batchDir.appendingPathComponent("regen")
    }

    // MARK: - Fixed seeds for regen variation test (from known Chill songs)
    // Replace with seeds from listened-to songs after round 1.
    private static let regenSeeds: [UInt64] = [
        836996789863366411,   // Zudio-Gil (Free / Mixolydian)
        0xDEAD_BEEF_1234_5678,
        0xCAFE_BABE_DEAD_C0DE,
    ]

    // MARK: - Batch generation

    @Test func generateChillBatch() throws {
        let dir = Self.batchDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Clear previous batch (keep regen/ subdirectory)
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing where url.pathExtension.lowercased() == "mid" || url.pathExtension == "zudio" {
            try? fm.removeItem(at: url)
        }

        print("\n=== Generating 20 Chill songs ===")
        print("Output: \(dir.path)\n")

        var moodCounts: [String: Int] = [:]

        for i in 1...20 {
            let seed = UInt64.random(in: .min ... .max)
            let song = SongGenerator.generate(seed: seed, style: .chill, testMode: false)

            let seedHex = String(format: "%016llx", seed)
            let filename = String(format: "chill_%02d_%@.MID", i, seedHex)
            let midiURL  = dir.appendingPathComponent(filename)

            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)

            let mood = song.frame.mood.rawValue
            moodCounts[mood, default: 0] += 1

            // Identify drum rule and lead instrument from log
            let drumRule = song.generationLog.first { $0.tag.hasPrefix("CHL-DRUM-") }?.tag ?? "?"
            let form = song.generationLog.first { $0.tag == "Form" }?.description ?? "?"
            let keyMode = (song.frame.key + " " + song.frame.mode.rawValue).padding(toLength: 20, withPad: " ", startingAt: 0)
            print("  \(i). \(keyMode)  \(mood)/\(song.title)  drum=\(drumRule)  \(form)")
        }

        print("\nMood distribution: \(moodCounts.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))")
        print("\n✓ Done. Run: python3 tools/chill_analyze.py \(dir.path)")
    }

    // MARK: - Regen variation test

    @Test func generateChillRegenVariation() throws {
        let dir = Self.regenDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Clear previous regen files
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing where url.pathExtension.lowercased() == "mid" || url.pathExtension == "zudio" {
            try? fm.removeItem(at: url)
        }

        print("\n=== Chill Regen Variation Test ===")
        print("Seeds: \(Self.regenSeeds.map { String(format: "0x%llx", $0) }.joined(separator: ", "))\n")

        for seed in Self.regenSeeds {
            let seedHex = String(format: "%016llx", seed)
            let baseSong = SongGenerator.generate(seed: seed, style: .chill, testMode: false)
            print("Seed \(seedHex)  [\(baseSong.frame.mood.rawValue) \(baseSong.frame.mode.rawValue)]  \(baseSong.frame.totalBars) bars")

            // Generate 5 drum regens
            var drumStepSets: [Set<Int>] = []
            for i in 1...5 {
                let regen = SongGenerator.regenerateTrack(kTrackDrums, songState: baseSong)
                let steps = Set(regen.events(forTrack: kTrackDrums).map { $0.stepIndex })
                drumStepSets.append(steps)
                let url = dir.appendingPathComponent("chill_\(seedHex)_drums_regen\(i).MID")
                try MIDIFileExporter.export(regen, to: url)
                try SongLogExporter.export(regen, midiURL: url)
            }

            // Generate 5 Lead 1 regens
            var lead1StepSets: [Set<Int>] = []
            for i in 1...5 {
                let regen = SongGenerator.regenerateTrack(kTrackLead1, songState: baseSong)
                let steps = Set(regen.events(forTrack: kTrackLead1).map { $0.stepIndex })
                lead1StepSets.append(steps)
                let url = dir.appendingPathComponent("chill_\(seedHex)_lead1_regen\(i).MID")
                try MIDIFileExporter.export(regen, to: url)
                try SongLogExporter.export(regen, midiURL: url)
            }

            let drumDiff  = pairwiseJaccardDiff(drumStepSets)
            let lead1Diff = pairwiseJaccardDiff(lead1StepSets)
            print(String(format: "  Drums  avg step diff: %4.1f%%  min: %4.1f%%  %@",
                         drumDiff.avg * 100, drumDiff.min * 100,
                         drumDiff.min < 0.15 ? "!! REGEN-MONOTONE" : "ok"))
            print(String(format: "  Lead1  avg step diff: %4.1f%%  min: %4.1f%%  %@",
                         lead1Diff.avg * 100, lead1Diff.min * 100,
                         lead1Diff.min < 0.15 ? "!! REGEN-MONOTONE" : "ok"))
        }

        print("\n✓ Regen files written to: \(dir.path)")
        print("Run: python3 tools/chill_analyze.py \(Self.batchDir.path)")
    }

    // MARK: - Helpers

    /// Pairwise Jaccard difference (fraction of step positions present in one but not both).
    private func pairwiseJaccardDiff(_ sets: [Set<Int>]) -> (avg: Double, min: Double) {
        var diffs: [Double] = []
        for i in 0..<sets.count {
            for j in (i+1)..<sets.count {
                let union = sets[i].union(sets[j])
                guard !union.isEmpty else { diffs.append(0); continue }
                let shared = sets[i].intersection(sets[j]).count
                diffs.append(Double(union.count - shared) / Double(union.count))
            }
        }
        guard !diffs.isEmpty else { return (0, 0) }
        return (diffs.reduce(0, +) / Double(diffs.count), diffs.min() ?? 0)
    }
}
