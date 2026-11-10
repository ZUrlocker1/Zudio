// HookLeadEngine.swift — transcription-inspired hook rules for Motorik and Kosmic Lead 1
// Copyright (c) 2026 Zack Urlocker
//
// Each rule is a short phrase drawn from a real piece: a call, an answer, a few variants from the
// same source and an optional tail. The engine states the phrase, varies it on return and plays it
// plain once more near the end, so the lead has a hook you could hum. All rules share this engine
// and differ only in data. See docs/Solo-improvement-plan.md, "Build spec".
//
// Homage, not copy: before a song uses its hook, `homage` reworks the cells with the song's seed —
// a passing note added, an interior note dropped, an onset moved, two notes swapped, a repeated
// note turned into a neighbour. The first note and the held last note stay, so the shape is still
// recognisable, but no song plays the source as transcribed and no two songs play the same version.
//
// MOT-LD1-023 Hallogallo hook     — Neu!, Hallogallo (1972), Michael Rother's Guitar 2 riff
// MOT-LD1-024 Radioactive riff    — Kraftwerk, Radioactivity (1975), the key-synth riff
// MOT-LD1-025 Model riff          — Kraftwerk, The Model (1978), synth riff and vocal line
// MOT-LD1-026 Tour de France riff — Kraftwerk, Tour de France (1983), the guitar theme

/// One note of a hook cell. `step` is the onset within its bar (negative for a pickup into the
/// bar), `deg` is semitones from the song tonic in the source's terms (14 is the ninth an octave
/// up; a source's major or minor third both become the song's third), `len` is the gate in steps.
struct HookNote: Sendable {
    var step: Int
    var deg: Int
    var len: Int
    var vel: Int
}

typealias HookBar = [HookNote]

/// A replacement for the call or the answer, taken from the same source.
struct HookSourceVariant: Sendable {
    var call: [HookBar]? = nil
    var answer: [HookBar]? = nil
}

struct HookRule: Sendable {
    let id: String
    var call: [HookBar]
    var answer: [HookBar]
    /// A second form of the call that alternates with it on plain statements, as The Model's
    /// riff alternates with its vocal line.
    var restatement: [HookBar]? = nil
    /// Scale steps applied to the plain answer: Radioactivity answers itself a third lower.
    var answerShift: Int = 0
    var sourceVariants: [HookSourceVariant] = []
    /// Filler for the bar after a statement, so the reply isn't always another hook.
    var tail: HookBar? = nil
    /// Statement starts, in bars from the previous start, and their weights (sum to 1). A song
    /// states its hook 3 to 5 times in the body, so these run 8 to 20 bars.
    var spacings: [Int]
    var spacingWeights: [Double]
    /// `deg` is a scale step from the tonic, not a semitone: Blade Runner's line steps down the
    /// scale, so it keeps its shape in any mode.
    var scaleSteps = false
    /// Homage changes one note instead of two or three, for cells of a few long notes.
    var gentle = false
    /// Weights for add passing, drop, move onset, swap and neighbour, where the defaults would
    /// break the cell: a drop leaves a bar of Blade Runner's staircase empty, and a swap trades
    /// Pulstar's tonic with the pickup before it.
    var homageWeights: [Double]? = nil
    /// Body statements a song may have: the cap is drawn from `maxStatements`, and a song with
    /// fewer than `minStatements` gets one more placed.
    var minStatements = 3
    var maxStatements = [3, 4, 5]
    var maxStatementWeights = [0.20, 0.40, 0.40]
    /// Weights for head, loop, answer only, sequence and varied, when the defaults don't suit.
    var formWeights: [Double]? = nil
    /// A call sequenced as a statement of its own, or as a variation, goes up a scale step this
    /// often and down otherwise.
    var sequenceUpChance = 0.70
    /// The song register the hook sits in, where it differs from Lead 1's.
    var register: RegisterBounds? = nil
}

enum HookLeadEngine {

    // MARK: - Rule data

    private static func n(_ step: Int, _ deg: Int, _ len: Int, _ vel: Int) -> HookNote {
        HookNote(step: step, deg: deg, len: len, vel: vel)
    }

    /// Built from Claude's sketch (`hallogallo-lead1-sketch.mid`, approved by Zack 2026-11-10), not
    /// the literal tab. The tab's Guitar 2 riff is A3 B3 F#4 F#4, then A3 B3 E4 E4: degrees 4 5 9 9
    /// answered by 4 5 1 1, the call ending open on the ninth and the answer ending home.
    static let hallogallo = HookRule(
        id: "MOT-LD1-023",
        call:   [[n(0, 5, 2, 84), n(2, 7, 2, 80), n(4, 14, 4, 88), n(8, 14, 8, 82)]],
        answer: [[n(0, 5, 2, 84), n(2, 7, 2, 80), n(4, 12, 4, 88), n(8, 12, 8, 82)]],
        sourceVariants: [
            // The answer ends on the fifth, so not every statement resolves.
            HookSourceVariant(answer: [[n(0, 5, 2, 84), n(2, 7, 2, 80), n(4, 7, 4, 88), n(8, 7, 8, 82)]]),
        ],
        // From the tab's riff 1 variation: the flat seventh as a grace into the root, in soft 8ths.
        tail: [n(0, 10, 2, 60), n(2, 12, 2, 66), n(4, 12, 2, 58),
               n(8, 10, 2, 58), n(10, 12, 2, 64), n(12, 12, 2, 56)],
        spacings: [12, 16, 8],
        spacingWeights: [0.40, 0.35, 0.25]
    )

