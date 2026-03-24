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
    /// Kosmic-only: percussion pattern selected at generation time. `.absent` for Motorik.
    let percussionStyle: PercussionStyle
    /// Kosmic-only: chord family selected at generation time. `.static_drone` default for Motorik.
    let kosmicProgFamily: KosmicProgressionFamily
    /// Ambient-only: progression family. `.droneSingle` default for Motorik/Kosmic.
    let ambientProgFamily: AmbientProgressionFamily
    /// Ambient-only: co-prime loop lengths per track. `nil` for Motorik/Kosmic.
    let ambientLoopLengths: AmbientLoopLengths?
    /// Ambient-only: step range of the X-Files block (4 bars). `nil` if no X-Files in this song.
    /// Used by PlaybackEngine to mute Lead 1 delay during the whistle phrase.
    let ambientXFilesBlockRange: Range<Int>?
    /// Ordered log entries built by SongGenerator; rendered by StatusBoxView.
    let generationLog: [GenerationLogEntry]
    /// Live playback annotations keyed by absolute step index. Each entry fires when playback
    /// reaches that step, giving precise timing (e.g. fills fire 2 beats before the hit).
    let stepAnnotations: [Int: [GenerationLogEntry]]

    // MARK: - Custom init (default values for Ambient fields preserve all existing call sites)

    init(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        trackEvents: [[MIDIEvent]],
        globalSeed: UInt64,
        trackOverrides: [Int: UInt64],
        title: String,
        form: SongForm,
        style: MusicStyle,
        percussionStyle: PercussionStyle,
        kosmicProgFamily: KosmicProgressionFamily,
        generationLog: [GenerationLogEntry],
        stepAnnotations: [Int: [GenerationLogEntry]],
        ambientProgFamily: AmbientProgressionFamily = .droneSingle,
        ambientLoopLengths: AmbientLoopLengths? = nil,
        ambientXFilesBlockRange: Range<Int>? = nil
    ) {
        self.frame              = frame
        self.structure          = structure
        self.tonalMap           = tonalMap
        self.trackEvents        = trackEvents
        self.globalSeed         = globalSeed
        self.trackOverrides     = trackOverrides
        self.title              = title
        self.form               = form
        self.style              = style
        self.percussionStyle    = percussionStyle
        self.kosmicProgFamily   = kosmicProgFamily
        self.ambientProgFamily       = ambientProgFamily
        self.ambientLoopLengths      = ambientLoopLengths
        self.ambientXFilesBlockRange = ambientXFilesBlockRange
        self.generationLog           = generationLog
        self.stepAnnotations    = stepAnnotations
    }

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
                  percussionStyle: percussionStyle, kosmicProgFamily: kosmicProgFamily,
                  generationLog: generationLog, stepAnnotations: stepAnnotations,
                  ambientProgFamily: ambientProgFamily, ambientLoopLengths: ambientLoopLengths,
                  ambientXFilesBlockRange: ambientXFilesBlockRange)
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
            percussionStyle: percussionStyle, kosmicProgFamily: kosmicProgFamily,
            generationLog: generationLog + extra, stepAnnotations: stepAnnotations,
            ambientProgFamily: ambientProgFamily, ambientLoopLengths: ambientLoopLengths,
            ambientXFilesBlockRange: ambientXFilesBlockRange
        )
    }
}
