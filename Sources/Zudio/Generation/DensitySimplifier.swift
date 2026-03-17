// DensitySimplifier.swift — generation step 10
// Collision / density simplification pass.
// Rules: if Lead 1 conflicts with pads → thin Lead 1; if Lead 1 conflicts with Lead 2 → thin Lead 2.
// Never allow high-fill drums and high-density Lead 1 in the same 8-bar window.

struct DensitySimplifier {
    static func simplify(
        trackEvents: [[MIDIEvent]],
        frame: GlobalMusicalFrame,
        structure: SongStructure
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

            // Lead 2 conflicts with Lead 1 → thin Lead 2
            if lead2Density > lead1Density * 0.8 {
                events[kTrackLead2] = thin(events[kTrackLead2], startStep: startStep, endStep: endStep, keepRate: 0.55)
            }
        }

        return events
    }

    // MARK: - Helpers

    private static func eventDensity(_ events: [MIDIEvent], startStep: Int, endStep: Int) -> Double {
        let windowEvents = events.filter { $0.stepIndex >= startStep && $0.stepIndex < endStep }
        let totalSteps = endStep - startStep
        guard totalSteps > 0 else { return 0 }
        return Double(windowEvents.count) / Double(totalSteps)
    }

    /// Keeps `keepRate` fraction of events in the given step range (deterministically via index).
    private static func thin(_ events: [MIDIEvent], startStep: Int, endStep: Int, keepRate: Double) -> [MIDIEvent] {
        var result: [MIDIEvent] = []
        var idx = 0
        for ev in events {
            if ev.stepIndex >= startStep && ev.stepIndex < endStep {
                if Double(idx % 100) / 100.0 < keepRate {
                    result.append(ev)
                }
                idx += 1
            } else {
                result.append(ev)
            }
        }
        return result
    }
}
