// MIDILaneView.swift — Canvas-based piano-roll with DAW visible window + drag-to-seek.
// Copyright (c) 2026 Zack Urlocker
// Drag anywhere in the lane to reposition the playhead.
//
// Performance split: note drawing is isolated in NoteLayerView (Equatable).
// NoteLayerView.body is skipped by SwiftUI when only currentStep changes (every tick),
// so O(N) note iteration is eliminated from the per-tick hot path.
// Only the tiny playhead Canvas re-draws on each step tick.

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
    // Monotonic counter incremented in buildCache(). NoteLayerView.== checks this first
    // (O(1)) so the expensive onsets dict comparison never runs during normal playback.
    @State private var cacheVersion: Int = 0

    var body: some View {
        // Capture stable locals so closures hold their current values
        let onsets    = onsetsByNote
        let pitchRng  = cachedPitchRange
        let version   = cacheVersion
        let curStep   = playback.currentStep

        ZStack {
            // Note layer — does not capture currentStep, so SwiftUI skips its body
            // whenever only the playhead moves. O(N) note draw runs only on song
            // load, track regen, or DAW scroll — not on every 9 Hz step tick.
            NoteLayerView(
                events: events,
                onsets: onsets,
                pitchRange: pitchRng,
                visibleBars: visibleBars,
                barOffset: barOffset,
                totalBars: totalBars,
                isDrumTrack: isDrumTrack,
                trackColor: trackColor,
                noteH: noteH,
                cacheVersion: version
            )
            .equatable()

            // Playhead layer — O(1): one rect + optional triangle per tick
            Canvas { ctx, size in
                drawPlayhead(ctx: ctx, size: size, currentStep: curStep)
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
                                let clampedOffset  = max(0, min(barOffset, totalBars - clampedVisible))
                                let startStep = clampedOffset * 16
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
        .onChangeCompat(of: events) { _ in buildCache() }
    }

    // MARK: - Cache

    private func buildCache() {
        var map: [UInt8: [Int]] = [:]
        for ev in events { map[ev.note, default: []].append(ev.stepIndex) }
        for key in map.keys { map[key]?.sort() }
        onsetsByNote = map
        cacheVersion += 1

        let notes = events.map { Int($0.note) }
        if notes.isEmpty {
            cachedPitchRange = (48, 84)
        } else {
            let lo = max(notes.min()! - 3, 0)
            let hi = min(notes.max()! + 3, 127)
            cachedPitchRange = hi - lo < 12 ? (lo, lo + 12) : (lo, hi)
        }
    }

    // MARK: - Playhead draw (O(1): only called by the playhead Canvas)

    private func drawPlayhead(ctx: GraphicsContext, size: CGSize, currentStep: Int) {
        let w = size.width
        let h = size.height
        let clampedVisible = max(1, min(visibleBars, totalBars))
        let clampedOffset  = max(0, min(barOffset, totalBars - clampedVisible))
        let visibleSteps   = clampedVisible * 16
        let startStep      = clampedOffset * 16

        guard currentStep >= startStep && currentStep < startStep + visibleSteps else { return }
        let px = CGFloat(currentStep - startStep) / CGFloat(visibleSteps) * w
        ctx.fill(Path(CGRect(x: px, y: 0, width: 2, height: h)),
                 with: .color(.white.opacity(0.9)))
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

// MARK: - NoteLayerView

// Equatable: SwiftUI calls == before deciding whether to re-run body.
// When only currentStep changes (every tick), inputs are equal → body skipped.
// Body re-runs only on song load, track regen, or DAW scroll.
private struct NoteLayerView: View, Equatable {
    let events: [MIDIEvent]
    let onsets: [UInt8: [Int]]
    let pitchRange: (Int, Int)
    let visibleBars: Int
    let barOffset: Int
    let totalBars: Int
    let isDrumTrack: Bool
    let trackColor: Color
    let noteH: CGFloat
    let cacheVersion: Int

    static func == (lhs: NoteLayerView, rhs: NoteLayerView) -> Bool {
        // Fast path: same cache version means events haven't changed — skip the O(N)
        // onsets dict comparison entirely. Version differs only on song load / track regen.
        guard lhs.cacheVersion == rhs.cacheVersion else { return false }
        return lhs.pitchRange.0 == rhs.pitchRange.0 &&
               lhs.pitchRange.1 == rhs.pitchRange.1 &&
               lhs.visibleBars  == rhs.visibleBars  &&
               lhs.barOffset    == rhs.barOffset     &&
               lhs.totalBars    == rhs.totalBars     &&
               lhs.isDrumTrack  == rhs.isDrumTrack   &&
               lhs.trackColor   == rhs.trackColor
    }

    var body: some View {
        Canvas { ctx, size in
            drawNotes(ctx: ctx, size: size)
        }
    }

    // MARK: - Note draw (bar lines + drum separators + note rects — no playhead)

    private func drawNotes(ctx: GraphicsContext, size: CGSize) {
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


        // Notes — only those overlapping visible window
        let (lo, hi) = pitchRange
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
    }

    // MARK: - Y calculation

    private func rawNoteY(note: Int, lo: Int, hi: Int, height: CGFloat) -> CGFloat {
        if isDrumTrack { return drumY(for: note, height: height) }
        let span = CGFloat(max(1, hi - lo))
        return (1.0 - CGFloat(note - lo) / span) * (height - noteH)
    }

    private func drumY(for note: Int, height: CGFloat) -> CGFloat {
        let norms: [Int: CGFloat] = [
            // Standard GM kit (rows top→bottom: cymbal → hat → tom → snare → kick)
            49: 0.04, 57: 0.04,
            51: 0.13, 53: 0.13, 55: 0.13,
            46: 0.22,
            42: 0.31, 44: 0.31,
            48: 0.40, 50: 0.40,
            37: 0.49, 39: 0.49,
            38: 0.58, 40: 0.58,
            41: 0.67, 43: 0.67, 45: 0.67, 47: 0.67,
            35: 0.80, 36: 0.80,
            // Hand percussion (AMB-DRUM-004) — shaker/maracas/claves → bongos → congas
            82: 0.04,           // Shaker         — top row (light, fast)
            70: 0.17,           // Maracas
            75: 0.30,           // Claves
            81: 0.30,           // Open Triangle  — same row as Claves (Brush Kit substitute)
            60: 0.44,           // Hi Bongo
            61: 0.56,           // Low Bongo
            63: 0.67,           // Open Hi Conga
            62: 0.78,           // Mute Hi Conga
            64: 0.90,           // Low Conga       — bottom row (heaviest)
        ]
        return (norms[note] ?? 0.50) * (height - noteH)
    }

    private let drumLaneNorms: [CGFloat] = [
        // Standard kit separators
        0.04, 0.13, 0.22, 0.31, 0.40, 0.49, 0.58, 0.67, 0.80,
        // Hand percussion separators
        0.17, 0.30, 0.44, 0.56, 0.78, 0.90
    ]

    // MARK: - Colors

    private func noteColor(for note: Int) -> Color {
        if isDrumTrack {
            switch note {
            case 35, 36:         return trackColor                    // kick
            case 38, 40:         return trackColor.opacity(0.85)      // snare
            case 42, 44, 46:     return trackColor.opacity(0.60)      // hats
            case 82, 70:         return trackColor.opacity(0.55)      // shaker / maracas
            case 75, 81:         return trackColor.opacity(0.70)      // claves / triangle
            case 60, 61:         return trackColor.opacity(0.80)      // bongos
            case 62, 63, 64:     return trackColor.opacity(0.90)      // congas
            default:             return trackColor.opacity(0.75)
            }
        }
        let oct = min(max(note / 12, 0), 8)
        return trackColor.opacity(0.72 + Double(oct % 4) * 0.07)
    }
}
