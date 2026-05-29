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
        genre: String,
        bpm: Int,
        year: Int,
        keySignature: String,
        timeSignature: String,
        encoder: String,
        comment: String
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
        items.append(iTunesItem(.iTunesMetadataKeyArtist,       artist))
        items.append(iTunesItem(.iTunesMetadataKeyAlbum,        "Greatest Hits"))
        items.append(iTunesItem(.iTunesMetadataKeyUserGenre,    genre))
        // NOTE: do NOT write BPM via AVFoundation here.
        // AVFoundation serialises NSNumber tmpo as a 64-bit integer (8-byte content, 32-byte item)
        // but Apple Music requires a 16-bit integer (2-byte content, 26-byte item).
        // injectBPM() writes the correct atom at the byte level after the session completes.
        items.append(iTunesItem(.iTunesMetadataKeyEncodingTool, encoder))
        // Raw 4-char iTunes atom codes for fields without named AVMetadataKey constants
        items.append(iTunesItem(AVMetadataKey(rawValue: "©day"), "\(year)"))    // year / release date
        items.append(iTunesItem(AVMetadataKey(rawValue: "©key"), keySignature)) // key (Logic/GarageBand; not shown in Music.app)
        items.append(iTunesItem(AVMetadataKey(rawValue: "©tmr"), timeSignature)) // time signature

        // Comment: key and time signature, plus muted-track note if any.
        // BPM is omitted here — it is written correctly to the dedicated tmpo atom by injectBPM().
        var commentParts: [String] = ["\(keySignature), \(timeSignature)"]
        if !comment.isEmpty { commentParts.append(comment) }
        items.append(iTunesItem(.iTunesMetadataKeyUserComment, commentParts.joined(separator: " — ")))

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
            // AVFoundation does not reliably write the tmpo (BPM) atom as an integer —
            // a known limitation. Patch the file at the byte level so Apple Music reads it.
            try? injectBPM(bpm, into: url)
        } else {
            try? FileManager.default.removeItem(at: tmp)
            if let err = session.error { print("Metadata export skipped: \(err)") }
        }
    }

    // MARK: - BPM byte-level injection

    /// Injects a `tmpo` (BPM) atom into an M4A file at the byte level.
    ///
    /// AVFoundation's `AVAssetExportSession` cannot write a correct tmpo atom.
    /// When given an NSNumber it emits an 8-byte (64-bit) integer with item-size=32;
    /// Apple Music requires a 2-byte (16-bit) integer with item-size=26.
    /// We therefore keep BPM out of AVFoundation metadata entirely and insert the
    /// correctly-sized atom here after the passthrough session completes.
    ///
    /// `tmpo` atom layout inside `moov.udta.meta.ilst` (26 bytes total):
    ///
    ///   Offset  Size  Content
    ///   +0      4     item size = 26
    ///   +4      4     "tmpo"
    ///   +8      4     data-box size = 18
    ///   +12     4     "data"
    ///   +16     1     version = 0x00
    ///   +17     3     flags   = 0x00 0x00 0x15  (signed integer, type 21)
    ///   +20     4     locale  = 0x00000000
    ///   +24     2     BPM as big-endian int16
    private static func injectBPM(_ bpm: Int, into url: URL) throws {
        guard bpm > 0, bpm < 32768 else { return }
        var d = try Data(contentsOf: url)
        let bpmU16 = UInt16(bpm)

        // Canonical 26-byte tmpo item with correct 16-bit integer encoding.
        let tmpoItem = Data([
            0, 0, 0, 26,                                    // item size = 26
            116, 109, 112, 111,                             // "tmpo"
            0, 0, 0, 18,                                    // data-box size = 18
            100, 97, 116, 97,                               // "data"
            0, 0, 0, 0x15,                                  // version=0, flags=integer(21)
            0, 0, 0, 0,                                     // locale = 0
            UInt8(bpmU16 >> 8), UInt8(bpmU16 & 0xFF)       // BPM as big-endian int16
        ])

        // Navigate to ilst. Try moov > udta > meta > ilst first,
        // then fall back to moov > meta > ilst (some muxers omit udta).
        guard let moov = mp4Box("moov", in: d, range: 0..<d.count) else { return }

        var ilst: Range<Int>?
        var ancestorStarts: [Int] = []   // outermost-first; all need +26

        if let udta = mp4Box("udta", in: d, range: (moov.lowerBound+8)..<moov.upperBound),
           let meta = mp4Box("meta", in: d, range: (udta.lowerBound+8)..<udta.upperBound),
           let il   = mp4Box("ilst", in: d, range: (meta.lowerBound+12)..<meta.upperBound) {
            ilst           = il
            ancestorStarts = [moov.lowerBound, udta.lowerBound, meta.lowerBound, il.lowerBound]
        } else if let meta = mp4Box("meta", in: d, range: (moov.lowerBound+8)..<moov.upperBound),
                  let il   = mp4Box("ilst", in: d, range: (meta.lowerBound+12)..<meta.upperBound) {
            ilst           = il
            ancestorStarts = [moov.lowerBound, meta.lowerBound, il.lowerBound]
        }

        guard let ilstRange = ilst else { return }

        // Insert the new tmpo at the end of ilst.
        // Since moov comes AFTER mdat in typical AVFoundation output, inserting inside
        // moov does NOT shift mdat, so stco/co64 offsets remain valid.
        let moovPrecedesMdat = moov.upperBound < d.count
        d.insert(contentsOf: tmpoItem, at: ilstRange.upperBound)

        for start in ancestorStarts {
            mp4WriteU32(mp4ReadU32(d, start) + 26, into: &d, at: start)
        }

        // Only patch chunk offsets when moov was before mdat (rare for AVFoundation output).
        if moovPrecedesMdat, let newMoov = mp4Box("moov", in: d, range: 0..<d.count) {
            mp4PatchChunkOffsets(in: newMoov, data: &d, delta: 26)
        }

        try d.write(to: url)
    }

    // MARK: - MP4 box helpers (used only by injectBPM)

    /// Read a big-endian UInt32 from `data` at byte offset `i`.
    private static func mp4ReadU32(_ data: Data, _ i: Int) -> UInt32 {
        (UInt32(data[i]) << 24) | (UInt32(data[i+1]) << 16) | (UInt32(data[i+2]) << 8) | UInt32(data[i+3])
    }

    /// Write a big-endian UInt32 into `data` at byte offset `i`.
    private static func mp4WriteU32(_ value: UInt32, into data: inout Data, at i: Int) {
        data[i]   = UInt8((value >> 24) & 0xFF)
        data[i+1] = UInt8((value >> 16) & 0xFF)
        data[i+2] = UInt8((value >>  8) & 0xFF)
        data[i+3] = UInt8( value        & 0xFF)
    }

    /// Find the first MP4 box with the given 4-char type within `range`.
    /// Returns the range of the entire box (header + content), or nil if not found.
    ///
    /// Handles the two special size values defined by ISO 14496-12:
    ///   sz == 0  — box extends to end of its parent (rare; treated as rest of range)
    ///   sz == 1  — box uses a 64-bit "largesize" field at bytes [8..15]
    ///              Layout: [size=1][fourcc][8-byte largesize][content...]
    ///              AVFoundation routinely emits mdat with largesize even for small files.
    private static func mp4Box(_ type: String, in data: Data, range: Range<Int>) -> Range<Int>? {
        let t = Array(type.utf8)
        var i = range.lowerBound
        while i + 8 <= range.upperBound {
            let szU32 = mp4ReadU32(data, i)
            let sz: Int
            if szU32 == 0 {
                // Box extends to end of parent range.
                sz = range.upperBound - i
            } else if szU32 == 1 {
                // 64-bit largesize: [size=1 (4)][fourcc (4)][largesize (8)][content…]
                guard i + 16 <= range.upperBound else { return nil }
                let hi  = UInt64(mp4ReadU32(data, i + 8))
                let lo  = UInt64(mp4ReadU32(data, i + 12))
                let s64 = (hi << 32) | lo
                guard s64 >= 16, s64 <= UInt64(range.upperBound - i) else {
                    // Box is larger than the remaining scan range; can't navigate inside,
                    // but we can skip it if we know the exact size — just give up here.
                    return nil
                }
                sz = Int(s64)
            } else {
                sz = Int(szU32)
                guard sz >= 8, i + sz <= range.upperBound else { return nil }
            }
            if data[i+4..<i+8].elementsEqual(t) { return i..<i+sz }
            i += sz
        }
        return nil
    }

    /// Adds `delta` to every chunk-offset entry in all `stco` and `co64` boxes
    /// inside `moovRange`. Called after inserting bytes into moov when moov precedes
    /// mdat — the insertion shifts mdat's absolute position, invalidating stored offsets.
    private static func mp4PatchChunkOffsets(in moovRange: Range<Int>, data d: inout Data, delta: Int) {
        var stack = [moovRange]
        while let range = stack.popLast() {
            var i = range.lowerBound + 8
            while i + 8 <= range.upperBound {
                let sz = Int(mp4ReadU32(d, i))
                guard sz >= 8, i + sz <= range.upperBound else { break }
                let type = String(bytes: d[i+4..<i+8], encoding: .isoLatin1) ?? ""
                switch type {
                case "stco":
                    let n = Int(mp4ReadU32(d, i + 12))
                    var e = i + 16
                    for _ in 0..<n {
                        let old = mp4ReadU32(d, e)
                        mp4WriteU32(old + UInt32(delta), into: &d, at: e)
                        e += 4
                    }
                case "co64":
                    let n = Int(mp4ReadU32(d, i + 12))
                    var e = i + 16
                    for _ in 0..<n {
                        let hi = UInt64(mp4ReadU32(d, e))
                        let lo = UInt64(mp4ReadU32(d, e + 4))
                        let new = ((hi << 32) | lo) + UInt64(delta)
                        mp4WriteU32(UInt32(new >> 32),         into: &d, at: e)
                        mp4WriteU32(UInt32(new & 0xFFFFFFFF),  into: &d, at: e + 4)
                        e += 8
                    }
                case "trak", "mdia", "minf", "stbl":
                    stack.append(i..<i+sz)  // recurse into container boxes on the stco path
                default:
                    break
                }
                i += sz
            }
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
