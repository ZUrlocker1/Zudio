// KosmicTitleGenerator.swift — Kosmic / space-themed song title generator
//
// Eight patterns:
//   1. Single JMJ-X word            — Vortexe, Proxima, Equinoxe
//   2. JMJ-X word + Roman numeral   — Galaxie II, Paradoxe IV
//   3. Prefix + JMJ-X word          — Inner Orbite, Neo Equinoxe, Trans Galaxie
//   4. Two-word English kosmic       — Dark Nebula, Solar Arc, Void Pulse
//   5. Space adj + deep-space noun  — Eternal Cosmos, Vast Aether, Cold Nimbus
//   6. Prefix + kosmic noun          — Exo Helix, Sub Horizon, Ultra Parallax
//   7. Fake-Greek single word        — Empyrion, Zephyron, Hesperon
//   8. Fake-Greek + Roman numeral    — Orpheon II, Elyseon IV

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

    /// Invented Greek-style words — Tangerine Dream aesthetic (-on, -eon, -ax endings)
    private static let greekStyleWords = [
        "Empyrion", "Orpheon", "Elyseon", "Zephyron", "Kroneon",
        "Aureon",   "Hezperon", "Logion",  "Pneumex",  "Aionex",
        "Zatarax",   "Pyreon",   "Zodeon",  "Hypereon", "Chthonon",
        "Eideon",   "Zopheon",  "Zaerion", "Thyreon",  "Aztraeon", "Zorvaak"
    ]

    /// Poetic space adjectives — atmospheric, distinct from Motorik's German register
    private static let spaceAdjectives = [
        "Eternal", "Vast", "Cold", "Still", "Remote", "Pale",
        "Dense", "Slow", "Soft", "Absolute", "Infinite", "Formless",
        "Faint", "Lone", "Serene", "Boundless", "Timeless"
    ]

    private static let deepSpaceNouns = [
        "Cosmos", "Aether", "Nimbus", "Stratus", "Orbit",
        "Gravity", "Matter", "Spectrum", "Crystal", "Gravitas",
        "Expanse", "Silence", "Interval", "Cascade", "Canopy", "Zorvaak", "Basso"
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

        // 5. Space adj + deep-space noun  (weight ×2)
        { _, rng in
            let adj  = spaceAdjectives[rng.nextInt(upperBound: spaceAdjectives.count)]
            let noun = deepSpaceNouns[rng.nextInt(upperBound: deepSpaceNouns.count)]
            return "\(adj) \(noun)"
        },
        { _, rng in
            let adj  = spaceAdjectives[rng.nextInt(upperBound: spaceAdjectives.count)]
            let noun = deepSpaceNouns[rng.nextInt(upperBound: deepSpaceNouns.count)]
            return "\(adj) \(noun)"
        },

        // 6. Prefix + kosmic noun  — "Exo Helix", "Sub Horizon"
        { _, rng in
            let pre  = kosmicPrefixes[rng.nextInt(upperBound: kosmicPrefixes.count)]
            let noun = kosmicNouns[rng.nextInt(upperBound: kosmicNouns.count)]
            return "\(pre) \(noun)"
        },

        // 7. Fake-Greek single word  (weight ×2 — TD aesthetic)
        { _, rng in greekStyleWords[rng.nextInt(upperBound: greekStyleWords.count)] },
        { _, rng in greekStyleWords[rng.nextInt(upperBound: greekStyleWords.count)] },

        // 8. Fake-Greek + Roman numeral  — "Orpheon II", "Elyseon IV"
        { _, rng in
            let word = greekStyleWords[rng.nextInt(upperBound: greekStyleWords.count)]
            let num  = romanNumerals[rng.nextInt(upperBound: romanNumerals.count)]
            return "\(word) \(num)"
        },
    ]
}