    /// Radioactivity's key-synth riff (track "Key Synthesizer", 15 statements in the file): a
    /// pickup on the fifth below, rocking between root and fifth, then a turn through 3 2 1. The
    /// record alternates it with the same shape a third lower, so the plain answer is the riff
    /// moved down two scale steps. The vocal line (1 1 1 1 3 2 1) is the source variant answer.
    static let radioactive = HookRule(
        id: "MOT-LD1-024",
        call:   [[n(-1, -5, 1, 74), n(0, 0, 2, 88), n(2, 0, 1, 76), n(3, -5, 1, 72), n(4, 0, 1, 82),
                  n(5, -5, 2, 74), n(7, 0, 1, 78), n(8, 4, 2, 86), n(10, 2, 1, 80), n(11, 0, 4, 84)]],
        answer: [[n(-1, -5, 1, 74), n(0, 0, 2, 88), n(2, 0, 1, 76), n(3, -5, 1, 72), n(4, 0, 1, 82),
                  n(5, -5, 2, 74), n(7, 0, 1, 78), n(8, 4, 2, 86), n(10, 2, 1, 80), n(11, 0, 4, 84)]],
        answerShift: -2,
        sourceVariants: [
            HookSourceVariant(answer: [[n(0, 0, 2, 84), n(2, 0, 2, 76), n(4, 0, 3, 82), n(7, 0, 1, 76),
                                        n(8, 4, 2, 86), n(10, 2, 1, 80), n(11, 0, 4, 84)]]),
        ],
        spacings: [12, 16, 8],
        spacingWeights: [0.40, 0.35, 0.25]
    )

    /// The Model's synth riff (track "Synth 2"): a long held root, b3 2 1, then 2 b7 5 5. The
    /// vocal line has the same contour with a repeated-note start, and alternates with the riff
    /// on plain statements as the record does. The riff is complete on its own, so there is no
    /// separate answer.
    static let model = HookRule(
        id: "MOT-LD1-025",
        call: [[n(0, 0, 10, 86), n(10, 3, 2, 80), n(12, 2, 2, 78), n(14, 0, 2, 80)],
               [n(0, 2, 6, 84), n(6, -2, 2, 78), n(8, -5, 6, 82), n(14, -5, 2, 70)]],
        answer: [],
        restatement: [[n(-2, -5, 2, 74), n(0, 0, 2, 82), n(2, 0, 2, 76), n(4, 0, 2, 80), n(6, 0, 2, 76),
                       n(8, 0, 2, 80), n(10, 3, 2, 82), n(12, 2, 2, 78), n(14, 0, 2, 80)],
                      [n(0, 2, 6, 84), n(6, -2, 2, 78), n(8, -5, 8, 82)]],
        sourceVariants: [
            // A homage ending: the riff's second bar comes home to the root instead of the fifth.
            HookSourceVariant(call: [[n(0, 0, 10, 86), n(10, 3, 2, 80), n(12, 2, 2, 78), n(14, 0, 2, 80)],
                                     [n(0, 2, 6, 84), n(6, -2, 2, 78), n(8, 0, 8, 82)]]),
        ],
        spacings: [12, 16, 20],
        spacingWeights: [0.40, 0.40, 0.20]
    )

    /// Tour de France's guitar theme (track "guitar"): a rising call 5 1 2 5, then a two-bar
    /// answer 3 5 6 2 3 5 1 | b7 b3 1. The longest phrase of the four, so it states least often.
    static let tourDeFrance = HookRule(
        id: "MOT-LD1-026",
        call:   [[n(0, -5, 4, 84), n(4, 0, 2, 80), n(6, 2, 2, 82), n(8, 7, 6, 90)]],
        answer: [[n(-2, 4, 2, 78), n(0, 7, 2, 84), n(2, 9, 2, 86), n(4, 2, 2, 78), n(6, 4, 2, 80),
                  n(8, 7, 4, 86), n(12, 0, 4, 82)],
                 [n(0, -2, 4, 84), n(4, 3, 2, 80), n(6, 0, 8, 86)]],
        sourceVariants: [
            // A homage cadence: 4 3 1 in place of b7 b3 1.
            HookSourceVariant(answer: [[n(-2, 4, 2, 78), n(0, 7, 2, 84), n(2, 9, 2, 86), n(4, 2, 2, 78),
                                        n(6, 4, 2, 80), n(8, 7, 4, 86), n(12, 0, 4, 82)],
                                       [n(0, 5, 4, 84), n(4, 4, 2, 80), n(6, 0, 8, 86)]]),
        ],
        spacings: [16, 12, 20],
        spacingWeights: [0.45, 0.35, 0.20]
    )

    static let motorikRules: [String: HookRule] = Dictionary(
        uniqueKeysWithValues: [hallogallo, radioactive, model, tourDeFrance].map { ($0.id, $0) })

    static func isMotorikHookRule(_ id: String) -> Bool { motorikRules[id] != nil }

    // MARK: - Kosmic rule data

    /// Hooks sit in the Kosmic Lead 1 register, MIDI 56 to 84; the Pulstar line repeats an octave
    /// up, so it needs the room.
    static let kosmicRegister = RegisterBounds(low: 56, high: 84)
    /// Pulstar's line repeats an octave up and spans 19 semitones, so it takes more room below.
    static let pulstarRegister = RegisterBounds(low: 52, high: 84)

