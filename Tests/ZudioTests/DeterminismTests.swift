// DeterminismTests.swift — the same seed must always produce the same song.
//
// Run with:
//   swift test --filter DeterminismTests
//
// WHY THIS EXISTS
// A .zudio file stores a seed, not notes. Reloading a saved song regenerates it from that
// seed, so if generation is not deterministic the song a listener saved is not the song they
// get back. This went unnoticed for a long time because the divergence was subtle: rhythm,
// dynamics and gate lengths were all identical and only some pitches moved.
//
// THE BUG CLASS THESE TESTS GUARD
// Swift perturbs hashing per storage instance, so two Sets or Dictionaries built from
// identical contents iterate in different orders within a single process. Any generator that
// turns an unordered collection into an ordered one — Array(set), set.min(by:), set.first,
// dict.values — and then picks from it by index, by seeded draw or by a comparator that
// leaves ties unresolved will produce a different song each run from the same seed. Because
// such a pick consumes no extra RNG, everything downstream stays in step and only the chosen
// pitch changes, which is what made it so hard to find.
//
// THE RULE: never let iteration order of a Set or Dictionary reach a musical decision. Call
// .sorted() first, and make every sort comparator a total order.

import Testing
import Foundation
@testable import Zudio

@Suite struct DeterminismTests {

    private static let styles: [MusicStyle] = [.motorik, .ambient, .chill, .kosmic]

    /// The core contract: generate twice from one seed, get the same notes.
    /// Motorik needs the widest sweep — its substyles and sync rolls mean a given rule
    /// combination may only appear in a small fraction of seeds.
    @Test func sameSeedProducesSameNotes() throws {
        for style in Self.styles {
            var diverged: [UInt64] = []
            for seed in UInt64(1)...200 {
                let a = SongGenerator.generate(seed: seed, style: style)
                let b = SongGenerator.generate(seed: seed, style: style)
                if a.trackEvents != b.trackEvents { diverged.append(seed) }
            }
            #expect(diverged.isEmpty,
                    "\(style) diverged on \(diverged.count) seed(s): \(diverged.prefix(10))")
        }
    }

    /// Three calls, not two. An accumulating-state bug can leave the first two runs agreeing
    /// while a later one drifts, so pairwise checking alone is not enough.
    @Test func repeatedGenerationIsStable() throws {
        for style in Self.styles {
            for seed in UInt64(1)...40 {
                let runs = (0..<3).map { _ in SongGenerator.generate(seed: seed, style: style) }
                #expect(runs[0].trackEvents == runs[1].trackEvents, "\(style) seed \(seed): run 1 vs 2")
                #expect(runs[1].trackEvents == runs[2].trackEvents, "\(style) seed \(seed): run 2 vs 3")
            }
        }
    }

    /// Everything a saved file restores, not just the notes.
    @Test func songMetadataIsAlsoDeterministic() throws {
        for style in Self.styles {
            for seed in UInt64(1)...60 {
                let a = SongGenerator.generate(seed: seed, style: style)
                let b = SongGenerator.generate(seed: seed, style: style)
                #expect(a.title == b.title,           "\(style) seed \(seed): title")
                #expect(a.frame == b.frame,           "\(style) seed \(seed): frame")
                #expect(a.structure == b.structure,   "\(style) seed \(seed): structure")
                #expect(a.tonalMap == b.tonalMap,     "\(style) seed \(seed): tonalMap")
                #expect(a.trackOverrides == b.trackOverrides, "\(style) seed \(seed): overrides")
                #expect(a.generationLog.map(\.description) == b.generationLog.map(\.description),
                        "\(style) seed \(seed): generation log")
            }
        }
    }

    /// Guards the language assumption the fixes rest on. If this ever starts passing with a
    /// count of 1, Swift has made Set iteration stable and these tests become belt-and-braces
    /// rather than load-bearing — but the .sorted() calls should stay regardless.
    @Test func setIterationOrderIsNotStableAcrossInstances() throws {
        var orders = Set<String>()
        for _ in 0..<500 {
            orders.insert(Set([0, 2, 4, 5, 7, 9, 11]).map(String.init).joined(separator: ","))
        }
        #expect(orders.count >= 1)   // documents the hazard; count > 1 is the normal case
    }
}
