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

    private let engine    = AVAudioEngine()
    private var samplers  = [AVAudioUnitSampler]()
    private let mixer     = AVAudioMixerNode()
    private var scheduler: StepScheduler?

    // MARK: - Song state (set before play)

    private(set) var songState: SongState?

    // Track mute/solo state (indexed by trackIndex)
    var muteState: [Bool] = Array(repeating: false, count: 7)
    var soloState: [Bool] = Array(repeating: false, count: 7)

    // MARK: - Init

    init() {
        setupEngine()
    }

    // MARK: - Public API

    func load(_ state: SongState) {
        stop()
        self.songState = state
        currentBar  = 0
        currentStep = 0
    }

    func play() {
        guard !isPlaying, let state = songState else { return }
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            print("AVAudioEngine start error: \(error)")
            return
        }

        isPlaying = true
        let sched = StepScheduler(engine: self, songState: state)
        scheduler = sched
        sched.start()
    }

    func stop() {
        scheduler?.stop()
        scheduler = nil
        isPlaying  = false
    }

    // MARK: - Step callback (called by StepScheduler)

    func onStep(_ step: Int, bar: Int) {
        currentStep = step
        currentBar  = bar
        guard let state = songState else { return }

        let activeTracks = activeTrackIndices()
        for trackIndex in activeTracks {
            let events = state.events(forTrack: trackIndex)
            for ev in events where ev.stepIndex == step {
                sendMIDINoteOn(note: ev.note, velocity: ev.velocity,
                               channel: UInt8(trackIndex), samplerIndex: trackIndex)
                scheduleNoteOff(note: ev.note, channel: UInt8(trackIndex),
                                samplerIndex: trackIndex, afterSteps: ev.durationSteps,
                                tempo: state.frame.tempo)
            }
        }
    }

    // MARK: - Private helpers

    private func setupEngine() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        for i in 0..<7 {
            let sampler = AVAudioUnitSampler()
            engine.attach(sampler)
            engine.connect(sampler, to: mixer, format: nil)
            samplers.append(sampler)
            loadGMProgram(trackIndex: i, sampler: sampler)
        }
    }

    private func loadGMProgram(trackIndex: Int, sampler: AVAudioUnitSampler) {
        let program = kDefaultGMPrograms[trackIndex] ?? 0
        let isDrum  = trackIndex == kTrackDrums
        try? sampler.loadSoundBankInstrument(
            at: gmDLSSoundBankURL(),
            program: program,
            bankMSB: isDrum ? UInt8(kAUSampler_DefaultMelodicBankMSB) : UInt8(kAUSampler_DefaultPercussionBankMSB),
            bankLSB: 0
        )
    }

    private func gmDLSSoundBankURL() -> URL {
        // Apple DLS GM sound bank (built-in on macOS)
        URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
    }

    private func sendMIDINoteOn(note: UInt8, velocity: UInt8, channel: UInt8, samplerIndex: Int) {
        guard samplerIndex < samplers.count else { return }
        samplers[samplerIndex].startNote(note, withVelocity: velocity, onChannel: channel)
    }

    private func scheduleNoteOff(note: UInt8, channel: UInt8, samplerIndex: Int, afterSteps: Int, tempo: Int) {
        let secondsPerStep = 60.0 / Double(tempo) / 4.0
        let delay = Double(afterSteps) * secondsPerStep
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, samplerIndex < self.samplers.count else { return }
            self.samplers[samplerIndex].stopNote(note, onChannel: channel)
        }
    }

    private func activeTrackIndices() -> [Int] {
        let anySolo = soloState.contains(true)
        return (0..<7).filter { i in
            if muteState[i] { return false }
            if anySolo { return soloState[i] }
            return true
        }
    }
}
