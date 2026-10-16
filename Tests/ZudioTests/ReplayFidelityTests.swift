import Testing
@testable import Zudio

/// A saved song replays note for note from what was saved with it. The first song of each style
/// is generated with forced settings (AppState.generateNew's "best first song"), and a replay
/// only sees what the song recorded in `forcedRules`: Chill's forced texture and Ambient's Brush
/// Kit were not recorded, and the history paths dropped the percussion style and bridge, so
/// those songs came back different from the Songs list (found 2026-10-16).
@Suite struct ReplayFidelityTests {

    private static func replay(_ s: SongState) -> SongState {
        AppState.regenerateSong(seed: s.globalSeed, keyOverride: nil, tempoOverride: nil, moodOverride: nil,
                                style: s.style, forced: s.forcedRules, trackOverrides: [:])
    }

    private static func sameNotes(_ a: SongState, _ b: SongState) -> Bool {
        a.trackEvents == b.trackEvents && a.chillAudioTexture == b.chillAudioTexture
            && a.ambientAudioTexture == b.ambientAudioTexture
    }

    @Test func firstSongsReplayExactly() {
        for seed in UInt64(1)...25 {
            let firsts = [
                SongGenerator.generate(seed: seed, style: .motorik, forceBassRuleID: "MOT-BASS-015",
                                       forceDrumRuleID: "MOT-DRUM-001", forceArpRuleID: "MOT-RTHM-001"),
                SongGenerator.generate(seed: seed, style: .kosmic, forceBassRuleID: "KOS-BASS-010",
                                       forceArpRuleID: "KOS-RTHM-002", forcePercussionStyle: .motorikGrid,
                                       forceBridge: true),
                SongGenerator.generate(seed: seed, style: .ambient, forceLeadRuleID: "AMB-LEAD-003",
                                       forcePercussionStyle: .handPercussion, useBrushKit: true),
                SongGenerator.generate(seed: seed, style: .chill, forceDrumRuleID: "CHL-DRUM-004",
                                       forceLeadRuleID: "CHL-LD1-004", forceTexRuleID: "forced"),
            ]
            for s in firsts {
                #expect(Self.sameNotes(s, Self.replay(s)), "seed \(seed) \(s.style)")
            }
        }
    }

    @Test func ordinarySongsReplayExactly() {
        for seed in UInt64(1)...25 {
            for style in [MusicStyle.motorik, .kosmic, .ambient, .chill] {
                let s = SongGenerator.generate(seed: seed, style: style)
                #expect(Self.sameNotes(s, Self.replay(s)), "seed \(seed) \(style)")
            }
        }
    }

    /// Each curated first-Soho seed still gives what it was chosen for: Soho under both the
    /// test and the release activation mix, a Latin groove, Operator on flute, a Remix Break,
    /// Duo or bass-ostinato breakdown, and the hook coming home at least three times. A
    /// generator change that breaks one fails here; re-run the search in AppState's comment.
    @Test func firstSohoSeedsStillQualify() {
        for seed in AppState.firstSohoSeeds {
            var r = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: 90))
            #expect(r.nextDouble() < 0.25, "seed \(seed) is not Soho under the release mix")
            let s = SongGenerator.generate(seed: seed, style: .chill)
            #expect(s.chillSohoVariation && s.chillBeatStyle == .sohoLatin, "seed \(seed) groove")
            #expect(s.chillLeadInstrument == .flute, "seed \(seed) lead \(s.chillLeadInstrument)")
            #expect(s.generationLog.contains { $0.tag == "CHL-LD1-010" }, "seed \(seed) lead rule")
            #expect([.sohoRemix, .sohoDuo, .bassOstinato].contains(s.chillBreakdownStyle)
                    && s.structure.sections.contains { $0.label == .bridge }, "seed \(seed) breakdown")
            let homes = s.stepAnnotations.values.filter { $0.contains { $0.description == "return to form" } }.count
            #expect(homes >= 3, "seed \(seed): hook comes home \(homes) times")
        }
    }

    /// The first Chill Soho song is swapped for a curated one, once; anything else passes through.
    @Test func firstSohoSongIsCurated() throws {
        let soho = try #require((UInt64(1)...200).lazy.map { SongGenerator.generate(seed: $0, style: .chill) }
            .first { $0.chillSohoVariation && !AppState.firstSohoSeeds.contains($0.globalSeed) })
        let swapped = AppState.withFirstSohoSong(soho, hadSoho: false)
        #expect(AppState.firstSohoSeeds.contains(swapped.globalSeed))
        #expect(AppState.withFirstSohoSong(soho, hadSoho: true).globalSeed == soho.globalSeed)
        let motorik = SongGenerator.generate(seed: 3, style: .motorik)
        #expect(AppState.withFirstSohoSong(motorik, hadSoho: false).globalSeed == motorik.globalSeed)
    }
}
