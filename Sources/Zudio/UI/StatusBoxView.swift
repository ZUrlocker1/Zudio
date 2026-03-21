// StatusBoxView.swift — scrollable generation log.
// Accumulates entries across all generations; newest at bottom.
// Renders as a single Text view so selection spans the entire log
// exactly like a word processor — drag to select across any lines,
// then copy with ⌘C.

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
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 1).id("top")

                        if appState.statusLog.isEmpty {
                            Text("Ready — press Generate to create a song.")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            // Single Text view built from all entries so drag-selection
                            // spans the entire log (multiple Text views create isolated
                            // selection islands that cannot be bridged).
                            buildLogText()
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

    // Build the entire log as one Text value by concatenating styled segments.
    // A single Text supports contiguous selection across all lines.
    private func buildLogText() -> Text {
        let entries = appState.statusLog
        var result = Text("")
        for (i, entry) in entries.enumerated() {
            let tag = entry.tag.padding(toLength: tagWidth, withPad: " ", startingAt: 0)
            let weight: Font.Weight = entry.isTitle ? .bold : .regular
            let font = Font.system(size: 12, weight: weight, design: .monospaced)

            let tagText  = Text(tag)
                .font(font)
                .foregroundStyle(entry.isTitle ? Color.white : Color.green.opacity(0.85))
            let descText = Text(entry.description)
                .font(font)
                .foregroundStyle(entry.isTitle ? Color.yellow.opacity(0.95) : Color.white.opacity(0.85))

            let line = tagText + descText
            result = i == 0 ? line : result + Text("\n").font(font) + line
        }
        return result
    }
}
