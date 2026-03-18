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

    // MARK: - Per-track UI state

    @Published var muteState: [Bool] = Array(repeating: false, count: 7)
    @Published var soloState: [Bool] = Array(repeating: false, count: 7)

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

        // DAW-style scrolling: advance visible window when playhead hits 85%
        playback.$currentStep
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] step in
                Task { @MainActor [weak self] in
                    self?.updateDAWScroll(step: step)
                }
            }
            .store(in: &cancellables)
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
                moodOverride:  await self.moodOverride
            )
            await MainActor.run {
                self.songState    = state
                self.generationHistory.append(state)
                self.isGenerating = false
                self.visibleBarOffset = 0
                // Reflect key/mood back so the user can see what was picked.
                // BPM resets to Auto so the next generation is free to pick a fresh tempo.
                self.keyOverride   = state.frame.key
                self.tempoOverride = nil
                self.moodOverride  = state.frame.mood
                self.playback.load(state)
                self.playback.seek(toStep: 0)
                if thenPlay { self.playback.play() }
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
            }
        }
    }

    // MARK: - Transport

    func play() {
        NSApp.activate(ignoringOtherApps: true)
        if songState == nil {
            generateNew(thenPlay: true)
        } else {
            // If the playhead is at or past the end, rewind to bar 1 before playing
            if let song = songState, playback.currentStep >= song.frame.totalBars * 16 - 1 {
                playback.seek(toStep: 0)
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
