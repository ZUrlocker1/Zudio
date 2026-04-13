// ContentView.swift — root layout: top bar + song info+zoom strip + track rows + h-scroll + status box

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    private let trackLabels = ["Lead 1", "Lead 2", "Pads", "Rhythm", "Texture", "Bass", "Drums"]

    // Pinch-to-zoom state — anchor captured on first tick of each gesture
    @State private var pinchAnchorBars: Int = 16
    @State private var isPinching: Bool = false

    // Window width — measured by the root GeometryReader so it updates on every
    // resize (macOS) or orientation change (iOS). GeometryReader as the root view is
    // proposed new dimensions by the window system; .background/.overlay GeometryReaders
    // do not reliably re-evaluate on resize/rotation in SwiftUI.
    #if os(iOS)
    @State private var contentWidth:  CGFloat = UIScreen.main.bounds.width
    @State private var contentHeight: CGFloat = UIScreen.main.bounds.height
    #else
    @State private var contentWidth:  CGFloat = 1200  // actual value set by GeometryReader on first render
    @State private var contentHeight: CGFloat = 775   // actual value set by GeometryReader on first render
    @State private var fontSizeMonitor: Any? = nil    // NSEvent local monitor for +/= and - hotkeys
    #endif

    #if os(iOS)
    // iPad tab navigation — Visuals (default) · Log · Tracks · Songs
    private enum IPadTab: String { case visuals, log, tracks, songs }
    // Use @State so we can control what gets persisted: only visuals/tracks survive restart.
    // Log and Songs tabs reset to visuals on next launch (they're transient session views).
    @State private var iPadTab: IPadTab = {
        let stored = UserDefaults.standard.string(forKey: "iPadTabPersist") ?? ""
        return (stored == "tracks") ? .tracks : .visuals
    }()

    // iPad mini landscape: contentWidth 900–1150pt (portrait mini is <800pt).
    // In this orientation there isn't enough vertical room to show all 7 track rows
    // (441pt) plus the generation log, so the log is hidden on the Tracks tab.
    private var isIPadMiniLandscape: Bool {
        contentWidth >= 900 && contentWidth < 1150
    }
    #endif

    // Brief flash feedback for the Generation Log +/- font-size buttons
    @State private var logMinusFlash: Bool = false
    @State private var logPlusFlash:  Bool = false

    // Cross-platform accessors for macOS-only AppState properties.
    // mainContent is compiled on all platforms even though it's only called on macOS,
    // so bare references to #if os(macOS) AppState properties would fail on iOS.
    private var macShowVisualizer: Bool {
        #if os(macOS)
        return appState.macShowVisualizer
        #else
        return false
        #endif
    }
    private var macIsCompact: Bool {
        #if os(macOS)
        return appState.isWindowCompact
        #else
        return false
        #endif
    }

    // Height of the track-rows VStack — measured via background GeometryReader.
    // Used to suppress the "Press Generate" placeholder when the grid is too short.
    @State private var trackRowsHeight: CGFloat = 0

    // Layout constants matching TrackRowView internals
    // TrackRowView: .padding(.horizontal, 8) wraps HStack(spacing:0)
    //   left panel: .frame(width:232).padding(.horizontal,6)  → 8+6+232+6 = 252 from left edge
    //   right panel: .frame(width:136).padding(.horizontal,6) → 8+6+136+6 = 156 from right edge
    private let midiLaneLeading: CGFloat = 8 + 6 + 232 + 6   // 252
    private let midiLaneTrailing: CGFloat = 8 + 6 + 136 + 6  // 156

    // MARK: - Body

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            PhonePlayerView()
                .environmentObject(appState)
                .environmentObject(appState.playback)
        } else {
            // iPad — tab-based layout (Visuals · Log · Tracks · Songs)
            GeometryReader { geo in
                iPadContent
                    .onAppear      { contentWidth = geo.size.width }
                    .onChange(of: geo.size) { size in contentWidth = size.width }
            }
        }
        #else
        // macOS — existing layout unchanged
        GeometryReader { geo in
            mainContent
                .onAppear      { contentWidth = geo.size.width; contentHeight = geo.size.height }
                .onChange(of: geo.size) { size in contentWidth = size.width; contentHeight = size.height }
        }
        .frame(minWidth: 650, minHeight: kCompactContentHeight, alignment: .top)
        #endif
    }

    // MARK: - Main layout (shared between iOS GeometryReader wrapper and macOS direct use)

    @ViewBuilder private var mainContent: some View {
        VStack(spacing: 0) {
            TopBarView(contentWidth: contentWidth)
                .fixedSize(horizontal: false, vertical: true)   // top bar never shrinks
                .layoutPriority(3)
                .zIndex(1)   // wins every hit-test over track rows + scrollbar when window is short

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

                // Zoom slider — right side of the same row; hidden in compact/minimum window
                if !macIsCompact && contentHeight >= 250 {
                    HStack(spacing: 5) {
                        Text("Bars:")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize()
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
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color(white: 0.17))

            // Track rows (or Visualizer) + scrollbar in a single sub-VStack so the scrollbar
            // always claims its 22pt before track rows compress — at any window height.
            VStack(spacing: 0) {
            if macShowVisualizer {
                VisualizerView(style: appState.selectedStyle)
                    .environmentObject(appState.playback)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Lead 1 (index 0) gets the single playhead handle triangle
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
                            onSeek: { step in appState.seekTo(step: step) },
                            contentWidth: contentWidth
                        )
                    }
                }
                // frame(minHeight:0) + clipped() lets the VStack compress when the window is
                // made short: its row children have fixed .frame(height:63) so SwiftUI would
                // otherwise treat it as incompressible.
                // contentShape(Rectangle()) bounds the gesture-capture area to the visible
                // clipped region so MIDILaneView's DragGesture can't reach outside it.
                .frame(minHeight: 0)
                .clipped()
                .contentShape(Rectangle())
                .background(
                    GeometryReader { geo in
                        Color(white: 0.18)   // single slab behind all rows — eliminates inter-row seams
                            .onAppear      { trackRowsHeight = geo.size.height }
                            .onChange(of: geo.size.height) { h in trackRowsHeight = h }
                    }
                )
                .padding(.top, 2)
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
                    } else if appState.songState == nil && trackRowsHeight >= 300 {
                        Text("Press Generate or Play to create a song")
                            .font(.callout)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                // Clip overlay to track-row frame so "Press Generate" text doesn't escape
                // into the top bar when track rows compress to 0px in compact window mode.
                .clipped()
            }

            // Horizontal scrollbar — always visible.
            // In tracks mode (normal): aligned with MIDI lanes, Generation Log label + ±buttons on left.
            // In visualizer or compact mode: full-width scrollbar only (no label/buttons).
            let totalBars = appState.songState?.frame.totalBars ?? 32
            let maxOffset = max(0, totalBars - appState.visibleBars)
            HStack(spacing: 0) {
                if !macShowVisualizer && !macIsCompact {
                    // Generation Log label + font-size buttons — MIDI lane left column
                    HStack(spacing: 4) {
                        Text("Generation Log")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Button {
                                appState.statusLogFontOffset = max(-4, appState.statusLogFontOffset - 1)
                                logMinusFlash = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { logMinusFlash = false }
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 11, height: 11)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(logMinusFlash ? Color.white.opacity(0.55) : Color(white: 0.26),
                                                in: RoundedRectangle(cornerRadius: 3))
                                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(white: 0.48), lineWidth: 0.5))
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 10, weight: .medium))
                            .help("Decrease log font size")
                            .disabled(appState.statusLogFontOffset <= -4)
                            Button {
                                appState.statusLogFontOffset = min(8, appState.statusLogFontOffset + 1)
                                logPlusFlash = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { logPlusFlash = false }
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 11, height: 11)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(logPlusFlash ? Color.white.opacity(0.55) : Color(white: 0.26),
                                                in: RoundedRectangle(cornerRadius: 3))
                                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(white: 0.48), lineWidth: 0.5))
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 10, weight: .medium))
                            .help("Increase log font size")
                            .disabled(appState.statusLogFontOffset >= 8)
                        }
                        .padding(.leading, 4)
                    }
                    .frame(width: midiLaneLeading - 8, alignment: .leading)
                }
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
                if !macShowVisualizer && !macIsCompact {
                    Color.clear.frame(width: midiLaneTrailing - 8)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .fixedSize(horizontal: false, vertical: true)   // scrollbar always gets 22pt within the group
            .background(Color(white: 0.13))
            }   // end track-rows + scrollbar sub-VStack
            .layoutPriority(1)   // whole group shrinks before status box

            // StatusBoxView — shown in tracks mode; hidden when visualizer fills the space
            if !macShowVisualizer {
                StatusBoxView(contentWidth: contentWidth)
                    .layoutPriority(0)   // status box shrinks first when window narrows
            }
        }
        #if os(iOS)
        .frame(minHeight: 500)
        #else
        // alignment: .top ensures that when window is at minimum height and TopBarView's
        // fixedSize children cause the VStack to overflow, the overflow goes BELOW the
        // visible frame (not above), keeping the top bar and logo always visible.
        .frame(minWidth: 650, minHeight: kCompactContentHeight, alignment: .top)
        #endif
        .background(Color(white: 0.20))
        .preferredColorScheme(.dark)
        #if os(macOS)
        // Log font-size hotkeys via NSEvent local monitor.
        // SwiftUI .keyboardShortcut is unreliable for = / - because macOS system shortcuts
        // (zoom in/out) intercept them before SwiftUI sees them.
        // The monitor fires first; it passes keys through when a text field is focused.
        //   = key (with any combo of Cmd/Shift, covering =, +, Cmd-=, Cmd-+) → increase
        //   - key (plain or Cmd-) → decrease
        .onAppear {
            // Sync compact-mode arrow icon with actual window size.
            // macOS persists the frame via NSUserDefaults even with isRestorable = false,
            // so the window may launch smaller than the default. Delay lets it settle first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { appState.syncCompactStateFromWindow() }

            fontSizeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
                guard let appState else { return event }
                // Don't steal keys from focused text fields (e.g. BPM input)
                if let fr = NSApp.keyWindow?.firstResponder,
                   (fr is NSTextField || fr is NSTextView) { return event }
                let key  = event.charactersIgnoringModifiers ?? ""
                let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
                // = key covers =, +, Cmd-=, Cmd-+ (shift changes = to + but same physical key)
                if key == "=" && !mods.contains(.option) && !mods.contains(.control) {
                    appState.statusLogFontOffset = min(8, appState.statusLogFontOffset + 1)
                    return nil   // consume
                }
                // - key covers -, Cmd-- (shift on - gives _, which is a different key code)
                if key == "-" && !mods.contains(.option) && !mods.contains(.control) && !mods.contains(.shift) {
                    appState.statusLogFontOffset = max(-4, appState.statusLogFontOffset - 1)
                    return nil   // consume
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = fontSizeMonitor { NSEvent.removeMonitor(monitor) }
        }
        #endif
        .sheet(isPresented: $appState.showExportConfirmation) {
            ExportConfirmationView()
                .environmentObject(appState)
        }
        .overlay {
            if appState.isExportingAudio {
                // frame(maxWidth/maxHeight: .infinity) ensures the ZStack fills the full
                // overlay bounds so the dialog is centered on the complete screen.
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - iPad Tab Layout (iOS only)

    #if os(iOS)

    /// Root content for iPad: TopBarView + song info + tab body + scrollbar + tab strip.
    @ViewBuilder private var iPadContent: some View {
        VStack(spacing: 0) {
            TopBarView(contentWidth: contentWidth)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(3)
                .zIndex(1)

            // Song title + info chips + zoom slider — visible in all tabs
            iPadSongInfoRow

            // Tab body — fills all remaining space
            Group {
                if iPadTab == .visuals {
                    VisualizerView(style: appState.selectedStyle)
                        .environmentObject(appState.playback)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture(count: 2) { appState.resetEffectsToDefaults() }
                } else if iPadTab == .log {
                    StatusBoxView(contentWidth: contentWidth, showHeader: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if iPadTab == .tracks {
                    iPadTracksBody
                } else {
                    iPadSongHistoryList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bar scrollbar — visible in all tabs; allows seeking and shows playback position
            iPadScrollbarRow

            // Bottom tab strip — always visible
            iPadTabStrip
        }
        .frame(minHeight: 500)
        .background(Color(white: 0.20))
        .preferredColorScheme(.dark)
        .onChange(of: iPadTab) { _, tab in
            // Only persist visuals/tracks — log and songs are session-transient
            if tab == .visuals || tab == .tracks {
                UserDefaults.standard.set(tab.rawValue, forKey: "iPadTabPersist")
            }
        }
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Tracks tab body — MIDI grid + StatusBoxView.
    /// Song info row and scrollbar are in iPadContent and shared across all tabs.
    @ViewBuilder private var iPadTracksBody: some View {
        VStack(spacing: 0) {
            // Track rows
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
                        onSeek: { step in appState.seekTo(step: step) },
                        contentWidth: contentWidth
                    )
                }
            }
            .frame(minHeight: 0)
            .clipped()
            .contentShape(Rectangle())
            .background(
                GeometryReader { geo in
                    Color(white: 0.18)
                        .onAppear      { trackRowsHeight = geo.size.height }
                        .onChange(of: geo.size.height) { h in trackRowsHeight = h }
                }
            )
            .padding(.top, 2)
            .layoutPriority(1)
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
                        appState.visibleBarOffset = max(0, min(appState.visibleBarOffset, total - clamped))
                    }
                    .onEnded { _ in
                        isPinching = false
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
                } else if appState.songState == nil && trackRowsHeight >= 300 {
                    Text("Press Generate or Play to create a song")
                        .font(.callout)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .clipped()

            // Hide the generation log on iPad mini landscape — not enough vertical room
            // to show all 7 track rows (441pt) plus the log without clipping the grid.
            if !isIPadMiniLandscape {
                StatusBoxView(contentWidth: contentWidth, showHeader: true)
                    .layoutPriority(0)
            }
        }
    }

    /// Song title + info chips + zoom slider — shown above all tab bodies.
    private var iPadSongInfoRow: some View {
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
            if iPadTab == .tracks {
                HStack(spacing: 5) {
                    Text("Bars:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize()
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
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color(white: 0.17))
    }

    /// Full-width bar scrollbar — shown below all tab bodies.
    /// Tracks tab: scrolls the visible window (visibleBarOffset).
    /// Other tabs: seeks the playhead (seekTo step).
    private var iPadScrollbarRow: some View {
        let totalBars = appState.songState?.frame.totalBars ?? 32
        let maxOffset = max(0, totalBars - appState.visibleBars)
        let isTracksTab = iPadTab == .tracks
        // Tracks tab: scroll the visible window. All other tabs: seek the playhead.
        let barBinding = isTracksTab
            ? Binding<Int>(
                get: { appState.visibleBarOffset },
                set: { appState.visibleBarOffset = max(0, min($0, maxOffset)) }
              )
            : Binding<Int>(
                get: { appState.playback.currentBar },
                set: { newBar in appState.seekTo(step: max(0, min(newBar, totalBars - 1)) * 16) }
              )
        return HStack(spacing: 6) {
            Text("Bar 1")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            HorizontalScrollBar(
                value: barBinding,
                total: totalBars,
                visible: isTracksTab ? appState.visibleBars : 1
            )
            Text("Bar \(totalBars)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
        .background(Color(white: 0.13))
    }

    private var iPadTabStrip: some View {
        HStack(spacing: 0) {
            iPadTabButton("Visuals", systemImage: "sparkles",            tab: .visuals)
            iPadTabButton("Log",     systemImage: "list.bullet",         tab: .log)
            iPadTabButton("Tracks",  systemImage: "slider.horizontal.3", tab: .tracks)
            iPadTabButton("Songs",   systemImage: "music.note.list",     tab: .songs)
        }
        .frame(height: 36)
        .background(Color(white: 0.10))
    }

    private func iPadTabButton(_ label: String, systemImage: String, tab: IPadTab) -> some View {
        Button { iPadTab = tab } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage).font(.system(size: 14))
                Text(label).font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(iPadTab == tab ? Color.white : Color(white: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var iPadSongHistoryList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.generationHistory, id: \.globalSeed) { song in
                        // oldest at top, newest at bottom — natural history order
                        Button { appState.loadFromGenerationHistory(song) } label: {
                            HStack(spacing: 8) {
                                if song.globalSeed == appState.songState?.globalSeed {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(.green).font(.system(size: 12))
                                } else {
                                    // Invisible spacer so title stays aligned
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 12))
                                        .hidden()
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(song.style.rawValue.capitalized)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.white.opacity(0.50))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .id(song.globalSeed)
                        .buttonStyle(.plain)
                        Divider().background(Color(white: 0.25))
                    }
                }
            }
            .onAppear {
                if let seed = appState.songState?.globalSeed {
                    proxy.scrollTo(seed, anchor: .center)
                }
            }
            .onChange(of: appState.songState?.globalSeed) { _, seed in
                if let seed { proxy.scrollTo(seed, anchor: .center) }
            }
        }
        .background(Color(white: 0.08))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #endif

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
        VStack(spacing: 10) {
            Text("Export Audio")
                .font(.headline)
            VStack(spacing: 6) {
                Text("Export to an M4A Audio file will take approximately \(songMinutes).")
                    .multilineTextAlignment(.center)
                Text("Alternatively, we can save a 60 second sample.")
                    .multilineTextAlignment(.center)
            }
            .frame(width: 300)
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    #if os(iOS)
                    .buttonStyle(.bordered)
                    #endif
                Button("Sample") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        appState.startExport(sampleMode: true)
                    }
                }
                #if os(iOS)
                .buttonStyle(.bordered)
                #endif
                Button("Full Song") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        appState.startExport(sampleMode: false)
                    }
                }
                .keyboardShortcut(.defaultAction)
                #if os(iOS)
                .buttonStyle(.borderedProminent)
                #endif
            }
        }
        #if os(iOS)
        .padding(.horizontal, 32)
        .padding(.vertical, 14)
        #else
        .padding(32)
        #endif
        .frame(width: 400)
        #if os(iOS)
        .presentationDetents([.height(240)])
        #endif
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

    // Canvas receives its correct settled size directly from SwiftUI layout with no
    // GeometryReader in the main layout path — eliminates the greedy-width inflation
    // that caused the thumb to overflow into the effects buttons area during evolve
    // transitions. The overlay GeometryReader is safe: it measures the Canvas frame
    // (already sized by frame(maxWidth:)) rather than competing for HStack space.
    var body: some View {
        let maxOffset = max(1, total - visible)
        let fraction  = min(1.0, CGFloat(visible) / CGFloat(max(1, total)))

        Canvas { ctx, size in
            let w      = size.width
            let thumbW = max(thumbMinWidth, w * fraction)
            let travel = max(0, w - thumbW)
            let thumbX = travel > 0 ? (CGFloat(value) / CGFloat(maxOffset)) * travel : 0
            let midY   = size.height / 2

            // Track
            ctx.fill(Path(roundedRect: CGRect(x: 0, y: midY - trackHeight / 2,
                                              width: w, height: trackHeight), cornerRadius: 3),
                     with: .color(.white.opacity(0.10)))
            // Thumb
            ctx.fill(Path(roundedRect: CGRect(x: thumbX, y: midY - trackHeight / 2,
                                              width: thumbW, height: trackHeight), cornerRadius: 3),
                     with: .color(.white.opacity(0.35)))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 14)
        // Drag-to-seek: overlay GeometryReader reads the Canvas's resolved width.
        // Overlay does not affect parent layout — Canvas already claimed the space.
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let w      = geo.size.width
                                let thumbW = max(thumbMinWidth, w * fraction)
                                let travel = max(0, w - thumbW)
                                guard travel > 0 else { return }
                                let newThumbX = max(0, min(drag.location.x - thumbW / 2, travel))
                                let newOffset = Int((newThumbX / travel) * CGFloat(maxOffset) + 0.5)
                                value = max(0, min(newOffset, maxOffset))
                            }
                    )
            }
        }
    }
}
