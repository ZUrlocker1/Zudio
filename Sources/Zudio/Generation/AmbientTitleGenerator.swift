// AmbientTitleGenerator.swift — Satirical ambient song title generator
//
// Targets the specific pomposity of generative ambient music naming conventions:
//   1. Music for [mundane place]       — parodies Eno "Music for Airports"
//   2. An Ending ([parenthetical])     — parodies Eno "An Ending (Ascent)"
//   3. Weather + UK drab geography     — Damp Pavement at Slough
//   4. The [abstraction] of [tepid]    — The Thermodynamic Properties of Tepid Tea
//   5. Technical adj + mundane context — Stochastic Patterns for a Slow Elevator
//   6. Day + mundane event             — parodies Eno "Thursday Afternoon"
//   7. A [pretentious adj] [banal noun]— A Discreet Humming → A Persistent Fan Noise
//   8. Ambient N: subtitle             — parodies Eno Ambient 1/2/3/4 series
//   9. Through/In/Above [drab setting] — Through Translucent Curtains
//  10. Fake French / faux-European     — Deuxieme part deux
//  11. Loscil-style corrupted neologism— Stagnata, Blandeur, Drizzlement
//  12. Light + mundane surface         — Light Reflected in a Puddle of Oil
//  13. Philosophical observation       — A Meaningful Meeting About Quarterly Targets

struct AmbientTitleGenerator {

    static func generate(rng: inout SeededRNG) -> String {
        let pattern = patterns[rng.nextInt(upperBound: patterns.count)]
        return pattern(&rng)
    }

    // MARK: - Word banks

    private static let functionWords = [
        "Music", "Audio", "Sounds", "Tones", "Textures",
        "Soundscapes", "Ambience", "Studies", "Variations"
    ]

    private static let mundanePlaces = [
        "Dentist Waiting Rooms", "a Drafty Hallway", "the Lower Deck of a Ferry",
        "a Mildly Inadequate Conference Room", "the Queue at Boots",
        "Browsing IKEA on a Sunday", "a Cancelled Train",
        "the Waiting Area of a Tyre Fitting Centre",
        "the Bus that Was Already Full", "Supermarket Self-Checkout",
        "an Uneventful Tuesday", "a Slightly Too Long Meeting",
        "the Leisure Centre Changing Room", "a Business Park in January",
        "the Period Between Lunch and the 3pm Meeting",
        "the NCP Car Park at Dusk", "a Mildly Warm Office",
        "a Regional Distribution Centre", "the Holdmusic",
        "a Slowly Loading Web Page", "an Unattended Printer",
        "the Forecourt of a Petrol Station", "Reconsidering Life Choices",
        "Returning an Item Without a Receipt"
    ]

    private static let endingParentheticals = [
        "That Never Ends", "Possibly", "Eventually",
        "In Which Nothing Much Happens", "Awaiting Confirmation",
        "TBC", "Already Happened", "Subject to Availability",
        "Pending", "More or Less", "See Previous Notes",
        "Under Review", "Not Really", "Gradually, Then All at Once",
        "To Be Rescheduled", "Which Was Actually the Middle",
        "Descending Slowly", "In Which the Tape Simply Runs Out",
        "Pt. II of I", "Do Not Distribute", "Final Version (3)",
        "The One Where Nothing Resolves"
    ]

    private static let weatherConditions = [
        "Damp Pavement", "Mist", "Drizzle", "Light Rain",
        "A Persistent Drizzle", "Low Cloud", "Grey Skies",
        "Morning Fog", "The Smell of Rain on Tarmac",
        "Unremarkable Haze", "Fine Mist", "Intermittent Showers",
        "Overcast Conditions", "Residual Dampness",
        "A Mild Weather Warning", "Patchy Fog"
    ]

    private static let weatherPrepositions = ["at", "over", "near", "above", "outside", "beyond"]

    private static let drabLocations = [
        "Slough", "Stevenage", "the Retail Park", "Milton Keynes", "Luton",
        "the Industrial Estate", "the Business Park", "a Roundabout",
        "the Lower Car Park", "a Disused Underpass", "Basingstoke",
        "the Ring Road", "a Disused Gravel Pit", "the Trading Estate",
        "Hemel Hempstead", "the NCP Car Park", "a Suburban Cul-de-Sac",
        "the Service Station", "the B2047", "the Overflow Car Park",
        "a Light Industrial Unit", "the Dual Carriageway",
        "the Goods Entrance", "a Medium-Sized Retail Park"
    ]

