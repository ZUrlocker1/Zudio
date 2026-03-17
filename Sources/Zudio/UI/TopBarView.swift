// TopBarView.swift — logo + Generate + transport + global selectors + title readout

import SwiftUI
import AppKit

struct TopBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showHelp  = false
    @State private var showAbout = false
    @State private var stopFlash = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {

                // Logo — 50% larger than previous 156px = 234px
                Group {
                    if let nsImg = loadLogoImage() {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 234)
                    } else {
                        Text("Zudio")
                            .font(.system(size: 60, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 260, alignment: .leading)
                .padding(.leading, 8)

                Divider().frame(height: 70)

                // Transport — prev/next + play/stop
                HStack(spacing: 8) {
                    // ◀ Previous (non-functional v1 placeholder)
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .disabled(true)
                    .help("Previous (coming soon)")

                    // Play
                    Button(action: { appState.play() }) {
                        Image(systemName: appState.isGenerating ? "hourglass" : "play.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }
                    .disabled(appState.playback.isPlaying || appState.isGenerating)
                    .help("Play (auto-generates if no song)")
                    .keyboardShortcut(.space, modifiers: [])

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
                            .font(.title3)
                            .scaleEffect(stopFlash ? 1.3 : 1.0)
                    }
                    .disabled(!appState.playback.isPlaying)
                    .help("Stop")

                    // ▶ Next (non-functional v1 placeholder)
                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .disabled(true)
                    .help("Next (coming soon)")
                }
                .background(FirstMouseFix())

                Divider().frame(height: 70)

                // Two-row control section
                VStack(alignment: .leading, spacing: 6) {
                    // Row 1: Generate + Style + Key + Mood  |  song title (18pt)
                    HStack(spacing: 8) {
                        Button(action: { appState.generateNew() }) {
                            Label("Generate", systemImage: "wand.and.stars")
                                .fontWeight(.semibold)
                        }
                        .disabled(appState.isGenerating)
                        .keyboardShortcut("g", modifiers: .command)

                        LabeledContent("Style") {
                            Text("Motorik").foregroundStyle(.secondary).font(.caption)
                        }

                        Picker("Key", selection: $appState.keyOverride) {
                            Text("Auto").tag(Optional<String>.none)
                            ForEach(kAllKeys, id: \.self) { k in
                                Text(k).tag(Optional(k))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 72)

                        Picker("Mood", selection: $appState.moodOverride) {
                            Text("Auto").tag(Optional<Mood>.none)
                            ForEach(Mood.allCases, id: \.self) { m in
                                Text(m.rawValue.capitalized).tag(Optional(m))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)

                        // Song title aligned with this row
                        if let song = appState.songState {
                            Text(song.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        } else if !appState.isGenerating {
                            Text("No song — press Generate or Play")
                                .foregroundStyle(Color.white.opacity(0.5))
                                .font(.system(size: 14))
                        }
                    }

                    // Row 2: Save MIDI + BPM + Key/BPM/Mood/Length readouts (2× larger)
                    HStack(spacing: 8) {
                        Button(action: { appState.saveMIDI() }) {
                            Label("Save MIDI", systemImage: "square.and.arrow.down")
                        }
                        .disabled(appState.songState == nil)
                        .help("Save multi-track MIDI to ~/Downloads/")

                        HStack(spacing: 4) {
                            Text("BPM").font(.caption).foregroundStyle(.secondary)
                            TextField("", value: Binding(
                                get: { appState.tempoOverride ?? 0 },
                                set: { v in appState.tempoOverride = v == 0 ? nil : max(20, min(200, v)) }
                            ), format: .number)
                            .frame(width: 44)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            Stepper("", value: Binding(
                                get: { appState.tempoOverride ?? 138 },
                                set: { appState.tempoOverride = max(20, min(200, $0)) }
                            ), in: 20...200)
                            .labelsHidden()
                            .frame(width: 24)
                            Button("A") { appState.tempoOverride = nil }
                                .buttonStyle(.borderless)
                                .foregroundStyle(appState.tempoOverride == nil ? .blue : .secondary)
                                .font(.caption2.bold())
                                .help("Auto tempo")
                        }

                        // Key/BPM/Mood/Length readouts — 2× larger (caption2→callout)
                        if let song = appState.songState {
                            HStack(spacing: 14) {
                                readout("Key",    "\(song.frame.key) \(song.frame.mode.rawValue)")
                                readout("BPM",    "\(song.frame.tempo)")
                                readout("Mood",   song.frame.mood.rawValue.capitalized)
                                readout("Length", songLength(song))
                            }
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Button("Help")  { showHelp  = true }
                    Button("About") { showAbout = true }
                }
                .padding(.trailing, 10)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(white: 0.15))

            Divider()
        }
        .sheet(isPresented: $showHelp)  { HelpView() }
        .sheet(isPresented: $showAbout) { AboutView() }
    }

    // MARK: - Helpers

    /// Readouts at 2× size: was caption2 (~10pt) → callout (~14pt)
    private func readout(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label + ":").font(.callout).foregroundStyle(Color.white.opacity(0.55))
            Text(value).font(.callout.bold()).foregroundStyle(.white)
        }
    }

    private func songLength(_ song: SongState) -> String {
        let seconds = Int(Double(song.frame.totalBars) * 4.0 * 60.0 / Double(song.frame.tempo))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

// MARK: - Logo loader

private func loadLogoImage() -> NSImage? {
    // Both Xcode build and `make run` copy assets/ → Contents/Resources/assets/
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
    // Direct Bundle lookup (Xcode sometimes flattens resources)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    helpLine("Generate (⌘G)", "Creates a full Motorik song — structure, chords, and all 7 tracks.")
                    helpLine("Play (Space)", "Plays the song from the beginning. If no song exists, generates one first.")
                    helpLine("Stop", "Stops playback immediately.")
                    helpLine("Save MIDI", "Exports a Type-1 multi-track MIDI file to ~/Downloads/.")
                    helpLine("◀ Name ▶", "Cycle through GM instruments for that track. Change takes effect immediately.")
                    helpLine("⚡ Lightning", "Regenerates only that track's MIDI notes (structure and key stay the same).")
                    helpLine("M / S", "Mute (blue) or Solo (yellow) a track. Second click toggles off.")
                    helpLine("Key / Mood / BPM", "Override parameters for the next Generate. Set to Auto for random.")
                    helpLine("Status log", "Shows the generation rules applied to the current song.")
                }
                .padding(.bottom, 8)
            }
            Spacer()
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 480, height: 400)
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
            Text("Personal generative music research prototype for native macOS.")
                .foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Version: 0.1 (prototype)").font(.callout)
                Text("Audio engine: Apple AVAudioEngine with Apple DLS/GM playback.").font(.callout)
                Text("MIDI export: Type-1 multi-track, saved to ~/Downloads/.").font(.callout)
                Text("V1 scope: Motorik style — 7 tracks: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums.").font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Generation is seeded and deterministic.").font(.callout)
            }
            Spacer()
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 420, height: 320)
    }
}
