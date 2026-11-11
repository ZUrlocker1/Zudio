// LeadGenerator.swift — generation step 7
// Copyright (c) 2026 Zack Urlocker
// Lead 1, base Motorik:
// MOT-LD1-001 Hallogallo hook, 002 Radioactive riff, 003 Tour de France riff and 006 Model riff,
//   transcription hooks written by HookLeadEngine
// MOT-LD1-004 Stepwise Sequence — descending 5→4→2→1 (bar A), shifted b7→5→4→2 (bar B)
// MOT-LD1-005 Call and answer — bar A ascends 1→2→b3→5, bar B silent then answers 4→b3
// MOT-LD1-007 Vanishing Solo — 10-bar pentatonic guitar-style solo, with shorter returns
// MOT-LD1-008 Visiting Solo — 9-bar Dorian moog-style solo with octave arpeggios, with shorter returns
//   (Lead 2 plays with both: only the gap-answer rule MOT-LD2-002 Low bed keeps the solo bars to itself)
// Lead 1, Noir: MOT-LD1-009 Cold descent, 010 Pendulum arc, 011 Melodic Spiral,
//   012 Chromatic Descent, 013 Slow arc, 014 Rising phrase
// Lead 1, Arcade: MOT-LD1-015 Arcade Riff, 016 Machine Answer, 017 Pentatonic Blitz,
//   018 Octave Bounce, 019 Triad Climb, 020 Synth Hook
// Lead 1, Kraftwerk sync: MOT-LD1-021 Short Statement, 022 Long Run
// Lead 2, gap answers written later by GapAnswerEngine: MOT-LD2-001 Echo answer, 002 Low bed,
//   003 Hook fragment, 004 Answer cell, 006 Statement harmony
// Lead 2, Arcade arps: MOT-LD2-007 Arcade Arp, 008 Gate Arp, 009 Bounce Arp, 010 Blip
// Lead 2, Kraftwerk sync: MOT-LD2-011 Counter Sequencer, 012 Octave Unison

struct LeadGenerator {

    // Phrase note for LD1-010 Pendulum release phrases — stores a scale index resolved at replay time.
    private struct PendulumNote {
        var bar: Int; var step: Int; var scaleIdx: Int; var dur: Int; var velBase: Int
    }

    // Phrase note for LD1-013/014 melodic phrase engine — stores the resolved MIDI note directly.
    private struct MelodicNote {
        var barOff: Int; var step: Int; var midi: Int; var dur: Int; var vel: Int
    }

    // MARK: - Lead 1

    /// The longest stretch of bars Motorik Lead 1 may leave silent in the body, other than Noir,
    /// which is sparse by design. The hook engine fills longer gaps with fragments, the solo
    /// rules with short returns, and the arrangement filter won't rest a block that would open
    /// one (Zack, 2026-11-11).
    static let maxLead1SilentBars = 24

    static func generateLead1(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceLeadRuleID: String? = nil,
        passBodyBars: Int? = nil,
        noirVariation: Bool = false,
        arcadeVariation: Bool = false,
        sync: MotorikSync = .none,
        breakdownBars: Set<Int> = []
    ) -> (events: [MIDIEvent], solo: SoloWindows) {

        // Kraftwerk sync (Machine Voice only). No solo range: these rules are announcements
        // separated by silence, not a solo, and the Lead 1 solo machinery would fight them.
        if forceLeadRuleID == nil, sync.includes(kTrackLead1) {
            let ruleID = rng.weightedPick([0.60, 0.40]) == 1 ? "MOT-LD1-022" : "MOT-LD1-021"
            usedRuleIDs.insert(ruleID)
            return (kraftwerkLead1(ruleID: ruleID, frame: frame, tonalMap: tonalMap, rng: &rng), .none)
        }

        // A: Per-section rule — always consume two draws for RNG determinism across songs.
        // forceLeadRuleID is honoured only for known Motorik-lead IDs; cross-style IDs are ignored.
        let pickedA        = pickLd1Rule(rng: &rng, noir: noirVariation, arcade: arcadeVariation)
        let bRuleCandidate = pickLd1Rule(rng: &rng, noir: noirVariation, arcade: arcadeVariation)
        let aRule: String  = forceLeadRuleID.flatMap { $0.hasPrefix("MOT-LD1-") ? $0 : nil } ?? pickedA
        // B sections reuse the A rule 70% of the time.
        var bRule = (rng.nextDouble() < 0.70) ? aRule : bRuleCandidate
        // Hook rules own the whole song, so one can only arrive as the A rule. A hook drawn
        // for B alone keeps the A rule instead; no extra draw.
        if HookLeadEngine.isMotorikHookRule(bRule) && !HookLeadEngine.isMotorikHookRule(aRule) {
            bRule = aRule
        }
        // A solo rule plays only in the A section's solo window and its returns, and is silent in
        // the rest of the body. Drawn for B alone it left the whole B section empty, 60 bars of
        // it in a long song, so B keeps the A rule.
        if isSoloRule(bRule) && !isSoloRule(aRule) {
            bRule = aRule
        }
        usedRuleIDs.insert(aRule)

        // E: Delayed body entry — Lead 1 hard-silent for first 8 or 16 bars of A section,
        //    capped so Lead 1 never starts past absolute bar 12 (index 11).
        let aStart   = structure.sections.first(where: { $0.label == .A })?.startBar ?? 0
        let rawDelay = rng.nextDouble() < 0.7 ? 8 : 16
        let entryBar = min(aStart + rawDelay, arcadeVariation ? 9 : 11)

        // Two per-song draws whose values are unused. They are kept so every later draw lands
        // the same for a given seed.
        _ = rng.nextInt(upperBound: 8)
        _ = rng.nextDouble()

        // D: Previous note for octave-smooth voice leading across bars
        var prevNote: UInt8? = nil

        // LD1-004: Stepwise Sequence — run-length tracker for forced gap
        // After 3 full sequences (~6 bars) or 14 notes, mandates ≥1 bar silence.
        var ld4RunBars  = 0   // consecutive bars that produced notes
        var ld4RunNotes = 0   // notes produced in current active run
        var ld4RestUntil = -1 // bar index at which forced rest ends

        // G: Phrase gate for LD1-004 and LD1-005 — set at the start of each 4-bar cycle
        var phraseSparseCycle = false
        // The last bar either gated rule sounded in: past `maxGatedSilence` bars without one the
        // gate gives way, see `gateOpens`.
        var lastGatedBar = entryBar - 1

        // J: LD1-009 Cold Chord — two melodic variants, Noir-only
        //   Variant 0 (A): slow descent — one scale note per bar descending (20% ascending),
        //     30% chance beat-3 placement, octave drift every 3rd cycle, occasional long silence
        //   Variant 1 (C): motivic ostinato — 4-note cell, 4-bar blocks; transposes ±1 scale
        //     step every 3rd block, 15% retrograde, 20% +4-step rhythmic offset, velocity arc
        var coldVariant:      Int     = -1
        var coldWindowEnd:    Int     = -1
        var coldSilUntil:     Int     = 0
        var coldDescent:      [UInt8] = []
        var coldDescentIdx:   Int     = 0
        var coldCycleCount:   Int     = 0       // A: descent cycles (register drift, beat offset)
        var coldGoUp:         Int     = 0        // A: contour: 0=descent, 1=ascent, 2=arch
        var coldBeatOffset:   Int     = 0       // A: step offset within bar (0=beat1, 4=beat2, 8=beat3, 12=beat4)
        var coldMotif:        [UInt8] = []
        var coldBlockCount:   Int     = 0       // C: blocks played (transposition scheduling)
        var coldMotifReverse: Bool    = false   // C: play motif in retrograde this block
        var coldMotifStepOff: Int     = 0       // C: rhythmic displacement (0 or +4 steps)

        // K: LD1-010 Pendulum — two-note quarter alternation, Noir-only
        var pendulumWindowEnd:    Int  = -1   // bar where active block ends
        var pendulumUsesP4:       Bool = false
        var pendulumRestEnd:      Int  = -1   // bar where forced rest ends (phrase + silence)
        var pendulumBlockStart:   Int  = -1   // bar where current block started (for vel arc)
        var pendulumLastRootPC:   Int  = -1   // detects chord changes mid-block
        var pendulumPhraseShape:  Int  = -1   // 0=Rising Call  1=Falling Cascade  2=Riff Cell
        var pendulumPhraseBarStart: Int = -1  // first bar of the 2-bar release phrase
        var pendulumPhraseEnd:    Int  = -1   // bar where phrase ends
        // Persists across episodes so each repeat mutates slightly from the previous.
        var pendulumPhraseData: [PendulumNote] = []

        // L: LD1-012 Chromatic Descent — slow descending line, Noir only
        var chromaDescNote:      UInt8? = nil
        var chromaDescStepUntil: Int    = -1
        var chromaArcMode:       Bool   = false
        var chromaAscending:     Bool   = false
        var chromaArcFastFired:  Bool   = false
        var chromaArcPeak:       UInt8  = 0

        // M: LD1-013 Slow Arc — melodic phrase generator, Noir only
        var dronePhraseData: [MelodicNote] = []
        var dronePhraseBarStart: Int    = -1
        var droneActiveEnd:      Int    = -1
        var droneSilentEnd:      Int    = -1
        var droneLastNote:       UInt8? = nil
        var droneDirUp:          Bool   = true
        var droneDirCount:       Int    = 0

        // N: LD1-014 Semitone Stab — high-register phrase generator, Noir only
        var stabPhraseData: [MelodicNote] = []
        var stabPhraseBarStart: Int    = -1
        var stabPhraseEnd:      Int    = -1
        var stabSilenceEnd:     Int    = -1
        var stabLastNote:       UInt8? = nil
        var stabDirUp:          Bool   = true
        var stabDirCount:       Int    = 0

        // O: LD1-011 Melodic Spiral — phrase silence gate + consecutive-active counter (Noir thinning)
        var baPhraseSilent: Bool = false
        var baConsecutiveActive: Int = 0

        // H: Solo placement for LD1-007 / LD1-008 — single well-placed window in the A section.
        let isSoloRule = Self.isSoloRule(aRule)
        let soloLen    = aRule == "MOT-LD1-007" ? 10 : 9
        let soloWindow: Range<Int>? = isSoloRule
            ? pickSoloStartBar(structure: structure, soloLength: soloLen, rng: &rng, passBodyBars: passBodyBars)
            : nil
        let soloRange: Range<Int>? = soloWindow

        // I: General Lead 1 rest windows — applies to all non-solo rules.
        // Solo rules (007/008) manage their own silence via soloWindow; skip them.
        let ld1RestBars: Set<Int> = !isSoloRule
            ? buildRestBars(entryBar: entryBar, totalBars: frame.totalBars, rng: &rng, arcade: arcadeVariation)
            : []

        // Transcription hook rules (MOT-LD1-001 onward) generate the whole song in one call,
        // after the entry bar and rest windows are drawn, and own both A and B sections.
        if let hook = HookLeadEngine.motorikRules[aRule] {
            let events = HookLeadEngine.generate(
                rule: hook, frame: frame, structure: structure, tonalMap: tonalMap,
                entryBar: entryBar, restBars: ld1RestBars.union(breakdownBars),
                register: kRegisterBounds[kTrackLead1]!,
                maxGapBars: noirVariation ? nil : Self.maxLead1SilentBars, rng: &rng)
            return (events, .none)
        }

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            // E: Body section hard-silent before entryBar.
            // Solo rules (007/008) bypass this — their solo window starts near the top of the body.
            let isBodySection = section.label == .A || section.label == .B
            if isBodySection && bar < entryBar && !isSoloRule { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let rawIntensity = section.subPhaseIntensity(atBar: bar)
            // Arcade: never fully silent in the first 12 body bars — Lead 1 enters early.
            // Dense arp rules (015/017/018/019/020) return [] on .low, so a long A section
            // combined with buildRestBars can push the first note past bar 25+. Cap it.
            let intensity: SectionIntensity = (arcadeVariation && isBodySection
                                               && bar < aStart + 12
                                               && rawIntensity == .low) ? .medium : rawIntensity
            let barStart     = bar * 16

            // A: Choose rule based on section label
            let ruleID = (section.label == .B) ? bRule : aRule

            var barEvents: [MIDIEvent] = []

            // H: Solo window — checked before the switch so bRule never interferes.
            if !isIntroOutro, let window = soloWindow, window.contains(bar) {
                let soloBar = bar - window.lowerBound
                barEvents = soloBarEvents(rule: aRule, soloBar: soloBar, barStart: barStart, frame: frame)
                events.append(contentsOf: barEvents)
                prevNote = barEvents.last?.note
                continue
            }

            // H-pre: Solo rules — silence body bars outside the solo window.
            // In the 16 bars before the solo window, fire one ghost note at 8-bar boundaries (35%).
            // This gives the "soloist drifts in quietly, then steps forward" feel.
            if isSoloRule, !isIntroOutro, let window = soloWindow {
                let bodyStart = structure.bodySections.first?.startBar ?? 0
                if bar < window.lowerBound {
                    let preEchoStart = max(bodyStart, window.lowerBound - 16)
                    let atBoundary = bar >= preEchoStart && (bar - preEchoStart) % 8 == 0
                    if atBoundary && rng.nextDouble() < 0.35 {
                        let note = pickNoteNearest(entry: entry, frame: frame, trackIndex: kTrackLead1,
                                                   prevNote: prevNote, rng: &rng)
                        let dur  = 8 + rng.nextInt(upperBound: 5)  // 8–12 steps
                        let vel  = UInt8(45 + rng.nextInt(upperBound: 11))  // 45–55
                        events.append(MIDIEvent(stepIndex: barStart, note: note, velocity: vel, durationSteps: dur))
                        prevNote = note
                    }
                    continue
                }
                continue  // post-solo body bars: silent
            }

            // I: Structured rest window — silent for pre-computed 4–8 bar stretches (all non-solo rules)
            // LD1-011, LD1-013 and LD1-014 manage their own phrase silences; skip to preserve solo presence.
            // LD1-010 and LD1-011 reprise zone (final 25%) bypasses ld1RestBars so the return-to-form fires.
            let ld1RepriseBypass = (ruleID == "MOT-LD1-010" || ruleID == "MOT-LD1-011")
                                    && bar >= frame.totalBars * 3 / 4
            if !isIntroOutro && ld1RestBars.contains(bar)
                && ruleID != "MOT-LD1-013" && ruleID != "MOT-LD1-014"
                && !ld1RepriseBypass {
                prevNote = nil
                continue
            }

            switch ruleID {

            case "MOT-LD1-004":
                if !isIntroOutro {
                    // Forced gap: after 3 full sequences (~6 bars) or 14 notes, rest ≥1 bar.
                    let inForcedRest = bar < ld4RestUntil
                    if !inForcedRest && (ld4RunBars >= 6 || ld4RunNotes >= 14) {
                        ld4RestUntil = bar + 1 + rng.nextInt(upperBound: 3)  // 1–3 bar rest
                        ld4RunBars  = 0
                        ld4RunNotes = 0
                    }

                    // Phrase gate: 25% of 4-bar cycles are completely silent (Motorik breathing room).
                    // Bar gate: 15% of individual bars in active phrases are also silent.
                    let cycleBar = (bar - entryBar) % 4
                    if cycleBar == 0 { phraseSparseCycle = rng.nextDouble() < 0.25 }
                    let gatePasses = !inForcedRest && bar >= ld4RestUntil
                                  && !phraseSparseCycle && rng.nextDouble() >= 0.15
                    let willPlay = gatePasses || (!inForcedRest && Self.gateOpens(bar: bar, lastSounded: lastGatedBar))
                    if willPlay {
                        barEvents = lead1StepwiseSequence(barStart: barStart, bar: bar, entry: entry, frame: frame,
                            intensity: intensity, isIntroOutro: false, prevNote: prevNote, rng: &rng)
                        ld4RunBars  += 1
                        ld4RunNotes += barEvents.count
                    } else if !willPlay && barEvents.isEmpty {
                        // Any silent bar resets the run counters (but not the restUntil guard)
                        if bar >= ld4RestUntil { ld4RunBars = 0; ld4RunNotes = 0 }
                    }
                } else {
                    barEvents = lead1StepwiseSequence(barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity, isIntroOutro: true, prevNote: prevNote, rng: &rng)
                }

            case "MOT-LD1-005":
                if !isIntroOutro {
                    let cycleBar = (bar - entryBar) % 4
                    if cycleBar == 0 { phraseSparseCycle = rng.nextDouble() < 0.25 }
                    let gatePasses = !phraseSparseCycle && rng.nextDouble() >= 0.15
                    if gatePasses || Self.gateOpens(bar: bar, lastSounded: lastGatedBar) {
                        barEvents = lead1StatementAnswer(barStart: barStart, bar: bar, entry: entry, frame: frame,
                            intensity: intensity, isIntroOutro: false, prevNote: prevNote, rng: &rng)
                    }
                } else {
                    barEvents = lead1StatementAnswer(barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity, isIntroOutro: true, prevNote: prevNote, rng: &rng)
                }

            case "MOT-LD1-007", "MOT-LD1-008":
                // H: Solo windows handled by the pre-switch guard above.
                // Intro/outro: use motif-first so the track isn't silent before the song body.
                // Body bars not in any solo window: silent (Lead 1 yields to the solo identity).
                if isIntroOutro {
                    barEvents = lead1MotifFirst(barStart: barStart, entry: entry, frame: frame,
                        intensity: intensity, isIntroOutro: true, prevNote: prevNote, rng: &rng)
                }

            case "MOT-LD1-009":
                if !isIntroOutro {
                    barEvents = lead1ColdChord(
                        barStart: barStart, bar: bar, entry: entry, frame: frame,
                        coldVariant: &coldVariant, coldWindowEnd: &coldWindowEnd,
                        coldSilUntil: &coldSilUntil, coldDescent: &coldDescent,
                        coldDescentIdx: &coldDescentIdx,
                        coldCycleCount: &coldCycleCount, coldGoUp: &coldGoUp,
                        coldBeatOffset: &coldBeatOffset,
                        coldMotif: &coldMotif,
                        coldBlockCount: &coldBlockCount, coldMotifReverse: &coldMotifReverse,
                        coldMotifStepOff: &coldMotifStepOff, rng: &rng)
                }

            case "MOT-LD1-010":
                if !isIntroOutro {
                    barEvents = lead1Pendulum(
                        barStart: barStart, bar: bar, entry: entry, frame: frame,
                        pendulumWindowEnd: &pendulumWindowEnd, pendulumUsesP4: &pendulumUsesP4,
                        pendulumRestEnd: &pendulumRestEnd, pendulumBlockStart: &pendulumBlockStart,
                        pendulumLastRootPC: &pendulumLastRootPC,
                        pendulumPhraseShape: &pendulumPhraseShape,
                        pendulumPhraseBarStart: &pendulumPhraseBarStart,
                        pendulumPhraseEnd: &pendulumPhraseEnd,
                        pendulumPhraseData: &pendulumPhraseData,
                        rng: &rng)
                }

            case "MOT-LD1-011":
                if !isIntroOutro {
                    barEvents = lead1BeatAnchor(
                        barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity, baPhraseSilent: &baPhraseSilent,
                        baConsecutiveActive: &baConsecutiveActive,
                        rng: &rng)
                }

            case "MOT-LD1-012":
                if !isIntroOutro {
                    barEvents = lead1ChromaticDescent(
                        barStart: barStart, bar: bar, entry: entry, frame: frame,
                        chromaDescNote: &chromaDescNote, chromaDescStepUntil: &chromaDescStepUntil,
                        chromaArcMode: &chromaArcMode, chromaAscending: &chromaAscending,
                        chromaArcFastFired: &chromaArcFastFired, chromaArcPeak: &chromaArcPeak,
                        rng: &rng)
                }

            case "MOT-LD1-013":
                if !isIntroOutro {
                    barEvents = lead1DroneHold(
                        barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity,
                        dronePhraseData: &dronePhraseData, dronePhraseBarStart: &dronePhraseBarStart,
                        droneActiveEnd: &droneActiveEnd, droneSilentEnd: &droneSilentEnd,
                        droneLastNote: &droneLastNote, droneDirUp: &droneDirUp,
                        droneDirCount: &droneDirCount,
                        rng: &rng)
                }

            case "MOT-LD1-014":
                if !isIntroOutro {
                    let stabPos = Double(max(0, bar - entryBar))
                                / Double(max(1, frame.totalBars - 8 - entryBar))
                    barEvents = lead1SemitoneStab(
                        barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity, songPos: min(1.0, stabPos),
                        stabPhraseData: &stabPhraseData, stabPhraseBarStart: &stabPhraseBarStart,
                        stabPhraseEnd: &stabPhraseEnd, stabSilenceEnd: &stabSilenceEnd,
                        stabLastNote: &stabLastNote, stabDirUp: &stabDirUp,
                        stabDirCount: &stabDirCount,
                        rng: &rng)
                }

            case "MOT-LD1-020":
                if !isIntroOutro {
                    barEvents = lead1SynthHook(barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity)
                }

            case "MOT-LD1-015":
                if !isIntroOutro {
                    barEvents = lead1ArcadeRiff(barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity, rng: &rng)
                }

            case "MOT-LD1-016":
                if !isIntroOutro {
                    barEvents = lead1MachineAnswer(barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity, rng: &rng)
                }

            case "MOT-LD1-017":
                if !isIntroOutro {
                    barEvents = lead1PentatonicBlitz(barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity)
                }

            case "MOT-LD1-018":
                if !isIntroOutro {
                    barEvents = lead1OctaveBounce(barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity)
                }
        case "MOT-LD1-019":
                if !isIntroOutro {
                    barEvents = lead1TriadClimb(barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity, rng: &rng)
                }

            default:
                barEvents = lead1MotifFirst(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, prevNote: prevNote, rng: &rng)
            }

            events += barEvents
            if !barEvents.isEmpty, ruleID == "MOT-LD1-004" || ruleID == "MOT-LD1-005" { lastGatedBar = bar }

            // D: Update prevNote from the last event in this bar
            if let last = barEvents.max(by: { $0.stepIndex < $1.stepIndex }) {
                prevNote = last.note
            }
        }

        // Cap the two rules that combine length with density.
        //
        // Most long-running Lead 1 rules are sparse, and there the length IS the gesture: Noir's
        // Chromatic Descent runs 19 bars at 1.6 notes a bar, which is a slow descent, not a
        // fault. Arcade is relentless by design. These two are different — Melodic Spiral is
        // the densest rule in Motorik at 6.8 notes a bar and Octave Bounce is close behind at
        // 6.2, and both hold that for twenty bars and occasionally forty. A stream of
        // sixteenths with no air in it stops reading as a line.
        //
        // Rests are cut into the stretch rather than the rule being rewritten, so each keeps
        // its own character and only the tail cases change.
        let dense: Set<String> = ["MOT-LD1-011", "MOT-LD1-018"]
        if dense.contains(aRule) || dense.contains(bRule) {
            events = capUnbrokenStretch(events, maxBars: 20, totalBars: frame.totalBars, rng: &rng)
        }

        // MOT-LD1-007 and 008 play the full solo once. Shorter versions of it come back later in
        // the song, spread out from the full one. A pass regen only covers the start of the body,
        // so it keeps the full solo alone.
        var solo = SoloWindows(main: soloRange)
        if let main = soloRange, passBodyBars == nil {
            let reprise = shortSoloReprises(rule: aRule, main: main, structure: structure, frame: frame,
                                            avoidBars: breakdownBars, rng: &rng)
            events = (events + reprise.events).sorted { $0.stepIndex < $1.stepIndex }
            solo.short = reprise.ranges
        }
        return (events, solo)
    }

