// RhythmGenerator.swift — generation step 8
// Pulse embellishment: melodic ostinato that follows chord changes.
// Register: MIDI 45–76 (low-mid to mid).
//
// Rule catalog:
//   RHY-001: 8th-note stride — alternating root/fifth/third, active Motorik pulse
//   RHY-002: Quarter-note stride — root-anchored, open and spacious
//   RHY-003: Syncopated Motorik — hits at 0,3,6,8,11,14 (3+3+2+3+3+2 feel)
//   RHY-004: 2-bar melodic riff — scale-tone riff cycling over 2 bars
//   RHY-005: Chord stab — short root+third stabs on beats 2 and 4
//   RHY-006: Arpeggio — quarter-note legato, 5 direction variants:
//              0=up, 1=down, 2=up-down bounce, 3=down-up bounce, 4=ping-pong
//
// Pattern type chosen per section; arpeggio direction fixed for the whole song.
// prevNote tracking gives smooth voice leading across bar lines.

struct RhythmGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []

        // Arpeggio direction is fixed for the whole song (consistent feel)
        // 0=up  1=down  2=up-down  3=down-up  4=ping-pong
        let arpDirection = rng.nextInt(upperBound: 5)

        for section in structure.sections {
            // Rhythm is silent in intro/outro
            guard section.label != .intro && section.label != .outro else { continue }

            // Pick pattern type once per section
            let patternWeights: [Double] = [0.30, 0.17, 0.17, 0.13, 0.08, 0.15]
            let patternType = rng.weightedPick(patternWeights)
            switch patternType {
            case 0:  usedRuleIDs.insert("RHY-001")
            case 1:  usedRuleIDs.insert("RHY-002")
            case 2:  usedRuleIDs.insert("RHY-003")
            case 3:  usedRuleIDs.insert("RHY-004")
            case 4:  usedRuleIDs.insert("RHY-005")
            default: usedRuleIDs.insert("RHY-006")
            }

            // prevNote for smooth octave transitions across bar lines
            var prevNote: UInt8? = nil

            // For RHY-004: build a 2-bar riff once per section
            let riffPattern = buildMelodicRiff(rng: &rng)

            for bar in section.startBar..<section.endBar {
                guard let entry = tonalMap.entry(atBar: bar) else { continue }

                // Intensity arc: drives how many steps actually fire
                let intensity = section.subPhaseIntensity(atBar: bar)
                let density: Double
                switch intensity {
                case .low:    density = 0.72
                case .medium: density = 0.88
                case .high:   density = 1.00
                }

                let barStart = bar * 16
                let pitches  = chordPitches(entry: entry, frame: frame, prevNote: prevNote)

                switch patternType {
                case 0:
                    // RHY-001: 8th-note pulse — root on beat 1, cycle root/fifth/third
                    let cycle: [UInt8] = [pitches.root, pitches.fifth, pitches.third, pitches.fifth]
                    for (idx, step) in (Swift.stride(from: 0, to: 16, by: 2)).enumerated() {
                        guard rng.nextDouble() < density else { continue }
                        let note = (step == 0) ? pitches.root : cycle[idx % 4]
                        let vel  = UInt8(step == 0 ? 82 : 62 + rng.nextInt(upperBound: 14))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 2))
                        prevNote = note
                    }

                case 1:
                    // RHY-002: quarter-note, root on 1+3, fifth on 2+4
                    for (i, step) in [0, 4, 8, 12].enumerated() {
                        guard rng.nextDouble() < density else { continue }
                        let note: UInt8 = (i % 2 == 0) ? pitches.root : pitches.fifth
                        let vel  = UInt8(step == 0 ? 86 : 65 + rng.nextInt(upperBound: 12))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 3))
                        prevNote = note
                    }

                case 2:
                    // RHY-003: syncopated Motorik — 3+3+2+3+3+2 pattern
                    let rhy3Cycle: [UInt8] = [pitches.root, pitches.fifth, pitches.third,
                                              pitches.root, pitches.fifth, pitches.flat7]
                    for (i, step) in [0, 3, 6, 8, 11, 14].enumerated() {
                        guard rng.nextDouble() < density else { continue }
                        let note = (step == 0) ? pitches.root : rhy3Cycle[i % rhy3Cycle.count]
                        let vel  = UInt8(step == 0 ? 84 : 63 + rng.nextInt(upperBound: 16))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 2))
                        prevNote = note
                    }

                case 3:
                    // RHY-004: 2-bar melodic riff cycling over the section
                    let riffBar = (bar - section.startBar) % 2
                    let riffSlice = riffBar == 0 ? Array(riffPattern.prefix(4))
                                                 : Array(riffPattern.suffix(4))
                    for (i, step) in [0, 4, 8, 12].enumerated() {
                        guard i < riffSlice.count else { continue }
                        guard rng.nextDouble() < density else { continue }
                        let note = nearestMIDI(
                            target: Int(pitches.root) + riffSlice[i],
                            low: 45, high: 76,
                            prev: prevNote
                        )
                        let vel = UInt8(step == 0 ? 85 : 65 + rng.nextInt(upperBound: 12))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                                velocity: vel, durationSteps: 3))
                        prevNote = note
                    }

                case 4:
                    // RHY-005: chord stab — root+third on beats 2 and 4
                    for step in [4, 12] {
                        guard rng.nextDouble() < density else { continue }
                        let vel = UInt8(72 + rng.nextInt(upperBound: 14))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: pitches.root,
                                                velocity: vel, durationSteps: 2))
                        events.append(MIDIEvent(stepIndex: barStart + step, note: pitches.third,
                                                velocity: UInt8(vel - 6), durationSteps: 2))
                        prevNote = pitches.third
                    }

                default:
                    // RHY-006: arpeggio — quarter-note legato, direction fixed per song
                    let arpNotes = buildArpNotes(entry: entry, frame: frame, direction: arpDirection)
                    guard !arpNotes.isEmpty else { break }
                    var arpEvents: [MIDIEvent] = []
                    for i in 0..<4 {
                        let note = arpNotes[i % arpNotes.count]
                        let vel  = UInt8(i == 0 ? min(110, Int(pitches.root) > 0 ? 80 : 72)
                                                : 62 + rng.nextInt(upperBound: 14))
                        arpEvents.append(MIDIEvent(stepIndex: barStart + i * 4, note: note,
                                                   velocity: vel, durationSteps: 3))
                    }
                    // Legato fill: extend each note to (next_onset − 1), min 4
                    for i in 0..<arpEvents.count {
                        let nextOnset = (i + 1 < arpEvents.count)
                            ? arpEvents[i + 1].stepIndex : barStart + 16
                        let legatoDur = max(4, min(nextOnset - arpEvents[i].stepIndex - 1, 12))
                        events.append(MIDIEvent(stepIndex: arpEvents[i].stepIndex,
                                                note:      arpEvents[i].note,
                                                velocity:  arpEvents[i].velocity,
                                                durationSteps: legatoDur))
                        prevNote = arpEvents[i].note
                    }
                }
            }
        }

        return events
    }

    // MARK: - Pitch helpers

    private struct ChordPitches {
        let root:  UInt8
        let fifth: UInt8
        let third: UInt8
        let flat7: UInt8
    }

    /// Derives root, fifth, third, and flat-7 for the current chord window.
    /// prevNote anchors the register so notes don't jump across bar lines.
    private static func chordPitches(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, prevNote: UInt8?
    ) -> ChordPitches {
        let keyS   = keySemitone(frame.key)
        let rootPC = (keyS + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        let isMajorThird = entry.chordWindow.chordType == .major ||
                           entry.chordWindow.chordType == .dom7  ||
                           entry.chordWindow.chordType == .add9  ||
                           entry.chordWindow.chordType == .sus4  ||
                           entry.chordWindow.chordType == .power
        let thirdPC = (rootPC + (isMajorThird ? 4 : 3)) % 12
        let fifthPC = (rootPC + 7) % 12
        let flat7PC = (rootPC + 10) % 12

        let root  = nearestMIDI(target: findMIDI(pc: rootPC,  ref: 57), low: 45, high: 72, prev: prevNote)
        let fifth = nearestMIDI(target: findMIDI(pc: fifthPC, ref: 57), low: 48, high: 76, prev: prevNote)
        let third = nearestMIDI(target: findMIDI(pc: thirdPC, ref: 57), low: 45, high: 76, prev: prevNote)
        let flat7 = nearestMIDI(target: findMIDI(pc: flat7PC, ref: 57), low: 45, high: 76, prev: prevNote)

        return ChordPitches(root: root, fifth: fifth, third: third, flat7: flat7)
    }

    // MARK: - Arpeggio builder (RHY-006)

    /// Builds an ordered MIDI note sequence from chord tones in the Rhythm register (45–76).
    ///
    /// Directions:
    ///   0 = up           (1 2 3 4 …)
    ///   1 = down         (… 4 3 2 1)
    ///   2 = up-down      (1 2 3 4 3 2 …  — no endpoint repeats)
    ///   3 = down-up      (4 3 2 1 2 3 …  — no endpoint repeats)
    ///   4 = ping-pong    (1 N 2 N-1 3 …  — alternating low/high inward)
    private static func buildArpNotes(
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, direction: Int
    ) -> [UInt8] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        let chordIntervals: [Int]
        switch entry.chordWindow.chordType {
        case .major:   chordIntervals = [0, 4, 7]
        case .minor:   chordIntervals = [0, 3, 7]
        case .sus2:    chordIntervals = [0, 2, 7]
        case .sus4:    chordIntervals = [0, 5, 7]
        case .dom7:    chordIntervals = [0, 4, 7, 10]
        case .min7:    chordIntervals = [0, 3, 7, 10]
        case .add9:    chordIntervals = [0, 4, 7, 14]
        case .quartal: chordIntervals = [0, 5, 10]
        case .power:   chordIntervals = [0, 7, 12]
        }

        var ascending: [UInt8] = []
        for octave in 3...6 {
            for interval in chordIntervals {
                let pc   = (rootPC + interval) % 12
                let midi = octave * 12 + pc
                if midi >= 45 && midi <= 76 { ascending.append(UInt8(midi)) }
            }
        }
        ascending.sort()
        guard ascending.count >= 2 else { return ascending }

        switch direction {
        case 0:  // up
            return ascending

        case 1:  // down
            return Array(ascending.reversed())

        case 2:  // up-down bounce
            var seq = ascending
            seq += Array(ascending.dropFirst().dropLast().reversed())
            return seq

        case 3:  // down-up bounce
            let desc = Array(ascending.reversed())
            var seq  = desc
            seq += Array(desc.dropFirst().dropLast().reversed())
            return seq

        default: // 4 ping-pong: alternate low/high inward
            var lo = 0, hi = ascending.count - 1
            var seq: [UInt8] = []
            while lo <= hi {
                seq.append(ascending[lo]); lo += 1
                if lo <= hi { seq.append(ascending[hi]); hi -= 1 }
            }
            return seq
        }
    }

    // MARK: - Note helpers

    /// Returns the MIDI note closest to `ref` that has pitch class `pc`.
    private static func findMIDI(pc: Int, ref: Int) -> Int {
        let base = (ref / 12) * 12 + pc
        let candidates = [base - 12, base, base + 12]
        return candidates.min(by: { abs($0 - ref) < abs($1 - ref) }) ?? base
    }

    /// Picks the octave of `target` that stays in [low, high] and is closest to `prev`.
    private static func nearestMIDI(target: Int, low: Int, high: Int, prev: UInt8?) -> UInt8 {
        var candidates: [Int] = []
        var t = target
        while t > high { t -= 12 }
        while t < low  { t += 12 }
        if t >= low && t <= high { candidates.append(t) }
        var up = t + 12; while up <= high { candidates.append(up); up += 12 }
        var dn = t - 12; while dn >= low  { candidates.append(dn); dn -= 12 }
        if candidates.isEmpty { return UInt8(clamping: low) }
        if let p = prev {
            return UInt8(clamping: candidates.min(by: { abs($0 - Int(p)) < abs($1 - Int(p)) }) ?? low)
        }
        let mid = (low + high) / 2
        return UInt8(clamping: candidates.min(by: { abs($0 - mid) < abs($1 - mid) }) ?? low)
    }

    /// Builds a random 8-step (2-bar) melodic riff as semitone intervals from root.
    private static func buildMelodicRiff(rng: inout SeededRNG) -> [Int] {
        let pool = [0, 0, 2, 3, 4, 5, 7, 7, 9, 10]
        return (0..<8).map { _ in pool[rng.nextInt(upperBound: pool.count)] }
    }
}
