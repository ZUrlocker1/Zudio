// ChillTitleGenerator.swift — Chill generation step 8
// Urban/nocturnal/cosmopolitan title vocabulary.
// Seven pools: French words, English two-word, city districts, adj+noun (generative),
// time-of-day phrases, single jazz first names, and location phrases (modifier + place).
// Location phrases appear 20–30% of the time; e.g. "Late Night Baie d'Urfé", "Cool Cut Montreal".
// Pool weights are mood-shaded: Deep/Dream favor French words and city districts;
// Bright/Free favor English compounds and generative adj+noun.

import Foundation

struct ChillTitleGenerator {

    static func generate(frame: GlobalMusicalFrame, rng: inout SeededRNG) -> String {
        let roll = rng.nextDouble()

        // Mood-shaded cutoffs (cumulative):
        //   Deep/Dream:  Location 25%, French 25%, English 20%, City 10%, AdjNoun 10%, Time 5%, JazzName 5%
        //   Bright/Free: Location 25%, French 10%, English 28%, City 10%, AdjNoun 20%, Time 4%, JazzName 3%
        let (location, french, english, city, adjNoun, time): (Double, Double, Double, Double, Double, Double)
        switch frame.mood {
        case .Deep, .Dream:
            (location, french, english, city, adjNoun, time) = (0.25, 0.50, 0.70, 0.80, 0.90, 0.95)
        case .Bright, .Free:
            (location, french, english, city, adjNoun, time) = (0.25, 0.35, 0.63, 0.73, 0.93, 0.97)
        }

        if roll < location { return locationPhrase(rng: &rng) }
        if roll < french   { return frenchWord(rng: &rng) }
        if roll < english  { return englishTwoWord(rng: &rng) }
        if roll < city     { return cityDistrict(rng: &rng) }
        if roll < adjNoun  { return coolAdjectiveNoun(rng: &rng) }
        if roll < time     { return timeOfDay(rng: &rng) }
        return jazzName(rng: &rng)
    }

    // MARK: - Title pools

    private static func frenchWord(rng: inout SeededRNG) -> String {
        let words = ["Velours", "Sablier", "Solstice", "Brume", "Toile",
                     "Azur", "Nuit", "Soirée", "Douceur", "Crépuscule",
                     "Lune", "Reflet", "Silence", "Calme", "Nuage",
                     "Nocturne", "Étude", "Reverie", "Minuit", "Lumière"]
        return words[rng.nextInt(upperBound: words.count)]
    }

    private static func englishTwoWord(rng: inout SeededRNG) -> String {
        let combos = ["Blue Hour", "Glass City", "Slow Burn", "Night Tide",
                      "Soft Focus", "Low Light", "Still Water", "Quiet Pulse",
                      "Cool Rain", "Dark Honey", "Last Call", "Neon Fog",
                      "Deep Current", "Open Air", "Pale Sun",
                      "Still Frame", "Warm Static", "Cold Burn", "Low Heat", "Slow Exposure"]
        return combos[rng.nextInt(upperBound: combos.count)]
    }

    private static func cityDistrict(rng: inout SeededRNG) -> String {
        let districts = ["Marais", "Belleville", "Lafayette", "Brixton", "Stoke",
                         "Pigalle", "Montmartre", "Shoreditch", "Brooklyn", "Clichy",
                         "Oberkampf", "Dalston", "Hackney", "Battersea", "Notting Hill",
                         "Saint-Germain", "Bastille", "République", "Amsterdam",
                         "Ladbroke Grove", "Lisbon",
                         "Baie d'Urfé", "Montreal", "Dorval", "Pointe-Claire",
                         "Sainte-Anne-de-Bellevue", "Saint-Laurent",
                         "Traverse City", "Detroit"]
        return districts[rng.nextInt(upperBound: districts.count)]
    }

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

    private static func timeOfDay(rng: inout SeededRNG) -> String {
        let times = ["After Midnight", "Three AM", "Last Set", "Before Dawn",
                     "Late Hour", "After Two", "Last Light", "After Hours",
                     "Midnight Minus One", "Before Blue"]
        return times[rng.nextInt(upperBound: times.count)]
    }

    private static func jazzName(rng: inout SeededRNG) -> String {
        let names = ["Chet", "Miles", "Bill", "Monk", "Gil",
                     "Lee", "Wes", "Hank", "Art", "Bud"]
        return names[rng.nextInt(upperBound: names.count)]
    }

    // MARK: - Location phrase: modifier + place (20–25% of titles)

    private static func locationPhrase(rng: inout SeededRNG) -> String {
        let modifiers = ["Late Night", "After Dark", "Cool", "Still",
                         "Low Light", "West End", "East Side", "North Shore",
                         "Early", "Quiet", "Winter", "Summer Night"]
        let places = ["Baie d'Urfé", "Montreal", "Dorval", "Pointe-Claire",
                      "Saint-Laurent", "Sainte-Anne", "Traverse City",
                      "Saint-Germain", "Marais", "Belleville", "Montmartre",
                      "Shoreditch", "Brixton", "Hackney", "Lisbon",
                      "Brooklyn", "Detroit", "Amsterdam", "Oberkampf"]
        let mod   = modifiers[rng.nextInt(upperBound: modifiers.count)]
        let place = places[rng.nextInt(upperBound: places.count)]
        return "\(mod) \(place)"
    }
}
