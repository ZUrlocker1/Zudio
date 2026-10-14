// ChordPlanShapeTests.swift — pins the invariant `SongStructure.chordWindow(atBar:)` relies on.
//
// Run with:
//   swift test --filter ChordPlanShapeTests
//
// WHY THIS EXISTS
// ---------------
// `chordWindow(atBar:)` binary-searches the chord plan. That is only correct while the plan is
// sorted by startBar and its windows do not overlap. Nothing in the type system enforces either:
// `chordPlan` is a plain array that every style's structure generator builds by hand.
//
// Before the search replaced it, 38 call sites each ran `chordPlan.first { $0.contains(bar:) }`,
// a linear scan that would still have found the right window in an unsorted plan. A generator
// that breaks the ordering today would instead make the search miss, and the symptom would be a
// handful of bars quietly taking the wrong chord — the kind of fault that is nearly impossible
// to hear as a bug rather than as a bad song.
//
// So the invariant is pinned here rather than left implicit.

import Testing
@testable import Zudio

@Suite struct ChordPlanShapeTests {

    @Test func chordPlansAreSortedAndNonOverlapping() {
        for style in [MusicStyle.chill, .motorik, .kosmic, .ambient] {
            for seed in UInt64(1)...120 {
                let s = SongGenerator.generate(seed: seed, style: style)
                let plan = s.structure.chordPlan
                guard plan.count > 1 else { continue }
                for (a, b) in zip(plan, plan.dropFirst()) {
                    #expect(b.startBar >= a.startBar,
                            "\(style) seed \(seed): plan not sorted (\(a.startBar) then \(b.startBar))")
                    #expect(b.startBar >= a.endBar,
                            "\(style) seed \(seed): windows overlap at bar \(b.startBar)")
                }
            }
        }
    }

    /// The search and the scan it replaced must agree on every bar of every song.
    @Test func binarySearchMatchesALinearScan() {
        for style in [MusicStyle.chill, .motorik, .kosmic, .ambient] {
            for seed in UInt64(1)...60 {
                let s = SongGenerator.generate(seed: seed, style: style)
                for bar in -2..<(s.frame.totalBars + 2) {
                    let scanned = s.structure.chordPlan.first { $0.contains(bar: bar) }
                    #expect(s.structure.chordWindow(atBar: bar) == scanned,
                            "\(style) seed \(seed) bar \(bar): search and scan disagree")
                }
            }
        }
    }
}
