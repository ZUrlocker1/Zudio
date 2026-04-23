// MacPlatformHost.swift — macOS implementation of ZudioPlatformHost
// Copyright (c) 2026 Zack Urlocker

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

@MainActor
final class MacPlatformHost: ZudioPlatformHost {

    private var keyEventMonitor: Any?

    // MARK: - Keyboard shortcuts

    func registerKeyboardShortcuts(target: AppState) {
        // NSEvent monitor callbacks always run on the main thread.
        // Arrow keys and Return guard against text field focus (BPM field uses these for editing).
        // Return also guards against open sheets (Help/About use .defaultAction = Return on Close).
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak target] event in
            guard let target else { return event }
            // Strip modifier keys irrelevant to our shortcuts (.numericPad/.function are set on arrows)
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])

            switch event.keyCode {

            case 49: // Space — play/stop (BPM field never needs space, no guard required)
                guard mods.isEmpty else { return event }
                Task { @MainActor [weak target] in
                    guard let target, !target.isGenerating else { return }
                    target.playOrStop()
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
                Task { @MainActor [weak target] in
                    guard let target, !target.isGenerating else { return }
                    target.generateNew(thenPlay: true)
                }
                return nil

            case 123: // Left arrow — seek back 1 bar (plain) or to start (Cmd)
                let isTextField = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
                guard !isTextField else { return event }
                if mods.isEmpty {
                    Task { @MainActor [weak target] in
                        guard let target, target.songState != nil else { return }
                        target.seekBackOneBar()
                    }
                    return nil
                } else if mods == .command {
                    Task { @MainActor [weak target] in
                        guard let target, target.songState != nil else { return }
                        target.seekToStart()
                    }
                    return nil
                }

            case 124: // Right arrow — seek forward 1 bar (plain) or to end (Cmd)
                let isTextField = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
                guard !isTextField else { return event }
                if mods.isEmpty {
                    Task { @MainActor [weak target] in
                        guard let target, target.songState != nil else { return }
                        target.seekForwardOneBar()
                    }
                    return nil
                } else if mods == .command {
                    Task { @MainActor [weak target] in
                        guard let target, target.songState != nil else { return }
                        target.loadNextFromHistory()
                    }
                    return nil
                }

            // Plain-letter shortcuts — all guard against text-field focus and open sheets
            case 5, 1, 37, 46, 15, 40, 4, 0, 11, 6, 14:
                guard mods.isEmpty else { return event }
                let isTextField = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
                let sheetOpen   = !(NSApp.keyWindow?.sheets.isEmpty ?? true)
                guard !isTextField, !sheetOpen else { return event }
                switch event.keyCode {
                case 5:  // 'g' — generate
                    Task { @MainActor [weak target] in
                        guard let target, !target.isGenerating else { return }
                        target.generateNew(thenPlay: true)
                    }
                case 14: // 'e' — export audio
                    guard target.songState != nil, !target.isExportingAudio else { return event }
                    Task { @MainActor [weak target] in target?.requestExport() }
                case 1:  // 's' — save MIDI
                    guard target.songState != nil else { return event }
                    Task { @MainActor [weak target] in target?.saveMIDI() }
                case 37: // 'l' — load song
                    guard !target.isGenerating else { return event }
                    Task { @MainActor [weak target] in target?.loadFromLog() }
                case 46: // 'm' — Motorik
                    Task { @MainActor [weak target] in target?.selectedStyle = .motorik }
                case 15: // 'r' — reset (always allowed — clears everything)
                    Task { @MainActor [weak target] in target?.resetTrackDefaults() }
                case 40: // 'k' — Kosmic
                    Task { @MainActor [weak target] in target?.selectedStyle = .kosmic }
                case 4:  // 'h' — help
                    Task { @MainActor [weak target] in target?.triggerShowHelp.toggle() }
                case 0:  // 'a' — Ambient
                    Task { @MainActor [weak target] in target?.selectedStyle = .ambient }
                case 8:  // 'c' — Chill
                    Task { @MainActor [weak target] in target?.selectedStyle = .chill }
                case 11: // 'b' — beginning of current track only, never rewinds to prior track
                    guard target.songState != nil else { return event }
                    Task { @MainActor [weak target] in target?.seekTo(step: 0) }
                case 6:  // 'z' — next song (or generate if at top of stack)
                    guard target.songState != nil else { return event }
                    Task { @MainActor [weak target] in target?.loadNextFromHistory() }
                default: break
                }
                return nil

            case 42: // '\' — compact / expand window
                guard mods.isEmpty else { return event }
                let isTextField42 = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
                let sheetOpen42   = !(NSApp.keyWindow?.sheets.isEmpty ?? true)
                guard !isTextField42, !sheetOpen42 else { return event }
                Task { @MainActor [weak target] in target?.toggleWindowCompact() }
                return nil

            default:
                break
            }

            return event
        }
    }

    // MARK: - Audio session

    func configureAudioSession() {
        // No-op on macOS — audio session management is automatic.
    }

    // MARK: - Error sound

    func playErrorSound() {
        NSSound(named: "Basso")?.play()
    }

    // MARK: - File picker

    func showOpenPanel(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Load Zudio Song"
        panel.message = "Select a Zudio song file (.zudio or .txt)"
        var types: [UTType] = [.plainText]
        if let zudioType = UTType("com.zudio.song") { types.insert(zudioType, at: 0) }
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        completion(panel.runModal() == .OK ? panel.url : nil)
    }

    // MARK: - Keyboard dismissal

    func dismissKeyboard() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}
#endif
