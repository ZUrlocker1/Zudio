// AudioTexturePlayer.swift — ambient texture loop player for Chill style
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

    init() {
        setupEngine()
    }

    // MARK: - Public

    /// Call when playback starts. `texture` is a filename (e.g. "light_rain.m4a") or nil for silence.
    func start(style: MusicStyle, texture: String?) {
        guard style == .chill, let filename = texture else { stopImmediate(); return }
        if playerNode.isPlaying { return }
        startFile(filename: filename)
    }

    /// Call when playback stops — fades out then releases.
    func stop() {
        fadeOut {
            self.playerNode.stop()
            self.stopPan()
        }
    }

    /// Live swap to a different texture (e.g. user cycling picker): fast crossfade ≤500 ms.
    func switchTexture(_ filename: String?) {
        guard let filename else { stopImmediate(); return }
        fastFadeOut { [weak self] in
            guard let self else { return }
            self.playerNode.stop()
            self.startFile(filename: filename, fastFadeIn: true)
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
            reverbNode.wetDryMix = enabled ? 35 : 0
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

        // Reverb: large chamber at 35% wet (ON by default)
        reverbNode.loadFactoryPreset(.largeChamber)
        reverbNode.wetDryMix = 35
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
        case "harbor.m4a":        return 0.12   // harbor ambience reads loud
        case "vinyl_crackle.m4a": return 0.30   // crackle sits low in recordings; needs a boost
        case "city_at_night.m4a": return 0.36   // city ambience is quiet; raise further
        case "bar_sounds.m4a":    return 0.28   // bar ambience sits quiet; raise to match feel
        case "ocean_waves.m4a":   return 0.10   // waves are already loud; pull back
        default:                  return 0.18
        }
    }

    // MARK: - File playback

    private func startFile(filename: String, fastFadeIn: Bool = false) {
        guard let url = textureURL(filename: filename) else { return }
        currentTargetVolume = volumeForTexture(filename)
        applyRandomVariation()
        if !engine.isRunning { try? engine.start() }
        do {
            let file     = try AVAudioFile(forReading: url)
            let capacity = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: capacity) else { return }
            try file.read(into: buffer)
            playerNode.volume = 0.0
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
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
        panTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.panPhase += 0.1 * 2 * .pi / period
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
        stopPan()
        playerNode.stop()
    }

    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }
}
