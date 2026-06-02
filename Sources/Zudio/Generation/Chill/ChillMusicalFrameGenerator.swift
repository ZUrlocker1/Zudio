// ChillMusicalFrameGenerator.swift — Chill generation step 1
// Copyright (c) 2026 Zack Urlocker
// Produces a GlobalMusicalFrame tuned for nu-jazz / acid jazz / chill-out style.
// Tempo: Deep/Dream 72–92 BPM (peak 83), Bright/Free 88–110 BPM (peak 96). Blues: always 85–92 BPM (peak 88).
// Four moods: Deep 35%, Dream 30%, Free 20%, Bright 15%.
// Four modes: Dorian 40%, Aeolian 25%, Mixolydian 20%, Ionian 15%.

import Foundation

struct ChillMusicalFrameGenerator {

    static func generate(
        rng: inout SeededRNG,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        forceBeatStyle: ChillBeatStyle? = nil,
        forceBluesVariation: Bool = false
    ) -> (frame: GlobalMusicalFrame,
          chillProgFamily: ChillProgressionFamily,
          chillLeadInstrument: ChillLeadInstrument,
          chillBeatStyle: ChillBeatStyle,
          chillSwingFeel: Bool,
          chillBluesVariation: Bool) {

        let mood = moodOverride ?? pickMood(rng: &rng)
        let key  = keyOverride  ?? pickKey(rng: &rng)

        // Blues Chill activation: 20% of Chill songs.
        let bluesVariation = forceBluesVariation || rng.nextDouble() < 0.20

        // Blues forces Dorian (Im7 / IVm7 / V7 are diatonic to Dorian only).
        let mode = bluesVariation ? Mode.Dorian : pickMode(rng: &rng)

        let progFamily = pickProgressionFamily(rng: &rng)

        // Blues uses a dedicated instrument pool (all blues-appropriate horns/reeds).
        let leadInst = bluesVariation
            ? pickLeadInstrumentBlues(rng: &rng)
            : pickLeadInstrument(mood: mood, rng: &rng)

        // Blues excludes stGermain and hipHopJazz beat styles.
        // forceBeatStyle from best-first-song/load path takes priority in all cases.
        let beatStyle = forceBeatStyle ?? (bluesVariation
            ? pickBeatStyleBlues(rng: &rng)
            : pickBeatStyle(rng: &rng))

        let swingFeel = false  // swing not yet implemented (requires sub-step timing)

        // Tempo picked after beat style so stGermain can bias toward its faster range.
        // Blues range: 85–92 BPM. Re-roll once if the initial pick lands outside that window.
        var tempo = tempoOverride ?? pickTempo(mood: mood, rng: &rng, beatStyle: beatStyle)
        if bluesVariation {
            tempo = Swift.max(85, Swift.min(tempo, 92))
        } else {
            tempo = Swift.max(72, Swift.min(tempo, 124))
        }

        // Blues: cap total bars so grooveTotal stays within 4–5 complete 16-bar forms.
        // 5 forms × 16 + max intro (4) + outro (2) = 86. Beyond that the form repeats too many times.
        var total = pickTotalBars(tempo: tempo, rng: &rng)
        if bluesVariation { total = Swift.min(total, 86) }

        let frame = GlobalMusicalFrame(
            key: key, mode: mode, tempo: tempo, mood: mood,
            progressionFamily: .static_tonic, totalBars: total
        )
        return (frame, progFamily, leadInst, beatStyle, swingFeel, bluesVariation)
    }

    // MARK: - Private helpers

    private static func pickMood(rng: inout SeededRNG) -> Mood {
        // Deep 35%, Dream 30%, Free 20%, Bright 15%
        let moods:   [Mood]   = [.Deep, .Dream, .Free, .Bright]
        let weights: [Double] = [0.35,  0.30,   0.20,  0.15]
        return moods[rng.weightedPick(weights)]
    }

    private static func pickKey(rng: inout SeededRNG) -> String {
        // Jazz-friendly keys slightly boosted; D and G top the list
        let keys:    [String] = ["D",  "G",  "C",  "F",  "A",  "Bb", "Eb", "Ab", "E",  "B",  "F#", "C#"]
        let weights: [Double] = [0.15, 0.12, 0.12, 0.10, 0.10, 0.08, 0.07, 0.06, 0.06, 0.05, 0.05, 0.04]
        return keys[rng.weightedPick(weights)]
    }

