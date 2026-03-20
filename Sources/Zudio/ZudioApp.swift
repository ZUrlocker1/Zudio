// ZudioApp.swift — @main entry point

import SwiftUI
import AppKit

@main
struct ZudioApp: App {
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
        }
    }
}
