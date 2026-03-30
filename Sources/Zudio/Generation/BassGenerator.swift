// BassGenerator.swift — generation step 5
//
// Rule catalog:
//   BAS-001: Root Anchor — root beat 1 (long), chord tone beat 3, clean and locked
//   BAS-002: Motorik Drive — 4 quarter notes, staccato, velocity accent on 1+3
//   BAS-003: Crawling Walk — 2-bar root/fifth/approach note pattern
//   BAS-004: Hallogallo Lock — root beat 1 (long), fifth beat 3, locked to kick 1+3 pattern
//   BAS-005: McCartney Drive — 8th-note locked groove derived from SLS verse;
//            bar 1: root-root-m3↓-m3↓-5↓-5↓-m3↓-5↓ descent, bar 2: breathe + pickup
//   BAS-006: LA Woman Sustain — root holds most of bar, chromatic neighbor shimmer at end
//   BAS-007: Hook Ascent — Peter Hook / Joy Division "She's Lost Control";
//            high-register melodic riff: bar 1 hammers the M3 in 8th notes then descends,
//            bar 2 falls to root with m6 color and chromatic pickup
//   BAS-008: Moroder Pulse — Giorgio Moroder "I Feel Love" sequenced staccato 8th notes;
//            root-root-fifth-fifth-b7-b7-root-root; mechanical, relentless, pure chord tones
//   BAS-009: Vitamin Hook — Holger Czukay / CAN "Vitamin C" ascending arpeggio;
//            bar 1 climbs root→fifth→octave with chromatic pass, bar 2 descends with long root breathe
//   BAS-010: Quo Arc — Status Quo "Down Down" 2-bar boogie-woogie arc;
//            bar 1 ascends in paired 8th notes: 1-1-3-3-5-5-6-b7;
//            bar 2 descends: b7-6-5-3-1-1-1-1 back to root.
//            Uses the boogie-woogie scale (1-3-5-6-b7) — b7 always present regardless of chord type.
//   BAS-011: Quo Drive — Status Quo "Caroline" 1-bar compressed boogie arc;
//            full up-and-back arc in one bar: 1-3-5-6-b7-6-5-3.
//            Root-push variant (Paper Plane): 1-1-3-5-6-b7-6-5 — applied on even bars.
//   BAS-012: Moroder Chase — Giorgio Moroder "Chase" (Midnight Express, 1978) delay-echo 16th-note ostinato;
//            primary 8th notes cycle root–mode3rd–fifth, with a mirrored quieter echo on each odd 16th step
//            simulating the AMS digital delay Moroder used to double his Minimoog 8th notes into 16ths.
//   BAS-013: Kraftwerk Roboter — "The Robots" (1978) 3-note octave-jump cell;
//            root(low, 8th)–root+octave(high, 8th)–mode3rd(quarter), repeated twice per bar.
//            The instant synthesizer octave jump is the signature; creates a mechanical robot feel.
//            Works in both Motorik and Kosmic ranges.
//   BAS-014: McCartney PBW — "Paperback Writer" (1966) Mixolydian riff;
//            root–fifth–root–b7–fifth–root–mode3rd–root in 8 8th-notes.
//            The flat-seventh gives a blues/Mixolydian edge. b7 falls back to fifth in pure major contexts.
//
// All patterns hit beat 1 (step 0) as the primary anchor, matching the kick drum.
// Syncopation is deliberately minimized — Motorik bass is locked and pulse-forward.

struct BassGenerator {
    static func generate(
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        rng: inout SeededRNG,
        usedRuleIDs: inout Set<String>,
        forceRuleID: String? = nil
    ) -> [MIDIEvent] {
        let rules:   [String] = ["MOT-BASS-001","MOT-BASS-002","MOT-BASS-003","MOT-BASS-004",
                                  "MOT-BASS-005","MOT-BASS-006","MOT-BASS-007","MOT-BASS-008","MOT-BASS-009",
                                  "MOT-BASS-010","MOT-BASS-011",
                                  "MOT-BASS-012","MOT-BASS-013","MOT-BASS-014","MOT-BASS-015"]
        let weights: [Double] = [0.07,     0.11,     0.04,     0.04,
                                  0.09,     0.05,     0.08,     0.10,     0.06,
                                  0.03,     0.03,
                                  0.07,     0.04,     0.08,     0.11]
        let ruleID = forceRuleID ?? rules[rng.weightedPick(weights)]
        usedRuleIDs.insert(ruleID)

        // BAS-005: pre-roll per-4-bar-group flags — ~1/3 chance the phrase is all-drive
        // (bass sits on the descent groove for 4 straight bars instead of alternating breathe bars).
        var mccartney4BarDrive: [Bool] = []
        if ruleID == "MOT-BASS-005" {
            let groups = frame.totalBars / 4 + 1
            mccartney4BarDrive = (0..<groups).map { _ in rng.nextDouble() < 0.33 }
        }

        // Precompute variation windows for simple 1–2 note rules (BAS-001/002/004).
        // Fires for: every B section; every other A section that starts at or after bar 48
        // (alternating on/off so the variation doesn't take over the whole second half).
        // This keeps the bass interesting at section boundaries without being relentless.
        let simpleRules: Set<String> = ["MOT-BASS-001", "MOT-BASS-002", "MOT-BASS-004",
                                         "MOT-BASS-013", "MOT-BASS-014", "MOT-BASS-015"]
        var variationBars = Set<Int>()
        if simpleRules.contains(ruleID) {
            var aToggle = false
            var seenSection: SectionLabel? = nil
            for bar in 0..<frame.totalBars {
                guard let sec = structure.section(atBar: bar),
                      sec.label != .intro && sec.label != .outro else { continue }
                guard sec.startBar == bar else { continue }   // process each section once at its start
                if sec.label == .B {
                    for b in sec.startBar..<sec.endBar { variationBars.insert(b) }
                } else if sec.label == .A && sec.startBar >= 48 {
                    aToggle.toggle()
                    if aToggle { for b in sec.startBar..<sec.endBar { variationBars.insert(b) } }
                }
                seenSection = sec.label
            }
            _ = seenSection  // suppress unused warning
        }

        var events: [MIDIEvent] = []
        var variationLogged = false   // emit "BASS-EVOL" rule once when first variation bar fires
        var devolveLogged   = false   // emit "BASS-DEVOL" rule once when first revert bar fires
        var wasInVariation  = false   // tracks previous body bar's variation state

        // MOT-BASS-015: sub-pattern rotation (same 3 variants as KOS-BASS-011)
        var mot015Variant    = 0
        var mot015LastSwitch = -16

        for bar in 0..<frame.totalBars {
            guard let section = structure.section(atBar: bar),
                  let entry   = tonalMap.entry(atBar: bar) else { continue }
            let barStart = bar * 16

            if let introSec = structure.introSection, introSec.contains(bar: bar) {
                events += introBar(bar: bar, introSection: introSec, ruleID: ruleID,
                                   barStart: barStart, entry: entry, frame: frame, rng: &rng,
                                   mccartney4BarDrive: mccartney4BarDrive, style: structure.introStyle)
            } else if let outroSec = structure.outroSection, outroSec.contains(bar: bar) {
                events += outroBar(bar: bar, outroSection: outroSec, ruleID: ruleID,
                                   barStart: barStart, entry: entry, frame: frame, rng: &rng,
                                   mccartney4BarDrive: mccartney4BarDrive, style: structure.outroStyle)
            } else {
                let useVariation = variationBars.contains(bar)
                if useVariation { variationLogged = true }
                if !useVariation && wasInVariation { devolveLogged = true }
                wasInVariation = useVariation

                // MOT-BASS-015: rotate sub-pattern at section boundaries and every 16 bars
                // Weights: D=15%, E=35%, C=50% — C (continuous trill) suits high-tempo Motorik best
                if ruleID == "MOT-BASS-015" {
                    let isNewSection  = section.startBar == bar
                    let bars16Elapsed = (bar - mot015LastSwitch) >= 16
                    if isNewSection || bars16Elapsed {
                        let r = rng.nextDouble()
                        mot015Variant    = r < 0.15 ? 0 : r < 0.50 ? 1 : 2
                        mot015LastSwitch = bar
                    }
                }

                events += bodyBar(ruleID: ruleID, barStart: barStart, bar: bar, entry: entry,
                                  frame: frame, rng: &rng, mccartney4BarDrive: mccartney4BarDrive,
                                  useVariation: useVariation, mot015Variant: mot015Variant)
            }
        }

        // variationLogged / devolveLogged are retained for potential future use
        // but BASS-EVOL / BASS-DEVOL are intentionally NOT inserted into usedRuleIDs.
        // "Evolving pattern" is a live playback annotation (step annotations) — it should
        // not appear in the static generation log shown at song-load time.
        _ = variationLogged
        _ = devolveLogged

        return events
    }

