// ZudioApp.swift — @main entry point

import SwiftUI
import AppKit

// Quit the app when the last window closes (window-close = full exit, not just hide)
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        removeUnwantedMenus()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Re-apply removals in case SwiftUI rebuilds menus after activation.
        removeUnwantedMenus()
    }

    private func removeUnwantedMenus() {
        DispatchQueue.main.async {
            guard let menu = NSApp.mainMenu else { return }
            // Hide Edit rather than remove — removal kills pasteboard key equivalents (⌘C etc.)
            // that .textSelection(.enabled) depends on. Hidden items stay in the responder chain.
            if let edit = menu.item(withTitle: "Edit") { edit.isHidden = true }
            // Format, View, Window have no needed key equivalents — remove entirely.
            for title in ["Format", "View", "Window"] {
                if let item = menu.item(withTitle: title) {
                    menu.removeItem(item)
                }
            }
        }
    }
}

@main
struct ZudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var appState = AppState()

    init() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            // Set dock icon from bundled assets (works for both Xcode and make run)
            if let url = Bundle.main.resourceURL?
                .appendingPathComponent("assets/images/icon/zudio-icon.icns"),
               let icon = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = icon
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.playback)  // MIDILaneView observes directly — no AppState cascade on each step
        }
        .windowStyle(.titleBar)
        .commands {
            // App menu: wire "About Zudio" to our custom AboutView
            CommandGroup(replacing: .appInfo) {
                Button("About Zudio") {
                    appState.triggerShowAbout.toggle()
                }
            }

            // File menu: Generate New + Save MIDI
            CommandGroup(replacing: .newItem) {
                Button("Generate New") {
                    appState.generateNew()
                }
                .keyboardShortcut("g", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Load Song") {
                    appState.loadFromLog()
                }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(appState.isGenerating)

                Divider()

                Button("Save MIDI") {
                    appState.saveMIDI()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.songState == nil)

                Button("Export Audio") {
                    appState.requestExport()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.songState == nil || appState.isExportingAudio)
            }

            // Empty out Edit menu groups so the menu is blank before removal.
            // NOTE: .pasteboard must NOT be replaced — SwiftUI's .textSelection relies on it for ⌘C.
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .textFormatting) {}

            // Empty out Window menu groups
            CommandGroup(replacing: .windowSize) {}
            CommandGroup(replacing: .windowArrangement) {}
            CommandGroup(replacing: .singleWindowList) {}

            // Help menu: single "Zudio Help" item that opens our HelpView sheet
            CommandGroup(replacing: .help) {
                Button("Zudio Help") {
                    appState.triggerShowHelp.toggle()
                }
                .keyboardShortcut("/", modifiers: .command)
            }
        }
    }
}
