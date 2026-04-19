// TopBarView.swift — compact 3-row header
// Row 1: blank spacer | Row 2: transport + controls | Row 3: Export Audio + Save Song

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

// Styled to match macOS bordered Button appearance with a press-state highlight.
private extension View {
    func transportButtonStyle(isDown: Bool) -> some View {
        self
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDown ? Color(white: 0.28) : Color(white: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(white: 0.4, opacity: 0.5), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
    }
}

// Reference-type repeater so gesture closures always see the live timer reference,
// avoiding the SwiftUI stale-closure problem that caused post-release drift.
private final class HoldRepeater: ObservableObject {
    private var timer: Timer?
    private var holding = false

    /// Call on press. Fires `initial` immediately, then after `delay` seconds starts
    /// repeating `step` every `interval` seconds. Stops automatically when `atLimit` returns true.
    func start(initial: @escaping () -> Void,
               step: @escaping () -> Void,
               atLimit: @escaping () -> Bool,
               delay: Double = 0.45,
               interval: Double = 0.25) {
        guard !holding else { return }
        holding = true
        initial()
        guard !atLimit() else { holding = false; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.holding else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] t in
                guard let self, self.holding else { t.invalidate(); return }
                if atLimit() { self.stop(); return }
                step()
            }
        }
    }

    func stop() {
        holding = false
        timer?.invalidate()
        timer = nil
    }
}

/// Highlight colour for the active Song / Evolve / Endless mode button.
let kActiveModeBlue = Color(red: 0.18, green: 0.42, blue: 0.78)

// Platform-adaptive spacing and sizing — avoids duplicate view code.
#if os(iOS)
private let kMainHStackSpacing: CGFloat        = 4
private let kGenerateHStackSpacing: CGFloat    = 6
private let kRightBlockHStackSpacing: CGFloat  = 6
private let kLogoFrameWidth: CGFloat           = 100   // 2:1 logo → 50pt tall; fits cleanly
private let kModePickerWidth: CGFloat          = 218   // Song/Evolve/Endless — text-only now so 73pt each is fine
private let kStylePickerWidth: CGFloat         = 220   // Ambient/Chill/Kosmic/Motorik — 55pt each
private let kStyleVStackWidth: CGFloat         = 220   // must equal picker width so picker doesn't overflow into mood/key column
private let kActionButtonWidth: CGFloat        = 100
private let kMoodPickerWidth: CGFloat          = 100
private let kKeyPickerWidth: CGFloat           = 90
private let kBPMFieldWidth: CGFloat            = 40
private let kHelpButtonWidth: CGFloat          = 44
#else
private let kMainHStackSpacing: CGFloat        = 10
private let kGenerateHStackSpacing: CGFloat    = 14
private let kRightBlockHStackSpacing: CGFloat  = 20
private let kLogoFrameWidth: CGFloat           = 200
private let kModePickerWidth: CGFloat          = 219   // Song(66)+Evolve(71)+Endless(81)+separators
private let kModeSongWidth: CGFloat            = 66    // 18pt narrower than equal-split 84pt
private let kModeEvolveWidth: CGFloat          = 71    // 13pt narrower than equal-split 84pt
private let kModeEndlessWidth: CGFloat         = 81    // 3pt narrower than original 84pt
private let kStylePickerWidth: CGFloat         = 245
private let kStyleVStackWidth: CGFloat         = 210
private let kActionButtonWidth: CGFloat        = 128
private let kMoodPickerWidth: CGFloat          = 110
private let kKeyPickerWidth: CGFloat           = 105
private let kBPMFieldWidth: CGFloat            = 48
private let kHelpButtonWidth: CGFloat          = 52
#endif

struct TopBarView: View {
    /// Passed from ContentView so portrait/landscape/compact layout switches correctly.
    /// Defaults to 1200 so both macOS and iOS start in wide-layout mode before first render.
    var contentWidth: CGFloat = 1200

    @EnvironmentObject var appState: AppState
    @State private var showHelp  = false
    @State private var showAbout = false
    @State private var stopFlash = false
    @State private var saveFlash = false
    #if os(iOS)
    @State private var showFileImporter  = false
    @State private var showSleepPicker   = false
    #endif

    @StateObject private var reverseRepeater = HoldRepeater()
    @StateObject private var forwardRepeater = HoldRepeater()

    // Tracks button press state for highlight; updated by MousePressTracker callbacks
    @State private var reverseIsDown = false
    @State private var forwardIsDown = false

