// KosmicArpeggioGenerator.swift — Kosmic generation step 3 (Rhythm track slot)
// The most important Kosmic generator — replaces RhythmGenerator for Kosmic style.
//
// Rules:
//   KOS-RTHM-001  Tangerine Dream step-sequencer: multi-voice modal grid, 16th notes,
//                skip positions, parallel voices, glacial modulation. Phaedra/Rubycon era.
//   KOS-RTHM-002  JMJ Hook: single-voice 4-note ascending hook, 8th/quarter notes,
//                brighter register, occasional harmony voice a 3rd above. Oxygène/Équinoxe era.
//   KOS-RTHM-003  JMJ Oxygène Oscillation: one voice slowly ascending then descending,
//                quarter-note legato. Very spacious. Classic early JMJ feel.
//   KOS-RTHM-004  Electric Buddha Groove: pentatonic, 2 interlocking voices, syncopated
//                16th-note grid with quarter-note anchor on beat 1. Driving and accessible.
//   KOS-RTHM-005  JMJ Dual-Rate: two voices sharing the same note pool cycling at 8th and
//                quarter-note rates; each step independently gated. Interlocking, shifting feel.
//   KOS-RTHM-006  Kraftwerk Locked Pulse: rigid 3-note cell on 8th-note grid, pitches fixed
//                for entire body. No gate probability — mechanical regularity is the sound.
//                Every 32 body bars (from bar 32 onward), cell jumps one octave for 4 bars
//                then snaps back. Deterministic — same displacement point every cycle.
//   KOS-RTHM-007  Pitch-Drifting Sequence: 4-step quarter-note pattern whose home pitch
//                transposes up one scale step every 4 bars through first body half, then
//                back down. Phaedra/Schulze slow-modulation style. Probabilistic gate.
//   KOS-RTHM-008  Oxygène 8-bar Arc: 5–7 notes spread across an 8-bar window, each held
//                1.5–2 bars. Ascending arcs on even 8-bar blocks, descending on odd.
//                Very sparse — wide interval arcs across multiple bars.
//   KOS-RTHM-009  Craven Faults Phase Drift: 5-note cell at 3-step intervals (15-step cycle,
//                coprime to 16-step bar). Start note advances +1 per bar creating a slow drift
//                through the material. 80% gate, MIDI 58–75, vel 52–68.
//   KOS-RTHM-010  Craven Faults Modular Grit: 7-note cell at 2-step intervals (14-step cycle).
//                Phase advances 2 notes per bar over 7-bar cycle. 65% gate + 25% ghost notes.
//                Staccato (dur=1), MIDI 58–76, vel 44–60 (ghosts 22–38).

import Foundation

struct KosmicArpeggioGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {

        let rules:   [String] = ["KOS-RTHM-001", "KOS-RTHM-002", "KOS-RTHM-003", "KOS-RTHM-004",
                                 "KOS-RTHM-005", "KOS-RTHM-006", "KOS-RTHM-007", "KOS-RTHM-008",
                                 "KOS-RTHM-009", "KOS-RTHM-010"]
        let weights: [Double] = [0.14,           0.13,           0.12,           0.09,
                                 0.12,           0.12,           0.09,           0.07,
                                 0.06,           0.06]
        let chosenRule = forceRuleID ?? rules[rng.weightedPick(weights)]
        usedRuleIDs.insert(chosenRule)

