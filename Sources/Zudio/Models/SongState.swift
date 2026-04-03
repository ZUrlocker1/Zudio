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
    /// Ambient-only: true when Brush Kit (program 40) was selected at generation time.
    /// Stored so per-track drum regen can reproduce the same note substitutions.
    let ambientUseBrushKit: Bool
    /// Force-rule IDs passed to generators at generation time (e.g. best-song path, test mode).
    /// Keys: "Bass", "Drums", "Rhythm", "Pads", "Lead", "Tex". Written to the log file so that
    /// Load Song can restore the exact generators used and reproduce the song from the seed.
    let forcedRules: [String: String]
    /// User-set overrides active when the song was generated. nil = value came from RNG naturally.
    /// Written to the log file as "Key Override:", "Tempo Override:", "Mood Override:" so that
    /// Load Song re-applies ONLY these — never the informational Key:/Tempo:/Mood: result fields.
    let keyOverride:   String?
    let tempoOverride: Int?
    let moodOverride:  Mood?
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
        ambientXFilesBlockRange: Range<Int>? = nil,
        ambientUseBrushKit: Bool = false,
        forcedRules: [String: String] = [:],
        keyOverride:   String? = nil,
        tempoOverride: Int?    = nil,
        moodOverride:  Mood?   = nil
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
        self.ambientUseBrushKit      = ambientUseBrushKit
        self.forcedRules             = forcedRules
        self.keyOverride             = keyOverride
        self.tempoOverride           = tempoOverride
        self.moodOverride            = moodOverride
        self.generationLog           = generationLog
        self.stepAnnotations    = stepAnnotations
    }

    // MARK: - Convenience

    func events(forTrack trackIndex: Int) -> [MIDIEvent] {
        guard trackIndex < trackEvents.count else { return [] }
        return trackEvents[trackIndex]
    }

    /// Returns a copy of this state with ambientUseBrushKit updated (used when user cycles drum kit).
    func withAmbientBrushKit(_ useBrushKit: Bool) -> SongState {
        SongState(frame: frame, structure: structure, tonalMap: tonalMap,
                  trackEvents: trackEvents, globalSeed: globalSeed,
                  trackOverrides: trackOverrides, title: title, form: form, style: style,
                  percussionStyle: percussionStyle, kosmicProgFamily: kosmicProgFamily,
                  generationLog: generationLog, stepAnnotations: stepAnnotations,
                  ambientProgFamily: ambientProgFamily, ambientLoopLengths: ambientLoopLengths,
                  ambientXFilesBlockRange: ambientXFilesBlockRange,
                  ambientUseBrushKit: useBrushKit, forcedRules: forcedRules,
                  keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride)
    }

    /// Returns a copy of this state with the frame replaced (used for real-time tempo changes).
    func withFrame(_ newFrame: GlobalMusicalFrame) -> SongState {
        SongState(frame: newFrame, structure: structure, tonalMap: tonalMap,
                  trackEvents: trackEvents, globalSeed: globalSeed,
                  trackOverrides: trackOverrides, title: title, form: form, style: style,
                  percussionStyle: percussionStyle, kosmicProgFamily: kosmicProgFamily,
                  generationLog: generationLog, stepAnnotations: stepAnnotations,
                  ambientProgFamily: ambientProgFamily, ambientLoopLengths: ambientLoopLengths,
                  ambientXFilesBlockRange: ambientXFilesBlockRange,
                  ambientUseBrushKit: ambientUseBrushKit, forcedRules: forcedRules,
                  keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride)
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
            ambientXFilesBlockRange: ambientXFilesBlockRange,
            ambientUseBrushKit: ambientUseBrushKit, forcedRules: forcedRules,
            keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride
        )
    }
}
