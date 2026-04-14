// PatternEvolver.swift — generation step 12
// Applies gradual pattern mutation to the bass track across evolution windows.
//
// Inspired by Glass/Reich additive-subtractive process, Tangerine Dream sequencer drift,
// and the Autechre principle: "not random but based on sets of rules we have a good handle on."
//
// The evolver divides the song into windows (8, 16, or 32 bars — chosen once per song).
// Within each window, up to two operators fire, whose intensity follows an arc:
//
//   evolveReset:   ramps to 1.0 over 60% of window, then drops to 0 (pattern flowers, returns).
//   evolveHold:    ramps to 1.0 over 40%, holds at peak (pattern transforms and stays).
//   evolveReverse: triangle — peaks at window midpoint, then returns (symmetric evolution).
//
// Operators (selected based on busyness of the bass pattern):
//
//   Thin       — removes 1–2 non-anchor events per bar at peak intensity.
//                Triggered when busyness ≥ 0.60 (busy patterns: BAS-005/007/008/010/011).
//                Protects beats 1 (step 0) and 3 (step 8) — the groove anchors.
//
//   Fill       — inserts a short scale-adjacent passing note on an off-beat step.
//                Triggered when busyness ≤ 0.40 (sparse patterns: BAS-001/002/003/004/006).
//                Restricted to off-beat 8th positions (steps 2, 6, 10, 14).
//
//   Substitute — replaces one non-anchor note's pitch with the adjacent scale degree.
//                Available at all busyness levels (60% probability per window).
//                Direction (+1 / -1 scale degree) is fixed for the whole window.
//
//   Rotate     — shifts all non-beat1 notes by ±1–2 steps, accumulating across the window.
//                Available with 35% probability; only on windows ≥ 8 bars.
//                The evolve-reset arc reverses the rotation on the descent.
//
// Performance: events are pre-indexed into a [bar → [MIDIEvent]] dictionary once at the
// top of apply(). All per-bar operations do O(1) dictionary lookups instead of O(n_events)
// filter scans. The tonal map is also pre-indexed per bar. Total work drops from O(n² ) to O(n).

struct PatternEvolver {

    static func apply(
        trackEvents: [[MIDIEvent]],
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        seed: UInt64
    ) -> [[MIDIEvent]] {
        var rng = SeededRNG(seed: seed &+ 0xCAFE_BABE_7654_3210)
        var events = trackEvents

        // Window size chosen once per song: 8 bars (15%), 16 bars (50%), 32 bars (35%).
        let windowSize = [8, 16, 32][rng.weightedPick([0.15, 0.50, 0.35])]

        // Pre-index bass events by bar — eliminates repeated O(n_events) filter scans.
        var barDict = buildBarDict(events[kTrackBass])

        // Pre-index tonal map by bar — replaces O(n_windows) linear scan per bar.
        let entryForBar = tonalMap.barEntryMap(totalBars: frame.totalBars)

        // Busyness: avg events per body bar, normalised so 8 events/bar = 1.0
        let busyness = measureBusyness(barDict, frame: frame, structure: structure)

        var bar = 0
        while bar < frame.totalBars {
            let windowEnd = min(bar + windowSize, frame.totalBars)
            evolveWindow(
                &barDict,
                startBar: bar, endBar: windowEnd,
                frame: frame, structure: structure, entryForBar: entryForBar,
                busyness: busyness, rng: &rng
            )
            bar = windowEnd
        }

        // Reconstruct flat sorted array from bar dictionary.
        events[kTrackBass] = barDict.values
            .flatMap { $0 }
            .sorted { $0.stepIndex < $1.stepIndex }
        return events
    }

    // MARK: - Bar indexing

    /// Buckets events by bar number for O(1) per-bar access.
    private static func buildBarDict(_ events: [MIDIEvent]) -> [Int: [MIDIEvent]] {
        var dict = [Int: [MIDIEvent]]()
        dict.reserveCapacity(max(1, events.count / 4))
        for ev in events {
            dict[ev.stepIndex / 16, default: []].append(ev)
        }
        return dict
    }

    // MARK: - Busyness

