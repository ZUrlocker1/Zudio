// AppState.swift — global observable app state, shared across all views

import SwiftUI
import AppKit
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Song state

    @Published var songState: SongState? = nil
    @Published var isGenerating: Bool = false

    // MARK: - Generation history (status log accumulates across generations)

    @Published var generationHistory: [SongState] = []

    // MARK: - Visible window — zoom + DAW scroll

    @Published var visibleBars: Int = 16
    @Published var visibleBarOffset: Int = 0

    // MARK: - UI selectors (nil = Auto)

    @Published var keyOverride:   String? = nil
    @Published var tempoOverride: Int?    = nil
    @Published var moodOverride:  Mood?   = nil

    // MARK: - Test mode (shorter songs for rapid audition)

    @Published var testModeEnabled: Bool = false

    func toggleTestMode() { testModeEnabled.toggle() }

    // MARK: - Per-track UI state

    @Published var muteState: [Bool] = Array(repeating: false, count: 7)
    @Published var soloState: [Bool] = Array(repeating: false, count: 7)

    // MARK: - Live playback feed (Now Playing strip)

    @Published var livePlaybackFeed: [GenerationLogEntry] = []
    private var lastEmittedStep: Int = -1

    // MARK: - Playback engine

    let playback = PlaybackEngine()

    private var cancellables = Set<AnyCancellable>()
    private var spaceBarMonitor: Any?

    init() {
        // *** KEY FIX: forward PlaybackEngine changes through AppState ***
        // Without this, @Published properties on PlaybackEngine (like currentStep)
        // do not trigger redraws in views that observe AppState.
        playback.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Global space-bar monitor — intercepts space regardless of keyboard focus.
        // Bypasses the BPM TextField focus-stealing issue.
        spaceBarMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 49,   // space bar
                  event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
            else { return event }
            // Always consume space — the only TextField in this app is numeric (BPM),
            // which never needs space. Removing the NSText guard fixes the focus-steal bug.
            Task { @MainActor [weak self] in
                guard let self, !self.isGenerating else { return }
                self.playOrStop()
            }
            return nil   // consume event so no other handler sees it
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

        // DAW-style scrolling + live annotation feed
        playback.$currentStep
            .dropFirst()
             .receive(on: DispatchQueue.main)
            .sink { [weak self] step in
                Task { @MainActor [weak self] in
                    self?.updateDAWScroll(step: step)
                    self?.emitStepAnnotations(upTo: step)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Live annotation feed

    private func emitStepAnnotations(upTo step: Int) {
        guard step > lastEmittedStep,
              let annotations = songState?.stepAnnotations else { return }
        for s in (lastEmittedStep + 1)...step {
            if let entries = annotations[s] {
                for entry in entries {
                    livePlaybackFeed.append(entry)
                }
            }
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
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = SongGenerator.generate(
                keyOverride:   await self.keyOverride,
                tempoOverride: await self.tempoOverride,
                moodOverride:  await self.moodOverride,
                testMode:      await self.testModeEnabled
            )
            await MainActor.run {
                self.songState    = state
                self.generationHistory.append(state)
                self.isGenerating = false
                self.visibleBarOffset = 0
                self.livePlaybackFeed = []
                self.lastEmittedStep  = -1
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
                self.playback.load(state)
                self.playback.seek(toStep: 0)
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
                // Keep generationHistory in sync so StatusBoxView shows the regen log
                if !self.generationHistory.isEmpty {
                    self.generationHistory[self.generationHistory.count - 1] = updated
                }
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
