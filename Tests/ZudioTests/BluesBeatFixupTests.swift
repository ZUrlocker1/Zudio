// BluesBeatFixupTests.swift — pins which Chill songs take the behind-the-beat delay.
//
// Run with:
//   swift test --filter BluesBeatFixupTests

import Testing
import Foundation
@testable import Zudio

@Suite struct BluesBeatFixupTests {

    @Test func bluesDelayFollowsTheBassPattern() throws {
        var seenAllowed = Set<String>(), seenDenied = Set<String>()
        for i in UInt64(1)...400 {
            let song = SongGenerator.generate(seed: i &* 0x9E3779B97F4A7C15, style: .chill)
            guard song.chillBluesVariation else { continue }
            let rule = BeatFixup.bassRule(in: song.generationLog.map(\.tag)) ?? "none"
            let o = BeatFixup.offsets(for: song)
            let logged = song.generationLog.contains { $0.tag == "Laid back" }
            if BeatFixup.bluesBassRules.contains(rule) {
                seenAllowed.insert(rule)
                #expect(o == BeatFixup.bluesOffsets, "\(rule)")
                #expect(logged, "\(rule) should log a Laid back row")
            } else {
                seenDenied.insert(rule)
                #expect(o == (bassMs: 0, backbeatMs: 0), "\(rule)")
                #expect(!logged, "\(rule) should not log a Laid back row")
            }
        }
        #expect(seenAllowed.count >= 3, "saw \(seenAllowed)")
        #expect(seenDenied.contains("CHL-BASS-011") && seenDenied.contains("CHL-BASS-012"), "saw \(seenDenied)")
    }

    @Test func sohoSoulAndBaseChillAreUnchanged() throws {
        for i in UInt64(1)...150 {
            let song = SongGenerator.generate(seed: i &* 0x9E3779B97F4A7C15, style: .chill)
            guard !song.chillBluesVariation else { continue }
            let want = BeatFixup.offsets(for: song.chillBeatStyle)
            #expect(BeatFixup.offsets(for: song) == want)
        }
    }
}
