// MotorikNoirCompareTests.swift — Generates 15 Motorik Noir + 15 regular Motorik songs
// for comparison testing.
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/MotorikNoirCompareTests
//
// Output: ~/Downloads/Zudio/tools/batch-output/motorik/
//   noir_NN_<seed>.MID/.zudio      — 15 Noir songs
//   regular_NN_<seed>.MID/.zudio   — 15 Regular songs

import Testing
import Foundation
@testable import Zudio

struct MotorikNoirCompareTests {

    private static var batchDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/motorik")
    }

    @Test func generateMotorikNoirComparison() throws {
        let dir = Self.batchDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Clear previous output
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing { try? fm.removeItem(at: url) }

        var noirSongs:    [SongState] = []
        var regularSongs: [SongState] = []
        var attempts = 0

        print("\n=== Generating Motorik Comparison: 15 Noir + 15 Regular ===")
        print("Output: \(dir.path)\n")

        while (noirSongs.count < 15 || regularSongs.count < 15) && attempts < 300 {
            let seed = UInt64.random(in: .min ... .max)
            let song = SongGenerator.generate(seed: seed, style: .motorik)
            attempts += 1
            if song.motorikNoirVariation && noirSongs.count < 15 {
                noirSongs.append(song)
            } else if !song.motorikNoirVariation && regularSongs.count < 15 {
                regularSongs.append(song)
            }
        }

        func save(_ song: SongState, prefix: String, index: Int) throws {
            let seedHex  = String(format: "%016llx", song.globalSeed)
            let filename = String(format: "\(prefix)_%02d_%@.MID", index, seedHex)
            let midiURL  = dir.appendingPathComponent(filename)
            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)
            let keyMode  = (song.frame.key + " " + song.frame.mode.rawValue)
                .padding(toLength: 22, withPad: " ", startingAt: 0)
            let ld1Rule  = song.generationLog.first { $0.tag.hasPrefix("MOT-LD1") }?.tag ?? "?"
            print("  \(prefix.uppercased()) \(index). \(keyMode) \(song.frame.tempo) BPM  \(song.frame.totalBars) bars  [\(ld1Rule)]  \(song.title)")
        }

        print("--- Noir ---")
        for (i, song) in noirSongs.enumerated() { try save(song, prefix: "noir",    index: i + 1) }
        print("\n--- Regular ---")
        for (i, song) in regularSongs.enumerated() { try save(song, prefix: "regular", index: i + 1) }

        print("\n✓ Done — Noir: \(noirSongs.count), Regular: \(regularSongs.count), attempts: \(attempts)")
        print("Analyze: cd tools/batch-output/motorik && python3 ../../motorik_noir_compare.py")
    }
}
