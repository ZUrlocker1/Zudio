// TitleGenerator.swift — Motorik title generator (spec §Motorik Title Generator)

struct TitleGenerator {
    static func generate(frame: GlobalMusicalFrame, rng: inout SeededRNG) -> String {
        let pattern = patterns[rng.nextInt(upperBound: patterns.count)]
        return pattern(frame, &rng)
    }

    // MARK: - Word banks (spec §Title word banks)

    private static let motorikNouns = [
        "Maschine", "Bahn", "Kraft", "Welle", "Licht", "Raum", "Zeit", "Geist",
        "Zug", "Strom", "Feld", "Nacht", "Tag", "Kern", "Punkt", "Lauf"
    ]
    private static let motorikAdjectives = [
        "Ewig", "Dunkel", "Hell", "Klar", "Tief", "Weit", "Stark", "Ruhig",
        "Endlos", "Frei", "Neu", "Alt", "Groß", "Klein", "Schnell", "Langsam"
    ]
    private static let motorikVerbs = [
        "Fährt", "Läuft", "Dreht", "Fließt", "Leuchtet", "Klingt", "Bewegt", "Zieht"
    ]
    private static let englishAtmospheric = [
        "Phase", "Drift", "Pulse", "Grid", "Loop", "Arc", "Current", "Signal",
        "Motion", "Cycle", "Flow", "Trace", "Layer", "Tone", "Field", "Space"
    ]

    // MARK: - Generation patterns

    typealias PatternFn = @Sendable (GlobalMusicalFrame, inout SeededRNG) -> String

    private static let patterns: [PatternFn] = [
        // German noun compound
        { _, rng in
            let a = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            let b = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            return a + b
        },
        // Adjective + Noun
        { _, rng in
            let adj  = motorikAdjectives[rng.nextInt(upperBound: motorikAdjectives.count)]
            let noun = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            return "\(adj) \(noun)"
        },
        // English atmospheric + number
        { _, rng in
            let word = englishAtmospheric[rng.nextInt(upperBound: englishAtmospheric.count)]
            let num  = rng.nextInt(upperBound: 9) + 1
            return "\(word) \(num)"
        },
        // Key-based title
        { frame, rng in
            let word = englishAtmospheric[rng.nextInt(upperBound: englishAtmospheric.count)]
            return "\(frame.key) \(word)"
        },
        // Verb phrase
        { _, rng in
            let verb = motorikVerbs[rng.nextInt(upperBound: motorikVerbs.count)]
            let noun = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            return "\(verb) \(noun)"
        }
    ]
}
