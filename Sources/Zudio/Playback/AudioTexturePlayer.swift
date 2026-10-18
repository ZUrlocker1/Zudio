// AudioTexturePlayer.swift — ambient texture loop player for Chill and Ambient styles
// Copyright (c) 2026 Zack Urlocker
// Uses AVAudioEngine + AVAudioPlayerNode for full DSP effect support.
// Chill effects: Boost, Low shelf (+5 dB at 80 Hz), Reverb (medium hall 22%), pitch/HP variation.
// Ambient effects: LP at 3.5 kHz + small-room reverb 10% wet (pushes file into background).
// Hidden: slow stereo pan LFO + random high-pass or pitch shift per play-through (Chill only).
// Silent for all non-Chill/non-Ambient styles and when texture is nil.

import AVFoundation
import Foundation

final class AudioTexturePlayer {

    private let engine     = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let boostNode  = AVAudioMixerNode()
    private let eqNode     = AVAudioUnitEQ(numberOfBands: 2)
    private let reverbNode = AVAudioUnitReverb()
    private var fadeTimer: Timer?
    private var panTimer:  Timer?
    private var panPhase:  Double = 0

    private var currentTargetVolume: Float = 0.18  // set per-texture in startFile
    private let fadeDuration:     Double = 3.0   // fade-in
    private let stopFadeDuration: Double = 0.5   // stop() fade-out — short so Stop feels responsive
    private let fadeInterval:     Double = 0.05

    /// Filename that is currently scheduled/playing, so start() can detect a change.
    private var currentFilename: String? = nil
    /// True while a stop()-initiated fade-out is running (don't treat as "playing normally").
    private var isFadingOut: Bool = false
    /// True for Ambient textures — uses LP+light reverb instead of Chill DSP chain.
    private var bypassEffects: Bool = false
    /// Tracks which effect mode was last configured so loadFactoryPreset is skipped when unchanged.
    private var lastEffectsMode: Bool? = nil
    /// The most recently decoded texture, whole. Every start used to decode the file on the
    /// main thread (every Play after Stop, every song with the same texture), and twice when
    /// the offset was 0: once for the tail, once for the loop. One entry is the memory an
    /// active texture already holds (up to about 15 MB), so it is safe on iOS too.
    private var decodedLoop: (filename: String, buffer: AVAudioPCMBuffer)? = nil

    init() {
        setupEngine()
    }

    // MARK: - Public

    /// Call when playback starts. `texture` is a filename (e.g. "light_rain.m4a") or nil for silence.
    /// `offsetSeconds` is the position in the file to start from — the song's saved texture
    /// offset plus the song time at the playhead (AppState.textureSeconds) — wrapped into the loop.
    func start(style: MusicStyle, texture: String?, offsetSeconds: Double = 0) {
        guard (style == .chill || style == .ambient), let filename = texture else { stopImmediate(); return }
        bypassEffects = (style == .ambient)
        // Skip restart only if already playing this exact file at the same offset with no fade in progress.
        if playerNode.isPlaying && !isFadingOut && currentFilename == filename { return }
        // Cancel any in-progress fade (stop or fast-fade) so we don't kill the new playback.
        cancelFade()
        isFadingOut = false
        if playerNode.isPlaying { playerNode.stop() }
        startFile(filename: filename, offsetSeconds: offsetSeconds)
    }

    /// Call when playback stops — fades out then releases.
    func stop() {
        isFadingOut = true
        fadeOut(duration: stopFadeDuration) {
            self.isFadingOut = false
            self.playerNode.stop()
            self.stopPan()
            self.pauseEngineWhenIdle()
        }
    }

    /// Pauses this player's own engine while no texture plays, so its IO cycle, reverb and EQ
    /// stop processing silence (every Soho, Motorik and Kosmic song, and whenever stopped).
    /// startFile restarts it. Mac only for now: iOS manages this engine with the audio session.
    private func pauseEngineWhenIdle() {
        #if os(macOS)
        if engine.isRunning { engine.pause() }
        #endif
    }

    #if os(iOS)
    /// Pause the engine without releasing it. Called before AppState deactivates
    /// AVAudioSession when the app backgrounds while stopped.
    func pauseEngine() {
        guard engine.isRunning else { return }
        engine.pause()
    }
    #endif

    /// Live swap to a different texture (e.g. user cycling picker): fast crossfade ≤500 ms.
    func switchTexture(_ filename: String?, offsetSeconds: Double = 0) {
        guard let filename else { stopImmediate(); return }
        isFadingOut = true
        fastFadeOut { [weak self] in
            guard let self else { return }
            self.isFadingOut = false
            self.playerNode.stop()
            self.startFile(filename: filename, fastFadeIn: true, offsetSeconds: offsetSeconds)
        }
    }

