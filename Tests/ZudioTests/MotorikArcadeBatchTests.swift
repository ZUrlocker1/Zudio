// MotorikArcadeBatchTests.swift — Motorik Arcade batch generator + analyser.
//
// Run with:  swift test --filter MotorikArcadeBatchTests
// Output:    ~/Downloads/Zudio/tools/batch-output/motorik-arcade/

import Testing
import Foundation
@testable import Zudio

struct MotorikArcadeBatchTests {

    private static var batchDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio/tools/batch-output/motorik-arcade")
    }

    @Test func generateMotorikArcadeBatch() throws {
        let dir = Self.batchDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in existing where ["mid", "MID", "zudio"].contains(url.pathExtension) { try? fm.removeItem(at: url) }

        print("\n══════════════════════════════════════════════════")
        print("  MOTORIK ARCADE BATCH ANALYSIS — 20 songs")
        print("══════════════════════════════════════════════════\n")
        print("Output: \(dir.path)\n")

        var instOverrides: [Int: Int] = [:]
        var instLastUsed:  [Int: [MusicStyle: Int]] = [:]

        // Summary accumulators
        var modeCounts     = [String: Int]()
        var ld1RuleCounts  = [String: Int]()
        var ld2RuleCounts  = [String: Int]()
        var bassRuleCounts = [String: Int]()
        var drumRuleCounts = [String: Int]()
        var drumInstCounts = [String: Int]()
        var ld2InstCounts  = [String: Int]()
        var formCounts     = [String: Int]()
        var bpmValues         = [Int]()
        var barValues         = [Int]()
        var ld1CoverageValues = [Double]()
        var ld2RatioValues    = [Double]()
        var ld1FirstBarValues = [Int]()
        var ld1MaxRunValues   = [Int]()
        var ld2MaxRunValues   = [Int]()
        var silentRunValues   = [Int]()
        var chordWindowLens   = [Int]()    // all body chord windows across all songs
        var songsArpLd2 = 0; var songsArpLd1 = 0; var songsBothArp = 0
        var instWarnings = 0
        var allWarnings: [(song: Int, msg: String)] = []

        let arcadeArpLd2: Set<String> = ["MOT-LD2-007", "MOT-LD2-008", "MOT-LD2-009"]
        let arcadeArpLd1: Set<String> = ["MOT-LD1-018", "MOT-LD1-017", "MOT-LD1-019"]

        // ── Helpers ─────────────────────────────────────────────────────────────
        func maxFingerprintRun(_ events: [MIDIEvent], introEnd: Int, outroStart: Int) -> Int {
            var barFP = [Int: Set<UInt8>]()
            for ev in events {
                let bar = ev.stepIndex / 16
                guard bar >= introEnd && bar < outroStart else { continue }
                barFP[bar, default: []].insert(ev.note % 12)
            }
            let active = barFP.keys.sorted()
            guard !active.isEmpty else { return 0 }
            var maxRun = 1; var cur = 1; var prev: Set<UInt8>? = nil
            for bar in active {
                let fp = barFP[bar]!
                if fp == prev { cur += 1; maxRun = max(maxRun, cur) } else { cur = 1; prev = fp }
            }
            return maxRun
        }

        func maxSilentRun(_ ld1: [MIDIEvent], _ ld2: [MIDIEvent], introEnd: Int, outroStart: Int) -> Int {
            var activeBars = Set<Int>()
            for ev in ld1 + ld2 {
                let bar = ev.stepIndex / 16
                if bar >= introEnd && bar < outroStart { activeBars.insert(bar) }
            }
            var maxRun = 0; var cur = 0
            for bar in introEnd..<outroStart {
                if activeBars.contains(bar) { cur = 0 } else { cur += 1; maxRun = max(maxRun, cur) }
            }
            return maxRun
        }

        func ld1CoveragePerWindow(_ events: [MIDIEvent], windows: [ChordWindow]) -> [(bars: Int, covPct: Double)] {
            var result = [(bars: Int, covPct: Double)]()
            for w in windows {
                var present = Set<Int>()
                for ev in events {
                    let bar = ev.stepIndex / 16
                    if bar >= w.startBar && bar < w.startBar + w.lengthBars { present.insert(bar) }
                }
                let pct = w.lengthBars > 0 ? Double(present.count) / Double(w.lengthBars) * 100.0 : 0.0
                result.append((bars: w.lengthBars, covPct: pct))
            }
            return result
        }

        var i = 0; var attempts = 0
        while i < 20 {
            attempts += 1
            guard attempts < 300 else { print("⚠ Reached 300 attempts."); break }
            let seed = UInt64.random(in: .min ... .max)
            let song = SongGenerator.generate(seed: seed, style: .motorik)
            guard song.motorikArcadeVariation else { continue }
            i += 1

            // Export
            let seedHex = String(format: "%016llx", seed)
            let midiURL = dir.appendingPathComponent(String(format: "arcade_%02d_%@.MID", i, seedHex))
            try MIDIFileExporter.export(song, to: midiURL)
            try SongLogExporter.export(song, midiURL: midiURL)

            // Instrument selection
            AppState.selectInstrumentsForSong(state: song, isFirstForStyle: i == 1,
                overrides: &instOverrides, lastUsed: &instLastUsed)

            let drumPool = AppState.instrumentPoolNames(trackIndex: kTrackDrums,  style: .motorik)
            let bassPool = AppState.instrumentPoolNames(trackIndex: kTrackBass,   style: .motorik)
            let ld1Pool  = AppState.instrumentPoolNames(trackIndex: kTrackLead1,  style: .motorik)
            let ld2Pool  = AppState.instrumentPoolNames(trackIndex: kTrackLead2,  style: .motorik)
            let rhtmPool = AppState.instrumentPoolNames(trackIndex: kTrackRhythm, style: .motorik)
            func instName(_ pool: [String], _ track: Int) -> String {
                let idx = instOverrides[track] ?? 0; return idx < pool.count ? pool[idx] : "idx\(idx)?"
            }
            let drumName = instName(drumPool, kTrackDrums)
            let ld1Name  = instName(ld1Pool,  kTrackLead1)
            let ld2Name  = instName(ld2Pool,  kTrackLead2)
            let bassName = instName(bassPool,  kTrackBass)
            let rhtmName = instName(rhtmPool,  kTrackRhythm)

            // Rule IDs
            let ld1Rule  = song.generationLog.first { $0.tag.hasPrefix("MOT-LD1-")  }?.tag ?? "?"
            let ld2Rule  = song.generationLog.first { $0.tag.hasPrefix("MOT-LD2-")  }?.tag ?? "?"
            let bassRule = song.generationLog.first { $0.tag.hasPrefix("MOT-BASS-") }?.tag ?? "?"
            let drumRule = song.generationLog.first { $0.tag.hasPrefix("MOT-DRUM-") }?.tag ?? "?"
            let rhtmRule = song.generationLog.first { $0.tag.hasPrefix("MOT-RTHM-") }?.tag ?? "?"

            // Body / section info
            let introEnd   = song.structure.sections.first { $0.label == .intro }.map { $0.startBar + $0.lengthBars } ?? 0
            let outroStart = song.structure.sections.first { $0.label == .outro }?.startBar ?? song.frame.totalBars
            let bodyBars   = outroStart - introEnd
            let hasBSection = song.structure.bodySections.contains { $0.label == .B }
            let formLabel  = hasBSection ? "A/B" : "A"
            let aSectionBars = song.structure.bodySections.filter { $0.label == .A }.reduce(0) { $0 + $1.lengthBars }
            let bSectionBars = song.structure.bodySections.filter { $0.label == .B }.reduce(0) { $0 + $1.lengthBars }

            // Chord windows in body (exclude intro/outro)
            let bodyWindows = song.structure.chordPlan.filter { w in
                song.structure.sections.contains { s in s.label != .intro && s.label != .outro && w.startBar >= s.startBar && w.startBar < s.startBar + s.lengthBars }
            }
            for w in bodyWindows { chordWindowLens.append(w.lengthBars) }
            let maxChordWindow = bodyWindows.map { $0.lengthBars }.max() ?? 0

            // Lead events
            let ld1Events = song.trackEvents[kTrackLead1]
            let ld2Events = song.trackEvents[kTrackLead2]

            // Lead 1 first bar (1-indexed)
            let ld1FirstBar: Int = {
                guard let first = ld1Events.min(by: { $0.stepIndex < $1.stepIndex }) else { return -1 }
                return first.stepIndex / 16 + 1
            }()

            // Lead 1 body coverage
            var ld1BodyBars = Set<Int>()
            for ev in ld1Events { let b = ev.stepIndex/16; if b >= introEnd && b < outroStart { ld1BodyBars.insert(b) } }
            let ld1Coverage = bodyBars > 0 ? Double(ld1BodyBars.count) / Double(bodyBars) * 100.0 : 0.0

            // L2/L1 note ratio
            let ld1Count = ld1Events.count; let ld2Count = ld2Events.count
            let ld2Ratio = ld1Count > 0 ? Double(ld2Count) / Double(ld1Count) : 99.0

            // Repetitiveness
            let ld1MaxRun    = maxFingerprintRun(ld1Events, introEnd: introEnd, outroStart: outroStart)
            let ld2MaxRun    = maxFingerprintRun(ld2Events, introEnd: introEnd, outroStart: outroStart)
            let silentMaxRun = maxSilentRun(ld1Events, ld2Events, introEnd: introEnd, outroStart: outroStart)

            // Per-chord-window Lead 1 coverage (body windows only)
            let windowCov = ld1CoveragePerWindow(ld1Events, windows: bodyWindows)
            let missedWindows = windowCov.filter { $0.covPct < 10.0 && $0.bars >= 8 }

            // ARP flags
            let hasArpLd2 = arcadeArpLd2.contains(ld2Rule)
            let hasArpLd1 = arcadeArpLd1.contains(ld1Rule)

            // Instrument correctness
            let drumIdx = instOverrides[kTrackDrums] ?? 0
            let ld2Idx  = instOverrides[kTrackLead2] ?? 0
            let bassIdx = instOverrides[kTrackBass]  ?? 0
            let ld1Idx  = instOverrides[kTrackLead1] ?? 0
            let rhtmIdx = instOverrides[kTrackRhythm] ?? 0

            var warnings = [String]()
            if ![2, 3].contains(drumIdx)            { warnings.append("⚠  DRUM idx=\(drumIdx) (\(drumName)) — not in Arcade pool [2,3]"); instWarnings += 1 }
            if ![2, 5, 7].contains(ld2Idx)          { warnings.append("⚠  LD2 idx=\(ld2Idx) (\(ld2Name)) — not in Arcade pool [2,5,7]"); instWarnings += 1 }
            if ![1, 3, 4, 5, 6].contains(bassIdx)  { warnings.append("⚠  BASS idx=\(bassIdx) (\(bassName)) — not in Arcade pool [1,3,4,5,6]"); instWarnings += 1 }
            if ![0, 1, 6, 7].contains(ld1Idx)      { warnings.append("⚠  LD1 idx=\(ld1Idx) (\(ld1Name)) — not in Arcade pool [0,1,6,7]"); instWarnings += 1 }
            if ![0, 6, 9, 10].contains(rhtmIdx)    { warnings.append("⚠  RTHM idx=\(rhtmIdx) (\(rhtmName)) — not in Arcade pool [0,6,9,10]"); instWarnings += 1 }

            if ld1FirstBar > 12  { warnings.append("⚠  L1 first note bar \(ld1FirstBar) — exceeds bar-12 cap") }
            if ld1Coverage < 20  { warnings.append("⚠  L1 body coverage \(String(format:"%.0f",ld1Coverage))% — very sparse") }
            if ld2Ratio > 3.5    { warnings.append("⚠  L2/L1 ratio \(String(format:"%.1f",ld2Ratio))x — Lead 2 dominates") }
            if hasArpLd2 && hasArpLd1 { warnings.append("⚠  Both L1+L2 arp rules — may feel over-arped") }
            if ld1MaxRun >= 8    { warnings.append("⚠  L1 pitch-class run \(ld1MaxRun) bars") }
            if ld2MaxRun >= 8    { warnings.append("⚠  L2 pitch-class run \(ld2MaxRun) bars") }
            if silentMaxRun >= 8 { warnings.append("⚠  Both leads silent for \(silentMaxRun) bars") }
            if maxChordWindow > 24 { warnings.append("⚠  Chord window \(maxChordWindow) bars — very long") }
            if !missedWindows.isEmpty { warnings.append("⚠  L1 absent from \(missedWindows.count) chord window(s) ≥8 bars") }

            // Accumulate
            modeCounts[song.frame.mode.rawValue, default: 0]  += 1
            ld1RuleCounts[ld1Rule, default: 0]  += 1
            ld2RuleCounts[ld2Rule, default: 0]  += 1
            bassRuleCounts[bassRule, default: 0] += 1
            drumRuleCounts[drumRule, default: 0] += 1
            drumInstCounts[drumName, default: 0] += 1
            ld2InstCounts[ld2Name, default: 0]   += 1
            formCounts[formLabel, default: 0]    += 1
            bpmValues.append(song.frame.tempo)
            barValues.append(song.frame.totalBars)
            ld1CoverageValues.append(ld1Coverage)
            ld2RatioValues.append(ld2Ratio)
            ld1FirstBarValues.append(ld1FirstBar)
            ld1MaxRunValues.append(ld1MaxRun)
            ld2MaxRunValues.append(ld2MaxRun)
            silentRunValues.append(silentMaxRun)
            if hasArpLd2 { songsArpLd2 += 1 }
            if hasArpLd1 { songsArpLd1 += 1 }
            if hasArpLd2 && hasArpLd1 { songsBothArp += 1 }
            for w in warnings { allWarnings.append((song: i, msg: w)) }

            // Per-song output
            let modeStr  = song.frame.mode.rawValue
            let modeFlag = ["Lydian","Mixolydian"].contains(modeStr) ? "✓" : "~"
            let arpFlag  = (hasArpLd2 ? "L2-arp " : "") + (hasArpLd1 ? "L1-arp" : "")
            let formDetail = hasBSection ? "A/B  A=\(aSectionBars)b B=\(bSectionBars)b" : "A    A=\(aSectionBars)b"
            let windowStr = bodyWindows.map { "\($0.lengthBars)b" }.joined(separator: "/")

            print("─── \(String(format:"%02d",i)). \(song.title.padding(toLength:20,withPad:" ",startingAt:0))  \(song.frame.key) \(modeStr) \(modeFlag)  \(song.frame.tempo)bpm  \(song.frame.totalBars)bars")
            print("    Rules:   LD1=\(ld1Rule)  LD2=\(ld2Rule)  BASS=\(bassRule)  DRUM=\(drumRule)  RTHM=\(rhtmRule)")
            print("    Instr:   L1=\(ld1Name.padding(toLength:14,withPad:" ",startingAt:0))  L2=\(ld2Name.padding(toLength:14,withPad:" ",startingAt:0))  Ry=\(rhtmName.padding(toLength:14,withPad:" ",startingAt:0))  Bs=\(bassName.padding(toLength:14,withPad:" ",startingAt:0))  Dr=\(drumName)")
            print("    Form:    \(formDetail)  chords=[\(windowStr)]")
            print("    Melody:  L1-first=bar\(ld1FirstBar < 0 ? " N/A" : String(format:"%3d",ld1FirstBar))  cov=\(String(format:"%3.0f",ld1Coverage))%  L2/L1=\(String(format:"%.1f",ld2Ratio))x")
            print("    Repeat:  L1-run=\(ld1MaxRun)b  L2-run=\(ld2MaxRun)b  both-silent=\(silentMaxRun)b  \(arpFlag.isEmpty ? "no-arp" : arpFlag)")
            for w in warnings { print("    \(w)") }
            print()
        }

        // ── Summary ──────────────────────────────────────────────────────────────
        func avgI(_ a: [Int])    -> String { a.isEmpty ? "n/a" : String(format:"%.1f", Double(a.reduce(0,+))/Double(a.count)) }
        func avgD(_ a: [Double]) -> String { a.isEmpty ? "n/a" : String(format:"%.1f", a.reduce(0,+)/Double(a.count)) }
        func hist(_ d: [String:Int]) -> String { d.sorted{$0.value>$1.value}.map{"\($0.key):\($0.value)"}.joined(separator:"  ") }
        let n = i

        print("════════════════════════════════════════════════════════════")
        print("SUMMARY — \(n) Arcade songs generated (\(attempts) total draws)\n")

        print("▸ DISTINCTIVENESS")
        let majorPct = Double((modeCounts["Lydian"] ?? 0) + (modeCounts["Mixolydian"] ?? 0)) / Double(n) * 100
        print("  Modes:          \(hist(modeCounts))")
        print("  Lydian+Mixo:    \(String(format:"%.0f",majorPct))%  (target ~80%)")
        print("  BPM:            avg=\(avgI(bpmValues))  range=\(bpmValues.min()!)-\(bpmValues.max()!)  (target 130–165)")
        print("  Bars:           avg=\(avgI(barValues))  range=\(barValues.min()!)-\(barValues.max()!)  (target 80–120)")
        print("  Forms:          \(hist(formCounts))  (target A/B dominant)")
        print("  LD1 rules:      \(hist(ld1RuleCounts))")
        print("  LD2 rules:      \(hist(ld2RuleCounts))")
        print("  Bass rules:     \(hist(bassRuleCounts))")
        print("  Drum rules:     \(hist(drumRuleCounts))")
        print()

        print("▸ ARP SATURATION")
        print("  L2 Arcade arp (007/008/009): \(songsArpLd2)/\(n) (\(String(format:"%.0f",Double(songsArpLd2)/Double(n)*100))%)")
        print("  L1 arp-adjacent (017/018):   \(songsArpLd1)/\(n) (\(String(format:"%.0f",Double(songsArpLd1)/Double(n)*100))%)")
        print("  Both L1+L2 arp:              \(songsBothArp)/\(n) (\(String(format:"%.0f",Double(songsBothArp)/Double(n)*100))%)")
        print("  LD2 instruments:  \(hist(ld2InstCounts))")
        print()

        print("▸ MELODIC QUALITY")
        print("  L1 avg first bar:   \(avgD(ld1FirstBarValues.map{Double($0)}))  (≤12 = good)")
        print("  L1 avg coverage:    \(avgD(ld1CoverageValues))%")
        print("  Avg L2/L1 ratio:    \(avgD(ld2RatioValues))x  (1–2 = balanced)")
        print()

        print("▸ REPETITIVENESS")
        print("  L1 max run — avg: \(avgD(ld1MaxRunValues.map{Double($0)}))b  worst: \(ld1MaxRunValues.max() ?? 0)b  (≥8 = concern)")
        print("  L2 max run — avg: \(avgD(ld2MaxRunValues.map{Double($0)}))b  worst: \(ld2MaxRunValues.max() ?? 0)b")
        print("  Both-silent run — avg: \(avgD(silentRunValues.map{Double($0)}))b  worst: \(silentRunValues.max() ?? 0)b  (≥8 = concern)")
        let longWindows = chordWindowLens.filter { $0 > 24 }
        print("  Chord windows >24b: \(longWindows.count) of \(chordWindowLens.count)  (longest: \(chordWindowLens.max() ?? 0)b)")
        print("  L1 run dist: <4b=\(ld1MaxRunValues.filter{$0<4}.count)  4–7b=\(ld1MaxRunValues.filter{$0>=4 && $0<8}.count)  ≥8b=\(ld1MaxRunValues.filter{$0>=8}.count)")
        print("  L2 run dist: <4b=\(ld2MaxRunValues.filter{$0<4}.count)  4–7b=\(ld2MaxRunValues.filter{$0>=4 && $0<8}.count)  ≥8b=\(ld2MaxRunValues.filter{$0>=8}.count)")
        print()

        print("▸ INSTRUMENTS")
        print("  Drum kits:  \(hist(drumInstCounts))  (valid: Dance Drums, Machine Kit)")
        print("  Instrument warnings: \(instWarnings)")
        print()

        if allWarnings.isEmpty {
            print("▸ WARNINGS: none")
        } else {
            print("▸ WARNINGS (\(allWarnings.count) total)")
            for w in allWarnings { print("  Song \(w.song): \(w.msg)") }
        }
        print()
        print("✓ Done. Files: \(dir.path)")
        print("════════════════════════════════════════════════════════════")
    }
}
