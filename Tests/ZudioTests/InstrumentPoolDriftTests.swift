import Testing
@testable import Zudio

/// Pins the instrument sanitiser to the pick pools, for every style and substyle.
///
/// Only two instruments are re-picked per song, so the other five carry over from the previous
/// song, and a sanitiser has to pull anything the new song's form never draws back into range.
/// There used to be seven of them, three carrying hard-coded index lists that duplicated
/// `instrumentPickPoolStatic` and drifted from it — Arcade's Lead 1 list permitted a Square Lead
/// the pick pool never selects, Kosmic Drift's bass replacement offered a Mono Synth it excludes
/// (both found 2026-10-13) — while regular Kosmic and base Chill had none. Since 2026-10-15 there
/// is one, `AppState.sanitisedOverrides`, driven by the pick pools themselves. These tests pin the
/// two properties that make it consistent:
///
///   - whatever a song inherits, every track it sanitises ends inside its pick pool;
///   - an instrument already inside its pick pool is never changed.
@Suite struct InstrumentPoolDriftTests {

    /// A spread of songs covering every form: base, Noir, Arcade and sync Motorik; regular and
    /// Drift Kosmic; base, Blues and Soho Chill; Ambient.
    private static let songs: [SongState] = {
        var out: [SongState] = []
        for style in [MusicStyle.motorik, .kosmic, .chill, .ambient] {
            for seed in UInt64(1)...120 { out.append(SongGenerator.generate(seed: seed, style: style)) }
        }
        return out
    }()

    private static func label(_ s: SongState) -> String {
        switch s.style {
        case .motorik:
            if s.motorikNoirVariation { return "Noir" }
            if s.motorikArcadeVariation { return "Arcade" }
            return s.motorikSync.isActive ? "Motorik sync" : "Motorik"
        case .kosmic:  return s.isKosmicDrift ? "Drift" : "Kosmic"
        case .chill:
            if s.chillSohoVariation { return "Soho" }
            return s.chillBluesVariation ? "Blues" : "Chill"
        default:       return "\(s.style)"
        }
    }

    private static func generatorOwned(_ s: SongState) -> Set<Int> {
        s.style == .chill ? [kTrackLead1, kTrackLead2] : []
    }

    private static func pool(_ s: SongState, _ track: Int) -> (names: [String], pick: [Int]) {
        let names = AppState.instrumentPoolNames(trackIndex: track, style: s.style,
                                                 isChillSoho: s.chillSohoVariation)
        let pick = AppState.instrumentPickPoolStatic(trackIndex: track, style: s.style,
                                                     poolCount: names.count, state: s)
        return (names, pick)
    }

    @Test func everyFormIsCovered() {
        let seen = Set(Self.songs.map(Self.label))
        for form in ["Motorik", "Noir", "Arcade", "Kosmic", "Drift", "Chill", "Blues", "Soho"] {
            #expect(seen.contains(form), Comment(rawValue: "no \(form) song in the sample"))
        }
    }

    /// Whatever is inherited — any index in the pool, or none at all — ends inside the pick pool.
    @Test func inheritedInstrumentsEndInsideThePickPool() {
        var rng = SeededRNG(seed: 7)
        var sys = SystemRandomNumberGenerator()
        for s in Self.songs {
            for _ in 0..<4 {
                var inherited: [Int: Int] = [:]
                for t in 0..<kTrackCount {
                    let n = Self.pool(s, t).names.count
                    if n > 0, rng.nextInt(upperBound: 5) > 0 { inherited[t] = rng.nextInt(upperBound: n) }
                }
                let out = AppState.sanitisedOverrides(inherited, for: s, using: &sys)
                for t in 0..<kTrackCount where !Self.generatorOwned(s).contains(t) {
                    let (names, pick) = Self.pool(s, t)
                    guard names.count > 1, !pick.isEmpty else { continue }
                    let i = out[t] ?? 0
                    let name = i < names.count ? names[i] : "index \(i) OUT OF RANGE"
                    #expect(pick.contains(i), Comment(rawValue:
                        "\(Self.label(s)) \(kTrackNames[t]): kept \(name), which its pick pool never draws"))
                }
            }
        }
    }

    /// A choice the new song's form allows is left alone — the sanitiser only ever repairs.
    @Test func allowedInstrumentsAreNeverChanged() {
        var rng = SeededRNG(seed: 11)
        var sys = SystemRandomNumberGenerator()
        for s in Self.songs {
            var valid: [Int: Int] = [:]
            for t in 0..<kTrackCount {
                let pick = Self.pool(s, t).pick
                if !pick.isEmpty { valid[t] = pick[rng.nextInt(upperBound: pick.count)] }
            }
            let out = AppState.sanitisedOverrides(valid, for: s, using: &sys)
            #expect(out == valid, Comment(rawValue: "\(Self.label(s)): a valid instrument was re-picked"))
        }
    }

    /// Every index a pick pool can return is inside its pool.
    @Test func everyPickPoolIndexIsInRange() {
        for s in Self.songs {
            for t in 0..<kTrackCount {
                let (names, pick) = Self.pool(s, t)
                for i in pick where i >= names.count {
                    Issue.record(Comment(rawValue:
                        "\(Self.label(s)) \(kTrackNames[t]): index \(i) past a \(names.count)-entry pool"))
                }
            }
        }
    }
}
