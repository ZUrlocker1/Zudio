// SongState.swift — complete song state held in memory while a song is loaded
// Copyright (c) 2026 Zack Urlocker

// MARK: - Generation log

struct GenerationLogEntry: Sendable {
    let tag: String
    let description: String
    var isTitle: Bool = false

    /// TESTING ONLY. Rules that are new or changed in the current round, marked with "* " in the
    /// generation log so Zack can spot them while listening ("MOT-LD1-001 * Hallogallo hook").
    /// Add each new or changed rule ID as it lands. Empty this set when Zack says testing is
    /// done, the rules are final, or the build is going to the App Store.
    static let testingMarkedRules: Set<String> = [
        "MOT-LD1-001", "MOT-LD1-002", "MOT-LD1-003", "MOT-LD1-006",
        "MOT-LD1-007", "MOT-LD1-008",
        "MOT-LD2-001", "MOT-LD2-002", "MOT-LD2-003", "MOT-LD2-004", "MOT-LD2-006",
        "KOS-LD1-001", "KOS-LD1-005", "KOS-LD1-007",
        "KOS-LD2-002", "KOS-LD2-003", "KOS-LD2-004", "KOS-LD2-005",
        "CHL-LD1-001", "CHL-LD1-007", "CHL-LD1-008", "CHL-LD1-013", "CHL-LD1-014", "CHL-LD1-015",
        "CHL-LD2-002", "CHL-LD2-003", "CHL-LD2-004", "CHL-LD2-005", "CHL-LD2-006",
    ]

    init(tag: String, description: String, isTitle: Bool = false) {
        self.tag = tag
        self.description = Self.testingMarkedRules.contains(tag) && !description.hasPrefix("* ")
            ? "* " + description : description
        self.isTitle = isTitle
    }
}

// MARK: - Solo windows

/// The bars where Motorik Lead 1 plays its MOT-LD1-007 or 008 solo: the full window and the
/// shorter returns. Kept on the song because the ranges are drawn once, with Lead 1, and a later
/// Lead 2 regen needs the same bars to answer or stay silent as generation did.
struct SoloWindows: Equatable, Sendable {
    var main: Range<Int>? = nil
    var short: [Range<Int>] = []

    static let none = SoloWindows()

    var isEmpty: Bool { main == nil }

    /// The full solo first, then its shorter returns.
    var ranges: [Range<Int>] { (main.map { [$0] } ?? []) + short }

    var allBars: Set<Int> { Set(ranges.flatMap { Array($0) }) }

    func contains(bar: Int) -> Bool { ranges.contains { $0.contains(bar) } }

