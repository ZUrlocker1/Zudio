// TrackRowView.swift — one horizontal track row: controls + MIDI lane + effects (disabled)

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

    var body: some View {
        HStack(spacing: 0) {
            // Left controls panel (fixed width)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(isMuted ? .secondary : .primary)

                HStack(spacing: 4) {
                    // Mute
                    Button(isMuted ? "M" : "M") {
                        appState.toggleMute(trackIndex)
                    }
                    .buttonStyle(.bordered)
                    .tint(isMuted ? .orange : .secondary)
                    .font(.caption2)

                    // Solo
                    Button("S") {
                        appState.toggleSolo(trackIndex)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSolo ? .yellow : .secondary)
                    .font(.caption2)

                    // Regenerate
                    Button(action: { appState.regenerateTrack(trackIndex) }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    .disabled(appState.isGenerating || appState.songState == nil)
                }
            }
            .frame(width: 110)
            .padding(.horizontal, 8)

            // MIDI lane
            MIDILaneView(
                events: events,
                totalBars: totalBars,
                currentStep: currentStep,
                isDrumTrack: trackIndex == kTrackDrums
            )
            .frame(height: 54)
            .opacity(isMuted ? 0.35 : 1.0)

            // Effects controls (disabled placeholder in v1)
            VStack(spacing: 4) {
                ForEach(["Rev", "Dly", "Chs"], id: \.self) { fx in
                    HStack(spacing: 2) {
                        Text(fx).font(.caption2).foregroundStyle(.secondary)
                        Slider(value: .constant(0.3)).disabled(true).frame(width: 60)
                    }
                }
            }
            .frame(width: 120)
            .padding(.horizontal, 8)
            .opacity(0.35) // visually disabled
        }
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 8)
    }
}
