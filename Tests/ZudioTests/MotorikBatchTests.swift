// MotorikBatchTests.swift — headless Motorik batch generator.
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/MotorikBatchTests
//
// Output: ~/Downloads/Zudio/tools/batch-output/motorik/
//   *.MID + *.zudio   — 40 freshly generated Motorik songs (all 8 lead rules, 5 each, shuffled)

import Testing
import Foundation
@testable import Zudio

struct MotorikBatchTests {

    private static var batchDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/motorik")
    }

    // All 8 lead rules, 5 songs each = 40 songs total, shuffled for random order
    private static let allLeadRules: [String] = [
        "MOT-LD1-001", "MOT-LD1-002", "MOT-LD1-003", "MOT-LD1-004",
        "MOT-LD1-005", "MOT-LD1-006", "MOT-LD1-007", "MOT-LD1-008",
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

        // Build shuffled rotation: 5 songs × 8 rules = 40, randomly ordered
        var rotation: [String] = []
        for rule in Self.allLeadRules { for _ in 1...5 { rotation.append(rule) } }
        rotation.shuffle()

        print("\n=== Generating 40 Motorik songs (all 8 lead rules, 5 each) ===")
        print("Output: \(dir.path)\n")

        for i in 1...40 {
            let seed     = UInt64.random(in: .min ... .max)
            let ruleID   = rotation[i - 1]
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
