// KosmicBatchTests.swift — headless Kosmic batch generator.
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/KosmicBatchTests
//
// Output: ~/Downloads/Zudio/tools/batch-output/kosmic/
//   *.MID + *.zudio   — 10 freshly generated Kosmic songs

import Testing
import Foundation
@testable import Zudio

struct KosmicBatchTests {

    private static var batchDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/kosmic")
    }

    @Test func generateKosmicBatch() throws {
        let dir = Self.batchDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Clear all previous output
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing {
            try? fm.removeItem(at: url)
        }

        print("\n=== Generating 10 Kosmic songs ===")
        print("Output: \(dir.path)\n")

        for i in 1...10 {
            let seed = UInt64.random(in: .min ... .max)
            let song = SongGenerator.generate(seed: seed, style: .kosmic, testMode: false)

            let seedHex  = String(format: "%016llx", seed)
            let filename = String(format: "kosmic_%02d_%@.MID", i, seedHex)
            let midiURL  = dir.appendingPathComponent(filename)

            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)

            let keyMode   = (song.frame.key + " " + song.frame.mode.rawValue).padding(toLength: 20, withPad: " ", startingAt: 0)
            let leadRule  = song.generationLog.first { $0.tag.hasPrefix("KOS-LEAD") }?.tag ?? "?"
            let drumRule  = song.generationLog.first { $0.tag.hasPrefix("KOS-DRUM") }?.tag ?? "?"
            let rhytmRule = song.generationLog.first { $0.tag.hasPrefix("KOS-RTHM") }?.tag ?? "?"
            print("  \(i). \(keyMode)  \(song.frame.tempo) BPM  \(song.frame.totalBars) bars  [\(leadRule)] [\(drumRule)] [\(rhytmRule)]  \(song.title)")
        }

        print("\n✓ Done. Run: cd tools/batch-output/kosmic && python3 ../../kosmic_analyze.py *.MID")
    }
}
