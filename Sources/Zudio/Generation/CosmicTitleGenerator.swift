// KosmicTitleGenerator.swift — Kosmic / space-themed song title generator
// Copyright (c) 2026 Zack Urlocker
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
    static func generate(frame: GlobalMusicalFrame, rng: inout SeededRNG,
                         isKosmicSpace: Bool = false) -> String {
        if isKosmicSpace { return spaceTitle(frame: frame, rng: &rng) }
        let pattern = patterns[rng.nextInt(upperBound: patterns.count)]
        return pattern(frame, &rng)
    }

    // MARK: - Kosmic Space titles
    // Single words repeated too often (Zack, 2026-11-03): 40% of Space titles came from about 63
    // words. Space now has its own patterns, JMJ in spirit and allowed a joke, and a larger single-word
    // pool. Base Kosmic and Drift titles are unchanged. Nothing draws from the song stream after the
    // title, so the extra draws change only the title. No commas or apostrophes: titles become file
    // names, and the save panel strips both.
    //   15% single word          Galexion, Kroneon
    //   15% part number          Fluxion Part 4, Kroneon Part VI
    //   12% two coined words     Magnetique Cosmopod IX, Quantique Orbitron
    //   12% French phrase        Les Chants Paradoxes, Le Grand Plexion, La Nuit Ionique
    //   12% Jarre templates      Waiting for Kroneon, Rendez-Vous a Proxima, Pyreon & Plexion
    //    4% long-running series  Galexion V Part 7 of 42, Plexion 7-13
    //    4% gear jokes           Concerto for Minipops, Laser Harp No 3
    //   26% the earlier Space patterns: word + numeral 6%, fake-Greek + numeral 6%, prefix + word 7%,
    //       adjective + noun 7%

    private static let spaceExtraWords = [
        "Galexion", "Synthetique", "Orbitale", "Cosmodrome", "Ondioline", "Hypnotique", "Zoolon",
        "Equinova", "Stellarix", "Lunatique", "Rotonde", "Gravitone", "Photonique", "Neutrino",
        "Sputnique", "Teslatron", "Polyphonique", "Oscillon"
    ]

    private static let comicNouns = [
        "Cosmopod", "Orbitron", "Moonmoog", "Roboloop", "Laserharp", "Zoomzoom", "Minipod",
        "Pulsotron", "Spacebox", "Starfax", "Teletone", "Moogmobile"
    ]

    /// French adjectives the same in both genders, so they fit Le, La and Les alike
    private static let frenchAdjectives = [
        "Magnetique", "Ionique", "Cosmique", "Quantique", "Electronique", "Hypnotique",
        "Polaire", "Stellaire", "Lunaire", "Paradoxe", "Synthetique", "Galactique"
    ]

    private static let gearTitles = [
        "Concerto for Minipops", "Sonata for Theremin and Stylophone", "Prelude for Eminent 310",
        "Nocturne for ARP 2600", "Suite for Fairlight", "Variations on a Rhythm Box",
        "Laser Harp No", "Etude for Moogs"
    ]

    private static let longRomanNumerals = ["II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XII"]

    private static func spaceTitle(frame: GlobalMusicalFrame, rng: inout SeededRNG) -> String {
        func pick(_ list: [String]) -> String { list[rng.nextInt(upperBound: list.count)] }
        let singles = jmjXWords + greekStyleWords + spaceExtraWords
        let coined  = jmjXWords + spaceExtraWords
        switch rng.weightedPick([0.15, 0.15, 0.12, 0.12, 0.12, 0.04, 0.04, 0.06, 0.06, 0.07, 0.07]) {
        case 0:
            return pick(singles)
        case 1:
            let word = pick(singles)
            return rng.nextDouble() < 0.50 ? "\(word) Part \(2 + rng.nextInt(upperBound: 8))"
                                           : "\(word) Part \(pick(romanNumerals))"
        case 2:
            let name = "\(pick(coined)) \(pick(comicNouns))"
            return rng.nextDouble() < 0.50 ? "\(name) \(pick(longRomanNumerals))" : name
        case 3:
            switch rng.nextInt(upperBound: 5) {
            case 0:  return "Les Chants \(pick(frenchAdjectives.filter { $0 != "Magnetique" }))s"
            case 1:  return "Le Grand \(pick(greekStyleWords))"
            case 2:  return "La Nuit \(pick(frenchAdjectives))"
            case 3:  return "Les Jardins \(pick(frenchAdjectives))s"
            default: return "Le Reve \(pick(frenchAdjectives))"
            }
        case 4:
            switch rng.nextInt(upperBound: 3) {
            case 0:  return "Waiting for \(pick(greekStyleWords + spaceExtraWords))"
            case 1:  return "Rendez-Vous a \(pick(coined))"
            default:
                let first = pick(greekStyleWords)
                return "\(first) & \(pick(greekStyleWords.filter { $0 != first }))"
            }
        case 5:
            let word = pick(coined)
            if rng.nextDouble() < 0.50 {
                let of = [42, 64, 99, 108][rng.nextInt(upperBound: 4)]
                return "\(word) \(pick(longRomanNumerals)) Part \(2 + rng.nextInt(upperBound: 12)) of \(of)"
            }
            let from = 3 + rng.nextInt(upperBound: 7)
            return "\(word) \(from)-\(from + 4 + rng.nextInt(upperBound: 5))"
        case 6:
            let gear = pick(gearTitles)
            if gear == "Laser Harp No" { return "Laser Harp No \(2 + rng.nextInt(upperBound: 8))" }
            if gear == "Etude for Moogs" { return "Etude for \(pick(["Three", "Eight", "Twelve"])) Moogs" }
            return gear
        case 7:  return wordAndNumeral(&rng)
        case 8:  return greekWordAndNumeral(&rng)
        case 9:  return prefixAndWord(&rng)
        default: return spaceAdjectiveAndNoun(&rng)
        }
    }

    // MARK: - Word banks

    /// French/Latin and invented JMJ-inspired words — the sonic signature of Kosmic
    private static let jmjXWords = [
        // JMJ-inspired (not exact titles)
        "Albatroxe", "Nitrogen", "Magnetique", "Electronique", "Chronique",
        // Real French/Latin scientific
        "Galaxie", "Proxima", "Axiome", "Paradoxe", "Fluxion", "Maxima",
        "Orbite", "Cosmique", "Quantique", "Ionique", "Luminare", "Arastradero",
        "Polarite", "Dimensione", "Algorhythme", "Spectrion", "Resonanse",
        // Invented in JMJ style
        "Vortexe", "Galaxene", "Solaxe", "Nexione", "Hexalon", "Flexure",
        "Auxese", "Plexion", "Oxidane", "Luxieme", "Helixe", "Vectore", "Tikkenzeboxes",
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
        "Solar", "Dark", "Deep", "Void", "Stellar", "Astral", "Polar", "Bad",
        "Silent", "Orbital", "Distant", "Ancient", "Frozen", "Hollow",
        "Radiant", "Spectral", "Liminal", "Oblique", "Inert", "Ambient", "Forest"
    ]

    private static let kosmicNouns = [
        "Arc", "Field", "Drift", "Pulse", "Nebula", "Void", "Ether", "Gear",
        "Flux", "Prism", "Helix", "Vortex", "Horizon", "Signal", "Connection",
        "Current", "Phase", "Lattice", "Aurora", "Apex", "Zenith", "Crescendo",
        "Parallax", "Apogee", "Solstice", "Perihelion", "Penumbra", "Galaxy"
    ]

    /// Invented Greek-style words — Tangerine Dream aesthetic (-on, -eon, -ax endings)
    private static let greekStyleWords = [
        "Empyrion", "Orpheon", "Axolotl", "Zephyron", "Kroneon",
        "Aureon",   "Hezperon", "Flummoxx",  "Pneumex",  "Aionex",
        "Zatarax",  "Pyreon",   "FedExx",  "Orthodoxx", "Spandexx",
        "Eideon",   "Zopheon",  "ExLaxx", "Thyreon",  "Aztraeon", "Gyro"
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

    // The four patterns Space titles also draw on, by name

    /// JMJ-X word + Roman numeral
    private static func wordAndNumeral(_ rng: inout SeededRNG) -> String {
        let word = jmjXWords[rng.nextInt(upperBound: jmjXWords.count)]
        let num  = romanNumerals[rng.nextInt(upperBound: romanNumerals.count)]
        return "\(word) \(num)"
    }

    /// Prefix + JMJ-X word  — "Inner Orbite", "Neo Equinoxe"
    private static func prefixAndWord(_ rng: inout SeededRNG) -> String {
        let pre  = kosmicPrefixes[rng.nextInt(upperBound: kosmicPrefixes.count)]
        let word = jmjXWords[rng.nextInt(upperBound: jmjXWords.count)]
        return "\(pre) \(word)"
    }

    /// Space adj + deep-space noun  — "Eternal Cosmos", "Vast Aether"
    private static func spaceAdjectiveAndNoun(_ rng: inout SeededRNG) -> String {
        let adj  = spaceAdjectives[rng.nextInt(upperBound: spaceAdjectives.count)]
        let noun = deepSpaceNouns[rng.nextInt(upperBound: deepSpaceNouns.count)]
        return "\(adj) \(noun)"
    }

    /// Fake-Greek + Roman numeral  — "Orpheon II", "Elyseon IV"
    private static func greekWordAndNumeral(_ rng: inout SeededRNG) -> String {
        let word = greekStyleWords[rng.nextInt(upperBound: greekStyleWords.count)]
        let num  = romanNumerals[rng.nextInt(upperBound: romanNumerals.count)]
        return "\(word) \(num)"
    }

    private static let patterns: [PatternFn] = [

        // 1. Single JMJ-X word  (weight ×2 — most iconic)
        { _, rng in jmjXWords[rng.nextInt(upperBound: jmjXWords.count)] },
        { _, rng in jmjXWords[rng.nextInt(upperBound: jmjXWords.count)] },

        // 2. JMJ-X word + Roman numeral
        { _, rng in wordAndNumeral(&rng) },

        // 3. Prefix + JMJ-X word  (weight ×2)
        { _, rng in prefixAndWord(&rng) },
        { _, rng in prefixAndWord(&rng) },

        // 4. Two-word English kosmic
        { _, rng in
            let adj  = kosmicAdjectives[rng.nextInt(upperBound: kosmicAdjectives.count)]
            let noun = kosmicNouns[rng.nextInt(upperBound: kosmicNouns.count)]
            return "\(adj) \(noun)"
        },

        // 5. Space adj + deep-space noun  (weight ×2)
        { _, rng in spaceAdjectiveAndNoun(&rng) },
        { _, rng in spaceAdjectiveAndNoun(&rng) },

        // 6. Prefix + kosmic noun  — "Exo Helix", "Sub Horizon"
        { _, rng in
            let pre  = kosmicPrefixes[rng.nextInt(upperBound: kosmicPrefixes.count)]
            let noun = kosmicNouns[rng.nextInt(upperBound: kosmicNouns.count)]
            return "\(pre) \(noun)"
        },

        // 7. Fake-Greek single word  (weight ×2 — TD aesthetic)
        { _, rng in greekStyleWords[rng.nextInt(upperBound: greekStyleWords.count)] },
        { _, rng in greekStyleWords[rng.nextInt(upperBound: greekStyleWords.count)] },

        // 8. Fake-Greek + Roman numeral
        { _, rng in greekWordAndNumeral(&rng) },
    ]
}
