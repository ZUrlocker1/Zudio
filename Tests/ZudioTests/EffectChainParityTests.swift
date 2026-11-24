// EffectChainParityTests.swift — keeps the three effect chains in sync.
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/EffectChainParityTests
//
// WHY THIS EXISTS
// ---------------
// The same effect chain used to be built in three places: PlaybackEngine (live), OfflineExport
// Phase 2 (the M4A mix) and Phase 3 (the stems). Phases 2 and 3 now share one ExportTrackChain,
// so only live and export remain to keep in step; the audio texture still has a copy in each
// phase. Nothing forces them to agree, and in Build 128 (commit 8a73f5b) they silently
// diverged: the Air effect was tuned up to a two-band shape (4 kHz presence peak +
// 8 kHz high shelf) in PlaybackEngine and Phase 2, but the Phase 3 copy was left on
// the original single 12 kHz +3.5 dB shelf. Air-enabled Motorik stems therefore
// exported far duller than the same song's mix, with nothing to flag it.
//
// These tests parse the source directly rather than the built nodes, because the
// chains are constructed inside long engine-setup functions that cannot be invoked
// in isolation. It is a blunt instrument, but it catches exactly the drift that bit us.

import Testing
import Foundation

struct EffectChainParityTests {

    // MARK: - Source loading

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ZudioTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Phase 2 builds every track at once and holds nodes in arrays; Phase 3 builds one
    /// track at a time with scalar locals. Same parameter, different spelling — fold them
    /// together so the comparison is about values, not local variable style.
    private static let alias = [
        "sweepNodes": "sweep",
        "tremoloGains": "tremoloGain",
        "vibratoNodes": "vibratoNode",
    ]

