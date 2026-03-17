// ContentView.swift — root layout: top bar + track rows + status box

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    private let trackLabels = ["Lead 1", "Lead 2", "Pads", "Rhythm", "Texture", "Bass", "Drums"]

    var body: some View {
        VStack(spacing: 0) {
            TopBarView()

            // Track rows — plain VStack eliminates gap between last row and status box
            VStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { trackIndex in
                    TrackRowView(
                        trackIndex: trackIndex,
                        label: trackLabels[trackIndex],
                        events: appState.songState?.events(forTrack: trackIndex) ?? [],
                        totalBars: appState.songState?.frame.totalBars ?? 32,
                        currentStep: appState.playback.currentStep,
                        isMuted: appState.muteState[trackIndex],
                        isSolo:  appState.soloState[trackIndex]
                    )
                }
            }
            .padding(.vertical, 4)
            .overlay {
                if appState.isGenerating {
                    ProgressView("Generating…")
                        .progressViewStyle(.circular)
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                } else if appState.songState == nil {
                    Text("Press Generate or Play to create a song")
                        .font(.callout)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            // Status box sits directly below the last row with no gap
            StatusBoxView()
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(white: 0.20))
        .preferredColorScheme(.dark)
    }
}
