// AppState.swift — global observable app state, shared across all views
// Copyright (c) 2026 Zack Urlocker

import SwiftUI
import Combine
import MediaPlayer
import StoreKit
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Play mode

enum PlayMode: String, Hashable { case song, endless, evolve }

#if os(macOS)
/// Minimum content-area height (points) for the compact Mac window, excluding the title bar.
/// Referenced by AppState, ContentView, and ZudioApp — change here to update all four sites.
let kCompactContentHeight: CGFloat = 205
#endif

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

    // Font size offset for the generation log — adjusted by +/- hotkeys.
    // 0 = default (12pt macOS, 12pt mini iOS, 14pt other iOS). Clamped to [-4, +8].
    @Published var statusLogFontOffset: Int = 0

    // MARK: - Compact window toggle + visualizer mode (macOS only)
    #if os(macOS)
    @Published var isWindowCompact: Bool = false
    @Published var macShowVisualizer: Bool = UserDefaults.standard.bool(forKey: "macShowVisualizer") {
        didSet { UserDefaults.standard.set(macShowVisualizer, forKey: "macShowVisualizer") }
    }
    @Published var macShowSongList: Bool = false
    var windowExpandedFrame: NSRect? = nil   // saved before compressing; not published (no UI depends on it)
    /// Set true during a programmatic animated resize so onChange(of: geo.size) doesn't
    /// call syncCompactStateFromWindow() mid-animation and flip isWindowCompact prematurely.
    var suppressWindowResizeSync: Bool = false

    func toggleWindowCompact() {
        guard let window = NSApp.keyWindow else { return }
        let currentFrame = window.frame
        // Use actual frame height to decide direction — avoids stale isWindowCompact state
        // that occurs when the user manually drags the window to minimum height.
        let compactContent   = NSSize(width: 650, height: kCompactContentHeight)
        let compactFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: compactContent)).size
        let compactFrameH    = compactFrameSize.height
        // Never go below AppKit's enforced minimum (user-drag floor).
        // Use whichever is larger so compact never drops the scrollbar.
        let collapseTargetH    = max(compactFrameH, window.minSize.height)
        let isCurrentlyCompact = currentFrame.height <= collapseTargetH + 4  // 4pt tolerance for rounding
        if isCurrentlyCompact {
            // Restore to saved frame, or fall back to default expanded size
            let targetFrame: NSRect
            if let saved = windowExpandedFrame, saved.height > collapseTargetH + 4 {
                targetFrame = saved
            } else {
                let defaultContent = NSSize(width: 1175, height: 775)
                let newWinSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: defaultContent)).size
                let newOrigin  = NSPoint(x: currentFrame.origin.x,
                                         y: currentFrame.origin.y + currentFrame.height - newWinSize.height)
                targetFrame = NSRect(origin: newOrigin, size: newWinSize)
            }
            suppressWindowResizeSync = true
            window.setFrame(targetFrame, display: true, animate: true)
            isWindowCompact = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.suppressWindowResizeSync = false }
        } else {
            // Save current frame, then collapse to minimum size keeping top-left pinned
            windowExpandedFrame = currentFrame
            let newWinSize = CGSize(width: compactFrameSize.width,
                                    height: collapseTargetH)
            let newOrigin  = NSPoint(x: currentFrame.origin.x,
                                     y: currentFrame.origin.y + currentFrame.height - newWinSize.height)
            suppressWindowResizeSync = true
            window.setFrame(NSRect(origin: newOrigin, size: newWinSize), display: true, animate: true)
            isWindowCompact = true
            macShowSongList = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.suppressWindowResizeSync = false }
        }
    }

    /// Called on launch to sync isWindowCompact with the actual window size.
    /// macOS persists window frame via NSUserDefaults even when isRestorable = false,
    /// so we must check the real size rather than assuming the default.
    func syncCompactStateFromWindow() {
        guard let window = NSApp.keyWindow else { return }
        let compactContent = NSSize(width: 650, height: kCompactContentHeight)
        let compactFrameH  = window.frameRect(forContentRect: NSRect(origin: .zero, size: compactContent)).size.height
        isWindowCompact = window.frame.height <= compactFrameH + 4
    }
    #endif

    // MARK: - Visible window — zoom + DAW scroll

    @Published var visibleBars: Int = 16
    @Published var visibleBarOffset: Int = 0

    // MARK: - Style selector

    @Published var selectedStyle: MusicStyle = {
        guard let raw = UserDefaults.standard.string(forKey: "selectedStyle"),
              let style = MusicStyle(rawValue: raw) else { return .chill }
        return style
    }() {
        didSet { UserDefaults.standard.set(selectedStyle.rawValue, forKey: "selectedStyle") }
    }

    // MARK: - Play mode (Song / Endless)

    @Published var playMode: PlayMode = {
        guard let raw = UserDefaults.standard.string(forKey: "playMode"),
              let mode = PlayMode(rawValue: raw) else { return .song }
        return mode
    }() {
        didSet {
            UserDefaults.standard.set(playMode.rawValue, forKey: "playMode")
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

    // MARK: - Sleep timer

    @Published var sleepTimerDuration: SleepTimerDuration = {
        guard let raw = UserDefaults.standard.string(forKey: "sleepTimerDuration"),
              let d = SleepTimerDuration(rawValue: raw) else { return .twoHours }
        return d
    }() {
        didSet { UserDefaults.standard.set(sleepTimerDuration.rawValue, forKey: "sleepTimerDuration") }
    }

    private(set) var sleepTimerExpiresAt: Date? = nil
    private var sleepTimerFire: Timer? = nil

    var sleepTimerIsActive: Bool { sleepTimerExpiresAt != nil }

    @Published var sleepTimerEndedVisible: Bool = false

    func setSleepTimer(_ duration: SleepTimerDuration) {
        sleepTimerFire?.invalidate()
        sleepTimerFire = nil
        sleepTimerDuration = duration
        sleepTimerExpiresAt = nil
        guard let mins = duration.minutes else { return }
        let expiresAt = Date().addingTimeInterval(mins * 60)
        sleepTimerExpiresAt = expiresAt
        sleepTimerFire = Timer.scheduledTimer(withTimeInterval: mins * 60, repeats: false) { [weak self] _ in
            self?.executeSleepTimerStop()
        }
    }

    private func executeSleepTimerStop() {
        sleepTimerExpiresAt = nil
        sleepTimerFire = nil
        logSleepTimerStop()
        playback.fadeOutAndStop(duration: 5)
    }

    // Re-arms the timer after the user presses Play following a sleep stop.
    // Guard ensures it only fires when the timer has expired (expiresAt is nil)
    // and a duration is actually selected — never resets a running timer.
    private func rearmSleepTimerIfNeeded() {
        guard sleepTimerDuration != .never, sleepTimerExpiresAt == nil else { return }
        setSleepTimer(sleepTimerDuration)
    }

    private func logSleepTimerStop() {
        appendToLog([GenerationLogEntry(
            tag: "Sleep",
            description: "Playback paused after \(sleepTimerDuration.rawValue)",
            isTitle: false
        )])
        withAnimation(.easeIn(duration: 0.3)) { sleepTimerEndedVisible = true }
    }

    private func clearSleepTimerMessage() {
        guard sleepTimerEndedVisible else { return }
        withAnimation(.easeOut(duration: 0.4)) { sleepTimerEndedVisible = false }
    }

    // MARK: - Persisted song history (survives app restarts — stored in UserDefaults)

    /// Minimal record needed to reproduce a song exactly. Codable so it can be
    /// JSON-encoded into UserDefaults. Newest entry last, max 50 entries.
    struct PersistedSong: Codable, Identifiable {
        var id: UInt64 { seed }
        let seed:           UInt64
        let style:          MusicStyle
        let title:          String
        let forcedRules:    [String: String]
        let keyOverride:    String?
        let tempoOverride:  Int?
        let moodOverride:   Mood?
        // [Int: UInt64] → [String: UInt64]: JSON requires String keys in dictionaries.
        let trackOverrides: [String: UInt64]
        // Instrument pool indices per track. Optional so old persisted data decodes as nil.
        let instrumentOverrides: [String: Int]?
        // Substyle display name (e.g. "Ambient Piano", "Chill Blues"). Optional so old persisted data decodes as nil.
        var substyleName: String?

        /// Always returns a non-empty display string. Uses the persisted substyleName for new songs;
        /// infers from forced rule IDs for songs saved before build 125 (when substyleName was added).
        var displaySubstyleName: String {
            if let name = substyleName { return name }
            let vals = Set(forcedRules.values)
            if forcedRules.values.contains(where: { $0.hasPrefix("AMB-PNO-") })   { return "Ambient Piano" }
            if forcedRules.values.contains(where: { $0.hasPrefix("CHL-BLUES-") }) { return "Chill Blues" }
            if !vals.isDisjoint(with: ["MOT-DRUM-005","MOT-DRUM-006","MOT-DRUM-007","MOT-DRUM-008",
                                       "MOT-BASS-016","MOT-BASS-017","MOT-BASS-018","MOT-BASS-019","MOT-BASS-020","MOT-BASS-021"]) {
                return "Motorik Noir"
            }
            if !vals.isDisjoint(with: ["KOS-DRUM-007","KOS-DRUM-008",
                                       "KOS-BASS-014","KOS-BASS-015","KOS-BASS-016","KOS-BASS-017"]) {
                return "Kosmic Drift"
            }
            return style.rawValue.capitalized
        }

        init(from state: SongState, instrumentOverrides: [Int: Int] = [:]) {
            seed                    = state.globalSeed
            style                   = state.style
            title                   = state.title
            forcedRules             = state.forcedRules
            keyOverride             = state.keyOverride
            tempoOverride           = state.tempoOverride
            moodOverride            = state.moodOverride
            trackOverrides          = Dictionary(uniqueKeysWithValues:
                state.trackOverrides.map { (String($0.key), $0.value) })
            self.instrumentOverrides = instrumentOverrides.isEmpty ? nil :
                Dictionary(uniqueKeysWithValues: instrumentOverrides.map { (String($0.key), $0.value) })
            substyleName            = state.displayStyleName
        }

        /// Decodes `instrumentOverrides` (String keys) back to `[Int: Int]`.
        var decodedInstrumentOverrides: [Int: Int] {
            guard let ovr = instrumentOverrides else { return [:] }
            return Dictionary(uniqueKeysWithValues: ovr.compactMap { k, v -> (Int, Int)? in
                guard let i = Int(k) else { return nil }; return (i, v) })
        }
    }

    /// Cross-session song list for the Songs tab. Newest last. Published so the UI updates.
    @Published var persistedHistory: [PersistedSong] = []

    private static let kPersistedHistoryKey = "persistedSongHistory_v1"
    private static let kPersistedHistoryMax = 10

    private static func loadPersistedHistory() -> [PersistedSong] {
        guard let data = UserDefaults.standard.data(forKey: kPersistedHistoryKey),
              let list = try? JSONDecoder().decode([PersistedSong].self, from: data)
        else { return [] }
        // Trim to current max in case the saved list predates a lower limit
        return list.count > kPersistedHistoryMax ? Array(list.suffix(kPersistedHistoryMax)) : list
    }

    private func savePersistedHistory() {
        guard let data = try? JSONEncoder().encode(persistedHistory) else { return }
        UserDefaults.standard.set(data, forKey: Self.kPersistedHistoryKey)
    }

    /// Appends a newly generated song to persistedHistory and saves to UserDefaults.
    /// No-op if this seed is already present (deduplicates reloads).
    private func appendPersistedSong(from state: SongState) {
        guard !persistedHistory.contains(where: { $0.seed == state.globalSeed }) else { return }
        persistedHistory.append(PersistedSong(from: state, instrumentOverrides: instrumentOverrides))
        if persistedHistory.count > Self.kPersistedHistoryMax { persistedHistory.removeFirst() }
        savePersistedHistory()
    }

    /// Called at startup: regenerates all persisted songs in the background and caches them as
    /// SongState objects in generationHistory. This makes navigation via ⏮/⏭ and song list taps
    /// instant (fast path in loadFromPersistedSong) without blocking the UI thread.
    private func preloadPersistedSongs() {
        let songs = persistedHistory
        guard !songs.isEmpty else { return }
        Task.detached(priority: .background) { [weak self, songs] in
            guard let self else { return }
            for song in songs {
                let trackOvr = Dictionary(uniqueKeysWithValues:
                    song.trackOverrides.compactMap { k, v -> (Int, UInt64)? in
                        guard let i = Int(k) else { return nil }; return (i, v) })
                var state = SongGenerator.generate(
                    seed:            song.seed,
                    keyOverride:     song.keyOverride,
                    tempoOverride:   song.tempoOverride,
                    moodOverride:    song.moodOverride,
                    style:           song.style,
                    forceBassRuleID: song.forcedRules["Bass"],
                    forceDrumRuleID: song.forcedRules["Drums"],
                    forceArpRuleID:  song.forcedRules["Rhythm"],
                    forcePadsRuleID: song.forcedRules["Pads"],
                    forceLeadRuleID: song.forcedRules["Lead"],
                    forceTexRuleID:  song.forcedRules["Tex"]
                )
                for idx in trackOvr.keys.sorted() {
                    state = SongGenerator.regenerateTrack(idx, songState: state, overrideSeed: trackOvr[idx])
                }
                var finalState = state
                finalState.title = song.title   // preserve the title from when the song was generated
                await MainActor.run {
                    guard !self.generationHistory.contains(where: { $0.globalSeed == finalState.globalSeed }) else { return }
                    self.generationHistory.append(finalState)
                    if self.generationHistory.count > Self.kPersistedHistoryMax {
                        self.generationHistory.removeFirst()
                    }
                    // Restore instrument overrides so ⏮ navigation gets the right instruments.
                    let ovr = song.decodedInstrumentOverrides
                    if !ovr.isEmpty {
                        self.sessionInstrumentOverrides[finalState.globalSeed] = ovr
                    }
                    // Backfill substyleName for songs saved before build 125.
                    if song.substyleName == nil,
                       let idx = self.persistedHistory.firstIndex(where: { $0.seed == song.seed }) {
                        self.persistedHistory[idx].substyleName = finalState.displayStyleName
                    }
                }
            }
            await MainActor.run { self.savePersistedHistory() }
        }
    }

    // Endless style continuum: fixed axis, movement ±1 only
    private let endlessStyleAxis: [MusicStyle] = [.ambient, .chill, .kosmic, .motorik]
    private var endlessStyleIndex: Int = 1    // start at Chill
    private var songsInCurrentStyle: Int = 0

    // Pre-generated next song for seamless Endless transitions
    private var nextSongState:            SongState? = nil
    private var isPreGenerating:          Bool       = false
    // Incremented by stop() so any 500ms-delayed finishLoadingSong from a just-ended song
    // is cancelled when the user explicitly stops, preventing texture/music from restarting.
    private var endlessTransitionToken:   Int        = 0
    // Incremented each time a new pre-gen is started; stale task completions that carry an old
    // token are discarded so they can't overwrite nextSongState with the wrong style.

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
    private var evolveInstrumentsChanged:  Bool        = false  // true if both evolve passes ran before song end
    private var lead2MirroredProgram: Int?               = nil    // non-nil = Lead 2 plays Lead 1's program
    // Incremented on each evolve phase switch so the scrollbar recreates itself even when
    // totalBars hasn't changed (e.g. preGeneratePassContent(pass: 2) already extended songState).
    @Published var evolvePhaseToken: Int = 0
    // Incremented by switchEvolveInstruments so TrackRowView refreshes the instrument name display.
    @Published var instrumentChangeToken: Int = 0

    // Incremented to signal TrackRowViews to reset instruments + effects to style defaults.
    // Fired on generateNew() and on the manual Reset button.
    @Published var defaultsResetToken: Int = 0
    @Published var lead2MirrorName: String? = nil   // non-nil = Lead 2 display name is overridden to match Lead 1

    /// Full clean-state reset — equivalent to a fresh app launch.
    /// Resets style, clears song, clears history, restores first-best-song behavior,
    /// resets all overrides, and re-enumerates the audio output device.
    func resetTrackDefaults() {
        // Stop playback and audio texture before tearing down state
        stop()
        audioTexture.stop()

        // Clear the current song and all history (including persisted song list)
        songState         = nil
        generationHistory = []
        persistedHistory  = []
        savePersistedHistory()
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

    // MARK: - Instrument randomization
    // After the first generation (all-defaults), each new song picks 2 random non-drums tracks
    // and assigns each a random non-default instrument from that track's pool.
    // instrumentOverrides maps trackIndex → instrumentIndex; TrackRowView reads this on defaultsResetToken.

    private var songGenerationCount = 0
    // Tracks which styles have had at least one song generated — used for best-song mode.
    private var stylesWithGeneratedSongs: Set<MusicStyle> = []
    var instrumentOverrides: [Int: Int] = [:]
    /// Saves the pads instrument override that was active before the most recent blues song,
    /// so it can be restored when returning to a regular Chill song.
    private var bluePadsSaved: Bool = false
    private var bluePadsRestoreValue: Int? = nil
    /// Snapshot of instrumentOverrides taken right after each song finishes generating or loading.
    /// resetEffectsToDefaults() restores from this so instruments return to their song-original state.
    private var songInstrumentOverrides: [Int: Int] = [:]
    /// Per-song instrument overrides keyed by globalSeed. Lets ⏮ navigation restore the
    /// exact instruments that were playing when the song was first generated this session.
    private var sessionInstrumentOverrides: [UInt64: [Int: Int]] = [:]
    /// Last pool index used per (track, style) for no-repeat instruments.
    /// Keyed by trackIndex → style → poolIndex. Nil entry = no previous song in that style.
    private var lastUsedInstrumentIndex: [Int: [MusicStyle: Int]] = [:]

    private static let randomizableTrackIndices = [kTrackLead1, kTrackLead2, kTrackPads, kTrackRhythm, kTrackTexture, kTrackBass, kTrackDrums]

    // Instruments that should not play in two consecutive songs.
    // If the SAME instrument was used in the previous song, a different one is chosen.
    // All instruments remain equally available — this only prevents back-to-back repeats.
    private static let noRepeatInstruments: [(track: Int, style: MusicStyle, poolIndex: Int)] = [
        (kTrackLead1,  .ambient, 1),  // Ocarina          patch 79
        (kTrackLead1,  .ambient, 1),  // Stereo Piano     patch 61001
        (kTrackLead2,  .kosmic,  2),  // Charang          patch 84
        (kTrackLead2,  .kosmic,  3),  // Vox Solo         patch 85
        (kTrackBass,   .kosmic,  2),  // Lead Bass        patch 87
        (kTrackRhythm, .kosmic,  2),  // Rock Organ       patch 18
        (kTrackLead1,  .motorik, 5),  // Square Lead      patch 80
        (kTrackBass,   .motorik, 1),  // Lead Bass        patch 87
        (kTrackBass,   .motorik, 2),  // Rock Bass        patch 34
        (kTrackLead2,  .motorik, 1),  // Brightness       patch 100
        (kTrackLead2,  .ambient, 0),  // Harp             patch 46
        (kTrackLead2,  .ambient, 1),  // Acoustic Guitar  patch 24
        (kTrackBass,   .ambient, 2),  // Voice Oohs       patch 54
        (kTrackBass,   .ambient, 3),  // FM Synth         patch 62
        (kTrackTexture, .motorik, 0), // Fifths Lead      patch 86
        (kTrackTexture, .motorik, 6), // Interference     patch 11127
        (kTrackTexture, .kosmic,  3), // FX Echoes        patch 102  (index shifted: FX Atmosphere removed)
        (kTrackRhythm,  .kosmic,  6), // Synth Chime      patch 11098 (index shifted: Crystal Bells removed)
    ]

    private static let trackDisplayName: [Int: String] = [
        kTrackLead1: "Lead 1", kTrackLead2: "Lead 2", kTrackPads: "Pads",
        kTrackRhythm: "Rhythm", kTrackTexture: "Texture", kTrackBass: "Bass", kTrackDrums: "Drums"
    ]

    nonisolated static func instrumentPoolNames(trackIndex: Int, style: MusicStyle, isKosmicDrift: Bool = false) -> [String] {
        // Full Kosmic pool is always shown to the user (Regular + Drift-exclusive instruments combined).
        // instrumentPickPool() restricts random generation to the appropriate substyle subset.
        switch (trackIndex, style) {
        case (kTrackLead1,   .chill):   return ["Muted Trumpet","Tenor Sax","Alto Sax","Trumpet","Clarinet"]
        case (kTrackLead1,   .ambient): return ["Stereo Piano","Flute","Ocarina","Whistle","Brightness","Calliope Lead","Harp","Shakuhachi"]
        case (kTrackLead1,   .kosmic):  return ["Flute","Brightness","Oboe","Recorder","Warm Pad","Sine Wave","Bottle Blow","Shenai"]
        case (kTrackLead1,   .motorik): return ["Mono Synth","Saw Lead 3","Soft Brass","Polysynth","Chiff Lead","Square Lead","Synth Lead","Saw Stack"]
        case (kTrackLead1,   _):        return ["Mono Synth","Soft Brass","Pad 3 Poly","Chiff Lead"]
        case (kTrackLead2,   .chill):   return ["Vibraphone","Flute","Soprano Sax","Trombone","Xylophone"]
        case (kTrackLead2,   .ambient): return ["Harp","Acoustic Guitar","FX Crystal","Space Voice","FX Atmosphere"]
        case (kTrackLead2,   .kosmic):  return ["Brightness","Bassoon","Charang","Vox Solo","Crystal"]
        case (kTrackLead2,   .motorik): return ["Polysynth","Brightness","Moog","Elec Guitar"]
        case (kTrackLead2,   _):        return ["Polysynth","Brightness","Minimoog","Elec Guitar"]
        case (kTrackPads,    .chill):   return ["Warm Pad","Synth Strings","String Pad","Sweep Pad"]
        case (kTrackPads,    .ambient): return ["Sweep Pad","Synth Strings","Halo Pad","Soundtrack"]
        case (kTrackPads,    .kosmic):  return ["Sweep Pad","Synth Strings","Warm Pad","Space Voice","Halo Pad","Bowed Glass","Fantasia 2"]
        case (kTrackPads,    _):        return ["Halo Pad","Sweep Pad","Bowed Glass","Synth Strings"]
        case (kTrackRhythm,  .chill):    return ["Rhodes","Wurlitzer","B3 Organ","Perc Organ","Stereo Piano","Rock Organ","Tonewheel"]
        case (kTrackRhythm,  .ambient):  return ["Glockenspiel","Celesta","Crystal","Rain","Tinker Bell","Windchime","Church Bells","Kalimba"]
        case (kTrackRhythm,  .kosmic):   return ["Moog","Wurlitzer","Rock Organ","Harpsi Pad","New Age Pad","Synth Mallet","Synth Chime","Mystery Pad"]
        case (kTrackRhythm,  .motorik):  return ["Guitar Pulse","Crunch Guitar","Fuzz Guitar","Doctor Solo","Acoustic Bass","Pick Bass","Synth Bass 3","Charang"]
        case (kTrackRhythm,  _):         return ["Guitar Pulse","Moog Lead","Fuzz Guitar"]
        case (kTrackTexture, .chill):   return ["None","Another bar","Another pub","Bar sounds","City at night","Harbor","Vinyl crackle"]
        case (kTrackTexture, .ambient): return ["Strings","Bowed Glass","Choir Aahs","FX Atmosphere","Pad 3 Poly"]
        case (kTrackTexture, .kosmic):  return ["Pad 3 Poly","Fifths Lead","Solar Wind","FX Echoes","Rain"]
        case (kTrackTexture, .motorik): return ["Fifths Lead","Halo Pad","Warm Pad","FX Atmosphere","FX Echoes",
                                                "Solar Wind","Interference","Guitar Fdbk"]
        case (kTrackTexture, _):        return ["Fifths Lead","Halo Pad","Warm Pad","FX Atmosphere","FX Echoes"]
        case (kTrackBass,    .chill):   return ["Fretless Bass","Acoustic Bass","Elec Bass"]
        case (kTrackBass,    .ambient): return ["Cello","French Horn","Voice Oohs","FM Synth","Metallic Pad"]
        case (kTrackBass,    .kosmic):  return ["Moog","Lead Bass","Mono Synth","Rock Bass","Synth Bass 3","Pulse Bass"]
        case (kTrackBass,    .motorik): return ["Moog","Lead Bass","Rock Bass","Elec Bass","Mean Saw Bass","Techno Bass"]
        case (kTrackBass,    _):        return ["Moog Bass","Lead Bass","Rock Bass","Elec Bass"]
        case (kTrackDrums,   .chill):   return ["Brush Kit","808 Kit","Jazz Drums"]
        case (kTrackDrums,   .ambient): return ["Percussion Kit", "Brush Kit"]
        case (kTrackDrums,   .kosmic):  return ["808 Kit","Machine Kit","Standard Kit","Brush Kit","Jazz Kit"]
        case (kTrackDrums,   .motorik): return ["Rock Kit","Brush Kit","Dance Drums","Machine Kit"]
        case (kTrackDrums,   _):        return ["Rock Kit","808 Kit","Brush Kit"]
        default:                        return []
        }
    }

    /// MIDI program numbers for each slot in instrumentPoolNames — same order, same count.
    /// Only covers the tracks that can be "fresh" in Evolve passes (Lead1, Lead2, Pads, Rhythm).
    nonisolated static func instrumentPoolPrograms(trackIndex: Int, style: MusicStyle, isKosmicDrift: Bool = false) -> [Int] {
        // All Kosmic programs are in the base .kosmic cases below (Regular + Drift-exclusive combined).
        switch (trackIndex, style) {
        case (kTrackLead1, .chill):    return [59, 66, 65, 56, 71]
        case (kTrackLead1, .ambient):  return [61001, 73, 79, 78, 100, 82, 46, 77]
        case (kTrackLead1, .kosmic):   return [73, 100, 68, 74, 89, 8080, 76, 111]  // + Warm Pad, Sine Wave, Bottle Blow, Shenai
        case (kTrackLead1, .motorik):  return [81, 13081, 62, 90, 83, 80, 87, 11100]
        case (kTrackLead1, _):         return [81, 62, 90, 83]
        case (kTrackLead2, .chill):    return [11, 73, 64, 57, 13]
        case (kTrackLead2, .ambient):  return [46, 24, 98, 91, 99]
        case (kTrackLead2, .kosmic):   return [100, 70, 84, 85, 98]
        case (kTrackLead2, .motorik):  return [90, 100, 39, 30]
        case (kTrackLead2, _):         return [90, 100, 39, 30]
        case (kTrackPads, .ambient):   return [95, 50, 94, 97]
        case (kTrackPads, .kosmic):    return [95, 50, 89, 91, 94, 92, 12088]
        case (kTrackPads, .chill):     return [89, 50, 48, 95]
        case (kTrackPads, _):          return [94, 95, 92, 50]
        case (kTrackRhythm, .ambient): return [9, 8, 98, 96, 112, 5124, 8014, 108]
        case (kTrackRhythm, .chill):   return [4, 5, 17, 16, 61001, 18, 8016]
        case (kTrackRhythm, .kosmic):  return [39, 5, 18, 11088, 88, 1098, 11098, 11096]  // + New Age Pad, Synth Mallet, Synth Chime, Mystery Pad
        case (kTrackRhythm, .motorik): return [28, 29, 30, 8081, 32, 34, 8038, 84]
        case (kTrackRhythm, _):        return [28, 39, 29]
        case (kTrackTexture, .chill):  return [240, 241, 251, 242, 243, 245, 250]
        case (kTrackTexture, .ambient):return [49, 92, 52, 99, 90]
        case (kTrackTexture, .kosmic): return [90, 86, 11089, 102, 96]  // + Rain
        case (kTrackTexture, .motorik): return [86, 94, 89, 99, 102, 11089, 11127, 8031]
        case (kTrackTexture, _):       return [86, 94, 89, 99, 102]
        case (kTrackBass, .chill):     return [35, 32, 33]
        case (kTrackBass, .ambient):   return [42, 60, 54, 62, 93]
        case (kTrackBass, .kosmic):    return [39, 87, 81, 34, 8038, 11039]
        case (kTrackBass, .motorik):   return [39, 87, 34, 33, 12038, 11038]
        case (kTrackBass, _):          return [39, 87, 34, 33]
        case (kTrackDrums, .chill):    return [40, 25, 32]
        case (kTrackDrums, .ambient):  return [0, 40]
        case (kTrackDrums, .kosmic):   return [25, 24, 0, 40, 32]  // + Brush Kit, Jazz Kit
        case (kTrackDrums, .motorik):  return [8, 40, 26, 24]
        case (kTrackDrums, _):         return [8, 25, 40]
        default: return []
        }
    }

    /// CC7 channel-volume override per pool slot (0 = use default 100).
    /// Entries that differ from 100 are listed explicitly; all others return 100.
    nonisolated static func instrumentPoolVolumeCC7(trackIndex: Int, style: MusicStyle, isKosmicDrift: Bool = false) -> [Int] {
        let names = instrumentPoolNames(trackIndex: trackIndex, style: style, isKosmicDrift: isKosmicDrift)
        return names.map { name in
            switch (trackIndex, style, name) {
            // Square Lead (program 80) at default CC7 100 — PlaybackEngine vol 0.78 handles calibration
            case (kTrackLead1,   .motorik, "Saw Stack"):     return 127
            case (kTrackLead1,   .motorik, "Synth Lead"):    return 70
            case (kTrackLead1,   .motorik, "Mono Synth"):    return 85
            case (kTrackLead1,   .motorik, "Soft Brass"):    return 80
            case (kTrackRhythm,  .motorik, "Charang"):       return 70
            case (kTrackTexture, .motorik, "Interference"):  return 127
            case (kTrackBass,    .kosmic,  "Pulse Bass"):    return 115
            case (kTrackRhythm,  .chill,   "Tonewheel"):    return 65
            default: return 100
            }
        }
    }

    /// Synchronously loads the correct instrument for every track into the playback engine.
    /// Must be called right before playback.play() at each song-load site.
    /// TrackRowView.onChange(of: defaultsResetToken) fires on the NEXT SwiftUI render cycle
    /// (deferred), so without this call the first notes play with stale/default programs.
    private func applyCurrentInstrumentsToPlayback() {
        // iOS: loadSoundBankInstrument() must be called while the engine is stopped —
        // calling it while running appears to succeed but produces silence. Stop once,
        // load all tracks (including kTrackLeadSynth=7, Kosmic's hidden doubling layer),
        // then restart. The dedup cache is invalidated first so every track reloads fresh.
        // macOS: setProgram() works while the engine is running — no stop/start needed.
        #if os(iOS)
        playback.invalidateProgramCache()
        let batchWasRunning = playback.beginBatchLoad()
        #endif

        let style = selectedStyle
        let isDrift = songState?.isKosmicDrift == true
        let trackNames = ["Lead 1", "Lead 2", "Pads", "Rhythm", "Texture", "Bass", "Drums"]
        var warnings: [GenerationLogEntry] = []
        for trackIndex in 0..<kTrackCount {
            let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: style, isKosmicDrift: isDrift)
            guard !programs.isEmpty else { continue }
            // Chill/Ambient audio texture tracks are handled by audioTexture.start() — skip MIDI load
            if trackIndex == kTrackTexture && style == .chill { continue }
            if trackIndex == kTrackTexture && style == .ambient && songState?.ambientAudioTexture != nil { continue }
            // Drums always use percussion bank — no meaningful "default MIDI" concept
            if trackIndex == kTrackDrums { continue }
            let idx = instrumentOverrides[trackIndex] ?? 0
            let poolProgram = programs[min(idx, programs.count - 1)]
            let program = (trackIndex == kTrackLead2 ? lead2MirroredProgram : nil) ?? poolProgram
            playback.setProgram(program, forTrack: trackIndex, immediate: true)
            let cc7Values = Self.instrumentPoolVolumeCC7(trackIndex: trackIndex, style: style, isKosmicDrift: isDrift)
            let cc7 = idx < cc7Values.count ? cc7Values[idx] : 100
            playback.setChannelVolume(cc7, forTrack: trackIndex)
            // Check that the load was confirmed (currentProgram updated only on success)
            let loaded = playback.loadedProgram(forTrack: trackIndex)
            if loaded != program {
                let name = trackIndex < trackNames.count ? trackNames[trackIndex] : "Track \(trackIndex)"
                let loadedStr = loaded == 255 ? "none" : "\(loaded)"
                warnings.append(GenerationLogEntry(
                    tag: "Error",
                    description: "\(name) instrument \(program) load failed (got \(loadedStr))",
                    isTitle: false))
            }
        }
        // Also load drums (excluded from mismatch check above)
        let drumPrograms = Self.instrumentPoolPrograms(trackIndex: kTrackDrums, style: style)
        if !drumPrograms.isEmpty {
            let drumIdx = instrumentOverrides[kTrackDrums] ?? 0
            playback.setProgram(drumPrograms[min(drumIdx, drumPrograms.count - 1)], forTrack: kTrackDrums, immediate: true)
        }

        #if os(iOS)
        // Restart the engine after all instruments are loaded.
        // endBatchLoad() → startEngine() → setActive(true) + engine.start().
        // Only called when beginBatchLoad() actually stopped the engine (song load / style
        // change paths). Route-change path: restartAudio() already stopped the engine before
        // calling this, so beginBatchLoad() returned false — restartAudio() handles the
        // engine restart itself after this callback returns.
        if batchWasRunning { playback.endBatchLoad() }
        #endif

        // Log the actual programs loaded so mismatches are immediately visible.
        // Format:  Instruments  L1:73  L2:11  Pd:95  Ry:4  Tx:49  Bs:35  Dr:40
        // Chill texture (240+) is an audio file, not a MIDI patch — shown as "audio".
        // kTrackCount=8 (includes kTrackLeadSynth=7, Kosmic-only silent doubling layer).
        let shortNames = ["L1", "L2", "Pd", "Ry", "Tx", "Bs", "Dr", "LS"]
        var parts: [String] = []
        for i in 0..<kTrackCount {
            let p = playback.loadedProgram(forTrack: i)
            if i == kTrackTexture && style == .chill { continue }   // audio texture omitted
            if let s = songState, SongLogExporter.isTrackSilent(i, song: s) { continue }
            if i == kTrackTexture && style == .ambient,
                      let texFile = songState?.ambientAudioTexture {
                let displayName = Self.ambientAudioDisplayName(texFile)
                parts.append("Tx:\(displayName)")
            } else if p != 255 {   // omit tracks that weren't loaded (e.g. LeadSynth in non-Kosmic)
                parts.append("\(shortNames[i]):\(p)")
            }
        }
        let instrumentsEntry = GenerationLogEntry(tag: "Instruments", description: parts.joined(separator: " "), isTitle: false)
        appendToLog([instrumentsEntry])
        // Also store in songState.generationLog so SongLogExporter writes it to .zudio files.
        songState?.generationLog.removeAll { $0.tag == "Instruments" }
        songState?.generationLog.append(instrumentsEntry)

        if !warnings.isEmpty { appendToLog(warnings) }

        // Re-assert cachedIsKosmicDrift after all instrument loading is complete.
        // iOS invalidateProgramCache() and other paths can reset it; this is the canonical
        // final write so the audio thread always sees the correct value for note velocity scaling.
        playback.updateKosmicDriftCache(songState?.isKosmicDrift == true)
    }

    // MARK: - Sheet triggers (set by key monitor, observed by TopBarView)
    @Published var triggerShowHelp  = false
    @Published var triggerShowAbout = false
    @Published var saveFlashCounter = 0   // incremented each save; TopBarView flashes Save button
    @Published var savedSongSeed: UInt64? = nil  // seed of last saved song; drives green checkmark

    // MARK: - Per-track UI state

    @Published var muteState: [Bool] = Array(repeating: false, count: kTrackCount)
    @Published var soloState: [Bool] = Array(repeating: false, count: kTrackCount)

    /// trackIndex → Date when a flash was triggered (dry/wet toggle, instrument regen).
    /// VisualizerView reads this each frame via TimelineView — does NOT need @Published.
    /// Keeping it plain avoids broadcasting objectWillChange on every note action, which
    /// was causing SwiftUI to rebuild command menus and briefly re-inject Format/Window.
    var visualizerFlashEvents: [Int: Date] = [:]

    func triggerVisualizerFlash(trackIndex: Int) {
        visualizerFlashEvents[trackIndex] = Date()
        // Auto-remove after 0.6 s so the dictionary stays clean
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            if let d = visualizerFlashEvents[trackIndex], Date().timeIntervalSince(d) >= 0.55 {
                visualizerFlashEvents.removeValue(forKey: trackIndex)
            }
        }
    }

    /// Tap-point flash: a white ring drawn at the raw tap/click position. Not @Published —
    /// canvas reads it each frame via TimelineView, same as visualizerFlashEvents.
    var orbTapFlashes: [(pos: CGPoint, date: Date, duration: Double, maxRadius: Double, maxOpacity: Double)] = []

    func recordOrbTap(at pos: CGPoint) {
        let duration   = Double.random(in: 0.20...0.40)
        let maxRadius  = Double.random(in: 30...70)
        let maxOpacity = Double.random(in: 0.25...0.60)
        orbTapFlashes.append((pos: pos, date: Date(), duration: duration, maxRadius: maxRadius, maxOpacity: maxOpacity))
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) { [weak self] in
            let cutoff = Date().addingTimeInterval(-(duration + 0.03))
            self?.orbTapFlashes.removeAll { $0.date < cutoff }
        }
    }

    // MARK: - Live playback feed (Now Playing strip)

    @Published var livePlaybackFeed: [GenerationLogEntry] = []
    private var lastEmittedStep: Int = -1

    // MARK: - Playback engine

    let playback = PlaybackEngine()
    let audioTexture = AudioTexturePlayer()
    let nowPlaying = NowPlayingController()

    private var cancellables = Set<AnyCancellable>()
    var platformHost: ZudioPlatformHost?

    init() {
        persistedHistory = Self.loadPersistedHistory()
        // Pre-populate from persisted history so "first best" rules only fire on a true clean
        // slate (new install or after reset). A returning user with any saved songs skips them.
        stylesWithGeneratedSongs = Set(persistedHistory.map { $0.style })
        preloadPersistedSongs()
        // Arm sleep timer from launch using saved preference (default 2 hours).
        // Set directly to avoid triggering sleepTimerDuration.didSet (no UserDefaults write at init).
        if let mins = sleepTimerDuration.minutes {
            let expiresAt = Date().addingTimeInterval(mins * 60)
            sleepTimerExpiresAt = expiresAt
            sleepTimerFire = Timer.scheduledTimer(withTimeInterval: mins * 60, repeats: false) { [weak self] _ in
                self?.executeSleepTimerStop()
            }
        }

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

        // Update elapsed time on each bar change so the lock screen seek bar tracks
        // scrubbing, and so the play/pause button re-syncs after Next Track transitions.
        playback.$currentBar
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.nowPlaying.update(song: self.songState, isPlaying: self.playback.isPlaying,
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

        // Create the platform host and wire up keyboard shortcuts + audio session.
        #if os(macOS)
        let host = MacPlatformHost()
        platformHost = host
        host.configureAudioSession()
        host.registerKeyboardShortcuts(target: self)
        #elseif os(iOS)
        let host = IOSPlatformHost()
        platformHost = host
        host.configureAudioSession()
        host.registerKeyboardShortcuts(target: self)

        // When the app backgrounds while stopped, deactivate AVAudioSession so iOS
        // removes the active-audio inference that causes the lock screen to show ⏸/■.
        // Both engines must be paused first (setActive(false) fails if any engine is running).
        // On resume, play() reactivates the session and restarts the engines as needed.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.playback.isPlaying else { return }
            self.audioTexture.pauseEngine()
            self.playback.pauseEngine()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif

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
        // stepPublisher replaces $currentStep — same per-step delivery without the
        // objectWillChange broadcast that @Published would trigger (8×/sec at 120 BPM).
        playback.stepPublisher
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
                    self.upNextLogged = true
                    _ = next
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
            case .song:    self.audioTexture.stop()
            }
        }
        // Re-apply instruments when the audio engine restarts after a route change.
        // Route changes (e.g. plugging in car audio) can invalidate sampler soundbank buffers —
        // without this the playing song falls back to default GM patches until the next song load.
        playback.onAudioEngineRestarted = { [weak self] in
            guard let self else { return }
            self.applyCurrentInstrumentsToPlayback()
            self.appendToLog([GenerationLogEntry(
                tag: "Audio",
                description: "New device — reloading",
                isTitle: false)])
        }
        // Surface engine start failures to the generation log.
        playback.onEngineError = { [weak self] msg in
            guard let self else { return }
            self.appendToLog([GenerationLogEntry(tag: "ERROR", description: msg, isTitle: false)])
        }
        // Log missing SF2 patches so stripped presets are visible in the generation log.
        playback.onMissingPatch = { [weak self] trackIndex, program in
            guard let self else { return }
            let style    = self.songState?.style ?? .chill
            let programs = AppState.instrumentPoolPrograms(trackIndex: trackIndex, style: style)
            let names    = AppState.instrumentPoolNames(trackIndex: trackIndex, style: style)
            let name     = zip(programs, names).first { $0.0 == program }.map(\.1) ?? "p\(program)"
            self.appendToLog([GenerationLogEntry(tag: "Error",
                description: "Missing MIDI patch \(program) \(name)", isTitle: false)])
        }
        // iOS audio interruption (another app takes focus) or headphones pulled.
        // PlaybackEngine.stop() has already fired; stop audioTexture (Chill background loop) too.
        playback.onAudioInterrupted = { [weak self] in
            guard let self else { return }
            self.audioTexture.stop()
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

    /// Appends a blank separator (if the log isn't empty) followed by the generation log entries.
    /// Use this whenever a new song's Style/Form/Chords/rules block is written to the log.
    private func appendGenerationLog(_ entries: [GenerationLogEntry]) {
        guard !entries.isEmpty else { return }
        var batch: [GenerationLogEntry] = []
        if !statusLog.isEmpty {
            batch.append(GenerationLogEntry(tag: "", description: "", isTitle: false))
        }
        batch.append(contentsOf: entries)
        appendToLog(batch)
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
                        : "\(e.tag.trimmingCharacters(in: .whitespaces)) \(e.description)"
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

    /// In Song mode: steps back to the previous song using persistedHistory order.
    /// If no song is loaded, loads the most recent song from history.
    /// Beeps if already at the oldest entry or history is empty.
    func loadPreviousFromHistory() {
        guard playMode == .song else { return }
        guard let current = songState else {
            // No song loaded — load the most recent one from history without starting playback
            if let newest = persistedHistory.last {
                loadFromPersistedSong(newest, forcePlay: false)
            } else {
                platformHost?.playErrorSound()
            }
            return
        }
        if let idx = persistedHistory.firstIndex(where: { $0.seed == current.globalSeed }),
           idx > 0 {
            let prev = persistedHistory[idx - 1]
            appendToLog([GenerationLogEntry(tag: "Rewind",
                description: "\(prev.style.rawValue) - \(prev.title)", isTitle: true)])
            loadFromPersistedSong(prev, forcePlay: false)
            return
        }
        // Already at the oldest song — beep and stay at bar 0
        platformHost?.playErrorSound()
        seekTo(step: 0)
        visibleBarOffset = 0
    }

    /// In Song mode: advances to the next song using persistedHistory order.
    /// Generates a new song when already at the newest entry.
    func loadNextFromHistory() {
        guard playMode == .song else { return }
        guard let current = songState else { generateNew(thenPlay: true); return }
        if let idx = persistedHistory.firstIndex(where: { $0.seed == current.globalSeed }),
           idx + 1 < persistedHistory.count {
            let next = persistedHistory[idx + 1]
            appendToLog([GenerationLogEntry(tag: "Forward",
                description: "\(next.style.rawValue) - \(next.title)", isTitle: true)])
            loadFromPersistedSong(next, forcePlay: false)
            return
        }
        // Already at the newest song — generate a new one
        generateNew(thenPlay: true)
    }

    func generateNew(thenPlay: Bool = false) {
        clearSleepTimerMessage()
        guard !isGenerating else { return }
        isGenerating = true
        // In Endless mode use the rotation's current style, not selectedStyle.
        // selectedStyle stays fixed on whatever the user last picked; only the rotation axis moves.
        let style = (playMode == .endless) ? endlessStyleAxis[endlessStyleIndex] : selectedStyle
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
                forceBassRuleID:      useBest ? bestBass   : nil,
                forceDrumRuleID:      useBest ? bestDrum   : nil,
                forceArpRuleID:       useBest ? bestArp    : nil,
                forceLeadRuleID:      useBest ? bestLead   : nil,
                forceTexRuleID:       useBest ? bestTex    : nil,
                forcePercussionStyle: useBest ? bestPerc   : nil,
                forceBridge:          useBest ? bestBridge : false,
                useBrushKit:          useBrushKit
            )
            await MainActor.run {
                self.songState    = state
                self.generationHistory.append(state)
                if self.generationHistory.count > Self.kPersistedHistoryMax { self.generationHistory.removeFirst() }
                self.appendPersistedSong(from: state)
                self.isGenerating = false
                self.visibleBarOffset = 0
                self.lastEmittedStep  = -1
                // Endless: sync selectedStyle to the rotation style that was just played,
                // discard stale pre-gen, and let preGenerateNextSong advance the counter.
                if self.playMode == .endless {
                    self.selectedStyle   = style
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
                // Instrument randomization: first song per style uses all defaults (index 0).
                // Subsequent songs: pick 2 random tracks and assign each a new instrument drawn
                // uniformly from the full pool, skipping if it would repeat the current choice.
                // The overrides dict is updated (not replaced) so the other tracks keep their
                // current instruments — giving a feeling of gradual change song to song.
                // kTrackTexture for Chill is handled separately below.
                if isFirstForStyle {
                    self.instrumentOverrides = [:]
                } else {
                    self.randomizeTwoInstruments(style: style)
                }
                self.replaceOnceOnlyInstruments(style: style)
                self.sanitiseBluesInstruments(for: state)
                self.sanitiseNoirInstruments(for: state)
                self.sanitiseDriftInstruments(for: state)
                self.applyBluesPadsInstrument(for: state)
                // Chill: sync Lead 1 and Lead 2 overrides to generation-time instruments so log and
                // playback agree. chillLeadInstrument/chillLead2Instrument drive musical generation
                // (phrasing, register); instrumentOverrides drives the sampler patch — they must match.
                if style == .chill {
                    let l1Pool = Self.instrumentPoolPrograms(trackIndex: kTrackLead1, style: .chill)
                    if let idx = l1Pool.firstIndex(of: Int(state.chillLeadInstrument.gmProgram)) {
                        self.instrumentOverrides[kTrackLead1] = idx
                    }
                    let l2Pool = Self.instrumentPoolPrograms(trackIndex: kTrackLead2, style: .chill)
                    if let idx = l2Pool.firstIndex(of: Int(state.chillLead2Instrument.gmProgram)) {
                        self.instrumentOverrides[kTrackLead2] = idx
                    }
                    let prog = Self.chillTextureProgram(forFilename: state.chillAudioTexture)
                    self.instrumentOverrides[kTrackTexture] = Int(prog) - 240
                }
                // Ambient audio texture: set picker index to match the chosen file.
                if style == .ambient, let audioTex = state.ambientAudioTexture {
                    let prog = Self.ambientAudioProgram(forFilename: audioTex)
                    self.instrumentOverrides[kTrackTexture] = Int(prog) - 231
                }
                // Snapshot the final overrides — resetEffectsToDefaults() restores from here.
                self.songInstrumentOverrides = self.instrumentOverrides
                self.sessionInstrumentOverrides[state.globalSeed] = self.instrumentOverrides
                self.saveLastUsedInstruments(style: style)
                self.songGenerationCount += 1
                self.stylesWithGeneratedSongs.insert(style)

                self.appendGenerationLog(state.generationLog)
                self.applyAmbientPianoInstrument(for: state)
                self.restoreLead2Mirror()
                self.applyLead2Mirror(for: state)
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
                self.playback.setChillMode(self.selectedStyle == .chill, bluesVariation: state.chillBluesVariation)
                // Reset instruments + effects and apply them synchronously before play.
                // defaultsResetToken fires TrackRowView.onChange on the next render cycle
                // (deferred), so applyCurrentInstrumentsToPlayback() ensures the correct
                // programs are loaded before the first note fires.
                self.defaultsResetToken += 1
                self.applyCurrentInstrumentsToPlayback()
                if thenPlay || wasPlaying {
                    self.rearmSleepTimerIfNeeded()
                    self.playback.play()
                    // Start ambient audio texture directly (Chill is handled via setProgram/switchTexture).
                    if state.style == .ambient, let texFile = state.ambientAudioTexture {
                        self.audioTexture.start(style: .ambient, texture: texFile,
                                                offsetSeconds: state.ambientAudioTextureOffset)
                    }
                    self.incrementPlayCountAndRequestReviewIfNeeded()
                }
                // Resign first responder so BPM TextField doesn't hold focus
                self.platformHost?.dismissKeyboard()
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
        // In evolve mode the extended state has a minimal structure (sections: []) — generators
        // that call structure.section(atBar:) return nil for every body bar, producing empty arrays.
        //
        // Fix: use the anchor state (full structure) as the generation source, then stitch the
        // result back into the extended state:
        //   • steps  0 ..< bodyEndStep : replaced with anchor-generated events
        //   • steps  bodyEndStep ..    : existing pass events preserved as-is
        //
        // bodyEndStep is the step where pass content begins (= outroStartBar * 16), which is
        // the same split point used by buildExtendedState to splice anchor body + pass events.
        let sourceState: SongState
        let evolveBodyEndStep: Int?
        if playMode == .evolve, let anchor = evolveAnchorState {
            sourceState       = anchor
            evolveBodyEndStep = (anchor.structure.outroSection?.startBar ?? anchor.frame.totalBars) * 16
        } else {
            sourceState       = current
            evolveBodyEndStep = nil     // non-evolve: replace entire track as before
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let regen        = SongGenerator.regenerateTrack(trackIndex, songState: sourceState)
            let regenEntries = Array(regen.generationLog.dropFirst(sourceState.generationLog.count))
            // Stitch anchor body events + preserved pass events (evolve) or use all events (song/endless).
            let newEvents: [MIDIEvent]
            if let bodyEnd = evolveBodyEndStep {
                let anchorBody = regen.trackEvents[trackIndex].filter { $0.stepIndex <  bodyEnd }
                let passEvents = current.trackEvents[trackIndex].filter { $0.stepIndex >= bodyEnd }
                newEvents = (anchorBody + passEvents).sorted { $0.stepIndex < $1.stepIndex }
            } else {
                newEvents = regen.trackEvents[trackIndex]
            }
            var updated = current.replacingEvents(newEvents, forTrack: trackIndex, appendingLog: regenEntries)
            // For Ambient texture regen: carry the new audio texture choice (may differ from current).
            if trackIndex == kTrackTexture && current.style == .ambient {
                updated = updated.withAmbientAudioTexture(regen.ambientAudioTexture,
                                                          offset: regen.ambientAudioTextureOffset)
            }
            await MainActor.run {
                self.songState    = updated
                self.isGenerating = false
                self.playback.load(updated)  // always rebuild stepEventMap — regen while paused left stale events
                // Keep generationHistory in sync for SongState tracking
                if !self.generationHistory.isEmpty {
                    self.generationHistory[self.generationHistory.count - 1] = updated
                }
                // Restart ambient audio texture if the regen changed it; sync picker index.
                if trackIndex == kTrackTexture && updated.style == .ambient {
                    self.audioTexture.start(style: .ambient, texture: updated.ambientAudioTexture,
                                            offsetSeconds: updated.ambientAudioTextureOffset)
                    if let audioTex = updated.ambientAudioTexture {
                        let prog = Self.ambientAudioProgram(forFilename: audioTex)
                        self.instrumentOverrides[kTrackTexture] = Int(prog) - 231
                        // Audio texture: turn off Pan and Sweep in playback engine
                        self.playback.setEffect(.pan,   enabled: false, forTrack: kTrackTexture)
                        self.playback.setEffect(.sweep, enabled: false, forTrack: kTrackTexture)
                    } else {
                        self.instrumentOverrides[kTrackTexture] = nil
                    }
                    self.instrumentChangeToken += 1
                }
                // Append only the NEW regen entries to the flat status log (at the very bottom)
                self.appendToLog(regenEntries)
                // If a file-open arrived while we were regenerating, load it now.
                self.consumePendingLoad()
            }
        }
    }

    // MARK: - Transport

    func play() {
        clearSleepTimerMessage()
        rearmSleepTimerIfNeeded()
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
            let texFile   = selectedStyle == .ambient ? songState?.ambientAudioTexture : songState?.chillAudioTexture
            let texOffset = selectedStyle == .ambient ? (songState?.ambientAudioTextureOffset ?? 0) : (songState?.chillAudioTextureOffset ?? 0)
            audioTexture.start(style: selectedStyle, texture: texFile, offsetSeconds: texOffset)
        }
    }

    func stop() {
        clearSleepTimerMessage()
        endlessTransitionToken += 1
        playback.stop()
        audioTexture.stop()
    }

    // MARK: - App Store review

    private func incrementPlayCountAndRequestReviewIfNeeded() {
        let key = "completedGeneratePlayCount"
        let count = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(count, forKey: key)
        guard count == 5 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            #if os(iOS)
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            SKStoreReviewController.requestReview(in: scene)
            #elseif os(macOS)
            SKStoreReviewController.requestReview()
            #endif
        }
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

    /// Rewind to bar 0. Within the first 3 bars: load the previous song instead (all modes).
    func seekToStart() {
        if playback.currentBar < 3 {
            if playMode == .song {
                loadPreviousFromHistory()
            } else {
                // Endless / Evolve: walk back through in-memory generation history
                guard let current = songState,
                      let idx = generationHistory.firstIndex(where: { $0.globalSeed == current.globalSeed }),
                      idx > 0 else {
                    seekTo(step: 0)
                    visibleBarOffset = 0
                    return
                }
                let prev = generationHistory[idx - 1]
                appendToLog([GenerationLogEntry(tag: "Rewind",
                    description: "\(prev.style.rawValue) - \(prev.title)", isTitle: true)])
                loadFromGenerationHistory(prev)
            }
        } else {
            seekTo(step: 0)
            visibleBarOffset = 0
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
            // 65% outward (toward nearest endpoint), 35% inward — raises Ambient/Motorik
            // steady-state share from ~17% toward ~20% without starving the middle styles.
            let outward = endlessStyleIndex < endlessStyleAxis.count / 2 ? -1 : 1
            step = Double.random(in: 0..<1) < 0.65 ? outward : -outward
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
            let state = SongGenerator.generate(style: nextStyle)
            await MainActor.run {
                guard self.playMode == .endless else { return }
                self.nextSongState   = state
                self.isPreGenerating = false
                if self.shouldLogNextUpWhenReady {
                    self.shouldLogNextUpWhenReady = false
                    self.upNextLogged = true
                }
            }
        }
    }

    private nonisolated static func buildAmbientModalShiftPass(
        anchor: SongState, mode: Mode, passBars: Int
    ) -> SongState {
        let shiftedFrame  = anchor.frame.withMode(mode).withTotalBars(passBars)
        var rng1 = SeededRNG(seed: UInt64.random(in: .min ... .max))
        var rng2 = SeededRNG(seed: UInt64.random(in: .min ... .max))

        // Build a single-window tonal map so pads can find chord tones at bar 0.
        let chordType = mode.isMajorFlavored ? ChordType.major : ChordType.minor
        let (chordTones, scaleTensions, avoidTones) = NotePoolBuilder.build(
            chordRootDegree: "1", chordType: chordType,
            key: anchor.frame.key, mode: mode)
        let window   = ChordWindow(startBar: 0, lengthBars: passBars,
                                   chordRoot: "1", chordType: chordType,
                                   chordTones: chordTones,
                                   scaleTensions: scaleTensions, avoidTones: avoidTones)
        let tonalMap: TonalGovernanceMap = [
            TonalGovernanceEntry(chordWindow: window, sectionLabel: .A, sectionMode: mode)
        ]

        var lead1Rules: Set<String> = []
        var padRules:   Set<String> = []
        let lead1Events = AmbientLeadGenerator.generateAmbientPianoLead(
            pianoRule: anchor.ambientPianoRule, frame: shiftedFrame, totalBars: passBars,
            rng: &rng1, usedRuleIDs: &lead1Rules, isEvolvePass: true)

        var events = Array(repeating: [MIDIEvent](), count: kTrackCount)
        events[kTrackLead1] = lead1Events
        if !anchor.trackEvents[kTrackPads].isEmpty {
            events[kTrackPads] = AmbientPadsGenerator.generateAmbientPianoPads(
                pianoRule: anchor.ambientPianoRule, frame: shiftedFrame, tonalMap: tonalMap,
                totalBars: passBars, rng: &rng2, usedRuleIDs: &padRules)
            events[kTrackLead1] = AmbientLeadGenerator.trimLeadAgainstPads(
                events[kTrackLead1], pads: events[kTrackPads], totalSteps: passBars * 16)
        }

        let minStruct = SongStructure(sections: [], chordPlan: [],
                                      introStyle: anchor.structure.introStyle,
                                      outroStyle: anchor.structure.outroStyle)
        return SongState(frame: shiftedFrame, structure: minStruct,
                         trackEvents: events, generationLog: [], stepAnnotations: [:],
                         copyingStyleFieldsFrom: anchor)
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

    /// Saves the current instrumentOverrides for no-repeat tracking.
    /// Call this after a song's instruments are fully determined so the NEXT song
    /// can avoid repeating any no-repeat instrument that was just heard.
    private func saveLastUsedInstruments(style: MusicStyle) {
        for entry in Self.noRepeatInstruments where entry.style == style {
            var dict = lastUsedInstrumentIndex[entry.track] ?? [:]
            dict[style] = instrumentOverrides[entry.track] ?? 0
            lastUsedInstrumentIndex[entry.track] = dict
        }
    }

    /// If the freshly-randomized song picked the same no-repeat instrument as the
    /// previous song, swap it for a different random pick. All instruments remain
    /// equally available — this only prevents two consecutive songs from sharing
    /// the same distinctive instrument.
    private func replaceOnceOnlyInstruments(style: MusicStyle) {
        let isDrift = songState?.isKosmicDrift == true
        var rng = SystemRandomNumberGenerator()
        for entry in Self.noRepeatInstruments where entry.style == style {
            let current = instrumentOverrides[entry.track] ?? 0
            guard current == entry.poolIndex else { continue }
            // Only swap if the previous song also used this instrument.
            guard lastUsedInstrumentIndex[entry.track]?[style] == entry.poolIndex else { continue }
            let pool = Self.instrumentPoolNames(trackIndex: entry.track, style: style, isKosmicDrift: isDrift)
            guard pool.count > 1 else { continue }
            var newIdx = current
            var attempts = 0
            repeat {
                newIdx = Int.random(in: 0..<pool.count, using: &rng)
                attempts += 1
            } while newIdx == current && attempts < 8
            instrumentOverrides[entry.track] = newIdx
        }
    }

    /// Ensures Motorik bass and Lead 1 instruments are appropriate for Noir vs regular.
    /// Fixes any stale override left over from the previous song when the Noir flag changed.
    private func sanitiseNoirInstruments(for state: SongState) {
        guard state.style == .motorik else { return }
        let isNoir = state.motorikNoirVariation
        var rng    = SystemRandomNumberGenerator()

        // Bass pool: [0=Moog, 1=Lead Bass, 2=Rock Bass, 3=Elec Bass, 4=Mean Saw Bass, 5=Techno Bass]
        let bassNoirOnly: Set<Int>    = [4, 5]
        let bassRegularOnly: Set<Int> = [2, 3]
        let currentBass = instrumentOverrides[kTrackBass] ?? 0
        if isNoir ? bassRegularOnly.contains(currentBass) : bassNoirOnly.contains(currentBass) {
            let valid = isNoir ? [0, 1, 4, 5] : [0, 1, 2, 3]
            instrumentOverrides[kTrackBass] = valid[Int.random(in: 0..<valid.count, using: &rng)]
        }

        // Lead 1 pool: [0=Mono Synth, 1=Saw Lead 3, 2=Soft Brass, 3=Polysynth, 4=Chiff Lead, 5=Square Lead, 6=Synth Lead, 7=Saw Stack]
        let ld1NoirOnly: Set<Int>    = [5, 7]
        let ld1RegularOnly: Set<Int> = [0, 2, 3]
        let currentLd1 = instrumentOverrides[kTrackLead1] ?? 0
        if isNoir ? ld1RegularOnly.contains(currentLd1) : ld1NoirOnly.contains(currentLd1) {
            let valid = isNoir ? [1, 4, 5, 6, 7] : [0, 1, 2, 3, 4, 6]
            instrumentOverrides[kTrackLead1] = valid[Int.random(in: 0..<valid.count, using: &rng)]
        }

        // Rhythm pool: [0=Guitar Pulse, 1=Crunch Guitar, 2=Fuzz Guitar, 3=Doctor Solo, 4=Acoustic Bass, 5=Pick Bass, 6=Synth Bass 3, 7=Charang]
        let rhtmNoirOnly: Set<Int>    = [3, 7]       // Doctor Solo + Charang are Noir-only
        let rhtmRegularOnly: Set<Int> = [0, 1, 4]    // Guitar Pulse + Crunch Guitar + Acoustic Bass are regular-only
        let currentRhtm = instrumentOverrides[kTrackRhythm] ?? 0
        if isNoir ? rhtmRegularOnly.contains(currentRhtm) : rhtmNoirOnly.contains(currentRhtm) {
            let valid = isNoir ? [2, 3, 5, 6, 7] : [0, 1, 2, 4, 5, 6]
            instrumentOverrides[kTrackRhythm] = valid[Int.random(in: 0..<valid.count, using: &rng)]
        }

        // Texture pool: [0=Fifths Lead, 1=Halo Pad, 2=Warm Pad, 3=FX Atmosphere, 4=FX Echoes,
        //                5=Solar Wind, 6=Interference, 7=Guitar Fdbk]
        let texNoirOnly: Set<Int>    = [0, 2, 6, 7]
        let texRegularOnly: Set<Int> = [1, 4]
        let currentTex = instrumentOverrides[kTrackTexture] ?? 0
        if isNoir ? texRegularOnly.contains(currentTex) : texNoirOnly.contains(currentTex) {
            let valid = isNoir ? [0, 2, 3, 5, 6, 7] : [1, 3, 4, 5]
            instrumentOverrides[kTrackTexture] = valid[Int.random(in: 0..<valid.count, using: &rng)]
        }

        // Drums pool: [0=Rock Kit, 1=Brush Kit, 2=Dance Drums, 3=Machine Kit]
        let currentDrums = instrumentOverrides[kTrackDrums] ?? 0
        if isNoir && currentDrums == 2 {
            // Dance Drums not available in Noir — swap to Rock Kit, Brush Kit, or Machine Kit
            let valid = [0, 1, 3]
            instrumentOverrides[kTrackDrums] = valid[Int.random(in: 0..<valid.count, using: &rng)]
        } else if !isNoir && currentDrums == 3 {
            // Machine Kit not available in Regular — swap to Rock Kit, Brush Kit, or Dance Drums
            instrumentOverrides[kTrackDrums] = Int.random(in: 0..<3, using: &rng)
        }
    }

    /// Forces Lead 1 to Stereo Piano (pool index 0) for Ambient Piano songs.
    /// Called after randomizeTwoInstruments so randomisation cannot overwrite it.
    /// User can still change it manually after the song loads.
    private func applyAmbientPianoInstrument(for state: SongState) {
        guard state.isAmbientPiano else { return }
        // Ambient Lead 1 pool: ["Stereo Piano","Flute","Ocarina","Whistle","Brightness","Calliope Lead","Harp","Shakuhachi"]
        // Stereo Piano is at index 0 (encoded program 61001).
        instrumentOverrides[kTrackLead1] = 0
    }

    // When Ambient Lead 1 uses a sparse/melodic rule, mirror Lead 2's program to match
    // Lead 1 so both leads share the same timbre.
    // Stored as a raw MIDI program number so it survives pool-index lookup differences.
    private func applyLead2Mirror(for state: SongState) {
        let mirrorRules: Set<String> = ["AMB-LEAD-001", "AMB-LEAD-002", "AMB-LEAD-007", "AMB-LEAD-008"]
        guard state.style == .ambient,
              state.generationLog.contains(where: { mirrorRules.contains($0.tag) })
        else { return }
        let lead1Idx      = instrumentOverrides[kTrackLead1] ?? 0
        let lead1Names    = Self.instrumentPoolNames(trackIndex: kTrackLead1, style: .ambient)
        let lead1Programs = Self.instrumentPoolPrograms(trackIndex: kTrackLead1, style: .ambient)
        guard !lead1Programs.isEmpty else { return }
        lead2MirroredProgram = lead1Programs[min(lead1Idx, lead1Programs.count - 1)]
        let name = lead1Idx < lead1Names.count ? lead1Names[lead1Idx] : "Lead 1"
        lead2MirrorName = name
        appendToLog([GenerationLogEntry(tag: "Instrument", description: "Lead 2 \(name) locked to L1", isTitle: false)])
    }

    private func restoreLead2Mirror() {
        lead2MirroredProgram = nil
        lead2MirrorName      = nil
    }

    private func randomizeTwoInstruments(style: MusicStyle) {
        let isDrift = songState?.isKosmicDrift == true
        var rng = SystemRandomNumberGenerator()
        // Chill: Lead 1 and Lead 2 are always driven by the song's generated chillLeadInstrument /
        // chillLead2Instrument (register, phrasing rules, and register separation all depend on them).
        // Exclude them from random variation — only Pads, Rhythm, Bass, Drums vary between songs.
        // Texture is excluded because the generator already picks the audio file.
        var eligible = Self.randomizableTrackIndices.filter {
            if style == .chill { return $0 != kTrackTexture && $0 != kTrackLead1 && $0 != kTrackLead2 }
            return true
        }
        var pickedCount = 0
        while pickedCount < 2, !eligible.isEmpty {
            let pos = eligible.indices.randomElement(using: &rng)!
            let trackIdx = eligible.remove(at: pos)
            let pool = Self.instrumentPoolNames(trackIndex: trackIdx, style: style, isKosmicDrift: isDrift)
            guard pool.count > 1 else { continue }
            let currentIdx = instrumentOverrides[trackIdx] ?? 0
            let weightedPool = instrumentPickPool(trackIndex: trackIdx, style: style, poolCount: pool.count)
            var newIdx = currentIdx
            var attempts = 0
            repeat {
                newIdx = weightedPool[Int.random(in: 0..<weightedPool.count, using: &rng)]
                attempts += 1
            } while newIdx == currentIdx && attempts < 3
            if newIdx != currentIdx {
                instrumentOverrides[trackIdx] = newIdx
                pickedCount += 1
            }
        }
    }

    // MARK: - Static instrument selection — callable from batch tests without AppState instance

    /// Full instrument selection pipeline: randomise two tracks, enforce no-repeat, sanitise per substyle.
    /// Identical logic to the instance methods; uses explicit inout state so batch tests can call it directly.
    /// `isFirstForStyle` resets overrides to defaults (index 0 = pool default) on the first song.
    /// `lastUsed` persists across songs for no-repeat enforcement — initialise to [:] at batch start.
    nonisolated static func selectInstrumentsForSong(
        state: SongState,
        isFirstForStyle: Bool,
        overrides: inout [Int: Int],
        lastUsed: inout [Int: [MusicStyle: Int]]
    ) {
        let style  = state.style
        let isDrift = state.isKosmicDrift
        var rng = SystemRandomNumberGenerator()

        if isFirstForStyle {
            overrides = [:]
        } else {
            // Randomise two instruments (same logic as randomizeTwoInstruments)
            var eligible = randomizableTrackIndices.filter {
                if style == .chill { return $0 != kTrackTexture && $0 != kTrackLead1 && $0 != kTrackLead2 }
                return true
            }
            var pickedCount = 0
            while pickedCount < 2, !eligible.isEmpty {
                let pos      = eligible.indices.randomElement(using: &rng)!
                let trackIdx = eligible.remove(at: pos)
                let pool     = instrumentPoolNames(trackIndex: trackIdx, style: style, isKosmicDrift: isDrift)
                guard pool.count > 1 else { continue }
                let currentIdx   = overrides[trackIdx] ?? 0
                let weightedPool = instrumentPickPoolStatic(trackIndex: trackIdx, style: style, poolCount: pool.count, state: state)
                var newIdx   = currentIdx; var attempts = 0
                repeat {
                    newIdx = weightedPool[Int.random(in: 0..<weightedPool.count, using: &rng)]
                    attempts += 1
                } while newIdx == currentIdx && attempts < 3
                if newIdx != currentIdx { overrides[trackIdx] = newIdx; pickedCount += 1 }
            }
        }

        // No-repeat enforcement (same logic as replaceOnceOnlyInstruments)
        for entry in noRepeatInstruments where entry.style == style {
            let current = overrides[entry.track] ?? 0
            guard current == entry.poolIndex else { continue }
            guard lastUsed[entry.track]?[style] == entry.poolIndex else { continue }
            let pool = instrumentPoolNames(trackIndex: entry.track, style: style, isKosmicDrift: isDrift)
            guard pool.count > 1 else { continue }
            var newIdx = current; var attempts = 0
            repeat { newIdx = Int.random(in: 0..<pool.count, using: &rng); attempts += 1 }
            while newIdx == current && attempts < 8
            overrides[entry.track] = newIdx
        }

        // Substyle sanitisation (same logic as sanitiseXxx methods)
        if style == .motorik, state.motorikNoirVariation {
            let bassNoirOnly: Set<Int> = [4, 5]; let bassRegOnly: Set<Int> = [2, 3]
            let cb = overrides[kTrackBass] ?? 0
            if bassRegOnly.contains(cb) { overrides[kTrackBass] = [0,1,4,5][Int.random(in:0..<4,using:&rng)] }
            let cl = overrides[kTrackLead1] ?? 0
            if [0,2,3].contains(cl)    { overrides[kTrackLead1] = [1,4,5,6,7][Int.random(in:0..<5,using:&rng)] }
            let cr = overrides[kTrackRhythm] ?? 0
            if [0,1,4].contains(cr)    { overrides[kTrackRhythm] = [2,3,5,6,7][Int.random(in:0..<5,using:&rng)] }
            let cd = overrides[kTrackDrums] ?? 0
            if cd == 2 { overrides[kTrackDrums] = [0,1,3][Int.random(in:0..<3,using:&rng)] }
            let _ = bassNoirOnly  // silence unused warning
        } else if style == .motorik {
            let cd = overrides[kTrackDrums] ?? 0
            if cd == 3 { overrides[kTrackDrums] = Int.random(in:0..<3, using:&rng) }
        }
        if style == .kosmic, state.isKosmicDrift {
            let cb = overrides[kTrackBass] ?? 0;   if cb == 0           { overrides[kTrackBass]    = [1,2,3,4][Int.random(in:0..<4,using:&rng)] }
            let cl = overrides[kTrackLead1] ?? 0;  if cl <= 3           { overrides[kTrackLead1]   = [4,5,6,7][Int.random(in:0..<4,using:&rng)] }
            let cr = overrides[kTrackRhythm] ?? 0; if (1...3).contains(cr) { overrides[kTrackRhythm] = [0,4,5,6,7][Int.random(in:0..<5,using:&rng)] }
            let cd = overrides[kTrackDrums] ?? 0;  if cd == 0 || cd == 1{ overrides[kTrackDrums]   = [2,3,4][Int.random(in:0..<3,using:&rng)] }
        }
        if style == .chill, state.chillBluesVariation {
            let pool2 = instrumentPoolNames(trackIndex: kTrackLead2, style: .chill)
            let vp2   = instrumentPickPoolStatic(trackIndex: kTrackLead2, style: .chill, poolCount: pool2.count, state: state)
            if let cur = overrides[kTrackLead2], !Set(vp2).contains(cur) {
                overrides[kTrackLead2] = vp2[Int.random(in:0..<vp2.count, using:&rng)]
            }
            overrides[kTrackPads] = Bool.random() ? 0 : 2   // Warm Pad or String Pad
        }

        // Save last-used for next song's no-repeat check
        for entry in noRepeatInstruments where entry.style == style {
            var dict = lastUsed[entry.track] ?? [:]
            dict[style] = overrides[entry.track] ?? 0
            lastUsed[entry.track] = dict
        }
    }

    /// Static backing for instrumentPickPool — takes explicit SongState instead of self.songState.
    nonisolated static func instrumentPickPoolStatic(trackIndex: Int, style: MusicStyle, poolCount: Int, state: SongState?) -> [Int] {
        if style == .motorik && trackIndex == kTrackBass {
            return state?.motorikNoirVariation == true ? [0,1,4,5] : [0,1,2,3]
        }
        if style == .motorik && trackIndex == kTrackLead1 {
            return state?.motorikNoirVariation == true ? [1,4,5,6,7] : [0,1,2,3,4,6]
        }
        if style == .motorik && trackIndex == kTrackDrums {
            return state?.motorikNoirVariation == true ? [0,1,3] : [0,1,2]
        }
        if style == .motorik && trackIndex == kTrackRhythm {
            return state?.motorikNoirVariation == true ? [2,3,5,6,7] : [0,1,2,4,5,6]
        }
        if style == .kosmic {
            let isDrift = state?.isKosmicDrift == true
            switch trackIndex {
            case kTrackLead1:   return isDrift ? [4,5,6,7]       : [0,1,2,3]
            case kTrackRhythm:  return isDrift ? [0,4,5,6,7]     : [0,1,2,3]
            case kTrackDrums:   return isDrift ? [2,3,4]         : [0,1,2]
            case kTrackTexture: return isDrift ? Array(0..<poolCount) : [0,1,2,3]
            case kTrackPads:    return isDrift ? [0,1,2,4,5]     : Array(0..<poolCount)
            case kTrackBass:    return isDrift ? [1,3,4]         : Array(0..<poolCount)
            default: break
            }
        }
        guard style == .chill else { return Array(0..<poolCount) }
        let isBlues = state?.chillBluesVariation == true
        switch trackIndex {
        case kTrackRhythm:
            return isBlues ? [2,2,2,2,3,3,3,3,3,3,4,4,4,4,5,5,5,5,5,5] : [0,0,0,1,1,1,2,2,4,4,6,6]
        case kTrackLead2:
            return isBlues ? [0,0,0,2,2,3,3,3] : [0,0,0,1,1,2,3,3,4]
        default:
            return Array(0..<poolCount)
        }
    }

    /// Weighted index pool for instrument randomisation — repeated entries increase probability.
    /// Chill kTrackRhythm: blues favours organs, regular favours Rhodes/Wurlitzer.
    /// Chill kTrackLead2:  blues excludes Flute; regular reduces Trombone and Soprano Sax.
    /// Motorik kTrackBass: Noir restricts to cold/synthetic sounds; regular restricts to organic sounds.
    private func instrumentPickPool(trackIndex: Int, style: MusicStyle, poolCount: Int) -> [Int] {
        if style == .motorik && trackIndex == kTrackBass {
            // Pool: [0=Moog, 1=Lead Bass, 2=Rock Bass, 3=Elec Bass, 4=Mean Saw Bass, 5=Techno Bass]
            return songState?.motorikNoirVariation == true
                ? [0, 1, 4, 5]   // Noir: Moog + Lead Bass (shared) + Mean Saw Bass + Techno Bass
                : [0, 1, 2, 3]   // Regular: Moog + Lead Bass (shared) + Rock Bass + Elec Bass
        }
        if style == .motorik && trackIndex == kTrackLead1 {
            // Pool: [0=Mono Synth, 1=Saw Lead 3, 2=Soft Brass, 3=Polysynth, 4=Chiff Lead, 5=Square Lead, 6=Synth Lead, 7=Saw Stack]
            // Must match sanitiseNoirInstruments's valid sets exactly to avoid immediate overrides.
            return songState?.motorikNoirVariation == true
                ? [1, 4, 5, 6, 7]      // Noir: Saw Lead 3 + Chiff Lead + Square Lead + Synth Lead + Saw Stack
                : [0, 1, 2, 3, 4, 6]   // Regular: Mono Synth + Saw Lead 3 + Soft Brass + Polysynth + Chiff Lead + Synth Lead
        }
        if style == .motorik && trackIndex == kTrackDrums {
            // Pool: [0=Rock Kit, 1=Brush Kit, 2=Dance Drums, 3=Machine Kit]
            return songState?.motorikNoirVariation == true
                ? [0, 1, 3]   // Noir: Rock Kit + Brush Kit + Machine Kit — no Dance Drums
                : [0, 1, 2]   // Regular: Rock Kit + Brush Kit + Dance Drums — no Machine Kit
        }
        if style == .motorik && trackIndex == kTrackRhythm {
            // Pool: [0=Guitar Pulse, 1=Crunch Guitar, 2=Fuzz Guitar, 3=Doctor Solo, 4=Acoustic Bass, 5=Pick Bass, 6=Synth Bass 3, 7=Charang]
            // Must match sanitiseNoirInstruments's valid sets exactly to avoid immediate overrides.
            return songState?.motorikNoirVariation == true
                ? [2, 3, 5, 6, 7]      // Noir: Fuzz Guitar + Doctor Solo + Pick Bass + Synth Bass 3 + Charang
                : [0, 1, 2, 4, 5, 6]   // Regular: Guitar Pulse + Crunch Guitar + Fuzz Guitar + Acoustic Bass + Pick Bass + Synth Bass 3
        }
        // Kosmic: unified pool (Regular + Drift-exclusive); substyle restricts random picks.
        if style == .kosmic {
            let isDrift = songState?.isKosmicDrift == true
            switch trackIndex {
            case kTrackLead1:
                // [0=Flute, 1=Brightness, 2=Oboe, 3=Recorder, 4=Warm Pad, 5=Sine Wave, 6=Bottle Blow, 7=Shenai]
                return isDrift ? [4, 5, 6, 7] : [0, 1, 2, 3]
            case kTrackRhythm:
                // [0=Moog, 1=Wurlitzer, 2=Rock Organ, 3=Harpsi Pad, 4=New Age Pad, 5=Synth Mallet, 6=Synth Chime, 7=Mystery Pad]
                return isDrift ? [0, 4, 5, 6, 7] : [0, 1, 2, 3]
            case kTrackDrums:
                // [0=808 Kit, 1=Machine Kit, 2=Standard Kit, 3=Brush Kit, 4=Jazz Kit]
                return isDrift ? [2, 3, 4] : [0, 1, 2]  // Drift: Standard/Brush/Jazz; Regular: 808/Machine/Standard
            case kTrackTexture:
                // [0=Pad 3 Poly, 1=Fifths Lead, 2=Solar Wind, 3=FX Echoes, 4=Rain]
                return isDrift ? Array(0..<poolCount) : [0, 1, 2, 3]  // Rain (4) Drift-only
            case kTrackPads:
                // [0=Sweep Pad, 1=Synth Strings, 2=Warm Pad, 3=Space Voice, 4=Halo Pad, 5=Bowed Glass, 6=Fantasia 2]
                return isDrift ? [0, 1, 2, 4, 5, 6] : Array(0..<poolCount)  // Space Voice (3) excluded from Drift random
            case kTrackBass:
                // [0=Moog, 1=Lead Bass, 2=Mono Synth, 3=Rock Bass, 4=Synth Bass 3]
                return isDrift ? [1, 3, 4] : Array(0..<poolCount)  // Moog+Mono Synth excluded from Drift random
            default: break
            }
        }
        guard style == .chill else { return Array(0..<poolCount) }
        let isBlues = songState?.chillBluesVariation == true
        switch trackIndex {
        case kTrackRhythm:
            // [0=Rhodes, 1=Wurlitzer, 2=B3, 3=PercOrg, 4=StereoPiano, 5=RockOrg(blues only)]
            return isBlues
                // Blues: B3 20%, PercOrg/RockOrg 30% each, StereoPiano 20%; no Rhodes/Wurlitzer
                ? [2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5]
                // Regular: Rhodes/Wurlitzer high, B3/StereoPiano medium, organs excluded
                : [0, 0, 0, 1, 1, 1, 2, 2, 4, 4]
        case kTrackLead2:
            // [0=Vibraphone, 1=Flute, 2=SopSax, 3=Trombone, 4=Xylophone]
            return isBlues
                // Blues: Flute and Xylophone excluded
                ? [0, 0, 0, 2, 2, 3, 3, 3]
                // Regular: Xylophone rare (~11%), Trombone/SopSax rare
                : [0, 0, 0, 1, 1, 2, 3, 3, 4]
        default:
            return Array(0..<poolCount)
        }
    }

    /// Ensures Kosmic Drift bass is never Moog (index 0) — Moog is Kosmic-regular only.
    /// Fixes stale overrides from prior regular-Kosmic songs where Moog was the default.
    private func sanitiseDriftInstruments(for state: SongState) {
        guard state.style == .kosmic, state.isKosmicDrift else { return }
        var rng = SystemRandomNumberGenerator()

        // Bass: [0=Moog, 1=Lead Bass, 2=Mono Synth, 3=Rock Bass, 4=Synth Bass 3] — Moog excluded from Drift random.
        let currentBass = instrumentOverrides[kTrackBass] ?? 0
        if currentBass == 0 {
            let valid = [1, 2, 3, 4]
            instrumentOverrides[kTrackBass] = valid[Int.random(in: 0..<valid.count, using: &rng)]
        }

        // Lead 1: [0=Flute, 1=Brightness, 2=Oboe, 3=Recorder, 4=Warm Pad, 5=Sine Wave, 6=Bottle Blow, 7=Shenai]
        // Regular-only instruments (0-3) must not appear in Drift — swap to Drift-appropriate.
        let currentLd1 = instrumentOverrides[kTrackLead1] ?? 0
        if currentLd1 <= 3 {
            let valid = [4, 5, 6, 7]
            instrumentOverrides[kTrackLead1] = valid[Int.random(in: 0..<valid.count, using: &rng)]
        }

        // Rhythm: [0=Moog, 1=Wurlitzer, 2=Rock Organ, 3=Harpsi Pad, 4=New Age Pad, 5=Synth Mallet, 6=Synth Chime, 7=Mystery Pad]
        // Regular-only: Wurlitzer/Rock Organ/Harpsi Pad (1-3) — Moog (0) is shared.
        let currentRhtm = instrumentOverrides[kTrackRhythm] ?? 0
        if (1...3).contains(currentRhtm) {
            let valid = [0, 4, 5, 6, 7]
            instrumentOverrides[kTrackRhythm] = valid[Int.random(in: 0..<valid.count, using: &rng)]
        }

        // Drums: [0=808 Kit, 1=Machine Kit, 2=Standard Kit, 3=Brush Kit, 4=Jazz Kit]
        // 808 Kit (0) and Machine Kit (1) are Regular-only — swap to Drift-appropriate.
        let currentDrums = instrumentOverrides[kTrackDrums] ?? 0
        if currentDrums == 0 || currentDrums == 1 {
            let valid = [2, 3, 4]
            instrumentOverrides[kTrackDrums] = valid[Int.random(in: 0..<valid.count, using: &rng)]
        }
    }

    /// After randomisation, enforce per-song instrument constraints.
    /// Chill blues: Lead 2 must not be Flute (index 1) or Xylophone (index 4).
    /// These instruments can be stale from a prior regular-Chill song when the randomly chosen
    /// 2 tracks didn't happen to include Lead 2 or Rhythm.
    private func sanitiseBluesInstruments(for state: SongState) {
        guard state.style == .chill, state.chillBluesVariation else { return }
        var rng = SystemRandomNumberGenerator()
        for trackIdx in [kTrackLead2, kTrackRhythm] {
            guard let current = instrumentOverrides[trackIdx] else { continue }
            let pool = Self.instrumentPoolNames(trackIndex: trackIdx, style: .chill)
            let validPool = instrumentPickPool(trackIndex: trackIdx, style: .chill, poolCount: pool.count)
            guard !Set(validPool).contains(current) else { continue }
            instrumentOverrides[trackIdx] = validPool[Int.random(in: 0..<validPool.count, using: &rng)]
        }
    }

    /// Sets pad instrument for blues songs (Warm Pad or String Pad, equally weighted) and
    /// restores the previous pads instrument when returning to a regular Chill song.
    private func applyBluesPadsInstrument(for state: SongState) {
        guard state.style == .chill else { return }
        if state.chillBluesVariation {
            if !bluePadsSaved {
                bluePadsSaved = true
                bluePadsRestoreValue = instrumentOverrides[kTrackPads]
            }
            // Warm Pad (0) or String Pad (2) — equally weighted, both suit the blues texture.
            instrumentOverrides[kTrackPads] = Bool.random() ? 0 : 2
        } else {
            if bluePadsSaved {
                instrumentOverrides[kTrackPads] = bluePadsRestoreValue
                bluePadsSaved = false
                bluePadsRestoreValue = nil
            }
        }
    }

    private func startEndlessSong(_ state: SongState) {
        selectedStyle                = state.style
        shouldLogNextUpWhenReady     = false   // reset — next pre-gen is silent until trigger fires
        upNextLogged                 = false
        nextSongState   = nil
        isPreGenerating = false
        preGenerateNextSong()   // silently pre-gen the song after next; starts during the gap
        // 500 ms silence between songs.
        // Capture token so if the user presses Stop during the gap, the transition is cancelled.
        let transitionToken = endlessTransitionToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.playMode == .endless,
                  self.endlessTransitionToken == transitionToken else { return }
            // Generation log first (Style, Form, Chords, rules), then finishLoadingSong
            // appends Instruments — matching the order the Generate button produces.
            self.appendGenerationLog(state.generationLog)
            self.randomizeTwoInstruments(style: state.style)
            self.replaceOnceOnlyInstruments(style: state.style)
            self.sanitiseBluesInstruments(for: state)
            self.sanitiseNoirInstruments(for: state)
            self.applyBluesPadsInstrument(for: state)
            self.applyAmbientPianoInstrument(for: state)
            self.restoreLead2Mirror()
            self.applyLead2Mirror(for: state)
            self.finishLoadingSong(state, thenPlay: true)
        }
    }

    private func generateAndStartNextSong() {
        appendToLog([GenerationLogEntry(tag: "Endless", description: "Loading next song...", isTitle: false)])
        let nextStyle = decideNextStyle()
        let transitionToken = endlessTransitionToken  // capture so a stop() during generation cancels this
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = SongGenerator.generate(style: nextStyle)
            await MainActor.run {
                guard self.endlessTransitionToken == transitionToken else { return }
                self.startEndlessSong(state)
            }
        }
    }

    /// If the user has navigated back through generation history, steps forward to the next
    /// entry and loads it without re-generating. Returns true when a history entry was loaded.
    @discardableResult
    private func stepForwardInGenerationHistory() -> Bool {
        guard let current = songState,
              let idx = generationHistory.firstIndex(where: { $0.globalSeed == current.globalSeed }),
              idx + 1 < generationHistory.count else { return false }
        let next = generationHistory[idx + 1]
        appendToLog([GenerationLogEntry(tag: "Forward",
            description: "\(next.style.rawValue) - \(next.title)", isTitle: true)])
        loadFromGenerationHistory(next, forcePlay: true)
        return true
    }

    /// Skip immediately to the next song (Endless mode ⏭ button).
    func skipToNextSong() {
        guard playMode == .endless else { return }
        if stepForwardInGenerationHistory() { return }
        // At the most recent song — use pre-generated or generate new.
        if let next = nextSongState {
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
        evolveInstrumentsChanged = false
        evolvePhaseToken        += 1   // ensure scrollbar recreates even if next song has same totalBars
    }

    /// Picks a different instrument for each fresh track and sends a program change immediately.
    private func switchEvolveInstruments(freshTracks: [Int]) {
        guard let anchor = evolveAnchorState else { return }
        let style = anchor.style
        let isDrift = songState?.isKosmicDrift == true
        var rng = SystemRandomNumberGenerator()
        var entries: [GenerationLogEntry] = []
        for trackIndex in freshTracks {
            let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: style, isKosmicDrift: isDrift)
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
            let tName = trackIndex < kTrackNames.count ? kTrackNames[trackIndex] : "Track \(trackIndex)"
            let names = Self.instrumentPoolNames(trackIndex: trackIndex, style: style, isKosmicDrift: isDrift)
            let iName = newIdx < names.count ? names[newIdx] : "prog \(programs[newIdx])"
            entries.append(GenerationLogEntry(tag: "Instrument", description: "\(tName) \(iName)", isTitle: false))
        }
        instrumentChangeToken += 1
        if !entries.isEmpty {
            appendToLog(entries)
            evolveInstrumentsChanged = true
        }
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
        if song.isAmbientPiano {
            evolvePass1Bars = 16
            evolvePass2Bars = 8
        } else {
            let aBars       = aSectionBars(of: song)
            evolvePass1Bars = min(40, max(32, aBars / 2))
            evolvePass2Bars = max(16, evolvePass1Bars / 2)
        }
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
            while attempts < 4 {
                let newRuleIDs = Set(newEntries.map(\.tag).filter(isRuleID))
                let eventsEmpty = anchorHadContent &&
                    !regen.trackEvents[idx].contains { $0.stepIndex >= bodyStartStep && $0.stepIndex < bodyStartStep + cutoff }
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

    // Returns indices from `candidates` that have no events in the anchor's body section.
    // Used to detect bass/drum tracks that are absent so evolve passes can add them.
    private func absentBodyTracks(_ anchor: SongState, candidates: [Int]) -> [Int] {
        let bodyStartStep  = (anchor.structure.introSection?.endBar  ?? 0) * 16
        let outroStartStep = (anchor.structure.outroSection?.startBar ?? anchor.frame.totalBars) * 16
        return candidates.filter { idx in
            !anchor.trackEvents[idx].contains {
                $0.stepIndex >= bodyStartStep && $0.stepIndex < outroStartStep
            }
        }
    }

    private func preGeneratePassContent(pass: Int) {
        guard let anchor = evolveAnchorState, !evolveIsPreGenerating else { return }
        var freshTracks: [Int]
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
        // Ambient piano: modal shift — same rule, different scale mode. No instrument swap.
        if anchor.isAmbientPiano {
            let targetMode = (pass == 1) ? anchor.frame.mode.complementaryMode : anchor.frame.mode
            evolveIsPreGenerating = true
            let tokenAtStart = evolvePhaseToken   // stale-Task guard — see note below
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let state = Self.buildAmbientModalShiftPass(anchor: anchor, mode: targetMode, passBars: passBars)
                await MainActor.run {
                    // If tearDownEvolve() fired since this Task was launched, evolvePhaseToken
                    // has been incremented and this result belongs to a now-abandoned session.
                    // Applying it would corrupt songState and cause Next-Track oscillation.
                    guard self.playMode == .evolve,
                          self.evolvePhaseToken == tokenAtStart else { return }
                    if pass == 1 { self.evolvePass1State = state } else { self.evolvePass2State = state }
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
                    }
                }
            }
            return
        }

        // If bass or drums are absent from the anchor body, add them to freshTracks so the
        // evolve pass introduces them. Both passes do this so bass/drums persist through pass 2.
        freshTracks += absentBodyTracks(anchor, candidates: [kTrackBass, kTrackDrums])
        evolveIsPreGenerating = true
        let tokenAtStart = evolvePhaseToken   // stale-Task guard
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = Self.buildPassState(anchor: anchor, freshTracks: freshTracks, passBars: passBars)
            await MainActor.run {
                // Stale-Task guard: if tearDownEvolve() was called since this Task launched,
                // the token has changed. Applying a stale result here would overwrite songState
                // with an extended state built from the old anchor — causing Next-Track to
                // oscillate between two history entries instead of generating a new song.
                guard self.playMode == .evolve,
                      self.evolvePhaseToken == tokenAtStart else { return }
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
                        description: "Evolving \(passBars) bars, new pads, rhythm",
                        isTitle: false)])
                }
            }
        }
    }

    private func preGenerateEvolveNextSong() {
        guard let anchor = evolveAnchorState, !evolveIsPreGenerating,
              evolveNextSongState == nil else { return }
        evolveIsPreGenerating = true
        let style        = selectedStyle   // use the currently selected style, not the anchor's
        let styleChanged = style != (anchor.style)
        // If style changed, generate fresh — no BPM, mood, key or scale from the previous song.
        let mood:  Mood? = styleChanged ? nil : evolveMoodAnchor
        let tempo: Int?  = styleChanged ? nil : evolveTempoAnchor
        let tokenAtStart = evolvePhaseToken   // stale-Task guard
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let newTempo: Int? = tempo.map { max(20, min(200, $0 + Int.random(in: -5...5))) }
            let state = SongGenerator.generate(tempoOverride: newTempo, moodOverride: mood,
                                               style: style)
            await MainActor.run {
                guard self.playMode == .evolve,
                      self.evolvePhaseToken == tokenAtStart else { return }
                self.evolveNextSongState   = state
                self.evolveIsPreGenerating = false
                if self.evolveNextSongShouldLog && !self.evolveNextSongLogged {
                    self.evolveNextSongShouldLog = false
                    self.evolveNextSongLogged    = true
                }
            }
        }
    }

    private func handleEvolveOutroStart() {
        guard evolvePhase == .original else { return }
        if let pass1 = evolvePass1State {
            doSwitchToEvolvePass1(pass1)
        } else {
            guard let anchor = evolveAnchorState else { return }
            let passBars     = evolvePass1Bars
            let absentTracks = absentBodyTracks(anchor, candidates: [kTrackBass, kTrackDrums])
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let state = Self.buildPassState(anchor: anchor,
                                                freshTracks: [kTrackLead1, kTrackLead2] + absentTracks,
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
        if anchor.isAmbientPiano {
            let comp   = anchor.frame.mode.complementaryMode
            let barTag = String(format: "Bar %03d", outroStartBar + 1)
            appendToLog([GenerationLogEntry(tag: barTag,
                description: "Shifting to \(anchor.frame.key) \(comp.rawValue) (\(evolvePass1Bars) bars)",
                isTitle: false)])
        } else {
            switchEvolveInstruments(freshTracks: [kTrackLead1, kTrackLead2])
            appendToLog(pass1.generationLog)
        }
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
        if anchor.isAmbientPiano {
            let barTag = String(format: "Bar %03d", pass2StartBar + 1)
            appendToLog([GenerationLogEntry(tag: barTag,
                description: "Back to \(anchor.frame.key) \(anchor.frame.mode.rawValue) (\(evolvePass2Bars) bars)",
                isTitle: false)])
        } else {
            switchEvolveInstruments(freshTracks: [kTrackPads, kTrackRhythm])
            appendToLog(pass2.generationLog)
        }
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
            if anchor.isAmbientPiano {
                appendToLog([GenerationLogEntry(tag: "Upcoming",
                    description: "\(evolvePass1Bars) bar modal shift",
                    isTitle: false)])
            } else {
                appendToLog([GenerationLogEntry(tag: "Upcoming",
                    description: "Evolving \(evolvePass1Bars) bars, new leads",
                    isTitle: false)])
            }
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
        // Discard pre-generated next song if its style no longer matches the user's selection.
        if let next = evolveNextSongState, next.style != selectedStyle {
            evolveNextSongState  = nil
            evolveIsPreGenerating = false
            evolveNextSongLogged  = false
        }
        // Capture token now so the 500 ms asyncAfter closure can detect if the user navigated
        // away (via history tap or Next-Track-into-history) before the silence gap expires.
        let tokenAtStart = evolvePhaseToken
        if let next = evolveNextSongState {
            evolveNextSongState = nil
            // 500 ms silence between songs
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.playMode == .evolve,
                      self.evolvePhaseToken == tokenAtStart else { return }
                self.finishLoadingEvolveSong(next)
            }
        } else {
            let style        = selectedStyle   // use currently selected style, not anchor's
            let styleChanged = style != (evolveAnchorState?.style ?? style)
            // If style changed, generate fresh — no BPM, mood, key or scale from the previous song.
            let mood:  Mood? = styleChanged ? nil : evolveMoodAnchor
            let tempo: Int?  = styleChanged ? nil : evolveTempoAnchor
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let newTempo: Int? = tempo.map { max(20, min(200, $0 + Int.random(in: -5...5))) }
                let state = SongGenerator.generate(tempoOverride: newTempo, moodOverride: mood,
                                                   style: style)
                await MainActor.run {
                    guard self.playMode == .evolve,
                          self.evolvePhaseToken == tokenAtStart else { return }
                    // 500 ms silence between songs
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self, self.playMode == .evolve,
                              self.evolvePhaseToken == tokenAtStart else { return }
                        self.finishLoadingEvolveSong(state)
                    }
                }
            }
        }
    }

    private func finishLoadingEvolveSong(_ state: SongState) {
        let alreadyEvolved = evolveInstrumentsChanged
        tearDownEvolve()           // resets evolveMoodAnchor and evolveInstrumentsChanged to false
        selectedStyle = state.style
        // Generation log first (Style, Form, Chords, rules), then finishLoadingSong
        // appends Instruments — matching the order the Generate button produces.
        appendGenerationLog(state.generationLog)
        if !alreadyEvolved { randomizeTwoInstruments(style: state.style) }
        replaceOnceOnlyInstruments(style: state.style)
        sanitiseBluesInstruments(for: state)
        sanitiseNoirInstruments(for: state)
        sanitiseDriftInstruments(for: state)
        applyBluesPadsInstrument(for: state)
        applyAmbientPianoInstrument(for: state)
        restoreLead2Mirror()
        applyLead2Mirror(for: state)
        finishLoadingSong(state, thenPlay: true)
        // Song 2 already matched song 1's mood (enforced at pre-gen time via evolveMoodAnchor).
        // From song 3 onward, lockMoodToSong: false so mood is picked freely each time.
        startEvolveMode(from: state, lockMoodToSong: false)
    }

    /// Skip to the next song immediately (Evolve mode ⏭ button).
    /// Uses pre-generated next song if available, otherwise generates one — same as Endless skipToNextSong.
    func skipEvolvePass() {
        guard playMode == .evolve else { return }
        if stepForwardInGenerationHistory() { return }
        transitionToEvolveNextSong()
    }

    /// Shared song-loading kernel for Endless transitions and ⏮ rewind.
    /// Stops current playback, loads `state`, and plays if `thenPlay` is true.
    private func finishLoadingSong(_ state: SongState, thenPlay: Bool) {
        saveLastUsedInstruments(style: state.style)
        sessionInstrumentOverrides[state.globalSeed] = instrumentOverrides
        playback.stop()
        audioTexture.stop()
        songState = state
        // Avoid duplicate entries (e.g. ⏮ reloads a song already in the list).
        // Duplicate globalSeeds break ForEach identity in the Songs tab UI.
        if !generationHistory.contains(where: { $0.globalSeed == state.globalSeed }) {
            generationHistory.append(state)
            if generationHistory.count > Self.kPersistedHistoryMax { generationHistory.removeFirst() }
            appendPersistedSong(from: state)
        }
        visibleBarOffset = 0
        lastEmittedStep  = -1
        muteState = Array(repeating: false, count: kTrackCount)
        soloState = Array(repeating: false, count: kTrackCount)
        playback.muteState = muteState
        playback.soloState = soloState
        playback.kosmicStyle  = state.style == .kosmic
        playback.motorikStyle = state.style == .motorik
        playback.chillFade    = false
        // load() must come before setAmbientMode/setChillMode so PlaybackEngine.songState
        // is current when those methods check state fields like chillBluesVariation.
        playback.load(state)
        playback.seek(toStep: 0)
        playback.setAmbientMode(state.style == .ambient)
        playback.setChillMode(state.style == .chill, bluesVariation: state.chillBluesVariation)
        defaultsResetToken += 1
        applyCurrentInstrumentsToPlayback()
        if thenPlay {
            playback.play()
            let texFile2   = state.style == .ambient ? state.ambientAudioTexture : state.chillAudioTexture
            let texOffset2 = state.style == .ambient ? state.ambientAudioTextureOffset : state.chillAudioTextureOffset
            audioTexture.start(style: state.style, texture: texFile2, offsetSeconds: texOffset2)
        }
        platformHost?.dismissKeyboard()
    }

    /// Step back one bar. Beeps when already at the very start (step 0).
    func seekBackOneBar() {
        if playback.currentStep == 0 {
            platformHost?.playErrorSound()
            return
        }
        let targetBar = max(0, playback.currentBar - 1)
        seekEdgeSensitive(toBar: targetBar)
    }

    /// Step back two bars. Clamps at bar 0.
    func seekBackTwoBars() {
        let targetBar = max(0, playback.currentBar - 2)
        seekEdgeSensitive(toBar: targetBar)
    }

    /// Step forward one bar. At the last bar: beep (Next Song button handles song generation).
    func seekForwardOneBar() {
        guard let song = songState else { return }
        if playback.currentBar >= song.frame.totalBars - 1 {
            platformHost?.playErrorSound()
            return
        }
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

    /// Writes the current song to a temp .zudio file and returns its URL for sharing.
    func buildShareURL() -> URL? {
        guard let song = songState else { return nil }
        return SongLogExporter.shareURL(for: song)
    }

#if os(macOS)
    func shareSongMac() {
        guard let url = buildShareURL() else { return }
        let picker = NSSharingServicePicker(items: [url, "Here's a cool song I created with Zudio."])
        let delegate = MacSharePickerDelegate()
        picker.delegate = delegate
        if let window = NSApp.keyWindow, let view = window.contentView {
            withExtendedLifetime(delegate) {
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            }
        }
    }
#endif

    func saveMIDI() {
        guard let song = songState else { return }
        saveFlashCounter += 1
        #if os(macOS)
        guard let zudioURL = AudioFileExporter.presentSaveSongPanel(songName: song.title) else { return }
        let midiURL = zudioURL.deletingPathExtension().appendingPathExtension("MID")
        do {
            try MIDIFileExporter.export(song, to: midiURL)
            try? SongLogExporter.export(song, midiURL: midiURL)
            lastSaveURL = zudioURL
            print("Song saved: \(zudioURL.path)")
            appendToLog([GenerationLogEntry(tag: "FILE", description: "Saved \(zudioURL.lastPathComponent)")])
            savedSongSeed = songState?.globalSeed
        } catch {
            print("MIDI export error: \(error)")
        }
        #else
        do {
            let url = try MIDIFileExporter.export(song)
            lastSaveURL = url
            print("MIDI saved: \(url.path)")
            try? SongLogExporter.export(song, midiURL: url)
            appendToLog([GenerationLogEntry(tag: "FILE", description: "Saved \(url.lastPathComponent)")])
            savedSongSeed = songState?.globalSeed
        } catch {
            print("MIDI export error: \(error)")
        }
        #endif
    }

    // MARK: - Load from log

    func loadFromLog() {
        platformHost?.showOpenPanel { [weak self] url in
            guard let url else { return }
            self?.loadFromLogURL(url)
        }
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
        var loadedKeyOverride:      String? = nil
        var loadedTempoOverride:    Int?    = nil
        var loadedMoodOverride:     Mood?   = nil
        var loadedInstrumentOverrides: [Int: Int] = [:]
        let instrumentShortNames = ["L1": 0, "L2": 1, "Pd": 2, "Ry": 3, "Tx": 4, "Bs": 5, "Dr": 6, "LS": 7]

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
            } else if trimmed.hasPrefix("Instruments") {
                // "Instruments      L1:73 L2:100 Pd:95 Ry:39 Tx:audio Bs:39 Dr:40 LS:90"
                // Map each program number back to its pool index so instruments are restored on load.
                let tokens = trimmed.dropFirst("Instruments".count)
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                for token in tokens {
                    let parts = token.components(separatedBy: ":")
                    guard parts.count == 2,
                          let trackIdx = instrumentShortNames[parts[0]],
                          let prog = Int(parts[1]) else { continue }
                    let pool = Self.instrumentPoolPrograms(trackIndex: trackIdx, style: style)
                    if let poolIdx = pool.firstIndex(of: prog) {
                        loadedInstrumentOverrides[trackIdx] = poolIdx
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
        let overrides         = trackOverrides
        let loadForced        = forcedRules
        let loadTitle         = songTitle
        let loadVersion       = zudioVersion
        let loadKey           = loadedKeyOverride
        let loadTempo         = loadedTempoOverride
        let loadMood          = loadedMoodOverride
        let loadedInstOverrides = loadedInstrumentOverrides
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
                self.savedSongSeed    = state.globalSeed  // loaded from file → mark as saved
                self.appendPersistedSong(from: state)
                self.generationHistory.append(state)
                if self.generationHistory.count > Self.kPersistedHistoryMax { self.generationHistory.removeFirst() }
                self.isGenerating     = false
                self.visibleBarOffset = 0
                self.lastEmittedStep  = -1
                self.instrumentOverrides = loadedInstOverrides
                // Chill/Ambient audio texture — restore picker index from song state.
                if style == .chill {
                    let prog = Self.chillTextureProgram(forFilename: state.chillAudioTexture)
                    self.instrumentOverrides[kTrackTexture] = Int(prog) - 240
                }
                if style == .ambient, let audioTex = state.ambientAudioTexture {
                    let prog = Self.ambientAudioProgram(forFilename: audioTex)
                    self.instrumentOverrides[kTrackTexture] = Int(prog) - 231
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
                batch.append(GenerationLogEntry(tag: "FILE", description: "Loading song:\(nameStr) --Zudio \(loadVersion)", isTitle: false))
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
                self.playback.setChillMode(style == .chill, bluesVariation: state.chillBluesVariation)
                self.defaultsResetToken += 1
                self.applyCurrentInstrumentsToPlayback()
                if wasPlaying { self.playback.play() }
                self.platformHost?.dismissKeyboard()
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

    @Published var isFastExporting:          Bool   = false
    @Published var exportingSeparateTracks:  Bool   = false
    @Published var isExportingAudio:         Bool   = false
    @Published var audioExportProgress:   Double = 0
    @Published var audioExportFilename:   String = ""
    @Published var showExportConfirmation: Bool  = false
    /// Set to a non-nil URL on iOS after fast export completes — views observe this to present a share sheet.
    @Published var fastExportedFileURL: URL? = nil
    /// Set on export failure so the UI can show an alert.
    @Published var fastExportErrorMessage: String? = nil
    /// True when a fast export is pending due to low disk space confirmation.
    @Published var showLowDiskSpaceAlert: Bool = false
    nonisolated(unsafe) private var pendingExportURL: URL? = nil

    /// Called from button/menu/keyboard — routes to fast export on all platforms.
    func requestExport() {
        requestFastExport()
    }

    /// On macOS: called directly from requestExport() — NSSavePanel provides file location and mode.
    /// On iOS: kept for reference but disabled; iOS now uses requestFastExport().
    func startExport(sampleMode: Bool = false) {
        guard let song = songState, !isExportingAudio else { return }
        #if os(macOS)
        let exportSeconds = Double(song.frame.totalBars) * 4.0 * 60.0 / Double(song.frame.tempo)
        let exportMinutes = Int((exportSeconds + 30) / 60)
        let songDuration  = exportMinutes == 1 ? "1 minute" : "\(exportMinutes) minutes"
        guard let result = AudioFileExporter.presentExportPanel(songName: song.title,
                                                                songDuration: songDuration) else { return }
        let url = result.url
        let effectiveSampleMode = result.sampleMode
        audioExportFilename = url.lastPathComponent
        audioExportProgress = 0
        isExportingAudio    = true
        visibleBarOffset    = 0
        let style = selectedStyle.rawValue.capitalized
        playback.exportAudio(url: url, state: song, sampleMode: effectiveSampleMode) { [weak self] progress in
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
                print("Audio saved: \(url.path)")
                self?.appendToLog([
                    GenerationLogEntry(tag: "FILE", description: "Exported audio \(url.lastPathComponent)")
                ])
                let legacyAnySolo = self?.soloState.contains(true) ?? false
                let legacyMuteState = self?.muteState ?? Array(repeating: false, count: kTrackCount)
                let legacySoloState = self?.soloState ?? Array(repeating: false, count: kTrackCount)
                let legacyMutedNames = (0..<kTrackCount).compactMap { i -> String? in
                    guard i != kTrackLeadSynth else { return nil }
                    let muted = legacyMuteState[i] || (legacyAnySolo && !legacySoloState[i])
                    return muted ? kTrackNames[i] : nil
                }
                let legacyComment = legacyMutedNames.isEmpty ? "" : "Muted: \(legacyMutedNames.joined(separator: ", "))"
                let legacyVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
                await AudioFileExporter.addMetadata(
                    to: url,
                    title:         song.title,
                    artist:        "Zudio",
                    genre:         song.displayStyleName,
                    bpm:           song.frame.tempo,
                    year:          Calendar.current.component(.year, from: Date()),
                    keySignature:  "\(song.frame.key) \(song.frame.mode.rawValue)",
                    timeSignature: "4/4",
                    encoder:       "Zudio \(legacyVersion)",
                    comment:       legacyComment
                )
            }
        }
        #else
        // OLD REAL-TIME EXPORT (disabled — iOS now uses requestFastExport())
        //
        // let url = AudioFileExporter.nextURL(songName: song.title, sampleMode: sampleMode)
        // audioExportFilename = url.lastPathComponent
        // audioExportProgress = 0
        // isExportingAudio    = true
        // visibleBarOffset    = 0
        // let style = selectedStyle.rawValue.capitalized
        // playback.exportAudio(url: url, state: song, sampleMode: sampleMode) { [weak self] progress in
        //     Task { @MainActor [weak self] in self?.audioExportProgress = progress }
        // } onComplete: { [weak self] error in
        //     Task { @MainActor [weak self] in
        //         self?.isExportingAudio = false
        //         if let error {
        //             if error is CancellationError {
        //                 try? FileManager.default.removeItem(at: url)
        //             } else {
        //                 print("Audio export error: \(error)")
        //             }
        //             return
        //         }
        //         print("Audio saved: \(url.path)")
        //         self?.appendToLog([
        //             GenerationLogEntry(tag: "FILE", description: "Exported audio \(url.lastPathComponent)")
        //         ])
        //         await AudioFileExporter.addMetadata(to: url, title: song.title, artist: "Zudio", genre: style)
        //     }
        // }
        print("startExport(sampleMode:) — disabled on iOS; use requestFastExport()")
        #endif
    }

    /// Cancels an in-progress export; the partial file is deleted.
    func cancelExport() {
        if isFastExporting { fastExportCancelled = true; return }
        playback.cancelExport()
    }

    private func hasSufficientDiskSpace(_ minBytes: Int64 = 500 * 1024 * 1024) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let free = attrs[.systemFreeSize] as? Int64 else { return true }
        return free >= minBytes
    }

    /// Called from the low-disk-space alert "Export Anyway" button.
    func confirmLowDiskSpaceExport() {
        guard let url = pendingExportURL, let song = songState else { return }
        pendingExportURL = nil
        launchFastExport(song: song, url: url)
    }

    // MARK: - Instrument

    func setProgram(_ program: Int, forTrack trackIndex: Int) {
        // If Lead 1 changes while the mirror is active, keep Lead 2 in sync.
        if trackIndex == kTrackLead1, lead2MirroredProgram != nil {
            lead2MirroredProgram = program
            let lead1Programs = Self.instrumentPoolPrograms(trackIndex: kTrackLead1, style: selectedStyle)
            let lead1Names    = Self.instrumentPoolNames(trackIndex: kTrackLead1, style: selectedStyle)
            if let idx = lead1Programs.firstIndex(of: program), idx < lead1Names.count {
                lead2MirrorName = lead1Names[idx]
            }
            playback.setProgram(program, forTrack: kTrackLead2)
            // Fall through — Lead 1 still gets its own program applied below.
        }
        // While Lead 2 is mirrored to Lead 1's instrument, ignore any other program change for it.
        if trackIndex == kTrackLead2, let mirrored = lead2MirroredProgram {
            playback.setProgram(mirrored, forTrack: trackIndex)
            return
        }
        // Chill texture track uses pseudo-programs 240–247 that map to M4A filenames.
        if trackIndex == kTrackTexture && selectedStyle == .chill {
            let filename = Self.chillTextureFilename(forProgram: program)
            songState = songState?.withChillAudioTexture(filename)
            if playback.isPlaying {
                audioTexture.switchTexture(filename, offsetSeconds: songState?.chillAudioTextureOffset ?? 0)
            }
            return
        }
        // Ambient texture track uses pseudo-programs 231–233 that map to audio filenames.
        if trackIndex == kTrackTexture && selectedStyle == .ambient,
           let filename = Self.ambientAudioFilename(forProgram: program) {
            let offset = songState?.ambientAudioTextureOffset ?? 0
            songState = songState?.withAmbientAudioTexture(filename, offset: offset)
            if playback.isPlaying {
                audioTexture.start(style: .ambient, texture: filename, offsetSeconds: offset)
            }
            return
        }
        playback.setProgram(program, forTrack: trackIndex)
        let style = selectedStyle
        let isDrift = songState?.isKosmicDrift == true
        let poolPrograms = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: style, isKosmicDrift: isDrift)
        if let poolIdx = poolPrograms.firstIndex(of: program) {
            let cc7Values = Self.instrumentPoolVolumeCC7(trackIndex: trackIndex, style: style, isKosmicDrift: isDrift)
            let cc7 = poolIdx < cc7Values.count ? cc7Values[poolIdx] : 100
            playback.setChannelVolume(cc7, forTrack: trackIndex)
        }
    }

    /// Maps a Chill texture pseudo-program (240–250) to an M4A filename.
    static func chillTextureFilename(forProgram program: Int) -> String? {
        switch program {
        case 240: return nil
        case 241: return "another_bar.m4a"
        case 242: return "bar_sounds.m4a"
        case 243: return "city_at_night.m4a"
        case 245: return "harbor.m4a"
        case 250: return "vinyl_crackle.m4a"
        case 251: return "another-pub.m4a"
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
        case "harbor.m4a":         return 245
        case "vinyl_crackle.m4a":  return 250
        case "another-pub.m4a":    return 251
        default:                    return 240
        }
    }

    /// Maps an Ambient audio texture filename to a short display name.
    static func ambientAudioDisplayName(_ filename: String) -> String {
        switch filename {
        case "light_rain.m4a":    return "Light Rain"
        case "rain-and-thunder.m4a":    return "Rain & Thunder"
        case "ocean_waves.m4a":   return "Ocean Waves"
        case "zen-bells.m4a":     return "Zen Bells"
        case "wind-stoorm.m4a":   return "Wind Storm"
        case "desert-winds.m4a":  return "Desert Winds"
        default:                  return "Audio"
        }
    }

    /// Maps an Ambient audio texture pseudo-program (231–236) to an M4A filename.
    static func ambientAudioFilename(forProgram program: Int) -> String? {
        switch program {
        case 231: return "light_rain.m4a"
        case 232: return "rain-and-thunder.m4a"
        case 233: return "ocean_waves.m4a"
        case 234: return "zen-bells.m4a"
        case 235: return "wind-stoorm.m4a"
        case 236: return "desert-winds.m4a"
        default:  return nil
        }
    }

    /// Maps an Ambient audio texture filename to its pseudo-program number.
    static func ambientAudioProgram(forFilename filename: String?) -> UInt8 {
        switch filename {
        case "light_rain.m4a":   return 231
        case "rain-and-thunder.m4a":   return 232
        case "ocean_waves.m4a":  return 233
        case "zen-bells.m4a":    return 234
        case "wind-stoorm.m4a":  return 235
        case "desert-winds.m4a": return 236
        default:                 return 231
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

    // MARK: - Phone player gesture helpers

    /// Returns the current MIDI program number for a track, using instrumentOverrides if set.
    func currentInstrument(forTrack trackIndex: Int) -> Int {
        let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: selectedStyle)
        guard !programs.isEmpty else { return 0 }
        let idx = instrumentOverrides[trackIndex] ?? 0
        return programs[min(idx, programs.count - 1)]
    }

    /// Shuffles the instrument on a track to a different entry in its pool.
    func regenInstrument(forTrack trackIndex: Int) {
        // Use the loaded song's style, not selectedStyle — the style picker may differ
        // from the song currently playing (e.g. a Motorik song loaded while the picker
        // still shows Chill would otherwise draw instruments from the Chill pool).
        let style = songState?.style ?? selectedStyle
        let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: style)
        guard programs.count > 1 else { return }
        let currentIdx = instrumentOverrides[trackIndex] ?? 0
        var newIdx = currentIdx
        var attempts = 0
        repeat {
            newIdx = Int.random(in: 0..<programs.count)
            attempts += 1
        } while newIdx == currentIdx && attempts < 16
        guard newIdx != currentIdx else { return }
        instrumentOverrides[trackIndex] = newIdx
        setProgram(programs[newIdx], forTrack: trackIndex)
        instrumentChangeToken += 1
        triggerVisualizerFlash(trackIndex: trackIndex)
        let isDrift2 = songState?.isKosmicDrift == true
        let tName = trackIndex < kTrackNames.count ? kTrackNames[trackIndex] : "Track \(trackIndex)"
        let names = Self.instrumentPoolNames(trackIndex: trackIndex, style: style, isKosmicDrift: isDrift2)
        let iName = newIdx < names.count ? names[newIdx] : "prog \(programs[newIdx])"
        appendToLog([GenerationLogEntry(tag: "Instrument", description: "\(tName) \(iName)", isTitle: false)])
    }

    /// Sets a specific program on a track and records the override index.
    func setInstrument(_ program: Int, forTrack trackIndex: Int) {
        let isDrift = songState?.isKosmicDrift == true
        let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: selectedStyle, isKosmicDrift: isDrift)
        if let idx = programs.firstIndex(of: program) {
            instrumentOverrides[trackIndex] = idx
        }
        setProgram(program, forTrack: trackIndex)
        instrumentChangeToken += 1
        let tName = trackIndex < kTrackNames.count ? kTrackNames[trackIndex] : "Track \(trackIndex)"
        let names = Self.instrumentPoolNames(trackIndex: trackIndex, style: selectedStyle, isKosmicDrift: isDrift)
        if let idx = programs.firstIndex(of: program), idx < names.count {
            appendToLog([GenerationLogEntry(tag: "Instrument", description: "\(tName) \(names[idx])", isTitle: false)])
        }
    }

    /// Appends an instrument-change entry to the generation log.
    /// Called by TrackRowView.cycleInstrument() which owns the display name.
    func logInstrumentChange(trackIndex: Int, name: String) {
        let tName = trackIndex < kTrackNames.count ? kTrackNames[trackIndex] : "Track \(trackIndex)"
        appendToLog([GenerationLogEntry(tag: "Instrument", description: "\(tName) \(name)", isTitle: false)])
    }

    /// Removes all active effects from a track.
    func clearAllEffects(forTrack trackIndex: Int) {
        for fx in TrackEffect.allCases {
            setEffect(fx, enabled: false, forTrack: trackIndex)
        }
        triggerVisualizerFlash(trackIndex: trackIndex)
    }

    /// Restores the style-default effects for a track (mirrors TrackRowView.applyDefaultEffects).
    func restoreDefaultEffects(forTrack trackIndex: Int) {
        // Clear all first
        for fx in TrackEffect.allCases {
            setEffect(fx, enabled: false, forTrack: trackIndex)
        }
        // Apply style defaults
        let defaults: [TrackEffect]
        switch selectedStyle {
        case .ambient:
            defaults = switch trackIndex {
            case kTrackLead1:   songState?.isAmbientPiano == true ? [.space] : [.delay, .space]
            case kTrackLead2:   [.space]
            case kTrackPads:    [.space, .sweep]
            case kTrackRhythm:  [.reverb]
            case kTrackTexture: [.space, .pan, .sweep]
            case kTrackBass:    [.reverb, .sweep]
            case kTrackDrums:   [.delay]
            default:            []
            }
        case .chill:
            let isBlues = songState?.chillBluesVariation == true
            defaults = switch trackIndex {
            case kTrackLead1:   isBlues ? [.space] : [.space, .delay]
            case kTrackLead2:   isBlues ? [.space] : [.space, .delay]
            case kTrackRhythm:  [.space]
            case kTrackPads:    [.sweep, .tremolo]
            case kTrackTexture: [.lowShelf, .reverb]
            case kTrackBass:    [.reverb]
            case kTrackDrums:   [.space]
            default:            []
            }
        case .kosmic:
            // Drift: Sweep on Pads, Pan on Texture, Tremolo on Bass (all ON); Regular: same effects available but OFF
            let isDriftEffects = songState?.isKosmicDrift == true
            defaults = switch trackIndex {
            case kTrackLead1:   [.delay, .space]
            case kTrackLead2:   [.space]
            case kTrackPads:    isDriftEffects ? [.space, .delay, .sweep] : [.space, .delay]
            case kTrackTexture: isDriftEffects ? [.delay, .space, .pan]   : [.delay, .space]
            case kTrackBass:    isDriftEffects ? [.tremolo] : []
            case kTrackRhythm:  [.delay]
            default:            []
            }
        case .motorik:
            let idx = instrumentOverrides[kTrackLead1] ?? 0
            let mnames = Self.instrumentPoolNames(trackIndex: kTrackLead1, style: .motorik)
            let isTremoloLead = trackIndex == kTrackLead1
                && idx < mnames.count
                && (mnames[idx] == "Synth Lead" || mnames[idx] == "Square Lead")
            let isNoir = songState?.motorikNoirVariation == true
            defaults = switch trackIndex {
            case kTrackLead1:   isTremoloLead ? [.delay, .tremolo] : [.delay]
            case kTrackRhythm:  [.delay]
            case kTrackPads:    isNoir ? [.space, .sweep] : [.space]
            case kTrackTexture: [.pan]
            default:            []
            }
        }
        for fx in defaults {
            setEffect(fx, enabled: true, forTrack: trackIndex)
        }
        triggerVisualizerFlash(trackIndex: trackIndex)
    }

    /// Regenerates the pattern for a random non-drum track.
    func regenRandomNonDrumTrack() {
        let eligible = [kTrackLead1, kTrackLead2, kTrackPads, kTrackRhythm, kTrackTexture, kTrackBass]
        guard let track = eligible.randomElement() else { return }
        triggerVisualizerFlash(trackIndex: track)
        regenerateTrack(track)
    }

    /// Loads a SongState from the in-memory generationHistory without re-generating.
    /// Pass forcePlay: true (song list taps) to always start playback regardless of prior state.
    func loadFromGenerationHistory(_ state: SongState, forcePlay: Bool = false) {
        guard !isGenerating else { return }
        let wasPlaying = playback.isPlaying
        stop()
        selectedStyle    = state.style
        keyOverride      = nil
        tempoOverride    = nil
        moodOverride     = nil
        songState        = state
        visibleBarOffset = 0
        lastEmittedStep  = -1
        // Restore the exact instruments that were playing when this song was first generated.
        if let cached = sessionInstrumentOverrides[state.globalSeed] {
            instrumentOverrides = cached
        } else {
            instrumentOverrides = [:]
            if state.style == .chill {
                let prog = Self.chillTextureProgram(forFilename: state.chillAudioTexture)
                instrumentOverrides[kTrackTexture] = Int(prog) - 240
            }
            if state.style == .ambient, let audioTex = state.ambientAudioTexture {
                let prog = Self.ambientAudioProgram(forFilename: audioTex)
                instrumentOverrides[kTrackTexture] = Int(prog) - 231
            }
        }
        songInstrumentOverrides = instrumentOverrides
        applyAmbientPianoInstrument(for: state)
        restoreLead2Mirror()
        applyLead2Mirror(for: state)
        muteState = Array(repeating: false, count: kTrackCount)
        soloState = Array(repeating: false, count: kTrackCount)
        playback.muteState    = muteState
        playback.soloState    = soloState
        playback.kosmicStyle  = state.style == .kosmic
        playback.motorikStyle = state.style == .motorik
        playback.load(state)
        playback.seek(toStep: 0)
        playback.setAmbientMode(state.style == .ambient)
        playback.setChillMode(state.style == .chill, bluesVariation: state.chillBluesVariation)
        defaultsResetToken += 1
        applyCurrentInstrumentsToPlayback()
        if wasPlaying || forcePlay { playback.play() }
        if playMode == .evolve { tearDownEvolve(); startEvolveMode(from: state) }
    }

    /// Loads a song from persistedHistory. Fast path: already in session memory.
    /// Slow path: regenerates deterministically from seed (async).
    /// forcePlay: true  — always start playback (song list taps, default).
    /// forcePlay: false — resume playback only if already playing (⏮/⏭ navigation).
    func loadFromPersistedSong(_ song: PersistedSong, forcePlay: Bool = true) {
        guard !isGenerating else { return }
        // Fast path — still in session memory, no regeneration needed.
        if let existing = generationHistory.first(where: { $0.globalSeed == song.seed }) {
            loadFromGenerationHistory(existing, forcePlay: forcePlay)
            return
        }
        // Slow path — regenerate from seed.
        let thenPlay = forcePlay || playback.isPlaying   // capture before stop()
        stop()
        isGenerating = true
        let trackOvr = Dictionary(uniqueKeysWithValues:
            song.trackOverrides.compactMap { k, v -> (Int, UInt64)? in
                guard let i = Int(k) else { return nil }; return (i, v) })
        Task.detached(priority: .userInitiated) { [weak self, song, trackOvr, thenPlay] in
            guard let self else { return }
            var state = SongGenerator.generate(
                seed:            song.seed,
                keyOverride:     song.keyOverride,
                tempoOverride:   song.tempoOverride,
                moodOverride:    song.moodOverride,
                style:           song.style,
                forceBassRuleID: song.forcedRules["Bass"],
                forceDrumRuleID: song.forcedRules["Drums"],
                forceArpRuleID:  song.forcedRules["Rhythm"],
                forcePadsRuleID: song.forcedRules["Pads"],
                forceLeadRuleID: song.forcedRules["Lead"],
                forceTexRuleID:  song.forcedRules["Tex"]
            )
            for idx in trackOvr.keys.sorted() {
                state = SongGenerator.regenerateTrack(idx, songState: state, overrideSeed: trackOvr[idx])
            }
            await MainActor.run {
                state.title = song.title   // preserve the title from when the song was generated
                self.isGenerating  = false
                self.selectedStyle = song.style
                self.keyOverride   = song.keyOverride
                self.tempoOverride = song.tempoOverride
                self.moodOverride  = song.moodOverride
                self.instrumentOverrides = song.decodedInstrumentOverrides
                if song.style == .chill && self.instrumentOverrides[kTrackTexture] == nil {
                    let prog = Self.chillTextureProgram(forFilename: state.chillAudioTexture)
                    self.instrumentOverrides[kTrackTexture] = Int(prog) - 240
                }
                if song.style == .ambient, let audioTex = state.ambientAudioTexture,
                   self.instrumentOverrides[kTrackTexture] == nil {
                    let prog = Self.ambientAudioProgram(forFilename: audioTex)
                    self.instrumentOverrides[kTrackTexture] = Int(prog) - 231
                }
                self.songInstrumentOverrides = self.instrumentOverrides
                self.applyAmbientPianoInstrument(for: state)
                self.restoreLead2Mirror()
                self.applyLead2Mirror(for: state)
                self.finishLoadingSong(state, thenPlay: thenPlay)
                if self.playMode == .evolve { self.tearDownEvolve(); self.startEvolveMode(from: state) }
            }
        }
    }

    // MARK: - Fast export

    // Written from main actor before launch; read from render thread via isCancelled closure.
    nonisolated(unsafe) private var fastExportCancelled = false

    func requestFastExport() {
        guard let song = songState, !isFastExporting, !isExportingAudio else { return }

        #if os(macOS)
        if !hasSufficientDiskSpace() {
            let alert = NSAlert()
            alert.messageText = "Low Disk Space"
            alert.informativeText = "Less than 500 MB is available. The export may fail. Continue anyway?"
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Export Anyway")
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        guard let result = AudioFileExporter.presentFastExportPanel(songName: song.title) else { return }
        launchFastExport(song: song, url: result.url, separateTracks: result.separateTracks)
        #else
        let url = AudioFileExporter.nextURL(songName: song.title)
        if !hasSufficientDiskSpace() {
            pendingExportURL = url
            showLowDiskSpaceAlert = true
        } else {
            launchFastExport(song: song, url: url)
        }
        #endif
    }

    private func launchFastExport(song: SongState, url: URL, separateTracks: Bool = false) {
        var programs        = (0..<kTrackCount).map { playback.loadedProgram(forTrack: $0) }
        // Lead Synth is a fixed Polysynth (90) doubler — it has no instrument pool and
        // loadedProgram() returns 255 on iOS after cache invalidation. Restore the default
        // so OfflineExport doesn't try to load a non-existent GM patch 255.
        if programs[kTrackLeadSynth] == 255 {
            programs[kTrackLeadSynth] = Int(kDefaultGMPrograms[kTrackLeadSynth] ?? 90)
        }
        // If instruments haven't loaded yet (program 255 = never loaded), don't attempt export.
        // This can happen when an old saved song is loaded and the user taps Export immediately.
        if programs.allSatisfy({ $0 == 255 }) {
            let msg = "Song not ready — please wait a moment for instruments to load, then try again."
            fastExportErrorMessage = msg
            appendToLog([GenerationLogEntry(tag: "⚠️ EXPORT", description: msg)])
            return
        }
        let rawSnapshots    = playback.effectSnapshots()
        // Apply mute/solo: mirror PlaybackEngine.applyMuteState() so export
        // matches what the user hears during playback.
        let anySolo = soloState.contains(true)
        var snapshots = rawSnapshots
        for i in 0..<snapshots.count {
            let idx    = (i == kTrackLeadSynth) ? kTrackLead1 : i
            let muted  = muteState[idx] || (anySolo && !soloState[idx])
            if muted { snapshots[i].volume = 0.0 }
        }
        let textureSnapshot = audioTexture.exportSnapshot()
        let genre           = song.displayStyleName   // e.g. "Chill Blues", "Motorik Noir", not just "Chill"

        // Muted-track comment — list any user-visible tracks that are silent in this export
        let mutedTrackNames = (0..<kTrackCount).compactMap { i -> String? in
            guard i != kTrackLeadSynth else { return nil }  // internal track, not user-visible
            let muted = muteState[i] || (anySolo && !soloState[i])
            return muted ? kTrackNames[i] : nil
        }
        let exportComment = mutedTrackNames.isEmpty
            ? ""
            : "Muted: \(mutedTrackNames.joined(separator: ", "))"

        let exportYear    = Calendar.current.component(.year, from: Date())
        let exportVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let exportEncoder = "Zudio \(exportVersion)"
        let exportKey     = "\(song.frame.key) \(song.frame.mode.rawValue)"

        audioExportFilename        = url.lastPathComponent
        audioExportProgress        = 0
        isExportingAudio           = true
        isFastExporting            = true
        exportingSeparateTracks    = separateTracks
        fastExportCancelled        = false

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let renderResult = try OfflineExport.render(
                    state: song,
                    programs: programs,
                    snapshots: snapshots,
                    rawSnapshots: separateTracks ? rawSnapshots : nil,
                    textureSnapshot: textureSnapshot,
                    outputURL: url,
                    separateTracks: separateTracks,
                    onProgress: { p in
                        Task { @MainActor [weak self] in self?.audioExportProgress = p }
                    },
                    isCancelled: { [weak self] in self?.fastExportCancelled ?? true }
                )

                await AudioFileExporter.addMetadata(
                    to: url,
                    title:         song.title,
                    artist:        "Zudio",
                    genre:         genre,
                    bpm:           song.frame.tempo,
                    year:          exportYear,
                    keySignature:  exportKey,
                    timeSignature: "4/4",
                    encoder:       exportEncoder,
                    comment:       exportComment
                )
                for item in renderResult.trackURLs {
                    let label = item.trackIdx < kTrackNames.count
                        ? kTrackNames[item.trackIdx] : "Track \(item.trackIdx)"
                    await AudioFileExporter.addMetadata(
                        to: item.url,
                        title:         "\(song.title) – \(label)",
                        artist:        "Zudio",
                        genre:         genre,
                        bpm:           song.frame.tempo,
                        year:          exportYear,
                        keySignature:  exportKey,
                        timeSignature: "4/4",
                        encoder:       exportEncoder,
                        comment:       ""
                    )
                }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isExportingAudio          = false
                    self.isFastExporting           = false
                    self.exportingSeparateTracks   = false
                    let stemNote = renderResult.trackURLs.isEmpty
                        ? "" : " + \(renderResult.trackURLs.count) stems"
                    self.appendToLog([GenerationLogEntry(tag: "FILE",
                        description: "Fast export: \(url.lastPathComponent)\(stemNote)")])
                    #if !os(macOS)
                    self.fastExportedFileURL = url
                    #endif
                }
            } catch {
                try? FileManager.default.removeItem(at: url)
                await MainActor.run { [weak self] in
                    self?.isExportingAudio         = false
                    self?.isFastExporting          = false
                    self?.exportingSeparateTracks  = false
                    if !(error is CancellationError) {
                        let msg = error.localizedDescription
                        self?.fastExportErrorMessage = msg
                        self?.appendToLog([GenerationLogEntry(tag: "⚠️ EXPORT", description: msg)])
                    }
                }
            }
        }
    }

    // MARK: - Mac share filter

