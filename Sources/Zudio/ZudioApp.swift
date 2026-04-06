// ZudioApp.swift — @main entry point

import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted by AppDelegate when Finder asks us to open a .zudio file.
    /// Object is the URL. AppState observes this and loads the file into the
    /// existing window rather than opening a second instance.
    static let zudioOpenFile = Notification.Name("zudioOpenFile")

    /// Posted by AppDelegate on applicationDidBecomeActive so AppState can
    /// re-assert Now Playing routing without AppDelegate needing a reference to AppState.
    static let zudioClaimNowPlaying = Notification.Name("zudioClaimNowPlaying")

    /// Holds the URL from the most recent file-open request while AppState may still be
    /// initialising.  AppState clears this on first receipt so the 0.5 s fallback post
    /// in AppDelegate is a no-op once the URL has been handled.
    nonisolated(unsafe) static var zudioPendingOpenURL: URL? = nil
}

// Quit the app when the last window closes (window-close = full exit, not just hide)
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        removeUnwantedMenus()

        // macOS State Restoration can re-open the previous session window alongside the new one,
        // giving two windows on startup. Mark all windows non-restorable and close any extras.
        DispatchQueue.main.async {
            let content = NSApp.windows.filter { !($0 is NSPanel) }
            content.forEach { $0.isRestorable = false }
            // Keep only the first content window; close any duplicates from state restore.
            content.dropFirst().forEach { $0.close() }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Re-apply removals in case SwiftUI rebuilds menus after activation.
        removeUnwantedMenus()
        // Re-claim Now Playing routing whenever Zudio comes to front.
        // Browsers continuously update their playbackState while media is playing;
        // re-asserting here ensures Zudio owns F8 whenever it is the active app.
        NotificationCenter.default.post(name: .zudioClaimNowPlaying, object: nil)
    }

    /// Prevent a new window from opening when the user clicks the Dock icon
    /// while the app is already running and has a visible window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            sender.windows.first(where: { $0.isVisible && !($0 is NSPanel) })?.makeKeyAndOrderFront(nil)
        }
        return !flag
    }

    /// Called by macOS when the user double-clicks a .zudio file in Finder, both when Zudio
    /// is already running and when macOS launches it fresh to open the file.
    /// On fresh launch, SwiftUI may not have finished creating AppState (and its notification
    /// observer) by the time this fires.  We therefore:
    ///   1. Post immediately — handles the already-running case where AppState is ready.
    ///   2. Store the URL and re-post after 0.5 s — handles fresh launch where SwiftUI's
    ///      @StateObject init races with this callback.  AppState clears pendingOpenURL on
    ///      first receipt so the fallback post is a no-op once the URL is handled.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if let window = application.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
            application.activate(ignoringOtherApps: true)
        }
        Notification.Name.zudioPendingOpenURL = url
        // Immediate post — works when app is already running.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .zudioOpenFile, object: url)
        }
        // Fallback post — for fresh launch where AppState may not be ready yet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard Notification.Name.zudioPendingOpenURL != nil else { return }
            Notification.Name.zudioPendingOpenURL = nil
            NotificationCenter.default.post(name: .zudioOpenFile, object: url)
        }
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
        // Prevent WindowGroup from opening a second window when a .zudio file is opened.
        // File loading is handled entirely by AppDelegate.application(_:open:) → zudioOpenFile notification.
        .handlesExternalEvents(matching: [])
        .windowStyle(.titleBar)
        .commands {
            // App menu: wire "About Zudio" to our custom AboutView
            CommandGroup(replacing: .appInfo) {
                Button("About Zudio") {
                    appState.triggerShowAbout.toggle()
                }
            }

            // File menu: Generate New + Save Song
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

                Button("Save Song") {
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
