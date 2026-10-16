// ChillLeadRegisterTests.swift — pins Chill's leads inside their instrument's register.
//
// Run with:
//   swift test --filter ChillLeadRegisterTests
//
// WHY THIS EXISTS
// ---------------
// Zudio carries TWO register systems and they do not agree:
//
//   kRegisterBounds           per track    Lead 1 is 52–79
//   ChillLeadGenerator.register(for:)  per instrument   tenor sax is 57–72, flute 65–85
//
// The per-instrument one is the one that matters for Chill — a tenor sax tops out well below
// Lead 1's track ceiling — but only the lead GENERATORS consulted it. `HarmonicFilter`'s Pass B,
// which lifts lead notes above the pad median by an octave, used the track bound, so it pushed
// notes into the gap between the two: measured 2026-10-14, 41% of tenor and alto sax notes
// finished above their own ceiling, at 78–79 where the instrument is in altissimo. That is what
// Zack heard as "too high and screechy".
//
// The lead generators themselves were blameless — they produced ZERO out-of-range notes. Every
// violation was created afterwards, which is exactly the kind of fault that is invisible unless
// something pins the finished song rather than the generator.
//
// So this checks the OUTPUT, for every Chill form and both leads.

import Testing
@testable import Zudio

@Suite struct ChillLeadRegisterTests {

    /// A regenerated Chill lead gets the passes a generated one does: it stays inside its
    /// instrument's register and out of bar 0 when the song has no intro. Regeneration once
    /// skipped the harmonic filter, the fold and the bar-0 rule (found 2026-10-16).
    @Test func regeneratedLeadsGetTheSamePasses() {
        var checked = 0
        for seed in UInt64(1)...120 {
            let s = SongGenerator.generate(seed: seed, style: .chill)
            let noIntro = !s.structure.sections.contains { $0.label == .intro && $0.lengthBars > 0 }
            for (track, inst) in [(kTrackLead1, s.chillLeadInstrument), (kTrackLead2, s.chillLead2Instrument)] {
                let r = SongGenerator.regenerateTrack(track, songState: s, overrideSeed: seed &+ 99)
                let (low, high) = ChillLeadGenerator.register(for: inst)
                for e in r.trackEvents[track] {
                    #expect(Int(e.note) >= low && Int(e.note) <= high,
                            "seed \(seed) track \(track): note \(e.note) outside \(low)-\(high)")
                    if noIntro { #expect(e.stepIndex >= 16, "seed \(seed) track \(track): bar 0 with no intro") }
                }
                checked += 1
            }
        }
        #expect(checked > 0)
    }

    @Test func everyChillLeadNoteIsInsideItsInstrumentRegister() {
        var checked = 0
        var worst: (inst: String, note: Int, low: Int, high: Int)? = nil
        var violations = 0, total = 0

        for seed in UInt64(1)...400 {
            let s = SongGenerator.generate(seed: seed, style: .chill)
            checked += 1
            for (track, instrument) in [(kTrackLead1, s.chillLeadInstrument),
                                        (kTrackLead2, s.chillLead2Instrument)] {
                let r = ChillLeadGenerator.register(for: instrument)
                for e in s.trackEvents[track] {
                    total += 1
                    let n = Int(e.note)
                    guard n < r.low || n > r.high else { continue }
                    violations += 1
                    if worst == nil { worst = ("\(instrument)", n, r.low, r.high) }
                }
            }
        }
        var detail = "none"
        if let w = worst {
            detail = w.inst + " played " + String(w.note)
                   + ", register " + String(w.low) + "-" + String(w.high)
        }
        let why = String(violations) + " of " + String(total)
                + " Chill lead notes sit outside their instrument's register; first was " + detail
        #expect(checked > 0)
        #expect(violations == 0, Comment(rawValue: why))
    }

    /// `fold` moves a note by octaves, so every Chill lead register must be at least an octave
    /// wide or it degenerates to a clamp — which squashes a melody onto one note instead of
    /// transposing it. This is the invariant the safety fold in `generateChill` depends on.
    @Test func everyChillLeadRegisterIsAtLeastAnOctave() {
        let instruments: [ChillLeadInstrument] = [.tenorSax, .saxophone, .flute, .sopranoSax,
                                                  .recorder, .mutedTrumpet, .trumpet, .clarinet,
                                                  .trombone, .vibraphone, .synthBrass]
        for i in instruments {
            let r = ChillLeadGenerator.register(for: i)
            #expect(r.high - r.low >= 12,
                    Comment(rawValue: "\(i) register \(r.low)-\(r.high) is narrower than an octave"))
        }
    }

    /// The per-track bounds in `kRegisterBounds` are style-agnostic and SHARED with Motorik,
    /// Kosmic and Ambient; the per-instrument registers are Chill's own and may legitimately
    /// reach past them — a flute lead runs to 85 where Lead 1's generic ceiling is 79. The two
    /// are not meant to agree, so nothing here asserts that they do. What matters is that the
    /// instrument register wins for Chill, which the test above checks on the finished song.
    @Test func theTwoTablesAreAllowedToDiffer() {
        let flute = ChillLeadGenerator.register(for: .flute)
        let track = kRegisterBounds[kTrackLead1]!
        #expect(flute.high > track.high, "if these ever align, this note is stale")
    }
}
