// Types.swift — all enums and track-index constants (authoritative per prototype spec)

// MARK: - Track index constants
let kTrackLead1   = 0
let kTrackLead2   = 1
let kTrackPads    = 2
let kTrackRhythm  = 3
let kTrackTexture = 4
let kTrackBass    = 5
let kTrackDrums   = 6
let kTrackCount   = 7

let kTrackNames = ["Lead 1", "Lead 2", "Pads", "Rhythm", "Texture", "Bass", "Drums"]

// MIDI channel per track (Drums must be channel 9 for GM)
let kTrackMIDIChannels: [UInt8] = [0, 1, 2, 3, 4, 5, 9]

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
    case space       = "Space"   // Cathedral reverb (Pads-specific label)
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
}

enum ProgressionFamily: String, Codable, Sendable {
    case static_tonic
    case two_chord_I_bVII
    case minor_loop_i_VII
    case minor_loop_i_VI
    case modal_cadence_bVI_bVII_I
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
    case crash2        = 57
}

// MARK: - Register boundaries (MIDI note ranges per track)

struct RegisterBounds {
    let low: Int
    let high: Int

    func clamp(_ note: Int) -> Int { max(low, min(high, note)) }
}

let kRegisterBounds: [Int: RegisterBounds] = [
    kTrackLead1:   RegisterBounds(low: 60, high: 88),
    kTrackLead2:   RegisterBounds(low: 55, high: 81),
    kTrackPads:    RegisterBounds(low: 48, high: 84),
    kTrackRhythm:  RegisterBounds(low: 45, high: 76),
    kTrackTexture: RegisterBounds(low: 36, high: 96),
    kTrackBass:    RegisterBounds(low: 40, high: 64),
    kTrackDrums:   RegisterBounds(low: 35, high: 81),
]

// MARK: - GM program numbers per track (v1 defaults)

let kDefaultGMPrograms: [Int: UInt8] = [
    kTrackLead1:   80,  // Square Lead
    kTrackLead2:   80,  // Square Lead
    kTrackPads:    89,  // Warm Pad
    kTrackRhythm:  28,  // Guitar Pulse
    kTrackTexture: 95,  // Swell
    kTrackBass:    39,  // Moog Bass
    kTrackDrums:   8,   // Rock Kit
]
