// ChillTitleGenerator.swift — Chill generation step 8
// Copyright (c) 2026 Zack Urlocker
// Urban/nocturnal/cosmopolitan title vocabulary.
// Five pools: city phrase (50%), French word, English two-word, adj+noun, time-of-day.
// City phrases use three sub-patterns: prefix+city, city+suffix, or "The [City] [Suffix]".
// Mood-shaded: Deep/Dream favor French words; Bright/Free favor English and adj+noun.
// No accents in any word.

import Foundation

struct ChillTitleGenerator {

    static func generate(frame: GlobalMusicalFrame, rng: inout SeededRNG) -> String {
        let roll = rng.nextDouble()

        // City+modifier is always 50%. The remaining 50% is mood-shaded:
        //   Deep/Dream:  French 25%, English 10%, AdjNoun 8%, Time 7%
        //   Bright/Free: French 8%,  English 20%, AdjNoun 18%, Time 4%
        let (french, english, adjNoun): (Double, Double, Double)
        switch frame.mood {
        case .Deep, .Dream:
            (french, english, adjNoun) = (0.75, 0.85, 0.93)   // time = remainder
        case .Bright, .Free:
            (french, english, adjNoun) = (0.58, 0.78, 0.96)   // time = remainder
        }

        if roll < 0.50    { return cityPhrase(rng: &rng) }
        if roll < french  { return frenchWord(rng: &rng) }
        if roll < english { return englishTwoWord(rng: &rng) }
        if roll < adjNoun { return coolAdjectiveNoun(rng: &rng) }
        return timeOfDay(rng: &rng)
    }

    // MARK: - City phrase (50% of all titles, three sub-patterns)

