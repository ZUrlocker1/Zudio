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
                                 "KOS-RTHM-005", "KOS-RTHM-006", "KOS-RTHM-007", "KOS-RTHM-008"]
        let weights: [Double] = [0.16,           0.15,           0.13,           0.10,
                                 0.14,           0.14,           0.10,           0.08]
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
        default:             events = generateTD(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        }
        // Bridge A-1 (.bridge): arpeggio re-enters in final 2 bars with descending figure
        events += generateBridgeA1Arp(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        // Bridge A-2 (.bridgeAlt call+response): melodic response phrase on non-hit bars
        events += generateBridgeAltArp(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
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
                if !isIntroOutro {
                    let grooveSteps = [2, 3, 5, 6, 9, 10, 13, 14]
                    for vIdx in 0..<voiceCount {
                        let noteOffset = vIdx % pentNotes.count
                        let note       = pentNotes[(noteOffset + vIdx) % pentNotes.count]
                        let stepShift  = voiceStepOffsets[vIdx % voiceStepOffsets.count]
                        for gs in grooveSteps {
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

    // MARK: - Bridge A-1: descending figure in final 2 bars (re-entry signal before B section)
    // Only fires for .bridge (Archetype A-1 escalating drum bridge) sections.
    // Pattern: 5th → descend1 → 5th → descend2 → 5th → descend3, quarter-note durations.

    private static func generateBridgeA1Arp(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard section.label == .bridge else { continue }
            guard section.lengthBars >= 2 else { continue }
            // Only play in the final 2 bars of the bridge
            let startBar = section.endBar - 2
            for bar in startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)
                let fifth  = 7

                func place(_ pc: Int) -> Int {
                    var m = 60 + rootPC + pc
                    while m > 72 { m -= 12 }
                    while m < 60 { m += 12 }
                    return m
                }
                // Descend from 5th: 5th, 3rd, root, alternating with 5th
                let descend = [place(fifth), place(third), place(0), place(fifth),
                               place(third), place(0), place(fifth), place(third)]
                let barStart = bar * 16
                for (i, note) in descend.prefix(4).enumerated() {
                    let vel = UInt8(78 + rng.nextInt(upperBound: 14))
                    events.append(MIDIEvent(stepIndex: barStart + i * 4,
                                            note: UInt8(note), velocity: vel, durationSteps: 4))
                }
            }
        }
        return events
    }

    // MARK: - Bridge A-2 melodic response (call + response)
    // The "call" is the synchronized drum+pads+bass hit on even bridge bars.
    // The "response" fires here on the odd (non-hit) bars — a 3-note melodic phrase
    // in the mid register that makes the silence between hits feel intentional, not empty.
    // Pattern: root → 3rd → 5th over beats 1–3, quarter-note durations, medium velocity.

    private static func generateBridgeAltArp(
        frame: GlobalMusicalFrame, structure: SongStructure,
        tonalMap: TonalGovernanceMap, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for section in structure.sections {
            guard section.label == .bridgeAlt else { continue }
            for bar in section.startBar..<section.endBar {
                let bridgeBar = bar - section.startBar
                guard bridgeBar % 2 == 1 else { continue }   // odd bars = response bars only
                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let third  = mode.nearestInterval(3)
                let fifth  = 7

                func place(_ pc: Int) -> Int {
                    var m = 60 + rootPC + pc
                    while m > 72 { m -= 12 }
                    while m < 60 { m += 12 }
                    return m
                }

                // 3-note ascending response: root → 3rd → 5th, one per beat
                let phrase = [place(0), place(third), place(fifth)]
                let barStart = bar * 16
                for (i, note) in phrase.enumerated() {
                    let vel = UInt8(68 + rng.nextInt(upperBound: 14))
                    events.append(MIDIEvent(stepIndex: barStart + i * 4,
                                            note: UInt8(note), velocity: vel, durationSteps: 4))
                }
            }
        }
        return events
    }

    // MARK: - Note set builders

    /// 5-note modal subset in MIDI 55–72 (used by KOS-RTHM-001)
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
        let mode   = entry.sectionMode
        let third  = mode.nearestInterval(3)
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
        let mode   = entry.sectionMode
        let third  = mode.nearestInterval(3)
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

    /// Pentatonic major/minor note set for KOS-RTHM-004 in MIDI 58–76
    private static func pentatonicNotes(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> [Int] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
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

    /// KOS-RTHM-005 note pool: root, modal 3rd, 5th, flat-7 in MIDI 60–80
    private static func dualRateNotes(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> [Int] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
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
}