#if os(macOS)
    /// Limits the Mac share sheet to AirDrop, Mail, and Messages only.
    private final class MacSharePickerDelegate: NSObject, NSSharingServicePickerDelegate {
        func sharingServicePicker(_ picker: NSSharingServicePicker,
                                  sharingServicesForItems items: [Any],
                                  proposedSharingServices services: [NSSharingService]) -> [NSSharingService] {
            var result: [NSSharingService] = []
            if let s = NSSharingService(named: .sendViaAirDrop)   { result.append(s) }
            if let s = NSSharingService(named: .composeEmail)      { s.subject = "Check out Zudio"; result.append(s) }
            if let s = NSSharingService(named: .composeMessage)    { result.append(s) }
            return result
        }
    }
#endif

    /// Clears all mutes, solos, manual effect changes, and instrument overrides —
    /// restores the song to the exact state it was in right after generation/load.
    func resetEffectsToDefaults() {
        muteState = Array(repeating: false, count: kTrackCount)
        soloState = Array(repeating: false, count: kTrackCount)
        playback.muteState = muteState
        playback.soloState = soloState
        audioTexture.setSoloMuted(false)
        // Restore instruments to what they were when the song was generated/loaded.
        instrumentOverrides = songInstrumentOverrides
        defaultsResetToken += 1
        applyCurrentInstrumentsToPlayback()
        // Restore audio effects to style defaults.
        for trackIndex in 0..<kTrackCount {
            restoreDefaultEffects(forTrack: trackIndex)
        }
    }
}
