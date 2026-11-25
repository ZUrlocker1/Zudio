// AmbientPianoShared.swift — Ambient Piano entry point, shared helpers and trimmers, split out of AmbientLeadGenerator.swift
// Copyright (c) 2026 Zack Urlocker

import Foundation

extension AmbientLeadGenerator {

    // MARK: - Ambient Piano Lead (full-song, no loop tiler)

    /// The per-call options of `generateAmbientPianoLead`. Each rule reads only the ones it uses.
    struct PianoParams {
        /// Satin keeps its left hand out of the intro.
        var introEndBar = 0
        /// An Evolve pass: shorter, no fresh opening.
        var isEvolvePass = false
        /// Koln's vamp is redrawn from this per regen; 0 is the original song.
        var arcVariation: UInt64 = 0
        /// Koln records its high-note reach steps here for the log.
        var reachLog: ReachLog? = nil
    }

    static func generateAmbientPianoLead(
        pianoRule: String,
        frame: GlobalMusicalFrame,
        totalBars: Int,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        params: PianoParams = PianoParams()
    ) -> [MIDIEvent] {
        let (introEndBar, isEvolvePass, arcVariation, reachLog) =
            (params.introEndBar, params.isEvolvePass, params.arcVariation, params.reachLog)
        usedRuleIDs.insert(pianoRule)
        let events: [MIDIEvent]
        switch AmbientPianoRule(id: pianoRule) {
        case .buds: events = floatingTonesFullSong(frame: frame, totalBars: totalBars, rng: &rng, usedRuleIDs: &usedRuleIDs, isEvolvePass: isEvolvePass)
        case .koln: events = dramaticArcFullSong(frame: frame, totalBars: totalBars, rng: &rng,
                                                       usedRuleIDs: &usedRuleIDs, isEvolvePass: isEvolvePass,
                                                       arcVariation: arcVariation, reachLog: reachLog)
        case .satin: events = pensiveMelodyFullSong(frame: frame, totalBars: totalBars, rng: &rng, introEndBar: introEndBar, isEvolvePass: isEvolvePass)
        }
        return events.map { capPianoSustain($0) }
    }

    /// Swaps a rule's parent ID for the variant that was drawn (the log tags it under the parent).
    static func logVariant(_ variant: String, of parent: AmbientPianoRule, in ids: inout Set<String>) {
        ids.remove(parent.rawValue); ids.insert(variant)
    }

    /// The longest a piano note is written: one bar. A piano does not sustain much past that, so a
    /// 3-bar low note or closing chord (Soft Landing in the Open Plan, bars 18, 28 and the outro,
    /// Zack 2026-11-24) read in the piano roll as a hold the sound never had. Applied to the rules'
    /// finished notes, so no random draw changes.
    static let pianoMaxSustainSteps = 16
    /// A velocity from any Int formula, clamped to 1-127, so a drifting formula can't trap on the cast.
    static func pnoVel(_ v: Int) -> UInt8 { UInt8(Swift.max(1, Swift.min(127, v))) }
    /// The left hand's bass register (E2 to F#3) in Satin and Koln.
    static let pnoBassLow = 40, pnoBassHigh = 54
    /// Half-step, tritone or major 7th apart (octaves ignored): the rubs the piano rules keep out.
    static func pnoRubs(_ a: Int, _ b: Int) -> Bool { [1, 6, 11].contains(abs(a - b) % 12) }
    /// Below this a major 2nd is a real close second (a 9th over a low root or drone is colour).
    static let pnoCloseSecondCeiling: UInt8 = 55
    /// What the trimmers treat as a clash: a rub, or a close second low down. A 9th over a low root
    /// or drone is colour, and treating it as a clash dropped Satie's suspended-2nd endings.
    static func pnoClash(_ a: UInt8, _ b: UInt8) -> Bool {
        pnoRubs(Int(a), Int(b)) || (abs(Int(a) - Int(b)) == 2 && Swift.min(a, b) < pnoCloseSecondCeiling)
    }

    /// A block-chord stab: `root`, the m3 or M3 above it and the 5th above it, all from `pool`; the
    /// upper notes a little softer.
    static func chordHit(at step: Int, root: UInt8, pool: [UInt8], vel: UInt8, dur: Int) -> [MIDIEvent] {
        var out = [MIDIEvent(stepIndex: step, note: root, velocity: vel, durationSteps: dur)]
        if let third = pool.first(where: { [3, 4].contains(Int($0) - Int(root)) }) {
            out.append(MIDIEvent(stepIndex: step, note: third, velocity: vel > 4 ? vel - 4 : vel, durationSteps: dur))
        }
        if let fifth = pool.first(where: { Int($0) - Int(root) == 7 }) {
            out.append(MIDIEvent(stepIndex: step, note: fifth, velocity: vel > 7 ? vel - 7 : vel, durationSteps: dur))
        }
        return out
    }

    /// The tonic triad's third in the scale: the major 3rd if the scale has it, else the minor 3rd.
    static func pnoThirdPC(of root: Int, in scale: some Collection<Int>) -> Int? {
        let major = (root + 4) % 12, minor = (root + 3) % 12
        return scale.contains(major) ? major : (scale.contains(minor) ? minor : nil)
    }

