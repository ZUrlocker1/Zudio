// PlaybackEngine.swift — AVAudioEngine + 7 AVAudioUnitSampler nodes
// Spec §AVAudioEngine playback architecture

import AVFoundation

@MainActor
final class PlaybackEngine: ObservableObject {
    // MARK: - State

    @Published var isPlaying: Bool = false
    @Published var currentBar: Int = 0
    @Published var currentStep: Int = 0

    // MARK: - Audio graph

    private let engine      = AVAudioEngine()
    private var samplers    = [AVAudioUnitSampler]()
    private var distortions = [AVAudioUnitDistortion]()
    private var delays      = [AVAudioUnitDelay]()
    private var reverbs     = [AVAudioUnitReverb]()
    private let mixer       = AVAudioMixerNode()
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
    }

    // MARK: - Per-track effect toggle

    func setEffect(_ effect: TrackEffect, enabled: Bool, forTrack trackIndex: Int) {
        guard trackIndex < samplers.count else { return }
        switch effect {
        case .boost:
            distortions[trackIndex].wetDryMix = enabled ? 65 : 0
        case .delay:
            delays[trackIndex].wetDryMix = enabled ? 40 : 0
        case .reverb:
            reverbs[trackIndex].wetDryMix = enabled ? 50 : 0
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

        for _ in 0..<7 {
            let sampler = AVAudioUnitSampler()
            let dist    = AVAudioUnitDistortion()
            let delay   = AVAudioUnitDelay()
            let reverb  = AVAudioUnitReverb()

            // Boost: cubic waveshaping with positive preGain — clean boost + crunch
            dist.loadFactoryPreset(.multiDistortedCubed)
            dist.preGain    = 8   // drives signal into waveshaper for crunch and volume lift
            dist.wetDryMix  = 0   // off by default

            // Delay: 16th-note echo with moderate feedback
            delay.delayTime     = 0.125  // 16th note at ~120 BPM
            delay.feedback      = 40
            delay.lowPassCutoff = 6000   // tame harsh distortion harmonics
            delay.wetDryMix     = 0  // off by default

            // Reverb: large chamber for obvious spaciousness
            reverb.loadFactoryPreset(.largeChamber)
            reverb.wetDryMix = 0  // off by default

            engine.attach(sampler)
            engine.attach(dist)
            engine.attach(delay)
            engine.attach(reverb)

            // Chain: sampler → boost → delay → reverb → mixer
            engine.connect(sampler, to: dist,  format: nil)
            engine.connect(dist,    to: delay, format: nil)
            engine.connect(delay,   to: reverb, format: nil)
            engine.connect(reverb,  to: mixer, format: nil)

            samplers.append(sampler)
            distortions.append(dist)
            delays.append(delay)
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