    // MARK: - Body bar dispatcher

    private static func bodyBar(
        ruleID: String, barStart: Int, bar: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, mccartney4BarDrive: [Bool],
        useVariation: Bool = false, mot015Variant: Int = 0
    ) -> [MIDIEvent] {
        // Simple 1–2 note rules get a more interesting variant in B sections and after bar 48
        if useVariation, ["MOT-BASS-001", "MOT-BASS-002", "MOT-BASS-004",
                          "MOT-BASS-013", "MOT-BASS-014"].contains(ruleID) {
            return simpleRuleVariationBar(barStart: barStart, bar: bar, ruleID: ruleID, entry: entry, frame: frame)
        }
        switch ruleID {
        case "MOT-BASS-002": return motorikDriveBar(barStart: barStart, entry: entry, frame: frame)
        case "MOT-BASS-003": return crawlingWalkBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "MOT-BASS-004": return hallogalloLockBar(barStart: barStart, entry: entry, frame: frame)
        case "MOT-BASS-005":
            let allDrive = mccartney4BarDrive[min(bar / 4, mccartney4BarDrive.count - 1)]
            return mccartneyDriveBar(barStart: barStart, bar: bar, entry: entry, frame: frame, allDrive: allDrive)
        case "MOT-BASS-006": return laWomanSustainBar(barStart: barStart, entry: entry, frame: frame)
        case "MOT-BASS-007": return hookAscentBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "MOT-BASS-008": return motoroderPulseBar(barStart: barStart, entry: entry, frame: frame)
        case "MOT-BASS-009": return vitaminHookBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "MOT-BASS-010": return quoArcBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "MOT-BASS-011": return quoDriveBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "MOT-BASS-012": return moroderChaseBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "MOT-BASS-013": return kraftwerkRoboterBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "MOT-BASS-014": return mccartneyPBWBar(barStart: barStart, bar: bar, entry: entry, frame: frame)
        case "MOT-BASS-015": return kraftwerkAutobahnMotBar(barStart: barStart, bar: bar, entry: entry,
                                                             frame: frame, useVariation: useVariation,
                                                             subVariant: mot015Variant)
        default:        return rootAnchorBar(barStart: barStart, entry: entry, frame: frame, rng: &rng)
        }
    }

    // MARK: - Variation for simple rules (BAS-001 / BAS-002 / BAS-004)
    // Fires in B sections and at bars >= 48. Keeps the Motorik quarter-note pulse
    // but adds a third or fifth to break the monotony.