    private static func cityPhrase(rng: inout SeededRNG) -> String {
        let cities = [
            // Montreal neighborhoods
            "Montreal", "Verdun", "Outremont", "Westmount", "Hochelaga",
            "Cote-des-Neiges", "Lachine", "Longueuil", "NDG",
            "L'Avenir", "Bizou", "Loyola",
            // West Island / South Shore
            "Baie d'Urfe", "Dorval", "Pointe-Claire", "Ste-Anne",
            "Beaconsfield", "Kirkland", "Dollard", "Vaudreuil",
            // Quebec cities
            "Saint-Louis-du-Ha!Ha!", "Trois-Rivieres", "Gatineau", "Saguenay",
            "Rimouski", "Chicoutimi", "Jonquiere", "Riviere-du-Loup",
            "Magog", "Granby", "Drummondville", "Chibougamau", "Petawawa",
            "Shawinigan", "Val d'Or", "Hudson", "Sorel", "Sutton",
            // Quebec regions
            "Charlevoix", "Gaspesie", "Abitibi",
            // Other North America
            "Traverse City", "Detroit", "Cadillac", "Alpina", "Midland", "Flint", "Petoskey", "Interlochen", "Long Island", "Point Lookout", "Hicksville",
            "Santa Cruz", "Scotts Valley", "Felton", "Boulder Creek","San Francisco", "Ben Lomond", "Cupertino", "Santa Clara", "San Mateo",
            "Long Lake", "Leland", "Lelenau", "Ann Arbor", "Ypsilanti", "Northport",
            "Glen Arbor","Maple City", "Walled Lake", "Waterloo", "Plymouth",
            "Mississauga","Port Credit", "Toronto", "Etobicoke",
            "TVC", "YYZ", "SFO", "ORD", "LHR", "SJC", "DTW", "LGA","Forest",
            "Berlin", "Mexico", "London", "Mittelwerk", "Avoine", "Farine"
        ]
        let city = cities[rng.nextInt(upperBound: cities.count)]
        let sub  = rng.nextDouble()

        if sub < 0.55 {
            // Pattern A: prefix + city  ("Funeral in Berlin", "Night Train to Dorval")
            let prefixes = [
                // Time-of-day
                "Late Night", "After Dark", "After Midnight", "Before Dawn",
                "Three AM", "Blue Hour", "Last Light", "After Hours",
                "Midnight", "Early", "Sunrise", "Sunset", "Day Break",
                // Atmospheric
                "Low Light", "Still Water", "Quiet", "Cool", "Windy",
                "Slow Burn", "Soft Focus", "Deep", "Open Air",
                "Warm", "Pale Sun", "Rainy", "Snow Bound", "Dark",
                // Directional / geographic
                "West Side", "East Side", "North Shore", "South", "Uptown", "Downtown",
                "Upper", "Old", "Inner", "Winter", "Summer", "Fall", "Midtown",
                // Spy / thriller / mystery prefixes
                "Funeral in",       // Funeral in Berlin (Deighton)
                "The Man from",     // The Man from Mittelwerk
                "Our Man in",       // Our Man in Havana (Greene)
                "Death in",         // Donna Leon / Christie style
                "Murder in",        // classic mystery
                "Night Train to",   // atmospheric Cold War escape feel
                "Midnight in",      // noir
                "Last Train from",  // Cold War / thriller
                "Appointment in",   // Appointment with Death (Christie)
                "Station",          // intelligence world ("Station Berlin")
            ]
            let prefix = prefixes[rng.nextInt(upperBound: prefixes.count)]
            return "\(prefix) \(city)"

        } else if sub < 0.85 {
            // Pattern B: city + suffix  ("Berlin Game", "London File", "Toronto Station")
            let suffixes = [
                "Game", "Set", "Match",          // Len Deighton Game Set Match trilogy
                "File", "Affair", "Protocol",    // spy thriller (Forsyth / le Carre style)
                "Option", "Sanction",            // Trevanian / MacLean style
                "Exchange", "Document",          // tradecraft / Forsyth
                "Memorandum",                    // The Quiller Memorandum
                "Station",                       // Berlin Station (TV)
                "Connection",                    // the Forrest connection
                "Case", "Inquest",               // murder mystery
            ]
            let suffix = suffixes[rng.nextInt(upperBound: suffixes.count)]
            return "\(city) \(suffix)"

        } else {
            // Pattern C: "The [City] [Suffix]" or "From [City] with Love"
            if rng.nextDouble() < 0.20 {
                return "From \(city) with Love"  // From Russia with Love (Fleming)
            }
            let suffixes = [
                "File",          // The Odessa File (Forsyth)
                "Affair",        // Christie / le Carre style
                "Protocol",      // modern thriller
                "Option",        // MacLean style
                "Sanction",      // The Eiger Sanction (Trevanian)
                "Exchange",      // Cold War spy exchange
                "Memorandum",    // The Quiller Memorandum
                "Document",      // Forsyth style
                "Alternative",   // The Afghan Alternative (Forsyth)
            ]
            let suffix = suffixes[rng.nextInt(upperBound: suffixes.count)]
            return "The \(city) \(suffix)"
        }
    }

    // MARK: - French word + modifier

    private static func frenchWord(rng: inout SeededRNG) -> String {
        let words = ["Velours", "Sablier", "Tournesol", "Fromage", "Stylo",
                     "Pamplemousse", "Nuit", "Soiree", "Homard", "Cornichon",
                     "Lune", "Poitrine", "Escargot", "Parapluie", "Nuage", "Poisson",
                     "Nocturne", "Etude", "Reverie", "Gaufrier", "Lumiere"]
        let modifiers = [
            // Time-of-day
            "Late Night", "After Dark", "After Midnight", "Before Dawn",
            "Three AM", "Blue Hour", "Last Light", "Midnight",
            // Directional / atmospheric
            "Upper", "Old", "Inner", "West End", "East Side", "North Shore",
            "Deep", "Quiet", "Cool", "Warm", "Low Light", "Still",
        ]
        let word = words[rng.nextInt(upperBound: words.count)]
        let mod  = modifiers[rng.nextInt(upperBound: modifiers.count)]
        return "\(mod) \(word)"
    }

    // MARK: - English two-word

