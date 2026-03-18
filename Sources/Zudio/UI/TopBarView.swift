// TopBarView.swift — compact 3-row header
// Row 1: blank spacer | Row 2: transport + controls | Row 3: Save MIDI

import SwiftUI
import AppKit

struct TopBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showHelp  = false
    @State private var showAbout = false
    @State private var stopFlash = false

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: small top margin
            Color(white: 0.15).frame(height: 8)

            // Main controls block
            HStack(alignment: .center, spacing: 10) {

                // Logo — 700×350 landscape asset, height matched to controls height (60px → 120px wide)
                Group {
                    if let nsImg = loadLogoImage() {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                    } else {
                        Text("Zudio")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 200, alignment: .leading)
                .padding(.leading, 8)

                Divider()

                // Transport — ⏮ ▶ ■ ⏭
                HStack(spacing: 10) {
                    Button(action: { appState.seekToStart() }) {
                        Image(systemName: "backward.end.fill")
                            .foregroundStyle(.primary)
                    }
                    .disabled(appState.songState == nil)
                    .help("Go to start (rewind to bar 1)")

                    Button(action: { appState.play() }) {
                        Image(systemName: appState.isGenerating ? "hourglass" : "play.fill")
                            .foregroundStyle(.green)
                    }
                    .disabled(appState.playback.isPlaying || appState.isGenerating)
                    .help("Play (auto-generates if no song)")

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
                            Label("Generate", systemImage: "wand.and.stars")
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
                                get: { appState.tempoOverride ?? 0 },
                                set: { v in appState.tempoOverride = v == 0 ? nil : max(20, min(200, v)) }
                            ), format: .number)
                            .frame(width: 44)
                            .textFieldStyle(.roundedBorder)
                            Stepper("", value: Binding(
                                get: { appState.tempoOverride ?? 138 },
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
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    helpLine("Generate (⌘G)", "Creates a full Motorik song — structure, chords, and all 7 tracks.")
                    helpLine("Play / Stop (Space)", "Space bar toggles play/stop. Play auto-generates if no song exists.")
                    helpLine("⏮ Go to Start", "Moves the playhead to bar 1. Keeps playing if currently playing.")
                    helpLine("⏭ Go to End", "Moves the playhead to the last bar and stops playback.")
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
        .frame(width: 480, height: 420)
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
