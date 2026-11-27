// MixAutomation.swift — the timed changes to a song's sound, defined once for playback and export.
// Copyright (c) 2026 Zack Urlocker
//
// Live playback changes the mix over time with timers: the intro and outro fades, the slow filter
// tides and Kosmic filter sweeps, the Ambient pad and bass swells. The offline export has no
// timers; it sets the same node parameters between render blocks. Both must produce the same
// curves, so the curves are pure functions here, and PlaybackEngine's timers and OfflineExport's
// render loop both read them. A song's automation is a function of the song alone (and a time in
// seconds), so the export can evaluate it at any moment.
//
// What lives here:
// - the filter tide and fast sweep curves, and the schedule of automatic ones for a song
// - the master fade of Motorik, Chill (alreadyPlaying intro) and Ambient
// - the Kosmic drone and body-entrance fades on single tracks
// - the Ambient Zen pad cutoff that follows the song's swell
// - the drum note and velocity mapping applied as a note fires
//
// Not here: the per-note Ambient and Chill Pads fade (it needs the note list, so OfflineExport's
// NoteFadeEnvelope replays it), and live-only gestures (tap-empty sweeps, mute and solo).

import Foundation

enum MixAutomation {

    // MARK: - Filter tides and sweeps

    /// The floor a slow Ambient tide closes the filters to.
    static let tideFloorHz: Float = 600
    /// A fast sweep runs 60 ticks at 20 a second.
    static let fastSweepSeconds = 3.0
    /// Radians per tick of the fast sweep's phase, and ticks a second.
    static let fastSweepPhasePerTick = 0.052
    static let ticksPerSecond = 20.0

    /// The cutoff of a slow tide at progress `p` (0 to 1) of its run, on a log scale in smoothstep
    /// steps. A tide out closes over the first 40%, holds 20%, reopens over the last 40%. A tide in
    /// is the other way round: dark within the first 10%, holds 20%, then the brightness comes
    /// back slowly over the last 70%.
    static func tideCutoff(progress p: Double, tideIn: Bool) -> Float {
        let ramp: Double
        if tideIn {
            ramp = p < 0.1 ? p / 0.1 : (p > 0.3 ? (1.0 - p) / 0.7 : 1.0)
        } else {
            ramp = p < 0.4 ? p / 0.4 : (p > 0.6 ? (1.0 - p) / 0.4 : 1.0)
        }
        let closed = ramp * ramp * (3.0 - 2.0 * ramp)
        return 6000 * Float(pow(Double(tideFloorHz / 6000), closed))
    }

    /// The cutoff of Motorik's opening tide at progress `p`: dark from the first instant, held
    /// dark for the first `hold` of the run (the intro, under its fade-in), then opening on the
    /// log scale in smoothstep steps over the rest.
    static func openCutoff(progress p: Double, hold: Double) -> Float {
        let ramp = p < hold ? 1.0 : max(0.0, (1.0 - p) / max(0.001, 1.0 - hold))
        let closed = ramp * ramp * (3.0 - 2.0 * ramp)
        return 6000 * Float(pow(Double(tideFloorHz / 6000), closed))
    }

    /// The cutoff of a closing tide at progress `p`: it closes over the first 70% and stays closed,
    /// since the song's outro fade carries it out (Motorik's closing tide, see `MotorikAutoTide`).
    static func closeCutoff(progress p: Double) -> Float {
        let ramp = min(1.0, max(0.0, p / 0.7))
        let closed = ramp * ramp * (3.0 - 2.0 * ramp)
        return 6000 * Float(pow(Double(tideFloorHz / 6000), closed))
    }

    /// The cutoff of the fast open-close-open sweep at a phase, 300 to 6000 Hz.
    static func fastSweepCutoff(phase: Double) -> Float {
        Float(300 + 5700 * (1.0 + sin(phase)) / 2.0)
    }

    /// One automatic filter effect in a song: a Kosmic fast sweep or an Ambient slow tide.
    struct FilterSweep: Sendable {
        enum Kind: Sendable { case fast, tide(isIn: Bool), tideOpen(hold: Double), tideClose }
        let start: Double      // seconds from the top of the song
        let seconds: Double
        let kind: Kind
    }

