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

    func resetTrackDefaults() { instrumentOverrides = [:]; songGenerationCount = 0; defaultsResetToken += 1 }

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

    // 10-slot cycle focused on new Loscil/Craven Faults rules + bridges (90% bridge coverage).
    // Slot 0:  RTHM-009 * + BASS-013 * — call+response bridge                       [Kosmic]
    // Slot 1:  RTHM-010 * + BASS-013 * — escalating drum bridge                     [Kosmic]
    // Slot 2:  RTHM-009 * + TEXT-004 * — melody bridge                               [Kosmic]
    // Slot 3:  RTHM-010 * + TEXT-004 * — call+response bridge                        [Kosmic]
    // Slot 4:  RTHM-009 * + BASS-013 * + TEXT-004 * — escalating drum bridge         [Kosmic]
    // Slot 5:  RTHM-010 * + BASS-013 * — melody bridge                               [Kosmic]
    // Slot 6:  RTHM-009 * + TEXT-004 * — call+response bridge                        [Kosmic]
    // Slot 7:  RTHM-010 * + BASS-013 * + TEXT-004 * — melody bridge                  [Kosmic]
    // Slot 8:  RTHM-009 * + BASS-013 * — random bridge archetype                     [Kosmic]
    // Slot 9:  RTHM-010 * + TEXT-004 * — no forced bridge (free)                     [Kosmic]
    private static let testCycle: [TestModeConfig] = [
        TestModeConfig(forceArpRuleID: "KOS-RTHM-009", forceBassRuleID: "KOS-BASS-013", forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil,            forcePercussionStyle: .electricBuddhaRestrained, forceBridge: true,  forceBridgeArchetype: "drumAlt"),
        TestModeConfig(forceArpRuleID: "KOS-RTHM-010", forceBassRuleID: "KOS-BASS-013", forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil,            forcePercussionStyle: .electricBuddhaRestrained, forceBridge: true,  forceBridgeArchetype: "drum"),
        TestModeConfig(forceArpRuleID: "KOS-RTHM-009", forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: nil,                         forceBridge: true,  forceBridgeArchetype: "melody"),
        TestModeConfig(forceArpRuleID: "KOS-RTHM-010", forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: .electricBuddhaRestrained, forceBridge: true,  forceBridgeArchetype: "drumAlt"),
        TestModeConfig(forceArpRuleID: "KOS-RTHM-009", forceBassRuleID: "KOS-BASS-013", forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: .electricBuddhaRestrained, forceBridge: true,  forceBridgeArchetype: "drum"),
        TestModeConfig(forceArpRuleID: "KOS-RTHM-010", forceBassRuleID: "KOS-BASS-013", forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil,            forcePercussionStyle: nil,                         forceBridge: true,  forceBridgeArchetype: "melody"),
        TestModeConfig(forceArpRuleID: "KOS-RTHM-009", forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: .electricBuddhaRestrained, forceBridge: true,  forceBridgeArchetype: "drumAlt"),
        TestModeConfig(forceArpRuleID: "KOS-RTHM-010", forceBassRuleID: "KOS-BASS-013", forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: nil,                         forceBridge: true,  forceBridgeArchetype: "melody"),
        TestModeConfig(forceArpRuleID: "KOS-RTHM-009", forceBassRuleID: "KOS-BASS-013", forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: nil,            forcePercussionStyle: nil,                         forceBridge: true,  forceBridgeArchetype: nil),
        TestModeConfig(forceArpRuleID: "KOS-RTHM-010", forceBassRuleID: nil,            forcePadsRuleID: nil, forceLeadRuleID: nil, forceTexRuleID: "KOS-TEXT-004", forcePercussionStyle: nil,                         forceBridge: true,  forceBridgeArchetype: "drum"),
    ]

    private func nextTestConfig() -> TestModeConfig? {
        guard testModeEnabled else { return nil }
        let config = Self.testCycle[testCycleIndex % Self.testCycle.count]
        testCycleIndex += 1
        return config
    }

    // MARK: - Instrument randomization
    // After the first generation (all-defaults), each new song picks 2 random non-drums tracks
    // and assigns each a random non-default instrument from that track's pool.
    // instrumentOverrides maps trackIndex → instrumentIndex; TrackRowView reads this on defaultsResetToken.

    private var songGenerationCount = 0
    var instrumentOverrides: [Int: Int] = [:]

    private static let randomizableTrackIndices = [kTrackLead1, kTrackLead2, kTrackPads, kTrackRhythm, kTrackTexture, kTrackBass, kTrackDrums]

    private static let trackDisplayName: [Int: String] = [
        kTrackLead1: "Lead 1", kTrackLead2: "Lead 2", kTrackPads: "Pads",
        kTrackRhythm: "Rhythm", kTrackTexture: "Texture", kTrackBass: "Bass", kTrackDrums: "Drums"
    ]

    static func instrumentPoolNames(trackIndex: Int, style: MusicStyle) -> [String] {
        let c = style == .kosmic
        switch trackIndex {
        case kTrackLead1:   return c ? ["Ocarina","Flute","Whistle","Calliope Lead","Fifths Lead"]
                                     : ["Square Lead","Mono Synth","Synth Brass","Synth Brass 2","Fifths Lead","Moog Lead","Overdrive Gtr","Flute"]
        case kTrackLead2:   return c ? ["Brightness","Warm Pad","Halo Pad","New Age Pad"]
                                     : ["Brightness","Vibraphone","Marimba","Bell/Pluck","Soft Brass","Ocarina"]
        case kTrackPads:    return c ? ["Choir Aahs","String Ensemble","Synth Strings","Warm Pad","Space Voice"]
                                     : ["Warm Pad","Halo Pad","New Age Pad","Sweep Pad","Bowed Glass","Synth Strings","String Pad","Organ Drone"]
        case kTrackRhythm:  return c ? ["FX Crystal","Square Lead","Vibraphone","Elec Piano 2","Church Organ"]
                                     : ["Guitar Pulse","Wurlitzer","Rock Organ","Clavinet","Electric Piano","Muted Guitar","Tremolo Strings","Mono Synth"]
        case kTrackTexture: return c ? ["FX Atmosphere","Pad 3 Poly","Sweep Pad"]
                                     : ["Halo Pad","Warm Pad","Space Voice","Swell","FX Atmosphere","FX Echoes"]
        case kTrackBass:    return c ? ["Moog Bass","Synth Bass 1","Lead Bass","Fretless Bass"]
                                     : ["Moog Bass","Lead Bass","Analog Bass","Electric Bass"]
        case kTrackDrums:   return c ? ["Brush Kit","808 Kit","Machine Kit","Standard Kit"]
                                     : ["Rock Kit","808 Kit","Brush Kit"]
        default:            return []
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
            case 5, 1, 46, 15, 40, 4, 0, 11, 6:
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
                case 1:  // 's' — save MIDI
                    guard songState != nil else { return event }
                    Task { @MainActor [weak self] in self?.saveMIDI() }
                case 46: // 'm' — Motorik
                    Task { @MainActor [weak self] in self?.selectedStyle = .motorik }
                case 15: // 'r' — reset
                    guard songState != nil else { return event }
                    Task { @MainActor [weak self] in self?.resetTrackDefaults() }
                case 40: // 'k' — Kosmic
                    Task { @MainActor [weak self] in self?.selectedStyle = .kosmic }
                case 4:  // 'h' — help
                    Task { @MainActor [weak self] in self?.triggerShowHelp.toggle() }
                case 0:  // 'a' — about
                    Task { @MainActor [weak self] in self?.triggerShowAbout.toggle() }
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
                newEntries.append(contentsOf: entries)
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
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = SongGenerator.generate(
                keyOverride:     await self.keyOverride,
                tempoOverride:   await self.tempoOverride,
                moodOverride:    await self.moodOverride,
                style:           style,
                testMode:        await self.testModeEnabled,
                forceBassRuleID:      testConfig?.forceBassRuleID,
                forceArpRuleID:       testConfig?.forceArpRuleID,
                forcePadsRuleID:      testConfig?.forcePadsRuleID,
                forceLeadRuleID:      testConfig?.forceLeadRuleID,
                forceTexRuleID:       testConfig?.forceTexRuleID,
                forcePercussionStyle: testConfig?.forcePercussionStyle,
                forceBridge:          testConfig?.forceBridge ?? false,
                forceBridgeArchetype: testConfig?.forceBridgeArchetype
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
                // Reflect key/mood back so the user can see what was picked.
                // BPM resets to Auto so the next generation is free to pick a fresh tempo.
                self.keyOverride   = state.frame.key
                self.tempoOverride = nil
                self.moodOverride  = state.frame.mood
                // Stop any in-progress playback cleanly before swapping in the new song.
                // This prevents the old scheduler from firing events against the new song state
                // during the brief window between load() and seek(), which caused desync.
                let wasPlaying = self.playback.isPlaying
                self.playback.stop()
                self.playback.kosmicStyle = self.selectedStyle == .kosmic
                self.playback.load(state)
                self.playback.seek(toStep: 0)
                // Reset instruments + effects BEFORE play so setProgram() doesn't race
                // against the first note firing.
                self.defaultsResetToken += 1
                if thenPlay || wasPlaying { self.playback.play() }
                // Resign first responder so BPM TextField doesn't hold focus
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
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
            playback.kosmicStyle = selectedStyle == .kosmic
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
        // Recenter visible window on seek position
        let totalBars = songState?.frame.totalBars ?? 32
        let targetBar = step / 16
        let newOffset = max(0, min(targetBar - Int(Double(visibleBars) * 0.15), totalBars - visibleBars))
        visibleBarOffset = newOffset
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
        } catch {
            print("MIDI export error: \(error)")
        }
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
