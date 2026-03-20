// StatusBoxView.swift — scrollable generation log.
// Accumulates entries across all generations; newest at bottom.
// Renders as a single attributed Text so the whole log is one selectable block.

import SwiftUI

struct StatusBoxView: View {
    @EnvironmentObject var appState: AppState

    // Column width for tag (padded with spaces so descriptions align).
    // Must exceed the longest rule ID (12 chars, e.g. COS-DRUM-003) + separator space.
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
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 1).id("top")

                        if appState.statusLog.isEmpty {
                            Text("Ready — press Generate to create a song.")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12, design: .monospaced))
                        } else {
                            Text(buildLogText())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
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

    // Build one AttributedString from all log entries so the entire block
    // is selectable as contiguous text (tag + description on each line).
    private func buildLogText() -> AttributedString {
        let monoFont = Font.system(size: 12, design: .monospaced)
        let monoBold = Font.system(size: 12, weight: .bold, design: .monospaced)

        var result = AttributedString()

        for (i, entry) in appState.statusLog.enumerated() {
            // Pad tag to fixed width so descriptions start in the same column
            let padded = entry.tag.padding(toLength: tagWidth, withPad: " ", startingAt: 0)

            var tagPart = AttributedString(padded)
            tagPart.font = entry.isTitle ? monoBold : monoFont
            tagPart.foregroundColor = entry.isTitle ? .white : Color.green.opacity(0.85)

            let suffix = i < appState.statusLog.count - 1 ? "\n" : ""
            var descPart = AttributedString(entry.description + suffix)
            descPart.font = entry.isTitle ? monoBold : monoFont
            descPart.foregroundColor = entry.isTitle ? Color.yellow.opacity(0.95) : Color.white.opacity(0.85)

            result += tagPart + descPart
        }

        return result
    }
}
