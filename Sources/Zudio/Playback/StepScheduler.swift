// StepScheduler.swift — DispatchSourceTimer at 16th-note resolution
// Spec §Playback timeline and step timer

import Foundation

final class StepScheduler: Sendable {
    private let engine: PlaybackEngine
    private let songState: SongState
    private var timer: DispatchSourceTimer?
    private var currentStep: Int = 0
    private let totalSteps: Int

    init(engine: PlaybackEngine, songState: SongState) {
        self.engine    = engine
        self.songState = songState
        self.totalSteps = songState.frame.totalBars * 16
    }

    func start() {
        let secondsPerStep = songState.frame.secondsPerStep
        let interval = Int(secondsPerStep * 1_000_000_000) // nanoseconds
        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        src.schedule(deadline: .now(), repeating: .nanoseconds(interval), leeway: .nanoseconds(interval / 20))
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
        guard currentStep < totalSteps else {
            stop()
            return
        }
        let step = currentStep
        let bar  = step / 16
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.engine.onStep(step, bar: bar)
        }
        currentStep += 1
    }
}
