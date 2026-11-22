// ChillBassSlides.swift — slides into bass notes, Chill Soho and Chill Blues
// Copyright (c) 2026 Zack Urlocker
//
// A slide is one finger moving along the string: the note before the target is plucked, held,
// and slid into the target, which is never plucked again. Playback and export play the two
// written notes as one held note (the earlier note's key, from its start to the target's end)
// and bend it to the target's pitch, arriving exactly on the target's start. The notes in the
// song are unchanged, so the MIDI lane, MIDI export, fingerprints and saved songs are as written;
// playback and export both read the slides from this pure function of the finished song.
//
// Measured from the corpus bass channels (scratchpad bendshape.py, 2026-10-15). Every bass bend
// in the fourteen records is a slide UP INTO a note, by a whole step (most) or a half step, gliding
// over one to two sixteenths. How often varies widely: Holding Back the Years' fretless about one
// per 8 bars, always on the same note of its figure; Black Cow 1.3 per 8 bars, also tied to the
// riff; Smooth Operator twice in 144 bars; Your Love Is King once in 86. Soho also slides down
// into a note the line falls to (Zack, 2026-10-15).
//
// Scope: Chill Soho songs on CHL-BASS-014 Best Melodic Bass, the fretless rule, and the root
// that lands after each of their turnarounds; and Chill Blues songs on CHL-BASS-009, the B.B.
// King pickup riff, into the root at the top of every form. Independent of the instrument.
//
// The shape, after Ambient Zen's Slow Glide (Zack, 2026-11-22): no new attack, the glide starts
// early so the target is in tune on its beat, and the pitch eases off the first note and settles
// into the target. Blues glides over at most a sixteenth and a half, Soho two.

import Foundation

struct BassSlide: Equatable, Sendable {
    /// The step of the earlier note, whose key is held through the slide.
    let fromStep: Int
    /// The step of the target note, where the pitch arrives.
    let landStep: Int
    /// The target's pitch less the held key's: -3 to +3 semitones.
    let semitones: Int
    /// How long the glide takes, in sixteenth steps; it ends on landStep.
    let glideSteps: Double

    /// When the glide starts, in steps (fractional).
    var glideStart: Double { Double(landStep) - glideSteps }
}

enum ChillBassSlides {

    /// The pitch-bend range the bass channel is set to for a song with slides, as Slow Glide's, so
    /// the Vibrato effect's wide-range path rides on it unchanged.
    static let bendRange = ZenBassGlide.bendRange
    /// The longest gap a held note bridges between the two notes: an eighth. Over a longer rest
    /// the slide would fill a silence the line wants.
    static let maxGapSteps = 2

    /// Slides keyed by the step of the note they lead into. Empty for anything out of scope.
    static func slides(for state: SongState) -> [Int: BassSlide] {
        guard state.style == .chill else { return [:] }
        let rule = currentBassRule(state)
        let soho  = state.chillSohoVariation && rule == "CHL-BASS-014"
        let blues = state.chillBluesVariation && rule == "CHL-BASS-009"
        guard soho || blues else { return [:] }
        let notes = state.trackEvents[kTrackBass].sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }
        guard notes.count > 1 else { return [:] }

