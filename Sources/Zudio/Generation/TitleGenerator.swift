// TitleGenerator.swift — Motorik title generator (spec §Motorik Title Generator)
// Copyright (c) 2026 Zack Urlocker
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
        // Beer terms
        "Pils", "Schaum", "Bier", "BierGarten", "Helles", "Dunkels","Altbier", "Kolsch", "Radler","Bock",
        // Fake / comic — sounds plausibly German
        "Wumms", "Schnork", "Klonk", "Blinken", "Zeig", 
        // Yiddish — Germanic roots, fits right in
        "Schlep", "Schmutz", "Schmaltz", "Gonif", "Mishegoss",
        "Luftmensh", "Nudnik", "Chutzpah", "Plotz", "Shtick",
        // The Man from Mittelwerk
        "Wunderwaffe", "Wunderwaffen",
        "Stollen", "Tunnel", "Dehomag ", "Zwilling",
        "V2", "Vergeltung",
        "Zeitmaschine", "Z-Maschine", "Z-Machine", "Gear"
    ]

    private static let motorikAdjectives = [
        // Core
        "Ewig", "Dunkel", "Hell", "Klar", "Tief", "Weit", "Stark", "Ruhig", "Schiaches",
        "Endlos", "Frei", "Neu", "Alt", "Gross", "Klein", "Schnell", "Langsam","Bad",
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
        "Hannover", "Leipzig", "Dresden","Vienna",
        "Nordhausen", "Dora", "Middelbrau", "Mittelwerk",
        "Volkmann","Stinnes", "Riemeck", "Fiedler", "Mundt",
    ]

    /// City prefixes — English or near-English so they read immediately
    private static let motorikCityPrefixes = [
        "West", "Nord", "Ost", "Sud",
        "Nacht", "Neu", "Alt", "Klein", "Gross",
        "Inner", "Outer", "Deep", "Dark",
    ]

    // MARK: - Kraftwerk cluster affix

    /// German-flavoured affix applied only when a Kraftwerk cluster fires, so the character is
    /// visible in the Songs list and not only audible. Non-cluster Motorik titles are untouched.
    ///
    /// Words are kept recognisable to an English speaker — either cognates (Motor, Signal,
    /// System, Magnet) or short and concrete (Werk, Netz, Blitz, Licht). Anything that reads as
    /// English rather than German is out, which is why "Sender" was dropped.

    /// `Auto` and `Radio` are deliberately absent: both compound straight into real Kraftwerk
    /// titles, and the aim is to evoke the idiom, never to reproduce the work.
    private static let kraftwerkPrefixes = [
        "Der", "Die", "Das", "Neo", "Elektro", "Trans", "Ultra", "Hyper",
        "Mikro", "Tele", "Zentral", "Stahl", "Nacht", "Schnell", "Fern", "Tekno",
    ]

    /// Grouped by field in the plan — industry, energy, transport, signal, abstract — and
    /// flattened here because the draw is uniform across all of them.
    ///
    /// Each noun carries its article so "Article + noun" titles are grammatical. "Die Werk" and
    /// "Das Welle" are wrong in a way a German speaker reads immediately, and the whole point of
    /// the affix is that it reads as German.
    private static let kraftwerkNouns: [(word: String, article: String)] = [
        // Industry
        ("Werk", "Das"), ("Maschine", "Die"), ("Motor", "Der"), ("Apparat", "Der"),
        ("Anlage", "Die"), ("Getriebe", "Das"), ("Turbine", "Die"), ("Dynamo", "Der"),
        ("Montage", "Die"), ("Automat", "Der"),
        // Energy
        ("Strom", "Der"), ("Energie", "Die"), ("Funke", "Der"), ("Blitz", "Der"),
        ("Netz", "Das"), ("Leitung", "Die"), ("Kontakt", "Der"), ("Magnet", "Der"),
        // Transport
        ("Bahn", "Die"), ("Fahrt", "Die"), ("Strecke", "Die"), ("Gleis", "Das"),
        ("Tunnel", "Der"),
        // Signal
        ("Signal", "Das"), ("Impuls", "Der"), ("Frequenz", "Die"), ("Kanal", "Der"),
        ("Welle", "Die"), ("Takt", "Der"), ("Echo", "Das"),
        // Abstract
        ("Form", "Die"), ("System", "Das"), ("Struktur", "Die"), ("Muster", "Das"),
        ("Licht", "Das"), ("Zeit", "Die"),
    ]

    /// Actual Kraftwerk song titles. Compounding can land on a real one by accident, so any
    /// formed title is checked against this and redrawn on a hit. Stored lowercased with
    /// spaces and hyphens stripped, which is how isRealTitle normalises its candidate.
    private static let realKraftwerkTitles: Set<String> = [
        "autobahn", "dieroboter", "dasmodel", "radioaktivitat", "computerwelt",
        "computerliebe", "transeuropaexpress", "nummern", "taschenrechner",
        "heimcomputer", "neonlicht", "spacelab", "metropolis", "tanzmusik",
        "kometenmelodie", "mitternacht", "morgenspaziergang", "schaufensterpuppen",
        "technopop", "musiquenonstop", "elektrokardiogramm", "tourdefrance",
        "ruckzuck", "vitamin", "geigercounter", "roboter", "model",
    ]

    private static func isRealTitle(_ s: String) -> Bool {
        realKraftwerkTitles.contains(s.lowercased().filter { !$0.isWhitespace && $0 != "-" })
    }

    /// Exactly one affix — a prefix OR a suffix, never both. A title is never wrapped on both
    /// sides ("Elektro Pulse Werk" is wrong). The last two patterns REPLACE the generated title
    /// rather than affixing to it, so the one-affix rule does not apply to them.
    static func applyKraftwerkAffix(to base: String, rng: inout SeededRNG) -> String {
        // Der/Die/Das work as standalone prefixes ("Der Apparat") but not glued into a compound
        // — "Diedynamo" is not a word. Compounds draw from the rest.
        let compoundPrefixes = kraftwerkPrefixes.filter { !["Der", "Die", "Das"].contains($0) }

        // Motorik titles are often already compounds ("Blinkt Wunderwaffen", "KolschWunderwaffe"),
        // and hanging another word off one of those reads as a mouthful rather than a signal.
        // Past 14 characters, use only the two patterns that REPLACE the title, keeping their
        // 20:10 ratio. Noir and Arcade take the same precaution with their own count < 12 gate.
        let baseIsUnwieldy = base.count > 14

        for _ in 0..<8 {
            let roll = baseIsUnwieldy ? 0.70 + rng.nextDouble() * 0.30 : rng.nextDouble()
            let candidate: String
            if roll < 0.45 {
                candidate = "\(kraftwerkPrefixes[rng.nextInt(upperBound: kraftwerkPrefixes.count)]) \(base)"
            } else if roll < 0.70 {
                candidate = "\(base) \(kraftwerkNouns[rng.nextInt(upperBound: kraftwerkNouns.count)].word)"
            } else if roll < 0.90 {
                // German compound — prefix joined to a noun, no space: "Stahlwelle", "Fernsignal"
                let p = compoundPrefixes[rng.nextInt(upperBound: compoundPrefixes.count)]
                let n = kraftwerkNouns[rng.nextInt(upperBound: kraftwerkNouns.count)].word
                candidate = p + n.lowercased()
            } else {
                let n = kraftwerkNouns[rng.nextInt(upperBound: kraftwerkNouns.count)]
                candidate = "\(n.article) \(n.word)"
            }
            if !isRealTitle(candidate) { return candidate }
        }
        return base   // every draw collided, which should never happen — keep the plain title
    }

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
