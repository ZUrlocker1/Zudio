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
                discardPreGeneratedSong()
                shouldLogNextUpWhenReady = false
                upNextLogged             = false
            case .evolve:
                if let current = songState { startEvolveMode(from: current) }
            case .endless:
                // Sync style axis to the currently playing style so shifts are relative to it
                songsInCurrentStyle = 1
                songsInCurrentPair  = 1
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

    /// Cancels any in-progress countdown. Playback has stopped, so a pending sleep-timer
    /// fire tied to the previous play session is no longer meaningful — without this, the
    /// timer keeps counting down in the background and fires later against a silent player.
    private func cancelSleepTimerCountdown() {
        sleepTimerFire?.invalidate()
        sleepTimerFire = nil
        sleepTimerExpiresAt = nil
    }

    /// Call immediately before every playback.play() site: dismisses any stale "sleep timer
    /// ended" message and arms a fresh countdown (the timer starts when playback starts, not
    /// at app launch or at some earlier press of Play).
    private func prepareSleepTimerForPlayback() {
        clearSleepTimerMessage()
        rearmSleepTimerIfNeeded()
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
        var trackOverrides: [String: UInt64]
        // Instrument pool indices per track. Optional so old persisted data decodes as nil.
        var instrumentOverrides: [String: Int]?
        // Instruments changed by the user after load, by track. Applied after the Chill lead
        // pin on reload, so a deliberate change survives while the pin still repairs entries
        // saved with the wrong lead. Optional so older persisted data decodes as nil.
        var manualInstruments: [String: Int]?
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

        // The saved Chill substyle, replayed on reload so a later change to the Soho share cannot
        // turn a saved song into another substyle. Only an explicit saved name counts: songs from
        // before substyleName existed are left to the seed.
        var savedAsBlues:     Bool { style == .chill && substyleName == "Chill Blues" }
        var savedAsSoho:      Bool { style == .chill && substyleName == "Chill Soho" }
        var savedAsBaseChill: Bool { style == .chill && substyleName == "Chill" }

        /// Decodes `instrumentOverrides` (String keys) back to `[Int: Int]`.
        var decodedTrackOverrides: [Int: UInt64] {
            Dictionary(uniqueKeysWithValues: trackOverrides.compactMap { k, v -> (Int, UInt64)? in
                guard let i = Int(k) else { return nil }; return (i, v) })
        }

        var decodedManualInstruments: [Int: Int] {
            guard let m = manualInstruments else { return [:] }
            return Dictionary(uniqueKeysWithValues: m.compactMap { k, v -> (Int, Int)? in
                guard let i = Int(k) else { return nil }; return (i, v) })
        }

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

    /// Rebuilds a saved song from its seed: the generator with every recorded forced setting,
    /// then the per-track regenerations in order. The one place a saved song is replayed — the
    /// Songs list, the startup preload and a .zudio file all come here. They used to carry
    /// their own copies, and the two history paths left out the percussion style and bridge
    /// that the file path passed (found 2026-10-16).
    nonisolated static func regenerateSong(seed: UInt64, keyOverride: String?, tempoOverride: Int?,
                                           moodOverride: Mood?, style: MusicStyle,
                                           forced: [String: String], trackOverrides: [Int: UInt64],
                                           forceBlues: Bool = false, forceSoho: Bool = false,
                                           forbidSoho: Bool = false) -> SongState {
        var state = SongGenerator.generate(
            seed:                 seed,
            keyOverride:          keyOverride,
            tempoOverride:        tempoOverride,
            moodOverride:         moodOverride,
            style:                style,
            forceBassRuleID:      forced["Bass"],
            forceDrumRuleID:      forced["Drums"],
            forceArpRuleID:       forced["Rhythm"],
            forcePadsRuleID:      forced["Pads"],
            forceLeadRuleID:      forced["Lead"],
            forceTexRuleID:       forced["Tex"],
            forcePercussionStyle: forced["PercStyle"].flatMap { PercussionStyle(rawValue: $0) },
            forceBridge:          forced["Bridge"] == "true",
            useBrushKit:          forced["BrushKit"] == "true",
            forceBluesVariation:  forceBlues,
            forceSohoVariation:   forceSoho,
            forbidSohoVariation:  forbidSoho,
            forceAmbientPianoRule: forced["Piano"]
        )
        for idx in trackOverrides.keys.sorted() {
            state = SongGenerator.regenerateTrack(idx, songState: state, overrideSeed: trackOverrides[idx])
        }
        return state
    }

    /// The instruments for a song just loaded, after `instrumentOverrides` holds what was saved:
    /// the Chill leads pinned to what the generator chose, the snapshot that "reset effects"
    /// restores, Ambient Piano's Lead 1, Lead 2's mirror and the session cache. Every load path
    /// runs this; the .zudio path used to skip it and saved the song with its leads unpinned.
    private func applyLoadedInstruments(for state: SongState) {
        syncGeneratedInstruments(for: state)
        songInstrumentOverrides = instrumentOverrides
        applyAmbientPianoInstrument(for: state)
        restoreLead2Mirror()
        applyLead2Mirror(for: state)
        sessionInstrumentOverrides[state.globalSeed] = instrumentOverrides
    }

    /// The playback engine's per-style switches for `state`: Kosmic and Motorik fades, the Chill
    /// fade-in on a song that opens already playing, and the Ambient and Chill effect setups.
    /// `finishLoadingSong` used to switch the Chill fade off, and the history path never set
    /// it, so Endless, ⏮ and Songs-list reloads lost the fade (found 2026-10-16).
    private func configurePlaybackStyle(for state: SongState) {
        playback.kosmicStyle  = state.style == .kosmic
        playback.motorikStyle = state.style == .motorik
        playback.chillFade    = state.style == .chill && {
            if case .alreadyPlaying = state.structure.introStyle { return true }
            return false
        }()
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
                let state = Self.regenerateSong(seed: song.seed, keyOverride: song.keyOverride,
                                                tempoOverride: song.tempoOverride, moodOverride: song.moodOverride,
                                                style: song.style, forced: song.forcedRules,
                                                trackOverrides: song.decodedTrackOverrides,
                                                forceBlues: song.savedAsBlues, forceSoho: song.savedAsSoho,
                                                forbidSoho: song.savedAsBaseChill)
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
                    // Refresh substyleName from the regenerated state. Backfills songs saved
                    // before build 125 (when the field was added) and corrects songs whose
                    // substyle was named later than they were saved — a Motorik Europe song
                    // saved while the sync group was still unnamed reads back as "Motorik".
                    if song.substyleName != finalState.displayStyleName,
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
    /// Consecutive songs confined to one pair — Ambient+Chill (0) or Kosmic+Motorik (1) — used by
    /// the hard streak cap in decideNextStyle(). Reset to 1 whenever the pair actually changes.
    private var songsInCurrentPair: Int = 0

    // Pre-generated next song for seamless Endless transitions
    private var nextSongState:            SongState? = nil
    private var isPreGenerating:          Bool       = false
    // Incremented by stop() so any 500ms-delayed finishLoadingSong from a just-ended song
    // is cancelled when the user explicitly stops, preventing texture/music from restarting.
    private var endlessTransitionToken:   Int        = 0
    // Incremented each time a pre-gen starts, is discarded or is taken; a task completion that
    // carries an old token is dropped, so an abandoned pre-gen can't land in nextSongState
    // later with the wrong style. (This comment described a token that did not exist until
    // 2026-10-18: two pre-gens could run and whichever finished last won.)
    private var preGenToken:              Int        = 0
    // The style-rotation state before the in-flight or ready pre-gen called decideNextStyle().
    // Restored when that song is discarded unplayed, so an abandoned pre-gen doesn't move the
    // Endless axis. Cleared when the song is taken for playback.
    private var preGenAxisSnapshot: (index: Int, inStyle: Int, inPair: Int)? = nil

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
    // Separate in-flight flags: pass content and the next song used to share one, so starting
    // pass 2 made preGenerateEvolveNextSong() return at once and the next song was never
    // generated early.
    private var evolvePassInFlight:        Bool        = false
    private var evolveNextSongInFlight:    Bool        = false
    // The pass (1 or 2) whose turn came before its content was ready: the in-flight build
    // switches in when it lands, instead of a second identical build being started.
    private var evolvePassPending:         Int?        = nil
    // Set when the next song is due while its pre-generation is still running: it starts when
    // that lands, instead of a second song being generated.
    private var evolveNextSongPending:     Bool        = false
    // Style the in-flight next song is being generated for (waited on only if still selected).
    private var evolveNextSongPendingStyle: MusicStyle? = nil
    // Bumped only by tearDownEvolve(). The next song belongs to the session, not to a phase, so
    // its pre-generation checks this: evolvePhaseToken also moves at every pass switch, which
    // used to discard a finished next song and leave its in-flight flag set.
    private var evolveSessionToken:        Int         = 0
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
        hasHadSohoSong           = false
        songGenerationCount      = 0

        // Reset Endless / Evolve mode state
        playMode             = .song
        discardPreGeneratedSong()
        songsInCurrentStyle  = 0
        songsInCurrentPair   = 0
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
    /// Whether a Chill Soho song has been generated yet: the history holds one at launch, or one
    /// was made this session. Until then the first Soho song is a curated one — see
    /// `firstSohoSeeds`. Cleared with the first-best songs.
    private var hasHadSohoSong = false

    /// Seeds whose natural song is the best first Chill Soho song: a Latin groove in drums and
    /// bass, Operator (CHL-LD1-010) on flute with vibraphone on Lead 2, and a breakdown — the Remix Break, the Duo or the
    /// bass ostinato — with the hook coming home three to six times. Natural rather than forced,
    /// so the song replays exactly with no forced settings, and each one is Soho under the
    /// release activation mix as well as today's test mix. ReplayFidelityTests'
    /// `firstSohoSeedsStillQualify` fails if a generator change stops any of them qualifying —
    /// re-run the search then (chosen 2026-10-16; 34075 and 65086 replaced by 4673 and 9594 on
    /// 2026-10-18, after the 20% Blues threshold turned those two into Blues songs).
    nonisolated static let firstSohoSeeds: [UInt64] = [
        17597, 48059, 54933, 48701,     // Remix Break
        4673, 36568, 63372, 13012,      // Duo
        16015, 41529, 9594, 32350,      // bass ostinato
    ]

    /// `state`, or the curated first Soho song in its place when `state` is the first Chill Soho
    /// song (`hadSoho` false). The curated song takes a seed from `firstSohoSeeds` at random.
    nonisolated static func withFirstSohoSong(_ state: SongState, hadSoho: Bool) -> SongState {
        guard !hadSoho, state.style == .chill, state.chillSohoVariation,
              let seed = firstSohoSeeds.randomElement() else { return state }
        return SongGenerator.generate(seed: seed, style: .chill)
    }
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
    /// Instruments the user changed after load, per song seed (see PersistedSong.manualInstruments).
    private var sessionManualInstruments: [UInt64: [Int: Int]] = [:]
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
        (kTrackLead1,  .motorik, 0),  // Mono Synth       patch 81 — thin on repeat, so never twice running
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
        (kTrackBass,    .kosmic,  7), // Warm Pad         patch 89
        (kTrackBass,    .motorik, 6), // Synth Bass 1     patch 38
    ]

    private static let trackDisplayName: [Int: String] = [
        kTrackLead1: "Lead 1", kTrackLead2: "Lead 2", kTrackPads: "Pads",
        kTrackRhythm: "Rhythm", kTrackTexture: "Texture", kTrackBass: "Bass", kTrackDrums: "Drums"
    ]

    /// The instruments a style offers, as ONE superset per style. The user's picker shows this
    /// whole list, so any song can be auditioned on any instrument the style owns — including
    /// ones its own substyle would never generate. `instrumentPickPool` is what narrows
    /// generation to the substyle's subset, and it is the only place a substyle restriction
    /// belongs.
    ///
    /// **Do not branch this on a substyle.** Chill briefly did, giving each of its three forms
    /// its own pool, which hid instruments from the picker that the user was meant to reach
    /// (Zack, 2026-10-13). Motorik and Kosmic have always had one pool each.
    ///
    /// The single exception is the Chill **Texture** track: base Chill and Blues play audio loop
    /// files there and Soho plays MIDI horns. Those are not interchangeable patches — the engine
    /// loads them by different paths — so that one branches on `isChillSoho`, which is why the
    /// flag exists at all.
    nonisolated static func instrumentPoolNames(trackIndex: Int, style: MusicStyle,
                                                isChillSoho: Bool = false) -> [String] {
        // Chill Soho texture is MIDI, never audio: horns for the stabs, bells and vibes for colour.
        // Every program was checked against Zudio.sf2 (tools/sf2_drum_keys.py's sibling check) —
        // Brass Section (61), the obvious section voice, is NOT in the soundfont and would play
        // silent. Synth Brass 1/2 stood in for it until Zack heard them (2026-10-11): both are
        // synthetic where this music wants real horns. French Horns replaced them and in turn did
        // not work for the punctuation either (Zack, 2026-10-12); Trombone took its slot, the
        // third voice of an early-80s horn section, sitting under Lead 1 rather than over it.
        // The bank-8 Synth Brass 3/4 were tried there too and rejected like the bank-0 pair, so
        // no synth brass belongs here. The saxes stay out: they are Lead 2's voices.
        // Celesta, Glockenspiel, Solo Vox, Halo Pad and then Crystal all came out on
        // 2026-10-12. Vibraphone keeps its place as the bell colour. Xylophone joined it, then came
        // out on 2026-10-15: it never sounded like much, and it is not musical here unless it is
        // the lead (Zack). Its 10% went to Vibraphone.
        // Nothing in the pool sustains now except the brass, so a Sustained Halo song that draws
        // a mallet gets a note that rings and decays inside its written length rather than
        // holding — brass is 70% of picks, so that is the minority case.
        if isChillSoho && style == .chill && trackIndex == kTrackTexture { return ["Trumpet","Trombone","Muted Trumpet","Vibraphone"] }
        // Chill Soho Lead 1: base Chill's five plus Flute, which is in 4 of the 14 corpus files as
        // the voice standing in for the singer. The first five keep base Chill's order so an
        // index carried over from another Chill song still means the same instrument.
        // The WEIGHTS live in ChillMusicalFrameGenerator.pickLeadInstrumentSoho, which is what
        // actually chooses Lead 1 for a song — keep the two in step.
        // Chill Lead 1, one pool per form, each with a voice the other two do not have: Flute is
        // Soho's, Clarinet is Blues's, Muted Trumpet is base Chill's. The WEIGHTS live in
        // ChillMusicalFrameGenerator's three pickers, which is what actually chooses Lead 1 for a
        // song — a pool must contain everything its picker can choose or the instrument never
        // reaches the sampler. (Zack, 2026-10-13)
        // Chill Soho Lead 2: what answers the singer in the corpus. Baritone Sax (67) was measured
        // too but is not in Zudio.sf2.
        // Chill Soho rhythm: base Chill's keyboards plus guitars. Guitar is the corpus's dominant
        // comping voice — Jazz Guitar is in 8 of the 14 records and Clean Guitar in 7, between
        // them more notes than anything else. Neither was in Zudio.sf2 until both were copied in
        // for the 2026-10-15 audition, alongside five more — see the Soho rhythm branch above.
        // Full Kosmic pool is always shown to the user (Regular + Drift-exclusive instruments combined).
        // instrumentPickPool() restricts random generation to the appropriate substyle subset.
        switch (trackIndex, style) {
        case (kTrackLead1,   .chill):   return ["Muted Trumpet","Tenor Sax","Alto Sax","Trumpet","Clarinet","Flute","Soprano Sax","Recorder"]
        case (kTrackLead1,   .ambient): return ["Stereo Piano","Flute","Ocarina","Whistle","Brightness","Calliope Lead","Harp","Shakuhachi"]
        case (kTrackLead1,   .kosmic):  return ["Flute","Brightness","Oboe","Recorder","Warm Pad","Sine Wave","Bottle Blow","Shenai"]
        case (kTrackLead1,   .motorik): return ["Mono Synth","Saw Lead 3","Soft Brass","Polysynth","Chiff Lead","Square Lead","Synth Lead","Saw Stack"]
        case (kTrackLead1,   _):        return ["Mono Synth","Soft Brass","Pad 3 Poly","Chiff Lead"]
        // Blues drops Flute; the generator never chose Xylophone for any form, so it is gone.
        case (kTrackLead2,   .chill):   return ["Vibraphone","Flute","Soprano Sax","Trombone","Alto Sax","Tenor Sax","Synth Brass 1"]
        case (kTrackLead2,   .ambient): return ["Harp","Acoustic Guitar","FX Crystal","Space Voice","FX Atmosphere"]
        case (kTrackLead2,   .kosmic):  return ["Brightness","Bassoon","Charang","Vox Solo","Crystal"]
        case (kTrackLead2,   .motorik): return ["Polysynth","Brightness","Moog","Elec Guitar","Square Lead","Synth Lead","Saw Lead","5th Saw Wave"]
        case (kTrackLead2,   _):        return ["Polysynth","Brightness","Minimoog","Elec Guitar"]
        // Chill pads. The corpus's sustained voices are Stereo Strings Slow (p49, 850 notes
        // across 4 files, 3.2 beats a note) and Synth Strings 1 (p50, 848 notes across 4).
        // Base Chill's "String Pad" is p48, Stereo Strings *Fast*, which no corpus file uses and
        // which is the wrong articulation for a pad — Soho and Blues take the slow one instead.
        // Soho adds Bowed Glass (p92, 2 files); Blues adds a detuned tonewheel organ, the bed
        // under a blues ballad, and the one organ its Rhythm track never uses (Zack, 2026-10-13).
        // Each form keeps two pads the other two do not have, and only Synth Strings is common to
        // all three (Zack, 2026-10-13):
        //   base  — Warm Pad, String Pad (p48, the fast strings) and Sweep Pad, the filter sweep
        //           that suits its electronic and St Germain beat styles and neither other form.
        //           Every pad base Chill has is its own
        //   Blues — Synth Strings. A tonewheel organ was tried here and removed: an organ is a
        //           comping voice, and Blues already draws one on Rhythm in 80% of songs, so a
        //           sixth of them ended up with two organs at once (Zack, 2026-10-13)
        //   Soho  — Bowed Glass and Halo Pad, the longest-sustaining pad voice in the corpus at
        //           3.4 beats a note. Concert Choir was tried and removed: the pads are too busy
        //           a part for a choir
        // Stereo Strings (p49) is the only pad shared at all, by Blues and Soho; nothing is
        // common to all three.
        case (kTrackPads,    .chill):   return ["Warm Pad","Strings Fast","Sweep Pad","Soundtrack","Cello","Synth Strings 5","Strings Slow","Halo Pad","Bowed Glass"]
        case (kTrackPads,    .ambient): return ["Sweep Pad","Synth Strings","Halo Pad","Soundtrack"]
        case (kTrackPads,    .kosmic):  return ["Sweep Pad","Synth Strings","Warm Pad","Space Voice","Halo Pad","Bowed Glass","Fantasia 2"]
        case (kTrackPads,    _):        return ["Halo Pad","Sweep Pad","Bowed Glass","Synth Strings"]
        // Chill rhythm, every form. The guitars after Nylon were copied into Zudio.sf2 from
        // GeneralUser GS 2.0.3 (tools/sf2_copy_presets.py) for a Soho audition (2026-10-15) and
        // are kept adjacent so the picker reads as one block. Only Soho draws them at random;
        // base Chill and Blues reach them through the picker — one pool for all three forms,
        // no per-form pickers (Zack, 2026-10-15). Wah Guitar (11029), 12-String Guitar (8025),
        // Steel Guitar (25) and Clean Guitar 2 (12027) came out after listening and were removed
        // from the soundfont again by tools/sf2_remove_presets.py. Clean Guitar (27) came out of
        // the pool later; it stays in the soundfont, as Funk Guitar is built on its samples. Every guitar takes the amp
        // tremolo by default — see rhythmUsesTremolo, which keys on the GM guitar family.
        case (kTrackRhythm,  .chill):    return ["Rhodes","Wurlitzer","B3 Organ","Perc Organ","Stereo Piano","Rock Organ","Tonewheel","Nylon Guitar",
                                                 "Jazz Guitar","Funk Guitar"]
        case (kTrackRhythm,  .ambient):  return ["Glockenspiel","Celesta","Crystal","Rain","Tinker Bell","Windchime","Church Bells","Kalimba"]
        case (kTrackRhythm,  .kosmic):   return ["Moog","Wurlitzer","Rock Organ","Harpsi Pad","New Age Pad","Synth Mallet","Synth Chime","Mystery Pad"]
        case (kTrackRhythm,  .motorik):  return ["Guitar Pulse","Crunch Guitar","Fuzz Guitar","Doctor Solo","Acoustic Bass","Pick Bass","Synth Bass 3","Charang","Harpsi Pad","Electric Piano 1"]
        case (kTrackRhythm,  _):         return ["Guitar Pulse","Moog Lead","Fuzz Guitar"]
        case (kTrackTexture, .chill):   return ["None","Another bar","Another pub","Bar sounds","City at night","Harbor","Vinyl crackle"]
        case (kTrackTexture, .ambient): return ["Strings","Bowed Glass","Choir Aahs","FX Atmosphere","Pad 3 Poly"]
        case (kTrackTexture, .kosmic):  return ["Pad 3 Poly","Fifths Lead","Solar Wind","FX Echoes","Rain"]
        case (kTrackTexture, .motorik): return ["Fifths Lead","Halo Pad","Warm Pad","FX Atmosphere","FX Echoes",
                                                "Solar Wind","Interference","Guitar Fdbk","Metal Pad","Ice Rain","Mystery Pad"]
        case (kTrackTexture, _):        return ["Fifths Lead","Halo Pad","Warm Pad","FX Atmosphere","FX Echoes"]
        case (kTrackBass,    .chill):   return ["Fretless Bass","Acoustic Bass","Elec Bass"]
        case (kTrackBass,    .ambient): return ["Cello","French Horn","Voice Oohs","FM Synth","Metallic Pad"]
        case (kTrackBass,    .kosmic):  return ["Moog","Lead Bass","Mono Synth","Rock Bass","Synth Bass 3","Pulse Bass","Tonewheel","Warm Pad"]
        case (kTrackBass,    .motorik): return ["Moog","Lead Bass","Rock Bass","Elec Bass","Mean Saw Bass","Techno Bass","Synth Bass 1"]
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
    /// MIDI programs for each slot of `instrumentPoolNames` — same order, same count. A
    /// non-zero soundfont bank is encoded as `bank * 1000 + program`.
    nonisolated static func instrumentPoolPrograms(trackIndex: Int, style: MusicStyle,
                                                   isChillSoho: Bool = false) -> [Int] {
        // Chill Soho MIDI texture — names and the reasons are in instrumentPoolNames.
        // Trombone replaced French Horns, which did not work for the punctuation (Zack,
        // 2026-10-12). Brass Section (61) is not in Zudio.sf2 and would play silent.
        if isChillSoho && style == .chill && trackIndex == kTrackTexture { return [56, 57, 59, 11] }
        // All Kosmic programs are in the base .kosmic cases below (Regular + Drift-exclusive combined).
        switch (trackIndex, style) {
        case (kTrackLead1, .chill):    return [59, 66, 65, 56, 71, 73, 64, 74]
        case (kTrackLead1, .ambient):  return [61001, 73, 79, 78, 100, 82, 46, 77]
        case (kTrackLead1, .kosmic):   return [73, 100, 68, 74, 89, 8080, 76, 111]  // + Warm Pad, Sine Wave, Bottle Blow, Shenai
        case (kTrackLead1, .motorik):  return [81, 13081, 62, 90, 83, 80, 87, 11100]
        case (kTrackLead1, _):         return [81, 62, 90, 83]
        case (kTrackLead2, .chill):    return [11, 73, 64, 57, 65, 66, 62]
        case (kTrackLead2, .ambient):  return [46, 24, 98, 91, 99]
        case (kTrackLead2, .kosmic):   return [100, 70, 84, 85, 98]
        case (kTrackLead2, .motorik):  return [90, 100, 39, 30, 80, 87, 81, 86]
        case (kTrackLead2, _):         return [90, 100, 39, 30]
        case (kTrackPads, .ambient):   return [95, 50, 94, 97]
        case (kTrackPads, .kosmic):    return [95, 50, 89, 91, 94, 92, 12088]
        case (kTrackPads, .chill):     return [89, 48, 95, 97, 42, 11051, 49, 94, 92]
        case (kTrackPads, _):          return [94, 95, 92, 50]
        case (kTrackRhythm, .ambient): return [9, 8, 98, 96, 112, 5124, 8014, 108]
        case (kTrackRhythm, .chill):   return [4, 5, 17, 16, 61001, 18, 8016, 24, 26, 8028]
        case (kTrackRhythm, .kosmic):  return [39, 5, 18, 11088, 88, 1098, 11098, 11096]  // + New Age Pad, Synth Mallet, Synth Chime, Mystery Pad
        // Clavinet (GM 7) was removed in build 131: the preset is not present in Zudio.sf2, so it
        // played silent and logged "Missing MIDI patch 7".
        case (kTrackRhythm, .motorik): return [28, 29, 30, 8081, 32, 34, 8038, 84, 11088, 4]
        case (kTrackRhythm, _):        return [28, 39, 29]
        case (kTrackTexture, .chill):  return [240, 241, 251, 242, 243, 245, 250]
        case (kTrackTexture, .ambient):return [49, 92, 52, 99, 90]
        case (kTrackTexture, .kosmic): return [90, 86, 11089, 102, 96]  // + Rain
        case (kTrackTexture, .motorik): return [86, 94, 89, 99, 102, 11089, 11127, 8031, 93, 96, 11096]
        case (kTrackTexture, _):       return [86, 94, 89, 99, 102]
        case (kTrackBass, .chill):     return [35, 32, 33]
        case (kTrackBass, .ambient):   return [42, 60, 54, 62, 93]
        case (kTrackBass, .kosmic):    return [39, 87, 81, 34, 8038, 11039, 16, 89]
        case (kTrackBass, .motorik):   return [39, 87, 34, 33, 12038, 11038, 38]
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
    /// CC7 channel volume per slot, 100 meaning untouched. Keyed on the instrument NAME rather
    /// than its index, so reordering a pool cannot move a trim onto the wrong patch.
    nonisolated static func instrumentPoolVolumeCC7(trackIndex: Int, style: MusicStyle,
                                                    isChillSoho: Bool = false) -> [Int] {
        let names = instrumentPoolNames(trackIndex: trackIndex, style: style,
                                        isChillSoho: isChillSoho)
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
            // Moog, Mono Synth and Synth Bass 3 are the loudest patches in the Kosmic bass
            // pool — thick synth basses that sit well forward against Kosmic's sustained pads,
            // where the remaining patches read as background.
            case (kTrackBass,    .kosmic,  "Moog"):          return 80
            case (kTrackBass,    .kosmic,  "Mono Synth"):    return 80
            case (kTrackBass,    .kosmic,  "Synth Bass 3"):  return 80
            // Synth Chime cuts through Kosmic's sustained texture more than the other rhythm
            // patches, which are pads and organs sitting further back.
            case (kTrackRhythm,  .kosmic,  "Synth Chime"):   return 80
            case (kTrackRhythm,  .chill,   "Tonewheel"):    return 65
            // Chill audition guitar (Zack, 2026-10-15): Jazz sat under the rest of the rhythm
            // pool. 127 is the CC7 ceiling; the rest of its lift is PlaybackEngine's rhythm boost.
            case (kTrackRhythm,  .chill,   "Jazz Guitar"):   return 127
            // Funk Guitar sat on top of the rest of the band (Zack, 2026-10-15). 80 is about 4 dB down.
            case (kTrackRhythm,  .chill,   "Funk Guitar"):   return 80
            // Bowed Glass is a soft patch and sat under the rest of the Chill pad pool. 115 was
            // still too quiet, so it now takes the CC7 ceiling (Zack, 2026-10-13). Nothing more
            // is available through channel volume; a further lift would need
            // PlaybackEngine's boostBaseMultiplier, which drives the gain node past unity.
            case (kTrackPads,    .chill,   "Bowed Glass"):  return 127
            // Chill Soho Lead 2 only — base Chill's Lead 2 pool has no Synth Brass. It is the
            // loudest and brightest patch in that pool and sat over the top of Lead 1.
            case (kTrackLead2,   .chill,   "Synth Brass 1"): return 70
            // Vibraphone on Lead 2, in every Chill form — base, Blues and Soho all carry it in
            // that pool. Matched to the texture track's vibraphone: the mallet attack sits
            // forward of the reeds and brass it shares the pool with (Zack, 2026-10-12).
            case (kTrackLead2,   .chill,   "Vibraphone"):    return 75
            // Chill Soho texture only — base Chill's texture "pool" is audio textures, so no
            // released song can match this. Vibraphone's mallet attack cuts through the horn
            // punctuation far harder than the brass patches it shares the pool with (Zack,
            // 2026-10-12).
            // Cut again to 60 on 2026-10-13: at 75 the mallets still rang out over the horns.
            case (kTrackTexture, .chill,   "Vibraphone"):    return 60
            // Open trumpet is the loudest thing in the Soho texture pool — brighter than the
            // muted trumpet and higher than the trombone it shares the brass slots with (Zack,
            // 2026-10-13). A lighter cut than the mallets take: it is the pool's main voice at
            // 30% of picks and should not be buried. Base Chill's texture is audio files, not
            // instruments, so this can only match Soho.
            case (kTrackTexture, .chill,   "Trumpet"):       return 80
            default: return 100
            }
        }
    }

    /// Synchronously loads the correct instrument for every track into the playback engine.
    /// Must be called right before playback.play() at each song-load site.
    /// TrackRowView.onChange(of: defaultsResetToken) fires on the NEXT SwiftUI render cycle
    /// (deferred), so without this call the first notes play with stale/default programs.
    /// The "Instruments" log line from the programs actually loaded in the playback engine.
    /// Format:  Instruments  L1:73  L2:11  Pd:95  Ry:4  Tx:49  Bs:35  Dr:40
    private func instrumentsLogEntry(style: MusicStyle) -> GenerationLogEntry {
        // Format:  Instruments  L1:73  L2:11  Pd:95  Ry:4  Tx:49  Bs:35  Dr:40
        // Chill texture (240+) is an audio file, not a MIDI patch — shown as "audio".
        // kTrackCount=8 (includes kTrackLeadSynth=7, Kosmic-only silent doubling layer).
        let shortNames = ["L1", "L2", "Pd", "Ry", "Tx", "Bs", "Dr", "LS"]
        var parts: [String] = []
        for i in 0..<kTrackCount {
            let p = playback.loadedProgram(forTrack: i)
            // Chill audio textures are files, not MIDI patches — report by name, matching
            // the Ambient branch below. Previously skipped entirely, so a Chill song's
            // texture never appeared in the log at all.
            if i == kTrackTexture && style == .chill && songState?.chillSohoVariation != true {
                if let texFile = songState?.chillAudioTexture {
                    parts.append("Tx:\(Self.chillTextureDisplayName(texFile))")
                }
                continue
            }
            // MUST come before the isTrackSilent() skip below. An Ambient audio texture has
            // no MIDI events (the audio file replaces them), so isTrackSilent() reports it
            // silent and the Tx: entry was never emitted — the log could not show which
            // texture was playing, which made the Sept 2026 iPhone texture bug much harder
            // to diagnose than it needed to be.
            if i == kTrackTexture && style == .ambient,
               let texFile = songState?.ambientAudioTexture {
                parts.append("Tx:\(Self.ambientAudioDisplayName(texFile))")
                continue
            }
            if let s = songState, SongLogExporter.isTrackSilent(i, song: s) { continue }
            if p != 255 {   // omit tracks that weren't loaded (e.g. LeadSynth in non-Kosmic)
                parts.append("\(shortNames[i]):\(p)")
            }
        }
        return GenerationLogEntry(tag: "Instruments", description: parts.joined(separator: " "), isTitle: false)
    }

    /// The current song with its "Instruments" line rebuilt from what is playing now, for
    /// saving and sharing. The line was written only when a song loaded, so an instrument
    /// changed afterwards (⚡ REGEN, the picker, an orb gesture) was lost from the saved file
    /// and the song reopened with its old instrument (The Walled Lake Option, 2026-10-18).
    /// Replaced in place so the line keeps its position in the file's log.
    func songStateForSaving() -> SongState? {
        guard var song = songState else { return nil }
        let entry = instrumentsLogEntry(style: song.style)
        if let idx = song.generationLog.lastIndex(where: { $0.tag == "Instruments" }) {
            song.generationLog[idx] = entry
        } else {
            song.generationLog.append(entry)
        }
        songState = song
        return song
    }

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
        let isSoho = songState?.chillSohoVariation == true
        let trackNames = ["Lead 1", "Lead 2", "Pads", "Rhythm", "Texture", "Bass", "Drums"]
        var warnings: [GenerationLogEntry] = []
        for trackIndex in 0..<kTrackCount {
            let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: style, isChillSoho: isSoho)
            guard !programs.isEmpty else { continue }
            // Chill/Ambient audio texture tracks are handled by audioTexture.start() — skip MIDI load
            if trackIndex == kTrackTexture && style == .chill && songState?.chillSohoVariation != true { continue }
            if trackIndex == kTrackTexture && style == .ambient && songState?.ambientAudioTexture != nil { continue }
            // Drums always use percussion bank — no meaningful "default MIDI" concept
            if trackIndex == kTrackDrums { continue }
            let idx = instrumentOverrides[trackIndex] ?? 0
            let poolProgram = programs[min(idx, programs.count - 1)]
            let program = (trackIndex == kTrackLead2 ? lead2MirroredProgram : nil) ?? poolProgram
            playback.setProgram(program, forTrack: trackIndex, immediate: true)
            let cc7Values = Self.instrumentPoolVolumeCC7(trackIndex: trackIndex, style: style, isChillSoho: isSoho)
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
        let instrumentsEntry = instrumentsLogEntry(style: style)
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

    // Both observed so the audio texture follows every write — the toggles and the six places a
    // new song resets them. It plays outside PlaybackEngine's mixer, so engine mute misses it.
    @Published var muteState: [Bool] = Array(repeating: false, count: kTrackCount) {
        didSet { syncAudioTextureSilence() }
    }
    @Published var soloState: [Bool] = Array(repeating: false, count: kTrackCount) {
        didSet { syncAudioTextureSilence() }
    }

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
    private var autoSweepCache: (key: String, steps: Set<Int>) = ("", [])

    // MARK: - Playback engine

    let playback = PlaybackEngine()
    let audioTexture = AudioTexturePlayer()
    let nowPlaying = NowPlayingController()

    private var cancellables = Set<AnyCancellable>()
    /// Throttle for the AUDIO status-log line in onAudioInterrupted — prevents a single
    /// real-world interruption from logging twice if iOS fires the notification more than once.
    private var lastInterruptionLogAt: Date?
    #if os(iOS)
    /// Pending "playback stopped while backgrounded" check — see the `playback.$isPlaying`
    /// subscription in `init()`. Cancelled whenever playback resumes before it fires, so a
    /// normal Endless/Evolve song-to-song gap (as short as instant, up to ~500ms) never
    /// triggers a session deactivation mid-transition.
    private var backgroundedStopWorkItem: DispatchWorkItem?
    #endif
    var platformHost: ZudioPlatformHost?

    init() {
        persistedHistory = Self.loadPersistedHistory()
        // Pre-populate from persisted history so "first best" rules only fire on a true clean
        // slate (new install or after reset). A returning user with any saved songs skips them.
        stylesWithGeneratedSongs = Set(persistedHistory.map { $0.style })
        hasHadSohoSong = persistedHistory.contains { $0.displaySubstyleName == "Chill Soho" }
        preloadPersistedSongs()
        // Sleep timer arms when playback actually starts (see prepareSleepTimerForPlayback()),
        // not at app launch — a countdown with nothing playing isn't meaningful.

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
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.playback.isPlaying else { return }
            self.suspendAudioSessionIfBackgroundedAndStopped()
        }

        // Mirror image of the handler above: playback can also stop WHILE the app is
        // already backgrounded (sleep timer, natural song end with no auto-continue,
        // interruption) — a transition the didEnterBackground observer can't see, since
        // it only fires once, at the moment backgrounding itself happens. Left unhandled,
        // the session stays active and the lock screen keeps showing ⏸/■ indefinitely.
        //
        // Debounced ~1.5s (well past Evolve's fixed 500ms inter-song gap, and Endless's
        // typically-instant pre-generated resume) so an ordinary song-to-song transition
        // while backgrounded doesn't trigger a mid-transition deactivate/reactivate —
        // harmless either way since play() unconditionally reactivates, but pointless churn
        // to invite. Cancelled outright the moment playback resumes.
        playback.$isPlaying
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                guard let self else { return }
                self.backgroundedStopWorkItem?.cancel()
                guard !isPlaying else { return }
                let work = DispatchWorkItem { [weak self] in
                    guard let self, !self.playback.isPlaying,
                          UIApplication.shared.applicationState == .background else { return }
                    self.suspendAudioSessionIfBackgroundedAndStopped()
                }
                self.backgroundedStopWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
            }
            .store(in: &cancellables)
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
                self.syncTextureToPlayhead()   // same file time now falls at a different bar
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
            let soho     = self.songState?.chillSohoVariation == true
            let programs = AppState.instrumentPoolPrograms(trackIndex: trackIndex, style: style, isChillSoho: soho)
            let names    = AppState.instrumentPoolNames(trackIndex: trackIndex, style: style, isChillSoho: soho)
            let name     = zip(programs, names).first { $0.0 == program }.map(\.1) ?? "p\(program)"
            self.appendToLog([GenerationLogEntry(tag: "Error",
                description: "Missing MIDI patch \(program) \(name)", isTitle: false)])
        }
        // iOS audio interruption (another app takes focus) or headphones pulled.
        // PlaybackEngine.stop() has already fired; stop audioTexture (Chill background loop) too.
        // Logged to the status log (throttled) so a repeated real-world problem is visible after
        // the fact instead of just silently stopping playback with no trace.
        playback.onAudioInterrupted = { [weak self] reason in
            guard let self else { return }
            self.audioTexture.stop()
            let now = Date()
            if self.lastInterruptionLogAt == nil || now.timeIntervalSince(self.lastInterruptionLogAt!) > 3 {
                self.lastInterruptionLogAt = now
                self.appendToLog([GenerationLogEntry(tag: "AUDIO", description: reason)])
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

    #if os(iOS)
    // MARK: - Background audio session

    /// Pauses both engines and deactivates AVAudioSession — removes the active-audio
    /// inference that makes iOS show ⏸/■ on the lock screen even though Zudio itself has
    /// stopped. Both engines must be paused first (setActive(false) fails while either is
    /// running). Safe to call redundantly (e.g. during an interruption, which has already
    /// deactivated the session itself) — `try?` swallows the resulting no-op error.
    /// On resume, `play()` unconditionally reactivates the session and restarts the engines.
    ///
    /// Two callers: `didEnterBackgroundNotification` (background while already stopped) and
    /// the debounced `playback.$isPlaying` sink in `init()` (stopped while already
    /// backgrounded) — the two directions of the same underlying fix.
    private func suspendAudioSessionIfBackgroundedAndStopped() {
        audioTexture.pauseEngine()
        playback.pauseEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    #endif

    // MARK: - Log append helper

    // Single entry point for all statusLog mutations. Increments statusLogVersion
    // (StatusBoxView redraws on that, NOT on statusLog itself — append without it and rows
    // accumulate invisibly until something else bumps the version). Internal rather than
    // private so extensions in other files use this instead of re-implementing the invariant.
    // so StatusBoxView.onChange fires even when the net count is unchanged.
    // Trims front of log when it exceeds 600 entries (drops down to 400).
    // Using a large drop (not a 1-entry trim) ensures the count changes noticeably.
    func appendToLog(_ entries: [GenerationLogEntry]) {
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

    /// Every step of the loaded song that fires a filter sweep: the Kosmic automatic ones (see
    /// KosmicAutoSweep) plus, in Evolve on a Kosmic (not Drift) song, the start of pass 1 and
    /// pass 2. All of it is a function of the song, so the sweep fires on every pass over its bar,
    /// including after a rewind or a seek. Cached per song and Evolve phase.
    private func autoSweepSteps() -> Set<Int> {
        guard let song = songState else { return [] }
        let key = autoSweepKey(song)
        if autoSweepCache.key != key {
            var steps = Set(KosmicAutoSweep.steps(for: song))
            if playMode == .evolve, let anchor = evolveAnchorState,
               anchor.style == .kosmic, !anchor.isKosmicDrift {
                let pass1Start = (anchor.structure.outroSection?.startBar ?? anchor.frame.totalBars)
                switch evolvePhase {
                case .pass1:
                    steps.insert(pass1Start * 16)
                case .pass2, .outro:
                    steps.insert(pass1Start * 16)
                    steps.insert((pass1Start + evolvePass1Bars) * 16)
                case .inactive, .original: break
                }
            }
            autoSweepCache = (key, steps)
        }
        return autoSweepCache.steps
    }

    private func autoSweepKey(_ song: SongState) -> String {
        "\(song.globalSeed)-\(song.frame.totalBars)-\(playMode)-\(evolvePhaseToken)-\(evolvePass1Bars)"
    }

    /// Fires the global filter sweep (audio plus canvas flash) and logs it. Used by the tap-empty
    /// gesture, the Kosmic automatic sweeps and the Evolve phase changes. A trigger that lands
    /// while a sweep is still running restarts it but adds no second log line.
    func triggerFilterSweep(bar: Int? = nil) {
        let wasRunning = playback.isGlobalSweepRunning
        playback.triggerGlobalFilterSweep()
        guard playback.isPlaying, !wasRunning else { return }
        let b = bar ?? (playback.currentBar + 1)
        appendToLog([GenerationLogEntry(tag: String(format: "Bar %03d", b), description: "Filter sweep")])
    }

    private func emitStepAnnotations(upTo step: Int) {
        guard step > lastEmittedStep,
              let annotations = songState?.stepAnnotations else { return }
        var newEntries: [GenerationLogEntry] = []
        let sweepSteps = autoSweepSteps()
        for s in (lastEmittedStep + 1)...step {
            // Only a sweep that is due now; a scrub that skips over one must not replay it.
            if step - s <= 2, sweepSteps.contains(s) { triggerFilterSweep(bar: s / 16 + 1) }
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
            let clamped   = min(newOffset, max(0, totalBars - visibleBars))
            // Once clamped at the song end this stays true every step; @Published fires even for
            // an unchanged value and re-renders the whole app, so assign only on a real change.
            if clamped != visibleBarOffset { visibleBarOffset = clamped }
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
        // The curated first Soho song only stands in when nothing is overridden: a key, tempo or
        // mood override would change it, and the user asked for that override.
        let hadSoho = hasHadSohoSong || keyOverride != nil || tempoOverride != nil || moodOverride != nil
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
            let generated = SongGenerator.generate(
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
            let state = useBest ? generated : Self.withFirstSohoSong(generated, hadSoho: hadSoho)
            await MainActor.run {
                self.songState    = state
                self.generationHistory.append(state)
                if self.generationHistory.count > Self.kPersistedHistoryMax { self.generationHistory.removeFirst() }
                self.isGenerating = false
                self.visibleBarOffset = 0
                self.lastEmittedStep  = -1
                // Endless: sync selectedStyle to the rotation style that was just played,
                // discard stale pre-gen, and let preGenerateNextSong advance the counter.
                if self.playMode == .endless {
                    self.selectedStyle   = style
                    self.discardPreGeneratedSong()
                    self.preGenerateNextSong()
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
                    self.seedInstrumentOverrides(for: state, style: style)
                } else {
                    self.randomizeTwoInstruments(style: style)
                }
                self.replaceOnceOnlyInstruments(style: style)
                self.sanitiseInstruments(for: state)
                self.applyBluesPadsInstrument(for: state)
                // Snapshot the final overrides — resetEffectsToDefaults() restores from here.
                self.songInstrumentOverrides = self.instrumentOverrides
                self.sessionInstrumentOverrides[state.globalSeed] = self.instrumentOverrides
                // Persisted only now that the instruments are final. Saved before them, the entry
                // carried the previous song's instruments, and a song replayed from the Songs list
                // after a relaunch played Lead 1 on that song's sax (Zack, 2026-10-16).
                self.appendPersistedSong(from: state)
                self.saveLastUsedInstruments(style: style)
                self.songGenerationCount += 1
                self.stylesWithGeneratedSongs.insert(style)
                if state.chillSohoVariation { self.hasHadSohoSong = true }

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
                // Evolve: fresh generate resets evolution state and starts a new evolve session.
                // After the seek: startEvolveMode reads the playhead to see whether the song is
                // already in its outro, and before it the playhead was still the previous song's.
                // Generating late in a long song started the new one with no Evolve at all.
                if self.playMode == .evolve {
                    self.tearDownEvolve()
                    self.startEvolveMode(from: state)
                }
                // Configure ambient mode before defaultsResetToken fires so setEffect
                // uses the correct Ambient reverb/delay values from the start.
                self.playback.setAmbientMode(self.selectedStyle == .ambient)
                self.playback.setChillMode(self.selectedStyle == .chill, bluesVariation: state.chillBluesVariation, sohoVariation: state.chillSohoVariation)
                // Reset instruments + effects and apply them synchronously before play.
                // defaultsResetToken fires TrackRowView.onChange on the next render cycle
                // (deferred), so applyCurrentInstrumentsToPlayback() ensures the correct
                // programs are loaded before the first note fires.
                self.defaultsResetToken += 1
                self.applyCurrentInstrumentsToPlayback()
                if thenPlay || wasPlaying {
                    self.prepareSleepTimerForPlayback()
                    self.playback.play()
                    // Start ambient audio texture directly (Chill is handled via setProgram/switchTexture).
                    if state.style == .ambient, let texFile = state.ambientAudioTexture {
                        self.audioTexture.start(style: .ambient, texture: texFile,
                                                offsetSeconds: self.textureSeconds(atStep: self.playback.currentStep, in: state))
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
            // Carry the regen's step annotations (bass slides, variation bars, returns to form),
            // spliced at the same point as the events in evolve.
            let newAnnotations: [Int: [GenerationLogEntry]]
            if let bodyEnd = evolveBodyEndStep {
                newAnnotations = regen.stepAnnotations.filter { $0.key < bodyEnd }
                    .merging(current.stepAnnotations.filter { $0.key >= bodyEnd }) { a, _ in a }
            } else {
                newAnnotations = regen.stepAnnotations
            }
            var updated = current.replacingEvents(newEvents, forTrack: trackIndex, appendingLog: regenEntries,
                                                  replacingStepAnnotations: newAnnotations)
            // Keep the regen's track seed. Without it a saved file or history entry replays the
            // old seed and rebuilds the track as it was before ⚡REGEN, and bass slides (seeded
            // from this override) play the old track's slides over the new bass.
            updated.trackOverrides[trackIndex] = regen.trackOverrides[trackIndex]
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
                // Record the new track seed in the Songs list so ⏮ and relaunch replay this
                // version. Not in evolve: the playing state there is a splice of passes.
                if evolveBodyEndStep == nil,
                   let idx = self.persistedHistory.firstIndex(where: { $0.seed == updated.globalSeed }) {
                    self.persistedHistory[idx].trackOverrides = Dictionary(uniqueKeysWithValues:
                        updated.trackOverrides.map { (String($0.key), $0.value) })
                    self.savePersistedHistory()
                }
                // Restart ambient audio texture if the regen changed it; sync picker index.
                if trackIndex == kTrackTexture && updated.style == .ambient {
                    self.audioTexture.start(style: .ambient, texture: updated.ambientAudioTexture,
                                            offsetSeconds: self.textureSeconds(atStep: self.playback.currentStep, in: updated))
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
        prepareSleepTimerForPlayback()
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
            audioTexture.start(style: selectedStyle, texture: texFile,
                               offsetSeconds: textureSeconds(atStep: playback.currentStep))
        }
    }

    func stop() {
        clearSleepTimerMessage()
        cancelSleepTimerCountdown()
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

    // MARK: - Audio texture follows the song

    /// Where the audio texture should be when the playhead is at `step`: the song's saved
    /// texture offset plus the song time to that step. AudioWaveformView draws the file on the
    /// same terms, so following this keeps what plays and what the lane shows together.
    ///
    /// Before 2026-10-18 every start used the bare offset, as if at bar 1: Play mid-song, a
    /// seek, a texture switch or a tempo change left the texture somewhere other than where the
    /// lane drew it, so a loud stretch of the waveform could pass with nothing loud heard.
    private func textureSeconds(atStep step: Int, in state: SongState? = nil) -> Double {
        guard let s = state ?? songState else { return 0 }
        let offset = s.style == .ambient ? s.ambientAudioTextureOffset : s.chillAudioTextureOffset
        return Double(offset) + Double(step) * s.frame.secondsPerStep
    }

    private var textureSyncToken = 0

    /// Moves a playing texture to the playhead after a seek or tempo change. Debounced, so a
    /// drag across the lanes repositions once when it settles rather than on every move.
    private func syncTextureToPlayhead() {
        guard playback.isPlaying else { return }   // Play positions it itself
        textureSyncToken += 1
        let token = textureSyncToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, token == self.textureSyncToken, self.playback.isPlaying else { return }
            self.audioTexture.reposition(toSeconds: self.textureSeconds(atStep: self.playback.currentStep))
        }
    }

    func seekTo(step: Int) {
        playback.seek(toStep: step)
        syncTextureToPlayhead()
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

    /// Drops the pre-generated next song, or the one still being generated, and undoes its
    /// style-rotation step. Every Endless path that throws the next song away comes here.
    private func discardPreGeneratedSong() {
        preGenToken    += 1
        nextSongState   = nil
        isPreGenerating = false
        if let s = preGenAxisSnapshot {
            endlessStyleIndex   = s.index
            songsInCurrentStyle = s.inStyle
            songsInCurrentPair  = s.inPair
        }
        preGenAxisSnapshot = nil
    }

    /// Takes the pre-generated next song for playback; its style-rotation step stands.
    private func takePreGeneratedSong() -> SongState? {
        guard let next = nextSongState else { return nil }
        preGenToken       += 1
        nextSongState      = nil
        isPreGenerating    = false
        preGenAxisSnapshot = nil
        return next
    }

    private func decideNextStyle() -> MusicStyle {
        let atLeft  = endlessStyleIndex == 0
        let atRight = endlessStyleIndex == endlessStyleAxis.count - 1
        let currentPair = endlessStyleIndex < endlessStyleAxis.count / 2 ? 0 : 1   // 0 = Ambient+Chill, 1 = Kosmic+Motorik
        let shiftNow: Bool
        switch songsInCurrentStyle {
        case 1:  shiftNow = Double.random(in: 0..<1) < 0.30
        case 2:  shiftNow = Double.random(in: 0..<1) < 0.50
        default: shiftNow = true
        }
        if !shiftNow {
            songsInCurrentStyle += 1
            songsInCurrentPair  += 1   // still counts toward the pair-streak cap even without a style shift
            return endlessStyleAxis[endlessStyleIndex]
        }
        // Style-mix tuning: asymmetric per-side probabilities, chosen and verified by simulating
        // the underlying Markov chain, to hit a target steady-state mix of roughly Ambient 21% /
        // Chill 27% / Kosmic 28% / Motorik 24% (retuned 2026-10-19: Chill is stronger with Soho). Ambient/Motorik each have a two-step "escape
        // valve" (a chance to jump past their neighbor straight to Kosmic/Chill) that bounds how
        // long the walk can get stuck oscillating within one pair of adjacent styles; the
        // pair-streak cap below is a hard backstop for the rare case where the valves alone aren't
        // enough. Full derivation, the structural constraints this target runs into (Ambient can
        // never exceed Chill's share; Chill can never go below 22.5%), and the tuning history are
        // all in docs/continuous-play.md — worth reading before changing any number here.
        let crossStep: Int      // step that crosses into the other pair
        let sameStep: Int       // step that stays within the current pair
        let crossProbability: Double
        if atLeft {
            // Ambient: ~75% → Chill (adjacent), ~25% → Kosmic (escape valve, breaks ping-pong traps).
            crossStep = 2; sameStep = 1; crossProbability = 0.25
        } else if atRight {
            // Motorik: ~60% → Kosmic (adjacent), ~40% → Chill (escape valve, breaks long
            // Kosmic/Motorik-only streaks).
            crossStep = -2; sameStep = -1; crossProbability = 0.40
        } else if endlessStyleIndex < endlessStyleAxis.count / 2 {
            // Chill: ~88% → Ambient (adjacent), ~12% → Kosmic (forward valve — occasional direct
            // advance, restoring some of the original design's two-way movement).
            crossStep = 1; sameStep = -1; crossProbability = 0.12
        } else {
            // Kosmic: ~90% outward (toward Motorik, same pair), ~10% inward (toward Chill, crosses pair).
            crossStep = -1; sameStep = 1; crossProbability = 0.10
        }
        let pairStreakCap = currentPair == 0 ? 8 : 12   // smaller cap for Ambient+Chill
        let step = songsInCurrentPair >= pairStreakCap
            ? crossStep
            : (Double.random(in: 0..<1) < crossProbability ? crossStep : sameStep)
        endlessStyleIndex   = max(0, min(endlessStyleAxis.count - 1, endlessStyleIndex + step))
        songsInCurrentStyle = 1
        let newPair = endlessStyleIndex < endlessStyleAxis.count / 2 ? 0 : 1
        songsInCurrentPair  = newPair == currentPair ? songsInCurrentPair + 1 : 1
        return endlessStyleAxis[endlessStyleIndex]
    }

    private func preGenerateNextSong() {
        guard playMode == .endless, !isPreGenerating, nextSongState == nil else { return }
        isPreGenerating = true
        preGenAxisSnapshot = (endlessStyleIndex, songsInCurrentStyle, songsInCurrentPair)
        let nextStyle = decideNextStyle()
        let hadSoho = hasHadSohoSong
        preGenToken += 1
        let token = preGenToken
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let state = Self.withFirstSohoSong(SongGenerator.generate(style: nextStyle), hadSoho: hadSoho)
            await MainActor.run {
                guard self.playMode == .endless, self.preGenToken == token else { return }
                if state.chillSohoVariation { self.hasHadSohoSong = true }
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
        if let next = takePreGeneratedSong() {
            // "Up next" was already logged when pre-gen completed
            startEndlessSong(next)
        } else {
            discardPreGeneratedSong()   // a pre-gen still running would land after its turn
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
        let isSoho = songState?.chillSohoVariation == true
        var rng = SystemRandomNumberGenerator()
        for entry in Self.noRepeatInstruments where entry.style == style {
            let current = instrumentOverrides[entry.track] ?? 0
            guard current == entry.poolIndex else { continue }
            // Only swap if the previous song also used this instrument.
            guard lastUsedInstrumentIndex[entry.track]?[style] == entry.poolIndex else { continue }
            let pool = Self.instrumentPoolNames(trackIndex: entry.track, style: style, isChillSoho: isSoho)
            guard pool.count > 1 else { continue }
            // Replace from the pool this song actually allows, not the whole instrument list.
            // Drawing from the full list usually landed outside the substyle's subset, so the
            // sanitiser re-picked afterwards — and could land back on the very instrument this
            // rule exists to move away from, letting it play two songs running anyway.
            let allowed = instrumentPickPool(trackIndex: entry.track, style: style,
                                             poolCount: pool.count).filter { $0 != current }
            guard !allowed.isEmpty else { continue }
            instrumentOverrides[entry.track] = allowed[Int.random(in: 0..<allowed.count, using: &rng)]
        }
    }

    /// Brings every track's instrument inside the set its style and substyle allow, then pins the
    /// tracks the generator chose for itself. The one sanitiser, for every style.
    ///
    /// Only two instruments are re-picked per song, so the other five carry over from the
    /// previous song untouched: a Noir song could inherit a regular Motorik bass, a base Chill
    /// song a Soho guitar, a sync song a guitar where a sequencer belongs. This also covers the
    /// first song of a style, where every override defaults to index 0.
    ///
    /// There used to be seven of these — Noir, Arcade, Sync, Drift, Blues, Soho and base Chill —
    /// and they did not agree. Noir, Drift and Blues carried their own hard-coded index lists,
    /// which had drifted from the pick pools; regular Kosmic had none at all; and the Endless and
    /// Evolve paths each skipped a different subset of them (Zack, 2026-10-15: "make sure they all
    /// are consistent"). The allowed set is now written down once, in `instrumentPickPoolStatic`,
    /// and every generation path calls this.
    private func sanitiseInstruments(for state: SongState) {
        var rng = SystemRandomNumberGenerator()
        instrumentOverrides = Self.sanitisedOverrides(instrumentOverrides, for: state, using: &rng)
        syncGeneratedInstruments(for: state)
    }

    /// The pure part of `sanitiseInstruments`, static so it can be tested. An override already
    /// inside its pick pool is never touched — so a manual choice survives whenever the new song's
    /// form allows it — and one outside is re-picked from the pool, weights included.
    /// Chill's Lead 1 and Lead 2 are skipped: the generator chooses those and
    /// `syncGeneratedInstruments` pins them to the song.
    nonisolated static func sanitisedOverrides<R: RandomNumberGenerator>(
        _ overrides: [Int: Int], for state: SongState, using rng: inout R) -> [Int: Int] {
        var out = overrides
        let generatorOwned: Set<Int> = state.style == .chill ? [kTrackLead1, kTrackLead2] : []
        for track in 0..<kTrackCount where !generatorOwned.contains(track) {
            let count = instrumentPoolNames(trackIndex: track, style: state.style,
                                            isChillSoho: state.chillSohoVariation).count
            guard count > 1 else { continue }
            let allowed = instrumentPickPoolStatic(trackIndex: track, style: state.style,
                                                   poolCount: count, state: state)
            guard !allowed.isEmpty, !allowed.contains(out[track] ?? 0) else { continue }
            out[track] = allowed[Int.random(in: 0..<allowed.count, using: &rng)]
        }
        return out
    }

    /// Points the picker at what the song was generated with, for the tracks the generator chooses
    /// itself. Chill's leads drive phrasing and register at generation time and the sampler patch
    /// comes from `instrumentOverrides`, so the two must match — this used to run on the Generate
    /// path only, and an Endless or Evolve Chill song played its leads on whatever patch the
    /// previous song left behind.
    private func syncGeneratedInstruments(for state: SongState) {
        if state.style == .chill {
            let l1Pool = Self.instrumentPoolPrograms(trackIndex: kTrackLead1, style: .chill,
                                                     isChillSoho: state.chillSohoVariation)
            if let idx = l1Pool.firstIndex(of: Int(state.chillLeadInstrument.gmProgram)) {
                instrumentOverrides[kTrackLead1] = idx
            }
            let l2Pool = Self.instrumentPoolPrograms(trackIndex: kTrackLead2, style: .chill,
                                                     isChillSoho: state.chillSohoVariation)
            if let idx = l2Pool.firstIndex(of: Int(state.chillLead2Instrument.gmProgram)) {
                instrumentOverrides[kTrackLead2] = idx
            }
            // Chill Soho's texture is MIDI: its override is a real pool index, already set by
            // randomise/seed and kept in range by the sanitiser.
            if !state.chillSohoVariation {
                instrumentOverrides[kTrackTexture] = Self.chillTexturePoolIndex(forFilename: state.chillAudioTexture)
            }
        }
        // Ambient audio texture: set picker index to match the chosen file.
        if state.style == .ambient, let audioTex = state.ambientAudioTexture {
            let prog = Self.ambientAudioProgram(forFilename: audioTex)
            instrumentOverrides[kTrackTexture] = Int(prog) - 231
        }
    }

    /// Forces Lead 1 to Stereo Piano (pool index 0) for Ambient Piano songs.
    /// Called after randomizeTwoInstruments so randomisation cannot overwrite it.
    /// User can still change it manually after the song loads.
    private func applyAmbientPianoInstrument(for state: SongState) {
        // Ambient Lead 1 pool: ["Stereo Piano","Flute","Ocarina","Whistle","Brightness","Calliope Lead","Harp","Shakuhachi"]
        // Stereo Piano is at index 0 (encoded program 61001).
        //
        // The else branch is load-bearing. This used to `guard isAmbientPiano else { return }`,
        // which pinned Lead 1 to Stereo Piano for an Ambient Piano song and then never cleared
        // it. Because instrumentOverrides is snapshotted into sessionInstrumentOverrides and
        // PersistedSong, every later Ambient song inherited — and persisted — Stereo Piano on
        // Lead 1, showing as "L1:61001" in the Instruments log where the song had generated
        // something else entirely.
        guard state.style == .ambient else { return }
        if state.isAmbientPiano {
            instrumentOverrides[kTrackLead1] = 0
        } else if instrumentOverrides[kTrackLead1] == 0 {
            // Only clear a value that could have come from the piano pin. A genuine manual
            // pick of Stereo Piano on a non-piano song is indistinguishable, so this
            // deliberately resets to "unset" and lets the song's own assignment apply.
            instrumentOverrides[kTrackLead1] = nil
        }
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

    /// Assigns every track an instrument from its allowed pool, explicitly.
    ///
    /// `instrumentOverrides` is sparse: a track with no entry reads as index 0 through the
    /// `?? 0` fallback at a dozen call sites. Clearing the dictionary for the first song of a
    /// style therefore put every track on the FIRST instrument in its pool rather than on a
    /// neutral one — and because only two tracks are re-picked per song, that choice then
    /// persisted for several songs.
    ///
    /// On Motorik Lead 1 the first entry is Mono Synth, which reached 25% of Motorik Europe
    /// songs against an even share of 16.7%, roughly twice Polysynth's rate. Seeding every
    /// track removes the privilege of being first in the list; the `?? 0` fallback stays as a
    /// safety net but no longer decides what anything sounds like.
    ///
    /// Chill's Lead 1, Lead 2 and Texture are left out for the same reason
    /// `randomizeTwoInstruments` skips them: the generator picks those itself, and register and
    /// phrasing rules depend on the choice.
    private func seedInstrumentOverrides(for state: SongState, style: MusicStyle) {
        var rng = SystemRandomNumberGenerator()
        instrumentOverrides = [:]
        let generatorOwned: Set<Int> = style == .chill
            ? [kTrackLead1, kTrackLead2, kTrackTexture] : []
        for track in 0..<kTrackCount where !generatorOwned.contains(track) {
            let pool = Self.instrumentPoolNames(trackIndex: track, style: style,
                                                isChillSoho: state.chillSohoVariation)
            guard pool.count > 1 else { continue }
            let allowed = instrumentPickPool(trackIndex: track, style: style, poolCount: pool.count)
            guard !allowed.isEmpty else { continue }
            instrumentOverrides[track] = allowed[Int.random(in: 0..<allowed.count, using: &rng)]
        }
    }

    private func randomizeTwoInstruments(style: MusicStyle) {
        let isDrift = songState?.isKosmicDrift == true
        let isSoho = songState?.chillSohoVariation == true
        var rng = SystemRandomNumberGenerator()
        // Chill: Lead 1 and Lead 2 are always driven by the song's generated chillLeadInstrument /
        // chillLead2Instrument (register, phrasing rules, and register separation all depend on them).
        // Exclude them from random variation — only Pads, Rhythm, Bass, Drums vary between songs.
        // Texture is excluded because the generator already picks the audio file.
        var eligible = Self.randomizableTrackIndices.filter {
            // Chill Soho's texture is MIDI with a real pool, so it varies like any other track.
            if style == .chill { return ($0 != kTrackTexture || isSoho) && $0 != kTrackLead1 && $0 != kTrackLead2 }
            return true
        }
        var pickedCount = 0
        while pickedCount < 2, !eligible.isEmpty {
            let pos = eligible.indices.randomElement(using: &rng)!
            let trackIdx = eligible.remove(at: pos)
            let pool = Self.instrumentPoolNames(trackIndex: trackIdx, style: style, isChillSoho: isSoho)
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
        let isSoho = state.chillSohoVariation
        var rng = SystemRandomNumberGenerator()

        if isFirstForStyle {
            overrides = [:]
        } else {
            // Randomise two instruments (same logic as randomizeTwoInstruments)
            var eligible = randomizableTrackIndices.filter {
                if style == .chill { return ($0 != kTrackTexture || isSoho) && $0 != kTrackLead1 && $0 != kTrackLead2 }
                return true
            }
            var pickedCount = 0
            while pickedCount < 2, !eligible.isEmpty {
                let pos      = eligible.indices.randomElement(using: &rng)!
                let trackIdx = eligible.remove(at: pos)
                let pool     = instrumentPoolNames(trackIndex: trackIdx, style: style, isChillSoho: isSoho)
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
            let pool = instrumentPoolNames(trackIndex: entry.track, style: style, isChillSoho: isSoho)
            guard pool.count > 1 else { continue }
            var newIdx = current; var attempts = 0
            repeat { newIdx = Int.random(in: 0..<pool.count, using: &rng); attempts += 1 }
            while newIdx == current && attempts < 8
            overrides[entry.track] = newIdx
        }

        // Substyle sanitisation — the same function the live paths call.
        overrides = sanitisedOverrides(overrides, for: state, using: &rng)
        if style == .chill, state.chillBluesVariation {
            // Drawn from the Blues pads pick pool, not hard-coded indices. This read
            // `Bool.random() ? 0 : 2` with the comment "Warm Pad or String Pad"; after the pads
            // were split per Chill form those indices meant Strings Slow and Cello, and neither
            // Warm Pad nor String Pad is in the Blues pool at all (Zack, 2026-10-13).
            let padPool = instrumentPoolNames(trackIndex: kTrackPads, style: .chill)
            let padPicks = instrumentPickPoolStatic(trackIndex: kTrackPads, style: .chill,
                                                    poolCount: padPool.count, state: state)
            if !padPicks.isEmpty {
                overrides[kTrackPads] = padPicks[Int.random(in: 0..<padPicks.count, using: &rng)]
            }
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
        // Kraftwerk sync (base Motorik only) restricts its member tracks to the machine
        // sounds in each existing pool. Checked before the substyle branches because a sync
        // never fires in a Noir or Arcade song, so no substyle case can be reached from here.
        if style == .motorik,
           let syncSubset = state?.motorikSync.instrumentSubset(forTrack: trackIndex) {
            return syncSubset
        }
        if style == .motorik && trackIndex == kTrackBass {
            if state?.motorikArcadeVariation == true { return [1,3,4,5,6] }
            return state?.motorikNoirVariation == true ? [0,1,4,5] : [0,1,2,3]
        }
        if style == .motorik && trackIndex == kTrackLead1 {
            if state?.motorikArcadeVariation == true { return [0,1,6,7] }
            return state?.motorikNoirVariation == true ? [1,4,5,6,7] : [0,1,2,3,4,6]
        }
        if style == .motorik && trackIndex == kTrackLead2 {
            if state?.motorikArcadeVariation == true { return [2,5,7] }  // Arcade: Moog + Synth Lead + 5th Saw Wave
            return Array(0..<poolCount)
        }
        if style == .motorik && trackIndex == kTrackDrums {
            if state?.motorikArcadeVariation == true { return [2,3] }
            return state?.motorikNoirVariation == true ? [0,1,3] : [0,1,2]
        }
        if style == .motorik && trackIndex == kTrackRhythm {
            if state?.motorikArcadeVariation == true { return [0,6,9] }  // Arcade: Guitar Pulse + Synth Bass 3 + Electric Piano 1
            return state?.motorikNoirVariation == true ? [2,3,5,6,7] : [0,1,2,4,5,6]
        }
        if style == .motorik && trackIndex == kTrackPads {
            if state?.motorikArcadeVariation == true { return [0,1,3] }
            return Array(0..<poolCount)
        }
        if style == .motorik && trackIndex == kTrackTexture {
            // Pool: [0=Fifths Lead, 1=Halo Pad, 2=Warm Pad, 3=FX Atmosphere, 4=FX Echoes, 5=Solar Wind, 6=Interference, 7=Guitar Fdbk,
            //        8=Metal Pad, 9=Ice Rain, 10=Mystery Pad]
            if state?.motorikArcadeVariation == true { return [0, 3, 5, 6, 8, 9, 10] }  // Arcade: electronic textures only
            // Regular: Halo Pad, FX Atmosphere, FX Echoes and Solar Wind. Fifths Lead, Warm Pad,
            // Interference and Guitar Fdbk are Noir's; Metal Pad, Ice Rain and Mystery Pad (8-10)
            // were added for Arcade (Zack, 2026-10-15). This list used to be the whole pool while
            // the old Noir sanitiser swapped Noir's four straight back out, which let the Arcade
            // three through.
            return state?.motorikNoirVariation == true ? [0, 2, 3, 5, 6, 7] : [1, 3, 4, 5]
        }
        if style == .kosmic {
            let isDrift = state?.isKosmicDrift == true
            switch trackIndex {
            case kTrackLead1:   return isDrift ? [4,5,6,7]       : [0,1,2,3]
            case kTrackRhythm:  return isDrift ? [0,4,5,6,7]     : [0,1,2,3]
            case kTrackDrums:   return isDrift ? [2,3,4]         : [0,1,2]
            case kTrackTexture: return isDrift ? Array(0..<poolCount) : [0,1,2,3]
            case kTrackPads:    return isDrift ? [0,1,2,4,5,6]   : Array(0..<poolCount)
            case kTrackBass:    return isDrift ? [1,3,4,6,7]     : Array(0..<poolCount)
            default: break
            }
        }
        guard style == .chill else { return Array(0..<poolCount) }
        let isBlues = state?.chillBluesVariation == true
        let isSoho  = state?.chillSohoVariation == true
        switch trackIndex {
        case kTrackTexture where isSoho:
            // [0=Trumpet, 1=Trombone, 2=Muted Trumpet, 3=Vibraphone] — brass leads at 70% of
            // picks, as a horn section is the idiomatic voice for both the stabs and the halo;
            // Vibraphone is the colour, with Xylophone's 10% since it left (2026-10-15).
            // Filtered by poolCount: a caller that sized the pool without isChillSoho would get
            // the 7-entry audio list, so an index past its end must not be returned.
            return [0, 0, 0, 1, 1, 2, 2, 3, 3, 3].filter { $0 < poolCount }
        case kTrackBass where isSoho:
            // Chill Soho bass: [0=Fretless, 1=Acoustic, 2=Elec Bass]. Elec Bass is in the mix but
            // less often than the other two — 25% against base Chill's even 33% (Zack,
            // 2026-10-12). When it is drawn it takes Low, in both effect-default paths.
            return [0, 0, 0, 1, 1, 1, 2, 2].filter { $0 < poolCount }
        case kTrackDrums where isSoho:
            // Chill Soho drums are rim click, brushes and a soft backbeat — never the 808.
            // Pool: [0=Brush Kit, 1=808 Kit, 2=Jazz Drums]. See docs/chill-soho-plan.md.
            return [0, 2].filter { $0 < poolCount }
        // ---- Chill pads. Pool (all forms):
        //   [0=Warm Pad, 1=Strings Fast, 2=Sweep Pad, 3=Soundtrack, 4=Cello, 5=Synth Strings 5,
        //    6=Strings Slow, 7=Halo Pad, 8=Bowed Glass]
        case kTrackPads where isSoho:
            // Strings Slow 42%, Halo Pad 33%, Bowed Glass 25%. Concert Choir was tried and
            // removed: the pads are too busy a part to carry a choir, and the Texture track that
            // might have suited it occasionally is doing horn hits (Zack, 2026-10-13).
            return [6,6,6,6,6, 7,7,7,7, 8,8,8].filter { $0 < poolCount }
        case kTrackPads where isBlues:
            // Strings Fast, Cello and Synth Strings 5, evenly. Synth Strings 1 and 3, then
            // Strings Slow, were auditioned here and dropped, and Synth Strings 4 came out of the
            // pool (Zack, 2026-10-15).
            //
            // Zudio.sf2 has NO Violin, Viola, Contrabass, Tremolo Strings or Pizzicato — those GM
            // slots were stripped from GeneralUser GS in build 119.
            return [1, 4, 5].filter { $0 < poolCount }
        case kTrackPads where style == .chill:
            // Warm Pad 28%, Strings Fast 24%, Sweep Pad 24%, Soundtrack 24%. Base Chill is the
            // one Chill form where a frankly synthetic pad belongs: its beat styles include
            // electronic and St Germain.
            return [0,0,0,0,0,0,0, 1,1,1,1,1,1, 2,2,2,2,2,2, 3,3,3,3,3,3].filter { $0 < poolCount }

        // ---- Chill Lead 1. Pool (all forms):
        //   [0=Muted Trumpet, 1=Tenor Sax, 2=Alto Sax, 3=Trumpet, 4=Clarinet, 5=Flute,
        //    6=Soprano Sax, 7=Recorder]
        case kTrackLead1 where isSoho:
            // The generator's own weights (ChillMusicalFrameGenerator.sohoLeadWeights), one entry
            // per percent, so a manual randomise picks as a generated song does.
            let programs = Self.instrumentPoolPrograms(trackIndex: kTrackLead1, style: .chill, isChillSoho: true)
            return ChillMusicalFrameGenerator.sohoLeadWeights.flatMap { entry -> [Int] in
                guard let idx = programs.firstIndex(of: Int(entry.instrument.gmProgram)) else { return [] }
                return Array(repeating: idx, count: Int((entry.weight * 100).rounded()))
            }.filter { $0 < poolCount }
        case kTrackLead1 where isBlues:
            // Tenor Sax, Alto Sax, Trumpet, Clarinet — evenly, as pickLeadInstrumentBlues does.
            return [1, 2, 3, 4].filter { $0 < poolCount }
        case kTrackLead1 where style == .chill:
            // Muted Trumpet, Tenor Sax, Alto Sax, Trumpet — evenly, as pickLeadInstrument does.
            return [0, 1, 2, 3].filter { $0 < poolCount }

        // ---- Chill rhythm. Pool (all forms):
        //   [0=Rhodes, 1=Wurlitzer, 2=B3 Organ, 3=Perc Organ, 4=Stereo Piano, 5=Rock Organ,
        //    6=Tonewheel, 7=Nylon Guitar, 8=Jazz Guitar, 9=Funk Guitar]
        case kTrackRhythm where isSoho:
            // Guitar-led for now (Zack, 2026-10-15): Rhodes, Stereo Piano, Nylon, Jazz and Funk
            // Guitar at 20% each, the three guitars 60% between them. Guitar is the
            // corpus's dominant comping voice, Jazz Guitar in 8 of the 14 records and Clean Guitar
            // in 7. Wurlitzer and Tonewheel are out of Soho; B3 Organ already was, because base
            // Chill and Blues both draw it. All three stay in the shared picker.
            // Every guitar always takes tremolo — see AppState.rhythmUsesTremolo.
            return [0, 4, 7, 8, 9].filter { $0 < poolCount }
        case kTrackRhythm where style == .chill:
            // Blues is organ-led: B3, Perc Organ, Stereo Piano, Rock Organ. Base Chill favours
            // the electric pianos. Neither draws the guitars at random; both can pick them.
            return (isBlues ? [2,2,2,2,3,3,3,3,3,3,4,4,4,4,5,5,5,5,5,5]
                            : [0,0,0,1,1,1,2,2,4,4,6,6]).filter { $0 < poolCount }

        // ---- Chill Lead 2. Pool (all forms):
        //   [0=Vibraphone, 1=Flute, 2=Soprano Sax, 3=Trombone, 4=Alto Sax, 5=Tenor Sax,
        //    6=Synth Brass 1]
        case kTrackLead2 where isSoho:
            // Alto Sax, Tenor Sax, Synth Brass 1, Trombone, Vibraphone — evenly, as the generator
            // does, which then drops whichever instrument Lead 1 already has.
            return [0, 3, 4, 5, 6].filter { $0 < poolCount }
        case kTrackLead2 where style == .chill:
            // Blues has no flute. Base Chill draws all four, Vibraphone weighted up.
            return (isBlues ? [0, 2, 3] : [0,0,0,1,1,2,3,3]).filter { $0 < poolCount }
        case kTrackLead2:
            return isBlues ? [0, 1, 2] : [0,0,0,1,1,2,3,3]
        default:
            return Array(0..<poolCount)
        }
    }

    /// Weighted index pool for instrument randomisation — repeated entries increase probability.
    /// Chill kTrackRhythm: blues favours organs, regular favours Rhodes/Wurlitzer.
    /// Chill kTrackLead2:  blues excludes Flute; regular reduces Trombone and Soprano Sax.
    /// Motorik kTrackBass: Noir restricts to cold/synthetic sounds; regular restricts to organic sounds.
    /// Instance wrapper over `instrumentPickPoolStatic`, supplying the current `songState`.
    ///
    /// These two used to be separate implementations of the same tables, and they drifted in
    /// three places: Arcade Rhythm, Kosmic Drift Pads and Chill Rhythm each had an instrument
    /// added to one copy and not the other. Because both are live picking paths, the same song
    /// could get a different instrument depending on which one ran. One implementation now.
    private func instrumentPickPool(trackIndex: Int, style: MusicStyle, poolCount: Int) -> [Int] {
        Self.instrumentPickPoolStatic(trackIndex: trackIndex, style: style,
                                      poolCount: poolCount, state: songState)
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
            // Drawn from the Blues pads pick pool rather than a hard-coded index pair, so the
            // pool, the picker and this selector cannot drift apart (Zack, 2026-10-13).
            let padNames = Self.instrumentPoolNames(trackIndex: kTrackPads, style: .chill)
            let allowed = Self.instrumentPickPoolStatic(trackIndex: kTrackPads, style: .chill,
                                                        poolCount: padNames.count, state: state)
            if !allowed.isEmpty {
                var rng = SystemRandomNumberGenerator()
                instrumentOverrides[kTrackPads] = allowed[Int.random(in: 0..<allowed.count, using: &rng)]
            }
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
        discardPreGeneratedSong()   // already taken or discarded by the caller; this clears any stray run
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
            self.sanitiseInstruments(for: state)
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
        let hadSoho = hasHadSohoSong
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = Self.withFirstSohoSong(SongGenerator.generate(style: nextStyle), hadSoho: hadSoho)
            await MainActor.run {
                guard self.endlessTransitionToken == transitionToken else { return }
                if state.chillSohoVariation { self.hasHadSohoSong = true }
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
        if let next = takePreGeneratedSong() {
            startEndlessSong(next)
        } else {
            discardPreGeneratedSong()   // a pre-gen still running would land after its turn
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
        evolvePassInFlight       = false
        evolveNextSongInFlight   = false
        evolvePassPending        = nil
        evolveNextSongPending    = false
        evolveSessionToken      += 1
        evolveNextSongShouldLog  = false
        evolveNextSongLogged     = false
        evolveInstrumentsChanged = false
        evolvePhaseToken        += 1   // ensure scrollbar recreates even if next song has same totalBars
    }

    /// Switches each fresh track to a different instrument and sends a program change immediately.
    /// Chill's leads take the instruments `pass` was generated for; every other track draws from
    /// its substyle's own pick list.
    ///
    /// This drew from the whole style pool until 2026-10-19. Since the Chill pool became the
    /// superset of all three forms (2026-10-13), that put Recorder, Flute and Synth Brass on the
    /// leads of a Blues song, a Sweep Pad and a Jazz Guitar in its pass 2, and played leads
    /// written for an alto sax's register on whatever patch was drawn.
    private func switchEvolveInstruments(freshTracks: [Int], pass: SongState) {
        guard let anchor = evolveAnchorState else { return }
        let style = anchor.style
        let isSoho = anchor.chillSohoVariation
        var entries: [GenerationLogEntry] = []
        for trackIndex in freshTracks {
            let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: style, isChillSoho: isSoho)
            guard programs.count > 1 else { continue }
            let currentIdx = instrumentOverrides[trackIndex] ?? 0
            let picked: Int?
            if style == .chill && (trackIndex == kTrackLead1 || trackIndex == kTrackLead2) {
                let inst = trackIndex == kTrackLead1 ? pass.chillLeadInstrument : pass.chillLead2Instrument
                picked = programs.firstIndex(of: Int(inst.gmProgram))
            } else {
                picked = evolvePickIndex(trackIndex, in: anchor, excluding: [currentIdx])
            }
            guard let newIdx = picked, newIdx != currentIdx else { continue }
            instrumentOverrides[trackIndex] = newIdx
            setProgram(programs[newIdx], forTrack: trackIndex)
            let tName = trackIndex < kTrackNames.count ? kTrackNames[trackIndex] : "Track \(trackIndex)"
            let names = Self.instrumentPoolNames(trackIndex: trackIndex, style: style, isChillSoho: isSoho)
            let iName = newIdx < names.count ? names[newIdx] : "prog \(programs[newIdx])"
            entries.append(GenerationLogEntry(tag: "Instrument", description: "\(tName) \(iName)", isTitle: false))
        }
        instrumentChangeToken += 1
        if !entries.isEmpty {
            appendToLog(entries)
            evolveInstrumentsChanged = true
        }
    }

    /// A random pool index for `trackIndex` from the substyle's own pick list for `song`, other
    /// than those in `excluding`; nil when the list offers no other.
    private func evolvePickIndex(_ trackIndex: Int, in song: SongState, excluding: Set<Int>) -> Int? {
        let count = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: song.style,
                                                isChillSoho: song.chillSohoVariation).count
        guard count > 1 else { return nil }
        return Self.instrumentPickPoolStatic(trackIndex: trackIndex, style: song.style,
                                             poolCount: count, state: song)
            .filter { !excluding.contains($0) }
            .randomElement()
    }

    /// Chill only: the Lead 1 and Lead 2 instruments Evolve pass 1 will switch to, each from the
    /// substyle's own pick list and different from the one playing now. Lead 2 never takes Lead
    /// 1's instrument, as in generation. Chosen before the pass is built, so its leads are written
    /// for these instruments.
    private func evolveLeadInstruments(for anchor: SongState) -> (ChillLeadInstrument, ChillLeadInstrument)? {
        guard anchor.style == .chill else { return nil }
        let isSoho     = anchor.chillSohoVariation
        let l1Programs = Self.instrumentPoolPrograms(trackIndex: kTrackLead1, style: .chill, isChillSoho: isSoho)
        let l2Programs = Self.instrumentPoolPrograms(trackIndex: kTrackLead2, style: .chill, isChillSoho: isSoho)
        func instrument(_ program: Int) -> ChillLeadInstrument? {
            ChillLeadInstrument.allCases.first { Int($0.gmProgram) == program }
        }
        let l1 = evolvePickIndex(kTrackLead1, in: anchor, excluding: [instrumentOverrides[kTrackLead1] ?? 0])
            .flatMap { instrument(l1Programs[$0]) } ?? anchor.chillLeadInstrument
        var l2Excluded: Set<Int> = [instrumentOverrides[kTrackLead2] ?? 0]
        if let i = l2Programs.firstIndex(of: Int(l1.gmProgram)) { l2Excluded.insert(i) }
        let l2 = evolvePickIndex(kTrackLead2, in: anchor, excluding: l2Excluded)
            .flatMap { instrument(l2Programs[$0]) } ?? anchor.chillLead2Instrument
        return (l1, l2)
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
    // leadInstruments (Chill pass 1): the instruments the leads are regenerated for, and which the
    // returned state carries so the switch can apply them.
    private nonisolated static func buildPassState(anchor: SongState, freshTracks: [Int], passBars: Int,
                                                   leadInstruments: (ChillLeadInstrument, ChillLeadInstrument)? = nil) -> SongState {
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
        // Lead 2 is written around Lead 1 (Chill fills Lead 1's gaps; Motorik answers it), and
        // regenerateTrack reads Lead 1 from the state it is given. Pass 1 regenerates both, so
        // once Lead 1 is done its new events go into the source for the tracks after it.
        // Built against the anchor's Lead 1, Lead 2 played over the new one in 41-42% of its
        // notes in Chill and Motorik, against 20-24% in a generated song (measured 2026-10-18).
        var source = leadInstruments.map { anchor.withChillLeadInstruments($0.0, $0.1) } ?? anchor
        var fullTracks = anchor.trackEvents   // whole-song events per track, regenerated ones swapped in
        for idx in freshTracks {
            let anchorHadContent = !anchor.trackEvents[idx].isEmpty
            var regen      = SongGenerator.regenerateTrack(idx, songState: source, passBodyBars: passBars)
            var newEntries = Array(regen.generationLog.dropFirst(baseLogCount))
            // Retry until: (a) the regen brings at least one rule the anchor did not use AND
            //              (b) there are body events (not just intro motif) within the pass window.
            //              Solo rules (MOT-LD1-007/008) are completely silent in body bars outside
            //              their solo window. passBodyBars constrains the solo to land within the
            //              pass window, but we still retry if only intro motif notes exist.
            //
            // (a) used to demand that EVERY rule be new. A track that logs two rules (Chill
            // Rhythm's A and B comping modes) rarely managed that, and Blues Lead 2 (CHL-LD2-001)
            // and Blues Pads (CHL-PAD-004) have a single rule, so no attempt could ever pass:
            // every Blues pass ran all four full regenerations and kept the last. A fresh seed
            // is the only change available on a fixed rule, so those skip (a).
            let ruleIsFixed = anchor.chillBluesVariation && (idx == kTrackLead2 || idx == kTrackPads)
            var attempts = 1
            while attempts < 4 {
                let newRuleIDs = Set(newEntries.map(\.tag).filter(isRuleID))
                let eventsEmpty = anchorHadContent &&
                    !regen.trackEvents[idx].contains { $0.stepIndex >= bodyStartStep && $0.stepIndex < bodyStartStep + cutoff }
                let bringsNewRule = ruleIsFixed || newRuleIDs.isEmpty || !newRuleIDs.isSubset(of: anchorRuleIDs)
                if bringsNewRule && !eventsEmpty { break }
                regen      = SongGenerator.regenerateTrack(idx, songState: source, passBodyBars: passBars)
                newEntries = Array(regen.generationLog.dropFirst(baseLogCount))
                attempts  += 1
            }
            if idx == kTrackLead1 {
                source = source.replacingEvents(regen.trackEvents[kTrackLead1], forTrack: kTrackLead1)
            }
            fullTracks[idx] = regen.trackEvents[idx]
            events[idx] = regen.trackEvents[idx]
                .filter { $0.stepIndex >= bodyStartStep && $0.stepIndex < bodyStartStep + cutoff }
                .map { MIDIEvent(stepIndex: $0.stepIndex - bodyStartStep, note: $0.note,
                                 velocity: $0.velocity, durationSteps: $0.durationSteps) }
            regenLog.append(contentsOf: newEntries)
        }
        // A song with no intro opens on a cold-start pickup: its first bar is drums alone (Blues:
        // half a bar of silence, then a fill; Soho: a drum bar) and the band enters on the next
        // downbeat. A pass copies the body from its first bar, so every pass replayed that pickup
        // mid-song and the whole band dropped out for a half or a whole bar at both Evolve
        // points (Zack, 2026-10-19). The pass takes that bar from one chord cycle later instead,
        // where the band plays the same chord in full. The leads keep their own first bar: they
        // are phrases, and a lead entering a bar in is natural.
        if let cycle = pickupStandInOffset(anchor) {
            let from = bodyStartStep + cycle * 16
            for t in 0..<events.count where t != kTrackLead1 && t != kTrackLead2 && t < fullTracks.count {
                let standIn = fullTracks[t]
                    .filter { $0.stepIndex >= from && $0.stepIndex < from + 16 }
                    .map { e -> MIDIEvent in
                        let step = e.stepIndex - from
                        // Clipped at the bar line, so a held note cannot overlap the next bar's
                        // own notes; a same-pitch note-off there would cut them short.
                        return MIDIEvent(stepIndex: step, note: e.note, velocity: e.velocity,
                                         durationSteps: Swift.min(e.durationSteps, 16 - step))
                    }
                events[t] = (standIn + events[t].filter { $0.stepIndex >= 16 })
                    .sorted { $0.stepIndex < $1.stepIndex }
            }
        }
        let passFrame = anchor.frame.withTotalBars(passBars)
        let minStruct = SongStructure(sections: [], chordPlan: [],
                                      introStyle: anchor.structure.introStyle,
                                      outroStyle: anchor.structure.outroStyle)
        return SongState(frame: passFrame, structure: minStruct,
                         trackEvents: events, generationLog: regenLog, stepAnnotations: [:],
                         copyingStyleFieldsFrom: source)
    }

    /// For a song whose first bar is a cold-start pickup (no intro, so the pickup is the body's
    /// first bar), how many bars later the same place in the chord cycle comes round: the bar an
    /// Evolve pass plays in place of the pickup. nil for any other song.
    ///
    /// The cycle is the shortest multiple of 4 bars, up to half the first section, that the
    /// section's chords repeat at: over the whole section if any length does (a 16-bar blues
    /// gives 16, so the stand-in is the second chorus's first bar), otherwise over one cycle (a
    /// Soho loop whose turnaround breaks the repeat late in the section). nil if neither holds,
    /// and the pass keeps the pickup as before.
    nonisolated static func pickupStandInOffset(_ song: SongState) -> Int? {
        let s = song.structure
        guard s.introSection == nil, case .coldStart = s.introStyle,
              let first = s.sections.first, first.startBar == 0, first.lengthBars >= 8 else { return nil }
        func chord(_ bar: Int) -> String? {
            s.chordWindow(atBar: bar).map { "\($0.chordRoot) \($0.chordType.rawValue)" }
        }
        let n = first.lengthBars
        // At most half the section, so the repeat is tested over at least one whole cycle.
        let cycles = Array(stride(from: 4, through: n / 2, by: 4))
        if let p = cycles.first(where: { p in (0..<(n - p)).allSatisfy { chord($0) == chord($0 + p) } }) {
            return p
        }
        return cycles.first { p in (0..<p).allSatisfy { chord($0) == chord($0 + p) } }
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
        // The anchor's log, not an empty one. Playback reads the song's bass rule from it, so
        // with an empty log the Chill Blues behind-the-beat feel switched off at pass 1; and a
        // song saved mid-Evolve was written with no title line and no rules (2026-10-19).
        return SongState(frame: extFrame, structure: minStruct,
                         trackEvents: tracks, generationLog: anchor.generationLog,
                         stepAnnotations: extAnnotations,
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
        guard let anchor = evolveAnchorState, !evolvePassInFlight else { return }
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
            evolvePassInFlight = true
            let tokenAtStart = evolvePhaseToken   // stale-Task guard — see note below
            let session      = evolveSessionToken
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let state = Self.buildAmbientModalShiftPass(anchor: anchor, mode: targetMode, passBars: passBars)
                await MainActor.run {
                    // tearDownEvolve() clears the flag itself; any other discard must clear it
                    // here, or no pass could ever be built again this session.
                    guard self.evolveSessionToken == session else { return }
                    self.evolvePassInFlight = false
                    // If the phase moved since this Task was launched, this result belongs to a
                    // now-abandoned phase. Applying it would corrupt songState and cause
                    // Next-Track oscillation.
                    guard self.playMode == .evolve,
                          self.evolvePhaseToken == tokenAtStart else { return }
                    if pass == 1 { self.evolvePass1State = state } else { self.evolvePass2State = state }
                    if self.switchToPendingPass(pass, state) { return }
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
        // Chill pass 1: the lead instruments are chosen now, so the leads are written for them.
        let leadInstruments = pass == 1 ? evolveLeadInstruments(for: anchor) : nil
        evolvePassInFlight = true
        let tokenAtStart = evolvePhaseToken   // stale-Task guard
        let session      = evolveSessionToken
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = Self.buildPassState(anchor: anchor, freshTracks: freshTracks, passBars: passBars,
                                            leadInstruments: leadInstruments)
            await MainActor.run {
                guard self.evolveSessionToken == session else { return }
                self.evolvePassInFlight = false
                // Stale-Task guard: if the phase moved since this Task launched, the token has
                // changed. Applying a stale result here would overwrite songState with an
                // extended state built from the old anchor — causing Next-Track to oscillate
                // between two history entries instead of generating a new song.
                guard self.playMode == .evolve,
                      self.evolvePhaseToken == tokenAtStart else { return }
                if pass == 1 {
                    self.evolvePass1State = state
                } else {
                    self.evolvePass2State = state
                }
                if self.switchToPendingPass(pass, state) { return }
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
        guard let anchor = evolveAnchorState, !evolveNextSongInFlight,
              evolveNextSongState == nil else { return }
        evolveNextSongInFlight = true
        let style        = selectedStyle   // use the currently selected style, not the anchor's
        evolveNextSongPendingStyle = style
        let styleChanged = style != (anchor.style)
        // If style changed, generate fresh — no BPM, mood, key or scale from the previous song.
        let mood:  Mood? = styleChanged ? nil : evolveMoodAnchor
        let tempo: Int?  = styleChanged ? nil : evolveTempoAnchor
        let session = evolveSessionToken   // stale-Task guard: the session, not the phase
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let newTempo: Int? = tempo.map { max(20, min(200, $0 + Int.random(in: -5...5))) }
            let state = SongGenerator.generate(tempoOverride: newTempo, moodOverride: mood,
                                               style: style)
            await MainActor.run {
                guard self.playMode == .evolve,
                      self.evolveSessionToken == session else { return }
                self.evolveNextSongInFlight = false
                // The song is already due: start it now (transitionToEvolveNextSong waited).
                if self.evolveNextSongPending {
                    self.evolveNextSongPending = false
                    self.evolveNextSongState   = state
                    self.transitionToEvolveNextSong()
                    return
                }
                self.evolveNextSongState    = state
                if self.evolveNextSongShouldLog && !self.evolveNextSongLogged {
                    self.evolveNextSongShouldLog = false
                    self.evolveNextSongLogged    = true
                }
            }
        }
    }

    /// If `pass` was due before its content was ready, switches to it now. Returns true if it did.
    private func switchToPendingPass(_ pass: Int, _ state: SongState) -> Bool {
        guard evolvePassPending == pass else { return false }
        evolvePassPending = nil
        if pass == 1, evolvePhase == .original { doSwitchToEvolvePass1(state); return true }
        if pass == 2, evolvePhase == .pass1    { doSwitchToEvolvePass2(state); return true }
        return false
    }

    private func handleEvolveOutroStart() {
        guard evolvePhase == .original else { return }
        if let pass1 = evolvePass1State {
            doSwitchToEvolvePass1(pass1)
        } else {
            // Not ready: switch when the build lands. Starts it if none is in flight (a no-op if
            // one is), rather than starting a second identical build alongside it.
            evolvePassPending = 1
            preGeneratePassContent(pass: 1)
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
        // Restart playback before switching instruments. On iOS setProgram loads the patch
        // synchronously on the main thread, and the pass waited behind both loads: the outro's
        // cold-stop hit rang through the gap before the pass began (2026-10-19). The Mac defers
        // its loads by 80 ms, so it already ran in this order in effect.
        playback.loadAndPlay(state: extended, fromStep: outroStartBar * 16)
        if anchor.isAmbientPiano {
            let comp   = anchor.frame.mode.complementaryMode
            let barTag = String(format: "Bar %03d", outroStartBar + 1)
            appendToLog([GenerationLogEntry(tag: barTag,
                description: "Shifting to \(anchor.frame.key) \(comp.rawValue) (\(evolvePass1Bars) bars)",
                isTitle: false)])
        } else {
            switchEvolveInstruments(freshTracks: [kTrackLead1, kTrackLead2], pass: pass1)
            appendToLog(pass1.generationLog)
        }
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
        // Restart first, then switch instruments — see doSwitchToEvolvePass1. Here the gap was
        // pure silence: pass 1 has already ended, so nothing played until both loads finished.
        playback.loadAndPlay(state: extended, fromStep: pass2StartBar * 16)
        if anchor.isAmbientPiano {
            let barTag = String(format: "Bar %03d", pass2StartBar + 1)
            appendToLog([GenerationLogEntry(tag: barTag,
                description: "Back to \(anchor.frame.key) \(anchor.frame.mode.rawValue) (\(evolvePass2Bars) bars)",
                isTitle: false)])
        } else {
            switchEvolveInstruments(freshTracks: [kTrackPads, kTrackRhythm], pass: pass2)
            appendToLog(pass2.generationLog)
        }
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
                // Not ready: as for pass 1. This also keeps Ambient Piano on its modal-shift
                // pass; the old fallback built a regular pads-and-rhythm pass for it.
                evolvePassPending = 2
                preGeneratePassContent(pass: 2)
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
            evolveNextSongLogged  = false
        }
        // Still being generated for the right style: wait for it rather than generating another.
        if evolveNextSongState == nil, evolveNextSongInFlight,
           evolveNextSongPendingStyle == selectedStyle {
            evolveNextSongPending = true
            return
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
        sanitiseInstruments(for: state)
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
        configurePlaybackStyle(for: state)
        // load() must come before setAmbientMode/setChillMode so PlaybackEngine.songState
        // is current when those methods check state fields like chillBluesVariation.
        playback.load(state)
        playback.seek(toStep: 0)
        playback.setAmbientMode(state.style == .ambient)
        playback.setChillMode(state.style == .chill, bluesVariation: state.chillBluesVariation, sohoVariation: state.chillSohoVariation)
        defaultsResetToken += 1
        applyCurrentInstrumentsToPlayback()
        if thenPlay {
            prepareSleepTimerForPlayback()
            playback.play()
            let texFile2   = state.style == .ambient ? state.ambientAudioTexture : state.chillAudioTexture
            audioTexture.start(style: state.style, texture: texFile2,
                               offsetSeconds: textureSeconds(atStep: playback.currentStep, in: state))
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
        syncTextureToPlayhead()

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
        guard let song = songStateForSaving() else { return nil }
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
        guard let song = songStateForSaving() else { return }
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
        var loadedBluesVariation:   Bool    = false
        var loadedSohoVariation:    Bool    = false
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
                // Falls back to the first word so a file that ever carries a substyle name
                // here ("Motorik Europe") still resolves to its base style rather than Kosmic.
                let val = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                style = MusicStyle(rawValue: val)
                    ?? MusicStyle(rawValue: val.components(separatedBy: " ").first ?? "")
                    ?? .kosmic
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
            } else if trimmed.hasPrefix("Blues Variation:") {
                loadedBluesVariation = true
            } else if trimmed.hasPrefix("Soho Variation:") {
                loadedSohoVariation = true
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
                    // Soho Variation: sits in the header above this line, so it is already known.
                    let pool = Self.instrumentPoolPrograms(trackIndex: trackIdx, style: style,
                                                           isChillSoho: loadedSohoVariation)
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
        let loadBlues         = loadedBluesVariation
        let loadSoho          = loadedSohoVariation
        let loadedInstOverrides = loadedInstrumentOverrides
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var state = Self.regenerateSong(seed: seed, keyOverride: loadKey, tempoOverride: loadTempo,
                                            moodOverride: loadMood, style: style, forced: loadForced,
                                            trackOverrides: overrides,
                                            forceBlues: loadBlues, forceSoho: loadSoho,
                                            // A Chill file without either line was saved as base Chill.
                                            forbidSoho: style == .chill && !loadBlues && !loadSoho)
            await MainActor.run {
                self.selectedStyle    = style
                self.keyOverride      = loadKey
                self.tempoOverride    = loadTempo
                self.moodOverride     = loadMood
                if !loadTitle.isEmpty { state.title = loadTitle }
                self.songState        = state
                self.savedSongSeed    = state.globalSeed  // loaded from file → mark as saved
                self.generationHistory.append(state)
                if self.generationHistory.count > Self.kPersistedHistoryMax { self.generationHistory.removeFirst() }
                self.isGenerating     = false
                self.visibleBarOffset = 0
                self.lastEmittedStep  = -1
                self.instrumentOverrides = loadedInstOverrides
                self.applyLoadedInstruments(for: state)   // texture positions included
                // applyLoadedInstruments pins the Chill leads to the generator's instruments.
                // A file records what was actually playing, so a lead changed before saving
                // (⚡ REGEN, the picker) comes back as saved, not as first generated.
                if style == .chill {
                    for t in [kTrackLead1, kTrackLead2] {
                        if let idx = loadedInstOverrides[t] { self.instrumentOverrides[t] = idx }
                    }
                    self.sessionInstrumentOverrides[state.globalSeed] = self.instrumentOverrides
                }
                self.appendPersistedSong(from: state)   // after the instruments, as in generateNew
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
                self.configurePlaybackStyle(for: state)
                self.playback.load(state)
                self.playback.seek(toStep: 0)
                self.playback.setAmbientMode(style == .ambient)
                self.playback.setChillMode(style == .chill, bluesVariation: state.chillBluesVariation, sohoVariation: state.chillSohoVariation)
                self.defaultsResetToken += 1
                self.applyCurrentInstrumentsToPlayback()
                if wasPlaying {
                    self.prepareSleepTimerForPlayback()
                    self.playback.play()
                }
                // Evolve: start a session for this song, as every other load path does. This one
                // left the previous song's session running, so at this song's outro Evolve
                // switched to the previous song's pass 1 — its drums, bass and title (2026-10-19).
                if self.playMode == .evolve { self.tearDownEvolve(); self.startEvolveMode(from: state) }
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
        // Chill Soho's texture is MIDI, so its programs fall through to the normal sampler path.
        if trackIndex == kTrackTexture && selectedStyle == .chill && songState?.chillSohoVariation != true {
            let filename = Self.chillTextureFilename(forProgram: program)
            songState = songState?.withChillAudioTexture(filename)
            if playback.isPlaying {
                audioTexture.switchTexture(filename, offsetSeconds: textureSeconds(atStep: playback.currentStep))
            }
            return
        }
        // Ambient texture track uses pseudo-programs 231–237 that map to audio filenames.
        if trackIndex == kTrackTexture && selectedStyle == .ambient,
           let filename = Self.ambientAudioFilename(forProgram: program) {
            let offset = songState?.ambientAudioTextureOffset ?? 0
            songState = songState?.withAmbientAudioTexture(filename, offset: offset)
            if playback.isPlaying {
                audioTexture.start(style: .ambient, texture: filename,
                                   offsetSeconds: textureSeconds(atStep: playback.currentStep))
            }
            return
        }
        playback.setProgram(program, forTrack: trackIndex)
        let style = selectedStyle
        let isDrift = songState?.isKosmicDrift == true
        let isSoho = songState?.chillSohoVariation == true
        let poolPrograms = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: style, isChillSoho: isSoho)
        if let poolIdx = poolPrograms.firstIndex(of: program) {
            let cc7Values = Self.instrumentPoolVolumeCC7(trackIndex: trackIndex, style: style, isChillSoho: isSoho)
            let cc7 = poolIdx < cc7Values.count ? cc7Values[poolIdx] : 100
            playback.setChannelVolume(cc7, forTrack: trackIndex)
            recordInstrument(poolIdx, forTrack: trackIndex, style: style)
        }
    }

    /// Records an instrument change against the current song, so ⏮ / ⏭ and the Songs list
    /// bring back what was playing rather than what the song first loaded with. Every
    /// instrument change (picker, ⚡, orb gestures, Evolve) reaches setProgram; the Mac picker
    /// did not even update instrumentOverrides. Skipped when the style picker shows another
    /// style than the loaded song, where the pool index would belong to the wrong pool.
    private func recordInstrument(_ poolIdx: Int, forTrack trackIndex: Int, style: MusicStyle) {
        guard let song = songState, song.style == style else { return }
        if instrumentOverrides[trackIndex] != poolIdx { instrumentOverrides[trackIndex] = poolIdx }
        sessionInstrumentOverrides[song.globalSeed] = instrumentOverrides
        sessionManualInstruments[song.globalSeed, default: [:]][trackIndex] = poolIdx
        guard let idx = persistedHistory.firstIndex(where: { $0.seed == song.globalSeed }) else { return }
        let key = String(trackIndex)
        guard persistedHistory[idx].manualInstruments?[key] != poolIdx else { return }
        persistedHistory[idx].manualInstruments = (persistedHistory[idx].manualInstruments ?? [:])
            .merging([key: poolIdx]) { _, new in new }
        persistedHistory[idx].instrumentOverrides = Dictionary(uniqueKeysWithValues:
            instrumentOverrides.map { (String($0.key), $0.value) })
        savePersistedHistory()
    }

    /// Re-applies the user's instrument changes for `seed` after a reload has pinned the
    /// song's generated instruments (applyLoadedInstruments).
    private func applyManualInstruments(seed: UInt64) {
        let manual = sessionManualInstruments[seed]
            ?? persistedHistory.first(where: { $0.seed == seed })?.decodedManualInstruments ?? [:]
        guard !manual.isEmpty else { return }
        for (track, idx) in manual { instrumentOverrides[track] = idx }
        sessionInstrumentOverrides[seed] = instrumentOverrides
    }

    /// Maps a Chill texture pseudo-program (240–250) to an M4A filename.
    nonisolated static func chillTextureFilename(forProgram program: Int) -> String? {
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
    nonisolated static func chillTextureProgram(forFilename filename: String?) -> UInt8 {
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

    /// Recovers a song's per-track instrument assignment from its own generation log.
    ///
    /// Instrument picks use SystemRandomNumberGenerator (randomizeTwoInstruments), so they
    /// cannot be re-derived from the song seed — they have to be remembered. They were only
    /// ever held in sessionInstrumentOverrides (session-scoped) and PersistedSong, so a
    /// cache miss silently fell back to pool index 0 for every track: an Ambient song would
    /// reload as "L1:61001 L2:46 Pd:95 Bs:42" (all index 0) instead of what it generated.
    ///
    /// The assignment is already durably recorded: applyCurrentInstrumentsToPlayback() writes
    /// an "Instruments" entry into songState.generationLog, which SongLogExporter saves into
    /// the .zudio file. Parsing it back makes the assignment survive reloads AND file loads
    /// without changing SongState or the save format.
    ///
    /// Format: "L1:73 L2:99 Pd:94 Tx:Long Lake Bs:42". Tx: is a texture NAME, not a program,
    /// and is handled separately by the ambient/chill texture paths — skipped here.
    static func instrumentOverridesFromLog(_ state: SongState) -> [Int: Int] {
        guard let entry = state.generationLog.last(where: { $0.tag == "Instruments" }) else { return [:] }
        let shortNames = ["L1", "L2", "Pd", "Ry", "Tx", "Bs", "Dr", "LS"]
        let isDrift = state.isKosmicDrift
        let isSoho = state.chillSohoVariation
        var result: [Int: Int] = [:]
        for token in entry.description.split(separator: " ") {
            let parts = token.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  let trackIndex = shortNames.firstIndex(of: String(parts[0])),
                  trackIndex != kTrackTexture,                 // texture is a name, not a program
                  let program = Int(parts[1]) else { continue }
            let pool = instrumentPoolPrograms(trackIndex: trackIndex, style: state.style, isChillSoho: isSoho)
            if let idx = pool.firstIndex(of: program) { result[trackIndex] = idx }
        }
        return result
    }

    /// Maps a Chill audio texture filename to a short display name.
    /// Mirrors ambientAudioDisplayName so both styles log their texture the same way.
    /// Display name for a Chill audio texture: the picker's own pool name, so the picker, the
    /// Instruments line and the generation log all spell it the same way. They used to give three
    /// spellings of one texture — "Another pub", "Another Pub" and "another-pub".
    nonisolated static func chillTextureDisplayName(_ filename: String) -> String {
        let names = instrumentPoolNames(trackIndex: kTrackTexture, style: .chill)
        let idx   = chillTexturePoolIndex(forFilename: filename)
        return idx > 0 && idx < names.count ? names[idx] : "Audio"
    }

    /// Picker position for a Chill audio texture. The picker reads `instrumentOverrides` as a
    /// POSITION in the pool, but the pool's pseudo-programs are not contiguous — "Another pub" is
    /// 251 at position 2 — so the old `prog - 240` was right for only four of the seven textures:
    /// Another pub showed as Vinyl crackle, Bar sounds as Another pub, City at night as Bar sounds,
    /// and because the picker re-applies its selection on generate, the wrong one could play.
    nonisolated static func chillTexturePoolIndex(forFilename filename: String?) -> Int {
        let prog = Int(chillTextureProgram(forFilename: filename))
        return instrumentPoolPrograms(trackIndex: kTrackTexture, style: .chill).firstIndex(of: prog) ?? 0
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
        case "long_lake_loons.m4a": return "Long Lake"
        default:                  return "Audio"
        }
    }

    /// Maps an Ambient audio texture pseudo-program (231–237) to an M4A filename.
    static func ambientAudioFilename(forProgram program: Int) -> String? {
        switch program {
        case 231: return "light_rain.m4a"
        case 232: return "rain-and-thunder.m4a"
        case 233: return "ocean_waves.m4a"
        case 234: return "zen-bells.m4a"
        case 235: return "wind-stoorm.m4a"
        case 236: return "desert-winds.m4a"
        case 237: return "long_lake_loons.m4a"
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
        case "long_lake_loons.m4a": return 237
        default:                 return 231
        }
    }

    func setEffect(_ effect: TrackEffect, enabled: Bool, forTrack trackIndex: Int) {
        // Chill texture track effects are routed to AudioTexturePlayer's own effect chain.
        // Chill Soho's texture is a MIDI sampler, so its effects go to the engine like any track.
        if trackIndex == kTrackTexture && selectedStyle == .chill && songState?.chillSohoVariation != true {
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

    /// AudioTexturePlayer (the Chill café loops and Ambient audio textures) is outside
    /// PlaybackEngine's mute graph, so it is silenced here: when the Texture track is muted, or
    /// another track is soloed and Texture is not.
    private func syncAudioTextureSilence() {
        guard muteState.count > kTrackTexture, soloState.count > kTrackTexture else { return }
        let soloedOut = soloState.contains(true) && !soloState[kTrackTexture]
        audioTexture.setSilenced(muteState[kTrackTexture] || soloedOut)
    }

    // MARK: - Solo visual helper

    var isAnySolo: Bool { soloState.contains(true) }

    func isEffectivelyMuted(_ trackIndex: Int) -> Bool {
        isAnySolo && !soloState[trackIndex]
    }

    // MARK: - Phone player gesture helpers

    /// Returns the current MIDI program number for a track, using instrumentOverrides if set.
    func currentInstrument(forTrack trackIndex: Int) -> Int {
        let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: selectedStyle,
                                                   isChillSoho: songState?.chillSohoVariation == true)
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
        let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: style,
                                                   isChillSoho: songState?.chillSohoVariation == true)
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
        if trackIndex == kTrackRhythm,
           songState?.motorikNoirRhythmDistortion == true {
            setEffect(.distortion, enabled: ![2, 4].contains(newIdx), forTrack: trackIndex)
        }
        instrumentChangeToken += 1
        triggerVisualizerFlash(trackIndex: trackIndex)
        let isDrift2 = songState?.isKosmicDrift == true
        let isSoho2 = songState?.chillSohoVariation == true
        let tName = trackIndex < kTrackNames.count ? kTrackNames[trackIndex] : "Track \(trackIndex)"
        let names = Self.instrumentPoolNames(trackIndex: trackIndex, style: style, isChillSoho: isSoho2)
        let iName = newIdx < names.count ? names[newIdx] : "prog \(programs[newIdx])"
        appendToLog([GenerationLogEntry(tag: "Instrument", description: "\(tName) \(iName)", isTitle: false)])
    }

    /// Sets a specific program on a track and records the override index.
    func setInstrument(_ program: Int, forTrack trackIndex: Int) {
        let isDrift = songState?.isKosmicDrift == true
        let isSoho = songState?.chillSohoVariation == true
        let programs = Self.instrumentPoolPrograms(trackIndex: trackIndex, style: selectedStyle, isChillSoho: isSoho)
        if let idx = programs.firstIndex(of: program) {
            instrumentOverrides[trackIndex] = idx
        }
        setProgram(program, forTrack: trackIndex)
        instrumentChangeToken += 1
        let tName = trackIndex < kTrackNames.count ? kTrackNames[trackIndex] : "Track \(trackIndex)"
        let names = Self.instrumentPoolNames(trackIndex: trackIndex, style: selectedStyle, isChillSoho: isSoho)
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

    /// Instruments whose Chill lead parts take vibrato. Named rather than indexed so that
    /// reordering or re-scoping a pool cannot silently change which instrument is eligible.
    /// Flute is deliberately absent: it reads as breath, not as a bowed wobble (Zack, 2026-10-13).
    nonisolated static let chillVibratoLeads: Set<String> = [
        "Tenor Sax", "Alto Sax", "Soprano Sax", "Trumpet", "Trombone"
    ]

    /// True 20% of the time when `lead`'s current instrument is one that uses vibrato, and the
    /// track being configured IS that lead. Shared by `restoreDefaultEffects` and
    /// `TrackRowView.applyDefaultEffects`, which must agree.
    nonisolated static func leadUsesVibrato(trackIndex: Int, lead: Int, state: SongState?,
                                            overrides: [Int: Int]) -> Bool {
        guard trackIndex == lead, state?.style == .chill else { return false }
        let names = instrumentPoolNames(trackIndex: lead, style: .chill,
                                        isChillSoho: state?.chillSohoVariation == true)
        let idx = overrides[lead] ?? 0
        guard idx >= 0, idx < names.count, chillVibratoLeads.contains(names[idx]) else { return false }
        return Float.random(in: 0..<1) < 0.20
    }

    /// Whether this Chill rhythm instrument takes the Leslie-style tremolo, matched by NAME.
    /// Blues gives its organs a 50% chance; base Chill and Soho give theirs 20%.
    ///
    /// This was `[2, 3, 5]` and `[2, 6]`, raw pool indices. It survived the Soho rhythm pool
    /// gaining a guitar only because the guitar was appended rather than inserted — had it gone
    /// anywhere earlier, tremolo would have silently moved onto the wrong instruments, exactly
    /// as it did with the lead vibrato (Zack, 2026-10-13).
    nonisolated static func rhythmUsesTremolo(trackIndex: Int, state: SongState?,
                                              overrides: [Int: Int]) -> Bool {
        guard trackIndex == kTrackRhythm, state?.style == .chill else { return false }
        let blues = state?.chillBluesVariation == true
        let names = instrumentPoolNames(trackIndex: kTrackRhythm, style: .chill,
                                        isChillSoho: state?.chillSohoVariation == true)
        let progs = instrumentPoolPrograms(trackIndex: kTrackRhythm, style: .chill,
                                           isChillSoho: state?.chillSohoVariation == true)
        let idx = overrides[kTrackRhythm] ?? 0
        guard idx >= 0, idx < names.count, idx < progs.count else { return false }
        // A guitar always takes it. The slow shallow amp tremolo is part of that sound rather
        // than an occasional colour (Zack, 2026-10-13), and PlaybackEngine gives a guitar its own
        // 4 Hz / 0.32 setting instead of the organ's 8 Hz / 0.40. Keyed on the GM guitar family,
        // so any guitar added to any Chill rhythm pool gets it without another edit.
        if PlaybackEngine.isGuitarProgram(progs[idx]) { return true }
        // Chill Soho's Rhodes takes it too: the slow stereo-style shimmer is the sound of the
        // Sade records' electric piano, so in Soho it is always on (Zack, 2026-10-15). Base Chill
        // and Blues Rhodes are unchanged.
        if state?.chillSohoVariation == true && names[idx] == "Rhodes" { return true }
        let eligible: Set<String> = blues ? ["B3 Organ", "Perc Organ", "Rock Organ"]
                                          : ["B3 Organ", "Tonewheel"]
        guard eligible.contains(names[idx]) else { return false }
        return Float.random(in: 0..<1) < (blues ? 0.50 : 0.20)
    }

    /// Chill Soho's Elec Bass takes Low under it (Comp came off 2026-10-15). Matched by name for the same reason:
    /// it was `instrumentOverrides[kTrackBass] == 2`, and index 2 only happens to be Elec Bass.
    nonisolated static func sohoBassTakesLow(trackIndex: Int, state: SongState?,
                                                 overrides: [Int: Int]) -> Bool {
        guard trackIndex == kTrackBass, state?.chillSohoVariation == true else { return false }
        let names = instrumentPoolNames(trackIndex: kTrackBass, style: .chill, isChillSoho: true)
        let idx = overrides[kTrackBass] ?? 0
        return idx >= 0 && idx < names.count && names[idx] == "Elec Bass"
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
            case kTrackLead1:   [.delay, .space]
            // Matches TrackRowView: a mirrored Lead 2 doubles Lead 1, so it takes
            // Lead 1's delay as well. `lead2MirrorName != nil` is what the Mac path
            // calls isInstrumentLocked.
            case kTrackLead2:   lead2MirrorName != nil ? [.delay, .space] : [.space]
            case kTrackPads:    [.space, .sweep]
            case kTrackRhythm:  [.reverb]
            // Matches TrackRowView: with an audio texture file playing, the texture
            // track is driven by AudioTexturePlayer, where pan and sweep do nothing.
            case kTrackTexture: songState?.ambientAudioTexture != nil ? [.space] : [.space, .pan, .sweep]
            case kTrackBass:    [.reverb, .sweep]
            case kTrackDrums:   [.delay]
            default:            []
            }
        case .chill:
            let isBlues    = songState?.chillBluesVariation == true
            let baseLeadFX: [TrackEffect] = isBlues ? [.space] : [.space, .delay]
            // Chill Soho: no delay on Lead 1 (a St Germain signature). Mirrors TrackRowView.
            let lead1FX: [TrackEffect] = songState?.chillSohoVariation == true ? [.space] : baseLeadFX

            // Rhythm organ tremolo — matched by instrument name, not pool index. See
            // rhythmUsesTremolo. Mirrored in TrackRowView.applyDefaultEffects.
            let rhythmTrem = Self.rhythmUsesTremolo(trackIndex: trackIndex, state: songState,
                                                    overrides: instrumentOverrides)

            // Lead vibrato, 20% of songs, on the instruments that actually use it: the saxes,
            // the open trumpet, the flute and the trombone. Muted trumpet is out (a harmon mute
            // does not vibrato), as are the mallets and the synth brass.
            //
            // This was a list of POOL INDICES, [1, 2, 3], which silently meant something different
            // in each Chill form and broke the moment the Lead 1 pools were split per form —
            // Tenor Sax, the commonest lead in Blues and Soho, lost its vibrato (Zack,
            // 2026-10-13). Matching on the name cannot drift when a pool is reordered.
            let l1Vib = Self.leadUsesVibrato(trackIndex: trackIndex, lead: kTrackLead1, state: songState,
                                             overrides: instrumentOverrides)
            let l2Vib = Self.leadUsesVibrato(trackIndex: trackIndex, lead: kTrackLead2, state: songState,
                                             overrides: instrumentOverrides)

            // Chill Soho's Elec Bass wants Low under it — the chips and the audio chain are the
            // same switch, so they cannot drift. Matched by name; see sohoBassTakesLow. Mirrored
            // in TrackRowView.applyDefaultEffects. Comp came off (Zack, 2026-10-15).
            let sohoElecBass = Self.sohoBassTakesLow(trackIndex: trackIndex, state: songState,
                                                         overrides: instrumentOverrides)

            defaults = switch trackIndex {
            case kTrackLead1:   l1Vib      ? lead1FX + [.vibrato]    : lead1FX
            case kTrackLead2:   l2Vib      ? baseLeadFX + [.vibrato] : baseLeadFX
            case kTrackRhythm:  rhythmTrem ? [.space, .tremolo]       : [.space]
            case kTrackPads:    [.sweep, .tremolo]
            // Chill Soho's texture is MIDI horns/bells — mirrors TrackRowView.
            case kTrackTexture: songState?.chillSohoVariation == true ? [.space, .reverb] : [.lowShelf, .reverb]
            case kTrackBass:    sohoElecBass ? [.reverb, .lowShelf] : [.reverb]
            case kTrackDrums:   [.space]
            default:            []
            }
        case .kosmic:
            let isDriftEffects    = songState?.isKosmicDrift == true
            let kl1VibProb: Float = isDriftEffects ? 0.75 : 0.20
            let kl2VibProb: Float = isDriftEffects ? 0.50 : 0.20

            // Lead 1 eligible: Flute(0)/Oboe(2)/Recorder(3)/Sine Wave(5)/Bottle Blow(6)/Shenai(7)
            let kl1Idx = trackIndex == kTrackLead1 ? (instrumentOverrides[kTrackLead1] ?? 0) : -1
            let kl1Vib = [0, 2, 3, 5, 6, 7].contains(kl1Idx) && Float.random(in: 0..<1) < kl1VibProb
            // Lead 2 eligible: Bassoon(1)/Charang(2)/Vox Solo(3)
            let kl2Idx = trackIndex == kTrackLead2 ? (instrumentOverrides[kTrackLead2] ?? 0) : -1
            let kl2Vib = [1, 2, 3].contains(kl2Idx) && Float.random(in: 0..<1) < kl2VibProb
            // Probabilistic additions for regular Kosmic (Drift already has these always on)
            let padsSwp  = !isDriftEffects && trackIndex == kTrackPads    && Float.random(in: 0..<1) < 0.20
            let bassTrem = !isDriftEffects && trackIndex == kTrackBass    && Float.random(in: 0..<1) < 0.15
            let texPan   = !isDriftEffects && trackIndex == kTrackTexture && Float.random(in: 0..<1) < 0.15

            defaults = switch trackIndex {
            case kTrackLead1:   kl1Vib ? [.delay, .space, .vibrato] : [.delay, .space]
            case kTrackLead2:   kl2Vib ? [.space, .vibrato]         : [.space]
            case kTrackPads:    (isDriftEffects || padsSwp)  ? [.space, .delay, .sweep] : [.space, .delay]
            case kTrackTexture: (isDriftEffects || texPan)   ? [.delay, .space, .pan]   : [.delay, .space]
            case kTrackBass:    (isDriftEffects || bassTrem) ? [.tremolo] : []
            case kTrackRhythm:  [.delay]
            default:            []
            }
        case .motorik:
            let idx = instrumentOverrides[kTrackLead1] ?? 0
            let mnames = Self.instrumentPoolNames(trackIndex: kTrackLead1, style: .motorik)
            let isTremoloLead = trackIndex == kTrackLead1
                && idx < mnames.count
                && (mnames[idx] == "Synth Lead" || mnames[idx] == "Square Lead")
            let isNoir           = songState?.motorikNoirVariation        == true
            let isBassDistortion = songState?.motorikBassDistortion       == true
            let isNoirBassDist   = songState?.motorikNoirBassDistortion   == true
            let isNoirRhythmDist = songState?.motorikNoirRhythmDistortion == true
            // Fuzz Guitar (idx 2) and Acoustic Bass (idx 4) sound wrong with distortion — exempt them.
            let rhythmExemptsDistortion = [2, 4].contains(instrumentOverrides[kTrackRhythm] ?? 0)
            let airProb: Float   = isNoir ? 0.45 : 0.25
            let ml1Air           = trackIndex == kTrackLead1 && Float.random(in: 0..<1) < airProb
            let lead1Base: [TrackEffect] = isTremoloLead ? [.delay, .tremolo] : [.delay]
            let padsSwpMot = !isNoir && trackIndex == kTrackPads   && Float.random(in: 0..<1) < 0.15
            let ml2Delay   = trackIndex == kTrackLead2             && Float.random(in: 0..<1) < 0.20
            defaults = switch trackIndex {
            case kTrackLead1:   ml1Air ? lead1Base + [.air] : lead1Base
            case kTrackLead2:   ml2Delay ? [.delay] : []
            case kTrackRhythm:  isNoirRhythmDist && !rhythmExemptsDistortion ? [.delay, .distortion] : [.delay]
            case kTrackPads:    (isNoir || padsSwpMot) ? [.space, .sweep] : [.space]
            case kTrackTexture: [.pan]
            case kTrackBass:    isNoirBassDist || isBassDistortion ? [.distortion] : []
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
        // Reloading a song reprints its full generation log, exactly as loading a .zudio
        // file does on Mac. Without this, ⏮/⏭ and Songs-tab taps logged only a one-line
        // "Rewind" entry, so there was no way to see which rules (AMB-TEXT-0NN in
        // particular) the reloaded song actually used.
        appendGenerationLog(state.generationLog)
        // Restore the exact instruments that were playing when this song was first generated.
        if let cached = sessionInstrumentOverrides[state.globalSeed] {
            instrumentOverrides = cached
        } else {
            // No cached assignment for this seed. Instrument picks use
            // SystemRandomNumberGenerator (see randomizeTwoInstruments), so they cannot be
            // re-derived from the song seed — every track without an entry falls back to
            // pool index 0 in applyCurrentInstrumentsToPlayback(). That silent fallback is
            // why "L1:61001" (Ambient index 0, Stereo Piano) went unnoticed for so long, so
            // say it out loud in the log rather than quietly substituting instruments.
            instrumentOverrides = Self.instrumentOverridesFromLog(state)
            if instrumentOverrides.filter({ $0.key != kTrackTexture }).isEmpty {
                appendToLog([GenerationLogEntry(
                    tag: "Warning",
                    description: "using default instruments",
                    isTitle: false)])
            }
        }
        // Chill's leads are chosen by the generator, and their phrasing is written for that
        // instrument: pin the patch to it, whatever the history saved. Entries persisted before
        // 2026-10-16 hold the previous song's Lead 1, usually a sax. Texture positions too.
        applyLoadedInstruments(for: state)
        applyManualInstruments(seed: state.globalSeed)
        muteState = Array(repeating: false, count: kTrackCount)
        soloState = Array(repeating: false, count: kTrackCount)
        playback.muteState    = muteState
        playback.soloState    = soloState
        configurePlaybackStyle(for: state)
        playback.load(state)
        playback.seek(toStep: 0)
        playback.setAmbientMode(state.style == .ambient)
        playback.setChillMode(state.style == .chill, bluesVariation: state.chillBluesVariation, sohoVariation: state.chillSohoVariation)
        defaultsResetToken += 1
        applyCurrentInstrumentsToPlayback()
        if wasPlaying || forcePlay {
            prepareSleepTimerForPlayback()
            playback.play()
            // Ambient/Chill audio textures are NOT part of the MIDI engine, so
            // playback.play() does not start them. AppState.play() has its own
            // audioTexture.start() call, but this path calls playback.play() directly and
            // bypasses it — so the texture has to be started here, exactly as
            // finishLoadingSong() does on the regenerate-from-seed path. Without this,
            // reloading a song that was still in generationHistory played every MIDI track
            // but left the audio texture silent, while the log correctly reported it.
            let texFile   = state.style == .ambient ? state.ambientAudioTexture : state.chillAudioTexture
            audioTexture.start(style: state.style, texture: texFile,
                               offsetSeconds: textureSeconds(atStep: playback.currentStep, in: state))
        }
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
        Task.detached(priority: .userInitiated) { [weak self, song, thenPlay] in
            guard let self else { return }
            var state = Self.regenerateSong(seed: song.seed, keyOverride: song.keyOverride,
                                            tempoOverride: song.tempoOverride, moodOverride: song.moodOverride,
                                            style: song.style, forced: song.forcedRules,
                                            trackOverrides: song.decodedTrackOverrides,
                                            forceBlues: song.savedAsBlues, forceSoho: song.savedAsSoho,
                                            forbidSoho: song.savedAsBaseChill)
            await MainActor.run {
                state.title = song.title   // preserve the title from when the song was generated
                self.isGenerating  = false
                self.selectedStyle = song.style
                self.keyOverride   = song.keyOverride
                self.tempoOverride = song.tempoOverride
                self.moodOverride  = song.moodOverride
                // Songs saved before the assignment was reliably captured have no persisted
                // overrides; recover them from the regenerated song's own Instruments log
                // rather than letting every track fall back to pool index 0.
                self.instrumentOverrides = song.decodedInstrumentOverrides.isEmpty
                    ? Self.instrumentOverridesFromLog(state)
                    : song.decodedInstrumentOverrides
                // The Chill and Ambient texture positions are re-derived from the song by
                // applyLoadedInstruments, which also repairs ones saved under old numbering.
                self.applyLoadedInstruments(for: state)
                self.applyManualInstruments(seed: state.globalSeed)
                self.appendGenerationLog(state.generationLog)
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
        let beatFixupOn     = playback.beatFixupEnabled   // so export matches what is heard
        // Apply mute/solo: mirror PlaybackEngine.applyMuteState() so export
        // matches what the user hears during playback.
        let anySolo = soloState.contains(true)
        var snapshots = rawSnapshots
        for i in 0..<snapshots.count {
            let idx    = (i == kTrackLeadSynth) ? kTrackLead1 : i
            let muted  = muteState[idx] || (anySolo && !soloState[idx])
            if muted { snapshots[i].volume = 0.0 }
        }
        // The audio texture is outside the snapshots above, so mute and solo apply to it here.
        let textureMuted    = muteState[kTrackTexture] || (anySolo && !soloState[kTrackTexture])
        let textureSnapshot = textureMuted ? nil : audioTexture.exportSnapshot()
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
                    beatFixupEnabled: beatFixupOn,
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
