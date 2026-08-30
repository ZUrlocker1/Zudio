// ZudioApp.swift — @main entry point
// Copyright (c) 2026 Zack Urlocker 

import SwiftUI
#if os(macOS)
import AppKit
import os
#endif

#if os(macOS)
// DIAGNOSTIC LOGGING — Messages "Open with Zudio" cold-launch window bug (2026).
// Set to false (or delete this + call sites in AppDelegate) once the investigation is done.
// Visible in Console.app: subsystem "com.zudio.app", category "AppOpen".
let kAppOpenDebugLog = false
let appOpenLogger = Logger(subsystem: "com.zudio.app", category: "AppOpen")
#endif

#if os(macOS)
/// Captures SwiftUI's `openWindow` action so AppDelegate (a plain NSObject outside the
/// SwiftUI environment) can ask SwiftUI itself to create the WindowGroup's window.
///
/// Root cause (confirmed via logging, 2026): on a cold launch where macOS delivers a
/// pending "open this document" request (e.g. Messages' "Open with Zudio", or a Finder
/// double-click on a .zudio file), SwiftUI never creates its default WindowGroup window at
/// all — `NSApp.windows.count` stays 0 for the process's entire lifetime until it quits
/// itself. A plain app launch with no pending document reliably gets a window. This is
/// consistent with Info.plist declaring `CFBundleTypeRole = Editor` for .zudio files
/// without any real NSDocument/DocumentGroup backing it — macOS defers to "the document
/// will supply its own window," which never happens here.
///
/// Set from `ZudioApp.body`, which SwiftUI re-evaluates with a real environment context
/// even before any window exists. Called from `application(_:open:)` only when
/// `application.windows` is empty, so it's a no-op (and can't cause a duplicate window)
/// on every already-working path.
nonisolated(unsafe) var zudioOpenWindowAction: (() -> Void)?
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        if kAppOpenDebugLog {
            appOpenLogger.notice("applicationShouldTerminateAfterLastWindowClosed — windows.count=\(sender.windows.count, privacy: .public)")
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if kAppOpenDebugLog {
            appOpenLogger.notice("applicationWillTerminate — windows.count=\(NSApp.windows.count, privacy: .public)")
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        if kAppOpenDebugLog {
            appOpenLogger.notice("applicationWillFinishLaunching — windows.count=\(NSApp.windows.count, privacy: .public)")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if kAppOpenDebugLog {
            appOpenLogger.notice("applicationDidFinishLaunching — windows.count=\(NSApp.windows.count, privacy: .public)")
        }
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

        // DIAGNOSTIC LOGGING — delayed re-checks to see whether the WindowGroup's default
        // window ever appears after this point, or whether it's truly never created, and
        // whether the process is still alive when it would/should appear. Purely additive —
        // no behavior change. Delete alongside the rest of the kAppOpenDebugLog block.
        if kAppOpenDebugLog {
            for delay in [0.5, 2.0, 5.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    appOpenLogger.notice("delayed check +\(delay, format: .fixed(precision: 1), privacy: .public)s — windows.count=\(NSApp.windows.count, privacy: .public) isActive=\(NSApp.isActive, privacy: .public)")
                }
            }
        }

        // Window setup — async because windows aren't fully initialised at this point.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let content = NSApp.windows.filter { !($0 is NSPanel) }
            if kAppOpenDebugLog {
                appOpenLogger.notice("post-launch async tick — windows.count=\(NSApp.windows.count, privacy: .public) content.count=\(content.count, privacy: .public)")
            }
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
        if kAppOpenDebugLog {
            appOpenLogger.notice("applicationShouldHandleReopen — hasVisibleWindows=\(flag, privacy: .public) windows.count=\(sender.windows.count, privacy: .public)")
        }
        if flag {
            sender.windows.first(where: { $0.isVisible && !($0 is NSPanel) })?.makeKeyAndOrderFront(nil)
        }
        return !flag
    }

    /// Called by macOS when the user double-clicks a .zudio file in Finder, or when another
    /// app (e.g. Messages' "Open with Zudio") asks us to open one.
    ///
    /// REVERTED to the original, known-good logic (2026) after a retry/broadened-window-match
    /// attempt at fixing the Messages cold-launch case caused a worse regression (no window on
    /// EITHER Finder or Messages cold-launch). Logging is kept so we can diagnose properly
    /// before touching this again — see kAppOpenDebugLog above.
    func application(_ application: NSApplication, open urls: [URL]) {
        if kAppOpenDebugLog {
            appOpenLogger.notice("application(_:open:) ENTRY — urls=\(urls.map(\.lastPathComponent).joined(separator: ","), privacy: .public) windows.count=\(application.windows.count, privacy: .public) isActive=\(application.isActive, privacy: .public)")
        }
        guard let url = urls.first else { return }
        if let window = application.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
            application.activate(ignoringOtherApps: true)
        } else if application.windows.isEmpty {
            // Confirmed via logging: on a cold launch with a pending open-document request,
            // SwiftUI never creates its default WindowGroup window on its own. Ask SwiftUI's
            // own window-management API to create one, rather than poking NSWindow directly.
            if kAppOpenDebugLog {
                appOpenLogger.notice("application(_:open:) — no window, invoking zudioOpenWindowAction (present=\(zudioOpenWindowAction != nil, privacy: .public))")
            }
            zudioOpenWindowAction?()
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
    @Environment(\.openWindow) private var openWindow
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
        #if os(macOS)
        // Re-captured every time body is evaluated (idempotent) — see zudioOpenWindowAction's
        // doc comment above for why AppDelegate needs this instead of creating an NSWindow itself.
        // id: "main" matches the WindowGroup(id:) below — this SDK's OpenWindowAction has no
        // plain no-argument overload.
        let _ = { zudioOpenWindowAction = { openWindow(id: "main") } }()
        #endif
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.playback)
                #if os(iOS)
                .onOpenURL { url in
                    _ = url.startAccessingSecurityScopedResource()
                    appState.loadFromLogURL(url)
                }
                #endif
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
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                    .disabled(appState.isGenerating)

                Divider()

                Button("Save Song") { appState.saveMIDI() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(appState.songState == nil)

                Button("Export Audio") { appState.requestFastExport() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(appState.songState == nil || appState.isExportingAudio)

                Button("Share Song…") { appState.shareSongMac() }
                    .disabled(appState.songState == nil)

                Divider()

                Menu("Sleep Timer") {
                    Picker("Sleep Timer", selection: Binding(
                        get: { appState.sleepTimerDuration },
                        set: { appState.setSleepTimer($0) }
                    )) {
                        ForEach(SleepTimerDuration.allCases, id: \.self) { dur in
                            Text(dur.rawValue).tag(dur)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
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

                Button("Song List") { appState.macShowSongList.toggle() }
                    .keyboardShortcut("i", modifiers: .command)
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
