// ReverbSendConversionTests.swift — pins the send/insert reverb equivalence.
//
// Run with:
//   swift test --filter ReverbSendConversionTests
//
// WHY THIS EXISTS
// Before build 124 each track had its own insert reverb, set from a per-style table of
// wetDryMix values. The bus rewrite replaced those with send levels set to W/100, on the
// assumption that a send of 0.72 and a wetDryMix of 72 are the same amount of reverb.
//
// They are not. An insert rebalances dry against wet; a send leaves dry at full level and
// adds wet on top. That single assumption made playback roughly half as reverberant as it
// had been, and — because export converted back the same way — made exported files roughly
// twice as reverberant as playback.
//
// PlaybackEngine.reverbGains(forWetDryMix:) is the one place the two topologies are related.
// These tests render real audio through both and require them to match.

import Testing
import Foundation
import AVFoundation
@testable import Zudio

@Suite struct ReverbSendConversionTests {

    /// Every wetDryMix the four styles use, so the equivalence is pinned across the range.
    static let styleWetDryMixes: [Float] = [35, 40, 45, 50, 55, 56, 60, 62, 65, 70, 72]

    /// Renders a tone burst and returns (peak, RMS) of the result.
    ///
    /// `asInsert` builds one reverb inline, the way offline export does.
    /// Otherwise it builds the playback topology: a full-level dry leg and a separate send,
    /// both fed from one fan-out point, with gains from `reverbGains`.
    private func render(wetDryMix W: Float, asInsert: Bool) throws -> (peak: Float, rms: Float) {
        let sr = 44100.0
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let reverb = AVAudioUnitReverb()
        engine.attach(player)
        engine.attach(reverb)

        if asInsert {
            engine.connect(player, to: reverb, format: fmt)
            engine.connect(reverb, to: engine.mainMixerNode, format: fmt)
            reverb.wetDryMix = W
        } else {
            let dry = AVAudioMixerNode()
            let send = AVAudioMixerNode()
            engine.attach(dry)
            engine.attach(send)
            engine.connect(player, to: [AVAudioConnectionPoint(node: dry, bus: 0),
                                        AVAudioConnectionPoint(node: send, bus: 0)],
                           fromBus: 0, format: fmt)
            engine.connect(dry, to: engine.mainMixerNode, format: fmt)
            engine.connect(send, to: reverb, format: fmt)
            engine.connect(reverb, to: engine.mainMixerNode, format: fmt)
            let gains = PlaybackEngine.reverbGains(forWetDryMix: W)
            send.outputVolume = gains.send
            dry.outputVolume = gains.dry
            reverb.wetDryMix = 100
        }

        try engine.enableManualRenderingMode(.offline, format: fmt, maximumFrameCount: 4096)
        try engine.start()

        let dur = 3.0
        let total = AVAudioFrameCount(sr * dur)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: total)!
        buf.frameLength = total
        for ch in 0..<2 {
            let p = buf.floatChannelData![ch]
            for i in 0..<Int(total) {
                // Repeated short chords, closer to a real track than a single click.
                let t = Float(i) / Float(sr)
                let sounding = (i % Int(sr / 2)) < Int(sr * 0.25)
                var v: Float = 0
                if sounding { for f: Float in [220, 277, 330] { v += sinf(2 * .pi * f * t) } }
                p[i] = 0.18 * v
            }
        }
        player.scheduleBuffer(buf, at: nil, options: [])
        player.play()

        let out = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
        var peak: Float = 0
        var sum = 0.0
        var n = 0
        var done: AVAudioFramePosition = 0
        let end = AVAudioFramePosition(sr * dur)
        while done < end {
            let c = min(4096, AVAudioFrameCount(end - done))
            guard (try engine.renderOffline(c, to: out)) == .success else { break }
            let p = out.floatChannelData![0]
            for i in 0..<Int(out.frameLength) {
                let v = abs(p[i])
                peak = max(peak, v)
                sum += Double(v) * Double(v)
                n += 1
            }
            done += AVAudioFramePosition(out.frameLength)
        }
        engine.stop()
        return (peak, Float((sum / Double(max(1, n))).squareRoot()))
    }

    /// The contract. Playback's two-leg topology must be indistinguishable from the insert
    /// reverb it replaced — which is also what offline export still builds, so this is what
    /// keeps the two in agreement.
    @Test func sendTopologyReproducesTheInsert() throws {
        for W in Self.styleWetDryMixes {
            let insert = try render(wetDryMix: W, asInsert: true)
            let sends  = try render(wetDryMix: W, asInsert: false)
            #expect(insert.rms > 0, "wetDryMix \(W): insert render was silent")
            let rmsRatio = sends.rms / insert.rms
            let peakRatio = sends.peak / insert.peak
            #expect(abs(rmsRatio - 1.0) < 0.05,
                    "wetDryMix \(W): send topology RMS is \(rmsRatio)x the insert")
            #expect(abs(peakRatio - 1.0) < 0.05,
                    "wetDryMix \(W): send topology peak is \(peakRatio)x the insert")
        }
    }

    /// Guards the specific mistake this file exists for: treating the send level as the
    /// wetDryMix percentage. If this ever stops being wrong, the conversion has been removed.
    @Test func rawPercentageWouldBeWrong() throws {
        for W in Self.styleWetDryMixes {
            let gains = PlaybackEngine.reverbGains(forWetDryMix: W)
            #expect(abs(gains.send - W / 100) > 0.04,
                    "wetDryMix \(W): send \(gains.send) has collapsed back onto W/100")
        }
    }

    /// The closed form, checked without rendering: the gains are a power-domain pair, so the
    /// two legs always sum to unit power and the wet/dry split is exactly W.
    @Test func gainsArePowerComplementary() throws {
        for W in Self.styleWetDryMixes {
            let g = PlaybackEngine.reverbGains(forWetDryMix: W)
            #expect(abs(g.send * g.send + g.dry * g.dry - 1) < 1e-5,
                    "wetDryMix \(W): gains are not power-complementary")
            #expect(abs(g.send * g.send * 100 - W) < 1e-3,
                    "wetDryMix \(W): wet power is not W")
        }
        // No reverb means a fully dry track at full level, not a quiet one.
        let off = PlaybackEngine.reverbGains(forWetDryMix: 0)
        #expect(off.send == 0 && off.dry == 1)
    }
}
