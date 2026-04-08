// AmbientBatchTests.swift — headless Ambient batch generator.
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/AmbientBatchTests
//
// Output: ~/Downloads/Zudio/tools/batch-output/ambient/
//   *.MID + *.zudio   — 20 freshly generated Ambient songs

import Testing
import Foundation
@testable import Zudio

struct AmbientBatchTests {

    private static var batchDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/ambient")
    }

    @Test func generateAmbientBatch() throws {
        let dir = Self.batchDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Clear all previous output
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing {
            try? fm.removeItem(at: url)
        }

        print("\n=== Generating 20 Ambient songs ===")
        print("Output: \(dir.path)\n")

        for i in 1...20 {
            let seed = UInt64.random(in: .min ... .max)
            let song = SongGenerator.generate(seed: seed, style: .ambient, testMode: false)

            let seedHex  = String(format: "%016llx", seed)
            let filename = String(format: "ambient_%02d_%@.MID", i, seedHex)
            let midiURL  = dir.appendingPathComponent(filename)

            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)

            let keyMode  = (song.frame.key + " " + song.frame.mode.rawValue).padding(toLength: 20, withPad: " ", startingAt: 0)
            let leadRule = song.generationLog.first { $0.tag.hasPrefix("AMB-LEAD") }?.tag ?? "?"
            let drumRule = song.generationLog.first { $0.tag.hasPrefix("AMB-DRUM") }?.tag ?? "?"
            let bassRule = song.generationLog.first { $0.tag.hasPrefix("AMB-BASS") }?.tag ?? "?"
            print("  \(i). \(keyMode)  \(song.frame.tempo) BPM  \(song.frame.totalBars) bars  [\(leadRule)] [\(drumRule)] [\(bassRule)]  \(song.title)")
        }

        print("\n✓ Done. Run: cd tools/batch-output/ambient && python3 ../../ambient_analyze.py *.MID")
    }
}
