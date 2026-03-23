// PlaybackEngine.swift — AVAudioEngine + 7 AVAudioUnitSampler nodes
// Spec §AVAudioEngine playback architecture

import AVFoundation
import AudioToolbox

@MainActor
final class PlaybackEngine: ObservableObject {
    // MARK: - State

    @Published var isPlaying: Bool = false
    @Published var currentBar: Int = 0
    @Published var currentStep: Int = 0

    // MARK: - Audio graph

    private let engine   = AVAudioEngine()
    // nonisolated(unsafe): built once in setupEngine() (main actor, before playback).
    // Read from background timer thread in onStep() — AVAudioUnitSampler is thread-safe.
    nonisolated(unsafe) private var samplers = [AVAudioUnitSampler]()
    private var boosts      = [AVAudioMixerNode]()     // outputVolume > 1 = clean gain boost; also carries pan
    private var sweepFilters = [AVAudioUnitEffect]()   // LFO-driven low-pass for Sweep effect
    private var delays      = [AVAudioUnitDelay]()
    private var comps       = [AVAudioUnitEffect]()
    private var lowEQs      = [AVAudioUnitEQ]()
    private var reverbs     = [AVAudioUnitReverb]()
    private let mixer       = AVAudioMixerNode()

    // Tremolo LFO
    private var tremEnabled = Array(repeating: false, count: 7)
    private var tremPhase   = Array(repeating: Double(0), count: 7)
    private var tremTimers  = [DispatchSourceTimer?](repeating: nil, count: 7)

    // Sweep LFO (low-pass filter cutoff modulation)
    private var sweepEnabled = Array(repeating: false, count: 7)
    private var sweepPhase   = Array(repeating: Double(0), count: 7)
    private var sweepTimers  = [DispatchSourceTimer?](repeating: nil, count: 7)

    // Pan LFO (auto-pan on boost mixer node)
    private var panEnabled  = Array(repeating: false, count: 7)
    private var panPhase    = Array(repeating: Double(0), count: 7)
    private var panTimers   = [DispatchSourceTimer?](repeating: nil, count: 7)

    // Kosmic drone fade (intro 0→1, outro 1→0 on boosts[bass] and boosts[pads])
    var kosmicStyle: Bool = false
    private var droneFadeTimers: [DispatchSourceTimer?] = [nil, nil]  // [intro, outro]
    // Body entrance fade: tracks with no intro notes fade in over 1 bar at the body downbeat
    private var bodyEntranceFadeTimer: DispatchSourceTimer? = nil

    // Step-event map: built once at load time for O(1) lookup in onStep.
    // nonisolated(unsafe): written on main actor in load(), read from background timer thread.
    // Writes always happen-before reads (load() runs before play() which starts the timer).
    nonisolated(unsafe) private var stepEventMap: [Int: [(Int, MIDIEvent)]] = [:]

    // Cached seconds-per-step from the loaded song frame — avoids accessing songState on the
    // background timer thread. Set in load() alongside stepEventMap.
    nonisolated(unsafe) private var cachedSecondsPerStep: Double = 0

    // Export tap state — allows cancelExport() to stop capture from outside the tap closure.
    // @unchecked Sendable: written on main actor, read/written from audio thread; done flag is
    // set once and only grows monotonically — no torn reads possible.
    private final class ExportTapState: @unchecked Sendable {
        var frames:        Int64 = 0
        var done:          Bool  = false
        // Fade-out: fadeStartFrame < fadeTotalFrames means a linear 0→silence fade is applied.
        // Int64.max = no fade (default for full-song export).
        var fadeStartFrame:  Int64 = Int64.max
        var fadeTotalFrames: Int64 = 0
    }
    nonisolated(unsafe) private var currentExportTap:        ExportTapState?                        = nil
    nonisolated(unsafe) private var currentExportOnComplete: (@Sendable (Error?) -> Void)?          = nil

    // Hidden intro/outro modulation: pads sweep LFO + bass slow pan (no UI change)
    private var kosmicIntroSweepPhase:   Double = 0.0
    private var kosmicIntroSweepTimer:   DispatchSourceTimer? = nil
    private var kosmicIntroBassPanPhase: Double = 0.0
    private var kosmicIntroBassPanTimer: DispatchSourceTimer? = nil

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
    private var scheduler: StepScheduler?

    // MARK: - Song state

    private(set) var songState: SongState?

    // Incremented each time a new scheduler starts. onStep tasks check this to
    // reject stale callbacks queued before a stop/seek/generate.
    // nonisolated(unsafe): written on main actor, read from background note-off closures.
    // Reads may be slightly stale (one extra stopNote at worst) — acceptable trade-off.
    nonisolated(unsafe) private(set) var currentSchedulerID: Int = 0

