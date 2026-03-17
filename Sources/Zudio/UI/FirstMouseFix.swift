// FirstMouseFix.swift — makes a region accept mouse events without requiring window focus first.
// Apply as .background(FirstMouseFix()) to any area that should respond on first click.

import SwiftUI
import AppKit

struct FirstMouseFix: NSViewRepresentable {
    func makeNSView(context: Context) -> FirstMouseNSView { FirstMouseNSView() }
    func updateNSView(_ nsView: FirstMouseNSView, context: Context) {}
}

final class FirstMouseNSView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { false }
}