    private static let abstractNouns = [
        "The Memory", "The Properties", "The Persistence",
        "The Thermodynamic Properties", "The Geometry",
        "The Topology", "The Absence", "The Curvature",
        "The Structural Integrity", "The Gradual Decay",
        "The Fading Echo", "The Quiet Insistence",
        "The Phenomenology", "The Specific Gravity",
        "The Load-Bearing Capacity", "The Half-Life"
    ]

    private static let tepidSubjects = [
        "a Beige Wall", "Tepid Tea", "the Waiting Room",
        "a Slightly Damp Coat", "Mildly Warm Coffee",
        "an Unread Email", "a Forgotten Password",
        "a Partially Eaten Sandwich", "the Suspended Ceiling",
        "a Persistent Low-Level Hum", "a Lukewarm Radiator",
        "the Beige Carpet", "a Receding Hairline",
        "an Unanswered Voicemail", "the Fire Exit",
        "a Nearly Empty Stapler", "Mild Disappointment"
    ]

    private static let technicalAdjectives = [
        "Stochastic", "Recursive", "Algorithmic", "Probabilistic",
        "Thermodynamic", "Entropic", "Parametric", "Non-Deterministic",
        "Emergent", "Iterative", "Tautological", "Self-Referential",
        "Asymptotic", "Non-Euclidean", "Heuristic", "Brownian"
    ]

    private static let technicalNouns = [
        "Patterns", "Textures", "Fragments", "Functions",
        "Oscillations", "Drifts", "Sequences", "Feedback",
        "Processes", "Permutations", "Data", "Decay Functions",
        "Error Rates", "Gradient Descent", "Signal Loss"
    ]

    private static let mundaneActivities = [
        "a Slow Elevator", "the Monday Commute",
        "Reconsidering Your Career Path", "an Uneventful Tuesday",
        "a Mild Administrative Error", "an Unscheduled Meeting",
        "Completing a Form in Triplicate", "a Lukewarm Room",
        "the Lower Suburbs", "a Slight Change of Plans",
        "a Poorly Attended Meeting", "a Delayed Reply",
        "an Unremarkable Wednesday", "an Expired Parking Permit",
        "a Very Slow Download", "a Mildly Inconvenient Error Message"
    ]

    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Sunday"]

    private static let mundaneEvents = [
        "Afternoon", "Lunch", "Morning", "Evening",
        "the 3pm Meeting", "a Routine Dental Appointment",
        "a Mild Disagreement", "a Brief Drizzle", "Persistent Drizzle",
        "a Slight Delay", "a Tepid Coffee", "a Cancelled Appointment",
        "Nothing in Particular", "the Usual", "a Light Lunch",
        "a Slightly Long Queue", "an Awkward Silence",
        "a Missed Connection", "a Gentle Administrative Inconvenience"
    ]

    private static let pretentiousAdjectives = [
        "Discreet", "Mild", "Brief", "Persistent", "Gentle",
        "Lukewarm", "Quiet", "Gradual", "Unremarkable",
        "Faint", "Vague", "Indeterminate", "Hollow", "Ambient"
    ]

    private static let mundaneSounds = [
        "Humming", "Droning", "Hiss", "Ticking", "Background Noise",
        "Fan Noise", "Rattling", "Gurgling", "Beeping", "Whirring",
        "Air Conditioning", "Distant Traffic", "Lift Music",
        "The Sound of a Building Settling", "Printer Noise",
        "A Fluorescent Tube Flickering", "A Tap Dripping",
        "The Noise the Boiler Makes"
    ]

    private static let ambientSubtitles = [
        "Music for Spreadsheets", "Day of Moderate Precipitation",
        "On the Ring Road", "The Plateaux of the Car Park",
        "On Beige", "Thinking Music III", "Mild Weather",
        "Thursday Afternoon (Revised)", "On Hold",
        "Music for the DMV", "Studies in Low Effort",
        "Atmospheres of the M25", "On Tepid", "Day of Low Motivation"
    ]

    private static let drabSettings = [
        "Translucent Curtains", "a Net Curtain", "a Frosted Window",
        "the Gap Under the Door", "a Stairwell",
        "a Fluorescent-Lit Corridor", "a Partially Open Office Door",
        "a Fogged Car Window", "the Suspended Ceiling Tiles",
        "a Venetian Blind", "a Fire Door (Propped Open)",
        "the Internal Window of a Conference Room",
        "a Revolving Door That Moves Too Slowly"
    ]

