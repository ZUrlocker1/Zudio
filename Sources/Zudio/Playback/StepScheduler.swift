// StepScheduler.swift — DispatchSourceTimer at 16th-note resolution
// Spec §Playback timeline and step timer

import Foundation

final class StepScheduler {
    private unowned let engine: PlaybackEngine
    private let songState: SongState
    private var timer: DispatchSourceTimer?
    private var currentStep: Int = 0
    private let totalSteps: Int

    init(engine: PlaybackEngine, songState: SongState, startStep: Int = 0) {
        self.engine       = engine
        self.songState    = songState
        self.totalSteps   = songState.frame.totalBars * 16
        self.currentStep  = max(0, startStep)
    }

    func start() {
        let ns = Int(songState.frame.secondsPerStep * 1_000_000_000)
        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
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
        engine.onStep(step, bar: step / 16)
        currentStep += 1
    }
}
