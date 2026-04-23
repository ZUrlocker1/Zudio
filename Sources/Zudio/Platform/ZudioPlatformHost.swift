// ZudioPlatformHost.swift — platform abstraction protocol for AppState
// Copyright (c) 2026 Zack Urlocker
//
// AppState calls through this protocol for all platform-specific behavior.
// MacPlatformHost provides the macOS implementation; IOSPlatformHost provides iOS.

import Foundation

@MainActor
protocol ZudioPlatformHost: AnyObject {

    /// Wire up global keyboard shortcuts.
    /// Called automatically when platformHost is set on AppState (via didSet).
    /// The conformer fires callbacks into `target` via its public transport/generation methods.
    func registerKeyboardShortcuts(target: AppState)

    /// Configure the audio session for playback.
    /// macOS: no-op. iOS: AVAudioSession category, activation, and interruption observer.
    func configureAudioSession()

    /// Play the platform error sound (Basso on macOS, error haptic on iOS).
    func playErrorSound()

    /// Present a file-open panel or document picker.
    /// Calls `completion` with the chosen URL, or nil if the user cancelled.
    func showOpenPanel(completion: @escaping (URL?) -> Void)

    /// Resign first responder / dismiss the software keyboard.
    func dismissKeyboard()
}
