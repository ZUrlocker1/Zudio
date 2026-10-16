// WeightedPickTests.swift — pins every literal weight array passed to weightedPick.
//
// Run with:
//   swift test --filter WeightedPickTests
//
// WHY THIS EXISTS
// ---------------
// `SeededRNG.weightedPick` subtracts the weights from a `[0,1)` draw and does NOT normalise, so
// the weights must sum to 1.0. Getting that wrong fails silently rather than loudly: pass
// percentages and the first weight alone exceeds the draw, so index 0 comes back every time.
//
// Two sites in Operator (CHL-LD1-010) passed `[35, 30, 15, 20]` and `[35, 45, 20]`. The result was
// that every phrase began on the downbeat — 99% of them, measured — and every rest between
// phrases took its shortest option. The rule had been written to vary both and never did
// (found 2026-10-15).
//
// Normalising inside weightedPick looks like the obvious fix and was tried. It is not safe:
// several call sites build their weights at runtime and land slightly under 1.0, and that
// shortfall currently falls through to the last option. Normalising redistributes it and
// changed five Motorik Noir songs, which must not move. So the contract stays, and this test
// enforces it by reading the source — the same approach EffectChainParityTests uses.
//
// It only sees LITERAL arrays. Computed weights are not covered, so a generator that builds
// weights at runtime still has to get this right by hand.

import Testing
import Foundation

struct WeightedPickTests {

    private static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // ZudioTests
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // repo root
            .appendingPathComponent("Sources")
    }

    @Test func literalWeightsSumToOne() throws {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: Self.sourceRoot, includingPropertiesForKeys: nil) else {
            Issue.record("could not read Sources"); return
        }
        // weightedPick([ ... ]) where the contents are numeric literals only.
        let re = try NSRegularExpression(pattern: #"weightedPick\(\s*\[([0-9eE_.,\s+-]+)\]\s*\)"#)
        var checked = 0

        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            let lines = text.components(separatedBy: .newlines)
            for (n, line) in lines.enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                for m in re.matches(in: line, range: range) {
                    guard let r = Range(m.range(at: 1), in: line) else { continue }
                    let parts = line[r].split(separator: ",")
                        .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    guard parts.count > 1 else { continue }
                    checked += 1
                    let total = parts.reduce(0, +)
                    let where_ = url.lastPathComponent + ":" + String(n + 1)
                    #expect(abs(total - 1.0) < 0.001,
                            Comment(rawValue: where_ + " passes weights summing to "
                                  + String(format: "%g", total)
                                  + " — weightedPick does not normalise, so index 0 wins every time"))
                }
            }
        }
        #expect(checked > 50, "expected to find the call sites; found \(checked)")
    }
}