    private static let frenchWords   = ["Deuxième", "Troisième", "Quatrième", "Fragment", "Suite", "Reprise"]
    private static let frenchTargets = [
        "Part Deux", "Pensées", "Pour le Car Park", "Numéro Trois",
        "Pour la Salle d'Attente", "Studies", "Encore Une Fois (Reluctant)",
        "Interlude (Unnecessary)", "Coda (Unresolved)"
    ]

    // Craven Faults style — terse obscure geological/topographical single words
    private static let cravenFaultsTerms = [
        "Drumlins", "Grykes", "Clints", "Shakeholes", "Erratics",
        "Soughs", "Rakes", "Screes", "Swales", "Kettle Holes",
        "Alluvium", "Corries", "Runnels", "Loess", "Ghylls",
        "Moraines", "Eskers", "Tarns", "Kames", "Outwash",
        "Unconformities", "Striations", "Pavements", "Drumlins"
    ]

    // Craven Faults "X & Y" compound — geological term + mundane administrative noun
    private static let cravenAdminNouns = [
        "Spreadsheets", "Overpayments", "Pending Items", "Resubmissions",
        "Amendments", "Carryovers", "Adjustments", "Shortfalls",
        "Outstanding Actions", "Deferrals", "Reconciliations", "Variance Reports"
    ]

    // JMJ-style French concept words (parody of Oxygène, Équinoxe, etc.)
    private static let jmjConcepts = [
        "Oxygène", "Équinoxe", "Magnétique", "Chronologie",
        "Métamorphoses", "Électronique", "Atmosphère",
        "Cosmique", "Solstice", "Méridien", "Lumineux",
        "Téléphonie", "Zénith", "Isotrope"
    ]

    // JMJ mundane deflating suffixes
    private static let jmjDeflators = [
        "Part 47", "Part 23 (Revised)", "For One Person",
        "In a Slightly Stuffy Office", "Without the Good Synthesizer",
        "Pt. II (The Sad One)", "En Route to the Car Park",
        "Suite for Overhead Projector", "Live from Basildon",
        "The Director's Cut (Shorter)", "Pour le Ring Road",
        "Version 3 (Almost Final)", "Performed on a Broken Keyboard",
        "With Reduced Funding", "For a Mostly Empty Arena"
    ]

    // Loscil-style neologisms: sounds profound, is subtly damp
    private static let neologisms = [
        "Stagnata", "Blandeur", "Ambiguance", "Tepidity", "Greyscape",
        "Beigenoise", "Dullitude", "Drizzlement", "Ambivalance",
        "Middlespace", "Nullscape", "Voidance", "Blankture",
        "Stagnance", "Residuum", "Overhang", "Flatline Studies",
        "Mildura", "Muted", "Overcast", "Plateau", "Droning",
        "Inertia Studies", "Tepidness", "Carpeting",
        "Substagna", "Greyform", "Dampworks", "Sedimentia",
        "Murkling", "Fogware", "Drearscape", "Blankwave",
        "Hazura", "Stillence", "Tidemarks", "Vapourings",
        "Mistform", "Pallor", "Residua"
    ]

    private static let lightConditions = [
        "Light Reflected", "Grey Light Falling", "Refracted Light",
        "Diffuse Light Pooling", "Fluorescent Light Flickering",
        "Light Scattering Across", "Pale Light Resting On",
        "Ambient Light Failing Above"
    ]

    private static let mundaneSurfaces = [
        "a Puddle of Oil", "the Car Park Tarmac", "a Polished Floor",
        "the Office Partition", "a Cheap Laminate Surface",
        "a Fogged Mirror", "the Suspended Ceiling Tiles",
        "an Off-White Wall", "a Lukewarm Cup of Tea",
        "the Back of a Bus Seat", "a Fire Door",
        "a Slightly Damp Pavement"
    ]

    private static let philosophicalOpeners = [
        "A Meaningful", "An Important", "A Significant", "A Decisive",
        "A Transformative", "A Pivotal", "A Nuanced"
    ]

    private static let philosophicalEvents = [
        "Meeting About Quarterly Targets", "Moment Through a Pointless Process",
        "Discussion of Car Park Allocation", "Pause Before the Next Slide",
        "Reflection on the Biscuit Selection", "Contribution to the Team Away Day",
        "Response to the Previous Email", "Consideration of the Updated Policy",
        "Acknowledgement of the Situation", "Review of the Situation (Ongoing)"
    ]