    /// Vangelis, Blade Runner End Titles, track 4 bars 13 to 26, stored as scale steps from the
    /// tonic. A four-bar unit: a whole note, two half notes and a two-bar hold, each note a scale
    /// step lower, then the unit again a step lower, twice. The third unit breaks the sequence and
    /// falls to the long low tonic. Phrases 2 and 3 are the answer, so the full statement is 12
    /// bars; the call alone is an open question that ends on the held fourth below.
    static let bladeRunner = HookRule(
        id: "KOS-LEAD-010",
        call: [[n(0, 0, 16, 72)],
               [n(0, -1, 8, 70), n(8, -2, 8, 68)],
               [n(0, -3, 32, 74)],
               []],
        answer: [[n(0, -1, 16, 70)],
                 [n(0, -2, 8, 68), n(8, -3, 8, 66)],
                 [n(0, -4, 32, 72)],
                 [],
                 [n(0, -2, 16, 68)],
                 [n(0, -3, 8, 66), n(8, -4, 8, 64)],
                 [n(0, -7, 24, 70)],
                 [n(8, -5, 4, 62), n(12, -7, 12, 72)]],
        sourceVariants: [
            // The cadence settles on the fifth below instead of the tonic.
            HookSourceVariant(answer: [[n(0, -1, 16, 70)],
                                       [n(0, -2, 8, 68), n(8, -3, 8, 66)],
                                       [n(0, -4, 32, 72)],
                                       [],
                                       [n(0, -2, 16, 68)],
                                       [n(0, -3, 8, 66), n(8, -4, 8, 64)],
                                       [n(0, -7, 24, 70)],
                                       [n(8, -5, 4, 62), n(12, -4, 12, 70)]]),
        ],
        spacings: [16, 20, 24],
        spacingWeights: [0.40, 0.35, 0.25],
        scaleSteps: true, gentle: true, homageWeights: [1, 0, 0, 0, 0],
        minStatements: 3, maxStatements: [3, 4], maxStatementWeights: [0.50, 0.50],
        formWeights: [0, 0, 0.25, 0.35, 0.40],
        sequenceUpChance: 0.0,
        register: kosmicRegister
    )

    /// Vangelis, Pulstar, the brass theme (channel 8, bars 119 to 134): a pickup F F F G into C,
    /// then four whole notes, one a bar, C Bb F G, said again an octave up. The pickup sits in the
    /// bar before the line. The variants hold the last note across two bars, or drop the pickup.
    static let pulstar = HookRule(
        id: "KOS-LEAD-011",
        call: [[n(-8, -7, 2, 70), n(-6, -7, 2, 72), n(-4, -7, 2, 74), n(-2, -5, 2, 78), n(0, 0, 16, 84)],
               [n(0, -2, 16, 78)],
               [n(0, -7, 16, 76)],
               [n(0, -5, 16, 74)]],
        answer: [[n(-8, -7, 2, 66), n(-6, -7, 2, 68), n(-4, -7, 2, 70), n(-2, -5, 2, 74), n(0, 0, 16, 80)],
                 [n(0, -2, 16, 74)],
                 [n(0, -7, 16, 72)],
                 [n(0, -5, 16, 70)]],
        answerShift: 7,
        sourceVariants: [
            // The line without its pickup, the first note entering on the bar.
            HookSourceVariant(call: [[n(0, 0, 16, 84)], [n(0, -2, 16, 78)], [n(0, -7, 16, 76)],
                                     [n(0, -5, 16, 74)]]),
            // The last note held across two bars.
            HookSourceVariant(answer: [[n(-8, -7, 2, 66), n(-6, -7, 2, 68), n(-4, -7, 2, 70),
                                        n(-2, -5, 2, 74), n(0, 0, 16, 80)],
                                       [n(0, -2, 16, 74)],
                                       [n(0, -7, 16, 72)],
                                       [n(0, -5, 32, 70)],
                                       []]),
        ],
        // 4 to 6 statements (Zack, 2026-11-10): three left long silences in a 118-bar body.
        // The shorter answer-only form, the octave-up half, is drawn more often than the others.
        spacings: [12, 14, 16],
        spacingWeights: [0.35, 0.40, 0.25],
        scaleSteps: false, gentle: true, homageWeights: [0, 0, 0, 0, 1],
        minStatements: 4, maxStatements: [4, 5, 6], maxStatementWeights: [0.35, 0.40, 0.25],
        formWeights: [0, 0, 0.35, 0.20, 0.45],
        register: pulstarRegister
    )

    /// Tangerine Dream, Beach Scene, the guitar sigh (bars 51 to 66): the root slips to the
    /// seventh, repeats and sinks to the sixth, then rising arpeggios on IV and V land on the
    /// root. The variant call falls to the fifth before rising to the sixth.
    static let beachScene = HookRule(
        id: "KOS-LEAD-012",
        call: [[n(0, 0, 2, 70), n(2, -1, 4, 72), n(6, -1, 6, 70), n(12, -1, 4, 72)],
               [n(0, -1, 4, 72), n(4, -3, 28, 76)],
               []],
        answer: [[n(0, -12, 2, 66), n(2, -7, 2, 68), n(4, -3, 4, 72), n(8, -10, 2, 66),
                  n(10, -5, 2, 68), n(12, -1, 4, 74)],
                 [n(0, 0, 12, 78)]],
        sourceVariants: [
            HookSourceVariant(call: [[n(0, 0, 2, 70), n(2, -1, 4, 72), n(6, -5, 6, 70), n(12, -5, 4, 72)],
                                     [n(0, -5, 4, 72), n(4, -3, 28, 76)],
                                     []]),
        ],
        spacings: [8, 12, 16],
        spacingWeights: [0.35, 0.40, 0.25],
        gentle: true, homageWeights: [0.25, 0.20, 0.10, 0.20, 0.25],
        minStatements: 3, maxStatements: [3, 4, 5], maxStatementWeights: [0.25, 0.40, 0.35],
        formWeights: [0, 0, 0.25, 0.30, 0.45],
        register: kosmicRegister
    )

    static let kosmicRules: [String: HookRule] = Dictionary(
        uniqueKeysWithValues: [bladeRunner, pulstar, beachScene].map { ($0.id, $0) })

    static func isKosmicHookRule(_ id: String) -> Bool { kosmicRules[id] != nil }

    // MARK: - Homage

    private struct FlatNote { var at: Int; var deg: Int; var len: Int; var vel: Int }

