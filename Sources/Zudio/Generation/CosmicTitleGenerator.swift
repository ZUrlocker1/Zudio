// KosmicTitleGenerator.swift — Kosmic / space-themed song title generator
//
// Six patterns:
//   1. Single JMJ-X word            — Vortexe, Proxima, Equinoxe
//   2. JMJ-X word + Roman numeral   — Galaxie II, Paradoxe IV
//   3. Prefix + JMJ-X word          — Inner Orbite, Neo Equinoxe, Trans Galaxie
//   4. Two-word English kosmic       — Dark Nebula, Solar Arc, Void Pulse
//   5. Faux-German adj + noun        — Ewig Kosmos, Dunkel Stern, Tief Welle
//   6. Prefix + kosmic noun          — Exo Helix, Sub Horizon, Ultra Parallax

struct KosmicTitleGenerator {
    static func generate(frame: GlobalMusicalFrame, rng: inout SeededRNG) -> String {
        let pattern = patterns[rng.nextInt(upperBound: patterns.count)]
        return pattern(frame, &rng)
    }

    // MARK: - Word banks

    /// French/Latin and invented JMJ-inspired words — the sonic signature of Kosmic
    private static let jmjXWords = [
        // JMJ-inspired (not exact titles)
        "Albatroxe", "Nitrogen", "Magnetique", "Electronique", "Chronique",
        // Real French/Latin scientific
        "Galaxie", "Proxima", "Axiome", "Paradoxe", "Fluxion", "Maxima",
        "Orbite", "Cosmique", "Quantique", "Ionique", "Luminare", "Frequence",
        "Polarite", "Dimensione", "Algorhythme", "Spectrion", "Resonanse",
        // Invented in JMJ style
        "Vortexe", "Galaxene", "Solaxe", "Nexione", "Hexalon", "Flexure",
        "Auxese", "Plexion", "Oxidane", "Luxieme", "Helixe", "Vectore",
        "Morphione", "Catalyxe", "Synapxe", "Aetheron", "Transcendome"
    ]

    private static let romanNumerals = ["II", "III", "IV", "V", "VI", "VII", "VIII"]

    /// Prefix adjectives — electronic / spatial / philosophical
    private static let kosmicPrefixes = [
        "Pre", "Post", "Cyber", "Inner", "Outer", "Dark", "Light",
        "Ultra", "Hyper", "Neo", "Trans", "Astro", "Exo", "Inter",
        "Sub", "Omni", "Supra"
    ]

    private static let kosmicAdjectives = [
        "Solar", "Dark", "Deep", "Void", "Stellar", "Astral", "Polar",
        "Silent", "Orbital", "Distant", "Ancient", "Frozen", "Hollow",
        "Radiant", "Spectral", "Liminal", "Oblique", "Inert", "Ambient", "Forest"
    ]

    private static let kosmicNouns = [
        "Arc", "Field", "Drift", "Pulse", "Nebula", "Void", "Ether",
        "Flux", "Prism", "Helix", "Vortex", "Horizon", "Signal", "Connection",
        "Current", "Phase", "Lattice", "Aurora", "Apex", "Zenith", "Crescendo",
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

        // 3. Prefix + JMJ-X word  — "Inner Orbite", "Neo Equinoxe"  (weight ×2)
        { _, rng in
            let pre  = kosmicPrefixes[rng.nextInt(upperBound: kosmicPrefixes.count)]
            let word = jmjXWords[rng.nextInt(upperBound: jmjXWords.count)]
            return "\(pre) \(word)"
        },
        { _, rng in
            let pre  = kosmicPrefixes[rng.nextInt(upperBound: kosmicPrefixes.count)]
            let word = jmjXWords[rng.nextInt(upperBound: jmjXWords.count)]
            return "\(pre) \(word)"
        },

        // 4. Two-word English kosmic
        { _, rng in
            let adj  = kosmicAdjectives[rng.nextInt(upperBound: kosmicAdjectives.count)]
            let noun = kosmicNouns[rng.nextInt(upperBound: kosmicNouns.count)]
            return "\(adj) \(noun)"
        },

        // 5. Faux-German adj + kosmic noun  (weight ×2 — TD flavour)
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

        // 6. Prefix + kosmic noun  — "Exo Helix", "Sub Horizon"
        { _, rng in
            let pre  = kosmicPrefixes[rng.nextInt(upperBound: kosmicPrefixes.count)]
            let noun = kosmicNouns[rng.nextInt(upperBound: kosmicNouns.count)]
            return "\(pre) \(noun)"
        },
    ]
}
