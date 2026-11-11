// ArrangementFilter.swift — generation step 10.5
// Copyright (c) 2026 Zack Urlocker
// "Spotlight" arrangement: when 3+ melodic tracks are active in the same
// N-bar block, some step back so one performer can lead.
//
// Exempt tracks (always play full): Bass, Drums, Texture.
// Subject tracks:                   Lead 1, Lead 2, Rhythm, Pads.
//
// Algorithm per block:
//   1. Measure density of each subject track (unique steps with notes ÷ total steps).
//   2. If ≥3 tracks are "active" (density > 0.05), assign a spotlight of 1–2 tracks.
//   3. Non-spotlight tracks receive one of three treatment levels:
//      - Rest (45%): all notes in the block removed.
//      - Reduced (35%): ~35% of notes kept, velocity softened –18.
//      - Light (20%): velocity softened –20 only (notes kept).
//   4. A track given a `maxSilentBars` limit may not be left silent for longer than that. A
//      rest or reduction that would break it becomes a firm back-off instead (every note kept,
//      softened –18), so the block steps back without the track going missing.
//   5. Spotlight rotates: tracks featured in the previous block are deprioritised.
//
// Block size is 8 or 16 bars, chosen once per song (seeded).

struct ArrangementFilter {

    // Tracks that can be spotlighted / rested
    private static let subjectTracks = [kTrackLead1, kTrackLead2, kTrackRhythm, kTrackPads]

    static func apply(
        trackEvents: [[MIDIEvent]],
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        seed: UInt64,
        solo: SoloWindows = .none,            // LD1-007/008 solo and its shorter returns — never rested
        arcadeVariation: Bool = false,        // Arcade: Lead 1 is always protected from block silencing
        exemptTracks: [Int] = [],             // Kraftwerk sync members — see below
        phraseTracks: [Int] = [],             // whole-phrase hook leads: never thinned, see below
        maxSilentBars: [Int: Int] = [:]       // track → longest silence a rest or reduction may leave
    ) -> [[MIDIEvent]] {
        var events = trackEvents

        // Sync tracks are exempt. This filter spotlights one track and thins the others
        // INDEPENDENTLY, which is the opposite of what a sync is: those parts are chosen to
        // agree with each other, and MOT-LD2-012 in particular is a strict unison with Rhythm
        // that thinning one side would silently break. The sync has its own arrangement
        // device — the section dropout, which drops the whole group together.
        let subjectTracks = Self.subjectTracks.filter { !exemptTracks.contains($0) }
        // Arrangement-specific sub-seed — differs from all per-track seeds
        var rng = SeededRNG(seed: seed &+ 0xC3D2E1F4A5B60798)

        // Block size: 8 or 16 bars, chosen per song
        let blockSize = rng.nextDouble() < 0.5 ? 8 : 16
        let totalBlocks = (frame.totalBars + blockSize - 1) / blockSize

        // Pre-compute bridge bars — blocks containing ANY bridge bar are skipped entirely
        // so the arrangement filter never silences bridge-specific events (X-Files whistle, etc.)
        let bridgeBars: Set<Int> = Set(structure.sections
            .filter { $0.label.isBridge }
            .flatMap { $0.startBar..<$0.endBar })

        var lastSpotlight: Set<Int> = []

        for b in 0..<totalBlocks {
            let startBar  = b * blockSize
            let endBar    = min(startBar + blockSize, frame.totalBars)
            let startStep = startBar * 16
            let endStep   = endBar   * 16

            // Skip blocks that overlap a bridge section — generators already handle those
            guard !bridgeBars.contains(where: { $0 >= startBar && $0 < endBar }) else { continue }

            // Measure density as unique steps with notes (normalises pad chords vs single-note leads)
            let densities = subjectTracks.map { track -> (track: Int, density: Double) in
                (track, uniqueStepDensity(events[track], startStep: startStep, endStep: endStep))
            }

            // "Active" = meaningful content (> ~6 unique note-steps in an 8-bar window)
            let activeTracks = densities.filter { $0.density > 0.05 }.map { $0.track }

            // Only intervene when ≥3 melodic tracks are active together
            guard activeTracks.count >= 3 else { continue }

            // Choose 1 or 2 spotlight tracks
            let spotlightCount = rng.nextDouble() < 0.55 ? 1 : 2

            // Sort candidates: prefer tracks NOT spotlighted last block, then by density (higher = more prominent).
            // Tiebreaker: Lead 1 always beats Lead 2 when freshness is equal — prevents Lead 2
            // accumulating more notes than Lead 1 via the density sort.
            let sorted = activeTracks.sorted { a, b in
                let aFresh = !lastSpotlight.contains(a)
                let bFresh = !lastSpotlight.contains(b)
                if aFresh != bFresh { return aFresh }
                if (a == kTrackLead1 && b == kTrackLead2) || (a == kTrackLead2 && b == kTrackLead1) {
                    return a == kTrackLead1
                }
                let aD = densities.first { $0.track == a }?.density ?? 0
                let bD = densities.first { $0.track == b }?.density ?? 0
                return aD > bD
            }
            let spotlight = Set(sorted.prefix(spotlightCount))
            lastSpotlight = spotlight

            // Apply rest / reduce to non-spotlight active tracks
            // Lead 1 solo window is protected: never rest or thin a block containing solo bars.
            let soloOverlaps = solo.overlaps(startBar..<endBar)

            for track in activeTracks where !spotlight.contains(track) {
                if track == kTrackLead1 && (soloOverlaps || arcadeVariation) { continue }
                // A hook lead states whole phrases, so it is only ever softened: resting or
                // thinning it picks notes out of the hook (one song kept 2 of 8 statements).
                let treatment = Treatment(roll: rng.nextDouble(), isPhraseTrack: phraseTracks.contains(track))
                let steps = startStep..<endStep
                // The treatment runs in full whatever the limit says, so the random stream is the
                // same with or without one.
                var result = treatment.applied(to: events[track], steps: steps, rng: &rng)
                if let limit = maxSilentBars[track], treatment.removesNotes,
                   opensLongSilence(result, was: events[track], in: startBar..<endBar,
                                    totalBars: frame.totalBars, limit: limit) {
                    result = Treatment.backOff.applied(to: events[track], steps: steps, rng: &rng)
                }
                events[track] = result
            }
        }

        return events
    }

