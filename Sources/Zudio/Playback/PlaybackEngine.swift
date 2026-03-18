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

    private let engine   = AVAudioEngine()
    private var samplers = [AVAudioUnitSampler]()
    private let mixer    = AVAudioMixerNode()
    private var scheduler: StepScheduler?

    // MARK: - Song state

    private(set) var songState: SongState?

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
        let sched = StepScheduler(engine: self, songState: state, startStep: currentStep)
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

    nonisolated func onStep(_ step: Int, bar: Int) {
        Task { @MainActor [weak self] in
            guard let self, let state = self.songState, self.isPlaying else { return }
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
            let sched = StepScheduler(engine: self, songState: state, startStep: clampedStep)
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
        let sched = StepScheduler(engine: self, songState: songState!, startStep: currentStep)
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
            let sampler = AVAudioUnitSampler()
            engine.attach(sampler)
            engine.connect(sampler, to: mixer, format: nil)
            samplers.append(sampler)
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
        URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
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
