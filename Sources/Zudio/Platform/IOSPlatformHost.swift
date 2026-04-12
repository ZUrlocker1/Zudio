// IOSPlatformHost.swift — iOS implementation of ZudioPlatformHost
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession setup failed: \(error)")
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleInterruption(note)
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

    // MARK: - Private

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        // Playback pause/resume on interruption is handled by the audio engine automatically.
        // Add AppState callbacks here if manual intervention is needed.
        _ = type
    }
}
#endif
