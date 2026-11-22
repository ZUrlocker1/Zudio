// AmbientZenPlan.swift — Ambient Zen: the one picture of the song every Zen track reads
// Copyright (c) 2026 Zack Urlocker
//
// Ambient Zen is a "sounds like" homage to AMB-1 (Charles Vestal's generative firmware for the
// M-Vave FM-1) and through it to Eno's Music for Airports. See docs/Ambient-Zen-plan.md,
// sections 4 to 6: the dials, the chord table, the walk, the way home and the pedal.
//
// The plan is a pure function of the seed and the Zen tempo, never the user's tempo scrub, so a
// regenerated track reads the same picture the song was generated with. All of its draws come
// from the trackSeed block 120 to 127, which no other style uses, and none of them reads
// Dictionary or Set order.

import Foundation

/// The echo dial's character: the usual echo, or an occasional deep or dry one (Zack, 2026-11-21).
enum ZenEchoCharacter: Sendable, Equatable {
    case usual, deep, dry
}

/// The harmony plan (Zack, 2026-11-21): AMB-1's drift, or the Big Ship cycle with breathing pads
/// or with block chords.
enum ZenCycle: Sendable, Equatable {
    case none, breathing, block
}

/// The per-song dials that stand in for AMB-1's knobs (plan section 4). Drawn from index 120.
struct AmbientZenDials: Sendable, Equatable {
    let mode: Mode
    /// 62 to 88 bpm, triangular, peak 72.
    let tempo: Int
    /// The mean chord window, 25 to 60 seconds.
    let chordPaceSeconds: Double
    /// AMB-1's Swell knob, 45 to 70: sets the pad breath cycle.
    let breathLength: Double
    /// 0.25 to 0.45. Phase 1 uses it only for the bass sit-outs.
    let restlessness: Double
    /// The bell loops' density: 30, 45 or 60 (sparse, medium, full).
    let bellDensity: Int
    /// 0.75 to 0.90, sets the echo feedback.
    let echoSize: Double
    /// AMB-DRUM-005 Garden Pulse plays: 10 percent of songs (Zack, 2026-11-21).
    let pulse: Bool
    /// The outro's length, 6 to 12 bars (Zack, 2026-11-20).
    let outroBars: Int
    /// How many bars before the end of the music each track stops: [Pads, Pedal, Bass]. One track
    /// always holds to the end (0); the other two stop 1 to 2 bars apart, so the three never end
    /// together. Always inside the held breath, which keeps at least 2 bars of all three.
    let endOffsets: [Int]
    /// Lead 2 plays on Lead 1's instrument, as AMB-1 plays all its bell loops on one voice: 25
    /// percent of songs (Zack, 2026-11-20). An instrument choice only; the notes don't change.
    let lead2SyncsLead1: Bool
    /// AMB-1's bass octave at -1: the bass an octave lower, MIDI 24 to 35 (never higher).
    /// 12 percent of songs (Zack, 2026-11-21).
    let bassLow: Bool
    /// AMB-1's bell octave at -1: all three bell loops an octave lower (never higher).
    /// 12 percent of songs (Zack, 2026-11-21).
    let bellsLow: Bool
    /// The echo's character (Zack, 2026-11-21): usual 75 percent; deep 15 (feedback 79 to 80
    /// percent and the bells 15 points wetter, after AMB-1's Shoreline); dry 10 (feedback 66 to 70
    /// and the bells 15 points drier). One dial, so a song is never extreme both ways.
    let echoCharacter: ZenEchoCharacter
    /// 0 to 1: where the feedback sits inside a deep or dry echo's range.
    let echoAmount: Double
    /// The Big Ship cycle (AMB-PADS-015): 30 percent of songs while testing, split evenly between
    /// breathing pads and block chords; likely 20 at release (Zack, 2026-11-21).
    let cycle: ZenCycle
    /// AMB-TEXT-011 Low Tide plays instead of AMB-TEXT-012 Pearl Pedal: 40 percent of songs
    /// (Zack, 2026-11-21). A lighter tonic that comes and goes.
    let lowTide: Bool
    /// AMB-PADS-016 Shell Voices: breathing pads with only the 3rd and 7th (Zack, 2026-11-21).
    /// Drawn in 47 percent of songs and ignored under Big Ship block chords, so about 40 percent.
    let shellVoices: Bool
    /// AMB-BASS-009 Slow Glide: AMB-BASS-007's notes, played as one held note that bends to each
    /// new root (Zack, 2026-11-21). 35 percent of songs; playback reads this dial (ZenBassGlide).
    let slowGlide: Bool
    /// The pads voice every tonic window as a rootless 6/9 (Ionian and Lydian only): 25 percent of
    /// drift songs (Zack, 2026-11-21).
    let homeSixNine: Bool
    /// The stream for the per-window pad colours (AmbientZenPlan.colourPads).
    let padColourSeed: UInt64

