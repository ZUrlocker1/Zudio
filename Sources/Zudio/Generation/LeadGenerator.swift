// LeadGenerator.swift — generation step 7
// Copyright (c) 2026 Zack Urlocker
// LD1-001: Phrase-first — v2 starter phrases (4 bars, 8 phrases), cycling with directional mutation
// LD1-002: Pentatonic Cell — short driving cell, locked 16 bars then one-interval mutation
// LD1-003: Punch Solo — 3–4 note melodic bursts, pentatonic, 4–8 bar silence between solos
// LD1-004: Stepwise Sequence — descending 5→4→2→1 (bar A), shifted b7→5→4→2 (bar B)
// LD1-005: Statement-Answer — bar A ascends 1→2→b3→5, bar B silent then answers 4→b3
// LD1-006: Long Arc Solo — quarter-note backbone, ascending/descending through register; 8th runs fill bar
// LD1-007: Vanishing Solo — 10-bar pentatonic guitar-style solo; Lead 2 silenced during solo
// LD1-008: Visiting Solo — 9-bar Dorian moog-style solo with octave arpeggios; Lead 2 silenced
// LD2-001: Counter-response — density ≤55% of Lead 1, attacks offset by half-beat for call-and-response
// LD2-002: Sustained Drone — very sparse, long holds on root or 5th
// LD2-003: Rhythmic Counter — short bursts offset from Lead 1 rhythm
// LD2-004: Hallogallo Motif Counter — 16th-note pairs at steps 0,2,4,6,10,12,14,15
// LD2-005: Descending Line — off-beat 2-bar arc 6→5→b3→2 with velocity diminuendo

struct LeadGenerator {

    // MARK: - v2 phrase starter data (used by LD1-001)

    private struct PhEvent: Sendable {
        let step: Int; let deg: Int; let oct: Int; let dur: Int; let vel: Int
    }
    private typealias Ph = [PhEvent]

    // Phrase note for LD1-010 Pendulum release phrases — stores a scale index resolved at replay time.
    private struct PendulumNote {
        var bar: Int; var step: Int; var scaleIdx: Int; var dur: Int; var velBase: Int
    }

    // Phrase note for LD1-013/014 melodic phrase engine — stores the resolved MIDI note directly.
    private struct MelodicNote {
        var barOff: Int; var step: Int; var midi: Int; var dur: Int; var vel: Int
    }

    // 8 phrases × 4 bars each. deg = semitone offset from key root (degreeSemitone pre-applied).
    // oct multiplier: 1 → C4 region (60+key+deg+12), 2 → one octave higher.
    private static let v2Phrases: [Ph] = [
        // phrase_01: statement-answer
        [.init(step:0,  deg:0,  oct:1, dur:2, vel:88), .init(step:3,  deg:2,  oct:1, dur:2, vel:84),
         .init(step:6,  deg:3,  oct:1, dur:2, vel:86), .init(step:10, deg:7,  oct:1, dur:2, vel:90),
         .init(step:17, deg:0,  oct:1, dur:2, vel:86), .init(step:21, deg:2,  oct:1, dur:2, vel:82),
         .init(step:24, deg:3,  oct:1, dur:2, vel:84), .init(step:28, deg:5,  oct:1, dur:3, vel:82),
         .init(step:36, deg:7,  oct:1, dur:2, vel:88), .init(step:40, deg:10, oct:1, dur:2, vel:84),
         .init(step:44, deg:7,  oct:1, dur:2, vel:86), .init(step:56, deg:0,  oct:1, dur:4, vel:90)],
        // phrase_02: sequence develop
        [.init(step:1,  deg:7,  oct:1, dur:2, vel:88), .init(step:4,  deg:5,  oct:1, dur:2, vel:84),
         .init(step:8,  deg:2,  oct:1, dur:2, vel:82), .init(step:12, deg:0,  oct:1, dur:2, vel:86),
         .init(step:17, deg:10, oct:1, dur:2, vel:82), .init(step:20, deg:7,  oct:1, dur:2, vel:86),
         .init(step:24, deg:5,  oct:1, dur:2, vel:84), .init(step:33, deg:7,  oct:1, dur:2, vel:90),
         .init(step:36, deg:9,  oct:1, dur:2, vel:84), .init(step:40, deg:7,  oct:1, dur:2, vel:88),
         .init(step:44, deg:3,  oct:1, dur:2, vel:84), .init(step:52, deg:2,  oct:1, dur:2, vel:80),
         .init(step:56, deg:0,  oct:1, dur:4, vel:88)],
        // phrase_03: register climb release
        [.init(step:0,  deg:0,  oct:1, dur:2, vel:86), .init(step:4,  deg:2,  oct:1, dur:2, vel:82),
         .init(step:8,  deg:3,  oct:1, dur:2, vel:84), .init(step:12, deg:7,  oct:1, dur:2, vel:88),
         .init(step:19, deg:0,  oct:2, dur:2, vel:84), .init(step:22, deg:10, oct:1, dur:2, vel:82),
         .init(step:26, deg:7,  oct:1, dur:2, vel:86), .init(step:34, deg:2,  oct:2, dur:2, vel:84),
         .init(step:38, deg:0,  oct:2, dur:2, vel:88), .init(step:42, deg:10, oct:1, dur:2, vel:82),
         .init(step:48, deg:7,  oct:1, dur:2, vel:86), .init(step:52, deg:5,  oct:1, dur:2, vel:82),
         .init(step:56, deg:0,  oct:1, dur:4, vel:90)],
        // phrase_04: syncopated space
        [.init(step:2,  deg:0,  oct:1, dur:2, vel:86), .init(step:7,  deg:2,  oct:1, dur:1, vel:80),
         .init(step:10, deg:3,  oct:1, dur:2, vel:84), .init(step:14, deg:2,  oct:1, dur:1, vel:78),
         .init(step:19, deg:7,  oct:1, dur:2, vel:88), .init(step:23, deg:5,  oct:1, dur:2, vel:82),
         .init(step:29, deg:2,  oct:1, dur:2, vel:80), .init(step:35, deg:0,  oct:1, dur:2, vel:86),
         .init(step:41, deg:10, oct:1, dur:2, vel:80), .init(step:47, deg:7,  oct:1, dur:2, vel:84),
         .init(step:56, deg:0,  oct:1, dur:4, vel:88)],
        // phrase_05: minor pentatonic bias
        [.init(step:0,  deg:0,  oct:1, dur:2, vel:88), .init(step:4,  deg:3,  oct:1, dur:2, vel:86),
         .init(step:8,  deg:5,  oct:1, dur:2, vel:82), .init(step:12, deg:7,  oct:1, dur:2, vel:88),
         .init(step:16, deg:10, oct:1, dur:2, vel:84), .init(step:22, deg:7,  oct:1, dur:2, vel:86),
         .init(step:26, deg:5,  oct:1, dur:2, vel:82), .init(step:32, deg:0,  oct:2, dur:2, vel:84),
         .init(step:38, deg:10, oct:1, dur:2, vel:82), .init(step:44, deg:7,  oct:1, dur:2, vel:86),
         .init(step:56, deg:0,  oct:1, dur:4, vel:90)],
        // phrase_06: dorian color
        [.init(step:1,  deg:0,  oct:1, dur:2, vel:86), .init(step:5,  deg:2,  oct:1, dur:2, vel:82),
         .init(step:9,  deg:3,  oct:1, dur:2, vel:84), .init(step:13, deg:7,  oct:1, dur:2, vel:88),
         .init(step:18, deg:9,  oct:1, dur:2, vel:80), .init(step:22, deg:7,  oct:1, dur:2, vel:86),
         .init(step:28, deg:5,  oct:1, dur:2, vel:82), .init(step:34, deg:2,  oct:1, dur:2, vel:80),
         .init(step:40, deg:0,  oct:1, dur:2, vel:88), .init(step:46, deg:10, oct:1, dur:2, vel:82),
         .init(step:56, deg:0,  oct:1, dur:4, vel:90)],
        // phrase_07: sequence then break
        [.init(step:0,  deg:7,  oct:1, dur:2, vel:88), .init(step:4,  deg:5,  oct:1, dur:2, vel:84),
         .init(step:8,  deg:2,  oct:1, dur:2, vel:82), .init(step:12, deg:0,  oct:1, dur:2, vel:86),
         .init(step:16, deg:5,  oct:1, dur:2, vel:84), .init(step:20, deg:2,  oct:1, dur:2, vel:82),
         .init(step:24, deg:0,  oct:1, dur:2, vel:86), .init(step:32, deg:10, oct:1, dur:2, vel:80),
         .init(step:40, deg:7,  oct:1, dur:2, vel:86), .init(step:48, deg:5,  oct:1, dur:2, vel:82),
         .init(step:56, deg:0,  oct:1, dur:4, vel:90)],
        // phrase_08: peak and resolve
        [.init(step:0,  deg:0,  oct:1, dur:2, vel:86), .init(step:4,  deg:2,  oct:1, dur:2, vel:82),
         .init(step:8,  deg:3,  oct:1, dur:2, vel:84), .init(step:12, deg:7,  oct:1, dur:2, vel:88),
         .init(step:18, deg:10, oct:1, dur:2, vel:84), .init(step:22, deg:0,  oct:2, dur:2, vel:90),
         .init(step:26, deg:10, oct:1, dur:2, vel:84), .init(step:34, deg:7,  oct:1, dur:2, vel:86),
         .init(step:40, deg:5,  oct:1, dur:2, vel:82), .init(step:46, deg:2,  oct:1, dur:2, vel:80),
         .init(step:56, deg:0,  oct:1, dur:4, vel:90)]
    ]