    // Mute/solo state indexed by trackIndex
    var muteState: [Bool] = Array(repeating: false, count: 7) {
        didSet { applyMuteState() }
    }
    var soloState: [Bool] = Array(repeating: false, count: 7) {
        didSet { applyMuteState() }
    }

    // MARK: - Init — engine starts once at launch (spec §Engine setup)

    init() {
        setupEngine()
        startEngine()
    }

    // MARK: - Public API

    func load(_ state: SongState) {
        songState = state
        cachedSecondsPerStep = state.frame.secondsPerStep
        buildStepEventMap(state: state)
        // Always restore bass+pads to full volume. Kosmic intro fade is now handled
        // purely by velocity ramp in KosmicBassGenerator / KosmicPadsGenerator —
        // no audio graph volume manipulation means zero render-thread race, zero pop.
        // Outro fade still uses samplers[x].volume (ramps down), so restore here.
        samplers[kTrackBass].volume = 1.0
        samplers[kTrackPads].volume = 1.0
        boosts[kTrackBass].outputVolume = 1.0
        boosts[kTrackPads].outputVolume = 1.0
    }

    private func buildStepEventMap(state: SongState) {
        var map: [Int: [(Int, MIDIEvent)]] = [:]
        for trackIndex in 0..<7 {
            for ev in state.events(forTrack: trackIndex) {
                map[ev.stepIndex, default: []].append((trackIndex, ev))
            }
        }
        stepEventMap = map
    }

    func play() {
        guard !isPlaying, let state = songState else { return }
        // Resume from current playhead position (currentStep already set correctly)
        isPlaying = true
        currentSchedulerID += 1
        let sched = StepScheduler(engine: self, songState: state, startStep: currentStep, schedulerID: currentSchedulerID)
        scheduler = sched
        sched.start()
        if kosmicStyle { startKosmicDroneFades(state: state) }
    }

    func stop() {
        scheduler?.stop()
        scheduler = nil
        isPlaying = false
        // Leave playhead in place — user can resume from here with Play
        allNotesOff()
        stopKosmicDroneFades()
    }

    // MARK: - Step callback (called by StepScheduler on a background queue)

