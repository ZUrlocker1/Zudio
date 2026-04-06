// ChillLeadGenerator.swift — Chill generation step 6
// Lead 1: primary solo voice (flute, muted trumpet, vibraphone, saxophone).
// Lead 2: counter-melody; call-and-response with Lead 1 (CHL-LD2-001, CHL-LD2-002).
// Phrases: 2–4 bars with deliberate rests (CHL-RULE-06).
// Pitch pool: mode pentatonic + occasional blue note (CHL-RULE-07).
// All notes snapped to scale (CHL-SYNC-001).

import Foundation

struct ChillLeadGenerator {

    // MARK: - Lead 1

    static func generateLead1(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        leadInstrument: ChillLeadInstrument,
        beatStyle: ChillBeatStyle = .electronic,
        breakdownStyle: ChillBreakdownStyle = .bassOstinato,
        forceRuleID: String? = nil,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> (events: [MIDIEvent], phraseOnsets: [(startBar: Int, endBar: Int)]) {
        // CHL-LD1-005: St Germain staccato style — short bursts in active periods, long silences.
        // Used when beat style is stGermain (strongly) or occasionally for other styles.
        // Suppressed when a different rule is explicitly forced (best-first-song path).
        let forceNonStaccato = forceRuleID != nil && forceRuleID != "CHL-LD1-005"
        let staccatoProb: Double = forceNonStaccato ? 0.0 : (beatStyle == .stGermain ? 0.85 : 0.15)
        if rng.nextDouble() < staccatoProb {
            usedRuleIDs.insert("CHL-LD1-005")
            let events = stGermainStaccato(frame: frame, structure: structure,
                                           breakdownStyle: breakdownStyle, rng: &rng)
            // Build phraseOnsets from the events for Lead 2 call-and-response awareness
            let onsets = eventsToOnsets(events: events, totalBars: frame.totalBars)
            return (events, onsets)
        }

        let ruleID = lead1RuleID(for: leadInstrument)
        usedRuleIDs.insert(ruleID)

        var events: [MIDIEvent] = []
        var phraseOnsets: [(startBar: Int, endBar: Int)] = []

        let scale       = scaleNotes(frame: frame)
        let pentatonic  = pentatonicNotes(frame: frame)
        let blueNote    = blueNotePC(frame: frame)
        let (regLow, regHigh) = register(for: leadInstrument)

        // Stop-time breakdown: cap solo bars at 4 or 6 to leave some odd bars silent
        let stopTimeSoloMax = rng.nextDouble() < 0.50 ? 4 : 6
        var stopTimeSoloBarsUsed = 0

        var bar = 0
        while bar < frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Cold start: bar 0 is drums-only, lead silent
            if case .coldStart = structure.introStyle, bar == 0 {
                bar += 1; continue
            }

            // Cold stop: last 2 outro bars are drums-only, lead silent
            if case .coldStop = structure.outroStyle, let outroEnd = structure.outroSection?.endBar,
               bar >= outroEnd - 2 {
                bar += 1; continue
            }

            // Breakdown behavior depends on style
            if label == .bridge {
                switch breakdownStyle {
                case .bassOstinato:
                    // Silent — bass carries the groove alone
                    bar += 1
                    continue
                case .stopTime:
                    // Lead plays in the "odd" silence bars between stabs
                    let breakdownBar = bar - (section?.startBar ?? bar)
                    if breakdownBar % 2 == 0 {
                        // Stab bar — lead silent (rhythm section plays the hit)
                        bar += 1
                        continue
                    }
                    // Cap total solo bars at 4 or 6 — leave later odd bars silent for space
                    guard stopTimeSoloBarsUsed < stopTimeSoloMax else { bar += 1; continue }
                    // Odd bar: lead gets 1 bar to play freely
                    let stopPool = scale.filter { $0 >= regLow && $0 <= regHigh }.sorted()
                        .reduce(into: [Int]()) { acc, n in if acc.last != n { acc.append(n) } }
                    if !stopPool.isEmpty {
                        let noteCount = 3 + rng.nextInt(upperBound: 3)
                        let base = bar * 16
                        var prevNote = stopPool[rng.nextInt(upperBound: stopPool.count)]
                        var stepCursor = 0
                        for i in 0..<noteCount {
                            let remaining = 15 - stepCursor
                            guard remaining > 1 else { break }
                            let vel = UInt8(62 + rng.nextInt(upperBound: 18))
                            let maxDur = Swift.max(1, remaining / Swift.max(1, noteCount - i))
                            let dur = Swift.min(Swift.max(2, rng.nextInt(upperBound: 5) + 2), maxDur)
                            events.append(MIDIEvent(stepIndex: base + stepCursor, note: UInt8(prevNote),
                                                    velocity: vel, durationSteps: dur))
                            stepCursor += dur + 1
                            prevNote = stopPool[rng.nextInt(upperBound: stopPool.count)]
                        }
                    }
                    stopTimeSoloBarsUsed += 1
                    bar += 1
                    continue
                case .harmonicDrone:
                    // Lead plays freely over the drone — treat like a groove section
                    break  // fall through to normal phrase generation
                }
            }

            // Brass and blues leads occasionally "lay out" for a full 4 or 8 bars — jazz breathing room
            if (leadInstrument == .trumpet || leadInstrument == .mutedTrumpet || leadInstrument == .saxophone),
               label == .A || label == .B,
               rng.nextDouble() < 0.12 {
                bar += rng.nextDouble() < 0.60 ? 4 : 8
                continue
            }

            // Silence probability by section
            let silenceProb: Double
            switch label {
            case .intro:
                // First 4 bars of intro always silent (CHL-RULE-06); sparse thereafter
                let introStart = section?.startBar ?? 0
                if bar < introStart + 4 {
                    bar += 1
                    continue
                }
                silenceProb = 0.90  // very sparse — at most 1 brief phrase
            case .outro:  silenceProb = 0.85  // very sparse in outro — trailing off
            case .A:      silenceProb = 0.40  // groove A: moderately active
            case .B:      silenceProb = 0.10  // most active in groove B — consistently denser than A
            default:      silenceProb = 0.50
            }

            if rng.nextDouble() < silenceProb {
                // Rest: 1–2 bars
                bar += 1 + rng.nextInt(upperBound: 2)
                continue
            }

            // Phrase length: instrument-specific
            let phraseLen: Int
            switch leadInstrument {
            case .flute:         phraseLen = 3 + rng.nextInt(upperBound: 2)   // 3–4 bars
            case .mutedTrumpet:  phraseLen = 2                                 // 2 bars (punchy)
            case .vibraphone:    phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .saxophone:     phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .sopranoSax:    phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars (similar to tenor)
            case .trumpet:       phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars (slightly more spacious than muted)
            case .trombone:      phraseLen = 2 + rng.nextInt(upperBound: 3)   // 2–4 bars (smooth, longer lines)
            }

            // Clamp phrase to section boundary; intro/outro phrases max 2 bars to keep density low
            let sectionEnd = section.map { $0.startBar + $0.lengthBars } ?? frame.totalBars
            let maxPhraseLen = (label == .intro || label == .outro) ? 2 : phraseLen
            let actualPhraseLen = Swift.min(maxPhraseLen, sectionEnd - bar)
            guard actualPhraseLen > 0 else { bar += 1; continue }

            // Build phrase notes
            let phraseBluePc = rng.nextDouble() < 0.15 ? blueNote : nil  // occasional blue note
            // Use the chord at the END of the phrase for strong-landing calculation (not key root)
            let phraseEndChord = structure.chordPlan.first { $0.contains(bar: bar + actualPhraseLen - 1) }
            let phraseNotes = buildPhrase(
                frame: frame, bar: bar, bars: actualPhraseLen,
                leadInstrument: leadInstrument,
                pentatonic: pentatonic, scale: scale,
                blueNotePC: phraseBluePc,
                regLow: regLow, regHigh: regHigh,
                section: label,
                phraseEndChord: phraseEndChord,
                rng: &rng
            )
            events += phraseNotes
            phraseOnsets.append((startBar: bar, endBar: bar + actualPhraseLen))

            bar += actualPhraseLen
            // Mandatory rest after phrase (CHL-RULE-06); Groove B rests capped at 1 bar to stay dense
            bar += (label == .B) ? 1 : 1 + rng.nextInt(upperBound: 2)
        }
        return (events, phraseOnsets)
    }