    static func draw(seed: UInt64) -> AmbientZenDials {
        var rng = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: AmbientZenPlan.dialsIndex))
        let mode = rng.pick([Mode.Ionian, .Dorian, .Aeolian, .Mixolydian, .Lydian],
                            weights: [0.22, 0.22, 0.20, 0.18, 0.18])
        let tempo   = Int(rng.triangular(min: 62, peak: 72, max: 88).rounded())
        let pace    = 25 + 35 * rng.nextDouble()
        let breath  = 45 + 25 * rng.nextDouble()
        _ = rng.nextDouble()   // was the pad colour roll; the pads now draw from one weighted pool. Kept so no later dial moves
        let restless = 0.25 + 0.20 * rng.nextDouble()
        let density  = [30, 45, 60][rng.nextInt(upperBound: 3)]
        let echo     = 0.75 + 0.15 * rng.nextDouble()
        let pulse    = rng.nextDouble() < 0.10
        // New draws go last, so no earlier dial moves. The outro, then the order the tracks stop in.
        let outro    = 6 + rng.nextInt(upperBound: 7)
        let held     = AmbientZenPlan.heldBreathBars(outroBars: outro)
        var order    = [0, 1, 2]                       // Pads, Pedal, Bass: index 0 stops last
        for i in stride(from: 2, to: 0, by: -1) { order.swapAt(i, rng.nextInt(upperBound: i + 1)) }
        var gapA = 1 + rng.nextInt(upperBound: 2), gapB = 1 + rng.nextInt(upperBound: 2)
        if gapA + gapB > held - 2 { gapA = 1; gapB = 1 }
        var offsets = [0, 0, 0]
        offsets[order[1]] = gapA
        offsets[order[2]] = gapA + gapB
        let lead2Sync = rng.nextDouble() < 0.25
        // The octave dials (2026-11-21), last: 12 percent each (Zack, 2026-11-21).
        let bassLow  = rng.nextDouble() < 0.12
        let bellsLow = rng.nextDouble() < 0.12
        // The echo character (2026-11-21), last.
        let echoRoll = rng.nextDouble()
        let echoCharacter: ZenEchoCharacter = echoRoll < 0.15 ? .deep : echoRoll < 0.25 ? .dry : .usual
        let echoAmount = rng.nextDouble()
        // The Big Ship cycle (2026-11-21), last, testing share.
        let cycleRoll = rng.nextDouble()
        let cycle: ZenCycle = cycleRoll < 0.15 ? .breathing : cycleRoll < 0.30 ? .block : .none
        // The Texture rule (2026-11-21), last: Low Tide 40 percent, Pearl Pedal 60.
        let lowTide = rng.nextDouble() < 0.40
        // The pad shell (2026-11-21), last.
        let shellVoices = rng.nextDouble() < 0.47
        // The bass glide (2026-11-21), last.
        let slowGlide = rng.nextDouble() < 0.35
        // The pad colours (2026-11-21), last.
        let homeSixNine   = rng.nextDouble() < 0.25
        let padColourSeed = rng.next()
        return AmbientZenDials(mode: mode, tempo: tempo, chordPaceSeconds: pace, breathLength: breath,
                               restlessness: restless, bellDensity: density,
                               echoSize: echo, pulse: pulse, outroBars: outro, endOffsets: offsets,
                               lead2SyncsLead1: lead2Sync, bassLow: bassLow, bellsLow: bellsLow,
                               echoCharacter: echoCharacter, echoAmount: echoAmount, cycle: cycle, lowTide: lowTide,
                               shellVoices: shellVoices, slowGlide: slowGlide,
                               homeSixNine: homeSixNine, padColourSeed: padColourSeed)
    }

    /// Points added to the bells' echo wet mix (Lead 1, Lead 2, Rhythm): +15 deep, -15 dry.
    var bellEchoWetShift: Float {
        switch echoCharacter {
        case .usual: return 0
        case .deep:  return 15
        case .dry:   return -15
        }
    }

    /// How far the bell loops sit below AMB-1's base notes: 12 when the bells are low.
    var bellShift: Int { bellsLow ? -12 : 0 }
    /// How far the bass sits below MIDI 36 + root: 12 when the bass is low.
    var bassShift: Int { bassLow ? -12 : 0 }

    /// Echo feedback in AVAudioUnitDelay's percent: 0.5 + 0.32 x echo size, 74 to 79; a deep echo
    /// 79 to 80, a dry one 66 to 70.
    var echoFeedbackPercent: Float {
        switch echoCharacter {
        case .usual: return Float((0.5 + 0.32 * echoSize) * 100)
        case .deep:  return Float(79 + 1 * echoAmount)
        case .dry:   return Float(66 + 4 * echoAmount)
        }
    }

    /// The other dials in plain words for the Zen line of the log (the key, mode and chord pace
    /// are on the Chords line).
    var plainWords: String {
        // The pad colour isn't named: the Instruments line already shows the pads (Zack, 2026-11-21).
        let breath = breathLength < 53 ? "short" : breathLength < 62 ? "medium" : "long"
        // "deep" and "dry" name the occasional extremes; the usual echo reads light, medium or long.
        let echo: String
        switch echoCharacter {
        case .deep:  echo = "deep"
        case .dry:   echo = "dry"
        case .usual: echo = echoSize < 0.80 ? "light" : echoSize < 0.85 ? "medium" : "long"
        }
        let bells  = bellDensity <= 30 ? "sparse" : bellDensity <= 45 ? "medium" : "full"
        // Drift is the restlessness dial: how much the bell loops change each pass and how often
        // the bass sits out (Zack, 2026-11-21). The swell depth is added by the log builder.
        let drift  = restlessness < 0.317 ? "calm" : restlessness < 0.383 ? "medium" : "restless"
        // A dial at its middle setting ("medium") isn't named (Zack, 2026-11-21). A low octave is
        // added to its word: "Bells:sparse,low", or "Bells:low" when the density is medium;
        // "Bass:low" only when low.
        var parts: [String] = []
        if breath != "medium" { parts.append("Breaths:\(breath)") }
        if echo != "medium" { parts.append("Echo:\(echo)") }
        let bellWords = [bells == "medium" ? nil : bells, bellsLow ? "low" : nil].compactMap { $0 }
        if !bellWords.isEmpty { parts.append("Bells:" + bellWords.joined(separator: ",")) }
        if drift != "medium" { parts.append("Drift:\(drift)") }
        if bassLow { parts.append("Bass:low") }
        return parts.joined(separator: " ")
    }
}

