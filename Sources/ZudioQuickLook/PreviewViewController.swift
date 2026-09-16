// PreviewViewController.swift — Quick Look Preview Extension for .zudio songs.
//
// WHY THIS EXISTS
// ---------------
// iOS 26 and 27 will not open a .zudio attachment from Messages. Two days of testing
// (see the note in iOS-Info.plist) established it is not a Zudio bug — a plain .txt
// behaves identically, the same build works on iOS 18 and on Mac, and the official
// App Store build fails exactly like a local one.
//
// This is the last untested mechanism, and it only makes sense paired with the OPAQUE
// file type (public.data + public.content):
//
//   text-conforming type -> iOS uses its own text previewer and never consults us
//   opaque type, no previewer -> nothing can render the file, attachment goes inert
//   opaque type + THIS -> Zudio is the only thing that can preview a .zudio, which is
//                         the only arrangement where the system has a reason to
//                         associate the preview (and an open affordance) with the app
//
// A .zudio file is a UTF-8 analysis log written by SongLogExporter.buildLog, so the
// preview is just that text in a monospaced view — no parsing needed.

import UIKit
import QuickLook

final class PreviewViewController: UIViewController, QLPreviewingController {

    private let textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        tv.backgroundColor = .systemBackground
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        // The log is small (~2-3 KB) so reading it synchronously here is fine.
        do {
            let data = try Data(contentsOf: url)
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? "(unreadable)"
            textView.text = text
            handler(nil)
        } catch {
            handler(error)
        }
    }
}
