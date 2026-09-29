// MotorikLeadDensityTests.swift — pins the cap on the two dense Lead 1 rules.
//
// Run with:
//   swift test --filter MotorikLeadDensityTests
//
// WHY THIS EXISTS
// Most long-running Lead 1 rules are sparse, and there the length is the gesture rather than a
// fault: Noir's Chromatic Descent runs about 19 bars at 1.6 notes a bar, which is a slow
// descent. Arcade is relentless by design. Those are deliberately left alone.
//
// Two rules combine length with density. Melodic Spiral (Noir) is the densest rule in Motorik
// at 6.8 notes a bar and Octave Bounce (Arcade) is close behind at 6.1, and both used to hold
// that for twenty bars and occasionally nearly forty — a stream of sixteenths with no air in
// it. They are capped by cutting rests into the stretch rather than by rewriting the rules, so
// each keeps its own density and only the tail cases change.

import Testing
import Foundation
@testable import Zudio

@Suite struct MotorikLeadDensityTests {

    /// Longest run of consecutive bars in which Lead 1 sounds.
    private func longestStretch(_ song: SongState) -> Int {
        let sounding = Set(song.trackEvents[kTrackLead1].map { $0.stepIndex / 16 })
        var longest = 0, current = 0
        for bar in 0..<song.frame.totalBars {
            if sounding.contains(bar) { current += 1; longest = Swift.max(longest, current) }
            else { current = 0 }
        }
        return longest
    }

    /// The capped rules must not exceed the cap. Measured before the cap: Melodic Spiral ran to
    /// 32 bars and Octave Bounce to 38.
    @Test func denseLeadRulesAreCapped() throws {
        var seen: [String: Int] = [:]
        var worst: [String: Int] = [:]
        for seed in UInt64(1)...1500 {
            let song = SongGenerator.generate(seed: seed, style: .motorik)
            guard song.trackEvents[kTrackLead1].count > 20,
                  let rule = song.generationLog.first(where: { $0.tag.hasPrefix("MOT-LD1-") })?.tag,
                  rule == "MOT-LD1-011" || rule == "MOT-LD1-018"
            else { continue }
            seen[rule, default: 0] += 1
            worst[rule] = Swift.max(worst[rule] ?? 0, longestStretch(song))
        }
        for rule in ["MOT-LD1-011", "MOT-LD1-018"] {
            #expect((seen[rule] ?? 0) >= 10, "not enough \(rule) songs sampled: \(seen[rule] ?? 0)")
            #expect((worst[rule] ?? 0) <= 20,
                    "\(rule) played \(worst[rule] ?? 0) bars without a rest — the cap is 20")
        }
    }

    /// The cap cuts rests into the line; it must not thin the line itself. If these rules stop
    /// being dense, the cap has been applied in the wrong place and they have lost the
    /// character the cap exists to preserve.
    @Test func cappedRulesKeepTheirDensity() throws {
        var notes: [String: Int] = [:], bars: [String: Int] = [:]
        for seed in UInt64(1)...1500 {
            let song = SongGenerator.generate(seed: seed, style: .motorik)
            let events = song.trackEvents[kTrackLead1]
            guard events.count > 20,
                  let rule = song.generationLog.first(where: { $0.tag.hasPrefix("MOT-LD1-") })?.tag,
                  rule == "MOT-LD1-011" || rule == "MOT-LD1-018"
            else { continue }
            notes[rule, default: 0] += events.count
            bars[rule, default: 0] += Set(events.map { $0.stepIndex / 16 }).count
        }
        for rule in ["MOT-LD1-011", "MOT-LD1-018"] {
            guard let n = notes[rule], let b = bars[rule], b > 0 else { continue }
            let perBar = Double(n) / Double(b)
            #expect(perBar >= 5.0,
                    "\(rule) fell to \(perBar) notes a bar — the cap should remove bars, not notes")
        }
    }

    /// The sparse long-running rules are deliberately NOT capped, and this records that so the
    /// cap is not widened to them by someone reading only the first test.
    @Test func sparseLongRulesAreLeftAlone() throws {
        var worst = 0
        var seen = 0
        for seed in UInt64(1)...1500 {
            let song = SongGenerator.generate(seed: seed, style: .motorik)
            guard song.trackEvents[kTrackLead1].count > 20,
                  let rule = song.generationLog.first(where: { $0.tag.hasPrefix("MOT-LD1-") })?.tag,
                  rule == "MOT-LD1-012"      // Chromatic Descent — 1.6 notes a bar
            else { continue }
            seen += 1
            worst = Swift.max(worst, longestStretch(song))
        }
        #expect(seen >= 5, "not enough Chromatic Descent songs sampled: \(seen)")
        #expect(worst > 20,
                "Chromatic Descent no longer runs past 20 bars — a slow descent is its character, so the cap should not have reached it")
    }
}
