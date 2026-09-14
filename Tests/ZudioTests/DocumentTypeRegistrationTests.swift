// DocumentTypeRegistrationTests.swift — guards the .zudio document-type registration.
//
// Run with:
//   xcodebuild test -scheme Zudio -only-testing:ZudioTests/DocumentTypeRegistrationTests
//
// WHY THIS EXISTS
// ---------------
// The .zudio file association broke three separate times, each in a commit about
// something unrelated, each undocumented:
//
//   50d8973  Mac UTI deliberately set to [public.plain-text, public.data] so Finder
//            and Quick Look would preview .zudio files as text. This is the intent.
//   f0a1515  (Build 103) Silently dropped to [public.data] inside a commit about Chill
//            instruments and the Sleep Timer. public.data does NOT conform to
//            public.text, so Quick Look text preview was lost.
//   4ab8c81  (Build 116) Changed to [public.json] inside a commit about Kosmic/Chill/
//            Ambient musical improvements. Text preview came back by accident, because
//            public.json happens to conform to public.text.
//   6639de0  (Build 108) iOS bundle ID com.zudio.app.ios -> com.zudio.app inside a
//            commit about Ambient and Math Rock. Intentional (Universal purchase
//            requires the Mac and iOS apps to share one bundle ID), but it means the
//            two Info.plists can no longer disagree without confusing Launch Services.
//
// These tests pin the current, known-good declarations. They are deliberately strict:
// any edit to either plist fails a test, forcing a conscious decision instead of a
// silent regression. If you are changing the declarations on purpose, update the
// expected values below and say why in docs/change-log.md.

import Testing
import Foundation

struct DocumentTypeRegistrationTests {

    // MARK: - Locating the plists

