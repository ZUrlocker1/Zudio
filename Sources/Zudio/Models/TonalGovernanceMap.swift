// TonalGovernanceMap.swift — generation step 3 output
// Every non-drum track queries this at render time to get the active pitch-class sets.

struct TonalGovernanceEntry: Equatable, Sendable {
    let chordWindow: ChordWindow
    let sectionLabel: SectionLabel
    let sectionMode: Mode
}

typealias TonalGovernanceMap = [TonalGovernanceEntry]

extension Array where Element == TonalGovernanceEntry {
    /// Returns the governance entry active at the given absolute bar index.
    func entry(atBar bar: Int) -> TonalGovernanceEntry? {
        first { $0.chordWindow.contains(bar: bar) }
    }
}

// MARK: - Chord-window note pool builder

/// Builds the three pitch-class sets for a chord window from the chord type and active mode.
enum NotePoolBuilder {
    static func build(chordRootDegree: String, chordType: ChordType, key: String, mode: Mode) -> (chordTones: Set<Int>, scaleTensions: Set<Int>, avoidTones: Set<Int>) {
        let rootPC = (keySemitone(key) + degreeSemitone(chordRootDegree)) % 12

        // Chord tones: chord type intervals shifted to chord root pitch class
        let chordTones = Set(chordType.pitchClasses.map { ($0 + rootPC) % 12 })

        // Scale tones: all mode intervals from the key root
        let scaleTones = Set(mode.intervals.map { (keySemitone(key) + $0) % 12 })

        // Scale tensions: scale tones that are not chord tones
        let scaleTensions = scaleTones.subtracting(chordTones)

        // Avoid tones: chromatic tones not in the scale at all
        let allPCs = Set(0..<12)
        let avoidTones = allPCs.subtracting(scaleTones)

        return (chordTones, scaleTensions, avoidTones)
    }
}