    /// Every automatic sweep or tide of a song, as `AppState.autoSweepSteps` fires them in playback.
    /// `extraSteps` are Evolve's pass-boundary sweeps (`AppState.evolveBoundarySweepSteps`): they
    /// belong to the play session, so the caller passes them; export of an evolved song does.
    static func filterSweeps(for state: SongState, extraSteps: [Int] = []) -> [FilterSweep] {
        let sps = state.frame.secondsPerStep
        switch state.style {
        case .ambient:
            return AmbientAutoTide.steps(for: state).map { step in
                FilterSweep(start: Double(step) * sps,
                            seconds: Double(AmbientAutoTide.tideSeconds(seed: state.globalSeed, step: step)),
                            kind: .tide(isIn: AmbientAutoTide.isTideIn(seed: state.globalSeed, step: step)))
            }
        case .motorik:
            return MotorikAutoTide.plan(for: state).map { item in
                FilterSweep(start: Double(item.step) * sps, seconds: Double(item.seconds),
                            kind: item.isClosing ? .tideClose : (item.isMid ? .tide(isIn: false) : .tideOpen(hold: item.hold)))
            }
        case .kosmic:
            return Set(KosmicAutoSweep.steps(for: state)).union(extraSteps).sorted().map {
                FilterSweep(start: Double($0) * sps, seconds: fastSweepSeconds, kind: .fast)
            }
        default:
            return []
        }
    }

    /// The cutoff every non-drum filter takes `t` seconds into the song, or nil outside the sweep.
    static func sweepCutoff(_ s: FilterSweep, at t: Double) -> Float? {
        let e = t - s.start
        guard e >= 0, e < s.seconds else { return nil }
        switch s.kind {
        case .fast: return fastSweepCutoff(phase: Double.pi / 2 + fastSweepPhasePerTick * ticksPerSecond * e)
        case .tide(let isIn): return tideCutoff(progress: e / s.seconds, tideIn: isIn)
        case .tideOpen(let hold): return openCutoff(progress: e / s.seconds, hold: hold)
        case .tideClose: return closeCutoff(progress: e / s.seconds)
        }
    }

    /// The resonance of the filters during a sweep: the fast sweep's wah boost, else the static 3 dB.
    static func sweepResonance(_ s: FilterSweep) -> Float {
        if case .fast = s.kind { return 10 }
        return 3
    }

    // MARK: - Master fade

    /// The master level at `t` seconds: Motorik, and Chill with an alreadyPlaying intro, fade in over
    /// the intro and out over the outro; Ambient fades out over its outro. Kosmic fades single
    /// tracks instead (see `trackGain`) and every other style plays at 1.
    static func masterGain(for state: SongState, at t: Double) -> Float {
        let sps = state.frame.secondsPerStep
        switch state.style {
        case .motorik, .chill:
            if state.style == .chill {
                guard case .alreadyPlaying = state.structure.introStyle else { return 1 }
            }
            var g = 1.0
            if let intro = state.structure.introSection {
                let end = Double(intro.endBar * 16) * sps
                if end > 0, t < end { g = max(0, min(1, t / end)) }
            }
            if let outro = state.structure.outroSection {
                let s = Double(outro.startBar * 16) * sps, e = Double(outro.endBar * 16) * sps
                if e > s, t >= s { g *= max(0, 1 - (t - s) / (e - s)) }
            }
            return Float(g)
        case .ambient:
            guard let r = ambientOutro(for: state), t >= r.start else { return 1 }
            return Float(max(0, 1 - (t - r.start) / (r.end - r.start)))
        default:
            return 1
        }
    }

    /// Ambient's song-level outro: the structural outro, else the last 4 to 6 bars.
    static func ambientOutro(for state: SongState) -> (start: Double, end: Double)? {
        guard state.style == .ambient else { return nil }
        let total = state.frame.totalBars
        let startBar = state.structure.outroSection?.startBar ?? max(0, total - min(6, max(4, total / 10)))
        let sps = state.frame.secondsPerStep
        let s = Double(startBar * 16) * sps, e = Double(total * 16) * sps
        return e > s ? (s, e) : nil
    }

    /// When Ambient's outro releases every held note: playback calls allNotesOff once the fade is
    /// down to 15%, so the release envelopes finish and the reverb drains before it reaches 0.
    static func ambientNotesOffSecond(for state: SongState) -> Double? {
        guard let r = ambientOutro(for: state) else { return nil }
        return r.start + 0.85 * (r.end - r.start)
    }

    // MARK: - Kosmic track fades

