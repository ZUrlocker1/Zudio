// VisualizerView.swift — Abstract generative visual for iPhone Player Mode.
// Brian Eno Reflection / JMJ Eon aesthetic: per-note orbs drift and fade.
// Comet tails and sonar rings for long notes, calculated mathematically (no stored history).
// Each track's home position drifts slowly in its own direction using sinusoidal oscillation.

import SwiftUI

struct VisualizerView: View {
    @EnvironmentObject var playback: PlaybackEngine
    @EnvironmentObject var appState: AppState
    var style: MusicStyle

    // Tracks which tracks currently have effects stripped via right-click (macOS only).
    // Mirrors dryTracks in PhonePlayerView — right-click toggles dry, right-click again restores.
    @State private var macDryTracks: Set<Int> = []

    // Keyed by trackIndex → timestamp of the most recent mute→unmute transition.
    // drawOrbs reads this to render a bright burst when the track comes back in.
    @State private var trackUnmuteFlash: [Int: Date] = [:]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                drawBackground(ctx: &ctx, size: size)
                drawOrbs(ctx: &ctx, size: size, now: tl.date)
            }
        }
        #if os(macOS)
        .overlay {
            MacVisualizerGestureView(
                notes: playback.activeVisualizerNotes,
                onClickOrb:         { handleClickOrb($0) },
                onDoubleClickOrb:   { handleDoubleClickOrb($0) },
                onClickEmpty:       { handleClickEmpty() },
                onDoubleClickEmpty: { handleDoubleClickEmpty() },
                onRightClickOrb:    { handleRightClickOrb($0) },
                onRightClickEmpty:  { handleRightClickEmpty() }
            )
        }
        #endif
        // Detect mute → unmute transitions; stamp a flash date so drawOrbs can burst that track.
        .onChange(of: appState.muteState) { oldMute, newMute in
            let now = Date()
            for i in 0..<min(oldMute.count, newMute.count) {
                if oldMute[i] && !newMute[i] {
                    trackUnmuteFlash[i] = now
                }
            }
        }
    }

    // MARK: - Mac gesture handlers (mirrors iPhone tap/double-tap-orb, tap-empty)
    #if os(macOS)
    private func handleClickOrb(_ trackIndex: Int) {
        // Single click → 2-bar mute + instrument regen on release
        appState.toggleMute(trackIndex)
        let twoBars = 2.0 * 4.0 * (60.0 / Double(appState.songState?.frame.tempo ?? 120))
        DispatchQueue.main.asyncAfter(deadline: .now() + twoBars) {
            if appState.muteState[trackIndex] {
                appState.toggleMute(trackIndex)
                appState.regenInstrument(forTrack: trackIndex)
            }
        }
    }

    private func handleDoubleClickOrb(_ trackIndex: Int) {
        // Double click → 2-bar auto-releasing solo
        let wasSoloed = appState.soloState[trackIndex]
        appState.toggleSolo(trackIndex)
        guard !wasSoloed else { return }
        let twoBars = 2.0 * 4.0 * (60.0 / Double(appState.songState?.frame.tempo ?? 120))
        DispatchQueue.main.asyncAfter(deadline: .now() + twoBars) {
            if appState.soloState[trackIndex] { appState.toggleSolo(trackIndex) }
        }
    }

    private func handleClickEmpty() {
        // Filter sweep — same as iPhone tap-empty
        playback.triggerGlobalFilterSweep()
    }

    private func handleDoubleClickEmpty() {
        // Reset effects — same as iPhone double-tap-empty
        appState.resetEffectsToDefaults()
        macDryTracks.removeAll()
    }

    private func handleRightClickOrb(_ trackIndex: Int) {
        // Dry/wet toggle — same as iPhone long-press-orb
        if macDryTracks.contains(trackIndex) {
            appState.restoreDefaultEffects(forTrack: trackIndex)
            macDryTracks.remove(trackIndex)
        } else {
            appState.clearAllEffects(forTrack: trackIndex)
            macDryTracks.insert(trackIndex)
        }
    }

    private func handleRightClickEmpty() {
        // Regen random non-drum track — same as iPhone long-press-empty
        appState.regenRandomNonDrumTrack()
    }
    #endif

    // MARK: - Background

    private func drawBackground(ctx: inout GraphicsContext, size: CGSize) {
        let gradient = Gradient(colors: bgColors)
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(gradient,
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint:   CGPoint(x: size.width / 2, y: size.height))
        )
    }

    private var bgColors: [Color] {
        switch style {
        case .ambient:  return [Color(hue: 0.67, saturation: 0.8, brightness: 0.09),
                                Color(hue: 0.70, saturation: 0.6, brightness: 0.03)]
        case .chill:    return [Color(hue: 0.55, saturation: 0.3, brightness: 0.10),
                                Color(hue: 0.05, saturation: 0.2, brightness: 0.04)]
        case .kosmic:   return [Color(hue: 0.75, saturation: 0.9, brightness: 0.08),
                                Color(hue: 0.78, saturation: 0.7, brightness: 0.02)]
        case .motorik:  return [Color(hue: 0.33, saturation: 0.25, brightness: 0.09),
                                Color(hue: 0.33, saturation: 0.1,  brightness: 0.03)]
        }
    }

    // MARK: - Orbs

    private func drawOrbs(ctx: inout GraphicsContext, size: CGSize, now: Date) {
        // When any track is soloed, non-soloed tracks render at 5% intensity — ghostly but present.
        let anySolo = appState.isAnySolo
        for orb in playback.activeVisualizerNotes {
            let age = now.timeIntervalSince(orb.birthDate)
            let lifetime = orbLifetime(orb)
            guard age < lifetime else { continue }

            let isLong     = orb.durationSteps >= 8
            let isVeryLong = orb.durationSteps >= 32

            // Cosine fade: 1.0 at birth → 0 at lifetime end
            let t       = age / lifetime
            let opacity = 0.5 * (1.0 + cos(t * .pi))

            // Direct mute (click on orb) ghosts at 6%; solo-out ghosts at 5%.
            let directlyMuted = appState.muteState[orb.trackIndex]
            let soloedOut     = anySolo && !appState.soloState[orb.trackIndex]
            let muteScale: Double = directlyMuted ? 0.06 : (soloedOut ? 0.05 : 1.0)

            let color = trackColor(orb.trackIndex)

            // Comet tail ghosts (drawn before live orb so it sits on top)
            if isLong {
                let ghostCount = isVeryLong ? 4 : 3
                for g in 1...ghostCount {
                    let ghostAge = max(0, age - Double(g) * 0.08)
                    let pos = orbPosition(orb: orb, age: ghostAge, size: size, now: now)
                    let ghostRadius = orbRadius(orb) * (1.0 - Double(g) * 0.15)
                    let ghostOp = opacity * (0.3 / Double(g)) * muteScale
                    ctx.fill(
                        Path(ellipseIn: orbRect(pos, ghostRadius)),
                        with: .color(color.opacity(ghostOp))
                    )
                }
            }

            // Sonar ring for very long notes — expands and fades over lifetime
            if isVeryLong {
                let ringProgress = age / lifetime
                let ringRadius   = orbRadius(orb) * (1.0 + ringProgress * 3.0)
                let ringOp       = opacity * 0.4 * (1.0 - ringProgress) * muteScale
                let ringWidth: CGFloat = 1.5
                let pos = orbPosition(orb: orb, age: age, size: size, now: now)
                let outer = orbRect(pos, ringRadius)
                let inner = orbRect(pos, ringRadius - ringWidth)
                var ring = Path(ellipseIn: outer)
                ring.addEllipse(in: inner)
                ctx.fill(ring, with: .color(color.opacity(ringOp)))
            }

            // Live orb: halo + core, with optional un-mute flash burst
            let pos    = orbPosition(orb: orb, age: age, size: size, now: now)
            let radius = orbRadius(orb)

            // Cosine burst: peaks at 1.0 the instant the track un-mutes, decays to 0 over 0.6 s.
            var flashBoost = 0.0
            if let flashDate = trackUnmuteFlash[orb.trackIndex] {
                let flashAge = now.timeIntervalSince(flashDate)
                if flashAge < 0.6 {
                    flashBoost = 0.5 * (1.0 + cos(flashAge / 0.6 * .pi))
                }
            }

            let haloR  = radius * (2.2 + flashBoost * 2.5)
            let haloOp = opacity * (0.22 + flashBoost * 0.55) * muteScale
            ctx.fill(Path(ellipseIn: orbRect(pos, haloR)), with: .color(color.opacity(haloOp)))
            let coreR  = radius * (1.0 + flashBoost * 0.45)
            let coreOp = opacity * (0.85 + flashBoost * 0.60) * muteScale
            ctx.fill(Path(ellipseIn: orbRect(pos, coreR)), with: .color(color.opacity(coreOp)))

        }

        // Flash rings at each track's home position — drawn immediately on action,
        // independent of live orbs so there is no delay waiting for a note to sound.
        // One ring per active flash event, centered where that track's orbs congregate.
        let wallTime = now.timeIntervalSinceReferenceDate
        for (trackIndex, flashDate) in appState.visualizerFlashEvents {
            let flashAge = now.timeIntervalSince(flashDate)
            guard flashAge < 0.5 else { continue }
            let fp = flashAge / 0.5                          // 0 → 1
            let (homeX, homeY) = trackHome(trackIndex: trackIndex, wallTime: wallTime)
            let center = CGPoint(x: size.width * homeX, y: size.height * homeY)
            let flashR  = 16.0 + fp * 56.0                  // expands 16 pt → 72 pt
            let flashOp = (1.0 - fp) * 0.85                 // fades to transparent
            let rw: CGFloat = 2.5
            var ring = Path(ellipseIn: orbRect(center, flashR + rw))
            ring.addEllipse(in: orbRect(center, max(0, flashR - rw)))
            ctx.fill(ring, with: .color(Color.white.opacity(flashOp)))
        }

        // Canvas-wide white flash for filter-sweep gesture — fades over 3s (matches sweep duration).
        // Drawn last so it overlays everything else briefly.
        if let flashDate = playback.canvasFlashDate {
            let flashAge = now.timeIntervalSince(flashDate)
            if flashAge < 3.0 {
                let fp = flashAge / 3.0                      // 0 → 1 over 3 seconds
                // Gentle cosine fade: 0.20 at t=0, smooth decay to 0 at t=3s
                let flashOp = 0.20 * 0.5 * (1.0 + cos(fp * .pi))
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color.white.opacity(flashOp)))
            }
        }
    }

    // MARK: - Lifetime (doubled from original)

    func orbLifetime(_ orb: VisualizerNote) -> Double {
        if orb.durationSteps <= 4  { return 1.6 }   // spark (was 0.8)
        if orb.durationSteps <= 8  { return 3.0 }   // medium (was 1.5)
        if orb.durationSteps <= 16 { return 5.0 }   // comet (was 2.5)
        return 7.0                                   // comet+sonar (was 3.5)
    }

    // MARK: - Radius (half notes and whole notes 2x)

    func orbRadius(_ orb: VisualizerNote) -> Double {
        let base = 8.0 + Double(orb.velocity) / 127.0 * 20.0
        return orb.durationSteps >= 8 ? base * 2.0 : base
    }

    // MARK: - Track home position (slow sinusoidal drift, unique per track)

    /// Each track's anchor drifts in its own direction on a ~25-60s timescale.
    /// Uses two independent sin/cos oscillations on X and Y so the path never repeats quickly.
    func trackHome(trackIndex: Int, wallTime: Double) -> (x: Double, y: Double) {
        switch trackIndex {
        case kTrackLead1:   // ~32s X, ~43s Y — upper-mid area
            return (0.50 + sin(wallTime * 0.196 + 0.0) * 0.22,
                    0.30 + cos(wallTime * 0.146 + 1.2) * 0.18)
        case kTrackLead2:   // ~36s X, ~26s Y — overlaps Lead1 loosely
            return (0.45 + sin(wallTime * 0.173 + 2.1) * 0.20,
                    0.35 + cos(wallTime * 0.239 + 0.8) * 0.17)
        case kTrackPads:    // ~60s X, ~70s Y — large slow sweep across mid
            return (0.50 + sin(wallTime * 0.105 + 4.2) * 0.28,
                    0.48 + cos(wallTime * 0.089 + 3.5) * 0.24)
        case kTrackRhythm:  // ~25s X, ~33s Y — tighter faster motion
            return (0.55 + sin(wallTime * 0.251 + 1.7) * 0.18,
                    0.52 + cos(wallTime * 0.188 + 5.1) * 0.16)
        case kTrackTexture: // ~43s X, ~23s Y — wide lateral range
            return (0.40 + sin(wallTime * 0.148 + 3.3) * 0.28,
                    0.45 + cos(wallTime * 0.271 + 2.7) * 0.20)
        case kTrackBass:    // ~52s X, ~31s Y — stays lower on screen
            return (0.50 + sin(wallTime * 0.120 + 5.5) * 0.24,
                    0.70 + cos(wallTime * 0.201 + 4.0) * 0.12)
        case kTrackDrums:   // ~26s X, ~46s Y — lower-right region
            return (0.62 + sin(wallTime * 0.238 + 0.5) * 0.20,
                    0.68 + cos(wallTime * 0.136 + 6.2) * 0.14)
        default:
            return (0.50, 0.50)
        }
    }

    // MARK: - Position (home drift + pitch offset + age-based personality drift)

    func orbPosition(orb: VisualizerNote, age: Double, size: CGSize, now: Date) -> CGPoint {
        let wallTime = now.timeIntervalSinceReferenceDate
        let (homeX, homeY) = trackHome(trackIndex: orb.trackIndex, wallTime: wallTime)

        // Pitch adds ±15% vertical offset around home (high pitch = up)
        let pitchNorm   = clamp((Double(orb.note) - 36.0) / 60.0, 0.0, 1.0)
        let pitchOffset = (0.5 - pitchNorm) * 0.30

        // Per-track age drift personality
        let (driftX, driftY): (Double, Double)
        switch orb.trackIndex {
        case kTrackPads:    // slow large upward float
            driftX = sin(Double(orb.note % 7) * 0.9) * age * 5.0
            driftY = -age * 2.5
        case kTrackRhythm:  // tight oscillating fade
            driftX = sin(Double(orb.note % 5) * 1.1) * age * 2.5
            driftY = cos(Double(orb.velocity % 5) * 0.8) * age * 1.5
        case kTrackTexture: // wide lateral spread
            driftX = (Double(orb.note % 7) - 3.0) * age * 8.0
            driftY = sin(Double(orb.velocity % 3) * 1.2) * age * 3.0
        default:            // gentle jittered float
            driftX = (Double(orb.note % 7) - 3.0) * 0.03 * age * 10.0
            driftY = (Double(orb.velocity % 5) - 2.0) * 0.02 * age * 8.0 - age * 3.0
        }

        let x = size.width  * clamp(homeX + driftX / size.width,  0.02, 0.98)
        let y = size.height * clamp(homeY + pitchOffset + driftY / size.height, 0.02, 0.98)
        return CGPoint(x: x, y: y)
    }

    // MARK: - Helpers

    private func orbRect(_ center: CGPoint, _ radius: Double) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius,
               width: radius * 2, height: radius * 2)
    }

    /// Track hue palette — intra-family hue shifts distinguish Lead1/2 and Pads/Rhythm/Texture.
    private func trackColor(_ idx: Int) -> Color {
        switch idx {
        case kTrackLead1:    return Color(hue: 0.02, saturation: 0.85, brightness: 0.95) // pure red
        case kTrackLead2:    return Color(hue: 0.06, saturation: 0.85, brightness: 0.95) // orange-red
        case kTrackPads:     return Color(hue: 0.60, saturation: 0.75, brightness: 0.90) // soft blue (slow float)
        case kTrackRhythm:   return Color(hue: 0.54, saturation: 0.80, brightness: 0.88) // cyan-blue (tight)
        case kTrackTexture:  return Color(hue: 0.66, saturation: 0.70, brightness: 0.92) // indigo (wide lateral)
        case kTrackBass:     return Color(hue: 0.78, saturation: 0.70, brightness: 0.90) // purple
        case kTrackDrums:    return Color(hue: 0.14, saturation: 0.85, brightness: 0.98) // yellow
        default:             return .white
        }
    }

    func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }
}

