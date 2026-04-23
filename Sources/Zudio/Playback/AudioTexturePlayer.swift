// AudioTexturePlayer.swift — ambient texture loop player for Chill style
// Copyright (c) 2026 Zack Urlocker
// Uses AVAudioEngine + AVAudioPlayerNode for full DSP effect support.
// Effects: Boost, Low shelf (+5 dB at 80 Hz), Reverb (large chamber).
// Hidden: slow stereo pan LFO + random high-pass or pitch shift per play-through.
// Silent for all non-Chill styles and when texture is nil.

import AVFoundation
import Foundation

final class AudioTexturePlayer {

    private let engine     = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let boostNode  = AVAudioMixerNode()
    private let eqNode     = AVAudioUnitEQ(numberOfBands: 2)
    private let reverbNode = AVAudioUnitReverb()
    private let pitchNode  = AVAudioUnitTimePitch()

    private var fadeTimer: Timer?
    private var panTimer:  Timer?
    private var panPhase:  Double = 0

    private var currentTargetVolume: Float = 0.18  // set per-texture in startFile
    private let fadeDuration: Double = 3.0
    private let fadeInterval: Double = 0.05

    /// Filename that is currently scheduled/playing, so start() can detect a change.
    private var currentFilename: String? = nil
    /// True while a stop()-initiated fade-out is running (don't treat as "playing normally").
    private var isFadingOut: Bool = false

    init() {
        setupEngine()
    }

    // MARK: - Public

    /// Call when playback starts. `texture` is a filename (e.g. "light_rain.m4a") or nil for silence.
    func start(style: MusicStyle, texture: String?, offsetSeconds: Int = 0) {
        guard style == .chill, let filename = texture else { stopImmediate(); return }
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
        fadeOut {
            self.isFadingOut = false
            self.currentFilename = nil
            self.playerNode.stop()
            self.stopPan()
        }
    }

    /// Live swap to a different texture (e.g. user cycling picker): fast crossfade ≤500 ms.
    func switchTexture(_ filename: String?, offsetSeconds: Int = 0) {
        guard let filename else { stopImmediate(); return }
        fastFadeOut { [weak self] in
            guard let self else { return }
            self.playerNode.stop()
            self.startFile(filename: filename, fastFadeIn: true, offsetSeconds: offsetSeconds)
        }
    }

    /// Called when solo state changes. Instantly silences (or restores) the texture without
    /// a full fade — preserves position in the file so unsoloing resumes cleanly.
    func setSoloMuted(_ muted: Bool) {
        guard playerNode.isPlaying else { return }
        if muted {
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
            reverbNode.auAudioUnit.shouldBypassEffect = !enabled
            reverbNode.wetDryMix = enabled ? 22 : 0
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
        engine.attach(pitchNode)

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

        // Pitch node: unity; set at play time for subtle variation
        pitchNode.pitch = 0
        pitchNode.rate  = 1.0

        // Chain: player → boost → eq → reverb → pitch → main
        engine.connect(playerNode, to: boostNode,          format: nil)
        engine.connect(boostNode,  to: eqNode,             format: nil)
        engine.connect(eqNode,     to: reverbNode,         format: nil)
        engine.connect(reverbNode, to: pitchNode,          format: nil)
        engine.connect(pitchNode,  to: engine.mainMixerNode, format: nil)

        try? engine.start()
    }

    // MARK: - Per-texture volume

    private func volumeForTexture(_ filename: String) -> Float {
        switch filename {
        case "light_rain.m4a":    return 0.12   // rain reads loud; keep subtle
        case "urban_rain.m4a":    return 0.12   // urban rain also reads loud
        case "harbor.m4a":        return 0.22   // raised: harbor was too quiet
        case "vinyl_crackle.m4a": return 0.45   // raised: crackle needs more presence
        case "city_at_night.m4a": return 0.50   // raised: city at night was too faint
        case "bar_sounds.m4a":    return 0.42   // raised: bar ambience needs more presence
        case "ocean_waves.m4a":   return 0.10   // waves are already loud; pull back
        default:                  return 0.18
        }
    }

    // MARK: - File playback

    private func startFile(filename: String, fastFadeIn: Bool = false, offsetSeconds: Int = 0) {
        guard let url = textureURL(filename: filename) else { return }
        currentFilename = filename
        currentTargetVolume = volumeForTexture(filename)
        applyRandomVariation()
        if !engine.isRunning { try? engine.start() }
        do {
            let file        = try AVAudioFile(forReading: url)
            let sampleRate  = file.processingFormat.sampleRate
            let totalFrames = AVAudioFrameCount(file.length)

            // Clamp offset to valid range (0 ... fileLength-1)
            let rawOffset   = AVAudioFramePosition(Double(offsetSeconds) * sampleRate)
            let offsetFrame = min(rawOffset, AVAudioFramePosition(totalFrames) - 1)

            // Read tail: from offsetFrame to end of file (scheduled once, no loop)
            file.framePosition = offsetFrame
            let tailFrames = AVAudioFrameCount(Int64(totalFrames) - offsetFrame)
            guard tailFrames > 0,
                  let tailBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                    frameCapacity: tailFrames) else { return }
            try file.read(into: tailBuffer)

            // Read full file for seamless looping from the start
            file.framePosition = 0
            guard let loopBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                    frameCapacity: totalFrames) else { return }
            try file.read(into: loopBuffer)

            playerNode.volume = 0.0
            // Play the tail once (offsetFrame → end), then loop the full file forever
            playerNode.scheduleBuffer(tailBuffer, at: nil, completionHandler: nil)
            playerNode.scheduleBuffer(loopBuffer, at: nil, options: .loops, completionHandler: nil)
            playerNode.play()
            fadeIn(duration: fastFadeIn ? 0.20 : fadeDuration)
            startPan()
        } catch { }   // Unreadable file — silent fallback, no crash.
    }

    /// Each play-through: randomly apply subtle high-pass filter OR subtle pitch shift.
    /// Gives each texture session a slightly different character.
    private func applyRandomVariation() {
        if Bool.random() {
            // Option A: pitch shift ±30–70 cents (about a quarter-tone; barely noticeable)
            let sign: Float = Bool.random() ? 1 : -1
            pitchNode.pitch = Float.random(in: 30...70) * sign
            eqNode.bands[1].bypass = true
        } else {
            // Option B: gentle high-pass at 80–200 Hz (trims low-end rumble, alters character)
            eqNode.bands[1].frequency = Float.random(in: 80...200)
            eqNode.bands[1].bypass    = false
            pitchNode.pitch = 0
        }
    }

    private func textureURL(filename: String) -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let url = resourceURL.appendingPathComponent("Textures").appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Pan LFO (hidden, always active during playback)

    private func startPan() {
        stopPan()
        panPhase = Double.random(in: 0 ..< .pi * 2)
        let period = Double.random(in: 20...40)        // 20–40 s full left-right cycle
        panTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { [weak self] timer in
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
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); completion(); return }
            let next = max(self.playerNode.volume - step, 0.0)
            self.playerNode.volume = next
            if next <= 0.0 { timer.invalidate(); completion() }
        }
    }

    private func fadeOut(completion: @escaping () -> Void) {
        cancelFade()
        guard playerNode.isPlaying else { completion(); return }
        let startVol = playerNode.volume
        guard startVol > 0 else { completion(); return }
        let step = startVol / Float(fadeDuration / fadeInterval)
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { [weak self] timer in
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
    }

    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }
}