/// How the breathing pads voice a window (Zack, 2026-11-21). The chord stays the window's seventh
/// chord for the bells, Texture, bass and log; only the pads' four notes change.
enum ZenPadVoicing: Sendable, Equatable {
    /// Root, 3rd, 5th, 7th.
    case seventh
    /// The 9th in place of the root (the bass holds the root).
    case ninth
    /// Root, 3rd, 5th and the root again: no 7th.
    case triad
    /// The tonic as a rootless 6/9: 6th, 3rd, 5th, 9th.
    case sixNine
}

extension ChordType {
    /// The chord's own fifth above the root: 7, or 6 for a half-diminished chord.
    var fifthInterval: Int { intervals.count > 2 ? intervals[2] : 7 }
}

/// One entry of the chord table: a diatonic seventh chord on a degree, with AMB-1's walk weight.
struct ZenChord: Sendable, Equatable {
    let degree: String
    let type: ChordType
    let weight: Double
}

/// One chord window of the journey, with everything the Zen tracks need to stay clash-free.
struct ZenWindow: Sendable, Equatable {
    let startBar: Int
    let lengthBars: Int
    let degree: String
    let type: ChordType
    /// The four chord tones as pitch classes, root first, in stacked-thirds order.
    let chordTones: [Int]
    /// Scale notes that are not chord tones and not a semitone above any chord tone (section 5).
    let safeTensions: [Int]
    /// Whether the pedal's tonic and fifth may sound in this window (section 6, rule 2).
    let keepsTonic: Bool
    let keepsFifth: Bool
    /// The pads' voicing and its four pitch classes (empty for a plain seventh chord).
    var padVoicing: ZenPadVoicing = .seventh
    var padTones: [Int] = []

    /// The four pitch classes the breathing pads voice.
    var voiceTones: [Int] { padTones.isEmpty ? chordTones : padTones }
    var endBar: Int { startBar + lengthBars }
    var rootPC: Int { chordTones[0] }
    var fifthInterval: Int { type.fifthInterval }
    /// The degree's number, 1 to 7 ("b3" is 3, "#4" is 4).
    var degreeNumber: Int { AmbientZenPlan.degreeNumber(degree) }
}

struct AmbientZenPlan: Sendable {

    // MARK: - Seed indices (plan section 4)
    static let dialsIndex = 120
    static let walkIndex  = 121
    static let padsIndex  = 122
    static let pedalIndex = 123
    static let bassIndex  = 124
    static let swellIndex = 125
    /// The bell loops' default seeds (a regenerated bell track uses its override instead). 126 is
    /// the plan's spare; 127 stays the pulse's, so Lead 2 and Rhythm take 128 and 129.
    static let lead1Index  = 126
    /// AMB-DRUM-005 Garden Pulse's stream.
    static let pulseIndex  = 127
    static let lead2Index  = 128
    static let rhythmIndex = 129

    // MARK: - Shape
    /// One body section A, then an outro of 6 to 12 bars drawn per song (dials.outroBars); no
    /// intro (Zack, 2026-11-20).
    /// The song ends this many bars after the pads' held breath, for the reverb and echo wash.
    static let tailBars       = 2
    /// The pads' held breath: the final 6 bars of music, fewer in a short outro. The outro must
    /// hold the tail and the held breath, so it is the outro less the tail, at most 6 (4 to 6).
    static func heldBreathBars(outroBars: Int) -> Int { Swift.min(6, outroBars - tailBars) }