    private static func flatten(_ bars: [HookBar]) -> [FlatNote] {
        bars.enumerated().flatMap { bi, bar in
            bar.map { FlatNote(at: bi * 16 + $0.step, deg: $0.deg, len: $0.len, vel: $0.vel) }
        }.sorted { $0.at < $1.at }
    }

    private static func regroup(_ notes: [FlatNote], barCount: Int) -> [HookBar] {
        var bars = [HookBar](repeating: [], count: barCount)
        for f in notes {
            let bi = Swift.min(barCount - 1, Swift.max(0, f.at >= 0 ? f.at / 16 : 0))
            bars[bi].append(HookNote(step: f.at - bi * 16, deg: f.deg, len: f.len, vel: f.vel))
        }
        return bars
    }

    private enum HomageOp: CaseIterable { case addPassing, dropNote, moveOnset, swapPair, neighbour }
    private static let homageWeights: [Double] = [0.25, 0.20, 0.25, 0.15, 0.15]

    /// Reworks a cell with `count` distinct changes. The first note and the last note never
    /// change, so the shape that makes the hook recognisable survives every version.
    static func homage(_ bars: [HookBar], count: Int, unit: Int = 2, weights: [Double]? = nil,
                       rng: inout SeededRNG) -> [HookBar] {
        guard !bars.isEmpty else { return bars }
        var notes = flatten(bars)
        guard notes.count >= 3 else { return bars }
        var used: Set<Int> = []
        var attempts = 0
        while used.count < count && attempts < 12 {
            attempts += 1
            let opIndex = rng.weightedPick(weights ?? homageWeights)
            guard !used.contains(opIndex) else { continue }
            let last = notes.count - 1
            var applied = false
            switch HomageOp.allCases[opIndex] {
            case .addPassing:
                // Fill a gap of a quarter note or more with a note between its neighbours, or a
                // neighbour tone when they share a pitch.
                let slots = (0..<last).filter { notes[$0 + 1].at - notes[$0].at >= 4 }
                if !slots.isEmpty {
                    let i = slots[rng.nextInt(upperBound: slots.count)]
                    let a = notes[i], b = notes[i + 1]
                    let diff = b.deg - a.deg
                    // A scale-step cell takes the upper neighbour when it falls, so the new note never doubles
                    // the one that follows; semitone cells keep the random neighbour.
                    let deg = abs(diff) >= unit + 1 ? a.deg + diff / 2
                        : unit == 1 && diff != 0 ? a.deg + (diff < 0 ? 1 : -1)
                        : a.deg + (rng.nextDouble() < 0.5 ? unit : -unit)
                    // On the 8th-note grid, so it sits with the hats; a gap with no 8th between
                    // its neighbours takes no passing note.
                    var at = ((a.at + (b.at - a.at) / 2) / 2) * 2
                    if at <= a.at { at += 2 }
                    if at < b.at && at % 2 == 0 {
                        notes.insert(FlatNote(at: at, deg: deg, len: b.at - at,
                                              vel: Swift.max(40, Swift.min(a.vel, b.vel) - 6)), at: i + 1)
                        applied = true
                    }
                }
            case .dropNote:
                if notes.count >= 5 {
                    notes.remove(at: 1 + rng.nextInt(upperBound: notes.count - 2))
                    applied = true
                }
            case .moveOnset:
                // Move an off-beat 8th onto the beat before or after it, inside its bar and
                // without touching its neighbours. Notes already on a beat never move and nothing
                // lands on an odd step, so a variation still fits the strong beats of the drums.
                let deltas = [-2, 2]
                var options: [(Int, Int)] = []
                for i in 1..<last where notes[i].at % 4 == 2 {
                    for d in deltas {
                        let at = notes[i].at + d
                        let sameBar = (at >= 0 ? at / 16 : -1) == (notes[i].at >= 0 ? notes[i].at / 16 : -1)
                        if sameBar && at > notes[i - 1].at && at < notes[i + 1].at { options.append((i, d)) }
                    }
                }
                if !options.isEmpty {
                    let (i, d) = options[rng.nextInt(upperBound: options.count)]
                    notes[i].at += d
                    applied = true
                }
            case .swapPair:
                let pairs = (1..<Swift.max(1, last - 1)).filter { notes[$0].deg != notes[$0 + 1].deg }
                if !pairs.isEmpty {
                    let i = pairs[rng.nextInt(upperBound: pairs.count)]
                    let d = notes[i].deg
                    notes[i].deg = notes[i + 1].deg
                    notes[i + 1].deg = d
                    applied = true
                }
            case .neighbour:
                let repeats = (1..<last).filter { notes[$0].deg == notes[$0 - 1].deg }
                if !repeats.isEmpty {
                    let i = repeats[rng.nextInt(upperBound: repeats.count)]
                    notes[i].deg += rng.nextDouble() < 0.6 ? unit : -unit
                    applied = true
                }
            }
            if applied { used.insert(opIndex) }
        }
        return regroup(notes, barCount: bars.count)
    }

    /// This song's version of the rule: every cell reworked by the seed.
    private static func songVersion(of rule: HookRule, rng: inout SeededRNG) -> HookRule {
        var r = rule
        let unit = rule.scaleSteps ? 1 : 2
        // A gentle rule changes one note per cell; the draws are the same either way.
        func count(_ twoOrThree: Int, _ oneOrTwo: Int) -> Int { rule.gentle ? 1 : twoOrThree }
        r.call = homage(rule.call, count: count(rng.nextDouble() < 0.6 ? 2 : 3, 1), unit: unit, weights: rule.homageWeights, rng: &rng)
        r.answer = homage(rule.answer, count: count(rng.nextDouble() < 0.5 ? 1 : 2, 1), unit: unit, weights: rule.homageWeights, rng: &rng)
        if let re = rule.restatement {
            r.restatement = homage(re, count: count(rng.nextDouble() < 0.5 ? 1 : 2, 1), unit: unit, weights: rule.homageWeights, rng: &rng)
        }
        r.sourceVariants = rule.sourceVariants.map { v in
            var out = v
            if let c = v.call { out.call = homage(c, count: 1, unit: unit, weights: rule.homageWeights, rng: &rng) }
            if let a = v.answer { out.answer = homage(a, count: 1, unit: unit, weights: rule.homageWeights, rng: &rng) }
            return out
        }
        return r
    }