    private static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).map { m in
            (0..<m.numberOfRanges).map { i in
                Range(m.range(at: i), in: text).map { String(text[$0]) } ?? ""
            }
        }
    }

    /// Strips comments, collapses whitespace, and returns the effect-parameter
    /// assignments in a normalized, order-independent form.
    private static func effectParameters(of text: String) -> [String] {
        var flat = text.replacingOccurrences(of: "//[^\n]*", with: " ",
                                             options: .regularExpression)
        flat = flat.replacingOccurrences(of: "\\s+", with: " ",
                                         options: .regularExpression)

        var out: [String] = []

        // AudioUnitSetParameter(node.audioUnit, <index>, <scope>, 0, <value>, 0)
        for m in matches(#"AudioUnitSetParameter\(\s*(\w+)(?:\[i\])?\.audioUnit,\s*(\d+),[^,]*,\s*\d+,\s*([^,]+?),\s*0\s*\)"#, in: flat) {
            let node = alias[m[1]] ?? m[1]
            out.append("\(node)[\(m[2])]=\(m[3].trimmingCharacters(in: .whitespaces))")
        }

        // node.bands[i].property = value
        for m in matches(#"(\w+)\.bands\[(\d)\]\.(\w+)\s*=\s*([^\s;]+)"#, in: flat) {
            let node = alias[m[1]] ?? m[1]
            out.append("\(node).bands[\(m[2])].\(m[3])=\(m[4])")
        }

        return out.sorted()
    }

    private static func region(_ text: String, from: String, to: String?) -> String {
        guard let start = text.range(of: from) else { return "" }
        let tail = text[start.lowerBound...]
        guard let to, let end = tail.range(of: to) else { return String(tail) }
        return String(tail[..<end.lowerBound])
    }

    // MARK: - Phase 2 vs Phase 3

    @Test func exportPhasesUseIdenticalEffectParameters() throws {
        let src = try Self.source("Sources/Zudio/Assets/OfflineExport.swift")

        let phase2 = Self.region(src, from: "MARK: Phase 2", to: "MARK: Phase 3")
        let phase3 = Self.region(src, from: "MARK: Phase 3", to: "MARK: - One track's effect chain")

        #expect(!phase2.isEmpty, "Could not locate the Phase 2 marker in OfflineExport.swift")
        #expect(!phase3.isEmpty, "Could not locate the Phase 3 marker in OfflineExport.swift")

        let p2 = Self.effectParameters(of: phase2)
        let p3 = Self.effectParameters(of: phase3)

        #expect(!p2.isEmpty, "Extracted no effect parameters from Phase 2 — did the chain move?")

        let onlyIn2 = Set(p2).subtracting(p3).sorted()
        let onlyIn3 = Set(p3).subtracting(p2).sorted()

        #expect(onlyIn2.isEmpty && onlyIn3.isEmpty,
                """
                The main-mix (Phase 2) and stem (Phase 3) effect chains have drifted apart.
                Only in Phase 2 (main mix): \(onlyIn2)
                Only in Phase 3 (stems):    \(onlyIn3)
                Both render the same song and must apply identical effects.
                """)
    }

    // MARK: - Air: live vs both export phases
    //
    // The specific regression from Build 128, pinned across all three chains.

    /// The Air bands as set for every style but Ambient: `gentleAir ? A : B` reads as B and a bare
    /// `= gentleAir` as false. Ambient's gentler values are compared in `ambientAirMatches...`.
    private static func airBands(of text: String) -> [String] {
        let normal = text
            .replacingOccurrences(of: #"gentleAir\s*\?\s*[\d.]+\s*:\s*([\d.]+)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"=\s*gentleAir\b"#, with: "= false", options: .regularExpression)
        return effectParameters(of: normal).filter { $0.hasPrefix("airEQ.bands[") }
    }

    @Test func ambientAirMatchesAcrossPlaybackAndExport() throws {
        let engineSrc = try Self.source("Sources/Zudio/Playback/PlaybackEngine.swift")
        let exportSrc = try Self.source("Sources/Zudio/Assets/OfflineExport.swift")
        // Live: `gentleAir ? 10000 : 8000` and `gentleAir ? 3.5 : 7.5`, in the same order as export.
        let pattern = #"gentleAir\s*\?\s*([\d.]+)\s*:\s*([\d.]+)"#
        let live   = Self.matches(pattern, in: engineSrc).map { Array($0[1...2]) }
        let export = Self.matches(pattern, in: exportSrc).map { Array($0[1...2]) }
        #expect(!live.isEmpty && live == export, "Ambient Air: live \(live) vs export \(export)")
    }

    @Test func airMatchesAcrossPlaybackAndExport() throws {
        let engineSrc = try Self.source("Sources/Zudio/Playback/PlaybackEngine.swift")
        let exportSrc = try Self.source("Sources/Zudio/Assets/OfflineExport.swift")

        let live  = Self.airBands(of: engineSrc)
        let chain = Self.airBands(of: Self.region(exportSrc, from: "private final class ExportTrackChain",
                                                  to: "MARK: - Chill Pads fade envelope"))

        #expect(!live.isEmpty, "Found no airEQ band settings in PlaybackEngine")
        #expect(live == chain, "Live Air \(live) differs from the export chain's Air \(chain)")
    }

    // MARK: - Export builds each track through the one chain

    @Test func exportPhasesBuildTracksThroughTheSharedChain() throws {
        let src = try Self.source("Sources/Zudio/Assets/OfflineExport.swift")
        let phase2 = Self.region(src, from: "MARK: Phase 2", to: "MARK: Phase 3")
        let phase3 = Self.region(src, from: "MARK: Phase 3", to: "// Texture stem")

        for (name, text) in [("Phase 2", phase2), ("Phase 3", phase3)] {
            #expect(text.contains("ExportTrackChain("), "\(name) must build tracks with ExportTrackChain")
            #expect(!text.contains("AVAudioUnitDelay()") && !text.contains("airEQ"),
                    "\(name) builds its own track effects; they belong in ExportTrackChain")
        }
    }

    // MARK: - Timed automation is shared, not copied

    @Test func playbackTimersUseTheSharedCurves() throws {
        let engineSrc = try Self.source("Sources/Zudio/Playback/PlaybackEngine.swift")
        #expect(engineSrc.contains("MixAutomation.tideCutoff("), "Live tides must use MixAutomation.tideCutoff")
        #expect(engineSrc.contains("MixAutomation.fastSweepCutoff("), "Live sweeps must use MixAutomation.fastSweepCutoff")
        #expect(engineSrc.contains("MixAutomation.drumFire("), "Live drums must use MixAutomation.drumFire")
        #expect(!engineSrc.contains("let closed = ramp * ramp"), "A copy of the tide curve is back in PlaybackEngine")
    }
}