    /// Moves the playing texture to `seconds` in its file with a short crossfade, after a seek or
    /// a tempo change, so it stays where the song (and the waveform lane) say it should be.
    func reposition(toSeconds seconds: Double) {
        guard let filename = currentFilename, playerNode.isPlaying, !isFadingOut else { return }
        switchTexture(filename, offsetSeconds: seconds)
    }

    /// Whether the texture is silenced, by its own mute or by a solo on another track. The file
    /// sits outside PlaybackEngine's mixer, so engine mute never reaches it — AppState drives this
    /// from `muteState` and `soloState` instead. Held here because it can be asked for before the
    /// player is running: `startFile` reads it rather than fading up into a mute.
    ///
    /// Only solo used to reach it. Muting the Texture track on a base Chill or Chill Blues song
    /// changed nothing and the café loop played on (Zack, 2026-10-15).
    private(set) var silenced = false

    /// Instantly silences (or restores) the texture without a full fade — keeps the position in
    /// the file so unmuting resumes cleanly.
    func setSilenced(_ muted: Bool) {
        guard muted != silenced else { return }
        silenced = muted
        // A fade-out in progress (Stop, or a texture switch) owns the volume and finishes by
        // stopping or restarting the player, and startFile reads `silenced` when it does.
        // Cancelling that fade here would orphan its completion and leave the old file looping.
        guard playerNode.isPlaying, !isFadingOut else { return }
        if muted {
            // Cancel the fade first: a running fade timer steps the volume back up within a
            // frame or two and the texture stays audible through the solo (Zack, 2026-10-13).
            cancelFade()
            playerNode.volume = 0.0
        } else {
            // Restore to the target volume the texture was playing at
            fadeIn(duration: 0.15)
        }
    }

    /// Route effect toggle from the Chill texture track strip.
    func setEffect(_ effect: TrackEffect, enabled: Bool) {
        switch effect {
        case .boost:
            boostNode.outputVolume = enabled ? 1.7 : 1.0   // 1.7 ≈ +4.6 dB
        case .lowShelf:
            eqNode.bands[0].bypass = !enabled
        case .reverb, .space:
            reverbNode.wetDryMix = enabled ? 22 : 0
            // A zero mix still runs the reverb DSP; bypass it too. Export reads wetDryMix.
            reverbNode.auAudioUnit.shouldBypassEffect = !enabled
        default:
            break
        }
    }

    // MARK: - Engine setup

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(boostNode)
        engine.attach(eqNode)
        engine.attach(reverbNode)

        // Band 0 — low shelf: +5 dB at 80 Hz (user "Low" effect, ON by default)
        eqNode.bands[0].filterType = .lowShelf
        eqNode.bands[0].frequency  = 80
        eqNode.bands[0].gain       = 5.0
        eqNode.bands[0].bypass     = false

        // Band 1 — high-pass: random frequency per play-through; starts bypassed
        eqNode.bands[1].filterType = .highPass
        eqNode.bands[1].frequency  = 150
        eqNode.bands[1].bypass     = true

        eqNode.auAudioUnit.shouldBypassEffect = false

        // Reverb: medium hall at 22% wet — lighter than large chamber, adequate for background texture
        reverbNode.loadFactoryPreset(.mediumHall)
        reverbNode.wetDryMix = 22
        reverbNode.auAudioUnit.shouldBypassEffect = false

        // Chain: player → boost → eq → reverb → main
        engine.connect(playerNode, to: boostNode,            format: nil)
        engine.connect(boostNode,  to: eqNode,               format: nil)
        engine.connect(eqNode,     to: reverbNode,           format: nil)
        engine.connect(reverbNode, to: engine.mainMixerNode, format: nil)

