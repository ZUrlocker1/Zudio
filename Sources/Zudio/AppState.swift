// AppState.swift — global observable app state, shared across all views

import SwiftUI
import AppKit
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Song state

    @Published var songState: SongState? = nil
    @Published var isGenerating: Bool = false

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

    @Published var selectedStyle: MusicStyle = .kosmic

    // Incremented to signal TrackRowViews to reset instruments + effects to style defaults.
    // Fired on generateNew() and on the manual Reset button.
    @Published var defaultsResetToken: Int = 0

    func resetTrackDefaults() {
        instrumentOverrides = [:]
        songGenerationCount = 0
        keyOverride   = nil
        tempoOverride = nil
        moodOverride  = nil
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

    // Kosmic/Motorik 10-slot cycle: 90% of slots target currently new/modified rules.
    // Motorik lead rules (MOT-LD1-*) are silently ignored when style=Kosmic, and vice versa.
    // Slot 0: MOT-LD1-001* lead                    [Motorik — directional contour]
    // Slot 1: MOT-LD1-006* lead                    [Motorik — long arc solo]
    // Slot 2: KOS-LEAD-006* lead                   [Kosmic  — JMJ phrase loop]
    // Slot 3: KOS-LEAD-007* lead                   [Kosmic  — TD skip sequence]
    // Slot 4: KOS-LEAD-004* lead                   [Kosmic  — echo melody]
    // Slot 5: KOS-BASS-012* bass                   [Kosmic  — McCartney PBW]
    // Slot 6: MOT-LD1-001* lead (repeat)           [Motorik]
    // Slot 7: KOS-LEAD-006* lead + KOS-BASS-012*   [Kosmic combo]
    // Slot 8: MOT-LD1-006* lead (repeat)           [Motorik]
    // Slot 9: fully free                           [sanity / comparison baseline]
    private static let testCycle: [TestModeConfig] = [
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-001", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-006", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "KOS-LEAD-006", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "KOS-LEAD-007", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "KOS-LEAD-004", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: "KOS-BASS-012", forcePadsRuleID: nil, forceLeadRuleID: nil,            forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-001", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: "KOS-BASS-012", forcePadsRuleID: nil, forceLeadRuleID: "KOS-LEAD-006", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "MOT-LD1-006", forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil, forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: nil,            forceTexRuleID: nil, forcePercussionStyle: nil, forceBridge: false, forceBridgeArchetype: nil),
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
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-001", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-002", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-003", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-007", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-008", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: "AMB-BASS-001", forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-001", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: "AMB-BASS-003", forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-001", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: "AMB-RTHM-005", forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-001", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: "AMB-RTHM-006", forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-001", forceTexRuleID: nil, forcePercussionStyle: .textural,  forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: "AMB-LEAD-001", forceTexRuleID: nil, forcePercussionStyle: .softPulse, forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: nil,            forceTexRuleID: nil, forcePercussionStyle: .absent,    forceBridge: false, forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: nil,            forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: nil,            forceTexRuleID: nil, forcePercussionStyle: nil,         forceBridge: false, forceBridgeArchetype: nil),
    ]

    private func nextTestConfig() -> TestModeConfig? {
        guard testModeEnabled else { return nil }
        let cycle = selectedStyle == .ambient ? Self.ambientTestCycle : Self.testCycle
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
        case (kTrackLead1,   .ambient): return ["Flute","Ocarina","Pan Flute","Whistle","Recorder","Brightness","Halo Pad","New Age Pad","Calliope Lead"]
        case (kTrackLead1,   .kosmic):  return ["Ocarina","Flute","Whistle","Calliope Lead"]
        case (kTrackLead1,   _):        return ["Square Lead","Mono Synth","Synth Brass","Synth Brass 2","Fifths Lead","Moog Lead","Overdrive Gtr"]
        case (kTrackLead2,   .ambient): return ["Vibraphone","Celesta","Glockenspiel","Grand Piano","Warm Pad","Space Voice","FX Atmosphere"]
        case (kTrackLead2,   .kosmic):  return ["Brightness","Warm Pad","Halo Pad","New Age Pad","Ocarina"]
        case (kTrackLead2,   _):        return ["Brightness","Vibraphone","Bell/Pluck"]
        case (kTrackPads,    .ambient): return ["String Ensemble","Choir Aahs","Synth Strings","Bowed Glass","Warm Pad","Halo Pad","New Age Pad","Sweep Pad"]
        case (kTrackPads,    .kosmic):  return ["Choir Aahs","String Ensemble","Synth Strings","Warm Pad","Space Voice"]
        case (kTrackPads,    _):        return ["Warm Pad","Halo Pad","New Age Pad","Sweep Pad","Bowed Glass","Synth Strings","String Pad","Organ Drone"]
        case (kTrackRhythm,  .ambient): return ["Vibraphone","Marimba","Tubular Bells","Glockenspiel","FX Crystal","FX Echoes","Church Organ"]
        case (kTrackRhythm,  .kosmic):  return ["FX Crystal","Vibraphone","Elec Piano 2","Church Organ","Tremolo Strings"]
        case (kTrackRhythm,  _):        return ["Guitar Pulse","Wurlitzer","Rock Organ","Clavinet","Electric Piano","Muted Guitar","Mono Synth"]
        case (kTrackTexture, .ambient): return ["String Ensemble 2","Bowed Glass","Choir Aahs","Space Voice","FX Atmosphere","Sweep Pad","Pad 3 Poly"]
        case (kTrackTexture, .kosmic):  return ["FX Atmosphere","Pad 3 Poly","Sweep Pad"]
        case (kTrackTexture, _):        return ["Halo Pad","Warm Pad","Space Voice","Swell","FX Atmosphere","FX Echoes"]
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

    @Published var muteState: [Bool] = Array(repeating: false, count: 7)
    @Published var soloState: [Bool] = Array(repeating: false, count: 7)

    // MARK: - Live playback feed (Now Playing strip)

    @Published var livePlaybackFeed: [GenerationLogEntry] = []
    private var lastEmittedStep: Int = -1

    // MARK: - Playback engine

    let playback = PlaybackEngine()

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
                case 15: // 'r' — reset
                    guard songState != nil else { return event }
                    Task { @MainActor [weak self] in self?.resetTrackDefaults() }
                case 40: // 'k' — Kosmic
                    Task { @MainActor [weak self] in self?.selectedStyle = .kosmic }
                case 4:  // 'h' — help
                    Task { @MainActor [weak self] in self?.triggerShowHelp.toggle() }
                case 0:  // 'a' — Ambient
                    Task { @MainActor [weak self] in self?.selectedStyle = .ambient }
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
            let bestPerc: PercussionStyle?
            let bestBridge: Bool
            switch style {
            case .motorik:
                bestBass   = "MOT-BASS-015"
                bestDrum   = "MOT-DRUM-001"
                bestArp    = "MOT-RTHM-001"
                bestLead   = nil
                bestPerc   = nil
                bestBridge = false
            case .kosmic:
                bestBass   = "KOS-BASS-010"
                bestDrum   = nil
                bestArp    = "KOS-RTHM-002"
                bestLead   = nil
                bestPerc   = .motorikGrid   // → KOS-DRUM-004 Electric Buddha groove
                bestBridge = true
            case .ambient:
                bestBass   = nil
                bestDrum   = nil
                bestArp    = nil
                bestLead   = "AMB-LEAD-003"
                bestPerc   = .handPercussion  // → AMB-DRUM-004 hand percussion
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
                forceTexRuleID:       testConfig?.forceTexRuleID,
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
                var instrumentLogDesc: String? = nil
                if self.songGenerationCount > 0 {
                    var eligible = Self.randomizableTrackIndices
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
                self.songGenerationCount += 1
                self.stylesWithGeneratedSongs.insert(style)

                // Build the batch to append: optional separator + generation log + instruments entry
                var batch: [GenerationLogEntry] = []
                if !self.statusLog.isEmpty {
                    batch.append(GenerationLogEntry(tag: "", description: "", isTitle: false))
                }
                var logEntries = state.generationLog
                if let desc = instrumentLogDesc {
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
                self.muteState = Array(repeating: false, count: 7)
                self.soloState = Array(repeating: false, count: 7)
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
                self.playback.load(state)
                self.playback.seek(toStep: 0)
                // Configure ambient mode before defaultsResetToken fires so setEffect
                // uses the correct Ambient reverb/delay values from the start.
                self.playback.setAmbientMode(self.selectedStyle == .ambient)
                // Reset instruments + effects BEFORE play so setProgram() doesn't race
                // against the first note firing.
                self.defaultsResetToken += 1
                if thenPlay || wasPlaying { self.playback.play() }
                // Resign first responder so BPM TextField doesn't hold focus
                NSApp.keyWindow?.makeFirstResponder(nil)
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
            playback.play()
        }
    }

    func stop() {
        NSApp.activate(ignoringOtherApps: true)
        playback.stop()
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
        panel.title = "Load Song from Log File"
        panel.message = "Select a Zudio .txt log file to reload the song"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFromLogURL(url)
    }

    private func loadFromLogURL(_ url: URL) {
        guard !isGenerating else { return }
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

        isGenerating = true
        let overrides     = trackOverrides
        let loadForced    = forcedRules
        let loadTitle     = songTitle
        let loadVersion   = zudioVersion
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var state = SongGenerator.generate(
                seed:             seed,
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
                self.songState        = state
                self.generationHistory.append(state)
                if self.generationHistory.count > 5 { self.generationHistory.removeFirst() }
                self.isGenerating     = false
                self.visibleBarOffset = 0
                self.lastEmittedStep  = -1
                self.instrumentOverrides = [:]
                self.songGenerationCount += 1
                self.stylesWithGeneratedSongs.insert(style)
                self.muteState = Array(repeating: false, count: 7)
                self.soloState = Array(repeating: false, count: 7)
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
                self.playback.load(state)
                self.playback.seek(toStep: 0)
                self.playback.setAmbientMode(style == .ambient)
                self.defaultsResetToken += 1
                if wasPlaying { self.playback.play() }
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
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
        playback.setProgram(program, forTrack: trackIndex)
    }

    func setEffect(_ effect: TrackEffect, enabled: Bool, forTrack trackIndex: Int) {
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
