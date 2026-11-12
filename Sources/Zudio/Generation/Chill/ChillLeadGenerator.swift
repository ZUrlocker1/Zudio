// ChillLeadGenerator.swift — Chill generation step 6
// Copyright (c) 2026 Zack Urlocker
// Lead 1: primary solo voice (flute, muted trumpet, vibraphone, saxophone).
// Lead 2: answers that riff on Lead 1 (CHL-LD2-003 to 006), shadow hold (CHL-LD2-002); Soho's
// call-and-response (CHL-LD2-001).
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
        sohoVariation: Bool = false,
        forceRuleID: String? = nil,
        lickVariants: Bool = true,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        replayBars reportReplayBars: ((Set<Int>) -> Void)? = nil,
        returns reportReturns: ((Set<Int>) -> Void)? = nil
    ) -> (events: [MIDIEvent], phraseOnsets: [(startBar: Int, endBar: Int)], handoffBars: Set<Int>,
          hookTreatments: String?) {
        // Chill Soho has its own three rules (ChillSohoLeadGenerator.swift). The two base rules it
        // reuses come back through here forced, so the St Germain staccato roll below still draws,
        // at probability 0.
        if sohoVariation {
            return sohoLead1(frame: frame, structure: structure, leadInstrument: leadInstrument,
                             breakdownStyle: breakdownStyle, forceRuleID: forceRuleID,
                             rng: &rng, usedRuleIDs: &usedRuleIDs, reportReturns: reportReturns)
        }
        // CHL-LD1-005: St Germain staccato style — suppressed in blues (blues needs sustained phrases).
        let forceNonStaccato = bluesVariation || (forceRuleID != nil && forceRuleID != "CHL-LD1-005")
        // 70% on the St Germain beat, 5% on the other four: about 18% of Chill songs (was 85/15, 29%).
        let staccatoProb: Double = forceNonStaccato ? 0.0 : (beatStyle == .stGermain ? 0.70 : 0.05)
        if rng.nextDouble() < staccatoProb {
            usedRuleIDs.insert("CHL-LD1-005")
            let events = stGermainStaccato(frame: frame, structure: structure,
                                           breakdownStyle: breakdownStyle, rng: &rng)
            // Build phraseOnsets from the events for Lead 2 call-and-response awareness
            let onsets = eventsToOnsets(events: events, totalBars: frame.totalBars)
            return (events, onsets, [], nil)   // staccato already has long silences; no extra handoff
        }

        // Rule selection is independent of instrument — instrument controls timbre/register,
        // rule controls phrasing behavior.
        //
        // Shares of all songs (work in progress, fine-tuned by ear):
        //   Blues: 013 20, 004 20, 002 20, 003 15, 009 13, 014 12
        //   Chill: 005 18, 015 17, 001 17, 014 15, 007 13, 008 13, 009 7
        // 001 Chet sigh, 007 Horace hook and 008 Blues bossa took over those numbers
        // and shares on 2026-11-11; the random-walk rules they replaced are retired.
        // 005 St Germain staccato is a separate roll above (70% on the St Germain beat, 5% on the
        // others) and never plays in Blues. 002, 003, 004 and 013 are Blues only; 015 is Chill only;
        // 014 and 009 play in both. 001 is excluded from Blues (flowing European flute phrasing).
        //
        // A first draw picks a jazz rule (Blues 32%, Chill 39% of the pool); otherwise the other
        // rules run on their own draw, with their shares rescaled to the rest.
        // Original weights before the jazz rules, to restore: delete the two `j <` branches and use
        //   Blues: 009 35, 004 35, 002 20, 003 10
        //   Chill: 001 20, 002 20, 003 15, 004 13, 007 12, 008 12, 009 8, staccato roll 85/15
        let jazzRules = ["CHL-LD1-013", "CHL-LD1-014", "CHL-LD1-015"]
        let ruleID: String
        if bluesVariation {
            let bluesPool = ["CHL-LD1-004","CHL-LD1-009","CHL-LD1-002","CHL-LD1-003",
                             "CHL-LD1-013","CHL-LD1-014"]
            if let forced = forceRuleID, bluesPool.contains(forced) {
                ruleID = forced
            } else if case let j = rng.nextDouble(), j < 0.32 {
                ruleID = j < 0.20 ? "CHL-LD1-013" : "CHL-LD1-014"
            } else {
                let r = rng.nextDouble()
                ruleID = r < 0.191 ? "CHL-LD1-009"
                       : r < 0.485 ? "CHL-LD1-004"
                       : r < 0.779 ? "CHL-LD1-002"
                       :             "CHL-LD1-003"
            }
        } else {
            let chillPool = ["CHL-LD1-001","CHL-LD1-007","CHL-LD1-008","CHL-LD1-009",
                             "CHL-LD1-014","CHL-LD1-015"]
            if let forced = forceRuleID, chillPool.contains(forced) {
                ruleID = forced
            } else if forceRuleID != nil {
                ruleID = forceRuleID!   // allow 005 and other overrides to pass through
            } else if case let j = rng.nextDouble(), j < 0.390 {
                ruleID = j < 0.183 ? "CHL-LD1-014" : "CHL-LD1-015"
            } else {
                // 002 Miles punch, 003 Chet sparse and 004 Blues lead are Chill Blues only
                // (Zack, 2026-11-07); Soho still reaches 004 through forceRuleID.
                let r = rng.nextDouble()
                ruleID = r < 0.34 ? "CHL-LD1-001"
                       : r < 0.60 ? "CHL-LD1-007"
                       : r < 0.86 ? "CHL-LD1-008"
                       :            "CHL-LD1-009"
            }
        }
        let useJazzIdioms   = (ruleID == "CHL-LD1-009")
        let useBluesRuns    = (ruleID == "CHL-LD1-004")   // CHL-LD1-004: occasional fast blues runs
        let isShortPunch    = (ruleID == "CHL-LD1-002")   // CHL-LD1-002: compact staccato punches
        let isSparseMelodic = (ruleID == "CHL-LD1-003")   // CHL-LD1-003: sparse phrasing, per-bar density
        // CHL-LD1-013/014/015 and CHL-LD1-001/007/008: phrases come from a lick bank
        // (jazzCellPhrase) instead of buildPhrase. 001, 007 and 008 were scale random walks until
        // 2026-11-11 (Long phrase, Wide interval solo, Warm jazz line); those are retired and the
        // numbers now play Chet sigh, Horace hook and Blues bossa, wherever they are
        // drawn or forced (Soho reuses 001).
        let lickRules = jazzRules + ["CHL-LD1-001", "CHL-LD1-007", "CHL-LD1-008"]
        var jazzState: JazzCellState? = lickRules.contains(ruleID)
            ? JazzCellState(ruleID: ruleID, regLow: register(for: leadInstrument).low,
                            regHigh: register(for: leadInstrument).high,
                            keyPC: frame.keySemitoneValue, allowVariants: lickVariants, rng: &rng)
            : nil
        usedRuleIDs.insert(ruleID)

        var events: [MIDIEvent] = []
        var phraseOnsets: [(startBar: Int, endBar: Int)] = []

        let scale       = scaleNotes(frame: frame)
        let pentatonic  = pentatonicNotes(frame: frame)
        let blueNote    = blueNotePC(frame: frame)
        let (regLow, regHigh) = register(for: leadInstrument)

        // Blues: 60% of songs have a soloist who uses the blue note (the b5 of the key), the rest
        // play plain Dorian. In those songs about a third of phrases try for it until the first lands, and only as a
        // passing tone where it fits (see addBluePassingTones); a phrase with no fitting place
        // plays without it. After that the same move gets the blue note every time it comes up,
        // and the song's seed phrases carry it too, so it comes back as part of a lick.
        let bluesSoloistUsesBlueNote = bluesVariation && rng.nextDouble() < 0.60
        // The first time the blue note fits, that move (say C to D in G) becomes the soloist's lick:
        // from then on every phrase slides through the same move wherever it comes up.
        var blueNoteLick: (low: UInt8, high: UInt8)? = nil

        // A freshly built phrase, aware of the chord it ends on and, in Blues, the one it starts on.
        func freshPhrase(bar: Int, bars: Int, label: SectionLabel) -> [MIDIEvent] {
            let blueRoll = rng.nextDouble()
            let phraseEndChord   = structure.chordWindow(atBar: bar + bars - 1)
            let phraseStartChord = bluesVariation ? structure.chordWindow(atBar: bar) : nil
            if jazzState != nil {
                return jazzCellPhrase(state: &jazzState!, frame: frame, structure: structure,
                                      bar: bar, bars: bars, section: label,
                                      leadInstrument: leadInstrument,
                                      regLow: regLow, regHigh: regHigh, rng: &rng)
            }
            let phrase = buildPhrase(frame: frame, bar: bar, bars: bars,
                               leadInstrument: leadInstrument,
                               pentatonic: pentatonic, scale: scale,
                               blueNotePC: nil,
                               regLow: regLow, regHigh: regHigh,
                               section: label, phraseEndChord: phraseEndChord,
                               phraseStartChord: phraseStartChord,
                               useJazzIdioms: useJazzIdioms,
                               useBluesRuns: useBluesRuns,
                               isShortPunch: isShortPunch,
                               isSparseMelodic: isSparseMelodic, rng: &rng)
            guard bluesSoloistUsesBlueNote else { return phrase }
            if blueNoteLick == nil && blueRoll >= 0.33 { return phrase }
            let (withBlue, lick) = addBluePassingTones(phrase, frame: frame, structure: structure,
                                                       onlyLick: blueNoteLick)
            if blueNoteLick == nil { blueNoteLick = lick }
            return withBlue
        }

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

        // This draw set the old stop-time cap of 4 or 6 random solo bars. stopTimeSolo replaced
        // it (2026-11-11); the draw stays so songs without a stop-time breakdown are unchanged.
        _ = rng.nextDouble()
        var stopTimeSections = Set<Int>()

        // Zone-based phrase repetition for all melodic Chill lead rules except CHL-LD1-005
        // (St Germain staccato burst, which has its own active-period architecture).
        // First 2 phrases in groove-A are stored as seeds; replayed once each in the
        // opening, then freely developed with occasional mid-song returns (below), then
        // recalled in the final 40% with a last-note flip so the ending sounds like a familiar
        // motif with a fresh tail. In Blues a return that comes due off the I chord is held as
        // a pending recall and played, flipped, at the next I-chord bar.
        let useZoneRepeat = (ruleID != "CHL-LD1-005")
        var seedPhrases:       [[MIDIEvent]] = []
        var seedPhraseLengths: [Int]         = []
        var openingReplaysDone = 0
        let recapStartBar = (frame.totalBars * 3) / 5   // 60% — shorter free zone, longer recap
        // The free zone used to have no returns at all, so a solo could go 40–50 bars without its
        // opening idea (Zack, 2026-10-16). About one phrase in three there is now a seed, at least
        // eight bars after the last return, and only where it fits: seeds replay at their own
        // pitches, so each held note (three steps or longer) must be a chord tone or a colour
        // tone of the bar it lands on.
        var lastReturnBar  = Int.min / 2
        var replayBars     = Set<Int>()
        // Bars where a seed comes back after the opening replays — the log's "Lead 1 return to
        // form". A return here changes at most its last note or a note length, so to the ear it is
        // the opening phrase coming back. Recorded only; nothing here draws from the RNG.
        var formReturns    = Set<Int>()
        // Blues replays seeds only over the I chord. A recall that comes due anywhere else waits
        // for the next I-chord bar instead of being dropped, so the song still comes home to its
        // opening lick. One waits at a time.
        var pendingRecall  = false

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
                case .bassOstinato, .sohoRemix, .sohoDuo:   // remix: Lead 1 rests; duo: Rhythm and Bass alone
                    // Silent — bass carries the groove alone
                    bar += 1
                    continue
                case .stopTime:
                    // The whole breakdown's solo is written on the first bar Lead 1 reaches in it
                    // (a rest can step past the section's first bar). The fragment comes from the
                    // song's opening phrase, or Lead 1's latest notes if it has none yet.
                    if let sec = section, stopTimeSections.insert(sec.startBar).inserted {
                        var st = SeededRNG(seed: rng.next() ^ 0x5354_4F50_5449_4D45)   // "STOPTIME"
                        let motif = melodyPitches(seedPhrases.first ?? Array(events.suffix(6)))
                        events += stopTimeSolo(section: sec, frame: frame, structure: structure,
                                               motif: motif, regLow: regLow, regHigh: regHigh, rng: &st)
                    }
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

            // Phrase length: instrument-specific (the jazz cell rules set their own, below)
            var phraseLen: Int
            switch leadInstrument {
            case .flute:         phraseLen = 3 + rng.nextInt(upperBound: 2)   // 3–4 bars
            case .recorder:      phraseLen = 3 + rng.nextInt(upperBound: 2)   // 3–4 bars, as the flute
            case .mutedTrumpet:  phraseLen = 2                                 // 2 bars (punchy)
            case .vibraphone:    phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .saxophone:     phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .tenorSax:      phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars (slightly longer than alto)
            case .sopranoSax:    phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .trumpet:       phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            case .clarinet:      phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars (smoky, patient)
            case .trombone:      phraseLen = 2 + rng.nextInt(upperBound: 3)   // 2–4 bars (smooth, longer lines)
            case .synthBrass:    phraseLen = 2 + rng.nextInt(upperBound: 2)   // 2–3 bars
            }
            if let js = jazzState { phraseLen = js.phraseBars }

            // Clamp phrase to section boundary; intro/outro phrases max 2 bars to keep density low
            let sectionEnd = section.map { $0.startBar + $0.lengthBars } ?? frame.totalBars
            let maxPhraseLen = (label == .intro || label == .outro) ? 2 : phraseLen
            var actualPhraseLen = Swift.min(maxPhraseLen, sectionEnd - bar)
            guard actualPhraseLen > 0 else { bar += 1; continue }

            // Blues form: clamp phrase to not cross a chord-change seam (IVm7 pos 8, V7 pos 12, turnaround pos 15)
            if bluesVariation && bluesFormPos >= 0 {
                actualPhraseLen = Swift.min(actualPhraseLen, bluesNextSeam(after: bluesFormPos) - bluesFormPos)
            }

            // Zone-based repetition: seed collection → opening replay → free development → recap
            if useZoneRepeat, label == .A || label == .B {
                // Themed lick rules (001, 007, 008, 015) open A A B A: one replay of the first
                // seed, after the B theme has played, instead of replaying both seeds back to back.
                let themed = jazzState?.isThemed ?? false
                let canReplayOpening = openingReplaysDone < (themed ? 1 : 2) && seedPhrases.count == 2
                    && (!themed || (jazzState?.statements ?? 0) >= 3)

                if seedPhrases.count < 2 {
                    // Seed zone: generate normally and store as relative-indexed motif.
                    let phraseNotes = freshPhrase(bar: bar, bars: actualPhraseLen, label: label)
                    events += phraseNotes
                    phraseOnsets.append((startBar: bar, endBar: bar + actualPhraseLen))
                    let offset = bar * 16
                    seedPhrases.append(phraseNotes.map {
                        MIDIEvent(stepIndex: $0.stepIndex - offset, note: $0.note,
                                  velocity: $0.velocity, durationSteps: $0.durationSteps)
                    })
                    seedPhraseLengths.append(actualPhraseLen)
                    lastReturnBar = bar
                    bluesLeadHasPlayed = true
                    bar += actualPhraseLen
                    bar += (label == .B) ? 1 : 1 + rng.nextInt(upperBound: 2)
                    continue
                }

                // Themed rules recall the seeds less (30%, not 55%) so the B and C themes get room,
                // and never before the A A B A opening is complete.
                let openingDone = !themed || openingReplaysDone >= 1
                let canRecap = bar >= recapStartBar && rng.nextDouble() < (themed ? 0.30 : 0.55)
                    && openingDone
                // The seeds that fit this bar's chords, worked out only where a mid-song return
                // could otherwise happen. The 0.35 draw is made only when one fits.
                let midOpen = !canReplayOpening && seedPhrases.count == 2 && bar < recapStartBar
                    && bar >= lastReturnBar + 8 && openingDone
                let matching = !midOpen ? [] : seedPhrases.indices.filter { i in
                    seedPhrases[i].allSatisfy { e in
                        guard e.durationSteps >= 3,
                              let w = structure.chordWindow(atBar: bar + e.stepIndex / 16) else { return true }
                        let pc = Int(e.note) % 12
                        return w.chordTones.contains(pc) || w.scaleTensions.contains(pc)
                    }
                }
                let canMid = midOpen && !matching.isEmpty && rng.nextDouble() < 0.35
                // Blues: seeds were generated over the I chord; don't replay them over IV/V bars.
                // Fall through to normal phrase generation (chord-aware bodyPool) instead, and
                // hold the recall for the next I-chord bar.
                let bluesReplayOK = !bluesVariation || bluesFormPos < 8
                if bluesVariation && !bluesReplayOK && (canRecap || canMid) { pendingRecall = true }
                let duePending = pendingRecall && bluesReplayOK
                if (canReplayOpening || canRecap || canMid || duePending) && bluesReplayOK {
                    let seedIdx = canReplayOpening ? (openingReplaysDone % seedPhrases.count)
                                : (canMid && !canRecap && !duePending) ? matching[rng.nextInt(upperBound: matching.count)]
                                                   : rng.nextInt(upperBound: seedPhrases.count)
                    let seedLen = seedPhraseLengths[seedIdx]
                    // Blues: don't replay if the seed would cross a chord-change seam.
                    let bluesSeamOK: Bool
                    if bluesVariation && bluesFormPos >= 0 {
                        bluesSeamOK = bluesFormPos + seedLen <= bluesNextSeam(after: bluesFormPos)
                    } else {
                        bluesSeamOK = true
                    }
                    if bar + seedLen <= sectionEnd && bluesSeamOK {
                        let base = bar * 16
                        var replayedNotes = seedPhrases[seedIdx].map {
                            MIDIEvent(stepIndex: $0.stepIndex + base, note: $0.note,
                                      velocity: $0.velocity, durationSteps: $0.durationSteps)
                        }
                        // Opening and mid-song: 50% flip (jazz idioms: always); recap and a due
                        // Blues pending recall: always flip
                        if canRecap || duePending || useJazzIdioms || rng.nextDouble() < 0.50 {
                            replayedNotes = applyLastNoteFlip(replayedNotes, scale: scale,
                                                               regLow: regLow, regHigh: regHigh)
                        }
                        // 50% duration variation (jazz idioms: always — no exact opening replays)
                        if useJazzIdioms || rng.nextDouble() < 0.50 {
                            replayedNotes = applyLastNoteDuration(replayedNotes, rng: &rng)
                        }
                        if !canReplayOpening { formReturns.insert(bar) }
                        events += replayedNotes
                        phraseOnsets.append((startBar: bar, endBar: bar + seedLen))
                        if canReplayOpening { openingReplaysDone += 1 }
                        if canRecap || duePending { pendingRecall = false }
                        lastReturnBar = bar
                        replayBars.formUnion(bar..<(bar + seedLen))
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
            let phraseNotes = freshPhrase(bar: bar, bars: actualPhraseLen, label: label)
            events += phraseNotes
            phraseOnsets.append((startBar: bar, endBar: bar + actualPhraseLen))
            bluesLeadHasPlayed = true

            bar += actualPhraseLen
            // Mandatory rest after phrase (CHL-RULE-06); Groove B capped at 1 bar; CHL-LD1-002 blues
            // also capped at 1 bar so punches keep the groove alive without long halting gaps.
            let extraRest = (label == .B || (bluesVariation && isShortPunch)) ? 0 : rng.nextInt(upperBound: 2)
            bar += 1 + extraRest
        }
        // A lay-out can step over a whole stop-time breakdown; the soloist still plays it.
        if breakdownStyle == .stopTime {
            for sec in structure.sections where sec.label == .bridge
                && stopTimeSections.insert(sec.startBar).inserted {
                var st = SeededRNG(seed: rng.next() ^ 0x5354_4F50_5449_4D45)   // "STOPTIME"
                let before = events.filter { $0.stepIndex < sec.startBar * 16 }
                let motif = melodyPitches(seedPhrases.first ?? Array(before.suffix(6)))
                events += stopTimeSolo(section: sec, frame: frame, structure: structure,
                                       motif: motif, regLow: regLow, regHigh: regHigh, rng: &st)
            }
        }
        reportReplayBars?(replayBars)
        reportReturns?(formReturns)
        // The jazz lick rules' per-song version, named in the log beside the rule.
        return (events, phraseOnsets, handoffBarSet, jazzState?.variantNote)
    }

    // MARK: - Lead 2

    static func generateLead2(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        lead1Instrument: ChillLeadInstrument,
        lead1Onsets: [(startBar: Int, endBar: Int)],
        lead1Events: [MIDIEvent] = [],
        handoffBars: Set<Int> = [],
        bluesVariation: Bool = false,
        sohoVariation: Bool = false,
        keepInstrument: ChillLeadInstrument? = nil,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> (events: [MIDIEvent], instrument: ChillLeadInstrument) {
        // Blues never takes shadow hold, too ambient for blues energy. Soho: 75/25 call-and-response.
        // The second voice sounds under the main line a median 17% of the time across the Soho
        // corpus; a pad-like voice under the melody is the exception. Base Chill: shadow hold 35%
        // (50% until the answer rules arrived on 2026-11-11).
        let useShadowHold = bluesVariation ? false : rng.nextDouble() < (sohoVariation ? 0.25 : 0.35)
        if useShadowHold || sohoVariation {
            usedRuleIDs.insert(useShadowHold ? "CHL-LD2-002" : "CHL-LD2-001")
        }

        var events: [MIDIEvent] = []
        let scale      = scaleNotes(frame: frame)
        let pentatonic = pentatonicNotes(frame: frame)

        // Lead 2 instrument: uniform random from the four L2-appropriate instruments.
        // Register separation (below) ensures L2 stays out of L1's range regardless of choice.
        // Soho: what answers the singer in the corpus — a saxophone nearly every time, then synth
        // brass, trombone and vibraphone — never the same instrument as Lead 1.
        // Blues has no flute: AppState already excluded it from Blues Lead 2, but this pool did
        // not, so 299 Blues songs in 8,000 were written for flute register and then had the patch
        // overridden to something else — a flute part nobody ever heard on a flute (Zack,
        // 2026-10-13). Mirrored by the `isChillBlues` branch of `instrumentPoolNames`.
        let l2Pool: [ChillLeadInstrument] = sohoVariation
            ? [.saxophone, .tenorSax, .synthBrass, .trombone, .vibraphone].filter { $0 != lead1Instrument }
            : bluesVariation ? [.vibraphone, .sopranoSax, .trombone]
                             : [.vibraphone, .flute, .sopranoSax, .trombone]
        let picked = l2Pool[rng.nextInt(upperBound: l2Pool.count)]
        // Regeneration keeps the song's instrument: playback still has that patch loaded, so a
        // line written for a freshly drawn instrument's register would play on the wrong one.
        let inst2 = keepInstrument ?? picked
        let (regLow1, regHigh1) = register(for: lead1Instrument)
        let (rawLow2, rawHigh2) = register(for: inst2)
        // Lead 2 sits below the midpoint of Lead 1's register (CHL-RULE-12).
        // Using the midpoint (not regLow1) prevents degenerate one-note pools when Lead 1
        // has a low bottom register (e.g. regLow near 52 → midpoint cap → only a few scale notes).
        let regMid1  = (regLow1 + regHigh1) / 2
        let regHigh2 = min(rawHigh2, regMid1 - 2)
        let regLow2  = max(36, min(rawLow2, regHigh2 - 12))

        // CHL-LD2-002: Shadow hold — long-held chord tones sounding under Lead 1 simultaneously
        // Base Chill and Blues: Lead 2 never sounds in a breakdown. A shadow hold's lead-in two
        // steps before Groove B could land in a stop-time breakdown's last bar, on top of Lead 1
        // joining the band's climb there.
        func outsideBreakdowns(_ evs: [MIDIEvent]) -> [MIDIEvent] {
            evs.filter { structure.section(atBar: $0.stepIndex / 16)?.label != .bridge }
        }
        if useShadowHold {
            let events = shadowHold(frame: frame, structure: structure,
                                    lead1Onsets: lead1Onsets, scale: scale,
                                    regLow: regLow2, regHigh: regHigh2, rng: &rng)
            return (sohoVariation ? capNotesPerBar(events, 2) : outsideBreakdowns(events), inst2)
        }

        // CHL-LD2-003 to 006 (base Chill and Blues): answers that riff on Lead 1's phrases. Shares
        // of the answer songs: Tail riff 30, Rhythm trade 25, Bebop enclosure 20, Question and
        // answer 25. See jazzAnswers.
        if !sohoVariation {
            let ruleID = ["CHL-LD2-003", "CHL-LD2-004", "CHL-LD2-005", "CHL-LD2-006"][
                rng.weightedPick([0.30, 0.25, 0.20, 0.25])]
            usedRuleIDs.insert(ruleID)
            // The answers' register stays inside the instrument's own. regLow2 and regHigh2 above
            // can fall below it (a flute under a muted trumpet got 55 to 67, under the flute's 65
            // floor), and the final register fold then split figures across octaves. An answer
            // plays in Lead 1's gaps, so where the instrument cannot sit below the middle of Lead
            // 1's register it takes its own bottom octave and a half instead.
            let ansHigh = Swift.min(rawHigh2, Swift.max(regMid1 - 2, rawLow2 + 12))
            let ansLow  = Swift.max(rawLow2, ansHigh - 14)
            let answers = jazzAnswers(ruleID: ruleID, frame: frame, structure: structure,
                                      lead1Events: lead1Events, handoffBars: handoffBars,
                                      bluesVariation: bluesVariation, regLow: ansLow, regHigh: ansHigh,
                                      velocityOffset: inst2 == .vibraphone ? 0 : -15, rng: &rng)
            return (outsideBreakdowns(answers), inst2)
        }

        // Soho: Lead 2 sits out the opening of a groove section about a third of the time — a sax
        // that replies to everything stops sounding like a reply.
        //
        // It used to sit out the *whole* section, which in a two-section song meant vanishing for
        // more than half of it: a 56-bar B section sat out entirely left Lead 2 silent from bar 45
        // to the end while the log still listed a rule and a note count for it, and 29% of Soho
        // songs were silent for over 40% of their length (Zack, 2026-10-12). Sitting out the
        // first 8–16 bars gives the same effect — the section opens without the reply and the sax
        // arrives later — without the track disappearing.
        var sittingOut = Set<Int>()
        if sohoVariation {
            for sec in structure.sections where sec.label == .A || sec.label == .B {
                guard rng.nextDouble() < 0.35 else { continue }
                let len = Swift.min(sec.lengthBars, 8 + rng.nextInt(upperBound: 9))   // 8–16 bars
                sittingOut.formUnion(sec.startBar..<(sec.startBar + len))
            }
        }

        // CHL-LD2-001: Call-and-response, Chill Soho only since 2026-11-11 — a fresh phrase in the
        // gaps between Lead 1 phrases
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
            guard !lead1BarSet.contains(bar), !sittingOut.contains(bar) else { bar += 1; continue }
            // Handoff window: LD2 strongly encouraged to fill bars LD1 was forced to skip.
            // Normal: 40% in A (sparse), 80% in B (dense). Soho: 35% / 55%.
            let responseProb: Double = handoffBars.contains(bar) ? 0.90
                : sohoVariation ? (label == .A ? 0.35 : 0.55)
                : (label == .A ? 0.40 : 0.80)
            guard rng.nextDouble() < responseProb else { bar += 1; continue }

            let sectionEnd = section.map { $0.startBar + $0.lengthBars } ?? frame.totalBars
            // 2-bar phrases for Lead 2; blues: clamp to chord seam so phrases don't span chord changes
            var phraseLen = Swift.min(2, sectionEnd - bar)
            // Soho: Lead 1 rests about a bar and a half between phrases, so a one-bar answer is
            // what fits the gap.
            if sohoVariation && phraseLen == 2 && lead1BarSet.contains(bar + 1) { phraseLen = 1 }
            if bluesVariation {
                let ld2FormPos = bluesFormPosition(bar: bar, label: label, bStart: ld2_bSectionStart, aStart: ld2_aSectionStart)
                if ld2FormPos >= 0 {
                    phraseLen = Swift.min(phraseLen, bluesNextSeam(after: ld2FormPos) - ld2FormPos)
                }
            }
            guard phraseLen > 0 else { bar += 1; continue }

            // Check gap is free of Lead 1
            let gapFree = (bar..<bar + phraseLen).allSatisfy { !lead1BarSet.contains($0) }
            guard gapFree else { bar += 1; continue }

            let ld2PhraseStartChord = bluesVariation ? structure.chordWindow(atBar: bar) : nil
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
        return (sohoVariation ? capNotesPerBar(events, 2) : events, inst2)
    }

    /// The next chord-change seam of the 16-bar Blues form after `pos`: IVm7 at 8, V7 at 12, the
    /// turnaround at 15, else the end of the form.
    private static func bluesNextSeam(after pos: Int) -> Int {
        [8, 12, 15].first { $0 > pos } ?? 16
    }

    /// Keeps the first `cap` notes of each bar. Chill Soho's Lead 2 measures 1.3–2.0 notes/bar,
    /// always below the main line.
    private static func capNotesPerBar(_ events: [MIDIEvent], _ cap: Int) -> [MIDIEvent] {
        var kept: [Int: Int] = [:]
        return events.sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }.filter { ev in
            let bar = ev.stepIndex / 16
            guard kept[bar, default: 0] < cap else { return false }
            kept[bar, default: 0] += 1
            return true
        }
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

            let chord        = structure.chordWindow(atBar: bar)
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

            // Every Chill form, Soho and base alike (Zack, 2026-10-13). A lone held note sounded
            // wrong on Lead 1's Sustained Tone and sounds wrong here for the same reason, so most
            // holds get a companion. Shape and intervals are the ones tools/soho_sustained.py
            // measured off the corpus: short notes of one to two steps, sitting on the unison or
            // within a tone or two of the held pitch, leading in about twice as often as answering.
            //
            // Soho caps Lead 2 at two notes a bar, so a lead-in shares the hold's bar and an
            // answer falls in the bar after the hold ends — never three in one bar.
            let holdStart = bar * 16
            if rng.nextDouble() < 0.70 {
                let step = [0, 2, -2, 3][rng.weightedPick([0.34, 0.32, 0.21, 0.13])]
                let near = pool.min { abs($0 - (Int(note) + step)) < abs($1 - (Int(note) + step)) }
                let companion = UInt8(near ?? Int(note))
                let softer = UInt8(Swift.min(70, Int(vel) + 6))
                if rng.nextDouble() < 0.65 {
                    // The companion leads in, two steps ahead of the hold.
                    events.append(MIDIEvent(stepIndex: Swift.max(0, holdStart - 2), note: companion,
                                            velocity: softer, durationSteps: 2))
                } else if holdStart + dur + 2 < frame.totalBars * 16 {
                    // Or answers once the hold has let go.
                    events.append(MIDIEvent(stepIndex: holdStart + dur + 2, note: companion,
                                            velocity: softer, durationSteps: 2))
                }
            }
            events.append(MIDIEvent(stepIndex: holdStart, note: note,
                                    velocity: vel, durationSteps: Swift.max(1, dur)))
            lastPlaced = bar
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    // MARK: - Shared pitch helpers (stop-time solo, Lead 2 answers)

    /// The scale, sorted and without duplicates, for scale-step arithmetic.
    private static func sortedScale(frame: GlobalMusicalFrame) -> [Int] {
        scaleNotes(frame: frame).sorted().reduce(into: [Int]()) { acc, n in
            if acc.last != n { acc.append(n) }
        }
    }

    /// `note` moved `steps` scale steps (from the nearest scale note), held inside the scale array.
    private static func scaleStep(_ note: Int, _ steps: Int, scale: [Int]) -> Int {
        guard !scale.isEmpty else { return note }
        let idx = scale.indices.min { abs(scale[$0] - note) < abs(scale[$1] - note) } ?? 0
        return scale[Swift.max(0, Swift.min(scale.count - 1, idx + steps))]
    }

    /// The nearest note whose pitch class is in `pcs`; on a tie, the one in direction `prefer`
    /// (-1 lower, +1 higher). `note` itself if `pcs` is empty.
    private static func nearestPC(_ note: Int, _ pcs: Set<Int>, prefer: Int = -1) -> Int {
        guard !pcs.isEmpty else { return note }
        for d in 0...6 {
            let first = note + d * prefer, second = note - d * prefer
            if pcs.contains(((first % 12) + 12) % 12) { return first }
            if pcs.contains(((second % 12) + 12) % 12) { return second }
        }
        return note
    }

    /// A figure moved by whole octaves into the register as one block: the octave that leaves the
    /// fewest notes outside, then the one whose middle is nearest `near`. A note still outside is
    /// folded on its own, so the register is never crossed.
    /// With `scale`, a figure that fits the register's width but no octave of it is moved the
    /// fewest scale steps that bring it inside instead, keeping its shape.
    private static func fitBlock(_ notes: [Int], regLow: Int, regHigh: Int, near: Int,
                                 scale: [Int] = []) -> [Int] {
        guard !notes.isEmpty else { return notes }
        let mid = (notes.min()! + notes.max()!) / 2
        let outside = { (ns: [Int]) in ns.filter { $0 < regLow || $0 > regHigh }.count }
        let best = (-4...4).map { $0 * 12 }.min { a, b in
            let oa = outside(notes.map { $0 + a }), ob = outside(notes.map { $0 + b })
            return oa != ob ? oa < ob : abs(mid + a - near) < abs(mid + b - near)
        } ?? 0
        if !scale.isEmpty, outside(notes.map { $0 + best }) > 0,
           notes.max()! - notes.min()! <= regHigh - regLow - 2 {
            for k in [-1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6] {
                let moved = notes.map { scaleStep($0 + best, k, scale: scale) }
                if outside(moved) == 0 { return moved }
            }
        }
        return notes.map { n in
            var m = n + best
            while m < regLow { m += 12 }
            while m > regHigh { m -= 12 }
            return m
        }
    }

    // MARK: - Stop-time breakdown solo

    /// Lead 1 in a stop-time breakdown (Zack, 2026-11-11). The band hits on the even bars; on the
    /// odd bars Rhythm climbs the chord on beats 2, 3 and 4 (`ChillRhythmGenerator.stopTimeReveal`)
    /// and Pads climb with it. Until 2026-11-11 Lead 1 played random scale notes in up to four or
    /// six odd bars, often falling while the band rose on the same beats.
    ///
    /// The soloist now plays in every stop-time breakdown: all the odd bars of a short one, the
    /// last two of an 8-bar one and the last three of a 12-bar one. The earlier solo bars play the
    /// first notes of the song's opening phrase in the gaps around the band, a scale step higher
    /// each time. The last solo bar opens on the soloist's own note and then joins the band's climb
    /// on its beats: a chord tone above each band note, in unison with it, or from beat 3 only.
    /// Half the time an 8th-note pickup leads into the groove. Each song draws its own fragment
    /// rhythms, join and pickup from `rng`, a stream derived for this breakdown.
    private static func stopTimeSolo(section: SongSection, frame: GlobalMusicalFrame,
                                     structure: SongStructure, motif: [Int],
                                     regLow: Int, regHigh: Int,
                                     rng: inout SeededRNG) -> [MIDIEvent] {
        let len = section.lengthBars
        let oddBars = stride(from: 1, to: len, by: 2).map { section.startBar + $0 }
        guard !oddBars.isEmpty else { return [] }
        let soloBars = Array(oddBars.suffix(len <= 5 ? oddBars.count : (len >= 12 ? 3 : 2)))
        let scale = sortedScale(frame: frame)
        let regMid = (regLow + regHigh) / 2
        var events: [MIDIEvent] = []

        // The opening phrase's first four notes; a song with no opening yet climbs the chord.
        var head = Array(motif.prefix(4))
        if head.count < 3 {
            let tones = structure.chordWindow(atBar: section.startBar)?.chordTones ?? []
            let c0 = nearestPC(regMid - 4, tones)
            let c1 = nearestPC(c0 + 3, tones, prefer: 1)
            let c2 = nearestPC(c1 + 3, tones, prefer: 1)
            head = [c0, c1, c2, c1]
        }
        while head.count < 4 { head.append(head.last!) }
        head = fitBlock(head, regLow: regLow, regHigh: regHigh, near: regMid, scale: scale)

        // Fragment rhythms (step, length): in the gaps around the band's beats 2, 3 and 4; a
        // quick call on beat 1 and a pickup at the end of the bar; or the off-beats only.
        let fragmentRhythms: [[(Int, Int)]] = [
            [(0, 2), (2, 2), (6, 2), (10, 3)],
            [(0, 1), (1, 1), (2, 2), (14, 2)],
            [(2, 2), (6, 2), (10, 2), (14, 2)],
        ]
        var lastNote = head[0]
        for (i, bar) in soloBars.dropLast().enumerated() {
            let tones = structure.chordWindow(atBar: bar)?.chordTones ?? []
            let rhythm = fragmentRhythms[rng.nextInt(upperBound: fragmentRhythms.count)]
            var pitches = fitBlock(head.map { scaleStep($0, i, scale: scale) },
                                   regLow: regLow, regHigh: regHigh, near: regMid, scale: scale)
            pitches[pitches.count - 1] = nearestPC(pitches[pitches.count - 1], tones)
            pitches = fitBlock(pitches, regLow: regLow, regHigh: regHigh, near: regMid, scale: scale)
            for (k, (step, dur)) in rhythm.enumerated() {
                events.append(MIDIEvent(stepIndex: bar * 16 + step, note: UInt8(pitches[k]),
                                        velocity: UInt8(66 + 3 * k + rng.nextInt(upperBound: 6)),
                                        durationSteps: dur))
            }
            lastNote = pitches[pitches.count - 1]
        }

        // The join, in the last solo bar.
        guard let joinBar = soloBars.last else { return events }
        let chord = structure.chordWindow(atBar: joinBar)
        let tones = chord?.chordTones ?? []
        let band = ChillRhythmGenerator.stopTimeReveal(frame: frame, chord: chord)
        guard band.count >= 3 else { return events }
        let style = rng.weightedPick([0.45, 0.25, 0.30])   // above, unison, from beat 3
        // The climb must fit the register whole, at some octave, or it stops sounding like the
        // band's climb. The drawn line first, then the other; failing both, the chord climbed
        // from the bottom of the register.
        let above = [band[1], band[2], band[0] + 12], unison = [band[0], band[1], band[2]]
        let fits = { (l: [Int]) in l.max()! - l.min()! <= regHigh - regLow
            && (-4...4).contains { o in l.allSatisfy { $0 + o * 12 >= regLow && $0 + o * 12 <= regHigh } } }
        var line: [Int]
        if let l = (style == 1 ? [unison, above] : [above, unison]).first(where: fits) {
            line = fitBlock(l, regLow: regLow, regHigh: regHigh, near: lastNote, scale: scale)
        } else {
            let c0 = nearestPC(regLow + 1, tones, prefer: 1)
            let c1 = nearestPC(c0 + 3, tones, prefer: 1)
            line = [c0, c1, nearestPC(c1 + 3, tones, prefer: 1)]
        }
        let own = soloBars.count > 1 ? nearestPC(lastNote, tones) : nearestPC(head[0], tones)
        let pickup = rng.nextDouble() < 0.50
        let base = joinBar * 16
        var notes: [(step: Int, note: Int, dur: Int)]
        if style == 2 {
            let neighbour = scaleStep(own, line[1] > own ? 1 : -1, scale: scale)
            notes = [(0, own, 2), (2, neighbour, 2), (8, line[1], 3), (12, line[2], pickup ? 2 : 4)]
        } else {
            notes = [(0, own, 3), (4, line[0], 3), (8, line[1], 3), (12, line[2], pickup ? 2 : 4)]
        }
        if pickup {
            notes.append((14, scaleStep(line[2], rng.nextDouble() < 0.5 ? -1 : 1, scale: scale), 2))
        }
        for (k, n) in notes.enumerated() {
            let pitch = Swift.max(regLow, Swift.min(regHigh, n.note))
            events.append(MIDIEvent(stepIndex: base + n.step, note: UInt8(pitch),
                                    velocity: UInt8(Swift.min(90, 68 + 4 * k + rng.nextInt(upperBound: 5))),
                                    durationSteps: n.dur))
        }
        return events
    }

    /// Lead 1's pitches in time order, one per onset (the highest), for the stop-time fragment.
    private static func melodyPitches(_ events: [MIDIEvent]) -> [Int] {
        var seen = Set<Int>()
        return events.sorted { ($0.stepIndex, -Int($0.note)) < ($1.stepIndex, -Int($1.note)) }
            .filter { seen.insert($0.stepIndex).inserted }
            .map { Int($0.note) }
    }

    // MARK: - CHL-LD2-003 to 006: answers that riff on Lead 1

    /// Base Chill and Chill Blues Lead 2 since 2026-11-11 (Chill Soho keeps CHL-LD2-001). Until then
    /// every reply was a fresh scale random walk that took nothing from the phrase it answered.
    /// Now Lead 2 answers each Lead 1 phrase it replies to like a second soloist trading with the
    /// first, shorter than Lead 1: one answer, about a bar, starting an 8th or so after Lead 1's
    /// last note has ended and finishing before Lead 1's next note. In a handoff window, where
    /// Lead 1 lays out, Lead 2 keeps riffing on its own answer, up to three in a row.
    ///
    /// The song's rule is Lead 2's habit, used for about 70% of its answers; the rest are drawn
    /// from the other three so a song still varies:
    /// - CHL-LD2-003 Tail riff: Lead 1's last two to four notes in Lead 1's rhythm, a scale step
    ///   lower or higher, a third lower or an octave down, then a resolving chord tone. A two-note
    ///   tail is often sequenced twice.
    /// - CHL-LD2-004 Rhythm trade: the rhythm of Lead 1's last notes with a new line moving the
    ///   other way, ending on a chord tone.
    /// - CHL-LD2-005 Bebop enclosure: Lead 1's last note (or a chord tone next to it) approached
    ///   from a scale step above and a semitone below, then held, sometimes with a falling tag.
    /// - CHL-LD2-006 Question and answer: after a phrase that ends off the root or fifth, a falling
    ///   line home to a chord tone; after one that ends on it, a rising arpeggio left open on a
    ///   tension.
    ///
    /// Answers sit in Lead 2's register (below the middle of Lead 1's, CHL-RULE-12) as one block,
    /// held notes on chord tones of their bar and passing notes in the scale. Only groove sections
    /// (A and B); in Blues, never in the turnaround (form positions 13 to 15).
    private static func jazzAnswers(ruleID: String, frame: GlobalMusicalFrame, structure: SongStructure,
                                    lead1Events: [MIDIEvent], handoffBars: Set<Int>,
                                    bluesVariation: Bool, regLow: Int, regHigh: Int,
                                    velocityOffset: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        struct ANote { var rel: Int; var note: Int; var dur: Int; var chromatic = false }
        let scale = sortedScale(frame: frame)
        let keyPC = frame.keySemitoneValue % 12
        let regMid = (regLow + regHigh) / 2
        let totalSteps = frame.totalBars * 16
        let (bStart, aStart) = bluesVariation ? bluesSectionAnchors(structure: structure) : (-1, -1)
        let devices = ["CHL-LD2-003", "CHL-LD2-004", "CHL-LD2-005", "CHL-LD2-006"]

        // Lead 1 as heard: one note per onset (the highest), grouped into phrases wherever Lead 1
        // has been silent for 10 steps or more.
        var seen = Set<Int>()
        let melody = lead1Events.sorted { ($0.stepIndex, -Int($0.note)) < ($1.stepIndex, -Int($1.note)) }
            .filter { seen.insert($0.stepIndex).inserted }
        var phrases: [[MIDIEvent]] = []
        var soundingEnd = -100
        for n in melody {
            if n.stepIndex - soundingEnd >= 10 || phrases.isEmpty { phrases.append([n]) }
            else { phrases[phrases.count - 1].append(n) }
            soundingEnd = Swift.max(soundingEnd, n.stepIndex + n.durationSteps)
        }

        /// Lead 1's last notes, with gaps capped at 6 steps and each note held to the next.
        func tail(_ ph: [MIDIEvent], _ k: Int) -> [ANote] {
            let src = Array(ph.suffix(k))
            var out: [ANote] = []
            var rel = 0
            for (i, e) in src.enumerated() {
                if i > 0 { rel += Swift.max(1, Swift.min(6, e.stepIndex - src[i - 1].stepIndex)) }
                out.append(ANote(rel: rel, note: Int(e.note), dur: Swift.max(1, e.durationSteps)))
            }
            for i in out.indices.dropLast() { out[i].dur = Swift.min(out[i].dur, out[i + 1].rel - out[i].rel) }
            out[out.count - 1].dur = Swift.max(4, Swift.min(8, out[out.count - 1].dur))
            return out
        }
        let rhythmCells: [[(Int, Int)]] = [
            [(0, 2), (2, 2), (4, 2), (6, 8)],
            [(0, 3), (3, 1), (4, 4), (8, 8)],
            [(2, 2), (4, 1), (5, 3), (8, 8)],
        ]
        /// Pitches set to one of three jazz rhythm cells (straight 8ths, dotted, or pushed with a
        /// 16th), the held note last; a three-note line takes the cell's last three.
        func fromCell(_ pitches: [Int]) -> [ANote] {
            var cell = rhythmCells[rng.nextInt(upperBound: rhythmCells.count)]
            if pitches.count < cell.count { cell = Array(cell.suffix(pitches.count)) }
            let shift = cell.first?.0 ?? 0
            return zip(cell, pitches).map { ANote(rel: $0.0 - shift, note: $1, dur: $0.1) }
        }

        func answer(_ device: String, phrase ph: [MIDIEvent], tones: Set<Int>) -> [ANote] {
            let last = Int(ph.last!.note)
            switch device {
            case "CHL-LD2-003":   // Tail riff
                var t = tail(ph, Swift.min(ph.count, 2 + rng.nextInt(upperBound: 3)))
                let moved = fitBlock(t.map { $0.note }, regLow: regLow, regHigh: regHigh, near: regMid, scale: scale)
                // A chained riff always moves (a sequence); a first answer may echo at pitch.
                let shift = chaining ? [-1, 1, -2][rng.weightedPick([0.50, 0.30, 0.20])]
                    : [-1, 1, -2, 0][rng.weightedPick([0.40, 0.25, 0.15, 0.20])]
                for i in t.indices { t[i].note = scaleStep(moved[i], shift, scale: scale) }
                if t.count == 2 && rng.nextDouble() < 0.60 {
                    let again = shift == 0 ? -1 : shift
                    let gap = Swift.min(t[1].dur, 3)
                    t[1].dur = gap
                    let start = t[1].rel + gap + 1
                    t += t.map { ANote(rel: $0.rel + start, note: scaleStep($0.note, again, scale: scale),
                                       dur: Swift.min($0.dur, 3)) }
                }
                let dir = shift > 0 ? 1 : -1
                let lastT = t[t.count - 1]
                t[t.count - 1].dur = Swift.min(lastT.dur, 2)   // a passing note into the resolution
                let res = nearestPC(scaleStep(lastT.note, dir, scale: scale), tones, prefer: dir)
                t.append(ANote(rel: lastT.rel + t[t.count - 1].dur + (rng.nextDouble() < 0.5 ? 0 : 1),
                               note: res, dur: 6 + rng.nextInt(upperBound: 3)))
                return t
            case "CHL-LD2-004":   // Rhythm trade
                var t = tail(ph, Swift.min(ph.count, 3 + rng.nextInt(upperBound: 3)))
                let rising = Int(ph.last!.note) - Int(ph.suffix(t.count).first!.note) > 0
                let dir = rising ? -1 : 1
                var p = nearestPC(rising ? regHigh - 3 : regLow + 4, tones)
                for i in t.indices {
                    if i > 0 { p = scaleStep(p, dir * (rng.nextDouble() < 0.25 ? 2 : 1), scale: scale) }
                    t[i].note = p
                }
                t[t.count - 1].note = nearestPC(t[t.count - 1].note, tones, prefer: dir)
                return t
            case "CHL-LD2-005":   // Bebop enclosure
                let folded = fitBlock([last], regLow: regLow + 2, regHigh: regHigh - 2, near: regMid, scale: scale)[0]
                var target = nearestPC(folded, tones)
                if rng.nextDouble() < 0.30 {
                    target = nearestPC(target + 2, tones.subtracting([((target % 12) + 12) % 12]), prefer: 1)
                }
                let up = scaleStep(target, 1, scale: scale), up2 = scaleStep(target, 2, scale: scale)
                var t: [ANote]
                switch rng.nextInt(upperBound: 4) {
                case 0:  t = [ANote(rel: 0, note: up, dur: 2), ANote(rel: 2, note: target - 1, dur: 2, chromatic: true),
                              ANote(rel: 4, note: target, dur: 8)]
                case 1:  t = [ANote(rel: 0, note: target - 1, dur: 2, chromatic: true), ANote(rel: 2, note: up, dur: 2),
                              ANote(rel: 4, note: target, dur: 8)]
                case 2:  t = [ANote(rel: 0, note: up2, dur: 2), ANote(rel: 2, note: up, dur: 2),
                              ANote(rel: 4, note: target - 1, dur: 2, chromatic: true), ANote(rel: 6, note: target, dur: 8)]
                default: t = [ANote(rel: 0, note: up, dur: 1), ANote(rel: 1, note: target - 1, dur: 1, chromatic: true),
                              ANote(rel: 2, note: target, dur: 8)]
                }
                if rng.nextDouble() < 0.40 {
                    let held = t[t.count - 1]
                    t[t.count - 1].dur = 6
                    t.append(ANote(rel: held.rel + 8, note: nearestPC(held.note - 2, tones), dur: 4))
                }
                return t
            default:              // CHL-LD2-006 Question and answer
                let lastPC = ((last % 12) + 12) % 12
                let settled = lastPC == keyPC || lastPC == (keyPC + 7) % 12
                if settled {
                    let c0 = nearestPC(regLow + 3, tones, prefer: 1)
                    let c1 = nearestPC(c0 + 3, tones, prefer: 1)
                    let c2 = nearestPC(c1 + 3, tones, prefer: 1)
                    return fromCell([c0, c1, c2, scaleStep(c2, 1, scale: scale)])
                }
                let home = tones.contains(keyPC) ? Set([keyPC]) : tones
                let target = nearestPC(regMid - 2, home)
                let count = 3 + rng.nextInt(upperBound: 2)
                return fromCell((0..<count).reversed().map { scaleStep(target, $0, scale: scale) })
            }
        }

        /// Places an answer at `start`, cut at `limit`: held notes on chord tones of their bar,
        /// passing notes in the scale, the whole figure in the register.
        func place(_ shape: [ANote], start: Int, limit: Int, velocity: Int) -> [MIDIEvent] {
            // HarmonicFilter drops an out-of-scale note on a beat, which would leave an enclosure
            // without its chromatic note: push the answer an 8th later, or failing that play the
            // scale step instead.
            var shape = shape, start = start
            if shape.contains(where: { $0.chromatic && (start + $0.rel) % 4 == 0 }) {
                if start + 2 + (shape.last?.rel ?? 0) + 2 < limit { start += 2 }
                else { for i in shape.indices where shape[i].chromatic { shape[i].chromatic = false } }
            }
            var notes = shape.filter { start + $0.rel < limit - 1 }
            guard notes.count >= 2 else { return [] }
            for i in notes.indices {
                notes[i].dur = Swift.max(1, Swift.min(notes[i].dur, limit - (start + notes[i].rel)))
            }
            let fitted = fitBlock(notes.map { $0.note }, regLow: regLow, regHigh: regHigh, near: regMid, scale: scale)
            var out: [MIDIEvent] = []
            for (i, n) in notes.enumerated() {
                let step = start + n.rel
                let tones = structure.chordWindow(atBar: step / 16)?.chordTones ?? []
                var pitch = fitted[i]
                let isLast = i == notes.count - 1
                if !n.chromatic {
                    pitch = (n.dur >= 3 || isLast) ? nearestPC(pitch, tones) : scaleStep(pitch, 0, scale: scale)
                }
                // A held note never restates the note just before it: the line moves to the next
                // chord tone down (up at the bottom of the register).
                if (n.dur >= 3 || isLast), let prev = out.last, Int(prev.note) == pitch {
                    let down = nearestPC(pitch - 2, tones.subtracting([pitch % 12]))
                    pitch = down >= regLow ? down : nearestPC(pitch + 2, tones.subtracting([pitch % 12]), prefer: 1)
                }
                while pitch < regLow { pitch += 12 }
                while pitch > regHigh { pitch -= 12 }
                let v = velocity + (i == 0 ? 4 : 0) - (isLast ? 4 : 0) + rng.nextInt(upperBound: 6)
                out.append(MIDIEvent(stepIndex: step, note: UInt8(pitch),
                                     velocity: UInt8(Swift.max(30, Swift.min(110, v))), durationSteps: n.dur))
            }
            return out
        }

        var events: [MIDIEvent] = []
        var chaining = false
        for (pi, ph) in phrases.enumerated() {
            chaining = false
            let end = ph.map { $0.stepIndex + $0.durationSteps }.max()!
            let next = pi + 1 < phrases.count ? phrases[pi + 1][0].stepIndex : totalSteps
            var start = end + 2
            start += start % 2                                   // onto the 8th grid
            guard start < totalSteps, let sec = structure.section(atBar: start / 16),
                  sec.label == .A || sec.label == .B else { continue }
            var limit = Swift.min(next - 2, sec.endBar * 16)
            if bluesVariation {
                for b in (start / 16)...Swift.max(start / 16, (limit - 1) / 16)
                where bluesFormPosition(bar: b, label: sec.label, bStart: bStart, aStart: aStart) >= 13 {
                    limit = Swift.min(limit, b * 16); break
                }
            }
            guard limit - start >= 8 else { continue }
            let handoff = (start / 16...(limit - 1) / 16).contains { handoffBars.contains($0) }
            let prob = handoff ? 1.0 : (sec.label == .A ? 0.50 : 0.80)
            guard rng.nextDouble() < prob else { continue }

            let tones = structure.chordWindow(atBar: start / 16)?.chordTones ?? []
            let device = rng.nextDouble() < 0.70 ? ruleID
                : devices.filter { $0 != ruleID }[rng.nextInt(upperBound: devices.count - 1)]
            let velocity = Swift.max(55, Swift.min(90, Int(ph.last!.velocity))) - 6 + velocityOffset
            var placed = place(answer(device, phrase: ph, tones: tones), start: start, limit: limit,
                               velocity: velocity)
            events += placed

            // Riffing on: in a handoff window, or now and then over a long gap in Groove B, Lead 2
            // takes its own answer as the next call, up to three answers in all.
            let chain = handoff || (sec.label == .B && limit - start >= 40 && rng.nextDouble() < 0.30)
            var answers = 1
            while chain, answers < 3, placed.count >= 2 {
                let lastEnd = placed.map { $0.stepIndex + $0.durationSteps }.max()!
                var s = lastEnd + 4 + 2 * rng.nextInt(upperBound: 3)
                s += s % 2
                guard limit - s >= 8 else { break }
                let chordAt = structure.chordWindow(atBar: s / 16)?.chordTones ?? []
                let own = placed.map { MIDIEvent(stepIndex: $0.stepIndex, note: $0.note,
                                                 velocity: $0.velocity, durationSteps: $0.durationSteps) }
                let d = rng.nextDouble() < 0.60 ? "CHL-LD2-003" : devices[rng.nextInt(upperBound: devices.count)]
                chaining = true
                placed = place(answer(d, phrase: own, tones: chordAt), start: s, limit: limit,
                               velocity: velocity - 3 * answers)
                events += placed
                answers += 1
            }
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
            case .recorder:     notesPerBar = 2 + rng.nextInt(upperBound: 2)   // 2–3
            case .mutedTrumpet: notesPerBar = 3 + rng.nextInt(upperBound: 2)   // 3–4
            case .trumpet:      notesPerBar = 3 + rng.nextInt(upperBound: 2)   // 3–4
            case .vibraphone:   notesPerBar = 3 + rng.nextInt(upperBound: 3)   // 3–5
            case .saxophone:    notesPerBar = 3 + rng.nextInt(upperBound: 3)   // 3–5
            case .tenorSax:     notesPerBar = 3 + rng.nextInt(upperBound: 3)   // 3–5 (rich, bluesy lines)
            case .sopranoSax:   notesPerBar = 2 + rng.nextInt(upperBound: 3)   // 2–4
            case .trombone:     notesPerBar = 2 + rng.nextInt(upperBound: 2)   // 2–3 (smooth legato, fewer notes)
            case .synthBrass:   notesPerBar = 2 + rng.nextInt(upperBound: 2)   // 2–3 (a section answering)
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
        case .recorder:     noteDurSteps = 8 + rng.nextInt(upperBound: 5)   // 8–12 steps (legato)
        case .mutedTrumpet: noteDurSteps = 2 + rng.nextInt(upperBound: 3)   // 2–4 steps (staccato)
        case .trumpet:      noteDurSteps = 3 + rng.nextInt(upperBound: 3)   // 3–5 steps
        case .vibraphone:   noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
        case .saxophone:    noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
        case .tenorSax:     noteDurSteps = 5 + rng.nextInt(upperBound: 5)   // 5–9 steps (slightly longer, warmer tone)
        case .sopranoSax:   noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
        case .trombone:     noteDurSteps = 6 + rng.nextInt(upperBound: 7)   // 6–12 steps (long legato slides)
        case .synthBrass:   noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps
        case .clarinet:     noteDurSteps = 4 + rng.nextInt(upperBound: 5)   // 4–8 steps (chalumeau breath)
        }

        // Build an ordered pool from the full scale so adjacent indices are ≤2 semitones apart —
        // guaranteeing ≥55% measured step ratio. Pentatonic character is preserved through
        // landing-note selection. The blue note (b5), when active, is injected into the pool
        // so the navigator can land on it naturally.
        var scaleForPool = scale
        if let bluePC = blueNotePC {
            // Insert all octave instances of the blue note within the register
            var bn = regLow + ((bluePC - (regLow % 12) + 12) % 12)   // first note at or above regLow with the blue pitch class
            while bn < regLow { bn += 12 }
            while bn <= regHigh { scaleForPool.append(bn); bn += 12 }
        }
        let orderedPool = scaleForPool.filter { $0 >= regLow && $0 <= regHigh }
            .sorted().reduce(into: [Int]()) { acc, n in if acc.last != n { acc.append(n) } }
        guard !orderedPool.isEmpty else { return events }

        // Blues: strip avoid tones of the active chord from the body pool so body notes
        // don't clash over IV and V bars (e.g. B♮ over Gm7 = tritone against F).
        // orderedPool (full) is kept for phrase-ending chord-tone snapping below.
        // The blue note (b5 of the key) is out of Dorian, so it counts as an avoid tone; it is kept
        // over the I chord, where it is the b5 of the tonic's blues scale. Over IV and V it would
        // sit a semitone above the chord root, so the strip stays.
        var bodyPool = orderedPool
        if let chord = phraseStartChord, !chord.avoidTones.isEmpty {
            let keepBlue = blueNotePC != nil && chord.chordRoot == "1"
            let filtered = orderedPool.filter { !chord.avoidTones.contains($0 % 12) || (keepBlue && $0 % 12 == blueNotePC) }
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

    static func register(for instrument: ChillLeadInstrument) -> (low: Int, high: Int) {
        switch instrument {
        case .flute:        return (65, 85)
        case .recorder:     return (65, 81)   // narrower than the flute; thin above this
        case .mutedTrumpet: return (58, 80)
        case .trumpet:      return (58, 79)
        case .vibraphone:   return (60, 80)
        case .saxophone:    return (58, 72)   // alto sax lead: Bb3–C5 (D3 floor was too muddy)
        case .tenorSax:     return (57, 72)   // tenor sax lead: A3–C5
        case .sopranoSax:   return (58, 80)   // soprano sits higher than alto/tenor
        case .trombone:     return (45, 65)   // warm low brass — Lead 2 counter-melody register
        case .synthBrass:   return (55, 77)   // Synth Brass 1 — Chill Soho Lead 2
        case .clarinet:     return (58, 72)   // clarinet lead: Bb3–C5 (D3 floor was too muddy)
        }
    }

    /// Every scale note across five octaves, 36–96.
    ///
    /// **The order of this array is load-bearing. Do not sort it here.** It comes back grouped
    /// by interval and then by octave, so consecutive indices are an octave apart rather than a
    /// scale step apart. Two call sites depend on that in opposite ways:
    ///
    /// - Lead 2 Shadow Hold draws a note with `pool[rng.nextInt(upperBound: pool.count)]` from
    ///   an unsorted filter of this array. Sorting here changes which note that draw lands on,
    ///   in every Chill form, for every Shadow Hold song.
    /// - The harmony pass at `scaleNotes(frame:).sorted()` does `scale[idx - intervalSteps]`,
    ///   stepping down the scale by index. That is only correct because it sorts first.
    ///
    /// A caller that needs scale-step arithmetic must sort; a caller that is only picking from
    /// a pool must not, or existing songs change. `DeterminismTests` will catch a change here,
    /// but the diff reads as "every Chill song is different", which is a long way from the cause.
    static func scaleNotes(frame: GlobalMusicalFrame) -> [Int] {
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

    /// Blues: puts the blue note (b5 of the key) between the 4th and the 5th, where a horn player
    /// would slide through it: C to D in G becomes C, Db, D (or D, Db, C going down). The blue note
    /// is a soft one- or two-step passing tone just before the target, off the beat, taken from the
    /// end of the first note, and only over the I chord, where it is the b5 of the tonic's blues scale. Where
    /// a pair has no room (first note too short to give up the time, wrong chord) the
    /// phrase is left alone: if it doesn't fit, it isn't played.
    private static func addBluePassingTones(_ phrase: [MIDIEvent], frame: GlobalMusicalFrame,
                                            structure: SongStructure, onlyLick: (low: UInt8, high: UInt8)?)
        -> (events: [MIDIEvent], lick: (low: UInt8, high: UInt8)?) {
        let key = frame.keySemitoneValue
        func degree(_ n: UInt8) -> Int { ((Int(n) - key) % 12 + 12) % 12 }
        var notes = phrase.sorted { $0.stepIndex < $1.stepIndex }
        var added: [MIDIEvent] = []
        var lick: (low: UInt8, high: UInt8)? = nil
        for i in 0..<Swift.max(0, notes.count - 1) {
            let a = notes[i], b = notes[i + 1]
            if let want = onlyLick, (Swift.min(a.note, b.note), Swift.max(a.note, b.note)) != (want.low, want.high) { continue }
            // Two steps before a target on the beat, one step before an off-beat target: either way
            // the blue note lands off the beat, a passing tone and never a stressed one.
            let roomy = b.stepIndex % 4 == 0 && a.stepIndex + 4 <= b.stepIndex
            let blueLen = roomy ? 2 : 1
            let blueStep = b.stepIndex - blueLen
            guard abs(Int(a.note) - Int(b.note)) == 2,
                  [5, 7].contains(degree(a.note)), [5, 7].contains(degree(b.note)),
                  blueStep % 4 != 0,
                  a.stepIndex + 1 <= blueStep,
                  a.stepIndex + a.durationSteps <= b.stepIndex,
                  structure.chordWindow(atBar: blueStep / 16)?.chordRoot == "1",
                  structure.chordWindow(atBar: b.stepIndex / 16)?.chordRoot == "1" else { continue }
            notes[i] = MIDIEvent(stepIndex: a.stepIndex, note: a.note, velocity: a.velocity,
                                 durationSteps: Swift.min(a.durationSteps, blueStep - a.stepIndex))
            added.append(MIDIEvent(stepIndex: blueStep, note: UInt8(Swift.min(a.note, b.note) + 1),
                                   velocity: UInt8(Swift.max(30, Int(a.velocity) - 8)), durationSteps: blueLen))
            if lick == nil { lick = (Swift.min(a.note, b.note), Swift.max(a.note, b.note)) }
        }
        return ((notes + added).sorted { $0.stepIndex < $1.stepIndex }, lick)
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

        var stopTimeSections = Set<Int>()
        var bar = 0
        while bar < frame.totalBars {
            let section = structure.section(atBar: bar)
            let label   = section?.label ?? .A

            // Breakdown: behavior depends on style
            if label == .bridge {
                switch breakdownStyle {
                case .bassOstinato, .sohoRemix, .sohoDuo:   // remix: Lead 1 rests; duo: Rhythm and Bass alone
                    // Silent — bass carries the groove alone
                    bar += 1; continue
                case .stopTime:
                    // The same stop-time solo as the other rules (stopTimeSolo), its fragment
                    // taken from the latest staccato notes. Until 2026-11-11, random 2–4 note bursts.
                    if let sec = section, stopTimeSections.insert(sec.startBar).inserted {
                        var st = SeededRNG(seed: rng.next() ^ 0x5354_4F50_5449_4D45)   // "STOPTIME"
                        events += stopTimeSolo(section: sec, frame: frame, structure: structure,
                                               motif: melodyPitches(Array(events.suffix(6))),
                                               regLow: regLow, regHigh: regHigh, rng: &st)
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
                    let activeChord = structure.chordWindow(atBar: activeCursor)
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
        // A silent gap can still step over a whole stop-time breakdown; the soloist plays it.
        if breakdownStyle == .stopTime {
            for sec in structure.sections where sec.label == .bridge
                && stopTimeSections.insert(sec.startBar).inserted {
                var st = SeededRNG(seed: rng.next() ^ 0x5354_4F50_5449_4D45)   // "STOPTIME"
                let before = events.filter { $0.stepIndex < sec.startBar * 16 }
                events += stopTimeSolo(section: sec, frame: frame, structure: structure,
                                       motif: melodyPitches(Array(before.suffix(6))),
                                       regLow: regLow, regHigh: regHigh, rng: &st)
            }
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

// MARK: - Jazz cell rules: CHL-LD1-013 Moanin', CHL-LD1-014 Cantaloupe Island, CHL-LD1-015 Blue Monk
//
// Each rule plays licks from a small bank taken from a real tune (sources and analysis in
// docs/chill-jazz-leads-plan.md), reworked as homage. The seed picks the order, the rhythmic
// placement and the answer, and the licks change as the song goes on. A lick is written in minor
// blues terms, as semitones from the chord root under the phrase's first bar. It is moved to that
// root and fitted to the song's scale and chords, so one bank serves Dorian Blues and the major
// modes of regular Chill.

/// One note of a lick: step from the phrase start, semitones from the chord root, length in steps.
typealias JazzNote = (step: Int, iv: Int, dur: Int)

/// Per-song choices for a jazz cell rule, drawn once when the rule is picked.
struct JazzCellState {
    let ruleID: String
    /// Phrases played so far; the licks change as this grows.
    var statements = 0
    /// Cantaloupe Island: the full hook has come back in the last fifth of the song.
    var finalHookDone = false
    /// Moanin': the order the three calls climb through, as the head does (A, B, C, A).
    let ladder: [Int]
    /// Rhythmic placement in steps: Moanin' pickup on beat 2 or beat 1, Blue Monk riff on the
    /// downbeat or an 8th late, Cantaloupe solo licks on the beat or a beat late.
    let shift: Int
    /// Moanin': the amen answers b7 to 5 instead of 4 to b3.
    let altAmen: Bool
    /// The key-root MIDI note the phrases sit around.
    let anchor: Int
    /// CHL-LD1-001/007/008: the root the last phrase was placed on, so the next stays in its octave.
    var lastRoot: Int? = nil
    /// CHL-LD1-001/007/008/015 play three themes like a player with a head and two more ideas:
    /// A (the rule's own licks), B (a contrasting tune) and C (a blowing line from a solo). After
    /// the opening A A B, the song cycles this seed-picked form; A also comes back through seed
    /// returns, the recap and a plain final statement.
    let form: [Character]
    var formPos = 0
    /// Which of the two B and the two C licks plays next; they alternate from a seed-picked start.
    var bPick = 0
    var cPick = 0
    /// This song's version of the licks (2026-11-12): up to one transformation from each family,
    /// applied to every lick the rule plays, so the hook is the same all through a song and
    /// different from the next song's. Empty in a fifth of songs, which play the licks as written.
    let variants: [JazzVariant]
    var isThemed: Bool { Self.themedRules.contains(ruleID) }
    static let themedRules: Set<String> = ["CHL-LD1-001", "CHL-LD1-007", "CHL-LD1-008", "CHL-LD1-015"]
    /// The rules that draw a per-song version.
    static let variantRules: Set<String> = ["CHL-LD1-001", "CHL-LD1-007", "CHL-LD1-008",
                                            "CHL-LD1-013", "CHL-LD1-014", "CHL-LD1-015"]

    /// The transformations for the log, beside the rule's name; nil when the licks play as written.
    /// Short, after the rule's name: "Blues bossa filled, pushed" (Zack, 2026-11-12).
    var variantNote: String? {
        variants.isEmpty ? nil : variants.map(\.rawValue).joined(separator: ", ")
    }

    var phraseBars: Int {
        switch ruleID {
        case "CHL-LD1-014":                               return 3
        case "CHL-LD1-001", "CHL-LD1-007", "CHL-LD1-008": return 4
        default:                                          return 2
        }
    }

    init(ruleID: String, regLow: Int, regHigh: Int, keyPC: Int, allowVariants: Bool = true,
         rng: inout SeededRNG) {
        self.ruleID = ruleID
        // The song's version, drawn on a stream derived from a copy of `rng`, so the main stream
        // does not move and every other draw in the song stays as it was.
        if allowVariants && Self.variantRules.contains(ruleID) {
            var copy = rng
            var vr = SeededRNG(seed: copy.next() ^ 0x4A41_5A5A_5641_5249)   // "JAZZVARI"
            variants = JazzVariant.draw(rng: &vr)
        } else {
            variants = []
        }
        let ladders = [[0, 1, 2, 0], [0, 2, 1, 0], [1, 0, 2, 0]]
        ladder = ladders[rng.nextInt(upperBound: ladders.count)]
        switch ruleID {
        case "CHL-LD1-013": shift = rng.nextDouble() < 0.65 ? 0 : -4
        case "CHL-LD1-015": shift = rng.nextDouble() < 0.65 ? 0 : 2
        // Chet sigh and Horace hook: pickups on time or an 8th early (held notes anticipate
        // the bar). Blues bossa: the fall on the beat or an 8th late.
        case "CHL-LD1-001", "CHL-LD1-007": shift = rng.nextDouble() < 0.65 ? 0 : -2
        case "CHL-LD1-008": shift = rng.nextDouble() < 0.65 ? 0 : 2
        default:            shift = rng.nextDouble() < 0.65 ? 0 : 4
        }
        altAmen = rng.nextDouble() < 0.30
        // The key root a few semitones under the middle of the register, so climbing licks fit.
        let target = (regLow + regHigh) / 2 - 3
        let below = target - ((target - keyPC) % 12 + 12) % 12
        anchor = (target - below > 6) ? below + 12 : below
        // Drawn only for the themed rules, so the other lick rules keep their seeds' songs.
        if Self.themedRules.contains(ruleID) {
            // One A in five: seed returns and the final statement bring A back on top of these.
            let forms: [[Character]] = [["C", "B", "A", "C", "B"],
                                        ["C", "A", "B", "C", "B"],
                                        ["B", "C", "A", "B", "C"]]
            form  = forms[rng.nextInt(upperBound: forms.count)]
            bPick = rng.nextInt(upperBound: 2)
            cPick = rng.nextInt(upperBound: 2)
        } else {
            form = []
        }
    }
}

/// A per-song transformation of the jazz licks. Three families, at most one from each, so they
/// never pile up on the same feature: the contour (inverted, reversed, leap flipped), the notes
/// (filled in, pared down) and the rhythm (pushed, laid back). Every one keeps the 8th grid,
/// the phrase's landing note and its octave span.
enum JazzVariant: String {
    case inverted       = "inverted"
    case reversed       = "reversed"
    case leapFlipped    = "flipped"
    case filledIn       = "filled"
    case paredDown      = "pared"
    case pushed         = "pushed"
    case laidBack       = "laid back"

    /// None in 20% of songs, one in 20%, two in 30%, three in 30% (Zack, 2026-11-12).
    static func draw(rng: inout SeededRNG) -> [JazzVariant] {
        let r = rng.nextDouble()
        let families: [Int]
        if r < 0.20 {
            families = []
        } else if r < 0.40 {
            // One alone: the contour half the time, since it changes the hook most.
            let f = rng.nextDouble()
            families = [f < 0.50 ? 0 : f < 0.75 ? 1 : 2]
        } else if r < 0.70 {
            families = [[0, 1], [0, 2], [1, 2]][rng.nextInt(upperBound: 3)]
        } else {
            families = [0, 1, 2]
        }
        return families.map { family -> JazzVariant in
            let c = rng.nextDouble()
            switch family {
            case 0:  return c < 0.40 ? .inverted : c < 0.75 ? .reversed : .leapFlipped
            case 1:  return c < 0.50 ? .filledIn : .paredDown
            default: return c < 0.50 ? .pushed : .laidBack
            }
        }
    }
}

extension ChillLeadGenerator {

    // MARK: Per-song versions of the licks

    /// A lick in this song's version. Deterministic: the same lick always comes out the same in
    /// one song, so its hook is recognisable each time it returns.
    static func applyJazzVariants(_ input: [JazzNote], _ variants: [JazzVariant]) -> [JazzNote] {
        var cell = input.sorted { $0.step < $1.step }
        guard cell.count >= 3 else { return cell }
        for v in variants {
            switch v {
            case .inverted:    cell = invertedLick(cell)
            case .reversed:    cell = reversedFigure(cell)
            case .leapFlipped: cell = leapFlippedLick(cell) ?? reversedFigure(cell)
            case .filledIn:    cell = filledInLick(cell)
            case .paredDown:   cell = paredDownLick(cell)
            case .pushed:      cell = shiftedHeldNotes(cell, by: -2)
            case .laidBack:    cell = shiftedHeldNotes(cell, by: 2)
            }
        }
        return cell
    }

    /// Mirrored around the chord root, so a minor-pentatonic climb becomes a major-pentatonic
    /// fall (b3 to the 6 below, 4 to the 5 below). The landing note keeps its pitch, in the octave
    /// nearest the note before it, so the phrase still comes home.
    private static func invertedLick(_ cell: [JazzNote]) -> [JazzNote] {
        var out = cell.map { (step: $0.step, iv: -$0.iv, dur: $0.dur) }
        let landing = cell[cell.count - 1].iv
        let before  = out[out.count - 2].iv
        let octaves = Int((Double(before - landing) / 12).rounded())
        out[out.count - 1].iv = landing + 12 * octaves
        return out
    }

    /// The pitches of the opening figure (the first run of three or more short notes, up to five)
    /// played backwards in the same rhythm. The held notes and the landing stay.
    private static func reversedFigure(_ cell: [JazzNote]) -> [JazzNote] {
        var start = 0
        while start < cell.count - 1 {
            var end = start
            while end < cell.count - 1 && cell[end].dur < 6 { end += 1 }
            if end - start >= 3 {
                let stop = Swift.min(end, start + 5)
                var out = cell
                let ivs = cell[start..<stop].map(\.iv).reversed()
                for (j, iv) in zip(start..<stop, ivs) { out[j].iv = iv }
                return out
            }
            start = end + 1
        }
        return cell
    }

    /// The widest leap out to a peak or a trough goes the other way: a dip to the b7 below
    /// becomes a lift to the b7 above, and the line comes back as before. Only where the leap
    /// back is a minor 7th or less and the lick stays within an octave (or its own span). Nil if
    /// the lick has no such leap.
    private static func leapFlippedLick(_ cell: [JazzNote]) -> [JazzNote]? {
        let ivs = cell.map(\.iv)
        let maxSpan = Swift.max(12, ivs.max()! - ivs.min()!)
        var best: (i: Int, size: Int)? = nil
        for i in 1..<(cell.count - 1) {
            let d = ivs[i] - ivs[i - 1]
            guard Swift.abs(d) >= 5 && Swift.abs(d) < 12 else { continue }
            guard Swift.abs(ivs[i + 1] - ivs[i - 1]) < Swift.abs(d) else { continue }
            let moved = ivs[i] - (d > 0 ? 12 : -12)
            guard Swift.abs(ivs[i + 1] - moved) <= 10 else { continue }
            var trial = ivs
            trial[i] = moved
            guard trial.max()! - trial.min()! <= maxSpan else { continue }
            if best == nil || Swift.abs(d) > best!.size { best = (i, Swift.abs(d)) }
        }
        guard let b = best else { return nil }
        var out = cell
        out[b.i].iv -= (ivs[b.i] - ivs[b.i - 1] > 0 ? 12 : -12)
        return out
    }

    /// Up to two notes added an 8th before a note that has room before it: an upper neighbour
    /// between repeated notes, a step through a third, or a step into the end of a fourth or
    /// fifth. The fitting pass moves them into the scale.
    private static func filledInLick(_ cell: [JazzNote]) -> [JazzNote] {
        var out: [JazzNote] = []
        var added = 0
        for i in cell.indices {
            out.append(cell[i])
            guard added < 2, i + 1 < cell.count else { continue }
            let a = cell[i], b = cell[i + 1]
            guard b.step - a.step >= 4 else { continue }
            let gap = b.iv - a.iv, dir = gap >= 0 ? 1 : -1
            let passing: Int
            switch Swift.abs(gap) {
            case 0:      passing = a.iv + 2
            case 3, 4:   passing = a.iv + 2 * dir
            case 5, 7:   passing = b.iv - 2 * dir
            default:     continue
            }
            out[out.count - 1].dur = Swift.min(a.dur, b.step - 2 - a.step)
            out.append((step: b.step - 2, iv: passing, dur: 2))
            added += 1
        }
        return out
    }

    /// One short inner note left out, its time given to the note before: a repeated note if
    /// there is one, otherwise the first short note after another short note.
    private static func paredDownLick(_ cell: [JazzNote]) -> [JazzNote] {
        guard cell.count >= 4 else { return cell }
        let inner = Array(1..<(cell.count - 1)).filter { cell[$0].dur <= 2 }
        guard let i = inner.first(where: { cell[$0].iv == cell[$0 - 1].iv })
                ?? inner.first(where: { cell[$0 - 1].dur <= 3 }) else { return cell }
        var out = cell
        out[i - 1].dur = cell[i].step + cell[i].dur - cell[i - 1].step
        out.remove(at: i)
        return out
    }

    /// Held notes on a beat moved an 8th: early (pushed, anticipating the beat) or late (laid
    /// back, the note before held into the beat).
    private static func shiftedHeldNotes(_ cell: [JazzNote], by delta: Int) -> [JazzNote] {
        var out = cell
        for i in 1..<out.count where out[i].step % 4 == 0 && out[i].dur >= 4 {
            if delta < 0 {
                guard out[i - 1].step <= out[i].step - 3 else { continue }
                out[i].step -= 2
                out[i].dur  += 2
            } else {
                guard out[i].dur >= 5 else { continue }
                if i + 1 < out.count && out[i].step + 2 >= out[i + 1].step { continue }
                let joined = out[i - 1].step + out[i - 1].dur >= out[i].step
                out[i].step += 2
                out[i].dur  -= 2
                if joined { out[i - 1].dur = out[i].step - out[i - 1].step }
            }
        }
        return out
    }

    // Moanin' (Bobby Timmons, from Art Blakey's Moanin', 1958): a two-bar call and response.
    private static let moaninCalls: [[JazzNote]] = [
        // A: pickup, climbs to b3, drops to the 5 and b7 below, lands on the root
        [(4, 0, 2), (7, 0, 1), (8, 3, 3), (11, 3, 1), (12, 0, 3), (15, -5, 1), (16, -2, 3), (20, 0, 4)],
        // B: climbs to 4, falls through the blue note, #4-4-b3, to the root
        [(4, 0, 2), (7, 0, 1), (8, 3, 3), (12, 5, 4), (16, 6, 1), (17, 5, 1), (18, 3, 2), (20, 0, 4)],
        // C: climbs to 5 and b7, the same blue-note fall
        [(4, 0, 2), (7, 0, 1), (8, 7, 3), (12, 10, 4), (16, 6, 1), (17, 5, 1), (18, 3, 2), (20, 0, 4)],
    ]
    /// The horns' "A-men", the top voice of the IV-to-I answer: 4 held, then b3.
    private static let moaninAmen: [JazzNote]     = [(24, 5, 6), (30, 3, 2)]
    private static let moaninAmenAlt: [JazzNote]  = [(24, 10, 6), (30, 7, 2)]
    /// A longer amen that comes home: 4, b3, root.
    private static let moaninAmenHome: [JazzNote] = [(24, 5, 3), (28, 3, 2), (30, 0, 2)]
    /// Over other chords, the shape of the bridge: a held 5 slipping down, then b3 settling home.
    private static let moaninBridge: [JazzNote] =
        [(0, 7, 7), (8, 6, 1), (9, 5, 2), (11, 0, 1), (12, 5, 3),
         (16, 3, 7), (24, -2, 3), (27, -5, 1), (28, -2, 2), (30, 0, 2)]

    // Cantaloupe Island (Herbie Hancock, Empyrean Isles, 1964).
    /// The hook: 1 1 . 1 b3 4, then 4 held, b3 4 5, then the b7 below and a long root.
    private static let cantaloupeHook: [JazzNote] =
        [(0, 0, 2), (2, 0, 2), (10, 0, 2), (12, 3, 2), (14, 5, 2),
         (16, 5, 10), (26, 3, 2), (28, 5, 3), (31, 7, 2), (33, -2, 3), (36, 0, 12)]
    /// The second statement: a ghost octave on the second note and a 5-b7 tag at the end.
    private static let cantaloupeRestate: [JazzNote] =
        [(0, 0, 2), (2, 12, 1), (10, 0, 2), (12, 3, 2), (14, 5, 2),
         (16, 5, 10), (26, 3, 2), (28, 5, 3), (31, 7, 2), (33, -2, 3), (36, 0, 8), (44, 7, 2), (46, 10, 2)]
    /// The top voice of the horn stabs: hits on steps 6, 9, 12 and 14, then one hit a bar later.
    private static let cantaloupeStabs: [JazzNote] = [(6, 0, 1), (9, 0, 1), (12, 0, 2), (14, 3, 2), (26, 0, 2)]
    /// 8th-note lines in the manner of Freddie Hubbard's solo, with the #4 blue note.
    private static let cantaloupeSolos: [[JazzNote]] = [
        [(0, 5, 2), (2, 3, 2), (4, 5, 2), (6, 3, 2), (8, 0, 2), (10, 3, 2), (12, 5, 1), (13, 6, 1),
         (14, 5, 2), (16, 3, 2), (18, 0, 6)],
        [(0, 7, 2), (2, 5, 2), (4, 3, 2), (6, 2, 2), (8, 0, 4), (16, 2, 2), (18, 5, 2), (20, 7, 1),
         (21, 7, 3), (24, 6, 2), (26, 6, 2), (28, 5, 1), (29, 3, 1), (30, 0, 2)],
    ]

    // Blue Monk (Thelonious Monk, 1954): a one-bar riff, a chromatic climb into a held 5.
    /// The source climbs 3-4-#4-5 over a major chord; in minor blues terms it is b3-4-#4-5.
    private static let monkRiff: [JazzNote]   = [(0, 3, 2), (2, 5, 2), (4, 6, 2), (6, 7, 10)]
    /// The falling answer: 5 6 5 #4 4, the 5 below, then 2 rising to b3.
    private static let monkAnswer: [JazzNote] =
        [(16, 7, 2), (18, 9, 2), (20, 7, 2), (22, 6, 2), (24, 5, 2), (26, -5, 2), (28, 2, 2), (30, 3, 2)]
    /// The short tail: b3, then 2 held.
    private static let monkTail: [JazzNote]   = [(18, 3, 4), (22, 2, 8)]

    // CHL-LD1-001 Chet sigh: after My Funny Valentine (Rodgers and Hart), Chet Baker's signature
    // tune, 1954. Deliberately not the tune: the gesture (a short pickup into a held 2 that
    // leans on the root, a climb that falls home) with its own pitches and rhythm, and every
    // statement varied. Four-bar phrases.
    /// The sigh approached from the b7 below (b7-1-b3 into a held 2), then a climb to the 5
    /// falling b3-2 to a held root.
    private static let valentineOpening: [JazzNote] =
        [(10, -2, 2), (12, 0, 2), (14, 3, 2), (16, 2, 10),
         (26, 3, 2), (28, 2, 1), (29, 0, 1), (30, 2, 2), (32, 7, 8),
         (42, 5, 2), (44, 3, 2), (46, 2, 2), (48, 0, 12)]
    /// The sigh twice, the second climbing to the 4 and turning back onto the held 2.
    private static let valentineSighs: [JazzNote] =
        [(10, -2, 2), (12, 0, 2), (14, 3, 2), (16, 2, 10),
         (26, 0, 2), (28, 3, 2), (30, 5, 1), (31, 3, 1), (32, 2, 14)]
    /// The sigh moved up: 2-b3-5 into a held 4, then up to the b7 settling on the 5.
    private static let valentineSequence: [JazzNote] =
        [(10, 2, 2), (12, 3, 2), (14, 7, 2), (16, 5, 10),
         (26, 3, 2), (28, 5, 1), (29, 7, 1), (30, 10, 2), (32, 7, 12)]
    /// The trumpet's scale run up to the b3 an octave over, then the fall from the 9th to the 5.
    private static let valentineRun: [JazzNote] =
        [(0, 3, 4), (4, 5, 2), (6, 7, 1), (8, 10, 2), (11, 12, 2), (13, 14, 2), (16, 15, 14),
         (32, 14, 9), (42, 12, 1), (45, 10, 1), (47, 8, 1), (48, 7, 14)]
    /// Over other chords, a bridge in the tune's manner, not its melody: 5 dropping to a held root
    /// with a leading-tone lean, then 3-4 up to the 6 and a slow fall to the 2.
    private static let valentineBridge: [JazzNote] =
        [(0, 7, 3), (4, 0, 8), (13, -1, 3), (16, 0, 8),
         (28, 4, 2), (30, 5, 2), (32, 9, 4), (36, 7, 2), (38, 4, 2), (40, 2, 10)]

    // CHL-LD1-007 Horace hook: after Song for My Father (Horace Silver, 1965). Four-bar phrases.
    /// The hook: a pickup from the 5 below, the turn on the b6, the fall to the b7 below with a b2
    /// grace, and a long b6 under the root.
    private static let fatherHook: [JazzNote] =
        [(10, -5, 2), (12, 0, 2), (14, 3, 2),
         (16, 7, 2), (18, 8, 1), (19, 7, 1), (20, 5, 1), (21, 3, 2), (23, 5, 3), (26, 7, 1), (27, 5, 1),
         (28, 0, 2), (30, 3, 4),
         (34, 5, 1), (35, 3, 1), (36, -2, 3), (39, 0, 3), (42, 1, 1), (43, 0, 1), (44, -5, 2), (46, -4, 14)]
    /// The B-section call: the 5 repeated, a fall to the 4 and a held b6; then the b6 repeated
    /// and lifted to the b7.
    private static let fatherCall: [JazzNote] =
        [(10, 7, 1), (12, 7, 1), (14, 7, 2), (16, 7, 2), (18, 5, 2), (22, 8, 14),
         (43, 8, 1), (44, 8, 1), (46, 8, 2), (48, 8, 2), (51, 7, 1), (54, 10, 10)]
    /// Over other chords, the horns' sighs: 4 to 3 into a held b6, then the leading tone home.
    private static let fatherSighs: [JazzNote] =
        [(12, 5, 2), (14, 4, 2), (16, 3, 2), (18, 8, 14), (40, -1, 6), (46, 0, 14)]

    // CHL-LD1-008 Blues bossa: after Blue Bossa (Kenny Dorham, on Joe Henderson's Page One, 1963). Four-bar phrases in the bossa's anticipations.
    /// The fall 5-4-b3-2 on the off-beats into a held root, then a 5-4 tag held over.
    private static let bossaHead: [JazzNote] =
        [(0, 7, 4), (6, 5, 3), (10, 3, 3), (14, 2, 2), (16, 0, 8), (42, 7, 2), (46, 5, 14)]
    /// The second phrase, the same fall a step lower, on through the b6 to the 5 below.
    private static let bossaSequence: [JazzNote] =
        [(0, 5, 4), (6, 3, 3), (10, 2, 3), (14, 0, 2), (16, -2, 8), (26, -4, 2), (30, -5, 9),
         (42, 5, 2), (46, 3, 14)]
    /// The fall turned upside down: root-2-b3-4 up to a held 5.
    private static let bossaRise: [JazzNote] =
        [(0, 0, 4), (6, 2, 3), (10, 3, 3), (14, 5, 2), (16, 7, 8), (42, 5, 2), (46, 3, 14)]
    /// Over other chords, the modulation's long fall: down a whole octave from the root.
    private static let bossaLongFall: [JazzNote] =
        [(0, 0, 3), (6, -2, 2), (10, -3, 2), (14, -5, 2), (16, -7, 10), (28, -9, 2),
         (32, -9, 4), (36, -10, 2), (40, -12, 12)]

    // Second and third themes (B, C) for CHL-LD1-001, 007, 008 and 015, each from a different
    // work, transcribed in key-root terms and fitted per song like the A licks. Four bars for
    // 001/007/008, two for 015. Notes are held to the next onset (legato for synth leads).

    /// 001 B, after Chet Baker's ballad solo on I Fall in Love Too Easily (Chet Baker Sings, 1954):
    /// a lean around the 3 climbing to a held 5, then a rise from the 5 below to the root.
    private static let chetBalladClimb: [JazzNote] =
        [(14, 4, 2), (17, 5, 2), (19, 4, 3), (22, 4, 7), (29, 2, 2), (31, 4, 4), (35, 5, 3),
         (38, 7, 4), (42, 7, 6), (48, -5, 2), (50, -3, 2), (52, -1, 3), (55, 0, 3), (58, -1, 2),
         (60, 0, 4)]
    /// 001 B: the same solo's repeated 3 between the blue thirds, settling on a long 5.
    private static let chetBalladRepeat: [JazzNote] =
        [(2, 4, 3), (5, 3, 2), (7, 6, 2), (9, 9, 4), (20, 8, 2), (22, 9, 1), (23, 11, 2),
         (25, 4, 3), (28, 4, 3), (31, 4, 4), (35, 4, 4), (39, 5, 1), (40, 4, 1), (41, 3, 1),
         (42, 4, 3), (45, 6, 3), (48, 7, 14)]
    /// 001 C, after Chet Baker's solo on Let's Get Lost (1955): a leap to the b7 and 9 above,
    /// through the #4 to the 5, then a fall to the 6 below and a lift to a held 2.
    private static let lostLeap: [JazzNote] =
        [(15, 12, 1), (16, 10, 4), (20, 14, 3), (23, 9, 3), (26, 6, 1), (27, 10, 1), (28, 7, 5),
         (33, 9, 1), (34, 7, 1), (35, 5, 1), (36, 2, 1), (37, -3, 2), (39, -5, 2), (41, -3, 7),
         (48, 0, 2), (50, 4, 1), (51, 5, 1), (52, 2, 8)]
    /// 001 C: an arpeggio up to the octave, turning down through the 5 and 3, home to the root.
    private static let lostTurn: [JazzNote] =
        [(3, -2, 1), (4, 2, 1), (5, 5, 1), (6, 9, 1), (7, 12, 5), (12, 9, 1), (13, 7, 4),
         (17, 12, 3), (20, 7, 1), (21, 4, 3), (24, 7, 1), (25, 10, 3), (28, 9, 1), (29, 7, 1),
         (30, 4, 2), (32, 5, 2), (34, 0, 2), (36, -3, 1), (37, -5, 6), (43, 4, 1), (44, 5, 2),
         (46, 0, 12)]

    /// 007 B, after Kenny Dorham's solo on Doodlin' (Horace Silver, 1954): a riff around the
    /// root stated three times, each reaching higher, falling to a held 5 below.
    private static let doodlinRiff: [JazzNote] =
        [(3, -5, 2), (5, -3, 1), (6, 0, 2), (8, 2, 1), (9, 0, 1), (10, -3, 2), (12, 0, 4),
         (19, -7, 2), (21, -3, 1), (22, 0, 2), (24, 3, 1), (25, 0, 2), (27, -3, 1), (28, 0, 4),
         (33, -5, 2), (35, -3, 2), (37, 0, 2), (39, 3, 1), (40, 4, 2), (42, 0, 2), (44, -3, 2),
         (46, 0, 3), (49, -3, 3), (52, -5, 10)]
    /// 007 B: the same solo's chromatic climb b3-3-4-#4-5 in 8ths, the fall to a held 4, home on the 5 below.
    private static let doodlinClimb: [JazzNote] =
        [(13, -5, 1), (14, -3, 1), (15, 0, 2), (17, 3, 2), (19, 4, 2), (21, 5, 2), (23, 6, 2),
         (25, 7, 2), (27, 4, 6), (33, 0, 2), (35, -2, 2), (37, -5, 3), (40, -7, 6), (46, -9, 1),
         (47, -8, 1), (48, -5, 10)]
    /// 007 C, after Lee Morgan's solo on The Sidewinder (1963): a b7-5-4 pickup to the root, the
    /// 4 hammered in 8ths, then b3-3 down to the root.
    private static let sidewinderHammer: [JazzNote] =
        [(3, 10, 2), (5, 7, 1), (6, 5, 1), (7, 7, 1), (8, 0, 1), (9, -2, 1), (10, 0, 6),
         (24, 5, 2), (26, 5, 2), (28, 5, 2), (30, 5, 2), (32, 5, 1), (33, 4, 1), (34, 3, 2),
         (36, 0, 1), (37, -2, 1), (38, 0, 8), (48, 3, 1), (49, 4, 2), (51, 0, 1), (52, -2, 1),
         (53, -5, 3), (56, 0, 8)]
    /// 007 C: the same solo's 8th-note run up to the octave and back down, then a 3-4 tag home.
    private static let sidewinderRun: [JazzNote] =
        [(0, 2, 2), (2, 4, 2), (4, 5, 2), (6, 7, 2), (8, 9, 2), (10, 12, 2), (12, 11, 2),
         (14, 10, 2), (16, 9, 2), (18, 8, 2), (20, 7, 2), (22, 5, 2), (24, 4, 2), (26, 7, 2),
         (28, 0, 6), (36, 4, 2), (38, 5, 4), (42, 3, 2), (44, 4, 2), (46, 0, 4), (50, -2, 2),
         (52, 0, 10)]

    /// 008 B, after Stolen Moments (Oliver Nelson, The Blues and the Abstract Truth, 1961): the
    /// head's climb to the 9 and fall to the b3 below, stated twice with a new ending.
    private static let stolenHead: [JazzNote] =
        [(2, -5, 2), (4, -2, 2), (6, 2, 4), (10, 0, 4), (14, -2, 2), (16, 0, 2), (18, -3, 4),
         (22, -7, 2), (24, -9, 2), (26, -5, 8), (34, -5, 2), (36, -2, 2), (38, 2, 4), (42, 0, 4),
         (46, -2, 2), (48, 0, 2), (50, -3, 6), (56, -5, 8)]
    /// 008 B: the head's second phrase, the same shape a step up and falling further.
    private static let stolenSequence: [JazzNote] =
        [(2, -4, 2), (4, 0, 2), (6, 3, 4), (10, 2, 4), (14, 0, 2), (16, 2, 2), (18, -2, 6),
         (24, -7, 2), (26, -4, 8), (34, -9, 2), (36, -5, 2), (38, -2, 4), (42, -3, 4),
         (46, -5, 2), (48, -3, 2), (50, -7, 6), (56, -9, 8)]
    /// 008 C, after Miles Davis's solo on So What (Kind of Blue, 1959): the root restated with
    /// space around it, a b3, a long 2 and a b7 that does not resolve.
    private static let soWhatSpace: [JazzNote] =
        [(0, 0, 2), (2, 0, 9), (11, 0, 2), (13, 3, 4), (17, 2, 1), (18, 0, 2), (20, -5, 1),
         (21, -5, 6), (31, 5, 3), (34, 2, 11), (45, 2, 1), (46, -2, 1), (47, 2, 2), (49, 5, 2),
         (51, 2, 3), (54, -2, 2), (56, -2, 7)]
    /// 008 C: the same solo's 2-b3 into a held 4, the fall to the 5 below, and a slow rise home.
    private static let soWhatFall: [JazzNote] =
        [(0, 2, 1), (1, 3, 1), (2, 5, 5), (7, 2, 8), (15, -2, 3), (18, -5, 1), (19, -2, 1),
         (20, 2, 1), (21, 5, 2), (23, 2, 4), (27, -2, 2), (29, 0, 1), (30, -2, 2), (32, -3, 1),
         (33, -5, 2), (35, -5, 8), (48, -5, 1), (49, -1, 1), (50, 0, 1), (51, 2, 4), (55, -2, 3),
         (58, 0, 6)]

    /// 015 B, after Parker's Mood (Charlie Parker, 1948): the opening fanfare up to the 3, a
    /// turn around the 2, and a long 2. Two bars.
    private static let moodFanfare: [JazzNote] =
        [(0, 0, 2), (2, -3, 2), (4, 4, 6), (10, 2, 1), (11, 0, 1), (12, 2, 1), (13, 4, 1),
         (14, 0, 1), (15, -3, 1), (16, 4, 3), (19, 0, 1), (20, 2, 2), (22, 2, 10)]
    /// 015 B: the theme's arpeggio up to the octave, dropping back to the root, then the
    /// octave repeated into a held 4.
    private static let moodArpeggio: [JazzNote] =
        [(2, 0, 2), (4, 4, 1), (5, 7, 2), (7, 9, 1), (8, 12, 1), (9, 0, 2), (11, 4, 3),
         (14, 0, 2), (16, 12, 1), (17, 12, 2), (19, 12, 1), (20, 7, 1), (21, 5, 10)]
    /// 015 C, after Sonny Rollins's solo on Tenor Madness (1956): the 3 and root traded in a
    /// rhythm, twice, landing on the root.
    private static let madnessRhythm: [JazzNote] =
        [(4, 4, 1), (5, 4, 2), (7, 0, 1), (8, 4, 2), (10, 0, 6), (16, 4, 2), (18, 0, 1),
         (19, 0, 1), (20, 4, 2), (22, 0, 1), (23, 3, 1), (24, 0, 8)]
    /// 015 C: the root hammered in a broken rhythm, a turn below it, and the 5 below held.
    private static let madnessHammer: [JazzNote] =
        [(1, 0, 2), (3, 0, 1), (4, 0, 2), (6, 0, 1), (7, 0, 2), (9, 0, 1), (10, -1, 1),
         (11, 2, 1), (12, -1, 1), (13, -3, 3), (16, -5, 2), (18, 0, 5), (23, 0, 2), (25, -2, 2),
         (27, -5, 5)]

    /// The B or C lick for a themed rule; `pick` alternates between the two of each.
    private static func themeLick(ruleID: String, theme: Character, pick: Int) -> [JazzNote] {
        let banks: [String: [[JazzNote]]] = [
            "CHL-LD1-001B": [chetBalladClimb, chetBalladRepeat], "CHL-LD1-001C": [lostLeap, lostTurn],
            "CHL-LD1-007B": [doodlinRiff, doodlinClimb], "CHL-LD1-007C": [sidewinderHammer, sidewinderRun],
            "CHL-LD1-008B": [stolenHead, stolenSequence], "CHL-LD1-008C": [soWhatSpace, soWhatFall],
            "CHL-LD1-015B": [moodFanfare, moodArpeggio], "CHL-LD1-015C": [madnessRhythm, madnessHammer],
        ]
        guard let bank = banks[ruleID + String(theme)] else { return [] }
        return bank[pick % bank.count]
    }

    /// The homage transformations for CHL-LD1-001, 007 and 008, each drawn on its own: drop a short
    /// inner note, nudge one inner note a 16th, add a chromatic grace into the first note, and on
    /// Chet sigh, Chet's turn (note, the one above, note) on the first long held note.
    private static func varyHomageCell(_ input: [JazzNote], ruleID: String,
                                       rng: inout SeededRNG) -> [JazzNote] {
        var cell = input.sorted { $0.step < $1.step }
        guard cell.count >= 4 else { return cell }
        if rng.nextDouble() < 0.35 {
            let inner = (1..<(cell.count - 1)).filter { cell[$0].dur <= 3 }
            if !inner.isEmpty { cell.remove(at: inner[rng.nextInt(upperBound: inner.count)]) }
        }
        if rng.nextDouble() < 0.30, cell.count >= 3 {
            let i = 1 + rng.nextInt(upperBound: cell.count - 2)
            let moved = cell[i].step + (rng.nextDouble() < 0.5 ? -1 : 1)
            if moved > cell[i - 1].step && moved < cell[i + 1].step { cell[i].step = moved }
        }
        if rng.nextDouble() < 0.20, cell[0].step >= 1 {
            let first = cell[0]
            cell.insert((step: first.step - 1, iv: first.iv - 1, dur: 1), at: 0)
        }
        if ruleID == "CHL-LD1-001", rng.nextDouble() < 0.30,
           let i = cell.indices.first(where: { cell[$0].dur >= 8 }) {
            let held = cell[i]
            cell.replaceSubrange(i...i, with: [(step: held.step, iv: held.iv, dur: 1),
                                               (step: held.step + 1, iv: held.iv + 1, dur: 1),
                                               (step: held.step + 2, iv: held.iv, dur: held.dur - 2)])
        }
        return cell
    }

    /// One phrase for a jazz cell rule. Picks a lick for this point in the song, moves it to the
    /// chord root under the phrase's first bar, and fits it to the scale and the register.
    static func jazzCellPhrase(state: inout JazzCellState, frame: GlobalMusicalFrame,
                               structure: SongStructure, bar: Int, bars: Int,
                               section: SectionLabel, leadInstrument: ChillLeadInstrument,
                               regLow: Int, regHigh: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let k = state.statements
        state.statements += 1
        let degree  = structure.chordWindow(atBar: bar)?.chordRoot ?? "1"
        let onTonic = degree == "1"
        let late    = bar >= frame.totalBars * 4 / 5   // the last fifth plays the licks plain
        let shift   = state.shift

        // Themed rules (001, 007, 008, 015): A A B to open, then the song's seed-picked form. The
        // last fifth opens with a plain A before the form resumes.
        var theme: Character = "A"
        if state.isThemed && k >= 2 && !(late && !state.finalHookDone) {
            if k == 2 {
                theme = "B"
            } else {
                theme = state.form[state.formPos % state.form.count]
                state.formPos += 1
            }
        }

        var cell: [JazzNote]
        if theme != "A" {
            let pick: Int
            if theme == "B" { pick = state.bPick; state.bPick += 1 }
            else            { pick = state.cPick; state.cPick += 1 }
            cell = themeLick(ruleID: state.ruleID, theme: theme, pick: pick)
            if state.ruleID != "CHL-LD1-015" {
                cell = cell.map { (step: $0.step + shift, iv: $0.iv, dur: $0.dur) }
            }
        } else {
            switch state.ruleID {
            case "CHL-LD1-013":   // Moanin'
                if !onTonic && rng.nextDouble() < 0.50 {
                    cell = moaninBridge
                } else {
                    cell = moaninCalls[state.ladder[k % state.ladder.count]].map {
                        (step: $0.step < 16 ? $0.step + shift : $0.step, iv: $0.iv, dur: $0.dur)
                    }
                    // The first four calls are always answered; later the answer varies or drops out.
                    let answer = rng.nextDouble()
                    if late || k < 4 || answer >= 0.55 {
                        cell += state.altAmen ? moaninAmenAlt : moaninAmen
                    } else if answer >= 0.25 {
                        cell += moaninAmenHome
                    }
                }
            case "CHL-LD1-014":   // Cantaloupe Island
                if k < 2 {
                    cell = k == 0 ? cantaloupeHook : cantaloupeRestate
                } else if late && !state.finalHookDone {
                    cell = cantaloupeHook
                    state.finalHookDone = true
                } else {
                    let r = rng.nextDouble()
                    let fragment = cantaloupeHook.filter { $0.step < 32 }
                    if !onTonic {
                        cell = r < 0.50 ? fragment : cantaloupeStabs
                    } else if r < 0.30 {
                        cell = fragment
                    } else if r < 0.80 {
                        cell = cantaloupeSolos[rng.nextInt(upperBound: cantaloupeSolos.count)].map {
                            (step: $0.step + shift, iv: $0.iv, dur: $0.dur)
                        }
                    } else {
                        cell = cantaloupeStabs
                    }
                }
            case "CHL-LD1-001":   // Chet sigh
                if k == 0 {
                    cell = valentineOpening
                } else if k == 1 {
                    cell = valentineSequence
                } else if late && !state.finalHookDone {
                    cell = valentineOpening
                    state.finalHookDone = true
                } else if !onTonic {
                    cell = rng.nextDouble() < 0.55 ? valentineBridge : valentineSighs
                } else {
                    let r = rng.nextDouble()
                    cell = r < 0.35 ? valentineSighs
                         : r < 0.65 ? valentineRun
                         : r < 0.85 ? valentineOpening
                         :            valentineSequence
                }
                cell = cell.map { (step: $0.step + shift, iv: $0.iv, dur: $0.dur) }
            case "CHL-LD1-007":   // Horace hook
                // The tune's A A B A: the hook, the hook again, the call, the hook.
                if k < 2 || (late && !state.finalHookDone) {
                    cell = fatherHook
                    if late && k >= 2 { state.finalHookDone = true }
                } else if !onTonic {
                    cell = rng.nextDouble() < 0.60 ? fatherSighs : fatherCall
                } else if k % 4 == 2 {
                    cell = fatherCall
                } else {
                    // Later the hook keeps its head and swaps the tail for the sighs' resolution.
                    cell = rng.nextDouble() < 0.60 ? fatherHook
                         : fatherHook.filter { $0.step < 32 } + [(40, -1, 6), (46, 0, 14)]
                }
                cell = cell.map { (step: $0.step + shift, iv: $0.iv, dur: $0.dur) }
            case "CHL-LD1-008":   // Blues bossa
                if k == 0 {
                    cell = bossaHead
                } else if k == 1 {
                    cell = bossaSequence
                } else if late && !state.finalHookDone {
                    cell = bossaHead
                    state.finalHookDone = true
                } else if !onTonic {
                    cell = rng.nextDouble() < 0.50 ? bossaSequence : bossaLongFall
                } else {
                    let r = rng.nextDouble()
                    cell = r < 0.40 ? bossaHead : r < 0.70 ? bossaRise : bossaSequence
                }
                cell = cell.map { (step: $0.step + shift, iv: $0.iv, dur: $0.dur) }
            default:              // CHL-LD1-015 Blue Monk
                var riff: [JazzNote] = monkRiff.map { (step: $0.step + shift, iv: $0.iv, dur: $0.dur) }
                // Later on the riff sometimes cuts its held note short, leaving air.
                if k >= 3 && !late && rng.nextDouble() < 0.30 { riff[riff.count - 1].dur = 4 }
                let answer: [JazzNote]
                if k == 0 || late           { answer = monkAnswer }
                else if k == 1 || !onTonic  { answer = monkTail }
                else                        { answer = rng.nextDouble() < 0.50 ? monkAnswer : monkTail }
                cell = riff + answer
                if late { state.finalHookDone = true }
            }
        }

        // This song's version of the lick, the same every time the lick comes round.
        if !state.variants.isEmpty { cell = applyJazzVariants(cell, state.variants) }

        // Horace hook and Blues bossa vary each statement after the first two (the last fifth
        // plays plain), so the tune is recognisable but never copied. Chet sigh varies every
        // statement, the first and last included: its source melody is too well known to state.
        let homage = ["CHL-LD1-001", "CHL-LD1-007", "CHL-LD1-008"].contains(state.ruleID)
        if homage && (state.ruleID == "CHL-LD1-001" || (k >= 2 && !late)) {
            cell = varyHomageCell(cell, ruleID: state.ruleID, rng: &rng)
        }

        // Fit to the phrase: drop what runs past its end, and keep the line to one note at a time.
        let span = bars * 16
        cell = cell.filter { $0.step >= 0 && $0.step < span }.sorted { $0.step < $1.step }
        guard !cell.isEmpty else { return [] }
        for i in cell.indices {
            let end = i + 1 < cell.count ? cell[i + 1].step : span
            cell[i].dur = Swift.max(1, Swift.min(cell[i].dur, end - cell[i].step))
        }
        // A phrase cut short by a section end or the intro's two-bar cap can stop on a pickup
        // whose landing was cut. End on the last note that is held instead (every bank lick ends
        // on a held note, so only a cut one ends short).
        if homage {
            while cell.count > 1, let last = cell.last, last.dur < 3 {
                cell.removeLast()
            }
        }

        // Move to the chord root, in the octave nearest the song's anchor where the whole lick fits.
        let rootPC = (frame.keySemitoneValue + degreeSemitone(degree)) % 12
        let lo = cell.map { $0.iv }.min()!, hi = cell.map { $0.iv }.max()!
        let roots = Array(stride(from: 24 + rootPC, through: 108, by: 12))
        let root: Int
        if homage {
            // The register is a hard limit (the Chill post-pass folds anything outside it), and a
            // four-bar lick can be wider than a sax's. Take the octave that folds the fewest notes,
            // then the one nearest the last phrase, so a figure stays in one octave.
            let target = state.lastRoot ?? state.anchor
            let folds = { (r: Int) in cell.filter { r + $0.iv < regLow || r + $0.iv > regHigh }.count }
            root = roots.min { (folds($0), Swift.abs($0 - target)) < (folds($1), Swift.abs($1 - target)) }!
            state.lastRoot = root
        } else {
            let fitting = roots.filter { $0 + lo >= regLow && $0 + hi <= regHigh }
            root = (fitting.isEmpty ? roots : fitting)
                .min { Swift.abs($0 - state.anchor) < Swift.abs($1 - state.anchor) }!
        }

        let mutedTrumpetBoost = leadInstrument == .mutedTrumpet ? 22 : 0
        let velBase: Int
        switch section {
        case .intro, .outro: velBase = 47 + mutedTrumpetBoost
        case .B:             velBase = 72 + mutedTrumpetBoost
        default:             velBase = 67 + mutedTrumpetBoost
        }
        let scale = frame.scalePCs
        var events: [MIDIEvent] = []
        for (i, n) in cell.enumerated() {
            let at = bar * 16 + n.step
            let tones = structure.chordWindow(atBar: at / 16)?.chordTones ?? []
            let allowed = scale.union(tones)
            var pitch = root + n.iv
            if !allowed.contains(pitch % 12) {
                // A short note a semitone from the next one is a passing tone (the blue note, or a
                // chromatic approach) and stays. Anything else moves to the nearest allowed note,
                // a chord tone first, then the lower one.
                let next = i + 1 < cell.count ? root + cell[i + 1].iv : nil
                let passing = n.dur <= 2 && next.map { Swift.abs($0 - pitch) == 1 } == true
                if !passing {
                    let options = [pitch - 1, pitch + 1, pitch - 2, pitch + 2]
                        .filter { allowed.contains($0 % 12) }
                    pitch = options.first { tones.contains($0 % 12) } ?? options.first ?? pitch
                }
            }
            while pitch < regLow  { pitch += 12 }
            while pitch > regHigh { pitch -= 12 }
            let accent = n.step % 4 == 0 ? 4 : 0
            let vel = Swift.max(30, Swift.min(120, velBase + accent + rng.nextInt(upperBound: 9) - 4))
            events.append(MIDIEvent(stepIndex: at, note: UInt8(pitch), velocity: UInt8(vel),
                                    durationSteps: n.dur))
        }
        return events
    }
}
