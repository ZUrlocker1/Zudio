// SongStructure.swift — generation step 2 output
// Copyright (c) 2026 Zack Urlocker

// MARK: - ChordWindow

struct ChordWindow: Equatable, Sendable {
    let startBar: Int
    let lengthBars: Int
    /// Degree string of the chord root within the active key (e.g. "1", "b7", "b6").
    let chordRoot: String
    let chordType: ChordType
    /// Pitch classes (mod 12) that are chord tones.
    let chordTones: Set<Int>
    /// Pitch classes that are scale-compatible tensions (not chord tones).
    let scaleTensions: Set<Int>
    /// Pitch classes disallowed on strong beats.
    let avoidTones: Set<Int>

    var endBar: Int { startBar + lengthBars }

    func contains(bar: Int) -> Bool { bar >= startBar && bar < endBar }
}

// MARK: - SongSection

struct SongSection: Equatable, Sendable {
    let startBar: Int
    let lengthBars: Int
    let label: SectionLabel
    let intensity: SectionIntensity
    /// Active mode for this section (may differ from GlobalMusicalFrame.mode for Moderate A/B B-section).
    let mode: Mode

    var endBar: Int { startBar + lengthBars }

    func contains(bar: Int) -> Bool { bar >= startBar && bar < endBar }

    /// For Single-A sections, returns the intensity at a specific bar using the
    /// low→medium→high sub-phase arc (25% / 50% / 25% of section length).
    func subPhaseIntensity(atBar bar: Int) -> SectionIntensity {
        guard label == .A else { return intensity }
        let offset = bar - startBar
        let phase1End = Int(Double(lengthBars) * 0.25)
        let phase2End = Int(Double(lengthBars) * 0.75)
        if offset < phase1End { return .low }
        if offset < phase2End { return .medium }
        return .high
    }
}

// MARK: - SongStructure

struct SongStructure: Equatable, Sendable {
    let sections: [SongSection]
    let chordPlan: [ChordWindow]
    let introStyle: IntroStyle
    let outroStyle: OutroStyle

    func section(atBar bar: Int) -> SongSection? {
        sections.first { $0.contains(bar: bar) }
    }

    var introSection: SongSection? { sections.first { $0.label == .intro } }
    var outroSection: SongSection? { sections.first { $0.label == .outro } }
    var bodySections: [SongSection] { sections.filter { $0.label == .A || $0.label == .B } }

    /// True if this song has at least one B section (any form other than single_evolving).
    var hasBSection: Bool { sections.contains { $0.label == .B } }

    /// True if the bar falls within any B section.
    func inBSection(atBar bar: Int) -> Bool {
        section(atBar: bar)?.label == .B
    }

    /// True if the bar falls within any bridge section (any archetype).
    func inBridge(atBar bar: Int) -> Bool {
        guard let lbl = section(atBar: bar)?.label else { return false }
        return lbl == .bridge || lbl == .bridgeAlt || lbl == .bridgeMelody
    }
}

// MARK: - Chord lookup

extension SongStructure {

    /// The chord window covering `bar`, or nil if no window does.
    ///
    /// This method already existed and was already the right answer; the generators simply did
    /// not use it.
    ///
    /// This is the single canonical way to ask which chord is in force at a bar. It replaced 38
    /// copies of `chordPlan.first { $0.contains(bar: bar) }` spread across the generators
    /// (2026-10-14), every one of them a linear scan inside a per-bar loop — and Chill Soho's
    /// plan runs to a median of 95 windows over 104 bars, so each lookup averaged about 48
    /// comparisons.
    ///
    /// Binary search is safe here because the plan is sorted, non-overlapping and contiguous,
    /// and no bar ever matches two windows. That was verified across 454 songs spanning all four
    /// styles before this was written; `ChordPlanShapeTests` pins it so a generator that breaks
    /// the invariant fails loudly instead of quietly returning the wrong chord.
    func chordWindow(atBar bar: Int) -> ChordWindow? {
        var lo = 0, hi = chordPlan.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let w = chordPlan[mid]
            if bar < w.startBar      { hi = mid - 1 }
            else if bar >= w.endBar  { lo = mid + 1 }
            else                     { return w }
        }
        return nil
    }

    /// How far into its chord window `bar` sits — 0 on the bar the chord changes.
    /// Bars outside the plan report 0, matching the `?? 0` the call sites used to write.
    func barInChordWindow(_ bar: Int) -> Int {
        guard let w = chordWindow(atBar: bar) else { return 0 }
        return bar - w.startBar
    }

    /// The length in bars of the chord window covering `bar`, or `fallback` if there is none.
    func chordWindowLength(atBar bar: Int, fallback: Int) -> Int {
        chordWindow(atBar: bar)?.lengthBars ?? fallback
    }
}

