// IOSPlatformHost.swift — iOS implementation of ZudioPlatformHost
// Copyright (c) 2026 Zack Urlocker
// Full implementation wired up in Phase 1 of the iOS port.

#if os(iOS)
import UIKit
import AVFoundation

@MainActor
final class IOSPlatformHost: ZudioPlatformHost {

    func registerKeyboardShortcuts(target: AppState) {
        // UIKeyCommand registration — implemented in Phase 4 (iPhone portrait)
    }

    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            // Pin the IO buffer to ~1024 frames (~23ms at 44.1kHz). Without this iOS picks
            // 256 frames when the screen is on and silently jumps to 4096 when the screen locks,
            // causing a render-thread frequency spike at exactly the screen-off moment.
            try session.setPreferredIOBufferDuration(0.023)
            try session.setActive(true)
        } catch {
            print("AVAudioSession setup failed: \(error)")
        }
        // DIAGNOSTIC LOGGING — lock-screen tempo drift investigation (2026).
        // protectedDataWillBecomeUnavailable/DidBecomeAvailable fire precisely on device
        // lock/unlock (data-protection boundary), which is a tighter correlate than
        // app background/foreground. Gated on the same kStepTimingDebugLog flag as the
        // StepScheduler logging so both can be toggled with one flip. Safe to delete
        // this whole block (and the flag/prints in StepScheduler.swift) once done.
        if kStepTimingDebugLog {
            NotificationCenter.default.addObserver(
                forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
                object: nil, queue: .main
            ) { _ in stepTimingLogger.notice("==== SCREEN LOCK (protectedDataWillBecomeUnavailable) ====") }
            NotificationCenter.default.addObserver(
                forName: UIApplication.protectedDataDidBecomeAvailableNotification,
                object: nil, queue: .main
            ) { _ in stepTimingLogger.notice("==== SCREEN UNLOCK (protectedDataDidBecomeAvailable) ====") }
        }
    }

    func playErrorSound() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.error)
    }

    func showOpenPanel(completion: @escaping (URL?) -> Void) {
        // UIDocumentPickerViewController — implemented in Phase 1 iOS port
        completion(nil)
    }

    func dismissKeyboard() {
        // Keyboard dismissal is handled via @FocusState in SwiftUI views on iOS
    }
}
#endif