    func overlaps(_ bars: Range<Int>) -> Bool { ranges.contains { $0.overlaps(bars) } }
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
    var title: String
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
    /// Chill-only: progression family selected at generation time.
    let chillProgFamily: ChillProgressionFamily
    /// Chill-only: lead instrument assigned at frame generation time (same for entire song).
    let chillLeadInstrument: ChillLeadInstrument
    /// Chill-only: Lead 2 counter-melody instrument assigned at generation time.
    let chillLead2Instrument: ChillLeadInstrument
    /// Chill-only: drum/beat style assigned at frame generation time.
    let chillBeatStyle: ChillBeatStyle
    /// Chill-only: breakdown texture style selected at generation time.
    let chillBreakdownStyle: ChillBreakdownStyle
    /// Chill-only: true when swing feel is applied (Bright/Free moods).
    let chillSwingFeel: Bool
    /// Chill-only: true when the Blues Chill variation is active (Dorian mode, blues chord cycle, blues drums/bass).
    let chillBluesVariation: Bool
    /// Chill-only: true when the Chill Soho variation is active (Sade / EBTG / Style Council —
    /// Latin or soul groove, extended-chord vamp, sax answering a vocal-shaped lead).
    /// Mutually exclusive with `chillBluesVariation`. See docs/chill-soho-plan.md.
    let chillSohoVariation: Bool
    /// Motorik-only: true when the Motorik Noir sub-style is active (dark minor, low BPM, sparse melodic lead).
    let motorikNoirVariation: Bool
    /// Motorik-only: true when the Motorik Arcade sub-style is active (4-on-floor, arpeggios, bright modes).
    let motorikArcadeVariation: Bool
    /// Kraftwerk-flavoured track sync; `.none` for the great majority of songs.
    let motorikSync: MotorikSync
    /// Motorik (non-Noir) only: true when bass distortion is applied for this song (~20% of regular Motorik songs).
    /// Defaults to false so old saved songs never get unexpected distortion.
    let motorikBassDistortion: Bool
    /// Motorik Noir only: true when bass distortion is on for this song (~75% of Noir songs).
    let motorikNoirBassDistortion: Bool
    /// Motorik Noir only: true when rhythm distortion is on for this song (~75% of Noir songs).
    let motorikNoirRhythmDistortion: Bool
    /// Kosmic-only: true when the Kosmic Drift sub-style is active (70–90 BPM, loping groove, meditative).
    let isKosmicDrift: Bool
    /// Kosmic Drift only: true when the Dreamscape variant is active (Floating snare + Four-Bar Hold + Svefn Float).
    let isDriftDreamscape: Bool
    /// Kosmic-only: true when the Kosmic Space sub-style is active (Jean-Michel Jarre — locked
    /// sequencer over fast minor chord cycles, preset rhythm box). See docs/kosmic-space-plan.md.
    let isKosmicSpace: Bool
    /// Ambient-only: true when the Ambient Piano sub-style is active (sparse piano, near-silence).
    let isAmbientPiano: Bool
    /// Ambient Piano rule selected at generation time. "AMB-PNO-001" / "AMB-PNO-002" / "AMB-PNO-003"; "" otherwise.
    let ambientPianoRule: String
    /// Chill-only: audio texture filename selected at generation time (nil = no texture).
    let chillAudioTexture: String?
    /// Chill-only: playback start offset in seconds (0, 15, 30, or 45) for audio texture.
    let chillAudioTextureOffset: Int
    /// Ambient-only: audio texture filename when drums are absent (nil = MIDI texture).
    let ambientAudioTexture: String?
    /// Ambient-only: playback start offset in seconds (0, 15, 30, or 45) for audio texture.
    let ambientAudioTextureOffset: Int
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
    /// Motorik only: where Lead 1's solo plays (`.none` for every other song). Set by generation
    /// and by a Lead 1 regen; a Lead 2 regen reads it.
    var soloWindows: SoloWindows
    /// Ordered log entries built by SongGenerator; rendered by StatusBoxView.
    var generationLog: [GenerationLogEntry]
    /// Live playback annotations keyed by absolute step index. Each entry fires when playback
    /// reaches that step, giving precise timing (e.g. fills fire 2 beats before the hit).
    let stepAnnotations: [Int: [GenerationLogEntry]]

    // MARK: - Display helpers

    /// Style name for UI display. Returns the substyle name when a substyle is active
    /// (e.g. "Chill Blues" instead of "Chill"). Add new substyle cases here as they are implemented.
    var displayStyleName: String {
        if isAmbientPiano { return "Ambient Piano" }
        if chillBluesVariation { return "Chill Blues" }
        if chillSohoVariation { return "Chill Soho" }
        if motorikNoirVariation { return "Motorik Noir" }
        if motorikArcadeVariation { return "Motorik Arcade" }
        if motorikSync.isActive { return "Motorik Europe" }
        if isKosmicSpace { return "Kosmic Space" }
        if isKosmicDrift { return "Kosmic Drift" }
        return style.rawValue.capitalized
    }

