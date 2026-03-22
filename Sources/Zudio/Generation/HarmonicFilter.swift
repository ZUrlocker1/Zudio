// HarmonicFilter.swift — generation step 11
// Three-pass musicality pass; runs after ArrangementFilter.
//
// Pass A — Harmonic clash guard (Lead 1, Lead 2):
//   Notes on strong beats (quarter-note downbeats) whose pitch class falls in
//   the current chord window's avoidTones set (chromatic, out-of-scale entirely)
//   are removed. Cap: never remove more than 50% of a bar's notes, so the
//   melody shape is preserved even in edge cases.
//
// Pass B — Register separation (Lead 1, Lead 2 above Pads):
//   Per 8-bar window, if the Lead median pitch sits within 4 semitones of the
//   Pad median, Lead notes below the Pad median are transposed up one octave,
//   clamped to the track's registered bounds. Keeps Leads audible above the
//   harmonic bed without silencing them.
//
// Pass C — Velocity arc shaping (Lead 1, Lead 2, Pads, Rhythm, Texture):
//   A song-wide dynamic arc multiplier is applied: intro 0.75×, body opening
//   ramp 0.88→1.0, main body 1.0, climax peak 1.07, pre-outro taper →0.95.
//   Bass and Drums are exempt — they hold steady regardless of the arc.
//   Motorik principle: the groove never drops; the melody breathes around it.

struct HarmonicFilter {

    static func apply(
        trackEvents: [[MIDIEvent]],
        frame: GlobalMusicalFrame,
        structure: SongStructure
    ) -> [[MIDIEvent]] {
        var events = trackEvents

        // Pass A — remove out-of-scale Lead notes on strong beats
        for track in [kTrackLead1, kTrackLead2] {
            events[track] = removeStrongBeatClashes(events[track], structure: structure)
        }

        // Pass B — push Leads above the Pad median in each 8-bar window
        let windowBars  = 8
        let totalWindows = (frame.totalBars + windowBars - 1) / windowBars
        for w in 0..<totalWindows {
            let startBar  = w * windowBars
            let endBar    = min(startBar + windowBars, frame.totalBars)
            let startStep = startBar * 16
            let endStep   = endBar   * 16

            guard let padMedian = medianPitch(events[kTrackPads],
                                              startStep: startStep, endStep: endStep)
            else { continue }

            for track in [kTrackLead1, kTrackLead2] {
                guard let leadMedian = medianPitch(events[track],
                                                   startStep: startStep, endStep: endStep),
                      leadMedian < padMedian + 4
                else { continue }

                let bounds = kRegisterBounds[track] ?? RegisterBounds(low: 55, high: 88)
                events[track] = pushLeadAbovePads(
                    events[track], startStep: startStep, endStep: endStep,
                    padMedian: padMedian, bounds: bounds
                )
            }
        }

        // Pass C — velocity arc (melodic tracks only; Bass and Drums exempt)
        let bodyStart = structure.bodySections.map { $0.startBar }.min() ?? 0
        let bodyEnd   = structure.bodySections.map { $0.endBar   }.max() ?? frame.totalBars

        let arcTracks = [kTrackLead1, kTrackLead2, kTrackPads, kTrackRhythm, kTrackTexture]
        for track in arcTracks {
            events[track] = events[track].map { ev in
                let bar  = ev.stepIndex / 16
                let mult = arcMultiplier(bar: bar, frame: frame, structure: structure,
                                         bodyStart: bodyStart, bodyEnd: bodyEnd)
                let newV = UInt8(clamped(Int((Double(ev.velocity) * mult).rounded()), low: 20, high: 115))
                return MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                 velocity: newV, durationSteps: ev.durationSteps)
            }
        }

