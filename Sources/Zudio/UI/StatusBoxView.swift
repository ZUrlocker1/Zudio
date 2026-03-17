// StatusBoxView.swift — song metadata footer (title, key, BPM, mode, seed in debug)

import SwiftUI

struct StatusBoxView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            if let song = appState.songState {
                Group {
                    statusItem(label: "Title", value: song.title)
                    statusItem(label: "Key",   value: "\(song.frame.key) \(song.frame.mode.rawValue)")
                    statusItem(label: "BPM",   value: "\(song.frame.tempo)")
                    statusItem(label: "Mood",  value: song.frame.mood.rawValue.capitalized)
                    statusItem(label: "Form",  value: formLabel(song.form))
                    statusItem(label: "Bars",  value: "\(song.frame.totalBars)")

                    #if DEBUG
                    statusItem(label: "Seed", value: "\(song.globalSeed)")
                    #endif
                }
            } else {
                Text("No song generated")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Spacer()

            if appState.playback.isPlaying, let song = appState.songState {
                let bar  = appState.playback.currentBar + 1
                let total = song.frame.totalBars
                Text("Bar \(bar) / \(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func statusItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":").font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.bold())
        }
    }

    private func formLabel(_ form: SongForm) -> String {
        switch form {
        case .singleA:    return "Single-A"
        case .subtleAB:   return "Subtle A/B"
        case .moderateAB: return "Moderate A/B"
        }
    }
}
