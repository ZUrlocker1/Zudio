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

    /// The rule pools are named arrays (`let ruleWeights: [Double] = [...]`, often over several
    /// lines, or one array per substyle behind `? :`), which the test above cannot see. The Noir
    /// Rhythm pool summed to 1.02 for weeks that way (found 2026-11-11). This reads every
    /// assignment to a name ending in "weights" and checks each all-number array after it, through
    /// every branch of a `? :`. Arrays with arithmetic (`1.0 / 6.0`) or built at runtime are skipped.
    @Test func namedWeightPoolsSumToOne() throws {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: Self.sourceRoot, includingPropertiesForKeys: nil) else {
            Issue.record("could not read Sources"); return
        }
        let assign = try NSRegularExpression(pattern: #"[wW]eights\s*(?::\s*\[Double\])?\s*=(?!=)"#)
        var checked = 0

        for case let url as URL in walker where url.pathExtension == "swift" {
            // Comments stripped, so a note inside a multi-line array does not hide it.
            let text = try String(contentsOf: url, encoding: .utf8)
                .replacingOccurrences(of: #"//[^\n]*"#, with: "", options: .regularExpression)
            let ns = text as NSString
            for m in assign.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                var pos = m.range.location + m.range.length
                var first = true
                while true {
                    let open = ns.range(of: "[", range: NSRange(location: pos, length: ns.length - pos))
                    guard open.location != NSNotFound else { break }
                    // Between arrays only a condition and `?` or `:` may appear.
                    let between = ns.substring(with: NSRange(location: pos, length: open.location - pos))
                    if between.contains(where: { "=;{},".contains($0) }) { break }
                    if !first && !between.contains(where: { $0 == "?" || $0 == ":" }) { break }
                    let close = ns.range(of: "]", range: NSRange(location: open.location, length: ns.length - open.location))
                    guard close.location != NSNotFound else { break }
                    let body = ns.substring(with: NSRange(location: open.location + 1,
                                                          length: close.location - open.location - 1))
                    let items = body.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    let values = items.compactMap(Double.init)
                    guard values.count == items.count, values.count > 1 else { break }
                    checked += 1
                    let total = values.reduce(0, +)
                    let line = ns.substring(to: open.location).filter { $0 == "\n" }.count + 1
                    #expect(abs(total - 1.0) < 0.001,
                            Comment(rawValue: "\(url.lastPathComponent):\(line) weights sum to "
                                  + String(format: "%g", total) + ", not 1"))
                    pos = close.location + 1
                    first = false
                }
            }
        }
        #expect(checked > 60, "expected to find the rule pools; found \(checked)")
    }
}
