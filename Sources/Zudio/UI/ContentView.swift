// ContentView.swift — root layout: top bar + song info+zoom strip + track rows + h-scroll + status box

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    private let trackLabels = ["Lead 1", "Lead 2", "Pads", "Rhythm", "Texture", "Bass", "Drums"]

    // Pinch-to-zoom state — anchor captured on first tick of each gesture
    @State private var pinchAnchorBars: Int = 16
    @State private var isPinching: Bool = false

    // Layout constants matching TrackRowView internals
    // TrackRowView: .padding(.horizontal, 8) wraps HStack(spacing:0)
    //   left panel: .frame(width:232).padding(.horizontal,6)  → 8+6+232+6 = 252 from left edge
    //   right panel: .frame(width:136).padding(.horizontal,6) → 8+6+136+6 = 156 from right edge
    private let midiLaneLeading: CGFloat = 8 + 6 + 232 + 6   // 252
    private let midiLaneTrailing: CGFloat = 8 + 6 + 136 + 6  // 156

    var body: some View {
        VStack(spacing: 0) {
            TopBarView()
                .fixedSize(horizontal: false, vertical: true)   // top bar never shrinks
                .layoutPriority(3)

            // Song info + zoom slider — single combined row
            HStack(spacing: 10) {
                if let song = appState.songState {
                    Text(song.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    infoChip("Mood",   song.frame.mood.rawValue.capitalized)
                    infoChip("Key",    "\(song.frame.key) \(song.frame.mode.rawValue)")
                    infoChip("BPM",    "\(song.frame.tempo)")
                    infoChip("Length", songLength(song))
                    infoChip("Bar", String(format: "%03d", appState.playback.currentBar + 1))
                } else if !appState.isGenerating {
                    Text("No song — press Generate or Play")
                        .foregroundStyle(Color.white.opacity(0.45))
                        .font(.system(size: 12))
                }

                Spacer()

                // Zoom slider — right side of the same row
                HStack(spacing: 5) {
                    Text("Bars:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(appState.visibleBars) },
                            set: { newVal in
                                let total = appState.songState?.frame.totalBars ?? 64
                                appState.visibleBars = max(4, min(total, (Int(newVal) / 4) * 4))
                            }
                        ),
                        in: 4...64, step: 4
                    )
                    .frame(width: 140)
                    Text("\(appState.visibleBars)b")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color(white: 0.17))

            // Track rows — Lead 1 (index 0) gets the single playhead handle triangle
            VStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { trackIndex in
                    TrackRowView(
                        trackIndex: trackIndex,
                        label: trackLabels[trackIndex],
                        events: appState.songState?.events(forTrack: trackIndex) ?? [],
                        totalBars: appState.songState?.frame.totalBars ?? 32,
                        isMuted: appState.muteState[trackIndex],
                        isSolo:  appState.soloState[trackIndex],
                        isEffectivelyMuted: appState.isEffectivelyMuted(trackIndex),
                        visibleBars: appState.visibleBars,
                        barOffset: appState.visibleBarOffset,
                        showPlayheadHandle: trackIndex == 0,
                        onSeek: { step in appState.seekTo(step: step) }
                    )
                }
            }
            .background(Color(white: 0.18))   // single slab behind all rows — eliminates inter-row seams
            .padding(.top, 2)
            .layoutPriority(1)   // shrinks after status box, before top bar
            .gesture(
                MagnificationGesture()
                    .onChanged { scale in
                        if !isPinching {
                            pinchAnchorBars = appState.visibleBars
                            isPinching = true
                        }
                        let total = appState.songState?.frame.totalBars ?? 64
                        let divided = scale > 0 ? Double(pinchAnchorBars) / scale : Double(total)
                        let raw = divided.isFinite ? Int(divided.rounded()) : total
                        let clamped = max(4, min(total, raw))
                        appState.visibleBars = clamped
                        // Keep offset in bounds as window shrinks or grows
                        appState.visibleBarOffset = max(0, min(appState.visibleBarOffset, total - clamped))
                    }
                    .onEnded { _ in
                        isPinching = false
                        // Snap to nearest multiple of 4 to match the zoom slider behaviour
                        let total = appState.songState?.frame.totalBars ?? 64
                        let snapped = max(4, min(total, ((appState.visibleBars + 2) / 4) * 4))
                        appState.visibleBars = snapped
                        appState.visibleBarOffset = max(0, min(appState.visibleBarOffset, total - snapped))
                    }
            )
            .overlay {
                if appState.isGenerating {
                    ProgressView("Generating…")
                        .progressViewStyle(.circular)
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                } else if appState.songState == nil {
                    Text("Press Generate or Play to create a song")
                        .font(.callout)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            // Horizontal scrollbar — aligned with MIDI lanes, below Drums
            let totalBars = appState.songState?.frame.totalBars ?? 32
            let maxOffset = max(0, totalBars - appState.visibleBars)
            HStack(spacing: 0) {
                Color.clear.frame(width: midiLaneLeading - 8)
                HStack(spacing: 6) {
                    Text("Bar 1")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)
                    HorizontalScrollBar(
                        value: Binding(
                            get: { appState.visibleBarOffset },
                            set: { appState.visibleBarOffset = max(0, min($0, maxOffset)) }
                        ),
                        total: totalBars,
                        visible: appState.visibleBars
                    )
                    Text("Bar \(totalBars)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                Color.clear.frame(width: midiLaneTrailing - 8)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Color(white: 0.13))

            StatusBoxView()
                .layoutPriority(0)   // status box shrinks first when window narrows
        }
        .frame(minWidth: 900, minHeight: 500)
        .background(Color(white: 0.20))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $appState.showExportConfirmation) {
            ExportConfirmationView()
                .environmentObject(appState)
        }
        .overlay {
            if appState.isExportingAudio {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 18) {
                        Text("Exporting Audio…")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ProgressView(value: appState.audioExportProgress)
                            .frame(width: 300)
                            .tint(.white)
                        Text(appState.audioExportFilename)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                        Button("Cancel") { appState.cancelExport() }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.white)
                            .tint(.white)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Helpers

    private func infoChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label + ":")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.50))
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func songLength(_ song: SongState) -> String {
        let seconds = Int(Double(song.frame.totalBars) * 4.0 * 60.0 / Double(song.frame.tempo))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

// MARK: - Export confirmation dialog

struct ExportConfirmationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Audio")
                .font(.headline)
            VStack(spacing: 8) {
                Text("Export to an M4A Audio file will take approximately \(songMinutes).")
                    .multilineTextAlignment(.center)
                Text("Alternatively, we can save a 60 second sample.")
                    .multilineTextAlignment(.center)
            }
            .frame(width: 300)
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Sample") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        appState.startExport(sampleMode: true)
                    }
                }
                Button("Full Song") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        appState.startExport(sampleMode: false)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 400)
    }

    private var songLength: String {
        guard let song = appState.songState else { return "unknown" }
        let seconds = Int(Double(song.frame.totalBars) * 4.0 * 60.0 / Double(song.frame.tempo))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private var songMinutes: String {
        guard let song = appState.songState else { return "unknown" }
        let seconds = Double(song.frame.totalBars) * 4.0 * 60.0 / Double(song.frame.tempo)
        let minutes = Int((seconds + 30) / 60)
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

// MARK: - Custom thin horizontal scrollbar

struct HorizontalScrollBar: View {
    @Binding var value: Int      // current offset (in bars)
    let total: Int               // total bars in song
    let visible: Int             // visible bars

    private let trackHeight: CGFloat = 6
    private let thumbMinWidth: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let maxOffset = max(1, total - visible)
            let thumbFraction = min(1.0, CGFloat(visible) / CGFloat(max(1, total)))
            let thumbW = max(thumbMinWidth, w * thumbFraction)
            let travel = w - thumbW
            let thumbX = travel > 0 ? (CGFloat(value) / CGFloat(maxOffset)) * travel : 0

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.10))
                    .frame(height: trackHeight)

                // Thumb
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.35))
                    .frame(width: thumbW, height: trackHeight)
                    .offset(x: thumbX)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard travel > 0 else { return }
                        let newThumbX = max(0, min(drag.location.x - thumbW / 2, travel))
                        let newOffset = Int((newThumbX / travel) * CGFloat(maxOffset) + 0.5)
                        value = max(0, min(newOffset, maxOffset))
                    }
            )
        }
        .frame(height: 14)
    }
}