    let dials: AmbientZenDials
    let key: String
    let tempo: Int
    let totalBars: Int
    /// var only so colourPads can set the pad voicings after the walk.
    var windows: [ZenWindow]
    /// The swell, one value per bar from -1 (sparse) to +1 (full): AMB-1's arc (plan section 8).
    /// Empty until make or rebuild fills it; swell(atBar:) reads it.
    var swell: [Double] = []

    var mode: Mode { dials.mode }
    var tonicPC: Int { keySemitone(key) % 12 }
    /// The scale's leading tone, a semitone under the tonic (absent from Dorian, Mixolydian and Aeolian).
    var leadingTonePC: Int { (tonicPC + 11) % 12 }
    /// Pedal tonic in MIDI 48 to 59, its fifth 7 above (section 6, rule 3).
    var pedalTonicNote: Int { 48 + tonicPC }
    var pedalFifthNote: Int { pedalTonicNote + 7 }
    var outroBars: Int { dials.outroBars }
    var outroStartBar: Int { totalBars - outroBars }
    var musicEndBar: Int { totalBars - Self.tailBars }
    var heldBreathStartBar: Int { musicEndBar - Self.heldBreathBars(outroBars: outroBars) }
    /// The bar where a track's music stops: the end of the music less its offset. The tracks
    /// are Pads, Pedal and Bass, as in dials.endOffsets.
    var padsEndBar: Int  { musicEndBar - dials.endOffsets[0] }
    var pedalEndBar: Int { musicEndBar - dials.endOffsets[1] }
    var bassEndBar: Int  { musicEndBar - dials.endOffsets[2] }
    /// MIDI steps per second at the Zen tempo.
    var stepsPerSecond: Double { Double(tempo) / 15.0 }

    /// A window's chord as a Roman numeral with its quality, as the Chill logs write them:
    /// IVm7, bVImaj7, V7.
    static func numeral(degree: String, type: ChordType) -> String {
        let romans = ["I", "II", "III", "IV", "V", "VI", "VII"]
        let accidental = degree.hasPrefix("b") ? "b" : degree.hasPrefix("#") ? "#" : ""
        let n = degreeNumber(degree)
        let quality: String
        switch type {
        case .min7:   quality = "m7"
        case .maj7:   quality = "maj7"
        case .dom7:   quality = "7"
        case .min7b5: quality = "m7b5"
        default:      quality = ""
        }
        return accidental + romans[Swift.max(0, Swift.min(6, n - 1))] + quality
    }

    /// A degree string's number, 1 to 7: "b3" is 3, "#4" is 4.
    static func degreeNumber(_ degree: String) -> Int {
        Int(degree.drop { $0 == "b" || $0 == "#" }) ?? 1
    }

    /// Two MIDI notes a semitone or a minor 9th apart: the clash every Zen track avoids.
    static func rubs(_ a: Int, _ b: Int) -> Bool {
        let d = abs(a - b)
        return d == 1 || d == 13
    }

    /// Two pitch classes a semitone apart, either way round.
    static func pcNear(_ a: Int, _ b: Int) -> Bool {
        let d = (a - b + 12) % 12
        return d == 1 || d == 11
    }

    /// The chord the song comes home from (the last body window), or nil when it is the tonic.
    var wayHome: String? {
        guard windows.count >= 2 else { return nil }
        let w = windows[windows.count - 2]
        return w.degree == windows[windows.count - 1].degree ? nil : Self.numeral(degree: w.degree, type: w.type)
    }

    /// The window in force at a bar (the last one past the end).
    func windowIndex(atBar bar: Int) -> Int {
        for (i, w) in windows.enumerated() where bar < w.endBar { return i }
        return windows.count - 1
    }

    /// The pedal notes a window keeps, as MIDI notes.
    func pedalNotes(_ w: ZenWindow) -> [Int] {
        (w.keepsTonic ? [pedalTonicNote] : []) + (w.keepsFifth ? [pedalFifthNote] : [])
    }

    /// Every bass note a window may hold, under either bass rule: the root at MIDI 36 + its pitch
    /// class, its octave (AMB-BASS-008) and the fifths each may move to (never the leading tone).
    /// The pads and the pedal keep clear of all of them, so neither bass rule can put a semitone
    /// between the bass and the bed.
    func bassNotes(_ w: ZenWindow) -> [Int] {
        Self.bassNotes(rootPC: w.rootPC, fifthInterval: w.fifthInterval, leadingTonePC: leadingTonePC)
    }

    static func bassNotes(rootPC: Int, fifthInterval: Int, leadingTonePC: Int) -> [Int] {
        let root  = 36 + rootPC
        let upper = root + 12
        guard (rootPC + fifthInterval) % 12 != leadingTonePC else { return [root, upper] }
        let fifth      = root + fifthInterval > 47 ? root + fifthInterval - 12 : root + fifthInterval
        let upperFifth = upper + fifthInterval > 59 ? upper + fifthInterval - 12 : upper + fifthInterval
        return [root, upper, fifth, upperFifth]
    }

    // MARK: - Tempo