    nonisolated func onStep(_ step: Int, bar: Int, schedulerID: Int) {
        guard currentSchedulerID == schedulerID else { return }
        // Fire note-ons directly from the timer thread — AVAudioUnitSampler.startNote()
        // is thread-safe (lock-free MIDI ring buffer consumed by the audio render thread).
        let sps = cachedSecondsPerStep
        for (trackIndex, ev) in stepEventMap[step] ?? [] {
            let channel = gmChannel(trackIndex)
            // Machine Kit (GM program 24) has harsh kick/snare at full velocity — scale down
            let fireVelocity: UInt8
            if trackIndex == kTrackDrums && cachedDrumProgram == 24 {
                fireVelocity = UInt8(max(1, Int(ev.velocity) * 78 / 100))
            } else {
                fireVelocity = ev.velocity
            }
            samplers[trackIndex].startNote(ev.note, withVelocity: fireVelocity, onChannel: channel)
            let sampler = samplers[trackIndex]
            let noteOffDelay = Double(ev.durationSteps) * sps
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + noteOffDelay) {
                guard self.currentSchedulerID == schedulerID else { return }
                sampler.stopNote(ev.note, onChannel: channel)
            }
        }
        // Minimal main-actor hop: only update @Published playhead position
        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentSchedulerID == schedulerID else { return }
            self.currentStep = step
            self.currentBar  = bar
        }
    }

    // Called by StepScheduler when song ends — leave playhead at end position so
    // atLimit closures in HoldRepeater see the final bar and stop correctly.
    // AppState.play() detects the end position and rewinds to bar 1 before playing.
    nonisolated func onSongEnd() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.scheduler?.stop()
            self.scheduler = nil
            self.isPlaying = false
            // Keep currentStep / currentBar at their last-set values (end of song)
            self.allNotesOff()
            self.stopKosmicDroneFades()
        }
    }

    // MARK: - Seek (restart scheduler from a new position)

    func seek(toStep newStep: Int) {
        guard let state = songState else { return }
        let totalSteps = state.frame.totalBars * 16
        let clampedStep = max(0, min(newStep, totalSteps - 1))
        if isPlaying {
            scheduler?.stop()
            scheduler = nil
            allNotesOff()
            stopKosmicDroneFades()
            currentStep = clampedStep
            currentBar  = clampedStep / 16
            currentSchedulerID += 1
            let sched = StepScheduler(engine: self, songState: state, startStep: clampedStep, schedulerID: currentSchedulerID)
            scheduler = sched
            sched.start()
            if kosmicStyle { startKosmicDroneFades(state: state) }
        } else {
            currentStep = clampedStep
            currentBar  = clampedStep / 16
        }
    }

    // MARK: - Real-time tempo change

    /// Updates the step-timer interval to match a new BPM without restarting the song.
    /// If playing, the current scheduler is swapped out from the current playhead position.
    func setTempo(_ bpm: Int) {
        guard let state = songState else { return }
        let newFrame = state.frame.withTempo(bpm)
        songState = state.withFrame(newFrame)
        guard isPlaying else { return }
        scheduler?.stop()
        scheduler = nil
        allNotesOff()
        currentSchedulerID += 1
        let sched = StepScheduler(engine: self, songState: songState!, startStep: currentStep, schedulerID: currentSchedulerID)
        scheduler = sched
        sched.start()
    }

    // MARK: - Instrument program change (called from TrackRowView via AppState)

    // Cache the currently-loaded program per sampler to skip redundant loadSoundBankInstrument
    // calls. loadSoundBankInstrument is expensive (SF2 parse + audio buffer alloc), and
    // TrackRowView always resets to program index 0 on generate — the same program every time.
    private var currentProgram: [UInt8] = Array(repeating: 255, count: 7)   // 255 = "not yet loaded"
    private var currentBankMSB: [UInt8] = Array(repeating: 0,   count: 7)
    // Cached drum program for nonisolated onStep (written on main actor in setProgram, read from timer thread)
    nonisolated(unsafe) private var cachedDrumProgram: UInt8 = 255

    func setProgram(_ program: UInt8, forTrack trackIndex: Int) {
        guard trackIndex < samplers.count else { return }
        let isDrum = (trackIndex == kTrackDrums)
        let bankMSB: UInt8 = isDrum ? 0x78 : 0x79
        // Skip if the sampler already has this exact program loaded
        if program == currentProgram[trackIndex] && bankMSB == currentBankMSB[trackIndex] { return }
        currentProgram[trackIndex] = program
        currentBankMSB[trackIndex] = bankMSB
        if trackIndex == kTrackDrums { cachedDrumProgram = program }
        try? samplers[trackIndex].loadSoundBankInstrument(
            at: gmDLSSoundBankURL(), program: program, bankMSB: bankMSB, bankLSB: 0
        )
        // Per-track default volumes; tremolo overrides this via LFO
        if !tremEnabled[trackIndex] {
            if trackIndex == kTrackBass && program == 87 {
                samplers[trackIndex].volume = 0.56   // Lead Bass runs hot
            } else if trackIndex == kTrackBass && program == 42 {
                samplers[trackIndex].volume = 0.45   // Cello runs significantly louder than synth basses
            } else if trackIndex == kTrackTexture {
                samplers[trackIndex].volume = 1.4    // Texture pads are quiet
            } else {
                samplers[trackIndex].volume = 1.0
            }
        }
        // Re-apply mute/solo state — loadSoundBankInstrument resets the sampler node
        applyMuteState()
    }

    // MARK: - Per-track effect toggle

    func setEffect(_ effect: TrackEffect, enabled: Bool, forTrack trackIndex: Int) {
        guard trackIndex < samplers.count else { return }
        switch effect {
        case .boost:
            boosts[trackIndex].outputVolume = enabled ? 1.7 : 1.0  // 1.7 ≈ +4.6 dB
        case .delay:
            delays[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
            delays[trackIndex].wetDryMix = enabled ? 40 : 0
        case .sweep:
            if enabled { startSweep(forTrack: trackIndex) }
            else       { stopSweep(forTrack: trackIndex) }
        case .pan:
            if enabled { startPan(forTrack: trackIndex) }
            else       { stopPan(forTrack: trackIndex) }
        case .tremolo:
            if enabled { startTremolo(forTrack: trackIndex) }
            else       { stopTremolo(forTrack: trackIndex) }
        case .compression:
            comps[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
        case .lowShelf:
            lowEQs[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
        case .reverb:
            reverbs[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
            reverbs[trackIndex].wetDryMix = enabled ? 50 : 0
        case .space:
            reverbs[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
            reverbs[trackIndex].wetDryMix = enabled ? 70 : 0
        }
    }

    // MARK: - Tremolo LFO (6 Hz sine, 50% depth, main-queue timer)

    private func startTremolo(forTrack i: Int) {
        tremEnabled[i] = true
        tremPhase[i]   = 0.0
        tremTimers[i]?.cancel()
        tremTimers[i] = nil
        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        // ~60 fps ticks for smooth modulation
        src.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        src.setEventHandler { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.tremEnabled[i] else { return }
                self.tremPhase[i] += 0.8378  // 2π × 8 Hz / 60 fps
                // Respect mute/solo state — don't overwrite a muted track's 0 volume
                let anySolo = self.soloState.contains(true)
                let muted = self.muteState[i] || (anySolo && !self.soloState[i])
                if muted {
                    self.samplers[i].volume = 0.0
                } else {
                    // Volume oscillates between 0.20 and 1.00
                    let vol = Float(1.0 - 0.40 * (1.0 + sin(self.tremPhase[i])))
                    self.samplers[i].volume = vol
                }
            }
        }
        src.resume()
        tremTimers[i] = src
    }

    private func stopTremolo(forTrack i: Int) {
        tremEnabled[i] = false
        tremTimers[i]?.cancel()
        tremTimers[i] = nil
        tremPhase[i]   = 0.0
        samplers[i].volume = 1.0
    }

    // MARK: - Sweep LFO (0.07 Hz sine, cutoff 300–3500 Hz, slight resonance)

    private func startSweep(forTrack i: Int) {
        sweepEnabled[i] = true
        sweepPhase[i]   = 0.0
        sweepTimers[i]?.cancel()
        sweepTimers[i] = nil
        sweepFilters[i].auAudioUnit.shouldBypassEffect = false
        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        // 50ms / 20fps — at 0.07 Hz the audible difference from 60fps is zero
        src.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
        src.setEventHandler { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.sweepEnabled[i] else { return }
                self.sweepPhase[i] += 0.02199   // 2π × 0.07 Hz / 20 fps
                let cutoff = Float(300 + 1600 * (1 + sin(self.sweepPhase[i])))  // 300–3500 Hz
                AudioUnitSetParameter(self.sweepFilters[i].audioUnit, 0, kAudioUnitScope_Global, 0, cutoff, 0)
            }
        }
        src.resume()
        sweepTimers[i] = src
    }

    private func stopSweep(forTrack i: Int) {
        sweepEnabled[i] = false
        sweepTimers[i]?.cancel()
        sweepTimers[i] = nil
        sweepPhase[i]  = 0.0
        sweepFilters[i].auAudioUnit.shouldBypassEffect = true
        AudioUnitSetParameter(sweepFilters[i].audioUnit, 0, kAudioUnitScope_Global, 0, 6000, 0)
    }

    // MARK: - Pan LFO (0.15 Hz sine, sweeps −1.0 to +1.0)

    private func startPan(forTrack i: Int) {
        panEnabled[i] = true
        panPhase[i]   = 0.0
        panTimers[i]?.cancel()
        panTimers[i] = nil
        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        // 50ms / 20fps — at 0.5 Hz the audible difference from 60fps is zero
        src.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
        src.setEventHandler { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.panEnabled[i] else { return }
                self.panPhase[i] += 0.15708   // 2π × 0.5 Hz / 20 fps — ~1 sweep per bar
                self.boosts[i].pan = Float(sin(self.panPhase[i]))
            }
        }
        src.resume()
        panTimers[i] = src
    }

    private func stopPan(forTrack i: Int) {
        panEnabled[i] = false
        panTimers[i]?.cancel()
        panTimers[i] = nil
        panPhase[i]  = 0.0
        boosts[i].pan = 0.0
    }

    // MARK: - Kosmic Drone Fade (intro/outro continuous note with boost volume ramp)
    // Uses boosts[kTrackBass/kTrackPads].outputVolume (separate from sampler mute volume).
    // Intro: 0 → 1 over the intro section duration.
    // Outro: 1 → 0 over the outro section duration.

    private func startKosmicDroneFades(state: SongState) {
        stopKosmicDroneFades()
        startKosmicIntroEffects()
        let schedulerID = currentSchedulerID

        // Schedule the body entrance fade to fire exactly at the intro/body boundary.
        // Bass+pads now use velocity ramp (in generators) so only non-bass/pads cold-entrant
        // tracks need the entrance fade.
        if let intro = state.structure.introSection {
            let introEndStep    = intro.endBar * 16
            let stepsUntilBody  = max(0, introEndStep - currentStep)
            let delayToBody     = Double(stepsUntilBody) * state.frame.secondsPerStep
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delayToBody) {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isPlaying, self.currentSchedulerID == schedulerID else { return }
                    self.stopKosmicIntroEffects()
                    self.startBodyEntranceFade(state: state, schedulerID: schedulerID)
                }
            }
        }

        startOutroDroneFade(state: state, schedulerID: schedulerID)
    }

    private func startOutroDroneFade(state: SongState, schedulerID: Int) {
        guard let outro = state.structure.outroSection else { return }
        let outroStartStep = outro.startBar * 16
        let outroEndStep   = outro.endBar   * 16
        let totalSteps     = outroEndStep - outroStartStep
        guard totalSteps > 0, currentStep < outroEndStep else { return }

        let sps             = state.frame.secondsPerStep
        let stepsUntilStart = max(0, outroStartStep - currentStep)
        let delaySeconds    = Double(stepsUntilStart) * sps

        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isPlaying, self.currentSchedulerID == schedulerID else { return }
                guard self.droneFadeTimers[1] == nil else { return }

                let elapsedInOutro = max(0, self.currentStep - outroStartStep)
                let startProgress  = Float(1.0 - Double(elapsedInOutro) / Double(totalSteps))
                let remainingSecs  = Double(totalSteps - elapsedInOutro) * sps
                let startNanos     = DispatchTime.now().uptimeNanoseconds

                self.samplers[kTrackBass].volume = startProgress
                self.samplers[kTrackPads].volume = startProgress
                self.startKosmicIntroEffects()

                let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
                src.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
                src.setEventHandler { [weak self] in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.currentSchedulerID == schedulerID else { return }
                        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000_000.0
                        let linearFade = Float(max(0.0, 1.0 - elapsed / max(0.001, remainingSecs)))
                        let vol = startProgress * linearFade
                        let anySolo = self.soloState.contains(true)
                        for trackIdx in [kTrackBass, kTrackPads] {
                            let muted = self.muteState[trackIdx] || (anySolo && !self.soloState[trackIdx])
                            self.samplers[trackIdx].volume = muted ? 0.0 : vol
                        }
                        if linearFade <= 0.0 {
                            self.droneFadeTimers[1]?.cancel()
                            self.droneFadeTimers[1] = nil
                            self.stopKosmicIntroEffects()
                        }
                    }
                }
                src.resume()
                self.droneFadeTimers[1] = src
            }
        }
    }

    private func stopKosmicDroneFades() {
        droneFadeTimers[0]?.cancel()
        droneFadeTimers[0] = nil
        droneFadeTimers[1]?.cancel()
        droneFadeTimers[1] = nil
        bodyEntranceFadeTimer?.cancel()
        bodyEntranceFadeTimer = nil
        stopKosmicIntroEffects()
        applyMuteState()
    }

    // MARK: - Kosmic body entrance fade
    // Tracks that have no events in the intro section enter cold at the body downbeat.
    // This fades their sampler volume 0→1 over 1 bar so the entrance is smooth, not a slam.

    private func startBodyEntranceFade(state: SongState, schedulerID: Int) {
        guard let intro = state.structure.introSection else { return }
        let introEndStep = intro.endBar * 16

        // Identify tracks with no intro events — they're "cold entrants" at the body start.
        var tracksToFade: [Int] = []
        for i in 0..<7 {
            guard i != kTrackBass && i != kTrackPads else { continue }  // drone tracks handled separately
            let hasIntroNotes = (0..<introEndStep).contains { step in
                stepEventMap[step]?.contains { $0.0 == i } ?? false
            }
            if !hasIntroNotes { tracksToFade.append(i) }
        }
        guard !tracksToFade.isEmpty else { return }

        // Silence them now; the timer will ramp them up.
        for i in tracksToFade { samplers[i].volume = 0.0 }

        let fadeSecs  = Double(8) * state.frame.secondsPerStep  // half bar — quick entrance, not a slam
        let startNanos = DispatchTime.now().uptimeNanoseconds

        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        src.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
        src.setEventHandler { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentSchedulerID == schedulerID else { return }
                let elapsed  = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000_000.0
                let progress = min(1.0, elapsed / max(0.001, fadeSecs))
                let curved   = Float(Foundation.sqrt(progress))
                let anySolo  = self.soloState.contains(true)
                for i in tracksToFade {
                    let muted = self.muteState[i] || (anySolo && !self.soloState[i])
                    self.samplers[i].volume = muted ? 0.0 : curved
                }
                if progress >= 1.0 {
                    self.bodyEntranceFadeTimer?.cancel()
                    self.bodyEntranceFadeTimer = nil
                    self.applyMuteState()  // restore authoritative mute/solo volumes
                }
            }
        }
        src.resume()
        bodyEntranceFadeTimer = src
    }

    // MARK: - Kosmic hidden intro/outro effects (pads sweep + bass slow pan)
    // Activated during intro/outro drone sections only — no UI state change.

    private func startKosmicIntroEffects() {
        // Cancel any already-running intro effect timers (safe to restart)
        kosmicIntroSweepTimer?.cancel()
        kosmicIntroSweepTimer = nil
        kosmicIntroBassPanTimer?.cancel()
        kosmicIntroBassPanTimer = nil

        // Pads: sweep LFO (0.07 Hz, cutoff 400–3200 Hz) — same rate as user sweep chip
        // Only activate if the user hasn't already enabled sweep on pads (avoid double-timer)
        if !sweepEnabled[kTrackPads] {
            kosmicIntroSweepPhase = 0.0
            sweepFilters[kTrackPads].auAudioUnit.shouldBypassEffect = false
            let sweepSrc = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
            sweepSrc.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
            sweepSrc.setEventHandler { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.kosmicIntroSweepPhase += 0.02199  // 2π × 0.07 Hz / 20 fps
                    let cutoff = Float(400 + 1400 * (1 + sin(self.kosmicIntroSweepPhase)))  // 400–3200 Hz
                    AudioUnitSetParameter(self.sweepFilters[kTrackPads].audioUnit,
                                         0, kAudioUnitScope_Global, 0, cutoff, 0)
                }
            }
            sweepSrc.resume()
            kosmicIntroSweepTimer = sweepSrc
        }

        // Bass: very slow pan (0.05 Hz, ±0.5) — gentle spatial drift, one sweep per 20 sec
        if !panEnabled[kTrackBass] {
            kosmicIntroBassPanPhase = 0.0
            let panSrc = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
            panSrc.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
            panSrc.setEventHandler { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.kosmicIntroBassPanPhase += 0.01571  // 2π × 0.05 Hz / 20 fps
                    self.boosts[kTrackBass].pan = Float(0.5 * sin(self.kosmicIntroBassPanPhase))
                }
            }
            panSrc.resume()
            kosmicIntroBassPanTimer = panSrc
        }
    }

    private func stopKosmicIntroEffects() {
        kosmicIntroSweepTimer?.cancel()
        kosmicIntroSweepTimer = nil
        kosmicIntroSweepPhase = 0.0
        if !sweepEnabled[kTrackPads] {
            sweepFilters[kTrackPads].auAudioUnit.shouldBypassEffect = true
            AudioUnitSetParameter(sweepFilters[kTrackPads].audioUnit,
                                  0, kAudioUnitScope_Global, 0, 6000, 0)
        }

        kosmicIntroBassPanTimer?.cancel()
        kosmicIntroBassPanTimer = nil
        kosmicIntroBassPanPhase = 0.0
        if !panEnabled[kTrackBass] {
            boosts[kTrackBass].pan = 0.0
        }
    }

    // MARK: - All-notes-off (used by stop())

    private func allNotesOff() {
        for (i, sampler) in samplers.enumerated() {
            let ch = gmChannel(i)
            // CC 120 = All Sound Off, CC 123 = All Notes Off
            sampler.sendController(120, withValue: 0, onChannel: ch)
            sampler.sendController(123, withValue: 0, onChannel: ch)
        }
    }

    // MARK: - Private setup

    private func setupEngine() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        for i in 0..<7 {
            let sampler      = AVAudioUnitSampler()
            let boost        = AVAudioMixerNode()   // outputVolume > 1 = boost; pan = auto-pan
            let sweepFilter  = AVAudioUnitEffect(audioComponentDescription: Self.lpDesc)
            let delay        = AVAudioUnitDelay()
            let comp         = AVAudioUnitEffect(audioComponentDescription: Self.compDesc)
            let lowEQ        = AVAudioUnitEQ(numberOfBands: 1)
            let reverb       = AVAudioUnitReverb()

            // Boost: unity gain, centre pan by default
            boost.outputVolume = 1.0
            boost.pan          = 0.0

            // Sweep filter: high cutoff (open), slight resonance for Moog character, bypassed until enabled
            AudioUnitSetParameter(sweepFilter.audioUnit, 0, kAudioUnitScope_Global, 0, 6000, 0) // cutoff Hz
            AudioUnitSetParameter(sweepFilter.audioUnit, 1, kAudioUnitScope_Global, 0,  3.0, 0) // resonance dB
            sweepFilter.auAudioUnit.shouldBypassEffect = true

            // Delay: 16th-note echo, rolled off above 6kHz
            delay.delayTime     = 0.125
            delay.feedback      = 40
            delay.lowPassCutoff = 6000
            delay.wetDryMix     = 0
            delay.auAudioUnit.shouldBypassEffect = true

            // Comp: threshold -15 dB, fast attack (2 ms), moderate release (80 ms), +4 dB makeup
            AudioUnitSetParameter(comp.audioUnit, 0, kAudioUnitScope_Global, 0, -15.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 1, kAudioUnitScope_Global, 0,   5.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 2, kAudioUnitScope_Global, 0,   1.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 4, kAudioUnitScope_Global, 0, 0.002, 0)
            AudioUnitSetParameter(comp.audioUnit, 5, kAudioUnitScope_Global, 0,  0.08, 0)
            AudioUnitSetParameter(comp.audioUnit, 6, kAudioUnitScope_Global, 0,   4.0, 0)
            comp.auAudioUnit.shouldBypassEffect = true

            // Low shelf: +5 dB at 80 Hz, bypassed until enabled
            lowEQ.bands[0].filterType = .lowShelf
            lowEQ.bands[0].frequency  = 80
            lowEQ.bands[0].gain       = 5.0
            lowEQ.bands[0].bypass     = false
            lowEQ.auAudioUnit.shouldBypassEffect = true

            // Reverb: cathedral for atmospheric tracks (Lead1, Lead2, Pads, Texture);
            // large chamber for rhythmic tracks (Rhythm, Bass, Drums)
            let atmosphericTracks: Set<Int> = [kTrackLead1, kTrackLead2, kTrackPads, kTrackTexture]
            reverb.loadFactoryPreset(atmosphericTracks.contains(i) ? .cathedral : .largeChamber)
            reverb.wetDryMix = 0
            reverb.auAudioUnit.shouldBypassEffect = true

            engine.attach(sampler)
            engine.attach(boost)
            engine.attach(sweepFilter)
            engine.attach(delay)
            engine.attach(comp)
            engine.attach(lowEQ)
            engine.attach(reverb)

            // Chain: sampler → boost → sweep → delay → comp → lowEQ → reverb → mixer
            engine.connect(sampler,     to: boost,       format: nil)
            engine.connect(boost,       to: sweepFilter, format: nil)
            engine.connect(sweepFilter, to: delay,       format: nil)
            engine.connect(delay,       to: comp,        format: nil)
            engine.connect(comp,        to: lowEQ,       format: nil)
            engine.connect(lowEQ,       to: reverb,      format: nil)
            engine.connect(reverb,      to: mixer,       format: nil)

            samplers.append(sampler)
            boosts.append(boost)
            sweepFilters.append(sweepFilter)
            delays.append(delay)
            comps.append(comp)
            lowEQs.append(lowEQ)
            reverbs.append(reverb)
        }
        loadGMPrograms()
    }

    private func startEngine() {
        do { try engine.start() }
        catch { print("AVAudioEngine start error: \(error)") }
    }

    private func loadGMPrograms() {
        let bankURL = gmDLSSoundBankURL()
        for i in 0..<7 {
            let program = kDefaultGMPrograms[i] ?? 0
            let isDrum  = (i == kTrackDrums)
            // bankMSB: 0x79 = melodic GM, 0x78 = percussion (GM drum channel 10)
            let bankMSB: UInt8 = isDrum ? 0x78 : 0x79
            // Texture pads tend to be quiet — boost their default volume
            if i == kTrackTexture { samplers[i].volume = 1.4 }
            try? samplers[i].loadSoundBankInstrument(
                at: bankURL, program: program, bankMSB: bankMSB, bankLSB: 0
            )
            // Seed the cache so setProgram() skips redundant reloads of the startup defaults
            currentProgram[i] = program
            currentBankMSB[i] = bankMSB
        }
    }

    private func gmDLSSoundBankURL() -> URL {
        // Prefer bundled GeneralUser GS SF2 for higher quality.
        // To roll back: delete the SF2 from Resources — this fallback restores the Apple DLS bank.
        if let sf2 = Bundle.main.url(forResource: "GeneralUser_GS_v1.471", withExtension: "sf2") {
            return sf2
        }
        return URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
    }

    /// Spec: MIDI channel assignment — drums must use channel 9 (GM drums).
    nonisolated private func gmChannel(_ trackIndex: Int) -> UInt8 {
        trackIndex == kTrackDrums ? 9 : UInt8(trackIndex)
    }

    /// Spec §Mute and Solo: set sampler output volume to 0; keep dispatching events for sync.
    private func applyMuteState() {
        let anySolo = soloState.contains(true)
        for i in 0..<samplers.count {
            let muted = muteState[i] || (anySolo && !soloState[i])
            samplers[i].volume = muted ? 0.0 : 1.0
        }
    }

    // MARK: - Audio export (real-time tap capture)

    /// Records the song by tapping the main mixer output during live playback.
    /// Captures exactly what the user hears — all effects, reverb, and samplers are live.
    ///
    /// A 500 ms pre-delay is inserted after stop() before the tap starts — this lets reverb
    /// tails from prior playback drain to silence so they never bleed into the recorded file.
    ///
    /// Full-song mode adds a 2.5-second reverb tail after the last bar.
    /// Sample mode captures up to 60 seconds with a 5-second linear fade-out at the end.
    func exportAudio(
        url: URL,
        state: SongState,
        sampleMode: Bool = false,
        onProgress: @escaping @Sendable (Double) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        stop()
        // Increment schedulerID to invalidate any pending onStep async blocks from the
        // previous playback session — they check this ID before writing currentStep and
        // would otherwise race to overwrite the 0 we set here.
        currentSchedulerID += 1
        currentStep = 0
        currentBar  = 0

        // Store callback now so cancelExport() works even during the pre-delay window.
        currentExportOnComplete = onComplete

        // 500 ms silence: lets cathedral/chamber reverb tails from prior playback decay
        // before the tap opens. The engine keeps running; samplers are silent via allNotesOff.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.currentExportOnComplete != nil else { return }
            self.installExportTap(url: url, state: state, sampleMode: sampleMode,
                                  onProgress: onProgress, onComplete: onComplete)
        }
    }

    private func installExportTap(
        url: URL,
        state: SongState,
        sampleMode: Bool,
        onProgress: @escaping @Sendable (Double) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        let mixerNode       = engine.mainMixerNode
        let tapFormat       = mixerNode.outputFormat(forBus: 0)
        let sr              = tapFormat.sampleRate
        let sps             = state.frame.secondsPerStep
        let songMusicFrames = Int64(Double(state.frame.totalBars * 16) * sr * sps)

        let musicFrames:    Int64
        let totalFrames:    Int64
        let fadeStartFrame: Int64

        if sampleMode {
            musicFrames    = min(songMusicFrames, Int64(60.0 * sr))
            totalFrames    = musicFrames
            fadeStartFrame = max(0, musicFrames - Int64(5.0 * sr))
        } else {
            musicFrames    = songMusicFrames
            totalFrames    = musicFrames + Int64(sr * 2.5)
            fadeStartFrame = Int64.max
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey:         kAudioFormatMPEG4AAC,
            AVSampleRateKey:       sr,
            AVNumberOfChannelsKey: tapFormat.channelCount,
            AVEncoderBitRateKey:   128_000
        ]
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: outputSettings)
        } catch {
            currentExportOnComplete = nil
            onComplete(error)
            return
        }

        let tapState = ExportTapState()
        tapState.fadeStartFrame  = fadeStartFrame
        tapState.fadeTotalFrames = totalFrames
        currentExportTap        = tapState

        mixerNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buf, _ in
            guard !tapState.done else { return }
            let remaining = totalFrames - tapState.frames
            guard remaining > 0 else { return }
            if Int64(buf.frameLength) > remaining {
                buf.frameLength = AVAudioFrameCount(remaining)
            }

            // Linear fade-out for sample mode.
            let bufStart = tapState.frames
            let fadeLen  = tapState.fadeTotalFrames - tapState.fadeStartFrame
            if fadeLen > 0 && bufStart + Int64(buf.frameLength) > tapState.fadeStartFrame,
               let channelData = buf.floatChannelData {
                let nch = Int(buf.format.channelCount)
                for i in 0..<Int(buf.frameLength) {
                    let absFrame = bufStart + Int64(i)
                    if absFrame >= tapState.fadeStartFrame {
                        let t      = Float(absFrame - tapState.fadeStartFrame) / Float(fadeLen)
                        let factor = max(0.0, 1.0 - t)
                        for ch in 0..<nch { channelData[ch][i] *= factor }
                    }
                }
            }

            do {
                try audioFile.write(from: buf)
            } catch {
                tapState.done = true
                Task { @MainActor [weak self] in
                    self?.finishExport(onComplete: onComplete, error: error)
                }
                return
            }
            tapState.frames += Int64(buf.frameLength)
            onProgress(min(1.0, Double(tapState.frames) / Double(musicFrames)))
            if tapState.frames >= totalFrames {
                tapState.done = true
                Task { @MainActor [weak self] in
                    self?.finishExport(onComplete: onComplete, error: nil)
                }
            }
        }

        load(state)
        play()
    }

    /// Cancels an in-progress export (including during the pre-delay window before the tap opens).
    /// AppState is responsible for deleting the partial file on cancel.
    func cancelExport() {
        if let ts = currentExportTap, !ts.done {
            // Tap is installed — stop it.
            ts.done = true
            currentExportTap = nil
            let cb = currentExportOnComplete
            currentExportOnComplete = nil
            engine.mainMixerNode.removeTap(onBus: 0)
            stop()
            cb?(CancellationError())
        } else if let cb = currentExportOnComplete {
            // Cancel during pre-delay — tap not yet installed, no file written yet.
            currentExportOnComplete = nil
            cb(CancellationError())
        }
    }

    private func finishExport(onComplete: @Sendable (Error?) -> Void, error: Error?) {
        currentExportTap        = nil
        currentExportOnComplete = nil
        engine.mainMixerNode.removeTap(onBus: 0)
        stop()
        onComplete(error)
    }
}
