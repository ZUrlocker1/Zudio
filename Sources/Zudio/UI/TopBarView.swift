// TopBarView.swift — logo + Generate + transport + global selectors

import SwiftUI

struct TopBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showHelp  = false
    @State private var showAbout = false

    var body: some View {
        HStack(spacing: 12) {
            // Logo
            Image("zudio-logo")
                .resizable()
                .scaledToFit()
                .frame(height: 32)
                .padding(.leading, 8)

            Divider().frame(height: 32)

            // Generate button
            Button(action: { appState.generateNew() }) {
                Label("Generate", systemImage: "wand.and.stars")
                    .fontWeight(.semibold)
            }
            .disabled(appState.isGenerating)

            Divider().frame(height: 32)

            // Transport: Previous (disabled) | Play | Stop | Next (disabled)
            HStack(spacing: 6) {
                Button(action: {}) {
                    Image(systemName: "backward.end.fill")
                }.disabled(true)

                Button(action: { appState.play() }) {
                    Image(systemName: "play.fill")
                        .foregroundStyle(.green)
                }
                .disabled(appState.songState == nil || appState.playback.isPlaying)

                Button(action: { appState.stop() }) {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                }
                .disabled(!appState.playback.isPlaying)

                Button(action: {}) {
                    Image(systemName: "forward.end.fill")
                }.disabled(true)
            }

            Divider().frame(height: 32)

            // Style selector (locked to Motorik in v1)
            LabeledContent("Style") {
                Text("Motorik")
                    .foregroundStyle(.secondary)
            }

            // Key selector
            LabeledContent("Key") {
                Picker("Key", selection: $appState.keyOverride) {
                    Text("Auto").tag(Optional<String>.none)
                    ForEach(kAllKeys, id: \.self) { key in
                        Text(key).tag(Optional(key))
                    }
                }
                .labelsHidden()
                .frame(width: 80)
            }

            // Tempo selector
            LabeledContent("BPM") {
                HStack(spacing: 4) {
                    Text(appState.tempoOverride.map { "\($0)" } ?? "Auto")
                        .frame(width: 40, alignment: .trailing)
                    Stepper("", value: Binding(
                        get: { appState.tempoOverride ?? 120 },
                        set: { appState.tempoOverride = $0 }
                    ), in: 20...200)
                    .labelsHidden()
                    Button("Auto") { appState.tempoOverride = nil }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            // Mood selector
            LabeledContent("Mood") {
                Picker("Mood", selection: $appState.moodOverride) {
                    Text("Auto").tag(Optional<Mood>.none)
                    ForEach(Mood.allCases, id: \.self) { mood in
                        Text(mood.rawValue.capitalized).tag(Optional(mood))
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }

            Spacer()

            // Help / About
            Button("Help")  { showHelp  = true }
            Button("About") { showAbout = true }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
        .sheet(isPresented: $showHelp)  { HelpView() }
        .sheet(isPresented: $showAbout) { AboutView() }
    }
}

// MARK: - Help / About placeholder sheets

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zudio Help").font(.title2).bold()
            Text("Press **Generate** to create a new Motorik-style song.\n\nUse **Key**, **BPM**, and **Mood** selectors to lock specific values; set them to **Auto** to let the generator choose.\n\nUse **Regenerate** on any track row to regenerate just that track while keeping the rest of the song.\n\nPress **Play** to hear the generated song through your Mac's built-in MIDI sounds.")
            Spacer()
            Button("Close") { dismiss() }
        }
        .padding(24)
        .frame(width: 400, height: 300)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 12) {
            Text("Zudio").font(.title).bold()
            Text("Motorik music generator · v1 prototype")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Close") { dismiss() }
        }
        .padding(24)
        .frame(width: 300, height: 200)
    }
}