    /// Repo root, derived from this file's location (Tests/ZudioTests/ -> up 3).
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ZudioTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
    }

    private static var macPlistURL: URL {
        repoRoot.appendingPathComponent("Sources/Zudio/Info.plist")
    }

    private static var iosPlistURL: URL {
        repoRoot.appendingPathComponent("Sources/Zudio/iOS-Info.plist")
    }

    private static func loadPlist(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = obj as? [String: Any] else {
            throw PlistError.notADictionary(url.lastPathComponent)
        }
        return dict
    }

    private enum PlistError: Error { case notADictionary(String) }

    /// The single exported declaration for com.zudio.song, or nil.
    private static func zudioExportedType(_ plist: [String: Any]) -> [String: Any]? {
        let declarations = plist["UTExportedTypeDeclarations"] as? [[String: Any]] ?? []
        return declarations.first { $0["UTTypeIdentifier"] as? String == kZudioUTI }
    }

    /// The document-type entry that claims com.zudio.song, or nil.
    private static func zudioDocumentType(_ plist: [String: Any]) -> [String: Any]? {
        let types = plist["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        return types.first {
            ($0["LSItemContentTypes"] as? [String])?.contains(kZudioUTI) ?? false
        }
    }

    private static let kZudioUTI = "com.zudio.song"

    /// Types that carry Quick Look / Finder text preview. A .zudio file is a UTF-8
    /// analysis log written by SongLogExporter.buildLog, so it must stay text-conforming
    /// or Zack loses spacebar preview in Finder and inline preview on iOS.
    private static let textConformingTypes: Set<String> = [
        "public.plain-text", "public.utf8-plain-text", "public.text", "public.json",
    ]

    // MARK: - Pinned declarations
    //
    // The Mac and iOS plists declare DIFFERENT conformance ON PURPOSE. Do not unify them.
    //
    //   Mac: com.zudio.song -> public.json -> public.text -> public.data
    //        Text-conforming, so Finder Quick Look previews as text and Open With offers
    //        TextEdit and friends. Verified via `mdls -name kMDItemContentTypeTree`.
    //
    //   iOS: com.zudio.song -> public.data, public.content
    //        NOT text-conforming. On iOS 26 Messages cannot open a text attachment at all
    //        (a plain .txt behaves the same), so the only thing conformance still affects
    //        is the label: text conformance makes Messages resolve up to public.plain-text
    //        and say "Text Document", while an opaque type lets UTTypeDescription through
    //        and it reads "Zudio Song". The cost is no inline preview on iPhone/iPad.

    private static let expectedMacConformance: Set<String> = ["public.json"]
    private static let expectedIOSConformance: Set<String> = ["public.data", "public.content"]

    // MARK: - Exported UTI declaration

    @Test func macExportsZudioUTI() throws {
        let plist = try Self.loadPlist(Self.macPlistURL)
        let decl = try #require(Self.zudioExportedType(plist),
                                "Mac Info.plist must export \(Self.kZudioUTI)")

        let conforms = Set(decl["UTTypeConformsTo"] as? [String] ?? [])
        #expect(conforms == Self.expectedMacConformance,
                "Mac UTTypeConformsTo changed to \(conforms.sorted()). If intentional, update expectedMacConformance.")

        let tags = decl["UTTypeTagSpecification"] as? [String: Any] ?? [:]
        let extensions = tags["public.filename-extension"] as? [String] ?? []
        #expect(extensions == ["zudio"], "Mac filename-extension must be exactly [\"zudio\"]")
    }

    @Test func iosExportsZudioUTI() throws {
        let plist = try Self.loadPlist(Self.iosPlistURL)
        let decl = try #require(Self.zudioExportedType(plist),
                                "iOS-Info.plist must export \(Self.kZudioUTI)")

        let conforms = Set(decl["UTTypeConformsTo"] as? [String] ?? [])
        #expect(conforms == Self.expectedIOSConformance,
                "iOS UTTypeConformsTo changed to \(conforms.sorted()). If intentional, update expectedIOSConformance.")

        let tags = decl["UTTypeTagSpecification"] as? [String: Any] ?? [:]
        let extensions = tags["public.filename-extension"] as? [String] ?? []
        #expect(extensions == ["zudio"], "iOS filename-extension must be exactly [\"zudio\"]")
    }

    // MARK: - Text preview must survive
    //
    // This is the assertion that would have caught Build 103. public.data alone is NOT
    // text-conforming, and Quick Look silently stopped previewing .zudio files as text.

    @Test func macKeepsTextPreview() throws {
        let plist = try Self.loadPlist(Self.macPlistURL)
        let decl = try #require(Self.zudioExportedType(plist))
        let conforms = Set(decl["UTTypeConformsTo"] as? [String] ?? [])

        #expect(!conforms.isDisjoint(with: Self.textConformingTypes),
                """
                Mac declares \(conforms.sorted()), none of which conform to public.text.
                .zudio files are UTF-8 logs and must stay text-previewable in Finder Quick
                Look, and openable with TextEdit via Open With.
                """)
    }

    /// The mirror of the above. iOS must NOT be text-conforming, or Messages resolves the
    /// file up to public.plain-text and labels it "Text Document" instead of "Zudio Song".
    /// See the note on expectedIOSConformance for why the platforms deliberately disagree.
    @Test func iosIsNotTextConforming() throws {
        let plist = try Self.loadPlist(Self.iosPlistURL)
        let decl = try #require(Self.zudioExportedType(plist))
        let conforms = Set(decl["UTTypeConformsTo"] as? [String] ?? [])

        #expect(conforms.isDisjoint(with: Self.textConformingTypes),
                "iOS declares \(conforms.sorted()), which conforms to text.")
    }

    // MARK: - Document type claim
    //
    // Exporting the UTI is not enough. The app must also declare that it OPENS documents
    // of that type, or it never appears in "Open in..." on either platform.

    @Test func bothPlatformsClaimTheDocumentType() throws {
        for (label, url) in [("Mac", Self.macPlistURL), ("iOS", Self.iosPlistURL)] {
            let plist = try Self.loadPlist(url)
            let docType = try #require(Self.zudioDocumentType(plist),
                                       "\(label) must claim \(Self.kZudioUTI) in CFBundleDocumentTypes")

            #expect(docType["CFBundleTypeRole"] as? String == "Editor",
                    "\(label) CFBundleTypeRole must be Editor")
            #expect(docType["LSHandlerRank"] as? String == "Owner",
                    "\(label) LSHandlerRank must be Owner")
            #expect(docType["CFBundleTypeExtensions"] as? [String] == ["zudio"],
                    "\(label) CFBundleTypeExtensions must be exactly [\"zudio\"]")
        }
    }

    // MARK: - In-place opening
    //
    // Without these, .zudio files opened from Files / Messages on iOS are copied into a
    // sandbox inbox rather than opened in place.

    @Test func iosSupportsOpeningDocumentsInPlace() throws {
        let plist = try Self.loadPlist(Self.iosPlistURL)
        #expect(plist["LSSupportsOpeningDocumentsInPlace"] as? Bool == true)
        #expect(plist["UIFileSharingEnabled"] as? Bool == true)
    }

    // MARK: - Universal purchase bundle ID parity
    //
    // Mac and iOS must ship under ONE bundle ID for Universal purchase. Because they do,
    // their UTI declarations are resolved against the same Launch Services record, so the
    // two plists disagreeing is a real hazard rather than a cosmetic inconsistency.

    @Test func macAndIOSShareOneBundleIdentifier() throws {
        let pbxproj = Self.repoRoot.appendingPathComponent("Zudio.xcodeproj/project.pbxproj")
        let text = try String(contentsOf: pbxproj, encoding: .utf8)

        var ids = Set<String>()
        for line in text.split(separator: "\n") {
            guard line.contains("PRODUCT_BUNDLE_IDENTIFIER") else { continue }
            let value = line
                .split(separator: "=").last?
                .trimmingCharacters(in: CharacterSet(charactersIn: " ;\t\""))
            guard let value, !value.hasSuffix(".tests") else { continue }
            ids.insert(value)
        }

        #expect(ids == ["com.zudio.app"],
                """
                Expected the Mac and iOS app targets to share exactly one bundle ID
                (com.zudio.app), required for Universal purchase. Found: \(ids.sorted()).
                """)
    }
}
