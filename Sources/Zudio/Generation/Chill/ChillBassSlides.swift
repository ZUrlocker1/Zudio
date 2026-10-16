// ChillBassSlides.swift — slides into bass notes, Chill Soho
// Copyright (c) 2026 Zack Urlocker
//
// A slide is a pitch-bend gesture laid over a note that is already in the bass track: the note
// starts one or two semitones flat and glides up to pitch. Nothing in the notes changes, so the
// MIDI lane, the fingerprints and every saved song are exactly as they were; playback and export
// both read the slides from this pure function of the finished song.
//
// Measured from the corpus bass channels (scratchpad bendshape.py, 2026-10-15). Every bass bend
// in the fourteen records is a slide UP INTO a note, by a whole step (most) or a half step, gliding
// over one to two sixteenths — a slide on one string, which is all a bass player can do between
// two notes. How often varies widely: Holding Back the Years' fretless about one per 8 bars,
// always on the same note of its figure; Black Cow 1.3 per 8 bars, also tied to the riff; Smooth
// Operator twice in 144 bars; Your Love Is King once in 86.
//
// Scope, for the first listen (Zack, 2026-10-15): Chill Soho songs on CHL-BASS-014 Best Melodic
// Bass, the fretless rule, and the root that lands after each of their turnarounds; and Chill
// Blues songs on CHL-BASS-009, the B.B. King pickup riff, into the IV and V. Independent of the
// instrument — any bass can slide.

import Foundation

struct BassSlide: Equatable, Sendable {
    /// Where the glide starts, in semitones from the written note: -2 or -1 below, +1 or +2
    /// above. Inside the sampler's default ±2 semitone bend range, so no range change is needed.
    let fromSemitones: Int
    /// How long the glide takes, in sixteenth steps.
    let glideSteps: Double
}

enum ChillBassSlides {

