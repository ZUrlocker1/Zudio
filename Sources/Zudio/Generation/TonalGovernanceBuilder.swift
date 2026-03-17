// TonalGovernanceBuilder.swift — generation step 3
// Builds the TonalGovernanceMap from the SongStructure.
// All non-drum tracks query this at render time to get active pitch-class sets.

struct TonalGovernanceBuilder {
    static func build(frame: GlobalMusicalFrame, structure: SongStructure) -> TonalGovernanceMap {
        var map: TonalGovernanceMap = []
        for section in structure.sections {
            guard let window = structure.chordWindow(atBar: section.startBar) else { continue }
            // One entry per chord window within each section
            var bar = section.startBar
            while bar < section.endBar {
                if let cw = structure.chordWindow(atBar: bar) {
                    let entry = TonalGovernanceEntry(
                        chordWindow: cw,
                        sectionLabel: section.label,
                        sectionMode: section.mode
                    )
                    // Avoid duplicating the same chord window entry
                    if map.last?.chordWindow != cw {
                        map.append(entry)
                    }
                    bar = cw.endBar
                } else {
                    bar += 1
                }
            }
            _ = window // suppress unused warning
        }
        return map
    }
}
