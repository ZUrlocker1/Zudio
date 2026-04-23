// StepScheduler.swift — DispatchSourceTimer at 16th-note resolution
// Copyright (c) 2026 Zack Urlocker
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

    // Audio-clock anchoring — keeps each step's deadline locked to the hardware crystal
    // rather than accumulated from the previous tick's actual fire time.
    // Populated on the first tick (when lastRenderTime is available); falls back to
    // simple forward scheduling until the engine has rendered at least one buffer.
    private var nextStepSample: Double = 0   // absolute sample count of the next step
    private var audioSampleRate: Double = 0
    private var samplesPerStep:  Double = 0
    private var clockReady = false

    // mach_timebase_info — computed once, stable for the process lifetime.
    private let tbNum: UInt64
    private let tbDen: UInt64

    init(engine: PlaybackEngine, songState: SongState, startStep: Int = 0, schedulerID: Int = 0) {
        self.engine       = engine
        self.songState    = songState
        self.totalSteps   = songState.frame.totalBars * 16
        self.currentStep  = max(0, startStep)
        self.schedulerID  = schedulerID
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        tbNum = UInt64(info.numer)
        tbDen = UInt64(info.denom)
    }

    func start() {
        clockReady = false
        #if os(iOS)
        // iOS: one-shot timer with .strict so the OS cannot widen the leeway window
        // when backgrounded. Each tick reschedules itself using the audio hardware clock
        // to prevent the burst of catch-up ticks a repeating timer fires on screen-on.
        let src = DispatchSource.makeTimerSource(flags: .strict, queue: stepTimerQueue)
        src.schedule(deadline: .now(), repeating: .never, leeway: .nanoseconds(0))
        #else
        // Mac: simple repeating timer with ns/20 leeway so the OS can coalesce timer
        // interrupts. Mac cores don't sleep aggressively so there's no background-drift
        // problem — the one-shot overhead would burn CPU with no benefit.
        let ns = Int(songState.frame.secondsPerStep * 1_000_000_000)
        let src = DispatchSource.makeTimerSource(queue: stepTimerQueue)
        src.schedule(deadline: .now(), repeating: .nanoseconds(ns), leeway: .nanoseconds(ns / 20))
        #endif
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
        #if os(iOS)
        scheduleNextTick()
        #endif
    }

    // MARK: - Audio-clock-anchored scheduling

    /// Schedules the next tick using the audio hardware clock as reference.
    ///
    /// `engine.outputNode.lastRenderTime` provides the sample count and host time
    /// (mach_absolute_time) of the most recent audio render. From those two numbers
    /// we can compute the audio position right now, compare it to where the next step
    /// *should* fall, and schedule the timer for exactly that interval — correcting any
    /// drift that accumulated since the previous tick.
    ///
    /// If lastRenderTime is unavailable (engine not yet started), falls back to a simple
    /// .now() + stepInterval schedule so playback still begins correctly.
    private func scheduleNextTick() {
        // Declare leeway first so it's available in both the fallback and normal paths.
        #if os(iOS)
        let leeway = DispatchTimeInterval.nanoseconds(0)
        #else
        // Allow 1ms leeway on Mac so the OS can coalesce timer interrupts — restores
        // the CPU efficiency of the old repeating-timer approach without losing audio-clock anchoring.
        let leeway = DispatchTimeInterval.milliseconds(1)
        #endif

        guard let renderTime = engine.lastRenderTime,
              renderTime.isSampleTimeValid,
              renderTime.isHostTimeValid else {
            // Fallback — engine hasn't rendered yet or just restarted.
            let ns = Int(songState.frame.secondsPerStep * 1_000_000_000)
            timer?.schedule(deadline: .now() + .nanoseconds(ns),
                            repeating: .never, leeway: leeway)
            return
        }

        // Staleness check: if lastRenderTime is from before an audio interruption,
        // hostTime will be from minutes ago while mach_absolute_time() is now.
        // The resulting currentSample would be enormous, making samplesToNext hugely
        // negative and causing every tick to fire at the 10% floor — the "catch-up burst".
        // Detect this by checking how long ago the last render was. If it's more than
        // 1 second ago, the engine was paused (interrupted). Reset clockReady so we
        // re-anchor on the next tick once the engine has produced a fresh render.
        let now = mach_absolute_time()
        let elapsedTicks = now > renderTime.hostTime ? now - renderTime.hostTime : 0
        let elapsedNs    = elapsedTicks * tbNum / tbDen
        if elapsedNs > 1_000_000_000 {
            clockReady = false
            let ns = Int(songState.frame.secondsPerStep * 1_000_000_000)
            timer?.schedule(deadline: .now() + .nanoseconds(ns),
                            repeating: .never, leeway: leeway)
            return
        }

        if !clockReady {
            // First successful tick: anchor nextStepSample to current audio position.
            // Guard against a zero sample rate — can occur briefly after a route change
            // (e.g. wired CarPlay forcing 48 kHz) before the engine has produced its first
            // valid render buffer. Dividing by zero below would produce Infinity and trap
            // on Int() conversion. Fall back to wall-clock scheduling for this one tick.
            guard renderTime.sampleRate > 0 else {
                let ns = Int(songState.frame.secondsPerStep * 1_000_000_000)
                timer?.schedule(deadline: .now() + .nanoseconds(ns),
                                repeating: .never, leeway: leeway)
                return
            }
            audioSampleRate = renderTime.sampleRate
            samplesPerStep  = audioSampleRate * songState.frame.secondsPerStep
            nextStepSample  = Double(renderTime.sampleTime) + samplesPerStep
            clockReady = true
        } else {
            nextStepSample += samplesPerStep
        }

        // Estimate current audio position using the elapsed time already computed above.
        // elapsedNs = (mach_absolute_time() − renderTime.hostTime) × tbNum/tbDen
        let currentSample = Double(renderTime.sampleTime) + Double(elapsedNs) / 1e9 * audioSampleRate

        // How many samples until the next step should fire.
        // Clamp to 10% of a step so we never schedule a negative or negligible delay.
        let samplesToNext = max(samplesPerStep * 0.10, nextStepSample - currentSample)
        let nsToNext      = Int(samplesToNext / audioSampleRate * 1_000_000_000)

        timer?.schedule(deadline: .now() + .nanoseconds(nsToNext),
                        repeating: .never, leeway: leeway)
    }
}
