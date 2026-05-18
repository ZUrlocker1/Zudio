// AmbientPadsGenerator.swift — Ambient pads generation
// Copyright (c) 2026 Zack Urlocker
// One rule per song, chosen by weighted roll:
//   AMB-PADS-001 (45%): Sustained chord — long held voicings, harp-roll onset, inversion rotation
//   AMB-PADS-002 (35%): Slow cascade — 3-note low/mid/high stagger, re-attack every 128–192 steps
//   AMB-PADS-003 (20%): Modal cloud — all 7 scale tones, upper-middle register, very soft clusters

import Foundation

struct AmbientPadsGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {
        guard let entry = tonalMap.entry(atBar: 0) else { return [] }

        let bounds    = kRegisterBounds[kTrackPads]!   // low:48, high:84
        let loopSteps = loopBars * 16
        let chordPCs  = entry.chordWindow.chordTones
        let allNotes  = notesInRegister(pitchClasses: chordPCs, low: bounds.low, high: bounds.high)
        guard allNotes.count >= 2 else { return [] }

        let validRules: Set<String> = ["AMB-PADS-001", "AMB-PADS-002", "AMB-PADS-003"]
        let roll   = rng.nextDouble()
        let ruleID: String
        if let forced = forceRuleID, validRules.contains(forced) {
            ruleID = forced
        } else if roll < 0.45 {
            ruleID = "AMB-PADS-001"
        } else if roll < 0.80 {
            ruleID = "AMB-PADS-002"
        } else {
            ruleID = "AMB-PADS-003"
        }
        usedRuleIDs.insert(ruleID)

