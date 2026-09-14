// SongRepeatAnalysisTest.swift — one-shot repetition analysis for a specific song seed.
// Run with: swift test --filter SongRepeatAnalysisTest

import Testing
import Foundation
@testable import Zudio

struct SongRepeatAnalysisTest {

    @Test func analyseBDrive() throws {
        try analyse(seed: 7454725748545204366,
                    ld1Label: "Lead 1 (MOT-LD1-015 Arcade Riff)",
                    ld2Label: "Lead 2 (MOT-LD2-008 Gate Arp)")
    }

    @Test func analyseDarkMittelwerk() throws {
        try analyse(seed: 11467076224229823064,
                    ld1Label: "Lead 1 (MOT-LD1-017 Pentatonic Blitz)",
                    ld2Label: "Lead 2 (MOT-LD2-008 Gate Arp)")
    }

    private func analyse(seed: UInt64, ld1Label: String, ld2Label: String) throws {
        let song = SongGenerator.generate(seed: seed, style: .motorik)
        let introEnd   = song.structure.sections.first(where: { $0.label == .intro })?.endBar ?? 0
        let outroStart = song.structure.sections.first(where: { $0.label == .outro })?.startBar
                         ?? song.structure.sections.last!.endBar

        print("\n══════════════════════════════════════════════════")
        print("  REPEAT ANALYSIS: \(song.title)")
        print("  \(song.frame.key) \(song.frame.mode.rawValue)  \(song.frame.tempo) BPM  \(song.frame.totalBars) bars")
        print("  Body: bars \(introEnd + 1)–\(outroStart)")
        print("══════════════════════════════════════════════════\n")

        analyseTrack(song.trackEvents[kTrackLead1], label: ld1Label, introEnd: introEnd, outroStart: outroStart)
        analyseTrack(song.trackEvents[kTrackLead2], label: ld2Label, introEnd: introEnd, outroStart: outroStart)
    }

    private func analyseTrack(_ events: [MIDIEvent], label: String, introEnd: Int, outroStart: Int) {
        var barFP: [Int: Set<UInt8>] = [:]
        for ev in events {
            let bar = ev.stepIndex / 16
            guard bar >= introEnd && bar < outroStart else { continue }
            barFP[bar, default: []].insert(ev.note % 12)
        }
        let activeBars = barFP.keys.sorted()
        guard !activeBars.isEmpty else { print("\(label): no notes in body\n"); return }

        struct Run { var fp: Set<UInt8>; var startBar: Int; var length: Int }
        var runs: [Run] = []
        var currentFP = barFP[activeBars[0]]!
        var runStart  = activeBars[0]
        var runLen    = 1
        for idx in 1..<activeBars.count {
            let bar = activeBars[idx]
            let fp  = barFP[bar]!
            if fp == currentFP { runLen += 1 }
            else { runs.append(Run(fp: currentFP, startBar: runStart, length: runLen)); currentFP = fp; runStart = bar; runLen = 1 }
        }
        runs.append(Run(fp: currentFP, startBar: runStart, length: runLen))

        let maxRun = runs.map { $0.length }.max() ?? 0
        let noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        print("\(label) — \(runs.count) distinct patterns, longest run: \(maxRun) bars")
        print(String(repeating: "─", count: 52))
        for r in runs {
            let pcs  = r.fp.sorted().map { noteNames[Int($0)] }.joined(separator: " ")
            let flag = r.length >= 8 ? " ⚠" : r.length >= 4 ? " ·" : ""
            print(String(format: "  bars %3d–%3d  (%2d bars)  [%@]%@",
                         r.startBar + 1, r.startBar + r.length, r.length, pcs, flag))
        }
        print()
    }
}