    static func capPianoSustain(_ e: MIDIEvent) -> MIDIEvent {
        e.durationSteps <= pianoMaxSustainSteps ? e : e.with(durationSteps: pianoMaxSustainSteps)
    }

    // MARK: - Shared helpers

    /// Removes Lead 1 notes that form dissonant intervals with simultaneously sustained Pads notes.
    /// Operates cross-track — `trimDissonances` only sees a single track, so this fills that gap.
    /// `keepGraces`: Koln (AMB-PNO-003) keeps its 16th-note grace notes, which pass too quickly to
    /// clash and are checked against the drone when written (the live wire take).
    static func trimLeadAgainstPads(_ lead: [MIDIEvent], pads: [MIDIEvent], totalSteps: Int,
                                    keepGraces: Bool = false) -> [MIDIEvent] {
        guard !pads.isEmpty else { return lead }
        var result = lead.sorted { $0.stepIndex < $1.stepIndex }
        var dropIndices = Set<Int>()
        for i in 0..<result.count where !dropIndices.contains(i) && !(keepGraces && result[i].durationSteps <= 1) {
            for pad in pads {
                let overlapStart = max(result[i].stepIndex, pad.stepIndex)
                let overlapEnd   = min(result[i].stepIndex + result[i].durationSteps,
                                       pad.stepIndex      + pad.durationSteps)
                guard overlapEnd > overlapStart else { continue }
                guard pnoClash(result[i].note, pad.note) else { continue }
                if pad.stepIndex > result[i].stepIndex {
                    let trimmedDur = pad.stepIndex - result[i].stepIndex - 1
                    if trimmedDur >= 4 {
                        result[i] = MIDIEvent(stepIndex: result[i].stepIndex, note: result[i].note,
                                              velocity: result[i].velocity, durationSteps: trimmedDur)
                    } else { dropIndices.insert(i) }
                } else {
                    dropIndices.insert(i)
                }
                break
            }
        }
        return result.indices.filter { !dropIndices.contains($0) }.map { result[$0] }
    }

    /// Trims or drops notes that form dissonant intervals when sustained simultaneously.
    /// Catches: minor 2nd (1), tritone (6), major 7th (11), bass major 2nd (2 when both < 57).
    static func trimDissonances(_ events: [MIDIEvent], totalSteps: Int) -> [MIDIEvent] {
        // Cap first: the trim should judge notes as they will sound, not as the rule wrote them
        var trimmed = events.filter { $0.stepIndex < totalSteps }.map(capPianoSustain).sorted { $0.stepIndex < $1.stepIndex }
        var dropIndices = Set<Int>()
        for i in 0..<trimmed.count where !dropIndices.contains(i) {
            for j in (i + 1)..<trimmed.count where !dropIndices.contains(j) {
                let b = trimmed[j]
                guard b.stepIndex < trimmed[i].stepIndex + trimmed[i].durationSteps else { break }
                if pnoClash(trimmed[i].note, b.note) {
                    if b.stepIndex == trimmed[i].stepIndex {
                        // Same start step — drop the quieter note
                        dropIndices.insert(trimmed[i].velocity >= b.velocity ? j : i)
                    } else {
                        let trimmedDur = b.stepIndex - trimmed[i].stepIndex - 1
                        if trimmedDur >= 4 {
                            // If the later note is much shorter (bass intruding on a sustained
                            // melody), drop the intruder rather than truncating the melody.
                            if b.durationSteps * 2 < trimmed[i].durationSteps {
                                dropIndices.insert(j)
                            } else {
                                trimmed[i] = MIDIEvent(stepIndex: trimmed[i].stepIndex, note: trimmed[i].note,
                                                       velocity: trimmed[i].velocity, durationSteps: trimmedDur)
                            }
                        } else if b.durationSteps < trimmed[i].durationSteps {
                            dropIndices.insert(j)
                        } else if trimmedDur >= 1 {
                            trimmed[i] = MIDIEvent(stepIndex: trimmed[i].stepIndex, note: trimmed[i].note,
                                                   velocity: trimmed[i].velocity, durationSteps: trimmedDur)
                        } else {
                            dropIndices.insert(trimmed[i].velocity >= b.velocity ? j : i)
                        }
                    }
                }
            }
        }
        return trimmed.indices.filter { !dropIndices.contains($0) }.map { trimmed[$0] }
    }
}

extension MIDIEvent {
    /// A copy with the given fields changed (the step stays; an event is moved by rebuilding it).
    func with(note: UInt8? = nil, velocity: UInt8? = nil, durationSteps: Int? = nil) -> MIDIEvent {
        MIDIEvent(stepIndex: stepIndex, note: note ?? self.note, velocity: velocity ?? self.velocity,
                  durationSteps: durationSteps ?? self.durationSteps)
    }
}

extension Array {
    /// Fisher-Yates with the song's own RNG (SeededRNG isn't a RandomNumberGenerator).
    func seededShuffle(_ rng: inout SeededRNG) -> [Element] {
        var a = self
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) { a.swapAt(i, rng.nextInt(upperBound: i + 1)) }
        return a
    }
}
