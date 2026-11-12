// MIDILaneView.swift — Canvas-based piano-roll with DAW visible window + drag-to-seek.
// Copyright (c) 2026 Zack Urlocker
// Drag anywhere in the lane to reposition the playhead.
//
// Performance split: note drawing is isolated in NoteLayerView (Equatable). The playhead is one
// Core Animation layer over all the lanes (TrackPlayheadOverlay), so playback costs the lane no
// per-frame drawing.

import SwiftUI
import Combine
import QuartzCore

struct MIDILaneView: View {
    let events: [MIDIEvent]
    let totalBars: Int
    let isDrumTrack: Bool
    var trackColor: Color = .white
    var visibleBars: Int = 16
    var barOffset: Int = 0
    var onSeek: ((Int) -> Void)? = nil   // called with absolute step index

    private let noteH: CGFloat = 7

    // Cached per-events data: recomputed only when events change (song load / track regen),
    // not on every Canvas redraw (which fires on each playhead step tick).
    @State private var onsetsByNote: [UInt8: [Int]] = [:]
    @State private var cachedPitchRange: (Int, Int) = (48, 84)
    // Monotonic counter incremented in buildCache(). NoteLayerView.== checks this first
    // (O(1)) so the expensive onsets dict comparison never runs during normal playback.
    @State private var cacheVersion: Int = 0

    var body: some View {
        // Capture stable locals so closures hold their current values. The lane does not observe
        // the playback engine (the playhead is drawn over the lanes), so this body only re-runs
        // on note-data changes (song load / regen / DAW scroll), not on bar or step ticks.
        let onsets    = onsetsByNote
        let pitchRng  = cachedPitchRange
        let version   = cacheVersion

        ZStack {
            // Note layer — Equatable, skipped on every tick. O(N) note draw
            // runs only on song load, track regen, or DAW scroll.
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

}

// MARK: - Track playhead

// One playhead for all the track lanes (2026-11-12). Each lane used to carry its own layer and
// re-anchor it separately; when a window-wide re-render (a log line, say) fell between two lanes'
// re-anchors, the lanes came out a few points apart for a bar. Now each lane reports its frame
// (LaneBoundsKey) and the track rows draw a single line over all of them (TrackPlayheadOverlay).

/// The track lanes' frames, so the rows can draw one playhead across them.
struct LaneBoundsKey: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value += nextValue()
    }
}

/// The playhead over the lanes reported through LaneBoundsKey: top of the first lane to the
/// bottom of the last, the lanes' width. Touches pass through to the lanes' drag-to-seek.
struct TrackPlayheadOverlay: View {
    let lanes: [Anchor<CGRect>]
    let playback: PlaybackEngine
    let visibleBars: Int
    let barOffset: Int
    let totalBars: Int

