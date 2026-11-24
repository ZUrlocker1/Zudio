// MixAutomationTests.swift — the timed changes playback and export share.
//
// Run with:
//   swift test --filter MixAutomationTests
//
// MixAutomation holds the curves both the live timers and the offline export read, so a change to
// one is a change to the other. These tests pin the curves and check a generated song's schedule.

import Testing
import Foundation
@testable import Zudio

@Suite struct MixAutomationTests {

    @Test func tideOutClosesHoldsAndReopens() {
        #expect(MixAutomation.tideCutoff(progress: 0, tideIn: false) == 6000)
        #expect(abs(MixAutomation.tideCutoff(progress: 0.5, tideIn: false) - MixAutomation.tideFloorHz) < 0.5)
        #expect(abs(MixAutomation.tideCutoff(progress: 1, tideIn: false) - 6000) < 0.5)
    }

    @Test func tideInIsDarkAtOnceThenBrightens() {
        #expect(abs(MixAutomation.tideCutoff(progress: 0.15, tideIn: true) - MixAutomation.tideFloorHz) < 0.5)
        #expect(MixAutomation.tideCutoff(progress: 0.65, tideIn: true) > MixAutomation.tideCutoff(progress: 0.4, tideIn: true))
        #expect(abs(MixAutomation.tideCutoff(progress: 1, tideIn: true) - 6000) < 0.5)
    }

    @Test func fastSweepStartsOpenAndClosesToTheFloor() {
        #expect(abs(MixAutomation.fastSweepCutoff(phase: .pi / 2) - 6000) < 0.5)
        #expect(abs(MixAutomation.fastSweepCutoff(phase: 3 * .pi / 2) - 300) < 0.5)
    }

    @Test func drumKitsMapTheirTomsAndScaleVelocity() {
        // 808 Kit: low tom to kick, hi tom to open hat, native notes untouched.
        let tom = MixAutomation.drumFire(note: 41, velocity: 90, program: 25, kosmicSpace: false, kosmicDrift: false, buddhaPulse: false)
        #expect(tom.note == GMDrum.kick.rawValue && tom.velocity == 90)
        let hi = MixAutomation.drumFire(note: 50, velocity: 90, program: 25, kosmicSpace: false, kosmicDrift: false, buddhaPulse: false)
        #expect(hi.note == GMDrum.openHat.rawValue)
        // Machine Kit: native notes at 88%, remapped toms at full velocity; Space keeps its toms.
        let kick = MixAutomation.drumFire(note: 36, velocity: 100, program: 24, kosmicSpace: false, kosmicDrift: false, buddhaPulse: false)
        #expect(kick.note == 36 && kick.velocity == 88)
        let machineTom = MixAutomation.drumFire(note: 45, velocity: 78, program: 24, kosmicSpace: false, kosmicDrift: false, buddhaPulse: false)
        #expect(machineTom.note == GMDrum.snare.rawValue && machineTom.velocity == 78)
        let spaceTom = MixAutomation.drumFire(note: 45, velocity: 78, program: 24, kosmicSpace: true, kosmicDrift: false, buddhaPulse: false)
        #expect(spaceTom.note == 45)
        // Kosmic Drift's standard-kit snare at 65%.
        let drift = MixAutomation.drumFire(note: GMDrum.snare.rawValue, velocity: 100, program: 0, kosmicSpace: false, kosmicDrift: true, buddhaPulse: false)
        #expect(drift.velocity == 65)
    }

    @Test func ambientSongFadesOutAndSchedulesItsTides() {
        for seed in UInt64(1)...UInt64(12) {
            let song = SongGenerator.generate(seed: seed &* 0x9E3779B97F4A7C15, style: .ambient)
            let sps = song.frame.secondsPerStep
            let end = Double(song.frame.totalBars * 16) * sps
            #expect(MixAutomation.masterGain(for: song, at: 1) == 1)
            #expect(MixAutomation.masterGain(for: song, at: end) < 0.01)
            // The schedule is the generator's own, step for step.
            let steps = AmbientAutoTide.steps(for: song)
            let sweeps = MixAutomation.filterSweeps(for: song)
            #expect(sweeps.map { Int(($0.start / sps).rounded()) } == steps)
            if song.isAmbientPiano { #expect(sweeps.isEmpty) }
        }
    }

    @Test func kosmicDroneFadesInAndOut() {
        for seed in UInt64(1)...UInt64(12) {
            let song = SongGenerator.generate(seed: seed &* 0x9E3779B97F4A7C15, style: .kosmic)
            guard let intro = song.structure.introSection else { continue }
            let sps = song.frame.secondsPerStep
            let bass = MixAutomation.trackGain(for: song, track: kTrackBass)
            #expect(bass != nil)
            #expect((bass?(0) ?? 1) < 0.2)
            #expect((bass?(Double(intro.endBar * 16) * sps) ?? 0) == 1)
            // Nothing else changes the master.
            #expect(MixAutomation.masterGain(for: song, at: 0) == 1)
        }
    }

    /// Evolve's pass-boundary sweeps are passed in by the caller and join the song's own, once each.
    @Test func evolveBoundarySweepsJoinTheKosmicSchedule() {
        let song = SongGenerator.generate(seed: 7 &* 0x9E3779B97F4A7C15, style: .kosmic)
        let sps = song.frame.secondsPerStep
        let own = MixAutomation.filterSweeps(for: song)
        let extra = [(song.frame.totalBars + 8) * 16, (song.frame.totalBars + 8) * 16]   // a duplicate collapses
        let all = MixAutomation.filterSweeps(for: song, extraSteps: extra)
        #expect(all.count == own.count + 1)
        #expect(all.contains { abs($0.start - Double(extra[0]) * sps) < 1e-6 })
    }
}

@Suite struct AmbientPianoSustainTests {
    /// A piano does not sustain past about a bar, so no Ambient Piano note is written longer.
    @Test func noPianoNoteRunsPastOneBar() {
        for rule in ["AMB-PNO-001", "AMB-PNO-002", "AMB-PNO-003"] {
            for i in 1...10 {
                let song = SongGenerator.generate(seed: UInt64(i) &* 0x9E3779B97F4A7C15, style: .ambient,
                                                  forceAmbientPianoRule: rule)
                let longest = song.trackEvents[kTrackLead1].map(\.durationSteps).max() ?? 0
                #expect(longest <= AmbientLeadGenerator.pianoMaxSustainSteps, "\(rule) seed \(i): \(longest) steps")
            }
        }
    }
}
