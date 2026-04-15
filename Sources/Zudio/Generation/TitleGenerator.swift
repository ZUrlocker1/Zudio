// TitleGenerator.swift — Motorik title generator (spec §Motorik Title Generator)
//
// Seven patterns:
//   1. German noun compound         — MaschineBahn, KraftWelle
//   2. Adjective + Noun             — Ewig Raum, Kalt Strom
//   3. English atmospheric + number — Phase 3, Drift 7
//   4. Key-based title              — C# Drift, Eb Signal
//   5. Verb phrase                  — Fahrt Licht, Blinkt Schnork
//   6. City standalone              — Bochum, Wuppertal, Leipzig
//   7. English word + German noun   — Drift Maschine, Signal Bahn

struct TitleGenerator {
    static func generate(frame: GlobalMusicalFrame, rng: inout SeededRNG) -> String {
        let pattern = patterns[rng.nextInt(upperBound: patterns.count)]
        return pattern(frame, &rng)
    }

    // MARK: - Word banks

    private static let motorikNouns = [
        // Core Motorik vocabulary
        "Maschine", "Bahn", "Kraft", "Welle", "Licht", "Raum", "Zeit", "Geist",
        "Zug", "Strom", "Feld", "Nacht", "Tag", "Kern", "Punkt", "Lauf",
        // Expanded — mechanical, rhythmic, spatial
        "Takt", "Rad", "Spur", "Puls", "Motor", "Ring", "Gleis", "Trieb",
        "Dampf", "Blitz", "Knall", "Kreis", "Schiene",
        // Fake / comic — sounds plausibly German
        "Wumms", "Schnork", "Klonk", "Blinken",
        // Yiddish — Germanic roots, fits right in
        "Schlep", "Schmutz", "Schmaltz", "Gonif", "Mishegoss",
        "Luftmensh", "Nudnik", "Chutzpah", "Plotz", "Shtick",
        // The Man from Mittelwerk
        "Wunderwaffe", "Wunderwaffen",
        "Stollen", "Tunnel", "Zwillinge", "Zwilling",
        "V2", "Vergeltung",
        "Zeitmaschine", "Z-Maschine", "Z-Machine",
    ]

    private static let motorikAdjectives = [
        // Core
        "Ewig", "Dunkel", "Hell", "Klar", "Tief", "Weit", "Stark", "Ruhig",
        "Endlos", "Frei", "Neu", "Alt", "Gross", "Klein", "Schnell", "Langsam",
        // Expanded — cold, mechanical, precise
        "Kalt", "Leise", "Hart", "Grau", "Leer", "Stetig", "Rein", "Scharf", "Blank",
        // Comic — greasy, rusty, rickety
        "Fettig", "Rostig", "Klapprig",
        // Yiddish
        "Mashugga", "Fakakta", "Farklempt", "Farblondzhet",
        // Zorvaak
        "Zorvaak",
    ]

    private static let motorikVerbs = [
        // Core
        "Fahrt", "Lauft", "Dreht", "Fliesst", "Leuchtet", "Klingt", "Bewegt", "Zieht",
        // Expanded — rolling, pulsing, droning
        "Rollt", "Pumpt", "Vibriert", "Pulsiert", "Treibt", "Gleitet",
        "Summt", "Brummt", "Kreist", "Schlagt", "Rattert", "Schnurrt",
        // Comic
        "Blinkt", "Klonkt",
        // Yiddish
        "Schvitz", "Kvetch", "Plotz",
    ]

    private static let englishAtmospheric = [
        // Core
        "Phase", "Drift", "Pulse", "Grid", "Loop", "Arc", "Current", "Signal",
        "Motion", "Cycle", "Flow", "Trace", "Layer", "Tone", "Field", "Space",
        // Expanded
        "Drive", "Track", "Route", "Circuit", "Zone", "Channel", "Vector",
        "Path", "Frequency", "Pattern", "Module", "Axis", "Rail",
    ]

    /// German cities — Kraftwerk's geographic universe
    private static let motorikCities = [
        "Bochum", "Berlin", "Koln", "Hamburg", "Dusseldorf", "Frankfurt",
        "Munchen", "Essen", "Wuppertal", "Dortmund", "Bremen",
        "Hannover", "Leipzig", "Dresden",
        "Nordhausen", "Dora", "Middelbrau", "Mittelwerk",
    ]

    /// City prefixes — English or near-English so they read immediately
    private static let motorikCityPrefixes = [
        "West", "Nord", "Ost", "Sud",
        "Nacht", "Neu", "Alt", "Klein", "Gross",
        "Inner", "Outer", "Deep", "Dark",
    ]

    // MARK: - Generation patterns

    typealias PatternFn = @Sendable (GlobalMusicalFrame, inout SeededRNG) -> String

    private static let patterns: [PatternFn] = [

        // 1. German noun compound  (weight ×2)
        { _, rng in
            let a = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            let b = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            return a + b
        },
        { _, rng in
            let a = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            let b = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            return a + b
        },

        // 2. Adjective + Noun
        { _, rng in
            let adj  = motorikAdjectives[rng.nextInt(upperBound: motorikAdjectives.count)]
            let noun = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            return "\(adj) \(noun)"
        },

        // 3. English atmospheric + number
        { _, rng in
            let word = englishAtmospheric[rng.nextInt(upperBound: englishAtmospheric.count)]
            let num  = rng.nextInt(upperBound: 9) + 1
            return "\(word) \(num)"
        },

        // 4. Key-based title
        { frame, rng in
            let word = englishAtmospheric[rng.nextInt(upperBound: englishAtmospheric.count)]
            return "\(frame.key) \(word)"
        },

        // 5. Verb phrase
        { _, rng in
            let verb = motorikVerbs[rng.nextInt(upperBound: motorikVerbs.count)]
            let noun = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            return "\(verb) \(noun)"
        },

        // 6. City — standalone 40%, prefixed 60%  (weight ×2 — Kraftwerk's geographic universe)
        { _, rng in
            let city = motorikCities[rng.nextInt(upperBound: motorikCities.count)]
            if rng.nextDouble() < 0.4 { return city }
            let pre = motorikCityPrefixes[rng.nextInt(upperBound: motorikCityPrefixes.count)]
            return "\(pre) \(city)"
        },
        { _, rng in
            let city = motorikCities[rng.nextInt(upperBound: motorikCities.count)]
            if rng.nextDouble() < 0.4 { return city }
            let pre = motorikCityPrefixes[rng.nextInt(upperBound: motorikCityPrefixes.count)]
            return "\(pre) \(city)"
        },

        // 7. English word + German noun  — the Düsseldorf hybrid sound
        { _, rng in
            let eng  = englishAtmospheric[rng.nextInt(upperBound: englishAtmospheric.count)]
            let noun = motorikNouns[rng.nextInt(upperBound: motorikNouns.count)]
            return "\(eng) \(noun)"
        },
    ]
}
