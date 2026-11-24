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
    private static let distDesc = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_Distortion,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0, componentFlagsMask: 0
    )
    // MARK: - Public render entry point

    /// The texture's saved start position in its file, in seconds. The song starts at bar 1,
    /// so this is where live playback starts it too (AppState.textureSeconds at step 0).
    private static func textureOffsetSeconds(_ state: SongState) -> Double {
        Double(state.style == .ambient ? state.ambientAudioTextureOffset : state.chillAudioTextureOffset)
    }

    /// Schedules the texture as live playback does: the tail from the offset once, then the
    /// whole file looping. Export used to loop from the file's start, ignoring the offset, so
    /// an exported texture sat somewhere other than where playback and the lane put it.
    private static func scheduleTexture(_ buf: AVAudioPCMBuffer, on player: AVAudioPlayerNode,
                                        offsetSeconds: Double) {
        let total = AVAudioFramePosition(buf.frameLength)
        let start = total > 0 ? AVAudioFramePosition(offsetSeconds * buf.format.sampleRate) % total : 0
        if start > 0, let tail = AudioTexturePlayer.tail(of: buf, from: AVAudioFrameCount(start)) {
            player.scheduleBuffer(tail, at: nil, completionHandler: nil)
        }
        player.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
    }

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
        beatFixupEnabled: Bool = true,
        evolveSweepSteps: [Int] = [],
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
        // Bass slides, as playback plays them (PlaybackEngine.startChillSlide): each slide's two
        // notes as one held note, bent to the second pitch.
        let bassSlides  = ChillBassSlides.slides(for: state)
        // Behind-the-beat feel (BeatFixup), as PlaybackEngine.beatDelay plays it: the bass and the
        // drum backbeat notes sit late on a Chill Soho Soul song. Playback delays at fire time;
        // here the same offset is added to the event position, so the export matches.
        // Chill Pads per-note fade (PlaybackEngine, chillPadsMode): live, each pad note fades in
        // and out on a boost node and its note-off is deferred until the fade ends. Reproduced
        // here with a gain envelope (PadEnvelope) and the same deferred note-off.
        let chillPads = state.style == .chill
        let beat = (beatFixupEnabled && state.style == .chill)
            ? BeatFixup.offsets(for: state) : (bassMs: 0, backbeatMs: 0)
        // An Ambient Zen Slow Glide bass plays held keys with pitch bends in place of the written
        // notes (ZenBassGlide, as PlaybackEngine.stepGlide does); a Chill slide plays its two notes
        // as one held note. Never both.
        let zenGlide    = ZenBassGlide.make(for: state)
        let bassPlayed  = zenGlide?.played
            ?? ChillBassSlides.played(state.trackEvents[kTrackBass], slides: bassSlides)
        // The drum kit's note and velocity mapping, shared with playback (MixAutomation.drumFire).
        let drumProgram: UInt8 = {
            let p = programs[kTrackDrums]
            if p >= 60000 { return UInt8((p - 60000) % 1000) }
            return p >= 1000 ? UInt8(p % 1000) : UInt8(clamping: p)
        }()
        let isSpace = state.style == .kosmic && state.isKosmicSpace
        let isDrift = state.style == .kosmic && state.isKosmicDrift
        let isBuddha = !SongGenerator.currentRules(state.generationLog, track: kTrackDrums) { $0 == "KOS-DRUM-005" }.isEmpty
        let drumMap: (UInt8, UInt8) -> (UInt8, UInt8) = { note, vel in
            MixAutomation.drumFire(note: note, velocity: vel, program: drumProgram,
                                   kosmicSpace: isSpace, kosmicDrift: isDrift, buddhaPulse: isBuddha)
        }
        // Ambient releases every held note when its outro fade is down to 15%, so the release
        // envelopes finish and the reverb drains before the fade reaches zero.
        let notesOffPos: Int64? = MixAutomation.ambientNotesOffSecond(for: state).map { Int64($0 * sampleRate) }
        let eventLists: [[SampleEvent]] = samplers.map { item in
            buildEvents(item.trackIdx == kTrackBass ? bassPlayed : state.trackEvents[item.trackIdx],
                        track: item.trackIdx, beat: beat,
                        padsFade: chillPads, drumMap: drumMap, sampleRate: sampleRate, sps: sps)
                + (item.trackIdx == kTrackBass
                    ? (zenGlide.map { glideEvents($0, sampleRate: sampleRate, sps: sps) }
                       ?? slideEvents(bassSlides, played: bassPlayed,
                                      delaySamples: Int64(Double(beat.bassMs) / 1000 * sampleRate),
                                      sampleRate: sampleRate, sps: sps))
                    : [])
                + (notesOffPos.map { pos in
                    [SampleEvent(pos: pos, status: 0xB0, note: 120, vel: 0),    // All Sound Off
                     SampleEvent(pos: pos, status: 0xB0, note: 123, vel: 0)] }  // All Notes Off
                   ?? [])
        }.map { $0.sorted { $0.pos < $1.pos } }
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
        var chains = [ExportTrackChain]()
        // The song's timed automation, shared with playback (MixAutomation): automatic filter
        // sweeps and tides, and the Ambient Zen swell the pad filter follows.
        let sweeps  = MixAutomation.filterSweeps(for: state, extraSteps: evolveSweepSteps)
        let zenSwell = MixAutomation.zenSwell(for: state)

        // Every track feeds one bus whose volume is the master fade, so the texture (which plays
        // on its own engine live, outside the master) stays out of it.
        let fxBus = AVAudioMixerNode()
        fxEngine.attach(fxBus)
        fxEngine.connect(fxBus, to: fxEngine.mainMixerNode, format: avFormat)

        // Per-track chain with LFO and automation — see ExportTrackChain. Parameters that change
        // over time are set between renderOffline() calls, a block at a time.
        for i in 0..<samplers.count {
            let trackIdx = samplers[i].trackIdx
            let snap = trackIdx < snapshots.count ? snapshots[trackIdx] : Self.silentSnapshot
            chains.append(ExportTrackChain(snap: snap, trackIdx: trackIdx, state: state, sps: sps,
                                           sweeps: sweeps, zenSwell: zenSwell,
                                           engine: fxEngine, destination: fxBus, format: avFormat))
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
            chains[i].player.scheduleFile(audioFile, at: nil, completionHandler: nil)
            chains[i].player.play()
        }

        // Schedule looping texture buffer (volume already set above), from the song's saved
        // texture offset as live playback and the waveform lane do.
        if let tp = texturePlayer, let buf = textureLoopBuf {
            scheduleTexture(buf, on: tp, offsetSeconds: textureOffsetSeconds(state))
            tp.play()
        }

        // Render Phase 2: song duration + a reverb/delay tail sized to the rooms in use
        let introHold     = StartGuard.opensWithIntroHold(state)   // live: 50 ms hold, no ramp
        let tailSecs      = Self.tailSeconds(snapshots)
        let songEndSecs   = Double(totalSamples) / sampleRate
        let tailSamples   = Int64(tailSecs * sampleRate)
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
        try writeStartGap(to: audioFile, format: avFormat, introHold: introHold)

        // Block size. Tremolo, vibrato, auto-pan and the per-note fades are simulated by setting a
        // node parameter once per block, so a block must be short against the LFO period. At 4096
        // frames (~90 ms) an 8 Hz organ tremolo (125 ms) was updated about 1.4 times per cycle and
        // a 4 Hz guitar one about 2.7, which steps and aliases rather than swells. Playback updates
        // at 60 fps, so blocks match that whenever a fast LFO or a note fade is on; otherwise the
        // long block is kept for speed.
        let lfoBlock = chains.contains { $0.needsFineBlocks } ? Int64(sampleRate / 60) : 4096

        while phase2Done < phase2Total {
            if isCancelled() { throw CancellationError() }
            let thisFrames = AVAudioFrameCount(min(lfoBlock, phase2Total - phase2Done))
            let t0 = Double(phase2Done) / sampleRate
            let dt = Double(thisFrames) / sampleRate   // elapsed seconds this block

            // Update every automated parameter before rendering so this block uses current values.
            fxBus.outputVolume = MixAutomation.masterGain(for: state, at: t0 + dt / 2)
                * Self.tailFade(at: t0 + dt / 2, songEnd: songEndSecs, tail: tailSecs)
            for chain in chains { chain.update(t0: t0, dt: dt) }

            let status = try fxEngine.renderOffline(thisFrames, to: outBuf)
            guard status == .success else { break }
            if !introHold { applyStartRamp(outBuf, startFrame: phase2Done, sampleRate: sampleRate) }
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
                    snap = Self.silentSnapshot
                }

                let safeName = AudioFileExporter.sanitizedName(kTrackNames[trackIdx])
                let trackURL = AudioFileExporter.incrementingURL(
                    in: dir, base: "\(stem)-\(safeName)", ext: "m4a")

                // The same chain, automation and master fade as the mix (one track on its own).
                let trackEngine = AVAudioEngine()
                let stemBus = AVAudioMixerNode()
                trackEngine.attach(stemBus)
                trackEngine.connect(stemBus, to: trackEngine.mainMixerNode, format: avFormat)
                let chain = ExportTrackChain(snap: snap, trackIdx: trackIdx, state: state, sps: sps,
                                             sweeps: sweeps, zenSwell: zenSwell,
                                             engine: trackEngine, destination: stemBus, format: avFormat)

                try trackEngine.enableManualRenderingMode(.offline, format: avFormat,
                                                           maximumFrameCount: 4096)
                try trackEngine.start()

                // tempURLs[loopIdx] is the dry CAF for this track — still present (defer fires on return)
                let cafFile = try AVAudioFile(forReading: tempURLs[loopIdx])
                chain.player.scheduleFile(cafFile, at: nil, completionHandler: nil)
                chain.player.play()

                let trackFile = try AVAudioFile(
                    forWriting: trackURL,
                    settings: [AVFormatIDKey:         kAudioFormatMPEG4AAC,
                               AVSampleRateKey:       sampleRate,
                               AVNumberOfChannelsKey: nChannels,
                               AVEncoderBitRateKey:   128_000])
                let trackBuf = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: 4096)!
                try writeStartGap(to: trackFile, format: avFormat, introHold: introHold)

                var phase3Done: Int64 = 0
                // Short blocks for a fast LFO or a note fade, as in the mix render above.
                let stemBlock: Int64 = chain.needsFineBlocks ? Int64(sampleRate / 60) : 4096

                while phase3Done < phase2Total {
                    if isCancelled() { throw CancellationError() }
                    let thisFrames = AVAudioFrameCount(min(stemBlock, phase2Total - phase3Done))
                    let t0 = Double(phase3Done) / sampleRate
                    let dt = Double(thisFrames) / sampleRate

                    stemBus.outputVolume = MixAutomation.masterGain(for: state, at: t0 + dt / 2)
                        * Self.tailFade(at: t0 + dt / 2, songEnd: songEndSecs, tail: tailSecs)
                    chain.update(t0: t0, dt: dt)

                    let status = try trackEngine.renderOffline(thisFrames, to: trackBuf)
                    guard status == .success else { break }
                    if !introHold { applyStartRamp(trackBuf, startFrame: phase3Done, sampleRate: sampleRate) }
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
                scheduleTexture(texBuf, on: tPlayer, offsetSeconds: textureOffsetSeconds(state))
                tPlayer.play()

                let texFile = try AVAudioFile(
                    forWriting: trackURL,
                    settings: [AVFormatIDKey:         kAudioFormatMPEG4AAC,
                               AVSampleRateKey:       sampleRate,
                               AVNumberOfChannelsKey: nChannels,
                               AVEncoderBitRateKey:   128_000])
                let texOutBuf  = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: 4096)!
                try writeStartGap(to: texFile, format: avFormat, introHold: introHold)
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

    // MARK: - One track's effect chain

    /// Seconds of tail to render after the song: enough for the longest room any sounding track uses
    /// (spike 2026-11-24: medium hall about 4 s, cathedral over 8 s), never under the old 3 s.
    nonisolated static func tailSeconds(_ snapshots: [PlaybackEngine.TrackEffectSnapshot]) -> Double {
        var tail = 3.0
        for s in snapshots where !s.reverbBypassed && s.reverbWetDryMix > 0 {
            switch s.reverbPreset {
            case .cathedral, .largeHall, .largeHall2, .largeRoom2: tail = max(tail, 9)
            case .mediumHall, .mediumHall2, .mediumHall3, .largeChamber: tail = max(tail, 6)
            default: break
            }
        }
        return tail
    }

    /// A linear fade over the last 1.5 s of the tail, so a room still ringing when the file ends
    /// does not stop with a click. 1 until then, and 1 throughout the song.
    nonisolated static func tailFade(at t: Double, songEnd: Double, tail: Double) -> Float {
        let fadeStart = songEnd + tail - 1.5
        guard t > fadeStart else { return 1 }
        return Float(max(0, 1 - (t - fadeStart) / 1.5))
    }

    /// Gives an attached AVAudioUnitReverb its room in an offline engine.
    ///
    /// `loadFactoryPreset` does nothing offline, and calling it after prepare applies the room
    /// but kills the tail (ReverbPresetOfflineTests). Setting the unit's own `currentPreset`
    /// works at any point and keeps the tail (spike, 2026-11-24: small room 0.4 s, plate 0.7 s,
    /// medium hall 4 s, cathedral over 8 s). The preset list is only filled once the unit is
    /// attached to an engine. Choosing a preset resets the wet/dry amount, so that is set after.
    nonisolated static func applyRoom(_ preset: AVAudioUnitReverbPreset, to reverb: AVAudioUnitReverb, wetDryMix: Float) {
        let au = reverb.auAudioUnit
        if let p = (au.factoryPresets ?? []).first(where: { $0.number == Int(preset.rawValue) }) {
            au.currentPreset = p
        }
        reverb.wetDryMix = wetDryMix
    }

    /// A track with no snapshot renders dry and silent-effected (reverb, delay and every effect off).
    private static let silentSnapshot = PlaybackEngine.TrackEffectSnapshot(
        volume: 1, pan: 0,
        reverbPreset: .mediumHall, reverbWetDryMix: 0, reverbBypassed: true,
        delayTime: 0.125, delayFeedback: 40, delayLowPassCutoff: 6000,
        delayWetDryMix: 0, delayBypassed: true,
        compBypassed: true, distortionBypassed: true, lowShelfBypassed: true, airEnabled: false,
        hpfEnabled: false, hpfFrequency: 250,
        sweepEnabled: false, sweepFloor: 0, sweepHalfRange: 0, sweepHz: 0,
        tremoloEnabled: false, tremoloHz: 0, tremoloDepth: 0,
        panEnabled: false, panHz: 0,
        vibratoEnabled: false, vibratoHz: 0, vibratoDepthCents: 0)

    /// The effect chain of one track and the automation that moves it, built once and used by the
    /// full mix and by every stem, so the two cannot drift apart (they did: build 128's Air).
    ///
    /// Chain: player → vibrato → tremoloGain → sweep → delay → comp → dist → eq → airEQ → reverb → destination.
    ///
    /// tremoloGain: always present; its volume is the track's level, and carries tremolo, the
    ///              per-note fades and the Kosmic track fades.
    /// sweep:       a low-pass, bypassed when no sweep runs; the LFO, a tide or a fast sweep moves it.
    /// pan:         static on tremoloGain, or the auto-pan LFO.
    private final class ExportTrackChain {
        let player      = AVAudioPlayerNode()
        private let vibrato     = AVAudioUnitTimePitch()
        private let tremoloGain = AVAudioMixerNode()
        private let sweep: AVAudioUnitEffect

        private let snap: PlaybackEngine.TrackEffectSnapshot
        private let trackIdx: Int
        private let state: SongState
        private let sps: Double
        private let sweeps: [MixAutomation.FilterSweep]
        private let zenSwell: [Double]

        // Automation
        private var envelope: PadEnvelope?                  // Chill Pads or an Ambient bass/pads swell
        private let isChillPads: Bool
        private let isAmbientBass: Bool
        private let trackGain: ((Double) -> Float)?         // Kosmic drone and body-entrance fades
        private var sweepPhase: Double
        private var tremoloPhase = 0.0, panPhase = 0.0, vibratoPhase = 0.0
        private var inGlobalSweep = false

        /// True when a parameter changes faster than a 4096-frame block resolves.
        var needsFineBlocks: Bool {
            envelope != nil || snap.vibratoEnabled
                || (snap.tremoloEnabled && snap.tremoloHz > 1) || (snap.panEnabled && snap.panHz > 1)
        }

        init(snap: PlaybackEngine.TrackEffectSnapshot, trackIdx: Int, state: SongState, sps: Double,
             sweeps: [MixAutomation.FilterSweep], zenSwell: [Double],
             engine: AVAudioEngine, destination: AVAudioNode, format: AVAudioFormat) {
            self.snap = snap
            self.trackIdx = trackIdx
            self.state = state
            self.sps = sps
            self.sweeps = sweeps
            self.zenSwell = zenSwell

            isChillPads   = state.style == .chill && trackIdx == kTrackPads
            let ambientSwell = state.style == .ambient && !state.isAmbientZen
                && (trackIdx == kTrackBass || trackIdx == kTrackPads)
            isAmbientBass = ambientSwell && trackIdx == kTrackBass
            if isChillPads {
                envelope = PadEnvelope(events: state.trackEvents[kTrackPads], sps: sps)
            } else if ambientSwell {
                envelope = PadEnvelope(events: state.events(forTrack: trackIdx), sps: sps,
                                       fade: { MixAutomation.ambientNoteFadeSeconds(durationSteps: $0, secondsPerStep: $1) })
            }
            trackGain = MixAutomation.trackGain(for: state, track: trackIdx)
            sweepPhase = snap.sweepPhaseOffset

            // Sweep LP filter: starts where its cycle starts if active; bypassed if not.
            sweep = AVAudioUnitEffect(audioComponentDescription: OfflineExport.lpDesc)
            AudioUnitSetParameter(sweep.audioUnit, 1, kAudioUnitScope_Global, 0, 3.0, 0)  // resonance
            if snap.sweepEnabled {
                let start = snap.sweepFloor + snap.sweepHalfRange * Float(1 + sin(snap.sweepPhaseOffset))
                AudioUnitSetParameter(sweep.audioUnit, 0, kAudioUnitScope_Global, 0, start, 0)
                sweep.auAudioUnit.shouldBypassEffect = false
            } else {
                AudioUnitSetParameter(sweep.audioUnit, 0, kAudioUnitScope_Global, 0, 6000, 0)
                sweep.auAudioUnit.shouldBypassEffect = true
            }

            let reverb = AVAudioUnitReverb()
            // The room is set after the unit is attached (see applyRoom), because loadFactoryPreset
            // is ignored offline and a late loadFactoryPreset kills the tail. The amount of reverb
            // is set there too, since choosing a preset resets it.

            let delay = AVAudioUnitDelay()
            delay.delayTime     = snap.delayTime
            delay.feedback      = snap.delayFeedback
            delay.lowPassCutoff = snap.delayLowPassCutoff
            delay.wetDryMix     = snap.delayBypassed ? 0 : snap.delayWetDryMix
            delay.auAudioUnit.shouldBypassEffect = snap.delayBypassed

            let comp = AVAudioUnitEffect(audioComponentDescription: OfflineExport.compDesc)
            AudioUnitSetParameter(comp.audioUnit, 0, kAudioUnitScope_Global, 0, -15.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 1, kAudioUnitScope_Global, 0,   5.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 2, kAudioUnitScope_Global, 0,   1.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 4, kAudioUnitScope_Global, 0, 0.002, 0)
            AudioUnitSetParameter(comp.audioUnit, 5, kAudioUnitScope_Global, 0,  0.08, 0)
            AudioUnitSetParameter(comp.audioUnit, 6, kAudioUnitScope_Global, 0,   4.0, 0)
            comp.auAudioUnit.shouldBypassEffect = snap.compBypassed

            let dist = AVAudioUnitEffect(audioComponentDescription: OfflineExport.distDesc)
            AudioUnitSetParameter(dist.audioUnit, 14, kAudioUnitScope_Global, 0, snap.distortionGainDB, 0) // SoftClipGain dB
            AudioUnitSetParameter(dist.audioUnit, 15, kAudioUnitScope_Global, 0, snap.distortionMix, 0) // FinalMix %
            dist.auAudioUnit.shouldBypassEffect = snap.distortionBypassed

            let eq = AVAudioUnitEQ(numberOfBands: 2)
            eq.bands[0].filterType = .lowShelf
            eq.bands[0].frequency  = 80
            eq.bands[0].gain       = PlaybackEngine.lowShelfGain(zenBass: state.isAmbientZen && trackIdx == kTrackBass)
            eq.bands[0].bypass     = false
            eq.bands[1].filterType = .highPass
            eq.bands[1].frequency  = snap.hpfFrequency
            eq.bands[1].bypass     = !snap.hpfEnabled
            eq.auAudioUnit.shouldBypassEffect = snap.lowShelfBypassed

            // Must stay identical to PlaybackEngine's live airEQ (setEffect .air and setupEngine).
            // Build 128 tuned live and one export copy to this two-band shape and left the other on
            // the original single 12 kHz shelf, so Air-enabled stems exported far duller than the mix.
            // Ambient's Air is a soft sheen.
            let gentleAir = state.style == .ambient
            let airEQ = AVAudioUnitEQ(numberOfBands: 2)
            airEQ.bands[0].filterType = .parametric  // presence peak: upper-mid bite
            airEQ.bands[0].frequency  = 4000
            airEQ.bands[0].gain       = 5.0
            airEQ.bands[0].bandwidth  = 1.5          // broad, natural-sounding peak
            airEQ.bands[0].bypass     = gentleAir
            airEQ.bands[1].filterType = .highShelf   // air shelf: opens up top end
            airEQ.bands[1].frequency  = gentleAir ? 10000 : 8000
            airEQ.bands[1].gain       = gentleAir ? 3.5 : 7.5
            airEQ.bands[1].bypass     = false
            airEQ.auAudioUnit.shouldBypassEffect = !snap.airEnabled

            engine.attach(player);      engine.attach(vibrato)
            engine.attach(tremoloGain); engine.attach(sweep)
            engine.attach(delay);       engine.attach(comp)
            engine.attach(dist);        engine.attach(eq)
            engine.attach(airEQ);       engine.attach(reverb)
            OfflineExport.applyRoom(snap.reverbPreset, to: reverb, wetDryMix: snap.reverbBypassed ? 0 : snap.reverbWetDryMix)
            engine.connect(player,      to: vibrato,     format: format)
            engine.connect(vibrato,     to: tremoloGain, format: format)
            engine.connect(tremoloGain, to: sweep,       format: format)
            engine.connect(sweep,       to: delay,       format: format)
            engine.connect(delay,       to: comp,        format: format)
            engine.connect(comp,        to: dist,        format: format)
            engine.connect(dist,        to: eq,          format: format)
            engine.connect(eq,          to: airEQ,       format: format)
            engine.connect(airEQ,       to: reverb,      format: format)
            engine.connect(reverb,      to: destination, format: format)

            player.volume            = 1.0          // unity — volume applied on tremoloGain (supports > 1.0)
            player.pan               = 0            // always centre — pan is applied on tremoloGain below
            vibrato.pitch            = 0
            tremoloGain.pan          = snap.panEnabled ? panCentre : snap.pan  // static pan at mixer output
            tremoloGain.outputVolume = snap.volume  // calibrated volume; AVAudioMixerNode supports > 1.0
        }

        /// Ambient Zen's Rhythm swings around its home position, not the centre.
        private var panCentre: Float {
            state.isAmbientZen && trackIdx == kTrackRhythm ? snap.pan : 0
        }

        /// Sets every automated parameter for the block starting at `t0` seconds and lasting `dt`.
        func update(t0: Double, dt: Double) {
            let t1 = t0 + dt
            let tm = t0 + dt / 2
            // The per-note fade level, read once: it is both the track's gain and what the Ambient
            // bass sweep follows.
            let fade: Float? = envelope?.value(at: tm)

            updateSweep(t0: t0, t1: t1, tm: tm, dt: dt, fade: fade)

            if snap.tremoloEnabled { tremoloPhase += 2 * .pi * Double(snap.tremoloHz) * dt }
            if snap.tremoloEnabled || fade != nil || trackGain != nil {
                var gain: Float = 1
                if snap.tremoloEnabled { gain *= Float(1.0 - Double(snap.tremoloDepth) * (1.0 + sin(tremoloPhase))) }
                if let fade { gain *= fade }
                if let trackGain { gain *= trackGain(tm) }
                tremoloGain.outputVolume = max(0, snap.volume * gain)
            }

            if snap.panEnabled {
                panPhase += 2 * .pi * Double(snap.panHz) * dt
                if trackIdx == kTrackRhythm && state.style == .kosmic && state.isSpaceStereoTwin {
                    tremoloGain.pan = snap.pan    // a stereo twin's Rhythm holds its side
                } else {
                    tremoloGain.pan = panCentre + Float(sin(panPhase)) * snap.panDepth
                }
            }

            if snap.vibratoEnabled {
                vibratoPhase += 2 * .pi * Double(snap.vibratoHz) * dt
                vibrato.pitch = snap.vibratoDepthCents * Float(sin(vibratoPhase))
            }
        }

        private func setCutoff(_ hz: Float) {
            AudioUnitSetParameter(sweep.audioUnit, 0, kAudioUnitScope_Global, 0, hz, 0)
        }

        private func updateSweep(t0: Double, t1: Double, tm: Double, dt: Double, fade: Float?) {
            // An automatic tide or sweep takes every non-drum filter, and pauses the track's own LFO.
            if trackIdx != kTrackDrums,
               let s = sweeps.first(where: { tm >= $0.start && tm < $0.start + $0.seconds }),
               let cutoff = MixAutomation.sweepCutoff(s, at: tm) {
                inGlobalSweep = true
                sweep.auAudioUnit.shouldBypassEffect = false
                AudioUnitSetParameter(sweep.audioUnit, 1, kAudioUnitScope_Global, 0, MixAutomation.sweepResonance(s), 0)
                setCutoff(cutoff)
                return
            }
            if inGlobalSweep {
                // Back to the pre-sweep state: the track's own sweep resumes, or the filter is bypassed.
                inGlobalSweep = false
                AudioUnitSetParameter(sweep.audioUnit, 1, kAudioUnitScope_Global, 0, 3.0, 0)
                if !snap.sweepEnabled {
                    sweep.auAudioUnit.shouldBypassEffect = true
                    setCutoff(6000)
                }
            }
            guard snap.sweepEnabled else { return }

            if state.isAmbientZen && trackIdx == kTrackPads && !zenSwell.isEmpty {
                // Zen pads brighten with the song's swell.
                setCutoff(MixAutomation.zenPadCutoff(swell: zenSwell, at: tm, secondsPerStep: sps))
            } else if isAmbientBass, let fade {
                // Amplitude-coupled: the cutoff follows the bass's per-note fade level.
                setCutoff(MixAutomation.ambientBassCutoff(fade: fade))
            } else {
                sweepPhase += 2 * .pi * Double(snap.sweepHz) * dt
                // Chill Pads: the sweep restarts closed at each chord and opens over it.
                if isChillPads, let on = envelope?.lastOn(after: t0, through: t1) {
                    sweepPhase = -.pi / 2 + 2 * .pi * Double(snap.sweepHz) * (t1 - on)
                }
                setCutoff(snap.sweepFloor + snap.sweepHalfRange * Float(1 + sin(sweepPhase)))
            }
        }
    }

    // MARK: - Chill Pads fade envelope

    /// A boost-node note envelope (Chill Pads, Ambient bass and pads), as PlaybackEngine animates it. The boost starts at 0;
    /// a note-on ramps it linearly to 1 over `fadeSeconds`, a note-off ramps it from wherever it
    /// is to 0 over the fade of the most recent note-on. Evaluated at increasing times only.
    private struct PadEnvelope {
        /// min(1 s, max(0.1 s, noteSeconds / 4)) — the live rule in PlaybackEngine.onStep.
        static func fadeSeconds(durationSteps: Int, sps: Double) -> Double {
            min(1.0, max(0.1, Double(durationSteps) * sps / 4.0))
        }

        private struct Change { let time: Double; let isOn: Bool; let fade: Double }
        private var changes: [Change] = []
        private var next = 0
        private var rampStart = 0.0, rampFrom: Float = 0, rampTo: Float = 0, rampDur = 0.001
        private var lastOnFade = 0.1
        /// Times of every note-on, ascending — the sweep restarts at each.
        let onTimes: [Double]

        /// `fade` is the rule from a note's length in steps and the step length in seconds to its
        /// fade; the default is the Chill Pads rule, Ambient's swell passes its own.
        init(events: [MIDIEvent], sps: Double, fade fadeRule: ((Int, Double) -> Double)? = nil) {
            var c: [Change] = []
            for e in events {
                let fade = fadeRule?(e.durationSteps, sps) ?? Self.fadeSeconds(durationSteps: e.durationSteps, sps: sps)
                c.append(Change(time: Double(e.stepIndex) * sps, isOn: true, fade: fade))
                c.append(Change(time: Double(e.stepIndex + e.durationSteps) * sps, isOn: false, fade: fade))
            }
            // Note-ons before note-offs at the same instant, as the live loop runs them.
            changes = c.sorted { $0.time != $1.time ? $0.time < $1.time : ($0.isOn && !$1.isOn) }
            onTimes = Array(Set(c.filter { $0.isOn }.map { $0.time })).sorted()
        }

        private func current(at t: Double) -> Float {
            rampFrom + Float(min(1.0, max(0.0, (t - rampStart) / rampDur))) * (rampTo - rampFrom)
        }

        mutating func value(at t: Double) -> Float {
            while next < changes.count && changes[next].time <= t {
                let c = changes[next]; next += 1
                let from = current(at: c.time)
                if c.isOn { lastOnFade = c.fade }
                rampStart = c.time; rampFrom = from; rampTo = c.isOn ? 1 : 0
                rampDur = max(0.001, c.isOn ? c.fade : lastOnFade)
            }
            return current(at: t)
        }

        /// The latest note-on in (from, to], or nil — the moment the sweep restarts.
        func lastOn(after from: Double, through to: Double) -> Double? {
            onTimes.last { $0 > from && $0 <= to }
        }
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

    /// StartGuard.gapSeconds of silence at the head of the mix and of every stem, so an export
    /// starts like live playback. The render itself is not shifted, so effects, fades and the
    /// texture keep their timing; every file just starts that much later.
    /// StartGuard's ramp over the first 100 ms of rendered audio, after the start gap. Applied to
    /// the mix and the instrument stems; the texture has its own fade-in.
    private static func applyStartRamp(_ buf: AVAudioPCMBuffer, startFrame: Int64, sampleRate: Double) {
        let rampFrames = Int64(StartGuard.rampSeconds * sampleRate)
        guard startFrame < rampFrames, let data = buf.floatChannelData else { return }
        for i in 0..<Int(buf.frameLength) {
            let f = startFrame + Int64(i)
            if f >= rampFrames { break }
            let gain = StartGuard.gain(atSecond: Double(f) / sampleRate)
            for ch in 0..<Int(buf.format.channelCount) { data[ch][i] *= gain }
        }
    }

    private static func writeStartGap(to file: AVAudioFile, format: AVAudioFormat, introHold: Bool) throws {
        let secs = introHold ? StartGuard.introHoldSeconds : StartGuard.gapSeconds
        let frames = AVAudioFrameCount(secs * format.sampleRate)
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buf.frameLength = frames
        if let data = buf.floatChannelData {
            for ch in 0..<Int(format.channelCount) { memset(data[ch], 0, Int(frames) * MemoryLayout<Float>.size) }
        }
        try file.write(from: buf)
    }

    private static func buildEvents(_ trackEvents: [MIDIEvent], track: Int,
                                    beat: (bassMs: Int, backbeatMs: Int), padsFade: Bool,
                                    drumMap: (UInt8, UInt8) -> (UInt8, UInt8),
                                    sampleRate: Double, sps: Double) -> [SampleEvent] {
        var evts = [SampleEvent]()
        evts.reserveCapacity(trackEvents.count * 2)
        for e in trackEvents {
            // Same rule as PlaybackEngine.beatDelay: the bass, and the drum backbeat notes only.
            let delayMs = track == kTrackBass ? beat.bassMs
                : (track == kTrackDrums && BeatFixup.backbeatNotes.contains(e.note)) ? beat.backbeatMs : 0
            let late = Int64(Double(delayMs) / 1000 * sampleRate)
            let on  = Int64(Double(e.stepIndex)                   * sampleRate * sps) + late
            var off = Int64(Double(e.stepIndex + e.durationSteps) * sampleRate * sps) + late
            if padsFade && track == kTrackPads {
                off += Int64(PadEnvelope.fadeSeconds(durationSteps: e.durationSteps, sps: sps) * sampleRate)
            }
            // A drum note fires mapped, and is released as written, as playback does.
            let (fireNote, fireVel) = track == kTrackDrums ? drumMap(e.note, e.velocity) : (e.note, e.velocity)
            evts.append(SampleEvent(pos: on,  status: 0x90, note: fireNote, vel: fireVel))
            evts.append(SampleEvent(pos: off, status: 0x80, note: e.note, vel: 0))
        }
        return evts.sorted { $0.pos < $1.pos }
    }

    /// Bend events for the bass slides, as PlaybackEngine plays them: the wide bend range at the
    /// start, then for each slide a glide in 4 ms steps on ChillBassSlides.progress, ending on the
    /// target's start, and the bend home one sample before the next bass note. SampleEvent's
    /// `note` and `vel` carry a bend's low and high seven bits, or a controller and its value.
    private static func slideEvents(_ slides: [Int: BassSlide], played: [MIDIEvent], delaySamples: Int64,
                                    sampleRate: Double, sps: Double) -> [SampleEvent] {
        guard !slides.isEmpty else { return [] }
        var evts = [SampleEvent]()
        func bend(_ pos: Int64, _ semis: Double) {
            let v = ChillBassSlides.bendValue(semitones: semis)
            evts.append(SampleEvent(pos: max(0, pos), status: 0xE0, note: UInt8(v & 0x7F), vel: UInt8(v >> 7)))
        }
        // RPN 0, the pitch-bend range, then the null RPN.
        for (cc, value) in [(101, 0), (100, 0), (6, Int(ChillBassSlides.bendRange)), (38, 0), (101, 127), (100, 127)] {
            evts.append(SampleEvent(pos: 0, status: 0xB0, note: UInt8(cc), vel: UInt8(value)))
        }
        let starts = played.map(\.stepIndex).sorted()
        for slide in slides.values {
            let start = Int64(slide.glideStart * sps * sampleRate) + delaySamples
            let ticks = max(4, Int(slide.glideSteps * sps / 0.004))
            for k in 0...ticks {
                let t = Double(k) / Double(ticks)
                bend(start + Int64(slide.glideSteps * sps * sampleRate * t),
                     Double(slide.semitones) * ChillBassSlides.progress(t))
            }
            if let next = starts.first(where: { $0 > slide.fromStep }) {
                bend(Int64(Double(next) * sps * sampleRate) + delaySamples - 1, 0)
            }
        }
        return evts
    }

    /// Bend events for an Ambient Zen Slow Glide bass, as PlaybackEngine.stepGlide plays them: the
    /// wide bend range at the start, the bend back to centre one sample before each run's key is
    /// struck, and each glide a one-pole approach (time constant ZenBassGlide.tau) sent every 16 ms
    /// over four time constants, then exactly on target. A newer glide or a new run cuts the glide
    /// short where it stands, as the live token does.
    private static func glideEvents(_ glide: ZenBassGlide, sampleRate: Double, sps: Double) -> [SampleEvent] {
        var evts = [SampleEvent]()
        func bend(_ pos: Int64, _ semis: Double) {
            let v = ZenBassGlide.bendValue(semitones: semis)
            evts.append(SampleEvent(pos: max(0, pos), status: 0xE0, note: UInt8(v & 0x7F), vel: UInt8(v >> 7)))
        }
        // RPN 0, the pitch-bend range, then the null RPN.
        for (cc, value) in [(101, 0), (100, 0), (6, Int(ZenBassGlide.bendRange)), (38, 0), (101, 127), (100, 127)] {
            evts.append(SampleEvent(pos: 0, status: 0xB0, note: UInt8(cc), vel: UInt8(value)))
        }
        let steps = glide.runStarts.union(glide.bends.keys).sorted()
        var current = 0.0
        let tau = ZenBassGlide.tau
        for (n, step) in steps.enumerated() {
            let start = Double(step) * sps
            if glide.runStarts.contains(step) {
                current = 0
                bend(Int64(start * sampleRate) - 1, 0)
            }
            guard let target = glide.bends[step] else { continue }
            let limit = n + 1 < steps.count ? Double(steps[n + 1]) * sps - start : Double.infinity
            let total = 4 * tau
            let ticks = Int(total / 0.016)
            let from = current
            for k in 1...ticks {
                let t = total * Double(k) / Double(ticks)
                if t >= limit { break }
                let value = k == ticks ? target : target - (target - from) * exp(-t / tau)
                bend(Int64((start + t) * sampleRate), value)
                current = value
            }
        }
        return evts
    }

    @inline(__always)
    private static func check(_ status: OSStatus, _ ctx: String) throws {
        if status != noErr { throw ExportError.auError(status, ctx) }
    }

}