    /// A single track's level over time for Kosmic: the drone tracks (bass and pads) fade in over
    /// the intro and out over the outro; every other track with nothing in the intro enters the body
    /// on a half-bar square-root ramp. Nil when the track has no such fade.
    static func trackGain(for state: SongState, track: Int) -> ((Double) -> Float)? {
        guard state.style == .kosmic else { return nil }
        let sps = state.frame.secondsPerStep
        let intro = state.structure.introSection
        let outro = state.structure.outroSection
        if track == kTrackBass || track == kTrackPads {
            var floor: Float = 1, introSecs = 0.0
            if let intro {
                floor = intro.lengthBars >= 4 ? 0.15 : 0.0
                let fadeBars = intro.lengthBars >= 8 ? intro.lengthBars / 2 : intro.lengthBars
                introSecs = Double(min(intro.endBar * 16, fadeBars * 16)) * sps
            }
            let outroSpan = outro.map { (Double($0.startBar * 16) * sps, Double($0.endBar * 16) * sps) }
            guard intro != nil || outroSpan != nil else { return nil }
            return { t in
                var g: Float = 1
                if intro != nil {
                    let frac = Float(min(1, max(0, t / max(0.001, introSecs))))
                    g = floor + frac * (1 - floor)
                }
                if let (s, e) = outroSpan, e > s, t >= s {
                    g *= Float(max(0, 1 - (t - s) / (e - s)))
                }
                return g
            }
        }
        guard let intro else { return nil }
        let introEnd = intro.endBar * 16
        guard !state.events(forTrack: track).contains(where: { $0.stepIndex < introEnd }) else { return nil }
        let bodyStart = Double(introEnd) * sps
        let fadeSecs = 8 * sps
        return { t in
            t < bodyStart ? 1 : Float(sqrt(min(1, max(0, (t - bodyStart) / max(0.001, fadeSecs)))))
        }
    }

    // MARK: - Ambient Zen pad brightness

    /// Ambient Zen's pads brighten with the song's swell curve (one value a bar, interpolated).
    static func zenSwell(for state: SongState) -> [Double] {
        guard state.isAmbientZen else { return [] }
        return AmbientZenPlan.swell(for: state, dials: AmbientZenDials.draw(seed: state.globalSeed))
    }

    /// The pad filter's cutoff `t` seconds into a Zen song.
    static func zenPadCutoff(swell: [Double], at t: Double, secondsPerStep sps: Double) -> Float {
        let pos  = t / (16 * sps)
        let bar  = max(0, min(swell.count - 1, Int(pos)))
        let next = min(swell.count - 1, bar + 1)
        let frac = max(0, min(1, pos - Double(bar)))
        return PlaybackEngine.zenPadCutoff(swell: swell[bar] + (swell[next] - swell[bar]) * frac)
    }

    // MARK: - Ambient swells

    /// Ambient (not Zen) fades its bass and pads up on every note-on and down on every note-off. The
    /// attack is a third of the note, between 30 ms and half a second.
    static func ambientNoteFadeSeconds(durationSteps: Int, secondsPerStep sps: Double) -> Double {
        min(0.5, max(0.03, Double(durationSteps) * sps / 3.0))
    }

    /// The bass sweep's cutoff follows the bass's fade level: 300 Hz closed to 3500 Hz open.
    static func ambientBassCutoff(fade: Float) -> Float { 300 + 3200 * fade }

    // MARK: - Drum notes

    /// The note and velocity a drum event fires with, as playback maps them: the 808 and Machine
    /// kits trade their synthetic toms for kick, snare and hats; Machine Kit's own notes fire at
    /// 88%; Kosmic Drift's standard-kit snare and Buddha Pulse's 808 snare are turned down.
    /// `program` is the drum kit's GM program.
    static func drumFire(note: UInt8, velocity: UInt8, program: UInt8,
                         kosmicSpace: Bool, kosmicDrift: Bool, buddhaPulse: Bool) -> (note: UInt8, velocity: UInt8) {
        var fire = note
        var remapped = false
        if program == 25 {
            switch note {
            case 41, 43, 45: fire = GMDrum.kick.rawValue;    remapped = true
            case 48:         fire = GMDrum.snare.rawValue;   remapped = true
            case 50:         fire = GMDrum.openHat.rawValue; remapped = true
            case 67 where kosmicSpace:
                             fire = GMDrum.pedalHat.rawValue; remapped = true
            default: break
            }
        } else if program == 24 && !kosmicSpace {
            switch note {
            case 41, 43, 45: fire = GMDrum.snare.rawValue; remapped = true
            case 48:         fire = GMDrum.snare.rawValue; remapped = true
            case 50:         fire = GMDrum.snare.rawValue; remapped = true
            case 40:         fire = GMDrum.snare.rawValue; remapped = true
            case 49:         fire = GMDrum.ride.rawValue;  remapped = true
            default: break
            }
        } else if program == 24 && kosmicSpace
                    && (note == GMDrum.snare2.rawValue || note == GMDrum.highAgogo.rawValue) {
            fire = note == GMDrum.snare2.rawValue ? GMDrum.snare.rawValue : GMDrum.pedalHat.rawValue
            remapped = true
        } else if program == 26 && kosmicSpace && note == GMDrum.highAgogo.rawValue {
            fire = GMDrum.pedalHat.rawValue
            remapped = true
        }
        let vel: UInt8
        if program == 24 && !remapped {
            vel = UInt8(max(1, Int(velocity) * 88 / 100))
        } else if program == 0 && kosmicDrift
                    && (fire == GMDrum.snare.rawValue || fire == GMDrum.snare2.rawValue) {
            vel = UInt8(max(1, Int(velocity) * 65 / 100))
        } else if program == 25 && buddhaPulse && fire == GMDrum.snare2.rawValue {
            vel = UInt8(max(1, Int(velocity) * 75 / 100))
        } else {
            vel = velocity
        }
        return (fire, vel)
    }
}


