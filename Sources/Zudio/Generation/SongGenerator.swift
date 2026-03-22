// SongGenerator.swift — top-level 10-step generation pipeline
// All steps must complete in order. Outputs a fully populated SongState.

import Foundation

struct SongGenerator {
    // MARK: - Public entry points

    /// Full generation from scratch. Key/tempo overrides from UI selectors (nil = random).
    static func generate(
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        style: MusicStyle = .kosmic,
        testMode: Bool = false,
        forceBassRuleID:      String? = nil,
        forceArpRuleID:       String? = nil,
        forcePadsRuleID:      String? = nil,
        forceLeadRuleID:      String? = nil,
        forceTexRuleID:       String? = nil,
        forcePercussionStyle: PercussionStyle? = nil,
        forceBridge:          Bool    = false,
        forceBridgeArchetype: String? = nil
    ) -> SongState {
        let globalSeed = UInt64.random(in: .min ... .max)
        return generate(seed: globalSeed, keyOverride: keyOverride, tempoOverride: tempoOverride,
                        moodOverride: moodOverride, style: style, testMode: testMode,
                        forceBassRuleID: forceBassRuleID, forceArpRuleID: forceArpRuleID,
                        forcePadsRuleID: forcePadsRuleID, forceLeadRuleID: forceLeadRuleID,
                        forceTexRuleID: forceTexRuleID, forcePercussionStyle: forcePercussionStyle,
                        forceBridge: forceBridge, forceBridgeArchetype: forceBridgeArchetype)
    }

    /// Deterministic generation from an explicit seed (for reproducible test runs).
    static func generate(
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        style: MusicStyle = .kosmic,
        testMode: Bool = false,
        forceBassRuleID:      String? = nil,
        forceArpRuleID:       String? = nil,
        forcePadsRuleID:      String? = nil,
        forceLeadRuleID:      String? = nil,
        forceTexRuleID:       String? = nil,
        forcePercussionStyle: PercussionStyle? = nil,
        forceBridge:          Bool    = false,
        forceBridgeArchetype: String? = nil
    ) -> SongState {
        switch style {
        case .kosmic:
            return generateKosmic(seed: seed, keyOverride: keyOverride, tempoOverride: tempoOverride,
                                  moodOverride: moodOverride, testMode: testMode,
                                  forceBassRuleID: forceBassRuleID, forceArpRuleID: forceArpRuleID,
                                  forcePadsRuleID: forcePadsRuleID, forceLeadRuleID: forceLeadRuleID,
                                  forceTexRuleID: forceTexRuleID, forcePercussionStyle: forcePercussionStyle,
                                  forceBridge: forceBridge, forceBridgeArchetype: forceBridgeArchetype)
        case .motorik:
            return generateMotorik(seed: seed, keyOverride: keyOverride, tempoOverride: tempoOverride,
                                   moodOverride: moodOverride, testMode: testMode,
                                   forceBassRuleID: forceBassRuleID)
        }
    }

    // MARK: - Motorik generation (original path, unchanged)

    private static func generateMotorik(
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        testMode: Bool = false,
        forceBassRuleID: String? = nil
    ) -> SongState {
        var rng = SeededRNG(seed: seed)

        // Step 1 — Global musical frame
        let frame = MusicalFrameGenerator.generate(
            rng: &rng,
            keyOverride: keyOverride,
            tempoOverride: tempoOverride,
            moodOverride: moodOverride,
            testMode: testMode
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
        trackEvents[kTrackBass]    = BassGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &bassRNG, usedRuleIDs: &bassRules, forceRuleID: forceBassRuleID)

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
        var texRules: Set<String> = []
        trackEvents[kTrackTexture] = TextureGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &texRNG, usedRuleIDs: &texRules)

        // Step 10 — Collision / density simplification pass
        trackEvents = DensitySimplifier.simplify(trackEvents: trackEvents, frame: frame, structure: structure)

        // Step 10.5 — Arrangement filter: spotlight rotation so 3+ melodic tracks don't all peak together
        trackEvents = ArrangementFilter.apply(trackEvents: trackEvents, frame: frame, seed: seed)

        // Step 11 — Harmonic filter: clash guard, register separation, velocity arc
        trackEvents = HarmonicFilter.apply(trackEvents: trackEvents, frame: frame, structure: structure)

        // Step 12 — Pattern evolver: gradual bass mutation across evolution windows
        trackEvents = PatternEvolver.apply(trackEvents: trackEvents, frame: frame, structure: structure, tonalMap: tonalMap, seed: seed)

