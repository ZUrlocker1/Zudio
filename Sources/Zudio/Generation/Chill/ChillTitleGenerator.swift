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
            "Saint-Laurent", "Pointe-Saint-Charles", "Loyola",
            // West Island / South Shore
            "Baie d'Urfe", "Dorval", "Pointe-Claire", "Sainte-Anne",
            "Beaconsfield", "Kirkland", "Dollard", "Vaudreuil",
            // Quebec cities
            "Sherbrooke", "Trois-Rivieres", "Gatineau", "Saguenay",
            "Rimouski", "Chicoutimi", "Jonquiere", "Riviere-du-Loup",
            "Magog", "Granby", "Drummondville",
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
            "Berlin", "Mexico", "London", "Mittelwerk", "Nordhausen", "Dora"
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
        let words = ["Velours", "Sablier", "Solstice", "Brume", "Toile",
                     "Azur", "Nuit", "Soiree", "Homard", "Crepuscule",
                     "Lune", "Reflet", "Silence", "Calme", "Nuage", "Poisson",
                     "Nocturne", "Etude", "Reverie", "Minuit", "Lumiere"]
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

    // MARK: - Time of day

    private static func timeOfDay(rng: inout SeededRNG) -> String {
        let times = ["After Midnight", "Three AM", "Last Set", "Before Dawn",
                     "Late Hour", "After Two", "Last Light", "After Hours",
                     "Midnight Minus One", "Before Blue"]
        return times[rng.nextInt(upperBound: times.count)]
    }
}
