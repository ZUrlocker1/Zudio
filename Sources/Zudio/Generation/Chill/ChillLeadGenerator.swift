// ChillLeadGenerator.swift — Chill generation step 6
// Copyright (c) 2026 Zack Urlocker
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
        bluesVariation: Bool = false,
        forceRuleID: String? = nil,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> (events: [MIDIEvent], phraseOnsets: [(startBar: Int, endBar: Int)], handoffBars: Set<Int>) {
        // CHL-LD1-005: St Germain staccato style — suppressed in blues (blues needs sustained phrases).
        let forceNonStaccato = bluesVariation || (forceRuleID != nil && forceRuleID != "CHL-LD1-005")
        let staccatoProb: Double = forceNonStaccato ? 0.0 : (beatStyle == .stGermain ? 0.85 : 0.15)
        if rng.nextDouble() < staccatoProb {
            usedRuleIDs.insert("CHL-LD1-005")
            let events = stGermainStaccato(frame: frame, structure: structure,
                                           breakdownStyle: breakdownStyle, rng: &rng)
            // Build phraseOnsets from the events for Lead 2 call-and-response awareness
            let onsets = eventsToOnsets(events: events, totalBars: frame.totalBars)
            return (events, onsets, [])   // staccato already has long silences; no extra handoff
        }

        // Rule selection is independent of instrument — instrument controls timbre/register,
        // rule controls phrasing behavior.
        //
        // Blues pool: 009 35%, 004 35%, 002 20%, 003 10%.
        // (001 "St Germain Long Phrase" and 005 "St Germain Staccato Burst" excluded —
        //  European jazz flute phrasing and staccato club feel are wrong for blues character.)
        //
        // Regular Chill pool: 001 20%, 002 20%, 003 15%, 004 13%, 007 12%, 008 12%, 009 8%.
        // (005 "St Germain Staccato Burst" handled by separate staccato path above.)
        let ruleID: String
        if bluesVariation {
            let bluesPool = ["CHL-LD1-004","CHL-LD1-009","CHL-LD1-002","CHL-LD1-003"]
            if let forced = forceRuleID, bluesPool.contains(forced) {
                ruleID = forced
            } else {
                let r = rng.nextDouble()
                ruleID = r < 0.35 ? "CHL-LD1-009"
                       : r < 0.70 ? "CHL-LD1-004"
                       : r < 0.90 ? "CHL-LD1-002"
                       :            "CHL-LD1-003"
            }
        } else {
            let chillPool = ["CHL-LD1-001","CHL-LD1-002","CHL-LD1-003","CHL-LD1-004",
                             "CHL-LD1-007","CHL-LD1-008","CHL-LD1-009"]
            if let forced = forceRuleID, chillPool.contains(forced) {
                ruleID = forced
            } else if forceRuleID != nil {
                ruleID = forceRuleID!   // allow 005 and other overrides to pass through
            } else {
                let r = rng.nextDouble()
                ruleID = r < 0.20 ? "CHL-LD1-001"
                       : r < 0.40 ? "CHL-LD1-002"
                       : r < 0.55 ? "CHL-LD1-003"
                       : r < 0.68 ? "CHL-LD1-004"
                       : r < 0.80 ? "CHL-LD1-007"
                       : r < 0.92 ? "CHL-LD1-008"
                       :            "CHL-LD1-009"
            }
        }
        let useJazzIdioms   = (ruleID == "CHL-LD1-009")
        let useBluesRuns    = (ruleID == "CHL-LD1-004")   // CHL-LD1-004: occasional fast blues runs
        let isShortPunch    = (ruleID == "CHL-LD1-002")   // CHL-LD1-002: compact staccato punches
        let isSparseMelodic = (ruleID == "CHL-LD1-003")   // CHL-LD1-003: sparse phrasing, per-bar density
        usedRuleIDs.insert(ruleID)

        var events: [MIDIEvent] = []
        var phraseOnsets: [(startBar: Int, endBar: Int)] = []

        let scale       = scaleNotes(frame: frame)
        let pentatonic  = pentatonicNotes(frame: frame)
        let blueNote    = blueNotePC(frame: frame)
        let (regLow, regHigh) = register(for: leadInstrument)

        // Pre-compute handoff windows: 1–2 blocks of 4–6 bars in groove sections where LD1
        // is forced silent so LD2 can take over. Placed in the middle portion of each section
        // so they don't collide with section entrances or exits.
        var handoffBarSet = Set<Int>()
        let grooveSections = structure.sections.filter { $0.label == .A || $0.label == .B }
        let windowCount = 1 + rng.nextInt(upperBound: 2)   // 1 or 2 windows
        var sectionsUsed = Set<Int>()
        for _ in 0..<windowCount {
            let available = grooveSections.indices.filter { !sectionsUsed.contains($0) }
            guard !available.isEmpty else { break }
            let idx = available[rng.nextInt(upperBound: available.count)]
            sectionsUsed.insert(idx)
            let sec = grooveSections[idx]
            let winLen = 4 + rng.nextInt(upperBound: 3)    // 4–6 bars
            guard sec.lengthBars >= winLen + 6 else { continue }   // need room to breathe
            // Place in the middle half of the section — avoid first and last quarters
            let earliest = sec.startBar + sec.lengthBars / 4
            let latest   = sec.endBar   - winLen - sec.lengthBars / 4
            guard latest > earliest else { continue }
            let winStart = earliest + rng.nextInt(upperBound: latest - earliest)
            for b in winStart..<(winStart + winLen) { handoffBarSet.insert(b) }
        }

        // Stop-time breakdown: cap solo bars at 4 or 6 to leave some odd bars silent
        let stopTimeSoloMax = rng.nextDouble() < 0.50 ? 4 : 6
        var stopTimeSoloBarsUsed = 0

        // Zone-based phrase repetition for all melodic Chill lead rules except CHL-LD1-005
        // (St Germain staccato burst, which has its own active-period architecture).
        // First 2 phrases in groove-A are stored as seeds; replayed once each in the
        // opening, then freely developed, then recalled in the final 40% with a
        // last-note flip so the ending sounds like a familiar motif with a fresh tail.
        let useZoneRepeat = (ruleID != "CHL-LD1-005")
        var seedPhrases:       [[MIDIEvent]] = []
        var seedPhraseLengths: [Int]         = []
        var openingReplaysDone = 0
        let recapStartBar = (frame.totalBars * 3) / 5   // 60% — shorter free zone, longer recap

        // Blues form: section anchors for posInForm tracking (same approach as drums/bass/pads)
        let (bSectionStart, aSectionStart) = bluesVariation ? bluesSectionAnchors(structure: structure) : (-1, -1)

        // Blues: lead must have played at least one phrase before bar 4 of section A.
        // Suppresses the lay-out rule and overrides silence probability until first phrase fires.
        var bluesLeadHasPlayed = false

        var bar = 0
        while bar < frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Cold start: bar 0 is drums-only, lead silent.
            // Blues: leads are silent for the entire intro — rhythm section sets the pocket first.
            if case .coldStart = structure.introStyle, bar == 0 {
                bar += 1; continue
            }
            if bluesVariation && label == .intro {
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
                case .groovePocket:
                    // Lead silent — pads and drums carry the section
                    bar += 1
                    continue
                }
            }

            // Handoff window: LD1 forced silent so LD2 can take the melody
            if handoffBarSet.contains(bar) { bar += 1; continue }

            // Brass and blues leads occasionally "lay out" for a full 4 or 8 bars — jazz breathing room.
            // Suppressed in blues until the lead has played at least once (guarantees early A-section entry).
            // Blues caps lay-out at 4 bars: an 8-bar lay-out at the start of a chorus can chain with
            // another and silence a full 16-bar pass, which prevents harmony from firing.
            // CHL-LD1-002 in blues: reduce lay-out probability to 5% — short punches should keep
            // the groove alive rather than dropping out for 4 bars at a time.
            let layOutProb: Double = (bluesVariation && isShortPunch) ? 0.05 : 0.12
            if (leadInstrument == .trumpet || leadInstrument == .mutedTrumpet || leadInstrument == .saxophone || leadInstrument == .tenorSax || leadInstrument == .clarinet),
               label == .A || label == .B,
               !(bluesVariation && !bluesLeadHasPlayed),
               rng.nextDouble() < layOutProb {
                bar += (bluesVariation || rng.nextDouble() < 0.60) ? 4 : 8
                continue
            }

            // Blues form: handle turnaround zone (positions 14–15 of 16-bar form).
            // Position 15 always silent (drums/bass own the turnaround bar).
            // Position 14: optional descending lick (50%) or rest; beats 3–4 left clear for fill.
            let bluesFormPos = bluesVariation
                ? bluesFormPosition(bar: bar, label: label, bStart: bSectionStart, aStart: aSectionStart)
                : -1
            if bluesFormPos >= 14 {
                if bluesFormPos == 14 && rng.nextDouble() < 0.50 {
                    events += bluesTurnaroundLick(base: bar * 16, frame: frame,
                                                  regLow: regLow, regHigh: regHigh,
                                                  useChromatic: useJazzIdioms, rng: &rng)
                }
                bar += 1; continue
            }

            // Blues: force the lead to play within the first 4 bars of the groove section.
            // Once the lead has played once, normal silence/rest rules resume.
            let forceBluesEntry = bluesVariation && !bluesLeadHasPlayed
                && (label == .A || label == .B)
                && bar >= (section?.startBar ?? 0) + 4

            if !forceBluesEntry {
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
                // CHL-LD1-002 in blues: less silence in A so punches keep the energy going
                case .A:      silenceProb = (bluesVariation && isShortPunch) ? 0.25 : 0.40
                case .B:      silenceProb = 0.10  // most active in groove B — consistently denser than A
                default:      silenceProb = 0.50
                }

                if rng.nextDouble() < silenceProb {
                    // Rest: 1–2 bars
                    bar += 1 + rng.nextInt(upperBound: 2)
                    continue
                }
            }

            // Phrase length: instrument-specific
            let phraseLen: Int
            switch leadInstrument {
            case .flute:         phraseLen = 3 + rng.nextInt(upperBound: 2)   // 3–4 bars
            case .mutedTrumpet:  phraseLen = 2                                 // 2 bars (punchy)
            case .vibraphone:    phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .saxophone:     phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .tenorSax:      phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars (slightly longer than alto)
            case .sopranoSax:    phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .trumpet:       phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .clarinet:      phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars (smoky, patient)
            case .trombone:      phraseLen = 2 + rng.nextInt(upperBound: 3)   // 2–4 bars (smooth, longer lines)
            }

            // Clamp phrase to section boundary; intro/outro phrases max 2 bars to keep density low
            let sectionEnd = section.map { $0.startBar + $0.lengthBars } ?? frame.totalBars
            let maxPhraseLen = (label == .intro || label == .outro) ? 2 : phraseLen
            var actualPhraseLen = Swift.min(maxPhraseLen, sectionEnd - bar)
            guard actualPhraseLen > 0 else { bar += 1; continue }

            // Blues form: clamp phrase to not cross a chord-change seam (IVm7 pos 8, V7 pos 12, turnaround pos 15)
            if bluesVariation && bluesFormPos >= 0 {
                let nextSeam = [8, 12, 15].first { $0 > bluesFormPos } ?? 16
                actualPhraseLen = Swift.min(actualPhraseLen, nextSeam - bluesFormPos)
            }

            // Zone-based repetition: seed collection → opening replay → free development → recap
            if useZoneRepeat, label == .A || label == .B {
                let canReplayOpening = openingReplaysDone < 2 && seedPhrases.count == 2

                if seedPhrases.count < 2 {
                    // Seed zone: generate normally and store as relative-indexed motif.
                    // Blues increases blue-note probability from 15% to 50%.
                    let bluePcProb = bluesVariation ? 0.50 : 0.15
                    let phraseBluePc = rng.nextDouble() < bluePcProb ? blueNote : nil
                    let phraseEndChord   = structure.chordPlan.first { $0.contains(bar: bar + actualPhraseLen - 1) }
                    let phraseStartChord = bluesVariation ? structure.chordPlan.first { $0.contains(bar: bar) } : nil
                    let phraseNotes = buildPhrase(frame: frame, bar: bar, bars: actualPhraseLen,
                                                   leadInstrument: leadInstrument,
                                                   pentatonic: pentatonic, scale: scale,
                                                   blueNotePC: phraseBluePc,
                                                   regLow: regLow, regHigh: regHigh,
                                                   section: label, phraseEndChord: phraseEndChord,
                                                   phraseStartChord: phraseStartChord,
                                                   useJazzIdioms: useJazzIdioms,
                                                   useBluesRuns: useBluesRuns,
                                                   isShortPunch: isShortPunch,
                                                   isSparseMelodic: isSparseMelodic, rng: &rng)
                    events += phraseNotes
                    phraseOnsets.append((startBar: bar, endBar: bar + actualPhraseLen))
                    let offset = bar * 16
                    seedPhrases.append(phraseNotes.map {
                        MIDIEvent(stepIndex: $0.stepIndex - offset, note: $0.note,
                                  velocity: $0.velocity, durationSteps: $0.durationSteps)
                    })
                    seedPhraseLengths.append(actualPhraseLen)
                    bluesLeadHasPlayed = true
                    bar += actualPhraseLen
                    bar += (label == .B) ? 1 : 1 + rng.nextInt(upperBound: 2)
                    continue
                }

                let canRecap = bar >= recapStartBar && rng.nextDouble() < 0.55
                // Blues: seeds were generated over the I chord; don't replay them over IV/V bars.
                // Fall through to normal phrase generation (chord-aware bodyPool) instead.
                let bluesReplayOK = !bluesVariation || bluesFormPos < 8
                if (canReplayOpening || canRecap) && bluesReplayOK {
                    let seedIdx = canReplayOpening ? (openingReplaysDone % seedPhrases.count)
                                                   : rng.nextInt(upperBound: seedPhrases.count)
                    let seedLen = seedPhraseLengths[seedIdx]
                    // Blues: don't replay if the seed would cross a chord-change seam.
                    let bluesSeamOK: Bool
                    if bluesVariation && bluesFormPos >= 0 {
                        let nextSeam = [8, 12, 15].first { $0 > bluesFormPos } ?? 16
                        bluesSeamOK = bluesFormPos + seedLen <= nextSeam
                    } else {
                        bluesSeamOK = true
                    }
                    if bar + seedLen <= sectionEnd && bluesSeamOK {
                        let base = bar * 16
                        var replayedNotes = seedPhrases[seedIdx].map {
                            MIDIEvent(stepIndex: $0.stepIndex + base, note: $0.note,
                                      velocity: $0.velocity, durationSteps: $0.durationSteps)
                        }
                        // Opening: 50% flip (jazz idioms: always); recap: always flip
                        if canRecap || useJazzIdioms || rng.nextDouble() < 0.50 {
                            replayedNotes = applyLastNoteFlip(replayedNotes, scale: scale,
                                                               regLow: regLow, regHigh: regHigh)
                        }
                        // 50% duration variation (jazz idioms: always — no exact opening replays)
                        if useJazzIdioms || rng.nextDouble() < 0.50 {
                            replayedNotes = applyLastNoteDuration(replayedNotes, rng: &rng)
                        }
                        events += replayedNotes
                        phraseOnsets.append((startBar: bar, endBar: bar + seedLen))
                        if canReplayOpening { openingReplaysDone += 1 }
                        bluesLeadHasPlayed = true
                        bar += seedLen
                        bar += (label == .B) ? 1 : 1 + rng.nextInt(upperBound: 2)
                        continue
                    }
                    // Seed doesn't fit remaining section — count replay as done to avoid getting stuck
                    if canReplayOpening { openingReplaysDone += 1 }
                }
            }

            // Normal phrase generation (free development zone, or replay fallback).
            // Blues raises blue-note probability from 15% to 50%.
            let bluePcProb2 = bluesVariation ? 0.50 : 0.15
            let phraseBluePc = rng.nextDouble() < bluePcProb2 ? blueNote : nil
            let phraseEndChord   = structure.chordPlan.first { $0.contains(bar: bar + actualPhraseLen - 1) }
            let phraseStartChord = bluesVariation ? structure.chordPlan.first { $0.contains(bar: bar) } : nil
            let phraseNotes = buildPhrase(
                frame: frame, bar: bar, bars: actualPhraseLen,
                leadInstrument: leadInstrument,
                pentatonic: pentatonic, scale: scale,
                blueNotePC: phraseBluePc,
                regLow: regLow, regHigh: regHigh,
                section: label,
                phraseEndChord: phraseEndChord,
                phraseStartChord: phraseStartChord,
                useJazzIdioms: useJazzIdioms,
                useBluesRuns: useBluesRuns,
                isShortPunch: isShortPunch,
                isSparseMelodic: isSparseMelodic,
                rng: &rng
            )
            events += phraseNotes
            phraseOnsets.append((startBar: bar, endBar: bar + actualPhraseLen))
            bluesLeadHasPlayed = true

            bar += actualPhraseLen
            // Mandatory rest after phrase (CHL-RULE-06); Groove B capped at 1 bar; CHL-LD1-002 blues
            // also capped at 1 bar so punches keep the groove alive without long halting gaps.
            let extraRest = (label == .B || (bluesVariation && isShortPunch)) ? 0 : rng.nextInt(upperBound: 2)
            bar += 1 + extraRest
        }
        return (events, phraseOnsets, handoffBarSet)
    }

    // MARK: - Lead 2

    static func generateLead2(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        lead1Instrument: ChillLeadInstrument,
        lead1Onsets: [(startBar: Int, endBar: Int)],
        handoffBars: Set<Int> = [],
        bluesVariation: Bool = false,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> (events: [MIDIEvent], instrument: ChillLeadInstrument) {
        // Blues forces CHL-LD2-001 (call-and-response) — shadow hold is too ambient for blues energy.
        let useShadowHold = bluesVariation ? false : rng.nextDouble() < 0.50
        usedRuleIDs.insert(useShadowHold ? "CHL-LD2-002" : "CHL-LD2-001")

        var events: [MIDIEvent] = []
        let scale      = scaleNotes(frame: frame)
        let pentatonic = pentatonicNotes(frame: frame)

        // Lead 2 instrument: complement Lead 1 — pitched percussion (vibraphone) contrasts brass/reeds;
        // trombone adds warm low-brass depth when Lead 1 is a reed; flute lightens if Lead 1 is vibraphone.
        let inst2: ChillLeadInstrument
        switch lead1Instrument {
        case .vibraphone:
            // Vibraphone never used as Lead 1 in blues — flute pairing is regular-Chill only
            inst2 = .flute
        case .saxophone:
            // Alto Sax Lead 1 (regular Chill only — not in blues pool)
            // Regular: vibraphone 65%, trombone 10%, flute 20%, soprano sax 5%
            let r0 = rng.nextDouble()
            if r0 < 0.65      { inst2 = .vibraphone }
            else if r0 < 0.75 { inst2 = .trombone }
            else if r0 < 0.95 { inst2 = .flute }
            else              { inst2 = .sopranoSax }
        case .flute:
            // Flute Lead 1 (regular Chill only — not in blues pool)
            // Regular: vibraphone 80%, trombone 20%
            inst2 = rng.nextDouble() < 0.80 ? .vibraphone : .trombone
        case .clarinet:
            // Clarinet Lead 1 — appears in both regular Chill and blues
            let rc = rng.nextDouble()
            if bluesVariation {
                // Blues: vibraphone 50%, soprano sax 30%, trombone 20% — no flute
                if rc < 0.50      { inst2 = .vibraphone }
                else if rc < 0.80 { inst2 = .sopranoSax }
                else              { inst2 = .trombone }
            } else {
                // Regular: vibraphone 55%, trombone 10%, flute 35%
                if rc < 0.55      { inst2 = .vibraphone }
                else if rc < 0.65 { inst2 = .trombone }
                else              { inst2 = .flute }
            }
        default:
            // Brass Lead 1 (muted trumpet, trumpet, tenor sax) — main blues Lead 1 family
            let r = rng.nextDouble()
            if bluesVariation {
                // Blues: soprano sax 40%, vibraphone 40%, trombone 20% — no flute
                if r < 0.40      { inst2 = .sopranoSax }
                else if r < 0.80 { inst2 = .vibraphone }
                else             { inst2 = .trombone }
            } else {
                // Regular: vibraphone 50%, flute 35%, soprano sax 10%, trombone 5%
                if r < 0.50      { inst2 = .vibraphone }
                else if r < 0.85 { inst2 = .flute }
                else if r < 0.95 { inst2 = .sopranoSax }
                else             { inst2 = .trombone }
            }
        }
        let (regLow1, regHigh1) = register(for: lead1Instrument)
        let (rawLow2, rawHigh2) = register(for: inst2)
        // Lead 2 sits below the midpoint of Lead 1's register (CHL-RULE-12).
        // Using the midpoint (not regLow1) prevents degenerate one-note pools when Lead 1
        // has a low bottom register (e.g. regLow near 52 → midpoint cap → only a few scale notes).
        let regMid1  = (regLow1 + regHigh1) / 2
        let regHigh2 = min(rawHigh2, regMid1 - 2)
        let regLow2  = max(36, min(rawLow2, regHigh2 - 12))

        // CHL-LD2-002: Shadow hold — long-held chord tones sounding under Lead 1 simultaneously
        if useShadowHold {
            let events = shadowHold(frame: frame, structure: structure,
                                    lead1Onsets: lead1Onsets, scale: scale,
                                    regLow: regLow2, regHigh: regHigh2, rng: &rng)
            return (events, inst2)
        }

        // CHL-LD2-001: Call-and-response — responds in gaps between Lead 1 phrases
        var lead1BarSet = Set<Int>()
        for onset in lead1Onsets {
            for b in onset.startBar..<onset.endBar { lead1BarSet.insert(b) }
        }

        // Blues form: section anchors for turnaround zone silence (pos 13–15 are Lead-2-free)
        let (ld2_bSectionStart, ld2_aSectionStart) = bluesVariation ? bluesSectionAnchors(structure: structure) : (-1, -1)

        var bar = 0
        while bar < frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Lead 2 only in groove sections (A and B)
            guard label == .A || label == .B else { bar += 1; continue }

            // Blues: turnaround zone (pos 13–15) — Lead 2 silent; Lead 1 lick + drums own this
            if bluesVariation
                && bluesFormPosition(bar: bar, label: label, bStart: ld2_bSectionStart, aStart: ld2_aSectionStart) >= 13 {
                bar += 1; continue
            }

            // Skip bars where Lead 1 is playing
            guard !lead1BarSet.contains(bar) else { bar += 1; continue }
            // Handoff window: LD2 strongly encouraged to fill bars LD1 was forced to skip.
            // Normal: 40% in A (sparse), 80% in B (dense).
            let responseProb: Double = handoffBars.contains(bar) ? 0.90
                : (label == .A ? 0.40 : 0.80)
            guard rng.nextDouble() < responseProb else { bar += 1; continue }

            let sectionEnd = section.map { $0.startBar + $0.lengthBars } ?? frame.totalBars
            // 2-bar phrases for Lead 2; blues: clamp to chord seam so phrases don't span chord changes
            var phraseLen = Swift.min(2, sectionEnd - bar)
            if bluesVariation {
                let ld2FormPos = bluesFormPosition(bar: bar, label: label, bStart: ld2_bSectionStart, aStart: ld2_aSectionStart)
                if ld2FormPos >= 0 {
                    let nextSeam = [8, 12, 15].first { $0 > ld2FormPos } ?? 16
                    phraseLen = Swift.min(phraseLen, nextSeam - ld2FormPos)
                }
            }
            guard phraseLen > 0 else { bar += 1; continue }

            // Check gap is free of Lead 1
            let gapFree = (bar..<bar + phraseLen).allSatisfy { !lead1BarSet.contains($0) }
            guard gapFree else { bar += 1; continue }

            let ld2PhraseStartChord = bluesVariation ? structure.chordPlan.first { $0.contains(bar: bar) } : nil
            let phraseNotes = buildPhrase(
                frame: frame, bar: bar, bars: phraseLen,
                leadInstrument: inst2,
                pentatonic: pentatonic, scale: scale,
                blueNotePC: nil,
                regLow: regLow2, regHigh: regHigh2,
                section: label,
                phraseStartChord: ld2PhraseStartChord,
                rng: &rng,
                velocityOffset: inst2 == .vibraphone ? 0 : -15  // vibraphone reads quietly; match Lead 1 level
            )
            events += phraseNotes
            bar += phraseLen + 1  // mandatory 1-bar rest after each phrase (CHL-RULE-06 breathing room)
        }
        return (events, inst2)
    }

    // MARK: - CHL-LD2-002: Shadow Hold

    /// CHL-LD2-002: Long-held chord tones sounding underneath Lead 1 simultaneously.
    /// Iterates all Lead 1 active bars across groove sections; places a hold whenever
    /// ≥2 bars have elapsed since the last hold and a 50% roll clears. Each hold lasts
    /// 16–28 steps. Notes are chord tones in the lower octave of Lead 2's register.
    /// Velocity is soft (38–55) so the shadow sits under Lead 1 without competing.
    private static func shadowHold(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        lead1Onsets: [(startBar: Int, endBar: Int)],
        scale: [Int],
        regLow: Int,
        regHigh: Int,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Sorted Lead 1 active bars restricted to groove sections
        let grooveBarSet = Set(structure.sections
            .filter { $0.label == .A || $0.label == .B }
            .flatMap { s in s.startBar..<(s.startBar + s.lengthBars) })
        var lead1BarSet = Set<Int>()
        for onset in lead1Onsets { for b in onset.startBar..<onset.endBar { lead1BarSet.insert(b) } }
        let activeBars = lead1BarSet.intersection(grooveBarSet).sorted()
        guard !activeBars.isEmpty else { return [] }

        // Shadow notes sit in the lower octave of Lead 2's register
        let shadowHigh = Swift.min(regLow + 13, regHigh)
        var lastPlaced = -4

        for bar in activeBars {
            guard bar >= lastPlaced + 2 else { continue }   // minimum 2-bar spacing
            guard rng.nextDouble() < 0.50 else { continue } // 50% chance when gap is met

            let chord        = structure.chordPlan.first { $0.contains(bar: bar) }
            let chordTonePCs = chord?.chordTones ?? Set<Int>()
            var pool = scale.filter { $0 >= regLow && $0 <= shadowHigh }
            if !chordTonePCs.isEmpty {
                let chordPool = pool.filter { chordTonePCs.contains($0 % 12) }
                if !chordPool.isEmpty { pool = chordPool }
            }
            guard !pool.isEmpty else { continue }

            let note   = UInt8(pool[rng.nextInt(upperBound: pool.count)])
            let maxDur = frame.totalBars * 16 - bar * 16
            let dur    = Swift.min(16 + rng.nextInt(upperBound: 13), maxDur)  // 16–28 steps
            let vel    = UInt8(38 + rng.nextInt(upperBound: 18))              // 38–55

            events.append(MIDIEvent(stepIndex: bar * 16, note: note,
                                    velocity: vel, durationSteps: Swift.max(1, dur)))
            lastPlaced = bar
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
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
        phraseStartChord: ChordWindow? = nil,
        useJazzIdioms: Bool = false,
        useBluesRuns: Bool = false,
        isShortPunch: Bool = false,
        isSparseMelodic: Bool = false,
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
        var notesPerBar: Int
        if section == .intro || section == .outro {
            notesPerBar = 2
        } else {
            switch leadInstrument {
            case .flute:        notesPerBar = 2 + rng.nextInt(upperBound: 2)   // 2–3
            case .mutedTrumpet: notesPerBar = 3 + rng.nextInt(upperBound: 2)   // 3–4
            case .trumpet:      notesPerBar = 3 + rng.nextInt(upperBound: 2)   // 3–4
            case .vibraphone:   notesPerBar = 3 + rng.nextInt(upperBound: 3)   // 3–5
            case .saxophone:    notesPerBar = 3 + rng.nextInt(upperBound: 3)   // 3–5
            case .tenorSax:     notesPerBar = 3 + rng.nextInt(upperBound: 3)   // 3–5 (rich, bluesy lines)
            case .sopranoSax:   notesPerBar = 2 + rng.nextInt(upperBound: 3)   // 2–4
            case .trombone:     notesPerBar = 2 + rng.nextInt(upperBound: 2)   // 2–3 (smooth legato, fewer notes)
            case .clarinet:     notesPerBar = 3 + rng.nextInt(upperBound: 2)   // 3–4 (breathy, slightly sparse)
            }
        }
        // CHL-LD1-009: enforce minimum 4 notes per body bar — denser lines for jazz character
        if useJazzIdioms && section != .intro && section != .outro {
            notesPerBar = Swift.max(4, notesPerBar)
        }

        // Duration per note in steps: instrument-specific
        let noteDurSteps: Int
        switch leadInstrument {
        case .flute:        noteDurSteps = 8 + rng.nextInt(upperBound: 5)   // 8–12 steps (legato)
        case .mutedTrumpet: noteDurSteps = 2 + rng.nextInt(upperBound: 3)   // 2–4 steps (staccato)
        case .trumpet:      noteDurSteps = 3 + rng.nextInt(upperBound: 3)   // 3–5 steps
        case .vibraphone:   noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
        case .saxophone:    noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
        case .tenorSax:     noteDurSteps = 5 + rng.nextInt(upperBound: 5)   // 5–9 steps (slightly longer, warmer tone)
        case .sopranoSax:   noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
        case .trombone:     noteDurSteps = 6 + rng.nextInt(upperBound: 7)   // 6–12 steps (long legato slides)
        case .clarinet:     noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps (chalumeau breath)
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

        // Blues: strip avoid tones of the active chord from the body pool so body notes
        // don't clash over IV and V bars (e.g. B♮ over Gm7 = tritone against F).
        // orderedPool (full) is kept for phrase-ending chord-tone snapping below.
        var bodyPool = orderedPool
        if let chord = phraseStartChord, !chord.avoidTones.isEmpty {
            let filtered = orderedPool.filter { !chord.avoidTones.contains($0 % 12) }
            if filtered.count >= 3 { bodyPool = filtered }
        }

        // Starting note: bias toward chord tones when phrase opens on a chord change (IVm7, V7)
        let startIdx: Int
        if let startChord = phraseStartChord, !startChord.chordTones.isEmpty {
            let chordPool = bodyPool.filter { startChord.chordTones.contains($0 % 12) }
            if !chordPool.isEmpty {
                let target = chordPool[rng.nextInt(upperBound: chordPool.count)]
                startIdx = bodyPool.indices.min(by: { abs(bodyPool[$0] - target) < abs(bodyPool[$1] - target) }) ?? 0
            } else {
                let tonicNote = regLow + 5 + rng.nextInt(upperBound: Swift.max(1, regHigh - regLow - 5))
                startIdx = bodyPool.indices.min(by: { abs(bodyPool[$0] - tonicNote) < abs(bodyPool[$1] - tonicNote) }) ?? 0
            }
        } else {
            let tonicNote = regLow + 5 + rng.nextInt(upperBound: Swift.max(1, regHigh - regLow - 5))
            startIdx = bodyPool.indices.min(by: { abs(bodyPool[$0] - tonicNote) < abs(bodyPool[$1] - tonicNote) }) ?? 0
        }
        var prevIdx   = startIdx
        var prevNote  = bodyPool[prevIdx]
        var direction = 1               // +1 ascending, -1 descending
        var lastWasLeap = false         // after a leap, strongly prefer stepwise (CHL-RULE-07)

        // Collect (stepIndex, pitch, velocity) first; assign durations after so we can
        // clamp each note to end before the next one starts — guaranteeing monophonic output.
        struct NoteSlot { var step: Int; var pitch: Int; var vel: UInt8 }
        var slots: [NoteSlot] = []

        // CHL-LD1-009: jazz idiom phrase starters — turn figure (30%), riff cell (20%), or normal (50%).
        // Idiom starters pre-fill bar 0; skipBars advances the main loop past that bar.
        enum PhraseStart { case normal, turnFigure, riffCell }
        let phraseStart: PhraseStart
        if useJazzIdioms && bars >= 2 {
            let r = rng.nextDouble()
            phraseStart = r < 0.30 ? .turnFigure : (r < 0.50 ? .riffCell : .normal)
        } else {
            phraseStart = .normal
        }
        let skipBars = phraseStart == .normal ? 0 : 1
        let barBase0 = bar * 16

        if phraseStart == .turnFigure {
            // [Lo, T, Hi, T, Lo, T] ornament at 2-step spacing around anchor chord tone T
            let ctPool = bodyPool.filter { phraseStartChord?.chordTones.contains($0 % 12) ?? false }
            let anchorNote: Int = !ctPool.isEmpty
                ? ctPool[rng.nextInt(upperBound: ctPool.count)]
                : bodyPool[bodyPool.count / 2]
            let tIdx  = bodyPool.indices.min(by: { abs(bodyPool[$0] - anchorNote) < abs(bodyPool[$1] - anchorNote) }) ?? bodyPool.count / 2
            let loIdx = Swift.max(0, tIdx - 1)
            let hiIdx = Swift.min(bodyPool.count - 1, tIdx + 1)
            let pattern   = [loIdx, tIdx, hiIdx, tIdx, loIdx, tIdx]
            let velShapes = [-4, 8, 4, 6, 0, 10]
            for (k, pidx) in pattern.enumerated() {
                let s = barBase0 + k * 2
                guard s < frame.totalBars * 16 else { break }
                let v = UInt8(Swift.max(30, Swift.min(100, velBase + velShapes[k] + rng.nextInt(upperBound: 8))))
                slots.append(NoteSlot(step: s, pitch: bodyPool[pidx], vel: v))
            }
            prevIdx  = tIdx
            prevNote = bodyPool[tIdx]
        }

        if phraseStart == .riffCell {
            // Oscillating [T, Lo, Approach] × 1–2 cycles with varied spacing, then a register break.
            // Approach = Lo−1 (chromatic, non-pool). Cycle widths vary 4–6 steps for rhythmic variety.
            // Anchor is constrained to the upper half of the register so the riff + break stay
            // out of the muddy low zone.
            let ctPool = bodyPool.filter { phraseStartChord?.chordTones.contains($0 % 12) ?? false }
            let midPitch = (regLow + regHigh) / 2
            let upperCtPool   = ctPool.filter { $0 >= midPitch }
            let upperBodyPool = bodyPool.filter { $0 >= midPitch }
            let anchorNote: Int = !upperCtPool.isEmpty
                ? upperCtPool[rng.nextInt(upperBound: upperCtPool.count)]
                : !upperBodyPool.isEmpty
                    ? upperBodyPool[rng.nextInt(upperBound: upperBodyPool.count)]
                    : bodyPool[bodyPool.count / 2]
            let tIdx     = bodyPool.indices.min(by: { abs(bodyPool[$0] - anchorNote) < abs(bodyPool[$1] - anchorNote) }) ?? bodyPool.count / 2
            let loIdx    = Swift.max(0, tIdx - 1)
            let tPitch   = bodyPool[tIdx]
            let loPitch  = bodyPool[loIdx]
            let appPitch = loPitch - 1
            let cycles   = 1 + rng.nextInt(upperBound: 2)   // 1–2 cycles (room left for break)
            var cycleBase = barBase0
            for _ in 0..<cycles {
                let cycleWidth = 4 + rng.nextInt(upperBound: 3)   // 4, 5, or 6 steps
                let s0 = cycleBase; let s1 = cycleBase + 2; let s2 = cycleBase + cycleWidth - 1
                guard s2 < frame.totalBars * 16 && s2 < barBase0 + 13 else { break }
                let vT   = UInt8(Swift.max(30, Swift.min(100, velBase + 10 + rng.nextInt(upperBound: 6))))
                let vLo  = UInt8(Swift.max(30, Swift.min(100, velBase +  2 + rng.nextInt(upperBound: 6))))
                let vApp = UInt8(Swift.max(30, Swift.min(100, velBase -  4 + rng.nextInt(upperBound: 6))))
                slots.append(NoteSlot(step: s0, pitch: tPitch,   vel: vT))
                slots.append(NoteSlot(step: s1, pitch: loPitch,  vel: vLo))
                slots.append(NoteSlot(step: s2, pitch: appPitch, vel: vApp))
                cycleBase += cycleWidth
            }
            // Register break: leap up 3–5 pool steps then step down — the blues "setup + payoff".
            if cycleBase < barBase0 + 12 && rng.nextDouble() < 0.70 {
                let pivotIdx = Swift.min(bodyPool.count - 1, tIdx + 3 + rng.nextInt(upperBound: 3))
                let down1Idx = Swift.max(0, pivotIdx - 1)
                let down2Idx = Swift.max(0, pivotIdx - 2)
                let s0 = cycleBase; let s1 = s0 + 2; let s2 = s1 + 2
                if s2 < frame.totalBars * 16 && s2 < barBase0 + 15 {
                    slots.append(NoteSlot(step: s0, pitch: bodyPool[pivotIdx],
                                          vel: UInt8(Swift.max(30, Swift.min(100, velBase + 15 + rng.nextInt(upperBound: 8))))))
                    slots.append(NoteSlot(step: s1, pitch: bodyPool[down1Idx],
                                          vel: UInt8(Swift.max(30, Swift.min(100, velBase +  8 + rng.nextInt(upperBound: 6))))))
                    slots.append(NoteSlot(step: s2, pitch: bodyPool[down2Idx],
                                          vel: UInt8(Swift.max(30, Swift.min(100, velBase +  4 + rng.nextInt(upperBound: 6))))))
                }
            }
            prevIdx  = loIdx
            prevNote = loPitch
        }

        for barOffset in skipBars..<bars {
            let barBase = (bar + barOffset) * 16
            // CHL-LD1-009: jazz burst mode — 25% of bars get 5–7 rapid notes at 2-step spacing,
            // creating the short burst character that defines classic jazz phrasing.
            // CHL-LD1-004: blues run mode — 20% of bars get 3–5 rapid notes at 2–3 step spacing,
            // mimicking horn players throwing in quick passing-tone licks between longer phrases.
            let burstMode     = useJazzIdioms  && section != .intro && section != .outro && rng.nextDouble() < 0.25
            let bluesRunMode  = useBluesRuns   && section != .intro && section != .outro && rng.nextDouble() < 0.20
            let barNotes: Int
            let spacing:  Int
            let sparsePhaseOffset: Int   // only used when isSparseMelodic
            if burstMode {
                barNotes = 5 + rng.nextInt(upperBound: 3)   // 5–7
                spacing  = 2
                sparsePhaseOffset = 0
            } else if bluesRunMode {
                barNotes = 3 + rng.nextInt(upperBound: 3)   // 3–5
                spacing  = 2 + rng.nextInt(upperBound: 2)   // 2–3 steps
                sparsePhaseOffset = 0
            } else if isSparseMelodic && section != .intro && section != .outro {
                // Option C: draw fresh density each bar — lyrical (30%), moderate (50%), cluster (20%)
                let dr = rng.nextDouble()
                if dr < 0.30 {
                    barNotes = 1 + rng.nextInt(upperBound: 2)   // 1–2 notes: long, lyrical
                    spacing  = barNotes == 1 ? 8 : 6 + rng.nextInt(upperBound: 4)
                } else if dr < 0.80 {
                    barNotes = 3 + rng.nextInt(upperBound: 2)   // 3–4 notes: moderate
                    spacing  = 3 + rng.nextInt(upperBound: 3)   // 3–5 steps (tighter grouping)
                } else {
                    barNotes = 5                                 // cluster run
                    spacing  = 2
                }
                // Shift the whole cluster to a random beat position within the bar
                let maxPhase = Swift.max(0, 15 - (barNotes - 1) * spacing)
                sparsePhaseOffset = maxPhase > 0 ? rng.nextInt(upperBound: maxPhase + 1) : 0
            } else {
                barNotes = notesPerBar
                spacing  = 16 / notesPerBar
                sparsePhaseOffset = 0
            }
            // CHL-LD1-002: syncopated spacing — pairs with a mid-bar breath instead of a
            // mechanical even grid. First note lands on or just off the beat; subsequent notes
            // cluster in pairs with a gap between, giving the "dit-dit [breath] dahh" feel.
            let punchOffsets: [Int]
            if isShortPunch && !burstMode && !bluesRunMode {
                let s = rng.nextDouble() < 0.45 ? 0 : 2  // on-beat or pickup
                switch barNotes {
                case 2:
                    let gap = 6 + rng.nextInt(upperBound: 5)                      // 6–10 step gap
                    punchOffsets = [s, Swift.min(15, s + gap)]
                case 3:
                    let t  = 2 + rng.nextInt(upperBound: 2)                        // 2–3 tight
                    let g  = t + 5 + rng.nextInt(upperBound: 4)                    // 7–11 from start
                    punchOffsets = [s, Swift.min(13, s + t), Swift.min(15, s + g)]
                case 4:
                    let t1 = 2 + rng.nextInt(upperBound: 2)                        // 2–3
                    let g2 = t1 + 4 + rng.nextInt(upperBound: 3)                  // gap of 6–9 from start
                    punchOffsets = [s, s + t1, Swift.min(13, s + g2), Swift.min(15, s + g2 + 2)]
                default:
                    punchOffsets = (0..<barNotes).map { $0 * spacing }
                }
            } else {
                punchOffsets = (0..<barNotes).map { $0 * spacing }
            }

            for noteIdx in 0..<barNotes {
                // CHL-LD1-002: syncopated offsets; other brass: off-beat pickup on note 0
                let stepOffset: Int
                if isShortPunch && !burstMode {
                    stepOffset = noteIdx < punchOffsets.count ? punchOffsets[noteIdx] : noteIdx * spacing
                } else if isSparseMelodic && !burstMode {
                    stepOffset = sparsePhaseOffset + noteIdx * spacing
                } else if (leadInstrument == .mutedTrumpet || leadInstrument == .trumpet) && noteIdx == 0 && !burstMode {
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
                } else if useJazzIdioms {
                    stepProb = lastWasLeap ? 0.82 : 0.65  // more leaps for jazz idioms — angular, wider phrases
                } else {
                    stepProb = lastWasLeap ? 0.90 : 0.75
                }
                var nextIdx: Int
                if rng.nextDouble() < stepProb {
                    // Step: adjacent pool index
                    let candidate = prevIdx + direction
                    if candidate >= 0 && candidate < bodyPool.count {
                        nextIdx = candidate
                    } else {
                        // Hit boundary — reverse and jump 2–3 steps inward to break ping-pong
                        direction = -direction
                        let inward = 2 + rng.nextInt(upperBound: 2)
                        nextIdx = Swift.max(0, Swift.min(bodyPool.count - 1, prevIdx + direction * inward))
                    }
                    lastWasLeap = false
                } else {
                    // Leap: skip 2–3 pool positions
                    let skip = 2 + rng.nextInt(upperBound: 2)
                    let candidate = prevIdx + direction * skip
                    if candidate >= 0 && candidate < bodyPool.count {
                        nextIdx = candidate
                    } else {
                        direction = -direction
                        nextIdx = Swift.max(0, Swift.min(bodyPool.count - 1, prevIdx + direction * skip))
                    }
                    direction = -direction  // reverse after leap
                    lastWasLeap = true
                }
                // Avoid same-pitch-class repeat: nudge 2 positions further if we'd land on the same PC
                if bodyPool.count > 3 && bodyPool[nextIdx] % 12 == prevNote % 12 {
                    let nudge = direction != 0 ? direction : 1
                    let alt = Swift.max(0, Swift.min(bodyPool.count - 1, nextIdx + nudge * 2))
                    if alt != nextIdx { nextIdx = alt }
                }
                let snappedNote = bodyPool[nextIdx]
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

        // CHL-LD1-009: chromatic approach note leading into the first body slot (35% chance).
        // Only applied when phraseStart is .normal — idiom starters already shape the entry.
        // Shifts the first slot 2 steps forward and inserts a lower-neighbor semitone before it.
        if useJazzIdioms && phraseStart == .normal && !slots.isEmpty && rng.nextDouble() < 0.35 {
            let first = slots[0]
            let shiftedStep = first.step + 2
            let maxStepInBar = (first.step / 16 + 1) * 16 - 1
            let nextStep = slots.count >= 2 ? slots[1].step : Int.max
            if shiftedStep <= maxStepInBar && shiftedStep < nextStep {
                slots[0].step = shiftedStep
                let approachVel = UInt8(Swift.max(30, Swift.min(100, Int(first.vel) - 18)))
                slots.insert(NoteSlot(step: first.step, pitch: first.pitch - 1, vel: approachVel), at: 0)
            }
        }

        // Phrase-split: saxophone and trumpet (wide-interval / blues lead) phrases longer than 7 notes
        // are broken into two shorter sub-phrases by dropping 1–2 notes near the middle. This creates
        // a brief rest that makes long lines breathe rather than run continuously.
        if (leadInstrument == .saxophone || leadInstrument == .tenorSax || leadInstrument == .trumpet),
           slots.count > 7 {
            // Aim for the break at 45–55% through the phrase
            let breakCenter = Int(Double(slots.count) * (0.45 + rng.nextDouble() * 0.10))
            let dropCount = rng.nextDouble() < 0.55 ? 2 : 1   // usually drop 2; occasionally just 1
            let dropStart = Swift.max(1, Swift.min(breakCenter, slots.count - dropCount - 1))
            slots.removeSubrange(dropStart ..< Swift.min(dropStart + dropCount, slots.count - 1))
        }

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
                    $0 >= regLow - 3 && $0 <= regHigh + 12 }
                    .sorted().reduce(into: [Int]()) { acc, n in if acc.last != n { acc.append(n) } }
            }
            if !pool2.isEmpty {
                let lastPitch = slots[slots.count - 1].pitch
                let landingPitch = pool2.min(by: { abs($0 - lastPitch) < abs($1 - lastPitch) }) ?? pool2[0]
                slots[slots.count - 1].pitch = landingPitch
            }
        }

        // CHL-LD1-002: remove orphaned tail notes — a slot is "orphaned" when it's the last
        // in its bar, the gap from the previous same-bar note is large (> 6 steps), and it's
        // not the final note of the whole phrase. These sound like accidental stray notes.
        if isShortPunch && slots.count > 2 {
            var toRemove = IndexSet()
            for i in 1..<(slots.count - 1) {
                let barIdx = slots[i].step / 16
                let isLastInBar = slots[i + 1].step / 16 != barIdx
                let prevSameBar = slots[i - 1].step / 16 == barIdx
                let gapBefore = prevSameBar ? slots[i].step - slots[i - 1].step : 0
                if isLastInBar && gapBefore > 6 { toRemove.insert(i) }
            }
            if !toRemove.isEmpty {
                slots = slots.enumerated().filter { !toRemove.contains($0.offset) }.map { $0.element }
            }
        }

        // Assign durations: each note ends ≥1 step before the next note starts (monophonic).
        // CHL-LD1-004: per-note duration variation — 30% short punches (2–3 steps), 50% normal
        // (4–8 steps), 20% longer holds (8–12 steps) — gives the blues horn a more varied,
        // realistic feel instead of uniform note lengths.
        for i in 0..<slots.count {
            let maxDur: Int
            if i + 1 < slots.count {
                maxDur = Swift.max(1, slots[i + 1].step - slots[i].step - 1)
            } else {
                maxDur = noteDurSteps * 2   // final note: allow a longer hold
            }
            var baseDur: Int
            if useBluesRuns {
                let r = rng.nextDouble()
                if r < 0.30 {
                    baseDur = 2 + rng.nextInt(upperBound: 2)    // 2–3 steps: short punch
                } else if r < 0.80 {
                    baseDur = noteDurSteps                       // 4–8 steps: normal
                } else {
                    baseDur = noteDurSteps + 4 + rng.nextInt(upperBound: 5)  // 8–12 steps: held note
                }
            } else if isShortPunch {
                // Per-note duration mix — 40% stab, 40% medium, 20% held.
                let r = rng.nextDouble()
                if r < 0.40 {
                    baseDur = 1 + rng.nextInt(upperBound: 2)    // 1–2 steps: quick stab
                } else if r < 0.80 {
                    baseDur = 3 + rng.nextInt(upperBound: 3)    // 3–5 steps: medium
                } else {
                    baseDur = 6 + rng.nextInt(upperBound: 4)    // 6–9 steps: held note
                }
                // If the gap to the next note is large and this note is still short,
                // extend it to fill the gap — avoids "dit-dit [big gap] dit" fragmented feel.
                if i + 1 < slots.count {
                    let gapToNext = slots[i + 1].step - slots[i].step
                    if gapToNext > 5 && baseDur < 4 { baseDur = gapToNext - 1 }
                }
            } else if isSparseMelodic {
                // Option A: 20% ornament, 55% medium, 25% long sustain.
                // Last note always gets a long ring-out regardless of roll.
                let r = rng.nextDouble()
                if i == slots.count - 1 || r >= 0.75 {
                    baseDur = noteDurSteps + 5 + rng.nextInt(upperBound: 6)  // long sustain
                } else if r < 0.20 {
                    baseDur = 2 + rng.nextInt(upperBound: 2)                 // 2–3: quick ornament
                } else {
                    baseDur = noteDurSteps                                    // instrument medium
                }
            } else {
                baseDur = noteDurSteps
            }
            let dur = Swift.min(baseDur, maxDur)
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
        case .tenorSax:     return "CHL-LD1-008"
        case .trombone:     return "CHL-LD2-002"  // Lead 2 only
        case .clarinet:     return "CHL-LD1-004"  // blues phrasing is the natural idiom
        }
    }

    private static func register(for instrument: ChillLeadInstrument) -> (low: Int, high: Int) {
        switch instrument {
        case .flute:        return (65, 85)
        case .mutedTrumpet: return (58, 80)
        case .trumpet:      return (58, 79)
        case .vibraphone:   return (60, 80)
        case .saxophone:    return (58, 72)   // alto sax lead: Bb3–C5 (D3 floor was too muddy)
        case .tenorSax:     return (57, 72)   // tenor sax lead: A3–C5
        case .sopranoSax:   return (58, 80)   // soprano sits higher than alto/tenor
        case .trombone:     return (45, 65)   // warm low brass — Lead 2 counter-melody register
        case .clarinet:     return (58, 72)   // clarinet lead: Bb3–C5 (D3 floor was too muddy)
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

    /// Blues lead variation: replace the last note of a phrase with the nearest scale note
    /// that resolves in the OPPOSITE direction from the second-to-last note.
    /// The phrase body stays identical; only the tail changes, creating the sense of a
    /// familiar motif with a fresh ending.
    private static func applyLastNoteFlip(_ notes: [MIDIEvent], scale: [Int],
                                           regLow: Int, regHigh: Int) -> [MIDIEvent] {
        guard notes.count >= 2 else { return notes }
        let sorted     = notes.sorted { $0.stepIndex < $1.stepIndex }
        let last       = sorted[sorted.count - 1]
        let secondLast = sorted[sorted.count - 2]
        let originalUp = Int(last.note) > Int(secondLast.note)
        let pool       = scale.filter { $0 >= regLow && $0 <= regHigh }.sorted()
        let flipped: Int
        if originalUp {
            // Was ascending → resolve downward: highest scale note below secondLast
            flipped = pool.filter { $0 < Int(secondLast.note) }.last ?? Int(last.note)
        } else {
            // Was descending → resolve upward: lowest scale note above secondLast
            flipped = pool.filter { $0 > Int(secondLast.note) }.first ?? Int(last.note)
        }
        guard flipped != Int(last.note) else { return notes }
        var result = notes
        for i in result.indices.reversed() {
            if result[i].stepIndex == last.stepIndex {
                result[i] = MIDIEvent(stepIndex: result[i].stepIndex, note: UInt8(flipped),
                                       velocity: result[i].velocity,
                                       durationSteps: result[i].durationSteps)
                break
            }
        }
        return result
    }

    /// Blues lead duration variation: if the last note of a replayed phrase is short (≤4 steps /
    /// quarter note), lengthen it; if long (≥8 steps), shorten it. Middle-range notes unchanged.
    private static func applyLastNoteDuration(_ notes: [MIDIEvent], rng: inout SeededRNG) -> [MIDIEvent] {
        guard !notes.isEmpty else { return notes }
        guard let lastIdx = notes.indices.max(by: { notes[$0].stepIndex < notes[$1].stepIndex }) else { return notes }
        let dur = Int(notes[lastIdx].durationSteps)
        let newDur: Int
        if dur <= 4 {
            newDur = 6 + rng.nextInt(upperBound: 5)   // short → long: 6–10 steps
        } else if dur >= 8 {
            newDur = 3 + rng.nextInt(upperBound: 3)   // long → short: 3–5 steps
        } else {
            return notes                                // middle range — leave as-is
        }
        var result = notes
        result[lastIdx] = MIDIEvent(stepIndex: result[lastIdx].stepIndex,
                                    note:       result[lastIdx].note,
                                    velocity:   result[lastIdx].velocity,
                                    durationSteps: newDur)
        return result
    }

    /// Returns (bSectionStart, aSectionStart) bar indices for blues form tracking.
    /// bSectionStart is -1 if no B section exists; aSectionStart falls back to bSectionStart.
    private static func bluesSectionAnchors(structure: SongStructure) -> (bStart: Int, aStart: Int) {
        let b = structure.sections.first { $0.label == .B }?.startBar ?? -1
        let a = structure.sections.first { $0.label == .A }?.startBar ?? b
        return (b, a)
    }

    /// Returns the position (0–15) within the 16-bar blues form for the given bar,
    /// or -1 if the bar is not in a groove section (A or B) or the anchor is invalid.
    private static func bluesFormPosition(bar: Int, label: SectionLabel, bStart: Int, aStart: Int) -> Int {
        guard label == .A || label == .B else { return -1 }
        let anchor = (label == .B) ? bStart : aStart
        guard anchor >= 0 else { return -1 }
        return (bar - anchor) % 16
    }

    private static func snapToRegister(_ note: Int, pool: [Int], regLow: Int, regHigh: Int) -> Int {
        // Find closest note in pool that is within [regLow, regHigh]
        let inRange = pool.filter { $0 >= regLow && $0 <= regHigh }
        guard !inRange.isEmpty else { return Swift.max(regLow, Swift.min(regHigh, note)) }
        return inRange.min(by: { abs($0 - note) < abs($1 - note) }) ?? note
    }

    /// Blues form position 14: 3–4 note descending figure on beats 1–2 (steps 0–6),
    /// leaving beats 3–4 clear for the drum fill that precedes the turnaround bar.
    /// useChromatic: descend by semitones (chromatic passing tones) instead of scale steps.
    private static func bluesTurnaroundLick(
        base: Int,
        frame: GlobalMusicalFrame,
        regLow: Int,
        regHigh: Int,
        useChromatic: Bool = false,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let scale = scaleNotes(frame: frame)
        let pool = scale.filter { $0 >= regLow && $0 <= regHigh }.sorted()
            .reduce(into: [Int]()) { acc, n in if acc.last != n { acc.append(n) } }
        guard pool.count >= 3 else { return [] }

        // Start from upper-mid register and descend toward root
        let startNote = regLow + (regHigh - regLow) * 2 / 3
        var idx = pool.indices.min(by: { abs(pool[$0] - startNote) < abs(pool[$1] - startNote) }) ?? pool.count / 2

        let noteCount   = 3 + rng.nextInt(upperBound: 2)   // 3 or 4 notes
        let stepOffsets = [0, 2, 4, 6]                     // beats 1–2 only (steps 0–6)
        var events: [MIDIEvent] = []
        var chromaNote  = pool[idx]

        for i in 0..<noteCount {
            guard i < stepOffsets.count else { break }
            let noteToPlay: Int
            if useChromatic {
                if i > 0 { chromaNote = Swift.max(regLow, chromaNote - 1 - rng.nextInt(upperBound: 2)) }
                noteToPlay = chromaNote
            } else {
                if i > 0 { idx = Swift.max(0, idx - 1 - rng.nextInt(upperBound: 2)) }
                noteToPlay = pool[idx]
            }
            let vel = UInt8(62 + i * 4 + rng.nextInt(upperBound: 10))
            let dur = (i == noteCount - 1) ? 4 + rng.nextInt(upperBound: 3) : 2
            events.append(MIDIEvent(stepIndex: base + stepOffsets[i], note: UInt8(noteToPlay),
                                    velocity: vel, durationSteps: dur))
        }
        return events
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
                case .groovePocket:
                    bar += 1; continue  // lead 2 silent
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

    // MARK: - Blues harmony / unison section

    /// Post-processing pass: replaces Lead 2 events in `harmonyBars` with notes derived
    /// from Lead 1 — either diatonic parallel harmony (intervalSteps scale positions below)
    /// or unison (same pitch). Called from SongGenerator after both leads are generated.
    /// ~15% of Lead 1's shortest notes are dropped for natural player looseness.
    static func applyBluesHarmony(
        lead1Events: [MIDIEvent],
        lead2Events: inout [MIDIEvent],
        harmonyBars: Set<Int>,
        useUnison: Bool,
        intervalSteps: Int,
        maxPhrases: Int = 2,
        frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) {
        // Strip any existing Lead 2 events from the harmony window
        lead2Events = lead2Events.filter { !harmonyBars.contains($0.stepIndex / 16) }

        let scale = scaleNotes(frame: frame).sorted()
        guard !scale.isEmpty else { return }

        // Gather and sort Lead 1 events within the window
        let windowEvents = lead1Events
            .filter { harmonyBars.contains($0.stepIndex / 16) }
            .sorted { $0.stepIndex < $1.stepIndex }
        guard !windowEvents.isEmpty else { return }

        // Identify phrases by bar activity: contiguous runs of bars that have notes.
        // Any silent bar (no Lead 1 events) breaks the run → phrase boundary.
        // Keep only the first maxPhrases phrases.
        let activeBars = Set(windowEvents.map { $0.stepIndex / 16 }).sorted()
        var phraseBarGroups: [[Int]] = []
        var currentGroup: [Int] = []
        for bar in activeBars {
            if let last = currentGroup.last, bar - last > 1 {
                phraseBarGroups.append(currentGroup)
                currentGroup = []
            }
            currentGroup.append(bar)
        }
        if !currentGroup.isEmpty { phraseBarGroups.append(currentGroup) }

        let keptBars = Set(phraseBarGroups.prefix(maxPhrases).flatMap { $0 })
        let keptEvents = windowEvents.filter { keptBars.contains($0.stepIndex / 16) }

        for event in keptEvents {
            // Drop ~15% of very short notes — looseness like real horn players
            if Int(event.durationSteps) < 3 && rng.nextDouble() < 0.15 { continue }

            let pitch: Int
            if useUnison {
                pitch = Int(event.note)
            } else {
                // Find Lead 1's note in the sorted scale, then go intervalSteps positions down
                let noteInt = Int(event.note)
                let idx = scale.indices.min(by: { abs(scale[$0] - noteInt) < abs(scale[$1] - noteInt) }) ?? 0
                pitch = scale[Swift.max(0, idx - intervalSteps)]
            }

            lead2Events.append(MIDIEvent(
                stepIndex:     event.stepIndex,
                note:          UInt8(Swift.max(0, Swift.min(127, pitch))),
                velocity:      event.velocity,
                durationSteps: event.durationSteps
            ))
        }
        lead2Events.sort { $0.stepIndex < $1.stepIndex }
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
