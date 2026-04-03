// KosmicPadsGenerator.swift — Kosmic pads generation
// Implements KOS-PADS-001 through KOS-PADS-008
//   001 Eno Long Drone · 002 Swell Chord · 003 Unsync Layers · 004 Suspended Resolution
//   005 Quartal Stack  · 006 Shimmer Layer · 007 Gated Chord Pulse · 008 bIII Colour Chord
// Register: MIDI 36–72 (lower than Motorik pads at 48–84 — creates depth below arpeggio)

import Foundation

struct KosmicPadsGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        kosmicProgFamily: KosmicProgressionFamily,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {

        // Pick primary pad rule
        let padRules:   [String] = ["KOS-PADS-001", "KOS-PADS-002", "KOS-PADS-003", "KOS-PADS-004", "KOS-PADS-005", "KOS-PADS-007"]
        let padWeights: [Double] = [0.18,           0.20,           0.18,           0.13,           0.13,            0.18]

        // forceRuleID > quartal_stack/suspended_resolution constraints > weighted pick
        let primaryRule: String
        if let forced = forceRuleID {
            primaryRule = forced
        } else if kosmicProgFamily == .quartal_stack {
            primaryRule = "KOS-PADS-005"
        } else if kosmicProgFamily == .suspended_resolution {
            primaryRule = "KOS-PADS-004"
        } else {
            primaryRule = padRules[rng.weightedPick(padWeights)]
        }
        usedRuleIDs.insert(primaryRule)

        // Secondary layers: decide once per song whether each is active.
        // Per-bar probability compounds across many bars — a 40% per-bar rate fires in >99% of songs.
        // A single song-level gate keeps these as genuine occasional colour, not guaranteed fixtures.
        let use008 = rng.nextDouble() < 0.40   // KOS-PADS-008: bIII Colour Chord
        let use006 = rng.nextDouble() < 0.30   // KOS-PADS-006: Shimmer Layer
        if use008 { usedRuleIDs.insert("KOS-PADS-008") }
        if use006 { usedRuleIDs.insert("KOS-PADS-006") }

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard let entry = tonalMap.entry(atBar: bar) else { continue }
            let barStart = bar * 16

