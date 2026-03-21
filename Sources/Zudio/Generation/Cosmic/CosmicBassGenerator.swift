// CosmicBassGenerator.swift — Cosmic bass generation
// Implements COS-BAS-001 through COS-BAS-005 and COS-RULE-17 (dual bass layers)
// COS-RULE-06: bass range MIDI 40–55
// COS-RULE-05: synth-bass patterns use velocity = 100 flat

import Foundation

struct CosmicBassGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil,
        bassEvolutionBars: inout [Int]
    ) -> [MIDIEvent] {

        // Pick primary bass rule
        let rules:   [String] = ["COS-BASS-001", "COS-BASS-002", "COS-BASS-003", "COS-BASS-004", "COS-BASS-005",
                                  "COS-BASS-008", "COS-BASS-009", "COS-BASS-010",
                                  "COS-BASS-011", "COS-BASS-012"]
        let weights: [Double] = [0.18,           0.15,          0.13,           0.10,           0.07,
                                  0.09,           0.07,           0.05,
                                  0.09,           0.07]
        let ruleID = forceRuleID ?? rules[rng.weightedPick(weights)]

        // COS-BASS-005 = truly absent bass in body sections (intro/outro still get a root note).
        // Always logged so the status shows "Bass absent in main section".
        // Blocks 006 and 007: no point layering over silence.
        let bassAbsent = ruleID == "COS-BASS-005"
        usedRuleIDs.insert(ruleID)

        // COS-BASS-006: staccato dual layer — blocked with COS-BASS-004 (chromatic neighbour
        // clashes with staccato root) and COS-BASS-010 (Moroder Pulse already fills off-beats).
        // COS-BASS-008 (Hallogallo Lock) REQUIRES the dual layer — sounds thin without it.
        // PBW (012) is already an 8-note melodic riff — dual staccato layer would clutter it.
        let canUseDualLayer = !bassAbsent && ruleID != "COS-BASS-004" && ruleID != "COS-BASS-010" && ruleID != "COS-BASS-012"
        let useDualLayer    = canUseDualLayer && (ruleID == "COS-BASS-008" || rng.nextDouble() < 0.55)
        if useDualLayer { usedRuleIDs.insert("COS-BASS-006") }

        // COS-BASS-007: pulsating tremolo — mutually exclusive with 006, blocked when absent,
        // blocked with COS-BASS-004 (Moroder Drift long hold clashes), and
        // blocked with COS-BASS-010 (Moroder Pulse is already a dense 8th-note sequence).
        let usePulsatingLayer = !bassAbsent && !useDualLayer && ruleID != "COS-BASS-004" && ruleID != "COS-BASS-010" && ruleID != "COS-BASS-012" && rng.nextDouble() < 0.45
        if usePulsatingLayer { usedRuleIDs.insert("COS-BASS-007") }

        // Precompute variation windows for static Cosmic rules (same logic as Motorik BassGenerator).
        // Fires for: every B section; every other A section that starts at or after bar 48.
        // COS-BASS-008 uses middle-third body detection instead (computed below).
        // COS-BASS-010 omitted: gating IS its variation; no discrete evolution events needed.
        let cosmicVariableRules: Set<String> = ["COS-BASS-011", "COS-BASS-012"]
        var variationBars = Set<Int>()
        if cosmicVariableRules.contains(ruleID) {
            var aToggle = false
            for bar in 0..<frame.totalBars {
                guard let sec = structure.section(atBar: bar),
                      sec.label != .intro && sec.label != .outro,
                      sec.startBar == bar else { continue }
                if sec.label == .B {
                    for b in sec.startBar..<sec.endBar { variationBars.insert(b) }
                } else if sec.label == .A && sec.startBar >= 48 {
                    aToggle.toggle()
                    if aToggle { for b in sec.startBar..<sec.endBar { variationBars.insert(b) } }
                }
            }
        }

        // COS-BASS-008: middle-third body evolution (same approach as COS-BASS-003 pedalPulseBar).
        // Reliable even in songs with no B sections or short A sections.
        var cos008EvoStart = Int.max
        var cos008EvoEnd   = Int.max
        if ruleID == "COS-BASS-008", let introSec = structure.introSection {
            let bodyStart  = introSec.endBar
            let outroStart = structure.outroSection?.startBar ?? frame.totalBars
            let bodyLen    = max(1, outroStart - bodyStart)
            if bodyLen >= 12 {
                cos008EvoStart = bodyStart + bodyLen / 3
                cos008EvoEnd   = bodyStart + (bodyLen * 2) / 3
            }
        }

        var wasInVariation = false

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard let entry = tonalMap.entry(atBar: bar) else { continue }
            let barStart = bar * 16

            // COS-BASS-005: truly absent in body — no notes at all
            if bassAbsent && section.label != .intro && section.label != .outro { continue }

            // Intro: growing drone with beat-3 motion.
            // Beat-1 (every 2 bars): root note, velocity ramp 20→88. Retriggers refresh velocity upward.
            // Beat-3 (every bar): root + octave — different pitch so no noteOff conflict with beat-1.
            //   Softer, adds upward motion and tension on each bar's 3rd beat.
            // All noteOffs converge at intro end (same formula), no bleed into body.
            if section.label == .intro {
                let root       = bassRoot(entry: entry, frame: frame)
                let introLen   = section.endBar - section.startBar
                let barInIntro = bar - section.startBar
                let p = introLen <= 2 ? 1.0
                                      : min(1.0, max(0.0, Double(barInIntro) / Double(introLen - 2)))

                if bar % 2 == 0 {
                    let vel = UInt8(20 + Int(p * 68))  // 20 → 88
                    let dur = (section.endBar - bar) * 16 - 1
                    events.append(MIDIEvent(stepIndex: barStart, note: root, velocity: vel, durationSteps: dur))
                }

                let octaveNote = UInt8(min(127, Int(root) + 12))
                let beat3Vel   = UInt8(12 + Int(p * 40))   // 12 → 52, softer complement
                let beat3Step  = barStart + 8
                let beat3Dur   = section.endBar * 16 - beat3Step - 1
                if beat3Dur > 0 {
                    events.append(MIDIEvent(stepIndex: beat3Step, note: octaveNote,
                                            velocity: beat3Vel, durationSteps: beat3Dur))
                }
                continue
            }

            // Outro: single long note at body velocity — PlaybackEngine volume ramp handles fade-out.
            if section.label == .outro {
                guard bar == section.startBar else { continue }
                let root = bassRoot(entry: entry, frame: frame)
                let dur  = max(1, (section.endBar - section.startBar) * 16 - 1)
                events.append(MIDIEvent(stepIndex: barStart, note: root, velocity: 90, durationSteps: dur))
                continue
            }

            // Sub-layer A: long harmonic anchor (COS-RULE-17)
            let isBody = section.label != .intro && section.label != .outro
            let useVariation: Bool
            if ruleID == "COS-BASS-008" {
                useVariation = bar >= cos008EvoStart && bar < cos008EvoEnd
            } else {
                useVariation = variationBars.contains(bar)
            }
            if isBody {
                if !wasInVariation && useVariation  { bassEvolutionBars.append(bar) }
                if wasInVariation  && !useVariation { bassEvolutionBars.append(bar) }
                wasInVariation = useVariation
            }
            events += primaryBassBar(ruleID: ruleID, barStart: barStart, bar: bar,
                                     entry: entry, frame: frame, rng: &rng,
                                     totalBars: frame.totalBars, isBody: isBody,
                                     structure: structure, useVariation: useVariation)

            // Sub-layer B: rhythmic staccato movement (COS-RULE-17)
            if useDualLayer {
                events += rhythmicBassLayer(barStart: barStart, entry: entry, frame: frame, rng: &rng)
            }

            // Pulsating tremolo layer (COS-RULE-23)
            if usePulsatingLayer && bar % 4 == 0 {
                events += pulsatingTremoloLayer(barStart: barStart, entry: entry, frame: frame)
            }
        }

        // COS-BASS-001 fifth-breath detection: the dual layer always provides root+fifth pitch
        // classes so the fingerprint detector in buildStepAnnotations can't see the transition.
        // Post-pass: compare the beat-1 note against the expected chord root; when the primary
        // drone switches to fifth (or back), record that bar explicitly.
        if ruleID == "COS-BASS-001" {
            var prevEvenBarIsRoot: Bool? = nil
            for bar in stride(from: 0, to: frame.totalBars, by: 2) {
                guard let sec = structure.section(atBar: bar),
                      sec.label != .intro && sec.label != .outro,
                      let entry = tonalMap.entry(atBar: bar) else { continue }
                let barStart = bar * 16
                guard let beat1 = events.first(where: { $0.stepIndex == barStart }) else { continue }
                let expectedRoot = bassRoot(entry: entry, frame: frame)
                let isRoot = (beat1.note == expectedRoot)
                if let prev = prevEvenBarIsRoot, prev != isRoot {
                    bassEvolutionBars.append(bar)
                }
                prevEvenBarIsRoot = isRoot
            }
        }

        // COS-BASS-011 cycle detection: the 4-bar cycle (bars 0–1 = third, bars 2–3 = fifth)
        // always produces {root, third, fifth} in every 4-bar fingerprint window, so the
        // aggregate fingerprint never changes. Fire explicitly at cycle phase transitions
        // (every bar%4==0 and bar%4==2) with an 8-bar cooldown to avoid spamming the log.
        if ruleID == "COS-BASS-011" {
            var lastCycleFireBar = -8
            for bar in 0..<frame.totalBars {
                guard let sec = structure.section(atBar: bar),
                      sec.label != .intro && sec.label != .outro else { continue }
                guard bar % 8 != 7 else { continue }   // skip lock bars
                let isTransition = (bar % 4 == 0 || bar % 4 == 2)
                guard isTransition else { continue }
                guard (bar - lastCycleFireBar) >= 8 else { continue }
                bassEvolutionBars.append(bar)
                lastCycleFireBar = bar
            }
        }

        return events
    }

    // MARK: - Primary bass (Sub-layer A)

    private static func primaryBassBar(
        ruleID: String, barStart: Int, bar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, totalBars: Int, isBody: Bool,
        structure: SongStructure, useVariation: Bool = false
    ) -> [MIDIEvent] {
        switch ruleID {
        case "COS-BASS-001": return droneRootBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                  rng: &rng, totalBars: totalBars, isBody: isBody)
        case "COS-BASS-002": return rootFifthWalkBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "COS-BASS-003": return pedalPulseBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                   structure: structure, totalBars: totalBars)
        case "COS-BASS-004": return moroderDriftBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "COS-BASS-005": return droneRootBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                  rng: &rng, totalBars: totalBars, isBody: false)
        case "COS-BASS-008": return hallogalloLockBar(barStart: barStart, bar: bar, entry: entry,
                                                       frame: frame, useVariation: useVariation)
        case "COS-BASS-009": return crawlingWalkBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "COS-BASS-010": return moroderPulseBar(barStart: barStart, entry: entry, frame: frame,
                                                     useVariation: useVariation, rng: &rng)
        case "COS-BASS-011": return kraftwerkRoboterBar(barStart: barStart, bar: bar, entry: entry,
                                                         frame: frame, useVariation: useVariation)
        case "COS-BASS-012": return mccartneyPBWBar(barStart: barStart, entry: entry, frame: frame,
                                                     useVariation: useVariation)
        default:             return droneRootBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                  rng: &rng, totalBars: totalBars, isBody: isBody)
        }
    }

    // MARK: - COS-BAS-001: Drone Root
    // Root held 2 bars (32 steps), re-attacks every 2 bars.
    // Minor evolution: in body sections after bar 8, ~1-in-6 two-bar windows briefly
    // breathe to the fifth then return — authentic TD behaviour for shorter pieces.
    // The drone stays on root the vast majority of the time.

    private static func droneRootBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, totalBars: Int, isBody: Bool
    ) -> [MIDIEvent] {
        guard bar % 2 == 0 else { return [] }
        let root = bassRoot(entry: entry, frame: frame)

        // Occasional fifth breath: only in body, past the first 8 bars,
        // not in the final 8 bars, and only ~1-in-6 two-bar windows.
        // Two-bar window index used as a deterministic seed so the pattern is
        // stable (not re-rolled every call).
        let windowIdx = bar / 2
        let nearEnd   = bar >= totalBars - 8
        if isBody && bar >= 8 && !nearEnd {
            // Use window index to decide — roughly every 6th window gets a fifth
            let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
            let fifthPC = (rootPC + 7) % 12
            var fifthMidi = 36 + fifthPC
            while fifthMidi < 40 { fifthMidi += 12 }
            while fifthMidi > 55 { fifthMidi -= 12 }
            // Seeded decision: modulo keeps it stable, small random push from rng
            let doFifth = (windowIdx % 6 == 4) && rng.nextDouble() < 0.60
            if doFifth {
                return [MIDIEvent(stepIndex: barStart, note: UInt8(fifthMidi),
                                  velocity: 58, durationSteps: 30)]
            }
        }

        return [MIDIEvent(stepIndex: barStart, note: root, velocity: 65, durationSteps: 30)]
    }

    // MARK: - COS-BAS-002: Root-Fifth Slow Walk
    // Root 2 bars, fifth 2 bars, root; 8-bar cycle

    private static func rootFifthWalkBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let cycle = bar % 8
        let root  = bassRoot(entry: entry, frame: frame)
        let fifth = UInt8(clamped(Int(root) + 7, low: 40, high: 55))

        if cycle < 4 {
            // Root for 4 bars (attack every 2 bars)
            guard cycle % 2 == 0 else { return [] }
            return [MIDIEvent(stepIndex: barStart, note: root, velocity: 100, durationSteps: 30)]
        } else {
            // Fifth for 4 bars
            guard cycle % 2 == 0 else { return [] }
            return [MIDIEvent(stepIndex: barStart, note: fifth, velocity: 100, durationSteps: 30)]
        }
    }

    // MARK: - COS-BAS-003: Pedal Pulse with Mid-Song Evolution
    //
    // Evolution window: bars within the middle third of body sections.
    //   Intro + body_start … body_start + bodyLen/3  → plain pedal pulse
    //   body_start + bodyLen/3 … body_start + 2*bodyLen/3 → evolved pattern
    //   body_start + 2*bodyLen/3 … outro → devolve back (plain pulse)
    //
    // Evolved pattern (COS-BASS-003-EVO):
    //   Beat 1  → root,  vel 100, dur 3 (anchor)
    //   Beat 1+ → fifth, vel 78,  dur 2 (syncopated off-beat push, step 2)
    //   Beat 2  → root,  vel 88,  dur 3
    //   Beat 3  → fifth, vel 95,  dur 3 (harmonic lift)
    //   Beat 3+ → third, vel 72,  dur 2 (passing tone, step 10)
    //   Beat 4  → root,  vel 88,  dur 3 (return)
    //
    // The fifth and third are derived via pitch-class to respect COS-RULE-06 range.

    private static func pedalPulseBar(
        barStart: Int, bar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        structure: SongStructure, totalBars: Int
    ) -> [MIDIEvent] {
        let root = bassRoot(entry: entry, frame: frame)

        // Determine body boundaries
        guard let introSection = structure.introSection else {
            return pedalPulseSimple(barStart: barStart, root: root)
        }
        let bodyStart = introSection.endBar
        let outroStart = structure.outroSection?.startBar ?? totalBars
        let bodyLen = max(1, outroStart - bodyStart)

        let barInBody = bar - bodyStart
        let third1  = bodyLen / 3
        let third2  = (bodyLen * 2) / 3

        // Only evolve in the middle third; also require at least 12 body bars for evolution to feel earned
        let shouldEvolve = bodyLen >= 12 && barInBody >= third1 && barInBody < third2

        if shouldEvolve {
            return pedalPulseEvolved(barStart: barStart, entry: entry, frame: frame, root: root)
        }
        return pedalPulseSimple(barStart: barStart, root: root)
    }

    // Original plain pedal pulse
    private static func pedalPulseSimple(barStart: Int, root: UInt8) -> [MIDIEvent] {
        return [
            MIDIEvent(stepIndex: barStart,      note: root, velocity: 100, durationSteps: 3),
            MIDIEvent(stepIndex: barStart + 4,  note: root, velocity: 88,  durationSteps: 3),
            MIDIEvent(stepIndex: barStart + 8,  note: root, velocity: 95,  durationSteps: 3),
            MIDIEvent(stepIndex: barStart + 12, note: root, velocity: 88,  durationSteps: 3),
        ]
    }

    // Evolved pedal pulse: adds fifth and minor-third passing tones between beats
    private static func pedalPulseEvolved(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, root: UInt8
    ) -> [MIDIEvent] {
        // Compute fifth and minor third via pitch-class (COS-RULE-06: MIDI 40–55)
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        let thirdPC = (rootPC + 3) % 12  // minor third (fits Aeolian/Dorian modes)

        var fifthMidi = 36 + fifthPC
        while fifthMidi < 40 { fifthMidi += 12 }
        while fifthMidi > 55 { fifthMidi -= 12 }

        var thirdMidi = 36 + thirdPC
        while thirdMidi < 40 { thirdMidi += 12 }
        while thirdMidi > 55 { thirdMidi -= 12 }

        let fifth = UInt8(fifthMidi)
        let third = UInt8(thirdMidi)

        return [
            // Beat 1: root anchor
            MIDIEvent(stepIndex: barStart,      note: root,  velocity: 100, durationSteps: 3),
            // Beat 1 off-beat push: fifth syncopation (step 2 = 0.5 beat after beat 1)
            MIDIEvent(stepIndex: barStart + 2,  note: fifth, velocity: 78,  durationSteps: 2),
            // Beat 2: root
            MIDIEvent(stepIndex: barStart + 4,  note: root,  velocity: 88,  durationSteps: 3),
            // Beat 3: fifth harmonic lift
            MIDIEvent(stepIndex: barStart + 8,  note: fifth, velocity: 95,  durationSteps: 3),
            // Beat 3 off-beat: minor third passing tone (step 10)
            MIDIEvent(stepIndex: barStart + 10, note: third, velocity: 72,  durationSteps: 2),
            // Beat 4: root return
            MIDIEvent(stepIndex: barStart + 12, note: root,  velocity: 88,  durationSteps: 3),
        ]
    }

    // MARK: - COS-BAS-004: Moroder Drift
    // Root 3 bars, chromatic neighbor bar 4, return.
    // Cycle:  0=root(30 steps)  1=silent  2=root(14 steps)  3=neighbor(14 steps)
    // Bar 2 MUST use 14 steps, not 30: a 30-step hold from bar 2 bleeds into bar 3
    // while the chromatic neighbour attacks there, creating a minor-2nd clash.
    // Bar 0 can still hold 30 steps because bar 1 is silent (no overlap).

    private static func moroderDriftBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let cycle = bar % 4
        let root  = bassRoot(entry: entry, frame: frame)

        switch cycle {
        case 0:
            return [MIDIEvent(stepIndex: barStart, note: root, velocity: 100, durationSteps: 30)]
        case 1:
            return []
        case 2:
            // Short hold — must not bleed into bar 3's chromatic neighbour
            return [MIDIEvent(stepIndex: barStart, note: root, velocity: 100, durationSteps: 14)]
        default: // cycle == 3
            // Use a whole-tone step (root+2) instead of semitone (root+1).
            // A whole tone is still a drift but far less dissonant than a minor 2nd,
            // especially when bleed-over from bar 2 could still linger at low velocity.
            let rootPC    = Int(root)
            let neighbor  = UInt8(clamped(rootPC + 2, low: 40, high: 55))
            return [MIDIEvent(stepIndex: barStart, note: neighbor, velocity: 88, durationSteps: 14)]
        }
    }

    // MARK: - COS-BASS-008: Hallogallo Lock (Cosmic)
    // Root beat 1 (7 steps), fifth beat 3 (6 steps) — two long notes per bar.
    // Adapted from Neu! "Hallogallo" bass character; extremely minimal and locked.
    // More active than Drone Root (every bar vs every 2 bars) but still very spacious.

    private static func hallogalloLockBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        useVariation: Bool = false
    ) -> [MIDIEvent] {
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        var fifthMidi = 36 + fifthPC
        while fifthMidi < 40 { fifthMidi += 12 }
        while fifthMidi > 55 { fifthMidi -= 12 }
        let root  = bassRoot(entry: entry, frame: frame)
        let fifth = UInt8(fifthMidi)

        if useVariation {
            // B-section: add a third passing note between root and fifth.
            // root(5) → third(4) → fifth(5) — adds thirdPC to fingerprint, detector fires.
            let thirdInterval = frame.mode.nearestInterval(4)
            var thirdMidi = rootPC + thirdInterval + 36
            while thirdMidi < 40 { thirdMidi += 12 }
            while thirdMidi > 55 { thirdMidi -= 12 }
            let third = UInt8(thirdMidi)
            return [
                MIDIEvent(stepIndex: barStart,      note: root,  velocity: 90, durationSteps: 5),
                MIDIEvent(stepIndex: barStart + 5,  note: third, velocity: 76, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 10, note: fifth, velocity: 82, durationSteps: 5),
            ]
        }
        return [
            MIDIEvent(stepIndex: barStart,     note: root,  velocity: 88, durationSteps: 7),
            MIDIEvent(stepIndex: barStart + 8, note: fifth, velocity: 74, durationSteps: 6),
        ]
    }

    // MARK: - COS-BASS-009: Crawling Walk (Cosmic)
    // 2-bar pattern with approach note chromaticism. Adapted from Motorik BAS-003
    // with Cosmic pitch range (MIDI 40–55) and lower velocities for the spacious feel.
    // Bar 1: root long → fifth at beat 2.75 → semitone approach at bar end (brief pickup)
    // Bar 2: root rearticulated short → root again → fifth holds the rest of bar

    private static func crawlingWalkBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        // Approach: semitone below root (chromatic leading tone)
        let approachPC = (rootPC + 11) % 12

        var fifthMidi    = 36 + fifthPC
        while fifthMidi < 40    { fifthMidi += 12 }
        while fifthMidi > 55    { fifthMidi -= 12 }
        var approachMidi = 36 + approachPC
        while approachMidi < 40 { approachMidi += 12 }
        while approachMidi > 55 { approachMidi -= 12 }

        let root     = bassRoot(entry: entry, frame: frame)
        let fifth    = UInt8(fifthMidi)
        let approach = UInt8(approachMidi)

        if bar % 2 == 0 {
            return [
                MIDIEvent(stepIndex: barStart,      note: root,     velocity: 85, durationSteps: 7),
                MIDIEvent(stepIndex: barStart + 10, note: fifth,    velocity: 70, durationSteps: 3),
                MIDIEvent(stepIndex: barStart + 15, note: approach, velocity: 58, durationSteps: 1),
            ]
        } else {
            return [
                MIDIEvent(stepIndex: barStart,     note: root,  velocity: 85, durationSteps: 3),
                MIDIEvent(stepIndex: barStart + 5, note: root,  velocity: 72, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 8, note: fifth, velocity: 80, durationSteps: 6),
            ]
        }
    }

    // MARK: - COS-BASS-010: Moroder Pulse (Cosmic)
    // Sequential 8th-note pattern: root-root-fifth-fifth-b7-b7-root-root.
    // Adapted from Giorgio Moroder sequencer feel (as in "I Feel Love").
    // Velocity 100 flat (COS-RULE-05). Notes in Cosmic range MIDI 40–55.
    // b7 is a natural scale tone in Dorian/Aeolian — no clash.

    private static func moroderPulseBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        useVariation: Bool = false, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        let b7PC    = (rootPC + 10) % 12
        // M6 (9 semitones) gives a diatonic 6th in Dorian/Aeolian — distinct from b7
        let m6PC    = (rootPC + 9) % 12

        func midiInRange(_ pc: Int) -> UInt8 {
            var m = 36 + pc
            while m < 40 { m += 12 }
            while m > 55 { m -= 12 }
            return UInt8(m)
        }

        let root  = midiInRange(rootPC)
        let fifth = midiInRange(fifthPC)
        let b7    = midiInRange(b7PC)
        let m6    = midiInRange(m6PC)

        // Base: r r 5 5 b7 b7 r r
        // Variation (B sections): r r 5 5 m6 b7 r r — swaps one b7 for m6, adds new pitch class
        let sequence: [UInt8] = useVariation
            ? [root, root, fifth, fifth, m6, b7, root, root]
            : [root, root, fifth, fifth, b7,  b7, root, root]
        // Per-step gate probability: anchors at index 0 and 7 most reliable;
        // mid-sequence positions drop freely, producing the gated analog-sequencer feel.
        let gateProbs: [Double] = [0.94, 0.82, 0.82, 0.65, 0.65, 0.70, 0.70, 0.94]
        return sequence.enumerated().compactMap { i, note in
            guard rng.nextDouble() < gateProbs[i] else { return nil }
            return MIDIEvent(stepIndex: barStart + i * 2, note: note, velocity: 100, durationSteps: 2)
        }
    }

    // MARK: - COS-BAS-011: Kraftwerk Roboter — "The Robots" (1978) octave-jump 3-note cell
    // 3-note cell: root(low, 8th) – root+octave(high, 8th) – mode-3rd(quarter). Two cells per bar.
    // The synthesizer octave jump creates mechanical, robot-like feel — well-suited to Cosmic's
    // Berlin School synthetic palette. At Cosmic tempos (90–125 BPM) the quarter-note 3rd
    // breathes more than it does at full Motorik speed.

    // COS-BASS-011: Kraftwerk Roboter (Cosmic)
    // 4-bar cycle matching Motorik version: bars 0–1 land on third, bars 2–3 land on fifth.
    // bar%8==7: lock bar (root-only quarter notes) — jump re-arrives next bar.
    // B-section variation: root–octave–fifth only (drops third) → fingerprint {root,5th} vs
    // base {root,3rd,5th} — detector fires.
    private static func kraftwerkRoboterBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        useVariation: Bool = false
    ) -> [MIDIEvent] {
        let root   = bassRoot(entry: entry, frame: frame)
        let octave = UInt8(clamped(Int(root) + 12, low: 40, high: 67))
        let thirdInterval = frame.mode.nearestInterval(4)
        let third  = UInt8(clamped(Int(root) + thirdInterval, low: 40, high: 58))
        let fifth  = UInt8(clamped(Int(root) + 7, low: 40, high: 55))

        // Lock bar: root-only quarter notes — strips the octave jump for one bar
        if bar % 8 == 7 {
            return [
                MIDIEvent(stepIndex: barStart,      note: root, velocity: 92, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: root, velocity: 80, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 8,  note: root, velocity: 88, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 12, note: root, velocity: 78, durationSteps: 4),
            ]
        }

        // B-section: root–octave–fifth only (no third) → new fingerprint
        if useVariation {
            var evs: [MIDIEvent] = []
            for cell in 0..<2 {
                let off = cell * 8
                evs.append(MIDIEvent(stepIndex: barStart + off,     note: root,   velocity: 100, durationSteps: 2))
                evs.append(MIDIEvent(stepIndex: barStart + off + 2, note: octave, velocity: 88,  durationSteps: 2))
                evs.append(MIDIEvent(stepIndex: barStart + off + 4, note: fifth,  velocity: 84,  durationSteps: 4))
            }
            return evs
        }

        // Base: 4-bar cycle — bars 0–1 use third, bars 2–3 use fifth
        let landing = (bar % 4 < 2) ? third : fifth
        let landingVel: UInt8 = (bar % 4 < 2) ? 82 : 86
        var events: [MIDIEvent] = []
        for cell in 0..<2 {
            let offset = cell * 8
            events.append(MIDIEvent(stepIndex: barStart + offset,     note: root,    velocity: 100, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + offset + 2, note: octave,  velocity: 88,  durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + offset + 4, note: landing, velocity: landingVel, durationSteps: 4))
        }
        return events
    }

    // MARK: - COS-BAS-012: McCartney PBW — "Paperback Writer" (1966) Mixolydian riff
    // root–fifth–root–b7–fifth–root–mode3rd–root in 8 8th-notes.
    // The flat-seventh (b7) gives a blues/Mixolydian quality — diatonic in Dorian and Mixolydian,
    // which are common Cosmic modes. Falls back to fifth in pure major chord contexts.
    // The riff cycles identically each bar — becomes hypnotic at slower Cosmic tempos.

    private static func mccartneyPBWBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        useVariation: Bool = false
    ) -> [MIDIEvent] {
        let root  = bassRoot(entry: entry, frame: frame)
        let fifth = UInt8(clamped(Int(root) + 7,  low: 40, high: 55))
        let third = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 40, high: 55))

        let isMajorContext: Bool
        switch entry.chordWindow.chordType {
        case .major, .sus2, .sus4, .add9: isMajorContext = true
        default:                          isMajorContext = false
        }
        let flatSeven = isMajorContext ? fifth : UInt8(clamped(Int(root) + 10, low: 40, high: 55))

        let pitches: [UInt8] = [root, fifth, root, flatSeven, fifth, root, third, root]
        let vels:    [UInt8] = [100,  88,    92,   84,        86,    82,   88,    78  ]

        var evs = pitches.enumerated().map { i, note in
            MIDIEvent(stepIndex: barStart + i * 2, note: note, velocity: vels[i], durationSteps: 2)
        }

        // B-section: add a semitone approach note on step 14 (one 16th before next bar).
        // Approach = root-1 semitone (chromatic leading tone). Adds a new pitch class so
        // the fingerprint detector fires.
        if useVariation {
            let approach = UInt8(clamped(Int(root) - 1, low: 40, high: 55))
            evs.append(MIDIEvent(stepIndex: barStart + 14, note: approach, velocity: 68, durationSteps: 1))
        }
        return evs
    }

    // MARK: - COS-RULE-17: Rhythmic staccato bass layer (sub-layer B)
    // Velocity 80–88, short staccato hits on off-beats.
    // Step offsets avoid beat 1 (step 0) to prevent double-attack with sub-layer A,
    // and avoid step 14 which bleeds into the next bar's primary attack.
    //
    // Only called when primary rule is NOT COS-BASS-004, because that rule plays
    // a chromatic neighbour (root+1) on every 4th bar — combining with the staccato
    // root produces a minor-2nd clash.

    private static func rhythmicBassLayer(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let root = bassRoot(entry: entry, frame: frame)

        // Compute fifth correctly via pitch-class to avoid range-clamping wrong notes.
        // e.g. Dm in G Aeolian: root=D(50), naive +7 clamps to G instead of A.
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        var fifthMidi = 36 + fifthPC
        while fifthMidi < 40 { fifthMidi += 12 }
        while fifthMidi > 55 { fifthMidi -= 12 }
        let fifth = UInt8(fifthMidi)

        // Off-beat positions that don't collide with sub-layer A (step 0) or bleed into next bar
        let stepOffsets = [3, 8, 12]
        let hitCount    = 2 + rng.nextInt(upperBound: 2)  // 2 or 3 hits
        var evs: [MIDIEvent] = []

        for i in 0..<hitCount {
            guard i < stepOffsets.count else { break }
            let note = (i % 2 == 0) ? root : fifth
            let vel  = UInt8(80 + rng.nextInt(upperBound: 9))  // 80–88
            let dur  = 2 + rng.nextInt(upperBound: 2)           // 2–3 steps (tighter staccato)
            evs.append(MIDIEvent(stepIndex: barStart + stepOffsets[i], note: note,
                                 velocity: vel, durationSteps: dur))
        }
        return evs
    }

    // MARK: - COS-RULE-23: Pulsating tremolo layer

    private static func pulsatingTremoloLayer(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root = bassRoot(entry: entry, frame: frame)
        var evs: [MIDIEvent] = []
        // Alternating low/high velocity at 0.25-beat intervals (every step)
        var alternateHigh = true
        for step in stride(from: 0, to: 16, by: 1) {
            let vel: UInt8 = alternateHigh ? 85 : 20
            alternateHigh.toggle()
            evs.append(MIDIEvent(stepIndex: barStart + step, note: root, velocity: vel, durationSteps: 1))
        }
        return evs
    }

    // MARK: - Note helpers

    static func bassRoot(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> UInt8 {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // COS-RULE-06: bass in MIDI 40–55
        var midi = 36 + rootPC  // start in octave 2
        while midi < 40 { midi += 12 }
        while midi > 55 { midi -= 12 }
        return UInt8(midi)
    }

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        Swift.max(low, Swift.min(high, v))
    }
}
