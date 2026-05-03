// AudioFileExporter.swift — song-named M4A filenames + metadata writing
// Copyright (c) 2026 Zack Urlocker

import Foundation
import AVFoundation
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct AudioFileExporter {

    // MARK: - URL generation

    /// ~/Downloads on macOS, ~/Documents on iOS — the user-visible folder for saved songs.
    static func exportDirectory() -> URL {
        #if os(macOS)
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
    }

    /// Returns ~/Downloads/Zudio-{songName}.m4a (or Zudio-{songName}-Sample.m4a),
    /// appending -2/-3/... if the file already exists.
    static func nextURL(songName: String, sampleMode: Bool = false) -> URL {
        let safe = sanitizedName(songName)
        let base = sampleMode ? "\(safe)-Sample" : safe
        return incrementingURL(in: exportDirectory(), base: base, ext: "m4a")
    }

    static func incrementingURL(in dir: URL, base: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent("\(base).\(ext)")
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base)-\(n).\(ext)")
            n += 1
        }
        return candidate
    }

    static func sanitizedName(_ raw: String) -> String {
        let kept = raw.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" || $0 == "_"
        }
        return String(String.UnicodeScalarView(kept))
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
    }

    // MARK: - macOS Save Panels

    #if os(macOS)

    // Coordinator for the radio buttons inside the Export panel.
    // Must be a class so the @objc target-action pattern compiles.
    private final class ExportPanelCoordinator: NSObject {
        let panel: NSSavePanel
        let songName: String
        private(set) var isSampleMode = false
        // Held so radioChanged can flip both buttons without traversing the view tree.
        weak var radioFull: NSButton?
        weak var radioSample: NSButton?

        init(panel: NSSavePanel, songName: String) {
            self.panel = panel
            self.songName = songName
        }

        @objc func radioChanged(_ sender: NSButton) {
            isSampleMode = sender.tag == 1
            radioFull?.state   = isSampleMode ? .off : .on
            radioSample?.state = isSampleMode ? .on  : .off
            let base = AudioFileExporter.sanitizedName(songName)
            let stem = isSampleMode ? "\(base)-Sample" : base
            panel.nameFieldStringValue = "\(stem).m4a"
        }
    }

    /// Export Audio panel — 900 pt wide, resizable, with Full Song / 60-sec Sample radio buttons.
    /// Returns (url, isSampleMode) or nil if the user cancelled.
    @MainActor
    static func presentExportPanel(songName: String, songDuration: String) -> (url: URL, sampleMode: Bool)? {
        let panel = NSSavePanel()
        panel.title = "Export Audio"
        panel.prompt = "Export"
        panel.message = "Export to an M4A audio file will take approximately \(songDuration). Alternatively you can save a 60-second sample."
        panel.allowedContentTypes = [UTType.mpeg4Audio]
        panel.canCreateDirectories = true
        panel.directoryURL = exportDirectory()
        panel.nameFieldStringValue = "\(sanitizedName(songName)).m4a"

        let coord = ExportPanelCoordinator(panel: panel, songName: songName)
        panel.accessoryView = makeExportAccessoryView(coordinator: coord)
        panel.minSize = NSSize(width: 400, height: panel.minSize.height)
        // Resize during the modal runloop — main-queue async blocks run inside the nested runloop.
        DispatchQueue.main.async { setPanelWidth(900, panel: panel) }

        // withExtendedLifetime keeps coord alive for the entire synchronous runModal() call
        // (NSButton.target is a weak reference, so coord would otherwise be freed).
        let response = withExtendedLifetime(coord) { panel.runModal() }
        guard response == .OK, let url = panel.url else { return nil }
        return (url, coord.isSampleMode)
    }

    private static func makeExportAccessoryView(coordinator: ExportPanelCoordinator) -> NSView {
        // Sized to fit content only; panel width is controlled separately via setPanelWidth.
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 44))

        let label = NSTextField(labelWithString: "Mode:")
        label.font = .systemFont(ofSize: 13)
        label.frame = NSRect(x: 0, y: 12, width: 50, height: 20)
        label.alignment = .right

        let radioFull = NSButton(radioButtonWithTitle: "Full Song",
                                 target: coordinator,
                                 action: #selector(ExportPanelCoordinator.radioChanged(_:)))
        radioFull.tag   = 0
        radioFull.state = .on   // default selection
        radioFull.frame = NSRect(x: 58, y: 10, width: 110, height: 22)

        let radioSample = NSButton(radioButtonWithTitle: "60-sec Sample",
                                   target: coordinator,
                                   action: #selector(ExportPanelCoordinator.radioChanged(_:)))
        radioSample.tag   = 1
        radioSample.state = .off
        radioSample.frame = NSRect(x: 176, y: 10, width: 140, height: 22)

        coordinator.radioFull   = radioFull
        coordinator.radioSample = radioSample

        container.addSubview(label)
        container.addSubview(radioFull)
        container.addSubview(radioSample)
        return container
    }

    /// Fast Export panel — simple save panel, no duration estimate or mode options.
    /// Returns the chosen .m4a URL, or nil if the user cancelled.
    @MainActor
    static func presentFastExportPanel(songName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Fast Export Audio"
        panel.prompt = "Export"
        panel.allowedContentTypes = [UTType.mpeg4Audio]
        panel.canCreateDirectories = true
        panel.directoryURL = exportDirectory()
        panel.nameFieldStringValue = "\(sanitizedName(songName)).m4a"
        panel.minSize = NSSize(width: 400, height: panel.minSize.height)
        DispatchQueue.main.async { setPanelWidth(900, panel: panel) }
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Save Song panel — shows .zudio as the primary filename; saveMIDI() derives the .MID path.
    /// Returns the chosen .zudio URL, or nil if the user cancelled.
    @MainActor
    static func presentSaveSongPanel(songName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Song"
        panel.prompt = "Save"
        panel.message = "Saves a Zudio song and a MIDI file you can open in any DAW to the same folder."
        panel.canCreateDirectories = true
        panel.directoryURL = exportDirectory()
        panel.nameFieldStringValue = "\(sanitizedName(songName)).zudio"
        panel.minSize = NSSize(width: 400, height: panel.minSize.height)
        DispatchQueue.main.async { setPanelWidth(900, panel: panel) }
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Centers the panel on screen at the given width. Called async during the modal runloop.
    private static func setPanelWidth(_ width: CGFloat, panel: NSSavePanel) {
        var f = panel.frame
        guard abs(f.size.width - width) > 1 else { return }
        f.origin.x += (f.size.width - width) / 2
        f.size.width = width
        panel.setFrame(f, display: true, animate: false)
    }

    #endif

    // MARK: - Metadata

    /// Adds iTunes-style metadata to an existing M4A file.
    /// Uses AVAssetExportPresetPassthrough — audio data is not re-encoded.
    /// Best-effort: if the export session fails the original file is left untouched.
    static func addMetadata(
        to url: URL,
        title: String,
        artist: String,
        genre: String
    ) async {
        let asset = AVURLAsset(url: url)

        // Passthrough re-containers the audio without re-encoding it
        guard let session = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPresetPassthrough) else { return }

        var items: [AVMetadataItem] = []

        func iTunesItem(_ key: AVMetadataKey, _ value: String) -> AVMutableMetadataItem {
            let i = AVMutableMetadataItem()
            i.keySpace = .iTunes
            i.key      = key as NSString
            i.value    = value as NSString
            return i
        }

        items.append(iTunesItem(.iTunesMetadataKeySongName,     title))
        items.append(iTunesItem(.iTunesMetadataKeyArtist,      artist))
        items.append(iTunesItem(.iTunesMetadataKeyAlbum,       "Greatest Hits"))
        items.append(iTunesItem(.iTunesMetadataKeyUserGenre,   genre))

        // Album art — rendered from the bundled app icon
        if let artData = await MainActor.run(resultType: Data?.self, body: appIconPNGData) {
            let art = AVMutableMetadataItem()
            art.keySpace = .iTunes
            art.key      = AVMetadataKey.iTunesMetadataKeyCoverArt as NSString
            art.value    = artData as NSData
            items.append(art)
        }

        let tmp = url.deletingLastPathComponent()
                     .appendingPathComponent(".zudio_meta_tmp_\(url.lastPathComponent)")

        session.outputURL      = tmp
        session.outputFileType = .m4a
        session.metadata       = items

        await session.export()

        if session.status == .completed {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.moveItem(at: tmp, to: url)
        } else {
            try? FileManager.default.removeItem(at: tmp)
            if let err = session.error { print("Metadata export skipped: \(err)") }
        }
    }

    // Must run on main thread (NSImage/NSGraphicsContext are main-thread-only).
    @MainActor
    private static func appIconPNGData() -> Data? {
        #if !os(macOS)
        return nil
        #else
        let paths = ["assets/images/zudio-icon.icns", "Resources/assets/images/zudio-icon.icns"]
        var img: NSImage?
        if let base = Bundle.main.resourceURL {
            for p in paths {
                if let loaded = NSImage(contentsOf: base.appendingPathComponent(p)) {
                    img = loaded; break
                }
            }
        }
        if img == nil,
           let url = Bundle.main.url(forResource: "zudio-icon", withExtension: "icns") {
            img = NSImage(contentsOf: url)
        }
        guard let image = img else { return nil }

        let side = 500
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
        #endif
    }
}