            // Intro: single sustained chord — no retriggers, no velocity ramp.
            // PlaybackEngine volume fade 0→1 handles the swell; static velocities here.
            // Root + fifth + modal third all from bar 0 for full intro duration.
            // For 4+ bar intros, a soft root octave enters at bar 2 — the only second event,
            //   no further attacks; gives a sense of harmonic build without extra clicks.
            if section.label == .intro {
                guard bar == section.startBar else { continue }
                let introSteps = (section.endBar - section.startBar) * 16
                let introLen   = section.endBar - section.startBar
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
                let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
                let thirdPC = (rootPC + entry.sectionMode.intervals[2]) % 12
                let third   = noteInPadsRegister(pc: thirdPC, targetOct: 2)
                let dur = introSteps - 1
                events += [
                    MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 40, durationSteps: dur),
                    MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 32, durationSteps: dur),
                    MIDIEvent(stepIndex: barStart, note: UInt8(third), velocity: 24, durationSteps: dur),
                ]
                // For longer intros: soft root octave enters at bar 2 for added warmth
                if introLen >= 4 {
                    let octPC  = rootPC
                    let octave = noteInPadsRegister(pc: octPC, targetOct: 3)
                    let octStart = barStart + 32  // bar 2
                    let octDur   = introSteps - 32 - 1
                    if octDur > 0 {
                        events.append(MIDIEvent(stepIndex: octStart, note: UInt8(octave),
                                                velocity: 22, durationSteps: octDur))
                    }
                }
                continue
            }

            // Outro: same principle — velocity matches body so the fade-out is perceptually linear.
            if section.label == .outro {
                guard bar == section.startBar else { continue }
                let dur    = max(1, (section.endBar - section.startBar) * 16 - 1)
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
                let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
                events += [
                    MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 65, durationSteps: dur),
                    MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 58, durationSteps: dur),
                ]
                continue
            }

            // Bridge A-1 (.bridge): re-attack every bar, ascending or descending voicing per phase.
            // Direction: ascending 67% (startBar % 3 != 2), descending 33% — matches bass/arpeggio.
            // Ascending: root+fifth → +octave → +third → full chord (louder each phase).
            // Descending: full chord → -third → -octave → root+fifth (strips back to root).
            // Short hold (12 steps = 3 beats) leaves a crisp gap between attacks.
            if section.label == .bridge {
                let bridgeLen   = max(1, section.endBar - section.startBar)
                let barInBridge = bar - section.startBar
                let phase       = min(3, barInBridge * 4 / bridgeLen)
                let ascending   = section.startBar % 3 != 2
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let root   = noteInPadsRegister(pc: rootPC,                                   targetOct: 2)
                let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12,                        targetOct: 2)
                let octave = noteInPadsRegister(pc: rootPC,                                   targetOct: 3)
                let third  = noteInPadsRegister(pc: (rootPC + mode.nearestInterval(3)) % 12, targetOct: 2)
                let dur = 12
                // Ascending phases add voices; descending phases remove them
                let ascPhase = ascending ? phase : (3 - phase)
                let velBase = ascending ? [44, 50, 55, 62][phase] : [62, 55, 50, 44][phase]
                events += [
                    MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: UInt8(velBase),     durationSteps: dur),
                    MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: UInt8(velBase - 6), durationSteps: dur),
                ]
                if ascPhase >= 1 {
                    events.append(MIDIEvent(stepIndex: barStart, note: UInt8(octave), velocity: UInt8(velBase - 10), durationSteps: dur))
                }
                if ascPhase >= 2 {
                    events.append(MIDIEvent(stepIndex: barStart, note: UInt8(third),  velocity: UInt8(velBase - 8),  durationSteps: dur))
                }
                continue
            }

            // Bridge A-2 (.bridgeAlt): light rhythmic chords throughout.
            // Even bars (call): strong beat-1 hit + softer beat-3 echo (root + third + fifth).
            // Odd bars (response): sustained half-note chord at lower velocity to support the lead melody.
            if section.label == .bridgeAlt {
                let bridgeBar = bar - section.startBar
                let rootPC    = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode      = entry.sectionMode
                let root      = noteInPadsRegister(pc: rootPC, targetOct: 2)
                let third     = noteInPadsRegister(pc: (rootPC + mode.nearestInterval(3)) % 12, targetOct: 2)
                let fifth     = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
                if bridgeBar % 2 == 0 {
                    // Call bar: sharp hit beat 1, quieter echo beat 3
                    events += [
                        MIDIEvent(stepIndex: barStart,     note: UInt8(root),  velocity: 88, durationSteps: 4),
                        MIDIEvent(stepIndex: barStart,     note: UInt8(third), velocity: 80, durationSteps: 4),
                        MIDIEvent(stepIndex: barStart,     note: UInt8(fifth), velocity: 82, durationSteps: 4),
                        MIDIEvent(stepIndex: barStart + 8, note: UInt8(root),  velocity: 58, durationSteps: 4),
                        MIDIEvent(stepIndex: barStart + 8, note: UInt8(fifth), velocity: 52, durationSteps: 4),
                    ]
                } else {
                    // Response bar: always plays — root+fifth sustained under the melodic response
                    let vel = UInt8(38 + rng.nextInt(upperBound: 14))
                    events += [
                        MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: vel,     durationSteps: 11),
                        MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: vel - 6, durationSteps: 11),
                    ]
                }
                continue
            }

            // Bridge B (.bridgeMelody): evolving pad voicing across the bridge.
            // Short bridges (≤ 4 bars): single long hold (no room to evolve).
            // Longer bridges: re-attack every 4 bars with three phases —
            //   first half: open root+fifth (spacious, lets melody breathe)
            //   second half: root+third+fifth (warmer, supports the raised-peak variant)
            //   final 4 bars: root+fourth+fifth sus4 (harmonic tension before B section)
            if section.label == .bridgeMelody {
                let bridgeLen   = section.endBar - section.startBar
                let barInBridge = bar - section.startBar
                let halfLen     = max(1, bridgeLen / 2)
                let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let mode   = entry.sectionMode
                let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
                let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
                let third  = noteInPadsRegister(pc: (rootPC + mode.nearestInterval(3)) % 12, targetOct: 2)
                let fourth = noteInPadsRegister(pc: (rootPC + 5) % 12, targetOct: 2)

                if bridgeLen <= 4 {
                    // Short bridge: one long hold for the full duration
                    guard barInBridge == 0 else { continue }
                    let dur = max(1, bridgeLen * 16 - 1)
                    events += [
                        MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 60, durationSteps: dur),
                        MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 54, durationSteps: dur),
                    ]
                } else {
                    // Longer bridge: re-attack every 4 bars with evolving voicing
                    guard barInBridge % 4 == 0 else { continue }
                    let holdDur     = min(62, (section.endBar - bar) * 16 - 2)
                    let isNearEnd   = barInBridge >= bridgeLen - 4
                    let isSecondHalf = barInBridge >= halfLen
                    if isNearEnd {
                        // Sus4 tension — harmonic unrest before B section arrives
                        events += [
                            MIDIEvent(stepIndex: barStart, note: UInt8(root),   velocity: 52, durationSteps: holdDur),
                            MIDIEvent(stepIndex: barStart, note: UInt8(fourth), velocity: 46, durationSteps: holdDur),
                            MIDIEvent(stepIndex: barStart, note: UInt8(fifth),  velocity: 48, durationSteps: holdDur),
                        ]
                    } else if isSecondHalf {
                        // Warmer triad: supports the raised-peak phrase variant
                        events += [
                            MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 62, durationSteps: holdDur),
                            MIDIEvent(stepIndex: barStart, note: UInt8(third), velocity: 54, durationSteps: holdDur),
                            MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 56, durationSteps: holdDur),
                        ]
                    } else {
                        // Open fifth: spacious, melody has room to speak
                        events += [
                            MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 58, durationSteps: holdDur),
                            MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 52, durationSteps: holdDur),
                        ]
                    }
                }
                continue
            }

            // Technique C: Extended pad hold at B section entry (50% chance).
            // Long chord wells up underneath the B section entry — Dark Sun swell feel.
            if section.label == .B && bar == section.startBar && rng.nextDouble() < 0.50 {
                let holdBars = 8 + rng.nextInt(upperBound: 5)  // 8–12 bars
                let holdDur  = min(holdBars * 16 - 1, (section.endBar - bar) * 16 - 1)
                let rootPC   = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                let root     = noteInPadsRegister(pc: rootPC, targetOct: 2)
                let fifth    = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
                events += [
                    MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 68, durationSteps: holdDur),
                    MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 62, durationSteps: holdDur),
                ]
                // Fall through — normal pad rule also runs this bar (layered on top)
            }

            let primaryCountBefore = events.count

            switch primaryRule {
            case "KOS-PADS-001":
                events += longDroneBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
            case "KOS-PADS-002":
                events += swellChordBar(barStart: barStart, entry: entry, frame: frame, rng: &rng)
            case "KOS-PADS-003":
                events += unsyncLayersBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
            case "KOS-PADS-004":
                events += suspendedResolutionBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
            case "KOS-PADS-005":
                events += quartalStackBar(barStart: barStart, entry: entry, frame: frame)
            case "KOS-PADS-007":
                events += gatedChordPulseBar(barStart: barStart, entry: entry, frame: frame, rng: &rng)
            default:
                events += longDroneBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
            }

            // Secondary layers only fire when the primary rule is sparse this bar (< 4 notes).
            // Prevents crowding when KOS-PADS-002/005/007 already fill the bar.
            let primaryAddedThisBar = events.count - primaryCountBefore

            // KOS-PADS-008: bIII Colour Chord — fires per bar when song-level gate is open
            if use008 && !section.label.isBridge && primaryAddedThisBar < 4 && rng.nextDouble() < 0.55 {
                events += bIIIColourChordBar(barStart: barStart, entry: entry, frame: frame)
            }

            // KOS-PADS-006: Shimmer Layer — fires per bar when song-level gate is open
            if use006 && !section.label.isBridge && primaryAddedThisBar < 4 && rng.nextDouble() < 0.40 {
                events += shimmerLayerBar(barStart: barStart, entry: entry, frame: frame, rng: &rng)
            }
        }

        return events
    }

    // MARK: - KOS-PAD-001: Long Drone
    // Whole notes held 2–4 bars (but we emit per bar with overlap),
    // voicing: root+5th+octave+(3rd at octave up), velocity 40–55

    private static func longDroneBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        // Only re-attack every 2 bars to simulate held notes
        guard bar % 2 == 0 else { return [] }

        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let root    = noteInPadsRegister(pc: rootPC, targetOct: 2)
        let fifth   = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
        let octave  = noteInPadsRegister(pc: rootPC, targetOct: 3)
        let mode = frame.mode
        let thirdInterval = mode.nearestInterval(4)  // major or minor 3rd
        let thirdHigh = noteInPadsRegister(pc: (rootPC + thirdInterval) % 12, targetOct: 3)

        // Hold for 32 steps (2 bars) — slightly less than 32 for visual gap
        let dur = 30
        let vel = UInt8(50 + Int.random(in: 0...10))

        return [
            MIDIEvent(stepIndex: barStart, note: UInt8(root),      velocity: vel,       durationSteps: dur),
            MIDIEvent(stepIndex: barStart, note: UInt8(fifth),     velocity: vel - 5,   durationSteps: dur),
            MIDIEvent(stepIndex: barStart, note: UInt8(octave),    velocity: vel - 3,   durationSteps: dur),
            MIDIEvent(stepIndex: barStart, note: UInt8(thirdHigh), velocity: vel - 8,   durationSteps: dur),
        ]
    }

    // MARK: - KOS-PAD-002: Swell Chord
    // Velocity ramps 20→80 over the bar (Vangelis brass swell)

    private static func swellChordBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
        let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)

        // Simulate velocity ramp with sub-events at different velocities
        // Attack at 20, mid at 50, sustain at 75
        return [
            MIDIEvent(stepIndex: barStart,      note: UInt8(root),  velocity: 35, durationSteps: 6),
            MIDIEvent(stepIndex: barStart + 4,  note: UInt8(root),  velocity: 55, durationSteps: 6),
            MIDIEvent(stepIndex: barStart + 8,  note: UInt8(root),  velocity: 70, durationSteps: 8),
            MIDIEvent(stepIndex: barStart,      note: UInt8(fifth), velocity: 30, durationSteps: 6),
            MIDIEvent(stepIndex: barStart + 4,  note: UInt8(fifth), velocity: 45, durationSteps: 6),
            MIDIEvent(stepIndex: barStart + 8,  note: UInt8(fifth), velocity: 60, durationSteps: 8),
        ]
    }

    // MARK: - KOS-PAD-003: Unsync Layers
    // Three voices at 8, 10, 12 bar loop lengths (Roach-style unsync)

    private static func unsyncLayersBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var evs: [MIDIEvent] = []
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // Voice 1: 8-bar loop — root voicing
        if bar % 8 == 0 {
            let root = noteInPadsRegister(pc: rootPC, targetOct: 2)
            let fifth = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
            evs += [
                MIDIEvent(stepIndex: barStart, note: UInt8(root),  velocity: 50, durationSteps: 14 * 8),
                MIDIEvent(stepIndex: barStart, note: UInt8(fifth), velocity: 45, durationSteps: 14 * 8),
            ]
        }

        // Voice 2: 10-bar loop — different voicing
        if bar % 10 == 0 {
            let oct = noteInPadsRegister(pc: rootPC, targetOct: 3)
            let mode = frame.mode
            let thirdHigh = noteInPadsRegister(pc: (rootPC + mode.nearestInterval(4)) % 12, targetOct: 3)
            evs += [
                MIDIEvent(stepIndex: barStart, note: UInt8(oct),      velocity: 45, durationSteps: 14 * 10),
                MIDIEvent(stepIndex: barStart, note: UInt8(thirdHigh), velocity: 42, durationSteps: 14 * 10),
            ]
        }

        // Voice 3: 12-bar loop — inversion
        if bar % 12 == 0 {
            let rootHigh = noteInPadsRegister(pc: rootPC, targetOct: 3)
            evs.append(MIDIEvent(stepIndex: barStart, note: UInt8(rootHigh), velocity: 42, durationSteps: 14 * 12))
        }

        return evs
    }

    // MARK: - KOS-PAD-004: Suspended Resolution
    // sus4 for 3 bars, minor for 1 bar (per 4-bar cycle)

    private static func suspendedResolutionBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
        let cycle  = bar % 4

        if cycle < 3 {
            // sus4: root + fourth + fifth
            let fourth = noteInPadsRegister(pc: (rootPC + 5) % 12, targetOct: 2)
            let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
            return [
                MIDIEvent(stepIndex: barStart, note: UInt8(root),   velocity: 50, durationSteps: 14),
                MIDIEvent(stepIndex: barStart, note: UInt8(fourth),  velocity: 45, durationSteps: 14),
                MIDIEvent(stepIndex: barStart, note: UInt8(fifth),   velocity: 48, durationSteps: 14),
            ]
        } else {
            // minor resolution: root + minor third + fifth
            let mode = frame.mode
            let minor3rd = noteInPadsRegister(pc: (rootPC + mode.nearestInterval(3)) % 12, targetOct: 2)
            let fifth    = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)
            return [
                MIDIEvent(stepIndex: barStart, note: UInt8(root),     velocity: 55, durationSteps: 14),
                MIDIEvent(stepIndex: barStart, note: UInt8(minor3rd), velocity: 50, durationSteps: 14),
                MIDIEvent(stepIndex: barStart, note: UInt8(fifth),    velocity: 52, durationSteps: 14),
            ]
        }
    }

    // MARK: - KOS-PAD-005: Quartal Stack
    // Stacked fourths: 0, 5, 10 semitones (very spacious)

    private static func quartalStackBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
        let fourth = noteInPadsRegister(pc: (rootPC + 5) % 12, targetOct: 2)
        let flat7  = noteInPadsRegister(pc: (rootPC + frame.mode.nearestInterval(10)) % 12, targetOct: 2)

        return [
            MIDIEvent(stepIndex: barStart, note: UInt8(root),   velocity: 65, durationSteps: 14),
            MIDIEvent(stepIndex: barStart, note: UInt8(fourth), velocity: 60, durationSteps: 14),
            MIDIEvent(stepIndex: barStart, note: UInt8(flat7),  velocity: 57, durationSteps: 14),
        ]
    }

    // MARK: - KOS-PADS-007: Gated Chord Pulse
    // Root+fifth re-attacked each quarter beat with independent per-beat gate probability.
    // Beats 1 and 3 weighted higher; creates a rhythmically active pad in the JMJ/TD style
    // (Équinoxe, Stratosfear) rather than a static drone.

    private static func gatedChordPulseBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let root   = noteInPadsRegister(pc: rootPC, targetOct: 2)
        let fifth  = noteInPadsRegister(pc: (rootPC + 7) % 12, targetOct: 2)

        // Downbeats (1, 3) fire more reliably than upbeats (2, 4)
        let beatProbs: [Double] = [0.95, 0.72, 0.82, 0.65]
        let beatSteps            = [0, 4, 8, 12]
        var evs: [MIDIEvent] = []
        for (i, step) in beatSteps.enumerated() {
            guard rng.nextDouble() < beatProbs[i] else { continue }
            let vel = UInt8(52 + rng.nextInt(upperBound: 18))  // 52–69
            evs += [
                MIDIEvent(stepIndex: barStart + step, note: UInt8(root),  velocity: vel,     durationSteps: 3),
                MIDIEvent(stepIndex: barStart + step, note: UInt8(fifth), velocity: vel - 6, durationSteps: 3),
            ]
        }
        return evs
    }

    // MARK: - KOS-PADS-008: bIII Colour Chord (bIII voicing, velocity ramp)

    private static func bIIIColourChordBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // bIII = flat minor 3rd up from root
        let bIIIpc = (rootPC + 3) % 12
        let bIIIroot = noteInPadsRegister(pc: bIIIpc, targetOct: 2)
        let bIIIfifth = noteInPadsRegister(pc: (bIIIpc + 7) % 12, targetOct: 2)

        // Velocity ramp 15→65 simulated with two events
        return [
            MIDIEvent(stepIndex: barStart,     note: UInt8(bIIIroot),  velocity: 35, durationSteps: 8),
            MIDIEvent(stepIndex: barStart + 6, note: UInt8(bIIIroot),  velocity: 60, durationSteps: 10),
            MIDIEvent(stepIndex: barStart,     note: UInt8(bIIIfifth), velocity: 30, durationSteps: 8),
            MIDIEvent(stepIndex: barStart + 6, note: UInt8(bIIIfifth), velocity: 50, durationSteps: 10),
        ]
    }

    // MARK: - KOS-PADS-006: Shimmer Layer (high register, velocity ramp 15→55)

    private static func shimmerLayerBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12

        // 1–3 notes from upper register (root + 2 or 3 octaves = MIDI 60+key+24 or +36)
        let noteCount = 1 + rng.nextInt(upperBound: 3)
        var evs: [MIDIEvent] = []

        let semitones = [0, 7, 12]  // root, fifth, octave
        for i in 0..<noteCount {
            let st = semitones[i % semitones.count]
            let base = 60 + rootPC + st
            var midi = base
            while midi < 60 { midi += 12 }
            while midi > 84 { midi -= 12 }

            // Velocity ramp 52→72 over 4–8 beats
            let dur = 4 * (1 + rng.nextInt(upperBound: 2))  // 4 or 8 steps
            evs.append(MIDIEvent(stepIndex: barStart, note: UInt8(midi), velocity: 52, durationSteps: dur / 2))
            if barStart + dur / 2 < barStart + 16 {
                evs.append(MIDIEvent(stepIndex: barStart + dur / 2, note: UInt8(midi),
                                     velocity: 72, durationSteps: dur / 2))
            }
        }
        return evs
    }

    // MARK: - Register helper: put pitch class in pads register (MIDI 36–72)

    private static func noteInPadsRegister(pc: Int, targetOct: Int) -> Int {
        var midi = targetOct * 12 + pc
        while midi < 36 { midi += 12 }
        while midi > 72 { midi -= 12 }
        return midi
    }
}
