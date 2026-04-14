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
        "an Inadequate Conference Room", "the Queue at Boots",
        "Browsing IKEA on a Sunday", "a Cancelled Train",
        "the Tyre Centre Queue",
        "the Bus that Was Full", "Supermarket Self-Checkout",
        "an Uneventful Tuesday", "a Slightly Too Long Meeting",
        "the Unused Changing Room", "a Business Park in January",
        "the Post-Lunch Deadzone",
        "the NCP Car Park at Dusk", "a Mildly Warm Office",
        "a Regional Distribution Centre", "the Holdmusic",
        "a Slowly Loading Web Page", "an Unattended Printer",
        "the Outside of a Petrol Station", "Reconsidering Life Choices",
        "Returning Without Receipt"
    ]

    private static let endingParentheticals = [
        "That Never Ends", "Possibly", "Eventually",
        "In Which Nothing Happens", "Awaiting Confirmation",
        "TBC", "Already Happened", "Subject to Availability",
        "Pending", "More or Less", "See Previous Notes",
        "Under Review", "Not Really", "Gradually, Then All at Once",
        "To Be Rescheduled", "Which Was Really the Middle",
        "Descending Slowly", "In Which the Tape Runs Out",
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
        "the Industrial Estate", "the Business Park", "a Roundabout", "Bristol",
        "the Lower Car Park", "a Disused Underpass", "Basingstoke", "Guilford",
        "the Ring Road", "a Disused Gravel Pit", "the Trading Estate",
        "Hemel Hempstead", "the NCP Car Park", "a Suburban Cul-de-Sac",
        "the Service Station", "the B2047", "the Overflow Car Park",
        "an Industrial Unit", "the Dual Carriageway",
        "the Goods Entrance", "a Medium-Sized Retail Park"
    ]

    private static let abstractNouns = [
        "The Memory", "The Properties", "The Persistence",
        "The Thermodynamics", "The Geometry",
        "The Topology", "The Absence", "The Curvature",
        "The Structural Integrity", "The Gradual Decay",
        "The Fading Echo", "The Quiet Insistence",
        "The Phenomenology", "The Specific Gravity",
        "The Bearing Capacity", "The Half-Life"
    ]

    private static let tepidSubjects = [
        "a Beige Wall", "Tepid Tea", "the Waiting Room",
        "a Slightly Damp Coat", "Mildly Warm Coffee",
        "an Unread Email", "a Forgotten Password", "the Under-Secretary",
        "a Partially Eaten Sandwich", "the Suspended Ceiling","WOOC(P)",
        "a Persistent Hum", "a Lukewarm Radiator",
        "the Beige Carpet", "a Receding Hairline",
        "an Unanswered Voicemail", "the Fire Exit", "a Bad Investment", "the Reign of Zorvaak",
        "a Nearly Empty Stapler", "Mild Disappointment", "the Forrest Connection"
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
        "Error Rates", "Gradient Descent", "Signal Loss", "Connection"
    ]

    private static let mundaneActivities = [
        "a Slow Elevator", "the Monday Commute",
        "a Career Rethink", "an Uneventful Tuesday",
        "an Administrative Error", "an Unscheduled Meeting",
        "Forms in Triplicate", "a Lukewarm Room",
        "the Lower Suburbs", "a Slight Change of Plans",
        "a Poorly Attended Meeting", "a Delayed Reply",
        "an Uneventful Friday", "an Expired Parking Permit",
        "a Very Slow Download", "a Mildly Odd Error Message"
    ]

    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Sunday"]

    private static let mundaneEvents = [
        "Afternoon", "Lunch", "Morning", "Evening",
        "the 3pm Meeting", "a Routine Dental Checkup",
        "a Mild Disagreement", "a Brief Drizzle", "Persistent Drizzle",
        "a Slight Delay", "a Tepid Coffee", "a Cancelled Meeting",
        "Nothing in Particular", "the Usual", "a Light Lunch",
        "a Slightly Long Queue", "an Awkward Silence",
        "a Missed Connection", "a Gentle Inconvenience"
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
        "The Sound of a Building", "Printer Noise",
        "A Fluorescent Flickering", "A Tap Dripping",
        "The Noise the Boiler Makes"
    ]

    private static let ambientSubtitles = [
        "Music for Spreadsheets", "Day of Moderate Rain",
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
        "a Venetian Blind", "a Fire Door (Ajar)",
        "the Window of a Conference Room",
        "a Revolving Door That Is Stuck"
    ]

    private static let frenchWords   = ["Deuxieme", "Troisieme", "Quatrieme", "Fragment", "Suite", "Reprise"]
    private static let frenchTargets = [
        "Part Deux", "Pensees", "Pour le Car Park", "Numero Trois",
        "Pour la Salle d'Attente", "Studies", "Encore Un Fois (Reluctant)",
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

    // JMJ-style French concept words (parody of Oxygene, Equinoxe, etc.)
    private static let jmjConcepts = [
        "Oxygene", "Equinoxe", "Magnetique", "Kronologie", "Electrique",
        "Metamorphoses", "Electronique", "Atmosphere", "Crezendo",
        "Cozmique", "Solstice", "Meridien", "Lumineux", "Zorvaak",
        "Telephonie", "Zenith", "Isotrope", "Maladoxe", "Zut alors"
    ]

    // JMJ mundane deflating suffixes
    private static let jmjDeflators = [
        "Part 47", "Part 23 (Revised)", "For One Person",
        "In a Slightly Stuffy Office", "Without the Good Synthesizer",
        "Pt. II (The Sad One)", "En Route to the Car Park",
        "Suite for Overhead Projector", "Live from Basildon",
        "The Director's Cut (Too Long)", "Pour le Ring Road",
        "Version 3 (Almost Final)", "Performed on a Broken Keyboard",
        "With Reduced Funding", "For an Empty Arena"
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
        "Mistform", "Pallor", "Residua", "Zorvaak"
    ]

    private static let lightConditions = [
        "Light Reflected", "Grey Light Falling", "Refracted Light",
        "Diffuse Light Pooling", "Pale Light Flickering",
        "Light Scattering Across", "Pale Light Resting On",
        "Failing Light"
    ]

    private static let mundaneSurfaces = [
        "a Puddle of Oil", "the Car Park Tarmac", "a Polished Floor",
        "the Office Partition", "a Cheap Laminate Surface",
        "a Fogged Mirror", "the Beige Ceiling Tiles",
        "an Off-White Wall", "a Lukewarm Cup of Tea",
        "the Back of a Bus Seat", "a Fire Door",
        "Damp Pavement"
    ]

    private static let philosophicalOpeners = [
        "A Meaningful", "An Important", "A Significant", "A Decisive",
        "A Transformative", "A Pivotal", "A Nuanced"
    ]

    private static let philosophicalEvents = [
        "Meeting About Quarterly Targets", "Moment in a Pointless Process",
        "the Car Park Discussion", "Pause Before Next Slide",
        "Reflection on the Cake Selection", "Contribution to the Team Day",
        "Response to the Previous Email", "Consideration of the New Policy",
        "Situation Acknowledgement", "Ongoing Situation Review"
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
        "Ukrainian Dorian (Misremembered)", "Reverse-Dorian Approx.",
        "Debatably Pentatonic", "Post-Lydian (Flat 7)",
        "Hypo-Mixolydian-Adjacent", "Sub-Lydian (Nearly)",
        "B-Flat Existential", "Augmented Disappointment",
        "Double-Harmonic-ish", "Byzantine (Probably)",
        "Chromatic but Sad", "Slightly Sharp Ionian",
        "Dim. Self-Esteem Scale", "Whole Tone (Half Remembered)",
        "Octatonic (Missing One Note)", "Altered (Barely)"
    ]

    // Classical music forms — used in tech-grief pattern
    private static let classicalForms = [
        "Suite", "Nocturne", "Requiem", "Étude", "Notes",
        "Elegy", "Lament", "Prelude", "Dirge", "Threnody",
        "Interlude", "Fugue", "Variations", "Aria", "Coda"
    ]

    // Tech/SaaS/midlife tragedies — "for/from a ___"
    private static let techTragedies = [
        "SaaS Funeral", "Failed Pivot", "Midlife Crisis",
        "Forced Restructuring", "Dying Startup",
        "Redundancy Notice", "Failed MVP",
        "Abandoned Roadmap", "Post-Acquisition Reorg",
        "Series C That Didn't Close", "Pivot That Wasn't",
        "Missed Runway", "Down Round", "Strategic Reset",
        "Quiet Layoff", "Vision Misalignment"
    ]

    // People who are suffering — "Tears/Lament of a ___"
    private static let techVictims = [
        "SaaS Investor", "Product Manager",
        "Burned-Out Founder", "Pivoting CEO",
        "Bootstrapped Developer", "Laid-Off Engineer",
        "Venture Partner (Ret.)", "Thought Leader",
        "Pre-Revenue Startup", "Disruptive Innovator",
        "Chief AI Officer",
        "First-Time Angel Investor",
        "Head of Growth (Redundant)",
        "Technical Co-Founder (Diluted)", 
        "Series A Optimist"
    ]

    // Tech grief emotions — "Tears/Lament/Requiem of ___"
    private static let techGriefNouns = [
        "Tears", "Regrets", "Lament", "Dirge",
        "Elegy", "Eulogy", "Last Words", "Notes"
    ]

    // AI entities — for "The ___ Arrangements" style
    private static let aiEntities = [
        "Claude", "ChatGPT", "Copilot", "Gemini",
        "LLM", "Foundation Model", "Transformer",
        "Inference Engine", "GPT", "Prompt", "Buddha"
    ]

    // Words that follow an AI entity name
    private static let aiArrangementWords = [
        "Arrangements", "Sessions", "Variations", "Studies",
        "Meditations", "Transcriptions", "Improvisations",
        "Sketches", "Compositions", "Directives"
    ]

    // AI-specific tragedies and concepts
    private static let aiTragedies = [
        "a Failed AI Pivot", "a Hallucinated Roadmap",
        "a Deprecated Model", "an Orphaned Prompt",
        "a Token Limit", "the Context Window",
        "Fine-Tuned Anger", "a Vibe-Coded Startup",
        "the Alignment Problem", "an AI Wrapper",
        "a Feature That Never Shipped",
        "Prompt Engineering", "a Missed Inference",
        "a Confident Wrong Answer", "Latency"
    ]

    // Places where tech grief occurs
    private static let techPlaces = [
        "Silicon Valley", "Palo Alto", "San Francisco",
        "Shoreditch", "a WeWork", "a Hot-Desk",
        "a Pitch Deck", "a Pre-Seed Round",
        "the Catered Office", "the Off-Site",
        "an Unconference", "the Open Plan",
        "a Standing Meeting", "the All-Hands"
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

        // 17. Tech/SaaS grief — three sub-formats  (weight ×3)

        // 17a. [Classical form] for/from [tech tragedy] — "Suite for a SaaS Funeral"
        { rng in
            let form   = classicalForms[rng.nextInt(upperBound: classicalForms.count)]
            let trag   = techTragedies[rng.nextInt(upperBound: techTragedies.count)]
            let prep   = rng.nextInt(upperBound: 3) == 0 ? "from" : "for"
            return "\(form) for \(prep == "for" ? "a" : "the") \(trag)"
        },

        // 17b. [Emotion] of a [tech victim] — "Tears of a SaaS Investor"
        { rng in
            let grief  = techGriefNouns[rng.nextInt(upperBound: techGriefNouns.count)]
            let victim = techVictims[rng.nextInt(upperBound: techVictims.count)]
            return "\(grief) of a \(victim)"
        },

        // 17c. [Event] in [tech place] — "Funeral in Silicon Valley"
        { rng in
            let events = ["Funeral", "Wake", "Merger", "Pivot", "Reorg", "Acqui-hire",
                          "Liquidation Event", "Soft Landing", "Strategic Reset"]
            let event  = events[rng.nextInt(upperBound: events.count)]
            let place  = techPlaces[rng.nextInt(upperBound: techPlaces.count)]
            return "\(event) in \(place)"
        },

        // 17d. "The [AI entity] [arrangement word]" — "The Claude Arrangements"  (weight ×2)
        { rng in
            let entity = aiEntities[rng.nextInt(upperBound: aiEntities.count)]
            let word   = aiArrangementWords[rng.nextInt(upperBound: aiArrangementWords.count)]
            return "The \(entity) \(word)"
        },
        { rng in
            let entity = aiEntities[rng.nextInt(upperBound: aiEntities.count)]
            let word   = aiArrangementWords[rng.nextInt(upperBound: aiArrangementWords.count)]
            return "The \(entity) \(word)"
        },

        // 17e. "[Classical form] for [AI entity or tragedy]"  (weight ×2)
        // — "Arias for ChatGPT", "Sonata for a Failed AI Pivot"
        { rng in
            let form = classicalForms[rng.nextInt(upperBound: classicalForms.count)]
            if rng.nextInt(upperBound: 2) == 0 {
                let entity = aiEntities[rng.nextInt(upperBound: aiEntities.count)]
                return "\(form) for \(entity)"
            } else {
                let trag = aiTragedies[rng.nextInt(upperBound: aiTragedies.count)]
                return "\(form) for \(trag)"
            }
        },
        { rng in
            let form = classicalForms[rng.nextInt(upperBound: classicalForms.count)]
            if rng.nextInt(upperBound: 2) == 0 {
                let entity = aiEntities[rng.nextInt(upperBound: aiEntities.count)]
                return "\(form) for \(entity)"
            } else {
                let trag = aiTragedies[rng.nextInt(upperBound: aiTragedies.count)]
                return "\(form) for \(trag)"
            }
        },
    ]
}