// MARK: - Mac gesture overlay

#if os(macOS)
import AppKit

/// Transparent NSView overlay that handles clicks, right-clicks, and cursor changes
/// on the Mac visualizer canvas. Mirrors iOS CanvasGestureView hit-test logic.
private struct MacVisualizerGestureView: NSViewRepresentable {
    var notes: [VisualizerNote]
    var onClickOrb:         (Int) -> Void
    var onDoubleClickOrb:   (Int) -> Void
    var onClickEmpty:       ()    -> Void
    var onDoubleClickEmpty: ()    -> Void
    var onRightClickOrb:    (Int) -> Void
    var onRightClickEmpty:  ()    -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeNSView(context: Context) -> MacGestureNSView {
        let v = MacGestureNSView()
        v.coordinator = context.coordinator
        return v
    }
    func updateNSView(_ v: MacGestureNSView, context: Context) {
        context.coordinator.parent = self
    }

    // MARK: Coordinator — hit-testing + dispatch

    final class Coordinator: NSObject {
        var parent: MacVisualizerGestureView
        init(parent: MacVisualizerGestureView) { self.parent = parent }

        func dispatchSingle(at pt: CGPoint, size: CGSize) {
            if let t = hitOrb(at: pt, size: size) { parent.onClickOrb(t) }
            else { parent.onClickEmpty() }
        }
        func dispatchDouble(at pt: CGPoint, size: CGSize) {
            if let t = hitOrb(at: pt, size: size) { parent.onDoubleClickOrb(t) }
            else { parent.onDoubleClickEmpty() }
        }
        func dispatchRightClick(at pt: CGPoint, size: CGSize) {
            if let t = hitOrb(at: pt, size: size) { parent.onRightClickOrb(t) }
            else { parent.onRightClickEmpty() }
        }

