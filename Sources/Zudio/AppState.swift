// AppState.swift — global observable app state, shared across all views

import SwiftUI
import AppKit
import Combine
import MediaPlayer
import UniformTypeIdentifiers

// MARK: - Play mode

enum PlayMode: String, Hashable { case song, endless, evolve }

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {
    // MARK: - Song state

    @Published var songState: SongState? = nil
    @Published var isGenerating: Bool = false

    /// URL queued for loading if a file-open arrives while generation is in progress.
    /// Consumed once generation completes.
    private var pendingLoadURL: URL? = nil

    // MARK: - Generation history (SongState tracking for regen/export/playback)

    @Published var generationHistory: [SongState] = []

    // MARK: - Flat status log — single append-only source for StatusBoxView.
    // Everything writes here in chronological order: initial generation entries,
    // live bar annotations, and regen entries all go to the end.

    @Published var statusLog: [GenerationLogEntry] = []

    // Incremented on every write to statusLog (append or remove). StatusBoxView
    // observes this instead of statusLog.count so onChange fires even when the
    // net count is unchanged (e.g. simultaneous append+trim).
    @Published var statusLogVersion: Int = 0

    // MARK: - Visible window — zoom + DAW scroll

    @Published var visibleBars: Int = 16
    @Published var visibleBarOffset: Int = 0

    // MARK: - Style selector

    @Published var selectedStyle: MusicStyle = .chill

    // MARK: - Play mode (Song / Endless)

    @Published var playMode: PlayMode = .song {
        didSet {
            guard playMode != oldValue else { return }
            if oldValue == .evolve { tearDownEvolve() }
            switch playMode {
            case .song:
                // Cancel pending pre-gen; song end callback is guarded and will no-op
                nextSongState            = nil
                isPreGenerating          = false
                shouldLogNextUpWhenReady = false
                upNextLogged             = false
            case .evolve:
                if let current = songState { startEvolveMode(from: current) }
            case .endless:
                // Sync style axis to the currently playing style so shifts are relative to it
                songsInCurrentStyle = 1
                if let idx = endlessStyleAxis.firstIndex(of: selectedStyle) {
                    endlessStyleIndex = idx
                }
                // Kick off pre-gen immediately — covers the case where the 8-bar trigger
                // already fired while in Song mode (approachingEndFired=true, skipped then)
                preGenerateNextSong()
            }
        }
    }

    // Song history — last 10 seeds, populated in both modes, used by ⏮ back navigation
    struct SongHistoryEntry {
        let seed:  UInt64
        let style: MusicStyle
        let title: String
    }
    private var songHistory:      [SongHistoryEntry] = []
    private let songHistoryLimit = 10

    // Endless style continuum: fixed axis, movement ±1 only
    private let endlessStyleAxis: [MusicStyle] = [.ambient, .chill, .kosmic, .motorik]
    private var endlessStyleIndex: Int = 1    // start at Chill
    private var songsInCurrentStyle: Int = 0

    // Pre-generated next song for seamless Endless transitions
    private var nextSongState:         SongState? = nil
    private var isPreGenerating:       Bool       = false
    // Set by onApproachingEnd so preGenerateNextSong() logs "Up next" when it finishes.
    // Kept false for silent pre-gen calls (generateNew, startEndlessSong).
    private var shouldLogNextUpWhenReady = false
    // Tracks whether "Up next" has been logged for the current pre-genned song,
    // so skipToNextSong() can log it immediately without duplicating.
    private var upNextLogged = false

    // Evolve mode state
    private enum EvolvePhase { case inactive, original, pass1, pass2, outro }
    private var evolvePhase:           EvolvePhase = .inactive
    private var evolveAnchorState:     SongState?  = nil
    private var evolveMoodAnchor:      Mood?       = nil   // mood override for the next song; nil = free choice
    private var evolveTempoAnchor:     Int         = 0
    private var evolvePass1Bars:       Int         = 0
    private var evolvePass2Bars:       Int         = 0
    private var evolvePass1State:      SongState?  = nil
    private var evolvePass2State:      SongState?  = nil
    private var evolveNextSongState:       SongState?  = nil
    private var evolveIsPreGenerating:     Bool        = false
    private var evolveNextSongShouldLog:   Bool        = false  // set at 12-bar mark; tells preGen to log when ready
    private var evolveNextSongLogged:      Bool        = false  // prevents duplicate "Up next" at transition
    // Incremented on each evolve phase switch so the scrollbar recreates itself even when
    // totalBars hasn't changed (e.g. preGeneratePassContent(pass: 2) already extended songState).
    @Published var evolvePhaseToken: Int = 0
    // Incremented by switchEvolveInstruments so TrackRowView refreshes the instrument name display.
    @Published var instrumentChangeToken: Int = 0

    // Incremented to signal TrackRowViews to reset instruments + effects to style defaults.
    // Fired on generateNew() and on the manual Reset button.
    @Published var defaultsResetToken: Int = 0

    /// Full clean-state reset — equivalent to a fresh app launch.
    /// Resets style, clears song, clears history, restores first-best-song behavior,
    /// resets all overrides, and re-enumerates the audio output device.
    func resetTrackDefaults() {
        // Stop playback and audio texture before tearing down state
        stop()
        audioTexture.stop()

        // Clear the current song and all history
        songState         = nil
        generationHistory = []
        statusLog         = []
        statusLogVersion += 1
        lastEmittedStep   = -1
        visibleBarOffset  = 0
        playback.resetPlayhead()

        // Restore first-best-song behavior for all styles
        stylesWithGeneratedSongs = []
        songGenerationCount      = 0

        // Reset Endless / Evolve mode state
        playMode             = .song
        songHistory          = []
        nextSongState        = nil
        isPreGenerating      = false
        songsInCurrentStyle  = 0
        endlessStyleIndex    = 1
        tearDownEvolve()

        // Reset style to default
        selectedStyle = .chill

        // Reset all overrides
        instrumentOverrides = [:]
        keyOverride         = nil
        tempoOverride       = nil
        moodOverride        = nil

        // Reset mute/solo
        muteState = Array(repeating: false, count: kTrackCount)
        soloState = Array(repeating: false, count: kTrackCount)
        playback.muteState = muteState
        playback.soloState = soloState

        // Restart audio engine so macOS picks up any newly connected output device
        playback.restartAudio()

        // Clear Now Playing so the system knows no song is loaded
        nowPlaying.update(song: nil, isPlaying: false, currentStep: 0)

        // Fire token last — signals TrackRowViews to reset their instrument/effect UI
        defaultsResetToken += 1
    }

    // MARK: - UI selectors (nil = Auto)

    @Published var keyOverride:   String? = nil
    @Published var tempoOverride: Int?    = nil
    @Published var moodOverride:  Mood?   = nil

    // MARK: - Test mode (shorter songs cycling through recently-introduced rules)
    // Each generation advances to the next slot in testCycle.
    // Slot 0: ARP-005*, BASS-010*, PADS-007*   (all three new rules together)
    // Slot 1: ARP-001*, free BASS, free PADS    (ARP retrofit, everything else random)
    // Slot 2: ARP-002*, BASS-010*, PADS-007*    (second ARP retrofit + BASS/PADS repeat)

    struct TestModeConfig {
        var forceArpRuleID:        String?
        var forceBassRuleID:       String?
        var forceDrumRuleID:       String?
        var forcePadsRuleID:       String?
        var forceLeadRuleID:       String?
        var forceTexRuleID:        String?
        var forcePercussionStyle:  PercussionStyle?
        // Bridge testing: forceBridge=true guarantees a bridge fires (bypasses 35% gate).
        // forceBridgeArchetype: nil=random, "drum"=A-1 escalating, "drumAlt"=A-2 call+response, "melody"=Archetype B
        var forceBridge:           Bool    = false
        var forceBridgeArchetype:  String? = nil
    }

    @Published var testModeEnabled: Bool = false
    private var testCycleIndex: Int = 0

    func toggleTestMode() {
        testModeEnabled.toggle()
        testCycleIndex = 0
    }

    // Motorik 10-slot cycle: alternates MOT-LD1-003 (Punch Solo) and MOT-LD1-006 (Long Arc).
    // Slot 0: MOT-LD1-003* lead   [Punch solo]
    // Slot 1: MOT-LD1-006* lead   [Long arc solo]
    // Slot 2: MOT-LD1-003* lead   [Punch solo]
    // Slot 3: MOT-LD1-006* lead   [Long arc solo]
    // Slot 4: MOT-LD1-003* lead   [Punch solo]
    // Slot 5: MOT-LD1-006* lead   [Long arc solo]
    // Slot 6: MOT-LD1-003* lead   [Punch solo]
    // Slot 7: MOT-LD1-006* lead   [Long arc solo]
    // Slot 8: MOT-LD1-003* lead   [Punch solo]
    // Slot 9: MOT-LD1-006* lead   [Long arc solo]
    private static let testCycle: [TestModeConfig] = [
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-003", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-006", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-003", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-006", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-003", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-006", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-003", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-006", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-003", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-006", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
    ]

    // Ambient 12-slot cycle: exercises all lead rules, bass rules, and rhythm rules.
    // Slots 0–4: Lead 1 rules (floating, echo, shimmer, lyric fragment, returning motif)
    // Slot  5:   AMB-BASS-001* — root drone with Plan L neighbour-tone inflections
    // Slot  6:   AMB-BASS-003* — root+fifth drone
    // Slot  7:   AMB-RTHM-005* — celestial phrase (ascending pentatonic on Rhythm)
    // Slot  8:   AMB-RTHM-006* — Craven Faults bell cell (root/fifth/octave)
    // Slot  9:   softPulse drums / floating lead (drum style variation)
    // Slot 10:   absent drums (confirms pads+bass+lead carry the song without percussion)
    // Slot 11:   all random (let the generator pick freely)
    private static let ambientTestCycle: [TestModeConfig] = [
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-009", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-010", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-009", forceTexRuleID: nil, forcePercussionStyle: .softPulse, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-010", forceTexRuleID: nil, forcePercussionStyle: .softPulse, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-001", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-002", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-007", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-008", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: "AMB-BASS-001", forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-009", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-001", forceTexRuleID: nil, forcePercussionStyle: .softPulse, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: nil,            forceTexRuleID: nil, forcePercussionStyle: .absent,    forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: nil,            forceTexRuleID: nil, forcePercussionStyle: nil,         forceBridge: false, forceBridgeArchetype: nil),
    ]

    // Kosmic 10-slot cycle: high rotation on the two new texture rules only. All other
    // fields free (nil) so the generator picks leads, bass, arp, drums naturally.
    // Slot 0: KOS-TEXT-002*  [Distant Pulse]
    // Slot 1: KOS-TEXT-004*  [Loscil Drip]
    // Slot 2: KOS-TEXT-002*  [Distant Pulse]
    // Slot 3: KOS-TEXT-004*  [Loscil Drip]
    // Slot 4: KOS-TEXT-002*  [Distant Pulse]
    // Slot 5: KOS-TEXT-004*  [Loscil Drip]
    // Slot 6: KOS-TEXT-002*  [Distant Pulse]
    // Slot 7: KOS-TEXT-004*  [Loscil Drip]
    // Slot 8: KOS-TEXT-002*  [Distant Pulse]
    // Slot 9: KOS-TEXT-004*  [Loscil Drip]
    private static let kosmicTestCycle: [TestModeConfig] = [
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-002", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-002", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-002", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-002", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-002", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
    ]

    private func nextTestConfig() -> TestModeConfig? {
        guard testModeEnabled else { return nil }
        let cycle: [TestModeConfig]
        switch selectedStyle {
        case .ambient: cycle = Self.ambientTestCycle
        case .kosmic:  cycle = Self.kosmicTestCycle
        default:       cycle = Self.testCycle
        }
        let config = cycle[testCycleIndex % cycle.count]
        testCycleIndex += 1
        return config
    }

    // MARK: - Instrument randomization
    // After the first generation (all-defaults), each new song picks 2 random non-drums tracks
    // and assigns each a random non-default instrument from that track's pool.
    // instrumentOverrides maps trackIndex → instrumentIndex; TrackRowView reads this on defaultsResetToken.

    private var songGenerationCount = 0
    // Tracks which styles have had at least one song generated — used for best-song mode.
    private var stylesWithGeneratedSongs: Set<MusicStyle> = []
    var instrumentOverrides: [Int: Int] = [:]

    private static let randomizableTrackIndices = [kTrackLead1, kTrackLead2, kTrackPads, kTrackRhythm, kTrackTexture, kTrackBass, kTrackDrums]

    private static let trackDisplayName: [Int: String] = [
        kTrackLead1: "Lead 1", kTrackLead2: "Lead 2", kTrackPads: "Pads",
        kTrackRhythm: "Rhythm", kTrackTexture: "Texture", kTrackBass: "Bass", kTrackDrums: "Drums"
    ]

    static func instrumentPoolNames(trackIndex: Int, style: MusicStyle) -> [String] {
        switch (trackIndex, style) {
        case (kTrackLead1,   .chill):   return ["Muted Trumpet","Tenor Sax","Alto Sax","Trumpet"]
        case (kTrackLead1,   .ambient): return ["Flute","Ocarina","Pan Flute","Whistle","Recorder","Brightness","Halo Pad","New Age Pad","Calliope Lead"]
        case (kTrackLead1,   .kosmic):  return ["Flute","Brightness","Oboe","Recorder"]
        case (kTrackLead1,   _):        return ["Mono Synth","Soft Brass","Pad 3 Poly","Square Lead"]
        case (kTrackLead2,   .chill):   return ["Vibraphone","Flute","Soprano Sax","Trombone"]
        case (kTrackLead2,   .ambient): return ["Vibraphone","Celesta","Glockenspiel","Grand Piano","Warm Pad","Space Voice","FX Atmosphere"]
        case (kTrackLead2,   .kosmic):  return ["Brightness","Bassoon","Charang","Vox Solo"]
        case (kTrackLead2,   _):        return ["Polysynth","Brightness","Minimoog","Elec Guitar"]
        case (kTrackPads,    .chill):   return ["Warm Pad","Synth Strings","String Pad","Sweep Pad"]
        case (kTrackPads,    .ambient): return ["Choir Aahs","Synth Strings","Bowed Glass","Warm Pad","Halo Pad","New Age Pad","Sweep Pad"]
        case (kTrackPads,    .kosmic):  return ["Sweep Pad","Synth Strings","Warm Pad","Space Voice"]
        case (kTrackPads,    _):        return ["Halo Pad","Sweep Pad","Bowed Glass","Synth Strings"]
        case (kTrackRhythm,  .chill):    return ["Rhodes","Wurlitzer","B3 Organ"]
        case (kTrackRhythm,  .ambient):  return ["Vibraphone","Marimba","Tubular Bells","Glockenspiel","FX Crystal","FX Echoes"]
        case (kTrackRhythm,  .kosmic):   return ["Moog Lead","Wurlitzer","Rock Organ"]
        case (kTrackRhythm,  .motorik):  return ["Guitar Pulse","Moog Lead","Fuzz Guitar"]
        case (kTrackRhythm,  _):         return ["Guitar Pulse","Moog Lead","Fuzz Guitar"]
        case (kTrackTexture, .chill):   return ["None","Bar sounds","City at night","Light rain","Ocean waves","Urban rain","Vinyl crackle"]
        case (kTrackTexture, .ambient): return ["Strings","Bowed Glass","Choir Aahs","FX Atmosphere","Sweep Pad","Pad 3 Poly"]
        case (kTrackTexture, .kosmic):  return ["FX Atmosphere","Pad 3 Poly","Fifths Lead"]
        case (kTrackTexture, _):        return ["Fifths Lead","Halo Pad","Warm Pad","FX Atmosphere","FX Echoes"]
        case (kTrackBass,    .ambient): return ["Cello","Contrabass","Fretless Bass"]
        case (kTrackBass,    .kosmic):  return ["Moog Bass","Fretless Bass","Lead Bass","Mono Synth"]
        case (kTrackBass,    _):        return ["Moog Bass","Lead Bass","Rock Bass","Elec Bass"]
        case (kTrackDrums,   .ambient): return ["Percussion Kit", "Brush Kit"]
        case (kTrackDrums,   .kosmic):  return ["Brush Kit","808 Kit","Machine Kit","Standard Kit"]
        case (kTrackDrums,   _):        return ["Rock Kit","808 Kit","Brush Kit"]
        default:                        return []
        }
    }

    /// MIDI program numbers for each slot in instrumentPoolNames — same order, same count.
    /// Only covers the tracks that can be "fresh" in Evolve passes (Lead1, Lead2, Pads, Rhythm).
    static func instrumentPoolPrograms(trackIndex: Int, style: MusicStyle) -> [UInt8] {
        switch (trackIndex, style) {
        case (kTrackLead1, .chill):   return [59, 66, 65, 56]
        case (kTrackLead1, .ambient): return [73, 79, 75, 78, 74, 100, 94, 88, 82]
        case (kTrackLead1, .kosmic):  return [73, 100, 68, 74]
        case (kTrackLead1, _):        return [81, 62, 90, 80]
        case (kTrackLead2, .chill):   return [11, 73, 64, 57]
        case (kTrackLead2, .ambient): return [11, 8, 9, 0, 89, 91, 99]
        case (kTrackLead2, .kosmic):  return [100, 70, 84, 85]
        case (kTrackLead2, _):        return [90, 100, 39, 30]
        case (kTrackPads, .ambient):  return [95, 50, 89, 94, 88]
        case (kTrackPads, .kosmic):   return [95, 50, 89, 91]
        case (kTrackPads, .chill):    return [89, 50, 48, 95]
        case (kTrackPads, _):         return [94, 95, 92, 50]
        case (kTrackRhythm, .ambient): return [11, 12, 14, 9, 98, 102]
        case (kTrackRhythm, .chill):   return [4, 5, 17]
        case (kTrackRhythm, .kosmic):  return [39, 5, 18]
        case (kTrackRhythm, _):        return [28, 39, 29]
        default: return []
        }
    }

    // MARK: - Sheet triggers (set by key monitor, observed by TopBarView)
    @Published var triggerShowHelp  = false
    @Published var triggerShowAbout = false

    // MARK: - Per-track UI state

    @Published var muteState: [Bool] = Array(repeating: false, count: kTrackCount)
    @Published var soloState: [Bool] = Array(repeating: false, count: kTrackCount)

    // MARK: - Live playback feed (Now Playing strip)

    @Published var livePlaybackFeed: [GenerationLogEntry] = []
    private var lastEmittedStep: Int = -1

    // MARK: - Playback engine

    let playback = PlaybackEngine()
    let audioTexture = AudioTexturePlayer()
    let nowPlaying = NowPlayingController()

    private var cancellables = Set<AnyCancellable>()
    private var keyEventMonitor: Any?

    init() {
        // Forward only isPlaying changes so transport buttons (TopBarView) stay current.
        // Removing the blanket objectWillChange cascade breaks the per-step chain:
        // PlaybackEngine.currentStep → AppState → ContentView → 7 TrackRowViews → 7 Canvases.
        // MIDILaneView now observes PlaybackEngine directly (injected as EnvironmentObject),
        // so per-step redraws are scoped to the 7 Canvas views only.
        playback.$isPlaying
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Forward currentBar changes (once per bar boundary, not per step) so the bar
        // indicator in ContentView updates during playback without triggering per-step redraws.
        playback.$currentBar
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Media key support: update Now Playing info whenever song or play state changes.
        nowPlaying.configure(appState: self)
        Publishers.CombineLatest($songState, playback.$isPlaying)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] song, isPlaying in
                guard let self else { return }
                self.nowPlaying.update(song: song, isPlaying: isPlaying,
                                       currentStep: self.playback.currentStep)
            }
            .store(in: &cancellables)

        // Claim Now Playing routing whenever Zudio becomes the active app.
        // AppDelegate posts zudioClaimNowPlaying on applicationDidBecomeActive.
        // playbackState = .playing is a persistent, browser-tick-proof signal that
        // displaces any browser Now Playing session. Restores true state after 100 ms.
        NotificationCenter.default.addObserver(forName: .zudioClaimNowPlaying, object: nil,
                                               queue: .main) { [weak self] _ in
            guard let self else { return }
            self.nowPlaying.claimFocus(song: self.songState,
                                       isPlaying: self.playback.isPlaying,
                                       currentStep: self.playback.currentStep)
        }

        // Load .zudio files opened from Finder while the app is already running.
        // AppDelegate posts this notification instead of letting SwiftUI open a new window.
        NotificationCenter.default.addObserver(forName: .zudioOpenFile, object: nil,
                                               queue: .main) { [weak self] note in
            guard let url = note.object as? URL else { return }
            // Clear the shared pending URL so the 0.5 s fallback post in AppDelegate is
            // suppressed — prevents a double-load when the immediate post was already handled.
            Notification.Name.zudioPendingOpenURL = nil
            self?.loadFromLogURL(url)
        }

        // Global key monitor — intercepts transport/generation shortcuts regardless of focus.
        // NSEvent monitor callbacks always run on the main thread.
        // Arrow keys and Return guard against text field focus (BPM field uses these for editing).
        // Return also guards against open sheets (Help/About use .defaultAction = Return on Close).
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Strip modifier keys irrelevant to our shortcuts (.numericPad/.function are set on arrows)
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])

            switch event.keyCode {

            case 49: // Space — play/stop (BPM field never needs space, no guard required)
                guard mods.isEmpty else { return event }
                Task { @MainActor [weak self] in
                    guard let self, !self.isGenerating else { return }
                    self.playOrStop()
                }
                return nil

            case 36: // Return/Enter — generate new song
                guard mods.isEmpty else { return event }
                // Pass through only if an *editable* text field is focused (Enter commits the value)
                // or if a sheet is open (Return = Close on Help/About).
                // Read-only views like the status log must not block this.
                let isTextField = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
                let sheetOpen   = !(NSApp.keyWindow?.sheets.isEmpty ?? true)
                guard !isTextField, !sheetOpen else { return event }
                Task { @MainActor [weak self] in
                    guard let self, !self.isGenerating else { return }
                    self.generateNew()
                }
                return nil

            case 123: // Left arrow — seek back 1 bar (plain) or to start (Cmd)
                let isTextField = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
                guard !isTextField else { return event }
                if mods.isEmpty {
                    Task { @MainActor [weak self] in
                        guard let self, self.songState != nil else { return }
                        self.seekBackOneBar()
                    }
                    return nil
                } else if mods == .command {
                    Task { @MainActor [weak self] in
                        guard let self, self.songState != nil else { return }
                        self.seekToStart()
                    }
                    return nil
                }

            case 124: // Right arrow — seek forward 1 bar (plain) or to end (Cmd)
                let isTextField = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
                guard !isTextField else { return event }
                if mods.isEmpty {
                    Task { @MainActor [weak self] in
                        guard let self, self.songState != nil else { return }
                        self.seekForwardOneBar()
                    }
                    return nil
                } else if mods == .command {
                    Task { @MainActor [weak self] in
                        guard let self, self.songState != nil else { return }
                        self.seekToEnd()
                    }
                    return nil
                }

            // Plain-letter shortcuts — all guard against text-field focus and open sheets
            case 5, 1, 37, 46, 15, 40, 4, 0, 11, 6:
                guard mods.isEmpty else { return event }
                let isTextField = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
                let sheetOpen   = !(NSApp.keyWindow?.sheets.isEmpty ?? true)
                guard !isTextField, !sheetOpen else { return event }
                switch event.keyCode {
                case 5:  // 'g' — generate
                    Task { @MainActor [weak self] in
                        guard let self, !self.isGenerating else { return }
                        self.generateNew()
                    }
                case 14: // 'e' — export audio
                    guard songState != nil, !isExportingAudio else { return event }
                    Task { @MainActor [weak self] in self?.requestExport() }
                case 1:  // 's' — save MIDI
                    guard songState != nil else { return event }
                    Task { @MainActor [weak self] in self?.saveMIDI() }
                case 37: // 'l' — load song
                    guard !isGenerating else { return event }
                    Task { @MainActor [weak self] in self?.loadFromLog() }
                case 46: // 'm' — Motorik
                    Task { @MainActor [weak self] in self?.selectedStyle = .motorik }
                case 15: // 'r' — reset (always allowed — clears everything)
                    Task { @MainActor [weak self] in self?.resetTrackDefaults() }
                case 40: // 'k' — Kosmic
                    Task { @MainActor [weak self] in self?.selectedStyle = .kosmic }
                case 4:  // 'h' — help
                    Task { @MainActor [weak self] in self?.triggerShowHelp.toggle() }
                case 0:  // 'a' — Ambient
                    Task { @MainActor [weak self] in self?.selectedStyle = .ambient }
                case 8:  // 'c' — Chill
                    Task { @MainActor [weak self] in self?.selectedStyle = .chill }
                case 11: // 'b' — beginning
                    guard songState != nil else { return event }
                    Task { @MainActor [weak self] in self?.seekToStart() }
                case 6:  // 'z' — end
                    guard songState != nil else { return event }
                    Task { @MainActor [weak self] in self?.seekToEnd() }
                default: break
                }
                return nil

            default:
                break
            }

            return event
        }

        // Real-time tempo scrubbing: update live playback when BPM changes on a loaded song
        $tempoOverride
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] bpm in
                guard let self, let current = self.songState,
                      bpm != current.frame.tempo else { return }
                self.playback.setTempo(bpm)
                self.songState = self.playback.songState
            }
                .store(in: &cancellables)

        // DAW-style scrolling + live annotation feed.
        // .receive(on: DispatchQueue.main) guarantees main-thread delivery — no Task wrapper needed.
        playback.$currentStep
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] step in
                guard let self else { return }
                guard step <= self.playback.currentStep + 32 else { return }
                self.updateDAWScroll(step: step)
                self.emitStepAnnotations(upTo: step)
            }
            .store(in: &cancellables)

        // Wire PlaybackEngine callbacks (called on main actor)
        playback.onApproachingEnd = { [weak self] in
            guard let self else { return }
            switch self.playMode {
            case .endless:
                if let next = self.nextSongState {
                    // Already pre-genned — log "Up next" now, at the 12-bar mark
                    self.appendToLog([GenerationLogEntry(tag: "Up next",
                        description: "\(next.style.rawValue) - \(next.title)", isTitle: true)])
                    self.upNextLogged = true
                } else {
                    // Not ready yet — set flag so preGenerateNextSong() logs when it finishes
                    self.shouldLogNextUpWhenReady = true
                    self.preGenerateNextSong()
                }
            case .evolve:
                self.handleEvolveApproachingEnd()
            case .song:
                break
            }
        }
        playback.onSongEndNaturally = { [weak self] in
            guard let self else { return }
            switch self.playMode {
            case .endless: self.handleSongEndedNaturally()
            case .evolve:  self.handleEvolvePhaseEnded()
            case .song:    break
            }
        }
        playback.onOutroStart = { [weak self] in
            guard let self, self.playMode == .evolve else { return }
            switch self.evolvePhase {
            case .original:
                self.handleEvolveOutroStart()
            case .pass2:
                // Outro is baked into the extended state — its step annotation streams the
                // "Bar NNN  Outro  N bar cold stop / fade / dissolve" message automatically.
                self.evolvePhase      = .outro
                self.evolvePhaseToken += 1
                self.preGenerateEvolveNextSong()
            default:
                break
            }
        }
    }

    // MARK: - Log append helper

    // Single entry point for all statusLog mutations. Increments statusLogVersion
    // so StatusBoxView.onChange fires even when the net count is unchanged.
    // Trims front of log when it exceeds 600 entries (drops down to 400).
    // Using a large drop (not a 1-entry trim) ensures the count changes noticeably.
    private func appendToLog(_ entries: [GenerationLogEntry]) {
        guard !entries.isEmpty else { return }
        statusLog.append(contentsOf: entries)
        if statusLog.count > 600 {
            statusLog.removeFirst(statusLog.count - 400)
        }
        statusLogVersion += 1
    }

    // MARK: - Live annotation feed

    private func emitStepAnnotations(upTo step: Int) {
        guard step > lastEmittedStep,
              let annotations = songState?.stepAnnotations else { return }
        var newEntries: [GenerationLogEntry] = []
        for s in (lastEmittedStep + 1)...step {
            if let entries = annotations[s] {
                let bar = s / 16 + 1
                let barTag = String(format: "Bar %03d", bar)
                let prefixed = entries.map { e -> GenerationLogEntry in
                    let desc = e.tag.isEmpty
                        ? e.description
                        : "\(e.tag.trimmingCharacters(in: .whitespaces))  \(e.description)"
                    return GenerationLogEntry(tag: barTag, description: desc, isTitle: e.isTitle)
                }
                newEntries.append(contentsOf: prefixed)
            }
        }
        if !newEntries.isEmpty {
            appendToLog(newEntries)
        }
        lastEmittedStep = step
    }

    // MARK: - DAW Scroll

    private func updateDAWScroll(step: Int) {
        guard playback.isPlaying else { return }
        let totalBars = songState?.frame.totalBars ?? 32
        let triggerStep = (visibleBarOffset + Int(Double(visibleBars) * 0.85)) * 16
        if step >= triggerStep {
            let newOffset = max(0, step / 16 - Int(Double(visibleBars) * 0.15))
            visibleBarOffset = min(newOffset, max(0, totalBars - visibleBars))
        }
    }

    // MARK: - Generate

    func generateNew(thenPlay: Bool = false) {
        guard !isGenerating else { return }
        isGenerating = true
        let style = selectedStyle
        let testConfig = nextTestConfig()
        let isFirstForStyle = !stylesWithGeneratedSongs.contains(style)
        // Brush Kit is index 1 in the Ambient drum pool ["Percussion Kit", "Brush Kit"]
        let useBrushKit = style == .ambient && (instrumentOverrides[kTrackDrums] ?? 0) == 1
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            // Best-song params: applied on first generation per style; testConfig overrides where set.
            let bestBass: String?
            let bestDrum: String?
            let bestArp:  String?
            let bestLead: String?
            let bestTex:  String?
            let bestPerc: PercussionStyle?
            let bestBridge: Bool
            switch style {
            case .motorik:
                bestBass   = "MOT-BASS-015"
                bestDrum   = "MOT-DRUM-001"
                bestArp    = "MOT-RTHM-001"
                bestLead   = nil
                bestTex    = nil
                bestPerc   = nil
                bestBridge = false
            case .kosmic:
                bestBass   = "KOS-BASS-010"
                bestDrum   = nil
                bestArp    = "KOS-RTHM-002"
                bestLead   = nil
                bestTex    = nil
                bestPerc   = .motorikGrid   // → KOS-DRUM-004 Electric Buddha groove
                bestBridge = true
            case .ambient:
                bestBass   = nil
                bestDrum   = nil
                bestArp    = nil
                bestLead   = "AMB-LEAD-003"
                bestTex    = nil
                bestPerc   = .handPercussion  // → AMB-DRUM-004 hand percussion
                bestBridge = false
            case .chill:
                // First Chill song: St Germain four-on-the-floor groove.
                // forceDrumRuleID "CHL-DRUM-004" maps to .stGermain beat style, which also
                // biases tempo into the upper range (108–124 BPM) and auto-selects CHL-BASS-007.
                bestBass   = nil            // implied by stGermain beat style (CHL-BASS-007)
                bestDrum   = "CHL-DRUM-004" // stGermain groove → upper-range tempo
                bestArp    = nil
                bestLead   = "CHL-LD1-004" // saxophone / blues lead
                bestTex    = "forced"       // guarantee a texture on the first song
                bestPerc   = nil
                bestBridge = false
            }
            let useBest = isFirstForStyle
            let state = SongGenerator.generate(
                keyOverride:     await self.keyOverride,
                tempoOverride:   await self.tempoOverride,
                moodOverride:    await self.moodOverride,
                style:           style,
                testMode:        await self.testModeEnabled,
                forceBassRuleID:      testConfig?.forceBassRuleID      ?? (useBest ? bestBass   : nil),
                forceDrumRuleID:      testConfig?.forceDrumRuleID      ?? (useBest ? bestDrum   : nil),
                forceArpRuleID:       testConfig?.forceArpRuleID       ?? (useBest ? bestArp    : nil),
                forcePadsRuleID:      testConfig?.forcePadsRuleID,
                forceLeadRuleID:      testConfig?.forceLeadRuleID      ?? (useBest ? bestLead   : nil),
                forceTexRuleID:       testConfig?.forceTexRuleID       ?? (useBest ? bestTex    : nil),
                forcePercussionStyle: testConfig?.forcePercussionStyle ?? (useBest ? bestPerc   : nil),
                forceBridge:          testConfig?.forceBridge ?? (useBest ? bestBridge : false),
                forceBridgeArchetype: testConfig?.forceBridgeArchetype,
                useBrushKit:          useBrushKit
            )
            await MainActor.run {
                self.songState    = state
                self.generationHistory.append(state)
                if self.generationHistory.count > 5 { self.generationHistory.removeFirst() }
                self.isGenerating = false
                self.visibleBarOffset = 0
                self.lastEmittedStep  = -1
                // Track song history for ⏮ back navigation
                self.appendSongHistory(from: state)
                // Endless: reset stream counters to current style; start pre-gen for song after next
                if self.playMode == .endless {
                    self.songsInCurrentStyle = 1
                    if let idx = self.endlessStyleAxis.firstIndex(of: style) {
                        self.endlessStyleIndex = idx
                    }
                    self.nextSongState   = nil
                    self.isPreGenerating = false
                    self.preGenerateNextSong()
                }
                // Evolve: fresh generate resets evolution state and starts a new evolve session
                if self.playMode == .evolve {
                    self.tearDownEvolve()
                    self.startEvolveMode(from: state)
                }

                // Instrument randomization: first song per style uses all defaults (index 0).
                // From the second song onwards, pick 2 random non-drums tracks and assign
                // each a random non-default instrument, so users hear the instrument variety.
                // kTrackTexture is excluded for Chill — the generator already chose the texture.
                var instrumentLogDesc: String? = nil
                if !isFirstForStyle {
                    var eligible = Self.randomizableTrackIndices.filter { style != .chill || $0 != kTrackTexture }
                    var picks: [(trackIndex: Int, instIndex: Int, name: String)] = []
                    var rng = SystemRandomNumberGenerator()
                    while picks.count < 2, !eligible.isEmpty {
                        let pos = eligible.indices.randomElement(using: &rng)!
                        let trackIdx = eligible.remove(at: pos)
                        let pool = Self.instrumentPoolNames(trackIndex: trackIdx, style: style)
                        if pool.count > 1 {
                            let instIdx = Int.random(in: 1..<pool.count, using: &rng)
                            picks.append((trackIdx, instIdx, pool[instIdx]))
                        }
                    }
                    if !picks.isEmpty {
                        self.instrumentOverrides = Dictionary(uniqueKeysWithValues: picks.map { ($0.trackIndex, $0.instIndex) })
                        let parts = picks.map { "\(Self.trackDisplayName[$0.trackIndex] ?? "Track"): \($0.name)" }
                        instrumentLogDesc = parts.joined(separator: ",  ")
                    }
                } else {
                    self.instrumentOverrides = [:]
                }
                // Chill texture: always applied last so randomization can't overwrite it.
                if style == .chill {
                    let prog = Self.chillTextureProgram(forFilename: state.chillAudioTexture)
                    self.instrumentOverrides[kTrackTexture] = Int(prog) - 240
                }
                self.songGenerationCount += 1
                self.stylesWithGeneratedSongs.insert(style)

                // Build the batch to append: optional separator + generation log + instruments entry
                var batch: [GenerationLogEntry] = []
                if !self.statusLog.isEmpty {
                    batch.append(GenerationLogEntry(tag: "", description: "", isTitle: false))
                }
                var logEntries = state.generationLog
                if let desc = instrumentLogDesc, style != .chill {
                    let entry = GenerationLogEntry(tag: "Instruments", description: desc, isTitle: false)
                    if let firstIdx = logEntries.firstIndex(where: { $0.tag == "Intro" || $0.tag == "Outro" }) {
                        logEntries.insert(entry, at: firstIdx)
                    } else {
                        logEntries.append(entry)
                    }
                }
                batch.append(contentsOf: logEntries)
                self.appendToLog(batch)
                // Reset mute/solo so every new song starts with all parts audible
                self.muteState = Array(repeating: false, count: kTrackCount)
                self.soloState = Array(repeating: false, count: kTrackCount)
                self.playback.muteState = self.muteState
                self.playback.soloState = self.soloState
                // Keep all overrides at Auto after generation — key/mood/tempo are shown in
                // the status log header. Writing them back here caused subsequent generations
                // to treat the randomly-picked values as user-forced overrides.
                self.keyOverride   = nil
                self.tempoOverride = nil
                self.moodOverride  = nil
                // Stop any in-progress playback cleanly before swapping in the new song.
                // This prevents the old scheduler from firing events against the new song state
                // during the brief window between load() and seek(), which caused desync.
                let wasPlaying = self.playback.isPlaying
                self.playback.stop()
                // Stop the audio texture immediately so a Chill texture never bleeds into
                // a newly-generated song of any style. play() will restart it if needed.
                self.audioTexture.switchTexture(nil)
                self.playback.kosmicStyle  = self.selectedStyle == .kosmic
                self.playback.motorikStyle = self.selectedStyle == .motorik
                self.playback.chillFade = state.style == .chill && {
                    if case .alreadyPlaying = state.structure.introStyle { return true }
                    return false
                }()
                self.playback.load(state)
                self.playback.seek(toStep: 0)
                // Configure ambient mode before defaultsResetToken fires so setEffect
                // uses the correct Ambient reverb/delay values from the start.
                self.playback.setAmbientMode(self.selectedStyle == .ambient)
                self.playback.setChillMode(self.selectedStyle == .chill)
                // Reset instruments + effects BEFORE play so setProgram() doesn't race
                // against the first note firing.
                self.defaultsResetToken += 1
                if thenPlay || wasPlaying { self.playback.play() }
                // Resign first responder so BPM TextField doesn't hold focus
                NSApp.keyWindow?.makeFirstResponder(nil)
                // If a file-open arrived while we were generating, load it now.
                self.consumePendingLoad()
            }
        }
    }

    /// Called when the user cycles the drum kit in Ambient mode.
    /// Remaps the 2-3 affected note numbers in existing drum events — no regeneration needed.
    /// Percussion Kit: Shaker=82, Claves=75  |  Brush Kit: Maracas=70, Triangle=81
    func remapAmbientDrumNotes(instrumentIndex: Int) {
        guard let current = songState, current.style == .ambient else { return }
        let useBrushKit = instrumentIndex == 1
        instrumentOverrides[kTrackDrums] = instrumentIndex
        let remapped = current.trackEvents[kTrackDrums].map { ev in
            var n = ev.note
            if useBrushKit {
                if n == 82 { n = 70 }   // Shaker → Maracas
                if n == 75 { n = 81 }   // Claves → Open Triangle
            } else {
                if n == 70 { n = 82 }   // Maracas → Shaker
                if n == 81 { n = 75 }   // Triangle → Claves
            }
            return MIDIEvent(stepIndex: ev.stepIndex, note: n, velocity: ev.velocity, durationSteps: ev.durationSteps)
        }
        let updated = current.withAmbientBrushKit(useBrushKit).replacingEvents(remapped, forTrack: kTrackDrums)
        songState = updated
        if playback.isPlaying { playback.load(updated) }
        if !generationHistory.isEmpty { generationHistory[generationHistory.count - 1] = updated }
    }

    func regenerateTrack(_ trackIndex: Int) {
        guard let current = songState, !isGenerating else { return }
        isGenerating = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let updated = SongGenerator.regenerateTrack(trackIndex, songState: current)
            await MainActor.run {
                self.songState    = updated
                self.isGenerating = false
                self.playback.load(updated)  // always rebuild stepEventMap — regen while paused left stale events
                // Keep generationHistory in sync for SongState tracking
                if !self.generationHistory.isEmpty {
                    self.generationHistory[self.generationHistory.count - 1] = updated
                }
                // Append only the NEW regen entries to the flat status log (at the very bottom)
                let regenEntries = Array(updated.generationLog.dropFirst(current.generationLog.count))
                self.appendToLog(regenEntries)
                // If a file-open arrived while we were regenerating, load it now.
                self.consumePendingLoad()
            }
        }
    }

    // MARK: - Transport

    func play() {
        NSApp.activate(ignoringOtherApps: true)
        if songState == nil {
            generateNew(thenPlay: true)
        } else {
            // Rewind if the playhead is anywhere in the last bar or beyond
            if let song = songState, playback.currentStep >= (song.frame.totalBars - 1) * 16 {
                playback.seek(toStep: 0)
                visibleBarOffset = 0
            }
            playback.kosmicStyle  = selectedStyle == .kosmic
            playback.motorikStyle = selectedStyle == .motorik
            if let song = songState {
                playback.chillFade = song.style == .chill && {
                    if case .alreadyPlaying = song.structure.introStyle { return true }
                    return false
                }()
            }
            playback.play()
            audioTexture.start(style: selectedStyle, texture: songState?.chillAudioTexture,
                               offsetSeconds: songState?.chillAudioTextureOffset ?? 0)
        }
    }

    func stop() {
        NSApp.activate(ignoringOtherApps: true)
        playback.stop()
        audioTexture.stop()
    }

    // MARK: - Seek

    func seekTo(step: Int) {
        playback.seek(toStep: step)
        // Reset annotation pointer so seeks don't re-emit or skip annotations
        lastEmittedStep = step - 1
        // Only scroll the window if the target bar is outside the current visible range.
        // When the user clicks inside the visible lane the window stays put so the
        // playhead lands on exactly the pixel that was clicked.
        let totalBars = songState?.frame.totalBars ?? 32
        let targetBar = step / 16
        if targetBar < visibleBarOffset || targetBar >= visibleBarOffset + visibleBars {
            let newOffset = max(0, min(targetBar - Int(Double(visibleBars) * 0.15), totalBars - visibleBars))
            visibleBarOffset = newOffset
        }
    }

    /// Rewind to bar 1. Already in bars 1–2: load previous song from history if available.
    func seekToStart() {
        if playback.currentBar < 2 {
            goToPreviousSong()
        } else {
            seekTo(step: 0)
            visibleBarOffset = 0
        }
    }

    /// Jump to the last bar and stop playback.
    func seekToEnd() {
        guard let song = songState else { return }
        stop()
        let lastStep = song.frame.totalBars * 16 - 1
        let totalBars = song.frame.totalBars
        // Show the final window of bars
        visibleBarOffset = max(0, totalBars - visibleBars)
        playback.seek(toStep: lastStep)
    }

    // MARK: - Song history helpers

    private func appendSongHistory(from state: SongState) {
        songHistory.append(SongHistoryEntry(seed: state.globalSeed, style: state.style, title: state.title))
        if songHistory.count > songHistoryLimit { songHistory.removeFirst() }
    }

    private func goToPreviousSong() {
        guard songHistory.count >= 2 else { return }
        songHistory.removeLast()   // drop current song entry
        let prev = songHistory.last!
        appendToLog([GenerationLogEntry(tag: "Rewind",
            description: "\(prev.style.rawValue) - \(prev.title)", isTitle: true)])
        let wasPlaying = playback.isPlaying
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = SongGenerator.generate(seed: prev.seed, style: prev.style, testMode: false)
            await MainActor.run {
                self.selectedStyle = state.style
                self.finishLoadingSong(state, thenPlay: wasPlaying)
            }
        }
    }

    // MARK: - Endless mode helpers

    private func decideNextStyle() -> MusicStyle {
        let atLeft  = endlessStyleIndex == 0
        let atRight = endlessStyleIndex == endlessStyleAxis.count - 1
        let shiftNow: Bool
        switch songsInCurrentStyle {
        case 1:  shiftNow = Double.random(in: 0..<1) < 0.30
        case 2:  shiftNow = Double.random(in: 0..<1) < 0.50
        default: shiftNow = true
        }
        if !shiftNow {
            songsInCurrentStyle += 1
            return endlessStyleAxis[endlessStyleIndex]
        }
        // Normal walls force the adjacent step, but a 25% escape valve jumps two steps
        // so Ambient can leap to Kosmic and Motorik can leap to Chill — breaks ping-pong traps.
        let step: Int
        if atLeft {
            step = Double.random(in: 0..<1) < 0.25 ? 2 : 1   // Ambient: 75%→Chill, 25%→Kosmic
        } else if atRight {
            step = Double.random(in: 0..<1) < 0.25 ? -2 : -1  // Motorik: 75%→Kosmic, 25%→Chill
        } else {
            step = Bool.random() ? 1 : -1
        }
        endlessStyleIndex   = max(0, min(endlessStyleAxis.count - 1, endlessStyleIndex + step))
        songsInCurrentStyle = 1
        return endlessStyleAxis[endlessStyleIndex]
    }

    private func preGenerateNextSong() {
        guard playMode == .endless, !isPreGenerating, nextSongState == nil else { return }
        isPreGenerating = true
        let nextStyle = decideNextStyle()
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let state = SongGenerator.generate(style: nextStyle, testMode: false)
            await MainActor.run {
                guard self.playMode == .endless else { return }
                self.nextSongState   = state
                self.isPreGenerating = false
                // Only log "Up next" if the approaching-end trigger requested it
                if self.shouldLogNextUpWhenReady {
                    self.shouldLogNextUpWhenReady = false
                    self.upNextLogged = true
                    self.appendToLog([GenerationLogEntry(tag: "Up next",
                        description: "\(state.style.rawValue) - \(state.title)", isTitle: true)])
                }
            }
        }
    }

    private func handleSongEndedNaturally() {
        guard playMode == .endless else { return }
        if let next = nextSongState {
            // "Up next" was already logged when pre-gen completed
            nextSongState   = nil
            isPreGenerating = false
            startEndlessSong(next)
        } else {
            generateAndStartNextSong()
        }
    }

    private func startEndlessSong(_ state: SongState) {
        appendSongHistory(from: state)
        selectedStyle            = state.style
        shouldLogNextUpWhenReady = false   // reset — next pre-gen is silent until trigger fires
        upNextLogged             = false
        finishLoadingSong(state, thenPlay: true)
        nextSongState   = nil
        isPreGenerating = false
        preGenerateNextSong()   // silently pre-gen the song after next
    }

    private func generateAndStartNextSong() {
        appendToLog([GenerationLogEntry(tag: "Endless", description: "Loading next song...", isTitle: false)])
        let nextStyle = decideNextStyle()
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = SongGenerator.generate(style: nextStyle, testMode: false)
            await MainActor.run {
                self.appendToLog([GenerationLogEntry(tag: "Up next",
                    description: "\(state.style.rawValue) - \(state.title)", isTitle: true)])
                self.startEndlessSong(state)
            }
        }
    }

    /// Skip immediately to the next song (Endless mode ⏭ button).
    func skipToNextSong() {
        guard playMode == .endless else { return }
        if let next = nextSongState {
            // Log "Up next" now if the 12-bar trigger hadn't fired yet
            if !upNextLogged {
                appendToLog([GenerationLogEntry(tag: "Up next",
                    description: "\(next.style.rawValue) - \(next.title)", isTitle: true)])
            }
            nextSongState   = nil
            isPreGenerating = false
            startEndlessSong(next)
        } else {
            generateAndStartNextSong()
        }
    }

    // MARK: - Evolve mode helpers

    private func tearDownEvolve() {
        evolvePhase           = .inactive
        evolveAnchorState     = nil
        evolveMoodAnchor      = nil
        evolveTempoAnchor     = 0
        evolvePass1Bars       = 0
        evolvePass2Bars       = 0
        evolvePass1State      = nil
        evolvePass2State      = nil
        evolveNextSongState      = nil
        evolveIsPreGenerating    = false
        evolveNextSongShouldLog  = false
        evolveNextSongLogged     = false
        evolvePhaseToken        += 1   // ensure scrollbar recreates even if next song has same totalBars
    }

    /// Picks a different instrument for each fresh track and sends a program change immediately.
    private func switchEvolveInstruments(freshTracks: [Int]) {
        guard let anchor = evolveAnchorState else { return }
        let style = anchor.style
        var rng = SystemRandomNumberGenerator()
        for trackIndex in freshTracks {
            let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: style)
            guard programs.count > 1 else { continue }
            let currentIdx = instrumentOverrides[trackIndex] ?? 0
            var newIdx = currentIdx
            var attempts = 0
            repeat {
                newIdx = Int.random(in: 0..<programs.count, using: &rng)
                attempts += 1
            } while newIdx == currentIdx && attempts < 16
            guard newIdx != currentIdx else { continue }
            instrumentOverrides[trackIndex] = newIdx
            setProgram(programs[newIdx], forTrack: trackIndex)
        }
        instrumentChangeToken += 1
    }

    private func startEvolveMode(from song: SongState, lockMoodToSong: Bool = true) {
        // lockMoodToSong: true = next generated song matches this song's mood (used for song 1→2).
        //                false = next generated song picks mood freely (used for song 2→3 onward).
        let moodOverride: Mood? = lockMoodToSong ? song.frame.mood : nil
        // If already in or past the Outro, let it finish; pre-gen the next song
        if let outroBar = song.structure.outroSection?.startBar,
           playback.currentBar >= outroBar {
            evolveAnchorState  = song
            evolveMoodAnchor   = moodOverride
            evolveTempoAnchor  = song.frame.tempo
            evolvePhase        = .outro
            preGenerateEvolveNextSong()
            return
        }
        evolveAnchorState  = song
        evolveMoodAnchor   = moodOverride
        evolveTempoAnchor  = song.frame.tempo
        evolvePhase        = .original
        let aBars          = aSectionBars(of: song)
        evolvePass1Bars    = min(40, max(32, aBars / 2))
        evolvePass2Bars    = max(16, evolvePass1Bars / 2)
        preGeneratePassContent(pass: 1)
    }

    private func aSectionBars(of song: SongState) -> Int {
        let aSections = song.structure.sections.filter { $0.label == .A }
        if !aSections.isEmpty { return aSections.reduce(0) { $0 + $1.lengthBars } }
        let body = song.structure.bodySections
        if !body.isEmpty { return body.reduce(0) { $0 + $1.lengthBars } }
        return max(32, song.frame.totalBars - 16)
    }

    // Builds a pass SongState from anchor events. freshTracks get regenerated content trimmed to
    // passBars; all other tracks copy the first passBars of anchor events. nonisolated so it can
    // be called safely from Task.detached without capturing `self`.
    private nonisolated static func buildPassState(anchor: SongState, freshTracks: [Int], passBars: Int) -> SongState {
        // Identifies tags that are rule IDs (e.g. "AMB-LEAD-003"), not prose labels like "Key" or "⚡ REGEN"
        func isRuleID(_ tag: String) -> Bool {
            !tag.isEmpty && tag.contains("-") &&
            tag.allSatisfy { $0.isUppercase || $0.isNumber || $0 == "-" }
        }
        let anchorRuleIDs = Set(anchor.generationLog.map(\.tag).filter(isRuleID))
        let baseLogCount  = anchor.generationLog.count
        let cutoff = passBars * 16
        // Non-fresh tracks are copied from the anchor's body start (not step 0) so that the
        // anchor's intro silence (e.g. 7 silent drum bars) is not replayed at the beginning
        // of each evolution pass when it lands in the extended timeline mid-song.
        let bodyStartStep = (anchor.structure.introSection?.endBar ?? 0) * 16
        var events = anchor.trackEvents.map { track -> [MIDIEvent] in
            track
                .filter { $0.stepIndex >= bodyStartStep && $0.stepIndex < bodyStartStep + cutoff }
                .map { MIDIEvent(stepIndex: $0.stepIndex - bodyStartStep, note: $0.note,
                                 velocity: $0.velocity, durationSteps: $0.durationSteps) }
        }
        var regenLog: [GenerationLogEntry] = []
        for idx in freshTracks {
            let anchorHadContent = !anchor.trackEvents[idx].isEmpty
            var regen      = SongGenerator.regenerateTrack(idx, songState: anchor, passBodyBars: passBars)
            var newEntries = Array(regen.generationLog.dropFirst(baseLogCount))
            // Retry until: (a) new rule differs from every rule used in the anchor AND
            //              (b) there are body events (not just intro motif) within the pass window.
            //              Solo rules (MOT-LD1-007/008) are completely silent in body bars outside
            //              their solo window. passBodyBars constrains the solo to land within the
            //              pass window, but we still retry if only intro motif notes exist.
            var attempts = 1
            while attempts < 12 {
                let newRuleIDs = Set(newEntries.map(\.tag).filter(isRuleID))
                let eventsEmpty = anchorHadContent &&
                    regen.trackEvents[idx].filter({ $0.stepIndex >= bodyStartStep && $0.stepIndex < bodyStartStep + cutoff }).isEmpty
                if newRuleIDs.isDisjoint(with: anchorRuleIDs) && !eventsEmpty { break }
                regen      = SongGenerator.regenerateTrack(idx, songState: anchor, passBodyBars: passBars)
                newEntries = Array(regen.generationLog.dropFirst(baseLogCount))
                attempts  += 1
            }
            events[idx] = regen.trackEvents[idx]
                .filter { $0.stepIndex >= bodyStartStep && $0.stepIndex < bodyStartStep + cutoff }
                .map { MIDIEvent(stepIndex: $0.stepIndex - bodyStartStep, note: $0.note,
                                 velocity: $0.velocity, durationSteps: $0.durationSteps) }
            regenLog.append(contentsOf: newEntries)
        }
        let passFrame = anchor.frame.withTotalBars(passBars)
        let minStruct = SongStructure(sections: [], chordPlan: [],
                                      introStyle: anchor.structure.introStyle,
                                      outroStyle: anchor.structure.outroStyle)
        return SongState(frame: passFrame, structure: minStruct,
                         trackEvents: events, generationLog: regenLog, stepAnnotations: [:],
                         copyingStyleFieldsFrom: anchor)
    }

    // Builds an extended SongState by appending pass events (and optionally the original Outro)
    // after the anchor body. pass1Events and pass2Events are 0-indexed within their own pass lengths;
    // they are shifted into the correct absolute position in the extended timeline.
    private nonisolated static func buildExtendedState(
        anchor: SongState,
        outroStartBar: Int,
        pass1Events: [[MIDIEvent]],
        pass1Bars: Int,
        pass2Events: [[MIDIEvent]]? = nil,
        pass2Bars: Int = 0,
        includeOutro: Bool = false
    ) -> SongState {
        let outroStartStep = outroStartBar * 16
        let p1Offset       = outroStartStep
        let p2Offset       = (outroStartBar + pass1Bars) * 16
        let outroShift     = (pass1Bars + pass2Bars) * 16

        var tracks: [[MIDIEvent]] = []
        for t in 0..<kTrackCount {
            var events: [MIDIEvent] = []
            // Anchor body (before Outro start)
            events.append(contentsOf: anchor.trackEvents[t].filter { $0.stepIndex < outroStartStep })
            // Pass 1 events shifted to start at outroStartBar
            events.append(contentsOf: pass1Events[t].map {
                MIDIEvent(stepIndex: $0.stepIndex + p1Offset, note: $0.note,
                          velocity: $0.velocity, durationSteps: $0.durationSteps)
            })
            // Pass 2 events shifted to start at (outroStartBar + pass1Bars)
            if let p2 = pass2Events {
                events.append(contentsOf: p2[t].map {
                    MIDIEvent(stepIndex: $0.stepIndex + p2Offset, note: $0.note,
                              velocity: $0.velocity, durationSteps: $0.durationSteps)
                })
            }
            // Original Outro events shifted to play after all passes
            if includeOutro {
                events.append(contentsOf: anchor.trackEvents[t]
                    .filter { $0.stepIndex >= outroStartStep }
                    .map { MIDIEvent(stepIndex: $0.stepIndex + outroShift, note: $0.note,
                                     velocity: $0.velocity, durationSteps: $0.durationSteps) })
            }
            tracks.append(events)
        }

        let outroBars  = includeOutro ? (anchor.frame.totalBars - outroStartBar) : 0
        let totalBars  = outroStartBar + pass1Bars + pass2Bars + outroBars
        let extFrame   = anchor.frame.withTotalBars(totalBars)
        // Include the outro section in the structure so PlaybackEngine can schedule the audio fade.
        // Also carry the anchor's outro step annotations (shifted) so the normal bar-annotation
        // feed shows e.g. "Bar 165  Outro  4 bar cold stop — drum fill ending" at the right time.
        var extSections: [SongSection] = []
        var extAnnotations: [Int: [GenerationLogEntry]] = [:]
        if includeOutro, let anchorOutro = anchor.structure.outroSection {
            let extOutroStart = outroStartBar + pass1Bars + pass2Bars
            extSections = [SongSection(startBar: extOutroStart,
                                       lengthBars: anchorOutro.lengthBars,
                                       label: .outro,
                                       intensity: anchorOutro.intensity,
                                       mode: anchorOutro.mode)]
            // Shift every annotation that belongs to the outro section.
            for (step, entries) in anchor.stepAnnotations where step >= outroStartStep {
                extAnnotations[step + outroShift] = entries
            }
        }
        let minStruct  = SongStructure(sections: extSections, chordPlan: [],
                                       introStyle: anchor.structure.introStyle,
                                       outroStyle: anchor.structure.outroStyle)
        return SongState(frame: extFrame, structure: minStruct,
                         trackEvents: tracks, generationLog: [], stepAnnotations: extAnnotations,
                         copyingStyleFieldsFrom: anchor)
    }

    private func preGeneratePassContent(pass: Int) {
        guard let anchor = evolveAnchorState, !evolveIsPreGenerating else { return }
        let freshTracks: [Int]
        let passBars: Int
        switch pass {
        case 1:
            guard evolvePass1State == nil else { return }
            freshTracks = [kTrackLead1, kTrackLead2]
            passBars    = evolvePass1Bars
        case 2:
            guard evolvePass2State == nil else { return }
            freshTracks = [kTrackPads, kTrackRhythm]
            passBars    = evolvePass2Bars
        default: return
        }
        evolveIsPreGenerating = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = Self.buildPassState(anchor: anchor, freshTracks: freshTracks, passBars: passBars)
            await MainActor.run {
                guard self.playMode == .evolve else { return }
                if pass == 1 {
                    self.evolvePass1State = state
                } else {
                    self.evolvePass2State = state
                }
                self.evolveIsPreGenerating = false
                // Pass-2 only: update display immediately (12-bar early look-ahead)
                if pass == 2, self.evolvePhase == .pass1,
                   let pass1 = self.evolvePass1State {
                    let outroStartBar = anchor.structure.outroSection?.startBar ?? anchor.frame.totalBars
                    let extended = Self.buildExtendedState(
                        anchor: anchor, outroStartBar: outroStartBar,
                        pass1Events: pass1.trackEvents, pass1Bars: self.evolvePass1Bars,
                        pass2Events: state.trackEvents, pass2Bars: passBars)
                    self.songState = extended
                    self.appendToLog([GenerationLogEntry(tag: "Upcoming",
                        description: "Evolving section \(passBars) bars with new pads, rhythm",
                        isTitle: false)])
                }
            }
        }
    }

    private func preGenerateEvolveNextSong() {
        guard let anchor = evolveAnchorState, !evolveIsPreGenerating,
              evolveNextSongState == nil else { return }
        evolveIsPreGenerating = true
        let style = anchor.style
        let mood  = evolveMoodAnchor
        let tempo = evolveTempoAnchor
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let bpmDelta = Int.random(in: -5...5)
            let newTempo = max(20, min(200, tempo + bpmDelta))
            let state = SongGenerator.generate(tempoOverride: newTempo, moodOverride: mood,
                                               style: style, testMode: false)
            await MainActor.run {
                guard self.playMode == .evolve else { return }
                self.evolveNextSongState   = state
                self.evolveIsPreGenerating = false
                if self.evolveNextSongShouldLog && !self.evolveNextSongLogged {
                    self.evolveNextSongShouldLog = false
                    self.evolveNextSongLogged    = true
                    self.appendToLog([GenerationLogEntry(tag: "Up next",
                        description: "\(state.style.rawValue) - \(state.title)", isTitle: true)])
                }
            }
        }
    }

    private func handleEvolveOutroStart() {
        guard evolvePhase == .original else { return }
        if let pass1 = evolvePass1State {
            doSwitchToEvolvePass1(pass1)
        } else {
            appendToLog([GenerationLogEntry(tag: "Evolve", description: "Generating pass...", isTitle: false)])
            guard let anchor = evolveAnchorState else { return }
            let passBars = evolvePass1Bars
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let state = Self.buildPassState(anchor: anchor, freshTracks: [kTrackLead1, kTrackLead2],
                                                passBars: passBars)
                await MainActor.run {
                    guard self.playMode == .evolve, self.evolvePhase == .original else { return }
                    self.doSwitchToEvolvePass1(state)
                }
            }
        }
    }

    private func doSwitchToEvolvePass1(_ pass1: SongState) {
        guard let anchor = evolveAnchorState else { return }
        evolvePhase       = .pass1
        evolvePhaseToken += 1
        // Keep evolvePass1State for building extendedState2 later
        evolvePass1State = pass1

        let outroStartBar = anchor.structure.outroSection?.startBar ?? anchor.frame.totalBars
        let extended = Self.buildExtendedState(anchor: anchor, outroStartBar: outroStartBar,
                                               pass1Events: pass1.trackEvents, pass1Bars: evolvePass1Bars)
        songState        = extended
        lastEmittedStep  = outroStartBar * 16 - 1
        visibleBarOffset = max(0, outroStartBar - Int(Double(visibleBars) * 0.15))
        switchEvolveInstruments(freshTracks: [kTrackLead1, kTrackLead2])
        appendToLog(pass1.generationLog)
        playback.loadAndPlay(state: extended, fromStep: outroStartBar * 16)
    }

    private func doSwitchToEvolvePass2(_ pass2: SongState) {
        guard let anchor = evolveAnchorState, let pass1 = evolvePass1State else { return }
        evolvePhase       = .pass2
        evolvePhaseToken += 1
        // Keep evolvePass2State for building extendedStateWithOutro later
        evolvePass2State = pass2

        let outroStartBar = anchor.structure.outroSection?.startBar ?? anchor.frame.totalBars
        let extended = Self.buildExtendedState(anchor: anchor, outroStartBar: outroStartBar,
                                               pass1Events: pass1.trackEvents, pass1Bars: evolvePass1Bars,
                                               pass2Events: pass2.trackEvents, pass2Bars: evolvePass2Bars,
                                               includeOutro: true)
        let pass2StartBar = outroStartBar + evolvePass1Bars
        songState        = extended
        lastEmittedStep  = pass2StartBar * 16 - 1
        visibleBarOffset = max(0, pass2StartBar - Int(Double(visibleBars) * 0.15))
        switchEvolveInstruments(freshTracks: [kTrackPads, kTrackRhythm])
        appendToLog(pass2.generationLog)
        playback.loadAndPlay(state: extended, fromStep: pass2StartBar * 16)
    }

    private func handleEvolveApproachingEnd() {
        switch evolvePhase {
        case .original:
            // 12 bars before Outro: if pass1 is ready, show the extended bars now and log (once only)
            guard let pass1 = evolvePass1State, let anchor = evolveAnchorState,
                  (songState?.frame.totalBars ?? 0) <= anchor.frame.totalBars else { break }
            let outroStartBar = anchor.structure.outroSection?.startBar ?? anchor.frame.totalBars
            let extended = Self.buildExtendedState(anchor: anchor, outroStartBar: outroStartBar,
                                                   pass1Events: pass1.trackEvents, pass1Bars: evolvePass1Bars)
            songState = extended
            appendToLog([GenerationLogEntry(tag: "Upcoming",
                description: "Evolving section \(evolvePass1Bars) bars with new leads",
                isTitle: false)])
        case .pass1:
            preGeneratePassContent(pass: 2)
            preGenerateEvolveNextSong()   // start next-song gen early so it's ready at the 12-bar mark
        case .pass2, .outro:
            // onApproachingEnd fires 12 bars before the outro of the extended state while
            // evolvePhase is still .pass2 (onOutroStart hasn't fired yet). This is the right
            // moment to show "Up next" — same timing as Endless mode.
            // The .outro branch is a fallback — normally unreachable because onApproachingEnd
            // fires exactly once per loadAndPlay and the .pass2 case handles it first.
            if let next = evolveNextSongState, !evolveNextSongLogged {
                evolveNextSongLogged = true
                appendToLog([GenerationLogEntry(tag: "Up next",
                    description: "\(next.style.rawValue) - \(next.title)", isTitle: true)])
            } else if !evolveNextSongLogged {
                evolveNextSongShouldLog = true
                preGenerateEvolveNextSong()
            }
        case .inactive: break
        }
    }

    private func handleEvolvePhaseEnded() {
        switch evolvePhase {
        case .original:
            // Song ended without triggering outro start (e.g. no outro section)
            handleEvolveOutroStart()
        case .pass1:
            if let pass2 = evolvePass2State {
                doSwitchToEvolvePass2(pass2)
            } else {
                appendToLog([GenerationLogEntry(tag: "Evolve", description: "Generating pass 2...", isTitle: false)])
                guard let anchor = evolveAnchorState else { return }
                let passBars = evolvePass2Bars
                Task.detached(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    let state = Self.buildPassState(anchor: anchor, freshTracks: [kTrackPads, kTrackRhythm],
                                                    passBars: passBars)
                    await MainActor.run {
                        guard self.playMode == .evolve, self.evolvePhase == .pass1 else { return }
                        self.doSwitchToEvolvePass2(state)
                    }
                }
            }
        case .pass2, .outro:
            transitionToEvolveNextSong()
        case .inactive:
            break
        }
    }

    private func transitionToEvolveNextSong() {
        if let next = evolveNextSongState {
            evolveNextSongState = nil
            if !evolveNextSongLogged {
                appendToLog([GenerationLogEntry(tag: "Up next",
                    description: "\(next.style.rawValue) - \(next.title)", isTitle: true)])
            }
            finishLoadingEvolveSong(next)
        } else {
            appendToLog([GenerationLogEntry(tag: "Evolve", description: "Loading next song...", isTitle: false)])
            guard let anchor = evolveAnchorState else { return }
            let style = anchor.style
            let mood  = evolveMoodAnchor
            let tempo = evolveTempoAnchor
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let bpmDelta = Int.random(in: -5...5)
                let newTempo = max(20, min(200, tempo + bpmDelta))
                let state = SongGenerator.generate(tempoOverride: newTempo, moodOverride: mood,
                                                   style: style, testMode: false)
                await MainActor.run {
                    guard self.playMode == .evolve else { return }
                    if !self.evolveNextSongLogged {
                        self.appendToLog([GenerationLogEntry(tag: "Up next",
                            description: "\(state.style.rawValue) - \(state.title)", isTitle: true)])
                    }
                    self.finishLoadingEvolveSong(state)
                }
            }
        }
    }

    private func finishLoadingEvolveSong(_ state: SongState) {
        tearDownEvolve()           // resets evolveMoodAnchor to nil
        appendSongHistory(from: state)
        selectedStyle = state.style
        finishLoadingSong(state, thenPlay: true)
        // Append the full generation log (title, key, mode, rules) for the new song,
        // same as generateNew does — so the status area shows all the song details.
        var batch: [GenerationLogEntry] = []
        if !statusLog.isEmpty {
            batch.append(GenerationLogEntry(tag: "", description: "", isTitle: false))
        }
        batch.append(contentsOf: state.generationLog)
        appendToLog(batch)
        // Song 2 already matched song 1's mood (enforced at pre-gen time via evolveMoodAnchor).
        // From song 3 onward, lockMoodToSong: false so mood is picked freely each time.
        startEvolveMode(from: state, lockMoodToSong: false)
    }

    /// Skip to the next evolution pass immediately (Evolve mode ⏭ button).
    func skipEvolvePass() {
        guard playMode == .evolve else { return }
        switch evolvePhase {
        case .original: handleEvolveOutroStart()
        case .pass1:    handleEvolvePhaseEnded()
        case .pass2:    transitionToEvolveNextSong()
        case .outro:    transitionToEvolveNextSong()
        case .inactive: break
        }
    }

    /// Shared song-loading kernel for Endless transitions and ⏮ rewind.
    /// Stops current playback, loads `state`, and plays if `thenPlay` is true.
    private func finishLoadingSong(_ state: SongState, thenPlay: Bool) {
        playback.stop()
        audioTexture.stop()
        songState = state
        generationHistory.append(state)
        if generationHistory.count > 5 { generationHistory.removeFirst() }
        visibleBarOffset = 0
        lastEmittedStep  = -1
        muteState = Array(repeating: false, count: kTrackCount)
        soloState = Array(repeating: false, count: kTrackCount)
        playback.muteState = muteState
        playback.soloState = soloState
        playback.kosmicStyle  = state.style == .kosmic
        playback.motorikStyle = state.style == .motorik
        playback.chillFade    = false
        playback.setAmbientMode(state.style == .ambient)
        playback.setChillMode(state.style == .chill)
        playback.load(state)
        playback.seek(toStep: 0)
        defaultsResetToken += 1
        if thenPlay {
            playback.play()
            audioTexture.start(style: state.style, texture: state.chillAudioTexture,
                               offsetSeconds: state.chillAudioTextureOffset)
        }
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    /// Step back one bar. Clamps at bar 0.
    func seekBackOneBar() {
        let targetBar = max(0, playback.currentBar - 1)
        seekEdgeSensitive(toBar: targetBar)
    }

    /// Step back two bars. Clamps at bar 0.
    func seekBackTwoBars() {
        let targetBar = max(0, playback.currentBar - 2)
        seekEdgeSensitive(toBar: targetBar)
    }

    /// Step forward one bar. Clamps at last bar.
    func seekForwardOneBar() {
        guard let song = songState else { return }
        let targetBar = min(song.frame.totalBars - 1, playback.currentBar + 1)
        seekEdgeSensitive(toBar: targetBar)
    }

    /// Step forward two bars. Clamps at last bar.
    func seekForwardTwoBars() {
        guard let song = songState else { return }
        let targetBar = min(song.frame.totalBars - 1, playback.currentBar + 2)
        seekEdgeSensitive(toBar: targetBar)
    }

    /// Moves the playhead to `targetBar` without scrolling the visible window, unless the
    /// target is within the outer 10% of the window — in which case the window scrolls just
    /// enough to keep the playhead visible with a small margin.
    private func seekEdgeSensitive(toBar targetBar: Int) {
        playback.seek(toStep: targetBar * 16)

        let totalBars  = songState?.frame.totalBars ?? 32
        let winStart   = visibleBarOffset
        let winEnd     = visibleBarOffset + visibleBars
        let lowEdge    = winStart + max(1, Int(Double(visibleBars) * 0.10))
        let highEdge   = winEnd   - max(1, Int(Double(visibleBars) * 0.10))

        if targetBar < lowEdge {
            // Approaching left edge — scroll so target sits ~20% from the left
            visibleBarOffset = max(0, targetBar - Int(Double(visibleBars) * 0.20))
        } else if targetBar >= highEdge {
            // Approaching right edge — scroll so target sits ~80% from the left
            let ideal = targetBar - Int(Double(visibleBars) * 0.80)
            visibleBarOffset = max(0, min(ideal, totalBars - visibleBars))
        }
        // Target is safely within the middle 80% — no scroll needed
    }

    /// Space-bar toggle: play if stopped, stop if playing.
    func playOrStop() {
        if playback.isPlaying {
            stop()
        } else {
            play()
        }
    }

    // MARK: - MIDI export

    @Published var lastSaveURL: URL? = nil

    func saveMIDI() {
        guard let song = songState else { return }
        do {
            let url = try MIDIFileExporter.export(song)
            lastSaveURL = url
            print("MIDI saved: \(url.path)")
            try? SongLogExporter.export(song, midiURL: url)
            appendToLog([
                GenerationLogEntry(tag: "FILE", description: "Saved as MIDI \(url.lastPathComponent)")
            ])
        } catch {
            print("MIDI export error: \(error)")
        }
    }

    // MARK: - Load from log

    func loadFromLog() {
        let panel = NSOpenPanel()
        panel.title = "Load Zudio Song"
        panel.message = "Select a Zudio song file (.zudio or .txt)"
        // Accept both the new .zudio type and plain-text .txt files from earlier versions
        var types: [UTType] = [.plainText]
        if let zudioType = UTType("com.zudio.song") { types.insert(zudioType, at: 0) }
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFromLogURL(url)
    }

    func loadFromLogURL(_ url: URL) {
        // If a generation is in progress, queue the URL and load it when generation finishes.
        if isGenerating {
            pendingLoadURL = url
            return
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            appendToLog([GenerationLogEntry(tag: "FILE", description: "Could not load file -- could not read \(url.lastPathComponent)", isTitle: false)])
            return
        }

        var globalSeed: UInt64? = nil
        var style: MusicStyle = .kosmic
        var trackOverrides: [Int: UInt64] = [:]
        var forcedRules: [String: String] = [:]
        var songTitle: String = ""
        var zudioVersion: String = "0.91a"   // inferred for logs that pre-date version field
        var loadedKeyOverride:   String? = nil
        var loadedTempoOverride: Int?    = nil
        var loadedMoodOverride:  Mood?   = nil

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Title:") {
                songTitle = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Zudio Version:") {
                zudioVersion = trimmed.dropFirst(14).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Seed:") {
                globalSeed = UInt64(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Style:") {
                let val = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                style = MusicStyle(rawValue: val) ?? .kosmic
            } else if trimmed.hasPrefix("Key Override:") {
                // "C#" — user had a key override active at generation time
                let val = trimmed.dropFirst(13).trimmingCharacters(in: .whitespaces)
                loadedKeyOverride = val.components(separatedBy: .whitespaces).first
            } else if trimmed.hasPrefix("Tempo Override:") {
                // "121" — user had a tempo override active at generation time
                let val = trimmed.dropFirst(15).trimmingCharacters(in: .whitespaces)
                loadedTempoOverride = Int(val.components(separatedBy: .whitespaces).first ?? "")
            } else if trimmed.hasPrefix("Mood Override:") {
                // "Bright" — user had a mood override active at generation time
                let val = trimmed.dropFirst(14).trimmingCharacters(in: .whitespaces)
                loadedMoodOverride = Mood(rawValue: val)
            } else if trimmed.hasPrefix("Track Overrides:") {
                let val = trimmed.dropFirst(16).trimmingCharacters(in: .whitespaces)
                for pair in val.components(separatedBy: "  ") {
                    let parts = pair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
                    if parts.count == 2, let idx = Int(parts[0]), let s = UInt64(parts[1]) {
                        trackOverrides[idx] = s
                    }
                }
            } else if trimmed.hasPrefix("Forced Rules:") {
                let val = trimmed.dropFirst(13).trimmingCharacters(in: .whitespaces)
                for pair in val.components(separatedBy: "  ") {
                    let parts = pair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
                    if parts.count == 2 {
                        forcedRules[parts[0]] = parts[1]
                    }
                }
            }
        }

        guard let seed = globalSeed else {
            appendToLog([GenerationLogEntry(tag: "FILE", description: "Could not load file -- missing seed information", isTitle: false)])
            return
        }

        // Stop playback immediately so the old song goes silent while the new one loads.
        // Also stop the audio texture immediately (switchTexture(nil) → stopImmediate) so
        // the new song's texture can start cleanly when the user presses Play.
        playback.stop()
        audioTexture.switchTexture(nil)
        isGenerating = true
        let overrides     = trackOverrides
        let loadForced    = forcedRules
        let loadTitle     = songTitle
        let loadVersion   = zudioVersion
        let loadKey       = loadedKeyOverride
        let loadTempo     = loadedTempoOverride
        let loadMood      = loadedMoodOverride
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var state = SongGenerator.generate(
                seed:             seed,
                keyOverride:      loadKey,
                tempoOverride:    loadTempo,
                moodOverride:     loadMood,
                style:            style,
                forceBassRuleID:  loadForced["Bass"],
                forceDrumRuleID:  loadForced["Drums"],
                forceArpRuleID:   loadForced["Rhythm"],
                forcePadsRuleID:  loadForced["Pads"],
                forceLeadRuleID:  loadForced["Lead"],
                forceTexRuleID:   loadForced["Tex"]
            )
            for trackIdx in overrides.keys.sorted() {
                state = SongGenerator.regenerateTrack(trackIdx, songState: state, overrideSeed: overrides[trackIdx])
            }
            await MainActor.run {
                self.selectedStyle    = style
                self.keyOverride      = loadKey
                self.tempoOverride    = loadTempo
                self.moodOverride     = loadMood
                if !loadTitle.isEmpty { state.title = loadTitle }
                self.songState        = state
                self.generationHistory.append(state)
                if self.generationHistory.count > 5 { self.generationHistory.removeFirst() }
                self.isGenerating     = false
                self.visibleBarOffset = 0
                self.lastEmittedStep  = -1
                self.instrumentOverrides = [:]
                // Restore the Chill texture picker to reflect the loaded song's texture.
                if style == .chill {
                    let prog = Self.chillTextureProgram(forFilename: state.chillAudioTexture)
                    self.instrumentOverrides[kTrackTexture] = Int(prog) - 240
                }
                self.songGenerationCount += 1
                self.stylesWithGeneratedSongs.insert(style)
                self.muteState = Array(repeating: false, count: kTrackCount)
                self.soloState = Array(repeating: false, count: kTrackCount)
                self.playback.muteState = self.muteState
                self.playback.soloState = self.soloState
                var batch: [GenerationLogEntry] = []
                if !self.statusLog.isEmpty {
                    batch.append(GenerationLogEntry(tag: "", description: "", isTitle: false))
                }
                let nameStr = loadTitle.isEmpty ? "" : " \(loadTitle)"
                batch.append(GenerationLogEntry(tag: "FILE", description: "Loading song:\(nameStr)  --Zudio \(loadVersion)", isTitle: false))
                batch.append(contentsOf: state.generationLog)
                self.appendToLog(batch)
                let wasPlaying = self.playback.isPlaying
                self.playback.stop()
                self.playback.kosmicStyle  = style == .kosmic
                self.playback.motorikStyle = style == .motorik
                self.playback.chillFade = style == .chill && {
                    if case .alreadyPlaying = state.structure.introStyle { return true }
                    return false
                }()
                self.playback.load(state)
                self.playback.seek(toStep: 0)
                self.playback.setAmbientMode(style == .ambient)
                self.playback.setChillMode(style == .chill)
                self.defaultsResetToken += 1
                if wasPlaying { self.playback.play() }
                NSApp.keyWindow?.makeFirstResponder(nil)
                // If another file-open arrived while we were loading, load it now.
                self.consumePendingLoad()
            }
        }
    }

    /// Loads any URL that was queued while a generation/load was in progress.
    /// Must be called on the MainActor immediately after setting isGenerating = false.
    private func consumePendingLoad() {
        if let url = pendingLoadURL {
            pendingLoadURL = nil
            loadFromLogURL(url)
        }
    }

    // MARK: - Audio export

    @Published var isExportingAudio:      Bool   = false
    @Published var audioExportProgress:   Double = 0
    @Published var audioExportFilename:   String = ""
    @Published var showExportConfirmation: Bool  = false

    /// Called from button/menu/keyboard — shows the confirmation dialog.
    func requestExport() {
        guard songState != nil, !isExportingAudio else { return }
        showExportConfirmation = true
    }

    /// Called when the user presses Full Song or Sample in the confirmation dialog.
    func startExport(sampleMode: Bool = false) {
        guard let song = songState, !isExportingAudio else { return }
        let url = AudioFileExporter.nextURL(songName: song.title, sampleMode: sampleMode)
        audioExportFilename = url.lastPathComponent
        audioExportProgress = 0
        isExportingAudio    = true
        visibleBarOffset    = 0   // snap scroll back to bar 0 so display matches the render
        let style = selectedStyle.rawValue.capitalized
        playback.exportAudio(url: url, state: song, sampleMode: sampleMode) { [weak self] progress in
            Task { @MainActor [weak self] in self?.audioExportProgress = progress }
        } onComplete: { [weak self] error in
            Task { @MainActor [weak self] in
                self?.isExportingAudio = false
                if let error {
                    if error is CancellationError {
                        try? FileManager.default.removeItem(at: url)
                        print("Audio export cancelled — file deleted")
                    } else {
                        print("Audio export error: \(error)")
                    }
                    return
                }
                // Success — log and add metadata.
                print("Audio saved: \(url.path)")
                self?.appendToLog([
                    GenerationLogEntry(tag: "FILE", description: "Exported audio \(url.lastPathComponent)")
                ])
                await AudioFileExporter.addMetadata(
                    to: url,
                    title: song.title,
                    artist: "Zudio",
                    genre: style
                )
            }
        }
    }

    /// Cancels an in-progress export; the partial file is deleted.
    func cancelExport() {
        playback.cancelExport()
    }

    // MARK: - Instrument

    func setProgram(_ program: UInt8, forTrack trackIndex: Int) {
        // Chill texture track uses pseudo-programs 240–247 that map to M4A filenames.
        if trackIndex == kTrackTexture && selectedStyle == .chill {
            let filename = Self.chillTextureFilename(forProgram: program)
            songState = songState?.withChillAudioTexture(filename)
            if playback.isPlaying {
                audioTexture.switchTexture(filename, offsetSeconds: songState?.chillAudioTextureOffset ?? 0)
            }
            return
        }
        playback.setProgram(program, forTrack: trackIndex)
    }

    /// Maps a Chill texture pseudo-program (240–250) to an M4A filename.
    static func chillTextureFilename(forProgram program: UInt8) -> String? {
        switch program {
        case 240: return nil
        case 241: return "another_bar.m4a"
        case 242: return "bar_sounds.m4a"
        case 243: return "city_at_night.m4a"
        case 244: return nil  // removed
        case 245: return "harbor.m4a"
        case 246: return "light_rain.m4a"
        case 247: return "ocean_waves.m4a"
        case 248: return "urban_rain.m4a"
        case 249: return nil  // removed
        case 250: return "vinyl_crackle.m4a"
        default:  return nil
        }
    }

    /// Maps a Chill audio texture filename to its pseudo-program number for the instrument picker.
    static func chillTextureProgram(forFilename filename: String?) -> UInt8 {
        switch filename {
        case nil:                   return 240
        case "another_bar.m4a":    return 241
        case "bar_sounds.m4a":     return 242
        case "city_at_night.m4a":  return 243
        // 244 removed (city_sounds)
        case "harbor.m4a":         return 245
        case "light_rain.m4a":     return 246
        case "ocean_waves.m4a":    return 247
        case "urban_rain.m4a":     return 248
        // 249 removed (urban_sounds)
        case "vinyl_crackle.m4a":  return 250
        default:                    return 240
        }
    }

    func setEffect(_ effect: TrackEffect, enabled: Bool, forTrack trackIndex: Int) {
        // Chill texture track effects are routed to AudioTexturePlayer's own effect chain.
        if trackIndex == kTrackTexture && selectedStyle == .chill {
            audioTexture.setEffect(effect, enabled: enabled)
            return
        }
        playback.setEffect(effect, enabled: enabled, forTrack: trackIndex)
    }

    // MARK: - Mute / Solo

    func toggleMute(_ trackIndex: Int) {
        muteState[trackIndex].toggle()
        playback.muteState = muteState
    }

    func toggleSolo(_ trackIndex: Int) {
        soloState[trackIndex].toggle()
        playback.soloState = soloState
        // AudioTexturePlayer is outside PlaybackEngine's mute graph — update its volume manually.
        // Mute it when any solo is active and kTrackTexture is NOT one of the soloed tracks.
        let textureSoloed = !isAnySolo || soloState[kTrackTexture]
        audioTexture.setSoloMuted(!textureSoloed)
    }

    // MARK: - Solo visual helper

    var isAnySolo: Bool { soloState.contains(true) }

    func isEffectivelyMuted(_ trackIndex: Int) -> Bool {
        isAnySolo && !soloState[trackIndex]
    }
}