    // MARK: - Statement

    private enum Variation: CaseIterable { case dropNote, stepUp, holdOver, withhold }
    // Drop a note 35, call a step up as a sequence 30, hold the last note over the next bar 20,
    // withhold the answer 15. There is no push: a statement shifted a 16th late drifts off the
    // drums, which sit on the 8th-note grid with the kick and snare on the beats.
    private static let variationWeights: [Double] = [0.35, 0.30, 0.20, 0.15]

    private struct Statement {
        var startBar: Int
        var bars: [HookBar]
        /// Scale steps for each bar, parallel to `bars`.
        var barShift: [Int]
        var callCount: Int
        /// Scale steps applied to the whole statement (B sections).
        var shift = 0
        var velOffset = 0
        var ringSteps = 0
        /// Bars the statement occupies, counting a held last note that rings into the next bar.
        var spanBars: Int { bars.count + (ringSteps > 0 ? 1 : 0) }
        var endBar: Int { startBar + spanBars }
    }

    // MARK: - Generation

    /// Generates the whole Lead 1 part for a hook rule. The caller has already drawn the entry
    /// bar and the rest windows, so those keep their place in the Lead 1 stream; every draw made
    /// here comes from a derived stream.
    static func generate(
        rule source: HookRule,
        frame: GlobalMusicalFrame,
        structure: SongStructure,
        tonalMap: TonalGovernanceMap,
        entryBar: Int,
        restBars: Set<Int>,
        register: RegisterBounds,
        rng: inout SeededRNG
    ) -> [MIDIEvent] {
        var r = SeededRNG(seed: rng.next() ^ 0x484F_4F4B_4C45_4144)   // "HOOKLEAD"
        let register = source.register ?? register
        var rule = songVersion(of: source, rng: &r)
        let tonicPC = ((frame.keySemitoneValue % 12) + 12) % 12
        guard let bodyEnd = structure.bodySections.map(\.endBar).max() else { return [] }

        // A rule that repeats itself an octave up needs room for both; in a key that has none, the
        // repeat comes down to a fifth, then to the same octave, rather than folding notes.
        while rule.answerShift > 4 && anchorCandidate(rule: rule, tonicPC: tonicPC, register: register) == nil {
            rule.answerShift = 4
            if anchorCandidate(rule: rule, tonicPC: tonicPC, register: register) == nil { rule.answerShift = 0 }
        }
        let base = anchorTonic(rule: rule, tonicPC: tonicPC, register: register)

        func plain(_ index: Int) -> Statement {
            let call = (index % 2 == 1 ? rule.restatement : nil) ?? rule.call
            return Statement(startBar: 0, bars: call + rule.answer,
                             barShift: Array(repeating: 0, count: call.count)
                                 + Array(repeating: rule.answerShift, count: rule.answer.count),
                             callCount: call.count)
        }
        let plainLen = plain(0).bars.count

        func isBody(_ bar: Int) -> Bool {
            guard let label = structure.section(atBar: bar)?.label else { return false }
            return label == .A || label == .B
        }
        func isFree(_ bar: Int) -> Bool {
            bar >= entryBar && bar < bodyEnd && isBody(bar) && !restBars.contains(bar)
        }

        // B sections restate the hook a scale step or a third up, or lean on the variants.
        let bRoll  = r.nextDouble()
        let bShift = bRoll < 0.40 ? 1 : bRoll < 0.70 ? 2 : 0

        func vary(_ st: inout Statement, moreVariants: Bool) {
            // One varied statement in five returns to form instead.
            if !moreVariants && r.nextDouble() < 0.20 { return }
            let count = r.nextDouble() < 0.30 ? 2 : 1
            var kinds: [Variation] = []
            var usedSource = false
            for _ in 0..<count {
                if !rule.sourceVariants.isEmpty && !usedSource
                    && r.nextDouble() < (moreVariants ? 0.70 : 0.50) {
                    usedSource = true
                    let v = rule.sourceVariants[r.nextInt(upperBound: rule.sourceVariants.count)]
                    if let call = v.call {
                        st.bars.replaceSubrange(0..<st.callCount, with: call)
                        st.barShift.replaceSubrange(0..<st.callCount, with: Array(repeating: 0, count: call.count))
                        st.callCount = call.count
                    }
                    if let answer = v.answer {
                        st.bars = Array(st.bars.prefix(st.callCount)) + answer
                        st.barShift = Array(st.barShift.prefix(st.callCount)) + Array(repeating: 0, count: answer.count)
                    }
                    continue
                }
                let k = Variation.allCases[r.weightedPick(variationWeights)]
                if !kinds.contains(k) { kinds.append(k) }
            }
            if kinds.contains(.stepUp) {
                let calls = Array(st.bars.prefix(st.callCount))
                st.bars.insert(contentsOf: calls, at: st.callCount)
                st.barShift.insert(contentsOf: st.barShift.prefix(st.callCount).map { $0 + (rule.sequenceUpChance < 0.5 ? -1 : 1) }, at: st.callCount)
                st.callCount *= 2
            }
            // Withholding the answer leaves the question open; pointless if a variant just
            // rewrote that answer.
            if kinds.contains(.withhold) && !usedSource && st.bars.count > st.callCount {
                st.bars = Array(st.bars.prefix(st.callCount))
                st.barShift = Array(st.barShift.prefix(st.callCount))
            }
            if kinds.contains(.dropNote) {
                // Never the first note or the held last note of a bar.
                let candidates = (0..<st.callCount).filter { st.bars[$0].count >= 3 }
                if !candidates.isEmpty {
                    let b = candidates[r.nextInt(upperBound: candidates.count)]
                    st.bars[b].remove(at: 1 + r.nextInt(upperBound: st.bars[b].count - 2))
                }
            }
            if kinds.contains(.holdOver) { st.ringSteps = 16 }
        }

        // Forms a statement can take. The full cell is the original form; the others are real
        // variations of it, not tweaks: the head alone, the head said twice, the answer alone, or
        // the call as a sequence a step away.
        enum Form: CaseIterable { case head, loop, answerOnly, sequence, varied }
        let formWeights: [Double] = rule.formWeights ?? [0.28, 0.17, 0.15, 0.15, 0.25]

        /// The first half of a bar, ending on an even step, with the last note held. If cutting
        /// would leave fewer than two notes the whole bar is the head.
        func headBar(_ bar: HookBar) -> HookBar {
            var out = bar.filter { $0.step < 8 }
            while out.count > 2, let l = out.last, l.step % 2 != 0 { out.removeLast() }
            if out.count < 2 { return bar }
            out[out.count - 1].len = Swift.max(out[out.count - 1].len, Swift.min(8, 16 - out[out.count - 1].step))
            return out
        }

        func build(_ form: Form, index: Int) -> Statement {
            let call = (index % 2 == 1 ? rule.restatement : nil) ?? rule.call
            switch form {
            case .head:
                return Statement(startBar: 0, bars: [headBar(call[0])], barShift: [0], callCount: 1)
            case .loop:
                // The head said twice in one bar, the second time with the last note held. Only
                // when the cut actually shortened the bar; otherwise it is just the head.
                let head = headBar(call[0])
                guard head.count < call[0].count, head.allSatisfy({ $0.step < 8 }) else {
                    return Statement(startBar: 0, bars: [head], barShift: [0], callCount: 1)
                }
                let second = head.filter { $0.step >= 0 }.map { HookNote(step: $0.step + 8, deg: $0.deg, len: $0.len, vel: $0.vel - 4) }
                return Statement(startBar: 0, bars: [head + second], barShift: [0], callCount: 1)
            case .answerOnly:
                if rule.answer.isEmpty {
                    return Statement(startBar: 0, bars: [call[call.count - 1]], barShift: [0], callCount: 1)
                }
                var bars = rule.answer
                bars[0] = bars[0].filter { $0.step >= 0 }      // a pickup would land in the bar before
                return Statement(startBar: 0, bars: bars,
                                 barShift: Array(repeating: rule.answerShift, count: bars.count), callCount: 0)
            case .sequence:
                var st = plain(index)
                let up = r.nextDouble() < rule.sequenceUpChance ? 1 : -1
                st.bars.insert(contentsOf: Array(st.bars.prefix(st.callCount)), at: st.callCount)
                st.barShift.insert(contentsOf: st.barShift.prefix(st.callCount).map { $0 + up }, at: st.callCount)
                st.callCount *= 2
                return st
            case .varied:
                var st = plain(index)
                vary(&st, moreVariants: true)
                return st
            }
        }

        // Lay out the body statements. The first is the full hook, so it is learned before it
        // moves; after a varied statement the original form returns about 45% of the time.
        var statements: [Statement] = []
        var bar = entryBar
        var previousVaried = false
        while bar < bodyEnd {
            let index = statements.count
            var st = plain(index)
            var varied = false
            if index >= 1, !(index == 1 && r.nextDouble() < 0.50), !(previousVaried && r.nextDouble() < 0.45) {
                st = build(Form.allCases[r.weightedPick(formWeights)], index: index)
                varied = true
            }
            st.startBar = bar
            if structure.section(atBar: bar)?.label == .B { st.shift = bShift }
            guard (st.startBar..<st.endBar).allSatisfy(isFree) else {
                bar += 2      // stay on the two-bar grid from the entry
                continue
            }
            statements.append(st)
            previousVaried = varied
            let spacing = rule.spacings[r.weightedPick(rule.spacingWeights)]
            bar = Swift.max(bar + spacing, st.endBar + 1)
        }

        // The hook is never missing from the last third of the song, and the last fifth plays it
        // plain once more. Both go on the two-bar grid from the entry, in the first free slot, so
        // a rest window or a breakdown can't swallow them.
        func placePlain(from start: Int) -> Statement? {
            var at = Swift.max(start, entryBar)
            if (at - entryBar) % 2 != 0 { at += 1 }
            while at + plainLen <= bodyEnd {
                var st = plain(0)
                st.startBar = at
                if (st.startBar..<st.endBar).allSatisfy(isFree) { return st }
                at += 2
            }
            return nil
        }
        let thirdStart = frame.totalBars * 2 / 3
        if !statements.contains(where: { $0.startBar >= thirdStart }),
           let st = placePlain(from: Swift.max(thirdStart, (statements.last?.endBar ?? entryBar) + 1)) {
            statements.append(st)
        }
        let lateStart = Swift.max(entryBar, frame.totalBars * 4 / 5)
        if statements.last.map({ $0.startBar < lateStart }) ?? true,
           let st = placePlain(from: Swift.max(lateStart, statements.last?.endBar ?? entryBar)) {
            statements.append(st)
        }
        // A song states its hook 3 to 5 times in the body. Over the cap, the statement whose
        // neighbours are closest goes, never the first, the last or the only one in the last
        // third. Under three, the biggest gap takes a statement near its middle.
        // The cap is drawn per song so the count spreads across 3, 4 and 5 (20, 40 and 40%).
        let maxBody = rule.maxStatements[r.weightedPick(rule.maxStatementWeights)]
        while statements.count > maxBody {
            let onlyLate = statements.filter { $0.startBar >= thirdStart }.count == 1
            var best: Int? = nil
            var bestGap = Int.max
            for i in 1..<(statements.count - 1) {
                if onlyLate && statements[i].startBar >= thirdStart { continue }
                let gap = statements[i + 1].startBar - statements[i - 1].startBar
                if gap < bestGap { bestGap = gap; best = i }
            }
            guard let b = best else { break }
            statements.remove(at: b)
        }
        while statements.count < rule.minStatements && statements.count >= 1 {
            var gapAt = 0
            var gapSize = 0
            for i in 0..<(statements.count - 1) {
                let g = statements[i + 1].startBar - statements[i].endBar
                if g > gapSize { gapSize = g; gapAt = i }
            }
            var placed: Statement? = nil
            if statements.count >= 2 {
                let lo = statements[gapAt].endBar + 1
                let hi = statements[gapAt + 1].startBar - plainLen - 1
                let mid = (lo + hi) / 2
                let candidates = (lo...Swift.max(lo, hi)).filter { ($0 - entryBar) % 2 == 0 && $0 <= hi }
                    .sorted { abs($0 - mid) < abs($1 - mid) }
                for at in candidates {
                    var st = build(Form.allCases[r.weightedPick(formWeights)], index: gapAt + 1)
                    st.startBar = at
                    if (st.startBar..<st.endBar).allSatisfy(isFree) { placed = st; break }
                }
            }
            guard let st = placed else { break }
            statements.insert(st, at: gapAt + 1)
        }
        if let i = statements.indices.last {
            var final = plain(0)
            final.startBar = statements[i].startBar
            let next = final.startBar + final.bars.count
            // Ring through the following bar when nothing else wants it.
            if next < frame.totalBars && (next >= bodyEnd || isFree(next)) { final.ringSteps = 16 }
            statements[i] = final
        }

        // Outro: at most one soft plain statement, so a song never states the hook more than 6 times.
        var outroStatement: Statement? = nil
        if let outro = structure.outroSection, outro.lengthBars >= plainLen + 1, r.nextDouble() < 0.30 {
            var st = plain(0)
            st.startBar = outro.startBar
            st.velOffset = -18
            if let last = statements.last, last.endBar > st.startBar { statements[statements.count - 1].ringSteps = 0 }
            outroStatement = st
        }

        var events: [MIDIEvent] = []
        for (i, st) in statements.enumerated() {
            events += realise(st, base: base, tonicPC: tonicPC, structure: structure,
                              tonalMap: tonalMap, register: register, scaleSteps: rule.scaleSteps, rng: &r)
            // The bar after a statement: silence, or about three times in ten the tail.
            guard let tail = rule.tail else { continue }
            let tailBar = st.endBar
            let nextStart = i + 1 < statements.count ? statements[i + 1].startBar : bodyEnd
            if i + 1 < statements.count, tailBar < nextStart, isFree(tailBar), r.nextDouble() < 0.30 {
                let t = Statement(startBar: tailBar, bars: [tail], barShift: [0], callCount: 1)
                events += realise(t, base: base, tonicPC: tonicPC, structure: structure,
                                  tonalMap: tonalMap, register: register, legato: false,
                                  scaleSteps: rule.scaleSteps, rng: &r)
            }
        }
        if let st = outroStatement {
            events += realise(st, base: base, tonicPC: tonicPC, structure: structure,
                              tonalMap: tonalMap, register: register, scaleSteps: rule.scaleSteps, rng: &r)
        }
        return events.filter { $0.stepIndex >= 0 && $0.stepIndex < frame.totalBars * 16 }
    }

