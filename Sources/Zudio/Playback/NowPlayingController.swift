// NowPlayingController.swift — Mac media key support (F7 / F8 / F9 and Control-Center strip).
//
// Uses MPRemoteCommandCenter — entirely separate from NSEvent.addLocalMonitorForEvents,
// so it cannot conflict with Space, B, Z, arrow keys or any existing Zudio hotkey.
//
// Registered commands:
//   togglePlayPause  (F8 / ⏯)  → playOrStop()
//   play / pause / stop         → play() / stop()
//   previousTrack   (F7 / ⏮)  → seekToStart() (bars 0-1: go to previous song)
//   nextTrack       (F9 / ⏭)  → mode-aware next song: Endless=skipToNextSong, Evolve=skipEvolvePass
//
// Media-key routing on macOS is controlled by MPNowPlayingInfoCenter.playbackState
// (separate from nowPlayingInfo) — the system routes to whichever app most recently
// set .playing. Browsers set their own playbackState continuously via the Web Media
// Session API; we must set ours explicitly or browsers will always win.

import MediaPlayer
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

final class NowPlayingController {

    private weak var appState: AppState?

    // Artwork computed once at configure time — avoids re-allocating on every Now Playing update.
    private var cachedArtwork: MPMediaItemArtwork?

    // MARK: - Setup

    func configure(appState: AppState) {
        self.appState = appState
        cachedArtwork = Self.makeArtwork()
        setupRemoteCommands()
    }

    // MARK: - Artwork

    private static func makeArtwork() -> MPMediaItemArtwork? {
        #if os(iOS)
        // ZudioLogoSquare: square wordmark with yellow bolt — ideal for lock screen / Now Playing.
        let image = UIImage(named: "ZudioLogoSquare") ?? UIImage(named: "AppIconImage")
        guard let image else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        #elseif os(macOS)
        guard let image = NSApp.applicationIconImage else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        #else
        return nil
        #endif
    }

    // MARK: - Remote commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        // Play/pause toggle — the primary F8 / ⏯ key
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.appState?.playOrStop() }
            return .success
        }

        // Explicit play
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                guard let app = self?.appState, !app.playback.isPlaying else { return }
                app.play()
            }
            return .success
        }

        // Explicit pause (same as stop in Zudio — no mid-song pause concept)
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                guard let app = self?.appState, app.playback.isPlaying else { return }
                app.stop()
            }
            return .success
        }

        // Stop
        center.stopCommand.isEnabled = true
        center.stopCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.appState?.stop() }
            return .success
        }

        // Previous track (F7 / ⏮) → go to beginning
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                guard let app = self?.appState, app.songState != nil else { return }
                app.seekToStart()
            }
            return .success
        }

        // Next track (F9 / ⏭) → skip to next song (mode-aware)
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                guard let app = self?.appState else { return }
                switch app.playMode {
                case .endless: app.skipToNextSong()
                case .evolve:  app.skipEvolvePass()
                case .song:    app.loadNextFromHistory()
                }
            }
            return .success
        }

        // Disable inapplicable commands so the system doesn't show scrub bars etc.
        center.changePlaybackPositionCommand.isEnabled = false
        center.skipForwardCommand.isEnabled            = false
        center.skipBackwardCommand.isEnabled           = false
        center.seekForwardCommand.isEnabled            = false
        center.seekBackwardCommand.isEnabled           = false
        center.changePlaybackRateCommand.isEnabled     = false
        center.ratingCommand.isEnabled                 = false
        center.likeCommand.isEnabled                   = false
        center.dislikeCommand.isEnabled                = false
        center.bookmarkCommand.isEnabled               = false
    }

    // MARK: - Now Playing info

    /// Call whenever song or play state changes.
    ///
    /// `playbackState` is the key signal: it is a first-class property separate from
    /// `nowPlayingInfo` and is NOT overwritten by browser elapsed-time ticks. Setting it
    /// explicitly is the macOS equivalent of iOS's AVAudioSession.setActive(true), and is
    /// required for reliable media-key routing (IINA issue #3340, fix PR #3579).
    func update(song: SongState?, isPlaying: Bool, currentStep: Int) {
        let center = MPNowPlayingInfoCenter.default()
        center.playbackState = isPlaying ? .playing : .paused

        if let song {
            let elapsed = Double(currentStep) * song.frame.secondsPerStep
            var info: [String: Any] = [
                MPMediaItemPropertyTitle:                    song.title,
                MPMediaItemPropertyArtist:                   "Zudio",
                MPMediaItemPropertyPlaybackDuration:         song.frame.totalDurationSeconds,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
                MPNowPlayingInfoPropertyPlaybackRate:        isPlaying ? 1.0 : 0.0,
                MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            ]
            if let artwork = cachedArtwork { info[MPMediaItemPropertyArtwork] = artwork }
            center.nowPlayingInfo = info
        } else {
            var info: [String: Any] = [
                MPMediaItemPropertyTitle:             "Zudio",
                MPNowPlayingInfoPropertyPlaybackRate: 0.0,
            ]
            if let artwork = cachedArtwork { info[MPMediaItemPropertyArtwork] = artwork }
            center.nowPlayingInfo = info
        }
    }

    /// Claim Now Playing routing from other apps (e.g. a browser with a playing tab).
    ///
    /// Sets playbackState = .playing — a persistent signal that browsers cannot overwrite
    /// (they only update their own nowPlayingInfo, not our playbackState). After 100 ms,
    /// restores the true state. This is the approach used by IINA and VLC on macOS.
    func claimFocus(song: SongState?, isPlaying: Bool, currentStep: Int) {
        MPNowPlayingInfoCenter.default().playbackState = .playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.update(song: song, isPlaying: isPlaying, currentStep: currentStep)
        }
    }
}
