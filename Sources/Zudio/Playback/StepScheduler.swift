// StepScheduler.swift — DispatchSourceTimer at 16th-note resolution
// Spec §Playback timeline and step timer

import Foundation

/// Serial queue shared between the step timer and PlaybackEngine.buildStepEventMap.
/// Using one serial queue for both timer callbacks and map writes guarantees that
/// a map rebuild never races with an in-flight onStep read — the write is dispatched
/// synchronously to this queue from the main thread, so it can only execute when no
/// timer callback is running. Without this, regenerateTrack's call to load() while
/// playing could cause a data race on the Dictionary (EXC_BAD_ACCESS).
let stepTimerQueue = DispatchQueue(label: "com.zudio.step", qos: .userInteractive)

final class StepScheduler {
    private unowned let engine: PlaybackEngine
    private let songState: SongState
    private var timer: DispatchSourceTimer?
    private var currentStep: Int = 0
    private let totalSteps: Int
    private let schedulerID: Int

    init(engine: PlaybackEngine, songState: SongState, startStep: Int = 0, schedulerID: Int = 0) {
        self.engine       = engine
        self.songState    = songState
        self.totalSteps   = songState.frame.totalBars * 16
        self.currentStep  = max(0, startStep)
        self.schedulerID  = schedulerID
    }

    func start() {
        let ns = Int(songState.frame.secondsPerStep * 1_000_000_000)
        let src = DispatchSource.makeTimerSource(queue: stepTimerQueue)
        src.schedule(deadline: .now(), repeating: .nanoseconds(ns), leeway: .nanoseconds(ns / 20))
        src.setEventHandler { [weak self] in self?.tick() }
        src.resume()
        timer = src
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Tick

    private func tick() {
        let step = currentStep
        if step >= totalSteps {
            stop()
            engine.onSongEnd()
            return
        }
        engine.onStep(step, bar: step / 16, schedulerID: schedulerID)
        currentStep += 1
    }
}