    /// The Zen tempo: the dial, or a user tempo override of 92 or below, clamped as the Ambient
    /// frame clamps it.
    static func zenTempo(dials: AmbientZenDials, tempoOverride: Int?) -> Int {
        let t: Int
        if let o = tempoOverride, o <= 92 { t = o } else { t = dials.tempo }
        return Swift.max(62, Swift.min(t, 110))
    }

    // MARK: - Chord table (plan section 5, in C; degrees transpose with the key)

    static func chordTable(_ mode: Mode) -> [ZenChord] {
        switch mode {
        case .Dorian:
            return [ZenChord(degree: "1",  type: .min7,   weight: 4),
                    ZenChord(degree: "2",  type: .min7,   weight: 2),
                    ZenChord(degree: "b3", type: .maj7,   weight: 1),
                    ZenChord(degree: "4",  type: .dom7,   weight: 3),
                    ZenChord(degree: "5",  type: .min7,   weight: 3),
                    ZenChord(degree: "6",  type: .min7b5, weight: 3),
                    ZenChord(degree: "b7", type: .maj7,   weight: 0.4)]
        case .Mixolydian:
            return [ZenChord(degree: "1",  type: .dom7,   weight: 4),
                    ZenChord(degree: "2",  type: .min7,   weight: 2),
                    ZenChord(degree: "3",  type: .min7b5, weight: 1),
                    ZenChord(degree: "4",  type: .maj7,   weight: 3),
                    ZenChord(degree: "5",  type: .min7,   weight: 3),
                    ZenChord(degree: "6",  type: .min7,   weight: 3),
                    ZenChord(degree: "b7", type: .maj7,   weight: 0.4)]
        case .Aeolian:
            return [ZenChord(degree: "1",  type: .min7,   weight: 4),
                    ZenChord(degree: "2",  type: .min7b5, weight: 2),
                    ZenChord(degree: "b3", type: .maj7,   weight: 1),
                    ZenChord(degree: "4",  type: .min7,   weight: 3),
                    ZenChord(degree: "5",  type: .min7,   weight: 3),
                    ZenChord(degree: "b6", type: .maj7,   weight: 3),
                    ZenChord(degree: "b7", type: .dom7,   weight: 0.4)]
        case .Lydian:
            // vii (Bm7 in C) is not used: its root sits a semitone under the tonic pedal.
            return [ZenChord(degree: "1",  type: .maj7,   weight: 4),
                    ZenChord(degree: "2",  type: .dom7,   weight: 2),
                    ZenChord(degree: "3",  type: .min7,   weight: 1),
                    ZenChord(degree: "#4", type: .min7b5, weight: 3),
                    ZenChord(degree: "5",  type: .maj7,   weight: 3),
                    ZenChord(degree: "6",  type: .min7,   weight: 3)]
        default:
            // Ionian. vii (Bm7b5 in C) is not used, as in Lydian.
            return [ZenChord(degree: "1",  type: .maj7,   weight: 4),
                    ZenChord(degree: "2",  type: .min7,   weight: 2),
                    ZenChord(degree: "3",  type: .min7,   weight: 1),
                    ZenChord(degree: "4",  type: .maj7,   weight: 3),
                    ZenChord(degree: "5",  type: .dom7,   weight: 3),
                    ZenChord(degree: "6",  type: .min7,   weight: 3)]
        }
    }

    /// The way home: the window before the outro tonic is drawn from this list (degree, weight).
    static func cadenceList(_ mode: Mode) -> [(degree: String, weight: Double)] {
        switch mode {
        case .Lydian:     return [("2", 0.4), ("5", 0.3), ("6", 0.3)]
        case .Mixolydian: return [("b7", 0.4), ("4", 0.4), ("5", 0.2)]
        case .Dorian:     return [("4", 0.5), ("b7", 0.3), ("2", 0.2)]
        case .Aeolian:    return [("4", 0.4), ("b7", 0.3), ("b6", 0.3)]
        default:          return [("4", 0.5), ("2", 0.25), ("5", 0.25)]
        }
    }

    // MARK: - Building

