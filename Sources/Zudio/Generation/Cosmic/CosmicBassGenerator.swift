// KosmicBassGenerator.swift — Kosmic bass generation
// Implements KOS-BAS-001 through KOS-BAS-005 and KOS-RULE-17 (dual bass layers)
// KOS-RULE-06: bass range MIDI 40–55
// KOS-RULE-05: synth-bass patterns use velocity = 100 flat

import Foundation

struct KosmicBassGenerator {

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
        let rules:   [String] = ["KOS-BASS-001", "KOS-BASS-002", "KOS-BASS-003", "KOS-BASS-004", "KOS-BASS-005",
                                  "KOS-BASS-008", "KOS-BASS-009", "KOS-BASS-010",
                                  "KOS-BASS-011", "KOS-BASS-012", "KOS-BASS-013"]
        let weights: [Double] = [0.09,           0.07,          0.11,           0.09,           0.06,
                                  0.08,           0.07,           0.11,
                                  0.12,           0.07,           0.13]
        // Only honour forceRuleID if it belongs to the Kosmic bass pool.
        // Test slots that force Motorik rules (e.g. MOT-BASS-015) must not bleed into Kosmic songs.
        let validForce = forceRuleID.flatMap { rules.contains($0) ? $0 : nil }
        let ruleID = validForce ?? rules[rng.weightedPick(weights)]

        // KOS-BASS-005 = truly absent bass in body sections (intro/outro still get a root note).
        // Always logged so the status shows "Bass absent in main section".
        // Blocks 006 and 007: no point layering over silence.
        let bassAbsent = ruleID == "KOS-BASS-005"
        usedRuleIDs.insert(ruleID)

        // KOS-BASS-006: staccato dual layer — blocked with KOS-BASS-004 (chromatic neighbour
        // clashes with staccato root) and KOS-BASS-010 (Moroder Pulse already fills off-beats).
        // KOS-BASS-008 (Hallogallo Lock) REQUIRES the dual layer — sounds thin without it.
        // PBW (012) is already an 8-note melodic riff — dual staccato layer would clutter it.
        let canUseDualLayer = !bassAbsent && ruleID != "KOS-BASS-004" && ruleID != "KOS-BASS-010" && ruleID != "KOS-BASS-012" && ruleID != "KOS-BASS-013"
        let useDualLayer    = canUseDualLayer && (ruleID == "KOS-BASS-008" || rng.nextDouble() < 0.25)
        if useDualLayer { usedRuleIDs.insert("KOS-BASS-006") }

        // KOS-BASS-007: pulsating tremolo — mutually exclusive with 006, blocked when absent,
        // blocked with KOS-BASS-004 (Moroder Drift long hold clashes), and
        // blocked with KOS-BASS-010 (Moroder Pulse is already a dense 8th-note sequence).
        let usePulsatingLayer = !bassAbsent && !useDualLayer && ruleID != "KOS-BASS-004" && ruleID != "KOS-BASS-010" && ruleID != "KOS-BASS-012" && ruleID != "KOS-BASS-013" && rng.nextDouble() < 0.45
        if usePulsatingLayer { usedRuleIDs.insert("KOS-BASS-007") }

