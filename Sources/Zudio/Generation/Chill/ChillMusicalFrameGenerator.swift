// ChillMusicalFrameGenerator.swift — Chill generation step 1
// Copyright (c) 2026 Zack Urlocker
// Produces a GlobalMusicalFrame tuned for nu-jazz / acid jazz / chill-out style.
// Tempo: Deep/Dream 72–92 BPM (peak 83), Bright/Free 88–110 BPM (peak 96). Blues: always 85–92 BPM (peak 88).
// Soho: 84–128 BPM (peak ~100), independent of groove.
// Four moods: Deep 35%, Dream 30%, Free 20%, Bright 15%.
// Four modes: Dorian 40%, Aeolian 25%, Mixolydian 20%, Ionian 15%.

import Foundation

struct ChillMusicalFrameGenerator {

    /// Share of NON-Blues Chill songs that become Chill Soho. Blues takes 20% of Chill on the
    /// main stream, so Soho's overall share is 0.80 x this.
    ///
    /// The mix is **30% Soho, 20% Blues, 50% base Chill** (Zack, 2026-10-18; 60/20/20 on
    /// 2026-10-16, 70/15/15 before that), which makes this 30/80. Changing it changes which existing Chill seeds are
    /// Soho, but never their main-stream draws. See docs/chill-soho-plan.md.
    static let sohoShareOfNonBlues: Double = 30.0 / 80.0

