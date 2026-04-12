// KosmicTitleGenerator.swift — Kosmic / space-themed song title generator
//
// Four patterns:
//   1. Single JMJ-X word          — Vortexe, Proxima, Fluxion
//   2. JMJ-X word + Roman numeral — Galaxie II, Paradoxe IV
//   5. Two-word English kosmic     — Dark Nebula, Solar Arc, Void Pulse
//   6. Faux-German adj + noun      — Ewig Kosmos, Dunkel Stern, Tief Welle

struct KosmicTitleGenerator {
    static func generate(frame: GlobalMusicalFrame, rng: inout SeededRNG) -> String {
        let pattern = patterns[rng.nextInt(upperBound: patterns.count)]
        return pattern(frame, &rng)
    }

    // MARK: - Word banks

    /// 3-syllable words containing X — real French/Latin and invented JMJ-style
    private static let jmjXWords = [
        // Real
        "Galaxie", "Proxima", "Axiome", "Paradoxe", "Fluxion", "Maxima",
        // Invented in JMJ style
        "Vortexe", "Galaxene", "Solaxe", "Nexione", "Hexalon", "Flexure",
        "Auxese", "Plexion", "Oxidane", "Luxieme"
    ]

    private static let romanNumerals = ["II", "III", "IV", "V", "VI", "VII", "VIII"]

    private static let kosmicAdjectives = [
        "Solar", "Dark", "Deep", "Void", "Stellar", "Astral", "Polar",
        "Silent", "Orbital", "Distant", "Ancient", "Frozen", "Hollow",
        "Radiant", "Spectral", "Liminal", "Oblique", "Inert", "Ambient", "Forest"
    ]

    private static let kosmicNouns = [
        "Arc", "Field", "Drift", "Pulse", "Nebula", "Void", "Ether",
        "Flux", "Prism", "Helix", "Vortex", "Horizon", "Signal", "Connection",
        "Current", "Phase", "Lattice", "Aurora", "Apex", "Zenith",
        "Parallax", "Apogee", "Solstice", "Perihelion", "Penumbra", "Zorvaak"
    ]

    private static let germanAdjectives = [
        "Ewig", "Tief", "Dunkel", "Fern", "Kalt", "Weit", "Still",
        "Schwarz", "Leer", "Uralt", "Gross", "Sanft", "Trage", "Fahl"
    ]

    private static let germanKosmicNouns = [
        "Kosmos", "Nebel", "Stern", "Raum", "Welle", "Licht", "Aether",
        "Ferne", "Himmel", "Strom", "Feld", "Leere", "Geist", "Tiefe", "Zorvaak",
        "Schwere", "Dunkel", "Stille", "Weite", "Schein", "Hauch", "Basso"
    ]

    // MARK: - Patterns

    typealias PatternFn = @Sendable (GlobalMusicalFrame, inout SeededRNG) -> String

    private static let patterns: [PatternFn] = [

        // 1. Single JMJ-X word  (weight ×2 — most iconic)
        { _, rng in jmjXWords[rng.nextInt(upperBound: jmjXWords.count)] },
        { _, rng in jmjXWords[rng.nextInt(upperBound: jmjXWords.count)] },

        // 2. JMJ-X word + Roman numeral
        { _, rng in
            let word = jmjXWords[rng.nextInt(upperBound: jmjXWords.count)]
            let num  = romanNumerals[rng.nextInt(upperBound: romanNumerals.count)]
            return "\(word) \(num)"
        },

        // 5. Two-word English kosmic
        { _, rng in
            let adj  = kosmicAdjectives[rng.nextInt(upperBound: kosmicAdjectives.count)]
            let noun = kosmicNouns[rng.nextInt(upperBound: kosmicNouns.count)]
            return "\(adj) \(noun)"
        },

        // 6. Faux-German adj + kosmic noun  (weight ×2 — TD flavour)
        { _, rng in
            let adj  = germanAdjectives[rng.nextInt(upperBound: germanAdjectives.count)]
            let noun = germanKosmicNouns[rng.nextInt(upperBound: germanKosmicNouns.count)]
            return "\(adj) \(noun)"
        },
        { _, rng in
            let adj  = germanAdjectives[rng.nextInt(upperBound: germanAdjectives.count)]
            let noun = germanKosmicNouns[rng.nextInt(upperBound: germanKosmicNouns.count)]
            return "\(adj) \(noun)"
        },
    ]
}