    /// Kosmic Space KOS-LD2-001 Magnetic Twin's stereo variant: Lead 2 replays Rhythm's notes. Found
    /// from the notes rather than the log, so it holds after a regen and a reload; the harmonic filter
    /// may drop a few of the twin's notes, hence the 80 and 90% thresholds. The late-octave variant
    /// doubles Lead 1 and shares few onsets with Rhythm.
    var isSpaceStereoTwin: Bool {
        guard isKosmicSpace, trackEvents.count > kTrackRhythm else { return false }
        let twin = trackEvents[kTrackLead2]
        // The twin rests in B sections, so compare with Rhythm's notes outside them
        let rhythm = trackEvents[kTrackRhythm].filter { structure.section(atBar: $0.stepIndex / 16)?.label != .B }
        guard twin.count >= 16, twin.count * 10 >= rhythm.count * 8 else { return false }
        let onsets = Set(rhythm.map(\.stepIndex))
        return twin.filter { onsets.contains($0.stepIndex) }.count * 10 >= twin.count * 9
    }

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
        chillProgFamily: ChillProgressionFamily = .static_groove,
        chillLeadInstrument: ChillLeadInstrument = .flute,
        chillLead2Instrument: ChillLeadInstrument = .vibraphone,
        chillBeatStyle: ChillBeatStyle = .electronic,
        chillBreakdownStyle: ChillBreakdownStyle = .bassOstinato,
        chillSwingFeel: Bool = false,
        chillBluesVariation: Bool = false,
        chillSohoVariation: Bool = false,
        motorikNoirVariation: Bool = false,
        motorikArcadeVariation: Bool = false,
        motorikSync: MotorikSync = .none,
        motorikBassDistortion: Bool = false,
        motorikNoirBassDistortion: Bool = false,
        motorikNoirRhythmDistortion: Bool = false,
        isKosmicDrift: Bool = false,
        isDriftDreamscape: Bool = false,
        isKosmicSpace: Bool = false,
        isAmbientPiano: Bool = false,
        ambientPianoRule: String = "",
        chillAudioTexture: String? = nil,
        chillAudioTextureOffset: Int = 0,
        ambientAudioTexture: String? = nil,
        ambientAudioTextureOffset: Int = 0,
        forcedRules: [String: String] = [:],
        keyOverride:   String? = nil,
        tempoOverride: Int?    = nil,
        moodOverride:  Mood?   = nil,
        soloWindows: SoloWindows = .none
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
        self.chillProgFamily         = chillProgFamily
        self.chillLeadInstrument     = chillLeadInstrument
        self.chillLead2Instrument    = chillLead2Instrument
        self.chillBeatStyle          = chillBeatStyle
        self.chillBreakdownStyle     = chillBreakdownStyle
        self.chillSwingFeel          = chillSwingFeel
        self.chillBluesVariation     = chillBluesVariation
        self.chillSohoVariation      = chillSohoVariation
        self.motorikNoirVariation        = motorikNoirVariation
        self.motorikArcadeVariation      = motorikArcadeVariation
        self.motorikSync              = motorikSync
        self.motorikBassDistortion       = motorikBassDistortion
        self.motorikNoirBassDistortion   = motorikNoirBassDistortion
        self.motorikNoirRhythmDistortion = motorikNoirRhythmDistortion
        self.isKosmicDrift               = isKosmicDrift
        self.isDriftDreamscape       = isDriftDreamscape
        self.isKosmicSpace           = isKosmicSpace
        self.isAmbientPiano          = isAmbientPiano
        self.ambientPianoRule        = ambientPianoRule
        self.chillAudioTexture        = chillAudioTexture
        self.chillAudioTextureOffset  = chillAudioTextureOffset
        self.ambientAudioTexture      = ambientAudioTexture
        self.ambientAudioTextureOffset = ambientAudioTextureOffset
        self.forcedRules             = forcedRules
        self.keyOverride             = keyOverride
        self.tempoOverride           = tempoOverride
        self.moodOverride            = moodOverride
        self.soloWindows             = soloWindows
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
                  ambientUseBrushKit: useBrushKit,
                  chillProgFamily: chillProgFamily, chillLeadInstrument: chillLeadInstrument,
                  chillLead2Instrument: chillLead2Instrument,
                  chillBeatStyle: chillBeatStyle, chillBreakdownStyle: chillBreakdownStyle, chillSwingFeel: chillSwingFeel,
                  chillBluesVariation: chillBluesVariation, chillSohoVariation: chillSohoVariation, motorikNoirVariation: motorikNoirVariation,
                  motorikArcadeVariation: motorikArcadeVariation,
                  motorikSync: motorikSync,
                  motorikBassDistortion: motorikBassDistortion,
                  motorikNoirBassDistortion: motorikNoirBassDistortion,
                  motorikNoirRhythmDistortion: motorikNoirRhythmDistortion,
                  isKosmicDrift: isKosmicDrift, isDriftDreamscape: isDriftDreamscape,
                  isKosmicSpace: isKosmicSpace,
                  isAmbientPiano: isAmbientPiano, ambientPianoRule: ambientPianoRule,
                  chillAudioTexture: chillAudioTexture, chillAudioTextureOffset: chillAudioTextureOffset,
                  ambientAudioTexture: ambientAudioTexture, ambientAudioTextureOffset: ambientAudioTextureOffset,
                  forcedRules: forcedRules,
                  keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride,
                  soloWindows: soloWindows)
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
                  ambientUseBrushKit: ambientUseBrushKit,
                  chillProgFamily: chillProgFamily, chillLeadInstrument: chillLeadInstrument,
                  chillLead2Instrument: chillLead2Instrument,
                  chillBeatStyle: chillBeatStyle, chillBreakdownStyle: chillBreakdownStyle, chillSwingFeel: chillSwingFeel,
                  chillBluesVariation: chillBluesVariation, chillSohoVariation: chillSohoVariation, motorikNoirVariation: motorikNoirVariation,
                  motorikArcadeVariation: motorikArcadeVariation,
                  motorikSync: motorikSync,
                  motorikBassDistortion: motorikBassDistortion,
                  motorikNoirBassDistortion: motorikNoirBassDistortion,
                  motorikNoirRhythmDistortion: motorikNoirRhythmDistortion,
                  isKosmicDrift: isKosmicDrift, isDriftDreamscape: isDriftDreamscape,
                  isKosmicSpace: isKosmicSpace,
                  isAmbientPiano: isAmbientPiano, ambientPianoRule: ambientPianoRule,
                  chillAudioTexture: chillAudioTexture, chillAudioTextureOffset: chillAudioTextureOffset,
                  ambientAudioTexture: ambientAudioTexture, ambientAudioTextureOffset: ambientAudioTextureOffset,
                  forcedRules: forcedRules,
                  keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride,
                  soloWindows: soloWindows)
    }

    /// Returns a copy of this state with the ambient audio texture updated (regen / generation).
    func withAmbientAudioTexture(_ texture: String?, offset: Int = 0) -> SongState {
        SongState(frame: frame, structure: structure, tonalMap: tonalMap,
                  trackEvents: trackEvents, globalSeed: globalSeed,
                  trackOverrides: trackOverrides, title: title, form: form, style: style,
                  percussionStyle: percussionStyle, kosmicProgFamily: kosmicProgFamily,
                  generationLog: generationLog, stepAnnotations: stepAnnotations,
                  ambientProgFamily: ambientProgFamily, ambientLoopLengths: ambientLoopLengths,
                  ambientXFilesBlockRange: ambientXFilesBlockRange,
                  ambientUseBrushKit: ambientUseBrushKit,
                  chillProgFamily: chillProgFamily, chillLeadInstrument: chillLeadInstrument,
                  chillLead2Instrument: chillLead2Instrument,
                  chillBeatStyle: chillBeatStyle, chillBreakdownStyle: chillBreakdownStyle, chillSwingFeel: chillSwingFeel,
                  chillBluesVariation: chillBluesVariation, chillSohoVariation: chillSohoVariation, motorikNoirVariation: motorikNoirVariation,
                  motorikArcadeVariation: motorikArcadeVariation,
                  motorikSync: motorikSync,
                  motorikBassDistortion: motorikBassDistortion,
                  motorikNoirBassDistortion: motorikNoirBassDistortion,
                  motorikNoirRhythmDistortion: motorikNoirRhythmDistortion,
                  isKosmicDrift: isKosmicDrift, isDriftDreamscape: isDriftDreamscape,
                  isKosmicSpace: isKosmicSpace,
                  isAmbientPiano: isAmbientPiano, ambientPianoRule: ambientPianoRule,
                  chillAudioTexture: chillAudioTexture, chillAudioTextureOffset: chillAudioTextureOffset,
                  ambientAudioTexture: texture, ambientAudioTextureOffset: offset,
                  forcedRules: forcedRules,
                  keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride,
                  soloWindows: soloWindows)
    }

    /// Returns a copy of this state with the audio texture filename updated (user selection).
    func withChillAudioTexture(_ texture: String?) -> SongState {
        SongState(frame: frame, structure: structure, tonalMap: tonalMap,
                  trackEvents: trackEvents, globalSeed: globalSeed,
                  trackOverrides: trackOverrides, title: title, form: form, style: style,
                  percussionStyle: percussionStyle, kosmicProgFamily: kosmicProgFamily,
                  generationLog: generationLog, stepAnnotations: stepAnnotations,
                  ambientProgFamily: ambientProgFamily, ambientLoopLengths: ambientLoopLengths,
                  ambientXFilesBlockRange: ambientXFilesBlockRange,
                  ambientUseBrushKit: ambientUseBrushKit,
                  chillProgFamily: chillProgFamily, chillLeadInstrument: chillLeadInstrument,
                  chillLead2Instrument: chillLead2Instrument,
                  chillBeatStyle: chillBeatStyle, chillBreakdownStyle: chillBreakdownStyle, chillSwingFeel: chillSwingFeel,
                  chillBluesVariation: chillBluesVariation, chillSohoVariation: chillSohoVariation, motorikNoirVariation: motorikNoirVariation,
                  motorikArcadeVariation: motorikArcadeVariation,
                  motorikSync: motorikSync,
                  motorikBassDistortion: motorikBassDistortion,
                  motorikNoirBassDistortion: motorikNoirBassDistortion,
                  motorikNoirRhythmDistortion: motorikNoirRhythmDistortion,
                  isKosmicDrift: isKosmicDrift, isDriftDreamscape: isDriftDreamscape,
                  isKosmicSpace: isKosmicSpace,
                  isAmbientPiano: isAmbientPiano, ambientPianoRule: ambientPianoRule,
                  chillAudioTexture: texture, chillAudioTextureOffset: chillAudioTextureOffset,
                  ambientAudioTexture: ambientAudioTexture, ambientAudioTextureOffset: ambientAudioTextureOffset,
                  forcedRules: forcedRules,
                  keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride,
                  soloWindows: soloWindows)
    }

    /// Convenience initializer for synthetic pass/extended states: carries all style-specific
    /// fields from an anchor, resetting trackOverrides to empty and ambientXFilesBlockRange to nil. The caller supplies only the
    /// structural fields that differ (frame, structure, trackEvents, generationLog, stepAnnotations).
    init(frame: GlobalMusicalFrame,
         structure: SongStructure,
         trackEvents: [[MIDIEvent]],
         generationLog: [GenerationLogEntry],
         stepAnnotations: [Int: [GenerationLogEntry]],
         copyingStyleFieldsFrom anchor: SongState) {
        self.init(frame: frame, structure: structure, tonalMap: anchor.tonalMap,
                  trackEvents: trackEvents, globalSeed: anchor.globalSeed,
                  trackOverrides: [:], title: anchor.title, form: anchor.form,
                  style: anchor.style, percussionStyle: anchor.percussionStyle,
                  kosmicProgFamily: anchor.kosmicProgFamily,
                  generationLog: generationLog, stepAnnotations: stepAnnotations,
                  ambientProgFamily: anchor.ambientProgFamily,
                  ambientLoopLengths: anchor.ambientLoopLengths,
                  ambientUseBrushKit: anchor.ambientUseBrushKit,
                  chillProgFamily: anchor.chillProgFamily,
                  chillLeadInstrument: anchor.chillLeadInstrument,
                  chillLead2Instrument: anchor.chillLead2Instrument,
                  chillBeatStyle: anchor.chillBeatStyle,
                  chillBreakdownStyle: anchor.chillBreakdownStyle,
                  chillSwingFeel: anchor.chillSwingFeel,
                  chillBluesVariation: anchor.chillBluesVariation, chillSohoVariation: anchor.chillSohoVariation,
                  motorikNoirVariation: anchor.motorikNoirVariation,
                  motorikArcadeVariation: anchor.motorikArcadeVariation,
                  motorikSync: anchor.motorikSync,
                  motorikBassDistortion: anchor.motorikBassDistortion,
                  motorikNoirBassDistortion: anchor.motorikNoirBassDistortion,
                  motorikNoirRhythmDistortion: anchor.motorikNoirRhythmDistortion,
                  isKosmicDrift: anchor.isKosmicDrift, isDriftDreamscape: anchor.isDriftDreamscape,
                  isKosmicSpace: anchor.isKosmicSpace,
                  isAmbientPiano: anchor.isAmbientPiano, ambientPianoRule: anchor.ambientPianoRule,
                  chillAudioTexture: anchor.chillAudioTexture,
                  chillAudioTextureOffset: anchor.chillAudioTextureOffset,
                  ambientAudioTexture: anchor.ambientAudioTexture,
                  ambientAudioTextureOffset: anchor.ambientAudioTextureOffset,
                  // The forced rules and overrides are what a saved file needs to rebuild the
                  // song from its seed. Without them a song saved mid-Evolve reopened as a
                  // different song whenever it had been generated with any (2026-10-19).
                  forcedRules: anchor.forcedRules,
                  keyOverride: anchor.keyOverride, tempoOverride: anchor.tempoOverride,
                  moodOverride: anchor.moodOverride)
    }

    /// A copy with the Chill lead instruments replaced. Evolve pass 1 regenerates the leads for
    /// the instruments it is about to switch to: Chill leads are written for their instrument's
    /// register and phrasing, so they must be generated for the patch that will play them.
    func withChillLeadInstruments(_ lead1: ChillLeadInstrument, _ lead2: ChillLeadInstrument) -> SongState {
        SongState(frame: frame, structure: structure, tonalMap: tonalMap,
                  trackEvents: trackEvents, globalSeed: globalSeed,
                  trackOverrides: trackOverrides, title: title, form: form, style: style,
                  percussionStyle: percussionStyle, kosmicProgFamily: kosmicProgFamily,
                  generationLog: generationLog, stepAnnotations: stepAnnotations,
                  ambientProgFamily: ambientProgFamily, ambientLoopLengths: ambientLoopLengths,
                  ambientXFilesBlockRange: ambientXFilesBlockRange,
                  ambientUseBrushKit: ambientUseBrushKit,
                  chillProgFamily: chillProgFamily, chillLeadInstrument: lead1,
                  chillLead2Instrument: lead2,
                  chillBeatStyle: chillBeatStyle, chillBreakdownStyle: chillBreakdownStyle, chillSwingFeel: chillSwingFeel,
                  chillBluesVariation: chillBluesVariation, chillSohoVariation: chillSohoVariation, motorikNoirVariation: motorikNoirVariation,
                  motorikArcadeVariation: motorikArcadeVariation,
                  motorikSync: motorikSync,
                  motorikBassDistortion: motorikBassDistortion,
                  motorikNoirBassDistortion: motorikNoirBassDistortion,
                  motorikNoirRhythmDistortion: motorikNoirRhythmDistortion,
                  isKosmicDrift: isKosmicDrift, isDriftDreamscape: isDriftDreamscape,
                  isKosmicSpace: isKosmicSpace,
                  isAmbientPiano: isAmbientPiano, ambientPianoRule: ambientPianoRule,
                  chillAudioTexture: chillAudioTexture, chillAudioTextureOffset: chillAudioTextureOffset,
                  ambientAudioTexture: ambientAudioTexture, ambientAudioTextureOffset: ambientAudioTextureOffset,
                  forcedRules: forcedRules,
                  keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride,
                  soloWindows: soloWindows)
    }

    /// Returns a copy of this state with one track's events replaced.
    /// The generation log is carried through unchanged (reflects the full generation).
    func replacingEvents(_ events: [MIDIEvent], forTrack trackIndex: Int) -> SongState {
        replacingEvents(events, forTrack: trackIndex, appendingLog: [])
    }

    /// Returns a copy of this state with one track's events replaced and extra log entries appended.
    /// `replacingStepAnnotations`, when given, replaces stepAnnotations entirely instead of
    /// carrying the old ones over verbatim — used when a track regen needs to drop stale
    /// per-bar annotations (e.g. Chill Blues bass variation bars) tied to the rule it just replaced.
    func replacingEvents(_ events: [MIDIEvent], forTrack trackIndex: Int, appendingLog extra: [GenerationLogEntry],
                         replacingStepAnnotations: [Int: [GenerationLogEntry]]? = nil) -> SongState {
        var updated = trackEvents
        if trackIndex < updated.count { updated[trackIndex] = events }
        return SongState(
            frame: frame, structure: structure, tonalMap: tonalMap,
            trackEvents: updated, globalSeed: globalSeed,
            trackOverrides: trackOverrides, title: title, form: form, style: style,
            percussionStyle: percussionStyle, kosmicProgFamily: kosmicProgFamily,
            generationLog: generationLog + extra,
            stepAnnotations: replacingStepAnnotations ?? stepAnnotations,
            ambientProgFamily: ambientProgFamily, ambientLoopLengths: ambientLoopLengths,
            ambientXFilesBlockRange: ambientXFilesBlockRange,
            ambientUseBrushKit: ambientUseBrushKit,
            chillProgFamily: chillProgFamily, chillLeadInstrument: chillLeadInstrument,
            chillLead2Instrument: chillLead2Instrument,
            chillBeatStyle: chillBeatStyle, chillBreakdownStyle: chillBreakdownStyle, chillSwingFeel: chillSwingFeel,
            chillBluesVariation: chillBluesVariation, chillSohoVariation: chillSohoVariation, motorikNoirVariation: motorikNoirVariation,
            motorikArcadeVariation: motorikArcadeVariation, motorikSync: motorikSync,
            motorikBassDistortion: motorikBassDistortion,
            motorikNoirBassDistortion: motorikNoirBassDistortion,
            motorikNoirRhythmDistortion: motorikNoirRhythmDistortion,
            isKosmicDrift: isKosmicDrift, isDriftDreamscape: isDriftDreamscape,
            isKosmicSpace: isKosmicSpace,
            isAmbientPiano: isAmbientPiano, ambientPianoRule: ambientPianoRule,
            chillAudioTexture: chillAudioTexture, chillAudioTextureOffset: chillAudioTextureOffset,
            ambientAudioTexture: ambientAudioTexture, ambientAudioTextureOffset: ambientAudioTextureOffset,
            forcedRules: forcedRules,
            keyOverride: keyOverride, tempoOverride: tempoOverride, moodOverride: moodOverride,
            soloWindows: soloWindows
        )
    }
}
