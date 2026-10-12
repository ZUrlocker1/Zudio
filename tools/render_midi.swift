#!/usr/bin/env swift
// Render a MIDI file to WAV using a SoundFont and Apple's built-in multi-timbral GM synth.
//
// Usage:
//     swift tools/render_midi.swift <in.mid> [out.wav] [soundfont.sf2|.dls]
//     swift tools/render_midi.swift ~/Downloads/soho-midi/*.mid      # batch, see render_all below
//
// Why this exists: Logic Pro is unavailable and GarageBand is not installed, but the reference
// MIDI for Chill Soho still needs listening to. This uses AUMIDISynth (kAudioUnitSubType_MIDISynth),
// which unlike AVAudioUnitSampler is MULTI-TIMBRAL — it honours per-channel program changes, so a
// 16-channel General MIDI arrangement plays back with the right instrument on each track rather
// than one patch across everything.
//
// It renders OFFLINE (manual rendering mode), so it is faster than real time and needs no audio
// device. Defaults to assets/Zudio.sf2, which means the references are heard through the same
// 156-preset bank Zudio generates with — more useful for judging how a groove will translate than
// hearing it on premium instruments.

import AVFoundation
import AudioToolbox
import Foundation

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(("error: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let inPath = args.first else {
    print("usage: swift tools/render_midi.swift <in.mid> [out.wav] [soundfont.sf2]")
    exit(2)
}
let midiURL = URL(fileURLWithPath: (inPath as NSString).expandingTildeInPath)
guard FileManager.default.fileExists(atPath: midiURL.path) else { fail("no such MIDI file: \(midiURL.path)") }

let outURL: URL = args.count > 1
    ? URL(fileURLWithPath: (args[1] as NSString).expandingTildeInPath)
    : midiURL.deletingPathExtension().appendingPathExtension("wav")

// SoundFont is OPTIONAL and off by default. AUMIDISynth has a perfectly good built-in GM bank,
// and Zudio.sf2 is a STRIPPED font (tools/strip_sf2.py) whose structure crashes CoreAudio's
// sampler loader outright — not a graceful error, a SIGSEGV inside SamplerFactory. Pass a path
// explicitly only if you want a specific bank, and expect stripped fonts to fail.
let sf2Path: String? = args.count > 2 ? (args[2] as NSString).expandingTildeInPath : nil
if let p = sf2Path, !FileManager.default.fileExists(atPath: p) { fail("no such SoundFont: \(p)") }

// ---------------------------------------------------------------- engine

let engine = AVAudioEngine()

// AUMIDISynth: Apple's built-in multi-timbral GM synth. AVAudioUnitSampler would be simpler but
// is single-timbral, which collapses every channel onto one patch.
var desc = AudioComponentDescription(
    componentType: kAudioUnitType_MusicDevice,
    componentSubType: kAudioUnitSubType_MIDISynth,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0, componentFlagsMask: 0)

let sem = DispatchSemaphore(value: 0)
var synthUnit: AVAudioUnit?
AVAudioUnit.instantiate(with: desc, options: []) { unit, err in
    if let err = err { FileHandle.standardError.write("instantiate: \(err)\n".data(using: .utf8)!) }
    synthUnit = unit
    sem.signal()
}
sem.wait()
guard let synth = synthUnit else { fail("could not instantiate AUMIDISynth") }

engine.attach(synth)
engine.connect(synth, to: engine.mainMixerNode, format: nil)

// Headroom. At unity these render hot — a dense GM arrangement pinned max_volume to 0.0 dB,
// which clips on the loud bars. 0.7 lands around -3 dB peak with no audible loss.
engine.mainMixerNode.outputVolume = 0.7

// Point the synth at a SoundFont only if one was asked for. This must happen BEFORE the engine
// starts: the synth loads its bank on initialisation and a later set is silently ignored. The
// property takes a CFURLRef — passing a Swift URL struct compiles cleanly and then crashes
// inside CoreAudio, because it reads the struct's bytes as a pointer.
if let p = sf2Path {
    var bankURL = URL(fileURLWithPath: p) as CFURL
    let status = AudioUnitSetProperty(
        synth.audioUnit,
        AudioUnitPropertyID(kMusicDeviceProperty_SoundBankURL),
        AudioUnitScope(kAudioUnitScope_Global), 0,
        &bankURL, UInt32(MemoryLayout.size(ofValue: bankURL)))
    if status != noErr { fail("could not load SoundFont (OSStatus \(status))") }
}

// ---------------------------------------------------------------- offline render setup

let sampleRate = 44100.0
guard let renderFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
    fail("could not build render format")
}
let maxFrames: AVAudioFrameCount = 4096
do {
    try engine.enableManualRenderingMode(.offline, format: renderFormat, maximumFrameCount: maxFrames)
} catch { fail("manual rendering mode: \(error)") }

// The sequencer must be created AFTER the engine is in manual rendering mode so it picks up the
// offline clock rather than the real-time one.
let sequencer = AVAudioSequencer(audioEngine: engine)
do { try sequencer.load(from: midiURL, options: []) } catch { fail("load MIDI: \(error)") }

do { try engine.start() } catch { fail("engine start: \(error)") }
sequencer.prepareToPlay()
do { try sequencer.start() } catch { fail("sequencer start: \(error)") }

// Longest track plus a tail for release and reverb.
let songLength = sequencer.tracks.map { $0.lengthInSeconds }.max() ?? 0
guard songLength > 0 else { fail("MIDI file has no note data") }
let totalSeconds = songLength + 3.0
let totalFrames = AVAudioFramePosition(totalSeconds * sampleRate)

guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                    frameCapacity: engine.manualRenderingMaximumFrameCount) else {
    fail("could not allocate render buffer")
}

let outFile: AVAudioFile
do {
    outFile = try AVAudioFile(forWriting: outURL, settings: renderFormat.settings)
} catch { fail("open output: \(error)") }

while engine.manualRenderingSampleTime < totalFrames {
    let remaining = totalFrames - engine.manualRenderingSampleTime
    let frames = AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity), remaining))
    do {
        let result = try engine.renderOffline(frames, to: buffer)
        switch result {
        case .success:          try outFile.write(from: buffer)
        case .insufficientDataFromInputNode: break
        case .cannotDoInCurrentContext, .error: fail("render failed: \(result)")
        @unknown default:       fail("render returned an unknown result")
        }
    } catch { fail("render: \(error)") }
}

sequencer.stop()
engine.stop()

let mins = Int(totalSeconds) / 60, secs = Int(totalSeconds) % 60
print("\(outURL.lastPathComponent)  —  \(mins):\(String(format: "%02d", secs))  (\(sequencer.tracks.count) tracks)")