    // Fake scale names — either plausible-sounding corruptions or
    // openly absurd combinations of real theory jargon with mundane life
    private static let fakeScaleNames = [
        // User's examples (selected good ones)
        "Hyper-Hypo-Lydian", "Pseudo-Phrygian Dominant-ish", "Locrian-Shmocrian",
        "Neapolitan Major", "Aeroplanian", "Mixerlydian",
        "Cheddar-Chromatic", "Espressolydian", "Lasagnian Minor",
        "Mid-Life-Crisis-Major", "Passive-Aggressive-Pentatonic",
        "Existential-Dread-Diminished", "3:00 AM Ionian",
        "Pre-Coffee Harmonic Minor", "Synthesized Regret Major",
        "Quantum-Superposition-C",
        // Originals
        "Vaguely Phrygian", "Accidentally Octatonic", "Ionian (With Mistakes)",
        "Dorian Mode (The Sad One)", "Wonky Bebop Diminished",
        "Ukrainian Dorian (Misremembered)", "Reverse-Dorian Approximately",
        "Debatably Pentatonic", "Post-Lydian (Flat 7)",
        "Hypo-Mixolydian-Adjacent", "Sub-Lydian (Nearly)",
        "B-Flat Existential", "Augmented Disappointment",
        "Double-Harmonic-ish", "Byzantine (Probably)",
        "Chromatic but Make It Sad", "Slightly Sharp Ionian",
        "Diminished Self-Esteem Scale", "Whole Tone (Half Remembered)",
        "Octatonic (Missing One Note)", "Altered (Barely)"
    ]

    // Fake musical terms — corruptions of Italian/Spanish performance directions
    // that sound plausible until you think about them
    private static let fakeMusicalTerms = [
        // User's examples (selected good ones)
        "Slipsando", "Derpeggio", "Stuckinato", "Lazygato",
        "Jitterato", "Screamscendo", "Fumblando", "Blunderando",
        "Burpeggio", "Hiccupato", "Panicatto", "Oopsando",
        "Snorato", "Mumblando", "Grumblato", "Spillando",
        // Originals
        "Forgettissimo", "Vaguissimo", "Dozecrescendo", "Shufflando",
        "Driftissimo", "Hesitando", "Wanderissimo", "Procrasticando",
        "Meanderato", "Tepidissimo", "Shruggendo", "Spiralando",
        "Distresscendo", "Noodleando", "Lurchicato", "Collapsicato",
        "Flumblicato", "Befuddlicato", "Teetrando", "Squirmicato",
        "Evaporando", "Dissolvicato", "Dithericato", "Splutterando",
        "Wheezicato", "Mutterlando", "Frownissimo", "Blankissimo"
    ]

    // MARK: - Patterns
    // Pattern appears multiple times in the array to weight it higher.

    typealias PatternFn = @Sendable (inout SeededRNG) -> String

