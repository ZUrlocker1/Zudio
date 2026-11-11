// DensitySimplifier.swift — generation step 10
// Copyright (c) 2026 Zack Urlocker
// Collision / density simplification pass.
// Rules: if Lead 1 conflicts with pads → thin Lead 1; if Lead 1 conflicts with Lead 2 → thin Lead 2.
// Never allow high-fill drums and high-density Lead 1 in the same 8-bar window.

struct DensitySimplifier {
    static func simplify(
        trackEvents: [[MIDIEvent]],
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        exemptTracks: [Int] = []
    ) -> [[MIDIEvent]] {
        var events = trackEvents

        // Per 8-bar window conflict check
        let windowBars = 8
        let totalWindows = (frame.totalBars + windowBars - 1) / windowBars

        for w in 0..<totalWindows {
            let startBar = w * windowBars
            let endBar   = min(startBar + windowBars, frame.totalBars)
            let startStep = startBar * 16
            let endStep   = endBar   * 16

            let drumDensity = eventDensity(events[kTrackDrums],   startStep: startStep, endStep: endStep)
            let lead1Density = eventDensity(events[kTrackLead1],  startStep: startStep, endStep: endStep)
            let lead2Density = eventDensity(events[kTrackLead2],  startStep: startStep, endStep: endStep)
            let padDensity   = eventDensity(events[kTrackPads],   startStep: startStep, endStep: endStep)

            // High-fill drums + high-density Lead 1 → thin Lead 1
            if drumDensity > 0.70 && lead1Density > 0.70 {
                events[kTrackLead1] = thin(events[kTrackLead1], startStep: startStep, endStep: endStep, keepRate: 0.5)
            }

            // Lead 1 conflicts with pads → thin Lead 1
            if lead1Density > 0.80 && padDensity > 0.60 {
                events[kTrackLead1] = thin(events[kTrackLead1], startStep: startStep, endStep: endStep, keepRate: 0.6)
            }

            // Lead 2 conflicts with Lead 1 → thin Lead 2.
            // Two-stage: moderate imbalance → 55% keepRate; severe imbalance → 35%.
            // Severe case catches sparse Lead 1 rules (Long Arc, Call & Answer) paired with
            // dense Lead 2 rules (Hallogallo, Rhythmic Counter) — seen at 3× imbalance in practice.
            // A Lead 2 in a Kraftwerk sync doubles Rhythm sectionally; thinning it would break the
            // lock, so it is exempt here as in ArrangementFilter.
            if exemptTracks.contains(kTrackLead2) { continue }
            if lead2Density > lead1Density * 1.5 {
                events[kTrackLead2] = thin(events[kTrackLead2], startStep: startStep, endStep: endStep, keepRate: 0.35)
            } else if lead2Density > lead1Density * 0.6 {
                events[kTrackLead2] = thin(events[kTrackLead2], startStep: startStep, endStep: endStep, keepRate: 0.55)
            }
        }

        return events
    }

    // MARK: - Helpers

    private static func eventDensity(_ events: [MIDIEvent], startStep: Int, endStep: Int) -> Double {
        let totalSteps = endStep - startStep
        guard totalSteps > 0 else { return 0 }
        var count = 0
        for ev in events where ev.stepIndex >= startStep && ev.stepIndex < endStep { count += 1 }
        return Double(count) / Double(totalSteps)
    }

    /// Keeps about `keepRate` of the two-bar phrases that hold events in the step range, spread
    /// evenly from the first, and silences the rest, so a thinned arp keeps whole figures and
    /// rests between them. It used to keep the first `keepRate` share of the events (idx % 100
    /// with under 100 events), which played the front of each window and left the back silent.
    private static func thin(_ events: [MIDIEvent], startStep: Int, endStep: Int, keepRate: Double) -> [MIDIEvent] {
        let unitSteps = 32
        let inRange = { (ev: MIDIEvent) in ev.stepIndex >= startStep && ev.stepIndex < endStep }
        let units = Array(Set(events.filter(inRange).map { ($0.stepIndex - startStep) / unitSteps })).sorted()
        guard !units.isEmpty else { return events }
        let keepCount = max(1, Int((Double(units.count) * keepRate).rounded()))
        let kept = Set((0..<keepCount).map { units[$0 * units.count / keepCount] })
        return events.filter { !inRange($0) || kept.contains(($0.stepIndex - startStep) / unitSteps) }
    }
}
