// MIDILaneView.swift — Canvas-based piano-roll with DAW visible window + drag-to-seek.
// Drag anywhere in the lane to reposition the playhead.

import SwiftUI

struct MIDILaneView: View {
    let events: [MIDIEvent]
    let totalBars: Int
    let currentStep: Int
    let isDrumTrack: Bool
    var trackColor: Color = .white
    var visibleBars: Int = 16
    var barOffset: Int = 0
    var onSeek: ((Int) -> Void)? = nil   // called with absolute step index
    var showPlayheadHandle: Bool = false // only top lane draws the ▼ drag handle

    private let noteH: CGFloat = 7

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                drawLane(ctx: ctx, size: size)
            }

            // Drag-to-seek overlay — invisible, covers full lane
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = max(0, min(1.0, value.location.x / geo.size.width))
                                let clampedVisible = max(1, min(visibleBars, totalBars))
                                let startStep = barOffset * 16
                                let visibleSteps = clampedVisible * 16
                                let step = startStep + Int(fraction * Double(visibleSteps))
                                onSeek?(step)
                            }
                    )
            }
        }
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Main draw

    private func drawLane(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        let clampedVisible = max(1, min(visibleBars, totalBars))
        let clampedOffset  = max(0, min(barOffset, totalBars - clampedVisible))
        let visibleSteps   = clampedVisible * 16
        let startStep      = clampedOffset * 16

        // Bar lines — only within visible window
        for bar in 0..<clampedVisible {
            let absoluteBar = bar + clampedOffset
            let x = CGFloat(bar) / CGFloat(clampedVisible) * w
            let alpha: Double = absoluteBar % 4 == 0 ? 0.14 : 0.05
            ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: h)),
                     with: .color(.white.opacity(alpha)))
        }

        // Drum lane separators
        if isDrumTrack {
            for norm in drumLaneNorms {
                let y = norm * (h - noteH)
                ctx.fill(Path(CGRect(x: 0, y: y + noteH, width: w, height: 1)),
                         with: .color(.white.opacity(0.07)))
            }
        }

        // Notes — only those overlapping visible window
        let (lo, hi) = pitchRange
        for ev in events {
            let evEnd = ev.stepIndex + ev.durationSteps
            guard evEnd > startStep && ev.stepIndex < startStep + visibleSteps else { continue }

            let clampedStart = max(ev.stepIndex, startStep)
            let clampedEnd   = min(evEnd, startStep + visibleSteps)
            let x   = CGFloat(clampedStart - startStep) / CGFloat(visibleSteps) * w
            let nw  = max(2, CGFloat(clampedEnd - clampedStart) / CGFloat(visibleSteps) * w - 1.5)
            let y   = rawNoteY(note: Int(ev.note), lo: lo, hi: hi, height: h)
            let col = noteColor(for: Int(ev.note))
            ctx.fill(Path(CGRect(x: x, y: max(0, min(h - noteH, y)), width: nw, height: noteH)),
                     with: .color(col))
        }

        // Playhead — only if in visible window
        if currentStep >= startStep && currentStep < startStep + visibleSteps {
            let px = CGFloat(currentStep - startStep) / CGFloat(visibleSteps) * w
            // Playhead line
            ctx.fill(Path(CGRect(x: px, y: 0, width: 2, height: h)),
                     with: .color(.white.opacity(0.9)))
            // Drag-handle triangle (▼) — only on the top lane
            if showPlayheadHandle {
                let cx = px + 1.0
                var tri = Path()
                tri.move(to: CGPoint(x: cx - 6, y: 0))
                tri.addLine(to: CGPoint(x: cx + 6, y: 0))
                tri.addLine(to: CGPoint(x: cx,     y: 10))
                tri.closeSubpath()
                ctx.fill(tri, with: .color(.white))
            }
        }
    }

    // MARK: - Y calculation

    private func rawNoteY(note: Int, lo: Int, hi: Int, height: CGFloat) -> CGFloat {
        if isDrumTrack { return drumY(for: note, height: height) }
        let span = CGFloat(max(1, hi - lo))
        return (1.0 - CGFloat(note - lo) / span) * (height - noteH)
    }

    private func drumY(for note: Int, height: CGFloat) -> CGFloat {
        let norms: [Int: CGFloat] = [
            49: 0.04, 57: 0.04,
            51: 0.15, 53: 0.15, 55: 0.15,
            46: 0.26,
            42: 0.36, 44: 0.36,
            48: 0.48, 50: 0.48,
            37: 0.58, 39: 0.58,
            38: 0.67, 40: 0.67,
            41: 0.77, 43: 0.77, 45: 0.77, 47: 0.77,
            35: 0.90, 36: 0.90
        ]
        return (norms[note] ?? 0.50) * (height - noteH)
    }

    private let drumLaneNorms: [CGFloat] = [0.04, 0.15, 0.26, 0.36, 0.48, 0.58, 0.67, 0.77, 0.90]

    private var pitchRange: (Int, Int) {
        let notes = events.map { Int($0.note) }
        guard !notes.isEmpty else { return (48, 84) }
        let lo = max(notes.min()! - 3, 0)
        let hi = min(notes.max()! + 3, 127)
        return hi - lo < 12 ? (lo, lo + 12) : (lo, hi)
    }

    // MARK: - Colors

    private func noteColor(for note: Int) -> Color {
        if isDrumTrack {
            switch note {
            case 35, 36:     return trackColor
            case 38, 40:     return trackColor.opacity(0.85)
            case 42, 44, 46: return trackColor.opacity(0.60)
            default:         return trackColor.opacity(0.75)
            }
        }
        let oct = min(max(note / 12, 0), 8)
        return trackColor.opacity(0.72 + Double(oct % 4) * 0.07)
    }
}