    private static func measureBusyness(
        _ barDict: [Int: [MIDIEvent]], frame: GlobalMusicalFrame, structure: SongStructure
    ) -> Double {
        var bodyBars = 0
        var total    = 0
        for bar in 0..<frame.totalBars {
            guard let sec = structure.section(atBar: bar),
                  sec.label != .intro && sec.label != .outro else { continue }
            bodyBars += 1
            total += (barDict[bar] ?? []).count   // O(1) — no filter scan
        }
        guard bodyBars > 0 else { return 0.5 }
        return min(1.0, Double(total) / Double(bodyBars) / 8.0)
    }

    // MARK: - Window evolution

    private static func evolveWindow(
        _ barDict: inout [Int: [MIDIEvent]],
        startBar: Int, endBar: Int,
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        entryForBar: [Int: TonalGovernanceEntry],
        busyness: Double,
        rng: inout SeededRNG
    ) {
        let windowLen = endBar - startBar
        guard windowLen >= 4 else { return }

        // Arc: 0 = evolve-reset, 1 = evolve-hold, 2 = evolve-reverse
        let arcType = rng.weightedPick([0.40, 0.35, 0.25])

        // Operator availability
        let canThin   = busyness >= 0.60 && rng.nextDouble() < 0.80
        let canFill   = busyness <= 0.40 && rng.nextDouble() < 0.70
        let canSub    = rng.nextDouble() < 0.45
        let canRotate = windowLen >= 8 && rng.nextDouble() < 0.15

        // Pre-select targets for the window (decided once, applied per-bar)
        let thinTargets = canThin
            ? selectThinTargets(barDict, startBar: startBar, endBar: endBar,
                                structure: structure, rng: &rng) : []
        let fillTarget  = canFill
            ? selectFillTarget(barDict, startBar: startBar, endBar: endBar,
                               structure: structure, rng: &rng) : nil
        let subTarget   = canSub
            ? selectSubTarget(barDict, startBar: startBar, endBar: endBar,
                              structure: structure, rng: &rng) : nil
        let rotateDir   = canRotate ? (rng.nextDouble() < 0.5 ? 1 : -1) : 0
        var rotateAccum = 0

        let bassBounds = RegisterBounds(low: 28, high: 52)

        for bar in startBar..<endBar {
            guard let section = structure.section(atBar: bar),
                  section.label != .intro && section.label != .outro else { continue }
            guard let entry = entryForBar[bar] else { continue }   // O(1) — no linear scan

            let pos = windowLen > 1
                ? Double(bar - startBar) / Double(windowLen - 1)
                : 0.0
            let intensity = arcIntensity(pos: pos, arcType: arcType)

            let barStart  = bar * 16
            var barEvents = barDict[bar] ?? []   // O(1) — no filter scan

            // ── Thin ──────────────────────────────────────────────────────────
            if !thinTargets.isEmpty {
                let removeCount = intensity > 0.75 ? min(2, thinTargets.count)
                                : intensity > 0.40 ? 1 : 0
                if removeCount > 0 {
                    let stepsToRemove = Set(thinTargets.prefix(removeCount).map { barStart + $0 })
                    barEvents = barEvents.filter { !stepsToRemove.contains($0.stepIndex) }
                }
            }

            // ── Fill ──────────────────────────────────────────────────────────
            if let fill = fillTarget, intensity > 0.40 {
                let fillStep = barStart + fill.stepOffset
                if !barEvents.contains(where: { $0.stepIndex == fillStep }) {
                    // Reference pitch: nearest note in the bar
                    let refNote = barEvents
                        .min(by: { abs($0.stepIndex - fillStep) < abs($1.stepIndex - fillStep) })
                        .map { $0.note }
                        ?? UInt8(clamped(
                            (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12 + 36,
                            low: 28, high: 52))
                    let newNote = adjacentScaleNote(from: refNote, steps: fill.direction,
                                                   entry: entry, frame: frame, bounds: bassBounds)
                    // Velocity: slightly below surrounding notes (passing-tone character)
                    let avgVel  = barEvents.isEmpty ? 70
                        : barEvents.map { Int($0.velocity) }.reduce(0, +) / barEvents.count
                    barEvents.append(MIDIEvent(
                        stepIndex: fillStep, note: newNote,
                        velocity: UInt8(clamped(avgVel - 10, low: 55, high: 85)),
                        durationSteps: 2))
                }
            }

            // ── Substitute ────────────────────────────────────────────────────
            if let sub = subTarget, intensity > 0.65 {
                let subStep = barStart + sub.stepOffset
                if let idx = barEvents.firstIndex(where: { $0.stepIndex == subStep }) {
                    let ev      = barEvents[idx]
                    let newNote = adjacentScaleNote(from: ev.note, steps: sub.direction,
                                                   entry: entry, frame: frame, bounds: bassBounds)
                    barEvents[idx] = MIDIEvent(stepIndex: ev.stepIndex, note: newNote,
                                               velocity: ev.velocity, durationSteps: ev.durationSteps)
                }
            }

            // ── Rotate ────────────────────────────────────────────────────────
            if canRotate && rotateDir != 0 {
                // Accumulate one step when intensity crosses 0.60; max drift ±1
                if intensity > 0.60 && abs(rotateAccum) < 1 && rng.nextDouble() < 0.35 {
                    rotateAccum += rotateDir
                }
                // On evolve-reset arc, start reversing once intensity falls below 0.30
                if arcType == 0 && intensity < 0.30 && rotateAccum != 0 {
                    rotateAccum -= rotateDir
                }
                if rotateAccum != 0 {
                    barEvents = barEvents.map { ev in
                        let off = ev.stepIndex - barStart
                        // Protect beat 1 (step 0) and beat 3 (step 8) — kick-drum anchors.
                        guard off != 0 && off != 8 else { return ev }
                        // Protect all 8th-note grid positions (even offsets: 2,4,6,10,12,14).
                        // Rotating them to 16th positions (odd steps) destroys the locked-groove
                        // feel of Motorik: the bass would land between every hi-hat hit while the
                        // kick/snare/hat all stay on the 8th-note grid (the "Apache beat" lock).
                        // Only rotate events that are already at syncopated 16th positions.
                        guard off % 2 != 0 else { return ev }
                        let newOff = max(1, min(15, off + rotateAccum))
                        return MIDIEvent(stepIndex: barStart + newOff, note: ev.note,
                                        velocity: ev.velocity, durationSteps: ev.durationSteps)
                    }
                }
            }

            barDict[bar] = barEvents   // O(1) update — no full-array rebuild
        }
    }

    // MARK: - Target selection (operate on barDict directly)

    /// Finds 2–3 non-anchor step offsets (within a bar) that appear most frequently
    /// across body bars — these are the candidates for thinning.
    /// Beat 1 (step 0) and beat 3 (step 8) are never thinned.
    private static func selectThinTargets(
        _ barDict: [Int: [MIDIEvent]], startBar: Int, endBar: Int,
        structure: SongStructure, rng: inout SeededRNG
    ) -> [Int] {
        var freq: [Int: Int] = [:]
        for bar in startBar..<endBar {
            guard let s = structure.section(atBar: bar),
                  s.label != .intro && s.label != .outro else { continue }
            let bs = bar * 16
            for ev in barDict[bar] ?? [] {
                let off = ev.stepIndex - bs
                if off != 0 && off != 8 { freq[off, default: 0] += 1 }
            }
        }
        guard !freq.isEmpty else { return [] }

        // Highest frequency first; off-beat positions (steps 2, 6, 10, 14) preferred on ties
        let sorted = freq.keys.sorted {
            let fa = freq[$0, default: 0], fb = freq[$1, default: 0]
            if fa != fb { return fa > fb }
            return ($0 % 4 == 2) && ($1 % 4 != 2)  // prefer off-beat
        }
        return Array(sorted.prefix(rng.nextInt(upperBound: 2) + 2))  // 2–3 targets
    }

    /// Finds an off-beat 8th-note step that is consistently empty but adjacent to a note.
    private static func selectFillTarget(
        _ barDict: [Int: [MIDIEvent]], startBar: Int, endBar: Int,
        structure: SongStructure, rng: inout SeededRNG
    ) -> (stepOffset: Int, direction: Int)? {
        var occupied = Set<Int>()
        var bodyCount = 0
        for bar in startBar..<endBar {
            guard let s = structure.section(atBar: bar),
                  s.label != .intro && s.label != .outro else { continue }
            bodyCount += 1
            let bs = bar * 16
            for ev in barDict[bar] ?? [] { occupied.insert(ev.stepIndex - bs) }
        }
        guard bodyCount > 0 else { return nil }

        // Off-beat 8th positions only; must be empty and adjacent (≤2 steps) to a note
        let candidates = [2, 6, 10, 14].filter { step in
            !occupied.contains(step) &&
            occupied.contains(where: { abs($0 - step) <= 2 })
        }
        guard !candidates.isEmpty else { return nil }

        let chosen    = candidates[rng.nextInt(upperBound: candidates.count)]
        let direction = rng.nextDouble() < 0.5 ? 1 : -1
        return (stepOffset: chosen, direction: direction)
    }

    /// Selects a non-anchor step (not beats 1 or 3) that consistently carries a note
    /// in at least half the body bars — candidate for pitch substitution.
    private static func selectSubTarget(
        _ barDict: [Int: [MIDIEvent]], startBar: Int, endBar: Int,
        structure: SongStructure, rng: inout SeededRNG
    ) -> (stepOffset: Int, direction: Int)? {
        var freq: [Int: Int] = [:]
        var bodyCount = 0
        for bar in startBar..<endBar {
            guard let s = structure.section(atBar: bar),
                  s.label != .intro && s.label != .outro else { continue }
            bodyCount += 1
            let bs = bar * 16
            for ev in barDict[bar] ?? [] {
                let off = ev.stepIndex - bs
                if off != 0 && off != 8 { freq[off, default: 0] += 1 }
            }
        }
        guard bodyCount > 0 else { return nil }

        let threshold  = max(1, bodyCount / 2)
        let candidates = freq.filter { $0.value >= threshold }.map { $0.key }.sorted()
        guard !candidates.isEmpty else { return nil }

        let chosen    = candidates[rng.nextInt(upperBound: candidates.count)]
        let direction = rng.nextDouble() < 0.5 ? 1 : -1
        return (stepOffset: chosen, direction: direction)
    }

    // MARK: - Scale-adjacent pitch

    /// Returns the MIDI note that is `steps` diatonic scale degrees away from `note`
    /// in the song's mode. Positive = step up, negative = step down.
    /// Respects the mode's intervals (minor 3rd in Aeolian, major 3rd in Ionian, etc.)
    /// and clamps the result to `bounds`.
    private static func adjacentScaleNote(
        from note: UInt8, steps: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        bounds: RegisterBounds
    ) -> UInt8 {
        let keyRoot = keySemitone(frame.key)
        let scale   = frame.mode.intervals          // semitones above key root
        let notePC  = (Int(note) % 12 - keyRoot + 12) % 12

        // Find the nearest scale index to the note's pitch class
        let nearestIdx = scale.indices.min(by: {
            abs(scale[$0] - notePC) < abs(scale[$1] - notePC)
        }) ?? 0

        let n         = scale.count
        let totalIdx  = nearestIdx + steps
        let targetIdx = ((totalIdx % n) + n) % n

        // Did we cross an octave boundary?
        let octaveShift: Int
        if      totalIdx < 0 { octaveShift = -1 }
        else if totalIdx >= n { octaveShift =  1 }
        else                  { octaveShift =  0 }

        let targetPC = (keyRoot + scale[targetIdx]) % 12
        let noteOct  = Int(note) / 12
        var newMIDI  = (noteOct + octaveShift) * 12 + targetPC

        // Ensure movement is in the requested direction
        if steps > 0 && newMIDI <= Int(note) { newMIDI += 12 }
        if steps < 0 && newMIDI >= Int(note) { newMIDI -= 12 }

        return UInt8(clamped(newMIDI, low: Int(bounds.low), high: Int(bounds.high)))
    }

    // MARK: - Arc intensity

    /// Returns 0.0–1.0 intensity for position `pos` (0.0 = window start, 1.0 = end).
    private static func arcIntensity(pos: Double, arcType: Int) -> Double {
        switch arcType {
        case 0:  // evolve-reset: ramp up over 60%, drop to 0 over last 30%
            if pos < 0.6  { return pos / 0.6 }
            return max(0.0, 1.0 - (pos - 0.6) / 0.3)
        case 1:  // evolve-hold: ramp up over 40%, hold at 1.0
            return min(1.0, pos / 0.4)
        default: // evolve-reverse: symmetric triangle
            return pos < 0.5 ? pos * 2.0 : (1.0 - pos) * 2.0
        }
    }

    // MARK: - Utility

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        max(low, min(high, v))
    }
}
