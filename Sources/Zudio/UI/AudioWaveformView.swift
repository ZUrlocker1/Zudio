// AudioWaveformView.swift — Looping audio waveform display for the Chill Texture track.
// Copyright (c) 2026 Zack Urlocker
// Replaces MIDILaneView on kTrackTexture when an audio texture is selected.
// Same 3-layer ZStack pattern as MIDILaneView: static waveform layer (Equatable,
// skipped on playhead ticks) + playhead Canvas (O(1) per tick) + drag-to-seek.

import SwiftUI
import AVFoundation

struct AudioWaveformView: View {
    @EnvironmentObject var playback: PlaybackEngine

    let filename: String?
    let totalBars: Int
    let tempo: Double
    let visibleBars: Int
    let barOffset: Int
    var offsetSeconds: Int = 0
    var onSeek: ((Int) -> Void)? = nil

    @State private var samples: [Float] = []
    @State private var audioDurationBars: Double = 0
    @State private var audioDurationSeconds: Double = 0
    // Tracks the most-recently-requested filename so stale background tasks
    // cannot repopulate samples after a newer filename (including nil) has been set.
    @State private var expectedFilename: String? = nil

    var body: some View {
        let curStep = playback.currentStep
        ZStack {
            WaveformLayerView(
                samples: samples,
                audioDurationBars: audioDurationBars,
                visibleBars: visibleBars,
                barOffset: barOffset,
                totalBars: totalBars,
                offsetBars: tempo > 0 ? Double(offsetSeconds) / (240.0 / max(tempo, 1)) : 0
            )
            .equatable()

            // Playhead — O(1), redraws every tick
            Canvas { ctx, size in
                drawPlayhead(ctx: ctx, size: size, currentStep: curStep)
            }

            // Drag-to-seek
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
                                onSeek?(startStep + Int(fraction * Double(visibleSteps)))
                            }
                    )
            }
        }
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .onAppear {
            expectedFilename = filename
            if let f = filename { Task { await loadWaveform(filename: f) } }
        }
        .onChangeCompat(of: filename) { newName in
            expectedFilename = newName
            if let f = newName {
                Task { await loadWaveform(filename: f) }
            } else {
                samples = []
                audioDurationBars = 0
            }
        }
        .onChangeCompat(of: tempo) { newTempo in
            // Recalculate bar duration from cached seconds — no file re-read needed
            guard audioDurationSeconds > 0 else { return }
            audioDurationBars = audioDurationSeconds / (240.0 / max(newTempo, 1))
        }
    }

    // MARK: - Waveform loading

    private func loadWaveform(filename: String) async {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let url = resourceURL
            .appendingPathComponent("Textures")
            .appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        guard let file = try? AVAudioFile(forReading: url) else { return }

        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: frameCount),
              (try? file.read(into: buffer)) != nil,
              let channelData = buffer.floatChannelData else { return }

        // Use max across all channels so stereo files with uneven content display correctly.
        // Max (not average) preserves the louder channel's peaks without reducing ocean-like
        // files where both channels are nearly identical.
        let frameLength  = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Downsample to 256 peak buckets — more than enough for the lane width (~400–600px)
        let bucketCount = 256
        let bucketSize  = max(1, frameLength / bucketCount)
        var peaks = [Float](repeating: 0, count: bucketCount)
        for i in 0..<bucketCount {
            let start = i * bucketSize
            let end   = min(start + bucketSize, frameLength)
            var peak: Float = 0
            for j in start..<end {
                for ch in 0..<channelCount {
                    let v = abs(channelData[ch][j])
                    if v > peak { peak = v }
                }
            }
            peaks[i] = peak
        }

        // Normalize
        let maxPeak = peaks.max() ?? 1
        if maxPeak > 0 {
            for i in 0..<peaks.count { peaks[i] /= maxPeak }
        }

        // How many song bars does this audio file span before looping?
        // Use buffer.frameLength (actual decoded frames) not file.length, which may differ
        // from decoded frame count when there are priming/remainder frames or sample-rate conversion.
        let sampleRate     = file.processingFormat.sampleRate
        let durationSec    = Double(frameLength) / sampleRate
        let barDurationSec = 240.0 / max(tempo, 1)
        let durationBars   = durationSec / barDurationSec

        await MainActor.run {
            // Discard if a newer filename (or nil) has been requested since this task started
            guard expectedFilename == filename else { return }
            self.samples = peaks
            self.audioDurationSeconds = durationSec
            self.audioDurationBars = durationBars
        }
    }

    // MARK: - Playhead (identical to MIDILaneView)

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
    }
}

