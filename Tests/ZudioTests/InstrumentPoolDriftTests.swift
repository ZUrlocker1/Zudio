import Testing
@testable import Zudio

/// The randomiser's substyle sanitisation carries hard-coded pool INDICES that duplicate what
/// `instrumentPickPoolStatic` already encodes. Two copies can disagree, and have: Arcade's Lead 1
/// list permitted a Square Lead the pick pool never selects, and Kosmic Drift's bass replacement
/// offered a Mono Synth the pick pool excludes (both found 2026-10-13).
///
/// This pins the two together. If a pool is reordered or an instrument added, whichever copy was
/// not updated fails here with the instrument names, rather than silently mis-selecting.
@Suite struct InstrumentPoolDriftTests {

    /// Transcribed from the substyle blocks of `AppState`'s randomiser. Keep in step with them.
    private static let sanitiseLists: [(label: String, track: Int, allowed: Set<Int>)] = [
        ("noir bass",      kTrackBass,    [0, 1, 4, 5]),
        ("noir lead1",     kTrackLead1,   [1, 4, 5, 6, 7]),
        ("noir rhythm",    kTrackRhythm,  [2, 3, 5, 6, 7]),
        ("noir drums",     kTrackDrums,   [0, 1, 3]),
        ("arcade drums",   kTrackDrums,   [2, 3]),
        ("arcade lead2",   kTrackLead2,   [2, 5, 7]),
        ("arcade bass",    kTrackBass,    [1, 3, 4, 5, 6]),
        ("arcade lead1",   kTrackLead1,   [0, 1, 6, 7]),
        ("arcade rhythm",  kTrackRhythm,  [0, 6, 9]),
        ("arcade texture", kTrackTexture, [0, 3, 5, 6, 8, 9, 10]),
        ("drift bass",     kTrackBass,    [1, 3, 4, 6, 7]),
        ("drift lead1",    kTrackLead1,   [4, 5, 6, 7]),
        ("drift rhythm",   kTrackRhythm,  [0, 4, 5, 6, 7]),
        ("drift drums",    kTrackDrums,   [2, 3, 4]),
    ]

    private static func sample(_ which: String) -> SongState? {
        for seed in UInt64(1)...4000 {
            if which == "drift" {
                let k = SongGenerator.generate(seed: seed, style: .kosmic)
                if k.isKosmicDrift { return k }
            } else {
                let m = SongGenerator.generate(seed: seed, style: .motorik)
                if which == "noir",   m.motorikNoirVariation   { return m }
                if which == "arcade", m.motorikArcadeVariation { return m }
            }
        }
        return nil
    }

    /// Every hard-coded sanitisation list equals its pick pool's set.
    @Test func sanitisationMatchesThePickPools() {
        var cache: [String: SongState] = [:]
        for (label, track, allowed) in Self.sanitiseLists {
            let which = String(label.split(separator: " ")[0])
            if cache[which] == nil { cache[which] = Self.sample(which) }
            guard let state = cache[which] else {
                Issue.record(Comment(rawValue: "no \(which) song in 4,000 seeds")); continue
            }
            let style: MusicStyle = which == "drift" ? .kosmic : .motorik
            let names = AppState.instrumentPoolNames(trackIndex: track, style: style,
                                                     isKosmicDrift: state.isKosmicDrift)
            let pick = Set(AppState.instrumentPickPoolStatic(trackIndex: track, style: style,
                                                             poolCount: names.count, state: state))
            func nameList(_ s: Set<Int>) -> [String] {
                s.sorted().compactMap { $0 < names.count ? names[$0] : "index \($0) OUT OF RANGE" }
            }
            let why = "\(label): sanitisation allows \(nameList(allowed)), "
                    + "pick pool allows \(nameList(pick))"
            #expect(pick == allowed, Comment(rawValue: why))
        }
    }

    /// Every index either list names is inside its pool.
    @Test func everySanitisationIndexIsInRange() {
        var cache: [String: SongState] = [:]
        for (label, track, allowed) in Self.sanitiseLists {
            let which = String(label.split(separator: " ")[0])
            if cache[which] == nil { cache[which] = Self.sample(which) }
            guard let state = cache[which] else { continue }
            let style: MusicStyle = which == "drift" ? .kosmic : .motorik
            let names = AppState.instrumentPoolNames(trackIndex: track, style: style,
                                                     isKosmicDrift: state.isKosmicDrift)
            for i in allowed {
                #expect(i < names.count,
                        Comment(rawValue: "\(label): index \(i) past a \(names.count)-entry pool"))
            }
        }
    }
}
