// TrackRowView.swift — track controls + MIDI lane + effects column
// Track colors: Lead 1/2 = red, Pads/Rhythm/Texture = blue, Bass = purple, Drums = yellow

import SwiftUI

struct TrackRowView: View {
    @EnvironmentObject var appState: AppState

    let trackIndex: Int
    let label: String
    let events: [MIDIEvent]
    let totalBars: Int
    let currentStep: Int
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
        switch trackIndex {
        case kTrackLead1:
            return [.init(name:"Synth Lead",     program:82), .init(name:"Electric Lead", program:26),
                    .init(name:"Brass Lead",      program:56), .init(name:"Piano",         program:0),
                    .init(name:"Rhodes",          program:4)]
        case kTrackLead2:
            return [.init(name:"Square Lead",    program:80), .init(name:"Guitar Counter", program:24),
                    .init(name:"Bell/Pluck",      program:14), .init(name:"Soft Brass",     program:56),
                    .init(name:"Synth Brass",     program:63)]
        case kTrackPads:
            return [.init(name:"Warm Pad",       program:89), .init(name:"Glass Pad",      program:98),
                    .init(name:"String Pad",      program:48), .init(name:"Choir Pad",      program:53),
                    .init(name:"Organ Drone",     program:16)]
        case kTrackRhythm:
            return [.init(name:"Guitar Pulse",   program:28), .init(name:"Mono Synth",     program:80),
                    .init(name:"Arp Synth",       program:37), .init(name:"E-Piano",         program:4)]
        case kTrackTexture:
            return [.init(name:"Noise/Swell",    program:95), .init(name:"Field Noise",    program:119),
                    .init(name:"Metallic FX",     program:98), .init(name:"Tape Texture",   program:93)]
        case kTrackBass:
            return [.init(name:"Analog Bass",    program:38), .init(name:"FM Bass",         program:37),
                    .init(name:"Electric Bass",   program:33), .init(name:"Upright Bass",   program:32)]
        case kTrackDrums:
            return [.init(name:"Electronic Kit", program:0),  .init(name:"Rock Kit",        program:8)]
        default:
            return [.init(name:"Synth",          program:0)]
        }
    }

    @State private var instrumentIndex: Int = 0

    // MARK: - Body

    var body: some View {
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
                        .foregroundStyle(isMuted ? .tertiary : .primary)
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

                    Button { appState.regenerateTrack(trackIndex) } label: {
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
                currentStep: currentStep,
                isDrumTrack: trackIndex == kTrackDrums,
                trackColor: trackColor,
                visibleBars: visibleBars,
                barOffset: barOffset,
                onSeek: onSeek,
                showPlayheadHandle: showPlayheadHandle
            )
            .frame(height: 63)
            .opacity(isMuted ? 0.35 : 1.0)

            // Right effects column
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(["Dry", "Wide", "Hazy", "Punchy"], id: \.self) { effectChip($0) }
                }
                HStack(spacing: 2) {
                    ForEach(["Space", "Echo", "Width", "Grit", "Tone"], id: \.self) { effectChip($0) }
                }
            }
            .frame(width: 136)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .opacity(0.75)
        }
        .background(trackColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .opacity(isEffectivelyMuted ? 0.22 : 1.0)
    }

    // MARK: - Helpers

    private func cycleInstrument(by delta: Int) {
        instrumentIndex = (instrumentIndex + delta + instruments.count) % instruments.count
        appState.setProgram(instruments[instrumentIndex].program, forTrack: trackIndex)
    }

    private func effectChip(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 9))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(.secondary)
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
