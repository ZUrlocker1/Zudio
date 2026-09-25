// MotorikClusterTests.swift — pins the Kraftwerk cluster field against silent loss.
//
// Run with:
//   swift test --filter MotorikClusterTests
//
// WHY THIS EXISTS
// SongState's withXxx() copy methods construct a fresh SongState by listing every field
// explicitly. A field omitted from one of them does not fail to compile — it silently takes
// the init default. For motorikCluster that default is `.none`, so a missed copy method would
// quietly cancel the cluster partway through generation, and the only symptom would be a song
// that half-sounds like Kraftwerk.
//
// These tests round-trip a non-default cluster through every copy method. Add a case here
// whenever a new withXxx() is added to SongState.

import Testing
import Foundation
@testable import Zudio

@Suite struct MotorikClusterTests {

    /// A minimal Motorik song carrying a non-default cluster.
    private func clusteredState(_ cluster: MotorikCluster = .sequenceLock) -> SongState {
        let g = SongGenerator.generate(seed: 4242, style: .motorik)
        // Argument order must match the initialiser exactly; everything other than
        // motorikCluster is copied straight from the generated song.
        return SongState(
            frame: g.frame, structure: g.structure, tonalMap: g.tonalMap,
            trackEvents: g.trackEvents, globalSeed: g.globalSeed,
            trackOverrides: g.trackOverrides, title: g.title, form: g.form, style: g.style,
            percussionStyle: g.percussionStyle, kosmicProgFamily: g.kosmicProgFamily,
            generationLog: g.generationLog, stepAnnotations: g.stepAnnotations,
            motorikCluster: cluster)
    }

    // MARK: - The copy methods

    @Test func survivesWithAmbientBrushKit() throws {
        let s = clusteredState().withAmbientBrushKit(true)
        #expect(s.motorikCluster == .sequenceLock)
    }

    @Test func survivesWithFrame() throws {
        let original = clusteredState()
        let s = original.withFrame(original.frame)
        #expect(s.motorikCluster == .sequenceLock)
    }

    @Test func survivesWithAmbientAudioTexture() throws {
        let s = clusteredState().withAmbientAudioTexture("light_rain.m4a", offset: 15)
        #expect(s.motorikCluster == .sequenceLock)
    }

    @Test func survivesWithChillAudioTexture() throws {
        let s = clusteredState().withChillAudioTexture("harbor.m4a")
        #expect(s.motorikCluster == .sequenceLock)
    }

    /// Chained, because a single surviving hop proves less than a sequence of them.
    @Test func survivesChainedCopies() throws {
        let s = clusteredState(.machineVoice)
            .withAmbientBrushKit(false)
            .withChillAudioTexture(nil)
            .withAmbientAudioTexture(nil)
        #expect(s.motorikCluster == .machineVoice)
    }

    // MARK: - Membership

    /// Texture joins every cluster; Lead 2 is never listed, since the generator decides it.
    @Test func textureIsInEveryCluster() throws {
        for c in MotorikCluster.allCases where c != .none {
            #expect(c.includes(kTrackTexture), "\(c) must include Texture")
            #expect(!c.includes(kTrackLead2), "\(c) must not list Lead 2 — the generator decides it")
        }
    }

    @Test func clusterMembershipMatchesPlan() throws {
        #expect(MotorikCluster.rhythmSection.tracks.sorted() == [kTrackTexture, kTrackBass, kTrackDrums].sorted())
        #expect(MotorikCluster.sequenceLock.tracks.sorted()  == [kTrackTexture, kTrackBass, kTrackRhythm].sorted())
        #expect(MotorikCluster.machineVoice.tracks.sorted()  == [kTrackTexture, kTrackRhythm, kTrackLead1].sorted())
    }

