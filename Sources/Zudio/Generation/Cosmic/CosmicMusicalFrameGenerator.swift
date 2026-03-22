// KosmicMusicalFrameGenerator.swift — Kosmic generation step 1
// Produces a GlobalMusicalFrame tuned for Berlin School / Kosmic style.
// Reuses GlobalMusicalFrame (same struct as Motorik) with Kosmic distributions.

import Foundation

struct KosmicMusicalFrameGenerator {

    // Shadow root semitone: tritone partner (KOS-RULE-14)
    // Not stored in frame — derived at generation time and passed to generators that need it.
    static func shadowRoot(frame: GlobalMusicalFrame) -> Int {
        (frame.keySemitoneValue + 6) % 12
    }

    static func generate(
        rng: inout SeededRNG,
        keyOverride: String? = nil,
        tempoOverride: Int? = nil,
        moodOverride: Mood? = nil,
        testMode: Bool = false
    ) -> (frame: GlobalMusicalFrame, percussionStyle: PercussionStyle, kosmicProgFamily: KosmicProgressionFamily) {

        let key    = keyOverride   ?? pickKey(rng: &rng)
        let tempo  = tempoOverride ?? pickTempo(rng: &rng)
        let mood   = moodOverride  ?? pickMood(rng: &rng)
        let mode   = pickMode(rng: &rng)
        let family = pickProgressionFamilyMotarik(rng: &rng)  // standard ProgressionFamily for StructureGenerator
        let total  = pickTotalBars(tempo: tempo, rng: &rng, testMode: testMode)
        let percStyle = pickPercussionStyle(tempo: tempo, rng: &rng)
        let kosmicFamily = pickKosmicProgressionFamily(rng: &rng)

        let frame = GlobalMusicalFrame(
            key: key,
            mode: mode,
            tempo: tempo,
            mood: mood,
            progressionFamily: family,
            totalBars: total
        )
        return (frame, percStyle, kosmicFamily)
    }

    // MARK: - Private helpers

    /// Kosmic key weights — minor keys heavily weighted (KOS-RULE-02 confirms minor preference)
    private static func pickKey(rng: inout SeededRNG) -> String {
        // Am 20%, Em 18%, Dm 15%, Gm 12%, Cm 10%, Fm 8%, Bm 7%, others 10%
        // We pick the root and let mode determine minor/major flavour
        let keys:    [String] = ["A",  "E",  "D",  "G",  "C",  "F",  "B",  "F#", "Bb", "Eb", "Ab", "C#"]
        let weights: [Double] = [0.20, 0.18, 0.15, 0.12, 0.10, 0.08, 0.07, 0.02, 0.02, 0.02, 0.02, 0.02]
        return keys[rng.weightedPick(weights)]
    }

    /// Kosmic tempo: bimodal distribution per KOS-RULE-20
    /// Mode A (70%): triangular min=115, peak=120, max=126 — driving Kosmic
    /// Mode B (30%): triangular min=108, peak=113, max=118 — contemplative Kosmic
    /// Floor raised from 88 to 108: sub-108 BPM makes the 16th-note grid feel sluggish.
    /// Reference artists (TD Phaedra/Rubycon, Craven Faults groove tracks) bottom out ~108.
    private static func pickTempo(rng: inout SeededRNG) -> Int {
        let useDriverMode = rng.nextDouble() < 0.70
        let minT: Double  = useDriverMode ? 115.0 : 108.0
        let peakT: Double = useDriverMode ? 120.0 : 113.0
        let maxT: Double  = useDriverMode ? 126.0 : 118.0
        let r = rng.nextDouble()
        let fc = (peakT - minT) / (maxT - minT)
        let raw: Double
        if r < fc {
            raw = minT + Foundation.sqrt(r * (maxT - minT) * (peakT - minT))
        } else {
            raw = maxT - Foundation.sqrt((1 - r) * (maxT - minT) * (maxT - peakT))
        }
        return Swift.max(20, Swift.min(200, Int(raw.rounded())))
    }