        var events: [MIDIEvent]
        switch chosenRule {
        case "KOS-RTHM-002": events = generateJMJHook(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "KOS-RTHM-003": events = generateJMJOxygene(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "KOS-RTHM-004": events = generateElectricBuddha(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "KOS-RTHM-005": events = generateJMJDualRate(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "KOS-RTHM-006": events = generateKraftwerkLocked(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "KOS-RTHM-007": events = generatePitchDrifting(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "KOS-RTHM-008": events = generateOxygene8Bar(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "KOS-RTHM-009": events = generateCravenFaultsPhase(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "KOS-RTHM-010": events = generateCravenFaultsGrit(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        default:             events = generateTD(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        }
        // Bridge A-1 (.bridge): arpeggio re-enters with ascending/descending phase walk
        events += generateBridgeA1Arp(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        // Bridge A-2 (.bridgeAlt call+response): melodic response phrase on non-hit bars
        events += generateBridgeAltArp(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        // Long intro hint: sparse ascending phrase from the midpoint of 6/8-bar intros
        events += generateLongIntroHint(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        return events
    }

    // MARK: - KOS-RTHM-001: Tangerine Dream multi-voice step-sequencer

    private static func generateTD(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {

        let patternLen   = rng.nextDouble() < 0.65 ? 4 : 8
        let stepDurations: [Int]    = [1,    2,    3,    4   ]
        let stepWeights:   [Double] = [0.55, 0.25, 0.10, 0.10]
        let stepDuration = stepDurations[rng.weightedPick(stepWeights)]
        let arpShape     = rng.nextInt(upperBound: 5)
        let voiceCount   = 3 + rng.nextInt(upperBound: 3)
        var voiceOffsets: [Int] = []
        for _ in 0..<voiceCount { voiceOffsets.append(rng.nextInt(upperBound: 4)) }
        var skipPositions: Set<Int> = []
        let skipCount = rng.nextDouble() < 0.50 ? 1 : 2
        for _ in 0..<skipCount { skipPositions.insert(rng.nextInt(upperBound: patternLen)) }

        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard !section.label.isBridge else { continue }  // bridges handled separately
            let isIntro = section.label == .intro
            let isOutro = section.label == .outro
            for bar in section.startBar..<section.endBar {
                // Sequencer spins up in last 2 bars of intro; winds down in first 2 bars of outro
                if isIntro && bar < section.endBar - 2 { continue }
                if isOutro && bar >= section.startBar + 2 { continue }
                let isIntroOutro = isIntro || isOutro

                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart    = bar * 16
                let notes5      = fiveNoteSubset(entry: entry, frame: frame)
                let modNotes    = glacialModulate(notes: notes5, bar: bar, rng: &rng)
                let pattern     = buildArpPattern(notes: modNotes, shape: arpShape, patternLen: patternLen, bar: bar)
                let countBefore = events.count
                // Single voice during intro/outro — full voices in body
                let voicesToUse = isIntroOutro ? Array(voiceOffsets.prefix(1)) : voiceOffsets
                for (voiceIdx, offset) in voicesToUse.enumerated() {
                    let voicePattern = shufflePattern(pattern, seed: voiceIdx, rng: &rng)
                    emitTDVoice(pattern: voicePattern, skipPositions: skipPositions,
                                barStart: barStart, stepDuration: stepDuration,
                                voiceOffset: offset, bar: bar, rng: &rng, events: &events)
                }
                if !isIntroOutro {
                    emitLowAnchor(barStart: barStart, entry: entry, frame: frame, rng: &rng, events: &events)
                }
                // Scale velocity down: sequencer spinning up/winding down
                if isIntroOutro {
                    for i in countBefore..<events.count {
                        let ev = events[i]
                        events[i] = MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                              velocity: UInt8(max(55, Int(ev.velocity) * 80 / 100)),
                                              durationSteps: ev.durationSteps)
                    }
                }
            }
        }
        return events
    }

    // MARK: - KOS-RTHM-002: JMJ Hook — single-voice melodic hook, 8th/quarter dominant

    private static func generateJMJHook(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {

        // 8th note (2 steps) 55%, quarter (4) 30%, dotted-8th (3) 15%
        let stepDur = [2, 2, 2, 4, 4, 3][rng.nextInt(upperBound: 6)]
        // 0: root-3rd-5th-3rd pendulum, 1: root-3rd-5th-octave ascend, 2: root-2nd-3rd-5th scale
        let hookShape  = rng.nextInt(upperBound: 3)
        // 40% chance of second harmony voice a minor/major 3rd above
        let addHarmony = rng.nextDouble() < 0.40

        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard !section.label.isBridge else { continue }
            let isIntro = section.label == .intro
            let isOutro = section.label == .outro
            for bar in section.startBar..<section.endBar {
                if isIntro && bar < section.endBar - 2 { continue }
                if isOutro && bar >= section.startBar + 2 { continue }
                let isIntroOutro = isIntro || isOutro

                guard let entry = tonalMap.entry(atBar: bar) else { continue }

                let barStart    = bar * 16
                let notes       = jmjHookNotes(entry: entry, frame: frame, shape: hookShape)
                let countBefore = events.count

                // Gate probabilities replace the coarse whole-bar silence: the anchor note
                // plays reliably while later hook notes thin out progressively, so bars breathe
                // naturally rather than block-silencing every 4th bar.
                let melodyGate:  [Double] = isIntroOutro ? [] : [0.95, 0.78, 0.72, 0.65]
                let harmonyGate: [Double] = isIntroOutro ? [] : [0.88, 0.70, 0.65, 0.58]

                emitJMJVoice(notes: notes, barStart: barStart, stepDur: stepDur,
                             offset: 0, legato: true, bar: bar, rng: &rng, events: &events,
                             gateProbs: melodyGate)
                // No harmony voice during intro/outro — keep it minimal
                if addHarmony && !isIntroOutro {
                    let keyPC     = keySemitone(frame.key)
                    let harmNotes = notes.map { note -> Int in
                        // Diatonic third: scale degree +2 above each melody note.
                        // Using a fixed chromatic interval (e.g. +3) causes out-of-scale
                        // clashes whenever the melody note is not the root (e.g. C → Eb
                        // in A Aeolian, which is a semitone outside the scale).
                        Swift.min(diatonicThirdAbove(note, keyPC: keyPC, mode: frame.mode), 84)
                    }
                    emitJMJVoice(notes: harmNotes, barStart: barStart, stepDur: stepDur,
                                 offset: stepDur, legato: true, bar: bar, rng: &rng, events: &events,
                                 gateProbs: harmonyGate)
                }
                if isIntroOutro {
                    for i in countBefore..<events.count {
                        let ev = events[i]
                        events[i] = MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                              velocity: UInt8(max(55, Int(ev.velocity) * 82 / 100)),
                                              durationSteps: ev.durationSteps)
                    }
                }
            }
        }
        return events
    }

    // MARK: - KOS-RTHM-003: JMJ Oxygène — single voice ascending then descending, quarter legato

    private static func generateJMJOxygene(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {

        // Quarter note (4 steps) dominant — very spacious
        let stepDur = rng.nextDouble() < 0.70 ? 4 : 2

        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard !section.label.isBridge else { continue }
            let isIntro = section.label == .intro
            let isOutro = section.label == .outro
            for bar in section.startBar..<section.endBar {
                if isIntro && bar < section.endBar - 2 { continue }
                if isOutro && bar >= section.startBar + 2 { continue }
                let isIntroOutro = isIntro || isOutro

                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart    = bar * 16
                let notes       = jmjOxygeneNotes(entry: entry, frame: frame)
                let countBefore = events.count

                let ascending = (bar % 2) == 0
                let ordered   = ascending ? notes : notes.reversed() as [Int]
                var stepPos = 0
                var noteIdx = 0
                while stepPos + stepDur <= 16 {
                    let note = ordered[noteIdx % ordered.count]
                    noteIdx += 1
                    let dur = stepDur + 1
                    let vel = UInt8(68 + rng.nextInt(upperBound: 13))  // 68–80
                    events.append(MIDIEvent(stepIndex: barStart + stepPos,
                                            note: UInt8(note), velocity: vel, durationSteps: dur))
                    stepPos += stepDur
                }
                if isIntroOutro {
                    for i in countBefore..<events.count {
                        let ev = events[i]
                        events[i] = MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                              velocity: UInt8(max(55, Int(ev.velocity) * 82 / 100)),
                                              durationSteps: ev.durationSteps)
                    }
                }
            }
        }
        return events
    }

    // MARK: - KOS-RTHM-004: Electric Buddha Groove — pentatonic interlocking voices, driving

    private static func generateElectricBuddha(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {

        // 2 or 3 interlocking voices
        let voiceCount = rng.nextDouble() < 0.50 ? 2 : 3
        // Groove pattern offsets per voice (voice 0 on beat, voice 1 syncopated)
        let voiceStepOffsets = [0, 2, 1]

        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard !section.label.isBridge else { continue }
            let isIntro = section.label == .intro
            let isOutro = section.label == .outro
            for bar in section.startBar..<section.endBar {
                if isIntro && bar < section.endBar - 2 { continue }
                if isOutro && bar >= section.startBar + 2 { continue }
                let isIntroOutro = isIntro || isOutro

                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart    = bar * 16
                let pentNotes   = pentatonicNotes(entry: entry, frame: frame)
                let countBefore = events.count

                // Beat-1 anchor always present
                let rootNote  = pentNotes[0]
                let anchorVel = UInt8(82 + rng.nextInt(upperBound: 10))
                events.append(MIDIEvent(stepIndex: barStart, note: UInt8(rootNote),
                                        velocity: anchorVel, durationSteps: 4))

                // Interlocking groove — skip in intro/outro (anchor only)
                // Cap: max 6 notes per bar total (anchor + 5 groove); prevents over-dense
                // bars from KOS-RTHM-004 (Study 02 found up to 13.9 notes/bar in Flexure).
                if !isIntroOutro {
                    let grooveSteps = [2, 3, 5, 6, 9, 10, 13, 14]
                    grooveLoop: for vIdx in 0..<voiceCount {
                        let noteOffset = vIdx % pentNotes.count
                        let note       = pentNotes[(noteOffset + vIdx) % pentNotes.count]
                        let stepShift  = voiceStepOffsets[vIdx % voiceStepOffsets.count]
                        for gs in grooveSteps {
                            guard events.count - countBefore < 6 else { break grooveLoop }
                            let s = gs + stepShift
                            guard s < 16 else { continue }
                            if rng.nextDouble() < 0.35 { continue }
                            let vel = UInt8(78 + rng.nextInt(upperBound: 15))
                            events.append(MIDIEvent(stepIndex: barStart + s, note: UInt8(note),
                                                    velocity: vel, durationSteps: 1))
                        }
                    }
                }
                if isIntroOutro {
                    for i in countBefore..<events.count {
                        let ev = events[i]
                        events[i] = MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                              velocity: UInt8(max(55, Int(ev.velocity) * 82 / 100)),
                                              durationSteps: ev.durationSteps)
                    }
                }
            }
        }
        return events
    }

    // MARK: - KOS-RTHM-005: JMJ Dual-Rate — two voices at different sequencer rates, gated
    // Voice A cycles the note pool at 8th-note rate (busier, higher velocity).
    // Voice B cycles the reversed pool at quarter-note rate (slower, quieter harmonic anchor).
    // Each step is independently gated so the two rates shift in and out of phase naturally.

    private static func generateJMJDualRate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Gate probability per step position: index 0 anchors the bar; later positions thin out.
        let gateA: [Double] = [0.95, 0.70, 0.70, 0.65, 0.65, 0.68, 0.68, 0.62]  // 8 × 8th-note
        let gateB: [Double] = [0.95, 0.82, 0.80, 0.78]                           // 4 × quarter-note

        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard !section.label.isBridge else { continue }
            let isIntro = section.label == .intro
            let isOutro = section.label == .outro
            for bar in section.startBar..<section.endBar {
                if isIntro && bar < section.endBar - 2 { continue }
                if isOutro && bar >= section.startBar + 2 { continue }
                let isIntroOutro = isIntro || isOutro

                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart  = bar * 16
                let notesA    = dualRateNotes(entry: entry, frame: frame)
                let notesB    = notesA.reversed() as [Int]
                let countBefore = events.count

                // Voice A: 8th-note rate — melodic, gated per step in body sections
                var stepPos = 0
                var noteIdx = 0
                while stepPos < 16 {
                    let prob = isIntroOutro ? 1.0 : (noteIdx < gateA.count ? gateA[noteIdx] : gateA.last!)
                    if rng.nextDouble() < prob {
                        let note = notesA[noteIdx % notesA.count]
                        let vel  = UInt8(74 + rng.nextInt(upperBound: 15))  // 74–88
                        events.append(MIDIEvent(stepIndex: barStart + stepPos,
                                                note: UInt8(Swift.max(60, Swift.min(80, note))),
                                                velocity: vel, durationSteps: 3))
                    }
                    noteIdx += 1
                    stepPos += 2
                }

                // Voice B: quarter-note rate — quieter harmonic anchor; body only
                if !isIntroOutro {
                    stepPos = 0
                    noteIdx = 0
                    while stepPos < 16 {
                        let prob = noteIdx < gateB.count ? gateB[noteIdx] : gateB.last!
                        if rng.nextDouble() < prob {
                            let note = notesB[noteIdx % notesB.count]
                            let vel  = UInt8(62 + rng.nextInt(upperBound: 13))  // 62–74
                            events.append(MIDIEvent(stepIndex: barStart + stepPos,
                                                    note: UInt8(Swift.max(60, Swift.min(80, note))),
                                                    velocity: vel, durationSteps: 5))
                        }
                        noteIdx += 1
                        stepPos += 4
                    }
                }

                if isIntroOutro {
                    for i in countBefore..<events.count {
                        let ev = events[i]
                        events[i] = MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                              velocity: UInt8(max(55, Int(ev.velocity) * 82 / 100)),
                                              durationSteps: ev.durationSteps)
                    }
                }
            }
        }
        return events
    }

    // MARK: - KOS-RTHM-006: Kraftwerk Locked Pulse

    private static func generateKraftwerkLocked(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Determine cell pitches from the first body bar — locked for the entire song.
        // Using a fixed pitch cell regardless of chord changes gives the mechanical indifference.
        let bodySections = structure.sections.filter { $0.label != .intro && $0.label != .outro }
        let firstBodyBar = bodySections.first?.startBar ?? 0
        guard let firstEntry = tonalMap.entry(atBar: firstBodyBar) else { return [] }

        let rootPC = (keySemitone(frame.key) + degreeSemitone(firstEntry.chordWindow.chordRoot)) % 12
        let mode   = firstEntry.sectionMode
        let third  = mode.nearestInterval(3)

        func place(_ pc: Int) -> Int {
            var m = 60 + rootPC + pc
            while m > 76 { m -= 12 }
            while m < 58 { m += 12 }
            return m
        }
        let r = place(0); let t = place(third); let f = place(7)

        // Pick one of 4 cell patterns once — locked for the song
        let cellPatterns: [[Int]] = [
            [r, t, r, f],
            [r, f, t, f],
            [r, t, f, t],
            [r, f, r, t],
        ]
        let basePattern = cellPatterns[rng.nextInt(upperBound: cellPatterns.count)]

        // Octave-displaced variant: same cell, +12 semitones, clamped to ≤ 86.
        // Fires for 4 bars at every 32-bar boundary within the body (starting at body bar 32),
        // then snaps back. Fully deterministic — the sequence "jumps" at the same point every cycle.
        let octavePattern = basePattern.map { min($0 + 12, 86) }

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro && section.label != .outro else { continue }
            guard !section.label.isBridge else { continue }
            let barStart   = bar * 16
            let barInBody  = bar - firstBodyBar

            // B section (or bar-count fallback for single_evolving) drives octave displacement.
            let inOctaveWindow: Bool
            if structure.hasBSection {
                inOctaveWindow = structure.inBSection(atBar: bar)
            } else {
                inOctaveWindow = barInBody >= 32 && barInBody % 32 < 4
            }
            let pattern = inOctaveWindow ? octavePattern : basePattern

            for i in 0..<8 {  // 8 eighth notes per bar (step duration = 2)
                let pitch = pattern[i % pattern.count]
                let vel: UInt8 = i == 0
                    ? UInt8(82 + rng.nextInt(upperBound: 7))   // beat-1 accent
                    : UInt8(62 + rng.nextInt(upperBound: 11))  // all other 8ths
                events.append(MIDIEvent(stepIndex: barStart + i * 2,
                                        note: UInt8(pitch), velocity: vel, durationSteps: 2))
            }
        }
        return events
    }

    // MARK: - KOS-RTHM-007: Pitch-Drifting Sequence (TD/Schulze)

    private static func generatePitchDrifting(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro && section.label != .outro else { continue }
            guard !section.label.isBridge else { continue }
            guard let entry = tonalMap.entry(atBar: bar) else { continue }

            let mode  = entry.sectionMode
            let scale = mode.intervals

            // Per-section pitch arch: each A and B section gets its own rise-and-fall arc.
            // This way the A section returns and the B section's arch is independent.
            let sectionLen = max(1, section.lengthBars)
            let halfLen    = max(1, sectionLen / 2)
            let barInSection = bar - section.startBar

            let peakDeg    = min(halfLen / 4, scale.count - 1)
            let transposeDeg: Int
            if barInSection < halfLen {
                transposeDeg = min(barInSection / 4, peakDeg)
            } else {
                transposeDeg = max(0, peakDeg - (barInSection - halfLen) / 4)
            }
            let transposeInterval = scale[transposeDeg % scale.count]

            let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
            let third  = mode.nearestInterval(3)

            func place(_ pc: Int) -> Int {
                var m = 60 + rootPC + pc + transposeInterval
                while m > 80 { m -= 12 }
                while m < 56 { m += 12 }
                return m
            }

            // 4-step quarter-note sequence: root → third → fifth → root
            let sequence  = [place(0), place(third), place(7), place(0)]
            let gateProbs = [0.92, 0.78, 0.78, 0.78]
            let barStart  = bar * 16

            for (i, pitch) in sequence.enumerated() {
                guard rng.nextDouble() < gateProbs[i] else { continue }
                let vel = UInt8(68 + rng.nextInt(upperBound: 18))
                events.append(MIDIEvent(stepIndex: barStart + i * 4,
                                        note: UInt8(pitch), velocity: vel, durationSteps: 4))
            }
        }
        return events
    }

    // MARK: - KOS-RTHM-008: Oxygène 8-bar Arc

    private static func generateOxygene8Bar(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard section.label != .intro && section.label != .outro else { continue }
            guard !section.label.isBridge else { continue }
            guard bar % 8 == 0 else { continue }  // arc starts every 8 bars
            guard let entry = tonalMap.entry(atBar: bar) else { continue }

            let ascending  = (bar / 8) % 2 == 0
            let noteCount  = 5 + rng.nextInt(upperBound: 3)  // 5–7 notes
            let rootPC     = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
            let mode       = entry.sectionMode
            let third      = mode.nearestInterval(3)
            let flat7      = mode.nearestInterval(10)

            // Build a 2-octave scale pool in MIDI 58–82
            var pool: [Int] = []
            for pc in [0, 2, third, 5, 7, flat7, 12, 12 + third, 12 + 7] {
                var m = 60 + rootPC + pc
                while m > 82 { m -= 12 }
                while m < 58 { m += 12 }
                if !pool.contains(m) { pool.append(m) }
            }
            pool.sort()
            guard pool.count >= 3 else { continue }

            let arcPool   = ascending ? pool : pool.reversed() as [Int]
            let maxStart  = max(0, arcPool.count - noteCount)
            let startIdx  = maxStart > 0 ? rng.nextInt(upperBound: maxStart) : 0
            let arcNotes  = Array(arcPool[startIdx ..< min(startIdx + noteCount, arcPool.count)])

            // Spread notes evenly across 128 steps (8 bars)
            let totalSteps   = 8 * 16
            let stepPerNote  = totalSteps / arcNotes.count
            let barStart     = bar * 16

            for (i, note) in arcNotes.enumerated() {
                let jitter = rng.nextInt(upperBound: 5) - 2  // ±2 steps timing humanise
                let stepOff = max(0, i * stepPerNote + jitter)
                let dur     = max(12, stepPerNote - 4 + rng.nextInt(upperBound: 9))
                let vel     = UInt8(58 + rng.nextInt(upperBound: 22))
                events.append(MIDIEvent(stepIndex: barStart + stepOff,
                                        note: UInt8(note), velocity: vel, durationSteps: dur))
            }
        }
        return events
    }

    // MARK: - Bridge A-1: full-bridge ascending or descending arpeggio phrase
    // Plays throughout the entire .bridge section alongside the main groove + drum fills.
    // Direction: ascending 67% (startBar % 3 != 2), descending 33% — same hash used in bass/pads.
    // Phase 0: 2 anchor hits (beats 1+3) — quiet, establishes register.
    // Phase 1: 2-note step (beats 1+2) — motion begins.
    // Phase 2: 4-note walk through chord tones on each beat — full direction established.
    // Phase 3: 4-note walk reversed direction — arrives at the destination, launching B section.
    // Register: MIDI 60–72, distinct from bass (36–55) and drums.

    private static func generateBridgeA1Arp(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard section.label == .bridge else { continue }
            let bridgeLen = max(1, section.endBar - section.startBar)
            let ascending = section.startBar % 3 != 2
            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let barInBridge = bar - section.startBar
                let phase       = min(3, barInBridge * 4 / bridgeLen)
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)

                // Place a pitch class in the mid register (MIDI 60–72)
                func place(_ pc: Int) -> Int {
                    var m = 60 + rootPC + pc
                    while m > 72 { m -= 12 }
                    while m < 60 { m += 12 }
                    return m
                }

                let lo = place(0)        // root in register
                let md = place(third)    // 3rd
                let hi = place(7)        // 5th
                let tp = place(12)       // octave (wraps into same register)

                // Ascending: low→mid→hi→top. Descending: reverse.
                let walk4 = ascending ? [lo, md, hi, tp] : [tp, hi, md, lo]
                let walk2 = ascending ? [lo, md]          : [tp, hi]
                let anchor = ascending ? lo               : tp

                let barStart = bar * 16

                switch phase {
                    case 0:
                        // 2 anchor hits: beats 1 and 3
                        for step in [0, 8] {
                            let vel = UInt8(max(20, min(127, 52 + rng.nextInt(upperBound: 8) - 4)))
                            events.append(MIDIEvent(stepIndex: barStart + step,
                                                    note: UInt8(anchor), velocity: vel, durationSteps: 6))
                        }
                    case 1:
                        // 2-note step: beats 1+2
                        for (i, note) in walk2.enumerated() {
                            let vel = UInt8(max(20, min(127, 58 + rng.nextInt(upperBound: 8) - 4)))
                            events.append(MIDIEvent(stepIndex: barStart + i * 4,
                                                    note: UInt8(note), velocity: vel, durationSteps: 5))
                        }
                    case 2:
                        // 4-note walk, one per beat
                        for (i, note) in walk4.enumerated() {
                            let vel = UInt8(max(20, min(127, 64 + rng.nextInt(upperBound: 10) - 5)))
                            events.append(MIDIEvent(stepIndex: barStart + i * 4,
                                                    note: UInt8(note), velocity: vel, durationSteps: 4))
                        }
                    default:
                        // Phase 3: reverse direction — arrival signal before B section
                        let arrival = walk4.reversed()
                        for (i, note) in arrival.enumerated() {
                            let vel = UInt8(max(20, min(127, 72 + rng.nextInt(upperBound: 10) - 5)))
                            events.append(MIDIEvent(stepIndex: barStart + i * 4,
                                                    note: UInt8(note), velocity: vel, durationSteps: 3))
                        }
                    }
            }
        }
        return events
    }

    // MARK: - Bridge A-2 melodic response (call + response)
    // The "call" is the synchronized drum+pads+bass hit on even bridge bars.
    // The "response" fires here on the odd (non-hit) bars — a melodic phrase chosen once
    // per bridge and repeated consistently across every response bar (same form twice).
    //
    // 6 phrase variants (chosen once at bridge start via rng):
    //   0 — ascending arc:   root → 3rd → 5th on beats 1,2,3
    //   1 — descending arc:  5th  → 3rd → root on beats 1,2,3
    //   2 — arch:            root → 5th → 3rd (rise then partial fall)
    //   3 — two long notes:  root held 6 steps, then 5th held 5 steps — very spacious
    //   4 — syncopated:      root beat 1 (short), 3rd "and of 2" (step 6), 5th beat 4 (step 12)
    //   5 — high-root drop:  root (upper octave) → 5th → root (lower) — octave gesture

    private static func generateBridgeAltArp(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard section.label == .bridgeAlt else { continue }
            // Choose one phrase variant (0-5) for all response bars in this bridge.
            let mainVariant = rng.nextInt(upperBound: 6)
            for bar in section.startBar..<section.endBar {
                let bridgeBar = bar - section.startBar
                guard let entry = tonalMap.entry(atBar: bar) else { continue }

                // Call bars (even): always held root — clean space before the response.
                if bridgeBar % 2 == 0 {
                    let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                    func placeC(_ pc: Int) -> Int {
                        var m = 60 + rootPC + pc
                        while m > 72 { m -= 12 }
                        while m < 60 { m += 12 }
                        return m
                    }
                    let vel = UInt8(48 + rng.nextInt(upperBound: 12))  // 48–59, background
                    events.append(MIDIEvent(stepIndex: bar * 16 + 4, note: UInt8(placeC(0)),
                                            velocity: vel, durationSteps: 10))
                    continue
                }

                // Response bars (odd): melodic phrase variant
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)

                func place(_ pc: Int) -> Int {
                    var m = 60 + rootPC + pc
                    while m > 72 { m -= 12 }
                    while m < 60 { m += 12 }
                    return m
                }
                let lo = place(0)
                let md = place(third)
                let hi = place(7)
                var hiRoot = rootPC + 72
                while hiRoot > 84 { hiRoot -= 12 }
                while hiRoot < 60 { hiRoot += 12 }

                func vel(_ base: Int) -> UInt8 { UInt8(max(20, min(127, base + rng.nextInt(upperBound: 14) - 7))) }
                let barStart = bar * 16

                switch mainVariant {
                case 0:  // ascending arc
                    for (i, n) in [lo, md, hi].enumerated() {
                        events.append(MIDIEvent(stepIndex: barStart + i * 4, note: UInt8(n), velocity: vel(68), durationSteps: 4))
                    }
                case 1:  // descending arc
                    for (i, n) in [hi, md, lo].enumerated() {
                        events.append(MIDIEvent(stepIndex: barStart + i * 4, note: UInt8(n), velocity: vel(68), durationSteps: 4))
                    }
                case 2:  // arch: up then partial fall
                    for (i, n) in [lo, hi, md].enumerated() {
                        events.append(MIDIEvent(stepIndex: barStart + i * 4, note: UInt8(n), velocity: vel(68), durationSteps: 4))
                    }
                case 3:  // two long notes — spacious
                    events.append(MIDIEvent(stepIndex: barStart,     note: UInt8(lo), velocity: vel(72), durationSteps: 6))
                    events.append(MIDIEvent(stepIndex: barStart + 8, note: UInt8(hi), velocity: vel(64), durationSteps: 5))
                case 4:  // syncopated: beat 1, and-of-2, beat 4
                    events.append(MIDIEvent(stepIndex: barStart,      note: UInt8(lo), velocity: vel(68), durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: barStart + 6,  note: UInt8(md), velocity: vel(62), durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: barStart + 12, note: UInt8(hi), velocity: vel(72), durationSteps: 3))
                default:  // high-root drop: upper root → 5th → lower root
                    for (i, n) in [hiRoot, hi, lo].enumerated() {
                        events.append(MIDIEvent(stepIndex: barStart + i * 4, note: UInt8(n), velocity: vel(65), durationSteps: 4))
                    }
                }
            }
        }
        return events
    }

    // MARK: - Note set builders

    /// 5-note modal subset in MIDI 55–72 (used by KOS-RTHM-001)
    // MARK: - Long intro hint
    // For intros of 6+ bars, plays a sparse ascending figure starting at the midpoint
    // (bar 3 of a 6-bar intro, bar 4 of an 8-bar intro). Stops before the normal
    // 2-bar spin-up begins. Very quiet — signals that music is building without
    // competing with the existing spin-up.

    private static func generateLongIntroHint(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        guard let intro = structure.sections.first(where: { $0.label == .intro }) else { return [] }
        let introLen = intro.endBar - intro.startBar
        guard introLen >= 6 else { return [] }

        // Hint window: midpoint up to (but not including) the normal 2-bar spin-up
        let hintStart = intro.startBar + introLen / 2   // bar 3 (6-bar) or bar 4 (8-bar)
        let hintEnd   = intro.endBar - 2                // spin-up begins here

        guard let entry = tonalMap.entry(atBar: hintStart) else { return [] }
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let mode   = entry.sectionMode

        // Build a short ascending scale fragment: root, 3rd, 5th, octave (4 notes max)
        // Register: mid-upper (MIDI 60–79) to sit above bass but below spin-up texture
        let intervals = [0, mode.nearestInterval(3), 7, 12]
        var phrase: [Int] = []
        for iv in intervals {
            var midi = 60 + rootPC + iv
            while midi > 79 { midi -= 12 }
            while midi < 60 { midi += 12 }
            phrase.append(midi)
        }

        // Spread notes across the hint window — one note roughly every 4-6 steps,
        // starting on beat 2 (step 4) of the first hint bar for a subtle late entry
        var events: [MIDIEvent] = []
        let windowSteps = hintEnd * 16 - (hintStart * 16 + 4)
        guard windowSteps > 0 else { return [] }
        let spacing = max(5, windowSteps / phrase.count)

        var step = hintStart * 16 + 4   // beat 2 of the first hint bar
        for note in phrase {
            guard step < hintEnd * 16 else { break }
            let vel = UInt8(38 + rng.nextInt(upperBound: 16))   // 38–53, very quiet
            let dur = min(spacing - 1, 6)
            events.append(MIDIEvent(stepIndex: step, note: UInt8(note),
                                    velocity: vel, durationSteps: dur))
            step += spacing
        }
        return events
    }

    private static func fiveNoteSubset(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> [Int] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let mode   = entry.sectionMode
        let third  = mode.nearestInterval(3)
        let flat7  = mode.nearestInterval(10)
        var notes: [Int] = []
        for st in [0, third, 7, flat7, 12] {
            var midi = 60 + rootPC + st
            while midi > 72 { midi -= 12 }
            while midi < 55 { midi += 12 }
            notes.append(midi)
        }
        return notes
    }

    /// JMJ hook note set: 4 notes in MIDI 60–80, scale degrees depend on shape
    private static func jmjHookNotes(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, shape: Int) -> [Int] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // Use chord type (not song mode) for third quality — avoids C natural against a major chord
        // in a Dorian/Aeolian song (mode.nearestInterval gives minor third regardless of chord type).
        let isMajorChord: Bool
        switch entry.chordWindow.chordType {
        case .major, .sus2, .sus4, .add9, .dom7: isMajorChord = true
        default: isMajorChord = false
        }
        let third  = isMajorChord ? 4 : 3
        let fifth  = 7
        let octave = 12

        func place(_ pc: Int) -> Int {
            var m = 60 + rootPC + pc
            while m > 80 { m -= 12 }
            while m < 60 { m += 12 }
            return m
        }
        switch shape {
        case 0:  return [place(0), place(third), place(fifth), place(third)]   // pendulum
        case 1:  return [place(0), place(third), place(fifth), place(octave)]  // ascend
        default: return [place(0), place(2), place(third), place(fifth)]        // scale walk (adds 2nd)
        }
    }

    /// JMJ Oxygène 4-note set, quarter-note register MIDI 58–78
    private static func jmjOxygeneNotes(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> [Int] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // Use chord type (not song mode) — same fix as jmjHookNotes
        let isMajorChord: Bool
        switch entry.chordWindow.chordType {
        case .major, .sus2, .sus4, .add9, .dom7: isMajorChord = true
        default: isMajorChord = false
        }
        let third  = isMajorChord ? 4 : 3
        let fifth  = 7
        let octave = 12
        func place(_ pc: Int) -> Int {
            var m = 60 + rootPC + pc
            while m > 78 { m -= 12 }
            while m < 58 { m += 12 }
            return m
        }
        return [place(0), place(third), place(fifth), place(octave)]
    }

    /// Pentatonic major/minor note set for KOS-RTHM-004 in MIDI 58–76.
    /// Always anchored to the song tonic (not the chord root) so notes stay in key
    /// even when Modal Drift selects a non-tonic chord root.
    private static func pentatonicNotes(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> [Int] {
        let rootPC = keySemitone(frame.key)   // tonic-anchored — was: (keySemitone + chordRoot offset)
        let mode   = entry.sectionMode
        // Minor pentatonic: root, b3, 4, 5, b7
        // Major pentatonic: root, 2, 3, 5, 6
        // Use mode to pick flavour
        let third  = mode.nearestInterval(3)
        let fourth = mode.nearestInterval(5)
        let sixth  = mode.nearestInterval(9)
        func place(_ pc: Int) -> Int {
            var m = 60 + rootPC + pc
            while m > 76 { m -= 12 }
            while m < 58 { m += 12 }
            return m
        }
        return [place(0), place(third), place(fourth), place(7), place(sixth)]
    }

    /// KOS-RTHM-005 note pool: root, modal 3rd, 5th, flat-7 in MIDI 60–80.
    /// Tonic-anchored to stay in key regardless of Modal Drift chord root.
    private static func dualRateNotes(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> [Int] {
        let rootPC = keySemitone(frame.key)   // tonic-anchored — was: (keySemitone + chordRoot offset)
        let mode   = entry.sectionMode
        let third  = mode.nearestInterval(3)
        let flat7  = mode.nearestInterval(10)
        func place(_ pc: Int) -> Int {
            var m = 60 + rootPC + pc
            while m > 80 { m -= 12 }
            while m < 60 { m += 12 }
            return m
        }
        return [place(0), place(third), place(7), place(flat7)]
    }

    // MARK: - KOS-RTHM-001 helpers (TD style)

    private static func glacialModulate(notes: [Int], bar: Int, rng: inout SeededRNG) -> [Int] {
        guard bar > 0 && bar % 16 == 0 else { return notes }
        var result = notes
        let idx = rng.nextInt(upperBound: result.count)
        result[idx] = Swift.max(40, Swift.min(96, result[idx] + (rng.nextDouble() < 0.5 ? 1 : -1)))
        return result
    }

    private static func buildArpPattern(notes: [Int], shape: Int, patternLen: Int, bar: Int) -> [Int] {
        switch shape {
        case 0: return Array(notes.prefix(patternLen))
        case 1:
            let q = [notes[0], notes.count > 1 ? notes[1] : notes[0],
                     notes.count > 2 ? notes[2] : notes[0],
                     notes.count > 4 ? notes[4] : notes[0]]
            return Array(q.prefix(patternLen))
        case 2:
            if notes.count >= 4 {
                return Array([notes[0], notes[2], notes[4 % notes.count], notes[1]].prefix(patternLen))
            }
            return Array(notes.prefix(patternLen))
        case 3:
            if notes.count >= 3 {
                return Array([notes[0], notes[1], notes[2], notes[1], notes[0]].prefix(patternLen))
            }
            return Array(notes.prefix(patternLen))
        default:
            if notes.count >= 3 {
                return Array([notes[0], notes[1], notes[1], notes[2],
                              notes[1], notes[0], notes[0], notes[0]].prefix(patternLen))
            }
            return Array(notes.prefix(patternLen))
        }
    }

    private static func shufflePattern(_ pattern: [Int], seed: Int, rng: inout SeededRNG) -> [Int] {
        guard seed > 0 && !pattern.isEmpty else { return pattern }
        let offset = seed % pattern.count
        return Array(pattern[offset...] + pattern[..<offset])
    }

    private static func emitTDVoice(
        pattern: [Int], skipPositions: Set<Int>,
        barStart: Int, stepDuration: Int, voiceOffset: Int,
        bar: Int, rng: inout SeededRNG, events: inout [MIDIEvent]
    ) {
        guard !pattern.isEmpty else { return }
        let reversed = (bar / 32) % 2 == 1
        let resolved = reversed ? pattern.reversed() as [Int] : pattern
        var stepPos = voiceOffset
        var noteIdx = 0
        while stepPos < 16 {
            let patIdx = noteIdx % resolved.count
            noteIdx += 1
            if skipPositions.contains(patIdx) { stepPos += stepDuration; continue }
            // Per-bar gate: pattern anchor (first position each cycle) plays reliably;
            // inner positions thin out, creating organic bar-to-bar variation.
            let gateProb = patIdx == 0 ? 0.96 : 0.70
            if rng.nextDouble() >= gateProb { stepPos += stepDuration; continue }
            let note = Swift.max(55, Swift.min(72, resolved[patIdx]))
            let dur  = stepDuration == 1 && rng.nextDouble() < 0.15 ? 2 : stepDuration
            let vel  = UInt8(95 + rng.nextInt(upperBound: 6))
            events.append(MIDIEvent(stepIndex: Swift.min(barStart + stepPos, barStart + 15),
                                    note: UInt8(note), velocity: vel, durationSteps: dur))
            stepPos += stepDuration
        }
    }

    private static func emitLowAnchor(
        barStart: Int, entry: TonalGovernanceEntry,
        frame: GlobalMusicalFrame, rng: inout SeededRNG, events: inout [MIDIEvent]
    ) {
        for beat in 0..<4 {
            guard rng.nextDouble() < 0.20 else { continue }
            let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
            let anchor = Swift.max(28, Swift.min(55, 60 + rootPC + 7 - 24))
            let stepOff = beat * 4 + rng.nextInt(upperBound: 4)
            events.append(MIDIEvent(stepIndex: Swift.min(barStart + stepOff, barStart + 15),
                                    note: UInt8(anchor),
                                    velocity: UInt8(40 + rng.nextInt(upperBound: 16)),
                                    durationSteps: 2))
        }
    }

    // MARK: - KOS-RTHM-002 helpers

    /// Returns the MIDI note a diatonic third (scale degree +2) above `note`.
    /// Correctly handles all scale positions — never produces out-of-scale pitches.
    private static func diatonicThirdAbove(_ note: Int, keyPC: Int, mode: Mode) -> Int {
        let scale      = mode.intervals  // e.g. Aeolian: [0,2,3,5,7,8,10]
        let relPC      = (note % 12 - keyPC + 12) % 12
        // Find which scale degree this pitch class best matches
        let degIdx     = scale.enumerated().min(by: { abs($0.element - relPC) < abs($1.element - relPC) })?.offset ?? 0
        let thirdIdx   = (degIdx + 2) % scale.count
        var semitones  = scale[thirdIdx] - scale[degIdx]
        if semitones <= 0 { semitones += 12 }  // wrap up if third crosses the octave
        return note + semitones
    }

    private static func emitJMJVoice(
        notes: [Int], barStart: Int, stepDur: Int, offset: Int,
        legato: Bool, bar: Int, rng: inout SeededRNG, events: inout [MIDIEvent],
        gateProbs: [Double] = []
    ) {
        guard !notes.isEmpty else { return }
        var stepPos = offset
        var noteIdx = 0
        while stepPos < 16 {
            let prob      = noteIdx < gateProbs.count ? gateProbs[noteIdx] : (gateProbs.last ?? 1.0)
            let shouldPlay = gateProbs.isEmpty || rng.nextDouble() < prob
            if shouldPlay {
                let note    = notes[noteIdx % notes.count]
                let dur     = legato ? stepDur + 1 : stepDur
                let vel     = UInt8(72 + rng.nextInt(upperBound: 17))  // 72–88
                let clamped = Swift.max(55, Swift.min(84, note))
                events.append(MIDIEvent(stepIndex: barStart + stepPos,
                                        note: UInt8(clamped), velocity: vel, durationSteps: dur))
            }
            noteIdx += 1
            stepPos += stepDur
        }
    }

    // MARK: - KOS-RTHM-009: Craven Faults Phase Drift
    // 5-note cell at 3-step spacing (15 steps total — coprime to 16-step bar).
    // Because 15 and 16 are coprime, each successive bar begins on a different cell step,
    // causing the material to drift slowly through all positions over 15 bars.
    // startNote advances by 1 per bar (5-bar drift cycle), 80% gate, MIDI 58–75.

    private static func generateCravenFaultsPhase(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        for section in structure.sections {
            guard !section.label.isBridge else { continue }
            let isIntro = section.label == .intro
            let isOutro = section.label == .outro

            for bar in section.startBar..<section.endBar {
                if isIntro && bar < section.endBar - 2 { continue }
                if isOutro && bar >= section.startBar + 2 { continue }
                guard let entry = tonalMap.entry(atBar: bar) else { continue }

                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)
                let second = mode.nearestInterval(2)

                // Build 5-note cell: root, 2nd, 3rd, 5th, 3rd (modal texture, not a scale run)
                func place(_ pc: Int) -> Int {
                    var m = 60 + rootPC + pc
                    while m > 75 { m -= 12 }
                    while m < 58 { m += 12 }
                    return m
                }
                let cell = [place(0), place(second), place(third), place(7), place(third)]

                // Starting note drifts +1 per bar over a 5-bar cycle
                let startNote = bar % 5
                let barStart  = bar * 16

                // Emit notes at 3-step intervals within the bar (steps 0,3,6,9,12 = 5 hits max)
                for i in 0..<5 {
                    let step = i * 3
                    guard step < 16 else { break }
                    guard rng.nextDouble() < 0.80 else { continue }  // 80% gate
                    let cellIdx = (startNote + i) % cell.count
                    let note    = cell[cellIdx]
                    let vel     = UInt8(52 + rng.nextInt(upperBound: 17))  // 52–68
                    events.append(MIDIEvent(stepIndex: barStart + step,
                                            note: UInt8(note), velocity: vel, durationSteps: 2))
                }
            }
        }
        return events
    }

    // MARK: - KOS-RTHM-010: Craven Faults Modular Grit
    // 7-note cell at 2-step spacing (14-step cycle — coprime to 16 but shorter).
    // Phase advances 2 notes per bar over a 7-bar cycle, creating faster drift.
    // 65% gate for main hits; missed positions get 25% chance of a quiet ghost note.
    // Staccato (dur=1), MIDI 58–76, vel 44–60 main / 22–38 ghost.

    private static func generateCravenFaultsGrit(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // 50% chance to drop an octave — lower-mid "cello" register vs default mid register
        let lowOctave = rng.nextDouble() < 0.50
        let (lo, hi) = lowOctave ? (46, 64) : (58, 76)

        for section in structure.sections {
            guard !section.label.isBridge else { continue }
            let isIntro = section.label == .intro
            let isOutro = section.label == .outro

            for bar in section.startBar..<section.endBar {
                if isIntro && bar < section.endBar - 2 { continue }
                if isOutro && bar >= section.startBar + 2 { continue }
                guard let entry = tonalMap.entry(atBar: bar) else { continue }

                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)
                let second = mode.nearestInterval(2)
                let flat7  = mode.nearestInterval(10)

                // Build 7-note cell: root, 3rd, 5th, flat-7, 5th, 3rd, 2nd — symmetrical arch
                func place(_ pc: Int) -> Int {
                    var m = 60 + rootPC + pc
                    while m > hi { m -= 12 }
                    while m < lo { m += 12 }
                    return m
                }
                let cell = [place(0), place(third), place(7), place(flat7),
                             place(7), place(third), place(second)]

                // Phase advances 2 per bar over 7-bar cycle
                let startNote = (bar * 2) % 7
                let barStart  = bar * 16

                // Emit at 2-step intervals (steps 0,2,4,6,8,10,12,14 = 8 positions)
                for i in 0..<8 {
                    let step = i * 2
                    guard step < 16 else { break }
                    let cellIdx = (startNote + i) % cell.count
                    let note    = cell[cellIdx]
                    if rng.nextDouble() < 0.65 {
                        // Main hit
                        let vel = UInt8(44 + rng.nextInt(upperBound: 17))  // 44–60
                        events.append(MIDIEvent(stepIndex: barStart + step,
                                                note: UInt8(note), velocity: vel, durationSteps: 1))
                    } else if rng.nextDouble() < 0.25 {
                        // Ghost note — same pitch, quiet, provides modular "bleed" texture
                        let vel = UInt8(22 + rng.nextInt(upperBound: 17))  // 22–38
                        events.append(MIDIEvent(stepIndex: barStart + step,
                                                note: UInt8(note), velocity: vel, durationSteps: 1))
                    }
                }
            }
        }
        return events
    }
}
