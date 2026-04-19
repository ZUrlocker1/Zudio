// AudioFileExporter.swift — song-named M4A filenames + metadata writing

import Foundation
import AVFoundation
#if os(macOS)
import AppKit
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
