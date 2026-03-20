// CosmicArpeggioGenerator.swift — Cosmic generation step 3 (Rhythm track slot)
// The most important Cosmic generator — replaces RhythmGenerator for Cosmic style.
//
// Rules:
//   COS-ARP-001  Tangerine Dream step-sequencer: multi-voice modal grid, 16th notes,
//                skip positions, parallel voices, glacial modulation. Phaedra/Rubycon era.
//   COS-ARP-002  JMJ Hook: single-voice 4-note ascending hook, 8th/quarter notes,
//                brighter register, occasional harmony voice a 3rd above. Oxygène/Équinoxe era.
//   COS-ARP-003  JMJ Oxygène Oscillation: one voice slowly ascending then descending,
//                quarter-note legato. Very spacious. Classic early JMJ feel.
//   COS-ARP-004  Electric Buddha Groove: pentatonic, 2 interlocking voices, syncopated
//                16th-note grid with quarter-note anchor on beat 1. Driving and accessible.

import Foundation

struct CosmicArpeggioGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {

        let rules:   [String] = ["COS-ARP-001", "COS-ARP-002", "COS-ARP-003", "COS-ARP-004"]
        let weights: [Double] = [0.30,           0.28,           0.27,           0.15]
        let chosenRule = rules[rng.weightedPick(weights)]
        usedRuleIDs.insert(chosenRule)

        switch chosenRule {
        case "COS-ARP-002": return generateJMJHook(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "COS-ARP-003": return generateJMJOxygene(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        case "COS-ARP-004": return generateElectricBuddha(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        default:             return generateTD(frame: frame, structure: structure, tonalMap: tonalMap, rng: &rng)
        }
    }

    // MARK: - COS-ARP-001: Tangerine Dream multi-voice step-sequencer

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
                                              velocity: UInt8(max(42, Int(ev.velocity) * 58 / 100)),
                                              durationSteps: ev.durationSteps)
                    }
                }
            }
        }
        return events
    }

    // MARK: - COS-ARP-002: JMJ Hook — single-voice melodic hook, 8th/quarter dominant

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
            let isIntro = section.label == .intro
            let isOutro = section.label == .outro
            for bar in section.startBar..<section.endBar {
                if isIntro && bar < section.endBar - 2 { continue }
                if isOutro && bar >= section.startBar + 2 { continue }
                let isIntroOutro = isIntro || isOutro

                guard let entry = tonalMap.entry(atBar: bar) else { continue }
                // 1-in-4 bars: silence in body only — intro/outro plays all bars
                if !isIntroOutro && bar % 4 == 3 { continue }

                let barStart    = bar * 16
                let notes       = jmjHookNotes(entry: entry, frame: frame, shape: hookShape)
                let countBefore = events.count

                emitJMJVoice(notes: notes, barStart: barStart, stepDur: stepDur,
                             offset: 0, legato: true, bar: bar, rng: &rng, events: &events)
                // No harmony voice during intro/outro — keep it minimal
                if addHarmony && !isIntroOutro {
                    let mode  = frame.mode
                    let third = mode.nearestInterval(3)
                    let harmNotes = notes.map { Swift.min($0 + third, 84) }
                    emitJMJVoice(notes: harmNotes, barStart: barStart, stepDur: stepDur,
                                 offset: stepDur, legato: true, bar: bar, rng: &rng, events: &events)
                }
                if isIntroOutro {
                    for i in countBefore..<events.count {
                        let ev = events[i]
                        events[i] = MIDIEvent(stepIndex: ev.stepIndex, note: ev.note,
                                              velocity: UInt8(max(42, Int(ev.velocity) * 60 / 100)),
                                              durationSteps: ev.durationSteps)
                    }
                }
            }
        }
        return events
    }

    // MARK: - COS-ARP-003: JMJ Oxygène — single voice ascending then descending, quarter legato

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
                                              velocity: UInt8(max(42, Int(ev.velocity) * 60 / 100)),
                                              durationSteps: ev.durationSteps)
                    }
                }
            }
        }
        return events
    }

    // MARK: - COS-ARP-004: Electric Buddha Groove — pentatonic interlocking voices, driving

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
                                              velocity: UInt8(max(42, Int(ev.velocity) * 60 / 100)),
                                              durationSteps: ev.durationSteps)
                    }
                }
            }
        }
        return events
    }

    // MARK: - Note set builders

    /// 5-note modal subset in MIDI 55–72 (used by COS-ARP-001)
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

    /// Pentatonic major/minor note set for COS-ARP-004 in MIDI 58–76
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

    // MARK: - COS-ARP-001 helpers (TD style)

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

    // MARK: - COS-ARP-002 helper: emit JMJ voice

    private static func emitJMJVoice(
        notes: [Int], barStart: Int, stepDur: Int, offset: Int,
        legato: Bool, bar: Int, rng: inout SeededRNG, events: inout [MIDIEvent]
    ) {
        guard !notes.isEmpty else { return }
        var stepPos = offset
        var noteIdx = 0
        while stepPos < 16 {
            let note = notes[noteIdx % notes.count]
            noteIdx += 1
            let dur  = legato ? stepDur + 1 : stepDur
            let vel  = UInt8(72 + rng.nextInt(upperBound: 17))  // 72–88
            let clamped = Swift.max(55, Swift.min(84, note))
            events.append(MIDIEvent(stepIndex: barStart + stepPos,
                                    note: UInt8(clamped), velocity: vel, durationSteps: dur))
            stepPos += stepDur
        }
    }
}