    private static func englishTwoWord(rng: inout SeededRNG) -> String {
        let combos = ["Blue Hour", "Glass City", "Slow Burn", "Night Tide",
                      "Soft Focus", "Low Light", "Still Water", "Quiet Pulse",
                      "Cool Rain", "Dark Honey", "Last Call", "Neon Fog",
                      "Deep Current", "Open Air", "Pale Sun",
                      "Still Frame", "Warm Static", "Cold Burn", "Low Heat", "Slow Exposure"]
        return combos[rng.nextInt(upperBound: combos.count)]
    }

    // MARK: - Adj + noun generative

    private static func coolAdjectiveNoun(rng: inout SeededRNG) -> String {
        let adjectives = ["Quiet", "Still", "Low", "Deep", "Soft",
                          "Cool", "Slow", "Dark", "Late", "Warm",
                          "Cold", "Faint", "Long"]
        let nouns      = ["Signal", "Motion", "Shore", "Grain", "Current",
                          "Distance", "Drift", "Moment", "Surface", "Echo",
                          "Frame", "Cut", "Dissolve", "Exposure"]
        let adj  = adjectives[rng.nextInt(upperBound: adjectives.count)]
        let noun = nouns[rng.nextInt(upperBound: nouns.count)]
        return "\(adj) \(noun)"
    }

    // MARK: - Chill Soho

    /// Chill Soho titles: London, Soho's streets, Hull, the cafe, and the mid-80s. Same two-word
    /// register as base Chill, and the same light tone — the base bank has Escargot and
    /// Pamplemousse beside real Montreal place names, so Gaggia, Filofax and Wine Bar belong here.
    ///
    /// Hull is here because Tracey Thorn and Ben Watt met at Hull University. Words come from
    /// "Title generation" in docs/chill-soho-plan.md, checked against the base bank: none collide.
    /// No accents ("Cafe", not "Café"), matching the base Chill rule.
    /// Chill Soho titles. Eight forms, all built from parts — measured across 4,000 songs, the
    /// old shape produced only 199 effectively distinct titles, so one song in five repeated an
    /// earlier one (Zack, 2026-10-11). Two bottlenecks caused most of it: a late-night form that
    /// picked from eight finished strings, and a period form of 4 adjectives by 7 nouns.
    static func generateSoho(rng: inout SeededRNG) -> String {
        switch rng.weightedPick([0.25, 0.17, 0.13, 0.12, 0.09, 0.09, 0.07, 0.05, 0.03]) {
        case 0:  return sohoPlace(rng: &rng)
        case 1:  return sohoCafe(rng: &rng)
        case 2:  return sohoPeriod(rng: &rng)
        case 3:  return sohoPreposition(rng: &rng)
        case 4:  return sohoVenue(rng: &rng)
        case 5:  return sohoLateNight(rng: &rng)
        case 6:  return sohoPair(rng: &rng)
        case 7:  return sohoGerund(rng: &rng)
        default: return sohoClock(rng: &rng)
        }
    }

    // MARK: - Soho word banks
    //
    // Tests read these rather than keeping their own copy: a hand-copied list went out of date
    // once already and failed the suite for no musical reason.

    /// Real Soho streets. The substyle is named for the place, so this is the one bank that
    /// should never be invented.
    static let sohoStreets = ["Wardour", "Berwick", "Dean", "Frith", "Greek", "Carnaby", "Brewer",
                              "Old Compton",  "Rupert", "Archer",
                              "Broadwick", "Kingly", "Marshall", "Noel", "Ganton",
                              "Romilly", "Hollen", "Denmark"]

    /// The streets that read as a name on their own, without "Street" after them — the ones a
    /// listener has heard of. "Dean Lights" works; "Broadwick Doorway" is nothing.
    static let sohoStreetsKnown = ["Wardour", "Berwick", "Dean", "Frith", "Greek", "Carnaby",
                                   "Brewer", "Old Compton"]

    static let sohoLondon  = ["Fitzrovia", "Marylebone", "Mayfair", "Camden", "Islington",
                              "Hackney", "Brixton", "Portobello", "Ladbroke", "Kensington",
                              "Chelsea", "Shoreditch", "Clerkenwell", "Bloomsbury", "Pimlico",
                              "Barbican", "Bermondsey", "Hoxton", "Dalston", "Maida Vale",
                              "Covent Garden", "Holborn",
                              "West End", "East End", "Woking", "Dorking",
                              "Bromley", "Guildford", "Dagenham"]

