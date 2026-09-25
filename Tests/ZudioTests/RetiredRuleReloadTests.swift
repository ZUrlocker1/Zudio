// RetiredRuleReloadTests.swift — a retired rule must never produce a silent track.
//
// Run with:
//   swift test --filter RetiredRuleReloadTests
//
// WHY THIS EXISTS
// Build 131 retired four bass rules from the base Motorik pool: MOT-BASS-005 McCartney Drive,
// 006 LA Woman Sustain, 007 Hook Ascent and 010 Quo Arc. Retired means removed from the base
// pool's draw, NOT deleted — Noir and Arcade still draw all four, and a saved song may still
// name one in its Forced Rules line.
//
// A .zudio file stores the seed, not the notes, so an old song is rebuilt by re-running the
// generator. Two paths have to keep working:
//
//   1. A song with a FORCED rule replays that rule by ID through forceRuleID, which bypasses
//      pool selection entirely. The retired implementations must still be reachable and must
//      still produce notes.
//   2. An ordinary song re-draws from today's pool. It will get a DIFFERENT bass rule than it
//      originally had, because the pool and weights changed — that is expected and fine. What
//      is NOT acceptable is an empty track.

import Testing
import Foundation
@testable import Zudio

@Suite struct RetiredRuleReloadTests {

    /// The four rules retired from base Motorik in build 131.
    private static let retired = ["MOT-BASS-005", "MOT-BASS-006", "MOT-BASS-007", "MOT-BASS-010"]

    /// Path 1 — a saved song naming a retired rule still plays it.
    @Test func retiredRulesStillGenerateWhenForced() throws {
        for ruleID in Self.retired {
            for seed in UInt64(1)...25 {
                let s = SongGenerator.generate(seed: seed, style: .motorik, forceBassRuleID: ruleID)
                #expect(!s.trackEvents[kTrackBass].isEmpty,
                        "\(ruleID) seed \(seed): forced retired rule produced a silent bass track")
            }
        }
    }

    /// The forced rule is the one that actually runs, not a substitute.
    @Test func forcedRetiredRuleIsTheRuleUsed() throws {
        for ruleID in Self.retired {
            let s = SongGenerator.generate(seed: 7, style: .motorik, forceBassRuleID: ruleID)
            let log = s.generationLog.map(\.description).joined(separator: " | ")
            #expect(log.contains(SongGenerator.ruleDescriptionForTest(ruleID)),
                    "\(ruleID): forced rule not reflected in the log — \(log)")
        }
    }

    /// Path 2 — an ordinary reload re-draws from today's pool and is never silent. Checked for
    /// every track, since a retired rule is only the most obvious way to end up with nothing.
    @Test func reloadedSongsNeverHaveASilentBass() throws {
        for seed in UInt64(1)...300 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            #expect(!s.trackEvents[kTrackBass].isEmpty, "seed \(seed): silent bass")
            #expect(!s.trackEvents[kTrackDrums].isEmpty, "seed \(seed): silent drums")
        }
    }

    /// The retired four must be gone from the base pool but still reachable from a substyle,
    /// which is the condition that made them safe to retire in the first place.
    @Test func retiredRulesAreAbsentFromBaseButPresentInSubstyles() throws {
        var base = Set<String>(), substyle = Set<String>()
        for seed in UInt64(1)...1500 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            let log = s.generationLog.map(\.description).joined(separator: " | ")
            for ruleID in Self.retired where log.contains(SongGenerator.ruleDescriptionForTest(ruleID)) {
                if s.motorikNoirVariation || s.motorikArcadeVariation { substyle.insert(ruleID) }
                else { base.insert(ruleID) }
            }
        }
        #expect(base.isEmpty, "retired rules still drawn by base Motorik: \(base.sorted())")
        #expect(!substyle.isEmpty, "retired rules unreachable from Noir/Arcade too — they are now dead code")
    }
}