    /// The most bars LD1-004 or LD1-005 stay silent from their phrase and bar gates. Those gates are
    /// independent coin flips, and a few songs drew thirty or forty bars of silence from them
    /// (Zack, 2026-11-11). Rest windows and forced rests are not gates; they keep their place.
    private static let maxGatedSilence = 10

    /// True when the gate has held for long enough that the next bar plays regardless.
    private static func gateOpens(bar: Int, lastSounded: Int) -> Bool {
        bar - lastSounded > maxGatedSilence
    }

    /// Silences a two-to-three bar window inside any stretch of sounding bars longer than
    /// `maxBars`, repeating until nothing exceeds the cap.
    static func capUnbrokenStretch(_ events: [MIDIEvent], maxBars: Int,
                                           totalBars: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        var out = events
        var guardCount = 0
        while guardCount < 16 {
            guardCount += 1
            let sounding = Set(out.map { $0.stepIndex / 16 })
            // Find the first stretch that runs past the cap.
            var runStart = -1, found = -1
            for bar in 0...totalBars {
                if bar < totalBars, sounding.contains(bar) {
                    if runStart < 0 { runStart = bar }
                    if bar - runStart + 1 > maxBars { found = runStart; break }
                } else {
                    runStart = -1
                }
            }
            guard found >= 0 else { break }
            // Cut near the middle of the cap so the rest lands inside the phrase, not at its edge.
            let restLen   = 2 + rng.nextInt(upperBound: 2)          // 2 or 3 bars
            let restStart = found + maxBars - restLen - rng.nextInt(upperBound: 3)
            guard restStart > found else { break }
            let lo = restStart * 16, hi = (restStart + restLen) * 16
            out.removeAll { $0.stepIndex >= lo && $0.stepIndex < hi }
        }
        return out
    }

    // MARK: - Lead 2

    static func generateLead2(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        lead1Events: [MIDIEvent],
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        solo: SoloWindows = .none,
        arcadeVariation: Bool = false,
        arcadeDenseMelody: Bool = false
    ) -> [MIDIEvent] {
        // The regular pool holds the gap-answer rules MOT-LD2-001 to 004 and 006 in every variation.
        // Arcade's arp rules MOT-LD2-007 to 010 are drawn below, from the same stream.
        let ld2Rules:   [String] = arcadeVariation
            ? ["MOT-LD2-001", "MOT-LD2-003", "MOT-LD2-004"]
            : ["MOT-LD2-001", "MOT-LD2-002", "MOT-LD2-003", "MOT-LD2-004", "MOT-LD2-006"]
        let ld2Weights: [Double] = arcadeVariation
            ? [0.45,          0.35,          0.20]
            : [0.225,         0.15,          0.225,         0.25,          0.15]
        var ruleID = ld2Rules[rng.weightedPick(ld2Weights)]
        // MOT-LD2-006 Statement harmony is drawn in solo songs too: GapAnswerEngine lets it harmonise
        // the statements inside a Lead 1 solo window, which block every other Lead 2 rule.
        if arcadeVariation {
            let arcadeRoll = rng.nextDouble()
            if arcadeDenseMelody {
                // Lead 1 is a dense arp — 20% no Lead 2, rest spread across sparse rules and pool.
                // Distribution: 20% off / 16% Blip / 16% Bounce Arp / 12% Gate Arp / 36% pool.
                // The pool pick is a gap-answer rule, which answers only in Lead 1's gaps.
                if arcadeRoll < 0.20 {
                    usedRuleIDs.insert("MOT-LD2-000")
                    return []
                } else if arcadeRoll < 0.36 { ruleID = "MOT-LD2-010" }
                else if arcadeRoll < 0.52   { ruleID = "MOT-LD2-009" }
                else if arcadeRoll < 0.64   { ruleID = "MOT-LD2-008" }
                // else: keep pool pick (36%)
            } else {
                // Normal Arcade: 75% arp rules, 25% regular pool.
                if arcadeRoll < 0.25      { ruleID = "MOT-LD2-007" }
                else if arcadeRoll < 0.50 { ruleID = "MOT-LD2-008" }
                else if arcadeRoll < 0.75 { ruleID = "MOT-LD2-009" }
            }
        }
        usedRuleIDs.insert(ruleID)
        // A gap-answer rule needs the Lead 1 the listener hears, after ArrangementFilter and the
        // breakdown cut, so SongGenerator writes it later with GapAnswerEngine, continuing this
        // stream. Nothing is drawn here for it. Only the Arcade arp rules reach the bar loop.
        if GapAnswerEngine.isGapRule(ruleID) { return [] }

        var events: [MIDIEvent] = []

        // Pre-group Lead 1 events by bar for O(1) per-bar lookup (avoids O(n²) filter).
        var lead1ByBar = [[MIDIEvent]](repeating: [], count: frame.totalBars)
        for e in lead1Events {
            let b = e.stepIndex / 16
            if b < frame.totalBars { lead1ByBar[b].append(e) }
        }

        // Track L1 activity and dual-silence state for complementary scheduling.
        var l1ActiveRun = 0    // consecutive body bars L1 has been active
        var bothSilentRun = 0  // consecutive body bars both leads silent

        for bar in 0..<frame.totalBars {
            if solo.contains(bar: bar) { continue }

            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let barStart     = bar * 16

            let barL1 = lead1ByBar[bar]
            let l1ActiveBody = !barL1.isEmpty && !isIntroOutro
            if l1ActiveBody { l1ActiveRun += 1 } else if !isIntroOutro { l1ActiveRun = 0 }

            // Force L2 active after 4+ consecutive body bars where both leads are silent.
            let forcedActive = !isIntroOutro && bothSilentRun >= 4

            // A — Bar-level silencing (skipped when forced active to break a dead zone):
            // 35% extra rest when L1 has been active ≥8 consecutive bars.
            if !forcedActive && !isIntroOutro && l1ActiveRun >= 8 {
                if rng.nextDouble() < 0.35 { bothSilentRun = 0; continue }
            }

            let priorCount = events.count
            switch ruleID {
            case "MOT-LD2-007":
                events += lead2ArcadeArp(barStart: barStart, bar: bar, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro)
            case "MOT-LD2-008":
                events += lead2GateArp(barStart: barStart, bar: bar, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro)
            case "MOT-LD2-009":
                events += lead2BounceArp(barStart: barStart, bar: bar, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro)
            case "MOT-LD2-010":
                events += lead2Blip(barStart: barStart, bar: bar, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro)
            default:
                break
            }

            // Fallback: if forced active but the rule still produced nothing (e.g., arp rest bar),
            // inject a single root quarter-note to break the silence.
            if forcedActive && events.count == priorCount {
                let rootPC = chordRootPC(frame: frame, entry: entry)
                let note = nearestMIDI(pc: rootPC, bounds: RegisterBounds(low: 57, high: 69), prevNote: nil)
                events.append(MIDIEvent(stepIndex: barStart, note: note, velocity: 58, durationSteps: 4))
            }

            // Update both-silent counter (body bars only).
            if !isIntroOutro {
                if !l1ActiveBody && events.count == priorCount { bothSilentRun += 1 }
                else { bothSilentRun = 0 }
            }
        }

        return events
    }

    // MARK: - Motif-first: intro/outro for MOT-LD1-007 and 008, and the default case

