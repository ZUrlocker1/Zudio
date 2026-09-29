// MotorikSyncTests.swift — pins the Kraftwerk sync field against silent loss.
//
// Run with:
//   swift test --filter MotorikSyncTests
//
// WHY THIS EXISTS
// SongState's withXxx() copy methods construct a fresh SongState by listing every field
// explicitly. A field omitted from one of them does not fail to compile — it silently takes
// the init default. For motorikSync that default is `.none`, so a missed copy method would
// quietly cancel the sync partway through generation, and the only symptom would be a song
// that half-sounds like Kraftwerk.
//
// These tests round-trip a non-default sync through every copy method. Add a case here
// whenever a new withXxx() is added to SongState.

import Testing
import Foundation
@testable import Zudio

@Suite struct MotorikSyncTests {

    /// A minimal Motorik song carrying a non-default sync.
    private func syncedState(_ sync: MotorikSync = .sequenceLock) -> SongState {
        let g = SongGenerator.generate(seed: 4242, style: .motorik)
        // Argument order must match the initialiser exactly; everything other than
        // motorikSync is copied straight from the generated song.
        return SongState(
            frame: g.frame, structure: g.structure, tonalMap: g.tonalMap,
            trackEvents: g.trackEvents, globalSeed: g.globalSeed,
            trackOverrides: g.trackOverrides, title: g.title, form: g.form, style: g.style,
            percussionStyle: g.percussionStyle, kosmicProgFamily: g.kosmicProgFamily,
            generationLog: g.generationLog, stepAnnotations: g.stepAnnotations,
            motorikSync: sync)
    }

    // MARK: - The copy methods

    @Test func survivesWithAmbientBrushKit() throws {
        let s = syncedState().withAmbientBrushKit(true)
        #expect(s.motorikSync == .sequenceLock)
    }

    @Test func survivesWithFrame() throws {
        let original = syncedState()
        let s = original.withFrame(original.frame)
        #expect(s.motorikSync == .sequenceLock)
    }

    @Test func survivesWithAmbientAudioTexture() throws {
        let s = syncedState().withAmbientAudioTexture("light_rain.m4a", offset: 15)
        #expect(s.motorikSync == .sequenceLock)
    }

    @Test func survivesWithChillAudioTexture() throws {
        let s = syncedState().withChillAudioTexture("harbor.m4a")
        #expect(s.motorikSync == .sequenceLock)
    }

    /// Chained, because a single surviving hop proves less than a sequence of them.
    @Test func survivesChainedCopies() throws {
        let s = syncedState(.machineVoice)
            .withAmbientBrushKit(false)
            .withChillAudioTexture(nil)
            .withAmbientAudioTexture(nil)
        #expect(s.motorikSync == .machineVoice)
    }

    // MARK: - Membership

