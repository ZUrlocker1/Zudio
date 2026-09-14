// SharedSongInbox.swift — hand-off point between the Share Extension and the main app.
//
// The Share Extension runs in its own process with its own sandbox and cannot talk to the
// app directly. Both sides get access to one shared container via the App Group, so the
// extension drops the incoming .zudio file there and the app picks it up.
//
// COMPILED INTO BOTH TARGETS (ZudioiOS and ZudioShare). Keep it Foundation-only — no
// UIKit, no SwiftUI, nothing app-specific — or the extension will not build.

import Foundation

enum SharedSongInbox {

    /// Must match the App Group enabled on BOTH targets in Signing & Capabilities,
    /// and the value in both .entitlements files.
    static let appGroupID = "group.com.zudio.app"

    /// URL scheme the extension uses to ask the system to launch the app.
    /// Declared in CFBundleURLTypes in iOS-Info.plist.
    static let launchURL = URL(string: "zudio://open")

    private static let folderName = "Inbox"

    static var inboxURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    // MARK: - Extension side

    /// Copies an incoming song into the shared container. Must be called synchronously
    /// inside NSItemProvider's completion handler — the source file is a temporary the
    /// system deletes as soon as that handler returns.
    @discardableResult
    static func deposit(from source: URL) -> URL? {
        guard let dir = inboxURL else { return nil }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let destination = dir.appendingPathComponent(source.lastPathComponent)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    // MARK: - App side

    /// The most recently deposited song, if the extension left one waiting.
    static func pendingSong() -> URL? {
        guard let dir = inboxURL,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return nil }

        return items
            .filter { $0.pathExtension.lowercased() == "zudio" }
            .max { modified($0) < modified($1) }
    }

    /// Removes a song once the app has loaded it, so it is not re-opened on next launch.
    static func clear(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
    }
}
