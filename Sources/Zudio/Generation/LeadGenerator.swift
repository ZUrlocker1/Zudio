// LeadGenerator.swift — generation step 7
// LD1-001: Phrase-first — v2 starter phrases (4 bars, 8 phrases), cycling with directional mutation
// LD1-002: Pentatonic Cell — short driving cell, locked 16 bars then one-interval mutation
// LD1-003: Long Breath — sparse, long sustained notes with lots of rests
// LD1-004: Stepwise Sequence — descending 5→4→2→1 (bar A), shifted b7→5→4→2 (bar B)
// LD1-005: Statement-Answer — bar A ascends 1→2→b3→5, bar B silent then answers 4→b3
// LD1-006: Long Arc Solo — single note per bar, ascending or descending through register across section
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
        forceLeadRuleID: String? = nil
    ) -> [MIDIEvent] {

        // A: Per-section rule — always consume two draws for RNG determinism across songs.
        // forceLeadRuleID is honoured only for known Motorik-lead IDs; cross-style IDs are ignored.
        let pickedA        = pickLd1Rule(rng: &rng)
        let bRuleCandidate = pickLd1Rule(rng: &rng)
        let aRule: String  = forceLeadRuleID.flatMap { $0.hasPrefix("MOT-LD1-") ? $0 : nil } ?? pickedA
        // Technique D: LD1-003 Long Breath is too passive for B sections; escalate to an active rule.
        let bRule: String
        if aRule == "MOT-LD1-003" {
            bRule = (rng.nextDouble() < 0.60) ? "MOT-LD1-001" : "MOT-LD1-004"
        } else {
            bRule = (rng.nextDouble() < 0.70) ? aRule : bRuleCandidate
        }
        usedRuleIDs.insert(aRule)

        // E: Delayed body entry — Lead 1 hard-silent for first 8 or 16 bars of A section
        let aStart   = structure.sections.first(where: { $0.label == .A })?.startBar ?? 0
        let entryBar = aStart + (rng.nextDouble() < 0.5 ? 8 : 16)

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

        // G: Sparse-phrase gate for LD1-001 — 35% of 4-bar cycles thin to ~45% note density
        var phraseSparseCycle = false

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            // E: Body section hard-silent before entryBar
            let isBodySection = section.label == .A || section.label == .B
            if isBodySection && bar < entryBar { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let intensity    = section.subPhaseIntensity(atBar: bar)
            let barStart     = bar * 16

            // A: Choose rule based on section label
            let ruleID = (section.label == .B) ? bRule : aRule

            var barEvents: [MIDIEvent] = []

            switch ruleID {

            case "MOT-LD1-001":
                if isIntroOutro {
                    // Fallback: sparse random during intro/outro
                    barEvents = lead1MotifFirst(barStart: barStart, entry: entry, frame: frame,
                        intensity: intensity, isIntroOutro: true, prevNote: prevNote, rng: &rng)
                } else {
                    // C: Mutate phrase every 16 bars
                    if bar >= nextPhraseBar {
                        currentPhrase = mutatePhraseOnce(currentPhrase, mode: frame.mode, rng: &rng)
                        nextPhraseBar += 16
                    }
                    // Which 16-step window within the 4-bar phrase cycle?
                    let cycleBar      = (bar - entryBar) % 4
                    let phraseStepBase = cycleBar * 16
                    let bounds        = kRegisterBounds[kTrackLead1]!
                    let keyRoot       = 60 + keySemitone(frame.key)
                    // G: Decide sparse mode at the start of each 4-bar cycle (35% chance).
                    // Sparse mode thins the phrase to ~45% of notes, giving 4–6 from a 10–13 note phrase.
                    if cycleBar == 0 { phraseSparseCycle = rng.nextDouble() < 0.35 }
                    let gateProb: Double = phraseSparseCycle ? 0.45 : 1.0
                    for evt in currentPhrase where evt.step >= phraseStepBase && evt.step < phraseStepBase + 16 {
                        guard rng.nextDouble() < gateProb else { continue }   // G: sparse gate
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
                }

            case "MOT-LD1-002":
                if !isIntroOutro {
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
                    // 15% rest bar — breathing room between repetitions
                    if rng.nextDouble() >= 0.15 {
                        barEvents = replayPentatonicCell(
                            intervals: motifIntervals, steps: motifSteps, durs: motifDurs, vels: motifVels,
                            barStart: barStart, entry: entry, frame: frame,
                            intensity: intensity, prevNote: prevNote)
                    }
                }

            case "MOT-LD1-003":
                barEvents = lead1LongBreath(barStart: barStart, entry: entry, frame: frame,
                    intensity: intensity, isIntroOutro: isIntroOutro, prevNote: prevNote, rng: &rng)

            case "MOT-LD1-004":
                if !isIntroOutro {
                    // Phrase gate: 25% of 4-bar cycles are completely silent (Motorik breathing room).
                    // Bar gate: 15% of individual bars in active phrases are also silent.
                    let cycleBar = (bar - entryBar) % 4
                    if cycleBar == 0 { phraseSparseCycle = rng.nextDouble() < 0.25 }
                    if !phraseSparseCycle && rng.nextDouble() >= 0.15 {
                        barEvents = lead1StepwiseSequence(barStart: barStart, bar: bar, entry: entry, frame: frame,
                            intensity: intensity, isIntroOutro: false, prevNote: prevNote, rng: &rng)
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

            case "MOT-LD1-006":
                // F: One held note per bar, stepping through mode scale.
                // Reverses direction at register boundaries so it doesn't clamp on one note.
                // Variable duration and occasional rests add rhythmic variety.
                if !isIntroOutro && !arcScale.isEmpty {
                    // 15% chance of a rest bar — creates breathing space in the arc
                    if rng.nextDouble() > 0.15 {
                        let note = UInt8(arcScale[max(0, min(arcScale.count - 1, arcScaleIdx))])
                        let vel  = velocityForIntensity(intensity, rng: &rng)
                        // Variable duration: short (8), normal (12), or held (16 steps)
                        let durRoll = rng.nextDouble()
                        let dur = durRoll < 0.20 ? 8 : durRoll < 0.35 ? 16 : 12
                        barEvents = [MIDIEvent(stepIndex: barStart, note: note, velocity: vel, durationSteps: dur)]
                    }
                    // Advance arc 1–2 scale steps; reverse direction at register boundaries
                    let step = 1 + rng.nextInt(upperBound: 2)
                    if arcAscending {
                        arcScaleIdx += step
                        if arcScaleIdx >= arcScale.count - 1 {
                            arcScaleIdx = arcScale.count - 1
                            arcAscending = false   // reverse at top
                        }
                    } else {
                        arcScaleIdx -= step
                        if arcScaleIdx <= 0 {
                            arcScaleIdx = 0
                            arcAscending = true    // reverse at bottom
                        }
                    }
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

        return events
    }

    // MARK: - Lead 2

    static func generateLead2(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        lead1Events: [MIDIEvent],
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let ld2Rules:   [String] = ["MOT-LD2-001", "MOT-LD2-002", "MOT-LD2-003", "MOT-LD2-004", "MOT-LD2-005", "MOT-LD2-006"]
        let ld2Weights: [Double] = [0.20,      0.15,      0.10,      0.20,      0.15,      0.20]
        let ruleID = ld2Rules[rng.weightedPick(ld2Weights)]
        usedRuleIDs.insert(ruleID)

        let lead1StepSet = Set(lead1Events.map(\.stepIndex))
        var lead1LastNote: UInt8? = nil   // tracks last Lead 1 pitch for LD2 harmonization
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }

            let isIntroOutro = section.label == .intro || section.label == .outro
            let intensity    = section.subPhaseIntensity(atBar: bar)
            let barStart     = bar * 16

            // Update last Lead 1 note for this bar (used by LD2-001 and LD2-006)
            let barL1 = lead1Events.filter { $0.stepIndex >= barStart && $0.stepIndex < barStart + 16 }
            if let l1Last = barL1.max(by: { $0.stepIndex < $1.stepIndex }) {
                lead1LastNote = l1Last.note
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
                    isIntroOutro: isIntroOutro, rng: &rng)
            case "MOT-LD2-005":
                events += lead2DescendingLine(barStart: barStart, bar: bar, entry: entry, frame: frame,
                    isIntroOutro: isIntroOutro, rng: &rng)
            case "MOT-LD2-006":
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

    // MARK: - LD1-003: long breath — sparse, sustained

    private static func lead1LongBreath(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        intensity: SectionIntensity, isIntroOutro: Bool, prevNote: UInt8?, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let prob: Double = isIntroOutro ? 0.10 : (intensity == .high ? 0.40 : 0.22)
        guard rng.nextDouble() < prob else { return events }
        let step = [0, 4, 8][rng.nextInt(upperBound: 3)]
        let note = pickNoteNearest(entry: entry, frame: frame, trackIndex: kTrackLead1,
                                   prevNote: prevNote, rng: &rng)
        let dur  = [6, 8, 10, 12][rng.nextInt(upperBound: 4)]
        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
            velocity: velocityForIntensity(intensity, rng: &rng), durationSteps: dur))
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
        let bounds = kRegisterBounds[kTrackLead1]!
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        let offsets: [Int] = (bar % 2 == 0) ? [7, 5, 2, 0] : [frame.mode.nearestInterval(10), 7, 5, 2]
        let durs:    [Int] = [3, 2, 3, 4]
        let velAdj:  [Int] = [11, 5, 7, 3]

        let baseVel = Int(velocityForIntensity(intensity, rng: &rng))
        var localPrev = prevNote
        for (i, step) in [0, 4, 8, 12].enumerated() {
            let pc   = (rootPC + offsets[i]) % 12
            let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
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
        let bounds = kRegisterBounds[kTrackLead1]!
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let baseVel = Int(velocityForIntensity(intensity, rng: &rng))
        var localPrev = prevNote

        if bar % 2 == 0 {
            let offsets = [0, 2, frame.mode.nearestInterval(3), 7]
            let durs    = [4, 3, 3, 5]
            let velBump = [0, -6, -3, +2]
            for (i, step) in [0, 4, 8, 12].enumerated() {
                let pc   = (rootPC + offsets[i]) % 12
                let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
                let v    = UInt8(Swift.max(50, Swift.min(110, baseVel + velBump[i])))
                events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                        velocity: v, durationSteps: durs[i]))
                localPrev = note
            }
        } else {
            if rng.nextDouble() < 0.40 {
                let pc   = (rootPC + 5) % 12
                let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
                events.append(MIDIEvent(stepIndex: barStart + 6, note: note, velocity: 65, durationSteps: 2))
                localPrev = note
            }
            let answerOffsets = [5, frame.mode.nearestInterval(3)]
            let answerDurs    = [4, 5]
            for (i, step) in [8, 12].enumerated() {
                let pc   = (rootPC + answerOffsets[i]) % 12
                let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
                let v    = UInt8(Swift.max(50, Swift.min(105, baseVel - i * 5)))
                events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                        velocity: v, durationSteps: answerDurs[i]))
                localPrev = note
            }
        }
        return events
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
            guard rng.nextDouble() < density && (!conflicts || rng.nextDouble() < 0.15) else { continue }
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
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        let barL1 = lead1Events
            .filter { $0.stepIndex >= barStart && $0.stepIndex < barStart + 16 }
            .sorted { $0.stepIndex < $1.stepIndex }
        guard !barL1.isEmpty else { return events }

        var localPrev: UInt8? = nil
        for e1 in barL1 {
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
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        let pc      = rng.nextDouble() < 0.65 ? fifthPC : rootPC
        let note    = midiNoteForPC(pc, bounds: bounds, rng: &rng)
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
        isIntroOutro: Bool, rng: inout SeededRNG
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
            guard rng.nextDouble() < 0.55 else { continue }
            let pc   = (rootPC + noteOffsets[i]) % 12
            let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
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
            let note = midiNoteForPC(pc, bounds: bounds, rng: &rng)
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: vel, durationSteps: 2))
        }
        return events
    }

    // MARK: - LD1-001 helpers

    /// Picks a new LD1 rule consuming one RNG draw (called twice in generateLead1 for determinism).
    private static func pickLd1Rule(rng: inout SeededRNG) -> String {
        let rules:   [String] = ["MOT-LD1-001", "MOT-LD1-002", "MOT-LD1-003", "MOT-LD1-004", "MOT-LD1-005", "MOT-LD1-006"]
        let weights: [Double] = [0.26,          0.18,          0.08,          0.22,          0.16,          0.10]
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
        for step in [0, 4, 8, 12] {
            guard rng.nextDouble() < 0.75 else { continue }
            steps.append(step)
            intervals.append(pcsOffsets[rng.nextInt(upperBound: pcsOffsets.count)])
            durs.append([1, 2, 2, 3][rng.nextInt(upperBound: 4)])
            vels.append(72 + rng.nextInt(upperBound: 18))
        }
        if steps.isEmpty { steps = [0]; intervals = [0]; durs = [2]; vels = [80] }
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
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let velAdj: Int
        switch intensity { case .low: velAdj = -12; case .medium: velAdj = 0; case .high: velAdj = 10 }
        var localPrev = prevNote
        for (i, step) in steps.enumerated() {
            guard i < intervals.count && i < durs.count && i < vels.count else { break }
            let pc   = (rootPC + intervals[i]) % 12
            let note = nearestMIDI(pc: pc, bounds: bounds, prevNote: localPrev)
            let vel  = UInt8(max(50, min(110, vels[i] + velAdj)))
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: vel, durationSteps: durs[i]))
            localPrev = note
        }
        return events
    }

    // MARK: - Shared helpers

    private static func densityForIntensity(_ intensity: SectionIntensity) -> Double {
        switch intensity {
        case .low:    return 0.25
        case .medium: return 0.55
        case .high:   return 0.80
        }
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
            ? entry.chordWindow.chordTones.sorted()
            : entry.chordWindow.scaleTensions.sorted()
        guard !pool.isEmpty else {
            return frame.midiNote(degree: "1", oct: 0, trackIndex: trackIndex)
        }
        let pc     = pool[rng.nextInt(upperBound: pool.count)]
        let bounds = kRegisterBounds[trackIndex] ?? RegisterBounds(low: 60, high: 96)
        return nearestMIDI(pc: pc, bounds: bounds, prevNote: prevNote)
    }

    /// Legacy chord-tone/tension picker (first-match octave). Used by LD2 rules.
    private static func pickNote(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, trackIndex: Int, rng: inout SeededRNG
    ) -> UInt8 {
        let pool: [Int]
        if rng.nextDouble() < 0.80 {
            pool = entry.chordWindow.chordTones.sorted()
        } else {
            pool = entry.chordWindow.scaleTensions.sorted()
        }
        guard !pool.isEmpty else {
            return frame.midiNote(degree: "1", oct: 0, trackIndex: trackIndex)
        }
        let pc     = pool[rng.nextInt(upperBound: pool.count)]
        let bounds = kRegisterBounds[trackIndex] ?? RegisterBounds(low: 60, high: 96)
        for oct in 3...7 {
            let midi = oct * 12 + pc
            if midi >= Int(bounds.low) && midi <= Int(bounds.high) { return UInt8(midi) }
        }
        return UInt8(bounds.low)
    }

    /// First-match pitch-class → MIDI note. Used by LD2 rules (no prevNote needed there).
    private static func midiNoteForPC(_ pc: Int, bounds: RegisterBounds, rng: inout SeededRNG) -> UInt8 {
        for oct in 3...7 {
            let midi = oct * 12 + pc
            if midi >= bounds.low && midi <= bounds.high { return UInt8(midi) }
        }
        return UInt8(bounds.low)
    }

    // MARK: - LD2-001 / LD2-006 harmony helpers

    /// Picks a chord tone whose pitch class forms a consonant interval with Lead 1's last note.
    /// Falls back to a random chord tone if no consonant option is available.
    private static func pickNoteHarmonized(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        trackIndex: Int, lead1LastNote: UInt8?, rng: inout SeededRNG
    ) -> UInt8 {
        let pool = entry.chordWindow.chordTones.sorted()
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
            return midiNoteForPC(pc, bounds: bounds, rng: &rng)
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
}
