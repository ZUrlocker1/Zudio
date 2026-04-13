// ZudioApp.swift — @main entry point

import SwiftUI
#if os(macOS)
import AppKit
#endif

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

// MARK: - Menu sweeper (macOS only)

// Items that AppKit injects into the View submenu that Zudio doesn't want.
// Checked by title — works regardless of localization changes to our own items.
#if os(macOS)
private let kViewMenuUnwanted: Set<String> = [
    "Show Tab Bar", "Hide Tab Bar", "Show All Tabs", "New Tab",
    "Enter Full Screen", "Exit Full Screen",
    "Show Sidebar", "Hide Sidebar",
    "Show Toolbar", "Hide Toolbar", "Customize Toolbar…",
]

/// Single delegate/sweeper used for both NSApp.mainMenu and the View submenu.
/// NSMenu holds a weak reference — AppDelegate owns this object strongly.
private final class MenuSweeper: NSObject, NSMenuDelegate {

    // Called right before a menu is displayed — guaranteed last word before the user sees it.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === NSApp.mainMenu {
            pruneMainMenu(menu)
        } else {
            pruneViewSubmenu(menu)
        }
    }

    // MARK: - Targeted sweeps

    func pruneMainMenu(_ menu: NSMenu) {
        for title in ["Format", "Window"] {
            menu.item(withTitle: title).map { menu.removeItem($0) }
        }
        // Keep the View submenu delegate current — SwiftUI may have rebuilt the submenu object.
        reattachViewSubmenuDelegate(in: menu)
    }

    func pruneViewSubmenu(_ menu: NSMenu) {
        for item in menu.items where kViewMenuUnwanted.contains(item.title) {
            menu.removeItem(item)
        }
        // Remove orphaned separators at top and bottom
        while menu.items.first?.isSeparatorItem == true { menu.removeItem(at: 0) }
        while let last = menu.items.last, last.isSeparatorItem {
            menu.removeItem(at: menu.items.count - 1)
        }
    }

    func reattachViewSubmenuDelegate(in mainMenu: NSMenu) {
        if let viewMenu = mainMenu.item(withTitle: "View")?.submenu,
           viewMenu.delegate !== self {
            viewMenu.delegate = self
        }
    }
}

// MARK: - AppDelegate

// Quit the app when the last window closes (window-close = full exit, not just hide)
private final class AppDelegate: NSObject, NSApplicationDelegate {
    // Owned strongly here — NSMenu only holds a weak reference to its delegate.
    private let sweeper = MenuSweeper()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Attach sweeper as main menu delegate — fires right before menu bar is displayed.
        NSApp.mainMenu?.delegate = sweeper
        // Also attach to View submenu immediately if it already exists.
        if let viewMenu = NSApp.mainMenu?.item(withTitle: "View")?.submenu {
            viewMenu.delegate = sweeper
        }

        // Broad notification observer — catches unwanted items the instant they're added
        // to ANY menu in the app, including the View submenu during SwiftUI rebuilds.
        // Correct userInfo key is "NSMenuItemIndex" (NSNumber), not "NSMenuItem".
        NotificationCenter.default.addObserver(
            forName: NSMenu.didAddItemNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let idx  = note.userInfo?["NSMenuItemIndex"] as? Int,
                  let srcMenu = note.object as? NSMenu,
                  idx >= 0, idx < srcMenu.items.count else { return }

            let addedItem = srcMenu.items[idx]

            if srcMenu === NSApp.mainMenu {
                // Top-level: remove Format and Window.
                if addedItem.title == "Format" || addedItem.title == "Window" {
                    srcMenu.removeItem(addedItem)
                }
                // Re-attach sweeper if SwiftUI rebuilt the menu object.
                if srcMenu.delegate == nil { srcMenu.delegate = self.sweeper }
                // Re-attach to View submenu in case SwiftUI rebuilt it too.
                self.sweeper.reattachViewSubmenuDelegate(in: srcMenu)
            } else {
                // Any other menu (typically the View submenu): remove known unwanted items.
                if kViewMenuUnwanted.contains(addedItem.title) {
                    srcMenu.removeItem(addedItem)
                }
                // If this turns out to be the View submenu with no delegate, attach now.
                if srcMenu.delegate == nil,
                   srcMenu === NSApp.mainMenu?.item(withTitle: "View")?.submenu {
                    srcMenu.delegate = self.sweeper
                }
            }
        }