        // Its own stream, mixed with the bass track's regenerate seed, so a regenerated bass line
        // gets its own slides and nothing else in the song moves.
        var rng = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: state.globalSeed, trackIndex: 110)
                            ^ (state.trackOverrides[kTrackBass] ?? 0))

        // The note before each note, when both stand alone on their steps (a slide is one string).
        var notesAt: [Int: Int] = [:]
        for n in notes { notesAt[n.stepIndex, default: 0] += 1 }
        var previous: [Int: MIDIEvent] = [:]
        for (a, b) in zip(notes, notes.dropFirst())
            where a.stepIndex < b.stepIndex && notesAt[a.stepIndex] == 1 && notesAt[b.stepIndex] == 1 {
            previous[b.stepIndex] = a
        }

        var slides: [Int: BassSlide] = [:]
        var used: Set<Int> = []   // steps already part of a slide, so two never chain
        let maxGlide = blues ? 1.5 : 2.0

        // Slidable: a move of a half step to a minor third from the note before (the corpus slides
        // a half or whole step), close enough (a gap of an eighth at most) to be held into this
        // one. A wider slide reads as a siren; into a repeated note it is a bend.
        func slidable(_ note: MIDIEvent) -> Bool {
            guard let a = previous[note.stepIndex],
                  !used.contains(a.stepIndex), !used.contains(note.stepIndex) else { return false }
            let move = abs(Int(note.note) - Int(a.note))
            return move >= 1 && move <= 3 && note.stepIndex - (a.stepIndex + a.durationSteps) <= maxGapSteps
        }
        func slide(_ note: MIDIEvent) {
            guard let a = previous[note.stepIndex] else { return }
            // At most half the earlier note's span, so that note is heard at pitch first.
            let glide = Swift.min(maxGlide, Double(note.stepIndex - a.stepIndex) * 0.5)
            slides[note.stepIndex] = BassSlide(fromStep: a.stepIndex, landStep: note.stepIndex,
                                               semitones: Int(note.note) - Int(a.note), glideSteps: glide)
            used.insert(a.stepIndex); used.insert(note.stepIndex)
        }

        // Chill Blues, the B.B. King pickup riff (CHL-BASS-009): up into the root at the top of
        // every form, from the riff's last note below it. Every form, so it is part of the riff.
        // The IV and V are reached from above, where a slide reads as a pull-off (2026-10-15).
        if blues {
            for note in notes.dropFirst() where note.stepIndex % 16 == 0 && slidable(note)
                    && note.note > (previous[note.stepIndex]?.note ?? 255) {
                let bar = note.stepIndex / 16
                guard let s = state.structure.section(atBar: bar), s.label == .A || s.label == .B,
                      (bar - s.startBar) % 16 == 0 else { continue }
                slide(note)
            }
            return slides
        }

        // The root after each turnaround slides half the time, so the return is audible.
        let landings = Set(ChillStructureGenerator.sohoTurnarounds(frame: state.frame, structure: state.structure)
                               .exits.map { ($0 + 1) * 16 })
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

    /// The bass notes as played with these slides: each slide's two notes become one, on the
    /// earlier note's key, from its start to the target's end. Unchanged when there are none.
    static func played(_ events: [MIDIEvent], slides: [Int: BassSlide]) -> [MIDIEvent] {
        guard !slides.isEmpty else { return events }
        let byFrom = Dictionary(uniqueKeysWithValues: slides.values.map { ($0.fromStep, $0) })
        let lands  = Set(slides.keys)
        let ends   = Dictionary(events.filter { lands.contains($0.stepIndex) }
                                    .map { ($0.stepIndex, $0.stepIndex + $0.durationSteps) },
                                uniquingKeysWith: { Swift.max($0, $1) })
        var out: [MIDIEvent] = []
        out.reserveCapacity(events.count)
        for e in events {
            if lands.contains(e.stepIndex) { continue }
            if let s = byFrom[e.stepIndex], let end = ends[s.landStep] {
                out.append(MIDIEvent(stepIndex: e.stepIndex, note: e.note, velocity: e.velocity,
                                     durationSteps: Swift.max(e.stepIndex + e.durationSteps, end) - e.stepIndex))
            } else {
                out.append(e)
            }
        }
        return out
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

    /// How far through the move the pitch is at `t` (0–1) through the glide: eased at both ends,
    /// so it leaves the first note gently, moves fastest mid-way and settles into the target.
    static func progress(_ t: Double) -> Double {
        let c = Swift.max(0, Swift.min(1, t))
        return 0.5 - 0.5 * cos(Double.pi * c)
    }

    /// The 14-bit pitch-bend value for `semitones` at the slide range of ±12.
    static func bendValue(semitones: Double) -> Int { ZenBassGlide.bendValue(semitones: semitones) }
}
