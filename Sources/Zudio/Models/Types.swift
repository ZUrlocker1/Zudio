// Types.swift — all enums and track-index constants (authoritative per prototype spec)

import Foundation

// MARK: - Track index constants
let kTrackLead1   = 0
let kTrackLead2   = 1
let kTrackPads    = 2
let kTrackRhythm  = 3
let kTrackTexture = 4
let kTrackBass    = 5
let kTrackDrums      = 6
let kTrackLeadSynth  = 7   // Kosmic only: silent Fantasia layer doubling Lead 1
let kTrackCount      = 8

let kTrackNames = ["Lead 1", "Lead 2", "Pads", "Rhythm", "Texture", "Bass", "Drums", "Lead Synth"]

// MIDI channel per track (Drums must be channel 9 for GM)
let kTrackMIDIChannels: [UInt8] = [0, 1, 2, 3, 4, 5, 9, 6]

// MARK: - Track effects

enum TrackEffect: String, CaseIterable {
    case boost       = "Boost"
    case delay       = "Delay"
    case reverb      = "Reverb"
    case tremolo     = "Trem"
    case compression = "Comp"
    case lowShelf    = "Low"
    case sweep       = "Sweep"   // LFO-driven low-pass filter sweep
    case pan         = "Pan"     // LFO-driven auto-pan
    case space       = "Hall"    // Hall/chamber reverb (large acoustic space)
}

// MARK: - Musical enumerations

enum Mode: String, CaseIterable, Codable, Sendable {
    case Ionian, Dorian, Mixolydian, Aeolian, MinorPentatonic, MajorPentatonic

    // Scale degrees as semitones above root
    var intervals: [Int] {
        switch self {
        case .Ionian:          return [0, 2, 4, 5, 7, 9, 11]
        case .Dorian:          return [0, 2, 3, 5, 7, 9, 10]
        case .Mixolydian:      return [0, 2, 4, 5, 7, 9, 10]
        case .Aeolian:         return [0, 2, 3, 5, 7, 8, 10]
        case .MinorPentatonic: return [0, 3, 5, 7, 10]
        case .MajorPentatonic: return [0, 2, 4, 7, 9]
        }
    }

    /// Snaps `semitones` to the nearest interval present in this mode's scale.
    /// Use for diatonic scale degrees (3rd, 6th, 7th) that differ between modes.
    /// Purely chromatic passing tones (tritone, neighbour notes) should not use this.
    ///
    /// Examples:
    ///   Ionian.nearestInterval(4)  → 4  (major 3rd stays major)
    ///   Aeolian.nearestInterval(4) → 3  (snaps to minor 3rd)
    ///   Aeolian.nearestInterval(9) → 8  (major 6th snaps to minor 6th)
    ///   Ionian.nearestInterval(10) → 9  (b7 snaps to major 6th — closest scale tone)
    func nearestInterval(_ semitones: Int) -> Int {
        intervals.min(by: { abs($0 - semitones) < abs($1 - semitones) }) ?? semitones
    }
}

enum Mood: String, CaseIterable, Codable, Sendable {
    case Bright, Deep, Dream, Free

    var primaryMode: Mode {
        switch self {
        case .Bright: return .Ionian
        case .Deep:   return .Aeolian
        case .Dream:  return .Dorian
        case .Free:   return .Aeolian
        }
    }
}

enum SectionLabel: String, Codable, Sendable {
    case intro, A, B, outro
    case bridge        // Archetype A-1: escalating drum bridge (Mister Mosca style)
    case bridgeAlt     // Archetype A-2: sparse hit + call-and-response (Caligari Drop style)
    case bridgeMelody  // Archetype B: melody-driven long bridge (Dark Sun style)
    case preRamp       // 4-8 bar transition INTO bridgeMelody
    case postRamp      // 4-8 bar transition OUT OF bridgeMelody back to A

    /// True for any bridge variant (all three archetypes). Rhythm/Texture/Lead2 are silent here.
    var isBridge: Bool {
        self == .bridge || self == .bridgeAlt || self == .bridgeMelody
    }
}

