// MotorikBatchTests.swift — headless Motorik batch generator.
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/MotorikBatchTests
//
// Output: ~/Downloads/Zudio/tools/batch-output/motorik/
//   *.MID + *.zudio   — 10 freshly generated Motorik songs

import Testing
import Foundation
@testable import Zudio

struct MotorikBatchTests {

    private static var batchDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/motorik")
    }

    @Test func generateMotorikBatch() throws {
        let dir = Self.batchDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing where url.pathExtension.lowercased() == "mid" || url.pathExtension == "zudio" {
            try? fm.removeItem(at: url)
        }

        print("\n=== Generating 10 Motorik songs ===")
        print("Output: \(dir.path)\n")

        for i in 1...10 {
            let seed = UInt64.random(in: .min ... .max)
            let song = SongGenerator.generate(seed: seed, style: .motorik, testMode: false)

            let seedHex  = String(format: "%016llx", seed)
            let filename = String(format: "motorik_%02d_%@.MID", i, seedHex)
            let midiURL  = dir.appendingPathComponent(filename)

            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)

            let keyMode = (song.frame.key + " " + song.frame.mode.rawValue).padding(toLength: 20, withPad: " ", startingAt: 0)
            let form = song.generationLog.first { $0.tag == "Form" }?.description ?? "?"
            print("  \(i). \(keyMode)  \(song.frame.tempo) BPM  \(song.frame.totalBars) bars  \(song.title)  \(form)")
        }

        print("\n✓ Done. Run: python3 tools/analyze_zudio.py \(dir.path)")
    }
}