    static func generate(
        rng: inout SeededRNG,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        forceBeatStyle: ChillBeatStyle? = nil,
        forceBluesVariation: Bool = false,
        sohoRoll: Double = 1.0,
        forceSohoVariation: Bool = false
    ) -> (frame: GlobalMusicalFrame,
          chillProgFamily: ChillProgressionFamily,
          chillLeadInstrument: ChillLeadInstrument,
          chillBeatStyle: ChillBeatStyle,
          chillSwingFeel: Bool,
          chillBluesVariation: Bool,
          chillSohoVariation: Bool) {

        let mood = moodOverride ?? pickMood(rng: &rng)
        let key  = keyOverride  ?? pickKey(rng: &rng)

        // Blues Chill activation: 20% of Chill songs.
        // The roll is always drawn, forced or not. `force || rng.nextDouble()` short-circuited, so a
        // forced .zudio reload of a Blues song made one fewer main-stream draw than the original
        // and every later draw (lead, beat, tempo, length) shifted. Generation never forces Blues,
        // so drawing unconditionally changes no newly generated song.
        let bluesRoll = rng.nextDouble()
        let bluesVariation = forceBluesVariation || bluesRoll < 0.20

        // Chill Soho activation. `sohoRoll` comes from a DERIVED stream in the caller and is
        // never drawn from `rng`, so base Chill and Blues make exactly the same main-stream draws
        // as they did before Soho existed. Blues keeps precedence: 20% Blues, then 30/80 of the
        // remaining 80% = 30% Soho overall, leaving 50% base Chill.
        // The default of 1.0 means a caller that does not pass a roll never gets Soho.
        let sohoVariation = !bluesVariation && (forceSohoVariation || sohoRoll < sohoShareOfNonBlues)

        // Blues forces Dorian (Im7 / IVm7 / V7 are diatonic to Dorian only).
        let mode = bluesVariation ? Mode.Dorian : pickMode(rng: &rng)

        let progFamily = pickProgressionFamily(rng: &rng)

        // Blues uses a dedicated instrument pool (all blues-appropriate horns/reeds), and Soho
        // weights its own toward what the corpus actually plays.
        let leadInst = bluesVariation
            ? pickLeadInstrumentBlues(rng: &rng)
            : sohoVariation ? pickLeadInstrumentSoho(rng: &rng)
                            : pickLeadInstrument(rng: &rng)

        // Blues excludes stGermain and hipHopJazz beat styles.
        // forceBeatStyle from best-first-song/load path takes priority in all cases.
        let beatStyle = forceBeatStyle ?? (bluesVariation
            ? pickBeatStyleBlues(rng: &rng)
            : sohoVariation
                ? pickBeatStyleSoho(rng: &rng)
                : pickBeatStyle(rng: &rng))

        let swingFeel = false  // swing not yet implemented (requires sub-step timing)

        // Tempo picked after beat style so stGermain can bias toward its faster range.
        // Blues range: 85–92 BPM. Re-roll once if the initial pick lands outside that window.
        // Soho: one band for the whole substyle, independent of the groove — 84–128, peak ~100.
        // Measured bimodal in the corpus (80–106 and 121–134); restraint comes from density and
        // touch, not BPM, so the slow band alone would exclude three of the strongest references.
        var tempo = tempoOverride ?? (sohoVariation
            ? triangularInt(min: 84, peak: 100, max: 128, rng: &rng)
            : pickTempo(mood: mood, rng: &rng, beatStyle: beatStyle))
        if bluesVariation {
            tempo = Swift.max(85, Swift.min(tempo, 92))
        } else if sohoVariation {
            tempo = Swift.max(84, Swift.min(tempo, 128))
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
        return (frame, progFamily, leadInst, beatStyle, swingFeel, bluesVariation, sohoVariation)
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

    /// Lead 1 pool: all five horn/reed instruments equally weighted, independent of mood.
    /// Soprano sax, vibraphone, trombone, flute are Lead 2 only.
    /// (2026: this used to take an unused `mood` parameter — chill-plan.md's CHILL-RULE-09 once
    /// specified mood-dependent instrument choice, e.g. muted trumpet/sax for Deep/Dream, but that
    /// was never wired up; the parameter was dead code. Removed rather than implemented, to match
    /// the flat, mood-independent selection every other Chill track generator already uses.)
    /// Base Chill's lead, drawn evenly. **Muted Trumpet is base Chill's alone** — Soho and Blues
    /// both dropped it. Clarinet moved out to Blues (Zack, 2026-10-13).
    /// Mirrored by `instrumentPoolNames(kTrackLead1, .chill)`; keep the two in step.
    private static func pickLeadInstrument(rng: inout SeededRNG) -> ChillLeadInstrument {
        let insts: [ChillLeadInstrument] = [.mutedTrumpet, .saxophone, .trumpet, .tenorSax]
        return insts[rng.nextInt(upperBound: insts.count)]
    }

    /// Chill Soho's lead. Across the 14 corpus files Tenor Sax appears in 6, Alto Sax in 4 and
    /// **Flute in 4** — the flute standing in for the singer, and a voice neither other Chill
    /// form has. Levelled to 25/25/24 at Zack's call (2026-10-15) from 30/22/22, so the three
    /// main voices share the lead almost equally rather than the tenor leading. Muted Trumpet, Clarinet and then Trumpet
    /// were dropped to keep the substyle distinct (Zack, 2026-10-13) — trumpet is in only 1 of
    /// the 14 files, and for 154 notes. **Soprano Sax and Recorder are on trial** in its place:
    /// Recorder is in 1 file for 313 notes, Soprano Sax in none, so this is the first Soho pool
    /// chosen partly against the measurement rather than from it.
    /// `AppState.instrumentPickPoolStatic` reads this table for a manual randomise, so the two
    /// cannot drift: it once kept the old 30/22/22 after this was levelled (found 2026-10-16).
    static let sohoLeadWeights: [(instrument: ChillLeadInstrument, weight: Double)] = [
        (.tenorSax, 0.25), (.saxophone, 0.25), (.flute, 0.24), (.sopranoSax, 0.13), (.recorder, 0.13),
    ]

    private static func pickLeadInstrumentSoho(rng: inout SeededRNG) -> ChillLeadInstrument {
        sohoLeadWeights[rng.weightedPick(sohoLeadWeights.map(\.weight))].instrument
    }

    /// Chill Soho: Latin 55% / Soul 45%, matching the reference set. The drum, bass and rhythm
    /// generators each pick their pool from this one value.
    private static func pickBeatStyleSoho(rng: inout SeededRNG) -> ChillBeatStyle {
        rng.nextDouble() < 0.55 ? .sohoLatin : .sohoSoul
    }

    private static func pickBeatStyleBlues(rng: inout SeededRNG) -> ChillBeatStyle {
        // Blues pool: stGermain excluded (four-on-the-floor doesn't suit blues phrasing).
        // All remaining styles equally weighted.
        let styles: [ChillBeatStyle] = [.brushKit, .neoSoul, .electronic, .hipHopJazz]
        return styles[rng.nextInt(upperBound: styles.count)]
    }

    /// Blues's lead, drawn evenly. **Clarinet is Blues's alone** — its reediest voice, and the
    /// one base Chill and Soho both gave up. Muted Trumpet dropped out here (Zack, 2026-10-13).
    /// Mirrored by the `isChillBlues` branch of `instrumentPoolNames`; keep the two in step.
    private static func pickLeadInstrumentBlues(rng: inout SeededRNG) -> ChillLeadInstrument {
        let insts: [ChillLeadInstrument] = [.tenorSax, .saxophone, .trumpet, .clarinet]
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