        /// Returns the trackIndex of the topmost orb under `point`, or nil if empty space.
        /// Internal so MacGestureNSView can call it for cursor updates.
        func hitOrb(at point: CGPoint, size: CGSize) -> Int? {
            let now = Date()
            for orb in parent.notes.reversed() {
                let age = now.timeIntervalSince(orb.birthDate)
                guard age < orbLifetime(orb) else { continue }
                let pos    = orbPosition(orb: orb, age: age, size: size, now: now)
                let radius = orbRadius(orb) * 1.5   // generous hit target
                let dx = point.x - pos.x
                let dy = point.y - pos.y
                if dx*dx + dy*dy <= radius*radius { return orb.trackIndex }
            }
            return nil
        }

        // -- Position helpers kept in sync with VisualizerView --

        private func orbLifetime(_ orb: VisualizerNote) -> Double {
            if orb.durationSteps <= 4  { return 1.6 }
            if orb.durationSteps <= 8  { return 3.0 }
            if orb.durationSteps <= 16 { return 5.0 }
            return 7.0
        }
        private func orbRadius(_ orb: VisualizerNote) -> Double {
            let base = 8.0 + Double(orb.velocity) / 127.0 * 20.0
            return orb.durationSteps >= 8 ? base * 2.0 : base
        }
        private func trackHome(_ idx: Int, wallTime: Double) -> (Double, Double) {
            switch idx {
            case kTrackLead1:   return (0.50 + sin(wallTime*0.196+0.0)*0.22, 0.30 + cos(wallTime*0.146+1.2)*0.18)
            case kTrackLead2:   return (0.45 + sin(wallTime*0.173+2.1)*0.20, 0.35 + cos(wallTime*0.239+0.8)*0.17)
            case kTrackPads:    return (0.50 + sin(wallTime*0.105+4.2)*0.28, 0.48 + cos(wallTime*0.089+3.5)*0.24)
            case kTrackRhythm:  return (0.55 + sin(wallTime*0.251+1.7)*0.18, 0.52 + cos(wallTime*0.188+5.1)*0.16)
            case kTrackTexture: return (0.40 + sin(wallTime*0.148+3.3)*0.28, 0.45 + cos(wallTime*0.271+2.7)*0.20)
            case kTrackBass:    return (0.50 + sin(wallTime*0.120+5.5)*0.24, 0.70 + cos(wallTime*0.201+4.0)*0.12)
            case kTrackDrums:   return (0.62 + sin(wallTime*0.238+0.5)*0.20, 0.68 + cos(wallTime*0.136+6.2)*0.14)
            default:            return (0.50, 0.50)
            }
        }
        private func orbPosition(orb: VisualizerNote, age: Double, size: CGSize, now: Date) -> CGPoint {
            let wt = now.timeIntervalSinceReferenceDate
            let (homeX, homeY) = trackHome(orb.trackIndex, wallTime: wt)
            let pitchNorm   = max(0, min((Double(orb.note) - 36.0) / 60.0, 1.0))
            let pitchOffset = (0.5 - pitchNorm) * 0.30
            let (driftX, driftY): (Double, Double)
            switch orb.trackIndex {
            case kTrackPads:    driftX = sin(Double(orb.note % 7) * 0.9) * age * 5.0
                                driftY = -age * 2.5
            case kTrackRhythm:  driftX = sin(Double(orb.note % 5) * 1.1) * age * 2.5
                                driftY = cos(Double(orb.velocity % 5) * 0.8) * age * 1.5
            case kTrackTexture: driftX = (Double(orb.note % 7) - 3.0) * age * 8.0
                                driftY = sin(Double(orb.velocity % 3) * 1.2) * age * 3.0
            default:            driftX = (Double(orb.note % 7) - 3.0) * 0.03 * age * 10.0
                                driftY = (Double(orb.velocity % 5) - 2.0) * 0.02 * age * 8.0 - age * 3.0
            }
            let x = size.width  * max(0.02, min(homeX + driftX / size.width,  0.98))
            let y = size.height * max(0.02, min(homeY + pitchOffset + driftY / size.height, 0.98))
            return CGPoint(x: x, y: y)
        }
    }
}

