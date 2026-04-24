// AmbientTextureGenerator.swift — Ambient texture generation
// Copyright (c) 2026 Zack Urlocker
// AMB-TEXT-004 (40%): silent
// AMB-TEXT-001 (30%): orbital shimmer — sparse mid-register notes, long hold, velocity 18–32
// AMB-TEXT-002 (30%): ghost tone — 2–3 long-held notes filling each slot, velocity 22–38, register 48–79
// Generates a short loop; AmbientLoopTiler tiles to full song length.

import Foundation

struct AmbientTextureGenerator {

    static func generate(
        frame: GlobalMusicalFrame,
        tonalMap: TonalGovernanceMap,
        loopBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceNonSilent: Bool = false
    ) -> [MIDIEvent] {
        let roll = rng.nextDouble()
        if !forceNonSilent && roll < 0.40 { usedRuleIDs.insert("AMB-TEXT-004"); return [] }

        let bounds    = kRegisterBounds[kTrackTexture]!  // low:36, high:96
        let loopSteps = loopBars * 16
        let scalePCs  = frame.scalePCs
        let chordPCs  = tonalMap.entry(atBar: 0)?.chordWindow.chordTones ?? scalePCs

        if roll < 0.70 {
            usedRuleIDs.insert("AMB-TEXT-001")
            return orbitalShimmer(scalePCs: scalePCs, loopSteps: loopSteps, rng: &rng)
        }
        usedRuleIDs.insert("AMB-TEXT-002")
        return ghostTone(chordPCs: chordPCs, bounds: bounds, loopSteps: loopSteps, rng: &rng)
    }

    // MARK: - Rules

    /// Slowly cycling mid-register notes — sparse, long hold, velocity 18–32.
    private static func orbitalShimmer(scalePCs: Set<Int>,
                                        loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let notes = notesInRegister(pitchClasses: scalePCs, low: 55, high: 75)
        guard !notes.isEmpty else { return [] }
        var events: [MIDIEvent] = []
        var step = rng.nextInt(upperBound: 16)
        while step < loopSteps {
            if rng.nextDouble() < 0.30 {
                let note = notes[rng.nextInt(upperBound: notes.count)]
                let vel  = UInt8(18 + rng.nextInt(upperBound: 15))  // 18–32
                let dur  = Swift.min(20 + rng.nextInt(upperBound: 21), loopSteps - step)  // 20–40
                if dur >= 16 {
                    events.append(MIDIEvent(stepIndex: step, note: note, velocity: vel, durationSteps: dur))
                }
            }
            step += 20 + rng.nextInt(upperBound: 13)  // 20–32 steps between opportunities
        }
        return events
    }

    /// Long-held tones — 2–3 per loop, nearly filling each slot, velocity 22–38.
    /// Uses mid register (48–79) to avoid extreme lows/highs on strings and choir patches.
    /// Each note is guaranteed to differ from the previous one.
    private static func ghostTone(chordPCs: Set<Int>, bounds: RegisterBounds,
                                   loopSteps: Int, rng: inout SeededRNG) -> [MIDIEvent] {
        let pool = notesInRegister(pitchClasses: chordPCs, low: 48, high: 79)
        guard !pool.isEmpty else { return [] }
        var events: [MIDIEvent] = []
        let count   = 2 + rng.nextInt(upperBound: 2)   // 2–3, always at least two distinct pitches
        let slot    = Swift.max(16, loopSteps / count)
        var lastIdx = -1
        for i in 0..<count {
            let jitter = rng.nextInt(upperBound: Swift.max(1, slot / 4))
            let start  = slot * i + jitter
            if start >= loopSteps { break }
            let dur = Swift.min(slot - 4, loopSteps - start)   // fills nearly the whole slot
            if dur >= 8 {
                var idx = rng.nextInt(upperBound: pool.count)
                if pool.count >= 2 && idx == lastIdx {
                    idx = (idx + 1 + rng.nextInt(upperBound: pool.count - 1)) % pool.count
                }
                lastIdx = idx
                let vel  = UInt8(22 + rng.nextInt(upperBound: 17))  // 22–38
                events.append(MIDIEvent(stepIndex: start, note: pool[idx], velocity: vel, durationSteps: dur))
            }
        }
        return events
    }

}
