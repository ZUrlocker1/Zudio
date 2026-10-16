import Testing
@testable import Zudio

/// Every SongState copy method must carry every field it is not meant to change. They are written
/// out by hand, and a missed field silently takes its default: `replacingEvents` once dropped
/// `motorikArcadeVariation` and `motorikSync`, so regenerating any track of an Arcade or Europe
/// song turned it into plain Motorik (2026-10-16). Compared by reflection, so a field added later
/// and forgotten in a copy method fails here.
@Suite struct SongStateCopyTests {

    /// The fields of `s`, by name, as text.
    private static func fields(_ s: SongState) -> [String: String] {
        Dictionary(uniqueKeysWithValues: Mirror(reflecting: s).children.compactMap { c in
            c.label.map { ($0, String(describing: c.value)) }
        })
    }

    /// Fields that differ between `a` and `b`, other than `allowed`.
    private static func changed(_ a: SongState, _ b: SongState, allowed: Set<String>) -> [String] {
        let fa = fields(a), fb = fields(b)
        return fa.keys.filter { !allowed.contains($0) && fa[$0] != fb[$0] }.sorted()
    }

    /// A Motorik song with the Arcade or Europe flag set, so the fields with non-default values
    /// are the ones a copy is most likely to drop.
    private static func flaggedMotorik() -> SongState? {
        (UInt64(1)...400).lazy.map { SongGenerator.generate(seed: $0, style: .motorik) }
            .first { $0.motorikArcadeVariation || $0.motorikSync.isActive }
    }

    @Test func copiesKeepEveryOtherField() throws {
        let songs = [try #require(Self.flaggedMotorik()),
                     SongGenerator.generate(seed: 7, style: .chill),
                     SongGenerator.generate(seed: 7, style: .ambient),
                     SongGenerator.generate(seed: 7, style: .kosmic)]
        for s in songs {
            let replaced = s.replacingEvents(s.trackEvents[kTrackBass], forTrack: kTrackBass,
                                             appendingLog: [], replacingStepAnnotations: s.stepAnnotations)
            #expect(Self.changed(s, replaced, allowed: []) == [], "replacingEvents, \(s.style)")
            #expect(Self.changed(s, s.withAmbientBrushKit(!s.ambientUseBrushKit),
                                 allowed: ["ambientUseBrushKit"]) == [], "withAmbientBrushKit, \(s.style)")
            #expect(Self.changed(s, s.withFrame(s.frame), allowed: []) == [], "withFrame, \(s.style)")
            #expect(Self.changed(s, s.withAmbientAudioTexture("x", offset: 3),
                                 allowed: ["ambientAudioTexture", "ambientAudioTextureOffset"]) == [],
                    "withAmbientAudioTexture, \(s.style)")
            #expect(Self.changed(s, s.withChillAudioTexture("x"), allowed: ["chillAudioTexture"]) == [],
                    "withChillAudioTexture, \(s.style)")
        }
    }
}
