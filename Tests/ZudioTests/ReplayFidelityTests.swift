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
}
