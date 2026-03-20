// MIDILaneView.swift — Canvas-based piano-roll with DAW visible window + drag-to-seek.
// Drag anywhere in the lane to reposition the playhead.

import SwiftUI

struct MIDILaneView: View {
    @EnvironmentObject var playback: PlaybackEngine

    let events: [MIDIEvent]
    let totalBars: Int
    let isDrumTrack: Bool
    var trackColor: Color = .white
    var visibleBars: Int = 16
    var barOffset: Int = 0
    var onSeek: ((Int) -> Void)? = nil   // called with absolute step index
    var showPlayheadHandle: Bool = false // only top lane draws the ▼ drag handle

    private let noteH: CGFloat = 7

    // Cached per-events data: recomputed only when events change (song load / track regen),
    // not on every Canvas redraw (which fires on each playhead step tick).
    @State private var onsetsByNote: [UInt8: [Int]] = [:]
    @State private var cachedPitchRange: (Int, Int) = (48, 84)

    var body: some View {
        // Capture stable locals so the Canvas closure holds their current values
        // without going through @State property wrappers inside the draw call.
        let onsets    = onsetsByNote
        let pitchRng  = cachedPitchRange
        let curStep   = playback.currentStep

        ZStack {
            Canvas { ctx, size in
                drawLane(ctx: ctx, size: size, onsets: onsets,
                         pitchRange: pitchRng, currentStep: curStep)
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
        .onAppear { buildCache() }
        .onChange(of: events) { _, _ in buildCache() }
    }

    // MARK: - Cache

    private func buildCache() {
        var map: [UInt8: [Int]] = [:]
        for ev in events { map[ev.note, default: []].append(ev.stepIndex) }
        for key in map.keys { map[key]?.sort() }
        onsetsByNote = map

        let notes = events.map { Int($0.note) }
        if notes.isEmpty {
            cachedPitchRange = (48, 84)
        } else {
            let lo = max(notes.min()! - 3, 0)
            let hi = min(notes.max()! + 3, 127)
            cachedPitchRange = hi - lo < 12 ? (lo, lo + 12) : (lo, hi)
        }
    }

    // MARK: - Main draw

    private func drawLane(ctx: GraphicsContext, size: CGSize,
                          onsets: [UInt8: [Int]], pitchRange: (Int, Int), currentStep: Int) {
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
        // Scale note height so adjacent semitones always have a 1px vertical gap.
        // Without this, dense chords (e.g. 4-voice pad block) render as a solid rectangle.
        let semitoneCount = max(1, hi - lo)
        let pixelsPerSemitone = (h - noteH) / CGFloat(semitoneCount)
        let drawH = max(2, min(noteH, pixelsPerSemitone - 1))

        for ev in events {
            let rawEnd = ev.stepIndex + ev.durationSteps
            // Clip to next same-pitch onset so held notes never overdraw a later note
            let nextOnset = onsets[ev.note]?.first(where: { $0 > ev.stepIndex }) ?? rawEnd
            let evEnd = min(rawEnd, nextOnset)

            guard evEnd > startStep && ev.stepIndex < startStep + visibleSteps else { continue }

            let clampedStart = max(ev.stepIndex, startStep)
            let clampedEnd   = min(evEnd, startStep + visibleSteps)
            let x   = CGFloat(clampedStart - startStep) / CGFloat(visibleSteps) * w
            let nw  = max(2, CGFloat(clampedEnd - clampedStart) / CGFloat(visibleSteps) * w - 2)
            let y   = rawNoteY(note: Int(ev.note), lo: lo, hi: hi, height: h)
            let col = noteColor(for: Int(ev.note))
            ctx.fill(Path(CGRect(x: x, y: max(0, min(h - drawH, y)), width: nw, height: drawH)),
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
