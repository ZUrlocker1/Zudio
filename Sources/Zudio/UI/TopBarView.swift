// TopBarView.swift — compact 3-row header
// Row 1: blank spacer | Row 2: transport + controls | Row 3: Save MIDI

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
                .frame(width: 200, alignment: .center)
                .padding(.leading, 8)

                Divider()

                // Transport — ⏮ ◀ ▶ ■ ▶ ⏭
                HStack(spacing: 10) {
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

                // Generate (row 2) and Save MIDI (row 3) in a VStack, plus selectors
                VStack(alignment: .leading, spacing: 6) {
                    // Blank row above first button row
                    Color.clear.frame(height: 22)

                    // Row 2: Generate | Style | Mood | Key | BPM
                    HStack(spacing: 14) {
                        Button(action: { appState.generateNew() }) {
                            Label("Generate", systemImage: "bolt.fill")
                                .fontWeight(.semibold)
                        }
                        .disabled(appState.isGenerating)
                        .keyboardShortcut("g", modifiers: .command)

                        Text("Style: Motorik")
                            .foregroundStyle(.secondary)

                        Picker("Mood", selection: $appState.moodOverride) {
                            Text("Auto").tag(Optional<Mood>.none)
                            ForEach(Mood.allCases, id: \.self) { m in
                                Text(m.rawValue.capitalized).tag(Optional(m))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 110)

                        Picker("Key", selection: $appState.keyOverride) {
                            Text("Auto").tag(Optional<String>.none)
                            ForEach(kAllKeys, id: \.self) { k in
                                Text(k).tag(Optional(k))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)

                        HStack(spacing: 4) {
                            Text("BPM").foregroundStyle(.secondary)
                            TextField("", value: Binding(
                                get: { appState.tempoOverride ?? appState.songState?.frame.tempo ?? 0 },
                                set: { v in appState.tempoOverride = v == 0 ? nil : max(20, min(200, v)) }
                            ), format: .number)
                            .frame(width: 44)
                            .textFieldStyle(.roundedBorder)
                            Stepper("", value: Binding(
                                get: { appState.tempoOverride ?? appState.songState?.frame.tempo ?? 138 },
                                set: { appState.tempoOverride = max(20, min(200, $0)) }
                            ), in: 20...200)
                            .labelsHidden()
                            .frame(width: 24)
                        }
                    }

                    // Row 3: Save MIDI grouped below Generate
                    HStack(spacing: 14) {
                        Button(action: { appState.saveMIDI() }) {
                            Label("Save MIDI", systemImage: "square.and.arrow.down")
                                .fontWeight(.semibold)
                        }
                        .disabled(appState.songState == nil)
                        .help("Save multi-track MIDI to ~/Downloads/")
                    }

                    // Blank row below second button row
                    Color.clear.frame(height: 22)
                }
                .font(.callout)
                .padding(.vertical, 5)

                Spacer()

                // Help / About — rows align with Generate (row 2) and Save MIDI (row 3)
                VStack(alignment: .trailing, spacing: 6) {
                    Button("Help")  { showHelp  = true }
                    Button("About") { showAbout = true }
                }
                .font(.callout)
                .padding(.top, 5)      // match controls VStack .padding(.vertical, 5)
                .padding(.trailing, 8)
            }
            .padding(.horizontal, 2)
            .background(Color(white: 0.15))

            Divider()
        }
        .sheet(isPresented: $showHelp)  { HelpView() }
        .sheet(isPresented: $showAbout) { AboutView() }
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

// MARK: - Help

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zudio Help").font(.title2.bold())
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Zudio generates Motorik-inspired music using MIDI tracks.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                Divider()
                helpLine("Generate (⌘G)", "Creates a new song. Use Mood, Key, and BPM to shape the result, or leave them on Auto.")
                helpLine("Play / Stop (Space)", "Space bar toggles play/stop from the current playhead position.")
                helpLine("Save MIDI", "Exports a multi-track MIDI file to ~/Downloads/. Open in any DAW to edit further.")
                helpLine("◀ Name ▶", "Cycle through GM instruments for that track.")
                helpLine("⚡ Lightning", "Regenerates only that track's notes. Structure and key are preserved.")
                helpLine("M / S", "Mute or Solo a track. Click again to toggle off.")
                helpLine("Status log", "Shows the generation rules applied to the current song.")
            }
            Spacer()
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 600, height: 430)
    }

    private func helpLine(_ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.callout.bold())
            Text(desc).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - About

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zudio").font(.title.bold())
            Text("Generative music application vibe coded with Claude!")
                .foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Version: 0.7 (alpha)").font(.callout)
                Text("Built by analyzing classic Motorik songs as well as other works. Then a set of rules were defined to keep the instruments locked-in playing together. Sometimes it even sounds like music!").font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text("V1: Motorik style only. Instruments using GS MIDI. Effects not implemented.").font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text("V2: Improve musicality, add effects, attempt additional styles (Electronic, Ambient, etc.).").font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 440, height: 298)
    }
}
