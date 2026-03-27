// TopBarView.swift — compact 3-row header
// Row 1: blank spacer | Row 2: transport + controls | Row 3: Save Audio + Save MIDI

import SwiftUI
import AppKit

// Styled to match macOS bordered Button appearance with a press-state highlight.
private extension View {
    func transportButtonStyle(isDown: Bool) -> some View {
        self
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDown ? Color(NSColor.selectedControlColor) : Color(NSColor.controlColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
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

struct TopBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showHelp  = false
    @State private var showAbout = false
    @State private var stopFlash = false

    @StateObject private var reverseRepeater = HoldRepeater()
    @StateObject private var forwardRepeater = HoldRepeater()

    // @GestureState auto-resets to false when the gesture ends — used for press highlight
    @GestureState private var reverseIsDown = false
    @GestureState private var forwardIsDown = false

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: small top margin
            Color(white: 0.15).frame(height: 8)

            // Main controls block
            HStack(alignment: .center, spacing: 10) {

                // Logo — 700×350 landscape asset, 40% bigger than controls height (84px)
                Group {
                    if let nsImg = loadLogoImage() {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 84)
                    } else {
                        Text("Zudio")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if appState.testModeEnabled {
                            Text("TEST")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        Text("V 0.93 alpha")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(4)
                    .offset(x: 20)
                }
                .onTapGesture { appState.toggleTestMode() }
                .frame(width: 200, alignment: .center)
                .padding(.leading, 8)
                .background {
                    Group {
                        // Hidden keyboard shortcuts
                        Button("") { appState.toggleTestMode() }
                            .keyboardShortcut("t", modifiers: .command)
                        Button("") { appState.selectedStyle = .motorik }
                            .keyboardShortcut("m", modifiers: .command)
                        Button("") { appState.selectedStyle = .kosmic }
                            .keyboardShortcut("k", modifiers: .command)
                        Button("") { appState.selectedStyle = .ambient }
                            .keyboardShortcut("a", modifiers: .command)
                        Button("") { appState.seekToStart() }
                            .keyboardShortcut("b", modifiers: .command)
                            .disabled(appState.songState == nil)
                    }
                    .hidden()
                }

                Divider()

                // Transport — ⏮ ◀ ▶ ■ ▶ ⏭
                HStack(spacing: 4) {
                    // Jump to start
                    Button(action: { appState.seekToStart() }) {
                        Image(systemName: "backward.end.fill")
                            .foregroundStyle(.primary)
                    }
                    .disabled(appState.songState == nil)
                    .help("Go to start (rewind to bar 1)")

                    // Reverse: tap = -1 bar, hold = -2 bars per tick, stops at bar 0
                    Image(systemName: "backward.fill")
                        .transportButtonStyle(isDown: reverseIsDown)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .updating($reverseIsDown) { _, state, _ in state = true }
                                .onChanged { _ in
                                    guard appState.songState != nil else { return }
                                    reverseRepeater.start(
                                        initial:  { appState.seekBackOneBar() },
                                        step:     { appState.seekBackTwoBars() },
                                        atLimit:  { appState.playback.currentBar <= 0 }
                                    )
                                }
                                .onEnded { _ in reverseRepeater.stop() }
                        )
                        .help("Back 1 bar (hold: back 2 bars repeatedly)")

                    // Play
                    Button(action: { appState.play() }) {
                        Image(systemName: appState.isGenerating ? "hourglass" : "play.fill")
                            .foregroundStyle(.green)
                    }
                    .disabled(appState.playback.isPlaying || appState.isGenerating)
                    .help("Play (auto-generates if no song)")

                    // Stop
                    Button(action: {
                        appState.stop()
                        withAnimation(.easeOut(duration: 0.1)) { stopFlash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            withAnimation { stopFlash = false }
                        }
                    }) {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(stopFlash ? .white : .red)
                            .scaleEffect(stopFlash ? 1.2 : 1.0)
                    }
                    .disabled(!appState.playback.isPlaying)
                    .help("Stop")

                    // Fast forward: tap = +1 bar, hold = +2 bars per tick, stops at last bar
                    Image(systemName: "forward.fill")
                        .transportButtonStyle(isDown: forwardIsDown)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .updating($forwardIsDown) { _, state, _ in state = true }
                                .onChanged { _ in
                                    guard let song = appState.songState else { return }
                                    forwardRepeater.start(
                                        initial:  { appState.seekForwardOneBar() },
                                        step:     { appState.seekForwardTwoBars() },
                                        atLimit:  { appState.playback.currentBar >= song.frame.totalBars - 1 }
                                    )
                                }
                                .onEnded { _ in forwardRepeater.stop() }
                        )
                        .help("Forward 1 bar (hold: forward 2 bars repeatedly)")

                    // Jump to end
                    Button(action: { appState.seekToEnd() }) {
                        Image(systemName: "forward.end.fill")
                            .foregroundStyle(.primary)
                    }
                    .disabled(appState.songState == nil)
                    .help("Go to end (stops playback)")
                }
                .font(.callout)
                .padding(.vertical, 8)
                .background(FirstMouseFix())

                Divider()

                // Generate / Save MIDI / Export Audio stacked left; selectors + Reset right.
                HStack(alignment: .center, spacing: 14) {

                    // Left column: three action buttons, all same width
                    VStack(spacing: 6) {
                        Button(action: { appState.generateNew() }) {
                            Label {
                                (Text("G").underline() + Text("enerate"))
                                    .fontWeight(.semibold)
                            } icon: { Image(systemName: "bolt.fill") }
                            .frame(width: 128, alignment: .center)
                        }
                        .disabled(appState.isGenerating)
                        .keyboardShortcut("g", modifiers: .command)
                        .help("Generate a new song (⌘G)")

                        Button(action: { appState.saveMIDI() }) {
                            Label {
                                (Text("S").underline() + Text("ave MIDI"))
                                    .fontWeight(.semibold)
                            } icon: { Image(systemName: "square.and.arrow.down") }
                            .frame(width: 128, alignment: .center)
                        }
                        .disabled(appState.songState == nil)
                        .keyboardShortcut("s", modifiers: .command)
                        .help("Save multi-track MIDI to ~/Downloads/ (⌘S)")

                        Button(action: { appState.loadFromLog() }) {
                            Label {
                                (Text("L").underline() + Text("oad Song"))
                                    .fontWeight(.semibold)
                            } icon: { Image(systemName: "doc.text") }
                            .frame(width: 128, alignment: .center)
                        }
                        .disabled(appState.isGenerating)
                        .keyboardShortcut("l", modifiers: .command)
                        .help("Reload a song from a saved .txt log file (⌘L)")

                        Button(action: { appState.requestExport() }) {
                            Label {
                                (Text("E").underline() + Text("xport Audio"))
                                    .fontWeight(.semibold)
                            } icon: { Image(systemName: "waveform") }
                            .frame(width: 128, alignment: .center)
                        }
                        .disabled(appState.songState == nil || appState.isExportingAudio)
                        .keyboardShortcut("e", modifiers: .command)
                        .help("Export song to M4A audio file in ~/Downloads/ (⌘E)")
                    }

                    // Right block: [style picker + reset centered] [20pt gap] [mood + key/bpm]
                    HStack(alignment: .top, spacing: 20) {

                        // Left column: style picker (full width) + reset (centered beneath it)
                        VStack(alignment: .center, spacing: 6) {
                            Picker("", selection: $appState.selectedStyle) {
                                (Text("A").underline() + Text("mbient")).tag(MusicStyle.ambient)
                                (Text("K").underline() + Text("osmic")).tag(MusicStyle.kosmic)
                                (Text("M").underline() + Text("otorik")).tag(MusicStyle.motorik)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 210)

                            Button(action: { appState.resetTrackDefaults() }) {
                                Label {
                                    (Text("R").underline() + Text("eset"))
                                        .fontWeight(.semibold)
                                } icon: { Image(systemName: "arrow.counterclockwise") }
                                .frame(width: 105, alignment: .center)
                            }
                            .disabled(appState.songState == nil)
                            .keyboardShortcut("r", modifiers: .command)
                            .help("Reset all instruments and effects to style defaults (⌘R)")
                        }
                        .frame(width: 210)

                        // Right column: Mood centered above Key + BPM
                        VStack(alignment: .center, spacing: 4) {
                            Picker("Mood", selection: $appState.moodOverride) {
                                Text("Auto").tag(Optional<Mood>.none)
                                ForEach(Mood.allCases, id: \.self) { m in
                                    Text(m.rawValue.capitalized).tag(Optional(m))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 110)

                            HStack(spacing: 8) {
                                Picker("Key", selection: $appState.keyOverride) {
                                    Text("Auto").tag(Optional<String>.none)
                                    ForEach(kAllKeys, id: \.self) { k in
                                        Text(k).tag(Optional(k))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 90)

                                HStack(spacing: 6) {
                                    Text("BPM")
                                        .foregroundStyle(.white)
                                        .fixedSize()
                                    TextField("", value: Binding(
                                        get: { appState.tempoOverride ?? 120 },
                                        set: { v in appState.tempoOverride = v == 0 ? nil : max(20, min(200, v)) }
                                    ), format: .number)
                                    .frame(width: 48)
                                    .textFieldStyle(.roundedBorder)
                                    Stepper("", value: Binding(
                                        get: { appState.tempoOverride ?? 120 },
                                        set: { appState.tempoOverride = max(20, min(200, $0)) }
                                    ), in: 20...200)
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                }
                .font(.callout)
                .padding(.vertical, 5)

                Spacer()

                // Help / About — rows align with Generate (row 2) and Save MIDI (row 3)
                VStack(alignment: .trailing, spacing: 6) {
                    Button { showHelp  = true } label: { (Text("H").underline() + Text("elp")).frame(width: 52) }
                    Button { showAbout = true } label: { Text("About").frame(width: 52) }
                    Text("Copyright © 2026 Zack Urlocker")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.top, 6)
                }
                .font(.callout)
                .padding(.top, 5)
                .padding(.trailing, 20)
            }
            .padding(.horizontal, 2)
            .background(Color(white: 0.15))
            .onAppear {
                // Prevent BPM text field from stealing focus on launch so plain keyboard shortcuts work
                DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
            }

            Divider()
        }
        .sheet(isPresented: $showHelp)  { HelpView() }
        .sheet(isPresented: $showAbout) { AboutView() }
        .onChange(of: appState.triggerShowHelp)  { _ in showHelp  = true }
        .onChange(of: appState.triggerShowAbout) { _ in showAbout = true }
    }
}

// MARK: - Logo loader

private func loadLogoImage() -> NSImage? {
    let paths: [String] = [
        "assets/images/logo/zudio-logo.png",
        "Resources/assets/images/logo/zudio-logo.png",
    ]
    if let base = Bundle.main.resourceURL {
        for path in paths {
            let url = base.appendingPathComponent(path)
            if let img = NSImage(contentsOf: url) { return img }
        }
    }
    if let url = Bundle.main.url(forResource: "zudio-logo", withExtension: "png"),
       let img = NSImage(contentsOf: url) { return img }
    return nil
}

private func loadAppIcon() -> NSImage? {
    let paths = ["assets/zudio-icon.icns", "Resources/assets/zudio-icon.icns"]
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

// MARK: - Help

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let img = loadAppIcon() {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                }
                Text("Zudio Help").font(.title.bold())
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Zudio generates Ambient, Kosmic and Motorik inspired music using MIDI.")
                    .font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                Divider()
                helpLine("Generate (⌘G / Return)", "Creates a new song. Use Mood, Key, and BPM to shape the result.")
                helpLine("Play / Stop (Space)", "Space bar toggles play/stop from the current playhead position.")
                helpLine("← → arrows", "Seek back or forward 1 bar. Hold the transport buttons to repeat.")
                helpLine("Export Audio (⌘E)", "Exports the song as an M4A audio file to /Downloads.")
                helpLine("Save MIDI (⌘S) / Load Song (⌘L)", "Exports a multi-track MIDI file to /Downloads. Open in any DAW to edit further. Also saves a text log file of rules. The log file can be reloaded to restore a song.")
                helpLine("Reset (⌘R)", "Reset all instruments and effects to style defaults.")
                helpLine("◀ Name ▶", "Cycle through GM instruments for that track.")
                helpLine("⚡ Lightning", "Regenerates only that track's notes. Structure and key are preserved.")
                helpLine("M / S", "Mute or Solo a track. Click again to toggle off.")
                helpLine("Status log", "Shows the generation rules applied to the current song.")
            }
            Spacer()
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
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
                if let img = loadAppIcon() {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                }
                Text("Zudio").font(.title.bold())
            }
            Text("Generative music application vibe coded in a week with Claude!")
                .foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Version: 0.93 (alpha)").font(.system(size: 14))
                Text("Built by analyzing classic Ambient, Kosmic and Motorik artists including Brian Eno,Jean Michel Jarre, Kraftwerk, Neu!, Deluxe, Harmonia, Tangerine Dream, Electric Buddha Band, Loscil, Craven Faults and more. A set of rules was built for each style to keep the instruments locked-in playing together. Then I had Claude analyze the songs in order to find bugs, identify musical clashes and update the rules to make things more coherent. Sometimes it even sounds like music! If not, try again and add more reverb.").font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
                Text("V1.0 uses GS MIDI instruments as well as arpeggios, pads, textures, sweeps, pans, ripped off riffs, Berlin school bass and Dinger beat. There are basic audio effects per track for boost, reverb, delay, tremolo, auto-pan and space echo.").font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Continuous playback, improved sound and an iPad version coming soon. Maybe.").font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("Design docs and source code:")
                    .foregroundStyle(.white)
                Link("https://github.com/ZUrlocker1/Zudio",
                     destination: URL(string: "https://github.com/ZUrlocker1/Zudio")!)
                    .onHover { isHovering in
                        if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            }
            .font(.system(size: 14))
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 580, height: 440)
    }
}