    // MARK: - Treatments

    /// What a block does to a track that is not in the spotlight.
    private enum Treatment {
        case rest           // every note in the block removed
        case reduce         // about 35% of the notes kept, softened
        case backOff        // every note kept, softened
        case lightBackOff   // every note kept, softened a little more

        init(roll: Double, isPhraseTrack: Bool) {
            if roll < 0.45 && !isPhraseTrack { self = .rest }
            else if roll < 0.80 { self = isPhraseTrack ? .backOff : .reduce }
            else { self = .lightBackOff }
        }

        var removesNotes: Bool { self == .rest || self == .reduce }

        func applied(to events: [MIDIEvent], steps: Range<Int>, rng: inout SeededRNG) -> [MIDIEvent] {
            switch self {
            case .rest:
                return ArrangementFilter.silence(events, startStep: steps.lowerBound, endStep: steps.upperBound)
            case .reduce:
                let thinned = ArrangementFilter.thin(events, startStep: steps.lowerBound, endStep: steps.upperBound,
                                                     keepRate: 0.35, rng: &rng)
                return ArrangementFilter.soften(thinned, startStep: steps.lowerBound, endStep: steps.upperBound,
                                                reduction: 18)
            case .backOff:
                return ArrangementFilter.soften(events, startStep: steps.lowerBound, endStep: steps.upperBound,
                                                reduction: 18)
            case .lightBackOff:
                return ArrangementFilter.soften(events, startStep: steps.lowerBound, endStep: steps.upperBound,
                                                reduction: 20)
            }
        }
    }

    // MARK: - Helpers

    /// True when `result` leaves a silence over `limit` bars around `block` that `original` did
    /// not already have to that length.
    private static func opensLongSilence(_ result: [MIDIEvent], was original: [MIDIEvent],
                                         in block: Range<Int>, totalBars: Int, limit: Int) -> Bool {
        let after = longestSilence(result, overlapping: block, totalBars: totalBars)
        return after > limit && after > longestSilence(original, overlapping: block, totalBars: totalBars)
    }

    /// The longest run of bars with no note onset that overlaps `block`; the song start and end
    /// count as edges, so a lead that never starts has one long run.
    private static func longestSilence(_ events: [MIDIEvent], overlapping block: Range<Int>,
                                       totalBars: Int) -> Int {
        let sounding = Set(events.map { $0.stepIndex / 16 })
        var longest = 0
        var runStart = 0
        for bar in 0...totalBars {
            if bar == totalBars || sounding.contains(bar) {
                if bar > runStart, runStart < block.upperBound, bar > block.lowerBound {
                    longest = Swift.max(longest, bar - runStart)
                }
                runStart = bar + 1
            }
        }
        return longest
    }

    /// Fraction of steps in the range that contain at least one note.
    /// Using unique steps normalises chords (4 notes/step for pads) against single-note lines.
    private static func uniqueStepDensity(_ events: [MIDIEvent], startStep: Int, endStep: Int) -> Double {
        let totalSteps = endStep - startStep
        guard totalSteps > 0 else { return 0 }
        let uniqueSteps = Set(
            events.filter { $0.stepIndex >= startStep && $0.stepIndex < endStep }
                  .map { $0.stepIndex }
        ).count
        return Double(uniqueSteps) / Double(totalSteps)
    }

    /// Remove all events in the step range.
    private static func silence(_ events: [MIDIEvent], startStep: Int, endStep: Int) -> [MIDIEvent] {
        return events.filter { $0.stepIndex < startStep || $0.stepIndex >= endStep }
    }

    /// Keep approximately `keepRate` fraction of events in the range (seeded random).
    private static func thin(
        _ events: [MIDIEvent], startStep: Int, endStep: Int,
        keepRate: Double, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        for ev in events {
            if ev.stepIndex >= startStep && ev.stepIndex < endStep {
                if rng.nextDouble() < keepRate { result.append(ev) }
            } else {
                result.append(ev)
            }
        }
        return result
    }

    /// Reduce velocity of events in the step range by `reduction`, floored at 20.
    private static func soften(
        _ events: [MIDIEvent], startStep: Int, endStep: Int, reduction: Int
    ) -> [MIDIEvent] {
        return events.map { ev in
            guard ev.stepIndex >= startStep && ev.stepIndex < endStep else { return ev }
            let newVel = UInt8(max(20, Int(ev.velocity) - reduction))
            return MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                             velocity: newVel, durationSteps: ev.durationSteps)
        }
    }
}