    /// The squares, which take no "Street" after them. Berkeley Square carries a standard of its
    /// own ("A Nightingale Sang in..."), and Grosvenor is a minute from it — both Zack's (2026-10-11).
    static let sohoSquares = ["Berkeley Square", "Grosvenor Square", "Soho Square", "Golden Square",
                              "Hanover Square", "Manchester Square", "Fitzroy Square",
                              "Bedford Square", "Portman Square", "Cavendish Square",
                              "Russell Square", "Sloane Square"]

    /// Streets that carry their own thoroughfare word, so nothing is appended to them —
    /// "King's Road Rain", "Rain on King's Road".
    static let sohoNamedStreets = ["King's Road", "Portobello Road", "Shaftesbury Avenue"]

    /// London rooms where this music was actually played, late 70s to late 80s. Sade's own circuit
    /// is most of the Soho half — Ronnie Scott's, etc. `article` is whether the name
    /// takes a "the": "at the Wag", but "at Ronnie Scott's".
    /// `article` is whether the name takes a "the" — "at the Marquee", but "at Ronnie Scott's".
    /// `alone` is whether it can stand as a whole title: "The 101 Club" works, "The BBC" does not.
    ///
    /// The pub rooms are Zack's (2026-10-12), after the Hope & Anchor — London pubs where a great
    /// many records were made, and nearer this music's world than the clubs alone. The Wag and
    /// Crackers came out at the same time.
    static let sohoVenues: [(name: String, article: Bool, alone: Bool)] = [
        ("Ronnie Scott's", false, true), ("100 Club", true, true), ("101 Club", true, true),
        ("Marquee", true, true), ("Le Beat Route", false, true), ("Dingwalls", false, true),
        ("Palladium", true, true), ("Camden Palace", false, true), ("Lyceum", true, true),
        ("Hammersmith Palais", false, true), ("Electric Ballroom", true, true),
        ("Bass Clef", false, true), ("Embassy Club", true, true),
        ("Jazz Cafe", true, true), ("Astoria", true, true), ("Legends", false, true),
        ("Hope & Anchor", true, true), ("Roundhouse", true, true),
        ("Nashville Rooms", true, true), ("Greyhound", true, true), ("BBC", true, false),
        ("Rainbow", true, true), ("Hammersmith Odeon", true, true), ("Brixton Academy", false, true),
        ("Borderline", true, true),
        // The Tube — Channel 4, 1982-87, Jools Holland co-hosting and bands playing live. Reads
        // as the programme and as the Underground at the same time.
        ("Tube", true, true),
    ]

    /// Hull, where Everything But The Girl formed. Not extended past the names a listener outside
    /// Yorkshire might place — Zack ruled that out (2026-10-11), and he is right that the smaller
    /// East Riding names read as nowhere at all.
    static let sohoHull    = ["Hull", "Humber", "Hessle", "Beverley", "Spurn", "Holderness",
                              "Cottingham", "Hedon", "Withernsea"]
    static let sohoCafeNouns = ["Cafe", "Espresso", "Cappuccino", "Latte", "Macchiato", "Croissant",
                                "Demitasse", "Brasserie", "Bistro", "Patisserie", "Pavement",
                                "Terrace", "Booth", "Banquette", "Formica", "Saucer", "Crema",
                                "Ristretto", "Cortado", "Americano", "Percolator", "Cafetiere",
                                "Ashtray", "Counter", "Window Seat", "Caff", "Tablecloth", "Sandwich Bar"]

    static let sohoPeriodAdjectives = ["Pastel", "Linen", "Chrome", "Neon", "Suede", "Satin", "Broken", "Torn",
                                       "Velvet", "Monochrome", "Sepia", "Oyster", "Slate",
                                       "Charcoal", "Powder Blue", "Ivory", "Brass", "Glass",
                                       "Pearl", "Taupe"]

