// StatusBoxView.swift — scrollable generation log.
// Accumulates entries across all generations; newest at bottom.
// Renders directly from SongState.generationLog — no ad-hoc formatting here.

import SwiftUI

struct StatusBoxView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Header bar: label + scroll-to-top / scroll-to-bottom
            HStack(spacing: 4) {
                Text("Generation Log")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                ScrollViewReader { proxy in
                    HStack(spacing: 4) {
                        Button {
                            withAnimation { proxy.scrollTo("top", anchor: .top) }
                        } label: {
                            Image(systemName: "arrow.up.to.line")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                        .help("Scroll to first entry")

                        Button {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        } label: {
                            Image(systemName: "arrow.down.to.line")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                        .help("Scroll to latest entry")
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color(white: 0.12))

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 3) {
                        Color.clear.frame(height: 1).id("top")

                        if appState.generationHistory.isEmpty {
                            Text("Ready — press Generate to create a Motorik song.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(appState.generationHistory.enumerated()), id: \.offset) { idx, song in
                                if idx > 0 { Divider().padding(.vertical, 3) }
                                generationSection(song)
                            }
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
                .frame(minHeight: 60, idealHeight: 200, maxHeight: 280)
                .background(Color(white: 0.10))
                .onChange(of: appState.generationHistory.reduce(0) { $0 + $1.generationLog.count }) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }
        }
    }

    // MARK: - Render one generation block

    @ViewBuilder
    private func generationSection(_ song: SongState) -> some View {
        ForEach(Array(song.generationLog.enumerated()), id: \.offset) { _, entry in
            logLine(entry)
        }
    }

    private func logLine(_ entry: GenerationLogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.tag)
                .foregroundStyle(entry.isTitle ? Color.white : Color.green.opacity(0.8))
                .fontWeight(entry.isTitle ? .bold : .regular)
                .frame(width: 72, alignment: .leading)
            Text(entry.description)
                .foregroundStyle(entry.isTitle ? Color.yellow.opacity(0.95) : Color.white.opacity(0.85))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