    private static func pickTempo(mood: Mood, rng: inout SeededRNG, beatStyle: ChillBeatStyle? = nil) -> Int {
        // St Germain four-on-the-floor groove needs the higher end of the tempo range to drive
        if beatStyle == .stGermain {
            return triangularInt(min: 108, peak: 116, max: 124, rng: &rng)
        }
        switch mood {
        case .Deep, .Dream:
            // 72–92 BPM triangular (peak 83) — trip-hop / Moby range
            return triangularInt(min: 72, peak: 83, max: 92, rng: &rng)
        case .Free, .Bright:
            // 88–110 BPM triangular (peak 96) — nu-jazz / St Germain range
            return triangularInt(min: 88, peak: 96, max: 110, rng: &rng)
        }
    }

    private static func pickMode(rng: inout SeededRNG) -> Mode {
        // Dorian 40%, Aeolian 25%, Mixolydian 20%, Ionian 15%
        let modes:   [Mode]   = [.Dorian, .Aeolian, .Mixolydian, .Ionian]
        let weights: [Double] = [0.40,    0.25,     0.20,        0.15]
        return modes[rng.weightedPick(weights)]
    }

    private static func pickTotalBars(tempo: Int, rng: inout SeededRNG) -> Int {
        let minS: Double  = 180.0
        let peakS: Double = 240.0
        let maxS: Double  = 315.0
        let secs = Double(triangularInt(min: Int(minS), peak: Int(peakS), max: Int(maxS), rng: &rng))
        let secondsPerBar = 60.0 / Double(tempo) * 4.0
        let rawBars = Int((secs / secondsPerBar).rounded())
        return Swift.max(68, Swift.min(116, (rawBars / 4) * 4))
    }

    private static func pickProgressionFamily(rng: inout SeededRNG) -> ChillProgressionFamily {
        // static_groove 35%, two_chord_pendulum 30%, minor_blues 20%, modal_drift 15%
        let families: [ChillProgressionFamily] = [.static_groove, .two_chord_pendulum, .minor_blues, .modal_drift]
        let weights:  [Double]                 = [0.35,           0.30,                0.20,          0.15]
        return families[rng.weightedPick(weights)]
    }

    private static func pickLeadInstrument(mood: Mood, rng: inout SeededRNG) -> ChillLeadInstrument {
        // Lead 1 pool: all five horn/reed instruments equally weighted.
        // Soprano sax, vibraphone, trombone, flute are Lead 2 only.
        let insts: [ChillLeadInstrument] = [.mutedTrumpet, .saxophone, .trumpet, .tenorSax, .clarinet]
        return insts[rng.nextInt(upperBound: insts.count)]
    }

    private static func pickBeatStyleBlues(rng: inout SeededRNG) -> ChillBeatStyle {
        // Blues pool: stGermain excluded (four-on-the-floor doesn't suit blues phrasing).
        // All remaining styles equally weighted.
        let styles: [ChillBeatStyle] = [.brushKit, .neoSoul, .electronic, .hipHopJazz]
        return styles[rng.nextInt(upperBound: styles.count)]
    }

    private static func pickLeadInstrumentBlues(rng: inout SeededRNG) -> ChillLeadInstrument {
        // Blues pool: same five horn/reed instruments, equally weighted.
        let insts: [ChillLeadInstrument] = [.tenorSax, .saxophone, .clarinet, .mutedTrumpet, .trumpet]
        return insts[rng.nextInt(upperBound: insts.count)]
    }

    private static func pickBeatStyle(rng: inout SeededRNG) -> ChillBeatStyle {
        // All five beat styles equally weighted — no mood bias.
        let styles: [ChillBeatStyle] = [.electronic, .neoSoul, .brushKit, .stGermain, .hipHopJazz]
        return styles[rng.nextInt(upperBound: styles.count)]
    }

    // MARK: - Triangular distribution

    static func triangularInt(min: Int, peak: Int, max: Int, rng: inout SeededRNG) -> Int {
        let minD = Double(min), peakD = Double(peak), maxD = Double(max)
        let r  = rng.nextDouble()
        let fc = (peakD - minD) / (maxD - minD)
        let raw: Double
        if r < fc {
            raw = minD + Foundation.sqrt(r * (maxD - minD) * (peakD - minD))
        } else {
            raw = maxD - Foundation.sqrt((1 - r) * (maxD - minD) * (maxD - peakD))
        }
        return Swift.max(min, Swift.min(max, Int(raw.rounded())))
    }
}
