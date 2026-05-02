// ChillPadsGenerator.swift — Chill generation step 5 (Pads track)
// Copyright (c) 2026 Zack Urlocker
// Pads = sustained harmonic layer (Warm Pad default) — NOT Rhodes comping.
// Pad rules (equally weighted for testing): CHL-PAD-001 chord sustain, CHL-PAD-002 staggered entry,
//   CHL-PAD-003 Moby anchor, CHL-PAD-004 open fifth hold, CHL-PAD-005 slow chord build,
//   CHL-PAD-006 Portishead string hold, CHL-PAD-007 absent.
// All voicings snapped to scale (CHL-SYNC-004).
// Per-note audio fade-in/fade-out is handled by PlaybackEngine.chillPadsMode (boost node ramp),
// not via MIDI velocity — identical mechanism to Ambient bass/pads.

import Foundation

struct ChillPadsGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        breakdownStyle: ChillBreakdownStyle,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let roll = rng.nextDouble()
        var events: [MIDIEvent]
        if roll < 0.20 {
            usedRuleIDs.insert("CHL-PAD-001")
            events = chordSustain(frame: frame, structure: structure, rng: &rng)
        } else if roll < 0.36 {
            usedRuleIDs.insert("CHL-PAD-002")
            events = staggeredEntry(frame: frame, structure: structure, rng: &rng)
        } else if roll < 0.51 {
            usedRuleIDs.insert("CHL-PAD-003")
            events = mobyAnchor(frame: frame, structure: structure, rng: &rng)
        } else if roll < 0.61 {
            usedRuleIDs.insert("CHL-PAD-004")
            events = openFifthHold(frame: frame, structure: structure, rng: &rng)
        } else if roll < 0.75 {
            usedRuleIDs.insert("CHL-PAD-005")
            events = slowChordBuild(frame: frame, structure: structure, rng: &rng)
        } else if roll < 0.92 {
            usedRuleIDs.insert("CHL-PAD-006")
            events = portisheadStrings(frame: frame, structure: structure, rng: &rng)
        } else {
            usedRuleIDs.insert("CHL-PAD-007")
            events = []  // absent — texture-only songs
        }
        // Overlay breakdown pad behavior based on breakdown style
        events += breakdownPad(frame: frame, structure: structure, breakdownStyle: breakdownStyle, rng: &rng)

        // Cold start: bar 0 is drums-only, pads silent
        if case .coldStart = structure.introStyle {
            events = events.filter { $0.stepIndex >= 16 }
        }

        // Cold stop: final bar silent; crash bar lets any sustained chord ring naturally.
        if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar {
            let silenceFrom = (outroEnd - 1) * 16
            events = events.filter { $0.stepIndex < silenceFrom }
        }

        return events
    }

    // MARK: - CHL-PAD-001: Chord sustain (Long Lake Winter Strings model)

    /// One sustained chord per 2–4 bars; held for most of the window; half-note rhythm.
    /// Velocity: 55–70 (mid-mix presence, not background whisper per Long Lake Winter analysis).
    private static func chordSustain(frame: GlobalMusicalFrame, structure: SongStructure,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scalePCs  = frame.scalePCs
        let snapTable = makeSnapTable(scalePCs)

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A
            let chord   = structure.chordPlan.first { $0.contains(bar: bar) }
            let base    = bar * 16

            // Pads are silent in breakdown (breakdownPad() handles bridge for all modes)
            if label == .bridge { continue }

            // Build upper-structure jazz voicing for this bar's chord
            let chordRootPC = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12
            let voiceNotes  = buildUpperStructure(chordRootPC: chordRootPC,
                                                   chordType: chord?.chordType ?? .min7,
                                                   snapTable: snapTable,
                                                   register: 60)  // mid register for pads

            // Only emit new sustain on renewal bars (every 2–4 bars within each chord window)
            let windowStart = chord?.startBar ?? 0
            let barInWindow = bar - windowStart
            let period = 2 + rng.nextInt(upperBound: 3)  // 2, 3, or 4 bars
            guard barInWindow % period == 0 else { continue }

            // Velocity: consistent across sections; the dynamic arc in SongGenerator handles intro/outro fading.
            let baseVel = 40 + rng.nextInt(upperBound: 16)  // 40–55

            let holdBars   = Swift.min(period, (chord?.endBar ?? frame.totalBars) - bar)
            let holdSteps  = max(4, holdBars * 16 - 10)  // 10-step gap before renewal so fade-out is audible

            for note in voiceNotes {
                let vel = UInt8(Swift.max(20, Swift.min(90, baseVel + rng.nextInt(upperBound: 6) - 3)))
                events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: vel,
                                        durationSteps: holdSteps))
            }
        }
        return events
    }

    // MARK: - CHL-PAD-002: Staggered entry (Air / Winter Flight model)

    /// Four pad voices entering 8 bars apart, same harmonic content, different registers.
    /// Creates a natural swell without automation.
    private static func staggeredEntry(frame: GlobalMusicalFrame, structure: SongStructure,
                                        rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scalePCs  = frame.scalePCs
        let snapTable = makeSnapTable(scalePCs)

        // Find the first groove section start
        let grooveStart = structure.sections.first { $0.label == .A }?.startBar ?? 0

        // Each of 4 voices enters 8 bars after the previous
        let entryBars = [grooveStart, grooveStart + 8, grooveStart + 16, grooveStart + 24]
        let voiceRegisters = [48, 60, 72, 84]  // low → high

        for (voiceIdx, entryBar) in entryBars.enumerated() {
            guard entryBar < frame.totalBars else { continue }
            let register = voiceRegisters[voiceIdx]

            // Hold from entry to end of song (or end of non-breakdown sections)
            for bar in entryBar..<frame.totalBars {
                let section = structure.section(atBar: bar)
                if section?.label == .bridge { continue }

                let chord = structure.chordPlan.first { $0.contains(bar: bar) }
                let chordRootPC = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12

                // Only emit on chord change bars (or first bar)
                let windowStart = chord?.startBar ?? 0
                guard bar == windowStart || bar == entryBar else { continue }

                let vel = UInt8(40 + rng.nextInt(upperBound: 16))  // 40–55; arc handles intro/outro fading

                let holdBars = Swift.min(chord.map { $0.endBar - bar } ?? 4,
                                          frame.totalBars - bar)
                let holdSteps = max(4, holdBars * 16 - 10)  // 10-step gap before renewal so fade-out is audible

                // Single note per voice: the chord degree appropriate to the voice index
                let degree = [0, 3, 7, 10][voiceIdx]  // root, 3rd, 5th, 7th
                let notePC = (chordRootPC + degree) % 12
                // Snap to scale
                let snappedPC = snapTable[notePC]
                // Correct pitch-class-to-MIDI: find note near register with pitch class snappedPC
                let targetPC = register % 12
                let semisUp = (snappedPC - targetPC + 12) % 12
                var note = register + semisUp
                while note < 36 { note += 12 }
                while note > 96 { note -= 12 }
                let clampedNote = note

                events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(clampedNote),
                                        velocity: vel, durationSteps: holdSteps))
            }
        }
        return events
    }

    // MARK: - CHL-PAD-003: Moby Anchor
    // Single note in bass-mid register (MIDI 43–60), re-attacked every 4 bars.
    // Alternates between chord root (bars 0–7 of window) and fifth (bars 8–15)
    // so the anchor shifts slightly over long chord windows without changing harmony.

    private static func mobyAnchor(frame: GlobalMusicalFrame, structure: SongStructure,
                                    rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scalePCs  = frame.scalePCs
        let snapTable = makeSnapTable(scalePCs)

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Silent in breakdown (breakdownPad handles bridge for all modes)
            if label == .bridge { continue }

            let chord       = structure.chordPlan.first { $0.contains(bar: bar) }
            let windowStart = chord?.startBar ?? 0
            let barInWindow = bar - windowStart

            // Re-attack every 4 bars
            guard barInWindow % 4 == 0 else { continue }

            // Root pitch class, snapped to scale
            let rawRootPC = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12
            let rootPC    = snapTable[rawRootPC]

            // Alternates root / fifth every 8 bars of song position so variation
            // fires regardless of chord window length (window-relative position
            // would never reach bar 8 in an 8-bar window — always stays on root).
            let useFifth  = (bar / 8) % 2 == 1
            let anchorPC  = useFifth ? snapTable[(rootPC + 7) % 12] : rootPC

            // Place note in bass-mid register (MIDI 43–60), anchored near C3 (MIDI 48)
            let refMIDI   = 48
            let semisUp   = (anchorPC - refMIDI % 12 + 12) % 12
            var note      = refMIDI + semisUp
            while note < 43 { note += 12 }
            while note > 60 { note -= 12 }

            // Hold for 4 bars minus a short gap so re-attack is audible
            let holdBars  = Swift.min(4, (chord?.endBar ?? frame.totalBars) - bar)
            let holdSteps = Swift.max(4, holdBars * 16 - 4)

            let vel = UInt8(65 + rng.nextInt(upperBound: 16))  // 65–80
            events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(note),
                                    velocity: vel, durationSteps: holdSteps))
        }
        return events
    }

    // MARK: - CHL-PAD-004: Open Fifth Hold
    // Root + fifth only — no third, so the voicing is modally ambiguous (neither major nor minor).
    // Held for the full chord window; only re-attacks on chord changes.
    // The missing third lets it sit under any chord quality without clashing.
    // Two voices spread an octave apart for width: lower root and upper fifth.

    private static func openFifthHold(frame: GlobalMusicalFrame, structure: SongStructure,
                                       rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scalePCs  = frame.scalePCs
        let snapTable = makeSnapTable(scalePCs)

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            if label == .bridge { continue }

            let chord       = structure.chordPlan.first { $0.contains(bar: bar) }
            let windowStart = chord?.startBar ?? 0

            // Only attack on the first bar of each chord window
            guard bar == windowStart else { continue }

            let rawRootPC = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12
            let rootPC    = snapTable[rawRootPC]
            let fifthPC   = snapTable[(rootPC + 7) % 12]

            // Lower voice: root in mid-low register (MIDI 48–60), anchored near C3
            let refLow    = 48
            let semisLow  = (rootPC - refLow % 12 + 12) % 12
            var noteLow   = refLow + semisLow
            while noteLow < 48 { noteLow += 12 }
            while noteLow > 60 { noteLow -= 12 }

            // Upper voice: fifth one octave above the lower root
            var noteHigh  = noteLow + 7   // perfect fifth above lower root
            // Snap high note's pitch class to scale
            let highPC    = noteHigh % 12
            let snappedHP = snapTable[highPC]
            noteHigh      = noteHigh - highPC + snappedHP
            // If the fifth collapsed into the lower voice, push it up an octave
            if noteHigh <= noteLow { noteHigh += 12 }
            while noteHigh > 76 { noteHigh -= 12 }

            // Hold for the full chord window, with a small gap at the end for breath
            let windowBars = (chord?.endBar ?? frame.totalBars) - windowStart
            let holdSteps  = Swift.max(4, windowBars * 16 - 10)

            let velLow  = UInt8(42 + rng.nextInt(upperBound: 14))  // 42–55
            let velHigh = UInt8(Swift.max(1, Int(velLow) - 8))     // 5–8 softer on top

            events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(noteLow),
                                    velocity: velLow,  durationSteps: holdSteps))
            events.append(MIDIEvent(stepIndex: bar * 16, note: UInt8(noteHigh),
                                    velocity: velHigh, durationSteps: holdSteps))
        }
        return events
    }

    // MARK: - CHL-PAD-005: Slow Chord Build
    // Additive harmonic layering across each chord window (Röyksopp / Air model).
    // Phase 0 (bar 0): root + fifth — bare open interval
    // Phase 1 (+4 bars): add third — chord quality defined
    // Phase 2 (+8 bars): add seventh — jazz depth
    // Phase 3 (+12 bars): add ninth — full color
    // Each voice holds from its entry bar to the end of the window.
    // Short windows get fewer phases; the build only completes in long windows (12+ bars).

    private static func slowChordBuild(frame: GlobalMusicalFrame, structure: SongStructure,
                                        rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scalePCs  = frame.scalePCs
        let snapTable = makeSnapTable(scalePCs)

        // Place a pitch class near `ref`, clamped to [lo, hi]
        func noteNear(_ pc: Int, ref: Int, lo: Int, hi: Int) -> Int {
            let semisUp = (pc - ref % 12 + 12) % 12
            var n = ref + semisUp
            while n < lo { n += 12 }
            while n > hi { n -= 12 }
            return n
        }

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            if section?.label == .bridge { continue }

            let chord       = structure.chordPlan.first { $0.contains(bar: bar) }
            let windowStart = chord?.startBar ?? 0
            let windowEnd   = chord?.endBar   ?? frame.totalBars
            let windowLen   = windowEnd - windowStart
            let barInWindow = bar - windowStart

            let isPhase0 = barInWindow == 0
            let isPhase1 = barInWindow == 4  && windowLen > 4
            let isPhase2 = barInWindow == 8  && windowLen > 8
            let isPhase3 = barInWindow == 12 && windowLen > 12
            guard isPhase0 || isPhase1 || isPhase2 || isPhase3 else { continue }

            let rawRootPC = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12
            let rootPC    = snapTable[rawRootPC]
            let ct        = chord?.chordType ?? .min7

            // Each voice holds from its entry bar to the end of the chord window
            let holdSteps = Swift.max(4, (windowEnd - bar) * 16 - 10)
            let base      = bar * 16

            if isPhase0 {
                // Root + fifth — open, ambiguous, lets the section breathe before chord color arrives
                let fifthPC  = snapTable[(rootPC + 7) % 12]
                let noteRoot = noteNear(rootPC,  ref: 50, lo: 45, hi: 62)
                let noteFifth = noteNear(fifthPC, ref: 57, lo: 52, hi: 69)
                let vel = UInt8(35 + rng.nextInt(upperBound: 12))  // 35–46, quiet start
                events.append(MIDIEvent(stepIndex: base, note: UInt8(noteRoot),
                                        velocity: vel, durationSteps: holdSteps))
                events.append(MIDIEvent(stepIndex: base, note: UInt8(noteFifth),
                                        velocity: UInt8(max(1, Int(vel) - 5)), durationSteps: holdSteps))
            }

            if isPhase1 {
                // Third — reveals chord quality (major/minor/sus)
                let thirdInt: Int
                switch ct {
                case .major, .dom7, .add9: thirdInt = 4
                case .sus4:                thirdInt = 5
                default:                   thirdInt = 3
                }
                let thirdPC   = snapTable[(rootPC + thirdInt) % 12]
                let noteThird = noteNear(thirdPC, ref: 53, lo: 48, hi: 65)
                let vel = UInt8(40 + rng.nextInt(upperBound: 12))  // 40–51
                events.append(MIDIEvent(stepIndex: base, note: UInt8(noteThird),
                                        velocity: vel, durationSteps: holdSteps))
            }

            if isPhase2 {
                // Seventh — adds jazz complexity
                let seventhInt = (ct == .major) ? 11 : 10
                let seventhPC   = snapTable[(rootPC + seventhInt) % 12]
                let noteSeventh = noteNear(seventhPC, ref: 60, lo: 55, hi: 72)
                let vel = UInt8(43 + rng.nextInt(upperBound: 12))  // 43–54
                events.append(MIDIEvent(stepIndex: base, note: UInt8(noteSeventh),
                                        velocity: vel, durationSteps: holdSteps))
            }

            if isPhase3 {
                // Ninth — full harmonic color
                let ninthPC   = snapTable[(rootPC + 2) % 12]
                let noteNinth = noteNear(ninthPC, ref: 64, lo: 59, hi: 76)
                let vel = UInt8(45 + rng.nextInt(upperBound: 12))  // 45–56
                events.append(MIDIEvent(stepIndex: base, note: UInt8(noteNinth),
                                        velocity: vel, durationSteps: holdSteps))
            }
        }
        return events
    }

    // MARK: - CHL-PAD-006: Portishead String Hold
    // Close-voiced 4-note string chord (root, third, fifth, seventh) in mid register (52–79).
    // All four voices within an octave of the root — tight, cinematic string quartet texture.
    // Re-attacked every 2 bars; voices stagger by 2 steps each for a bowed attack feel.
    // Third and seventh are chord-type-aware (major vs minor quality).

    private static func portisheadStrings(frame: GlobalMusicalFrame, structure: SongStructure,
                                           rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scalePCs  = frame.scalePCs
        let snapTable = makeSnapTable(scalePCs)

        func noteNear(_ pc: Int, ref: Int, lo: Int, hi: Int) -> Int {
            let semisUp = (pc - ref % 12 + 12) % 12
            var n = ref + semisUp
            while n < lo { n += 12 }
            while n > hi { n -= 12 }
            return n
        }

        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A
            if label == .bridge { continue }

            let chord       = structure.chordPlan.first { $0.contains(bar: bar) }
            let windowStart = chord?.startBar ?? 0
            let barInWindow = bar - windowStart

            guard barInWindow % 2 == 0 else { continue }

            let rawRootPC  = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12
            let rootPC     = snapTable[rawRootPC]
            let ct         = chord?.chordType ?? .min7

            let thirdInt: Int
            switch ct {
            case .major, .dom7, .add9: thirdInt = 4
            case .sus4:                thirdInt = 5
            default:                   thirdInt = 3
            }
            let seventhInt = (ct == .major) ? 11 : 10

            let thirdPC   = snapTable[(rootPC + thirdInt) % 12]
            let fifthPC   = snapTable[(rootPC + 7) % 12]
            let seventhPC = snapTable[(rootPC + seventhInt) % 12]

            // Close voicing in string register — all voices within an octave of root
            let noteRoot    = noteNear(rootPC,    ref: 57,               lo: 52,             hi: 67)
            let noteThird   = noteNear(thirdPC,   ref: noteRoot + thirdInt,   lo: noteRoot + 1,   hi: noteRoot + 12)
            let noteFifth   = noteNear(fifthPC,   ref: noteRoot + 7,          lo: noteThird,      hi: noteRoot + 13)
            let noteSeventh = noteNear(seventhPC, ref: noteRoot + seventhInt,  lo: noteFifth,      hi: noteRoot + 14)

            let chordEnd  = chord?.endBar ?? frame.totalBars
            let holdBars  = Swift.min(2, chordEnd - bar)
            let holdSteps = Swift.max(4, holdBars * 16 - 8)

            let baseVel = Int(50 + rng.nextInt(upperBound: 15))  // 50–64, root loudest

            // Stagger each voice by 2 steps — root first, like a bowed attack
            let voices = [noteRoot, noteThird, noteFifth, noteSeventh]
            for (i, n) in voices.enumerated() {
                let stagger = i * 2
                let vel = UInt8(max(1, baseVel - i * 3))  // taper upper voices slightly
                events.append(MIDIEvent(stepIndex: bar * 16 + stagger, note: UInt8(n),
                                        velocity: vel, durationSteps: Swift.max(4, holdSteps - stagger)))
            }
        }
        return events
    }

    // MARK: - Breakdown pad (all modes, CHL-SYNC-009)

    /// Breakdown pad behavior depends on breakdown style:
    /// - stopTime: staccato chord stab (4 steps) on beat 1 of every other bar (the unison hit)
    /// - bassOstinato: completely silent — bass carries the groove alone
    /// - harmonicDrone: whisper sustain vel 25–40, renewed every 4 bars (barely there warmth)
    /// - groovePocket: full-strength sustain vel 55–70 — pads are prominent since bass/leads are absent
    private static func breakdownPad(frame: GlobalMusicalFrame, structure: SongStructure,
                                      breakdownStyle: ChillBreakdownStyle,
                                      rng: inout SeededRNG) -> [MIDIEvent] {
        guard breakdownStyle != .bassOstinato else { return [] }
        var events: [MIDIEvent] = []
        let scalePCs  = frame.scalePCs
        let snapTable = makeSnapTable(scalePCs)
        for bar in 0..<frame.totalBars {
            let section = structure.section(atBar: bar)
            guard section?.label == .bridge else { continue }
            let chord = structure.chordPlan.first { $0.contains(bar: bar) }
            let chordRootPC = (frame.keySemitoneValue + degreeSemitone(chord?.chordRoot ?? "1")) % 12
            let voiceNotes  = buildUpperStructure(chordRootPC: chordRootPC,
                                                   chordType: chord?.chordType ?? .sus4,
                                                   snapTable: snapTable,
                                                   register: 60)
            let base = bar * 16
            let breakdownBar = bar - (section?.startBar ?? bar)

            switch breakdownStyle {
            case .stopTime:
                if breakdownBar % 2 == 0 {
                    // Even bars: staccato stab on beat 1 synchronized with the drum/bass hit
                    for note in voiceNotes {
                        let vel = UInt8(52 + rng.nextInt(upperBound: 10))  // slightly raised
                        events.append(MIDIEvent(stepIndex: base, note: UInt8(note),
                                                velocity: vel, durationSteps: 4))
                    }
                } else {
                    // Odd (silence) bars: sustained chord reveal — notes enter bottom to top on
                    // beats 2, 3, 4 and each sustains to beat 1 of the next bar, so the full
                    // voicing accumulates and is already ringing when the hit lands.
                    let sorted = voiceNotes.sorted()
                    let n = sorted.count
                    // Step offsets: 4 (beat 2), 8 (beat 3), 12 (beat 4)
                    // Duration: sustain to step 16 from bar start, i.e. 16 - stepOffset
                    if n >= 1 {
                        let vel = UInt8(48 + rng.nextInt(upperBound: 10))
                        events.append(MIDIEvent(stepIndex: base + 4,  note: UInt8(sorted[0]),
                                                velocity: vel, durationSteps: 12))
                    }
                    if n >= 2 {
                        let vel = UInt8(55 + rng.nextInt(upperBound: 10))
                        events.append(MIDIEvent(stepIndex: base + 8,  note: UInt8(sorted[1]),
                                                velocity: vel, durationSteps: 8))
                    }
                    if n >= 3 {
                        let vel = UInt8(62 + rng.nextInt(upperBound: 10))
                        for note in sorted.suffix(n > 3 ? 2 : 1) {
                            events.append(MIDIEvent(stepIndex: base + 12, note: UInt8(note),
                                                    velocity: vel, durationSteps: 4))
                        }
                    }
                }
            case .bassOstinato:
                break  // handled by guard above
            case .harmonicDrone:
                // Whisper sustain renewed every 4 bars — barely audible harmonic warmth
                guard breakdownBar % 4 == 0 else { continue }
                let holdBars  = Swift.min(4, frame.totalBars - bar)
                let holdSteps = holdBars * 16 - 2
                for note in voiceNotes {
                    let vel = UInt8(Swift.max(18, Swift.min(40, 25 + rng.nextInt(upperBound: 15))))
                    events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: vel,
                                            durationSteps: holdSteps))
                }
            case .groovePocket:
                // Full-strength sustain, renewed every 2 bars — pads are prominent since bass and leads are out
                guard breakdownBar % 2 == 0 else { continue }
                let holdBars  = Swift.min(2, frame.totalBars - bar)
                let holdSteps = holdBars * 16 - 12  // 12-step gap keeps deferred stopNote from cutting re-attack
                for note in voiceNotes {
                    let vel = UInt8(55 + rng.nextInt(upperBound: 16))
                    events.append(MIDIEvent(stepIndex: base, note: UInt8(note), velocity: vel,
                                            durationSteps: holdSteps))
                }
            }
        }
        return events
    }

    // MARK: - Snap table helper

    /// Builds a 12-element lookup: chromatic PC → nearest scale PC.
    /// Built once per generator call so per-note snapping is O(1) instead of O(scale_size).
    static func makeSnapTable(_ scalePCs: Set<Int>) -> [Int] {
        (0..<12).map { pc in
            scalePCs.contains(pc) ? pc : (scalePCs.min(by: { abs($0 - pc) < abs($1 - pc) }) ?? pc)
        }
    }

    // MARK: - Voicing helper

    /// Upper-structure voicing: [3rd, 5th, 7th] spread over 2 octaves, root omitted.
    /// All intervals snapped to active scale (CHL-SYNC-004).
    private static func buildUpperStructure(chordRootPC: Int, chordType: ChordType,
                                             snapTable: [Int],
                                             register: Int) -> [Int] {
        // Chord intervals above root — 4-note upper structure (3rd, 5th, 7th, 9th);
        // root omitted (bass covers it); voicing spread across 2 octaves (CHL-RULE-03).
        let rawIntervals: [Int]
        switch chordType {
        case .min7:   rawIntervals = [3, 7, 10, 14]   // b3, 5, b7, 9
        case .major:  rawIntervals = [4, 7, 11, 14]   // 3, 5, maj7, 9
        case .dom7:   rawIntervals = [4, 7, 10, 14]   // 3, 5, b7, 9
        case .sus4:   rawIntervals = [5, 7, 10, 14]   // 4, 5, b7, 9
        case .add9:   rawIntervals = [4, 7, 10, 14]   // 3, 5, b7, 9
        default:      rawIntervals = [3, 7, 10, 14]
        }

        var notes: [Int] = []
        for (i, interval) in rawIntervals.enumerated() {
            let pc = snapTable[(chordRootPC + interval) % 12]
            // Spread 4 voices across 2 octaves: voices 0–1 in lower octave, voices 2–3 upper.
            // Use correct pitch-class-to-MIDI mapping: find the nearest note at/above
            // (register + octaveOffset) that has pitch class pc.
            let octaveOffset = i < 2 ? 0 : 12
            let target = register + octaveOffset
            let targetPC = target % 12
            let semisUp = (pc - targetPC + 12) % 12
            var note = target + semisUp
            // Keep within pads register
            while note < 48 { note -= 12 }
            while note > 84 { note -= 12 }
            notes.append(note)
        }
        return notes
    }
}
