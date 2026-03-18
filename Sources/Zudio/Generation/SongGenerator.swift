// SongGenerator.swift — top-level 10-step generation pipeline
// All steps must complete in order. Outputs a fully populated SongState.

import Foundation

struct SongGenerator {
    // MARK: - Public entry points

    /// Full generation from scratch. Key/tempo overrides from UI selectors (nil = random).
    static func generate(
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil
    ) -> SongState {
        let globalSeed = UInt64.random(in: .min ... .max)
        return generate(seed: globalSeed, keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride)
    }

    /// Deterministic generation from an explicit seed (for reproducible test runs).
    static func generate(
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil
    ) -> SongState {
        var rng = SeededRNG(seed: seed)

        // Step 1 — Global musical frame
        let frame = MusicalFrameGenerator.generate(
            rng: &rng,
            keyOverride: keyOverride,
            tempoOverride: tempoOverride,
            moodOverride: moodOverride
        )

        // Step 2 — Song structure + chord plan
        let structure = StructureGenerator.generate(frame: frame, rng: &rng)

        // Step 3 — Tonal governance map
        let tonalMap = TonalGovernanceBuilder.build(frame: frame, structure: structure)

        // Steps 4–9 — Per-track MIDI event generation
        var trackEvents = [[MIDIEvent]](repeating: [], count: 7)

        // Each track gets its own deterministically-derived RNG
        var drumRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackDrums))
        var bassRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackBass))
        var padsRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackPads))
        var lead1RNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead1))
        var lead2RNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead2))
        var rhythmRNG = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackRhythm))
        var texRNG    = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackTexture))

        // Step 4 — Drums
        var drumRules: Set<String> = []
        trackEvents[kTrackDrums]   = DrumGenerator.generate(frame: frame, structure: structure, rng: &drumRNG, usedRuleIDs: &drumRules)

        // Step 5 — Bass
        var bassRules: Set<String> = []
        trackEvents[kTrackBass]    = BassGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &bassRNG, usedRuleIDs: &bassRules)

        // Step 6 — Pads
        var padRules: Set<String> = []
        trackEvents[kTrackPads]    = PadsGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &padsRNG, usedRuleIDs: &padRules)

        // Step 7 — Leads
        var lead1Rules: Set<String> = []
        var lead2Rules: Set<String> = []
        trackEvents[kTrackLead1]   = LeadGenerator.generateLead1(frame: frame, structure: structure, tonalMap: tonalMap, rng: &lead1RNG, usedRuleIDs: &lead1Rules)
        trackEvents[kTrackLead2]   = LeadGenerator.generateLead2(frame: frame, structure: structure, tonalMap: tonalMap, lead1Events: trackEvents[kTrackLead1], rng: &lead2RNG, usedRuleIDs: &lead2Rules)

        // Step 8 — Rhythm
        var rhythmRules: Set<String> = []
        trackEvents[kTrackRhythm]  = RhythmGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rhythmRNG, usedRuleIDs: &rhythmRules)

        // Step 9 — Texture
        trackEvents[kTrackTexture] = TextureGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &texRNG)

        // Step 10 — Collision / density simplification pass
        trackEvents = DensitySimplifier.simplify(trackEvents: trackEvents, frame: frame, structure: structure)

        // Title generation
        let title = TitleGenerator.generate(frame: frame, rng: &rng)

        // Song form
        let form: SongForm = {
            if structure.bodySections.count >= 3 { return .moderateAB }
            if structure.bodySections.map({ $0.label }).contains(.B) { return .subtleAB }
            return .singleA
        }()

        // Build generation log
        let log = buildLog(
            title: title, frame: frame, structure: structure, form: form,
            drumRules: drumRules, bassRules: bassRules,
            padRules: padRules, lead1Rules: lead1Rules, lead2Rules: lead2Rules,
            rhythmRules: rhythmRules
        )

        return SongState(
            frame: frame,
            structure: structure,
            tonalMap: tonalMap,
            trackEvents: trackEvents,
            globalSeed: seed,
            trackOverrides: [:],
            title: title,
            form: form,
            generationLog: log
        )
    }

    // MARK: - Per-track regenerate

    /// Regenerates a single track without touching any other track or the global seed.
    /// The generation log is carried through unchanged (reflects the full generation).
    static func regenerateTrack(_ trackIndex: Int, songState: SongState) -> SongState {
        let newTrackSeed = UInt64.random(in: .min ... .max)
        var rng = SeededRNG(seed: newTrackSeed)
        var discardedRules: Set<String> = []

        let events: [MIDIEvent]
        switch trackIndex {
        case kTrackDrums:
            events = DrumGenerator.generate(frame: songState.frame, structure: songState.structure, rng: &rng, usedRuleIDs: &discardedRules)
        case kTrackBass:
            events = BassGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &discardedRules)
        case kTrackPads:
            events = PadsGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &discardedRules)
        case kTrackLead1:
            events = LeadGenerator.generateLead1(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &discardedRules)
        case kTrackLead2:
            events = LeadGenerator.generateLead2(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, lead1Events: songState.trackEvents[kTrackLead1], rng: &rng, usedRuleIDs: &discardedRules)
        case kTrackRhythm:
            events = RhythmGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &discardedRules)
        case kTrackTexture:
            events = TextureGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng)
        default:
            return songState
        }

        var updated = songState.replacingEvents(events, forTrack: trackIndex)
        updated.trackOverrides[trackIndex] = newTrackSeed
        return updated
    }

    // MARK: - Generation log builder

    private static func buildLog(
        title: String,
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        form: SongForm,
        drumRules: Set<String>,
        bassRules: Set<String>,
        padRules: Set<String>,
        lead1Rules: Set<String>,
        lead2Rules: Set<String>,
        rhythmRules: Set<String>
    ) -> [GenerationLogEntry] {
        var log: [GenerationLogEntry] = []

        // Song title
        log.append(GenerationLogEntry(tag: "SONG", description: title, isTitle: true))

        // Structure form rule
        let formRuleID = structureRuleID(form: form, structure: structure)
        let formDesc   = buildFormDescription(form: form, structure: structure)
        log.append(GenerationLogEntry(tag: formRuleID, description: formDesc))

        // Intro rule — immediately after form
        if let intro = structure.introSection {
            let ruleID = intro.lengthBars <= 8 ? "INT-001" : "INT-002"
            log.append(GenerationLogEntry(tag: ruleID,
                description: "Intro: \(intro.lengthBars) bars, drums-only entry → sparse from bar 2"))
        }

        // Outro rule — immediately after intro
        if let outro = structure.outroSection {
            let ruleID = outro.lengthBars <= 8 ? "OUT-001" : "OUT-002"
            log.append(GenerationLogEntry(tag: ruleID,
                description: "Outro: \(outro.lengthBars) bars, sparse/low-intensity drop"))
        }

        // Chord progression — single combined line
        let chordNames = structure.chordPlan
            .map { chordName(key: frame.key, degree: $0.chordRoot, type: $0.chordType) }
            .removingAdjacentDuplicates()
            .joined(separator: ", ")
        let progLabel = progressionFamilyLabel(frame.progressionFamily)
        let chordDesc = chordNames.isEmpty ? progLabel : "\(progLabel)  (\(chordNames))"
        log.append(GenerationLogEntry(tag: "Chords", description: chordDesc))

        // Global frame
        log.append(GenerationLogEntry(tag: "GBL-001",
            description: "\(frame.key) \(frame.mode.rawValue), \(frame.tempo) BPM, \(frame.progressionFamily.rawValue)"))

        // Drums
        for ruleID in drumRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: drumRuleDescription(ruleID)))
        }
        if drumRules.isEmpty {
            log.append(GenerationLogEntry(tag: "DRM-001", description: drumRuleDescription("DRM-001")))
        }

        // Bass
        for ruleID in bassRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: bassRuleDescription(ruleID)))
        }
        if bassRules.isEmpty {
            log.append(GenerationLogEntry(tag: "BAS-001", description: bassRuleDescription("BAS-001")))
        }

        // Pads — may be multiple rules
        let sortedPadRules = padRules.sorted()
        for ruleID in sortedPadRules {
            log.append(GenerationLogEntry(tag: ruleID, description: padRuleDescription(ruleID)))
        }
        if sortedPadRules.isEmpty {
            log.append(GenerationLogEntry(tag: "PAD-001",
                description: padRuleDescription("PAD-001")))
        }

        // Lead 1
        for ruleID in lead1Rules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: lead1RuleDescription(ruleID)))
        }
        if lead1Rules.isEmpty {
            log.append(GenerationLogEntry(tag: "LD1-001", description: lead1RuleDescription("LD1-001")))
        }

        // Lead 2
        for ruleID in lead2Rules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: lead2RuleDescription(ruleID)))
        }
        if lead2Rules.isEmpty {
            log.append(GenerationLogEntry(tag: "LD2-001", description: lead2RuleDescription("LD2-001")))
        }

        // Rhythm — may be multiple rules
        let sortedRhythmRules = rhythmRules.sorted()
        for ruleID in sortedRhythmRules {
            log.append(GenerationLogEntry(tag: ruleID, description: rhythmRuleDescription(ruleID)))
        }
        if sortedRhythmRules.isEmpty {
            log.append(GenerationLogEntry(tag: "RHY-001",
                description: "8th-note ostinato, alternating root/fifth"))
        }

        // Texture — single rule in v1
        log.append(GenerationLogEntry(tag: "TEX-001",
            description: "Boundary-weighted sparse atmosphere, scale tensions"))

        return log
    }

    // MARK: - Log helpers

    private static func structureRuleID(form: SongForm, structure: SongStructure) -> String {
        let hasReprise = structure.bodySections.filter { $0.label == .A }.count >= 2
        switch form {
        case .singleA:    return "STR-001"
        case .subtleAB:   return "STR-002"
        case .moderateAB: return hasReprise ? "STR-004" : "STR-003"
        }
    }

    private static func buildFormDescription(form: SongForm, structure: SongStructure) -> String {
        var parts: [String] = [formLabel(form)]
        if let intro = structure.introSection {
            parts.append("intro: \(intro.lengthBars) bars")
        }
        for section in structure.bodySections {
            parts.append("\(section.label.rawValue) section: \(section.lengthBars) bars")
        }
        if let outro = structure.outroSection {
            parts.append("outro: \(outro.lengthBars) bars")
        }
        return parts.joined(separator: ", ")
    }

    private static func formLabel(_ form: SongForm) -> String {
        switch form {
        case .singleA:    return "Single-A"
        case .subtleAB:   return "Subtle A/B"
        case .moderateAB: return "Moderate A/B"
        }
    }

    /// Converts key + degree + chord type to a proper chord name (e.g. "Em", "Gmaj7", "Asus2").
    static func chordName(key: String, degree: String, type: ChordType) -> String {
        let pc = (keySemitone(key) + degreeSemitone(degree)) % 12
        let flatKeys: Set<String> = ["F", "Bb", "Eb", "Ab", "Db", "Gb"]
        let names = flatKeys.contains(key)
            ? ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
            : ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let root = names[pc]
        return root + chordTypeSuffix(type)
    }

    private static func chordTypeSuffix(_ t: ChordType) -> String {
        switch t {
        case .major:   return ""
        case .minor:   return "m"
        case .sus2:    return "sus2"
        case .sus4:    return "sus4"
        case .dom7:    return "7"
        case .min7:    return "m7"
        case .add9:    return "add9"
        case .quartal: return "qrt"
        case .power:   return "5"
        }
    }

    private static func progressionFamilyLabel(_ family: ProgressionFamily) -> String {
        switch family {
        case .static_tonic:             return "Static tonic: I"
        case .two_chord_I_bVII:         return "Two chord: I — ♭VII"
        case .minor_loop_i_VII:         return "Minor loop: i — VII"
        case .minor_loop_i_VI:          return "Minor loop: i — VI"
        case .modal_cadence_bVI_bVII_I: return "Modal rock: ♭VI — ♭VII — I"
        }
    }

    private static func drumRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "DRM-001": return "4-on-the-floor kick, closed-hat 16ths, snare beat 3"
        case "DRM-002": return "Open pocket — closed-hat 8ths, open hat beat 1, ghost snares"
        case "DRM-003": return "Ride groove — ride 8ths, snare beat 3, pedal hi-hat beats 2+4"
        default:        return ruleID
        }
    }

    private static func bassRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "BAS-001": return "Root anchor beat 1, chord tones beat 3, syncopation"
        case "BAS-002": return "Motorik Drive — steady quarter-note root pulse, staccato"
        case "BAS-003": return "Crawling Walk — 2-bar root/fifth/approach note pattern"
        default:        return ruleID
        }
    }

    private static func lead1RuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "LD1-001": return "Motif-first, chord tones 80%, scale tensions 20%"
        case "LD1-002": return "Pentatonic Cell — short driving notes from pentatonic scale"
        case "LD1-003": return "Long Breath — sparse, sustained notes with rests"
        default:        return ruleID
        }
    }

    private static func lead2RuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "LD2-001": return "Counter-response, density ≤55% of Lead 1"
        case "LD2-002": return "Sustained Drone — sparse long holds on root or 5th"
        case "LD2-003": return "Rhythmic Counter — short bursts offset from Lead 1"
        default:        return ruleID
        }
    }

    private static func padRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "PAD-001": return "Sustained whole-bar (auto-breaks to Charleston after 4 bars)"
        case "PAD-002": return "Power/drone voicing (root, fifth, octave), 4-bar break rule"
        case "PAD-003": return "Pulsed — one attack every 2 bars with overlap"
        case "PAD-004": return "Sparse intro/outro (50% skip probability)"
        case "PAD-005": return "Arpeggio — 8th notes cycling through chord tones (up/down/bounce)"
        case "PAD-006": return "Stabs — short chord attacks on beat 1, sometimes beat 3"
        case "PAD-007": return "Charleston (3+3+2) — dotted-quarter rhythm from Silly Love Songs"
        case "PAD-008": return "16th-note chop — dense staccato from Hallogallo guitar"
        default:        return ruleID
        }
    }

    private static func rhythmRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "RHY-001": return "8th-note ostinato, alternating root/fifth per chord"
        case "RHY-002": return "Quarter-note ostinato, root-anchored"
        case "RHY-003": return "Syncopated Motorik (3+3+2 feel), root/fifth alternation"
        default:        return ruleID
        }
    }
}

// MARK: - Array helper

private extension Array where Element: Equatable {
    /// Removes consecutive duplicate elements (keeps first occurrence of each run).
    func removingAdjacentDuplicates() -> [Element] {
        reduce(into: []) { result, el in
            if result.last != el { result.append(el) }
        }
    }
}