enum SectionIntensity: String, Codable, Sendable, Comparable {
    case low, medium, high

    private var order: Int {
        switch self { case .low: return 0; case .medium: return 1; case .high: return 2 }
    }

    static func < (lhs: SectionIntensity, rhs: SectionIntensity) -> Bool {
        lhs.order < rhs.order
    }

    func stepped(by delta: Int) -> SectionIntensity {
        let clamped = max(0, min(2, order + delta))
        switch clamped { case 0: return .low; case 2: return .high; default: return .medium }
    }
}

enum ChordType: String, Codable, Sendable {
    case major, minor, sus2, sus4, add9, dom7, min7, quartal, power

    // Semitone intervals from chord root
    var intervals: [Int] {
        switch self {
        case .major:   return [0, 4, 7]
        case .minor:   return [0, 3, 7]
        case .sus2:    return [0, 2, 7]
        case .sus4:    return [0, 5, 7]
        case .add9:    return [0, 4, 7, 14]
        case .dom7:    return [0, 4, 7, 10]
        case .min7:    return [0, 3, 7, 10]
        case .quartal: return [0, 5, 10]
        case .power:   return [0, 7, 12]
        }
    }

    // Pitch classes (mod 12)
    var pitchClasses: Set<Int> { Set(intervals.map { $0 % 12 }) }

    /// True for chord types that imply a major harmonic context in bass patterns.
    /// Used to decide whether b7 / flatSeven slots use the mode's b7 or a neutral replacement.
    var isMajorContext: Bool {
        switch self {
        case .major, .sus2, .sus4, .add9: return true
        default:                           return false
        }
    }
}

enum ProgressionFamily: String, Codable, Sendable {
    case static_tonic
    case two_chord_I_bVII
    case minor_loop_i_VII
    case minor_loop_i_VI
    case modal_cadence_bVI_bVII_I
}

// MARK: - Music style

enum MusicStyle: String, CaseIterable, Codable, Sendable {
    case motorik = "Motorik"
    case kosmic  = "Kosmic"
    case ambient = "Ambient"
    case chill   = "Chill"
}

// MARK: - Chill progression families

enum ChillProgressionFamily: String, Codable, Sendable {
    case static_groove       // One chord throughout (35%)
    case two_chord_pendulum  // Two chords alternating every 4–8 bars (30%)
    case minor_blues         // 12-bar blues tile in groove sections (20%)
    case modal_drift         // 2–3 slow chord changes over the full song (15%)
}

// MARK: - Chill lead instrument

enum ChillLeadInstrument: String, Codable, Sendable {
    case flute         // GM 73 — Bright/Free; Lead 2 default
    case mutedTrumpet  // GM 59 — Deep/Dream primary
    case vibraphone    // GM 11 — Lead 2 default
    case saxophone     // GM 65 — Deep/Dream secondary
    case sopranoSax    // GM 64 — brighter reed; Lead 1
    case trumpet       // GM 56 — open horn; brighter than muted; Lead 1
    case trombone      // GM 57 — warm low brass; Lead 2
}

// MARK: - Chill beat style

enum ChillBeatStyle: String, Codable, Sendable {
    case electronic   // 808 kit, syncopated hip-hop feel (Deep/Dream)
    case neoSoul      // programmed but warm, ghost notes (Bright/Free)
    case brushKit     // acoustic brushed jazz kit (Bright/Free)
    case stGermain    // four-on-the-floor kick + 8th-note ride, St Germain style (Bright/Free)
    case hipHopJazz   // CHL-DRUM-005: kick 1+3, snare 2+4, steady 8th hat, tambourine texture
}

// MARK: - Chill breakdown style

enum ChillBreakdownStyle: String, Codable, Sendable {
    case stopTime       // Unison stabs on beat 1 of every other bar; lead plays freely in the gaps
    case bassOstinato   // Syncopated bass riff only; drums and harmonic instruments silent
    case harmonicDrone  // Beat continues at full density; bass simplifies to root pulse; lead plays over drone
}

// MARK: - Percussion style (Kosmic + future Ambient)

