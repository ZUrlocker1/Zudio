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
        trackEvents[kTrackDrums]   = DrumGenerator.generate(frame: frame, structure: structure, rng: &drumRNG)
        // Step 5 — Bass
        trackEvents[kTrackBass]    = BassGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &bassRNG)
        // Step 6 — Pads
        trackEvents[kTrackPads]    = PadsGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &padsRNG)
        // Step 7 — Leads
        trackEvents[kTrackLead1]   = LeadGenerator.generateLead1(frame: frame, structure: structure, tonalMap: tonalMap, rng: &lead1RNG)
        trackEvents[kTrackLead2]   = LeadGenerator.generateLead2(frame: frame, structure: structure, tonalMap: tonalMap, lead1Events: trackEvents[kTrackLead1], rng: &lead2RNG)
        // Step 8 — Rhythm
        trackEvents[kTrackRhythm]  = RhythmGenerator.generate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rhythmRNG)
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

        return SongState(
            frame: frame,
            structure: structure,
            tonalMap: tonalMap,
            trackEvents: trackEvents,
            globalSeed: seed,
            trackOverrides: [:],
            title: title,
            form: form
        )
    }

    // MARK: - Per-track regenerate

    /// Regenerates a single track without touching any other track or the global seed.
    /// Always reads selectors from SongState.frame (last full generate).
    static func regenerateTrack(_ trackIndex: Int, songState: SongState) -> SongState {
        let newTrackSeed = UInt64.random(in: .min ... .max)
        var rng = SeededRNG(seed: newTrackSeed)

        let events: [MIDIEvent]
        switch trackIndex {
        case kTrackDrums:
            events = DrumGenerator.generate(frame: songState.frame, structure: songState.structure, rng: &rng)
        case kTrackBass:
            events = BassGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng)
        case kTrackPads:
            events = PadsGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng)
        case kTrackLead1:
            events = LeadGenerator.generateLead1(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng)
        case kTrackLead2:
            events = LeadGenerator.generateLead2(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, lead1Events: songState.trackEvents[kTrackLead1], rng: &rng)
        case kTrackRhythm:
            events = RhythmGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng)
        case kTrackTexture:
            events = TextureGenerator.generate(frame: songState.frame, structure: songState.structure, tonalMap: songState.tonalMap, rng: &rng)
        default:
            return songState
        }

        var updated = songState.replacingEvents(events, forTrack: trackIndex)
        updated.trackOverrides[trackIndex] = newTrackSeed
        return updated
    }
}
