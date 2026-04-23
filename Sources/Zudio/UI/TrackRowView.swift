// TrackRowView.swift — track controls + MIDI lane + effects column
// Copyright (c) 2026 Zack Urlocker
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
    var contentWidth: CGFloat = 900

    // Adaptive panel widths (iOS only).
    //
    // iPad mini portrait (744pt):
    //   left=220  right=232 (explicit, leading-aligned)  MIDI=728−232−244=252pt
    //   rightPanelWidth=232 → frame is 232+2×6=244pt. Chips (140pt) left-aligned
    //   within the 232pt frame: 6pt gap from MIDI, dead space on right edge only.
    //   MIDI = 252pt (31% narrower than natural 344pt) — narrowed 6pt per request.
    //
    // iPad 11" / Air / standard portrait (820–834pt):
    //   left=222  right≈174 (natural 140+2×17)  MIDI≈398pt  (6pt narrower per request)
    //
    // Landscape (any iPad) / macOS:
    //   left=232  right=152
    #if os(iOS)
    private var leftPanelWidth: CGFloat {
        if contentWidth < 800 { return 220 }           // iPad mini portrait (744pt)
        if contentWidth < 900 { return 222 }           // iPad 11" / Air portrait (820–834pt)
        if contentWidth < 1150 { return 242 }          // iPad mini landscape (1133pt) — wider for Lead 1
        return 232                                     // iPad Pro landscape + macOS
    }
    // iPad mini portrait: explicit frame so the effects panel claims a fixed 232pt,
    // narrowing MIDI to 252pt (31% less than the 344pt natural-sizing result).
    // Nil for other sizes → natural chip sizing used instead.
    private var rightPanelWidth: CGFloat? {
        if contentWidth < 800 { return 232 }
        return nil
    }
    // Padding between MIDI lane and chips (leading) / chips and right edge (trailing).
    // iPad A16/11"/Air portrait (800–900pt): 9pt leading removes dead space, 17pt trailing
    // keeps chips away from the right screen edge.
    private var rightEffectsLeadingPadding: CGFloat {
        if contentWidth >= 800 && contentWidth < 900 { return 9 }
        return 6
    }
    private var rightEffectsTrailingPadding: CGFloat {
        if contentWidth >= 800 && contentWidth < 900 { return 17 }
        return 6
    }
    #endif

    // MARK: - Instrument definitions (no "Auto" — always show real name)

    private struct Instrument { let name: String; let program: UInt8 }

    private var instruments: [Instrument] {
        let isKosmic  = activeStyle == .kosmic
        let isAmbient = activeStyle == .ambient
        let isChill   = activeStyle == .chill
        switch trackIndex {
        case kTrackLead1:
            if isChill {
                return [.init(name:"Muted Trumpet", program:59),  .init(name:"Tenor Sax",     program:66),
                        .init(name:"Alto Sax",       program:65),  .init(name:"Trumpet",       program:56)]
            }
            if isAmbient {
                return [.init(name:"Flute",         program:73),  .init(name:"Ocarina",       program:79),
                        .init(name:"Pan Flute",     program:75),  .init(name:"Whistle",       program:78),
                        .init(name:"Recorder",      program:74),  .init(name:"Brightness",    program:100),
                        .init(name:"Calliope Lead", program:82)]
            }
            if isKosmic {
                return [.init(name:"Flute",        program:73),  .init(name:"Brightness",     program:100),
                        .init(name:"Oboe",         program:68),  .init(name:"Recorder",       program:74)]
            }
            return [.init(name:"Mono Synth",       program:81), .init(name:"Soft Brass",      program:62),
                    .init(name:"Pad 3 Poly",       program:90), .init(name:"Chiff Lead",       program:83)]
        case kTrackLead2:
            if isChill {
                return [.init(name:"Vibraphone",   program:11),  .init(name:"Flute",          program:73),
                        .init(name:"Soprano Sax",  program:64),  .init(name:"Trombone",       program:57),
                        .init(name:"Xylophone",    program:13)]
            }
            if isAmbient {
                return [.init(name:"Harp",           program:46),  .init(name:"Grand Piano",   program:0),
                        .init(name:"Acoustic Guitar",program:24), .init(name:"FX Crystal",     program:98),
                        .init(name:"Space Voice",  program:91),  .init(name:"FX Atmosphere",  program:99)]
            }
            if isKosmic {
                return [.init(name:"Brightness",  program:100), .init(name:"Bassoon",    program:70),
                        .init(name:"Charang",     program:84),  .init(name:"Vox Solo",   program:85)]
            }
            return [.init(name:"Polysynth",   program:90),  .init(name:"Brightness",  program:100),
                    .init(name:"Minimoog",    program:39),  .init(name:"Elec Guitar", program:30)]
        case kTrackPads:
            if isAmbient {
                return [.init(name:"Sweep Pad",    program:95), .init(name:"Synth Strings",program:50),
                        .init(name:"Halo Pad",     program:94), .init(name:"New Age Pad",  program:88)]
            }
            if isKosmic {
                return [.init(name:"Sweep Pad",    program:95), .init(name:"Synth Strings", program:50),
                        .init(name:"Warm Pad",     program:89), .init(name:"Space Voice",   program:91)]
            }
            if isChill {
                return [.init(name:"Warm Pad",     program:89), .init(name:"Synth Strings", program:50),
                        .init(name:"String Pad",   program:48), .init(name:"Sweep Pad",     program:95)]
            }
            return [.init(name:"Halo Pad",        program:94), .init(name:"Sweep Pad",       program:95),
                    .init(name:"Bowed Glass",     program:92), .init(name:"Synth Strings",   program:50)]
        case kTrackRhythm:
            if isChill {
                return [.init(name:"Rhodes",       program:4),  .init(name:"Wurlitzer",   program:5),
                        .init(name:"B3 Organ",    program:17)]
            }
            if isAmbient {
                return [.init(name:"Glockenspiel",  program:9),   .init(name:"Steel Drums",   program:114),
                        .init(name:"Marimba",       program:12),  .init(name:"Tubular Bells", program:14)]
            }
            if isKosmic {
                return [.init(name:"Moog Lead",    program:39), .init(name:"Wurlitzer",   program:5),
                        .init(name:"Rock Organ",   program:18)]
            }
            return [.init(name:"Guitar Pulse",  program:28), .init(name:"Moog Lead",   program:39),
                    .init(name:"Fuzz Guitar",   program:29)]
        case kTrackTexture:
            if isChill {
                // Pseudo-programs 240–250 map to audio texture files (intercepted in AppState.setProgram).
                return [.init(name:"None",           program:240),
                        .init(name:"Another bar",    program:241),
                        .init(name:"Bar sounds",     program:242),
                        .init(name:"City at night",  program:243),
                        .init(name:"Harbor",         program:245),
                        .init(name:"Light rain",     program:246),
                        .init(name:"Ocean waves",    program:247),
                        .init(name:"Urban rain",     program:248),
                        .init(name:"Vinyl crackle",  program:250)]
            }
            if isAmbient {
                return [.init(name:"Strings",       program:49), .init(name:"Bowed Glass",    program:92),
                        .init(name:"Choir Aahs",    program:52), .init(name:"FX Atmosphere",  program:99),
                        .init(name:"Pad 3 Poly",    program:90)]
            }
            if isKosmic {
                return [.init(name:"FX Atmosphere", program:99), .init(name:"Pad 3 Poly",    program:90),
                        .init(name:"Fifths Lead",    program:86)]
            }
            return [.init(name:"Fifths Lead",   program:86), .init(name:"Halo Pad",      program:94),
                    .init(name:"Warm Pad",      program:89), .init(name:"FX Atmosphere", program:99),
                    .init(name:"FX Echoes",     program:102)]
        case kTrackBass:
            if isChill {
                return [.init(name:"Fretless Bass",  program:35), .init(name:"Acoustic Bass",  program:32),
                        .init(name:"Elec Bass",      program:33)]
            }
            if isAmbient {
                return [.init(name:"Cello",        program:42),  .init(name:"French Horn",    program:60),
                        .init(name:"Contrabass",   program:43),  .init(name:"Voice Oohs",     program:54),
                        .init(name:"English Horn", program:69)]
            }
            if isKosmic {
                return [.init(name:"Moog Bass",    program:39), .init(name:"Fretless Bass",  program:35),
                        .init(name:"Lead Bass",    program:87), .init(name:"Mono Synth",     program:81)]
            }
            return [.init(name:"Moog Bass",   program:39), .init(name:"Lead Bass",  program:87),
                    .init(name:"Rock Bass",   program:34), .init(name:"Elec Bass",  program:33)]
        case kTrackDrums:
            if isChill {
                return [.init(name:"Brush Kit",    program:40), .init(name:"808 Kit",       program:25),
                        .init(name:"Standard Kit", program:0)]
            }
            if isAmbient {
                return [.init(name:"Percussion Kit", program:0),
                        .init(name:"Brush Kit",      program:40)]
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
                #if os(iOS)
                .frame(width: leftPanelWidth)
                #else
                .frame(width: 232)
                #endif
                .padding(.horizontal, 6)
                .padding(.vertical, 3)

                // MIDI lane (or audio waveform for Chill Texture track)
                if trackIndex == kTrackTexture && activeStyle == .chill {
                    AudioWaveformView(
                        filename: appState.songState?.chillAudioTexture,
                        totalBars: max(totalBars, 1),
                        tempo: Double(appState.songState?.frame.tempo ?? 92),
                        visibleBars: visibleBars,
                        barOffset: barOffset,
                        offsetSeconds: appState.songState?.chillAudioTextureOffset ?? 0,
                        onSeek: onSeek
                    )
                    .frame(height: 63)
                    .opacity(isEffectivelyMuted ? 0.22 : (isMuted ? 0.35 : 1.0))
                } else {
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
            }
            // Right effects column — layout varies by platform and size class
            effectsColumn
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
        .onChange(of: appState.instrumentChangeToken) { _ in
            // Evolve pass switched instruments — update display to match (audio already changed)
            let override = appState.instrumentOverrides[trackIndex]
            let newIdx = override.map { min($0, instruments.count - 1) } ?? 0
            if newIdx != instrumentIndex { instrumentIndex = newIdx }
        }
    }

    // MARK: - Helpers

    // Right effects column.
    // Three layout strategies:
    //   macOS           : .frame(width:152) — explicit, chips centered with 6pt each side
    //   iOS mini (<800) : .frame(width:232, alignment:.leading) — chips sit at leading
    //                     edge; dead space on right only; MIDI=252pt (31% narrower)
    //   iOS other       : natural chip width (140pt) + asymmetric leading/trailing — no frame
    @ViewBuilder private var effectsColumn: some View {
        #if os(macOS)
        HStack(spacing: 4) { chipButtons }
            .frame(width: 152)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 6)
        #else
        if let w = rightPanelWidth {
            // iPad mini portrait: explicit frame keeps panel at full width so MIDI
            // yields 25% of its space. Leading alignment puts chips flush left.
            HStack(spacing: 4) { chipButtons }
                .frame(width: w, alignment: .leading)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 6)
        } else {
            // iPad 11" / Air portrait + landscape: natural chip sizing.
            // Asymmetric padding trims dead space between MIDI and chips (leading)
            // while keeping a comfortable gap from the right screen edge (trailing).
            HStack(spacing: 4) { chipButtons }
                .frame(maxHeight: .infinity)
                .padding(.leading, rightEffectsLeadingPadding)
                .padding(.trailing, rightEffectsTrailingPadding)
        }
        #endif
    }

    // Chip buttons extracted so effectsColumn can reference them in multiple branches.
    @ViewBuilder private var chipButtons: some View {
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

    // Per-track effect subset — exactly 3 per track (style-specific)
    private var trackEffects: [TrackEffect] {
        let isKosmic  = activeStyle == .kosmic || activeStyle == .ambient
        let isAmbient = activeStyle == .ambient
        let isChill   = activeStyle == .chill
        switch trackIndex {
        case kTrackLead1:
            if isChill   { return [.space, .delay, .compression] }
            if isAmbient { return [.sweep, .delay, .space] }
            return isKosmic ? [.boost, .delay, .space] : [.boost, .delay, .tremolo]
        case kTrackLead2:
            if isChill   { return [.space, .delay, .compression] }
            if isAmbient { return [.tremolo, .delay, .space] }
            return isKosmic ? [.boost, .delay, .space] : [.boost, .delay, .reverb]
        case kTrackPads:
            if isChill   { return [.space, .sweep, .boost] }
            return isAmbient ? [.sweep, .tremolo, .space] : [.sweep, .delay, .space]
        case kTrackRhythm:
            if isChill   { return [.tremolo, .space, .compression] }
            return [.boost, .delay, .reverb]
        case kTrackTexture:
            if isChill   { return [.boost, .lowShelf, .reverb] }
            if isAmbient { return [.pan, .sweep, .space] }
            return isKosmic ? [.pan, .delay, .space] : [.pan, .delay, .reverb]
        case kTrackBass:
            if isChill   { return [.lowShelf, .compression, .reverb] }
            if isAmbient { return [.sweep, .delay, .reverb] }
            return [.lowShelf, .delay, .reverb]
        case kTrackDrums:
            if isChill   { return [.compression, .space, .lowShelf] }
            return [.sweep, .delay, .reverb]
        default:                       return [.boost, .delay, .reverb]  // Rhythm
        }
    }

    private func cycleInstrument(by delta: Int) {
        instrumentIndex = (instrumentIndex + delta + instruments.count) % instruments.count
        appState.setProgram(instruments[instrumentIndex].program, forTrack: trackIndex)
        // Ambient drum kit change: remap note numbers (shaker↔maracas, claves↔triangle)
        if trackIndex == kTrackDrums && appState.selectedStyle == .ambient {
            appState.remapAmbientDrumNotes(instrumentIndex: instrumentIndex)
        }
        appState.logInstrumentChange(trackIndex: trackIndex, name: instruments[instrumentIndex].name)
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
            defaults = switch trackIndex {
            case kTrackLead1:   [.delay, .space]
            case kTrackLead2:   [.space]
            case kTrackPads:    [.space, .sweep]
            case kTrackRhythm:  [.reverb]
            case kTrackTexture: [.space, .pan, .sweep]
            case kTrackBass:    [.reverb, .sweep]
            case kTrackDrums:   [.delay]
            default:            []
            }
        } else if activeStyle == .chill {
            defaults = switch trackIndex {
            case kTrackLead1:   [.space, .delay]
            case kTrackLead2:   [.space, .delay]
            case kTrackRhythm:  [.space]
            case kTrackPads:    [.sweep, .tremolo]
            case kTrackTexture: [.lowShelf, .reverb]
            case kTrackBass:    [.reverb]
            case kTrackDrums:   [.space]
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