    // MARK: - Fitting

    /// The MIDI note of the song tonic that the hook is built on, chosen once per song so the
    /// figure stays in one octave. Headroom covers a step-up, a third-up in B, and a shifted
    /// answer.
    private static func anchorTonic(rule: HookRule, tonicPC: Int, register: RegisterBounds) -> Int {
        if let best = anchorCandidate(rule: rule, tonicPC: tonicPC, register: register) { return best }
        let (lo, _) = anchorSpan(rule)
        var t = tonicPC
        while t + lo < register.low { t += 12 }
        return t
    }

    /// The span in semitones the rule's cells cover from the tonic, with headroom.
    private static func anchorSpan(_ rule: HookRule) -> (lo: Int, hi: Int) {
        var cells = rule.call + rule.answer + (rule.restatement ?? [])
        if let t = rule.tail { cells.append(t) }
        for v in rule.sourceVariants { cells += (v.call ?? []) + (v.answer ?? []) }
        // A scale step is about 12/7 of a semitone.
        let degs = cells.flatMap { $0 }.map { rule.scaleSteps ? Int((Double($0.deg) * 12 / 7).rounded()) : $0.deg }
        // Up to two steps the headroom is the old four semitones; a bigger shift, an octave say,
        // takes its own size.
        let shiftSemis = abs(rule.answerShift) <= 2 ? rule.answerShift * 2
            : Int((Double(rule.answerShift) * 12 / 7).rounded())
        let lo = (degs.min() ?? 0) - (rule.answerShift < 0 ? -Swift.min(shiftSemis, 0) : 0)
        let hi = (degs.max() ?? 0) + 3 + (rule.answerShift > 0 ? shiftSemis : 0)
        return (lo, hi)
    }

