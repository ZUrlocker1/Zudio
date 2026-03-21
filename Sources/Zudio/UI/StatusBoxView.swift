// StatusBoxView.swift — scrollable generation log.
// Accumulates entries across all generations; newest at bottom.
// Uses LazyVStack so SwiftUI renders only visible rows — appending one entry
// no longer rebuilds the entire AttributedString from scratch.

import SwiftUI

struct StatusBoxView: View {
    @EnvironmentObject var appState: AppState

    // Tag column fixed width in monospaced chars (must exceed longest rule ID + space)
    private let tagWidth = 15

    var body: some View {   
        VStack(spacing: 0) {
            Divider()

            // Header bar
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
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 1).id("top")

                        if appState.statusLog.isEmpty {
                            Text("Ready — press Generate to create a song.")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12, design: .monospaced))
                        } else {
                            ForEach(appState.statusLog.indices, id: \.self) { i in
                                logRow(appState.statusLog[i])
                            }
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
                .frame(minHeight: 60, idealHeight: 200, maxHeight: 280)
                .background(Color(white: 0.10))
                .onChange(of: appState.statusLog.count) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }
        }
    }

    // Single log row — rendered independently; LazyVStack only instantiates visible rows.
    private func logRow(_ entry: GenerationLogEntry) -> some View {
        HStack(spacing: 0) {
            Text(entry.tag.padding(toLength: tagWidth, withPad: " ", startingAt: 0))
                .font(.system(size: 12, weight: entry.isTitle ? .bold : .regular, design: .monospaced))
                .foregroundStyle(entry.isTitle ? Color.white : Color.green.opacity(0.85))
            Text(entry.description)
                .font(.system(size: 12, weight: entry.isTitle ? .bold : .regular, design: .monospaced))
                .foregroundStyle(entry.isTitle ? Color.yellow.opacity(0.95) : Color.white.opacity(0.85))
            Spacer(minLength: 0)
        }
    }
}