// MARK: - WaveformLayerView (Equatable — not re-drawn on playhead ticks)

private struct WaveformLayerView: View, Equatable {
    let samples: [Float]
    let audioDurationBars: Double
    let visibleBars: Int
    let barOffset: Int
    let totalBars: Int
    var offsetBars: Double = 0

    static func == (lhs: WaveformLayerView, rhs: WaveformLayerView) -> Bool {
        lhs.samples.count     == rhs.samples.count     &&
        lhs.audioDurationBars == rhs.audioDurationBars &&
        lhs.visibleBars       == rhs.visibleBars       &&
        lhs.barOffset         == rhs.barOffset         &&
        lhs.totalBars         == rhs.totalBars         &&
        lhs.offsetBars        == rhs.offsetBars
    }

    var body: some View {
        Canvas { ctx, size in
            drawContent(ctx: ctx, size: size)
        }
    }

    private func drawContent(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let clampedVisible = max(1, min(visibleBars, totalBars))
        let clampedOffset  = max(0, min(barOffset, totalBars - clampedVisible))

        // Bar lines — identical to MIDILaneView
        for bar in 0..<clampedVisible {
            let absoluteBar = bar + clampedOffset
            let x = CGFloat(bar) / CGFloat(clampedVisible) * w
            let alpha: Double = absoluteBar % 4 == 0 ? 0.14 : 0.05
            ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: h)),
                     with: .color(.white.opacity(alpha)))
        }

        guard !samples.isEmpty && audioDurationBars > 0 else { return }

        // Draw waveform: one 1-pixel-wide rect per horizontal pixel
        let pixelCount = Int(w)
        guard pixelCount > 0 else { return }

        let maxBarH = h * 0.80   // waveform uses 80% of lane height
        let centerY = h * 0.50

        // Build the filled waveform as a single Path for efficiency
        var fillPath = Path()
        var outlineTop    = Path()
        var outlineBottom = Path()

        var firstPoint = true
        for px in 0..<pixelCount {
            let fraction    = Double(px) / Double(pixelCount)
            let absoluteBar = Double(clampedOffset) + fraction * Double(clampedVisible)
            // Shift by offset then wrap into the audio loop — matches AudioTexturePlayer's tail+loop scheduling
            let loopedBar   = audioDurationBars > 0
                ? (absoluteBar + offsetBars).truncatingRemainder(dividingBy: audioDurationBars)
                : 0
            let sampleIdx   = min(samples.count - 1,
                                  Int(loopedBar / audioDurationBars * Double(samples.count)))
            let amp         = CGFloat(samples[sampleIdx])
            let halfH       = max(1, amp * maxBarH * 0.5)
            let top         = centerY - halfH
            let x           = CGFloat(px)

            fillPath.addRect(CGRect(x: x, y: top, width: 1, height: halfH * 2))

            // Outline: trace top and bottom edges as connected lines
            let topPt    = CGPoint(x: x + 0.5, y: top)
            let bottomPt = CGPoint(x: x + 0.5, y: top + halfH * 2)
            if firstPoint {
                outlineTop.move(to: topPt)
                outlineBottom.move(to: bottomPt)
                firstPoint = false
            } else {
                outlineTop.addLine(to: topPt)
                outlineBottom.addLine(to: bottomPt)
            }
        }

        outlineTop.addPath(outlineBottom)
        ctx.fill(fillPath, with: .color(.blue.opacity(0.45)))
        ctx.stroke(outlineTop, with: .color(.blue.opacity(0.80)), lineWidth: 1)
    }
}
