// OfflineExport.swift — Two-phase offline render (dry AUSampler + software effects)
//
// Phase 1: Render each active track dry via standalone AUSampler → per-track temp CAF files.
// Phase 2: Feed those files through an offline AVAudioEngine (reverb, delay, EQ, comp)
//          and write the final mixed M4A to outputURL.
//
// No hardware clock — runs at CPU speed (typically 15–40× real-time).
//
// To revert: delete this file, remove isFastExporting / fastExportCancelled /
// requestFastExport() / cancelExport() changes from AppState.swift,
// and remove the "Fast Export" Button from ZudioApp.swift.
import Foundation
import AudioToolbox
import AVFoundation

enum OfflineExport {

    enum ExportError: LocalizedError {
        case sf2NotFound
        case auError(OSStatus, String)
        var errorDescription: String? {
            switch self {
            case .sf2NotFound:             return "GeneralUser SF2 not found in bundle."
            case .auError(let s, let ctx): return "AudioUnit error \(s) in \(ctx)."
            }
        }
    }

    private struct SampleEvent {
        let pos: Int64; let status: UInt8; let note: UInt8; let vel: UInt8
    }

    // MARK: - AudioComponentDescriptions (mirror PlaybackEngine)

    private static let compDesc = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_DynamicsProcessor,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0, componentFlagsMask: 0
    )
    private static let lpDesc = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_LowPassFilter,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0, componentFlagsMask: 0
    )

    // MARK: - Public render entry point

    /// Two-phase render: dry AUSampler per track → per-track CAF → offline effects engine → M4A.
    /// - `snapshots`: effect settings captured from PlaybackEngine at export time.
    /// - `textureSnapshot`: current AudioTexturePlayer state (nil if no texture active).
    /// - `onProgress`: called from background thread with 0…1 fraction.
    /// - `isCancelled`: polled each block; throws CancellationError when true.
    /// Returns (songSeconds, elapsedSeconds) — caller may discard.
    @discardableResult
    static func render(
        state: SongState,
        programs: [Int],
        snapshots: [PlaybackEngine.TrackEffectSnapshot],
        rawSnapshots: [PlaybackEngine.TrackEffectSnapshot]? = nil,
        textureSnapshot: AudioTexturePlayer.ExportSnapshot?,
        outputURL: URL,
        separateTracks: Bool = false,
        onProgress: @escaping (Double) -> Void,
        isCancelled: @escaping () -> Bool
    ) throws -> (songSeconds: Double, elapsed: Double, trackURLs: [(trackIdx: Int, url: URL)]) {

        let wallStart  = CFAbsoluteTimeGetCurrent()
        let phase1End  = separateTracks ? 0.25 : 0.50
        let phase2End  = separateTracks ? 0.50 : 1.00
        var trackURLs: [(trackIdx: Int, url: URL)] = []

        guard let sf2URL = Bundle.main.url(forResource: "Zudio", withExtension: "sf2")
                        ?? Bundle.main.url(forResource: "GeneralUser_GS_v1.471", withExtension: "sf2") else {
            throw ExportError.sf2NotFound
        }

        let activeTracks = (0..<min(programs.count, state.trackEvents.count))
            .filter { !state.trackEvents[$0].isEmpty && programs[$0] != 255 }

        guard !activeTracks.isEmpty else {
            throw ExportError.auError(-1, "No active tracks to render")
        }

        // Create one AUSampler per active track; dispose all on exit
        var samplers: [(trackIdx: Int, au: AudioUnit)] = []
        defer { samplers.forEach { AudioComponentInstanceDispose($0.au) } }

        for t in activeTracks {
            let bankMSB: UInt8 = (t == kTrackDrums) ? 0x78 : 0x79
            let trackSF2: URL
            if programs[t] >= 60000 {
                let fileIdx = (programs[t] - 60000) / 1000
                trackSF2 = PlaybackEngine.externalPianoURL(fileIndex: fileIdx) ?? sf2URL
            } else {
                trackSF2 = sf2URL
            }
            let au = try makeSampler(sf2: trackSF2, encodedProgram: programs[t], bankMSB: bankMSB)
            samplers.append((t, au))
        }

        // Read audio format from first sampler
        var asbd = AudioStreamBasicDescription()
        var asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        AudioUnitGetProperty(samplers[0].au, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output, 0, &asbd, &asbdSize)
        let sampleRate = asbd.mSampleRate > 0 ? asbd.mSampleRate : 44100.0
        let nChannels  = Int(asbd.mChannelsPerFrame > 0 ? asbd.mChannelsPerFrame : 2)

        let avFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                     channels: AVAudioChannelCount(nChannels))!


        // Per-track render buffers and event lists
        let trackBufs = samplers.map { _ in
            AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: 4096)!
        }

        let sps = 60.0 / Double(state.frame.tempo) / 4.0
        let eventLists: [[SampleEvent]] = samplers.map { item in
            buildEvents(state.trackEvents[item.trackIdx], sampleRate: sampleRate, sps: sps)
        }
        var evtIdxs = [Int](repeating: 0, count: samplers.count)

        let totalSamples = Int64(Double(state.frame.totalBars * 16) * sampleRate * sps)

        // MARK: Phase 1 — render dry PCM per track to temp CAF files

        let tmpDir   = FileManager.default.temporaryDirectory
        var tempURLs = [URL]()
        var tempFiles = [AVAudioFile]()
        defer { tempURLs.forEach { try? FileManager.default.removeItem(at: $0) } }

        for i in 0..<samplers.count {
            let url  = tmpDir.appendingPathComponent("zudio_track_\(samplers[i].trackIdx)_\(ProcessInfo.processInfo.processIdentifier).caf")
            let file = try AVAudioFile(
                forWriting: url,
                settings: [AVFormatIDKey:              kAudioFormatLinearPCM,
                           AVSampleRateKey:           sampleRate,
                           AVNumberOfChannelsKey:     nChannels,
                           AVLinearPCMBitDepthKey:    16,
                           AVLinearPCMIsFloatKey:     false,
                           AVLinearPCMIsBigEndianKey: false]
            )
            tempURLs.append(url)
            tempFiles.append(file)
        }

        var rendered: Int64 = 0
        var ts = AudioTimeStamp()
        ts.mFlags = .sampleTimeValid
        ts.mSampleTime = 0

        while rendered < totalSamples {
            if isCancelled() { throw CancellationError() }

            let thisFrames = Int(min(4096, totalSamples - rendered))
            let blockEnd   = rendered + Int64(thisFrames)
            let frameCount = AVAudioFrameCount(thisFrames)

            for i in 0..<samplers.count {
                let au  = samplers[i].au
                let evs = eventLists[i]
                while evtIdxs[i] < evs.count && evs[evtIdxs[i]].pos < blockEnd {
                    let e   = evs[evtIdxs[i]]; evtIdxs[i] += 1
                    let off = UInt32(max(0, e.pos - rendered))
                    MusicDeviceMIDIEvent(au, UInt32(e.status), UInt32(e.note), UInt32(e.vel), off)
                }
            }

            for i in 0..<samplers.count {
                trackBufs[i].frameLength = frameCount
                AudioUnitRender(samplers[i].au, nil, &ts, 0, UInt32(thisFrames),
                                trackBufs[i].mutableAudioBufferList)
                try tempFiles[i].write(from: trackBufs[i])
            }
            ts.mSampleTime += Double(thisFrames)
            rendered = blockEnd

            // Phase 1 is 0…0.5 of total progress
            onProgress(phase1End * Double(rendered) / Double(totalSamples))
        }
        tempFiles.removeAll()   // flush and close all temp files

        // MARK: Phase 2 — offline AVAudioEngine with effects chain

        let fxEngine = AVAudioEngine()
        var players         = [AVAudioPlayerNode]()
        var sweepNodes      = [AVAudioUnitEffect]()
        var tremoloGains    = [AVAudioMixerNode]()
        var allSnaps        = [PlaybackEngine.TrackEffectSnapshot]()

        // Per-track chain with LFO effects — sweep, tremolo, and auto-pan are simulated per render
        // block by updating node parameters between renderOffline() calls.
        //
        // Chain: player → tremoloGain → sweep → delay → comp → eq → reverb → mainMixer
        //
        // tremoloGain: always present; outputVolume = 1.0 when tremolo is off, LFO value when on.
        // sweep:       bypassed when sweep is off; starts at floor cutoff (fully closed) when on.
        // player.pan:  static when pan is off; updated per block when on.
        for i in 0..<samplers.count {
            let trackIdx = samplers[i].trackIdx
            let snap     = trackIdx < snapshots.count ? snapshots[trackIdx]
                         : PlaybackEngine.TrackEffectSnapshot(
                               volume: 1, pan: 0,
                               reverbPreset: .mediumHall, reverbWetDryMix: 0, reverbBypassed: true,
                               delayTime: 0.125, delayFeedback: 40, delayLowPassCutoff: 6000,
                               delayWetDryMix: 0, delayBypassed: true,
                               compBypassed: true, lowShelfBypassed: true, hpfEnabled: false,
                               sweepEnabled: false, sweepFloor: 0, sweepHalfRange: 0, sweepHz: 0,
                               tremoloEnabled: false, tremoloHz: 0, tremoloDepth: 0,
                               panEnabled: false, panHz: 0)
            allSnaps.append(snap)

            let player      = AVAudioPlayerNode()
            let tremoloGain = AVAudioMixerNode()

            // Sweep LP filter: start at floor cutoff (fully closed) if active; bypassed if not.
            let sweep = AVAudioUnitEffect(audioComponentDescription: lpDesc)
            AudioUnitSetParameter(sweep.audioUnit, 1, kAudioUnitScope_Global, 0, 3.0, 0)  // resonance
            if snap.sweepEnabled {
                AudioUnitSetParameter(sweep.audioUnit, 0, kAudioUnitScope_Global, 0, snap.sweepFloor, 0)
                sweep.auAudioUnit.shouldBypassEffect = false
            } else {
                AudioUnitSetParameter(sweep.audioUnit, 0, kAudioUnitScope_Global, 0, 6000, 0)
                sweep.auAudioUnit.shouldBypassEffect = true
            }

            let reverb = AVAudioUnitReverb()
            reverb.loadFactoryPreset(snap.reverbPreset)
            reverb.wetDryMix = snap.reverbBypassed ? 0 : snap.reverbWetDryMix

            let delay = AVAudioUnitDelay()
            delay.delayTime     = snap.delayTime
            delay.feedback      = snap.delayFeedback
            delay.lowPassCutoff = snap.delayLowPassCutoff
            delay.wetDryMix     = snap.delayBypassed ? 0 : snap.delayWetDryMix
            delay.auAudioUnit.shouldBypassEffect = snap.delayBypassed

            let comp = AVAudioUnitEffect(audioComponentDescription: compDesc)
            AudioUnitSetParameter(comp.audioUnit, 0, kAudioUnitScope_Global, 0, -15.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 1, kAudioUnitScope_Global, 0,   5.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 2, kAudioUnitScope_Global, 0,   1.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 4, kAudioUnitScope_Global, 0, 0.002, 0)
            AudioUnitSetParameter(comp.audioUnit, 5, kAudioUnitScope_Global, 0,  0.08, 0)
            AudioUnitSetParameter(comp.audioUnit, 6, kAudioUnitScope_Global, 0,   4.0, 0)
            comp.auAudioUnit.shouldBypassEffect = snap.compBypassed

            let eq = AVAudioUnitEQ(numberOfBands: 2)
            eq.bands[0].filterType = .lowShelf
            eq.bands[0].frequency  = 80
            eq.bands[0].gain       = 5.0
            eq.bands[0].bypass     = false
            eq.bands[1].filterType = .highPass
            eq.bands[1].frequency  = 250
            eq.bands[1].bypass     = !snap.hpfEnabled
            eq.auAudioUnit.shouldBypassEffect = snap.lowShelfBypassed

            fxEngine.attach(player)
            fxEngine.attach(tremoloGain)
            fxEngine.attach(sweep)
            fxEngine.attach(delay)
            fxEngine.attach(comp)
            fxEngine.attach(eq)
            fxEngine.attach(reverb)
            fxEngine.connect(player,      to: tremoloGain,           format: avFormat)
            fxEngine.connect(tremoloGain, to: sweep,                 format: avFormat)
            fxEngine.connect(sweep,       to: delay,                 format: avFormat)
            fxEngine.connect(delay,       to: comp,                  format: avFormat)
            fxEngine.connect(comp,        to: eq,                    format: avFormat)
            fxEngine.connect(eq,          to: reverb,                format: avFormat)
            fxEngine.connect(reverb,      to: fxEngine.mainMixerNode,format: avFormat)

            player.volume            = 1.0          // unity — volume applied on tremoloGain (supports > 1.0)
            player.pan               = 0           // always centre — pan is applied on tremoloGain below
            tremoloGain.pan          = snap.panEnabled ? 0 : snap.pan  // static pan at mixer output
            tremoloGain.outputVolume = snap.volume  // calibrated volume; AVAudioMixerNode supports > 1.0

            players.append(player)
            sweepNodes.append(sweep)
            tremoloGains.append(tremoloGain)
        }

        // Audio texture track (Chill/Ambient rain, wind, vinyl, etc.)
        var texturePlayer: AVAudioPlayerNode? = nil
        var textureLoopBuf: AVAudioPCMBuffer? = nil
        if let tex = textureSnapshot,
           let texResourceURL = Bundle.main.resourceURL?
               .appendingPathComponent("Textures")
               .appendingPathComponent(tex.filename),
           FileManager.default.fileExists(atPath: texResourceURL.path) {
            let texFile = try AVAudioFile(forReading: texResourceURL)
            let frameCount = AVAudioFrameCount(texFile.length)
            if var buf = AVAudioPCMBuffer(pcmFormat: texFile.processingFormat,
                                          frameCapacity: frameCount) {
                try texFile.read(into: buf)
                // Offline render mode does not auto-SRC: resample to engine rate if file rate differs.
                if texFile.processingFormat.sampleRate != avFormat.sampleRate,
                   let conv = AVAudioConverter(from: texFile.processingFormat, to: avFormat) {
                    let ratio = avFormat.sampleRate / texFile.processingFormat.sampleRate
                    let dstCount = AVAudioFrameCount((Double(buf.frameLength) * ratio).rounded(.up) + 1)
                    if let dst = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: dstCount) {
                        let srcBuf = buf
                        var fed = false
                        conv.convert(to: dst, error: nil) { _, status in
                            if fed { status.pointee = .noDataNow; return nil }
                            status.pointee = .haveData; fed = true; return srcBuf
                        }
                        buf = dst
                    }
                }
                let tPlayer = AVAudioPlayerNode()
                let tReverb = AVAudioUnitReverb()
                let tEQ     = AVAudioUnitEQ(numberOfBands: 2)

                tEQ.bands[1].bypass = true
                tEQ.auAudioUnit.shouldBypassEffect = false
                if tex.isAmbient {
                    // Ambient: gentle LP at 3.5 kHz + light reverb 10%
                    tEQ.bands[0].filterType = .lowPass
                    tEQ.bands[0].frequency  = 3500
                    tEQ.bands[0].bypass     = false
                    tReverb.loadFactoryPreset(.smallRoom)
                    tReverb.wetDryMix = tex.reverbBypassed ? 0 : 10
                } else {
                    // Chill: low shelf + medium-hall reverb
                    tEQ.bands[0].filterType = .lowShelf
                    tEQ.bands[0].frequency  = 80
                    tEQ.bands[0].gain       = 5.0
                    tEQ.bands[0].bypass     = !tex.lowShelfEnabled
                    tReverb.loadFactoryPreset(.mediumHall)
                    tReverb.wetDryMix = tex.reverbBypassed ? 0 : tex.reverbWetDryMix
                }
                let boostGain: Float = tex.boostEnabled ? 1.7 : 1.0

                fxEngine.attach(tPlayer)
                fxEngine.attach(tEQ)
                fxEngine.attach(tReverb)
                fxEngine.connect(tPlayer,  to: tEQ,                  format: nil)
                fxEngine.connect(tEQ,      to: tReverb,              format: nil)
                fxEngine.connect(tReverb,  to: fxEngine.mainMixerNode, format: avFormat)
                texturePlayer = tPlayer
                textureLoopBuf = buf
                tPlayer.volume = tex.volume * boostGain
            }
        }

        try fxEngine.enableManualRenderingMode(.offline, format: avFormat,
                                               maximumFrameCount: 4096)
        try fxEngine.start()

        // Schedule dry files and set per-player volume/pan
        for i in 0..<samplers.count {
            let audioFile = try AVAudioFile(forReading: tempURLs[i])
            players[i].scheduleFile(audioFile, at: nil, completionHandler: nil)
            players[i].play()
        }

        // Schedule looping texture buffer (volume already set above)
        if let tp = texturePlayer, let buf = textureLoopBuf {
            tp.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
            tp.play()
        }

        // Render Phase 2: song duration + 3 s reverb/delay tail
        let tailSamples   = Int64(3.0 * sampleRate)
        let phase2Total   = totalSamples + tailSamples
        var phase2Done: Int64 = 0

        let audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: [AVFormatIDKey:         kAudioFormatMPEG4AAC,
                       AVSampleRateKey:       sampleRate,
                       AVNumberOfChannelsKey: nChannels,
                       AVEncoderBitRateKey:   128_000]
        )
        let outBuf = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: 4096)!

        // LFO phase accumulators — one per track, updated each block.
        // Phases are advanced by exactly (2π × hz × blockFrames / sampleRate) per block,
        // giving accurate LFO simulation regardless of block size.
        var sweepPhases   = [Double](repeating: 0, count: samplers.count)
        var tremoloPhases = [Double](repeating: 0, count: samplers.count)
        var panPhases     = [Double](repeating: 0, count: samplers.count)

        while phase2Done < phase2Total {
            if isCancelled() { throw CancellationError() }
            let thisFrames = AVAudioFrameCount(min(4096, phase2Total - phase2Done))
            let dt = Double(thisFrames) / sampleRate   // elapsed seconds this block

            // Update LFO parameters before rendering so this block uses current LFO values.
            for i in 0..<samplers.count {
                let snap = allSnaps[i]

                if snap.sweepEnabled {
                    sweepPhases[i] += 2 * .pi * Double(snap.sweepHz) * dt
                    let cutoff = snap.sweepFloor + snap.sweepHalfRange * Float(1 + sin(sweepPhases[i]))
                    AudioUnitSetParameter(sweepNodes[i].audioUnit, 0, kAudioUnitScope_Global, 0, cutoff, 0)
                }

                if snap.tremoloEnabled {
                    tremoloPhases[i] += 2 * .pi * Double(snap.tremoloHz) * dt
                    let factor = Float(1.0 - Double(snap.tremoloDepth) * (1.0 + sin(tremoloPhases[i])))
                    tremoloGains[i].outputVolume = max(0, snap.volume * factor)
                }

                if snap.panEnabled {
                    panPhases[i] += 2 * .pi * Double(snap.panHz) * dt
                    tremoloGains[i].pan = Float(sin(panPhases[i]))
                }
            }

            let status = try fxEngine.renderOffline(thisFrames, to: outBuf)
            guard status == .success else { break }
            try audioFile.write(from: outBuf)
            phase2Done += Int64(thisFrames)
            // Phase 2 is 0.5…1.0 of total progress
            onProgress(phase1End + (phase2End - phase1End) * Double(phase2Done) / Double(phase2Total))
        }
        fxEngine.stop()

        // MARK: Phase 3 — per-track stems with effects
        if separateTracks {
            let stem           = outputURL.deletingPathExtension().lastPathComponent
            let dir            = outputURL.deletingLastPathComponent()
            let hasTextureStem = textureSnapshot != nil && textureLoopBuf != nil
            let numTracks      = samplers.count + (hasTextureStem ? 1 : 0)

            for (loopIdx, samplerInfo) in samplers.enumerated() {
                let trackIdx = samplerInfo.trackIdx

                // Use raw (unmuted) snapshot so stems are always at full volume.
                let snap: PlaybackEngine.TrackEffectSnapshot
                if let raw = rawSnapshots, trackIdx < raw.count {
                    snap = raw[trackIdx]
                } else if trackIdx < snapshots.count {
                    snap = snapshots[trackIdx]
                } else {
                    snap = PlaybackEngine.TrackEffectSnapshot(
                        volume: 1, pan: 0,
                        reverbPreset: .mediumHall, reverbWetDryMix: 0, reverbBypassed: true,
                        delayTime: 0.125, delayFeedback: 40, delayLowPassCutoff: 6000,
                        delayWetDryMix: 0, delayBypassed: true,
                        compBypassed: true, lowShelfBypassed: true, hpfEnabled: false,
                        sweepEnabled: false, sweepFloor: 0, sweepHalfRange: 0, sweepHz: 0,
                        tremoloEnabled: false, tremoloHz: 0, tremoloDepth: 0,
                        panEnabled: false, panHz: 0)
                }

                let safeName = AudioFileExporter.sanitizedName(kTrackNames[trackIdx])
                let trackURL = AudioFileExporter.incrementingURL(
                    in: dir, base: "\(stem)-\(safeName)", ext: "m4a")

                let trackEngine = AVAudioEngine()
                let player      = AVAudioPlayerNode()
                let tremoloGain = AVAudioMixerNode()

                let sweep = AVAudioUnitEffect(audioComponentDescription: lpDesc)
                AudioUnitSetParameter(sweep.audioUnit, 1, kAudioUnitScope_Global, 0, 3.0, 0)
                if snap.sweepEnabled {
                    AudioUnitSetParameter(sweep.audioUnit, 0, kAudioUnitScope_Global, 0,
                                          snap.sweepFloor, 0)
                    sweep.auAudioUnit.shouldBypassEffect = false
                } else {
                    AudioUnitSetParameter(sweep.audioUnit, 0, kAudioUnitScope_Global, 0, 6000, 0)
                    sweep.auAudioUnit.shouldBypassEffect = true
                }

                let reverb = AVAudioUnitReverb()
                reverb.loadFactoryPreset(snap.reverbPreset)
                reverb.wetDryMix = snap.reverbBypassed ? 0 : snap.reverbWetDryMix

                let delay = AVAudioUnitDelay()
                delay.delayTime     = snap.delayTime
                delay.feedback      = snap.delayFeedback
                delay.lowPassCutoff = snap.delayLowPassCutoff
                delay.wetDryMix     = snap.delayBypassed ? 0 : snap.delayWetDryMix
                delay.auAudioUnit.shouldBypassEffect = snap.delayBypassed

                let comp = AVAudioUnitEffect(audioComponentDescription: compDesc)
                AudioUnitSetParameter(comp.audioUnit, 0, kAudioUnitScope_Global, 0, -15.0, 0)
                AudioUnitSetParameter(comp.audioUnit, 1, kAudioUnitScope_Global, 0,   5.0, 0)
                AudioUnitSetParameter(comp.audioUnit, 2, kAudioUnitScope_Global, 0,   1.0, 0)
                AudioUnitSetParameter(comp.audioUnit, 4, kAudioUnitScope_Global, 0, 0.002, 0)
                AudioUnitSetParameter(comp.audioUnit, 5, kAudioUnitScope_Global, 0,  0.08, 0)
                AudioUnitSetParameter(comp.audioUnit, 6, kAudioUnitScope_Global, 0,   4.0, 0)
                comp.auAudioUnit.shouldBypassEffect = snap.compBypassed

                let eq = AVAudioUnitEQ(numberOfBands: 2)
                eq.bands[0].filterType = .lowShelf
                eq.bands[0].frequency  = 80
                eq.bands[0].gain       = 5.0
                eq.bands[0].bypass     = false
                eq.bands[1].filterType = .highPass
                eq.bands[1].frequency  = 250
                eq.bands[1].bypass     = !snap.hpfEnabled
                eq.auAudioUnit.shouldBypassEffect = snap.lowShelfBypassed

                trackEngine.attach(player);      trackEngine.attach(tremoloGain)
                trackEngine.attach(sweep);       trackEngine.attach(delay)
                trackEngine.attach(comp);        trackEngine.attach(eq)
                trackEngine.attach(reverb)
                trackEngine.connect(player,      to: tremoloGain,               format: avFormat)
                trackEngine.connect(tremoloGain, to: sweep,                     format: avFormat)
                trackEngine.connect(sweep,       to: delay,                     format: avFormat)
                trackEngine.connect(delay,       to: comp,                      format: avFormat)
                trackEngine.connect(comp,        to: eq,                        format: avFormat)
                trackEngine.connect(eq,          to: reverb,                    format: avFormat)
                trackEngine.connect(reverb,      to: trackEngine.mainMixerNode, format: avFormat)

                player.volume            = 1.0
                tremoloGain.pan          = snap.panEnabled ? 0 : snap.pan
                tremoloGain.outputVolume = snap.volume

                try trackEngine.enableManualRenderingMode(.offline, format: avFormat,
                                                           maximumFrameCount: 4096)
                try trackEngine.start()

                // tempURLs[loopIdx] is the dry CAF for this track — still present (defer fires on return)
                let cafFile = try AVAudioFile(forReading: tempURLs[loopIdx])
                player.scheduleFile(cafFile, at: nil, completionHandler: nil)
                player.play()

                let trackFile = try AVAudioFile(
                    forWriting: trackURL,
                    settings: [AVFormatIDKey:         kAudioFormatMPEG4AAC,
                               AVSampleRateKey:       sampleRate,
                               AVNumberOfChannelsKey: nChannels,
                               AVEncoderBitRateKey:   128_000])
                let trackBuf = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: 4096)!

                // LFO accumulators start at 0 — same as Phase 2, so shape matches the mix
                var sweepPhase:   Double = 0
                var tremoloPhase: Double = 0
                var panPhase:     Double = 0
                var phase3Done:   Int64  = 0

                while phase3Done < phase2Total {
                    if isCancelled() { throw CancellationError() }
                    let thisFrames = AVAudioFrameCount(min(4096, phase2Total - phase3Done))
                    let dt = Double(thisFrames) / sampleRate

                    if snap.sweepEnabled {
                        sweepPhase += 2 * .pi * Double(snap.sweepHz) * dt
                        let cutoff = snap.sweepFloor + snap.sweepHalfRange * Float(1 + sin(sweepPhase))
                        AudioUnitSetParameter(sweep.audioUnit, 0, kAudioUnitScope_Global, 0, cutoff, 0)
                    }
                    if snap.tremoloEnabled {
                        tremoloPhase += 2 * .pi * Double(snap.tremoloHz) * dt
                        let factor = Float(1.0 - Double(snap.tremoloDepth) * (1.0 + sin(tremoloPhase)))
                        tremoloGain.outputVolume = max(0, snap.volume * factor)
                    }
                    if snap.panEnabled {
                        panPhase += 2 * .pi * Double(snap.panHz) * dt
                        tremoloGain.pan = Float(sin(panPhase))
                    }

                    let status = try trackEngine.renderOffline(thisFrames, to: trackBuf)
                    guard status == .success else { break }
                    try trackFile.write(from: trackBuf)
                    phase3Done += Int64(thisFrames)

                    let trackFraction = (Double(loopIdx) + Double(phase3Done) / Double(phase2Total))
                                        / Double(numTracks)
                    onProgress(phase2End + (1.0 - phase2End) * trackFraction)
                }
                trackEngine.stop()
                trackURLs.append((trackIdx: trackIdx, url: trackURL))
            }

            // Texture stem — exported when AudioTexturePlayer audio is active
            if let tex = textureSnapshot, let texBuf = textureLoopBuf {
                let safeName = AudioFileExporter.sanitizedName(kTrackNames[kTrackTexture])
                let trackURL = AudioFileExporter.incrementingURL(
                    in: dir, base: "\(stem)-\(safeName)", ext: "m4a")

                let texEngine = AVAudioEngine()
                let tPlayer   = AVAudioPlayerNode()
                let tReverb   = AVAudioUnitReverb()
                let tEQ       = AVAudioUnitEQ(numberOfBands: 2)

                tEQ.bands[1].bypass = true
                tEQ.auAudioUnit.shouldBypassEffect = false
                if tex.isAmbient {
                    tEQ.bands[0].filterType = .lowPass
                    tEQ.bands[0].frequency  = 3500
                    tEQ.bands[0].bypass     = false
                    tReverb.loadFactoryPreset(.smallRoom)
                    tReverb.wetDryMix = tex.reverbBypassed ? 0 : 10
                } else {
                    tEQ.bands[0].filterType = .lowShelf
                    tEQ.bands[0].frequency  = 80
                    tEQ.bands[0].gain       = 5.0
                    tEQ.bands[0].bypass     = !tex.lowShelfEnabled
                    tReverb.loadFactoryPreset(.mediumHall)
                    tReverb.wetDryMix = tex.reverbBypassed ? 0 : tex.reverbWetDryMix
                }
                let boostGain: Float = tex.boostEnabled ? 1.7 : 1.0
                tPlayer.volume = tex.volume * boostGain

                texEngine.attach(tPlayer)
                texEngine.attach(tEQ)
                texEngine.attach(tReverb)
                texEngine.connect(tPlayer, to: tEQ,                     format: nil)
                texEngine.connect(tEQ,     to: tReverb,                 format: nil)
                texEngine.connect(tReverb, to: texEngine.mainMixerNode, format: avFormat)

                try texEngine.enableManualRenderingMode(.offline, format: avFormat,
                                                        maximumFrameCount: 4096)
                try texEngine.start()
                tPlayer.scheduleBuffer(texBuf, at: nil, options: .loops, completionHandler: nil)
                tPlayer.play()

                let texFile = try AVAudioFile(
                    forWriting: trackURL,
                    settings: [AVFormatIDKey:         kAudioFormatMPEG4AAC,
                               AVSampleRateKey:       sampleRate,
                               AVNumberOfChannelsKey: nChannels,
                               AVEncoderBitRateKey:   128_000])
                let texOutBuf  = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: 4096)!
                var phase3Done: Int64 = 0

                while phase3Done < phase2Total {
                    if isCancelled() { throw CancellationError() }
                    let thisFrames = AVAudioFrameCount(min(4096, phase2Total - phase3Done))
                    let status = try texEngine.renderOffline(thisFrames, to: texOutBuf)
                    guard status == .success else { break }
                    try texFile.write(from: texOutBuf)
                    phase3Done += Int64(thisFrames)
                    let texFraction = (Double(samplers.count) + Double(phase3Done) / Double(phase2Total))
                                      / Double(numTracks)
                    onProgress(phase2End + (1.0 - phase2End) * texFraction)
                }
                texEngine.stop()
                trackURLs.append((trackIdx: kTrackTexture, url: trackURL))
            }
        }

        let songSecs = Double(totalSamples) / sampleRate
        let elapsed  = CFAbsoluteTimeGetCurrent() - wallStart
        return (songSecs, elapsed, trackURLs)
    }

    // MARK: - Helpers

    // externalPianoURL is defined in PlaybackEngine as a static func — delegates there.

    private static func makeSampler(sf2: URL, encodedProgram: Int, bankMSB: UInt8) throws -> AudioUnit {
        let bankLSB: UInt8
        let program: UInt8
        if encodedProgram >= 60000 {
            bankLSB = 0
            program = UInt8((encodedProgram - 60000) % 1000)
        } else {
            bankLSB = encodedProgram >= 1000 ? UInt8(encodedProgram / 1000) : 0
            program = encodedProgram >= 1000 ? UInt8(encodedProgram % 1000) : UInt8(encodedProgram)
        }
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: kAudioUnitSubType_Sampler,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0
        )
        guard let comp = AudioComponentFindNext(nil, &desc) else {
            throw ExportError.auError(-1, "AudioComponentFindNext")
        }
        var auPtr: AudioUnit?
        try check(AudioComponentInstanceNew(comp, &auPtr), "ComponentInstanceNew")
        guard let au = auPtr else { throw ExportError.auError(-1, "nil AudioUnit") }

        var maxFrames: UInt32 = 4096
        AudioUnitSetProperty(au, kAudioUnitProperty_MaximumFramesPerSlice,
                             kAudioUnitScope_Global, 0, &maxFrames, 4)
        try check(AudioUnitInitialize(au), "Initialize")

        var instrData = AUSamplerInstrumentData(
            fileURL: Unmanaged.passUnretained(sf2 as CFURL),
            instrumentType: UInt8(kInstrumentType_SF2Preset),
            bankMSB: bankMSB, bankLSB: bankLSB, presetID: program
        )
        try check(AudioUnitSetProperty(
            au, kAUSamplerProperty_LoadInstrument, kAudioUnitScope_Global, 0,
            &instrData, UInt32(MemoryLayout<AUSamplerInstrumentData>.size)
        ), "LoadInstrument")

        return au
    }

    private static func buildEvents(_ trackEvents: [MIDIEvent],
                                    sampleRate: Double, sps: Double) -> [SampleEvent] {
        var evts = [SampleEvent]()
        evts.reserveCapacity(trackEvents.count * 2)
        for e in trackEvents {
            let on  = Int64(Double(e.stepIndex)                   * sampleRate * sps)
            let off = Int64(Double(e.stepIndex + e.durationSteps) * sampleRate * sps)
            evts.append(SampleEvent(pos: on,  status: 0x90, note: e.note, vel: e.velocity))
            evts.append(SampleEvent(pos: off, status: 0x80, note: e.note, vel: 0))
        }
        return evts.sorted { $0.pos < $1.pos }
    }

    @inline(__always)
    private static func check(_ status: OSStatus, _ ctx: String) throws {
        if status != noErr { throw ExportError.auError(status, ctx) }
    }

}