    /// The mid-80s by its objects. Some are trade names — Filofax, Walkman, Betamax — which is
    /// how the period is remembered; the bank already worked that way.
    static let sohoPeriodNouns = ["Filofax", "Walkman", "Cassette", "Discotheque", "Wine Bar",
                                  "Suit", "Betamax", "Lambretta", "Vespa", "Polaroid",
                                  "Telex", "Pager", "Minicab", "Payphone", "Espadrilles", "Loafers",
                                  "Trench Coat", "Ticket Stub", "Deck Shoes", "Answerphone",
                                  "Overcoat", "Brogues", "Raincoat", "Bangers & Mash", "Pie & Mash", "Brothel Creepers",
                                  "Mixtape", "12-Inch", "B-Side", "Sleeve Notes", "Travelcard",
                                  "Phone Box", "Tube Map", "Hi-Fi",
                                  "Melody Maker", "NME",
                                  "Sinclair", "Spectrum", "Psion",
                                  // Mod tailoring. Burton is Montague Burton, where most British
                                  // men bought a suit — the origin of "the full Monty".
                                  "Sta-Prest Suit", "Desert Boots", "Burton Suits"]

    /// What is in the air on the street outside.
    static let sohoAtmosphere = ["Rain", "Smoke", "Lights", "Frost", "Neon", "Dust", "Shadows",
                                 "Voices", "Footsteps", "Headlights", "Taxis", "Laughter", "Snow",
                                 "Steam", "Traffic", "Thunder"]

    /// Somewhere just out of the weather.
    static let sohoInteriors = ["Doorway", "Stairwell", "Basement", "Back Room", "Side Street", "Tube Station",
                                "Window", "Alley", "Courtyard", "Lobby", "Booth", "Last Carriage",
                                "Cloakroom", "Forecourt", "Long Bar", "Corridor", "Underground"]

    static let sohoPairNouns = sohoAtmosphere + ["Coffee", "Cigarettes", "Sunday", "Silence",
                        "Vinyl", "Static", "Velvet", "Gold", "Matches"]

    static let sohoGerunds = ["Waiting", "Walking", "Driving", "Dancing", "Leaving", "Falling",
                              "Drifting", "Counting", "Watching", "Holding On", "Coming Down",
                              "Getting Home", "Running Late", "Looking Back"]

    /// Tails that follow any of the gerunds above.
    static let sohoGerundTails = ["Home in the Rain", "Through Soho", "in the Small Hours",
                                  "Past Closing Time", "to the Last Song", "Without You",
                                  "Until Monday", "After Midnight", "in the Blue Hour",
                                  "on a Wet Thursday", "Down to Berwick Street", "All Night"]

    /// Tails that need a verb of waiting. "Waiting for the Last Train" works; "Walking for the
    /// Last Train" does not, which is what the single tail bank was producing.
    static let sohoWaitingTails = ["for the Last Train", "for the Lights to Change",
                                   "for the Night Bus", "for Monday", "for the Rain to Stop",
                                   "for Closing Time"]

    static let sohoLateNightHeads = ["Last Orders", "Closing Time", "Small Hours", "Late Licence",
                                     "Last Bus Home", "Sunday Papers", "Half Ten", "Last Call",
                                     "Lock-In", "Night Bus", "First Light", "Last Round",
                                     "Kicking Out Time", "One for the Road"]

    static let sohoClockHours = ["One", "Two", "Three", "Four", "Five", "Midnight", "Dawn"]

    /// Every word a Soho title is guaranteed to contain at least one of — the head bank of each
    /// of the eight forms.
    static var sohoVocabulary: [String] {
        sohoStreets + sohoLondon + sohoHull + sohoSquares + sohoNamedStreets
            + sohoVenues.map(\.name) + sohoCafeNouns
            + sohoPeriodNouns + sohoAtmosphere + sohoPairNouns + sohoGerunds + sohoLateNightHeads
            + sohoClockHours
    }

    private static func pick(_ a: [String], _ rng: inout SeededRNG) -> String {
        a[rng.nextInt(upperBound: a.count)]
    }