    /// Shared BPM text binding used by both the iOS and macOS tempo fields.
    /// Empty string means Auto (nil override); valid integers are clamped to [20, 200].
    private var tempoBinding: Binding<String> {
        Binding(
            get: { appState.tempoOverride.map { String($0) } ?? "" },
            set: { s in
                let t = s.trimmingCharacters(in: .whitespaces)
                if t.isEmpty {
                    appState.tempoOverride = nil
                } else if let v = Int(t) {
                    appState.tempoOverride = max(20, min(200, v))
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: small top margin
            Color(white: 0.15).frame(height: 8)

            // Main controls block
            HStack(alignment: .center, spacing: kMainHStackSpacing) {

                // Logo — wide macOS (≥1150): left of transport; compact macOS (<1150): inside transport VStack
                //         iOS landscape (≥900): left of transport; iOS portrait (<900): inside transport VStack
                #if os(iOS)
                if contentWidth >= 900 {
                    LogoAreaView(contentWidth: contentWidth)
                    Divider()
                }
                #else
                if contentWidth >= 1150 {
                    LogoAreaView()
                    Divider()
                }
                #endif

                // Transport — ⏮ ◀ ▶ ■ ▶ ⏭ + mode selector below
                VStack(spacing: 0) {
                #if os(iOS)
                if contentWidth < 900 {
                    LogoAreaView(contentWidth: contentWidth)
                        .padding(.bottom, 2)
                }
                #endif
                #if os(macOS)
                if contentWidth < 1150 {
                    LogoAreaView(compact: true)
                        .padding(.bottom, 4)
                }
                #endif
                HStack(spacing: 4) {
                    // Jump to start
                    Button(action: { appState.seekToStart() }) {
                        Image(systemName: "backward.end.fill")
                            #if os(iOS)
                            .foregroundStyle(Color(white: 0.78))
                            #else
                            .foregroundStyle(.primary)
                            #endif
                    }
                    .disabled(appState.songState == nil)
                    .help("Go to start (rewind to bar 1)")

                    // Reverse: tap = -1 bar, hold = -2 bars per tick, stops at bar 0
                    #if os(macOS)
                    Image(systemName: "backward.fill")
                        .transportButtonStyle(isDown: reverseIsDown)
                        .overlay(
                            MousePressTracker(
                                onPress: {
                                    guard appState.songState != nil else { return }
                                    reverseIsDown = true
                                    reverseRepeater.start(
                                        initial:  { appState.seekBackOneBar() },
                                        step:     { appState.seekBackTwoBars() },
                                        atLimit:  { appState.playback.currentBar <= 0 }
                                    )
                                },
                                onRelease: {
                                    reverseIsDown = false
                                    reverseRepeater.stop()
                                }
                            )
                        )
                        .help("Back 1 bar (hold: back 2 bars repeatedly)")
                    #else
                    Button(action: { appState.seekBackOneBar() }) {
                        Image(systemName: "backward.fill")
                            .foregroundStyle(Color(white: 0.78))
                    }
                    .disabled(appState.songState == nil)
                    .help("Back 1 bar")
                    #endif

                    // Play / Stop — single button that toggles between states
                    Button(action: {
                        if appState.playback.isPlaying {
                            appState.stop()
                            withAnimation(.easeOut(duration: 0.1)) { stopFlash = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                withAnimation { stopFlash = false }
                            }
                        } else {
                            appState.play()
                        }
                    }) {
                        Group {
                            if appState.playback.isPlaying {
                                Image(systemName: "stop.fill")
                                    .foregroundStyle(stopFlash ? .white : .red)
                                    .scaleEffect(stopFlash ? 1.2 : 1.0)
                            } else {
                                Image(systemName: appState.isGenerating ? "hourglass" : "play.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(width: 14, alignment: .center)
                    }
                    .disabled(appState.isGenerating)
                    .help(appState.playback.isPlaying ? "Stop" : "Play (auto-generates if no song)")

                    // Fast forward: tap = +1 bar, hold = +2 bars per tick, stops at last bar
                    #if os(macOS)
                    Image(systemName: "forward.fill")
                        .transportButtonStyle(isDown: forwardIsDown)
                        .overlay(
                            MousePressTracker(
                                onPress: {
                                    guard appState.songState != nil else { return }
                                    forwardIsDown = true
                                    forwardRepeater.start(
                                        initial:  { appState.seekForwardOneBar() },
                                        step:     { appState.seekForwardTwoBars() },
                                        atLimit:  {
                                            guard let s = appState.songState else { return true }
                                            return appState.playback.currentBar >= s.frame.totalBars - 1
                                        }
                                    )
                                },
                                onRelease: {
                                    forwardIsDown = false
                                    forwardRepeater.stop()
                                }
                            )
                        )
                        .help("Forward 1 bar (hold: forward 2 bars repeatedly)")
                    #else
                    Button(action: { appState.seekForwardOneBar() }) {
                        Image(systemName: "forward.fill")
                            .foregroundStyle(Color(white: 0.78))
                    }
                    .disabled(appState.songState == nil)
                    .help("Forward 1 bar")
                    #endif

                    // Next song/pass — always generates a new song in Song mode
                    Button(action: {
                        if appState.playMode == .endless {
                            appState.skipToNextSong()
                        } else if appState.playMode == .evolve {
                            appState.skipEvolvePass()
                        } else {
                            appState.loadNextFromHistory()
                        }
                    }) {
                        Image(systemName: "forward.end.fill")
                            #if os(iOS)
                            .foregroundStyle(Color(white: 0.78))
                            #else
                            .foregroundStyle(.primary)
                            #endif
                    }
                    .disabled(appState.songState == nil)
                    .help(appState.playMode == .endless ? "Skip to next song" :
                          appState.playMode == .evolve  ? "Skip to next song" :
                          "Go to end (stops playback)")
                }
                #if os(iOS)
                .font(.system(size: 29))
                .padding(.bottom, 22)
                #else
                .font(.callout)
                .padding(.vertical, 8)
                .background(FirstMouseFix())
                #endif

                // Mode selector: Song / Evolve / Endless — font/height matches Reset button; blue active = effects buttons
                HStack(spacing: 0) {
                    Button { appState.playMode = .song } label: {
                        Group {
                            #if os(iOS)
                            (Text("So") + Text("n").underline() + Text("g")).fontWeight(.semibold)
                            #else
                            HStack(spacing: 4) {
                                Image(systemName: "music.note")
                                (Text("So") + Text("n").underline() + Text("g")).fontWeight(.semibold)
                            }
                            #endif
                        }
                        #if os(macOS)
                        .frame(width: kModeSongWidth)
                        #else
                        .frame(maxWidth: .infinity)
                        #endif
                        .frame(height: 22)
                        .background(appState.playMode == .song ? kActiveModeBlue : Color.clear)
                        .foregroundStyle(appState.playMode == .song ? Color.white : Color.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle()
                        .fill(Color(white: 0.4, opacity: 0.5))
                        .frame(width: 0.5, height: 22)
                    Button { appState.playMode = .evolve } label: {
                        Group {
                            #if os(iOS)
                            (Text("E") + Text("v").underline() + Text("olve")).fontWeight(.semibold)
                            #else
                            HStack(spacing: 4) {
                                Image(systemName: "waveform")
                                (Text("E") + Text("v").underline() + Text("olve")).fontWeight(.semibold)
                            }
                            #endif
                        }
                        #if os(macOS)
                        .frame(width: kModeEvolveWidth)
                        #else
                        .frame(maxWidth: .infinity)
                        #endif
                        .frame(height: 22)
                        .background(appState.playMode == .evolve ? kActiveModeBlue : Color.clear)
                        .foregroundStyle(appState.playMode == .evolve ? Color.white : Color.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle()
                        .fill(Color(white: 0.4, opacity: 0.5))
                        .frame(width: 0.5, height: 22)
                    Button { appState.playMode = .endless } label: {
                        Group {
                            #if os(iOS)
                            (Text("En") + Text("d").underline() + Text("less")).fontWeight(.semibold)
                            #else
                            HStack(spacing: 4) {
                                Image(systemName: "infinity")
                                (Text("En") + Text("d").underline() + Text("less")).fontWeight(.semibold)
                            }
                            #endif
                        }
                        #if os(macOS)
                        .frame(width: kModeEndlessWidth)
                        #else
                        .frame(maxWidth: .infinity)
                        #endif
                        .frame(height: 22)
                        .background(appState.playMode == .endless ? kActiveModeBlue : Color.clear)
                        .foregroundStyle(appState.playMode == .endless ? Color.white : Color.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .font(.callout)
                .frame(width: kModePickerWidth)
                .background(Color(white: 0.18))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color(white: 0.4, opacity: 0.5), lineWidth: 0.5))
                .padding(.bottom, 5)
                .onChange(of: appState.playMode) { _ in
                    appState.platformHost?.dismissKeyboard()
                }
                #if os(macOS)
                // Compact mode: Help + About sit below the mode selector instead of the right edge
                if contentWidth < 1150 {
                    HStack(spacing: 8) {
                        Button { showHelp  = true } label: { (Text("H").underline() + Text("elp")).frame(width: kHelpButtonWidth) }
                        Button { showAbout = true } label: { Text("About").frame(width: kHelpButtonWidth) }
                    }
                    .font(.callout)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                }
                #endif
                } // end VStack (transport + mode selector)
                #if os(iOS)
                .padding(.horizontal, 6)
                #endif

                Divider()

                // Flex gap between transport and action buttons — expands up to 48pt on wide displays,
                // collapses to 0 on compact windows so the small-screen layout is unchanged.
                Spacer(minLength: 0).frame(maxWidth: 0)

                // Generate / Save Song / Export Audio stacked left; selectors + Reset right.
                HStack(alignment: .center, spacing: kGenerateHStackSpacing) {

                    // Left column: three action buttons, all same width
                    VStack(spacing: 6) {
                        Button(action: { appState.generateNew(thenPlay: true) }) {
                            Label {
                                (Text("G").underline() + Text("enerate"))
                                    .fontWeight(.semibold)
                            } icon: { Image(systemName: "bolt.fill") }
                            .frame(width: kActionButtonWidth, alignment: .center)
                        }
                        .disabled(appState.isGenerating)
                        .keyboardShortcut("g", modifiers: .command)
                        .help("Generate a new song (⌘G)")

                        Button(action: { appState.saveMIDI() }) {
                            Label {
                                #if os(iOS)
                                Text("Save").fontWeight(.semibold)
                                #else
                                (Text("S").underline() + Text("ave Song"))
                                    .fontWeight(.semibold)
                                #endif
                            } icon: {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundStyle(saveFlash ? .white : .primary)
                                    .scaleEffect(saveFlash ? 1.2 : 1.0)
                            }
                            .frame(width: kActionButtonWidth, alignment: .center)
                        }
                        .disabled(appState.songState == nil)
                        .keyboardShortcut("s", modifiers: .command)
                        .help("Save multi-track MIDI to ~/Downloads/ (S or ⌘S)")

                        Button(action: {
                            #if os(iOS)
                            showFileImporter = true
                            #else
                            appState.loadFromLog()
                            #endif
                        }) {
                            Label {
                                #if os(iOS)
                                Text("Load").fontWeight(.semibold)
                                #else
                                (Text("L").underline() + Text("oad Song"))
                                    .fontWeight(.semibold)
                                #endif
                            } icon: { Image(systemName: "doc.text") }
                            .frame(width: kActionButtonWidth, alignment: .center)
                        }
                        .disabled(appState.isGenerating)
                        .keyboardShortcut("l", modifiers: .command)
                        .help("Reload a song from a saved .txt log file (⌘L)")

                        Button(action: { appState.requestExport() }) {
                            Label {
                                #if os(iOS)
                                Text("Export").fontWeight(.semibold)
                                #else
                                (Text("E").underline() + Text("xport Audio"))
                                    .fontWeight(.semibold)
                                #endif
                            } icon: { Image(systemName: "waveform") }
                            .frame(width: kActionButtonWidth, alignment: .center)
                        }
                        .disabled(appState.songState == nil || appState.isExportingAudio)
                        .keyboardShortcut("e", modifiers: .command)
                        .help("Export song to M4A audio file in ~/Downloads/ (⌘E)")
                    }
                    #if os(iOS)
                    .buttonStyle(.bordered)
                    // All 11-inch iPads in landscape (mini ≈1133pt, Air/Pro 11" ≈1180–1195pt):
                    // slim down buttons 4pt vertically so 7 MIDI track rows aren't clipped.
                    // 13-inch iPads (≈1366pt+) have enough vertical room and keep .regular.
                    .environment(\.controlSize, (contentWidth >= 900 && contentWidth < 1220) ? .small : .regular)
                    #endif

                    // Right block — iOS: VStack (style+reset row, then mood/key/bpm row)
                    //              — macOS: side-by-side HStack (style column | selectors column)
                    #if os(iOS)
                    VStack(alignment: .leading, spacing: 6) {
                        // Row 1: style segmented picker fills available width; Reset at trailing end
                        HStack(spacing: 8) {
                            Picker("", selection: $appState.selectedStyle) {
                                (Text("A").underline() + Text("mbient")).tag(MusicStyle.ambient)
                                (Text("C").underline() + Text("hill")).tag(MusicStyle.chill)
                                (Text("K").underline() + Text("osmic")).tag(MusicStyle.kosmic)
                                (Text("M").underline() + Text("otorik")).tag(MusicStyle.motorik)
                            }
                            .pickerStyle(.segmented)
                            .tint(Color.gray)
                            // iPad mini portrait (<800pt): 220pt with 10pt font so "Ambient" fits
                            // without truncation (11pt + default insets would overflow the segment).
                            .font(.system(size: contentWidth < 800 ? 10 : 11))
                            .frame(width: contentWidth < 800 ? 220 : 260)
                            .disabled(appState.playMode == .endless)
                            .opacity(appState.playMode == .endless ? 0.5 : 1.0)

                            Button(action: { appState.resetTrackDefaults() }) {
                                Label {
                                    (Text("R").underline() + Text("eset")).fontWeight(.semibold)
                                } icon: { Image(systemName: "arrow.counterclockwise") }
                                .frame(width: 80, alignment: .center)
                            }
                            .keyboardShortcut("r", modifiers: .command)
                            .help("Reset to clean state: clear song, restore defaults, re-detect audio (⌘R)")
                            .buttonStyle(.bordered)
                        }

                        // Row 2: Mood / Key / BPM overrides in a single flat HStack
                        HStack(spacing: 8) {
                            HStack(spacing: 0) {
                                Text("Mood").font(.callout).foregroundStyle(.white.opacity(0.7)).fixedSize()
                                Picker("Mood", selection: $appState.moodOverride) {
                                    Text("Auto").tag(Optional<Mood>.none)
                                    ForEach(Mood.allCases, id: \.self) { m in
                                        Text(m.rawValue.capitalized).tag(Optional(m))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: kMoodPickerWidth)
                                .padding(.leading, -4)  // tighten: menu picker has ~8pt internal leading inset
                            }

                            HStack(spacing: 0) {
                                Text("Key").font(.callout).foregroundStyle(.white.opacity(0.7)).fixedSize()
                                Picker("Key", selection: $appState.keyOverride) {
                                    Text("Auto").tag(Optional<String>.none)
                                    ForEach(kAllKeys, id: \.self) { k in
                                        Text(k).tag(Optional(k))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: kKeyPickerWidth)
                                .padding(.leading, -4)  // tighten: menu picker has ~8pt internal leading inset
                            }

                            Text("BPM").foregroundStyle(.white).fixedSize()
                            TextField("Auto", text: tempoBinding)
                            .frame(width: kBPMFieldWidth)
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.leading, 5)
                    #else
                    HStack(alignment: .top, spacing: kRightBlockHStackSpacing) {

                        // Left column: style picker + reset
                        VStack(alignment: .center, spacing: 6) {
                            Picker("", selection: $appState.selectedStyle) {
                                (Text("A").underline() + Text("mbient")).tag(MusicStyle.ambient)
                                (Text("C").underline() + Text("hill")).tag(MusicStyle.chill)
                                (Text("K").underline() + Text("osmic")).tag(MusicStyle.kosmic)
                                (Text("M").underline() + Text("otorik")).tag(MusicStyle.motorik)
                            }
                            .pickerStyle(.segmented)
                            .tint(Color.gray)
                            .font(.system(size: 11))
                            .frame(width: kStylePickerWidth)
                            .disabled(appState.playMode == .endless)
                            .opacity(appState.playMode == .endless ? 0.5 : 1.0)

                            Button(action: { appState.resetTrackDefaults() }) {
                                Label {
                                    (Text("R").underline() + Text("eset"))
                                        .fontWeight(.semibold)
                                } icon: { Image(systemName: "arrow.counterclockwise") }
                                .frame(width: 105, alignment: .center)
                            }
                            .keyboardShortcut("r", modifiers: .command)
                            .help("Reset to clean state: clear song, restore defaults, re-detect audio (⌘R)")
                        }
                        .frame(width: kStyleVStackWidth)
                        .offset(x: 20)

                        // Right column: Mood above Key + BPM — hidden when window is too narrow
                        if contentWidth >= 850 {
                        VStack(alignment: .center, spacing: 4) {
                            HStack(spacing: 6) {
                                Picker("Mood", selection: $appState.moodOverride) {
                                    Text("Auto").tag(Optional<Mood>.none)
                                    ForEach(Mood.allCases, id: \.self) { m in
                                        Text(m.rawValue.capitalized).tag(Optional(m))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: kMoodPickerWidth)
                            }

                            HStack(spacing: 8) {
                                Picker("Key", selection: $appState.keyOverride) {
                                    Text("Auto").tag(Optional<String>.none)
                                    ForEach(kAllKeys, id: \.self) { k in
                                        Text(k).tag(Optional(k))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: kKeyPickerWidth)

                                HStack(spacing: 6) {
                                    Text("BPM")
                                        .foregroundStyle(.white)
                                        .fixedSize()
                                    TextField("Auto", text: tempoBinding)
                                    .frame(width: kBPMFieldWidth)
                                    .textFieldStyle(.roundedBorder)
                                    Stepper("", value: Binding(
                                        get: { appState.tempoOverride ?? appState.songState?.frame.tempo ?? 120 },
                                        set: { appState.tempoOverride = max(20, min(200, $0)) }
                                    ), in: 20...200)
                                    .labelsHidden()
                                }
                            }
                        }
                        } // end if contentWidth >= 850
                    }
                    #endif
                }
                .font(.callout)
                .padding(.vertical, 5)
                #if os(macOS)
                .offset(x: -25)
                #endif

                Spacer()

                // Help / About + copyright — right edge in wide mode only.
                // In macOS compact mode (<1150) these buttons move to below the mode selector.
                #if os(macOS)
                if contentWidth >= 1150 {
                    VStack(alignment: .trailing, spacing: 6) {
                        Button { showHelp  = true } label: { (Text("H").underline() + Text("elp")).frame(width: kHelpButtonWidth) }
                        Button { showAbout = true } label: { Text("About").frame(width: kHelpButtonWidth) }
                    }
                    .font(.callout)
                    .padding(.top, 5)
                    .padding(.trailing, 20)
                }
                #else
                VStack(alignment: .trailing, spacing: 6) {
                    Button { showHelp  = true } label: { (Text("H").underline() + Text("elp")).frame(width: kHelpButtonWidth) }
                    Button { showAbout = true } label: { Text("About").frame(width: kHelpButtonWidth) }
                    Button { showSleepPicker = true } label: { Text("Sleep").frame(width: kHelpButtonWidth) }
                    Button {
                        guard let song = appState.songState else { return }
                        PhonePlayerView.presentShare(song: song)
                    } label: { Text("Share").frame(width: kHelpButtonWidth) }
                    .disabled(appState.songState == nil)
                }
                .font(.callout)
                .controlSize(.small)
                .padding(.top, -5)
                .padding(.trailing, 8)
                .buttonStyle(.bordered)
                .confirmationDialog("Sleep Timer", isPresented: $showSleepPicker, titleVisibility: .visible) {
                    ForEach(SleepTimerDuration.allCases, id: \.self) { dur in
                        Button(dur == appState.sleepTimerDuration ? "\(dur.rawValue) ✓" : dur.rawValue) {
                            appState.setSleepTimer(dur)
                        }
                    }
                }
                #endif
            }
            .padding(.horizontal, 2)
            .background(Color(white: 0.15))
            .onAppear {
                // Prevent BPM text field from stealing focus on launch so plain keyboard shortcuts work.
                // asyncAfter gives SwiftUI time to finish its initial focus pass before we clear it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    appState.platformHost?.dismissKeyboard()
                }
            }
            .onChange(of: appState.selectedStyle) { _ in
                // Segmented style picker can shift focus to the BPM text field — clear it immediately
                DispatchQueue.main.async { appState.platformHost?.dismissKeyboard() }
                // Reset tempo override so the new style generates at its own natural tempo range
                appState.tempoOverride = nil
            }

            Divider()
        }
        #if os(macOS)
        // Compact/expand + visualizer toggle — top-left overlay, always inside
        // layoutPriority(3) + fixedSize(vertical:true) so it never leaves the window.
        .overlay(alignment: .topLeading) {
            HStack(spacing: 2) {
                Button { appState.toggleWindowCompact() } label: {
                    Image(systemName: appState.isWindowCompact
                          ? "arrow.up.left.and.arrow.down.right"
                          : "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.white.opacity(0.7))
                .help(appState.isWindowCompact ? "Restore window (\\ or ⌘0)"
                      : "Compact window (\\ or ⌘0)")

                Button { appState.macShowVisualizer.toggle() } label: {
                    Image(systemName: appState.macShowVisualizer
                          ? "slider.horizontal.3"
                          : "sparkles")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(appState.macShowVisualizer
                                 ? Color.white
                                 : Color.white.opacity(0.55))
                .help(appState.macShowVisualizer ? "Show Tracks (⌘Z)"
                      : "Show Visualizer (⌘Z)")

                Button { appState.macShowSongList.toggle() } label: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(appState.macShowSongList
                                 ? Color.white
                                 : Color.white.opacity(0.55))
                .help(appState.macShowSongList ? "Hide Song List (⌘I)"
                      : "Show Song List (⌘I)")
            }
            .padding(.leading, 6)
            .padding(.top, 9)
        }
        #endif
        .sheet(isPresented: $showHelp)  { HelpView() }
        .sheet(isPresented: $showAbout) { AboutView() }
        .onChange(of: appState.triggerShowHelp)  { _ in showHelp  = true }
        .onChange(of: appState.triggerShowAbout) { _ in showAbout = true }
        .onChange(of: appState.saveFlashCounter) { _ in
            withAnimation(.easeOut(duration: 0.1)) { saveFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation { saveFlash = false }
            }
        }
        #if os(iOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType("com.zudio.song") ?? .data]
        ) { result in
            guard case .success(let url) = result else { return }
            _ = url.startAccessingSecurityScopedResource()
            appState.loadFromLogURL(url)
            url.stopAccessingSecurityScopedResource()
        }
        // Pin to the default Dynamic Type size so the top bar doesn't grow when
        // the user has increased system text size in Accessibility settings.
        .dynamicTypeSize(.large)
        #endif
    }
}

// MARK: - LogoAreaView
// Extracted to its own struct to avoid type-checker timeout on the combined
// #if os(macOS)/#else logo block + complex .background { } modifier chain.

private struct LogoAreaView: View {
    @EnvironmentObject var appState: AppState
    /// When true, renders at half size for the macOS compact top-bar (<1150pt).
    var compact: Bool = false
    /// Content width passed from TopBarView — used on iOS to hide version text in portrait (<900pt).
    var contentWidth: CGFloat = 1200

    var body: some View {
        logoImage
            .frame(width: compact ? 100 : kLogoFrameWidth, alignment: .center)
            #if os(macOS)
            .padding(.leading, compact ? 4 : 8)
            #else
            .padding(.leading, 4)
            #endif
            .background { hiddenShortcuts }
    }

    // Loaded once at startup — avoids a disk read on every SwiftUI render pass.
    #if os(macOS)
    private static let cachedLogoImage: NSImage? = loadLogoImage()
    #endif

    @ViewBuilder private var logoImage: some View {
        #if os(macOS)
        if let nsImg = Self.cachedLogoImage {
            Image(nsImage: nsImg)
                .resizable()
                .scaledToFit()
                .frame(height: compact ? 42 : 84)
        } else {
            Text("Zudio")
                .font(.system(size: compact ? 21 : 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        #else
        if let url = Bundle.main.url(forResource: "zudio-logo", withExtension: "png"),
           let data = try? Data(contentsOf: url),
           let uiImg = UIImage(data: data) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFit()
                .frame(width: kLogoFrameWidth)  // fixes overflow: 2:1 logo → height = width/2
        } else {
            Text("Zudio")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        #endif
    }

    @ViewBuilder private var hiddenShortcuts: some View {
        Group {
            Button("") { appState.selectedStyle = .motorik }
                .keyboardShortcut("m", modifiers: .command)
            Button("") { appState.selectedStyle = .kosmic }
                .keyboardShortcut("k", modifiers: .command)
            Button("") { appState.selectedStyle = .ambient }
                .keyboardShortcut("a", modifiers: .command)
            Button("") { appState.selectedStyle = .chill }
                .keyboardShortcut("c", modifiers: [])
            Button("") { appState.playMode = .song }
                .keyboardShortcut("n", modifiers: [])
            Button("") { appState.playMode = .evolve }
                .keyboardShortcut("v", modifiers: [])
            Button("") { appState.playMode = .endless }
                .keyboardShortcut("d", modifiers: [])
            Button("") { appState.seekToStart() }
                .keyboardShortcut("b", modifiers: .command)
                .disabled(appState.songState == nil)
        }
        .hidden()
    }
}

// MARK: - MousePressTracker
// NSViewRepresentable that intercepts mouseDown/mouseUp natively — more reliable than
// DragGesture(minimumDistance:0) on macOS, and acceptsFirstMouse so it works without
// the window needing focus first. Used for the ◀ / ▶ hold-repeat transport buttons.

#if os(macOS)
private struct MousePressTracker: NSViewRepresentable {
    var onPress:   () -> Void
    var onRelease: () -> Void

    func makeNSView(context: Context) -> PressNSView {
        let v = PressNSView()
        v.onPress   = onPress
        v.onRelease = onRelease
        return v
    }

    func updateNSView(_ nsView: PressNSView, context: Context) {
        nsView.onPress   = onPress
        nsView.onRelease = onRelease
    }

    final class PressNSView: NSView {
        var onPress:   (() -> Void)?
        var onRelease: (() -> Void)?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var isOpaque: Bool { false }

        override func mouseDown(with event: NSEvent) { onPress?() }
        // mouseUp fires even if cursor has moved outside the view (macOS mouse capture)
        override func mouseUp(with event: NSEvent) { onRelease?() }
    }
}

// MARK: - Logo loader

private func loadLogoImage() -> NSImage? {
    if let url = Bundle.main.url(forResource: "zudio-logo", withExtension: "png"),
       let img = NSImage(contentsOf: url) { return img }
    return nil
}

private func loadAppIcon() -> NSImage? {
    let paths = ["assets/images/zudio-icon.icns", "Resources/assets/images/zudio-icon.icns"]
    if let base = Bundle.main.resourceURL {
        for path in paths {
            let url = base.appendingPathComponent(path)
            if let img = NSImage(contentsOf: url) { return img }
        }
    }
    if let url = Bundle.main.url(forResource: "zudio-icon", withExtension: "icns"),
       let img = NSImage(contentsOf: url) { return img }
    return nil
}
#endif

// MARK: - Help

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                Text("Zudio Help").font(.title.bold())
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Zudio generates Ambient, Chill, Kosmic and Motorik inspired music using MIDI.")
                    .font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                Divider()
                helpLine("Generate (⌘G / Return)", "Creates a new song. Use Evolve (one style) or Endless (all styles) for continuous playback.")
                helpLine("⏮ ⏭ Previous / Next track", "Go to the previous or next generated song.")
                helpLine("Export Audio (⌘E)", "Exports the song as an M4A audio file to /Downloads.")
                helpLine("Save Song (⌘S) / Load Song (⌘L)", "Saves a Zudio song file as well as a MIDI version to /Downloads. The MIDI file can be opened in any DAW. The Zudio song file is a plain text log file.")
                helpLine("Reset (⌘R)", "Reset audio, and all tracks and settings to initial state.")
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .bold))
                        Text("Visualizer / Tracks (⌘Z)")
                            .font(.system(size: 14).bold())
                    }
                    Text("Switch between visualizer and track view. Click on visuals to modify sounds.")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                helpLine("◀ Name ▶", "Cycle through MIDI instruments for that track.")
                helpLine("⚡ Lightning", "Regenerates a track and its     instrument. Structure and key are preserved.")
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("M")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 22, height: 18)
                            .background(Color(white: 0.30))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("S")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 22, height: 18)
                            .background(Color(white: 0.30))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("Mute / Solo").font(.system(size: 14).bold())
                    }
                    Text("Mute or Solo a track. Click again to toggle off.")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                helpLine("Status log", "Shows the generation rules applied to the current song.")
            }
            Spacer()
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    #if os(iOS)
                    .buttonStyle(.borderedProminent)
                    #endif
            }
        }
        .padding(24)
        .frame(width: 580, height: 620)
    }

    private func helpLine(_ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 14).bold())
            Text(desc).font(.system(size: 14)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - About

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                Text("Zudio").font(.title.bold())
            }
            Text("Generative music application vibe coded with AI!")
                .foregroundStyle(.secondary)
            Divider()

            // Long text — scrollable on iOS so it fits within the sheet detent height.
            // On macOS the sheet is tall enough to show everything without scrolling.
            #if os(iOS)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Version: 1.0").font(.system(size: 14))
                    Text("Built by analyzing classic Ambient, Chill, Kosmic and Motorik artists including Brian Eno, Loscil, Craven Faults, Moby, St Germain, Jean Michel Jarre, Tangerine Dream, Kraftwerk, Neu!, Deluxe, Harmonia, Electric Buddha Band and more.\n\nA set of rules was built for each style to keep the instruments locked-in playing together. Then I had AI analyze the songs in order to find bugs, identify musical clashes and update the rules to make things more coherent. Sometimes it even sounds like music! If not, try again and add more reverb.").font(.system(size: 14))
                    Text("Uses GeneralUser GS MIDI sound bank created by S. Christian Collins, arpeggios, pads, textures, sweeps, pans, ripped off riffs, Berlin school bass, muted trumpets and Dinger beat. There are audio effects for reverb, delay, tremolo and auto-pan.").font(.system(size: 14))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            #else
            VStack(alignment: .leading, spacing: 6) {
                Text("Version: 1.0").font(.system(size: 14))
                Text("Built by analyzing classic Ambient, Chill, Kosmic and Motorik artists including Brian Eno, Loscil, Craven Faults, Moby, St Germain, Jean Michel Jarre, Tangerine Dream, Kraftwerk, Neu!, Deluxe, Harmonia, Electric Buddha Band and more.\n\nA set of rules was built for each style to keep the instruments locked-in playing together. Then I had AI analyze the songs in order to find bugs, identify musical clashes and update the rules to make things more coherent. Sometimes it even sounds like music! If not, try again and add more reverb.").font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Uses GeneralUser GS MIDI sound bank created by S. Christian Collins, arpeggios, pads, textures, sweeps, pans, ripped off riffs, Berlin school bass, muted trumpets and Dinger beat. There are audio effects for reverb, delay, tremolo and auto-pan.").font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            #endif

            Text("Available for iPhone, iPad and Mac.")
                .font(.system(size: 14))
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                Text("More information:")
                    .foregroundStyle(.white)
                Link("https://www.mzurlocker.com/zudio",
                     destination: URL(string: "https://www.mzurlocker.com/zudio")!)
                    #if os(macOS)
                    .onHover { isHovering in
                        if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    #endif
            }
            .font(.system(size: 14))
            Text("Copyright © 2026 Zack Urlocker").font(.system(size: 14))
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    #if os(iOS)
                    .buttonStyle(.borderedProminent)
                    #endif
            }
        }
        .padding(24)
        #if os(iOS)
        .frame(width: 580)
        .presentationDetents([.height(490)])
        .presentationContentInteraction(.scrolls)
        #else
        .frame(width: 580, height: 440)
        #endif
    }
}