        switch ruleID {
        case "AMB-PADS-002":
            return slowCascade(allNotes: allNotes, loopSteps: loopSteps, rng: &rng)
        case "AMB-PADS-003":
            let allPCs = chordPCs.union(entry.chordWindow.scaleTensions)
            return modalCloud(pitchClasses: allPCs, loopSteps: loopSteps, rng: &rng)
        default:
            return sustainedChord(allNotes: allNotes, loopSteps: loopSteps, rng: &rng)
        }
    }

    // MARK: - AMB-PADS-001: Sustained chord

    private static func sustainedChord(allNotes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let reattack  = 96 + rng.nextInt(upperBound: 33)
        let duration  = reattack - 4 - rng.nextInt(upperBound: 9)
        let baseVel   = 55 + rng.nextInt(upperBound: 16)
        var invOffset = 0

        var step   = rng.nextInt(upperBound: 8)
        var events: [MIDIEvent] = []
        while step < loopSteps {
            if rng.nextDouble() > 0.30 {
                let r = rng.nextDouble()
                let noteCount = r < 0.20 ? 2 : (r < 0.80 ? 3 : Swift.min(4, allNotes.count))
                let spread = spreadNotesInverted(from: allNotes, count: noteCount, invOffset: invOffset)
                let vel = UInt8(Swift.max(40, Swift.min(95, baseVel + rng.nextInt(upperBound: 11) - 5)))
                let doRoll  = rng.nextDouble() < 0.60
                let rollGap = doRoll ? (1 + rng.nextInt(upperBound: 2)) : 0
                for (ni, note) in spread.enumerated() {
                    let noteStep = step + (doRoll ? ni * rollGap : 0)
                    let dur = Swift.min(duration - (doRoll ? ni * rollGap : 0), loopSteps - noteStep)
                    if dur >= 4 && noteStep < loopSteps {
                        events.append(MIDIEvent(stepIndex: noteStep, note: note, velocity: vel, durationSteps: dur))
                    }
                }
                invOffset = (invOffset + 1) % Swift.max(1, allNotes.count - 2)
            }
            step += reattack
        }
        return events   // step only increases — events are already in step order
    }

    // MARK: - AMB-PADS-002: Slow cascade

    /// Three notes — low/mid/high — staggered 10–20 steps apart, sustain to loop boundary, re-attack every 128–192 steps.
    private static func slowCascade(allNotes: [UInt8], loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let cascade  = [allNotes.first!, allNotes[allNotes.count / 2], allNotes.last!]
        let reattack = 128 + rng.nextInt(upperBound: 65)   // 128–192 steps (8–12 bars)
        let stagger  = 10  + rng.nextInt(upperBound: 11)   // 10–20 steps between notes
        let baseVel  = 35  + rng.nextInt(upperBound: 21)   // 35–55

        var events: [MIDIEvent] = []
        var step = rng.nextInt(upperBound: 16)
        while step < loopSteps {
            for (i, note) in cascade.enumerated() {
                let noteStep = step + i * stagger
                let dur      = loopSteps - noteStep
                guard noteStep < loopSteps, dur >= 16 else { break }   // skip micro-notes at loop boundary
                let vel = UInt8(Swift.max(30, Swift.min(60, baseVel + rng.nextInt(upperBound: 9) - 4)))
                events.append(MIDIEvent(stepIndex: noteStep, note: note, velocity: vel, durationSteps: dur))
            }
            step += reattack
        }
        return events   // step only increases — events are already in step order
    }

    // MARK: - AMB-PADS-003: Modal cloud

    /// All 7 scale tones, upper-middle register (63–84), 3–5 consecutive notes, very soft, 80% fire rate.
    private static func modalCloud(pitchClasses: Set<Int>, loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let cloudNotes = notesInRegister(pitchClasses: pitchClasses, low: 63, high: 84)
        guard cloudNotes.count >= 2 else { return [] }

        let reattack = 80 + rng.nextInt(upperBound: 33)    // 80–112 steps (5–7 bars)
        let duration = reattack - 4 - rng.nextInt(upperBound: 8)
        let baseVel  = 40 + rng.nextInt(upperBound: 16)    // 40–55

        var events: [MIDIEvent] = []
        var step = rng.nextInt(upperBound: 12)
        while step < loopSteps {
            if rng.nextDouble() < 0.80 {
                let noteCount = 3 + rng.nextInt(upperBound: 3)   // 3–5
                let startIdx  = rng.nextInt(upperBound: Swift.max(1, cloudNotes.count - noteCount + 1))
                let endIdx    = Swift.min(startIdx + noteCount, cloudNotes.count)
                let cluster   = Array(cloudNotes[startIdx..<endIdx])
                for note in cluster {
                    let vel    = UInt8(Swift.max(34, Swift.min(62, baseVel + rng.nextInt(upperBound: 9) - 4)))
                    let noteDur = Swift.min(duration, loopSteps - step)
                    if noteDur >= 4 {
                        events.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: noteDur))
                    }
                }
            }
            step += reattack
        }
        return events   // step only increases — events are already in step order
    }

    // MARK: - Ambient Piano Pads (full-song, no loop tiler)

    /// Generates full-song pad events paired to the active piano lead rule.
    /// Called only for Ambient Piano songs — does not use a loop tiler.
    /// 50% chance of returning empty events (pads are optional in this style).
    static func generateAmbientPianoPads(
        pianoRule: String,
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        totalBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>
    ) -> [MIDIEvent] {
        let roll = rng.nextDouble()
        // Select rule ID based on piano rule and roll.
        // AMB-PNO-001: 20% sparse drone, 30% halo shimmer, 25% warm sustain, 25% staggered strings
        // AMB-PNO-002: 40% staggered strings, 30% halo shimmer, 20% warm sustain, 10% sparse drone
        // AMB-PNO-003: 50% warm sustain, 50% halo shimmer
        let chosen: String
        switch pianoRule {
        case "AMB-PNO-001":
            chosen = roll < 0.20 ? "AMB-PADS-007" : roll < 0.50 ? "AMB-PADS-010" : roll < 0.75 ? "AMB-PADS-009" : "AMB-PADS-008"
        case "AMB-PNO-003":
            chosen = roll < 0.50 ? "AMB-PADS-009" : "AMB-PADS-010"
        default:
            chosen = roll < 0.40 ? "AMB-PADS-008" : roll < 0.70 ? "AMB-PADS-010" : roll < 0.90 ? "AMB-PADS-009" : "AMB-PADS-007"
        }
        usedRuleIDs.insert(chosen)
        switch chosen {
        case "AMB-PADS-007": return sparseDroneFullSong(tonalMap: tonalMap, totalBars: totalBars, rng: &rng)
        case "AMB-PADS-008": return staggeredStringsFullSong(tonalMap: tonalMap, totalBars: totalBars, rng: &rng)
        case "AMB-PADS-010": return haloShimmerFullSong(tonalMap: tonalMap, totalBars: totalBars, rng: &rng)
        default:             return warmSustainFullSong(tonalMap: tonalMap, totalBars: totalBars, rng: &rng)
        }
    }

    // AMB-PADS-007: Sparse Drone — paired with Floating Tones (AMB-PNO-001)
    // Root + fifth, 14-21 bar sustain followed by a 4-8 bar silence so the chord
    // "reveals" itself 2-3 times as the piano pauses, rather than sustaining invisibly
    // for the entire song and only becoming audible once.
    private static func sparseDroneFullSong(tonalMap: TonalGovernanceMap, totalBars: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let totalSteps  = totalBars * 16
        let sustainBars = 14 + rng.nextInt(upperBound: 8)   // 14-21 bars of audible chord
        let gapBars     = 4  + rng.nextInt(upperBound: 5)   // 4-8 bars of true silence
        let cycleBars   = sustainBars + gapBars
        let baseVel     = 34 + rng.nextInt(upperBound: 11)
        let drones      = pianoDroneFoundation(tonalMap: tonalMap, low: 36, high: 52)
        guard !drones.isEmpty else { return [] }

        var events: [MIDIEvent] = []
        var step = (1 + rng.nextInt(upperBound: 3)) * 16   // first swell starts bar 1-3
        while step < totalSteps {
            let dur = Swift.min(sustainBars * 16, totalSteps - step)
            guard dur >= 16 else { break }
            for note in drones {
                let v = UInt8(Swift.max(28, Swift.min(48, baseVel + rng.nextInt(upperBound: 7) - 3)))
                events.append(MIDIEvent(stepIndex: step, note: note, velocity: v, durationSteps: dur))
            }
            step += cycleBars * 16
        }
        return events
    }

    // AMB-PADS-008: Staggered Strings — paired with Pensive Melody (AMB-PNO-002)
    // Drone (re-attack 256-384 steps = 16-24 bars) + optional rising string arc at high register.
    private static func staggeredStringsFullSong(tonalMap: TonalGovernanceMap, totalBars: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let reattack   = 256 + rng.nextInt(upperBound: 129)
        let baseVel    = 32 + rng.nextInt(upperBound: 13)
        let drones     = pianoDroneFoundation(tonalMap: tonalMap, low: 36, high: 55)
        guard !drones.isEmpty else { return [] }

        var events: [MIDIEvent] = []
        var step = rng.nextInt(upperBound: 16)
        while step < totalSteps {
            let dur = Swift.min(reattack - 8, totalSteps - step)
            guard dur > 0 else { break }
            for note in drones {
                let v = UInt8(Swift.max(28, Swift.min(50, baseVel + rng.nextInt(upperBound: 7) - 3)))
                events.append(MIDIEvent(stepIndex: step, note: note, velocity: v, durationSteps: dur))
            }
            step += reattack
        }

        // Raein-style rising string arc: appears 2-3 times across the song (always at least twice).
        // Each occurrence uses chord tones at that position so chord shifts are respected.
        for (arcIdx, pct) in [25, 52, 74].enumerated() {
            if arcIdx == 2 && rng.nextDouble() < 0.50 { break }  // 3rd occurrence: 50% chance
            let arcBar = totalBars * pct / 100
            guard arcBar < totalBars - 4 else { continue }
            guard let arcEntry = tonalMap.entry(atBar: arcBar) else { continue }
            let highPool = notesInRegister(pitchClasses: arcEntry.chordWindow.chordTones, low: 68, high: 84)
            guard highPool.count >= 3 else { continue }
            let jitter       = rng.nextInt(upperBound: Swift.max(1, totalBars * 6 / 100)) * 16
            let arcStartStep = arcBar * 16 + jitter
            guard arcStartStep < totalSteps - 32 else { continue }
            let arcNotes = Array(highPool.prefix(4))
            let stagger  = 8 + rng.nextInt(upperBound: 9)
            let arcVel   = UInt8(35 + rng.nextInt(upperBound: 16))
            for (i, note) in arcNotes.enumerated() {
                let ns = arcStartStep + i * stagger
                guard ns < totalSteps else { break }
                let dur = Swift.min(64 + rng.nextInt(upperBound: 33), totalSteps - ns)
                events.append(MIDIEvent(stepIndex: ns, note: note, velocity: arcVel, durationSteps: dur))
            }
        }

        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    // AMB-PADS-009: Warm Sustain — paired with Dramatic Arc (AMB-PNO-003)
    // Drone (re-attack 128-256 steps = 8-16 bars) + optional static pedal tone at 2nd or 4th scale degree.
    private static func warmSustainFullSong(tonalMap: TonalGovernanceMap, totalBars: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        let reattack   = 128 + rng.nextInt(upperBound: 129)
        let baseVel    = 28 + rng.nextInt(upperBound: 13)
        let drones     = pianoDroneFoundation(tonalMap: tonalMap, low: 36, high: 55)
        guard !drones.isEmpty else { return [] }

        var events: [MIDIEvent] = []
        var step = rng.nextInt(upperBound: 16)
        while step < totalSteps {
            let dur = Swift.min(reattack - 8, totalSteps - step)
            guard dur > 0 else { break }
            for note in drones {
                let v = UInt8(Swift.max(22, Swift.min(48, baseVel + rng.nextInt(upperBound: 9) - 4)))
                events.append(MIDIEvent(stepIndex: step, note: note, velocity: v, durationSteps: dur))
            }
            step += reattack
        }

        // Optional pedal tone at 2nd or 4th scale degree (30%)
        if rng.nextDouble() < 0.30, let entry = tonalMap.entry(atBar: 0) {
            let chordPCs  = entry.chordWindow.chordTones
            let scalePCs  = chordPCs.union(entry.chordWindow.scaleTensions)
            let rootPC    = chordPCs.min() ?? 0
            let secondPC  = (rootPC + 2) % 12
            let fourthPC  = (rootPC + 5) % 12
            let pedalPC   = scalePCs.contains(secondPC) ? secondPC : fourthPC
            let pedalPool = notesInRegister(pitchClasses: Set([pedalPC]), low: 48, high: 64)
            if let pedalNote = pedalPool.first {
                let bodyStart = (totalBars / 6) * 16
                let bodyEnd   = Swift.min(totalSteps, (totalBars * 5 / 6) * 16)
                let dur = bodyEnd - bodyStart
                if dur > 32 {
                    let v = UInt8(30 + rng.nextInt(upperBound: 11))
                    events.append(MIDIEvent(stepIndex: bodyStart, note: pedalNote, velocity: v, durationSteps: dur))
                }
            }
        }

        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    // Derives root + perfect-fifth drone notes in the given register from tonal map bar 0.
    private static func pianoDroneFoundation(tonalMap: TonalGovernanceMap, low: Int, high: Int) -> [UInt8] {
        guard let entry = tonalMap.entry(atBar: 0) else { return [] }
        let allNotes = notesInRegister(pitchClasses: entry.chordWindow.chordTones, low: low, high: high)
        guard !allNotes.isEmpty else { return [] }
        let root    = allNotes[0]
        let fifthPC = (Int(root) + 7) % 12
        if entry.chordWindow.chordTones.contains(fifthPC) {
            let fifth = UInt8(Int(root) + 7)
            if fifth <= UInt8(high) { return [root, fifth] }
        }
        let octave = UInt8(Int(root) + 12)
        return octave <= UInt8(high) ? [root, octave] : [root]
    }

    // AMB-PADS-010: Halo Shimmer — high-register overtone floating above the piano.
    // Root (+ fifth if it fits) in octave 5, velocity 16–26, 2–3 long breaths with short gaps.
    private static func haloShimmerFullSong(tonalMap: TonalGovernanceMap, totalBars: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let totalSteps = totalBars * 16
        guard let entry = tonalMap.entry(atBar: 0) else { return [] }

        let allNotes = notesInRegister(pitchClasses: entry.chordWindow.chordTones, low: 72, high: 86)
        guard !allNotes.isEmpty else { return [] }
        let root    = allNotes[0]
        let fifthPC = (Int(root) + 7) % 12
        let fifth   = entry.chordWindow.chordTones.contains(fifthPC) ? UInt8(Int(root) + 7) : nil
        let notes: [UInt8] = (fifth != nil && Int(fifth!) <= 86) ? [root, fifth!] : [root]

        let breathBars = 18 + rng.nextInt(upperBound: 7)   // 18–24 bars per breath
        let gapBars    = 2  + rng.nextInt(upperBound: 3)   // 2–4 bar gap between breaths
        let baseVel    = 18 + rng.nextInt(upperBound: 8)   // 18–25

        var events: [MIDIEvent] = []
        var step = (2 + rng.nextInt(upperBound: 4)) * 16   // first breath starts bar 2–5
        while step < totalSteps {
            let dur = Swift.min(breathBars * 16, totalSteps - step)
            guard dur >= 16 else { break }
            for note in notes {
                let v = UInt8(Swift.max(16, Swift.min(26, baseVel + rng.nextInt(upperBound: 5) - 2)))
                events.append(MIDIEvent(stepIndex: step, note: note, velocity: v, durationSteps: dur))
            }
            step += (breathBars + gapBars) * 16
        }
        return events
    }

    // MARK: - Helpers

    private static func spreadNotesInverted(from notes: [UInt8], count: Int, invOffset: Int) -> [UInt8] {
        guard notes.count >= 2 else { return notes }
        let n     = notes.count
        let start = invOffset % Swift.max(1, n - count + 1)
        return (0..<Swift.min(count, n)).map { i in
            let idx = start + (i * (n - 1 - start)) / Swift.max(1, count - 1)
            return notes[Swift.min(idx, n - 1)]
        }
    }
}