    private static func pickMood(rng: inout SeededRNG) -> Mood {
        // Kosmic mood weights — Dream/Deep dominate
        let weights: [Double] = [0.35, 0.30, 0.20, 0.15]
        let moods: [Mood] = [.Dream, .Deep, .Free, .Bright]
        return moods[rng.weightedPick(weights)]
    }

    /// Kosmic modes — Dorian 40%, Aeolian 30%, Phrygian 15%, Mixolydian 10%, Ionian 5%
    /// (KOS-RULE-02: Dorian confirmed as primary from Mister Mosca analysis)
    private static func pickMode(rng: inout SeededRNG) -> Mode {
        let modes:   [Mode]   = [.Dorian, .Aeolian, .Aeolian, .Mixolydian, .Ionian]
        let weights: [Double] = [0.40,    0.30,     0.15,     0.10,        0.05]
        // Phrygian not in Mode enum — use Aeolian as nearest dark mode
        return modes[rng.weightedPick(weights)]
    }

    /// Motorik-compatible ProgressionFamily used for StructureGenerator chord plan
    private static func pickProgressionFamilyMotarik(rng: inout SeededRNG) -> ProgressionFamily {
        // For Kosmic, we favour static_tonic and two_chord_I_bVII heavily
        let families: [ProgressionFamily] = [
            .static_tonic, .two_chord_I_bVII, .minor_loop_i_VII,
            .minor_loop_i_VI, .modal_cadence_bVI_bVII_I
        ]
        let weights: [Double] = [0.35, 0.30, 0.15, 0.12, 0.08]
        return families[rng.weightedPick(weights)]
    }

    /// Kosmic-specific progression family (for KosmicStructureGenerator)
    private static func pickKosmicProgressionFamily(rng: inout SeededRNG) -> KosmicProgressionFamily {
        let families: [KosmicProgressionFamily] = [
            .static_drone, .two_chord_pendulum, .modal_drift, .suspended_resolution, .quartal_stack
        ]
        let weights: [Double] = [0.30, 0.25, 0.20, 0.15, 0.10]
        return families[rng.weightedPick(weights)]
    }

    /// PercussionStyle weights (tempo >= 100):
    ///   absent 22%, sparse 18%, minimal 13%,
    ///   electricBuddhaGroove 27%, electricBuddhaPulse 10%, electricBuddhaRestrained 10%
    /// Below 100 BPM: Electric Buddha patterns redistributed to absent/sparse/restrained.
    private static func pickPercussionStyle(tempo: Int, rng: inout SeededRNG) -> PercussionStyle {
        if tempo >= 100 {
            let styles:  [PercussionStyle] = [.absent, .sparse, .minimal, .motorikGrid, .electricBuddhaPulse, .electricBuddhaRestrained]
            let weights: [Double]          = [0.22,    0.18,    0.13,     0.27,          0.10,                  0.10]
            return styles[rng.weightedPick(weights)]
        } else {
            // Very slow tempo: heavier toward absent/sparse, restrained suits slow tempos well
            let styles:  [PercussionStyle] = [.absent, .sparse, .minimal, .electricBuddhaRestrained]
            let weights: [Double]          = [0.38,    0.27,    0.20,     0.15]
            return styles[rng.weightedPick(weights)]
        }
    }

    /// Song length: triangular min=225s (3:45), peak=250s, max=270s (4:30) — slightly longer than Motorik
    private static func pickTotalBars(tempo: Int, rng: inout SeededRNG, testMode: Bool = false) -> Int {
        let minS: Double  = testMode ? 120.0 : 225.0
        let peakS: Double = testMode ? 150.0 : 250.0
        let maxS: Double  = testMode ? 170.0 : 270.0
        let r = rng.nextDouble()
        let fc = (peakS - minS) / (maxS - minS)
        let secs: Double
        if r < fc {
            secs = minS + Foundation.sqrt(r * (maxS - minS) * (peakS - minS))
        } else {
            secs = maxS - Foundation.sqrt((1 - r) * (maxS - minS) * (maxS - peakS))
        }
        let secondsPerBar = 60.0 / Double(tempo) * 4.0
        let rawBars = Int((secs / secondsPerBar).rounded())
        return Swift.max(8, (rawBars / 4) * 4)
    }
}
