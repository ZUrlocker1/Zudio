// StatusBoxView.swift — 3-5 line scrollable generation log (spec §Status box)
// Shows: form, progression, bar counts, chord sequence, per-track rule notes.
// No seed values, no timestamps, no transport event logs.

import SwiftUI

struct StatusBoxView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 3) {
                    if let song = appState.songState {
                        statusLines(song)
                    } else {
                        Text("Ready — press Generate to create a Motorik song.")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 240)
            .background(Color(white: 0.10))
        }
    }

    // MARK: - Build status lines from SongState

    @ViewBuilder
    private func statusLines(_ song: SongState) -> some View {
        let structure = song.structure
        let frame     = song.frame

        // Line 1: form + progression + bar counts
        let bodyBars = structure.bodySections.map { "\($0.label.rawValue)=\($0.lengthBars)b" }.joined(separator: " ")
        let introBars = structure.introSection.map { "intro=\($0.lengthBars)b" } ?? ""
        let outroBars = structure.outroSection.map { "outro=\($0.lengthBars)b" } ?? ""
        statusLine("Form",  "\(formLabel(song.form)), \(introBars) \(bodyBars) \(outroBars)".trimmingCharacters(in: .whitespaces))

        // Line 2: chord sequence (Nashville notation)
        let chords = structure.chordPlan.map { cw in "\(cw.chordRoot)\(chordTypeShort(cw.chordType))" }.joined(separator: "–")
        statusLine("Chords", chords.isEmpty ? "—" : chords)

        // Line 3: key / mode / tempo / progression
        statusLine("GBL-001", "\(frame.key) \(frame.mode.rawValue), \(frame.tempo) BPM, progression: \(frame.progressionFamily.rawValue)")

        // Line 4: track rule summary (spec §Required generation messages)
        statusLine("DRM-001", "Drums: 4-on-the-floor kick, closed-hat grid, sparse intro, sub-phase intensity arc")
        statusLine("BAS-001", "Bass: chord-root anchor beat 1, passing tones on beat 3, syncopated off-beats \(Int(Double(frame.tempo)*0.7))%")
        statusLine("PAD-001", "Pads: open 4-note voicing (root–fifth–oct–third), one chord per window, \(song.structure.chordPlan.count) windows")
        statusLine("LD1-001", "Lead 1: motif-first, chord tones strong beats 80%, scale tensions 20%")
        statusLine("LD2-001", "Lead 2: counter-response, density ≤55% of Lead 1, avoids simultaneous accents")
        statusLine("RHY-001", "Rhythm: 2-bar repeating ostinato, chord-root pitch, 8th or quarter-note stride")
        statusLine("TEX-001", "Texture: sparse, boundary-weighted, scale tensions preferred")

        // Line 5: outro/intro notes
        if let intro = structure.introSection {
            statusLine("STR-INT", "Intro: \(intro.lengthBars) bars, drums-only start → sparse enter bar 2+")
        }
        if let outro = structure.outroSection {
            statusLine("STR-OUT", "Outro: \(outro.lengthBars) bars, sparse/low intensity layer drop")
        }
    }

    private func statusLine(_ ruleId: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(ruleId)
                .foregroundStyle(.green.opacity(0.8))
                .frame(width: 72, alignment: .leading)
            Text(text)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
        }
    }

    private func formLabel(_ form: SongForm) -> String {
        switch form {
        case .singleA:    return "Single-A"
        case .subtleAB:   return "Subtle A/B"
        case .moderateAB: return "Moderate A/B"
        }
    }

    private func chordTypeShort(_ t: ChordType) -> String {
        switch t {
        case .major:   return ""
        case .minor:   return "m"
        case .sus2:    return "sus2"
        case .sus4:    return "sus4"
        case .dom7:    return "7"
        case .min7:    return "m7"
        case .add9:    return "add9"
        case .quartal: return "qrt"
        case .power:   return "5"
        }
    }
}