    // MARK: - Lead 1

    static func generateLead1(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceLeadRuleID: String? = nil,
        passBodyBars: Int? = nil,
        noirVariation: Bool = false
    ) -> (events: [MIDIEvent], soloRange: Range<Int>?) {

        // A: Per-section rule — always consume two draws for RNG determinism across songs.
        // forceLeadRuleID is honoured only for known Motorik-lead IDs; cross-style IDs are ignored.
        let pickedA        = pickLd1Rule(rng: &rng, noir: noirVariation)
        let bRuleCandidate = pickLd1Rule(rng: &rng, noir: noirVariation)
        let aRule: String  = forceLeadRuleID.flatMap { $0.hasPrefix("MOT-LD1-") ? $0 : nil } ?? pickedA
        // Technique D: LD1-003 Punch Solo handles its own silence via punchNextSoloBar; escalate to an active rule for B sections.
        let bRule: String
        if aRule == "MOT-LD1-003" {
            bRule = (rng.nextDouble() < 0.60) ? "MOT-LD1-001" : "MOT-LD1-004"
        } else {
            bRule = (rng.nextDouble() < 0.70) ? aRule : bRuleCandidate
        }
        usedRuleIDs.insert(aRule)

        // E: Delayed body entry — Lead 1 hard-silent for first 8 or 16 bars of A section
        let aStart   = structure.sections.first(where: { $0.label == .A })?.startBar ?? 0
        let entryBar = aStart + (rng.nextDouble() < 0.7 ? 8 : 16)  // 70% enter after 8 bars, 30% after 16

        // C: Select one v2 starter phrase for LD1-001
        let phraseIdx    = rng.nextInt(upperBound: v2Phrases.count)
        var currentPhrase = v2Phrases[phraseIdx]
        var nextPhraseBar = entryBar + 16   // mutate once per 4-cycle (16 bars)

        // B: Motif lock state for LD1-002 pentatonic cell
        var motifIntervals:       [Int] = []
        var motifSteps:           [Int] = []
        var motifDurs:            [Int] = []
        var motifVels:            [Int] = []
        var motifBuilt                 = false
        var motifMutationBar           = entryBar + 4    // pitch shifts every 4 bars
        var motifRhythmMutationBar     = entryBar + 8    // rhythm grid refreshes every 8 bars
        var motifRepeatCount           = 0               // consecutive bars with same first note
        var motifPrevFirstNote: UInt8? = nil             // first note of the previous bar's replay

        // D: Previous note for octave-smooth voice leading across bars
        var prevNote: UInt8? = nil

        // F: Long-arc solo state for LD1-006 — ascending or descending through the mode scale
        var arcAscending = rng.nextDouble() < 0.5   // var so arc can reverse at boundaries
        let arcScale: [Int] = {
            let keyST  = keySemitone(frame.key)
            let bounds = kRegisterBounds[kTrackLead1]!
            var notes: [Int] = []
            for oct in 0...7 {
                for interval in frame.mode.intervals {
                    let midi = keyST + interval + (oct * 12)
                    if midi >= bounds.low && midi <= bounds.high { notes.append(midi) }
                }
            }
            return notes.sorted()
        }()
        var arcScaleIdx = arcAscending ? 0 : max(0, arcScale.count - 1)
        var arcDescendRunLen = 0   // F2: consecutive descending steps (triggers upward correction after 4)
        var arcAscendRunLen  = 0   // F2: consecutive ascending steps (triggers downward correction after 4)

        // LD1-003: Short Punch — next bar at which a punch solo is allowed to start
        var punchNextSoloBar = entryBar   // initially at section start

        // LD1-004: Stepwise Sequence — run-length tracker for forced gap
        // After 3 full sequences (~6 bars) or 14 notes, mandates ≥1 bar silence.
        var ld4RunBars  = 0   // consecutive bars that produced notes
        var ld4RunNotes = 0   // notes produced in current active run
        var ld4RestUntil = -1 // bar index at which forced rest ends

        // G: Sparse-phrase gate for LD1-001 — 35% of 4-bar cycles thin to ~45% note density
        var phraseSparseCycle = false

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
        let isSoloRule = aRule == "MOT-LD1-007" || aRule == "MOT-LD1-008"
        let soloLen    = aRule == "MOT-LD1-007" ? 10 : 9
        let soloWindow: Range<Int>? = isSoloRule
            ? pickSoloStartBar(structure: structure, soloLength: soloLen, rng: &rng, passBodyBars: passBodyBars)
            : nil
        let soloRange: Range<Int>? = soloWindow

        // I: General Lead 1 rest windows — applies to all non-solo rules.
        // Solo rules (007/008) manage their own silence via soloWindow; skip them.
        let ld1RestBars: Set<Int> = !isSoloRule
            ? buildRestBars(entryBar: entryBar, totalBars: frame.totalBars, rng: &rng)
            : []

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            // E: Body section hard-silent before entryBar.
            // Solo rules (007/008) bypass this — their solo window starts near the top of the body.
            let isBodySection = section.label == .A || section.label == .B
            if isBodySection && bar < entryBar && !isSoloRule { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let intensity    = section.subPhaseIntensity(atBar: bar)
            let barStart     = bar * 16

            // A: Choose rule based on section label
            let ruleID = (section.label == .B) ? bRule : aRule

            var barEvents: [MIDIEvent] = []

            // H: Solo window — checked before the switch so bRule never interferes.
            if !isIntroOutro, let window = soloWindow, window.contains(bar) {
                let soloBar = bar - window.lowerBound
                barEvents = aRule == "MOT-LD1-007"
                    ? generateGuitarSolo007(soloBar: soloBar, barStart: barStart, frame: frame)
                    : generateMoogSolo008(soloBar: soloBar, barStart: barStart, frame: frame)
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

            case "MOT-LD1-001":
                barEvents = lead1PhraseReplay(
                    barStart: barStart, bar: bar, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro,
                    currentPhrase: &currentPhrase, nextPhraseBar: &nextPhraseBar,
                    entryBar: entryBar, phraseSparseCycle: &phraseSparseCycle,
                    noir: noirVariation,
                    prevNote: prevNote, rng: &rng)

            case "MOT-LD1-002":
                if !isIntroOutro {
                    barEvents = lead1PentatonicMotif(
                        barStart: barStart, bar: bar, entry: entry, frame: frame,
                        intensity: intensity,
                        motifIntervals: &motifIntervals, motifSteps: &motifSteps,
                        motifDurs: &motifDurs, motifVels: &motifVels,
                        motifBuilt: &motifBuilt, motifMutationBar: &motifMutationBar,
                        motifRhythmMutationBar: &motifRhythmMutationBar, motifRepeatCount: &motifRepeatCount,
                        motifPrevFirstNote: &motifPrevFirstNote,
                        prevNote: prevNote, rng: &rng)
                }

            case "MOT-LD1-003":
                barEvents = lead1ShortPunch(barStart: barStart, bar: bar, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, rng: &rng,
                    punchNextSoloBar: &punchNextSoloBar)

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
                    let willPlay = !inForcedRest && bar >= ld4RestUntil
                                  && !phraseSparseCycle && rng.nextDouble() >= 0.15
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
                    if !phraseSparseCycle && rng.nextDouble() >= 0.15 {
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

            case "MOT-LD1-006":
                barEvents = lead1ArcSolo(
                    barStart: barStart, bar: bar, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro,
                    arcScale: arcScale, arcScaleIdx: &arcScaleIdx, arcAscending: &arcAscending,
                    arcDescendRunLen: &arcDescendRunLen, arcAscendRunLen: &arcAscendRunLen,
                    noir: noirVariation,
                    rng: &rng)

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

            default:
                barEvents = lead1MotifFirst(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, prevNote: prevNote, rng: &rng)
            }

            events += barEvents

            // D: Update prevNote from the last event in this bar
            if let last = barEvents.max(by: { $0.stepIndex < $1.stepIndex }) {
                prevNote = last.note
            }
        }

        return (events, soloRange)
    }

    // MARK: - Lead 2

    static func generateLead2(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        lead1Events: [MIDIEvent],
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        soloRange: Range<Int>? = nil
    ) -> [MIDIEvent] {
        let ld2Rules:   [String] = ["MOT-LD2-001", "MOT-LD2-002", "MOT-LD2-003", "MOT-LD2-004", "MOT-LD2-005", "MOT-LD2-006"]
        let ld2Weights: [Double] = [0.20,      0.20,      0.10,      0.10,      0.20,      0.20]
        var ruleID = ld2Rules[rng.weightedPick(ld2Weights)]
        // LD2-006 (Diatonic Shadow) requires Lead 1 notes to harmonize — if Lead 1 is on a solo rule
        // with a sparse window, Lead 2 would be silent for the whole song. Redirect to Counter Response.
        if soloRange != nil && ruleID == "MOT-LD2-006" { ruleID = "MOT-LD2-001" }
        usedRuleIDs.insert(ruleID)

        let lead1StepSet = Set(lead1Events.map(\.stepIndex))
        var lead1LastNote: UInt8? = nil   // tracks last Lead 1 pitch for LD2 harmonization
        var events: [MIDIEvent] = []

        // Pre-group Lead 1 events by bar for O(1) per-bar lookup (avoids O(n²) filter).
        var lead1ByBar = [[MIDIEvent]](repeating: [], count: frame.totalBars)
        for e in lead1Events {
            let b = e.stepIndex / 16
            if b < frame.totalBars { lead1ByBar[b].append(e) }
        }

        // LD2-006: pre-compute which 4-bar blocks are active — sits out ~35% of blocks entirely.
        // Decided once per song so the silences are structural, not bar-by-bar random.
        let ld2006BlockCount = (frame.totalBars + 3) / 4
        let ld2006ActiveBlocks: Set<Int> = ruleID == "MOT-LD2-006"
            ? Set((0..<ld2006BlockCount).filter { _ in rng.nextDouble() < 0.65 })
            : Set()

        for bar in 0..<frame.totalBars {
            // Silence Lead 2 during the Lead 1 extended solo window
            if let sr = soloRange, sr.contains(bar) { continue }

            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let intensity    = section.subPhaseIntensity(atBar: bar)
            let barStart     = bar * 16

            // Update last Lead 1 note for this bar (used by LD2-001 and LD2-006)
            let barL1 = lead1ByBar[bar]
            if let l1Last = barL1.max(by: { $0.stepIndex < $1.stepIndex }) {
                lead1LastNote = l1Last.note
            }

            // A — Bar-level silencing: if Lead 1 is active this bar, Lead 2 rests 50% of the time.
            // Intro/outro exempt (already sparse); LD2-006 exempt (shadow needs L1 to work).
            if !isIntroOutro && !barL1.isEmpty && ruleID != "MOT-LD2-006" {
                if rng.nextDouble() < 0.50 { continue }
            }

            switch ruleID {
            case "MOT-LD2-002":
                events += lead2SustainedDrone(barStart: barStart, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro, rng: &rng)
            case "MOT-LD2-003":
                events += lead2RhythmicCounter(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, lead1StepSet: lead1StepSet, rng: &rng)
            case "MOT-LD2-004":
                events += lead2HallogalloCounter(barStart: barStart, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro, lead1StepSet: lead1StepSet, rng: &rng)
            case "MOT-LD2-005":
                events += lead2DescendingLine(barStart: barStart, bar: bar, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro, rng: &rng)
            case "MOT-LD2-006":
                guard ld2006ActiveBlocks.contains(bar / 4) else { break }
                events += lead2DiatonicShadow(barStart: barStart, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro, lead1Events: lead1Events, rng: &rng)
            default:
                events += lead2CounterResponse(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro,
                    lead1StepSet: lead1StepSet, lead1LastNote: lead1LastNote, rng: &rng)
            }
        }

        return events
    }

    // MARK: - LD1-001: motif-first (intro/outro fallback + default case)

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

    // MARK: - LD1-003: Punch Solo — melodic burst, Chill trumpet style
    // Inspired by CHL-LD1-002 (muted trumpet): 3–4 notes drawn from the mode pentatonic,
    // with 4–8 bars of complete silence between solos.
    // 4-note burst: inner dur=3 (dotted-eighth) + 1 gap — 4 steps each, fits from step 0 or 2.
    // 3-note burst: inner dur=4 (quarter) + 1 gap — 5 steps each, fits from step 0, 2, or 4.
    // Final note always held (half or dotted-half) so the phrase lands and resonates.
    // Intro/outro: always silent. Body: fires only when bar >= punchNextSoloBar.

    private static func lead1ShortPunch(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool,
        rng: inout SeededRNG, punchNextSoloBar: inout Int
    ) -> [MIDIEvent] {
        guard !isIntroOutro, bar >= punchNextSoloBar else { return [] }

        // Build note pool using NotePoolBuilder — chord-tone and scale-tension pitch classes
        // only, with avoid tones excluded. This ensures no tritone clashes against the active
        // chord root regardless of which chord is active in the tonal governance map.
        let (chordTones, scaleTensions, _) = NotePoolBuilder.build(
            chordRootDegree: entry.chordWindow.chordRoot,
            chordType:       entry.chordWindow.chordType,
            key:             frame.key,
            mode:            frame.mode
        )
        let allowedPCs = chordTones.union(scaleTensions)
        var pool: [Int] = []
        for midi in 60...84 where allowedPCs.contains(midi % 12) {
            pool.append(midi)
        }
        guard pool.count >= 3 else { return [] }

        // Mostly 3–4 notes. 4-note bursts use shorter inner dur so they fit in the bar.
        let noteCount  = rng.nextDouble() < 0.55 ? 4 : 3
        let innerDur   = noteCount == 4 ? 3 : 4   // dotted-eighth for 4-note, quarter for 3-note
        // 4-note bursts need tighter start to fit; 3-note bursts allow step 4 too
        let startStep  = noteCount == 4
            ? [0, 2][rng.nextInt(upperBound: 2)]
            : [0, 2, 4][rng.nextInt(upperBound: 3)]
        var events: [MIDIEvent] = []
        var cursor  = startStep
        var prevIdx = rng.nextInt(upperBound: pool.count)

        for i in 0..<noteCount {
            guard cursor < 16 else { break }
            // Melodic motion: small interval steps, slight downward bias (jazz descend tendency)
            let delta = (rng.nextDouble() < 0.60) ? 1 : (rng.nextDouble() < 0.50 ? 2 : 3)
            let goUp  = (i == 0) ? (rng.nextDouble() < 0.50) : (rng.nextDouble() < 0.40)
            prevIdx   = goUp ? min(pool.count - 1, prevIdx + delta)
                             : max(0,              prevIdx - delta)
            let note  = UInt8(pool[prevIdx])

            let isLast = (i == noteCount - 1)
            let dur: Int
            if isLast {
                // Final note: half note (8) or dotted-half (12) — phrase lands and rings out
                dur = rng.nextDouble() < 0.55 ? 8 : 12
            } else {
                dur = innerDur
            }

            let baseVel: Int
            switch intensity { case .low: baseVel = 65; case .medium: baseVel = 75; case .high: baseVel = 85 }
            let vel = UInt8(max(55, min(100, baseVel + rng.nextInt(upperBound: 16) - 8)))
            events.append(MIDIEvent(stepIndex: barStart + cursor, note: note,
                                    velocity: vel, durationSteps: dur))
            if isLast { break }
            cursor += dur + 1   // 1-step gap between inner notes
        }

        // Schedule next solo 4–8 bars from now
        punchNextSoloBar = bar + 4 + rng.nextInt(upperBound: 5)
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

        if bar % 2 == 0 {
            let offsets = [0, 2, frame.mode.nearestInterval(3), 7]
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
            let answerOffsets = [5, frame.mode.nearestInterval(3)]
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

    // MARK: - LD1-001: Phrase Replay

    private static func lead1PhraseReplay(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool,
        currentPhrase: inout Ph, nextPhraseBar: inout Int,
        entryBar: Int, phraseSparseCycle: inout Bool,
        noir: Bool = false,
        prevNote: UInt8?, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        if isIntroOutro {
            // Fallback: sparse random during intro/outro
            return lead1MotifFirst(barStart: barStart, entry: entry, frame: frame,
                intensity: intensity, isIntroOutro: true, prevNote: prevNote, rng: &rng)
        }
        // C: Mutate phrase every 16 bars
        if bar >= nextPhraseBar {
            currentPhrase = mutatePhraseOnce(currentPhrase, mode: frame.mode, rng: &rng)
            nextPhraseBar += 16
        }
        // Which 16-step window within the 4-bar phrase cycle?
        let cycleBar      = (bar - entryBar) % 4
        let phraseStepBase = cycleBar * 16
        let bounds        = kRegisterBounds[kTrackLead1]!
        let keyRoot       = 48 + keySemitone(frame.key)
        // G: Decide sparse mode at the start of each 4-bar cycle (20% chance normally).
        // Sparse mode thins the phrase to ~45% of notes, giving 4–6 from a 10–13 note phrase.
        // Noir: per-bar gate — 45% of bars are completely silent; active bars fire at full density.
        // ld1RestBars already provides macro 4–8 bar gaps, so per-note thinning (the old 0.25
        // gate) only scattered isolated singles. A bar-level flip always delivers melodic cells.
        // phraseSparseCycle is still drawn to keep RNG deterministic across modes.
        if cycleBar == 0 { phraseSparseCycle = rng.nextDouble() < 0.20 }
        if noir && rng.nextDouble() < 0.45 { return [] }   // G: Noir bar-level silence gate
        let gateProb: Double = phraseSparseCycle ? 0.45 : 1.0
        var barEvents: [MIDIEvent] = []
        for evt in currentPhrase where evt.step >= phraseStepBase && evt.step < phraseStepBase + 16 {
            guard rng.nextDouble() < gateProb else { continue }   // G: sparse gate (non-Noir only)
            let localStep = evt.step - phraseStepBase
            // Mode-snap deg to current mode's nearest interval — fixes out-of-scale notes
            // when the same phrase is replayed in a different mode (e.g. deg:9 in Aeolian).
            let modeDeg = frame.mode.nearestInterval((evt.deg % 12 + 12) % 12)
            let rawMIDI   = bounds.clamp(keyRoot + modeDeg + evt.oct * 12)
            let velAdj: Int
            switch intensity { case .low: velAdj = -15; case .medium: velAdj = -5; case .high: velAdj = 5 }
            let vel = UInt8(max(50, min(110, evt.vel + velAdj)))
            barEvents.append(MIDIEvent(stepIndex: barStart + localStep, note: UInt8(rawMIDI),
                                       velocity: vel, durationSteps: evt.dur))
        }
        // Legato fill: extend each note toward the next attack so phrases breathe
        // rather than chopping at the raw dur:2 (8th note) stored in the JSON data.
        barEvents.sort { $0.stepIndex < $1.stepIndex }
        for i in 0 ..< Swift.max(0, barEvents.count - 1) {
            let gap    = barEvents[i + 1].stepIndex - barEvents[i].stepIndex
            let newDur = max(barEvents[i].durationSteps, min(gap - 1, 12))
            barEvents[i] = MIDIEvent(stepIndex: barEvents[i].stepIndex,
                                     note: barEvents[i].note,
                                     velocity: barEvents[i].velocity,
                                     durationSteps: newDur)
        }
        // Last note in bar: minimum quarter note (4 steps)
        if !barEvents.isEmpty {
            let i = barEvents.count - 1
            let newDur = max(barEvents[i].durationSteps, 4)
            barEvents[i] = MIDIEvent(stepIndex: barEvents[i].stepIndex,
                                     note: barEvents[i].note,
                                     velocity: barEvents[i].velocity,
                                     durationSteps: newDur)
        }
        return barEvents
    }

    // MARK: - LD1-002: Pentatonic Motif

    private static func lead1PentatonicMotif(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity,
        motifIntervals: inout [Int], motifSteps: inout [Int],
        motifDurs: inout [Int], motifVels: inout [Int],
        motifBuilt: inout Bool, motifMutationBar: inout Int,
        motifRhythmMutationBar: inout Int, motifRepeatCount: inout Int,
        motifPrevFirstNote: inout UInt8?,
        prevNote: UInt8?, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // B: Build motif on first body bar; pitch mutates every 4 bars, rhythm every 8.
        if !motifBuilt {
            (motifIntervals, motifSteps, motifDurs, motifVels) =
                buildPentatonicCell(frame: frame, rng: &rng)
            motifBuilt = true
        }
        // Pitch mutation: shift one interval (30% chance: two intervals) every 4 bars
        if bar >= motifMutationBar {
            motifIntervals = shiftOneInterval(motifIntervals, mode: frame.mode, rng: &rng)
            if rng.nextDouble() < 0.30 {
                motifIntervals = shiftOneInterval(motifIntervals, mode: frame.mode, rng: &rng)
            }
            motifMutationBar += 4
        }
        // Rhythm mutation: rebuild step grid every 8 bars; keeps pitch, refreshes rhythm.
        // Resize motifIntervals to match the new step count (cycling existing pitches)
        // so replayPentatonicCell never indexes out of bounds.
        if bar >= motifRhythmMutationBar {
            let (_, newSteps, newDurs, newVels) = buildPentatonicCell(frame: frame, rng: &rng)
            if !motifIntervals.isEmpty {
                motifIntervals = (0..<newSteps.count).map { motifIntervals[$0 % motifIntervals.count] }
            }
            motifSteps = newSteps
            motifDurs  = newDurs
            motifVels  = newVels
            motifRhythmMutationBar += 8
        }
        // Repetition guard: if the same first note has fired 2 bars in a row,
        // force an early pitch mutation so we never hear 3 identical bars.
        if motifRepeatCount >= 2 {
            motifIntervals = shiftOneInterval(motifIntervals, mode: frame.mode, rng: &rng)
            motifRepeatCount = 0
        }

        var barEvents: [MIDIEvent] = []
        // 8% rest bar — breathing room between repetitions
        if rng.nextDouble() >= 0.08 {
            barEvents = replayPentatonicCell(
                intervals: motifIntervals, steps: motifSteps, durs: motifDurs, vels: motifVels,
                barStart: barStart, entry: entry, frame: frame,
                intensity: intensity, prevNote: prevNote)
            // Track first note of this bar to detect repetition next bar
            let thisFirstNote = barEvents.min(by: { $0.stepIndex < $1.stepIndex })?.note
            if let cur = thisFirstNote, cur == motifPrevFirstNote {
                motifRepeatCount += 1
            } else {
                motifRepeatCount = 0
            }
            motifPrevFirstNote = thisFirstNote
        } else {
            motifRepeatCount = 0
            motifPrevFirstNote = nil
        }
        return barEvents
    }

    // MARK: - LD1-006: Arc Solo

    private static func lead1ArcSolo(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool,
        arcScale: [Int], arcScaleIdx: inout Int, arcAscending: inout Bool,
        arcDescendRunLen: inout Int, arcAscendRunLen: inout Int,
        noir: Bool = false,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // F: Arc solo stepping through mode scale; quarter notes are the backbone.
        // Bar modes: half note, single quarter, two quarters, three quarters,
        // quarter+burst (q beat1 + 4 eighths from beat3), off-beat run (pickup + run from beat2/3),
        // eighth-note run (fills bar fully). Multi-note bars walk adjacent scale steps in arc direction.
        // F2: After 4 consecutive steps in same direction, jump the other way.
        guard !isIntroOutro && !arcScale.isEmpty else { return [] }
        var barEvents: [MIDIEvent] = []
        // Rest bar probability: 12% normally, 35% in Noir for more breathing space.
        if rng.nextDouble() > (noir ? 0.35 : 0.12) {
            let idx = max(0, min(arcScale.count - 1, arcScaleIdx))
            // Chord-aware snap helper: returns nearest chord-compatible MIDI note
            let (ct006, st006, _) = NotePoolBuilder.build(
                chordRootDegree: entry.chordWindow.chordRoot,
                chordType:       entry.chordWindow.chordType,
                key:             frame.key, mode: frame.mode)
            let allowed006 = ct006.union(st006)
            let snapArc: (Int) -> UInt8 = { rawIdx in
                let candidate = arcScale[max(0, min(arcScale.count - 1, rawIdx))]
                if allowed006.contains(candidate % 12) { return UInt8(candidate) }
                let snapped = arcScale.filter { allowed006.contains($0 % 12) }
                                      .min(by: { abs($0 - candidate) < abs($1 - candidate) })
                return UInt8(snapped ?? candidate)
            }
            let mainNote = snapArc(idx)
            let vel = UInt8(min(88, Int(velocityForIntensity(intensity, rng: &rng))))
            let dir = arcAscending ? 1 : -1   // direction for passing tones

            let modeRoll = rng.nextDouble()
            if modeRoll < 0.10 {
                // Half note — rare longer hold for variety
                barEvents = [MIDIEvent(stepIndex: barStart, note: mainNote, velocity: vel, durationSteps: 8)]
            } else if modeRoll < 0.20 {
                // Single quarter at beat 1 — hit and space
                barEvents = [MIDIEvent(stepIndex: barStart, note: mainNote, velocity: vel, durationSteps: 4)]
            } else if modeRoll < 0.38 {
                // Two quarter notes — varied beat placement
                let n2 = snapArc(idx + dir)
                let subRoll = rng.nextDouble()
                if subRoll < 0.40 {
                    // beats 1+2 (steps 0, 4)
                    barEvents = [
                        MIDIEvent(stepIndex: barStart,     note: mainNote, velocity: vel,     durationSteps: 4),
                        MIDIEvent(stepIndex: barStart + 4, note: n2,       velocity: vel - 5, durationSteps: 4)
                    ]
                } else if subRoll < 0.75 {
                    // beats 1+3 (steps 0, 8)
                    barEvents = [
                        MIDIEvent(stepIndex: barStart,     note: mainNote, velocity: vel,     durationSteps: 4),
                        MIDIEvent(stepIndex: barStart + 8, note: n2,       velocity: vel - 5, durationSteps: 4)
                    ]
                } else {
                    // beats 2+4 (steps 4, 12)
                    barEvents = [
                        MIDIEvent(stepIndex: barStart + 4,  note: mainNote, velocity: vel,     durationSteps: 4),
                        MIDIEvent(stepIndex: barStart + 12, note: n2,       velocity: vel - 5, durationSteps: 4)
                    ]
                }
            } else if modeRoll < 0.56 {
                // Three quarter notes — beats 1, 2, 3 (steps 0, 4, 8)
                let n2 = snapArc(idx + dir)
                let n3 = snapArc(idx + dir * 2)
                barEvents = [
                    MIDIEvent(stepIndex: barStart,     note: mainNote, velocity: vel,     durationSteps: 4),
                    MIDIEvent(stepIndex: barStart + 4, note: n2,       velocity: vel - 3, durationSteps: 4),
                    MIDIEvent(stepIndex: barStart + 8, note: n3,       velocity: vel - 5, durationSteps: 4)
                ]
            } else if modeRoll < 0.68 {
                // Quarter + burst: quarter beat 1, silence beat 2, 4 eighths from beat 3 (gentle crescendo)
                let n2 = snapArc(idx + dir)
                let n3 = snapArc(idx + dir * 2)
                let n4 = snapArc(idx + dir * 3)
                let n5 = snapArc(idx + dir * 4)
                let bv = Int(vel)
                barEvents = [
                    MIDIEvent(stepIndex: barStart,      note: mainNote, velocity: vel,                            durationSteps: 4),
                    MIDIEvent(stepIndex: barStart + 8,  note: n2,       velocity: UInt8(max(50, bv - 4)),         durationSteps: 2),
                    MIDIEvent(stepIndex: barStart + 10, note: n3,       velocity: UInt8(max(50, bv - 2)),         durationSteps: 2),
                    MIDIEvent(stepIndex: barStart + 12, note: n4,       velocity: UInt8(max(50, bv)),             durationSteps: 2),
                    MIDIEvent(stepIndex: barStart + 14, note: n5,       velocity: UInt8(min(95, bv + 3)),         durationSteps: 2)
                ]
            } else if modeRoll < 0.80 {
                // Off-beat run: quarter pickup(s) then eighth run from beat 2 or 3
                if rng.nextDouble() < 0.50 {
                    // Variant A: one quarter on beat 1, 6-note run from beat 2
                    var runEvents: [MIDIEvent] = [MIDIEvent(stepIndex: barStart, note: mainNote, velocity: vel, durationSteps: 4)]
                    var runIdx = idx + dir; var runDir = dir
                    let bv = Int(vel)
                    for i in 0..<6 {
                        let ni = snapArc(runIdx)
                        let v  = UInt8(max(50, bv - 3 + rng.nextInt(upperBound: 5)))
                        runEvents.append(MIDIEvent(stepIndex: barStart + 4 + i * 2, note: ni, velocity: v, durationSteps: 2))
                        runIdx += runDir
                        if runIdx >= arcScale.count { runIdx = arcScale.count - 2; runDir = -runDir }
                        else if runIdx < 0          { runIdx = 1;                  runDir = -runDir }
                    }
                    barEvents = runEvents
                } else {
                    // Variant B: two quarters on beats 1+2, 4-note run from beat 3
                    let n2 = snapArc(idx + dir)
                    var runEvents: [MIDIEvent] = [
                        MIDIEvent(stepIndex: barStart,     note: mainNote, velocity: vel,                         durationSteps: 4),
                        MIDIEvent(stepIndex: barStart + 4, note: n2,       velocity: UInt8(max(50, Int(vel) - 5)), durationSteps: 4)
                    ]
                    var runIdx = idx + dir * 2; var runDir = dir
                    let bv = Int(vel)
                    for i in 0..<4 {
                        let ni = snapArc(runIdx)
                        let v  = UInt8(max(50, bv - 2 + rng.nextInt(upperBound: 5)))
                        runEvents.append(MIDIEvent(stepIndex: barStart + 8 + i * 2, note: ni, velocity: v, durationSteps: 2))
                        runIdx += runDir
                        if runIdx >= arcScale.count { runIdx = arcScale.count - 2; runDir = -runDir }
                        else if runIdx < 0          { runIdx = 1;                  runDir = -runDir }
                    }
                    barEvents = runEvents
                }
            } else {
                // Eighth-note run — 8 notes × 2 steps, fills bar completely, no rest
                var runEvents: [MIDIEvent] = []
                var runIdx = idx
                var runDir = dir
                for i in 0..<8 {
                    let ni = snapArc(runIdx)
                    let v  = UInt8(i == 0 ? Int(vel) : max(50, Int(vel) - 4 + rng.nextInt(upperBound: 5)))
                    runEvents.append(MIDIEvent(stepIndex: barStart + i * 2, note: ni, velocity: v, durationSteps: 2))
                    runIdx += runDir
                    if runIdx >= arcScale.count { runIdx = arcScale.count - 2; runDir = -runDir }
                    else if runIdx < 0          { runIdx = 1;                  runDir = -runDir }
                }
                barEvents = runEvents
            }
        }
        // F2: After 4 steps in the same direction, jump the other way instead.
        // Prevents a monotone ascending or descending run across the section.
        if arcAscending && arcAscendRunLen >= 4 {
            let jumpDown = 3 + rng.nextInt(upperBound: 3)   // 3–5 scale steps down
            arcScaleIdx  = max(0, arcScaleIdx - jumpDown)
            arcAscending = false
            arcAscendRunLen = 0
        } else if !arcAscending && arcDescendRunLen >= 4 {
            let jumpUp   = 3 + rng.nextInt(upperBound: 3)   // 3–5 scale steps up
            arcScaleIdx  = min(arcScale.count - 1, arcScaleIdx + jumpUp)
            arcAscending = true
            arcDescendRunLen = 0
        } else {
            // Normal advance: 1–2 scale steps; reverse direction at register boundaries
            let step = 1 + rng.nextInt(upperBound: 2)
            if arcAscending {
                arcDescendRunLen = 0
                arcAscendRunLen += 1
                arcScaleIdx += step
                if arcScaleIdx >= arcScale.count - 1 {
                    arcScaleIdx = arcScale.count - 1
                    arcAscending = false
                    arcAscendRunLen = 0
                }
            } else {
                arcAscendRunLen = 0
                arcDescendRunLen += 1
                arcScaleIdx -= step
                if arcScaleIdx <= 0 {
                    arcScaleIdx = 0
                    arcAscending = true
                    arcDescendRunLen = 0
                }
            }
        }
        return barEvents
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

    // MARK: - LD2-001: counter-response

    private static func lead2CounterResponse(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, lead1StepSet: Set<Int>,
        lead1LastNote: UInt8?, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let density = isIntroOutro ? 0.1 : densityForIntensity(intensity) * 0.55
        // Steps offset by 2 (half-beat) from Lead 1's beat-aligned attacks — creates
        // call-and-response feel: Lead 1 speaks on the beat, Lead 2 answers a half-beat later.
        for step in [2, 6, 10, 14] {
            let conflicts = lead1StepSet.contains(barStart + step)
            guard rng.nextDouble() < density && (!conflicts || rng.nextDouble() < 0.03) else { continue }
            let note = pickNoteHarmonized(entry: entry, frame: frame, trackIndex: kTrackLead2,
                                         lead1LastNote: lead1LastNote, rng: &rng)
            let dur  = [2, 4, 6][rng.nextInt(upperBound: 3)]
            events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: 65, durationSteps: dur))
        }
        return events
    }

    // MARK: - LD2-006: Diatonic Shadow
    // Mirrors Lead 1's rhythm at a diatonic 3rd below (or 4th above for variety).
    // Directly creates the "parallel harmony guitar" texture of Hallogallo.

    private static func lead2DiatonicShadow(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool, lead1Events: [MIDIEvent], rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro { return events }
        let bounds = kRegisterBounds[kTrackLead2]!
        // Key root PC — mode intervals are relative to the key root, not the chord root.
        // Using chordRootPC here would produce OOS shadow notes when the chord root is non-tonic.
        let rootPC = keySemitone(frame.key)

        let barL1 = lead1Events
            .filter { $0.stepIndex >= barStart && $0.stepIndex < barStart + 16 }
            .sorted { $0.stepIndex < $1.stepIndex }
        guard !barL1.isEmpty else { return events }

        var localPrev: UInt8? = nil
        for e1 in barL1 {
            // C — Shadow only ~55% of Lead 1 notes to thin the parallel harmony texture
            guard rng.nextDouble() < 0.55 else { continue }
            let lead1PC = Int(e1.note) % 12
            // 75%: diatonic 3rd below; 25%: diatonic 4th above — for occasional open-interval color
            let shadowPC = (rng.nextDouble() < 0.75)
                ? diatonicBelow(pitchClass: lead1PC, degrees: 2, mode: frame.mode, rootPC: rootPC)
                : diatonicAbove(pitchClass: lead1PC, degrees: 3, mode: frame.mode, rootPC: rootPC)
            let note = nearestMIDI(pc: shadowPC, bounds: bounds, prevNote: localPrev)
            let vel  = UInt8(max(45, Int(e1.velocity) - 10))
            events.append(MIDIEvent(stepIndex: e1.stepIndex, note: note,
                                    velocity: vel, durationSteps: e1.durationSteps))
            localPrev = note
        }
        return events
    }

    // MARK: - LD2-002: sustained drone — sparse long holds on root or 5th

    private static func lead2SustainedDrone(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let prob: Double = isIntroOutro ? 0.08 : 0.22
        guard rng.nextDouble() < prob else { return events }
        let bounds  = kRegisterBounds[kTrackLead2]!
        let rootPC  = chordRootPC(frame: frame, entry: entry)
        let fifthPC = (rootPC + 7) % 12
        let pc      = rng.nextDouble() < 0.65 ? fifthPC : rootPC
        let note    = nearestMIDI(pc: pc, bounds: bounds, prevNote: nil)
        let dur     = [8, 12, 16][rng.nextInt(upperBound: 3)]
        events.append(MIDIEvent(stepIndex: barStart, note: note, velocity: 55, durationSteps: dur))
        return events
    }

    // MARK: - LD2-003: rhythmic counter — short bursts in gaps left by Lead 1

    private static func lead2RhythmicCounter(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, lead1StepSet: Set<Int>, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro { return events }
        let density = densityForIntensity(intensity) * 0.55
        for step in [2, 4, 6, 8, 10, 12, 14] {
            guard !lead1StepSet.contains(barStart + step) else { continue }
            guard rng.nextDouble() < density else { continue }
            let note = pickNote(entry: entry, frame: frame, trackIndex: kTrackLead2, rng: &rng)
            let vel = UInt8(58 + rng.nextInt(upperBound: 16))
            events.append(MIDIEvent(stepIndex: barStart + step, note: note, velocity: vel, durationSteps: 2))
        }
        return events
    }

    // MARK: - LD2-004: Hallogallo Motif Counter
    // Source: lead2_hallogallo_motif_01 — Guitar 2 Motif (only 32 notes across the full song).

    private static func lead2HallogalloCounter(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool, lead1StepSet: Set<Int>, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro { return events }
        let bounds = kRegisterBounds[kTrackLead2]!
        // LD2-004 plays a fixed tonic-anchored motif (NEU! style) — rootPC is the song tonic,
        // not the current chord root, so the counter stays in-scale across all chord changes.
        let rootPC = keySemitone(frame.key)

        let noteOffsets: [Int] = [5, 7, 2, 2,   5, 7, 0, 0]
        let steps:       [Int] = [0, 2, 4, 6,  10,12,14,15]
        let vels: [UInt8]      = [84, 82, 82, 80,  84, 82, 80, 76]

        for (i, step) in steps.enumerated() {
            // Skip steps where Lead 1 is active — no simultaneous attacks
            if lead1StepSet.contains(barStart + step) { continue }
            guard rng.nextDouble() < 0.38 else { continue }
            let pc   = (rootPC + noteOffsets[i]) % 12
            let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: nil)
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: vels[i], durationSteps: 1))
        }
        return events
    }

    // MARK: - LD2-005: Descending Diatonic Line
    // Source: lead2_counter_02 — 2-bar phrase, ~8-step off-beat spacing, 6→5→b3→2 descent.

    private static func lead2DescendingLine(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        isIntroOutro: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        if isIntroOutro && rng.nextDouble() < 0.60 { return events }
        guard rng.nextDouble() >= 0.20 else { return events }   // 20% rest bar
        let bounds = kRegisterBounds[kTrackLead2]!
        // LD2-005 uses the song tonic as base for scale degree offsets to stay diatonic.
        let rootPC = keySemitone(frame.key)

        // Cycle through 4 descent positions every 8 bars so the line travels across the song
        // rather than repeating the same 2-bar phrase endlessly.
        let descPhase = (bar / 8) % 4
        let evenBar   = bar % 2 == 0
        let (off1, off2): (Int, Int)
        switch descPhase {
        case 1:  (off1, off2) = evenBar ? (7, frame.mode.nearestInterval(5))
                                        : (2, 0)
        case 2:  (off1, off2) = evenBar ? (frame.mode.nearestInterval(5), frame.mode.nearestInterval(3))
                                        : (0, frame.mode.nearestInterval(11))
        case 3:  (off1, off2) = evenBar ? (frame.mode.nearestInterval(3), 2)
                                        : (frame.mode.nearestInterval(11), 7)
        default: (off1, off2) = evenBar ? (frame.mode.nearestInterval(9), 7)
                                        : (frame.mode.nearestInterval(3), 2)
        }
        let (vel1, vel2): (UInt8, UInt8) = evenBar ? (70, 72) : (68, 66)

        for (pcOffset, step, vel) in [(off1, 5, vel1), (off2, 13, vel2)] {
            let pc   = (rootPC + pcOffset) % 12
            let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: nil)
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: vel, durationSteps: 2))
        }
        return events
    }

    // MARK: - LD1-001 helpers

    /// Picks a new LD1 rule consuming one RNG draw (called twice in generateLead1 for determinism).
    private static func pickLd1Rule(rng: inout SeededRNG, noir: Bool = false) -> String {
        if noir {
            // Noir: sparse, atmospheric leads dominate — long-note anchor, solo phrases, cold chord texture.
            // High-density rules (002 Pentatonic Cell, 003 Ratchet, 004 Syncopated) are suppressed.
            // MOT-LD1-007 (Vanishing Solo) excluded: its major-key melodic arc feels tonally out of place
            // even with minor-scale adjustment; its 4% redistributed 1% each to 010/011/013/014.
            let rules:   [String] = ["MOT-LD1-006","MOT-LD1-008","MOT-LD1-001","MOT-LD1-005","MOT-LD1-009","MOT-LD1-010","MOT-LD1-011","MOT-LD1-012","MOT-LD1-013","MOT-LD1-014"]
            let weights: [Double] = [0.04,         0.04,         0.04,         0.04,         0.11,         0.17,         0.17,         0.10,         0.14,         0.15]
            return rules[rng.weightedPick(weights)]
        }
        let rules:   [String] = ["MOT-LD1-001", "MOT-LD1-002", "MOT-LD1-003", "MOT-LD1-004", "MOT-LD1-005", "MOT-LD1-006", "MOT-LD1-007", "MOT-LD1-008"]
        let weights: [Double] = [0.15,          0.14,          0.10,          0.15,          0.14,          0.11,          0.11,          0.10]
        return rules[rng.weightedPick(weights)]
    }

    /// Shifts one random event's degree by one diatonic step (±2 semitones, snapped to mode).
    /// Applies directional bias: if the phrase already trends upward, bias mutations upward
    /// (65% chance) and vice versa — reinforces melodic arcs rather than random drift.
    private static func mutatePhraseOnce(_ phrase: Ph, mode: Mode, rng: inout SeededRNG) -> Ph {
        guard !phrase.isEmpty else { return phrase }
        var result = phrase
        let idx    = rng.nextInt(upperBound: result.count)
        let evt    = result[idx]
        // Detect phrase trend: compare first-half avg degree vs second-half avg degree
        let half       = max(1, phrase.count / 2)
        let firstAvg   = phrase.prefix(half).map(\.deg).reduce(0, +) / half
        let secondAvg  = phrase.suffix(half).map(\.deg).reduce(0, +) / max(1, phrase.count - half)
        let trendingUp = secondAvg > firstAvg
        let delta: Int = trendingUp
            ? (rng.nextDouble() < 0.65 ? 2 : -2)   // 65% up when phrase already rising
            : (rng.nextDouble() < 0.65 ? -2 : 2)   // 65% down when phrase already falling
        let newDeg = mode.nearestInterval(((evt.deg + delta) % 12 + 12) % 12)
        result[idx] = PhEvent(step: evt.step, deg: newDeg, oct: evt.oct, dur: evt.dur, vel: evt.vel)
        return result
    }

    // MARK: - LD1-002 helpers

    /// Builds a random 3-4 note pentatonic cell for LD1-002 motif lock.
    private static func buildPentatonicCell(
        frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> (intervals: [Int], steps: [Int], durs: [Int], vels: [Int]) {
        let pcsOffsets: [Int]
        switch frame.mode {
        case .Ionian, .MajorPentatonic, .Mixolydian: pcsOffsets = [0, 2, 4, 7, 9]
        default:                                      pcsOffsets = [0, 3, 5, 7, 10]
        }
        var intervals: [Int] = []; var steps: [Int] = []
        var durs:      [Int] = []; var vels:  [Int] = []
        // Long-note mode (25% of cells): 2 notes per bar with quarter-to-half note durations.
        // Normal mode: up to 4 notes per bar at sixteenth-to-dotted-eighth durations.
        let longMode = rng.nextDouble() < 0.25
        let stepPositions: [Int] = longMode
            ? [0, 8].filter { _ in rng.nextDouble() < 0.90 }   // beat 1 + beat 3, usually both
            : [0, 4, 8, 12]
        for step in stepPositions {
            if !longMode { guard rng.nextDouble() < 0.75 else { continue } }
            steps.append(step)
            // Pick an interval that differs from the previous one — prevents all-root cells
            var candidate = pcsOffsets[rng.nextInt(upperBound: pcsOffsets.count)]
            if let prev = intervals.last, candidate == prev, pcsOffsets.count > 1 {
                let others = pcsOffsets.filter { $0 != prev }
                candidate = others[rng.nextInt(upperBound: others.count)]
            }
            intervals.append(candidate)
            // Long mode: quarter (4) to half note (8); normal mode: 16th (1) to dotted-8th (3)
            // with an occasional quarter note (4) — 20% chance
            let dur: Int
            if longMode {
                dur = [4, 6, 6, 8][rng.nextInt(upperBound: 4)]
            } else {
                let roll = rng.nextInt(upperBound: 5)
                dur = [1, 2, 2, 3, 4][roll]
            }
            durs.append(dur)
            vels.append(72 + rng.nextInt(upperBound: 18))
        }
        if steps.isEmpty { steps = [0]; intervals = [0]; durs = [4]; vels = [80] }
        return (intervals, steps, durs, vels)
    }

    /// Shifts one interval in the motif by ±2 semitones, snapped to the mode's scale.
    private static func shiftOneInterval(_ intervals: [Int], mode: Mode, rng: inout SeededRNG) -> [Int] {
        guard !intervals.isEmpty else { return intervals }
        var result = intervals
        let idx    = rng.nextInt(upperBound: result.count)
        let delta  = rng.nextDouble() < 0.5 ? 2 : -2
        result[idx] = mode.nearestInterval(((result[idx] + delta) % 12 + 12) % 12)
        return result
    }

    /// Replays a locked pentatonic cell using the current bar's chord root and prevNote smoothing.
    private static func replayPentatonicCell(
        intervals: [Int], steps: [Int], durs: [Int], vels: [Int],
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, prevNote: UInt8?
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let bounds = kRegisterBounds[kTrackLead1]!
        let rootPC = chordRootPC(frame: frame, entry: entry)
        // Build the set of in-scale pitch classes so we can snap chord-relative offsets to
        // the actual key. Applying major-pentatonic offsets {0,2,4,7,9} from a non-tonic
        // chord root (e.g. C# in A Ionian) yields OOS notes (Eb, F, Bb). Snapping each
        // result to the nearest in-scale PC fixes this without changing the motif's rhythm
        // or melodic shape.
        let scalePCs = frame.scalePCs
        let velAdj: Int
        switch intensity { case .low: velAdj = -12; case .medium: velAdj = 0; case .high: velAdj = 10 }
        var localPrev = prevNote
        for (i, step) in steps.enumerated() {
            guard i < intervals.count && i < durs.count && i < vels.count else { break }
            let rawPC = (rootPC + intervals[i]) % 12
            // Snap to nearest in-scale pitch class (wrapping at the octave boundary).
            let pc = nearestScalePitchClass(rawPC, in: scalePCs)
            let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
            let vel  = UInt8(max(50, min(110, vels[i] + velAdj)))
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: vel, durationSteps: durs[i]))
            localPrev = note
        }
        return events
    }

    // MARK: - Shared helpers

    // I: Pre-computed rest windows for LD1-002 and LD1-006 — 1 or 2 deliberate 4–8 bar
    // silent stretches per rule in body sections. Decided from seed so silences are
    // structural and repeatable, not per-bar noise.
    private static func buildRestBars(entryBar: Int, totalBars: Int, rng: inout SeededRNG) -> Set<Int> {
        var restBars = Set<Int>()
        let bodyStart = entryBar
        let bodyEnd   = max(bodyStart, totalBars - 8)
        let bodyLen   = bodyEnd - bodyStart
        guard bodyLen >= 8 else { return restBars }
        let numWindows = 1 + rng.nextInt(upperBound: 2)  // 1 or 2 rest windows
        for _ in 0..<numWindows {
            let restLen   = 4 + rng.nextInt(upperBound: 5)   // 4–8 bars
            let maxStart  = max(bodyStart, bodyEnd - restLen)
            let restStart = bodyStart + rng.nextInt(upperBound: max(1, maxStart - bodyStart))
            for rb in restStart..<min(restStart + restLen, bodyEnd) {
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
        let pool: [Int] = (rng.nextDouble() < 0.80)
            ? Array(entry.chordWindow.chordTones)
            : Array(entry.chordWindow.scaleTensions)
        guard !pool.isEmpty else {
            return frame.midiNote(degree: "1", oct: 0, trackIndex: trackIndex)
        }
        let pc     = pool[rng.nextInt(upperBound: pool.count)]
        let bounds = kRegisterBounds[trackIndex] ?? RegisterBounds(low: 60, high: 96)
        return nearestMIDI(pc: pc, bounds: bounds, prevNote: prevNote)
    }

    /// Chord-tone/tension picker with smooth octave selection. Used by LD2 rules.
    private static func pickNote(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, trackIndex: Int, rng: inout SeededRNG
    ) -> UInt8 {
        pickNoteNearest(entry: entry, frame: frame, trackIndex: trackIndex, prevNote: nil, rng: &rng)
    }

// MARK: - LD2-001 / LD2-006 harmony helpers

    /// Picks a chord tone whose pitch class forms a consonant interval with Lead 1's last note.
    /// Falls back to a random chord tone if no consonant option is available.
    private static func pickNoteHarmonized(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        trackIndex: Int, lead1LastNote: UInt8?, rng: inout SeededRNG
    ) -> UInt8 {
        let pool = Array(entry.chordWindow.chordTones)
        guard !pool.isEmpty else { return frame.midiNote(degree: "1", oct: 0, trackIndex: trackIndex) }
        let bounds = kRegisterBounds[trackIndex] ?? RegisterBounds(low: 60, high: 96)

        if let l1Note = lead1LastNote {
            let l1PC = Int(l1Note) % 12
            // Consonant intervals (semitones): m3, M3, P4, P5, m6, M6
            let consonant: Set<Int> = [3, 4, 5, 7, 8, 9]
            let harmonized = pool.filter { pc in
                let interval = (pc - l1PC + 12) % 12
                return consonant.contains(interval) || consonant.contains((12 - interval) % 12)
            }
            let finalPool = harmonized.isEmpty ? pool : harmonized
            let pc = finalPool[rng.nextInt(upperBound: finalPool.count)]
            return nearestMIDI(pc: pc, bounds: bounds, prevNote: nil)
        } else {
            let pc = pool[rng.nextInt(upperBound: pool.count)]
            return nearestMIDI(pc: pc, bounds: bounds, prevNote: nil)
        }
    }

    /// Finds the mode scale-degree index closest to the given pitch class relative to root.
    private static func modeIndex(pitchClass: Int, mode: Mode, rootPC: Int) -> Int {
        let relPC = (pitchClass - rootPC + 12) % 12
        return mode.intervals.indices.min(by: {
            abs(mode.intervals[$0] - relPC) < abs(mode.intervals[$1] - relPC)
        }) ?? 0
    }

    /// Pitch class `degrees` diatonic scale steps below `pitchClass`.
    private static func diatonicBelow(pitchClass: Int, degrees: Int, mode: Mode, rootPC: Int) -> Int {
        let count  = mode.intervals.count
        let idx    = modeIndex(pitchClass: pitchClass, mode: mode, rootPC: rootPC)
        let newIdx = ((idx - degrees) % count + count) % count
        return (rootPC + mode.intervals[newIdx]) % 12
    }

    /// Pitch class `degrees` diatonic scale steps above `pitchClass`.
    private static func diatonicAbove(pitchClass: Int, degrees: Int, mode: Mode, rootPC: Int) -> Int {
        let count  = mode.intervals.count
        let idx    = modeIndex(pitchClass: pitchClass, mode: mode, rootPC: rootPC)
        let newIdx = (idx + degrees) % count
        return (rootPC + mode.intervals[newIdx]) % 12
    }

    // MARK: - LD1-007 / LD1-008: Solo placement

    /// Returns the bar range for the solo window, always within the A section.
    /// Never uses the B section — the bar loop applies bRule there, which would silence the solo.
    /// In test mode, places the solo near the start of the body so it is heard quickly.
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
                // Normal mode: place in the first two-thirds of the A section so the solo
                // isn't too late. Using 1/3 as earliest and 2/3 as latest cap keeps it
                // roughly centred in the song.
                earliest = a.startBar + a.lengthBars / 3
                latest   = min(a.startBar + (a.lengthBars * 2) / 3,
                               a.startBar + a.lengthBars - soloLength - 4)
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
}
