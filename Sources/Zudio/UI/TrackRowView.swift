// TrackRowView.swift — track controls + MIDI lane + effects column
// Track colors: Lead 1/2 = red, Pads/Rhythm/Texture = blue, Bass = purple, Drums = yellow

import SwiftUI

struct TrackRowView: View {
    @EnvironmentObject var appState: AppState

    let trackIndex: Int
    let label: String
    let events: [MIDIEvent]
    let totalBars: Int
    let isMuted: Bool
    let isSolo: Bool
    let isEffectivelyMuted: Bool
    let visibleBars: Int
    let barOffset: Int
    var showPlayheadHandle: Bool = false
    var onSeek: ((Int) -> Void)? = nil

    // MARK: - Instrument definitions (no "Auto" — always show real name)

    private struct Instrument { let name: String; let program: UInt8 }

    private var instruments: [Instrument] {
        let isKosmic  = activeStyle == .kosmic
        let isAmbient = activeStyle == .ambient
        switch trackIndex {
        case kTrackLead1:
            if isAmbient {
                return [.init(name:"Flute",         program:73),  .init(name:"Ocarina",       program:79),
                        .init(name:"Pan Flute",     program:75),  .init(name:"Whistle",       program:78),
                        .init(name:"Recorder",      program:74),  .init(name:"Brightness",    program:100),
                        .init(name:"Halo Pad",      program:94),  .init(name:"New Age Pad",   program:88),
                        .init(name:"Calliope Lead", program:82)]
            }
            if isKosmic {
                return [.init(name:"Ocarina",        program:79),  .init(name:"Flute",        program:73),
                        .init(name:"Whistle",        program:78),  .init(name:"Calliope Lead", program:82),
                        .init(name:"Soft Brass",     program:56)]
            }
            return [.init(name:"Square Lead",      program:80), .init(name:"Mono Synth",      program:81),
                    .init(name:"Synth Brass",      program:63), .init(name:"Synth Brass 2",   program:62),
                    .init(name:"Fifths Lead",      program:86), .init(name:"Moog Lead",        program:39),
                    .init(name:"Overdrive Gtr",    program:29)]
        case kTrackLead2:
            if isAmbient {
                return [.init(name:"Vibraphone",   program:11),  .init(name:"Celesta",        program:8),
                        .init(name:"Glockenspiel", program:9),   .init(name:"Grand Piano",    program:0),
                        .init(name:"Warm Pad",     program:89),  .init(name:"Space Voice",    program:91),
                        .init(name:"FX Atmosphere",program:99)]
            }
            if isKosmic {
                return [.init(name:"Brightness",   program:100), .init(name:"Warm Pad",       program:89),
                        .init(name:"Halo Pad",     program:94),  .init(name:"New Age Pad",    program:88),
                        .init(name:"Ocarina",       program:79)]
            }
            return [.init(name:"Brightness",     program:100), .init(name:"Vibraphone",      program:11),
                    .init(name:"Bell/Pluck",       program:14)]
        case kTrackPads:
            if isAmbient {
                return [.init(name:"String Ensemble",program:48), .init(name:"Choir Aahs",   program:52),
                        .init(name:"Synth Strings", program:50), .init(name:"Bowed Glass",   program:92),
                        .init(name:"Warm Pad",      program:89), .init(name:"Halo Pad",      program:94),
                        .init(name:"New Age Pad",   program:88), .init(name:"Sweep Pad",     program:95)]
            }
            if isKosmic {
                return [.init(name:"Choir Aahs",   program:52), .init(name:"String Ensemble", program:48),
                        .init(name:"Synth Strings", program:50), .init(name:"Warm Pad",       program:89),
                        .init(name:"Space Voice",   program:91)]
            }
            return [.init(name:"Warm Pad",       program:89), .init(name:"Halo Pad",        program:94),
                    .init(name:"New Age Pad",     program:88), .init(name:"Sweep Pad",       program:95),
                    .init(name:"Bowed Glass",     program:92), .init(name:"Synth Strings",   program:50),
                    .init(name:"String Pad",      program:48), .init(name:"Organ Drone",     program:16)]
        case kTrackRhythm:
            if isAmbient {
                return [.init(name:"Vibraphone",   program:11),  .init(name:"Marimba",        program:12),
                        .init(name:"Tubular Bells",program:14),  .init(name:"Glockenspiel",   program:9),
                        .init(name:"FX Crystal",   program:98),  .init(name:"FX Echoes",      program:102),
                        .init(name:"Church Organ", program:19)]
            }
            if isKosmic {
                return [.init(name:"FX Crystal",      program:98), .init(name:"Vibraphone",      program:11),
                        .init(name:"Elec Piano 2",    program:5),  .init(name:"Church Organ",    program:19),
                        .init(name:"Tremolo Strings", program:44)]
            }
            return [.init(name:"Guitar Pulse",     program:28), .init(name:"Wurlitzer",         program:5),
                    .init(name:"Rock Organ",        program:18), .init(name:"Clavinet",          program:7),
                    .init(name:"Electric Piano",    program:4),  .init(name:"Muted Guitar",      program:29),
                    .init(name:"Mono Synth",        program:80)]
        case kTrackTexture:
            if isAmbient {
                return [.init(name:"String Ensemble 2",program:49), .init(name:"Bowed Glass",  program:92),
                        .init(name:"Choir Aahs",    program:52), .init(name:"Space Voice",      program:91),
                        .init(name:"FX Atmosphere", program:99), .init(name:"Sweep Pad",        program:95),
                        .init(name:"Pad 3 Poly",    program:90)]
            }
            if isKosmic {
                return [.init(name:"FX Atmosphere", program:99), .init(name:"Pad 3 Poly",    program:90),
                        .init(name:"Sweep Pad",      program:95)]
            }
            return [.init(name:"Halo Pad",        program:94), .init(name:"Warm Pad",        program:89),
                    .init(name:"Space Voice",      program:91), .init(name:"Swell",           program:95),
                    .init(name:"FX Atmosphere",    program:99), .init(name:"FX Echoes",       program:102)]
        case kTrackBass:
            if isAmbient {
                return [.init(name:"Cello",        program:42),  .init(name:"Contrabass",     program:43),
                        .init(name:"Moog Bass",    program:39),  .init(name:"Synth Bass 1",   program:38),
                        .init(name:"Fretless Bass",program:35)]
            }
            if isKosmic {
                return [.init(name:"Moog Bass",    program:39), .init(name:"Synth Bass 1",   program:38),
                        .init(name:"Fretless Bass", program:35)]
            }
            return [.init(name:"Moog Bass",       program:39), .init(name:"Lead Bass",      program:87),
                    .init(name:"Analog Bass",     program:38), .init(name:"Electric Bass",   program:33)]
        case kTrackDrums:
            if isAmbient {
                return [.init(name:"Brush Kit",    program:40)]
            }
            if isKosmic {
                return [.init(name:"Brush Kit",    program:40), .init(name:"808 Kit",      program:25),
                        .init(name:"Machine Kit",  program:24), .init(name:"Standard Kit", program:0)]
            }
            return [.init(name:"Rock Kit",       program:8),  .init(name:"808 Kit",         program:25),
                    .init(name:"Brush Kit",       program:40)]
        default:
            return [.init(name:"Synth",          program:0)]
        }
    }