    private static func lead1MotifFirst(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, prevNote: UInt8?, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        var localPrev = prevNote
        let density = isIntroOutro ? 0.2 : densityForIntensity(intensity)
        for step in [0, 4, 8, 12] {
            guard rng.nextDouble() < density else { continue }
            let note = pickNoteNearest(entry: entry, frame: frame, trackIndex: kTrackLead1,
                                       prevNote: localPrev, rng: &rng)
            let dur  = [4, 6, 8, 10, 12][rng.nextInt(upperBound: 5)]
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                velocity: velocityForIntensity(intensity, rng: &rng), durationSteps: dur))
            localPrev = note
        }
        if rng.nextDouble() < density * 0.3 {
            let offStep = [2, 6, 10, 14][rng.nextInt(upperBound: 4)]
            let note = pickNoteNearest(entry: entry, frame: frame, trackIndex: kTrackLead1,
                                       prevNote: localPrev, rng: &rng)
            events.append(MIDIEvent(stepIndex: barStart + offStep, note: note, velocity: 70, durationSteps: 2))
        }
        return events
    }

    // MARK: - LD1-004: Stepwise Sequence
    // Source: lead1_phrase_02 — descending 5→4→2→1 (bar A), shifted b7→5→4→2 (bar B).

    private static func lead1StepwiseSequence(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, prevNote: UInt8?, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro && rng.nextDouble() < 0.65 { return events }
        let bounds   = kRegisterBounds[kTrackLead1]!
        let rootPC   = chordRootPC(frame: frame, entry: entry)
        let scalePCs = frame.scalePCs

        let offsets: [Int] = (bar % 2 == 0) ? [7, 5, 2, 0] : [frame.mode.nearestInterval(10), 7, 5, 2]
        let durs:    [Int] = [3, 2, 3, 4]
        let velAdj:  [Int] = [11, 5, 7, 3]

        let baseVel = Int(velocityForIntensity(intensity, rng: &rng))
        var localPrev = prevNote
        for (i, step) in [0, 4, 8, 12].enumerated() {
            let rawPC = (rootPC + offsets[i]) % 12
            let pc    = nearestScalePitchClass(rawPC, in: scalePCs)
            let note  = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
            let v    = UInt8(Swift.max(50, Swift.min(110, baseVel + velAdj[i] - 8)))
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: v, durationSteps: durs[i]))
            localPrev = note
        }
        return events
    }

    // MARK: - LD1-005: Statement-Answer
    // Source: lead1_phrase_01 — statement-answer 2-bar phrasing.

    private static func lead1StatementAnswer(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, prevNote: UInt8?, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro && rng.nextDouble() < 0.65 { return events }
        let bounds   = kRegisterBounds[kTrackLead1]!
        let rootPC   = chordRootPC(frame: frame, entry: entry)
        let scalePCs = frame.scalePCs
        let baseVel  = Int(velocityForIntensity(intensity, rng: &rng))
        var localPrev = prevNote

        // Snap a raw PC (chord-root-relative offset) to the nearest in-scale pitch class.
        // Applying mode intervals from a non-tonic chord root yields OOS notes for non-tonic
        // chords (e.g. G+3=A# in A Aeolian). Snapping preserves melodic shape in-key.
        func snap(_ rawPC: Int) -> Int {
            nearestScalePitchClass((rawPC % 12 + 12) % 12, in: scalePCs)
        }

        // The mode's own third. nearestInterval(3) tied 2 and 4 in the major modes and took 2, so
        // the call played 1-2-2-5 and the answer 4-2.
        let third = frame.mode.isMajorFlavored ? 4 : 3

        if bar % 2 == 0 {
            let offsets = [0, 2, third, 7]
            let durs    = [4, 3, 3, 5]
            let velBump = [0, -6, -3, +2]
            for (i, step) in [0, 4, 8, 12].enumerated() {
                let pc   = snap((rootPC + offsets[i]) % 12)
                let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
                let v    = UInt8(Swift.max(50, Swift.min(110, baseVel + velBump[i])))
                events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                        velocity: v, durationSteps: durs[i]))
                localPrev = note
            }
        } else {
            if rng.nextDouble() < 0.40 {
                let pc   = snap((rootPC + 5) % 12)
                let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
                events.append(MIDIEvent(stepIndex: barStart + 6, note: note, velocity: 65, durationSteps: 2))
                localPrev = note
            }
            let answerOffsets = [5, third]
            let answerDurs    = [4, 5]
            for (i, step) in [8, 12].enumerated() {
                let pc   = snap((rootPC + answerOffsets[i]) % 12)
                let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
                let v    = UInt8(Swift.max(50, Swift.min(105, baseVel - i * 5)))
                events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                        velocity: v, durationSteps: answerDurs[i]))
                localPrev = note
            }
        }
        return events
    }

    // MARK: - LD1-009: Cold descent — melodic direction variant, Motorik Noir only
    //
    // Two variants chosen once per song (50/50):
    //   Variant A (0) — Slow Descent: one in-scale note per bar, mostly descending from b3 → b7
    //     (20% chance ascending). 30% chance note falls on beat 3 instead of beat 1.
    //     Every 3rd cycle: 40% chance of ±1 octave register shift. Silence 2–4 bars (20%: 6–8).
    //   Variant C (1) — Motivic Ostinato: 4-note cell at quarter-note spacing, 4-bar blocks.
    //     Every 3rd block: motif transposes ±1 scale step. 15% of blocks: retrograde.
    //     20% of blocks: +4-step rhythmic displacement. Velocity arcs low→mid over song.

    private static func lead1ColdChord(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        coldVariant:      inout Int,
        coldWindowEnd:    inout Int,
        coldSilUntil:     inout Int,
        coldDescent:      inout [UInt8],
        coldDescentIdx:   inout Int,
        coldCycleCount:   inout Int,
        coldGoUp:         inout Int,
        coldBeatOffset:   inout Int,
        coldMotif:        inout [UInt8],
        coldBlockCount:   inout Int,
        coldMotifReverse: inout Bool,
        coldMotifStepOff: inout Int,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let bounds   = kRegisterBounds[kTrackLead1]!
        let scalePCs = frame.scalePCs
        let rootPC   = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // Variant selection — once per song
        if coldVariant < 0 {
            coldVariant = rng.nextDouble() < 0.50 ? 0 : 1
        }

        // ── Variant A: Slow Descent (with ascent, arch, register drift, beat offset) ──────────
        if coldVariant == 0 {
            if bar >= coldWindowEnd && bar >= coldSilUntil {
                coldCycleCount += 1

                // Beat placement: 55% beat 1, 20% beat 3, 15% beat 2, 10% beat 4
                let br = rng.nextDouble()
                coldBeatOffset = br < 0.55 ? 0 : br < 0.75 ? 8 : br < 0.90 ? 4 : 12

                // Contour: 60% descent, 15% ascent, 25% arch (descend then partially rise)
                let cr = rng.nextDouble()
                coldGoUp = cr < 0.60 ? 0 : cr < 0.75 ? 1 : 2

                let startPC   = nearestScalePitchClass((rootPC + 3) % 12, in: scalePCs)
                var startNote = Int(nearestMIDI(pc: startPC, bounds: bounds, prevNote: nil))

                // Every 3rd cycle: 40% chance ±1 octave register shift (within bounds)
                if coldCycleCount % 3 == 0 && rng.nextDouble() < 0.40 {
                    let shift   = rng.nextDouble() < 0.55 ? 12 : -12
                    let shifted = startNote + shift
                    if shifted >= bounds.low && shifted <= bounds.high { startNote = shifted }
                }

                var seq: [UInt8] = []
                if coldGoUp == 2 {
                    // Arch: descend 3–4 scale steps then rise back 2–3 steps
                    let descLen = 3 + rng.nextInt(upperBound: 2)
                    for n in stride(from: startNote, through: bounds.low, by: -1) {
                        guard scalePCs.contains(n % 12) else { continue }
                        seq.append(UInt8(n))
                        if seq.count >= descLen { break }
                    }
                    if let bottom = seq.last {
                        let ascLen = 2 + rng.nextInt(upperBound: 2)
                        var rising = 0
                        for n in stride(from: Int(bottom) + 1, through: bounds.high, by: 1) {
                            guard scalePCs.contains(n % 12) else { continue }
                            seq.append(UInt8(n))
                            rising += 1
                            if rising >= ascLen { break }
                        }
                    }
                } else {
                    let direction = coldGoUp == 1 ? 1 : -1
                    let limit     = coldGoUp == 1 ? bounds.high : bounds.low
                    for n in stride(from: startNote, through: limit, by: direction) {
                        guard scalePCs.contains(n % 12) else { continue }
                        seq.append(UInt8(n))
                        if seq.count >= 8 { break }
                    }
                }
                let len        = min(5 + rng.nextInt(upperBound: 3), seq.count)
                coldDescent    = Array(seq.prefix(len))
                coldDescentIdx = 0
                coldWindowEnd  = bar + coldDescent.count
            }

            guard bar >= coldSilUntil && coldDescentIdx < coldDescent.count else { return [] }

            let note = coldDescent[coldDescentIdx]
            coldDescentIdx += 1
            if coldDescentIdx >= coldDescent.count {
                // 20% chance of a long silence (6–8 bars) vs normal 2–4
                let silLen    = rng.nextDouble() < 0.20 ? 6 + rng.nextInt(upperBound: 3)
                                                        : 2 + rng.nextInt(upperBound: 3)
                coldSilUntil  = bar + silLen
                coldWindowEnd = coldSilUntil
            }
            let vel = UInt8(55 + rng.nextInt(upperBound: 16))
            return [MIDIEvent(stepIndex: barStart + coldBeatOffset, note: note,
                              velocity: vel, durationSteps: 14)]
        }

        // ── Variant C: Motivic Ostinato (with transposition, retrograde, step offset) ───────
        if coldMotif.isEmpty {
            let r = rng.nextDouble()
            let offsets: [Int]
            if r < 0.33 {
                offsets = [0, 3, 2, 0]    // root → b3 → M2 → root
            } else if r < 0.66 {
                offsets = [3, 2, 0, 10]   // b3 → M2 → root → b7
            } else {
                offsets = [0, 7, 3, 0]    // root → 5th → b3 → root
            }
            var built: [UInt8] = []
            for (i, offset) in offsets.enumerated() {
                let pc   = nearestScalePitchClass((rootPC + offset) % 12, in: scalePCs)
                let prev: UInt8? = built.isEmpty ? nil : built[i - 1]
                built.append(nearestMIDI(pc: pc, bounds: bounds, prevNote: prev))
            }
            coldMotif     = built
            coldWindowEnd = bar + 4
            coldSilUntil  = 0
        }

        // Window management: 4-bar blocks with gaps
        if bar >= coldWindowEnd {
            coldBlockCount += 1

            // Every 3rd block: transpose motif ±1 scale step
            if coldBlockCount % 3 == 0 {
                var scaleNotes: [Int] = []
                for n in bounds.low...bounds.high where scalePCs.contains(n % 12) { scaleNotes.append(n) }
                let stepDelta = rng.nextDouble() < 0.55 ? 1 : -1
                coldMotif = coldMotif.map { note in
                    let closest = scaleNotes.indices.min(by: {
                        abs(scaleNotes[$0] - Int(note)) < abs(scaleNotes[$1] - Int(note))
                    }) ?? 0
                    return UInt8(clamping: scaleNotes[max(0, min(scaleNotes.count - 1, closest + stepDelta))])
                }
            }

            // 15% retrograde, 20% +4-step rhythmic offset
            coldMotifReverse = rng.nextDouble() < 0.15
            coldMotifStepOff = rng.nextDouble() < 0.20 ? 4 : 0

            if rng.nextDouble() < 0.30 {
                coldSilUntil  = bar + 2 + rng.nextInt(upperBound: 2)
                coldWindowEnd = coldSilUntil
            } else {
                coldSilUntil  = bar + 1
                coldWindowEnd = bar + 1 + 4
            }
        }

        guard bar < coldWindowEnd && bar >= coldSilUntil else { return [] }

        // Velocity arc: grows from ~50 to ~70 over song duration
        let songPos   = Double(bar) / Double(max(1, frame.totalBars))
        let velCenter = Int(50.0 + songPos * 20.0)

        let playMotif: [UInt8] = coldMotifReverse ? Array(coldMotif.reversed()) : coldMotif
        let steps = [0, 4, 8, 12].map { ($0 + coldMotifStepOff) % 16 }
        var events: [MIDIEvent] = []
        for (i, step) in steps.enumerated() {
            let note = playMotif[i % playMotif.count]
            let vel  = UInt8(clamping: max(28, velCenter + rng.nextInt(upperBound: 10) - (i == 0 ? 0 : 6)))
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: vel, durationSteps: 3))
        }
        return events
    }

    // MARK: - LD1-010: Pendulum arc — Disorder two-note quarter alternation, Noir only
    // Restructured: max 3–4 bar blocks, mandatory 3–5 bar rest between blocks.
    // Rhythmic fade: bar 0-1 full, bar 2 drops beat 4, bar 3 beats 1-2 only.
    // Rest bars: sparse dark drone fill (option 2 — pendulum as punctuation into a held field).
    // Active bars: occasional third-pitch interjection between root and lower (option 4).
    // Chord change mid-block forces an early rest.

    private static func lead1Pendulum(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        pendulumWindowEnd: inout Int, pendulumUsesP4: inout Bool,
        pendulumRestEnd: inout Int, pendulumBlockStart: inout Int,
        pendulumLastRootPC: inout Int,
        pendulumPhraseShape: inout Int, pendulumPhraseBarStart: inout Int,
        pendulumPhraseEnd: inout Int, pendulumPhraseData: inout [PendulumNote],
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let bounds = kRegisterBounds[kTrackLead1]!
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let p5bPC  = (rootPC + 5) % 12
        let p4bPC  = (rootPC + 7) % 12

        // Late reprise — final ~25% of song: chain blocks continuously, no silence between them.
        let isReprise = bar >= (frame.totalBars * 3 / 4)

        // Chord change mid-block: end block now, short rest before new one
        if pendulumLastRootPC >= 0 && rootPC != pendulumLastRootPC && bar < pendulumWindowEnd {
            pendulumWindowEnd = bar
            pendulumRestEnd   = bar + 2 + rng.nextInt(upperBound: 2)
        }
        pendulumLastRootPC = rootPC

        // Reprise: truncate any ongoing post-phrase silence so the next block starts immediately
        if isReprise && bar >= pendulumPhraseEnd && pendulumPhraseEnd > 0 && bar < pendulumRestEnd {
            pendulumRestEnd = bar
        }

        // Rest phase — 2-bar melodic release phrase, then 1-2 bars sparse/silence
        if bar >= pendulumWindowEnd && bar < pendulumRestEnd {
            if bar < pendulumPhraseEnd {
                return pendulumReleasePhrase(
                    barStart: barStart, phraseBar: bar - pendulumPhraseBarStart,
                    shape: pendulumPhraseShape, rootPC: rootPC, frame: frame,
                    chordTones: entry.chordWindow.chordTones,
                    phraseData: &pendulumPhraseData, rng: &rng)
            }
            // After phrase: occasional quiet drone, otherwise silence
            if rng.nextDouble() < 0.30 {
                return pendulumDroneFill(barStart: barStart, rootPC: rootPC, frame: frame, rng: &rng)
            }
            return []
        }

        // Start a new active block
        if bar >= pendulumRestEnd {
            // Noir thinning: 35% of potential blocks are skipped with an extended rest,
            // creating breathing room. Reprise bypasses this so late-song density returns.
            if !isReprise && rng.nextDouble() < 0.35 {
                pendulumWindowEnd      = bar
                pendulumPhraseBarStart = bar
                pendulumPhraseEnd      = bar
                pendulumRestEnd        = bar + 3 + rng.nextInt(upperBound: 3)  // 3–5 bar skip
                pendulumUsesP4         = rng.nextDouble() < 0.30   // consume draw for RNG determinism
                return []
            }
            let blockLen           = 3 + rng.nextInt(upperBound: 2)   // 3–4 bars max
            pendulumBlockStart     = bar
            pendulumWindowEnd      = bar + blockLen
            pendulumPhraseShape    = rng.nextInt(upperBound: 3)        // pick phrase shape once
            pendulumPhraseBarStart = pendulumWindowEnd
            pendulumPhraseEnd      = pendulumWindowEnd + 2             // 2-bar phrase
            // Reprise: no silence after phrase — chain directly into next block
            let silenceLen         = isReprise ? 0 : 1 + rng.nextInt(upperBound: 2)
            pendulumRestEnd        = pendulumPhraseEnd + silenceLen
            pendulumUsesP4         = rng.nextDouble() < 0.30
        }

        let root     = nearestMIDI(pc: rootPC, bounds: bounds, prevNote: nil)
        let lowerPC  = pendulumUsesP4 ? p4bPC : p5bPC
        var lowerInt = Int(nearestMIDI(pc: lowerPC, bounds: bounds, prevNote: root))
        if lowerInt >= Int(root) { lowerInt -= 12 }
        lowerInt = max(bounds.low, lowerInt)
        let lowerNote = UInt8(lowerInt)

        let blockPos = max(0, bar - pendulumBlockStart)
        let baseVel  = max(60, 82 - blockPos * 5)   // 82→77→72→67 fade across block

        var events: [MIDIEvent] = []
        switch blockPos {
        case 0, 1:
            events.append(MIDIEvent(stepIndex: barStart,      note: root,      velocity: UInt8(baseVel),      durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 4,  note: lowerNote, velocity: UInt8(baseVel - 8),  durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 8,  note: root,      velocity: UInt8(baseVel - 2),  durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 12, note: lowerNote, velocity: UInt8(baseVel - 10), durationSteps: 4))
            // Each beat independently: 70% chance to double with nearest chord tone above
            let ct = entry.chordWindow.chordTones
            for baseEvent in [
                (barStart,      Int(root),      baseVel),
                (barStart + 4,  Int(lowerNote), baseVel - 8),
                (barStart + 8,  Int(root),      baseVel - 2),
                (barStart + 12, Int(lowerNote), baseVel - 10)
            ] where rng.nextDouble() < 0.70 {
                let extra = (1...12).lazy.compactMap { off -> UInt8? in
                    let m = baseEvent.1 + off
                    guard m <= bounds.high, ct.contains(m % 12) else { return nil }
                    return UInt8(m)
                }.first
                if let extraNote = extra {
                    events.append(MIDIEvent(stepIndex: baseEvent.0, note: extraNote,
                                            velocity: UInt8(max(50, baseEvent.2 - 10)), durationSteps: 4))
                }
            }
        case 2:
            // Beat 4 dropped — root held as half note on beat 3
            events.append(MIDIEvent(stepIndex: barStart,     note: root,      velocity: UInt8(baseVel),     durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 4, note: lowerNote, velocity: UInt8(baseVel - 8), durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 8, note: root,      velocity: UInt8(baseVel - 4), durationSteps: 8))
        default:
            // Beats 1–2 only, then silence — winds down into rest
            events.append(MIDIEvent(stepIndex: barStart,     note: root,      velocity: UInt8(baseVel),     durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 4, note: lowerNote, velocity: UInt8(baseVel - 8), durationSteps: 4))
        }

        if blockPos <= 1 && rng.nextDouble() < 0.15 {
            let echoStep = rng.nextDouble() < 0.5 ? barStart + 2 : barStart + 6
            events.append(MIDIEvent(stepIndex: echoStep, note: root, velocity: 58, durationSteps: 2))
        }

        // Third-pitch interjection: ghosted scale tone between root and lower, on an off-beat.
        // Fires from blockPos 1+ so the first bar of each block stays clean.
        if blockPos >= 1 && rng.nextDouble() < 0.30 {
            let interjStep = rng.nextDouble() < 0.5 ? barStart + 10 : barStart + 14
            if let interjNote = pendulumInterjectionNote(root: root, lowerNote: lowerNote,
                                                         scalePCs: frame.scalePCs, bounds: bounds) {
                events.append(MIDIEvent(stepIndex: interjStep, note: interjNote,
                                        velocity: UInt8(55 + rng.nextInt(upperBound: 14)),
                                        durationSteps: 2))
            }
        }

        return events
    }

    // Full 2-bar melodic release phrase fired after each pendulum block ends.
    // Shape 0 Rising Call: climbs stepwise to a held peak, 2-note falling answer.
    // Shape 1 Falling Cascade: enters from upper register, descends to long root hold.
    // Shape 2 Riff Cell: punchy 4-note cell repeated, then extension and resolution.
    // Full 2-bar melodic release phrase. Phrase events are stored as stride-5 ints
    // [bar, step, scaleIdx, dur, velBase] so they persist and mutate across episodes.
    // First episode: built from shape. Each subsequent episode: last 2 bar-1 notes vary.
    private static func pendulumReleasePhrase(
        barStart: Int, phraseBar: Int, shape: Int,
        rootPC: Int, frame: GlobalMusicalFrame,
        chordTones: Set<Int>,
        phraseData: inout [PendulumNote], rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let bounds   = kRegisterBounds[kTrackLead1]!
        let rootMIDI = Int(nearestMIDI(pc: rootPC, bounds: bounds, prevNote: nil))

        // Use key-scale PCs (not chord-root Aeolian) so peak notes survive HarmonicFilter's
        // avoidTones check — e.g. in E minor key the 6th is F#, not F natural.
        var scale: [Int] = []
        for m in rootMIDI...bounds.high where frame.scalePCs.contains(m % 12) {
            scale.append(m)
        }
        guard scale.count >= 4 else { return [] }

        func s(_ i: Int) -> UInt8 { UInt8(scale[min(max(0, i), scale.count - 1)]) }
        func v(_ base: Int) -> UInt8 { UInt8(max(50, min(95, base + rng.nextInt(upperBound: 8) - 4))) }

        // Build from scratch on first episode; mutate at the start of each subsequent episode.
        if phraseData.isEmpty {
            pendulumBuildPhrase(shape: shape, phraseData: &phraseData)
        } else if phraseBar == 0 {
            pendulumMutatePhrase(phraseData: &phraseData, rng: &rng)
        }

        var events: [MIDIEvent] = []
        for note in phraseData where note.bar == phraseBar {
            let step     = note.step
            let scaleIdx = note.scaleIdx
            let dur      = note.dur
            let velBase  = note.velBase

            // Peak note (bar 1 step 0, long hold): 25% chance shorten it and add a
            // one-step-lower bridge note so the fall to s3 feels less abrupt.
            if phraseBar == 1 && step == 0 && dur >= 6 && rng.nextDouble() < 0.25 {
                let shortDur = 3 + rng.nextInt(upperBound: 3)   // 3–5 steps
                events.append(MIDIEvent(stepIndex: barStart + step, note: s(scaleIdx),
                                        velocity: v(velBase), durationSteps: shortDur))
                let bridgeStep = step + shortDur
                if bridgeStep < 8 {   // only if there's room before s3
                    events.append(MIDIEvent(stepIndex: barStart + bridgeStep,
                                            note: s(max(0, scaleIdx - 1)),
                                            velocity: UInt8(max(45, Int(v(velBase)) - 18)),
                                            durationSteps: 8 - bridgeStep))
                }
                continue
            }

            events.append(MIDIEvent(stepIndex: barStart + step, note: s(scaleIdx),
                                    velocity: v(velBase), durationSteps: dur))
        }

        // Bar 0 (ascending figure): each note independently 70% chance to double with
        // nearest chord tone above, so most of the ascent gets harmonic thickness.
        if phraseBar == 0 {
            let snapshot = events
            for pick in snapshot where rng.nextDouble() < 0.70 {
                let extra = (1...12).lazy.compactMap { off -> UInt8? in
                    let m = Int(pick.note) + off
                    guard m <= bounds.high, chordTones.contains(m % 12) else { return nil }
                    return UInt8(m)
                }.first
                if let extraNote = extra {
                    events.append(MIDIEvent(stepIndex: pick.stepIndex, note: extraNote,
                                            velocity: UInt8(max(35, Int(pick.velocity) - 18)),
                                            durationSteps: pick.durationSteps))
                }
            }
        }

        return events
    }

    private static func pendulumBuildPhrase(shape: Int, phraseData: inout [PendulumNote]) {
        phraseData.removeAll()
        switch shape {
        case 0:  // Rising Call
            // bar 0: ascends s1→s4, legato start-to-end
            phraseData += [.init(bar:0,step:0, scaleIdx:1,dur:2,velBase:65), .init(bar:0,step:2, scaleIdx:2,dur:4,velBase:70),
                           .init(bar:0,step:6, scaleIdx:3,dur:4,velBase:75), .init(bar:0,step:10,scaleIdx:4,dur:6,velBase:80)]
            // bar 1: peak s5 held, falling answer s3→s1
            phraseData += [.init(bar:1,step:0, scaleIdx:5,dur:8,velBase:85), .init(bar:1,step:8, scaleIdx:3,dur:2,velBase:68),
                           .init(bar:1,step:10,scaleIdx:1,dur:4,velBase:62)]
        case 1:  // Falling Cascade
            // bar 0: enters high s6, descends to s2
            phraseData += [.init(bar:0,step:0, scaleIdx:6,dur:2,velBase:82), .init(bar:0,step:2, scaleIdx:5,dur:2,velBase:76),
                           .init(bar:0,step:4, scaleIdx:4,dur:4,velBase:72), .init(bar:0,step:8, scaleIdx:3,dur:4,velBase:68),
                           .init(bar:0,step:12,scaleIdx:2,dur:4,velBase:64)]
            // bar 1: brief s3, then long root resolution
            phraseData += [.init(bar:1,step:0,scaleIdx:3,dur:2,velBase:70), .init(bar:1,step:2,scaleIdx:1,dur:4,velBase:66),
                           .init(bar:1,step:6,scaleIdx:0,dur:10,velBase:62)]
        default:  // Riff Cell
            // bar 0: root-m3-P4-P5 cell, repeated with slight offset
            phraseData += [.init(bar:0,step:0, scaleIdx:0,dur:2,velBase:82), .init(bar:0,step:3, scaleIdx:2,dur:2,velBase:76),
                           .init(bar:0,step:5, scaleIdx:3,dur:2,velBase:78), .init(bar:0,step:8, scaleIdx:0,dur:2,velBase:80),
                           .init(bar:0,step:11,scaleIdx:2,dur:2,velBase:72), .init(bar:0,step:13,scaleIdx:4,dur:3,velBase:74)]
            // bar 1: extension s5, fall s3→s2, long root
            phraseData += [.init(bar:1,step:0,scaleIdx:5,dur:4,velBase:78), .init(bar:1,step:4,scaleIdx:3,dur:2,velBase:70),
                           .init(bar:1,step:6,scaleIdx:2,dur:2,velBase:68), .init(bar:1,step:8,scaleIdx:0,dur:8,velBase:72)]
        }
    }

    // Mutate the last 2 bar-1 events slightly: nudge pitch, reverse direction, or leave.
    // All other events stay identical so the phrase retains its recognisable form.
    private static func pendulumMutatePhrase(phraseData: inout [PendulumNote], rng: inout SeededRNG) {
        let bar1Indices = phraseData.indices.filter { phraseData[$0].bar == 1 }
        guard bar1Indices.count >= 2 else { return }

        let last = bar1Indices[bar1Indices.count - 1]
        let prev = bar1Indices[bar1Indices.count - 2]

        let r = rng.nextDouble()
        if r < 0.35 {
            let delta = rng.nextDouble() < 0.5 ? 1 : -1
            phraseData[last].scaleIdx = max(0, phraseData[last].scaleIdx + delta)
        } else if r < 0.60 {
            let delta = rng.nextDouble() < 0.5 ? 1 : -1
            phraseData[last].scaleIdx = max(0, phraseData[last].scaleIdx + delta)
            phraseData[prev].scaleIdx = max(0, phraseData[prev].scaleIdx + delta)
        } else if r < 0.85 {
            let lastIdx = phraseData[last].scaleIdx
            let prevIdx = phraseData[prev].scaleIdx
            let diff = lastIdx - prevIdx
            if diff != 0 { phraseData[last].scaleIdx = max(0, prevIdx - diff) }
        }
        // else: ~15% no change — only velocity variation distinguishes this repeat

        let bar0Indices = phraseData.indices.filter { phraseData[$0].bar == 0 }
        if bar0Indices.count >= 2 && rng.nextDouble() < 0.30 {
            let candidates = Array(bar0Indices.dropFirst())
            let pick       = candidates[rng.nextInt(upperBound: candidates.count)]
            let delta      = rng.nextDouble() < 0.5 ? 1 : -1
            phraseData[pick].scaleIdx = max(0, min(phraseData[pick].scaleIdx + delta, 6))
        }
    }

    // Sparse long-held dark tone for pendulum rest bars — makes pendulum feel like punctuation.
    private static func pendulumDroneFill(
        barStart: Int, rootPC: Int, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let bounds  = kRegisterBounds[kTrackLead1]!
        let offsets = [0, 3, 10, 6]   // root, b3, b7, tritone
        let pc      = (rootPC + offsets[rng.nextInt(upperBound: offsets.count)]) % 12
        let note    = nearestMIDI(pc: pc, bounds: bounds, prevNote: nil)
        let vel     = UInt8(48 + rng.nextInt(upperBound: 11))
        let dur     = 12 + rng.nextInt(upperBound: 3)
        return [MIDIEvent(stepIndex: barStart, note: note, velocity: vel, durationSteps: dur)]
    }

    // Finds a scale tone between lowerNote and root to use as a ghosted interjection.
    private static func pendulumInterjectionNote(
        root: UInt8, lowerNote: UInt8, scalePCs: Set<Int>, bounds: RegisterBounds
    ) -> UInt8? {
        let lo = Int(lowerNote) + 1
        let hi = Int(root)
        guard hi > lo else { return nil }
        let candidates = (lo..<hi).filter { scalePCs.contains($0 % 12) }
        let pool = candidates.isEmpty ? Array(lo..<hi) : candidates
        guard !pool.isEmpty else { return nil }
        return UInt8(pool[pool.count / 2])   // pick the middle candidate for smoothest voice leading
    }

    // MARK: - LD1-011: Melodic Spiral — No Birds beat-melody over sustained lower drone, Noir only
    //
    // Variations added:
    //   1. Phrase silence gate  — 30% of 4-bar cycles completely silent
    //   2. Density by intensity — low: beats 1+3 only; medium: 1+3+4; high: all 4 beats
    //   3. Anchor dropout       — 20% of bars skip the lower anchor pulse
    //   5. Chord-change dropout — silent the 2 bars before any long chord transition (≥16 bars)

    private static func lead1BeatAnchor(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity,
        baPhraseSilent: inout Bool,
        baConsecutiveActive: inout Int,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let bounds   = kRegisterBounds[kTrackLead1]!
        let rootPC   = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let scalePCs = frame.scalePCs
        let melodyLow = (bounds.low + bounds.high) / 2   // ~65

        // 6. Late reprise — final ~25% of song: bypass silence gate, restore full density.
        // Gives a sense of returning to the original form after the thinned mid-section.
        let isReprise = bar >= (frame.totalBars * 3 / 4)

        // 1. Phrase silence gate — reset at start of each 4-bar cycle.
        // 50% base silence probability; after 3 consecutive active cycles (12 bars), next forced silent.
        // Reprise: gate bypassed — always active. RNG draw consumed for determinism.
        if bar % 4 == 0 {
            let roll = rng.nextDouble()   // always consume for RNG determinism
            if isReprise {
                baPhraseSilent     = false
                baConsecutiveActive = 0   // reset cap so reprise starts cleanly
            } else {
                let forceRest  = baConsecutiveActive >= 3
                baPhraseSilent = forceRest || roll < 0.50
                if baPhraseSilent { baConsecutiveActive = 0 } else { baConsecutiveActive += 1 }
            }
        }
        if baPhraseSilent { return [] }

        // 5. Chord-change dropout — drop 2 bars before a long chord transition (skip in reprise)
        let chordLen     = entry.chordWindow.endBar - entry.chordWindow.startBar
        let barsToChange = entry.chordWindow.endBar - bar
        if !isReprise && chordLen >= 16 && barsToChange <= 2 { return [] }

        var scale: [Int] = []
        for oct in 0...8 {
            for pc in 0..<12 {
                let midi = oct * 12 + pc
                if midi >= melodyLow && midi <= bounds.high && scalePCs.contains(pc) {
                    scale.append(midi)
                }
            }
        }
        scale.sort()
        guard scale.count >= 4 else { return [] }

        let rootMIDI = nearestMIDI(pc: rootPC, bounds: RegisterBounds(low: melodyLow, high: bounds.high), prevNote: nil)
        var startIdx = scale.firstIndex(where: { $0 >= Int(rootMIDI) }) ?? 0
        startIdx = (startIdx + (bar % 4)) % max(1, scale.count - 3)
        let melodyNotes = (0..<4).map { i -> UInt8 in
            UInt8(scale[min(startIdx + i, scale.count - 1)])
        }
        let anchorMIDI = UInt8(max(bounds.low, Int(melodyNotes[0]) - 12))

        // 2. Density by intensity — controls how many melody beats fire.
        // Reprise: always full density (all 4 beats) regardless of intensity.
        let melodySteps: [Int]
        if isReprise {
            melodySteps = [0, 4, 8, 12]   // full density — return to form
        } else {
            switch intensity {
            case .low:    melodySteps = [0, 8]           // beats 1+3 — spare and open
            case .medium: melodySteps = [0, 8, 12]       // beats 1+3+4
            case .high:   melodySteps = [0, 4, 8, 12]   // all 4 — full original density
            }
        }

        // 3. Anchor dropout — 20% of active bars drop the lower pulse entirely.
        // Reprise: anchor always on for full rhythmic presence. RNG draw consumed for determinism.
        let dropAnchorRoll = rng.nextDouble()
        let dropAnchor     = isReprise ? false : dropAnchorRoll < 0.20

        var events: [MIDIEvent] = []

        for step in melodySteps {
            let noteIdx = step / 4
            let vel: UInt8 = step == 0 ? 80 : 70
            events.append(MIDIEvent(stepIndex: barStart + step, note: melodyNotes[noteIdx],
                                    velocity: vel, durationSteps: 3))
        }

        if !dropAnchor {
            for step in [2, 6, 10, 14] {
                events.append(MIDIEvent(stepIndex: barStart + step, note: anchorMIDI,
                                        velocity: 54, durationSteps: 2))
            }
        }

        return events
    }

    // MARK: - LD1-012: Chromatic Descent — slow descending line, Noir only
    // Love Will Tear Us Apart Arp Omni 2 synth: beat-1 attacks, d12-16 holds.
    // Starts near P5 or P4 above root, steps down 1-2 semitones every 2-3 bars, cycles on root.
    // 20% of phrase restarts enter arc mode: ascend from root, fire a chromatic fast run at the
    // peak, then descend with 20%-per-bar burst chances.

    private static func lead1ChromaticDescent(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        chromaDescNote: inout UInt8?, chromaDescStepUntil: inout Int,
        chromaArcMode: inout Bool, chromaAscending: inout Bool,
        chromaArcFastFired: inout Bool, chromaArcPeak: inout UInt8,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let bounds   = kRegisterBounds[kTrackLead1]!
        let rootPC   = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let rootMIDI = nearestMIDI(pc: rootPC, bounds: bounds, prevNote: nil)

        // Silence gate — respect gap after phrase cadence
        if bar < chromaDescStepUntil { return [] }

        if chromaDescNote == nil {
            if rng.nextDouble() < 0.20 {
                chromaArcMode = true; chromaAscending = true; chromaArcFastFired = false
                chromaArcPeak = UInt8(clamping: Int(rootMIDI) + (rng.nextDouble() < 0.55 ? 7 : 5))
                chromaDescNote = rootMIDI
            } else {
                chromaArcMode = false
                chromaDescNote = UInt8(clamping: Int(rootMIDI) + (rng.nextDouble() < 0.55 ? 7 : 5))
            }
            chromaDescStepUntil = -1
        }

        guard var noteVal = chromaDescNote else { return [] }

        let stepEveryBars = 2 + (bar % 3 == 0 ? 1 : 0)
        let shouldStep    = bar % stepEveryBars == 0 && bar > 0

        if chromaArcMode && chromaAscending {
            // Ascending leg: step up each period, fire fast run when near peak
            if shouldStep {
                let step = rng.nextDouble() < 0.60 ? 1 : 2
                noteVal  = UInt8(clamping: min(Int(chromaArcPeak), Int(noteVal) + step))
                chromaDescNote = noteVal
            }
            if Int(noteVal) >= Int(chromaArcPeak) - 1 && !chromaArcFastFired {
                chromaArcFastFired = true
                chromaAscending    = false
                chromaDescNote     = chromaArcPeak
                let baseVel  = UInt8(62 + rng.nextInt(upperBound: 12))
                let runStart = UInt8(clamping: Int(chromaArcPeak) - 3)
                return chromaFastRun(barStart: barStart, startNote: runStart, direction: 1,
                                     bounds: bounds, baseVel: baseVel, rng: &rng)
            }
            let dur = 12 + rng.nextInt(upperBound: 5)
            let vel = UInt8(62 + rng.nextInt(upperBound: 12))
            return [MIDIEvent(stepIndex: barStart, note: noteVal, velocity: vel, durationSteps: dur)]

        } else if chromaArcMode {
            // Descending leg of arc
            if shouldStep {
                let step      = rng.nextDouble() < 0.60 ? 1 : 2
                let descended = Int(noteVal) - step
                if descended <= Int(rootMIDI) {
                    // 30% chance: cadence on root then insert 2–4 bar silence
                    if rng.nextDouble() < 0.30 {
                        noteVal = rootMIDI
                        chromaDescNote = nil
                        chromaDescStepUntil = bar + 2 + rng.nextInt(upperBound: 3)
                    } else if rng.nextDouble() < 0.20 {
                        chromaAscending = true; chromaArcFastFired = false
                        chromaArcPeak = UInt8(clamping: Int(rootMIDI) + (rng.nextDouble() < 0.55 ? 7 : 5))
                        noteVal = rootMIDI; chromaDescNote = noteVal
                    } else {
                        chromaArcMode = false
                        noteVal = UInt8(clamping: Int(rootMIDI) + (rng.nextDouble() < 0.55 ? 7 : 5))
                        chromaDescNote = noteVal
                    }
                } else {
                    noteVal = UInt8(clamping: max(Int(bounds.low), descended))
                    chromaDescNote = noteVal
                }
            }
            // Gap was triggered — fire root cadence note cleanly, skip fast run
            if chromaDescNote == nil {
                let vel = UInt8(62 + rng.nextInt(upperBound: 12))
                return [MIDIEvent(stepIndex: barStart, note: noteVal, velocity: vel, durationSteps: 12)]
            }
            if rng.nextDouble() < 0.20 {
                let baseVel  = UInt8(62 + rng.nextInt(upperBound: 12))
                let runStart = UInt8(clamping: min(Int(bounds.high), Int(noteVal) + 2))
                return chromaFastRun(barStart: barStart, startNote: runStart, direction: -1,
                                     bounds: bounds, baseVel: baseVel, rng: &rng)
            }
            let dur = 12 + rng.nextInt(upperBound: 5)
            let vel = UInt8(62 + rng.nextInt(upperBound: 12))
            return [MIDIEvent(stepIndex: barStart, note: noteVal, velocity: vel, durationSteps: dur)]

        } else {
            // Normal descent (original behavior with arc restart chance)
            if shouldStep {
                let step      = rng.nextDouble() < 0.60 ? 1 : 2
                let descended = Int(noteVal) - step
                if descended <= Int(rootMIDI) {
                    // 30% chance: cadence on root then insert 2–4 bar silence
                    if rng.nextDouble() < 0.30 {
                        noteVal = rootMIDI
                        chromaDescNote = nil
                        chromaDescStepUntil = bar + 2 + rng.nextInt(upperBound: 3)
                    } else if rng.nextDouble() < 0.20 {
                        chromaArcMode = true; chromaAscending = true; chromaArcFastFired = false
                        chromaArcPeak = UInt8(clamping: Int(rootMIDI) + (rng.nextDouble() < 0.55 ? 7 : 5))
                        noteVal = rootMIDI; chromaDescNote = noteVal
                    } else {
                        noteVal = UInt8(clamping: Int(rootMIDI) + (rng.nextDouble() < 0.55 ? 7 : 5))
                        chromaDescNote = noteVal
                    }
                } else {
                    noteVal = UInt8(clamping: max(Int(bounds.low), descended))
                    chromaDescNote = noteVal
                }
            }
            let dur = 12 + rng.nextInt(upperBound: 5)
            let vel = UInt8(62 + rng.nextInt(upperBound: 12))
            var events: [MIDIEvent] = []
            events.append(MIDIEvent(stepIndex: barStart, note: noteVal, velocity: vel, durationSteps: dur))
            // Skip echo on phrase-end cadence — clean landing before the silence gap
            if chromaDescNote != nil {
                // Echo only when pitch class is in scale — out-of-scale main notes are removed by
                // HarmonicFilter, which would leave the echo orphaned with nothing preceding it.
                let echoRoll = rng.nextDouble()
                if echoRoll < 0.20 && frame.scalePCs.contains(Int(noteVal) % 12) {
                    events.append(MIDIEvent(stepIndex: barStart + 8, note: noteVal,
                                            velocity: UInt8(clamping: Int(vel) - 12), durationSteps: 4))
                }
            }
            return events
        }
    }

    // 4-5 quick chromatic notes at steps 0,2,4,6(,8). direction: +1 up, -1 down.
    private static func chromaFastRun(
        barStart: Int, startNote: UInt8, direction: Int,
        bounds: RegisterBounds, baseVel: UInt8, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let count = 4 + rng.nextInt(upperBound: 2)
        var events: [MIDIEvent] = []
        var note = Int(startNote)
        for i in 0..<count {
            let dur    = 2 + rng.nextInt(upperBound: 2)
            let velAdj = rng.nextInt(upperBound: 9) - 4
            let vel    = UInt8(clamping: Int(baseVel) + velAdj)
            events.append(MIDIEvent(stepIndex: barStart + i * 2, note: UInt8(clamping: note),
                                    velocity: vel, durationSteps: dur))
            note = max(Int(bounds.low), min(Int(bounds.high), note + direction))
        }
        return events
    }

    // MARK: - LD1-013 / LD1-014: Shared phrase-builder config

    // Configuration struct parameterising the shared melodic phrase engine used by
    // both LD1-013 (Slow Arc) and LD1-014 (Semitone Stab).
    private struct PhraseGenConfig {
        // Note count: low-intensity base + rng(range); high-intensity adds 1 more to base
        var noteCountLow: Int;  var noteCountHigh: Int;  var noteCountRange: Int
        // Phrase span in bars
        var phraseLenBase: Int; var phraseLenRange: Int
        // Initial cursor offset within the phrase (supports offbeat entry for LD1-014)
        var cursorBase: Int;    var cursorRange: Int
        // Note durations (steps): first, middle, last note in phrase
        var firstDurBase: Int;  var firstDurRange: Int
        var midDurBase: Int;    var midDurRange: Int
        var lastDurBase: Int;   var lastDurRange: Int
        // Inter-note gap
        var gapBase: Int;       var gapRange: Int
        // Velocity envelope: velFloor + velMul * velRange, where velMul is a piecewise ramp
        var velFloor: Double;   var velRange: Double
        var velBreakpoint: Double
        var velRiseSlope: Double
        var velFallSlope: Double
        // Shape probability thresholds for dirUp=true (dirUp=false mirrors them)
        var shapeThresh0: Double   // prob of ascending (or descending when !dirUp)
        var shapeThresh1: Double   // cumulative prob up to arch (or valley)
        // Characteristic pitch-class offsets for first-phrase start-note selection
        var charPCOffsets: [Int]
    }

    // LD1-013 Slow Arc: slow, wide-range phrases
    private static let droneConfig = PhraseGenConfig(
        noteCountLow: 4,  noteCountHigh: 5,  noteCountRange: 3,
        phraseLenBase: 3, phraseLenRange: 3,
        cursorBase: 0,    cursorRange: 4,
        firstDurBase: 10, firstDurRange: 5,
        midDurBase: 5,    midDurRange: 5,
        lastDurBase: 8,   lastDurRange: 5,
        gapBase: 1,       gapRange: 4,
        velFloor: 64.0,   velRange: 20.0,
        velBreakpoint: 0.5, velRiseSlope: 0.5, velFallSlope: 0.3,
        shapeThresh0: 0.45, shapeThresh1: 0.75,
        charPCOffsets: [0, 3, 7, 10]
    )

    // LD1-014 Semitone Stab: faster, high-register phrases with offbeat entry
    private static let stabConfig = PhraseGenConfig(
        noteCountLow: 5,  noteCountHigh: 6,  noteCountRange: 3,
        phraseLenBase: 2, phraseLenRange: 2,
        cursorBase: 2,    cursorRange: 5,
        firstDurBase: 5,  firstDurRange: 4,
        midDurBase: 3,    midDurRange: 4,
        lastDurBase: 4,   lastDurRange: 5,
        gapBase: 1,       gapRange: 3,
        velFloor: 68.0,   velRange: 18.0,
        velBreakpoint: 0.35, velRiseSlope: 0.57, velFallSlope: 0.25,
        shapeThresh0: 0.40, shapeThresh1: 0.70,
        charPCOffsets: [0, 7, 3, 10]
    )

    // Shared phrase-building engine for LD1-013 and LD1-014.
    private static func buildMelodicPhrase(
        scaleNotes: [Int],
        rootPC: Int,
        intensity: SectionIntensity,
        config: PhraseGenConfig,
        lastNote: inout UInt8?,
        dirUp: inout Bool,
        dirCount: inout Int,
        rng: inout SeededRNG
    ) -> (phraseData: [MelodicNote], phraseLen: Int) {
        let noteCount = (intensity == .low ? config.noteCountLow : config.noteCountHigh)
                        + rng.nextInt(upperBound: config.noteCountRange)
        let phraseLen = config.phraseLenBase + rng.nextInt(upperBound: config.phraseLenRange)

        // Start note: melodic memory + direction arc, or characteristic tone on first phrase
        let startNote: Int
        if let last = lastNote {
            let lastInt = Int(last)
            let step    = 1 + rng.nextInt(upperBound: 3)
            let srcIdx  = scaleNotes.indices.min(by: { abs(scaleNotes[$0] - lastInt) < abs(scaleNotes[$1] - lastInt) }) ?? 0
            let tgtIdx  = dirUp ? min(scaleNotes.count - 1, srcIdx + step) : max(0, srcIdx - step)
            startNote   = scaleNotes[tgtIdx]
        } else {
            let charPCs   = config.charPCOffsets.map { (rootPC + $0) % 12 }
            let charNotes = scaleNotes.filter { charPCs.contains($0 % 12) }
            let mid       = (scaleNotes.first! + scaleNotes.last!) / 2
            startNote     = (charNotes.isEmpty ? scaleNotes : charNotes)
                .min(by: { abs($0 - mid) < abs($1 - mid) })!
        }

        var scaleIdx = scaleNotes.indices.min(by: { abs(scaleNotes[$0] - startNote) < abs(scaleNotes[$1] - startNote) }) ?? 0

        // Phrase shape: 0=ascending  1=descending  2=arch(up→down)  3=valley(down→up)
        let shapeR = rng.nextDouble()
        let shape: Int
        if dirUp {
            shape = shapeR < config.shapeThresh0 ? 0 : (shapeR < config.shapeThresh1 ? 2 : 3)
        } else {
            shape = shapeR < config.shapeThresh0 ? 1 : (shapeR < config.shapeThresh1 ? 3 : 2)
        }

        var phraseData: [MelodicNote] = []
        var cursor = config.cursorBase + rng.nextInt(upperBound: config.cursorRange)

        for noteIdx in 0..<noteCount {
            guard cursor < phraseLen * 16 else { break }
            let barOff    = cursor / 16
            let stepInBar = cursor % 16

            let isFirst = noteIdx == 0
            let isLast  = noteIdx == noteCount - 1
            let dur: Int
            if isFirst     { dur = config.firstDurBase + rng.nextInt(upperBound: config.firstDurRange) }
            else if isLast { dur = config.lastDurBase  + rng.nextInt(upperBound: config.lastDurRange) }
            else           { dur = config.midDurBase   + rng.nextInt(upperBound: config.midDurRange) }

            let prog   = Double(noteIdx) / Double(max(1, noteCount - 1))
            let velMul: Double
            if prog < config.velBreakpoint {
                velMul = (1.0 - config.velRiseSlope) + prog / config.velBreakpoint * config.velRiseSlope
            } else {
                velMul = 1.0 - (prog - config.velBreakpoint) / (1.0 - config.velBreakpoint) * config.velFallSlope
            }
            let vel = UInt8(clamping: Int(config.velFloor + velMul * config.velRange) + rng.nextInt(upperBound: 5))

            phraseData.append(MelodicNote(barOff: barOff, step: stepInBar, midi: scaleNotes[scaleIdx], dur: dur, vel: Int(vel)))

            let gap  = config.gapBase + rng.nextInt(upperBound: config.gapRange)
            cursor  += dur + gap

            let halfNotes = noteCount / 2
            let move      = 1 + rng.nextInt(upperBound: 2)
            let prevIdx   = scaleIdx
            switch shape {
            case 0:  scaleIdx = min(scaleNotes.count - 1, scaleIdx + move)
            case 1:  scaleIdx = max(0, scaleIdx - move)
            case 2:  scaleIdx = noteIdx < halfNotes
                ? min(scaleNotes.count - 1, scaleIdx + move)
                : max(0, scaleIdx - move)
            default: scaleIdx = noteIdx < halfNotes
                ? max(0, scaleIdx - move)
                : min(scaleNotes.count - 1, scaleIdx + move)
            }
            // If the boundary clamped scaleIdx in place, bounce 1–2 steps the other way
            // to prevent flat runs of 3+ identical notes at the top or bottom of the register.
            if scaleIdx == prevIdx {
                let bounce   = 1 + rng.nextInt(upperBound: 2)
                let goingUp  = (shape == 0)
                    || (shape == 2 && noteIdx < halfNotes)
                    || (shape == 3 && noteIdx >= halfNotes)
                scaleIdx = goingUp
                    ? max(0, scaleIdx - bounce)
                    : min(scaleNotes.count - 1, scaleIdx + bounce)
            }
        }

        // Update melodic memory and direction arc
        if phraseData.count >= 2 {
            let lastMIDI  = phraseData.last!.midi
            lastNote      = UInt8(lastMIDI)
            let firstMIDI = phraseData.first!.midi
            let netUp     = lastMIDI >= firstMIDI
            if netUp == dirUp {
                dirCount += 1
                if dirCount >= 2 { dirUp = !dirUp; dirCount = 0 }
            } else {
                dirUp = netUp; dirCount = 1
            }
        }

        return (phraseData, phraseLen)
    }

    private static func replayPhrase(
        phraseData: [MelodicNote], phraseBarStart: Int, bar: Int, barStart: Int
    ) -> [MIDIEvent] {
        let myBarOff = bar - phraseBarStart
        var events: [MIDIEvent] = []
        for note in phraseData where note.barOff == myBarOff {
            events.append(MIDIEvent(
                stepIndex:     barStart + note.step,
                note:          UInt8(note.midi),
                velocity:      UInt8(note.vel),
                durationSteps: note.dur))
        }
        return events
    }

    // MARK: - LD1-013: Slow Arc — melodic phrase generator, Noir only
    // Joy Division / PiL guitar lead: 4-7 note phrases with clear melodic shape,
    // quarter-to-half-note durations, 2-5 bar silence between phrases.

    private static func lead1DroneHold(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity,
        dronePhraseData: inout [MelodicNote], dronePhraseBarStart: inout Int,
        droneActiveEnd: inout Int, droneSilentEnd: inout Int,
        droneLastNote: inout UInt8?, droneDirUp: inout Bool, droneDirCount: inout Int,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Late reprise — final ~25% of song: chain phrases continuously with no silence gaps.
        let isReprise = bar >= (frame.totalBars * 3 / 4)
        if bar >= droneActiveEnd && bar < droneSilentEnd && !isReprise { return [] }

        if bar >= droneActiveEnd {
            let bounds = kRegisterBounds[kTrackLead1]!
            let keyST  = keySemitone(frame.key)
            let rootPC = (keyST + degreeSemitone(entry.chordWindow.chordRoot)) % 12

            let scaleNotes: [Int] = frame.mode.intervals
                .flatMap { iv in (0...9).map { oct in keyST + iv + oct * 12 } }
                .filter { $0 >= Int(bounds.low) && $0 <= Int(bounds.high) }
                .sorted()
            guard !scaleNotes.isEmpty else { return [] }

            let (data, phraseLen) = buildMelodicPhrase(
                scaleNotes: scaleNotes, rootPC: rootPC, intensity: intensity,
                config: droneConfig,
                lastNote: &droneLastNote, dirUp: &droneDirUp, dirCount: &droneDirCount,
                rng: &rng)

            dronePhraseData     = data
            dronePhraseBarStart = bar
            droneActiveEnd      = bar + phraseLen
            let silBars         = isReprise ? 0 : (intensity == .high ? 1 : 2) + rng.nextInt(upperBound: 3)
            droneSilentEnd      = droneActiveEnd + silBars
        }

        guard bar < droneActiveEnd, !dronePhraseData.isEmpty else { return [] }
        return replayPhrase(phraseData: dronePhraseData, phraseBarStart: dronePhraseBarStart,
                            bar: bar, barStart: barStart)
    }

    // MARK: - LD1-014: Rising phrase — high-register melodic phrase generator, Noir only
    // PiL Annalisa T1 guitar character: 5-8 note phrases in high register (65-79),
    // shorter durations (3-8 steps), tight gaps, offbeat entry.
    // Silence blends shorter as song progresses. Same phrase engine as LD1-013.

    private static func lead1SemitoneStab(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, songPos: Double,
        stabPhraseData: inout [MelodicNote], stabPhraseBarStart: inout Int,
        stabPhraseEnd: inout Int, stabSilenceEnd: inout Int,
        stabLastNote: inout UInt8?, stabDirUp: inout Bool, stabDirCount: inout Int,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Late reprise — final ~25% of song: chain phrases continuously with no silence gaps.
        let isReprise = bar >= (frame.totalBars * 3 / 4)
        if bar >= stabPhraseEnd && bar < stabSilenceEnd && !isReprise { return [] }

        if bar >= stabPhraseEnd {
            let bounds     = kRegisterBounds[kTrackLead1]!
            let stabBounds = RegisterBounds(low: 65, high: bounds.high)
            let keyST      = keySemitone(frame.key)
            let rootPC     = (keyST + degreeSemitone(entry.chordWindow.chordRoot)) % 12

            let scaleNotes: [Int] = frame.mode.intervals
                .flatMap { iv in (0...9).map { oct in keyST + iv + oct * 12 } }
                .filter { $0 >= Int(stabBounds.low) && $0 <= Int(stabBounds.high) }
                .sorted()
            guard !scaleNotes.isEmpty else { return [] }

            let (data, phraseLen) = buildMelodicPhrase(
                scaleNotes: scaleNotes, rootPC: rootPC, intensity: intensity,
                config: stabConfig,
                lastNote: &stabLastNote, dirUp: &stabDirUp, dirCount: &stabDirCount,
                rng: &rng)

            stabPhraseData     = data
            stabPhraseBarStart = bar
            stabPhraseEnd      = bar + phraseLen

            // Silence blends shorter as song progresses; reprise: no silence — chain phrases continuously
            let silBars: Int
            if isReprise {
                silBars = 0
            } else {
                let quickChance = 0.10 + 0.30 * songPos
                let longChance  = 0.30 - 0.25 * songPos
                let sr = rng.nextDouble()
                if sr < quickChance           { silBars = 1 }
                else if sr < 1.0 - longChance { silBars = 2 + rng.nextInt(upperBound: 2) }
                else                          { silBars = 4 + rng.nextInt(upperBound: 3) }
            }
            stabSilenceEnd = stabPhraseEnd + silBars
        }

        guard bar < stabPhraseEnd, !stabPhraseData.isEmpty else { return [] }
        return replayPhrase(phraseData: stabPhraseData, phraseBarStart: stabPhraseBarStart,
                            bar: bar, barStart: barStart)
    }

    // MARK: - MOT-LD2-007: Arcade Arp — 16th-note arpeggio (Tempest 2000 / Raiden II texture)
    // Cycles root–M3–P5–oct–P5–M3 continuously (6 notes per cycle). 4 bars on / 1 bar rest.
    // Fully staccato (dur=1). Register MIDI 60–76. Delay on 35% probability — set by SongGenerator.
    // Arcade weight: 55–65% of Arcade songs (determined in generateLead2 via 60% rng roll).

    private static func lead2ArcadeArp(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool
    ) -> [MIDIEvent] {
        if isIntroOutro { return [] }
        // 4-bar on / 1-bar rest cycle
        guard bar % 5 != 4 else { return [] }
        var events: [MIDIEvent] = []
        let bounds = kRegisterBounds[kTrackLead2]!
        let rootPC  = chordRootPC(frame: frame, entry: entry)
        let thirdSemis: Int
        switch frame.mode {
        case .Ionian, .Mixolydian, .Lydian: thirdSemis = 4
        default:                            thirdSemis = 3
        }
        // Rotate arp base every 8 bars: root → 3rd → 5th → root…
        // Transposes the whole 6-note cycle to different chord tones, changing pitch-class fingerprint.
        let baseShifts = [0, thirdSemis, 7]
        let basePC = (rootPC + baseShifts[(bar / 8) % 3]) % 12
        let baseThirdPC  = (basePC + thirdSemis) % 12
        let baseFifthPC  = (basePC + 7) % 12
        // 6-note cycle: base, base+3rd, base+5th, base+oct, base+5th, base+3rd
        let cyclePCs: [Int] = [basePC, baseThirdPC, baseFifthPC, basePC, baseFifthPC, baseThirdPC]
        let phaseStart = (bar % 5) * 16
        for step in 0..<16 {
            let cycleIdx = (phaseStart + step) % 6
            let pc  = cyclePCs[cycleIdx]
            let low  = (cycleIdx == 0 || cycleIdx == 3) ? bounds.low : bounds.low + 5
            let high = bounds.high
            let note = nearestMIDI(pc: pc, bounds: RegisterBounds(low: low, high: high), prevNote: nil)
            events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: 50, durationSteps: 1))
        }
        return events
    }

    // MARK: - MOT-LD1-020: Synth Hook — diatonic 2-bar melodic phrase with 2-bar rest (not an arp)
    // Bar 0 (call): root→M2→3rd→P5 at 8th-note positions (steps 0,2,4,8). Gap at step 6 gives breathing room.
    // Bar 1 (answer): P5→3rd→M2→root at steps 0,2,6,8; root held a quarter note (dur=4).
    // Bars 2–3: completely silent — lets Bass and Lead 2 own those bars.
    // Register MIDI 62–76. Intensity: low=silent; medium=call bar only; high=full phrase.
    // Not in arcadeDenseArpRules, so coordination layer leaves Bass and Lead 2 at full weights.

    private static func lead1SynthHook(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity
    ) -> [MIDIEvent] {
        if intensity == .low { return [] }
        let phase = bar % 4
        guard phase < 2 else { return [] }               // bars 2–3 always silent
        if intensity == .medium && phase == 1 { return [] } // medium: call only
        let bounds = RegisterBounds(low: 62, high: 76)
        let rootPC = chordRootPC(frame: frame, entry: entry)
        let thirdSemis: Int
        switch frame.mode {
        case .Ionian, .Mixolydian, .Lydian: thirdSemis = 4
        default:                            thirdSemis = 3
        }
        let callPCs:   [Int] = [rootPC, (rootPC+2)%12, (rootPC+thirdSemis)%12, (rootPC+7)%12]
        let answerPCs: [Int] = [(rootPC+7)%12, (rootPC+thirdSemis)%12, (rootPC+2)%12, rootPC]
        let pcs        = (phase == 0) ? callPCs   : answerPCs
        let steps      = (phase == 0) ? [0, 2, 4, 8]            : [0, 2, 6, 8]
        let durs: [Int]     = (phase == 0) ? [2, 2, 2, 2]       : [2, 2, 2, 4]
        let vels: [UInt8]   = (phase == 0) ? [88, 80, 76, 80]   : [84, 76, 72, 86]
        var events: [MIDIEvent] = []
        var prevNote: UInt8? = nil
        for i in 0..<pcs.count {
            let note = nearestMIDI(pc: pcs[i], bounds: bounds, prevNote: prevNote)
            events.append(MIDIEvent(stepIndex: barStart + steps[i], note: note, velocity: vels[i], durationSteps: durs[i]))
            prevNote = note
        }
        return events
    }

    // MARK: - MOT-LD1-015: Arcade Riff — 2-bar ascending staccato motif (Carpenter Brut / arcade riff-as-ostinato)
    // A 4–6 note motif at 8th-note spacing (dur=1 staccato). Ascending by 3rds primarily.
    // Repeats every 2 bars; shifts up by P4 (5 semitones) once after 8–12 bars for an energy-boost.
    // Register MIDI 64–79. Arcade lead pool weight: 22%.

    private static func lead1ArcadeRiff(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        if intensity == .low                         { return [] }
        if intensity == .medium && bar % 4 == 3     { return [] }
        var events: [MIDIEvent] = []
        let bounds = RegisterBounds(low: 64, high: 79)
        let rootPC  = chordRootPC(frame: frame, entry: entry)
        // Energy shift: bars 8–11 push the motif up by 5 semitones (P4)
        let shiftSemis = (bar >= 8 && bar < 12) ? 5 : 0
        // Bar-alternating pattern: bar A = ascending riff, bar B = riff from P5
        let barPhase = bar % 2
        let basePC: Int
        if barPhase == 0 {
            basePC = (rootPC + shiftSemis) % 12
        } else {
            basePC = (rootPC + 7 + shiftSemis) % 12  // start from P5
        }
        // 4-note motif at 8th-note spacing. Every 8 bars the direction reverses (descending)
        // to break up long identical runs — 6 bars ascending, 2 bars descending, repeat.
        let thirdSemis: Int
        switch frame.mode {
        case .Ionian, .Mixolydian, .Lydian: thirdSemis = 4
        default:                            thirdSemis = 3
        }
        let ascending: [Int] = [0, 2, thirdSemis, 7]
        let motifOffsets = (bar % 8 >= 6) ? ascending.reversed() : ascending
        var prevNote: UInt8? = nil
        for (i, offset) in motifOffsets.enumerated() {
            let pc   = (basePC + offset) % 12
            let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: prevNote)
            let step = i * 2
            let vel: UInt8 = i == 0 ? 90 : 80
            events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: vel, durationSteps: 1))
            prevNote = note
        }
        return events
    }

    // MARK: - MOT-LD1-016: Machine Answer — 4-bar symmetric call-and-answer (mechanical mirror)
    // Bars 1–2: ascending "call" figure (3rds + P4/P5). Bars 3–4: same notes reversed (the "answer").
    // Perfect symmetry = machine aesthetic; unlike organic call-and-answer where response varies.
    // Register MIDI 60–76. Duration 60% of step (slightly more breath than Arcade Riff). Arcade pool weight: 18%.

    private static func lead1MachineAnswer(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let bounds  = RegisterBounds(low: 60, high: 76)
        let rootPC  = chordRootPC(frame: frame, entry: entry)
        let thirdSemis: Int
        switch frame.mode {
        case .Ionian, .Mixolydian, .Lydian: thirdSemis = 4
        default:                            thirdSemis = 3
        }
        // Rotate base pitch class every 8 bars (root → 3rd → 5th) to prevent long same-chord-window runs.
        let baseShifts = [0, thirdSemis, 7]
        let basePC = (rootPC + baseShifts[(bar / 8) % 3]) % 12
        // 4-note call figure — ascending arc from rotated base
        let callOffsets: [Int] = [0, thirdSemis, 7, 12]
        let callPCs = callOffsets.map { (basePC + $0) % 12 }
        let callNotes: [UInt8] = callPCs.enumerated().map { i, pc in
            nearestMIDI(pc: pc, bounds: bounds, prevNote: i > 0 ? nearestMIDI(pc: callPCs[i-1], bounds: bounds, prevNote: nil) : nil)
        }
        let answerNotes = callNotes.reversed()  // mirror = the machine answer
        let callOrAnswer = (bar % 4 < 2) ? callNotes : Array(answerNotes)
        for (i, note) in callOrAnswer.enumerated() {
            let step = i * 4  // quarter-note spacing: steps 0, 4, 8, 12
            let vel: UInt8 = i == 0 ? 88 : 78
            events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: vel, durationSteps: 2))
        }
        return events
    }

    // MARK: - MOT-LD1-017: Pentatonic Blitz — 16th-note burst (chiptune fast-arp, BPM ≥ 143 only)
    // 1-bar cycle: 4 ascending 16ths (root–M2–P4–P5), 2 rests, 4 descending 16ths (P5–P4–M2–root), 2 rests.
    // At 150 BPM: ~5 notes per second in the bursts (8th notes). Duration staccato. Register MIDI 67–84.
    // Only fired when frame.tempo ≥ 143 (enforced in generateLead1). Arcade lead pool weight: 15%.

    private static func lead1PentatonicBlitz(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity
    ) -> [MIDIEvent] {
        // Periodic breath breaks to prevent relentlessness:
        // 1-bar gap every 4 bars (bar % 4 == 3); extended to a 2-bar gap every 8 bars (bar % 8 == 6 adds the extra bar).
        // 8-bar cycle: ✓✓✓ _ ✓✓ _ _ → 5 active, 3 silent.
        if bar % 4 == 3 || bar % 8 == 6 { return [] }
        var events: [MIDIEvent] = []
        let bounds = RegisterBounds(low: 67, high: 84)
        let rootPC = chordRootPC(frame: frame, entry: entry)
        // Rotate arp base every 8 bars: root → 3rd → 5th → root…
        // Changes the pitch-class fingerprint so long chord windows don't stagnate.
        let thirdSemis = (frame.mode == .Ionian || frame.mode == .Mixolydian || frame.mode == .Lydian) ? 4 : 3
        let baseShifts = [0, thirdSemis, 7]
        let basePC = (rootPC + baseShifts[(bar / 8) % 3]) % 12
        // Ascending burst: base–M2–P4–P5 (pentatonic subset in any mode)
        let ascOffsets: [Int] = [0, 2, 5, 7]
        let ascNotes = ascOffsets.map { offset -> UInt8 in
            nearestMIDI(pc: (basePC + offset) % 12, bounds: bounds, prevNote: nil)
        }
        let descNotes = ascNotes.reversed()
        // Every 4 bars swap order (desc-then-asc) to vary the 1-bar repeating cycle.
        let firstBurst  = (bar % 4 >= 2) ? Array(descNotes) : ascNotes
        let secondBurst = (bar % 4 >= 2) ? ascNotes          : Array(descNotes)
        for (i, note) in firstBurst.enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + i * 2, note: note, velocity: 86, durationSteps: 2))
        }
        // Gap: steps 8–9 (rest)
        for (i, note) in secondBurst.prefix(3).enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + 10 + i * 2, note: note, velocity: 82, durationSteps: 2))
        }
        // Gap: steps 16+ (rest — breathing space before next bar)
        return events
    }

    // MARK: - MOT-LD1-018: Octave Bounce — Tempest 2000 octave-leap lead (highest Arcade pool weight)
    // The defining Tempest 2000 gesture: interval analysis showed octave as #1 interval by 5:1 margin.
    // 2-bar pattern: chord tone → jump up an octave → back down → neighboring chord tone → repeat.
    // The octave leap fires on every other 8th note — "bouncing ball" regularity reads as mechanical precision.
    // Register MIDI 55–79 (two octaves). Duration 55% of step. Arcade lead pool weight: 25%.

    private static func lead1OctaveBounce(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let loLow = 55; let loHigh = 67   // lower octave zone
        let hiLow = 67; let hiHigh = 79   // upper octave zone
        let rootPC = chordRootPC(frame: frame, entry: entry)
        let thirdSemis: Int
        switch frame.mode {
        case .Ionian, .Mixolydian, .Lydian: thirdSemis = 4
        default:                            thirdSemis = 3
        }
        let fifthPC = (rootPC + 7) % 12
        let thirdPC = (rootPC + thirdSemis) % 12
        // Two alternating chord tones: root and 3rd or root and 5th
        let toneA = bar % 4 < 2 ? rootPC : thirdPC
        let toneB = bar % 4 < 2 ? thirdPC : fifthPC
        // Pattern: lo–hi–lo–lo2   lo–hi–lo–lo2 (toneB on 4th position for color)
        let lowA  = nearestMIDI(pc: toneA, bounds: RegisterBounds(low: loLow, high: loHigh), prevNote: nil)
        let highA = nearestMIDI(pc: toneA, bounds: RegisterBounds(low: hiLow, high: hiHigh), prevNote: nil)
        let lowB  = nearestMIDI(pc: toneB, bounds: RegisterBounds(low: loLow, high: loHigh), prevNote: nil)
        // Standard: 8 8th-note positions per bar: lo, hi, lo, loB, lo, hi, lo, loB.
        // Every 8 bars (bar % 8 >= 6): half density — only quarter-note positions (0, 4, 8, 12).
        // Keeps the octave-bounce character while giving breathing room after a long run.
        let fullPattern: [(Int, UInt8)] = [
            (0,  lowA), (2,  highA), (4,  lowA), (6,  lowB),
            (8,  lowA), (10, highA), (12, lowA), (14, lowB)
        ]
        let sparsePattern: [(Int, UInt8)] = [
            (0,  lowA), (4,  highA), (8,  lowA), (12, highA)
        ]
        let pattern = (bar % 8 >= 6) ? sparsePattern : fullPattern
        for (step, note) in pattern {
            let vel: UInt8 = (step == 2 || step == 10 || step == 4 || step == 12) ? 92 : 82
            events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: vel, durationSteps: 1))
        }
        return events
    }

    // MARK: - MOT-LD2-010: Blip — ultra-sparse accent stabs (2 bars active / 2 bars silent)
    // On active bars: root at step 0, P5 at step 8 — two staccato 8th-note accents per bar.
    // 50% of bars are silent (bar % 4 >= 2), giving Lead 1 plenty of uncontested space.
    // Register MIDI 60–72. Used by coordination layer when Lead 1 is a dense arp rule.

    private static func lead2Blip(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool
    ) -> [MIDIEvent] {
        if isIntroOutro { return [] }
        guard bar % 4 < 2 else { return [] }
        let rootPC  = chordRootPC(frame: frame, entry: entry)
        let fifthPC = (rootPC + 7) % 12
        let root  = nearestMIDI(pc: rootPC,  bounds: RegisterBounds(low: 60, high: 72), prevNote: nil)
        let fifth = nearestMIDI(pc: fifthPC, bounds: RegisterBounds(low: 60, high: 72), prevNote: root)
        return [
            MIDIEvent(stepIndex: barStart + 0, note: root,  velocity: 80, durationSteps: 1),
            MIDIEvent(stepIndex: barStart + 8, note: fifth, velocity: 68, durationSteps: 1),
        ]
    }

    // MARK: - MOT-LD2-009: Bounce Arp — sparse quarter-note bounce between root and P5/oct
    // Four notes per bar at quarter-note spacing (steps 0/4/8/12): root → P5 → root → oct.
    // Half the density of Gate Arp (8th notes) — sits lightly under fast Lead 1 rules.
    // 4-bar on / 1-bar rest. Staccato (dur=1). Register MIDI 60–72.

    private static func lead2BounceArp(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool
    ) -> [MIDIEvent] {
        if isIntroOutro { return [] }
        guard bar % 5 != 4 else { return [] }  // 4-on / 1-off
        var events: [MIDIEvent] = []
        let rootPC = chordRootPC(frame: frame, entry: entry)
        let thirdSemis: Int
        switch frame.mode {
        case .Ionian, .Mixolydian, .Lydian: thirdSemis = 4
        default:                            thirdSemis = 3
        }
        // Rotate base every 8 bars: root → 3rd → 5th → root…
        let baseShifts = [0, thirdSemis, 7]
        let basePC  = (rootPC + baseShifts[(bar / 8) % 3]) % 12
        let baseFifthPC = (basePC + 7) % 12
        let loLow = 60; let loHigh = 68
        let hiLow = 67; let hiHigh = 72
        let loNote  = nearestMIDI(pc: basePC,      bounds: RegisterBounds(low: loLow, high: loHigh), prevNote: nil)
        let midNote = nearestMIDI(pc: baseFifthPC, bounds: RegisterBounds(low: loLow, high: loHigh), prevNote: nil)
        let hiNote  = nearestMIDI(pc: basePC,      bounds: RegisterBounds(low: hiLow, high: hiHigh), prevNote: nil)
        // base → base+P5 → base → base+oct (quarter-note bounce)
        let pattern: [(Int, UInt8, UInt8)] = [
            (0, loNote, 78), (4, midNote, 68), (8, loNote, 74), (12, hiNote, 68)
        ]
        for (step, note, vel) in pattern {
            events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: vel, durationSteps: 1))
        }
        return events
    }

    // MARK: - MOT-LD1-019: Triad Climb — ascending broken-chord arpeggios that build over a 4-bar phrase
    // Each bar plays root → 3rd → 5th → oct at 8th-note spacing (steps 0/2/4/6), rest on 8–15.
    // Every 2 bars the base pitch shifts up by a third, so the figure climbs across the phrase.
    // Distinct from Octave Bounce (which oscillates vertically on two fixed pitches) — this moves
    // forward through the chord. Register MIDI 64–79. Staccato (dur=1). Arcade pool weight: 18%.
    // Intensity: low = silent; medium = 3-bars-on / 1-off (bar % 4 == 3 rests); high = every bar.

    private static func lead1TriadClimb(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        if intensity == .low                          { return [] }
        if intensity == .medium && bar % 4 == 3      { return [] }
        var events: [MIDIEvent] = []
        let bounds = RegisterBounds(low: 64, high: 79)
        let rootPC = chordRootPC(frame: frame, entry: entry)
        let thirdSemis: Int
        switch frame.mode {
        case .Ionian, .Mixolydian, .Lydian: thirdSemis = 4
        default:                            thirdSemis = 3
        }
        // Shift up by a third every 2 bars across a 4-bar cycle
        let shiftSemis = ((bar % 4) / 2) * thirdSemis
        let basePC = (rootPC + shiftSemis) % 12
        let motifOffsets: [Int] = [0, thirdSemis, 7, 12]
        // Duration mode: 40% all 8th (dur=2), 20% alternating 2/1, 20% staccato (dur=1), 20% run-and-land (last note dur=4).
        let roll = rng.nextDouble()
        let bodyDur  = roll < 0.80 ? 2 : 1          // 8th or staccato for first 3 notes
        let lastDur  = roll < 0.20 ? 4 : bodyDur    // 20%: held octave resolution
        let altMode  = roll >= 0.60 && roll < 0.80  // 20%: alternating dur per note
        var prevNote: UInt8? = nil
        for (i, offset) in motifOffsets.enumerated() {
            let pc   = (basePC + offset) % 12
            let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: prevNote)
            let vel: UInt8 = i == 0 ? 90 : (i == 3 ? 84 : 78)
            let dur: Int
            if i == 3 {
                dur = lastDur
            } else if altMode {
                dur = i % 2 == 0 ? 2 : 1
            } else {
                dur = bodyDur
            }
            events.append(MIDIEvent(stepIndex: barStart + i * 2, note: note, velocity: vel, durationSteps: dur))
            prevNote = note
        }
        return events
    }

    // MARK: - MOT-LD2-008: Gate Arp — classic analog arpeggiator feel (root → P5 → oct → P5)
    // 8th-note cycle: root, fifth, octave(root), fifth — half the note density of Arcade Arp.
    // Sits lower in the mix (MIDI 55–72), creating space for Lead 1 to cut through.
    // 4-bar on / 1-bar rest cycle (same as LD2-007). Fully staccato (dur=1).
    // Hypnotic churning quality — more Boards of Canada analogue arp than chiptune 16th grid.
    // Arcade LD2 pool: 35% chance alongside LD2-007's 35%.

    private static func lead2GateArp(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool
    ) -> [MIDIEvent] {
        if isIntroOutro { return [] }
        guard bar % 5 != 4 else { return [] }  // 4-on / 1-off
        var events: [MIDIEvent] = []
        let rootPC  = chordRootPC(frame: frame, entry: entry)
        let fifthPC = (rootPC + 7) % 12
        let thirdSemis = (frame.mode == .Ionian || frame.mode == .Mixolydian || frame.mode == .Lydian) ? 4 : 3
        let thirdPC = (rootPC + thirdSemis) % 12
        let loLow = 55; let loHigh = 65
        let hiLow = 65; let hiHigh = 72
        // Rotate the 3rd into the cycle every 8 bars — changes pitch-class fingerprint while
        // preserving the analog arp feel. Three phases on an 8-bar clock:
        //   0–7:  [root, fifth, oct, fifth]  — pure root/fifth
        //   8–15: [root, third, oct, fifth]  — third replaces first fifth
        //   16–23:[root, fifth, oct, third]  — third replaces last fifth
        let phase8 = (bar / 8) % 3
        let cyclePCs: [Int]
        switch phase8 {
        case 1:  cyclePCs = [rootPC, thirdPC, rootPC, fifthPC]
        case 2:  cyclePCs = [rootPC, fifthPC, rootPC, thirdPC]
        default: cyclePCs = [rootPC, fifthPC, rootPC, fifthPC]
        }
        let cycleHigh: [Bool] = [false, false, true, false]
        let phaseStart = (bar % 5) * 8  // 8 8th-note positions per bar; continuous across bars
        for i in 0..<8 {
            let posInCycle = (phaseStart + i) % 4
            let pc    = cyclePCs[posInCycle]
            let isHi  = cycleHigh[posInCycle]
            let note  = nearestMIDI(pc: pc, bounds: RegisterBounds(low: isHi ? hiLow : loLow,
                                                                    high: isHi ? hiHigh : loHigh), prevNote: nil)
            let vel: UInt8 = posInCycle == 0 ? 78 : 68
            events.append(MIDIEvent(stepIndex: barStart + i * 2, note: note, velocity: vel, durationSteps: 1))
        }
        return events
    }

    // MARK: - Lead 1 rule pools

    /// Picks a new LD1 rule consuming one RNG draw (called twice in generateLead1 for determinism).
    private static func pickLd1Rule(rng: inout SeededRNG, noir: Bool = false, arcade: Bool = false) -> String {
        if noir {
            // Noir: sparse, atmospheric leads dominate — long-note anchor, solo phrases, cold chord texture.
            // MOT-LD1-007 (Vanishing Solo) excluded: its major-key melodic arc feels tonally out of place
            // even with minor-scale adjustment.
            // The hook rules MOT-LD1-006 Model riff and MOT-LD1-001 Hallogallo hook hold 4% each.
            let rules:   [String] = ["MOT-LD1-006","MOT-LD1-008","MOT-LD1-001","MOT-LD1-005","MOT-LD1-009","MOT-LD1-010","MOT-LD1-011","MOT-LD1-012","MOT-LD1-013","MOT-LD1-014"]
            let weights: [Double] = [0.04,         0.04,         0.04,         0.04,         0.11,         0.17,         0.17,         0.10,         0.14,         0.15]
            return rules[rng.weightedPick(weights)]
        }
        if arcade {
            // Arcade: staccato mechanical leads dominant. Arpeggio rules 018/019 together ~37% of picks.
            // 020 (Synth Hook) is melodic but not an arp — gives Bass/Lead 2 full weights via coordination layer.
            // 017 (Pentatonic Blitz) fires only when BPM ≥ 143 — handled inside the bar generator.
            // The hook rules MOT-LD1-001 Hallogallo hook and MOT-LD1-002 Radioactive riff hold 3% and 2%.
            let rules:   [String] = ["MOT-LD1-018","MOT-LD1-019","MOT-LD1-015","MOT-LD1-016","MOT-LD1-020","MOT-LD1-017","MOT-LD1-005","MOT-LD1-001","MOT-LD1-002"]
            let weights: [Double] = [0.17,          0.18,          0.17,          0.13,          0.13,          0.14,          0.03,          0.03,          0.02]
            return rules[rng.weightedPick(weights)]
        }
        // 005 Call and answer sits at 0.11. It is the most recognisable shape in the pool, and
        // because bRule reuses aRule 70% of the time a rule that wins usually carries the whole
        // song, so a larger share registers as more frequent than it is.
        //
        // The transcription hook rules MOT-LD1-001 Hallogallo hook, 002 Radioactive riff,
        // 003 Tour de France riff and 006 Model riff hold 56% of the pool.
        let rules:   [String] = ["MOT-LD1-001", "MOT-LD1-002", "MOT-LD1-003", "MOT-LD1-004", "MOT-LD1-005", "MOT-LD1-006", "MOT-LD1-007", "MOT-LD1-008"]
        let weights: [Double] = [0.15,          0.14,          0.15,          0.11,          0.11,          0.12,          0.12,          0.10]
        return rules[rng.weightedPick(weights)]
    }

    // MARK: - Shared helpers

    // I: Pre-computed rest windows for Lead 1 — deliberate 4–8 bar silent stretches in body
    // sections. Decided from seed so silences are structural and repeatable, not per-bar noise.
    static func buildRestBars(entryBar: Int, totalBars: Int, rng: inout SeededRNG, arcade: Bool = false) -> Set<Int> {
        var restBars = Set<Int>()
        let bodyStart = entryBar
        let bodyEnd   = max(bodyStart, totalBars - 8)
        let bodyLen   = bodyEnd - bodyStart
        guard bodyLen >= 8 else { return restBars }
        // One window per ~22 bars of body, rather than one or two for a whole song. A fixed
        // count meant a long song breathed no more often than a short one: a 112-bar song got
        // a single gap and the lead ran 19 bars without stopping.
        let numWindows = Swift.max(1, Swift.min(6, bodyLen / 22)) + rng.nextInt(upperBound: 2)
        // Laid out one per slot so they spread across the song instead of clustering, the same
        // reason MOT-LD1-022's statements are slotted.
        let slot = Swift.max(1, bodyLen / numWindows)
        for w in 0..<numWindows {
            let restLen  = 4 + rng.nextInt(upperBound: arcade ? 2 : 5)  // Arcade: 4–5 bars, Base: 4–8 bars
            let slotStart = bodyStart + w * slot
            // Guarantee at least 8 active bars before the first rest window.
            let floorBar = w == 0 ? Swift.min(bodyStart + 8, bodyEnd - restLen) : slotStart
            let ceilBar  = Swift.min(slotStart + slot - restLen, bodyEnd - restLen)
            guard ceilBar > floorBar else { continue }
            let restStart = floorBar + rng.nextInt(upperBound: ceilBar - floorBar)
            for rb in restStart..<Swift.min(restStart + restLen, bodyEnd) {
                restBars.insert(rb)
            }
        }
        return restBars
    }

    private static func densityForIntensity(_ intensity: SectionIntensity) -> Double {
        switch intensity {
        case .low:    return 0.25
        case .medium: return 0.55
        case .high:   return 0.80
        }
    }

    /// Pitch class of the current chord root (0–11).
    private static func chordRootPC(frame: GlobalMusicalFrame, entry: TonalGovernanceEntry) -> Int {
        (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
    }

    private static func velocityForIntensity(_ intensity: SectionIntensity, rng: inout SeededRNG) -> UInt8 {
        let base: Int
        switch intensity {
        case .low:    base = 60
        case .medium: base = 75
        case .high:   base = 90
        }
        return UInt8(base + rng.nextInt(upperBound: 15))
    }

    /// D: Nearest-octave MIDI note selection — picks the in-bounds octave closest to prevNote.
    /// Falls back to middle of register when prevNote is nil.
    private static func nearestMIDI(pc: Int, bounds: RegisterBounds, prevNote: UInt8?) -> UInt8 {
        var candidates: [Int] = []
        for oct in 0...9 {
            let midi = oct * 12 + pc
            if midi >= bounds.low && midi <= bounds.high { candidates.append(midi) }
        }
        guard !candidates.isEmpty else { return UInt8(bounds.low) }
        if let prev = prevNote {
            let prevInt = Int(prev)
            return UInt8(candidates.min(by: { abs($0 - prevInt) < abs($1 - prevInt) })!)
        } else {
            let mid = (bounds.low + bounds.high) / 2
            return UInt8(candidates.min(by: { abs($0 - mid) < abs($1 - mid) })!)
        }
    }

    /// Picks a chord-tone or scale-tension pitch class, then uses nearestMIDI for octave selection.
    private static func pickNoteNearest(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        trackIndex: Int, prevNote: UInt8?, rng: inout SeededRNG
    ) -> UInt8 {
        // DETERMINISM: sorted(), not Array(). These are Sets, and a Set's iteration order
        // differs between runs even for identical contents, so indexing the raw Array with a
        // seeded draw returned a different pitch each time while the rhythm — driven by the
        // same RNG stream — stayed identical.
        let pool: [Int] = (rng.nextDouble() < 0.80)
            ? entry.chordWindow.chordTones.sorted()
            : entry.chordWindow.scaleTensions.sorted()
        guard !pool.isEmpty else {
            return frame.midiNote(degree: "1", oct: 0, trackIndex: trackIndex)
        }
        let pc     = pool[rng.nextInt(upperBound: pool.count)]
        let bounds = kRegisterBounds[trackIndex] ?? RegisterBounds(low: 60, high: 96)
        return nearestMIDI(pc: pc, bounds: bounds, prevNote: prevNote)
    }

    // MARK: - LD1-007 / LD1-008: Solo placement

    /// MOT-LD1-007 Vanishing Solo and MOT-LD1-008 Visiting Solo: the rules that play a solo window.
    static func isSoloRule(_ id: String) -> Bool { id == "MOT-LD1-007" || id == "MOT-LD1-008" }

    /// One bar of the full solo, by solo bar number; the shorter returns use the same bars.
    private static func soloBarEvents(rule: String, soloBar: Int, barStart: Int,
                                      frame: GlobalMusicalFrame) -> [MIDIEvent] {
        rule == "MOT-LD1-007"
            ? generateGuitarSolo007(soloBar: soloBar, barStart: barStart, frame: frame)
            : generateMoogSolo008(soloBar: soloBar, barStart: barStart, frame: frame)
    }

    /// Returns the bar range for the solo window, always within the A section.
    /// Never uses the B section — the bar loop applies bRule there, which would silence the solo.
    /// passBodyBars: when set (pass-regen context), constrains the solo to land within the
    /// first passBodyBars of the body so it is always audible in the evolved bars, regardless
    /// of how long the A section is.
    private static func pickSoloStartBar(
        structure: SongStructure, soloLength: Int, rng: inout SeededRNG,
        passBodyBars: Int? = nil
    ) -> Range<Int> {
        if let a = structure.sections.first(where: { $0.label == .A }),
           a.lengthBars >= soloLength + 8 {
            let earliest: Int
            let latest: Int
            if let maxBars = passBodyBars {
                // Pass-regen: place anywhere in the first maxBars of the body so the solo
                // always falls within the pass window, regardless of A section length.
                earliest = a.startBar
                latest   = a.startBar + maxBars - soloLength
            } else {
                // Normal mode: the full solo starts between bars 24 and 48 (1-based), so the
                // shorter returns have room to follow it and the song is not half over before
                // the solo is heard. Short A sections are clamped so the solo still fits.
                let hardLatest = a.startBar + a.lengthBars - soloLength - 4
                latest   = min(47, hardLatest)
                earliest = min(max(a.startBar + 8, 23), latest)
            }
            let clampedLatest = max(latest, earliest)
            let start = clampedLatest > earliest
                ? earliest + rng.nextInt(upperBound: clampedLatest - earliest)
                : earliest
            return start ..< start + soloLength
        }
        // Fallback: place near the first body bar
        let bodyStart = structure.bodySections.first?.startBar ?? 0
        return bodyStart ..< bodyStart + soloLength
    }

    // MARK: - Shorter returns of the solo

    /// Bars of the full solo that make each shorter version, by length in bars. Every bar is one of
    /// the full solo's own, so the short version is the same solo cut down: Vanishing solo keeps
    /// its motif and its peak and ends on the final root; Visiting solo keeps its opening hold, its
    /// circling phrase and its arpeggio and ends on the low root. Two orderings per length.
    private static let shortSoloBars: [String: [Int: [[Int]]]] = [
        "MOT-LD1-007": [4: [[1, 2, 4, 9], [1, 3, 5, 9]],
                        5: [[1, 2, 3, 5, 9], [1, 2, 3, 6, 9]],
                        6: [[0, 1, 2, 3, 6, 9], [1, 2, 3, 5, 8, 9]]],
        "MOT-LD1-008": [4: [[0, 1, 5, 8], [1, 4, 6, 8]],
                        5: [[0, 1, 4, 6, 8], [1, 4, 5, 6, 8]],
                        6: [[0, 1, 4, 5, 6, 8], [1, 3, 4, 5, 7, 8]]],
    ]

    /// One or two shorter versions of the solo, 4 to 6 bars each, placed in the body at least 12
    /// bars from the full solo and from each other where the song has room, otherwise 8. The
    /// further a window is from the others the likelier it is. They stay out of the breakdown
    /// windows, the intro and the last four body bars, and play a little softer than the full
    /// solo. Draws for those come after everything else in Lead 1, so the rest of the song is
    /// unchanged.
    ///
    /// Then any stretch of the body longer than `maxLead1SilentBars` with no solo in it, before,
    /// between or after the windows, gets a further short version near its middle, up to six
    /// more, so Lead 1 never leaves the song empty for long. Each is a different cut or ordering
    /// from the one before it and, where the table allows, a different length from its neighbour,
    /// so it reads as the solo coming back changed and not as a copy.

    private static func shortSoloReprises(
        rule: String, main: Range<Int>, structure: SongStructure, frame: GlobalMusicalFrame,
        avoidBars: Set<Int>, rng: inout SeededRNG
    ) -> (events: [MIDIEvent], ranges: [Range<Int>]) {
        guard let table = shortSoloBars[rule] else { return ([], []) }
        let bodyBars = Set(structure.bodySections.flatMap { Array($0.startBar..<$0.endBar) })
        guard let bodyStart = bodyBars.min(), let bodyEnd = bodyBars.max().map({ $0 + 1 }) else { return ([], []) }
        let wanted = rng.nextDouble() < 0.60 ? 2 : 1
        var ranges: [Range<Int>] = []
        var events: [MIDIEvent] = []
        var lastChoice = -1

        func place(start: Int, length: Int) {
            guard let options = table[length] else { return }
            var choice = rng.nextInt(upperBound: options.count)
            if choice == lastChoice { choice = (choice + 1) % options.count }
            lastChoice = choice
            for (i, soloBar) in options[choice].enumerated() {
                let barStart = (start + i) * 16
                let bar = soloBarEvents(rule: rule, soloBar: soloBar, barStart: barStart, frame: frame)
                events += bar.map {
                    MIDIEvent(stepIndex: $0.stepIndex, note: $0.note,
                              velocity: UInt8(max(40, Int($0.velocity) - 6)), durationSteps: $0.durationSteps)
                }
            }
            ranges.append(start..<(start + length))
        }

        for _ in 0..<wanted {
            let length = [4, 5, 6][rng.weightedPick([0.30, 0.40, 0.30])]
            let all = [main] + ranges
            func gap(_ start: Int) -> Int {
                all.map { max(start - $0.upperBound, $0.lowerBound - (start + length)) }.min() ?? 0
            }
            let starts = stride(from: bodyStart, through: bodyEnd - 4 - length, by: 2).filter { s in
                (s..<(s + length)).allSatisfy { bodyBars.contains($0) && !avoidBars.contains($0) }
                    && gap(s) >= 8
            }
            let spaced = starts.filter { gap($0) >= 12 }
            let pool = spaced.isEmpty ? starts : spaced
            guard !pool.isEmpty else { break }
            let total = Double(pool.map(gap).reduce(0, +))
            let start = pool[rng.weightedPick(pool.map { Double(gap($0)) / total })]
            guard table[length] != nil else { break }
            place(start: start, length: length)
        }

        // Fill the long silences. The widest stretch of the body with no solo in it, before the
        // full solo, between two windows or after the last, that is longer than the cap gets a
        // window near its middle. The first stretch runs from the body's first bar, so a full solo
        // that arrives late is not preceded by a long silence.
        for _ in 0..<6 {
            let windows = ([main] + ranges).sorted { $0.lowerBound < $1.lowerBound }
            let edges = [(from: bodyStart, to: windows[0].lowerBound)]
                + windows.enumerated().map { i, w in
                    (from: w.upperBound, to: i + 1 < windows.count ? windows[i + 1].lowerBound : bodyEnd)
                }
            guard let span = edges.filter({ $0.to - $0.from > maxLead1SilentBars })
                .max(by: { $0.to - $0.from < $1.to - $1.from }) else { break }
            let neighbour = windows.first { $0.upperBound == span.from }.map { $0.count }
                ?? windows.first { $0.lowerBound == span.to }.map { $0.count }
            var lengths = [4, 5, 6]
            if let n = neighbour, lengths.count > 1 { lengths.removeAll { $0 == n } }
            let length = lengths[rng.nextInt(upperBound: lengths.count)]
            let mid = Double(span.from + span.to) / 2
            // A window sits 8 bars clear of its neighbours, 4 where the breakdowns leave no room.
            var start: Int? = nil
            for margin in [8, 4] {
                let starts = stride(from: bodyStart, through: bodyEnd - 4 - length, by: 2).filter { s in
                    s >= span.from + margin
                        && s + length <= span.to - (span.to == bodyEnd ? 4 : margin)
                        && (s..<(s + length)).allSatisfy { bodyBars.contains($0) && !avoidBars.contains($0) }
                }
                start = starts.min(by: {
                    abs(Double($0) + Double(length) / 2 - mid) < abs(Double($1) + Double(length) / 2 - mid)
                })
                if start != nil { break }
            }
            guard let start else { break }
            place(start: start, length: length)
        }
        return (events, ranges.sorted { $0.lowerBound < $1.lowerBound })
    }

    // MARK: - Solo note builder (shared by LD1-007 and LD1-008)

    /// Builds a single MIDIEvent for a scripted solo. `offset` is in semitones from `kr`;
    /// the note is clamped to `bounds`. Both solos use the same construction — extracted
    /// here so the logic lives in one place.
    private static func soloNote(_ offset: Int, vel: Int, step: Int, dur: Int,
                                  barStart: Int, kr: Int, bounds: RegisterBounds) -> MIDIEvent {
        MIDIEvent(stepIndex: barStart + step,
                  note: UInt8(max(bounds.low, min(bounds.high, kr + offset))),
                  velocity: UInt8(vel), durationSteps: dur)
    }

    // MARK: - LD1-007: Vanishing Solo
    // 10-bar solo derived from Vanishing Point guitar solo (Electric Buddha Band).
    // Uses mode-aware intervals: root, mode-3rd, P4, P5, mode-7th.
    // P4 (+5) and P5 (±7) are mode-independent; the 3rd and 7th are read from the mode
    // so the solo stays in-scale for Ionian/Mixolydian (major 3rd/7th) as well as
    // Aeolian/Dorian (minor 3rd, minor 7th).
    // Phase 1 (bars 0–3): active eighth/quarter motion, primary 5-note motif × 2
    // Phase 2 (bars 4–6): wind-down, half-note motion, descending
    // Phase 3 (bars 7–9): dissolution, 1–3 notes/bar, final single root on beat 2 of bar 9

    private static func generateGuitarSolo007(soloBar: Int, barStart: Int, frame: GlobalMusicalFrame) -> [MIDIEvent] {
        let bounds  = kRegisterBounds[kTrackLead1]!
        let kr      = 60 + keySemitone(frame.key)  // root in octave 4

        // Mode-aware 3rd and 7th so the solo stays in-scale for major modes.
        // frame.mode.intervals is a 7-element array: [root, M2, 3rd, 4th, 5th, 6th, 7th].
        let t = frame.mode.intervals.count >= 3 ? frame.mode.intervals[2] : 3  // mode 3rd above root
        let b = (frame.mode.intervals.count >= 7 ? frame.mode.intervals[6] : 10) - 12 // mode 7th below root

        // Named pitch offsets (all relative to kr, clamped to register)
        func n(_ offset: Int, vel: Int, step: Int, dur: Int) -> MIDIEvent {
            soloNote(offset, vel: vel, step: step, dur: dur, barStart: barStart, kr: kr, bounds: bounds)
        }

        switch soloBar {
        case 0: // Pickup — enters on beat 3; P5(low) then mode-3rd
            return [n(-5, vel:84, step:8,  dur:4),
                    n( t, vel:67, step:12, dur:4)]

        case 1: // Primary motif: 3rd – 7th(low) – 3rd long – root – 3rd
            return [n( t, vel:66, step:0,  dur:2),
                    n( b, vel:62, step:2,  dur:2),
                    n( t, vel:62, step:4,  dur:4),
                    n( 0, vel:93, step:8,  dur:4),
                    n( t, vel:65, step:12, dur:4)]

        case 2: // Peak bar: brief 3rd – P5(high) peak – P5(low) drop – 7th(low)
            return [n( t, vel:63, step:2,  dur:2),
                    n( 7, vel:62, step:4,  dur:2),
                    n(-5, vel:86, step:8,  dur:4),
                    n( b, vel:81, step:12, dur:4)]

        case 3: // Primary motif reprise (verbatim of bar 1)
            return [n( t, vel:73, step:0,  dur:2),
                    n( b, vel:63, step:2,  dur:2),
                    n( t, vel:62, step:4,  dur:4),
                    n( 0, vel:96, step:8,  dur:5),
                    n( t, vel:77, step:12, dur:4)]

        case 4: // Wind-down: P5 brief – 3rd brief – 7th(low) held
            return [n( 7, vel:65, step:0, dur:2),
                    n( t, vel:63, step:2, dur:2),
                    n( b, vel:62, step:4, dur:8)]

        case 5: // Half-note motion: 7th(low) – root – 3rd
            return [n( b, vel:84, step:0,  dur:8),
                    n( 0, vel:93, step:8,  dur:4),
                    n( t, vel:93, step:12, dur:5)]

        case 6: // root(beat 2) – P5(low)
            return [n( 0, vel:93, step:4,  dur:7),
                    n(-5, vel:93, step:12, dur:5)]

        case 7: // Sparse: 3rd(beat 2) – root
            return [n( t, vel:77, step:4,  dur:5),
                    n( 0, vel:62, step:10, dur:6)]

        case 8: // Brief motion: 3rd – 7th(low) – P5(low) – 7th(low)
            return [n( t, vel:71, step:0,  dur:4),
                    n( b, vel:62, step:4,  dur:6),
                    n(-5, vel:72, step:10, dur:4),
                    n( b, vel:72, step:14, dur:5)]

        case 9: // Final: single root on beat 2
            return [n( 0, vel:74, step:4, dur:4)]

        default:
            return []
        }
    }

    // MARK: - LD1-008: Visiting Solo
    // 9-bar moog-style solo derived from Visitor from the Past (Electric Buddha Band).
    // Uses mode-aware intervals: root, M2, mode-3rd, P4, P5, mode-6th, mode-7th.
    // M2 (+2) and P4/P5 (±5, ±7) are mode-independent; 3rd and 6th are read from the mode
    // so the solo stays in-scale for all modes (e.g. M3 in Ionian, M6 in Dorian vs m6 in Aeolian).
    // Phase 1 (bars 0–1): root anchor + active circling eighth-note phrase
    // Phase 2 (bars 2–5): sparse long held notes + octave arpeggio motif (root–oct–2oct–oct)
    // Phase 3 (bars 6–8): terminal — stepwise descent, final low root

    private static func generateMoogSolo008(soloBar: Int, barStart: Int, frame: GlobalMusicalFrame) -> [MIDIEvent] {
        let bounds = kRegisterBounds[kTrackLead1]!
        let kr     = 60 + keySemitone(frame.key)

        // Mode-aware intervals: 3rd (index 2) and 6th (index 5).
        let t = frame.mode.intervals.count >= 3 ? frame.mode.intervals[2] : 3  // mode 3rd above root
        let s = frame.mode.intervals.count >= 6 ? frame.mode.intervals[5] : 9  // mode 6th above root

        func n(_ offset: Int, vel: Int, step: Int, dur: Int) -> MIDIEvent {
            soloNote(offset, vel: vel, step: step, dur: dur, barStart: barStart, kr: kr, bounds: bounds)
        }

        switch soloBar {
        case 0: // Root long hold + P5(low)/root eighth pickup at end
            return [n( 0, vel:80, step:0,  dur:12),
                    n(-5, vel:87, step:12, dur:2),
                    n( 0, vel:96, step:14, dur:2)]

        case 1: // Active circling phrase — P4→P5→3rd→root→6th→3rd→P4 in eighths
            return [n( 5, vel:73, step:0,  dur:2),
                    n( 7, vel:75, step:2,  dur:2),
                    n( t, vel:79, step:4,  dur:2),
                    n( 0, vel:86, step:6,  dur:2),
                    n( s, vel:60, step:8,  dur:4),
                    n( t, vel:75, step:12, dur:2),
                    n( 5, vel:79, step:14, dur:4)]

        case 2: // Root brief + P5(low) long hold (ties into bar 3)
            return [n( 0, vel:95, step:0, dur:4),
                    n(-5, vel:82, step:4, dur:20)]

        case 3: // P5(low) still sounding; root enters mid-bar
            return [n( 0, vel:94, step:8, dur:12)]

        case 4: // Octave arpeggio: root – root+12 – root+24(clamped) – root+12
            return [n(  0, vel:81, step:2, dur:2),
                    n( 12, vel:81, step:4, dur:2),
                    n( 24, vel:79, step:6, dur:4),
                    n( 12, vel:81, step:10, dur:2)]

        case 5: // Arpeggio echo: root+12 – root – root+12 held
            return [n( 12, vel:84, step:2, dur:4),
                    n(  0, vel:81, step:6, dur:2),
                    n( 12, vel:80, step:8, dur:8)]

        case 6: // Stepwise walk: root – M2 – mode-3rd – root
            return [n( 0, vel:82, step:0,  dur:4),
                    n( 2, vel:76, step:4,  dur:4),
                    n( t, vel:74, step:8,  dur:4),
                    n( 0, vel:88, step:12, dur:4)]

        case 7: // Long M2 whole bar
            return [n( 2, vel:50, step:0, dur:16)]

        case 8: // Terminal: dramatic low root long hold (one octave below)
            return [n(-12, vel:60, step:0, dur:16)]

        default:
            return []
        }
    }

    // MARK: - Kraftwerk sync lead

    /// Two measured shapes: short compact statements with proportionate silence, and long runs
    /// followed by very long silences. Both are announcements rather than melodies — the rest
    /// ratio lands 88-95% either way, and the silence is as much the material as the notes.
    /// Closed melodic cells measured from the Kraftwerk corpus by `tools/kraftwerk_lead_phrases.py`.
    ///
    /// Each is a list of semitone intervals, and each SUMS TO ZERO — the figure returns to the
    /// pitch it started on. That single property is what separates these lines from a random
    /// walk. The corpus leads are not stepwise (4-33% of motion is a step, and the median
    /// interval is a perfect fourth), so wide intervals are correct here; what makes them sound
    /// melodic rather than shrill is that every leap is answered.
    ///
    /// The first interval is the cell's own starting offset and is always 0; the rest are the
    /// moves. Counts are how often the figure recurs in its source track.
    private static let kraftwerkCells: [[Int]] = [
        [0,  5,  3, -8],    // The Robots "steampad" x204 — 4th up, m3 up, m6 back down
        [0,  9, -4, -5],    // Autobahn ch2 x20 — 6th up, then walked back down
        [0, -9,  5,  4],    // Autobahn ch2 x19 — the same figure inverted
        [0,  5, -2,  4, -7], // Computer Love ch0 x8
        [0,  9, -2, -2, -5], // Autobahn ch5
        [0,  6, -1, -5],    // Autobahn ch11
        [0, 12,  0, -12],   // Autobahn ch10 x77 — octave oscillation
        [0,  0, -5,  5],    // Autobahn ch6 x27 — repeated note, then a fourth away and back
        [0, -2,  0,  2],    // The Robots "steeldrm" x40 — neighbour-tone oscillation
        [0,  7, -2, -5],    // 5th up, step down, 4th home
        [0, -1, -3,  8, -4], // Autobahn ch8 — a descent, then a 6th back up
        [0,  4, -7,  3],    // Computer Love ch0 x12 — 3rd up, 5th down, back
    ]

    private static func kraftwerkLead1(
        ruleID: String,
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let totalSteps = frame.totalBars * 16

        /// Pitch classes usable at `step` — chord tones first, then scale tensions. Used to
        /// snap a realised cell into the harmony without changing its shape more than it must.
        func harmony(at step: Int) -> (chord: Set<Int>, usable: Set<Int>) {
            guard let entry = tonalMap.entry(atBar: step / 16) else { return ([], []) }
            let chord = entry.chordWindow.chordTones
            return (chord, chord.union(entry.chordWindow.scaleTensions))
        }

        /// Realises a cell as actual MIDI pitches, starting from `startPitch`.
        ///
        /// A cell is a list of semitone intervals whose running sum returns to zero, so the
        /// figure ends where it began and the line cycles in place. Every pitch is snapped to
        /// the nearest usable pitch class, which bends the shape slightly but never lets it
        /// drift: the anchor is re-derived from the ORIGINAL offset each time rather than from
        /// the previous snapped note, so snapping errors cannot accumulate.
        func realise(_ cell: [Int], from startPitch: Int, at step: Int,
                     low: Int, high: Int) -> [Int] {
            let usable = harmony(at: step).usable
            var offset = 0
            var out: [Int] = []
            // The final interval is the cell's return home, and the NEXT statement's first note
            // already supplies that pitch — emitting it too puts a repeated note at every seam.
            // `[0 +5 +3 -8]` is the three notes 0, +5, +8, cycling; not four ending where it
            // started. Bars of `82 81 77 82 | 82 81 77 82` were this, not the figure itself.
            for (i, interval) in cell.dropLast().enumerated() {
                if i > 0 { offset += interval }
                let raw = startPitch + offset
                var pitch = raw
                if !usable.isEmpty {
                    let pc = nearestScalePitchClass(((raw % 12) + 12) % 12, in: usable)
                    // Move to that pitch class by the shortest route, so the interval the cell
                    // asked for is close to the interval the ear hears.
                    let delta = ((pc - (((raw % 12) + 12) % 12)) + 18) % 12 - 6
                    // Snap only when the nearest usable note is close. Two notes snapping in
                    // opposite directions each shift their shared interval, so an unbounded
                    // snap can turn a cell's octave into a minor tenth — the shape matters
                    // more here than absolute diatonicism, and the harmony pool is wide enough
                    // that a distant nearest note means the raw pitch is the better answer.
                    if abs(delta) <= 2 { pitch = raw + delta }
                }
                // Fold by octaves rather than clamping. Clamping collapses every out-of-band
                // note onto the same edge pitch, which flattens the figure and breaks its
                // closure exactly where it is most exposed — the same failure as clamping a
                // pitch into a register band. An octave shift keeps the pitch class, so the
                // cell still reads as itself.
                while pitch > high { pitch -= 12 }
                while pitch < low  { pitch += 12 }
                out.append(Swift.max(low, Swift.min(high, pitch)))
            }
            return out
        }

        /// Varies a cell the way the corpus does, keeping it closed.
        ///
        /// The Robots states `[+5 +3 -8]` and then `[+2 -7 +5]`: intervals nudged, and the sum
        /// still zero. A change that does not compensate turns the figure into a random walk —
        /// which is exactly what the previous per-note walk produced, with a `+17` leap making
        /// up a tenth of the part and cells summing to +12, +14 and -15.
        func varyCell(_ cell: [Int], rng: inout SeededRNG) -> [Int] {
            guard cell.count >= 2 else { return cell }
            let roll = rng.nextDouble()
            if roll < 0.20 { return cell }                       // say it again, unchanged
            // Four entries minimum: index 0 is the starting offset and the last is the return
            // home, and the realiser emits neither, so both are off limits — a change there
            // moves nothing while its compensating partner still moves. That leaves at least
            // two interior intervals to trade between.
            guard cell.count >= 4 else { return cell }
            var c = cell
            // Nudge one interval and take the same amount back out of another, so the running
            // sum is unchanged and the figure still returns to its start.
            //
            // Only the interior intervals, for the reason above.
            let interior = c.count - 2                            // indices 1 ..< count-1
            let a = 1 + rng.nextInt(upperBound: interior)
            var b = 1 + rng.nextInt(upperBound: interior)
            if b == a { b = a == c.count - 2 ? 1 : a + 1 }
            let nudge = (rng.nextDouble() < 0.5 ? 1 : -1) * (rng.nextDouble() < 0.7 ? 1 : 2)
            c[a] += nudge
            c[b] -= nudge
            // A cell that has drifted past an octave in one move is no longer the same figure.
            guard c.allSatisfy({ abs($0) <= 12 }) else { return cell }
            return c
        }

        /// A start pitch for a statement: a chord tone, placed so the whole cell fits in the
        /// band, and biased low so the top of the band is somewhere the figure reaches rather
        /// than somewhere it sits.
        func anchor(for cell: [Int], at step: Int, low: Int, high: Int,
                    near: Int? = nil, rng: inout SeededRNG) -> Int {
            var offsets = [0]
            for interval in cell.dropFirst().dropLast() { offsets.append(offsets.last! + interval) }
            let lo = offsets.min() ?? 0, hi = offsets.max() ?? 0
            // Two semitones of headroom at each end: snapping to the nearest usable pitch
            // class can move a note either way, and a note that leaves the band has to be
            // folded, which costs the figure an octave jump it did not ask for.
            let margin = (high - low) > (hi - lo) + 4 ? 2 : 0
            let floorP = low + margin - lo, ceilP = high - margin - hi
            guard ceilP >= floorP else { return low - lo }
            let chord = harmony(at: step).chord
            var candidates = (floorP...ceilP).filter { chord.isEmpty || chord.contains(((($0 % 12) + 12) % 12)) }
            // Moving the figure mid-run is a transposition, so it has to travel a musical
            // distance. Left unbounded it picks any chord tone in the band, which across a
            // 19-semitone register reads as the line teleporting rather than moving — one run
            // dropped a fifteenth between two notes four steps apart.
            if let near {
                let close = candidates.filter { abs($0 - near) <= 7 }
                if !close.isEmpty { candidates = close }
            }
            guard !candidates.isEmpty else {
                let r = rng.nextDouble()
                return floorP + Int(Double(ceilP - floorP) * r * r)
            }
            let r = rng.nextDouble()
            return candidates[Swift.min(candidates.count - 1, Int(Double(candidates.count) * r * r))]
        }

        /// Shapes the end of every phrase: a note followed by real silence holds, and sometimes
        /// resolves onto the tonic.
        ///
        /// Both ideas are taken from the Chill lead, which ends a phrase by lengthening a short
        /// final note and by resolving it AGAINST the direction the phrase was travelling. A
        /// sequencer line does not need Chill's contrary-motion resolution, but it does need the
        /// other two: a statement that stops on a two-step blip before four bars of nothing
        /// sounds cut off rather than finished, and a figure that never lands on the tonic never
        /// sounds like it arrived anywhere.
        ///
        /// Applied as a pass over the finished events so both rules get it, and so it sees the
        /// actual gaps rather than the ones each rule intended.
        func shapePhraseEndings(_ input: [MIDIEvent], rng: inout SeededRNG,
                                low: Int, high: Int) -> [MIDIEvent] {
            var out = input.sorted { $0.stepIndex < $1.stepIndex }
            let tonicPC = ((frame.keySemitoneValue % 12) + 12) % 12

            // A pitch may be struck twice — several cells repeat their first note, which is
            // how Autobahn's `[+0 +0 -5]` figure goes — but a third strike in a row is a stuck
            // sequencer rather than a figure. Drop it and leave the space instead; the gap it
            // opens then feeds the phrase-ending pass below, so the pair before it holds.
            var deduped: [MIDIEvent] = []
            var sameRun = 0
            for e in out {
                if let previous = deduped.last, previous.note == e.note,
                   e.stepIndex - previous.stepIndex <= 8 {
                    sameRun += 1
                    if sameRun >= 2 { continue }
                } else {
                    sameRun = 0
                }
                deduped.append(e)
            }
            out = deduped
            // Clamp every note to end before the next begins. Long Run's legato branch can
            // draw a duration longer than the gap it sits in, which overlaps the next note —
            // on a lead meant to read as a single voice that muddies the line. The Chill lead
            // assigns its durations last for exactly this reason.
            for i in out.indices where i + 1 < out.count {
                // At least one step, so two notes landing on adjacent steps still yield a
                // playable note rather than being skipped and left overlapping.
                let room = Swift.max(1, out[i + 1].stepIndex - out[i].stepIndex - 1)
                if Int(out[i].durationSteps) > room {
                    out[i] = MIDIEvent(stepIndex: out[i].stepIndex, note: out[i].note,
                                       velocity: out[i].velocity, durationSteps: room)
                }
            }
            for i in out.indices {
                // The gap to whatever comes next — or to the end of the song for the last note.
                let nextStart = i + 1 < out.count ? out[i + 1].stepIndex : totalSteps
                let gap = nextStart - out[i].stepIndex
                guard gap >= 8 else { continue }          // less than half a bar is not an ending

                var note = Int(out[i].note)
                // Land on the tonic, but only where the harmony wants it and only if it is a
                // short move — a phrase ending should settle, not leap to get there.
                if rng.nextDouble() < 0.45, harmony(at: out[i].stepIndex).usable.contains(tonicPC) {
                    var candidate = note - ((((note - tonicPC) % 12) + 12) % 12)
                    if note - candidate > 6 { candidate += 12 }
                    // The move must not widen the interval arriving at this note. Resolving is
                    // a settling gesture; reaching the tonic by a bigger leap than the phrase
                    // was already making defeats it, and turns an ending into a lurch.
                    let approach = i > 0 && out[i].stepIndex - out[i - 1].stepIndex <= 8
                        ? Int(out[i - 1].note) : nil
                    let widens = approach.map { abs(candidate - $0) > Swift.max(12, abs(note - $0)) } ?? false
                    // Never resolve onto the pitch just played: the repetition guard has
                    // already run by this point, so a resolution that matches its neighbour
                    // reintroduces exactly the stuck note it removed.
                    let repeats = approach.map { $0 == candidate } ?? false
                    if candidate >= low, candidate <= high, abs(candidate - note) <= 5,
                       !widens, !repeats {
                        note = candidate
                    }
                }
                // Hold it — but a half note, not a whole one, and always followed by real rest.
                //
                // Filling the gap to within two steps made the ending a long tone rather than a
                // held note with air after it: durations ran to 20 steps and the median rest
                // that followed was 2. A half note either side is long enough to read as an
                // arrival, and reserving a quarter note of silence is what makes it land.
                let want = 6 + rng.nextInt(upperBound: 5)        // 6...10 steps, around a half note
                let dur  = Swift.max(2, Swift.min(want, gap - 4))
                out[i] = MIDIEvent(stepIndex: out[i].stepIndex, note: UInt8(note),
                                   velocity: out[i].velocity,
                                   durationSteps: dur)
            }

            // Final guarantee: nothing inside a phrase leaps more than an octave.
            //
            // The cells cap there by construction, but the passes that run afterwards can widen
            // an interval without meaning to — dropping a repeated note leaves its neighbours
            // adjacent, and snapping moves two notes apart. Folding by an octave fixes it
            // without changing the pitch class, so the harmony is untouched.
            for i in 1..<Swift.max(1, out.count) where out[i].stepIndex - out[i - 1].stepIndex < 8 {
                let previous = Int(out[i - 1].note)
                var note = Int(out[i].note)
                while note - previous > 12, note - 12 >= low { note -= 12 }
                while previous - note > 12, note + 12 <= high { note += 12 }
                if note != Int(out[i].note) {
                    out[i] = MIDIEvent(stepIndex: out[i].stepIndex, note: UInt8(note),
                                       velocity: out[i].velocity,
                                       durationSteps: out[i].durationSteps)
                }
            }
            return out
        }

        if ruleID == "MOT-LD1-021" {
            // Short Statement — 4-6 notes over 6-34 steps, then 1.0-4.0x that span in silence.
            let (low, high) = (65, 86)
            var cell: [Int] = []                                // drawn once, then varied
            var step = 16 * 4                                   // let the song start first
            while step < totalSteps {
                let span      = 6 + rng.nextInt(upperBound: 29) // 6...34 steps
                if cell.isEmpty { cell = Self.kraftwerkCells[rng.nextInt(upperBound: Self.kraftwerkCells.count)] }
                else             { cell = varyCell(cell, rng: &rng) }
                // Successive statements are separated by silence, but a short gap between two
                // of them still reads as one line, so the next statement starts within a fifth
                // of where the last one ended rather than anywhere in the band.
                let start  = anchor(for: cell, at: step, low: low, high: high,
                                    near: events.last.map { Int($0.note) }, rng: &rng)
                let placed = realise(cell, from: start, at: step, low: low, high: high)
                let noteCount = placed.count
                for i in 0..<noteCount {
                    let at = step + (span * i) / max(1, noteCount)
                    guard at < totalSteps else { break }
                    // A statement is short, so its notes can hold: each lasts most of the way to
                    // the next rather than being a uniform two-step blip.
                    let nextAt = step + (span * (i + 1)) / max(1, noteCount)
                    let dur    = max(2, min(12, nextAt - at - 1))
                    events.append(MIDIEvent(stepIndex: at, note: UInt8(placed[i]),
                                            velocity: 80, durationSteps: dur))
                }
                let silence = Int(Double(span) * (1.0 + rng.nextDouble() * 3.0))   // 1.0...4.0x
                step += span + max(1, silence)
            }
            return shapePhraseEndings(events, rng: &rng, low: low, high: high)
        }

        // MOT-LD1-022 Long Run — a continuous run at ~1.0 notes/beat, then 4-6x that span in
        // silence. Typically two or three statements in a song, which is what makes the lead
        // feel like an announcement rather than a part.
        //
        // The plan's 77-106 came from the corpus, but 106 is Bb7 — well over an octave above
        // Motorik's own Lead 1 band of 52-79, and it put 29% of this rule's notes above C7,
        // which reads as shrill. 72-91 stays above MOT-LD1-021's centre without reaching
        // whistle register, and the figure is placed low within it.
        let (low, high) = (72, 91)
        var cell: [Int] = []                                // drawn once, then varied

        // Statements are LAID OUT ACROSS THE SONG rather than chained end to end.
        //
        // The corpus gives "4-6x the span in silence", and taken literally with runs of up to
        // 130 notes that is 120-180 bars of rest — so one statement and its silence consumed the
        // whole song. Measured over 43 songs the rule managed 1.7 appearances, its last note
        // fell 46% of the way through, and 33 of them had no lead at all after the two-thirds
        // mark. The plan asks for two or three statements; this guarantees them, and guarantees
        // the last one lands late.
        let statements = 3 + rng.nextInt(upperBound: 2)         // 3...4
        let bodyStart  = 16 * 8
        let bodyEnd    = max(bodyStart + 1, totalSteps - 16 * 4)
        let slot       = max(1, (bodyEnd - bodyStart) / statements)

        for s in 0..<statements {
            let slotStart = bodyStart + s * slot
            // Jitter the entry so the statements do not arrive on a grid.
            let step = slotStart + rng.nextInt(upperBound: max(1, slot / 4))
            // The run fills roughly half its slot, but is capped at 14 bars however long the
            // slot is. Uncapped, a long song gave 15-25 bar runs — too much unbroken presence
            // for a rule whose character is a statement followed by silence.
            // 13 bars of span, not 14: a window that starts mid-bar touches one more bar index
            // than its length, so 14 would spill to 15.
            let maxRun    = 13 * 16
            let minRun    = 7 * 16
            let runSteps  = max(minRun, min(maxRun, slot / 2 + rng.nextInt(upperBound: max(1, slot / 4))))
            let noteCount = 40 + rng.nextInt(upperBound: 91)    // 40...130
            // The cell is drawn once for the song and restated through every run, so the same
            // figure recurs across minutes rather than each run being unrelated to the last.
            // The first run establishes the figure; later runs take a fresh one 40% of the
            // time, so a song states two or three related ideas rather than one for its whole
            // length. Within a run the figure still holds, which is what keeps it recognisable.
            if cell.isEmpty || rng.nextDouble() < 0.40 {
                cell = Self.kraftwerkCells[rng.nextInt(upperBound: Self.kraftwerkCells.count)]
            }
            var statement = realise(cell, from: anchor(for: cell, at: step, low: low, high: high, rng: &rng),
                                    at: step, low: low, high: high)
            var posInFigure = 0

            // A rhythmic cell of 3 or 4 gaps, drawn once per run and repeated. An unvarying
            // 4-step grid for a hundred notes is the single most fatiguing thing this rule did:
            // same length, same spacing, no phrase anywhere in it.
            let cellLen = 3 + rng.nextInt(upperBound: 2)
            var gapCell = (0..<cellLen).map { _ -> Int in
                let r = rng.nextDouble()
                return r < 0.45 ? 4 : r < 0.75 ? 2 : r < 0.92 ? 6 : 8
            }
            // A cell that draws the same gap throughout is the even grid again by another
            // route, so force at least one contrasting value into it.
            if Set(gapCell).count == 1 {
                gapCell[rng.nextInt(upperBound: gapCell.count)] = gapCell[0] == 4 ? 2 : 4
            }
            // Long notes in some runs, short in others — one more axis that never varied.
            let legato = rng.nextDouble() < 0.4

            var at = step
            var placed = 0
            let runEnd = min(totalSteps, step + runSteps)
            while placed < noteCount && at < runEnd {
                let gap = gapCell[placed % cellLen]
                // Duration follows the gap but is not locked to it: a note may hold into the
                // next or clip short, which is what stops a repeating cell sounding mechanical.
                let dur = legato ? max(2, gap - 1 + (rng.nextDouble() < 0.3 ? 2 : 0))
                                 : max(1, min(3, gap - (rng.nextDouble() < 0.4 ? 2 : 1)))
                events.append(MIDIEvent(stepIndex: at, note: UInt8(statement[posInFigure]),
                                        velocity: 80, durationSteps: dur))
                posInFigure += 1
                if posInFigure >= statement.count {
                    // The cell has been stated; say it again. Most restatements keep the same
                    // anchor so the figure sits still — re-anchoring every time is the drift
                    // this rewrite exists to remove — and a transposition, when it happens, is
                    // onto a chord tone via anchor().
                    cell = varyCell(cell, rng: &rng)
                    let reanchor = rng.nextDouble() < 0.45
                    let previous = statement[0]
                    statement = realise(cell,
                                        from: reanchor ? anchor(for: cell, at: at, low: low, high: high,
                                                                near: previous, rng: &rng)
                                                       : previous,
                                        at: at, low: low, high: high)
                    posInFigure = 0
                }
                at += gap
                placed += 1
                // A breath every 6-10 notes: without one the run is a hundred notes with no seam.
                // One breath in four opens into a full bar or two of silence, so the statement
                // has space inside it rather than only around it.
                if placed % (6 + (placed / 7) % 5) == 0 {
                    // One breath in three opens into two to four bars. At one in four and a
                    // two-bar ceiling, a thirteen-bar run had no real gap in it and forty bars
                    // of a long song could pass without the lead ever leaving.
                    at += rng.nextDouble() < 0.33
                        ? 32 + rng.nextInt(upperBound: 33)      // 2-4 bars
                        : 4 + rng.nextInt(upperBound: 9)        // a short breath
                }
            }
            _ = step
        }
        return shapePhraseEndings(events, rng: &rng, low: low, high: high)
    }

}
