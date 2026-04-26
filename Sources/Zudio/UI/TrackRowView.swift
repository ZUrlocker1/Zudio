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

    // MARK: - Instrument list — single source of truth is AppState pool definitions

    private struct Instrument { let name: String; let program: UInt8 }

    private var instruments: [Instrument] {
        // Ambient texture with audio active: picker shows audio file names (pseudo-programs 231–236)
        if trackIndex == kTrackTexture, activeStyle == .ambient,
           appState.songState?.ambientAudioTexture != nil {
            return [
                Instrument(name: "Light Rain",   program: 231),
                Instrument(name: "Rain & Thunder", program: 232),
                Instrument(name: "Ocean Waves",  program: 233),
                Instrument(name: "Zen Bells",    program: 234),
                Instrument(name: "Wind Storm",   program: 235),
                Instrument(name: "Desert Winds", program: 236),
            ]
        }
        let names    = AppState.instrumentPoolNames(trackIndex: trackIndex, style: activeStyle)
        let programs = AppState.instrumentPoolPrograms(trackIndex: trackIndex, style: activeStyle)
        return zip(names, programs).map { Instrument(name: $0, program: $1) }
    }

    @State private var instrumentIndex: Int = 0
    @State private var activeEffects: Set<String> = []

    /// Safe name for the current instrument picker position. Guards against the brief window
    /// where songState switches the instruments array (e.g. MIDI→audio texture) before
    /// instrumentChangeToken fires and clamps instrumentIndex to the new pool size.
    private var currentInstrumentName: String {
        guard !instruments.isEmpty else { return "—" }
        return instruments[min(instrumentIndex, instruments.count - 1)].name
    }

    private var isInstrumentLocked: Bool {
        trackIndex == kTrackLead2 && appState.lead2MirrorName != nil
    }
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
                        .foregroundStyle(isInstrumentLocked ? Color.secondary.opacity(0.35) : .secondary)
                        .disabled(isInstrumentLocked)

                        Text(trackIndex == kTrackLead2 ? (appState.lead2MirrorName ?? currentInstrumentName) : currentInstrumentName)
                            .font(.system(size: 11))
                            .foregroundStyle(isInstrumentLocked ? Color.white.opacity(0.35) : Color.white.opacity(0.8))
                            .lineLimit(1)
                            .frame(width: 82, alignment: .center)

                        Button { cycleInstrument(by: 1) } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(isInstrumentLocked ? Color.secondary.opacity(0.35) : .secondary)
                        .disabled(isInstrumentLocked)
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

                // MIDI lane (or audio waveform for Chill/Ambient Texture track when audio texture active)
                let ambientTextureFile = appState.songState?.ambientAudioTexture
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
                } else if trackIndex == kTrackTexture && activeStyle == .ambient && ambientTextureFile != nil {
                    AudioWaveformView(
                        filename: ambientTextureFile,
                        totalBars: max(totalBars, 1),
                        tempo: Double(appState.songState?.frame.tempo ?? 92),
                        visibleBars: visibleBars,
                        barOffset: barOffset,
                        offsetSeconds: appState.songState?.ambientAudioTextureOffset ?? 0,
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
            // Ambient texture regen may switch between audio and MIDI — re-apply effect defaults
            // so Pan/Sweep chips show the correct active state without a full song regeneration.
            if trackIndex == kTrackTexture && activeStyle == .ambient {
                applyDefaultEffects()
            }
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
            if isAmbient { return [.tremolo, .delay, .space] }   // delay chip visible whether locked or not
            return isKosmic ? [.boost, .delay, .space] : [.boost, .delay, .reverb]
        case kTrackPads:
            if isChill   { return [.space, .sweep, .boost] }
            return isAmbient ? [.sweep, .tremolo, .space] : [.sweep, .delay, .space]
        case kTrackRhythm:
            if isChill   { return [.tremolo, .space, .compression] }
            return [.boost, .delay, .reverb]
        case kTrackTexture:
            if isChill   { return [.boost, .lowShelf, .reverb] }
            if isAmbient {
                // Audio texture: only reverb chip (pan/sweep have no effect on the audio player)
                return [.pan, .sweep, .space]
            }
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

    // "Hall" is relabelled "Reverb" on the Ambient Texture track for clarity.
    private func effectChipLabel(_ fx: TrackEffect) -> String {
        if fx == .space && trackIndex == kTrackTexture && activeStyle == .ambient { return "Reverb" }
        return fx.rawValue
    }

    private func effectChip(_ fx: TrackEffect, active: Bool) -> some View {
        Text(effectChipLabel(fx))
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
            case kTrackLead2:   isInstrumentLocked ? [.delay, .space] : [.space]
            case kTrackPads:    [.space, .sweep]
            case kTrackRhythm:  [.reverb]
            case kTrackTexture: appState.songState?.ambientAudioTexture != nil ? [.space] : [.space, .pan, .sweep]
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