        try? engine.start()
    }

    // MARK: - Per-texture volume

    private func volumeForTexture(_ filename: String) -> Float {
        switch filename {
        case "light_rain.m4a":    return 0.07
        case "rain-and-thunder.m4a":    return 0.14
        case "ocean_waves.m4a":   return 0.05
        case "zen-bells.m4a":     return 0.18
        case "wind-stoorm.m4a":   return 0.20
        case "desert-winds.m4a":  return 0.10
        case "harbor.m4a":        return 0.22
        case "vinyl_crackle.m4a": return 0.38
        case "city_at_night.m4a": return 0.50
        case "bar_sounds.m4a":    return 0.25
        case "another-pub.m4a":   return 0.22
        default:                  return 0.18
        }
    }

    // MARK: - File playback

    private func startFile(filename: String, fastFadeIn: Bool = false, offsetSeconds: Double = 0) {
        guard let url = textureURL(filename: filename) else { return }
        currentFilename = filename
        currentTargetVolume = volumeForTexture(filename)
        if bypassEffects {
            // Ambient: gentle LP at 3.5 kHz + light reverb to push file into background.
            if lastEffectsMode != true {
                eqNode.bands[0].bypass     = true
                eqNode.bands[1].filterType = .lowPass
                eqNode.bands[1].frequency  = 3500
                eqNode.bands[1].bypass     = false
                eqNode.auAudioUnit.shouldBypassEffect = false
                reverbNode.loadFactoryPreset(.smallRoom)
                reverbNode.wetDryMix = 10
                reverbNode.auAudioUnit.shouldBypassEffect = false
                lastEffectsMode = true
            }
        } else {
            if lastEffectsMode != false {
                eqNode.bands[0].bypass = false
                eqNode.auAudioUnit.shouldBypassEffect = false
                reverbNode.loadFactoryPreset(.mediumHall)
                reverbNode.wetDryMix = 22
                reverbNode.auAudioUnit.shouldBypassEffect = false
                lastEffectsMode = false
            }
            applyRandomVariation()
        }
        if !engine.isRunning { try? engine.start() }
        do {
            // Full file for seamless looping from the start
            let loopBuffer  = try loopBuffer(for: filename, url: url)
            let sampleRate  = loopBuffer.format.sampleRate
            let totalFrames = loopBuffer.frameLength

            // Wrap into the loop: past the file's end the loop has come round again, which is
            // also how the waveform lane draws it.
            let rawOffset   = AVAudioFramePosition(max(0, offsetSeconds) * sampleRate)
            let offsetFrame = totalFrames > 0 ? rawOffset % AVAudioFramePosition(totalFrames) : 0

            playerNode.volume = 0.0
            // Play the tail once (offsetFrame → end), then loop the full file forever. At offset 0
            // the tail is the whole file, so the loop alone plays the same thing.
            if offsetFrame > 0 {
                guard let tailBuffer = Self.tail(of: loopBuffer, from: AVAudioFrameCount(offsetFrame)) else { return }
                playerNode.scheduleBuffer(tailBuffer, at: nil, completionHandler: nil)
            }
            playerNode.scheduleBuffer(loopBuffer, at: nil, options: .loops, completionHandler: nil)
            playerNode.play()
            // A texture that starts muted, or while another track is soloed, stays silent until
            // that clears rather than fading up underneath it.
            if silenced { playerNode.volume = 0.0 } else {
                fadeIn(duration: fastFadeIn ? 0.20 : fadeDuration)
            }
            startPan()
        } catch { }   // Unreadable file — silent fallback, no crash.
    }

    /// The whole texture decoded, from the cache when it is the same file as last time.
    private func loopBuffer(for filename: String, url: URL) throws -> AVAudioPCMBuffer {
        if let cached = decodedLoop, cached.filename == filename { return cached.buffer }
        decodedLoop = nil   // release the previous file before decoding the next
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length))
        else { throw CocoaError(.fileReadCorruptFile) }
        try file.read(into: buffer)
        decodedLoop = (filename, buffer)
        return buffer
    }

    /// A copy of `buffer` from `start` to its end: the once-through tail before the loop.
    /// Copied from the decoded loop rather than decoded again from the file.
    static func tail(of buffer: AVAudioPCMBuffer, from start: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard start < buffer.frameLength, let src = buffer.floatChannelData,
              let tail = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength - start),
              let dst = tail.floatChannelData else { return nil }
        let frames = Int(buffer.frameLength - start)
        if buffer.format.isInterleaved {
            // One pointer holding every channel, frame by frame.
            let channels = Int(buffer.format.channelCount)
            dst[0].update(from: src[0] + Int(start) * channels, count: frames * channels)
        } else {
            // One pointer per channel — the format AVAudioFile decodes to.
            for ch in 0..<Int(buffer.format.channelCount) {
                dst[ch].update(from: src[ch] + Int(start), count: frames)
            }
        }
        tail.frameLength = AVAudioFrameCount(frames)
        return tail
    }

    /// Each play-through: randomly apply a subtle high-pass filter for tonal variety.
    /// Pitch node is never touched here — it stays at 0 cents set by startFile().
    private func applyRandomVariation() {
        if Bool.random() {
            eqNode.bands[1].frequency = Float.random(in: 80...200)
            eqNode.bands[1].bypass    = false
        } else {
            eqNode.bands[1].bypass = true
        }
    }

    private func textureURL(filename: String) -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let url = resourceURL.appendingPathComponent("Textures").appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Export snapshot

    struct ExportSnapshot {
        let filename: String
        let volume: Float
        let boostEnabled: Bool
        let lowShelfEnabled: Bool
        let reverbWetDryMix: Float
        let reverbBypassed: Bool
        let isAmbient: Bool
    }

    /// Captures the current playback state for use by OfflineExport.
    func exportSnapshot() -> ExportSnapshot? {
        guard let filename = currentFilename else { return nil }
        return ExportSnapshot(
            filename:       filename,
            volume:         currentTargetVolume,
            boostEnabled:   boostNode.outputVolume > 1.1,
            lowShelfEnabled: !eqNode.bands[0].bypass && !eqNode.auAudioUnit.shouldBypassEffect,
            reverbWetDryMix: reverbNode.wetDryMix,
            reverbBypassed: reverbNode.wetDryMix == 0,
            isAmbient:      bypassEffects
        )
    }

    // MARK: - Pan LFO (hidden, always active during playback)

    /// Schedules a repeating timer in `.common` run-loop mode.
    ///
    /// `Timer.scheduledTimer` installs in `.default` mode only, which does NOT fire while
    /// the main run loop is in `.tracking` mode — i.e. while the user is touching a List
    /// row or scrolling on iOS. In `.default` mode a texture switch triggered from the
    /// Songs tab could leave the fade-in timer unfired, so playerNode.volume stayed at the
    /// 0.0 that startFile() sets (silence), and leave stop()'s fade-out unfired, so its
    /// completion never ran playerNode.stop() and the previous texture kept looping.
    private func scheduleTimer(interval: Double,
                               _ tick: @escaping (Timer) -> Void) -> Timer {
        let t = Timer(timeInterval: interval, repeats: true) { timer in tick(timer) }
        RunLoop.main.add(t, forMode: .common)
        return t
    }

    private func startPan() {
        stopPan()
        panPhase = Double.random(in: 0 ..< .pi * 2)
        let period = Double.random(in: 20...40)        // 20–40 s full left-right cycle
        panTimer = scheduleTimer(interval: 1.0) { [weak self] _ in
            guard let self else { return }
            self.panPhase += 1.0 * 2 * .pi / period   // 1 s tick — imperceptible at 20–40 s period
            self.playerNode.pan = Float(sin(self.panPhase) * 0.30)  // max ±30% stereo spread
        }
    }

    private func stopPan() {
        panTimer?.invalidate()
        panTimer = nil
        playerNode.pan = 0
    }

    // MARK: - Fade

    private func fadeIn(duration: Double = 3.0) {
        cancelFade()
        let target = currentTargetVolume
        let step = target / Float(duration / fadeInterval)
        fadeTimer = scheduleTimer(interval: fadeInterval) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let next = min(self.playerNode.volume + step, target)
            self.playerNode.volume = next
            if next >= target { timer.invalidate() }
        }
    }

    /// Fast fade-out for picker cycling: completes in ~200 ms so total switch is ≤500 ms.
    private func fastFadeOut(completion: @escaping () -> Void) {
        cancelFade()
        guard playerNode.isPlaying else { completion(); return }
        let startVol = playerNode.volume
        guard startVol > 0 else { completion(); return }
        let fastDuration = 0.20   // 200 ms out; startFile fade-in adds another ~200 ms
        let step = startVol / Float(fastDuration / fadeInterval)
        fadeTimer = scheduleTimer(interval: fadeInterval) { [weak self] timer in
            guard let self else { timer.invalidate(); completion(); return }
            let next = max(self.playerNode.volume - step, 0.0)
            self.playerNode.volume = next
            if next <= 0.0 { timer.invalidate(); completion() }
        }
    }

    private func fadeOut(duration: Double = 3.0, completion: @escaping () -> Void) {
        cancelFade()
        guard playerNode.isPlaying else { completion(); return }
        let startVol = playerNode.volume
        guard startVol > 0 else { completion(); return }
        let step = startVol / Float(duration / fadeInterval)
        fadeTimer = scheduleTimer(interval: fadeInterval) { [weak self] timer in
            guard let self else { timer.invalidate(); completion(); return }
            let next = max(self.playerNode.volume - step, 0.0)
            self.playerNode.volume = next
            if next <= 0.0 { timer.invalidate(); completion() }
        }
    }

    private func stopImmediate() {
        cancelFade()
        isFadingOut = false
        currentFilename = nil
        stopPan()
        playerNode.stop()
        pauseEngineWhenIdle()
    }

    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }
}
