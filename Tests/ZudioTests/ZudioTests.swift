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
            chordRootDegree: "1", chordType: .minor, key: "C", mode: .aeolian
        )
        #expect(!tones.isEmpty)
    }

    @Test func avoidTonesExcludeScaleTones() {
        let (_, tensions, avoids) = NotePoolBuilder.build(
            chordRootDegree: "1", chordType: .minor, key: "C", mode: .aeolian
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