    /// The tonic that puts the whole span inside `register`, nearest a little below its middle, or
    /// nil if no octave of the tonic does.
    private static func anchorCandidate(rule: HookRule, tonicPC: Int, register: RegisterBounds) -> Int? {
        let (lo, hi) = anchorSpan(rule)
        let target = Double(register.low + register.high) / 2 - 2      // a little below the middle
        let candidates = stride(from: tonicPC, through: 127, by: 12)
            .filter { $0 + lo >= register.low && $0 + hi <= register.high }
        return candidates.min(by: {
            abs(Double($0) + Double(lo + hi) / 2 - target) < abs(Double($1) + Double(lo + hi) / 2 - target)
        })
    }

    static func scalePCs(_ mode: Mode, tonicPC: Int) -> Set<Int> {
        Set(mode.intervals.map { (tonicPC + $0) % 12 })
    }

    /// Source semitone to scale-degree index for seven-note modes: a major or minor third is the
    /// third, a flat or natural seventh is the seventh, so a source in any key keeps its contour.
    private static let degreeIndex = [0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6]

    /// The song pitch for a source degree. Seven-note modes map by scale degree; pentatonic
    /// modes snap to the nearest scale pitch, with ties going up.
    static func pitch(for deg: Int, base: Int, mode: Mode, scale: Set<Int>) -> Int {
        let intervals = mode.intervals
        if intervals.count == 7 {
            let oct = deg >= 0 ? deg / 12 : -((-deg + 11) / 12)
            let within = deg - oct * 12
            return base + oct * 12 + intervals[degreeIndex[within]]
        }
        return snap(base + deg, to: scale)
    }

