// AppState.swift — global observable app state, shared across all views

import SwiftUI

@MainActor
final class AppState: ObservableObject {
    // MARK: - Song state

    @Published var songState: SongState? = nil
    @Published var isGenerating: Bool = false

    // MARK: - UI selectors (nil = Auto)

    @Published var keyOverride:   String? = nil  // nil = Auto
    @Published var tempoOverride: Int?    = nil  // nil = Auto, range 20–200
    @Published var moodOverride:  Mood?   = nil  // nil = Auto

    // MARK: - Per-track UI state

    @Published var muteState: [Bool] = Array(repeating: false, count: 7)
    @Published var soloState: [Bool] = Array(repeating: false, count: 7)

    // MARK: - Playback engine

    let playback = PlaybackEngine()

    // MARK: - Generate

    func generateNew() {
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
                self.isGenerating = false
                self.playback.load(state)
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
                if self.playback.isPlaying {
                    self.playback.load(updated) // bar-boundary swap handled by PlaybackEngine
                }
            }
        }
    }

    // MARK: - Transport

    func play()  { playback.play() }
    func stop()  { playback.stop() }

    // MARK: - Mute / Solo

    func toggleMute(_ trackIndex: Int) {
        muteState[trackIndex].toggle()
        playback.muteState = muteState
    }

    func toggleSolo(_ trackIndex: Int) {
        soloState[trackIndex].toggle()
        playback.soloState = soloState
    }
}
