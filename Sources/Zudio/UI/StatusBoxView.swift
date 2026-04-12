// StatusBoxView.swift — scrollable generation log.
// Accumulates entries across all generations; newest at bottom.
// Renders as a single Text view so selection spans the entire log
// exactly like a word processor — drag to select across any lines,
// then copy with ⌘C.

import SwiftUI

struct StatusBoxView: View {
    @EnvironmentObject var appState: AppState

    /// Passed from ContentView so font size can adapt for iPad mini.
    var contentWidth: CGFloat = 0

    // Tag column fixed width in monospaced chars (must exceed longest rule ID + space)
    private let tagWidth = 15

    // Body font: the generated log entries. Affected by +/- hotkeys and mini-device reduction.
    private var fontBody: CGFloat {
        let base: CGFloat
        #if os(macOS)
        base = 12
        #else
        base = isMini ? 12 : 14
        #endif
        return max(8, min(20, base + CGFloat(appState.statusLogFontOffset)))
    }
    // iPad mini portrait (<800pt) or mini landscape (900–1150pt)
    private var isMini: Bool {
        contentWidth < 800 || (contentWidth >= 900 && contentWidth < 1150)
    }

    // Cached Text built from the log — rebuilt only when entry count or font size changes.
    @State private var builtText: Text = Text("")

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 1).id("top")

                        if appState.statusLog.isEmpty {
                            Text("Ready — press Generate to create a song.")
                                .foregroundStyle(.secondary)
                                .font(.system(size: fontBody, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            // Single Text view built from all entries so drag-selection
                            // spans the entire log (multiple Text views create isolated
                            // selection islands that cannot be bridged).
                            builtText
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    #if os(iOS)
                    .padding(.leading, 15)
                    .padding(.trailing, 10)
                    #else
                    .padding(.horizontal, 10)
                    #endif
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
                #if os(iOS)
                // iPad mini (portrait <800pt, landscape 900–1150pt): smaller minimum so
                // track rows get their full 7×63pt. Other iPads get ≥3 lines.
                .frame(minHeight: isMini ? 44 : 63)
                #else
                .frame(minHeight: 0)    // shrinks first (layoutPriority 0) when window height is reduced
                #endif
                .background(Color(white: 0.10))
                .onAppear { builtText = buildLogText() }
                .onChange(of: appState.statusLogVersion) { _ in
                    builtText = buildLogText()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                .onChange(of: contentWidth) { _ in
                    // Rebuild when screen rotates — font size may change for iPad mini
                    builtText = buildLogText()
                }
                .onChange(of: appState.statusLogFontOffset) { _ in
                    builtText = buildLogText()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }
        }
    }

    // Build the entire log as a single AttributedString so text selection spans all lines.
    // AttributedString appending is O(n) total — avoids the O(n²) cost of chaining
    // SwiftUI Text structs via + (each + copies the entire accumulated value so far).
    private func buildLogText() -> Text {
        let entries = appState.statusLog
        guard !entries.isEmpty else { return Text("") }

        var attrStr = AttributedString()

        #if os(macOS)
        let uiFont     = NSFont.monospacedSystemFont(ofSize: fontBody, weight: .regular)
        let uiFontBold = NSFont.monospacedSystemFont(ofSize: fontBody, weight: .bold)
        let tagColor       = NSColor(Color.green.opacity(0.85))
        let tagTitleColor  = NSColor.white
        let descColor      = NSColor(Color.white.opacity(0.85))
        let descTitleColor = NSColor(Color.yellow.opacity(0.95))
        #else
        let uiFont     = UIFont.monospacedSystemFont(ofSize: fontBody, weight: .regular)
        let uiFontBold = UIFont.monospacedSystemFont(ofSize: fontBody, weight: .bold)
        let tagColor       = UIColor(Color.green.opacity(0.85))
        let tagTitleColor  = UIColor.white
        let descColor      = UIColor(Color.white.opacity(0.85))
        let descTitleColor = UIColor(Color.yellow.opacity(0.95))
        #endif

        for (i, entry) in entries.enumerated() {
            let tag = entry.tag.padding(toLength: tagWidth, withPad: " ", startingAt: 0)
            let font = entry.isTitle ? uiFontBold : uiFont

            var tagAttr = AttributedString(tag)
            tagAttr.font = font
            tagAttr.foregroundColor = entry.isTitle ? tagTitleColor : tagColor

            var descAttr = AttributedString(entry.description)
            descAttr.font = font
            descAttr.foregroundColor = entry.isTitle ? descTitleColor : descColor

            if i > 0 {
                var nl = AttributedString("\n")
                nl.font = uiFont
                attrStr += nl
            }
            attrStr += tagAttr
            attrStr += descAttr
        }

        return Text(attrStr)
    }
}