    private static func snap(_ pitch: Int, to scale: Set<Int>) -> Int {
        let pc = ((pitch % 12) + 12) % 12
        if scale.isEmpty || scale.contains(pc) { return pitch }
        for d in 1...6 {
            if scale.contains((pc + d) % 12) { return pitch + d }
            if scale.contains((pc - d + 12) % 12) { return pitch - d }
        }
        return pitch
    }

    /// Moves a scale pitch by `steps` scale steps.
    static func scaleShift(_ pitch: Int, by steps: Int, in scale: Set<Int>) -> Int {
        guard !scale.isEmpty, steps != 0 else { return pitch }
        var p = pitch
        for _ in 0..<abs(steps) {
            repeat { p += steps > 0 ? 1 : -1 } while !scale.contains(((p % 12) + 12) % 12)
        }
        return p
    }

    private static func realise(
        _ st: Statement, base: Int, tonicPC: Int,
        structure: SongStructure, tonalMap: TonalGovernanceMap,
        register: RegisterBounds, legato: Bool = true, scaleSteps: Bool = false, rng: inout SeededRNG
    ) -> [MIDIEvent] {
        struct Placed { var step: Int; var pitch: Int; var len: Int; var vel: Int; let bar: Int }
        var notes: [Placed] = []
        for (bi, barNotes) in st.bars.enumerated() {
            let barIdx = st.startBar + bi
            guard let entry = tonalMap.entry(atBar: barIdx) else { continue }
            let scale = scalePCs(entry.sectionMode, tonicPC: tonicPC)
            let shift = st.shift + (bi < st.barShift.count ? st.barShift[bi] : 0)
            for n in barNotes {
                // A scale-step rule moves from the tonic by steps; the others map a semitone.
                let p = scaleSteps
                    ? scaleShift(base, by: n.deg + shift, in: scale)
                    : scaleShift(pitch(for: n.deg, base: base, mode: entry.sectionMode, scale: scale),
                                 by: shift, in: scale)
                notes.append(Placed(step: barIdx * 16 + n.step, pitch: p,
                                    len: n.len, vel: n.vel, bar: barIdx))
            }
        }
        guard !notes.isEmpty else { return [] }
        notes.sort { $0.step < $1.step }
        // Two notes on one step: keep the first.
        notes = notes.enumerated().filter { i, n in i == 0 || n.step != notes[i - 1].step }.map(\.element)

        // Hold each note to the next onset inside a phrase; short transcribed notes sound
        // clunky on synth leads. The last note keeps its own length, plus any ring.
        for i in notes.indices {
            if i + 1 < notes.count {
                let gap = notes[i + 1].step - notes[i].step
                if legato && gap <= 8 { notes[i].len = gap } else { notes[i].len = Swift.min(notes[i].len, gap) }
            } else {
                notes[i].len += st.ringSteps
            }
        }

        // Keep the whole statement in one octave band: move it as a block first, and fold a
        // single note only if the block can't fit. Decided on the cell as written, so a chord
        // adjustment below can't drag the whole statement into another octave.
        let lo = notes.map(\.pitch).min()!, hi = notes.map(\.pitch).max()!
        var blockShift = 0
        if hi > register.high && lo - 12 >= register.low { blockShift = -12 }
        else if lo < register.low && hi + 12 <= register.high { blockShift = 12 }

        // A held note that is an avoid tone over the current chord moves to the nearest chord
        // tone, the other way if the nearer one leaves the register. Passing notes keep their
        // pitch.
        for i in notes.indices where notes[i].len >= 4 {
            guard let window = tonalMap.entry(atBar: notes[i].bar)?.chordWindow else { continue }
            let pc = ((notes[i].pitch % 12) + 12) % 12
            guard window.avoidTones.contains(pc), !window.chordTones.isEmpty else { continue }
            let target = nearestScalePitchClass(pc, in: window.chordTones)
            var delta = ((target - pc) + 18) % 12 - 6
            let moved = notes[i].pitch + delta + blockShift
            if moved < register.low || moved > register.high { delta += delta < 0 ? 12 : -12 }
            notes[i].pitch += delta
        }

        return notes.map { n in
            let pitch = register.fold(n.pitch + blockShift)
            let intensity = structure.section(atBar: n.bar)?.subPhaseIntensity(atBar: n.bar) ?? .medium
            let lift = intensity == .low ? -6 : intensity == .high ? 5 : 0
            let vel = n.vel + st.velOffset + lift + rng.nextInt(upperBound: 7) - 3
            return MIDIEvent(stepIndex: n.step, note: UInt8(pitch),
                             velocity: UInt8(Swift.max(30, Swift.min(120, vel))),
                             durationSteps: Swift.max(1, n.len))
        }
    }
}
