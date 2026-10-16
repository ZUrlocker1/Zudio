// HarmonicFilter.swift — generation step 11
// Copyright (c) 2026 Zack Urlocker
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
//   Pad median, Lead figures that dip below the Pad median are transposed up one
//   octave whole, if the whole figure fits the track's registered bounds. Keeps
//   Leads audible above the harmonic bed without silencing them.
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
        structure: SongStructure,
        skipLead1ClashFilter: Bool = false,
        // Narrower, per-instrument registers that override `kRegisterBounds` for these tracks.
        // Chill passes its leads' instrument registers here: a tenor sax tops out at 72 while
        // Lead 1's track ceiling is 79, and Pass B used to push notes into that gap — 41% of a
        // tenor's notes ended up above its own ceiling, which is where the screech came from
        // (Zack, 2026-10-14).
        registerOverrides: [Int: RegisterBounds] = [:]
    ) -> [[MIDIEvent]] {
        var events = trackEvents
        // Each lead is filtered on its own (Passes A, B and C below, in `filterLead`), reading the
        // pads' pitches before Pass C touches the pads' velocities — so a regenerated lead can be
        // put through exactly the same passes without running them over the other tracks again.
        for track in [kTrackLead1, kTrackLead2] {
            events[track] = filterLead(events[track], track: track, pads: events[kTrackPads],
                                       frame: frame, structure: structure,
                                       skipClashFilter: track == kTrackLead1 && skipLead1ClashFilter,
                                       bounds: registerOverrides[track] ?? kRegisterBounds[track]
                                             ?? RegisterBounds(low: 55, high: 88))
        }
        for track in [kTrackPads, kTrackRhythm, kTrackTexture] {
            events[track] = velocityArc(events[track], frame: frame, structure: structure)
        }
        return events
    }

    /// The harmonic filter for one lead track, as `apply` runs it:
    /// Pass A — remove out-of-scale notes on strong beats (unless `skipClashFilter`; LD1-012
    /// Chromatic Descent uses chromatic passing tones on purpose);
    /// Pass B — push the lead above the pads' median in each 8-bar window;
    /// Pass C — the song's velocity arc.
    static func filterLead(_ lead: [MIDIEvent], track: Int, pads: [MIDIEvent],
                           frame: GlobalMusicalFrame, structure: SongStructure,
                           skipClashFilter: Bool = false, bounds: RegisterBounds) -> [MIDIEvent] {
        var events = skipClashFilter ? lead : removeStrongBeatClashes(lead, structure: structure)

        let windowBars  = 8
        let totalWindows = (frame.totalBars + windowBars - 1) / windowBars
        for w in 0..<totalWindows {
            let startBar  = w * windowBars
            let endBar    = min(startBar + windowBars, frame.totalBars)
            let startStep = startBar * 16
            let endStep   = endBar   * 16
            guard let padMedian = medianPitch(pads, startStep: startStep, endStep: endStep),
                  let leadMedian = medianPitch(events, startStep: startStep, endStep: endStep),
                  leadMedian < padMedian + 4
            else { continue }
            events = pushLeadAbovePads(events, startStep: startStep, endStep: endStep,
                                       padMedian: padMedian, bounds: bounds)
        }
        return velocityArc(events, frame: frame, structure: structure)
    }

    /// Pass C — the velocity arc for one melodic track (Bass and Drums are exempt).
    private static func velocityArc(_ track: [MIDIEvent], frame: GlobalMusicalFrame,
                                    structure: SongStructure) -> [MIDIEvent] {
        let bodyStart = structure.bodySections.map { $0.startBar }.min() ?? 0
        let bodyEnd   = structure.bodySections.map { $0.endBar   }.max() ?? frame.totalBars
        return track.map { ev in
            let mult = arcMultiplier(bar: ev.stepIndex / 16, frame: frame, structure: structure,
                                     bodyStart: bodyStart, bodyEnd: bodyEnd)
            let newV = UInt8(clamped(Int((Double(ev.velocity) * mult).rounded()), low: 20, high: 115))
            return MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                             velocity: newV, durationSteps: ev.durationSteps)
        }
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

    /// Transposes Lead figures that dip below `padMedian` up one octave, within bounds. A figure
    /// is a run of notes with less than a bar's gap between them — a phrase, or an Avalon Hook
    /// episode of call and answer — found across the whole track, and it moves whole or not at
    /// all. This window decides the figures that START in it, so one that runs on past the window
    /// moves with all its notes. Moving single notes split figures across octaves: C5 B♭4 B♭4
    /// became C5 B♭5 B♭5, a step down turned into a seventh up, in 10 of Late Americano's 30
    /// figures; deciding figures only inside the window still split the ones that crossed it
    /// (Zack, 2026-10-16).
    private static func pushLeadAbovePads(
        _ events: [MIDIEvent], startStep: Int, endStep: Int,
        padMedian: Double, bounds: RegisterBounds
    ) -> [MIDIEvent] {
        let order = events.indices.sorted { events[$0].stepIndex < events[$1].stepIndex }
        var figures: [[Int]] = []
        for i in order {
            if let prev = figures.last?.last,
               events[i].stepIndex - (events[prev].stepIndex + events[prev].durationSteps) < 16 {
                figures[figures.count - 1].append(i)
            } else {
                figures.append([i])
            }
        }
        var out = events
        for figure in figures {
            guard let first = figure.first,
                  events[first].stepIndex >= startStep && events[first].stepIndex < endStep,
                  figure.contains(where: { Double(events[$0].note) < padMedian }),
                  figure.allSatisfy({ Int(events[$0].note) + 12 <= bounds.high }) else { continue }
            for i in figure {
                let ev = events[i]
                out[i] = MIDIEvent(stepIndex: ev.stepIndex, note: UInt8(Int(ev.note) + 12),
                                   velocity: ev.velocity, durationSteps: ev.durationSteps)
            }
        }
        return out
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