    /// A Soho street in its full form: "Wardour Street". A fifth of the time, a square instead —
    /// "Rain on Berkeley Square" is the same sentence and a better one.
    private static func street(_ rng: inout SeededRNG) -> String {
        rng.nextDouble() < 0.20 ? pick(sohoSquares + sohoNamedStreets, &rng)
                                : "\(pick(sohoStreets, &rng)) Street"
    }

    /// A venue with its article: "the Marquee", "Ronnie Scott's".
    private static func venue(_ rng: inout SeededRNG) -> String {
        let v = sohoVenues[rng.nextInt(upperBound: sohoVenues.count)]
        return v.article ? "the \(v.name)" : v.name
    }

    // MARK: - Soho title forms

    /// "Frith Street", "Late Night Mayfair", "Last Train to Hull", "Portobello Rain".
    private static func sohoPlace(rng: inout SeededRNG) -> String {
        let sub = rng.nextDouble()
        if sub < 0.35 {
            // A real Soho street, as a street or with a nocturnal noun.
            if rng.nextDouble() < 0.5 { return "\(pick(sohoStreets, &rng)) Street" }
            let st = pick(sohoStreetsKnown, &rng)
            return "\(st) \(pick(["Corner", "Lights", "Rain", "Hours", "Mews", "Nights", "Doorway", "Morning"], &rng))"
        }
        // A street keeps its "Street" in these forms. Half the bank is only a name once it has
        // one — "Rainy Beak" and "Winter in Ganton" are nothing, "Rainy Beak Street" is a place.
        let named = sohoLondon + sohoHull + sohoSquares + sohoNamedStreets
            + sohoStreets.map { "\($0) Street" }
        let place = pick(named, &rng)
        if sub < 0.75 {
            let prefixes = ["Late Night", "After Hours", "Blue Hour", "Last Light", "Before Dawn",
                            "Three AM", "Rainy", "Soft Focus", "Low Light", "Sunday",
                            "Midnight in", "Last Train to", "Night Bus to", "Back to",
                            "Winter in", "Walking Home to", "Somewhere Near", "A Letter from"]
            return "\(pick(prefixes, &rng)) \(place)"
        }
        let suffixes = ["Rain", "Blue", "Morning", "Evening", "Lights", "Drift", "Hours", "Grey",
                        "Weather", "Sunday", "Afterglow", "Winter"]
        return "\(place) \(pick(suffixes, &rng))"
    }

    /// "Midnight Espresso", "Pavement Cafe", "Greek Street Bistro", "Gaggia at Dawn".
    private static func sohoCafe(rng: inout SeededRNG) -> String {
        if rng.nextDouble() < 0.30 {
            return "\(street(&rng)) \(pick(["Cafe", "Espresso", "Bistro", "Brasserie", "Terrace"], &rng))"
        }
        let mods = ["Midnight", "Late", "Rainy", "Corner", "Pavement", "Window", "Sunday",
                    "Second", "Cold", "Last", "Morning", "Quiet", "Empty", "Winter", "First"]
        let mod = pick(mods, &rng)
        var word = pick(sohoCafeNouns, &rng)
        // Never "Pavement Pavement", and never "Window Window Seat" either.
        if word.localizedCaseInsensitiveContains(mod) { word = "Cafe" }
        return "\(mod) \(word)"
    }

    /// The mid-80s: "Neon Filofax", "Pastel Walkman", "Chrome Discotheque", "Linen Wine Bar".
    /// (A bare "Wine Bar" shortcut put that one phrase in a tenth of all titles; it now appears
    /// only as one noun among many.)
    private static func sohoPeriod(rng: inout SeededRNG) -> String {
        "\(pick(sohoPeriodAdjectives, &rng)) \(pick(sohoPeriodNouns, &rng))"
    }

    /// Something in the air, somewhere specific: "Rain on Wardour Street", "Smoke in the Doorway".
    private static func sohoPreposition(rng: inout SeededRNG) -> String {
        let subject = pick(sohoAtmosphere, &rng)
        return rng.nextDouble() < 0.45
            ? "\(subject) on \(street(&rng))"
            : "\(subject) in the \(pick(sohoInteriors, &rng))"
    }