    private static func simpleRuleVariationBar(
        barStart: Int, bar: Int, ruleID: String,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root  = chordRootNote(entry: entry, frame: frame)
        let third = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 56))
        let fifth = UInt8(clamped(Int(root) + 7, low: 28, high: 56))

        switch ruleID {

        case "MOT-BASS-002":
            // Motorik Drive + third: root–root–third–root quarter pulse.
            // Same velocity/duration feel as BAS-002; third on beat 3 is the only change.
            let pitches: [UInt8] = [root, root,  third, root ]
            let vels:    [UInt8] = [96,   70,    86,    68   ]
            let durs:    [Int]   = [3,    2,     3,     2    ]
            var evs: [MIDIEvent] = []
            for beat in 0..<4 {
                evs.append(MIDIEvent(stepIndex: barStart + beat * 4, note: pitches[beat],
                                     velocity: vels[beat], durationSteps: durs[beat]))
            }
            return evs

        case "MOT-BASS-004":
            // Hallogallo + arc: root (long) → third → fifth instead of root → fifth.
            // Adds a passing third between the two anchor notes.
            return [
                MIDIEvent(stepIndex: barStart,      note: root,  velocity: 96, durationSteps: 5),
                MIDIEvent(stepIndex: barStart + 6,  note: third, velocity: 78, durationSteps: 3),
                MIDIEvent(stepIndex: barStart + 10, note: fifth, velocity: 84, durationSteps: 5),
            ]

        case "MOT-BASS-013":
            // Kraftwerk Roboter B-section: lock to root–octave–third only (drop fifth cycling).
            // Base bars alternate third (bars 0–1) and fifth (bars 2–3) → fingerprint {root,3rd,5th}.
            // This variation uses only third every bar → fingerprint {root,3rd} — detector fires.
            let octave13 = UInt8(clamped(Int(root) + 12, low: 28, high: 64))
            var evs13: [MIDIEvent] = []
            for cell in 0..<2 {
                let off = cell * 8
                evs13.append(MIDIEvent(stepIndex: barStart + off,     note: root,    velocity: 92, durationSteps: 2))
                evs13.append(MIDIEvent(stepIndex: barStart + off + 2, note: octave13, velocity: 80, durationSteps: 2))
                evs13.append(MIDIEvent(stepIndex: barStart + off + 4, note: third,   velocity: 86, durationSteps: 4))
            }
            return evs13

        case "MOT-BASS-014":
            // McCartney PBW B-section: all-drive, no breathe bar.
            // Base alternates drive (8 notes) / breathe (3 notes) → density ~22 per 4 bars.
            // This plays the full riff every bar → density 32 per 4 bars — density detector fires.
            let isMajorCtx: Bool
            switch entry.chordWindow.chordType {
            case .major, .sus2, .sus4, .add9: isMajorCtx = true
            default:                          isMajorCtx = false
            }
            let flatSeven = isMajorCtx ? fifth : UInt8(clamped(Int(root) + frame.mode.nearestInterval(10), low: 28, high: 52))
            let pitches14: [UInt8] = [root, fifth, root, flatSeven, fifth, root, third, root]
            let vels14:    [UInt8] = [94,   84,    88,   80,        82,    78,   84,    74  ]
            var evs14: [MIDIEvent] = []
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                evs14.append(MIDIEvent(stepIndex: barStart + step, note: pitches14[i],
                                       velocity: vels14[i], durationSteps: 2))
            }
            return evs14

        default: // BAS-001
            // Root Anchor walk: root → third → fifth → root (same arpeggio as the intro hint,
            // now used in the body for variety). Still quarter-note locked.
            return [
                MIDIEvent(stepIndex: barStart,      note: root,  velocity: 92, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: third, velocity: 82, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 8,  note: fifth, velocity: 88, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 12, note: root,  velocity: 78, durationSteps: 4),
            ]
        }
    }

    // MARK: - Intro bass

    private static func introBar(
        bar: Int, introSection: SongSection, ruleID: String,
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, mccartney4BarDrive: [Bool], style: IntroStyle
    ) -> [MIDIEvent] {
        let offsetBar = bar - introSection.startBar

        switch style {
        case .alreadyPlaying:
            // Play the actual bass pattern at full velocity — PlaybackEngine fades the master.
            return bodyBar(ruleID: ruleID, barStart: barStart, bar: bar, entry: entry,
                           frame: frame, rng: &rng, mccartney4BarDrive: mccartney4BarDrive)

        case .progressiveEntry:
            // Simplified riff derived from the song's bass rule — signals "something is coming"
            // without playing the actual groove. Volume fade handled by PlaybackEngine.
            return simplifiedIntroBar(ruleID: ruleID, barStart: barStart, entry: entry, frame: frame)

        case .coldStart(let drumsOnly):
            // drumsOnly bar 0: drums alone, bass silent — full impact lands on bar 1.
            // All other bars: simplified riff at note-on velocity (master ramp provides the fade).
            if drumsOnly && offsetBar == 0 { return [] }
            return simplifiedIntroBar(ruleID: ruleID, barStart: barStart, entry: entry, frame: frame)
        }
    }

    // MARK: - Simplified intro riff (derived-from-rule, not the full pattern)
    //
    // For COMPLEX rules: strip back to a recognisable skeleton that signals the groove.
    // For SIMPLE rules (BAS-001/003/004): go in the OPPOSITE direction — add interest
    // with an ascending scale/arpeggio figure so the intro isn't more boring than the body.
    //
    //   BAS-001  Root Anchor       → quarter-note arpeggio: root→3rd→5th→root (hints at chord)
    //   BAS-002  Motorik Drive     → root only, half-time (beats 1+3, long sustain)
    //   BAS-003  Crawling Walk     → ascending quarter notes: root→2nd→3rd→5th
    //   BAS-004  Hallogallo Lock   → 8th-note scale walk root→2nd→3rd then lands on 5th (held)
    //   BAS-005  McCartney Drive   → breathe-bar pattern (bar 2): root sustain + low fifth + approach
    //   BAS-006  LA Woman          → root whole-bar sustain, no chromatic shimmer
    //   BAS-007  Hook Ascent       → root 8th notes (rhythmic signal, melody withheld)
    //   BAS-008  Moroder Pulse     → root only staccato 8ths (omit fifth and b7)
    //   BAS-009  Vitamin Hook      → root on 1, fifth on 3 (omit arpeggio movement)
    //   BAS-010  Quo Arc           → alternating root–third 8th notes (omit fifth, sixth, b7)
    //   BAS-011  Quo Drive         → alternating root–third 8th notes (same stripped feel)

    private static func simplifiedIntroBar(
        ruleID: String, barStart: Int,
        entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root  = chordRootNote(entry: entry, frame: frame)
        let fifth = UInt8(clamped(Int(root) + 7, low: 28, high: 56))

        switch ruleID {

        case "MOT-BASS-002":   // Motorik Drive → root only, half-time beats 1+3
            return [
                MIDIEvent(stepIndex: barStart,     note: root, velocity: 82, durationSteps: 7),
                MIDIEvent(stepIndex: barStart + 8, note: root, velocity: 74, durationSteps: 7),
            ]

        case "MOT-BASS-003":   // Crawling Walk (simple) → ascending quarter notes root→2nd→3rd→5th
            // Body has root/fifth/approach; intro hints at more by climbing the scale.
            let second3 = UInt8(clamped(Int(root) + frame.mode.nearestInterval(2), low: 28, high: 56))
            let third3  = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 56))
            return [
                MIDIEvent(stepIndex: barStart,      note: root,    velocity: 82, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: second3, velocity: 80, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 8,  note: third3,  velocity: 84, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 12, note: fifth,   velocity: 88, durationSteps: 4),
            ]

        case "MOT-BASS-004":   // Hallogallo Lock (simple) → 8th-note scale walk root→2nd→3rd, lands on 5th
            // Body is just root+fifth; intro builds anticipation by walking up to that fifth.
            let second4 = UInt8(clamped(Int(root) + frame.mode.nearestInterval(2), low: 28, high: 56))
            let third4  = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 56))
            return [
                MIDIEvent(stepIndex: barStart,      note: root,    velocity: 84, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 2,  note: second4, velocity: 80, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 4,  note: third4,  velocity: 82, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 6,  note: fifth,   velocity: 88, durationSteps: 10),
            ]

        case "MOT-BASS-005":   // McCartney Drive → breathe bar: root sustain + low fifth + approach
            let lowerFifth = UInt8(clamped(Int(root) - 5, low: 28, high: 52))
            let approach   = UInt8(clamped(Int(root) - 2, low: 28, high: 52))
            return [
                MIDIEvent(stepIndex: barStart,      note: root,       velocity: 84, durationSteps: 7),
                MIDIEvent(stepIndex: barStart + 8,  note: lowerFifth, velocity: 74, durationSteps: 5),
                MIDIEvent(stepIndex: barStart + 14, note: approach,   velocity: 60, durationSteps: 2),
            ]

        case "MOT-BASS-006":   // LA Woman → root whole-bar, no shimmer
            return [MIDIEvent(stepIndex: barStart, note: root, velocity: 86, durationSteps: 14)]

        case "MOT-BASS-007":   // Hook Ascent → root 8th notes (rhythm signal, melody withheld)
            var evs7: [MIDIEvent] = []
            let vels7: [UInt8] = [86, 72, 78, 68, 82, 68, 76, 66]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                evs7.append(MIDIEvent(stepIndex: barStart + step, note: root,
                                      velocity: vels7[i], durationSteps: 2))
            }
            return evs7

        case "MOT-BASS-008":   // Moroder Pulse → root only staccato 8ths (omit fifth and b7)
            var evs8: [MIDIEvent] = []
            let vels8: [UInt8] = [90, 74, 80, 70, 84, 70, 80, 72]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                evs8.append(MIDIEvent(stepIndex: barStart + step, note: root,
                                      velocity: vels8[i], durationSteps: 1))
            }
            return evs8

        case "MOT-BASS-009":   // Vitamin Hook → root on 1, fifth on 3 (omit arpeggio movement)
            return [
                MIDIEvent(stepIndex: barStart,     note: root,  velocity: 86, durationSteps: 7),
                MIDIEvent(stepIndex: barStart + 8, note: fifth, velocity: 76, durationSteps: 7),
            ]

        case "MOT-BASS-012":   // Moroder Chase → root only staccato 16ths (omit b3 and fifth)
            // Intro strips back to pure-root machine pulse — saves the minor-pentatonic
            // cycling (b3/fifth) for the body arrival.
            var evs12: [MIDIEvent] = []
            let vels12: [UInt8] = [90, 68, 78, 58, 86, 64, 74, 56, 88, 66, 76, 58, 84, 62, 72, 54]
            for step in 0..<16 {
                evs12.append(MIDIEvent(stepIndex: barStart + step, note: root,
                                       velocity: vels12[step], durationSteps: 1))
            }
            return evs12

        case "MOT-BASS-013":   // Kraftwerk Roboter → root only, quarter notes (no octave jump intro)
            // Holds back the octave jump for the body; quarter-note root pulse signals "something big"
            return [
                MIDIEvent(stepIndex: barStart,      note: root, velocity: 90, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: root, velocity: 78, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 8,  note: root, velocity: 86, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 12, note: root, velocity: 74, durationSteps: 4),
            ]

        case "MOT-BASS-014":   // McCartney PBW → root only, half-time beats 1+3 (withholds the Mixolydian melody)
            return [
                MIDIEvent(stepIndex: barStart,     note: root, velocity: 86, durationSteps: 7),
                MIDIEvent(stepIndex: barStart + 8, note: root, velocity: 76, durationSteps: 7),
            ]

        case "MOT-BASS-010", "MOT-BASS-011":   // Quo Arc / Quo Drive → root–third alternating 8ths
            let third = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 62))
            let quoNotes: [UInt8] = [root, third, root, third, root, third, root, third]
            let quoVels:  [UInt8] = [90,   76,    86,   72,    88,   74,    84,   70  ]
            var evsQuo: [MIDIEvent] = []
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                evsQuo.append(MIDIEvent(stepIndex: barStart + step, note: quoNotes[i],
                                        velocity: quoVels[i], durationSteps: 2))
            }
            return evsQuo

        default:   // BAS-001 Root Anchor (simple) → quarter-note chord arpeggio: root→3rd→5th→root
            // Body alternates just two notes; intro hints at the full chord with a short arpeggio.
            let third1 = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 56))
            return [
                MIDIEvent(stepIndex: barStart,      note: root,   velocity: 86, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: third1, velocity: 80, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 8,  note: fifth,  velocity: 86, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 12, note: root,   velocity: 78, durationSteps: 4),
            ]
        }
    }

    // MARK: - Outro bass

    private static func outroBar(
        bar: Int, outroSection: SongSection, ruleID: String,
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        rng: inout SeededRNG, mccartney4BarDrive: [Bool], style: OutroStyle
    ) -> [MIDIEvent] {
        let offsetBar = bar - outroSection.startBar
        let totalBars = outroSection.lengthBars

        switch style {
        case .fade:
            // Actual bass pattern at full velocity — PlaybackEngine fades the master out.
            return bodyBar(ruleID: ruleID, barStart: barStart, bar: bar, entry: entry,
                           frame: frame, rng: &rng, mccartney4BarDrive: mccartney4BarDrive)

        case .dissolve:
            // Bass plays a simplified anchor in the first half, then drops out — pads hold alone.
            if offsetBar < totalBars / 2 {
                return simplifiedBassBar(barStart: barStart, entry: entry, frame: frame)
            }
            return []  // silent — pads carry the final bars

        case .coldStop:
            // Bass plays body pattern until the final bar; cuts one bar before the drum fill.
            if offsetBar >= totalBars - 1 { return [] }
            return bodyBar(ruleID: ruleID, barStart: barStart, bar: bar, entry: entry,
                           frame: frame, rng: &rng, mccartney4BarDrive: mccartney4BarDrive)
        }
    }

    // MARK: - Simplified bass (root on 1, fifth on 3) — intro/outro anchor

    private static func simplifiedBassBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root  = chordRootNote(entry: entry, frame: frame)
        let fifth = UInt8(clamped(Int(root) + 7, low: 28, high: 56))
        return [
            MIDIEvent(stepIndex: barStart,     note: root,  velocity: 78, durationSteps: 7),
            MIDIEvent(stepIndex: barStart + 8, note: fifth, velocity: 70, durationSteps: 7),
        ]
    }

    // MARK: - BAS-001: Root Anchor — clean, locked to beat 1 and 3

    private static func rootAnchorBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote = chordRootNote(entry: entry, frame: frame)
        let chordTones = entry.chordWindow.chordTones.sorted()

        events.append(MIDIEvent(stepIndex: barStart, note: rootNote, velocity: 92, durationSteps: 6))

        let beat3Note: UInt8
        if let fifth = chordTones.first(where: { ($0 - (Int(rootNote) % 12) + 12) % 12 == 7 }) {
            beat3Note = noteInBassRegister(pc: fifth, frame: frame)
        } else {
            beat3Note = rootNote
        }
        events.append(MIDIEvent(stepIndex: barStart + 8, note: beat3Note, velocity: 80, durationSteps: 5))
        return events
    }

    // MARK: - BAS-002: Motorik Drive — steady quarter pulse, velocity-accented

    private static func motorikDriveBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote = chordRootNote(entry: entry, frame: frame)
        let velocities: [UInt8] = [96, 70, 88, 68]
        let durations:  [Int]   = [3,  2,  3,  2]
        for beat in 0..<4 {
            events.append(MIDIEvent(stepIndex: barStart + beat * 4, note: rootNote,
                                    velocity: velocities[beat], durationSteps: durations[beat]))
        }
        return events
    }

    // MARK: - BAS-003: Crawling Walk — 2-bar root/fifth/approach pattern

    private static func crawlingWalkBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote    = chordRootNote(entry: entry, frame: frame)
        let fifthNote   = UInt8(clamped(Int(rootNote) + 7, low: 28, high: 52))
        // Approach note: 2 semitones below root. Only use it when it falls on a scale tone —
        // the chromatic approach clashes badly in Dorian/Aeolian where -2 from the chord root
        // often lands outside the mode.
        let approachPC   = (Int(rootNote) - 2 + 12) % 12
        let keyST        = keySemitone(frame.key)
        let scalePCs     = Set(frame.mode.intervals.map { (keyST + $0) % 12 })
        let useApproach  = scalePCs.contains(approachPC)
        let approachNote = UInt8(clamped(Int(rootNote) - 2, low: 28, high: 52))

        if bar % 2 == 0 {
            events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,  velocity: 92, durationSteps: 7))
            events.append(MIDIEvent(stepIndex: barStart + 10, note: fifthNote, velocity: 76, durationSteps: useApproach ? 3 : 6))
            if useApproach {
                events.append(MIDIEvent(stepIndex: barStart + 15, note: approachNote, velocity: 65, durationSteps: 1))
            }
        } else {
            events.append(MIDIEvent(stepIndex: barStart,     note: rootNote,  velocity: 92, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 5, note: rootNote,  velocity: 78, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 8, note: fifthNote, velocity: 85, durationSteps: 6))
        }
        return events
    }

    // MARK: - BAS-004: Hallogallo Lock — most authentic Motorik bass

    private static func hallogalloLockBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote  = chordRootNote(entry: entry, frame: frame)
        let fifthNote = UInt8(clamped(Int(rootNote) + 7, low: 28, high: 52))
        events.append(MIDIEvent(stepIndex: barStart,     note: rootNote,  velocity: 96, durationSteps: 7))
        events.append(MIDIEvent(stepIndex: barStart + 8, note: fifthNote, velocity: 80, durationSteps: 6))
        return events
    }

    // MARK: - BAS-005: McCartney Drive — 8th-note locked groove from SLS verse

    private static func mccartneyDriveBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame, allDrive: Bool = false
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote   = chordRootNote(entry: entry, frame: frame)
        // lowerThird: 3rd interval going down — tracks mode (major 3rd=4 in Ionian, minor 3rd=3 in Aeolian/Dorian)
        let lowerThird = UInt8(clamped(Int(rootNote) - frame.mode.nearestInterval(4), low: 28, high: 52))
        let lowerFifth = UInt8(clamped(Int(rootNote) - 5, low: 28, high: 52))  // P5 down, always mode-neutral
        let approach   = UInt8(clamped(Int(rootNote) - 2, low: 28, high: 52))  // chromatic approach, intentional

        // allDrive: bass "sits on" the descent groove for 4 bars straight (1/3 of phrases).
        // Normal alternation: drive on even bars, breathe on odd bars.
        if allDrive || bar % 2 == 0 {
            let pitches: [UInt8] = [rootNote, rootNote, lowerThird, lowerThird,
                                    lowerFifth, lowerFifth, lowerThird, lowerFifth]
            let vels:    [UInt8] = [92, 84, 78, 74, 82, 76, 72, 68]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
        } else {
            events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,   velocity: 92, durationSteps: 7))
            events.append(MIDIEvent(stepIndex: barStart + 8,  note: lowerFifth, velocity: 82, durationSteps: 5))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: approach,   velocity: 65, durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-006: LA Woman Sustain — long root hold with chromatic shimmer at bar end

    private static func laWomanSustainBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let rootNote      = chordRootNote(entry: entry, frame: frame)
        let upperNeighbor = UInt8(clamped(Int(rootNote) + 1, low: 28, high: 52))
        events.append(MIDIEvent(stepIndex: barStart,      note: rootNote,      velocity: 90, durationSteps: 11))
        events.append(MIDIEvent(stepIndex: barStart + 12, note: rootNote,      velocity: 76, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 13, note: upperNeighbor, velocity: 68, durationSteps: 1))
        events.append(MIDIEvent(stepIndex: barStart + 14, note: rootNote,      velocity: 72, durationSteps: 2))
        return events
    }

    // MARK: - BAS-007: Hook Ascent — Peter Hook / Joy Division "She's Lost Control"
    // Melodic riff in standard bass register, 2-bar pattern.
    // Bar 1 (drive): 8 eighth-note attacks, hammering the mode 3rd, descending tail 3rd→2nd.
    // Bar 2 (descent): steps down from 3rd through 2nd to root, lands on mode 6th, chromatic pickup.
    // All scale degrees (3rd, 2nd, 6th) snap to the song's mode — minor songs get minor 3rd etc.

    private static func hookAscentBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root   = chordRootNote(entry: entry, frame: frame)
        let third  = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 36, high: 60))  // mode 3rd
        let second = UInt8(clamped(Int(root) + frame.mode.nearestInterval(2), low: 36, high: 60))  // mode 2nd
        let sixth  = UInt8(clamped(Int(root) + frame.mode.nearestInterval(9), low: 36, high: 60))  // mode 6th

        if bar % 2 == 0 {
            // Drive bar: six M3 hits, step down to M2, return to M3 (descending tail)
            let pitches: [UInt8] = [third, third, third, third, third, third, second, third]
            let vels:    [UInt8] = [90, 86, 84, 80, 80, 78, 76, 74]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
        } else {
            // Descent bar: M3 → M2 → M3 → root (long) → m6 → root pickup
            events.append(MIDIEvent(stepIndex: barStart,      note: third,  velocity: 88, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 4,  note: second, velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 6,  note: third,  velocity: 76, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 8,  note: root,   velocity: 82, durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 12, note: sixth,  velocity: 72, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: root,   velocity: 68, durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-008: Moroder Pulse — Giorgio Moroder "I Feel Love" sequenced staccato 8ths
    // Mechanical 8th-note ostinato: root-root-fifth-fifth-b7-b7-root-root.
    // All notes staccato (dur 1). The b7 pair gives a dominant-7th / Mixolydian colour;
    // in major chord context, the b7 slots are replaced with root to stay diatonic.
    // The wrap-around (steps 12-14 repeat root) creates subtle 6-against-8 metric displacement.

    private static func motoroderPulseBar(
        barStart: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root  = chordRootNote(entry: entry, frame: frame)
        let fifth = UInt8(clamped(Int(root) + 7, low: 28, high: 52))
        // b7 only in minor/Dorian/Mixolydian chord contexts; stay on root in pure major
        let isMajorContext: Bool
        switch entry.chordWindow.chordType {
        case .major, .sus2, .sus4, .add9: isMajorContext = true
        default:                          isMajorContext = false
        }
        let flatSeven = isMajorContext ? root : UInt8(clamped(Int(root) + 10, low: 28, high: 52))

        let pitches: [UInt8] = [root, root, fifth, fifth, flatSeven, flatSeven, root, root]
        let vels:    [UInt8] = [92,   80,   84,    78,    84,        78,        82,   76  ]
        for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                    velocity: vels[i], durationSteps: 1))
        }
        return events
    }

    // MARK: - BAS-009: Vitamin Hook — Holger Czukay / CAN "Vitamin C" ascending arpeggio
    // 2-bar rolling arpeggio spanning root→fifth→octave with scale-snapped passing tones.
    // Bar 1 (ascent): root×2 drive, fifth, scale passing note, octave arrival, mode 3rd colour, fifth tail.
    // Bar 2 (descent): octave→fifth→root (long breathe), scale upper neighbour, fifth, root pickup.
    // Source: Ege Bamyasi (1972) — Czukay's signature ascending string-crossing arpeggiation.

    /// Returns the nearest in-scale MIDI note to `target`, clamped to [low, high].
    private static func nearestScaleNote(to target: Int, frame: GlobalMusicalFrame, low: Int, high: Int) -> UInt8 {
        let scalePCs = Set(frame.mode.intervals.map { (frame.keySemitoneValue + $0) % 12 })
        let nearest  = (low...high).filter { scalePCs.contains($0 % 12) }
                                   .min(by: { abs($0 - target) < abs($1 - target) })
        return UInt8(clamped(nearest ?? target, low: low, high: high))
    }

    private static func vitaminHookBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root       = chordRootNote(entry: entry, frame: frame)
        let fifth      = UInt8(clamped(Int(root) + 7,  low: 28, high: 56))
        let octave     = UInt8(clamped(Int(root) + 12, low: 28, high: 56))  // wide range for arpeggio
        let minorThird = nearestScaleNote(to: Int(root) + 3, frame: frame, low: 28, high: 56)  // mode 3rd colour
        let tritPass   = nearestScaleNote(to: Int(root) + 6, frame: frame, low: 28, high: 56)  // scale passing tone
        let upperNeigh = nearestScaleNote(to: Int(root) + 8, frame: frame, low: 28, high: 56)  // scale upper neighbour

        if bar % 2 == 0 {
            // Ascent bar: root pump → fifth → chromatic pass → octave arrival → m3 colour → fifth tail
            events.append(MIDIEvent(stepIndex: barStart,      note: root,       velocity: 90, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 2,  note: root,       velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 4,  note: fifth,      velocity: 86, durationSteps: 3))
            events.append(MIDIEvent(stepIndex: barStart + 7,  note: tritPass,   velocity: 72, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + 8,  note: octave,     velocity: 88, durationSteps: 4))
            events.append(MIDIEvent(stepIndex: barStart + 12, note: minorThird, velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: fifth,      velocity: 72, durationSteps: 2))
        } else {
            // Descent bar: octave → fifth → long root breathe → m6 upper neighbour → fifth → root pickup
            events.append(MIDIEvent(stepIndex: barStart,      note: octave,     velocity: 86, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 2,  note: fifth,      velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 4,  note: root,       velocity: 90, durationSteps: 6))
            events.append(MIDIEvent(stepIndex: barStart + 10, note: upperNeigh, velocity: 70, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 12, note: fifth,      velocity: 76, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + 14, note: root,       velocity: 68, durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-010: Quo Arc — Status Quo "Down Down" 2-bar boogie-woogie arc
    // Boogie-woogie scale: 1, 3, 5, 6, b7 (major 3rd and b7 always used — the blues/boogie colour).
    // Bar 1 (even, ascent): paired 8th notes climbing 1-1-3-3-5-5-6-b7.
    //   The pairs give a "pumping" double-hit feel — root and root, 3rd and 3rd, etc.
    //   b7 marks the arc apex on beat 4 with a solo hit (no pair), creating forward lean.
    // Bar 2 (odd, descent): b7-6-5-3-1-1-1-1 — falls back to root, which is then held
    //   as four repeated 8th notes, locking to the kick on the next downbeat.
    // Source: Alan Lancaster / Status Quo, "Down Down" (1974).

    private static func quoArcBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root  = chordRootNote(entry: entry, frame: frame)
        let third = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 62))  // mode 3rd
        let fifth = UInt8(clamped(Int(root) + 7,  low: 28, high: 62))  // P5, mode-neutral
        let sixth = UInt8(clamped(Int(root) + frame.mode.nearestInterval(9), low: 28, high: 62))  // mode 6th
        let flatSeven = UInt8(clamped(Int(root) + 10, low: 28, high: 62))  // b7 boogie apex — intentional chromatic

        if bar % 2 == 0 {
            // Ascent bar: 1-1-3-3-5-5-6-b7 (paired doubles, solo b7 at beat 4)
            let pitches: [UInt8] = [root, root, third, third, fifth, fifth, sixth, flatSeven]
            let vels:    [UInt8] = [92,   82,   80,    76,    88,    80,    78,    76]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
        } else {
            // Descent bar: b7-6-5-3-1-1-1-1 (falls to root, then root holds for locking)
            let pitches: [UInt8] = [flatSeven, sixth, fifth, third, root, root, root, root]
            let vels:    [UInt8] = [88,        80,    78,    76,    86,   80,   76,   72]
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
        }
        return events
    }

    // MARK: - BAS-011: Quo Drive — Status Quo "Caroline"/"Paper Plane" 1-bar boogie arc
    // Full up-and-back arc compressed into a single bar — all 8 8th-note slots.
    // Even bars use the "Paper Plane" root-push variant: 1-1-3-5-6-b7-6-5.
    //   The double root at steps 0-2 gives a punchy launch before climbing.
    // Odd bars use the "Caroline" full-arc variant: 1-3-5-6-b7-6-5-3.
    //   Symmetric up-and-back — every note in the boogie-woogie scale visited once.
    // Both variants sit within a single bar, making this a dense, relentless driver.
    // Source: Alan Lancaster / Status Quo, "Caroline" (1973), "Paper Plane" (1972).

    private static func quoDriveBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        let root      = chordRootNote(entry: entry, frame: frame)
        let third     = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 62))  // mode 3rd
        let fifth     = UInt8(clamped(Int(root) + 7,  low: 28, high: 62))  // P5, mode-neutral
        let sixth     = UInt8(clamped(Int(root) + frame.mode.nearestInterval(9), low: 28, high: 62))  // mode 6th
        let flatSeven = UInt8(clamped(Int(root) + 10, low: 28, high: 62))  // b7 boogie apex — intentional chromatic

        let pitches: [UInt8]
        let vels:    [UInt8]

        if bar % 2 == 0 {
            // Paper Plane root-push: 1-1-3-5-6-b7-6-5 (double root, then climb, partial descent)
            pitches = [root, root, third, fifth, sixth, flatSeven, sixth, fifth]
            vels    = [92,   82,   80,    78,    86,    80,        78,    74]
        } else {
            // Caroline full arc: 1-3-5-6-b7-6-5-3 (complete up-and-back in one bar)
            pitches = [root, third, fifth, sixth, flatSeven, sixth, fifth, third]
            vels    = [92,   82,    80,    78,    88,        80,    78,    74]
        }

        for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
            events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                    velocity: vels[i], durationSteps: 2))
        }
        return events
    }

    // MARK: - BAS-012: Moroder Chase — Midnight Express (1978) delay-echo 16th-note ostinato
    // The original bass was 8th notes on a Minimoog; an AMS digital delay set to exact
    // 16th-note time created a mirrored echo on every odd step, producing continuous 16ths.
    // Simulated here by writing alternating primary (even steps, 8th-note positions) and
    // quieter echo notes (odd steps, 16th-note off-positions) at ~70% of primary velocity.
    // Primary pattern (even steps): root–mode3rd–fifth–root cycling (4 pairs = 8 positions).
    // The minor-pentatonic cycling (1–b3–5) is what distinguishes Chase from BAS-008 (1–5–b7).
    // In major chord contexts the mode-third becomes a major third — stays diatonic either way.
    //
    // 2-bar evolution: bar 1 (even) plays the full root–b3–fifth cycling;
    // bar 2 (odd) releases tension by dropping to root–root–fifth–root (omits b3),
    // simulating the natural "breath" a real bassist would take between drive bars.

    private static func moroderChaseBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root  = chordRootNote(entry: entry, frame: frame)
        let third = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 52))
        let fifth = UInt8(clamped(Int(root) + 7, low: 28, high: 52))

        // Even bars: full chase (root–third–fifth–root); odd bars: simplified (root–root–fifth–root)
        let primaryNotes: [UInt8]
        let primaryVels:  [UInt8]
        if bar % 2 == 0 {
            primaryNotes = [root, third, fifth, root, root, third, fifth, root]
            primaryVels  = [92,   86,    88,   84,   90,   84,    86,   82  ]
        } else {
            primaryNotes = [root, root,  fifth, root, root, fifth, root, root]
            primaryVels  = [90,   82,    86,   80,   88,   84,    82,   78  ]
        }

        var events: [MIDIEvent] = []
        for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
            let pVel = primaryVels[i]
            let eVel = UInt8(max(18, Int(pVel) * 70 / 100))  // echo at ~70% of primary
            events.append(MIDIEvent(stepIndex: barStart + step,     note: primaryNotes[i],
                                    velocity: pVel, durationSteps: 1))
            events.append(MIDIEvent(stepIndex: barStart + step + 1, note: primaryNotes[i],
                                    velocity: eVel, durationSteps: 1))
        }
        return events
    }

    // MARK: - BAS-013: Kraftwerk Roboter — "The Robots" (1978) octave-jump 3-note cell
    // A 3-note cell repeating twice per bar: root(low, 8th) – root+octave(high, 8th) – mode-3rd(quarter).
    // The instant octave jump (impossible on acoustic bass; native to synthesizer) is the signature.
    // 3-note cell in 8-step half-bar groups: steps 0-7 = cell 1, steps 8-15 = cell 2.
    // The cell is exactly 2 beats long (8 steps), fitting twice in a 4/4 bar.
    // In the original Dm, the 3rd is F (minor); in major keys, it's the major third.
    // Range extended to 28-64 to allow the octave note to sit above the normal bass floor.
    // Best at Kosmic tempos (100-125 BPM) and low Motorik (128-135 BPM).
    //
    // 4-bar evolution: bars 1-2 (standard): root–octave–third / root–octave–third
    //                 bars 3-4 (inverted):  root–octave–fifth / root–octave–fifth
    // The fifth swap on bars 3-4 adds harmonic lift before returning to the third on bar 1.
    // Also: every 8 bars a "lock" bar plays root-only quarter notes (root–root–root–root)
    // — strips back the octave jump for one bar so the return of the jump on the next bar
    // feels like a re-arrival. Inspired by how Kraftwerk's sequencers occasionally held a note.

    private static func kraftwerkRoboterBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root   = chordRootNote(entry: entry, frame: frame)
        let octave = UInt8(clamped(Int(root) + 12, low: 28, high: 64))
        let third  = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 56))
        let fifth  = UInt8(clamped(Int(root) + 7, low: 28, high: 56))

        // Every 8 bars: one "lock" bar — root-only quarter notes, no octave jump
        if bar % 8 == 7 {
            return [
                MIDIEvent(stepIndex: barStart,      note: root, velocity: 92, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: root, velocity: 80, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 8,  note: root, velocity: 88, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 12, note: root, velocity: 78, durationSteps: 4),
            ]
        }

        // Bars 0-1 of each 4-bar group: third on the landing note
        // Bars 2-3 of each 4-bar group: fifth on the landing note (harmonic lift)
        let landing = (bar % 4 < 2) ? third : fifth
        let landingVel: UInt8 = (bar % 4 < 2) ? 76 : 80

        var events: [MIDIEvent] = []
        for cell in 0..<2 {
            let offset = cell * 8
            events.append(MIDIEvent(stepIndex: barStart + offset,     note: root,    velocity: 92, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + offset + 2, note: octave,  velocity: 80, durationSteps: 2))
            events.append(MIDIEvent(stepIndex: barStart + offset + 4, note: landing, velocity: landingVel, durationSteps: 4))
        }
        return events
    }

    // MARK: - BAS-014: McCartney PBW — "Paperback Writer" (1966) Mixolydian riff
    // One of McCartney's most analyzed bass lines. In G major/Mixolydian:
    //   G–D–G–F–D–G–B–G = root–fifth–root–b7–fifth–root–mode3rd–root in 8 8th-notes.
    // The flat-seventh (b7 = F in G major) gives it a blues/Mixolydian edge.
    // In minor/Dorian/Mixolydian contexts b7 is naturally diatonic (stays on b7).
    // In pure major (Ionian) contexts b7 is chromatic — replaced with fifth to stay diatonic.
    // The mode-third at position 7 adapts: major third in Ionian/Mixolydian, minor third in Dorian/Aeolian.
    //
    // 2-bar evolution: McCartney alternates the full riff (even bars) with a "breathe" bar (odd bars)
    // that holds root for two beats then walks root–fifth–root–pickup — giving the riff room to land
    // before repeating. This is faithful to how Beatles arrangements actually work: the bass riff
    // doesn't repeat mechanically for 32 bars; it breathes every other bar.

    private static func mccartneyPBWBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame
    ) -> [MIDIEvent] {
        let root  = chordRootNote(entry: entry, frame: frame)
        let fifth = UInt8(clamped(Int(root) + 7,  low: 28, high: 52))
        let third = UInt8(clamped(Int(root) + frame.mode.nearestInterval(4), low: 28, high: 52))

        let isMajorContext: Bool
        switch entry.chordWindow.chordType {
        case .major, .sus2, .sus4, .add9: isMajorContext = true
        default:                          isMajorContext = false
        }
        let flatSeven = isMajorContext ? fifth : UInt8(clamped(Int(root) + 10, low: 28, high: 52))

        if bar % 2 == 0 {
            // Drive bar: full riff — root–fifth–root–b7–fifth–root–mode3rd–root
            let pitches: [UInt8] = [root, fifth, root, flatSeven, fifth, root, third, root]
            let vels:    [UInt8] = [94,   84,    88,   80,        82,    78,   84,    74  ]
            var events: [MIDIEvent] = []
            for (i, step) in stride(from: 0, to: 16, by: 2).enumerated() {
                events.append(MIDIEvent(stepIndex: barStart + step, note: pitches[i],
                                        velocity: vels[i], durationSteps: 2))
            }
            return events
        } else {
            // Breathe bar: root hold (beats 1–2), then root–fifth–root walkup (beats 3–4)
            // Simulates McCartney sustaining under the chord while the riff "resets"
            return [
                MIDIEvent(stepIndex: barStart,      note: root,  velocity: 90, durationSteps: 7),
                MIDIEvent(stepIndex: barStart + 8,  note: root,  velocity: 82, durationSteps: 3),
                MIDIEvent(stepIndex: barStart + 12, note: fifth, velocity: 78, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 14, note: root,  velocity: 70, durationSteps: 2),
            ]
        }
    }

    // MARK: - MOT-BASS-015: Kraftwerk Autobahn driving bass (Motorik range MIDI 28–52)
    // Same 3-pattern rotation as KOS-BASS-011 but tuned for Motorik's unwavering pulse.
    //   0 = Pattern D — 5-note grid: root(q), octave(e), 4th(e), root(e), 5th(e)
    //       Beat 3 (step 8) is now covered with a root so the groove stays locked.
    //   1 = Pattern E — canonical hook with held 4th: root(q), octave(e), 4th(e), 4th(dotq), 5th(e)
    //   2 = Pattern C — 8th-note octave trill: all 8 subdivisions alternating root/octave
    // B-section variation (useVariation): b7th replaces the 4th in patterns D and E.
    // NO lock bar — Motorik must maintain the pulse every bar without interruption.
    // Weights: D=15%, E=35%, C=50% — C dominates since trill suits high-tempo Motorik best.

    private static func kraftwerkAutobahnMotBar(
        barStart: Int, bar: Int, entry: TonalGovernanceEntry, frame: GlobalMusicalFrame,
        useVariation: Bool = false, subVariant: Int = 0
    ) -> [MIDIEvent] {
        let root   = chordRootNote(entry: entry, frame: frame)
        let octave = UInt8(clamped(Int(root) + 12, low: 40, high: 64))
        let fourth = UInt8(clamped(Int(root) + 5,  low: 28, high: 52))
        let fifth  = UInt8(clamped(Int(root) + 7,  low: 28, high: 52))
        let b7     = UInt8(clamped(Int(root) + frame.mode.nearestInterval(10), low: 28, high: 55))

        switch subVariant {
        case 1:
            let midNote: UInt8 = useVariation ? b7 : fourth
            let midVel:  UInt8 = useVariation ? 82 : 86
            return [
                MIDIEvent(stepIndex: barStart,      note: root,    velocity: 89, durationSteps: 4),
                MIDIEvent(stepIndex: barStart + 4,  note: octave,  velocity: 89, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 6,  note: midNote, velocity: midVel, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 8,  note: midNote, velocity: 84, durationSteps: 6),
                MIDIEvent(stepIndex: barStart + 14, note: fifth,   velocity: 84, durationSteps: 2),
            ]
        case 2:
            return stride(from: 0, to: 16, by: 2).map { step in
                let onBeat = (step % 4 == 0)
                let note   = onBeat ? root : octave
                return MIDIEvent(stepIndex: barStart + step, note: note,
                                 velocity: UInt8(onBeat ? 89 : 80), durationSteps: 2)
            }
        default:
            // Pattern D: cover beat 3 with a root hit so there's no hole at high tempo
            let midNote: UInt8 = useVariation ? b7 : fourth
            let midVel:  UInt8 = useVariation ? 82 : 86
            return [
                MIDIEvent(stepIndex: barStart,      note: root,    velocity: 89, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 4,  note: octave,  velocity: 89, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 6,  note: midNote, velocity: midVel, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 8,  note: root,    velocity: 82, durationSteps: 2),
                MIDIEvent(stepIndex: barStart + 14, note: fifth,   velocity: 84, durationSteps: 2),
            ]
        }
    }

    // MARK: - Note helpers

    private static func chordRootNote(entry: TonalGovernanceEntry, frame: GlobalMusicalFrame) -> UInt8 {
        let rootPC = (keySemitone(frame.key) + degreeSemitone(entry.chordWindow.chordRoot)) % 12
        let raw = 12 + 2 * 12 + rootPC  // octave 3 (MIDI 36-47)
        return UInt8(clamped(raw, low: 28, high: 52))
    }

    private static func noteInBassRegister(pc: Int, frame: GlobalMusicalFrame) -> UInt8 {
        for oct in 2...4 {
            let midi = oct * 12 + pc
            if midi >= 28 && midi <= 52 { return UInt8(midi) }
        }
        return 36
    }

    private static func clamped(_ v: Int, low: Int, high: Int) -> Int {
        max(low, min(high, v))
    }

}
