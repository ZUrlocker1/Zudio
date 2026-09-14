// ShareViewController.swift — Share Extension principal class.
//
// WHY THIS EXISTS
// ---------------
// iOS 18 showed an "Open in Zudio" chip when you tapped a .zudio attachment in Messages.
// iOS 26 removed it. Verified Sept 2026 with an identical build on 18.x and 26.2, and no
// UTI declaration brings it back (see the comment in iOS-Info.plist for what was ruled
// out). The only remaining route from a Messages attachment into an app is the share
// sheet inside Quick Look, and that is populated by Share Extensions.
//
// WHAT THIS IS TESTING
// --------------------
// Two open questions this target exists to answer on a real device:
//   1. Does Zudio actually appear in the share sheet reached from a Messages attachment?
//   2. Does NSExtensionContext.open() launch the app? It is documented for app extensions
//      but has historically been unreliable for share extensions specifically. If it does
//      not fire, the song still lands in the shared container and the app picks it up on
//      next launch — worse UX, but not broken.
//
// Deliberately has no UI. It takes the file, hands it off, and dismisses.

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    /// Must match LSItemContentTypes / UTTypeIdentifier in iOS-Info.plist.
    private static let zudioUTI = "com.zudio.song"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        acceptSharedSong()
    }

    private func acceptSharedSong() {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let provider = items
            .compactMap(\.attachments)
            .flatMap { $0 }
            .first { $0.hasItemConformingToTypeIdentifier(Self.zudioUTI) }

        guard let provider else {
            finish(deposited: false)
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: Self.zudioUTI) { [weak self] url, _ in
            // Copy synchronously: `url` is a temporary the system reclaims when this
            // handler returns.
            let deposited = url.flatMap { SharedSongInbox.deposit(from: $0) } != nil
            DispatchQueue.main.async { self?.finish(deposited: deposited) }
        }
    }

    private func finish(deposited: Bool) {
        if deposited, let launchURL = SharedSongInbox.launchURL {
            extensionContext?.open(launchURL, completionHandler: nil)
        }
        extensionContext?.completeRequest(returningItems: nil)
    }
}
