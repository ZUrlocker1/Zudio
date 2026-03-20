// ZudioTests.swift — determinism + basic sanity tests

import Testing
@testable import Zudio

// MARK: - SeededRNG determinism

struct SeededRNGTests {
    @Test func sameSeedException() {
        var rng1 = SeededRNG(seed: 42)
        var rng2 = SeededRNG(seed: 42)
        for _ in 0..<100 {
            #expect(rng1.next() == rng2.next())
        }
    }

    @Test func differentSeedsProduceDifferentOutput() {
        var rng1 = SeededRNG(seed: 1)
        var rng2 = SeededRNG(seed: 2)
        #expect(rng1.next() != rng2.next())
    }
}

// MARK: - Generation determinism

struct SongGeneratorTests {
    @Test func sameInputSameSong() {
        let seed: UInt64 = 12345
        let song1 = SongGenerator.generate(seed: seed)
        let song2 = SongGenerator.generate(seed: seed)
        #expect(song1.frame.key    == song2.frame.key)
        #expect(song1.frame.tempo  == song2.frame.tempo)
        #expect(song1.frame.totalBars == song2.frame.totalBars)
        #expect(song1.trackEvents  == song2.trackEvents)
    }

    @Test func allTracksHaveEvents() {
        let song = SongGenerator.generate(seed: 99)
        // Drums and bass should always have events
        #expect(!song.events(forTrack: kTrackDrums).isEmpty)
        #expect(!song.events(forTrack: kTrackBass).isEmpty)
    }

    @Test func totalBarsPositive() {
        let song = SongGenerator.generate(seed: 7)
        #expect(song.frame.totalBars > 0)
    }

    @Test func totalBarsMultipleOfFour() {
        let song = SongGenerator.generate(seed: 100)
        #expect(song.frame.totalBars % 4 == 0)
    }
}

// MARK: - SongStructure sanity

struct SongStructureTests {
    @Test func sectionsSpanFullSong() {
        let song = SongGenerator.generate(seed: 55)
        let covered = song.structure.sections.reduce(0) { $0 + $1.lengthBars }
        #expect(covered == song.frame.totalBars)
    }

    @Test func chordWindowsSpanAtLeastBody() {
        let song = SongGenerator.generate(seed: 55)
        #expect(!song.structure.chordPlan.isEmpty)
    }
}

// MARK: - Note pool builder

struct NotePoolBuilderTests {
    @Test func chordTonesNonEmpty() {
        let (tones, _, _) = NotePoolBuilder.build(
            chordRootDegree: "1", chordType: .minor, key: "C", mode: .Aeolian
        )
        #expect(!tones.isEmpty)
    }

    @Test func avoidTonesExcludeScaleTones() {
        let (_, tensions, avoids) = NotePoolBuilder.build(
            chordRootDegree: "1", chordType: .minor, key: "C", mode: .Aeolian
        )
        let overlap = tensions.intersection(avoids)
        #expect(overlap.isEmpty)
    }
}

// MARK: - Per-track regenerate

struct RegenerateTests {
    @Test func regenerateChangesOnlyTargetTrack() {
        let seed: UInt64 = 777
        let original  = SongGenerator.generate(seed: seed)
        let updated   = SongGenerator.regenerateTrack(kTrackBass, songState: original)
        // All other tracks unchanged
        for i in [kTrackLead1, kTrackLead2, kTrackPads, kTrackRhythm, kTrackTexture, kTrackDrums] {
            #expect(original.events(forTrack: i) == updated.events(forTrack: i))
        }
        // Frame unchanged (last full generate)
        #expect(original.frame.key   == updated.frame.key)
        #expect(original.frame.tempo == updated.frame.tempo)
    }
}

// MARK: - Phase 1a: stepEventMap correctness
// PlaybackEngine is @MainActor + requires AVAudioEngine, so we test the map-building
// algorithm directly: the map must be a lossless, non-duplicating index of all events.

private func buildStepEventMap(state: SongState) -> [Int: [(Int, MIDIEvent)]] {
    var map: [Int: [(Int, MIDIEvent)]] = [:]
    for trackIndex in 0..<7 {
        for ev in state.events(forTrack: trackIndex) {
            map[ev.stepIndex, default: []].append((trackIndex, ev))
        }
    }
    return map
}

struct StepEventMapTests {
    @Test func mapContainsEveryEvent() {
        let song = SongGenerator.generate(seed: 42)
        let map  = buildStepEventMap(state: song)
        // Count events via O(n) scan (ground truth)
        var directCount = 0
        for t in 0..<7 { directCount += song.events(forTrack: t).count }
        // Count events via map (what onStep now uses)
        let mapCount = map.values.reduce(0) { $0 + $1.count }
        #expect(mapCount == directCount)
    }

    @Test func mapLookupMatchesDirectScan() {
        let song = SongGenerator.generate(seed: 99)
        let map  = buildStepEventMap(state: song)
        let totalSteps = song.frame.totalBars * 16
        for step in 0..<totalSteps {
            // Direct scan (old approach)
            var direct: [(Int, MIDIEvent)] = []
            for t in 0..<7 {
                for ev in song.events(forTrack: t) where ev.stepIndex == step {
                    direct.append((t, ev))
                }
            }
            // Map lookup (new approach)
            let fromMap = map[step] ?? []
            // Same total count per step
            #expect(fromMap.count == direct.count, "Step \(step): map has \(fromMap.count), direct has \(direct.count)")
        }
    }

    @Test func mapHasNoStepsOutsideSongRange() {
        let song = SongGenerator.generate(seed: 7)
        let map  = buildStepEventMap(state: song)
        let maxStep = song.frame.totalBars * 16
        for step in map.keys {
            #expect(step >= 0 && step < maxStep, "Event at step \(step) outside song range 0..<\(maxStep)")
        }
    }

    @Test func mapTrackIndicesAreValid() {
        let song = SongGenerator.generate(seed: 55)
        let map  = buildStepEventMap(state: song)
        for entries in map.values {
            for (trackIndex, _) in entries {
                #expect(trackIndex >= 0 && trackIndex < 7)
            }
        }
    }
}

// MARK: - Phase 3a: generationHistory cap
// Tests the pure array-capping logic in isolation.

struct GenerationHistoryCapTests {
    @Test func capAt5() {
        var history: [Int] = []
        for i in 0..<10 {
            history.append(i)
            if history.count > 5 { history.removeFirst() }
        }
        #expect(history.count == 5)
        #expect(history == [5, 6, 7, 8, 9])
    }

    @Test func capRetainsMostRecent() {
        var history: [SongState] = []
        for seed: UInt64 in 0..<8 {
            let s = SongGenerator.generate(seed: seed)
            history.append(s)
            if history.count > 5 { history.removeFirst() }
        }
        #expect(history.count == 5)
        // Oldest seed kept should be 3 (seeds 0–2 evicted)
        #expect(history.first?.globalSeed == 3)
        #expect(history.last?.globalSeed  == 7)
    }
}
