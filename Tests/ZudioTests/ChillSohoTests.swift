// ChillSohoTests.swift — Chill Soho activation, persistence and the first measured rules.
//
// Run with:
//   swift test --filter ChillSohoTests
//
// What these guard, and why each matters, is in docs/chill-soho-plan.md. In short:
//   - Soho is rolled on a DERIVED stream, so base Chill and Blues must be untouched. That was
//     proven across 600 seeds by diffing builds; these tests guard the properties that make it
//     true (mutual exclusion, and forcing being draw-neutral).
//   - The four rules in this slice are checked against the numbers they were MEASURED to,
//     not against whatever the code happens to produce.

import Testing
import Foundation
@testable import Zudio

@Suite struct ChillSohoTests {

    private static let seeds = UInt64(1)...400

    private static func sohoSongs() -> [SongState] {
        seeds.map { SongGenerator.generate(seed: $0, style: .chill) }.filter { $0.chillSohoVariation }
    }

    /// True when the song's generation log lists the rule.
    private static func uses(_ s: SongState, _ ruleID: String) -> Bool {
        s.generationLog.contains { $0.tag == ruleID }
    }

    /// Bars that belong to the groove (A or B), where the rules play at full strength.
    /// The bar before a Remix Break, where the band stops and hits beats 3 and 4 together.
    /// Not part of the groove for the purposes of any groove measurement.
    private static func remixEntry(_ s: SongState) -> Set<Int> {
        ChillStructureGenerator.remixEntryBars(structure: s.structure,
                                               breakdownStyle: s.chillBreakdownStyle)
    }

    /// Bars where the groove proper is playing. A cold start makes bar 0 a drums-only pickup, and
    /// since Soho songs may now open with no intro at all, that bar can fall inside section A —
    /// it is a way in, not a bar of the groove, so no groove measurement should read it.
    /// All four bars of each turnaround, and separately the last bar of each. On the exit bar the
    /// bass re-pitches its figure into a lead-in and the drums take a fill, so it is not a bar of
    /// the groove for measurement purposes.
    private static func turnaroundBars(_ s: SongState) -> Set<Int> {
        ChillStructureGenerator.sohoTurnaroundBars(frame: s.frame, structure: s.structure)
    }

    private static func turnaroundExit(_ s: SongState) -> Set<Int> {
        let t = turnaroundBars(s)
        return t.filter { !t.contains($0 + 1) }
    }

    /// The turnaround's last two bars, where the bass stops playing the groove and plays a
    /// turnaround. No groove measurement should read these.
    private static func turnaroundTreated(_ s: SongState) -> Set<Int> {
        let t = turnaroundBars(s)
        return Set(turnaroundExit(s).flatMap { [$0 - 1, $0] }).intersection(t)
    }

    private static func grooveBars(_ s: SongState) -> [Int] {
        var coldStartBar = -1
        if case .coldStart = s.structure.introStyle { coldStartBar = 0 }
        return s.structure.sections
            .filter { $0.label == .A || $0.label == .B }
            .flatMap { $0.startBar..<($0.startBar + $0.lengthBars) }
            .filter { $0 != coldStartBar }
    }

    // MARK: - Activation

    /// Reads the activation constant, so moving between the testing (80%) and release (20%)
    /// weights needs no edit here.
    @Test func activatesAtTheConfiguredShare() {
        let n = Self.sohoSongs().count
        let pct = 100.0 * Double(n) / Double(Self.seeds.count)
        let target = 80.0 * ChillMusicalFrameGenerator.sohoShareOfNonBlues   // Blues keeps 20%
        #expect(abs(pct - target) < 6, "Soho fired on \(pct)% of Chill seeds; target \(target)%")
    }

    @Test func neverBothSohoAndBlues() {
        for seed in Self.seeds {
            let s = SongGenerator.generate(seed: seed, style: .chill)
            #expect(!(s.chillSohoVariation && s.chillBluesVariation), "seed \(seed) is both")
        }
    }

    @Test func sohoUsesItsOwnGrooveAndTempoBand() {
        for s in Self.sohoSongs() {
            #expect(s.chillBeatStyle.isSoho, "Soho song with non-Soho groove \(s.chillBeatStyle)")
            #expect((84...128).contains(s.frame.tempo), "tempo \(s.frame.tempo) outside 84-128")
            #expect(s.displayStyleName == "Chill Soho")
        }
    }

    @Test func nonSohoNeverGetsASohoGroove() {
        for seed in Self.seeds {
            let s = SongGenerator.generate(seed: seed, style: .chill)
            if !s.chillSohoVariation {
                #expect(!s.chillBeatStyle.isSoho, "seed \(seed): base Chill with a Soho groove")
            }
        }
    }

    /// The Chords line gives the chords only — never the record a cycle was measured from — and
    /// marks a held chord "×n" so the modal cycle cannot be mistaken for a one-bar alternation.
    @Test func chordsLineNamesNoSong() {
        var sawHeld = false
        for s in Self.sohoSongs() {
            guard let line = s.generationLog.first(where: { $0.tag == "Chords" })?.description else {
                Issue.record("Soho song with no Chords line"); continue
            }
            #expect(!line.contains("("), "Chords line names a source: \(line)")
            if line.contains("×") { sawHeld = true }
        }
        #expect(sawHeld, "no modal (held-chord) cycle appeared in range")
    }

    // MARK: - Persistence

    /// The loader replays the flag as `forceSohoVariation: true`. Because Soho is decided on a
    /// derived stream, forcing it must consume no main-stream draws — so a forced regeneration
    /// has to be identical to the original. (Blues does not have this property: its
    /// `force || rng.nextDouble()` short-circuit skips a draw when forced.)
    @Test func forcingSohoIsDrawNeutral() {
        var checked = 0
        for seed in Self.seeds {
            let natural = SongGenerator.generate(seed: seed, style: .chill)
            guard natural.chillSohoVariation else { continue }
            let forced = SongGenerator.generate(seed: seed, style: .chill, forceSohoVariation: true)
            #expect(natural.trackEvents == forced.trackEvents, "seed \(seed) differs when forced")
            #expect(natural.frame.tempo == forced.frame.tempo)
            checked += 1
            if checked >= 25 { break }
        }
        #expect(checked > 0)
    }

    @Test func exportWritesTheSohoLine() throws {
        guard let s = Self.sohoSongs().first else { Issue.record("no Soho song in range"); return }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("soho-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let midi = dir.appendingPathComponent("song.mid")
        try SongLogExporter.export(s, midiURL: midi)
        let text = try String(contentsOf: midi.deletingPathExtension().appendingPathExtension("zudio"),
                              encoding: .utf8)
        #expect(text.contains("Soho Variation:"))
        // Style: must stay the bare MusicStyle rawValue or the loader cannot parse it.
        #expect(!text.contains("Style:          Chill Soho"))
    }

    // MARK: - Bass, measured

    /// CHL-BASS-013 — measured from Smooth Operator at 4-6 notes a bar, short 2-3 step notes.
    @Test func bossaBassMatchesItsMeasurements() {
        var perBar: [Double] = [], durs: [Int] = []
        for s in Self.sohoSongs() where Self.uses(s, "CHL-BASS-013") {
            let bars = Set(Self.grooveBars(s))
            let notes = s.trackEvents[kTrackBass].filter { bars.contains($0.stepIndex / 16) }
            guard !bars.isEmpty else { continue }
            perBar.append(Double(notes.count) / Double(bars.count))
            durs += notes.map { $0.durationSteps }
        }
        let mean = perBar.reduce(0, +) / Double(max(1, perBar.count))
        let medDur = durs.sorted()[durs.count / 2]
        #expect(mean >= 4.0 && mean <= 6.0, "013 plays \(mean) notes/bar; measured 4-6")
        #expect(medDur >= 2 && medDur <= 3, "013 median duration \(medDur) steps; measured 2-3")
    }

    /// CHL-BASS-014 — measured from You're the Best Thing's fretless at ~2.8 notes a bar, held
    /// ~4 steps. Sparse and sustained, the opposite of 013.
    @Test func melodicBassMatchesItsMeasurements() {
        var perBar: [Double] = [], durs: [Int] = []
        for s in Self.sohoSongs() where Self.uses(s, "CHL-BASS-014") {
            let bars = Set(Self.grooveBars(s))
            let notes = s.trackEvents[kTrackBass].filter { bars.contains($0.stepIndex / 16) }
            guard !bars.isEmpty else { continue }
            perBar.append(Double(notes.count) / Double(bars.count))
            durs += notes.map { $0.durationSteps }
        }
        let mean = perBar.reduce(0, +) / Double(max(1, perBar.count))
        let medDur = durs.sorted()[durs.count / 2]
        #expect(mean >= 2.0 && mean <= 3.6, "014 plays \(mean) notes/bar; measured ~2.8")
        #expect(medDur >= 3, "014 median duration \(medDur) steps; should be sustained (~4)")
    }

    @Test func melodicBassIsMonophonic() {
        for s in Self.sohoSongs() where Self.uses(s, "CHL-BASS-014") {
            let notes = s.trackEvents[kTrackBass].sorted { $0.stepIndex < $1.stepIndex }
            for (a, b) in zip(notes, notes.dropFirst()) where a.stepIndex / 16 == b.stepIndex / 16 {
                #expect(a.stepIndex + a.durationSteps <= b.stepIndex,
                        "014 overlaps itself at step \(a.stepIndex)")
            }
        }
    }

    // MARK: - Texture — always MIDI, never audio, never absent

    @Test func sohoTextureIsNeverAudio() {
        for s in Self.sohoSongs() {
            #expect(s.chillAudioTexture == nil, "Soho song has audio texture \(s.chillAudioTexture ?? "")")
        }
    }

    @Test func sohoTextureIsNeverAbsent() {
        for s in Self.sohoSongs() {
            #expect(!s.trackEvents[kTrackTexture].isEmpty, "Soho song with an empty texture track")
        }
    }

    /// Exactly one texture rule per song — running both turns Texture into a fourth rhythm part.
    @Test func exactlyOneTextureRule() {
        for s in Self.sohoSongs() {
            let tex = s.generationLog.filter { $0.tag == "CHL-TEXT-001" || $0.tag == "CHL-TEXT-002" }
            #expect(tex.count == 1, "expected one CHL-TEXT rule, got \(tex.map { $0.tag })")
        }
    }

    /// Punctuation Stabs double the kit: every drum crash downbeat carries a stab. Read from
    /// the drum track itself, so the two cannot drift apart.
    @Test func stabsLandOnTheDrumCrashes() {
        var checked = 0
        for s in Self.sohoSongs()
        where s.generationLog.contains(where: { $0.tag == "CHL-TEXT-002" }) {
            let crashes = ChillSohoTextureGenerator.CrashPoints(s.trackEvents[kTrackDrums]).bars
            let stabSteps = Set(s.trackEvents[kTrackTexture].map { $0.stepIndex })
            for bar in crashes {
                #expect(stabSteps.contains(bar * 16), "no stab on the crash at bar \(bar)")
            }
            checked += 1
        }
        #expect(checked > 0)
    }

    /// Sustained Halo: 3–10 long, high notes across the whole song.
    @Test func haloIsSparseLongAndHigh() {
        for s in Self.sohoSongs()
        where s.generationLog.contains(where: { $0.tag == "CHL-TEXT-001" }) {
            // The breakdown horns and the turnaround stabs are separate figures on this track —
            // see breakdownAnswer and turnaroundStabs.
            let skip = Self.bridgeBars(s).union(Self.turnaroundBars(s))
            let ev = s.trackEvents[kTrackTexture].filter { !skip.contains($0.stepIndex / 16) }
            #expect((1...10).contains(ev.count), "halo has \(ev.count) events")
            #expect(ev.allSatisfy { $0.durationSteps >= 8 && $0.note >= 72 && $0.note <= 84 })
        }
    }