enum PercussionStyle: String, Codable, Sendable {
    case absent
    case sparse
    case minimal
    case motorikGrid               // Electric Buddha groove — 8th-note hi-hat + varied rock kick/snare (KOS-DRUM-004)
    case electricBuddhaPulse       // Electric Buddha pulse — quarter-note hi-hat + half-time kick/snare (KOS-DRUM-005)
    case electricBuddhaRestrained  // Electric Buddha restrained — ride+clap+4-on-floor kick, periodic dropouts (KOS-DRUM-006)
    case handPercussion              // Ambient: congas, bongos, shakers (AMB-DRUM-004)
    case textural                    // Ambient: sparse brush/ride (AMB-DRUM-001)
    case softPulse                   // Ambient: gentle kick + hat (AMB-DRUM-002)
}

// MARK: - Kosmic song forms

enum KosmicSongForm: String, Codable, Sendable {
    case single_evolving    // A only — one long evolving section
    case ab                 // A → B
    case aba                // A → B → A
    case abab               // A → B → A → B (two full cycles)
    case abba               // A → B → B → A (double B, TD-like)
    // Legacy names kept for any persisted state
    case two_world          // alias for ab
    case build_and_dissolve // alias for aba
}

// MARK: - Kosmic progression families

enum KosmicProgressionFamily: String, Codable, Sendable {
    case static_drone
    case two_chord_pendulum
    case modal_drift
    case suspended_resolution
    case quartal_stack
}

// MARK: - Ambient progression families

enum AmbientProgressionFamily: String, Codable, Sendable {
    case droneSingle    // Single root drone throughout
    case droneTwo       // Two-chord pendulum, very slow movement
    case modalDrift     // Gradual mode drift over the song
    case suspendedDrone // Sus2/sus4 chord as drone base
    case dissonantHaze  // Minor cluster with min7 tension
}

// MARK: - Ambient tempo style

enum AmbientTempoStyle: String, Codable, Sendable {
    case beatless   // 62–78 BPM
    case slowPulse  // 72–92 BPM
    case midPulse   // 95–110 BPM
}

// MARK: - Ambient loop lengths (co-prime primes, one per track)

struct AmbientLoopLengths: Sendable {
    let lead1: Int
    let lead2: Int
    let pads: Int
    let rhythm: Int
    let texture: Int
    let bass: Int

    func loopBars(forTrack trackIndex: Int) -> Int {
        switch trackIndex {
        case kTrackLead1:   return lead1
        case kTrackLead2:   return lead2
        case kTrackPads:    return pads
        case kTrackRhythm:  return rhythm
        case kTrackTexture: return texture
        case kTrackBass:    return bass
        default:            return pads
        }
    }
}

enum SongForm: String, Sendable {
    case singleA
    case subtleAB
    case moderateAB
}

/// How the song enters from silence.
enum IntroStyle: Equatable, Sendable {
    /// Neu!/Harmonia style — full groove present from bar 1 at ~55% velocity, ramping to full.
    /// Bass plays its actual pattern. Pads present throughout. "Already in motion."
    case alreadyPlaying
    /// Can style — full Motorik groove from bar 0, actual bass rule at reduced velocity, pads enter last bar.
    case progressiveEntry
    /// Cold start — pickup fill launches the song, then full groove enters on the next downbeat.
    /// drumsOnly: true = bar 0 is drums alone (bass and pads silent); false = bass grounds the pickup.
    case coldStart(drumsOnly: Bool)
}

/// How the song exits to silence.
enum OutroStyle: Equatable, Sendable {
    /// Full groove with velocity fading to near-silence over all outro bars.
    case fade
    /// Drums strip back progressively; pads/texture hold all the way to the final bar.
    case dissolve
    /// Full groove until the final bar, which is a big closing fill → complete silence.
    case coldStop
}

// MARK: - Scale-snapping utilities

/// Snaps `pc` to the nearest pitch class present in `scalePCs`, using circular semitone distance.
/// Returns `pc` unchanged if it is already in the scale.
func nearestScalePitchClass(_ pc: Int, in scalePCs: Set<Int>) -> Int {
    guard !scalePCs.contains(pc) else { return pc }
    return scalePCs.min(by: {
        min(abs($0 - pc), 12 - abs($0 - pc)) < min(abs($1 - pc), 12 - abs($1 - pc))
    }) ?? pc
}

