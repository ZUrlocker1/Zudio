// ChillTitleGenerator.swift — Chill generation step 8
// Urban/nocturnal/cosmopolitan title vocabulary.
// Five pools: city+modifier (50%), French word, English two-word, adj+noun, time-of-day.
// City combinations use a modifier drawn from time-of-day phrases, two-word phrases,
// or directional/atmospheric words — all produce "Modifier City" style titles.
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

    // MARK: - City + modifier (50%)

    private static func cityPhrase(rng: inout SeededRNG) -> String {
        let modifiers = [
            // Time-of-day
            "Late Night", "After Dark", "After Midnight", "Before Dawn",
            "Three AM", "Blue Hour", "Last Light", "After Hours",
            "Midnight", "Early", "Sunrise", "Sunset", "Day Break",
            // Atmospheric two-word
            "Low Light", "Still Water", "Quiet", "Cool", "Windy",
            "Slow Burn", "Soft Focus", "Deep", "Open Air",
            "Warm", "Pale Sun", "Rainy", "Snow Bound", "Dark",
            // Directional / geographic feel
            "West End", "East Side", "North Shore", "South", "Uptown",
            "Upper", "Old", "Inner", "Winter", "Summer", "Fall", "Upper"
        ]
        let cities = [
            // Montreal neighborhoods
            "Montreal", "Verdun",
            "Outremont", "Westmount", "Hochelaga",
            "Cote-des-Neiges", "Lachine", "Longueuil", "NDG",
            "Saint-Laurent", "Pointe-Saint-Charles", "Loyola",
            // West Island / South Shore
            "Baie d'Urfe", "Dorval", "Pointe-Claire", "Sainte-Anne",
            "Beaconsfield", "Kirkland", "Dollard", "Vaudreuil",
            // Quebec cities
            "Sherbrooke", "Trois-Rivieres", "Gatineau", "Saguenay",
            "Rimouski", "Chicoutimi", "Jonquiere", "Riviere-du-Loup",
            "Magog", "Granby", "Drummondville",
            "Shawinigan", "Val-d'Or", "Hudson", "Sorel", "Sutton",
            // Quebec regions
            "Charlevoix", "Gaspesie", "Abitibi",
            // Other North America
            "Traverse City", "Detroit", "Cadillac", "Alpina", "Midland", "Flint", "Petoskey", "Interlochen", "Long Island", "Point Lookout", "Hicksville",
            "Santa Cruz", "Scotts Valley", "Felton", "Boulder Creek","San Francisco", "Ben Lomond", "Cupertino", "Santa Clara", "San Mateo",
            "Long Lake", "Leland", "Lelenau", "Ann Arbor", "Ypsilanti", "Northport",
            "Glen Arbor","Maple City", "Walled Lake", "Waterloo", "Plymouth",
            "Mississauga","Port Credit", "Toronto", "Etobicoke",
        ]
        let mod  = modifiers[rng.nextInt(upperBound: modifiers.count)]
        let city = cities[rng.nextInt(upperBound: cities.count)]
        return "\(mod) \(city)"
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