    // MARK: - Lead 2

    static func generateLead2(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        lead1Instrument: ChillLeadInstrument,
        lead1Onsets: [(startBar: Int, endBar: Int)],
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        usedRuleIDs.insert("CHL-LD2-001")

        var events: [MIDIEvent] = []
        let scale      = scaleNotes(frame: frame)
        let pentatonic = pentatonicNotes(frame: frame)

        // Lead 2 instrument: complement Lead 1 — pitched percussion (vibraphone) contrasts brass/reeds;
        // trombone adds warm low-brass depth when Lead 1 is a reed; flute lightens if Lead 1 is vibraphone.
        let inst2: ChillLeadInstrument
        switch lead1Instrument {
        case .vibraphone:
            inst2 = .flute          // flute lightens the texture when vibe is primary
        case .saxophone:
            // Alto Sax Lead 1: vibraphone (50%) or trombone (50%) — different timbre family
            inst2 = rng.nextDouble() < 0.50 ? .vibraphone : .trombone
        case .flute:
            // Flute Lead 1: vibraphone (50%) or trombone (50%) — warm bass counterpoint
            inst2 = rng.nextDouble() < 0.50 ? .vibraphone : .trombone
        default:
            // Brass Lead 1 (muted trumpet, trumpet): soprano sax (40%), vibraphone (40%), flute (20%)
            let r = rng.nextDouble()
            if r < 0.40      { inst2 = .sopranoSax }
            else if r < 0.80 { inst2 = .vibraphone }
            else             { inst2 = .flute }
        }
        let (regLow1, _) = register(for: lead1Instrument)
        let (rawLow2, rawHigh2) = register(for: inst2)
        // Lead 2 must sit below the bottom of Lead 1's register (CHL-RULE-12).
        // Capping at regLow1 - 2 ensures clear separation regardless of how high Lead 1
        // actually plays within its range (avoids median-based cap being too generous).
        let regHigh2 = min(rawHigh2, regLow1 - 2)
        let regLow2  = max(36, min(rawLow2, regHigh2 - 12))

        // Lead 2 responds in gaps between Lead 1 phrases (call-and-response)
        // Find bars NOT covered by Lead 1 phrases in groove sections
        var lead1BarSet = Set<Int>()
        for onset in lead1Onsets {
            for b in onset.startBar..<onset.endBar { lead1BarSet.insert(b) }
        }

        var bar = 0
        while bar < frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Lead 2 only in groove sections (A and B)
            guard label == .A || label == .B else { bar += 1; continue }
            // Skip bars where Lead 1 is playing
            guard !lead1BarSet.contains(bar) else { bar += 1; continue }
            // 80% chance to respond in any available gap
            guard rng.nextDouble() < 0.80 else { bar += 1; continue }

            let sectionEnd = section.map { $0.startBar + $0.lengthBars } ?? frame.totalBars
            // 2-bar phrases for Lead 2
            let phraseLen = Swift.min(2, sectionEnd - bar)
            guard phraseLen > 0 else { bar += 1; continue }

            // Check gap is free of Lead 1
            let gapFree = (bar..<bar + phraseLen).allSatisfy { !lead1BarSet.contains($0) }
            guard gapFree else { bar += 1; continue }

            let phraseNotes = buildPhrase(
                frame: frame, bar: bar, bars: phraseLen,
                leadInstrument: inst2,
                pentatonic: pentatonic, scale: scale,
                blueNotePC: nil,
                regLow: regLow2, regHigh: regHigh2,
                section: label, rng: &rng,
                velocityOffset: inst2 == .vibraphone ? 0 : -15  // vibraphone reads quietly; match Lead 1 level
            )
            events += phraseNotes
            bar += phraseLen  // Lead 2 fills gaps; Lead 1 bars provide natural spacing
        }
        return events
    }

    // MARK: - Phrase builder

    private static func buildPhrase(
        frame: GlobalMusicalFrame,
        bar: Int,
        bars: Int,
        leadInstrument: ChillLeadInstrument,
        pentatonic: [Int],
        scale: [Int],
        blueNotePC: Int?,
        regLow: Int,
        regHigh: Int,
        section: SectionLabel,
        phraseEndChord: ChordWindow? = nil,
        rng: inout SeededRNG,
        velocityOffset: Int = 0
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Velocity range by section; muted trumpet reads quietly so gets +6 boost
        let mutedTrumpetBoost = leadInstrument == .mutedTrumpet ? 22 : 0
        let velBase: Int
        switch section {
        case .intro, .outro: velBase = 47 + velocityOffset + mutedTrumpetBoost
        case .B:             velBase = 72 + velocityOffset + mutedTrumpetBoost
        default:             velBase = 67 + velocityOffset + mutedTrumpetBoost
        }

        // Note count per bar: instrument-specific; intro/outro capped at 2 (sparse fade)
        let notesPerBar: Int
        if section == .intro || section == .outro {
            notesPerBar = 2
        } else {
            switch leadInstrument {
            case .flute:        notesPerBar = 2 + rng.nextInt(upperBound: 2)   // 2–3
            case .mutedTrumpet: notesPerBar = 3 + rng.nextInt(upperBound: 2)   // 3–4 (min 3 ensures ≥3 pitch classes per phrase)
            case .trumpet:      notesPerBar = 3 + rng.nextInt(upperBound: 2)   // 3–4 (open trumpet: punchy like muted)
            case .vibraphone:   notesPerBar = 3 + rng.nextInt(upperBound: 3)   // 3–5
            case .saxophone:    notesPerBar = 3 + rng.nextInt(upperBound: 3)   // 3–5
            case .sopranoSax:   notesPerBar = 2 + rng.nextInt(upperBound: 3)   // 2–4 (brighter reed, medium density)
            case .trombone:     notesPerBar = 2 + rng.nextInt(upperBound: 2)   // 2–3 (smooth legato, fewer notes)
            }
        }

        // Duration per note in steps: instrument-specific
        let noteDurSteps: Int
        switch leadInstrument {
        case .flute:        noteDurSteps = 8 + rng.nextInt(upperBound: 5)   // 8–12 steps (legato)
        case .mutedTrumpet: noteDurSteps = 2 + rng.nextInt(upperBound: 3)   // 2–4 steps (staccato)
        case .trumpet:      noteDurSteps = 3 + rng.nextInt(upperBound: 3)   // 3–5 steps (slightly longer than muted)
        case .vibraphone:   noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
        case .saxophone:    noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
        case .sopranoSax:   noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps (similar to tenor)
        case .trombone:     noteDurSteps = 6 + rng.nextInt(upperBound: 7)   // 6–12 steps (long legato slides)
        }

        // Build an ordered pool from the full scale so adjacent indices are ≤2 semitones apart —
        // guaranteeing ≥55% measured step ratio. Pentatonic character is preserved through
        // landing-note selection. The blue note (b5), when active, is injected into the pool
        // so the navigator can land on it naturally.
        var scaleForPool = scale
        if let bluePC = blueNotePC {
            // Insert all octave instances of the blue note within the register
            var bn = regLow + ((bluePC - (frame.keySemitoneValue % 12) + 12) % 12)
            while bn < regLow { bn += 12 }
            while bn <= regHigh { scaleForPool.append(bn); bn += 12 }
        }
        let orderedPool = scaleForPool.filter { $0 >= regLow && $0 <= regHigh }
            .sorted().reduce(into: [Int]()) { acc, n in if acc.last != n { acc.append(n) } }
        guard !orderedPool.isEmpty else { return events }

        // Starting note: near tonic
        let tonicNote = regLow + 5 + rng.nextInt(upperBound: Swift.max(1, regHigh - regLow - 5))
        let startIdx  = orderedPool.indices.min(by: { abs(orderedPool[$0] - tonicNote) < abs(orderedPool[$1] - tonicNote) }) ?? 0
        var prevIdx   = startIdx
        var prevNote  = orderedPool[prevIdx]
        var direction = 1               // +1 ascending, -1 descending
        var lastWasLeap = false         // after a leap, strongly prefer stepwise (CHL-RULE-07)

        // Collect (stepIndex, pitch, velocity) first; assign durations after so we can
        // clamp each note to end before the next one starts — guaranteeing monophonic output.
        struct NoteSlot { var step: Int; var pitch: Int; var vel: UInt8 }
        var slots: [NoteSlot] = []

        for barOffset in 0..<bars {
            let barBase = (bar + barOffset) * 16
            let spacing = 16 / notesPerBar
            for noteIdx in 0..<notesPerBar {
                // Brass: start on off-beat occasionally (syncopated attack)
                let stepOffset: Int
                if (leadInstrument == .mutedTrumpet || leadInstrument == .trumpet) && noteIdx == 0 {
                    stepOffset = rng.nextDouble() < 0.40 ? 2 : 0
                } else {
                    stepOffset = noteIdx * spacing
                }
                let stepIndex = barBase + stepOffset
                if stepIndex >= frame.totalBars * 16 { break }

                // Navigate pool by index: step = ±1 position, leap = ±2–3 positions.
                // Because we move within the pool (not by raw semitones) every "step"
                // is a genuine scale step, guaranteeing ≥55% measured step ratio.
                // Trumpet uses a lower step probability to produce the wider intervallic leaps
                // characteristic of jazz brass improvisation (measured at ~58% leaps in Cantaloop).
                let stepProb: Double
                if leadInstrument == .mutedTrumpet || leadInstrument == .trumpet {
                    stepProb = lastWasLeap ? 0.78 : 0.60  // ~40% leaps for brass — wider intervals than reeds
                } else {
                    stepProb = lastWasLeap ? 0.90 : 0.75
                }
                var nextIdx: Int
                if rng.nextDouble() < stepProb {
                    // Step: adjacent pool index
                    let candidate = prevIdx + direction
                    if candidate >= 0 && candidate < orderedPool.count {
                        nextIdx = candidate
                    } else {
                        // Hit boundary — reverse and jump 2–3 steps inward to break ping-pong
                        direction = -direction
                        let inward = 2 + rng.nextInt(upperBound: 2)
                        nextIdx = Swift.max(0, Swift.min(orderedPool.count - 1, prevIdx + direction * inward))
                    }
                    lastWasLeap = false
                } else {
                    // Leap: skip 2–3 pool positions
                    let skip = 2 + rng.nextInt(upperBound: 2)
                    let candidate = prevIdx + direction * skip
                    if candidate >= 0 && candidate < orderedPool.count {
                        nextIdx = candidate
                    } else {
                        direction = -direction
                        nextIdx = Swift.max(0, Swift.min(orderedPool.count - 1, prevIdx + direction * skip))
                    }
                    direction = -direction  // reverse after leap
                    lastWasLeap = true
                }
                // Avoid same-pitch-class repeat: nudge 2 positions further if we'd land on the same PC
                if orderedPool.count > 3 && orderedPool[nextIdx] % 12 == prevNote % 12 {
                    let nudge = direction != 0 ? direction : 1
                    let alt = Swift.max(0, Swift.min(orderedPool.count - 1, nextIdx + nudge * 2))
                    if alt != nextIdx { nextIdx = alt }
                }
                let snappedNote = orderedPool[nextIdx]
                // Avoid same-note repeat: nudge direction if stuck at boundary
                if nextIdx == prevIdx { direction = -direction }

                // Brass: wide dynamic range — expressive swells
                // Reeds and mallet: moderate velocity variation
                let vel: UInt8
                if leadInstrument == .mutedTrumpet || leadInstrument == .trumpet {
                    let brassBase = velBase + rng.nextInt(upperBound: 30) - 8  // wider swing: ±~20 from base
                    vel = UInt8(Swift.max(52, Swift.min(108, brassBase)))
                } else {
                    vel = UInt8(Swift.max(30, Swift.min(100, velBase + rng.nextInt(upperBound: 16))))
                }
                slots.append(NoteSlot(step: stepIndex, pitch: snappedNote, vel: vel))
                prevIdx  = nextIdx
                prevNote = snappedNote
            }
        }
        _ = prevNote  // suppress unused-variable warning

        // Phrase-ending note: snap to chord tones (root, 3rd, 5th of the active chord) for ≥85% of phrases.
        // Use phraseEndChord.chordTones when available — more accurate than computing from key root.
        if rng.nextDouble() < 0.85, !slots.isEmpty {
            let strongPCs: Set<Int>
            if let chord = phraseEndChord, !chord.chordTones.isEmpty {
                strongPCs = chord.chordTones
            } else {
                // Fallback: root + mode-appropriate 3rd + 5th based on key
                let thirdInterval = (frame.mode == .Ionian || frame.mode == .Mixolydian) ? 4 : 3
                strongPCs = Set([0, thirdInterval, 7].map { (frame.keySemitoneValue + $0) % 12 })
            }
            var pool2 = orderedPool.filter { strongPCs.contains($0 % 12) }
            // If no landing note in the narrow register pool, search ±12 semitones
            if pool2.isEmpty {
                pool2 = scale.filter { strongPCs.contains($0 % 12) &&
                    $0 >= regLow - 12 && $0 <= regHigh + 12 }
                    .sorted().reduce(into: [Int]()) { acc, n in if acc.last != n { acc.append(n) } }
            }
            if !pool2.isEmpty {
                let lastPitch = slots[slots.count - 1].pitch
                let landingPitch = pool2.min(by: { abs($0 - lastPitch) < abs($1 - lastPitch) }) ?? pool2[0]
                slots[slots.count - 1].pitch = landingPitch
            }
        }

        // Assign durations: each note ends ≥1 step before the next note starts (monophonic).
        // The final note in the phrase keeps its instrument-specific duration.
        for i in 0..<slots.count {
            let maxDur: Int
            if i + 1 < slots.count {
                // Leave at least 1 step gap to the next note
                maxDur = Swift.max(1, slots[i + 1].step - slots[i].step - 1)
            } else {
                maxDur = noteDurSteps
            }
            let dur = Swift.min(noteDurSteps, maxDur)
            events.append(MIDIEvent(stepIndex: slots[i].step, note: UInt8(slots[i].pitch),
                                    velocity: slots[i].vel, durationSteps: Swift.max(1, dur)))
        }
        return events
    }

    // MARK: - Helpers

    private static func lead1RuleID(for instrument: ChillLeadInstrument) -> String {
        switch instrument {
        case .flute:        return "CHL-LD1-001"
        case .mutedTrumpet: return "CHL-LD1-002"
        case .vibraphone:   return "CHL-LD1-003"
        case .saxophone:    return "CHL-LD1-004"
        case .sopranoSax:   return "CHL-LD1-006"
        case .trumpet:      return "CHL-LD1-007"
        case .trombone:     return "CHL-LD2-002"  // trombone is Lead 2 only; rule ID for completeness
        }
    }

    private static func register(for instrument: ChillLeadInstrument) -> (low: Int, high: Int) {
        switch instrument {
        case .flute:        return (65, 85)
        case .mutedTrumpet: return (53, 80)  // widened: jazz leads span 2.5+ octaves with big leaps
        case .trumpet:      return (55, 79)  // open trumpet: slightly higher ceiling than muted
        case .vibraphone:   return (60, 80)
        case .saxophone:    return (50, 70)
        case .sopranoSax:   return (58, 80)  // soprano sits higher than alto/tenor
        case .trombone:     return (45, 65)  // warm low brass — Lead 2 counter-melody register
        }
    }

    private static func scaleNotes(frame: GlobalMusicalFrame) -> [Int] {
        let root = 60 + frame.keySemitoneValue
        return frame.mode.intervals.flatMap { interval -> [Int] in
            [root + interval - 24, root + interval - 12, root + interval, root + interval + 12, root + interval + 24]
        }.filter { $0 >= 36 && $0 <= 96 }
    }

    private static func pentatonicNotes(frame: GlobalMusicalFrame) -> [Int] {
        // Dorian pentatonic: [0, 2, 3, 7, 9] (root, 2, b3, 5, 6)
        // For other modes, use the mode's pentatonic subset
        let pentIntervals: [Int]
        switch frame.mode {
        case .Dorian:     pentIntervals = [0, 2, 3, 7, 9]
        case .Aeolian:    pentIntervals = [0, 3, 5, 7, 10]
        case .Mixolydian: pentIntervals = [0, 2, 4, 7, 9]
        case .Ionian:     pentIntervals = [0, 2, 4, 7, 9]
        default:          pentIntervals = [0, 2, 3, 7, 10]
        }
        let root = 60 + frame.keySemitoneValue
        return pentIntervals.flatMap { interval -> [Int] in
            [root + interval - 24, root + interval - 12, root + interval, root + interval + 12]
        }.filter { $0 >= 36 && $0 <= 96 }
    }

    private static func blueNotePC(frame: GlobalMusicalFrame) -> Int {
        // Blue note = b5 (+6 semitones from root) — spice, not scale degree
        return (frame.keySemitoneValue + 6) % 12
    }

    private static func snapToRegister(_ note: Int, pool: [Int], regLow: Int, regHigh: Int) -> Int {
        // Find closest note in pool that is within [regLow, regHigh]
        let inRange = pool.filter { $0 >= regLow && $0 <= regHigh }
        guard !inRange.isEmpty else { return Swift.max(regLow, Swift.min(regHigh, note)) }
        return inRange.min(by: { abs($0 - note) < abs($1 - note) }) ?? note
    }

    // MARK: - CHL-LD1-005: St Germain Staccato

    /// CHL-LD1-005: Inspired by St Germain "So Flute" — short staccato bursts (2–4 notes,
    /// 1–2 steps each) in active periods of 4–8 bars (one burst every 2 bars), separated by
    /// silent gaps of 4–8 bars. Far sparser than the source (~7.5 notes/bar) but retains the
    /// staccato 16th-note articulation character. Instrument-agnostic (pitch pool from scale).
    /// Breakdown section always silent.
    private static func stGermainStaccato(frame: GlobalMusicalFrame, structure: SongStructure,
                                           breakdownStyle: ChillBreakdownStyle,
                                           rng: inout SeededRNG) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let scale   = scaleNotes(frame: frame)
        // Mid-high register, instrument-agnostic
        let regLow  = 60 + frame.keySemitoneValue % 12
        let regHigh = regLow + 24
        let pool    = scale.filter { $0 >= regLow && $0 <= regHigh }.sorted()
            .reduce(into: [Int]()) { acc, n in if acc.last != n { acc.append(n) } }
        guard pool.count >= 3 else { return events }

        // Root note index for tonic-anchoring
        let tonicPC  = frame.keySemitoneValue % 12
        let tonicIdx = pool.indices.min(by: { abs(pool[$0] % 12 - tonicPC) < abs(pool[$1] % 12 - tonicPC) }) ?? 0

        var bar = 0
        while bar < frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Breakdown: behavior depends on style
            if label == .bridge {
                switch breakdownStyle {
                case .bassOstinato:
                    // Silent — bass carries the groove alone
                    bar += 1; continue
                case .stopTime:
                    // Play 2–4 note burst in the "silence" bars between stabs (odd breakdown bars)
                    let breakdownBar = bar - (section?.startBar ?? bar)
                    if breakdownBar % 2 == 0 {
                        bar += 1; continue  // stab bar — lead silent
                    }
                    if !pool.isEmpty {
                        let burstCount = 2 + rng.nextInt(upperBound: 3)
                        let barBase    = bar * 16
                        var step       = barBase + rng.nextInt(upperBound: 4)
                        var prevIdx    = tonicIdx
                        for i in 0..<burstCount {
                            guard step < barBase + 15 else { break }
                            let delta = rng.nextDouble() < 0.70 ? (rng.nextDouble() < 0.5 ? 1 : -1)
                                                                 : (rng.nextDouble() < 0.5 ? 2 : -2)
                            prevIdx = Swift.max(0, Swift.min(pool.count - 1, prevIdx + delta))
                            let isLast = i == burstCount - 1
                            let remaining = barBase + 15 - step
                            let dur = isLast ? Swift.min(4 + rng.nextInt(upperBound: 4), remaining)
                                             : 1 + rng.nextInt(upperBound: 2)
                            let vel = UInt8(60 + i * 3 + rng.nextInt(upperBound: 18))
                            events.append(MIDIEvent(stepIndex: step, note: UInt8(pool[prevIdx]),
                                                    velocity: vel, durationSteps: Swift.max(1, dur)))
                            step += dur + (isLast ? 0 : rng.nextInt(upperBound: 2))
                        }
                    }
                    bar += 1; continue
                case .harmonicDrone:
                    break  // treat like a groove bar (fall through to active period logic)
                }
            }
            if label == .intro || label == .outro {
                bar += 2 + rng.nextInt(upperBound: 4)
                continue
            }

            // Active period: 4–8 bars with a burst every 2 bars
            let activeBars = 4 + rng.nextInt(upperBound: 5)
            let sectionEnd = section.map { $0.startBar + $0.lengthBars } ?? frame.totalBars
            let activeEnd  = Swift.min(bar + activeBars, sectionEnd)

            var activeCursor = bar
            while activeCursor < activeEnd {
                // Place burst at start of this 2-bar window
                let burstCount  = 2 + rng.nextInt(upperBound: 3)  // 2–4 notes
                let barBase     = activeCursor * 16
                let windowEnd   = (activeCursor + 2) * 16
                // Burst starts anywhere in the first 8 steps of the bar (slight rhythmic variety)
                var step = barBase + rng.nextInt(upperBound: 8)

                // Collect pitch indices first so we can handle the final note separately
                var prevIdx = tonicIdx
                var burstIndices = [Int]()
                for _ in 0..<burstCount {
                    let delta = rng.nextDouble() < 0.70 ? (rng.nextDouble() < 0.5 ? 1 : -1)
                                                        : (rng.nextDouble() < 0.5 ? 2 : -2)
                    prevIdx = Swift.max(0, Swift.min(pool.count - 1, prevIdx + delta))
                    burstIndices.append(prevIdx)
                }

                // Snap last burst note to a chord tone for strong phrase resolution
                if let lastIdx = burstIndices.indices.last {
                    let activeChord = structure.chordPlan.first { $0.contains(bar: activeCursor) }
                    if let chord = activeChord, !chord.chordTones.isEmpty {
                        let chordPool = pool.filter { chord.chordTones.contains($0 % 12) }
                        if !chordPool.isEmpty {
                            let lastPitch = pool[burstIndices[lastIdx]]
                            let snapped   = chordPool.min(by: { abs($0 - lastPitch) < abs($1 - lastPitch) }) ?? chordPool[0]
                            burstIndices[lastIdx] = pool.indices.min(by: { abs(pool[$0] - snapped) < abs(pool[$1] - snapped) }) ?? lastIdx
                        }
                    }
                }

                for (i, noteIdx) in burstIndices.enumerated() {
                    guard step < windowEnd else { break }
                    let note   = pool[noteIdx]
                    let isLast = i == burstIndices.count - 1

                    let dur: Int
                    if isLast {
                        // Last note: always ≥ quarter note (4 steps); usually slightly longer.
                        let remaining = windowEnd - step
                        let short     = Swift.min(4 + rng.nextInt(upperBound: 3), remaining)  // 4–6 steps (quarter–dotted quarter)
                        let long      = Swift.min(6 + rng.nextInt(upperBound: 5), remaining)  // 6–10 steps
                        dur = rng.nextDouble() < 0.70 ? long : short  // 70% longer hold
                    } else {
                        dur = 1 + rng.nextInt(upperBound: 2)  // 1–2 steps (16th or 8th)
                    }

                    // Velocity builds slightly across the burst; last note a touch louder
                    let velBase = isLast ? 72 : 60 + i * 2
                    let vel = UInt8(Swift.min(95, velBase + rng.nextInt(upperBound: 16)))
                    events.append(MIDIEvent(stepIndex: step, note: UInt8(note),
                                            velocity: vel, durationSteps: Swift.max(1, dur)))
                    step += dur + (isLast ? 0 : rng.nextInt(upperBound: 2))  // tiny gap between non-last notes
                }
                activeCursor += 2  // next burst 2 bars later
            }

            // Silent gap: 4–8 bars before next active period.
            // Clamp so we don't jump over an upcoming section boundary (e.g. a bridge) —
            // the main loop needs to visit the bridge bar-by-bar to generate stop-time solos.
            let gapDest = activeEnd + 4 + rng.nextInt(upperBound: 5)
            // Find the start of any section that begins between activeEnd and gapDest
            var nextBoundary = gapDest
            for b in (activeEnd + 1)..<Swift.min(gapDest, frame.totalBars) {
                if let sec = structure.section(atBar: b), sec.startBar == b {
                    nextBoundary = b; break
                }
            }
            bar = nextBoundary
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    /// Convert a flat event list to (startBar, endBar) onset pairs for Lead 2 awareness.
    private static func eventsToOnsets(events: [MIDIEvent], totalBars: Int) -> [(startBar: Int, endBar: Int)] {
        guard !events.isEmpty else { return [] }
        var activeBars = Set<Int>()
        for ev in events { activeBars.insert(ev.stepIndex / 16) }
        let sorted = activeBars.sorted()
        var onsets: [(startBar: Int, endBar: Int)] = []
        var start = sorted[0]
        var prev  = sorted[0]
        for bar in sorted.dropFirst() {
            if bar > prev + 2 {
                onsets.append((startBar: start, endBar: prev + 1))
                start = bar
            }
            prev = bar
        }
        onsets.append((startBar: start, endBar: prev + 1))
        return onsets
    }
}
