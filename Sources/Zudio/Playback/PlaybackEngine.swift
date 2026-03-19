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
    private var samplers = [AVAudioUnitSampler]()
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
    private var currentSchedulerID: Int = 0

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
        // Don't reset playhead here; only reset on play/stop
    }

    func play() {
        guard !isPlaying, let state = songState else { return }
        // Resume from current playhead position (currentStep already set correctly)
        isPlaying = true
        currentSchedulerID += 1
        let sched = StepScheduler(engine: self, songState: state, startStep: currentStep, schedulerID: currentSchedulerID)
        scheduler = sched
        sched.start()
    }

    func stop() {
        scheduler?.stop()
        scheduler = nil
        isPlaying = false
        // Leave playhead in place — user can resume from here with Play
        allNotesOff()
    }

    // MARK: - Step callback (called by StepScheduler on a background queue)

    nonisolated func onStep(_ step: Int, bar: Int, schedulerID: Int) {
        Task { @MainActor [weak self] in
            guard let self, self.isPlaying, self.currentSchedulerID == schedulerID,
                  let state = self.songState else { return }
            self.currentStep = step
            self.currentBar  = bar

            // Always dispatch all events (mute is handled by sampler volume, not skipping)
            for trackIndex in 0..<7 {
                let events = state.events(forTrack: trackIndex)
                for ev in events where ev.stepIndex == step {
                    let channel = gmChannel(trackIndex)
                    self.samplers[trackIndex].startNote(ev.note, withVelocity: ev.velocity, onChannel: channel)
                    let delay = Double(ev.durationSteps) * state.frame.secondsPerStep
                    let sampler = self.samplers[trackIndex]
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        sampler.stopNote(ev.note, onChannel: channel)
                    }
                }
            }
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
            currentStep = clampedStep
            currentBar  = clampedStep / 16
            currentSchedulerID += 1
            let sched = StepScheduler(engine: self, songState: state, startStep: clampedStep, schedulerID: currentSchedulerID)
            scheduler = sched
            sched.start()
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

    func setProgram(_ program: UInt8, forTrack trackIndex: Int) {
        guard trackIndex < samplers.count else { return }
        let isDrum = (trackIndex == kTrackDrums)
        let bankMSB: UInt8 = isDrum ? 0x78 : 0x79
        try? samplers[trackIndex].loadSoundBankInstrument(
            at: gmDLSSoundBankURL(), program: program, bankMSB: bankMSB, bankLSB: 0
        )
        // Per-track default volumes; tremolo overrides this via LFO
        if !tremEnabled[trackIndex] {
            if trackIndex == kTrackBass && program == 87 {
                samplers[trackIndex].volume = 0.56   // Lead Bass runs hot
            } else if trackIndex == kTrackTexture {
                samplers[trackIndex].volume = 1.4    // Texture pads are quiet
            } else {
                samplers[trackIndex].volume = 1.0
            }
        }
    }

    // MARK: - Per-track effect toggle

    func setEffect(_ effect: TrackEffect, enabled: Bool, forTrack trackIndex: Int) {
        guard trackIndex < samplers.count else { return }
        switch effect {
        case .boost:
            boosts[trackIndex].outputVolume = enabled ? 1.7 : 1.0  // 1.7 ≈ +4.6 dB
        case .delay:
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
        case .reverb, .space:
            reverbs[trackIndex].wetDryMix = enabled ? 50 : 0
        }
    }

    // MARK: - Tremolo LFO (6 Hz sine, 50% depth, main-queue timer)

    private func startTremolo(forTrack i: Int) {
        tremEnabled[i] = true
        tremPhase[i]   = 0.0
        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        // ~60 fps ticks for smooth modulation
        src.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        src.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
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
        sweepFilters[i].auAudioUnit.shouldBypassEffect = false
        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        src.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        src.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.sweepEnabled[i] else { return }
                self.sweepPhase[i] += 0.00733   // 2π × 0.07 Hz / 60 fps
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
        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        src.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        src.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.panEnabled[i] else { return }
                self.panPhase[i] += 0.05236   // 2π × 0.5 Hz / 60 fps — ~1 sweep per bar
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

            // Reverb: cathedral for Pads, large chamber for all others
            reverb.loadFactoryPreset(i == kTrackPads ? .cathedral : .largeChamber)
            reverb.wetDryMix = 0

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
    private func gmChannel(_ trackIndex: Int) -> UInt8 {
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
}
