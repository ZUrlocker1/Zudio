// AppState.swift — global observable app state, shared across all views

import SwiftUI
import AppKit
import Combine
import MediaPlayer
import UniformTypeIdentifiers

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

    // Motorik 10-slot cycle: all slots force the two new extended solos (007/008) alternating.
    // Old Motorik rules (001–006), old bass rules, and Kosmic rules removed from rotation.
    // Slot 0: MOT-LD1-007* lead   [Vanishing solo]
    // Slot 1: MOT-LD1-008* lead   [Visiting solo]
    // Slot 2: MOT-LD1-007* lead   [Vanishing solo]
    // Slot 3: MOT-LD1-008* lead   [Visiting solo]
    // Slot 4: MOT-LD1-007* lead   [Vanishing solo]
    // Slot 5: MOT-LD1-008* lead   [Visiting solo]
    // Slot 6: MOT-LD1-007* lead   [Vanishing solo]
    // Slot 7: MOT-LD1-008* lead   [Visiting solo]
    // Slot 8: MOT-LD1-007* lead   [Vanishing solo]
    // Slot 9: MOT-LD1-008* lead   [Visiting solo]
    private static let testCycle: [TestModeConfig] = [
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-007", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-008", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-007", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-008", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-007", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-008", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-007", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-008", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-007", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil, forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-008", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
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

    // Kosmic 10-slot cycle: exercises the 3 second-batch modified rules (DRUM-002 hat density,
    // BASS-004 ghost note, PADS-008 density guard) plus the first-batch rhythm/texture fixes.
    // DRUM-002 exercised via forcePercussionStyle .sparse (3×); BASS-004 forced directly (3×);
    // combined DRUM-002+BASS-004 (2×); two free nil slots for natural generation.
    private static let kosmicTestCycle: [TestModeConfig] = [
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,             forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: .sparse,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,             forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: .sparse,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,             forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: .sparse,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: "KOS-BASS-004",  forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: nil,      forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: "KOS-BASS-004",  forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: nil,      forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: "KOS-BASS-004",  forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: nil,      forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: "KOS-BASS-004",  forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: .sparse,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: "KOS-BASS-004",  forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: .sparse,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,             forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: nil,      forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,             forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil, forcePercussionStyle: nil,      forceBridge: false, forceBridgeArchetype: nil),
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
        case (kTrackLead1,   .kosmic):  return ["Flute","Brightness"]
        case (kTrackLead1,   _):        return ["Mono Synth","Soft Brass","Fifths Lead","Moog Lead"]
        case (kTrackLead2,   .chill):   return ["Vibraphone","Flute","Soprano Sax","Trombone"]
        case (kTrackLead2,   .ambient): return ["Vibraphone","Celesta","Glockenspiel","Grand Piano","Warm Pad","Space Voice","FX Atmosphere"]
        case (kTrackLead2,   .kosmic):  return ["Brightness","Warm Pad","Halo Pad","New Age Pad"]
        case (kTrackLead2,   _):        return ["Brightness","Vibraphone","Bell/Pluck"]
        case (kTrackPads,    .chill):   return ["Warm Pad","Synth Strings","String Pad","Sweep Pad"]
        case (kTrackPads,    .ambient): return ["Choir Aahs","Synth Strings","Bowed Glass","Warm Pad","Halo Pad","New Age Pad","Sweep Pad"]
        case (kTrackPads,    .kosmic):  return ["Choir Aahs","Synth Strings","Warm Pad","Space Voice"]
        case (kTrackPads,    _):        return ["Halo Pad","Sweep Pad","Bowed Glass","Synth Strings","Organ Drone"]
        case (kTrackRhythm,  .chill):  return ["Rhodes","Wurlitzer","Grand Piano"]
        case (kTrackRhythm,  .ambient): return ["Vibraphone","Marimba","Tubular Bells","Glockenspiel","FX Crystal","FX Echoes","Church Organ"]
        case (kTrackRhythm,  .kosmic):  return ["FX Crystal","Vibraphone","Wurlitzer","Church Organ"]
        case (kTrackRhythm,  _):        return ["Guitar Pulse","Wurlitzer","Rock Organ","Rhodes","Muted Guitar"]
        case (kTrackTexture, .chill):   return ["None","Bar sounds","City at night","Light rain","Ocean waves","Urban rain","Vinyl crackle"]
        case (kTrackTexture, .ambient): return ["String Ensemble 2","Bowed Glass","Choir Aahs","FX Atmosphere","Sweep Pad","Pad 3 Poly"]
        case (kTrackTexture, .kosmic):  return ["FX Atmosphere","Pad 3 Poly","Sweep Pad"]
        case (kTrackTexture, _):        return ["Halo Pad","Warm Pad","FX Atmosphere","FX Echoes"]
        case (kTrackBass,    .ambient): return ["Cello","Contrabass","Moog Bass","Synth Bass 1","Fretless Bass"]
        case (kTrackBass,    .kosmic):  return ["Moog Bass","Synth Bass 1","Fretless Bass"]
        case (kTrackBass,    _):        return ["Moog Bass","Lead Bass","Analog Bass","Electric Bass"]
        case (kTrackDrums,   .ambient): return ["Percussion Kit", "Brush Kit"]
        case (kTrackDrums,   .kosmic):  return ["Brush Kit","808 Kit","Machine Kit","Standard Kit"]
        case (kTrackDrums,   _):        return ["Rock Kit","808 Kit","Brush Kit"]
        default:                        return []
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

                // Instrument randomization: first song uses all defaults (index 0).
                // From the second song onwards, pick 2 random non-drums tracks and assign
                // each a random non-default instrument, so users hear the instrument variety.
                // kTrackTexture is excluded for Chill — the generator already chose the texture.
                var instrumentLogDesc: String? = nil
                if self.songGenerationCount > 0 {
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
                if self.playback.isPlaying { self.playback.load(updated) }
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
            audioTexture.start(style: selectedStyle, texture: songState?.chillAudioTexture)
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

    /// Rewind to bar 1. Keeps current play state.
    func seekToStart() {
        seekTo(step: 0)
        visibleBarOffset = 0
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
                audioTexture.switchTexture(filename)
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
    }

    // MARK: - Solo visual helper

    var isAnySolo: Bool { soloState.contains(true) }

    func isEffectivelyMuted(_ trackIndex: Int) -> Bool {
        isAnySolo && !soloState[trackIndex]
    }
}