    /// Slides keyed by the step of the note they lead into. Empty for anything out of scope.
    static func slides(for state: SongState) -> [Int: BassSlide] {
        guard state.style == .chill else { return [:] }
        let rule = currentBassRule(state)
        let soho  = state.chillSohoVariation && rule == "CHL-BASS-014"
        let blues = state.chillBluesVariation && rule == "CHL-BASS-009"
        guard soho || blues else { return [:] }
        let notes = state.trackEvents[kTrackBass].sorted { $0.stepIndex < $1.stepIndex }
        guard notes.count > 1 else { return [:] }

        // Its own stream, mixed with the bass track's regenerate seed, so a regenerated bass line
        // gets its own slides and nothing else in the song moves.
        var rng = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: state.globalSeed, trackIndex: 110)
                            ^ (state.trackOverrides[kTrackBass] ?? 0))

        var slides: [Int: BassSlide] = [:]
        var previous: [Int: UInt8] = [:]
        for (a, b) in zip(notes, notes.dropFirst()) { previous[b.stepIndex] = a.note }
        func slide(_ note: MIDIEvent) {
            // A whole step (most of the corpus) or a half step, from the side the line is coming
            // from: up from below after a lower note, down from above after a higher one. Sliding
            // up into a note the line falls to read as a bend rather than a slide (Zack,
            // 2026-10-15). Two and a half sixteenths, but never more than half the note, so the
            // note is heard at pitch for most of its length — at three quarters of a quarter note
            // it still moved too long and read as a bend.
            // From a note a half or whole step away the slide starts ON that note — one finger
            // moving along the string, its starting pitch one the listener just heard.
            let move     = abs(Int(note.note) - Int(previous[note.stepIndex] ?? note.note))
            let distance = move <= 2 ? move : (rng.nextDouble() < 0.65 ? 2 : 1)
            let falling  = (previous[note.stepIndex] ?? 0) > note.note
            slides[note.stepIndex] = BassSlide(fromSemitones: falling ? distance : -distance,
                                               glideSteps: Swift.min(2.5, Double(note.durationSteps) * 0.5))
        }
        // Only after a move of a half step to a fourth. After a wider leap the starting pitch
        // comes from nowhere and is heard as a scoop; into a repeated note it is a bend.
        func slidable(_ note: MIDIEvent) -> Bool {
            let move = abs(Int(note.note) - Int(previous[note.stepIndex] ?? note.note))
            return move >= 1 && move <= 5
        }

        // Chill Blues, the B.B. King pickup riff (CHL-BASS-009). Zack slides into the IV and V
        // playing The Thrill Is Gone, but this riff reaches those roots from above, so a slide
        // there goes down and reads as a pull-off (2026-10-15). It slides up into the root at the
        // top of every form instead, where the turnaround ends on the b7 below it. Every form, so
        // it is part of the riff: one that came and went (three times in four, plus occasional
        // extras) sounded arbitrary in a form this repetitive. And small — a half step over a
        // sixteenth and a half — since a whole step over most of a beat sounded artificial.
        if blues {
            for note in notes.dropFirst() where note.stepIndex % 16 == 0 && slidable(note)
                    && note.note > (previous[note.stepIndex] ?? 255) {
                let bar = note.stepIndex / 16
                guard let s = state.structure.section(atBar: bar), s.label == .A || s.label == .B,
                      (bar - s.startBar) % 16 == 0 else { continue }
                slides[note.stepIndex] = BassSlide(fromSemitones: -1,
                                                   glideSteps: Swift.min(1.5, Double(note.durationSteps) * 0.5))
            }
            return slides
        }

        // The root after each turnaround slides in half the time, so the return is audible.
        let turns = ChillStructureGenerator.sohoTurnaroundBars(frame: state.frame, structure: state.structure)
        let landings = Set(turns.filter { !turns.contains($0 + 1) }.map { ($0 + 1) * 16 })
        // Slides stay at least four bars apart: two in neighbouring bars read as a habit, not a
        // gesture (Zack, 2026-10-15). Landings are placed first and take priority.
        func clear(_ bar: Int) -> Bool { !slides.keys.contains { abs($0 / 16 - bar) < 4 } }
        for note in notes.dropFirst() where landings.contains(note.stepIndex) && slidable(note) {
            if clear(note.stepIndex / 16) && rng.nextDouble() < 0.5 { slide(note) }
        }
        // Otherwise a note held a quarter or longer slides in 5% of the time.
        for note in notes.dropFirst() where !landings.contains(note.stepIndex)
                && note.durationSteps >= 4 && slidable(note) {
            if clear(note.stepIndex / 16) && rng.nextDouble() < 0.05 { slide(note) }
        }
        return slides
    }

    /// The song with a "Bass slide" line on the bar of each slide, replacing any from before a
    /// regenerate. Slides are not in the notes, so the log is the only place to see them.
    static func annotated(_ state: SongState) -> SongState {
        var notes = state.stepAnnotations
        for key in notes.keys {
            notes[key]?.removeAll { $0.tag == "Bass" && $0.description == "slide" }
            if notes[key]?.isEmpty == true { notes.removeValue(forKey: key) }
        }
        for step in slides(for: state).keys.sorted() {
            notes[step / 16 * 16, default: []].append(GenerationLogEntry(tag: "Bass", description: "slide"))
        }
        return state.replacingEvents(state.trackEvents[kTrackBass], forTrack: kTrackBass,
                                     appendingLog: [], replacingStepAnnotations: notes)
    }

    /// The bass rule the song is playing now. A regenerated bass appends its rule to the log, so
    /// the last bass rule listed is the current one; the breakdown drone (005) is not a groove rule.
    private static func currentBassRule(_ state: SongState) -> String? {
        state.generationLog.last { $0.tag.hasPrefix("CHL-BASS-") && $0.tag != "CHL-BASS-005" }?.tag
    }

    /// How far from pitch the note still is, as a fraction of the slide, at `t` (0–1) through the
    /// glide. The starting note holds for the first quarter so it is heard, then the pitch moves
    /// steadily, as a finger along the frets does. An eased curve that left at once read as a
    /// bend (Zack, 2026-10-15).
    static func remaining(_ t: Double) -> Double {
        t < 0.25 ? 1 : Swift.max(0, 1 - (t - 0.25) / 0.75)
    }

    /// The 14-bit pitch-bend value for a bend of `semitones` (negative is flat), at the GM
    /// default range of ±2 semitones.
    static func bendValue(semitones: Double) -> Int {
        Swift.max(0, Swift.min(16383, Int((8192.0 + semitones / 2.0 * 8192.0).rounded())))
    }
}
