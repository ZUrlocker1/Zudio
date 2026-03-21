// SongState.swift — complete song state held in memory while a song is loaded

// MARK: - Generation log

struct GenerationLogEntry: Sendable {
    let tag: String
    let description: String
    var isTitle: Bool = false
}

// MARK: - Song state

struct SongState: Sendable {
    let frame: GlobalMusicalFrame
    let structure: SongStructure
    /// Step 3 output. All tracks query this at render time.
    let tonalMap: TonalGovernanceMap
    /// Indexed by kTrackLead1…kTrackDrums. Each array covers the full song.
    let trackEvents: [[MIDIEvent]]
    let globalSeed: UInt64
    /// Per-track override seeds set by per-track Regenerate. Key = trackIndex.
    var trackOverrides: [Int: UInt64]
    let title: String
    let form: SongForm
    let style: MusicStyle
    /// Cosmic-only: percussion pattern selected at generation time. `.absent` for Motorik.
    let percussionStyle: PercussionStyle
    /// Cosmic-only: chord family selected at generation time. `.static_drone` default for Motorik.
    let cosmicProgFamily: CosmicProgressionFamily
    /// Ordered log entries built by SongGenerator; rendered by StatusBoxView.
    let generationLog: [GenerationLogEntry]
    /// Live playback annotations keyed by absolute step index. Each entry fires when playback
    /// reaches that step, giving precise timing (e.g. fills fire 2 beats before the hit).
    let stepAnnotations: [Int: [GenerationLogEntry]]

    // MARK: - Convenience

    func events(forTrack trackIndex: Int) -> [MIDIEvent] {
        guard trackIndex < trackEvents.count else { return [] }
        return trackEvents[trackIndex]
    }

    /// Returns a copy of this state with the frame replaced (used for real-time tempo changes).
    func withFrame(_ newFrame: GlobalMusicalFrame) -> SongState {
        SongState(frame: newFrame, structure: structure, tonalMap: tonalMap,
                  trackEvents: trackEvents, globalSeed: globalSeed,
                  trackOverrides: trackOverrides, title: title, form: form, style: style,
                  percussionStyle: percussionStyle, cosmicProgFamily: cosmicProgFamily,
                  generationLog: generationLog, stepAnnotations: stepAnnotations)
    }

    /// Returns a copy of this state with one track's events replaced.
    /// The generation log is carried through unchanged (reflects the full generation).
    func replacingEvents(_ events: [MIDIEvent], forTrack trackIndex: Int) -> SongState {
        replacingEvents(events, forTrack: trackIndex, appendingLog: [])
    }

    /// Returns a copy of this state with one track's events replaced and extra log entries appended.
    func replacingEvents(_ events: [MIDIEvent], forTrack trackIndex: Int, appendingLog extra: [GenerationLogEntry]) -> SongState {
        var updated = trackEvents
        if trackIndex < updated.count { updated[trackIndex] = events }
        return SongState(
            frame: frame, structure: structure, tonalMap: tonalMap,
            trackEvents: updated, globalSeed: globalSeed,
            trackOverrides: trackOverrides, title: title, form: form, style: style,
            percussionStyle: percussionStyle, cosmicProgFamily: cosmicProgFamily,
            generationLog: generationLog + extra, stepAnnotations: stepAnnotations
        )
    }
}