    /// The plan for a newly generated song.
    static func make(seed: UInt64, key: String, tempo: Int, totalBars: Int) -> AmbientZenPlan {
        let dials = AmbientZenDials.draw(seed: seed)
        var rng   = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: walkIndex))
        let bodyEnd = Swift.max(4, totalBars - dials.outroBars)

        // AMB-PADS-015 Big Ship Cycle: the cycle replaces the drift (it reads the walk stream,
        // which only the drift reads otherwise).
        if dials.cycle != .none, bodyEnd >= 16 {
            var plan = AmbientZenPlan(dials: dials, key: key, tempo: tempo, totalBars: totalBars,
                                      windows: cycleWindows(rng: &rng, dials: dials, key: key,
                                                            bodyEnd: bodyEnd, totalBars: totalBars))
            plan.finish(seed: seed)   // colourPads returns at once under Big Ship
            return plan
        }

        // Window lengths first: the chord pace x random 0.7 to 1.3, in whole bars, at least 4.
        func drawLength() -> Int {
            let secs = dials.chordPaceSeconds * (0.7 + 0.6 * rng.nextDouble())
            return Swift.max(4, Int((secs * Double(tempo) / 240.0).rounded()))
        }
        var lengths: [Int] = []
        let first = drawLength()
        if bodyEnd - first < 4 {
            lengths = [bodyEnd]
        } else {
            lengths = [first]
            var cursor = first
            while cursor < bodyEnd {
                let remaining = bodyEnd - cursor
                let len = drawLength()
                // The last body window, the cadence, takes whatever is left.
                if remaining - len < 4 { lengths.append(remaining); break }
                lengths.append(len)
                cursor += len
            }
        }

        // Then the chords: the tonic, AMB-1's weighted walk, and the cadence window.
        let table = chordTable(dials.mode)
        let tonic = table[0]
        func walk(from current: ZenChord) -> ZenChord {
            let weights = table.map { $0.degree == current.degree ? 0 : $0.weight }
            let total = weights.reduce(0, +)
            return rng.pick(table, weights: weights.map { $0 / total })
        }
        var chords: [ZenChord] = [tonic]
        for i in 1..<Swift.max(1, lengths.count) {
            let current = chords[chords.count - 1]
            if i == lengths.count - 1 {
                // The way home, never the chord already playing.
                let options = cadenceList(dials.mode).filter { $0.degree != current.degree }
                let total = options.reduce(0) { $0 + $1.weight }
                let pick = rng.pick(options.map(\.degree), weights: options.map { $0.weight / total })
                chords.append(table.first { $0.degree == pick } ?? tonic)
            } else {
                var next = walk(from: current)
                // Landing on the tonic just before the cadence window redraws once.
                if i == lengths.count - 2 && next.degree == tonic.degree { next = walk(from: current) }
                chords.append(next)
            }
        }

        var windows: [ZenWindow] = []
        var start = 0
        for (len, chord) in zip(lengths, chords) {
            windows.append(makeWindow(start: start, length: len, degree: chord.degree, type: chord.type,
                                      key: key, mode: dials.mode))
            start += len
        }
        // The outro: the tonic again, to the end of the song.
        windows.append(makeWindow(start: start, length: Swift.max(1, totalBars - start),
                                  degree: tonic.degree, type: tonic.type, key: key, mode: dials.mode))
        var plan = AmbientZenPlan(dials: dials, key: key, tempo: tempo, totalBars: totalBars, windows: windows)
        plan.finish(seed: seed)
        return plan
    }

    /// The last steps of every plan, new or rebuilt: the swell curve, then the pad colours.
    mutating func finish(seed: UInt64) {
        swell = Self.swellCurve(seed: seed, tempo: tempo, totalBars: totalBars, outroStartBar: outroStartBar)
        colourPads()
    }

    // MARK: - Pad colours (Zack, 2026-11-21)

    /// Share of non-tonic windows whose pads take the 9th in place of the root.
    static let ninthShare = 0.20
    /// Share of non-tonic windows whose pads drop the 7th (taken after the 9th's share).
    static let triadShare = 0.10

    /// Colours the drift's pad voicings: in songs with the 6/9 dial, every tonic window as a
    /// rootless 6/9 (Ionian and Lydian); in other windows the 9th for the root (20 percent, only
    /// where the 9th is a safe tension) or a plain triad (10 percent). Not under Big Ship or Shell
    /// Voices. Every added note is a scale note that sits a semitone from no chord tone, pad tone,
    /// Texture note or bass note in the window; a colour that would is left plain. One draw per
    /// window from its own stream, so a rebuild from the song's windows gives the same colours.
    mutating func colourPads() {
        guard dials.cycle == .none, !dials.shellVoices else { return }
        var rng = SeededRNG(seed: dials.padColourSeed)
        let scale = mode.intervals.map { (tonicPC + $0) % 12 }
        let near = Self.pcNear
        for i in windows.indices {
            let roll = rng.nextDouble()
            let w = windows[i]
            guard w.chordTones.count == 4, let r = scale.firstIndex(of: w.rootPC) else { continue }
            let ninth = scale[(r + 1) % 7], sixth = scale[(r + 5) % 7]
            let ct = w.chordTones
            var voicing = ZenPadVoicing.seventh
            var tones: [Int] = []
            if w.rootPC == tonicPC {
                if dials.homeSixNine, mode == .Ionian || mode == .Lydian {
                    voicing = .sixNine; tones = [sixth, ct[1], ct[2], ninth]
                }
            } else if roll < Self.ninthShare {
                if w.safeTensions.contains(ninth) { voicing = .ninth; tones = [ninth, ct[1], ct[2], ct[3]] }
            } else if roll < Self.ninthShare + Self.triadShare {
                voicing = .triad; tones = [ct[0], ct[1], ct[2], ct[0]]
            }
            guard !tones.isEmpty else { continue }
            let bed = (pedalNotes(w) + bassNotes(w)).map { $0 % 12 }
            let added = tones.filter { !ct.contains($0) }
            let clear = added.allSatisfy { a in
                !ct.contains { near(a, $0) } && !tones.contains { near(a, $0) } && !bed.contains { near(a, $0) }
            }
            if clear { windows[i].padVoicing = voicing; windows[i].padTones = tones }
        }
    }

    /// The pad colours in plain words for the Chords line ("" when every window is plain).
    var padColourWords: String {
        let kinds = Set(windows.map(\.padVoicing))
        var parts: [String] = []
        if kinds.contains(.ninth) { parts.append("9ths") }
        if kinds.contains(.triad) { parts.append("triads") }
        if kinds.contains(.sixNine) { parts.append("6/9 home") }
        return parts.isEmpty ? "" : ", pads with " + parts.joined(separator: " and ")
    }

    // MARK: - The Big Ship cycle

    /// Bars per chord in the Big Ship cycle (Zack, 2026-11-09: 2 bars was too fast).
    static let cycleChordBars = 4
    /// The cycle's slots: A B T B A B T C, where 3 is the tonic, so the tonic comes round twice
    /// and C turns the cycle round (Eno's The Big Ship: Am F C F Am F C G).
    static let cycleSlots = [0, 1, 3, 1, 0, 1, 3, 2]

    /// The Big Ship windows: A, B and C drawn from the chord table on the walk weights without
    /// repeats or the tonic, then the cycle at 4 bars a chord. The body is a whole number of chord
    /// pairs, so it always ends on B or C, each of which goes to T in the cycle itself; the
    /// leftover bars join the outro's tonic.
    static func cycleWindows(rng: inout SeededRNG, dials: AmbientZenDials, key: String,
                             bodyEnd: Int, totalBars: Int) -> [ZenWindow] {
        let table = chordTable(dials.mode)
        let tonic = table[0]
        var pool  = Array(table.dropFirst())
        var picks: [ZenChord] = []
        for _ in 0..<3 {
            let total = pool.reduce(0) { $0 + $1.weight }
            let chord = rng.pick(pool, weights: pool.map { $0.weight / total })
            picks.append(chord)
            pool.removeAll { $0.degree == chord.degree }
        }
        let chords = picks + [tonic]
        let pair   = 2 * cycleChordBars
        let body   = (bodyEnd / pair) * pair
        var windows: [ZenWindow] = []
        var start = 0, slot = 0
        while start < body {
            let c = chords[cycleSlots[slot % cycleSlots.count]]
            windows.append(makeWindow(start: start, length: cycleChordBars, degree: c.degree, type: c.type,
                                      key: key, mode: dials.mode))
            start += cycleChordBars
            slot  += 1
        }
        windows.append(makeWindow(start: start, length: Swift.max(1, totalBars - start),
                                  degree: tonic.degree, type: tonic.type, key: key, mode: dials.mode))
        return windows
    }

    /// The cycle in numerals for the Chords line: its eight chords, one pass.
    var cycleNumerals: String {
        windows.prefix(Self.cycleSlots.count).map { Self.numeral(degree: $0.degree, type: $0.type) }
            .joined(separator: " ")
    }

    // MARK: - The swell (plan section 8)

    /// The swell's stream, and its first draw: the per-song scale, 0.5 to 0.9. swellCurve and
    /// swellDepthWords both read it here, so the log's depth word always matches the curve.
    private static func swellRNG(seed: UInt64) -> SeededRNG {
        SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: swellIndex))
    }
    private static func swellScale(_ rng: inout SeededRNG) -> Double { 0.5 + 0.4 * rng.nextDouble() }

    /// AMB-1's arc, per bar. Every 50 to 150 s a new target is drawn (random -1 to 1 times 0.6 to
    /// 1.0, pushed 0.25 further from the middle, clamped); the value eases toward it with a 35 s
    /// time constant and is scaled by 0.5 to 0.9 per song. Held at -0.5 or below for the first 8
    /// bars and in the outro. A pure function of the seed, tempo and length, so a regenerated
    /// track reads the same curve.
    static func swellCurve(seed: UInt64, tempo: Int, totalBars: Int, outroStartBar: Int) -> [Double] {
        var rng = swellRNG(seed: seed)
        let barSeconds = 240.0 / Double(Swift.max(1, tempo))
        let ease  = 1 - exp(-barSeconds / 35.0)
        let scale = swellScale(&rng)
        func newTarget() -> Double {
            let raw = (2 * rng.nextDouble() - 1) * (0.6 + 0.4 * rng.nextDouble())
            let pushed = raw + (raw < 0 ? -0.25 : 0.25)
            return Swift.max(-1, Swift.min(1, pushed))
        }
        var value = -0.5
        var target = newTarget()
        var untilNext = 50 + 100 * rng.nextDouble()
        var out: [Double] = []
        for bar in 0..<Swift.max(0, totalBars) {
            value += (target - value) * ease
            var s = value * scale
            if bar < 8 || bar >= outroStartBar { s = Swift.min(s, -0.5) }
            out.append(s)
            untilNext -= barSeconds
            if untilNext <= 0 {
                target = newTarget()
                untilNext = 50 + 100 * rng.nextDouble()
            }
        }
        return out
    }

    /// The swell's depth in plain words, for the Zen log line: the first draw of swellCurve's
    /// stream (its `scale`, 0.5 to 0.9), read on a fresh copy, so nothing moves.
    static func swellDepthWords(seed: UInt64) -> String {
        var rng = swellRNG(seed: seed)
        let scale = swellScale(&rng)
        return scale < 0.633 ? "gentle" : scale < 0.767 ? "medium" : "deep"
    }

    /// The swell at a bar (-0.5 past either end).
    func swell(atBar bar: Int) -> Double {
        bar >= 0 && bar < swell.count ? swell[bar] : -0.5
    }

    /// A song's swell curve without rebuilding its windows: what rebuild(from:) would give.
    static func swell(for song: SongState, dials: AmbientZenDials) -> [Double] {
        swellCurve(seed: song.globalSeed, tempo: zenTempo(dials: dials, tempoOverride: song.tempoOverride),
                   totalBars: song.frame.totalBars, outroStartBar: song.frame.totalBars - dials.outroBars)
    }

    /// The plan of an existing song, for a track regeneration: the dials from the seed and the
    /// chord windows the song already has.
    static func rebuild(from song: SongState) -> AmbientZenPlan {
        let dials = AmbientZenDials.draw(seed: song.globalSeed)
        let tempo = zenTempo(dials: dials, tempoOverride: song.tempoOverride)
        let windows = song.structure.chordPlan.map {
            makeWindow(start: $0.startBar, length: $0.lengthBars, degree: $0.chordRoot, type: $0.chordType,
                       key: song.frame.key, mode: dials.mode)
        }
        var plan = AmbientZenPlan(dials: dials, key: song.frame.key, tempo: tempo,
                                  totalBars: song.frame.totalBars, windows: windows)
        plan.finish(seed: song.globalSeed)
        return plan
    }

    static func makeWindow(start: Int, length: Int, degree: String, type: ChordType,
                           key: String, mode: Mode) -> ZenWindow {
        let keyPC  = keySemitone(key) % 12
        let rootPC = (keyPC + degreeSemitone(degree)) % 12
        let tones  = type.intervals.map { (rootPC + $0) % 12 }
        let toneSet = Set(tones)
        let scale  = mode.intervals.map { (keyPC + $0) % 12 }
        // A tension is safe unless it sits a semitone above a chord tone.
        let safe = scale.filter { s in
            !toneSet.contains(s) && !tones.contains { (s - $0 + 12) % 12 == 1 }
        }
        // A pedal note that is not a chord tone drops when it sits a semitone from one.
        func keeps(_ pc: Int) -> Bool {
            toneSet.contains(pc) || !tones.contains { pcNear(pc, $0) }
        }
        var keepsTonic = keeps(keyPC), keepsFifth = keeps((keyPC + 7) % 12)
        // A pedal note a semitone or a minor 9th from a bass note drops too. Only Aeolian's bVI
        // in C to Eb does this: the pedal fifth sits a semitone under AMB-BASS-008's upper root.
        let bass = bassNotes(rootPC: rootPC, fifthInterval: type.fifthInterval, leadingTonePC: (keyPC + 11) % 12)
        func clearOfBass(_ note: Int) -> Bool { !bass.contains { rubs($0, note) } }
        let tonicClear = clearOfBass(48 + keyPC), fifthClear = clearOfBass(55 + keyPC)
        if (keepsTonic && tonicClear) || (keepsFifth && fifthClear) {
            keepsTonic = keepsTonic && tonicClear
            keepsFifth = keepsFifth && fifthClear
        }
        return ZenWindow(startBar: start, lengthBars: length, degree: degree, type: type,
                         chordTones: tones, safeTensions: safe,
                         keepsTonic: keepsTonic, keepsFifth: keepsFifth)
    }

    // MARK: - Structure

    /// Two sections, A and the outro, in the Zen mode, and the chord plan from the windows.
    func structure() -> SongStructure {
        let outroStart = Swift.min(outroStartBar, windows.last?.startBar ?? outroStartBar)
        let sections = [
            SongSection(startBar: 0, lengthBars: outroStart, label: .A, intensity: .medium, mode: mode),
            SongSection(startBar: outroStart, lengthBars: totalBars - outroStart, label: .outro,
                        intensity: .low, mode: mode),
        ]
        let chordPlan = windows.map { w -> ChordWindow in
            let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: w.degree, chordType: w.type,
                                                     key: key, mode: mode)
            return ChordWindow(startBar: w.startBar, lengthBars: w.lengthBars, chordRoot: w.degree,
                               chordType: w.type, chordTones: ct, scaleTensions: st, avoidTones: at)
        }
        return SongStructure(sections: sections, chordPlan: chordPlan,
                             introStyle: .alreadyPlaying, outroStyle: .fade)
    }
}
