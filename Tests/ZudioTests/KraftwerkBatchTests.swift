// KraftwerkBatchTests.swift — headless batch generator for Kraftwerk-sync Motorik songs.
//
// Run with:
//   swift test --filter KraftwerkBatchTests
//
// Output: tools/batch-output/kraftwerk/
//   *.MID     — with the song's ACTUAL instrument programs, not the GM defaults
//   *.zudio   — the generation log
//
// A sync fires in only about 20% of base Motorik songs, so this searches seeds until it
// has a balanced sample of all three sync types rather than taking the first 20 it finds.

import Testing
import Foundation
import AVFoundation
@testable import Zudio

struct KraftwerkBatchTests {

    private static var batchDir: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("tools/batch-output/kraftwerk")
    }


    // MARK: - Offline audio render
    //
    // The app's OfflineExport resolves its SoundFont through Bundle.main, which under
    // `swift test` points into the Xcode toolchain — so it cannot be used here. AVAudioUnitSampler
    // loads a bank from a plain URL instead, one sampler per track, driven in manual rendering
    // mode at CPU speed. That gives the song's real notes and real instruments.
    //
    // Zudio's effect chain (reverb, delay, sweep, pan) is NOT applied: these are dry renders for
    // auditioning arrangement and instrumentation, not a substitute for the app's own export.
    static func renderWAV(song: SongState, programs: [Int: Int], sf2: URL, to outURL: URL) throws {
        let engine = AVAudioEngine()
        let sampleRate = 44_100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        var samplers: [Int: AVAudioUnitSampler] = [:]
        var unloadable: [String] = []
        for (track, program) in programs.sorted(by: { $0.key < $1.key })
        where !song.events(forTrack: track).isEmpty {
            let sampler = AVAudioUnitSampler()
            engine.attach(sampler)
            engine.connect(sampler, to: engine.mainMixerNode, format: format)
            // Load the bank while the graph is still stopped — the sampler rejects it once the
            // engine is running in manual rendering mode. Drums take the percussion bank,
            // everything else the melodic bank, matching PlaybackEngine's bank selects.
            //
            // Pool entries above 1000 encode a bank in their leading digits, the same scheme
            // OfflineExport.makeSampler decodes; 60000+ marks an external piano file, which has
            // no equivalent here and falls back to its plain program.
            let bankMSB: UInt8 = (track == kTrackDrums) ? 0x78 : 0x79
            let bankLSB: UInt8 = program >= 60000 ? 0 : (program >= 1000 ? UInt8(program / 1000) : 0)
            let gmProgram = UInt8((program >= 60000 ? (program - 60000) : program) % 1000 % 128)
            // Not every encoded bank/program exists in this SoundFont. Try the exact patch,
            // then the same program in the default bank, then the bank's first program —
            // losing one voice is far better than losing the song.
            var loaded = false
            for (msb, lsb, prog) in [(bankMSB, bankLSB, gmProgram),
                                     (bankMSB, 0, gmProgram),
                                     (bankMSB, 0, UInt8(0))] {
                do {
                    try sampler.loadSoundBankInstrument(at: sf2, program: prog,
                                                        bankMSB: msb, bankLSB: lsb)
                    loaded = true
                    break
                } catch { continue }
            }
            guard loaded else {
                unloadable.append("\(kTrackNames[track]) prog \(program)")
                engine.detach(sampler)
                continue
            }
            samplers[track] = sampler
        }
        if !unloadable.isEmpty {
            print("      (no SoundFont patch for: \(unloadable.joined(separator: ", ")) — track omitted)")
        }
        guard !samplers.isEmpty else { return }

        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try engine.start()

        // Flatten every track into one time-ordered list of note-on / note-off actions.
        struct Action { let frame: AVAudioFramePosition; let track: Int; let note: UInt8; let vel: UInt8; let on: Bool }
        let secondsPerStep = 60.0 / Double(song.frame.tempo) / 4.0
        var actions: [Action] = []
        for (track, _) in samplers {
            for ev in song.events(forTrack: track) {
                let onFrame  = AVAudioFramePosition(Double(ev.stepIndex) * secondsPerStep * sampleRate)
                let offFrame = AVAudioFramePosition(Double(ev.stepIndex + max(1, ev.durationSteps)) * secondsPerStep * sampleRate)
                actions.append(Action(frame: onFrame,  track: track, note: ev.note, vel: ev.velocity, on: true))
                actions.append(Action(frame: offFrame, track: track, note: ev.note, vel: 0,           on: false))
            }
        }
        actions.sort { ($0.frame, $0.on ? 1 : 0) < ($1.frame, $1.on ? 1 : 0) }

        let tailFrames = AVAudioFramePosition(3.0 * sampleRate)
        let totalFrames = (actions.last?.frame ?? 0) + tailFrames

        let outFile = try AVAudioFile(forWriting: outURL, settings: format.settings,
                                      commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                      frameCapacity: engine.manualRenderingMaximumFrameCount)!
        var next = 0
        while engine.manualRenderingSampleTime < totalFrames {
            let blockStart = engine.manualRenderingSampleTime
            let frames = AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity),
                                               totalFrames - blockStart))
            // Fire everything due before the end of this block. Quantising to the block edge
            // costs at most 4096 frames — under a tenth of a 16th note at these tempos.
            let blockEnd = blockStart + AVAudioFramePosition(frames)
            while next < actions.count && actions[next].frame < blockEnd {
                let a = actions[next]
                if a.on { samplers[a.track]?.startNote(a.note, withVelocity: a.vel, onChannel: 0) }
                else    { samplers[a.track]?.stopNote(a.note, onChannel: 0) }
                next += 1
            }
            guard try engine.renderOffline(frames, to: buffer) == .success else { break }
            try outFile.write(from: buffer)
        }
        engine.stop()
    }

    @Test func generateKraftwerkBatch() throws {
        let fm = FileManager.default
        let dir = Self.batchDir
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        // Audio goes somewhere obvious for listening, not into the repo.
        let audioDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/Zudio-Kraftwerk-Batch")
        try fm.createDirectory(at: audioDir, withIntermediateDirectories: true)
        for url in (try? fm.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: url)
        }
        let sf2URL: URL? = {
            let repo = URL(fileURLWithPath: fm.currentDirectoryPath)
            for candidate in ["Sources/Zudio/Resources/Zudio.sf2", "assets/Zudio.sf2"] {
                let u = repo.appendingPathComponent(candidate)
                if fm.fileExists(atPath: u.path) { return u }
            }
            return nil
        }()
        for url in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: url)
        }

        // A balanced sample: the three sync groups occur at 8/7/5, so taking the first 20 hits
        // would under-represent Machine Voice, which is the one most worth listening to.
        let wanted: [MotorikSync: Int] = [.rhythmSection: 7, .sequenceLock: 7, .machineVoice: 6]
        var have: [MotorikSync: Int] = [:]
        var picked: [(seed: UInt64, song: SongState)] = []

        var rng = SystemRandomNumberGenerator()
        var attempts = 0
        while picked.count < 20 && attempts < 40_000 {
            attempts += 1
            let seed = UInt64.random(in: .min ... .max, using: &rng)
            let song = SongGenerator.generate(seed: seed, style: .motorik)
            let c = song.motorikSync
            guard c.isActive, (have[c] ?? 0) < (wanted[c] ?? 0) else { continue }
            have[c, default: 0] += 1
            picked.append((seed, song))
        }
        #expect(picked.count == 20, "only found \(picked.count) sync songs in \(attempts) seeds")

        print("\n=== 20 Kraftwerk-sync Motorik songs ===")
        print("Output: \(dir.path)\n")

        // Instruments are assigned outside generation and carry over between songs, exactly as
        // they do in the app, so the batch walks them the same way.
        var overrides: [Int: Int] = [:]
        var lastUsed: [Int: [MusicStyle: Int]] = [:]

        for (i, entry) in picked.enumerated() {
            let song = entry.song
            AppState.selectInstrumentsForSong(state: song, isFirstForStyle: i == 0,
                                              overrides: &overrides, lastUsed: &lastUsed)

            var encoded: [Int: Int] = [:]        // raw pool values, bank digits intact
            var midiPrograms: [Int: UInt8] = [:] // plain GM for the .MID file
            var names: [String] = []
            for track in 0..<kTrackCount {
                let pool = AppState.instrumentPoolPrograms(trackIndex: track, style: .motorik)
                let poolNames = AppState.instrumentPoolNames(trackIndex: track, style: .motorik)
                guard !pool.isEmpty else { continue }
                let idx = min(overrides[track] ?? 0, pool.count - 1)
                encoded[track] = pool[idx]
                midiPrograms[track] = UInt8((pool[idx] >= 60000 ? pool[idx] - 60000 : pool[idx]) % 1000 % 128)
                if idx < poolNames.count && track != kTrackDrums {
                    names.append("\(kTrackNames[track]):\(poolNames[idx])")
                }
            }

            let seedHex  = String(format: "%016llx", entry.seed)
            let safeName = song.title.replacingOccurrences(of: " ", with: "-")
                .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
                .joined()
            let base = String(format: "kw_%02d_%@_%@", i + 1, safeName, seedHex)

            let midiURL = dir.appendingPathComponent(base + ".MID")
            try MIDIFileExporter.export(song, to: midiURL, programs: midiPrograms)
            try SongLogExporter.export(song, midiURL: midiURL)

            if let sf2 = sf2URL {
                try Self.renderWAV(song: song, programs: encoded, sf2: sf2,
                                   to: audioDir.appendingPathComponent(base + ".wav"))
            }

            print(String(format: "%2d. %-28@ %@ %3d bpm %3d bars  %@",
                         i + 1, song.title as NSString, song.motorikSync.rawValue,
                         song.frame.tempo, song.frame.totalBars, names.joined(separator: " ")))
        }
        print("")
    }
}
