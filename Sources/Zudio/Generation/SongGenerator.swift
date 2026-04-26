// SongGenerator.swift — top-level 10-step generation pipeline
// Copyright (c) 2026 Zack Urlocker
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
        forceBassRuleID:      String? = nil,
        forceDrumRuleID:      String? = nil,
        forceArpRuleID:       String? = nil,
        forcePadsRuleID:      String? = nil,
        forceLeadRuleID:      String? = nil,
        forceTexRuleID:       String? = nil,
        forcePercussionStyle: PercussionStyle? = nil,
        forceBridge:          Bool    = false,
        useBrushKit:          Bool    = false
    ) -> SongState {
        let globalSeed = UInt64.random(in: .min ... .max)
        return generate(seed: globalSeed, keyOverride: keyOverride, tempoOverride: tempoOverride,
                        moodOverride: moodOverride, style: style,
                        forceBassRuleID: forceBassRuleID, forceDrumRuleID: forceDrumRuleID,
                        forceArpRuleID: forceArpRuleID,
                        forcePadsRuleID: forcePadsRuleID, forceLeadRuleID: forceLeadRuleID,
                        forceTexRuleID: forceTexRuleID, forcePercussionStyle: forcePercussionStyle,
                        forceBridge: forceBridge,
                        useBrushKit: useBrushKit)
    }

    /// Deterministic generation from an explicit seed (for reproducible test runs).
    static func generate(
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        style: MusicStyle = .kosmic,
        forceBassRuleID:      String? = nil,
        forceDrumRuleID:      String? = nil,
        forceArpRuleID:       String? = nil,
        forcePadsRuleID:      String? = nil,
        forceLeadRuleID:      String? = nil,
        forceTexRuleID:       String? = nil,
        forcePercussionStyle: PercussionStyle? = nil,
        forceBridge:          Bool    = false,
        useBrushKit:          Bool    = false
    ) -> SongState {
        switch style {
        case .kosmic:
            return generateKosmic(seed: seed, keyOverride: keyOverride, tempoOverride: tempoOverride,
                                  moodOverride: moodOverride,
                                  forceBassRuleID: forceBassRuleID, forceArpRuleID: forceArpRuleID,
                                  forcePadsRuleID: forcePadsRuleID, forceLeadRuleID: forceLeadRuleID,
                                  forceTexRuleID: forceTexRuleID, forcePercussionStyle: forcePercussionStyle,
                                  forceBridge: forceBridge)
        case .motorik:
            return generateMotorik(seed: seed, keyOverride: keyOverride, tempoOverride: tempoOverride,
                                   moodOverride: moodOverride,
                                   forceBassRuleID:   forceBassRuleID,
                                   forceDrumRuleID:   forceDrumRuleID,
                                   forceRhythmRuleID: forceArpRuleID,
                                   forceLeadRuleID:   forceLeadRuleID)
        case .ambient:
            return generateAmbient(seed: seed, keyOverride: keyOverride, tempoOverride: tempoOverride,
                                   moodOverride: moodOverride,
                                   forceBassRuleID: forceBassRuleID, forceArpRuleID: forceArpRuleID,
                                   forcePadsRuleID: forcePadsRuleID, forceLeadRuleID: forceLeadRuleID,
                                   forceTexRuleID: forceTexRuleID, forcePercussionStyle: forcePercussionStyle,
                                   forceBridge: forceBridge,
                                   useBrushKit: useBrushKit)
        case .chill:
            return generateChill(seed: seed, keyOverride: keyOverride, tempoOverride: tempoOverride,
                                 moodOverride: moodOverride,
                                 forceBassRuleID: forceBassRuleID,
                                 forceDrumRuleID: forceDrumRuleID,
                                 forcePadsRuleID: forcePadsRuleID,
                                 forceLeadRuleID: forceLeadRuleID,
                                 forceRhythmRuleID: forceArpRuleID,
                                 forceTexRuleID: forceTexRuleID)
        }
    }

    // MARK: - Motorik generation (original path, unchanged)

    private static func generateMotorik(
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        forceBassRuleID:   String? = nil,
        forceDrumRuleID:   String? = nil,
        forceRhythmRuleID: String? = nil,
        forceLeadRuleID:   String? = nil
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
        var trackEvents = [[MIDIEvent]](repeating: [], count: kTrackCount)

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
        trackEvents[kTrackDrums]   = DrumGenerator.generate(frame: frame, structure: structure, rng: &drumRNG, usedRuleIDs: &drumRules, forceRuleID: forceDrumRuleID)

        // Step 5 — Bass
        var bassRules: Set<String> = []
        trackEvents[kTrackBass]    = BassGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &bassRNG, usedRuleIDs: &bassRules, forceRuleID: forceBassRuleID)

        // Step 6 — Pads
        var padRules: Set<String> = []
        trackEvents[kTrackPads]    = PadsGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &padsRNG, usedRuleIDs: &padRules)

        // Step 7 — Leads
        var lead1Rules: Set<String> = []
        var lead2Rules: Set<String> = []
        let (lead1Events, ld1SoloRange) = LeadGenerator.generateLead1(frame: frame, structure: structure, tonalMap: tonalMap, rng: &lead1RNG, usedRuleIDs: &lead1Rules, forceLeadRuleID: forceLeadRuleID)
        trackEvents[kTrackLead1] = lead1Events
        trackEvents[kTrackLead2] = LeadGenerator.generateLead2(frame: frame, structure: structure, tonalMap: tonalMap, lead1Events: lead1Events, rng: &lead2RNG, usedRuleIDs: &lead2Rules, soloRange: ld1SoloRange)

        // Step 8 — Rhythm
        var rhythmRules: Set<String> = []
        trackEvents[kTrackRhythm]  = RhythmGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rhythmRNG, usedRuleIDs: &rhythmRules, forceRuleID: forceRhythmRuleID)

        // Step 9 — Texture
        var texRules: Set<String> = []
        trackEvents[kTrackTexture] = TextureGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &texRNG, usedRuleIDs: &texRules)

        // Step 10 — Collision / density simplification pass
        trackEvents = DensitySimplifier.simplify(trackEvents: trackEvents, frame: frame, structure: structure)

        // Step 10.5 — Arrangement filter: spotlight rotation so 3+ melodic tracks don't all peak together
        trackEvents = ArrangementFilter.apply(trackEvents: trackEvents, frame: frame, structure: structure, seed: seed, lead1SoloRange: ld1SoloRange)

        // Step 10.7 — Pads gate: when Lead 1 is on a solo rule (< 30 notes), thin pads outside
        // the solo window to avoid a dense shimmer wall with nothing cutting through it.
        if let soloWindow = ld1SoloRange, trackEvents[kTrackLead1].count < 30 {
            let soloSteps = Set(soloWindow.flatMap { bar in (bar * 16)..<(bar * 16 + 16) })
            var padGateRNG = SeededRNG(seed: seed &+ 0xE1)
            trackEvents[kTrackPads] = trackEvents[kTrackPads].filter { ev in
                soloSteps.contains(ev.stepIndex) || padGateRNG.nextDouble() < 0.70
            }
        }

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
            rhythmRules: rhythmRules, texRules: texRules
        )

        let stepAnnotations = buildStepAnnotations(structure: structure, trackEvents: trackEvents, frame: frame, drumRules: drumRules, soloRange: ld1SoloRange, soloRuleID: lead1Rules.first(where: { $0 == "MOT-LD1-007" || $0 == "MOT-LD1-008" }))

        var forced: [String: String] = [:]
        if let r = forceBassRuleID   { forced["Bass"]   = r }
        if let r = forceDrumRuleID   { forced["Drums"]  = r }
        if let r = forceRhythmRuleID { forced["Rhythm"] = r }
        if let r = forceLeadRuleID   { forced["Lead"]   = r }

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
            stepAnnotations: stepAnnotations,
            forcedRules: forced,
            keyOverride: keyOverride,
            tempoOverride: tempoOverride,
            moodOverride: moodOverride
        )
    }

    // MARK: - Kosmic generation path

    private static func generateKosmic(
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        forceBassRuleID:      String? = nil,
        forceArpRuleID:       String? = nil,
        forcePadsRuleID:      String? = nil,
        forceLeadRuleID:      String? = nil,
        forceTexRuleID:       String? = nil,
        forcePercussionStyle: PercussionStyle? = nil,
        forceBridge:          Bool    = false
    ) -> SongState {
        var rng = SeededRNG(seed: seed)

        // Step 1 — Kosmic musical frame
        let (frame, percussionStylePicked, kosmicProgFamily) = KosmicMusicalFrameGenerator.generate(
            rng: &rng,
            keyOverride: keyOverride,
            tempoOverride: tempoOverride,
            moodOverride: moodOverride
        )

        let percussionStyle = forcePercussionStyle ?? percussionStylePicked

        // Step 2 — Kosmic structure (longer sections, glacial pacing)
        let kosmicForm: KosmicSongForm = {
            if forceBridge {
                // Bridge requires an A→B transition — force ab or aba (50/50)
                return rng.nextDouble() < 0.50 ? .ab : .aba
            }
            let forms:   [KosmicSongForm] = [.single_evolving, .ab,  .aba, .abab, .abba]
            let weights: [Double]         = [0.15,             0.25, 0.30, 0.18,  0.12 ]
            return forms[rng.weightedPick(weights)]
        }()
        let structure = KosmicStructureGenerator.generate(
            frame: frame,
            kosmicForm: kosmicForm,
            kosmicProgFamily: kosmicProgFamily,
            percussionStyle: percussionStyle,
            rng: &rng,
            forceBridge: forceBridge
        )

        // Step 3 — Tonal governance map (reused as-is)
        let tonalMap = TonalGovernanceBuilder.build(frame: frame, structure: structure)

        // Steps 4–9 — Per-track MIDI event generation (Kosmic generators)
        var trackEvents = [[MIDIEvent]](repeating: [], count: kTrackCount)

        var drumRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackDrums))
        var bassRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackBass))
        var padsRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackPads))
        var lead1RNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead1))
        var lead2RNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead2))
        var rhythmRNG = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackRhythm))
        var texRNG    = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackTexture))

        // Lead 1 (must run before arpeggio so xFilesBars are known)
        var lead1Rules: Set<String> = []
        var lead1BaseRule = ""
        var xFilesBars: [Int] = []
        trackEvents[kTrackLead1] = KosmicLeadGenerator.generateLead1(
            frame: frame, structure: structure, tonalMap: tonalMap,
            rng: &lead1RNG, usedRuleIDs: &lead1Rules, forceRuleID: forceLeadRuleID,
            lead1BaseRule: &lead1BaseRule, xFilesBars: &xFilesBars
        )

        // Arpeggio (rhythm slot) — the heartbeat of Kosmic
        var rhythmRules: Set<String> = []
        trackEvents[kTrackRhythm] = KosmicArpeggioGenerator.generate(
            frame: frame, structure: structure, tonalMap: tonalMap,
            rng: &rhythmRNG, usedRuleIDs: &rhythmRules, forceRuleID: forceArpRuleID
        )

        // Lead 2
        var lead2Rules: Set<String> = []
        trackEvents[kTrackLead2] = KosmicLeadGenerator.generateLead2(
            frame: frame, structure: structure, tonalMap: tonalMap,
            lead1Events: trackEvents[kTrackLead1],
            rng: &lead2RNG, usedRuleIDs: &lead2Rules,
            lead1BaseRuleID: lead1BaseRule,
            xFilesBars: xFilesBars
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
            kosmicProgFamily: kosmicProgFamily,
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
        trackEvents = ArrangementFilter.apply(trackEvents: trackEvents, frame: frame, structure: structure, seed: seed)
        trackEvents = HarmonicFilter.apply(trackEvents: trackEvents, frame: frame, structure: structure)

        // Kosmic density guard: if Rhythm is more than 2× as dense as Lead 1, thin Rhythm
        // to 65% retention to prevent it from burying the lead. Downbeats are always kept.
        let lead1Count  = trackEvents[kTrackLead1].count
        let rhythmCount = trackEvents[kTrackRhythm].count
        if lead1Count > 0 && rhythmCount > lead1Count * 2 {
            var densityRNG = SeededRNG(seed: seed &+ 0xD0)
            trackEvents[kTrackRhythm] = trackEvents[kTrackRhythm].filter { ev in
                ev.stepIndex % 16 == 0 || densityRNG.nextDouble() < 0.65
            }
        }

        // A-B-B-A second-B variation: thin Rhythm (60% retention), drop Texture for first 8 bars,
        // and reduce Pads velocity for first half — gives the repeat B a stripped-back feel.
        let bSections = structure.sections.filter { $0.label == .B }
        if bSections.count >= 2 {
            let secondB = bSections[1]
            let halfBar = secondB.startBar + (secondB.endBar - secondB.startBar) / 2
            var varRNG = SeededRNG(seed: seed &+ 0xBB)
            trackEvents[kTrackRhythm] = trackEvents[kTrackRhythm].filter { ev in
                let bar = ev.stepIndex / 16
                guard bar >= secondB.startBar && bar < secondB.endBar else { return true }
                return ev.stepIndex % 16 == 0 || varRNG.nextDouble() < 0.60
            }
            // Texture: silent for first 8 bars of second B
            let texSilenceEnd = min(secondB.startBar + 8, secondB.endBar)
            trackEvents[kTrackTexture] = trackEvents[kTrackTexture].filter { ev in
                let bar = ev.stepIndex / 16
                return !(bar >= secondB.startBar && bar < texSilenceEnd)
            }
            // Pads: reduce velocity by ~15% in first half of second B
            trackEvents[kTrackPads] = trackEvents[kTrackPads].map { ev in
                let bar = ev.stepIndex / 16
                guard bar >= secondB.startBar && bar < halfBar else { return ev }
                return MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                 velocity: UInt8(max(10, Int(ev.velocity) * 85 / 100)),
                                 durationSteps: ev.durationSteps)
            }
        }

        // Lead Synth — copy AFTER all filters so it mirrors exactly what Lead 1 plays.
        // (Bug fix: copying before filters caused Lead Synth to have more notes than Lead 1.)
        trackEvents[kTrackLeadSynth] = trackEvents[kTrackLead1].map { ev in
            MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                      velocity: UInt8(max(1, Int(ev.velocity) * 60 / 100)),
                      durationSteps: ev.durationSteps)
        }

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
            rhythmRules: rhythmRules, texRules: texRules
        )

        let stepAnnotations = buildStepAnnotations(structure: structure, trackEvents: trackEvents,
                                                    frame: frame, bassEvolutionBars: bassEvolutionBars,
                                                    rhythmRules: rhythmRules, texRules: texRules,
                                                    xFilesBars: xFilesBars)

        var forced: [String: String] = [:]
        if let r = forceBassRuleID  { forced["Bass"]   = r }
        if let r = forceArpRuleID   { forced["Rhythm"] = r }
        if let r = forcePadsRuleID  { forced["Pads"]   = r }
        if let r = forceLeadRuleID  { forced["Lead"]   = r }
        if let r = forceTexRuleID   { forced["Tex"]    = r }

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
            stepAnnotations: stepAnnotations,
            forcedRules: forced,
            keyOverride: keyOverride,
            tempoOverride: tempoOverride,
            moodOverride: moodOverride
        )
    }

    // MARK: - Ambient generation path

    private static func generateAmbient(
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        forceBassRuleID:      String? = nil,
        forceArpRuleID:       String? = nil,
        forcePadsRuleID:      String? = nil,
        forceLeadRuleID:      String? = nil,
        forceTexRuleID:       String? = nil,
        forcePercussionStyle: PercussionStyle? = nil,
        forceBridge:          Bool    = false,
        useBrushKit:          Bool    = false
    ) -> SongState {
        var rng = SeededRNG(seed: seed)

        // Step 1 — Ambient musical frame (tempo, key, mood, loop lengths, prog family)
        let (frame, percStylePicked, ambientProgFamily, loopLengths) = AmbientMusicalFrameGenerator.generate(
            rng: &rng, keyOverride: keyOverride, tempoOverride: tempoOverride,
            moodOverride: moodOverride
        )
        let percussionStyle = forcePercussionStyle ?? percStylePicked

        // Step 2 — Ambient structure (intro/body/outro + chord plan)
        let structure = AmbientStructureGenerator.generate(
            frame: frame, ambientProgFamily: ambientProgFamily, rng: &rng
        )

        // Step 3 — Tonal governance map (same builder as Motorik/Kosmic)
        let tonalMap = TonalGovernanceBuilder.build(frame: frame, structure: structure)

        // Steps 4–9 — Per-track loops then tile to full song length
        var trackEvents = [[MIDIEvent]](repeating: [], count: kTrackCount)

        var padsRNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackPads))
        var bassRNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackBass))
        var drumRNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackDrums))
        var lead1RNG = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead1))
        var lead2RNG = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead2))
        var rythmRNG = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackRhythm))
        var texRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackTexture))

        // Dropout zone coordinator (Option C) — one 8-bar rest zone per pitched track, staggered
        // across the body so no two tracks drop out at the same time. Guarantees no track is
        // active in 100% of 4-bar windows (RELENTLESS) regardless of loop density.
        let bodyStart  = structure.introSection?.endBar   ?? 0
        let bodyEnd    = structure.outroSection?.startBar ?? frame.totalBars
        let bodyLength = bodyEnd - bodyStart
        var dropoutZones: [Int: Set<Int>] = [:]
        if bodyLength >= 40 {
            var dropRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: 98))
            let zoneLen   = 8   // bars — always 8 for predictable analysis
            let nTracks   = 5
            let segment   = Swift.max(zoneLen + 4, bodyLength / nTracks)
            // Shuffle order so dropout positions rotate across different songs
            var order = [kTrackPads, kTrackBass, kTrackLead1, kTrackRhythm, kTrackTexture]
            for i in stride(from: order.count - 1, through: 1, by: -1) {
                order.swapAt(i, dropRNG.nextInt(upperBound: i + 1))
            }
            for (i, trackIdx) in order.enumerated() {
                let segStart  = bodyStart + i * segment
                let segEnd    = Swift.min(segStart + segment, bodyEnd - zoneLen)
                guard segEnd > segStart else { continue }
                let rawStart  = segStart + dropRNG.nextInt(upperBound: Swift.max(1, segEnd - segStart))
                let zoneStart = (rawStart / 4) * 4   // snap to 4-bar boundary
                let zoneEnd   = Swift.min(zoneStart + zoneLen, bodyEnd)
                dropoutZones[trackIdx] = Set(zoneStart..<zoneEnd)
            }
        }

        // Pads
        var padRules: Set<String> = []
        let padLoop = AmbientPadsGenerator.generate(frame: frame, tonalMap: tonalMap,
                                                     loopBars: loopLengths.pads, rng: &padsRNG,
                                                     usedRuleIDs: &padRules,
                                                     forceRuleID: forcePadsRuleID)
        trackEvents[kTrackPads] = AmbientLoopTiler.tile(events: padLoop,
                                                         loopBars: loopLengths.pads,
                                                         totalBars: frame.totalBars,
                                                         silentBars: dropoutZones[kTrackPads] ?? [])

        // Bass — rhythm template tiled at loopLengths.bass; pitch resolved from tonal map per note
        var bassRules: Set<String> = []
        trackEvents[kTrackBass] = AmbientBassGenerator.generate(frame: frame, tonalMap: tonalMap,
                                                                  rng: &bassRNG,
                                                                  loopBars: loopLengths.bass,
                                                                  usedRuleIDs: &bassRules,
                                                                  forceRuleID: forceBassRuleID,
                                                                  silentBars: dropoutZones[kTrackBass] ?? [])

        // Drums (stochastic full-song — no tiling)
        var drumRules: Set<String> = []
        trackEvents[kTrackDrums] = AmbientDrumGenerator.generate(frame: frame, structure: structure,
                                                                   percussionStyle: percussionStyle,
                                                                   rng: &drumRNG, usedRuleIDs: &drumRules,
                                                                   useBrushKit: useBrushKit)

        // Lead 1 — if silent and pads are non-empty, force a second attempt with a real rule
        var lead1Rules: Set<String> = []
        var lead1Loop = AmbientLeadGenerator.generateLead1(frame: frame, tonalMap: tonalMap,
                                                            loopBars: loopLengths.lead1, rng: &lead1RNG,
                                                            usedRuleIDs: &lead1Rules,
                                                            forceRuleID: forceLeadRuleID,
                                                            structure: structure)
        if lead1Loop.isEmpty && !padLoop.isEmpty && forceLeadRuleID == nil {
            lead1Rules.removeAll()
            lead1Loop = AmbientLeadGenerator.generateLead1(frame: frame, tonalMap: tonalMap,
                                                            loopBars: loopLengths.lead1, rng: &lead1RNG,
                                                            usedRuleIDs: &lead1Rules,
                                                            forceNonSilent: true,
                                                            structure: structure)
        }
        // AMB-LEAD-009 and AMB-LEAD-010 return full-song events — skip the loop tiler for those.
        // Section solos are already sparse by design so dropout zones don't apply to them.
        // AMB-LEAD-001 (floating tone) and AMB-LEAD-002 (echo phrase) are minimalist by design
        // (1–3 notes per loop). Applying an 8-bar dropout zone on top makes them nearly inaudible;
        // skip the dropout zone for these rules so their intended sparsity is preserved intact.
        let isAmbSectionSolo = lead1Rules.contains("AMB-LEAD-009") || lead1Rules.contains("AMB-LEAD-010")
        let isMinimalistLead = lead1Rules.contains("AMB-LEAD-001") || lead1Rules.contains("AMB-LEAD-002")
        if isAmbSectionSolo {
            // Section solos return full-song events — skip the loop tiler entirely.
            trackEvents[kTrackLead1] = lead1Loop
        } else if isMinimalistLead {
            // Floating tone / echo phrase are already very sparse — skip the dropout zone
            // so the handful of notes they produce aren't further suppressed.
            trackEvents[kTrackLead1] = AmbientLoopTiler.tile(events: lead1Loop,
                                                              loopBars: loopLengths.lead1,
                                                              totalBars: frame.totalBars)
        } else {
            trackEvents[kTrackLead1] = AmbientLoopTiler.tile(events: lead1Loop,
                                                              loopBars: loopLengths.lead1,
                                                              totalBars: frame.totalBars,
                                                              silentBars: dropoutZones[kTrackLead1] ?? [])
        }

        // Lead 2 (AMB-LEAD-005: sparse tonal cell from Lead 1 pitch classes) — no dropout zone; already very sparse
        var lead2Rules: Set<String> = []
        let lead2Loop = AmbientLeadGenerator.generateLead2(frame: frame, tonalMap: tonalMap,
                                                            lead1Events: lead1Loop,
                                                            loopBars: loopLengths.lead2, rng: &lead2RNG,
                                                            usedRuleIDs: &lead2Rules)
        trackEvents[kTrackLead2] = AmbientLoopTiler.tile(events: lead2Loop,
                                                          loopBars: loopLengths.lead2,
                                                          totalBars: frame.totalBars)

        // Rhythm
        var rhythmRules: Set<String> = []
        let rythmLoop = AmbientRhythmGenerator.generate(frame: frame, tonalMap: tonalMap,
                                                         loopBars: loopLengths.rhythm, rng: &rythmRNG,
                                                         usedRuleIDs: &rhythmRules,
                                                         forceRuleID: forceArpRuleID)
        trackEvents[kTrackRhythm] = AmbientLoopTiler.tile(events: rythmLoop,
                                                            loopBars: loopLengths.rhythm,
                                                            totalBars: frame.totalBars,
                                                            silentBars: dropoutZones[kTrackRhythm] ?? [])

        // Ambient audio texture: when drums are absent, replace the MIDI texture track with an
        // audio file. No effects applied — raw ambient sound fills the texture slot.
        let ambientAudioFiles = ["light_rain.m4a", "rain-and-thunder.m4a", "ocean_waves.m4a",
                                  "zen-bells.m4a", "wind-stoorm.m4a", "desert-winds.m4a"]
        let ambientAudioTexture: String? = (percussionStyle == .absent)
            ? ambientAudioFiles[texRNG.nextInt(upperBound: ambientAudioFiles.count)] : nil
        let ambientAudioTextureOffset = ambientAudioTexture != nil ? [0, 15, 30, 45][texRNG.nextInt(upperBound: 4)] : 0

        // Texture
        var texRules: Set<String> = []
        if let audioFile = ambientAudioTexture {
            // Audio texture replaces MIDI — leave track empty, mark with a per-file rule ID for the log.
            switch audioFile {
            case "light_rain.m4a":   texRules.insert("AMB-TEXT-003")
            case "rain-and-thunder.m4a":   texRules.insert("AMB-TEXT-005")
            case "ocean_waves.m4a":  texRules.insert("AMB-TEXT-006")
            case "zen-bells.m4a":    texRules.insert("AMB-TEXT-007")
            case "wind-stoorm.m4a":  texRules.insert("AMB-TEXT-008")
            case "desert-winds.m4a": texRules.insert("AMB-TEXT-009")
            default:                 texRules.insert("AMB-TEXT-003")
            }
        } else {
            let texLoop = AmbientTextureGenerator.generate(frame: frame, tonalMap: tonalMap,
                                                            loopBars: loopLengths.texture, rng: &texRNG,
                                                            usedRuleIDs: &texRules)
            trackEvents[kTrackTexture] = AmbientLoopTiler.tile(events: texLoop,
                                                                 loopBars: loopLengths.texture,
                                                                 totalBars: frame.totalBars,
                                                                 silentBars: dropoutZones[kTrackTexture] ?? [])
        }

        // Hollow guard A: if bass, rhythm, and texture are all absent (and no audio texture),
        // the song will sound hollow — pads re-attack every 2–4 bars, leaving long empty stretches.
        // Force texture non-silent to provide movement regardless of drum presence.
        if ambientAudioTexture == nil
            && trackEvents[kTrackBass].isEmpty
            && trackEvents[kTrackRhythm].isEmpty
            && trackEvents[kTrackTexture].isEmpty {
            var texRulesH: Set<String> = []
            let texLoopH = AmbientTextureGenerator.generate(frame: frame, tonalMap: tonalMap,
                                                             loopBars: loopLengths.texture, rng: &texRNG,
                                                             usedRuleIDs: &texRulesH,
                                                             forceNonSilent: true)
            trackEvents[kTrackTexture] = AmbientLoopTiler.tile(events: texLoopH,
                                                                loopBars: loopLengths.texture,
                                                                totalBars: frame.totalBars,
                                                                silentBars: dropoutZones[kTrackTexture] ?? [])
            texRules.formUnion(texRulesH)
        }

        // Hollow guard B: rhythm and texture both absent — ensure bass is present.
        if trackEvents[kTrackRhythm].isEmpty
            && trackEvents[kTrackTexture].isEmpty
            && trackEvents[kTrackBass].isEmpty {
            var bassRulesH: Set<String> = []
            let bassLoopH = AmbientBassGenerator.generate(frame: frame, tonalMap: tonalMap,
                                                           rng: &bassRNG,
                                                           loopBars: loopLengths.bass,
                                                           usedRuleIDs: &bassRulesH,
                                                           forceRuleID: "AMB-BASS-001",
                                                           silentBars: dropoutZones[kTrackBass] ?? [])
            trackEvents[kTrackBass] = AmbientLoopTiler.tile(events: bassLoopH,
                                                              loopBars: loopLengths.bass,
                                                              totalBars: frame.totalBars,
                                                              silentBars: dropoutZones[kTrackBass] ?? [])
            bassRules.formUnion(bassRulesH)
        }

        // Hollow guard C: section solos (009/010) only play in two narrow 8-bar windows —
        // the rest of the song is nearly silent without rhythmic support.
        // If bass and rhythm are both absent and the lead is a section solo, force sparse arpeggio.
        if isAmbSectionSolo
            && trackEvents[kTrackBass].isEmpty
            && trackEvents[kTrackRhythm].isEmpty {
            rhythmRules.removeAll()
            let rythmLoopH = AmbientRhythmGenerator.generate(frame: frame, tonalMap: tonalMap,
                                                               loopBars: loopLengths.rhythm, rng: &rythmRNG,
                                                               usedRuleIDs: &rhythmRules,
                                                               forceRuleID: "AMB-RTHM-002")
            trackEvents[kTrackRhythm] = AmbientLoopTiler.tile(events: rythmLoopH,
                                                                loopBars: loopLengths.rhythm,
                                                                totalBars: frame.totalBars,
                                                                silentBars: dropoutZones[kTrackRhythm] ?? [])
        }

        // Plan J: Strip Rhythm and Texture events from intro and outro bars.
        // Lets those tracks emerge with the body rather than starting from bar 1.
        let introEndStep   = (structure.introSection?.endBar   ?? 0) * 16
        let outroStartStep = (structure.outroSection?.startBar ?? frame.totalBars) * 16
        if introEndStep > 0 {
            trackEvents[kTrackRhythm]  = trackEvents[kTrackRhythm].filter  { $0.stepIndex >= introEndStep }
            trackEvents[kTrackTexture] = trackEvents[kTrackTexture].filter { $0.stepIndex >= introEndStep }
        }
        if outroStartStep < frame.totalBars * 16 {
            trackEvents[kTrackRhythm]  = trackEvents[kTrackRhythm].filter  { $0.stepIndex < outroStartStep }
            trackEvents[kTrackTexture] = trackEvents[kTrackTexture].filter { $0.stepIndex < outroStartStep }
        }

        // Staggered entry/exit: when Bass, Pads, and Rhythm are all active, silence one of them
        // for the first 12 and last 12 bars of the song. The chosen instrument enters late and
        // exits early, creating a natural arrangement swell and avoiding a wall-of-sound opening.
        if frame.totalBars >= 32,
           !trackEvents[kTrackBass].isEmpty,
           !trackEvents[kTrackPads].isEmpty,
           !trackEvents[kTrackRhythm].isEmpty {
            var arrangeRNG = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: 97))
            let candidates  = [kTrackBass, kTrackPads, kTrackRhythm]
            let chosen      = candidates[arrangeRNG.nextInt(upperBound: candidates.count)]
            let headEndStep  = 12 * 16
            let tailStartStep = (frame.totalBars - 12) * 16
            trackEvents[chosen] = trackEvents[chosen].filter {
                $0.stepIndex >= headEndStep && $0.stepIndex < tailStartStep
            }
        }

        // Texture always enters at bar 16 and exits 16 bars before the end.
        // Creates a slow reveal — texture emerges from the sonic field rather than being present from the start.
        if frame.totalBars >= 40, !trackEvents[kTrackTexture].isEmpty {
            let texHeadEnd   = 16 * 16
            let texTailStart = (frame.totalBars - 16) * 16
            trackEvents[kTrackTexture] = trackEvents[kTrackTexture].filter {
                $0.stepIndex >= texHeadEnd && $0.stepIndex < texTailStart
            }
        }

        // Plan H: Coordinated breath silence — 2–4 bars of stillness in Pads + Lead 1 mid-body (40% chance).
        // Bass and texture continue through it. Creates a moment of arrival when pads return.
        var breathSilenceBar: Int? = nil
        var breathSilenceLenBars: Int = 0
        if let body = structure.bodySections.first, body.lengthBars >= 8, rng.nextDouble() < 0.40 {
            let silenceLenBars = 2 + rng.nextInt(upperBound: 3)   // 2–4 bars
            let safeStart = body.startBar + 4
            let safeEnd   = body.endBar - silenceLenBars - 4
            if safeEnd > safeStart {
                let silenceBar       = safeStart + rng.nextInt(upperBound: safeEnd - safeStart)
                let silenceStartStep = silenceBar * 16
                let silenceEndStep   = silenceStartStep + silenceLenBars * 16
                trackEvents[kTrackPads]  = clearStepRange(trackEvents[kTrackPads],
                                                           from: silenceStartStep, to: silenceEndStep)
                // Section solos (009/010) play in fixed windows — never suppress them mid-song.
                if !isAmbSectionSolo {
                    trackEvents[kTrackLead1] = clearStepRange(trackEvents[kTrackLead1],
                                                               from: silenceStartStep, to: silenceEndStep)
                }
                breathSilenceBar     = silenceBar
                breathSilenceLenBars = silenceLenBars
            }
        }

        // Plan G: Dynamic arc — scale velocity for Pads and Lead 1 across the song.
        // Intro fades up (72%→100%), body stays full, outro fades down (100%→72%).
        let totalSteps  = frame.totalBars * 16
        let introStepsD = Double((structure.introSection?.lengthBars ?? 0) * 16)
        let outroStepsD = Double((structure.outroSection?.lengthBars ?? 0) * 16)
        let arcMin: Double = 0.72
        func dynamicFactor(step: Int) -> Double {
            let s = Double(step)
            let total = Double(totalSteps)
            if introStepsD > 0 && s < introStepsD {
                return arcMin + (1.0 - arcMin) * (s / introStepsD)
            }
            if outroStepsD > 0 && s >= total - outroStepsD {
                return 1.0 - (1.0 - arcMin) * ((s - (total - outroStepsD)) / outroStepsD)
            }
            return 1.0
        }
        for track in [kTrackPads, kTrackLead1] {
            trackEvents[track] = trackEvents[track].map { ev in
                let scaled = Int((Double(ev.velocity) * dynamicFactor(step: ev.stepIndex)).rounded())
                let vel = UInt8(Swift.max(20, Swift.min(110, scaled)))
                return MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                 velocity: vel, durationSteps: ev.durationSteps)
            }
        }

        // Post-processing: harmonic filter only (no Density/Arrangement/PatternEvolver/DrumVariation)
        trackEvents = HarmonicFilter.apply(trackEvents: trackEvents, frame: frame, structure: structure)

        // X-Files whistle — injected AFTER harmonic filter so the melody is not scale-snapped.
        // 5% chance (75% in test mode) of appearing once in the 30–60 second window.
        // Plays once, starting at bar 2 of the block; phrase spills into bar 3 (bars 1 and 4 silent).
        var ambientXFilesBars: [Int] = []
        let xFilesProb = 0.05
        if lead1RNG.nextDouble() < xFilesProb {
            let stepsPerSec = (Double(frame.tempo) / 60.0) * 4.0
            let bar30 = max(0, Int(stepsPerSec * 30.0) / 16)
            let bar60 = min(frame.totalBars - 4, Int(stepsPerSec * 60.0) / 16)
            if bar30 <= bar60 {
                let candidates = Array(bar30...bar60)
                let blockStart     = candidates[lead1RNG.nextInt(upperBound: candidates.count)]
                let blockStartStep = blockStart * 16
                let blockEndStep   = blockStartStep + 64   // 4 bars × 16 steps
                // Clear Lead 1 and Lead 2 in the 4-bar block, truncating any bleed-in notes.
                trackEvents[kTrackLead1] = clearStepRange(trackEvents[kTrackLead1],
                                                           from: blockStartStep, to: blockEndStep)
                trackEvents[kTrackLead2] = clearStepRange(trackEvents[kTrackLead2],
                                                           from: blockStartStep, to: blockEndStep)
                // Play whistle once starting at bar 2 of the block — phrase naturally spills into bar 3.
                let whistleEvents = KosmicLeadGenerator.xFilesWhistleBar(
                    bar: blockStart + 1, frame: frame, tonalMap: tonalMap, rng: &lead1RNG)
                trackEvents[kTrackLead1] = (trackEvents[kTrackLead1] + whistleEvents)
                    .sorted { $0.stepIndex < $1.stepIndex }
                lead1Rules.insert("AMB-XFILES-001")
                ambientXFilesBars = [blockStart + 1]
            }
        }

        // Void guard: prevent extended stretches with no pitched instruments.
        // After all processing, scan body bars for runs of consecutive bars where no pitched
        // track has any note-on. Fill each void with a soft Pads reattack at the midpoint.
        // Threshold: 4+ bars when drums are absent (every silence is audible),
        //            6+ bars when drums are present (drums provide rhythmic continuity).
        if !trackEvents[kTrackPads].isEmpty {
            let vBodyStart    = structure.introSection?.endBar   ?? 0
            let vBodyEnd      = structure.outroSection?.startBar ?? frame.totalBars
            let drumsActive   = !trackEvents[kTrackDrums].isEmpty
            let voidThreshold = drumsActive ? 3 : 2
            let pitchedTracks = [kTrackLead1, kTrackLead2, kTrackPads,
                                  kTrackBass, kTrackRhythm, kTrackTexture]
            var barsWithPitch = Set<Int>()
            for track in pitchedTracks {
                for ev in trackEvents[track] {
                    let bar = ev.stepIndex / 16
                    if bar >= vBodyStart && bar < vBodyEnd { barsWithPitch.insert(bar) }
                }
            }
            var runStart: Int? = nil
            var voids: [(start: Int, length: Int)] = []
            for bar in vBodyStart..<vBodyEnd {
                if !barsWithPitch.contains(bar) {
                    if runStart == nil { runStart = bar }
                } else if let rs = runStart {
                    if bar - rs >= voidThreshold { voids.append((rs, bar - rs)) }
                    runStart = nil
                }
            }
            if let rs = runStart, vBodyEnd - rs >= voidThreshold { voids.append((rs, vBodyEnd - rs)) }

            for void in voids {
                let fillBar  = void.start + void.length / 2
                let fillStep = fillBar * 16
                guard let entry = tonalMap.entry(atBar: fillBar) else { continue }
                let pool = notesInRegister(pitchClasses: entry.chordWindow.chordTones,
                                           low: kRegisterBounds[kTrackPads]!.low,
                                           high: kRegisterBounds[kTrackPads]!.high)
                guard !pool.isEmpty else { continue }
                // Prefer a pitch already used by Pads nearby for tonal continuity
                let refNote = trackEvents[kTrackPads]
                    .min(by: { abs($0.stepIndex - fillStep) < abs($1.stepIndex - fillStep) })
                    .map { $0.note } ?? pool[pool.count / 2]
                trackEvents[kTrackPads].append(
                    MIDIEvent(stepIndex: fillStep, note: refNote, velocity: 40, durationSteps: 20))
                trackEvents[kTrackPads].sort { $0.stepIndex < $1.stepIndex }
            }
        }

        // Title
        let title = AmbientTitleGenerator.generate(rng: &rng)

        // Song form (Ambient is always single-section evolving)
        let form = SongForm.singleA

        // Build Ambient generation log
        let log = buildAmbientLog(
            title: title, frame: frame, structure: structure, loopLengths: loopLengths,
            percussionStyle: percussionStyle, ambientProgFamily: ambientProgFamily,
            drumRules: drumRules, bassRules: bassRules,
            padRules: padRules, lead1Rules: lead1Rules, lead2Rules: lead2Rules,
            rhythmRules: rhythmRules, texRules: texRules,
            forceBassRuleID: forceBassRuleID, forceArpRuleID: forceArpRuleID,
            forceLeadRuleID: forceLeadRuleID, forcePercussionStyle: forcePercussionStyle
        )

        let stepAnnotations = buildStepAnnotations(structure: structure, trackEvents: trackEvents,
                                                    frame: frame, xFilesBars: ambientXFilesBars,
                                                    breathSilenceBar: breathSilenceBar,
                                                    breathSilenceLenBars: breathSilenceLenBars,
                                                    isAmbient: true, includeDrumFills: false)

        // Derive the 4-bar block step range for PlaybackEngine delay muting.
        let ambientXFilesBlockRange: Range<Int>? = ambientXFilesBars.first.map {
            let s = ($0 - 1) * 16   // blockStart = firstXFilesBar - 1
            return s ..< s + 64     // 4 bars × 16 steps
        }

        var forced: [String: String] = [:]
        if let r = forceBassRuleID  { forced["Bass"]   = r }
        if let r = forceArpRuleID   { forced["Rhythm"] = r }
        if let r = forcePadsRuleID  { forced["Pads"]   = r }
        if let r = forceLeadRuleID  { forced["Lead"]   = r }
        if let r = forceTexRuleID   { forced["Tex"]    = r }

        return SongState(
            frame: frame, structure: structure, tonalMap: tonalMap,
            trackEvents: trackEvents, globalSeed: seed, trackOverrides: [:],
            title: title, form: form, style: .ambient,
            percussionStyle: percussionStyle, kosmicProgFamily: .static_drone,
            generationLog: log, stepAnnotations: stepAnnotations,
            ambientProgFamily: ambientProgFamily, ambientLoopLengths: loopLengths,
            ambientXFilesBlockRange: ambientXFilesBlockRange,
            ambientUseBrushKit: useBrushKit,
            ambientAudioTexture: ambientAudioTexture,
            ambientAudioTextureOffset: ambientAudioTextureOffset,
            forcedRules: forced,
            keyOverride: keyOverride,
            tempoOverride: tempoOverride,
            moodOverride: moodOverride
        )
    }

    // MARK: - Per-track regenerate

    /// Regenerates a single track without touching any other track or the global seed.
    /// Appends regen log entries so the status box reflects the new rules used.
    static func regenerateTrack(_ trackIndex: Int, songState: SongState, overrideSeed: UInt64? = nil, passBodyBars: Int? = nil) -> SongState {
        let newTrackSeed = overrideSeed ?? UInt64.random(in: .min ... .max)
        var rng = SeededRNG(seed: newTrackSeed)
        var usedRules: Set<String> = []

        var events: [MIDIEvent]
        let isKosmic  = songState.style == .kosmic
        let isAmbient = songState.style == .ambient
        let isChill   = songState.style == .chill
        let ambLoopLengths = songState.ambientLoopLengths
        // For Ambient texture regen: may switch between audio and MIDI texture.
        var regenAmbientAudioTexture: String? = songState.ambientAudioTexture
        var regenAmbientAudioOffset:  Int     = songState.ambientAudioTextureOffset
        var ambientAudioTextureChanged = false
        switch trackIndex {
        case kTrackDrums:
            if isAmbient {
                let regenPercStyle = AmbientMusicalFrameGenerator.pickPercussionStyle(rng: &rng)
                events = AmbientDrumGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    percussionStyle: regenPercStyle,
                    rng: &rng, usedRuleIDs: &usedRules,
                    useBrushKit: songState.ambientUseBrushKit)
            } else if isKosmic {
                let regenPercStyle = KosmicMusicalFrameGenerator.pickPercussionStyle(
                    tempo: songState.frame.tempo, rng: &rng)
                events = KosmicDrumGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    percussionStyle: regenPercStyle,
                    rng: &rng, usedRuleIDs: &usedRules)
            } else if isChill {
                var ignoredFills: [Int] = []
                events = ChillDrumGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    beatStyle: songState.chillBeatStyle,
                    breakdownStyle: songState.chillBreakdownStyle,
                    rng: &rng, usedRuleIDs: &usedRules, fillBars: &ignoredFills)
            } else {
                let rawDrum = DrumGenerator.generate(frame: songState.frame, structure: songState.structure, rng: &rng, usedRuleIDs: &usedRules)
                var scratch = songState.trackEvents
                scratch[kTrackDrums] = rawDrum
                events = DrumVariationEngine.apply(trackEvents: scratch, frame: songState.frame, structure: songState.structure, seed: newTrackSeed)[kTrackDrums]
            }
        case kTrackBass:
            if isAmbient {
                events = AmbientBassGenerator.generate(
                    frame: songState.frame, tonalMap: songState.tonalMap,
                    rng: &rng, loopBars: songState.ambientLoopLengths?.bass ?? 11,
                    usedRuleIDs: &usedRules)
            } else if isKosmic {
                var ignored: [Int] = []
                events = KosmicBassGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules,
                    bassEvolutionBars: &ignored)
            } else if isChill {
                events = ChillBassGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    chillProgFamily: songState.chillProgFamily,
                    beatStyle: songState.chillBeatStyle,
                    breakdownStyle: songState.chillBreakdownStyle,
                    rng: &rng, usedRuleIDs: &usedRules)
            } else {
                let rawBass = BassGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
                var scratch = songState.trackEvents
                scratch[kTrackBass] = rawBass
                scratch = PatternEvolver.apply(trackEvents: scratch, frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, seed: newTrackSeed)
                scratch = DrumVariationEngine.lockBassToExistingFills(trackEvents: scratch, frame: songState.frame, structure: songState.structure, seed: songState.globalSeed)
                events = scratch[kTrackBass]
            }
        case kTrackPads:
            if isAmbient {
                let loopBars = ambLoopLengths?.pads ?? 8
                let loop = AmbientPadsGenerator.generate(
                    frame: songState.frame, tonalMap: songState.tonalMap,
                    loopBars: loopBars, rng: &rng, usedRuleIDs: &usedRules)
                events = AmbientLoopTiler.tile(events: loop, loopBars: loopBars, totalBars: songState.frame.totalBars)
            } else if isKosmic {
                events = KosmicPadsGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, kosmicProgFamily: songState.kosmicProgFamily,
                    rng: &rng, usedRuleIDs: &usedRules)
            } else if isChill {
                events = ChillPadsGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    breakdownStyle: songState.chillBreakdownStyle,
                    rng: &rng, usedRuleIDs: &usedRules)
            } else {
                events = PadsGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            }
        case kTrackLead1:
            if isAmbient {
                let loopBars = ambLoopLengths?.lead1 ?? 11
                var regenRules: Set<String> = []
                let loop = AmbientLeadGenerator.generateLead1(
                    frame: songState.frame, tonalMap: songState.tonalMap,
                    loopBars: loopBars, rng: &rng, usedRuleIDs: &regenRules,
                    structure: songState.structure)
                let isSectionSolo = regenRules.contains("AMB-LEAD-009") || regenRules.contains("AMB-LEAD-010")
                usedRules.formUnion(regenRules)
                events = isSectionSolo ? loop
                    : AmbientLoopTiler.tile(events: loop, loopBars: loopBars, totalBars: songState.frame.totalBars)
            } else if isKosmic {
                var discardedBaseRule = ""
                var discardedXFiles: [Int] = []
                events = KosmicLeadGenerator.generateLead1(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules,
                    lead1BaseRule: &discardedBaseRule, xFilesBars: &discardedXFiles)
            } else if isChill {
                (events, _, _) = ChillLeadGenerator.generateLead1(
                    frame: songState.frame, structure: songState.structure,
                    leadInstrument: songState.chillLeadInstrument,
                    beatStyle: songState.chillBeatStyle,
                    breakdownStyle: songState.chillBreakdownStyle,
                    rng: &rng, usedRuleIDs: &usedRules)
            } else {
                (events, _) = LeadGenerator.generateLead1(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules, passBodyBars: passBodyBars)
            }
        case kTrackLead2:
            if isAmbient {
                let loopBars = ambLoopLengths?.lead2 ?? 13
                let lead1Loop = Array(songState.trackEvents[kTrackLead1].filter { $0.stepIndex < loopBars * 16 })
                let loop = AmbientLeadGenerator.generateLead2(
                    frame: songState.frame, tonalMap: songState.tonalMap,
                    lead1Events: lead1Loop, loopBars: loopBars,
                    rng: &rng, usedRuleIDs: &usedRules)
                events = AmbientLoopTiler.tile(events: loop, loopBars: loopBars, totalBars: songState.frame.totalBars)
            } else if isKosmic {
                events = KosmicLeadGenerator.generateLead2(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, lead1Events: songState.trackEvents[kTrackLead1],
                    rng: &rng, usedRuleIDs: &usedRules)
            } else if isChill {
                // Derive lead1Onsets from current Lead 1 events so Lead 2 avoids overlapping
                let lead1Evts = songState.trackEvents[kTrackLead1]
                let barsWithLead1 = Set(lead1Evts.map { $0.stepIndex / 16 }).sorted()
                var lead1Onsets: [(startBar: Int, endBar: Int)] = []
                var onsetStart: Int? = nil
                var onsetPrev  = -2
                for bar in barsWithLead1 {
                    if bar == onsetPrev + 1 {
                        onsetPrev = bar
                    } else {
                        if let s = onsetStart { lead1Onsets.append((s, onsetPrev + 1)) }
                        onsetStart = bar; onsetPrev = bar
                    }
                }
                if let s = onsetStart { lead1Onsets.append((s, onsetPrev + 1)) }
                events = ChillLeadGenerator.generateLead2(
                    frame: songState.frame, structure: songState.structure,
                    lead1Instrument: songState.chillLeadInstrument,
                    lead1Onsets: lead1Onsets,
                    rng: &rng, usedRuleIDs: &usedRules).events
            } else {
                events = LeadGenerator.generateLead2(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, lead1Events: songState.trackEvents[kTrackLead1], rng: &rng, usedRuleIDs: &usedRules)
            }
        case kTrackRhythm:
            if isAmbient {
                let loopBars = ambLoopLengths?.rhythm ?? 5
                let loop = AmbientRhythmGenerator.generate(
                    frame: songState.frame, tonalMap: songState.tonalMap,
                    loopBars: loopBars, rng: &rng, usedRuleIDs: &usedRules)
                events = AmbientLoopTiler.tile(events: loop, loopBars: loopBars, totalBars: songState.frame.totalBars)
            } else if isKosmic {
                events = KosmicArpeggioGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            } else if isChill {
                events = ChillRhythmGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    mood: songState.frame.mood,
                    beatStyle: songState.chillBeatStyle,
                    breakdownStyle: songState.chillBreakdownStyle,
                    rng: &rng, usedRuleIDs: &usedRules)
            } else {
                events = RhythmGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            }
        case kTrackTexture:
            if isAmbient {
                let loopBars = ambLoopLengths?.texture ?? 7
                let ambientFiles = ["light_rain.m4a", "rain-and-thunder.m4a", "ocean_waves.m4a",
                                    "zen-bells.m4a", "wind-stoorm.m4a", "desert-winds.m4a"]
                ambientAudioTextureChanged = true
                if rng.nextDouble() < 0.45 {
                    // Audio texture path (45%)
                    let file = ambientFiles[rng.nextInt(upperBound: ambientFiles.count)]
                    let offset = [0, 15, 30, 45][rng.nextInt(upperBound: 4)]
                    events = []
                    regenAmbientAudioTexture = file
                    regenAmbientAudioOffset  = offset
                    switch file {
                    case "light_rain.m4a":   usedRules.insert("AMB-TEXT-003")
                    case "rain-and-thunder.m4a":   usedRules.insert("AMB-TEXT-005")
                    case "ocean_waves.m4a":  usedRules.insert("AMB-TEXT-006")
                    case "zen-bells.m4a":    usedRules.insert("AMB-TEXT-007")
                    case "wind-stoorm.m4a":  usedRules.insert("AMB-TEXT-008")
                    case "desert-winds.m4a": usedRules.insert("AMB-TEXT-009")
                    default:                usedRules.insert("AMB-TEXT-003")
                    }
                } else {
                    // MIDI texture path (55%)
                    let loop = AmbientTextureGenerator.generate(
                        frame: songState.frame, tonalMap: songState.tonalMap,
                        loopBars: loopBars, rng: &rng, usedRuleIDs: &usedRules)
                    events = AmbientLoopTiler.tile(events: loop, loopBars: loopBars, totalBars: songState.frame.totalBars)
                    regenAmbientAudioTexture = nil
                    regenAmbientAudioOffset  = 0
                }
            } else if isKosmic {
                events = KosmicTextureGenerator.generate(
                    frame: songState.frame, structure: songState.structure,
                    tonalMap: songState.tonalMap, rng: &rng, usedRuleIDs: &usedRules)
            } else if isChill {
                // Chill texture is audio-only; regen is a no-op for the MIDI track.
                events = []
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
        if ambientAudioTextureChanged {
            updated = updated.withAmbientAudioTexture(regenAmbientAudioTexture, offset: regenAmbientAudioOffset)
        }
        updated.trackOverrides[trackIndex] = newTrackSeed
        return updated
    }

    /// Route a ruleID to the correct description function by trackIndex.
    private static func ruleDescription(_ ruleID: String, trackIndex: Int) -> String {
        if ruleID.hasPrefix("AMB-") { return ambientRuleDescription(ruleID) }
        if ruleID.hasPrefix("KOS-RTHM-") { return kosmicRthmRuleDescription(ruleID) }
        if ruleID.hasPrefix("CHL-") { return chillRuleDescription(ruleID) }
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
        texRules: Set<String>
    ) -> [GenerationLogEntry] {
        var log: [GenerationLogEntry] = []

        // Song title
        log.append(GenerationLogEntry(tag: "SONG", description: title, isTitle: true))

        // Structure form rule
        log.append(GenerationLogEntry(tag: "Form", description: formLabel(form)))

        // Chord progression — key/mode + progression family
        let progLabel = progressionFamilyLabel(frame.progressionFamily)
        log.append(GenerationLogEntry(tag: "Chords", description: "\(frame.key) \(frame.mode.rawValue) \(progLabel)"))

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
            log.append(GenerationLogEntry(tag: baseTag, description: bassRuleDescription(ruleID)))
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
            log.append(GenerationLogEntry(tag: "MOT-RTHM-001",
                description: "8th-note ostinato, alternating root/fifth"))
        }

        // Texture
        for ruleID in texRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: textureRuleDescription(ruleID)))
        }
        if texRules.isEmpty {
            log.append(GenerationLogEntry(tag: "MOT-TEXT-001",
                description: "Cluster sparse"))
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
        case .singleA:    return "Steady A section"
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
        case .coldStop: return "cold stop"
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
        case .static_tonic:             return "Static tonic I"
        case .two_chord_I_bVII:         return "Two chord I ♭VII"
        case .minor_loop_i_VII:         return "Minor loop i VII"
        case .minor_loop_i_VI:          return "Minor loop i VI"
        case .modal_cadence_bVI_bVII_I: return "Modal rock ♭VI ♭VII I"
        }
    }

    private static func drumRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-DRUM-001": return "Classic Motorik Apache beat"
        case "MOT-DRUM-002": return "Open Pocket beat"
        case "MOT-DRUM-003": return "Dinger groove"
        case "MOT-DRUM-004": return "Mostly Motorik"
        // Kosmic drum rules (shared lookup for regen log)
        case "KOS-DRUM-001": return "Minimal JMJ Pop"
        case "KOS-DRUM-002": return "Basic Channel minimal dub"
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
        case "MOT-BASS-004": return "Neu! Hallogallo lock"
        case "MOT-BASS-005": return "McCartney drive"
        case "MOT-BASS-006": return "LA Woman Sustain"
        case "MOT-BASS-007": return "Hook Ascent"
        case "MOT-BASS-008": return "Moroder Pulse"
        case "MOT-BASS-009": return "Vitamin Hook"
        case "MOT-BASS-010": return "Quo Arc"
        case "MOT-BASS-011": return "Quo Drive"
        case "MOT-BASS-012": return "Moroder Chase"
        case "MOT-BASS-013": return "Kraftwerk robotic bass"
        case "MOT-BASS-014": return "McCartney melodic drive"
        case "MOT-BASS-015": return "Kraftwerk driving bass"
        case "BASS-EVOL":    return "Evolving pattern"
        case "BASS-DEVOL":   return "Devolving pattern"
        // Kosmic bass rules (shared lookup for regen log)
        case "KOS-BASS-001": return "Berlin School drone"
        case "KOS-BASS-002": return "Root-Fifth Slow Walk"
        case "KOS-BASS-003": return "TD pulse"
        case "KOS-BASS-004": return "Moroder Drift"
        case "KOS-BASS-005": return "No bass"
        case "KOS-BASS-006": return "Additive dual bass"
        case "KOS-BASS-007": return "Berlin school tremolo"
        case "KOS-BASS-008": return "Hallogallo Lock"
        case "KOS-BASS-009": return "Crawling Walk"
        case "KOS-BASS-010": return "Probabilistic Moroder Pulse"
        case "KOS-BASS-011": return "Kraftwerk driving bass"
        case "KOS-BASS-012": return "McCartney melodic drive"
        case "KOS-BASS-013": return "Loscil sub-bass pulse"
        default:             return ruleID
        }
    }

    private static func lead1RuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-LD1-001": return "Neu! motif first"
        case "MOT-LD1-002": return "Pentatonic cell"
        case "MOT-LD1-003": return "Punch solo"
        case "MOT-LD1-004": return "Stepwise sequence"
        case "MOT-LD1-005": return "Call and answer"
        case "MOT-LD1-006": return "Long arc solo"
        case "MOT-LD1-007": return "Vanishing solo"
        case "MOT-LD1-008": return "Visiting solo"
        default:            return ruleID
        }
    }

    private static func lead2RuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-LD2-001": return "Counter-response"
        case "MOT-LD2-002": return "Sustained Drone"
        case "MOT-LD2-003": return "Rhythmic Counter"
        case "MOT-LD2-004": return "Neu! counter melody"
        case "MOT-LD2-005": return "Descending line"
        case "MOT-LD2-006": return "Neu! harmony"
        // Ambient Lead 2 rules
        case "AMB-LEAD-005": return "Silent-window fill"
        case "AMB-LEAD-006": return "No lead 2"
        default:            return ruleID
        }
    }

    private static func padRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-PADS-001": return "Harmonia sustained notes"
        case "MOT-PADS-002": return "Power Drone"
        case "MOT-PADS-003": return "Pulsed"
        case "MOT-PADS-004": return "Stabs"
        case "MOT-PADS-005": return "Harmonia charleston"
        case "MOT-PADS-006": return "Half-bar Breathe"
        case "MOT-PADS-007": return "Backbeat Stabs"
        default:             return ruleID
        }
    }

    private static func rhythmRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-RTHM-001": return "8th-note Stride"
        case "MOT-RTHM-002": return "Quarter stride"
        case "MOT-RTHM-003": return "Syncopated Motorik"
        case "MOT-RTHM-004": return "2-bar Melodic Riff"
        case "MOT-RTHM-005": return "Chord Stab"
        case "MOT-RTHM-006": return "Harmonia arpeggio"
        default:             return ruleID
        }
    }

    private static func textureRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "MOT-TEXT-001": return "Cluster sparse"
        case "MOT-TEXT-002": return "Transition swell"
        case "MOT-TEXT-003": return "Spatial sweep"
        case "MOT-TEXT-004": return "Shimmer hold"
        case "MOT-TEXT-005": return "Eno Cluster breath release"
        case "MOT-TEXT-006": return "High-tension touch"
        case "MOT-TEXT-007": return "Pedal drone"
        case "MOT-TEXT-008": return "Phase slip"
        // Kosmic texture rules
        case "KOS-TEXT-001": return "Orbital looping motif"
        case "KOS-TEXT-002": return "Distant Pulse"
        case "KOS-TEXT-003": return "Spatial Sweep"
        case "KOS-TEXT-004": return "Loscil Drip"
        default:             return ruleID
        }
    }

    // MARK: - Kosmic rule descriptions

    private static func kosmicDrumRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-DRUM-001": return "Minimal — JMJ Mini Pops style"
        case "KOS-DRUM-002": return "Basic Channel minimal dub"
        case "KOS-DRUM-003": return "No percussion"
        case "KOS-DRUM-004": return "Electric Buddha groove"
        case "KOS-DRUM-005": return "Electric Buddha minimal beat"
        case "KOS-DRUM-006": return "Electric Buddha restrained"
        default:                 return ruleID
        }
    }

    private static func kosmicBassRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-BASS-001":  return "Berlin School drone"
        case "KOS-BASS-002":  return "Root-Fifth Slow Walk"
        case "KOS-BASS-003":  return "Tangerine Dream pulse"
        case "KOS-BASS-004":  return "Moroder Drift"
        case "KOS-BASS-005":  return "No bass"
        case "KOS-BASS-006":  return "Additive dual bass"
        case "KOS-BASS-007":  return "Berlin school tremolo"
        case "KOS-BASS-008":  return "Hallogallo Lock"
        case "KOS-BASS-009":  return "Crawling Walk"
        case "KOS-BASS-010":  return "Probabilistic Moroder Pulse"
        case "KOS-BASS-011":  return "Kraftwerk driving bass"
        case "KOS-BASS-012":  return "McCartney melodic drive"
        case "KOS-BASS-013":  return "Loscil sub-bass pulse"
        case "BASS-EVOL":     return "Evolving pattern"
        case "BASS-DEVOL":    return "Devolving pattern"
        default:              return ruleID.hasPrefix("KOS-") ? ruleID : "Unknown bass rule"
        }
    }

    private static func kosmicPadRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-PADS-001":  return "Eno long drone"
        case "KOS-PADS-002":  return "Vangelis swell"
        case "KOS-PADS-003":  return "Steve Roach unsync layers"
        case "KOS-PADS-004":  return "Suspended Resolution — sus4→minor"
        case "KOS-PADS-005":  return "Stacked fourths"
        case "KOS-PADS-006":  return "Electric Buddha cloud shimmer"
        case "KOS-PADS-007":  return "Probabilistic gated chord pulse"
        case "KOS-PADS-008":  return "bIII colour chord layer"
        default:              return ruleID
        }
    }

    private static func kosmicLeadRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-LEAD-001": return "Berlin school slow arc"
        case "KOS-LEAD-002": return "Eno floating tones"
        case "KOS-LEAD-003": return "Pentatonic drift"
        case "KOS-LEAD-004": return "Echo melody"
        case "KOS-LEAD-005": return "TD arp highlight"
        case "KOS-LEAD-006": return "JMJ evolving phrase"
        case "KOS-LEAD-007": return "TD skip sequence"
        case "KOS-LEAD-008": return "Caligari solo"
        case "KOS-LEAD-009": return "Dark Sun solo"
        default:             return ruleID
        }
    }

    private static func kosmicRthmRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-RTHM-001": return "Probabilistic TD sequencer"
        case "KOS-RTHM-002": return "Probabilistic JMJ melodic hook"
        case "KOS-RTHM-003": return "JMJ oscillation"
        case "KOS-RTHM-004": return "Electric Buddha groove"
        case "KOS-RTHM-005": return "JMJ dual arpeggio"
        case "KOS-RTHM-006": return "Kraftwerk locked pulse"
        case "KOS-RTHM-007": return "TD pitch drift"
        case "KOS-RTHM-008": return "JMJ Oxygen 8-bar arc"
        case "KOS-RTHM-009": return "Craven Faults phase drift"
        case "KOS-RTHM-010": return "Craven Faults modular grit"
        default:            return ruleID
        }
    }

    private static func kosmicTexRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "KOS-TEXT-001": return "Orbital looping motif"
        case "KOS-TEXT-002": return "Distant Pulse"
        case "KOS-TEXT-003": return "Spatial Sweep — chromatic passing"
        case "KOS-TEXT-004": return "Loscil Drip"
        default:             return ruleID
        }
    }

    private static func kosmicProgressionFamilyLabel(_ family: KosmicProgressionFamily) -> String {
        switch family {
        case .static_drone:          return "Static Drone"
        case .two_chord_pendulum:    return "Two chord pendulum i bVI"
        case .modal_drift:           return "Modal Drift i bVII bVI"
        case .suspended_resolution:  return "Suspended Resolution sus4 minor"
        case .quartal_stack:         return "Stacked fourths"
        }
    }

    // MARK: - Kosmic generation log builder

    /// Rule IDs introduced recently — shown with a " *" suffix in the status log.
    /// Capped at 6; retire oldest when adding new ones.
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
        texRules: Set<String>
    ) -> [GenerationLogEntry] {
        var log: [GenerationLogEntry] = []

        // Song title
        log.append(GenerationLogEntry(tag: "SONG", description: title, isTitle: true))

        // Style identifier
        log.append(GenerationLogEntry(tag: "Style", description: "Kosmic"))

        // Kosmic form
        let kosmicFormLabel: String
        switch kosmicForm {
        case .single_evolving:              kosmicFormLabel = "Steady evolution"
        case .ab, .two_world:               kosmicFormLabel = "A - B"
        case .aba, .build_and_dissolve:     kosmicFormLabel = "A - B - A"
        case .abab:                         kosmicFormLabel = "A - B - A - B"
        case .abba:                         kosmicFormLabel = "A - B - B - A"
        }
        // Append bridge note if one was inserted
        let hasBridge = structure.sections.contains { $0.label == .bridge || $0.label == .bridgeAlt || $0.label == .bridgeMelody }
        let bridgeSuffix = hasBridge ? " + bridge" : ""
        log.append(GenerationLogEntry(tag: "Form", description: kosmicFormLabel + bridgeSuffix))


        // Chord progression — key/mode + progression family
        let progFamilyLabel = kosmicProgressionFamilyLabel(kosmicProgFamily)
        log.append(GenerationLogEntry(tag: "Chords", description: "\(frame.key) \(frame.mode.rawValue) \(progFamilyLabel)"))

        // Arpeggio (Rhythm track)
        for ruleID in rhythmRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: kosmicRthmRuleDescription(ruleID)))
        }

        // Lead 1
        for ruleID in lead1Rules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: kosmicLeadRuleDescription(ruleID)))
        }

        // Lead 2 — skip any rule already shown under Lead 1 (same rule = Lead 2 mirrors Lead 1
        // with a timing offset; logging it twice is redundant and looks like a bug).
        for ruleID in lead2Rules.sorted() {
            guard !lead1Rules.contains(ruleID) else { continue }
            log.append(GenerationLogEntry(tag: ruleID, description: kosmicLeadRuleDescription(ruleID)))
        }

        // Pads
        for ruleID in padRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: kosmicPadRuleDescription(ruleID)))
        }

        // Texture
        for ruleID in texRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: kosmicTexRuleDescription(ruleID)))
        }

        // Bass
        for ruleID in bassRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: kosmicBassRuleDescription(ruleID)))
        }

        // Drums
        for ruleID in drumRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: kosmicDrumRuleDescription(ruleID)))
        }

        return log
    }

    // MARK: - Ambient generation log builder

    private static func ambientProgressionFamilyLabel(_ family: AmbientProgressionFamily) -> String {
        switch family {
        case .droneSingle:    return "Static drone"
        case .droneTwo:       return "Two chord drift i ♭VII"
        case .modalDrift:     return "Modal drift i ♭VII ♭VI"
        case .suspendedDrone: return "Suspended drone"
        case .dissonantHaze:  return "Dissonant haze m7"
        }
    }

    /// Removes events that start inside [from, to) and truncates any event that starts before
    /// `from` but whose duration bleeds into the range. Used by breath silence and X-Files block.
    private static func clearStepRange(_ events: [MIDIEvent], from: Int, to: Int) -> [MIDIEvent] {
        events.compactMap { ev in
            if ev.stepIndex >= from && ev.stepIndex < to { return nil }
            if ev.stepIndex < from {
                let bleed = ev.stepIndex + ev.durationSteps - from
                if bleed > 0 {
                    return MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                     velocity: ev.velocity,
                                     durationSteps: ev.durationSteps - bleed)
                }
            }
            return ev
        }
    }

    private static func buildAmbientLog(
        title: String,
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        loopLengths: AmbientLoopLengths,
        percussionStyle: PercussionStyle,
        ambientProgFamily: AmbientProgressionFamily,
        drumRules: Set<String>,
        bassRules: Set<String>,
        padRules: Set<String>,
        lead1Rules: Set<String>,
        lead2Rules: Set<String>,
        rhythmRules: Set<String>,
        texRules: Set<String>,
        forceBassRuleID: String? = nil,
        forceArpRuleID: String? = nil,
        forceLeadRuleID: String? = nil,
        forcePercussionStyle: PercussionStyle? = nil
    ) -> [GenerationLogEntry] {
        var log: [GenerationLogEntry] = []

        log.append(GenerationLogEntry(tag: "SONG", description: title, isTitle: true))
        log.append(GenerationLogEntry(tag: "Style", description: "Ambient"))

        // Song form / structure shape
        let hasIntro = structure.introSection != nil
        let hasOutro = structure.outroSection != nil
        let formDesc: String
        if !hasIntro && !hasOutro {
            formDesc = "Pure drone — no intro/outro"
        } else {
            let introBars = structure.introSection.map { "\($0.lengthBars) bar intro" } ?? ""
            let outroBars = structure.outroSection.map { "\($0.lengthBars) bar outro" } ?? ""
            let parts = [introBars, outroBars].filter { !$0.isEmpty }
            formDesc = parts.joined(separator: ", ")
        }
        log.append(GenerationLogEntry(tag: "Form", description: formDesc))

        // Chord plan — key/mode + progression family
        let progLabel = ambientProgressionFamilyLabel(ambientProgFamily)
        log.append(GenerationLogEntry(tag: "Chords", description: "\(frame.key) \(frame.mode.rawValue) \(progLabel)"))

        // Loop lengths (shows phase-shift structure)
        let loopDesc = "pd \(loopLengths.pads) l1 \(loopLengths.lead1) l2 \(loopLengths.lead2) ry \(loopLengths.rhythm) tx \(loopLengths.texture) bs \(loopLengths.bass)"
        log.append(GenerationLogEntry(tag: "Loops", description: loopDesc))

        for ruleID in padRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: ambientRuleDescription(ruleID)))
        }
        for ruleID in lead1Rules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: ambientRuleDescription(ruleID)))
        }
        for ruleID in lead2Rules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: ambientRuleDescription(ruleID)))
        }
        for ruleID in rhythmRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: ambientRuleDescription(ruleID)))
        }
        for ruleID in texRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: ambientRuleDescription(ruleID)))
        }
        for ruleID in bassRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: ambientRuleDescription(ruleID)))
        }
        for ruleID in drumRules.sorted() {
            log.append(GenerationLogEntry(tag: ruleID, description: ambientRuleDescription(ruleID)))
        }

        return log
    }

    // MARK: - Ambient rule descriptions

    private static func ambientRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        // Pads
        case "AMB-PADS-001":    return "Sustained chord layer"
        case "AMB-PADS-002":    return "Slow cascade"
        case "AMB-PADS-003":    return "Modal cloud"
        // Bass
        case "AMB-BASS-001":  return "Loscil drone root"
        case "AMB-BASS-002":  return "No bass"
        case "AMB-BASS-003":  return "Root+fifth drone"
        // Lead 1
        case "AMB-LEAD-001":  return "Eno floating tone"
        case "AMB-LEAD-002":  return "Echo phrase"
        case "AMB-LEAD-003":  return "Harold Budd shimmer"
        case "AMB-LEAD-007":  return "Lyric fragment"
        case "AMB-LEAD-008":  return "Returning motif"
        case "AMB-LEAD-009":  return "Magnetik solo"
        case "AMB-LEAD-010":  return "Oxygenerator solo"
        // Lead 2
        case "AMB-LEAD-005":     return "Silent-window fill"
        case "AMB-LEAD-006":     return "No lead 2"
        case "AMB-LEAD-004":    return "Echo lead phrase"
        case "AMB-XFILES-001":  return "Spooky X-Files theme"
        // Rhythm
        case "AMB-RTHM-001": return "Single-tone pulse"
        case "AMB-RTHM-002": return "Sparse arpeggio"
        case "AMB-RTHM-003": return "Stochastic phrase"
        case "AMB-RTHM-004": return "No rhythm"
        case "AMB-RTHM-005": return "Celestial phrase"
        case "AMB-RTHM-006": return "Craven Faults bell cell"
        // Texture
        case "AMB-TEXT-001": return "Orbital shimmer"
        case "AMB-TEXT-002": return "Ghost tone"
        case "AMB-TEXT-003": return "Audio: Light Rain"
        case "AMB-TEXT-004": return "No texture"
        case "AMB-TEXT-005": return "Audio: Rain & Thunder"
        case "AMB-TEXT-006": return "Audio: Ocean Waves"
        case "AMB-TEXT-007": return "Audio: Zen Bells"
        case "AMB-TEXT-008": return "Audio: Wind Storm"
        case "AMB-TEXT-009": return "Audio: Desert Winds"
        // Drums
        case "AMB-DRUM-004": return "Claude hand percussion"
        case "AMB-DRUM-001": return "Sparse ride, cymbals"
        case "AMB-DRUM-002": return "Soft pulse"
        case "AMB-DRUM-003": return "No percussion"
        default:                   return ruleID
        }
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
        texRules: Set<String> = [],
        xFilesBars: [Int] = [],
        breathSilenceBar: Int? = nil,
        breathSilenceLenBars: Int = 0,
        isAmbient: Bool = false,
        includeDrumFills: Bool = true,
        soloRange: Range<Int>? = nil,
        soloRuleID: String? = nil,
        chillBreakdownStyle: ChillBreakdownStyle? = nil,
        chillDrumFillBars: [Int] = []
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

        // Bar-indexed event tables: one pass each, O(totalEvents).
        // Replaces repeated O(totalEvents) filter scans in hatCount/bassLocked/fillName
        // and the per-bar drum cymbal loop — all become O(eventsInThatBar) lookups.
        var drumByBar = [Int: [MIDIEvent]]()
        if kTrackDrums < trackEvents.count {
            for ev in trackEvents[kTrackDrums] {
                let b = ev.stepIndex / 16
                if b >= 0 && b < totalBars { drumByBar[b, default: []].append(ev) }
            }
        }
        var bassByBar = [Int: [MIDIEvent]]()
        if kTrackBass < trackEvents.count {
            for ev in trackEvents[kTrackBass] {
                let b = ev.stepIndex / 16
                if b >= 0 && b < totalBars { bassByBar[b, default: []].append(ev) }
            }
        }

        // fire: fires at the given absolute step index
        func fire(_ step: Int, tag: String, desc: String) {
            out[max(0, step), default: []].append(GenerationLogEntry(tag: tag, description: desc))
        }
        // fireBar: convenience — fires at the start of a bar
        func fireBar(_ bar: Int, tag: String, desc: String) {
            fire(bar * 16, tag: tag, desc: desc)
        }

        // Extended solo annotation — fires at the first bar of the solo window
        if let sr = soloRange, let ruleID = soloRuleID {
            let desc: String
            switch ruleID {
            case "MOT-LD1-007": desc = "Extended solo  Vanishing solo"
            case "MOT-LD1-008": desc = "Extended solo  Visiting solo"
            default:            desc = "Extended solo"
            }
            fireBar(sr.lowerBound, tag: "", desc: desc)
        }

        // Helper: format chord name from degree string + type, respecting flat/sharp key context
        func chordName(_ rootDegree: String, _ type: ChordType) -> String {
            let keyST = keySemitone(frame.key)
            let rootST = (keyST + degreeSemitone(rootDegree) + 12) % 12
            let flatKeys: Set<String> = ["F", "Bb", "Eb", "Ab", "Db", "Gb"]
            let names = flatKeys.contains(frame.key)
                ? ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"]
                : ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
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
            let bs = bar * 16
            // Include ride: ride-based patterns (CHL-DRUM-004) strip ride in the fill region,
            // so ride absence = fill, just like hat absence for hat-based patterns.
            let hatNotes: Set<UInt8> = [GMDrum.closedHat.rawValue, GMDrum.pedalHat.rawValue,
                                        GMDrum.openHat.rawValue, GMDrum.ride.rawValue]
            return (drumByBar[bar] ?? []).filter {
                $0.stepIndex >= bs + fromStep && $0.stepIndex < bs + toStep && hatNotes.contains($0.note)
            }.count
        }

        // Helper: infer fill length in beats from hat-stripping signature
        func fillBeats(bar: Int) -> Int {
            if hatCount(bar: bar, fromStep: 4, toStep: 16) == 0 { return 3 }
            if hatCount(bar: bar, fromStep: 8, toStep: 16) == 0 { return 2 }
            return 1
        }

        // Helper: bass locked = no notes in back 12 steps of bar
        func bassLocked(bar: Int) -> Bool {
            let bs = bar * 16
            return (bassByBar[bar] ?? []).allSatisfy { $0.stepIndex < bs + 4 }
        }

        // Helper: identify cold start pickup fill name by examining drum notes in the last intro bar
        func coldStartFillName(bar: Int) -> String {
            let evs = drumByBar[bar] ?? []
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
            let bs = bar * 16
            let regionStart = bs + (beats == 3 ? 4 : beats == 2 ? 8 : 12)
            let evs = (drumByBar[bar] ?? []).filter { $0.stepIndex >= regionStart && $0.stepIndex < bs + 16 }
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
                    introDesc = "\(section.lengthBars) bar cold start"
                } else {
                    introDesc = "\(section.lengthBars) bar \(introStyleLabel(structure.introStyle))"
                }
                fireBar(bar, tag: "Intro", desc: introDesc)
            case .A:
                if !isAmbient {
                    if seenLabels.contains(.A) && chillBreakdownStyle != nil && seenLabels.contains(.bridge) {
                        fireBar(bar, tag: "Groove A", desc: "Groove returns")
                    } else if seenLabels.contains(.A) {
                        fireBar(bar, tag: "Form", desc: "Return to A section")
                    } else {
                        fireBar(bar, tag: "Section A", desc: "\(section.lengthBars) bars")
                    }
                }
            case .B:
                if chillBreakdownStyle != nil && seenLabels.contains(.bridge) {
                    // Chill: B section is always the groove return after breakdown
                    fireBar(bar, tag: "Groove B", desc: "Groove returns")
                } else if seenLabels.contains(.B) {
                    fireBar(bar, tag: "Form", desc: "Enter B section again")
                } else {
                    fireBar(bar, tag: "Form", desc: "Enter B section")
                }
            case .outro:
                fireBar(bar, tag: "Outro", desc: "\(section.lengthBars) bar \(outroStyleLabel(structure.outroStyle))")
            case .bridge:
                if let bds = chillBreakdownStyle {
                    let styleLabel: String
                    switch bds {
                    case .stopTime:      styleLabel = "stop-time solo"
                    case .bassOstinato:  styleLabel = "bass ostinato"
                    case .harmonicDrone: styleLabel = "harmonic drone"
                    case .groovePocket:  styleLabel = "groove pocket"
                    }
                    fireBar(bar, tag: "Breakdown", desc: "\(section.lengthBars) bars — \(styleLabel)")
                } else {
                    fireBar(bar, tag: "Form", desc: "Ascending bridge")
                }
            case .bridgeAlt:
                fireBar(bar, tag: "Form", desc: "Call and response bridge")
            case .bridgeMelody:
                fireBar(bar, tag: "Form", desc: "Melodic bridge")
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
        //    Skip entirely when percussion is absent (drum track empty), or for Ambient.
        let hasDrums = includeDrumFills && kTrackDrums < trackEvents.count && !trackEvents[kTrackDrums].isEmpty
        for fillBar in allFillBars.sorted() where fillBar < outroStartBar && hasDrums {
            guard let sec = structure.section(atBar: fillBar),
                  sec.label != .intro && sec.label != .outro && !sec.label.isBridge else { continue }
            let beats  = fillBeats(bar: fillBar)
            guard beats > 1 else { continue }  // 1-beat fills are too brief to clutter the log with
            let name   = fillName(bar: fillBar, beats: beats)
            let locked = bassLocked(bar: fillBar)
            let desc   = locked ? "\(beats) beat \(name) bass lock" : "\(beats) beat \(name)"
            // fillRegionOffset: where in the bar the fill starts; fire 1/4 bar (4 steps) before that
            let fillRegionOffset = beats == 1 ? 12 : beats == 2 ? 8 : 4
            fire(fillBar * 16 + max(0, fillRegionOffset - 4), tag: "Drum fill", desc: desc)
        }

        // 2b. Chill snare-roll fills — fired 1 beat (4 steps) before bar end so the text
        //     appears slightly ahead of the roll climax. Only fires in groove sections.
        for bar in chillDrumFillBars.sorted() where bar < outroStartBar {
            guard let sec = structure.section(atBar: bar),
                  sec.label == .A || sec.label == .B else { continue }
            fire(bar * 16 + 8, tag: "Drum fill", desc: "snare roll")
        }

        // 3. Drum cymbal variations — Kosmic/Motorik only; Ambient drums are too sparse for this.
        // DRM-003 (Ride Groove) uses ride as its baseline — skip ride annotations for it
        // since the generation log already documents this. For all other drum rules, track
        // the cymbal mode across the whole song (no reset between sections) so a transition
        // back to ride after a non-body section doesn't re-trigger.
        let isRideGroove = drumRules.contains("MOT-DRUM-003") || drumRules.contains("CHL-DRUM-004")
        if includeDrumFills && kTrackDrums < trackEvents.count {
            var prevCymbalMode: String? = nil
            for bar in 0..<totalBars {
                guard !allFillBars.contains(bar),
                      let sec = structure.section(atBar: bar),
                      sec.label == .A || sec.label == .B else { continue }
                let bs = bar * 16
                let barEvs = drumByBar[bar] ?? []
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
                        fireBar(bar, tag: "Drums", desc: "crash + open hat")
                    case "openHat":
                        fireBar(bar, tag: "Drums", desc: "open hat on & of 4")
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
            // trackBars[trackIdx] is already exactly this — no need to rebuild.
            let barHasNotes = trackIdx < trackBars.count ? trackBars[trackIdx]
                                                         : [Bool](repeating: false, count: totalBars)
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
                // Fires at most once per body section — oscillating patterns like KOS-BASS-002
                // (root ↔ fifth every 4 bars) would otherwise trigger on every window change.
                // Single-pass window: uses bassByBar so the 4-bar accumulation is O(eventsInWindow).
                func bassWindow(fromBar: Int) -> (fp: Set<UInt8>, count: Int) {
                    let windowEnd = min(fromBar + 4, totalBars)
                    var pitchClasses = Set<UInt8>()
                    var count = 0
                    for b in fromBar..<windowEnd {
                        for ev in bassByBar[b] ?? [] {
                            pitchClasses.insert(ev.note % 12)
                            count += 1
                        }
                    }
                    return (pitchClasses, count)
                }
                var prevFP: Set<UInt8>? = nil
                var prevCount: Int = 0
                var lastEvolvedSectionStart: Int = -1
                for bar in stride(from: 0, to: outroStartBar, by: 4) {
                    guard let sec = structure.section(atBar: bar),
                          sec.label == .A || sec.label == .B else { continue }
                    let (fp, count) = bassWindow(fromBar: bar)
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
                        if (pitchChanged || densityChanged) && sec.startBar != lastEvolvedSectionStart {
                            fireBar(bar, tag: "Bass", desc: "pattern evolving")
                            lastEvolvedBar = bar
                            lastEvolvedSectionStart = sec.startBar
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

        // X-Files theme appearances — one annotation per bridge section (first bar only)
        var annotatedBridges = Set<Int>()
        for bar in xFilesBars.sorted() {
            guard let section = structure.section(atBar: bar) else { continue }
            guard annotatedBridges.insert(section.startBar).inserted else { continue }
            fireBar(bar, tag: "Spooky", desc: "X-Files theme")
        }

        // Breath silence annotation
        if let bBar = breathSilenceBar, breathSilenceLenBars > 0 {
            fireBar(bBar, tag: "Breath", desc: "\(breathSilenceLenBars) bar\(breathSilenceLenBars == 1 ? "" : "s") more quiet")
        }

        // Ambient chord shift annotations — fire at each chord boundary after bar 0.
        // First window is the opening tonic; subsequent windows are shifts or returns.
        if isAmbient && structure.chordPlan.count > 1 {
            let first = structure.chordPlan[0]
            for window in structure.chordPlan.dropFirst() {
                let name = chordName(window.chordRoot, window.chordType)
                let isReturn = window.chordRoot == first.chordRoot && window.chordType == first.chordType
                fireBar(window.startBar, tag: isReturn ? "Return" : "Chord shift", desc: name)
            }
        }

        return out
    }

    // MARK: - Chill generation path

    private static func generateChill(
        seed: UInt64,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        forceBassRuleID:    String? = nil,
        forceDrumRuleID:    String? = nil,
        forcePadsRuleID:    String? = nil,
        forceLeadRuleID:    String? = nil,
        forceRhythmRuleID:  String? = nil,
        forceTexRuleID:     String? = nil
    ) -> SongState {
        var rng = SeededRNG(seed: seed)

        // Derive forced beat style and lead instrument from rule IDs (best-first-song / load path).
        // CHL-DRUM-004 = stGermain four-on-the-floor; forcing the beat style also biases
        // the tempo into the stGermain upper range (108–124 BPM) and routes the bass to
        // CHL-BASS-007 (stGermainOstinato) automatically.
        let forceBeatStyle: ChillBeatStyle? = forceDrumRuleID == "CHL-DRUM-004" ? .stGermain : nil
        let forceLeadInstrument: ChillLeadInstrument? = {
            switch forceLeadRuleID {
            case "CHL-LD1-001": return .flute
            case "CHL-LD1-002": return .mutedTrumpet
            case "CHL-LD1-003": return .vibraphone
            case "CHL-LD1-004": return .saxophone
            case "CHL-LD1-006": return .sopranoSax
            case "CHL-LD1-007": return .trumpet
            case "CHL-LD1-008": return .tenorSax
            default:            return nil
            }
        }()

        // Step 1 — Chill musical frame
        let (frame, chillProgFamily, pickedLeadInstrument, chillBeatStyle, chillSwingFeel) =
            ChillMusicalFrameGenerator.generate(
                rng: &rng, keyOverride: keyOverride, tempoOverride: tempoOverride,
                moodOverride: moodOverride, forceBeatStyle: forceBeatStyle
            )
        let chillLeadInstrument = forceLeadInstrument ?? pickedLeadInstrument

        // Pick breakdown style first — needed to set breakdown length in the structure.
        // hasBreakdown is optimistically true; if the structure uses simple form (no bridge),
        // the style value is unused.
        let chillBreakdownStyle: ChillBreakdownStyle = pickChillBreakdownStyle(
            beatStyle: chillBeatStyle, hasBreakdown: true, rng: &rng
        )

        // Step 2 — Structure (INTRO / GROOVE-A / BREAKDOWN / GROOVE-B / OUTRO)
        let structure = ChillStructureGenerator.generate(
            frame: frame, chillProgFamily: chillProgFamily,
            mood: frame.mood, breakdownStyle: chillBreakdownStyle, rng: &rng
        )

        // Step 3 — Tonal governance map
        let tonalMap = TonalGovernanceBuilder.build(frame: frame, structure: structure)

        var trackEvents = [[MIDIEvent]](repeating: [], count: kTrackCount)

        var drumRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackDrums))
        var bassRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackBass))
        var padsRNG   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackPads))
        var rhythmRNG = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackRhythm))
        var lead1RNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead1))
        var lead2RNG  = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: kTrackLead2))

        // Step 3 — Drums
        var drumRules: Set<String> = []
        var drumFillBars: [Int] = []
        trackEvents[kTrackDrums] = ChillDrumGenerator.generate(
            frame: frame, structure: structure, beatStyle: chillBeatStyle,
            breakdownStyle: chillBreakdownStyle,
            rng: &drumRNG, usedRuleIDs: &drumRules, fillBars: &drumFillBars
        )

        // Step 4 — Bass
        var bassRules: Set<String> = []
        trackEvents[kTrackBass] = ChillBassGenerator.generate(
            frame: frame, structure: structure, chillProgFamily: chillProgFamily,
            beatStyle: chillBeatStyle, breakdownStyle: chillBreakdownStyle,
            rng: &bassRNG, usedRuleIDs: &bassRules
        )

        // Step 5 — Pads (sustained harmonic layer)
        var padRules: Set<String> = []
        trackEvents[kTrackPads] = ChillPadsGenerator.generate(
            frame: frame, structure: structure, breakdownStyle: chillBreakdownStyle,
            rng: &padsRNG, usedRuleIDs: &padRules
        )

        // Step 6 — Lead 1 (primary solo) and Lead 2 (call-and-response)
        var lead1Rules: Set<String> = []
        let (lead1Events, lead1Onsets, lead1HandoffBars) = ChillLeadGenerator.generateLead1(
            frame: frame, structure: structure, leadInstrument: chillLeadInstrument,
            beatStyle: chillBeatStyle, breakdownStyle: chillBreakdownStyle,
            forceRuleID: forceLeadRuleID,
            rng: &lead1RNG, usedRuleIDs: &lead1Rules
        )
        trackEvents[kTrackLead1] = lead1Events

        var lead2Rules: Set<String> = []
        let (lead2Events, chillLead2Instrument) = ChillLeadGenerator.generateLead2(
            frame: frame, structure: structure, lead1Instrument: chillLeadInstrument,
            lead1Onsets: lead1Onsets, handoffBars: lead1HandoffBars,
            rng: &lead2RNG, usedRuleIDs: &lead2Rules
        )
        trackEvents[kTrackLead2] = lead2Events

        // Step 7 — Rhythm (Rhodes active comping)
        var rhythmRules: Set<String> = []
        trackEvents[kTrackRhythm] = ChillRhythmGenerator.generate(
            frame: frame, structure: structure, mood: frame.mood,
            beatStyle: chillBeatStyle,
            breakdownStyle: chillBreakdownStyle,
            rng: &rhythmRNG, usedRuleIDs: &rhythmRules
        )

        // Texture track: audio-only — no MIDI events generated here.
        trackEvents[kTrackTexture] = []

        // Post-processing: harmonic filter
        trackEvents = HarmonicFilter.apply(trackEvents: trackEvents, frame: frame, structure: structure)

        // Post-processing: drum fills + cymbal variation.
        // Only stGermain (CHL-DRUM-004) is four-on-the-floor like Motorik; other Chill
        // beat styles are sparse by design and must not have tom cascades added.
        // hipHopJazz (CHL-DRUM-005) has its own internal variation via tambourine scheduling.
        if chillBeatStyle == .stGermain {
            trackEvents = DrumVariationEngine.apply(trackEvents: trackEvents, frame: frame, structure: structure, seed: seed, chillMode: true)
        }

        // Audio texture: 60% chance of selecting one of the bundled M4A files.
        // High-tempo songs (≥100 BPM) skip harbor; low-tempo songs (≤82 BPM) skip city.
        var chillTextureFiles = ["another_bar.m4a", "another-pub.m4a", "bar_sounds.m4a",
                                  "city_at_night.m4a", "harbor.m4a",
                                  "vinyl_crackle.m4a"]
        if frame.tempo >= 100 {
            chillTextureFiles.removeAll { $0 == "harbor.m4a" }
        }
        if frame.tempo <= 82 {
            chillTextureFiles.removeAll { $0 == "city_at_night.m4a" }
        }
        // forceTexRuleID "forced" guarantees a texture is selected (used by best-first-song).
        let chillAudioTexture: String? = (forceTexRuleID == "forced" || rng.nextDouble() < 0.60)
            ? chillTextureFiles[rng.weightedPick(Array(repeating: 1.0 / Double(chillTextureFiles.count),
                                                       count: chillTextureFiles.count))]
            : nil
        // Random start offset: 0, 15, 30, or 45 seconds into the audio file.
        let chillAudioTextureOffset = chillAudioTexture != nil ? [0, 15, 30, 45][rng.nextInt(upperBound: 4)] : 0

        // Title
        let title = ChillTitleGenerator.generate(frame: frame, rng: &rng)

        // Log
        let log = buildChillLog(
            title: title, frame: frame, structure: structure,
            chillProgFamily: chillProgFamily, chillLeadInstrument: chillLeadInstrument,
            chillBeatStyle: chillBeatStyle, chillBreakdownStyle: chillBreakdownStyle,
            chillSwingFeel: chillSwingFeel, chillAudioTexture: chillAudioTexture,
            drumRules: drumRules, bassRules: bassRules, padRules: padRules,
            lead1Rules: lead1Rules, lead2Rules: lead2Rules, rhythmRules: rhythmRules,
            drumFillBars: drumFillBars
        )

        let stepAnnotations = buildStepAnnotations(
            structure: structure, trackEvents: trackEvents, frame: frame,
            xFilesBars: [], breathSilenceBar: nil, breathSilenceLenBars: 0,
            isAmbient: false, includeDrumFills: true,
            chillBreakdownStyle: chillBreakdownStyle,
            chillDrumFillBars: drumFillBars
        )

        var forced: [String: String] = [:]
        if let r = forceBassRuleID   { forced["Bass"]   = r }
        if let r = forceDrumRuleID   { forced["Drums"]  = r }
        if let r = forcePadsRuleID   { forced["Pads"]   = r }
        // Only persist lead rule if it belongs to Chill — discard stale Motorik/Kosmic IDs
        if let r = forceLeadRuleID, r.hasPrefix("CHL-") { forced["Lead"] = r }
        if let r = forceRhythmRuleID { forced["Rhythm"] = r }

        return SongState(
            frame: frame, structure: structure, tonalMap: tonalMap,
            trackEvents: trackEvents, globalSeed: seed, trackOverrides: [:],
            title: title, form: .singleA, style: .chill,
            percussionStyle: .absent, kosmicProgFamily: .static_drone,
            generationLog: log, stepAnnotations: stepAnnotations,
            chillProgFamily: chillProgFamily,
            chillLeadInstrument: chillLeadInstrument,
            chillLead2Instrument: chillLead2Instrument,
            chillBeatStyle: chillBeatStyle,
            chillBreakdownStyle: chillBreakdownStyle,
            chillSwingFeel: chillSwingFeel,
            chillAudioTexture: chillAudioTexture,
            chillAudioTextureOffset: chillAudioTextureOffset,
            forcedRules: forced,
            keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride
        )
    }

    // MARK: - Chill breakdown style picker

    private static func pickChillBreakdownStyle(
        beatStyle: ChillBeatStyle, hasBreakdown: Bool, rng: inout SeededRNG
    ) -> ChillBreakdownStyle {
        guard hasBreakdown else { return .bassOstinato }  // no breakdown section — value unused
        // Breakdown style is independent of drum beat style (instruments are set separately).
        // stopTime 25%, bassOstinato 25%, harmonicDrone 25%, groovePocket 25%
        let r = rng.nextDouble()
        if r < 0.25 { return .stopTime }
        if r < 0.50 { return .bassOstinato }
        if r < 0.75 { return .harmonicDrone }
        return .groovePocket
    }

    // MARK: - Chill log builder

    private static func buildChillLog(
        title: String,
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        chillProgFamily: ChillProgressionFamily,
        chillLeadInstrument: ChillLeadInstrument,
        chillBeatStyle: ChillBeatStyle,
        chillBreakdownStyle: ChillBreakdownStyle,
        chillSwingFeel: Bool,
        chillAudioTexture: String?,
        drumRules: Set<String>,
        bassRules: Set<String>,
        padRules: Set<String>,
        lead1Rules: Set<String>,
        lead2Rules: Set<String>,
        rhythmRules: Set<String>,
        drumFillBars: [Int]
    ) -> [GenerationLogEntry] {
        var log: [GenerationLogEntry] = []
        log.append(GenerationLogEntry(tag: "SONG",  description: title, isTitle: true))
        log.append(GenerationLogEntry(tag: "Style", description: "Chill"))

        // Form — simple label matching the style of other generators
        let hasBreakdown = structure.sections.contains { $0.label == .bridge }
        let breakdownLabel: String
        switch chillBreakdownStyle {
        case .stopTime:      breakdownLabel = "stop-time"
        case .bassOstinato:  breakdownLabel = "bass ostinato"
        case .harmonicDrone: breakdownLabel = "harmonic drone"
        case .groovePocket:  breakdownLabel = "groove pocket"
        }
        let formDesc = hasBreakdown ? "Groove - breakdown" : "Groove"
        log.append(GenerationLogEntry(tag: "Form", description: formDesc))

        // Chords — key/mode + family
        let familyLabel: String
        switch chillProgFamily {
        case .static_groove:      familyLabel = "Static groove"
        case .two_chord_pendulum: familyLabel = "2 chord pendulum"
        case .minor_blues:        familyLabel = "Minor blues"
        case .modal_drift:        familyLabel = "Modal drift"
        }
        log.append(GenerationLogEntry(tag: "Chords", description: "\(frame.key) \(frame.mode.rawValue) \(familyLabel)"))

        // Audio texture
        let textureDesc = chillAudioTexture.map { name in
            name.replacingOccurrences(of: ".m4a", with: "").replacingOccurrences(of: "_", with: " ")
        } ?? "none"
        log.append(GenerationLogEntry(tag: "Texture", description: textureDesc))

        // Per-track rules with descriptions
        for ruleID in (drumRules.union(bassRules).union(padRules)
                        .union(lead1Rules).union(lead2Rules).union(rhythmRules)).sorted() {
            log.append(GenerationLogEntry(tag: ruleID,
                                          description: chillRuleDescription(ruleID)))
        }

        return log
    }

    private static func chillRuleDescription(_ ruleID: String) -> String {
        switch ruleID {
        case "CHL-DRUM-001": return "Moby minimal syncopated"
        case "CHL-DRUM-002": return "Neo soul ghost note groove"
        case "CHL-DRUM-003": return "Jazz quarter-note pulse"
        case "CHL-DRUM-004": return "St Germain four-on-the-floor"
        case "CHL-DRUM-005": return "Hip-hop jazz pulse"
        case "CHL-BASS-001": return "Moby root sustain"
        case "CHL-BASS-002": return "Syncopated groove"
        case "CHL-BASS-003": return "Walking approach"
        case "CHL-BASS-004": return "Air ostinato"
        case "CHL-BASS-005": return "Breakdown root drone"
        case "CHL-BASS-006": return "Moby bass statement"
        case "CHL-BASS-007": return "St Germain 8th-note ostinato"
        case "CHL-BASS-008": return "Acid jazz chord-tone groove"
        case "CHL-PAD-001":  return "Chord sustain"
        case "CHL-PAD-002":  return "Staggered entry"
        case "CHL-PAD-003":  return "No pads"
        case "CHL-LD1-001":  return "Long phrase"
        case "CHL-LD1-002":  return "Short punch"
        case "CHL-LD1-003":  return "Sparse melodic solo"
        case "CHL-LD1-004":  return "Blues lead"
        case "CHL-LD1-005":  return "St Germain staccato burst"
        case "CHL-LD1-006":  return "Soprano sax lead"
        case "CHL-LD1-007":  return "Wide interval solo"
        case "CHL-LD1-008":  return "Tenor sax lead"
        case "CHL-LD2-001":  return "Counter-melody"
        case "CHL-LD2-002":  return "Trombone counter-melody"
        case "CHL-RHY-001":  return "St Germain beat 1 + and-of-2"
        case "CHL-RHY-002":  return "Moby backbeat beats 2+4"
        case "CHL-RHY-003":  return "Bosa Moon broken chord"
        case "CHL-RHY-004":  return "Acid jazz off-beat stab"
        default:             return ruleID
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
