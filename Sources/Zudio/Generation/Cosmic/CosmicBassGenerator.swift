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
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {

        // Pick primary bass rule
        let rules:   [String] = ["COS-BASS-001", "COS-BASS-002", "COS-BASS-003", "COS-BASS-004", "COS-BASS-005"]
        let weights: [Double] = [0.30,           0.25,          0.20,           0.15,           0.10]
        let ruleID = rules[rng.weightedPick(weights)]

        // COS-BASS-005 = truly absent bass in body sections (intro/outro still get a root note).
        // Always logged so the status shows "Bass absent in main section".
        // Blocks 006 and 007: no point layering over silence.
        let bassAbsent = ruleID == "COS-BASS-005"
        usedRuleIDs.insert(ruleID)

        // COS-BASS-006: staccato dual layer — blocked with COS-BASS-004 (chromatic
        // neighbour on bar%4==3 would clash with staccato root) and with absent bass.
        let canUseDualLayer = !bassAbsent && ruleID != "COS-BASS-004"
        let useDualLayer    = canUseDualLayer && rng.nextDouble() < 0.55
        if useDualLayer { usedRuleIDs.insert("COS-BASS-006") }

        // COS-BASS-007: pulsating tremolo — mutually exclusive with 006, blocked when absent,
        // and blocked with COS-BASS-004 (tremolo 16th retriggering on bar%4==0 clashes with
        // the Moroder Drift 30-step root hold on the same bar).
        let usePulsatingLayer = !bassAbsent && !useDualLayer && ruleID != "COS-BASS-004" && rng.nextDouble() < 0.45
        if usePulsatingLayer { usedRuleIDs.insert("COS-BASS-007") }

        var events: [MIDIEvent] = []

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar) else { continue }
            guard let entry = tonalMap.entry(atBar: bar) else { continue }
            let barStart = bar * 16

            // COS-BASS-005: truly absent in body — no notes at all
            if bassAbsent && section.label != .intro && section.label != .outro { continue }

            // Intro: single continuous bass note spanning the entire section.
            // Volume fade-in (0 → 1) handled by PlaybackEngine boost ramp — no velocity ramp needed.
            if section.label == .intro {
                guard bar == section.startBar else { continue }
                let root = bassRoot(entry: entry, frame: frame)
                let dur  = max(1, (section.endBar - section.startBar) * 16 - 1)
                events.append(MIDIEvent(stepIndex: barStart, note: root, velocity: 60, durationSteps: dur))
                continue
            }

            // Outro: single continuous bass note spanning the entire section.
            // Volume fade-out (1 → 0) handled by PlaybackEngine boost ramp.
            if section.label == .outro {
                guard bar == section.startBar else { continue }
                let root = bassRoot(entry: entry, frame: frame)
                let dur  = max(1, (section.endBar - section.startBar) * 16 - 1)
                events.append(MIDIEvent(stepIndex: barStart, note: root, velocity: 60, durationSteps: dur))
                continue
            }

            // Sub-layer A: long harmonic anchor (COS-RULE-17)
            let isBody = section.label != .intro && section.label != .outro
            events += primaryBassBar(ruleID: ruleID, barStart: barStart, bar: bar,
                                     entry: entry, frame: frame, rng: &rng,
                                     totalBars: frame.totalBars, isBody: isBody)

            // Sub-layer B: rhythmic staccato movement (COS-RULE-17)
            if useDualLayer {
                events += rhythmicBassLayer(barStart: barStart, entry: entry, frame: frame, rng: &rng)
            }

            // Pulsating tremolo layer (COS-RULE-23)
            if usePulsatingLayer && bar % 4 == 0 {
                events += pulsatingTremoloLayer(barStart: barStart, entry: entry, frame: frame)
            }
        }

        return events
    }

    // MARK: - Primary bass (Sub-layer A)

    private static func primaryBassBar(
        ruleID: String, barStart: Int, bar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, totalBars: Int, isBody: Bool
    ) -> [MIDIEvent] {
        switch ruleID {
        case "COS-BASS-001": return droneRootBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                  rng: &rng, totalBars: totalBars, isBody: isBody)
        case "COS-BASS-002": return rootFifthWalkBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "COS-BASS-003": return pedalPulseBar(barStart: barStart, entry: entry, frame: frame)
        case "COS-BASS-004": return moroderDriftBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "COS-BASS-005": return droneRootBar(barStart: barStart, bar: bar, entry: entry, frame: frame,
                                                  rng: &rng, totalBars: totalBars, isBody: false)
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

    // MARK: - COS-BAS-003: Pedal Pulse
    // Root on every quarter note beat, short duration (4 steps), subtle pulse

    private static func pedalPulseBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root = bassRoot(entry: entry, frame: frame)
        // COS-RULE-05: velocity 100 flat for synth-bass patterns
        return [
            MIDIEvent(stepIndex: barStart,      note: root, velocity: 100, durationSteps: 3),
            MIDIEvent(stepIndex: barStart + 4,  note: root, velocity: 88,  durationSteps: 3),
            MIDIEvent(stepIndex: barStart + 8,  note: root, velocity: 95,  durationSteps: 3),
            MIDIEvent(stepIndex: barStart + 12, note: root, velocity: 88,  durationSteps: 3),
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
