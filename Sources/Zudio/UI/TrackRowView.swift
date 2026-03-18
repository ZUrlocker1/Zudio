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
            return [.init(name:"Synth Brass",      program:63), .init(name:"Synth Brass 2",  program:62),
                    .init(name:"Sawtooth Lead",    program:81), .init(name:"Fifths Lead",    program:86),
                    .init(name:"Moog Lead",        program:39), .init(name:"Overdrive Gtr",  program:29),
                    .init(name:"Flute",            program:82), .init(name:"Ocarina",        program:79)]
        case kTrackLead2:
            return [.init(name:"Square Lead",    program:80), .init(name:"Brightness",      program:100),
                    .init(name:"Vibraphone",      program:11), .init(name:"Marimba",         program:12),
                    .init(name:"Bell/Pluck",      program:14), .init(name:"Soft Brass",      program:56)]
        case kTrackPads:
            return [.init(name:"Warm Pad",       program:89), .init(name:"Halo Pad",        program:94),
                    .init(name:"New Age Pad",     program:88), .init(name:"Sweep Pad",       program:95),
                    .init(name:"Bowed Glass",     program:92), .init(name:"Synth Strings",   program:50),
                    .init(name:"String Pad",      program:48), .init(name:"Organ Drone",     program:16)]
        case kTrackRhythm:
            return [.init(name:"Guitar Pulse",     program:28), .init(name:"Wurlitzer",         program:5),
                    .init(name:"Rock Organ",        program:18), .init(name:"Tremolo Strings",   program:44),
                    .init(name:"Pizzicato Strings", program:45), .init(name:"Mono Synth",        program:80)]
        case kTrackTexture:
            return [.init(name:"Swell",          program:95), .init(name:"Tape Texture",    program:93),
                    .init(name:"Slow Strings",    program:49), .init(name:"Space Voice",     program:91),
                    .init(name:"FX Soundtrack",   program:97), .init(name:"Field Noise",     program:119)]
        case kTrackBass:
            return [.init(name:"Moog Bass",       program:39), .init(name:"Lead Bass",      program:87),
                    .init(name:"Analog Bass",     program:38), .init(name:"Electric Bass",   program:33)]
        case kTrackDrums:
            return [.init(name:"Rock Kit",       program:8),  .init(name:"808 Kit",         program:25),
                    .init(name:"Brush Kit",       program:40),
                    .init(name:"Rock Kit",        program:8)]
        default:
            return [.init(name:"Synth",          program:0)]
        }
    }

    @State private var instrumentIndex: Int = 0
    @State private var activeEffects: Set<String> = []

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
            .opacity(isEffectivelyMuted ? 0.22 : (isMuted ? 0.35 : 1.0))

            // Right effects column
            HStack(spacing: 4) {
                ForEach(trackEffects, id: \.self) { name in
                    Button { activeEffects.formSymmetricDifference([name]) } label: {
                        effectChip(name, active: activeEffects.contains(name))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 110)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .opacity(0.75)
        }
        .background(trackColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }

    // MARK: - Helpers

    private var trackEffects: [String] {
        switch trackIndex {
        case kTrackLead1, kTrackLead2:          return ["Fuzz",   "Echo", "Delay"]
        case kTrackPads, kTrackRhythm,
             kTrackTexture:                     return ["Space",  "Echo", "Delay"]
        case kTrackBass:                        return ["Punch",  "Echo", "Delay"]
        case kTrackDrums:                       return ["Reverb", "Echo", "Delay"]
        default:                                return ["Space",  "Echo", "Delay"]
        }
    }

    private func cycleInstrument(by delta: Int) {
        instrumentIndex = (instrumentIndex + delta + instruments.count) % instruments.count
        appState.setProgram(instruments[instrumentIndex].program, forTrack: trackIndex)
    }

    private func effectChip(_ name: String, active: Bool) -> some View {
        Text(name)
            .font(.system(size: 9, weight: active ? .semibold : .regular))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(active ? Color(white: 0.45) : Color(white: 0.22))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(active ? Color.white : Color(white: 0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(active ? Color(white: 0.65) : Color.clear, lineWidth: 1)
            )
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
