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

    /// When true, shows a "Generation Log  [−] [+]" header bar above the log.
    /// Used when StatusBoxView fills the full Log tab (iPhone / iPad) rather than
    /// sitting below the scrollbar strip that already contains these controls.
    var showHeader: Bool = false

    /// When true, the header row is rendered at 1.5× height with larger text/buttons.
    /// Used by PhonePlayerView on iPhone; iPad and Mac use the default compact size.
    var largeHeader: Bool = false

    /// Optional reset action — when provided, a red "Reset" button appears in the
    /// header to the left of the − and + font-size buttons.
    var onReset: (() -> Void)? = nil

    // Tag column fixed width in monospaced chars (must exceed longest rule ID + space)
    private let tagWidth = 15

    // Scales with the user's Dynamic Type setting so the log text honours
    // their preferred reading size. The +/- buttons then nudge within that scale.
    #if os(iOS)
    @ScaledMetric(relativeTo: .body) private var scaledBase: CGFloat = 14
    #endif

    // Body font: the generated log entries. Scales with Dynamic Type on iOS;
    // further adjusted by +/- buttons via statusLogFontOffset.
    private var fontBody: CGFloat {
        let base: CGFloat
        #if os(macOS)
        base = 12
        #else
        base = isMini ? min(scaledBase, 12) : scaledBase
        #endif
        return max(8, min(28, base + CGFloat(appState.statusLogFontOffset)))
    }
    // iPad mini portrait (<800pt) or mini landscape (900–1150pt)
    private var isMini: Bool {
        contentWidth < 800 || (contentWidth >= 900 && contentWidth < 1150)
    }

    // Cached Text built from the log — rebuilt only when entry count or font size changes.
    @State private var builtText: Text = Text("")
    @State private var minusFlash: Bool = false
    @State private var plusFlash:  Bool = false

    // Pinch-to-zoom state — captures the offset at gesture start so successive
    // onChanged values (always relative to gesture origin) apply cleanly.
    @State private var pinchBaseOffset: Int = 0
    @State private var pinching: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header — "Generation Log" label + font-size ±buttons.
            // Only shown when embedded as a standalone Log tab panel (not below the
            // scrollbar strip in the Tracks tab, which already contains these controls).
            if showHeader {
                let hdrFontSize: CGFloat  = largeHeader ? 15 : 11
                let btnSize: CGFloat      = largeHeader ? 18 : 13
                let btnPadH: CGFloat      = largeHeader ? 6  : 4
                let btnPadV: CGFloat      = largeHeader ? 4  : 2
                let hdrHeight: CGFloat    = largeHeader ? 51 : 34
                HStack(spacing: largeHeader ? 12 : 8) {
                    Text("Generation Log")
                        .font(.system(size: hdrFontSize, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.70))
                    Button {
                        appState.statusLogFontOffset = max(-4, appState.statusLogFontOffset - 1)
                        minusFlash = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { minusFlash = false }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: btnSize, height: btnSize)
                            .padding(.horizontal, btnPadH)
                            .padding(.vertical, btnPadV)
                            .background(minusFlash ? Color.white.opacity(0.55) : Color(white: 0.30),
                                        in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(white: 0.55), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .font(.system(size: hdrFontSize, weight: .medium))
                    .disabled(appState.statusLogFontOffset <= -4)
                    Button {
                        appState.statusLogFontOffset = min(8, appState.statusLogFontOffset + 1)
                        plusFlash = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { plusFlash = false }
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: btnSize, height: btnSize)
                            .padding(.horizontal, btnPadH)
                            .padding(.vertical, btnPadV)
                            .background(plusFlash ? Color.white.opacity(0.55) : Color(white: 0.30),
                                        in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(white: 0.55), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .font(.system(size: hdrFontSize, weight: .medium))
                    .disabled(appState.statusLogFontOffset >= 8)
                    if appState.songState != nil {
                        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                            Text(String(format: "Bar: %03d", appState.playback.currentBar + 1))
                                .font(.system(size: hdrFontSize, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.90))
                        }
                        .padding(.leading, largeHeader ? 12 : 8)
                    }
                    Spacer()
                    if let onReset {
                        Button(action: onReset) {
                            Text("Reset")
                                .font(.system(size: hdrFontSize, weight: .semibold))
                                .foregroundStyle(Color.red)
                                .padding(.horizontal, largeHeader ? 10 : 6)
                                .padding(.vertical, btnPadV)
                                .background(Color(white: 0.20), in: RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.red.opacity(0.5), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: hdrHeight)
                .dynamicTypeSize(.large)
                .background(Color(white: 0.13))
            }

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
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            guard UIDevice.current.userInterfaceIdiom == .phone else { return }
                            if !pinching {
                                pinching = true
                                pinchBaseOffset = appState.statusLogFontOffset
                            }
                            let delta = Int(round((scale - 1.0) * 6))
                            appState.statusLogFontOffset = max(-4, min(8, pinchBaseOffset + delta))
                        }
                        .onEnded { _ in
                            guard UIDevice.current.userInterfaceIdiom == .phone else { return }
                            pinching = false
                            pinchBaseOffset = appState.statusLogFontOffset
                        }
                )
                #endif
                #if os(iOS)
                // iPad mini (portrait <800pt, landscape 900–1150pt): smaller minimum so
                // track rows get their full 7×63pt. Other iPads get ≥3 lines.
                .frame(minHeight: isMini ? 44 : 63)
                #else
                .frame(minHeight: 0)    // shrinks first (layoutPriority 0) when window height is reduced
                #endif
                .background(Color(white: 0.10))
                .onAppear {
                    builtText = buildLogText()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
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
        // Ensure the VStack always fills the full proposed width so the header's Spacer
        // pushes the +/- buttons to the true right edge regardless of log content width.
        .frame(maxWidth: .infinity)
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
