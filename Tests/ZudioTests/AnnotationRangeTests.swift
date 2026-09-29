// AnnotationRangeTests.swift — pins the bass-window guard in buildStepAnnotations.
//
// Run with:
//   swift test --filter AnnotationRangeTests
//
// WHY THIS EXISTS
// `bassWindow(fromBar:)` builds `fromBar..<min(fromBar + 4, totalBars)`. For a bar at or past
// the last one that clamps the upper bound BELOW the lower one, and constructing the range
// traps: "Range requires lowerBound <= upperBound". The caller strides to outroStartBar and
// only checks that a section covers the bar, which can hold past totalBars when a section's
// declared range overruns the song.
//
// Ambient seed 622 is one such song. The bug dates to commit 90b05aa (March) and went unseen
// because it needs a specific structure; it surfaced when the batch suites grew enough that
// some run would hit it, crashing the whole test process about half the time.

import Testing
import Foundation
@testable import Zudio

@Suite struct AnnotationRangeTests {

    /// The song that found it. A crash here takes the process down, so reaching the assertion
    /// at all is the result.
    @Test func ambientSeed622Generates() throws {
        let song = SongGenerator.generate(seed: 622, style: .ambient)
        #expect(song.frame.totalBars > 0)
    }

    /// A sweep wide enough to catch other structures that overrun their bar count. Kept modest
    /// so it stays a unit test; the fix was verified separately across 80,000 songs.
    @Test func annotationsSurviveAWideSweep() throws {
        for style in [MusicStyle.ambient, .chill, .kosmic, .motorik] {
            for i in UInt64(1)...750 {
                // Small and scattered seeds both: the batch suites use the full UInt64 range.
                let seed = i % 2 == 0 ? i : (i &* 0x9E3779B97F4A7C15) ^ (i << 32)
                let song = SongGenerator.generate(seed: seed, style: style)
                #expect(song.frame.totalBars > 0, "\(style) seed \(seed) produced no bars")
            }
        }
    }
}
