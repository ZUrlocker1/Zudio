// ContentView.swift — root layout: top bar + track rows + status box

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    private let trackLabels = ["Lead 1", "Lead 2", "Pads", "Rhythm", "Texture", "Bass", "Drums"]

    var body: some View {
        VStack(spacing: 0) {
            TopBarView()

            if let song = appState.songState {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { trackIndex in
                            TrackRowView(
                                trackIndex: trackIndex,
                                label: trackLabels[trackIndex],
                                events: song.events(forTrack: trackIndex),
                                totalBars: song.frame.totalBars,
                                currentStep: appState.playback.currentStep,
                                isMuted: appState.muteState[trackIndex],
                                isSolo:  appState.soloState[trackIndex]
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Spacer()
                if appState.isGenerating {
                    ProgressView("Generating…")
                        .progressViewStyle(.circular)
                } else {
                    Text("Press Generate to create a song")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            StatusBoxView()
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
