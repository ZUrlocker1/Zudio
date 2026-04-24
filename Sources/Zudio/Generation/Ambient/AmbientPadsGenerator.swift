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
