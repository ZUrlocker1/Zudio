// MIDILaneView.swift — horizontal MIDI note visualisation + playback scroll indicator

import SwiftUI

struct MIDILaneView: View {
    let events: [MIDIEvent]
    let totalBars: Int
    let currentStep: Int
    let isDrumTrack: Bool

    // Layout
    private let noteHeight: CGFloat = 3
    private let minNote: Int = 21   // A0
    private let maxNote: Int = 108  // C8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Background grid (bar lines)
                barLines(width: geo.size.width, height: geo.size.height)

                // MIDI notes
                ForEach(Array(events.enumerated()), id: \.offset) { _, ev in
                    noteRect(ev: ev, width: geo.size.width, height: geo.size.height)
                }

                // Playhead
                playhead(width: geo.size.width, height: geo.size.height)
            }
            .clipped()
        }
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Subviews

    @ViewBuilder
    private func barLines(width: CGFloat, height: CGFloat) -> some View {
        let totalSteps = totalBars * 16
        ForEach(0..<totalBars, id: \.self) { bar in
            let x = CGFloat(bar * 16) / CGFloat(totalSteps) * width
            Rectangle()
                .fill(Color.white.opacity(bar % 4 == 0 ? 0.15 : 0.05))
                .frame(width: 1, height: height)
                .offset(x: x)
        }
    }

    @ViewBuilder
    private func noteRect(ev: MIDIEvent, width: CGFloat, height: CGFloat) -> some View {
        let totalSteps = totalBars * 16
        let x = CGFloat(ev.stepIndex) / CGFloat(totalSteps) * width
        let w = max(2, CGFloat(ev.durationSteps) / CGFloat(totalSteps) * width)
        let y = isDrumTrack
            ? height * 0.5
            : (1.0 - CGFloat(Int(ev.note) - minNote) / CGFloat(maxNote - minNote)) * (height - noteHeight)

        Rectangle()
            .fill(noteColor(for: Int(ev.note)))
            .frame(width: w, height: noteHeight)
            .offset(x: x, y: y)
    }

    @ViewBuilder
    private func playhead(width: CGFloat, height: CGFloat) -> some View {
        let totalSteps = totalBars * 16
        let x = CGFloat(currentStep) / CGFloat(max(1, totalSteps)) * width
        Rectangle()
            .fill(Color.white.opacity(0.85))
            .frame(width: 1.5, height: height)
            .offset(x: x)
    }

    // MARK: - Helpers

    private func noteColor(for note: Int) -> Color {
        // Color by octave
        let oct = note / 12
        let hue = Double(oct % 6) / 6.0
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }
}
