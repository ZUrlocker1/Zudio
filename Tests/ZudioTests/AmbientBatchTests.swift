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

        // Distribute 20 songs across rules in natural proportions: 001×6 (30%), 002×9 (45%), 003×5 (25%)
        let ruleSequence: [String] = Array(repeating: "AMB-PNO-001", count: 6)
            + Array(repeating: "AMB-PNO-002", count: 9)
            + Array(repeating: "AMB-PNO-003", count: 5)

        print("\n=== Generating 20 Ambient Piano songs ===")
        print("Rules: 6×AMB-PNO-001, 9×AMB-PNO-002, 5×AMB-PNO-003")
        print("Output: \(dir.path)\n")

        for i in 1...20 {
            let pianoRule = ruleSequence[i - 1]
            let seed = UInt64.random(in: .min ... .max)
            let song = SongGenerator.generate(seed: seed, style: .ambient,
                                              forceAmbientPianoRule: pianoRule)

            let seedHex  = String(format: "%016llx", seed)
            let filename = String(format: "ambient_%02d_%@_%@.MID", i, pianoRule, seedHex)
            let midiURL  = dir.appendingPathComponent(filename)

            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)

            let keyMode  = (song.frame.key + " " + song.frame.mode.rawValue).padding(toLength: 20, withPad: " ", startingAt: 0)
            let padsRule = song.generationLog.first { $0.tag.hasPrefix("AMB-PADS") }?.tag ?? "—"
            print("  \(i). \(keyMode)  \(song.frame.tempo) BPM  \(song.frame.totalBars) bars  [\(pianoRule)] [\(padsRule)]  \(song.title)")
        }

        print("\n✓ Done. Run: cd tools/batch-output/ambient && python3 ../../ambient_piano_analyze.py *.MID")
    }
}
