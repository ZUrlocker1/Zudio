// SongStructure.swift — generation step 2 output

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

    func section(atBar bar: Int) -> SongSection? {
        sections.first { $0.contains(bar: bar) }
    }

    func chordWindow(atBar bar: Int) -> ChordWindow? {
        chordPlan.first { $0.contains(bar: bar) }
    }

    var introSection: SongSection? { sections.first { $0.label == .intro } }
    var outroSection: SongSection? { sections.first { $0.label == .outro } }
    var bodySections: [SongSection] { sections.filter { $0.label == .A || $0.label == .B } }
}
