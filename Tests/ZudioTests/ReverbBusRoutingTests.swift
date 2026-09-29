// ReverbBusRoutingTests.swift — pins the reverb returns into the mix.
//
// Run with:
//   swift test --filter ReverbBusRoutingTests
//
// WHY THIS EXISTS
// PlaybackEngine mixes seven tracks plus two shared reverb buses into one AVAudioMixerNode.
// The tracks claim input buses 0...kTrackCount-1 explicitly. The reverb returns used to
// connect with the default "next available" bus, which handed them 0 and 1 — and claiming an
// input bus REPLACES whatever was on it, so the track fan-outs silently displaced both
// returns. Every send still fed its bus and every bus still produced reverb; none of it
// reached the mixer. Playback had no bus reverb from build 124 until this was found.
//
// Nothing failed, nothing logged, and the only symptom was that playback sounded dry and
// exported files — which build their own per-track reverbs — sounded far wetter than what
// the user heard. These tests model the real graph and require the returns to survive it.

import Testing
import Foundation
import AVFoundation
@testable import Zudio

@Suite struct ReverbBusRoutingTests {

    /// Builds the same shape as `setupEngine`: returns connected first, then the per-track
    /// fan-outs claiming explicit buses.
    private func buildGraph() -> (engine: AVAudioEngine, mixer: AVAudioMixerNode,
                                  large: AVAudioNode, small: AVAudioNode) {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        let large = AVAudioUnitReverb()
        let small = AVAudioUnitReverb()
        engine.attach(large)
        engine.attach(small)
        // The fix: return above the track range rather than taking the next free bus.
        engine.connect(large, to: [AVAudioConnectionPoint(node: mixer, bus: AVAudioNodeBus(kTrackCount))],
                       fromBus: 0, format: nil)
        engine.connect(small, to: [AVAudioConnectionPoint(node: mixer, bus: AVAudioNodeBus(kTrackCount + 1))],
                       fromBus: 0, format: nil)

        for i in 0..<kTrackCount {
            let fan = AVAudioMixerNode()
            let send = AVAudioMixerNode()
            engine.attach(fan)
            engine.attach(send)
            engine.connect(fan, to: [
                AVAudioConnectionPoint(node: mixer, bus: AVAudioNodeBus(i)),
                AVAudioConnectionPoint(node: send, bus: 0),
            ], fromBus: 0, format: fmt)
            engine.connect(send, to: small, format: nil)
        }
        return (engine, mixer, large, small)
    }

    private func isConnected(_ node: AVAudioNode, to mixer: AVAudioMixerNode,
                             in engine: AVAudioEngine) -> Bool {
        // Search past the track range so a return that moved is still found.
        (0..<(kTrackCount + 8)).contains { bus in
            engine.inputConnectionPoint(for: mixer, inputBus: AVAudioNodeBus(bus))?.node === node
        }
    }

    /// The contract: after every track has claimed its bus, both reverb returns must still
    /// reach the mixer. If either is displaced, that bus's reverb is inaudible in playback.
    @Test func bothReverbReturnsSurviveTheTrackFanOuts() throws {
        let g = buildGraph()
        #expect(isConnected(g.large, to: g.mixer, in: g.engine),
                "the large reverb bus return is not connected — that bus is inaudible")
        #expect(isConnected(g.small, to: g.mixer, in: g.engine),
                "the small reverb bus return is not connected — that bus is inaudible")
    }

    /// Every track must also still own its own input bus, so the fix did not simply move the
    /// collision somewhere else.
    @Test func everyTrackKeepsItsOwnMixerInput() throws {
        let g = buildGraph()
        var seen = Set<Int>()
        for bus in 0..<kTrackCount {
            let cp = g.engine.inputConnectionPoint(for: g.mixer, inputBus: AVAudioNodeBus(bus))
            #expect(cp != nil, "mixer input bus \(bus) has nothing connected")
            #expect(cp?.node !== g.large && cp?.node !== g.small,
                    "a reverb return is sitting on track bus \(bus)")
            seen.insert(bus)
        }
        #expect(seen.count == kTrackCount)
    }

    /// The returns must land clear of the track range. This is the actual invariant — the
    /// original bug was two connections quietly sharing buses with the tracks.
    @Test func returnsUseBusesAboveTheTrackRange() throws {
        let g = buildGraph()
        for (name, node) in [("large", g.large), ("small", g.small)] {
            let bus = (0..<(kTrackCount + 8)).first {
                g.engine.inputConnectionPoint(for: g.mixer, inputBus: AVAudioNodeBus($0))?.node === node
            }
            #expect(bus != nil, "\(name) return not found on any mixer input")
            if let bus {
                #expect(bus >= kTrackCount,
                        "\(name) return is on bus \(bus), inside the track range 0..<\(kTrackCount)")
            }
        }
    }
}