/// Motorik's occasional filter tides, after Neu!'s filter moves, shaped around the intro and outro
/// fades that most Motorik songs have. The opening tide starts dark and holds dark through the
/// intro (under its fade-in), then opens over the next 8 bars. The closing tide starts 4 bars
/// before the outro, so it closes at full volume, is shut by about the middle of the outro and
/// stays closed under the fade. They come as a pair: 25% of songs get both, the rest neither.
/// Regular Motorik and Motorik Noir only, never Arcade or Europe. Drums are never filtered. The schedule comes from the seed with its own SeededRNG, so it
/// consumes nothing from the generator's stream and never changes a note, and nothing is stored
/// in SongState.
enum MotorikAutoTide {
    static let songChance = 0.25
    static let openBars = 8
    static let closeLeadBars = 4
    /// The mid-song tide out starts this many bars before the change it releases onto.
    static let midLeadBars = 5
    static let midClearBars = 8

    /// `hold` is the dark fraction of an opening tide; unused for a closing one.
    struct Item { let step: Int; let seconds: Int; let isClosing: Bool; let hold: Double; var isMid = false }

    static func plan(for song: SongState) -> [Item] {
        guard song.style == .motorik, !song.motorikArcadeVariation, !song.motorikSync.isActive,
              song.frame.totalBars >= 32 else { return [] }
        var rng = SeededRNG(seed: song.globalSeed ^ 0x4E45_5521_7DE5_A11D)
        guard rng.nextDouble() < songChance else { return [] }
        let sps = song.frame.secondsPerStep
        let introBars = max(2, song.structure.introSection?.endBar ?? 2)
        let openTotal = introBars + openBars
        var items = [Item(step: 0, seconds: Int((Double(openTotal * 16) * sps).rounded()), isClosing: false,
                          hold: Double(introBars) / Double(openTotal))]
        var closeStartBar = song.frame.totalBars
        if let outro = song.structure.outroSection, outro.lengthBars > 0 {
            let startBar = max(introBars + openBars, outro.startBar - closeLeadBars)
            let lengthBars = song.frame.totalBars - startBar
            if lengthBars > 0 {
                closeStartBar = startBar
                items.append(Item(step: startBar * 16, seconds: Int((Double(lengthBars * 16) * sps).rounded(.up)),
                                  isClosing: true, hold: 0))
            }
        }
        if let mid = midItem(for: song, rng: &rng, introBars: introBars, openTotal: openTotal,
                             closeStart: closeStartBar) {
            items.insert(mid, at: 1)
        }
        return items
    }

    /// A tide out that reopens on a change in the middle of the song, `midLeadBars` ahead of it: a
    /// bridge or section change if the body has one, else a chord change on an 8-bar bar in the middle
    /// third. With neither there is no mid-song tide. Needs `midClearBars` clear of the opening and
    /// closing tides; nil if nothing fits.
    private static func midItem(for song: SongState, rng: inout SeededRNG, introBars: Int,
                                openTotal: Int, closeStart: Int) -> Item? {
        let total = song.frame.totalBars
        let earliest = openTotal + midClearBars + midLeadBars   // the change bar, at the earliest
        let latest = closeStart - midClearBars
        func fits(_ bar: Int) -> Bool { bar >= earliest && bar <= latest }
        func pick(_ bars: [Int]) -> Int? {
            bars.isEmpty ? nil : bars[Int(rng.next() % UInt64(bars.count))]
        }
        let lo = total / 3, hi = total * 2 / 3
        let bodyStarts = song.structure.sections
            .filter { $0.label != .intro && $0.label != .outro && $0.startBar > 0 && fits($0.startBar) }
        let bridgey = bodyStarts.filter { $0.label != .A }.map(\.startBar)
        let sectionBar = pick(bridgey) ?? pick(bodyStarts.map(\.startBar))
        let chordBar = pick(song.structure.chordPlan.map(\.startBar)
            .filter { $0 % 8 == 0 && $0 >= lo && $0 <= hi && fits($0) })
        guard let change = sectionBar ?? chordBar else { return nil }
        let seconds = Int((Double(midLeadBars * 16) * song.frame.secondsPerStep).rounded())
        return Item(step: (change - midLeadBars) * 16, seconds: seconds, isClosing: false, hold: 0, isMid: true)
    }
}
