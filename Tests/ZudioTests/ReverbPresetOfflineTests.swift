// ReverbPresetOfflineTests.swift — records a platform limitation that shapes offline export.
//
// Run with:
//   swift test --filter ReverbPresetOfflineTests
//
// WHY THIS EXISTS
// OfflineExport builds one AVAudioUnitReverb per track and calls loadFactoryPreset with that
// track's intended room. The call does nothing: AVAudioUnitReverb ignores factory presets
// until the unit has been prepared, so every exported track renders in the default room.
//
// The obvious fix — move the call after prepare()/start() — is worse than the bug. The preset
// then takes effect, but the reverb stops producing a tail: one short burst and silence. So
// there is no ordering that both applies the preset and leaves the reverb working.
//
// These tests pin both halves of that. If a future OS fixes either one, a test here fails and
// the note in OfflineExport.swift can be revisited — at which point exported tracks could
// finally get their per-track rooms instead of the default.
//
// This is a limitation of offline manual-rendering engines. Live playback uses a real-time
// engine and is not covered here; it cannot be exercised without an audio device.

import Testing
import Foundation
import AVFoundation
@testable import Zudio

@Suite struct ReverbPresetOfflineTests {

    /// Renders a burst through a 100%-wet reverb offline and returns the output level of each
    /// 100 ms bucket. `loadAfterPrepare` selects which of the two orderings to use.
    private func render(preset: AVAudioUnitReverbPreset,
                        loadAfterPrepare: Bool) throws -> [Float] {
        let sr = 44100.0
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let reverb = AVAudioUnitReverb()
        engine.attach(player)
        engine.attach(reverb)
        engine.connect(player, to: reverb, format: fmt)
        engine.connect(reverb, to: engine.mainMixerNode, format: fmt)

        func load() {
            reverb.loadFactoryPreset(preset)
            reverb.wetDryMix = 100      // loadFactoryPreset resets this, so it comes after
        }
        if !loadAfterPrepare { load() }
        try engine.enableManualRenderingMode(.offline, format: fmt, maximumFrameCount: 4096)
        if loadAfterPrepare { engine.prepare(); load() }
        try engine.start()

        let dur = 5.0
        let total = AVAudioFrameCount(sr * dur)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: total)!
        buf.frameLength = total
        let burst = Int(sr * 0.05)
        for ch in 0..<2 {
            let p = buf.floatChannelData![ch]
            for i in 0..<Int(total) {
                p[i] = i < burst ? 0.7 * sinf(2.0 * .pi * 440.0 * Float(i) / Float(sr)) : 0
            }
        }
        player.scheduleBuffer(buf, at: nil, options: [])
        player.play()

        let out = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
        var buckets: [Float] = []
        var sum = 0.0
        var n = 0
        let bucketFrames = Int(sr * 0.1)
        var done: AVAudioFramePosition = 0
        let end = AVAudioFramePosition(sr * dur)
        while done < end {
            let c = min(4096, AVAudioFrameCount(end - done))
            guard (try engine.renderOffline(c, to: out)) == .success else { break }
            let p = out.floatChannelData![0]
            for i in 0..<Int(out.frameLength) {
                let v = Double(abs(p[i]))
                sum += v * v
                n += 1
                if n == bucketFrames {
                    buckets.append(Float((sum / Double(n)).squareRoot()))
                    sum = 0; n = 0
                }
            }
            done += AVAudioFramePosition(out.frameLength)
        }
        engine.stop()
        return buckets
    }

    /// True when the output still has meaningful energy well after the 50 ms burst.
    private func hasTail(_ buckets: [Float]) -> Bool {
        guard let peak = buckets.max(), peak > 0 else { return false }
        return buckets.dropFirst(4).contains { $0 > peak / 1000 }
    }

    /// Ordering as shipped: the preset is ignored, but the reverb works. If this ever starts
    /// failing, presets have begun applying and OfflineExport can honour its per-track rooms.
    @Test func presetIsIgnoredWhenLoadedBeforePrepare() throws {
        let plate = try render(preset: .plate, loadAfterPrepare: false)
        let cathedral = try render(preset: .cathedral, loadAfterPrepare: false)
        #expect(hasTail(plate), "the reverb produced no tail at all — the harness is wrong")
        #expect(plate.count == cathedral.count)
        let identical = zip(plate, cathedral).allSatisfy { abs($0 - $1) < 1e-6 }
        #expect(identical,
                "plate and cathedral now render differently — presets are applying, so the note in OfflineExport.swift is out of date")
    }

    /// The reason the ordering is not simply changed: loading after prepare applies the preset
    /// but leaves the unit unable to produce a tail.
    @Test func loadingAfterPrepareDestroysTheTail() throws {
        for preset: AVAudioUnitReverbPreset in [.plate, .mediumHall, .cathedral] {
            let buckets = try render(preset: preset, loadAfterPrepare: true)
            #expect(!hasTail(buckets),
                    "\(preset) kept its tail when loaded after prepare — offline export could now be reordered to honour per-track rooms")
        }
    }
}
