// AllStylesBatchTests.swift — 100-song random-style batch for statistical analysis.
//
// Style is chosen randomly for each song (equal probability across 4 styles),
// so the output distribution reflects natural randomness rather than forced balance.
// Run with:
//   swift test --package-path . --filter AllStylesBatchTests
// OR:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/AllStylesBatchTests
//
// Output: ~/Downloads/Zudio/tools/batch-output/all/
//   *.MID + *.zudio   — 100 songs, style picked randomly per song
// Then analyze with:
//   python3 tools/batch_stats.py tools/batch-output/all/

import Testing
import Foundation
@testable import Zudio

struct AllStylesBatchTests {

    private static var batchDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/all")
    }

    @Test func generateAllStylesBatch() throws {
        let dir = Self.batchDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing { try? fm.removeItem(at: url) }

        let totalSongs = 100
        let styles: [MusicStyle] = [.kosmic, .chill, .ambient, .motorik]

        print("\n=== Generating \(totalSongs) songs (random style, full AppState instrument selection) ===")
        print("Output: \(dir.path)\n")

        var styleCounts: [MusicStyle: Int] = [:]
        var stylesWithGeneratedSongs = Set<MusicStyle>()

        // Persistent state across songs — mirrors AppState instance state
        var instrumentOverrides:    [Int: Int]                = [:]
        var lastUsedInstrumentIndex:[Int: [MusicStyle: Int]]  = [:]

        for i in 1...totalSongs {
            let style = styles[Int.random(in: 0..<styles.count)]
            styleCounts[style, default: 0] += 1

            let isFirstForStyle = !stylesWithGeneratedSongs.contains(style)
            stylesWithGeneratedSongs.insert(style)

            let seed = UInt64.random(in: .min ... .max)
            var song = SongGenerator.generate(seed: seed, style: style)

            // Run the exact same instrument selection AppState does — same static code, same logic
            AppState.selectInstrumentsForSong(
                state: song,
                isFirstForStyle: isFirstForStyle,
                overrides: &instrumentOverrides,
                lastUsed: &lastUsedInstrumentIndex
            )

            // Build the Instruments log line from the real overrides (same as applyCurrentInstrumentsToPlayback)
            let shortNames = ["L1","L2","Pd","Ry","Tx","Bs","Dr","LS"]
            var instParts: [String] = []
            for t in 0..<kTrackCount {
                if t == kTrackTexture && style == .chill { instParts.append("Tx:audio"); continue }
                if t == kTrackLeadSynth && style != .kosmic { continue }
                let pool = AppState.instrumentPoolPrograms(trackIndex: t, style: style,
                                                          isKosmicDrift: song.isKosmicDrift)
                guard !pool.isEmpty else { continue }
                let idx  = instrumentOverrides[t] ?? 0
                let prog = pool[min(idx, pool.count - 1)]
                if prog != 255 { instParts.append("\(shortNames[t]):\(prog)") }
            }
            let instLine = instParts.joined(separator: " ")

            // Inject the real Instruments entry into the log before saving
            song.generationLog.removeAll { $0.tag == "Instruments" }
            song.generationLog.append(GenerationLogEntry(tag: "Instruments", description: instLine, isTitle: false))

            let seedHex  = String(format: "%016llx", seed)
            let prefix   = style.rawValue.prefix(3).lowercased()
            let filename = String(format: "song%03d_%@_%@.MID", i, prefix, seedHex)
            let midiURL  = dir.appendingPathComponent(filename)

            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)

            let substyle = song.generationLog.first { $0.tag == "Style" }?.description ?? ""
            let keyMode  = "\(song.frame.key) \(song.frame.mode.rawValue)"
            let mood     = song.frame.mood.rawValue
            let sub      = substyle.isEmpty ? "(base)" : substyle
            print("  \(String(format:"%3d",i)). [\(style.rawValue.prefix(3).uppercased())] \(keyMode.padding(toLength:18,withPad:" ",startingAt:0)) \(song.frame.tempo)BPM \(song.frame.totalBars)bars \(mood.padding(toLength:6,withPad:" ",startingAt:0)) \(sub)  \(song.title)")
        }

        print("\nStyle distribution:")
        for style in styles {
            let n = styleCounts[style, default: 0]
            print("  \(style.rawValue.capitalized.padding(toLength:10,withPad:" ",startingAt:0)) \(n)/\(totalSongs)")
        }
        print("\n(Run length analysis in batch_stats.py)")
        print("\n✓ Done. Analyze with:")
        print("   python3 tools/batch_stats.py tools/batch-output/all/")
    }
}