    /// Base Chill and Blues keep their audio texture path: no MIDI texture events at all.
    @Test func baseChillTextureStaysAudio() {
        for seed in Self.seeds {
            let s = SongGenerator.generate(seed: seed, style: .chill)
            if !s.chillSohoVariation {
                #expect(s.trackEvents[kTrackTexture].isEmpty, "seed \(seed): base Chill got MIDI texture")
            }
        }
    }

    // MARK: - Titles

    /// Every Soho title contains a word from the Soho banks; base Chill never does. The banks are
    /// read from the generator, not copied here — a copied list went stale and failed once before.
    @Test func sohoTitlesUseTheSohoBank() {
        let vocabulary = ChillTitleGenerator.sohoVocabulary
        for s in Self.sohoSongs() {
            #expect(vocabulary.contains { s.title.contains($0) }, "not a Soho title: \(s.title)")
            #expect(!s.title.contains("  "), "double space in \(s.title)")
            #expect(s.title == s.title.trimmingCharacters(in: .whitespaces), "padded: '\(s.title)'")
        }
    }

    /// Titles must not repeat across a listening session. Measured over 4,000 songs: the first
    /// version produced 199 effectively distinct titles, so one song in five arrived with a name
    /// already used (Zack, 2026-10-11).
    @Test func sohoTitlesRarelyRepeat() {
        var counts: [String: Int] = [:]
        for seed in UInt64(1)...4000 {
            var rng = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: 93))
            counts[ChillTitleGenerator.generateSoho(rng: &rng), default: 0] += 1
        }
        let total = Double(counts.values.reduce(0, +))
        // Effective distinct titles: the reciprocal of the chance two songs share one. It counts
        // a bank of mostly-rare titles honestly, where a plain count of distinct strings does not.
        let effective = 1 / counts.values.reduce(0.0) { $0 + pow(Double($1) / total, 2) }
        #expect(effective > 1000, "only \(Int(effective)) effectively distinct titles")
        // No single title may take more than 1% of songs.
        let worst = counts.max { $0.value < $1.value }!
        #expect(Double(worst.value) / total < 0.01, "\(worst.key) is \(worst.value) of \(Int(total))")
    }

    /// Nothing in the vocabulary is blank or carries stray spacing, and the venue list is spelt
    /// so that "at the Wag" and "at Ronnie Scott's" both read.
    @Test func sohoTitleBanksAreWellFormed() {
        for word in ChillTitleGenerator.sohoVocabulary {
            #expect(!word.isEmpty && word == word.trimmingCharacters(in: .whitespaces), "'\(word)'")
            #expect(!word.contains("  "), "'\(word)'")
        }
        #expect(ChillTitleGenerator.sohoVenues.contains { $0.name == "Marquee" && $0.article })
        #expect(ChillTitleGenerator.sohoVenues.contains { $0.name == "Ronnie Scott's" && !$0.article })
        // Rooms that cannot stand as a title on their own must say so: "Live at the BBC" is a
        // phrase, "The BBC" is not a song.
        #expect(ChillTitleGenerator.sohoVenues.contains { $0.name == "BBC" && $0.article && !$0.alone })
        #expect(!ChillTitleGenerator.sohoVocabulary.contains("Gaggia"), "Gaggia is back")
        // Zack ruled out widening the Hull bank, so it stays at the names that place something.
        #expect(ChillTitleGenerator.sohoHull.count == 9)
    }

    // MARK: - Rhythm

    /// Soho rhythm comes only from its pools — never Bosa Moon (not a bossa), the Moby backbeat,
    /// St Germain or the acid-jazz stab.
    @Test func sohoRhythmExcludesBaseChillModes() {
        let excluded: Set<String> = ["CHL-RHY-001", "CHL-RHY-002", "CHL-RHY-003", "CHL-RHY-004"]
        for s in Self.sohoSongs() {
            let used = Set(s.generationLog.map(\.tag)).intersection(excluded)
            #expect(used.isEmpty, "Soho song used \(used.sorted())")
        }
    }

    /// Latin songs with a B section play two different rules, both from the Latin pool.
    @Test func latinSongsPlayTwoLatinRhythmRules() {
        let latinPool: Set<String> = ["CHL-RHY-007", "CHL-RHY-008", "CHL-RHY-009"]
        for s in Self.sohoSongs() where s.chillBeatStyle == .sohoLatin && s.structure.hasBSection {
            let used = Set(s.generationLog.map(\.tag)).filter { $0.hasPrefix("CHL-RHY-") }
            #expect(used.count == 2 && used.isSubset(of: latinPool), "Latin rhythm rules \(used.sorted())")
        }
    }

    /// CHL-RHY-007, measured: 2–3 note stabs, 7–13 notes a bar, steps 0, 6, 12 carrying the weight.
    @Test func chordalCompMatchesItsMeasurements() {
        var rng = SeededRNG(seed: 7)
        let voicing = [62, 65, 69]
        var perBar: [Int] = []
        for bar in 0..<64 {
            let ev = ChillRhythmGenerator.chordalComp(base: bar * 16, voicing: voicing, bar: bar,
                                                      clave: false, forceSparse: false, rng: &rng)
            perBar.append(ev.count)
            let onsets = Set(ev.map { $0.stepIndex % 16 })
            #expect([0, 6, 12].allSatisfy(onsets.contains), "missing a core step in bar \(bar)")
            for step in onsets {
                let size = ev.filter { $0.stepIndex % 16 == step }.count
                #expect(size >= 2 && size <= 3, "stab of \(size) notes")
            }
        }
        let mean = Double(perBar.reduce(0, +)) / Double(perBar.count)
        #expect(mean >= 7 && mean <= 13, "chordal comp plays \(mean) notes/bar; measured 7–13")
    }

    /// CHL-RHY-007 under the Latin groove: a 3-2 clave across the bar pair.
    @Test func chordalCompPlaysAClaveUnderLatin() {
        var rng = SeededRNG(seed: 3)
        let a = ChillRhythmGenerator.chordalComp(base: 0, voicing: [62, 65, 69], bar: 0, clave: true,
                                                 forceSparse: false, rng: &rng)
        let b = ChillRhythmGenerator.chordalComp(base: 16, voicing: [62, 65, 69], bar: 1, clave: true,
                                                 forceSparse: false, rng: &rng)
        #expect(Set(a.map { $0.stepIndex % 16 }) == [0, 6, 12])
        #expect(Set(b.map { $0.stepIndex % 16 }) == [4, 10, 14])
    }

    /// CHL-RHY-008, measured: monophonic, 4.5–9 notes a bar, inside one octave.
    @Test func singleNoteLineMatchesItsMeasurements() {
        var rng = SeededRNG(seed: 11)
        let (ct, st, at) = NotePoolBuilder.build(chordRootDegree: "1", chordType: .min9, key: "D", mode: .Dorian)
        let chord = ChordWindow(startBar: 0, lengthBars: 64, chordRoot: "1", chordType: .min9,
                                chordTones: ct, scaleTensions: st, avoidTones: at)
        var total = 0
        for bar in 0..<64 {
            let ev = ChillRhythmGenerator.singleNoteLine(base: bar * 16, chord: chord, bar: bar,
                                                         forceSparse: false, rng: &rng)
            total += ev.count
            let onsets = ev.map(\.stepIndex)
            #expect(Set(onsets).count == onsets.count, "not monophonic in bar \(bar)")
            #expect(ev.allSatisfy { $0.note >= 60 && $0.note <= 72 })
            for (x, y) in zip(ev, ev.dropFirst()) {
                #expect(x.stepIndex + x.durationSteps <= y.stepIndex, "notes overlap in bar \(bar)")
            }
        }
        let mean = Double(total) / 64
        #expect(mean >= 4.5 && mean <= 9, "single-note line plays \(mean) notes/bar; measured 4.5–9")
    }

    // MARK: - Drums, measured

    /// CHL-DRUM-012 — backbeat on 4 and 12 via rim click, never a struck snare in the groove.
    @Test func softSoulBackbeatIsRimOnFourAndTwelve() {
        let rim = Int(GMDrum.sidestick.rawValue), snare = Int(GMDrum.snare.rawValue)
        var bars = 0, withBackbeat = 0, snareOnBackbeat = 0
        for s in Self.sohoSongs() where Self.uses(s, "CHL-DRUM-012") {
            let drums = s.trackEvents[kTrackDrums]
            let skip = Self.remixEntry(s).union(Self.turnaroundTreated(s))
            for bar in Self.grooveBars(s) where !skip.contains(bar) {
                let hits = drums.filter { $0.stepIndex / 16 == bar }
                let rimSteps = Set(hits.filter { Int($0.note) == rim }.map { $0.stepIndex % 16 })
                bars += 1
                if rimSteps.contains(4) { withBackbeat += 1 }
                snareOnBackbeat += hits.filter { Int($0.note) == snare && [4, 12].contains($0.stepIndex % 16) }.count
            }
        }
        #expect(Double(withBackbeat) / Double(max(1, bars)) > 0.9, "rim on 4 in too few bars")
        #expect(snareOnBackbeat == 0, "012 struck the snare on the backbeat \(snareOnBackbeat) times")
    }

    /// CHL-DRUM-009 — no snare backbeat at any point; the rim clave replaces it.
    @Test func bossaClaveHasNoSnareBackbeat() {
        let snare = Int(GMDrum.snare.rawValue)
        for s in Self.sohoSongs() where Self.uses(s, "CHL-DRUM-009") {
            // The bar leading into a Remix Break is a band hit, not the groove.
            let groove = Set(Self.grooveBars(s)).subtracting(Self.remixEntry(s))
            let backbeat = s.trackEvents[kTrackDrums].filter {
                groove.contains($0.stepIndex / 16) && Int($0.note) == snare
                    && [4, 12].contains($0.stepIndex % 16)
            }
            #expect(backbeat.isEmpty, "009 played a snare backbeat")
        }
    }

    // MARK: - Step 3: full drum and bass pools, percussion overlay

    private static let latinDrums: Set<String> = ["CHL-DRUM-009", "CHL-DRUM-010", "CHL-DRUM-011"]
    private static let soulDrums:  Set<String> = ["CHL-DRUM-012", "CHL-DRUM-013", "CHL-DRUM-003"]

    /// Each groove draws only from its own drum pool, and every rule in each pool appears.
    @Test func drumRulesComeFromTheGroovesPool() {
        var seen = Set<String>()
        for s in Self.sohoSongs() {
            let tags = Set(s.generationLog.map(\.tag))
            let pool = s.chillBeatStyle == .sohoLatin ? Self.latinDrums : Self.soulDrums
            let other = s.chillBeatStyle == .sohoLatin ? Self.soulDrums : Self.latinDrums
            #expect(tags.intersection(pool).count == 1, "expected one drum rule from the pool")
            #expect(tags.intersection(other).isEmpty, "a soul rule under a Latin groove, or vice versa")
            seen.formUnion(tags.intersection(Self.latinDrums.union(Self.soulDrums)))
        }
        #expect(seen == Self.latinDrums.union(Self.soulDrums), "rules never drawn: \(Self.latinDrums.union(Self.soulDrums).subtracting(seen).sorted())")
    }

    /// The drum plan is a function of the seed, so SongGenerator can read it before the drums exist
    /// (the Remix Break depends on it) and a reload reproduces it.
    @Test func drumPlanIsReproducibleFromTheSeed() {
        for s in Self.sohoSongs().prefix(40) {
            let plan = ChillDrumGenerator.sohoDrumPlan(beatStyle: s.chillBeatStyle, seed: s.globalSeed)
            #expect(Self.uses(s, plan.ruleID), "log disagrees with the seed's plan (\(plan.ruleID))")
            #expect(Self.uses(s, "CHL-DRUM-014") == plan.overlay)
        }
    }

    /// Overlay rates: 85% under Latin, 40% under Soul, within sampling noise.
    @Test func percussionOverlayRates() {
        let songs = Self.sohoSongs()
        func rate(_ style: ChillBeatStyle) -> Double {
            let g = songs.filter { $0.chillBeatStyle == style }
            return Double(g.filter { Self.uses($0, "CHL-DRUM-014") }.count) / Double(max(1, g.count))
        }
        #expect(abs(rate(.sohoLatin) - 0.85) < 0.12, "Latin overlay \(rate(.sohoLatin))")
        #expect(abs(rate(.sohoSoul) - 0.40) < 0.15, "Soul overlay \(rate(.sohoSoul))")
    }

    /// A song with the overlay actually plays Latin percussion; one without plays none outside a
    /// rule that owns those voices (010's shaker and surdo, 011's congas, 013's shaker pickup).
    @Test func overlayPlaysLatinPercussion() {
        let latinVoices: Set<Int> = [60, 61, 62, 63, 64, 69, 70]
        for s in Self.sohoSongs() where Self.uses(s, "CHL-DRUM-014") {
            let played = Set(s.trackEvents[kTrackDrums].map { Int($0.note) })
            #expect(!played.isDisjoint(with: latinVoices), "overlay song with no Latin percussion")
        }
    }

    /// CHL-DRUM-010 Soft Samba: shaker sixteenths, and a real surdo weighted on step 8.
    @Test func softSambaHasShakerAndSurdo() {
        for s in Self.sohoSongs() where Self.uses(s, "CHL-DRUM-010") {
            let drums = s.trackEvents[kTrackDrums]
            let surdo8 = drums.filter { $0.note == 87 && $0.stepIndex % 16 == 8 }
            #expect(!surdo8.isEmpty, "no open surdo on step 8")
            #expect(drums.contains { $0.note == 82 }, "no shaker")
        }
    }

    /// CHL-DRUM-011 Latin Sway: congas on the loose tumbao 0, 3, 6, 10, 13.
    @Test func latinSwayCongasFollowTheTumbao() {
        let congas: Set<Int> = [62, 63, 64]
        for s in Self.sohoSongs() where Self.uses(s, "CHL-DRUM-011") && !Self.uses(s, "CHL-DRUM-014") {
            let groove = Set(Self.grooveBars(s))
            let steps = Set(s.trackEvents[kTrackDrums]
                .filter { congas.contains(Int($0.note)) && groove.contains($0.stepIndex / 16) }
                .map { $0.stepIndex % 16 })
            #expect(steps.isSubset(of: [0, 3, 6, 10, 13, 12, 14, 15]), "conga off the tumbao: \(steps.sorted())")
        }
    }

    /// CHL-DRUM-013 Ballad Half-Time: the rim backbeat is on beat 3 only.
    @Test func balladHalfTimeRimOnBeatThreeOnly() {
        let rim = Int(GMDrum.sidestick.rawValue)
        for s in Self.sohoSongs() where Self.uses(s, "CHL-DRUM-013") {
            let groove = Set(Self.grooveBars(s))
            let steps = Set(s.trackEvents[kTrackDrums]
                .filter { Int($0.note) == rim && groove.contains($0.stepIndex / 16) }
                .map { $0.stepIndex % 16 })
            #expect(steps == [8], "ballad rim on \(steps.sorted())")
        }
    }

    /// The Rumba bass hardcodes a minor third, so it must never play in a major mode.
    @Test func rumbaNeverInAMajorMode() {
        let minor: Set<Mode> = [.Dorian, .Aeolian, .Phrygian, .HarmonicMinor, .MinorPentatonic]
        var sawRumba = false
        for s in Self.sohoSongs() where Self.uses(s, "CHL-BASS-012") {
            sawRumba = true
            #expect(minor.contains(s.frame.mode), "Rumba in \(s.frame.mode)")
        }
        #expect(sawRumba)
    }

    /// CHL-BASS-015 Syncopated Pocket: Black Cow's attacks on 0, 3 and 6 every groove bar.
    @Test func syncopatedPocketHitsZeroThreeSix() {
        for s in Self.sohoSongs() where Self.uses(s, "CHL-BASS-015") {
            let treated = Self.turnaroundTreated(s)
            let groove = Self.grooveBars(s).filter { !treated.contains($0) }
            let bass = s.trackEvents[kTrackBass]
            for bar in groove.prefix(16) {
                let steps = Set(bass.filter { $0.stepIndex / 16 == bar }.map { $0.stepIndex % 16 })
                #expect([0, 3, 6].allSatisfy(steps.contains), "bar \(bar): \(steps.sorted())")
            }
        }
    }

    // MARK: - Step 4: breakdowns and the Remix Break

    /// Songs in which a Remix Break actually PLAYS. The remix is rare by design (~1 Soho song in
    /// 20), so this sweeps a wider seed range. A song can carry `.sohoRemix` and still have no
    /// breakdown at all — Simple form has no bridge, and the style then goes unused, as it does for
    /// every Chill breakdown style — so the bridge is required too.
    private static func remixSongs() -> [SongState] {
        (UInt64(1)...1500).compactMap { seed in
            let s = SongGenerator.generate(seed: seed, style: .chill)
            let plays = s.chillSohoVariation && s.chillBreakdownStyle == .sohoRemix
                && s.structure.sections.contains { $0.label == .bridge }
            return plays ? s : nil
        }
    }

    private static func remixBars(_ s: SongState) -> [Int] {
        s.structure.sections.filter { $0.label == .bridge }
            .flatMap { $0.startBar..<($0.startBar + $0.lengthBars) }
    }

    /// Only when its pivot and tempo exist: the overlay on, tempo above 105, and a kit Soho renders
    /// itself (not Ballad Half-Time, not the reused Brush Kit).
    @Test func remixOnlyWhenEligible() {
        let songs = Self.remixSongs()
        #expect(songs.count >= 5, "only \(songs.count) remix songs in range — too few to test")
        for s in songs {
            #expect(Self.uses(s, "CHL-DRUM-014"), "remix without the percussion overlay")
            #expect(s.frame.tempo > 105, "remix at \(s.frame.tempo) bpm")
            #expect(!Self.uses(s, "CHL-DRUM-013") && !Self.uses(s, "CHL-DRUM-003"))
            let len = s.structure.sections.first { $0.label == .bridge }?.lengthBars ?? 0
            #expect([6, 8, 12].contains(len), "remix of \(len) bars")
        }
    }

    /// The pivot: the shaker plays every step of the break, and the kit is four-on-the-floor.
    @Test func remixKeepsTheShakerAndGoesFourOnTheFloor() {
        let kick = Int(GMDrum.kick.rawValue)
        for s in Self.remixSongs() {
            let drums = s.trackEvents[kTrackDrums]
            let bars = Self.remixBars(s)
            for bar in bars {
                let shakerSteps = Set(drums.filter { $0.note == 82 && $0.stepIndex / 16 == bar }.map { $0.stepIndex % 16 })
                #expect(shakerSteps.count == 16, "shaker missing steps in remix bar \(bar)")
            }
            for bar in bars.dropLast() {
                let kicks = Set(drums.filter { Int($0.note) == kick && $0.stepIndex / 16 == bar }.map { $0.stepIndex % 16 })
                #expect(kicks == [0, 4, 8, 12], "remix bar \(bar) kick \(kicks.sorted())")
            }
        }
    }

    /// Bass sits out the first two bars of the break; Lead 1 rests through all of it except its
    /// pickup into the return on steps 10–14 of the last bar.
    @Test func remixBassEntersLateAndLeadRests() {
        for s in Self.remixSongs() {
            let bars = Self.remixBars(s)
            guard let first = bars.first, let last = bars.last else { continue }
            let bass = s.trackEvents[kTrackBass]
            #expect(!bass.contains { [first, first + 1].contains($0.stepIndex / 16) }, "bass in the first two remix bars")
            let lead = s.trackEvents[kTrackLead1].filter {
                !($0.stepIndex / 16 == last && $0.stepIndex % 16 >= 10)
            }
            #expect(!lead.contains { bars.contains($0.stepIndex / 16) }, "Lead 1 plays during the remix")
        }
    }

    /// Both exits are heard across the remix songs: unison stabs on 0 and 8, and the fill.
    @Test func remixExitsBothWays() {
        let crash = Int(GMDrum.crash1.rawValue)
        var stabs = 0, fills = 0
        for s in Self.remixSongs() {
            guard let last = Self.remixBars(s).last else { continue }
            let crashSteps = Set(s.trackEvents[kTrackDrums]
                .filter { Int($0.note) == crash && $0.stepIndex / 16 == last }.map { $0.stepIndex % 16 })
            if crashSteps == [0, 8] { stabs += 1 } else { fills += 1 }
        }
        #expect(stabs > 0 && fills > 0, "exits: \(stabs) stabs, \(fills) fills")
    }

    /// Punctuation Stabs double every crash — including the remix exit's step-8 hit.
    @Test func textureStabsDoubleEveryCrash() {
        for s in Self.sohoSongs() + Self.remixSongs()
        where Self.uses(s, "CHL-TEXT-002") {
            let stabSteps = Set(s.trackEvents[kTrackTexture].map(\.stepIndex))
            for at in ChillSohoTextureGenerator.CrashPoints(s.trackEvents[kTrackDrums]).steps {
                #expect(stabSteps.contains(at), "no stab on the crash at step \(at)")
            }
        }
    }

    /// Outside the remix, Soho favours bass ostinato as its breakdown, per the plan.
    @Test func sohoBreakdownMixFavoursBassOstinato() {
        var counts: [ChillBreakdownStyle: Int] = [:]
        for s in Self.sohoSongs() where s.structure.sections.contains(where: { $0.label == .bridge }) {
            counts[s.chillBreakdownStyle, default: 0] += 1
        }
        let top = counts.filter { $0.key != .sohoRemix }.max { $0.value < $1.value }?.key
        #expect(top == .bassOstinato, "breakdown mix \(counts)")
    }

    // MARK: - Pads

    private static let sohoPadRules: Set<String> = ["CHL-PAD-000", "CHL-PAD-001", "CHL-PAD-002",
        "CHL-PAD-004", "CHL-PAD-005", "CHL-PAD-006", "CHL-PAD-007", "CHL-PAD-008"]

    private static func bridgeBars(_ s: SongState) -> Set<Int> {
        Set(s.structure.sections.filter { $0.label == .bridge }.flatMap { $0.startBar..<$0.endBar })
    }

    /// Exactly one pad rule from the Soho pool; never Moby anchor.
    @Test func sohoPadsComeFromTheSohoPool() {
        for s in Self.sohoSongs() {
            let pads = s.generationLog.filter { $0.tag.hasPrefix("CHL-PAD-") }.map(\.tag)
            #expect(pads.count == 1 && Self.sohoPadRules.contains(pads[0]), "pad rules \(pads)")
        }
    }

    /// Absent means the pads never appear — not even in the breakdown.
    @Test func absentPadsPlayNothing() {
        var absent = 0
        let songs = Self.sohoSongs()
        for s in songs where Self.uses(s, "CHL-PAD-000") {
            absent += 1
            #expect(s.trackEvents[kTrackPads].isEmpty, "absent pads played \(s.trackEvents[kTrackPads].count) notes")
        }
        let share = Double(absent) / Double(songs.count)
        #expect(share > 0.12 && share < 0.28, "absent share \(share)")
    }

    /// Soho Chord Hold: onsets on step 0, step 8 or an anticipation on 15; 3–5 note voicings.
    @Test func chordHoldMatchesItsMeasurements() {
        var anticipations = 0, restates = 0, found = 0
        for s in Self.sohoSongs() where Self.uses(s, "CHL-PAD-007") {
            found += 1
            let bridge = Self.bridgeBars(s)
            let byStep = Dictionary(grouping: s.trackEvents[kTrackPads].filter { !bridge.contains($0.stepIndex / 16) },
                                    by: \.stepIndex)
            for (step, notes) in byStep {
                #expect([0, 8, 15].contains(step % 16), "onset on step \(step % 16)")
                #expect((3...5).contains(notes.count), "voicing of \(notes.count)")
                if step % 16 == 15 { anticipations += 1 }
                if step % 16 == 8 { restates += 1 }
            }
        }
        #expect(found > 0)
        #expect(anticipations > 0 && restates > 0, "anticipations \(anticipations), restates \(restates)")
    }

    /// Half-Bar Pad: steps 0 and 8 only, 2–3 notes, half-bar holds.
    @Test func halfBarPadMatchesItsMeasurements() {
        var found = 0
        for s in Self.sohoSongs() where Self.uses(s, "CHL-PAD-008") {
            found += 1
            let bridge = Self.bridgeBars(s)
            let evs = s.trackEvents[kTrackPads].filter { !bridge.contains($0.stepIndex / 16) }
            for (step, notes) in Dictionary(grouping: evs, by: \.stepIndex) {
                #expect([0, 8].contains(step % 16), "onset on step \(step % 16)")
                #expect((2...3).contains(notes.count), "voicing of \(notes.count)")
                #expect(notes.allSatisfy { $0.durationSteps == 6 })
            }
        }
        #expect(found > 0)
    }

    /// A restruck pitch must start after the previous note's fade (a quarter of its length) has
    /// finished, or the engine's deferred stopNote cuts the new attack off.
    @Test func sohoPadRestrikesClearTheFade() {
        for s in Self.sohoSongs() where Self.uses(s, "CHL-PAD-007") || Self.uses(s, "CHL-PAD-008") {
            let bridge = Self.bridgeBars(s)
            let evs = s.trackEvents[kTrackPads].filter { !bridge.contains($0.stepIndex / 16) }
            for (_, notes) in Dictionary(grouping: evs, by: \.note) {
                let sorted = notes.sorted { $0.stepIndex < $1.stepIndex }
                for (a, b) in zip(sorted, sorted.dropFirst()) {
                    let stopped = Double(a.stepIndex + a.durationSteps) + Double(a.durationSteps) / 4
                    #expect(Double(b.stepIndex) > stopped,
                            "note \(a.note) at \(a.stepIndex)+\(a.durationSteps) restruck at \(b.stepIndex)")
                }
            }
        }
    }

    // MARK: - Leads

    private static func lead1Rule(_ s: SongState) -> String? {
        s.generationLog.first { ChillLeadGenerator.sohoLead1Rules.contains($0.tag) }?.tag
    }

    /// Bars holding a Remix Break pickup or its landing note — the one place Lead 1 plays
    /// outside its rule.
    private static func pickupBars(_ s: SongState) -> Set<Int> {
        guard s.chillBreakdownStyle == .sohoRemix else { return [] }
        return Set(s.structure.sections.filter { $0.label == .bridge }.flatMap { [$0.endBar - 1, $0.endBar] })
    }

    /// Exactly one Soho Lead 1 rule; never St Germain staccato or an unlisted base Chill rule.
    @Test func sohoLead1UsesOnlySohoRules() {
        var counts: [String: Int] = [:]
        let songs = Self.sohoSongs()
        for s in songs {
            let ld1 = s.generationLog.map(\.tag).filter { $0.hasPrefix("CHL-LD1-") }
            #expect(ld1.count == 1 && ChillLeadGenerator.sohoLead1Rules.contains(ld1.first ?? ""), "Lead 1 rules \(ld1)")
            if let r = ld1.first { counts[r, default: 0] += 1 }
        }
        let share = { (r: String) in Double(counts[r, default: 0]) / Double(songs.count) }
        // 30 / 20 / 20 / 15 / 15
        #expect(share("CHL-LD1-010") > 0.20 && share("CHL-LD1-010") < 0.40, "\(counts)")
        #expect(share("CHL-LD1-012") > 0.11 && share("CHL-LD1-012") < 0.29, "\(counts)")
        #expect(share("CHL-LD1-004") > 0.11 && share("CHL-LD1-004") < 0.29, "\(counts)")
        #expect(share("CHL-LD1-001") > 0.07 && share("CHL-LD1-001") < 0.23, "\(counts)")
        #expect(share("CHL-LD1-011") > 0.07 && share("CHL-LD1-011") < 0.23, "\(counts)")
    }

    /// Soho's own Lead 1 rules never play in the intro, and in a breakdown only the remix
    /// pickup. The reused base rules keep base Chill's intro and breakdown behaviour.
    @Test func sohoLead1RestsInIntroAndBreakdowns() {
        for s in Self.sohoSongs()
        where !ChillLeadGenerator.sohoReusedLead1Rules.contains(Self.lead1Rule(s) ?? "") {
            let pickups = Self.pickupBars(s)
            // Lead 1 plays through the Harmonic Drone and no other breakdown (Zack, 2026-10-12).
            let droneOK = s.chillBreakdownStyle == .harmonicDrone
            for ev in s.trackEvents[kTrackLead1] where !pickups.contains(ev.stepIndex / 16) {
                let label = s.structure.section(atBar: ev.stepIndex / 16)?.label
                #expect(label == .A || label == .B || label == .outro || (droneOK && label == .bridge),
                        "Lead 1 note in \(String(describing: label))")
            }
        }
    }

    /// Counter-Line: eighth-note motion, repeated pitches present, few leaps.
    @Test func counterLineMatchesItsMeasurements() {
        var iois = 0, eighths = 0, intervals = 0, repeats = 0, leaps = 0
        for s in Self.sohoSongs() where Self.lead1Rule(s) == "CHL-LD1-010" {
            let pickups = Self.pickupBars(s)
            let notes = s.trackEvents[kTrackLead1].filter { !pickups.contains($0.stepIndex / 16) }
                .sorted { $0.stepIndex < $1.stepIndex }
            for (a, b) in zip(notes, notes.dropFirst()) where b.stepIndex - a.stepIndex <= 8 {
                iois += 1
                if b.stepIndex - a.stepIndex == 2 { eighths += 1 }
                intervals += 1
                let d = abs(Int(b.note) - Int(a.note))
                if d == 0 { repeats += 1 }
                if d >= 5 { leaps += 1 }
            }
        }
        #expect(iois > 0)
        #expect(Double(eighths) / Double(iois) > 0.40, "eighths \(eighths)/\(iois)")
        #expect(Double(repeats) / Double(intervals) > 0.12, "repeats \(repeats)/\(intervals)")
        // Leaps of a fourth or more are 17–20% of the measured intervals, so they must be
        // present — the cell bank alone cannot produce one — but must not take the line over.
        let leapShare = Double(leaps) / Double(intervals)
        #expect(leapShare > 0.12 && leapShare < 0.32, "leaps \(leaps)/\(intervals)")
    }

    /// Sustained Tone: phrases built on one long note, with long rests between the phrases.
    /// A phrase may add one to three short punches around its long tone (Zack, 2026-10-12), so
    /// the sparseness rule is about the gaps *between* phrases, not between notes.
    @Test func sustainedToneIsLongAndSparse() {
        var found = 0, multiNote = 0, phrases = 0
        for s in Self.sohoSongs() where Self.lead1Rule(s) == "CHL-LD1-011" {
            found += 1
            let pickups = Self.pickupBars(s)
            let notes = s.trackEvents[kTrackLead1].filter { !pickups.contains($0.stepIndex / 16) }
                .sorted { $0.stepIndex < $1.stepIndex }
            // Group into phrases: anything more than a bar apart starts a new one.
            var groups: [[MIDIEvent]] = []
            for n in notes {
                if let last = groups.last?.last, n.stepIndex - (last.stepIndex + last.durationSteps) <= 16 {
                    groups[groups.count - 1].append(n)
                } else {
                    groups.append([n])
                }
            }
            phrases += groups.count
            for g in groups {
                #expect((1...4).contains(g.count), "phrase of \(g.count) notes")
                if g.count > 1 { multiNote += 1 }
                // Exactly one long tone per phrase; the rest are short punches.
                #expect(g.filter { $0.durationSteps >= 16 }.count == 1,
                        "phrase durations \(g.map(\.durationSteps))")
            }
            #expect(groups.count <= 24, "\(groups.count) sustained-tone phrases")
            for (a, b) in zip(groups, groups.dropFirst()) {
                let gap = b[0].stepIndex - (a.last!.stepIndex + a.last!.durationSteps)
                #expect(gap >= 48, "rest under three bars between phrases")
            }
        }
        #expect(found > 0)
        // Most phrases carry more than one note — a lone held tone was too static.
        #expect(Double(multiNote) / Double(phrases) > 0.5,
                "only \(multiNote)/\(phrases) phrases have more than one note")
    }

    /// Tight Hook: each bar's figure fits inside about a tenth.
    @Test func tightHookStaysNarrow() {
        var found = 0
        for s in Self.sohoSongs() where Self.lead1Rule(s) == "CHL-LD1-012" {
            found += 1
            let pickups = Self.pickupBars(s)
            let byBar = Dictionary(grouping: s.trackEvents[kTrackLead1].filter { !pickups.contains($0.stepIndex / 16) },
                                   by: { $0.stepIndex / 16 })
            for (bar, notes) in byBar {
                let ps = notes.map { Int($0.note) }
                #expect(ps.max()! - ps.min()! <= 12, "bar \(bar) spans \(ps.max()! - ps.min()!) semitones")
                #expect(notes.count <= 6)
            }
        }
        #expect(found > 0)
    }

    /// No stretch of more than 16 sounding bars in a row, outside Sustained Tone.
    @Test func sohoLead1LeavesSpace() {
        for s in Self.sohoSongs() where Self.lead1Rule(s) != "CHL-LD1-011" {
            let bars = Set(s.trackEvents[kTrackLead1].map { $0.stepIndex / 16 })
            var run = 0, longest = 0
            for bar in 0..<s.frame.totalBars {
                run = bars.contains(bar) ? run + 1 : 0
                longest = max(longest, run)
            }
            #expect(longest <= 16, "Lead 1 ran \(longest) bars")
        }
    }

    /// Lead 1 picks up into the remix return on steps 10, 12 and 14.
    @Test func lead1PicksUpIntoTheRemixReturn() {
        var withPickup = 0, total = 0
        for s in Self.remixSongs() {
            guard let bridge = s.structure.sections.first(where: { $0.label == .bridge }) else { continue }
            total += 1
            let steps = Set(s.trackEvents[kTrackLead1].filter { $0.stepIndex / 16 == bridge.endBar - 1 }
                .map { $0.stepIndex % 16 })
            if steps == [10, 12, 14] { withPickup += 1 }
        }
        #expect(total > 0 && Double(withPickup) / Double(total) > 0.8, "pickups \(withPickup)/\(total)")
    }

    /// Lead 2: sax, brass, trombone or vibes, never Lead 1's instrument, at most 2 notes a bar,
    /// and call-and-response about three songs in four.
    @Test func sohoLead2IsSparseAndAnswers() {
        let pool: Set<ChillLeadInstrument> = [.saxophone, .tenorSax, .synthBrass, .trombone, .vibraphone]
        var shadow = 0
        let songs = Self.sohoSongs()
        for s in songs {
            #expect(pool.contains(s.chillLead2Instrument))
            #expect(s.chillLead2Instrument != s.chillLeadInstrument)
            if Self.uses(s, "CHL-LD2-002") { shadow += 1 }
            // The Chill harmony windows double Lead 1 note for note; that is not Lead 2's own line.
            // (Their tags are shown as step annotations, not in the generation log.)
            let lead1Steps = Set(s.trackEvents[kTrackLead1].map(\.stepIndex))
            let own = s.trackEvents[kTrackLead2].filter { !lead1Steps.contains($0.stepIndex) }
            let perBar = Dictionary(grouping: own, by: { $0.stepIndex / 16 })
            #expect(perBar.values.allSatisfy { $0.count <= 2 }, "Lead 2 over 2 notes a bar")
        }
        let share = Double(shadow) / Double(songs.count)
        #expect(share > 0.14 && share < 0.36, "shadow hold share \(share)")
    }

    /// The Lead 2 picker pool for Soho plays the instrument the song generated.
    @Test func sohoLead2PoolHoldsEveryInstrument() {
        let programs = AppState.instrumentPoolPrograms(trackIndex: kTrackLead2, style: .chill, isChillSoho: true)
        let names    = AppState.instrumentPoolNames(trackIndex: kTrackLead2, style: .chill, isChillSoho: true)
        #expect(programs.count == names.count)
        for inst in [ChillLeadInstrument.saxophone, .tenorSax, .synthBrass, .trombone, .vibraphone] {
            #expect(programs.contains(Int(inst.gmProgram)), "\(inst) missing from the Soho Lead 2 pool")
        }
    }

    // MARK: - Turnaround, B-section cycle, Root-and-Chord Eighths, Samba Pickup, dropouts

    private static func scalePCs(_ mode: Mode) -> Set<Int> { Set(mode.intervals.map { $0 % 12 }) }

    /// Every turnaround chord is diatonic to its mode, so nothing in it needs snapping.
    @Test func turnaroundChordsAreDiatonic() {
        for mode in [Mode.Ionian, .Mixolydian, .Dorian, .Aeolian] {
            for tonic in [ChordType.min9, .min7] {
                for (deg, type) in SongGenerator.sohoTurnaround(mode: mode, tonicType: tonic) {
                    let root = degreeSemitone(deg)
                    let tones = Set(type.intervals.map { (root + $0) % 12 })
                    #expect(tones.isSubset(of: Self.scalePCs(mode)),
                            "\(mode) \(deg)\(type) has \(tones.subtracting(Self.scalePCs(mode)).sorted())")
                }
            }
        }
    }

    /// Every A or B section of 8 bars or more ends on the turnaround: four one-bar chords where
    /// the first and third match and the second differs.
    @Test func sectionsEndOnTheTurnaround() {
        var checked = 0
        for s in Self.sohoSongs() {
            for sec in s.structure.sections where (sec.label == .A || sec.label == .B) && sec.lengthBars >= 8 {
                let last = s.structure.chordPlan.filter { $0.startBar >= sec.endBar - 4 && $0.startBar < sec.endBar }
                    .sorted { $0.startBar < $1.startBar }
                guard last.count == 4 else { Issue.record("section end has \(last.count) windows"); continue }
                // Major modes have two turnarounds — the measured one and a brighter cadence.
                let tonicType = s.structure.chordPlan.first?.chordType ?? .min7
                let shapes = [false, true].map {
                    SongGenerator.sohoTurnaround(mode: s.frame.mode, tonicType: tonicType, bright: $0).map(\.0)
                }
                #expect(shapes.contains(last.map(\.chordRoot)),
                        "section end \(last.map(\.chordRoot)) matches neither turnaround")
                checked += 1
            }
        }
        #expect(checked > 0)
    }

    /// The B section plays a different cycle from A.
    @Test func bSectionHasItsOwnCycle() {
        var checked = 0
        for s in Self.sohoSongs() where s.structure.hasBSection {
            guard let a = s.structure.sections.first(where: { $0.label == .A }),
                  let b = s.structure.sections.first(where: { $0.label == .B }),
                  a.lengthBars >= 8, b.lengthBars >= 8 else { continue }
            func opening(_ sec: SongSection) -> [String] {
                s.structure.chordPlan.filter { $0.startBar >= sec.startBar && $0.startBar < sec.startBar + 4 }
                    .sorted { $0.startBar < $1.startBar }.map { "\($0.chordRoot)\($0.chordType)" }
            }
            #expect(opening(a) != opening(b), "A and B open alike: \(opening(a))")
            checked += 1
        }
        #expect(checked > 0)
    }

    /// Bars played by CHL-RHY-009: a low root (48–59) on the downbeat and its octave on step 6.
    private static func eighthsBars(_ s: SongState) -> [Int: [MIDIEvent]] {
        let byBar = Dictionary(grouping: s.trackEvents[kTrackRhythm], by: { $0.stepIndex / 16 })
        return byBar.filter { _, evs in
            guard let low = evs.first(where: { $0.stepIndex % 16 == 0 && (48...59).contains(Int($0.note)) }) else { return false }
            return evs.contains { $0.stepIndex % 16 == 6 && Int($0.note) == Int(low.note) + 12 }
        }
    }

    /// Root-and-Chord Eighths: every eighth except the "and" of 1, the fragment changing shape on
    /// every hit, and more than one variant across the song.
    @Test func rootAndChordEighthsMatchesItsMeasurements() {
        var found = 0
        for s in Self.sohoSongs() where Self.uses(s, "CHL-RHY-009") {
            let bars = Self.eighthsBars(s)
            guard !bars.isEmpty else { continue }
            found += 1
            var patterns = Set<[Int]>()
            for (_, evs) in bars {
                let steps = Set(evs.map { $0.stepIndex % 16 })
                #expect(steps.isSubset(of: [0, 4, 6, 8, 10, 12, 14]), "steps \(steps.sorted())")
                patterns.insert(steps.sorted())
                let fragments = Dictionary(grouping: evs.filter { [4, 8, 10, 14].contains($0.stepIndex % 16) },
                                           by: \.stepIndex).sorted { $0.key < $1.key }.map { $0.value.map(\.note).sorted() }
                for (x, y) in zip(fragments, fragments.dropFirst()) { #expect(x != y, "same fragment twice") }
            }
            if bars.count >= 24 { #expect(patterns.count >= 2, "one pattern over \(bars.count) bars") }
        }
        #expect(found > 0)
    }

    /// Samba Pickup: the measured placements only, the pickup into beat 2 in every full bar, and
    /// at least two variants across a song.
    @Test func sambaPickupMatchesItsMeasurements() {
        var found = 0
        for s in Self.sohoSongs() where Self.uses(s, "CHL-BASS-016") {
            found += 1
            let groove = Set(Self.grooveBars(s)).subtracting(Self.turnaroundTreated(s))
            let byBar = Dictionary(grouping: s.trackEvents[kTrackBass].filter { groove.contains($0.stepIndex / 16) },
                                   by: { $0.stepIndex / 16 })
            var patterns = Set<[Int]>()
            for (_, evs) in byBar where evs.count >= 4 {
                let steps = Set(evs.map { $0.stepIndex % 16 })
                #expect(steps.isSubset(of: [0, 3, 4, 7, 9, 11, 12, 14]), "steps \(steps.sorted())")
                #expect(steps.isSuperset(of: [0, 3, 4]), "no pickup into beat 2: \(steps.sorted())")
                patterns.insert(steps.sorted())
            }
            if byBar.count >= 40 { #expect(patterns.count >= 2, "one pattern for the whole song") }
        }
        #expect(found > 0)
    }

    /// Soho's Rumba keeps its third and sixth in the scale over every chord.
    @Test func sohoRumbaStaysInTheScale() {
        for s in Self.sohoSongs() where Self.uses(s, "CHL-BASS-012") {
            let pcs = Self.scalePCs(s.frame.mode).map { ($0 + s.frame.keySemitoneValue) % 12 }
            let skip = Self.turnaroundTreated(s)
            for ev in s.trackEvents[kTrackBass]
            where [6, 12].contains(ev.stepIndex % 16) && !skip.contains(ev.stepIndex / 16) {
                #expect(pcs.contains(Int(ev.note) % 12), "Rumba note \(ev.note) outside the scale")
            }
        }
    }

    /// Every Soho song has at least one rhythm dropout of 8+ bars inside the groove, and long
    /// grooves have two.
    @Test func rhythmDropsOutForLongPassages() {
        for s in Self.sohoSongs() {
            let groove = Self.grooveBars(s)
            let sounding = Set(s.trackEvents[kTrackRhythm].map { $0.stepIndex / 16 })
            var runs: [Int] = [], run = 0, prev = -2
            for bar in groove {
                if !sounding.contains(bar) && bar == prev + 1 && run > 0 { run += 1 }
                else if !sounding.contains(bar) { if run > 0 { runs.append(run) }; run = 1 }
                else { if run > 0 { runs.append(run) }; run = 0 }
                prev = bar
            }
            if run > 0 { runs.append(run) }
            let long = runs.filter { $0 >= 8 }.count
            #expect(long >= 1, "no long rhythm dropout; silent runs \(runs)")
            if groove.count >= 72 { #expect(long >= 2, "\(groove.count) groove bars, one long dropout") }
        }
    }

    // MARK: - Texture horns, Latin intro and outro, Counter-Line variety

    /// The Soho texture pool is real horns and tuned percussion — no synth brass — and every
    /// program is in Zudio.sf2's preset list.
    @Test func sohoTexturePoolHasNoSynthBrass() {
        let names    = AppState.instrumentPoolNames(trackIndex: kTrackTexture, style: .chill, isChillSoho: true)
        let programs = AppState.instrumentPoolPrograms(trackIndex: kTrackTexture, style: .chill, isChillSoho: true)
        #expect(names.count == programs.count)
        // No synth brass of any bank: Zack rejected the bank-0 pair and then the bank-8
        // variation samples too (2026-10-12). This music wants real horns.
        #expect(!names.contains { $0.contains("Synth Brass") }, "\(names)")
        #expect(programs.prefix(3) == [56, 57, 59], "horns are \(programs.prefix(3))")
        // Every pick the randomiser can make is inside the pool.
        let picks = AppState.instrumentPickPoolStatic(trackIndex: kTrackTexture, style: .chill,
                                                      poolCount: names.count, state: nil)
        #expect(picks.allSatisfy { $0 >= 0 && $0 < names.count })
    }

    /// Punctuation stabs are 1–3 notes thick and nothing rings over the next downbeat.
    @Test func hornStabsVaryInSize() {
        var sizes = Set<Int>(), checked = 0
        for s in Self.sohoSongs() where Self.uses(s, "CHL-TEXT-002") {
            checked += 1
            for (step, notes) in Dictionary(grouping: s.trackEvents[kTrackTexture], by: \.stepIndex) {
                #expect((1...3).contains(notes.count), "stab of \(notes.count) notes")
                sizes.insert(notes.count)
                #expect(notes.allSatisfy { step % 16 + $0.durationSteps <= 16 }, "stab runs past the bar")
                // Note lengths inside one hit may differ — that is a voicing detail and sounds
                // fine as a chord. What matters is the rhythm *between* hits (Zack, 2026-10-12).
            }
        }
        #expect(checked > 0)
        #expect(sizes == [1, 2, 3], "stab sizes seen: \(sizes.sorted())")
    }

    /// The horns play *figures*, not one isolated chord every time. Two or three notes sounding
    /// together is still a single "bap" however thick it is — the rhythm has to carry it.
    @Test func hornStabsPlayMultiHitFigures() {
        var counts: [Int: Int] = [:]
        for s in Self.sohoSongs() where Self.uses(s, "CHL-TEXT-002") {
            var figure: [Int] = []
            for step in Set(s.trackEvents[kTrackTexture].map(\.stepIndex)).sorted() {
                if let last = figure.last, step - last > 8 {
                    counts[Swift.min(figure.count, 3), default: 0] += 1
                    figure = []
                }
                figure.append(step)
            }
            if !figure.isEmpty { counts[Swift.min(figure.count, 3), default: 0] += 1 }
        }
        let total = counts.values.reduce(0, +)
        #expect(total > 0)
        func share(_ hits: Int) -> Double { Double(counts[hits] ?? 0) / Double(total) }
        // Roughly half are a single hit; the rest are two- or three-hit figures. Pushing the
        // singles much below this was an over-correction.
        #expect(share(1) > 0.40 && share(1) < 0.65, "single hits are \(share(1)) of figures")
        #expect(share(2) > 0.20, "two-hit figures are only \(share(2))")
        #expect(share(3) > 0.05, "three-hit figures are only \(share(3))")
    }

    /// Chill Soho's texture sits right of centre; base Chill's stays where it was.
    @Test func sohoTextureIsPannedRight() {
        func pans(soho: Bool) -> [Float] {
            PlaybackEngine.staticPans(kosmic: false, motorik: false, ambient: false,
                                      chillPads: true, chillSoho: soho)
        }
        #expect(pans(soho: true)[kTrackTexture] > 0.2, "Soho texture pan \(pans(soho: true)[kTrackTexture])")
        #expect(pans(soho: false)[kTrackTexture] == 0, "base Chill texture pan moved")
        // Only the texture moves: the rest of the Chill stage is unchanged.
        for t in 0..<kTrackCount where t != kTrackTexture {
            #expect(pans(soho: true)[t] == pans(soho: false)[t], "track \(t) pan changed")
        }
    }

    /// A Latin song's intro plays its own percussion, not a generic hat pulse.
    @Test func latinIntroPlaysTheLatinGroove() {
        let latinVoices: Set<Int> = [60, 61, 62, 63, 64, 69, 70, 82, 86, 87]
        var checked = 0
        for s in Self.sohoSongs() where s.chillBeatStyle == .sohoLatin {
            guard let intro = s.structure.sections.first(where: { $0.label == .intro }),
                  intro.lengthBars >= 2 else { continue }
            let bars = (intro.startBar + 1)..<intro.endBar     // bar 0 may be a cold-start pickup
            let notes = s.trackEvents[kTrackDrums].filter { bars.contains($0.stepIndex / 16) }
            guard !notes.isEmpty else { continue }
            checked += 1
            let voices = Set(notes.map { Int($0.note) })
            let rim = voices.contains(Int(GMDrum.sidestick.rawValue))
            #expect(!voices.isDisjoint(with: latinVoices) || rim,
                    "intro voices \(voices.sorted()) carry no Latin percussion")
        }
        #expect(checked > 0)
    }

    /// The Latin percussion overlay carries on through the outro.
    @Test func percussionOverlayPlaysInTheOutro() {
        let perc: Set<Int> = [60, 61, 62, 63, 64, 69, 70, 82]
        var checked = 0, withPerc = 0
        for s in Self.sohoSongs() where Self.uses(s, "CHL-DRUM-014") {
            guard let outro = s.structure.sections.first(where: { $0.label == .outro }),
                  outro.lengthBars >= 4 else { continue }
            checked += 1
            let bars = outro.startBar..<(outro.endBar - 2)     // a cold stop silences the last two
            if s.trackEvents[kTrackDrums].contains(where: { bars.contains($0.stepIndex / 16) && perc.contains(Int($0.note)) }) {
                withPerc += 1
            }
        }
        #expect(checked > 0)
        #expect(Double(withPerc) / Double(checked) > 0.9, "outro percussion in \(withPerc)/\(checked)")
    }

    /// Counter-Line is longer than Tight Hook and ranges much wider — the two sounded alike
    /// because both drew on the same cells and rhythms.
    @Test func counterLineIsLongerAndWiderThanTheHook() {
        func stats(_ rule: String) -> (notes: Double, compass: Double) {
            var phrases = 0, notes = 0, compass = 0
            for s in Self.sohoSongs() where Self.lead1Rule(s) == rule {
                let pickups = Self.pickupBars(s)
                let evs = s.trackEvents[kTrackLead1].filter { !pickups.contains($0.stepIndex / 16) }
                    .sorted { $0.stepIndex < $1.stepIndex }
                var run: [MIDIEvent] = []
                func flush() {
                    guard run.count > 1 else { run = []; return }
                    phrases += 1; notes += run.count
                    compass += run.map { Int($0.note) }.max()! - run.map { Int($0.note) }.min()!
                    run = []
                }
                for ev in evs {
                    if let last = run.last, ev.stepIndex - (last.stepIndex + last.durationSteps) > 8 { flush() }
                    run.append(ev)
                }
                flush()
                if phrases > 400 { break }
            }
            guard phrases > 0 else { return (0, 0) }
            return (Double(notes) / Double(phrases), Double(compass) / Double(phrases))
        }
        let line = stats("CHL-LD1-010"), hook = stats("CHL-LD1-012")
        #expect(line.notes > hook.notes + 1.5, "notes/phrase line \(line.notes) hook \(hook.notes)")
        #expect(line.compass > hook.compass + 2, "compass line \(line.compass) hook \(hook.compass)")
    }

    // MARK: - Log lines, breakdown mix, remix shape

    private static func line(_ s: SongState, _ tag: String) -> String {
        s.generationLog.first { $0.tag == tag }?.description ?? ""
    }

    /// The Chords line is key, mode and the A cycle — nothing structural, and short.
    @Test func chordsLineIsJustKeyModeAndTheACycle() {
        for s in Self.sohoSongs() {
            let line = Self.line(s, "Chords")
            for token in ["A:", "B:", "turnaround", "(", "·"] {
                #expect(!line.contains(token), "Chords line carries '\(token)': \(line)")
            }
            #expect(line.count <= 40, "Chords line too long: \(line)")
            #expect(line.hasPrefix(s.frame.key), "Chords line does not open with the key: \(line)")
        }
    }

    /// The Form line carries the structure instead: groove, sections, break and its length,
    /// turnaround. Still short.
    @Test func formLineNamesTheStructure() {
        var sawB = false, sawBreak = false
        for s in Self.sohoSongs() {
            let line = Self.line(s, "Form")
            #expect(line.hasPrefix("Latin groove") || line.hasPrefix("Soul groove"), "Form line: \(line)")
            #expect(line.count <= 64, "Form line too long: \(line)")
            let hasB = s.structure.sections.contains { $0.label == .B }
            #expect(line.contains(hasB ? "A/B" : " - A -") || line.hasSuffix(" - A"), "sections: \(line)")
            if hasB { sawB = true }
            if let bridge = s.structure.sections.first(where: { $0.label == .bridge }) {
                sawBreak = true
                #expect(line.contains("\(bridge.lengthBars)"), "break length missing: \(line)")
            }
        }
        #expect(sawB && sawBreak)
    }

    /// Stop-time is gone from Soho; the other three breakdowns and the remix all appear.
    @Test func sohoBreakdownPoolExcludesStopTime() {
        var seen = Set<ChillBreakdownStyle>()
        for s in Self.sohoSongs() where s.structure.sections.contains(where: { $0.label == .bridge }) {
            seen.insert(s.chillBreakdownStyle)
        }
        #expect(!seen.contains(.stopTime), "stop-time still in the Soho pool")
        #expect(seen.isSuperset(of: [.bassOstinato, .groovePocket, .harmonicDrone, .sohoRemix]), "\(seen)")
    }

    /// The Remix Break is 6, 8 or 12 bars, and more than one length shows up.
    @Test func remixBreakVariesInLength() {
        var lengths = Set<Int>()
        for s in Self.remixSongs() {
            guard let b = s.structure.sections.first(where: { $0.label == .bridge }) else { continue }
            #expect([6, 8, 12].contains(b.lengthBars), "remix break of \(b.lengthBars) bars")
            lengths.insert(b.lengthBars)
        }
        #expect(lengths.count >= 2, "only \(lengths) seen")
    }

    /// The way into the Remix Break answers the way out: the band stops after beat 2 and hits
    /// beats 3 and 4 together — drums, bass and rhythm on the same two steps.
    @Test func remixEntryIsAUnisonFigure() {
        var checked = 0
        for s in Self.remixSongs() {
            guard let bridge = s.structure.sections.first(where: { $0.label == .bridge }),
                  bridge.startBar > 0 else { continue }
            let bar = bridge.startBar - 1
            checked += 1
            for (track, name) in [(kTrackDrums, "drums"), (kTrackBass, "bass"), (kTrackRhythm, "rhythm")] {
                let steps = Set(s.trackEvents[track].filter { $0.stepIndex / 16 == bar }.map { $0.stepIndex % 16 })
                #expect(steps.contains(8) && steps.contains(12), "\(name) entry steps \(steps.sorted())")
                #expect(!steps.contains(where: { (9...11).contains($0) || $0 > 12 }),
                        "\(name) plays through the stop: \(steps.sorted())")
            }
            // A crash lands on the break's downbeat.
            let crash = Int(GMDrum.crash1.rawValue)
            #expect(s.trackEvents[kTrackDrums].contains { $0.stepIndex == bridge.startBar * 16 && Int($0.note) == crash })
        }
        #expect(checked > 0)
    }

    /// The horns answer the two breakdowns that have no voice of their own.
    @Test func hornsAnswerDroneAndPocket() {
        for style in [ChillBreakdownStyle.harmonicDrone, .groovePocket] {
            var checked = 0
            for s in Self.sohoSongs() where s.chillBreakdownStyle == style {
                guard let b = s.structure.sections.first(where: { $0.label == .bridge }) else { continue }
                checked += 1
                let bars = b.startBar..<b.endBar
                #expect(s.trackEvents[kTrackTexture].contains { bars.contains($0.stepIndex / 16) },
                        "\(style): no horns in the break")
            }
            #expect(checked > 0, "no \(style) songs")
        }
    }

    /// A Latin groove pocket is a percussion feature: hand percussion through it, and the kit's
    /// backbeat rim out of the way.
    @Test func latinGroovePocketIsAPercussionFeature() {
        let hands: Set<Int> = [60, 61, 62, 63, 64, 69, 82]
        var checked = 0
        for s in Self.sohoSongs()
        where s.chillBreakdownStyle == .groovePocket && s.chillBeatStyle == .sohoLatin {
            guard let b = s.structure.sections.first(where: { $0.label == .bridge }) else { continue }
            checked += 1
            let bars = b.startBar..<b.endBar
            let inBreak = s.trackEvents[kTrackDrums].filter { bars.contains($0.stepIndex / 16) }
            #expect(inBreak.contains { hands.contains(Int($0.note)) }, "no hand percussion in the pocket")
            #expect(!inBreak.contains { Int($0.note) == Int(GMDrum.sidestick.rawValue) },
                    "the kit's rim still plays through the pocket")
        }
        #expect(checked > 0)
    }

    // MARK: - CHL-BASS-017 Stylish Root Pedal Walk

    /// The bar is in two halves: the root pedalled in eighths, then a walk away from it landing
    /// on the fifth or the flat seventh. Measured 5.8 notes a bar with 36% repeated pitches —
    /// the opposite of CHL-BASS-014, the other Style Council bass, at 2.9 and 2%.
    @Test func rootPedalWalkMatchesItsMeasurements() {
        var found = 0, bars = 0, notes = 0, repeats = 0, intervals = 0
        for s in Self.sohoSongs() where Self.uses(s, "CHL-BASS-017") {
            found += 1
            let groove = Set(Self.grooveBars(s)).subtracting(Self.remixEntry(s))
                .subtracting(Self.turnaroundTreated(s))
            let evs = s.trackEvents[kTrackBass].filter { groove.contains($0.stepIndex / 16) }
            var patterns = Set<[Int]>()
            for (_, inBar) in Dictionary(grouping: evs, by: { $0.stepIndex / 16 }) {
                let steps = Set(inBar.map { $0.stepIndex % 16 })
                #expect(steps.isSubset(of: [0, 1, 2, 3, 4, 6, 7, 8, 10, 12, 14]), "steps \(steps.sorted())")
                #expect(steps.contains(0), "no root on the downbeat: \(steps.sorted())")
                // The first half is the root and nothing else.
                let firstHalf = inBar.filter { $0.stepIndex % 16 < 8 }
                #expect(Set(firstHalf.map(\.note)).count == 1, "first half is not a pedal")
                #expect(inBar.allSatisfy { $0.durationSteps <= 2 }, "a long note in a pedal bar")
                bars += 1; notes += inBar.count
                patterns.insert(steps.sorted())
                let sorted = inBar.sorted { $0.stepIndex < $1.stepIndex }
                for (a, b) in zip(sorted, sorted.dropFirst()) {
                    intervals += 1
                    if a.note == b.note { repeats += 1 }
                }
            }
            if bars >= 40 { #expect(patterns.count >= 2, "one pattern for a whole song") }
        }
        #expect(found > 0)
        let perBar = Double(notes) / Double(bars)
        #expect(perBar > 4.0 && perBar < 7.0, "\(perBar) notes a bar")
        let repeatShare = Double(repeats) / Double(intervals)
        #expect(repeatShare > 0.25, "repeats \(repeatShare) — the pedal is the point")
    }

    /// Every Soho bass rule comes from the groove's own pool, and the Soul pool now leans on
    /// measured rules rather than the three borrowed from base Chill.
    @Test func sohoBassPoolsAreWhatThePlanSays() {
        let latin: Set<String> = ["CHL-BASS-013", "CHL-BASS-012", "CHL-BASS-015", "CHL-BASS-016"]
        let soul:  Set<String> = ["CHL-BASS-014", "CHL-BASS-017", "CHL-BASS-015",
                                  "CHL-BASS-002", "CHL-BASS-004", "CHL-BASS-001"]
        var soulSongs = 0, borrowed = 0
        for s in Self.sohoSongs() {
            let used = Set(s.generationLog.map(\.tag)).filter {
                $0.hasPrefix("CHL-BASS-") && $0 != "CHL-BASS-005" && $0 != "CHL-BASS-006"
            }
            #expect(used.count == 1, "bass rules \(used.sorted())")
            let rule = used.first ?? ""
            if s.chillBeatStyle == .sohoLatin {
                #expect(latin.contains(rule), "Latin song played \(rule)")
            } else {
                #expect(soul.contains(rule), "Soul song played \(rule)")
                soulSongs += 1
                if ["CHL-BASS-001", "CHL-BASS-002", "CHL-BASS-004"].contains(rule) { borrowed += 1 }
            }
        }
        // Borrowed base-Chill rules carried 40% of the Soul pool before CHL-BASS-017, and are now
        // weighted to 30% between them. The bound allows for sampling over the seed range, but is
        // tight enough that weighting them back up would fail it.
        let share = Double(borrowed) / Double(soulSongs)
        #expect(share < 0.33, "base-Chill bass rules carry \(share) of Soul songs")
    }

    // MARK: - The intro

    /// Four bars, or none. An eight-bar intro of percussion and one bass note a bar was the least
    /// musical thing the substyle did.
    @Test func sohoIntroIsShortOrAbsent() {
        var lengths: [Int: Int] = [:]
        let songs = Self.sohoSongs()
        for s in songs {
            let bars = s.structure.sections.first { $0.label == .intro }?.lengthBars ?? 0
            #expect(bars == 0 || bars == 4, "intro of \(bars) bars")
            lengths[bars, default: 0] += 1
        }
        // Skipping the intro stays occasional.
        let none = Double(lengths[0] ?? 0) / Double(songs.count)
        #expect(none > 0.08 && none < 0.24, "\(none) of songs open cold")
    }

    /// The intro builds: each bar carries more than the one before, rather than holding one
    /// texture until the groove arrives.
    @Test func sohoIntroGainsMomentum() {
        var totals = [0, 0, 0, 0], counted = 0
        for s in Self.sohoSongs() {
            guard let intro = s.structure.sections.first(where: { $0.label == .intro }),
                  intro.lengthBars == 4,
                  case .alreadyPlaying = s.structure.introStyle else { continue }  // a cold start silences bar 1
            counted += 1
            for i in 0..<4 {
                let bar = intro.startBar + i
                totals[i] += (0..<kTrackCount).reduce(0) { $0 + s.trackEvents[$1].filter { $0.stepIndex / 16 == bar }.count }
            }
        }
        #expect(counted > 0)
        let avg = totals.map { Double($0) / Double(counted) }
        #expect(avg[1] > avg[0], "bar 2 (\(avg[1])) is no fuller than bar 1 (\(avg[0]))")
        #expect(avg[2] > avg[1], "bar 3 (\(avg[2])) is no fuller than bar 2 (\(avg[1]))")
    }

    /// The Rhythm track enters before the groove does — it used to be silent through every intro.
    @Test func rhythmEntersDuringTheIntro() {
        var checked = 0, playing = 0
        for s in Self.sohoSongs() {
            guard let intro = s.structure.sections.first(where: { $0.label == .intro }),
                  intro.lengthBars == 4 else { continue }
            checked += 1
            // The comping enters on the intro's second-to-last bar, or its last where the bass
            // leads instead. It is never earlier: it is a late layer, not an opening one.
            let bassLeads = ChillStructureGenerator.sohoBassLeadsIntro(frame: s.frame, structure: s.structure)
            let entry = intro.endBar - (bassLeads ? 1 : 2)
            if s.trackEvents[kTrackRhythm].contains(where: { $0.stepIndex / 16 >= entry }) { playing += 1 }
            #expect(!s.trackEvents[kTrackRhythm].contains { (intro.startBar..<entry).contains($0.stepIndex / 16) },
                    "comping plays before its entry bar")
        }
        #expect(checked > 0)
        // Allows for the rhythm's own rest bars and dropouts landing on an intro bar.
        #expect(Double(playing) / Double(checked) > 0.8, "rhythm entered in only \(playing)/\(checked)")
    }

    /// A crash marks the arrival of the groove. No Soho song had one, so the density simply
    /// trebled with nothing announcing it.
    @Test func theGrooveArrivesOnACrash() {
        let crash = Int(GMDrum.crash1.rawValue)
        var checked = 0
        for s in Self.sohoSongs() {
            guard let intro = s.structure.sections.first(where: { $0.label == .intro }),
                  intro.lengthBars > 0,
                  let a = s.structure.sections.first(where: { $0.label == .A }) else { continue }
            checked += 1
            #expect(s.trackEvents[kTrackDrums].contains { $0.stepIndex == a.startBar * 16 && Int($0.note) == crash },
                    "no crash on the downbeat of A")
        }
        #expect(checked > 0)
    }

    /// The bass holds the root through the intro and plays its own figure on the LAST intro bar —
    /// not once section A has started. A layer-counted version deferred it past the end of a
    /// cold-start intro, so the lift landed a bar late.
    @Test func bassFindsItsFigureOnTheLastIntroBar() {
        var checked = 0, lifted = 0
        for s in Self.sohoSongs() {
            guard let intro = s.structure.sections.first(where: { $0.label == .intro }),
                  intro.lengthBars == 4 else { continue }
            checked += 1
            func count(_ bar: Int) -> Int { s.trackEvents[kTrackBass].filter { $0.stepIndex / 16 == bar }.count }
            // The figure arrives on the intro's second-to-last bar when the bass leads, otherwise
            // on its last. Everything before that is a holding pattern: at most the root, its
            // half-bar repeat and a pickup.
            let bassLeads = ChillStructureGenerator.sohoBassLeadsIntro(frame: s.frame, structure: s.structure)
            let entry = intro.endBar - (bassLeads ? 2 : 1)
            for bar in intro.startBar..<entry {
                #expect(count(bar) <= 3, "bass plays \(count(bar)) notes in intro bar \(bar - intro.startBar + 1)")
            }
            if count(entry) > count(entry - 1) { lifted += 1 }
        }
        #expect(checked > 0)
        // Not every rule's bar is busy — Root Sustain and a sparse Melodic Bass bar are quiet by
        // design — but the great majority should lift into the groove.
        #expect(Double(lifted) / Double(checked) > 0.70, "bass lifted in only \(lifted)/\(checked)")
    }

    /// The intro alternates which of the bass and the comping enters first, so the build is not
    /// the same shape every song. Whichever leads enters a bar before the other.
    @Test func introEntryOrderAlternates() {
        var bassFirst = 0, rhythmFirst = 0
        for s in Self.sohoSongs() {
            guard let intro = s.structure.sections.first(where: { $0.label == .intro }),
                  intro.lengthBars == 4 else { continue }
            let bassLeads = ChillStructureGenerator.sohoBassLeadsIntro(frame: s.frame, structure: s.structure)
            bassLeads ? (bassFirst += 1) : (rhythmFirst += 1)

            // The two never enter on the same bar — that was the lopsided build Zack heard.
            let bassEntry   = intro.endBar - (bassLeads ? 2 : 1)
            let rhythmEntry = intro.endBar - (bassLeads ? 1 : 2)
            #expect(bassEntry != rhythmEntry)
            #expect(!s.trackEvents[kTrackRhythm].contains { $0.stepIndex / 16 < rhythmEntry
                                                            && $0.stepIndex / 16 >= intro.startBar },
                    "comping before its entry bar")
        }
        let total = bassFirst + rhythmFirst
        #expect(total > 0)
        let share = Double(bassFirst) / Double(total)
        #expect(share > 0.35 && share < 0.65, "bass leads \(share) of intros — not an even split")
    }

    /// King's Road carries its own thoroughfare word, so nothing is appended to it.
    @Test func kingsRoadIsANamedStreet() {
        #expect(ChillTitleGenerator.sohoNamedStreets.contains("King's Road"))
        #expect(ChillTitleGenerator.sohoVocabulary.contains("King's Road"))
        #expect(!ChillTitleGenerator.sohoStreets.contains("King's Road"), "would render as King's Road Street")
        var seen = Set<String>()
        for seed in UInt64(1)...4000 {
            var rng = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: 93))
            let t = ChillTitleGenerator.generateSoho(rng: &rng)
            if t.contains("King's Road") { seen.insert(t) }
        }
        #expect(seen.count >= 3, "King's Road appeared in \(seen.count) distinct titles")
        #expect(!seen.contains { $0.contains("King's Road Street") })
    }

    // MARK: - The turnaround is performed, not just written

    /// The bass plays the turnaround's last two bars as a turnaround, not as the groove over
    /// different chords. Three treatments plus the original form, varying within a song.
    @Test func bassPlaysTheTurnaroundAsATurnaround() {
        var seen = Set<Int>(), checked = 0
        for s in Self.sohoSongs() {
            let turns = Self.turnaroundBars(s)
            let exits = Self.turnaroundExit(s)
            // The way into a Remix Break is a bigger gesture and takes precedence, so a bar that
            // is both is not a turnaround bar for this purpose.
            let entry = Self.remixEntry(s)
            for (i, exit) in exits.sorted().enumerated() where turns.contains(exit - 1) {
                let style = ChillStructureGenerator.sohoTurnaroundStyle(
                    frame: s.frame, structure: s.structure, index: i)
                let pedal = style == 3 || style == 4
                seen.insert(style)
                func bass(_ bar: Int) -> [MIDIEvent] {
                    s.trackEvents[kTrackBass].filter { $0.stepIndex / 16 == bar }
                        .sorted { $0.stepIndex < $1.stepIndex }
                }
                guard !entry.contains(exit), !entry.contains(exit - 1) else { continue }
                // The original form has no figure to check — the groove rides through, and what
                // it plays is whatever the bar's own rule wrote.
                guard style != ChillStructureGenerator.sohoTurnaroundOriginal else { continue }
                let pair = [exit - 1, exit].map(bass)
                guard pair.allSatisfy({ !$0.isEmpty }) else { continue }
                checked += 1
                for inBar in pair {
                    let steps = inBar.map { $0.stepIndex % 16 }
                    switch style {
                    case 0:  // walking quarters — four of them, and a real line, not a repeat
                        #expect(steps == [0, 4, 8, 12], "walking bar steps \(steps)")
                        #expect(Set(inBar.map(\.note)).count >= 3, "walk repeats itself")
                    case 1:  // root and approach — a held root, then a pickup
                        #expect(steps.first == 0, "root & approach does not start on the root")
                        #expect(inBar[0].durationSteps >= 8, "the root is not held")
                        #expect(steps.contains(14), "no pickup into the next chord")
                    case 2, 3, 4:
                        // Descending: two notes a bar, or four when the root pedals under them
                        // — "ba-baa", the root short on the beat, the line on the eighth. A pair
                        // whose pedal would clash with the line drops it, so a pedalled bar can
                        // carry three steps rather than four.
                        #expect(Set(steps).isSubset(of: [0, 2, 8, 10]) && steps.contains(0)
                                && steps.contains(8), "descending bar steps \(steps)")
                        if !pedal { #expect(steps == [0, 8], "plain descending has a pedal") }
                        let roots = inBar.filter { $0.durationSteps <= 2 }
                        #expect(roots.allSatisfy { [0, 8].contains($0.stepIndex % 16) },
                                "a pedal is off the beat")
                        #expect(roots.allSatisfy { $0.note >= 40 && $0.note <= 52 },
                                "a pedal leaves the bass window")
                    default:
                        Issue.record("unknown turnaround treatment \(style)")
                    }
                }
                // The descending treatment falls across both bars — every step strictly down.
                // This asserted only `>=` until 2026-10-12, which four identical notes satisfy;
                // 55% of these turnarounds were clamping against the top of the bass ladder and
                // not descending at all, and the test passed throughout.
                if [2, 3, 4].contains(style) {
                    // When the root pedals, the line is the notes on the eighths; the pedal
                    // itself holds, so only the line is expected to fall.
                    let all = pair[0] + pair[1]
                    // Style 3 is a pedal point: one note under all four pairs, held through the
                    // chord change. Style 4 re-roots per bar, by design (Zack, 2026-10-12).
                    let roots = all.filter { $0.durationSteps <= 2 }.map { Int($0.note) }
                    if style == 3 { #expect(Set(roots).count <= 1, "the pedal moves: \(roots)") }
                    // Nowhere in the figure may two notes in a row sound the same pitch — that
                    // reads as one repeated note rather than as an alternation.
                    let seq = all.sorted { $0.stepIndex < $1.stepIndex }.map { Int($0.note) }
                    #expect(!zip(seq, seq.dropFirst()).contains { $0 == $1 },
                            "two notes in a row at the same pitch: \(seq)")
                    let line = (pedal ? all.filter { [2, 10].contains($0.stepIndex % 16) } : all)
                        .map { Int($0.note) }
                    #expect(zip(line, line.dropFirst()).allSatisfy { $0 > $1 },
                            "descending line does not descend: \(line)")
                }
            }
        }
        #expect(checked > 0)
        #expect(seen == Set(ChillStructureGenerator.sohoTurnaroundTreatments),
                "only styles \(seen.sorted()) appeared")
    }

    /// The last note of a turnaround is a step away from the chord the song returns to.
    @Test func theApproachLandsNextToTheTonic() {
        var checked = 0, adjacent = 0
        for s in Self.sohoSongs() {
            for exit in Self.turnaroundExit(s).sorted() {
                guard let last = s.trackEvents[kTrackBass]
                        .filter({ $0.stepIndex / 16 == exit })
                        .max(by: { $0.stepIndex < $1.stepIndex }),
                      let landing = s.trackEvents[kTrackBass]
                        .filter({ $0.stepIndex / 16 == exit + 1 })
                        .min(by: { $0.stepIndex < $1.stepIndex }) else { continue }
                checked += 1
                if abs(Int(last.note) - Int(landing.note)) <= 2 { adjacent += 1 }
            }
        }
        #expect(checked > 0)
        #expect(Double(adjacent) / Double(checked) > 0.6, "approach landed adjacent \(adjacent)/\(checked)")
    }

    /// The horns mark the turnaround in some songs but not all — at every turnaround of every
    /// song it stops being a gesture.
    @Test func hornsMarkSomeTurnaroundsButNotAll() {
        var with = 0, total = 0
        for s in Self.sohoSongs() {
            let firsts = Self.turnaroundBars(s).filter { !Self.turnaroundBars(s).contains($0 - 1) }
            guard !firsts.isEmpty else { continue }
            total += 1
            if s.trackEvents[kTrackTexture].contains(where: { firsts.contains($0.stepIndex / 16)
                                                              && $0.stepIndex % 16 == 0 }) { with += 1 }
        }
        #expect(total > 0)
        let share = Double(with) / Double(total)
        #expect(share > 0.35 && share < 0.85, "horns on \(share) of songs' turnarounds")
    }

    /// Denmark Street keeps its "Street", and the Borderline is a venue.
    @Test func denmarkStreetAndTheBorderline() {
        #expect(ChillTitleGenerator.sohoStreets.contains("Denmark"))
        #expect(!ChillTitleGenerator.sohoStreetsKnown.contains("Denmark"), "would render bare as the country")
        #expect(ChillTitleGenerator.sohoVenues.contains { $0.name == "Borderline" && $0.article })
        var denmark = 0, borderline = 0
        for seed in UInt64(1)...6000 {
            var rng = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: 93))
            let t = ChillTitleGenerator.generateSoho(rng: &rng)
            if t.contains("Denmark") {
                #expect(t.contains("Denmark Street"), "bare Denmark reads as the country: \(t)")
                denmark += 1
            }
            if t.contains("Borderline") { borderline += 1 }
        }
        #expect(denmark > 0 && borderline > 0)
    }

    /// The turnaround is marked in the performance log for both Chill substyles, and no longer
    /// clutters the Form line.
    @Test func turnaroundIsInThePerformanceLog() {
        var soho = 0, blues = 0, sohoN = 0, bluesN = 0
        for seed in Self.seeds {
            let s = SongGenerator.generate(seed: seed, style: .chill)
            let marked = s.stepAnnotations.values.contains { $0.contains { $0.tag == "Turnaround" } }
            // Soho names which treatment the bass is using; Blues has none, so no description.
            if s.chillSohoVariation {
                let names = ChillStructureGenerator.sohoTurnaroundStyleNames + ["original form"]
                let desc = s.stepAnnotations.values.flatMap { $0 }.first { $0.tag == "Turnaround" }?.description
                #expect(desc.map(names.contains) == true, "turnaround logged as '\(desc ?? "nil")'")
            }
            #expect(s.generationLog.first { $0.tag == "Form" }?.description.contains("turnaround") != true,
                    "Form line still names the turnaround")
            if s.chillSohoVariation { sohoN += 1; if marked { soho += 1 } }
            else if s.chillBluesVariation { bluesN += 1; if marked { blues += 1 } }
        }
        #expect(sohoN > 0 && soho == sohoN, "Soho: \(soho)/\(sohoN) marked")
        #expect(bluesN > 0 && blues == bluesN, "Blues: \(blues)/\(bluesN) marked")
    }


    /// Both major turnarounds appear, and the bright one has no minor chord in it. Every chord in
    /// either stays inside the mode, so nothing needs snapping.
    @Test func bothMajorTurnaroundsAreUsed() {
        let minorChords: Set<ChordType> = [.min7, .min9, .min6, .min7b5, .minor]
        for mode in [Mode.Ionian, .Mixolydian] {
            let measured = SongGenerator.sohoTurnaround(mode: mode, tonicType: .maj9, bright: false)
            let bright   = SongGenerator.sohoTurnaround(mode: mode, tonicType: .maj9, bright: true)
            #expect(measured.map(\.0) != bright.map(\.0), "\(mode): the two turnarounds are identical")
            #expect(!bright.contains { minorChords.contains($0.1) }, "\(mode): bright turnaround has a minor chord")
            let scale = Set(mode.intervals.map { $0 % 12 })
            for (deg, type) in measured + bright {
                let tones = Set(type.intervals.map { (degreeSemitone(deg) + $0) % 12 })
                #expect(tones.isSubset(of: scale), "\(mode) \(deg)\(type) leaves the scale")
            }
        }
        for mode in [Mode.Dorian, .Aeolian] {
            #expect(SongGenerator.sohoTurnaround(mode: mode, tonicType: .min9, bright: false).map(\.0)
                    == SongGenerator.sohoTurnaround(mode: mode, tonicType: .min9, bright: true).map(\.0))
        }
    }

    /// Portobello Road carries its own thoroughfare word; Meard Street is gone.
    @Test func portobelloRoadReplacesMeard() {
        #expect(ChillTitleGenerator.sohoNamedStreets.contains("Portobello Road"))
        #expect(!ChillTitleGenerator.sohoStreets.contains("Meard"))
        var meard = 0, portobello = 0
        for seed in UInt64(1)...6000 {
            var rng = SeededRNG(seed: SeededRNG.trackSeed(globalSeed: seed, trackIndex: 93))
            let t = ChillTitleGenerator.generateSoho(rng: &rng)
            if t.contains("Meard") { meard += 1 }
            if t.contains("Portobello Road") {
                portobello += 1
                #expect(!t.contains("Portobello Road Street"))
            }
        }
        #expect(meard == 0 && portobello > 0, "Meard \(meard), Portobello Road \(portobello)")
    }

    /// The Remix Break's backbeat is not always handclaps. Every break sounding identical is what
    /// gives the device away.
    @Test func remixBackbeatVariesItsVoice() {
        let voices: Set<Int> = [Int(GMDrum.clap.rawValue), Int(GMDrum.tambourine.rawValue),
                                Int(GMDrum.sidestick.rawValue)]
        var seen = Set<Int>(), checked = 0
        for s in Self.remixSongs() {
            guard let b = s.structure.sections.first(where: { $0.label == .bridge }),
                  b.lengthBars > 2 else { continue }
            let bars = (b.startBar + 2)..<(b.endBar - 1)
            let backbeat = Set(s.trackEvents[kTrackDrums]
                .filter { bars.contains($0.stepIndex / 16) && [4, 12].contains($0.stepIndex % 16) }
                .map { Int($0.note) })
                .intersection(voices)
            guard !backbeat.isEmpty else { continue }
            checked += 1
            // One voice for the whole break, not a mixture.
            #expect(backbeat.count == 1, "remix backbeat uses \(backbeat.sorted())")
            seen.formUnion(backbeat)
        }
        #expect(checked > 0)
        #expect(seen == voices, "only \(seen.sorted()) of the three backbeat voices appeared")
    }
}
