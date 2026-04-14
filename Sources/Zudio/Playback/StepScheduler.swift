// StepScheduler.swift — Audio-clock step scheduler
// Replaces DispatchSourceTimer with an AVAudioNode render tap.
//
// Timing is derived from AVAudioTime.sampleTime — a counter driven by the audio
// hardware crystal oscillator. Unlike mach_absolute_time() (used by DispatchSourceTimer),
// the sample clock never pauses when the iOS CPU enters a low-power sleep state.
// This eliminates the tempo drag on screen-off and the brief speed-up on screen-on
// that was most audible in Motorik and Kosmic at higher BPMs.
//
// The tap fires on AVAudioEngine's real-time I/O thread every render buffer
// (~11 ms at 44.1 kHz / 512 frames). Each callback checks whether the next
// step's sample threshold has been crossed and fires engine.onStep() if so.
//
// onSongEnd() is dispatched to the main queue — Apple forbids calling
// removeTap(onBus:) from inside a tap closure, and onSongEnd() calls stop().

import AVFoundation

final class StepScheduler {
    private unowned let engine:  PlaybackEngine
    private unowned let tapNode: AVAudioMixerNode
    private let songState:   SongState
    private var currentStep: Int = 0
    private let totalSteps:  Int
    private let schedulerID: Int
    private var tapInstalled = false

    // Audio-clock state — read/written exclusively on the render thread inside the tap.
    private var nextStepSample: AVAudioFramePosition = 0
    private var samplesPerStep: AVAudioFramePosition = 0
    private var isFirstTick  = true
    private var songEndFired = false   // prevents duplicate onSongEnd dispatches

    init(engine: PlaybackEngine, tapNode: AVAudioMixerNode,
         songState: SongState, startStep: Int = 0, schedulerID: Int = 0) {
        self.engine      = engine
        self.tapNode     = tapNode
        self.songState   = songState
        self.totalSteps  = songState.frame.totalBars * 16
        self.currentStep = max(0, startStep)
        self.schedulerID = schedulerID
    }

    func start() {
        let format = tapNode.outputFormat(forBus: 0)
        samplesPerStep = AVAudioFramePosition(format.sampleRate * songState.frame.secondsPerStep)
        isFirstTick  = true
        songEndFired = false

        tapNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] _, audioTime in
            guard let self, audioTime.isSampleTimeValid else { return }
            let now = audioTime.sampleTime
            if self.isFirstTick {
                // Align to current sample position so the first step fires immediately.
                self.nextStepSample = now
                self.isFirstTick = false
            }
            while now >= self.nextStepSample {
                let step = self.currentStep
                if step >= self.totalSteps {
                    // Dispatch to main — removeTap must not be called from inside a tap.
                    if !self.songEndFired {
                        self.songEndFired = true
                        DispatchQueue.main.async { [weak self] in self?.engine.onSongEnd() }
                    }
                    return
                }
                self.engine.onStep(step, bar: step / 16, schedulerID: self.schedulerID)
                self.currentStep    += 1
                self.nextStepSample += self.samplesPerStep
            }
        }
        tapInstalled = true
    }

    func stop() {
        guard tapInstalled else { return }
        tapNode.removeTap(onBus: 0)
        tapInstalled = false
    }
}