/// Transparent NSView backing MacVisualizerGestureView.
/// isFlipped = true makes y=0 at the top, matching SwiftUI Canvas coordinates.
private final class MacGestureNSView: NSView {
    weak var coordinator: MacVisualizerGestureView.Coordinator?
    private var pendingClick: DispatchWorkItem?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }

    // MARK: Tracking area — enables mouseMoved events for cursor changes

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        let pt   = convert(event.locationInWindow, from: nil)
        let size = CGSize(width: bounds.width, height: bounds.height)
        if coordinator?.hitOrb(at: pt, size: size) != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    // MARK: Left click — single (delayed) vs double; cmd+click routes to right-click handler

    override func mouseDown(with event: NSEvent) {
        let pt   = convert(event.locationInWindow, from: nil)
        let size = CGSize(width: bounds.width, height: bounds.height)
        // Cmd+click acts identically to right-click (dry/wet on orb, regen on empty).
        if event.modifierFlags.contains(.command) {
            pendingClick?.cancel()
            pendingClick = nil
            coordinator?.dispatchRightClick(at: pt, size: size)
            return
        }
        if event.clickCount == 2 {
            pendingClick?.cancel()
            pendingClick = nil
            coordinator?.dispatchDouble(at: pt, size: size)
        } else {
            pendingClick?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.coordinator?.dispatchSingle(
                    at: pt,
                    size: CGSize(width: self.bounds.width, height: self.bounds.height)
                )
            }
            pendingClick = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + NSEvent.doubleClickInterval,
                execute: work
            )
        }
    }

    // MARK: Right click — dry/wet toggle on orb, regen on empty

    override func rightMouseDown(with event: NSEvent) {
        let pt   = convert(event.locationInWindow, from: nil)
        let size = CGSize(width: bounds.width, height: bounds.height)
        coordinator?.dispatchRightClick(at: pt, size: size)
    }
}
#endif
