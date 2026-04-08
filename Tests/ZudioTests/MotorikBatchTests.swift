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

    // Lead rule rotation — exclusively MOT-LD1-003 (Punch Solo) and MOT-LD1-006 (Long Arc),
    // 5 songs each, so both revised rules can be evaluated side by side.
    private static let leadRuleRotation: [String?] = [
        "MOT-LD1-003", "MOT-LD1-003", "MOT-LD1-003", "MOT-LD1-003", "MOT-LD1-003",
        "MOT-LD1-006", "MOT-LD1-006", "MOT-LD1-006", "MOT-LD1-006", "MOT-LD1-006",
    ]

    @Test func generateMotorikBatch() throws {
        let dir = Self.batchDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Clear all previous output
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing {
            try? fm.removeItem(at: url)
        }

        print("\n=== Generating 10 Motorik songs ===")
        print("  5× MOT-LD1-003 (Punch Solo)   5× MOT-LD1-006 (Long Arc)")
        print("Output: \(dir.path)\n")

        for i in 1...10 {
            let seed     = UInt64.random(in: .min ... .max)
            let ruleID   = Self.leadRuleRotation[i - 1]
            let song     = SongGenerator.generate(seed: seed, style: .motorik,
                                                  testMode: false, forceLeadRuleID: ruleID)

            let seedHex  = String(format: "%016llx", seed)
            let filename = String(format: "motorik_%02d_%@.MID", i, seedHex)
            let midiURL  = dir.appendingPathComponent(filename)

            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)

            let keyMode  = (song.frame.key + " " + song.frame.mode.rawValue).padding(toLength: 20, withPad: " ", startingAt: 0)
            let ld1Rule  = song.generationLog.first { $0.tag.hasPrefix("MOT-LD1") }?.tag ?? "?"
            print("  \(i). \(keyMode)  \(song.frame.tempo) BPM  \(song.frame.totalBars) bars  [\(ld1Rule)]  \(song.title)")
        }

        print("\n✓ Done. Run: cd tools/batch-output/motorik && python3 ../../analyze_zudio.py *.MID")
    }
}