        // Step 13 — Drum variation engine: fills at section transitions and instrument entrances,
        //            plus cymbal variations on 16+-bar identical runs
        trackEvents = DrumVariationEngine.apply(trackEvents: trackEvents, frame: frame, structure: structure, seed: seed)

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
            rhythmRules: rhythmRules, texRules: texRules, testMode: testMode
        )

        let stepAnnotations = buildStepAnnotations(structure: structure, trackEvents: trackEvents, frame: frame, drumRules: drumRules)

        return SongState(
            frame: frame,
            structure: structure,
            tonalMap: tonalMap,
            trackEvents: trackEvents,
            globalSeed: seed,
            trackOverrides: [:],
            title: title,
            form: form,
            style: .motorik,
            percussionStyle: .absent,
            kosmicProgFamily: .static_drone,
            generationLog: log,
            stepAnnotations: stepAnnotations
        )
    }

    // MARK: - Kosmic generation path

    private static func generateKosmic(
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        testMode: Bool = false,
        forceBassRuleID:      String? = nil,
        forceArpRuleID:       String? = nil,
        forcePadsRuleID:      String? = nil,
        forceLeadRuleID:      String? = nil,
        forceTexRuleID:       String? = nil,
        forcePercussionStyle: PercussionStyle? = nil,
        forceBridge:          Bool    = false,
        forceBridgeArchetype: String? = nil
    ) -> SongState {
        var rng = SeededRNG(seed: seed)

        // Step 1 — Kosmic musical frame
        let (frame, percussionStylePicked, kosmicProgFamily) = KosmicMusicalFrameGenerator.generate(
            rng: &rng,
            keyOverride: keyOverride,
            tempoOverride: tempoOverride,
            moodOverride: moodOverride,
            testMode: testMode
        )

        let percussionStyle = forcePercussionStyle ?? percussionStylePicked

        // Step 2 — Kosmic structure (longer sections, glacial pacing)
        let kosmicForm: KosmicSongForm = {
            if forceBridge {
                // Bridge requires an A→B transition — force ab or aba (50/50)
                return rng.nextDouble() < 0.50 ? .ab : .aba
            }
            let forms:   [KosmicSongForm] = [.single_evolving, .ab,  .aba, .abab, .abba]
            let weights: [Double]         = [0.30,             0.20, 0.25, 0.15,  0.10 ]
            return forms[rng.weightedPick(weights)]
        }()
        let structure = KosmicStructureGenerator.generate(
            frame: frame,
            kosmicForm: kosmicForm,
            kosmicProgFamily: kosmicProgFamily,
            percussionStyle: percussionStyle,
            rng: &rng,
            forceBridge: forceBridge,
            forceBridgeArchetype: forceBridgeArchetype
        )

        // Step 3 — Tonal governance map (reused as-is)
        let tonalMap = TonalGovernanceBuilder.build(frame: frame, structure: structure)

        // Steps 4–9 — Per-track MIDI event generation (Kosmic generators)
        var trackEvents = [[MIDIEvent]](repeating: [], count: 7)

        var drumRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackDrums))
        var bassRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackBass))
        var padsRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackPads))
        var lead1RNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead1))
        var lead2RNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead2))
        var rhythmRNG = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackRhythm))
        var texRNG    = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackTexture))

        // Arpeggio (rhythm slot) — the heartbeat of Kosmic
        var rhythmRules: Set<String> = []
        trackEvents[kTrackRhythm] = KosmicArpeggioGenerator.generate(
            frame: frame, structure: structure, tonalMap: tonalMap,
            rng: &rhythmRNG, usedRuleIDs: &rhythmRules, forceRuleID: forceArpRuleID
        )

        // Lead 1
        var lead1Rules: Set<String> = []
        trackEvents[kTrackLead1] = KosmicLeadGenerator.generateLead1(
            frame: frame, structure: structure, tonalMap: tonalMap,
            rng: &lead1RNG, usedRuleIDs: &lead1Rules, forceRuleID: forceLeadRuleID
        )

        // Lead 2
        var lead2Rules: Set<String> = []
        trackEvents[kTrackLead2] = KosmicLeadGenerator.generateLead2(
            frame: frame, structure: structure, tonalMap: tonalMap,
            lead1Events: trackEvents[kTrackLead1],
            rng: &lead2RNG, usedRuleIDs: &lead2Rules
        )

        // Pads
        var padRules: Set<String> = []
        trackEvents[kTrackPads] = KosmicPadsGenerator.generate(
            frame: frame, structure: structure, tonalMap: tonalMap,
            kosmicProgFamily: kosmicProgFamily,
            rng: &padsRNG, usedRuleIDs: &padRules, forceRuleID: forcePadsRuleID
        )

        // Texture (lower register arpeggio, orbital motives)
        var texRules: Set<String> = []
        trackEvents[kTrackTexture] = KosmicTextureGenerator.generate(
            frame: frame, structure: structure, tonalMap: tonalMap,
            rng: &texRNG, usedRuleIDs: &texRules, forceRuleID: forceTexRuleID
        )

        // Bass
        var bassRules: Set<String> = []
        var bassEvolutionBars: [Int] = []
        trackEvents[kTrackBass] = KosmicBassGenerator.generate(
            frame: frame, structure: structure, tonalMap: tonalMap,
            rng: &bassRNG, usedRuleIDs: &bassRules, forceRuleID: forceBassRuleID,
            bassEvolutionBars: &bassEvolutionBars
        )

        // Drums (absent / sparse / minimal per percussionStyle)
        var drumRules: Set<String> = []
        trackEvents[kTrackDrums] = KosmicDrumGenerator.generate(
            frame: frame, structure: structure,
            percussionStyle: percussionStyle,
            rng: &drumRNG, usedRuleIDs: &drumRules
        )

        // Post-processing: apply arrangement and harmonic filters
        // (DensitySimplifier and DrumVariationEngine are Motorik-specific — skip for Kosmic)
        trackEvents = ArrangementFilter.apply(trackEvents: trackEvents, frame: frame, seed: seed)
        trackEvents = HarmonicFilter.apply(trackEvents: trackEvents, frame: frame, structure: structure)

        // Title generation — Kosmic uses its own space-themed generator
        let title = KosmicTitleGenerator.generate(frame: frame, rng: &rng)

        // Song form (use standard Motorik SongForm for compatibility with existing log/UI)
        let form: SongForm = {
            switch kosmicForm {
            case .single_evolving:              return .singleA
            case .ab, .two_world:               return .subtleAB
            case .aba, .build_and_dissolve,
                 .abab, .abba:                  return .moderateAB
            }
        }()

        // Build Kosmic generation log
        let log = buildKosmicLog(
            title: title, frame: frame, structure: structure, form: form,
            percussionStyle: percussionStyle, kosmicForm: kosmicForm,
            kosmicProgFamily: kosmicProgFamily,
            drumRules: drumRules, bassRules: bassRules,
            padRules: padRules, lead1Rules: lead1Rules, lead2Rules: lead2Rules,
            rhythmRules: rhythmRules, texRules: texRules,
            testMode: testMode
        )

        let stepAnnotations = buildStepAnnotations(structure: structure, trackEvents: trackEvents,
                                                    frame: frame, bassEvolutionBars: bassEvolutionBars,
                                                    rhythmRules: rhythmRules, texRules: texRules)

        return SongState(
            frame: frame,
            structure: structure,
            tonalMap: tonalMap,
            trackEvents: trackEvents,
            globalSeed: seed,
            trackOverrides: [:],
            title: title,
            form: form,
            style: .kosmic,
            percussionStyle: percussionStyle,
            kosmicProgFamily: kosmicProgFamily,
            generationLog: log,
            stepAnnotations: stepAnnotations
        )
    }

    // MARK: - Per-track regenerate

    /// Regenerates a single track without touching any other track or the global seed.
    /// Appends regen log entries so the status box reflects the new rules used.
    static func regenerateTrack(_ trackIndex: Int, songState: SongState) -> SongState {
        let newTrackSeed = UInt64.random(in: .min ... .max)
        var rng = SeededRNG(seed: newTrackSeed)
        var usedRules: Set<String> = []

        let events: [MIDIEvent]
        let isKosmic = songState.style == .kosmic
        switch trackIndex {
        case kTrackDrums:
            if isKosmic {
                events = KosmicDrumGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    percussionStyle: songState.percussionStyle,
                    rng: &rng, usedRuleIDs: &usedRules)
            } else {
                let rawDrum = DrumGenerator.generate(frame: songState.frame, structure: songState.structure, rng: &rng, usedRuleIDs: &usedRules)
                var scratch = songState.trackEvents
                scratch[kTrackDrums] = rawDrum
                events = DrumVariationEngine.apply(trackEvents: scratch, frame: songState.frame, structure: songState.structure, seed: newTrackSeed)[kTrackDrums]
            }
        case kTrackBass:
            if isKosmic {
                var ignored: [Int] = []
                events = KosmicBassGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules,
                    bassEvolutionBars: &ignored)
            } else {
                let rawBass = BassGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
                var scratch = songState.trackEvents
                scratch[kTrackBass] = rawBass
                scratch = PatternEvolver.apply(trackEvents: scratch, frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, seed: newTrackSeed)
                scratch = DrumVariationEngine.lockBassToExistingFills(trackEvents: scratch, frame: songState.frame, structure: songState.structure, seed: songState.globalSeed)
                events = scratch[kTrackBass]
            }
        case kTrackPads:
            if isKosmic {
                events = KosmicPadsGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, kosmicProgFamily: songState.kosmicProgFamily,
                    rng: &rng, usedRuleIDs: &usedRules)
            } else {
                events = PadsGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            }
        case kTrackLead1:
            if isKosmic {
                events = KosmicLeadGenerator.generateLead1(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            } else {
                events = LeadGenerator.generateLead1(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            }
        case kTrackLead2:
            if isKosmic {
                events = KosmicLeadGenerator.generateLead2(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, lead1Events: songState.trackEvents[kTrackLead1],
                    rng: &rng, usedRuleIDs: &usedRules)
            } else {
                events = LeadGenerator.generateLead2(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, lead1Events: songState.trackEvents[kTrackLead1], rng: &rng, usedRuleIDs: &usedRules)
            }
        case kTrackRhythm:
            if isKosmic {
                events = KosmicArpeggioGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            } else {
                events = RhythmGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            }
        case kTrackTexture:
            if isKosmic {
                events = KosmicTextureGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            } else {
                events = TextureGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            }
        default:
            return songState
        }

        // Build regen log entries for the status box
        let trackName = trackIndex < kTrackNames.count ? kTrackNames[trackIndex] : "Track \(trackIndex)"
        var regenLog: [GenerationLogEntry] = [
            GenerationLogEntry(tag: "⚡ REGEN", description: trackName, isTitle: true)
        ]
        if usedRules.isEmpty {
            regenLog.append(GenerationLogEntry(tag: "—", description: "no rules captured"))
        } else {
            for ruleID in usedRules.sorted() {
                let desc = ruleDescription(ruleID, trackIndex: trackIndex)
                let tag  = (ruleID == "BASS-EVOL" || ruleID == "BASS-DEVOL") ? "BASS" : ruleID
                regenLog.append(GenerationLogEntry(tag: tag, description: desc))
            }
        }

        var updated = songState.replacingEvents(events, forTrack: trackIndex, appendingLog: regenLog)
        updated.trackOverrides[trackIndex] = newTrackSeed
        return updated
    }

    /// Route a ruleID to the correct description function by trackIndex.
    private static func ruleDescription(_ ruleID: String, trackIndex: Int) -> String {
        switch trackIndex {
        case kTrackDrums:   return drumRuleDescription(ruleID)
        case kTrackBass:    return bassRuleDescription(ruleID)
        case kTrackPads:    return padRuleDescription(ruleID)
        case kTrackLead1:   return lead1RuleDescription(ruleID)
        case kTrackLead2:   return lead2RuleDescription(ruleID)
        case kTrackRhythm:   return rhythmRuleDescription(ruleID)
        case kTrackTexture:  return textureRuleDescription(ruleID)
        default:             return ruleID
        }
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
        rhythmRules: Set<String>,
        texRules: Set<String>,
        testMode: Bool = false
    ) -> [GenerationLogEntry] {
        var log: [GenerationLogEntry] = []

        // Song title
        log.append(GenerationLogEntry(tag: "SONG", description: title, isTitle: true))

        // Structure form rule
        let formRuleID = structureRuleID(form: form, structure: structure)
        let formDesc   = buildFormDescription(form: form, structure: structure)
        log.append(GenerationLogEntry(tag: formRuleID, description: formDesc))

        // Chord progression — key/mode + progression family + chord names on one line
        let chordNames = structure.chordPlan
            .map { chordName(key: frame.key, degree: $0.chordRoot, type: $0.chordType) }
            .removingAdjacentDuplicates()
            .joined(separator: ", ")
        let progLabel = progressionFamilyLabel(frame.progressionFamily)
        let chordDesc = "\(frame.key) \(frame.mode.rawValue)  \(progLabel)" + (chordNames.isEmpty ? "" : "  \(chordNames)")
        log.append(GenerationLogEntry(tag: "Chords", description: chordDesc))

        // Drums
        for ruleID in drumRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: drumRuleDescription(ruleID)))
        }
        if drumRules.isEmpty {
            log.append(GenerationLogEntry(tag: "MOT-DRUM-001", description: drumRuleDescription("MOT-DRUM-001")))
        }

        // Bass
        for ruleID in bassRules.sorted() {
            let baseTag = (ruleID == "BASS-EVOL" || ruleID == "BASS-DEVOL") ? "BASS" : ruleID
            let tag = ruleTag(baseTag, testMode: testMode)
            log.append(GenerationLogEntry(tag: tag, description: bassRuleDescription(ruleID)))
        }
        if bassRules.isEmpty {
            log.append(GenerationLogEntry(tag: "MOT-BASS-001", description: bassRuleDescription("MOT-BASS-001")))
        }

        // Pads — may be multiple rules
        let sortedPadRules = padRules.sorted()
        for ruleID in sortedPadRules {
            log.append(GenerationLogEntry(tag: ruleID, description: padRuleDescription(ruleID)))
        }
        if sortedPadRules.isEmpty {
            log.append(GenerationLogEntry(tag: "MOT-PADS-001",
                description: padRuleDescription("MOT-PADS-001")))
        }

        // Lead 1
        for ruleID in lead1Rules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: lead1RuleDescription(ruleID)))
        }
        if lead1Rules.isEmpty {
            log.append(GenerationLogEntry(tag: "MOT-LD1-001", description: lead1RuleDescription("MOT-LD1-001")))
        }

        // Lead 2
        for ruleID in lead2Rules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: lead2RuleDescription(ruleID)))
        }
        if lead2Rules.isEmpty {
            log.append(GenerationLogEntry(tag: "MOT-LD2-001", description: lead2RuleDescription("MOT-LD2-001")))
        }

        // Rhythm — may be multiple rules
        let sortedRhythmRules = rhythmRules.sorted()
        for ruleID in sortedRhythmRules {
            log.append(GenerationLogEntry(tag: ruleID, description: rhythmRuleDescription(ruleID)))
        }
        if sortedRhythmRules.isEmpty {
            log.append(GenerationLogEntry(tag: "MOT-RHYT-001",
                description: "8th-note ostinato, alternating root/fifth"))
        }

        // Texture
        for ruleID in texRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: textureRuleDescription(ruleID)))
        }
        if texRules.isEmpty {
            log.append(GenerationLogEntry(tag: "MOT-TEXR-001",
                description: "Boundary-weighted sparse atmosphere, scale tensions"))
        }

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

    private static func introStyleLabel(_ style: IntroStyle) -> String {
        switch style {
        case .alreadyPlaying:   return "fade in"
        case .progressiveEntry: return "lock in"
        case .coldStart(_): return "cold start"
        }
    }

    private static func outroStyleLabel(_ style: OutroStyle) -> String {
        switch style {
        case .fade:     return "fade"
        case .dissolve: return "dissolve"
        case .coldStop: return "cold stop — drum fill ending"
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
        case .quartal: return "4th"
        case .power:   return "5"
        }
    }

    private static func progressionFamilyLabel(_ family: ProgressionFamily) -> String {
        switch family {
        case .static_tonic:             return "Static tonic: I"
        case .two_chord_I_bVII:         return "Two chord: I - ♭VII"
        case .minor_loop_i_VII:         return "Minor loop: i - VII"
        case .minor_loop_i_VI:          return "Minor loop: i - VI"
        case .modal_cadence_bVI_bVII_I: return "Modal rock: ♭VI - ♭VII - I"
        }
    }

    private static func drumRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-DRUM-001": return "Classic Motorik"
        case "MOT-DRUM-002": return "Open Pocket"
        case "MOT-DRUM-003": return "Ride Groove"
        case "MOT-DRUM-004": return "Almost Motorik"
        // Kosmic drum rules (shared lookup for regen log)
        case "KOS-DRUM-001": return "Minimal JMJ Pop"
        case "KOS-DRUM-002": return "Sparse pitched percussion"
        case "KOS-DRUM-003": return "No percussion"
        case "KOS-DRUM-004": return "Electric Buddha Groove"
        case "KOS-DRUM-005": return "Electric Buddha Pulse"
        case "KOS-DRUM-006": return "Electric Buddha Restrained"
        default:             return ruleID
        }
    }

    private static func bassRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-BASS-001": return "Root Anchor"
        case "MOT-BASS-002": return "Motorik Drive"
        case "MOT-BASS-003": return "Crawling Walk"
        case "MOT-BASS-004": return "Hallogallo Lock"
        case "MOT-BASS-005": return "McCartney Drive"
        case "MOT-BASS-006": return "LA Woman Sustain"
        case "MOT-BASS-007": return "Hook Ascent"
        case "MOT-BASS-008": return "Moroder Pulse"
        case "MOT-BASS-009": return "Vitamin Hook"
        case "MOT-BASS-010": return "Quo Arc"
        case "MOT-BASS-011": return "Quo Drive"
        case "MOT-BASS-012": return "Moroder Chase"
        case "MOT-BASS-013": return "Kraftwerk Roboter"
        case "MOT-BASS-014": return "McCartney melodic drive"
        case "MOT-BASS-015": return "Kraftwerk driving bass"
        case "BASS-EVOL":    return "Evolving pattern"
        case "BASS-DEVOL":   return "Devolving pattern"
        // Kosmic bass rules (shared lookup for regen log)
        case "KOS-BASS-001": return "Drone Root"
        case "KOS-BASS-002": return "Root-Fifth Slow Walk"
        case "KOS-BASS-003": return "Pedal Pulse"
        case "KOS-BASS-004": return "Moroder Drift"
        case "KOS-BASS-005": return "No bass"
        case "KOS-BASS-006": return "Additive dual bass"
        case "KOS-BASS-007": return "Pulsating tremolo"
        case "KOS-BASS-008": return "Hallogallo Lock"
        case "KOS-BASS-009": return "Crawling Walk"
        case "KOS-BASS-010": return "Probabilistic Moroder Pulse"
        case "KOS-BASS-011": return "Kraftwerk driving bass"
        case "KOS-BASS-012": return "McCartney melodic drive"
        default:             return ruleID
        }
    }

    private static func lead1RuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-LD1-001": return "Motif-first"
        case "MOT-LD1-002": return "Pentatonic Cell"
        case "MOT-LD1-003": return "Long Breath"
        case "MOT-LD1-004": return "Stepwise Sequence"
        case "MOT-LD1-005": return "Statement-Answer"
        default:            return ruleID
        }
    }

    private static func lead2RuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-LD2-001": return "Counter-response"
        case "MOT-LD2-002": return "Sustained Drone"
        case "MOT-LD2-003": return "Rhythmic Counter"
        case "MOT-LD2-004": return "Hallogallo Counter"
        case "MOT-LD2-005": return "Descending Line"
        default:            return ruleID
        }
    }

    private static func padRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-PADS-001": return "Sustained"
        case "MOT-PADS-002": return "Power Drone"
        case "MOT-PADS-003": return "Pulsed"
        case "MOT-PADS-004": return "Sparse"
        case "MOT-PADS-005": return "Arpeggio"
        case "MOT-PADS-006": return "Stabs"
        case "MOT-PADS-007": return "Charleston"
        case "MOT-PADS-008": return "16th Chop"
        case "MOT-PADS-009": return "Quarter Pump"
        case "MOT-PADS-010": return "Half-bar Breathe"
        case "MOT-PADS-011": return "Backbeat Stabs"
        default:             return ruleID
        }
    }

    private static func rhythmRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-RHYT-001": return "8th-note Stride"
        case "MOT-RHYT-002": return "Quarter Stride"
        case "MOT-RHYT-003": return "Syncopated Motorik"
        case "MOT-RHYT-004": return "2-bar Melodic Riff"
        case "MOT-RHYT-005": return "Chord Stab"
        case "MOT-RHYT-006": return "Arpeggio"
        default:             return ruleID
        }
    }

    private static func textureRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-TEXR-001": return "Sparse"
        case "MOT-TEXR-002": return "Transition Swell"
        case "MOT-TEXR-003": return "Drone Anchor"
        case "MOT-TEXR-004": return "Shimmer Pair"
        case "MOT-TEXR-005": return "Breath Release"
        case "MOT-TEXR-006": return "High Tension Touch"
        // Kosmic texture rules
        case "KOS-TEXT-001": return "Orbital Motive"
        case "KOS-TEXT-002": return "EB Shimmer Hold"
        case "KOS-TEXT-003": return "Spatial Sweep"
        default:             return ruleID
        }
    }

    // MARK: - Kosmic rule descriptions

    private static func kosmicDrumRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-DRUM-001": return "Minimal — JMJ Mini Pops style"
        case "KOS-DRUM-002": return "Sparse pitched percussion"
        case "KOS-DRUM-003": return "No percussion — Berlin School"
        case "KOS-DRUM-004": return "Electric Buddha groove"
        case "KOS-DRUM-005": return "Electric Buddha minimal beat"
        case "KOS-DRUM-006": return "Electric Buddha restrained"
        default:                 return ruleID
        }
    }

    private static func kosmicBassRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-BASS-001":  return "Drone Root"
        case "KOS-BASS-002":  return "Root-Fifth Slow Walk"
        case "KOS-BASS-003":  return "Pedal Pulse"
        case "KOS-BASS-004":  return "Moroder Drift"
        case "KOS-BASS-005":  return "No bass"
        case "KOS-BASS-006":  return "Additive dual bass"
        case "KOS-BASS-007":  return "Pulsating tremolo"
        case "KOS-BASS-008":  return "Hallogallo Lock"
        case "KOS-BASS-009":  return "Crawling Walk"
        case "KOS-BASS-010":  return "Probabilistic Moroder Pulse"
        case "KOS-BASS-011":  return "Kraftwerk driving bass"
        case "KOS-BASS-012":  return "McCartney melodic drive"
        case "BASS-EVOL":     return "Evolving pattern"
        case "BASS-DEVOL":    return "Devolving pattern"
        default:              return ruleID.hasPrefix("KOS-") ? ruleID : "Unknown bass rule"
        }
    }

    private static func kosmicPadRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-PADS-001":  return "Long Drone — whole notes held 2–4 bars"
        case "KOS-PADS-002":  return "Swell Chord — velocity ramp 20→80"
        case "KOS-PADS-003":  return "Unsync Layers — 8/10/12 bar loops"
        case "KOS-PADS-004":  return "Suspended Resolution — sus4→minor"
        case "KOS-PADS-005":  return "Quartal Stack — stacked fourths"
        case "KOS-PADS-006":  return "Cloud Shimmer — upper register fade"
        case "KOS-PADS-007":  return "Probabilistic gated chord pulse"
        default:              return ruleID
        }
    }

    private static func kosmicLeadRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-LEAD-001": return "Slow Arc — long rising/falling phrase"
        case "KOS-LEAD-002": return "Floating Tones — widely spaced notes"
        case "KOS-LEAD-003": return "Pentatonic Drift — slow 5-note move"
        case "KOS-LEAD-004": return "Echo Melody — phrase + answer"
        case "KOS-LEAD-005": return "Arpeggio Highlight — held note"
        case "KOS-LEAD-006": return "JMJ evolving phrase loop"
        default:             return ruleID
        }
    }

    private static func kosmicRthmRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-RTHM-001": return "Probabilistic Tangerine Dream sequencer"
        case "KOS-RTHM-002": return "Probabilistic JMJ melodic hook"
        case "KOS-RTHM-003": return "JMJ Oxygène oscillation — ascending then descending"
        case "KOS-RTHM-004": return "Probabilistic Electric Buddha pentatonic groove"
        case "KOS-RTHM-005": return "Probabilistic JMJ Dual-rate arpeggiator"
        case "KOS-RTHM-006": return "Kraftwerk locked pulse"
        case "KOS-RTHM-007": return "Probabilistic pitch-drifting sequence"
        case "KOS-RTHM-008": return "JMJ Oxygène 8-bar arc"
        default:            return ruleID
        }
    }

    private static func kosmicTexRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-TEXT-001": return "Orbital Motive — lower register loop"
        case "KOS-TEXT-002": return "Electric Buddha shimmer hold"
        case "KOS-TEXT-003": return "Spatial Sweep — chromatic passing"
        default:             return ruleID
        }
    }

    private static func kosmicProgressionFamilyLabel(_ family: KosmicProgressionFamily) -> String {
        switch family {
        case .static_drone:          return "Static Drone — single tonic hold"
        case .two_chord_pendulum:    return "Two Chord Pendulum — Vangelis i - bVI"
        case .modal_drift:           return "Modal Drift — i - bVII - bVI"
        case .suspended_resolution:  return "Suspended Resolution — sus4 - minor"
        case .quartal_stack:         return "Quartal Stack — stacked fourths"
        }
    }

    // MARK: - Kosmic generation log builder

    /// Rule IDs introduced recently — shown with a " *" suffix in the status log.
    /// Capped at 6; retire oldest when adding new ones.
    private static let newRuleIDs: Set<String> = [
        "KOS-RTHM-006", "KOS-RTHM-007", "KOS-RTHM-008",
        "KOS-PADS-007",
        "KOS-LEAD-006",
        "KOS-DRUM-006",
        "KOS-BASS-011",
        "MOT-BASS-013",
        "MOT-BASS-015"
    ]

    private static func ruleTag(_ ruleID: String, testMode: Bool) -> String {
        testMode && newRuleIDs.contains(ruleID) ? "\(ruleID) *" : ruleID
    }

    private static func buildKosmicLog(
        title: String,
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        form: SongForm,
        percussionStyle: PercussionStyle,
        kosmicForm: KosmicSongForm,
        kosmicProgFamily: KosmicProgressionFamily,
        drumRules: Set<String>,
        bassRules: Set<String>,
        padRules: Set<String>,
        lead1Rules: Set<String>,
        lead2Rules: Set<String>,
        rhythmRules: Set<String>,
        texRules: Set<String>,
        testMode: Bool = false
    ) -> [GenerationLogEntry] {
        var log: [GenerationLogEntry] = []

        // Song title
        log.append(GenerationLogEntry(tag: "SONG", description: title, isTitle: true))

        // Style identifier
        log.append(GenerationLogEntry(tag: "Style", description: "Kosmic"))

        // Kosmic form
        let kosmicFormLabel: String
        switch kosmicForm {
        case .single_evolving:              kosmicFormLabel = "Single Evolving (Roach/TD)"
        case .ab, .two_world:               kosmicFormLabel = "A - B"
        case .aba, .build_and_dissolve:     kosmicFormLabel = "A - B - A"
        case .abab:                         kosmicFormLabel = "A - B - A - B"
        case .abba:                         kosmicFormLabel = "A - B - B - A"
        }
        // Append bridge note if one was inserted
        let hasBridge = structure.sections.contains { $0.label == .bridge || $0.label == .bridgeAlt || $0.label == .bridgeMelody }
        let bridgeSuffix = hasBridge ? " + bridge" : ""
        let formTag = (hasBridge && testMode) ? "Form *" : "Form"
        log.append(GenerationLogEntry(tag: formTag, description: kosmicFormLabel + bridgeSuffix))


        // Chord progression — key/mode + progression family + chord names on one line
        let chordNames = structure.chordPlan
            .map { chordName(key: frame.key, degree: $0.chordRoot, type: $0.chordType) }
            .removingAdjacentDuplicates()
            .joined(separator: ", ")
        let progFamilyLabel = kosmicProgressionFamilyLabel(kosmicProgFamily)
        let chordDesc = "\(frame.key) \(frame.mode.rawValue)  \(progFamilyLabel)" + (chordNames.isEmpty ? "" : "  \(chordNames)")
        log.append(GenerationLogEntry(tag: "Chords", description: chordDesc))

        // Arpeggio (Rhythm track)
        for ruleID in rhythmRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleTag(ruleID, testMode: testMode), description: kosmicRthmRuleDescription(ruleID)))
        }

        // Lead 1
        for ruleID in lead1Rules.sorted() {
            log.append(GenerationLogEntry(tag: ruleTag(ruleID, testMode: testMode), description: kosmicLeadRuleDescription(ruleID)))
        }

        // Lead 2
        for ruleID in lead2Rules.sorted() {
            log.append(GenerationLogEntry(tag: ruleTag(ruleID, testMode: testMode), description: kosmicLeadRuleDescription(ruleID)))
        }

        // Pads
        for ruleID in padRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleTag(ruleID, testMode: testMode), description: kosmicPadRuleDescription(ruleID)))
        }

        // Texture
        for ruleID in texRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleTag(ruleID, testMode: testMode), description: kosmicTexRuleDescription(ruleID)))
        }

        // Bass
        for ruleID in bassRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleTag(ruleID, testMode: testMode), description: kosmicBassRuleDescription(ruleID)))
        }

        // Drums
        for ruleID in drumRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleTag(ruleID, testMode: testMode), description: kosmicDrumRuleDescription(ruleID)))
        }

        return log
    }

    // MARK: - Step annotations (live playback feed)

    /// Builds a map of absolute step → [GenerationLogEntry] for live playback annotations.
    /// Keys are absolute step indices so each entry fires at precisely the right moment:
    /// section/spotlight/bass events fire at bar start (step 0 of bar);
    /// drum fills fire 2 beats (8 steps) before the fill region begins.
    static func buildStepAnnotations(
        structure: SongStructure,
        trackEvents: [[MIDIEvent]],
        frame: GlobalMusicalFrame,
        drumRules: Set<String> = [],
        bassEvolutionBars: [Int] = [],
        rhythmRules: Set<String> = [],
        texRules: Set<String> = []
    ) -> [Int: [GenerationLogEntry]] {
        var out: [Int: [GenerationLogEntry]] = [:]
        let totalBars = frame.totalBars

        // Precompute bar presence: trackBars[t][bar] = true if track t has any event in that bar.
        // One pass per track (O(totalEvents) total), replaces O(totalEvents × totalBars) repeated
        // .contains calls in sectionInstruments() and the entrance-fills loop.
        let numTracks = min(trackEvents.count, 7)
        let trackBars: [[Bool]] = (0..<numTracks).map { t in
            var present = Array(repeating: false, count: totalBars)
            for ev in trackEvents[t] {
                let b = ev.stepIndex / 16
                if b >= 0 && b < totalBars { present[b] = true }
            }
            return present
        }

        // fire: fires at the given absolute step index
        func fire(_ step: Int, tag: String, desc: String) {
            out[max(0, step), default: []].append(GenerationLogEntry(tag: tag, description: desc))
        }
        // fireBar: convenience — fires at the start of a bar
        func fireBar(_ bar: Int, tag: String, desc: String) {
            fire(bar * 16, tag: tag, desc: desc)
        }

        // Helper: format chord name from degree string + type
        func chordName(_ rootDegree: String, _ type: ChordType) -> String {
            let keyST = keySemitone(frame.key)
            let rootST = (keyST + degreeSemitone(rootDegree) + 12) % 12
            let names = ["C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B"]
            let root = names[rootST]
            switch type {
            case .major:   return root
            case .minor:   return root + "m"
            case .sus2:    return root + "sus2"
            case .sus4:    return root + "sus4"
            case .add9:    return root + "add9"
            case .dom7:    return root + "7"
            case .min7:    return root + "m7"
            case .quartal: return root
            case .power:   return root + "5"
            }
        }

        // Helper: 2–3 chord names covering a section's bars
        func chordsLabel(for section: SongSection) -> String {
            let windows = structure.chordPlan.filter { $0.startBar >= section.startBar && $0.startBar < section.endBar }
            let names = windows.prefix(3).map { chordName($0.chordRoot, $0.chordType) }
            guard !names.isEmpty else { return "" }
            let joined = names.joined(separator: " ")
            return windows.count > 3 ? joined + " …" : joined
        }

        // Helper: describe which instruments are active in a section (for intro/outro labels)
        func sectionInstruments(_ section: SongSection) -> String {
            // O(sectionLength) — sections are 2–8 bars; trackBars lookup is O(1) per bar
            func active(_ t: Int) -> Bool {
                guard t < trackBars.count else { return false }
                return (section.startBar..<section.endBar).contains { trackBars[t][$0] }
            }
            let hasDrums   = active(kTrackDrums)
            let hasBass    = active(kTrackBass)
            let hasRhythm  = active(kTrackRhythm)
            let hasPads    = active(kTrackPads)
            let hasTexture = active(kTrackTexture)
            let hasLead    = active(kTrackLead1) || active(kTrackLead2)
            var parts: [String] = []
            if hasDrums   { parts.append("drums") }
            if hasBass    { parts.append("bass") }
            if hasRhythm  { parts.append("rhythm") }
            if hasPads    { parts.append("pads") }
            if hasTexture { parts.append("texture") }
            if hasLead    { parts.append("lead") }
            let instruments: String
            if parts.isEmpty        { instruments = "drums only" }
            else if parts.count == 2 { instruments = parts.joined(separator: " & ") }
            else                    { instruments = parts.joined(separator: ", ") }
            return "\(section.lengthBars) bars — \(instruments)"
        }

        // Helper: hat-event count in a step range within a bar
        func hatCount(bar: Int, fromStep: Int, toStep: Int) -> Int {
            guard kTrackDrums < trackEvents.count else { return 0 }
            let bs = bar * 16
            let hatNotes: Set<UInt8> = [GMDrum.closedHat.rawValue, GMDrum.pedalHat.rawValue, GMDrum.openHat.rawValue]
            return trackEvents[kTrackDrums].filter {
                $0.stepIndex >= bs + fromStep && $0.stepIndex < bs + toStep && hatNotes.contains($0.note)
            }.count
        }

        // Helper: infer fill length in beats from hat-stripping signature
        func fillBeats(bar: Int) -> Int {
            if hatCount(bar: bar, fromStep: 4, toStep: 16) == 0 { return 3 }
            if hatCount(bar: bar, fromStep: 8, toStep: 16) == 0 { return 2 }
            return 1
        }

        // Helper: bass locked = ≤1 note in back 12 steps of bar
        func bassLocked(bar: Int) -> Bool {
            guard kTrackBass < trackEvents.count else { return false }
            let bs = bar * 16
            return trackEvents[kTrackBass].filter { $0.stepIndex >= bs + 4 && $0.stepIndex < bs + 16 }.isEmpty
        }

        // Helper: identify cold start pickup fill name by examining drum notes in the last intro bar
        func coldStartFillName(bar: Int) -> String {
            guard kTrackDrums < trackEvents.count else { return "drum fill" }
            let bs = bar * 16
            let evs = trackEvents[kTrackDrums].filter { $0.stepIndex >= bs && $0.stepIndex < bs + 16 }
            guard !evs.isEmpty else { return "drum fill" }
            let notes = Set(evs.map { $0.note })
            // Ride-based: Manchester atmospheric (Kosmic v3)
            if notes.contains(GMDrum.ride.rawValue) { return "Buddha atmospheric fill" }
            // All snare: crescendo roll (Kosmic v2)
            if evs.allSatisfy({ $0.note == GMDrum.snare.rawValue }) { return "crescendo roll" }
            // Has electric snare: funk snare build (Motorik v2)
            if notes.contains(GMDrum.snare2.rawValue) { return "funky fill" }
            let hasToms = notes.contains(GMDrum.hiTom.rawValue) || notes.contains(GMDrum.hiMidTom.rawValue)
                       || notes.contains(GMDrum.lowMidTom.rawValue) || notes.contains(GMDrum.highFloorTom.rawValue)
                       || notes.contains(GMDrum.lowFloorTom.rawValue)
            let hasKick = notes.contains(GMDrum.kick.rawValue)
            let hasHat  = notes.contains(GMDrum.closedHat.rawValue)
            // Hat-only (no toms, no kick): hat crescendo (Kosmic v0)
            if !hasToms && !hasKick { return "hat crescendo" }
            // Toms with hat prefix: Bonham-style (Kosmic v1 3-beat / Motorik v1 3-beat)
            if hasToms && hasHat { return "Bonham fill" }
            // Toms, kick, no hat: rock cascade (Motorik v0, or 2-beat variants)
            return "rock fill"
        }

        // Helper: identify fill name by examining drum notes in the fill region
        func fillName(bar: Int, beats: Int) -> String {
            guard kTrackDrums < trackEvents.count else { return "drum fill" }
            let bs = bar * 16
            let regionStart = bs + (beats == 3 ? 4 : beats == 2 ? 8 : 12)
            let evs = trackEvents[kTrackDrums].filter { $0.stepIndex >= regionStart && $0.stepIndex < bs + 16 }
            let notes = Set(evs.map { $0.note })
            switch beats {
            case 1:
                if notes.contains(GMDrum.sidestick.rawValue)    { return "sidestick flam" }
                if notes.contains(GMDrum.highFloorTom.rawValue) { return "floor tap" }
                let snareCount = evs.filter { $0.note == GMDrum.snare.rawValue }.count
                if snareCount >= 4                               { return "snare roll" }
                // Hat triplet cue: closed hat on step 13 (odd position flags the triplet push)
                if evs.contains(where: { $0.stepIndex == bs + 13 && $0.note == GMDrum.closedHat.rawValue }) {
                    return "hat triplet cue"
                }
                // Ghost whisper: hat still rolls on step 14 (no stripping)
                if evs.contains(where: { $0.stepIndex == bs + 14 && ($0.note == GMDrum.closedHat.rawValue || $0.note == GMDrum.pedalHat.rawValue) }) {
                    return "ghost whisper"
                }
                return "double snap"
            case 2:
                if notes.contains(GMDrum.hiTom.rawValue)  { return "Bonham tom cascade" }
                if notes.contains(GMDrum.kick.rawValue)   { return "funk cross-pattern" }
                if evs.allSatisfy({ $0.note == GMDrum.snare.rawValue }) { return "double-time roll" }
                return "snare and toms"
            default: // 3 beats
                if evs.allSatisfy({ $0.note == GMDrum.snare.rawValue }) { return "crescendo roll" }
                // Alternating toms: hiMidTom and lowFloorTom interleaved
                let hiMidCount   = evs.filter { $0.note == GMDrum.hiMidTom.rawValue }.count
                let floorLowCount = evs.filter { $0.note == GMDrum.lowFloorTom.rawValue }.count
                if hiMidCount >= 3 && floorLowCount >= 3 { return "alternating toms" }
                return "tom cascade"
            }
        }

        // Compute all fill bars — replicates DrumVariationEngine.computeFillBars (deterministic part)
        var allFillBars = Set<Int>()
        // Section transition fills: bar before each new body section
        var prevLabel: SectionLabel? = nil
        for bar in 0..<totalBars {
            guard let sec = structure.section(atBar: bar) else { continue }
            if sec.label != prevLabel {
                if bar > 0, sec.label != .intro && sec.label != .outro {
                    let fillBar = bar - 1
                    if let prevSec = structure.section(atBar: fillBar), prevSec.label != .intro {
                        allFillBars.insert(fillBar)
                    }
                }
            }
            prevLabel = sec.label
        }
        // Entrance fills: non-drum track comes in after ≥2 silent bars
        for trackIdx in 0..<kTrackDrums {
            guard trackIdx < trackEvents.count else { continue }
            // O(1) per bar — uses the precomputed presence map instead of rescanning all events
            let presence = trackIdx < trackBars.count ? trackBars[trackIdx] : Array(repeating: false, count: totalBars)
            for bar in 2..<totalBars {
                guard presence[bar] && !presence[bar - 1] && !presence[bar - 2] else { continue }
                let fillBar = bar - 1
                guard let sec = structure.section(atBar: fillBar),
                      sec.label != .intro && sec.label != .outro else { continue }
                allFillBars.insert(fillBar)
            }
        }

        // 1. Section entries — fire at bar start (the change is heard immediately)
        var seenLabels = Set<SectionLabel>()
        for section in structure.sections {
            let bar = section.startBar
            switch section.label {
            case .intro:
                let introDesc: String
                if case .coldStart(_) = structure.introStyle {
                    let lastIntroBar = section.endBar - 1
                    let fillLabel = coldStartFillName(bar: lastIntroBar)
                    introDesc = "\(section.lengthBars) bar cold start — \(fillLabel)"
                } else {
                    introDesc = "\(section.lengthBars) bar \(introStyleLabel(structure.introStyle))"
                }
                fireBar(bar, tag: "Intro", desc: introDesc)
            case .A:
                let chords = chordsLabel(for: section)
                if seenLabels.contains(.A) {
                    fireBar(bar, tag: "Form", desc: "Return to A section" + (chords.isEmpty ? "" : " — \(chords)"))
                } else {
                    fireBar(bar, tag: "Section A", desc: chords.isEmpty ? "\(section.lengthBars) bars" : "chords \(chords)")
                }
            case .B:
                let chords = chordsLabel(for: section)
                if seenLabels.contains(.B) {
                    fireBar(bar, tag: "Form", desc: "Enter B section again" + (chords.isEmpty ? "" : " — \(chords)"))
                } else {
                    fireBar(bar, tag: "Form", desc: "Enter B section" + (chords.isEmpty ? "" : " — \(chords)"))
                }
            case .outro:
                fireBar(bar, tag: "Outro", desc: "\(section.lengthBars) bar \(outroStyleLabel(structure.outroStyle))")
            case .bridge:
                fireBar(bar, tag: "Form", desc: "Bridge: escalating drums")
            case .bridgeAlt:
                fireBar(bar, tag: "Form", desc: "Bridge: call and response")
            case .bridgeMelody:
                fireBar(bar, tag: "Form", desc: "Bridge: melody")
            case .preRamp:
                fireBar(bar, tag: "Form", desc: "Transition")
            case .postRamp:
                fireBar(bar, tag: "Form", desc: "Returning to A section")
            }
            seenLabels.insert(section.label)
        }

        // Once the outro begins the song is winding down — suppress all instrument
        // annotations (fills, cymbals, spotlight, bass evolution, pattern changes).
        let outroStartBar = structure.outroSection?.startBar ?? totalBars

        // 2. Drum fills — fire 2 beats (8 steps) before the fill region begins, so the
        //    text appears just ahead of the hit rather than a full bar early.
        //    Fill region offsets: 1-beat → step 12, 2-beat → step 8, 3-beat → step 4.
        //    Fire steps:          1-beat → step 4,  2-beat → step 0,  3-beat → step 0.
        //    Skip entirely when percussion is absent (drum track empty).
        let hasDrums = kTrackDrums < trackEvents.count && !trackEvents[kTrackDrums].isEmpty
        for fillBar in allFillBars.sorted() where fillBar < outroStartBar && hasDrums {
            guard let sec = structure.section(atBar: fillBar),
                  sec.label != .intro && sec.label != .outro else { continue }
            let beats  = fillBeats(bar: fillBar)
            guard beats > 1 else { continue }  // 1-beat fills are too brief to clutter the log with
            let name   = fillName(bar: fillBar, beats: beats)
            let locked = bassLocked(bar: fillBar)
            let desc   = locked ? "\(beats) beat — \(name) — bass locked in" : "\(beats) beat — \(name)"
            // fillRegionOffset: where in the bar the fill starts; fire 1/4 bar (4 steps) before that
            let fillRegionOffset = beats == 1 ? 12 : beats == 2 ? 8 : 4
            fire(fillBar * 16 + max(0, fillRegionOffset - 4), tag: "Drum fill", desc: desc)
        }

        // 3. Drum cymbal variations — announce only on transitions, not every bar.
        // DRM-003 (Ride Groove) uses ride as its baseline — skip ride annotations for it
        // since the generation log already documents this. For all other drum rules, track
        // the cymbal mode across the whole song (no reset between sections) so a transition
        // back to ride after a non-body section doesn't re-trigger.
        let isRideGroove = drumRules.contains("MOT-DRUM-003")
        if kTrackDrums < trackEvents.count {
            let drumEvs = trackEvents[kTrackDrums]
            var prevCymbalMode: String? = nil
            for bar in 0..<totalBars {
                guard !allFillBars.contains(bar),
                      let sec = structure.section(atBar: bar),
                      sec.label == .A || sec.label == .B else { continue }
                let bs = bar * 16
                let barEvs = drumEvs.filter { $0.stepIndex >= bs && $0.stepIndex < bs + 16 }
                let hasRide       = barEvs.contains { $0.note == GMDrum.ride.rawValue }
                let hasClosedHat  = barEvs.contains { $0.note == GMDrum.closedHat.rawValue }
                let hasCrashBeat1 = barEvs.contains { $0.stepIndex == bs     && $0.note == GMDrum.crash1.rawValue }
                let hasOpenHat6   = barEvs.contains { $0.stepIndex == bs + 6  && $0.note == GMDrum.openHat.rawValue }
                let hasOpenHat14  = barEvs.contains { $0.stepIndex == bs + 14 && $0.note == GMDrum.openHat.rawValue }
                let mode: String
                if hasRide && !hasClosedHat {
                    mode = "ride"
                } else if hasCrashBeat1 && hasOpenHat6 {
                    mode = "crash"
                } else if hasOpenHat14 && !hasClosedHat {
                    mode = "openHat"
                } else {
                    mode = "hat"
                }
                if mode != prevCymbalMode {
                    switch mode {
                    case "ride":
                        // Don't announce ride when ride IS the normal pattern for this song
                        if !isRideGroove {
                            fireBar(bar, tag: "Drums", desc: "switching to ride")
                        }
                    case "crash":
                        fireBar(bar, tag: "Drums", desc: "crash on beat 1, open hat colour")
                    case "openHat":
                        fireBar(bar, tag: "Drums", desc: "open hat on the 'and of 4'")
                    case "hat":
                        // Only announce the switch back if we were in a named variation
                        if prevCymbalMode != nil && prevCymbalMode != "hat" {
                            fireBar(bar, tag: "Drums", desc: "back on hi-hat")
                        }
                    default: break
                     }
                    prevCymbalMode = mode
                }
            }
        }

        // 4. Track spotlight entrances and departures.
        // Departure: fire "stepping back" at the start of a 4+ bar silence (ArrangementFilter rest/reduce).
        // Entrance: fire re-entry desc when a track returns after 3+ silent bars.
        let spotlightTracks: [(trackIdx: Int, name: String, entranceDesc: String)] = [
            (kTrackLead1,   "Lead 1",  "steps into the spotlight"),
            (kTrackLead2,   "Lead 2",  "steps into the spotlight"),
            (kTrackPads,    "Pads",    "is back on stage"),
            (kTrackRhythm,  "Rhythm",  "is back on stage"),
            (kTrackTexture, "Texture", "steps into the spotlight")
        ]
        for (trackIdx, trackName, entranceDesc) in spotlightTracks {
            guard trackIdx < trackEvents.count else { continue }
            var barHasNotes = [Bool](repeating: false, count: totalBars)
            for ev in trackEvents[trackIdx] {
                let b = ev.stepIndex / 16
                if b < totalBars { barHasNotes[b] = true }
            }
            // Scan for silence blocks: find start and end of each contiguous silent run.
            // Thresholds are intentionally high — only flag tracks that are genuinely absent,
            // not sparse instruments with natural gaps between phrases.
            var lastAnnouncedBar: Int = -16
            let limit = min(outroStartBar, totalBars)
            var i = 0
            while i < limit {
                if !barHasNotes[i] {
                    let silenceStart = i
                    while i < limit && !barHasNotes[i] { i += 1 }
                    let silenceLen = i - silenceStart
                    // Departure: 8+ bar silence that begins after the track was active
                    if silenceLen >= 8 && silenceStart > 0 && barHasNotes[silenceStart - 1]
                       && (silenceStart - lastAnnouncedBar) >= 16 {
                        fireBar(silenceStart, tag: trackName, desc: "stepping back")
                        lastAnnouncedBar = silenceStart
                    }
                    // Entrance: track re-enters after 8+ bar silence
                    if i < limit && silenceLen >= 8 && (i - lastAnnouncedBar) >= 16 {
                        fireBar(i, tag: trackName, desc: entranceDesc)
                        lastAnnouncedBar = i
                    }
                } else {
                    i += 1
                }
            }
        }

        // 5. Bass pattern evolving — fire when the bass pattern changes character.
        //
        // Two detection paths:
        // A) Explicit: generators pass bassEvolutionBars with the exact bars where the
        //    pattern variant starts/ends. Used for Kosmic patterns where the dual layer
        //    (KOS-BASS-006/007) masks fingerprint changes. Applied with 4-bar cooldown.
        // B) Fingerprint: 4-bar pitch-class window comparison + density check. Fallback
        //    for patterns not covered by explicit tracking. 8-bar cooldown.
        if kTrackBass < trackEvents.count {
            var lastEvolvedBar: Int = -8

            if !bassEvolutionBars.isEmpty {
                // Path A: explicit bars from generator
                for bar in bassEvolutionBars.sorted() where bar < outroStartBar {
                    guard let sec = structure.section(atBar: bar),
                          sec.label == .A || sec.label == .B else { continue }
                    guard (bar - lastEvolvedBar) >= 4 else { continue }
                    fireBar(bar, tag: "Bass", desc: "pattern evolving")
                    lastEvolvedBar = bar
                }
            } else {
                // Path B: fingerprint inference (Motorik and patterns without explicit tracking)
                let bassEvents = trackEvents[kTrackBass]
                func bassFP(fromBar: Int) -> Set<UInt8> {
                    let windowEnd = min(fromBar + 4, totalBars)
                    return Set(bassEvents
                        .filter { let b = $0.stepIndex / 16; return b >= fromBar && b < windowEnd }
                        .map { $0.note % 12 })
                }
                func bassCount(fromBar: Int) -> Int {
                    let windowEnd = min(fromBar + 4, totalBars)
                    return bassEvents.filter { let b = $0.stepIndex / 16; return b >= fromBar && b < windowEnd }.count
                }
                var prevFP: Set<UInt8>? = nil
                var prevCount: Int = 0
                for bar in stride(from: 0, to: outroStartBar, by: 4) {
                    guard let sec = structure.section(atBar: bar),
                          sec.label == .A || sec.label == .B else { continue }
                    let fp = bassFP(fromBar: bar)
                    let count = bassCount(fromBar: bar)
                    if let prev = prevFP, !fp.isEmpty, !prev.isEmpty,
                       (bar - lastEvolvedBar) >= 8 {
                        let union = fp.union(prev).count
                        let common = fp.intersection(prev).count
                        let jaccard = union > 0 ? Double(common) / Double(union) : 1.0
                        let n = Double(prev.count)
                        let adaptiveThreshold = prev.count <= 2 ? 0.99 :
                            min(0.88, n / (n + 1.0) + 0.03)
                        let newClasses = fp.subtracting(prev)
                        let pitchChanged = jaccard < adaptiveThreshold || (prev.count <= 2 && !newClasses.isEmpty)
                        let densityChanged = prevCount > 0 &&
                            abs(count - prevCount) > max(1, prevCount / 2)
                        if pitchChanged || densityChanged {
                            fireBar(bar, tag: "Bass", desc: "pattern evolving")
                            lastEvolvedBar = bar
                        }
                    }
                    if !fp.isEmpty {
                        prevFP = fp
                        prevCount = count
                    }
                }
            }
        }

        // 6. Pads and Rhythm pattern changes — compare step-position fingerprints between body sections.
        // PAD-001 auto-breaks to PAD-007 after 4 bars; Rhythm picks a new rule per section;
        // fingerprint comparison catches meaningful rhythmic shifts in both tracks.
        for (patternTrack, patternTag) in [(kTrackPads, "Pads"), (kTrackRhythm, "Rhythm")] {
            guard patternTrack < trackEvents.count else { continue }
            let evs = trackEvents[patternTrack]
            var prevStepFP: Set<Int>? = nil
            for section in structure.sections {
                guard section.label == .A || section.label == .B else { prevStepFP = nil; continue }
                let steps = Set(evs
                    .filter { let b = $0.stepIndex / 16; return b >= section.startBar && b < section.endBar }
                    .map { $0.stepIndex % 16 })
                if let prev = prevStepFP, !steps.isEmpty, !prev.isEmpty {
                    let union  = steps.union(prev).count
                    let common = steps.intersection(prev).count
                    if union > 0 && Double(common) / Double(union) < 0.55 {
                        fireBar(section.startBar, tag: patternTag, desc: "rhythm pattern changes")
                    }
                }
                if !steps.isEmpty { prevStepFP = steps }
            }
        }

        // Pattern evolution annotations — KOS-TEXT-001 and KOS-RTHM-006 shift register at B section
        // boundaries when a B section exists; fall back to bar-count logic for single_evolving.
        let firstBodyBar = structure.sections
            .first(where: { $0.label != .intro && $0.label != .outro })?.startBar ?? 0
        let bSections = structure.sections.filter { $0.label == .B }

        if texRules.contains("KOS-TEXT-001") {
            if structure.hasBSection {
                for bSec in bSections {
                    fireBar(bSec.startBar, tag: "Texture", desc: "octave lift")
                    if bSec.endBar < outroStartBar {
                        fireBar(bSec.endBar, tag: "Texture", desc: "back to original")
                    }
                }
            } else {
                var b = firstBodyBar + 24
                while b < outroStartBar {
                    fireBar(b, tag: "Texture", desc: "octave lift")
                    let returnBar = b + 8
                    if returnBar < outroStartBar { fireBar(returnBar, tag: "Texture", desc: "back to original") }
                    b += 24
                }
            }
        }

        if rhythmRules.contains("KOS-RTHM-006") {
            if structure.hasBSection {
                for bSec in bSections {
                    fireBar(bSec.startBar, tag: "Rhythm", desc: "octave shift")
                    if bSec.endBar < outroStartBar {
                        fireBar(bSec.endBar, tag: "Rhythm", desc: "back to original")
                    }
                }
            } else {
                var b = firstBodyBar + 32
                while b < outroStartBar {
                    fireBar(b, tag: "Rhythm", desc: "octave shift")
                    let returnBar = b + 4
                    if returnBar < outroStartBar { fireBar(returnBar, tag: "Rhythm", desc: "back to original") }
                    b += 32
                }
            }
        }

        return out
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