        // Window setup — async because windows aren't fully initialised at this point.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let content = NSApp.windows.filter { !($0 is NSPanel) }
            content.forEach { win in
                win.isRestorable = false
                // minSize must be the window FRAME size (includes title bar).
                win.minSize = win.frameRect(forContentRect: NSRect(
                    origin: .zero,
                    size:   NSSize(width: 650, height: kCompactContentHeight)
                )).size
                // Disallow tabbing — prevents "Show Tab Bar / New Tab" menu items.
                // (NSWindow.allowsAutomaticWindowTabbing = false in init() covers the
                // class-level default; this is per-window belt-and-suspenders.)
                win.tabbingMode = .disallowed
                // Opt out of full screen — prevents "Enter Full Screen" menu item and
                // removes the green button's full-screen affordance.
                win.collectionBehavior.remove(.fullScreenPrimary)
                win.collectionBehavior.insert(.fullScreenNone)
            }
            // Keep only the first content window; close any duplicates from state restore.
            content.dropFirst().forEach { $0.close() }
            // Run a manual sweep now that windows exist and menus are fully built.
            self.sweepAll()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        sweepAll()
        NotificationCenter.default.post(name: .zudioClaimNowPlaying, object: nil)
        // Re-enforce minimum window size in case SwiftUI's layout pass reset it.
        NSApp.windows.filter { !($0 is NSPanel) }.forEach {
            let reqMin = $0.frameRect(forContentRect: NSRect(
                origin: .zero,
                size:   NSSize(width: 650, height: kCompactContentHeight)
            )).size
            if $0.minSize.width < reqMin.width || $0.minSize.height < reqMin.height {
                $0.minSize = reqMin
            }
        }
    }

    /// Prevent a new window from opening when the user clicks the Dock icon
    /// while the app is already running and has a visible window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            sender.windows.first(where: { $0.isVisible && !($0 is NSPanel) })?.makeKeyAndOrderFront(nil)
        }
        return !flag
    }

    /// Called by macOS when the user double-clicks a .zudio file in Finder.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if let window = application.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
            application.activate(ignoringOtherApps: true)
        }
        Notification.Name.zudioPendingOpenURL = url
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .zudioOpenFile, object: url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard Notification.Name.zudioPendingOpenURL != nil else { return }
            Notification.Name.zudioPendingOpenURL = nil
            NotificationCenter.default.post(name: .zudioOpenFile, object: url)
        }
    }

    // MARK: - Sweep helpers

    /// Full menu-bar sweep: re-attaches delegates and manually prunes all known unwanted items.
    /// Called at launch (after window setup) and on every activation.
    private func sweepAll() {
        guard let mainMenu = NSApp.mainMenu else { return }

        // Re-attach main menu delegate.
        if mainMenu.delegate == nil { mainMenu.delegate = sweeper }

        // Hide Edit (don't remove — ⌘C etc. rely on its responder-chain presence).
        mainMenu.item(withTitle: "Edit").map { $0.isHidden = true }

        // Remove Format and Window entirely.
        for title in ["Format", "Window"] {
            mainMenu.item(withTitle: title).map { mainMenu.removeItem($0) }
        }

        // Clean the View submenu and (re-)attach its delegate.
        if let viewMenu = mainMenu.item(withTitle: "View")?.submenu {
            if viewMenu.delegate == nil { viewMenu.delegate = sweeper }
            sweeper.pruneViewSubmenu(viewMenu)
        }
    }
}
#endif

// MARK: - App entry point

@main
struct ZudioApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #endif
    @StateObject private var appState = AppState()

    init() {
        #if os(macOS)
        // Disable automatic window tabbing at the class level BEFORE any window is created.
        // This is the only reliable way to prevent "Show Tab Bar / New Tab" from appearing —
        // per-window tabbingMode = .disallowed is set async and races with menu construction.
        NSWindow.allowsAutomaticWindowTabbing = false

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let url = Bundle.main.resourceURL?
                .appendingPathComponent("assets/images/zudio-icon.icns"),
               let icon = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = icon
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.playback)
        }
        .handlesExternalEvents(matching: [])
        #if os(macOS)
        .defaultSize(width: 1175, height: 775)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Zudio") { appState.triggerShowAbout.toggle() }
            }

            CommandGroup(replacing: .newItem) {
                Button("Generate New") { appState.generateNew(thenPlay: true) }
                    .keyboardShortcut("g", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Load Song") { appState.loadFromLog() }
                    .keyboardShortcut("l", modifiers: .command)
                    .disabled(appState.isGenerating)

                Divider()

                Button("Save Song") { appState.saveMIDI() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(appState.songState == nil)

                Button("Export Audio") { appState.requestExport() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(appState.songState == nil || appState.isExportingAudio)
            }

            // View menu — uses .toolbar slot so it injects into the existing system View menu.
            // Static labels keep these buttons out of SwiftUI's @Published observation graph
            // so they don't trigger unnecessary menu rebuilds during playback.
            CommandGroup(replacing: .toolbar) {
                Button("Compact / Expand") { appState.toggleWindowCompact() }
                    .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Visualizer / Tracks") { appState.macShowVisualizer.toggle() }
                    .keyboardShortcut("z", modifiers: .command)
            }

            // Empty out Edit menu groups (menu itself stays hidden for ⌘C responder chain).
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .textFormatting) {}

            // Empty out Window menu groups so it collapses to nothing (then removed entirely).
            CommandGroup(replacing: .windowSize) {}
            CommandGroup(replacing: .windowArrangement) {}
            CommandGroup(replacing: .singleWindowList) {}

            CommandGroup(replacing: .help) {
                Button("Zudio Help") { appState.triggerShowHelp.toggle() }
                    .keyboardShortcut("/", modifiers: .command)
            }
        }
        #endif
    }
}