        return events
    }

    // MARK: - Pass A: Harmonic Clash Guard

    private static func removeStrongBeatClashes(
        _ events: [MIDIEvent], structure: SongStructure
    ) -> [MIDIEvent] {
        // Group events by bar for the 50% removal cap
        var byBar: [Int: [MIDIEvent]] = [:]
        for ev in events { byBar[ev.stepIndex / 16, default: []].append(ev) }

        var result: [MIDIEvent] = []
        for (bar, barEvents) in byBar.sorted(by: { $0.key < $1.key }) {
            guard let cw = structure.chordWindow(atBar: bar) else {
                result.append(contentsOf: barEvents)
                continue
            }

            // Never remove more than half this bar's notes
            let maxRemove = max(1, barEvents.count / 2)
            var removed   = 0
            for ev in barEvents {
                let stepInBar = ev.stepIndex % 16
                let pc        = Int(ev.note) % 12
                // Remove if: on a quarter-note beat AND pitch class is out-of-scale entirely
                if stepInBar % 4 == 0 && cw.avoidTones.contains(pc) && removed < maxRemove {
                    removed += 1
                    // Omit — don't append
                } else {
                    result.append(ev)
                }
            }
        }
        return result
    }

    // MARK: - Pass B: Register Separation

    /// Median MIDI pitch of events in the given step range; nil if no events.
    private static func medianPitch(
        _ events: [MIDIEvent], startStep: Int, endStep: Int
    ) -> Double? {
        let pitches = events
            .filter { $0.stepIndex >= startStep && $0.stepIndex < endStep }
            .map { Double($0.note) }
            .sorted()
        guard !pitches.isEmpty else { return nil }
        let mid = pitches.count / 2
        return pitches.count % 2 == 0
            ? (pitches[mid - 1] + pitches[mid]) / 2.0
            : pitches[mid]
    }

    /// Transposes Lead notes that sit below `padMedian` up one octave, within bounds.
    private static func pushLeadAbovePads(
        _ events: [MIDIEvent], startStep: Int, endStep: Int,
        padMedian: Double, bounds: RegisterBounds
    ) -> [MIDIEvent] {
        events.map { ev in
            guard ev.stepIndex >= startStep && ev.stepIndex < endStep else { return ev }
            guard Double(ev.note) < padMedian else { return ev }
            let transposed = Int(ev.note) + 12
            guard transposed <= bounds.high else { return ev }
            return MIDIEvent(stepIndex: ev.stepIndex, note: UInt8(transposed),
                             velocity: ev.velocity, durationSteps: ev.durationSteps)
        }
    }

    // MARK: - Pass C: Velocity Arc

    /// Smooth piecewise-linear arc multiplier based on position within the song body.
    /// Intro and outro sections use fixed multipliers.
    private static func arcMultiplier(
        bar: Int, frame: GlobalMusicalFrame, structure: SongStructure,
        bodyStart: Int, bodyEnd: Int
    ) -> Double {
        guard let section = structure.section(atBar: bar) else { return 1.0 }

        switch section.label {
        case .intro:
            return 0.75
        case .outro:
            return 0.78
        case .A, .B:
            let bodyLen = max(1, bodyEnd - bodyStart)
            let ratio   = Double(bar - bodyStart) / Double(bodyLen)  // 0.0 → 1.0

            // Ramp in: 0.88 → 1.0 over first 15% of body
            if ratio < 0.15 {
                return 0.88 + (ratio / 0.15) * 0.12
            }
            // Main body: hold at 1.0 (50% – 75%)
            if ratio < 0.75 {
                return 1.0
            }
            // Climax peak: 1.0 → 1.07 over next 13%
            if ratio < 0.88 {
                return 1.0 + ((ratio - 0.75) / 0.13) * 0.07
            }
            // Pre-outro taper: 1.07 → 0.95 over last 12%
            return 1.07 - ((ratio - 0.88) / 0.12) * 0.12
        default:
            // Bridge and ramp sections: neutral multiplier
            return 1.0
        }
    }

    // MARK: - Helpers

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        max(low, min(high, v))
    }
}
