// ChillBluesBatchTests.swift — headless Chill Blues batch generator.
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/ChillBluesBatchTests
//
// Output: ~/Downloads/Zudio/tools/batch-output/chill-blues/
//   *.MID + *.zudio   — 30 forced-blues Chill songs
//
// Then run: python3 tools/chill_blues_analyze.py ~/Downloads/Zudio/tools/batch-output/chill-blues/

import Testing
import Foundation
@testable import Zudio

struct ChillBluesBatchTests {

    // MARK: - Output directory

    private static var batchDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/chill-blues")
    }

    // MARK: - Batch generation

    @Test func generateChillBluesBatch() throws {
        let dir = Self.batchDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Clear previous batch
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing where url.pathExtension.lowercased() == "mid" || url.pathExtension == "zudio" {
            try? fm.removeItem(at: url)
        }

        print("\n=== Generating 30 Chill Blues songs ===")
        print("Output: \(dir.path)\n")

        var beatStyleCounts: [String: Int] = [:]
        var leadInstCounts:  [String: Int] = [:]
        var keyCounts:       [String: Int] = [:]

        for i in 1...30 {
            let seed = UInt64.random(in: .min ... .max)
            let song = SongGenerator.generate(seed: seed, style: .chill, forceBluesVariation: true)

            let seedHex = String(format: "%016llx", seed)
            let filename = String(format: "chill_blues_%02d_%@.MID", i, seedHex)
            let midiURL  = dir.appendingPathComponent(filename)

            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)

            let beatStyle = song.chillBeatStyle.rawValue
            let leadInst  = song.chillLeadInstrument.rawValue
            let drumRule  = song.generationLog.first { $0.tag.hasPrefix("CHL-DRUM-") }?.tag ?? "?"
            let bassRule  = song.generationLog.first { $0.tag.hasPrefix("CHL-BASS-") }?.tag ?? "?"
            let keyMode   = (song.frame.key + " " + song.frame.mode.rawValue).padding(toLength: 16, withPad: " ", startingAt: 0)

            beatStyleCounts[beatStyle, default: 0] += 1
            leadInstCounts[leadInst, default: 0]   += 1
            keyCounts[song.frame.key, default: 0]   += 1

            print("  \(i). \(keyMode)  \(song.frame.tempo)bpm  \(song.title)")
            print("       beat=\(beatStyle)  lead=\(leadInst)  \(drumRule)  \(bassRule)")
        }

        print("\nBeat styles: \(beatStyleCounts.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))")
        print("Lead insts:  \(leadInstCounts.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))")
        print("Keys:        \(keyCounts.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))")
        print("\n✓ Done. Run: python3 tools/chill_blues_analyze.py \(dir.path)")
    }
}
