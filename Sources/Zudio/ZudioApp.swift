// ZudioApp.swift — @main entry point

import SwiftUI
import AppKit

// Quit the app when the last window closes (window-close = full exit, not just hide)
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
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
            CommandGroup(replacing: .newItem) {
                Button("Generate New") {
                    appState.generateNew()
                }
                .keyboardShortcut("g", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save MIDI") {
                    appState.saveMIDI()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.songState == nil)
            }
        }
    }
}