    var body: some View {
        GeometryReader { geo in
            if let first = lanes.first {
                let r = lanes.dropFirst().reduce(geo[first]) { $0.union(geo[$1]) }
                PlayheadLayerView(playback: playback, visibleBars: visibleBars, barOffset: barOffset,
                                  totalBars: max(totalBars, 1), showHandle: true)
                    .frame(width: r.width, height: r.height)
                    .offset(x: r.minX, y: r.minY)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - PlayheadLayerView

// The playhead (2 pt line, plus the ▼ handle) as a Core Animation layer. While playing it carries
// one linear animation to the end of the visible window, which the window server runs at display
// rate with no per-frame work in the app. It replaced a TimelineView per lane that redrew a
// lane-sized Canvas 4-20 times a second (2026-11-11). Re-anchored on play/stop, every bar, seek,
// tempo change and Evolve pass (PlaybackEngine.playheadSync), and on zoom, scroll and resize.
struct PlayheadLayerView: Equatable {
    let playback: PlaybackEngine
    let visibleBars: Int
    let barOffset: Int
    let totalBars: Int
    let showHandle: Bool

    static func == (a: Self, b: Self) -> Bool {
        a.playback === b.playback && a.visibleBars == b.visibleBars && a.barOffset == b.barOffset
            && a.totalBars == b.totalBars && a.showHandle == b.showHandle
    }
}

#if os(macOS)
extension PlayheadLayerView: NSViewRepresentable {
    func makeNSView(context: Context) -> PlayheadHostView { PlayheadHostView() }
    func updateNSView(_ view: PlayheadHostView, context: Context) { view.configure(self) }
}
typealias PlayheadBaseView = NSView
#else
extension PlayheadLayerView: UIViewRepresentable {
    func makeUIView(context: Context) -> PlayheadHostView { PlayheadHostView() }
    func updateUIView(_ view: PlayheadHostView, context: Context) { view.configure(self) }
}
typealias PlayheadBaseView = UIView
#endif

final class PlayheadHostView: PlayheadBaseView {
    private let line   = CALayer()
    private let handle = CAShapeLayer()
    private var spec: PlayheadLayerView?
    private weak var subscribed: PlaybackEngine?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        super.init(frame: .zero)
        #if os(macOS)
        wantsLayer = true
        let root = layer!
        #else
        isUserInteractionEnabled = false
        backgroundColor = .clear
        let root = layer
        #endif
        root.masksToBounds = true                      // the handle stays inside the lanes
        line.anchorPoint = .zero
        line.backgroundColor = CGColor(gray: 1, alpha: 0.9)
        line.isHidden = true
        handle.fillColor = CGColor(gray: 1, alpha: 1)
        let tri = CGMutablePath()                      // ▼ centred on the 2 pt line
        tri.move(to: CGPoint(x: 1 - 6, y: 0))
        tri.addLine(to: CGPoint(x: 1 + 6, y: 0))
        tri.addLine(to: CGPoint(x: 1, y: 10))
        tri.closeSubpath()
        handle.path = tri
        handle.isHidden = true
        line.addSublayer(handle)
        root.addSublayer(line)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    #if os(macOS)
    override var isFlipped: Bool { true }            // y = 0 at the top, as on iOS
    override func hitTest(_ point: NSPoint) -> NSView? { nil }   // drags go to the seek overlay
    override func layout() { super.layout(); sync() }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        handle.contentsScale = window?.backingScaleFactor ?? 2
    }
    #else
    override func layoutSubviews() { super.layoutSubviews(); sync() }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        handle.contentsScale = window?.screen.scale ?? 2
    }
    #endif

    /// SwiftUI calls this on every re-render of the track rows (a log line re-renders the window);
    /// the glide is only rebuilt when something it depends on changed.
    func configure(_ spec: PlayheadLayerView) {
        guard spec != self.spec else { return }
        self.spec = spec
        if subscribed !== spec.playback {
            subscribed = spec.playback
            cancellables.removeAll()
            // @Published fires before the value is stored, so read the engine on the next turn.
            spec.playback.$isPlaying.receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sync() }.store(in: &cancellables)
            spec.playback.$currentBar.removeDuplicates().receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sync() }.store(in: &cancellables)
            spec.playback.playheadSync
                .sink { [weak self] in self?.sync() }.store(in: &cancellables)
        }
        sync()
    }

    /// Places the line at the engine's current position and, while playing, sets it gliding
    /// to the window's right edge at the song's step rate. The glide starts at the instant the
    /// position was read (`beginTime`), not when Core Animation commits it, so a busy main thread
    /// between the two cannot leave the line behind the music.
    private func sync() {
        guard let spec else { return }
        let pb  = spec.playback
        let now = CACurrentMediaTime()
        let w = bounds.width, h = bounds.height
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        line.removeAnimation(forKey: "glide")
        guard w > 0, h > 0, spec.totalBars > 0 else { line.isHidden = true; return }

        let visible   = max(1, min(spec.visibleBars, spec.totalBars))
        let offset    = max(0, min(spec.barOffset, spec.totalBars - visible))
        let startStep = Double(offset * 16)
        let steps     = Double(visible * 16)
        let pos       = pb.playheadPosition(at: now)
        guard pos >= startStep && pos < startStep + steps else { line.isHidden = true; return }

        line.isHidden = false
        line.bounds = CGRect(x: 0, y: 0, width: 2, height: h)
        handle.isHidden = !spec.showHandle
        let x = CGFloat((pos - startStep) / steps) * w
        line.position = CGPoint(x: x, y: 0)

        let secondsPerStep = pb.playbackSecondsPerStep
        guard pb.isPlaying && secondsPerStep > 0 else { return }
        let endStep  = min(startStep + steps, Double(pb.playbackTotalSteps))
        let duration = (endStep - pos) * secondsPerStep
        guard duration > 0 else { return }
        let endX = CGFloat((endStep - startStep) / steps) * w
        let glide = CABasicAnimation(keyPath: "position.x")
        glide.fromValue = x
        glide.toValue   = endX
        glide.duration  = duration
        glide.beginTime = line.convertTime(now, from: nil)
        glide.timingFunction = CAMediaTimingFunction(name: .linear)
        line.position = CGPoint(x: endX, y: 0)   // model value: where the glide ends
        line.add(glide, forKey: "glide")
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