    @State private var instrumentIndex: Int = 0
    @State private var activeEffects: Set<String> = []
    // Snapshot of the style currently applied to this track's instruments + effects.
    // Only updated when defaultsResetToken fires (generate or Reset button) — NOT on live
    // selectedStyle changes — so switching the picker mid-song doesn't touch anything.
    @State private var activeStyle: MusicStyle = .kosmic

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {

            // Left + MIDI zone
            HStack(spacing: 0) {

                // Left controls panel
                VStack(alignment: .leading, spacing: 3) {

                    // Row 1: [icon] [label]  ···  [◀ Name ▶]
                    HStack(spacing: 5) {
                        Image(systemName: trackIcon)
                            .foregroundStyle(trackColor)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(width: 22)
                        Text(label)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Button { cycleInstrument(by: -1) } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)

                        Text(instruments[instrumentIndex].name)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .lineLimit(1)
                            .frame(width: 82, alignment: .center)

                        Button { cycleInstrument(by: 1) } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }

                    // Row 2: [M] [S] [⚡]
                    HStack(spacing: 4) {
                        Button("M") { appState.toggleMute(trackIndex) }
                            .buttonStyle(ToggleChipStyle(active: isMuted, activeColor: .blue))
                            .help("Mute")

                        Button("S") { appState.toggleSolo(trackIndex) }
                            .buttonStyle(ToggleChipStyle(active: isSolo, activeColor: .yellow))
                            .help("Solo")

                        Button {
                            instrumentIndex = Int.random(in: 0..<instruments.count)
                            appState.setProgram(instruments[instrumentIndex].program, forTrack: trackIndex)
                            appState.regenerateTrack(trackIndex)
                        } label: {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(IconChipStyle())
                        .disabled(appState.isGenerating || appState.songState == nil)
                        .help("Regenerate \(label)")
                    }
                }
                .frame(width: 232)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)

                // MIDI lane
                MIDILaneView(
                    events: events,
                    totalBars: max(totalBars, 1),
                    isDrumTrack: trackIndex == kTrackDrums,
                    trackColor: trackColor,
                    visibleBars: visibleBars,
                    barOffset: barOffset,
                    onSeek: onSeek,
                    showPlayheadHandle: showPlayheadHandle
                )
                .frame(height: 63)
                .opacity(isEffectivelyMuted ? 0.22 : (isMuted ? 0.35 : 1.0))
            }
            // Right effects column
            HStack(spacing: 4) {
                ForEach(trackEffects, id: \.self) { fx in
                    let isOn = activeEffects.contains(fx.rawValue)
                    Button {
                        let nowOn = !isOn
                        if nowOn { activeEffects.insert(fx.rawValue) }
                        else     { activeEffects.remove(fx.rawValue) }
                        appState.setEffect(fx, enabled: nowOn, forTrack: trackIndex)
                    } label: {
                        effectChip(fx, active: isOn)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 152)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 6)
        }
        .frame(height: 63)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(white: 0.28))
                .frame(height: 1)
        }
        .onAppear {
            activeStyle = appState.selectedStyle
            applyDefaultEffects()
        }
        .onChange(of: appState.defaultsResetToken) { _ in
            activeStyle = appState.selectedStyle  // snapshot style at reset/generate time
            let override = appState.instrumentOverrides[trackIndex]
            instrumentIndex = override.map { min($0, instruments.count - 1) } ?? 0
            appState.setProgram(instruments[instrumentIndex].program, forTrack: trackIndex)
            applyDefaultEffects()
        }
    }

    // MARK: - Helpers

    // Per-track effect subset — exactly 3 per track (style-specific)
    private var trackEffects: [TrackEffect] {
        let isKosmic  = activeStyle == .kosmic || activeStyle == .ambient
        let isAmbient = activeStyle == .ambient
        switch trackIndex {
        case kTrackLead1:   return isKosmic  ? [.boost, .delay, .space]  : [.boost, .delay, .tremolo]
        case kTrackLead2:   return isKosmic  ? [.boost, .delay, .space]  : [.boost, .delay, .reverb]
        case kTrackPads:               return [.sweep, .delay, .space]
        case kTrackTexture:
            if isAmbient { return [.pan, .sweep, .space] }
            return isKosmic ? [.pan, .delay, .space] : [.pan, .delay, .reverb]
        case kTrackBass:               return [.lowShelf, .delay, .reverb]
        case kTrackDrums:              return [.compression, .delay, .reverb]
        default:                       return [.boost, .delay, .reverb]  // Rhythm
        }
    }

    private func cycleInstrument(by delta: Int) {
        instrumentIndex = (instrumentIndex + delta + instruments.count) % instruments.count
        appState.setProgram(instruments[instrumentIndex].program, forTrack: trackIndex)
    }

    private static let effectActiveColor = Color(red: 0.18, green: 0.42, blue: 0.78) // dark blue

    private func effectChip(_ fx: TrackEffect, active: Bool) -> some View {
        Text(fx.rawValue)
            .font(.system(size: 10, weight: active ? .bold : .medium))
            .frame(width: 44, height: 20)
            .background(active ? Self.effectActiveColor : Color(white: 0.28))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(active ? Self.effectActiveColor.opacity(0.7) : Color(white: 0.36), lineWidth: 1)
            )
    }

    private func applyDefaultEffects() {
        // Clear all active effects first (handles style switches cleanly)
        for fx in TrackEffect.allCases where activeEffects.contains(fx.rawValue) {
            activeEffects.remove(fx.rawValue)
            appState.setEffect(fx, enabled: false, forTrack: trackIndex)
        }

        let defaults: [TrackEffect]
        if activeStyle == .ambient {
            // Plan 14.3: deep reverb on everything; selective delay; no boost/comp/lowShelf
            defaults = switch trackIndex {
            case kTrackLead1:   [.delay, .space]   // dotted-half delay, cathedral 82%
            case kTrackLead2:   [.delay, .space]   // dotted-quarter delay, cathedral 78%
            case kTrackPads:    [.space, .sweep]    // delay causes beating; cathedral 88% + slow sweep
            case kTrackRhythm:  [.delay, .reverb]  // distant bell; large chamber 65%
            case kTrackTexture: [.space, .sweep]   // delay = mush; cathedral 90% + sweep
            case kTrackBass:    [.reverb]           // large chamber 62%; no delay (smears root)
            case kTrackDrums:   [.delay, .reverb]  // plate 70%; 1-beat delay for texture
            default:            []
            }
        } else if activeStyle == .kosmic {
            defaults = switch trackIndex {
            case kTrackLead1:    [.delay, .space]
            case kTrackLead2:    [.space]
            case kTrackPads:     [.space, .delay]
            case kTrackTexture:  [.delay, .space]
            case kTrackBass:     [.reverb]
            case kTrackRhythm:   [.delay]
            default:             []
            }
        } else {
            // Motorik defaults (unchanged from original)
            defaults = switch trackIndex {
            case kTrackLead1:    [.delay]
            case kTrackRhythm:   [.delay]
            case kTrackPads:     [.space]
            case kTrackTexture:  [.pan]
            default:             []
            }
        }

        for fx in defaults {
            activeEffects.insert(fx.rawValue)
            appState.setEffect(fx, enabled: true, forTrack: trackIndex)
        }
    }

    private var trackIcon: String {
        switch trackIndex {
        case kTrackLead1:   return "music.note"
        case kTrackLead2:   return "music.note.list"
        case kTrackPads:    return "pianokeys"
        case kTrackRhythm:  return "music.quarternote.3"
        case kTrackTexture: return "waveform"
        case kTrackBass:    return "waveform.path.ecg"
        case kTrackDrums:   return "metronome.fill"
        default:            return "music.note"
        }
    }

    private var trackColor: Color {
        switch trackIndex {
        case kTrackLead1, kTrackLead2:                return .red
        case kTrackPads, kTrackRhythm, kTrackTexture: return .blue
        case kTrackBass:                              return .purple
        case kTrackDrums:                             return .yellow
        default:                                      return .gray
        }
    }
}

// MARK: - Button styles

/// Toggle button (M mute, S solo) — filled color when active
struct ToggleChipStyle: ButtonStyle {
    let active: Bool
    let activeColor: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .frame(width: 22, height: 18)
            .background(active ? activeColor : Color(white: configuration.isPressed ? 0.45 : 0.30))
            .foregroundStyle(active ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
    }
}

/// Icon chip (⚡) — same size as M/S, press feedback via flash
struct IconChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .frame(width: 22, height: 18)
            .background(configuration.isPressed ? Color.yellow.opacity(0.40) : Color(white: 0.30))
            .foregroundStyle(.yellow)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
    }
}