// MARK: - Key semitone table

/// Maps a key name string to its semitone offset from C (0–11).
func keySemitone(_ key: String) -> Int {
    switch key {
    case "C":        return 0
    case "C#", "Db": return 1
    case "D":        return 2
    case "D#", "Eb": return 3
    case "E":        return 4
    case "F":        return 5
    case "F#", "Gb": return 6
    case "G":        return 7
    case "G#", "Ab": return 8
    case "A":        return 9
    case "A#", "Bb": return 10
    case "B":        return 11
    default:         return 0
    }
}

let kAllKeys = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

// MARK: - Degree string to semitone table

func degreeSemitone(_ degree: String) -> Int {
    switch degree {
    case "1":        return 0
    case "b2":       return 1
    case "2":        return 2
    case "b3":       return 3
    case "3":        return 4
    case "4":        return 5
    case "#4", "b5": return 6
    case "5":        return 7
    case "b6":       return 8
    case "6":        return 9
    case "b7":       return 10
    case "7":        return 11
    default:         return 0
    }
}

// MARK: - MIDI note formula

/// Converts key + degree + octave offset to an absolute MIDI note number.
/// midiNote = 60 + keySemitone + degreeSemitone + (oct * 12)
func midiNote(key: String, degree: String, oct: Int) -> Int {
    return 60 + keySemitone(key) + degreeSemitone(degree) + (oct * 12)
}

// MARK: - GM drum notes

enum GMDrum: UInt8 {
    case kick2         = 35
    case kick          = 36
    case sidestick     = 37
    case snare         = 38
    case clap          = 39
    case snare2        = 40
    case lowFloorTom   = 41
    case closedHat     = 42
    case highFloorTom  = 43
    case pedalHat      = 44
    case lowMidTom     = 45
    case openHat       = 46
    case hiMidTom      = 48
    case hiTom         = 50
    case crash1        = 49
    case ride          = 51
    case rideBell      = 53
    case tambourine    = 54
    case crash2        = 57
}

// MARK: - Register boundaries (MIDI note ranges per track)

struct RegisterBounds {
    let low: Int
    let high: Int

    func clamp(_ note: Int) -> Int { max(low, min(high, note)) }
}

let kRegisterBounds: [Int: RegisterBounds] = [
    kTrackLead1:      RegisterBounds(low: 52, high: 79),
    kTrackLead2:      RegisterBounds(low: 55, high: 81),
    kTrackPads:       RegisterBounds(low: 48, high: 84),
    kTrackRhythm:     RegisterBounds(low: 45, high: 76),
    kTrackTexture:    RegisterBounds(low: 36, high: 96),
    kTrackBass:       RegisterBounds(low: 40, high: 64),
    kTrackDrums:      RegisterBounds(low: 35, high: 81),
    kTrackLeadSynth:  RegisterBounds(low: 60, high: 88),
]

// MARK: - Visualizer

/// A note event captured during playback for the iPhone abstract visualizer.
struct VisualizerNote: Identifiable, Sendable {
    let id          = UUID()
    let trackIndex:    Int
    let note:          UInt8   // MIDI pitch 0–127
    let velocity:      UInt8   // 0–127 → drives orb size/brightness
    let birthDate:     Date    // wall-clock spawn time
    let durationSteps: Int     // gate length → drives orb lifetime and comet tail
}

// MARK: - GM program numbers per track (v1 defaults)

let kDefaultGMPrograms: [Int: UInt8] = [
    kTrackLead1:      80,  // Square Lead
    kTrackLead2:      90,  // Polysynth
    kTrackPads:       89,  // Warm Pad
    kTrackRhythm:     28,  // Guitar Pulse
    kTrackTexture:    86,  // Fifths Lead
    kTrackBass:       39,  // Moog Bass
    kTrackDrums:      8,   // Rock Kit
    kTrackLeadSynth:  90,  // Polysynth — Kosmic lead doubling layer
]