    private static let patterns: [PatternFn] = [

        // 1a. Music for [mundane place]  (weight ×3)
        { rng in
            let fn = functionWords[rng.nextInt(upperBound: functionWords.count)]
            let pl = mundanePlaces[rng.nextInt(upperBound: mundanePlaces.count)]
            return "\(fn) for \(pl)"
        },
        { rng in
            let fn = functionWords[rng.nextInt(upperBound: functionWords.count)]
            let pl = mundanePlaces[rng.nextInt(upperBound: mundanePlaces.count)]
            return "\(fn) for \(pl)"
        },
        { rng in
            let fn = functionWords[rng.nextInt(upperBound: functionWords.count)]
            let pl = mundanePlaces[rng.nextInt(upperBound: mundanePlaces.count)]
            return "\(fn) for \(pl)"
        },

        // 2. An Ending ([parenthetical])  (weight ×2)
        { rng in
            let p = endingParentheticals[rng.nextInt(upperBound: endingParentheticals.count)]
            return "An Ending (\(p))"
        },
        { rng in
            let p = endingParentheticals[rng.nextInt(upperBound: endingParentheticals.count)]
            return "An Ending (\(p))"
        },

        // 3. Weather + UK drab geography  (weight ×3)
        { rng in
            let w  = weatherConditions[rng.nextInt(upperBound: weatherConditions.count)]
            let pr = weatherPrepositions[rng.nextInt(upperBound: weatherPrepositions.count)]
            let l  = drabLocations[rng.nextInt(upperBound: drabLocations.count)]
            return "\(w) \(pr) \(l)"
        },
        { rng in
            let w  = weatherConditions[rng.nextInt(upperBound: weatherConditions.count)]
            let pr = weatherPrepositions[rng.nextInt(upperBound: weatherPrepositions.count)]
            let l  = drabLocations[rng.nextInt(upperBound: drabLocations.count)]
            return "\(w) \(pr) \(l)"
        },
        { rng in
            let w  = weatherConditions[rng.nextInt(upperBound: weatherConditions.count)]
            let pr = weatherPrepositions[rng.nextInt(upperBound: weatherPrepositions.count)]
            let l  = drabLocations[rng.nextInt(upperBound: drabLocations.count)]
            return "\(w) \(pr) \(l)"
        },

        // 4. The [abstraction] of [tepid subject]  (weight ×2)
        { rng in
            let a = abstractNouns[rng.nextInt(upperBound: abstractNouns.count)]
            let t = tepidSubjects[rng.nextInt(upperBound: tepidSubjects.count)]
            return "\(a) of \(t)"
        },
        { rng in
            let a = abstractNouns[rng.nextInt(upperBound: abstractNouns.count)]
            let t = tepidSubjects[rng.nextInt(upperBound: tepidSubjects.count)]
            return "\(a) of \(t)"
        },

        // 5. [Technical adj] [noun] for/in [mundane activity]  (weight ×3)
        { rng in
            let adj  = technicalAdjectives[rng.nextInt(upperBound: technicalAdjectives.count)]
            let noun = technicalNouns[rng.nextInt(upperBound: technicalNouns.count)]
            let act  = mundaneActivities[rng.nextInt(upperBound: mundaneActivities.count)]
            let prep = rng.nextInt(upperBound: 2) == 0 ? "for" : "in"
            return "\(adj) \(noun) \(prep) \(act)"
        },
        { rng in
            let adj  = technicalAdjectives[rng.nextInt(upperBound: technicalAdjectives.count)]
            let noun = technicalNouns[rng.nextInt(upperBound: technicalNouns.count)]
            let act  = mundaneActivities[rng.nextInt(upperBound: mundaneActivities.count)]
            let prep = rng.nextInt(upperBound: 2) == 0 ? "for" : "in"
            return "\(adj) \(noun) \(prep) \(act)"
        },
        { rng in
            let adj  = technicalAdjectives[rng.nextInt(upperBound: technicalAdjectives.count)]
            let noun = technicalNouns[rng.nextInt(upperBound: technicalNouns.count)]
            let act  = mundaneActivities[rng.nextInt(upperBound: mundaneActivities.count)]
            let prep = rng.nextInt(upperBound: 2) == 0 ? "for" : "in"
            return "\(adj) \(noun) \(prep) \(act)"
        },

        // 6. [Day]'s [mundane event]  (weight ×2)
        { rng in
            let d = weekdays[rng.nextInt(upperBound: weekdays.count)]
            let e = mundaneEvents[rng.nextInt(upperBound: mundaneEvents.count)]
            let fmt = rng.nextInt(upperBound: 3)
            switch fmt {
            case 0:  return "\(d)'s \(e)"
            case 1:  return "\(d) \(e)"
            default: return "\(d), \(e)"
            }
        },
        { rng in
            let d = weekdays[rng.nextInt(upperBound: weekdays.count)]
            let e = mundaneEvents[rng.nextInt(upperBound: mundaneEvents.count)]
            let fmt = rng.nextInt(upperBound: 3)
            switch fmt {
            case 0:  return "\(d)'s \(e)"
            case 1:  return "\(d) \(e)"
            default: return "\(d), \(e)"
            }
        },

        // 7. A [pretentious adj] [banal sound/noun]  (weight ×2)
        { rng in
            let adj  = pretentiousAdjectives[rng.nextInt(upperBound: pretentiousAdjectives.count)]
            let noun = mundaneSounds[rng.nextInt(upperBound: mundaneSounds.count)]
            return "A \(adj) \(noun)"
        },
        { rng in
            let adj  = pretentiousAdjectives[rng.nextInt(upperBound: pretentiousAdjectives.count)]
            let noun = mundaneSounds[rng.nextInt(upperBound: mundaneSounds.count)]
            return "A \(adj) \(noun)"
        },

        // 8. Ambient N: [subtitle]  (weight ×1)
        { rng in
            let n  = rng.nextInt(upperBound: 7) + 1
            let st = ambientSubtitles[rng.nextInt(upperBound: ambientSubtitles.count)]
            return "Ambient \(n): \(st)"
        },

        // 9. Through/In/Near [drab setting]  (weight ×2)
        { rng in
            let preps = ["Through", "In", "Above", "Beyond", "Near", "Outside", "Beside"]
            let prep  = preps[rng.nextInt(upperBound: preps.count)]
            let s     = drabSettings[rng.nextInt(upperBound: drabSettings.count)]
            return "\(prep) \(s)"
        },
        { rng in
            let preps = ["Through", "In", "Above", "Beyond", "Near", "Outside", "Beside"]
            let prep  = preps[rng.nextInt(upperBound: preps.count)]
            let s     = drabSettings[rng.nextInt(upperBound: drabSettings.count)]
            return "\(prep) \(s)"
        },

        // 10. Fake French / faux-European  (weight ×1)
        { rng in
            let fr = frenchWords[rng.nextInt(upperBound: frenchWords.count)]
            let tg = frenchTargets[rng.nextInt(upperBound: frenchTargets.count)]
            return "\(fr) \(tg)"
        },

        // 11. Loscil-style neologism  (weight ×1)
        { rng in neologisms[rng.nextInt(upperBound: neologisms.count)] },

        // 12. Light + mundane surface  (weight ×1)
        { rng in
            let lc = lightConditions[rng.nextInt(upperBound: lightConditions.count)]
            let ms = mundaneSurfaces[rng.nextInt(upperBound: mundaneSurfaces.count)]
            return "\(lc) \(ms)"
        },

        // 13. Philosophical opening + deflating event  (weight ×1)
        { rng in
            let op = philosophicalOpeners[rng.nextInt(upperBound: philosophicalOpeners.count)]
            let ev = philosophicalEvents[rng.nextInt(upperBound: philosophicalEvents.count)]
            return "\(op) \(ev)"
        },

        // 14a. Craven Faults — terse geological single word (±roman numeral)  (weight ×2)
        { rng in
            let term = cravenFaultsTerms[rng.nextInt(upperBound: cravenFaultsTerms.count)]
            if rng.nextInt(upperBound: 3) == 0 {
                let numerals = ["II", "III", "IV", "V", "VI"]
                return "\(term) \(numerals[rng.nextInt(upperBound: numerals.count)])"
            }
            return term
        },
        { rng in
            let term = cravenFaultsTerms[rng.nextInt(upperBound: cravenFaultsTerms.count)]
            if rng.nextInt(upperBound: 3) == 0 {
                let numerals = ["II", "III", "IV", "V", "VI"]
                return "\(term) \(numerals[rng.nextInt(upperBound: numerals.count)])"
            }
            return term
        },

        // 14b. Craven Faults "X & Y" compound  (weight ×1)
        { rng in
            let geo   = cravenFaultsTerms[rng.nextInt(upperBound: cravenFaultsTerms.count)]
            let admin = cravenAdminNouns[rng.nextInt(upperBound: cravenAdminNouns.count)]
            return "\(geo) & \(admin)"
        },

        // 15. JMJ concept + mundane deflator  (weight ×2)
        { rng in
            let concept  = jmjConcepts[rng.nextInt(upperBound: jmjConcepts.count)]
            let deflator = jmjDeflators[rng.nextInt(upperBound: jmjDeflators.count)]
            return "\(concept) \(deflator)"
        },
        { rng in
            let concept  = jmjConcepts[rng.nextInt(upperBound: jmjConcepts.count)]
            let deflator = jmjDeflators[rng.nextInt(upperBound: jmjDeflators.count)]
            return "\(concept) \(deflator)"
        },

        // 16. Fake scale name + fake musical term  (weight ×2)
        { rng in
            let scale = fakeScaleNames[rng.nextInt(upperBound: fakeScaleNames.count)]
            let term  = fakeMusicalTerms[rng.nextInt(upperBound: fakeMusicalTerms.count)]
            return "\(scale) \(term)"
        },
        { rng in
            let scale = fakeScaleNames[rng.nextInt(upperBound: fakeScaleNames.count)]
            let term  = fakeMusicalTerms[rng.nextInt(upperBound: fakeMusicalTerms.count)]
            return "\(scale) \(term)"
        },
    ]
}