    /// Bass is the one track in every group; Lead 2 is never listed, since the generator
    /// decides it. Pads is never synced — it is what keeps playing through a dropout, which is
    /// what makes the drop read as a section change rather than the song stopping.
    @Test func membershipInvariants() throws {
        for c in MotorikSync.allCases where c != .none {
            #expect(c.includes(kTrackBass), "\(c) must include Bass")
            #expect(!c.includes(kTrackLead2), "\(c) must not list Lead 2 — the generator decides it")
            #expect(!c.includes(kTrackPads), "\(c) must not include Pads")
            #expect(c.tracks.count == Set(c.tracks).count, "\(c) lists a track twice")
        }
        // Every rule written for the sync must be reachable from at least one group.
        for track in [kTrackBass, kTrackDrums, kTrackRhythm, kTrackLead1, kTrackTexture] {
            #expect(MotorikSync.allCases.contains { $0.includes(track) },
                    "no sync group includes track \(track) — its Kraftwerk rules can never fire")
        }
    }

    @Test func syncMembershipMatchesPlan() throws {
        #expect(MotorikSync.rhythmSection.tracks.sorted() == [kTrackBass, kTrackDrums, kTrackLead1].sorted())
        #expect(MotorikSync.sequenceLock.tracks.sorted()  == [kTrackBass, kTrackRhythm, kTrackTexture].sorted())
        #expect(MotorikSync.machineVoice.tracks.sorted()  == [kTrackBass, kTrackRhythm, kTrackLead1].sorted())
        // The log line must name exactly what the group contains.
        for c in MotorikSync.allCases where c != .none {
            #expect(c.logTrackNames.count == c.tracks.count,
                    "\(c): log names \(c.logTrackNames) do not match tracks \(c.tracks)")
        }
    }

    @Test func noneIsInert() throws {
        #expect(MotorikSync.none.tracks.isEmpty)
        #expect(!MotorikSync.none.isActive)
        for t in 0..<kTrackCount { #expect(!MotorikSync.none.includes(t)) }
    }

    // MARK: - The roll

    /// Sync groups are base-Motorik only. A Noir or Arcade song must never draw one, or the
    /// substyle's own carefully weighted rule pools would be overridden.
    @Test func noirAndArcadeNeverSync() throws {
        for seed in UInt64(1)...400 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            if s.motorikNoirVariation || s.motorikArcadeVariation {
                #expect(s.motorikSync == .none,
                        "seed \(seed): \(s.displayStyleName) drew \(s.motorikSync)")
            }
        }
    }

    /// Distribution within base Motorik: none 67.2 / rhythmSection 13.1 / sequenceLock 11.3 /
    /// machineVoice 8.4. Tolerances are wide enough to absorb sampling noise but tight enough
    /// to catch a threshold typo.
    ///
    /// Also checks the split of ALL Motorik, which is what the numbers are actually tuned
    /// against: regular 41 / Noir 20 / Arcade 19 / Europe 20. The sync share only means anything
    /// in combination with the substyle roll, and the two are set in different places.
    @Test func syncDistributionMatchesPlan() throws {
        var counts: [MotorikSync: Int] = [:]
        var base = 0, noir = 0, arcade = 0, total = 0
        for seed in UInt64(1)...4000 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            total += 1
            if s.motorikNoirVariation { noir += 1; continue }
            if s.motorikArcadeVariation { arcade += 1; continue }
            base += 1
            counts[s.motorikSync, default: 0] += 1
        }
        func pct(_ c: MotorikSync) -> Double { 100.0 * Double(counts[c] ?? 0) / Double(base) }
        #expect(base > 500, "need a reasonable base-Motorik sample, got \(base)")
        #expect(abs(pct(.none)          - 67.2) < 5, "none \(pct(.none))%")
        #expect(abs(pct(.rhythmSection) - 13.1) < 4, "rhythmSection \(pct(.rhythmSection))%")
        #expect(abs(pct(.sequenceLock)  - 11.3) < 4, "sequenceLock \(pct(.sequenceLock))%")
        #expect(abs(pct(.machineVoice)  -  8.4) < 4, "machineVoice \(pct(.machineVoice))%")

        let syncs = base - (counts[.none] ?? 0)
        func all(_ n: Int) -> Double { 100.0 * Double(n) / Double(total) }
        #expect(abs(all(counts[.none] ?? 0) - 41) < 3, "regular Motorik \(all(counts[.none] ?? 0))%")
        #expect(abs(all(noir)   - 20) < 3, "Noir \(all(noir))%")
        #expect(abs(all(arcade) - 19) < 3, "Arcade \(all(arcade))%")
        #expect(abs(all(syncs)  - 20) < 3, "Motorik Europe \(all(syncs))%")
    }

    /// The roll must come from a stream derived from the seed, never the shared generator
    /// RNG — drawing from the shared stream would shift every later draw and change what
    /// every previously generated Motorik song produces. Determinism is the observable part.
    /// Same seed, same output. This is the contract the whole saved-song feature rests on:
    /// a .zudio file stores a seed, and reloading regenerates from it.
    // MARK: - Sync rules

    /// Every sync track must actually draw a Kraftwerk rule, and Lead 2 must never draw a
    /// normal Motorik rule when Rhythm is synced — a melodic Lead 2 over a rigid
    /// two-pitch-class sequencer is the incoherence the whole sync design exists to prevent.
    @Test func syncTracksDrawKraftwerkRules() throws {
        let kraftwerk: [Int: [String]] = [
            kTrackDrums:   ["Sequenced Timekeeper", "Sparse Accents"],
            kTrackRhythm:  ["Two-Note Lock", "Paired Sequencer"],
            kTrackLead1:   ["Short Statement", "Long Run"],
            kTrackTexture: ["Wide Scatter", "Sparse Punctuation"],
        ]
        var checked = 0
        for seed in UInt64(1)...600 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.isActive else { continue }
            checked += 1
            let log = s.generationLog.map(\.description).joined(separator: " | ")
            // The sync line carries "KW" in its TAG, so check the entry rather than the
            // joined descriptions.
            #expect(s.generationLog.contains { $0.tag.hasPrefix("Sync ") },
                    "seed \(seed): no Sync line")
            for (track, names) in kraftwerk where s.motorikSync.includes(track) {
                #expect(names.contains { log.contains($0) },
                        "seed \(seed) \(s.motorikSync): track \(track) drew no Kraftwerk rule — \(log)")
            }
            // Bass draws from a four-option pool, two of which are pre-existing Kraftwerk rules.
            if s.motorikSync.includes(kTrackBass) {
                let bass = ["Locked Micro-Cell", "Restricted Run", "Kraftwerk", "Electro Pump"]
                #expect(bass.contains { log.contains($0) }, "seed \(seed): bass drew outside the sync pool")
            }
        }
        #expect(checked > 40, "expected a reasonable sync sample, got \(checked)")
    }

    /// Lead 2 partners with Rhythm or rests — it never plays its own material in a sync.
    @Test func syncLead2EitherPartnersOrRests() throws {
        for seed in UInt64(1)...600 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.includes(kTrackRhythm) else { continue }
            let log = s.generationLog.map(\.description).joined(separator: " | ")
            let partners = log.contains("Counter Sequencer") || log.contains("Octave Unison")
            let silent   = s.trackEvents[kTrackLead2].isEmpty
            #expect(partners || silent, "seed \(seed): Lead 2 neither partnered nor rested — \(log)")
            // Octave Unison is strict unison: every event must sit on a Rhythm event's step.
            if log.contains("Octave Unison") {
                let rhythmSteps = Set(s.trackEvents[kTrackRhythm].map(\.stepIndex))
                #expect(s.trackEvents[kTrackLead2].allSatisfy { rhythmSteps.contains($0.stepIndex) },
                        "seed \(seed): Octave Unison drifted off Rhythm's grid")
            }
        }
    }

    /// Sync songs sit in Kraftwerk's measured tempo band; everything else is untouched.
    @Test func syncSongsUseTheSlowerTempoBand() throws {
        var sync: [Int] = [], plain: [Int] = []
        for seed in UInt64(1)...600 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard !s.motorikNoirVariation && !s.motorikArcadeVariation else { continue }
            if s.motorikSync.isActive { sync.append(s.frame.tempo) } else { plain.append(s.frame.tempo) }
        }
        #expect(!sync.isEmpty && !plain.isEmpty)
        #expect(sync.allSatisfy { (120...132).contains($0) },
                "sync tempo outside 120-132: \(sync.filter { !(120...132).contains($0) })")
        // The base band must not have moved — this change is for sync songs only.
        #expect(plain.allSatisfy { (126...154).contains($0) },
                "non-sync tempo outside 126-154: \(plain.filter { !(126...154).contains($0) })")
    }

    /// A sync fills at exactly one kind of moment: the whole sync dropping out together,
    /// and returning. Nowhere else.
    ///
    /// Removing every fill made the arrangement read as unbroken; keeping the normal ones made
    /// it sound like a drummer. What must not come back: the every-eighth-bar periodic fills,
    /// the generic instrument-entrance fills (Texture and Lead 1 are deliberately sparse, so
    /// those fired almost continuously), and fills at ordinary section boundaries.
    @Test func syncFillsOnlyAtDropoutEdges() throws {
        // Notes the two Kraftwerk kits never play — their presence means a fill ran.
        let fillOnly: Set<UInt8> = [41, 43, 48, 50, 49]
        var counts: [Int] = []
        for seed in UInt64(1)...500 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.includes(kTrackDrums) else { continue }

            let fillBars = Set(s.trackEvents[kTrackDrums].filter { fillOnly.contains($0.note) }
                                                        .map { $0.stepIndex / 16 })
            counts.append(fillBars.count)

            // A window contributes at most two seams, so two windows cap a song at four.
            #expect(fillBars.count <= 4,
                    "seed \(seed): \(fillBars.count) fills — more than the dropout edges can explain")

            var seams = Set<Int>()
            for w in SongGenerator.syncDropoutWindows(sync: s.motorikSync,
                                                         totalBars: s.frame.totalBars, seed: s.globalSeed) {
                // The fill sits on the bar before the drop and the bar before the return; allow
                // one bar either side, since the dropout can silence the exact seam bar.
                seams.formUnion([w.lowerBound - 2, w.lowerBound - 1, w.lowerBound,
                                 w.upperBound - 2, w.upperBound - 1, w.upperBound, w.upperBound + 1])
            }
            for bar in fillBars {
                #expect(seams.contains(bar),
                        "seed \(seed): fill at bar \(bar + 1) is not at a dropout edge")
            }
        }
        #expect(!counts.isEmpty)
    }

    /// The log must not report fills that never played.
    ///
    /// The annotation pass mirrors the normal drum pass rather than reading the engine's
    /// output, so for a sync it described the fills a NON-sync song would have had — and
    /// `fillBeats` reads a fill's length from where the hi-hat stops, which for kits that have
    /// no hi-hat at all measured every bar as a 3-beat cascade. One song logged fifteen fills
    /// while its drum track contained one.
    @Test func syncFillLogMatchesWhatActuallyPlayed() throws {
        let tomMarkers: Set<UInt8> = [41, 43, 48, 50]
        for seed in UInt64(1)...400 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.isActive else { continue }

            let realFillBars = Set(s.trackEvents[kTrackDrums]
                .filter { tomMarkers.contains($0.note) }
                .map { $0.stepIndex / 16 })

            for (step, entries) in s.stepAnnotations {
                for entry in entries where entry.tag == "Drum fill" {
                    let bar = step / 16
                    #expect(realFillBars.contains(bar) || realFillBars.contains(bar + 1),
                            "seed \(seed): log claims a fill at bar \(bar + 1) but the drums have none")
                    // The engine never draws a 3-beat fill for a sync.
                    #expect(!entry.description.contains("3 beat"),
                            "seed \(seed) bar \(bar + 1): logged \"\(entry.description)\" — 3-beat fills are not drawn in a sync")
                }
            }
        }
    }

    /// Wood block does not belong in Motorik, and never appears.
    ///
    /// It was briefly the alternate timekeeper for MOT-DRUM-013. Eight to the bar it reads as
    /// knocking rather than timekeeping — a hard transient with no decay, unlike a hat.
    @Test func woodBlockNeverPlays() throws {
        for seed in UInt64(1)...500 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            #expect(!s.trackEvents[kTrackDrums].contains { $0.note == 76 || $0.note == 77 },
                    "seed \(seed): a wood block is playing")
        }
    }

    /// The Sequenced Timekeeper is accented rather than flat, so eight hits a bar read as a
    /// pulse instead of a drone. The corpus measures flat velocity, but the Evidence Base lists
    /// that as an artefact of the fan transcriptions, and a step sequencer has per-step accents.
    @Test func sequencedTimekeeperIsAccented() throws {
        var checked = 0
        for seed in UInt64(1)...600 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.includes(kTrackDrums),
                  s.generationLog.contains(where: { $0.description == "Sequenced Timekeeper" }) else { continue }
            checked += 1
            // Timekeeping runs on the hats; beats must be louder than the "and" steps.
            let hats = s.trackEvents[kTrackDrums].filter { $0.note == 42 || $0.note == 44 }
            let onBeat  = hats.filter { $0.stepIndex % 4 == 0 }.map(\.velocity)
            let offBeat = hats.filter { $0.stepIndex % 4 != 0 }.map(\.velocity)
            #expect(!onBeat.isEmpty && !offBeat.isEmpty, "seed \(seed): timekeeper missing a half")
            #expect((onBeat.min() ?? 0) > (offBeat.max() ?? 255),
                    "seed \(seed): offbeats are not softer than beats — the accent is gone")
        }
        #expect(checked > 5, "expected a reasonable sample, got \(checked)")
    }

    /// Every synced track plays in key.
    ///
    /// MOT-RTHM-014/015 build their cells from fixed semitone offsets above the chord root —
    /// root, fifth, octave, third, fourth — which is how the corpus describes them, and which
    /// is not diatonic in every mode: a minor third above the root is G natural in E Lydian,
    /// where the scale has G#. Three of MOT-RTHM-015's six offsets were wrong in that key.
    /// Nothing downstream catches it either, since HarmonicFilter's clash pass covers only the
    /// two leads and never checks Rhythm's pitches at all.
    @Test func syncedTracksStayInScale() throws {
        var offScale = 0, checked = 0, songs = 0
        for seed in UInt64(1)...400 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.isActive else { continue }
            songs += 1
            let scale = s.frame.scalePCs
            for track in s.motorikSync.tracks where track != kTrackDrums {
                for e in s.trackEvents[track] {
                    checked += 1
                    if !scale.contains(Int(e.note) % 12) { offScale += 1 }
                }
            }
        }
        #expect(songs > 20, "expected a reasonable sync sample, got \(songs)")
        // Rhythm must be exactly clean: its rules build pitches from fixed offsets, so any
        // non-diatonic note there is a snapping failure rather than a harmonic choice.
        var rhythmOff = 0
        for seed in UInt64(1)...400 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.includes(kTrackRhythm) else { continue }
            let scale = s.frame.scalePCs
            rhythmOff += s.trackEvents[kTrackRhythm].filter { !scale.contains(Int($0.note) % 12) }.count
        }
        #expect(rhythmOff == 0, "\(rhythmOff) Rhythm notes are out of scale")

        // Across the other synced tracks a few chromatic notes are legitimate — the reused
        // pre-existing rules use them deliberately — but a synced song must be no more
        // chromatic than an ordinary Motorik one.
        let rate = Double(offScale) / Double(max(1, checked))
        #expect(rate < 0.004, "synced tracks are \(String(format: "%.2f", rate * 100))% out of scale")
    }

    /// No sync track may play more than 12 identical bars in a row.
    ///
    /// The measured Kraftwerk behaviour is a figure repeated with no variation whatsoever, and
    /// the rules implement that — which over a 128-bar song gave stretches of 30 to 50 identical
    /// bars. Faithful, and tiring. Past twelve bars the pattern now takes a slight change.
    /// Silence resets the count, since a dropout already breaks the repetition.
    @Test func noSyncedTrackRepeatsMoreThan12Bars() throws {
        var worst = 0, worstWhere = ""
        for seed in UInt64(1)...400 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.isActive else { continue }
            var tracks = s.motorikSync.tracks
            if !s.trackEvents[kTrackLead2].isEmpty { tracks.append(kTrackLead2) }
            for track in tracks {
                var byBar: [Int: [MIDIEvent]] = [:]
                for ev in s.trackEvents[track] { byBar[ev.stepIndex / 16, default: []].append(ev) }
                func signature(_ bar: Int) -> String {
                    (byBar[bar] ?? []).sorted { ($0.stepIndex, $0.note) < ($1.stepIndex, $1.note) }
                        .map { "\($0.stepIndex % 16):\($0.note):\($0.velocity):\($0.durationSteps)" }
                        .joined(separator: ",")
                }
                var run = 0, previous = ""
                for bar in 0..<s.frame.totalBars {
                    let current = signature(bar)
                    if current.isEmpty { run = 0; previous = ""; continue }
                    if current == previous { run += 1 } else { run = 1; previous = current }
                    if run > worst { worst = run; worstWhere = "seed \(seed) track \(track) bar \(bar + 1)" }
                }
            }
        }
        #expect(worst <= 12, "a sync track repeated \(worst) identical bars at \(worstWhere)")
    }

    /// Full determinism coverage lives in DeterminismTests; this keeps a sync-specific
    /// check here, since the sync roll is the thing this suite is about.
    @Test func syncIsDeterministic() throws {
        for seed in UInt64(1)...200 {
            let a = SongGenerator.generate(seed: seed, style: .motorik)
            let b = SongGenerator.generate(seed: seed, style: .motorik)
            #expect(a.motorikSync == b.motorikSync, "seed \(seed): sync roll varied")
        }
    }

    // MARK: - Motorik Europe naming

    /// A sync song is presented to the user as "Motorik Europe" — in the song list, the
    /// style chip, Now Playing, the exported genre tag and the .zudio file — and every one
    /// of those reads `displayStyleName`. Nothing else may claim the name.
    @Test func syncSongsAreNamedMotorikEurope() throws {
        var europeCount = 0
        for seed in UInt64(1)...600 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            if s.motorikSync.isActive {
                europeCount += 1
                #expect(s.displayStyleName == "Motorik Europe",
                        "seed \(seed): synced song displayed as \(s.displayStyleName)")
            } else {
                #expect(s.displayStyleName != "Motorik Europe",
                        "seed \(seed): unsynced song displayed as Motorik Europe")
            }
        }
        #expect(europeCount > 0, "no Motorik Europe songs in 600 seeds")
    }

    /// The generation log's Style tag must agree with the chip the user sees, or the log
    /// says "Motorik" for a song the UI calls "Motorik Europe".
    @Test func generationLogStyleTagMatchesDisplayName() throws {
        for seed in UInt64(1)...300 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard let tag = s.generationLog.first(where: { $0.tag == "Style" })?.description
            else { Issue.record("seed \(seed): no Style entry in the generation log"); continue }
            #expect(tag.hasPrefix(s.displayStyleName + " "),
                    "seed \(seed): log says \(tag), UI says \(s.displayStyleName)")
        }
    }

    /// A .zudio file's `Style:` line is parsed back through MusicStyle(rawValue:) on load,
    /// so it must stay the bare style name — "Motorik Europe" there would fail to match and
    /// silently reload every Europe song as Kosmic. The display name goes on `Substyle:`,
    /// which the loader ignores.
    @Test func zudioFileKeepsStyleLineParseable() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("europe-roundtrip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        var seenEurope = false
        for seed in UInt64(1)...120 {
            let song = SongGenerator.generate(seed: seed, style: .motorik)
            let midi = tmp.appendingPathComponent("s\(seed).midi")
            try SongLogExporter.export(song, midiURL: midi)
            let text = try String(contentsOf: midi.deletingPathExtension()
                .appendingPathExtension("zudio"), encoding: .utf8)
            let lines = text.components(separatedBy: "\n").map {
                $0.trimmingCharacters(in: .whitespaces)
            }

            guard let styleLine = lines.first(where: { $0.hasPrefix("Style:") }) else {
                Issue.record("seed \(seed): no Style: line"); continue
            }
            let raw = styleLine.dropFirst(6).trimmingCharacters(in: .whitespaces)
            #expect(MusicStyle(rawValue: raw) == .motorik,
                    "seed \(seed): Style: \(raw) does not parse back to Motorik")

            let substyle = lines.first { $0.hasPrefix("Substyle:") }?
                .dropFirst(9).trimmingCharacters(in: .whitespaces)
            if song.displayStyleName == "Motorik Europe" {
                seenEurope = true
                #expect(substyle == "Motorik Europe",
                        "seed \(seed): Substyle: line was \(substyle ?? "absent")")
            }
        }
        #expect(seenEurope, "no Motorik Europe songs in 120 seeds")
    }

    // MARK: - Kraftwerk Lead 1 shape

    /// The Kraftwerk lead rules build their line from closed cells measured in the corpus —
    /// figures whose intervals sum to zero, so the line cycles in place. Before that, a
    /// per-note random walk over a sparse chord-tone ladder produced a `+17` leap making up a
    /// tenth of one part, with its repeated figures summing to +12, +14 and -15. The audible
    /// result was a line that lurched up a tenth and crawled back down, over and over.
    ///
    /// Two properties keep that from returning.
    ///
    /// Leaps are measured only between notes close together in time. A pitch jump across
    /// several bars of silence separates two statements and is not something the ear hears as
    /// a leap; measuring those too reports 17 semitones for a part whose widest real interval
    /// is an octave.
    @Test func kraftwerkLeadStaysMelodic() throws {
        var songs = 0
        var worstLeap = 0
        var worstLeapWhere = ""
        var worstDrift = 0.0
        var worstDriftWhere = ""
        for seed in UInt64(1)...500 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.includes(kTrackLead1) else { continue }
            let events = s.trackEvents[kTrackLead1].sorted { $0.stepIndex < $1.stepIndex }
            guard events.count >= 12 else { continue }
            songs += 1

            // Less than half a bar apart: notes the ear groups into one phrase. The generator
            // uses the same boundary — a gap of 8 steps or more is where it ends a phrase,
            // lengthening the note and sometimes resolving it — so a jump across one of those
            // is a new phrase entering, not a leap within a line.
            for (a, b) in zip(events, events.dropFirst()) where b.stepIndex - a.stepIndex < 8 {
                let leap = abs(Int(b.note) - Int(a.note))
                if leap > worstLeap {
                    worstLeap = leap
                    worstLeapWhere = "seed \(seed): \(a.note) -> \(b.note)"
                }
            }
            // A closed cell does not migrate. Compare the average pitch of the first and last
            // quarter: a wandering line shows up here even when no single leap is large.
            let pitches = events.map { Int($0.note) }
            let q = Swift.max(1, pitches.count / 4)
            let first = Double(pitches.prefix(q).reduce(0, +)) / Double(q)
            let last  = Double(pitches.suffix(q).reduce(0, +)) / Double(q)
            if abs(last - first) > abs(worstDrift) {
                worstDrift = last - first
                worstDriftWhere = "seed \(seed)"
            }
        }
        #expect(songs > 20, "not enough Kraftwerk lead songs sampled: \(songs)")
        // The cells cap at an octave and a final pass in the generator folds anything wider
        // back, so this is a guarantee rather than an observation.
        //
        // For scale: the corpus itself reaches 29 semitones on The Robots' "steampad" and 40 on
        // "echopan", so an octave is a conservative ceiling, not a stylistic one. What it
        // catches is the failure mode that produced it — a figure that climbs instead of
        // closing, which is what a `+17` leap making up a tenth of a part looked like.
        #expect(worstLeap <= 12,
                "a Kraftwerk lead leapt \(worstLeap) semitones within a phrase at \(worstLeapWhere) — its cells cap at an octave")
        // Measured across 800 seeds: median 1.6, worst 5.8.
        #expect(abs(worstDrift) <= 10,
                "a Kraftwerk lead drifted \(worstDrift) semitones end to end at \(worstDriftWhere) — the cells are no longer closing")
    }

    /// A lead that never stops, and one that repeats a single pitch, are the two ways this
    /// part stops sounding played. Both were measured in a real song before these guards:
    /// Schnell-Gleis ran 30 consecutive sounding bars, and eleven identical notes in a row.
    ///
    /// The repetition guard allows a pitch struck twice — several corpus cells repeat their
    /// first note — but drops the third strike and leaves the space. Later passes
    /// (`limitIdenticalBars`, the sync dropout) can remove notes and bring two of the same
    /// pitch together again, so a short run can still survive; what must not come back is a
    /// stuck sequencer.
    @Test func kraftwerkLeadBreathes() throws {
        var songs = 0
        var worstRun = 0, worstRunWhere = ""
        var worstStretch = 0, worstStretchWhere = ""
        for seed in UInt64(1)...500 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikSync.includes(kTrackLead1) else { continue }
            let events = s.trackEvents[kTrackLead1].sorted { $0.stepIndex < $1.stepIndex }
            guard events.count >= 12 else { continue }
            songs += 1

            var run = 1
            for (a, b) in zip(events, events.dropFirst()) {
                if a.note == b.note && b.stepIndex - a.stepIndex <= 8 {
                    run += 1
                    if run > worstRun { worstRun = run; worstRunWhere = "seed \(seed) on note \(a.note)" }
                } else {
                    run = 1
                }
            }

            let sounding = Set(events.map { $0.stepIndex / 16 })
            var stretch = 0
            for bar in 0..<s.frame.totalBars {
                if sounding.contains(bar) {
                    stretch += 1
                    if stretch > worstStretch { worstStretch = stretch; worstStretchWhere = "seed \(seed)" }
                } else {
                    stretch = 0
                }
            }
        }
        #expect(songs > 20, "not enough Kraftwerk lead songs sampled: \(songs)")
        #expect(worstRun <= 4,
                "a Kraftwerk lead struck the same pitch \(worstRun) times running at \(worstRunWhere)")
        // A run is capped at 13 bars and a run starting mid-bar touches one more bar index.
        #expect(worstStretch <= 16,
                "a Kraftwerk lead played \(worstStretch) bars without a rest at \(worstStretchWhere)")
    }
}
