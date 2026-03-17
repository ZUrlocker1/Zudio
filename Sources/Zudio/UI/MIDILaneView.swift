// MIDILaneView.swift — Canvas-based piano-roll. Uses Canvas (macOS 12+) for reliable
// rendering of all 7 tracks. ZStack+Rectangle had SwiftUI rendering gaps for sparse tracks.

import SwiftUI

struct MIDILaneView: View {
    let events: [MIDIEvent]
    let totalBars: Int
    let currentStep: Int
    let isDrumTrack: Bool
    var trackColor: Color = .white

    private let noteH: CGFloat = 7   // note rectangle height in points

    var body: some View {
        Canvas { ctx, size in
            drawLane(ctx: ctx, size: size)
        }
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Main draw

    private func drawLane(ctx: GraphicsContext, size: CGSize) {
        let totalSteps = max(1, totalBars * 16)
        let w = size.width
        let h = size.height

        // Bar lines
        for bar in 0..<totalBars {
            let x = CGFloat(bar * 16) / CGFloat(totalSteps) * w
            let alpha: Double = bar % 4 == 0 ? 0.14 : 0.05
            ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: h)),
                     with: .color(.white.opacity(alpha)))
        }

        // Drum lane separators
        if isDrumTrack {
            for norm in drumLaneNorms {
                let y = norm * (h - noteH)
                ctx.fill(Path(CGRect(x: 0, y: y + noteH, width: w, height: 1)),
                         with: .color(.white.opacity(0.07)))
            }
        }

        // Notes — drawn with full trackColor for vivid, clear representation
        let (lo, hi) = pitchRange
        for ev in events {
            let x  = CGFloat(ev.stepIndex)    / CGFloat(totalSteps) * w
            let nw = max(4, CGFloat(ev.durationSteps) / CGFloat(totalSteps) * w)
            let y  = rawNoteY(note: Int(ev.note), lo: lo, hi: hi, height: h)
            let col = noteColor(for: Int(ev.note))
            ctx.fill(Path(CGRect(x: x, y: max(0, min(h - noteH, y)), width: nw, height: noteH)),
                     with: .color(col))
        }

        // Playhead
        let px = CGFloat(currentStep) / CGFloat(totalSteps) * w
        ctx.fill(Path(CGRect(x: px, y: 0, width: 2, height: h)),
                 with: .color(.white.opacity(0.9)))
    }

    // MARK: - Y calculation

    private func rawNoteY(note: Int, lo: Int, hi: Int, height: CGFloat) -> CGFloat {
        if isDrumTrack { return drumY(for: note, height: height) }
        let span = CGFloat(max(1, hi - lo))
        return (1.0 - CGFloat(note - lo) / span) * (height - noteH)
    }

    private func drumY(for note: Int, height: CGFloat) -> CGFloat {
        let norms: [Int: CGFloat] = [
            49: 0.04, 57: 0.04,           // crash
            51: 0.15, 53: 0.15, 55: 0.15, // ride/cymbal
            46: 0.26,                      // open hi-hat
            42: 0.36, 44: 0.36,           // closed hi-hat / pedal
            48: 0.48, 50: 0.48,           // hi/mid tom
            37: 0.58, 39: 0.58,           // side stick / clap
            38: 0.67, 40: 0.67,           // snare
            41: 0.77, 43: 0.77, 45: 0.77, 47: 0.77, // floor toms
            35: 0.90, 36: 0.90            // kick
        ]
        let norm = norms[note] ?? 0.50
        return norm * (height - noteH)
    }

    private let drumLaneNorms: [CGFloat] = [0.04, 0.15, 0.26, 0.36, 0.48, 0.58, 0.67, 0.77, 0.90]

    // Fit pitch range to actual event content with a minimum 12-semitone span
    private var pitchRange: (Int, Int) {
        let notes = events.map { Int($0.note) }
        guard !notes.isEmpty else { return (48, 84) }
        let lo = max(notes.min()! - 3, 0)
        let hi = min(notes.max()! + 3, 127)
        return hi - lo < 12 ? (lo, lo + 12) : (lo, hi)
    }

    // MARK: - Colors — vivid, fully opaque

    private func noteColor(for note: Int) -> Color {
        if isDrumTrack {
            switch note {
            case 35, 36:     return trackColor           // kick — full
            case 38, 40:     return trackColor.opacity(0.85) // snare
            case 42, 44, 46: return trackColor.opacity(0.60) // hi-hat
            default:         return trackColor.opacity(0.75)
            }
        }
        // Melodic: slight octave-based brightness variation, always vivid
        let oct = min(max(note / 12, 0), 8)
        return trackColor.opacity(0.72 + Double(oct % 4) * 0.07)
    }
}
