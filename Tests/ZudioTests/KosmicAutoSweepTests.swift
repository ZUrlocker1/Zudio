// KosmicAutoSweepTests.swift — pins the automatic Kosmic filter-sweep schedule.
//
// Run with:
//   swift test --filter KosmicAutoSweepTests

import Testing
import Foundation
@testable import Zudio

@Suite struct KosmicAutoSweepTests {

    private let seeds: [UInt64] = (1...150).map { $0 &* 0x9E3779B97F4A7C15 }

    @Test func onlyRegularKosmicSongsGetSweeps() throws {
        for seed in seeds.prefix(40) {
            for style in [MusicStyle.motorik, .ambient, .chill] {
                let song = SongGenerator.generate(seed: seed, style: style)
                #expect(KosmicAutoSweep.steps(for: song).isEmpty, "\(style) seed \(seed)")
            }
        }
    }

    @Test func scheduleIsDeterministicAndWellFormed() throws {
        var withSweeps = 0, regular = 0
        for seed in seeds {
            let song = SongGenerator.generate(seed: seed, style: .kosmic)
            let a = KosmicAutoSweep.steps(for: song)
            #expect(a == KosmicAutoSweep.steps(for: song))
            if song.isKosmicDrift { #expect(a.isEmpty, "Drift seed \(seed)"); continue }
            regular += 1
            guard !a.isEmpty else { continue }
            withSweeps += 1
            #expect((1...3).contains(a.count))
            let lead = song.frame.tempo / 5
            let outro = song.structure.outroSection?.startBar ?? song.frame.totalBars
            for (i, s) in a.enumerated() {
                let boundary = (s + lead + 15) / 16
                #expect(boundary * 16 - lead == s)
                #expect(boundary <= outro - KosmicAutoSweep.outroGuardBars)
                if i > 0 { #expect((s - a[i - 1]) / 16 >= KosmicAutoSweep.minSpacingBars - 1) }
            }
        }
        // 40% of regular Kosmic songs, with room for sampling noise and songs too short to fit one.
        let share = Double(withSweeps) / Double(Swift.max(1, regular))
        #expect(share > 0.2 && share < 0.55, "share \(share) of \(regular)")
    }
}