    @Test func noneIsInert() throws {
        #expect(MotorikCluster.none.tracks.isEmpty)
        #expect(!MotorikCluster.none.isActive)
        for t in 0..<kTrackCount { #expect(!MotorikCluster.none.includes(t)) }
    }

    // MARK: - The roll

    /// Clusters are base-Motorik only. A Noir or Arcade song must never draw one, or the
    /// substyle's own carefully weighted rule pools would be overridden.
    @Test func noirAndArcadeNeverCluster() throws {
        for seed in UInt64(1)...400 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            if s.motorikNoirVariation || s.motorikArcadeVariation {
                #expect(s.motorikCluster == .none,
                        "seed \(seed): \(s.displayStyleName) drew \(s.motorikCluster)")
            }
        }
    }

    /// Distribution within base Motorik: none 80 / rhythmSection 8 / sequenceLock 7 /
    /// machineVoice 5. Tolerances are wide enough to absorb sampling noise but tight enough
    /// to catch a threshold typo.
    @Test func clusterDistributionMatchesPlan() throws {
        var counts: [MotorikCluster: Int] = [:]
        var base = 0
        for seed in UInt64(1)...3000 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard !s.motorikNoirVariation && !s.motorikArcadeVariation else { continue }
            base += 1
            counts[s.motorikCluster, default: 0] += 1
        }
        func pct(_ c: MotorikCluster) -> Double { 100.0 * Double(counts[c] ?? 0) / Double(base) }
        #expect(base > 500, "need a reasonable base-Motorik sample, got \(base)")
        #expect(abs(pct(.none)          - 80) < 5, "none \(pct(.none))%")
        #expect(abs(pct(.rhythmSection) -  8) < 4, "rhythmSection \(pct(.rhythmSection))%")
        #expect(abs(pct(.sequenceLock)  -  7) < 4, "sequenceLock \(pct(.sequenceLock))%")
        #expect(abs(pct(.machineVoice)  -  5) < 4, "machineVoice \(pct(.machineVoice))%")
    }

    /// The roll must come from a stream derived from the seed, never the shared generator
    /// RNG — drawing from the shared stream would shift every later draw and change what
    /// every previously generated Motorik song produces. Determinism is the observable part.
    /// Same seed, same output. This is the contract the whole saved-song feature rests on:
    /// a .zudio file stores a seed, and reloading regenerates from it.
    // MARK: - Cluster rules

    /// Every cluster track must actually draw a Kraftwerk rule, and Lead 2 must never draw a
    /// normal Motorik rule when Rhythm is clustered — a melodic Lead 2 over a rigid
    /// two-pitch-class sequencer is the incoherence the whole cluster design exists to prevent.
    @Test func clusterTracksDrawKraftwerkRules() throws {
        let kraftwerk: [Int: [String]] = [
            kTrackDrums:   ["Sequenced Timekeeper", "Sparse Accents"],
            kTrackRhythm:  ["Two-Note Lock", "Paired Sequencer"],
            kTrackLead1:   ["Short Statement", "Long Run"],
            kTrackTexture: ["Wide Scatter", "Sparse Punctuation"],
        ]
        var checked = 0
        for seed in UInt64(1)...600 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikCluster.isActive else { continue }
            checked += 1
            let log = s.generationLog.map(\.description).joined(separator: " | ")
            // The cluster line carries "KW" in its TAG, so check the entry rather than the
            // joined descriptions.
            #expect(s.generationLog.contains { $0.tag == "Sync" },
                    "seed \(seed): no Sync line")
            for (track, names) in kraftwerk where s.motorikCluster.includes(track) {
                #expect(names.contains { log.contains($0) },
                        "seed \(seed) \(s.motorikCluster): track \(track) drew no Kraftwerk rule — \(log)")
            }
            // Bass draws from a four-option pool, two of which are pre-existing Kraftwerk rules.
            if s.motorikCluster.includes(kTrackBass) {
                let bass = ["Locked Micro-Cell", "Restricted Run", "Kraftwerk", "Electro Pump"]
                #expect(bass.contains { log.contains($0) }, "seed \(seed): bass drew outside the cluster pool")
            }
        }
        #expect(checked > 40, "expected a reasonable cluster sample, got \(checked)")
    }

    /// Lead 2 partners with Rhythm or rests — it never plays its own material in a cluster.
    @Test func clusterLead2EitherPartnersOrRests() throws {
        for seed in UInt64(1)...600 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikCluster.includes(kTrackRhythm) else { continue }
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

    /// Cluster songs sit in Kraftwerk's measured tempo band; everything else is untouched.
    @Test func clusterSongsUseTheSlowerTempoBand() throws {
        var cluster: [Int] = [], plain: [Int] = []
        for seed in UInt64(1)...600 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard !s.motorikNoirVariation && !s.motorikArcadeVariation else { continue }
            if s.motorikCluster.isActive { cluster.append(s.frame.tempo) } else { plain.append(s.frame.tempo) }
        }
        #expect(!cluster.isEmpty && !plain.isEmpty)
        #expect(cluster.allSatisfy { (120...132).contains($0) },
                "cluster tempo outside 120-132: \(cluster.filter { !(120...132).contains($0) })")
        // The base band must not have moved — this change is for cluster songs only.
        #expect(plain.allSatisfy { (126...154).contains($0) },
                "non-cluster tempo outside 126-154: \(plain.filter { !(126...154).contains($0) })")
    }

    /// A cluster fills at exactly one kind of moment: the whole cluster dropping out together,
    /// and returning. Nowhere else.
    ///
    /// Removing every fill made the arrangement read as unbroken; keeping the normal ones made
    /// it sound like a drummer. What must not come back: the every-eighth-bar periodic fills,
    /// the generic instrument-entrance fills (Texture and Lead 1 are deliberately sparse, so
    /// those fired almost continuously), and fills at ordinary section boundaries.
    @Test func clusterFillsOnlyAtDropoutEdges() throws {
        // Notes the two Kraftwerk kits never play — their presence means a fill ran.
        let fillOnly: Set<UInt8> = [41, 43, 48, 50, 49]
        var counts: [Int] = []
        for seed in UInt64(1)...500 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikCluster.includes(kTrackDrums) else { continue }

            let fillBars = Set(s.trackEvents[kTrackDrums].filter { fillOnly.contains($0.note) }
                                                        .map { $0.stepIndex / 16 })
            counts.append(fillBars.count)

            // A window contributes at most two seams, so two windows cap a song at four.
            #expect(fillBars.count <= 4,
                    "seed \(seed): \(fillBars.count) fills — more than the dropout edges can explain")

            var seams = Set<Int>()
            for w in SongGenerator.clusterDropoutWindows(cluster: s.motorikCluster,
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
    /// output, so for a cluster it described the fills a NON-cluster song would have had — and
    /// `fillBeats` reads a fill's length from where the hi-hat stops, which for kits that have
    /// no hi-hat at all measured every bar as a 3-beat cascade. One song logged fifteen fills
    /// while its drum track contained one.
    @Test func clusterFillLogMatchesWhatActuallyPlayed() throws {
        let tomMarkers: Set<UInt8> = [41, 43, 48, 50]
        for seed in UInt64(1)...400 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikCluster.isActive else { continue }

            let realFillBars = Set(s.trackEvents[kTrackDrums]
                .filter { tomMarkers.contains($0.note) }
                .map { $0.stepIndex / 16 })

            for (step, entries) in s.stepAnnotations {
                for entry in entries where entry.tag == "Drum fill" {
                    let bar = step / 16
                    #expect(realFillBars.contains(bar) || realFillBars.contains(bar + 1),
                            "seed \(seed): log claims a fill at bar \(bar + 1) but the drums have none")
                    // The engine never draws a 3-beat fill for a cluster.
                    #expect(!entry.description.contains("3 beat"),
                            "seed \(seed) bar \(bar + 1): logged \"\(entry.description)\" — 3-beat fills are not drawn in a cluster")
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
            guard s.motorikCluster.includes(kTrackDrums),
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

    /// No cluster track may play more than 12 identical bars in a row.
    ///
    /// The measured Kraftwerk behaviour is a figure repeated with no variation whatsoever, and
    /// the rules implement that — which over a 128-bar song gave stretches of 30 to 50 identical
    /// bars. Faithful, and tiring. Past twelve bars the pattern now takes a slight change.
    /// Silence resets the count, since a dropout already breaks the repetition.
    @Test func noClusterTrackRepeatsMoreThan12Bars() throws {
        var worst = 0, worstWhere = ""
        for seed in UInt64(1)...400 {
            let s = SongGenerator.generate(seed: seed, style: .motorik)
            guard s.motorikCluster.isActive else { continue }
            var tracks = s.motorikCluster.tracks
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
        #expect(worst <= 12, "a cluster track repeated \(worst) identical bars at \(worstWhere)")
    }

    /// Full determinism coverage lives in DeterminismTests; this keeps a cluster-specific
    /// check here, since the cluster roll is the thing this suite is about.
    @Test func clusterIsDeterministic() throws {
        for seed in UInt64(1)...200 {
            let a = SongGenerator.generate(seed: seed, style: .motorik)
            let b = SongGenerator.generate(seed: seed, style: .motorik)
            #expect(a.motorikCluster == b.motorikCluster, "seed \(seed): cluster roll varied")
        }
    }
}
