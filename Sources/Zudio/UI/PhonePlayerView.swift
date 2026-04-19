// PhonePlayerView.swift — Minimal player UI for iPhone.
// Apple Music-style layout: visuals on top, controls at the bottom within thumb reach.

import SwiftUI
import UniformTypeIdentifiers
import LinkPresentation
#if os(iOS)
import MessageUI
#endif

#if os(iOS)

private enum PhoneTab { case visuals, log, songs }

// MARK: - Main view

struct PhonePlayerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var playback: PlaybackEngine

    @State private var activeTab: PhoneTab = .visuals
    @State private var visualizerPaused: Bool = false   // tap Visuals tab while on it to stop animation
    @State private var showVisualsOffLabel = false       // "Visuals off" toast, auto-hides after 8s
    @State private var stopFlash       = false
    @State private var showInfo        = false
    @State private var showSleepPicker = false
    @State private var showFileImporter    = false
    @State private var showDocumentExporter = false
    @State private var pendingExportURL: URL? = nil

    // Gesture state
    @State private var dryTracks: Set<Int> = []

    // Haptic triggers (each toggles to fire sensoryFeedback)
    @State private var hapticImpactMedium = false
    @State private var hapticImpactLight  = false
    @State private var hapticImpactHeavy  = false
    @State private var hapticImpactSoft   = false
    @State private var hapticImpactRigid  = false
    @State private var hapticSelection    = false
    @State private var hapticSuccess      = false
    @State private var hapticWarning      = false

    var body: some View {
        // Outer GR respects safe areas — gives us reliable inset values.
        // Inner GR ignores safe areas — measures full screen for background/layout math.
        GeometryReader { safeGeo in
            let safeTop    = safeGeo.safeAreaInsets.top
            let safeBottom = safeGeo.safeAreaInsets.bottom
            let safeLead   = safeGeo.safeAreaInsets.leading

            GeometryReader { geo in
                let landscape = geo.size.width > geo.size.height
                if landscape {
                    landscapeLayout(geo: geo, safeTop: safeTop,
                                    safeBottom: safeBottom, safeLead: safeLead)
                } else {
                    portraitLayout(geo: geo, safeTop: safeTop, safeBottom: safeBottom)
                }
            }
            .ignoresSafeArea()
        }
        .background(Color.black.ignoresSafeArea())
        // Export confirmation sheet
        .sheet(isPresented: $appState.showExportConfirmation) {
            ExportConfirmationView()
                .environmentObject(appState)
        }
        // Export progress overlay
        .overlay {
            if appState.isExportingAudio {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 18) {
                        Text("Exporting Audio…")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ProgressView(value: appState.audioExportProgress)
                            .frame(width: 260)
                            .tint(.white)
                        Text(appState.audioExportFilename)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                        Button("Cancel") { appState.cancelExport() }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.white)
                            .tint(.white)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticImpactMedium)
        .sensoryFeedback(.impact(weight: .light),  trigger: hapticImpactLight)
        .sensoryFeedback(.impact(weight: .heavy),  trigger: hapticImpactHeavy)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: hapticImpactSoft)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: hapticImpactRigid)
        .sensoryFeedback(.selection, trigger: hapticSelection)
        .sensoryFeedback(.success,   trigger: hapticSuccess)
        .sensoryFeedback(.warning,   trigger: hapticWarning)
        .onChange(of: appState.isGenerating) { _, generating in
            if !generating { hapticSuccess.toggle() }
        }
    }

    // MARK: - Portrait (Apple Music style: art on top, controls below)

    private func portraitLayout(geo: GeometryProxy,
                                safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Visualizer / log / songs fills available space above controls
            bodyArea(geo: geo)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            songTitleRow
                .padding(.horizontal, 18)
                .padding(.top, 10)

            progressRow
                .padding(.horizontal, 18)
                .padding(.top, 4)

            modeRow
                .padding(.horizontal, 18)
                .padding(.top, 10)

            styleRow
                .padding(.horizontal, 18)
                .padding(.top, 6)

            transportRow
                .padding(.horizontal, 18)
                .padding(.top, 12)

            portraitActionRow
                .padding(.horizontal, 18)
                .padding(.top, 8)

            tabStrip
                .padding(.top, 10)
                .padding(.bottom, safeBottom)
        }
        .padding(.top, safeTop + 4)
    }

    // MARK: - Landscape

    private func landscapeLayout(geo: GeometryProxy,
                                 safeTop: CGFloat, safeBottom: CGFloat,
                                 safeLead: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Left controls column — 260pt wide, enough for Ambient / Motorik labels.
            // Extra top padding (≥16pt) clears the rounded display corners in landscape.
            VStack(spacing: 0) {
                songTitleRow
                    .frame(height: 46, alignment: .leading)   // stable height prevents layout jump on isGenerating change
                progressRow
                    .padding(.top, 4)
                modeRow
                    .padding(.top, 12)
                styleRow
                    .padding(.top, 12)
                transportRow
                    .padding(.top, 12)
                Spacer()
                landscapeActionRow
            }
            .frame(width: 260)
            .animation(.none, value: appState.isGenerating)
            .padding(.horizontal, 12)
            .padding(.top, max(safeTop, 16) + 8)
            .padding(.bottom, safeBottom + 4)
            .background(Color(white: 0.07))
            .padding(.leading, safeLead)

            // Right: body area + tab strip
            VStack(spacing: 0) {
                bodyArea(geo: geo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                tabStrip
                    .padding(.bottom, safeBottom)
            }
        }
    }

    // MARK: - Body area (visualizer, log, or songs)

    private func bodyArea(geo: GeometryProxy) -> some View {
        ZStack {
            switch activeTab {
            case .visuals:
                if !visualizerPaused {
                    VisualizerView(style: appState.selectedStyle)
                        .overlay(canvasGestureLayer)
                } else {
                    ZStack(alignment: .bottomLeading) {
                        Color(white: 0.04)   // animation off — TimelineView removed from hierarchy
                        if showVisualsOffLabel {
                            Text("Visuals off")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.green.opacity(0.80))
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                        }
                    }
                }
            case .log:
                StatusBoxView(contentWidth: geo.size.width, showHeader: true, largeHeader: true,
                              onReset: {
                                  appState.resetTrackDefaults()
                                  dryTracks.removeAll()
                                  hapticImpactHeavy.toggle()
                                  activeTab = .visuals
                              })
                    .background(Color(white: 0.06))
            case .songs:
                songHistoryList
            }
        }
    }

    // MARK: - Song title row

    private var songTitleRow: some View {
        HStack {
            if appState.isGenerating {
                ProgressView().tint(.white).scaleEffect(0.75)
                Text("Generating…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
            } else if let song = appState.songState {
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: song.style == .ambient ? 16 : 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(appState.selectedStyle.rawValue.capitalized)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.50))
                }
            } else {
                Text("No song loaded")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            Spacer()
        }
    }

    // MARK: - Progress scrubber

    private var progressRow: some View {
        let totalBars = appState.songState?.frame.totalBars ?? 1
        return VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { Double(playback.currentBar) / Double(max(1, totalBars)) },
                    set: { appState.seekTo(step: Int($0 * Double(totalBars)) * 16) }
                )
            )
            .tint(Color.white.opacity(0.65))
            .disabled(appState.songState == nil)

            HStack {
                Text(timeString(bar: playback.currentBar))
                Spacer()
                Text(timeString(bar: totalBars))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.35))
        }
    }

    private func timeString(bar: Int) -> String {
        let bpm = Double(appState.songState?.frame.tempo ?? 120)
        let seconds = Int(Double(bar) * 4.0 * 60.0 / bpm)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Mode selector

    private var modeRow: some View {
        HStack(spacing: 0) {
            modeButton(.song,    label: "Song")
            Divider().frame(height: 22)
            modeButton(.evolve,  label: "Evolve")
            Divider().frame(height: 22)
            modeButton(.endless, label: "Endless")
        }
        .font(.callout)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(Color(white: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Color(white: 0.4, opacity: 0.5), lineWidth: 0.5))
    }

    private func modeButton(_ mode: PlayMode, label: String) -> some View {
        Button {
            appState.playMode = mode
            hapticImpactLight.toggle()
        } label: {
            Text(label).fontWeight(.semibold)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(appState.playMode == mode ? kActiveModeBlue : .clear)
                .foregroundStyle(.white)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Style selector (custom buttons — avoids dark-on-dark segmented issue)

    private var styleRow: some View {
        HStack(spacing: 0) {
            styleButton(.ambient,  label: "Ambient")
            Divider().frame(height: 22)
            styleButton(.chill,    label: "Chill")
            Divider().frame(height: 22)
            styleButton(.kosmic,   label: "Kosmic")
            Divider().frame(height: 22)
            styleButton(.motorik,  label: "Motorik")
        }
        .font(.callout)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(Color(white: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Color(white: 0.4, opacity: 0.5), lineWidth: 0.5))
        .disabled(appState.playMode == .endless)
        .opacity(appState.playMode == .endless ? 0.5 : 1.0)
    }

    private func styleButton(_ style: MusicStyle, label: String) -> some View {
        Button {
            appState.selectedStyle = style
            hapticImpactLight.toggle()
        } label: {
            Text(label)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(appState.selectedStyle == style ? kActiveModeBlue : .clear)
                .foregroundStyle(.white)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transport (3 buttons: ⏮  ■/▶  ⏭)

    private var transportRow: some View {
        HStack(spacing: 52) {
            Button {
                switch appState.playMode {
                case .endless, .evolve:
                    appState.seekToStart()
                    hapticImpactLight.toggle()
                case .song:
                    appState.loadPreviousFromHistory()
                    hapticImpactLight.toggle()
                }
            } label: {
                Image(systemName: "backward.end.fill")
            }

            Button {
                if playback.isPlaying {
                    appState.stop()
                    withAnimation(.easeOut(duration: 0.1)) { stopFlash = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation { stopFlash = false }
                    }
                    hapticImpactSoft.toggle()
                } else {
                    appState.play()
                    hapticImpactMedium.toggle()
                }
            } label: {
                Group {
                    if playback.isPlaying {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(stopFlash ? .white : .red)
                            .scaleEffect(stopFlash ? 1.2 : 1.0)
                    } else {
                        Image(systemName: appState.isGenerating ? "hourglass" : "play.fill")
                            .foregroundStyle(.green)
                    }
                }
                .frame(width: 28)
            }
            .disabled(appState.isGenerating)

            Button {
                switch appState.playMode {
                case .endless: appState.skipToNextSong()
                case .evolve:  appState.skipEvolvePass()
                case .song:    appState.loadNextFromHistory()
                }
                hapticImpactMedium.toggle()
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .disabled(appState.songState == nil && appState.playMode == .song)
        }
        .font(.system(size: 36))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Export + Info row

    // MARK: - Portrait action row: [Export + Sleep] | Generate (centre) | Info
    private var portraitActionRow: some View {
        HStack(spacing: 8) {
            // Left group: Export + Sleep moon (equal total width to Info button on right)
            HStack(spacing: 4) {
                Button {
                    guard appState.songState != nil && !appState.isExportingAudio else { return }
                    appState.requestExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .opacity(appState.songState == nil || appState.isExportingAudio ? 0.40 : 1.0)

                Button { showSleepPicker = true } label: {
                    Image(systemName: appState.sleepTimerIsActive ? "moon.fill" : "moon")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
            .frame(width: 104)

            Button {
                appState.generateNew(thenPlay: true)
                hapticImpactMedium.toggle()
            } label: {
                Label("Generate", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .frame(maxWidth: .infinity)
            .disabled(appState.isGenerating)

            Button {
                showInfo = true
                hapticImpactLight.toggle()
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.bordered)
            .frame(width: 104)
        }
        .font(.callout)
        .sheet(isPresented: $showInfo) { PhoneInfoView() }
        .confirmationDialog("Sleep Timer", isPresented: $showSleepPicker, titleVisibility: .visible) {
            ForEach(SleepTimerDuration.allCases, id: \.self) { dur in
                Button(dur == appState.sleepTimerDuration ? "\(dur.rawValue) ✓" : dur.rawValue) {
                    appState.setSleepTimer(dur)
                }
            }
        }
    }

    // MARK: - Landscape action rows: Generate full-width, then Export + Info below
    private var landscapeActionRow: some View {
        VStack(spacing: 8) {
            Button {
                appState.generateNew(thenPlay: true)
                hapticImpactMedium.toggle()
            } label: {
                Label("Generate", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .frame(maxWidth: .infinity)
            .disabled(appState.isGenerating)

            HStack(spacing: 10) {
                Button {
                    guard appState.songState != nil && !appState.isExportingAudio else { return }
                    appState.requestExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .opacity(appState.songState == nil || appState.isExportingAudio ? 0.40 : 1.0)

                Button { showSleepPicker = true } label: {
                    Image(systemName: appState.sleepTimerIsActive ? "moon.fill" : "moon")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button {
                    showInfo = true
                    hapticImpactLight.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.callout)
        .sheet(isPresented: $showInfo) { PhoneInfoView() }
        .confirmationDialog("Sleep Timer", isPresented: $showSleepPicker, titleVisibility: .visible) {
            ForEach(SleepTimerDuration.allCases, id: \.self) { dur in
                Button(dur == appState.sleepTimerDuration ? "\(dur.rawValue) ✓" : dur.rawValue) {
                    appState.setSleepTimer(dur)
                }
            }
        }
    }

    // MARK: - Tab strip (Visuals / Log / Songs)

    private var tabStrip: some View {
        HStack(spacing: 0) {
            // Visuals button: tap while already on Visuals to stop animation (removes TimelineView).
            // Tap again (or navigate away and back) to resume.
            Button {
                if activeTab == .visuals {
                    visualizerPaused.toggle()
                    if visualizerPaused {
                        showVisualsOffLabel = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
                            withAnimation(.easeOut(duration: 0.6)) { showVisualsOffLabel = false }
                        }
                    }
                } else {
                    activeTab = .visuals
                    visualizerPaused = false
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "sparkles").font(.system(size: 15))
                    Text("Visuals").font(.system(size: 10))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(
                    activeTab == .visuals
                        ? (visualizerPaused ? Color(white: 0.38) : Color.white)
                        : Color(white: 0.5)
                )
            }
            .buttonStyle(.plain)
            tabButton("Log",   systemImage: "list.bullet",     tab: .log)
            tabButton("Songs", systemImage: "music.note.list", tab: .songs)
        }
        .frame(height: 44)
        .background(Color(white: 0.10))
    }

    private func tabButton(_ label: String, systemImage: String, tab: PhoneTab) -> some View {
        Button {
            activeTab = tab
            if tab == .visuals { visualizerPaused = false }   // always resume on explicit nav
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage).font(.system(size: 15))
                Text(label).font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(activeTab == tab ? Color.white : Color(white: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Song history list

    private var songHistoryList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    hapticImpactLight.toggle()
                    guard let song = appState.songState else { return }
                    Task.detached(priority: .userInitiated) {
                        let url = PhonePlayerView.buildShareURL(song: song)
                        await MainActor.run {
                            if let url {
                                pendingExportURL = url
                                showDocumentExporter = true
                            }
                        }
                    }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(appState.songState == nil)
                .sheet(isPresented: $showDocumentExporter) {
                    if let url = pendingExportURL {
                        DocumentExporter(url: url) {
                            appState.savedSongSeed = appState.songState?.globalSeed
                            showDocumentExporter = false
                        }
                    }
                }

                Button {
                    hapticImpactLight.toggle()
                    showFileImporter = true
                } label: {
                    Label("Load", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    hapticImpactLight.toggle()
                    guard let song = appState.songState else { return }
                    PhonePlayerView.presentShare(song: song)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(appState.songState == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(white: 0.10))

            Divider().overlay(Color(white: 0.25))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let songs = Array(appState.persistedHistory.reversed())
                        if songs.isEmpty {
                            Text("No songs generated yet")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                        } else {
                            ForEach(songs) { song in
                                Button {
                                    appState.loadFromPersistedSong(song)
                                    activeTab = .visuals
                                    hapticImpactLight.toggle()
                                } label: {
                                    HStack(spacing: 8) {
                                        if song.seed == appState.songState?.globalSeed {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundStyle(.green)
                                                .font(.system(size: 12))
                                        } else {
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
                                        if song.seed == appState.savedSongSeed {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.system(size: 15))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .id(song.seed)
                                .buttonStyle(.plain)
                                Divider().overlay(Color(white: 0.25))
                            }
                        }
                    }
                }
                .onAppear {
                    if let seed = appState.songState?.globalSeed {
                        proxy.scrollTo(seed, anchor: .center)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.06))
        }
        .background(Color(white: 0.06))
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType("com.zudio.song") ?? .data]
        ) { result in
            guard case .success(let url) = result else { return }
            _ = url.startAccessingSecurityScopedResource()
            appState.loadFromLogURL(url)
            url.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - Canvas gesture layer

    private var canvasGestureLayer: some View {
        CanvasGestureView(
            notes: playback.activeVisualizerNotes,
            onTapOrb:         { orbTrack in handleTapOrb(orbTrack) },
            onDoubleTapOrb:   { orbTrack in handleDoubleTapOrb(orbTrack) },
            onLongPressOrb:   { orbTrack in handleLongPressOrb(orbTrack) },
            onTapEmpty:       { handleTapEmpty() },
            onDoubleTapEmpty: { handleDoubleTapEmpty() },
            onLongPressEmpty: { handleLongPressEmpty() },
            onSwipeRight:     { handleSwipeRight() },
            onSwipeLeft:      { handleSwipeLeft() },
            onTwoFinger:      { handleTwoFinger() },
            onTapPoint:       { pt in appState.recordOrbTap(at: pt) }
        )
    }

    // MARK: - Gesture handlers

    private func handleTapOrb(_ trackIndex: Int) {
        // Single tap → 2-bar mute + instrument regen on release
        appState.toggleMute(trackIndex)
        hapticImpactLight.toggle()
        let bpm = Double(appState.songState?.frame.tempo ?? 120)
        let twoBarsSeconds = 2.0 * 4.0 * (60.0 / bpm)
        DispatchQueue.main.asyncAfter(deadline: .now() + twoBarsSeconds) {
            if appState.muteState[trackIndex] {
                appState.toggleMute(trackIndex)
                appState.regenInstrument(forTrack: trackIndex)
            }
        }
    }

    private func handleDoubleTapOrb(_ trackIndex: Int) {
        // Double tap → 2-bar solo, auto-releases
        let wasSoloed = appState.soloState[trackIndex]
        appState.toggleSolo(trackIndex)
        hapticImpactMedium.toggle()
        guard !wasSoloed else { return }
        let bpm = Double(appState.songState?.frame.tempo ?? 120)
        let twoBarsSeconds = 2.0 * 4.0 * (60.0 / bpm)
        DispatchQueue.main.asyncAfter(deadline: .now() + twoBarsSeconds) {
            if appState.soloState[trackIndex] { appState.toggleSolo(trackIndex) }
        }
    }

    private func handleLongPressOrb(_ trackIndex: Int) {
        if dryTracks.contains(trackIndex) {
            appState.restoreDefaultEffects(forTrack: trackIndex)
            dryTracks.remove(trackIndex)
            hapticSuccess.toggle()
        } else {
            appState.clearAllEffects(forTrack: trackIndex)
            dryTracks.insert(trackIndex)
            hapticImpactHeavy.toggle()
        }
    }

    private func handleTapEmpty() {
        // Filter sweep — same effect as two-finger gesture, but single tap on empty canvas
        playback.triggerGlobalFilterSweep()
        hapticImpactMedium.toggle()
    }

    private func handleDoubleTapEmpty() {
        appState.regenInstrument(forTrack: kTrackLead1)
        appState.regenInstrument(forTrack: kTrackRhythm)
        hapticImpactLight.toggle()
    }

    private func handleLongPressEmpty() {
        appState.regenRandomNonDrumTrack()
        hapticImpactHeavy.toggle()
    }

    private func handleSwipeRight() {
        appState.regenInstrument(forTrack: kTrackRhythm)
        appState.regenInstrument(forTrack: kTrackPads)
        hapticSelection.toggle()
    }

    private func handleSwipeLeft() {
        appState.regenInstrument(forTrack: kTrackLead1)
        appState.regenInstrument(forTrack: kTrackLead2)
        hapticImpactSoft.toggle()
    }

    private func handleTwoFinger() {
        appState.regenInstrument(forTrack: kTrackBass)
        appState.regenInstrument(forTrack: kTrackDrums)
        hapticImpactRigid.toggle()
    }
}

// MARK: - Info sheet

private struct PhoneInfoView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Custom header — no NavigationStack overhead
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 17))
                    .padding(.trailing, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Zudio wordmark logo with text fallback
                    Group {
                        if let url = Bundle.main.url(forResource: "zudio-logo", withExtension: "png"),
                           let data = try? Data(contentsOf: url),
                           let uiImg = UIImage(data: data) {
                            Image(uiImage: uiImg)
                                .resizable().scaledToFit()
                                .frame(width: 140)
                        } else {
                            Text("Zudio")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                    Text("Generative music · v1.0")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    Text("Zudio was coded with AI, inspired by Brian Eno, Moby, St Germain, Jean-Michel Jarre, Tangerine Dream, Kraftwerk & Electric Buddha Band.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Each style is driven by rules built by analyzing songs in that genre. Rules were iteratively refined with Claude until it sounded like music!")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                    Text("Tap or swipe to change instruments. Save, Load or Share songs from the Song list view. Log view shows the rules firing behind the scenes.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                    Text("Available for iPad Mac with track view and MIDI export.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                    Text("Source code and design docs on Github")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                        .padding(.top, 5)
                    Link("github.com/ZUrlocker1/Zudio",
                         destination: URL(string: "https://github.com/ZUrlocker1/Zudio")!)
                        .font(.system(size: 16))
                        .padding(.top, 1)
                    Text("© 2026 Zack Urlocker")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                        .padding(.top, 3)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

}

// MARK: - Canvas gesture recognizer (UIViewRepresentable)

struct CanvasGestureView: UIViewRepresentable {
    var notes: [VisualizerNote]
    var onTapOrb:          (Int) -> Void
    var onDoubleTapOrb:    (Int) -> Void
    var onLongPressOrb:    (Int) -> Void
    var onTapEmpty:        () -> Void
    var onDoubleTapEmpty:  () -> Void
    var onLongPressEmpty:  () -> Void
    var onSwipeRight:      () -> Void
    var onSwipeLeft:       () -> Void
    var onTwoFinger:       () -> Void
    var onTapPoint:        (CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let c = context.coordinator

        let doubleTap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)

        let longPress = UILongPressGestureRecognizer(target: c, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        view.addGestureRecognizer(longPress)

        let swipeRight = UISwipeGestureRecognizer(target: c, action: #selector(Coordinator.handleSwipeRight))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        let swipeLeft = UISwipeGestureRecognizer(target: c, action: #selector(Coordinator.handleSwipeLeft))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let pinch = UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var parent: CanvasGestureView

        init(parent: CanvasGestureView) { self.parent = parent }

        // MARK: Hit test — mirrors VisualizerView position formula exactly

        private func hitOrb(at point: CGPoint, in view: UIView) -> Int? {
            let size = CGSize(width: view.bounds.width, height: view.bounds.height)
            let now  = Date()
            for orb in parent.notes.reversed() {
                let age      = now.timeIntervalSince(orb.birthDate)
                let lifetime = orbLifetime(orb)
                guard age < lifetime else { continue }
                let pos    = orbPosition(orb: orb, age: age, size: size, now: now)
                let radius = orbRadius(orb) * 1.5
                let dx = point.x - pos.x
                let dy = point.y - pos.y
                if dx*dx + dy*dy <= radius*radius { return orb.trackIndex }
            }
            return nil
        }

        // MARK: Mirror of VisualizerView helpers (kept in sync)

        private func orbLifetime(_ orb: VisualizerNote) -> Double {
            if orb.durationSteps <= 4  { return 1.6 }
            if orb.durationSteps <= 8  { return 3.0 }
            if orb.durationSteps <= 16 { return 5.0 }
            return 7.0
        }

        private func orbRadius(_ orb: VisualizerNote) -> Double {
            let base = 12.0 + Double(orb.velocity) / 127.0 * 16.0
            switch orb.durationSteps {
            case ...4:  return base
            case ...8:  return base * 1.4
            case ...16: return base * 1.8
            default:    return base * 2.2
            }
        }

        private func trackHome(trackIndex: Int, wallTime: Double) -> (x: Double, y: Double) {
            switch trackIndex {
            case kTrackLead1:
                return (0.50 + sin(wallTime * 0.196 + 0.0) * 0.22,
                        0.30 + cos(wallTime * 0.146 + 1.2) * 0.18)
            case kTrackLead2:
                return (0.45 + sin(wallTime * 0.173 + 2.1) * 0.20,
                        0.35 + cos(wallTime * 0.239 + 0.8) * 0.17)
            case kTrackPads:
                return (0.50 + sin(wallTime * 0.105 + 4.2) * 0.28,
                        0.48 + cos(wallTime * 0.089 + 3.5) * 0.24)
            case kTrackRhythm:
                return (0.55 + sin(wallTime * 0.251 + 1.7) * 0.18,
                        0.52 + cos(wallTime * 0.188 + 5.1) * 0.16)
            case kTrackTexture:
                return (0.40 + sin(wallTime * 0.148 + 3.3) * 0.28,
                        0.45 + cos(wallTime * 0.271 + 2.7) * 0.20)
            case kTrackBass:
                return (0.50 + sin(wallTime * 0.120 + 5.5) * 0.24,
                        0.70 + cos(wallTime * 0.201 + 4.0) * 0.12)
            case kTrackDrums:
                return (0.62 + sin(wallTime * 0.238 + 0.5) * 0.20,
                        0.68 + cos(wallTime * 0.136 + 6.2) * 0.14)
            default:
                return (0.50, 0.50)
            }
        }

        private func orbPosition(orb: VisualizerNote, age: Double, size: CGSize, now: Date) -> CGPoint {
            let wallTime = now.timeIntervalSinceReferenceDate
            let (homeX, homeY) = trackHome(trackIndex: orb.trackIndex, wallTime: wallTime)
            let pitchNorm   = clamp((Double(orb.note) - 36.0) / 60.0, 0.0, 1.0)
            let pitchOffset = (0.5 - pitchNorm) * 0.30
            let (driftX, driftY): (Double, Double)
            switch orb.trackIndex {
            case kTrackPads:
                driftX = sin(Double(orb.note % 7) * 0.9) * age * 5.0
                driftY = -age * 2.5
            case kTrackRhythm:
                driftX = sin(Double(orb.note % 5) * 1.1) * age * 2.5
                driftY = cos(Double(orb.velocity % 5) * 0.8) * age * 1.5
            case kTrackTexture:
                driftX = (Double(orb.note % 7) - 3.0) * age * 8.0
                driftY = sin(Double(orb.velocity % 3) * 1.2) * age * 3.0
            default:
                driftX = (Double(orb.note % 7) - 3.0) * 0.03 * age * 10.0
                driftY = (Double(orb.velocity % 5) - 2.0) * 0.02 * age * 8.0 - age * 3.0
            }
            let x = size.width  * clamp(homeX + driftX / size.width,  0.02, 0.98)
            let y = size.height * clamp(homeY + pitchOffset + driftY / size.height, 0.02, 0.98)
            return CGPoint(x: x, y: y)
        }

        private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
            max(lo, min(hi, v))
        }

        // MARK: Gesture handlers

        @objc func handleSingleTap(_ gr: UITapGestureRecognizer) {
            guard gr.state == .ended else { return }
            let pt = gr.location(in: gr.view)
            parent.onTapPoint(pt)
            if let track = hitOrb(at: pt, in: gr.view!) {
                parent.onTapOrb(track)
            } else {
                parent.onTapEmpty()
            }
        }

        @objc func handleDoubleTap(_ gr: UITapGestureRecognizer) {
            guard gr.state == .ended else { return }
            let pt = gr.location(in: gr.view)
            parent.onTapPoint(pt)
            if let track = hitOrb(at: pt, in: gr.view!) {
                parent.onDoubleTapOrb(track)
            } else {
                parent.onDoubleTapEmpty()
            }
        }

        @objc func handleLongPress(_ gr: UILongPressGestureRecognizer) {
            guard gr.state == .began else { return }
            let pt = gr.location(in: gr.view)
            if let track = hitOrb(at: pt, in: gr.view!) {
                parent.onLongPressOrb(track)
            } else {
                parent.onLongPressEmpty()
            }
        }

        @objc func handleSwipeRight() { parent.onSwipeRight() }
        @objc func handleSwipeLeft()  { parent.onSwipeLeft() }

        @objc func handlePinch(_ gr: UIPinchGestureRecognizer) {
            guard gr.state == .began else { return }
            parent.onTwoFinger()
        }
    }
}

private class ZudioShareItem: NSObject, UIActivityItemSource {
    let item: Any
    let title: String

    init(item: Any, title: String) { self.item = item; self.title = title; super.init() }

    func activityViewControllerPlaceholderItem(_ vc: UIActivityViewController) -> Any { item }
    func activityViewController(_ vc: UIActivityViewController, itemForActivityType type: UIActivity.ActivityType?) -> Any? { item }
    func activityViewControllerLinkMetadata(_ vc: UIActivityViewController) -> LPLinkMetadata? {
        // iOS ignores iconProvider/imageProvider for custom file types — only title is used.
        let meta = LPLinkMetadata()
        meta.title = title
        return meta
    }
}

private final class MessageComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    static var retainKey = 0
    func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                       didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}

// MARK: - Share helpers

extension PhonePlayerView {
    static func buildShareURL(song: SongState) -> URL? {
        SongLogExporter.shareURL(for: song)
    }

    /// Opens Messages compose directly with the .zudio file attached.
    static func presentShare(song: SongState) {
        Task.detached(priority: .userInitiated) {
            let url = buildShareURL(song: song)
            await MainActor.run {
                guard let url,
                      MFMessageComposeViewController.canSendText(),
                      MFMessageComposeViewController.canSendAttachments(),
                      let top = shareTopViewController() else { return }
                let mc = MFMessageComposeViewController()
                mc.addAttachmentURL(url, withAlternateFilename: url.lastPathComponent)
                let delegate = MessageComposeDelegate()
                mc.messageComposeDelegate = delegate
                objc_setAssociatedObject(mc, &MessageComposeDelegate.retainKey, delegate,
                                         .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                top.present(mc, animated: true)
            }
        }
    }

    private static func shareTopViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              let root = window.rootViewController else { return nil }
        var top = root
        while let pvc = top.presentedViewController { top = pvc }
        return top
    }
}

// MARK: - Document exporter (Save → Files picker so file appears in Recents)

struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL
    var onSuccess: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSuccess: onSuccess) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSuccess: () -> Void
        init(onSuccess: @escaping () -> Void) { self.onSuccess = onSuccess }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onSuccess()
        }
    }
}

#endif
