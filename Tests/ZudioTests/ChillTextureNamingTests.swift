// ChillTextureNamingTests.swift — the Chill texture picker must name the texture that plays.
//
// Run with:
//   swift test --filter ChillTextureNamingTests
//
// The picker reads instrumentOverrides as a POSITION in the texture pool, but the pool's audio
// pseudo-programs are not contiguous ("Another pub" is 251 at position 2). The override used to
// be stored as `prog - 240`, which was a valid position for only four of the seven textures:
// Another pub showed as Vinyl crackle, Bar sounds as Another pub, City at night as Bar sounds —
// and because the picker re-applies its selection on generate, the wrong one could play.
// The same texture was also spelt three ways across the picker, Instruments line and log.

import Testing
@testable import Zudio

@Suite struct ChillTextureNamingTests {

    private static let files = ["another_bar.m4a", "another-pub.m4a", "bar_sounds.m4a",
                                "city_at_night.m4a", "harbor.m4a", "vinyl_crackle.m4a"]

    private static let names    = AppState.instrumentPoolNames(trackIndex: kTrackTexture, style: .chill)
    private static let programs = AppState.instrumentPoolPrograms(trackIndex: kTrackTexture, style: .chill)

    /// The position stored for a texture must point at that texture's own entry in the picker,
    /// and selecting that entry must play the same file back.
    @Test func pickerPositionNamesAndPlaysTheSameTexture() {
        for file in Self.files {
            let idx = AppState.chillTexturePoolIndex(forFilename: file)
            #expect(idx > 0 && idx < Self.names.count, "\(file) maps outside the pool (\(idx))")
            let played = AppState.chillTextureFilename(forProgram: Self.programs[idx])
            #expect(played == file, "\(file) is stored at \(idx), which plays \(played ?? "nothing")")
        }
    }

    /// One spelling everywhere: the picker name is the display name.
    @Test func displayNameMatchesThePicker() {
        for file in Self.files {
            let idx = AppState.chillTexturePoolIndex(forFilename: file)
            #expect(AppState.chillTextureDisplayName(file) == Self.names[idx],
                    "\(file): display \(AppState.chillTextureDisplayName(file)) vs picker \(Self.names[idx])")
        }
    }

    /// No texture is stored at position 0, which the picker shows as "None".
    @Test func noTextureMapsToNone() {
        #expect(AppState.chillTexturePoolIndex(forFilename: nil) == 0)
        #expect(Self.names[0] == "None")
    }

    /// The generation log uses the same name as the picker, never a raw filename.
    @Test func generationLogUsesThePickerName() {
        for seed in UInt64(1)...300 {
            let s = SongGenerator.generate(seed: seed, style: .chill)
            guard let file = s.chillAudioTexture,
                  let line = s.generationLog.first(where: { $0.tag == "Texture" }) else { continue }
            #expect(line.description == AppState.chillTextureDisplayName(file),
                    "seed \(seed): log says \(line.description)")
            #expect(!line.description.contains("-") && !line.description.contains("_"))
        }
    }
}