        // Precompute variation windows for static Kosmic rules (same logic as Motorik BassGenerator).
        // Fires for: every B section; every other A section that starts at or after bar 48.
        // KOS-BASS-008 uses middle-third body detection instead (computed below).
        // KOS-BASS-010 omitted: gating IS its variation; no discrete evolution events needed.
        let kosmicVariableRules: Set<String> = ["KOS-BASS-011", "KOS-BASS-012", "KOS-BASS-013"]
        var variationBars = Set<Int>()
        if kosmicVariableRules.contains(ruleID) {
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

        // KOS-BASS-008: middle-third body evolution (same approach as KOS-BASS-003 pedalPulseBar).
        // Reliable even in songs with no B sections or short A sections.
        var cos008EvoStart = Int.max
        var cos008EvoEnd   = Int.max
        if ruleID == "KOS-BASS-008", let introSec = structure.introSection {
            let bodyStart  = introSec.endBar
            let outroStart = structure.outroSection?.startBar ?? frame.totalBars
            let bodyLen    = max(1, outroStart - bodyStart)
            if bodyLen >= 12 {
                cos008EvoStart = bodyStart + bodyLen / 3
                cos008EvoEnd   = bodyStart + (bodyLen * 2) / 3
            }
        }

        var wasInVariation = false

        // KOS-BASS-011: pre-select Autobahn sub-pattern per section / every 16 bars.
        // 0=Pattern D (sparse skeleton), 1=Pattern E (canonical full hook), 2=Pattern A (octave bounce), 3=Pattern F (sparse pairs)
        // Selection uses rng so it varies per song; switches fire at body-section boundaries and every 16 bars.
        var kos011Variant    = 0
        var kos011LastSwitch = -16

        var events: [MIDIEvent] = []

        // For melody bridges, pick a bass rule that always produces an active pattern.
        // Excluded rules and reasons:
        //   001 (drone root — single whole note per bar, worst case)
        //   002 (root-fifth slow walk — 30-step hold across 2 bars = whole note × 2)
        //   003 (unevolved = 4 boring quarter-note root hits per bar)
        //   004 (Moroder drift — 14–30 step holds = whole notes)
        //   013 (sub-bass doublet — too sparse for a bridge part)
        // All included rules have max note duration ≤ 7 steps — no whole notes, no half-note ties.
        let bridgeMelodyBassRules = ["KOS-BASS-009", "KOS-BASS-010",
                                     "KOS-BASS-011", "KOS-BASS-012"]
        let bridgeMelodyBassRule = bridgeMelodyBassRules[rng.nextInt(upperBound: bridgeMelodyBassRules.count)]

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard let entry = tonalMap.entry(atBar: bar) else { continue }
            let barStart = bar * 16

            // KOS-BASS-005: truly absent in body — no notes at all
            if bassAbsent && section.label != .intro && section.label != .outro { continue }

            // Intro: single sustained drone — no retriggers, no velocity ramp.
            // PlaybackEngine handles the volume fade 0→1.0 via boosts[kTrackBass].outputVolume.
            // Note 1: tonic root, full intro duration minus 2 steps.
            // Note 2 (4+ bar intros only): soft octave enters at bar 2 — one extra voice,
            //   no attack after that, pure harmonic build through the intro.
            if section.label == .intro {
                guard bar == section.startBar else { continue }
                let root      = bassRoot(entry: entry, frame: frame)
                let introSteps = (section.endBar - section.startBar) * 16
                events.append(MIDIEvent(stepIndex: barStart, note: root,
                                        velocity: 65, durationSteps: introSteps - 2))
                let introLen = section.endBar - section.startBar
                if introLen >= 4 {
                    let octaveNote = UInt8(min(127, Int(root) + 12))
                    let octaveStart = barStart + 32  // bar 2
                    let octaveDur   = introSteps - 32 - 2
                    if octaveDur > 0 {
                        events.append(MIDIEvent(stepIndex: octaveStart, note: octaveNote,
                                                velocity: 38, durationSteps: octaveDur))
                    }
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

            // Bridge A-1 (.bridge): ascending or descending walk across phases.
            // Direction: ascending 67% (startBar % 3 != 2), descending 33% — matches arpeggio/pads.
            // Phase pitch offsets — ascending: root→3rd→5th→oct; descending: oct→5th→3rd→root.
            // Pattern variant is chosen once per bridge (deterministic from startBar):
            //   V0 Root anchor   — phase note beat 1, root beat 3 (pedal-point feel)
            //   V1 Approach+land — chromatic approach → phase note → root (walking bass)
            //   V2 Synco push    — phase beat 1, syncopated push beat 2, root beat 3 (Kraftwerk)
            //   V3 Three-note    — root → passing → phase → root (most active figure)
            //   V4 Held + tail   — phase note held 6 steps, root staccato step 10 (spacious)
            if section.label == .bridge {
                let bridgeLen    = max(1, section.endBar - section.startBar)
                let barInBridge  = bar - section.startBar
                let phase        = min(3, barInBridge * 4 / bridgeLen)
                let ascending    = section.startBar % 3 != 2
                let root         = bassRoot(entry: entry, frame: frame)
                let rootInt      = Int(root)
                // Use mode-appropriate third: major 3rd in Ionian/Mixolydian, minor 3rd otherwise
                let thirdOff     = frame.mode.nearestInterval(4)
                let offsets      = ascending ? [0, thirdOff, 7, 12] : [12, 7, thirdOff, 0]
                let phaseNote    = UInt8(max(28, min(80, rootInt + offsets[phase])))
                let velBases     = ascending ? [75, 83, 91, 99] : [99, 91, 83, 75]
                let baseVel      = velBases[phase]
                let bassVariant  = (section.startBar / 2) % 5

                func v(_ base: Int, _ jitter: Int = 7) -> UInt8 {
                    UInt8(max(20, min(127, base + rng.nextInt(upperBound: jitter) - (jitter / 2))))
                }

                switch bassVariant {

                case 0:
                    // Root anchor: phase note on beat 1, root returns on beat 3.
                    // Pedal-point feel — the climbing note contrasts with the stable anchor.
                    events.append(MIDIEvent(stepIndex: barStart,     note: phaseNote, velocity: v(baseVel),      durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: barStart + 8, note: root,      velocity: v(baseVel - 14), durationSteps: 3))

                case 1:
                    // Approach + land: chromatic approach note (1 semitone toward phase) → land.
                    // Ascending approaches from below; descending from above.
                    let appOffset  = ascending ? -1 : 1
                    let approach   = UInt8(max(28, min(80, rootInt + offsets[phase] + appOffset)))
                    events.append(MIDIEvent(stepIndex: barStart,      note: approach,  velocity: v(baseVel - 10, 5), durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: barStart + 2,  note: phaseNote, velocity: v(baseVel),         durationSteps: 4))
                    events.append(MIDIEvent(stepIndex: barStart + 8,  note: root,      velocity: v(baseVel - 12, 5), durationSteps: 3))

                case 2:
                    // Syncopated push: phase note beat 1, repeat on beat 2 (push), root beat 3.
                    // The repeated hit before beat 3 gives a mechanical Kraftwerk groove.
                    events.append(MIDIEvent(stepIndex: barStart,     note: phaseNote, velocity: v(baseVel),          durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: barStart + 4, note: phaseNote, velocity: v(baseVel - 6, 5),   durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: barStart + 8, note: root,      velocity: v(baseVel - 14),     durationSteps: 3))

                case 3:
                    // Three-note pickup figure: root → passing → phase note → root echo.
                    // Passing tone is the semitone midpoint (min 1 step from root to avoid unison).
                    let rawMid   = offsets[phase] / 2
                    let midOff   = rawMid == 0 ? 1 : rawMid
                    let passing  = UInt8(max(28, min(80, rootInt + midOff)))
                    events.append(MIDIEvent(stepIndex: barStart,      note: root,      velocity: v(baseVel - 10, 5), durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: barStart + 2,  note: passing,   velocity: v(baseVel - 5, 5),  durationSteps: 2))
                    events.append(MIDIEvent(stepIndex: barStart + 4,  note: phaseNote, velocity: v(baseVel),         durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: barStart + 8,  note: phaseNote, velocity: v(baseVel - 6, 5),  durationSteps: 3))
                    events.append(MIDIEvent(stepIndex: barStart + 12, note: root,      velocity: v(baseVel - 16, 5), durationSteps: 2))

                default:
                    // Held + tail: phase note held 6 steps, brief root staccato at step 10.
                    // Spacious and atmospheric — lets the escalating drums breathe.
                    events.append(MIDIEvent(stepIndex: barStart,      note: phaseNote, velocity: v(baseVel),     durationSteps: 6))
                    events.append(MIDIEvent(stepIndex: barStart + 10, note: root,      velocity: v(baseVel - 18, 5), durationSteps: 2))
                }
                continue
            }

            // Bridge A-2 (.bridgeAlt): staccato double on hit bars (even), walking response on odd bars.
            // Hit bars (even): bass doubles the drum+pads hit — beat 1 staccato, then silent.
            // Response bars (odd): 2-note walking figure starting beat 3 — call-and-response texture.
            if section.label == .bridgeAlt {
                let bridgeBar = bar - section.startBar
                let root      = bassRoot(entry: entry, frame: frame)
                let rootPC    = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
                if bridgeBar % 2 == 0 {
                    // Double the synchronized hit — staccato, same step as drums
                    events.append(MIDIEvent(stepIndex: barStart, note: root, velocity: 95, durationSteps: 2))
                } else {
                    // 2-note scale walk from root: root → 2nd degree, starting beat 1
                    let intervals = frame.mode.intervals
                    let step2Int  = intervals.count > 1 ? intervals[1] : 2
                    var step2Midi = 36 + (rootPC + step2Int) % 12
                    while step2Midi < 40 { step2Midi += 12 }
                    while step2Midi > 55 { step2Midi -= 12 }
                    events.append(MIDIEvent(stepIndex: barStart,     note: root,              velocity: 85, durationSteps: 6))
                    events.append(MIDIEvent(stepIndex: barStart + 8, note: UInt8(step2Midi),  velocity: 78, durationSteps: 5))
                }
                continue
            }

            // Bridge B (.bridgeMelody): use a proper bass rule (picked once per song) rather than
            // a hardcoded root pulse. Adds variety and keeps the bridge musically interesting.
            if section.label == .bridgeMelody {
                events += primaryBassBar(ruleID: bridgeMelodyBassRule, barStart: barStart, bar: bar,
                                         entry: entry, frame: frame, rng: &rng,
                                         totalBars: frame.totalBars, isBody: true,
                                         structure: structure)
                continue
            }

            // Sub-layer A: long harmonic anchor (KOS-RULE-17)
            let isBody = section.label != .intro && section.label != .outro
            let useVariation: Bool
            if ruleID == "KOS-BASS-008" {
                useVariation = bar >= cos008EvoStart && bar < cos008EvoEnd
            } else {
                useVariation = variationBars.contains(bar)
            }
            if isBody {
                if !wasInVariation && useVariation  { bassEvolutionBars.append(bar) }
                if wasInVariation  && !useVariation { bassEvolutionBars.append(bar) }
                wasInVariation = useVariation
            }
            // KOS-BASS-011: rotate sub-pattern at body section boundaries and every 16 bars
            if ruleID == "KOS-BASS-011" && isBody {
                let isNewBodySection = section.startBar == bar && !section.label.isBridge
                let bars16Elapsed    = (bar - kos011LastSwitch) >= 16
                if isNewBodySection || bars16Elapsed {
                    let r = rng.nextDouble()
                    kos011Variant    = r < 0.25 ? 0 : r < 0.60 ? 1 : 2
                    kos011LastSwitch = bar
                }
            }

            events += primaryBassBar(ruleID: ruleID, barStart: barStart, bar: bar,
                                     sectionStartBar: section.startBar,
                                     entry: entry, frame: frame, rng: &rng,
                                     totalBars: frame.totalBars, isBody: isBody,
                                     structure: structure, useVariation: useVariation,
                                     kos011Variant: kos011Variant)

            // Sub-layer B: rhythmic staccato movement (KOS-RULE-17)
            if useDualLayer {
                events += rhythmicBassLayer(barStart: barStart, entry: entry, frame: frame, rng: &rng)
            }

            // Pulsating tremolo layer (KOS-RULE-23)
            if usePulsatingLayer {
                let bodyStartBar  = structure.introSection?.endBar ?? 0
                let barInBody     = bar - bodyStartBar
                // Primary trigger: every 4 bars (unchanged)
                let primaryFire   = bar % 4 == 0
                // After 12 bars: occasional phase-shifted trigger on bar%4==2 (~30%)
                let altFire       = barInBody >= 12 && bar % 4 == 2 && rng.nextDouble() < 0.30
                if primaryFire || altFire {
                    events += pulsatingTremoloLayer(barStart: barStart, entry: entry, frame: frame,
                                                    barInBody: barInBody, rng: &rng)
                }
            }
        }

        // KOS-BASS-001 fifth-breath detection: the dual layer always provides root+fifth pitch
        // classes so the fingerprint detector in buildStepAnnotations can't see the transition.
        // Post-pass: compare the beat-1 note against the expected chord root; when the primary
        // drone switches to fifth (or back), record that bar explicitly.
        if ruleID == "KOS-BASS-001" {
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

        // KOS-BASS-011 Autobahn: fire evolution at every B-section entry and every 16 body bars.
        // The pattern is the same every bar, so the variationBars mechanism handles B-section
        // transitions; add extra fires every 16 bars so the log shows a sense of progression.
        if ruleID == "KOS-BASS-011" {
            var lastFireBar = -16
            for bar in 0..<frame.totalBars {
                guard let sec = structure.section(atBar: bar),
                      sec.label != .intro && sec.label != .outro else { continue }
                let isBEntry = sec.label == .B && sec.startBar == bar
                let is16Cycle = (bar - lastFireBar) >= 16
                guard isBEntry || (is16Cycle && bar % 16 == 0) else { continue }
                bassEvolutionBars.append(bar)
                lastFireBar = bar
            }
        }

        return events
    }

    // MARK: - Primary bass (Sub-layer A)

    private static func primaryBassBar(
        ruleID: String, barStart: Int, bar: Int, sectionStartBar: Int = 0,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, totalBars: Int, isBody: Bool,
        structure: SongStructure, useVariation: Bool = false,
        kos011Variant: Int = 0
    ) -> [MIDIEvent] {
        switch ruleID {
        case "KOS-BASS-001": return droneRootBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                  rng: &rng, totalBars: totalBars, isBody: isBody)
        case "KOS-BASS-002": return rootFifthWalkBar(barStart: barStart, bar: bar, entry: entry, frame: frame, rng: &rng)
        case "KOS-BASS-003": return pedalPulseBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                   structure: structure, totalBars: totalBars, rng: &rng)
        case "KOS-BASS-004": return moroderDriftBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "KOS-BASS-005": return droneRootBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                  rng: &rng, totalBars: totalBars, isBody: false)
        case "KOS-BASS-008": return hallogalloLockBar(barStart: barStart, bar: bar, entry: entry,
                                                       frame: frame, useVariation: useVariation)
        case "KOS-BASS-009": return crawlingWalkBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "KOS-BASS-010": return moroderPulseBar(barStart: barStart, entry: entry, frame: frame,
                                                     useVariation: useVariation, rng: &rng)
        case "KOS-BASS-011": return kraftwerkAutobahnBar(barStart: barStart, bar: bar, entry: entry,
                                                          frame: frame, useVariation: useVariation,
                                                          subVariant: kos011Variant)
        case "KOS-BASS-012": return mccartneyPBWBar(barStart: barStart, bar: bar,
                                                     sectionStartBar: sectionStartBar,
                                                     entry: entry, frame: frame,
                                                     useVariation: useVariation, rng: &rng)
        case "KOS-BASS-013": return loscilSubBassPulseBar(barStart: barStart, bar: bar, entry: entry,
                                                           frame: frame, useVariation: useVariation,
                                                           rng: &rng)
        default:             return droneRootBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                  rng: &rng, totalBars: totalBars, isBody: isBody)
        }
    }

    // MARK: - KOS-BAS-001: Drone Root
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

    // MARK: - KOS-BAS-002: Root-Fifth Slow Walk
    // Root phase (bars 0–3 of 8-bar cycle) alternating with fifth/b7 phase (bars 4–7).
    // Attacks every 2 bars; probabilistic variations on articulation, timing, approach tones,
    // and a ghost echo within long holds to avoid the mechanical sustain feel.

    private static func rootFifthWalkBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let cycle = bar % 8

        // Only attack on even bars of the cycle
        guard cycle % 2 == 0 else { return [] }

        let rootPC_rfw = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let sPCs_rfw   = Set(frame.mode.intervals.map { (keySemitone(frame.key) + $0) % 12 })
        func bassPC_rfw(_ interval: Int) -> UInt8 {
            let raw = (rootPC_rfw + interval) % 12
            let pc  = sPCs_rfw.contains(raw) ? raw : {
                for d in 1...6 {
                    if sPCs_rfw.contains((raw + d) % 12) { return (raw + d) % 12 }
                    if sPCs_rfw.contains((raw - d + 12) % 12) { return (raw - d + 12) % 12 }
                }
                return raw
            }()
            var m = 36 + pc
            while m < 40 { m += 12 }
            while m > 55 { m -= 12 }
            return UInt8(m)
        }
        let root    = bassPC_rfw(0)
        // 20% chance use b7 instead of fifth — more modal, suits Dorian well
        let useB7   = rng.nextDouble() < 0.20
        let upper   = useB7 ? bassPC_rfw(10) : bassPC_rfw(7)
        let note    = cycle < 4 ? root : upper

        // Articulation: staccato (12 steps), medium (22 steps), full hold (30 steps)
        let durChoice = rng.nextDouble()
        let mainDur: Int
        switch durChoice {
        case ..<0.25: mainDur = 12   // staccato — leaves a breath before next attack
        case ..<0.55: mainDur = 22   // medium hold
        default:      mainDur = 30   // original full hold
        }

        // Timing: 30% chance of a one-16th syncopated push (attack on step 2 rather than 0)
        let attackStep = rng.nextDouble() < 0.30 ? 2 : 0
        let vel        = UInt8(88 + rng.nextInt(upperBound: 18))   // 88–105

        var events: [MIDIEvent] = []

        // Optional approach tone: 25% chance of a 2-step passing note one diatonic step below
        // the main note, fired 2 steps before the attack (or at step 0 if syncopated)
        if rng.nextDouble() < 0.25 && attackStep >= 2 {
            let scaleIntervals = entry.sectionMode.intervals
            let notePc = Int(note) % 12
            // Find the scale interval just below notePc
            if let belowInterval = scaleIntervals.filter({ ($0 % 12) < notePc }).last {
                let approachPC  = belowInterval % 12
                var approachNote = Int(note) - (notePc - approachPC)
                if approachNote < 36 { approachNote += 12 }
                events.append(MIDIEvent(stepIndex: barStart,
                                        note: UInt8(approachNote),
                                        velocity: UInt8(vel - 20),
                                        durationSteps: 2))
            }
        }

        // Main note
        events.append(MIDIEvent(stepIndex: barStart + attackStep,
                                note: note, velocity: vel, durationSteps: mainDur))

        // Ghost echo: for longer holds, 40% chance of a soft repeat on beat 3 (step 8)
        // at ~60% velocity — implies the note ringing rather than a hard mechanical sustain
        if mainDur >= 22 && rng.nextDouble() < 0.40 {
            let echoStep = attackStep + 8
            let echoEnd  = attackStep + mainDur
            if echoStep < echoEnd {
                events.append(MIDIEvent(stepIndex: barStart + echoStep,
                                        note: note,
                                        velocity: UInt8(Double(vel) * 0.60),
                                        durationSteps: echoEnd - echoStep))
            }
        }

        return events
    }

    // MARK: - KOS-BAS-003: Pedal Pulse with Mid-Song Evolution
    //
    // Evolution window: bars within the middle third of body sections.
    //   Intro + body_start … body_start + bodyLen/3  → plain pedal pulse
    //   body_start + bodyLen/3 … body_start + 2*bodyLen/3 → evolved pattern
    //   body_start + 2*bodyLen/3 … outro → devolve back (plain pulse)
    //
    // Evolved pattern (KOS-BASS-003-EVO):
    //   Beat 1  → root,  vel 100, dur 3 (anchor)
    //   Beat 1+ → fifth, vel 78,  dur 2 (syncopated off-beat push, step 2)
    //   Beat 2  → root,  vel 88,  dur 3
    //   Beat 3  → fifth, vel 95,  dur 3 (harmonic lift)
    //   Beat 3+ → third, vel 72,  dur 2 (passing tone, step 10)
    //   Beat 4  → root,  vel 88,  dur 3 (return)
    //
    // The fifth and third are derived via pitch-class to respect KOS-RULE-06 range.

    private static func pedalPulseBar(
        barStart: Int, bar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        structure: SongStructure, totalBars: Int,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let root = bassRoot(entry: entry, frame: frame)

        // Determine body boundaries
        guard let introSection = structure.introSection else {
            return pedalPulseSimple(barStart: barStart, root: root, fifth: nil,
                                    barInBody: 0, rng: &rng)
        }
        let bodyStart = introSection.endBar
        let outroStart = structure.outroSection?.startBar ?? totalBars
        let bodyLen = max(1, outroStart - bodyStart)

        let barInBody = bar - bodyStart
        let third1  = bodyLen / 3
        let third2  = (bodyLen * 2) / 3

        // When a B section exists, enrich throughout B; otherwise use middle-third fallback
        let shouldEvolve: Bool
        if structure.hasBSection {
            shouldEvolve = structure.inBSection(atBar: bar)
        } else {
            shouldEvolve = bodyLen >= 12 && barInBody >= third1 && barInBody < third2
        }

        if shouldEvolve {
            return pedalPulseEvolved(barStart: barStart, entry: entry, frame: frame, root: root, rng: &rng)
        }

        // Compute fifth for optional tonal variation in plain sections
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        var fifthMidi = 36 + fifthPC
        while fifthMidi < 40 { fifthMidi += 12 }
        while fifthMidi > 55 { fifthMidi -= 12 }

        return pedalPulseSimple(barStart: barStart, root: root, fifth: UInt8(fifthMidi),
                                barInBody: barInBody, rng: &rng)
    }

    // Plain pedal pulse — four-on-the-floor root pulse with TD-style breathing:
    // ~15% rest bars, ~10% half-time (beats 1+3 only), velocity wobble ±8.
    // After 12 bars in body: ~20% chance beats 2+4 use the fifth — subtle tonal lift
    // that breaks long monotone stretches without abandoning the pedal character.
    private static func pedalPulseSimple(
        barStart: Int, root: UInt8, fifth: UInt8?,
        barInBody: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Rest bar: ~15%
        if rng.nextDouble() < 0.15 { return [] }

        // After 12 bars on same root, occasionally alternate beats 2+4 to the fifth (~20%)
        let useFifthBeats = barInBody >= 12 && fifth != nil && rng.nextDouble() < 0.20

        let baseVels: [Int] = [100, 88, 95, 88]
        var events: [MIDIEvent] = []

        // Half-time bar: ~10% — play only beats 1 and 3
        let halfTime = rng.nextDouble() < 0.10
        let steps = halfTime ? [0, 8] : [0, 4, 8, 12]

        for (i, step) in steps.enumerated() {
            let beatIndex   = halfTime ? i * 2 : i   // map back to beat 0-3
            let isOffBeat   = beatIndex == 1 || beatIndex == 3
            let note        = useFifthBeats && isOffBeat ? fifth! : root
            let baseVel     = halfTime ? baseVels[i * 2] : baseVels[i]
            // Fifth beats play slightly softer — they're colour, not anchor
            let velBase     = useFifthBeats && isOffBeat ? baseVel - 10 : baseVel
            let wobble      = rng.nextInt(upperBound: 17) - 8   // ±8
            let vel         = UInt8(max(50, min(115, velBase + wobble)))
            events.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                    velocity: vel, durationSteps: 3))
        }
        return events
    }

    // Evolved pedal pulse: adds fifth and minor-third passing tones between beats, with velocity wobble.
    private static func pedalPulseEvolved(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, root: UInt8,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Compute fifth and minor third via pitch-class (KOS-RULE-06: MIDI 40–55)
        let rootPC  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC = (rootPC + 7) % 12
        let thirdPC = (rootPC + frame.mode.nearestInterval(4)) % 12  // mode-appropriate third

        var fifthMidi = 36 + fifthPC
        while fifthMidi < 40 { fifthMidi += 12 }
        while fifthMidi > 55 { fifthMidi -= 12 }

        var thirdMidi = 36 + thirdPC
        while thirdMidi < 40 { thirdMidi += 12 }
        while thirdMidi > 55 { thirdMidi -= 12 }

        let fifth = UInt8(fifthMidi)
        let third = UInt8(thirdMidi)

        func wobble(_ base: Int) -> UInt8 {
            UInt8(max(50, min(115, base + rng.nextInt(upperBound: 13) - 6)))
        }

        return [
            // Beat 1: root anchor
            MIDIEvent(stepIndex: barStart,      note: root,  velocity: wobble(100), durationSteps: 3),
            // Beat 1 off-beat push: fifth syncopation (step 2 = 0.5 beat after beat 1)
            MIDIEvent(stepIndex: barStart + 2,  note: fifth, velocity: wobble(78),  durationSteps: 2),
            // Beat 2: root
            MIDIEvent(stepIndex: barStart + 4,  note: root,  velocity: wobble(88),  durationSteps: 3),
            // Beat 3: fifth harmonic lift
            MIDIEvent(stepIndex: barStart + 8,  note: fifth, velocity: wobble(95),  durationSteps: 3),
            // Beat 3 off-beat: minor third passing tone (step 10)
            MIDIEvent(stepIndex: barStart + 10, note: third, velocity: wobble(72),  durationSteps: 2),
            // Beat 4: root return
            MIDIEvent(stepIndex: barStart + 12, note: root,  velocity: wobble(88),  durationSteps: 3),
        ]
    }

    // MARK: - KOS-BAS-004: Moroder Drift
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
            // Soft ghost pulse — bass should never be silent for a full bar.
            // Short hold, low velocity — a barely-there presence under the ringing cycle-0 note.
            return [MIDIEvent(stepIndex: barStart, note: root, velocity: 48, durationSteps: 6)]
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

    // MARK: - KOS-BASS-008: Hallogallo Lock (Kosmic)
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

    // MARK: - KOS-BASS-009: Crawling Walk (Kosmic)
    // 2-bar pattern with approach note chromaticism. Adapted from Motorik BAS-003
    // with Kosmic pitch range (MIDI 40–55) and lower velocities for the spacious feel.
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

    // MARK: - KOS-BASS-010: Moroder Pulse (Kosmic)
    // Sequential 8th-note pattern: root-root-fifth-fifth-b7-b7-root-root.
    // Adapted from Giorgio Moroder sequencer feel (as in "I Feel Love").
    // Velocity 100 flat (KOS-RULE-05). Notes in Kosmic range MIDI 40–55.
    // b7 is a natural scale tone in Dorian/Aeolian — no clash.

    private static func moroderPulseBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        useVariation: Bool = false, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC   = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let fifthPC  = (rootPC + 7) % 12
        let scalePCs = Set(frame.mode.intervals.map { (keySemitone(frame.key) + $0) % 12 })
        // b7 above the chord root may be outside the song's scale when chord is non-tonic.
        // Snap to nearest scale PC to prevent out-of-scale bass notes.
        let b7raw    = (rootPC + 10) % 12
        let b7PC     = scalePCs.contains(b7raw) ? b7raw : {
            for d in 1...6 {
                if scalePCs.contains((b7raw + d) % 12) { return (b7raw + d) % 12 }
                if scalePCs.contains((b7raw - d + 12) % 12) { return (b7raw - d + 12) % 12 }
            }
            return b7raw
        }()
        // M6 (9 semitones) gives a diatonic 6th in Dorian/Aeolian — distinct from b7
        let m6raw    = (rootPC + 9) % 12
        let m6PC     = scalePCs.contains(m6raw) ? m6raw : b7PC  // fallback to snapped b7

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

    // MARK: - KOS-BASS-011: Kraftwerk driving bass — rotates through 4 Autobahn patterns
    //
    // Sub-patterns (subVariant), all drawn from the Kraftwerk Autobahn MIDI file:
    //   0 = Pattern D — sparse 4-note skeleton (bars 175-180):
    //         step 0 root(q), step 4 octave(e), step 6 fourth(e), step 14 fifth(e)
    //   1 = Pattern E — canonical full hook (bars 122-246, the main riff):
    //         step 0 root(q), step 4 octave(e), step 6 fourth(e), step 8 fourth(dotq), step 14 fifth(e)
    //         The long held fourth at step 8 is the defining sound — tension then release to the fifth.
    //   2 = Pattern C — 8th-note octave trill (bars 21-27):
    //         all 8 eighth-note steps alternating root/octave — dense, high-energy, motorik drive
    //
    // Bar%8==7 (lock bar): root + octave only across all variants — strips scale tones, motor feel.
    // B-section variation (useVariation): in patterns D and E, b7th replaces the 4th.
    private static func kraftwerkAutobahnBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        useVariation: Bool = false, subVariant: Int = 0
    ) -> [MIDIEvent] {
        let rootPC_kw  = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let sPCs_kw    = Set(frame.mode.intervals.map { (keySemitone(frame.key) + $0) % 12 })
        func bassPC_kw(_ interval: Int, lo: Int, hi: Int) -> UInt8 {
            let raw = (rootPC_kw + interval) % 12
            let pc  = sPCs_kw.contains(raw) ? raw : {
                for d in 1...6 {
                    if sPCs_kw.contains((raw + d) % 12) { return (raw + d) % 12 }
                    if sPCs_kw.contains((raw - d + 12) % 12) { return (raw - d + 12) % 12 }
                }
                return raw
            }()
            var m = 36 + pc
            while m < lo { m += 12 }
            while m > hi { m -= 12 }
            return UInt8(m)
        }
        let root   = bassPC_kw(0, lo: 40, hi: 55)
        let octave = UInt8(clamped(Int(root) + 12, low: 48, high: 67))  // octave: +12 is same PC, safe
        let fourth = bassPC_kw(5,  lo: 40, hi: 55)
        let fifth  = bassPC_kw(7,  lo: 40, hi: 55)
        let b7     = bassPC_kw(10, lo: 40, hi: 58)

        // Lock bar: root + octave only — sparse, motor-like (all patterns)
        if bar % 8 == 7 {
            return [
                MIDIEvent(stepIndex: barStart,     note: root,   velocity: 89, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 4, note: octave, velocity: 89, durationSteps: 2),
            ]
        }

        switch subVariant {

        case 1:
            // Pattern E: canonical Autobahn hook — the actual main riff.
            // Held fourth at step 8 is the defining feature (dotted quarter = 6 steps holds into beat 3).
            let midNote: UInt8 = useVariation ? b7 : fourth
            let midVel:  UInt8 = useVariation ? 82 : 86
            return [
                MIDIEvent(stepIndex: barStart,      note: root,    velocity: 89, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: octave,  velocity: 89, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 6,  note: midNote, velocity: midVel, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 8,  note: midNote, velocity: 84, durationSteps: 6),  // long held note
                MIDIEvent(stepIndex: barStart + 14, note: fifth,   velocity: 84, durationSteps: 2),
            ]

        case 2:
            // Pattern C: 8th-note octave trill — all 8 subdivisions alternating root/octave.
            // Dense and driving; high-energy contrast to the sparser patterns.
            // Velocity alternates: on-beat slightly louder, off-beat softer for natural groove.
            return stride(from: 0, to: 16, by: 2).map { step in
                let onBeat = (step % 4 == 0)
                let note   = (step % 4 == 0) ? root : octave
                let vel    = UInt8(onBeat ? 89 : 80)
                return MIDIEvent(stepIndex: barStart + step, note: note, velocity: vel, durationSteps: 2)
            }

        default:
            // Pattern D: sparse 4-note skeleton — the current implementation (most common)
            let midNote: UInt8 = useVariation ? b7 : fourth
            let midVel:  UInt8 = useVariation ? 82 : 86
            return [
                MIDIEvent(stepIndex: barStart,      note: root,    velocity: 89, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 4,  note: octave,  velocity: 89, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 6,  note: midNote, velocity: midVel, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 14, note: fifth,   velocity: 84, durationSteps: 2),
            ]
        }
    }

    // MARK: - KOS-BAS-012: McCartney PBW — "Paperback Writer" (1966) Mixolydian riff
    // root–fifth–root–b7–fifth–root–mode3rd–root in 8 8th-notes.
    // The flat-seventh (b7) gives a blues/Mixolydian quality — diatonic in Dorian and Mixolydian,
    // which are common Kosmic modes. Falls back to fifth in pure major chord contexts.
    // The riff cycles identically each bar — becomes hypnotic at slower Kosmic tempos.

    private static func mccartneyPBWBar(
        barStart: Int, bar: Int, sectionStartBar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        useVariation: Bool = false, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        // Use pitch-class arithmetic (not naive note+interval clamping) so that the
        // fifth and b7 always fall on the correct pitch class regardless of octave.
        // e.g. Eb root=51: naive +7=58 clamps to 55=G (wrong); PC approach gives Bb=46.
        let rootPC   = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let scalePCs = Set(frame.mode.intervals.map { (keySemitone(frame.key) + $0) % 12 })
        func bassPC(_ interval: Int) -> UInt8 {
            let raw = (rootPC + interval) % 12
            let pc  = scalePCs.contains(raw) ? raw : {
                for d in 1...6 {
                    if scalePCs.contains((raw + d) % 12) { return (raw + d) % 12 }
                    if scalePCs.contains((raw - d + 12) % 12) { return (raw - d + 12) % 12 }
                }
                return raw
            }()
            var m = 36 + pc
            while m < 40 { m += 12 }
            while m > 55 { m -= 12 }
            return UInt8(m)
        }
        let root  = bassPC(0)

        // Use chord type (not song mode) to determine the third quality.
        // frame.mode.nearestInterval would give minor third in Dorian even when the
        // active chord is major — producing C natural against an A major chord, for example.
        let isMajorContext: Bool
        switch entry.chordWindow.chordType {
        case .major, .sus2, .sus4, .add9: isMajorContext = true
        default:                          isMajorContext = false
        }
        let fifth     = bassPC(7)
        let third     = bassPC(isMajorContext ? 4 : 3)
        let flatSeven = isMajorContext ? fifth : bassPC(10)

        let pitches: [UInt8] = [root, fifth, root, flatSeven, fifth, root, third, root]
        let vels:    [UInt8] = [100,  88,    92,   84,        86,    82,   88,    78  ]

        let posInSection = bar - sectionStartBar

        // After 16 bars: ~20% of bars drop to root-only — the bass briefly breathes
        if posInSection >= 16 && rng.nextDouble() < 0.20 {
            return [MIDIEvent(stepIndex: barStart, note: root, velocity: 85, durationSteps: 4)]
        }

        // First 16 bars: play only the first 4 notes — pattern builds gradually
        let activeCount = posInSection < 16 ? 4 : pitches.count
        var evs = pitches.prefix(activeCount).enumerated().map { i, note in
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

    // MARK: - KOS-RULE-17: Rhythmic staccato bass layer (sub-layer B)
    // Velocity 80–88, short staccato hits on off-beats.
    // Step offsets avoid beat 1 (step 0) to prevent double-attack with sub-layer A,
    // and avoid step 14 which bleeds into the next bar's primary attack.
    //
    // Only called when primary rule is NOT KOS-BASS-004, because that rule plays
    // a chromatic neighbour (root+1) on every 4th bar — combining with the staccato
    // root produces a minor-2nd clash.

    private static func rhythmicBassLayer(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let root = bassRoot(entry: entry, frame: frame)

        // Compute fifth via pitch-class to avoid range-clamping wrong notes.
        // Scale-snap: if the raw fifth PC is non-diatonic, move to nearest in-scale PC.
        let rootPC     = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let scalePCs   = Set(frame.mode.intervals.map { (keySemitone(frame.key) + $0) % 12 })
        let rawFifthPC = (rootPC + 7) % 12
        var bestFifthPC = rawFifthPC
        if !scalePCs.contains(rawFifthPC) {
            for d in 1...6 {
                if scalePCs.contains((rawFifthPC + d) % 12) { bestFifthPC = (rawFifthPC + d) % 12; break }
                if scalePCs.contains((rawFifthPC - d + 12) % 12) { bestFifthPC = (rawFifthPC - d + 12) % 12; break }
            }
        }
        var fifthMidi = 36 + bestFifthPC
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

    // MARK: - KOS-RULE-23: Pulsating tremolo layer
    //
    // Evolves over the course of the body to break long monotone stretches:
    //   bars 0–11:  standard 16th-note flutter, root only (original character)
    //   bars 12+:   ~20% chance whole bar plays fifth instead of root (tonal lift)
    //   bars 12+:   ~30% chance 8th-note density (every 2 steps, no ghost notes) —
    //               less frantic, creates contrast with the 16th-note bars
    //   bars 20+:   ~20% chance root/fifth alternation per beat (root on 1+3, fifth on 2+4)

    private static func pulsatingTremoloLayer(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        barInBody: Int, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let root       = bassRoot(entry: entry, frame: frame)
        let rootPC     = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // Scale-snap: if the raw fifth PC is non-diatonic, move to nearest in-scale PC.
        let scalePCs   = Set(frame.mode.intervals.map { (keySemitone(frame.key) + $0) % 12 })
        let rawFifthPC = (rootPC + 7) % 12
        var bestFifthPC = rawFifthPC
        if !scalePCs.contains(rawFifthPC) {
            for d in 1...6 {
                if scalePCs.contains((rawFifthPC + d) % 12) { bestFifthPC = (rawFifthPC + d) % 12; break }
                if scalePCs.contains((rawFifthPC - d + 12) % 12) { bestFifthPC = (rawFifthPC - d + 12) % 12; break }
            }
        }
        var fifthMidi = 36 + bestFifthPC
        while fifthMidi < 40 { fifthMidi += 12 }
        while fifthMidi > 55 { fifthMidi -= 12 }
        let fifth = UInt8(fifthMidi)

        // Choose tonal content for this bar
        enum ToneMode { case root, fifth, rootFifthAlt }
        let toneMode: ToneMode
        if barInBody >= 20 && rng.nextDouble() < 0.20 {
            toneMode = .rootFifthAlt  // root on beats 1+3, fifth on 2+4
        } else if barInBody >= 12 && rng.nextDouble() < 0.20 {
            toneMode = .fifth
        } else {
            toneMode = .root
        }

        // Choose rhythmic density: 16th-note (step=1) or 8th-note (step=2)
        let stepSize = barInBody >= 12 && rng.nextDouble() < 0.30 ? 2 : 1

        var evs: [MIDIEvent] = []
        var alternateHigh = true
        for step in stride(from: 0, to: 16, by: stepSize) {
            let note: UInt8
            switch toneMode {
            case .root:         note = root
            case .fifth:        note = fifth
            case .rootFifthAlt: note = (step < 4 || (step >= 8 && step < 12)) ? root : fifth
            }
            let vel: UInt8
            if stepSize == 1 {
                // 16th-note: classic alternating high/ghost pattern
                vel = alternateHigh ? 85 : 20
                alternateHigh.toggle()
            } else {
                // 8th-note: all notes are audible, slight velocity variation
                vel = UInt8(72 + rng.nextInt(upperBound: 16))  // 72–87
            }
            evs.append(MIDIEvent(stepIndex: barStart + step, note: note,
                                 velocity: vel, durationSteps: stepSize))
        }
        return evs
    }

    // MARK: - Note helpers

    // MARK: - KOS-BASS-013: Loscil Sub-Bass Pulse
    // Sub-bass register MIDI 28–43 — below KOS-RULE-06's normal 40–55 floor.
    // Doublet pulse on beat 1: primary hit + slightly quieter repeat 2 steps later.
    // Optional beat-3 note (50% chance) — creates gentle, underwater pumping feel.
    // Every 4 bars (useVariation): octave-up hit replaces beat-3 note for momentary brightness.

    private static func loscilSubBassPulseBar(
        barStart: Int, bar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        useVariation: Bool, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // Sub-bass register: MIDI 28–43
        var subRoot = 24 + rootPC
        while subRoot < 28 { subRoot += 12 }
        while subRoot > 43 { subRoot -= 12 }
        let upOct = Swift.min(55, subRoot + 12)

        var evs: [MIDIEvent] = []

        // Doublet pulse: beat 1 primary hit
        let vel1 = UInt8(48 + rng.nextInt(upperBound: 15))  // 48–62
        evs.append(MIDIEvent(stepIndex: barStart, note: UInt8(subRoot), velocity: vel1, durationSteps: 3))
        // Secondary repeat 2 steps later — quieter, gives the "pulse" feel
        let vel2 = UInt8(max(20, Int(vel1) - 12 - rng.nextInt(upperBound: 8)))
        evs.append(MIDIEvent(stepIndex: barStart + 2, note: UInt8(subRoot), velocity: vel2, durationSteps: 2))

        if useVariation {
            // Octave-up note on beat 3 — momentary brightness every variation window
            evs.append(MIDIEvent(stepIndex: barStart + 8, note: UInt8(upOct),
                                 velocity: UInt8(38 + rng.nextInt(upperBound: 12)), durationSteps: 2))
        } else if rng.nextDouble() < 0.50 {
            // Optional beat-3 sub-bass note (50% chance) — maintains pulse without being rigid
            evs.append(MIDIEvent(stepIndex: barStart + 8, note: UInt8(subRoot),
                                 velocity: UInt8(32 + rng.nextInt(upperBound: 14)), durationSteps: 2))
        }
        return evs
    }

    static func bassRoot(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> UInt8 {
        let rawPC    = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        // Scale-snap: if the chord root is a borrowed/non-diatonic PC, move to the nearest
        // in-scale PC. Prevents clashes when the chord plan uses modal-mixture chord roots.
        let scalePCs = Set(frame.mode.intervals.map { (keySemitone(frame.key) + $0) % 12 })
        let rootPC: Int
        if scalePCs.contains(rawPC) {
            rootPC = rawPC
        } else {
            var best = rawPC
            for d in 1...6 {
                if scalePCs.contains((rawPC + d) % 12) { best = (rawPC + d) % 12; break }
                if scalePCs.contains((rawPC - d + 12) % 12) { best = (rawPC - d + 12) % 12; break }
            }
            rootPC = best
        }
        // KOS-RULE-06: bass in MIDI 40–55
        var midi = 36 + rootPC  // start in octave 2
        while midi < 40 { midi += 12 }
        while midi > 55 { midi -= 12 }
        return UInt8(midi)
    }

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        Swift.max(low, Swift.min(high, v))
    }
}