    /// A night at a real room: "Saturday at the Wag", "Midnight at Ronnie Scott's",
    /// "Dancing at Le Beat Route", "The 101 Club".
    private static func sohoVenue(rng: inout SeededRNG) -> String {
        let sub = rng.nextDouble()
        if sub < 0.15 {
            // Standing alone, the article leads the title and takes a capital. Not every room
            // can: "The BBC" is not a song title, though "Live at the BBC" is.
            let standalone = sohoVenues.filter(\.alone)
            let v = standalone[rng.nextInt(upperBound: standalone.count)]
            return v.article ? "The \(v.name)" : v.name
        }
        if sub < 0.35 { return "\(pick(sohoGerunds, &rng)) at \(venue(&rng))" }
        // "Live" and "Session" are what precede a room on a record sleeve — Zack asked for
        // "at the BBC", and that is the sentence it belongs in.
        let when = ["Saturday", "Friday", "Sunday Night", "Midnight", "Last Orders",
                    "Closing Time", "Two AM", "Late Night", "First Night", "Last Night",
                    "Tuesday", "After Hours", "Live", "Session", "Sunday Afternoon"]
        return "\(pick(when, &rng)) at \(venue(&rng))"
    }

    /// British late-night vocabulary, now built rather than picked whole: "Last Orders",
    /// "Closing Time in the Rain", "Half Ten on Berwick Street".
    private static func sohoLateNight(rng: inout SeededRNG) -> String {
        let head = pick(sohoLateNightHeads, &rng)
        guard rng.nextDouble() < 0.55 else { return head }
        if rng.nextDouble() < 0.30 { return "\(head) on \(street(&rng))" }
        if rng.nextDouble() < 0.25 { return "\(head) at \(venue(&rng))" }
        let tails = ["in the Rain", "Again", "Alone", "Without You", "and After", "Somewhere Else",
                     "in Soho", "on a Wednesday", "and No Taxis", "in the Cold"]
        return "\(head) \(pick(tails, &rng))"
    }

    /// Two nouns and nothing else: "Coffee and Rain", "Cigarettes and Sunday".
    private static func sohoPair(rng: inout SeededRNG) -> String {
        let first = pick(sohoPairNouns, &rng)
        // Never a pair that says the same thing twice — "Lights and Headlights".
        let rest  = sohoPairNouns.filter {
            !$0.localizedCaseInsensitiveContains(first) && !first.localizedCaseInsensitiveContains($0)
        }
        return "\(first) and \(pick(rest, &rng))"
    }

    /// "Waiting for the Last Train", "Walking Home in the Rain", "Drifting Down Dean Street".
    private static func sohoGerund(rng: inout SeededRNG) -> String {
        if rng.nextDouble() < 0.22 {
            return "\(pick(["Waiting", "Watching"], &rng)) \(pick(sohoWaitingTails, &rng))"
        }
        let verb = pick(sohoGerunds, &rng)
        if rng.nextDouble() < 0.30 {
            return "\(verb) \(pick(["Down", "Along", "Through", "Past"], &rng)) \(street(&rng))"
        }
        var tail = pick(sohoGerundTails, &rng)
        // Never "Getting Home Home in the Rain".
        if verb.hasSuffix("Home") && tail.hasPrefix("Home") { tail = "in the Rain" }
        return "\(verb) \(tail)"
    }

    /// The clock in the small hours: "Quarter to Three", "Ten Past Two", "Half Past Midnight".
    private static func sohoClock(rng: inout SeededRNG) -> String {
        let hour = pick(sohoClockHours, &rng)
        if rng.nextDouble() < 0.30 { return "Half Past \(hour)" }
        let amount = pick(["Quarter", "Ten", "Five", "Twenty"], &rng)
        return "\(amount) \(rng.nextDouble() < 0.5 ? "to" : "Past") \(hour)"
    }

    // MARK: - Time of day

    private static func timeOfDay(rng: inout SeededRNG) -> String {
        let times = ["After Midnight", "Three AM", "Last Set", "Before Dawn",
                     "Late Hour", "After Two", "Last Light", "After Hours",
                     "Midnight Minus One", "Before Blue"]
        return times[rng.nextInt(upperBound: times.count)]
    }
}
