// StartGuard.swift — the one definition of how a song opens, shared by live playback and export.
//
// A song starting at step 0 gets a short silent gap, then a master-volume ramp that absorbs any
// DSP-init transient (the startup pop) and softens a loud bar 1. Kosmic had the ramp first
// (0.15 to 1.0 in five 20 ms steps); Ambient, and Motorik and Chill without an intro, now use it
// too, and the offline export applies the same numbers to its rendered audio.
//
// Live:   PlaybackEngine.play() holds the master at 0 for gapSeconds, then startPopGuardRamp().
// Export: OfflineExport writes gapSeconds of silence, then multiplies by StartGuard.gain(atSecond:).
enum StartGuard {
    /// Silence before the first note when a song starts from step 0 and has no intro fade.
    static let gapSeconds: Double = 0.200
    /// Master level at the first ramp tick.
    static let rampFloor: Float = 0.15
    static let rampSteps = 5
    static let rampStepSeconds: Double = 0.020
    static var rampSeconds: Double { Double(rampSteps) * rampStepSeconds }

    /// Master level after ramp step `i`: floor at 0, 1.0 at rampSteps, equal steps between.
    static func level(afterStep i: Int) -> Float {   // i in 0...rampSteps
        rampFloor + Float(i) / Float(rampSteps) * (1 - rampFloor)
    }

    /// Master level `t` seconds into the ramp, as live plays it: the floor for the first step,
    /// then each tick's level held until the next, reaching 1.0 at rampSeconds.
    static func gain(atSecond t: Double) -> Float {
        guard t < rampSeconds else { return 1 }
        return level(afterStep: Int(t / rampStepSeconds))
    }
}
